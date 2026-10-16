# kit035.char - one character: parts grouped by (group, colour), joints + idle/signature tracks, materials, FBX export.
#
# Naming (what Studio sees): <Model>_<Group>_<Colour>, one MeshPart per (group, colour). A group is either an R15 piece
# (Head, UpperTorso, LeftUpperArm, ...) or an extra rigid piece (Sword, Cape, Shield ...) that says which R15 part it is
# welded to (`on`) and which joints move it (`joints`, root -> leaf). Colours are plain Color3 / Material in Studio (no textures).
#
# Tracks (the SAME maths runs in Lua, CreatureAnim): weight w, then a transform about the joint's rest-frame pivot (frame A):
#   swing  rotate `amp` degrees * w about `axis`     push  move `amp` studs * w along axis      bob   move `amp` * w up
#   spin   rotate `amp` deg/s * t about axis         grow  scale along axis by 1 + (amp-1) * w   pop   uniform scale amp * w (hidden at rest)
#   continuous track: w = sin(t * speed + phase)
#   signature track (sig = {period, start, dur, shape, cycles}): u = ((t - start) mod period) / dur; outside 0..1 -> w = 0
#       strike: up to 1 by u=.55, slam to -.15 by .72, settle     u0: the move only starts at that fraction of dur
#       hump: sin(pi*u)     spring: sin(2*pi*cycles*u) * exp(-3u)     snap: sin(pi*u)^0.5 (fast out, soft in)
import json
import math
import os

import bpy
from mathutils import Matrix, Vector

from . import geo
from .geo import M, V

# name -> (hex, material, roughness, metallic). Material is the Roblox Material name; Neon parts glow.
BASE_PALETTE = {
    "Ink": ("#14141C", "SmoothPlastic", 0.45, 0),
    "White": ("#FFFFFF", "SmoothPlastic", 0.4, 0),
    "Blush": ("#FF9AA2", "SmoothPlastic", 0.6, 0),
    "Glow": ("#FFF2A8", "Neon", 0.2, 0),
}


