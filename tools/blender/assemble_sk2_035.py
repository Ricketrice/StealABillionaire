# Shield Knight v2 benchmark boards (PIL): reference gap analysis, old-vs-new turnaround, armour close-ups.
#   python3 -I tools/blender/assemble_sk2_035.py     (reads ~/Pictures/035_preview/sk2 + the reference images in .../Drill)
import os
from PIL import Image, ImageDraw, ImageFont
O = os.path.expanduser("~/Pictures/035_preview/sk2")
DR = os.path.expanduser("~/Pictures/035_preview/Drill")
BG = (222, 227, 236)
F = lambda n, sz: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if n else ""), sz)
H1, H2, T, TS = F(1, 28), F(1, 20), F(0, 15), F(0, 13)


def on_bg(p, bg=BG):
    im = Image.open(p).convert("RGBA")
    o = Image.new("RGBA", im.size, bg + (255,))
    o.alpha_composite(im)
    return o.convert("RGB")


def wrap(d, text, font, x, y, width, fill=(40, 45, 60), lh=19):
    words, line = text.split(), ""
    for w in words:
        if d.textlength(line + " " + w, font=font) > width and line:
            d.text((x, y), line, font=font, fill=fill); y += lh; line = w
        else:
            line = (line + " " + w).strip()
    d.text((x, y), line, font=font, fill=fill)
    return y + lh


def crop_ref(name, box, h):
    im = Image.open(os.path.join(DR, name)).convert("RGB")
    w0, h0 = im.size
    c = im.crop((int(box[0] * w0), int(box[1] * h0), int(box[2] * w0), int(box[3] * h0)))
    return c.resize((int(c.width * h / c.height), h), Image.LANCZOS)


def gap():
    W = 2000
    img = Image.new("RGB", (W, 930), (245, 246, 250))
    d = ImageDraw.Draw(img)
    d.text((24, 16), "B1 Shield Knight vs the references: where the quality gap comes from", font=H1, fill=(25, 30, 45))
    old = on_bg(os.path.join(O, "SK_old_front.png")).resize((480, 480), Image.LANCZOS)
    img.paste(old, (24, 70))
    d.text((24, 556), "B1 Shield Knight (rejected)", font=H2, fill=(180, 40, 40))
    d.text((24, 584), "4,918 tris, 57 parts", font=T, fill=(70, 75, 90))
    refs = [("amour1.jpeg", (0.15, 0.0, 0.85, 1.0), "armor1 = amour1.jpeg (file name typo): Roblox-style torso. Keeled breastplate, V chevron lames, angular layered pauldrons with lips and studs, hanging tasset lames. Arms and legs stay default blocks, so we copy none of that."),
            ("legendary1.jpeg", (0.0, 0.0, 0.38, 1.0), "legendary1: heroic proportions (long legs, V torso, small head); thick plates with raised trim lines, overlapping straps and a tabard; front, side and back all read."),
            ("secret1.jpeg", (0.1, 0.0, 0.92, 1.0), "secret1: heavy ornate silhouette, tapering waist, huge shoulders and thighs; trim as raised bands that follow the plate contours."),
            ("normal1.jpeg", (0.07, 0.12, 0.40, 1.0), "normal1: layered cloth, leather and mail on real anatomy (the Standard tier target): overlap, folds, straps, patches.")]
    x = 540
    for fn, box, cap in refs:
        c = crop_ref(fn, box, 440)
        if x + c.width > W - 20:
            c = c.resize((W - 20 - x, int(c.height * (W - 20 - x) / c.width)))
        img.paste(c, (x, 70))
        wrap(d, cap, TS, x, 520, c.width, lh=17)
        x += c.width + 14
    d.text((24, 640), "Modelling limitations behind the gap (measured on the B1 model)", font=H2, fill=(25, 30, 45))
    pts = [
        "1. The visible body IS the R15 body: 15 chamfered boxes (blocky, stumpy proportions: legs 2.0 of 5.2 studs, no waist, no shoulder mass). 1,344 of the 4,918 triangles (27%) are those boxes, mostly hidden under armour.",
        "2. Armour is a shell hugging each box: one thin skin, no thickness at the edges, no layering (plates never overlap or step), no flanged rims. Every edge gets the same uniform bevel, so nothing looks forged.",
        "3. Primitives instead of contours: frustums, domes and lathes. No keel or ridge, no chevron or curved cut lines, no flare at the lip, so the silhouette equals the box silhouette plus add-ons.",
        "4. No detail rhythm: the references read through overlapping lames, studs, straps and edge trim. B1 uses flat gold boxes as stripes and leaves large blank planes.",
        "5. Colour blocking: one saturated blue everywhere plus gold stripes. The references separate 3-4 tones (light steel, dark steel, enamel, cloth, trim) so layers read.",
        "6. Triangles are spent on the wrong things (bevels on hidden boxes) and not on silhouette features (pauldron lips, helm comb, tassets, knee cops).",
        "7. Only 3 distinct knight references exist: Knight1.webp and Knight3.webp are byte-identical (same md5). Knight2/Knight4 are dark textured Roblox avatars (chains, spiked pauldrons). Wizard refs unused (movie characters).",
    ]
    y = 678
    for p in pts:
        y = wrap(d, p, T, 24, y, W - 60, lh=19) + 6
    img.save(os.path.join(O, "SK_1_gap_analysis.png"))


