# Shield Knight v3 boards: v2 (left / top) vs v3 (right / bottom). python3 -I tools/blender/assemble_sk3_035.py
import os
from PIL import Image, ImageDraw, ImageFont
P = os.path.expanduser("~/Pictures/035_preview")
V2, V3 = os.path.join(P, "sk2"), os.path.join(P, "sk3")
BG = (222, 227, 236)
F = lambda b, n: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)
H1, H2, T = F(1, 28), F(1, 20), F(0, 15)


def on_bg(p):
    im = Image.open(p).convert("RGBA")
    o = Image.new("RGBA", im.size, BG + (255,))
    o.alpha_composite(im)
    return o.convert("RGB")


def turnaround():
    W, rowH = 1500, 760
    img = Image.new("RGB", (W, 110 + rowH * 3), (245, 246, 250))
    d = ImageDraw.Draw(img)
    d.text((24, 14), "Shield Knight v3 (right) vs v2 (left), same scale", font=H1, fill=(25, 30, 45))
    d.text((24, 62), "v2: 4,920 tris, 75 parts", font=H2, fill=(120, 125, 140))
    d.text((W // 2 + 24, 62), "v3: 5,746 tris, 64 parts (Epic ceiling 8,000 / 80)", font=H2, fill=(30, 120, 60))
    for i, v in enumerate(("front", "tq", "back")):
        im = on_bg(os.path.join(V3, "SK_pair_%s.png" % v)).resize((W - 20, (W - 20) // 2), Image.LANCZOS)
        img.paste(im, (10, 110 + i * rowH))
        d.text((24, 112 + i * rowH), {"front": "front", "tq": "three-quarter", "back": "back"}[v], font=H2, fill=(60, 65, 80))
    img.save(os.path.join(V3, "SK3_1_v2_vs_v3_turnaround.png"))


def closeups():
    cols = [("helm", "1+2  helmet + face"), ("crest", "1  crest + plume"), ("chest", "3  chest focal point"), ("legs", "4  thighs, knees, greaves"), ("boots", "4  sabatons"), ("shield", "5  signature shield")]
    S = 340
    img = Image.new("RGB", (S * len(cols), 100 + S * 2 + 30), (245, 246, 250))
    d = ImageDraw.Draw(img)
    d.text((16, 12), "The five requested changes: v2 (top row) vs v3 (bottom row)", font=H1, fill=(25, 30, 45))
    for c, (k, label) in enumerate(cols):
        d.text((c * S + 12, 62), label, font=H2, fill=(60, 65, 80))
        for r, (dirp, tag) in enumerate(((V2, "new"), (V3, "v3"))):
            f = os.path.join(dirp, "SK_%s_%s.png" % (tag, k))
            if not os.path.exists(f):
                continue
            img.paste(on_bg(f).resize((S - 6, S - 6), Image.LANCZOS), (c * S + 3, 96 + r * S))
    d.text((16, 100 + S * 2), "Same camera per column.", font=T, fill=(70, 75, 90))
    img.save(os.path.join(V3, "SK3_2_five_changes_closeups.png"))


if __name__ == "__main__":
    turnaround(); closeups(); print("ok")
