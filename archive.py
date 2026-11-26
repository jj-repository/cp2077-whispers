r"""archive.py   builds main\archive\pc\mod\WhispersNC.archive (the site art): one texture + one
inkatlas, own resource paths, nothing of the game overridden (no ArchiveXL feature, no .xl).

  whispers\gui\whispers.xbm      1024 x 1024, UI group, no mips (setup taken over from the game's own browser icon
                                 texture, the pixels from assets\whispers_atlas.png, made by art.py)
  whispers\gui\whispers.inkatlas parts "banner" (site header), "tile" (browser home tile), "title" (lettering only), see art.PARTS
The result is kept in main, so a normal build needs neither WolvenKit nor the game; run this after changing
the art. Same pipeline as Boosting's / Kill Arena's archive.py (WolvenKit CLI import -k, convert, pack + fix_segments / crc_check /
oodle_check). Structure templates (not shipped): the game's icons_atlas.inkatlas / .xbm, unbundled into tmp\tpl.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOLS = Path.home() / ".claude" / "tools" / "cyberpunk"  # WolvenKit CLI lives there
W = str(TOOLS / "wkc" / "WolvenKit.CLI.exe")
GAME = r"E:\SteamLibrary\steamapps\common\Cyberpunk 2077"
TPL = HERE / "tmp" / "tpl"
VAN = "base/gameplay/gui/world/internet/templates/atlases"
DIR = "whispers\\gui\\"  # resource folder inside the archive
NAME = "WhispersNC"
OUT = HERE / "main" / "archive" / "pc" / "mod" / (NAME + ".archive")


def wk(*a, ok=(0,)):
    r = subprocess.run(
        [W, *a],
        capture_output=True,
        text=True,
        cwd=os.path.dirname(W),
        errors="replace",
    )
    assert r.returncode in ok and ": Error" not in r.stdout, r.stdout[-800:]
    return r.stdout


def tool(script, *a):
    r = subprocess.run(
        [sys.executable, "-I", str(TOOLS / script), *a],
        capture_output=True,
        text=True,
        errors="replace",
    )
    print(
        "  ",
        script,
        "rc",
        r.returncode,
        (r.stdout.strip().splitlines() or [""])[-1][:140],
    )
    assert r.returncode == 0, r.stdout[-600:] + r.stderr[-600:]


def template():
    d = TPL / VAN
    if not (d / "icons_atlas.xbm").exists():
        wk(
            "unbundle",
            GAME + r"\archive\pc\content\basegame_4_gamedata.archive",
            "-o",
            str(TPL),
            "-w",
            r"*internet\templates\atlases\icons_atlas.*",
        )
    if not (d / "icons_atlas.inkatlas.json").exists():
        wk("convert", "serialize", str(d / "icons_atlas.inkatlas"), "-o", str(d))
    return d


def main():
    sys.path.insert(0, str(HERE))
    import art

    art.main()
    tpl = template()
    work = HERE / "tmp" / "arc"
    shutil.rmtree(work, ignore_errors=True)
    tree = work / NAME / "whispers" / "gui"
    raw = work / "raw"
    tree.mkdir(parents=True)
    raw.mkdir()
    # texture: the game's UI texture as the container (its setup is kept), our pixels as the buffer
    shutil.copy2(tpl / "icons_atlas.xbm", tree / "whispers.xbm")
    shutil.copy2(HERE / "assets" / "whispers_atlas.png", raw / "whispers.png")
    o = wk("import", str(raw), "-k", "-o", str(tree), ok=(0, 3))
    assert "Imported 1/1" in o, o[-400:]
    wk("convert", "serialize", str(tree / "whispers.xbm"), "-o", str(work))
    x = json.load(open(work / "whispers.xbm.json", encoding="utf8"))["Data"][
        "RootChunk"
    ]
    assert (x["width"], x["height"]) == art.ATLAS, (x["width"], x["height"])
    assert (
        x["setup"]["group"] == "TEXG_Generic_UI"
        and x["setup"]["hasMipchain"] == 0
        and x["setup"]["isGamma"] == 1
    ), x["setup"]
    print(
        "xbm",
        x["width"],
        "x",
        x["height"],
        x["setup"]["compression"],
        x["setup"]["rawFormat"],
    )
    # atlas: the game's atlas as the structure, every slot pointing at our texture with our two parts
    d = json.load(open(tpl / "icons_atlas.inkatlas.json", encoding="utf8"))
    rc = d["Data"]["RootChunk"]
    part0 = rc["slots"]["Elements"][0]["parts"][0]
    parts = []
    for name, (px, py, pw, ph) in art.PARTS.items():
        p = json.loads(json.dumps(part0))
        p["partName"]["$value"] = name
        p["clippingRectInUVCoords"].update(
            Left=px / art.ATLAS[0],
            Right=(px + pw) / art.ATLAS[0],
            Top=py / art.ATLAS[1],
            Bottom=(py + ph) / art.ATLAS[1],
        )
        parts.append(p)
    for slot in rc["slots"]["Elements"]:
        slot["parts"] = json.loads(json.dumps(parts))
        slot["slices"] = []
        slot["texture"]["DepotPath"]["$value"] = DIR + "whispers.xbm"
    d["Header"]["ArchiveFileName"] = ""  # only a note of the JSON export, not part of the resource
    rc["parts"] = []
    rc["slices"] = []
    text = json.dumps(d, indent=1)
    assert "icons_atlas" not in text, "a vanilla path is left in the atlas"
    j = tree / "whispers.inkatlas.json"
    j.write_text(text, encoding="utf8")
    wk("convert", "deserialize", str(j), "-o", str(tree))
    j.unlink()
    assert sorted(f.name for f in tree.iterdir()) == [
        "whispers.inkatlas",
        "whispers.xbm",
    ], list(tree.iterdir())
    wk("pack", str(work / NAME), "-o", str(work))
    arc = work / (NAME + ".archive")
    tool("fix_segments.py", W, str(arc))
    tool("crc_check.py", str(arc))
    tool("oodle_check.py", str(arc))
    for f in work.glob("*.bak"):
        f.unlink()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(arc, OUT)
    print("archive", OUT, OUT.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
