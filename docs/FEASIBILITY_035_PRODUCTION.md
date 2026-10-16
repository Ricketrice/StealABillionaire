# Character production feasibility (2026-10-16, art-roster)
Question: can our tools produce original Roblox fantasy characters at the craftsmanship of the owner's knight references? Evidence: V5 vs the modifier-based upper-body proof (`~/Pictures/035_preview/proof/PROOF_comparison_sheet.png`, files `assets/export/035/proof/`).

## What each option needs, and whether we can run it today
| Option | Runnable now? | Notes |
|---|---|---|
| Procedural patches (`kit035`, V1-V5) | yes | Flat-faceted, thin, assembled from primitives. Ceiling reached: five iterations, still reads as a decorated noob. |
| Modifier-based hard-surface (Solidify + Bevel + Boolean + tapered curve horns, `tools/blender/proof`) | yes (headless Blender 5.2) | Clearly better SURFACES (smooth, thick, bevelled, coherent), but forms are still primitive-derived: discs, domes, tubes. Needs a human eye for shape; blind iteration through renders is slow. |
| Hand-sculpted kit by an artist | not by me | Needs a person (Blender sculpt / ZBrush). Highest quality; the reference-level result. |
| `generate_3d` (Tripo / Hunyuan3D / Hyper3D via the Blender MCP) | NOT now | Needs the Blender GUI with the MCP addon running (`get_addon_status` failed: "Could not connect to Blender"). Providers and credits unknown until connected; each call may cost money. Output is one textured blob: needs retopology, UV, part splitting and rigging for our weld rig. Untested. |
| Local open-source image-to-3D (TripoSR etc.) | NO | Disk is 100% full (1.5 GB free), no torch, 6 GB VRAM. |
| Sketchfab / Poly Pizza library models | search only | Not original; licences vary; fine as reference only. |

## Recommendation
1. Do not mass-produce with the procedural method; it cannot reach the bar.
2. Best realistic path: an external 3D artist (or the owner) sculpts a small reusable ARMOUR KIT once (helm family, pauldrons, breastplate, gauntlet, boot, belt/tasset set; 4-6 variants each). I automate everything after that: UV, texture bake, per-group MeshPart merge, naming, rigging weld data, contact sheets, FBX, validation, wiring.
3. Alternative to try before commissioning: connect Blender with the MCP addon and spend ONE `generate_3d` credit on a helmet-and-shoulders design image, to see if the output can be retopologised. Treat as an experiment, not the pipeline.
4. Free disk space (>20 GB) before any local AI tooling.
