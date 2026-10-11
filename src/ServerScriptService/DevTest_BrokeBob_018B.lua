-- Studio location: ServerScriptService.DevTest_BrokeBob_018B (Script)
-- DevTest_BrokeBob_018B  (Milestone 018B2)
-- TEMPORARY, STUDIO-ONLY test harness for the custom Broke Bob prototype
-- (ServerStorage.Prototypes.BrokeBob_018B). It is Disabled by default and does nothing outside
-- Studio. To run it: enable this script, press Play, read the "[018B TEST]" lines in the Output.
--
-- What it does, on a platform 300 studs above the hub (far from every plot, zone and prompt):
--   1. clones the prototype the way real workers are cloned (NPCWanderer.cloneRig) and animates it
--      with the real NPCAnimation: checks joints, uprightness, scale, idle, walk, limb movement, facing
--   2. carries it with the real NPCCarry on your shoulder for a few seconds, then detaches it
--   3. stands it on a dummy station with the real NPCPlacement.placeOnStation
--   4. shows a ViewportFrame preview framed with the same maths as WorkerPreview
-- It never touches a real plot, station, zone, catalogue, inventory or save: the test worker has no
-- WorkerUid, so the inventory and income code ignore it. Everything it creates is removed at the end.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local NPCAnimation = require(ServerScriptService:WaitForChild("NPCAnimation"))
local NPCCarry = require(ServerScriptService:WaitForChild("NPCCarry"))
local NPCPlacement = require(ServerScriptService:WaitForChild("NPCPlacement"))
local NPCWanderer = require(ServerScriptService:WaitForChild("NPCWanderer"))

local PROTOTYPE = ServerStorage:WaitForChild("Prototypes"):WaitForChild("BrokeBob_018B")
local TAG = "[018B TEST]"
local ORIGIN = Vector3.new(-50, 300, -4)
local FLOOR_TOP = ORIGIN.Y + 1
local VIEW_TIME = 6 -- seconds each stage is held so it can be watched

local passed, failed = 0, 0
local function record(name: string, ok: boolean, detail: string?)
	if ok then passed += 1 else failed += 1 end
	print(TAG, if ok then "PASS" else "FAIL", name, detail or "")
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
local playerRoot = character:WaitForChild("HumanoidRootPart") :: BasePart
local playerHumanoid = character:WaitForChild("Humanoid") :: Humanoid
task.wait(4) -- let the normal game finish loading first

