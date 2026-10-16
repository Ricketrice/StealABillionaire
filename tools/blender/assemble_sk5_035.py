# Shield Knight v4 vs v5 board. python3 -I tools/blender/assemble_sk5_035.py
import os
from PIL import Image, ImageDraw, ImageFont
O = os.path.expanduser("~/Pictures/035_preview/sk5")
F = lambda b, n: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)
H1, H2, T = F(1, 26), F(1, 18), F(0, 14)
BG = (245, 246, 250)


def ld(n):
    f = os.path.join(O, n)
    return Image.open(f).convert("RGB") if os.path.exists(f) else None


def board():
    cols = [("front", "front"), ("tq", "three-quarter"), ("back", "back"), ("nogear_front", "no weapons / shield")]
    S = 470
    W = 130 + S * len(cols) + 300
    img = Image.new("RGB", (W, 100 + S * 2 + 20), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Shield Knight: V4 (top) vs V5 (bottom). Roblox-like sky + sun light, full PBR maps, no VFX", font=H1, fill=(25, 30, 45))
    for c, (k, label) in enumerate(cols):
        d.text((130 + c * S + 8, 62), label, font=H2, fill=(60, 65, 80))
    d.text((130 + len(cols) * S + 20, 62), "128 px", font=H2, fill=(60, 65, 80))
    for r, (ver, label, col) in enumerate((("SK4", "V4", (150, 60, 60)), ("SK5", "V5", (40, 120, 70)))):
        y = 90 + r * S
        d.text((16, y + S // 2), label, font=H1, fill=col)
        for c, (k, _) in enumerate(cols):
            im = ld("%s_roblox_%s.png" % (ver, k))
            if im:
                img.paste(im.resize((S, S), Image.LANCZOS), (130 + c * S, y))
        ic = ld("%s_roblox_icon.png" % ver)
        if ic:
            x0 = 130 + len(cols) * S + 20
            img.paste(ic, (x0, y + 20))
            img.paste(ic.resize((256, 256), Image.NEAREST), (x0, y + 160))
            d.text((x0, y + 430), "native / 2x zoom", font=T, fill=(90, 95, 110))
    img.save(os.path.join(O, "SK5_1_v4_vs_v5.png"))


def closeups():
    keys = [("helm", "helmet"), ("chest", "chest"), ("boots", "boots")]
    ims = [(l, ld("SK5_roblox_%s.png" % k)) for k, l in keys]
    cons = ld("SK5_construct_front.png"), ld("SK5_construct_tq.png")
    nt = ld("SK5_neutral_front.png")
    S = 520
    img = Image.new("RGB", (S * 3, S * 2 + 90), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "V5 close-ups (top), neutral light + construction by mesh group (bottom)", font=H1, fill=(25, 30, 45))
    for k, (l, im) in enumerate(ims):
        if im:
            img.paste(im.resize((S, S), Image.LANCZOS), (k * S, 60))
            d.text((k * S + 10, 66), l, font=H2, fill=(235, 238, 245))
    for k, im in enumerate([nt] + list(cons)):
        if im and k < 3:
            img.paste(im.resize((S, S), Image.LANCZOS), (k * S, 60 + S))
    img.save(os.path.join(O, "SK5_2_v5_closeups.png"))


if __name__ == "__main__":
    board(); closeups(); print("ok")
