-- Studio location: ServerScriptService.DevTest_Workers019 (Script)
-- DevTest_Workers019  (Milestone 019) -- TEMPORARY, STUDIO-ONLY test harness. Disabled by default.
-- Runs every worker in this script's "Workers" attribute (comma-separated ids) through:
--   A  its custom rig on a platform 300 studs up: joints, scale, idle, walk
--   B  the real loop: steal (NPCClaim.tryReserve, worker forced with TestForceWorkerId), reveal,
--      shoulder carry, and the reveal card's 3D preview on the client
--   C  placement on a station of your plot     D  income rate and cash
--   E  Store + Equip through the real InventoryAction remote (the rebuild-on-station path)
-- It prints "[019 TEST]" lines and writes the summary to ServerStorage.Test019_Result.
-- It only runs on the in-memory save (Studio API access off), so no real DataStore is written.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local resultValue = Instance.new("StringValue")
resultValue.Name = "Test019_Result"
resultValue.Value = "RUNNING"
resultValue.Parent = ServerStorage

local apiOn = pcall(function()
	return game:GetService("DataStoreService"):GetDataStore("__sab_probe_019"):GetAsync("probe")
end)
if apiOn then
	resultValue.Value = "ABORTED: Studio API access is on; this test only runs on the in-memory save"
	return
end

local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end
local NPCAnimation, NPCCarry, NPCClaim, NPCPlacement, NPCWanderer = mod("NPCAnimation"), mod("NPCCarry"), mod("NPCClaim"), mod("NPCPlacement"), mod("NPCWanderer")
local CashService, PassiveIncome, PlotService, WorkerInventory = mod("CashService"), mod("PassiveIncome"), mod("PlotService"), mod("WorkerInventory")
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any
local CustomWorkers = require(ReplicatedStorage:WaitForChild("CustomWorkers")) :: any

local CustomWorkerRigs = mod("CustomWorkerRigs")
local RIGS = { FindFirstChild = function(_, id: string) -- whichever rig the mapping selects
	return CustomWorkerRigs.getTemplate(id)
end }
local TAG = "[019 TEST]"
local HEIGHT = { -- total height in studs, from export/019/manifest.json
	broke_bob = 5.87, delivery_dave = 5.45, street_hustler = 5.67, business_betty = 5.28, security_sam = 5.138, crypto_carl = 5.956, ceo_chad = 6.096, mystery_millionaire = 6.437,
	butler_barnaby = 5.72, caddie_gus = 5.864, polo_pro_penny = 5.282, chef_pierre = 5.974, bodyguard_boris = 5.647, hedge_fund_hank = 6.036, oil_baron_oswald = 5.838, the_trillionaire = 6.46,
}
local ids = string.split(script:GetAttribute("Workers") or "broke_bob", ",")

local failLines, perWorker, passed, failed = {}, {}, 0, 0
local function record(id: string, name: string, ok: any, detail: any?)
	local tally = perWorker[id] or { pass = 0, fail = 0 }
	perWorker[id] = tally
	if ok then
		passed += 1
		tally.pass += 1
	else
		failed += 1
		tally.fail += 1
		table.insert(failLines, ("FAIL %s | %s | %s"):format(id, name, tostring(detail or "")))
	end
	print(TAG, if ok then "PASS" else "FAIL", id, name, detail or "")
end
local function summary(state: string): string
	local rows = {}
	for _, id in ids do
		local tally = perWorker[id] or { pass = 0, fail = 0 }
		table.insert(rows, ("%s %d/%d"):format(id, tally.pass, tally.pass + tally.fail))
	end
	return ("%s passed=%d failed=%d\n%s\n%s"):format(state, passed, failed, table.concat(rows, ", "), table.concat(failLines, "\n"))
end

local function meshes(model: Instance): { MeshPart }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(list, d)
		end
	end
	return list
