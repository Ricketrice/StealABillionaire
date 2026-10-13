-- Studio location: ServerScriptService.DevTest_Heist032 (Script)
-- DevTest_Heist032  (Milestone 032) -- STUDIO-ONLY two-player test of the Boss Heist and the Speed stat. Inert
-- unless Studio started the session with StudioTestService and the argument "heist032" (2 clients, in-memory
-- save: ServerStorage StudioMemoryStore = true). Turns StudioHeist / StudioSpeed on for the run and puts them
-- back as they were. Scenarios:
--   flags      heist + speed switches off and on (world, published attributes, walk speed, HUD row)
--   dodges     A grabs (real prompt hold), a second grab is refused; A jumps the stomp shockwave, steps off the
--              laser line, walks out of the locked searchlight: no hits; then A walks home: SAFE, reveal, saved
--   chase      both grab; the robot targets the nearest carrier (A, standing still) and hits A twice (shield,
--              then the capsule flies back); B runs home: SAFE, reveal, saved. Every hit came >= 1.5 s after its
--              fixed warning and after the client got it. Frame time + heist parts measured on A's client.
--   duplicates re-sent grab and grant, leave while carrying, rejoin (SIM), die while carrying, teleport past the
--              safe line (server-moved, = an exploit), time limit (SIM); one capsule per opening, cash never lower
--   speed      trails: buy / re-send / equip / unequip / refused; HUD Speed number; Store Trails tab; trail seen
--              by the other client; carry speed with the cap; save; HUD at phone sizes while carrying; the Royale
--              Race runs at its fixed speed with the best trail on; Speed switch off/on
--   off        heist switch off at the end: nothing left in the world
-- Results: "@@T032|". Start `TAG=T032 tools/test_guard.sh heist032` BEFORE launching.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "heist032") then
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
	print("@@T032|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d (simulated checks=%d)"):format(state, passed, failed, simulated)
	print("@@T032|SUMMARY " .. summary)
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
	return n >= 2
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
if not (A and B and ready(A) and ready(B)) then
	finish("ABORTED: needs two loaded players")
	return
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
for _, p in { A, B } do
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
	return helpers[A] and helpers[B]
end)

local saves: { [Player]: number } = { [A] = 0, [B] = 0 }
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

local template = ServerStorage:WaitForChild("HeistVault032")
local GRAB = (template:WaitForChild("GrabSpot") :: BasePart).Position
local STAND_A = Vector3.new(GRAB.X + 4.5, 15.6, GRAB.Z + 2)
local STAND_B = Vector3.new(GRAB.X + 4.5, 15.6, GRAB.Z - 2)
local LOOK = Vector3.new(GRAB.X - 20, 15.6, GRAB.Z)
local HOME = { Vector3.new(-157, 15.3, -326), Vector3.new(-157, 15.3, -176), Vector3.new(-157, 9, -140), Vector3.new(-157, 3.3, -104) }
local CASH0 = { [A] = CashService.get(A), [B] = CashService.get(B) }
local lowest = { [A] = CASH0[A], [B] = CASH0[B] }
local watching = true
task.spawn(function() -- cash may only go up during the heist scenarios (income); trails are bought later
	while watching do
		for _, p in { A, B } do
			lowest[p] = math.min(lowest[p], CashService.get(p))
		end
		task.wait(0.2)
	end
end)

-- Scenarios ---------------------------------------------------------------------------------------------------
scenario("flags", function()
	expect("heist world built with the Studio switch", waitUntil(5, heist) ~= nil)
	expect("HeistOn published", ReplicatedStorage:GetAttribute(HeistConfig.PUBLISHED) == true)
	local ui = ask(A, "ui")
	expect("vault sign shows the odds", type(ui.signOdds) == "string" and ui.signOdds:find("Epic 85%%") ~= nil and ui.signOdds:find("Secret 2%%") ~= nil, ui.signOdds)
	expect("vault timer pill on the HUD", ui.pill == true, ui.pillText)
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
end)