def hexc(h):
    h = h.lstrip("#")
    lin = lambda c: ((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1)


def default_region(g):
    if g == "Head":
        return "head"
    if g == "UpperTorso":
        return "torso"
    if g == "LowerTorso":
        return "static"
    for side, key in (("Right", "armR"), ("Left", "armL")):
        if g.startswith(side) and any(p in g for p in ("Arm", "Hand")):
            return key
    return "legs"


class Char:
    def __init__(self, name, rarity, zone, scale=1.0, face="smile"):
        self.name, self.rarity, self.zone, self.scale = name, rarity, zone, scale
        self.palette = dict(BASE_PALETTE)
        self.parts = {}  # (group, colour) -> M
        self.groups = {}  # group -> {"on": R15 part, "joints": [joint names], "tier": None | "World" | "Captured"}
        self.joints = {}  # joint name -> track dict
        self.notes = []
        self.sig_label = ""

    # ---- palette / parts
    def colours(self, **kw):
        """colours(Steel=("#aab", "Metal", .3, .8), Blue="#2255cc") - a bare hex string = SmoothPlastic."""
        for k, v in kw.items():
            if isinstance(v, str):
                v = (v,)
            v = tuple(v)
            self.palette[k] = v + ("", "SmoothPlastic", 0.5, 0)[len(v) :]

    def group(self, name, on=None, region=None, tier=None, extra=None):
        """A rigid piece. on = the R15 part it is welded to; region (head torso armR armL legs static) picks the idle chain;
        extra = joint names appended after the idle chain (signature moves)."""
        if name not in self.groups:
            self.groups[name] = {"on": on or name, "region": region or default_region(name), "joints": [], "tier": tier, "extra": list(extra or [])}
        else:
            g = self.groups[name]
            g["on"] = on or g["on"]
            g["region"] = region or g["region"]
            if extra is not None:
                g["extra"] = list(extra)
        return name

    def add(self, group, colour, mesh, on=None, region=None, tier=None, extra=None):
        if group not in self.groups:
            self.group(group, on, region, tier, extra)
        elif on or region or extra is not None:
            self.group(group, on, region, None, extra)
        assert colour in self.palette, "unknown colour %s in %s" % (colour, self.name)
        key = (group, colour)
        if key in self.parts:
            self.parts[key].add(mesh)
        else:
            self.parts[key] = mesh.copy() if isinstance(mesh, M) else mesh
        return mesh

    def remove(self, *groups):
        """Drop the plain body meshes of groups an armour piece replaces entirely (saves triangles and parts)."""
        for g in groups:
            for k in [k for k in self.parts if k[0] == g]:
                del self.parts[k]

    def joint(self, name, pivot, kind="swing", axis="X", amp=0.0, speed=2.0, phase=0.0, sig=None):
        self.joints[name] = dict(pivot=tuple(pivot), kind=kind, axis=axis, amp=amp, speed=speed, phase=phase, sig=sig)

    def finish_anim(self, breath=0.035, head_sway=4.0, arm_sway=3.0):
        """Idle joints every character shares (breathing, a slow head look, arms swaying) + the chains for every group:
        idle chain of its region, then its `extra` signature joints."""
        from .body import jp

        self.joint("breath", (0, 3.0, 0), "bob", amp=breath, speed=2.2)
        self.joint("headIdle", jp("Neck"), "swing", "Y", head_sway, 0.9)
        self.joint("RshIdle", jp("Shoulder", 1), "swing", "X", arm_sway, 1.6)
        self.joint("LshIdle", jp("Shoulder", -1), "swing", "X", arm_sway, 1.6, math.pi)
        base = {"torso": ["breath"], "head": ["breath", "headIdle"], "armR": ["breath", "RshIdle"], "armL": ["breath", "LshIdle"], "legs": [], "static": []}
        for g, info in self.groups.items():
            info["joints"] = base[info["region"]] + info["extra"]

    def arm_sig(self, side, groups_lower=(), groups_hand=(), sh=None, el=None, wr=None):
        """Signature joints for one arm: every UpperArm piece gets [sh]; LowerArm pieces [sh, el]; hand / held gear [sh, el, wr]."""
        pre = "Right" if side > 0 else "Left"
        up = [g for g in self.groups if g.startswith(pre + "UpperArm")]
        lo = [g for g in self.groups if g.startswith(pre + "LowerArm")] + list(groups_lower)
        hd = [g for g in self.groups if g.startswith(pre + "Hand")] + list(groups_hand)
        for g in up:
            self.groups[g]["extra"] = [j for j in (sh,) if j]
        for g in lo:
            self.groups[g]["extra"] = [j for j in (sh, el) if j]
        for g in hd:
            self.groups[g]["extra"] = [j for j in (sh, el, wr) if j]

    # ---- stats
    def tris(self, state=None):
        return sum(m.tris() for (g, c), m in self.parts.items() if self._shown(g, state))

    def _shown(self, g, state):
        t = self.groups[g]["tier"]
        return t is None or state is None or t == state

    def part_count(self, state=None):
        return sum(1 for (g, c) in self.parts if self._shown(g, state))

    # ---- animation maths (frame A matrices)
    def weight(self, j, t):
        sg = j["sig"]
        if sg is None:
            return math.sin(t * j["speed"] + j["phase"])
        u = ((t - sg["start"]) % sg["period"]) / sg["dur"]
        if u >= 1.0:
            return 0.0
        u0 = sg.get("u0", 0.0)
        if u < u0:
            return 0.0
        u = (u - u0) / (1.0 - u0)
        sh = sg.get("shape", "hump")
        imp = sg.get("imp", -0.15)
        if sh == "strike":  # wind up to 1 by u=.55, slam to -.15 by u=.72, settle
            if u < 0.55:
                return math.sin(math.pi / 2 * u / 0.55)
            if u < 0.72:
                q = (u - 0.55) / 0.17
                return 1 - (1 - imp) * q * q * (3 - 2 * q)
            q = (u - 0.72) / 0.28
            return imp * (1 - q * q * (3 - 2 * q))
        if sh == "spring":
            return math.sin(2 * math.pi * sg.get("cycles", 2) * u) * math.exp(-3 * u)
        if sh == "snap":
            return math.sin(math.pi * u) ** 0.5
        if sh == "wave":
            return math.sin(math.pi * u) * math.sin(2 * math.pi * sg.get("cycles", 2) * u)
        return math.sin(math.pi * u)

    def joint_matrix(self, name, t):
        j = self.joints[name]
        w = self.weight(j, t)
        ax = {"X": V((1, 0, 0)), "Y": V((0, 1, 0)), "Z": V((0, 0, 1))}.get(j["axis"], V((1, 0, 0)))
        p = V(j["pivot"])
        T, Ti = Matrix.Translation(p), Matrix.Translation(-p)
        k = j["kind"]
        if k == "swing":
            return T @ Matrix.Rotation(math.radians(j["amp"] * w), 4, ax) @ Ti
        if k == "spin":
            return T @ Matrix.Rotation(math.radians(j["amp"] * t), 4, ax) @ Ti
        if k == "push":
            return Matrix.Translation(ax * (j["amp"] * w))
        if k == "bob":
            return Matrix.Translation(V((0, 1, 0)) * (j["amp"] * w))
        if k == "grow":
            f = 1 + (j["amp"] - 1) * w
            s = V((1, 1, 1)) + (f - 1) * V((abs(ax.x), abs(ax.y), abs(ax.z)))
            return T @ Matrix.Diagonal((s.x, s.y, s.z, 1)) @ Ti
        if k == "pop":
            f = max(j["amp"] * w, 0.001)
            return T @ Matrix.Diagonal((f, f, f, 1)) @ Ti
        return Matrix.Identity(4)

    def group_matrix(self, g, t):
        m = Matrix.Identity(4)
        for jn in self.groups[g]["joints"]:
            m = m @ self.joint_matrix(jn, t)
        return m

    # ---- Blender objects
    def build_objects(self, collection=None, only_state=None):
        mats = {}
        objs = {}
        for (g, c), mesh in sorted(self.parts.items()):
            if not self._shown(g, only_state):
                continue
            ob = geo.to_object("%s_%s_%s" % (self.name, g, c), mesh, collection=collection)
            if c not in mats:
                hx, mat, rough, metal = self.palette[c]
                m = bpy.data.materials.new("%s_%s" % (self.name, c))
                m.use_nodes = True
                b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                b.inputs["Base Color"].default_value = hexc(hx)
                b.inputs["Roughness"].default_value = rough
                b.inputs["Metallic"].default_value = 0.6 if mat == "Metal" else metal
                if mat == "Neon":
                    b.inputs["Emission Color"].default_value = hexc(hx)
                    b.inputs["Emission Strength"].default_value = 0.9
                mats[c] = m
            ob.data.materials.append(mats[c])
            ob["group"] = g
            objs[(g, c)] = ob
        self.objs = objs
        return objs

    def pose(self, t):
        for (g, c), ob in getattr(self, "objs", {}).items():
            mA = self.group_matrix(g, t)
            ob.matrix_basis = geo.A2B @ mA @ geo.A2B.inverted()

    # ---- reports
    SMALL = 0.9  # a mesh whose bounding-box diagonal is under this many studs (at scale 1) is "detail": hidden by the far-away lite version

    def is_detail(self, g, c):
        lo, hi = self.parts[(g, c)].bounds()
        return (V(hi) - V(lo)).length < self.SMALL

    def report(self):
        per = {"%s_%s_%s" % (self.name, g, c): m.tris() for (g, c), m in sorted(self.parts.items())}
        return {
            "model": self.name, "rarity": self.rarity, "zone": self.zone, "scale": self.scale,
            "tris": self.tris(), "meshparts": self.part_count(), "max_mesh_tris": max(per.values()),
            "tris_world": self.tris("World"), "parts_world": self.part_count("World"),
            "tris_captured": self.tris("Captured"), "parts_captured": self.part_count("Captured"),
            "tris_per_mesh": per,
            "tris_lite": sum(m.tris() for (g, c), m in self.parts.items() if self._shown(g, "World") and not self.is_detail(g, c) and self.groups[g]["tier"] is None),
            "parts_lite": sum(1 for (g, c) in self.parts if self.groups[g]["tier"] is None and not self.is_detail(g, c)),
            "detail_meshes": sum(1 for (g, c) in self.parts if self.is_detail(g, c)),
        }

    def data(self):
        """The Lua-side description (CreatureKitData): palette, groups (on / chain / tier / colours), joints, mesh names."""
        used = {c for (_, c) in self.parts}
        joints_used = set()
        groups = {}
        for g in sorted(self.groups):
            cols = sorted(c for (gg, c) in self.parts if gg == g)
            if not cols:
                continue
            info = self.groups[g]
            joints_used.update(info["joints"])
            groups[g] = {"on": info["on"], "colours": cols, "chain": info["joints"]}
            det = [c for c in cols if self.is_detail(g, c)]
            if det:
                groups[g]["detail"] = det
            if info["tier"]:
                groups[g]["tier"] = info["tier"]
        joints = {}
        for jn in sorted(joints_used):
            j = self.joints[jn]
            d = {"pivot": [round(x, 4) for x in j["pivot"]], "kind": j["kind"], "axis": j["axis"], "amp": round(j["amp"], 4)}
            if j["sig"]:
                d["sig"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in j["sig"].items()}
            else:
                d["speed"], d["phase"] = round(j["speed"], 4), round(j["phase"], 4)
            joints[jn] = d
        return {
            "scale": self.scale, "rarity": self.rarity, "tris": self.tris(), "parts": self.part_count(),
            "palette": {k: {"hex": v[0].lstrip("#"), "mat": v[1]} for k, v in sorted(self.palette.items()) if k in used},
            "groups": groups, "joints": joints,
        }
