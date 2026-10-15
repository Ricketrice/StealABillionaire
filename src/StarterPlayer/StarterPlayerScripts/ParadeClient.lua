-- Studio location: StarterPlayer.StarterPlayerScripts.ParadeClient (LocalScript)
-- ParadeClient  (Milestone 028, D7)
-- Draws the Worker Parade on this client. Display only: the server decides every catch.
--   * walkers: each parade worker's position is worked out from its attributes every frame (the
--     server copy never moves) and it bounces along with code-driven leg and arm swings (joint
--     Transforms, no animation assets). Limbs only move near the camera.
--   * the Catch prompt: shows "FREE!" for a player's first worker, and an odds panel above it.
--   * Golden Parade: walkers turn gold and sparkle; a countdown pill on screen and a banner under
--     the gantry over the lane (both through UITheme).
--   * "Too slow!" puff when someone else catches the worker you were next to; server-wide
--     Legendary/Secret banner; a bouncing FREE arrow over the nearest walker until the first catch.
-- Everything here only exists while ReplicatedStorage.ParadeOn is true.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))

local player = Players.LocalPlayer
local clientEvent = ReplicatedStorage:WaitForChild("ParadeEvent") :: RemoteEvent
local actionEvent = ReplicatedStorage:WaitForChild("ParadeAction") :: RemoteEvent
local T = UITheme.Colors
local TAU = math.pi * 2

local state = { free = false, freeCatches = 0, goldenCatches = 0, book = {} :: { string } }

local function paradeOn(): boolean
	return ReplicatedStorage:GetAttribute("ParadeOn") == true
end
local function now(): number
	return workspace:GetServerTimeNow()
end

-- Golden window from Workspace.Parade's attributes.
local paradeFolder: Folder? = nil
local walkersFolder: Folder? = nil
local function goldenTimes(): (number?, number?, number?)
	if not paradeFolder then
		return nil, nil, nil
	end
	return paradeFolder:GetAttribute("GoldenStart"), paradeFolder:GetAttribute("GoldenEnd"), paradeFolder:GetAttribute("NextGolden")
end
local function isGolden(t: number): boolean
	local s, e = goldenTimes()
	return s ~= nil and e ~= nil and t >= s and t < e
end

local function oddsFor(golden: boolean): { [string]: number }
	return if golden then ParadeConfig.GOLDEN_PER_MILLE else WorkerCatalogue.RARITY_PER_MILLE
end
local function percent(perMille: number): string
	local p = perMille / 10
	return if p == math.floor(p) then ("%d%%"):format(p) else ("%.1f%%"):format(p)
end

-- Screen UI (through UITheme) ---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Parade"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Golden Parade countdown pill (first item of the shared top bar).
local pill =
	UITheme.panel({ Name = "GoldenPill", LayoutOrder = 1, Size = UDim2.fromOffset(if UITheme.v1 then 170 else 150, if UITheme.v1 then 60 else 44), Parent = UITheme.topBar() })
pill.Visible = false
local pillIcon = if UITheme.v1
	then UITheme.image({ Icon = "hourglass", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 8), Parent = pill })
	else UITheme.icon({ Text = "🌟", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(8, 8), Parent = pill })
local pillText = UITheme.text({
	Name = "Text",
	Text = "",
	Role = "Body",
	Align = "Left",
	Position = UDim2.fromOffset(if UITheme.v1 then 54 else 40, 0),
	Size = UDim2.new(1, if UITheme.v1 then -58 else -46, 1, 0),
	Parent = pill,
})
pillIcon.Name = "Icon"

