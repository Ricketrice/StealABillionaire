# Hub 2b (2026-10-19, overnight, branch `hub-2b`)

Owner's `~/Documents/Spawn/steal-a-billionaire-hub-2b.glb` (Import 3D → `Workspace.HubMap2b`) is the new hub; our three zones
sit on its two grey platforms; each zone has its boss as a guardian; every zone holds 8 wild creatures on a 120 s rotation.
Everything is in the **open Studio, not saved**: owner must File → Save. Scripts: `tools/hub2b/` (run with
`tools/hub2b/run_file.py <file>` → paste the 3-line snippet into MCP / the command bar).

## 1. The map
- **Export:** 346 nodes, 311 meshes, 57,550 tris, 31 flat materials (water uses textures), metre scale (×3.5714 = studs).
  Split files in `~/Documents/Spawn` (Base3/4/5, Bushes, GardenFountains) are the same pieces as in the full file: **no extra Import 3D needed.**
  `Hub2b_Markers.glb` (35 markers) and `~/Documents/Hub2b_Collision.glb` (101 boxes) were read offline (headless Blender, `tools/hub2b/inspect_glb.py`, `islands.py`), not imported.
- **Layout (hub-local studs, north = -Z, floor y 0, origin `HubOrigin` = world (0, 0, 700)):** walled town x ±170, z 10..200 (fountain plaza z 80,
  TeleportHall z 10..44 with 4 portals, shops, IndexHall, RebirthAltar, TradingPlaza, EventStage). Base row z -40..10.
  Red contested field = T shape: band x ±170, z -95..-40 in front of the bases + spine x ±20 north to z -235; cross junction at z -160
  (branches x ±20..50). Grey platforms x ±50..210, z -95..-225.
- **12 lots, not 8:** the export has **8 bases** (4 + 4 beside the NorthGate), not 6 + 6. Capacity stays 12: four copies of `Base4`
  (`Base9..12`) extend the row to x ±184 / ±220 (their inner walls line up with the town's end walls), on new floor/red band/rock parts
  (`HubMap2b.Ext2b`). Since the 10-20 repair (§7) the town wall stands at x ±242, so all 12 bases are inside and every base's back door opens onto the town walkway.
- **Fit (`H1_HubFit.lua`):** ScaleTo ×3.5714, half turn (Import 3D's), placed by Base1's centre (checks: Base8/TeleportHall/NorthGate within 0.05 studs).
  All meshes anchored, no collision / query / touch, `CollisionFidelity` Box; colours = GLB `baseColorFactor` (linear → sRGB);
  Wood / CorrodedMetal / Fabric for wood / iron / cloth, Neon for glow + portal surfaces, Glass for water/windows, Plastic otherwise;
  shadows only on buildings, walls and bases. Collision = 160 invisible boxes (`HubMap2b.Collision2b`): the 101 COL boxes + red field,
  spine seam, branches, platforms, NorthGate posts, 4 extra bases, and edge guards (6 tall) wherever a walkway meets the void.
- **Plots:** Plot1..12 (names, PlotId and code unchanged) moved into the bases, front = north (the red band); Plot1/2 next to the gate,
  then outwards (Plot1 → Base4, Plot2 → Base5, … Plot9..12 → Base9..12). Floor top y 0.35 (on the base floor). The plot's low fence is
  hidden (the base walls are the fence; the lock is logical, PvP `isInside` uses the Floor). The map's own 72 gold slot pads are parked
  (`_Parked2b.MapSlots`): the plot's stations are the pads. Pad spots (`BaseConfig.PAD_SPOTS`): 3 columns × 5 rows since §7
  (inside a base: x ±14, back wall z +20, front towers to z -20.5; every ring ≥ 1.6 studs from the side walls, ≥ 1.1 from the back wall).
- **Spawn** `Workspace.SpawnLocation` at hub (0, 0.5, 56) by the fountain, facing the bases. `SafeHubVolume` = the plaza (x ±50, z 10..120).
  `Hub.Floor` (home anchor) at the plaza centre. Shops / quest board / guide / `TopBillionaires` moved into the town
  (CosmeticShop, UpgradeForge, TradingPlaza west stall, beside the TeleportHall, EventStage west board). Arena + `BillionairePlaza` stay where they were (off at launch).
- **Parade:** `SkyCity.Ground.ParadeLane.Lane` (invisible now) along the whole red spine since §7 (spine end z -233 → NorthGate z -44):
  walkers walk towards the town; 179 studs at 2.6 studs/s ≈ 69 s, one every 9 s → 7-8 on the lane. Pinstripes/edge parked.
- **Parked** (`ServerStorage._Parked2b`, each with `ParkedFrom`): old LotBases, ReservedPlots, HideoutCamp, SkyCity.Hub pieces, hub ground/rocks/edges/trees,
  lane mouth tiles. Old hub: 647 parts (167 MeshParts). New hub: 476 parts (307 MeshParts + 169 blocks, 160 of them invisible collision);
  mesh tris ≈ 59.3k (57,550 − 8 × 6 slot pads + 4 copied bases). Old hub mesh tris: not measurable in Studio (no tri count API).

## 2. Zones on the grey platforms (`H2_Zones.lua`, `H2b_Portals.lua`)
- **Knight's Keep → west platform:** one rigid move, quarter turn (the Keep's north is now west); the bridge foot lands on the end of the
  west branch (hub -50, 0, -160). Spans hub x -50..-294 (the platform reaches x -290 since §7).
- **Sunken Kingdom + Ember Academy → east platform:** ONE move for both (the Sunken → Ember ramp still connects), quarter turn the other way,
  the Sunken ramp foot on the east branch (hub 50, 0, -160), 12.3 lower. Sunken x 50..276, Ember x 389..660 (not scaled; platforms under both since §7).
- Moved with them: `KnightsKeep`, `SunkenKingdom`, `EmberAcademy`, `Zones.*` (ZoneBoundary, SpawnPoints), `FutureZones.Our_SunkenKingdom` /
  `Zone6_BillionaireHills` (lane gates), `Bridges`, `BridgeGuards`, lane ramps/landings, `Start_MainStreet`, the safe line + banner,
  terrace/rocks/trees/clouds by position, and the ServerStorage templates that hold world positions: `HeistVault032` (door `Hinge` /
  `WheelCentre` points moved, `Axis` turned) and `SpellRunCourse034` (book `Axis` turned); photo spots.
- **Fixed for the move (code, defaults = old behaviour):** lane gates read barrier attrs `Inward` (+ `HalfWidth`, Sunken 64 so the red
  band never counts as Sunken) in `ZoneProgress`; the heist safe line reads `HomeSide` in `HeistService` / `HeistClient`. `SafeLaneVolume` =
  the junction square. The Keep's back terrace (led to the old Sunken ramp) is closed (`KnightsKeep.Access2b.TerraceEndGuard`).
  The Keep's `ZoneBoundary` was a quarter turn off its courtyard **before** tonight (78 across, 48 along): turned in place to match.
- **TeleportHall portals** work: invisible `PortalTrigger`s (tag `LanePortal`, ZoneId) on the Keep / Sunken / Ember pads → the normal Zones
  teleport and its checks. The Sealed_Future portal is decoration. Teammate portals T4-T7: parked since D48 (nothing to reconnect).
- Transforms stored on `HubMap2b`: attrs `KeepMove2b`, `SunkenMove2b` (037 world → now; the heist test uses KeepMove2b).

## 3. Zone guardians (`GuardianConfig`, `GuardianService`, `GuardianServer`, `GuardianClient`)
- Knight's Keep = Sir Malgrave, Sunken Kingdom = Aquaris, Ember Academy = Vault Wizard (the `BossHeist` entries; separate models from the
  heist chaser and from the Secret collectibles). Scale 2.5. Post: `Workspace.Zones.<zone>.GuardianPost` (`H3_GuardianPosts.lua`).