scenario("dodges", function()
	HeistService._test.holdAttacks(now() + 1000) -- (no attacks while grabbing: the dodges below are forced one by one)
	local id = open()
	expect("vault opens on the Studio hook", id ~= nil)
	local before = workerSet(A)
	put(A, STAND_A, LOOK)
	local g = ask(A, "grab", nil, 10)
	expect("prompt shown to A while open", g.enabled == true)
	expect("A grabbed a capsule", g.carrying == true and carrying(A))
	expect("capsule above A's head", (A.Character :: Model):FindFirstChild("BossCapsule") ~= nil)
	expect("carry speed = 16 x 0.85", near(hum(A).WalkSpeed, 13.6), hum(A).WalkSpeed)
	expect("A's grab marked for this opening", A:GetAttribute("HeistGrabbed") == id)
	local again = ask(A, "grab", nil, 10)
	expect("prompt hidden for A while carrying", again.enabled == false and HeistService._test.carriers()[A] ~= nil)
	-- a re-sent trigger (what an exploit could send) is refused by the server
	expect("re-sent grab refused by the server", HeistService.grab(A) == false)
	expect("refusal message on A's screen", waitUntil(2, function()
		return ask(A, "ui").message == "You already have a Boss Capsule!"
	end) == true, ask(A, "ui").message)
	local ui = ask(A, "ui")
	expect("carrier panel shown", ui.panel == true)
	expect("both shields shown", ui.shields[1] == 0 and ui.shields[2] == 0, ui.shields)
	expect("shield bubble drawn", ui.bubbles >= 1, ui.bubbles)
	expect("vault door swung open on the client", type(ui.doorLookX) == "number" and ui.doorLookX < 0.5, ui.doorLookX)

	-- dodges in the open street, robot in front of A (A walks there: a carrier who teleports loses the capsule)
	HeistService._test.holdAttacks(now() + 1000)
	waitAttackOver()
	ask(A, "walk", { points = { Vector3.new(-157, 15.6, -326), Vector3.new(-157, 15.6, -296) } }, 20)
	HeistService._test.placeRobot(Vector3.new(-157, 12.3, -306))
	task.wait(1)
	-- stomp: jump when the shockwave arrives
	expect("stomp forced", HeistService._test.attack("Stomp", A))
	local a = attackNow()
	local def = HeistConfig.ATTACKS.Stomp
	local d = ((root(A).Position - a.centre) * Vector3.new(1, 0, 1)).Magnitude
	ask(A, "jumpAt", { at = a.hitAt + d / def.waveSpeed - 0.22 }, 10)
	waitAttackOver()
	expect("jumped the stomp shockwave: no hit", (A:GetAttribute("HeistHits") or 0) == 0, A:GetAttribute("HeistHits"))
	HeistService._test.holdAttacks(now() + 1000)
	-- laser: step off the red line before the sweep
	task.wait(0.5)
	expect("laser forced", HeistService._test.attack("Laser", A))
	a = attackNow()
	local along = Vector3.new(a.across.Z, 0, -a.across.X)
	ask(A, "stepAt", { at = a.startAt + 0.4, offset = -along * 9 }, 10)
	waitAttackOver()
	expect("stepped off the laser line: no hit", (A:GetAttribute("HeistHits") or 0) == 0, A:GetAttribute("HeistHits"))
	HeistService._test.holdAttacks(now() + 1000)
	-- searchlight: walk out of the circle once it locks
	task.wait(0.5)
	expect("searchlight forced", HeistService._test.attack("Searchlight", A))
	a = attackNow()
	ask(A, "stepAt", { at = a.warnAt + 0.3, offset = Vector3.new(12, 0, 0) }, 10)
	waitAttackOver()
	expect("walked out of the locked light: no hit", (A:GetAttribute("HeistHits") or 0) == 0, A:GetAttribute("HeistHits"))
	expect("searchlight locked on a spot", a.spot ~= nil)
	expect("A still carrying after three dodges", carrying(A))
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
	local safe = eventsOf(A, "Safe")
	expect("SAFE shown", #safe >= 1)
	expect("reveal card for that worker", waitUntil(4, function()
		local r = eventsOf(A, "Reveal")
		return r[1] and got[1] and r[1].info.uid == got[1].uid
	end) == true)
	expect("walk speed back to 16 after the carry", near(hum(A).WalkSpeed, 16), hum(A).WalkSpeed)
end)

scenario("chase", function()
	local base = ask(A, "perf", { seconds = 4 }, 12)
	info("perf baseline (A's Studio client, heist idle)", ("avg %.1f ms, worst %.1f ms"):format(base.avgMs or -1, base.worstMs or -1))
	local chaseStart = now()
	HeistService._test.holdAttacks(now() + 5)
	local id = open()
	expect("second opening", id ~= nil)
	local beforeA, beforeB = workerSet(A), workerSet(B)
	local markerA = marker(A) and marker(A).id
	HeistService._test.placeRobot((template:FindFirstChild("GuardSpot") :: BasePart).Position)
	put(A, STAND_A, LOOK)
	put(B, STAND_B, LOOK)
	ask(A, "clear")
	ask(B, "clear")
	HeistService._test.holdAttacks(now() + 5)
	local ga = ask(A, "grab", nil, 10)
	local gb = ask(B, "grab", nil, 10)
	expect("A grabbed", ga.carrying == true)
	expect("B grabbed", gb.carrying == true)
	expect("two shield bubbles on B's screen", ask(B, "ui").bubbles >= 2, ask(B, "ui").bubbles)
	HeistService._test.holdAttacks(now() + 1.5)
	local savesB = saves[B]
	local walkDone = false
	local walkReply: any = nil
	task.spawn(function()
		walkReply = ask(B, "walk", { points = HOME }, 60)
		walkDone = true
	end)
	local perf: any = nil
	task.spawn(function()
		perf = ask(A, "perf", { seconds = 6 }, 15)
	end)
	local targetedA = waitUntil(8, function()
		local h = heist()
		return h and carrying(A) and carrying(B) and h:GetAttribute("RobotTarget") == A.UserId
	end)
	expect("robot targets the nearest carrier (A)", targetedA == true)
	expect("A hit twice: capsule back in the vault", waitUntil(30, function()
		return not carrying(A)
	end) == true)
	local hitsOnA = 0
	for _, entry in HeistService.attackLog do
		for _, h in entry.hits do
			if h.userId == A.UserId and h.at >= chaseStart then
				hitsOnA += 1
			end
		end
	end
	expect("A took exactly 2 hits", hitsOnA == 2, hitsOnA)
	waitUntil(50, function()
		return walkDone
	end)
	info("B walk home", ("%.1f s, stuck %s"):format(walkReply and walkReply.time or -1, tostring(walkReply and walkReply.stuck)))
	expect("B delivered", waitUntil(3, function()
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
	expect("A's save marker unchanged", (marker(A) and marker(A).id) == markerA)
	local lost = eventsOf(B, "Lost")
	expect("everyone sees A's capsule fly back", lost[1] ~= nil and lost[1].info.userId == A.UserId and lost[1].info.reason == "caught", lost[1] and lost[1].info.reason)
	local shownA = ask(A, "ui").message
	expect("A told: caught, cash kept", type(shownA) == "string" and shownA:find("Caught") ~= nil, shownA)
	-- telegraphs: every hit so far came after its fixed warning (>= 1.5 s) and after the client got the warning
	local evA = ask(A, "events").events or {}
	local issues, checked = {}, 0
	for _, entry in HeistService.attackLog do
		if entry.startAt < chaseStart then
			continue
		end
		if entry.hitAt - entry.warnAt < HeistConfig.MIN_WARNING - 1e-6 then
			table.insert(issues, ("%s #%d warning %.2f s"):format(entry.kind, entry.id, entry.hitAt - entry.warnAt))
		end
		for _, h in entry.hits do
			checked += 1
			if h.at < entry.hitAt - 1e-6 then
				table.insert(issues, ("%s #%d hit before its time"):format(entry.kind, entry.id))
			end
			if h.userId == A.UserId then
				local shown = nil
				for _, e in evA do
					if (e.kind == "Attack" and e.info.id == entry.id and entry.kind ~= "Searchlight") or (e.kind == "Lock" and e.info.id == entry.id) then
						shown = e.at
					end
				end
				if not shown or h.at - shown < HeistConfig.MIN_WARNING - 0.15 then
					table.insert(
						issues,
						("%s #%d: warning on A's screen %s s before the hit"):format(entry.kind, entry.id, if shown then ("%.2f"):format(h.at - shown) else "never")
					)
				end
			end
		end
	end
	expect("every attack warned >= 1.5 s before any hit, on screen first", #issues == 0 and checked >= 2, table.concat(issues, "; "))
	info("attacks so far", ("%d attacks, %d hits checked"):format(#HeistService.attackLog, checked))
	waitUntil(10, function()
		return perf ~= nil
	end)
	if perf then
		info(
			"perf (A's Studio client, chase with attacks)",
			("avg %.1f ms, worst %.1f ms, heist parts %d, local fx parts max %d"):format(perf.avgMs or -1, perf.worstMs or -1, perf.heistParts or -1, perf.fxMax or -1)
		)
	end
end)

scenario("duplicates", function()
	local id2 = opening() and opening().id
	-- re-sent grab after delivering in this opening
	put(B, STAND_B, LOOK)
	local g = ask(B, "grab", nil, 10)
	expect("B's prompt hidden after delivering in this opening", g.enabled == false and not carrying(B))
	expect("re-sent grab refused by the server", HeistService.grab(B) == false and not carrying(B))
	expect("refusal says one per opening", waitUntil(2, function()
		return (ask(B, "ui").message or ""):find("One capsule per opening") ~= nil
	end) == true, ask(B, "ui").message)
	-- re-sent grant for the same opening
	local count = #data(B).workers
	local dupBefore = HeistService.stats.duplicate
	local w = HeistService.grant(B, id2)
	expect("re-sent grant gives nothing", w == nil and #data(B).workers == count and HeistService.stats.duplicate == dupBefore + 1)
	-- leave while carrying (what PlayerRemoving does), then the same player tries again
	local id3 = open()
	local beforeB = workerSet(B)
	put(B, STAND_B, LOOK)
	expect("B grabbed in opening 3", ask(B, "grab", nil, 10).carrying == true)
	HeistService._test.drop(B)
	expect("left while carrying: capsule gone", not carrying(B) and (B.Character :: Model):FindFirstChild("BossCapsule") == nil)
	expect("left while carrying: no worker", #newWorkers(B, beforeB) == 0)
	expect("back after leaving: no second capsule this opening (SIM rejoin)", HeistService.canGrab(B) == false, nil, true)
	-- a rejoin after a delivery in this opening: the save marker alone refuses it (SIM: memory cleared)
	local keepGrab, keepMarker = HeistService._test.grabbed[B.UserId], data(B).hub.heist
	HeistService._test.grabbed[B.UserId] = nil
	data(B).hub.heist = { id = id3, cap = "Boss", uid = "test" }
	expect("save marker alone refuses this opening (SIM)", HeistService.canGrab(B) == false, nil, true)
	HeistService._test.grabbed[B.UserId], data(B).hub.heist = keepGrab, keepMarker
	-- die while carrying
	local beforeA = workerSet(A)
	put(A, STAND_A, LOOK)
	expect("A grabbed in opening 3", ask(A, "grab", nil, 10).carrying == true)
	hum(A).Health = 0
	expect("died while carrying: capsule back", waitUntil(3, function()
		return not carrying(A)
	end) == true)
	waitUntil(15, function()
		local c = A.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil and c:FindFirstChild("BossCapsule") == nil
	end)
	task.wait(1)
	expect("after respawning: no second capsule this opening", HeistService.canGrab(A) == false)
	expect("died while carrying: no worker", #newWorkers(A, beforeA) == 0)
	-- teleport past the safe line (server-moved = what an exploiter's client could do)
	open()
	put(A, STAND_A, LOOK)
	expect("A grabbed in opening 4", ask(A, "grab", nil, 10).carrying == true)
	HeistService._test.holdAttacks(now() + 1000)
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
	put(B, STAND_B, LOOK)
	expect("B grabbed in opening 5", ask(B, "grab", nil, 10).carrying == true)
	local c = HeistService._test.carriers()[B]
	c.at -= HeistConfig.CARRY_LIMIT
	expect("time limit: capsule back (SIM clock)", waitUntil(2, function()
		return not carrying(B)
	end) == true, nil, true)
	watching = false
	expect("cash never went down for A", lowest[A] >= CASH0[A], ("%d -> lowest %d"):format(CASH0[A], lowest[A]))
	expect("cash never went down for B", lowest[B] >= CASH0[B], ("%d -> lowest %d"):format(CASH0[B], lowest[B]))
	info("stats", HeistService.stats)
end)

scenario("speed", function()
	local function cash(p: Player): number
		return CashService.get(p)
	end
	local income = math.max(A:GetAttribute("Income") or 0, 1)
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
	r = ask(A, "speed", { action = "Equip", id = "bubble" })
	expect("equip an owned trail", r.result and r.result.ok and near(hum(A).WalkSpeed, 16.8))
	r = ask(A, "speed", { action = "Equip", id = "comet" })
	expect("equip a trail not owned: refused", r.result and r.result.ok == false and A:GetAttribute("SpeedTrail") == "bubble")
	r = ask(A, "speed", { action = "Buy", id = "rocket" })
	expect("unknown trail refused", r.result and r.result.ok == false)
	r = ask(A, "speed", { action = "Unequip" })
	expect("unequip: back to 16", r.result and r.result.ok and near(hum(A).WalkSpeed, 16) and A:GetAttribute("SpeedHud") == 100)
	ask(A, "speed", { action = "Equip", id = "gold" })
	local cashB = cash(B)
	r = ask(B, "speed", { action = "Buy", id = "gold" })
	expect(
		"not enough cash: refused, nothing charged",
		r.result and r.result.ok == false and r.result.text == "Not enough cash yet" and cash(B) >= cashB,
		r.result and r.result.text
	)
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
	local seen = ask(B, "trails").seen or {}
	expect("B's screen draws A's trail", seen[tostring(A.UserId)] == true)
	-- carry speed with the best trail, and the HUD at phone sizes while carrying
	open()
	put(A, STAND_A, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	expect("A grabbed in opening 6", ask(A, "grab", nil, 10).carrying == true)
	task.wait(0.3)
	expect("carry speed with Gold Rush = 16 x 1.3 x 0.85 (capped)", near(hum(A).WalkSpeed, 17.68), hum(A).WalkSpeed)
	local hud = ask(A, "hud", nil, 30).hud or { runs = 0, issues = { "no reply" } }
	expect("heist HUD fits at 7 sizes (panel, message, vault pill, Speed row)", hud.runs >= 21 and #hud.issues == 0, table.concat(hud.issues or {}, "; "))
	info("phone 667x375", hud.phone)
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
		local folder = workspace.World.VelocityRoyale:FindFirstChild(RaceConfig.FOLDER)
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
		return (ask(B, "trails").seen or {})[tostring(A.UserId)] == false
	end) == true)
	ServerStorage:SetAttribute("StudioSpeed", true)
	task.wait(1.6)
	expect("speed switch on: trail speed back", near(hum(A).WalkSpeed, 20.8), hum(A).WalkSpeed)
end)

scenario("off", function()
	open()
	put(B, STAND_B, LOOK)
	HeistService._test.holdAttacks(now() + 1000)
	local g = ask(B, "grab", nil, 10)
	expect("B carrying before the switch goes off", g.carrying == true)
	ServerStorage:SetAttribute("StudioHeist", false)
	expect("heist off: world removed", waitUntil(3, function()
		return heist() == nil
	end) == true)
	expect("heist off: carrier cleared, capsule gone, normal speed", not carrying(B) and (B.Character :: Model):FindFirstChild("BossCapsule") == nil and waitUntil(2, function()
		return near(hum(B).WalkSpeed, 16)
	end) == true, hum(B).WalkSpeed)
	expect("heist off: HUD panel gone", waitUntil(2, function()
		local ui = ask(B, "ui")
		return ui.panel == false and ui.pill == false
	end) == true)
end)

ServerStorage:SetAttribute("StudioHeist", was.heist)
ServerStorage:SetAttribute("StudioSpeed", was.speed)
finish("DONE")
