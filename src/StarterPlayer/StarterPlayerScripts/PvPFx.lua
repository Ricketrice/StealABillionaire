-- Studio location: StarterPlayer.StarterPlayerScripts.PvPFx (LocalScript)
-- PvPFx  (Milestone 022, phase 2)
-- Everything PvP that is seen or heard in the world, drawn on each client from what the server
-- replicates. Display only: nothing here decides an outcome, and nothing is created on the server.
--   * bats: swing trail, swing and charge poses (the arm is posed in code; no animation assets)
--   * hits: a burst and a short lean on the victim, one sound per attack
--   * special attacks: the warning ring / fan while it winds up, the blast when it lands
--   * thieves: a STOLEN tag above anyone carrying another player's worker
--   * bases: lock barrier, new-player protection barrier, countdowns, robbery alarm
-- Barriers are not solid for anyone: a lock stops new steals, it never traps a player.
-- All sounds are the stock Roblox ones at different pitches (placeholders for original sounds).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PvPBat = require(ReplicatedStorage:WaitForChild("PvPBat"))
local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local clientEvent = ReplicatedStorage:WaitForChild("PvPEvent", 60) :: RemoteEvent?
if not clientEvent then
	return
end
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
local C = UIStyle.Colors
local rgb = Color3.fromRGB

local LOCK_COLOR, SHIELD_COLOR, ALARM_COLOR = rgb(236, 190, 84), rgb(110, 180, 255), rgb(255, 70, 60)
-- Look and sound of each attack. sound = { file, speed, volume }.
local ATTACK_FX = {
	basic = { color = rgb(240, 232, 214), swing = { "action_jump.mp3", 1.9, 0.35 }, hit = { "action_jump_land.mp3", 1.5, 0.6 }, sparks = 10 },
	charged = { color = rgb(255, 196, 96), swing = { "action_jump.mp3", 1.15, 0.5 }, hit = { "impact_explosion_03.mp3", 2.1, 0.4 }, sparks = 22 },
	shockwave = {
		color = rgb(130, 200, 255),
		warn = { "action_get_up.mp3", 0.8, 0.5 },
		blast = { "impact_explosion_03.mp3", 0.95, 0.55 },
		hit = { "action_jump_land.mp3", 1.0, 0.6 },
		sparks = 18,
	},
	burst = {
		color = rgb(255, 150, 90),
		warn = { "action_get_up.mp3", 1.25, 0.5 },
		blast = { "impact_water.mp3", 1.35, 0.6 },
		hit = { "action_jump_land.mp3", 1.2, 0.6 },
		sparks = 18,
	},
}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "PvPLocalFx" -- exists only on this client
fxFolder.Parent = workspace

local function flagsOn(): boolean
	return ReplicatedStorage:GetAttribute("PvPStealing") == true or ReplicatedStorage:GetAttribute("WeaponCombat") == true
end
local function rootOf(userId: number): (BasePart?, Model?)
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil, character
end
local function playAt(part: BasePart?, sound)
	if not (part and sound) then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/" .. sound[1]
	s.PlaybackSpeed, s.Volume = sound[2], sound[3]
	s.RollOffMode, s.RollOffMinDistance, s.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 12, 110
	s.Parent = part
	s:Play()
	Debris:AddItem(s, 3)
