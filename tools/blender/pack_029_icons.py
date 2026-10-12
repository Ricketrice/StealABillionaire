# Packs assets/export/ui/icons/*.png (256x256) into 1024x1024 sprite sheets (4x4 tiles each):
#   python3 tools/blender/pack_029_icons.py
# Writes assets/export/ui/IconSheet1.png, IconSheet2.png and icons.json, and prints the Luau table
# for UITheme.ICONS (name = { sheet, x, y }). Order = ORDER below, so tiles never move when icons are
# added at the end.
import json, os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "export", "ui", "icons")
OUT = os.path.join(ROOT, "assets", "export", "ui")
TILE, PER_ROW, PER_SHEET = 256, 4, 16
ORDER = [
    "cash", "coin", "gem", "shop", "backpack", "book", "gift", "calendar", "clock", "settings", "close", "lock",
    "check", "star", "trophy", "arena", "base", "parade", "x2", "vip", "slots", "plus", "hourglass", "moon",
    "music", "sound", "sparkle", "quest", "bolt", "flag", "heart",
]
missing = [n for n in ORDER if not os.path.exists(os.path.join(SRC, n + ".png"))]
assert not missing, missing
layout, sheets = {}, []
for i, name in enumerate(ORDER):
    sheet, slot = divmod(i, PER_SHEET)
    if sheet == len(sheets):
        sheets.append(Image.new("RGBA", (TILE * PER_ROW, TILE * PER_ROW), (0, 0, 0, 0)))
    x, y = (slot % PER_ROW) * TILE, (slot // PER_ROW) * TILE
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    assert im.size == (TILE, TILE), (name, im.size)
    sheets[sheet].paste(im, (x, y))
    layout[name] = {"sheet": sheet + 1, "x": x, "y": y}
for i, im in enumerate(sheets):
    im.save(os.path.join(OUT, f"IconSheet{i + 1}.png"), optimize=True)
with open(os.path.join(OUT, "icons.json"), "w") as f:
    json.dump({"tile": TILE, "sheets": len(sheets), "icons": layout}, f, indent=1)
print("\n".join(f'\t{n} = {{ {v["sheet"]}, {v["x"]}, {v["y"]} }},' for n, v in layout.items()))
