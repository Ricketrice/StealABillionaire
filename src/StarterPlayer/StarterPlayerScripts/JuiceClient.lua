-- Studio location: StarterPlayer.StarterPlayerScripts.JuiceClient (LocalScript)
-- JuiceClient  (Milestone 028, D8/D12)
-- Rarity-scaled feel for the core loop, drawn on this client only (the server decides everything).
-- Off unless ReplicatedStorage.JuiceOn is true. All animation is code-driven: joint Transforms set
-- after the Animator each frame (on top of any idle animation), tweens and CFrame offsets; no
-- uploaded animations. Effects come from FxKit (one master each, auto-cleanup, Low effects).
--   * reveal: spin-up sparkles while the catch spins, rarity burst, camera shake for Epic+, a
--     name + rarity banner (UITheme); Legendary/Secret also get a light pillar and sparkle waves
--   * carry: the worker wriggles on your shoulder; Legendary+ leave a gold trail; a stolen worker
--     looks shocked ("!!" and frantic flailing)
--   * place: a celebration hop and a coin burst
--   * cash: "+$X" pops over your working workers (X = what each earned since the last pop)
--   * steal: a "SAFE!" burst when you get a stolen worker home (the alarm itself is PvPFx's)
--   * idle on pads: bounce and look around; Rare+ do their personality move now and then; Epic+
--     get a soft aura, only near the camera
--   * a "Low effects" toggle (top right) for slower phones
-- The Hud's cash counter rolls up while this is on (Hud reads JuiceOn itself).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BaseConfig = require(ReplicatedStorage:WaitForChild("BaseConfig"))
local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))

local player = Players.LocalPlayer
local J = ParadeConfig.Juice
local T = UITheme.Colors
local TAU = math.pi * 2
local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Secret = 5 }
local L = BaseConfig.Living

local function juiceOn(): boolean
	return ReplicatedStorage:GetAttribute("JuiceOn") == true
end
-- Living bases (Milestone 033, D25): placed workers do a job at their pad (published by BaseService).
local function livingOn(): boolean
	return ReplicatedStorage:GetAttribute("LivingOn") == true
