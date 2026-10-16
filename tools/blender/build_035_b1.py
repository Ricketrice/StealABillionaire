# Batch B1 (Knight's Keep): builds the nine characters from the shared Standard body + knight kit, checks budgets, exports FBX,
# writes the data module and renders the preview tiles + idle/signature frames. Art only: nothing is imported into Studio from here.
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/build_035_b1.py -- [--only Name,Name] [--dev] [--full] [--res 480] [--no-anim]
#   python3 tools/blender/assemble_b1_035.py        (contact sheet, GIF/MP4 previews, phone-load report)
# --dev: a quick front / three-quarter / back / side set into ~/Pictures/035_preview/b1_dev (no export).
# --full: budgets + FBX (assets/export/035/b1 and ~/Documents/035) + data (src/ReplicatedStorage/CreatureKitData.lua) + tiles + frames
#         in ~/Pictures/035_preview/b1.
import json
import math
import os
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy
from mathutils import Vector as V

from kit035 import geo, studio, b1, export
import fbx_raw_035 as fbxraw

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
opt = {"only": None, "dev": False, "full": False, "res": 480, "anim": True}
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--only":
        opt["only"] = argv[i + 1].split(",")
        i += 1
    elif a == "--dev":
        opt["dev"] = True
    elif a == "--full":
        opt["full"] = True
    elif a == "--no-anim":
        opt["anim"] = False
    elif a == "--res":
        opt["res"] = int(argv[i + 1])
        i += 1
    i += 1

BUDGET = {"Common": (2000, 30), "Rare": (3000, 45), "Epic": (5000, 80), "Legendary": (8000, 150), "Secret": (12000, 250)}
DEV = os.path.expanduser("~/Pictures/035_preview/b1_dev")
PREV = os.path.expanduser("~/Pictures/035_preview/b1")
TILES = os.path.join(PREV, "tiles")
ANIM = os.path.join(PREV, "anim")
EXPORT_REPO = os.path.join(ROOT, "assets", "export", "035", "b1")
EXPORT_DOCS = os.path.expanduser("~/Documents/035")
LUA_OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "CreatureKitData.lua")
for d in (DEV, TILES, ANIM, EXPORT_REPO, EXPORT_DOCS):
    os.makedirs(d, exist_ok=True)
FPS, SECONDS = 18, 3.0
names = opt["only"] or list(b1.CHARS)


def sig_shift(ch):
    """Time shift so the signature starts at preview time 1.0 s (idle first, then the move)."""
    starts = [j["sig"]["start"] for j in ch.joints.values() if j["sig"]]
    return (min(starts) - 1.0) if starts else 0.0


def union_bounds(ch, times, state_objs):
    lo = V((1e9,) * 3)
    hi = V((-1e9,) * 3)
    for t in times:
        ch.pose(t)
        bpy.context.view_layer.update()
        l, h = studio.bounds(state_objs)
        lo = V((min(lo.x, l.x), min(lo.y, l.y), min(lo.z, l.z)))
        hi = V((max(hi.x, h.x), max(hi.y, h.y), max(hi.z, h.z)))
    ch.pose(0.0)
    return lo, hi


def show_tiers(ch, on_world, on_captured=False):
    for (g, c), ob in ch.objs.items():
        t = ch.groups[g]["tier"]
        if t == "World":
            ob.hide_render = not on_world
        elif t == "Captured":
            ob.hide_render = not on_captured


def center(lo, hi):
    return V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))


