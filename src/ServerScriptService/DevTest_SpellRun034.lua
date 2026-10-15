-- Studio location: ServerScriptService.DevTest_SpellRun034 (Script)
-- DevTest_SpellRun034  (Milestone 034) -- STUDIO-ONLY two-player test of Spell Run (the race system on the Ember
-- Academy parkour course; replaces race031's circuit checks). Inert unless Studio started the session with
-- StudioTestService and the argument "spellrun034" (2 clients, in-memory save: ServerStorage StudioMemoryStore = true).
-- Covers: flag off/on (course under World.EmberAcademy, sign "SPELL RUN" + "5 rune gates" rule, odds board, route,
-- PvP-safe volumes), eligibility (locked Ember Academy, carrying), race 1 (both racers run the course on their own
-- clients with real MoveTo + jumps, gaps and sliding books included: both finish, small-race rule 1st Gold / 2nd
-- Silver, one Ember Academy creature each, hub.race marker, measured times vs RaceConfig.TIME_LIMIT), race 2 (a racer
-- who falls off is popped back at their last rune gate and keeps racing; a non-racer who falls is popped to the pad;
-- Leave = out, no reward), flag off. Results: "@@T034S|".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "spellrun034") then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s: %s | %s"):format(kind, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T034S|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d (simulated checks=%d)"):format(state, passed, failed, simulated)
	print("@@T034S|SUMMARY " .. summary)
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
	print("@@T034S|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
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
if not (ServerStorage:GetAttribute("StudioMemoryStore") == true or not PlayerData.isPersistent()) then
	finish("ABORTED: run spellrun034 on the in-memory save (ServerStorage StudioMemoryStore = true)")
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
bridge.Name = "Test034SBridge"
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
local home = workspace.World:WaitForChild(RaceConfig.WORLD)
local geometry = home:WaitForChild(RaceConfig.COURSE)
local function course(): Instance?
	return home:FindFirstChild(RaceConfig.FOLDER)
end
local function state(): string?
	local c = course()
	return c and c:GetAttribute("State")
end
local template = ServerStorage:WaitForChild(RaceConfig.TEMPLATE)
local PAD = (template.StartPad :: BasePart).Position
local Y0 = PAD.Y - 0.3
local function at(x: number, dy: number, z: number): Vector3
	return Vector3.new(x, Y0 + dy + 3, z)
end
-- the racing line (course points from tools/build034/B4_SpellRun): the client walker jumps at every gap/step itself
local ROUTE = {
	at(-80, 0, -760),
	at(-48, 0, -760),
	at(-37, 0, -762),
	at(-36, 2, -774),
	at(-26, 4, -790),
	at(-38, 6, -806),
	at(-27, 8, -822),
	at(-37, 10, -838),
	at(-34, 12, -856),
	at(-34, 12.5, -876),
	at(-34, 13, -892),
	at(-34, 13.5, -908),
	at(-34, 14, -926),
	at(-60, 15.4, -926),
	at(-92, 18, -926),
	at(-100, 18, -924),
	at(-100, 16, -910),
	at(-100, 14, -894),
	at(-100, 12, -878),
	at(-100, 10, -862),
	at(-100, 9, -853),
	at(-100, 0, -832),
	at(-100, 0, -818),
}
local function upTo(n: number): { Vector3 }
	return table.move(ROUTE, 1, n, 1, {})
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
	for _, z in { "SunkenKingdom", "BillionaireHills" } do
		if not table.find(data.zones, z) then
			table.insert(data.zones, z)
		end
	end
	ZoneProgress._test.publish(p)
end
local function lock(p: Player)
	local data = PlayerData.get(p) :: any
	for _, z in { "SunkenKingdom", "BillionaireHills" } do
		local i = table.find(data.zones, z)
		if i then
			table.remove(data.zones, i)
		end
	end
	ZoneProgress._test.publish(p)
end
local function onPads(players: { Player })
	for i, p in players do
		put(p, PAD + Vector3.new(0, 3, if i == 1 then 2 else -2), PAD + Vector3.new(10, 0, 0))
	end
end
local function startNow()
	ServerStorage:SetAttribute("StudioRaceNow", true)
end
local function waitState(want: string, seconds: number): boolean
	return waitUntil(seconds, function()
		return state() == want
	end) ~= nil
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
local times = {}

-- Scenarios ---------------------------------------------------------------------------------------------------
scenario("flag off", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, nil)
	task.wait(0.5)
	expect("no live course", course() == nil)
	expect("RaceOn not published", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == nil)
	expect("the course geometry is always there", geometry:FindFirstChild("FallZone") ~= nil and geometry:FindFirstChild("PadSpot") ~= nil)
	expect("one lap = start to finish", RaceConfig.LAPS == 1)
	expect("time limit 135 s (D45)", RaceConfig.TIME_LIMIT == 135, RaceConfig.TIME_LIMIT)
end)

