-- Studio location: StarterPlayer.StarterPlayerScripts.HeistClient (LocalScript)
-- HeistClient  (Milestone 032, D22/D24) -- everything the Boss Heist shows; nothing here decides anything.
--   * Vault: the door swings open (wheel spins first) while State = Open, siren beacons flash, a two-tone
--     siren plays when it opens; both vault signs show "Opens in 3:20" / "OPEN! 0:42".
--   * HUD: a vault timer in the shared top bar ("Vault 3:20" / "OPEN 0:42" on red); while carrying, a panel
--     under the top bar (RUN TO THE SAFE ZONE!, shields left, time left, a bar from the vault to the safe line);
--     big centre messages (shield popped, capsule lost, SAFE!) and short refusals ("One capsule per opening!").
--   * Robot: moved here from the server's RobotPos/RobotYaw (smoothed), walk cycle, head turns to its target,
--     searchlight aims at its circle, stomp leg lift + slam. Attack warnings in the world: searchlight circle
--     (yellow, following -> red, locked, filling up), laser line (red strip filling along its length, then the
--     sweep), stomp ring (red ring + disc, then the shockwave ring rolling out).
--   * Shield bubbles around every carrier who still has one; capsule flies back to the vault when lost.
-- The grab prompt is hidden on this client after its own grab in an opening (server checks everything).
-- Low effects: fewer particles, no screen shake; the warnings themselves always show.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AquarisChaser = require(ReplicatedStorage:WaitForChild("AquarisChaser"))
local BossWarnings = require(ReplicatedStorage:WaitForChild("BossWarnings"))
local BossHeist = require(ReplicatedStorage:WaitForChild("BossHeist"))
local HeistConfig = require(ReplicatedStorage:WaitForChild("HeistConfig"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local T = UITheme.Colors
local event = ReplicatedStorage:WaitForChild("HeistEvent") :: RemoteEvent
local action = ReplicatedStorage:WaitForChild("HeistAction") :: RemoteEvent

local RED = Color3.fromRGB(255, 70, 90)
local CYAN = Color3.fromRGB(80, 230, 255)
local AMBER = Color3.fromRGB(255, 160, 40)
local GOLD = Color3.fromRGB(255, 214, 92)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function on(): boolean
	return ReplicatedStorage:GetAttribute(HeistConfig.PUBLISHED) == true
end

-- HUD ----------------------------------------------------------------------------------------------------------
local pill =
	UITheme.panel({ Name = "VaultPill", LayoutOrder = 0, Size = UDim2.fromOffset(if UITheme.v1 then 190 else 160, if UITheme.v1 then 60 else 44), Parent = UITheme.topBar() })
pill.Visible = false
UITheme.image({
	Icon = "vault",
	Name = "Icon",
	Size = UDim2.fromOffset(if UITheme.v1 then 44 else 30, if UITheme.v1 then 44 else 30),
	Position = UDim2.fromOffset(6, if UITheme.v1 then 8 else 7),
	Parent = pill,
})
local pillText = UITheme.text({
	Name = "Text",
	Text = "",
	Role = "Body",
	Align = "Left",
	Position = UDim2.fromOffset(if UITheme.v1 then 54 else 40, 0),
	Size = UDim2.new(1, if UITheme.v1 then -58 else -44, 1, 0),
	Parent = pill,
})
pillText.TextScaled = true
UITheme.make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12, Parent = pillText })

local gui, root = UITheme.gui("Heist032", 4)
-- carrier panel (under the top bar)
local panel = UITheme.panel({ Name = "CarryPanel", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(440, 104), Parent = root })
panel.Visible = false
UITheme.scaleWith(panel, 0.7, 1.1)
UITheme.image({ Icon = "capsule", Size = UDim2.fromOffset(78, 78), Position = UDim2.fromOffset(8, 13), Parent = panel })
local panelTitle = UITheme.text({
	Name = "Title",
	Text = "RUN TO THE SAFE ZONE!",
	Role = "Title",
	TextSize = 26,
	Color = GOLD,
	Align = "Left",
	Position = UDim2.fromOffset(94, 6),
	Size = UDim2.new(1, -100, 0, 32),
	Parent = panel,
})
panelTitle.TextScaled = true
local shields = {}
for i = 1, HeistConfig.HITS do
	shields[i] = UITheme.image({ Icon = "shield", Name = "Shield" .. i, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(94 + (i - 1) * 38, 40), Parent = panel })