- **Rule:** wakes when a player carries a creature THEY caught in its zone (own record, `loc = carried`, `zone` = this zone; a stolen one never
  counts), chases and attacks only that carrier, never walks more than 8 studs outside its ZoneBoundary, gives up when the carrier is 40 studs
  outside it (or stops carrying / dies / leaves), walks back to its post.
- **Attacks:** the Boss Heist's three telegraphed attacks (same shapes, ranges and warnings ≥ 1.5 s): Searchlight 20 dmg (circle locks, walk out),
  Laser 25 (line, step aside), Stomp 20 (ring + wave, jump). 2.5 s between attacks, 1.5 s grace after a hit, chase speed 13.6 (= carry speed).
  Real Humanoid damage (a ForceField blocks it). **At 0 health:** the carried creature's record leaves the player's data and the same creature
  spawns back in the zone (`ZoneSpawner.dropBack`, no new roll), the player is knocked out and respawns at their base. Coins, stored and placed
  creatures and every other save field are untouched. Cartoon effects only (puff, "-20", sparkles).
- **Shared code, not copied:** `ServerScriptService.BossChase` (boss model, attack plan + hit test, jump check, clip timing) and
  `ReplicatedStorage.BossWarnings` (client warnings) were moved out of HeistService / HeistClient; the Boss Heist now uses them too.
- **Switch:** `GuardianConfig.ENABLED = true` (on, also live once published). **Turn off:** set it to `false`; in Studio only, ServerStorage
  attribute `StudioGuardian = false` overrides it. Off = nothing added to the world.

## 4. Spawns
`ReplicatedStorage.WildSpawnConfig`: BATCH_SIZE 8, BATCH_EVERY 120 s, used by all three zones in `NPCSpawner` (batch mode, odds unchanged).
A district zone starts its batch as soon as someone can collect there (was: wait a whole rotation). Keep and Ember got 2 checked spawn points
each (8 = a batch can always fill; `H4_SpawnPoints.lua`).

## 5. Checks (one solo Play, StudioMemoryStore, in-editor; plus the suites below)
- **Walks (real character, MoveTo, in-editor Play):** spawn by the fountain (hub 0, 56) facing the bases, health 100, Plot 1. Spawn → gate →
  junction → Keep bridge → courtyard 25.4 s; junction → Sunken ramp → gate → courtyard → palace → Ember ramp → Ember gate → Ember 36.2 s; no falls.
  The first walk FELL through a 5-stud collision gap where the red band meets the spine: fixed (`COL_SpineJoin`), then every route was
  ray-scanned at 1-stud steps (spawn/gate/junction, the whole band, base fronts, both zone routes): 0 gaps (one 1-stud side gap inside
  the Sunken palace's back door, unchanged by the move).
- **Free catch:** spawn → nearest parade walker → relayed catch in **7.9 s**, 0 coins; carry → Plot 1 → Place prompt → Station 1, income 11/s
  (+66 in 6 s). (In the first Play the new-player intro held the character ~20 s before it could move: the 10 s counts from control.)
- **Guardians:** Keep catch → Malgrave Wake → Chase within 4 s, telegraphed attacks (callouts SWORD THROW / IRONCALL / RIFTCLEAVE), 20-25 per hit.
  Ran out with the creature: gave up at the edge (see below), walked back to its post. Vault Wizard (COIN RAIN / VAULT BEAM) and Aquaris
  (TIDAL BREATH / WHIRLPOOL SLAM) wake and hit the same way. Carrying a Keep creature through Ember did NOT wake the Vault Wizard (own zone only).
- **Knock-out (on purpose, standing still):** KO after 22-42 s; the carried record left the save (records 2 → 1), the same creature came back
  among the Keep's wanderers, the player respawned at their base (Plot 1 spawn spot), coins kept rising from income (9,020 → 18,480), the
  placed creature stayed on its pad; message "Knocked out! Your creature ran back into Knight's Keep. You kept all your coins."
- **Give-up distance:** measured 28 studs past the box, because the Keep's `ZoneBoundary` was a quarter turn off its courtyard (since
  before tonight). Turned in place (matches the courtyard now; 8/8 spawn points + post inside); with it the give-up line is 40 studs past
  the courtyard's gate end, i.e. on the bridge. Re-measured in a second Play after the turn: gave up with the carrier 42.6 studs past the box.
