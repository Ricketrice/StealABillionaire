-- Studio location: ServerScriptService.DevTest_PvP022 (Script)
-- DevTest_PvP022  (Milestone 022) -- STUDIO-ONLY multi-client test of PvP stealing, base defence and
-- bats. It does nothing unless Studio started the session with StudioTestService and an argument
-- that starts with "pvp022", so it is inert in normal Play and in live servers.
-- Sessions (StudioTestService:ExecuteMultiplayerTestAsync(clients, argument)), one at a time:
--   3 clients, "pvp022"              the main run
--   2 clients, "pvp022:thief-first"  \
--   2 clients, "pvp022:owner-first"   > one scenario each; they end with both players gone
--   2 clients, "pvp022:shutdown"     /
--   2 clients, "pvp022:crash"        a server crash at every step of a hand-over (simulated)
-- Never more than 3 clients and never StudioTestService:AddPlayers: every client is a whole Studio
-- process, and more than 3 ran the 13 GB development machine out of memory.
-- It drives real players on a local server: characters are moved by the server, and the same server
-- functions the prompts and remotes call are used. Results: "@@T022|" lines in the output and the
-- summary returned through StudioTestService:EndTest.
-- Runs on the in-memory save only (Studio API access off). Lines marked SIM are simulations.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and type(args) == "string" and args:sub(1, 6) == "pvp022") then
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
	print("@@T022|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d (of which simulated checks=%d)\n%s"):format(state, passed, failed, simulated, table.concat(lines, "\n"))
	print("@@T022|SUMMARY " .. summary:gsub("\n", " ## "))
	StudioTestService:EndTest(summary)
end
if
	game:GetService("ServerStorage"):GetAttribute("StudioMemoryStore") ~= true
	and pcall(function()
		return game:GetService("DataStoreService"):GetDataStore("__sab_probe_022"):GetAsync("probe")
	end)
then -- (027: the StudioMemoryStore attribute puts PlayerData on the in-memory store even with API access on)
	finish("ABORTED: Studio API access is on; this test only runs on the in-memory save")
	return
end

local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end
local CashService, NPCCarry, NPCPlacement, PassiveIncome = mod("CashService"), mod("NPCCarry"), mod("NPCPlacement"), mod("PassiveIncome")
local PlayerData, PlotService, PvPBase, PvPCombat, PvPSteal, WorkerInventory =
	mod("PlayerData"), mod("PlotService"), mod("PvPBase"), mod("PvPCombat"), mod("PvPSteal"), mod("WorkerInventory")
local DataStoreMock, PvPTransfer = mod("DataStoreMock"), mod("PvPTransfer")
local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig")) :: any
local INCOME = (WorkerCatalogue.getStats("broke_bob", WorkerCatalogue.LEVEL, WorkerCatalogue.TIER))
local claimed = workspace:WaitForChild("ClaimedNPCs")
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")

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
local function living(p: Player): BasePart?
	local character = p.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root then root :: BasePart else nil
end
local function ready(p: Player): boolean
	return p.Parent ~= nil and PlayerData.isLoaded(p) and PlotService.getPlot(p) ~= nil and living(p) ~= nil
end
local function plotOf(p: Player): Model
	return PlotService.getPlot(p) :: Model
end
local function record(p: Player, uid: string): any
	local data = PlayerData.get(p)
	for _, w in (data and data.workers or {}) do
		if w.uid == uid then
			return w
		end
	end
	return nil
end
local function placed(p: Player, uid: string): Model?
	for _, m in plotOf(p).PlacedNPCs:GetChildren() do
		if m:GetAttribute("WorkerUid") == uid then
			return m
		end
	end
	return nil
end
local known: { [string]: boolean } = {}
local saved: { [number]: string } = {} -- UserId -> last successfully saved JSON
PlayerData.onSaved(function(p, ok, _at, json)
	if ok then
		saved[p.UserId] = json
	end
end)
local function savedHas(userId: number, uid: string): boolean
	return saved[userId] ~= nil and saved[userId]:find(uid, 1, true) ~= nil
end
-- Whether nothing is left in a player's transfer journal.
local function journalClear(p: Player): boolean
	return PvPTransfer.isClear(PlayerData.store(), p.UserId) == true
end
local function copy(value: any): any
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end
-- Puts away whatever `p` is carrying, through the real remote, so their hands are free again.
local storeCarried: (Player) -> ()

-- A worker of `p` standing on their station `station`.
local function seed(p: Player, station: number): string
	local uid = HttpService:GenerateGUID(false)
	known[uid] = true
	assert(WorkerInventory.give(p, { uid = uid, id = "broke_bob", zone = "MainStreet", level = 1, tier = "Normal", loc = "station", station = station }), "seed: give failed")
	assert(WorkerInventory.respawn(p, uid), "seed: respawn failed")
	return uid
end
local function near(p: Player, target: BasePart, distance: number?)
	(p.Character :: Model):PivotTo(CFrame.new(target.Position + Vector3.new(0, 1, distance or 4)))
end
-- Puts the attacker within reach of the victim, facing them (a hit pushes its victim away).
local function face(attacker: Player, victim: Player, distance: number?)
	local at = (victim.Character :: Model):GetPivot().Position;
	(attacker.Character :: Model):PivotTo(CFrame.lookAt(at + Vector3.new(distance or 4, 0, 0), at))
