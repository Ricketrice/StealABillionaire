# kit035.b1 - Batch B1: the nine Knight's Keep creatures, built from the shared Standard body + knight kit.
import math

from . import geo
from .geo import lathe_arc, bend, profile_slab, star, ellipse_slab, M, V, box, frustum, ellipsoid, lathe, tube, poly_slab, merge, cyl, cyl_between, spike, torus, dome, loft, sheet, dent
from .char import Char
from .body import standard_body, Head, face, jp, RIG
from . import kit

PI = math.pi


def squire():
    """Rookie Squire (Common): a kid in a too-big dented pot helmet, patched blue tunic, a wooden practice sword."""
    ch = Char("RookieSquire", "Common", "Knight's Keep", scale=0.9)
    ch.sig_label = "clumsy sword swing, almost drops it"
    ch.colours(
        Skin="#FFD3B4", Tunic="#3F72D6", TunicDark="#2C54A6", Cream="#EFE2BF", Boot="#8A5530", BootDark="#5E3920", Rope="#C9A36A",
        Steel=("#A9B1C0", "Metal", 0.4, 0.6), SteelDark=("#6C7486", "Metal", 0.45, 0.6), Wood="#E2BE86", WoodDark="#8E5C2E", Hair="#D2601F",
        Patch1="#F28C3C", Patch2="#F7E9BE", Strap="#6A4326",
    )
    hd = Head(1.08)
    standard_body(ch, dict(Head="Skin", UpperTorso="Tunic", LowerTorso="TunicDark", UpperArm="Tunic", LowerArm="Skin", Hand="Skin",
                           UpperLeg="Cream", LowerLeg="Cream", Foot="Boot"), build=dict(bw=0.96, aw=0.95), head=hd)
    ch.palette["TunicDark"] = ch.palette["Tunic"]
    face(ch, hd, "grin", blush=True)
    # tunic: flared skirt over the hips, rope belt, two patches
    ch.add("LowerTorso", "Tunic", frustum(1.62, 2.46, 2.3, 1.2, 1.9, 1.0, bev=0.12, seg=2))
    ch.add("LowerTorso", "Rope", frustum(2.36, 2.62, 2.06, 1.1, 2.06, 1.1, bev=0.05, seg=1))
    ch.add("LowerTorso", "Rope", box(0.2, 0.7, 0.08, c=(0.18, 2.1, -0.58)).rot(0, 0, 6, (0.18, 2.5, 0)))
    ch.add("UpperTorso", "Patch1", poly_slab([(-0.28, -0.24), (0.28, -0.22), (0.26, 0.26), (-0.27, 0.24)], 0.05, c=(0.42, 3.42, -0.495)))
    ch.add("UpperTorso", "Patch1", poly_slab([(-0.22, -0.22), (0.24, -0.2), (0.22, 0.22), (-0.24, 0.2)], 0.05, c=(-0.5, 2.85, -0.47)))
    # sleeve hems + wrist bands, boot cuffs
    for s in (1, -1):
        g = "Right" if s > 0 else "Left"
        ch.add(g + "LowerArm", "Strap", box(0.88, 0.2, 0.88, c=(1.5 * s, 2.42, 0))) if s > 0 else None
        ch.add(g + "LowerLeg", "BootDark", frustum(0.7, 1.12, 0.96, 1.0, 1.1, 1.14, c=(0.5 * s, 0, 0)))
    # the helmet: far too big, dented, sliding back off the brow
    helm = lathe([(0.0001, 0.0), (0.84, 0.0), (0.9, 0.45), (0.78, 0.84), (0.5, 1.08), (0.0001, 1.2)], seg=10, sx=1.02, sz=0.96)
    helm = dent(helm, (-0.45, 0.95, -0.4), 0.55, 0.12)
    rim = lathe([(0.9, -0.04), (1.02, 0.0), (1.04, 0.09), (0.9, 0.12)], seg=10, sx=1.04, sz=0.98)
    hy = hd.at(0.93)
    for m, col in ((helm, "Steel"), (rim, "SteelDark")):
        m.rot(-20, 0, 0, (0, 0, 0)).move(0, hy, 0.1)
        ch.add("Helmet", col, m, on="Head", region="head")
    ch.add("Head", "Hair", ellipsoid((0.9, 0.7, 0.78), (0, hd.at(0.62), 0.2), 8, 4))  # hair under the helmet (sides + back)
    # practice sword (right hand), held in front of the fist, blade up and leaning forward
    blade = poly_slab([(-0.13, 0.0), (0.13, 0.0), (0.14, 1.5), (0.07, 1.78), (-0.07, 1.78), (-0.14, 1.5)], 0.08, bev=0.03, seg=2)
    guard = box(0.74, 0.12, 0.16, bev=0.04, seg=1, c=(0, -0.04, 0))
    grip = cyl(0.065, 0.065, 0.55, (0, -0.58, 0), 7)
    pommel = ellipsoid((0.1, 0.1, 0.1), (0, -0.62, 0), 7, 4)
    for m, col in ((blade, "Wood"), (guard, "WoodDark"), (grip, "Strap"), (pommel, "WoodDark")):
        m.rot(-24, 0, 0).move(1.5, 2.3, -0.5)
        ch.add("Sword", col, m, on="RightHand", region="armR")
    # animation: idle chains + the signature swing
    sg = dict(period=5.0, start=1.0, dur=1.7)
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "X", 100, sig=dict(sg, shape="strike", imp=0.22))
    ch.joint("ReSig", jp("Elbow", 1), "swing", "X", 30, sig=dict(sg, shape="strike", imp=0.2))
    ch.joint("RwSig", jp("Wrist", 1), "swing", "X", -110, sig=dict(sg, shape="strike", imp=1.25))
    ch.joint("RwFumble", jp("Wrist", 1), "swing", "X", 38, sig=dict(sg, shape="spring", cycles=2.5, u0=0.7))
    ch.joint("helmWobble", (0, hd.at(0.5), 0), "swing", "X", 7, 1.5)
    ch.joint("helmSig", (0, hd.at(0.5), 0), "swing", "X", -12, sig=dict(sg, shape="wave", cycles=1.5))
    ch.group("Helmet", "Head", "head", extra=["helmWobble", "helmSig"])
    ch.group("Sword", "RightHand", "armR")
    ch.arm_sig(1, groups_hand=["Sword"], sh="RshSig", el="ReSig", wr="RwSig")
    ch.groups["Sword"]["extra"] = ["RshSig", "ReSig", "RwSig", "RwFumble"]
    ch.finish_anim()
    return ch