- **Wanderers:** 8 / 8 / 8 in Keep / Sunken / Ember (server log: "new batch of 8" each zone).
- **Errors:** 0 game-script errors in the Play log (only Roblox HTTP 403 noise and one of my own test commands).
- **Suites (1 client each, one at a time, kill_tests before/after):** `creature035` **469/469** (17 SIM; new: batch checks for Sunken and
  Ember). `heist032:solo` **108/108** (3 SIM) after making the test layout-independent (its old-world points go through `KeepMove2b`;
  the first run was 107/108: its door check compared world X, the treasury is turned now). `base033:solo` **130/130** (26 SIM; not asked for, run because the plots moved). Not run: everything multi-client (not approved
  tonight), base033 duo/save, lane030, spellrun034, pvp022, hub026, parade028 (parade028/lane030/hub026 expect the old hub layout in places: likely stale).
- **Undo.lua:** run inside a Play session (thrown away on Stop): 191 unparked, 692 moves reverted, 13 attributes restored, plots / spawn /
  Keep / Sunken gate / safe line / lane / heist template back to their exact old values, 0 tags left. Edit place untouched.
- `verify_sync`: every file changed tonight matches (only the known old differences remain).

## 6. Undo
0. The 10-20 layout repair first: `tools/hub2b/R_Undo.lua` (Edit) — see §7.
1. Map: run `tools/hub2b/Undo.lua` (Edit): unparks `_Parked2b`, moves every `Moved2b` back (`Pre2bCFrame`/`Pre2bSize`), restores turned
   attributes, fences and lane look, puts created parts and the fitted map into `ServerStorage._Undone2b` and the as-imported `HubMap2b`
   back. Nothing is deleted. In-place copies: `ServerStorage._Backups.Pre2b`.
2. Code: `git checkout art-skin -- src` (+ `push_to_studio.py`), or the scripts in `backups/pre_hub2b_20261019_scripts`.
3. Whole place: `backups/pre_hub2b_20261019.rbxl` (before anything tonight, with the import). Per part: `backups/hub2b_part1_…`, `_part2_…`, `_part34_…`.

## 7. Layout repair (2026-10-20, `R1_LayoutRepair.lua`, undo `R_Undo.lua`)
Everything new is in `Workspace.HubMap2b.Repair2b`; moved/resized parts have attrs `PreR2CFrame`/`PreR2Size` + tag `MovedR2`; parked
pieces are in `ServerStorage._ParkedR2` (attr `ParkedFrom`). `R_Undo.lua` (Edit) reverts exactly (tested: run, undone, re-run).
- **Town wall at x ±242 (was ±170), all 12 bases inside.** The export's `KingdomWall` is one merged mesh per colour (both sides in one
  mesh), and Studio's cut-mesh pieces (`IntersectAsync` on a MeshPart → MeshPart without a MeshId) are NOT saved in the place file, so the
  wall is parked (`_ParkedR2.KingdomWall`) and rebuilt from parts in `Repair2b.KingdomWall2b` (123 parts): the same boxes, sizes and
  colours (side walls 3×8 + gold trim + merlons, end walls 4×14 at ±240, back wall z 200 now x ±17..242), towers / gold rings / cone roofs
  as 12-sided part unions (block minus 12 outside blocks: part unions ARE saved), flags/poles. The two AgeDetails meshes with pieces on the
  old side walls (stone_worn, foliage_light) are parked and rebuilt as parts in `Repair2b.AgeDetails2b` (wall pieces on the new walls).
- **Town strips** x ±170..243.5: grass (z 38..200) + rock below, the base-row floor `Ext2b.BaseRowFloor_*` now also the walkway (z -40..38),
  red band / rock extended to the new corner, 2 lanterns each side (x ±194, ±230). Collision: `COL_West/East` → ±242, `COL_EndWall_*` → ±240,
  `COL_South_*` to ±242, `COL_Ext_*` resized, new `Repair2b.Collision` (town strips + the 6 towers); `GUARD_Ext_Back_*` (behind bases 9-12's
  back doors) and `GUARD_Band_N_WW/EE` parked, `GUARD_Ext_End_*` moved to the band's new end (x ±245.5).
