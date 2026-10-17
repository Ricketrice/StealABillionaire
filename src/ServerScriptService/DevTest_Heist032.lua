-- Studio location: ServerScriptService.DevTest_Heist032 (Script)
-- DevTest_Heist032  (Milestone 032) -- STUDIO-ONLY test of the Boss Heist and the Speed stat. Inert unless
-- Studio started the session with StudioTestService and one of these arguments (in-memory save: ServerStorage
-- StudioMemoryStore = true). Turns StudioHeist / StudioSpeed on for the run and puts them back as they were.
--   "heist032:solo" (1 client, A):
--     flags      heist + speed switches off and on (world, published attributes, walk speed, HUD row)
--     dodges     A grabs (real prompt hold), a re-sent grab is refused; A jumps the stomp shockwave, steps off
--                the laser line, walks out of the locked searchlight: no hits; every warning on A's screen >= 1.5 s
--                before the hit moment; then A walks home: SAFE, reveal, saved; a re-sent grab / grant after that
--                gives nothing. Frame time measured (idle and during the attacks).
--     caught     A grabs and stands still: shield popped (HUD), then the capsule flies back; both hits came after
--                a >= 1.5 s warning shown on A's screen; A told "Caught", nothing gained
--     duplicates leave while carrying, rejoin (SIM), save marker (SIM), die while carrying, teleport past the
--                safe line (server-moved = what an exploiter's client could do), time limit (SIM); cash never lower
--     speed      trails: refused without cash, buy / re-send / equip / unequip / unknown; HUD Speed number; Store
--                Trails tab; own trail drawn; carry speed = half boost (D39); save; HUD at phone sizes while
--                carrying; Royale Race at its fixed speed with the best trail on; Speed switch off/on
--     off        heist switch off while carrying: nothing left in the world, carrier cleared
--   "heist032:duo" (2 clients, A + B):
--     chase      both grab; the robot targets the nearest carrier (A, standing still) and hits A twice (capsule
--                back); B runs home: SAFE, reveal, saved; every hit warned >= 1.5 s on A's screen first
--     trails     B's screen draws A's trail
-- Results: "@@T032|". Start `TAG=T032 tools/test_guard.sh <label>` BEFORE launching.

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
local mode = if okArgs and args == "heist032:solo" then "solo" elseif okArgs and args == "heist032:duo" then "duo" else nil
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
	print("@@T032|" .. line)
end
local function finish(state: string)
	local summary = ("%s mode=%s passed=%d failed=%d (simulated checks=%d)"):format(state, mode, passed, failed, simulated)
	print("@@T032|SUMMARY " .. summary)
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
	print("@@T032|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

local PlayerData, PlotService, WorkerInventory, ZoneProgress = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory"), mod("ZoneProgress")
local CashService, HeistService, RaceService = mod("CashService"), mod("HeistService"), mod("RaceService")
local HeistConfig = require(ReplicatedStorage:WaitForChild("HeistConfig")) :: any
local SpeedConfig = require(ReplicatedStorage:WaitForChild("SpeedConfig")) :: any
local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

local was = { heist = ServerStorage:GetAttribute("StudioHeist"), speed = ServerStorage:GetAttribute("StudioSpeed") }
ServerStorage:SetAttribute("StudioHeist", true)
ServerStorage:SetAttribute("StudioSpeed", true)

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
if not (ServerStorage:GetAttribute("StudioMemoryStore") == true or not PlayerData.isPersistent()) then
	finish("ABORTED: run heist032 on the in-memory save (ServerStorage StudioMemoryStore = true)")
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
bridge.Name = "Test032Bridge"
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
	local value = waitUntil(timeout or 10, function()
		return replies[id]
	end)
	replies[id] = nil
	return value or { answered = false }
end
for _, p in everyone do
	-- (inside a ScreenGui that survives respawns: A dies on purpose in "duplicates")
	local holder = Instance.new("ScreenGui")
	holder.Name = "Test032Helper"
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

local saves: { [Player]: number } = {}
for _, p in everyone do
	saves[p] = 0
end
PlayerData.onSaved(function(p, ok)
	if ok and saves[p] then
		saves[p] += 1
	end
end)

-- Helpers ---------------------------------------------------------------------------------------------------
local function root(p: Player): BasePart
	return (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
end
local function hum(p: Player): Humanoid
	return (p.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
end
local function put(p: Player, pos: Vector3, look: Vector3?)
	pcall(p.RequestStreamAroundAsync, p, pos)
	local character = p.Character :: Model
	character:PivotTo(if look then CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)) else CFrame.new(pos))
	root(p).AssemblyLinearVelocity = Vector3.zero
	task.wait(0.8)
end
local function heist(): Instance?
	return workspace.World.SkyCity:FindFirstChild("Heist")
end
local function now(): number
	return workspace:GetServerTimeNow()
end
local function data(p: Player): any
	return PlayerData.get(p) :: any
end
local function workerSet(p: Player): { [string]: any }
	local set = {}
	for _, w in (data(p) or { workers = {} }).workers do
		set[w.uid] = w
	end
	return set
end
local function newWorkers(p: Player, before: { [string]: any }): { any }
	local found = {}
	for uid, w in workerSet(p) do
		if not before[uid] then
			table.insert(found, w)
		end
	end
	return found
end
local function marker(p: Player): any
	local d = data(p)
	return d and d.hub and d.hub.heist
end
local function carrying(p: Player): boolean
	return p:GetAttribute("HeistCarrying") == true
end
local function opening(): any
	return HeistService._test.opening()
end
local lastOpening: string? = nil
local function open(): string?
	HeistService._test.close()
	task.wait(0.2)
	HeistService.forceOpen()
	local id = waitUntil(3, function()
		local h = heist()
		local o = opening()
		return h and h:GetAttribute("State") == "Open" and o and o.id ~= lastOpening and o.id
	end)
	lastOpening = id
	return id
end
local function attackNow(): any
	return HeistService._test.robot.attack
end
local function waitAttackOver(timeout: number?)
	waitUntil(timeout or 8, function()
		return attackNow() == nil
	end)
end
local function eventsOf(p: Player, kind: string): { any }
	local found = {}
	for _, e in (ask(p, "events").events or {}) do
		if e.kind == kind then
			table.insert(found, e)
		end
	end
	return found
end
local function isEpicPlus(workerId: string): boolean
	local w = WorkerCatalogue.get(workerId)
	return w ~= nil and (w.rarity == "Epic" or w.rarity == "Legendary" or w.rarity == "Secret")
end
local function near(a: number?, b: number, tolerance: number?): boolean
	return type(a) == "number" and math.abs(a - b) <= (tolerance or 0.05)
end
-- Every attack since `since`: fixed warning >= MIN_WARNING before its hit moment, hits only after it, and for
-- every hit on `p`, `p`'s own screen got the warning (Attack, or Lock for the searchlight) >= ~1.5 s before.
local function telegraphCheck(p: Player, since: number): ({ string }, number, number)
	local events = ask(p, "events").events or {}
	local issues, attacks, hits = {}, 0, 0
	for _, entry in HeistService.attackLog do
		if entry.startAt < since then
			continue
		end
		attacks += 1
		if entry.hitAt - entry.warnAt < HeistConfig.MIN_WARNING - 1e-6 then
			table.insert(issues, ("%s #%d warning %.2f s"):format(entry.kind, entry.id, entry.hitAt - entry.warnAt))
		end
		local shown = nil
		for _, e in events do
			if (e.kind == "Attack" and e.info.id == entry.id and entry.kind ~= "Searchlight") or (e.kind == "Lock" and e.info.id == entry.id) then
				shown = e.at
			end
		end
		if entry.kind ~= "Searchlight" or entry.spot then
			if not shown then
				table.insert(issues, ("%s #%d never shown on %s's screen"):format(entry.kind, entry.id, p.Name))
			elseif entry.hitAt - shown < HeistConfig.MIN_WARNING - 0.15 then
				table.insert(issues, ("%s #%d shown only %.2f s before its hit moment"):format(entry.kind, entry.id, entry.hitAt - shown))
			end
		end
		for _, h in entry.hits do
			hits += 1
			if h.at < entry.hitAt - 1e-6 then
				table.insert(issues, ("%s #%d hit before its time"):format(entry.kind, entry.id))
			end
		end
	end
	return issues, attacks, hits
end

local template = ServerStorage:WaitForChild("HeistVault032")
local GRAB = (template:WaitForChild("GrabSpot") :: BasePart).Position
local STAND_A = Vector3.new(GRAB.X + 4.5, 15.6, GRAB.Z + 2)
local STAND_B = Vector3.new(GRAB.X + 4.5, 15.6, GRAB.Z - 2)
local LOOK = Vector3.new(GRAB.X - 20, 15.6, GRAB.Z)
local HOME = { Vector3.new(-157, 15.3, -326), Vector3.new(-157, 15.3, -176), Vector3.new(-157, 9, -140), Vector3.new(-157, 3.3, -104) }
local CASH0, lowest = {}, {}
for _, p in everyone do
	CASH0[p] = CashService.get(p)
	lowest[p] = CASH0[p]
end
local watching = true
task.spawn(function() -- cash may only go up during the heist scenarios (income); trails are bought later
	while watching do
		for _, p in everyone do
			lowest[p] = math.min(lowest[p], CashService.get(p))
		end
		task.wait(0.2)
	end
end)

-- Solo scenarios ------------------------------------------------------------------------------------------------
local function flags()
	expect("heist world built with the Studio switch", waitUntil(5, heist) ~= nil)
	expect("HeistOn published", ReplicatedStorage:GetAttribute(HeistConfig.PUBLISHED) == true)
	local ui = ask(A, "ui")
	expect(
		"vault sign shows the approved odds (89/10/1)",
		type(ui.signOdds) == "string" and ui.signOdds:find("Epic 89%%") ~= nil and ui.signOdds:find("Legendary 10%%") ~= nil and ui.signOdds:find("Secret 1%%") ~= nil,
		ui.signOdds
	)
	expect("vault timer pill on the HUD", ui.pill == true, ui.pillText)
	expect("odds in the config = 89/10/1", HeistConfig.PER_MILLE.Epic == 890 and HeistConfig.PER_MILLE.Legendary == 100 and HeistConfig.PER_MILLE.Secret == 10)
	ServerStorage:SetAttribute("StudioHeist", false)
	expect("heist off: nothing in the world", waitUntil(3, function()
		return heist() == nil
	end) == true)
	expect("heist off: HeistOn cleared", ReplicatedStorage:GetAttribute(HeistConfig.PUBLISHED) == nil)
	expect("heist off: vault pill hidden", waitUntil(3, function()
		return ask(A, "ui").pill == false
	end) == true)
	ServerStorage:SetAttribute("StudioHeist", true)
	expect("heist on again: rebuilt", waitUntil(3, heist) ~= nil)
	expect("heist on again: sign text on the client", waitUntil(12, function()
		local s = ask(A, "ui").signOdds
		return type(s) == "string" and s:find("Epic 89%%") ~= nil
	end) == true)
	ServerStorage:SetAttribute("StudioSpeed", false)
	task.wait(1.6)
	expect("speed off: SpeedOn cleared", ReplicatedStorage:GetAttribute(SpeedConfig.PUBLISHED) == nil)
	expect("speed off: walk speed 16", near(hum(A).WalkSpeed, 16), hum(A).WalkSpeed)
	expect("speed off: no Speed row", ask(A, "ui").speedRow == false)
	ServerStorage:SetAttribute("StudioSpeed", true)
	task.wait(1.6)
	ui = ask(A, "ui")
	expect("speed on: Speed row 'Speed 100'", ui.speedRow == true and ui.speedText == "Speed 100", ui.speedText)
	expect("speed on: SpeedHud 100", A:GetAttribute("SpeedHud") == 100, A:GetAttribute("SpeedHud"))
end

local function dodges()
	local base = ask(A, "perf", { seconds = 4 }, 12)
	info("perf baseline (A's Studio client, heist idle)", ("avg %.1f ms, worst %.1f ms, heist parts %d"):format(base.avgMs or -1, base.worstMs or -1, base.heistParts or -1))
	HeistService._test.holdAttacks(now() + 1000) -- (no attacks while grabbing: the dodges below are forced one by one)
	local id = open()
	expect("vault opens on the Studio hook", id ~= nil)
	local before = workerSet(A)
	put(A, STAND_A, LOOK)
	ask(A, "clear")
	local g = ask(A, "grab", nil, 10)
	expect("prompt shown to A while open", g.enabled == true)
	expect("A grabbed a capsule", g.carrying == true and carrying(A))
	expect("capsule above A's head", (A.Character :: Model):FindFirstChild("BossCapsule") ~= nil)
	expect("carry speed = 16 x 0.85", near(hum(A).WalkSpeed, 13.6), hum(A).WalkSpeed)
	expect("A's grab marked for this opening", A:GetAttribute("HeistGrabbed") == id)
	local again = ask(A, "grab", nil, 10)
	expect("prompt hidden for A while carrying", again.enabled == false and HeistService._test.carriers()[A] ~= nil)
	expect("re-sent grab refused by the server", HeistService.grab(A) == false)
	expect("refusal message on A's screen", waitUntil(2, function()
		return ask(A, "ui").message == "You already have a Boss Capsule!"
	end) == true, ask(A, "ui").message)
	local ui = ask(A, "ui")
	expect("carrier panel shown", ui.panel == true)
	expect("both shields shown", ui.shields[1] == 0 and ui.shields[2] == 0, ("%s/%s"):format(tostring(ui.shields[1]), tostring(ui.shields[2])))
	expect("shield bubble drawn", ui.bubbles >= 1, ui.bubbles)
	expect("vault door swung open on the client", type(ui.doorLookX) == "number" and ui.doorLookX < 0.5, ui.doorLookX)
	expect("vault sign says OPEN", type(ui.signStatus) == "string" and ui.signStatus:find("OPEN") ~= nil, ui.signStatus)

	-- dodges in the open street, robot in front of A (A walks there: a carrier who teleports loses the capsule)
	waitAttackOver()
	ask(A, "walk", { points = { Vector3.new(-157, 15.6, -326), Vector3.new(-157, 15.6, -296) } }, 20)
	HeistService._test.placeRobot(Vector3.new(-157, 12.3, -306))
	task.wait(1)
	local dodgeStart = now()
	local perf: any = nil
	task.spawn(function()
		perf = ask(A, "perf", { seconds = 10 }, 20)
	end)
	-- stomp: jump when the shockwave arrives
	local function hits(): number
		return A:GetAttribute("HeistHits") or 0
	end
	local h0 = hits()
	expect("stomp forced", HeistService._test.attack("Stomp", A))
	local a = attackNow()
	local def = HeistConfig.ATTACKS.Stomp
	local d = ((root(A).Position - a.centre) * Vector3.new(1, 0, 1)).Magnitude
	local arrival = a.hitAt + d / def.waveSpeed
	local j = ask(A, "jumpAt", { at = arrival - 0.22 }, 10)
	waitAttackOver()
	local hitDetail = {}
	for _, h in a.log.hits do
		table.insert(hitDetail, h.detail or "?")
	end
	info(
		"stomp jump",
		("d %.1f, wave arrives %.2f s after hitAt; jump pressed %.2f, left ground %s, rise %.1f (JumpPower %s, JumpHeight %s); hits: %s"):format(
			d,
			arrival - a.hitAt,
			(j.jumpedAt or 0) - a.hitAt,
			if j.leftAt then ("%.2f"):format(j.leftAt - a.hitAt) else "never",
			j.rise or -1,
			tostring(j.jumpPower),
			tostring(j.jumpHeight),
			table.concat(hitDetail, " | ")
		)
	)
	expect("jumped the stomp shockwave: no hit", hits() == h0 and carrying(A), hits())
	h0 = hits()
	HeistService._test.holdAttacks(now() + 1000)
	-- laser: step off the red line before the sweep
	task.wait(0.5)
	expect("laser forced", HeistService._test.attack("Laser", A))
	a = attackNow()
	local along = Vector3.new(a.across.Z, 0, -a.across.X)
	ask(A, "stepAt", { at = a.startAt + 0.4, offset = -along * 9 }, 10)
	waitAttackOver()
	expect("stepped off the laser line: no hit", hits() == h0 and carrying(A), hits())
	h0 = hits()
	HeistService._test.holdAttacks(now() + 1000)
	-- searchlight: walk out of the circle once it locks
	task.wait(0.5)
	expect("searchlight forced", HeistService._test.attack("Searchlight", A))
	a = attackNow()
	ask(A, "stepAt", { at = a.warnAt + 0.3, offset = Vector3.new(12, 0, 0) }, 10)
	waitAttackOver()
	expect("walked out of the locked light: no hit", hits() == h0 and carrying(A), hits())
	expect("searchlight locked on a spot", a.spot ~= nil)
	expect("A still carrying after three dodges", carrying(A))
	local issues, attacks = telegraphCheck(A, dodgeStart)
	expect(
		"3 warnings, each fixed >= 1.5 s before its hit moment and on A's screen first",
		#issues == 0 and attacks == 3,
		table.concat(issues, "; ") .. (" (%d attacks)"):format(attacks)
	)
	waitUntil(10, function()
		return perf ~= nil
	end)
	if perf then
		info(
			"perf (A's Studio client, during the 3 attacks)",
			("avg %.1f ms, worst %.1f ms, heist parts %d, local fx parts max %d"):format(perf.avgMs or -1, perf.worstMs or -1, perf.heistParts or -1, perf.fxMax or -1)
		)
	end
	-- home with the attacks held: SAFE, reveal, saved
	HeistService._test.holdAttacks(now() + 1000)
	ask(A, "clear")
	local savesBefore = saves[A]
	local w = ask(A, "walk", { points = HOME }, 60)
	info("A walk home", ("%.1f s, stuck points %s"):format(w.time or -1, tostring(w.stuck)))
	expect("A delivered (not carrying)", waitUntil(3, function()
		return not carrying(A)
	end) == true)
	local got = newWorkers(A, before)
	expect("A got exactly one new worker", #got == 1, #got)
	expect("Boss Capsule worker is Epic or better", got[1] and isEpicPlus(got[1].id), got[1] and got[1].id)
	expect("hub.heist marker = this opening", marker(A) and marker(A).id == id and marker(A).uid == (got[1] and got[1].uid))
	expect("A saved after delivery", waitUntil(6, function()
		return saves[A] > savesBefore
	end) == true)
	expect("SAFE shown", #eventsOf(A, "Safe") >= 1)
	expect("reveal card for that worker", waitUntil(4, function()
		local r = eventsOf(A, "Reveal")
		return r[1] and got[1] and r[1].info.uid == got[1].uid
	end) == true)
	expect("walk speed back to 16 after the carry", near(hum(A).WalkSpeed, 16), hum(A).WalkSpeed)
	-- re-sent grab / grant for this opening after delivering
	local count = #data(A).workers
	local dup = HeistService.stats.duplicate
	expect("re-sent grant gives nothing", HeistService.grant(A, id) == nil and #data(A).workers == count and HeistService.stats.duplicate == dup + 1)
	expect("re-sent grab after delivering refused", HeistService.grab(A) == false and not carrying(A) and #data(A).workers == count)
end

local function caught()
	local id = open()
	local before = workerSet(A)
	local markerBefore = marker(A) and marker(A).id
	HeistService._test.placeRobot((template:FindFirstChild("GuardSpot") :: BasePart).Position)
	put(A, STAND_A, LOOK)
	ask(A, "clear")
	HeistService._test.holdAttacks(now() + 3)
	local start = now()
	expect("A grabbed", ask(A, "grab", nil, 10).carrying == true)
	expect("first hit pops the shield (HUD shows one shield left)", waitUntil(20, function()
		if (A:GetAttribute("HeistHits") or 0) == 1 then
			local ui = ask(A, "ui")
			return ui.shields[2] == 0.75 and ui.shields[1] == 0 and ui.bubbles == 0
		end
		return false
	end) == true)
	expect("second hit: capsule back in the vault", waitUntil(20, function()
		return not carrying(A)
	end) == true)
	local issues, attacks, hits = telegraphCheck(A, start)
	expect("both hits warned >= 1.5 s before, on A's screen first", #issues == 0 and hits == 2, table.concat(issues, "; ") .. (" (%d attacks, %d hits)"):format(attacks, hits))
	local lost = eventsOf(A, "Lost")
	expect("capsule flies back (Lost, caught)", lost[1] ~= nil and lost[1].info.userId == A.UserId and lost[1].info.reason == "caught")
	local shown = ask(A, "ui").message
	expect("A told: caught, coins kept", type(shown) == "string" and shown:find("Caught") ~= nil and shown:find("coins") ~= nil, shown)
	expect("caught: no worker, marker unchanged", #newWorkers(A, before) == 0 and (marker(A) and marker(A).id) == markerBefore)
	expect("caught: walk speed back to 16", waitUntil(2, function()
		return near(hum(A).WalkSpeed, 16)
	end) == true, hum(A).WalkSpeed)
	expect("caught: no second capsule this opening", HeistService.canGrab(A) == false and lastOpening == id)
end

local function duplicates()
	-- leave while carrying (what PlayerRemoving does), then the same player tries again
	local id3 = open()
	local beforeA = workerSet(A)
	put(A, STAND_A, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	expect("A grabbed (leave test)", ask(A, "grab", nil, 10).carrying == true)
	HeistService._test.drop(A)
	expect("left while carrying: capsule gone", not carrying(A) and (A.Character :: Model):FindFirstChild("BossCapsule") == nil)
	expect("left while carrying: no worker", #newWorkers(A, beforeA) == 0)
	expect("back after leaving: no second capsule this opening (SIM rejoin)", HeistService.canGrab(A) == false, nil, true)
	-- after a delivery in this opening, the save marker alone refuses it (SIM: memory cleared, as on a new visit)
	local keepGrab, keepMarker = HeistService._test.grabbed[A.UserId], data(A).hub.heist
	HeistService._test.grabbed[A.UserId] = nil
	data(A).hub.heist = { id = id3, cap = "Boss", uid = "test" }
	expect("save marker alone refuses this opening (SIM)", HeistService.canGrab(A) == false, nil, true)
	HeistService._test.grabbed[A.UserId], data(A).hub.heist = keepGrab, keepMarker
	-- die while carrying
	open()
	put(A, STAND_A, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	expect("A grabbed (die test)", ask(A, "grab", nil, 10).carrying == true)
	hum(A).Health = 0
	expect("died while carrying: capsule back", waitUntil(3, function()
		return not carrying(A)
	end) == true)
	waitUntil(15, function()
		local c = A.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil and c:FindFirstChild("BossCapsule") == nil
	end)
	task.wait(1.5)
	expect("after respawning: no second capsule this opening", HeistService.canGrab(A) == false)
	expect("died while carrying: no worker", #newWorkers(A, beforeA) == 0)
	-- teleport past the safe line (server-moved = what an exploiter's client could do)
	open()
	put(A, STAND_A, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	expect("A grabbed (teleport test)", ask(A, "grab", nil, 10).carrying == true)
	local z = HeistService._test.safeLine()
	put(A, Vector3.new(-157, 3.3, z + 8))
	expect("teleported past the line: not delivered", carrying(A) and #newWorkers(A, beforeA) == 0)
	ask(A, "walk", { points = { Vector3.new(-157, 3.3, z + 14) } }, 10)
	expect("walking on in the safe zone: still not delivered (no crossing)", carrying(A) and #newWorkers(A, beforeA) == 0)
	put(A, STAND_A, LOOK)
	put(A, Vector3.new(-157, 3.3, z + 8))
	expect("three teleport-sized jumps: capsule back (no shortcuts)", waitUntil(3, function()
		return not carrying(A)
	end) == true and #newWorkers(A, beforeA) == 0)
	-- time limit (SIM: the grab is aged instead of waiting 90 s)
	open()
	put(A, STAND_A, LOOK)
	expect("A grabbed (time test)", ask(A, "grab", nil, 10).carrying == true)
	local c = HeistService._test.carriers()[A]
	c.at -= HeistConfig.CARRY_LIMIT
	expect("time limit: capsule back (SIM clock)", waitUntil(2, function()
		return not carrying(A)
	end) == true, nil, true)
	expect("time limit: no worker", #newWorkers(A, beforeA) == 0)
	watching = false
	expect("cash never went down", lowest[A] >= CASH0[A], ("%d -> lowest %d"):format(CASH0[A], lowest[A]))
	info(
		"stats",
		("openings %d, grabs %d, safe %d, lost %d, hits %d, refused %d, duplicate %d, attacks %d"):format(
			HeistService.stats.openings,
			HeistService.stats.grabs,
			HeistService.stats.safe,
			HeistService.stats.lost,
			HeistService.stats.hits,
			HeistService.stats.refused,
			HeistService.stats.duplicate,
			HeistService.stats.attacks
		)
	)
end

local function speed()
	local function cash(p: Player): number
		return CashService.get(p)
	end
	local income = math.max(A:GetAttribute("Income") or 0, 1)
	if cash(A) < 1000000 then
		local held = cash(A)
		local r = ask(A, "speed", { action = "Buy", id = "gold" })
		expect(
			"not enough cash: refused, nothing charged",
			r.result and r.result.ok == false and r.result.text == "Not enough coins yet" and cash(A) >= held,
			r.result and r.result.text
		)
	else
		note("SKIP", "not enough cash", "A already has 1,000,000")
	end
	CashService.add(A, 1100000)
	local before = cash(A)
	local r = ask(A, "speed", { action = "Buy", id = "bubble" })
	local spent = before - cash(A)
	expect("bought Bubble Trail", r.ok and r.result and r.result.ok == true and A:GetAttribute("SpeedTrail") == "bubble", r.result and r.result.text)
	expect("charged 5,000", math.abs(spent - 5000) <= income * 3 + 1, spent)
	expect("walk speed x1.05", near(hum(A).WalkSpeed, 16.8), hum(A).WalkSpeed)
	expect("HUD Speed 105", waitUntil(2, function()
		return ask(A, "ui").speedText == "Speed 105"
	end) == true)
	before = cash(A)
	r = ask(A, "speed", { action = "Buy", id = "bubble" })
	expect("re-sent buy: nothing charged", r.result and r.result.ok and before - cash(A) <= income * 3 and cash(A) <= before + income * 3, before - cash(A))
	before = cash(A)
	r = ask(A, "speed", { action = "Buy", id = "gold" })
	expect("bought Gold Rush Trail (1,000,000)", r.result and r.result.ok and math.abs((before - cash(A)) - 1000000) <= income * 3 + 1, before - cash(A))
	expect("Gold Rush equipped: x1.30 (the cap)", near(hum(A).WalkSpeed, 20.8) and A:GetAttribute("SpeedHud") == 130, hum(A).WalkSpeed)
	expect("HUD Speed 130", waitUntil(2, function()
		return ask(A, "ui").speedText == "Speed 130"
	end) == true)
	r = ask(A, "speed", { action = "Equip", id = "bubble" })
	expect("equip an owned trail", r.result and r.result.ok and near(hum(A).WalkSpeed, 16.8))
	r = ask(A, "speed", { action = "Equip", id = "comet" })
	expect("equip a trail not owned: refused", r.result and r.result.ok == false and A:GetAttribute("SpeedTrail") == "bubble")
	r = ask(A, "speed", { action = "Buy", id = "rocket" })
	expect("unknown trail refused", r.result and r.result.ok == false)
	r = ask(A, "speed", { action = "Unequip" })
	expect("unequip: back to 16", r.result and r.result.ok and near(hum(A).WalkSpeed, 16) and A:GetAttribute("SpeedHud") == 100)
	ask(A, "speed", { action = "Equip", id = "gold" })
	local s = data(A).hub.speed
	expect("saved fields: owned + equipped", s and table.find(s.owned, "bubble") and table.find(s.owned, "gold") and s.on == "gold")
	local savesA = saves[A]
	PlayerData.save(A)
	expect("save with hub.speed written", saves[A] > savesA)
	local store = ask(A, "store")
	local cards = store.cards or {}
	local n = 0
	for _ in cards do
		n += 1
	end
	expect("Store Trails tab: 6 trails", store.tab == "trails" and n == #SpeedConfig.TRAILS, n)
	expect("Gold Rush card says Equipped", cards.gold and cards.gold.equipped == true and cards.gold.button == "Equipped")
	expect("Bubble card says Equip", cards.bubble and cards.bubble.owned == true and cards.bubble.button == "Equip")
	expect(
		"Comet card shows its price",
		cards.comet and cards.comet.owned == false and type(cards.comet.button) == "string" and cards.comet.button:find("Buy") ~= nil,
		cards.comet and cards.comet.button
	)
	task.wait(0.6)
	expect("A's own screen draws A's trail", (ask(A, "trails").seen or {})[tostring(A.UserId)] == true)
	-- carry speed with the best trail (half the boost, D39), and the HUD at phone sizes while carrying
	open()
	put(A, STAND_A, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	expect("A grabbed (speed test)", ask(A, "grab", nil, 10).carrying == true)
	task.wait(0.3)
	expect("carry speed with Gold Rush = 16 x 1.15 x 0.85 = 15.64 (half boost)", near(hum(A).WalkSpeed, 15.64), hum(A).WalkSpeed)
	local hud = ask(A, "hud", nil, 30).hud or { runs = 0, issues = { "no reply" } }
	expect("heist HUD fits at 7 sizes (panel, message, vault pill, Speed row)", hud.runs >= 21 and #hud.issues == 0, table.concat(hud.issues or {}, "; "))
	local phone = {}
	for k, v in hud.phone or {} do
		table.insert(phone, k .. " " .. v)
	end
	info("phone 667x375", table.concat(phone, ", "))
	HeistService._test.drop(A)
	task.wait(0.4)
	expect("carry over: walk speed 20.8", near(hum(A).WalkSpeed, 20.8), hum(A).WalkSpeed)
	-- the Royale Race ignores speed
	if RaceService.enabled() then
		local d = data(A)
		if not table.find(d.zones, "BillionaireHills") then
			table.insert(d.zones, "BillionaireHills")
		end
		ZoneProgress._test.publish(A)
		local course = ServerStorage:WaitForChild(RaceConfig.TEMPLATE)
		local pad = (course:FindFirstChild("StartPad") :: BasePart).Position
		local folder = workspace.World[RaceConfig.WORLD]:FindFirstChild(RaceConfig.FOLDER)
		waitUntil(30, function()
			return folder and folder:GetAttribute("State") == "Waiting"
		end)
		RaceService._test.readyNow()
		put(A, pad + Vector3.new(0, 3, 0), pad + Vector3.new(0, 3, 10))
		local racing = waitUntil(30, function()
			return A:GetAttribute("Racing") == true
		end)
		expect("A races with Gold Rush on", racing == true)
		task.wait(1)
		expect("race speed fixed at 16 (trail ignored)", near(hum(A).WalkSpeed, RaceConfig.WALK_SPEED), hum(A).WalkSpeed)
		ask(A, "leaveRace")
		expect("left the race: trail speed back", waitUntil(3, function()
			return near(hum(A).WalkSpeed, 20.8)
		end) == true, hum(A).WalkSpeed)
	else
		note("SKIP", "race speed", "StudioRace is off in this place")
	end
	ServerStorage:SetAttribute("StudioSpeed", false)
	task.wait(1.6)
	expect("speed switch off: everyone at 16", near(hum(A).WalkSpeed, 16), hum(A).WalkSpeed)
	expect("speed switch off: trail no longer drawn", waitUntil(2, function()
		return (ask(A, "trails").seen or {})[tostring(A.UserId)] == false
	end) == true)
	ServerStorage:SetAttribute("StudioSpeed", true)
	task.wait(1.6)
	expect("speed switch on: trail speed back", near(hum(A).WalkSpeed, 20.8), hum(A).WalkSpeed)
end

local function off()
	open()
	put(A, STAND_A, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	expect("A carrying before the switch goes off", ask(A, "grab", nil, 10).carrying == true)
	ServerStorage:SetAttribute("StudioHeist", false)
	expect("heist off: world removed", waitUntil(3, function()
		return heist() == nil
	end) == true)
	expect("heist off: carrier cleared, capsule gone, walking speed", not carrying(A) and (A.Character :: Model):FindFirstChild("BossCapsule") == nil and waitUntil(2, function()
		return near(hum(A).WalkSpeed, 20.8)
	end) == true, hum(A).WalkSpeed)
	expect("heist off: HUD panel and pill gone", waitUntil(2, function()
		local ui = ask(A, "ui")
		return ui.panel == false and ui.pill == false
	end) == true)
end

-- Duo scenarios -------------------------------------------------------------------------------------------------
local function chase()
	local id = open()
	expect("vault open", id ~= nil)
	local beforeA, beforeB = workerSet(A), workerSet(B)
	HeistService._test.placeRobot((template:FindFirstChild("GuardSpot") :: BasePart).Position)
	put(A, STAND_A, LOOK)
	put(B, STAND_B, LOOK)
	ask(A, "clear")
	ask(B, "clear")
	local start = now()
	HeistService._test.holdAttacks(now() + 6)
	expect("A grabbed", ask(A, "grab", nil, 10).carrying == true)
	expect("B grabbed", ask(B, "grab", nil, 10).carrying == true)
	expect("two shield bubbles on B's screen", ask(B, "ui").bubbles >= 2, ask(B, "ui").bubbles)
	HeistService._test.holdAttacks(now() + 1.5)
	local savesB = saves[B]
	local walkDone, walkReply = false, nil :: any
	task.spawn(function()
		walkReply = ask(B, "walk", { points = HOME }, 60)
		walkDone = true
	end)
	expect("robot targets the nearest carrier (A)", waitUntil(8, function()
		local h = heist()
		return h and carrying(A) and carrying(B) and h:GetAttribute("RobotTarget") == A.UserId
	end) == true)
	expect("A hit twice: capsule back in the vault", waitUntil(30, function()
		return not carrying(A)
	end) == true)
	local issues, attacks, hits = telegraphCheck(A, start)
	local hitsOnA = 0
	for _, entry in HeistService.attackLog do
		for _, h in entry.hits do
			if h.userId == A.UserId and h.at >= start then
				hitsOnA += 1
			end
		end
	end
	expect("A took exactly 2 hits", hitsOnA == 2, hitsOnA)
	expect("every attack warned >= 1.5 s before its hit, on A's screen first", #issues == 0, table.concat(issues, "; ") .. (" (%d attacks, %d hits)"):format(attacks, hits))
	waitUntil(50, function()
		return walkDone
	end)
	info("B walk home", ("%.1f s, stuck %s"):format(walkReply and walkReply.time or -1, tostring(walkReply and walkReply.stuck)))
	expect("B escaped: delivered", waitUntil(3, function()
		return not carrying(B) and marker(B) ~= nil and marker(B).id == id
	end) == true, marker(B) and marker(B).id)
	local gotB = newWorkers(B, beforeB)
	expect("B got exactly one worker, Epic or better", #gotB == 1 and isEpicPlus(gotB[1].id), #gotB)
	expect("B saved", waitUntil(6, function()
		return saves[B] > savesB
	end) == true)
	expect("B's reveal card", waitUntil(4, function()
		local r = eventsOf(B, "Reveal")
		return r[1] and gotB[1] and r[1].info.uid == gotB[1].uid
	end) == true)
	expect("A got nothing", #newWorkers(A, beforeA) == 0)
	local lost = eventsOf(B, "Lost")
	expect("B's screen sees A's capsule fly back", lost[1] ~= nil and lost[1].info.userId == A.UserId and lost[1].info.reason == "caught")
	watching = false
	expect("cash never went down (A, B)", lowest[A] >= CASH0[A] and lowest[B] >= CASH0[B])
end

local function trails()
	CashService.add(A, 10000)
	local r = ask(A, "speed", { action = "Buy", id = "bubble" })
	expect("A bought a trail", r.result and r.result.ok and A:GetAttribute("SpeedTrail") == "bubble")
	put(B, root(A).Position + Vector3.new(8, 0, 0))
	expect("B's screen draws A's trail", waitUntil(3, function()
		return (ask(B, "trails").seen or {})[tostring(A.UserId)] == true
	end) == true)
end

if mode == "solo" then
	scenario("flags", flags)
	scenario("dodges", dodges)
	scenario("caught", caught)
	scenario("duplicates", duplicates)
	scenario("speed", speed)
	scenario("off", off)
else
	scenario("chase", chase)
	scenario("trails", trails)
end

ServerStorage:SetAttribute("StudioHeist", was.heist)
ServerStorage:SetAttribute("StudioSpeed", was.speed)
finish("DONE")
