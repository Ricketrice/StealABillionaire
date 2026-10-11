-- Studio location: ServerScriptService.DevTest_Hub026 (Script)
-- DevTest_Hub026  (Milestone 026) -- STUDIO-ONLY two-player test of the hub gameplay: arena, shops,
-- guide/tutorial, quests. It does nothing unless Studio started the session with StudioTestService
-- and the argument "hub026" (2 clients), so it is inert in normal Play and in live servers.
-- It drives real players on a local server through the same server functions the remotes call,
-- and through the real remotes where a client is involved. Results: "@@T026|" lines in the output.
-- Runs on the in-memory save only (Studio API access off). Lines marked SIM are simulations.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and type(args) == "string" and args:sub(1, 6) == "hub026") then
	return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s: %s | %s"):format(kind, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T026|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d (of which simulated checks=%d)"):format(state, passed, failed, simulated)
	print("@@T026|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end
if game:GetService("ServerStorage"):GetAttribute("StudioMemoryStore") ~= true and pcall(function()
	return game:GetService("DataStoreService"):GetDataStore("__sab_probe_026"):GetAsync("probe")
end) then -- (027: the StudioMemoryStore attribute puts PlayerData on the in-memory store even with API access on)
	finish("ABORTED: Studio API access is on; this test only runs on the in-memory save")
	return
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end
local CashService, PlayerData, PlotService, WorkerInventory = mod("CashService"), mod("PlayerData"), mod("PlotService"), mod("WorkerInventory")
local HubBase, HubArena, HubShops, HubQuests = mod("HubBase"), mod("HubArena"), mod("HubShops"), mod("HubQuests")
local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

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
local function waitUntil(seconds: number, check: () -> any): any
	local deadline = os.clock() + seconds
	repeat
		local value = check()
		if value then
			return value
		end
		task.wait(0.05)
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
	print("@@T026|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function ready(p: Player): boolean
	local character = p.Character
	return p.Parent ~= nil and PlayerData.isLoaded(p) and PlotService.getPlot(p) ~= nil and character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil and WorkerInventory.isReady(p)
end
local function hubOf(p: Player): any
	return (PlayerData.get(p) :: any).hub
end
local saved: { [number]: string } = {}
PlayerData.onSaved(function(p, ok, _at, json)
	if ok then
		saved[p.UserId] = json
	end
end)
-- A worker of `p` on their station `station`, or in storage if no station is given.
local function seed(p: Player, id: string, station: number?): string
	local uid = HttpService:GenerateGUID(false)
	assert(WorkerInventory.give(p, { uid = uid, id = id, zone = "MainStreet", level = 1, tier = "Normal", loc = if station then "station" else "inventory", station = station }), "seed: give failed")
	if station then
		assert(WorkerInventory.respawn(p, uid), "seed: respawn failed")
	end
	return uid
end
local function moveTo(p: Player, position: Vector3)
	(p.Character :: Model):PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)))
end
local venues = workspace:WaitForChild("Venues")
local function setFlags(on: boolean?)
	for _, attribute in HubConfig.STUDIO_ATTRIBUTES do
		ServerStorage:SetAttribute(attribute, on)
	end
	task.wait(0.4)
end

local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test026Bridge"
bridge.Parent = ReplicatedStorage
local probes: { [number]: any } = {}
local probeSeq = 0
bridge.OnServerEvent:Connect(function(_p, kind, id, state)
	if kind == "probe" and type(id) == "number" and type(state) == "table" then
		probes[id] = state
	end
end)
local function probe(p: Player): any
	probeSeq += 1
	local id = probeSeq
	bridge:FireClient(p, "probe", id)
	local state = waitUntil(4, function()
		return probes[id]
	end)
	probes[id] = nil
	return state or { answered = false, states = 0, npcs = 0, decor = 0 }
end
local function show(p: Player, what: string, id: string?) -- opens a screen on that client as a tap would
	HubBase.event(p, "TestOpen", { what = what, id = id })
	task.wait(0.5)
	return probe(p)
end

waitUntil(240, function()
	local count = 0
	for _, p in Players:GetPlayers() do
		if ready(p) then
			count += 1
		end
	end
	return count >= 2
end)
task.wait(2)
local everyone = {}
for _, p in Players:GetPlayers() do
	if ready(p) then
		table.insert(everyone, p)
	end
