# Packs the 032 icons (assets/export/ui/icons/*.png, 256x256) into one new sheet, IconSheet3.png (4x4 tiles),
# so the uploaded 029 sheets never change:
#   python3 tools/blender/pack_032_icons.py
# Writes assets/export/ui/IconSheet3.png + icons032.json and prints the Luau rows for UITheme.ICONS.
import json, os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "export", "ui", "icons")
OUT = os.path.join(ROOT, "assets", "export", "ui")
TILE, PER_ROW, SHEET = 256, 4, 3
ORDER = [
    "shoe", "vault", "robot", "shield", "capsule", "trail_bubble", "trail_leaf", "trail_star", "trail_comet",
    "trail_rainbow", "trail_gold",
]
missing = [n for n in ORDER if not os.path.exists(os.path.join(SRC, n + ".png"))]
assert not missing, missing
assert len(ORDER) <= PER_ROW * PER_ROW
sheet, layout = Image.new("RGBA", (TILE * PER_ROW, TILE * PER_ROW), (0, 0, 0, 0)), {}
for i, name in enumerate(ORDER):
    x, y = (i % PER_ROW) * TILE, (i // PER_ROW) * TILE
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    assert im.size == (TILE, TILE), (name, im.size)
    sheet.paste(im, (x, y))
    layout[name] = {"sheet": SHEET, "x": x, "y": y}
sheet.save(os.path.join(OUT, f"IconSheet{SHEET}.png"), optimize=True)
with open(os.path.join(OUT, "icons032.json"), "w") as f:
    json.dump({"tile": TILE, "sheet": SHEET, "icons": layout}, f, indent=1)
print("\n".join(f'\t{n} = {{ {v["sheet"]}, {v["x"]}, {v["y"]} }},' for n, v in layout.items()))
