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

local HeistConfig = require(ReplicatedStorage:WaitForChild("HeistConfig"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local T = UITheme.Colors
local event = ReplicatedStorage:WaitForChild("HeistEvent") :: RemoteEvent
local action = ReplicatedStorage:WaitForChild("HeistAction") :: RemoteEvent

local RED = Color3.fromRGB(255, 70, 90)
local YELLOW = Color3.fromRGB(255, 225, 90)
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
local lightAim: Vector3? = nil -- world point the searchlight looks at
local siren1: BasePart? = nil

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

local function bind(folder: Folder)
	live = folder
	local robot = folder:WaitForChild("Robot", 10)
	if robot then
		bindRobot(robot)
	end
	local vault = folder:WaitForChild("Vault", 10)
	if vault then
		bindVault(vault)
	end
end

local function unbind()
	live = nil
	table.clear(robotParts)
	table.clear(robotList)
	table.clear(swings)
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

local function safeLine(): (number?, number?)
	local world = workspace:FindFirstChild("World")
	local lane = world and world:FindFirstChild("SkyCity") and world.SkyCity:FindFirstChild("Lane")
	local line = lane and lane:FindFirstChild("SafeLineWide")
	if line and line:IsA("BasePart") then
		return line.Position.Z, line.Position.Y
	end
	return nil, nil
end

-- Attack warnings ------------------------------------------------------------------------------------------------
type Warning = { kind: string, info: any, parts: { BasePart }, spot: Vector3?, done: boolean }
local warnings: { [number]: Warning } = {}
local SEGMENTS = 28

local function ringParts(colour: Color3): { BasePart }
	local list = {}
	for i = 1, SEGMENTS do
		list[i] = fxPart({ Name = "Ring" .. i, Size = Vector3.new(0.5, 0.35, 1), Color = colour, Transparency = 0.15 })
	end
	return list
end

local function placeRing(list: { BasePart }, centre: Vector3, radius: number, from: number?)
	local seg = 2 * math.pi * radius / SEGMENTS
	for i = from or 1, (from or 1) + SEGMENTS - 1 do
		local p = list[i]
		local a = (i - (from or 1)) / SEGMENTS * 2 * math.pi
		local pos = centre + Vector3.new(math.cos(a) * radius, 0.25, math.sin(a) * radius)
		p.Size = Vector3.new(0.6, 0.35, math.max(0.4, seg * 1.05))
		p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
	end
end

local function disc(colour: Color3, radius: number, transparency: number): BasePart
	return fxPart({ Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2, radius * 2), Color = colour, Transparency = transparency })
end

local function flatDisc(p: BasePart, centre: Vector3, radius: number, lift: number)
	p.Size = Vector3.new(0.12, radius * 2, radius * 2)
	p.CFrame = CFrame.new(centre + Vector3.new(0, lift, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function targetRoot(userId: number): BasePart?
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function groundBelow(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { fxFolder }
	if live then
		table.insert(exclude, live)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local r = workspace:Raycast(pos, Vector3.new(0, -20, 0), params)
	return if r then r.Position else pos - Vector3.new(0, 3, 0)
end

local function startWarning(info: any)
	local w: Warning = { kind = info.kind, info = info, parts = {}, spot = nil, done = false }
	if info.kind == "Searchlight" then
		local fill = disc(YELLOW, 0.1, 0.35)
		local area = disc(YELLOW, info.radius, 0.6)
		local beam = fxPart({ Name = "Beam", Size = Vector3.new(2.4, 2.4, 1), Color = YELLOW, Transparency = 0.7 })
		w.parts = { area, fill, beam }
	elseif info.kind == "Laser" then
		local strip = fxPart({ Name = "Strip", Size = Vector3.new(info.length, 0.2, info.width), Color = RED, Transparency = 0.45 })
		local fill = fxPart({ Name = "Fill", Size = Vector3.new(0.1, 0.25, info.width * 0.6), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
		local wall = fxPart({ Name = "Laser", Size = Vector3.new(1.2, 10, info.width), Color = RED, Transparency = 1 })
		local cf = CFrame.lookAt(info.centre, info.centre + Vector3.new(info.across.Z, 0, -info.across.X))
		strip.CFrame = cf * CFrame.new(0, 0.12, 0) -- (local X = along the line, Z = its width)
		w.parts = { strip, fill, wall }
		w.spot = info.centre
	else -- Stomp
		local area = disc(RED, info.radius, 0.82)
		flatDisc(area, info.centre, info.radius, 0.08)
		local ring = ringParts(RED)
		placeRing(ring, info.centre, info.radius)
		local wave = ringParts(Color3.new(1, 1, 1))
		for _, p in wave do
			p.Transparency = 1
		end
		w.parts = { area }
		for _, p in ring do
			table.insert(w.parts, p)
		end
		for _, p in wave do
			table.insert(w.parts, p)
		end
		w.spot = info.centre
	end
	warnings[info.id] = w
	FxKit.sound("deny")
end

local function endWarning(id: number)
	local w = warnings[id]
	if w then
		warnings[id] = nil
		for _, p in w.parts do
			p:Destroy()
		end
	end
end

local function stepWarnings(t: number)
	for id, w in warnings do
		local info = w.info
		if w.kind == "Searchlight" then
			local area, fill, beam = w.parts[1], w.parts[2], w.parts[3]
			local centre = w.spot
			if not centre then
				local r = targetRoot(info.targetId)
				centre = if r then groundBelow(r.Position) else nil
			end
			if centre then
				local locked = w.spot ~= nil
				local colour = if locked then RED else YELLOW
				area.Color, fill.Color, beam.Color = colour, colour, colour
				flatDisc(area, centre, info.radius, 0.1)
				local k = if locked then math.clamp((t - info.lockAt) / (info.hitAt - info.lockAt), 0, 1) else 0
				flatDisc(fill, centre, math.max(0.1, info.radius * k), 0.14)
				area.Transparency = if locked then 0.45 + 0.2 * math.sin(t * 18) else 0.6
				lightAim = centre
				local lens = nil
				for _, rp in robotParts do
					if rp.part.Name == "Lens" then
						lens = rp.part.Position
					end
				end
				if lens then
					local len = (centre - lens).Magnitude
					beam.Size = Vector3.new(if locked then 1.6 else 2.4, if locked then 1.6 else 2.4, len)
					beam.CFrame = CFrame.lookAt((lens + centre) / 2, centre)
				end
			end
			if t >= info.hitAt + 0.35 then
				if centre and not w.done then
					w.done = true
					FxKit.burst(centre + Vector3.new(0, 1, 0), "glow", RED, if FxKit.low() then 6 else 14)
				end
				lightAim = nil
				endWarning(id)
			end
		elseif w.kind == "Laser" then
			local strip, fill, wall = w.parts[1], w.parts[2], w.parts[3]
			local k = math.clamp((t - info.startAt) / (info.hitAt - info.startAt), 0, 1)
			local cf = strip.CFrame
			fill.Size = Vector3.new(math.max(0.1, info.length * k), 0.26, info.width * 0.6)
			fill.CFrame = cf * CFrame.new(-info.length / 2 + info.length * k / 2, 0.02, 0)
			strip.Transparency = 0.35 + 0.2 * math.sin(t * 16)
			if t >= info.hitAt then
				local s = math.clamp((t - info.hitAt) / 0.45, 0, 1)
				wall.Transparency = 0.25
				wall.CFrame = cf * CFrame.new(-info.length / 2 + info.length * s, 5, 0)
				if not w.done then
					w.done = true
					FxKit.sound("steal")
				end
				if s >= 1 then
					endWarning(id)
				end
			end
		else -- Stomp
			local wave = {}
			for i = 2 + SEGMENTS, 1 + 2 * SEGMENTS do
				table.insert(wave, w.parts[i])
			end
			if t >= info.hitAt then
				if not w.done then
					w.done = true
					FxKit.burst(info.centre + Vector3.new(0, 1, 0), "puff", Color3.new(1, 1, 1), if FxKit.low() then 6 else 16)
					local cam = workspace.CurrentCamera
					if cam and (cam.CFrame.Position - info.centre).Magnitude < 60 and not FxKit.low() then
						FxKit.shake(0.5, 0.35)
					end
				end
				local r = info.waveSpeed * (t - info.hitAt)
				for _, p in wave do
					p.Transparency = 0.1
					p.Color = Color3.new(1, 1, 1)
				end
				placeRing(wave, info.centre, math.max(0.5, r))
				if r > info.radius + info.band then
					endWarning(id)
				end
			end
		end
	end
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
	if not (folder and #robotParts > 0) then
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
local vaultZ: number? = nil
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
		if not vaultZ and spot and spot:IsA("BasePart") then
			vaultZ = spot.Position.Z
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
		local z, _ = safeLine()
		local character = player.Character
		local r = character and character:FindFirstChild("HumanoidRootPart")
		if z and vaultZ and r and r:IsA("BasePart") then
			setTrack(math.clamp((r.Position.Z - vaultZ) / (z - vaultZ), 0, 1))
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
		startWarning(info)
		if info.kind == "Stomp" then
			stomp = { startAt = info.startAt, hitAt = info.hitAt }
		elseif info.kind == "Laser" then
			laserUntil = info.hitAt + 0.5
		end
		if info.targetId == player.UserId then
			say(if info.kind == "Stomp" then "SHIELD SLAM! JUMP!" elseif info.kind == "Laser" then "SWORD SWEEP! Step aside!" else "ARROWS! Get out of the circle!", RED, 1.4)
		end
	elseif kind == "Lock" then
		local w = warnings[info.id]
		if w then
			w.spot = info.spot
		end
	elseif kind == "Cancel" then
		endWarning(info.id)
		lightAim = nil
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
	stepWarnings(t)
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