- **Grey platforms** (`Repair2b.Platforms2b`, collide): west extended to x -290 (Keep reaches -284), east to x 280 (Sunken to 274), a
  connector under the Sunken → Ember ramp (x 280..357, z -185..-135) and a third platform under Ember Academy (x 357..647, z -283..-17,
  covers the island and the Spell Run). Ember's island floats 15 studs up: its 4 cliff parts are carried down to the platform
  (`EmberPedestal_Cliff1..4`, same shape/colour/footprint). 14 invisible edge guards (`Repair2b.Guards`). Ember's hanging rocks and two
  clouds (`Summit031`) lowered so they don't poke through the new floor. Spell Run falls onto that floor are still caught (FallZone box
  reaches y -124..16).
- **Pads:** `BaseConfig.PAD_SPOTS` = 3 × 5 grid (x -9/0/9; z 15.5/7.75/0/-7.75/-15.5): pads 1-6 back two rows, 7-12 middle, 13-14 front
  corners, front middle free for the gate. Ids, prices, count (14) unchanged.
- **Parade:** lane = whole spine (above); `ParadeConfig.WALK_SPEED` 4 → 2.6 (spawn rate unchanged: one walker every 9 s, so catches on
  offer per minute are the same); walkers `ModelStreamingMode.Persistent` (they move on the clients only, the server copy stays at the spawn
  point, so streaming could drop one a player can see).
- **Play check (solo, in-editor, StudioMemoryStore, test player held to Plot 12 = Base12 by marking Plots 1-11 taken; cleared after):**
  all 12 bases → plaza on foot through their back doors (path 98-247 studs, symmetric W/E), no falls; plaza → Keep courtyard (junction →
  west branch → bridge) and plaza → Sunken → Ember (lane centre line) no falls; free parade catch → Plot 12 pad 1, income 11/s; pads in the
  base ≥ 1.6 studs from the side walls; parade: server 7-8 walkers steady, client sees 6-7 complete walkers from the spawn point; Keep
  guardian woke on a Keep catch, chased + hit (100 → 46 hp), gave up and walked back to its post with the carrier on the bridge 28-50
  studs past the boundary (test run speed 24, rule 40); 0 game-script errors. Test speeds 40 (walks) / 24 (run-out), not the game's.
  Not run: any multi-client test, the test suites.

## 8. Visual review fixes (2026-10-20, `V1_VisualFix.lua`, undo `V_Undo.lua`; D51)
Everything new is in `Workspace.HubMap2b.VisualFix2b`; parked pieces are in `ServerStorage._Parked2b.VisualFix` (attr `ParkedFrom`).
Undo order: `V_Undo.lua`, then `R_Undo.lua`, then `Undo.lua`. **§7's platforms, connector, Ember platform/pedestal and their guards
are parked by this step.**
- **Red path:** the export's red T (`ContestedLane_2a`: band + 40-stud spine, one mesh) + its rock parked and rebuilt as parts
  (`VisualFix2b.RedPath`): band unchanged, spine 20 studs wide (x ±10), rock under both. Parade walkers stay on it (offsets ±3.5).
- **Parked:** `Hub2b.ZoneConnectors_Unchanged` (grey platforms + short red branches), §7's `Repair2b.Platforms2b` / `Repair2b.Guards`,
  `KnightsKeep.Bridge036`, both `SkyCity.Lane.Ramp` models, `Bridges.BillionaireHillsBridge`, `FutureZones.Zone6_BillionaireHills.Path`,
  23 Collision2b boxes/guards (platforms, branches, old 40-wide spine, their guards).
- **Red path to each entrance (collides, 20 wide, 25 invisible 6-stud edge guards):** west: junction → flat to x -50 → ramp to 13.5 at
  x -98 → flat onto the Keep island (x -140), new `KeepEntranceArch` ("ZONE 1 · KNIGHT'S KEEP · FREE", a copy of the gate frame, no
  barrier). East: junction → ramp to 12 at x 92 → under the Sunken gate paving to x 116 (gate x 104). Ember: from the Sunken palace's
  back door (x 269.7, 13.6) → ramp to 24 at x 313 → under the Ember gate paving to its island (x 372; gate x 325.5).
- **Gates:** `ZoneConfig` Sunken 10,000 (was 50,000). `ZoneGates` writes the price on the gate's lock plate ("10,000 COINS",
  "500,000 COINS", gold, big) instead of "COIN UNLOCK"; unlock + save are the existing ZoneProgress ones.
- **Treasury:** `HeistConfig.ENABLED = false` (no vault, no "Treasury m:ss" pill; the Golden pill stays).
- **Boss hit effects on the warnings:** `GuardianService` sets `VW_HitSpot` (+ `VW_HitAcross` / `VW_HitLength` for the line) on the boss
  model; Malgrave's and the Vault Wizard's `Vfx` use it (copied into `BossRigs.<Name>.Template.Runtime.Vfx` too): the thrown sword
  lands on the locked circle (was 3-19 studs off; now 0.7-0.8), Riftcleave's crack runs along the red strip, Ironcall / Coin Nova
  rings and Coin Rain sit on the warning centre (0.0 off). Damage, ranges, timing unchanged. Aquaris draws no ground circles of its own.
- **Play check (solo, in-editor, StudioMemoryStore):** spawn → narrow red path (7 walkers seen, all within 2.9 of the centre line) →
  free catch → pad 1, 11/s; plot → Knight's Keep along the red path, no unlock needed, no falls; Sunken gate blocks (stopped at x 102.9),
  plate "10,000 COINS", buying with 1,606 refused, with 12,256 bought (-10,000), walked through, then up to the Ember gate (blocked at
  324.5; with dev tools on, into Ember, no falls); attacks measured as above; HUD: Golden pill only; 0 game-script errors. Test walk speed
  30-40; coins via Studio `/devcash`. Not run: multi-client, the test suites (heist032 / lane030 / hub026 expect the old setup).

