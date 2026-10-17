# Palette textures for the Vault wizard, rebuilt CLEAN from the GLB's two 128x16 palette images (8 swatches, UV at swatch centres):
# one flat 32x32 block per swatch (256x32) so bilinear filtering / mip levels cannot bleed between neighbours.
# Writes EXPORT/VaultPalette_Color.png, _Metalness.png, _Roughness.png (+ palette.json). Run: python3 -I tools/blender/vault/vw_textures.py
import io, json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C
G = C.Glb()
tex = G.j["textures"]; mats = {m["name"]: m for m in G.j["materials"]}
def s_(x): return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
if C.CFG["texture"] == "atlas":
    # painted atlas (1024 px): colour as is, glTF metallicRoughness split into the two Roblox maps (roughness = G, metalness = B)
    armor = next(m for n, m in mats.items() if n.endswith("_Armor"))["pbrMetallicRoughness"]
    col = Image.open(io.BytesIO(G.image_bytes(tex[armor["baseColorTexture"]["index"]]["source"]))).convert("RGBA")
    mr = np.array(Image.open(io.BytesIO(G.image_bytes(tex[armor["metallicRoughnessTexture"]["index"]]["source"]))).convert("RGBA"))
    os.makedirs(C.EXPORT, exist_ok=True)
    print("atlas", col.size, "alpha min", np.array(col)[..., 3].min())
    col.convert("RGB").save(os.path.join(C.EXPORT, C.CFG["color_png"]))
    Image.fromarray(mr[..., 1], "L").save(os.path.join(C.EXPORT, C.CFG["rough_png"])); Image.fromarray(mr[..., 2], "L").save(os.path.join(C.EXPORT, C.CFG["metal_png"]))
    nc = mats["Neon"]["pbrMetallicRoughness"]["baseColorFactor"][:3]
    json.dump(dict(neon_linear=nc, neon_srgb=[round(s_(x), 4) for x in nc], neon_emissive_strength=mats["Neon"]["extensions"]["KHR_materials_emissive_strength"]["emissiveStrength"]), open(os.path.join(C.EXPORT, "palette.json"), "w"), indent=1)
    print("neon sRGB", [round(s_(x), 3) for x in nc]); sys.exit(0)
pm = mats["Vaultbane_Palette"]["pbrMetallicRoughness"]
img_color = Image.open(io.BytesIO(G.image_bytes(tex[pm["baseColorTexture"]["index"]]["source"]))).convert("RGBA")
img_mr = Image.open(io.BytesIO(G.image_bytes(tex[pm["metallicRoughnessTexture"]["index"]]["source"]))).convert("RGBA")
print("source images", img_color.size, img_mr.size)
cw, ch = img_color.size
sw = cw // 8
def centre(img, k):
    a = np.array(img); y = img.size[1] // 2; x = int((k + 0.5) / 8 * img.size[0]); return a[y, x].astype(int)
cols = [centre(img_color, k) for k in range(8)]; mrs = [centre(img_mr, k) for k in range(8)]
# spread inside each swatch (noise check)
a = np.array(img_color); spread = [int(np.abs(a[:, k * sw:(k + 1) * sw, :3].reshape(-1, 3) - cols[k][:3]).max()) for k in range(8)]
print("swatch colours (sRGB):", [tuple(c[:3]) for c in cols]); print("max in-swatch deviation:", spread)
W, H, B = 256, 32, 32
def build(vals):
    out = np.zeros((H, W, 4), np.uint8)
    for k, v in enumerate(vals): out[:, k * B:(k + 1) * B] = v
    return Image.fromarray(out, "RGBA")
os.makedirs(C.EXPORT, exist_ok=True)
build([tuple(c[:3]) + (255,) for c in cols]).convert("RGB").save(os.path.join(C.EXPORT, C.CFG["color_png"]))
# glTF: roughness = G, metalness = B (x factors; both factors are 1 here)
rough = [(int(m[1]),) * 3 + (255,) for m in mrs]; metal = [(int(m[2]),) * 3 + (255,) for m in mrs]
build(rough).convert("L").save(os.path.join(C.EXPORT, C.CFG["rough_png"])); build(metal).convert("L").save(os.path.join(C.EXPORT, C.CFG["metal_png"]))
neon = mats["Neon"]; nc = neon["pbrMetallicRoughness"]["baseColorFactor"][:3]
def s(x): return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
json.dump(dict(swatch_srgb=[c[:3].tolist() for c in cols], roughness=[m[1] / 255 for m in mrs], metalness=[m[2] / 255 for m in mrs], neon_linear=nc, neon_srgb=[round(s(x), 4) for x in nc],
               neon_emissive_strength=neon["extensions"]["KHR_materials_emissive_strength"]["emissiveStrength"]), open(os.path.join(C.EXPORT, "palette.json"), "w"), indent=1)
print("neon sRGB", [round(s(x), 3) for x in nc], "rough", [round(m[1] / 255, 2) for m in mrs], "metal", [round(m[2] / 255, 2) for m in mrs])
