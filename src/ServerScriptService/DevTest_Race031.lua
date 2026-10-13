-- Studio location: ServerScriptService.DevTest_Race031 (Script)
-- DevTest_Race031  (Milestone 031) -- STUDIO-ONLY two-player test of the Royale Race. Inert unless Studio started
-- the session with StudioTestService and one of these arguments (2 clients):
--   "race031"       in-memory save (ServerStorage StudioMemoryStore = true): flag off/on, eligibility, race 1
--                   (both finish: small-race Gold/Silver, reveal, save marker, podium, re-sent messages, phone
--                   HUD), race 2 (back-and-forth skipping checkpoints + time limit = nothing), race 3 (teleport
--                   cut, leave + rejoin mid-race), flag off again.
--   "race031:save"  REAL Studio DataStore (StudioMemoryStore not set; players are test users -1 / -2): A races
--                   solo, finishes, real final save + real load: the race worker and hub.race are back and a
--                   second capsule for that race is refused. Test keys removed at the end.
-- The racers walk the circuit on their own clients (Humanoid:MoveTo), so lap times are real. Results: "@@T031|".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
local mode = if okArgs and args == "race031" then "race" elseif okArgs and args == "race031:save" then "save" else nil
if not mode then
	return
end

local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s %s: %s | %s"):format(kind, mode, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T031|" .. line)
end
local function finish(state: string)
	local summary = ("%s mode=%s passed=%d failed=%d (simulated checks=%d)"):format(state, mode, passed, failed, simulated)
	print("@@T031|SUMMARY " .. summary)
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
	print("@@T031|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

local PlayerData, PlotService, WorkerInventory, ZoneProgress = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory"), mod("ZoneProgress")
local RaceService = mod("RaceService")
local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

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
task.wait(3)
local memory = ServerStorage:GetAttribute("StudioMemoryStore") == true or not PlayerData.isPersistent()
if mode == "race" and not memory then
	finish("ABORTED: run race031 on the in-memory save (ServerStorage StudioMemoryStore = true)")
	return
elseif mode == "save" and memory then
	finish("ABORTED: race031:save needs the real Studio DataStore (API access on, StudioMemoryStore not set)")
	return
end
local list = Players:GetPlayers()
table.sort(list, function(a, b)
	return a.UserId > b.UserId
end)
local A, B = list[1], list[2]
if not (A and B and ready(A) and ready(B)) then
	finish("ABORTED: needs two loaded players")
	return
end

local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test031Bridge"
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
	local value = waitUntil(timeout or 8, function()
		return replies[id]
	end)
	replies[id] = nil
	return value or { answered = false }
end
for _, p in { A, B } do
	local helper = script:WaitForChild("ClientHelper"):Clone()
	helper.Disabled = false
	helper.Parent = p:WaitForChild("PlayerGui")
end
waitUntil(20, function()
	return helpers[A] and helpers[B]
end)

-- Helpers ---------------------------------------------------------------------------------------------------
local function root(p: Player): BasePart
	return (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
end
local function put(p: Player, pos: Vector3, look: Vector3?)
	pcall(p.RequestStreamAroundAsync, p, pos)
	local character = p.Character :: Model
	character:PivotTo(if look then CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)) else CFrame.new(pos))
	root(p).AssemblyLinearVelocity = Vector3.zero
	task.wait(1)
end
local function course(): Instance?
	return workspace.World.VelocityRoyale:FindFirstChild(RaceConfig.FOLDER)
end
local function state(): string?
	local c = course()
	return c and c:GetAttribute("State")
end
local template = ServerStorage:WaitForChild(RaceConfig.TEMPLATE)
local LINE = {}
for _, v in template.Line:GetChildren() do
	LINE[tonumber(v.Name:sub(2)) :: number] = v.Value + Vector3.new(0, 3, 0)
end
local PAD = (template.StartPad :: BasePart).Position
-- 3 laps from the pad: every centre-line point from the line onwards, three times, ending past the line.
local function lapPoints(laps: number): { Vector3 }
	local pts = {}
	for _ = 1, laps do
		for i = 2, #LINE do
			table.insert(pts, LINE[i])
		end
		table.insert(pts, LINE[1])
	end
	table.insert(pts, LINE[1] + Vector3.new(0, 0, 4)) -- run through the line
	return pts
