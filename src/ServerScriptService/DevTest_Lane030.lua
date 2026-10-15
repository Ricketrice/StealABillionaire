-- Studio location: ServerScriptService.DevTest_Lane030 (Script)
-- DevTest_Lane030  (Milestone 030) -- STUDIO-ONLY two-player test of the Rising Lane. Inert unless Studio
-- started the session with StudioTestService and the argument "lane030" (2 clients, in-memory save:
-- ServerStorage StudioMemoryStore = true). Covers: the 14-case HUD layout check with the new buttons, the four
-- teammate portal prompts T4-T7 (held by a real client; "coming soon" even with an old unlock in the save), our two
-- lane gates (034: Sunken Kingdom 50k needs Knight's Keep, Ember Academy 500k needs Sunken), run-home walks at carry
-- speed, the saved peak rank, teleports refused while carrying, and a carry down the lane with the opponent's bat.
-- Results: "@@T030|".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "lane030") then
	return
end

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed = {}, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s: %s | %s"):format(kind, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T030|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d"):format(state, passed, failed)
	print("@@T030|SUMMARY " .. summary)
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
	print("@@T030|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

local PlayerData, PlotService, WorkerInventory, CashService = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory"), mod("CashService")
local LaneService, ZoneProgress, PvPBase, PvPCombat = mod("LaneService"), mod("ZoneProgress"), mod("PvPBase"), mod("PvPCombat")
local PvPSteal, NPCCarry = mod("PvPSteal"), mod("NPCCarry")
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig")) :: any

if ServerStorage:GetAttribute("StudioMemoryStore") ~= true and PlayerData.isPersistent() then
	finish("ABORTED: run on the in-memory save (ServerStorage StudioMemoryStore = true)")
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
task.wait(3)
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
bridge.Name = "Test030Bridge"
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

local function root(p: Player): BasePart
	return (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
end
local function put(p: Player, pos: Vector3, look: Vector3?)
	pcall(p.RequestStreamAroundAsync, p, pos)
	local character = p.Character :: Model
	character:PivotTo(if look then CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)) else CFrame.new(pos))
	root(p).AssemblyLinearVelocity = Vector3.zero
	task.wait(1.5) -- let the client stream the spot in
end
local FZ = workspace.World.FutureZones
local function portal(zoneId: string): BasePart?
	for _, t in CollectionService:GetTagged("LanePortal") do
		if t:GetAttribute("ZoneId") == zoneId and t:IsA("BasePart") then
			return t
		end
	end
	return nil
end
local function cooldown()
	task.wait(3.3)
end
local function give(p: Player, id: string, station: number): string
	local uid = HttpService:GenerateGUID(false)
	local rec = { uid = uid, id = id, zone = WorkerCatalogue.get(id).zone, level = 1, tier = "Normal", loc = "station", station = station }
	assert(WorkerInventory.give(p, rec, true), "give failed")
	assert(WorkerInventory.respawn(p, uid), "respawn failed")
	return uid
end