end
local timeLabel = UITheme.text({
	Name = "Time",
	Text = "",
	Role = "Body",
	TextSize = 22,
	Align = "Left",
	Position = UDim2.fromOffset(94 + HeistConfig.HITS * 38 + 8, 40),
	Size = UDim2.fromOffset(150, 34),
	Parent = panel,
})
local track, setTrack = UITheme.bar({ Name = "Progress", Color = T.Cash, Position = UDim2.fromOffset(94, 80), Size = UDim2.new(1, -106, 0, 14), Parent = panel })
track.ZIndex = 2

-- big centre message
local big = UITheme.text({
	Name = "Big",
	Text = "",
	Role = "Display",
	TextSize = 44,
	TextWrapped = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(640, 120),
	Parent = root,
})
big.Visible = false
big.TextScaled = true
UITheme.make("UITextSizeConstraint", { MaxTextSize = 46, MinTextSize = 16, Parent = big })
UITheme.scaleWith(big, 0.7, 1.1)
local bigScale = UITheme.make("UIScale", { Parent = big })
local bigToken = 0
local function say(text: string, color: Color3, seconds: number?)
	bigToken += 1
	local token = bigToken
	big.Text = text
	big.TextColor3 = color
	big.Visible = true
	bigScale.Scale = 0.5
	UITheme.tween(bigScale, UITheme.Motion.Normal, { Scale = 1 }, Enum.EasingStyle.Back)
	gui:SetAttribute("LastMessage", text)
	task.delay(seconds or 2.5, function()
		if token == bigToken then
			big.Visible = false
		end
	end)
end

-- siren: two tones, a few times (Sounds setting respected through the SFX group)
local siren = Instance.new("Sound")
siren.Name = "HeistSiren"
siren.SoundId = "rbxasset://sounds/volume_slider.ogg"
siren.Volume = 0.7
siren.SoundGroup = UITheme.soundGroup("SFX")
siren.Parent = SoundService
local function playSiren()
	task.spawn(function()
		for i = 1, 8 do
			siren.PlaybackSpeed = if i % 2 == 1 then 2.2 else 1.6
			siren.TimePosition = 0
			siren:Play()
			task.wait(0.32)
		end
	end)
end

-- World ----------------------------------------------------------------------------------------------------------
local live: Folder? = nil
local fxFolder = Instance.new("Folder")
fxFolder.Name = "HeistFxLocal"
fxFolder.Parent = workspace