scenario("flag on: course, sign, odds, route", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, true)
	expect("course built under Ember Academy", waitUntil(5, course) ~= nil)
	local c = course() :: Instance
	expect("RaceOn published", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == true)
	for _, name in { "StartPad", "Sign", "OddsBoard", "Name1", "Name2", "Name3", "SafeVolume", "SafeVolume2", "Route" } do
		expect(name .. " in the world", c:FindFirstChild(name) ~= nil)
	end
	expect("server gates stay on the server", c:FindFirstChild("Gates") == nil)
	local route = c:FindFirstChild("Route") :: Instance
	expect("route = 5 rune gates + finish", route and #route:GetChildren() == 6, route and #route:GetChildren())
	expect("Checkpoints attribute = 5", c:GetAttribute("Checkpoints") == 5, c:GetAttribute("Checkpoints"))
	for _, faceName in { "SignFront", "SignBack" } do
		local face = (c :: any).Sign:FindFirstChild(faceName)
		local title = face and face:FindFirstChild("Title") :: TextLabel?
		local rule = face and face:FindFirstChild("Rule") :: TextLabel?
		expect(faceName .. ": SPELL RUN title", title and title.Text == "SPELL RUN", title and title.Text)
		expect(faceName .. ": rune gate rule", rule and rule.Text == "5 rune gates · every finisher wins a capsule", rule and rule.Text)
	end
	local board = c:FindFirstChild("OddsBoard") :: BasePart
	local face = board and board:FindFirstChild("SignFront")
	local g, sv = face and face:FindFirstChild("Gold") :: TextLabel?, face and face:FindFirstChild("Silver") :: TextLabel?
	expect("odds: Gold = Golden Parade odds", g and g.Text:find("Common 50%%") and g.Text:find("Secret 0.5%%"), g and g.Text)
	expect("odds: Silver = normal odds", sv and sv.Text:find("Common 70%%") and sv.Text:find("Secret 0.2%%"), sv and sv.Text)
	expect("odds board beside the pad", board and ((PAD - board.Position) * Vector3.new(1, 0, 1)).Magnitude < 18)
	local safe = 0
	for _, v in c:GetChildren() do
		if v:HasTag("PvPSafeZone") then
			safe += 1
		end
	end
	expect("pad + course are PvP-safe", safe == 2, safe)
	expect("catch odds untouched", WorkerCatalogue.RARITY_PER_MILLE.Common == 700 and WorkerCatalogue.RARITY_PER_MILLE.Secret == 2)
	expect("Ember Academy has 9 creatures", #WorkerCatalogue.ZONES.BillionaireHills == 9, #WorkerCatalogue.ZONES.BillionaireHills)
	expect("state Waiting", state() == "Waiting")
end)

scenario("eligibility", function()
	put(A, PAD + Vector3.new(-20, 3, 0))
	put(B, PAD + Vector3.new(-20, 3, 6))
	lock(A)
	local ok, why = RaceService.eligible(A)
	expect("Ember Academy locked: not eligible", ok == false and tostring(why):find("Unlock Ember Academy") ~= nil, why)
	unlock(A)
	unlock(B)
	ok = RaceService.eligible(A)
	expect("unlocked: eligible", ok == true)
	A:SetAttribute("CarryingNPC", true) -- (SIM: the carry flag without a real creature in hand)
	ok, why = RaceService.eligible(A)
	expect("carrying: Drop your creature first", ok == false and why == "Drop your creature first", why, true)
	A:SetAttribute("CarryingNPC", nil)
end)

scenario("race 1: both run the course", function()
	local beforeA, beforeB = workers(A), workers(B)
	ask(A, "clear")
	ask(B, "clear")
	onPads({ A, B })
	startNow()
	expect("countdown", waitState("Countdown", 6), state())
	expect("racing", waitState("Racing", RaceConfig.JOIN_WINDOW + 4), state())
	expect("both racing", A:GetAttribute("Racing") == true and B:GetAttribute("Racing") == true)
	task.wait(0.3)
	local runs = {}
	for i, p in { A, B } do
		task.spawn(function()
			runs[i] = ask(p, "run", { points = ROUTE }, RaceConfig.TIME_LIMIT + 15)
		end)
	end
	expect(
		"both runs ended",
		waitUntil(RaceConfig.TIME_LIMIT + 20, function()
			return runs[1] and runs[2]
		end)
	)
	note(
		"INFO",
		"runs",
		("A %.1f s (stuck %s, jumps %s, falls %s) · B %.1f s (stuck %s, jumps %s, falls %s)"):format(
			runs[1] and runs[1].time or -1,
			tostring(runs[1] and runs[1].stuck),
			tostring(runs[1] and runs[1].jumps),
			tostring(runs[1] and runs[1].falls),
			runs[2] and runs[2].time or -1,
			tostring(runs[2] and runs[2].stuck),
			tostring(runs[2] and runs[2].jumps),
			tostring(runs[2] and runs[2].falls)
		)
	)
	expect("race over", waitState("Podium", 8), state())
	local last = RaceService.lastRace
	local fin = last and last.finishers or {}
	expect("both finished", #fin == 2, #fin)
	for _, f in fin do
		table.insert(times, f.time)
		note("INFO", "finish", ("%s place %d %s %.1f s"):format(f.name, f.place, f.capsule, f.time))
	end
	expect("small race: 1st Gold", fin[1] and fin[1].capsule == "Gold")
	expect("small race: 2nd Silver", fin[2] and fin[2].capsule == "Silver")
	for _, pair in { { A, beforeA }, { B, beforeB } } do
		local got = newWorkers(pair[1], pair[2])
		expect(pair[1].Name .. " got exactly one creature", #got == 1, #got)
		expect(pair[1].Name .. ": an Ember Academy creature", got[1] and WorkerCatalogue.get(got[1].id).zone == "BillionaireHills", got[1] and got[1].id)
		local rec = hubRace(pair[1])
		expect(pair[1].Name .. ": hub.race marker saved", rec and rec.id == (last and last.id) and rec.uid == (got[1] and got[1].uid))
	end
	local finishA = eventsOf(A, "Finish")
	expect("A told the result once", #finishA == 1, #finishA)
	expect("a second capsule for race 1 is refused", RaceService.grant(A, last.id, 1, "Gold") == nil)
end)

scenario("race 2: falls pop back, leave", function()
	expect("podium -> waiting", waitState("Waiting", RaceConfig.PODIUM_SECONDS + 5), state())
	local beforeA = workers(A)
	local pops0 = RaceService.stats.pops
	onPads({ A })
	put(B, PAD + Vector3.new(-20, 3, 0))
	startNow()
	expect("racing", waitState("Racing", RaceConfig.JOIN_WINDOW + 8), state())
	-- A runs to the first landing (CP1 + CP2 passed), then falls off the far side
	local run = ask(A, "run", { points = upTo(9) }, 40)
	expect("A reached landing 1", run.answered and run.stuck == 0, run.stuck)
	expect("A passed CP2", A:GetAttribute("RaceNext") == 3, A:GetAttribute("RaceNext"))
	put(A, Vector3.new(-34, Y0 - 30, -858))
	local back = waitUntil(4, function()
		local r = root(A)
		return r and r.Position.Y > Y0 + 8 and (r.Position * Vector3.new(1, 0, 1) - Vector3.new(-34, 0, -858)).Magnitude < 12
	end)
	-- (SIM: the fall is a teleport straight down under landing 1, not a real misstep)
	expect("A popped back at rune gate 2", back ~= nil, root(A).Position, true)
	expect("A still racing after the fall", A:GetAttribute("Racing") == true, nil, true)
	expect("A's next gate unchanged", A:GetAttribute("RaceNext") == 3, A:GetAttribute("RaceNext"), true)
	expect("A told 'Pop'", #eventsOf(A, "Pop") >= 1)
	-- a non-racer falling under the course goes to the pad spot
	put(B, Vector3.new(-60, Y0 - 30, -800))
	local spot = (geometry :: any).PadSpot.Position
	expect("B (not racing) popped to the pad", waitUntil(4, function()
		return (root(B).Position - spot).Magnitude < 6
	end) ~= nil, root(B).Position, true)
	expect("pops counted", RaceService.stats.pops >= pops0 + 2, RaceService.stats.pops - pops0)
	-- Leave: out now, no reward
	ask(A, "leave")
	expect("A left the race", waitUntil(3, function()
		return A:GetAttribute("Racing") == nil
	end) ~= nil)
	expect("race ended (no racers)", waitState("Podium", 6) or waitState("Waiting", 6), state())
	expect("leaving gives nothing", #newWorkers(A, beforeA) == 0)
end)

scenario("time limit vs measured runs", function()
	local slowest = 0
	for _, t in times do
		slowest = math.max(slowest, t)
	end
	note("INFO", "time limit", ("slowest %.1f s, limit %d s, 2x slowest %.1f s"):format(slowest, RaceConfig.TIME_LIMIT, slowest * 2))
	expect("limit leaves room (>= 1.5x the slowest run)", slowest > 0 and RaceConfig.TIME_LIMIT >= slowest * 1.5, slowest)
end)

scenario("flag off again", function()
	ServerStorage:SetAttribute(RaceConfig.STUDIO_ATTRIBUTE, nil)
	expect("course removed", waitUntil(4, function()
		return course() == nil
	end) ~= nil)
	expect("RaceOn cleared", ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == nil)
end)

finish("COMPLETE")
