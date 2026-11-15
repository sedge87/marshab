# Real Mars patches

Each `.npz` here is a small patch of real Mars relief cut from a HiRISE digital terrain model
(DTM) with `tools/hirise_patch.py`. The DTMs themselves are not in the repository. Each
patch's `source` field gives the DTM id, the mode, and where and how it was cut.

Credit: NASA/JPL-Caltech/University of Arizona (HiRISE), DTMs produced with USGS.

| Patch | DTM | What it shows | Used for |
|---|---|---|---|
| yardangs_arabia.npz | DTEED_061610_1895_061887_1895_A01 | yardangs, Arabia Terra | surface detail on the yardang maze |
| inverted_juventae.npz | DTEEC_007627_1765_008563_1765_U01 | inverted valleys near Juventae Chasma | raised riverbeds |
| glacier_protonilus.npz | DTEED_009455_2215_008809_2215_A01 | glacier-like flow, Protonilus Mensae | the glacier tongue's flow lines |
| ice_scarp_promethei.npz | DTEEC_021466_1230_021954_1230_A01 | ice scarp, Promethei Terra | the banded faces of ice scarps |
