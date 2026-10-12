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
