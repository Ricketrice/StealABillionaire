# Heroic skeleton: compatibility audit (read-only, 2026-10-16)
Hidden R15 rig re-proportioned for kit models (`body.HERO` in Blender, `spec.rig` / `CreatureBuilder.RIG_NOOB` in Lua; the default reproduces today's noob rig exactly). Studio NOT touched; nothing below is measured in-engine yet.

## What depends on rig geometry (code audit)
| Where | Dependency | HERO effect |
|---|---|---|
| `NPCPlacement` (pad) | root Y = stationTop + `Humanoid.HipHeight` + root.Size.Y/2 | HipHeight must equal the new leg length. **Risk #1.** |
| `CreatureScaler.feetY`, `CustomWorkerRigs` (rig swap lift), `JuiceClient`, `HeistService` | same HipHeight + root.Size.Y/2 | same |
| `NPCCarry` | carrier UpperTorso Size.Y, creature UpperTorso Size.Z/2 | unchanged: HERO keeps UpperTorso depth 1 and the HRP 2x2x1; carried length 6.2 studs (6.5 x 0.95) is inside today's range (Golden Paladin 5.2 x 1.25 = 6.5; bosses capped at 1.3) |
| `WorkerPreview.frame`, `HubArena`, `CreatureShowcase` | bounding box | adaptive, no change |
| `Animate` / `NPCAnimation` | joint rotations only (attachments are moved to the new joints, as the noob rebuild already does) | stride is longer with 2.75-stud legs: check foot sliding at the current WalkSpeed |
| `CreatureAnim` chains | pivots computed from the new rig in `makeKitParts` | no assumption on rig size |

## Numbers read from the saved place (`tools/rbxl_rig_035.py`)
MysteryNPC: HRP 2x2x1; ground to HRP bottom = 1.98 studs; stored `HipHeight` = 0 (the engine derives it at run time). Builder noob rig: 1.92. HERO needs about 2.65 (+0.72). Whether the engine follows the longer legs automatically for R15 cannot be proven offline.

## Verification plan (needs the owner's go: pushes builder changes into Studio, flag off, backup first)
1. Back up (local .rbxl + scripts); push `CreatureBuilder`, `CreatureSpecs`, `DevTest_Creature035`; `verify_sync`.
2. Solo test with a HERO proxy (no FBX: `spec.rig = HERO`, plain blocks): stand on flat ground (lowest visible part vs floor), pad placement (feet on the pad), carry offset, reveal/Index preview framing, Animate idle/walk (no errors, no sinking, stride/WalkSpeed), wander on the Keep floor, rig swap path (`CustomWorkerRigs`).
3. If HipHeight does not follow: set it explicitly in the builder from the measured foot distance.
## Height family (proposal, so units do not look extreme next to each other)
Common 5.0-5.6, Rare 5.4-6.0, Epic 6.0-6.6, Legendary 6.4-7.2 studs (before CreatureScaler caps); Secret bosses get presence through `spec.scale`, not a taller skeleton.
