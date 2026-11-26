r"""tools\import_gems.py <journal_dir> -> data\gems.json   (one-time data import, kept for provenance; NOT part of a build)

What it takes, and from where:
  - spot positions, shard journal titles, prerequisites: the two community gem lists we used before (our old private
    gems.json for the 194 city gems, the Dogtown list for 46 Dogtown gems). These are GAME FACTS only (coordinates,
    LocKey ids of vanilla shards, vanilla quest-fact names). No text of those mods is carried over.
  - every shard / mail title is checked against the game's own journal (base + ep1 cooked_journal.journal, serialized
    to JSON with WolvenKit CLI: `unbundle <ep1_2_gamedata.archive> -w *cooked_journal*` then `convert serialize`);
    the import stops if one is missing. The journal path also gives the district of each shard (region label).
  - location text: our own, generated: region (district from the journal path, else the nearest known gem) + a
    compass hint from the region's middle + "up high" / "down low" against the region's median height.
Run: python -I tools\import_gems.py <dir with base\journal\...json and ep1\journal\...json>
"""

import collections, json, math, os, sqlite3, sys

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = sys.argv[1]
OLD = os.path.expanduser(r"~\.claude\tools\cyberpunk\misc_patched\jj_whispers\gems.json")
PTDB = r"E:\SteamLibrary\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\PacificaTyphoon\db.sqlite3"
if not os.path.exists(PTDB):  # parked copy
    PTDB = os.path.expanduser(r"~\.claude\tools\cyberpunk\misc_patched\removed_1126\PacificaTyphoon_12245\cet\PacificaTyphoon\db.sqlite3")

# spots without a shard: (centre x, y, z, xy radius, z radius) from the box corners of each spot
BOX_BASE = {
    10: (-1128.876, -1126.012, 1214.765, 1217.599, 1.2, 1.5),
    20: (-1111.275, -1107.44, 1410.885, 1413.929, 21.7, 21.9),
    30: (-1051.27, -1050.38, 2400, 2401, 18.9, 19.2),
    54: (406.418, 407.459, -502.938, -501.242, 11, 12),
    68: (-220.5, -218.352, -1003.8, -1002.707, 35.9, 36.2),
    120: (291.291, 294.366, -3290.653, -3286.164, 47.3, 47.9),
    174: (-2050.779, -2048.769, 402.622, 405.626, 12.4, 12.6),
    180: (-2401.382, -2399.217, 357.634, 358.875, 17.5, 18),
    183: (-1364.123, -1361.612, -287.353, -286.714, 7.6, 7.8),
    194: (-1186.035, -1182.649, 2075.931, 2080.939, 7, 8),
}
BOX_DT = {  # Dogtown list ids
    11: (-1539.57, -1532.5, -2715.92, -2708.92, 94.276, 99.276),
    17: (-1692.89, -1691.89, -2177.0, -2176.0, 50.5, 51.577),
    20: (-1596.4, -1593.8, -2346.659, -2344.059, 121.8, 124.413),
    24: (-1507.0, -1500.0, -2615.0, -2610.0, 107.325, 111.325),
    42: (-1693.57, -1686.5, -2470.89, -2463.9, 82.5, 88.527),
}
MAIL_DT = {
    3: "LocKey#92253",
    14: "LocKey#83663",
    27: "LocKey#88791",
    36: "LocKey#90159",
}
LOST_BASE = {18, 50, 71, 142, 144}  # rules live in WNC_Core.reds (Lost)
DT_OFFSET = 193  # Dogtown list id 2..47 -> our 195..240 (list id 1 = meeting that mod's contact, not a gem)

