# Shield Knight v5: render the textured knight (PBR maps on the UV atlas, one mesh per group) in Roblox-like or neutral light.
#   flatpak run org.blender.Blender -b -P $PWD/tools/blender/render_035_sk4.py -- --light roblox|neutral [--views front,tq,back,helm,...] [--res 800] [--tex 2048|1024] [--construct]
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
import bpy
from mathutils import Vector as V
from kit035 import geo, studio

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"light": "roblox", "views": "front,tq,back", "res": 800, "tex": "2048", "out": os.path.expanduser("~/Pictures/035_preview/sk4"), "construct": False, "bg": "sky", "nogear": False}
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--construct": opt["construct"] = True
    elif a == "--nogear": opt["nogear"] = True
    elif a in ("--light", "--views", "--res", "--tex", "--out", "--bg"): opt[a[2:]] = argv[i + 1]; i += 1
    i += 1
opt["res"] = int(opt["res"])
DEV = os.path.expanduser("~/Pictures/035_preview/sk4_dev")
TEX = os.path.join(DEV, "tex")
os.makedirs(opt["out"], exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.join(DEV, "sk4_uv.blend"))
sc = bpy.context.scene
# ---- merge per group (one MeshPart per animated group)
groups = {}
for ob in list(bpy.data.objects):
    if ob.type == "MESH":
        groups.setdefault(ob["group"], []).append(ob)
merged = []
for g, obs in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = "ShieldKnight_" + g
    merged.append(o)
print("MERGED meshparts:", len(merged), "tris:", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in merged))
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
sc.render.film_transparent = False
sc.render.image_settings.file_format = "PNG"
sc.view_settings.view_transform = "Standard"
try:
    sc.eevee.taa_render_samples = 48
except Exception:
    pass
sc.render.resolution_x = sc.render.resolution_y = opt["res"]
# ---- material from the baked PBR maps
def img(name, cs):
    im = bpy.data.images.load(os.path.join(TEX, "ShieldKnight_%s_%s.png" % (name, opt["tex"])))
    im.colorspace_settings.name = cs
    return im
mat = bpy.data.materials.new("KnightPBR")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
def tex(name, cs):
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img(name, cs); t.interpolation = "Linear"; return t
col, met, rou, nor = tex("ColorMap", "sRGB"), tex("MetalnessMap", "Non-Color"), tex("RoughnessMap", "Non-Color"), tex("NormalMap", "Non-Color")
nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(met.outputs["Color"], bsdf.inputs["Metallic"])
nt.links.new(rou.outputs["Color"], bsdf.inputs["Roughness"])
nm = nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.0
nt.links.new(nor.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
for o in merged:
    o.data.materials.clear(); o.data.materials.append(mat)
hide = ("Flash", "Sword", "Shield") if opt["nogear"] else ("Flash",)
for o in merged:
    if o["group"] in hide:
        o.hide_render = True
if opt["construct"]:
    palette = [(0.7, 0.35, 0.3), (0.3, 0.55, 0.7), (0.75, 0.65, 0.3), (0.45, 0.65, 0.4), (0.6, 0.45, 0.7), (0.8, 0.5, 0.2)]
    for k, o in enumerate(merged):
        m = bpy.data.materials.new("c%d" % k); m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = palette[k % len(palette)] + (1,); b.inputs["Roughness"].default_value = 0.7
        o.data.materials.clear(); o.data.materials.append(m)
    sc.render.use_freestyle = True
    vl = bpy.context.view_layer
    vl.use_freestyle = True
    ls = vl.freestyle_settings.linesets[0] if vl.freestyle_settings.linesets else vl.freestyle_settings.linesets.new("l")
    ls.select_silhouette = True; ls.select_border = True; ls.select_crease = True
    vl.freestyle_settings.crease_angle = math.radians(60)
    ls.linestyle.thickness = 1.6; ls.linestyle.color = (0.02, 0.02, 0.03)
# ---- lighting
w = sc.world or bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
wn = w.node_tree
wn.nodes.clear()
out = wn.nodes.new("ShaderNodeOutputWorld"); bgn = wn.nodes.new("ShaderNodeBackground")
for ob in list(bpy.data.objects):
    if ob.type == "LIGHT":
        bpy.data.objects.remove(ob, do_unlink=True)
if opt["light"] == "roblox":
    sky = wn.nodes.new("ShaderNodeTexSky"); sky.sky_type = "SINGLE_SCATTERING" if hasattr(sky, "sky_type") else None
    try:
        sky.sun_elevation = math.radians(48); sky.sun_rotation = math.radians(210); sky.altitude = 0; sky.air_density = 1.0; sky.dust_density = 0.6; sky.ozone_density = 1.0
    except Exception:
        pass
    # the camera sees a plain Roblox-like sky blue; everything is LIT by the physical sky
    lp = wn.nodes.new("ShaderNodeLightPath"); mix = wn.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    mix.inputs[7].default_value = (0.36, 0.62, 0.9, 1)  # B (camera rays)
    wn.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    wn.links.new(sky.outputs["Color"], mix.inputs[6])
    wn.links.new(mix.outputs[2], bgn.inputs["Color"]); bgn.inputs["Strength"].default_value = 1.0
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
    s = bpy.context.active_object
    s.data.energy = 3.2; s.data.angle = math.radians(2.5)
    s.rotation_euler = (math.radians(42), 0, math.radians(35))
    # Roblox has ground bounce: a soft grey plane under the model
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.02))
    gp = bpy.context.active_object
    gm = bpy.data.materials.new("ground"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.22, 0.24, 0.26, 1)
    gp.data.materials.append(gm)
    gp.hide_render = opt["bg"] != "sky"
    gp.visible_camera = False
