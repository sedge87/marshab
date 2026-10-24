"""Cut the OUTPOST ONE: MARS trailer from the captured takes.

python trailer_outpost_one/edit/edit.py [--preview]

Reads work/footage/<shot>.avi (each starts with the director's WARMUP
frames), trims, grades, lays the takes on a black 60 s timeline with
dissolves at act changes and cuts on the beat (80 BPM: a beat is 0.75 s),
sets the type in the game's own fonts (Noto Sans, Noto Sans Mono), adds the
score and writes outpost-one-mars-trailer.mp4 in the trailer folder.
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parents[1]
WORK = HERE / "work"
FOOTAGE = WORK / "footage"
TITLES = WORK / "titles"
FONTS = HERE.parent / "fonts"
W, H, FPS = 1920, 1080, 30
WARMUP = 2.0            # seconds of WARMUP frames at the head of every take
LENGTH = 60.0
PREVIEW = "--preview" in sys.argv

# (shot, timeline start, timeline end, source in-point after warmup, dissolve in)
CUT = [
    # Act 1: the frontier
    ("canyon_dawn", 0.00, 5.25, 0.6, 0.0),
    ("ice_fog", 5.25, 9.00, 0.8, 0.6),
    ("touchdown", 9.00, 15.00, 1.4, 0.6),
    # Act 2: the outpost
    ("reveal", 15.00, 18.75, 1.6, 1.0),
    ("hull_glide", 18.75, 21.00, 1.5, 0.0),
    ("airlock_in", 21.00, 24.00, 0.4, 0.0),
    ("galley", 24.00, 27.00, 1.0, 0.0),
    ("hydro", 27.00, 30.00, 1.0, 0.0),
    # Act 3: building a future
    ("siteplan", 30.00, 33.00, 0.0, 0.0),
    ("furnish", 33.00, 36.00, 0.3, 0.0),
    ("science", 36.00, 37.50, 1.2, 0.0),
    ("power", 37.50, 39.75, 0.45, 0.0),
    ("solar_field", 39.75, 42.00, 1.0, 0.0),
    ("storm", 42.00, 48.00, 0.5, 0.0),
    # Act 4: Outpost One
    ("finale", 48.00, 60.00, 0.0, 0.8),
]
NO_GRADE = {"siteplan", "power", "furnish"}      # the game UI stays as it is

ORANGE = (237, 124, 53)
WHITE = (244, 240, 234)


def font(size: int, weight: int, mono=False) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONTS / ("NotoSansMono.ttf" if mono else "NotoSans.ttf")), size)
    try: f.set_variation_by_axes([weight] if mono else [weight, 100])
    except Exception: pass
    return f


def tracked(draw: ImageDraw.ImageDraw, xy, text: str, f, fill, spacing: float, anchor="l") -> float:
    """Draw letter-spaced text; returns its width. anchor 'c' centres it on x."""
    widths = [draw.textlength(ch, font=f) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x, y = xy
    if anchor == "c": x -= total / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=f, fill=fill)
        x += w + spacing
    return total


def card(name: str, paint, shadow=0.55) -> Path:
    """The type on a transparent frame, with a soft dark glow under it so it
    reads over bright haze without a box."""
    TITLES.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    paint(ImageDraw.Draw(im))
    if shadow > 0:
        alpha = im.getchannel("A").filter(ImageFilter.GaussianBlur(9))
        glow = Image.new("RGBA", (W, H), (8, 6, 6, 0))
        glow.putalpha(alpha.point(lambda a: int(min(255, a * 1.6) * shadow)))
        im = Image.alpha_composite(glow, im)
    path = TITLES / f"{name}.png"
    im.save(path)
    return path


def line(text: str, y=878, size=34, weight=380):
    def paint(d):
        tracked(d, (W / 2, y), text, font(size, weight), WHITE + (225,), size * 0.32, "c")
    return paint


def tag(word: str, index: int):
    """Act 3: the tagline, one word at a time, small in the lower left."""
    # Middle right: clear of the game's build bar along the bottom and its
    # info card in the top right.
    def paint(d):
        right, y = 1800, 560
        f = font(34, 400, True)
        width = tracked(d, (0, -200), word, f, (0, 0, 0, 0), 11)
        x = right - width
        d.rectangle([x - 26, y + 8, x - 23, y + 50], fill=ORANGE + (255,))
        tracked(d, (x, y), f"0{index}", font(22, 500, True), ORANGE + (255,), 4)
        tracked(d, (x, y + 26), word, f, WHITE + (245,), 11)
    return paint


def title(d):
    # In the dusk sky above the outpost.
    tracked(d, (W / 2, 196), "OUTPOST ONE", font(118, 250), WHITE + (255,), 30, "c")
    tracked(d, (W / 2, 350), "MARS", font(42, 500, True), ORANGE + (255,), 26, "c")
    d.rectangle([W / 2 - 60, 428, W / 2 + 60, 429], fill=WHITE + (120,))
    tracked(d, (W / 2, 456), "DESIGN.  LIVE.  WORK.  SURVIVE.", font(27, 450, True), WHITE + (235,), 8, "c")


# (png, in, out, fade)
TEXT = [
    (card("t_home", line("225 MILLION KILOMETRES FROM HOME")), 1.6, 4.6, 0.8),
    (card("t_bring", line("EVERYTHING WE NEED, WE BRING WITH US")), 10.5, 14.2, 0.8),
    (card("w_design", tag("DESIGN", 1)), 30.4, 32.8, 0.35),
    (card("w_live", tag("LIVE", 2)), 33.4, 35.8, 0.35),
    (card("w_work", tag("WORK", 3)), 36.4, 41.8, 0.35),
    (card("w_survive", tag("SURVIVE", 4)), 42.6, 47.6, 0.35),
    (card("title", title), 54.0, 60.0, 1.4),
]


def grade(shot: str) -> str:
    if shot in NO_GRADE: return "null"
    if shot == "ice_fog":   # morning fog: lift it out of the white a little
        return ("eq=contrast=1.16:saturation=1.08:gamma=0.9,"
                "colorbalance=rs=-0.02:bs=0.03:rh=0.03:bh=-0.02,"
                "vignette=angle=0.42,noise=alls=2:allf=t")
    # Gentle: a touch of contrast and warmth, a soft vignette, fine grain.
    return ("eq=contrast=1.07:saturation=1.05:gamma=0.97,"
            "colorbalance=rs=-0.02:bs=0.03:rh=0.03:bh=-0.02,"
            "vignette=angle=0.42,noise=alls=2:allf=t")


def main() -> None:
    inputs, chains = [], []
    inputs += ["-f", "lavfi", "-i", f"color=c=black:s={W}x{H}:r={FPS}:d={LENGTH}"]
    n = 1
    layers = []
    for shot, start, end, src_in, dissolve in CUT:
        tail = 0.6 if shot != "finale" else 0.0      # a little overlap so dissolves have frames
        dur = end - start + tail
        inputs += ["-ss", f"{WARMUP + src_in:.3f}", "-t", f"{dur:.3f}", "-i", str(FOOTAGE / f"{shot}.avi")]
        f = f"[{n}:v]scale={W}:{H}:flags=lanczos,fps={FPS},{grade(shot)},format=yuva420p"
        if dissolve > 0: f += f",fade=t=in:st=0:d={dissolve}:alpha=1"
        f += f",setpts=PTS-STARTPTS+{start}/TB[v{n}]"
        chains.append(f)
        layers.append((f"v{n}", start, end + tail))
        n += 1
    base = "0:v"
    for i, (label, start, stop) in enumerate(layers):
        out = f"b{i}"
        chains.append(f"[{base}][{label}]overlay=eof_action=pass:enable='between(t,{start},{stop})'[{out}]")
        base = out
    # Fades: up from black at the open, a dip behind the title, down to black at the end.
    chains.append(f"[{base}]fade=t=in:st=0:d=1.6,fade=t=out:st=58.6:d=1.4[graded]")
    inputs += ["-f", "lavfi", "-i", f"color=c=black:s={W}x{H}:r={FPS}:d={LENGTH},format=yuva420p"]
    chains.append(f"[{n}:v]fade=t=in:st=53.0:d=1.6:alpha=1,colorchannelmixer=aa=0.58[dim]")
    chains.append("[graded][dim]overlay[withdim]")
    n += 1
    base = "withdim"
    for i, (png, t_in, t_out, fade) in enumerate(TEXT):
        inputs += ["-loop", "1", "-t", f"{LENGTH}", "-i", str(png)]
        chains.append(f"[{n}:v]format=rgba,fade=t=in:st={t_in}:d={fade}:alpha=1,fade=t=out:st={t_out - fade}:d={fade}:alpha=1[t{i}]")
        chains.append(f"[{base}][t{i}]overlay=enable='between(t,{t_in},{t_out})'[o{i}]")
        base = f"o{i}"
        n += 1
    # The poster (the settled title) as frame 0, so every thumbnail shows it.
    poster = HERE / "poster.jpg"
    if poster.exists() and not PREVIEW:
        inputs += ["-loop", "1", "-t", "0.1", "-i", str(poster)]
        chains.append(f"[{n}:v]scale={W}:{H},format=yuv420p[poster]")
        chains.append(f"[{base}][poster]overlay=enable='eq(n,0)'[framed]")
        base = "framed"
        n += 1
    inputs += ["-i", str(WORK / "score.wav")]
    chains.append(f"[{n}:a]loudnorm=I=-15:TP=-1.5:LRA=9,aresample=48000[aout]")
    out = HERE / ("preview.mp4" if PREVIEW else "outpost-one-mars-trailer.mp4")
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *inputs, "-filter_complex", ";".join(chains),
           "-map", f"[{base}]", "-map", "[aout]", "-t", f"{LENGTH}", "-r", str(FPS),
           "-c:v", "libx264", "-preset", "veryfast" if PREVIEW else "slow", "-crf", "24" if PREVIEW else "18",
           "-pix_fmt", "yuv420p", "-profile:v", "high", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(out)]
    subprocess.run(cmd, check=True)
    print("wrote", out)
    if not PREVIEW and not poster.exists():
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", "57.0", "-i", str(out), "-frames:v", "1", "-q:v", "2", str(poster)], check=True)
        print("poster picked at 57.0 s; run again to bake it in as frame 0")


if __name__ == "__main__":
    main()
