# Effect sprites for the Vault wizard (original art, drawn here with PIL): ring (shockwave / nova / impact marks), rune circle (ground sigil), gold coin (coin rain).
# Run: python3 -I tools/blender/vault/vw_fx_textures.py   -> assets/export/vault/fx/{VaultRing,VaultSigil,VaultCoin}.png
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C
OUT = os.path.join(C.EXPORT, "fx"); os.makedirs(OUT, exist_ok=True)
SS = 4
def finish(img, size, name):
    img = img.resize((size, size), Image.LANCZOS); img.save(os.path.join(OUT, name)); print(name, img.size)
# ---- ring: soft bright core + wide glow (white; the emitter colours it)
n = 256; y, x = np.mgrid[0:n, 0:n]; r = np.hypot((x - n / 2 + 0.5) / (n / 2), (y - n / 2 + 0.5) / (n / 2))
a = np.exp(-((r - 0.84) / 0.035) ** 2) + 0.45 * np.exp(-((r - 0.84) / 0.11) ** 2); a *= (r < 0.995); a = np.clip(a, 0, 1)
rgba = np.zeros((n, n, 4), np.uint8); rgba[..., :3] = 255; rgba[..., 3] = (a * 255).astype(np.uint8); Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "VaultRing.png")); print("VaultRing.png", (n, n))
# ---- sigil: rune circle
N = 512 * SS; img = Image.new("RGBA", (N, N), (0, 0, 0, 0)); d = ImageDraw.Draw(img); c = N / 2; W = (255, 255, 255, 255)
def circle(rr, w): d.ellipse([c - rr * c, c - rr * c, c + rr * c, c + rr * c], outline=W, width=int(w * c))
circle(0.97, 0.014); circle(0.90, 0.008); circle(0.60, 0.008); circle(0.28, 0.01)
for k in range(48):                                         # outer ticks
    a_ = k * math.tau / 48; r0, r1 = (0.90, 0.97) if k % 4 == 0 else (0.90, 0.935)
    d.line([c + math.cos(a_) * r0 * c, c + math.sin(a_) * r0 * c, c + math.cos(a_) * r1 * c, c + math.sin(a_) * r1 * c], fill=W, width=int(0.007 * c))
def poly(rr, k, rot, w):
    pts = [(c + math.cos(rot + i * math.tau / k) * rr * c, c + math.sin(rot + i * math.tau / k) * rr * c) for i in range(k)]
    d.line(pts + [pts[0]], fill=W, width=int(w * c))
poly(0.88, 3, -math.pi / 2, 0.009); poly(0.88, 3, math.pi / 2, 0.009); poly(0.60, 8, 0, 0.007)
for k in range(8):                                          # rune dots + small diamonds between the rings
    a_ = k * math.tau / 8 + math.pi / 8; px, py = c + math.cos(a_) * 0.75 * c, c + math.sin(a_) * 0.75 * c; s = 0.035 * c
    d.polygon([(px, py - s * 1.4), (px + s, py), (px, py + s * 1.4), (px - s, py)], fill=W)
for k in range(12):                                         # rune strokes in the inner band
    a_ = k * math.tau / 12; px, py = c + math.cos(a_) * 0.44 * c, c + math.sin(a_) * 0.44 * c; s = 0.045 * c
    d.line([px - s * math.sin(a_), py + s * math.cos(a_), px + s * math.sin(a_), py - s * math.cos(a_)], fill=W, width=int(0.008 * c))
    d.line([px, py, px + math.cos(a_) * s, py + math.sin(a_) * s], fill=W, width=int(0.008 * c))
glow = np.array(img.resize((512, 512), Image.LANCZOS)).astype(np.float32)
# soft glow: blurred copy of alpha added underneath
from PIL import ImageFilter
al = Image.fromarray(glow[..., 3].astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)); al = np.asarray(al).astype(np.float32) * 0.55
A = np.clip(np.maximum(glow[..., 3], al), 0, 255).astype(np.uint8); out = np.zeros((512, 512, 4), np.uint8); out[..., :3] = 255; out[..., 3] = A
Image.fromarray(out, "RGBA").save(os.path.join(OUT, "VaultSigil.png")); print("VaultSigil.png", (512, 512))
# ---- coin: gold disc, dark rim, light inner ring, lavender diamond (original emblem)
N = 128 * SS; img = Image.new("RGBA", (N, N), (0, 0, 0, 0)); d = ImageDraw.Draw(img); c = N / 2
def disc(rr, col): d.ellipse([c - rr * c, c - rr * c, c + rr * c, c + rr * c], fill=col)
disc(0.97, (150, 100, 40, 255)); disc(0.90, (235, 184, 78, 255)); disc(0.74, (190, 130, 50, 255)); disc(0.70, (246, 208, 110, 255))
s = 0.34 * c; d.polygon([(c, c - s * 1.25), (c + s, c), (c, c + s * 1.25), (c - s, c)], fill=(150, 120, 255, 255)); s2 = s * 0.55
d.polygon([(c, c - s2 * 1.25), (c + s2, c), (c, c + s2 * 1.25), (c - s2, c)], fill=(230, 220, 255, 255))
finish(img, 128, "VaultCoin.png")
