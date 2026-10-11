-- Studio location: ServerScriptService.DevTest_Parade028 (Script)
-- DevTest_Parade028  (Milestone 028) -- STUDIO-ONLY two-player test of the Worker Parade, Golden
-- Parade, juice/goal/book clients and their flags. It does nothing unless Studio started the session
-- with StudioTestService and the argument "parade028" (2 clients), so it is inert in normal Play and
-- in live servers. Results: "@@T028|" lines in the output. Runs on the in-memory save only
-- (ServerStorage StudioMemoryStore = true, or Studio API access off). Lines marked SIM are simulations.
-- The clients walk to walkers themselves and send the same ParadeAction "Catch" the Catch prompt sends.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and type(args) == "string" and args:sub(1, 9) == "parade028") then
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
	print("@@T028|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d (of which simulated checks=%d)"):format(state, passed, failed, simulated)
	print("@@T028|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end
if
	ServerStorage:GetAttribute("StudioMemoryStore") ~= true
	and pcall(function()
		return game:GetService("DataStoreService"):GetDataStore("__sab_probe_028"):GetAsync("probe")
	end)
then
	finish("ABORTED: Studio API access is on and StudioMemoryStore is not set; this test only runs on the in-memory save")
	return
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end
local CashService, PlayerData, PlotService, WorkerInventory = mod("CashService"), mod("PlayerData"), mod("PlotService"), mod("WorkerInventory")
local ParadeService, NPCCarry = mod("ParadeService"), mod("NPCCarry")
local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

local function expect(name: string, condition: any, detail: any?, sim: boolean?)
	if sim then
		simulated += 1
	end
	if condition then
		passed += 1
		note(if sim then "pass(SIM)" else "pass", name, detail)
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
	print("@@T028|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function ready(p: Player): boolean
	local character = p.Character
	return p.Parent ~= nil
		and PlayerData.isLoaded(p)
		and PlotService.getPlot(p) ~= nil
		and character ~= nil
		and character:FindFirstChild("HumanoidRootPart") ~= nil
		and WorkerInventory.isReady(p)
end
local saved: { [number]: string } = {}
PlayerData.onSaved(function(p, ok, _at, json)
	if ok then
		saved[p.UserId] = json
	end
end)
local function setFlags(on: boolean?)
	for _, attribute in ParadeConfig.STUDIO_ATTRIBUTES do
		ServerStorage:SetAttribute(attribute, on)
	end
	task.wait(0.6)
end
local walkers = function(): Folder?
	local p = workspace:FindFirstChild("Parade")
	return p and p:FindFirstChild("Walkers") :: Folder?
end
local function uids(p: Player): { [string]: boolean }
	local set = {}
	for _, w in (PlayerData.get(p) :: any).workers do
		set[w.uid] = true
	end
	return set
end
local function total(p: Player): number
	return #(PlayerData.get(p) :: any).workers
end
local function carriedUid(p: Player): string?
	local npc = NPCCarry.getCarried(p)
	return npc and npc:GetAttribute("WorkerUid")
end

-- Bridge to the client helpers.
local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test028Bridge"
bridge.Parent = ReplicatedStorage
local replies: { [number]: any } = {}
local seq = 0
bridge.OnServerEvent:Connect(function(_p, kind, id, state)
	if kind == "reply" and type(id) == "number" then
		replies[id] = state
	end
end)
local function ask(p: Player, kind: string, arg: any?, timeout: number?): any
	seq += 1
	local id = seq
	bridge:FireClient(p, kind, id, arg)
	local state = waitUntil(timeout or 6, function()
		return replies[id]
	end)
	replies[id] = nil
	return state or { answered = false }
end
local function probe(p: Player, what: string?): any
	return ask(p, "probe", what, if what == "perf" then 12 else 6)
end
-- Stands `p` next to where walker `w` is now (beside it, across the lane).
local function standBy(p: Player, w: Model, side: number?)
	local pos = ParadeService.position(w)
	local lane = ParadeService._test.lane()
	local root = (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	root.AssemblyLinearVelocity = Vector3.zero;
	(p.Character :: Model):PivotTo(CFrame.new(pos + lane.side * (side or 3) + Vector3.new(0, 0.5, 0)))
end
local function pickWalker(): Model?
	-- a walker well inside the lane (not about to leave)
	local f = walkers()
	local best, bestD = nil, math.huge
	if f then
		local lane = ParadeService._test.lane()
		for _, w in f:GetChildren() do
			local pos = ParadeService.position(w)
			local along = (pos - lane.start):Dot(lane.dir)
			local d = math.abs(along - lane.length * 0.35)
			if w:GetAttribute("Claimed") ~= true and d < bestD then
				best, bestD = w, d
			end
		end
	end
	return best
end
-- Waits (up to 15 s) for an uncaught walker: quick catches in a row can empty the lane for a moment.
local function freshWalker(): Model?
	return waitUntil(15, pickWalker)
end
-- Puts whatever `p` carries into storage (the inventory screen's StoreCarried request).
local function storeCarried(p: Player)
	if NPCCarry.getCarried(p) then
		ask(p, "inv", { action = "StoreCarried" })
		waitUntil(3, function()
			return NPCCarry.getCarried(p) == nil
		end)
	end
end

-- Lane cap watcher: the most walkers ever seen at once.
local maxWalkers = 0
task.spawn(function()
	while bridge.Parent do
		local f = walkers()
		if f then
			maxWalkers = math.max(maxWalkers, #f:GetChildren())
		end
		task.wait(0.1)
	end
end)

-- Start ---------------------------------------------------------------------------------------------------
setFlags(true)
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
	holder.Name = "Test028Helper"
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

scenario("parade running", function()
	local f = walkers()
	expect("Workspace.Parade.Walkers exists and is filled at start", f ~= nil and #f:GetChildren() >= ParadeConfig.MAX_ON_LANE - 1, f and #f:GetChildren())
	expect("flags published to clients", ReplicatedStorage:GetAttribute("ParadeOn") == true and ReplicatedStorage:GetAttribute("JuiceOn") == true)
	local s = probe(A)
	expect("client draws the walkers", s.paradeGui == true and (s.walkersShown or 0) >= 7, s.walkersShown)
	expect("lane sign built on the client", s.sign == true)
	expect("both players start new: the first catch is free", ParadeService.isFree(A) and ParadeService.isFree(B))
	expect("goal HUD shows the first goal", s.goal == "Catch your first worker" and s.goalVisible == true, s.goal)
	-- the walker positions the clients draw match the server's path (sampled on the server copy: never moved)
	local lane = ParadeService._test.lane()
	local inside = 0
	for _, w in (f :: Folder):GetChildren() do
		local pos = ParadeService.position(w)
		local along = (pos - lane.start):Dot(lane.dir)
		if along >= -0.01 and along <= lane.length + 0.01 then
			inside += 1
		end
	end
	expect("every walker is on the lane path", inside == #(f :: Folder):GetChildren(), inside)
end)

scenario("first catch within 10 s of spawning", function()
	for _, p in { A, B } do
		local spawnedAt: number? = nil
		local conn = p.CharacterAdded:Connect(function()
			spawnedAt = os.clock()
		end)
		p:LoadCharacter()
		conn:Disconnect()
		waitUntil(5, function()
			return spawnedAt ~= nil and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		end)
		local cash = CashService.get(p)
		local reply = ask(p, "chase", 12, 16)
		local carriedAt = waitUntil(2, function()
			return p:GetAttribute("CarryingNPC") == true and os.clock()
		end)
		local took = if carriedAt and spawnedAt then carriedAt - spawnedAt else nil
		expect(
			p.Name .. " catches a parade worker within 10 s of spawning",
			took ~= nil and took < 10,
			("spawn->carrying %.2fs (client: in range %.2fs, Catch sent %.2fs, carrying %.2fs)"):format(took or -1, reply.inRange or -1, reply.sent or -1, reply.carry or -1)
		)
		expect(p.Name .. ": the first catch was free", CashService.get(p) == cash, CashService.get(p))
		expect(p.Name .. ": no longer free afterwards", not ParadeService.isFree(p) and ParadeService._test.hubOf(p).paradeFree == true)
	end
	task.wait(1.2)
	local s = probe(A)
	expect("A saw the reveal banner (juice)", type(s.banner) == "string" and #s.banner > 0, s.banner)
	expect("A's goal moved on after the catch", s.goal ~= "Catch your first worker", s.goal)
	expect("A's client got the Caught event", tostring(s.events):find("Caught") ~= nil, s.events)
	storeCarried(A)
	storeCarried(B)
	expect("caught parade workers are stored like any other", total(A) == 1 and total(B) == 1, ("%d/%d"):format(total(A), total(B)))
end)

scenario("paying", function()
	local w = freshWalker() :: Model
	standBy(A, w)
	local ok, message = ParadeService.tryCatch(A, w)
	expect("no cash: the catch is refused with a clear message", ok == false and tostring(message):find("need") ~= nil, message)
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	CashService.add(A, 100)
	w = freshWalker() :: Model
	standBy(A, w)
	ok, message = ParadeService.tryCatch(A, w)
	expect("with cash the catch goes through", ok == true, message)
	expect("the price is taken once", CashService.get(A) == 100 - ParadeConfig.CATCH_PRICE, CashService.get(A))
	expect(
		"A is carrying the new worker",
		waitUntil(3, function()
			return NPCCarry.getCarried(A) ~= nil and carriedUid(A) ~= nil
		end)
	)
	storeCarried(A)
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	w = freshWalker() :: Model
	local pos = ParadeService.position(w);
	(A.Character :: Model):PivotTo(CFrame.new(pos + Vector3.new(0, 0.5, 40)))
	ok, message = ParadeService.tryCatch(A, w)
	expect("too far away: refused", ok == false and tostring(message):find("closer") ~= nil, message)
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	standBy(A, w)
	local okSpam1 = ParadeService.tryCatch(A, w)
	local okSpam2, spamMessage = ParadeService.tryCatch(A, w)
	expect("a second attempt inside the cooldown is refused", okSpam1 == true and okSpam2 == false, spamMessage)
	waitUntil(3, function()
		return NPCCarry.getCarried(A) ~= nil
	end)
	storeCarried(A)
end)

scenario("race: two players, one walker", function()
	for round = 1, 3 do
		task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
		CashService.add(A, 100)
		CashService.add(B, 100)
		local beforeA, beforeB = total(A), total(B)
		local cashA, cashB = CashService.get(A), CashService.get(B)
		local w = freshWalker() :: Model
		standBy(A, w, 2.5)
		standBy(B, w, -2.5)
		local first, second = if round % 2 == 1 then A else B, if round % 2 == 1 then B else A
		local ok1 = ParadeService.tryCatch(first, w) -- same frame, no yield between
		local ok2, message2 = ParadeService.tryCatch(second, w)
		expect(("round %d: exactly one wins"):format(round), ok1 == true and ok2 == false, message2)
		expect(("round %d: the loser is told 'Too slow!'"):format(round), tostring(message2):find("Too slow") ~= nil, message2)
		waitUntil(3, function()
			return NPCCarry.getCarried(first) ~= nil
		end)
		expect(("round %d: one new worker in total"):format(round), (total(A) - beforeA) + (total(B) - beforeB) == 1, ("%d/%d"):format(total(A) - beforeA, total(B) - beforeB))
		expect(("round %d: only the winner paid"):format(round), (CashService.get(A) - cashA) + (CashService.get(B) - cashB) == -ParadeConfig.CATCH_PRICE)
		local seen, dupes = {}, 0
		for _, p in { A, B } do
			for uid in uids(p) do
				if seen[uid] then
					dupes += 1
				end
				seen[uid] = true
			end
		end
		expect(("round %d: no duplicate workers"):format(round), dupes == 0, dupes)
		storeCarried(first)
	end
	-- through the real remote: both clients send Catch for the same walker at once
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	local beforeA, beforeB = total(A), total(B)
	local w = freshWalker() :: Model
	standBy(A, w, 2.5)
	standBy(B, w, -2.5)
	task.wait(0.2)
	bridge:FireClient(A, "catch", -1, w)
	bridge:FireClient(B, "catch", -2, w)
	task.wait(2.5)
	local carrying = (if NPCCarry.getCarried(A) then 1 else 0) + (if NPCCarry.getCarried(B) then 1 else 0)
	expect("remote race: exactly one player carries the walker", carrying == 1, carrying)
	expect("remote race: one new worker in total", (total(A) - beforeA) + (total(B) - beforeB) == 1)
	local sa, sb = probe(A), probe(B)
	local loserFeedback = if NPCCarry.getCarried(A) then sb.feedback else sa.feedback
	expect(
		"remote race: the loser saw 'Too slow!' (or the walker was already gone)",
		tostring(loserFeedback):find("Too slow") ~= nil or tostring(loserFeedback) == "",
		loserFeedback
	)
	storeCarried(A)
	storeCarried(B)
end)

scenario("cancelled catch is refunded", function()
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	CashService.add(A, 50)
	local cash = CashService.get(A)
	local before = total(A)
	local w = freshWalker() :: Model
	standBy(A, w)
	local ok = ParadeService.tryCatch(A, w)
	local humanoid = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Health = 0 -- dies during the 0.7 s spin
	task.wait(1.5)
	expect("catch started, then the catcher died mid-spin", ok == true)
	expect("the price came back", CashService.get(A) == cash, ("%d -> %d"):format(cash, CashService.get(A)))
	expect("no worker was created", total(A) == before)
	waitUntil(8, function()
		return A.Character and A.Character:FindFirstChildOfClass("Humanoid") and A.Character:FindFirstChildOfClass("Humanoid").Health > 0
	end)
	task.wait(0.5)
end)

scenario("golden parade", function()
	local normal = WorkerCatalogue.RARITY_PER_MILLE
	expect("normal odds untouched (700/200/80/18/2)", normal.Common == 700 and normal.Rare == 200 and normal.Epic == 80 and normal.Legendary == 18 and normal.Secret == 2)
	local rng = Random.new(28)
	local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Secret = 0 }
	local n = 40000
	for _ = 1, n do
		local r = WorkerCatalogue.rollRarity(rng, ParadeConfig.GOLDEN_PER_MILLE)
		counts[r] += 1
	end
	local worst = 0
	for rarity, perMille in ParadeConfig.GOLDEN_PER_MILLE do
		worst = math.max(worst, math.abs(counts[rarity] / n * 1000 - perMille))
	end
	expect("golden rolls follow the golden odds (40,000 rolls)", worst < 8, ("worst gap %.1f per mille"):format(worst), true)

	ParadeService.startGolden()
	task.wait(0.8)
	expect("Golden Parade is on", ParadeService.isGolden())
	local s = probe(A)
	expect(
		"clients show it: countdown pill + gold walkers",
		tostring(s.pill):find("GOLDEN") ~= nil and (s.foil or 0) > 0,
		("%s, foil parts %s"):format(tostring(s.pill), tostring(s.foil))
	)
	expect("clients got the Golden event", tostring(s.events):find("Golden") ~= nil, s.events)
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	CashService.add(A, 100)
	local w = freshWalker() :: Model
	standBy(A, w)
	local ok = ParadeService.tryCatch(A, w)
	expect("a catch during the Golden Parade uses the golden odds", ok == true and w:GetAttribute("CaughtGolden") == true)
	waitUntil(3, function()
		return NPCCarry.getCarried(A) ~= nil
	end)
	storeCarried(A)
	-- End it through the real loop: bring its end time forward.
	local paradeFolder = workspace:FindFirstChild("Parade") :: Folder
	local startedAt = paradeFolder:GetAttribute("GoldenStart")
	paradeFolder:SetAttribute("GoldenEnd", workspace:GetServerTimeNow() + 1)
	task.wait(2)
	expect("it ends by itself: window cleared", paradeFolder:GetAttribute("GoldenStart") == nil and paradeFolder:GetAttribute("GoldenEnd") == nil)
	local nextAt = paradeFolder:GetAttribute("NextGolden")
	expect("the next one is ~15 min after this one started", nextAt and math.abs(nextAt - (startedAt + ParadeConfig.GOLDEN_INTERVAL)) < 2, nextAt and (nextAt - startedAt))
	s = probe(A)
	expect("clients went back to normal", (s.foil or 0) == 0 and tostring(s.pill):find("Golden Parade in") ~= nil, ("%s, foil %s"):format(tostring(s.pill), tostring(s.foil)))
	expect("the lane never had more than " .. ParadeConfig.MAX_ON_LANE .. " walkers", maxWalkers <= ParadeConfig.MAX_ON_LANE, maxWalkers)
end)

scenario("legendary announcement", function()
	task.wait(ParadeConfig.CATCH_COOLDOWN + 0.1)
	ServerStorage:SetAttribute("TestForceWorkerId", "ceo_chad")
	CashService.add(A, 100)
	probe(B) -- clear B's event log
	local w = freshWalker() :: Model
	standBy(A, w)
	local ok = ParadeService.tryCatch(A, w)
	waitUntil(3, function()
		return NPCCarry.getCarried(A) ~= nil
	end)
	ServerStorage:SetAttribute("TestForceWorkerId", nil)
	task.wait(0.8)
	expect("A caught CEO Chad (Legendary, forced by the Studio test hook)", ok and NPCCarry.getCarried(A) and NPCCarry.getCarried(A):GetAttribute("WorkerId") == "ceo_chad")
	local s = probe(B)
	expect("B got the server-wide Legendary message", tostring(s.events):find("Announce:Legendary") ~= nil, s.events)
	storeCarried(A)
end)

scenario("collection book and goals", function()
	local list = ParadeService._test.bookList(A)
	local set = {}
	for _, id in list do
		set[id] = true
	end
	local owned, ownedSet = 0, {}
	for _, w in (PlayerData.get(A) :: any).workers do
		if not ownedSet[w.id] then
			ownedSet[w.id] = true
			owned += 1
		end
	end
	local missing = 0
	for id in ownedSet do
		if not set[id] then
			missing += 1
		end
	end
	expect("every worker A caught is in A's book", missing == 0 and #list == owned, ("book %d, distinct owned %d"):format(#list, owned))
	expect("the book holds ceo_chad", set.ceo_chad == true)
	local s = probe(A, "book")
	expect("the book opens on the Main Street page", s.bookOpen == true and s.bookPage == "MainStreet", s.bookPage)
	expect("caught in colour, missing as silhouettes", s.cards == ("%d colour, %d silhouettes"):format(owned, 8 - owned), s.cards)
	-- put one worker on a pad: the goal moves on
	local uid = next(uids(A))
	ask(A, "inv", { action = "Equip", uid = uid })
	task.wait(1)
	s = probe(A)
	expect("after a worker is on a pad the goal is a later one", s.goal ~= "Put a worker on a pad" and s.goal ~= "Catch your first worker", s.goal)
end)

scenario("saves", function()
	PlayerData.save(A)
	task.wait(1)
	local json = saved[A.UserId]
	local allIn = json ~= nil
	for uid in uids(A) do
		allIn = allIn and json:find(uid, 1, true) ~= nil
	end
	expect("A's save has every parade worker", allIn, json and #json)
	expect("A's save has the book and the used free catch", json ~= nil and json:find('"book"', 1, true) ~= nil and json:find('"paradeFree":true', 1, true) ~= nil)
	local clean = PlayerData._sanitize(PlayerData._migrate(HttpService:JSONDecode(json)))
	local back = 0
	for _, w in clean.workers do
		if uids(A)[w.uid] then
			back += 1
		end
	end
	expect(
		"loading that save back keeps every worker, the book and the free flag (schema 3)",
		back == total(A) and clean.schema == 3 and clean.hub.book and clean.hub.book.ceo_chad == true and clean.hub.paradeFree == true,
		back,
		true
	)
end)

scenario("perf with 8 walkers and effects", function()
	waitUntil(40, function()
		local f = walkers()
		return f and #f:GetChildren() >= ParadeConfig.MAX_ON_LANE
	end)
	local s = probe(A, "perf")
	note(
		"info",
		"flags on",
		("frame avg %.1f ms, worst %.1f ms, parts %s, instances %s, active emitters %s, walkers %s"):format(
			s.frameAvg or -1,
			s.frameWorst or -1,
			tostring(s.parts),
			tostring(s.instances),
			tostring(s.emitters),
			tostring(s.walkersShown)
		)
	)
	expect("perf probe answered", s.frameAvg ~= nil)
	setFlags(nil)
	task.wait(1)
	local off = probe(A, "perf")
	note(
		"info",
		"flags off",
		("frame avg %.1f ms, worst %.1f ms, parts %s, instances %s, active emitters %s"):format(
			off.frameAvg or -1,
			off.frameWorst or -1,
			tostring(off.parts),
			tostring(off.instances),
			tostring(off.emitters)
		)
	)
end)

scenario("flags off", function()
	setFlags(nil)
	task.wait(0.6)
	expect(
		"parade gone: no Workspace.Parade, flags unpublished",
		workspace:FindFirstChild("Parade") == nil and ReplicatedStorage:GetAttribute("ParadeOn") == nil and ReplicatedStorage:GetAttribute("JuiceOn") == nil
	)
	local s = probe(A)
	expect(
		"clients hide everything (parade, juice, goal, book)",
		s.paradeGui == false and s.juiceGui == false and s.goalVisible == false and s.bookButton == false and s.sign == false,
		HttpService:JSONEncode(s)
	)
	local before = total(B)
	local cash = CashService.get(B)
	local hub = HttpService:JSONEncode((PlayerData.get(B) :: any).hub)
	task.wait(1)
	expect("with the flags off nothing changes B's save data", total(B) == before and CashService.get(B) >= cash and HttpService:JSONEncode((PlayerData.get(B) :: any).hub) == hub)
	setFlags(true)
	expect(
		"flags back on: the lane fills again",
		waitUntil(3, function()
			local f = walkers()
			return f and #f:GetChildren() >= ParadeConfig.MAX_ON_LANE - 1
		end)
	)
end)

scenario("leaving saves the parade workers", function()
	local leaverId = B.UserId
	local mine = uids(B)
	B:Kick("test: leaves")
	waitUntil(8, function()
		return saved[leaverId] ~= nil and Players:GetPlayerByUserId(leaverId) == nil
	end)
	task.wait(1)
	local json = saved[leaverId]
	local allIn = json ~= nil
	for uid in mine do
		allIn = allIn and json:find(uid, 1, true) ~= nil
	end
	expect("B's final save on leaving has all B's workers", allIn, json and #json)
end)

section = "end"
setFlags(nil)
bridge:Destroy()
finish("DONE")
