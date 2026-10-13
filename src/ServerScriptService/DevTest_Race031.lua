-- Studio location: ServerScriptService.DevTest_Race031 (Script)
-- DevTest_Race031  (Milestone 031) -- STUDIO-ONLY two-player test of the Royale Race. Inert unless Studio started
-- the session with StudioTestService and one of these arguments (2 clients):
--   "race031"       in-memory save (ServerStorage StudioMemoryStore = true): flag off/on (first race open at once,
--                   sign, odds board, walls, route, chevrons), eligibility + pad messages, race 1 (frozen on the
--                   pad for the last 5 s, next-checkpoint arch + arrow, both finish: small-race Gold/Silver,
--                   reveal, save marker, podium, re-sent messages, phone HUD), race 2 ("Next race in" on the
--                   pad, a non-racer walks through the track wall and a racer can't, back-and-forth skipping
--                   checkpoints + time limit = nothing), race 3 (teleport cut, "Race in progress" on the pad,
--                   leave + rejoin mid-race), flag off again.
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
-- across the inner barrier from the start straight into the infield (no pylons or gantry posts in the way)
local TRACK_SIDE = Vector3.new(-115.5, 75.3, -948)
local INFIELD = Vector3.new(-104, 75.3, -948)
local INNER_EDGE_X = -110.3
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
		expect("racing", waitState("Racing", RaceConfig.JOIN_WINDOW + 2))
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
local vrParts = 0 -- counted once the flag is off (the place may start with StudioRace on)

scenario("flag off: Zone 6 as before", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, nil)
	task.wait(0.5)
	expect("no course in the world", course() == nil)
	expect("RaceOn not published", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == nil)
	expect("no race has run", RaceService.stats.races == 0)
	put(A, PAD + Vector3.new(0, 3, 0))
	task.wait(1)
	expect("standing on the grid does nothing", A:GetAttribute("Racing") == nil and course() == nil)
	for _, d in workspace.World.VelocityRoyale:GetDescendants() do
		if d:IsA("BasePart") then
			vrParts += 1
		end
	end
end)

