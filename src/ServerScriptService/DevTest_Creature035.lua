-- Studio location: ServerScriptService.DevTest_Creature035 (Script)
-- DevTest_Creature035  (Milestone 035) -- STUDIO-ONLY solo test of the creature models. Inert unless Studio started
-- the session with StudioTestService and the argument "creature035" (1 client, in-memory save: ServerStorage
-- StudioMemoryStore = true). Launch from Edit with
--   task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1, "creature035") end)
-- and watch with `TAG=T035 tools/test_guard.sh creature035`. Results: "@@T035|".
--   models   every spec has a model within its rarity budget, R15 names, Humanoid, Animate; signature items exist;
--            animated props bind; all roster ids that have a spec are listed (those without are reported)
--   same     wanderer (rolled at spawn) = template = carried = placed = rebuilt-on-pad: same name + colour signature;
--            carried scale <= 1.3, pad scale <= 1.6; reveal fires (WorkerUid, Rarity) on catch; name tag text
--   odds     SIMULATED: 10,000 rolls per zone are within tolerance of the catalogue's rarity odds
--   parts    SIMULATED: 12 lots x 6 pads and x 14 pads filled with creatures drawn by the odds: Workspace part total,
--            Common/Rare average parts (<= 40 wanted)
--   cap      real server, player standing in each zone: wanderers reach the cap (10 Knight's Keep, 8 Sunken Kingdom /
--            Ember Academy for one player) and never exceed it; most spawn within ~125 studs of the player; wanderers
--            more than 80 studs away are Dormant (frozen), near ones are not; parts of the zone's wanderers at the cap

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "creature035") then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s: %s | %s"):format(kind, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T035|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d (simulated checks=%d)"):format(state, passed, failed, simulated)
	print("@@T035|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end
local function expect(name: string, condition: any, detail: any?, sim: boolean?)
	if sim then
		simulated += 1
	end
	if condition then
		passed += 1
	else
		failed += 1
		note(if sim then "FAIL(SIM)" else "FAIL", name, detail)
	end
end
local function info(name: string, detail: any)
	note("INFO", name, detail)
end
local function waitUntil(seconds: number, check: () -> any): any
	local deadline = os.clock() + seconds
	repeat
		local value = check()
		if value then
			return value
		end
		task.wait(0.1)
	until os.clock() > deadline
	return nil
end
local function scenario(name: string, run: () -> ())
	section = name
	local ok, err = pcall(run)
	if not ok then
		failed += 1
		note("ERROR", "scenario stopped", err)
	end
	print("@@T035|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

local PlayerData, PlotService, WorkerInventory = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory")
local NPCClaim, NPCPlacement, ZoneArea = mod("NPCClaim"), mod("NPCPlacement"), mod("ZoneArea")
local WorkerService, WorkerAppearance, CreatureBuilder = mod("WorkerService"), mod("WorkerAppearance"), mod("CreatureBuilder")
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any
local CreatureSpecs = require(ReplicatedStorage:WaitForChild("CreatureSpecs")) :: any
local CreatureAnim = require(ReplicatedStorage:WaitForChild("CreatureAnim")) :: any

local BUDGET = { Common = 34, Rare = 49, Epic = 80, Legendary = 150, Secret = 250 } -- part-built looks: ALL parts, hidden R15 rig included (as before)
-- Roster kit models (CreatureSpecs.KIT_B1): VISIBLE parts only (the hidden R15 rig, Transparency 1, is excluded), triangles from the Blender report.
local KIT_BUDGET = { Common = 30, Rare = 45, Epic = 80, Legendary = 150, Secret = 250 }
-- Epic raised 5,000 -> 8,000 (owner, 2026-10-16, a ceiling not a target: the layered-plate armour style needs the room).
local KIT_TRIS = { Common = 2000, Rare = 3000, Epic = 8000, Legendary = 8000, Secret = 12000 }
local KIT_SIGNATURE = {
	broke_bob = { "Sword_Wood", "Helmet_Steel" },
	delivery_dave = { "Scroll_Parchment", "ScrollSheet_Parchment" },
	training_dummy = { "UpperTorso_Red", "CrossBar_Wood" },
	street_hustler = { "Bow_Wood", "Apple_Apple" },
	business_betty = { "Pole_Pole", "FlagA_Flag" },
	security_sam = { "Shield_ShieldBlue", "Sword_Steel" },
	crypto_carl = { "Hammer_IronDark", "Hammer_Ember" },
	ceo_chad = { "Sword_Blade", "Burst_Halo" },
	mystery_millionaire = { "Shield_Blue", "Sword_Blade" },
}
local BOSS_SIGNATURE = {
	mystery_millionaire = { "Greatsword", "TatteredCape", "Head" },
	the_trillionaire = { "WizardTopHat", "Tool_LedgerScepter", "Head" },
}
local ODDS = { Common = 70, Rare = 20, Epic = 8, Legendary = 1.8, Secret = 0.2 }
local SIGNATURE = {
	broke_bob = { "SwordBlade", "Helmet" },
	delivery_dave = { "ScrollRoll" },
	training_dummy = { "TargetRed" },
	street_hustler = { "BowMid", "Apple" },
	business_betty = { "Pole", "FlagA" },
	security_sam = { "Shield", "Sword" },
	crypto_carl = { "HammerHead" },
	ceo_chad = { "Blade" },
	mystery_millionaire = { "Shield", "Blade" },
	bubble_fish = { "Bowl", "Tank" },
	hermit_porter = { "Shell", "CrateA" },
	coral_snail = { "Shell", "StalkL" },
	puffer_guard = { "Belly", "SpearShaft" },
	mermaid_mage = { "StaffShaft", "StaffPearl" },
	shark_knight = { "SharkHood", "Blade" },
	pearl_seahorse = { "Bubble", "TailPearl" },
	tide_warden = { "TridentShaft", "Coral1" },
	aquaris = if CreatureSpecs.AQUARIS_BOSS then { "Head_Blue", "Jaw_Ice", "TailC_Gold", "Body_Gold", "WingL_Membrane" } else { "Snout", "Jaw", "Tail1", "NeckSpike3" },
	butler_barnaby = { "Candle", "Flame" },
	caddie_gus = { "Snout", "Lantern" },
	bookling = { "CoverTop", "TeethTop" },
	polo_pro_penny = { "Quill", "WingL" },
	chef_pierre = { "Hat3", "FireL", "FireR" },
	bodyguard_boris = { "ChestRune", "FistL" },
	hedge_fund_hank = { "WingL", "WingR", "TailA" },
	oil_baron_oswald = { "StaffOrb", "RuneA" },
	the_trillionaire = { "StaffOrb", "CircleOuter", "HatFlame" },
}

local function parts(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end
-- Visible parts: everything that renders (the hidden R15 rig of kit models has Transparency 1).
local function visibleParts(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			n += 1
		end
	end
	return n
end
-- Name + colour of every part (sizes depend on the current scale, so they are left out).
local function signature(model: Instance): string
	local t = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			table.insert(t, d.Name .. ":" .. d.Color:ToHex())
		end
	end
	table.sort(t)
	return table.concat(t, ",")
end

local function ready(p: Player): boolean
	local c = p.Character
	return p.Parent ~= nil and PlayerData.isLoaded(p) and PlotService.getPlot(p) ~= nil and c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil and WorkerInventory.isReady(p)
end
waitUntil(240, function()
	for _, p in Players:GetPlayers() do
		if ready(p) then
			return true
		end
	end
	return false
end)
task.wait(3)
if not (ServerStorage:GetAttribute("StudioMemoryStore") == true or not PlayerData.isPersistent()) then
	finish("ABORTED: run creature035 on the in-memory save (ServerStorage StudioMemoryStore = true)")
	return
end
local A = Players:GetPlayers()[1]
if not (A and ready(A)) then
	finish("ABORTED: needs one loaded player")
	return
end
local models = ReplicatedStorage:WaitForChild(CreatureBuilder.FOLDER)

local function models_()
	local missing = {}
	for zoneId, roster in WorkerCatalogue.ZONES do
		if zoneId == "MainStreet" or zoneId == "SunkenKingdom" or zoneId == "BillionaireHills" then
			for _, id in roster do
				if not CreatureSpecs[id] then
					table.insert(missing, id)
				end
			end
		end
	end
	info("ids without a spec yet (still their old look)", table.concat(missing, ","))
	local count = 0
	for id, spec in CreatureSpecs do
		if type(spec) ~= "table" then
			continue
		end
		count += 1
		local worker = WorkerCatalogue.get(id)
		local model = models:FindFirstChild(id)
		expect(id .. " has a worker entry", worker ~= nil)
		expect(id .. " has a model", model ~= nil)
		if worker and model then
			local kitModel = model:GetAttribute("KitModel") -- set by CreatureBuilder only when the kit meshes were really used
			if spec.kit then
				info(id .. " kit", if kitModel then "using " .. tostring(kitModel) else "FALLBACK (import missing / wrong axes): part-built look")
			end
			local rigName = model:GetAttribute("BossRigName") -- 036 boss pass: a rigged boss welded to the hidden R15 root
			local visible = kitModel or rigName
			local n = if visible then visibleParts(model) else parts(model)
			local cap = if visible then KIT_BUDGET[worker.rarity] else BUDGET[worker.rarity]
			expect(("%s %sparts %d within %s budget %d"):format(id, if visible then "visible " else "", n, worker.rarity, cap), n <= cap)
			if rigName then
				local rig = model:FindFirstChild("BossRig")
				local motors, loose = 0, 0
				if rig then
					for _, d in rig:GetDescendants() do
						if d:IsA("Motor6D") then
							motors += 1
						end
					end
					for _, d in rig:GetChildren() do
						if d:IsA("BasePart") and d.Anchored then
							loose += 1
						end
					end
				end
				local complete = rig ~= nil and rig:FindFirstChild("Runtime") ~= nil and rig:FindFirstChild("Client") ~= nil
				local welded = rig ~= nil and rig:FindFirstChild("HumanoidRootPart") ~= nil and (rig :: any).HumanoidRootPart:FindFirstChild("BossRigRoot") ~= nil
				expect(
					id .. " boss rig " .. tostring(rigName) .. ": Runtime, Client, root weld, 18+ Motor6D, nothing anchored",
					complete and welded and motors >= 18 and loose == 0,
					("%d motors, %d anchored"):format(motors, loose)
				)
			end
			if kitModel then
				local kd = require(ReplicatedStorage:WaitForChild("CreatureKitData")) :: any
				local tris = kd[kitModel].tris
				expect(("%s triangles %d within %s budget %d (Blender report)"):format(id, tris, worker.rarity, KIT_TRIS[worker.rarity]), tris <= KIT_TRIS[worker.rarity])
				local meshes, bad = 0, 0
				for _, d in model:GetDescendants() do
					if d:IsA("MeshPart") and d:GetAttribute("KitSize") then
						meshes += 1
						if d.Size.Magnitude < 0.01 or d.Size.Magnitude > 60 then
							bad += 1
						end
					end
				end
				expect(id .. " kit meshes have studs-sized parts (import scale right)", meshes > 0 and bad == 0, ("%d meshes, %d odd"):format(meshes, bad))
			end
			local h = model:FindFirstChildOfClass("Humanoid")
			expect(
				id .. " keeps Humanoid + Animate + R15 names",
				h ~= nil and model:FindFirstChild("Animate") ~= nil and model:FindFirstChild("UpperTorso") ~= nil and model:FindFirstChild("RightHand") ~= nil
			)
			expect(id .. " tagged Creature", CollectionService:HasTag(model, "Creature"))
			for _, sig in (if kitModel then KIT_SIGNATURE[id] elseif model:GetAttribute("BossRigName") then BOSS_SIGNATURE[id] else SIGNATURE[id]) or {} do
				expect(id .. " has signature item " .. sig, model:FindFirstChild(sig, true) ~= nil)
			end
			if worker.rarity ~= "Common" and worker.rarity ~= "Rare" and not model:GetAttribute("BossRigName") then -- (a boss rig makes its aura on the client from its Vfx module)
				expect(
					id .. " (" .. worker.rarity .. ") has an aura or glow (Epic and up)",
					model:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil or model:FindFirstChildWhichIsA("PointLight", true) ~= nil
				)
			end
			if not model:GetAttribute("BossRigName") then -- (a boss rig animates through its own Driver on the client)
				local state = CreatureAnim.bind(model)
				expect(id .. " has an animated prop", #state.items >= 1, #state.items)
			end
		end
	end
	info("creatures with a spec", count)
end

local function sameFor(zoneName: string)
	local zone = ZoneArea.new(workspace.Zones[zoneName])
	local wanderers = waitUntil(90, function()
		local list = {}
		for _, npc in zone.npcFolder:GetChildren() do
			if npc:IsA("Model") and npc:GetAttribute("LookId") then
				table.insert(list, npc)
			end
		end
		return if #list >= 2 then list else nil
	end)
	expect(zoneName .. " wanderers spawn as their creature (LookId set)", wanderers ~= nil)
	if not wanderers then
		return
	end
	for _, npc in wanderers do
		local id = npc:GetAttribute("LookId")
		expect(("wanderer %s = its template (same parts + colours)"):format(id), signature(npc) == signature(models[id]))
		expect("wanderer shows no identity yet (rolled, not revealed)", npc:GetAttribute("WorkerUid") == nil)
		local root = npc:FindFirstChild("HumanoidRootPart")
		local prompt = root and root:FindFirstChild("StealPrompt")
		expect(
			"steal prompt names the creature + rarity",
			prompt ~= nil and (prompt :: any).ObjectText == npc:GetAttribute("PromptName") and npc:GetAttribute("PromptName") ~= nil,
			prompt and (prompt :: any).ObjectText
		)
	end

	-- catch one (real NPCClaim path: reserve -> spin -> reveal -> carry)
	local npc = wanderers[1]
	local id = npc:GetAttribute("LookId")
	local sigBefore = signature(npc)
	local root = A.Character.HumanoidRootPart :: BasePart
	local npcRoot = npc.HumanoidRootPart :: BasePart
	root.CFrame = npcRoot.CFrame * CFrame.new(0, 0, -3)
	local ok, msg = NPCClaim.tryReserve(A, npc, zone)
	expect("steal reserved", ok, msg)
	local carried = waitUntil(15, function()
		return npc:GetAttribute("ClaimPhase") == "Carrying" and npc:GetAttribute("WorkerUid") ~= nil
	end)
	expect("revealed + carried after the spin", carried ~= nil, npc:GetAttribute("ClaimPhase"))
	expect("reveal gave the rolled creature", npc:GetAttribute("WorkerId") == id, npc:GetAttribute("WorkerId"))
	expect("carried = same parts + colours", signature(npc) == sigBefore)
	task.wait(0.5)
	local want = math.min(models[id]:GetAttribute("CreatureScale") or 1, 1.3)
	expect("carried scale capped at 1.3", math.abs((npc:GetAttribute("CreatureScale") or 0) - want) < 0.01, npc:GetAttribute("CreatureScale"))

	local plot = PlotService.getPlot(A) :: Model
	local station = plot.Stations:FindFirstChildWhichIsA("BasePart")
	local target
	for _, s in plot.Stations:GetChildren() do
		if s:IsA("BasePart") and s:GetAttribute("Occupied") ~= true then
			target = s
			break
		end
	end
	root.CFrame = (target :: BasePart).CFrame * CFrame.new(0, 4, 0)
	task.wait(0.3)
	local placed, pmsg = NPCPlacement.tryPlace(A, target :: BasePart)
	expect("placed on a pad", placed, pmsg or station)
	task.wait(0.5)
	expect("pad = same parts + colours", signature(npc) == sigBefore)
	local padWant = math.min(models[id]:GetAttribute("CreatureScale") or 1, 1.6)
	expect("pad scale capped at 1.6", math.abs((npc:GetAttribute("CreatureScale") or 0) - padWant) < 0.01, npc:GetAttribute("CreatureScale"))
end

local function swapAll()
	-- the rebuild path (saved creature on a pad after rejoin) and the reveal swap: the call WorkerAppearance.apply makes
	for rid, spec in CreatureSpecs do
		if type(spec) == "table" then
			local m = ServerStorage.NPCModels.MysteryNPC:Clone()
			m.Parent = workspace
			m:PivotTo(CFrame.new(0, 600, 0))
			WorkerAppearance.apply(m, rid)
			expect(rid .. " reveal swap = template", signature(m) == signature(models[rid]))
			m:Destroy()
		end
	end
end

local function odds()
	for _, zone in { "MainStreet", "SunkenKingdom", "BillionaireHills" } do
		local count = {}
		for _ = 1, 10000 do
			local r = WorkerCatalogue.get(WorkerService.rollWorkerId(zone)).rarity
			count[r] = (count[r] or 0) + 1
		end
		local texts = {}
		for rarity, want in ODDS do
			local got = (count[rarity] or 0) / 100
			local tol = math.max(1.2, want * 0.6)
			table.insert(texts, ("%s %.2f%%"):format(rarity, got))
			expect(("SIM %s %s %.2f%% vs %.1f%%"):format(zone, rarity, got, want), math.abs(got - want) <= tol, nil, true)
		end
		info("SIM rolls " .. zone, table.concat(texts, ", "))
	end
end

local function partsBudget()
	local ids = {}
	for id, spec in CreatureSpecs do
		if type(spec) == "table" then
			table.insert(ids, id)
		end
	end
	local byRarity = {}
	for _, id in ids do
		local r = WorkerCatalogue.get(id).rarity
		byRarity[r] = byRarity[r] or {}
		table.insert(byRarity[r], id)
	end
	local function draw(): string
		local x, acc = math.random() * 100, 0
		for _, r in { "Common", "Rare", "Epic", "Legendary", "Secret" } do
			acc += ODDS[r]
			if x <= acc and byRarity[r] then
				return byRarity[r][math.random(#byRarity[r])]
			end
		end
		return byRarity.Common[math.random(#byRarity.Common)]
	end
	local before = 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			before += 1
		end
	end
	info("Workspace parts now", before)
	for _, pads in { 6, 14 } do
		local folder = Instance.new("Folder")
		folder.Name = "Sim035"
		folder.Parent = workspace
		local total, cr, crN = 0, 0, 0
		for i = 1, 12 * pads do
			local id = draw()
			local c = models[id]:Clone()
			c.Parent = folder
			c:PivotTo(CFrame.new(2000 + (i % 40) * 12, 300, (i // 40) * 12))
			local n = if c:GetAttribute("KitModel") then visibleParts(c) else parts(c)
			total += n
			local r = WorkerCatalogue.get(id).rarity
			if r == "Common" or r == "Rare" then
				cr += n
				crN += 1
			end
		end
		local after = 0
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") then
				after += 1
			end
		end
		local avg = if crN > 0 then cr / crN else 0
		info(
			("SIM 12 lots x %d pads"):format(pads),
			("creatures=%d creature parts=%d Workspace total=%d (+%d) Common/Rare avg=%.1f parts"):format(12 * pads, total, after, after - before, avg)
		)
		expect(("SIM Common/Rare on pads average <= 40 parts (%d pads)"):format(pads), avg <= 40, avg, true)
		folder:Destroy()
	end
end

local function capFor(zoneName: string, want: number)
	local zone = ZoneArea.new(workspace.Zones[zoneName])
	local root = A.Character.HumanoidRootPart :: BasePart
	local points = zone:getSpawnPoints()
	local home = points[math.ceil(#points / 2)].Position + Vector3.new(0, 4, 0)
	root.CFrame = CFrame.new(home)
	task.wait(1)
	local dists, maxSeen = {}, 0
	local conn = zone.npcFolder.ChildAdded:Connect(function(npc)
		task.wait(0.2)
		local r = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			table.insert(dists, (r.Position - root.Position).Magnitude)
		end
	end)
	local full = waitUntil(110, function()
		local n = #zone.npcFolder:GetChildren()
		maxSeen = math.max(maxSeen, n)
		return if n >= want then n else nil
	end)
	-- keep sampling for a while: the cap must hold while spawns and despawns continue
	local untilT = os.clock() + 15
	while os.clock() < untilT do
		maxSeen = math.max(maxSeen, #zone.npcFolder:GetChildren())
		task.wait(0.25)
	end
	conn:Disconnect()
	expect(("%s wanderers reach the cap %d with one player"):format(zoneName, want), full ~= nil, maxSeen)
	expect(("%s never above the cap %d"):format(zoneName, want), maxSeen <= want, maxSeen)
	local near = 0
	for _, d in dists do
		if d <= 125 then
			near += 1
		end
	end
	info(("%s spawned %d wanderers"):format(zoneName, #dists), ("%d within 125 studs of the player"):format(near))
	expect(zoneName .. " most wanderers spawn near the player", #dists == 0 or near / #dists >= 0.6, near .. "/" .. #dists, false)
	task.wait(2.5)
	local wrong, nearN, farN, n = 0, 0, 0, 0
	for _, npc in zone.npcFolder:GetChildren() do
		local r = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local d = (r.Position - root.Position).Magnitude
			local asleep = npc:GetAttribute("Dormant") == true
			if d <= 78 then
				nearN += 1
				wrong += if asleep then 1 else 0
			elseif d >= 83 then
				farN += 1
				wrong += if asleep then 0 else 1
			end
			n += parts(npc)
		end
	end
	info(zoneName .. " at the cap", ("%d wanderers, %d parts, %d within 80 studs (awake), %d farther (frozen)"):format(#zone.npcFolder:GetChildren(), n, nearN, farN))
	expect(zoneName .. " dormant only when no player within 80 studs", wrong == 0, wrong)
end

local errorsSeen = {}
local LogService = game:GetService("LogService")
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and (message:find("Creature") or message:find("ZoneSpawner") or message:find("WorkerReveal")) then
		table.insert(errorsSeen, message)
	end
end)

scenario("models", models_)
local ZoneProgress, CashService = mod("ZoneProgress"), mod("CashService")
CashService.add(A, 2000000)
for _, z in { "SunkenKingdom", "BillionaireHills" } do
	local ok, msg = ZoneProgress.purchase(A, z)
	info("unlock " .. z .. " (in-memory save)", tostring(ok) .. " " .. tostring(msg))
end
scenario("same MainStreet", function()
	sameFor("MainStreet")
end)
scenario("same SunkenKingdom", function()
	sameFor("SunkenKingdom")
end)
scenario("same BillionaireHills", function()
	sameFor("BillionaireHills")
end)
scenario("swap", swapAll)
scenario("odds", odds)
scenario("parts", partsBudget)
scenario("cap MainStreet", function()
	capFor("MainStreet", 10)
end)
scenario("cap SunkenKingdom", function()
	capFor("SunkenKingdom", 8)
end)
scenario("cap BillionaireHills", function()
	capFor("BillionaireHills", 8)
end)
section = "errors"
expect("no creature / spawner errors in the log", #errorsSeen == 0, table.concat(errorsSeen, " | "))
finish("DONE")
