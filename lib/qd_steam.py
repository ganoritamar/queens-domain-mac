"""Mac Steam helpers for Queen's Domain (Steam app 1799840).

Usage: python3 qd_steam.py <command>
  has-app        exit 0 if Steam's app cache knows the game (you own it and Steam has saved its info)
  is-patched     exit 0 if Steam's copy of the game's settings already has the Mac entries
  patch          add the Mac entries (Steam must be closed)
  steamid        print the SteamID64 of the account last signed in to Steam
  gamedir        print the game's install folder (whichever Steam library it's in)
  has-manifest   exit 0 if Steam has started installing the game (an install record exists)
  installed      exit 0 if Steam has finished downloading the game
  steaminput-off turn off Steam Input for this game, so controllers reach the game (Steam must be closed)
Exit code 3 means Steam's files are in a format this script doesn't understand.

What "patch" changes in ~/Library/Application Support/Steam/appcache/appinfo.vdf:
  - the game's platform list gets "macos", so Mac Steam offers Install/Play
  - a Mac save-folder rule, so Steam Cloud syncs saves to ~/Library/Application Support/QueensDomain
  - a Mac launch entry that runs QueensDomainMac (a small script in the game folder)
Steam rewrites this file when the game updates; the launcher app re-applies the patch.
"""
import glob, os, re, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from appinfo import AppInfo, find

STEAM = os.path.expanduser("~/Library/Application Support/Steam")
APPINFO = os.path.join(STEAM, "appcache/appinfo.vdf")
APP = 1799840
EXE = "QueensDomain/Binaries/Win64/QueensDomain-Win64-Shipping.exe"


class FormatError(Exception):
    pass


def load():
    try:
        a = AppInfo(APPINFO)
        if APP not in a.entries:
            return a, None
        kv, _ = a.parse(a.kv_of(APP)[1], 0)
        return a, kv
    except (AssertionError, ValueError, IndexError, KeyError) as e:
        raise FormatError(f"appinfo.vdf: {e!r}")


def is_patched(kv):
    ai = find(kv, "appinfo")
    launch = find(ai, "config", "launch") or []
    return ("macos" in (find(ai, "common", "oslist") or "")
            and bool(find(ai, "ufs", "rootoverrides"))
            and any(find(e, "executable") == "QueensDomainMac" for _, e in launch))


def patch():
    a, kv = load()
    if kv is None:
        sys.exit("Steam doesn't know the game yet (not owned, or Steam hasn't saved its info).")
    if is_patched(kv):
        print("already patched"); return
    ai = find(kv, "appinfo")
    common, config, ufs = find(ai, "common"), find(ai, "config"), find(ai, "ufs")
    if common is None or config is None or find(config, "launch") is None:
        raise FormatError("game settings missing common/config/launch")
    if ufs is None:
        ai.append(("ufs", [])); ufs = find(ai, "ufs")
    if not any(k == "oslist" for k, _ in common):
        common.append(("oslist", "windows"))
    for i, (k, v) in enumerate(common):
        if k == "oslist" and "macos" not in v:
            common[i] = (k, v + ",macos")
    if not find(ufs, "rootoverrides"):
        ufs.append(("rootoverrides", [("0", [("root", "WinAppDataLocal"), ("os", "MacOS"),
                                              ("oscompare", "="), ("useinstead", "MacAppSupport")])]))
    launch = find(config, "launch")
    if not any(find(e, "executable") == "QueensDomainMac" for _, e in launch):
        for _, entry in launch:
            if not find(entry, "config"):
                entry.append(("config", [("oslist", "windows")]))
        # launch keys must be numbers or Steam ignores the entry
        n = max([int(k) for k, _ in launch if k.isdigit()] + [-1]) + 1
        launch.append((str(n), [("executable", "QueensDomainMac"), ("type", "default"),
                                ("config", [("oslist", "macos")])]))
    shutil.copy2(APPINFO, APPINFO + ".before-queensdomain")
    a.replace(APP, kv)
    a.save(APPINFO)
    a2, kv2 = load()  # read back what we wrote
    if kv2 is None or not is_patched(kv2) or len(a2.entries) != len(a.entries):
        shutil.copy2(APPINFO + ".before-queensdomain", APPINFO)
        raise FormatError("patched file didn't read back correctly; restored the original")
    print("patched")


# ---------- text .vdf files (loginusers, libraryfolders, localconfig) ----------

