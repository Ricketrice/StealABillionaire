# Reference + concept-brief board. python3 -I tools/blender/proof/refboard.py
import os
from PIL import Image, ImageDraw, ImageFont
P = os.path.expanduser("~/Pictures/035_preview")
D = os.path.join(P, "Drill")
F = lambda b, n: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)
H1, H2, T = F(1, 24), F(1, 16), F(0, 13)
BG = (245, 246, 250)
refs = [
    ("boss1.jpeg", "boss1: STYLISED PREMIUM ROBLOX (the quality target): chunky bodies, big readable pauldrons, polished metal with bold colour blocking, horns/crest silhouette, strong belt and boot hierarchy"),
    ("bestKnight.jpeg", "bestKnight: dark gunmetal mood, closed visored helm, spiked pauldrons, engraved chest. Mood only"),
    ("kngith1.jpeg", "kngith1: clean plate language: layered lames on pauldrons, central keel plate, cloth under armour, rivets. Construction only"),
    ("Knight2.webp", "Knight2: closed bucket helm, chains, belts across chest. Detail density only"),
    ("Knight4.webp", "Knight4: black and gold: ornate chest roundel, bold pauldron silhouettes. Contrast only"),
    ("legendary1.jpeg", "legendary1: heroic proportions, thick plates with raised trim, tabard. Layering only"),
    ("amour1.jpeg", "amour1 (armor1): Roblox-style torso: V lames, layered pauldrons, tassets"),
    ("secret1.jpeg", "secret1: ornate heavy armour, huge shoulders. Hierarchy only"),
    ("normal1.jpeg", "normal1: layered cloth/leather/mail. Standard-tier target"),
    ("Knight1.webp", "Knight1 (=Knight3, identical file): winged helm, chains. NOT used: busy"),
]
S = 300
cols = 5
rows = (len(refs) + cols - 1) // cols
img = Image.new("RGB", (S * cols + 20 * (cols + 1), 90 + rows * (S + 120)), BG)
d = ImageDraw.Draw(img)
d.text((20, 14), "Reference review (all inspected; wizard refs are film characters: not used; sigBoss1/dragon refs: not knights)", font=H1, fill=(25, 30, 45))
for k, (fn, cap) in enumerate(refs):
    im = Image.open(os.path.join(D, fn)).convert("RGB")
    im.thumbnail((S, S))
    x, y = 20 + (k % cols) * (S + 20), 60 + (k // cols) * (S + 120)
    img.paste(im, (x + (S - im.width) // 2, y))
    words, line, yy = cap.split(), "", y + S + 6
    for w in words:
        if d.textlength(line + " " + w, font=T) > S and line:
            d.text((x, yy), line, font=T, fill=(40, 45, 60)); yy += 16; line = w
        else:
            line = (line + " " + w).strip()
    d.text((x, yy), line, font=T, fill=(40, 45, 60))
img.save(os.path.join(P, "concept", "REFERENCE_REVIEW.png"))
print(img.size)
