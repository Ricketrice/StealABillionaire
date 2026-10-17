import bpy, os, json
bpy.ops.wm.open_mainfile(filepath=os.path.expanduser("~/Pictures/035_preview/vault/vault_inspect_copy.blend"))
sc = bpy.context.scene; objs = bpy.data.objects
NAMES = ["LeftHand", "RightFoot", "Head", "LedgerScepter", "UpperTorso", "LeftFoot"]
out = {}
rest = {o.name: (o.rotation_quaternion.copy(), o.location.copy(), o.scale.copy()) for o in objs}
for c, fr in {"Walk": [1, 8, 15, 22], "Normal_Repossess": [1, 12, 23, 34], "Event_BankruptNova": [1, 20, 39, 58]}.items():
    for o in objs:
        o.rotation_quaternion, o.location, o.scale = rest[o.name][0].copy(), rest[o.name][1].copy(), rest[o.name][2].copy()
        ad = o.animation_data
        if ad:
            ad.action = None
            for t in ad.nla_tracks: t.mute = t.name != c
    for f in fr:
        sc.frame_set(f); out["%s@%d" % (c, f)] = {n: list(objs[n].matrix_world.translation) for n in NAMES}
json.dump(out, open(os.path.expanduser("~/Pictures/035_preview/vault/convert/blender_pose_dump.json"), "w"))