## 9. Visual review 2 (2026-10-20, `V2_Review2.lua`, undo `V2_Undo.lua`)
New parts: `Workspace.HubMap2b.Review2`; parked: `ServerStorage._Parked2b.Review2`; moved/resized: tag `MovedV2` (attrs `PreV2*`).
Undo order: `V2_Undo.lua`, `V_Undo.lua`, `R_Undo.lua`, `Undo.lua`.
- **Knight's Keep 66 studs closer** (rigid +X move, no turn): KnightsKeep, Zones.MainStreet (ZoneBoundary now centred x -125.5,
  SpawnPoints, GuardianPost), SkyCity.MainStreet / Ground.Island4 / MainStreetCurb / MainStreet, Start_MainStreet, hedges, rocks,
  trees, a cloud, PhotoSpotsDev, the HeistVault032 template (+ Hinge/WheelCentre), the FREE arch. `KeepMove2b` updated.
- **Keep path** 20 wide, x -10..-76 (was -10..-140): flat to -22, ramp to 13.5 at -66, onto the island. The "SAFE ZONE ENDS HERE"
  gate stands on the flat part at x -16, fitted to the path (posts on its edges, sign 18 / gold line 20 long, the 2 stripes that
  hung over the void parked).
- **Red band** 55 -> 30 deep (z -70..-40); the spine reaches it at z -70 (collision = `COL_ReturnPlaza`; `COL_RedBand_Far` parked;
  `Ext2b` band/rock and `COL_Ext_RedBand_*`, `GUARD_Ext_End_*` resized). Every base door has floor in front; parade unchanged.
- **Boss rings:** the rune circle and energy ring (Malgrave, Vault Wizard) were emitted from the whole flat ground helper part, so
  each ring spawned anywhere up to the aura radius from the boss; now from a centre attachment (0.00 studs off, measured).
  Aquaris' ring is drawn around its root (already centred). Warnings: stomp ring 0.01 studs off the boss.
- **Faster attacks** (`GuardianConfig`): warnings 1.0 / 0.9 / 0.8 s (were 2.0 / 1.8 / 1.6), searchlight follow `track` 0.3
  (was 0.6, now in config), `ATTACK_GAP` 1.25 (was 2.5), `MIN_WARNING` 0.8; damage unchanged. Clips whose wind-up is longer than the
  new warning start part-way (`BossChase.playClip`: `VW_ClipT0` = the planned start), so impacts still land on the hit.
- **Bat swing:** avatars now have `AnimationConstraint` joints (Roblox joint upgrade), not Motor6Ds; `PvPFx` only looked for Motor6D,
  so the code-posed swing never showed. It now poses either (R15 `RightShoulder`, R6 `Right Shoulder`). Bat damage/cooldown/knockback
  unchanged.
- **Play check (solo):** rings 0.00 off; Keep attacks every ~3 s (warning 1.3 / 0.9 / 0.8 s, ~1.8 s after a hit); bat swing: arm
  raised from -39 to 88 deg and swept on a real swing (R15; R6 not tested); spawn -> Keep 312 studs walked (Keep leg ~half), no
  falls; 7 walkers; free catch -> pad; 0 script errors. Not run: multi-client, test suites.

## 10. Pads + Zone 3 map (2026-10-20, D52; `tools/zone3/`)
Backups: `backups/pre_zone3necro_20261020.rbxl` (before), `backups/zone3necro_playsnap_20261020_0302.rbxl` (after; the 03:02 Play snapshot, the planned after-backup was never written). Undo order: `Z2_IslandRail.lua`
with `UNDO = true`, `Z1_Undo.lua`, `Z0_PadSize.lua` with `UNDO = true` (prelude via `run_file.py <file> "UNDO = true"`), then the older ones.
- **Pads:** measured against every base part (the base GLB's triangles mapped into plot space: `pad_clear.py` / `pad_map.py`, plus the
  colliders and the plot gate). The old 3x5 grid had pads 13/14 touching the gate posts (0.05), 10/12 0.5 from the gold wall brackets,
  the back row 1.1 from the back wall; 14 pads at ring 6.8 don't fit with 1.5 clearance. Now `PAD_SPOTS` x ±8.9 / 0, z 15.2 / 8.3 /
  1.35 / -5.6, pass pads (±8.9, -12.6); station pads 6 -> 5.4, rings 6.8 -> 6.2 (`Z0_PadSize.lua`, attr `PreZ0Size`). Closest: pads
  10/12 to the brackets 1.54, back row to the back wall 1.55-1.7, others >= 2.0; 0.7 between pads. Ids, prices, count unchanged.