def shield_knight():
    """Shield Knight (Epic): royal-blue plate, silver and gold trim, an open-face crested helm and a huge tower shield."""
    ch = Char("ShieldKnight", "Epic", "Knight's Keep", scale=1.1)
    ch.sig_label = "shield bash with a flash"
    ch.colours(
        Skin="#E8B48C", Under="#22305E", Plate=("#3E72D8", "Metal", 0.35, 0.6), PlateDark=("#2850A8", "Metal", 0.4, 0.6), Silver=("#CCD3DE", "Metal", 0.3, 0.7),
        Gold=("#F3B93A", "Metal", 0.3, 0.7), Cape="#EEF1F8", Boot="#4B3426", Steel=("#DFE5EF", "Metal", 0.25, 0.7), ShieldBlue="#2F62C8",
        Glow=("#FFF6B8", "Neon", 0.2, 0), Grip="#5B3A22",
    )
    hd = Head(1.0)
    standard_body(ch, dict(Head="Skin", UpperTorso="Under", LowerTorso="Under", UpperArm="Under", LowerArm="Under", Hand="Under", UpperLeg="Under", LowerLeg="Under", Foot="Boot"),
                  build=dict(bw=1.0, aw=1.0, lw=1.0), head=hd, q=2)
    face(ch, hd, "determined", eye_r=(0.16, 0.22))
    ch.add("Head", "Under", ellipsoid((0.82, 0.6, 0.7), (0, hd.at(0.7), 0.15), 8, 4))
    kit.helm_open(ch, hd, "Plate", "Gold", crest="Silver", crest_h=0.85)
    kit.chest_plate(ch, "Plate", "Gold")
    kit.belt(ch, "Grip", "Gold")
    kit.tassets(ch, "PlateDark", "Gold", n=5)
    kit.pauldron(ch, "Plate", "Gold", size=1.05, lames=2)
    kit.gauntlets(ch, "PlateDark", "Gold")
    kit.leg_armor(ch, "Plate", "Gold")
    kit.sabatons(ch, "PlateDark", "Gold")
    kit.cape(ch, "Cape", "Gold", hem=1.0, w_top=1.5, w_hem=2.2)
    kit.sword(ch, "Sword", "RightHand", "Steel", "Gold", "Grip", length=2.3, width=0.22)
    kit.shield(ch, "Shield", "ShieldBlue", "Gold", "Gold", "Silver", w=2.3, h=3.3, at=(-2.0, 2.7, -0.78))
    kit.tower_emblem(ch, "Shield", "Gold", (-2.0, 3.35, -0.78), 1.7)
    # flash star on the shield face (signature)
    ch.add("Flash", "Glow", star(8, 1.1, 0.45, 0.06, c=(-2.0, 2.75, -1.35), back=True), on="LeftLowerArm", region="armL")
    sg = dict(period=5.0, start=1.2, dur=1.3)
    ch.joint("LshSig", jp("Shoulder", -1), "swing", "X", 22, sig=dict(sg, shape="snap"))
    ch.joint("LbashPush", (0, 0, 0), "push", "Z", -0.9, sig=dict(sg, shape="snap"))
    ch.joint("flashPop", (-2.0, 2.75, -1.35), "pop", "X", 1.0, sig=dict(sg, shape="snap"))
    ch.group("Shield", "LeftLowerArm", "armL")
    ch.arm_sig(-1, groups_lower=["Shield"], sh="LshSig", el="LbashPush")
    ch.groups["Flash"]["extra"] = ["LshSig", "LbashPush", "flashPop"]
    ch.finish_anim()
    return ch


def scroll_page():
    """Scroll Page (Common): a kid in a red beret with a leather satchel, carrying a scroll that unrolls."""
    ch = Char("ScrollPage", "Common", "Knight's Keep", scale=0.88)
    ch.sig_label = "unrolls the scroll and reads"
    ch.colours(
        Skin="#C98C60", Hair="#33211A", Tunic="#3FA561", Cream="#F0E6C8", Boot="#7B4B2A", Beret="#C23A45", Leather="#8A5632", Parchment="#F4E5B8",
        Ribbon="#D8404A", Dowel="#B98652",
    )
    hd = Head(1.08)
    standard_body(ch, dict(Head="Skin", UpperTorso="Tunic", LowerTorso="Tunic", UpperArm="Tunic", LowerArm="Skin", Hand="Skin", UpperLeg="Cream", LowerLeg="Cream", Foot="Boot"),
                  build=dict(bw=0.92, aw=0.92, lw=0.95), head=hd)
    face(ch, hd, "smile", blush=True)
    ch.add("Head", "Hair", ellipsoid((0.9, 0.7, 0.78), (0, hd.at(0.62), 0.2), 8, 4))
    ch.add("LowerTorso", "Tunic", frustum(1.7, 2.46, 2.18, 1.14, 1.9, 1.0, bev=0.1, seg=1))
    ch.add("UpperTorso", "Cream", frustum(3.8, 4.06, 1.5, 1.1, 1.5, 1.1, bev=0.05, seg=1))
    # satchel: strap across the chest, bag on the left hip
    ch.add("UpperTorso", "Leather", box(0.26, 2.3, 0.07, c=(0, 3.2, -0.54)).rot(0, 0, 40, (0, 3.2, 0)))
    ch.add("Satchel", "Leather", box(0.95, 0.85, 0.42, bev=0.1, seg=1, c=(-1.0, 2.1, 0.42)), on="LowerTorso", region="static")
    ch.add("Satchel", "Leather", box(1.0, 0.3, 0.46, bev=0.05, seg=1, c=(-1.0, 2.5, 0.42)), on="LowerTorso")
    for s in (1, -1):
        g = "Right" if s > 0 else "Left"
        ch.add(g + "LowerLeg", "Leather", frustum(0.7, 1.1, 0.96, 1.0, 1.1, 1.14, c=(0.5 * s, 0, 0)))
    # beret with a feather
    bere = lathe([(0.0001, 0.0), (0.98, 0.0), (1.04, 0.12), (0.9, 0.34), (0.55, 0.46), (0.0001, 0.48)], seg=10, sz=0.95).rot(0, 0, 10).rot(-6, 0, 0).move(0.05, hd.at(0.97), 0.0)
    ch.add("Beret", "Beret", bere, on="Head", region="head")
    ch.add("Beret", "Cream", tube([(0.7, hd.at(1.0) + 0.1, 0.0), (1.05, hd.at(1.0) + 0.5, 0.15), (1.25, hd.at(1.0) + 0.55, 0.5)], [0.05, 0.09, 0.02], seg=4, sx=0.6))
    # the scroll: a roll in the right fist, leaning forward; its sheet hangs from the top and grows when unrolled
    at = (1.5, 2.3, -0.5)
    roll = cyl(0.17, 0.17, 1.5, (0, -0.75, 0), 8)
    for col, m in (("Parchment", roll), ("Ribbon", cyl(0.11, 0.11, 1.8, (0, -0.9, 0), 6)), ("Ribbon", cyl(0.2, 0.2, 0.18, (0, -0.02, 0), 8))):
        ch.add("Scroll", col, m.copy().rot(-22, 0, 0).move(*at), on="RightHand", region="armR")
    top = V(at) + V((0, 0.75, 0)).__class__((0, math.cos(math.radians(22)) * 0.75, -math.sin(math.radians(22)) * 0.75))
    sx, sy, sz = at[0], at[1] + math.cos(math.radians(22)) * 0.75, at[2] - math.sin(math.radians(22)) * 0.75
    sheet_m = box(0.82, 0.3, 0.04, c=(0, -0.15, 0))
    lines = merge([box(0.6, 0.035, 0.05, c=(0, -0.06 - 0.075 * k, -0.01)) for k in range(3)])
    ch.add("ScrollSheet", "Parchment", sheet_m.copy().move(sx, sy, sz - 0.18), on="RightHand", region="armR")
    ch.add("ScrollSheet", "Ink", lines.move(sx, sy, sz - 0.18), on="RightHand")
    sg = dict(period=5.0, start=1.0, dur=1.9)
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "X", 40, sig=dict(sg, shape="hump"))
    ch.joint("ReSig", jp("Elbow", 1), "swing", "X", 50, sig=dict(sg, shape="hump"))
    ch.joint("RwSig", jp("Wrist", 1), "swing", "X", -70, sig=dict(sg, shape="hump"))
    ch.joint("unroll", (sx, sy, sz - 0.18), "grow", "Y", 5.5, sig=dict(sg, shape="hump"))
    ch.joint("headRead", jp("Neck"), "swing", "X", 16, sig=dict(sg, shape="hump"))
    ch.group("Scroll", "RightHand", "armR")
    ch.group("ScrollSheet", "RightHand", "armR")
    ch.arm_sig(1, groups_hand=["Scroll"], sh="RshSig", el="ReSig", wr="RwSig")
    ch.groups["ScrollSheet"]["extra"] = ["RshSig", "ReSig", "RwSig", "unroll"]
    ch.groups["Head"]["extra"] = ["headRead"]
    ch.groups["Beret"]["extra"] = ["headRead"]
    ch.finish_anim()
    return ch