local function fxPart(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or fxFolder
	return p
end

-- Robot
type RobotPart = { part: BasePart, rest: CFrame, group: string }
local robotParts: { RobotPart } = {}
local pivots: { [string]: Vector3 } = {}
local robotList: { BasePart } = {}
local shown = { pos = nil :: Vector3?, yaw = 0, phase = 0, lift = 0, raise = 0, slamAt = 0, last = nil :: Vector3? }
local bossModel: Model? = nil -- (its root arrives with the rest of the model when the player gets near: stepRobot picks it up)
local bossRoot: BasePart? = nil -- 036 boss chaser (BossHeist): the boss model replaces the robot parts; the rig animates itself from the server's clip attributes
local bossLift = 0
local aquaris: any = nil -- AquarisChaser when the boss is Aquaris (no rig: its welds are posed here)
local bossEntry: BossHeist.Boss? = nil
local bossLens: Instance? = nil
local siren1: BasePart? = nil

-- Attack warnings: shared with the zone guardians (BossWarnings)
local function heistLens(_info: any): Vector3?
	if bossRoot then -- the boss chaser: the beam starts at its head (BossHeist lens part)
		local lensPart = bossLens
		return if lensPart and lensPart:IsA("BasePart") then lensPart.Position else bossRoot.Position + Vector3.new(0, 4, 0)
	end
	for _, rp in robotParts do
		if rp.part.Name == "Lens" then
			return rp.part.Position
		end
	end
	return nil
end
local fx = BossWarnings.new(fxFolder, heistLens, function()
	return if live then { live } else {}
end)

-- (the models are persistent, but their parts can still arrive over a few frames: wait for all of them)
local function waitParts(model: Instance, count: number, filter: (Instance) -> boolean)
	local t0 = os.clock()
	while os.clock() - t0 < 10 do
		local n = 0
		for _, c in model:GetChildren() do
			if filter(c) then
				n += 1
			end
		end
		if n >= count then
			return
		end
		task.wait(0.1)
	end
end

local function bindRobot(model: Instance)
	waitParts(model, model:GetAttribute("Parts") or 0, function(c)
		return c:IsA("BasePart")
	end)
	table.clear(robotParts)
	table.clear(robotList)
	bossRoot, bossEntry, bossLens, bossModel, aquaris = nil, nil, nil, nil, nil
	local bossZone = model:GetAttribute("BossHeist")
	if bossZone then
		bossEntry = BossHeist.forZone(bossZone)
		bossLift = model:GetAttribute("RootLift") or 0
		bossModel = model :: Model
		shown.pos = nil
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local group = p:GetAttribute("Group") or "Body"
			table.insert(robotParts, { part = p, rest = p:GetAttribute("Rest") or CFrame.new(), group = group })
			table.insert(robotList, p)
			pivots[group] = p:GetAttribute("Pivot") or Vector3.zero
			if p.Name == "Siren" then
				siren1 = p
			end
		end
	end
	shown.pos = nil
end

-- Vault door
type Swing = { part: BasePart, closed: CFrame, isWheel: boolean }
local swings: { Swing } = {}
local hinge, wheelCentre, wheelAxis = Vector3.zero, Vector3.zero, Vector3.xAxis
local doorOpen, doorAngle, wheelAngle = false, 0, 0

local function bindVault(vault: Instance)
	table.clear(swings)
	local door = vault:FindFirstChild("Door")
	if not door then
		return
	end
	waitParts(door, door:GetAttribute("Parts") or 0, function(c)
		return c:IsA("BasePart") and c:GetAttribute("Swing") == true
	end)
	hinge = door:GetAttribute("Hinge") or Vector3.zero
	wheelCentre = door:GetAttribute("WheelCentre") or Vector3.zero
	wheelAxis = door:GetAttribute("Axis") or Vector3.xAxis
	for _, p in door:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Swing") then
			table.insert(swings, { part = p, closed = p.CFrame, isWheel = p.Name == "Wheel" })
		end
	end
	doorAngle, wheelAngle = 0, 0
end

local robotConns: { RBXScriptConnection } = {}

local function dropRobot()
	bossRoot, bossEntry, bossLens, bossModel, aquaris = nil, nil, nil, nil, nil
	table.clear(robotParts)
	table.clear(robotList)
	siren1 = nil
	shown.pos = nil
end

-- The robot / boss model streams in by distance (StreamingEnabled), usually long after this script bound the folder: bind it whenever it arrives, drop it when it leaves.
local function bind(folder: Folder)
	live = folder
	for _, c in robotConns do
		c:Disconnect()
	end
	table.clear(robotConns)
	table.insert(
		robotConns,
		folder.ChildAdded:Connect(function(child)
			if child.Name == "Robot" then
				task.spawn(bindRobot, child)
			end
		end)
	)
	table.insert(
		robotConns,
		folder.ChildRemoved:Connect(function(child)
			if child.Name == "Robot" then
				dropRobot()
			end
		end)
	)
	local robot = folder:FindFirstChild("Robot")
	if robot then
		task.spawn(bindRobot, robot)
	end
	local vault = folder:WaitForChild("Vault", 10)
	if vault then
		bindVault(vault)
	end
end

local function unbind()
	live = nil
	for _, c in robotConns do
		c:Disconnect()
	end
	table.clear(robotConns)
	bossRoot, bossEntry, bossLens, bossModel, aquaris = nil, nil, nil, nil, nil
	table.clear(robotParts)
	table.clear(robotList)
	table.clear(swings)
	fx:clear()
	fxFolder:ClearAllChildren()
end

local function watchCity()
	local world = workspace:WaitForChild("World", 30)
	local city = world and world:WaitForChild("SkyCity", 30)
	if not city then
		return
	end
	city.ChildAdded:Connect(function(child)
		if child.Name == "Heist" and child:IsA("Folder") then
			bind(child)
		end
	end)
	city.ChildRemoved:Connect(function(child)
		if child == live then
			unbind()
		end
	end)
	local existing = city:FindFirstChild("Heist")
	if existing and existing:IsA("Folder") then
		bind(existing)
	end
end
task.spawn(watchCity)

-- The safe line's centre and the way home from it (Hub 2b attribute HomeSide; old lane = +Z).
local function safeLine(): (Vector3?, Vector3)
	local world = workspace:FindFirstChild("World")
	local lane = world and world:FindFirstChild("SkyCity") and world.SkyCity:FindFirstChild("Lane")
	local line = lane and lane:FindFirstChild("SafeLineWide")
	if line and line:IsA("BasePart") then
		local home = line:GetAttribute("HomeSide")
		if typeof(home) == "Vector3" and Vector3.new(home.X, 0, home.Z).Magnitude > 0.01 then
			return line.Position, Vector3.new(home.X, 0, home.Z).Unit
		end
		return line.Position, Vector3.new(0, 0, 1)
	end
	return nil, Vector3.new(0, 0, 1)
end

local function targetRoot(userId: number): BasePart?
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- Shield bubbles --------------------------------------------------------------------------------------------------
local bubbles: { [Player]: BasePart } = {}
local function stepBubbles()
	for _, p in Players:GetPlayers() do
		local want = p:GetAttribute("HeistCarrying") == true and (p:GetAttribute("HeistHits") or 0) < HeistConfig.HITS - 1
		local character = p.Character
		local r = character and character:FindFirstChild("HumanoidRootPart")
		local b = bubbles[p]
		if want and r and r:IsA("BasePart") then
			if not b then
				b = fxPart({ Name = "Shield", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Color = CYAN, Material = Enum.Material.ForceField, Transparency = 0.1 })
				bubbles[p] = b
			end
			(b :: BasePart).CFrame = r.CFrame
		elseif b then
			b:Destroy()
			bubbles[p] = nil
		end
	end
	for p, b in bubbles do
		if not p.Parent then
			b:Destroy()
			bubbles[p] = nil
		end
	end
end

-- Robot animation -------------------------------------------------------------------------------------------------
local function pivotRot(group: string, rot: CFrame): CFrame
	local pivot = pivots[group] or Vector3.zero
	return CFrame.new(pivot) * rot * CFrame.new(-pivot)
end

local stomp: { hitAt: number, startAt: number }? = nil
local laserUntil = 0
local cframes: { CFrame } = {}

local function stepRobot(dt: number, t: number)
	local folder = live
	if bossModel then -- pick up (or lose) the boss's root as the model streams in and out
		if bossRoot and not bossRoot:IsDescendantOf(workspace) then
			bossRoot, bossLens = nil, nil
			shown.pos = nil
		end
		if not bossRoot then
			local bossPart = bossModel:FindFirstChild("HumanoidRootPart")
			if bossPart and bossPart:IsA("BasePart") then
				bossRoot = bossPart
				bossLens = if bossEntry then bossModel:FindFirstChild(bossEntry.lens, true) else nil
				if bossEntry and not bossEntry.rig then
					aquaris = AquarisChaser.new(bossModel)
				end
				bossModel:SetAttribute("ClientBound", true) -- (local to this client: lets a Studio check see the chaser is bound)
			end
		end
	end
	if not (folder and (#robotParts > 0 or bossRoot)) then
		return
	end
	local target = folder:GetAttribute("RobotPos")
	if typeof(target) ~= "Vector3" then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - target).Magnitude > 400 then
		return -- far away: not drawn every frame
	end
	local yaw = folder:GetAttribute("RobotYaw") or 0
	local pos = shown.pos or target
	pos = pos:Lerp(target, math.clamp(dt * 9, 0, 1))
	local dyaw = (yaw - shown.yaw + math.pi) % (2 * math.pi) - math.pi
	shown.yaw += dyaw * math.clamp(dt * 8, 0, 1)
	if bossRoot then -- the boss: only its root is placed here (smoothed like the robot); every joint follows the root
		shown.last, shown.pos = pos, pos
		local place = CFrame.new(pos + Vector3.new(0, bossLift, 0)) * CFrame.Angles(0, shown.yaw, 0)
		bossRoot.CFrame = if aquaris then place * aquaris:step(t, place) else place
		return
	end
	local moved = if shown.last then ((pos - shown.last) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 1e-3) else 0
	shown.last, shown.pos = pos, pos
	local pace = math.clamp(moved / HeistConfig.ROBOT_SPEED, 0, 1)
	shown.phase += dt * 7 * pace
	local swing = math.sin(shown.phase) * 0.45 * pace
	local bob = math.abs(math.sin(shown.phase)) * 0.5 * pace + math.sin(t * 2) * 0.08
	-- stomp: lift the right leg during the warning, slam at hitAt
	local lift = 0
	if stomp then
		if t < stomp.hitAt then
			local k = math.clamp((t - stomp.startAt) / (stomp.hitAt - stomp.startAt), 0, 1)
			lift = 1.0 * (k * k * (3 - 2 * k))
		elseif t > stomp.hitAt + 0.5 then
			stomp = nil
		end
	end
	shown.lift += (lift - shown.lift) * math.clamp(dt * (if lift < shown.lift then 30 else 10), 0, 1)
	local raise = if t < laserUntil then 1.4 else 0
	shown.raise += (raise - shown.raise) * math.clamp(dt * 8, 0, 1)
	local rootCF = CFrame.new(pos) * CFrame.Angles(0, shown.yaw, 0)
	local body = CFrame.new(0, bob - shown.lift * 0.4, 0)
	-- head looks at its target (within reason)
	local headYaw = 0
	local targetId = folder:GetAttribute("RobotTarget")
	local tr = if type(targetId) == "number" then targetRoot(targetId) else nil
	if tr then
		local l = rootCF:PointToObjectSpace(tr.Position)
		headYaw = math.clamp(math.atan2(-l.X, -l.Z), -0.8, 0.8)
	end
	local light = CFrame.new()
	local lightAim = fx.aim -- world point the searchlight looks at
	if lightAim then
		local l = (rootCF * body):PointToObjectSpace(lightAim) - (pivots.Light or Vector3.zero)
		if l.Magnitude > 0.1 then
			light = CFrame.lookAt(Vector3.zero, l)
		end
	end
	local xf = {
		Body = body,
		Head = body * pivotRot("Head", CFrame.Angles(0, headYaw, 0)),
		ArmL = body * pivotRot("ArmL", CFrame.Angles(-swing * 0.8, 0, 0)),
		ArmR = body * pivotRot("ArmR", CFrame.Angles(swing * 0.8 + shown.raise, 0, 0)),
		LegL = pivotRot("LegL", CFrame.Angles(swing, 0, 0)),
		LegR = pivotRot("LegR", CFrame.Angles(-swing + shown.lift, 0, 0)),
		Light = body * pivotRot("Light", light),
	}
	for i, rp in robotParts do
		cframes[i] = rootCF * (xf[rp.group] or body) * rp.rest
	end
	for i = #robotParts + 1, #cframes do
		cframes[i] = nil
	end
	workspace:BulkMoveTo(robotList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	if siren1 then
		local mode = folder:GetAttribute("RobotMode")
		siren1.Color = if mode ~= "Dock" and math.floor(t * 4) % 2 == 0 then RED else AMBER
	end
end

-- Vault visuals -----------------------------------------------------------------------------------------------------
local OPEN_ANGLE = math.rad(-105)
local function stepVault(dt: number, t: number)
	local folder = live
	if not folder then
		return
	end
	local open = folder:GetAttribute("State") == "Open"
	if open ~= doorOpen then
		doorOpen = open
	end
	-- wheel spins while the door is moving; the door swings once the wheel has turned a bit
	local goal = if doorOpen then OPEN_ANGLE else 0
	if math.abs(doorAngle - goal) > 0.001 or (doorOpen and wheelAngle < math.pi * 2) then
		if doorOpen and wheelAngle < math.pi * 2 then
			wheelAngle += dt * 7
		else
			local step = dt * 1.6
			doorAngle = if doorAngle > goal then math.max(goal, doorAngle - step) else math.min(goal, doorAngle + step)
			if not doorOpen and math.abs(doorAngle - goal) < 0.001 then
				wheelAngle = 0
			end
		end
		local swing = CFrame.new(hinge) * CFrame.Angles(0, doorAngle, 0) * CFrame.new(-hinge)
		local spin = CFrame.new(wheelCentre) * CFrame.fromAxisAngle(wheelAxis, wheelAngle) * CFrame.new(-wheelCentre)
		for _, s in swings do
			s.part.CFrame = if s.isWheel then swing * spin * s.closed else swing * s.closed
		end
	end
	-- beacons
	local vault = folder:FindFirstChild("Vault")
	if vault then
		for i = 1, 2 do
			local b = vault:FindFirstChild("Beacon" .. i)
			if b and b:IsA("BasePart") then
				local flash = doorOpen and math.floor(t * 5 + i) % 2 == 0
				b.Color = if flash then RED else AMBER
				local l = b:FindFirstChild("Flash")
				if l and l:IsA("PointLight") then
					l.Enabled = doorOpen and flash
					l.Color = RED
				end
			end
		end
	end
end

-- Slow loop: signs, timer pill, carrier panel, prompt ---------------------------------------------------------------
local vaultAt: Vector3? = nil
local function setSign(folder: Folder, text: string, colour: Color3)
	local vault = folder:FindFirstChild("Vault")
	if not vault then
		return
	end
	for _, name in { "Sign", "DoorSign" } do
		local sign = vault:FindFirstChild(name)
		local g = sign and sign:FindFirstChild("SignFront")
		local status = g and g:FindFirstChild("Status")
		if status and status:IsA("TextLabel") then
			status.Text = text
			status.TextColor3 = colour
		end
	end
end

local function slow()
	local folder = live
	local t = now()
	pill.Visible = on() and folder ~= nil
	if folder then
		local open = folder:GetAttribute("State") == "Open"
		if open then
			local left = (folder:GetAttribute("ClosesAt") or t) - t
			pillText.Text = "OPEN " .. clock(left) -- (short: stays >= 12 px on the smallest phones)
			pillText.TextColor3 = GOLD
			pill.BackgroundColor3 = Color3.fromRGB(150, 40, 60)
			setSign(folder, "OPEN! Grab one: " .. clock(left), GOLD)
		else
			local wait = (folder:GetAttribute("OpensAt") or t) - t
			pillText.Text = "Treasury " .. clock(wait)
			pillText.TextColor3 = T.Text
			pill.BackgroundColor3 = T.Panel
			setSign(folder, "Opens in " .. clock(wait), Color3.new(1, 1, 1))
		end
		-- the prompt: hidden here after this player's grab in this opening, or while carrying anything
		local spot = folder:FindFirstChild("GrabSpot")
		local prompt = spot and spot:FindFirstChild("GrabPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			local mine = player:GetAttribute("HeistGrabbed") == folder:GetAttribute("OpeningId")
			local busy = player:GetAttribute("HeistCarrying") == true or player:GetAttribute("CarryingNPC") == true or player:GetAttribute("CarryingStolen") == true
			prompt.Enabled = open and not mine and not busy
		end
		if not vaultAt and spot and spot:IsA("BasePart") then
			vaultAt = spot.Position
		end
	end
	-- carrier panel
	local carrying = player:GetAttribute("HeistCarrying") == true and folder ~= nil
	panel.Visible = carrying
	if carrying then
		panel.Position = UDim2.new(0.5, 0, 0, UITheme.bannerTop())
		local hits = player:GetAttribute("HeistHits") or 0
		for i, s in shields do
			local alive = i <= HeistConfig.HITS - hits
			if s:IsA("ImageLabel") then
				s.ImageTransparency = if alive then 0 else 0.75
			end
		end
		local deadline = player:GetAttribute("HeistDeadline") or t
		timeLabel.Text = clock(deadline - t)
		timeLabel.TextColor3 = if deadline - t < 15 then RED else T.Text
		local lineAt, home = safeLine()
		local character = player.Character
		local r = character and character:FindFirstChild("HumanoidRootPart")
		if lineAt and vaultAt and r and r:IsA("BasePart") then
			local span = (lineAt - vaultAt):Dot(home)
			if math.abs(span) > 1 then
				setTrack(math.clamp((r.Position - vaultAt):Dot(home) / span, 0, 1))
			end
		end
	end
	gui:SetAttribute("Carrying", carrying)
end

-- Events ------------------------------------------------------------------------------------------------------------
event.OnClientEvent:Connect(function(kind: string, info: any)
	info = info or {}
	if kind == "Open" then
		playSiren()
		if player:GetAttribute("HeistCarrying") ~= true then
			say("THE TREASURY IS OPEN!", GOLD, 2.5)
		end
	elseif kind == "Attack" then
		fx:start(info)
		if info.kind == "Stomp" then
			stomp = { startAt = info.startAt, hitAt = info.hitAt }
		elseif info.kind == "Laser" then
			laserUntil = info.hitAt + 0.5
		end
		if info.targetId == player.UserId then
			local own = if bossEntry then (bossEntry.attacks :: any)[info.kind] else nil
			say(
				if own and own.callout
					then own.callout
					elseif info.kind == "Stomp" then "SHIELD SLAM! JUMP!"
					elseif info.kind == "Laser" then "SWORD SWEEP! Step aside!"
					else "ARROWS! Get out of the circle!",
				RED,
				1.4
			)
		end
	elseif kind == "Lock" then
		fx:lock(info.id, info.spot)
	elseif kind == "Cancel" then
		fx:finish(info.id)
	elseif kind == "Grab" then
		local r = targetRoot(info.userId)
		if r then
			FxKit.burst(r, "sparkle", GOLD, if FxKit.low() then 6 else 14)
		end
		if info.userId == player.UserId then
			say("RUN TO THE SAFE ZONE!", GOLD, 2)
			FxKit.sound("chime")
		end
	elseif kind == "Hit" then
		local r = targetRoot(info.userId)
		if r then
			FxKit.burst(r, "puff", CYAN, if FxKit.low() then 6 else 18)
		end
		if info.userId == player.UserId then
			say("SHIELD POPPED! One more hit and the capsule flies back!", CYAN, 2.5)
			FxKit.sound("deny")
			if not FxKit.low() then
				FxKit.shake(0.4, 0.3)
			end
		end
	elseif kind == "Lost" then
		local folder = live
		local pile = folder and folder:FindFirstChild("Vault") and folder.Vault:FindFirstChild("Pile")
		local sample = pile and pile:FindFirstChildWhichIsA("Model")
		if info.from and sample then
			local fly = sample:Clone()
			fly.Parent = fxFolder
			local from, to = info.from + Vector3.new(0, 4, 0), sample:GetPivot().Position
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 1.1 do
					local k = (os.clock() - t0) / 1.1
					local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 18, 0)
					fly:PivotTo(CFrame.new(p) * CFrame.Angles(0, k * 8, 0))
					RunService.RenderStepped:Wait()
				end
				fly:Destroy()
			end)
		end
		if info.userId == player.UserId then
			local text = if info.reason == "time"
				then "Out of time! The capsule flew back to the treasury."
				elseif info.reason == "fell" then "Oops! The capsule flew back to the treasury."
				elseif info.reason == "shortcut" then "No shortcuts! The capsule flew back to the treasury."
				else "Caught! The capsule flew back to the treasury."
			say(text .. " You kept all your coins.", RED, 3)
		end
	elseif kind == "Safe" then
		local r = targetRoot(info.userId)
		if r then
			FxKit.burst(r, "sparkle", GOLD, if FxKit.low() then 8 else 24)
			FxKit.text(r, "SAFE!", GOLD, 4)
		end
		if info.userId == player.UserId then
			say("SAFE! Opening your Boss Capsule...", GOLD, 1.6)
			FxKit.sound("safe")
		end
	elseif kind == "Msg" then
		say(info.text or "", Color3.new(1, 1, 1), 2.2)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not live then
		return
	end
	local t = now()
	stepRobot(dt, t)
	stepVault(dt, t)
	fx:step(t)
	stepBubbles()
end)

ReplicatedStorage:GetAttributeChangedSignal(HeistConfig.PUBLISHED):Connect(function()
	if on() then
		action:FireServer("State")
	end
end)
if on() then
	action:FireServer("State")
end

while true do
	slow()
	task.wait(0.25)
end
