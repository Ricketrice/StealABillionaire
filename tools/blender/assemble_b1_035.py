# Batch B1 contact sheet, previews and phone-load numbers (system Python + PIL + ffmpeg; run after build_035_b1.py --full).
#   python3 -I tools/blender/assemble_b1_035.py            -> sheet + GIF/MP4 per creature + overview + b1_load.json in ~/Pictures/035_preview/b1
#   python3 -I tools/blender/assemble_b1_035.py --strip Name [frames...]   -> a quick strip of animation frames
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PREV = os.path.expanduser("~/Pictures/035_preview/b1")
TILES, ANIM = os.path.join(PREV, "tiles"), os.path.join(PREV, "anim")
REPORT = os.path.join(ROOT, "assets", "export", "035", "b1", "B1_report.json")
ORDER = ["RookieSquire", "ScrollPage", "TrainingDummy", "AppleArcher", "BannerBearer", "ShieldKnight", "ForgeMaster", "GoldenPaladin", "SirIronclad"]
TITLE = {"RookieSquire": "Rookie Squire", "ScrollPage": "Scroll Page", "TrainingDummy": "Training Dummy", "AppleArcher": "Apple Archer", "BannerBearer": "Banner Bearer",
         "ShieldKnight": "Shield Knight", "ForgeMaster": "Forge Master", "GoldenPaladin": "Golden Paladin", "SirIronclad": "Sir Ironclad"}
RARC = {"Common": (150, 160, 170), "Rare": (60, 130, 230), "Epic": (150, 80, 220), "Legendary": (240, 170, 30), "Secret": (225, 60, 80)}
BG = (222, 227, 236)
try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
    FONT_S = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    FONT_H = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
except OSError:
    FONT = FONT_S = FONT_H = ImageFont.load_default()


def on_bg(im, bg=BG):
    out = Image.new("RGBA", im.size, bg + (255,))
    out.alpha_composite(im.convert("RGBA"))
    return out.convert("RGB")


def silhouette(front):
    a = front.convert("RGBA").split()[3]
    sil = Image.new("RGB", front.size, BG)
    black = Image.new("RGB", front.size, (18, 20, 28))
    sil.paste(black, mask=a.point(lambda v: 255 if v > 40 else 0))
    return sil


def tile(name, tag):
    p = os.path.join(TILES, "%s_%s.png" % (name, tag))
    return Image.open(p) if os.path.exists(p) else None


