-- Studio location: ServerScriptService.DevTest_Base033 (Script)
-- DevTest_Base033  (Milestone 033) -- STUDIO-ONLY test of living bases, worker levels, base pads 7-12, fair stealing
-- and purchases. Inert unless Studio started the session with StudioTestService and one of these arguments
-- (in-memory save: ServerStorage StudioMemoryStore = true). Turns the 033 switches on for the run and puts every
-- switch back as it was.
--   "base033:solo" (1 client, A):
--     off        all 033 switches off: pads where they were built, nothing published, no level/unlock prompts
--     on         switches on: the lot's six pads in the new layout, published
--     levels     hidden below 3 placed workers; NEW! hint at 3; refused without cash; card button (BaseRequest) and pad
--                prompt (a real prompt hold) each raise one level and charge exactly; a re-sent request with no
--                cash does nothing; income exact (attributes and paid cash); Level 10 = top; badge at 5, glow at 10;
--                saved (the in-memory store's copy) and loaded back (SIM rejoin)
--     pads       NEW! hint + unlock pad once all 6 are full; refused far away / without cash; real prompt hold
--                unlocks pad 7 at its spot; a new worker goes onto it; pads 8-12 in order at their prices; no 13th
--                for cash; Extra Slots pass (SIM ownership) = pads 13-14 + 10 storage; saved + loaded back (SIM)
--     living     props + job poses near the camera (push-up hands on the floor), none far away, none with Low
--                effects; frame time and part count with all 12 bases full (12 workers each) living on vs off
--     purchases  receipts (SIM: made-up receipts into the real handler): granted once, a repeat grants nothing,
--                a failed save -> NotProcessedYet and the retry grants nothing more, absent player / unknown
--                product -> NotProcessedYet, receipt list capped; Starter Pack once (cash + trail), then hidden;
--                passes (SIM ownership): 2x Cash, VIP (x1.1, gold tag), Extra Slots; Store cards; saved (SIM rejoin)
--     off again  switches off: pads back, bought pads down with their workers moved to storage (none lost)
--   "base033:duo" (2 clients, A thief + B owner):
--     fair       B's starred favourite can't be stolen (shield on A's screen, prompt off); a stolen Level 4 worker
--                keeps its level and income at A's base; same base twice refused; B's 2nd loss -> safety bubble;
--                a worker on a bought pad can be stolen; B's Store never opens by itself after the robbery
--   "base033:save" (1 client, REAL Studio DataStore: StudioMemoryStore not set, API access on; test user -1):
--     save       a Level 4 worker, bought pad 7 with a worker on it, a Cash Stack receipt and the Starter Pack go
--                through a real final save and a real load (rejoin); afterwards the level, income, pad and worker
--                are back, the same receipt grants nothing and the Starter Pack can't be bought again; test keys
--                removed at the end
-- Results: "@@T033|". Start `TAG=T033 tools/test_guard.sh <label>` BEFORE launching.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
local playArg = game:GetService("ServerStorage"):GetAttribute("StudioPlayTest") -- in-editor Play Solo (ONE process): for a machine too low on memory for a test session
if type(playArg) == "string" and playArg ~= "" then
	okArgs, args = true, playArg
end
local mode = if okArgs and args == "base033:solo" then "solo" elseif okArgs and args == "base033:duo" then "duo" elseif okArgs and args == "base033:save" then "save" else nil
if not mode then
	return
end
local NEED = if mode == "duo" then 2 else 1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s %s: %s | %s"):format(kind, mode, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T033|" .. line)
end
local function finish(state: string)
	local summary = ("%s mode=%s passed=%d failed=%d (simulated checks=%d)"):format(state, mode, passed, failed, simulated)
	print("@@T033|SUMMARY " .. summary)
	if type(playArg) == "string" and playArg ~= "" then
		game:GetService("ServerStorage"):SetAttribute("StudioPlayTestResult", summary .. "\n" .. table.concat(lines, "\n"))
		return
	end
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
	print("@@T033|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

local PlayerData, PlotService, WorkerInventory = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory")
local CashService, BaseService, PurchaseService = mod("CashService"), mod("BaseService"), mod("PurchaseService")
local PassiveIncome, WorkerService, StealGuard = mod("PassiveIncome"), mod("WorkerService"), mod("StealGuard")
local PvPSteal, PvPBase, NPCPlacement = mod("PvPSteal"), mod("PvPBase"), mod("NPCPlacement")
local NPCWanderer, WorkerAppearance = mod("NPCWanderer"), mod("WorkerAppearance")
local BaseConfig = require(ReplicatedStorage:WaitForChild("BaseConfig")) :: any
local StealConfig = require(ReplicatedStorage:WaitForChild("StealConfig")) :: any
local ProductConfig = require(ReplicatedStorage:WaitForChild("ProductConfig")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

local SWITCHES = { "StudioLiving", "StudioLevels", "StudioPads", "StudioFairSteal", "StudioPurchases", "StudioOwnPasses", "StudioPvPStealing", "StudioSpeed" }
local was = {}
for _, name in SWITCHES do
	was[name] = ServerStorage:GetAttribute(name)
end
ServerStorage:SetAttribute("StudioSpeed", true) -- 036: the Starter Pack's trail is published (SpeedOwned) only with Speed on; Speed is live (D46)
local function switches(on: boolean)
	for _, name in { "StudioLiving", "StudioLevels", "StudioPads", "StudioFairSteal", "StudioPurchases" } do
		ServerStorage:SetAttribute(name, on)
	end
	task.wait(0.6)
end
local function restore()
	for _, name in SWITCHES do
		ServerStorage:SetAttribute(name, was[name])
	end
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
	return n >= NEED
end)
task.wait(3)
local memory = ServerStorage:GetAttribute("StudioMemoryStore") == true or not PlayerData.isPersistent()
if mode ~= "save" and not memory then
	finish("ABORTED: run base033 on the in-memory save (ServerStorage StudioMemoryStore = true)")
	return
elseif mode == "save" and memory then
	finish("ABORTED: base033:save needs the real Studio DataStore (API access on, StudioMemoryStore not set)")
	return
end
local list = Players:GetPlayers()
table.sort(list, function(a, b)
	return a.UserId > b.UserId
end)
local A, B = list[1], list[2]
local everyone = if mode == "duo" then { A, B } else { A }
for _, p in everyone do
	if not (p and ready(p)) then
		finish(("ABORTED: needs %d loaded player(s)"):format(NEED))
		return
	end
end

local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test033Bridge"
bridge.Parent = ReplicatedStorage
local replies: { [number]: any } = {}
local helpers: { [Player]: boolean } = {}
local seq = 0
bridge.OnServerEvent:Connect(function(p, kind, id, value)
	if kind == "reply" and type(id) == "number" then
		replies[id] = value
	elseif kind == "ready" then
		helpers[p] = true
	end
end)
local function ask(p: Player, kind: string, arg: any?, timeout: number?): any
	seq += 1
	local id = seq
	bridge:FireClient(p, kind, id, arg)
	local value = waitUntil(timeout or 15, function()
		return replies[id]
	end)
	replies[id] = nil
	return value or { answered = false }
end
for _, p in everyone do
	local holder = Instance.new("ScreenGui")
	holder.Name = "Test033Helper"
	holder.ResetOnSpawn = false
	local helper = script:WaitForChild("ClientHelper"):Clone()
	helper.Disabled = false
	helper.Parent = holder
	holder.Parent = p:WaitForChild("PlayerGui")
end
waitUntil(20, function()
	for _, p in everyone do
		if not helpers[p] then
			return false
		end
	end
	return true
end)

-- Helpers ---------------------------------------------------------------------------------------------------
local function root(p: Player): BasePart
	return (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
end
local function put(p: Player, pos: Vector3)
	local character = p.Character :: Model
	character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	root(p).AssemblyLinearVelocity = Vector3.zero
	task.wait(0.6)
end
local function data(p: Player): any
	return PlayerData.get(p) :: any
end
local function plotOf(p: Player): Model
	return PlotService.getPlot(p) :: Model
end
local function pad(p: Player, index: number): BasePart?
	for _, s in plotOf(p).Stations:GetChildren() do
		if s:GetAttribute("StationIndex") == index then
			return s :: BasePart
		end
	end
	return nil
end
local function localXZ(plot: Model, part: BasePart): (number, number)
	local l = (plot.PrimaryPart :: BasePart).CFrame:PointToObjectSpace(part.Position)
	return l.X, l.Z
end
local function setCash(p: Player, amount: number)
	local have = CashService.get(p)
	if amount > have then
		CashService.add(p, amount - have)
	elseif amount < have then
		CashService.trySpend(p, have - amount)
	end
end
local uidN = 0
local function grant(p: Player, id: string, level: number?): any
	uidN += 1
	local record = { uid = ("T033_%d_%d"):format(p.UserId < 0 and -p.UserId or p.UserId, uidN), id = id, zone = WorkerCatalogue.get(id).zone, level = level or 1, tier = "Normal" }
	WorkerInventory.grant(p, record)
	return WorkerInventory.getRecord(p, record.uid)
end
local function clearWorkers(p: Player)
	for _, w in table.clone(data(p).workers) do
		WorkerInventory.take(p, w.uid)
	end
	task.wait(0.3)
end
local function placedModel(p: Player, uid: string): Model?
	return WorkerInventory.placedModel(p, uid)
end
local function savedCopy(p: Player): any?
	PlayerData.save(p)
	local store = PlayerData.store()
	local record = store and store.values and store.values["player_" .. p.UserId]
	return record and record.data
end
local function reload(saved: any): any -- what loading this save would give (SIM rejoin)
	return PlayerData._sanitize(PlayerData._migrate(saved))
end

-- SOLO ---------------------------------------------------------------------------------------------------------
local builtSpots: { [number]: Vector3 } = {}
local function soloOff()
	switches(false)
	ServerStorage:SetAttribute("StudioOwnPasses", nil)
	local plot = plotOf(A)
	for i = 1, 6 do
		local p = pad(A, i) :: BasePart
		builtSpots[i] = p.Position
		local x, z = localXZ(plot, p)
		expect(("pad %d where it was built"):format(i), math.abs(math.abs(x) - 8) < 0.05, ("%.2f,%.2f"):format(x, z))
	end
	for _, key in { "LivingOn", "LevelsOn", "PadsOn", "FairStealOn", "PurchasesOn" } do
		expect(key .. " off", ReplicatedStorage:GetAttribute(key) ~= true)
	end
	expect("no unlock pad", plot:FindFirstChild("PadUnlock") == nil)
	local enabledLevel = 0
	for _, d in plot:GetDescendants() do
		if d.Name == "LevelPrompt" and d:GetAttribute("Want") == true then
			enabledLevel += 1
		end
	end
	expect("no level prompts wanted", enabledLevel == 0, enabledLevel)
	local _, stations = WorkerInventory.capacity(A)
	expect("6 stations", stations == 6, stations)
	local ui = ask(A, "ui")
	expect("client: store cards Coming soon", ui.storeAvailable == 0, ui.storeAvailable)
end

local function soloOn()
	switches(true)
	local plot = plotOf(A)
	for i = 1, 6 do
		local p = pad(A, i) :: BasePart
		local x, z = localXZ(plot, p)
		local spot = BaseConfig.PAD_SPOTS[i]
		expect(("pad %d moved to its spot"):format(i), math.abs(x - spot[1]) < 0.05 and math.abs(z - spot[2]) < 0.05, ("%.2f,%.2f"):format(x, z))
		local ring = p:FindFirstChild("Ring") :: BasePart
		expect(("pad %d ring moved with it"):format(i), ring and (ring.Position - p.Position).Magnitude < 0.2)
	end
	for _, key in { "LivingOn", "LevelsOn", "PadsOn", "FairStealOn", "PurchasesOn" } do
		expect(key .. " published", ReplicatedStorage:GetAttribute(key) == true)
	end
end

local function soloLevels()
	clearWorkers(A)
	setCash(A, 0)
	ask(A, "clear")
	local w1 = grant(A, "broke_bob")
	grant(A, "broke_bob")
	task.wait(0.5)
	expect("2 placed: levels hidden", A:GetAttribute("LevelsShown") ~= true)
	local r = ask(A, "levelUp", w1.uid)
	expect("card level up refused while hidden", r.ok ~= true and w1.level == 1, r.ok)
	grant(A, "broke_bob")
	waitUntil(3, function()
		return A:GetAttribute("LevelsShown") == true
	end)
	expect("3 placed: levels shown", A:GetAttribute("LevelsShown") == true)
	local ev = ask(A, "events")
	local intro = false
	for _, e in ev.events or {} do
		intro = intro or (e.kind == "Intro" and e.info == "levels")
	end
	expect("client: NEW! levels hint event", intro)
	expect("client: NEW! hint on screen", ev.hintVisible == true and tostring(ev.hintText):find("Level up") ~= nil, ev.hintText)
	expect("intro saved in hub", data(A).hub.intro and data(A).hub.intro.levels == true)
	-- no cash
	r = ask(A, "levelUp", w1.uid)
	expect("refused without cash", r.ok ~= true and w1.level == 1, r.message)
	-- card button: exactly the cost
	local cost = BaseConfig.levelCost(5, 1)
	expect("Level 2 cost = 30 s of $5/s = $150", cost == 150, cost)
	setCash(A, cost)
	r = ask(A, "levelUp", w1.uid)
	expect("card: Level 2", r.ok == true and w1.level == 2, r.message)
	expect("charged exactly", CashService.get(A) == 0, CashService.get(A))
	local m = placedModel(A, w1.uid) :: Model
	expect("model Level 2 + income 5.5", m and m:GetAttribute("Level") == 2 and m:GetAttribute("Income") == 5.5, m and m:GetAttribute("Income"))
	expect("player income 15.5", A:GetAttribute("Income") == 15.5, A:GetAttribute("Income"))
	r = ask(A, "levelUp", w1.uid)
	expect("re-sent with no cash: nothing", r.ok ~= true and w1.level == 2)
	-- paid income over 6 s: 15.5/s (the half dollars carried, not lost)
	local c0, t0 = CashService.get(A), os.clock()
	task.wait(6)
	local paid, dt = CashService.get(A) - c0, os.clock() - t0
	expect("paid ~15.5/s", math.abs(paid / dt - 15.5) < 2.7, ("%d in %.1f s"):format(paid, dt))
	-- pad prompt (real hold on the client)
	local p1 = pad(A, (m :: Model):GetAttribute("StationIndex")) :: BasePart
	setCash(A, BaseConfig.levelCost(5, 2))
	put(A, p1.Position + (plotOf(A).PrimaryPart :: BasePart).CFrame.LookVector * 3)
	r = ask(A, "padLevel")
	expect("client: one level prompt enabled (nearest own pad)", r.enabled == 1, r.enabled)
	expect("pad prompt: Level 3", w1.level == 3, w1.level)
	expect("pad prompt charged", CashService.get(A) < BaseConfig.levelCost(5, 2), CashService.get(A))
	-- to Level 10
	for level = 3, 9 do
		setCash(A, BaseConfig.levelCost(5, level))
		BaseService.levelUp(A, w1.uid)
	end
	expect("Level 10", w1.level == 10, w1.level)
	expect("Level 10 income 9.5", m:GetAttribute("Income") == 9.5, m:GetAttribute("Income"))
	expect("no cost at the top", BaseConfig.levelCost(5, 10) == nil)
	setCash(A, 10 ^ 9)
	local ok = BaseService.levelUp(A, w1.uid)
	expect("Level 11 refused, nothing charged", not ok and w1.level == 10 and CashService.get(A) == 10 ^ 9)
	task.wait(0.6)
	r = ask(A, "badge", w1.uid)
	expect("client: star badge + gold glow at 10", r.badge == "10" and r.glow == true, ("%s %s"):format(tostring(r.badge), tostring(r.glow)))
	-- costs: a few spot values, all 2 significant digits
	info(
		"level costs Broke Bob ($5/s) L1..9",
		(function()
			local t = {}
			for l = 1, 9 do
				table.insert(t, BaseConfig.levelCost(5, l))
			end
			return table.concat(t, ",")
		end)()
	)
	info(
		"level costs CEO Chad ($100/s) L1..9",
		(function()
			local t = {}
			for l = 1, 9 do
				table.insert(t, BaseConfig.levelCost(100, l))
			end
			return table.concat(t, ",")
		end)()
	)
	-- saved + loaded back
	local saved = savedCopy(A)
	local found = nil
	for _, w in (saved and saved.workers or {}) do
		if w.uid == w1.uid then
			found = w
		end
	end
	expect("saved with level 10", found and found.level == 10, found and found.level)
	local back = reload(saved)
	local again = nil
	for _, w in back.workers do
		if w.uid == w1.uid then
			again = w
		end
	end
	expect("loads back at level 10", again and again.level == 10 and again.loc == "station", nil, true)
	setCash(A, 0)
end

local function soloPads()
	ask(A, "clear")
	-- fill the six
	local _, onPads = WorkerInventory.count(A)
	for _ = onPads + 1, 6 do
		grant(A, "delivery_dave")
	end
	waitUntil(3, function()
		return A:GetAttribute("PadUnlockShown") == true
	end)
	local plot = plotOf(A)
	local unlock = plot:FindFirstChild("PadUnlock") :: BasePart?
	expect("6 full: unlock pad shown", A:GetAttribute("PadUnlockShown") == true and unlock ~= nil)
	if unlock then
		local x, z = localXZ(plot, unlock)
		expect("unlock pad at spot 7", math.abs(x - BaseConfig.PAD_SPOTS[7][1]) < 0.05 and math.abs(z - BaseConfig.PAD_SPOTS[7][2]) < 0.05, ("%.1f,%.1f"):format(x, z))
		expect("unlock label $5,000", unlock:FindFirstChild("Label") and unlock.Label.Price.Text == "Unlock $5,000", unlock:FindFirstChild("Label") and unlock.Label.Price.Text)
	end
	local ev = ask(A, "events")
	local intro = false
	for _, e in ev.events or {} do
		intro = intro or (e.kind == "Intro" and e.info == "pads")
	end
	expect("client: NEW! pads hint", intro and tostring(ev.hintText):find("pad") ~= nil, ev.hintText)
	-- far away
	setCash(A, 5000)
	put(A, workspace.SpawnLocation.Position)
	local r = ask(A, "unlockRemote")
	expect("refused far away", r.ok ~= true and BaseService._test.padsBought(A) == 0, r.message)
	-- no cash, standing on it
	setCash(A, 0)
	put(A, (unlock :: BasePart).Position)
	r = ask(A, "unlockPrompt")
	expect("client: unlock prompt shown to the owner", r.enabled == true)
	expect("refused without cash", BaseService._test.padsBought(A) == 0, BaseService._test.padsBought(A))
	setCash(A, 5000)
	r = ask(A, "unlockPrompt")
	expect("prompt hold: pad 7 unlocked, $5,000 charged", BaseService._test.padsBought(A) == 1 and CashService.get(A) < 5000, CashService.get(A))
	local p7 = pad(A, 7)
	expect("pad 7 at its spot", p7 ~= nil and p7:GetAttribute("BasePad") == true)
	if p7 then
		local x, z = localXZ(plot, p7)
		expect("pad 7 spot", math.abs(x - BaseConfig.PAD_SPOTS[7][1]) < 0.05 and math.abs(z - BaseConfig.PAD_SPOTS[7][2]) < 0.05)
		expect("pad 7 has a Place prompt", p7:FindFirstChild("PlacePrompt") ~= nil)
	end
	local _, stations = WorkerInventory.capacity(A)
	expect("7 stations", stations == 7, stations)
	local w7 = grant(A, "business_betty")
	expect("new worker goes onto pad 7", w7.loc == "station" and w7.station == 7, ("%s %s"):format(tostring(w7.loc), tostring(w7.station)))
	expect("its model stands on pad 7", placedModel(A, w7.uid) ~= nil and p7 and (placedModel(A, w7.uid) :: Model):GetPivot().Position.X - p7.Position.X < 0.1)
	-- store it and equip it back (the inventory's own actions on a bought pad)
	local r2 = ask(A, "inventory", { action = "Store", uid = w7.uid })
	expect("store from pad 7", w7.loc == "inventory", r2.ok)
	r2 = ask(A, "inventory", { action = "Equip", uid = w7.uid })
	expect("equip back onto pad 7", w7.loc == "station" and w7.station == 7, r2.ok)
	-- pads 8-12 in order
	local prices = {}
	for n = 2, 6 do
		local price = A:GetAttribute("PadNextPrice")
		table.insert(prices, tostring(price))
		local u = plot:FindFirstChild("PadUnlock") :: BasePart?
		if not u then
			break
		end
		setCash(A, price)
		put(A, u.Position)
		local ok, message = BaseService.unlockPad(A)
		expect(("pad %d unlocked"):format(6 + n), ok and BaseService._test.padsBought(A) == n and CashService.get(A) < price, message)
	end
	expect("prices in order 12k 30k 75k 180k 450k", table.concat(prices, ",") == "12000,30000,75000,180000,450000", table.concat(prices, ","))
	_, stations = WorkerInventory.capacity(A)
	expect("12 stations", stations == 12, stations)
	expect("no 13th pad for cash", A:GetAttribute("PadNextPrice") == nil and plot:FindFirstChild("PadUnlock") == nil)
	setCash(A, 10 ^ 7)
	local ok = BaseService.unlockPad(A)
	expect("unlock refused at 12", not ok and CashService.get(A) == 10 ^ 7)
	-- Extra Slots pass (SIM ownership)
	ServerStorage:SetAttribute("StudioOwnPasses", "slots")
	task.wait(1)
	local slots
	slots, stations = WorkerInventory.capacity(A)
	expect("Extra Slots: 14 pads, 30 storage", stations == 14 and slots == 30, ("%d/%d"):format(stations, slots), true)
	local p13, p14 = pad(A, 13), pad(A, 14)
	expect("pads 13-14 at the front corners", p13 and p14 and math.abs(select(2, localXZ(plot, p13)) - BaseConfig.PAD_SPOTS[13][2]) < 0.05, nil, true)
	ServerStorage:SetAttribute("StudioOwnPasses", nil)
	task.wait(1)
	slots, stations = WorkerInventory.capacity(A)
	expect("pass gone again (SIM): 12 pads, 20 storage", stations == 12 and slots == 20, ("%d/%d"):format(stations, slots), true)
	-- saved + loaded back
	local saved = savedCopy(A)
	expect("hub.pads = 6 saved", saved and saved.hub and saved.hub.pads == 6, saved and saved.hub and saved.hub.pads)
	local back = reload(saved)
	expect("loads back with 6 bought pads and a worker on pad 7", back.hub.pads == 6 and (function()
		for _, w in back.workers do
			if w.uid == w7.uid then
				return w.station == 7
			end
		end
		return false
	end)(), nil, true)
	setCash(A, 0)
end

-- Fills every plot's pads (all 12 lots, 12 pads each) with workers for the frame-time check. Test-only models:
-- the other lots get extra pads like a bought base. Returns a cleanup function.
local function fillAllBases(): () -> ()
	local made: { Instance } = {}
	local template = ServerStorage:WaitForChild("NPCModels"):WaitForChild("MysteryNPC")
	local ids = { "broke_bob", "delivery_dave", "street_hustler", "business_betty", "security_sam", "crypto_carl" }
	local n = 0
	for _, plot in workspace.Hub.Plots:GetChildren() do
		if plot == plotOf(A) then
			continue
		end
		local stations = plot:FindFirstChild("Stations")
		local first = stations and stations:FindFirstChild("Station1") :: BasePart?
		if not first then
			continue
		end
		for index = 7, 12 do
			local spot = BaseConfig.PAD_SPOTS[index]
			local copy = first:Clone()
			for _, c in copy:GetChildren() do
				if not c:IsA("BasePart") then
					c:Destroy()
				end
			end
			local at = (plot.PrimaryPart :: BasePart).CFrame * CFrame.new(spot[1], 0, spot[2])
			local delta = CFrame.new(at.Position.X - first.Position.X, 0, at.Position.Z - first.Position.Z)
			for _, piece in copy:GetDescendants() do
				if piece:IsA("BasePart") then
					piece.CFrame = delta * piece.CFrame
				end
			end
			copy.CFrame = delta * first.CFrame
			copy.Name = "Station" .. index
			copy:SetAttribute("StationIndex", index)
			copy:SetAttribute("Occupied", false)
			copy:SetAttribute("TestPad", true)
			copy.Parent = stations
			table.insert(made, copy)
		end
		for _, station in stations:GetChildren() do
			if station:IsA("BasePart") and station:GetAttribute("Occupied") ~= true then
				n += 1
				local id = ids[n % #ids + 1]
				local npc = NPCWanderer.cloneRig(template)
				WorkerService.apply(npc, { uid = "T033perf" .. n, workerId = id, zoneId = "MainStreet", level = 1, tier = "Normal" })
				WorkerAppearance.apply(npc, id)
				npc:SetAttribute("Claimed", true)
				NPCPlacement.placeOnStation(npc, station, plot)
				table.insert(made, npc)
				if n % 12 == 0 then
					task.wait()
				end
			end
		end
	end
	-- A's own base: fill any free pad
	local _, onPads = WorkerInventory.count(A)
	local _, stations = WorkerInventory.capacity(A)
	for _ = onPads + 1, stations do
		grant(A, "crypto_carl")
	end
	return function()
		for _, inst in made do
			inst:Destroy()
		end
	end
end

local function partCount(): number
	local n = 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function soloLiving()
	-- one worker of each type on A's base (Earner and All-rounder are there already)
	grant(A, "street_hustler") -- Fighter
	grant(A, "security_sam") -- Tank
	-- A at the middle of their base: jobs near the camera
	local plot = plotOf(A)
	put(A, (plot.PrimaryPart :: BasePart).Position + (plot.PrimaryPart :: BasePart).CFrame.LookVector * -13)
	task.wait(1.5)
	local r = ask(A, "living")
	expect("client: props near the camera", (r.props or 0) > 0, r.props)
	expect("client: every type on the base (guard, laptop, pushups, sweep)", r.jobsSeen == "guard,laptop,pushups,sweep", r.jobsSeen)
	expect("client: joints driven on the own base", (r.driven or 0) > 0, r.driven)
	if r.pushupHands then
		expect("client: push-up hands near the floor", math.abs(r.pushupHands) < 1.2, ("%.2f studs from the pad top"):format(r.pushupHands))
		expect("client: push-up body low (head under 3 studs)", (r.pushupHead or 99) < 3, ("head %.2f"):format(r.pushupHead or -1))
	else
		info("no push-up worker on A's base", "-")
	end
	expect("client: laptop desk at hand height", r.deskGap == nil or math.abs(r.deskGap) < 1.2, r.deskGap)
	-- far away: no props
	put(A, (workspace.Hub.Plots.Plot11.PrimaryPart :: BasePart).Position) -- (the far end of the bases, ~200 studs)
	task.wait(1)
	r = ask(A, "living")
	info("props while 150 studs away", r.props)
	-- Low effects: none
	put(A, (plot.PrimaryPart :: BasePart).Position + (plot.PrimaryPart :: BasePart).CFrame.LookVector * -13)
	A:SetAttribute("LowEffects", true)
	task.wait(1)
	r = ask(A, "living")
	expect("client: Low effects = no props", r.props == 0, r.props)
	A:SetAttribute("LowEffects", false)
	-- 12 full bases
	local before = partCount()
	local clean = fillAllBases()
	task.wait(3)
	local after = partCount()
	local onPerf = ask(A, "perf", { seconds = 8 }, 30)
	ServerStorage:SetAttribute("StudioLiving", false)
	task.wait(1.5)
	local offPerf = ask(A, "perf", { seconds = 8 }, 30)
	ServerStorage:SetAttribute("StudioLiving", true)
	task.wait(1)
	local placedTotal = 0
	for _, p in workspace.Hub.Plots:GetChildren() do
		placedTotal += #p.PlacedNPCs:GetChildren()
	end
	info("12 full bases", ("%d workers placed; workspace parts %d -> %d (server)"):format(placedTotal, before, after))
	info(
		"frame time (Studio client, not a phone)",
		("living ON %.1f ms avg / %.1f worst, %d job props, %d driven; living OFF %.1f ms avg / %.1f worst"):format(
			onPerf.avgMs or -1,
			onPerf.worstMs or -1,
			onPerf.props or -1,
			onPerf.driven or -1,
			offPerf.avgMs or -1,
			offPerf.worstMs or -1
		)
	)
	expect("living costs < 4 ms a frame here", (onPerf.avgMs or 99) - (offPerf.avgMs or 0) < 4, ("%.1f vs %.1f"):format(onPerf.avgMs or -1, offPerf.avgMs or -1))
	clean()
	task.wait(1)
end

local function soloPurchases()
	local P = PurchaseService
	local realIds = {}
	for key, item in ProductConfig.BY_KEY do
		realIds[key] = item.id
	end
	local ids = { cash_s = 9001, cash_m = 9002, cash_l = 9003, starter = 9004, x2cash = 8001, slots = 8002, vip = 8003 }
	for key, id in ids do
		P._test.setId(key, id)
	end
	ask(A, "setIds", ids) -- (the client's Store reads its own copy of ProductConfig)
	ServerStorage:SetAttribute("StudioPurchases", false)
	task.wait(0.3)
	ServerStorage:SetAttribute("StudioPurchases", true) -- (re-indexes the ids)
	task.wait(0.5)
	setCash(A, 0)
	local income = PassiveIncome.getIncome(A)
	local function receipt(productId: number, purchaseId: string, playerId: number?): any
		return P.processReceipt({
			PlayerId = playerId or A.UserId,
			ProductId = productId,
			PurchaseId = purchaseId,
			CurrencySpent = 25,
			CurrencyType = Enum.CurrencyType.Robux,
			PlaceIdWherePurchased = 0,
		})
	end
	local small = ProductConfig.BY_KEY.cash_s
	local want = ProductConfig.cashFor(small, income)
	local slack0 = income * 20 + 1 -- (income keeps coming in while the save runs)
	local before = CashService.get(A)
	local d = receipt(9001, "T033-r1")
	local got = CashService.get(A) - before
	expect("Cash Stack granted", d == Enum.ProductPurchaseDecision.PurchaseGranted and got >= want and got < want + slack0, ("%s %d/%d"):format(tostring(d), got, want), true)
	before = CashService.get(A)
	d = receipt(9001, "T033-r1")
	got = CashService.get(A) - before
	expect("same receipt again: granted, nothing more", d == Enum.ProductPurchaseDecision.PurchaseGranted and got < slack0, got, true)
	local store = PlayerData.store()
	store.failNext = 3 -- (SessionStore tries a save 3 times)
	local c0 = CashService.get(A)
	d = receipt(9002, "T033-r2")
	local mid = ProductConfig.cashFor(ProductConfig.BY_KEY.cash_m, PassiveIncome.getIncome(A))
	expect("save failed: NotProcessedYet", d == Enum.ProductPurchaseDecision.NotProcessedYet, d, true)
	store.failNext = 0
	d = receipt(9002, "T033-r2")
	local gained = CashService.get(A) - c0
	local slack = PassiveIncome.getIncome(A) * 30
	expect("retry: granted once in total", d == Enum.ProductPurchaseDecision.PurchaseGranted and gained >= mid and gained < mid + slack, ("%d vs %d"):format(gained, mid), true)
	expect("absent player: NotProcessedYet", receipt(9001, "T033-r3", 123456789) == Enum.ProductPurchaseDecision.NotProcessedYet, nil, true)
	expect("unknown product: NotProcessedYet", receipt(7777, "T033-r4") == Enum.ProductPurchaseDecision.NotProcessedYet, nil, true)
	for i = 1, 55 do
		receipt(9001, "T033-cap" .. i)
	end
	expect("receipt list capped at 50", #data(A).hub.receipts == ProductConfig.RECEIPTS_KEPT, #data(A).hub.receipts, true)
	-- Starter Pack
	local st = P._test.state(A)
	expect("Starter Pack offered to a new player", st.starterShown == true, nil, true)
	local ui = ask(A, "ui")
	expect("client: Starter tab shown", ui.starterTab == true, nil, true)
	c0 = CashService.get(A)
	d = receipt(9004, "T033-s1")
	local owned = string.split(A:GetAttribute("SpeedOwned") or "", ",")
	expect(
		"Starter: cash + trail",
		d == Enum.ProductPurchaseDecision.PurchaseGranted and CashService.get(A) > c0 and table.find(owned, "starter") ~= nil,
		A:GetAttribute("SpeedOwned"),
		true
	)
	expect("Starter: once", data(A).hub.starter == true and P._test.starterShown(A) == false, nil, true)
	local ok = P.buy(A, "starter")
	expect("Starter: Buy refused afterwards", not ok, nil, true)
	task.wait(1)
	ui = ask(A, "ui")
	expect("client: Starter tab gone", ui.starterTab == false, nil, true)
	expect("client: cards available with ids", (ui.storeAvailable or 0) >= 3, ui.storeAvailable, true)
	-- passes (SIM ownership)
	local base = PassiveIncome.getIncome(A)
	ServerStorage:SetAttribute("StudioOwnPasses", "x2cash")
	task.wait(1)
	expect(
		"2x Cash doubles income",
		PassiveIncome.getIncome(A) == math.floor(base * 2 + 1e-9) and A:GetAttribute("Pass_x2cash") == true,
		("%s -> %s"):format(base, PassiveIncome.getIncome(A)),
		true
	)
	ServerStorage:SetAttribute("StudioOwnPasses", "x2cash,vip")
	task.wait(2.5)
	expect("VIP: x1.1 on top", PassiveIncome.getIncome(A) == math.floor(base * 2.2 + 1e-9), PassiveIncome.getIncome(A), true)
	local tag = (A.Character :: Model):FindFirstChild("RankTag")
	expect("VIP: gold tag", A:GetAttribute("IsVIP") == true and tag and tostring(tag.Label.Text):find("^VIP") ~= nil, tag and tag.Label.Text, true)
	ui = ask(A, "ui")
	expect("client: owned passes say Owned", ui.owned == 2, ui.owned, true)
	ok = P.buy(A, "vip")
	expect("an owned pass can't be bought again", not ok, nil, true)
	ServerStorage:SetAttribute("StudioOwnPasses", nil)
	task.wait(1)
	expect("passes off again (SIM)", PassiveIncome.getIncome(A) == base and A:GetAttribute("IsVIP") ~= true, nil, true)
	-- saved + loaded back
	local saved = savedCopy(A)
	local back = reload(saved)
	expect(
		"receipts, starter, born saved",
		type(back.hub.receipts) == "table" and table.find(back.hub.receipts, "T033-cap55") ~= nil and back.hub.starter == true and type(back.hub.born) == "number",
		nil,
		true
	)
	for key in ids do
		P._test.setId(key, realIds[key]) -- (back to the dashboard ids)
	end
end

local function soloOffAgain()
	local _, _, _, before = WorkerInventory.count(A)
	switches(false)
	task.wait(1)
	local plot = plotOf(A)
	for i = 1, 6 do
		local p = pad(A, i) :: BasePart
		expect(("pad %d back where it was built"):format(i), (p.Position - builtSpots[i]).Magnitude < 0.05)
	end
	expect("bought pads taken down (switch off)", pad(A, 7) == nil and plot:FindFirstChild("PadUnlock") == nil)
	local _, stations = WorkerInventory.capacity(A)
	expect("6 stations again", stations == 6, stations)
	local _, _, _, after = WorkerInventory.count(A)
	expect("no worker lost", after == before, ("%d -> %d"):format(before, after))
	for _, key in { "LivingOn", "LevelsOn", "PadsOn", "FairStealOn", "PurchasesOn" } do
		expect(key .. " off again", ReplicatedStorage:GetAttribute(key) ~= true)
	end
	local r = ask(A, "living")
	expect("client: no props with living off", r.props == 0, r.props)
end

-- DUO ----------------------------------------------------------------------------------------------------------
-- A thief who got a worker home still holds it: put it on a free pad of their base.
local function placeCarried(p: Player)
	local record = nil
	for _, w in data(p).workers do
		if w.loc == "carried" then
			record = w
		end
	end
	if not record then
		return
	end
	local _, stations = WorkerInventory.capacity(p)
	for index = 1, stations do
		local free = pad(p, index)
		if free and free:GetAttribute("Occupied") ~= true then
			put(p, free.Position)
			NPCPlacement.tryPlace(p, free)
			return
		end
	end
end

local function duoFair()
	switches(true)
	ServerStorage:SetAttribute("StudioPvPStealing", true)
	task.wait(1)
	PvPBase._test.setProtection(A, nil)
	PvPBase._test.setProtection(B, nil)
	StealGuard._test.reset()
	PvPSteal._test.setTeleportCheck(false) -- (the test moves A home by teleport; a real thief walks)
	clearWorkers(A)
	clearWorkers(B)
	local b1 = grant(B, "street_hustler", 4)
	local b2 = grant(B, "business_betty")
	local b3 = grant(B, "security_sam")
	task.wait(0.8)
	expect("B's Level 4 worker earns its level income", (placedModel(B, b1.uid) :: Model):GetAttribute("Income") == BaseConfig.levelIncome(9, 4))
	-- favourite
	local r = ask(B, "favourite", b2.uid)
	waitUntil(3, function()
		return (placedModel(B, b2.uid) :: Model):GetAttribute("FavShield") == true
	end)
	local m2 = placedModel(B, b2.uid) :: Model
	expect("B's star: one favourite, shielded", m2:GetAttribute("FavShield") == true and StealGuard.favourite(B) == b2.uid, r.ok)
	local prompt = m2.HumanoidRootPart:FindFirstChild("PvPStealPrompt") :: ProximityPrompt?
	expect("its Steal prompt is off", prompt == nil or prompt.Enabled == false)
	put(A, m2:GetPivot().Position + Vector3.new(0, 0, 3))
	local seen = ask(A, "shield", b2.uid)
	expect("A's screen shows the shield", seen.shield == true)
	local ok, message = PvPSteal.tryBegin(A, m2)
	expect("A can't steal the favourite", not ok and tostring(message):find("favourite") ~= nil, message)
	-- second star moves it
	ask(B, "favourite", b3.uid)
	waitUntil(3, function()
		return StealGuard.favourite(B) == b3.uid
	end)
	expect("starring another moves the shield", StealGuard.favourite(B) == b3.uid and m2:GetAttribute("FavShield") ~= true)
	ask(B, "favourite", b2.uid) -- back to b2
	waitUntil(3, function()
		return StealGuard.favourite(B) == b2.uid
	end)
	-- steal the Level 4 worker
	ask(B, "clear")
	local m1 = placedModel(B, b1.uid) :: Model
	put(A, m1:GetPivot().Position + Vector3.new(0, 0, 3))
	ok, message = PvPSteal.tryBegin(A, m1)
	expect("A starts stealing B's Level 4 worker", ok, message)
	put(A, (plotOf(A).PrimaryPart :: BasePart).Position)
	PvPSteal._test.deliver(A) -- (or the server's own home check delivers it first)
	waitUntil(6, function()
		return WorkerInventory.getRecord(A, b1.uid) ~= nil
	end)
	local got = WorkerInventory.getRecord(A, b1.uid)
	expect("delivered to A at Level 4", got and got.level == 4, got and got.level)
	placeCarried(A)
	local onA = placedModel(A, b1.uid)
	expect(
		"on A's pad with Level 4 income",
		onA and onA:GetAttribute("Level") == 4 and onA:GetAttribute("Income") == BaseConfig.levelIncome(9, 4),
		onA and onA:GetAttribute("Income")
	)
	-- same base twice
	local m3 = placedModel(B, b3.uid) :: Model
	put(A, m3:GetPivot().Position + Vector3.new(0, 0, 3))
	ok, message = PvPSteal.tryBegin(A, m3)
	expect("same base again refused", not ok and tostring(message):find("not long ago") ~= nil, message)
	-- B's Store didn't open
	local ui = ask(B, "ui")
	expect("B: no Store popped up after the robbery", ui.storeOpen == false)
	-- victim cap: second loss -> bubble
	local keep = StealConfig.SAME_BASE_COOLDOWN
	StealConfig.SAME_BASE_COOLDOWN = 0
	ok, message = PvPSteal.tryBegin(A, m3)
	expect("(cooldown 0 for this check) A steals a second worker", ok, message)
	put(A, (plotOf(A).PrimaryPart :: BasePart).Position)
	PvPSteal._test.deliver(A)
	waitUntil(6, function()
		return WorkerInventory.getRecord(A, b3.uid) ~= nil
	end)
	task.wait(0.5)
	placeCarried(A)
	expect("B's 2nd loss: safety bubble", PvPBase.isBubble(B.UserId) and B:GetAttribute("ProtectedUntil") ~= nil)
	local b4 = grant(B, "crypto_carl")
	task.wait(0.5)
	local m4 = placedModel(B, b4.uid) :: Model
	put(A, m4:GetPivot().Position + Vector3.new(0, 0, 3))
	ok, message = PvPSteal.tryBegin(A, m4)
	expect("bubble: no steal", not ok and tostring(message):find("bubble") ~= nil, message)
	StealConfig.SAME_BASE_COOLDOWN = keep
	-- a bought pad can be robbed
	PvPBase._test.setProtection(B, nil)
	StealGuard._test.reset()
	local _, onPads = WorkerInventory.count(B)
	for _ = onPads + 1, 6 do
		grant(B, "broke_bob")
	end
	waitUntil(3, function()
		return B:GetAttribute("PadUnlockShown") == true
	end)
	local u = plotOf(B):FindFirstChild("PadUnlock") :: BasePart?
	setCash(B, 5000)
	if u then
		put(B, u.Position)
	end
	ok = BaseService.unlockPad(B)
	local b7 = grant(B, "ceo_chad")
	expect("B: worker on bought pad 7", ok and b7.station == 7, b7.station)
	local m7 = placedModel(B, b7.uid) :: Model
	put(A, m7:GetPivot().Position + Vector3.new(0, 0, 3))
	-- (A must have room)
	ok, message = PvPSteal.tryBegin(A, m7)
	expect("worker on pad 7 can be stolen", ok, message)
	put(A, (plotOf(A).PrimaryPart :: BasePart).Position)
	PvPSteal._test.deliver(A)
	waitUntil(6, function()
		return WorkerInventory.getRecord(A, b7.uid) ~= nil
	end)
	task.wait(0.5)
	expect("delivered from pad 7", WorkerInventory.getRecord(A, b7.uid) ~= nil and pad(B, 7):GetAttribute("Occupied") ~= true)
	PvPSteal._test.setTeleportCheck(true)
	switches(false)
end

-- SAVE (real Studio DataStore) ----------------------------------------------------------------------------------
local saveState: any = {}
local function saveBuild()
	expect("test user", A.UserId < 0, A.UserId)
	switches(true)
	local P = PurchaseService
	saveState.realIds = { cash_s = ProductConfig.BY_KEY.cash_s.id, starter = ProductConfig.BY_KEY.starter.id }
	P._test.setId("cash_s", 9001)
	P._test.setId("starter", 9004)
	clearWorkers(A)
	setCash(A, 0)
	-- a Level 4 worker (levels show from 3 placed)
	local w = grant(A, "business_betty")
	for _ = 2, 6 do
		grant(A, "delivery_dave")
	end
	waitUntil(3, function()
		return A:GetAttribute("LevelsShown") == true and A:GetAttribute("PadUnlockShown") == true
	end)
	for _ = 1, 3 do
		setCash(A, BaseConfig.levelCost(14, w.level) or 0)
		BaseService.levelUp(A, w.uid)
	end
	expect("Business Betty at Level 4", w.level == 4, w.level)
	-- pad 7 + a worker on it
	local bought0 = BaseService._test.padsBought(A)
	local u = plotOf(A):FindFirstChild("PadUnlock") :: BasePart?
	setCash(A, A:GetAttribute("PadNextPrice") or 0)
	if u then
		put(A, u.Position)
	end
	local ok, message = BaseService.unlockPad(A)
	expect("a pad bought", ok and BaseService._test.padsBought(A) == bought0 + 1, message)
	local w7 = grant(A, "crypto_carl")
	expect("worker on the new pad", w7.loc == "station" and w7.station == 7 + bought0, w7.station)
	-- purchases (SIM receipts into the real handler, saved to the real store before PurchaseGranted)
	local function receipt(productId: number, purchaseId: string): any
		return P.processReceipt({
			PlayerId = A.UserId,
			ProductId = productId,
			PurchaseId = purchaseId,
			CurrencySpent = 25,
			CurrencyType = Enum.CurrencyType.Robux,
			PlaceIdWherePurchased = 0,
		})
	end
	expect("Cash Stack granted (real save)", receipt(9001, "T033S-r1") == Enum.ProductPurchaseDecision.PurchaseGranted, nil, true)
	expect("Starter Pack granted (real save)", receipt(9004, "T033S-s1") == Enum.ProductPurchaseDecision.PurchaseGranted and data(A).hub.starter == true, nil, true)
	saveState = { realIds = saveState.realIds, uid = w.uid, uid7 = w7.uid, station7 = w7.station, pads = BaseService._test.padsBought(A), receipt = receipt }
	task.wait(1)
	saveState.income = PassiveIncome.getIncome(A)
end

local function saveRejoin()
	local st = saveState
	PlayerData._test.leave(A)
	local stored = PlayerData.store():GetAsync("player_" .. A.UserId)
	local saved = stored and stored.data
	local lv, on7 = nil, nil
	for _, w in (saved and saved.workers or {}) do
		if w.uid == st.uid then
			lv = w.level
		elseif w.uid == st.uid7 then
			on7 = w.station
		end
	end
	expect("real save: Level 4", lv == 4, lv)
	expect("real save: worker on the bought pad", on7 == st.station7, on7)
	expect("real save: hub.pads", saved and saved.hub and saved.hub.pads == st.pads, saved and saved.hub and saved.hub.pads)
	expect(
		"real save: receipts + starter",
		saved and saved.hub and type(saved.hub.receipts) == "table" and table.find(saved.hub.receipts, "T033S-r1") ~= nil and saved.hub.starter == true
	)
	expect("real save: schema 3", saved and saved.schema == 3, saved and saved.schema)
	local plot = PlotService.getPlot(A)
	if plot then
		plot.PlacedNPCs:ClearAllChildren()
		for _, station in plot.Stations:GetChildren() do
			station:SetAttribute("Occupied", false)
		end
	end
	task.spawn(PlayerData._test.load, A)
	expect(
		"A loads again from the store",
		waitUntil(40, function()
			return PlayerData.isLoaded(A) and WorkerInventory.isReady(A)
		end)
	)
	task.wait(2)
	local w = WorkerInventory.getRecord(A, st.uid)
	expect("Level 4 came back", w and w.level == 4, w and w.level)
	local w7 = WorkerInventory.getRecord(A, st.uid7)
	expect("worker back on the bought pad", w7 and w7.loc == "station" and w7.station == st.station7 and placedModel(A, st.uid7) ~= nil, w7 and w7.station)
	expect("bought pads came back", BaseService._test.padsBought(A) == st.pads, BaseService._test.padsBought(A))
	expect("income the same after the rejoin", PassiveIncome.getIncome(A) == st.income, ("%s vs %s"):format(PassiveIncome.getIncome(A), st.income))
	local c0 = CashService.get(A)
	local d = st.receipt(9001, "T033S-r1")
	expect(
		"same receipt after the rejoin: nothing more",
		d == Enum.ProductPurchaseDecision.PurchaseGranted and CashService.get(A) - c0 < PassiveIncome.getIncome(A) * 20 + 1,
		CashService.get(A) - c0,
		true
	)
	expect("Starter Pack can't be bought again", PurchaseService.buy(A, "starter") == false and PurchaseService._test.starterShown(A) == false, nil, true)
	PurchaseService._test.setId("cash_s", st.realIds.cash_s)
	PurchaseService._test.setId("starter", st.realIds.starter)
	switches(false)
end

local function saveCleanup()
	if A.Parent then
		PlayerData._test.leave(A)
	end
	local store = PlayerData.store()
	for _, k in { "player_", "zones_", "pvpx_" } do
		pcall(store.RemoveAsync, store, k .. A.UserId)
	end
	expect("test keys removed", store:GetAsync("player_" .. A.UserId) == nil)
end

task.spawn(function()
	if mode == "save" then
		scenario("build", saveBuild)
		scenario("real final save + real load (rejoin)", saveRejoin)
		scenario("cleanup", saveCleanup)
	elseif mode == "solo" then
		scenario("off", soloOff)
		scenario("on", soloOn)
		scenario("levels", soloLevels)
		scenario("pads", soloPads)
		scenario("living", soloLiving)
		scenario("purchases", soloPurchases)
		scenario("off again", soloOffAgain)
	else
		scenario("fair", duoFair)
	end
	restore()
	finish("DONE")
end)
