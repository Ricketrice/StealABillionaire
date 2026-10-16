# Shield Knight v4 boards. python3 -I tools/blender/assemble_sk4_035.py
import os
from PIL import Image, ImageDraw, ImageFont
P = os.path.expanduser("~/Pictures/035_preview")
O = os.path.join(P, "sk4")
DEV = os.path.join(P, "sk4_dev")
F = lambda b, n: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)
H1, H2, T = F(1, 28), F(1, 20), F(0, 15)
BG = (245, 246, 250)


def fit(im, w=None, h=None):
    if h:
        return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)


def load(name):
    f = os.path.join(O, name)
    return Image.open(f).convert("RGB") if os.path.exists(f) else None


def vs_reference():
    ref = Image.open(os.path.join(P, "Drill", "bestKnight.jpeg")).convert("RGB")
    H = 760
    tiles = [("REFERENCE (bestKnight, real Roblox render)", fit(ref, h=H))]
    for tag, label in (("neutral_front", "OURS: neutral light"), ("roblox_front", "OURS: Roblox-like sky + sun")):
        im = load("SK4_%s.png" % tag)
        if im:
            tiles.append((label, fit(im, h=H)))
    W = sum(t[1].width for t in tiles) + 20 * (len(tiles) + 1)
    img = Image.new("RGB", (W, H + 140), BG)
    d = ImageDraw.Draw(img)
    d.text((20, 14), "Shield Knight v4 next to the actual reference (original design: layout, markings and identity are ours)", font=H2, fill=(25, 30, 45))
    x = 20
    for label, im in tiles:
        d.text((x, 54), label, font=T, fill=(60, 65, 80))
        img.paste(im, (x, 84))
        x += im.width + 20
    img.save(os.path.join(O, "SK4_1_vs_reference.png"))


def views():
    names = [("roblox_front", "front"), ("roblox_tq", "three-quarter"), ("roblox_back", "back"), ("roblox_side", "side")]
    ims = [(l, load("SK4_%s.png" % n)) for n, l in names]
    ims = [(l, i) for l, i in ims if i]
    S = 640
    img = Image.new("RGB", (S * len(ims), S + 70), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 14), "Shield Knight v4: Roblox-like lighting (sky + sun, standard tonemap), all PBR maps, no VFX", font=H2, fill=(25, 30, 45))
    for k, (l, i) in enumerate(ims):
        d.text((k * S + 12, 44), l, font=T, fill=(60, 65, 80))
        img.paste(i.resize((S, S), Image.LANCZOS), (k * S, 70))
    img.save(os.path.join(O, "SK4_2_views.png"))


def closeups():
    keys = [("helm", "helmet + faceplate"), ("helm_side", "helmet side"), ("chest", "breastplate"), ("pauldron", "pauldron"), ("arm", "arm segments"), ("waist", "waist + tassets"), ("legs", "greaves + poleyns"), ("boots", "sabatons"), ("shield", "shield"), ("backc", "back plate")]
    S = 520
    cols = 5
    rows = (len(keys) + cols - 1) // cols
    img = Image.new("RGB", (S * cols, 70 + S * rows), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 14), "Armour close-ups (Roblox-like light, full PBR maps)", font=H2, fill=(25, 30, 45))
    for k, (key, label) in enumerate(keys):
        i = load("SK4_roblox_%s.png" % key)
        if not i:
            continue
        x, y = (k % cols) * S, 70 + (k // cols) * S
        img.paste(i.resize((S - 4, S - 4), Image.LANCZOS), (x, y))
        d.text((x + 10, y + 8), label, font=T, fill=(235, 238, 245))
    img.save(os.path.join(O, "SK4_3_armour_closeups.png"))


def construction():
    ims = [load("SK4_construct_%s.png" % v) for v in ("front", "tq", "back")]
    tex = []
    for k in ("ColorMap", "MetalnessMap", "RoughnessMap", "NormalMap"):
        f = os.path.join(DEV, "tex", "ShieldKnight_%s_1024.png" % k)
        if os.path.exists(f):
            tex.append((k, Image.open(f).convert("RGB")))
    S = 620
    img = Image.new("RGB", (S * 3, 70 + S + 40 + 400), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 14), "Construction: one colour per mesh group with outlines (top), and the baked PBR atlas (bottom)", font=H2, fill=(25, 30, 45))
    for k, i in enumerate(ims):
        if i:
            img.paste(i.resize((S, S), Image.LANCZOS), (k * S, 70))
    for k, (name, t) in enumerate(tex):
        w = (S * 3) // 4
        img.paste(t.resize((380, 380), Image.LANCZOS), (20 + k * 460, 70 + S + 40))
        d.text((20 + k * 460, 70 + S + 14), name + " (1024)", font=T, fill=(60, 65, 80))
    img.save(os.path.join(O, "SK4_4_construction_and_maps.png"))


if __name__ == "__main__":
    vs_reference(); views(); closeups(); construction(); print("ok")