def sheet(reports):
    CW, LW, H0 = 300, 250, 100
    cols = ["front", "three-quarter", "back", "silhouette", "icon 128 px", "vs 5.2-stud noob (at spec scale)", "World FX on"]
    W = LW + CW * len(cols)
    img = Image.new("RGB", (W, H0 + CW * len(ORDER)), (245, 246, 250))
    d = ImageDraw.Draw(img)
    d.text((20, 18), "Knight's Keep: batch B1 (9 creatures)", font=FONT_H, fill=(25, 30, 45))
    d.text((20, 58), "Standard body + knight kit. Triangles / MeshParts are visible parts only (hidden R15 rig excluded). Right of the sheet: the game rig's classic noob.", font=FONT_S, fill=(70, 75, 90))
    for i, c in enumerate(cols):
        d.text((LW + i * CW + 12, H0 - 26), c, font=FONT_S, fill=(60, 65, 80))
    for r, name in enumerate(ORDER):
        rep = next(x for x in reports if x["model"] == name)
        y = H0 + r * CW
        d.rectangle([0, y, W, y + CW - 1], fill=(250, 251, 253) if r % 2 == 0 else (240, 242, 247))
        d.rectangle([0, y, 8, y + CW - 1], fill=RARC[rep["rarity"]])
        d.text((24, y + 18), TITLE[name], font=FONT, fill=(25, 30, 45))
        d.text((24, y + 46), "%s . spec scale %.2f" % (rep["rarity"], rep["scale"]), font=FONT_S, fill=(70, 75, 90))
        tw = rep["tris_world_state"]
        d.text((24, y + 70), "tris %d / %d" % (tw, rep["tri_budget"]), font=FONT_S, fill=(30, 120, 60) if rep["tris_ok"] else (200, 40, 40))
        d.text((24, y + 92), "parts %d / %d" % (rep["parts_world_state"], rep["part_budget"]), font=FONT_S, fill=(30, 120, 60) if rep["parts_ok"] else (200, 40, 40))
        d.text((24, y + 114), "max mesh %d tris" % rep["max_mesh_tris"], font=FONT_S, fill=(70, 75, 90))
        d.text((24, y + 140), "signature:", font=FONT_S, fill=(70, 75, 90))
        words, line, yy = rep["sig"].split(), "", y + 160
        for w in words:
            if len(line) + len(w) > 25:
                d.text((24, yy), line, font=FONT_S, fill=(40, 45, 60)); yy += 18; line = ""
            line += (" " if line else "") + w
        d.text((24, yy), line, font=FONT_S, fill=(40, 45, 60))
        front = tile(name, "front")
        cells = [on_bg(front), on_bg(tile(name, "tq")), on_bg(tile(name, "back")), silhouette(front), None, on_bg(tile(name, "scale")), None]
        for i, im in enumerate(cells):
            x = LW + i * CW
            if im is not None:
                im = im.resize((CW - 8, CW - 8), Image.LANCZOS)
                img.paste(im, (x + 4, y + 4))
        ic = tile(name, "icon")
        icb = on_bg(ic)
        img.paste(icb, (LW + 4 * CW + (CW - 128) // 2, y + (CW - 128) // 2))
        fx = tile(name, "fx")
        if fx is not None:
            img.paste(on_bg(fx).resize((CW - 8, CW - 8), Image.LANCZOS), (LW + 6 * CW + 4, y + 4))
        else:
            d.text((LW + 6 * CW + 100, y + CW // 2), "no World FX", font=FONT_S, fill=(150, 155, 170))
    out = os.path.join(PREV, "B1_contact_sheet.png")
    img.save(out)
    return out


def previews():
    outs = []
    small = []
    for name in ORDER:
        d = os.path.join(ANIM, name)
        frames = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        ims = [on_bg(Image.open(os.path.join(d, f))) for f in frames]
        gif = os.path.join(PREV, "%s_idle_signature.gif" % name)
        ims[0].save(gif, save_all=True, append_images=ims[1:], duration=int(1000 / 18), loop=0, optimize=False)
        tmp = os.path.join(d, "bg")
        os.makedirs(tmp, exist_ok=True)
        for i, im in enumerate(ims):
            im.save(os.path.join(tmp, "f%03d.png" % i))
        mp4 = os.path.join(PREV, "%s_idle_signature.mp4" % name)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "18", "-i", os.path.join(tmp, "f%03d.png"), "-vf", "format=yuv420p", "-movflags", "+faststart", mp4], check=True)
        outs.append(gif)
        small.append([im.resize((240, 240), Image.LANCZOS) for im in ims])
    n = len(small[0])
    grid = []
    for k in range(n):
        g = Image.new("RGB", (240 * 3, 240 * 3), BG)
        for i, fr in enumerate(small):
            g.paste(fr[k], ((i % 3) * 240, (i // 3) * 240))
        grid.append(g)
    ov = os.path.join(PREV, "B1_overview_idle_signature.gif")
    grid[0].save(ov, save_all=True, append_images=grid[1:], duration=int(1000 / 18), loop=0)
    return outs + [ov]


def load(reports):
    """Phone-load numbers: triangles and MeshParts for a full base (14 pads, Captured state) and a full server (12 bases = 168 creatures)."""
    odds = {"Common": 0.70, "Rare": 0.20, "Epic": 0.08, "Legendary": 0.018, "Secret": 0.002}
    by = {}
    for r in reports:
        by.setdefault(r["rarity"], []).append(r)
    avg = lambda rows, k: sum(x[k] for x in rows) / len(rows)
    exp = {k: sum(odds[ra] * avg(by[ra], k) for ra in odds) for k in ("tris_captured_state", "parts_captured_state", "tris_lite", "parts_lite")}
    worst_t = max(reports, key=lambda r: r["tris_captured_state"])
    worst_p = max(reports, key=lambda r: r["parts_captured_state"])
    out = {"expected_per_creature": {k: round(v) for k, v in exp.items()}}
    for label, n in (("base_14", 14), ("server_168", 168), ("wild_14", 14)):
        out[label] = {
            "expected_tris": round(exp["tris_captured_state"] * n), "expected_parts": round(exp["parts_captured_state"] * n),
            "expected_tris_lite": round(exp["tris_lite"] * n), "expected_parts_lite": round(exp["parts_lite"] * n),
            "worst_tris": worst_t["tris_captured_state"] * n, "worst_tris_who": worst_t["model"],
            "worst_parts": worst_p["parts_captured_state"] * n, "worst_parts_who": worst_p["model"],
        }
    out["avg_all9"] = {"tris": round(sum(r["tris_captured_state"] for r in reports) / 9), "parts": round(sum(r["parts_captured_state"] for r in reports) / 9)}
    json.dump(out, open(os.path.join(PREV, "b1_load.json"), "w"), indent=1)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--strip":
        name = sys.argv[2]
        idx = [int(x) for x in sys.argv[3:]] or list(range(0, 54, 6))
        ims = [on_bg(Image.open(os.path.join(ANIM, name, "f%03d.png" % i))).resize((270, 270)) for i in idx]
        s = Image.new("RGB", (270 * len(ims), 270), BG)
        for i, im in enumerate(ims):
            s.paste(im, (i * 270, 0))
        s.save(os.path.join(PREV, "%s_strip.png" % name))
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "--strips":
        idx = [0, 14, 20, 26, 32, 38, 44, 52]
        S = 220
        s = Image.new("RGB", (S * len(idx), S * len(ORDER)), BG)
        for r, nme in enumerate(ORDER):
            for c, i in enumerate(idx):
                s.paste(on_bg(Image.open(os.path.join(ANIM, nme, "f%03d.png" % i))).resize((S, S), Image.LANCZOS), (c * S, r * S))
        s.save(os.path.join(PREV, "B1_anim_strips.png"))
        sys.exit()
    reports = json.load(open(REPORT))
    print(sheet(reports))
    if "--no-gif" not in sys.argv:
        print(previews())
    print(json.dumps(load(reports), indent=1))
