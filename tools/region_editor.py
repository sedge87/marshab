"""The land editor (docs/terrain-design.md §13): a small local server for editing data/region_layout.json in the
browser. It listens on 127.0.0.1 only, so nothing but this PC can reach it. Start it with tools/edit_land.bat.

  GET  /                  the page (tools/region_editor/index.html)
  GET  /layout            the layout file
  GET  /region            the last build's region.json (anchors, checks, caves)
  GET  /map.png           the last build's shaded heights; /map_before.png the build before it
  GET  /sculpt.png        where the sculpt layer changes the land (if there is one)
  GET  /history           the saved layouts, newest first
  GET  /history/<name>    one of them
  POST /save              save the layout (body: JSON); the old one is kept in data/region_layout_history/
  POST /regenerate        run the generator (--quick) in the background; body {"full": true} for the textures too
  GET  /status            the generator's state and its log so far

Usage: python tools/region_editor.py [--port 8765] [--no-browser]
"""
import http.server
import io
import json
import os
import subprocess
import sys
import threading
import time
import webbrowser

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import region_layout  # noqa: E402

ROOT = region_layout.ROOT
HOST = "127.0.0.1"
PORT = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 8765
PAGE = os.path.join(ROOT, "tools", "region_editor", "index.html")
HISTORY = os.path.join(ROOT, "data", "region_layout_history")
STATE = {"running": False, "log": "", "started": 0.0, "finished": 0.0, "ok": None, "full": False}
LOCK = threading.Lock()


def region_folder():
    layout = region_layout.load()
    return os.path.join(ROOT, "assets", "terrain", layout["region"].get("id", "test_region"))


def map_png(folder, name="preview.png"):
    """The preview as the editor's map: shaded heights, north up, 1 px = 6 m (512 px)."""
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        return f.read()


def sculpt_png():
    """Where the sculpt layer changes the land: red raised, blue lowered, clear elsewhere (512 px)."""
    path = os.path.join(ROOT, "data", "region_sculpt.landdelta")
    if not os.path.exists(path):
        return None
    import land_delta
    delta = land_delta.read(path)
    full = delta.to_array()
    step = max(1, full.shape[0] // 512)
    d = full[::step, ::step]
    img = np.zeros(d.shape + (4,), dtype=np.uint8)
    a = np.clip(np.abs(d) / 4.0, 0.0, 1.0)
    img[..., 0] = np.where(d > 0, 230, 40); img[..., 2] = np.where(d < 0, 230, 40); img[..., 1] = 60
    img[..., 3] = (a * 200).astype(np.uint8)
    buf = io.BytesIO(); Image.fromarray(img, "RGBA").save(buf, "PNG")
    return buf.getvalue()


def keep_history(text):
    os.makedirs(HISTORY, exist_ok=True)
    name = time.strftime("%Y-%m-%d_%H%M%S") + ".json"
    with open(os.path.join(HISTORY, name), "w", encoding="utf-8") as f:
        f.write(text)
    return name


def regenerate(full):
    folder = region_folder()
    before = os.path.join(folder, "preview.png")
    if os.path.exists(before):
        with open(before, "rb") as f:
            data = f.read()
        with open(os.path.join(folder, "preview_before.png"), "wb") as f:
            f.write(data)
    cmd = [sys.executable, os.path.join(ROOT, "tools", "generate_region.py")] + ([] if full else ["--quick"])
    with LOCK:
        STATE.update(running=True, log="$ " + " ".join(os.path.basename(c) for c in cmd) + "\n", started=time.time(), ok=None, full=full)
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    for line in proc.stdout:
        with LOCK:
            STATE["log"] += line
    proc.wait()
    with LOCK:
        STATE.update(running=False, finished=time.time(), ok=proc.returncode == 0)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def send(self, body, kind="application/json", code=200):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def local_only(self):
        if self.client_address[0] != "127.0.0.1":
            self.send(b"local only", "text/plain", 403)
            return False
        return True

    def do_GET(self):
        if not self.local_only():
            return
        path = self.path.split("?")[0]
        folder = region_folder()
        if path in ("/", "/index.html"):
            with open(PAGE, "rb") as f:
                return self.send(f.read(), "text/html; charset=utf-8")
        if path == "/layout":
            with open(region_layout.PATH, "rb") as f:
                return self.send(f.read())
        if path == "/region":
            p = os.path.join(folder, "region.json")
            if not os.path.exists(p):
                return self.send("{}")
            with open(p, "rb") as f:
                return self.send(f.read())
        if path in ("/map.png", "/map_before.png"):
            data = map_png(folder, "preview.png" if path == "/map.png" else "preview_before.png")
            return self.send(data, "image/png") if data else self.send(b"", "image/png", 404)
        if path == "/sculpt.png":
            data = sculpt_png()
            return self.send(data, "image/png") if data else self.send(b"", "image/png", 404)
        if path == "/history":
            names = sorted(os.listdir(HISTORY), reverse=True) if os.path.isdir(HISTORY) else []
            return self.send(json.dumps([n for n in names if n.endswith(".json")]))
        if path.startswith("/history/"):
            name = os.path.basename(path[len("/history/"):])
            p = os.path.join(HISTORY, name)
            if not name.endswith(".json") or not os.path.exists(p):
                return self.send(b"{}", code=404)
            with open(p, "rb") as f:
                return self.send(f.read())
        if path == "/status":
            with LOCK:
                return self.send(json.dumps(STATE))
        self.send(b"not found", "text/plain", 404)

    def do_POST(self):
        if not self.local_only():
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8") if length else ""
        if self.path == "/save":
            try:
                layout = json.loads(body)
                assert isinstance(layout.get("landforms"), list) and "region" in layout
                ids = [e["id"] for e in layout["landforms"]]
                assert len(ids) == len(set(ids)), "two landforms share an id"
            except (ValueError, AssertionError, KeyError, TypeError) as error:
                return self.send(json.dumps({"ok": False, "error": str(error) or "not a layout"}), code=400)
            with open(region_layout.PATH, encoding="utf-8") as f:
                old = f.read()
            kept = keep_history(old)
            region_layout.save(layout)
            return self.send(json.dumps({"ok": True, "kept": kept}))
        if self.path == "/regenerate":
            with LOCK:
                if STATE["running"]:
                    return self.send(json.dumps({"ok": False, "error": "already running"}), code=409)
            full = bool(json.loads(body).get("full")) if body else False
            threading.Thread(target=regenerate, args=(full,), daemon=True).start()
            return self.send(json.dumps({"ok": True}))
        self.send(b"not found", "text/plain", 404)


def main():
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    url = f"http://{HOST}:{PORT}/"
    print(f"The land editor is at {url} (this PC only). Close this window to stop it.")
    if "--no-browser" not in sys.argv:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