def training_dummy():
    """Training Dummy (Common): a stuffed burlap dummy on peg legs with a target on its chest and two stuck arrows."""
    ch = Char("TrainingDummy", "Common", "Knight's Keep", scale=1.0)
    ch.sig_label = "wobbles and springs back"
    ch.colours(Burlap="#CDA86C", BurlapDark="#A68248", Straw="#EBCB6A", Wood="#9C6B3A", WoodDark="#6F4727", Rope="#E0C896", Red="#D8383F",
               Button="#4B3322", Feather="#F2F2EC")
    hd = Head(1.0)
    standard_body(ch, dict(Head="Burlap", UpperTorso="Burlap", LowerTorso="BurlapDark", UpperArm="Burlap", LowerArm="Burlap", Hand="Straw", UpperLeg="Wood", LowerLeg="Wood", Foot="WoodDark"),
                  build=dict(bw=1.0, aw=1.0, lw=0.92), head=hd)
    ch.remove("Head", "UpperTorso")
    ch.add("UpperTorso", "Burlap", ellipsoid((1.1, 0.92, 0.68), (0, 3.2, 0), 10, 5))  # round stuffed body
    ch.add("Head", "Burlap", ellipsoid((0.82, 0.74, 0.74), (0, 4.62, 0), 10, 5))  # sack head
    ch.add("Head", "Straw", merge([spike((0.0 + math.sin(a) * 0.22, 5.3, math.cos(a) * 0.22), (math.sin(a) * 0.5, 5.9 + 0.05 * k, math.cos(a) * 0.5), 0.09, 4) for k, a in enumerate([i * 1.05 for i in range(6)])]))
    ch.add("Head", "Rope", lathe([(0.55, 3.98), (0.6, 4.05), (0.6, 4.2), (0.55, 4.26)], seg=8))  # tied neck
    # button eyes, stitched mouth, target
    ch.add("Head", "Button", ellipse_slab(0.24, 0.24, 0.07, 10, (-0.32, 4.8, -0.71)))
    ch.add("Head", "Button", ellipse_slab(0.2, 0.2, 0.07, 10, (0.32, 4.76, -0.71)))
    ch.add("Head", "Ink", ellipse_slab(0.07, 0.07, 0.08, 6, (-0.32, 4.8, -0.76)))
    ch.add("Head", "Ink", ellipse_slab(0.06, 0.06, 0.08, 6, (0.32, 4.76, -0.76)))
    ch.add("Head", "Ink", tube([(-0.38, 4.38, -0.7), (-0.18, 4.27, -0.72), (0.0, 4.25, -0.73), (0.2, 4.3, -0.72), (0.4, 4.42, -0.7)], 0.035, 4))  # stitched smile
    ch.add("Head", "Ink", merge([box(0.05, 0.16, 0.04, c=(x, y, -0.7)) for x, y in ((-0.42, 4.46), (0.44, 4.5))]))
    ch.add("Head", "Rope", ellipse_slab(0.17, 0.12, 0.05, 6, (0.5, 4.5, -0.66)))  # little patch on the cheek
    for col, r, z in (("Red", 0.56, -0.66), ("Feather", 0.4, -0.675), ("Red", 0.24, -0.69)):
        ch.add("UpperTorso", col, ellipse_slab(r, r, 0.05, 14, (0, 3.2, z)))
    ch.add("UpperTorso", "Straw", merge([spike((0.9, 3.1, -0.1), (1.0 + 0.1 * k, 2.8 - 0.2 * k, -0.2), 0.08, 4) for k in range(2)]))
    # two arrows stuck in the body
    for k, (x, y, dz) in enumerate(((0.55, 3.5, 0.0), (-0.6, 3.0, 0.1))):
        sh = cyl_between((x, y, -0.55), (x + 0.3 * (1 - 2 * k), y + 0.35, -1.8), 0.035, 0.035, 4)
        ch.add("UpperTorso", "Wood", sh)
        ch.add("UpperTorso", "Feather", box(0.3, 0.02, 0.35, c=(x + 0.28 * (1 - 2 * k), y + 0.33, -1.65)))
    ch.add("LowerTorso", "Rope", frustum(2.2, 2.55, 2.0, 1.1, 2.0, 1.1, bev=0.04, seg=1))
    for s_ in (1, -1):
        g = "Right" if s_ > 0 else "Left"
        ch.add(g + "LowerArm", "Rope", box(0.9, 0.16, 0.9, c=(1.5 * s_, 2.45, 0)))
        ch.add(g + "LowerLeg", "WoodDark", box(1.0, 0.12, 1.04, c=(0.5 * s_, 0.95, 0)))
    ch.add("CrossBar", "Wood", box(3.7, 0.24, 0.24, bev=0.06, seg=1, c=(0, 3.75, 0.62)), on="UpperTorso", region="torso")
    sg = dict(period=5.0, start=1.0, dur=1.9)
    ch.joint("wobble", (0, 1.9, 0), "swing", "Z", 16, sig=dict(sg, shape="spring", cycles=3))
    ch.joint("wobbleX", (0, 1.9, 0), "swing", "X", 7, sig=dict(sg, shape="spring", cycles=2.2))
    for g, info in ch.groups.items():
        if info["region"] in ("torso", "head", "armR", "armL", "static"):
            info["extra"] = ["wobble", "wobbleX"]
    ch.finish_anim(breath=0.0, head_sway=3.0, arm_sway=2.0)
    return ch


