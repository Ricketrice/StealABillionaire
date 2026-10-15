# Assembles the Aquaris concept tiles (~/Pictures/035_preview/concept/tiles, from concept_035_aquaris_lock.py) into design sheets with system Python + PIL.
import os
VARS = {"LOCK": dict(label="Aquaris concept lock (B base, A restraint)")}
OUT = os.path.expanduser("~/Pictures/035_preview/concept_lock")
TMP = os.path.join(OUT, "tiles")
os.makedirs(OUT, exist_ok=True)
from PIL import Image, ImageDraw

names = ("front", "side", "three-quarter", "hero", "silhouette")
sheets = []
for key, v in VARS.items():
    sheet = Image.new("RGB", (620 * 5, 620 + 50), (240, 243, 248))
    d = ImageDraw.Draw(sheet)
    d.text((16, 14), "Aquaris concept %s" % v["label"], fill=(20, 40, 90))
    for i, n in enumerate(names):
        im = Image.open(os.path.join(TMP, "%s_%s.png" % (key, n))).convert("RGB")
        sheet.paste(im, (620 * i, 50))
        d.text((620 * i + 14, 52), n, fill=(20, 40, 90))
    sheet.save(os.path.join(OUT, "aquaris_lock_sheet.png"))
    sheets.append(sheet)
print("CONCEPT_DONE")
