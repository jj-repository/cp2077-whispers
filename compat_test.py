"""Clean-install compile test of Whispers of Night City.
Mirror = vanilla script bundle + only the Codeware (+ Mod Settings) script paths + Browser Extension + this mod.
No other mod is in the mirror, so anything that is not vanilla, Codeware, Browser Extension or ours fails here
(proves the JJ Bank / JJ Rewards branches stay out without those mods).
Runs the compiler at below-normal priority, one compile at a time."""

import os, shutil, subprocess, sys, tempfile

R = os.path.dirname(os.path.abspath(__file__))
G = r"E:\SteamLibrary\steamapps\common\Cyberpunk 2077"
VANILLA = os.path.expanduser(r"~\.claude\jobs\e44afcc9\tmp\sccrr\out\final.redscripts.bk")  # untouched vanilla bundle
OLD = os.path.join(tempfile.gettempdir(), "claude", "29abb69cf93759cc", "ef02c06b-cf46-4107-bda4-d89b5b15091a", "scratchpad", "rs")  # old compiler download, if still there
SCC = {
    "v1.0.0 (installed)": os.path.join(G, r"engine\tools\scc.exe"),
    "v0.5.32": os.path.join(
        OLD, r"x_v0.5.32\engine\tools\scc.exe"
    ),  # only if that download still exists
}
CW = os.path.join(G, r"red4ext\plugins\Codeware\Scripts")
MS = os.path.join(G, r"red4ext\plugins\mod_settings")
# name -> (script folders [(repo dir or None = from the game, folder)], extra compile paths)
WNC = [("main", "WhispersNC")]
BE = [(None, "BrowserExtension")]

SETS = {  # Browser Extension is a requirement (the website is the mod), Mod Settings optional
    "+Browser Ext": (WNC + BE, [CW]),
    "+Browser Ext+Mod Settings": (WNC + BE, [CW, MS]),
}

subprocess.run([sys.executable, os.path.join(R, "gen_data.py")], check=True)
bad = 0
for ver, scc in SCC.items():
    if not os.path.exists(scc):
        print(f"{ver:20} skipped (compiler not on this machine)")
        continue
    for name, (parts, paths) in SETS.items():
        J = os.path.join(tempfile.gettempdir(), "wnc_compat_mirror")
        shutil.rmtree(J, ignore_errors=True)
        sd = os.path.join(J, "r6", "scripts")
        os.makedirs(sd)
        os.makedirs(os.path.join(J, "out"))
        os.makedirs(
            os.path.join(J, "r6", "cache")
        )  # redscript 1.0.2 reads r6\cache next to r6\scripts
        for repo_dir, folder in parts:
            src = (
                os.path.join(G, "r6", "scripts", folder)
                if repo_dir is None
                else os.path.join(R, repo_dir, "r6", "scripts", folder)
            )
            shutil.copytree(src, os.path.join(sd, folder))
        for d in ("out", os.path.join("r6", "cache")):
            shutil.copy2(VANILLA, os.path.join(J, d, "final.redscripts"))
            shutil.copy2(
                VANILLA.replace(".bk", ".ts"), os.path.join(J, d, "final.redscripts.ts")
            )
        shutil.copy2(VANILLA, os.path.join(J, "r6", "cache", "final.redscripts.bk"))
        pf = os.path.join(J, "paths.txt")
        open(pf, "w").write("\n".join(paths) + "\n")
        try:
            p = subprocess.run(
                [
                    scc,
                    "-compile",
                    sd,
                    "-customCacheDir",
                    os.path.join(J, "out"),
                    "-compilePathsFile",
                    pf,
                ],
                capture_output=True,
                text=True,
                errors="replace",
                timeout=300,
                creationflags=subprocess.BELOW_NORMAL_PRIORITY_CLASS,
            )
        except subprocess.TimeoutExpired:
            print(f"{ver:20} {name:18} TIMEOUT (likely an error dialog)")
            bad += 1
            continue
        out = p.stdout + p.stderr
        log = os.path.join(J, "r6", "logs", "redscript_rCURRENT.log")
        if os.path.exists(log):
            out += open(log, encoding="utf-8", errors="replace").read()
        lines = out.splitlines()
        errs = [l for l in lines if "ERROR" in l]
        warns = [l for l in lines if "WARN" in l]
        ok = p.returncode == 0 and not errs
        bad += not ok
        print(
            f"{ver:20} {name:18} rc={p.returncode} ok={ok} errors={len(errs)} warnings={len(warns)}"
        )
        for i, l in enumerate(lines):
            if "ERROR" in l or (
                "WARN" in l and "WhispersNC" in "".join(lines[i : i + 3])
            ):
                print("     ", "\n      ".join(lines[i : i + 4])[:600])
sys.exit(1 if bad else 0)