-- Announcement banner (top centre, below where the goal bar sits).
local banner = UITheme.panel({ Name = "Announce", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(460, 54), Parent = gui })
banner.Visible = false
UITheme.scaleWith(banner, 0.65, 1.05)
local bannerText =
	UITheme.text({ Name = "Text", Text = "", Role = "Body", TextWrapped = true, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Parent = banner })
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = bannerText
local bannerToken = 0
local function announce(text: string, color: Color3, sound: string)
	bannerToken += 1
	local token = bannerToken
	bannerText.Text = text
	bannerText.TextColor3 = color
	banner.Position = UDim2.new(0.5, 0, 0, UITheme.bannerTop()) -- (under the top piece)
	banner.Visible = true
	bannerScale.Scale = 0.5
	UITheme.tween(bannerScale, UITheme.Motion.Normal, { Scale = 1 }, Enum.EasingStyle.Back)
	FxKit.sound(sound)
	task.delay(4.5, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

-- Odds panel shown with a parade Catch prompt (a billboard above the worker).
local odds = Instance.new("BillboardGui")
odds.Name = "ParadeOdds"
odds.Size = UDim2.fromOffset(230, 64)
odds.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
odds.AlwaysOnTop = true
odds.LightInfluence = 0
odds.MaxDistance = 40
odds.Enabled = false
odds.ResetOnSpawn = false
odds.Parent = gui.Parent -- billboards render from PlayerGui, not inside a ScreenGui
local oddsPanel = UITheme.panel({ Name = "Panel", Size = UDim2.fromScale(1, 1), Parent = odds })
local oddsTitle = UITheme.text({ Name = "Title", Text = "ODDS", Role = "Small", Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 18), Parent = oddsPanel })
local oddsRow = Instance.new("Frame")
oddsRow.Name = "Row"
oddsRow.BackgroundTransparency = 1
oddsRow.Position = UDim2.fromOffset(6, 24)
oddsRow.Size = UDim2.new(1, -12, 0, 34)
oddsRow.Parent = oddsPanel
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 2)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = oddsRow
local oddsCells: { [string]: TextLabel } = {}
for i, rarity in WorkerCatalogue.RARITIES do
	local cell = UITheme.text({
		Name = rarity,
		Text = "",
		Role = "Small",
		TextSize = 12,
		Color = UITheme.Rarity[rarity],
		LayoutOrder = i,
		Size = UDim2.new(0.2, -2, 1, 0),
		TextWrapped = true,
		Parent = oddsRow,
	})
	oddsCells[rarity] = cell
end
local function fillOdds(golden: boolean)
	local o = oddsFor(golden)
	oddsTitle.Text = if golden then "🌟 GOLDEN ODDS" else "ODDS"
	oddsTitle.TextColor3 = if golden then T.Golden else T.Text
	oddsPanel.BackgroundColor3 = if golden then T.GoldenDeep else T.Panel
	for _, rarity in WorkerCatalogue.RARITIES do
		oddsCells[rarity].Text = UITheme.RarityGlyph[rarity] .. "\n" .. percent(o[rarity] or 0)
	end
end

-- Lane banner under the TopBoard gantry (built on this client only).
local laneSign: Model? = nil
local signLines: { TextLabel } = {}
local function buildSign()
	if laneSign then
		return
	end
	local walkers = walkersFolder
	local start = walkers and walkers:GetAttribute("LaneStart")
	local dir = walkers and walkers:GetAttribute("LaneDir")
	if typeof(start) ~= "Vector3" or typeof(dir) ~= "Vector3" then
		return
	end
	local gantry = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("SkyCity")
	gantry = gantry and gantry:FindFirstChild("Hub") and gantry.Hub:FindFirstChild("TopBoardGantry")
	local beam = gantry and gantry:FindFirstChild("Beam")
	-- Under the gantry if there is one, else 30 studs down the lane.
	local at = if beam and beam:IsA("BasePart") then Vector3.new(beam.Position.X, start.Y + 10.5, beam.Position.Z) else start + dir * 30 + Vector3.new(0, 10.5, 0)
	local model = Instance.new("Model")
	model.Name = "ParadeLaneSign"
	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored, board.CanCollide, board.CanTouch, board.CanQuery = true, false, false, false
	board.Size = Vector3.new(0.6, 3.6, 17)
	board.Color = T.Panel
	board.Material = Enum.Material.SmoothPlastic
	board.CFrame = CFrame.lookAt(at, at - dir) * CFrame.Angles(0, math.rad(90), 0)
	board.Parent = model
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(560, 120)
		sg.LightInfluence = 0
		sg.Parent = board
		UITheme.text({
			Name = "Title",
			Text = "🎁 CREATURE PARADE 🎁",
			Role = "Display",
			TextSize = 46,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 56),
			Color = T.Accent,
			Parent = sg,
		})
		table.insert(
			signLines,
			UITheme.text({ Name = "Line", Text = "", Role = "Title", TextSize = 34, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 50), Parent = sg })
		)
	end
	model.Parent = workspace
	laneSign = model
end
local function clearSign()
	if laneSign then
		laneSign:Destroy()
	end
	laneSign = nil
	table.clear(signLines)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- Walkers --------------------------------------------------------------------------------------------------