reports = []
for name in names:
    ch = b1.CHARS[name]()
    sc = studio.setup(opt["res"])
    ch.build_objects()
    ch.pose(0.0)
    tri_cap, part_cap = BUDGET[ch.rarity]
    rep = ch.report()
    worst_t = max(rep["tris"], rep["tris_world"] if rep["parts_world"] else 0)
    state_t = max(ch.tris("World"), ch.tris("Captured"), ch.tris(None))
    state_p = max(ch.part_count("World"), ch.part_count("Captured"))
    rep.update(tri_budget=tri_cap, part_budget=part_cap, tris_all=ch.tris(), parts_all=ch.part_count(),
               tris_ok=ch.tris("World") <= tri_cap and ch.tris("Captured") <= tri_cap,
               parts_ok=ch.part_count("World") <= part_cap and ch.part_count("Captured") <= part_cap, sig=ch.sig_label)
    # visible-state numbers: the model as seen in the world (World tier shown) / carried (Captured tier shown)
    rep["tris_world_state"], rep["parts_world_state"] = ch.tris("World"), ch.part_count("World")
    rep["tris_captured_state"], rep["parts_captured_state"] = ch.tris("Captured"), ch.part_count("Captured")
    print("CHAR %-14s %-9s tris world %5d / captured %5d (cap %5d)  parts world %3d / captured %3d (cap %3d)  max mesh %d  %s" % (
        name, ch.rarity, rep["tris_world_state"], rep["tris_captured_state"], tri_cap, rep["parts_world_state"], rep["parts_captured_state"], part_cap, rep["max_mesh_tris"],
        "OK" if rep["tris_ok"] and rep["parts_ok"] else "OVER BUDGET"))
    reports.append(rep)
    show_tiers(ch, False)
    vis = [ob for (g, c), ob in ch.objs.items() if ch.groups[g]["tier"] is None]
    lo, hi = studio.bounds(vis)
    tgt, d = center(lo, hi), studio.fit_dist(lo, hi, margin=1.08)
    if opt["dev"]:
        for tag, az, el in (("front", 0, 8), ("tq", -35, 14), ("back", 180, 8), ("side", 90, 6)):
            studio.aim(sc, tgt, az, el, d)
            studio.shoot(sc, os.path.join(DEV, "%s_%s.png" % (name, tag)))
        continue
    if not opt["full"]:
        continue

    # ---- tiles (static model, FX hidden)
    for tag, az, el in (("front", 0, 8), ("tq", -35, 14), ("back", 180, 8)):
        studio.aim(sc, tgt, az, el, d)
        studio.shoot(sc, os.path.join(TILES, "%s_%s.png" % (name, tag)), 480)
    studio.aim(sc, tgt, -35, 14, d * 0.8)
    studio.shoot(sc, os.path.join(TILES, "%s_icon.png" % name), 128)
    has_fx = any(info["tier"] for info in ch.groups.values())
    if has_fx:
        show_tiers(ch, True, False)
        allv = list(ch.objs.values())
        flo, fhi = studio.bounds(allv)
        studio.aim(sc, center(flo, fhi), -35, 18, studio.fit_dist(flo, fhi, margin=1.05))
        studio.shoot(sc, os.path.join(TILES, "%s_fx.png" % name), 480)
        show_tiers(ch, False)
    # ---- scale against the game rig's classic noob (the character at its spec.scale)
    root = bpy.data.objects.new("ScaleRoot", None)
    bpy.context.scene.collection.objects.link(root)
    for ob in vis:
        ob.parent = root
    root.scale = (ch.scale,) * 3
    bpy.context.view_layer.update()
    slo, shi = studio.bounds(vis)
    half = max(abs(slo.x), abs(shi.x))
    noob = studio.noob_objects(-(half + 1.6))
    bpy.context.view_layer.update()
    nlo, nhi = studio.bounds(noob)
    alo, ahi = V((min(slo.x, nlo.x), min(slo.y, nlo.y), 0)), V((max(shi.x, nhi.x), max(shi.y, nhi.y), max(shi.z, nhi.z)))
    studio.aim(sc, center(alo, ahi), 0, 5, studio.fit_dist(alo, ahi, margin=1.1))
    studio.shoot(sc, os.path.join(TILES, "%s_scale.png" % name), 480)
    for ob in noob:
        bpy.data.objects.remove(ob, do_unlink=True)
    for ob in vis:
        ob.parent = None
        ob.matrix_basis.identity()
    bpy.data.objects.remove(root, do_unlink=True)
    bpy.context.view_layer.update()

    # ---- idle + signature frames (World state shown), fixed camera over the union of the poses
    if opt["anim"]:
        show_tiers(ch, True, False)
        allv = list(ch.objs.values())
        shift = sig_shift(ch)
        times = [k / FPS + shift for k in range(int(FPS * SECONDS))]
        alo, ahi = union_bounds(ch, times[::3], allv)
        studio.aim(sc, center(alo, ahi), -32, 12, studio.fit_dist(alo, ahi, margin=1.04))
        outd = os.path.join(ANIM, name)
        os.makedirs(outd, exist_ok=True)
        for k, t in enumerate(times):
            ch.pose(t)
            studio.shoot(sc, os.path.join(outd, "f%03d.png" % k), 360)
        ch.pose(0.0)
        show_tiers(ch, False)

    # ---- export (rest pose, all tiers)
    show_tiers(ch, True, True)
    fbx = os.path.join(EXPORT_REPO, name + ".fbx")
    export.export_fbx(ch, fbx)
    shutil.copy(fbx, os.path.join(EXPORT_DOCS, name + ".fbx"))
    nodes = fbxraw.read(fbx)
    models = {m[1][1].split(b"\x00")[0].decode(): m for m in fbxraw.walk(nodes, "Model")}
    bad = []
    for mn, m in models.items():
        for p in fbxraw.walk([m], "P"):
            if p[1] and p[1][0] == b"Lcl Scaling" and abs(p[1][4] - 1.0) > 1e-6:
                bad.append((mn, "Lcl Scaling", p[1][4]))
            if p[1] and p[1][0] == b"Lcl Rotation" and abs(p[1][4] + 90.0) > 1e-3:
                bad.append((mn, "Lcl Rotation", p[1][4]))
    want = {"%s_%s_%s" % (name, g, c) for (g, c) in ch.parts} | {"%s_%s" % (name, m) for m in ("Anchor", "AxisX", "AxisY", "AxisFront")}
    missing = sorted(want - set(models))
    extra = sorted(set(models) - want)
    rep["fbx"] = {"models": len(models), "expected": len(want), "missing": missing, "extra": extra, "bad_transform": bad[:3], "ok": not (bad or missing or extra)}
    print("  FBX %s: %d models, %s" % (name, len(models), "OK (Lcl Scaling 1, rotation -90)" if rep["fbx"]["ok"] else "PROBLEM %s" % rep["fbx"]))

if opt["full"]:
    chars = [b1.CHARS[n]() for n in names]
    hdr = ("-- Studio location: ReplicatedStorage.CreatureKitData (ModuleScript)\n"
           "-- GENERATED by tools/blender/build_035_b1.py from the Blender kit (do not edit by hand): per model, the palette (Color / Material), the\n"
           "-- groups (one MeshPart per group x colour named <Model>_<Group>_<Colour>; `on` = the R15 part it is welded to; `chain` = the joints that\n"
           "-- move it, root first) and the joints (pivot in kit space = ground under the feet, kind swing/push/bob/spin/grow/pop; `sig` = a\n"
           "-- signature move that plays once every `period` seconds). Read by CreatureBuilder (kit models) and CreatureAnim.\n")
    export.write_lua(chars, LUA_OUT, hdr)
    with open(os.path.join(EXPORT_REPO, "B1_report.json"), "w") as f:
        json.dump(reports, f, indent=1)
    print("B1_DONE", len(reports), "characters")
