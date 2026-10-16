# One comparison sheet: reference (bestKnight) vs V5 vs the modifier-based proof, upper body at the SAME height. python3 -I tools/blender/proof/sheet.py
import os
from PIL import Image, ImageDraw, ImageFont
P = os.path.expanduser("~/Pictures/035_preview")
F = lambda b, n: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)
H1, H2, T = F(1, 26), F(1, 18), F(0, 14)
BG = (245, 246, 250)
H = 640


def crop(path, box, h=H):
    im = Image.open(path).convert("RGB")
    c = im.crop(box)
    return c.resize((int(c.width * h / c.height), h), Image.LANCZOS)


ref = crop(os.path.join(P, "Drill", "bestKnight.jpeg"), (300, 100, 960, 640))
v5 = crop(os.path.join(P, "sk5", "SK5_neutral_front.png"), (110, 70, 790, 520))
pf = crop(os.path.join(P, "proof", "proof_front.png"), (95, 95, 605, 460))
pt = crop(os.path.join(P, "proof", "proof_tq.png"), (95, 95, 605, 460))
tiles = [("REFERENCE (bestKnight): real Roblox render, textured", ref), ("V5 (kit035 procedural, textured): neutral light", v5), ("PROOF (modifier-based): front, plain materials, neutral light", pf), ("PROOF: three-quarter", pt)]
W = sum(t[1].width for t in tiles) + 20 * (len(tiles) + 1)
close = [Image.open(os.path.join(P, "proof", "proof_%s.png" % n)).convert("RGB") for n in ("helm", "shoulder", "chest")]
CS = 480
img = Image.new("RGB", (W, 120 + H + CS + 90), BG)
d = ImageDraw.Draw(img)
d.text((20, 14), "Upper-body quality at the same height: reference vs V5 vs the new modifier-based proof (helmet, shoulders, chest only)", font=H2, fill=(25, 30, 45))
x = 20
for label, im in tiles:
    d.text((x, 54), label, font=T, fill=(60, 65, 80))
    img.paste(im, (x, 84))
    x += im.width + 20
d.text((20, 100 + H), "Proof close-ups (neutral light, restrained materials, no wear maps / VFX): helmet, shoulder, chest", font=H2, fill=(25, 30, 45))
x = 20
for im in close:
    img.paste(im.resize((CS, CS), Image.LANCZOS), (x, 130 + H))
    x += CS + 20
img.save(os.path.join(P, "proof", "PROOF_comparison_sheet.png"))
print("ok", img.size)
