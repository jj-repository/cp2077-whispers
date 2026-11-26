r"""build.py [--deploy] : regenerate the data (gen_data.py), zip the downloads into dist\,
--deploy also copies them into the game folder. Version = first version line of CHANGELOG.txt.
The site art archive (main\archive\pc\mod\WhispersNC.archive) is kept in the repo; rebuild it with `python archive.py`
after changing assets\source\logo.png (art.py -> atlas png -> WolvenKit CLI texture import + inkatlas + pack)."""

import os, re, shutil, subprocess, sys, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = r"E:\SteamLibrary\steamapps\common\Cyberpunk 2077"
PACKS = {  # zip name -> folder laid out like the game folder
    "WhispersOfNightCity": "main",  # one download: website, art, settings menu (behind ModuleExists)
}

subprocess.run([sys.executable, os.path.join(HERE, "gen_data.py")], check=True)
version = re.search(
    r"^(\d+\.\d+(?:\.\d+)?)\s*$",
    open(os.path.join(HERE, "CHANGELOG.txt"), encoding="utf-8").read(),
    re.M,
).group(1)

dist = os.path.join(HERE, "dist")
os.makedirs(dist, exist_ok=True)
for name, folder in PACKS.items():
    root = os.path.join(HERE, folder)
    zp = os.path.join(dist, "%s_v%s.zip" % (name, version))
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
        for d, ds, fs in os.walk(root):
            ds[:] = [
                x for x in ds if not x.startswith(".")
            ]  # editor/tool caches never ship
            for f in fs:
                full = os.path.join(d, f)
                z.write(full, os.path.relpath(full, root).replace(os.sep, "/"))
    print("zip", os.path.basename(zp), zipfile.ZipFile(zp).namelist())
    if "--deploy" in sys.argv:
        shutil.copytree(
            root, GAME, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".*")
        )
        print("  deployed", folder)
