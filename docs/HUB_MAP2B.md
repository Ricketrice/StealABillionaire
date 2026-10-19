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