def apple_archer():
    """Apple Archer (Rare): a cheerful archer in a rounded green hood with an apple balanced on top, a curved bow and a quiver."""
    ch = Char("AppleArcher", "Rare", "Knight's Keep", scale=1.0)
    ch.sig_label = "draws the bow, the apple wobbles"
    ch.colours(Skin="#F1BF95", Hair="#6B4023", Hood="#3F9B58", HoodDark="#2B7443", Tunic="#B98B4F", Pants="#5D4B3B", Boot="#6B4326", Leather="#7B4B2A",
               Apple="#E43D3D", Leaf="#5FC76C", Wood="#A8723A", String="#F4EFE2", Feather="#EFEFE8", Fletch="#E8503C", Stem="#6A4A2A")
    hd = Head(1.08)
    standard_body(ch, dict(Head="Skin", UpperTorso="Tunic", LowerTorso="Leather", UpperArm="Tunic", LowerArm="Leather", Hand="Leather", UpperLeg="Pants", LowerLeg="Pants", Foot="Boot"),
                  build=dict(bw=0.97, aw=0.95), head=hd)
    face(ch, hd, "smirk", blush=True)
    ch.add("Head", "Hair", ellipsoid((0.88, 0.62, 0.72), (0, hd.at(0.66), 0.18), 8, 4))
    # hood: an open-front cowl with a rounded crown, a curled tail, and a mantle over the shoulders
    hood = lathe_arc([(0.97, hd.at(0.05)), (1.0, hd.at(0.4)), (0.95, hd.at(0.8)), (0.8, hd.at(1.0)), (0.5, hd.at(1.12)), (0.0001, hd.at(1.17))], seg=10, a0=-38, a1=218, thick=0.1, sx=0.98, sz=0.94)
    ch.add("Hood", "Hood", hood, on="Head", region="head")
    ch.add("Hood", "HoodDark", tube([(0.0, hd.at(0.55), 0.78), (0.0, hd.at(0.1), 1.05), (0.0, hd.at(-0.35), 1.15)], [0.28, 0.3, 0.05], seg=5, sx=1.0, sz=0.6))
    ch.add("Hood", "HoodDark", lathe_arc([(0.97, hd.at(0.05)), (1.05, hd.at(0.02)), (1.05, hd.at(-0.06)), (0.97, hd.at(-0.04))], seg=10, a0=-38, a1=218, thick=0.07, sx=0.98, sz=0.94))
    ch.add("UpperTorso", "Hood", frustum(3.35, 4.08, 2.3, 1.3, 1.7, 1.18, bev=0.1, seg=1))  # mantle
    ch.add("UpperTorso", "HoodDark", frustum(3.28, 3.42, 2.36, 1.34, 2.3, 1.3, bev=0.03, seg=1))
    # apple on top of the hood
    ch.add("Apple", "Apple", ellipsoid((0.4, 0.38, 0.4), (0, hd.at(1.17) + 0.3, 0), 8, 5), on="Head", region="head")
    ch.add("Apple", "Stem", cyl_between((0, hd.at(1.17) + 0.62, 0), (0.05, hd.at(1.17) + 0.82, 0), 0.04, 0.03, 4))
    ch.add("Apple", "Leaf", ellipsoid((0.18, 0.05, 0.1), (0, 0, 0), 6, 3).rot(0, 0, 25).move(0.2, hd.at(1.12) + 0.74, 0))
    # belt, quiver on the back
    ch.add("LowerTorso", "Leather", box(2.04, 0.12, 1.08, c=(0, 2.5, 0)))
    ch.add("LowerTorso", "Wood", box(0.4, 0.28, 0.1, bev=0.03, seg=1, c=(0, 2.45, -0.56)))
    ch.add("UpperTorso", "Leather", box(0.22, 2.2, 0.07, c=(0, 3.2, -0.54)).rot(0, 0, -40, (0, 3.2, 0)))
    qv = cyl(0.24, 0.28, 1.5, (0, 0, 0), 8).rot(0, 0, -16).move(-0.45, 2.55, 0.78)
    ch.add("Quiver", "Leather", qv, on="UpperTorso", region="torso")
    for k in range(3):
        top = (-0.62 + 0.2 * k, 4.75 + 0.05 * k, 0.78 + 0.1 * (k - 1))
        ch.add("Quiver", "Wood", cyl_between((top[0] + 0.12, 3.6, top[2]), top, 0.03, 0.03, 4))
        ch.add("Quiver", "Fletch", box(0.2, 0.34, 0.04, c=top).rot(0, 20 * k, 0, top))
    # the bow (left hand): a curved limb, string halves that pull back, a nocked arrow that appears
    bx, by, bz = -1.5, 2.3, -0.62
    path = [(bx, by + 1.65 * t, bz + 0.5 * t * t) for t in (-1, -0.7, -0.35, 0, 0.35, 0.7, 1)]
    ch.add("Bow", "Wood", tube(path, [0.05, 0.08, 0.09, 0.12, 0.09, 0.08, 0.05], seg=5), on="LeftHand", region="armL")
    ch.add("Bow", "Leather", box(0.14, 0.45, 0.14, c=(bx, by, bz - 0.02)))
    ytop, ybot, zt = by + 1.65, by - 1.65, bz + 0.5
    ymid = by
    ch.add("StringTop", "String", cyl_between((bx, ytop, zt), (bx, ymid, zt), 0.018, 0.018, 3), on="LeftHand", region="armL")
    ch.add("StringBot", "String", cyl_between((bx, ybot, zt), (bx, ymid, zt), 0.018, 0.018, 3), on="LeftHand", region="armL")
    ch.add("Arrow", "Wood", cyl_between((bx, ymid, zt + 0.2), (bx, ymid, zt - 1.9), 0.03, 0.03, 4), on="LeftHand", region="armL")
    ch.add("Arrow", "Fletch", box(0.2, 0.04, 0.3, c=(bx, ymid, zt + 0.1)))
    sg = dict(period=5.0, start=1.0, dur=1.9)
    ch.joint("LshSig", jp("Shoulder", -1), "swing", "X", 78, sig=dict(sg, shape="snap"))
    ch.joint("LeSig", jp("Elbow", -1), "swing", "X", -12, sig=dict(sg, shape="snap"))
    ch.joint("LwSig", jp("Wrist", -1), "swing", "X", -78, sig=dict(sg, shape="snap"))
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "X", 70, sig=dict(sg, shape="snap"))
    ch.joint("ReSig", jp("Elbow", 1), "swing", "Y", 70, sig=dict(sg, shape="snap"))
    ch.joint("strTop", (bx, ytop, zt), "swing", "X", -18, sig=dict(sg, shape="snap", u0=0.15))
    ch.joint("strBot", (bx, ybot, zt), "swing", "X", 18, sig=dict(sg, shape="snap", u0=0.15))
    ch.joint("arrowPop", (bx, ymid, zt - 0.8), "pop", "X", 1.0, sig=dict(sg, shape="snap", u0=0.1))
    ch.joint("appleBob", (0, hd.at(1.17), 0), "swing", "Z", 9, 3.0)
    ch.joint("appleSig", (0, hd.at(1.17), 0), "swing", "Z", 16, sig=dict(sg, shape="wave", cycles=3, u0=0.2))
    ch.group("Bow", "LeftHand", "armL")
    ch.arm_sig(-1, groups_hand=["Bow", "StringTop", "StringBot", "Arrow"], sh="LshSig", el="LeSig", wr="LwSig")
    ch.arm_sig(1, sh="RshSig", el="ReSig")
    ch.groups["StringTop"]["extra"] = ["LshSig", "LeSig", "LwSig", "strTop"]
    ch.groups["StringBot"]["extra"] = ["LshSig", "LeSig", "LwSig", "strBot"]
    ch.groups["Arrow"]["extra"] = ["LshSig", "LeSig", "LwSig", "arrowPop"]
    ch.group("Apple", "Head", "head", extra=["appleBob", "appleSig"])
    ch.finish_anim()
    return ch


