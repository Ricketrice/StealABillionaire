"""Lists (and optionally extracts) the scripts in a binary .rbxl place file.
rbxl_scripts.py place.rbxl --export src   writes every live script into src/ (see export_all).
usage: rbxl_scripts.py place.rbxl [outdir name1 name2 ...]"""
import struct, sys, os

def lz4_block(src, size):
    out = bytearray(); i = 0; n = len(src)
    while i < n:
        token = src[i]; i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255: break
        out += src[i:i + lit]; i += lit
        if i >= n: break
        offset = src[i] | (src[i + 1] << 8); i += 2
        mlen = token & 15
        if mlen == 15:
            while True:
                b = src[i]; i += 1; mlen += b
                if b != 255: break
        mlen += 4
        start = len(out) - offset
        for k in range(mlen):
            out.append(out[start + k])
    assert len(out) == size, (len(out), size)
    return bytes(out)

def chunks(data):
    assert data[:8] == b"<roblox!", "not a binary place file"
    pos = 32
    while pos < len(data):
        name = data[pos:pos + 4]; clen, ulen = struct.unpack_from("<II", data, pos + 4); pos += 16
        if clen == 0:
            body = data[pos:pos + ulen]; pos += ulen
        else:
            raw = data[pos:pos + clen]; pos += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                import zstandard
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                body = lz4_block(raw, ulen)
        yield name, body
        if name == b"END\x00": break

def interleaved(body, pos, count):
    vals = []
    for i in range(count):
        v = 0
        for b in range(4):
            v = (v << 8) | body[pos + b * count + i]
        vals.append((v >> 1) ^ -(v & 1))
    return vals, pos + 4 * count

def rstr(body, pos):
    (n,) = struct.unpack_from("<I", body, pos)
    return body[pos + 4:pos + 4 + n], pos + 4 + n

def load(path):
    data = open(path, "rb").read()
    classes, name, source, parent = {}, {}, {}, {}
    for cname, body in chunks(data):
        if cname == b"INST":
            (cid,) = struct.unpack_from("<i", body, 0)
            cls, pos = rstr(body, 4)
            pos += 1
            (count,) = struct.unpack_from("<i", body, pos); pos += 4
            refs, pos = interleaved(body, pos, count)
            acc = 0; ids = []
            for r in refs:
                acc += r; ids.append(acc)
            classes[cid] = (cls.decode(), ids)
        elif cname == b"PROP":
            (cid,) = struct.unpack_from("<i", body, 0)
            prop, pos = rstr(body, 4)
            typ = body[pos]; pos += 1
            if typ == 1 and prop in (b"Name", b"Source"):
                cls, ids = classes[cid]
                for ref in ids:
                    s, pos = rstr(body, pos)
                    (name if prop == b"Name" else source)[ref] = s.decode("utf-8", "replace")
        elif cname == b"PRNT":
            (count,) = struct.unpack_from("<i", body, 1)
            kids, pos = interleaved(body, 5, count)
            pars, pos = interleaved(body, pos, count)
            a = b = 0
            for k, p in zip(kids, pars):
                a += k; b += p
                parent[a] = b
    cls_of = {ref: cls for cls, ids in classes.values() for ref in ids}
    def path(ref):
        parts = []
        while ref in name and ref != -1:
            parts.append(name[ref]); ref = parent.get(ref, -1)
        return ".".join(reversed(parts))
    return {path(r): (cls_of[r], source[r]) for r in source if cls_of[r] in ("Script", "LocalScript", "ModuleScript")}


SKIP = ("_Backups", "_DevOnly._WorkerLineup")


def export_all(scripts, out):
    """Writes every live script (not backups, not the stock Animate copies inside rigs) to
    out/<Service>/<Path>/<Name>.lua with the push_to_studio.py header line."""
    n = 0
    for p, (cls, src) in sorted(scripts.items()):
        if any(k in p for k in SKIP) or p.endswith(".Animate"):
            continue
        parts = p.split(".")
        fn = os.path.join(out, *parts[:-1], parts[-1] + ".lua")
        os.makedirs(os.path.dirname(fn), exist_ok=True)
        with open(fn, "w", encoding="utf-8") as f:
            f.write("-- Studio location: %s (%s)\n" % (p, cls) + src.replace("\r\n", "\n"))
        n += 1
    print("exported", n, "scripts to", out)


def main():
    scripts = load(sys.argv[1])
    if len(sys.argv) > 3 and sys.argv[2] == "--export":
        export_all(scripts, sys.argv[3])
    elif len(sys.argv) > 2:
        out = sys.argv[2]; os.makedirs(out, exist_ok=True)
        for want in sys.argv[3:]:
            hits = [p for p in scripts if p == want or (p.endswith("." + want.split(".")[-1]) and want in p)]
            hits = [p for p in hits if "_Backups" not in p]
            assert len(hits) == 1, (want, hits)
            fn = os.path.join(out, hits[0].split(".", 1)[1].replace(".", "__") + ".lua") if want.count(".") > 1 and hits[0].split(".")[-1] in ("ClientHelper",) else os.path.join(out, hits[0].split(".")[-1] + ".lua")
            cls, src = scripts[hits[0]]
            open(fn, "w").write("-- Studio location: %s (%s)\n" % (hits[0], cls) + src.replace("\r\n", "\n") + ("" if src.endswith("\n") else "\n"))
            print("wrote %s  (%d lines)" % (os.path.relpath(fn), src.count("\n") + 1))
    else:
        live = [p for p in scripts if "_Backups" not in p and "_DevOnly._WorkerLineup" not in p]
        print("scripts:", len(scripts), "| live scripts:", len(live))
        for p in sorted(live):
            print("  %-70s %5d lines" % (p, scripts[p][1].count("\n") + 1))

if __name__ == "__main__":
    main()
