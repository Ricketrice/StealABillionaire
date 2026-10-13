-- Studio location: StarterPlayer.StarterPlayerScripts.RaceClient (LocalScript)
-- RaceClient  (Milestone 031, D21 Royale Race): display only. The pad sign's status line ("Join the race! 12",
-- "Next race in 2:41", ...), the pad message for a player standing on the pad (big on screen + a billboard above
-- the pad: the round's status, or why they can't race from the RaceBlock attribute, 032), the big 5-4-3-2-1-GO
-- countdown in its last seconds (for players on the pad), the race HUD (big "LAP 2/3" + time left + an arrow to
-- the next checkpoint), a glowing arch over the next checkpoint (this client only, 032), the capsule pop at the
-- finish (the reveal card itself comes from WorkerRevealCard) and the top-3 banner after a race.
-- Everything is read from Workspace.World.VelocityRoyale.RaceCourse attributes, the local player's
-- Racing / RaceLap attributes and RaceEvent; RaceService decides everything. Nothing runs while RaceOn is off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local clientEvent = ReplicatedStorage:WaitForChild("RaceEvent") :: RemoteEvent
local actionEvent = ReplicatedStorage:WaitForChild("RaceAction") :: RemoteEvent
local C = UITheme.Colors
local GOLD, SILVER = Color3.fromRGB(255, 208, 0), Color3.fromRGB(214, 224, 236)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function course(): Instance?
	local world = workspace:FindFirstChild("World")
	local royale = world and world:FindFirstChild("VelocityRoyale")
	return royale and royale:FindFirstChild(RaceConfig.FOLDER)
end

-- Sounds: Roblox's own built-in files, pitched (like UIKit's defaults).
local sounds: { [string]: Sound } = {}
local function beep(name: string, speed: number, volume: number?)
	local s = sounds[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Race_" .. name
		s.SoundId = if name == "go" then "rbxasset://sounds/action_get_up.mp3" else "rbxasset://sounds/volume_slider.ogg"
		s.SoundGroup = UITheme.soundGroup("SFX")
		s.Parent = SoundService
		sounds[name] = s
	end
	s.PlaybackSpeed = speed
	s.Volume = volume or 0.7
	s.TimePosition = 0
	s:Play()
end

-- HUD -------------------------------------------------------------------------------------------------------
local _, root = UITheme.gui("Race031", 8)

-- Race panel: top centre under the shared top piece. Big LAP counter + time left + arrow to the next checkpoint.
local panel = UITheme.panel({ Name = "RacePanel", Size = UDim2.fromOffset(320, 104), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = root })
local scale = Instance.new("UIScale")
scale.Parent = panel
local lapLabel = UITheme.text({
	Name = "Lap",
	Text = "LAP 1/3",
	Role = "Display",
	TextSize = 44,
	Color = GOLD,
	Size = UDim2.new(1, -100, 0, 54),
	Position = UDim2.fromOffset(8, 4),
	Parent = panel,
})
local timeLabel =
	UITheme.text({ Name = "Time", Text = "1:00", Role = "Title", TextSize = 28, Size = UDim2.new(1, -100, 0, 36), Position = UDim2.fromOffset(8, 60), Parent = panel })
-- the arrow: a gold chevron in a dial that turns to point at the next checkpoint (up = straight ahead)
local arrow = Instance.new("Frame")
arrow.Name = "NextArrow"
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Size = UDim2.fromOffset(76, 76)
arrow.Position = UDim2.new(1, -48, 0.5, 0)
arrow.BackgroundColor3 = C.Stroke
arrow.BackgroundTransparency = 0.35
arrow.Parent = panel
UITheme.corner(arrow, UDim.new(1, 0))
for _, side in { -1, 1 } do
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = UDim2.fromOffset(13, 42)
	bar.Position = UDim2.fromScale(0.5 + side * 0.15, 0.52)
	bar.Rotation = side * 38
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.Parent = arrow
	UITheme.corner(bar, UDim.new(0, 5))
end

-- Pad message (032): big, top centre, while this player stands on the pad and isn't racing.
local padPanel = UITheme.panel({ Name = "PadMessage", Size = UDim2.fromOffset(560, 116), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = root })
local padScale = Instance.new("UIScale")
padScale.Parent = padPanel
local padBig = UITheme.text({
	Name = "Big",
	Text = "",
	Role = "Display",
	TextSize = 46,
	Color = GOLD,
	Size = UDim2.new(1, -20, 0, 62),
	Position = UDim2.fromOffset(10, 6),
	Parent = padPanel,
})
local padSmall = UITheme.text({ Name = "Small", Text = "", Role = "Title", TextSize = 24, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 72), Parent = padPanel })

