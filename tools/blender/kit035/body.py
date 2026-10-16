# kit035.body - the Standard body (normal1 quality: a Roblox build with bevelled, slightly tapered pieces) and the part-built faces.
# The 15 visible pieces sit on the SAME joints as the hidden R15 rig that CreatureBuilder re-proportions
# (torso 2x2x1, arms/legs 1x2x1, head 1.2 tall): hips y=2.0, knees 1.1, ankles 0.35, shoulders y=3.7 at x=+-1.5, elbows 3.1,
# wrists 2.3, neck 4.0, waist 2.4. So pieces rotate about the right places when the walk animation moves the hidden rig.
import math

from . import geo
from .geo import M, V, box, frustum, ellipsoid, lathe, tube, poly_slab, ellipse_slab, merge

RIG = {  # rig part centres (kit frame, scale 1): used for pivots and for builder checks
    "LowerTorso": (0, 2.2, 0), "UpperTorso": (0, 3.2, 0), "Head": (0, 4.6, 0),
    "RightUpperArm": (1.5, 3.55, 0), "RightLowerArm": (1.5, 2.7, 0), "RightHand": (1.5, 2.15, 0),
    "LeftUpperArm": (-1.5, 3.55, 0), "LeftLowerArm": (-1.5, 2.7, 0), "LeftHand": (-1.5, 2.15, 0),
    "RightUpperLeg": (0.5, 1.55, 0), "RightLowerLeg": (0.5, 0.725, 0), "RightFoot": (0.5, 0.175, -0.1),
    "LeftUpperLeg": (-0.5, 1.55, 0), "LeftLowerLeg": (-0.5, 0.725, 0), "LeftFoot": (-0.5, 0.175, -0.1),
}
JOINT = {  # joint positions (kit frame)
    "Shoulder": (1.5, 3.7, 0), "Elbow": (1.5, 3.1, 0), "Wrist": (1.5, 2.3, 0), "Hip": (0.5, 2.0, 0), "Knee": (0.5, 1.1, 0), "Ankle": (0.5, 0.35, 0),
    "Neck": (0, 4.0, 0), "Waist": (0, 2.4, 0),
}
PIECES = ["Head", "UpperTorso", "LowerTorso"] + [s + p for s in ("Left", "Right") for p in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]


class Skel:
    """Joint heights of the hidden R15 skeleton a kit model is built on. DEFAULT = the game's noob rig (B1). HERO = the heroic proportions of the
    redesign (longer legs and arms, a taller torso, a slimmer head relative to the body): the visible shapes never have to match R15 boxes,
    only these joints. CreatureBuilder re-proportions the invisible rig from the same numbers (written to CreatureKitData as `rig`)."""

    def __init__(self, ankle, knee, hip, waist, shoulder_y, neck, elbow, wrist, hand_end, arm_x=1.5, leg_x=0.5, head_h=1.2, foot_h=0.35):
        self.ankle, self.knee, self.hip, self.waist, self.shoulder_y, self.neck, self.elbow, self.wrist, self.hand_end = ankle, knee, hip, waist, shoulder_y, neck, elbow, wrist, hand_end
        self.arm_x, self.leg_x, self.head_h, self.foot_h = arm_x, leg_x, head_h, foot_h

    def joint(self, name, side=1):
        return {
            "Shoulder": (self.arm_x * side, self.shoulder_y, 0), "Elbow": (self.arm_x * side, self.elbow, 0), "Wrist": (self.arm_x * side, self.wrist, 0),
            "Hip": (self.leg_x * side, self.hip, 0), "Knee": (self.leg_x * side, self.knee, 0), "Ankle": (self.leg_x * side, self.ankle, 0),
            "Neck": (0, self.neck, 0), "Waist": (0, self.waist, 0),
        }[name]

    def data(self):
        return {k: getattr(self, k) for k in ("ankle", "knee", "hip", "waist", "shoulder_y", "neck", "elbow", "wrist", "hand_end", "arm_x", "leg_x", "head_h", "foot_h")}


DEFAULT = Skel(0.35, 1.1, 2.0, 2.4, 3.7, 4.0, 3.1, 2.3, 2.0, 1.5, 0.5, 1.2, 0.35)
HERO = Skel(0.4, 1.55, 2.75, 3.1, 4.4, 4.7, 3.5, 2.6, 2.2, 1.68, 0.5, 1.3, 0.4)
SKEL = DEFAULT


def set_skel(sk):
    global SKEL
    SKEL = sk


def jp(name, side=1):
    return SKEL.joint(name, side)