end
if #everyone < 2 then
	finish("ABORTED: needs 2 loaded players, got " .. #everyone)
	return
end
local A, B = everyone[1], everyone[2]
for _, p in everyone do
	local holder = Instance.new("ScreenGui")
	holder.Name = "Test026Helper"
	holder.ResetOnSpawn = false
	script:WaitForChild("ClientHelper"):Clone().Parent = holder
	holder.Parent = p:WaitForChild("PlayerGui")
end
task.wait(1)
for _, p in everyone do
	local answered = false
	for _ = 1, 3 do
		answered = answered or probe(p).answered
	end
	if not answered then
		bridge:Destroy()
		finish(("ABORTED: the test client of %s is not answering (stalled client): run this session again"):format(p.Name))
		return
	end
end

-- three workers: the weakest, and the strongest (far outside the 30% power range)
local weakest, strongest
for id, worker in WorkerCatalogue.WORKERS do
	local power = worker.attack + worker.speed + worker.defence
	if not weakest or power < weakest.power then
		weakest = { id = id, power = power, worker = worker }
	end
	if not strongest or power > strongest.power then
		strongest = { id = id, power = power, worker = worker }
	end
end
local leaverPads: Instance? = nil -- B's station pads (B leaves for real in the arena scenario)
local a1, b1, b2 = seed(A, weakest.id, 1), seed(B, weakest.id, 1), seed(B, strongest.id, nil) -- the strong one stays in storage: no income to blur the cash checks
local arena = venues:WaitForChild("Arena")
local pads = arena:WaitForChild("QueuePads")
local function scoreText(): string
	local label = venues.Arena.Scoreboard:FindFirstChild("Label", true) -- (027: the Battle Arena board in the plaza)
	return if label then label.Text else ""
end

scenario("flags off", function()
	expect("no flags published", ReplicatedStorage:GetAttribute("HubArena") == nil and ReplicatedStorage:GetAttribute("HubShops") == nil and ReplicatedStorage:GetAttribute("HubNpcQuests") == nil and ReplicatedStorage:GetAttribute("HubUpgrades") == nil)
	expect("nobody stands at the anchors", venues:FindFirstChild("People") == nil)
	moveTo(A, pads.Pad1.Position)
	expect("arena refuses", HubArena.join(A, a1) == false and #HubArena._test.queue == 0)
	expect("shops refuse", HubShops.buy(A, "skin:Neon") == false and HubShops.use(A, "skin:Neon") == false)
	HubQuests.progress(A, "steal", 1)
	expect("quests refuse", HubQuests.claim(A, "steal3") == false)
	expect("no hub data is created in the save", next(hubOf(A)) == nil and next(hubOf(B)) == nil, HttpService:JSONEncode(hubOf(A)))
	expect("scoreboard untouched", scoreText():find("coming soon") ~= nil, scoreText())
	expect("no lot decor, no trail colour", workspace.World.BillionaireCity:FindFirstChild("LotDecor") == nil and A:GetAttribute("BatTrail") == nil)
	expect("the client shows nothing", probe(A).open == nil and probe(A).speaker == nil)
end)

setFlags(true)
task.wait(1.5)

scenario("people and screens", function()
	local people = venues:FindFirstChild("People")
	expect("the guide, the quest board and three shopkeepers appear", people ~= nil and #people:GetChildren() == 5, people and #people:GetChildren())
	for _, id in { "Guide", "BatBoutique", "LotAndDecor", "UpgradeOffice" } do
		local holder = people and people:FindFirstChild(id)
		local body = holder and holder:FindFirstChild("Body")
		local anchor = if id == "Guide" then venues.NPCs.Guide else venues.Shops[id].KeeperSpot
		local root = body and body:FindFirstChild("HumanoidRootPart")
		local feet = if body then HubBase.feetY(body) else 0
		expect(id .. " stands on their anchor with a Talk prompt", body ~= nil and root ~= nil and holder:FindFirstChild("TalkPrompt", true) ~= nil and ((root.Position - anchor.Position) * Vector3.new(1, 0, 1)).Magnitude < 1.5 and math.abs(feet - (anchor.Position.Y - anchor.Size.Y / 2)) < 0.2, ("feet %.2f, floor %.2f"):format(feet, anchor.Position.Y - anchor.Size.Y / 2))
	end
	local seen = probe(A)
	expect("the client got its hub state and sees the people", seen.states >= 1 and seen.npcs == 5, ("states %s npcs %s"):format(tostring(seen.states), tostring(seen.npcs)))
	expect("a new player is offered the tutorial by the guide", seen.speaker == HubConfig.NPCs.Guide.name, seen.speaker)
	seen = show(A, "npc", "BatBoutique")
	expect("talking to a shopkeeper opens their speech bubble", seen.speaker == HubConfig.NPCs.BatBoutique.name and type(seen.line) == "string", seen.speaker)
	seen = show(A, "shop", "BatBoutique")
	expect("the shop screen opens", seen.open == "BatBoutique", seen.open)
	seen = show(A, "quests")
	expect("the quest board screen opens", seen.open == "Quests", seen.open)
	seen = show(A, "npc", "Guide")
	expect("talking to the guide opens her speech bubble", seen.speaker == HubConfig.NPCs.Guide.name, seen.speaker)
end)

scenario("tutorial", function()
	expect("not done yet", hubOf(A).tutorial ~= true)
	local seen = show(A, "tutorial")
	expect("the tutorial tracker starts at step 1", seen.tutorial == 1, seen.tutorial)
	seen = show(A, "next")
	expect("next moves to step 2", seen.tutorial == 2, seen.tutorial)
	show(A, "finish")
	expect("finishing (or skipping) is remembered by the server", waitUntil(3, function()
		return hubOf(A).tutorial == true
	end))
	PlayerData.save(A)
	task.wait(0.4)
	expect("and saved", saved[A.UserId] ~= nil and saved[A.UserId]:find('"tutorial":true', 1, true) ~= nil)
	expect("the other player's is untouched", hubOf(B).tutorial ~= true)
end)

scenario("quests", function()
	local quests = HubQuests.today(A)
	expect("three quests for today", quests ~= nil and #quests.ids == 3 and quests.day == HubQuests.day(), quests and #quests.ids)
	expect("the PvP quest is not offered while PvP is off", table.find(quests.ids, "defend1") == nil)
	quests.ids, quests.progress, quests.claimed = { "steal3", "earn5k", "arena1" }, {}, {} -- a known set for the checks below
	local cash = CashService.get(A)
	HubQuests.progress(A, "steal", 1)
	HubQuests.progress(A, "steal", 1)
	expect("progress counts", quests.progress.steal3 == 2)
	expect("an unfinished quest can't be claimed", HubQuests.claim(A, "steal3") == false)
	HubQuests.progress(A, "steal", 5)
	expect("progress stops at the goal", quests.progress.steal3 == 3)
	expect("a quest that isn't today's can't be claimed", HubQuests.claim(A, "place2") == false and HubQuests.claim(A, { "steal3" }) == false)
	local before = CashService.get(A)
	expect("the reward is paid", HubQuests.claim(A, "steal3") == true and CashService.get(A) - before >= 1500 and CashService.get(A) - before < 1500 + 200, CashService.get(A) - before)
	expect("only once", HubQuests.claim(A, "steal3") == false)
	task.wait(0.3)
	expect("a quest reward doesn't count as collected cash", (quests.progress.earn5k or 0) < 400, quests.progress.earn5k)
	CashService.add(A, 6000)
	task.wait(0.3)
	expect("cash coming in counts towards 'collect' quests", quests.progress.earn5k == 5000, quests.progress.earn5k)
	-- a street steal, as the server sees it: a worker reserved for the player appears in ClaimedNPCs
	quests.ids, quests.progress, quests.claimed = { "steal3", "rare1", "arena1" }, {}, {}
	local npc = Instance.new("Model")
	npc:SetAttribute("ClaimedBy", A.UserId)
	npc:SetAttribute("ClaimPhase", "Spinning")
	npc:SetAttribute("Rarity", "Rare")
	npc.Parent = workspace:WaitForChild("ClaimedNPCs")
	task.wait(0.3)
	expect("a steal counts, and a rare one counts for the rare quest", quests.progress.steal3 == 1 and quests.progress.rare1 == 1, HttpService:JSONEncode(quests.progress), true)
	npc:SetAttribute("StolenFrom", 1)
	npc.Parent = nil
	npc.Parent = workspace.ClaimedNPCs
	task.wait(0.3)
	expect("a worker stolen from a player doesn't count as a street steal", quests.progress.steal3 == 1, quests.progress.steal3, true)
	npc:Destroy()
	local seen = show(A, "quests")
	expect("the board is on the player's screen", seen.open == "Quests")
	bridge:FireClient(A, "hub", "QuestClaim", "rare1") -- through the real remote
	expect("claiming through the remote pays", waitUntil(3, function()
		return quests.claimed.rare1 == true
	end))
	-- daily reset
	local day = quests.day
	ServerStorage:SetAttribute("StudioHubDayShift", 1)
	local tomorrow = HubQuests.today(A)
	expect("the next day brings a fresh set with no progress", tomorrow.day == day + 1 and #tomorrow.ids == 3 and next(tomorrow.progress) == nil and next(tomorrow.claimed) == nil, nil, true)
	ServerStorage:SetAttribute("StudioHubDayShift", nil)
	expect("cash only went up by the rewards and the test's own grant", CashService.get(A) - cash >= 1500 + 2500 + 6000)
end)

scenario("shops", function()
	CashService.add(A, 800000)
	task.wait(0.2)
	local shops = venues.Shops
	local cash = CashService.get(A)
	moveTo(A, venues.NPCs.Guide.Position)
	local away = (A.Character :: Model):GetPivot().Position
	if (away - shops.BatBoutique.Counter.Position).Magnitude <= HubConfig.SHOP_REACH then
		moveTo(A, arena.PlatformA.Position)
	end
	local ok, message = HubShops.buy(A, "skin:Neon")
	expect("buying from far away is refused", ok == false and CashService.get(A) == cash, message)
	moveTo(A, shops.BatBoutique.Display.Position)
	ok, message = HubShops.buy(A, "skin:Neon")
	expect("Bat Boutique: Neon bat bought, cash taken", ok and hubOf(A).owned["skin:Neon"] == true and CashService.get(A) == cash - 15000, message)
	expect("can't buy it twice", HubShops.buy(A, "skin:Neon") == false and CashService.get(A) == cash - 15000)
	expect("unknown items are refused", HubShops.buy(A, "skin:Diamond") == false and HubShops.buy(A, { "skin:Neon" }) == false and HubShops.buy(A, 12) == false)
	moveTo(B, shops.BatBoutique.Display.Position + Vector3.new(3, 0, 0))
	if CashService.get(B) > 100 then
		CashService.trySpend(B, CashService.get(B) - 100) -- leave B with $100
	end
	local poor = CashService.get(B)
	expect("not enough cash: refused, nothing taken", HubShops.buy(B, "skin:Golden") == false and CashService.get(B) >= poor and (hubOf(B).owned == nil or hubOf(B).owned["skin:Golden"] == nil), poor)
	expect("can't use what isn't owned", HubShops.use(A, "skin:Golden") == false and HubShops.use(A, "trail:Mint") == false)
	ok = HubShops.buy(A, "trail:Sunset")
	expect("a trail colour is bought and put on", ok and HubShops.use(A, "trail:Sunset") == true and A:GetAttribute("BatTrail") == "255,140,60", A:GetAttribute("BatTrail"))
	-- the 022 locker now only hands out owned looks (through the real PvP remote)
	ServerStorage:SetAttribute("StudioWeaponCombat", true)
	task.wait(2.6) -- the locker wrapper is installed 2 s after the server starts; flags settle
	bridge:FireClient(A, "pvp", "Loadout", "skin", "Golden")
	task.wait(0.8)
	expect("the locker refuses a bat look that isn't owned", A:GetAttribute("BatSkin") ~= "Golden", A:GetAttribute("BatSkin"))
	bridge:FireClient(A, "pvp", "Loadout", "skin", "Neon")
	expect("and gives the one that is", waitUntil(3, function()
		return A:GetAttribute("BatSkin") == "Neon"
	end), A:GetAttribute("BatSkin"))
	task.wait(0.7)
	local shown = probe(A).locker
	if shown then
		expect("the locker screen offers only the bat looks they own", shown == "Neon,Starter", shown)
	else
		note("SKIPPED", "locker screen not checked", "the client has no locker screen")
	end
	ServerStorage:SetAttribute("StudioWeaponCombat", nil)

	-- Lot & Decor
	moveTo(A, shops.LotAndDecor.Display.Position)
	cash = CashService.get(A)
	expect("Lot & Decor: statue and planter bought", HubShops.buy(A, "decor:statue") and HubShops.buy(A, "decor:planter") and CashService.get(A) == cash - 40000 - 2000)
	expect("placed on decor spot 1", HubShops.use(A, "decor:statue", 1) == true and hubOf(A).decor["1"] == "decor:statue")
	local plot = PlotService.getPlot(A) :: Model
	local decor = workspace.World.BillionaireCity:FindFirstChild("LotDecor")
	local mine = decor and decor:FindFirstChild(plot.Name)
	local spot1 = mine and mine:FindFirstChild("Spot1")
	expect("the statue stands on the player's own lot", spot1 ~= nil and spot1:GetAttribute("Decor") == "decor:statue")
	local clear = true
	if spot1 then
		local floor = plot.PrimaryPart :: BasePart
		local at = floor.CFrame:PointToObjectSpace((spot1:GetBoundingBox()).Position)
		clear = math.abs(at.X) < 18 and math.abs(at.Z) < 18
		for _, station in plot.Stations:GetChildren() do
			if ((station.Position - (spot1:GetBoundingBox()).Position) * Vector3.new(1, 0, 1)).Magnitude < 5 then
				clear = false
			end
		end
	end
	expect("inside the fence and clear of all six pads", clear)
	expect("invalid spots and unowned decor are refused", HubShops.use(A, "decor:statue", 9) == false and HubShops.use(A, "decor:statue", 1.5) == false and HubShops.use(A, "decor:fountain", 2) == false)
	expect("moving it to another spot leaves one statue", HubShops.use(A, "decor:statue", 3) == true and hubOf(A).decor["1"] == nil and hubOf(A).decor["3"] == "decor:statue")
	HubShops.use(A, "decor:planter", 1)
	mine = workspace.World.BillionaireCity.LotDecor:FindFirstChild(plot.Name)
	expect("two decorations stand on the lot", mine ~= nil and #mine:GetChildren() == 2, mine and #mine:GetChildren())
	task.wait(0.6)
	expect("and the owner's client sees them", probe(A).decor == 2, probe(A).decor)
	expect("nothing appears on the other player's lot", workspace.World.BillionaireCity.LotDecor:FindFirstChild((PlotService.getPlot(B) :: Model).Name) == nil or #workspace.World.BillionaireCity.LotDecor[(PlotService.getPlot(B) :: Model).Name]:GetChildren() == 0)

	-- Upgrade Office (its own flag)
	moveTo(A, shops.UpgradeOffice.Display.Position)
	cash = CashService.get(A)
	expect("Upgrade Office: storage level 1 bought", HubShops.buy(A, "upgrade:storage") == true and hubOf(A).upgrades.storage == 1 and CashService.get(A) == cash - 25000)
	task.wait(0.6)
	expect("storage shows 5 more slots on the client", probe(A).slots == 25, probe(A).slots)
	expect("training needs one of your own workers", HubShops.buy(A, "upgrade:training") == false and HubShops.buy(A, "upgrade:training", b1) == false)
	expect("training bought for a worker", HubShops.buy(A, "upgrade:training", a1) == true and hubOf(A).upgrades.training[a1] == 1)
	local trained = HubArena.statsOf(A, a1)
	local w = weakest.worker
	local expected = math.floor(w.attack * 1.1 + 0.5) + math.floor(w.speed * 1.1 + 0.5) + math.floor(w.defence * 1.1 + 0.5)
	expect("training raises that worker's battle power by 10%", trained ~= nil and trained.power == expected and expected > weakest.power, trained and trained.power)
	-- extra stations
	local pads = plot:FindFirstChild("Stations") :: Instance
	local padsB = (PlotService.getPlot(B) :: Model):FindFirstChild("Stations") :: Instance
	leaverPads = padsB
	CashService.add(A, 1000000)
	task.wait(0.2)
	cash = CashService.get(A)
	expect("the lot starts with its six pads", #pads:GetChildren() == 6, #pads:GetChildren())
	expect("Upgrade Office: a seventh station bought", HubShops.buy(A, "upgrade:stations") == true and hubOf(A).upgrades.stations == 1 and CashService.get(A) == cash - 150000)
	local pad1, pad7 = nil, pads:FindFirstChild("Station7") :: any
	local nearest = math.huge
	for _, other in pads:GetChildren() do
		if other:GetAttribute("StationIndex") == 1 then
			pad1 = other
		end
		if pad7 and other ~= pad7 then
			nearest = math.min(nearest, (((other :: BasePart).Position - pad7.Position) * Vector3.new(1, 0, 1)).Magnitude)
		end
	end
	local floor = plot.PrimaryPart :: BasePart
	local onLot = pad7 and floor.CFrame:PointToObjectSpace(pad7.Position)
	expect("its pad is on the lot, clear of the other pads, with its ring and a Place prompt", pad7 ~= nil and pad1 ~= nil and pad7:GetAttribute("StationIndex") == 7 and pad7:GetAttribute("Occupied") == false and pad7:FindFirstChild("PlacePrompt") ~= nil and pad7:FindFirstChild("Ring") ~= nil and nearest >= 6.5 and math.abs(onLot.X) < 14 and math.abs(onLot.Z) < 14 and math.abs(pad7.Position.Y - pad1.Position.Y) < 0.01 and math.abs((pad7.Ring.Position - pad7.Position).Magnitude - (pad1.Ring.Position - pad1.Position).Magnitude) < 0.01, nearest)
	expect("the other player's lot is untouched", #padsB:GetChildren() == 6, #padsB:GetChildren())
	task.wait(0.6)
	expect("the owner's client shows 7 stations", probe(A).stations == 7, probe(A).stations)
	local incomeBefore = A:GetAttribute("Income") or 0
	local a7 = seed(A, weakest.id, 7)
	task.wait(0.4)
	expect("a worker on the new station earns like any other", pad7 ~= nil and pad7:GetAttribute("Occupied") == true and (A:GetAttribute("Income") or 0) > incomeBefore, ("%s -> %s"):format(tostring(incomeBefore), tostring(A:GetAttribute("Income"))))
	expect("an eighth station is bought; a ninth is refused", HubShops.buy(A, "upgrade:stations") == true and pads:FindFirstChild("Station8") ~= nil and HubShops.buy(A, "upgrade:stations") == false and #pads:GetChildren() == 8 and CashService.get(A) >= cash - 900000, #pads:GetChildren())
	ServerStorage:SetAttribute("StudioUpgrades", nil)
	task.wait(0.6)
	expect("with the upgrades flag off: the extra pads go and their worker is safe in storage", #pads:GetChildren() == 6 and WorkerInventory.getRecord(A, a7) ~= nil and WorkerInventory.getRecord(A, a7).loc == "inventory" and probe(A).stations == 6 and (A:GetAttribute("Income") or 0) == incomeBefore, #pads:GetChildren())
	expect("with the upgrades flag off: no purchases, no bonus slots, no training bonus", HubShops.buy(A, "upgrade:storage") == false and probe(A).slots == 20 and (HubArena.statsOf(A, a1) :: any).power == weakest.power, probe(A).slots)
	expect("and Mr. Ledger goes home", venues.People:FindFirstChild("UpgradeOffice") == nil)

	-- saved, and still there after the data is unloaded and loaded again
	PlayerData.save(A)
	task.wait(0.5)
	local json = saved[A.UserId] or ""
	expect("the save holds the purchases (schema 3)", json:find('"schema":3', 1, true) ~= nil and json:find("skin:Neon", 1, true) ~= nil and json:find("decor:statue", 1, true) ~= nil and json:find("trail:Sunset", 1, true) ~= nil)
	local trophies, owned, cashNow = hubOf(A).trophies, HttpService:JSONEncode(hubOf(A).owned), CashService.get(A)
	PlayerData._test.leave(A)
	expect("data unloaded", not PlayerData.isLoaded(A), nil, true)
	PlayerData._test.load(A)
	expect("data loaded again", waitUntil(6, function()
		return PlayerData.isLoaded(A) and WorkerInventory.isReady(A)
	end), nil, true)
	task.wait(1.5)
	local again = hubOf(A)
	expect("rejoin: purchases, trophies, tutorial and cash are all back", HubBase.data(A) ~= nil and HttpService:JSONEncode(again.owned) == owned and again.trophies == trophies and again.tutorial == true and math.abs(CashService.get(A) - cashNow) < 600, ("%s / %s"):format(HttpService:JSONEncode(again.owned), tostring(CashService.get(A) - cashNow)), true)
	expect("rejoin: decorations and trail colour are put back", waitUntil(4, function()
		local folder = workspace.World.BillionaireCity.LotDecor:FindFirstChild(plot.Name)
		return folder ~= nil and #folder:GetChildren() == 2 and A:GetAttribute("BatTrail") == "255,140,60"
	end), nil, true)
	-- (the player never left, so their model is still on the station and the reload puts the record
	-- in storage beside it; a real rejoin starts from an empty lot)
	local back = waitUntil(4, function()
		return WorkerInventory.getRecord(A, a1)
	end)
	expect("rejoin: the worker is still theirs", back ~= nil and (back.loc == "station" or back.loc == "inventory"), back and back.loc, true)
	-- an old (schema 2) save and a tampered hub field
	local old = PlayerData._sanitize(PlayerData._migrate({ schema = 2, cash = 5, workers = {}, zones = {} }))
	expect("a schema 2 save loads as schema 3 with an empty hub", old.schema == 3 and type(old.hub) == "table" and next(old.hub) == nil and old.cash == 5, nil, true)
	local dirty = PlayerData._sanitize(PlayerData._migrate({ schema = 3, cash = 1, workers = {}, zones = {}, hub = { trophies = 2, owned = { ["skin:Neon"] = true }, junk = string.rep("x", 500), deep = { a = { b = { c = { d = { e = 1 } } } } }, nan = 0 / 0 } }))
	expect("a damaged hub field is cleaned, keeping what is valid", dirty.hub.trophies == 2 and dirty.hub.owned["skin:Neon"] == true and dirty.hub.junk == nil and dirty.hub.nan == nil and dirty.hub.deep.a.b.c == nil, HttpService:JSONEncode(dirty.hub), true)

	-- extra stations after a rejoin (simulated: data unloaded, the pad and its worker taken off the
	-- lot as a real leave does, data loaded again). B gets a seeded station for the real leave below.
	HubBase.data(B).upgrades.stations = 1
	ServerStorage:SetAttribute("StudioUpgrades", true)
	task.wait(0.6)
	expect("upgrades back on: both extra pads return, and B's seeded one appears", #pads:GetChildren() == 8 and #padsB:GetChildren() == 7, ("%d / %d"):format(#pads:GetChildren(), #padsB:GetChildren()))
	WorkerInventory.take(A, a7)
	a7 = seed(A, weakest.id, 7)
	PlayerData.save(A)
	task.wait(0.5)
	expect("the save holds the worker on station 7", (saved[A.UserId] or ""):find('"station":7', 1, true) ~= nil)
	PlayerData._test.leave(A)
	for _, npc in (plot:FindFirstChild("PlacedNPCs") :: Instance):GetChildren() do
		if npc:GetAttribute("StationIndex") == 7 then
			npc:Destroy()
		end
	end
	for _, pad in pads:GetChildren() do
		if pad:GetAttribute("HubExtra") == true then
			pad:Destroy()
		end
	end
	task.wait(0.2)
	PlayerData._test.load(A)
	waitUntil(6, function()
		return PlayerData.isLoaded(A) and WorkerInventory.isReady(A)
	end)
	task.wait(1.5)
	local record7 = WorkerInventory.getRecord(A, a7)
	local rebuilt = pads:FindFirstChild("Station7")
	expect("rejoin: the pads are rebuilt and the worker is back on station 7", #pads:GetChildren() == 8 and rebuilt ~= nil and rebuilt:FindFirstChild("PlacePrompt") ~= nil and rebuilt:GetAttribute("Occupied") == true and record7 ~= nil and record7.loc == "station" and record7.station == 7, record7 and ("%s %s"):format(record7.loc, tostring(record7.station)), true)
	ServerStorage:SetAttribute("StudioUpgrades", nil)
	task.wait(0.6)
	record7 = WorkerInventory.getRecord(A, a7)
	expect("upgrades off again: six pads, the worker kept in storage", #pads:GetChildren() == 6 and record7 ~= nil and record7.loc == "inventory", record7 and record7.loc)
end)

scenario("arena", function()
	local CFG = HubConfig.Arena
	ServerStorage:SetAttribute("StudioUpgrades", true)
	task.wait(0.3)
	hubOf(A).upgrades.training = {} -- equal workers again for the fights below
	for _, p in everyone do
		local quests = HubQuests.today(p)
		quests.ids, quests.progress, quests.claimed = { "arena1", "steal3", "earn5k" }, {}, {}
	end
	expect("starts idle", HubArena._test.fight() == nil and #HubArena._test.queue == 0)
	moveTo(A, venues.NPCs.Guide.Position)
	local ok, message = HubArena.join(A, a1)
	expect("can't queue away from the pads", ok == false and tostring(message):find("pad") ~= nil, message)
	moveTo(A, pads.Pad1.Position)
	moveTo(B, pads.Pad3.Position)
	task.wait(0.3)
	expect("can't offer someone else's worker or nonsense", HubArena.join(A, b1) == false and HubArena.join(A, "nope") == false and HubArena.join(A, {}) == false)
	ok, message = HubArena.join(A, a1)
	expect("queued with a worker from a station", ok and #HubArena._test.queue == 1, message)
	expect("can't queue twice", HubArena.join(A, a1) == false and #HubArena._test.queue == 1)
	expect("the weakest and the strongest worker are out of range", not HubArena.inRange(weakest.power, strongest.power), ("%d vs %d"):format(weakest.power, strongest.power))
	expect("in range within 30%", HubArena.inRange(100, 71) and not HubArena.inRange(100, 69) and HubArena.inRange(70, 100))
	ok = HubArena.join(B, b2)
	task.wait(1.4)
	expect("power-range block: both wait, no fight starts", ok and HubArena._test.fight() == nil and #HubArena._test.queue == 2)
	HubArena.leave(B)
	expect("leaving the queue", #HubArena._test.queue == 1)
	-- the fight
	CFG.HIT_INTERVAL, CFG.INTRO_TIME, CFG.OUTRO_TIME = 0.05, 0.3, 1.5
	local cashA, cashB, trophiesA, trophiesB = CashService.get(A), CashService.get(B), HubBase.data(A).trophies, HubBase.data(B).trophies
	local locA = (WorkerInventory.getRecord(A, a1) :: any).loc
	bridge:FireClient(B, "hub", "ArenaJoin", b1) -- through the real remote
	expect("two workers of equal power are matched", waitUntil(4, function()
		return HubArena._test.fight() ~= nil
	end))
	local fighters = arena:FindFirstChild("Fighters")
	expect("both stand-in workers are on the platforms", fighters ~= nil and #fighters:GetChildren() == 2 and waitUntil(1, function()
		return scoreText():find(weakest.worker.name, 1, true) ~= nil
	end), scoreText())
	local onPlatforms = true
	for _, model in (fighters and fighters:GetChildren() or {}) do
		local at = (model:GetBoundingBox()).Position
		local near = math.min(((at - arena.PlatformA.Position) * Vector3.new(1, 0, 1)).Magnitude, ((at - arena.PlatformB.Position) * Vector3.new(1, 0, 1)).Magnitude)
		onPlatforms = onPlatforms and near < 2 and model:FindFirstChild("ArenaTag", true) ~= nil
	end
	expect("each on its platform with a name and health bar", onPlatforms)
	expect("the fight ends", waitUntil(12, function()
		return HubArena._test.fight() == nil
	end))
	task.wait(0.4)
	local wonA = HubBase.data(A).trophies - trophiesA
	local wonB = HubBase.data(B).trophies - trophiesB
	local winner, loser = if wonA == 1 then A else B, if wonA == 1 then B else A
	local reward = math.max(CFG.REWARD_MIN, weakest.worker.income * CFG.REWARD_INCOME_SECONDS)
	expect("exactly one winner gets one trophy point", wonA + wonB == 1, ("%d / %d"):format(wonA, wonB))
	local gain = CashService.get(winner) - (if winner == A then cashA else cashB)
	local loss = CashService.get(loser) - (if loser == A then cashA else cashB)
	expect("the winner is paid the reward", gain >= reward and gain < reward + 400, gain)
	expect("the loser is paid nothing and loses nothing", loss >= 0 and loss < 400, loss)
	expect("both still own their workers, exactly where they were", WorkerInventory.getRecord(A, a1) ~= nil and WorkerInventory.getRecord(A, a1).loc == locA and WorkerInventory.getRecord(B, b1) ~= nil and WorkerInventory.getRecord(B, b1).loc == "station", ("%s / %s"):format(tostring(WorkerInventory.getRecord(A, a1) and WorkerInventory.getRecord(A, a1).loc), locA))
	expect("the win counts for the winner's arena quest only", HubQuests.today(winner).progress.arena1 == 1 and HubQuests.today(loser).progress.arena1 == nil)
	expect("the scoreboard shows the winner; the platforms are cleared", scoreText():find("WINNER", 1, true) ~= nil and waitUntil(3, function()
		return arena:FindFirstChild("Fighters") == nil
	end), scoreText())
	local hits = math.ceil(CFG.HP_FACTOR * (weakest.worker.attack + weakest.worker.defence) / math.max(1, math.floor(weakest.worker.attack - weakest.worker.defence * CFG.DEFENCE_FACTOR))) * 2 - 1
	expect("at the real pace this fight takes 10-20 s (worked out from the numbers)", hits * 0.55 + 2 >= 10 and hits * 0.55 + 2 <= 20, hits * 0.55 + 2, true)
	ok, message = HubArena.join(A, a1)
	expect("cooldown before the next battle", ok == false and tostring(message):find("resting") ~= nil, message)
	-- a rematch straight away pays nothing to the same winner
	HubArena._test.cooldowns[A.UserId], HubArena._test.cooldowns[B.UserId] = nil, nil
	local paidBefore = HubArena.stats.paid
	trophiesA, trophiesB = HubBase.data(A).trophies, HubBase.data(B).trophies
	HubArena.join(A, a1)
	HubArena.join(B, b1)
	waitUntil(4, function()
		return HubArena._test.fight() ~= nil
	end)
	waitUntil(12, function()
		return HubArena._test.fight() == nil
	end)
	task.wait(0.3)
	local again = if HubBase.data(A).trophies + HubBase.data(B).trophies > trophiesA + trophiesB then "paid" else "unpaid"
	local sameWinner = (HubBase.data(winner).trophies == (if winner == A then trophiesA else trophiesB)) and again == "unpaid"
	expect("beating the same player again straight away pays no second reward", (again == "unpaid") == (HubArena.stats.paid == paidBefore) and (sameWinner or again == "paid"), again)
	-- leaving mid-fight
	HubArena._test.cooldowns[A.UserId], HubArena._test.cooldowns[B.UserId] = nil, nil
	for key in HubArena._test.paidPairs do
		HubArena._test.paidPairs[key] = nil
	end
	CFG.HIT_INTERVAL, CFG.INTRO_TIME = 1, 1
	cashA, trophiesA = CashService.get(A), HubBase.data(A).trophies
	HubArena.join(A, a1)
	HubArena.join(B, b1)
	expect("third fight starts", waitUntil(4, function()
		return HubArena._test.fight() ~= nil
	end))
	task.wait(0.5)
	local leaverId = B.UserId
	B:Kick("test: leaves mid-fight")
	expect("leaving mid-fight ends it at once: the other player wins", waitUntil(4, function()
		return HubArena._test.fight() == nil
	end) and HubBase.data(A).trophies == trophiesA + 1 and CashService.get(A) - cashA >= reward)
	task.wait(1.5)
	expect("the leaver's extra pad is taken off their lot", leaverPads ~= nil and #leaverPads:GetChildren() == 6, leaverPads and #leaverPads:GetChildren())
	expect("the leaver's save has no reward and keeps their workers", saved[leaverId] ~= nil and saved[leaverId]:find(b1, 1, true) ~= nil and saved[leaverId]:find(b2, 1, true) ~= nil)
	expect("the platforms are cleared", waitUntil(5, function()
		return arena:FindFirstChild("Fighters") == nil
	end))
	CFG.HIT_INTERVAL, CFG.INTRO_TIME, CFG.OUTRO_TIME = 0.55, 2, 3
end)

section = "end"
setFlags(nil)
task.wait(0.6)
expect("flags back off: the people leave, decor and trail colours go, the scoreboard resets", (venues:FindFirstChild("People") == nil or #venues.People:GetChildren() == 0) and A:GetAttribute("BatTrail") == nil and scoreText():find("coming soon") ~= nil and ReplicatedStorage:GetAttribute("HubArena") == nil, scoreText())
local decorLeft = workspace.World.BillionaireCity:FindFirstChild("LotDecor")
expect("flags back off: no decorations stand on any lot", decorLeft == nil or #decorLeft:GetDescendants() == 0, decorLeft and #decorLeft:GetDescendants())
local extraPads = 0
for _, lot in workspace.Hub.Plots:GetChildren() do
	extraPads += #lot.Stations:GetChildren() - 6
end
expect("flags back off: every lot has exactly its six pads", extraPads == 0, extraPads)
bridge:Destroy()
finish("DONE")
