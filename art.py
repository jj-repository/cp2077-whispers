r"""art.py   site art: assets\source\logo.png (the author's own key art, 1672 x 941: detective silhouette, title lettering
upper right) -> assets\whispers_atlas.png (1024 x 1024 RGBA) + release\cover.png (Nexus cover = the original picture).
Run by archive.py (which turns the atlas into the game texture).

Parts (PARTS below, pixels inside the atlas; 4 px clear border inside each part):
  banner  the whole picture, aspect kept (site header, shown at 960 x 540)
  tile    square for the browser's home tile, cut around the title lettering
  title   the title lettering alone (spare, for a narrow header)
"""

import os
import shutil
import sys
from pathlib import Path

sys.path.append(os.path.expandvars(r"%APPDATA%\Python\Python312\site-packages"))
from PIL import Image  # noqa: E402

HERE = Path(__file__).resolve().parent
ATLAS = (1024, 1024)
PARTS = {
    "banner": (0, 0, 1024, 576),
    "tile": (0, 584, 256, 256),
    "title": (264, 584, 760, 436),
}
TITLE = (
    820,
    100,
    1600,
    545,
)  # title lettering in the source picture (x0, y0, x1, y1), measured on logo.png
TILE = (780, 0, 1640, 860)  # square around it


def fit(im, w, h):
    s = min(w / im.width, h / im.height)
    r = im.resize(
        (max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS
    )
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    c.paste(r, ((w - r.width) // 2, (h - r.height) // 2))
    return c


def main():
    src = Image.open(HERE / "assets" / "source" / "logo.png").convert("RGBA")
    atlas = Image.new("RGBA", ATLAS, (0, 0, 0, 0))
    for name, crop in (("banner", None), ("tile", TILE), ("title", TITLE)):
        x, y, w, h = PARTS[name]
        atlas.paste(fit(src.crop(crop) if crop else src, w - 8, h - 8), (x + 4, y + 4))
    atlas.save(HERE / "assets" / "whispers_atlas.png")
    (HERE / "release").mkdir(exist_ok=True)
    shutil.copy2(
        HERE / "assets" / "source" / "logo.png", HERE / "release" / "cover.png"
    )
    print("source", src.size, "-> atlas", ATLAS)


if __name__ == "__main__":
    main()
