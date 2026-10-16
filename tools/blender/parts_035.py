# dev: lists the MeshParts (group x colour) and triangles of the Shield Knight benchmark (run inside Blender)
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
from kit035 import sk3, body
ch = sk3.shield_knight_v3()
rows = {}
for (g, c), m in ch.parts.items():
    rows.setdefault(g, []).append("%s:%d" % (c, m.tris()))
for g in sorted(rows):
    print("PART", g, " ".join(sorted(rows[g])))
print("PARTCOUNT", ch.part_count(), "TRIS", ch.tris())