-- Countdown number, screen centre.
local countLabel = UITheme.text({
	Name = "Count",
	Text = "",
	Role = "Display",
	TextSize = 150,
	Color = C.Text,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(420, 180),
	Visible = false,
	Parent = root,
})
local countScale = Instance.new("UIScale")
countScale.Parent = countLabel
local countBase = 1

-- Finish banner + capsule.
local banner = UITheme.panel({
	Name = "FinishBanner",
	Size = UDim2.fromOffset(440, 150),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Visible = false,
	Parent = root,
})
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local placeLabel =
	UITheme.text({ Name = "Place", Text = "", Role = "Display", TextSize = 40, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 8), Parent = banner })
local capsuleLabel = UITheme.text({
	Name = "Capsule",
	Text = "",
	Role = "Title",
	TextSize = 26,
	Size = UDim2.new(1, -110, 0, 36),
	Position = UDim2.fromOffset(100, 70),
	Align = "Left",
	Parent = banner,
})
local capsule = Instance.new("Frame")
capsule.Name = "CapsuleBall"
capsule.Size = UDim2.fromOffset(70, 70)
capsule.Position = UDim2.fromOffset(22, 60)
capsule.BorderSizePixel = 0
capsule.Parent = banner
UITheme.corner(capsule, UDim.new(1, 0))
UITheme.stroke(capsule, C.Stroke, 4)
local capsuleBand = Instance.new("Frame")
capsuleBand.Size = UDim2.new(1, 0, 0, 8)
capsuleBand.AnchorPoint = Vector2.new(0, 0.5)
capsuleBand.Position = UDim2.fromScale(0, 0.5)
capsuleBand.BackgroundColor3 = C.Stroke
capsuleBand.BorderSizePixel = 0
capsuleBand.Parent = capsule
local capsuleScale = Instance.new("UIScale")
capsuleScale.Parent = capsule

-- Podium banner after a race (players near the circuit).
local podium = UITheme.panel({ Name = "PodiumBanner", Size = UDim2.fromOffset(420, 120), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = root })
local podiumScale = Instance.new("UIScale")
podiumScale.Parent = podium
local podiumTitle = UITheme.text({
	Name = "Title",
	Text = "RACE RESULTS",
	Role = "Title",
	TextSize = 24,
	Color = GOLD,
	Size = UDim2.new(1, -16, 0, 30),
	Position = UDim2.fromOffset(8, 6),
	Parent = podium,
})
local podiumRows = UITheme.text({
	Name = "Rows",
	Text = "",
	Role = "Body",
	TextSize = 20,
	TextWrapped = true,
	Size = UDim2.new(1, -16, 1, -44),
	Position = UDim2.fromOffset(8, 38),
	Parent = podium,
})
podiumRows.TextYAlignment = Enum.TextYAlignment.Top
local _ = podiumTitle

UITheme.onHudLayout(root, function(view)
	local s = math.clamp(view.scale, 0.62, 1.1)
	scale.Scale, bannerScale.Scale, podiumScale.Scale, padScale.Scale = s, s, s, s
	countBase = math.clamp(view.size.Y / 720, 0.55, 1.2)
	countScale.Scale = countBase
	local top = UITheme.bannerTop()
	panel.Position = UDim2.fromOffset(view.size.X / 2, top)
	podium.Position = UDim2.fromOffset(view.size.X / 2, top)
	padPanel.Position = UDim2.fromOffset(view.size.X / 2, top)
end)