end
local function ghost(part: BasePart) -- seen, never felt
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
end
local function tween(instance: Instance, time: number, goal, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Poses ---------------------------------------------------------------------------------------------
-- The right arm and the body lean are posed by adding to the joints' Transform after the normal
-- animations have run each frame, so they blend with walking and need no animation assets.
-- (2026-10-20: avatars with Roblox's joint upgrade have AnimationConstraint joints instead of Motor6Ds; both have the
-- Transform the animations write, so either is posed the same way. Without this the bat never visibly swung.)
local function joint(character: Model, partName: string, jointName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(jointName)
	return if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then motor :: any else nil
end
local function shoulder(character: Model): Motor6D?
	return joint(character, "RightUpperArm", "RightShoulder") or joint(character, "Torso", "Right Shoulder")
end
local function waist(character: Model): Motor6D?
	return joint(character, "LowerTorso", "Root") or joint(character, "HumanoidRootPart", "RootJoint")
end

local swings: { [Model]: { kind: string, at: number } } = {}
local leans: { [Model]: { at: number, x: number, z: number } } = {}
local charges: { [Model]: number } = {} -- character -> os.clock() when the charge began
local SWING_TIME = { basic = 0.3, charged = 0.36 }
local LEAN_TIME = 0.3

local function armPose(character: Model, t: number): CFrame?
	local swing = swings[character]
	if swing then
		local a = (t - swing.at) / SWING_TIME[swing.kind]
		if a >= 1 then
			swings[character] = nil
		elseif swing.kind == "charged" then
			-- overhead smash: from behind the head down to the front
			return CFrame.Angles(math.rad(175 - 150 * a * a), 0, 0)
		else
			-- flat swipe from the right to the left, arm held out in front
			return CFrame.Angles(0, math.rad(-65 + 135 * a), 0) * CFrame.Angles(math.rad(85), 0, 0)
		end
	end
	local began = charges[character]
	if began then
		local a = math.clamp((t - began) / 0.25, 0, 1)
		local shake = if t - began > PvPConfig.Attacks.charged.chargeTime then math.sin(t * 40) * 0.04 else 0
		return CFrame.Angles(math.rad(165 * a) + shake, 0, shake) -- bat raised behind the head, trembling when ready
	end
	return nil
end
-- A joint the normal animations write every frame simply gets our pose on top. One they leave
-- alone would keep it for ever, so it is put back to what it was when we stop posing it.
local held: { [Motor6D]: { base: CFrame, set: CFrame, frame: number } } = {}
local frame = 0
local function pose(motor: Motor6D, compute: (CFrame) -> CFrame)
	local entry = held[motor]
	local base = if entry and motor.Transform == entry.set then entry.base else motor.Transform
	local value = compute(base)
	motor.Transform = value
	if entry then
		entry.base, entry.set, entry.frame = base, value, frame
	else
		held[motor] = { base = base, set = value, frame = frame }
	end
end
RunService.Stepped:Connect(function()
	local t = os.clock()
	frame += 1
	local posed: { [Model]: boolean } = {}
	for character in swings do
		posed[character] = true
	end
	for character in charges do
		posed[character] = true
	end
	for character in posed do
		local motor = if character.Parent then shoulder(character) else nil
		local arm = if motor then armPose(character, t) else nil
		if motor and arm then
			pose(motor, function()
				return arm
			end)
		elseif not character.Parent then
			swings[character], charges[character] = nil, nil
		end
	end
	for character, lean in leans do
		local a = (t - lean.at) / LEAN_TIME
		local motor = if character.Parent then waist(character) else nil
		if a >= 1 or not motor then
			leans[character] = nil
		else
			local amount = math.sin(a * math.pi) * 0.42
			pose(motor, function(base)
				return base * CFrame.Angles(lean.x * amount, 0, lean.z * amount)
			end)
		end
	end
	for motor, entry in held do
		if entry.frame ~= frame then
			held[motor] = nil
			if motor.Parent and motor.Transform == entry.set then
				motor.Transform = entry.base
			end
		end
	end
end)

-- Bats: trail and charge glow ---------------------------------------------------------------------------
local function trailOf(character: Model): Trail?
	local bat = character:FindFirstChild("PvPBat")
	local grip = bat and bat:FindFirstChild("Grip")
	if not grip then
		return nil
	end
	local trail = grip:FindFirstChild("SwingTrail")
	if trail and trail:IsA("Trail") then
		return trail
	end
	local tip, base = grip:FindFirstChild("TrailTip"), grip:FindFirstChild("TrailBase")
	if not (tip and base and tip:IsA("Attachment") and base:IsA("Attachment")) then
		return nil
	end
	local skin = PvPBat.SKINS[bat:GetAttribute("Skin") or ""] or PvPBat.SKINS.Starter
	local new = Instance.new("Trail")
	new.Name = "SwingTrail"
	new.Attachment0, new.Attachment1 = tip, base
	new.Color = ColorSequence.new(skin.trail)
	new.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	new.Lifetime, new.MinLength, new.LightEmission, new.FaceCamera = 0.16, 0.05, 0.6, true
	new.Enabled = false
	new.Parent = grip
	return new
end
local function glow(character: Model, on: boolean)
	local bat = character:FindFirstChild("PvPBat")
	local grip = bat and bat:FindFirstChild("Grip")
	if not grip then
		return
	end
	local light = grip:FindFirstChild("ChargeGlow")
	if on and not light then
		local new = Instance.new("PointLight")
		new.Name = "ChargeGlow"
		new.Color, new.Range, new.Brightness = ATTACK_FX.charged.color, 10, 0
		new.Parent = grip
		tween(new, PvPConfig.Attacks.charged.chargeTime, { Brightness = 3 }, Enum.EasingStyle.Linear)
	elseif not on and light then
		light:Destroy()
	end
end

local function onSwing(info)
	local root, character = rootOf(info.user)
	local fx = ATTACK_FX[info.kind]
	if not (root and character and fx) then
		return
	end
	swings[character] = { kind = info.kind, at = os.clock() }
	playAt(root, fx.swing)
	local trail = trailOf(character)
	if trail then
		trail.Enabled = true
		task.delay(SWING_TIME[info.kind] or 0.3, function()
			trail.Enabled = false
		end)
	end
end

-- Charging is read from the replicated BatCharging attribute, so late joiners see it too.
local function showCharge(other: Player)
	local character = other.Character
	if not character then
		return
	end
	local on = other:GetAttribute("BatCharging") ~= nil
	charges[character] = if on then (charges[character] or os.clock()) else nil
	glow(character, on)
end

-- Hits ----------------------------------------------------------------------------------------------
local vignette: Frame? = nil
local function hurtFlash() -- a short red edge on this player's own screen; never blocks input
	if not vignette then
		local gui = Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "PvPHurt", false, true, 1
		local frame = Instance.new("Frame")
		frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency, frame.BorderSizePixel, frame.Active = UDim2.fromScale(1, 1), ALARM_COLOR, 1, 0, false
		frame.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		vignette = frame
	end
	local frame = vignette :: Frame
	frame.BackgroundTransparency = 0.72
	tween(frame, 0.35, { BackgroundTransparency = 1 })
end
local function burst(position: Vector3, color: Color3, count: number)
	local anchor = Instance.new("Part")
	ghost(anchor)
	anchor.Transparency, anchor.Size, anchor.CFrame = 1, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime, sparks.Speed, sparks.SpreadAngle = NumberRange.new(0.25, 0.45), NumberRange.new(14, 24), Vector2.new(180, 180)
	sparks.Drag, sparks.LightEmission, sparks.Rate, sparks.Enabled = 4, 0.8, 0, false
	sparks.Parent = anchor
	anchor.Parent = fxFolder
	sparks:Emit(count)
	Debris:AddItem(anchor, 1)
end
local function onHit(info)
	local root, character = rootOf(info.victim)
	local fx = ATTACK_FX[info.kind] or ATTACK_FX.basic
	if not (root and character) then
		return
	end
	burst(root.Position + Vector3.new(0, 1, 0), fx.color, fx.sparks)
	playAt(root, fx.hit)
	local direction = if typeof(info.direction) == "Vector3" then root.CFrame:VectorToObjectSpace(info.direction) else Vector3.new(0, 0, 1)
	leans[character] = { at = os.clock(), x = direction.Z, z = -direction.X } -- lean the way they were pushed
	if info.victim == player.UserId then
		hurtFlash()
	end
end

-- Special attacks -------------------------------------------------------------------------------------
local warnings: { [number]: { parts: { BasePart }, connection: RBXScriptConnection } } = {}
local function endWarning(userId: number)
	local warning = warnings[userId]
	if warning then
		warnings[userId] = nil
		warning.connection:Disconnect()
		for _, part in warning.parts do
			part:Destroy()
		end
	end
end
local function flat(color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	ghost(part)
	part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, transparency
	part.Parent = fxFolder
	return part
end
local function onTelegraph(info)
	local root = rootOf(info.user)
	local def, fx = PvPConfig.Specials[info.special], ATTACK_FX[info.special]
	if not (root and def and fx) then
		return
	end
	endWarning(info.user)
	playAt(root, fx.warn)
	local parts: { BasePart } = {}
	local began, duration = os.clock(), info.duration or def.telegraph
	local place: (number) -> ()
	if def.shape == "radial" then
		local ring = flat(fx.color, 0.55) -- a disc on the ground that grows to the blast's reach
		ring.Shape = Enum.PartType.Cylinder
		parts[1] = ring
		place = function(a: number)
			local size = 2 * def.range * a
			ring.Size = Vector3.new(0.25, size, size)
			ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end
	else
		local half = math.acos(def.arcDot) -- a fan of rays showing where the push will go
		for i = -2, 2 do
			parts[#parts + 1] = flat(fx.color, 0.45)
		end
		place = function(a: number)
			local length = def.range * a
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local base =
				CFrame.lookAt(root.Position - Vector3.new(0, 2.6, 0), root.Position - Vector3.new(0, 2.6, 0) + (if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)))
			for index, part in parts do
				local angle = (index - 3) / 2 * half
				part.Size = Vector3.new(0.5, 0.25, math.max(length, 0.1))
				part.CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2)
			end
		end
	end
	local connection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			endWarning(info.user)
			return
		end
		place(math.clamp((os.clock() - began) / duration, 0.05, 1))
	end)
	warnings[info.user] = { parts = parts, connection = connection }
	task.delay(duration + 0.6, function() -- in case the result never arrives
		local warning = warnings[info.user]
		if warning and warning.parts == parts then
			endWarning(info.user)
		end
	end)
end
local function onSpecial(info)
	local root = rootOf(info.user)
	local def, fx = PvPConfig.Specials[info.special], ATTACK_FX[info.special]
	endWarning(info.user)
	if not (root and def and fx) then
		return
	end
	playAt(root, fx.blast)
	if def.shape == "radial" then
		local wave = flat(fx.color, 0.2)
		wave.Shape = Enum.PartType.Cylinder
		wave.Size = Vector3.new(0.4, 3, 3)
		wave.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		tween(wave, 0.3, { Size = Vector3.new(0.4, 2 * def.range, 2 * def.range), Transparency = 1 })
		Debris:AddItem(wave, 0.4)
	else
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
		local gust = flat(fx.color, 0.25)
		gust.Size = Vector3.new(5, 4, 2)
		gust.CFrame = CFrame.lookAt(root.Position + look * 2, root.Position + look * 3)
		tween(gust, 0.28, { CFrame = gust.CFrame + look * def.range, Size = Vector3.new(11, 5, 2), Transparency = 1 })
		Debris:AddItem(gust, 0.4)
	end
	burst(root.Position, fx.color, 14)
end

clientEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then
		return
	end
	if kind == "Swing" then
		onSwing(info)
	elseif kind == "Hit" then
		onHit(info)
	elseif kind == "Telegraph" then
		onTelegraph(info)
	elseif kind == "Special" then
		onSpecial(info)
	elseif kind == "TelegraphEnd" then
		endWarning(info.user)
	end
end)