else:
    bgn.inputs["Color"].default_value = (0.55, 0.56, 0.6, 1); bgn.inputs["Strength"].default_value = 1.0
    for loc, en, rot in (((6, -9, 10), 2.4, (math.radians(52), 0, math.radians(32))), ((-8, -4, 6), 0.8, (math.radians(70), 0, math.radians(-55))), ((0, 9, 7), 1.0, (math.radians(125), 0, math.radians(180)))):
        bpy.ops.object.light_add(type="SUN", location=loc)
        L = bpy.context.active_object; L.data.energy, L.rotation_euler = en, rot
wn.links.new(bgn.outputs["Background"], out.inputs["Surface"])
bpy.ops.object.camera_add()
sc.camera = bpy.context.active_object
vis = [o for o in merged if not o.hide_render]
lo, hi = studio.bounds(vis)
ctr = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))
d = studio.fit_dist(lo, hi, margin=1.08)
CLOSE = {
    "helm": ((0, 5.6, 0), -28, 8, 5.2), "helm_side": ((0, 5.6, 0), -90, 6, 5.2), "chest": ((0, 3.9, 0), -22, 8, 6.4), "pauldron": ((1.9, 4.4, 0), -42, 14, 6.0), "arm": ((1.8, 3.3, 0), -50, 8, 6.6),
    "waist": ((0, 2.8, 0), -25, 6, 6.6), "legs": ((0, 1.6, 0), -30, 6, 8.0), "boots": ((0, 0.7, 0), -35, 10, 5.6), "shield": ((-2.3, 3.0, -0.8), 28, 8, 8.0), "backc": ((0, 3.9, 0.5), 180, 8, 8.0),
}
tag = "construct" if opt["construct"] else opt["light"] + ("_nogear" if opt["nogear"] else "")
for v in opt["views"].split(","):
    if v == "icon":
        studio.aim(sc, ctr, -30, 10, d * 0.9)
    elif v in ("front", "tq", "back", "side"):
        az, el = {"front": (0, 6), "tq": (-35, 12), "back": (180, 8), "side": (-90, 6)}[v]
        studio.aim(sc, ctr, az, el, d)
    else:
        t, az, el, dist = CLOSE[v]
        studio.aim(sc, V(geo.to_blender(t)), az, el, dist, lens=60)
    sc.render.resolution_x = sc.render.resolution_y = 128 if v == "icon" else opt["res"]
    sc.render.filepath = os.path.join(opt["out"], "SK4_%s_%s.png" % (tag, v))
    bpy.ops.render.render(write_still=True)
print("RENDER done", tag, opt["views"])
