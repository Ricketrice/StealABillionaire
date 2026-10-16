# kit035.export - FBX export for Studio Import 3D, per-character reports, and the generated Lua data module.
#
# Axis + scale (verified against the Aquaris FBX by tools/blender/fbx_raw_035.py): Blender writes every Model with
# Lcl Rotation -90 deg X and Lcl Scaling = 100 (metres -> centimetres) unless global_scale compensates; Studio applies both and
# rotates 180 deg about Y (FBX front is +Z). Net: Studio = (-bx, bz, by) * Lcl scale = a pure rotation (no mirror), which is exactly
# geo.to_blender's inverse, so a part authored at A-frame x = +1 arrives at +X. The 100x came from Lcl Scaling, so we export with
# global_scale = 0.01 and the Models carry Lcl Scaling = 1 (checked after every export).
import json
import math
import os
import shutil
import sys

import bpy

from . import geo
from .geo import box

EXPORT_SCALE = 0.01


def markers(ch, collection):
    """Anchor (origin = ground under the feet) + three axis markers 1 stud out on the character's right (+X), up (+Y) and front (-Z):
    CreatureBuilder checks their offsets on import (scale, mirror, rotation) before it trusts the model."""
    out = []
    for nm, c in (("Anchor", (0, 0, 0)), ("AxisX", (1, 0, 0)), ("AxisY", (0, 1, 0)), ("AxisFront", (0, 0, -1))):
        out.append(geo.to_object("%s_%s" % (ch.name, nm), box(0.04, 0.04, 0.04, c=c), collection=collection))
    return out


def export_fbx(ch, path):
    bpy.ops.object.select_all(action="DESELECT")
    objs = list(ch.objs.values())
    for ob in objs:
        ob.matrix_basis.identity()
    mk = markers(ch, bpy.context.scene.collection)
    for ob in objs + mk:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=EXPORT_SCALE, apply_unit_scale=True,
                             bake_space_transform=False, mesh_smooth_type="FACE", add_leaf_bones=False, object_types={"MESH"})
    for ob in mk:
        bpy.data.objects.remove(ob, do_unlink=True)


def lua_value(v, ind=0):
    pad = "\t" * (ind + 1)
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = []
        for k in sorted(v, key=lambda x: str(x)):
            key = k if (isinstance(k, str) and k.isidentifier() and k not in ("end", "and", "or", "not", "nil", "true", "false", "if", "then", "else", "do", "for", "in", "local", "function", "return", "while", "repeat", "until", "break")) else "[%s]" % lua_value(k)
            items.append("%s%s = %s," % (pad, key, lua_value(v[k], ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + "\t" * ind + "}"
    if isinstance(v, (list, tuple)):
        if not v:
            return "{}"
        return "{ " + ", ".join(lua_value(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".") if v == v else "0"
    if isinstance(v, int):
        return str(v)
    if v is None:
        return "nil"
    return '"%s"' % str(v).replace('"', '\\"')


def write_lua(chars, path, header):
    data = {c.name: c.data() for c in chars}
    with open(path, "w") as f:
        f.write(header)
        f.write("return " + lua_value(data) + "\n")


def clean_data(d):
    """JSON-safe copy (tuples -> lists)."""
    return json.loads(json.dumps(d))