-- STOLEN tag above thieves ------------------------------------------------------------------------------
local function billboard(name: string, size: UDim2, offset: Vector3, maxDistance: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.StudsOffsetWorldSpace, gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance, gui.ResetOnSpawn = name, size, offset, true, 0, maxDistance, false
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency, label.Size = "Label", 1, UDim2.fromScale(1, 1)
	label.Font, label.TextScaled, label.TextColor3, label.RichText = UIStyle.Font, true, C.Text, true
	label.Parent = gui
	UIStyle.outline(label)
	return gui, label
end
local tags: { [Player]: BillboardGui } = {}
local function updateTag(other: Player)
	local character = other.Character
	local head = character and character:FindFirstChild("Head")
	local on = other:GetAttribute("CarryingStolen") == true and head ~= nil
	local tag = tags[other]
	if on and not tag then
		local gui, label = billboard("StolenTag", UDim2.fromOffset(150, 34), Vector3.new(0, 5.2, 0), 220)
		label.Text, label.TextColor3 = "STOLEN!", ALARM_COLOR
		gui.Parent = player:WaitForChild("PlayerGui")
		tags[other] = gui
		tag = gui
	end
	if tag then
		tag.Adornee = if on then head else nil
		tag.Enabled = on
	end
end
local function watchPlayer(other: Player)
	other:GetAttributeChangedSignal("CarryingStolen"):Connect(function()
		updateTag(other)
	end)
	other:GetAttributeChangedSignal("BatCharging"):Connect(function()
		showCharge(other)
	end)
	other.CharacterAdded:Connect(function()
		task.defer(updateTag, other)
		task.defer(showCharge, other)
	end)
	updateTag(other)
	showCharge(other)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in Players:GetPlayers() do
	watchPlayer(other)
end
Players.PlayerRemoving:Connect(function(other)
	local tag = tags[other]
	tags[other] = nil
	if tag then
		tag:Destroy()
	end
	endWarning(other.UserId)
end)

-- Bases: barrier, countdown and robbery alarm on every plot ------------------------------------------------
type PlotFx = {
	holder: Folder,
	walls: { BasePart },
	sign: BillboardGui,
	label: TextLabel,
	beacon: Part,
	light: PointLight,
	state: string,
	beeps: number,
	nextBeep: number,
	alarmKey: string,
}
local plotFx: { [Instance]: PlotFx } = {}
local WALL_HEIGHT = 9

local function buildPlotFx(plot: Model): PlotFx?
	local floor = plot.PrimaryPart
	if not floor then
		return nil
	end
	local holder = Instance.new("Folder")
	holder.Name = plot.Name
	holder.Parent = fxFolder
	local walls = {}
	local x, z = floor.Size.X, floor.Size.Z
	for _, side in { { 0, -z / 2, x, 0.3 }, { 0, z / 2, x, 0.3 }, { -x / 2, 0, 0.3, z }, { x / 2, 0, 0.3, z } } do
		local wall = Instance.new("Part")
		ghost(wall)
		wall.Name, wall.Material, wall.Transparency = "Barrier", Enum.Material.ForceField, 1
		wall.Size = Vector3.new(side[3], WALL_HEIGHT, side[4])
		wall.CFrame = floor.CFrame * CFrame.new(side[1], WALL_HEIGHT / 2, side[2])
		wall.Parent = holder
		table.insert(walls, wall)
	end
	local beacon = Instance.new("Part")
	ghost(beacon)
	beacon.Name, beacon.Shape, beacon.Material, beacon.Color, beacon.Transparency = "AlarmBeacon", Enum.PartType.Ball, Enum.Material.Neon, ALARM_COLOR, 1
	beacon.Size = Vector3.new(2.4, 2.4, 2.4)
	beacon.CFrame = floor.CFrame * CFrame.new(0, 15, 0)
	beacon.Parent = holder
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Enabled = ALARM_COLOR, 40, 4, false
	light.Parent = beacon
	local sign, label = billboard("PlotSign_" .. plot.Name, UDim2.fromOffset(330, 60), Vector3.new(0, 0, 0), 260)
	sign.Adornee, sign.Enabled = beacon, false
	sign.StudsOffsetWorldSpace = Vector3.new(0, -3.2, 0)
	sign.Parent = player:WaitForChild("PlayerGui")
	return { holder = holder, walls = walls, sign = sign, label = label, beacon = beacon, light = light, state = "", beeps = 0, nextBeep = 0, alarmKey = "" }
end
local function clockText(seconds: number): string
	local s = math.ceil(seconds)
	return ("%d:%02d"):format(s // 60, s % 60)
end
local function left(plot: Instance, attribute: string, now: number): number
	return math.max(0, (plot:GetAttribute(attribute) or 0) - now)
end
local function updatePlots()
	local now = workspace:GetServerTimeNow()
	local on = flagsOn()
	local ownId = player:GetAttribute("PlotId")
	for _, plot in plots:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end
		local fx = plotFx[plot]
		local locked, protected, recharging = left(plot, "LockedUntil", now), left(plot, "ProtectedUntil", now), left(plot, "LockCooldownUntil", now)
		local thief, worker = plot:GetAttribute("AlarmThief"), plot:GetAttribute("AlarmWorker")
		local own = plot:GetAttribute("PlotId") == ownId
		local alarm = on and type(thief) == "string"
		local barrier = if not on then "" elseif locked > 0 then "lock" elseif protected > 0 then "shield" else ""
		if not fx then
			if not (alarm or barrier ~= "" or (own and on and recharging > 0)) then
				continue -- nothing to show here yet: build nothing
			end
			fx = buildPlotFx(plot)
			if not fx then
				continue
			end
			plotFx[plot] = fx
		end
		local f = fx :: PlotFx
		if f.state ~= barrier then
			f.state = barrier
			local color = if barrier == "lock" then LOCK_COLOR else SHIELD_COLOR
			for _, wall in f.walls do
				wall.Color = color
				tween(wall, 0.25, { Transparency = if barrier == "" then 1 else 0.35 })
			end
			f.holder:SetAttribute("Barrier", if barrier == "" then nil else barrier)
		end
		local lines = {}
		if alarm then
			table.insert(lines, ('<font color="#ff5a4c">ROBBERY! %s has %s</font>'):format(thief, if type(worker) == "string" then worker else "a creature"))
		end
		if barrier == "lock" then
			table.insert(lines, ('<font color="#ecbe54">LOCKED %s</font>'):format(clockText(locked)))
		elseif barrier == "shield" then
			table.insert(lines, ('<font color="#6eb4ff">PROTECTED %s</font>'):format(clockText(protected)))
		elseif own and on and recharging > 0 and not alarm then
			table.insert(lines, ('<font color="#a4aabe">LOCK READY IN %s</font>'):format(clockText(recharging)))
		end
		f.sign.Enabled = #lines > 0
		f.label.Text = table.concat(lines, "\n")
		f.holder:SetAttribute("Sign", if #lines > 0 then f.label.Text else nil)
		-- Alarm: the beacon blinks for as long as the robbery lasts; the beeps stop after a few.
		local key = if alarm then thief .. "|" .. tostring(worker) else ""
		if key ~= f.alarmKey then
			f.alarmKey, f.beeps, f.nextBeep = key, 0, 0
		end
		local blink = alarm and (os.clock() % 0.6) < 0.3
		f.beacon.Transparency = if blink then 0.1 else 1
		f.light.Enabled = blink
		f.holder:SetAttribute("Alarm", if alarm then true else nil)
		if alarm and f.beeps < PvPConfig.Alarm.MAX_BEEPS and os.clock() >= f.nextBeep then
			f.beeps += 1
			f.nextBeep = os.clock() + PvPConfig.Alarm.BEEP_INTERVAL
			if not own then -- the owner hears the alarm from PvPAlerts wherever they are
				playAt(f.beacon, { "volume_slider.ogg", if f.beeps % 2 == 0 then 1.5 else 2.0, 0.5 })
			end
		end
	end
end

while true do
	updatePlots()
	for other in tags do
		updateTag(other)
	end
	task.wait(0.15)
end