- **Zone 3 map (`Z1_NecroZone3.lua`):** `necromap.glb` (owner's Import 3D, 1 stud = 1 m) -> `World.EmberAcademy.Zone3Map`, x3, gate
  (GLB -Y) facing the Zone 3 price gate, GLB +X = +Z. GLB origin -> (391.52, 24.1, 540); gate front x 332, town x 330-453, z 464-616,
  spire top y ~121. Colours from the GLB (linear -> sRGB), Neon for glow/FX, mist 0.82 / veil 0.85 transparent. All meshes no
  collide/query/touch except `Ground_ground_ash` (Box). `Collision` = 138 boxes (GLB welded, loose parts, merged; buildings one box each);
  `Guards` on the wall line (15 studs high), open only at the gate and at the east-wall gap (z 506-515) that leads onto Ember's island.
  Scale 3 (hub scale is 3.57) because the Spell Run start pad (x 460-473, z 596-608) must stay outside the map.
- **Kid-safe (Blender renders + names), parked in `ServerStorage._ParkedNecro`:** all 8 `*_bone` meshes (skulls, horned skull + ribcage
  on the plaza throne, bone piles, horns on the spire/gate), the graveyard (`Graveyard_stone_dark/stone_grey` tombstones, crosses,
  obelisks, crypt; `_cobble_dark` grave slabs; `_iron_black` fence + crypt door; `_glow_necro`, `_wood_dark`, `_vine`), `Plaza_glow_necro`
  (the pentagram on the plaza floor + crystals). Kept: dark houses, the spire, chapel ruins, throne (stone), dead trees, lamps, wisps,
  mist, the green pool. The 16 marker cubes are in `_ParkedNecro.Helpers_Markers`.
- **Ember parked** (`ServerStorage._ParkedEmber`, 24 items): avenue, arch, towers, library, spire, lab, books, rune circles, lanterns,
  balustrade. Kept: `SpellRun` (live Spell Run), `Summit031` rocks, the island, the price gate, the red path. The path's side guards
  (`GUARD_Ember_Gate_N/S`, `BillionaireHillsBridgeGuard±1`) cut to end at x 334.5 inside the map's gate wall (attrs `PreZ1*`).
  `Z2_IslandRail.lua`: Ember's balustrade is the island's 3-stud edge rail: the 33 pieces outside the map + `Ember036EndRail` are back,
  4 long rails cut at the map's east wall (attrs `PreZ2*`), 18 pieces inside the map stay parked.
- **Zone 3 anchors:** `ZoneBoundary` = the empty graveyard lot (69 x 42 at (391.5, 34.1, 491); wanderers walk straight lines, so the box
  covers open ground only), `Spawn1-8` on the lot (all on the ground slab, nothing within 4 studs), `GuardianPost` (391.5, 24.1, 508.5).
  Zone teleports still land in front of the price gate (unchanged). Guardian + Secret = Vault Wizard (the new boss was not in the place).
- **Play check (solo, in-editor, StudioMemoryStore, StudioDevTools on):** pads at the new spots/sizes in Plot 11 (outer) and Plot 1
  (inner, 8 pads), non-mesh clearance >= 1.70 in Plots 1/2/11/12 (unlock pad not shown: only appears when all pads are full; same spot
  code). Walk Sunken back door -> path -> gate -> town -> lot, root y 27.1 inside (no falls); lot -> east gap -> Spell Run pad and back;
  walking at the closed gaps stops at the guards. 8 wanderers spawned, all in the lot. Catch -> Vault Wizard attacked (hp 33 -> 14),
  chased, max 6.7 studs outside the zone, went back to its post with the carrier 33 out; earlier a KO at 0 hp. 0 script errors (log).
  Test walk speeds 24-30. Not run: multi-client, test suites.

## 11. Zone 3 access from the junction (2026-10-20, D53; `tools/zone3/Z3_Access.lua`, undo `Z3_Undo.lua`)
Backups: `backups/pre_zone3access_20261020.rbxl` (before), `backups/zone3access_20261020.rbxl` (after). Undo order: `Z3_Undo.lua`,
then §10's (Z2, Z1, Z0), then the older ones.
- **Which arm:** the junction (z 540) has west -> Keep, east -> Sunken, south -> bases; the dead end is the spine's north stub
  (z 540 -> 465). Zone 3 was east past Sunken, so the **whole Zone 3 group moved** (option 2): one rigid move, quarter turn (zone
  inward +X -> -Z), lowered 10.5 (gate paving top 24 -> 13.5). Transform on `HubMap2b` attr `Zone3Move`; moved items: attr
  `PreZ3CFrame` + tag `MovedZ3`; turned attrs (`Inward` on the gate barrier, `Axis` on the spell books): `PreZ3<name>`.
- **Moved:** `World.EmberAcademy` (Zone3Map, SpellRun, Balustrade, Summit031, Ember036EndRail), `FutureZones.Zone6_BillionaireHills`
  (gate + 500,000 price plate, FastTravelAnchor, BossReserve, FutureNPCArea), `Zones.BillionaireHills` (ZoneBoundary, Spawn1-8,
  GuardianPost), `Islands.BillionaireHillsIsland`, `Lane.T3_EmberAcademy`, `VisualFix2b.RedPath.Ember_GateFloor` + `GUARD_Ember_Gate_N/S`,
  `BridgeGuards.BillionaireHillsBridgeGuard±1`, lane rocks/clouds east of x 300, ServerStorage `SpellRunCourse034` (race template),
  `_ParkedEmber`, `_ParkedNecro` (so they fit if restored). Now: gate barrier (0, 18.7, 396.5) inward (0, 0, -1); town x -77..75,
  z 272..391; lot centre (-49, 330); Spell Run pad (56, 16.5, 255); course x 37..131, z 82..261.
- **New (`Workspace.HubMap2b.Zone3Access`):** `RedPath.North_Flat` (z 465 -> 453, top 0) + `North_Ramp` (z 453 -> 409, top 0 -> 13.5),
  20 wide like the spine, rock under both (`North_FlatRock`, `North_RampRock`); `Guards`: 4 edge guards (x ±10.5, 6 tall, ramp ones
  tilted) joining the spine guards and the gate paving guards; `SunkenBackDoorBlock` (invisible, x 268.7-271.2, z 534-546, y 13-33;
  the door panel stays, so it reads as a closed door); `PlazaIslandFallGuard` (invisible wall at z 73, x 98-148: the Spell Run's
  Landing2 now ends ~12 studs from the old PlazaIsland coast, 27 studs higher; a fast jump would land on it instead of in the FallZone).
- **Parked** (`ServerStorage._Parked2b.Zone3Access`, attr `ParkedFrom`): `Ember_Ramp` + `GUARD_Ember_Ramp_N/S` (old Sunken back door ->
  Zone 3 route), the lane rock under that ramp, `GUARD_Spine_End`.
- **Code:** none. `ZoneProgress` lane gates already read `Inward`; race, spawns, guardian, teleports read moved parts.
- **Play check (solo, in-editor, StudioMemoryStore, test walk speed 24-30):** spawn -> spine -> junction -> north arm -> ramp: stopped
  at z 397.6 by the gate (barrier 396.5), plate "500,000 COINS", buying with 0 refused ("Unlock Sunken Kingdom first"); `/devcash 600000`
  (dev tools then off) -> Sunken + Zone 3 bought (90,000 left) -> through the gate into the lot. 8/8 wanderers inside the ZoneBoundary.
  Catch -> Vault Wizard Wake -> Attack -> Chase (max 5.4 studs outside the zone) -> Return when the carrier was 47 out -> Post; a KO
  earlier (respawn at base). Lot -> east wall gap -> Spell Run pad (1.2 off); live RaceCourse copy on the course. Sunken courtyard ->
  palace -> back door: stopped at x 267.9. Floor ray scan spine end -> map plaza: 0 holes; edge guard scan z 466 -> 388: 0 gaps.
  No falls (lowest root y 3.0 on the path). 0 game-script errors (log). Not run: multi-client, test suites.
- **Known:** the parade walkers still start at the spine's north end (now the start of the Zone 3 path), unchanged. One short MoveTo
  snag inside the town near the east-wall gap (prop box, same as before the move).

## 12. Spell Run off, Zone 3 on the west side, parade on the band (2026-10-20, D54; `tools/zone3/Z4_SideZone3.lua`, undo `Z4_Undo.lua`)
Backups: `backups/pre_sidezone3_20261020.rbxl` (before), `backups/sidezone3_20261020.rbxl` (after). Undo order: `Z4_Undo.lua`, then
§11's `Z3_Undo.lua`, then the older ones. Code: `RaceConfig.ENABLED = false`, `StoreClient` speed text ("Races stay the same" dropped),
`ParadeConfig` comment. Studio attr `StudioRace` removed (Studio follows the config).
- **Spell Run parked** (`ServerStorage._ParkedSpellRun`, attr `ParkedFrom`): `EmberAcademy.SpellRun`, `Balustrade` (the island rail),
  `Ember036EndRail`, `Summit031`, `Islands.BillionaireHillsIsland`, `SpellRunCourse034` (race template). `_ParkedSpellRun.Plaza`: the
  old plaza island (`Islands.PlazaIsland`, `WorldBounds.PlazaRing*`) and what stood on it (`SkyCity.Hub.Vault/Arena/GateLines`,
  `Venues.Arena`, `BillionairePlaza` CentreSeal/BypassRing/ArenaEdge, 10 trees, 2 hedge caps, 2 rocks) + `PlazaIslandFallGuard`.
  `BillionairePlaza.ArenaFloor` stays (ZoneProgress waits for it), hidden + no collide (attrs `PreZ4*`). The Zone 3 wall gap to
  the Spell Run: `Zone3Map.Guards.Guard_East_Gap` (invisible, like the rest of that wall line). The race UI (`Race031`) still builds
  but every panel stays hidden while `RaceOn` is unset.
- **Spine ends at the junction:** `Spine` z 530..630, `SpineRock` z 532..628 (attrs `PreZ4Size/CFrame`), `Zone3Side.Guards.
  GUARD_Spine_JunctionEnd` (z 529-530, x ±10.5). Parked (`_Parked2b.Zone3Side`): §11's north path + rock + guards, `GUARD_Spine_E_B/W_B`,
  the band's west end guard (replaced by `GUARD_BandEnd_W_N/S`, open z 635..655).
- **Side used: west.** The box west of the hub (x -480..-250, z 520..780) was empty; east has Sunken's palace (to x 298) + hub clouds.
  Branch (`Zone3Side.RedPath`): from the band's west end x -245.5 at z 645: `West3_Flat` to x -257.5 (top 0), `West3_Ramp` to x -301.5
  (top 13.5), 20 wide (z 635..655), rock under both, 4 edge guards (z 634.5 / 655.5). Zone 3 group (as §11) moved once more: quarter
  turn (inward -Z -> -X), gate paving edge at the ramp top (transform `HubMap2b.Zone3Move4`, tag `MovedZ4`). Now: barrier (-314, 18.7, 645)
  inward -X; town x -440..-318, z 569..723; ZoneBoundary (-380, 23.6, 694); GuardianPost (-380, 13.6, 676.5). Keep (x >= -205) 100+ studs away.
- **Parade lane** (`SkyCity.Ground.ParadeLane.Lane`): x -92.5..92.5 along the band (z 645), 185 x 0.5 x 16; walkers appear at x -88.5
  and leave at x 86.5 (~175 studs, ~67 s at 2.6). `WALK_SPEED`, `SPAWN_INTERVAL`, `MAX_ON_LANE` unchanged.
- **Play check (solo, in-editor, StudioMemoryStore, test walk speed 24-30):** RaceOn unset; no Spell Run text in the PlayerGui or the
  world (Race031 panels all hidden). Spawn -> band -> spine -> junction -> Keep island (free, walked in); -> Sunken gate: stopped at x 102.9
  (0 coins); junction north end: stopped at z 530.8; band -> west branch -> Zone 3 gate: stopped at x -312.9. `/devcash 600000` (dev tools
  then off): Zone 3 refused before Sunken ("open in order"), Sunken bought + walked in, Zone 3 bought + walked into the lot (90,000 left).
  Zone 3: 8 wanderers (7 inside after one catch); catch -> Wake -> Attack (hp 100 -> 80) -> Chase (max 8.0 studs outside, the cap) ->
  Return when the carrier was 47 out -> Post. Parade: 7-8 walkers in every 4-s sample over 32 s, x -72..70, z 642..646. Branch floor scan
  0 holes, edge guards 0 gaps. No falls (lowest root y 2.9 on the paths). 0 game-script errors (log). Not run: multi-client, test suites
  (`DevTest_SpellRun034` / `race031` now test a parked feature).

## 13. Main road, Zone 3 on its right (2026-10-20, D55; `tools/zone3/Z5_MainRoad.lua`, undo `Z5_Undo.lua`)
Backups: `backups/pre_mainroad_20261020.rbxl` (before), `backups/mainroad_20261020.rbxl` (after). Undo order: `Z5_Undo.lua`, then
§12's `Z4_Undo.lua`, then the older ones. Code: none. **§12's Zone 3 place and west branch are superseded; its Spell Run / parade parts stand.**
- **Top-down (north = -Z, world studs):** bases + red band z 605..660 -> spine x ±10 north to the junction (z 530..550; west arm ->
  Keep x -200..-59, east arm -> Sunken gate x 104, Sunken x 108..274 z 504..576) -> **main road** x ±10, top 0, z 530 -> 140, end guard
  at z 140. **Zone 3 branch** at z 400 on the right (east): flat x 10..22, ramp x 22..66 to 13.5, 20 wide (z 390..410); gate barrier
  (78.5, 18.7, 400), inward +X; town x 84..203, z 323..475 (gate group to x 276); ZoneBoundary (144.5, 23.6, 351), GuardianPost
  (144.5, 13.6, 368.5), FastTravelAnchor (154.6, 16.3, 393). Zone 3 is 28 studs north of Sunken. **Empty for the next zone:** right side
  of the road z 140..~320 (the road's left side north of Keep is empty too).
- **New (`Workspace.HubMap2b.MainRoad`):** `RedPath.Road` + `RoadRock` (joins `SpineRock`), `East3_Flat/Ramp` + rocks; `Guards`:
  `GUARD_Road_W`, `GUARD_Road_E_South/North` (opening z 390..410), `GUARD_Road_End`, `GUARD_East3_Flat/Ramp/Seam_N/S` (6 tall,
  invisible; the seam pieces fill a low wedge where flat and ramp guards meet). `Zone3Side.Guards.GUARD_BandEnd_W` (CreatedZ5): the band's
  west end closed again.
- **Moved (one rigid move, half turn, inward -X -> +X, gate paving edge at the ramp top):** the same Zone 3 group as §12 (Zone3Map,
  gate + 500,000 plate, ZoneBoundary, Spawn1-8, GuardianPost, FastTravelAnchor, BossReserve, FutureNPCArea, T3 tile, gate paving +
  guards, bridge guards, the lane rocks/clouds that travel with it) plus the parked `_ParkedEmber`, `_ParkedNecro` and
  `_ParkedSpellRun` Spell Run pieces (not `.Plaza`), so they still fit if restored. Transform `HubMap2b.Zone3Move5`; attr `PreZ5CFrame`, tag `MovedZ5`.
- **Parked:** `_Parked2b.Zone3West` (11): `West3_Flat/Ramp/FlatRock/RampRock`, `GUARD_West3_*`, `GUARD_BandEnd_W_N/S`,
  `GUARD_Spine_JunctionEnd`. `_Parked2b.MainRoad`: 2 lane clouds under the new Zone 3 spot.
- **Edit checks:** road floor ray scan z 141..529: 0 holes (all top 0); branch profile 0 -> 13.5 smooth, gate paving 13.5-13.7;
  edge guard ray scan road + branch (3 heights): 0 gaps after the seam pieces.
- **Play check (solo, in-editor, StudioMemoryStore, test walk speed 28, dev tools off except for `/devcash`):** spawn -> band -> spine
  -> junction -> road -> branch -> stopped at x 77.4 by the Zone 3 gate (barrier 78.5); plate "ZONE 3 · EMBER ACADEMY / LOCKED /
  500,000 COINS"; buying with 0 refused ("Unlock Sunken Kingdom first"). Road end: stopped at z 140.8; road edges hold (x ±9.3). Keep
  island (-140, 16.5, 540) reached (free); Sunken gate stopped at x 102.9. `/devcash 600000`: Zone 3 refused again before Sunken, Sunken
  bought, Zone 3 bought (90,000 left), walked through the Zone 3 gate into the town (139, 16.6, 371) and through the Sunken gate
  (125.7, 14.8, 540). Zone 3: 8/8 wanderers inside the ZoneBoundary, guardian at its post (145, 20, 368). Parade: 7-8 walkers in every
  4-s sample, x -85..84, z 642..648 (unchanged). No falls (lowest root y 2.94 on the paths). Server + client LogService: 0 errors
  (1 StudioMemoryStore warning, UIBlox CoreGui warnings). Not run: multi-client, test suites, guardian chase (unchanged code).
