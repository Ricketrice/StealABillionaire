-- Studio location: ServerScriptService.DevTest_Save027 (Script)
-- DevTest_Save027  (Milestone 027) -- STUDIO-ONLY real-save test, on the REAL Studio DataStore
-- (Studio API access on). Inert unless StudioTestService started the session with "save027:a" or
-- "save027:b" (2 clients each). Test players only (UserIds -1 / -2, keys player_-1 ...), never a real
-- account. Results: "@@T027|" lines.
--   Before A (Edit mode): write a schema-2 save for -1 and -2 (see docs/SCRIPT_MAP.md, "Real-save test"),
--     and set ServerStorage attributes: hub flags on, StudioPvPStealing on, StudioPvPProtection false.
--   A  migration 2 -> 3, shop purchases incl. two extra stations, a real arena fight (trophies),
--      tutorial done, workers on stations 7 and 8, a PvP steal delivered. Both players then leave:
--      their final saves go to the real store, and what B must find is written to SAB_Test027/expect.
--   B  (StudioUpgrades OFF) a real rejoin in a new server: everything above is back, the station 7/8
--      workers are in storage and their pads are gone. Then it deletes every test key.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and type(args) == "string" and args:sub(1, 7) == "save027") then
	return
end
local phase = args:sub(9, 9)

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed = {}, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s %s: %s | %s"):format(kind, phase, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T027|" .. line)
end
local function finish(state: string)
	local summary = ("%s phase=%s passed=%d failed=%d"):format(state, phase, passed, failed)
	print("@@T027|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end
local function expect(name: string, condition: any, detail: any?)
	if condition then
		passed += 1
	else
		failed += 1
		note("FAIL", name, detail)
	end
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
	print("@@T027|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end

local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end
local PlayerData, PlotService, WorkerInventory, CashService = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory"), mod("CashService")
local HubBase, HubArena, HubShops = mod("HubBase"), mod("HubArena"), mod("HubShops")
local PvPSteal, PvPTransfer = mod("PvPSteal"), mod("PvPTransfer")
local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig")) :: any
local testStore = DataStoreService:GetDataStore("SAB_Test027")

if not PlayerData.isPersistent() and not waitUntil(20, function()
	return PlayerData.isPersistent()
end) then
	finish("ABORTED: Studio API access is off; this test needs the real Studio DataStore")
	return
end

local function ready(p: Player): boolean
	local c = p.Character
	return p.Parent ~= nil and PlayerData.isLoaded(p) and PlotService.getPlot(p) ~= nil and c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil and WorkerInventory.isReady(p)
end
waitUntil(240, function()
	local n = 0
	for _, p in Players:GetPlayers() do
		if ready(p) then
			n += 1
		end
	end
	return n >= 2
end)
task.wait(2)
local A, B = Players:GetPlayerByUserId(-1), Players:GetPlayerByUserId(-2)
if not (A and B and ready(A) and ready(B)) then
	finish("ABORTED: needs the loaded test players -1 and -2")
	return
end

local function record(p: Player, uid: string): any
	for _, w in (PlayerData.get(p) :: any).workers do
		if w.uid == uid then
			return w
		end
	end
	return nil
end
local function placed(p: Player, uid: string): Model?
	for _, m in PlotService.getPlot(p).PlacedNPCs:GetChildren() do
		if m:GetAttribute("WorkerUid") == uid then
			return m
		end
	end
	return nil
end
local function moveTo(p: Player, position: Vector3)
	(p.Character :: Model):PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)))
	task.wait(0.2)
end
local function pad(p: Player, index: number): Instance?
	return PlotService.getPlot(p).Stations:FindFirstChild("Station" .. index)
end
local function rawSchema(userId: number): any
	local record = PlayerData.store():GetAsync("player_" .. userId)
	return record and record.data and record.data.schema
end
local finalSaves: { [number]: string } = {}
PlayerData.onSaved(function(p, ok, _at, json)
	if ok then
		finalSaves[p.UserId] = json
	end
end)
local venues = workspace:WaitForChild("Venues")

