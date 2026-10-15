# Assembles the Aquaris v5 (zone boss) tiles into one sheet. Row 1 FX OFF, row 2 FX ON (world spawn), row 3 scale previews.
import os
from PIL import Image, ImageDraw
OUT = os.path.expanduser("~/Pictures/035_preview/concept_v5")
W = 620
rows = (
    ("FX OFF (model only)", "off", ("front", "side", "three-quarter", "hero", "silhouette")),
    ("FX ON - world spawn (full water aura)", "on", ("front", "side", "three-quarter", "hero", "wide")),
    ("Scale previews with a 5-stud noob: world (x3) | carried (x1.3) | on a pad (x1.6) | 128px icon + icon silhouette", "sc", ("world", "carried", "pad", "icon", "icon_sil")),
)
sheet = Image.new("RGB", (W * 5, (W + 40) * 3 + 40), (240, 243, 248))
d = ImageDraw.Draw(sheet)
d.text((16, 12), "Aquaris v5 - ultra-rare zone boss (original design)", fill=(20, 40, 90))
for r, (label, pre, names) in enumerate(rows):
    y0 = 40 + r * (W + 40)
    d.text((16, y0 + 4), label, fill=(20, 40, 90))
    for i, n in enumerate(names):
        im = Image.open(os.path.join(OUT, "tiles", "%s_%s.png" % (pre, n))).convert("RGB")
        if im.width < W:
            im = im.resize((W, W), Image.NEAREST)  # the 128px icons, enlarged without smoothing so you see the real pixels
        sheet.paste(im, (W * i, y0 + 40))
        d.text((W * i + 14, y0 + 44), n, fill=(255, 255, 255) if pre == "on" else (20, 40, 90))
sheet.save(os.path.join(OUT, "aquaris_concept_v5_sheet.png"))
print("SHEET_DONE")