end
local function workers(p: Player): { [string]: any }
	local set = {}
	for _, w in ((PlayerData.get(p) :: any) or { workers = {} }).workers do
		set[w.uid] = w
	end
	return set
end
local function newWorkers(p: Player, before: { [string]: any }): { any }
	local found = {}
	for uid, w in workers(p) do
		if not before[uid] then
			table.insert(found, w)
		end
	end
	return found
end
local function hubRace(p: Player): any
	local data = PlayerData.get(p) :: any
	return data and data.hub and data.hub.race
end
local function unlock(p: Player)
	local data = PlayerData.get(p) :: any
	if not table.find(data.zones, "BillionaireHills") then
		table.insert(data.zones, "BillionaireHills")
	end
	ZoneProgress._test.publish(p)
end
local function onPads(players: { Player })
	for i, p in players do
		put(p, PAD + Vector3.new(if i == 1 then 2 else -2, 3, 0), PAD + Vector3.new(0, 0, 10))
	end
end
local function eventsOf(p: Player, kind: string): { any }
	local found = {}
	for _, e in (ask(p, "events").events or {}) do
		if e.kind == kind then
			table.insert(found, e.info)
		end
	end
	return found
end
local function startNow()
	ServerStorage:SetAttribute("StudioRaceNow", true)
end
local function waitState(want: string, seconds: number): boolean
	return waitUntil(seconds, function()
		return state() == want
	end) ~= nil
end
local function cleanupStore()
	scenario("cleanup", function()
		for _, p in { A, B } do
			if p.Parent then
				PlayerData._test.leave(p)
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

-- REAL save mode ----------------------------------------------------------------------------------------------
if mode == "save" then
	local raceId, uid, workerId
	scenario("solo race on the real save", function()
		expect("test users", A.UserId < 0 and B.UserId < 0, A.UserId)
		ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, true)
		expect("course built", waitUntil(5, course) ~= nil)
		unlock(A)
		local before = workers(A)
		onPads({ A })
		put(B, PAD + Vector3.new(0, 3, 40))
		startNow()
		expect("countdown", waitState("Countdown", 4))
		expect("racing", waitState("Racing", RaceConfig.COUNTDOWN + 2))
		local run = ask(A, "walk", { points = lapPoints(RaceConfig.LAPS) }, RaceConfig.TIME_LIMIT + 10)
		expect("A walked 3 laps", run.answered, run.stuck)
		expect(
			"race over",
			waitUntil(5, function()
				return state() == "Podium"
			end)
		)
		local got = newWorkers(A, before)
		expect("A got exactly one worker", #got == 1, #got)
		local rec = hubRace(A)
		expect("solo winner gets Gold", rec and rec.cap == "Gold" and rec.place == 1, rec and rec.cap)
		raceId, uid = rec and rec.id, rec and rec.uid
		workerId = got[1] and got[1].id
		expect("worker is a Zone 6 worker", workerId and WorkerCatalogue.get(workerId).zone == "BillionaireHills", workerId)
		note("INFO", "solo 3-lap time", RaceService.lastRace and RaceService.lastRace.finishers[1] and ("%.1f s"):format(RaceService.lastRace.finishers[1].time))
	end)
	scenario("real final save + real load (rejoin)", function()
		PlayerData._test.leave(A)
		local stored = PlayerData.store():GetAsync("player_" .. A.UserId)
		local data = stored and stored.data
		local inSave = false
		for _, w in (data and data.workers or {}) do
			inSave = inSave or w.uid == uid
		end
		expect("the race worker is in the real save", inSave, uid)
		expect("hub.race is in the real save", data and data.hub and data.hub.race and data.hub.race.id == raceId)
		expect("schema is still 3", data and data.schema == 3)
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
		expect("the race worker came back", workers(A)[uid] ~= nil and workers(A)[uid].id == workerId)
		expect("hub.race came back", hubRace(A) and hubRace(A).id == raceId)
		local count = 0
		for _ in workers(A) do
			count += 1
		end
		local again = RaceService.grant(A, raceId, 1, "Gold")
		local after = 0
		for _ in workers(A) do
			after += 1
		end
		expect("a second capsule for that race is refused after the rejoin", again == nil and after == count, again)
	end)
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, nil)
	cleanupStore()
	finish("COMPLETE")
	return