def banner_bearer():
    """Banner Bearer (Rare): a red-tabarded standard bearer with a tall banner carrying an original tower-and-star crest."""
    ch = Char("BannerBearer", "Rare", "Knight's Keep", scale=1.0)
    ch.sig_label = "big banner wave"
    ch.colours(Skin="#8D5A3A", Hair="#2B1A14", Tabard="#CC3340", Gold=("#F3BF3B", "Metal", 0.3, 0.7), Mail=("#A8B0BF", "Metal", 0.4, 0.5), Leather="#6A4326",
               Pants="#39415F", Boot="#4F3526", Pole="#B27C44", Flag="#CC3340", Steel=("#CBD2DD", "Metal", 0.3, 0.7), Cream="#F6EFDC")
    hd = Head(1.05)
    standard_body(ch, dict(Head="Skin", UpperTorso="Mail", LowerTorso="Pants", UpperArm="Mail", LowerArm="Mail", Hand="Leather", UpperLeg="Pants", LowerLeg="Pants", Foot="Boot"),
                  build=dict(bw=0.98, aw=0.96), head=hd)
    face(ch, hd, "grin", blush=False)
    ch.add("Head", "Hair", ellipsoid((0.86, 0.6, 0.7), (0, hd.at(0.62), 0.2), 8, 4))
    ch.add("Head", "Hair", tube([(0, hd.at(0.7), 0.7), (0, hd.at(0.25), 1.0), (0.05, hd.at(-0.3), 1.05), (0.15, hd.at(-0.8), 0.95)], [0.2, 0.2, 0.17, 0.05], seg=5))  # braid
    kit.helm_open(ch, hd, "Steel", "Gold", crest="Tabard", crest_h=0.6, nasal=False)
    out = [(-0.8, 4.06), (0.8, 4.06), (0.94, 3.3), (0.92, 1.75), (0.0, 1.38), (-0.92, 1.75), (-0.94, 3.3)]
    for z in (-0.63, 0.63):
        ch.add("Tabard", "Tabard", poly_slab(out, 0.1, bev=0.03, seg=1, c=(0, 0, z)), on="UpperTorso", region="torso")
    ch.add("Tabard", "Gold", box(1.95, 0.1, 0.13, c=(0, 1.86, -0.64)))
    ch.add("Tabard", "Gold", box(0.1, 0.9, 0.13, c=(0.0, 2.3, -0.65)))
    kit.tower_emblem(ch, "Tabard", "Gold", (0.0, 3.15, -0.72), 1.15, on="UpperTorso", region="torso")
    kit.belt(ch, "Leather", "Gold", y=2.45)
    for s_ in (1, -1):
        g = "Right" if s_ > 0 else "Left"
        ch.add(g + "UpperArm", "Tabard", box(1.0, 0.16, 1.0, c=(1.5 * s_, 3.9, 0)))  # shoulder cap
        ch.add(g + "LowerLeg", "Leather", frustum(0.7, 1.12, 0.96, 1.0, 1.1, 1.14, c=(0.5 * s_, 0, 0)))
        ch.add(g + "LowerArm", "Gold", box(0.94, 0.14, 0.94, c=(1.5 * s_, 2.45, 0)))
    # the banner: pole in the right fist, crossbar, three hinged flag segments
    px, pz, tilt = 1.5, -0.55, -3
    ch.add("Pole", "Pole", cyl(0.07, 0.07, 6.2, (0, 0, 0), 6).rot(tilt, 0, 0).move(px, 1.3, pz), on="RightHand", region="armR")
    ch.add("Pole", "Gold", ellipsoid((0.16, 0.16, 0.16), (0, 7.62, 0), 6, 4).rot(tilt, 0, 0).move(px, 0, pz))
    ch.add("Pole", "Pole", box(1.9, 0.1, 0.1, c=(px + 0.85, 7.4, 0)).rot(tilt, 0, 0).move(0, 0, pz))
    cx = px + 0.9
    segs = [(7.35, 6.45, "FlagA"), (6.45, 5.55, "FlagB"), (5.55, 4.65, "FlagC")]
    for k, (ya, yb, g) in enumerate(segs):
        if g == "FlagC":
            ol = [(-0.8, ya), (0.8, ya), (0.8, yb), (0.0, yb + 0.35), (-0.8, yb)]
        else:
            ol = [(-0.8, ya), (0.8, ya), (0.8, yb), (-0.8, yb)]
        ch.add(g, "Flag", poly_slab(ol, 0.06, bev=0.02, seg=1, c=(cx, 0, pz - 0.02)), on="RightHand", region="armR")
        ch.add(g, "Gold", box(0.08, ya - yb, 0.09, c=(cx - 0.82, (ya + yb) / 2, pz - 0.02)))
        ch.add(g, "Gold", box(0.08, ya - yb, 0.09, c=(cx + 0.82, (ya + yb) / 2, pz - 0.02)))
    kit.tower_emblem(ch, "FlagB", "Gold", (cx, 6.0, pz - 0.02), 2.0, on="RightHand", region="armR")
    sg = dict(period=5.0, start=1.0, dur=1.9)
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "Z", 34, sig=dict(sg, shape="wave", cycles=1.0))
    ch.joint("RshSigX", jp("Shoulder", 1), "swing", "X", 14, sig=dict(sg, shape="hump"))
    ch.joint("fwA", (cx, 7.35, pz), "swing", "X", 9, 2.4, 0.0)
    ch.joint("fwB", (cx, 6.45, pz), "swing", "X", 11, 2.4, 0.9)
    ch.joint("fwC", (cx, 5.55, pz), "swing", "X", 13, 2.4, 1.8)
    ch.joint("fsA", (cx, 7.35, pz), "swing", "X", 14, sig=dict(sg, shape="wave", cycles=3))
    ch.joint("fsB", (cx, 6.45, pz), "swing", "X", 20, sig=dict(sg, shape="wave", cycles=3, u0=0.05))
    ch.joint("fsC", (cx, 5.55, pz), "swing", "X", 26, sig=dict(sg, shape="wave", cycles=3, u0=0.1))
    ch.group("Pole", "RightHand", "armR")
    ch.arm_sig(1, groups_hand=["Pole", "FlagA", "FlagB", "FlagC"], sh="RshSig")
    ch.groups["Pole"]["extra"] = ["RshSig", "RshSigX"]
    ch.groups["FlagA"]["extra"] = ["RshSig", "RshSigX", "fwA", "fsA"]
    ch.groups["FlagB"]["extra"] = ["RshSig", "RshSigX", "fwA", "fsA", "fwB", "fsB"]
    ch.groups["FlagC"]["extra"] = ["RshSig", "RshSigX", "fwA", "fsA", "fwB", "fsB", "fwC", "fsC"]
    ch.finish_anim()
    return ch