class Head:
    """Head geometry numbers (so hats, hair and faces fit): bottom y0, height H, widths and depths at bottom/top."""

    def __init__(self, hs=1.0, wide=1.0, y0=3.98):
        self.hs = hs
        self.y0 = y0
        self.H = 1.3 * hs
        self.w0, self.d0, self.w1, self.d1 = 1.3 * hs * wide, 1.2 * hs, 1.5 * hs * wide, 1.34 * hs
        self.top = self.y0 + self.H

    def cy(self):
        return self.y0 + self.H / 2

    def zf(self, y):
        """front surface z (negative) at height y"""
        k = (y - self.y0) / self.H
        return -(self.d0 / 2 + (self.d1 - self.d0) / 2 * k)

    def hw(self, y):
        k = (y - self.y0) / self.H
        return (self.w0 / 2 + (self.w1 - self.w0) / 2 * k)

    def at(self, k):
        """height at fraction k (0 chin .. 1 crown)"""
        return self.y0 + self.H * k


def standard_body(ch, cols, build=None, head=None, q=1):
    """Adds the 15 body pieces. cols maps piece kinds to palette colours:
    Head UpperTorso LowerTorso UpperArm LowerArm Hand UpperLeg LowerLeg Foot (+ "Left"/"Right" prefixed overrides)."""
    b = dict(bw=1.0, bd=1.0, aw=1.0, lw=1.0)
    b.update(build or {})
    hd = head or Head()
    bw, bd, aw, lw = b["bw"], b["bd"], b["aw"], b["lw"]
    sl = 1 if q <= 1 else 2  # limb bevel segments: Common/Rare chamfer (smooth-shaded), Epic and up rounder
    st = 2 if q <= 2 else 3  # head / torso

    def col(piece):
        return cols.get(piece) or cols[piece.replace("Left", "").replace("Right", "")]

    ch.add("Head", col("Head"), frustum(hd.y0, hd.top, hd.w0, hd.d0, hd.w1, hd.d1, bev=0.36 * hd.hs, seg=st))
    ch.add("UpperTorso", col("UpperTorso"), frustum(2.38, 4.0, 1.72 * bw, 0.88 * bd, 2.0 * bw, 1.0 * bd, bev=0.12, seg=st))
    ch.add("LowerTorso", col("LowerTorso"), frustum(2.0, 2.44, 1.86 * bw, 0.92 * bd, 1.8 * bw, 0.9 * bd, bev=0.09, seg=sl))
    for side, sx in (("Right", 1), ("Left", -1)):
        up = frustum(3.08, 4.0, 0.86 * aw, 0.86 * aw, 0.97 * aw, 0.97 * aw, bev=0.1, seg=sl).move(1.5)
        lo = frustum(2.28, 3.1, 0.74 * aw, 0.74 * aw, 0.86 * aw, 0.86 * aw, bev=0.09, seg=sl).move(1.5)
        hand = box(0.7 * aw, 0.42, 0.72 * aw, bev=0.14, seg=sl, c=(1.5, 2.1, 0))
        ul = frustum(1.08, 2.02, 0.84 * lw, 0.88 * lw, 0.93 * lw, 0.96 * lw, bev=0.1, seg=sl).move(0.5)
        ll = frustum(0.34, 1.1, 0.76 * lw, 0.8 * lw, 0.84 * lw, 0.88 * lw, bev=0.09, seg=sl).move(0.5)
        foot = box(0.88 * lw, 0.42, 1.26, bev=0.15, seg=sl, c=(0.5, 0.21, -0.14))
        for nm, m in (("UpperArm", up), ("LowerArm", lo), ("Hand", hand), ("UpperLeg", ul), ("LowerLeg", ll), ("Foot", foot)):
            m = m.copy()
            if sx < 0:
                m.mirror_x()
            ch.add(side + nm, col(side + nm), m, on=side + nm)
    return hd


# ------------------------------------------------------------------ faces (part-built, sculpted onto the head front)
def _lr(ch, colour, mesh_r, group="Head", mirror=True):
    ch.add(group, colour, mesh_r)
    if mirror:
        ch.add(group, colour, mesh_r.copy().mirror_x())


