-- Studio location: StarterPlayer.StarterPlayerScripts.BaseClient (LocalScript)
-- BaseClient  (Milestone 033, D25/D28): this client's side of worker levels and base pads. Display only: the server
-- (BaseService) checks and charges everything.
--   * "Level up $X" prompt: only the nearest occupied pad of YOUR base, only while you aren't carrying (all pad
--     prompts share the E key, like PlotPrompts); the server marks which pads may show one (attribute Want)
--   * the glowing "Unlock $X" pad: its prompt only for its owner
--   * one-time NEW! hints (BaseEvent "Intro"): levels, pads
--   * a shield over every player's protected favourite (033 fair stealing, attribute FavShield)
--   * level badges over working workers: a star from Level 5, a gold glow at Level 10 (BillboardGui MaxDistance
--     keeps them near the camera); a burst + "LEVEL N!" when one of yours levels up

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage:WaitForChild("BaseConfig"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
local T = UITheme.Colors
local GOLD = Color3.fromRGB(255, 200, 60)
local UPDATE_INTERVAL = 0.15
local LEVEL_REACH = 10 -- studs: the level prompt of the nearest occupied pad within this

-- Prompts ---------------------------------------------------------------------------------------------------------------
local levelPrompts: { ProximityPrompt } = {}
local unlockPrompts: { ProximityPrompt } = {}
local function track(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	if instance.Name == "LevelPrompt" then
		table.insert(levelPrompts, instance)
	elseif instance.Name == "UnlockPrompt" then
		table.insert(unlockPrompts, instance)
	end
end
for _, d in plots:GetDescendants() do
	track(d)
end
plots.DescendantAdded:Connect(track)

local function ownPlot(): Instance?
	local plotId = player:GetAttribute("PlotId")
	return plotId and plots:FindFirstChild("Plot" .. plotId)
end

local function carrying(): boolean
	return player:GetAttribute("CarryingNPC") == true or player:GetAttribute("CarryingStolen") == true or player:GetAttribute("HeistCarrying") == true
end

local function updatePrompts()
	local plot = ownPlot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target: ProximityPrompt? = nil
	if plot and root and not carrying() then
		local best = LEVEL_REACH
		for _, prompt in levelPrompts do
			local pad = prompt.Parent
			if prompt:GetAttribute("Want") == true and pad and pad:IsA("BasePart") and pad:IsDescendantOf(plot) then
				local distance = (pad.Position - root.Position).Magnitude
				if distance < best then
					best, target = distance, prompt
				end
			end
		end
	end
	for i = #levelPrompts, 1, -1 do
		local prompt = levelPrompts[i]
		if not prompt.Parent then
			table.remove(levelPrompts, i)
		elseif prompt.Enabled ~= (prompt == target) then
			prompt.Enabled = prompt == target
		end
	end
	for i = #unlockPrompts, 1, -1 do
		local prompt = unlockPrompts[i]
		local pad = prompt.Parent
		if not pad then
			table.remove(unlockPrompts, i)
		else
			local want = pad:GetAttribute("OwnerUserId") == player.UserId and not carrying()
			if prompt.Enabled ~= want then
				prompt.Enabled = want
			end
		end
	end
end

-- NEW! hints (D28) ----------------------------------------------------------------------------------------------------
local _, root = UITheme.gui("Base033", 6)
local hint = UITheme.panel({
	Name = "NewHint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(460, 92),
	Visible = false,
	Parent = root,
})
UITheme.scaleWith(hint)
local hintIcon = UITheme.image({ Icon = "plus", Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 14), Parent = hint })
UITheme.text({
	Name = "New",
	Text = "NEW!",
	Role = "Title",
	TextSize = 22,
	Color = T.Cash or GOLD,
	Align = "Left",
	Position = UDim2.fromOffset(88, 8),
	Size = UDim2.new(1, -100, 0, 26),
	Parent = hint,
})
local hintText = UITheme.text({
	Name = "Text",
	Text = "",
	Role = "Body",
	TextSize = 17,
	Align = "Left",
	TextWrapped = true,
	Position = UDim2.fromOffset(88, 34),
	Size = UDim2.new(1, -100, 0, 50),
	Parent = hint,
})
hintText.TextYAlignment = Enum.TextYAlignment.Top
local hintButton = Instance.new("TextButton")
hintButton.BackgroundTransparency = 1
hintButton.Text = ""
hintButton.Size = UDim2.fromScale(1, 1)
hintButton.Parent = hint
local hintToken = 0
hintButton.Activated:Connect(function()
	hint.Visible = false
end)

local HINTS = {
	levels = { icon = "plus", text = "Level up your creatures! Stand by a creature on your base, or tap one in Creatures." },
	pads = { icon = "base", text = "Your pads are full. Unlock a new pad on the glowing spot at your base!" },
}
local function showHint(what: string)
	local def = HINTS[what]
	if not def then
		return
	end
	hintToken += 1
	local token = hintToken
	local icon = UITheme.image({ Icon = def.icon, Size = hintIcon.Size, Position = hintIcon.Position, Parent = hint })
	hintIcon:Destroy()
	hintIcon = icon
	hintText.Text = def.text
	hint.Visible = true
	FxKit.sound("place")
	task.delay(8, function()
		if hintToken == token then
			hint.Visible = false
		end
	end)
end

-- Level badges and glow ---------------------------------------------------------------------------------------------
type Badge = {
	gui: BillboardGui?,
	shield: BillboardGui?,
	light: PointLight?,
	ring: BasePart?,
	ringColor: Color3?,
	ringMaterial: Enum.Material?,
	conn: RBXScriptConnection,
	shieldConn: RBXScriptConnection,
}
local badges: { [Model]: Badge } = {}

local function ringOf(model: Model): BasePart?
	local plot = model.Parent and model.Parent.Parent
	local stations = plot and plot:FindFirstChild("Stations")
	local index = model:GetAttribute("StationIndex")
	for _, pad in (if stations then stations:GetChildren() else {}) do
		if pad:GetAttribute("StationIndex") == index then
			local ring = pad:FindFirstChild("Ring")
			return if ring and ring:IsA("BasePart") then ring else nil
		end
	end
	return nil
end

local function paintBadge(model: Model)
	local b = badges[model]
	if not b then
		return
	end
	local level = model:GetAttribute("Level")
	level = if type(level) == "number" then level else 1
	local on = BaseConfig.on("LEVELS_ENABLED")
	-- star badge from Level 5
	if on and level >= BaseConfig.LEVEL_BADGE then
		local head = model:FindFirstChild("Head")
		if not b.gui and head and head:IsA("BasePart") then
			local g = Instance.new("BillboardGui")
			g.Name = "LevelBadge"
			g.Size = UDim2.fromOffset(64, 30)
			g.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
			g.MaxDistance = BaseConfig.Living.RANGE
			g.LightInfluence = 0
			g.Adornee = head
			UITheme.image({ Icon = "star", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(2, 1), Parent = g })
			UITheme.text({
				Name = "Level",
				Text = "",
				Role = "Title",
				TextSize = 22,
				Color = GOLD,
				Align = "Left",
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.fromOffset(32, 30),
				Parent = g,
			})
			g.Parent = model
			b.gui = g
		end
		local label = b.gui and b.gui:FindFirstChild("Level") :: TextLabel?
		if label then
			label.Text = tostring(level)
		end
	elseif b.gui then
		b.gui:Destroy()
		b.gui = nil
	end
	-- gold glow at Level 10: a warm light on the worker and a gold ring on its pad
	if on and level >= BaseConfig.LEVEL_GLOW then
		local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
		if not b.light and torso then
			local light = Instance.new("PointLight")
			light.Name = "LevelGlow"
			light.Color = GOLD
			light.Brightness = 2
			light.Range = 9
			light.Parent = torso
			b.light = light
		end
		if not b.ring then
			local ring = ringOf(model)
			if ring then
				b.ring, b.ringColor, b.ringMaterial = ring, ring.Color, ring.Material
				ring.Color, ring.Material = GOLD, Enum.Material.Neon
			end
		end
	else
		if b.light then
			b.light:Destroy()
			b.light = nil
		end
		if b.ring then
			b.ring.Color, b.ring.Material = b.ringColor :: Color3, b.ringMaterial :: Enum.Material
			b.ring = nil
		end
	end
end

-- (033 fair stealing) a shield over its owner's favourite: it can't be stolen. Seen by everyone.
local function paintShield(model: Model)
	local b = badges[model]
	if not b then
		return
	end
	local want = model:GetAttribute("FavShield") == true
	if want and not b.shield then
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local g = Instance.new("BillboardGui")
			g.Name = "FavShield"
			g.Size = UDim2.fromOffset(36, 36)
			g.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
			g.MaxDistance = BaseConfig.Living.RANGE
			g.LightInfluence = 0
			g.Adornee = head
			UITheme.image({ Icon = "shield", Size = UDim2.fromScale(1, 1), Parent = g })
			g.Parent = model
			b.shield = g
		end
	elseif not want and b.shield then
		b.shield:Destroy()
		b.shield = nil
	end
end

local function unwatch(model: Model)
	local b = badges[model]
	if not b then
		return
	end
	badges[model] = nil
	b.conn:Disconnect()
	b.shieldConn:Disconnect()
	if b.gui then
		b.gui:Destroy()
	end
	if b.shield then
		b.shield:Destroy()
	end
	if b.light then
		b.light:Destroy()
	end
	if b.ring and b.ring.Parent then
		b.ring.Color, b.ring.Material = b.ringColor :: Color3, b.ringMaterial :: Enum.Material
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or badges[model] then
		return
	end
	badges[model] = {
		conn = model:GetAttributeChangedSignal("Level"):Connect(function()
			paintBadge(model)
		end),
		shieldConn = model:GetAttributeChangedSignal("FavShield"):Connect(function()
			paintShield(model)
		end),
	}
	paintBadge(model)
	paintShield(model)
end

local function watchPlot(plot: Instance)
	local placed = plot:WaitForChild("PlacedNPCs", 30)
	if not placed then
		return
	end
	placed.ChildAdded:Connect(function(child)
		task.wait(0.2) -- its head and attributes replicate a moment later
		if child.Parent == placed then
			watch(child)
		end
	end)
	placed.ChildRemoved:Connect(function(child)
		unwatch(child :: Model)
	end)
	for _, child in placed:GetChildren() do
		watch(child)
	end
end
for _, plot in plots:GetChildren() do
	task.spawn(watchPlot, plot)
end
plots.ChildAdded:Connect(watchPlot)
ReplicatedStorage:GetAttributeChangedSignal("LevelsOn"):Connect(function()
	for model in badges do
		paintBadge(model)
	end
end)

-- Server events -------------------------------------------------------------------------------------------------------
local event = ReplicatedStorage:WaitForChild("BaseEvent", 60) :: RemoteEvent?
if event then
	event.OnClientEvent:Connect(function(kind, info)
		if kind == "Intro" and type(info) == "string" then
			showHint(info)
		elseif kind == "Levelled" and type(info) == "table" then
			local plot = ownPlot()
			local placed = plot and plot:FindFirstChild("PlacedNPCs")
			for _, model in (if placed then placed:GetChildren() else {}) do
				if model:GetAttribute("WorkerUid") == info.uid and model:IsA("Model") then
					local head = model:FindFirstChild("Head")
					FxKit.burst(model:GetPivot().Position, "sparkle", GOLD, 22)
					if head then
						FxKit.text(head, ("LEVEL %d!"):format(tonumber(info.level) or 0), GOLD, 3)
					end
				end
			end
			FxKit.sound("coin")
		elseif kind == "PadUnlocked" then
			FxKit.sound("place")
			local character = player.Character
			local r = character and character:FindFirstChild("HumanoidRootPart")
			if r then
				FxKit.burst((r :: BasePart).Position, "sparkle", GOLD, 26)
				FxKit.coins((r :: BasePart).Position, 10)
			end
		end
	end)
end

while true do
	updatePrompts()
	task.wait(UPDATE_INTERVAL)
end