REGION = {
    "city_center/downtown": "Downtown",
    "city_center/corpo_plaza": "Corpo Plaza",
    "watson/kabuki": "Kabuki",
    "watson/little_china": "Little China",
    "watson/norhside_industrial_district": "Northside",
    "westbrook/japantown": "Japantown",
    "westbrook/charter_hill": "Charter Hill",
    "westbrook/north_oak": "North Oak",
    "heywood/glen": "the Glen",
    "heywood/vista_del_rey": "Vista del Rey",
    "heywood/wellsprings": "Wellsprings",
    "santo_domingo/arroyo": "Arroyo",
    "santo_domingo/rancho_coronado": "Rancho Coronado",
    "pacifica/coastview": "Coastview",
    "pacifica/west_wind_estate": "West Wind Estate",
    "badlands/se1": "the Badlands",
    "badlands/se5": "the Badlands",
}


def box(b):
    x0, x1, y0, y1, z0, z1 = b
    return (
        (x0 + x1) / 2,
        (y0 + y1) / 2,
        (z0 + z1) / 2,
        round(max(5.0, math.hypot(x1 - x0, y1 - y0) / 2 + 2.0), 1),
        round(max(3.0, (z1 - z0) / 2 + 2.0), 1),
    )


def journal():
    ents = []

    def walk(node, path):
        if isinstance(node, dict):
            d = node.get("Data", node)
            if (
                isinstance(d, dict)
                and isinstance(d.get("id"), str)
                and d.get("$type", "").startswith("gameJournal")
            ):
                p = path + "/" + d["id"] if path else d["id"]
                ents.append((p, d))
                for k, v in d.items():
                    if k != "id":
                        walk(v, p)
                return
            for v in node.values():
                walk(v, path)
        elif isinstance(node, list):
            for v in node:
                walk(v, path)

    for f in (
        r"base\journal\cooked_journal.journal.json",
        r"ep1\journal\cooked_journal.journal.json",
    ):
        walk(
            json.load(open(os.path.join(J, f), encoding="utf-8"))["Data"]["RootChunk"],
            "",
        )
    on, mail = {}, {}
    for p, d in ents:
        t = (
            (d.get("title") or {}).get("value")
            if isinstance(d.get("title"), dict)
            else None
        )
        if d["$type"] == "gameJournalOnscreen":
            on.setdefault(t, p)
        elif d["$type"] == "gameJournalEmail":
            mail.setdefault(t, p)
    return on, mail


