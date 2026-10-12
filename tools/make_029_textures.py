# Makes the two Check-UI style textures (D18) for the 029 UI kit, original and code-generated:
#   python3 tools/make_029_textures.py
# Writes assets/export/ui/Checker.png (64 x 64, tileable 2 x 2 checkerboard) and
# assets/export/ui/Sunburst.png (512 x 512, 16 rays fading out from the centre). Both are white on
# transparent so UITheme tints them with ImageColor3. Upload both as Images (owner's account, D11) and
# put the ids in UITheme.TEXTURES.
import math, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "export", "ui")

# Checkerboard: two opaque white squares on the diagonal, so it tiles seamlessly.
checker = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
d = ImageDraw.Draw(checker)
d.rectangle((0, 0, 31, 31), fill=(255, 255, 255, 255))
d.rectangle((32, 32, 63, 63), fill=(255, 255, 255, 255))
checker.save(os.path.join(OUT, "Checker.png"), optimize=True)

# Sunburst: drawn at 4x and scaled down for smooth ray edges.
S, RAYS = 2048, 16
rays = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(rays)
c = S / 2
for i in range(RAYS):
    a0 = (i / RAYS) * 2 * math.pi
    a1 = a0 + math.pi / RAYS  # rays and gaps the same width
    d.polygon([(c, c), (c + math.cos(a0) * S, c + math.sin(a0) * S), (c + math.cos(a1) * S, c + math.sin(a1) * S)], fill=255)
fade = Image.new("L", (S, S), 0)
px = fade.load()
for y in range(0, S, 4):
    for x in range(0, S, 4):
        r = math.hypot(x - c, y - c) / c
        v = int(255 * max(0.0, 1 - r) ** 1.4)
        for yy in range(y, min(y + 4, S)):
            for xx in range(x, min(x + 4, S)):
                px[xx, yy] = v
fade = fade.filter(ImageFilter.GaussianBlur(6))
alpha = Image.composite(fade, Image.new("L", (S, S), 0), rays)
sun = Image.new("RGBA", (S, S), (255, 255, 255, 255))
sun.putalpha(alpha)
sun = sun.resize((512, 512), Image.LANCZOS)
sun.save(os.path.join(OUT, "Sunburst.png"), optimize=True)
print("wrote Checker.png and Sunburst.png")
