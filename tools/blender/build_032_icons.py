# Milestone 032 icons (Speed stat, 6 speed trails, Boss Heist), same look as the 029 sheet (D14):
#   flatpak run org.blender.Blender -b -P "$PWD/tools/blender/build_032_icons.py" [-- name name ...]
# Uses the shapes, materials and renderer from build_029_icons.py. Renders assets/export/ui/icons/<name>.png
# (256x256, transparent); pack them into IconSheet3 with tools/blender/pack_032_icons.py.
import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_029_icons as k  # noqa: E402

mat, star_points, arc_band = k.mat, k.star_points, k.arc_band


def streaks(I, key="white", x0=-1.15, zs=(0.35, 0.0, -0.35), lens=(0.55, 0.8, 0.55)):
    # three rounded speed lines behind a shape (to the left)
    for z, ln in zip(zs, lens):
        I.box((ln, 0.14, 0.14), mat(key), (x0 - ln / 2 + 0.2, 0.05, z), bevel=0.06)


def i_shoe(I):
    # chunky sneaker seen from the side, toe to the right, little gold wing at the heel
    I.prism([(-0.95, -0.55), (1.05, -0.55), (1.12, -0.38), (1.0, -0.25), (-0.95, -0.25)], 0.85, mat("white"), bevel=0.08)
    I.prism([(-0.9, -0.28), (-0.9, 0.55), (-0.55, 0.62), (-0.25, 0.25), (0.45, 0.05), (0.95, -0.05), (1.02, -0.28)], 0.8, mat("red"), (0, 0, 0), bevel=0.12)
    I.prism([(0.3, 0.06), (0.95, -0.06), (1.02, -0.28), (0.3, -0.28)], 0.84, mat("white"), (0, -0.01, 0), bevel=0.06)
    for i in range(3):
        I.box((0.32, 0.1, 0.08), mat("cream"), (-0.35 + i * 0.22, -0.43, 0.35 - i * 0.1), (0, -25, 0), bevel=0.03)
    I.prism([(-0.95, 0.35), (-1.45, 0.75), (-1.25, 0.35), (-1.55, 0.3), (-1.2, 0.05), (-0.95, 0.05)], 0.2, mat("gold"), (0, -0.4, 0), bevel=0.04)
    I.box((1.98, 0.86, 0.1), mat("greyDark"), (0.08, 0, -0.56), bevel=0.04)


def i_vault(I):
    I.box((2.0, 0.5, 2.0), mat("greyDark"), (0, 0.2, 0), bevel=0.14)
    I.cyl(0.82, 0.3, mat("grey"), (0, -0.1, 0), (90, 0, 0), bevel=0.06)
    I.torus(0.88, 0.07, mat("gold"), (0, -0.22, 0))
    I.torus(0.36, 0.06, mat("gold"), (0, -0.32, 0))
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        I.box((0.08, 0.08, 0.5), mat("gold"), (math.cos(r) * 0.22, -0.32, math.sin(r) * 0.22), (0, -a + 90, 0), bevel=0.02)
    I.sphere(0.12, mat("gold"), (0, -0.36, 0))
    I.box((0.12, 0.2, 0.42), mat("grey"), (-0.98, -0.02, 0.5), bevel=0.04)
    I.box((0.12, 0.2, 0.42), mat("grey"), (-0.98, -0.02, -0.5), bevel=0.04)


def i_robot(I):
    # the security robot's friendly face: cream head, dark visor, cyan eyes, amber siren
    I.box((1.9, 1.2, 1.4), mat("cream"), (0, 0, -0.15), bevel=0.4)
    I.box((1.5, 0.2, 0.75), mat("charcoal"), (0, -0.55, -0.1), bevel=0.18)
    for x in (-0.38, 0.38):
        I.sphere(0.18, mat("cyan", 0.15), (x, -0.68, 0.0), scale=(1, 0.4, 1.2))
    I.box((0.4, 0.08, 0.08), mat("cyan", 0.15), (0, -0.68, -0.28), bevel=0.03)
    for x in (-1.0, 1.0):
        I.sphere(0.24, mat("gold"), (x, 0, -0.15), scale=(0.6, 1, 1))
    I.cyl(0.32, 0.14, mat("greyDark"), (0, 0, 0.62))
    I.sphere(0.3, mat("orange", 0.15), (0, 0, 0.7), scale=(1, 1, 1.05))


def i_shield(I):
    pts = [(-0.95, 0.85), (0, 1.1), (0.95, 0.85), (0.9, -0.05), (0.55, -0.65), (0, -1.05), (-0.55, -0.65), (-0.9, -0.05)]
    I.prism(pts, 0.4, mat("blue"), bevel=0.12)
    inner = [(x * 0.7, z * 0.7 + 0.02) for x, z in pts]
    I.prism(inner, 0.2, mat("sky"), (0, -0.2, 0), bevel=0.06)
    I.prism(star_points(5, 0.38, 0.17), 0.12, mat("gold"), (0, -0.33, 0.05), bevel=0.03)