def face(ch, hd, expr="smile", blush=False, eye_r=(0.17, 0.235), glint=True, brow="Ink", eye_dx=0.36, mouth_w=0.3, eye_n=10, smooth_mouth=False, brow_scale=1.0, eye_k=0.62, brow_dy=0.3):
    """Part-built face on the head front (flat discs and bars, backs omitted): ~200 triangles."""
    s = hd.hs
    ey = hd.at(eye_k)
    my = hd.at(0.27)
    zf = hd.zf
    er = (eye_r[0] * s, eye_r[1] * s)
    shape = {"surprised": (1.15, 1.1), "sleepy": (1.0, 0.55)}.get(expr, (1.0, 1.0))
    _lr(ch, "Ink", ellipse_slab(er[0] * shape[0], er[1] * shape[1], 0.05, eye_n, (eye_dx * s, ey, zf(ey) - 0.02)))
    if glint:
        _lr(ch, "White", ellipse_slab(0.06 * s, 0.08 * s, 0.03, 5, (eye_dx * s + 0.05 * s, ey + 0.08 * s, zf(ey) - 0.05)))
    brow_y = ey + brow_dy * s
    tilt = {"smile": 6, "grin": 10, "worried": -22, "determined": 24, "stern": 28, "surprised": 14, "smirk": 10, "sleepy": -6, "shout": 30}.get(expr, 0)
    lift = {"surprised": 0.1, "worried": 0.04, "shout": -0.03}.get(expr, 0)
    bm = box(0.4 * s * brow_scale, 0.075 * s * brow_scale, 0.06, c=(eye_dx * s, brow_y + lift * s, zf(brow_y) - 0.03)).rot(0, 0, tilt, (eye_dx * s, brow_y, 0))
    _lr(ch, brow if brow in ch.palette else "Ink", bm)
    mz = zf(my) - 0.015
    if expr in ("smile", "smirk", "determined", "worried", "sleepy"):
        sag = {"smile": 0.1, "smirk": 0.07, "determined": 0.03, "worried": -0.05, "sleepy": 0.04}[expr]
        skew = 0.05 if expr == "smirk" else 0
        pts = [(-mouth_w * s, my + 0.04 * s - skew, mz), (-mouth_w * 0.5 * s, my - sag * 0.8 * s, mz), (0, my - sag * s, mz), (mouth_w * 0.5 * s, my - sag * 0.8 * s + skew, mz), (mouth_w * s, my + 0.04 * s + skew * 2, mz)] if smooth_mouth else [(-mouth_w * s, my + 0.04 * s - skew, mz), (0, my - sag * s, mz), (mouth_w * s, my + 0.04 * s + skew * 2, mz)]
        ch.add("Head", "Ink", tube(pts, 0.035 * s, seg=4, caps=(False, False)))
    elif expr in ("flat", "stern"):
        ch.add("Head", "Ink", box(0.44 * s, 0.07 * s, 0.05, c=(0, my, mz)))
    elif expr in ("grin", "shout"):
        n = 6
        outline = [(0.32 * s, my + 0.1 * s)] + [(0.32 * s * math.cos(math.pi * i / n), my + 0.1 * s - 0.3 * s * math.sin(math.pi * i / n)) for i in range(1, n)] + [(-0.32 * s, my + 0.1 * s)]
        ch.add("Head", "Ink", poly_slab(outline, 0.06, c=(0, 0, mz), back=False))
        ch.add("Head", "White", box(0.5 * s, 0.07 * s, 0.04, c=(0, my + 0.07 * s, mz - 0.03)))
    elif expr == "surprised":
        ch.add("Head", "Ink", ellipse_slab(0.1 * s, 0.13 * s, 0.05, 8, (0, my - 0.02, mz)))
    if blush and "Blush" in ch.palette:
        _lr(ch, "Blush", ellipse_slab(0.11 * s, 0.065 * s, 0.03, 6, (0.5 * s, my + 0.14 * s, zf(my) - 0.005)))


# ------------------------------------------------------------------ the 5-stud reference noob (the game rig's classic noob proportions)
def noob_meshes():
    """[(name, mesh, hex)] of the classic noob on the game rig: torso 2x2x1, 1x2x1 limbs, 1.32x1.2x1.2 head (5.2 studs tall)."""
    out = [
        ("Head", box(1.32, 1.2, 1.2, c=(0, 4.6, 0)), "#F5CD30"),
        ("Torso", box(2, 1.6, 1, c=(0, 3.2, 0)), "#3B6FD0"),
        ("Hips", box(2, 0.4, 1, c=(0, 2.2, 0)), "#3A8A3A"),
    ]
    for sx in (1, -1):
        out.append(("Arm", box(1, 2.0, 1, c=(1.5 * sx, 3.0, 0)), "#F5CD30"))
        out.append(("Leg", box(0.98, 2.0, 1, c=(0.5 * sx, 1.0, 0)), "#3A8A3A"))
    return out