type Walker = {
	model: Model,
	root: BasePart,
	joints: { [string]: Instance },
	wraps: { [BasePart]: Color3 },
	shine: ParticleEmitter?,
	golden: boolean,
	phase: number,
}
local walkers: { [Model]: Walker } = {}
local JOINTS = { "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "Neck" }

local function setTransform(joint: Instance, cf: CFrame)
	(joint :: any).Transform = cf
end

-- Parts and joints can replicate a moment after the model itself, so both are (re)scanned.
local function scan(w: Walker)
	for _, d in w.model:GetDescendants() do
		if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and table.find(JOINTS, d.Name) then
			w.joints[d.Name] = d
		elseif d:IsA("BasePart") and d:GetAttribute("Wrap") and not w.wraps[d] then
			w.wraps[d] = d.Color
		end
	end
end

local function setGolden(w: Walker, golden: boolean)
	if w.golden == golden then
		return
	end
	w.golden = golden
	if golden then
		scan(w)
	end
	for part, original in w.wraps do
		part.Color = if golden then T.Golden else original
		part.Material = if golden then Enum.Material.Foil else Enum.Material.SmoothPlastic
	end
	if golden and not w.shine then
		w.shine = FxKit.attach(w.root, "shine", T.Golden)
	elseif not golden and w.shine then
		w.shine:Destroy()
		w.shine = nil
	end
end

local function track(model: Model)
	if walkers[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	model:WaitForChild("WorkerLook", 2)
	if not (root and root:IsA("BasePart") and model.Parent == walkersFolder) or walkers[model] then
		return
	end
	local w: Walker = { model = model, root = root, joints = {}, wraps = {}, golden = false, phase = math.random() * TAU }
	scan(w)
	walkers[model] = w
end

-- Stop drawing a walker (caught, left, or the parade stopped): its server copy takes over again.
local function untrack(model: Model)
	local w = walkers[model]
	if not w then
		return
	end
	walkers[model] = nil
	setGolden(w, false)
	for _, joint in w.joints do
		setTransform(joint, CFrame.identity)
	end
end

local function lanePosition(model: Model, t: number): (Vector3?, CFrame?)
	local f = walkersFolder
	if not f then
		return nil, nil
	end
	local start, dir, side = f:GetAttribute("LaneStart"), f:GetAttribute("LaneDir"), f:GetAttribute("LaneSide")
	local length, lift = f:GetAttribute("LaneLength"), f:GetAttribute("RootLift")
	if typeof(start) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(side) ~= "Vector3" then
		return nil, nil
	end
	local age = t - (model:GetAttribute("SpawnT") or t)
	local distance = math.clamp(age * (model:GetAttribute("Speed") or ParadeConfig.WALK_SPEED), 0, length or 0)
	local pos = start + dir * distance + side * (model:GetAttribute("Offset") or 0) + Vector3.new(0, lift or 3, 0)
	return pos, CFrame.lookAt(pos, pos + dir)
end

local function step()
	local t = now()
	local golden = isGolden(t)
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local range = ParadeConfig.ANIMATE_RANGE
	for model, w in walkers do
		if model.Parent ~= walkersFolder then
			untrack(model)
			continue
		end
		local pos, facing = lanePosition(model, t)
		if not (pos and facing) then
			continue
		end
		setGolden(w, golden)
		local age = t - (model:GetAttribute("SpawnT") or t)
		local gait = age * ParadeConfig.STEP_RATE * math.pi + w.phase -- one gait cycle = two bounces
		local s = math.sin(gait)
		local bounce = math.abs(s) * ParadeConfig.BOUNCE_HEIGHT
		w.root.CFrame = facing * CFrame.new(0, bounce, 0) * CFrame.Angles(0, 0, s * 0.1)
		if (pos - camPos).Magnitude < range then
			local j = w.joints
			if j.LeftHip then
				setTransform(j.LeftHip, CFrame.Angles(s * 0.65, 0, 0))
			end
			if j.RightHip then
				setTransform(j.RightHip, CFrame.Angles(-s * 0.65, 0, 0))
			end
			if j.LeftKnee then
				setTransform(j.LeftKnee, CFrame.Angles(-math.max(0, -s) * 0.8, 0, 0))
			end
			if j.RightKnee then
				setTransform(j.RightKnee, CFrame.Angles(-math.max(0, s) * 0.8, 0, 0))
			end
			-- Arms up and waving a little: excited mystery guests.
			if j.LeftShoulder then
				setTransform(j.LeftShoulder, CFrame.Angles(-s * 0.5, 0, -0.35 - math.abs(s) * 0.2))
			end
			if j.RightShoulder then
				setTransform(j.RightShoulder, CFrame.Angles(s * 0.5, 0, 0.35 + math.abs(s) * 0.2))
			end
			if j.Neck then
				setTransform(j.Neck, CFrame.Angles(0, math.sin(gait * 0.5) * 0.25, 0))
			end
		end
	end
end

-- Free-catch arrow: over the walker nearest to this player while their first catch is free.
local arrow = Instance.new("BillboardGui")
arrow.Name = "FreeArrow"
arrow.Size = UDim2.fromOffset(120, 90)
arrow.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
arrow.AlwaysOnTop = true
arrow.LightInfluence = 0
arrow.Enabled = false
arrow.ResetOnSpawn = false
arrow.Parent = gui.Parent -- billboards render from PlayerGui, not inside a ScreenGui
UITheme.text({ Name = "Free", Text = "FREE!", Role = "Display", TextSize = 30, Color = T.Cash, Size = UDim2.new(1, 0, 0, 36), Parent = arrow })
UITheme.text({ Name = "Arrow", Text = "▼", Role = "Display", TextSize = 44, Color = T.Cash, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 50), Parent = arrow })

local function nearestWalker(): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for model, w in walkers do
		local d = (w.root.Position - root.Position).Magnitude
		if d < bestDistance then
			best, bestDistance = model, d
		end
	end
	return best
end

-- Prompts -------------------------------------------------------------------------------------------------
-- The same order the server uses: first catch, then (outside a Golden Parade) a Golden ticket, then a
-- free catch, then cash.
local function usesTicket(golden: boolean): boolean
	return not state.free and state.goldenCatches > 0 and not (golden and state.freeCatches > 0)
end
local function priceText(golden: boolean): string
	if state.free or state.freeCatches > 0 and not usesTicket(golden) then
		return "Catch FREE!"
	elseif usesTicket(golden) then
		return "Catch: Golden ticket!"
	end
	return "Catch " .. CashFormat.format(if golden then ParadeConfig.GOLDEN_PRICE else ParadeConfig.CATCH_PRICE)
end

local shownPrompt: ProximityPrompt? = nil
ProximityPromptService.PromptShown:Connect(function(prompt)
	if not prompt:GetAttribute("Parade") then
		return
	end
	local golden = isGolden(now())
	prompt.ActionText = priceText(golden)
	prompt.ObjectText = if golden then "Golden Mystery Creature" else "Mystery Creature"
	shownPrompt = prompt
	fillOdds(golden or usesTicket(golden))
	odds.Adornee = prompt.Parent
	odds.Enabled = true
end)
-- The server checks the catch itself (where the walker really is now, cash, cooldown, who was first).
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local walker = prompt:GetAttribute("Parade") and prompt.Parent and prompt.Parent.Parent
	if walker and walker.Parent == walkersFolder then
		actionEvent:FireServer("Catch", walker)
	end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt == shownPrompt then
		shownPrompt = nil
		odds.Enabled = false
		odds.Adornee = nil
	end
end)