def forge_master():
    """Forge Master (Epic): a broad blacksmith in a leather apron, goggles on his forehead, with a big glowing-headed hammer."""
    ch = Char("ForgeMaster", "Epic", "Knight's Keep", scale=1.1)
    ch.sig_label = "hammer strike, spark burst"
    ch.colours(Skin="#D9976A", Hair="#744628", Shirt="#9B4B37", Pants="#3F3F4D", Boot="#34271F", Apron="#7F4D2D", ApronDark="#5A3620", Leather="#6A4326",
               Iron=("#6A7384", "Metal", 0.35, 0.7), IronDark=("#454D5A", "Metal", 0.4, 0.7), Brass=("#E0AA48", "Metal", 0.3, 0.7), Lens=("#FFB347", "Neon", 0.2, 0),
               Wood="#A47040", Ember=("#FF7A2D", "Neon", 0.2, 0), Spark=("#FFD85E", "Neon", 0.2, 0), Glove="#4C3B33")
    hd = Head(1.06, wide=1.06)
    standard_body(ch, dict(Head="Skin", UpperTorso="Shirt", LowerTorso="Pants", UpperArm="Shirt", LowerArm="Skin", Hand="Glove", UpperLeg="Pants", LowerLeg="Pants", Foot="Boot"),
                  build=dict(bw=1.12, bd=1.1, aw=1.15, lw=1.05), head=hd, q=2)
    face(ch, hd, "grin", blush=False)
    ch.add("Head", "Hair", ellipsoid((0.84, 0.46, 0.5), (0, hd.at(0.74), 0.34), 8, 4))
    ch.add("Head", "Hair", ellipsoid((0.62, 0.34, 0.4), (0, hd.at(0.1), hd.zf(hd.at(0.1)) + 0.3), 8, 4))  # beard
    for s_ in (1, -1):
        ch.add("Head", "Hair", ellipsoid((0.12, 0.3, 0.3), (0.74 * hd.hs * s_, hd.at(0.28), -0.18), 6, 3))  # side whiskers
    # goggles pushed up on the forehead: strap, two brass rims, glowing amber lenses
    ch.add("Head", "Leather", frustum(hd.at(0.86), hd.at(1.0), hd.w1 + 0.1, hd.d1 + 0.1, hd.w1 + 0.08, hd.d1 + 0.08, bev=0.03, seg=1))
    for s_ in (1, -1):
        ch.add("Head", "Brass", cyl(0.25, 0.25, 0.16, (0.36 * s_, hd.at(0.93), hd.zf(hd.at(0.93)) - 0.2), 8).rot(90, 0, 0, (0.36 * s_, hd.at(0.93), hd.zf(hd.at(0.93)) - 0.2)))
        ch.add("Head", "Lens", ellipse_slab(0.19, 0.19, 0.05, 8, (0.36 * s_, hd.at(0.93), hd.zf(hd.at(0.93)) - 0.34)))
    # apron over shirt and hips, shoulder straps, pocket, wide belt, tongs
    bib = [(-0.5, 3.8), (0.5, 3.8), (0.56, 3.5), (1.0, 3.4), (1.02, 1.8), (-1.02, 1.8), (-1.0, 3.4), (-0.56, 3.5)]
    ch.add("Apron", "Apron", poly_slab(bib, 0.12, bev=0.03, seg=1, c=(0, 0, -0.66)), on="UpperTorso", region="torso")
    ch.add("Apron", "ApronDark", box(0.9, 0.55, 0.07, bev=0.02, seg=1, c=(0, 2.62, -0.75)))
    for s_ in (1, -1):
        ch.add("Apron", "ApronDark", box(0.2, 0.12, 1.22, c=(0.45 * s_, 4.05, 0.0)))
    kit.belt(ch, "Leather", "Brass", y=2.5, h=0.34, w=2.2, d=1.2)
    ch.add("LowerTorso", "IronDark", cyl_between((1.0, 2.45, -0.4), (1.1, 1.5, -0.5), 0.05, 0.05, 4))
    ch.add("LowerTorso", "IronDark", cyl_between((1.12, 2.45, -0.4), (1.2, 1.55, -0.55), 0.05, 0.05, 4))
    kit.pauldron(ch, "Leather", "Brass", size=1.12, lames=2, sides=(1,))
    for s_ in (1, -1):
        g = "Right" if s_ > 0 else "Left"
        ch.add(g + "LowerArm", "Shirt", box(1.08, 0.2, 1.08, bev=0.04, seg=1, c=(1.5 * s_, 3.0, 0)))
        ch.add(g + "LowerArm", "IronDark", box(1.0, 0.22, 1.0, bev=0.04, seg=1, c=(1.5 * s_, 2.42, 0)))
        ch.add(g + "LowerLeg", "Leather", frustum(0.5, 1.1, 1.0, 1.04, 1.08, 1.12, bev=0.06, seg=1, c=(0.5 * s_, 0, 0)))
    kit.sabatons(ch, "IronDark", "Brass")
    # the hammer: handle, iron head (long axis front-back), glowing band, bands on the handle
    at = (1.62, 2.2, -0.72)
    parts = [("Wood", cyl(0.12, 0.12, 2.9, (0, -0.6, 0), 6)), ("IronDark", box(0.74, 0.84, 1.5, bev=0.1, seg=1, c=(0, 2.5, 0))), ("Ember", box(0.8, 0.9, 0.28, bev=0.04, seg=1, c=(0, 2.5, 0))),
             ("Brass", box(0.26, 0.26, 0.26, bev=0.05, seg=1, c=(0, 2.0, 0))), ("Iron", box(0.66, 0.76, 0.12, c=(0, 2.5, -0.78))), ("Iron", box(0.66, 0.76, 0.12, c=(0, 2.5, 0.78)))]
    for col, m in parts:
        ch.add("Hammer", col, m.copy().rot(-12, 0, 0).move(*at), on="RightHand", region="armR")
    hp = V(at) + V((0, 0, 0))
    ang = math.radians(-12)
    def hpos(y, z):  # a point on the tilted hammer axis -> kit frame
        return (at[0], at[1] + y * math.cos(ang) - z * math.sin(ang), at[2] + y * math.sin(ang) + z * math.cos(ang))
    sp = hpos(2.5, -1.05)
    for k, rot_ in enumerate((0, 90)):
        ch.add("Sparks", "Spark", star(8, 1.0 - 0.15 * k, 0.32, 0.06, c=(0, 0, 0)).rot(0, rot_, 0).rot(-12, 0, 0).move(*sp), on="RightHand", region="armR")
    sg = dict(period=5.0, start=1.0, dur=1.9)
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "X", 165, sig=dict(sg, shape="strike", imp=0.24))
    ch.joint("ReSig", jp("Elbow", 1), "swing", "X", 28, sig=dict(sg, shape="strike", imp=0.1))
    ch.joint("RwSig", jp("Wrist", 1), "swing", "X", -120, sig=dict(sg, shape="strike", imp=1.25))
    ch.joint("sparkPop", sp, "pop", "X", 1.0, sig=dict(sg, shape="hump", u0=0.66))
    ch.joint("lean", (0, 2.4, 0), "swing", "X", 12, sig=dict(sg, shape="strike", imp=0.8))
    ch.group("Hammer", "RightHand", "armR")
    ch.group("Sparks", "RightHand", "armR")
    ch.arm_sig(1, groups_hand=["Hammer"], sh="RshSig", el="ReSig", wr="RwSig")
    ch.groups["Sparks"]["extra"] = ["RshSig", "ReSig", "RwSig", "sparkPop"]
    ch.finish_anim()
    return ch


def winged_pauldron(ch, main, trim, feather, size=1.0, n=3, spread=26, length=1.5):
    """Feather-blade wings fanned up and back from both shoulders (Legendary)."""
    for side in (1, -1):
        g = ("Right" if side > 0 else "Left") + "UpperArm"
        for k in range(n):
            a = -spread + spread * 2 * k / max(n - 1, 1)
            ln = length * (1.0 - 0.18 * abs(k - (n - 1) / 2))
            pts = [(0.0, 0.0), (0.18, 0.15), (ln * 0.8, 0.12), (ln, 0.0), (ln * 0.8, -0.12), (0.18, -0.15)]
            blade = poly_slab(pts, 0.07, bev=0.02, seg=1).rot(0, 0, 0)
            blade.rot(0, 0, 0).rot(a * 0.0, 0, 0)
            blade = blade.rot(0, 0, 70 + a * 0.8).rot(0, -18 - 0, 0).move(1.7, 4.05, 0.28)
            ch.add(g, feather, blade if side > 0 else blade.mirror_x())