if phase == "a" then
	scenario("migration 2 -> 3", function()
		expect("store still holds the schema-2 save of -1 (pre-seeded)", rawSchema(-1) == 2, rawSchema(-1))
		for _, p in { A, B } do
			local data = PlayerData.get(p) :: any
			expect(p.Name .. " loads as schema 3 with an empty hub field", data.schema == 3 and type(data.hub) == "table", HttpService:JSONEncode(data.hub))
		end
		expect("the seeded workers came through", record(A, "t027-a1") and record(A, "t027-a2") and record(B, "t027-b2"))
		expect("a save writes schema 3", PlayerData.save(A) and rawSchema(-1) == 3, rawSchema(-1))
	end)

	scenario("purchases", function()
		local shops = venues.Shops
		local before = CashService.get(A)
		moveTo(A, shops.BatBoutique.Counter.Position)
		local ok, message = HubShops.buy(A, "skin:Neon")
		expect("bought the Neon Bat", ok and HubBase.data(A).owned["skin:Neon"] == true, message)
		moveTo(A, shops.LotAndDecor.Counter.Position)
		ok, message = HubShops.buy(A, "decor:planter")
		expect("bought a planter", ok, message)
		ok, message = HubShops.use(A, "decor:planter", 1)
		expect("placed it on decor spot 1", ok and HubBase.data(A).decor["1"] == "decor:planter", message)
		moveTo(A, shops.UpgradeOffice.Counter.Position)
		for level = 1, 2 do
			ok, message = HubShops.buy(A, "upgrade:stations")
			expect("bought extra station level " .. level, ok and HubBase.data(A).upgrades.stations == level, message)
		end
		expect("pads 7 and 8 were built", pad(A, 7) ~= nil and pad(A, 8) ~= nil)
		local spent = before - CashService.get(A)
		expect("charged 15K + 2K + 150K + 750K (give or take income)", spent >= 917000 - 2000 and spent <= 917000, spent)
	end)

	scenario("stations 7 and 8", function()
		for _, pair in { { "t027-a2", 7 }, { "t027-a3", 8 } } do
			local rec = WorkerInventory.take(A, pair[1])
			rec.loc, rec.station = "station", pair[2]
			expect("worker given to station " .. pair[2], WorkerInventory.give(A, rec) and WorkerInventory.respawn(A, pair[1]) ~= nil)
			expect("it stands there", placed(A, pair[1]) ~= nil and (pad(A, pair[2]) :: any):GetAttribute("Occupied") == true)
		end
	end)

	scenario("arena trophy", function()
		local CFG = HubConfig.Arena
		CFG.HIT_INTERVAL, CFG.INTRO_TIME, CFG.OUTRO_TIME = 0.05, 0.3, 1.0
		local pads = venues.Arena.QueuePads
		moveTo(A, pads.Pad1.Position)
		moveTo(B, pads.Pad3.Position)
		local t0 = HubBase.data(A).trophies + HubBase.data(B).trophies
		expect("A queues", HubArena.join(A, "t027-a1"))
		expect("B queues", HubArena.join(B, "t027-b1"))
		expect("the fight ends with one trophy won", waitUntil(20, function()
			return HubBase.data(A).trophies + HubBase.data(B).trophies == t0 + 1
		end), ("%d + %d"):format(HubBase.data(A).trophies, HubBase.data(B).trophies))
		task.wait(1.5)
	end)

	scenario("tutorial", function()
		HubBase.handleAction(A, "TutorialDone")
		expect("tutorial marked done", HubBase.data(A).tutorial == true)
	end)

	scenario("PvP steal", function()
		local model = placed(B, "t027-b2")
		expect("B's worker stands on B's lot", model ~= nil)
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart
		;(A.Character :: Model):PivotTo(CFrame.new(root.Position + Vector3.new(0, 1, 4)))
		task.wait(0.3)
		local ok, message = PvPSteal.tryBegin(A, model :: Model)
		expect("steal begins", ok, message)
		PvPSteal._test.setTeleportCheck(false)
		;(A.Character :: Model):PivotTo(PlotService.getPlot(A).PrimaryPart.CFrame * CFrame.new(0, 3.5, 0))
		PvPSteal._test.check()
		PvPSteal._test.setTeleportCheck(true)
		expect("delivered: A owns it, B doesn't", waitUntil(10, function()
			return record(A, "t027-b2") ~= nil and record(B, "t027-b2") == nil
		end))
		expect("the transfer journal settles", waitUntil(30, function()
			return PvPTransfer.isClear(PlayerData.store(), -1) == true and PvPTransfer.isClear(PlayerData.store(), -2) == true
		end))
	end)

	scenario("leave (final saves)", function()
		HubArena.leave(A, true)
		HubArena.leave(B, true)
		for _, p in { A, B } do
			finalSaves[p.UserId] = nil
			PlayerData._test.leave(p)
			expect(p.Name .. " final save landed", waitUntil(20, function()
				return finalSaves[p.UserId]
			end))
		end
		local a = HttpService:JSONDecode(finalSaves[-1])
		local b = HttpService:JSONDecode(finalSaves[-2])
		local expectations = { cashA = a.cash, cashB = b.cash, trophiesA = a.hub.trophies or 0, trophiesB = b.hub.trophies or 0 }
		testStore:SetAsync("expect", expectations)
		note("INFO", "expectations for B", HttpService:JSONEncode(expectations))
		expect("A's save holds stations 7 and 8 and the stolen worker", finalSaves[-1]:find('"station":7', 1, true) and finalSaves[-1]:find('"station":8', 1, true) and finalSaves[-1]:find("t027-b2", 1, true), finalSaves[-1]:sub(1, 300))
	end)
	finish("COMPLETE")
	return