-- Countdown ---------------------------------------------------------------------------------------------------
local function nearPad(): boolean
	local folder = course()
	local pad = folder and folder:FindFirstChild("StartPad")
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (pad and pad:IsA("BasePart") and rootPart and rootPart:IsA("BasePart")) then
		return false
	end
	local p = pad.CFrame:PointToObjectSpace(rootPart.Position)
	return math.abs(p.X) <= pad.Size.X / 2 + 1 and math.abs(p.Z) <= pad.Size.Z / 2 + 1 and p.Y > -2 and p.Y < 10
end

local countToken = 0
local function pop(text: string, color: Color3)
	countLabel.Text = text
	countLabel.TextColor3 = color
	countLabel.Visible = true
	countScale.Scale = countBase * 1.3
	UITheme.tween(countScale, 0.25, { Scale = countBase }, Enum.EasingStyle.Back)
end

local function runCountdown(goAt: number)
	countToken += 1
	local token = countToken
	task.spawn(function()
		local shown = -1
		while token == countToken do
			local left = goAt - serverNow()
			if left <= 0 then
				break
			end
			local n = math.ceil(left)
			if n ~= shown then
				shown = n
				if n <= RaceConfig.COUNTDOWN and (nearPad() or player:GetAttribute("Racing")) then
					pop(tostring(n), C.Text)
					beep("tick", 1 + (5 - n) * 0.08)
				else
					countLabel.Visible = false
				end
			end
			task.wait(0.05)
		end
		if token ~= countToken then
			return
		end
		if player:GetAttribute("Racing") or nearPad() then
			pop("GO!", GOLD)
			beep("go", 1.3, 0.8)
			task.wait(0.9)
		end
		if token == countToken then
			countLabel.Visible = false
		end
	end)
end

-- Next checkpoint (032): one glowing arch over the gate the server expects next (RaceNext), this client only.
local routeFolder = Instance.new("Folder")
routeFolder.Name = "RaceRouteLocal"
routeFolder.Parent = workspace
local archKey: string? = nil
local archTarget: Vector3? = nil

local function gateFor(order: number): CFrameValue?
	local folder = course()
	local route = folder and folder:FindFirstChild("Route")
	for _, v in (route and route:GetChildren() or {}) do
		if v:IsA("CFrameValue") and v:GetAttribute("Order") == order then
			return v
		end
	end
	return nil
end

local function buildArch(cf: CFrame, size: Vector3)
	-- gate boxes start 1 stud below the track surface; the arch stands on the surface, across the track
	local base = cf * CFrame.new(0, -(size.Y / 2 - 1), 0)
	local radius, n = size.X / 2 - 0.5, 14
	for i = 0, n - 1 do
		local a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
		local p0 = Vector3.new(radius * math.cos(a0), radius * 1.1 * math.sin(a0), 0)
		local p1 = Vector3.new(radius * math.cos(a1), radius * 1.1 * math.sin(a1), 0)
		local mid = (p0 + p1) / 2
		local seg = Instance.new("Part")
		seg.Name = "Arch"
		seg.Anchored = true
		seg.CanCollide, seg.CanQuery, seg.CanTouch = false, false, false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = GOLD
		seg.Size = Vector3.new(0.8, 0.8, (p1 - p0).Magnitude + 0.3)
		seg.CFrame = base * CFrame.lookAt(mid, mid + (p1 - p0))
		seg.Parent = routeFolder
	end
end

local function refreshArch()
	local order = player:GetAttribute("RaceNext")
	local key = if player:GetAttribute("Racing") == true and type(order) == "number" then tostring(order) .. "/" .. tostring(player:GetAttribute("RaceLap")) else nil
	if key == archKey then
		return
	end
	archKey = key
	routeFolder:ClearAllChildren() -- passed gates disappear: only the next one is shown
	archTarget = nil
	local gate = key and gateFor(order)
	if gate then
		local size = gate:GetAttribute("Size")
		buildArch(gate.Value, if typeof(size) == "Vector3" then size else Vector3.new(15, 16, 8))
		archTarget = gate.Value.Position
	end
end
player:GetAttributeChangedSignal("RaceNext"):Connect(refreshArch)

RunService.RenderStepped:Connect(function()
	if not archTarget then
		return
	end
	local pulse = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 6))
	for _, seg in routeFolder:GetChildren() do
		(seg :: BasePart).Transparency = pulse
	end
	local camera = workspace.CurrentCamera
	if panel.Visible and camera then
		local rel = camera.CFrame:VectorToObjectSpace(archTarget - camera.CFrame.Position)
		arrow.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
	end