-- Server events ---------------------------------------------------------------------------------------------
local lastGolden: boolean? = nil
clientEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then
		return
	end
	if kind == "State" then
		state.free = info.free == true
		state.freeCatches = if type(info.freeCatches) == "number" then info.freeCatches else 0
		state.goldenCatches = if type(info.goldenCatches) == "number" then info.goldenCatches else 0
		gui:SetAttribute("FreeCatches", state.freeCatches)
		gui:SetAttribute("GoldenCatches", state.goldenCatches)
		state.book = if type(info.book) == "table" then info.book else {}
		gui:SetAttribute("Free", state.free)
	elseif kind == "Caught" and typeof(info.pos) == "Vector3" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = root and (root.Position - info.pos).Magnitude
		if near and near < 100 then
			FxKit.burst(info.pos, "puff", nil, 14)
			FxKit.burst(info.pos, "sparkle", if info.golden then T.Golden else Color3.fromRGB(255, 120, 200), 16)
		end
		if info.by ~= player.UserId and near and near < 22 then
			FxKit.text(info.pos, "Too slow!", T.Danger, 3)
			FxKit.sound("poof")
		end
	elseif kind == "Announce" then
		local rarity = tostring(info.rarity)
		local color = UITheme.Rarity[rarity] or T.Accent
		if info.userId == player.UserId then
			return -- your own catch gets the reveal card and banner instead
		end
		local who = tostring(info.player)
		announce(
			("%s %s caught %s %s!"):format(UITheme.RarityGlyph[rarity] or "★", who, string.upper(rarity), tostring(info.worker)),
			color,
			if rarity == "Secret" then "secret" else "legendary"
		)
	elseif kind == "Golden" then
		if info.on and lastGolden ~= true then
			announce("🌟 GOLDEN PARADE! Better odds for everyone for 60 seconds!", T.Golden, "golden")
		elseif not info.on and lastGolden == true then
			for _, w in walkers do
				FxKit.burst(w.root, "sparkle", T.Golden, 10)
			end
		end
		lastGolden = info.on == true
	end