end

-- In-memory mode ------------------------------------------------------------------------------------------------
local vrParts = 0
for _, d in workspace.World.VelocityRoyale:GetDescendants() do
	if d:IsA("BasePart") then
		vrParts += 1
	end
end

scenario("flag off: Zone 6 as before", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, nil)
	task.wait(0.5)
	expect("no course in the world", course() == nil)
	expect("RaceOn not published", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == nil)
	expect("no race has run", RaceService.stats.races == 0)
	put(A, PAD + Vector3.new(0, 3, 0))
	task.wait(1)
	expect("standing on the grid does nothing", A:GetAttribute("Racing") == nil and course() == nil)
end)

scenario("flag on: course, sign with odds", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, true)
	expect("course built", waitUntil(5, course) ~= nil)
	local c = course() :: Instance
	expect("RaceOn published", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == true)
	for _, name in { "StartPad", "Sign", "Name1", "Name2", "Name3", "SafeVolume" } do
		expect(name .. " in the world", c:FindFirstChild(name) ~= nil)
	end
	expect("gates stay on the server", c:FindFirstChild("Gates") == nil and c:FindFirstChild("CP1") == nil)
	local sign = c:FindFirstChild("Sign") :: Instance
	local front = sign:FindFirstChild("SignFront") :: Instance
	local gold, silver = front and front:FindFirstChild("Gold") :: TextLabel, front and front:FindFirstChild("Silver") :: TextLabel
	expect(
		"sign shows Gold = Golden Parade odds",
		gold and gold.Text:find("Common 50%%") and gold.Text:find("Legendary 5%%") and gold.Text:find("Secret 0.5%%"),
		gold and gold.Text
	)
	expect(
		"sign shows Silver = normal odds",
		silver and silver.Text:find("Common 70%%") and silver.Text:find("Legendary 1.8%%") and silver.Text:find("Secret 0.2%%"),
		silver and silver.Text
	)
	expect("racers never collide", PhysicsService:CollisionGroupsAreCollidable(RaceConfig.COLLISION_GROUP, RaceConfig.COLLISION_GROUP) == false)
	expect("Zone 6 catch odds untouched", WorkerCatalogue.RARITY_PER_MILLE.Common == 700 and WorkerCatalogue.RARITY_PER_MILLE.Secret == 2)
	expect("state Waiting", state() == "Waiting")
end)