def golden_paladin():
    """Golden Paladin (Legendary): gold plate over white and crimson layers, winged helm and pauldrons, crimson cape, a blade of light."""
    ch = Char("GoldenPaladin", "Legendary", "Knight's Keep", scale=1.25)
    ch.sig_label = "raises the sword, light burst"
    ch.colours(Skin="#F2C6A0", Hair="#E9C566", Gold=("#F6C43E", "Metal", 0.28, 0.8), GoldDark=("#D39A22", "Metal", 0.32, 0.8), White="#F7F4EC", WhiteTrim=("#E5E0D0", "Metal", 0.4, 0.4),
               Crimson="#B02834", CrimsonDark="#7F1C27", Under="#EDE8DB", Boot="#7A5434", Blade=("#FFE88A", "Neon", 0.2, 0), Grip="#8A2530", Halo=("#FFE27A", "Neon", 0.2, 0))
    hd = Head(1.0)
    standard_body(ch, dict(Head="Skin", UpperTorso="Under", LowerTorso="Crimson", UpperArm="Crimson", LowerArm="Under", Hand="Under", UpperLeg="Crimson", LowerLeg="Under", Foot="Boot"),
                  build=dict(bw=1.04, aw=1.02, lw=1.02), head=hd, q=3)
    face(ch, hd, "determined", eye_r=(0.16, 0.22))
    ch.add("Head", "Hair", ellipsoid((0.84, 0.62, 0.7), (0, hd.at(0.68), 0.2), 8, 4))
    kit.helm_open(ch, hd, "Gold", "GoldDark", crest="Crimson", crest_h=0.55, cap_base=0.88)
    for s_ in (1, -1):  # helmet wings
        for k, (ln, rz) in enumerate(((1.15, 38), (0.9, 18))):
            pts = [(0, 0), (0.12, 0.13), (ln * 0.8, 0.1), (ln, 0.0), (ln * 0.8, -0.1), (0.12, -0.13)]
            w = poly_slab(pts, 0.05, bev=0.015, seg=1).rot(0, 0, rz).rot(0, 18, 0).move(0.9, hd.at(0.86) + 0.1 * k, 0.12)
            ch.add("Helmet", "Gold", w if s_ > 0 else w.mirror_x())
    kit.chest_plate(ch, "Gold", "GoldDark", ridge=True, flare=1.02, lames=3, bevseg=3)
    # white tabard front + back with crimson border and a sun crest
    out = [(-0.72, 3.96), (0.72, 3.96), (0.84, 3.1), (0.8, 1.55), (0.0, 1.2), (-0.8, 1.55), (-0.84, 3.1)]
    for z in (-0.7, 0.7):
        ch.add("Tabard", "White", poly_slab(out, 0.09, bev=0.025, seg=1, c=(0, 0, z)), on="UpperTorso", region="torso")
    ch.add("Tabard", "Crimson", box(0.14, 2.3, 0.12, c=(0.0, 2.6, -0.72)))
    ch.add("Tabard", "Crimson", poly_slab([(-0.8, 1.55), (-0.0, 1.2), (0.8, 1.55), (0.8, 1.68), (0.0, 1.33), (-0.8, 1.68)], 0.12, c=(0, 0, -0.72)))
    ch.add("Tabard", "Gold", star(8, 0.46, 0.2, 0.08, c=(0, 3.45, -0.76)))
    kit.belt(ch, "Crimson", "Gold", y=2.44, h=0.34)
    kit.tassets(ch, "Gold", "GoldDark", n=5, hang=0.7)
    kit.pauldron(ch, "Gold", "GoldDark", size=1.15, lames=2, tilt=16, spikes=0, depth=0.7, out=0.2)
    winged_pauldron(ch, "Gold", "GoldDark", "Gold", n=3)
    kit.gauntlets(ch, "Gold", "GoldDark")
    kit.leg_armor(ch, "Gold", "GoldDark", bevseg=2)
    kit.sabatons(ch, "Gold", "GoldDark")
    kit.cape(ch, "Crimson", "Gold", top=3.95, hem=0.6, w_top=1.7, w_hem=2.9, z=0.68, split=2.4)
    # glowing sword: golden winged guard, blade of light, light-burst star + ring (pop)
    at = (1.5, 2.3, -0.55)
    kit.sword(ch, "Sword", "RightHand", "Blade", "Gold", "Grip", length=3.1, width=0.26, thick=0.09, at=at, tilt=-18, wing=0.45)
    ang = math.radians(-18)
    tipy = at[1] + 3.1 * math.cos(ang)
    tipz = at[2] + 3.1 * math.sin(ang)
    ch.add("Burst", "Halo", star(10, 1.5, 0.45, 0.06, c=(at[0], tipy, tipz)), on="RightHand", region="armR")
    ch.add("Burst", "Halo", torus(1.2, 0.06, (at[0], tipy, tipz), seg=18, tseg=4, axis="Z"))
    # World-state FX: a gold ground ring and floating light feathers
    ch.add("FxRing", "Halo", torus(2.2, 0.05, (0, 0.06, 0), seg=28, tseg=4), on="LowerTorso", region="static", tier="World")
    for k in range(4):
        a = k * math.pi / 2
        ch.add("FxFeathers", "Halo", poly_slab([(0, -0.3), (0.1, 0), (0, 0.3), (-0.1, 0)], 0.04, c=(math.cos(a) * 2.1, 2.2 + 0.35 * k, math.sin(a) * 2.1)), on="LowerTorso", region="static", tier="World")
    sg = dict(period=5.0, start=1.0, dur=2.0)
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "X", 150, sig=dict(sg, shape="snap"))
    ch.joint("ReSig", jp("Elbow", 1), "swing", "X", 18, sig=dict(sg, shape="snap"))
    ch.joint("RwSig", jp("Wrist", 1), "swing", "X", -150, sig=dict(sg, shape="snap"))
    ch.joint("burstPop", (at[0], tipy, tipz), "pop", "X", 1.0, sig=dict(sg, shape="hump", u0=0.35))
    ch.joint("fxSpin", (0, 0, 0), "spin", "Y", 25)
    ch.joint("fxBob", (0, 0, 0), "bob", "Y", 0.15, 1.3)
    ch.joint("capeSig", (0, 3.95, 0.68), "swing", "X", 10, sig=dict(sg, shape="snap"))
    ch.group("Sword", "RightHand", "armR")
    ch.arm_sig(1, groups_hand=["Sword"], sh="RshSig", el="ReSig", wr="RwSig")
    ch.groups["Burst"]["extra"] = ["RshSig", "ReSig", "RwSig", "burstPop"]
    ch.groups["FxRing"]["extra"] = ["fxSpin"]
    ch.groups["FxFeathers"]["extra"] = ["fxSpin", "fxBob"]
    ch.finish_anim()
    return ch


