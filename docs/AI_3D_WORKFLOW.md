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

## Update 2026-10-17: free-path attempt (budget $0)
- Hyper3D shared trial key ("vibecoding", shipped by the addon as its official "Set Free Trial API Key"): accepted by the API (read-only status call: bad key = 401, this key = valid), but ONE generation request (three-quarter image) returned `API_INSUFFICIENT_FUNDS`: the shared daily allowance is exhausted. Nothing was generated, nothing charged (no account, card or key of the owner was involved). Not retried. The integration was switched off again in Blender.
- Local open-source: impossible here (disk 1.5 GB free; TRELLIS.2 needs 24 GB VRAM; Hunyuan3D-2.1 needs 10 GB for shape only; this GPU has 6 GB).
- Free cloud (no card, run in a browser): Hugging Face Spaces `microsoft/TRELLIS.2` (MIT, single image -> GLB with PBR; RUNNING on ZeroGPU) and `tencent/Hunyuan3D-2.1` (RUNNING on ZeroGPU). Anonymous ZeroGPU quotas are small and queue-based. Output goes to the owner's browser; the image is uploaded to a third-party Space.
- Hyper3D own free plan: preview before paying, but downloads and commercial rights on the free tier are not stated on their page: verify before use. Tripo / Meshy free tiers: credits and licences conflict between sources (some free outputs are public / non-commercial): unverified. Tripo pricing page returned 403.

## Update 2026-10-17 (later): TRELLIS.2 Space via gradio_client (anonymous, $0)
- Space `microsoft/TRELLIS.2` is up (ZeroGPU A10G; card license: MIT). API verified with `gradio_client` in an isolated venv (47 MB, no model weights): `/start_session`, `/preprocess_image`, `/get_seed`, `/image_to_3d(image, seed, resolution 512|1024|1536, guidance/steps...)`, `/extract_glb(decimation_target, texture_size)`; single image input only.
- Result: **blocked by the free anonymous ZeroGPU quota.** `/image_to_3d` returned: "You have exceeded your ZeroGPU quota (120s requested vs. 176s left). Try again in 23:59:06. Authenticate with a Hugging Face token for more quota". Two submissions were made (the first failed with a generic app error before I corrected how I passed the preprocessed file; the second hit the quota). No retries after that, no quota bypass, no GLB produced, nothing evaluated.
- Each GPU step (`image_to_3d` and `extract_glb`) asks for 120 s of ZeroGPU, so a full run needs at least 240 s of quota; the anonymous allowance cannot cover it. A FREE Hugging Face account (token, no card) gets a larger daily allowance; PRO is paid and not wanted.
- Licensing notes: model and code MIT (card). The Space removes backgrounds with `briaai/BRIA-RMBG-2.0` when the upload has no alpha channel (that model's own licence is non-commercial, so supply an RGBA cut-out to avoid it: `gen_input_*_rgba.png` prepared). Uploaded images are cached temporarily and deleted at session end (Space notice). Commercial use of OUTPUTS is not restricted by the card, but check the model card of `microsoft/TRELLIS.2-4B` and dependency licences before production.
