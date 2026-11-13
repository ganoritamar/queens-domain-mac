"""Read/patch Steam appinfo.vdf (v29, string-table keys)."""
import hashlib, struct

class AppInfo:
    def __init__(self, path):
        self.path = path
        d = self.d = open(path, "rb").read()
        self.magic, self.universe, st_off = struct.unpack_from("<IIq", d, 0)
        assert self.magic == 0x07564429, hex(self.magic)
        n = struct.unpack_from("<I", d, st_off)[0]
        self.strings = d[st_off + 4:].split(b"\0")[:n]
        self.st_off = st_off
        self.entries = {}  # appid -> (offset, total_len)
        p = 16
        while p < st_off:
            appid, size = struct.unpack_from("<II", d, p)
            if appid == 0: break
            self.entries[appid] = (p, 8 + size)
            p += 8 + size
        self.end_marker = p

    def kv_of(self, appid):
        p, ln = self.entries[appid]
        hdr = self.d[p:p + 8 + 4 + 4 + 8 + 20 + 4 + 20]
        return hdr, self.d[p + len(hdr):p + ln]

    def parse(self, b, i=0):
        out = []
        while True:
            t = b[i]; i += 1
            if t == 8: return out, i
            k = self.strings[struct.unpack_from("<I", b, i)[0]].decode(); i += 4
            if t == 0:
                v, i = self.parse(b, i)
            elif t == 1:
                j = b.index(b"\0", i); v = b[i:j].decode("utf-8", "replace"); i = j + 1
            elif t == 2:
                v = ("i32", struct.unpack_from("<i", b, i)[0]); i += 4
            elif t == 7:
                v = ("u64", struct.unpack_from("<Q", b, i)[0]); i += 8
            elif t == 3:
                v = ("f32", struct.unpack_from("<f", b, i)[0]); i += 4
            else:
                raise ValueError(f"type {t} at {i}")
            out.append((k, v))

    def key(self, s):
        s = s.encode()
        if s not in self.strings: self.strings.append(s)
        return struct.pack("<I", self.strings.index(s))

    def dump(self, kv):
        b = b""
        for k, v in kv:
            if isinstance(v, list): b += b"\0" + self.key(k) + self.dump(v)
            elif isinstance(v, str): b += b"\1" + self.key(k) + v.encode() + b"\0"
            elif v[0] == "i32": b += b"\2" + self.key(k) + struct.pack("<i", v[1])
            elif v[0] == "u64": b += b"\7" + self.key(k) + struct.pack("<Q", v[1])
            elif v[0] == "f32": b += b"\3" + self.key(k) + struct.pack("<f", v[1])
        return b + b"\x08"

    def replace(self, appid, kv):
        p, ln = self.entries[appid]
        hdr, _ = self.kv_of(appid)
        body = self.dump(kv)
        hdr = bytearray(hdr)
        struct.pack_into("<I", hdr, 4, len(hdr) - 8 + len(body))
        hdr[len(hdr) - 20:] = hashlib.sha1(body).digest()
        self.d = self.d[:p] + bytes(hdr) + body + self.d[p + ln:]
        self.__dict__.update(AppInfo.__new__(AppInfo).__dict__)

    def save(self, path):
        d = self.d
        st_off = struct.unpack_from("<q", d, 8)[0]
        # recompute string table location: entries end at the 4-byte zero terminator
        p = 16
        while True:
            appid, size = struct.unpack_from("<II", d, p)
            if appid == 0: break
            p += 8 + size
        body = d[:p + 4]
        table = struct.pack("<I", len(self.strings)) + b"".join(s + b"\0" for s in self.strings)
        body = body[:8] + struct.pack("<q", len(body)) + body[16:]
        open(path, "wb").write(body + table)

def find(kv, *path):
    for k, v in kv:
        if k == path[0]:
            return v if len(path) == 1 else find(v, *path[1:])

def show(kv, ind=0):
    for k, v in kv:
        if isinstance(v, list): print(" " * ind + k); show(v, ind + 2)
        else: print(" " * ind + f"{k} = {v}")