def sir_ironclad():
    """Sir Ironclad (Secret, zone boss): a huge steel-and-blue knight with a gold-crowned great helm, giant pauldrons, a kite shield and a glowing greatsword."""
    ch = Char("SirIronclad", "Secret", "Knight's Keep", scale=2.2)
    ch.sig_label = "sword slam + shield flash"
    ch.colours(Under="#1E2848", Steel=("#B6BFCD", "Metal", 0.3, 0.8), SteelDark=("#7F8A9D", "Metal", 0.35, 0.8), Blue=("#2F62D2", "Metal", 0.35, 0.6), BlueDark=("#1D3F96", "Metal", 0.4, 0.6),
               Gold=("#F4BC3A", "Metal", 0.28, 0.8), Dark="#0B1124", Cape="#1F3F9C", Glow=("#9CE9FF", "Neon", 0.2, 0), Blade=("#C9EEFF", "Neon", 0.2, 0), Grip="#2A3350",
               Plume="#E9F3FF", PlumeBlue="#2F62D2", Shard=("#8FE4FF", "Neon", 0.2, 0), Rune=("#FFD66E", "Neon", 0.2, 0))
    hd = Head(1.05)
    standard_body(ch, dict(Head="Under", UpperTorso="Under", LowerTorso="Under", UpperArm="Under", LowerArm="Under", Hand="Under", UpperLeg="Under", LowerLeg="Under", Foot="Dark"),
                  build=dict(bw=1.2, bd=1.16, aw=1.28, lw=1.16), head=hd, q=3)
    ch.remove("Head")  # a full great helm covers the head
    kit.helm_great(ch, hd, "Steel", "Gold", "Dark", "Glow", crown="Gold")
    kit.plume(ch, "Plume", "Plume", (0, hd.at(1.5), 0.0), length=1.6, lift=0.9, sweep=1.5, width=0.34)
    kit.plume(ch, "PlumeBlue", "PlumeBlue", (0, hd.at(1.5) - 0.1, 0.25), length=1.4, lift=0.6, sweep=1.5, width=0.28)
    kit.chest_plate(ch, "Steel", "Gold", ridge=True, flare=1.12, lames=3, bevseg=3)
    out = [(-0.82, 3.98), (0.82, 3.98), (1.0, 3.2), (0.96, 1.5), (0.0, 1.1), (-0.96, 1.5), (-1.0, 3.2)]
    ch.add("Tabard", "Blue", poly_slab(out, 0.1, bev=0.03, seg=1, c=(0, 0, -0.74)), on="UpperTorso", region="torso")
    ch.add("Tabard", "Blue", poly_slab(out, 0.1, bev=0.03, seg=1, c=(0, 0, 0.74)))
    ch.add("Tabard", "Gold", poly_slab([(-0.96, 1.5), (0, 1.1), (0.96, 1.5), (0.96, 1.64), (0, 1.24), (-0.96, 1.64)], 0.13, c=(0, 0, -0.74)))
    kit.tower_emblem(ch, "Tabard", "Gold", (0, 3.1, -0.82), 1.9, on="UpperTorso", region="torso")
    kit.belt(ch, "BlueDark", "Gold", y=2.44, h=0.36, w=2.34, d=1.24)
    kit.tassets(ch, "SteelDark", "Gold", n=7, hang=0.85)
    kit.pauldron(ch, "Steel", "Gold", size=1.38, lames=3, tilt=18, spikes=3, depth=0.62, out=0.55)
    kit.gauntlets(ch, "SteelDark", "Gold")
    kit.leg_armor(ch, "Steel", "Gold", bevseg=2)
    kit.sabatons(ch, "SteelDark", "Gold")
    kit.cape(ch, "Cape", "Gold", top=3.98, hem=0.35, w_top=1.9, w_hem=3.4, z=0.8, split=2.3, ripple=0.14)
    at = (1.5, 2.3, -0.6)
    kit.sword(ch, "Sword", "RightHand", "Blade", "Gold", "Grip", length=3.8, width=0.32, thick=0.11, at=at, tilt=-16, wing=0.6)
    kit.shield(ch, "Shield", "Blue", "Steel", "Gold", "Gold", w=2.6, h=3.9, at=(-2.25, 2.85, -0.92))
    kit.tower_emblem(ch, "Shield", "Gold", (-2.25, 3.35, -0.92), 2.2)
    ch.add("Flash", "Glow", star(10, 1.5, 0.55, 0.06, c=(-2.25, 2.9, -1.5)), on="LeftLowerArm", region="armL")
    # World / Captured FX: rune ring + orbiting shards (World), a few shards (Captured), shockwave ring
    ch.add("FxRing", "Rune", torus(3.2, 0.06, (0, 0.06, 0), seg=32, tseg=4), on="LowerTorso", region="static", tier="World")
    for k in range(8):
        a = k * math.pi / 4
        ch.add("FxRing", "Rune", box(0.28, 0.04, 0.12, c=(math.cos(a) * 3.2, 0.1, math.sin(a) * 3.2)).rot(0, -math.degrees(a), 0, (math.cos(a) * 3.2, 0.1, math.sin(a) * 3.2)))
    for k in range(6):
        a = k * math.pi / 3
        ch.add("FxShards", "Shard", poly_slab([(0, -0.5), (0.18, 0), (0, 0.5), (-0.18, 0)], 0.1, c=(math.cos(a) * 2.7, 2.4 + 0.5 * (k % 3), math.sin(a) * 2.7)), on="LowerTorso", region="static", tier="World")
    for k in range(3):
        a = k * 2 * math.pi / 3
        ch.add("FxCap", "Shard", poly_slab([(0, -0.25), (0.09, 0), (0, 0.25), (-0.09, 0)], 0.06, c=(math.cos(a) * 1.9, 2.8 + 0.3 * k, math.sin(a) * 1.9)), on="LowerTorso", region="static", tier="Captured")
    ch.add("Shock", "Glow", torus(1.8, 0.09, (0, 0.1, -3.4), seg=24, tseg=4), on="LowerTorso", region="static")
    sg = dict(period=6.0, start=1.2, dur=2.0)
    ch.joint("RshSig", jp("Shoulder", 1), "swing", "X", 170, sig=dict(sg, shape="strike", imp=0.3))
    ch.joint("ReSig", jp("Elbow", 1), "swing", "X", 24, sig=dict(sg, shape="strike", imp=0.1))
    ch.joint("RwSig", jp("Wrist", 1), "swing", "X", -140, sig=dict(sg, shape="strike", imp=1.1))
    ch.joint("LshSig", jp("Shoulder", -1), "swing", "X", 34, sig=dict(sg, shape="hump", u0=0.55))
    ch.joint("flashPop", (-2.25, 2.9, -1.5), "pop", "X", 1.0, sig=dict(sg, shape="hump", u0=0.66))
    ch.joint("shockPop", (0, 0.1, -3.4), "pop", "X", 1.0, sig=dict(sg, shape="hump", u0=0.64))
    ch.joint("leanSig", (0, 2.4, 0), "swing", "X", 9, sig=dict(sg, shape="strike", imp=0.6))
    ch.joint("fxSpin", (0, 0, 0), "spin", "Y", 20)
    ch.joint("fxSpin2", (0, 0, 0), "spin", "Y", -35)
    ch.joint("fxBob", (0, 0, 0), "bob", "Y", 0.18, 1.2)
    ch.joint("plumeSway", (0, hd.at(1.4), 0.1), "swing", "X", 5, 1.7)
    ch.joint("capeA", (0, 3.98, 0.8), "swing", "X", 3, 1.3)
    ch.group("Sword", "RightHand", "armR")
    ch.group("Shield", "LeftLowerArm", "armL")
    ch.arm_sig(1, groups_hand=["Sword"], sh="RshSig", el="ReSig", wr="RwSig")
    ch.arm_sig(-1, groups_lower=["Shield", "Flash"], sh="LshSig")
    ch.groups["Flash"]["extra"] = ["LshSig", "flashPop"]
    ch.groups["Shock"]["extra"] = ["shockPop"]
    ch.groups["FxRing"]["extra"] = ["fxSpin"]
    ch.groups["FxShards"]["extra"] = ["fxSpin2", "fxBob"]
    ch.groups["FxCap"]["extra"] = ["fxSpin2", "fxBob"]
    for g in ("Plume", "PlumeBlue"):
        ch.groups[g]["extra"] = ["plumeSway"]
    for g in ("Tabard", "UpperTorso"):
        pass
    ch.finish_anim()
    return ch


CHARS = {"RookieSquire": squire, "ScrollPage": scroll_page, "TrainingDummy": training_dummy, "AppleArcher": apple_archer, "BannerBearer": banner_bearer,
         "ShieldKnight": shield_knight, "ForgeMaster": forge_master, "GoldenPaladin": golden_paladin, "SirIronclad": sir_ironclad}