end
local function spanY(parts: { BasePart }): (number, number)
	local low, high = math.huge, -math.huge
	for _, p in parts do
		local cf, half = p.CFrame, p.Size / 2
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local y = (cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y
			low, high = math.min(low, y), math.max(high, y)
		end end end
	end
	return low, high
end
local function feet(model: Instance): { BasePart }
	return { model:FindFirstChild("LeftFoot") :: BasePart, model:FindFirstChild("RightFoot") :: BasePart }
end
local function jointGap(model: Instance): (number, string)
	local worst, name = 0, "-"
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name ~= "Root" and d.Part0 and d.Part1 then
			local gap = ((d.Part0.CFrame * d.C0).Position - (d.Part1.CFrame * d.C1).Position).Magnitude
			if gap > worst then
				worst, name = gap, d.Name
			end
		elseif d:IsA("AnimationConstraint") and d.Name ~= "Root" and d.Attachment0 and d.Attachment1 then
			local gap = (d.Attachment0.WorldPosition - d.Attachment1.WorldPosition).Magnitude
			if gap > worst then
				worst, name = gap, d.Name
			end
		end
	end
	return worst, name
end
local function playing(humanoid: Humanoid, priority: Enum.AnimationPriority): boolean
	local animator = humanoid:FindFirstChildOfClass("Animator")
	for _, track in (animator and animator:GetPlayingAnimationTracks() or {}) do
		if track.Priority == priority and track.IsPlaying then
			return true
		end
	end
	return false
end
local BAD = { [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.Ragdoll] = true, [Enum.HumanoidStateType.Dead] = true, [Enum.HumanoidStateType.PlatformStanding] = true }
-- Same meshes at the same sizes as the template, and nothing else.
local function isCustom(model: Instance, template: Instance): (boolean, string)
	local function census(root: Instance): ({ [string]: number }, number)
		local counts, total = {}, 0
		for _, m in meshes(root) do
			local key = ("%s|%s|%.2f,%.2f,%.2f"):format(m.Name, m.MeshId, m.Size.X, m.Size.Y, m.Size.Z)
			counts[key] = (counts[key] or 0) + 1
			total += 1
		end
		return counts, total
	end
	local want, total = census(template)
	local have, haveTotal = census(model)
	for key, n in want do
		if have[key] ~= n then
			return false, (key:match("^[^|]+") or "?") .. " differs from the template"
		end
	end
	if haveTotal ~= total then
		return false, ("%d meshes, expected %d"):format(haveTotal, total)
	end
	return true, total .. " meshes at scale 1"
end
-- (the Milestone 019 version, by part name; kept for reference)
local function isCustomByName(model: Instance, template: Instance): (boolean, string)
	local want = meshes(template)
	for _, t in want do
		local m = model:FindFirstChild(t.Name, true)
		if not (m and m:IsA("MeshPart") and m.MeshId == t.MeshId) then
			return false, t.Name .. " is not the custom mesh"
		elseif (m.Size - t.Size).Magnitude > 0.01 then
			return false, t.Name .. " was resized"
		end
	end
	local have = #meshes(model)
	if have ~= #want or model:FindFirstChildWhichIsA("Accessory") then
		return false, ("%d meshes, expected %d"):format(have, #want)
	end
	return true, #want .. " meshes at scale 1"
end
local function waitFor(seconds: number, check: () -> any): any
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

-- A ---------------------------------------------------------------------------------------------
local function platformTest(id: string, index: number, stage: Instance, floorTop: number, origin: Vector3)
	local template = RIGS:FindFirstChild(id)
	if not template then
		record(id, "A rig template exists", false)
		return
	end
	local rig = NPCWanderer.cloneRig(template)
	rig.Name = id .. "_PlatformTest"
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local x = origin.X + (index - (#ids + 1) / 2) * 8
	local rootCFrame = CFrame.new(x, floorTop + humanoid.HipHeight + root.Size.Y / 2 + 0.2, origin.Z - 12)
	rig:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(rig:GetPivot()))
	rig.Parent = stage
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	humanoid.WalkSpeed = 6
	NPCAnimation.attach(rig)
	task.wait(2.5)

	local body = 0
	for _, p in rig:GetChildren() do
		if p:IsA("MeshPart") then
			body += 1
		end
	end
	record(id, "A 15 body meshes", body == 15, body)
	record(id, "A hip height", humanoid.HipHeight > 0.5 and humanoid.HipHeight < 3.5, ("%.2f"):format(humanoid.HipHeight))
	local gap, gapName = jointGap(rig)
	record(id, "A joints connected at rest", gap < 0.02, ("%.2f at %s"):format(gap, gapName))
	record(id, "A upright", root.CFrame.UpVector.Y > 0.95, ("%.2f"):format(root.CFrame.UpVector.Y))
	record(id, "A not fallen", not BAD[humanoid:GetState()], humanoid:GetState().Name)
	local low = spanY(feet(rig))
	local _, high = spanY(meshes(rig))
	record(id, "A hip height as built", math.abs(humanoid.HipHeight - (template:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight) < 0.01, ("%.3f"):format(humanoid.HipHeight))
	record(id, "A feet on the floor", math.abs(low - floorTop) < 0.05, ("%.2f"):format(low - floorTop))
	record(id, "A height as exported", math.abs((high - low) - ((template:GetAttribute("Height") :: number?) or HEIGHT[id])) < 0.35, ("%.2f vs %.2f"):format(high - low, ((template:GetAttribute("Height") :: number?) or HEIGHT[id])))
	record(id, "A idle playing", playing(humanoid, Enum.AnimationPriority.Idle))
	local rightHand = rig:FindFirstChild("RightHand") :: BasePart
	record(id, "A right hand on its right", (rightHand.Position - root.Position):Dot(root.CFrame.RightVector) > 0.3)

	local torso = rig:FindFirstChild("UpperTorso") :: BasePart
	local function swing(limb: BasePart): number
		return math.deg(math.acos(math.clamp(limb.CFrame.UpVector:Dot(torso.CFrame.UpVector), -1, 1)))
	end
	local leg, arm = rig:FindFirstChild("RightUpperLeg") :: BasePart, rig:FindFirstChild("RightUpperArm") :: BasePart
	local start = root.Position
	local goal = Vector3.new(x, start.Y, origin.Z + 8)
	humanoid:MoveTo(goal)
	local legMin, legMax, armMin, armMax, walkGap, facing, sawWalk, sawBad = math.huge, -math.huge, math.huge, -math.huge, 0, 1, false, false
	for i = 1, 26 do
		task.wait(0.1)
		local l, a = swing(leg), swing(arm)
		legMin, legMax, armMin, armMax = math.min(legMin, l), math.max(legMax, l), math.min(armMin, a), math.max(armMax, a)
		walkGap = math.max(walkGap, (jointGap(rig)))
		sawWalk = sawWalk or playing(humanoid, Enum.AnimationPriority.Movement)
		sawBad = sawBad or BAD[humanoid:GetState()] == true
		if i == 12 then
			local dir = (goal - root.Position) * Vector3.new(1, 0, 1)
			if dir.Magnitude > 0.5 then
				facing = root.CFrame.LookVector:Dot(dir.Unit)
			end
		end
	end
	local moved = ((root.Position - start) * Vector3.new(1, 0, 1)).Magnitude
	record(id, "A walks", moved > 8, ("%.1f studs in 2.6 s"):format(moved))
	record(id, "A walk animation playing", sawWalk)
	record(id, "A faces the way it walks", facing > 0.8, ("%.2f"):format(facing))
	record(id, "A legs swing", legMax - legMin > 8, ("%.0f deg"):format(legMax - legMin))
	record(id, "A arms swing", armMax - armMin > 4, ("%.0f deg"):format(armMax - armMin))
	record(id, "A joints connected while walking", walkGap < 0.3, ("%.2f"):format(walkGap))
	record(id, "A no fall while walking", not sawBad)
	rig:Destroy()
end

-- B to E ----------------------------------------------------------------------------------------
local function findMysteryNPC(): Model?
	local zones = workspace:FindFirstChild("Zones")
	local best: Model? = nil
	for _, d in (zones and zones:GetDescendants() or {}) do
		if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" then
			local npc = d.Parent and d.Parent.Parent
			if npc and npc:IsA("Model") and npc:GetAttribute("Claimed") ~= true then
				best = npc
			end
		end
	end
	return best
end

local function loopTest(id: string, player: Player, bridge: RemoteEvent, previewResults: { [string]: any })
	local worker = WorkerCatalogue.get(id)
	local template = RIGS:FindFirstChild(id)
	if not (worker and template) then
		record(id, "B worker and rig exist", false)
		return
	end
	local character = player.Character :: Model
	local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and character:FindFirstChild("UpperTorso") :: BasePart
	if not (playerHumanoid and playerHumanoid.Health > 0 and torso) then
		record(id, "B player alive", false)
		return
	end
	local ready = waitFor(30, function()
		return PlotService.getPlot(player) and (WorkerInventory.canClaim(player))
	end)
	if not ready then
		record(id, "B can claim", false, (select(2, WorkerInventory.canClaim(player))))
		return
	end
	local plot = PlotService.getPlot(player) :: Model
	local npc = waitFor(30, findMysteryNPC) :: Model?
	if not npc then
		record(id, "B a mystery NPC to steal", false)
		return
	end
	local npcRoot = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local zones = workspace:FindFirstChild("Zones") :: Instance
	local zone = { folder = zones:FindFirstChild(worker.zone) or { Name = worker.zone }, npcFolder = npc.Parent }
	local speedBefore = playerHumanoid.WalkSpeed

	ServerStorage:SetAttribute("TestForceWorkerId", id)
	character:PivotTo(CFrame.new(npcRoot.Position + Vector3.new(0, 1, 5)))
	bridge:FireClient(player, "preview", id, (template:FindFirstChild("Head") :: MeshPart).MeshId)
	local okReserve, message = NPCClaim.tryReserve(player, npc, zone)
	ServerStorage:SetAttribute("TestForceWorkerId", nil)
	record(id, "B steal starts", okReserve, message)
	if not okReserve then
		return
	end
	local carried = waitFor(6, function()
		return NPCCarry.getCarried(player) == npc
	end)
	record(id, "B stolen and on your shoulder", carried == true, npc:GetAttribute("ClaimPhase"))
	if not carried then
		return
	end

	local uid = npc:GetAttribute("WorkerUid")
	record(id, "B revealed as the forced worker", npc:GetAttribute("WorkerId") == id and uid ~= nil, npc:GetAttribute("WorkerId"))
	record(id, "B display name", npc.Name == worker.name and worker.name == CustomWorkers.WORKERS[id].name, npc.Name)
	local custom, why = isCustom(npc, template)
	record(id, "B reveal swapped in the custom model at scale 1", custom, why)
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
	record(id, "B PrimaryPart is the new root", root ~= nil and npc.PrimaryPart == root)
	local weld = root and root:FindFirstChild("CarryWeld")
	record(id, "B carry weld on your torso", weld ~= nil and weld:IsA("Weld") and weld.Part0 == torso and weld.Part1 == root)
	task.wait(2)
	record(id, "B still carried after 2 s", NPCCarry.getCarried(player) == npc and humanoid.Health > 0 and not root.Anchored)
	local alongBack = root.CFrame.UpVector:Dot(-torso.CFrame.LookVector)
	local side = (root.Position - torso.Position):Dot(torso.CFrame.RightVector)
	record(id, "B carry pose as designed (over the right shoulder, head down your back)", alongBack > 0.9 and side > 1, ("%.2f, %.1f studs right"):format(alongBack, side))
	local far = 0
	for _, p in meshes(npc) do
		far = math.max(far, (p.Position - torso.Position).Magnitude)
	end
	record(id, "B every part stays with you", far < 9, ("%.1f studs"):format(far))
	record(id, "B joints connected while carried", (jointGap(npc)) < 0.3, ("%.2f"):format((jointGap(npc))))
	record(id, "B you are slowed", playerHumanoid.WalkSpeed < speedBefore)
	local shown = waitFor(9, function()
		return previewResults[id]
	end)
	record(id, "B reveal card shows the custom preview", shown ~= nil and shown.ok, shown and shown.detail or "no answer from the client")

	-- C
	local placedFolder = plot:FindFirstChild("PlacedNPCs") :: Instance
	local function stationByIndex(index: any): BasePart?
		for _, s in (plot:FindFirstChild("Stations") :: Instance):GetChildren() do
			if s:IsA("BasePart") and s:GetAttribute("StationIndex") == index then
				return s
			end
		end
		return nil
	end
	local station: BasePart? = nil
	for index = 1, 40 do
		local s = stationByIndex(index)
		if s and s:GetAttribute("Occupied") ~= true then
			station = s
			break
		end
	end
	if not station then
		record(id, "C a free station", false)
		return
	end
	local function stationChecks(model: Model, pad: BasePart, label: string)
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local h = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local top = pad.Position.Y + pad.Size.X / 2
		local low = spanY(feet(model))
		local _, high = spanY(meshes(model))
		record(id, label .. " in PlacedNPCs, station occupied", model.Parent == placedFolder and pad:GetAttribute("Occupied") == true)
		record(id, label .. " hip height as built", math.abs(h.HipHeight - (template:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight) < 0.01, ("%.3f"):format(h.HipHeight))
		local rootJoint = model:FindFirstChild("Root", true) :: any
		local travel = if rootJoint:IsA("Motor6D") then ((rootJoint.Part0.CFrame * rootJoint.C0).Position - (rootJoint.Part1.CFrame * rootJoint.C1).Position).Magnitude else (rootJoint.Attachment0.WorldPosition - rootJoint.Attachment1.WorldPosition).Magnitude
		record(id, label .. " root joint within the idle's bob", travel < 0.07 * h.HipHeight + 0.02, ("%.3f"):format(travel))
		record(id, label .. " feet on the pad", math.abs(low - top) < 0.05, ("%.2f"):format(low - top))
		record(id, label .. " upright and anchored", r.Anchored and r.CFrame.UpVector.Y > 0.99)
		record(id, label .. " faces the gate", r.CFrame.LookVector:Dot((plot.PrimaryPart :: BasePart).CFrame.LookVector) > 0.95)
		record(id, label .. " height as exported", math.abs((high - low) - ((template:GetAttribute("Height") :: number?) or HEIGHT[id])) < 0.35, ("%.2f vs %.2f"):format(high - low, ((template:GetAttribute("Height") :: number?) or HEIGHT[id])))
		record(id, label .. " idle playing", playing(h, Enum.AnimationPriority.Idle))
		record(id, label .. " joints connected", (jointGap(model)) < 0.02, ("%.2f"):format((jointGap(model))))
		local c, w = isCustom(model, template)
		record(id, label .. " custom model at scale 1", c, w)
	end
	local incomeBefore = PassiveIncome.getIncome(player)
	character:PivotTo(CFrame.new(station.Position + Vector3.new(0, 4, 4)))
	local okPlace, placeMessage = NPCPlacement.tryPlace(player, station)
	record(id, "C placed on a station", okPlace, placeMessage)
	if not okPlace then
		return
	end
	task.wait(1.5)
	stationChecks(npc, station, "C placed:")

	-- D
	local income = (WorkerCatalogue.getStats(id, WorkerCatalogue.LEVEL, WorkerCatalogue.TIER))
	local rate = PassiveIncome.getIncome(player) - incomeBefore
	record(id, "D income rate is the catalogue's", rate == income, ("%s vs %s"):format(tostring(rate), tostring(income)))
	local cash = CashService.get(player)
	task.wait(3.3)
	local earned = CashService.get(player) - cash
	record(id, "D cash is paid", earned >= (incomeBefore + income) * 2 and earned <= (incomeBefore + income) * 5, ("+%d in 3.3 s at %d/s"):format(earned, incomeBefore + income))

	-- E
	local function placedByUid(): Model?
		for _, m in placedFolder:GetChildren() do
			if m:GetAttribute("WorkerUid") == uid then
				return m :: Model
			end
		end
		return nil
	end
	bridge:FireClient(player, "inv", "Store", uid)
	record(id, "E stored to the inventory", waitFor(5, function()
		return placedByUid() == nil
	end) == true)
	task.wait(0.6)
	bridge:FireClient(player, "inv", "Equip", uid)
	local rebuilt = waitFor(5, placedByUid) :: Model?
	record(id, "E rebuilt from the inventory", rebuilt ~= nil and rebuilt ~= npc)
	if rebuilt then
		task.wait(1.5)
		local pad = stationByIndex(rebuilt:GetAttribute("StationIndex"))
		if pad then
			stationChecks(rebuilt, pad, "E rebuilt:")
		else
			record(id, "E rebuilt: has a station", false)
		end
		record(id, "E rebuilt: display name", rebuilt.Name == worker.name, rebuilt.Name)
		record(id, "E rebuilt: income rate", PassiveIncome.getIncome(player) - incomeBefore == income)
		task.wait(0.6)
		bridge:FireClient(player, "inv", "Store", uid) -- leave the station free for the next worker
		waitFor(5, function()
			return placedByUid() == nil
		end)
		task.wait(0.6)
	end
end

-- run -------------------------------------------------------------------------------------------
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart")
task.wait(4) -- let the normal game finish loading first

local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test019Bridge"
bridge.Parent = ReplicatedStorage
local previewResults = {}
bridge.OnServerEvent:Connect(function(from, kind, id, ok, detail)
	if from == player and kind == "preview" and type(id) == "string" then
		previewResults[id] = { ok = ok == true, detail = tostring(detail) }
	end
end)
local helper = script:WaitForChild("ClientHelper"):Clone()
helper.Parent = player:WaitForChild("PlayerGui")

if script:GetAttribute("SkipPlatform") ~= true then
	local ORIGIN = Vector3.new(-50, 300, -4)
	local stage = Instance.new("Folder")
	stage.Name = "DevTest_019"
	local floor = Instance.new("Part")
	floor.Name, floor.Anchored, floor.Size, floor.CFrame = "Floor", true, Vector3.new(math.max(40, #ids * 8 + 16), 2, 60), CFrame.new(ORIGIN)
	floor.Parent = stage
	stage.Parent = workspace
	local pending = #ids
	for index, id in ids do
		task.spawn(function()
			local ok, err = pcall(platformTest, id, index, stage, ORIGIN.Y + 1, ORIGIN)
			if not ok then
				record(id, "A platform test ran", false, err)
			end
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait(0.2)
	end
	stage:Destroy()
	resultValue.Value = summary("RUNNING (A done)")
end

for _, id in ids do
	local ok, err = pcall(loopTest, id, player, bridge, previewResults)
	if not ok then
		record(id, "B-E loop test ran", false, err)
	end
	resultValue.Value = summary("RUNNING (" .. id .. " done)")
end

ServerStorage:SetAttribute("TestForceWorkerId", nil)
helper:Destroy()
bridge:Destroy()
resultValue.Value = summary("DONE")
print(TAG, resultValue.Value)
