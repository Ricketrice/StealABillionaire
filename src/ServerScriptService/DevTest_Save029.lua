-- Studio location: ServerScriptService.DevTest_Save029 (Script)
-- DevTest_Save029  (Milestone 029) -- STUDIO-ONLY save tests on the REAL Studio DataStore (Studio API
-- access on, ServerStorage StudioMemoryStore NOT set). Inert unless Studio started the session with
-- StudioTestService and one of these arguments (2 clients; the players are the test users -1 and -2,
-- never the Studio user, so nobody's own save is touched):
--   "save029:parade"   parade workers survive a real final save + a real load (the 027 "steal" method:
--                      PlayerData's own leave and load, against the real store, on this server)
--   "save029:rewards"  daily streak, playtime gifts, offline earnings, index claims, settings and
--                      favourites survive a real final save + load and can't be claimed twice
-- The test keys (player_/zones_/pvpx_ of -1 and -2) are removed at the end.
-- Results: "@@T029S|" lines; the last one starts with "@@T029S|SUMMARY".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
local mode = if okArgs and type(args) == "string" and args:sub(1, 8) == "save029:" then args:sub(9) else nil
if mode ~= "parade" and mode ~= "rewards" then
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
	local line = ("%s | %s %s: %s | %s"):format(kind, mode, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T029S|" .. line)
end
local function finish(state: string)
	local summary = ("%s mode=%s passed=%d failed=%d (simulated checks=%d)"):format(state, mode, passed, failed, simulated)
	print("@@T029S|SUMMARY " .. summary)
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
	print("@@T029S|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

local PlayerData, PlotService, WorkerInventory, CashService, NPCCarry = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory"), mod("CashService"), mod("NPCCarry")

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
if ServerStorage:GetAttribute("StudioMemoryStore") == true or not PlayerData.isPersistent() then
	finish("ABORTED: needs the real Studio DataStore (API access on, StudioMemoryStore not set)")
	return
end
local A, B = Players:GetPlayerByUserId(-1), Players:GetPlayerByUserId(-2)
if not (A and B and ready(A) and ready(B)) then
	finish("ABORTED: needs the loaded test players -1 and -2")
	return
end

local function record(p: Player, uid: string): any
	for _, w in ((PlayerData.get(p) :: any) or { workers = {} }).workers do
		if w.uid == uid then
			return w
		end
	end
	return nil
end
local function raw(userId: number): any
	local stored = PlayerData.store():GetAsync("player_" .. userId)
	return stored and stored.data
end
local function storedWorker(data: any, uid: string): any
	for _, w in (data and data.workers or {}) do
		if w.uid == uid then
			return w
		end
	end
	return nil
end
-- A real final save (PlayerData's own leave), then a real load of the same user from the store.
local function rejoin(p: Player): boolean
	PlayerData._test.leave(p)
	task.spawn(PlayerData._test.load, p)
	return waitUntil(40, function()
		return PlayerData.isLoaded(p) and PlayerData.get(p) ~= nil and WorkerInventory.isReady(p)
	end) ~= nil
end
local function cleanup()
	scenario("cleanup", function()
		for _, p in { A, B } do
			if p.Parent then
				PlayerData._test.leave(p) -- releases the lock so the keys can go
			end
		end
		local store = PlayerData.store()
		for _, id in { -1, -2 } do
			for _, k in { "player_", "zones_", "pvpx_" } do
				pcall(store.RemoveAsync, store, k .. id)
			end
		end
		expect("test keys removed", store:GetAsync("player_-1") == nil and store:GetAsync("player_-2") == nil)
	end)
end

-- Parade ---------------------------------------------------------------------------------------------
if mode == "parade" then
	local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig")) :: any
	local ParadeService = mod("ParadeService")
	ServerStorage:SetAttribute(ParadeConfig.STUDIO_ATTRIBUTES.PARADE_ENABLED, true)
	ServerStorage:SetAttribute(ParadeConfig.STUDIO_ATTRIBUTES.BOOK_ENABLED, true)
	local function walkers(): Folder?
		local f = workspace:FindFirstChild("Parade")
		return f and f:FindFirstChild("Walkers") :: Folder?
	end
	local function freshWalker(): Model?
		return waitUntil(20, function()
			local f = walkers()
			if not f then
				return nil
			end
			local lane = ParadeService._test.lane()
			local best, bestD = nil, math.huge
			for _, w in f:GetChildren() do
				local along = (ParadeService.position(w) - lane.start):Dot(lane.dir)
				local d = math.abs(along - lane.length * 0.35)
				if w:GetAttribute("Claimed") ~= true and d < bestD then
					best, bestD = w, d
				end
			end
			return best
		end)
	end
	-- Catches a walker for `p` the way the Catch request does; returns the new worker's uid once carried.
	local function catch(p: Player): (string?, string?)
		local w = freshWalker()
		if not w then
			return nil, "no walker"
		end
		local lane = ParadeService._test.lane()
		local root = (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		root.AssemblyLinearVelocity = Vector3.zero;
		(p.Character :: Model):PivotTo(CFrame.new(ParadeService.position(w) + lane.side * 3 + Vector3.new(0, 0.5, 0)))
		local ok, message = ParadeService.tryCatch(p, w)
		if not ok then
			return nil, message
		end
		local uid = waitUntil(8, function()
			local npc = NPCCarry.getCarried(p)
			return npc and npc:GetAttribute("WorkerUid")
		end)
		return uid, if uid then nil else "never carried"
	end
	-- What the inventory's Store button does with a carried worker.
	local function putAway(p: Player, uid: string)
		local npc = NPCCarry.detach(p)
		if npc then
			npc:Destroy()
		end
		WorkerInventory.putAway(p, uid)
	end

	local want = {} :: any
	scenario("catch at the parade", function()
		waitUntil(20, function()
			return walkers() and #(walkers() :: Folder):GetChildren() > 0
		end)
		expect("the parade is running", walkers() ~= nil and #(walkers() :: Folder):GetChildren() > 0)
		local freeBefore = ParadeService.isFree(A)
		CashService.add(A, 500)
		local cashBefore = CashService.get(A)
		local u1, why1 = catch(A)
		expect("A catches a first parade worker", u1 ~= nil, why1)
		expect(
			"it cost nothing if it was A's first worker, else the price",
			CashService.get(A) == cashBefore - (if freeBefore then 0 else ParadeConfig.CATCH_PRICE),
			("%d -> %d, free=%s"):format(cashBefore, CashService.get(A), tostring(freeBefore))
		)
		putAway(A, u1 :: string)
		expect("A's first worker is in storage", record(A, u1 :: string) and record(A, u1 :: string).loc == "inventory")
		task.wait(ParadeConfig.CATCH_COOLDOWN + 0.2)
		local u2, why2 = catch(A)
		expect("A catches a second (paid) one and keeps carrying it", u2 ~= nil and record(A, u2 :: string).loc == "carried", why2)
		CashService.add(B, 500)
		local u3, why3 = catch(B)
		expect("B catches one", u3 ~= nil, why3)
		-- B puts theirs on station 1, the way placing it does.
		if u3 then
			local npc = NPCCarry.detach(B)
			if npc then
				npc:Destroy()
			end
			local rec = WorkerInventory.take(B, u3)
			rec.loc, rec.station = "station", 1
			expect("B's parade worker stands on station 1", WorkerInventory.give(B, rec) and WorkerInventory.respawn(B, u3) ~= nil)
		end
		want.A = { u1 = u1, u2 = u2, id1 = u1 and record(A, u1).id, id2 = u2 and record(A, u2).id, cash = CashService.get(A) }
		want.B = { u3 = u3, id3 = u3 and record(B, u3).id }
		local hubA = (PlayerData.get(A) :: any).hub
		expect("A's book has both workers", type(hubA.book) == "table" and hubA.book[want.A.id1] == true and hubA.book[want.A.id2] == true, HttpService:JSONEncode(hubA.book or {}))
		expect("A's free catch is used up", hubA.paradeFree == true or not ParadeConfig.FIRST_CATCH_FREE)
	end)

	scenario("real final save", function()
		PlayerData._test.leave(A)
		PlayerData._test.leave(B)
		local sa, sb = raw(-1), raw(-2)
		expect("A's save has the stored parade worker", storedWorker(sa, want.A.u1) ~= nil and storedWorker(sa, want.A.u1).loc == "inventory")
		expect("A's save has the carried one, saved as stored", storedWorker(sa, want.A.u2) ~= nil and storedWorker(sa, want.A.u2).loc == "inventory")
		expect(
			"A's save has the book and the used free catch",
			sa and sa.hub and sa.hub.book and sa.hub.book[want.A.id1] == true and sa.hub.paradeFree == true,
			sa and HttpService:JSONEncode(sa.hub)
		)
		expect("A's save has the cash", sa and sa.cash == want.A.cash, sa and sa.cash)
		expect("B's save has the parade worker on station 1", storedWorker(sb, want.B.u3) ~= nil and storedWorker(sb, want.B.u3).station == 1)
		expect("schema is still 3", sa and sa.schema == 3 and sb and sb.schema == 3)
	end)

	scenario("real load (rejoin)", function()
		task.spawn(PlayerData._test.load, A)
		task.spawn(PlayerData._test.load, B)
		expect(
			"both load again from the store",
			waitUntil(40, function()
				return PlayerData.isLoaded(A) and PlayerData.isLoaded(B) and WorkerInventory.isReady(A) and WorkerInventory.isReady(B)
			end)
		)
		local r1, r2, r3 = record(A, want.A.u1), record(A, want.A.u2), record(B, want.B.u3)
		expect("A still owns both parade workers, same ids", r1 and r2 and r1.id == want.A.id1 and r2.id == want.A.id2)
		expect("both are in A's storage", r1 and r2 and r1.loc == "inventory" and r2.loc == "inventory")
		expect("B's worker is back on station 1", r3 and r3.loc == "station" and r3.station == 1 and r3.id == want.B.id3)
		local placed = false
		for _, m in PlotService.getPlot(B).PlacedNPCs:GetChildren() do
			placed = placed or m:GetAttribute("WorkerUid") == want.B.u3
		end
		expect("B's worker model stands on the lot again", placed)
		local hubA = (PlayerData.get(A) :: any).hub
		expect("A's book came back", hubA.book and hubA.book[want.A.id1] == true and hubA.book[want.A.id2] == true)
		expect("A's next catch is not free", not ParadeService.isFree(A))
		expect("A's cash came back", CashService.get(A) >= want.A.cash, ("%d vs %d"):format(CashService.get(A), want.A.cash))
	end)
	cleanup()
	finish("COMPLETE")
	return
end

-- Rewards (filled in with the 029 rewards; see RewardsService._test) ----------------------------------
local ok, RewardsService = pcall(mod, "RewardsService")
if not ok then
	finish("ABORTED: RewardsService not found")
	return
end
local runRewards = require(script:WaitForChild("Rewards")) :: any
runRewards({
	A = A,
	B = B,
	expect = expect,
	scenario = scenario,
	waitUntil = waitUntil,
	note = note,
	rejoin = rejoin,
	raw = raw,
	record = record,
	RewardsService = RewardsService,
	mod = mod,
})
cleanup()
finish("COMPLETE")