-- stage ------------------------------------------------------------------------------------------
local stage = Instance.new("Folder")
stage.Name = "DevTest_018B"
local function block(name: string, size: Vector3, cf: CFrame, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
	p.Color = Color3.fromRGB(60, 66, 90)
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = stage
	return p
end
block("Floor", Vector3.new(90, 2, 90), CFrame.new(ORIGIN))
-- a dummy plot with one station, built like the real ones (flat cylinder, height along X)
local testPlot = Instance.new("Model")
testPlot.Name = "TestPlot"
local plotFloor = block("PlotFloor", Vector3.new(12, 0.2, 12), CFrame.new(ORIGIN + Vector3.new(22, 1.1, 0)))
plotFloor.Color = Color3.fromRGB(80, 88, 116)
plotFloor.Parent = testPlot
testPlot.PrimaryPart = plotFloor
local placedFolder = Instance.new("Folder")
placedFolder.Name = "PlacedNPCs"
placedFolder.Parent = testPlot
local station = Instance.new("Part")
station.Name, station.Shape, station.Size, station.Anchored = "Station1", Enum.PartType.Cylinder, Vector3.new(0.12, 6, 6), true
station.CFrame = CFrame.new(ORIGIN + Vector3.new(22, 1.26, 0)) * CFrame.Angles(0, 0, math.rad(90))
station.Color = Color3.fromRGB(214, 176, 104)
station:SetAttribute("StationIndex", 1)
station:SetAttribute("Occupied", false)
local stationsFolder = Instance.new("Folder")
stationsFolder.Name = "Stations"
station.Parent = stationsFolder
stationsFolder.Parent = testPlot
testPlot.Parent = stage
stage.Parent = workspace

local home = playerRoot.CFrame
playerRoot.Anchored = true
character:PivotTo(CFrame.new(ORIGIN + Vector3.new(0, 6, 18)))
task.wait(2) -- give the platform time to stream in under the player
playerRoot.Anchored = false

-- 1. assembly, joints, scale -----------------------------------------------------------------------
local bob = NPCWanderer.cloneRig(PROTOTYPE)
bob.Name = "BrokeBob_018B_Test"
local humanoid = bob:FindFirstChildOfClass("Humanoid") :: Humanoid
local root = bob:FindFirstChild("HumanoidRootPart") :: BasePart
bob:PivotTo(CFrame.new(ORIGIN.X, FLOOR_TOP + humanoid.HipHeight + root.Size.Y / 2 + 0.2, ORIGIN.Z))
bob.Parent = stage
pcall(function()
	root:SetNetworkOwner(nil) -- server-owned, like the zone NPCs
end)
humanoid.WalkSpeed = 6
NPCAnimation.attach(bob)
task.wait(2.5)

local function worstJointGap(): (number, string)
	local worst, name = 0, "-"
	for _, d in bob:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local gap = (d.Attachment0.WorldPosition - d.Attachment1.WorldPosition).Magnitude
			if gap > worst then
				worst, name = gap, d.Name
			end
		end
	end
	return worst, name
end
local function extents(): (number, number)
	local low, high = math.huge, -math.huge
	for _, p in bob:GetChildren() do
		if p:IsA("MeshPart") then
			local cf, half = p.CFrame, p.Size / 2
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local y = (cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y
				low, high = math.min(low, y), math.max(high, y)
			end end end
		end
	end
	return low, high
end
local function playing(priority: Enum.AnimationPriority): boolean
	local animator = humanoid:FindFirstChildOfClass("Animator")
	for _, track in (animator and animator:GetPlayingAnimationTracks() or {}) do
		if track.Priority == priority and track.IsPlaying then
			return true
		end
	end
	return false
end
local BAD_STATES = { [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.Ragdoll] = true, [Enum.HumanoidStateType.Dead] = true, [Enum.HumanoidStateType.PlatformStanding] = true }

local meshes = 0
for _, p in bob:GetChildren() do
	if p:IsA("MeshPart") then meshes += 1 end
end
record("15 body meshes + HumanoidRootPart", meshes == 15 and root ~= nil)
record("HipHeight measured", humanoid.HipHeight > 0.5 and humanoid.HipHeight < 3, ("%.2f studs"):format(humanoid.HipHeight))
local gap, gapName = worstJointGap()
record("joints connected at rest", gap < 0.35, ("worst gap %.2f at %s"):format(gap, gapName))
record("standing upright", root.CFrame.UpVector.Y > 0.95, ("up %.2f"):format(root.CFrame.UpVector.Y))
record("not ragdolled or fallen", not BAD_STATES[humanoid:GetState()], humanoid:GetState().Name)
local low, high = extents()
record("feet on the floor", math.abs(low - FLOOR_TOP) < 0.45, ("feet %.2f above the floor"):format(low - FLOOR_TOP))
record("scale as exported", math.abs((high - low) - 6.18) < 0.5, ("%.2f studs tall with beanie (expected about 6.18)"):format(high - low))
record("idle animation playing", playing(Enum.AnimationPriority.Idle))
local leftHand = bob:FindFirstChild("LeftHand") :: BasePart
record("left and right the right way round", (leftHand.Position - root.Position):Dot(root.CFrame.RightVector) < 0, "coffee hand is on his left")
print(TAG, "watch: Bob is idling in front of you")
task.wait(VIEW_TIME)

-- 2. walk --------------------------------------------------------------------------------------------
local torso = bob:FindFirstChild("UpperTorso") :: BasePart
local function swing(limb: BasePart): number -- degrees between a limb and the torso
	return math.deg(math.acos(math.clamp(limb.CFrame.UpVector:Dot(torso.CFrame.UpVector), -1, 1)))
end
local leg, arm = bob:FindFirstChild("RightUpperLeg") :: BasePart, bob:FindFirstChild("RightUpperArm") :: BasePart
local start = root.Position
local goal = Vector3.new(ORIGIN.X - 16, start.Y, ORIGIN.Z)
humanoid:MoveTo(goal)
local legMin, legMax, armMin, armMax, walkGap, facing, sawWalk, sawBad = math.huge, -math.huge, math.huge, -math.huge, 0, 1, false, false
for i = 1, 26 do
	task.wait(0.1)
	local l, a = swing(leg), swing(arm)
	legMin, legMax, armMin, armMax = math.min(legMin, l), math.max(legMax, l), math.min(armMin, a), math.max(armMax, a)
	walkGap = math.max(walkGap, (worstJointGap()))
	sawWalk = sawWalk or playing(Enum.AnimationPriority.Movement)
	sawBad = sawBad or BAD_STATES[humanoid:GetState()] == true
	if i == 12 then
		local dir = (goal - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.5 then
			facing = root.CFrame.LookVector:Dot(dir.Unit)
		end
	end
end
local moved = ((root.Position - start) * Vector3.new(1, 0, 1)).Magnitude
record("walks when told to", moved > 8, ("%.1f studs in 2.6 s"):format(moved))
record("walk animation playing", sawWalk)
record("faces the way he walks", facing > 0.8, ("%.2f (1 = straight ahead, -1 = backwards)"):format(facing))
record("legs swing", legMax - legMin > 8, ("%.0f degrees of swing"):format(legMax - legMin))
record("arms swing", armMax - armMin > 4, ("%.0f degrees of swing"):format(armMax - armMin))
record("joints stay connected while walking", walkGap < 0.5, ("worst gap %.2f"):format(walkGap))
record("no fall or ragdoll while walking", not sawBad)
humanoid:MoveTo(Vector3.new(ORIGIN.X, start.Y, ORIGIN.Z))
print(TAG, "watch: Bob walks back to the middle")
task.wait(4)

-- 3. carry (the real NPCCarry, on your shoulder) ---------------------------------------------------------
if player:GetAttribute("CarryingNPC") == true then
	record("carry", false, "skipped: you are already carrying a worker")
else
	local speedBefore = playerHumanoid.WalkSpeed
	NPCCarry.start(player, bob)
	task.wait(1)
	local weld = root:FindFirstChild("CarryWeld")
	record("carry weld made", weld ~= nil and weld:IsA("Weld") and weld.Part1 == root and weld.Part0 ~= nil, weld and weld.Part0 and ("welded to your " .. weld.Part0.Name) or "no weld")
	record("carried at your shoulder", (root.Position - playerRoot.Position).Magnitude < 7, ("%.1f studs from you"):format((root.Position - playerRoot.Position).Magnitude))
	record("joints connected while carried", (worstJointGap()) < 0.6, ("worst gap %.2f"):format((worstJointGap())))
	record("you are slowed while carrying", playerHumanoid.WalkSpeed < speedBefore, ("%.1f -> %.1f"):format(speedBefore, playerHumanoid.WalkSpeed))
	print(TAG, "watch: Bob is on your shoulder; walk around")
	task.wait(VIEW_TIME)
	local back = NPCCarry.detach(player)
	record("detach hands him back", back == bob and root:FindFirstChild("CarryWeld") == nil and player:GetAttribute("CarryingNPC") ~= true)
	record("your speed is restored", math.abs(playerHumanoid.WalkSpeed - speedBefore) < 0.01, ("%.1f"):format(playerHumanoid.WalkSpeed))
end

-- 4. station placement (the real NPCPlacement.placeOnStation, on a dummy plot) ----------------------------
if bob.Parent then
	NPCPlacement.placeOnStation(bob, station, testPlot)
	task.wait(1.5)
	local feet = extents()
	local stationTop = station.Position.Y + station.Size.X / 2
	record("placed in the plot's PlacedNPCs", bob.Parent == placedFolder and station:GetAttribute("Occupied") == true)
	record("stands on the station", math.abs(feet - stationTop) < 0.45, ("feet %.2f above the pad"):format(feet - stationTop))
	record("anchored and upright on the station", root.Anchored and root.CFrame.UpVector.Y > 0.99)
	record("faces the plot gate", root.CFrame.LookVector:Dot(plotFloor.CFrame.LookVector) > 0.95)
	record("idle resumes on the station", playing(Enum.AnimationPriority.Idle))
	record("joints connected on the station", (worstJointGap()) < 0.35, ("worst gap %.2f"):format((worstJointGap())))
else
	record("station placement", false, "skipped: the test worker was removed")
end

-- 5. 3D preview (same framing maths as ReplicatedStorage.WorkerPreview) -------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DevTest_018B_Preview"
gui.ResetOnSpawn = false
local frame = Instance.new("Frame")
frame.AnchorPoint, frame.Position, frame.Size = Vector2.new(1, 0.5), UDim2.new(1, -20, 0.5, 0), UDim2.fromOffset(300, 330)
frame.BackgroundColor3 = Color3.fromRGB(19, 23, 36)
frame.Parent = gui
local title = Instance.new("TextLabel")
title.Size, title.BackgroundTransparency, title.Text = UDim2.new(1, 0, 0, 30), 1, "018B preview test (300 px stage)"
title.TextColor3, title.Font, title.TextSize = Color3.fromRGB(240, 232, 214), Enum.Font.GothamBold, 14
title.Parent = frame
local viewport = Instance.new("ViewportFrame")
viewport.Position, viewport.Size, viewport.BackgroundTransparency = UDim2.fromOffset(0, 30), UDim2.new(1, 0, 1, -30), 1
viewport.Ambient, viewport.LightColor, viewport.LightDirection = Color3.fromRGB(150, 150, 165), Color3.fromRGB(255, 240, 222), Vector3.new(-0.6, -1, -0.7)
local world = Instance.new("WorldModel")
world.Parent = viewport
local previewModel = PROTOTYPE:Clone()
for _, d in previewModel:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		d:Destroy()
	elseif d:IsA("BasePart") then
		d.Anchored = true
	end
end
previewModel:PivotTo(CFrame.Angles(0, math.rad(200), 0))
previewModel.Parent = world
local FOV = 26
local camera = Instance.new("Camera")
camera.FieldOfView = FOV
local boxCFrame, boxSize = previewModel:GetBoundingBox()
local height = math.max(boxSize.Y, boxSize.X * 0.9)
local dist = (height / 2) / math.tan(math.rad(FOV / 2)) * 1.12
local target = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.02, 0)
camera.CFrame = CFrame.lookAt(target + Vector3.new(0, boxSize.Y * 0.06, dist), target)
camera.Parent = viewport
viewport.CurrentCamera = camera
viewport.Parent = frame
gui.Parent = player:WaitForChild("PlayerGui")
local textured = 0
for _, d in previewModel:GetDescendants() do
	if d:IsA("MeshPart") and d.TextureID ~= "" then textured += 1 end
end
record("preview model builds", textured == 15, ("%d textured meshes; box %.1f x %.1f x %.1f; camera %.1f studs back"):format(textured, boxSize.X, boxSize.Y, boxSize.Z, dist))
record("preview fits the frame", boxSize.Y / height > 0.85, ("fills %.0f%% of the height"):format(boxSize.Y / height * 100))

print(TAG, ("SUMMARY: %d passed, %d failed. Look at Bob on the station and at the preview panel (right side)."):format(passed, failed))
print(TAG, "Cleaning up in 25 seconds, then you are returned to where you were.")
task.wait(25)
gui:Destroy()
if character.Parent then
	character:PivotTo(home)
end
stage:Destroy()
print(TAG, "Done. Disable this script again when you have finished testing.")