scenario("hud layout (28 runs: 14 screens x normal/worst, new buttons)", function()
	local r = ask(A, "layout", nil, 240)
	expect("client answered", r.answered, "no reply")
	expect("28 runs", r.cases == 28, r.cases)
	expect("8 menu buttons (Home + Zones visible)", r.menuButtons == 8, r.menuButtons)
	expect("no layout issues", r.issues and #r.issues == 0, r.issues and table.concat(r.issues, "; "))
end)

scenario("portals: the four teammate stops (T4-T7) held by a real client", function()
	local data = PlayerData.get(A) :: any
	-- the stops are past the Ember Academy gate (034): only players who unlocked it get there
	table.insert(data.zones, "SunkenKingdom")
	table.insert(data.zones, "BillionaireHills")
	table.insert(data.zones, "ToyTown") -- an old test save with Toy Town unlocked: still closed while not ready
	ZoneProgress._test.publish(A)
	expect("an old Toy Town unlock isn't published while it's not ready", not tostring(A:GetAttribute("UnlockedZones")):find("ToyTown"), A:GetAttribute("UnlockedZones"))
	for i, zoneId in { "FoodCourt", "BeachBoardwalk", "ToyTown", "NeonDowntown" } do
		local zone = ZoneConfig.get(zoneId)
		expect(zoneId .. " is zone " .. (i + 3) .. ", gated, not ready", zone.number == i + 3 and zone.gate and zone.ready == false, zone.number)
		local trig = portal(zoneId)
		expect(zoneId .. " portal exists", trig ~= nil)
		if trig then
			local stop = trig.Parent :: Instance
			expect(zoneId .. " stop is terrace " .. (i + 3), stop:GetAttribute("Terrace") == i + 3, stop.Name)
			expect(zoneId .. " has a status sign", stop:FindFirstChild("Status") ~= nil)
			put(A, trig.Position + Vector3.new(3, 0, 0))
			local before = root(A).Position
			local r = ask(A, "prompt", { zone = zoneId }, 12)
			expect(zoneId .. " prompt found by the client", r.found == true)
			expect(zoneId .. " says coming soon", r.notice and r.notice.ok == false and tostring(r.notice.message):find("coming soon") ~= nil, r.notice and r.notice.message)
			expect(zoneId .. " player stayed", (root(A).Position - before).Magnitude < 8)
			cooldown()
		end
		local bought, code = ZoneProgress.purchase(A, zoneId)
		expect(zoneId .. " can't be bought (coming soon)", bought == false and (code == "unavailable" or code == "owned"), code)
	end
	expect("Toy Town still counts as locked", ZoneProgress.isUnlocked(A, "ToyTown") == false)
	expect("its old region turns players back", ZoneProgress.zoneAt(Vector3.new(332, 10, 84)) == "ToyTown")
	for _, id in { "ToyTown", "SunkenKingdom", "BillionaireHills" } do
		table.remove(data.zones, table.find(data.zones, id))
	end
	ZoneProgress._test.publish(A)
	put(A, Vector3.new(-157, 3.5, -92))
	cooldown()
end)

-- Walks A at carry speed (13.6) along the centre line from `from` to the safe line; seconds or nil.
local function runHome(from: Vector3, via: { Vector3 }?): number?
	local humanoid = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	put(A, from, Vector3.new(-157, from.Y, -100))
	humanoid.WalkSpeed = 13.6
	local points = table.clone(via or {})
	table.insert(points, Vector3.new(-157, 3.5, -100))
	local t0 = os.clock()
	for _, point in points do
		local lastMove = 0
		while os.clock() - t0 < 140 do
			if os.clock() - lastMove > 4 then
				humanoid.WalkSpeed = 13.6
				humanoid:MoveTo(point)
				lastMove = os.clock()
			end
			task.wait(0.1)
			local p = root(A).Position
			if p.Y < -20 then
				return nil
			end
			if point.Z > -101 then
				if p.Z > -112.5 then
					return os.clock() - t0
				end
			elseif (Vector3.new(p.X, 0, p.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude < 3 then
				break
			end
		end
	end
	return nil
end

scenario("our lane gates: Sunken Kingdom (T2) and Ember Academy (T3)", function()
	local sunkenBarrier = FZ.Our_SunkenKingdom.Gate.Barrier :: BasePart
	local emberBarrier = FZ.Zone6_BillionaireHills.Gate.Barrier :: BasePart
	local sk, ea = ZoneConfig.get("SunkenKingdom"), ZoneConfig.get("BillionaireHills")
	expect(
		"Sunken Kingdom = zone 2, 50,000, gated, needs Knight's Keep",
		sk.number == 2 and sk.price == 50000 and sk.gate and ZoneConfig.prerequisite("SunkenKingdom").id == "MainStreet"
	)
	expect(
		"Ember Academy = zone 3, 500,000, gated, needs Sunken",
		ea.number == 3 and ea.price == 500000 and ea.gate and ZoneConfig.prerequisite("BillionaireHills").id == "SunkenKingdom"
	)
	expect("Sunken gate is a lane gate south of Ember's", FZ.Our_SunkenKingdom.Gate:GetAttribute("LaneGate") == true and sunkenBarrier.Position.Z > emberBarrier.Position.Z)
	expect("Knight's Keep (T1) is no district", ZoneProgress.zoneAt(Vector3.new(-157, 15, -300)) == nil)
	expect("north of the Sunken gate is Sunken Kingdom", ZoneProgress.zoneAt(sunkenBarrier.Position + Vector3.new(0, -2, -30)) == "SunkenKingdom")
	expect("the T2 -> T3 ramp is still Sunken", ZoneProgress.zoneAt(Vector3.new(-157, 30, -590)) == "SunkenKingdom")
	expect("north of the Ember gate is Ember Academy", ZoneProgress.zoneAt(emberBarrier.Position + Vector3.new(0, -2, -30)) == "BillionaireHills")
	expect("the teammate stops (T4) are past Ember", ZoneProgress.zoneAt(Vector3.new(-157, 51, -905)) == "BillionaireHills")
	-- locked: turned back at each gate, teleports refused
	for _, case in { { "SunkenKingdom", sunkenBarrier }, { "BillionaireHills", emberBarrier } } do
		local id, barrier = case[1], case[2]
		put(A, barrier.Position + Vector3.new(0, -2, -30))
		ZoneProgress._test.enforce()
		task.wait(0.3)
		expect(id .. " locked: turned back to its gate", root(A).Position.Z > barrier.Position.Z, root(A).Position.Z)
		local ok, why = LaneService.travel(A, "Zone", id)
		expect(id .. " locked: zone teleport refused", ok == false and tostring(why):find("Unlock") ~= nil, why)
		cooldown()
	end
	CashService.trySpend(A, math.max(CashService.get(A), 1))
	CashService.add(A, 600000)
	local bought, code = ZoneProgress.purchase(A, "BillionaireHills")
	expect("Ember before Sunken: refused (prerequisite)", bought == false and code == "prerequisite", code)
	bought, code = ZoneProgress.purchase(A, "SunkenKingdom")
	expect("Sunken Kingdom: unlocked", bought == true and code == "unlocked", code)
	expect("50,000 taken", CashService.get(A) == 550000, CashService.get(A))
	bought, code = ZoneProgress.purchase(A, "BillionaireHills")
	expect("Ember Academy: unlocked", bought == true and code == "unlocked", code)
	expect("500,000 taken", CashService.get(A) == 50000, CashService.get(A))
	for _, case in { { "SunkenKingdom", sunkenBarrier }, { "BillionaireHills", emberBarrier } } do
		local id, barrier = case[1], case[2]
		put(A, barrier.Position + Vector3.new(0, -2, -30))
		ZoneProgress._test.enforce()
		task.wait(0.3)
		expect(id .. " unlocked: stays beyond the gate", root(A).Position.Z < barrier.Position.Z, root(A).Position.Z)
		put(A, Vector3.new(-157, 3.5, -92))
		cooldown()
		local ok, why = LaneService.travel(A, "Zone", id)
		local entry = ZoneProgress.entryPoint(id)
		expect(id .. " unlocked: teleport lands in front of its gate", ok == true and entry ~= nil and (root(A).Position - entry.Position).Magnitude < 10, why)
		cooldown()
	end
	-- Sunken Kingdom catching: its spawner starts once someone has it unlocked
	local npcs = waitUntil(30, function()
		local area = workspace.Zones:FindFirstChild("SunkenKingdom")
		local folder = area and area:FindFirstChild("NPCs")
		return folder and #folder:GetChildren() > 0
	end)
	expect("Sunken Kingdom NPCs spawn", npcs ~= nil)
	local rolled = WorkerCatalogue.rollWorker("SunkenKingdom", Random.new(7))
	expect("a Sunken roll is a Sunken creature", WorkerCatalogue.get(rolled).zone == "SunkenKingdom", rolled)

	-- run-home walks at carry speed (13.6), measured from the far end of each catch area / to each portal
	local keepFar = workspace.Zones.MainStreet.ZoneBoundary :: BasePart
	local sunkenFar = workspace.Zones.SunkenKingdom.ZoneBoundary :: BasePart
	local emberFar = workspace.Zones.BillionaireHills.ZoneBoundary :: BasePart
	local function farEnd(b: BasePart): Vector3
		return Vector3.new(-157, b.Position.Y - b.Size.Y / 2 + 3.5, b.Position.Z - b.Size.Z / 2 + 3)
	end
	local times = {}
	local t1 = runHome(farEnd(keepFar))
	local t2 = runHome(farEnd(sunkenFar))
	local t3 = runHome(farEnd(emberFar))
	local t4 = runHome((portal("FoodCourt") :: BasePart).Position + Vector3.new(19.5 - 2, 0.5, 0))
	local all = { t1, t2, t3, t4 }
	for i = 1, 4 do
		local t = all[i]
		times[i] = if t then ("T%d %.1f s"):format(i, t) else ("T%d failed"):format(i)
		expect(("run home from T%d"):format(i), t ~= nil)
	end
	note("INFO", "run-home at 13.6 studs/s", table.concat(times, ", "))
	expect("T2 under 40 s", t2 and t2 < 40, t2)
	expect("T3 under 55 s", t3 and t3 < 55, t3)
	local humanoid = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = 16
	local data = PlayerData.get(A) :: any
	for _, id in { "SunkenKingdom", "BillionaireHills" } do
		table.remove(data.zones, table.find(data.zones, id))
	end
	ZoneProgress._test.publish(A)
	put(A, Vector3.new(-157, 3.5, -92))
	cooldown()
end)

scenario("rank never goes down (saved peak, schema stays 3)", function()
	local data = PlayerData.get(A) :: any
	CashService.add(A, 300000)
	local reached = waitUntil(6, function()
		return A:GetAttribute("Rank") == "Captain"
	end)
	expect("300,000 cash: Captain", reached, A:GetAttribute("Rank"))
	local peak = data.hub.peak
	expect("hub.peak saved in the record", type(peak) == "number" and peak >= 300000, peak)
	expect("schema still 3", data.schema == 3, data.schema)
	CashService.trySpend(A, CashService.get(A))
	task.wait(3)
	expect("cash spent: still Captain", A:GetAttribute("Rank") == "Captain", A:GetAttribute("Rank"))
	expect("net worth fell but the peak did not", (A:GetAttribute("NetWorth") or 0) < 1000 and (A:GetAttribute("Peak") or 0) >= peak, A:GetAttribute("Peak"))
	expect(
		"head tag shows the rank",
		(A.Character :: Model):FindFirstChild("RankTag") ~= nil
			and ((A.Character :: Model).RankTag.Label :: TextLabel).Text == "Captain"
			and (A.Character :: Model).RankTag.Adornee == (A.Character :: Model).Head
	)
end)

scenario("carry: teleports refused, then down the lane with the opponent's bat", function()
	expect("combat is on", PvPBase.combat() == true)
	local street = workspace.Zones.MainStreet
	local npc = waitUntil(40, function()
		for _, m in street.NPCs:GetChildren() do
			if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then
				return m
			end
		end
		return nil
	end) :: Model?
	expect("a Main Street worker to catch", npc ~= nil)
	if not npc then
		return
	end
	put(A, (npc.HumanoidRootPart :: BasePart).Position + Vector3.new(3, 0, 0))
	npc:SetAttribute("Claimed", true) -- (the spawner must not despawn it mid-test)
	local hum = (A.Character :: Model):FindFirstChildOfClass("Humanoid")
	local before = ("health %s, already carrying %s, npc root %s"):format(
		tostring(hum and hum.Health),
		tostring(NPCCarry.getCarried(A)),
		tostring(npc:FindFirstChild("HumanoidRootPart") ~= nil)
	)
	NPCCarry.start(A, npc)
	expect("A is carrying", A:GetAttribute("CarryingNPC") == true, before)
	local ok, why = LaneService.travel(A, "Home")
	expect("Home refused while carrying", ok == false and tostring(why):find("carrying") ~= nil, why)
	ok, why = LaneService.travel(A, "Zone", "MainStreet")
	expect("zone teleport refused while carrying", ok == false and tostring(why):find("carrying") ~= nil, why)
	local toy = portal("FoodCourt")
	if toy then
		local z = PlayerData.get(A) :: any
		table.insert(z.zones, "SunkenKingdom") -- (the stops are past the Ember gate)
		table.insert(z.zones, "BillionaireHills")
		put(A, toy.Position + Vector3.new(3, 0, 0))
		local r = ask(A, "prompt", { zone = "FoodCourt" }, 12)
		expect("portal refused while carrying", r.notice and r.notice.ok == false and tostring(r.notice.message):find("carrying") ~= nil, r.notice and r.notice.message)
		expect("still carrying", A:GetAttribute("CarryingNPC") == true and z ~= nil)
		for _, id in { "SunkenKingdom", "BillionaireHills" } do
			table.remove(z.zones, table.find(z.zones, id))
		end
	end
	PvPBase.endProtection(B)
	PvPBase.endProtection(A)
	PvPBase.endSpawnSafe(A)
	PvPBase.endSpawnSafe(B)
	local equipped = PvPCombat.equip(B)
	expect("B has a bat out", equipped == true)
	-- A starts at the top of ramp A (terrace 1) and walks home; B waits on the ramp and swings as A passes
	local rampB = Vector3.new(-153, 9.3, -140)
	put(B, rampB, Vector3.new(-157, 9.3, -170))
	put(A, Vector3.new(-157, 15.5, -178), Vector3.new(-157, 15.5, -100))
	local humanoid = (A.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local dest = Vector3.new(-157, 3.5, -100)
	humanoid:MoveTo(dest)
	local t0, lastMove, swung, hits0 = os.clock(), os.clock(), false, PvPCombat.stats.hits
	local minY = math.huge
	local reached = false
	while os.clock() - t0 < 45 do
		task.wait(0.1)
		if os.clock() - lastMove > 5 then
			humanoid:MoveTo(dest)
			lastMove = os.clock()
		end
		local p = root(A).Position
		minY = math.min(minY, p.Y)
		if not swung and (p - root(B).Position).Magnitude < 6 then
			swung = true
			(B.Character :: Model):PivotTo(CFrame.lookAt(root(B).Position, Vector3.new(p.X, root(B).Position.Y, p.Z)))
			hits0 = PvPCombat.stats.hits
			local started = PvPCombat.attack(B, "basic")
			expect("B's swing accepted", started == true)
			task.wait(0.6)
			expect("the bat hit A on the ramp", PvPCombat.stats.hits == hits0 + 1, PvPCombat.stats.hits - hits0)
			expect("A is still carrying after the hit", A:GetAttribute("CarryingNPC") == true)
		end
		if p.Z > -112.5 and swung then
			reached = true
			break
		end
	end
	expect("B got a swing in", swung)
	expect("A reached the safe line carrying", reached and A:GetAttribute("CarryingNPC") == true, root(A).Position)
	expect("nobody fell off the lane (lowest point)", minY > 0, minY)
	expect("A is inside the safe zone now", PvPBase.isSafe(root(A).Position), root(A).Position)
	NPCCarry.cancel(A)
	PvPCombat.unequip(B)
end)

scenario("stealing a base worker and the owner's bat (lot theft still works with the new layout)", function()
	local uid = give(B, "broke_bob", 1)
	local model: Model? = nil
	for _, m in (PlotService.getPlot(B) :: Model).PlacedNPCs:GetChildren() do
		if m:GetAttribute("WorkerUid") == uid then
			model = m
		end
	end
	expect("B's worker stands on a station", model ~= nil)
	if not model then
		return
	end
	PvPBase.endProtection(A)
	PvPBase.endProtection(B)
	PvPBase.endSpawnSafe(A)
	PvPBase.endSpawnSafe(B)
	local mr = (model:FindFirstChild("HumanoidRootPart") :: BasePart).Position
	put(A, mr + Vector3.new(0, 1, 4))
	local ok, why = PvPSteal.tryBegin(A, model)
	expect("A steals B's worker", ok == true, why)
	expect("A is carrying a stolen worker", A:GetAttribute("CarryingStolen") == true)
	local travel, reason = LaneService.travel(A, "Home")
	expect("Home refused while carrying a stolen worker", travel == false and tostring(reason):find("carrying") ~= nil, reason)
	expect("B equips the bat", PvPCombat.equip(B) == true)
	put(B, root(A).Position + Vector3.new(0, 0, 4), root(A).Position)
	local hits0 = PvPCombat.stats.hits
	expect("B swings at the thief", PvPCombat.attack(B, "basic") == true)
	task.wait(0.8)
	expect("the hit landed", PvPCombat.stats.hits == hits0 + 1)
	expect("the stolen worker is knocked loose", A:GetAttribute("CarryingStolen") ~= true and not PvPSteal.isStealing(A))
	PvPCombat.unequip(B)
end)

finish("DONE")