end)

-- Race HUD ----------------------------------------------------------------------------------------------------
local endsAt = 0
local function refreshPanel()
	local racing = player:GetAttribute("Racing") == true
	panel.Visible = racing
	refreshArch()
	if racing then
		local lap = player:GetAttribute("RaceLap") or 1
		lapLabel.Text = ("LAP %d/%d"):format(lap, RaceConfig.LAPS)
	end
end
player:GetAttributeChangedSignal("Racing"):Connect(refreshPanel)
player:GetAttributeChangedSignal("RaceLap"):Connect(function()
	refreshPanel()
	if player:GetAttribute("RaceLap") and player:GetAttribute("RaceLap") > 1 then
		lapLabel.TextColor3 = C.Text
		UITheme.tween(lapLabel, 0.6, { TextColor3 = GOLD })
		beep("lap", 1.6)
	end
end)

local finishToken = 0
local function showFinish(info: any)
	finishToken += 1
	local token = finishToken
	local place = tonumber(info.place) or 0
	local suffix = if place % 10 == 1 and place ~= 11 then "st" elseif place % 10 == 2 and place ~= 12 then "nd" elseif place % 10 == 3 and place ~= 13 then "rd" else "th"
	local gold = info.capsule == "Gold"
	placeLabel.Text = ("%d%s place!"):format(place, suffix)
	placeLabel.TextColor3 = if gold then GOLD else C.Text
	capsuleLabel.Text = if gold then "GOLD capsule!" else "SILVER capsule!"
	capsuleLabel.TextColor3 = if gold then GOLD else SILVER
	capsule.BackgroundColor3 = if gold then GOLD else SILVER
	capsule.Rotation = 0
	banner.Visible = true
	capsuleScale.Scale = 0.2
	UITheme.tween(capsuleScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	beep("go", 1.6, 0.8)
	-- wobble, then burst just before the reveal card
	task.spawn(function()
		for i = 1, 6 do
			if token ~= finishToken then
				return
			end
			capsule.Rotation = if i % 2 == 0 then -14 else 14
			task.wait(0.1)
		end
		capsule.Rotation = 0
		UITheme.tween(capsuleScale, 0.18, { Scale = 1.6 })
		task.wait(0.2)
		if token == finishToken then
			banner.Visible = false
		end
	end)
end

local podiumToken = 0
local function showPodium(rows: any)
	if type(rows) ~= "table" or #rows == 0 then
		return
	end
	local folder = course()
	local pad = folder and folder:FindFirstChild("StartPad")
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (pad and pad:IsA("BasePart") and rootPart and rootPart:IsA("BasePart")) or (rootPart.Position - pad.Position).Magnitude > 160 then
		return -- only for players at Velocity Royale
	end
	local lines = {}
	for i, row in rows do
		table.insert(lines, ("%s  %s"):format(({ "1st", "2nd", "3rd" })[i] or tostring(i), tostring(row.name)))
	end
	podiumRows.Text = table.concat(lines, "\n")
	podium.Position = UDim2.fromOffset(root.AbsoluteSize.X / 2, UITheme.bannerTop())
	podium.Visible = true
	podiumToken += 1
	local token = podiumToken
	task.delay(6, function()
		if token == podiumToken then
			podium.Visible = false
		end
	end)
end

clientEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Countdown" and type(info) == "table" and type(info.goAt) == "number" then
		runCountdown(info.goAt)
	elseif kind == "Go" and type(info) == "table" then
		endsAt = tonumber(info.endsAt) or 0
		refreshPanel()
	elseif kind == "State" and type(info) == "table" then
		endsAt = tonumber(info.endsAt) or endsAt
		refreshPanel()
	elseif kind == "Finish" and type(info) == "table" then
		panel.Visible = false
		showFinish(info)
	elseif kind == "Out" and type(info) == "table" then
		panel.Visible = false
		UITheme.toast("error", "Royale Race", tostring(info.reason or "Out of the race."))
	elseif kind == "End" and type(info) == "table" then
		showPodium(info.podium)
	end
end)

