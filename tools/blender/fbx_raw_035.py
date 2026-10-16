# Minimal binary-FBX reader (validator): python3 -I tools/blender/fbx_raw_035.py file.fbx
# Prints, per mesh Geometry, the RAW vertex bounds as stored in the file (what Studio's importer reads) and the global axis/unit header.
import struct, sys, zlib


def read(path):
    d = open(path, "rb").read()
    ver = struct.unpack_from("<I", d, 23)[0]
    big = ver >= 7500
    pos = 27

    def node(p):
        if big:
            end, nprops, plen, nl = struct.unpack_from("<QQQB", d, p); p += 25
        else:
            end, nprops, plen, nl = struct.unpack_from("<IIIB", d, p); p += 13
        if end == 0:
            return None, p
        name = d[p:p + nl].decode(); p += nl
        props = []
        for _ in range(nprops):
            t = chr(d[p]); p += 1
            if t in "YCIFDL":
                fmt = {"Y": "<h", "C": "<?", "I": "<i", "F": "<f", "D": "<d", "L": "<q"}[t]
                props.append(struct.unpack_from(fmt, d, p)[0]); p += struct.calcsize(fmt)
            elif t in "fdlib":
                n, enc, clen = struct.unpack_from("<III", d, p); p += 12
                es = {"f": 4, "d": 8, "l": 8, "i": 4, "b": 1}[t]
                raw = d[p:p + clen]; p += clen
                if enc == 1:
                    raw = zlib.decompress(raw)
                props.append(struct.unpack("<%d%s" % (n, {"f": "f", "d": "d", "l": "q", "i": "i", "b": "b"}[t]), raw))
            elif t in "SR":
                n = struct.unpack_from("<I", d, p)[0]; p += 4
                props.append(d[p:p + n]); p += n
        kids = []
        while p < end:
            k, p = node(p)
            if k is None:
                break
            kids.append(k)
        return (name, props, kids), end

    out = []
    while pos < len(d) - 40:
        n, pos = node(pos)
        if n is None:
            break
        out.append(n)
    return out


def walk(nodes, name):
    for n in nodes:
        if n[0] == name:
            yield n
        yield from walk(n[2], name)


if __name__ == "__main__":
    nodes = read(sys.argv[1])
    for gs in walk(nodes, "GlobalSettings"):
        for p in walk([gs], "P"):
            if p[1] and isinstance(p[1][0], bytes) and p[1][0] in (b"UpAxis", b"UpAxisSign", b"FrontAxis", b"FrontAxisSign", b"CoordAxis", b"CoordAxisSign", b"UnitScaleFactor", b"OriginalUnitScaleFactor"):
                print("  header", p[1][0].decode(), p[1][-1])
    names = {}
    for m in walk(nodes, "Model"):
        names[m[1][0]] = m[1][1].split(b"\x00")[0].decode()
    for g in walk(nodes, "Geometry"):
        for v in walk([g], "Vertices"):
            a = v[1][0]
            xs, ys, zs = a[0::3], a[1::3], a[2::3]
            print("  %-34s x %9.3f..%9.3f  y %9.3f..%9.3f  z %9.3f..%9.3f" % (g[1][1].split(b"\x00")[0].decode()[:34], min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