def i_capsule(I):
    I.sphere(0.95, mat("gold"), (0, 0, -0.2), scale=(1, 1, 0.75))
    I.sphere(0.92, mat("sky", 0.1), (0, 0, 0.1), scale=(1, 1, 0.95))
    I.torus(0.98, 0.12, mat("purple"), (0, 0, -0.05), rot=(90, 0, 0))
    I.prism(star_points(5, 0.3, 0.13), 0.1, mat("white"), (0, -0.85, -0.45), bevel=0.02)
    I.prism(star_points(4, 0.22, 0.07), 0.08, mat("white"), (-0.35, -0.85, 0.45), bevel=0.0)


# Trails: each is its symbol racing right with three speed lines behind it --------------------------------
def i_trail_bubble(I):
    streaks(I, "sky")
    for (x, z, r) in ((0.35, 0.1, 0.62), (-0.35, -0.55, 0.3), (0.95, 0.75, 0.25)):
        I.sphere(r, mat("sky", 0.08), (x, 0, z))
        I.sphere(r * 0.25, mat("white", 0.05), (x - r * 0.4, -r * 0.8, z + r * 0.4))


def i_trail_leaf(I):
    streaks(I, "green")
    # pointed leaf: width follows sin(t) along its length, tip at the top right, small stem
    n, leaf = 14, []
    for i in range(n + 1):
        t = i / n
        leaf.append((0.5 * math.sin(math.pi * t) ** 0.8, -1.0 + 2.0 * t))
    leaf += [(-x, z) for x, z in reversed(leaf[1:-1])]
    I.prism(leaf, 0.22, mat("green"), (0.35, 0, 0.05), (0, 40, 0), bevel=0.06)
    I.box((0.07, 0.08, 1.6), mat("greenDark"), (0.35, -0.13, 0.05), (0, 40, 0), bevel=0.03)
    I.box((0.09, 0.12, 0.45), mat("greenDark"), (0.35 - 0.95 * math.sin(math.radians(40)), 0, 0.05 - 0.95 * math.cos(math.radians(40))), (0, 40, 0), bevel=0.03)


def i_trail_star(I):
    streaks(I, "yellow")
    I.prism(star_points(5, 1.0, 0.45), 0.45, mat("yellow"), (0.35, 0, 0), bevel=0.1)
    I.prism(star_points(4, 0.25, 0.08), 0.2, mat("white"), (1.05, -0.2, 0.85), bevel=0.02)


def i_trail_comet(I):
    # round orange-gold comet head with a tapered tail (no fire, kid-friendly)
    I.prism([(-1.4, 0.15), (0.2, 0.6), (0.3, -0.6), (-1.4, -0.15)], 0.35, mat("orange"), (0, 0.15, 0), bevel=0.08)
    I.prism([(-0.9, 0.1), (0.2, 0.38), (0.3, -0.38), (-0.9, -0.1)], 0.3, mat("yellow"), (0, -0.05, 0), bevel=0.06)
    I.sphere(0.62, mat("gold"), (0.45, 0, 0))
    I.sphere(0.18, mat("white", 0.05), (0.25, -0.5, 0.25))


def i_trail_rainbow(I):
    keys = ["red", "orange", "yellow", "green", "blue", "purple"]
    for i, key in enumerate(keys):
        r_out = 1.15 - i * 0.16
        I.prism(arc_band(r_out - 0.16, r_out, 0, 180), 0.3, mat(key), (0, 0, -0.45), bevel=0.03)
    I.sphere(0.32, mat("white"), (-0.85, -0.2, -0.5), scale=(1.3, 1, 0.8))
    I.sphere(0.32, mat("white"), (0.85, -0.2, -0.5), scale=(1.3, 1, 0.8))


def i_trail_gold(I):
    streaks(I, "gold")
    for (x, z, ry) in ((0.55, 0.45, -20), (0.05, -0.35, 15), (0.95, -0.45, 30)):
        I.cyl(0.48, 0.18, mat("gold"), (x, 0, z), (90, ry, 0), bevel=0.05)
        I.text("$", 0.6, mat("yellow"), (x, -0.12, z), extrude=0.03)
    I.prism(star_points(4, 0.3, 0.09), 0.15, mat("white"), (-0.45, -0.25, 0.75), bevel=0.0)


ICONS = [
    ("shoe", i_shoe), ("vault", i_vault), ("robot", i_robot), ("shield", i_shield), ("capsule", i_capsule),
    ("trail_bubble", i_trail_bubble), ("trail_leaf", i_trail_leaf), ("trail_star", i_trail_star),
    ("trail_comet", i_trail_comet), ("trail_rainbow", i_trail_rainbow), ("trail_gold", i_trail_gold),
]

wanted = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
for name, build in ICONS:
    if not wanted or name in wanted:
        k.render(name, build)
