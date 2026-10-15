# Assembles the Aquaris concept tiles (~/Pictures/035_preview/concept/tiles, from concept_035_aquaris.py) into design sheets with system Python + PIL.
import os
VARS = {"A": dict(label="A  balanced"), "B": dict(label="B  fiercer"), "C": dict(label="C  younger, still cool")}
OUT = os.path.expanduser("~/Pictures/035_preview/concept")
TMP = os.path.join(OUT, "tiles")
os.makedirs(OUT, exist_ok=True)
from PIL import Image, ImageDraw

names = ("front", "side", "three-quarter", "silhouette")
sheets = []
for key, v in VARS.items():
    sheet = Image.new("RGB", (620 * 4, 620 + 50), (240, 243, 248))
    d = ImageDraw.Draw(sheet)
    d.text((16, 14), "Aquaris concept %s" % v["label"], fill=(20, 40, 90))
    for i, n in enumerate(names):
        im = Image.open(os.path.join(TMP, "%s_%s.png" % (key, n))).convert("RGB")
        sheet.paste(im, (620 * i, 50))
        d.text((620 * i + 14, 52), n, fill=(20, 40, 90))
    sheet.save(os.path.join(OUT, "aquaris_concept_%s.png" % key))
    sheets.append(sheet)
allsheet = Image.new("RGB", (sheets[0].width, sum(s.height for s in sheets)), (240, 243, 248))
y = 0
for s in sheets:
    allsheet.paste(s, (0, y))
    y += s.height
allsheet.save(os.path.join(OUT, "aquaris_concept_all.png"))
print("CONCEPT_DONE")