-- Sign + timer loop -------------------------------------------------------------------------------------------
local function signText(folder: Instance): string
	local state = folder:GetAttribute("State")
	local now = serverNow()
	local ready = folder:GetAttribute("Ready") or now
	if state == "Countdown" then
		return ("Join the race! %d"):format(math.max(0, math.ceil((folder:GetAttribute("GoAt") or now) - now)))
	elseif state == "Racing" then
		return "Race in progress"
	elseif now < ready then
		return "Next race in " .. clock(ready - now)
	end
	return "Stand on the pad to race!"
end

-- The message for this player while on the pad: (big line, small line).
local function padText(folder: Instance): (string, string)
	local block = player:GetAttribute("RaceBlock")
	local state = folder:GetAttribute("State")
	local now = serverNow()
	local ready = folder:GetAttribute("Ready") or now
	local status
	if state == "Countdown" then
		status = signText(folder)
	elseif state == "Racing" then
		status = "Race in progress, wait for the next one"
	elseif now < ready then
		status = "Next race in " .. clock(ready - now)
	else
		status = "Join the race!"
	end
	if type(block) == "string" and block ~= "" then
		return block, status
	end
	return status, ("%d laps · every finisher wins a capsule"):format(RaceConfig.LAPS)
end

-- Billboard above the pad (this client only): the pad message while on the pad, otherwise the sign's status.
local billboard = Instance.new("BillboardGui")
billboard.Name = "RacePadBillboard"
billboard.Size = UDim2.fromScale(16, 4.2)
billboard.StudsOffset = Vector3.new(0, 6, 0)
billboard.MaxDistance = 140
billboard.LightInfluence = 0
billboard.ResetOnSpawn = false
billboard.Enabled = false
billboard.Parent = player:WaitForChild("PlayerGui")
local function boardLabel(name: string, y: number, h: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Text = ""
	l.Parent = billboard
	return l
end
local boardBig = boardLabel("Big", 0, 0.62, GOLD)
local boardSmall = boardLabel("Small", 0.64, 0.36, Color3.new(1, 1, 1))

task.spawn(function()
	local asked = false
	while true do
		local folder = course()
		if ReplicatedStorage:GetAttribute(RaceConfig.PUBLISHED) == true and folder then
			if not asked then
				asked = true
				actionEvent:FireServer("State")
			end
			local sign = folder:FindFirstChild("Sign")
			local text = signText(folder)
			if sign then
				for _, gui in sign:GetChildren() do
					local status = gui:IsA("SurfaceGui") and gui:FindFirstChild("Status")
					if status and status:IsA("TextLabel") then
						status.Text = text
					end
				end
			end
			local padPart = folder:FindFirstChild("StartPad")
			local onPad = nearPad() and player:GetAttribute("Racing") ~= true
			if onPad then
				local big, small = padText(folder)
				padBig.Text, padSmall.Text = big, small
				padBig.TextColor3 = if player:GetAttribute("RaceBlock") then C.Text else GOLD
				boardBig.Text, boardSmall.Text = big, small
			else
				boardBig.Text, boardSmall.Text = text, ("%d laps · every finisher wins a capsule"):format(RaceConfig.LAPS)
			end
			padPanel.Visible = onPad
			billboard.Adornee = if padPart and padPart:IsA("BasePart") then padPart else nil
			billboard.Enabled = billboard.Adornee ~= nil
			if panel.Visible or podium.Visible or padPanel.Visible then -- follow the shared top piece (it re-lays out after us)
				local top = UITheme.bannerTop()
				panel.Position = UDim2.fromOffset(root.AbsoluteSize.X / 2, top)
				podium.Position = UDim2.fromOffset(root.AbsoluteSize.X / 2, top)
				padPanel.Position = UDim2.fromOffset(root.AbsoluteSize.X / 2, top)
			end
			if panel.Visible then
				endsAt = folder:GetAttribute("EndsAt") or endsAt
				local left = endsAt - serverNow()
				timeLabel.Text = clock(left)
				timeLabel.TextColor3 = if left <= 10 then C.Danger else C.Text
			end
		else
			asked = false
			panel.Visible = false
			padPanel.Visible = false
			billboard.Enabled = false
			billboard.Adornee = nil
		end
		task.wait(0.2)
	end
end)
