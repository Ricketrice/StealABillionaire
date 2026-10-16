# Shield Knight v5: compose the PBR maps from the baked geometry maps (system python + numpy + PIL).
#   python3 -I tools/blender/compose_035_sk5.py [--res 2048]        reads ~/Pictures/035_preview/sk5_dev/maps.npz, writes .../sk5_dev/tex/*.png
# Outputs (Roblox SurfaceAppearance): ShieldKnight_ColorMap, _MetalnessMap, _RoughnessMap, _NormalMap (OpenGL tangent space), plus a debug sheet.
import json, os, sys
import numpy as np
from PIL import Image

OUT = os.path.expanduser("~/Pictures/035_preview/sk5_dev")
TEX = os.path.join(OUT, "tex")
os.makedirs(TEX, exist_ok=True)
KIND = {"Plate": 1, "Dark": 2, "Trim": 3, "Gold": 4, "Blue": 5, "Cloth": 6, "Leather": 7, "Blade": 8, "Glow": 9}


def _hash3(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535.0


def vnoise(p, freq, seed=0):
    q = p * np.asarray(freq, dtype=np.float32)
    i = np.floor(q).astype(np.int64)
    f = (q - i).astype(np.float32)
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, freq, octaves=4, seed=0):
    tot, amp, norm = 0.0, 0.5, 0.0
    for o in range(octaves):
        tot = tot + amp * vnoise(p, freq * (2 ** o), seed + o)
        norm += amp
        amp *= 0.5
    return tot / norm


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def srgb(lin):
    lin = np.clip(lin, 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def lin(c):
    return np.array(c, dtype=np.float32)


# linear-space F0 / albedo per kind
F0 = {
    "Plate": lin((0.105, 0.115, 0.135)), "Dark": lin((0.022, 0.024, 0.032)), "Trim": lin((0.30, 0.315, 0.35)), "Gold": lin((0.55, 0.38, 0.1)),
    "Blue": lin((0.012, 0.05, 0.42)), "Cloth": lin((0.012, 0.02, 0.07)), "Leather": lin((0.04, 0.022, 0.014)), "Blade": lin((0.5, 0.52, 0.56)), "Glow": lin((0.3, 0.5, 1.0)),
}
WORN = lin((0.42, 0.44, 0.48))
ROUGH = {"Plate": 0.4, "Dark": 0.5, "Trim": 0.26, "Gold": 0.38, "Blue": 0.32, "Cloth": 0.95, "Leather": 0.72, "Blade": 0.2, "Glow": 0.3}
METAL = {"Plate": 1.0, "Dark": 1.0, "Trim": 1.0, "Gold": 1.0, "Blue": 0.0, "Cloth": 0.0, "Leather": 0.0, "Blade": 1.0, "Glow": 0.0}


def main():
    res = int(sys.argv[sys.argv.index("--res") + 1]) if "--res" in sys.argv else 2048
    z = np.load(os.path.join(OUT, "maps.npz"))
    meta = json.load(open(os.path.join(OUT, "maps_meta.json")))
    groups = meta["groups"]
    M5 = meta["meta"]
    H, W = z["idm"].shape[:2]
    kind = np.rint(z["idm"][..., 0].astype(np.float32) * 16).astype(np.int32)
    gid = np.rint(z["gid"][..., 0].astype(np.float32) * 64).astype(np.int32)
    cover = kind > 0
    idx = np.nonzero(cover.ravel())[0]
    n = idx.size
    print("covered texels", n, "of", H * W, "(%.0f%%)" % (100.0 * n / (H * W)))
    pb = z["pos"][..., :3].reshape(-1, 3)[idx].astype(np.float32)
    P = np.stack([-pb[:, 0], pb[:, 2], pb[:, 1]], 1)  # Blender -> kit frame A (x right, y up, z back)
    nb = (z["nrm"][..., :3].reshape(-1, 3)[idx].astype(np.float32)) * 2 - 1
    N = np.stack([-nb[:, 0], nb[:, 2], nb[:, 1]], 1)
    ao = np.clip(z["ao"][..., 0].reshape(-1)[idx].astype(np.float32), 0, 1)
    e1, e2, e3 = [np.clip(z[k][..., 0].reshape(-1)[idx].astype(np.float32), 0, 1) for k in ("e1", "e2", "e3")]
    kd = kind.reshape(-1)[idx]
    gd = gid.reshape(-1)[idx]
    gname = np.array(["" for _ in range(n)], dtype=object)
    for gi, g in enumerate(groups):
        gname[gd == gi + 1] = g
    isg = lambda *names: np.isin(gname, names)
    print("edge ranges e1/e2/e3 p50,p90,p99:", [tuple(np.round(np.percentile(a, [50, 90, 99]), 3)) for a in (e1, e2, e3)], "ao p10/p50:", np.round(np.percentile(ao, [10, 50]), 2))

    albedo = np.zeros((n, 3), np.float32)
    rough = np.zeros(n, np.float32)
    metal = np.zeros(n, np.float32)
    height = np.zeros(n, np.float32)
    for k, kid in KIND.items():
        m = kd == kid
        albedo[m] = F0[k]
        rough[m] = ROUGH[k]
        metal[m] = METAL[k]
    isMetal = metal > 0.5
    # ---- low-frequency mottling + brushed streaks
    mott = fbm(P, 1.7, 4, 1)
    mid = fbm(P, 7.0, 3, 5)
    fine = fbm(P, 15.0, 2, 9)
    brush = vnoise(P * np.array([16, 3, 16], np.float32), 1.0, 11)
    albedo *= (0.86 + 0.28 * mott)[:, None] * (0.97 + 0.06 * fine)[:, None]
    rough += (mott - 0.5) * 0.22 + (brush - 0.5) * 0.12 * isMetal
    # ---- scratches (two directions) and dents
    d1 = P[:, 0] * 0.8 + P[:, 1] * 0.6
    d2 = P[:, 0] * -0.5 + P[:, 2] * 0.85 + P[:, 1] * 0.2
    warp = fbm(P, 4.0, 2, 21) * 1.5
    s1 = np.abs(np.sin(d1 * 38 + warp * 6))
    s2 = np.abs(np.sin(d2 * 52 + warp * 8))
    sc1 = sstep(0.07, 0.0, s1) * sstep(0.78, 0.9, fbm(P, 3.0, 2, 31))
    sc2 = sstep(0.06, 0.0, s2) * sstep(0.8, 0.92, fbm(P, 3.4, 2, 41))
    scratch = np.clip(sc1 + sc2, 0, 1) * isMetal
    dent = fbm(P, 2.6, 3, 51)
    # ---- crevices / grime from AO, polished convex edges from the bevel masks
    grime = sstep(0.7, 0.2, ao)
    edge_conv = sstep(0.03, 0.16, e1) * sstep(0.25, 0.7, ao)
    patchy = fbm(P, 4.5, 3, 61)  # coarse: wear comes in patches along the edges (hands, shoulders, knees), not as speckle
    wear = sstep(0.42, 0.62, edge_conv * (0.25 + 1.3 * patchy) * 1.5) * isMetal
    wear = wear * (0.85 + 0.15 * sstep(0.35, 0.65, fbm(P, 14.0, 2, 63)))
    soft_edge = sstep(0.04, 0.2, e2) * sstep(0.3, 0.8, ao) * isMetal
    albedo = albedo * (1 - 0.5 * grime)[:, None]
    rough += 0.28 * grime
    albedo = albedo * (1 + 0.55 * soft_edge)[:, None]
    rough -= 0.12 * soft_edge
    albedo = albedo * (1 - wear[:, None]) + WORN[None, :] * wear[:, None] * (0.7 + 0.5 * fine)[:, None]
    rough = rough * (1 - wear) + 0.2 * wear
    albedo = albedo + scratch[:, None] * lin((0.07, 0.07, 0.08))[None, :]
    rough -= 0.1 * scratch
    # rust-brown grime in the deepest crevices of the steel (very restrained)
    rust = sstep(0.5, 0.25, ao) * sstep(0.5, 0.8, fbm(P, 9.0, 3, 71)) * isMetal
    albedo = albedo * (1 - 0.5 * rust[:, None]) + lin((0.05, 0.022, 0.012))[None, :] * 0.5 * rust[:, None]
    height += -0.25 * scratch + 0.06 * (dent - 0.5)

    # ---- engraved border lines that follow every plate outline (offset from the edge: bands in the wide bevel masks)
    plate_like = np.isin(kd, [KIND["Plate"], KIND["Trim"], KIND["Dark"]])
    line1 = sstep(0.045, 0.06, e3) * (1 - sstep(0.06, 0.075, e3))
    line2 = sstep(0.12, 0.135, e3) * (1 - sstep(0.135, 0.15, e3))
    border = np.clip(line1 + 0.7 * line2, 0, 1) * plate_like
    height += -0.9 * border
    albedo = albedo * (1 - 0.4 * border[:, None])
    # ---- filigree on the breastplate front and the shield rim bands: interwoven scroll lines (domain-warped lattice)
    def filigree(scale, seed):
        w1 = fbm(P, 2.2, 3, seed) * 2.4
        u = P[:, 0] * scale + w1
        v = P[:, 1] * scale + fbm(P, 2.7, 3, seed + 7) * 2.4
        pat = np.abs(np.sin(u) * np.sin(v) + 0.45 * np.sin(u + v) * np.cos(u - v))
        return sstep(0.16, 0.0, pat)

    chest = isg("UpperTorso") & (kd == KIND["Plate"]) & (N[:, 2] < -0.25) & (P[:, 1] > 3.65) & (P[:, 1] < 4.38) & (np.abs(P[:, 0]) < 1.05)
    ornate = filigree(10.0, 80) * chest * sstep(0.02, 0.09, e3)
    height += -0.55 * ornate
    albedo = albedo * (1 - 0.45 * ornate[:, None])
    # ---- pauldron fluting: radial grooves over the dome lames
    for sgn_, name in ((1, "RightUpperArm"), (-1, "LeftUpperArm")):
        m = isg(name) & np.isin(kd, [KIND["Plate"], KIND["Dark"]]) & (P[:, 1] > 4.0)
        th = np.arctan2(P[:, 2], (P[:, 0] - sgn_ * (M5['arm_x'] + 0.14)))
        fl = sstep(0.82, 0.97, np.abs(np.sin(th * 11)))
        height += -0.6 * fl * m
        albedo = albedo * (1 - 0.35 * (fl * m)[:, None])
    # ---- helm: vent slots on the faceplate cheeks, a hairline brow groove, dark eye-slit surround
    hm = isg("Helmet") & (kd == KIND["Plate"])
    yv = P[:, 1]
    A0 = M5['helm_y0']
    face = hm & (N[:, 2] < -0.3) & (yv < A0 + M5['helm_h'] * 0.5) & (yv > A0 + M5['helm_h'] * 0.04)
    slots = np.zeros(n, np.float32)
    for yk in (0.14, 0.22, 0.30, 0.38):
        yc = A0 + M5['helm_h'] * yk
        for xc in (-0.42, 0.42):
            slots = np.maximum(slots, sstep(0.028, 0.012, np.abs(yv - yc)) * sstep(0.17, 0.12, np.abs(P[:, 0] - xc)))
    slots *= face
    height += -0.9 * slots
    albedo = albedo * (1 - 0.8 * slots[:, None])
    rough = np.where(slots > 0.3, 0.9, rough)
    # ---- shield: heraldic paint (blue enamel chevron + lower field), flaking through noise; gilded edges on the gate relief
    sh = isg("Shield")
    lx, ly = P[:, 0] - M5['shield'][0], P[:, 1] - M5['shield'][1]
    face_sh = sh & (kd == KIND["Plate"]) & (N[:, 2] < -0.2)
    chev = (np.abs((ly + 0.15) - (-0.55) * np.abs(lx)) < 0.2) | (ly < -1.1 + 0.4 * np.abs(lx))
    flake = sstep(0.38, 0.62, fbm(P, 11.0, 4, 91))
    paint = face_sh & chev & (flake > 0.0)
    pm = (paint.astype(np.float32)) * (0.3 + 0.7 * flake)
    pm = np.clip(pm * 1.4, 0, 1)
    albedo = albedo * (1 - pm[:, None]) + F0["Blue"][None, :] * (0.5 + 0.8 * fbm(P, 5.0, 3, 95))[:, None] * pm[:, None]
    metal = metal * (1 - pm)
    rough = rough * (1 - pm) + 0.42 * pm
    gate = sh & (kd == KIND["Trim"])
    gilt = gate * sstep(0.012, 0.05, e1) * sstep(0.7, 0.4, e1 * 6)
    albedo = albedo * (1 - 0.8 * gilt[:, None]) + F0["Gold"][None, :] * 0.8 * gilt[:, None] * (0.6 + 0.6 * fine)[:, None]
    # ---- cloth weave and folds, leather grain
    cm = kd == KIND["Cloth"]
    weave = (np.sin(P[:, 0] * 260) * np.sin(P[:, 2] * 260 + P[:, 1] * 40) * 0.5 + 0.5)
    albedo = np.where(cm[:, None], albedo * (0.8 + 0.4 * weave)[:, None], albedo)
    height += 0.12 * weave * cm
    lm = kd == KIND["Leather"]
    grain = fbm(P, 90.0, 2, 101)
    albedo = np.where(lm[:, None], albedo * (0.7 + 0.6 * grain)[:, None], albedo)
    height += 0.2 * (grain - 0.5) * lm
    rough = np.clip(rough, 0.12, 1.0)

    # ---- pack into images, height -> tangent-space normal
    def full(vals, c=1, fill=0.0):
        arr = np.full((H * W, c), fill, np.float32)
        arr[idx] = vals.reshape(n, c)
        return arr.reshape(H, W, c)

    Himg = full(height)[..., 0]
    for _ in range(2):  # a light blur so the normal map does not alias into sparkle at distance
        Himg = (Himg + np.roll(Himg, 1, 0) + np.roll(Himg, -1, 0) + np.roll(Himg, 1, 1) + np.roll(Himg, -1, 1)) / 5.0
    gx = (np.roll(Himg, -1, 1) - np.roll(Himg, 1, 1)) * 0.5
    gy = (np.roll(Himg, -1, 0) - np.roll(Himg, 1, 0)) * 0.5
    strength = 4.0
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(gx)  # image rows run top-down: v up = -row
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nmap = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
    nmap[~cover] = (0.5, 0.5, 1.0)
    fill_alb = full(albedo, 3, 0.02)
    out = {
        "ColorMap": (srgb(fill_alb) * 255).astype(np.uint8),
        "MetalnessMap": (np.repeat(full(metal)[..., :1], 3, -1) * 255).astype(np.uint8),
        "RoughnessMap": (np.repeat(full(rough, 1, 0.8)[..., :1], 3, -1) * 255).astype(np.uint8),
        "NormalMap": (nmap * 255).astype(np.uint8),
    }
    # Blender stores image rows bottom-up: flip so the PNG matches the UV space (v up)
    for k, a in out.items():
        Image.fromarray(np.flipud(a)).save(os.path.join(TEX, "ShieldKnight_%s_%d.png" % (k, res)))
        if res > 1024:
            Image.fromarray(np.flipud(a)).resize((1024, 1024), Image.LANCZOS).save(os.path.join(TEX, "ShieldKnight_%s_1024.png" % k))
    print("textures written to", TEX)


if __name__ == "__main__":
    main()