def vdf_parse(text):
    toks = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', text)
    pos = 0

    def block():
        nonlocal pos
        out = []
        while pos < len(toks):
            s, brace = toks[pos]
            if brace == "}":
                pos += 1; return out
            key = s; pos += 1
            s2, brace2 = toks[pos]
            if brace2 == "{":
                pos += 1; out.append([key, block()])
            else:
                pos += 1; out.append([key, s2])
        return out
    return block()


def vdf_dump(kv, ind=0):
    t = "\t" * ind; out = ""
    for k, v in kv:
        if isinstance(v, list):
            out += f'{t}"{k}"\n{t}{{\n{vdf_dump(v, ind + 1)}{t}}}\n'
        else:
            out += f'{t}"{k}"\t\t"{v}"\n'
    return out


def vget(kv, key, create=False):
    for item in kv:
        if item[0].lower() == key.lower() and isinstance(item[1], list):
            return item[1]
    if create:
        kv.append([key, []]); return kv[-1][1]
    return None


def steamid():
    txt = open(os.path.join(STEAM, "config/loginusers.vdf"), encoding="utf-8", errors="replace").read()
    users = vget(vdf_parse(txt), "users") or []
    best = None
    for sid, body in users:
        if not isinstance(body, list):
            continue
        d = {k: v for k, v in body if isinstance(v, str)}
        key = (d.get("MostRecent") == "1", int(d.get("Timestamp", d.get("timestamp", "0")) or 0))
        if best is None or key > best[0]:
            best = (key, sid)
    if not best:
        sys.exit("no Steam account found; sign in to Steam first")
    return best[1]


def libraries():
    libs = [STEAM]
    p = os.path.join(STEAM, "steamapps/libraryfolders.vdf")
    if os.path.exists(p):
        for _, body in vget(vdf_parse(open(p, encoding="utf-8", errors="replace").read()), "libraryfolders") or []:
            if isinstance(body, list):
                path = dict((k, v) for k, v in body if isinstance(v, str)).get("path")
                if path and path not in libs:
                    libs.append(path.replace("\\\\", "\\"))
    return libs


def manifest_path():
    for lib in libraries():
        m = os.path.join(lib, "steamapps", f"appmanifest_{APP}.acf")
        if os.path.exists(m):
            return lib, m
    return None, None


def gamedir():
    lib, _ = manifest_path()
    return os.path.join(lib or STEAM, "steamapps/common/QueensDomain")


def installed():
    lib, m = manifest_path()
    if not m:
        return False
    flags = re.search(r'"StateFlags"\s+"(\d+)"', open(m).read())
    return bool(flags) and int(flags[1]) & 4 and os.path.exists(os.path.join(gamedir(), EXE))


def steaminput_off():
    account = int(steamid()) - 76561197960265728
    p = os.path.join(STEAM, f"userdata/{account}/config/localconfig.vdf")
    if not os.path.exists(p):
        print("no localconfig yet; skipped"); return
    text = open(p, encoding="utf-8", errors="replace").read()
    kv = vdf_parse(text)
    store = vget(kv, "UserLocalConfigStore")
    if store is None:
        raise FormatError("localconfig.vdf has no UserLocalConfigStore")
    app = vget(vget(vget(vget(vget(store, "Software", True), "Valve", True), "Steam", True), "apps", True), str(APP), True)
    for item in app:
        if item[0] == "UseSteamControllerConfig":
            if item[1] == "0":
                print("already off"); return
            item[1] = "0"; break
    else:
        app.append(["UseSteamControllerConfig", "0"])
    shutil.copy2(p, p + f".before-queensdomain-{int(time.time())}")
    open(p, "w", encoding="utf-8").write(vdf_dump(kv))
    print("Steam Input off")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if cmd == "has-app":
            sys.exit(0 if os.path.exists(APPINFO) and load()[1] is not None else 1)
        elif cmd == "is-patched":
            kv = load()[1] if os.path.exists(APPINFO) else None
            sys.exit(0 if kv is not None and is_patched(kv) else 1)
        elif cmd == "patch":
            patch()
        elif cmd == "steamid":
            print(steamid())
        elif cmd == "gamedir":
            print(gamedir())
        elif cmd == "has-manifest":
            sys.exit(0 if manifest_path()[1] else 1)
        elif cmd == "installed":
            sys.exit(0 if installed() else 1)
        elif cmd == "steaminput-off":
            steaminput_off()
        else:
            sys.exit(__doc__)
    except FormatError as e:
        print(f"Steam's files are in a format this script doesn't understand ({e}).", file=sys.stderr)
        sys.exit(3)