def main():
    on, mail = journal()
    gems = []
    for g in json.load(open(OLD, encoding="utf-8")):
        i = g["id"]
        o = g["obj"].lower()
        pool = (
            "stash"
            if g["type"] == "Hidden Stash" or "dead drop" in o
            else (
                "thing"
                if any(
                    w in o
                    for w in ("drone", "robot", "vessel", "cargo", "medical supplies")
                )
                else "person"
            )
        )
        pre = [p for p in g["pre"] if not p.startswith("TIME")]
        e = {
            "id": i,
            "set": "city",
            "x": g["pos"][0],
            "y": g["pos"][1],
            "z": g["pos"][2],
            "pool": pool,
            "early": 1 if g["fixer"] == 1 else 0,
            "pre": pre,
            "lost": i in LOST_BASE,
            "legacy": "hg%d" % i,
        }
        if i in BOX_BASE:
            cx, cy, cz, r, zr = box(BOX_BASE[i])
            e.update(kind="area", key="", x=cx, y=cy, z=cz, r=r, zr=zr)
        else:
            assert g["shard"] in on, ("shard not in the game journal", i, g["shard"])
            e.update(kind="shard", key=g["shard"], jpath=on[g["shard"]])
        for p in pre:
            if p.startswith("SHARD "):
                assert p[6:] in on, ("prereq shard not in journal", i, p)
        gems.append(e)
    assert len(gems) == 194
    c = sqlite3.connect("file:" + PTDB + "?mode=ro", uri=True)
    rows = list(
        c.execute(
            "select ID, Shard, Coordinates, Prerequisite1, Prerequisite2 from HiddenGems order by ID"
        )
    )
    for pid, shard, coords, p1, p2 in rows:
        if pid == 1:
            continue
        x, y, z = (float(v) for v in coords.split())
        pre = []
        if p1 and p1.startswith("FACT "):
            f = p1[5:]
            pre.append(
                "FACTGE %s 3" % f
                if f == "sa_ep1_courier_cars_mounted"
                else ("NOFACT " + f if f == "sts_ep1_08_katya_killed" else p1)
            )
        after = {37: 36, 44: 43}.get(pid)
        if after:
            pre.append("AFTER %d" % (after + DT_OFFSET))
        e = {
            "id": pid + DT_OFFSET,
            "set": "dogtown",
            "x": x,
            "y": y,
            "z": z,
            "early": 1,
            "pre": pre,
            "lost": pid == 44,
            "legacy": "pt%d" % pid,
        }
        if pid in BOX_DT:
            cx, cy, cz, r, zr = box(BOX_DT[pid])
            e.update(kind="area", key="", x=cx, y=cy, z=cz, r=r, zr=zr, pool="place")
        elif pid in MAIL_DT:
            assert MAIL_DT[pid] in mail or MAIL_DT[pid] in on, (
                "mail not in journal",
                pid,
            )
            e.update(
                kind="mail",
                key=MAIL_DT[pid],
                jpath=mail.get(MAIL_DT[pid]) or on[MAIL_DT[pid]],
                pool="place",
            )
        elif shard.startswith("FACT "):
            e.update(
                kind="fact", key=shard[5:], pool="weapon"
            )  # vanilla *_owned facts (in tweakdb.bin)
        else:
            assert shard in on, ("shard not in the game journal", pid, shard)
            jp = on[shard]
            e.update(
                kind="shard",
                key=shard,
                jpath=jp,
                pool="person"
                if (
                    "cyberjunkies" in jp
                    or "street_stories" in jp
                    or "world_encounters" in jp
                )
                else "place",
            )
        gems.append(e)
    assert [g["id"] for g in gems] == list(range(1, len(gems) + 1)), "ids must be 1..n"

    # region: journal district, else nearest gem that has one; Dogtown is Dogtown
    for g in gems:
        if g["set"] == "dogtown":
            g["region"] = "Dogtown"
            continue
        jp = g.get("jpath", "")
        g["region"] = next(
            (
                v
                for k, v in REGION.items()
                if "/" + k + "/" in jp or jp.endswith("/" + k)
            ),
            None,
        )
    known = [g for g in gems if g["region"]]
    for g in gems:
        if not g["region"]:
            n = min(
                known, key=lambda k: (k["x"] - g["x"]) ** 2 + (k["y"] - g["y"]) ** 2
            )
            g["region"] = n["region"]
    by = collections.defaultdict(list)
    for g in gems:
        by[g["region"]].append(g)
    for reg, gs in by.items():
        cx = sum(g["x"] for g in gs) / len(gs)
        cy = sum(g["y"] for g in gs) / len(gs)
        zs = sorted(g["z"] for g in gs)
        zmed = zs[len(zs) // 2]
        spread = max(math.hypot(g["x"] - cx, g["y"] - cy) for g in gs) or 1.0
        for g in gs:
            dx, dy = g["x"] - cx, g["y"] - cy
            if math.hypot(dx, dy) < spread * 0.25:
                where = "near the middle"
            else:
                a = (
                    math.degrees(math.atan2(dy, dx)) + 360
                ) % 360  # +y = north, +x = east
                where = [
                    "east",
                    "north-east",
                    "north",
                    "north-west",
                    "west",
                    "south-west",
                    "south",
                    "south-east",
                ][int((a + 22.5) // 45) % 8] + " side"
            hz = (
                ", up high"
                if g["z"] - zmed > 20
                else (", down low" if g["z"] - zmed < -12 else "")
            )
            g["loc"] = "%s, %s%s" % (reg[0].upper() + reg[1:], where, hz)
    for g in gems:
        g.pop("jpath", None)
    out = os.path.join(R, "data", "gems.json")
    json.dump(gems, open(out, "w", encoding="utf-8"), indent=1)
    print("gems", len(gems), collections.Counter((g["set"], g["kind"]) for g in gems))


main()