def turnaround():
    W, rowH = 1500, 760
    img = Image.new("RGB", (W, 110 + rowH * 3), (245, 246, 250))
    d = ImageDraw.Draw(img)
    d.text((24, 14), "Shield Knight: B1 (left) vs redesigned benchmark (right), at their spec scales", font=H1, fill=(25, 30, 45))
    d.text((24, 62), "OLD B1: 4,918 tris, 57 parts, R15-box body, shell armour", font=H2, fill=(180, 40, 40))
    d.text((W // 2 + 24, 62), "NEW: 4,920 tris, 75 parts (Epic 5,000 / 80), heroic skeleton", font=H2, fill=(30, 120, 60))
    for i, v in enumerate(("front", "tq", "back")):
        im = on_bg(os.path.join(O, "SK_pair_%s.png" % v)).resize((W - 20, (W - 20) // 2), Image.LANCZOS)
        img.paste(im, (10, 110 + i * rowH))
        d.text((24, 112 + i * rowH), {"front": "front", "tq": "three-quarter", "back": "back"}[v], font=H2, fill=(60, 65, 80))
    img.save(os.path.join(O, "SK_2_old_vs_new_turnaround.png"))


def closeups():
    cols = [("helm", "helmet"), ("chest", "chest + belly"), ("pauldron", "pauldron + arm"), ("arm", "elbow, vambrace, gauntlet"), ("legs", "thighs, knees, greaves"), ("boots", "sabatons"), ("shield", "shield")]
    S = 330
    img = Image.new("RGB", (S * len(cols), 100 + S * 2 + 30), (245, 246, 250))
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Armour close-ups: B1 (top row) vs redesigned (bottom row)", font=H1, fill=(25, 30, 45))
    for c, (k, label) in enumerate(cols):
        d.text((c * S + 12, 62), label, font=H2, fill=(60, 65, 80))
        for r, tag in enumerate(("old", "new")):
            im = on_bg(os.path.join(O, "SK_%s_%s.png" % (tag, k))).resize((S - 6, S - 6), Image.LANCZOS)
            img.paste(im, (c * S + 3, 96 + r * S))
    d.text((16, 100 + S * 2), "Rows: top = B1, bottom = new. Same camera distance per column, aimed at the same body region.", font=TS, fill=(70, 75, 90))
    img.save(os.path.join(O, "SK_3_armour_closeups.png"))


if __name__ == "__main__":
    gap(); turnaround(); closeups()
    print("ok")
