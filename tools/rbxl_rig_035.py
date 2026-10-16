"""Read-only: prints the R15 rig numbers of a model in a binary .rbxl (HipHeight, part sizes, positions) so rig changes can be checked offline.
usage: python3 -I tools/rbxl_rig_035.py place.rbxl ServerStorage.NPCModels.MysteryNPC"""
import struct, sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from rbxl_scripts import chunks, interleaved, rstr


def fl(body, pos, count):
    vals = []
    for i in range(count):
        u = 0
        for b in range(4):
            u = (u << 8) | body[pos + b * count + i]
        u = ((u >> 1) | ((u & 1) << 31)) & 0xFFFFFFFF
        vals.append(struct.unpack("<f", struct.pack("<I", u))[0])
    return vals, pos + 4 * count


def main(path, want):
    data = open(path, "rb").read()
    classes, props, parent, name = {}, {}, {}, {}
    for cname, body in chunks(data):
        if cname == b"INST":
            (cid,) = struct.unpack_from("<i", body, 0)
            cls, pos = rstr(body, 4)
            pos += 1
            (count,) = struct.unpack_from("<i", body, pos); pos += 4
            refs, pos = interleaved(body, pos, count)
            acc, ids = 0, []
            for r in refs:
                acc += r; ids.append(acc)
            classes[cid] = (cls.decode(), ids)
        elif cname == b"PROP":
            (cid,) = struct.unpack_from("<i", body, 0)
            prop, pos = rstr(body, 4)
            typ = body[pos]; pos += 1
            cls, ids = classes[cid]
            n = len(ids)
            pn = prop.decode()
            if typ == 1 and pn == "Name":
                for ref in ids:
                    s, pos = rstr(body, pos); name[ref] = s.decode("utf-8", "replace")
            elif typ == 4 and pn == "HipHeight":
                v, pos = fl(body, pos, n)
                for r, x in zip(ids, v): props[(r, pn)] = x
            elif typ == 14 and pn in ("Size", "size"):
                xs, pos = fl(body, pos, n); ys, pos = fl(body, pos, n); zs, pos = fl(body, pos, n)
                for i, r in enumerate(ids): props[(r, "Size")] = (round(xs[i], 3), round(ys[i], 3), round(zs[i], 3))
            elif typ == 16 and pn == "CFrame":
                rots = []
                for i in range(n):
                    rid = body[pos]; pos += 1
                    if rid == 0:
                        pos += 36
                    rots.append(rid)
                xs, pos = fl(body, pos, n); ys, pos = fl(body, pos, n); zs, pos = fl(body, pos, n)
                for i, r in enumerate(ids): props[(r, "Pos")] = (round(xs[i], 3), round(ys[i], 3), round(zs[i], 3))
        elif cname == b"PRNT":
            (count,) = struct.unpack_from("<i", body, 1)
            kids, pos = interleaved(body, 5, count)
            pars, pos = interleaved(body, pos, count)
            a = b = 0
            for k, p in zip(kids, pars):
                a += k; b += p; parent[a] = b
    cls_of = {r: c for c, ids in classes.values() for r in ids}

    def path_of(r):
        out = []
        while r in name and r != -1:
            out.append(name[r]); r = parent.get(r, -1)
        return ".".join(reversed(out))

    roots = [r for r in name if path_of(r) == want]
    assert roots, "model not found: " + want
    root = roots[0]
    for r in sorted(name):
        p = r
        chain = []
        while p in parent and p != -1:
            chain.append(p); p = parent[p]
        if root in chain:
            print("%-14s %-18s size=%s pos=%s hip=%s" % (cls_of[r], name[r], props.get((r, "Size")), props.get((r, "Pos")), props.get((r, "HipHeight"))))


main(sys.argv[1], sys.argv[2])