end

if phase == "b" then
	local wanted = testStore:GetAsync("expect")
	scenario("rejoin", function()
		expect("expectations from A found", type(wanted) == "table")
		local hubA, hubB = (PlayerData.get(A) :: any).hub, (PlayerData.get(B) :: any).hub
		expect("schema 3 in memory and in the store", (PlayerData.get(A) :: any).schema == 3 and rawSchema(-1) == 3)
		local gained = CashService.get(A) - wanted.cashA -- placed workers have been earning since the load
		expect("cash is what A saved (plus income since the load)", gained >= 0 and gained <= 1000, ("%s vs saved %s"):format(CashService.get(A), wanted.cashA))
		expect("purchases are back", hubA.owned["skin:Neon"] == true and hubA.owned["decor:planter"] == true and hubA.decor["1"] == "decor:planter", HttpService:JSONEncode(hubA))
		expect("upgrade levels are back", hubA.upgrades and hubA.upgrades.stations == 2, HttpService:JSONEncode(hubA.upgrades))
		expect("trophies are back", (hubA.trophies or 0) == wanted.trophiesA and (hubB.trophies or 0) == wanted.trophiesB and wanted.trophiesA + wanted.trophiesB == 1, ("%s/%s vs %s/%s"):format(tostring(hubA.trophies), tostring(hubB.trophies), wanted.trophiesA, wanted.trophiesB))
		expect("tutorial still done", hubA.tutorial == true)
		expect("the stolen worker survived the rejoin with A", record(A, "t027-b2") ~= nil and record(B, "t027-b2") == nil)
		expect("journals clear", PvPTransfer.isClear(PlayerData.store(), -1) == true and PvPTransfer.isClear(PlayerData.store(), -2) == true)
	end)
	scenario("upgrades off: stations 7/8", function()
		expect("UPGRADES flag is off for this session", not HubBase.flag("UPGRADES_ENABLED"))
		expect("no pads 7 and 8", pad(A, 7) == nil and pad(A, 8) == nil)
		for _, uid in { "t027-a2", "t027-a3" } do
			local rec = record(A, uid)
			expect(uid .. " went to storage", rec and rec.loc == "inventory" and rec.station == nil, rec and HttpService:JSONEncode(rec))
		end
		expect("the station-1 worker is still placed", placed(A, "t027-a1") ~= nil)
	end)
	scenario("cleanup", function()
		for _, p in { A, B } do
			PlayerData._test.leave(p)
		end
		task.wait(2)
		local store = PlayerData.store()
		for _, id in { -1, -2 } do
			for _, k in { "player_", "zones_", "pvpx_" } do
				pcall(store.RemoveAsync, store, k .. id)
			end
		end
		testStore:RemoveAsync("expect")
		expect("test keys removed", store:GetAsync("player_-1") == nil and store:GetAsync("player_-2") == nil)
	end)
	finish("COMPLETE")
end