scenario("eligibility: locked zone, full inventory", function()
	-- (a locked player can't even stand on the pad: the Zone 6 gate turns them back)
	local ok, why = RaceService.eligible(A)
	expect("Zone 6 locked: not eligible", ok == false and tostring(why):find("Unlock Velocity Royale") ~= nil, why)
	unlock(A)
	unlock(B)
	-- fill A up to capacity, stand on the pad: no race, told why
	local fillers = {}
	while WorkerInventory.hasRoom(A) and #fillers < 60 do
		local uid = HttpService:GenerateGUID(false)
		WorkerInventory.give(A, { uid = uid, id = "butler_barnaby", zone = "BillionaireHills", level = 1, tier = "Normal", loc = "inventory" }, true)
		table.insert(fillers, uid)
	end
	ask(A, "clear")
	put(B, PAD + Vector3.new(0, 3, 40))
	onPads({ A })
	startNow()
	task.wait(1.5)
	expect("no countdown for a full player", state() == "Waiting", state())
	local fb = eventsOf(A, "Feedback")
	expect("told there is no room", fb[1] and tostring(fb[1].message):find("No room") ~= nil, fb[1] and fb[1].message)
	put(A, PAD + Vector3.new(4, 3, 40)) -- off the pad first: with room again A alone would start a race
	for _, uid in fillers do
		WorkerInventory.take(A, uid)
	end
	task.wait(0.5)
	expect("nobody on the pad: still waiting", state() == "Waiting", state())
	expect("room again", WorkerInventory.hasRoom(A))
end)

local race1
scenario("race 1: two racers, 3 laps, small-race rule", function()
	ask(A, "clear")
	ask(B, "clear")
	local beforeA, beforeB = workers(A), workers(B)
	onPads({ A, B })
	startNow()
	expect("countdown starts", waitState("Countdown", 3))
	local hudCount = ask(B, "hud", { pieces = { "Count" }, settle = 0.35 }, 10)
	expect("countdown fits phone screens", hudCount.hud and #hudCount.hud.issues == 0, hudCount.hud and table.concat(hudCount.hud.issues, "; "))
	expect("GO", waitState("Racing", RaceConfig.COUNTDOWN + 2))
	local c = course() :: Instance
	expect("2 racers", c:GetAttribute("Racers") == 2, c:GetAttribute("Racers"))
	expect("A racing, lap 1", A:GetAttribute("Racing") == true and A:GetAttribute("RaceLap") == 1)
	expect("racer collision group", root(A).CollisionGroup == RaceConfig.COLLISION_GROUP, root(A).CollisionGroup)
	local h = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	expect("fixed race speed", h.WalkSpeed == RaceConfig.WALK_SPEED, h.WalkSpeed)
	local runA
	task.spawn(function()
		runA = ask(A, "walk", { points = lapPoints(RaceConfig.LAPS) }, RaceConfig.TIME_LIMIT + 10)
	end)
	local hudRace = ask(B, "hud", { pieces = { "RacePanel" } }, 10)
	expect("race HUD (LAP + timer) fits phone screens", hudRace.hud and #hudRace.hud.issues == 0, hudRace.hud and table.concat(hudRace.hud.issues, "; "))
	local texts = ask(B, "texts")
	expect("big LAP counter shows LAP 1/3", texts.lap == "LAP 1/3" and texts.panel == true, texts.lap)
	local runB = ask(B, "walk", { points = lapPoints(RaceConfig.LAPS) }, RaceConfig.TIME_LIMIT + 10)
	waitUntil(RaceConfig.TIME_LIMIT, function()
		return runA ~= nil
	end)
	expect("both walked", runA and runA.answered and runB.answered, ("stuck A %s B %s"):format(tostring(runA and runA.stuck), tostring(runB.stuck)))
	expect(
		"race over",
		waitUntil(5, function()
			return state() == "Podium"
		end)
	)
	local hudPodium = ask(A, "hud", { pieces = { "PodiumBanner" } }, 10)
	expect("podium banner fits phone screens", hudPodium.hud and #hudPodium.hud.issues == 0, hudPodium.hud and table.concat(hudPodium.hud.issues, "; "))
	race1 = RaceService.lastRace
	local f = race1 and race1.finishers or {}
	expect("two finishers", #f == 2, #f)
	expect("A 1st = Gold", f[1] and f[1].userId == A.UserId and f[1].capsule == "Gold", f[1] and f[1].capsule)
	expect("B 2nd = Silver (under 4 racers only 1st is Gold)", f[2] and f[2].userId == B.UserId and f[2].capsule == "Silver", f[2] and f[2].capsule)
	note("INFO", "3-lap times", ("A %.1f s, B %.1f s (B started ~5 s late for the HUD check)"):format(f[1] and f[1].time or -1, f[2] and f[2].time or -1))
	local gotA, gotB = newWorkers(A, beforeA), newWorkers(B, beforeB)
	expect("A got exactly one worker", #gotA == 1, #gotA)
	expect("B got exactly one worker", #gotB == 1, #gotB)
	expect("both are Zone 6 workers", gotA[1] and gotB[1] and gotA[1].zone == "BillionaireHills" and gotB[1].zone == "BillionaireHills")
	expect("A's went to a pad or storage", gotA[1] and (gotA[1].loc == "station" or gotA[1].loc == "inventory"), gotA[1] and gotA[1].loc)
	expect("save marker hub.race (A)", hubRace(A) and hubRace(A).id == race1.id and hubRace(A).cap == "Gold" and hubRace(A).uid == (gotA[1] and gotA[1].uid))
	expect("save marker hub.race (B)", hubRace(B) and hubRace(B).id == race1.id and hubRace(B).cap == "Silver")
	task.wait(RaceConfig.REVEAL_DELAY + 0.5)
	local fin, rev = eventsOf(A, "Finish"), eventsOf(A, "Reveal")
	expect("A saw the Finish capsule (1st, Gold)", fin[1] and fin[1].place == 1 and fin[1].capsule == "Gold")
	expect("A got the reveal card for that worker", rev[1] and gotA[1] and rev[1].workerId == gotA[1].id and rev[1].uid == gotA[1].uid)
	local laps = eventsOf(A, "Lap")
	expect("A saw lap 2 and lap 3", #laps == 2 and laps[1].lap == 2 and laps[2].lap == 3, #laps)
	expect(
		"racer state undone (collision group, attributes)",
		root(A).CollisionGroup == "Default" and A:GetAttribute("Racing") == nil and A:GetAttribute("RaceLap") == nil,
		root(A).CollisionGroup
	)
	local n1 = c:FindFirstChild("Name1") :: Instance
	local tag = n1 and n1:FindFirstChild("PodiumName") :: BillboardGui
	local nameLabel = tag and tag:FindFirstChild("Name") :: TextLabel?
	expect("podium shows A first", tag and tag.Enabled and nameLabel and nameLabel.Text:find(A.DisplayName, 1, true) ~= nil, nameLabel and nameLabel.Text)
end)

scenario("re-sent messages and repeated grants give nothing", function()
	local before = workers(A)
	ask(A, "resend", nil, 10)
	task.wait(0.5)
	expect("client messages: no new worker", #newWorkers(A, before) == 0)
	local again = race1 and RaceService.grant(A, race1.id, 1, "Gold")
	expect("same race id again: refused", again == nil and #newWorkers(A, before) == 0)
	local dataCopy = PlayerData._sanitize(PlayerData.get(A))
	expect("hub.race survives the save cleaner", dataCopy.hub.race and dataCopy.hub.race.id == race1.id)
	expect("duplicates counted", RaceService.stats.duplicate >= 1)
end)

scenario("race 2: skipping checkpoints + time limit", function()
	expect("podium ends after 20 s", waitState("Waiting", RaceConfig.PODIUM_SECONDS + 3))
	local beforeA, beforeB = workers(A), workers(B)
	local markB = hubRace(B) and hubRace(B).id
	ask(A, "clear")
	ask(B, "clear")
	onPads({ A, B })
	startNow()
	expect("GO", waitState("Racing", RaceConfig.COUNTDOWN + 4))
	local runA
	task.spawn(function()
		runA = ask(A, "walk", { points = lapPoints(RaceConfig.LAPS) }, RaceConfig.TIME_LIMIT + 10)
	end)
	-- B crosses the line back and forth (never reaching CP1): a lap only counts after every checkpoint
	local back = {}
	for _ = 1, 6 do
		table.insert(back, LINE[1] + Vector3.new(0, 0, 6))
		table.insert(back, LINE[1] + Vector3.new(0, 0, -6))
	end
	ask(B, "walk", { points = back }, 40)
	expect("B still on lap 1 after crossing the line 12 times", B:GetAttribute("RaceLap") == 1, B:GetAttribute("RaceLap"))
	expect(
		"race ends at the time limit",
		waitUntil(RaceConfig.TIME_LIMIT + 5, function()
			return state() == "Podium"
		end)
	)
	local r2 = RaceService.lastRace
	expect("ended by the time limit", r2 and r2.reason == "time", r2 and r2.reason)
	expect("A finished 1st (Gold)", r2 and r2.finishers[1] and r2.finishers[1].userId == A.UserId and r2.finishers[1].capsule == "Gold")
	expect("only A finished", r2 and #r2.finishers == 1, r2 and #r2.finishers)
	expect("A got one more worker", #newWorkers(A, beforeA) == 1)
	expect("B got nothing", #newWorkers(B, beforeB) == 0)
	expect("B's save marker unchanged", hubRace(B) and hubRace(B).id == markB)
	local out = eventsOf(B, "Out")
	expect("B told time's up", out[1] and tostring(out[1].reason):find("Time") ~= nil, out[1] and out[1].reason)
	expect("B no longer racing", B:GetAttribute("Racing") == nil and root(B).CollisionGroup == "Default")
	local _ = runA
end)

scenario("race 3: teleport cut (SIM) and leave + rejoin mid-race (SIM)", function()
	expect("podium ends", waitState("Waiting", RaceConfig.PODIUM_SECONDS + 3))
	local beforeA, beforeB = workers(A), workers(B)
	ask(A, "clear")
	onPads({ A, B })
	startNow()
	expect("GO", waitState("Racing", RaceConfig.COUNTDOWN + 4))
	-- A "teleports" (exploit) from gate to gate
	for i = 1, RaceConfig.WARP_LIMIT do
		local g = RaceService._test.gates[i]
		root(A).CFrame = g.cf
		task.wait(0.3)
	end
	expect("A out for teleporting", A:GetAttribute("Racing") == nil, nil, true)
	local out = eventsOf(A, "Out")
	expect("A told no shortcuts", out[1] and tostring(out[1].reason):find("shortcut") ~= nil, out[1] and out[1].reason, true)
	-- B leaves mid-race (what PlayerRemoving does), then rejoins: a fresh load is not a racer
	RaceService._test.drop(B)
	PlayerData._test.leave(B)
	local plot = PlotService.getPlot(B)
	if plot then
		plot.PlacedNPCs:ClearAllChildren()
		for _, station in plot.Stations:GetChildren() do
			station:SetAttribute("Occupied", false)
		end
	end
	task.spawn(PlayerData._test.load, B)
	expect("B loaded again", waitUntil(20, function()
		return PlayerData.isLoaded(B) and WorkerInventory.isReady(B)
	end) ~= nil, nil, true)
	expect("rejoined B is not a racer", B:GetAttribute("Racing") == nil, nil, true)
	expect("race ends with no finishers", waitUntil(5, function()
		return state() == "Podium"
	end) and RaceService.lastRace and #RaceService.lastRace.finishers == 0)
	expect("nobody got a worker", #newWorkers(A, beforeA) == 0 and #newWorkers(B, beforeB) == 0)
end)

scenario("creature showcase (Studio-only flag)", function()
	ServerStorage:SetAttribute("StudioCreatures", true)
	local showcase = waitUntil(5, function()
		return workspace.World.VelocityRoyale:FindFirstChild("CreatureShowcase")
	end)
	expect("showcase built", showcase ~= nil)
	for _, name in { "SlimeRookie", "DragonPup", "MechBeast" } do
		local m = showcase and showcase:FindFirstChild(name) :: Model?
		local body = m and m.PrimaryPart
		local eye = m and m:FindFirstChild(name .. "_EyeL") :: BasePart?
		expect(
			name .. " stands upright facing the plaza",
			body and eye and body.CFrame.UpVector.Y > 0.99 and eye.Position.Y > body.Position.Y - 0.5 and eye.Position.Z > body.Position.Z
		)
		local welds = 0
		for _, d in (m and m:GetDescendants() or {}) do
			welds += if d:IsA("Weld") then 1 else 0
		end
		expect(name .. " is one root + welded pieces", body and body.Anchored and welds >= 8, welds)
	end
	for zone, ids in WorkerCatalogue.ZONES do
		for _, id in ids do
			expect("no creature in the " .. zone .. " pool", not (id:lower():find("slime") or id:lower():find("dragon") or id:lower():find("mech")), id)
		end
	end
	put(A, Vector3.new(-159, 76, -895), Vector3.new(-159, 76, -912))
	task.wait(1.5)
	local c = ask(A, "creatures", nil, 10).creatures or {}
	for _, name in { "SlimeRookie", "DragonPup", "MechBeast" } do
		local r = c[name]
		expect(name .. " idles on the client (moves, joints turn)", r and r.bob > 0.05 and r.movingJoints >= 1, r and ("bob %.2f joints %d"):format(r.bob, r.movingJoints))
	end
	ServerStorage:SetAttribute("StudioCreatures", nil)
	task.wait(0.5)
	expect("showcase removed when off", workspace.World.VelocityRoyale:FindFirstChild("CreatureShowcase") == nil)
end)

scenario("flag off again: everything removed", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, nil)
	task.wait(0.6)
	expect("course removed", course() == nil)
	expect("RaceOn cleared", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == nil)
	local now = 0
	for _, d in workspace.World.VelocityRoyale:GetDescendants() do
		if d:IsA("BasePart") then
			now += 1
		end
	end
	expect("Velocity Royale parts as before the flag", now == vrParts, ("%d vs %d"):format(now, vrParts))
	note("INFO", "stats", HttpService:JSONEncode(RaceService.stats))
end)

finish("COMPLETE")