end)

-- Folder watching -------------------------------------------------------------------------------------------
local connections: { RBXScriptConnection } = {}
local renderBound = false
local function stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for model in walkers do
		untrack(model)
	end
	if renderBound then
		RunService:UnbindFromRenderStep("ParadeWalkers")
		renderBound = false
	end
	clearSign()
	gui.Enabled = false
	pill.Visible = false
	odds.Enabled, arrow.Enabled = false, false
	paradeFolder, walkersFolder = nil, nil
end

local function startWith(folder: Folder)
	if paradeFolder == folder then
		return
	end
	stop()
	paradeFolder = folder
	local w = folder:WaitForChild("Walkers", 10)
	if not (w and w:IsA("Folder") and paradeFolder == folder) then
		return
	end
	walkersFolder = w
	for _, child in w:GetChildren() do
		task.spawn(track, child)
	end
	table.insert(
		connections,
		w.ChildAdded:Connect(function(child)
			track(child :: Model)
		end)
	)
	table.insert(
		connections,
		w.ChildRemoved:Connect(function(child)
			untrack(child :: Model)
		end)
	)
	RunService:BindToRenderStep("ParadeWalkers", Enum.RenderPriority.Last.Value, step)
	renderBound = true
	buildSign()
	gui.Enabled = true
	actionEvent:FireServer("State")
end

local function refresh()
	local folder = workspace:FindFirstChild("Parade")
	if paradeOn() and folder and folder:IsA("Folder") then
		task.spawn(startWith, folder)
	elseif paradeFolder then
		stop()
	end
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Parade" then
		refresh()
	end
end)
workspace.ChildRemoved:Connect(function(child)
	if child == paradeFolder then
		stop()
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("ParadeOn"):Connect(refresh)
refresh()

-- Slow loop: countdown pill, lane sign, free arrow ----------------------------------------------------------
while true do
	if paradeFolder then
		local t = now()
		local s, e, nextAt = goldenTimes()
		local golden = s ~= nil and e ~= nil and t >= s and t < e
		local line
		if golden then
			line = ("GOLDEN PARADE!  %s left"):format(clock((e :: number) - t))
			pillText.Text = "GOLDEN! " .. clock((e :: number) - t)
			pillText.TextColor3 = T.Golden
			pill.BackgroundColor3 = T.GoldenDeep
		else
			line = if nextAt then ("Golden Parade in %s"):format(clock(nextAt - t)) else "Golden Parade soon"
			pillText.Text = if nextAt then "Golden " .. clock(nextAt - t) else "Golden soon"
			pillText.TextColor3 = T.Text
			pill.BackgroundColor3 = T.Panel
		end
		pill.Visible = nextAt ~= nil or golden
		local o = oddsFor(golden)
		local oddsLine = ("%s  ·  ★ %s  🌈 %s"):format(if golden then "🌟 " .. line else line, percent(o.Legendary), percent(o.Secret))
		for _, label in signLines do
			label.Text = oddsLine
			label.TextColor3 = if golden then T.Golden else T.Text
		end
		if shownPrompt then
			shownPrompt.ActionText = priceText(golden)
			fillOdds(golden or usesTicket(golden))
		end
		local target = if state.free then nearestWalker() else nil
		arrow.Adornee = if target then target:FindFirstChild("HumanoidRootPart") :: any else nil
		arrow.Enabled = target ~= nil
		gui:SetAttribute(
			"Walkers",
			(function()
				local n = 0
				for _ in walkers do
					n += 1
				end
				return n
			end)()
		)
	end
	task.wait(0.25)
end
