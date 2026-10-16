# Tools pipeline
_Use outside tools when they make the result clearly better, even for a simple style. Everything original, kid-safe; log every source in `ASSET_CREDITS.md`._

| Tool | Use it for | How Claude uses it | Into Roblox |
|---|---|---|---|
| **Roblox Studio** (MCP) | Building, scripts, VFX (particles/beams/trails), animations (Animation Editor), lighting | MCP scripts | — |
| **Blender** (headless) | Chunky stylised meshes: stalls, vault, island rock, trees, worker props, accessories; low-poly, few materials | `blender -b -P script.py`; export FBX/OBJ to `assets/export/` | Owner imports (3D Importer / Asset Manager) at a checkpoint |
| **Figma** | UI design: HUD, shop, reveal popup, index, store; icons; game icon + thumbnails | Figma MCP server (owner adds it to Claude Code once) | Export PNG at 2x → owner uploads as Decals/Images |
| **Krita / GIMP** (optional) | Textures, particle sprites (sparkles, coins, smoke) | Generate via scripts or owner draws | Upload as images |
| **Audacity** (optional) | Trim/normalise CC0 sound effects | Owner, or `sox`/`ffmpeg` scripts | Upload as audio (Roblox moderation) |

## UI icons (D14)
Model in Blender (chunky shapes, thick dark outline via inverted-hull or Freestyle, soft studio light, slight tilt), render transparent 256×256 PNG, pack into a sprite sheet (≤1024×1024), slice in Studio with ImageRectOffset/ImageRectSize. One upload per sheet.

## Rules
- Meshes: low poly, flat colours or one small texture atlas, CollisionFidelity Box for decoration.
- One master per asset, cloned. Name masters clearly (`M_Stall`, `M_Tree_A`).
- Uploads/imports are by hand: batch them into ONE checkpoint list per milestone with exact steps.
- Sounds: Roblox audio library (licensed) or CC0 only.

## Character kit pipeline (035roster)
`tools/blender/kit035/` builds whole batches headless: `flatpak run org.blender.Blender -b -P $PWD/tools/blender/build_035_b1.py -- --full` (budgets, FBX, data module, tiles, idle + signature frames), then `python3 -I tools/blender/assemble_b1_035.py` (contact sheet, GIF/MP4, phone-load numbers). Authored in Studio axes (+X = the character's right, front = -Z). Export fixes (verified with `fbx_raw_035.py`): the old 100x was `Lcl Scaling 100` on every Model, now `global_scale = 0.01` (Lcl Scaling 1); there is no mirror (Studio = (-bx, bz, by) is a rotation) - L/R is just named correctly. Every FBX carries `<Model>_Anchor` + `_AxisX/_AxisY/_AxisFront` markers so `CreatureBuilder` can verify scale and axes after Import 3D.

### Hard-surface method v2 (Shield Knight benchmark)
`kit035/hs.py`: `Prof` = stacked superellipse cross-sections of a body part; `band(...)` cuts an armour plate out of it by angle and height (V chevron edges, keels, flared lips); `patch(...)` = outer skin + rim walls down to an inner boundary (real edge thickness, no hidden inner skin, about half the triangles of a closed slab); `cap_lame` = dome bands (pauldrons, helm); `simplify` dissolves coplanar splits. `body.Skel` / `HERO` = joint heights of the invisible skeleton. Render the benchmark: `flatpak run org.blender.Blender -b -P $PWD/tools/blender/build_035_sk2.py -- --views front,tq,back,helm,chest --out DIR` (`--old` = B1, `--pair` = side by side), boards: `python3 -I tools/blender/assemble_sk2_035.py`.
- `tools/blender/ai/gw_*.py`: AI-model (TRELLIS GLB) pipeline: `gw_optimise` (8k bake), `gw_parts` (15 rig parts + FBX + maps), `gw_pose_render` / `gw_part_debug` (seam checks), `gw_fbx_check`. Run `flatpak run org.blender.Blender -b -P $PWD/tools/blender/ai/<script> -- args`.