end
-- Records the strength of every push `p` receives until the returned function is called.
local function watchPushes(p: Player): ({ number }, () -> ())
	local pushes = {}
	local connection = ((p.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart).ChildAdded:Connect(function(child)
		if child.Name == "PvPKnockback" and child:IsA("LinearVelocity") then
			table.insert(pushes, child.VectorVelocity.Magnitude)
		end
	end)
	return pushes, function()
		connection:Disconnect()
	end
end
local function steal(thief: Player, owner: Player, uid: string): (boolean, string?, Model?)
	local model = placed(owner, uid)
	if not model then
		return false, "no placed model", nil
	end
	near(thief, model:FindFirstChild("HumanoidRootPart") :: BasePart)
	local ok, message = PvPSteal.tryBegin(thief, model)
	return ok, message, model
end
-- Walks the thief home the only way a server can: by moving them (the teleport check is off for it).
local function deliverHome(thief: Player)
	PvPSteal._test.setTeleportCheck(false);
	(thief.Character :: Model):PivotTo((plotOf(thief).PrimaryPart :: BasePart).CFrame * CFrame.new(0, 3.5, 0))
	PvPSteal._test.check()
	PvPSteal._test.setTeleportCheck(true)
end
local function endThefts()
	local list = {}
	for _, theft in PvPSteal._test.thefts do
		table.insert(list, theft)
	end
	for _, theft in list do
		PvPSteal.onPlayerHit(theft.thief, theft.owner)
	end
end
-- No worker in two inventories, no two models of one worker, every station record has its model.
local function invariant()
	local holders, models = {}, {}
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		for _, w in (data and data.workers or {}) do
			holders[w.uid] = (holders[w.uid] or 0) + 1
			if w.loc == "station" and PlotService.getPlot(p) and not placed(p, w.uid) and not PvPSteal._test.thefts[w.uid] then
				expect("every worker on a station has its model", false, w.uid)
			end
		end
	end
	local function count(folder: Instance)
		for _, m in folder:GetChildren() do
			local uid = m:GetAttribute("WorkerUid")
			if uid then
				models[uid] = (models[uid] or 0) + 1
			end
		end
	end
	count(claimed)
	for _, plot in plots:GetChildren() do
		count(plot.PlacedNPCs)
	end
	for uid in known do
		expect("no worker is owned twice", (holders[uid] or 0) <= 1, uid)
		expect("no worker has two models", (models[uid] or 0) <= 1, uid)
	end
end
local function scenario(name: string, run: () -> ())
	section = name
	local ok, err = pcall(run)
	if not ok then
		failed += 1
		note("ERROR", "scenario stopped", err)
	end
	endThefts()
	PvPSteal._test.setSaver(nil)
	PvPSteal._test.setTeleportCheck(true)
	task.wait(0.2)
	invariant()
	print("@@T022|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function freeStation(p: Player): BasePart?
	for index = 1, InventoryConfig.STATION_SLOTS do
		local station = PvPBase.findStation(plotOf(p), index)
		if station and station:GetAttribute("Occupied") ~= true then
			return station
		end
	end
	return nil
end
local function unprotect()
	for _, p in Players:GetPlayers() do
		PvPBase._test.setProtection(p, nil)
	end
end
local function awaitPlayers(n: number): { Player }
	waitUntil(240, function()
		local count = 0
		for _, p in Players:GetPlayers() do
			if ready(p) then
				count += 1
			end
		end
		return count >= n
	end)
	task.wait(2)
	local list = {}
	for _, p in Players:GetPlayers() do
		if ready(p) then
			table.insert(list, p)
		end
	end
	return list
end

local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test022Bridge"
bridge.Parent = ReplicatedStorage
local spammed = {}
local probes: { [number]: any } = {}
local probeSeq = 0
bridge.OnServerEvent:Connect(function(p, kind, id, state)
	if kind == "spammed" then
		spammed[p] = true
	elseif kind == "probe" and type(id) == "number" and type(state) == "table" then
		probes[id] = state
	end
end)
-- What this player's own client is showing right now (see ClientHelper).
local NOTHING = { barrier = {}, sign = {}, plotAlarm = {}, stolenTags = 0, bannerCount = 0, answered = false }
local function probe(p: Player): any
	probeSeq += 1
	local id = probeSeq
	bridge:FireClient(p, "probe", id)
	local state = waitUntil(4, function()
		return probes[id]
	end)
	probes[id] = nil
	return state or NOTHING
end
storeCarried = function(p: Player)
	if NPCCarry.getCarried(p) then
		bridge:FireClient(p, "inv", "StoreCarried")
		waitUntil(3, function()
			return NPCCarry.getCarried(p) == nil
		end)
	end
end
local function helper(p: Player)
	-- Inside a ScreenGui that survives respawns (a respawn clears the rest of PlayerGui).
	local holder = Instance.new("ScreenGui")
	holder.Name = "Test022Helper"
	holder.ResetOnSpawn = false
	script:WaitForChild("ClientHelper"):Clone().Parent = holder
	holder.Parent = p:WaitForChild("PlayerGui")
end

local mode = args:match("^pvp022:(.+)$") or "main"
local needed = if mode == "main" then 3 else 2
local everyone = awaitPlayers(needed)
if #everyone < needed then
	finish(("ABORTED: needs %d loaded players, got %d"):format(needed, #everyone))
	return
end
for _, p in everyone do
	helper(p)
end
task.wait(1)
local setFlag = function(stealing: boolean?, combat: boolean?)
	ServerStorage:SetAttribute(PvPConfig.STUDIO_STEALING_ATTRIBUTE, stealing)
	ServerStorage:SetAttribute(PvPConfig.STUDIO_COMBAT_ATTRIBUTE, combat)
	task.wait(0.3)
end

-- A test client that has stalled (it happens when the machine is short of memory) would make every
-- check of what that player sees or sends meaningless: stop and say so instead. Only the main run
-- uses the clients; the other sessions are decided on the server alone.
for _, p in if mode == "main" then everyone else {} do
	local answered = false
	for _ = 1, 3 do
		if probe(p).answered then
			answered = true
			break
		end
	end
	if not answered then
		bridge:Destroy()
		finish(("ABORTED: the test client of %s is not answering (stalled client): run this session again"):format(p.Name))
		return
	end
end

-- The scenarios that end with both players gone: one per session (see the header).
-- A hand-over that is committed in the journal while neither player's save has been written.
local function unconfirmed(owner: Player, thief: Player): string
	local uid = seed(owner, 1)
	local release = Instance.new("BindableEvent")
	PvPSteal._test.setSaver(function()
		release.Event:Wait() -- the save never comes back
		return false
	end)
	local ok, message = steal(thief, owner, uid)
	expect("steal starts", ok, message)
	deliverHome(thief)
	expect("handed over, with neither save written yet", record(thief, uid) ~= nil and record(owner, uid) == nil and PvPSteal._test.journal[uid] ~= nil)
	return uid
end
local function leaveBoth(name: string, owner: Player, thief: Player, thiefFirst: boolean)
	scenario(name, function()
		local uid = unconfirmed(owner, thief)
		local ownerId, thiefId = owner.UserId, thief.UserId
		if thiefFirst then
			thief:Kick("test")
			owner:Kick("test")
		else
			owner:Kick("test")
			thief:Kick("test")
		end
		waitUntil(12, function()
			return PvPSteal._test.journal[uid] == nil and saved[ownerId] ~= nil and saved[thiefId] ~= nil
		end)
		task.wait(1)
		local inOwner, inThief = savedHas(ownerId, uid), savedHas(thiefId, uid)
		expect("the worker is in exactly one of the two saves", inOwner ~= inThief, ("owner=%s thief=%s"):format(tostring(inOwner), tostring(inThief)))
		expect(
			"it is the thief's (the hand-over was committed) and the journal is cleared",
			inThief and PvPTransfer.isClear(PlayerData.store(), ownerId) == true and PvPTransfer.isClear(PlayerData.store(), thiefId) == true
		)
	end)
end
local function shutdown(owner: Player, thief: Player)
	scenario("shutdown during the transfer (simulated)", function()
		local uid = unconfirmed(owner, thief)
		local ownerId, thiefId = owner.UserId, thief.UserId
		-- What BindToClose does: every player's final save, all at once.
		for _, p in { thief, owner } do
			task.spawn(PlayerData._test.leave, p)
		end
		waitUntil(12, function()
			return PvPSteal._test.journal[uid] == nil and saved[ownerId] ~= nil and saved[thiefId] ~= nil
		end)
		task.wait(1)
		local inOwner, inThief = savedHas(ownerId, uid), savedHas(thiefId, uid)
		expect("the worker is in exactly one of the two saves", inOwner ~= inThief, ("owner=%s thief=%s"):format(tostring(inOwner), tostring(inThief)), true)
		expect(
			"it is the thief's (the hand-over was committed) and the journal is cleared",
			inThief and PvPTransfer.isClear(PlayerData.store(), ownerId) == true and PvPTransfer.isClear(PlayerData.store(), thiefId) == true,
			nil,
			true
		)
	end)
end

-- Milestone 022.1: a server crash at every step of a hand-over (simulated).
-- A crash loses everything in memory and keeps exactly what is in the store. So at every step of a
-- real hand-over between the two players, the stored data (both saves and both journals) is copied;
-- then, for each copy, a fresh server is played out on it with the real load and replay code: each
-- player's data loads, the journal is replayed, their first save is written. Whatever the step and
-- whoever loads first, exactly one of them must end up with the worker.
local function crashTests(p1: Player, p2: Player)
	local store = PlayerData.store()
	local COMMITTED = { committed = true, swapped = true, ["owner saved"] = true, ["owner done"] = true, ["thief saved"] = true, applied = true, finished = true }
	local function has(data: any, uid: string): boolean
		for _, w in data.workers do
			if w.uid == uid then
				return true
			end
		end
		return false
	end
	-- This player's data loading on a fresh server, up to and including their first save
	-- (save = false: that server stops before saving anything).
	local function join(sandbox: any, userId: number, save: boolean): any
		local stored = sandbox.values["player_" .. userId]
		local data = PlayerData._sanitize(PlayerData._migrate(if stored and stored.data then copy(stored.data) else { workers = {} }))
		local ok, result = PvPTransfer.replay(sandbox, userId, {
			has = function(uid)
				return has(data, uid)
			end,
			drop = function(uid)
				for index, w in data.workers do
					if w.uid == uid then
						table.remove(data.workers, index)
						break
					end
				end
			end,
			add = function(record)
				record.loc = "inventory"
				table.insert(data.workers, record)
			end,
		})
		if not ok then
			return { workers = {}, failed = true }
		end
		if save then
			sandbox.values["player_" .. userId] = { data = copy(data) }
			PvPTransfer.afterSave(sandbox, userId, HttpService:JSONEncode(data), result.out, result.inc, math.huge)
		end
		return data
	end
	local function savedIn(sandbox: any, userId: number, uid: string): boolean
		return HttpService:JSONEncode(sandbox.values["player_" .. userId] or {}):find(uid, 1, true) ~= nil
	end

	local function transfer(owner: Player, thief: Player, station: number, firstSave: string)
		local ownerId, thiefId = owner.UserId, thief.UserId
		local keys = { "player_" .. ownerId, "player_" .. thiefId, PvPTransfer.key(ownerId), PvPTransfer.key(thiefId) }
		local uid = seed(owner, station)
		PlayerData.save(owner) -- the worker is in its owner's saved data before anything starts
		PlayerData.save(thief)
		local snapshots = {}
		PvPSteal._test.setSaveOrder(firstSave)
		PvPSteal._test.setStepHook(function(name, info)
			if info and info.uid == uid then
				local values = {}
				for _, key in keys do
					values[key] = store.values[key]
				end
				table.insert(snapshots, { step = name, id = info.id, values = copy(values) })
			end
		end)
		local ok, message = steal(thief, owner, uid)
		expect("steal starts", ok, message)
		deliverHome(thief)
		expect("the real hand-over completes and clears the journal", waitUntil(4, function()
			return PvPSteal._test.journal[uid] == nil and journalClear(owner) and journalClear(thief)
		end) and record(thief, uid) ~= nil and record(owner, uid) == nil)
		PvPSteal._test.setStepHook(nil)
		PvPSteal._test.setSaveOrder(nil)
		local names = {}
		for _, snap in snapshots do
			table.insert(names, snap.step)
		end
		expect("every step of it was captured", #snapshots == 9, table.concat(names, ", "))
		print("@@T022|steps (" .. firstSave .. "'s save first): " .. table.concat(names, " > "))

		for index, snap in snapshots do
			local expected = if COMMITTED[snap.step] then thiefId else ownerId
			local label = ("crash after step %d '%s' (%s's save first)"):format(index, snap.step, firstSave)
			for _, order in { { ownerId, thiefId }, { thiefId, ownerId } } do
				local tag = label .. (if order[1] == ownerId then ", owner loads first" else ", thief loads first")
				local sandbox = DataStoreMock.new()
				sandbox.values = copy(snap.values)
				local first = join(sandbox, order[1], true)
				expect(tag .. ": the first to load is right at once", not first.failed and has(first, uid) == (order[1] == expected), nil, true)
				local second = join(sandbox, order[2], true)
				expect(tag .. ": the second to load is right", not second.failed and has(second, uid) == (order[2] == expected), nil, true)
				local inOwner, inThief = savedIn(sandbox, ownerId, uid), savedIn(sandbox, thiefId, uid)
				expect(
					tag .. ": exactly one save has the worker",
					inOwner ~= inThief and inThief == (expected == thiefId),
					("owner=%s thief=%s"):format(tostring(inOwner), tostring(inThief)),
					true
				)
				local again1, again2 = join(sandbox, ownerId, true), join(sandbox, thiefId, true)
				expect(tag .. ": another restart changes nothing", has(again1, uid) == (expected == ownerId) and has(again2, uid) == (expected == thiefId), nil, true)
				expect(tag .. ": the journal is cleared", PvPTransfer.isClear(sandbox, ownerId) == true and PvPTransfer.isClear(sandbox, thiefId) == true, nil, true)
			end
			-- The recovering server stops too, after replaying both journals and before saving anyone.
			local sandbox = DataStoreMock.new()
			sandbox.values = copy(snap.values)
			join(sandbox, ownerId, false)
			join(sandbox, thiefId, false)
			local thiefData, ownerData = join(sandbox, thiefId, true), join(sandbox, ownerId, true)
			expect(
				label .. ": still exactly one owner after a second crash during recovery",
				has(ownerData, uid) == (expected == ownerId) and has(thiefData, uid) == (expected == thiefId),
				nil,
				true
			)
			if snap.step == "prepared" then
				-- The dead server's commit arriving late, after the owner's data has loaded elsewhere.
				expect(
					label .. ": a late commit is refused",
					PvPTransfer.commit(sandbox, thiefId, snap.id, { uid = uid, from = ownerId, record = { id = "broke_bob" }, at = os.time() }) == "voided"
						and not has(join(sandbox, thiefId, true), uid),
					nil,
					true
				)
			end
		end
	end

	scenario("crash at every step, owner's save first (simulated)", function()
		transfer(p1, p2, 1, "owner")
	end)
	scenario("crash at every step, thief's save first (simulated)", function()
		transfer(p2, p1, 1, "thief") -- roles swapped: p2 is still carrying the first worker
	end)
	scenario("journal replay on live players (simulated restart)", function()
		-- A hand-over that was committed in the journal and then cut off before anything else:
		-- both players' data "loads" again on this live server.
		local uid = seed(p1, 2)
		PlayerData.save(p1)
		PlayerData.save(p2)
		local id = HttpService:GenerateGUID(false)
		expect(
			"journal written",
			PvPTransfer.prepare(store, p1.UserId, p2.UserId, uid, id)
				and PvPTransfer.commit(
						store,
						p2.UserId,
						id,
						{ uid = uid, from = p1.UserId, record = { uid = uid, id = "broke_bob", zone = "MainStreet", level = 1, tier = "Normal" }, at = os.time() }
					)
					== "committed",
			nil,
			true
		)
		expect("before the replay the previous owner still has it in memory", record(p1, uid) ~= nil and record(p2, uid) == nil, nil, true)
		PvPSteal._test.replayNow(p1)
		expect("previous owner: the worker and its model are gone", record(p1, uid) == nil and placed(p1, uid) == nil, nil, true)
		PvPSteal._test.replayNow(p2)
		local received = record(p2, uid)
		expect("new owner: the worker is in their inventory", received ~= nil and received.loc == "inventory", nil, true)
		expect(
			"after their saves the journal is cleared",
			waitUntil(4, function()
				return PvPSteal._test.journal[uid] == nil and journalClear(p1) and journalClear(p2)
			end),
			nil,
			true
		)
		PlayerData.save(p1)
		PlayerData.save(p2)
		task.wait(0.3)
		expect("saved data: exactly one owner", savedHas(p2.UserId, uid) and not savedHas(p1.UserId, uid), nil, true)
		PvPSteal._test.replayNow(p1)
		PvPSteal._test.replayNow(p2)
		expect("replaying again changes nothing", record(p1, uid) == nil and record(p2, uid) ~= nil, nil, true)
	end)
end
if mode ~= "main" then
	local owner, thief = everyone[1], everyone[2]
	setFlag(true, true)
	unprotect()
	if mode == "thief-first" then
		leaveBoth("both leave at once, thief first", owner, thief, true)
	elseif mode == "owner-first" then
		leaveBoth("both leave at once, owner first", owner, thief, false)
	elseif mode == "shutdown" then
		shutdown(owner, thief)
	elseif mode == "crash" then
		crashTests(owner, thief)
	else
		section = "setup"
		expect("known test argument", false, args)
	end
	section = "end"
	setFlag(nil, nil)
	bridge:Destroy()
	finish("DONE " .. mode)
	return
end

local A, B, C = everyone[1], everyone[2], everyone[3]
local b1, b2, b3 = seed(B, 1), seed(B, 2), seed(B, 3)

scenario("flags off", function()
	local model = placed(B, b1) :: Model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	expect("no flags published", ReplicatedStorage:GetAttribute("PvPStealing") ~= true and ReplicatedStorage:GetAttribute("WeaponCombat") ~= true)
	expect("no steal prompt on placed workers", root:FindFirstChild("PvPStealPrompt") == nil)
	near(A, root)
	expect("steal refused", PvPSteal.tryBegin(A, model) == false)
	expect("lock refused", PvPBase.tryLock(B) == false)
	expect("bat refused", PvPCombat.equip(A) == false and PvPCombat.attack(A, "basic") == false)
	expect(
		"no PvP attributes on players or plots",
		B:GetAttribute("ProtectedUntil") == nil and plotOf(B):GetAttribute("ProtectedUntil") == nil and A:GetAttribute("PvPSpawnSafeUntil") == nil
	)
	setFlag(true, nil)
	expect("stealing flag alone: prompt appears, bats stay off", root:FindFirstChild("PvPStealPrompt") ~= nil and PvPCombat.equip(A) == false)
	setFlag(nil, true)
	expect("combat flag alone: bats work, prompts are gone", root:FindFirstChild("PvPStealPrompt") == nil and PvPCombat.equip(A) == true)
	PvPCombat.unequip(A)
	setFlag(true, true)
	local prompt = root:FindFirstChild("PvPStealPrompt") :: ProximityPrompt
	expect("prompt needs a 2 s hold", prompt ~= nil and prompt.HoldDuration == PvPConfig.Steal.HOLD)
end)

scenario("new-player protection", function()
	expect(
		"first session is protected",
		PvPBase.isProtected(B.UserId) and (B:GetAttribute("ProtectedUntil") or 0) > workspace:GetServerTimeNow() + PvPConfig.Protection.DURATION - 120
	)
	local ok, message = steal(A, B, b1)
	expect("cannot steal from a protected player", ok == false and tostring(message):find("protected") ~= nil, message)
	expect("granted once per UserId (a rejoin is not granted again)", PvPBase._test.seen[B.UserId] == true, nil, true)
	unprotect()
	PvPBase._test.setProtection(A, 300)
	local started = steal(A, B, b1)
	expect("a protected player who steals gives up protection", started and not PvPBase.isProtected(A.UserId))
end)
unprotect()

scenario("steal and deliver", function()
	local incomeA, incomeB = PassiveIncome.getIncome(A), PassiveIncome.getIncome(B)
	local ok, message, model = steal(A, B, b1)
	expect("steal starts", ok, message)
	local station = PvPBase.findStation(plotOf(B), 1) :: BasePart
	expect("thief carries the worker", NPCCarry.getCarried(A) == model and A:GetAttribute("CarryingStolen") == true)
	expect("owner still owns it", record(B, b1) ~= nil and record(A, b1) == nil)
	expect("its station is kept", station:GetAttribute("Occupied") == true and station:GetAttribute("StolenUid") == b1)
	expect("it earns nothing while carried", PassiveIncome.getIncome(B) == incomeB - INCOME, PassiveIncome.getIncome(B))
	expect("alarm shows on the plot", plotOf(B):GetAttribute("AlarmThief") == A.DisplayName)
	bridge:FireClient(B, "inv", "Store", b1) -- the owner tries to store it mid-theft, through the real remote
	task.wait(0.6)
	expect("owner cannot move it mid-theft", record(B, b1) ~= nil and record(B, b1).loc == "station")
	deliverHome(A)
	expect("delivered: thief owns it, owner does not", record(A, b1) ~= nil and record(B, b1) == nil)
	expect(
		"both saves landed and the journal is cleared",
		waitUntil(4, function()
			return PvPSteal._test.journal[b1] == nil and record(A, b1) ~= nil and journalClear(A) and journalClear(B)
		end)
	)
	expect(
		"victim's station and alarm cleared",
		station:GetAttribute("Occupied") ~= true and station:GetAttribute("StolenUid") == nil and plotOf(B):GetAttribute("AlarmThief") == nil
	)
	PlayerData.save(A)
	task.wait(0.4)
	expect("saved data: thief has it, owner does not", savedHas(A.UserId, b1) and not savedHas(B.UserId, b1))
	local free = freeStation(A) :: BasePart
	(A.Character :: Model):PivotTo(CFrame.new(free.Position + Vector3.new(0, 3, 2)))
	local placedOk, why = NPCPlacement.tryPlace(A, free)
	expect("thief places it on a station", placedOk, why)
	task.wait(0.4)
	expect("thief now earns its income", PassiveIncome.getIncome(A) == incomeA + INCOME, PassiveIncome.getIncome(A))
	expect("owner no longer earns it", PassiveIncome.getIncome(B) == incomeB - INCOME)
	local cash = CashService.get(A)
	task.wait(2.3)
	expect("thief is paid", CashService.get(A) - cash >= (incomeA + INCOME) * 2, CashService.get(A) - cash)
end)

scenario("owner tags thief", function()
	local ok, message, model = steal(A, B, b2)
	expect("steal starts", ok, message)
	expect("thief cannot take out a bat while carrying", PvPCombat.equip(A) == false)
	expect("owner equips a bat", PvPCombat.equip(B) == true and B:GetAttribute("BatEquipped") == true and (B.Character :: Model):FindFirstChild("PvPBat") ~= nil)
	local basic = PvPConfig.Attacks.basic
	local function faceA() -- B within reach of A, facing them (a hit pushes A away)
		local at = (living(A) :: BasePart).Position;
		(B.Character :: Model):PivotTo(CFrame.lookAt(at + Vector3.new(4, 0, 0), at))
	end
	faceA()
	local hits = PvPCombat.stats.hits
	expect("swing accepted", PvPCombat.attack(B, "basic") == true)
	expect("second swing inside the cooldown is ignored", PvPCombat.attack(B, "basic") == false)
	task.wait(0.4)
	expect("hit landed", PvPCombat.stats.hits == hits + 1)
	expect("worker dropped and back on its owner's station", NPCCarry.getCarried(A) == nil and placed(B, b2) ~= nil and record(B, b2).station == 2 and record(A, b2) == nil)
	expect("thief no longer flagged", A:GetAttribute("CarryingStolen") == nil and plotOf(B):GetAttribute("AlarmThief") == nil)
	expect("victim is briefly immune", PvPCombat.isImmune(A))
	PvPCombat._test.readyAt[B].basic = 0 -- skip the swing cooldown: this swing must land inside the immunity
	faceA()
	hits = PvPCombat.stats.hits
	expect("swing at an immune player is accepted", PvPCombat.attack(B, "basic") == true)
	task.wait(basic.windup + 0.15)
	expect("no second hit during immunity", PvPCombat.stats.hits == hits, PvPCombat.stats.hits - hits)
	task.wait(basic.immunity) -- immunity and cooldown are both over
	faceA()
	expect("swing after the immunity is accepted", PvPCombat.attack(B, "basic") == true)
	task.wait(basic.windup + 0.2)
	expect("hits land again once immunity ends", PvPCombat.stats.hits == hits + 1, PvPCombat.stats.hits - hits)
	-- safe zone around the spawn
	local spawn = (workspace:FindFirstChild("SpawnLocation") :: BasePart).Position
	local r = PvPConfig.Safe.SPAWN_RADIUS;
	(A.Character :: Model):PivotTo(CFrame.new(spawn + Vector3.new(r - 6, 3, 0)));
	(B.Character :: Model):PivotTo(CFrame.lookAt(spawn + Vector3.new(r - 2, 3, 0), spawn + Vector3.new(r - 6, 3, 0)))
	task.wait(1.2)
	local swung, why = PvPCombat.attack(B, "basic")
	expect("no attacking from inside the safe zone", swung == false and tostring(why):find("safe") ~= nil, why);
	(B.Character :: Model):PivotTo(CFrame.lookAt(spawn + Vector3.new(r + 2, 3, 0), spawn + Vector3.new(r - 3, 3, 0)));
	(A.Character :: Model):PivotTo(CFrame.new(spawn + Vector3.new(r - 3, 3, 0)))
	hits = PvPCombat.stats.hits
	expect("swing from outside is allowed", PvPCombat.attack(B, "basic") == true)
	task.wait(0.3)
	expect("but cannot hit someone inside the safe zone", PvPCombat.stats.hits == hits)
	PvPCombat.unequip(B)
end)

scenario("base lock", function()
	PvPConfig.Lock.DURATION, PvPConfig.Lock.COOLDOWN = 3, 3
	local started, message = steal(C, B, b2)
	expect("a steal is in progress", started, message)
	local function solid(): number
		local count = 0
		for _, d in plotOf(B):GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then
				count += 1
			end
		end
		return count
	end
	local solidBefore = solid()
	local locked, text = PvPBase.tryLock(B)
	expect("owner locks the base", locked and PvPBase.isLocked(B.UserId), text)
	expect("lock is published for the UI", (B:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow() and plotOf(B):GetAttribute("LockedUntil") ~= nil)
	expect("the steal in progress is not cancelled", NPCCarry.getCarried(C) ~= nil and PvPSteal.isStealing(C))
	local second, why = steal(A, B, b3)
	expect("new steals are blocked", second == false and tostring(why):find("locked") ~= nil, why)
	expect("the lock adds nothing solid (nobody is trapped)", solid() == solidBefore, ("%d solid parts before, %d locked"):format(solidBefore, solid()))
	deliverHome(C)
	expect("the earlier steal still delivers", record(C, b2) ~= nil and record(B, b2) == nil)
	expect("cannot lock again while locked", PvPBase.tryLock(B) == false)
	task.wait(3.2)
	expect("lock expires by itself", not PvPBase.isLocked(B.UserId))
	local again, recharge = PvPBase.tryLock(B)
	expect("cooldown before the next lock", again == false and tostring(recharge):find("recharging") ~= nil, recharge)
	task.wait(3.2)
	expect("lock available again after the cooldown", PvPBase.tryLock(B) == true)
	PvPBase._test.locks[B.UserId] = nil
	PvPBase.publish(B)
	PvPConfig.Lock.DURATION, PvPConfig.Lock.COOLDOWN = 60, 180
	waitUntil(4, function()
		return PvPSteal._test.journal[b2] == nil
	end)
	local carried = NPCCarry.getCarried(C)
	if carried then -- put C's prize away so C's hands are free again
		bridge:FireClient(C, "inv", "StoreCarried")
		waitUntil(3, function()
			return NPCCarry.getCarried(C) == nil
		end)
	end
end)

scenario("two thieves, one worker", function()
	local model = placed(B, b3) :: Model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	near(A, root, 4)
	near(C, root, -4)
	local first, m1 = PvPSteal.tryBegin(A, model)
	local second, m2 = PvPSteal.tryBegin(C, model)
	expect("exactly one thief gets it", first == true and second == false, tostring(m1) .. " / " .. tostring(m2))
	expect("only the winner carries", NPCCarry.getCarried(A) == model and NPCCarry.getCarried(C) == nil);
	-- the winner dies mid-carry
	((A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid).Health = 0
	task.wait(0.6)
	expect("thief died: worker is back with its owner", placed(B, b3) ~= nil and record(B, b3) ~= nil and record(A, b3) == nil and not PvPSteal.isStealing(A))
	expect("no stray model left behind", #claimed:GetChildren() == 0, #claimed:GetChildren())
	waitUntil(12, function()
		return living(A) ~= nil
	end)
	task.wait(1.5)
end)

scenario("thief teleports", function()
	local ok, message = steal(A, B, b3)
	expect("steal starts", ok, message)
	task.wait(0.3)
	local before = (living(A) :: BasePart).CFrame;
	(A.Character :: Model):PivotTo(before + Vector3.new(0, 0, 90))
	PvPSteal._test.check();
	(A.Character :: Model):PivotTo(before) -- straight back: 90 studs away can be over the void, which kills
	expect("teleporting drops the worker back to its owner", not PvPSteal.isStealing(A) and placed(B, b3) ~= nil and NPCCarry.getCarried(A) == nil)
end)

scenario("full inventory", function()
	local filler = {}
	local _, _, _, total = WorkerInventory.count(C)
	for _ = total + 1, InventoryConfig.INVENTORY_SLOTS + InventoryConfig.STATION_SLOTS do
		local uid = HttpService:GenerateGUID(false)
		WorkerInventory.give(C, { uid = uid, id = "broke_bob", zone = "MainStreet", level = 1, tier = "Normal", loc = "inventory" }, true)
		table.insert(filler, uid)
	end
	local ok, message = steal(C, B, b3)
	expect("blocked before it starts, with a reason", ok == false and tostring(message):find("no room") ~= nil and placed(B, b3) ~= nil, message)
	for _, uid in filler do
		WorkerInventory.take(C, uid)
	end
end)

scenario("spammed remotes", function()
	local before = { dropped = PvPBase.stats.dropped, handled = PvPBase.stats.handled }
	spammed[A] = nil
	bridge:FireClient(A, "spam", 400)
	expect(
		"the client sent its burst",
		waitUntil(8, function()
			return spammed[A]
		end)
	)
	task.wait(0.5)
	local dropped, handled = PvPBase.stats.dropped - before.dropped, PvPBase.stats.handled - before.handled
	expect("rate limit dropped the flood", dropped >= 380 and handled <= 40, ("dropped %d, handled %d"):format(dropped, handled))
	expect("nothing was stolen or broken by it", next(PvPSteal._test.thefts) == nil and record(B, b3) ~= nil)
	PvPCombat.unequip(A)
	PvPBase._test.locks[A.UserId] = nil
	PvPBase.publish(A)
	local ok, message = steal(A, B, b3)
	expect("the game still works afterwards", ok, message)
end)

scenario("store failures during the hand-over (simulated)", function()
	local store = PlayerData.store()
	local last: any = nil
	PvPSteal._test.setStepHook(function(_, info)
		last = info
	end)
	-- Makes chosen store requests fail from now on: fail(n) = the n-th request errors without being
	-- written; fail(n, true) = it is written and then reported as failed.
	local original = store.UpdateAsync
	local function fail(nth: number, afterWriting: boolean?)
		local count = 0
		store.UpdateAsync = function(self, key, transform)
			count += 1
			if count == nth then
				store.UpdateAsync = nil -- back to the real method for every later request
				if afterWriting then
					original(self, key, transform)
				end
				error("injected request failure")
			end
			return original(self, key, transform)
		end
	end

	local ok, message = steal(A, B, b3)
	expect("steal starts", ok, message, true)
	fail(1)
	deliverHome(A)
	expect(
		"the journal can't be written: nothing is handed over, the worker is back with its owner",
		record(B, b3) ~= nil and record(A, b3) == nil and placed(B, b3) ~= nil and not PvPSteal.isStealing(A),
		nil,
		true
	)
	expect("nothing is left in the journal", journalClear(A) and journalClear(B), nil, true)

	ok, message = steal(A, B, b3)
	expect("steal starts", ok, message, true)
	fail(2) -- the commit fails and is not written
	deliverHome(A)
	expect("the commit was not written: no hand-over, the worker is back with its owner", record(B, b3) ~= nil and record(A, b3) == nil and placed(B, b3) ~= nil, nil, true)
	expect(
		"that commit can never land later",
		last ~= nil and PvPTransfer.commit(store, A.UserId, last.id, { uid = b3, from = B.UserId, record = { id = "broke_bob" }, at = os.time() }) == "voided" and journalClear(A),
		nil,
		true
	)

	local b5 = seed(B, 1)
	ok, message = steal(A, B, b5)
	expect("steal starts", ok, message, true)
	fail(2, true) -- the commit is written but reported as failed
	deliverHome(A)
	expect("the commit was written although it reported a failure: the thief owns the worker, once", record(A, b5) ~= nil and record(B, b5) == nil, nil, true)
	expect(
		"and the journal is cleared after both saves",
		waitUntil(3, function()
			return PvPSteal._test.journal[b5] == nil and journalClear(A) and journalClear(B)
		end),
		nil,
		true
	)
	storeCarried(A)

	local b6 = seed(B, 2)
	ok, message = steal(A, B, b6)
	expect("steal starts", ok, message, true)
	PvPSteal._test.setSaver(function()
		return false -- neither player's data can be saved
	end)
	deliverHome(A)
	expect("saves failing after the commit: the thief still owns the worker", record(A, b6) ~= nil and record(B, b6) == nil and PvPSteal._test.journal[b6] ~= nil, nil, true)
	expect("the journal keeps the hand-over until the saves land", not journalClear(A) and not journalClear(B), nil, true)
	PvPSteal._test.setSaver(nil)
	PlayerData.save(B)
	PlayerData.save(A)
	expect(
		"once both saves land the journal is cleared",
		waitUntil(3, function()
			return PvPSteal._test.journal[b6] == nil and journalClear(A) and journalClear(B)
		end),
		nil,
		true
	)
	expect("saved data: the thief has it, the owner does not", savedHas(A.UserId, b6) and not savedHas(B.UserId, b6), nil, true)
	storeCarried(A)
	PvPSteal._test.setStepHook(nil)
end)

-- Phase 2 ---------------------------------------------------------------------------------------------
local basic, charged, stats = PvPConfig.Attacks.basic, PvPConfig.Attacks.charged, PvPCombat.stats
local function onBase(p: Player, x: number, z: number) -- somewhere on B's base (outside every safe zone)
	(p.Character :: Model):PivotTo((plotOf(B).PrimaryPart :: BasePart).CFrame * CFrame.new(x, 3.5, z))
end

scenario("charged swing", function()
	onBase(B, 0, 0)
	task.wait(1.3) -- earlier immunities are over
	expect("bat out", PvPCombat.equip(A) == true)
	local pushes, stopWatching = watchPushes(B)
	local hits, chargedSwings = stats.hits, stats.charged
	face(A, B)
	expect("charge starts and is published", PvPCombat.chargeStart(A) == true and type(A:GetAttribute("BatCharging")) == "number")
	expect("no second charge on top of it", PvPCombat.chargeStart(A) == false)
	expect("no ordinary swing while charging", PvPCombat.attack(A, "basic") == false)
	task.wait(0.2)
	local swung, _, kind = PvPCombat.chargeRelease(A)
	expect("let go early: a basic swing", swung == true and kind == "basic" and A:GetAttribute("BatCharging") == nil, kind)
	task.wait(basic.windup + 0.2)
	expect("basic hit landed", stats.hits == hits + 1 and stats.charged == chargedSwings, stats.hits - hits)
	task.wait(basic.immunity + 0.1)
	face(A, B)
	expect("charge again", PvPCombat.chargeStart(A) == true)
	task.wait(charged.chargeTime + 0.1)
	swung, _, kind = PvPCombat.chargeRelease(A)
	expect("held long enough: a charged swing", swung == true and kind == "charged", kind)
	task.wait(charged.windup + 0.2)
	expect("charged hit landed", stats.hits == hits + 2 and stats.charged == chargedSwings + 1, stats.hits - hits)
	expect("charged pushes harder than basic", #pushes == 2 and pushes[2] > pushes[1] * 1.3, table.concat(pushes, " / "))
	expect("charged has the longer cooldown", (PvPCombat._test.readyAt[A].charged or 0) - os.clock() > basic.cooldown)
	stopWatching()
	task.wait(charged.immunity + 0.1)
	PvPCombat._test.readyAt[A].charged = os.clock() + 5 -- still cooling down, whatever the timing
	face(A, B)
	PvPCombat.chargeStart(A)
	task.wait(charged.chargeTime + 0.1)
	swung, _, kind = PvPCombat.chargeRelease(A)
	expect("charged still cooling down: only a basic swing comes out", swung == true and kind == "basic", kind)
	PvPCombat._test.readyAt[A].charged = 0
	-- interruptible
	task.wait(basic.immunity + 0.3)
	expect("C's bat out", PvPCombat.equip(C) == true)
	expect("charge", PvPCombat.chargeStart(A) == true)
	face(C, A)
	local interrupted = stats.interrupted
	expect("someone swings at the charging player", PvPCombat.attack(C, "basic") == true)
	task.wait(basic.windup + 0.2)
	expect("a hit interrupts the charge", stats.interrupted == interrupted + 1 and not PvPCombat.isCharging(A) and A:GetAttribute("BatCharging") == nil)
	expect("nothing is left to release", PvPCombat.chargeRelease(A) == false)
	expect("an interrupted charge needs a moment before the next charged swing", (PvPCombat._test.readyAt[A].charged or 0) > os.clock())
	-- held too long
	charged.maxCharge = 0.5
	task.wait(0.2)
	expect("charge", PvPCombat.chargeStart(A) == true)
	task.wait(0.8)
	expect("a charge held too long fizzles", not PvPCombat.isCharging(A) and A:GetAttribute("BatCharging") == nil)
	charged.maxCharge = 3
	PvPCombat.unequip(A)
	PvPCombat.unequip(C)
end)

scenario("special attacks", function()
	local shock, burst = PvPConfig.Specials.shockwave, PvPConfig.Specials.burst
	local function around(dxB: number, dxC: number) -- B and C at these offsets along X from A
		local at = (A.Character :: Model):GetPivot().Position;
		(A.Character :: Model):PivotTo(CFrame.lookAt(at, at + Vector3.new(1, 0, 0)));
		(B.Character :: Model):PivotTo(CFrame.new(at + Vector3.new(dxB, 0, 0)));
		(C.Character :: Model):PivotTo(CFrame.new(at + Vector3.new(dxC, 0, 0)))
	end
	onBase(A, 0, 0)
	task.wait(1.3)
	expect(
		"bat out, default special is the shockwave",
		PvPCombat.equip(A) == true and select(2, PvPCombat.getLoadout(A)) == "shockwave" and A:GetAttribute("BatSpecial") == "shockwave"
	)
	around(6, -6)
	local hits = stats.hits
	expect(
		"special starts and its cooldown is published",
		PvPCombat.special(A) == true and (A:GetAttribute("SpecialReadyAt") or 0) > workspace:GetServerTimeNow() + shock.cooldown - 1
	)
	expect("no second special and no swing during the warning", PvPCombat.special(A) == false and PvPCombat.attack(A, "basic") == false)
	task.wait(shock.telegraph * 0.5)
	expect("nothing lands during the warning", stats.hits == hits)
	task.wait(shock.telegraph * 0.5 + 0.25)
	expect("the shockwave pushes everyone around", stats.hits == hits + 2, stats.hits - hits)
	expect("its victims are immune afterwards (no stun-lock)", PvPCombat.isImmune(B) and PvPCombat.isImmune(C) and shock.immunity > shock.duration)
	expect("on cooldown", PvPCombat.special(A) == false)
	expect("choose Burst Push", PvPCombat.setLoadout(A, "special", "burst") == true and A:GetAttribute("BatSpecial") == "burst")
	expect("switching specials does not reset the cooldown", PvPCombat.special(A) == false)
	expect(
		"unknown specials are refused",
		PvPCombat.setLoadout(A, "special", "nuke") == false and PvPCombat.setLoadout(A, "special", 5) == false and A:GetAttribute("BatSpecial") == "burst"
	)
	PvPCombat._test.readyAt[A].special = 0
	task.wait(shock.immunity + 0.1)
	around(10, -6) -- B in front, C behind
	hits = stats.hits
	expect("burst push starts", PvPCombat.special(A) == true)
	task.wait(burst.telegraph + 0.25)
	expect("the burst push only reaches who is in front", stats.hits == hits + 1 and PvPCombat.isImmune(B) and not PvPCombat.isImmune(C), stats.hits - hits)
	PvPCombat._test.readyAt[A].special = 0
	task.wait(burst.immunity + 0.1)
	around(6, -6)
	hits = stats.hits
	expect("special starts", PvPCombat.special(A) == true)
	PvPCombat.unequip(A)
	task.wait(burst.telegraph + 0.25)
	expect("putting the bat away during the warning cancels it", stats.hits == hits)
	PvPCombat.setLoadout(A, "special", "shockwave")
end)

scenario("weapon locker", function()
	onBase(B, 0, 0)
	onBase(C, 4, 0)
	onBase(A, -14, 14) -- out of reach
	task.wait(1.3)
	expect("everyone starts with the Starter bat", (PvPCombat.getLoadout(B)) == "Starter" and PvPCombat.equip(B) == true)
	local bat = (B.Character :: Model):FindFirstChild("PvPBat")
	expect("the bat in hand has the Starter look", bat ~= nil and bat:GetAttribute("Skin") == "Starter")
	expect("choose Golden", PvPCombat.setLoadout(B, "skin", "Golden") == true and B:GetAttribute("BatSkin") == "Golden")
	bat = (B.Character :: Model):FindFirstChild("PvPBat")
	expect("the bat in hand changes at once", bat ~= nil and bat:GetAttribute("Skin") == "Golden" and PvPCombat.isEquipped(B))
	expect(
		"unknown looks are refused",
		PvPCombat.setLoadout(B, "skin", "Diamond") == false and PvPCombat.setLoadout(B, "skin", { "Golden" }) == false and B:GetAttribute("BatSkin") == "Golden"
	)
	local pushes, stopWatching = watchPushes(C)
	face(B, C)
	PvPCombat.attack(B, "basic")
	task.wait(basic.windup + 0.2)
	PvPCombat.setLoadout(B, "skin", "Starter")
	PvPCombat._test.readyAt[B].basic = 0
	task.wait(basic.immunity + 0.1)
	face(B, C)
	PvPCombat.attack(B, "basic")
	task.wait(basic.windup + 0.2)
	stopWatching()
	expect("a Golden bat hits exactly as hard as a Starter bat", #pushes == 2 and math.abs(pushes[1] - pushes[2]) < 0.01, table.concat(pushes, " / "))
	bridge:FireClient(B, "loadout", "skin", "Neon") -- the request the locker sends, through the real remote
	expect(
		"the locker's request reaches the server",
		waitUntil(3, function()
			return B:GetAttribute("BatSkin") == "Neon"
		end)
	)
	task.wait(0.5)
	local seen = probe(B)
	expect(
		"the locker on that player's screen shows the choice",
		seen.lockerSkin == "Neon" and seen.lockerSpecial == "shockwave" and seen.lockerCards == 5,
		("%s / %s / %s cards"):format(tostring(seen.lockerSkin), tostring(seen.lockerSpecial), tostring(seen.lockerCards))
	)
	PvPCombat.unequip(B)
	expect(
		"the look is kept when the bat is put away and taken out again",
		PvPCombat.equip(B) == true and ((B.Character :: Model):FindFirstChild("PvPBat") :: Instance):GetAttribute("Skin") == "Neon"
	)
	PvPCombat.unequip(B)
end)

scenario("third-party hit", function()
	onBase(B, -14, -14) -- the owner stays out of it
	task.wait(1.3)
	local ok, message = steal(A, B, b3)
	expect("steal starts", ok, message)
	expect("a bystander takes out a bat", PvPCombat.equip(C) == true)
	face(C, A)
	expect("the bystander swings at the thief", PvPCombat.attack(C, "basic") == true)
	task.wait(basic.windup + 0.25)
	expect("a bystander's hit sends the worker home too", not PvPSteal.isStealing(A) and placed(B, b3) ~= nil and record(B, b3) ~= nil and record(A, b3) == nil)
	PvPCombat.unequip(C)
end)

scenario("escape rules", function()
	task.wait(1.1)
	local ok, message = steal(A, B, b3)
	expect("steal starts", ok, message)
	expect("the thief is flagged with the worker's name", A:GetAttribute("CarryingStolen") == true and type(A:GetAttribute("StolenWorker")) == "string")
	local humanoid = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local speed, jump = humanoid.WalkSpeed, humanoid.JumpHeight
	humanoid.WalkSpeed, humanoid.JumpHeight = speed + 20, jump + 30
	PvPSteal._test.check()
	expect(
		"speed and jump boosts are undone",
		math.abs(humanoid.WalkSpeed - speed) < 0.05 and math.abs(humanoid.JumpHeight - jump) < 0.05,
		("%.1f / %.1f"):format(humanoid.WalkSpeed, humanoid.JumpHeight)
	)
	PvPConfig.Steal.SAFE_ZONE_LIMIT = 0.6
	local spawn = (workspace:FindFirstChild("SpawnLocation") :: BasePart).Position
	task.wait(0.4)
	PvPSteal._test.setTeleportCheck(false);
	(A.Character :: Model):PivotTo(CFrame.new(spawn + Vector3.new(8, 4, 0)))
	PvPSteal._test.check()
	expect("crossing a safe zone is allowed", PvPSteal.isStealing(A))
	local dropped = waitUntil(3, function()
		return not PvPSteal.isStealing(A)
	end)
	local theft = PvPSteal._test.thefts[b3]
	expect(
		"waiting in a safe zone sends the worker home",
		dropped and placed(B, b3) ~= nil and record(B, b3) ~= nil,
		("thief %.0f studs from the spawn, counted %.2f s there"):format(((A.Character :: Model):GetPivot().Position - spawn).Magnitude, if theft then theft.safeTime else -1)
	)
	PvPSteal._test.setTeleportCheck(true)
	PvPConfig.Steal.SAFE_ZONE_LIMIT = 6
	PvPConfig.Steal.MAX_CARRY = 0.8
	ok, message = steal(A, B, b3)
	expect("steal starts", ok, message)
	expect("a stolen worker goes home when the carry takes too long", waitUntil(3, function()
		return not PvPSteal.isStealing(A)
	end) and placed(B, b3) ~= nil and record(B, b3) ~= nil and record(A, b3) == nil)
	PvPConfig.Steal.MAX_CARRY = 90
	expect("the thief's flag is cleared", A:GetAttribute("CarryingStolen") == nil and A:GetAttribute("StolenWorker") == nil)
end)

scenario("spawn camping", function()
	PvPCombat.unequip(C);
	((C.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid).Health = 0
	expect(
		"a fresh spawn is marked safe",
		waitUntil(12, function()
			return living(C) ~= nil and PvPBase.spawnSafe(C)
		end)
	)
	task.wait(0.5)
	onBase(C, 10, 10)
	onBase(B, -14, -14) -- out of reach: only C is in front of the bat
	expect("bat out", PvPCombat.equip(A) == true)
	face(A, C)
	local hits = stats.hits
	expect("someone swings at the fresh spawn", PvPCombat.attack(A, "basic") == true)
	task.wait(basic.windup + 0.2)
	expect("a fresh spawn can't be hit, even outside the safe zone", stats.hits == hits and PvPBase.spawnSafe(C) and not PvPCombat.isImmune(C), stats.hits - hits)
	expect("the fresh spawn takes out a bat", PvPCombat.equip(C) == true)
	face(C, A)
	expect("and attacks", PvPCombat.attack(C, "basic") == true)
	expect("attacking gives up the spawn safety", not PvPBase.spawnSafe(C))
	task.wait(basic.windup + 0.2)
	PvPCombat._test.readyAt[A].basic = 0
	face(A, C)
	hits = stats.hits
	expect("swing again", PvPCombat.attack(A, "basic") == true)
	task.wait(basic.windup + 0.2)
	expect("now they can be hit", stats.hits == hits + 1, stats.hits - hits)
	PvPCombat.unequip(A)
	PvPCombat.unequip(C)
end)

scenario("what the players see", function()
	local plotName = plotOf(B).Name
	local b4 = seed(B, 1)
	task.wait(1.3)
	local first = probe(B)
	expect("the clients answer", first.answered == true and probe(A).answered == true and probe(C).answered == true)
	local ok, message, model = steal(A, B, b4)
	expect("steal starts", ok, message)
	local worker = plotOf(B):GetAttribute("AlarmWorker")
	task.wait(0.9)
	local a, b, c = probe(A), probe(B), probe(C)
	expect(
		"the owner's screen shows the alarm with the thief and the worker",
		type(b.alarm) == "string" and type(worker) == "string" and b.alarm:find(A.DisplayName, 1, true) ~= nil and b.alarm:find(worker, 1, true) ~= nil,
		b.alarm
	)
	expect(
		"everyone sees the alarm on the base",
		c.plotAlarm[plotName] == true and type(c.sign[plotName]) == "string" and c.sign[plotName]:find("ROBBERY", 1, true) ~= nil,
		c.sign[plotName]
	)
	expect("the thief's screen shows the STOLEN bar", type(a.stolen) == "string" and b.stolen == nil and c.stolen == nil, a.stolen)
	expect("others see the STOLEN tag on the thief", c.stolenTags == 1 and b.stolenTags == 1, c.stolenTags)
	expect("the lock button is a request to the server", PvPBase.tryLock(B) == true)
	task.wait(0.9)
	c = probe(C)
	expect(
		"a locked base shows its barrier and countdown to everyone",
		c.barrier[plotName] == "lock" and type(c.sign[plotName]) == "string" and c.sign[plotName]:find("LOCKED", 1, true) ~= nil,
		c.sign[plotName]
	)
	expect("the barrier is not solid", NPCCarry.getCarried(A) == model and PvPSteal.isStealing(A))
	expect("owner's bat out", PvPCombat.equip(B) == true)
	face(B, A)
	PvPCombat.attack(B, "basic")
	task.wait(basic.windup + 0.9)
	a, b, c = probe(A), probe(B), probe(C)
	expect("DEFENDED banner on the owner's screen", b.banner == "DEFENDED!" and b.bannerCount > first.bannerCount, b.banner)
	expect("the alarm and the STOLEN displays clear when the worker is recovered", b.alarm == nil and a.stolen == nil and c.plotAlarm[plotName] == nil and c.stolenTags == 0)
	PvPCombat.unequip(B)
	PvPBase._test.locks[B.UserId] = nil
	PvPBase.publish(B)
	task.wait(0.4)
	ok, message = steal(A, B, b4)
	expect("steal starts", ok, message)
	deliverHome(A)
	task.wait(0.9)
	a, b, c = probe(A), probe(B), probe(C)
	expect("STEAL SUCCESSFUL banner on the thief's screen", a.banner == "STEAL SUCCESSFUL", a.banner)
	expect("the alarm clears on delivery and the lock barrier is gone", b.alarm == nil and c.plotAlarm[plotName] == nil and c.barrier[plotName] == nil)
	PvPBase._test.setProtection(B, 120)
	task.wait(0.9)
	c = probe(C)
	expect(
		"a protected base shows its barrier and countdown",
		c.barrier[plotName] == "shield" and type(c.sign[plotName]) == "string" and c.sign[plotName]:find("PROTECTED", 1, true) ~= nil,
		c.sign[plotName]
	)
	PvPBase._test.setProtection(B, nil)
	waitUntil(4, function()
		return PvPSteal._test.journal[b4] == nil
	end)
	if NPCCarry.getCarried(A) then -- put A's prize away so A's hands are free again
		bridge:FireClient(A, "inv", "StoreCarried")
		waitUntil(3, function()
			return NPCCarry.getCarried(A) == nil
		end)
	end
end)

scenario("thief leaves mid-carry", function()
	local ok, message = steal(C, B, b3)
	expect("steal starts", ok, message)
	C:Kick("test: thief leaves")
	expect("worker is back with its owner", waitUntil(5, function()
		return placed(B, b3) ~= nil and next(PvPSteal._test.thefts) == nil
	end) and record(B, b3) ~= nil)
	task.wait(1)
	expect("the thief's save does not contain it", not savedHas(C.UserId, b3))
end)

scenario("owner leaves mid-theft", function()
	local ok, message = steal(A, B, b3)
	expect("steal starts", ok, message)
	local userId = B.UserId
	B:Kick("test: owner leaves")
	expect("the steal is cancelled and the thief's hands are empty", waitUntil(5, function()
		return next(PvPSteal._test.thefts) == nil and NPCCarry.getCarried(A) == nil
	end) and record(A, b3) == nil)
	task.wait(1.5)
	expect("the owner's saved data still has the worker", savedHas(userId, b3))
	expect("leaving mid-robbery costs the lock cooldown", PvPBase._test.locks[userId] ~= nil and PvPBase._test.locks[userId].cooldownUntil > workspace:GetServerTimeNow())
	expect("rejoin would restore it from that save (no real rejoin possible here)", savedHas(userId, b3) and not savedHas(A.UserId, b3), nil, true)
end)

section = "end"
setFlag(nil, nil)
expect(
	"flags back off: prompts removed",
	(function()
		for _, d in plots:GetDescendants() do
			if d.Name == "PvPStealPrompt" then
				return false
			end
		end
		return true
	end)()
)
expect(
	"flags back off: bat choices and timers are no longer published",
	A:GetAttribute("BatSkin") == nil and A:GetAttribute("BatSpecial") == nil and A:GetAttribute("SpecialReadyAt") == nil and A:GetAttribute("BatCharging") == nil
)
bridge:Destroy()
finish("DONE")