end
local function cameraPos(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end
local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Low effects: default from the graphics level, then the player's choice (this session).
do
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	player:SetAttribute("LowEffects", ok and level > 0 and level <= 3)
end

-- UI (through UITheme) -------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Juice"
gui.ResetOnSpawn = false
gui.DisplayOrder = 7 -- above the reveal card, so its banner reads on top
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Effects toggle: last item of the shared top bar.
local fxButton = UITheme.button({ Name = "LowEffects", Kind = "Ghost", Text = "", TextSize = 13, LayoutOrder = 4, Size = UDim2.fromOffset(52, 52), Parent = UITheme.topBar() })
fxButton.Visible = false
local function showFxSetting()
	fxButton.Text = if FxKit.low() then "✨\nLow" else "✨\nFull"
end
fxButton.Activated:Connect(function()
	player:SetAttribute("LowEffects", not FxKit.low())
	showFxSetting()
end)
showFxSetting()

-- Reveal banner: name + rarity, slides down from the top.
local banner = UITheme.panel({ Name = "RevealBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(380, 58), Parent = gui })
banner.Visible = false
UITheme.scaleWith(banner, 0.7, 1.05)
local bannerRarity = UITheme.text({ Name = "Rarity", Text = "", Role = "Small", Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 18), Parent = banner })
local bannerName = UITheme.text({ Name = "WorkerName", Text = "", Role = "Title", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30), Parent = banner })
local bannerToken = 0
local function showBanner(name: string, rarity: string, hold: number)
	bannerToken += 1
	local token = bannerToken
	local color = UITheme.Rarity[rarity] or T.Text
	bannerRarity.Text = ("%s  %s  %s"):format(UITheme.RarityGlyph[rarity] or "", string.upper(rarity), UITheme.RarityGlyph[rarity] or "")
	bannerRarity.TextColor3 = color
	bannerName.Text = name
	banner.BackgroundColor3 = T.Panel
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -140)
	UITheme.tween(banner, UITheme.Motion.Slow, { Position = UDim2.new(0.5, 0, 0, UITheme.bannerTop()) }, Enum.EasingStyle.Back)
	task.delay(hold, function()
		if token == bannerToken then
			local out = UITheme.tween(banner, UITheme.Motion.Normal, { Position = UDim2.new(0.5, 0, 0, -140) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			out.Completed:Once(function()
				if token == bannerToken then
					banner.Visible = false -- (the top inset is up to ~60 px: off the top isn't always off screen)
				end
			end)
		end
	end)
end

-- Joint driver ------------------------------------------------------------------------------------------------
-- Each frame, after the Animator: Transform = (what the Animator set this frame) * our offset. If the
-- Animator doesn't drive a joint, the Transform still holds our last value, so we keep our own base.
type JointState = { written: CFrame, base: CFrame }
local jointState: { [Instance]: JointState } = setmetatable({}, { __mode = "k" }) :: any
local function near(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.99999 and a.UpVector:Dot(b.UpVector) > 0.99999
end
local function drive(joint: Instance?, offset: CFrame)
	if not joint then
		return
	end
	local target: any = joint
	local current = target.Transform :: CFrame
	local s = jointState[joint]
	local base = if s and near(current, s.written) then s.base else current
	local result = base * offset
	target.Transform = result
	jointState[joint] = { written = result, base = base }
end
local function release(joint: Instance?)
	if not joint then
		return
	end
	local s = jointState[joint]
	if s then
		local target: any = joint
		target.Transform = s.base
		jointState[joint] = nil
	end
end

local JOINT_NAMES = { "Root", "Waist", "Neck", "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow" }
local function jointsOf(model: Model): { [string]: Instance }
	local joints = {}
	for _, d in model:GetDescendants() do
		if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and table.find(JOINT_NAMES, d.Name) then
			joints[d.Name] = d
		end
	end
	return joints
end
local function releaseAll(joints: { [string]: Instance })
	for _, joint in joints do
		release(joint)
	end
end

-- Reveal --------------------------------------------------------------------------------------------------------
local BUILD = { Common = 0, Rare = 0, Epic = 0.6, Legendary = 1.1, Secret = 1.8 } -- matches WorkerRevealCard's build-up
local HOLD = { Common = 1.3, Rare = 2, Epic = 2.4, Legendary = 3.2, Secret = 3.6 } -- and how long its card stays
local function pillar(at: Vector3, color: Color3, seconds: number)
	if FxKit.low() then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "FxPillar"
	beam.Shape = Enum.PartType.Cylinder
	beam.Anchored, beam.CanCollide, beam.CanTouch, beam.CanQuery, beam.CastShadow = true, false, false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 1
	beam.Size = Vector3.new(60, 3, 3)
	beam.CFrame = CFrame.new(at + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	UITheme.tween(beam, 0.3, { Transparency = 0.45 })
	task.delay(seconds, function()
		local t = UITheme.tween(beam, 0.6, { Transparency = 1, Size = Vector3.new(60, 0.2, 0.2) })
		t.Completed:Once(function()
			beam:Destroy()
		end)
	end)
end

local function onRevealed(workerId: any)
	if not juiceOn() or type(workerId) ~= "string" then
		return
	end
	local worker = WorkerCatalogue.get(workerId)
	if not worker then
		return
	end
	local rarity = worker.rarity
	local rank = RANK[rarity] or 1
	local color = UITheme.Rarity[rarity] or T.Text
	local build = BUILD[rarity] or 0
	task.delay(build, function()
		local root = myRoot()
		if root then
			FxKit.burst(root, "sparkle", color, 10 + rank * 8)
			FxKit.burst(root, "glow", color, 2 + rank)
			if rank >= 4 then
				pillar(root.Position, color, if rarity == "Secret" then 4 else 3)
				for wave = 1, rank - 2 do
					task.delay(wave * 0.45, function()
						local r = myRoot()
						if r then
							FxKit.burst(r, "sparkle", if wave % 2 == 0 then T.Golden else color, 24)
						end
					end)
				end
			end
		end
		local shake = J.SHAKE[rarity]
		if shake then
			FxKit.shake(shake, 0.3 + rank * 0.08)
		end
	end)
	-- The name banner follows once the reveal card has gone (on a phone the card fills the middle).
	task.delay(build + (HOLD[rarity] or 2) + 0.4, function()
		if player:GetAttribute("CarryingNPC") == true then
			showBanner(worker.name .. "  ·  take it home!", rarity, if rank >= 4 then 3.5 else 2.4)
		else
			showBanner(worker.name, rarity, 2.4)
		end
	end)
end
ReplicatedStorage:WaitForChild("WorkerRevealed").OnClientEvent:Connect(onRevealed)

-- Claimed workers: spin-up, then carry ------------------------------------------------------------------------
local claimedFolder = workspace:WaitForChild("ClaimedNPCs", 30)
type Carried = { model: Model, joints: { [string]: Instance }, phase: number, trail: Trail?, shock: BillboardGui? }
local carried: { [Model]: Carried } = {}

local function stopCarried(model: Model)
	local c = carried[model]
	if not c then
		return
	end
	carried[model] = nil
	releaseAll(c.joints)
	if c.trail then
		c.trail:Destroy()
	end
	if c.shock then
		c.shock:Destroy()
	end
end

local function carrierOf(model: Model): Player?
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Name == "CarryWeld" and d.Part0 then
			return Players:GetPlayerFromCharacter(d.Part0.Parent)
		end
	end
	return nil
end

local function startCarried(model: Model)
	if carried[model] or not juiceOn() then
		return
	end
	-- The revealed worker's new body replicates a moment after its ClaimPhase: wait for it.
	model:WaitForChild("UpperTorso", 3)
	task.wait(0.2)
	if carried[model] or model:GetAttribute("ClaimPhase") ~= "Carrying" or not juiceOn() then
		return
	end
	local c: Carried = { model = model, joints = jointsOf(model), phase = math.random() * TAU }
	carried[model] = c
	local rarity = model:GetAttribute("Rarity")
	local torso = model:FindFirstChild("UpperTorso")
	if (RANK[rarity] or 0) >= 4 and torso and torso:IsA("BasePart") and not FxKit.low() then
		local a0 = Instance.new("Attachment")
		a0.Name = "FxTrailTop"
		a0.Position = Vector3.new(0, 0.6, 0)
		a0.Parent = torso
		local a1 = Instance.new("Attachment")
		a1.Name = "FxTrailBottom"
		a1.Position = Vector3.new(0, -0.6, 0)
		a1.Parent = torso
		local trail = Instance.new("Trail")
		trail.Name = "FxGoldTrail"
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(T.Golden, UITheme.Rarity[rarity] or T.Golden)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.6
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = torso
		trail.Destroying:Once(function()
			a0:Destroy()
			a1:Destroy()
		end)
		c.trail = trail
	end
	local carrier = carrierOf(model)
	if carrier and carrier:GetAttribute("CarryingStolen") == true then
		local head = model:FindFirstChild("Head")
		if head then
			local bb = Instance.new("BillboardGui")
			bb.Name = "FxShocked"
			bb.Size = UDim2.fromOffset(70, 50)
			bb.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
			bb.AlwaysOnTop = true
			bb.LightInfluence = 0
			bb.Adornee = head
			UITheme.text({ Text = "!!", Role = "Display", TextSize = 40, Color = T.Danger, Size = UDim2.fromScale(1, 1), Parent = bb })
			bb.Parent = player:WaitForChild("PlayerGui")
			c.shock = bb
		end
	end
end

local function spinUp(model: Model)
	if not juiceOn() then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local mine = model:GetAttribute("ClaimedBy") == player.UserId
	if (root.Position - cameraPos()).Magnitude > 120 then
		return
	end
	local swirl = FxKit.attach(root, "shine", Color3.fromRGB(255, 240, 200))
	if swirl then
		swirl.Rate = 30
		swirl.Speed = NumberRange.new(4, 7)
		swirl.EmissionDirection = Enum.NormalId.Top
		task.delay(0.8, function()
			swirl:Destroy()
		end)
	end
	if mine then
		FxKit.sound("whoosh")
	end
end

local function watchClaimed(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local function onPhase()
		local phase = model:GetAttribute("ClaimPhase")
		if phase == "Spinning" then
			spinUp(model)
		elseif phase == "Carrying" then
			task.spawn(startCarried, model)
		else
			stopCarried(model)
		end
	end
	model:GetAttributeChangedSignal("ClaimPhase"):Connect(onPhase)
	onPhase()
end
if claimedFolder then
	claimedFolder.ChildAdded:Connect(watchClaimed)
	claimedFolder.ChildRemoved:Connect(function(child)
		stopCarried(child :: Model)
	end)
	for _, child in claimedFolder:GetChildren() do
		watchClaimed(child)
	end
end

-- Placed workers: celebrate, idle, moves, aura, cash pops -----------------------------------------------------
type Placed = {
	model: Model,
	joints: { [string]: Instance },
	rarity: string,
	rank: number,
	phase: number,
	move: string?,
	moveAt: number,
	moveStart: number?,
	hopStart: number?,
	aura: ParticleEmitter?,
	mine: boolean,
	popAt: number,
	job: string?, -- living bases (033): this worker's job loop, from its type
	props: { BasePart }?, -- its job's props while near the camera
	broom: { BasePart }?, -- (sweep) handle + brush, moved every frame
	coinAt: number,
}
local placed: { [Model]: Placed } = {}
local plots = workspace:WaitForChild("Hub", 30) and workspace.Hub:WaitForChild("Plots", 30)
local startedAt = os.clock()

local function moveFor(workerId: string?): string
	local listed = workerId and J.MOVES[workerId]
	if listed then
		return listed
	end
	local h = 0
	for i = 1, #(workerId or "") do
		h = (h * 31 + string.byte(workerId :: string, i)) % 1000
	end
	return J.MOVE_LIST[h % #J.MOVE_LIST + 1]
end

local function nextMoveTime(): number
	return os.clock() + J.MOVE_EVERY[1] + math.random() * (J.MOVE_EVERY[2] - J.MOVE_EVERY[1])
end

-- Living bases (033): job props ---------------------------------------------------------------------------------
-- Client-only anchored parts in front of a working worker, made when it comes within PROP_RANGE of the camera and
-- removed when it leaves (or with Low effects). Placed relative to its root, which stands still on the pad.
local propFolder: Folder? = nil
local function props(): Folder
	if propFolder and propFolder.Parent then
		return propFolder
	end
	local f = Instance.new("Folder")
	f.Name = "BaseLifeLocal"
	f.Parent = workspace
	propFolder = f
	return f
end
local function propPart(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = props()
	return part
end
local function dropProps(p: Placed)
	if p.props then
		for _, part in p.props do
			part:Destroy()
		end
	end
	p.props, p.broom = nil, nil
end
-- Where the worker's feet are (the pad top), relative to its root.
local function footY(model: Model, root: BasePart): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return -((if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2)
end
local WOOD, STEEL, SCREEN = Color3.fromRGB(150, 104, 66), Color3.fromRGB(70, 74, 86), Color3.fromRGB(120, 210, 255)
local function buildProps(p: Placed)
	local root = p.model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local cf, feet = root.CFrame, footY(p.model, root)
	local list = {}
	if p.job == "laptop" then
		local top = 0.3 -- desk top, just under the hands
		table.insert(list, propPart(Vector3.new(0.35, top - feet, 0.35), cf * CFrame.new(0, (top + feet) / 2, -1.55), STEEL))
		table.insert(list, propPart(Vector3.new(2.4, 0.16, 1.2), cf * CFrame.new(0, top, -1.55), WOOD))
		table.insert(list, propPart(Vector3.new(1.3, 0.08, 0.85), cf * CFrame.new(0, top + 0.12, -1.5), STEEL))
		local screen = cf * CFrame.new(0, top + 0.55, -1.95) * CFrame.Angles(0.25, 0, 0)
		table.insert(list, propPart(Vector3.new(1.3, 0.85, 0.06), screen, STEEL))
		table.insert(list, propPart(Vector3.new(1.15, 0.7, 0.02), screen * CFrame.new(0, 0, 0.04), SCREEN, Enum.Material.Neon))
	elseif p.job == "sweep" then
		local handle = propPart(Vector3.new(0.18, 0.18, 3.6), cf, WOOD)
		local brush = propPart(Vector3.new(1.4, 0.32, 0.5), cf, Color3.fromRGB(240, 196, 70))
		table.insert(list, handle)
		table.insert(list, brush)
		p.broom = { handle, brush }
	end
	p.props = list
end
-- (sweep) the broom from the hands down to the floor in front, swung by `swing` radians round the worker.
local function broomCFrames(p: Placed, swing: number): (CFrame?, CFrame?)
	local root = p.model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil, nil
	end
	local cf = root.CFrame * CFrame.Angles(0, swing, 0)
	local feet = footY(p.model, root)
	local hands = (cf * CFrame.new(0, 0.1, -1.1)).Position
	local floor = (cf * CFrame.new(0, feet + 0.22, -3.1)).Position
	local handle = CFrame.lookAt((hands + floor) / 2, floor)
	local brush = CFrame.lookAt(floor, floor + cf.LookVector)
	return handle, brush
end
-- Joint offsets of a job loop at time t (seconds, with the worker's own phase).
local function jobOffsets(job: string, t: number): { [string]: CFrame }
	if job == "laptop" then -- typing: arms forward to the desk, hands tapping, head down at the screen
		local a, b = math.sin(t * 14) * 0.06, math.sin(t * 14 + 2) * 0.06
		return {
			LeftShoulder = CFrame.Angles(1.15 + a, 0, 0.12),
			RightShoulder = CFrame.Angles(1.15 + b, 0, -0.12),
			LeftElbow = CFrame.Angles(0.35, 0, 0),
			RightElbow = CFrame.Angles(0.35, 0, 0),
			Neck = CFrame.Angles(-0.28 + math.sin(t * 0.8) * 0.04, math.sin(t * 0.5) * 0.12, 0),
			Root = CFrame.new(0, math.abs(math.sin(t * 1.6)) * 0.04, 0),
		}
	elseif job == "pushups" then -- lying face down, arms straight to the floor, body going up and down
		local up = 0.5 + 0.5 * math.sin(t * 3.2)
		return {
			Root = CFrame.new(0, -1.55 + up * 0.45, 0) * CFrame.Angles(-1.4, 0, 0),
			LeftShoulder = CFrame.Angles(1.4, 0, 0.1),
			RightShoulder = CFrame.Angles(1.4, 0, -0.1),
			LeftElbow = CFrame.Angles((1 - up) * 0.6, 0, 0),
			RightElbow = CFrame.Angles((1 - up) * 0.6, 0, 0),
			Neck = CFrame.Angles(0.7, 0, 0),
		}
	elseif job == "guard" then -- standing guard: wide stance, slow look left and right
		local look = math.sin(t * 0.55)
		return {
			Root = CFrame.Angles(0, look * 0.35, 0) * CFrame.new(0, math.sin(t * 1.2) * 0.04, 0),
			Neck = CFrame.Angles(0, math.sin(t * 0.55 + 0.9) * 0.35, 0),
			LeftShoulder = CFrame.Angles(0.1, 0, -0.28),
			RightShoulder = CFrame.Angles(0.1, 0, 0.28),
			LeftHip = CFrame.Angles(0, 0, -0.08),
			RightHip = CFrame.Angles(0, 0, 0.08),
		}
	elseif job == "sweep" then -- sweeping: arms down-forward on the broom, body twisting with the swing
		local swing = math.sin(t * 2.6)
		return {
			Root = CFrame.Angles(0, swing * 0.32, 0) * CFrame.new(0, math.abs(swing) * 0.05, 0),
			LeftShoulder = CFrame.Angles(0.85, 0, 0.18),
			RightShoulder = CFrame.Angles(0.95, 0, -0.18),
			LeftElbow = CFrame.Angles(0.25, 0, 0),
			RightElbow = CFrame.Angles(0.25, 0, 0),
			Neck = CFrame.Angles(-0.3, -swing * 0.2, 0),
		}
	end
	return {}
end

local function stopPlaced(model: Model)
	local p = placed[model]
	if not p then
		return
	end
	placed[model] = nil
	releaseAll(p.joints)
	if p.aura then
		p.aura:Destroy()
	end
	dropProps(p)
end

local function startPlaced(model: Instance, plot: Instance, fresh: boolean)
	if not model:IsA("Model") or placed[model] then
		return
	end
	task.wait(0.1) -- let the rig's joints replicate
	if model.Parent == nil then
		return
	end
	local rarity = model:GetAttribute("Rarity") or "Common"
	local p: Placed = {
		model = model,
		joints = jointsOf(model),
		rarity = rarity,
		rank = RANK[rarity] or 1,
		phase = math.random() * TAU,
		move = if (RANK[rarity] or 1) >= 2 then moveFor(model:GetAttribute("WorkerId")) else nil,
		moveAt = nextMoveTime(),
		mine = plot:GetAttribute("OwnerUserId") == player.UserId,
		popAt = os.clock() + math.random() * J.CASH_POP_EVERY,
		job = L.JOBS[model:GetAttribute("Role") or ""],
		coinAt = os.clock() + L.COIN_EVERY[1] + math.random() * (L.COIN_EVERY[2] - L.COIN_EVERY[1]),
	}
	placed[model] = p
	if fresh and juiceOn() and os.clock() - startedAt > 3 then
		local pivot = model:GetPivot().Position
		if (pivot - cameraPos()).Magnitude < 120 then
			p.hopStart = os.clock()
			FxKit.coins(pivot + Vector3.new(0, 2, 0), 8)
			FxKit.burst(pivot, "sparkle", UITheme.Rarity[rarity], 18)
			if p.mine then
				FxKit.sound("place")
				task.delay(0.25, FxKit.sound, "coin")
			end
		end
	end
end

if plots then
	local function watchPlot(plot: Instance)
		local folder = plot:WaitForChild("PlacedNPCs", 30)
		if not folder then
			return
		end
		folder.ChildAdded:Connect(function(child)
			startPlaced(child, plot, true)
		end)
		folder.ChildRemoved:Connect(function(child)
			stopPlaced(child :: Model)
		end)
		for _, child in folder:GetChildren() do
			task.spawn(startPlaced, child, plot, false)
		end
	end
	for _, plot in plots:GetChildren() do
		task.spawn(watchPlot, plot)
	end
	plots.ChildAdded:Connect(watchPlot)
end

-- Personality moves: offsets for (Root, Neck, LeftShoulder, RightShoulder, LeftHip, RightHip) at progress t.
local MOVE_LENGTH = { hop = 0.7, wave = 1.6, spin = 0.8, flex = 1.4, dance = 2.4 }
local function moveOffsets(move: string, t: number): { [string]: CFrame }
	local ease = math.sin(math.min(t, 1) * math.pi) -- 0 -> 1 -> 0
	if move == "hop" then
		return { Root = CFrame.new(0, ease * 2.2, 0) * CFrame.Angles(0, 0, 0), LeftShoulder = CFrame.Angles(0, 0, -ease * 2.4), RightShoulder = CFrame.Angles(0, 0, ease * 2.4) }
	elseif move == "wave" then
		return { RightShoulder = CFrame.Angles(0, 0, ease * 2.6) * CFrame.Angles(math.sin(t * 18) * 0.35 * ease, 0, 0), Neck = CFrame.Angles(0, -0.3 * ease, 0) }
	elseif move == "spin" then
		return { Root = CFrame.Angles(0, math.min(t, 1) * TAU, 0) * CFrame.new(0, ease * 0.6, 0) }
	elseif move == "flex" then
		return {
			LeftShoulder = CFrame.Angles(0, 0, -ease * 1.6) * CFrame.Angles(0, -ease * 0.6, 0),
			RightShoulder = CFrame.Angles(0, 0, ease * 1.6) * CFrame.Angles(0, ease * 0.6, 0),
			Root = CFrame.new(0, -ease * 0.25, 0),
		}
	elseif move == "dance" then
		local s = math.sin(t * TAU * 2)
		return {
			Root = CFrame.new(s * 0.4 * ease, math.abs(s) * 0.4 * ease, 0) * CFrame.Angles(0, s * 0.4 * ease, 0),
			LeftShoulder = CFrame.Angles(0, 0, -(1.2 + s * 0.6) * ease),
			RightShoulder = CFrame.Angles(0, 0, (1.2 - s * 0.6) * ease),
		}
	end
	return {}
end

local brooms: { BasePart } = {}
local broomTargets: { CFrame } = {}
local function stepPlaced(now: number, camPos: Vector3)
	local juice, living, low = juiceOn(), livingOn(), FxKit.low()
	local range = if living then L.RANGE else J.IDLE_RANGE
	table.clear(brooms)
	table.clear(broomTargets)
	for model, p in placed do
		if model.Parent == nil then
			stopPlaced(model)
			continue
		end
		local pivot = model:GetPivot().Position
		local distance = (pivot - camPos).Magnitude
		-- Aura: Epic+ only near the camera.
		local wantAura = juice and p.rank >= 3 and distance < J.AURA_RANGE
		if wantAura and not p.aura then
			local torso = model:FindFirstChild("UpperTorso")
			if torso and torso:IsA("BasePart") then
				p.aura = FxKit.attach(torso, "aura", UITheme.Rarity[p.rarity])
			end
		elseif not wantAura and p.aura then
			p.aura:Destroy()
			p.aura = nil
		end
		-- Cash pops over your own working workers.
		if juice and p.mine and now >= p.popAt then
			p.popAt = now + J.CASH_POP_EVERY
			local income = model:GetAttribute("Income")
			local head = model:FindFirstChild("Head")
			if type(income) == "number" and income > 0 and head and distance < J.CASH_POP_RANGE then
				FxKit.text(head, "+" .. CashFormat.format(income * J.CASH_POP_EVERY), T.Cash, 2.5)
			end
		end
		-- Living bases: the job's props near the camera, and a coin pop now and then on your own workers.
		local working = living and not low and p.job ~= nil and distance < range
		if working and not p.props then
			buildProps(p)
		elseif not working and p.props then
			dropProps(p)
		end
		if living and p.mine and now >= p.coinAt then
			p.coinAt = now + L.COIN_EVERY[1] + math.random() * (L.COIN_EVERY[2] - L.COIN_EVERY[1])
			local head = model:FindFirstChild("Head")
			if head and distance < range and not low then
				FxKit.coins((head :: BasePart).Position + Vector3.new(0, 1, 0), 3)
			end
		end
		if distance > range then
			if next(jointState) then
				for _, joint in p.joints do
					if jointState[joint] then
						release(joint)
					end
				end
			end
			continue
		end
		if next(p.joints) == nil then
			p.joints = jointsOf(model)
		end
		local j = p.joints
		local t = now + p.phase
		local offsets: { [string]: CFrame }
		if working then
			offsets = jobOffsets(p.job :: string, t)
			if p.broom then
				local handle, brush = broomCFrames(p, math.sin(t * 2.6) * 0.32)
				if handle and brush then
					table.insert(brooms, p.broom[1])
					table.insert(broomTargets, handle)
					table.insert(brooms, p.broom[2])
					table.insert(broomTargets, brush)
				end
			end
		else
			offsets = {
				Root = CFrame.new(0, math.abs(math.sin(t * 2.4)) * 0.18, 0),
				Neck = CFrame.Angles(math.sin(t * 0.7) * 0.08, math.sin(t * 0.45) * 0.45, 0),
			}
		end
		-- Celebration hop right after being placed.
		if p.hopStart then
			local h = (now - p.hopStart) / 0.6
			if h >= 1 then
				p.hopStart = nil
			else
				local up = math.sin(h * math.pi)
				offsets = {
					Root = CFrame.new(0, up * 2.5, 0) * CFrame.Angles(0, h * TAU, 0),
					LeftShoulder = CFrame.Angles(0, 0, -up * 2.6),
					RightShoulder = CFrame.Angles(0, 0, up * 2.6),
				}
			end
		elseif juice and not working and p.move and now >= p.moveAt and not p.moveStart then
			p.moveStart = now -- (personality moves only while idle: never in the middle of a job)
		end
		if p.moveStart and p.move then
			local length = MOVE_LENGTH[p.move] or 1
			local mt = (now - p.moveStart) / length
			if mt >= 1 then
				p.moveStart = nil
				p.moveAt = nextMoveTime()
			else
				for name, cf in moveOffsets(p.move, mt) do
					offsets[name] = cf
				end
				if p.move == "hop" and mt < 0.05 and p.mine then
					FxKit.sound("hop")
				end
			end
		end
		for _, name in JOINT_NAMES do
			local joint = j[name]
			if joint then
				local cf = offsets[name]
				if cf then
					drive(joint, cf)
				elseif jointState[joint] then
					release(joint)
				end
			end
		end
	end
	if #brooms > 0 then
		workspace:BulkMoveTo(brooms, broomTargets, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function stepCarried(now: number, camPos: Vector3)
	for model, c in carried do
		if model.Parent == nil then
			stopCarried(model)
			continue
		end
		if (model:GetPivot().Position - camPos).Magnitude > 100 then
			continue
		end
		if next(c.joints) == nil or not (c.joints.LeftHip and c.joints.LeftHip.Parent) then
			c.joints = jointsOf(model) -- (the body was swapped or hadn't arrived yet)
		end
		local speed = if c.shock then 16 else 9
		local s = math.sin(now * speed + c.phase)
		local k = math.sin(now * speed * 0.5 + c.phase)
		local j = c.joints
		drive(j.LeftHip, CFrame.Angles(s * 0.5, 0, 0))
		drive(j.RightHip, CFrame.Angles(-s * 0.5, 0, 0))
		drive(j.LeftKnee, CFrame.Angles(-math.abs(k) * 0.7, 0, 0))
		drive(j.RightKnee, CFrame.Angles(-math.abs(s) * 0.7, 0, 0))
		drive(j.LeftShoulder, CFrame.Angles(k * 0.6, 0, -0.3))
		drive(j.RightShoulder, CFrame.Angles(-k * 0.6, 0, 0.3))
		drive(j.Neck, CFrame.Angles(0, s * 0.4, 0))
	end
end

-- After the Animator has posed everything this frame.
RunService.PreSimulation:Connect(function()
	local juice = juiceOn()
	if not (juice or livingOn()) then
		return
	end
	local now = os.clock()
	local camPos = cameraPos()
	stepPlaced(now, camPos)
	if juice then
		stepCarried(now, camPos)
	end
end)

-- Steal: "SAFE!" when you bring a stolen worker home ------------------------------------------------------------
task.spawn(function()
	local pvpEvent = ReplicatedStorage:WaitForChild("PvPEvent", 60)
	if not pvpEvent then
		return
	end
	local remote = pvpEvent :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind, info)
		if not juiceOn() or type(info) ~= "table" then
			return
		end
		if kind == "StealEnded" and info.outcome == "delivered" and info.thiefId == player.UserId then
			local root = myRoot()
			if root then
				FxKit.text(root, "SAFE!", T.Success, 4)
				FxKit.burst(root, "sparkle", T.Success, 26)
				FxKit.coins(root.Position, 8)
				FxKit.sound("safe")
			end
		elseif kind == "TheftStarted" and info.ownerId == player.UserId then
			FxKit.shake(0.2, 0.3)
		end
	end)
end)

-- On/off -----------------------------------------------------------------------------------------------------------
local function refresh()
	local on = juiceOn()
	gui.Enabled = on
	fxButton.Visible = on and not UITheme.v1 -- (the V1 look has it in Settings instead)
	local living = livingOn()
	for _, p in placed do
		if not (on or living) then
			releaseAll(p.joints)
		end
		if not on and p.aura then
			p.aura:Destroy()
			p.aura = nil
		end
		if not living then
			dropProps(p)
		end
	end
	if not on then
		for model in carried do
			stopCarried(model)
		end
	elseif claimedFolder then
		for _, child in claimedFolder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("ClaimPhase") == "Carrying" then
				startCarried(child)
			end
		end
	end
end
ReplicatedStorage:GetAttributeChangedSignal("JuiceOn"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("LivingOn"):Connect(refresh)
refresh()
UserInputService.LastInputTypeChanged:Connect(showFxSetting)
