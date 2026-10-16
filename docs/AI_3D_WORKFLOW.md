# AI image-to-3D workflow for the Shield Knight (2026-10-17)
Design direction (owner): `~/Pictures/035_preview/Drill/concept.png` ("The Gatehouse Warden" sheet, 1536x1024). Replaces V1-V5.

## Blender MCP status (checked live)
Blender was not running; I started it (GUI, the addon auto-starts its server on port 9876) and `get_addon_status` now connects: Blender 5.2.0 LTS, addon 1.8, protocol 13 OK. The Blender window stays open.

## Providers (all OFF right now)
| Provider | State | Needs | Image input | Cost |
|---|---|---|---|---|
| Hyper3D Rodin | off; mode MAIN_SITE; no API key | an account key (hyperhuman / deemos) or a fal.ai key (mode FAL_AI); the addon ships a shared free-trial key (`vibecoding`) | yes: several images in one job (front / three-quarter / back); fal mode needs image URLs | not verifiable from here (account pricing / trial quota). Addon fixes tier = "Sketch" (the lowest-detail tier), mesh_mode = Raw (triangles), texture_mode = high |
| Hunyuan3D | off; mode LOCAL_API (localhost:8081, no server running) | Tencent Cloud secret id/key for the official API, or a local server | one image per job (file path or URL); image and text prompt cannot be combined | per-call credits on the Tencent account: unknown. A local server is impossible: disk is 100% full (1.5 GB), 6 GB VRAM |
| Tripo | off: "Premium only" | MCP for Blender Premium | n/a | not available |
Costs and credit balances are NOT shown by any tool I have; nothing was generated and nothing spent.

## Input requirements
Use ONE clean subject per image, not the whole sheet (the sheet has labels, close-ups, a palette and props). Prepared (outside the repo, 1024x1024, flat light-grey background, labels and floor shadow removed):
`~/Pictures/035_preview/concept/gen_input_threequarter.png` (primary), `gen_input_front.png`, `gen_input_back.png`.
Best result likely from front + three-quarter (+ back) in ONE Hyper3D job. Shield and sword are separate props: generate them as separate objects later (sword and shield crops exist on the sheet).

## Recommendation
1. Hyper3D Rodin is the only available route that takes several views. Limitation: the addon forces tier "Sketch" (low fidelity) and Raw triangles: expect melted details (portcullis bars, studs), asymmetry and a noisy baked texture. Treat the output as a SCULPT BASE to be cleaned, not a finished asset.
2. With your approval: enable Hyper3D with your own key (preferred: you see the cost) or the addon's free trial key, and run ONE job (three-quarter + front + back). Do not run it without approval.
3. If Sketch quality is too low, the fallback is Hunyuan3D official API (single image, per-call credits) or an external artist using the concept sheet.

## Cleanup needed after generation (what I can script in headless Blender)
1. Import, orient (Studio front = -Z), scale to the CHUNK rig (about 6.3 studs), enforce left/right symmetry.
2. Remove interior and floating geometry; fix non-manifold.
3. Separate into rig groups by cutting at the CHUNK joint heights: helm, UpperTorso, LowerTorso (waist), each Upper/Lower arm, hand, each leg piece, foot; plus cloth pieces. Cap the cuts. Shield and sword are separate generations.
4. Retopology: decimate / quad-remesh to the budget (Epic 8,000 tris total; Common 2,000, Rare 3,000), keep silhouette edges; merge to about 20 MeshParts.
5. Re-UV into one atlas (1024), bake colour from the generated texture, then SIMPLIFY the albedo (posterise, remove baked lighting and noise) to the owner's clean stylised gunmetal / blue / gold; add a light metalness / roughness map.
6. Names and pivots for the weld animation (`<Model>_<Group>_<Colour>` or per group SurfaceAppearance), validate budgets, then the usual Import 3D hand-off.
Risks: fused hands and fingers, soft pauldron crenellations, texture seams at the cuts, and details that exist only as texture. A human artist's cleanup may still be needed for the helm and chest emblem.
