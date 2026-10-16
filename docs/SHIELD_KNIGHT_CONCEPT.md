# Shield Knight: original concept for image-to-3D (2026-10-17)
References reviewed: board `~/Pictures/035_preview/concept/REFERENCE_REVIEW.png`. Quality target = **boss1** (stylised premium Roblox: chunky, bold colour blocking, big readable pauldrons, strong belt and boots); mood = **bestKnight** (dark gunmetal); construction vocabulary = kngith1 / amour1 / legendary1. Wizard refs are film characters (not used). Knight1 and Knight3 are the same file.

## The concept: "the Gatehouse Warden" (original; ties to Knight's Keep)
A chunky Roblox knight whose whole silhouette says "castle gate":
- **Head:** a closed great-helm. The visor is a **portcullis**: a narrow eye slit over vertical bars (not a cross, not a T). The helm's top is a **crenellated crown** (three square merlons) with one tall swept-back crest fin behind them. Short forward-curving steel tusks at the temples.
- **Shoulders:** huge rounded **turret pauldrons**: stacked drum lames with a crenellated rim and a single arrow-slit notch, plus one curved spike on top. They are the biggest shapes on the figure.
- **Chest:** a keeled breastplate with a raised **gate-arch medallion** (arch between two small towers) in aged gold; a deep-blue enamel panel behind it.
- **Waist and legs:** two layers of tassets, a heavy belt with a square buckle, thick cuisses and knee cops, **big flared sabatons** (boots are a feature).
- **Cloth:** a long deep-blue tabard and short back sash; cloth is a flat, clean colour.
- **Props (generated separately):** a thick **tower kite shield** (portcullis grid in relief, rim studs) and a plain longsword. Generate them as separate objects: a shield fused to an arm ruins the mesh.
- **Palette:** gunmetal (primary), polished steel (edges), deep blue (accent), aged gold (small accents only). Kid-friendly: cool, never scary; no skulls, blood or bones.
- **Proportions:** head about 1/3 of the height, shoulders about 2.2x the torso width, forearms and thighs thick, a clear gap between the legs. 6.0 to 6.5 studs tall on the R15 skeleton.

## Image requirements for image-to-3D (what the generator needs)
One full-body character, **front three-quarter or pure front**, neutral A-pose (arms 30 degrees out, empty hands), no weapon, no shield, plain flat light-grey background, even soft lighting, no cast shadow, no text, no particles or effects, whole body in frame with margin. A second image of the **back** and a **side** view helps (Hunyuan3D / Hyper3D accept multi-view; Tripo accepts one image).

## Text-to-image prompt (for an external image generator; I have no image tool)
"Stylised Roblox fantasy knight character, chunky avatar proportions, full body, front three-quarter view, A-pose with empty hands, plain light grey background, soft even studio lighting, no shadow. Closed great-helm with a portcullis visor (narrow eye slit over vertical bars), crenellated castle-battlement crown with one tall swept-back crest fin, short curved steel tusks at the temples. Huge rounded turret-shaped pauldrons with crenellated rims and one curved spike each. Keeled gunmetal breastplate with a polished steel edge and an aged-gold gate-arch medallion on a deep-blue enamel panel. Heavy belt, layered tassets, thick cuisses, big flared sabaton boots. Long deep-blue tabard. Gunmetal and polished steel with deep-blue and small aged-gold accents. Clean hand-painted game-asset style like a premium Roblox avatar, crisp bevels, no text, no watermark, not scary, kid-friendly."
Negative: "realistic anatomy, face, skull, blood, weapon, shield, cape blowing, particles, glow, busy background, text, logo, copyrighted character".

## Tool and cost check (as of now: NOT confirmed)
- The only generator I can reach is `mcp__blender__generate_3d` (providers: tripo, hunyuan3d, hyper3d; **image input = an absolute file path or http(s) URL**, so image-to-3D is supported by the tool; per-provider multi-view support is not documented to me).
- **Cannot confirm which providers are enabled or what they cost:** `get_addon_status` fails ("Could not connect to Blender"): Blender must be open with the MCP addon running. Each generation "can cost the user money or a monthly generation"; "Premium" generators use credits, others use your own API keys. I will not generate before you have seen the numbers.
- Next step once Blender is connected: run `get_addon_status` (shows enabled generators and Premium status), report the price per call, then spend **one** credit on the body image only, and import nothing into Studio.