scenario("flag on: course, sign, odds board, walls, route", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, true)
	expect("course built", waitUntil(5, course) ~= nil)
	local c = course() :: Instance
	expect("RaceOn published", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == true)
	expect("first race open right away (no wait after start)", (c:GetAttribute("Ready") or math.huge) <= workspace:GetServerTimeNow(), c:GetAttribute("Ready"))
	for _, name in { "StartPad", "Sign", "OddsBoard", "Name1", "Name2", "Name3", "SafeVolume", "Walls", "Route" } do
		expect(name .. " in the world", c:FindFirstChild(name) ~= nil)
	end
	expect("server gates stay on the server", c:FindFirstChild("Gates") == nil and c:FindFirstChild("CP1") == nil)
	local route = c:FindFirstChild("Route") :: Instance
	expect("route = every gate's position", route and #route:GetChildren() == #template.Gates:GetChildren(), route and #route:GetChildren())
	-- pad sign: title, one huge status line, one rule line; both faces
	for _, faceName in { "SignFront", "SignBack" } do
		local face = (c :: any).Sign:FindFirstChild(faceName)
		local rule = face and face:FindFirstChild("Rule") :: TextLabel?
		local status = face and face:FindFirstChild("Status") :: TextLabel?
		expect(
			faceName .. ": ROYALE RACE + status + one rule line",
			face and face:FindFirstChild("Title") and status and rule and rule.Text == "3 laps · every finisher wins a capsule",
			rule and rule.Text
		)
		expect(faceName .. ": status is the big line", status and status.Size.Y.Scale >= 0.4, status and status.Size.Y.Scale)
		expect(faceName .. ": no odds on the pad sign", face and face:FindFirstChild("Gold") == nil and face:FindFirstChild("Silver") == nil)
	end
	-- odds board beside the pad: both faces, large, readable rules + odds
	local board = c:FindFirstChild("OddsBoard") :: BasePart
	for _, faceName in { "SignFront", "SignBack" } do
		local face = board and board:FindFirstChild(faceName)
		local gt, g = face and face:FindFirstChild("GoldTitle") :: TextLabel?, face and face:FindFirstChild("Gold") :: TextLabel?
		local st, sv = face and face:FindFirstChild("SilverTitle") :: TextLabel?, face and face:FindFirstChild("Silver") :: TextLabel?
		expect(faceName .. ": GOLD rule", gt and gt.Text == "GOLD: top 3 (1st only if under 4 racers)", gt and gt.Text)
		expect(faceName .. ": SILVER rule", st and st.Text == "SILVER: everyone else who finishes", st and st.Text)
		expect(faceName .. ": Gold = Golden Parade odds", g and g.Text:find("Common 50%%") and g.Text:find("Legendary 5%%") and g.Text:find("Secret 0.5%%"), g and g.Text)
		expect(faceName .. ": Silver = normal odds", sv and sv.Text:find("Common 70%%") and sv.Text:find("Legendary 1.8%%") and sv.Text:find("Secret 0.2%%"), sv and sv.Text)
	end
	local toPad = PAD - (board :: BasePart).Position
	expect("odds board is beside the pad", board and (toPad * Vector3.new(1, 0, 1)).Magnitude < 18, board and ("%.1f studs"):format((toPad * Vector3.new(1, 0, 1)).Magnitude))
	expect("odds board text is large (board >= 14 x 9 studs)", board and board.Size.X >= 14 and board.Size.Y >= 9, board and board.Size)
	-- players walk up the start straight from the plaza (heading -Z): one face of each board looks at them
	local approach = Vector3.new(-115.5, 76, -925)
	for _, part in { (c :: any).Sign :: BasePart, board } do
		local toViewer = (approach - part.Position).Unit
		local facing = math.max(part.CFrame.LookVector:Dot(toViewer), -part.CFrame.LookVector:Dot(toViewer))
		expect(part.Name .. " faces the approach", facing > 0.6, ("%.2f"):format(facing))
	end
	-- walls: racers only
	local walls = c:FindFirstChild("Walls") :: Instance
	local okWalls, n = true, 0
	for _, w in (walls and walls:GetChildren() or {}) do
		n += 1
		local part = w :: BasePart
		okWalls = okWalls and part.CollisionGroup == RaceConfig.WALL_GROUP and part.CanCollide and part.Transparency == 1 and not part.CanQuery
	end
	expect("track walls: invisible, in the wall group", n >= 30 and okWalls, n)
	expect("walls collide with racers", PhysicsService:CollisionGroupsAreCollidable(RaceConfig.WALL_GROUP, RaceConfig.COLLISION_GROUP))
	expect("walls don't collide with anyone else", PhysicsService:CollisionGroupsAreCollidable(RaceConfig.WALL_GROUP, "Default") == false)
	-- painted chevrons point the race direction
	local function dirAt(pos: Vector3): Vector3
		local best, bd = Vector3.zero, math.huge
		for i, a in LINE do
			local b = LINE[i % #LINE + 1]
			local ab = (b - a) * Vector3.new(1, 0, 1)
			local t = math.clamp(((pos - a) * Vector3.new(1, 0, 1)):Dot(ab) / ab:Dot(ab), 0, 1)
			local d = ((a + ab * t - pos) * Vector3.new(1, 0, 1)).Magnitude
			if d < bd then
				bd, best = d, ab.Unit
			end
		end
		return best
	end
	local arrows = workspace.World.VelocityRoyale.VelocityRoyale_016B.Circuit.RouteArrows
	local wrong, bars = {}, 0
	for _, bar in arrows:GetChildren() do
		bars += 1
		-- each chevron arm runs from the tip backwards: pointing forward means its look vector is against the race
		if ((bar :: BasePart).CFrame.LookVector * Vector3.new(1, 0, 1)).Unit:Dot(dirAt((bar :: BasePart).Position)) > -0.2 then
			table.insert(wrong, bar.Name)
		end
	end
	expect("every chevron points the race direction", bars >= 10 and #wrong == 0, table.concat(wrong, ","))
	expect("racers never collide", PhysicsService:CollisionGroupsAreCollidable(RaceConfig.COLLISION_GROUP, RaceConfig.COLLISION_GROUP) == false)
	expect("Zone 6 catch odds untouched", WorkerCatalogue.RARITY_PER_MILLE.Common == 700 and WorkerCatalogue.RARITY_PER_MILLE.Secret == 2)
	expect("state Waiting", state() == "Waiting")
end)

scenario("eligibility: locked zone, full inventory, carrying", function()
	-- (a locked player can't normally stand on the pad: the Zone 6 gate turns them back)
	local ok, why = RaceService.eligible(A)
	expect("Zone 6 locked: not eligible", ok == false and tostring(why):find("Unlock Velocity Royale") ~= nil, why)
	put(A, PAD + Vector3.new(4, 3, 40)) -- off the pad first: the first race is open, an eligible A would start it
	put(B, PAD + Vector3.new(0, 3, 40))
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
	onPads({ A })
	task.wait(1.5)
	expect("no countdown for a full player", state() == "Waiting", state())
	expect("full: reason attribute", A:GetAttribute("RaceBlock") == "Your base is full", A:GetAttribute("RaceBlock"))
	local pad = ask(A, "pad")
	expect("full: big message on screen", pad.visible and pad.big == "Your base is full", pad.big)
	expect("full: billboard above the pad", pad.board == "Your base is full", pad.board)
	A:SetAttribute("CarryingNPC", true) -- (SIM: the carry flag without a real worker in hand)
	task.wait(0.6)
	pad = ask(A, "pad")
	expect("carrying: Drop your worker first", A:GetAttribute("RaceBlock") == "Drop your worker first" and pad.big == "Drop your worker first", pad.big, true)
	A:SetAttribute("CarryingNPC", nil)
	put(A, PAD + Vector3.new(4, 3, 40)) -- off the pad first: with room again A alone would start a race
	task.wait(0.6)
	pad = ask(A, "pad")
	expect("off the pad: reason cleared, no pad message", A:GetAttribute("RaceBlock") == nil and pad.visible == false, A:GetAttribute("RaceBlock"))
	expect("off the pad: billboard shows the sign status", pad.board == "Stand on the pad to race!", pad.board)
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
	-- join window: no big number yet, sign says "Join the race!"
	task.wait(2)
	local early = ask(B, "visible", { piece = "Count" })
	expect("no big number early in the join window", early.visible == false, early.visible)
	expect("sign says Join the race!", tostring(early.sign):find("Join the race!") ~= nil, early.sign)
	local padB = ask(B, "pad")
	expect("pad message: Join the race! + seconds", padB.visible and tostring(padB.big):match("^Join the race! %d+$") ~= nil, padB.big)
	expect("billboard: Join the race! + seconds", tostring(padB.board):match("^Join the race! %d+$") ~= nil, padB.board)
	expect("not frozen early in the join window", RaceService._test.frozen(A) == false)
	local hA = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local jumpBefore = { power = hA.JumpPower, height = hA.JumpHeight }
	waitUntil(RaceConfig.JOIN_WINDOW, function()
		local goAt = (course() :: Instance):GetAttribute("GoAt")
		return goAt and goAt - workspace:GetServerTimeNow() <= RaceConfig.COUNTDOWN - 0.4
	end)
	expect("frozen for the last 5 s", RaceService._test.frozen(A) and A:GetAttribute("RaceFrozen") == true and hA.WalkSpeed == 0 and hA.JumpPower == 0 and hA.JumpHeight == 0)
	local pushA
	task.spawn(function()
		pushA = ask(A, "push", { to = PAD + Vector3.new(0, 3, 14), seconds = 1.5, jump = true }, 6)
	end)
	local hudCount = ask(B, "hud", { pieces = { "Count" }, settle = 0.35 }, 10)
	expect("countdown fits phone screens", hudCount.hud and #hudCount.hud.issues == 0, hudCount.hud and table.concat(hudCount.hud.issues, "; "))
	waitUntil(4, function()
		return pushA ~= nil
	end)
	local moved = pushA and pushA.start and ((pushA.finish - pushA.start) * Vector3.new(1, 0, 1)).Magnitude
	expect("frozen: walking + jumping does nothing", moved and moved < 1 and pushA.rise < 0.5, pushA and ("moved %.2f rise %.2f"):format(moved or -1, pushA.rise or -1))
	expect("GO", waitState("Racing", RaceConfig.JOIN_WINDOW + 2))
	expect(
		"let go at GO (jump back)",
		not RaceService._test.frozen(A) and A:GetAttribute("RaceFrozen") == nil and hA.JumpPower == jumpBefore.power and hA.JumpHeight == jumpBefore.height
	)
	local c = course() :: Instance
	expect("2 racers", c:GetAttribute("Racers") == 2, c:GetAttribute("Racers"))
	expect("A racing, lap 1", A:GetAttribute("Racing") == true and A:GetAttribute("RaceLap") == 1)
	expect("racer collision group", root(A).CollisionGroup == RaceConfig.COLLISION_GROUP, root(A).CollisionGroup)
	local h = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	expect("fixed race speed", h.WalkSpeed == RaceConfig.WALK_SPEED, h.WalkSpeed)
	local cp1 = (c :: any).Route.CP1.Value.Position
	expect("next gate = CP1", A:GetAttribute("RaceNext") == 1, A:GetAttribute("RaceNext"))
	local routeA = ask(A, "route")
	expect("one glowing arch, over CP1", routeA.count == 14 and routeA.centre and ((routeA.centre - cp1) * Vector3.new(1, 0, 1)).Magnitude < 2, routeA.count)
	expect("HUD arrow showing", routeA.arrow == true)
	local routeB0 = ask(B, "route")
	expect("B sees only B's own arch", routeB0.count == 14)
	local runA
	task.spawn(function()
		runA = ask(A, "walk", { points = lapPoints(RaceConfig.LAPS) }, RaceConfig.TIME_LIMIT + 10)
	end)
	local hudRace = ask(B, "hud", { pieces = { "RacePanel", "LeaveRace" } }, 10)
	expect("race HUD (LAP + timer) fits phone screens", hudRace.hud and #hudRace.hud.issues == 0, hudRace.hud and table.concat(hudRace.hud.issues, "; "))
	local texts = ask(B, "texts")
	expect("big LAP counter shows LAP 1/3", texts.lap == "LAP 1/3" and texts.panel == true, texts.lap)
	local runB
	task.spawn(function()
		runB = ask(B, "walk", { points = lapPoints(RaceConfig.LAPS) }, RaceConfig.TIME_LIMIT + 10)
	end)
	waitUntil(30, function()
		return A:GetAttribute("RaceNext") == 3
	end)
	local cp3 = (c :: any).Route.CP3.Value.Position
	local routeA3 = ask(A, "route")
	expect("passed gates hidden: the arch moved to CP3", routeA3.count == 14 and routeA3.centre and ((routeA3.centre - cp3) * Vector3.new(1, 0, 1)).Magnitude < 2, routeA3.count)
	waitUntil(RaceConfig.TIME_LIMIT, function()
		return runB ~= nil
	end)
	waitUntil(RaceConfig.TIME_LIMIT, function()
		return runA ~= nil
	end)
	expect("both walked", runA and runA.answered and runB and runB.answered, ("stuck A %s B %s"):format(tostring(runA and runA.stuck), tostring(runB and runB.stuck)))
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
	local routeDone = ask(A, "route")
	expect("arch gone after the finish", routeDone.count == 0, routeDone.count)
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

scenario("race 2: walls, skipping checkpoints + time limit", function()
	expect("podium ends after 20 s", waitState("Waiting", RaceConfig.PODIUM_SECONDS + 3))
	local beforeA, beforeB = workers(A), workers(B)
	local markB = hubRace(B) and hubRace(B).id
	ask(A, "clear")
	ask(B, "clear")
	-- not racing: B walks + jumps over the inner barrier into the infield (the walls are not there for B)
	put(B, TRACK_SIDE, INFIELD)
	local free = ask(B, "push", { to = INFIELD, seconds = 3, jump = true }, 8)
	expect("non-racer walks through the track wall", free.finish and free.finish.X > INNER_EDGE_X + 1.5, free.finish and ("x %.1f"):format(free.finish.X))
	onPads({ A, B })
	task.wait(0.6)
	local padA = ask(A, "pad")
	expect("cooldown: Next race in m:ss on screen", padA.visible and tostring(padA.big):match("^Next race in %d:%d%d$") ~= nil, padA.big)
	expect("cooldown: same above the pad", tostring(padA.board):match("^Next race in %d:%d%d$") ~= nil, padA.board)
	expect("cooldown: no countdown", state() == "Waiting", state())
	startNow()
	expect("GO", waitState("Racing", RaceConfig.JOIN_WINDOW + 4))
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
	-- racing: the same walk + jump into the infield is stopped by the track wall
	put(B, TRACK_SIDE, INFIELD)
	local blocked = ask(B, "push", { to = INFIELD, seconds = 3, jump = true }, 8)
	expect(
		"racer can't cut across the infield",
		blocked.finish and blocked.finish.X < INNER_EDGE_X - 0.3 and B:GetAttribute("Racing") == true,
		blocked.finish and ("x %.1f"):format(blocked.finish.X)
	)
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
	expect("GO", waitState("Racing", RaceConfig.JOIN_WINDOW + 4))
	-- A "teleports" (exploit) from gate to gate
	for i = 1, RaceConfig.WARP_LIMIT do
		local g = RaceService._test.gates[i]
		root(A).CFrame = g.cf
		task.wait(0.3)
	end
	expect("A out for teleporting", A:GetAttribute("Racing") == nil, nil, true)
	local out = eventsOf(A, "Out")
	expect("A told no shortcuts", out[1] and tostring(out[1].reason):find("shortcut") ~= nil, out[1] and out[1].reason, true)
	put(A, PAD + Vector3.new(0, 3, 0))
	task.wait(0.6)
	local padA = ask(A, "pad")
	expect("race on: Race in progress, wait for the next one", padA.visible and padA.big == "Race in progress, wait for the next one", padA.big)
	expect("race on: billboard says so too", padA.board == "Race in progress, wait for the next one", padA.board)
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

scenario("race 4: Leave race button", function()
	expect("podium ends", waitState("Waiting", RaceConfig.PODIUM_SECONDS + 3))
	local beforeA, beforeB = workers(A), workers(B)
	local leftBefore = RaceService.stats.left
	ask(A, "clear")
	onPads({ A, B })
	startNow()
	expect("GO", waitState("Racing", RaceConfig.JOIN_WINDOW + 4))
	local shown = ask(A, "leave")
	expect("Leave race button shown while racing (>= 44 px tap)", shown.visible == true and (shown.height or 0) >= 44, shown.height)
	ask(A, "leave", { press = true })
	expect("A out of the race", A:GetAttribute("Racing") == nil and A:GetAttribute("RaceNext") == nil and root(A).CollisionGroup == "Default", root(A).CollisionGroup)
	local out = eventsOf(A, "Out")
	expect("A told they left", out[1] and tostring(out[1].reason):find("left the race") ~= nil, out[1] and out[1].reason)
	local after = ask(A, "leave")
	expect("button hidden after leaving", after.visible == false)
	expect("race goes on for B", state() == "Racing" and B:GetAttribute("Racing") == true, state())
	-- the walls no longer apply to A: walk + jump into the infield
	put(A, TRACK_SIDE, INFIELD)
	local free = ask(A, "push", { to = INFIELD, seconds = 3, jump = true }, 8)
	expect("A's track walls off", free.finish and free.finish.X > INNER_EDGE_X + 1.5, free.finish and ("x %.1f"):format(free.finish.X))
	ask(A, "leave", { press = true }) -- again, no longer racing: nothing happens
	expect("a second Leave from a non-racer does nothing", RaceService.stats.left == leftBefore + 1 and B:GetAttribute("Racing") == true)
	ask(B, "leave", { press = true })
	expect("last racer leaves: race over, no finishers", waitState("Podium", 3) and RaceService.lastRace and #RaceService.lastRace.finishers == 0)
	expect("leaving gives nothing", #newWorkers(A, beforeA) == 0 and #newWorkers(B, beforeB) == 0)
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
