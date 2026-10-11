-- Studio location: StarterPlayer.StarterPlayerScripts.SkyCityLife (LocalScript)
-- SkyCityLife  (Milestone 027): this client's view of the sky city. Display only; nothing is sent.
--   * YOUR BASE: a soft gold light pillar and label over this player's own lot, and a gold beam from
--     the player to it for the first BEAM_SECONDS after each spawn and whenever they carry a worker.
--     Both hide once the player is standing on their lot.
--   * Ambient particles on parts tagged by the map: "Fx027Sparkle" (the Vault), "Fx027Coins" (spawn
--     medallion), "Fx027Leaves" (a few trees). Few emitters, low rates, only within FX_RANGE studs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 206, 84)
local BEAM_SECONDS = 45
local ON_LOT = 20 -- studs from the lot's centre that count as "on your lot"
local FX_RANGE = 140
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

-- YOUR BASE marker ---------------------------------------------------------------------------------
local marker: Model? = nil
local beam: Beam? = nil
local spawnedAt = os.clock()

local function plotModel(): Model?
	local id = player:GetAttribute("PlotId")
	local hub = workspace:FindFirstChild("Hub")
	local plots = hub and hub:FindFirstChild("Plots")
	local plot = plots and id and plots:FindFirstChild("Plot" .. tostring(id))
	return if plot and plot:IsA("Model") and plot.PrimaryPart then plot else nil
end

local function buildMarker(plot: Model)
	if marker then
		marker:Destroy()
	end
	local floor = plot.PrimaryPart :: BasePart
	local m = Instance.new("Model")
	m.Name = "YourBaseMarker"
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(70, 3, 3)
	pillar.CFrame = CFrame.new(floor.Position + Vector3.new(0, 35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
	pillar.Material = Enum.Material.Neon
	pillar.Color = GOLD
	pillar.Transparency = 0.72
	pillar.Parent = m
	local target = Instance.new("Attachment")
	target.Name = "BeamTarget"
	target.Parent = pillar
	target.WorldPosition = (floor.CFrame * CFrame.new(0, 2, -16)).Position -- just inside the gate
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(170, 46)
	label.StudsOffsetWorldSpace = Vector3.new(0, 38, 0)
	label.AlwaysOnTop = true
	label.LightInfluence = 0
	label.MaxDistance = 600
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(40, 52, 92)
	text.BackgroundTransparency = 0.1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "YOUR BASE"
	text.TextColor3 = GOLD
	Instance.new("UICorner").Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode = GOLD, 2, Enum.ApplyStrokeMode.Border
	stroke.Parent = text
	text.Parent = label
	label.Adornee = pillar
	label.Parent = pillar
	m.Parent = workspace
	marker = m
end

local function attachBeam(character: Model)
	if beam then
		beam:Destroy()
		beam = nil
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (root and marker) then
		return
	end
	local pillar = (marker :: Model):FindFirstChild("Pillar")
	local target = pillar and pillar:FindFirstChild("BeamTarget")
	if not (target and target:IsA("Attachment")) then
		return
	end
	local old = root:FindFirstChild("YourBaseFrom")
	if old then
		old:Destroy() -- called again for the same character (e.g. the plot was assigned late)
	end
	local start = Instance.new("Attachment")
	start.Name = "YourBaseFrom"
	start.Position = Vector3.new(0, -1.5, 0)
	start.Parent = root
	local b = Instance.new("Beam")
	b.Attachment0 = start
	b.Attachment1 = target
	b.FaceCamera = true
	b.Width0, b.Width1 = 0.5, 1.2
	b.Color = ColorSequence.new(GOLD)
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0.1) })
	b.LightEmission = 1
	b.Segments = 1
	b.Parent = root
	beam = b
	spawnedAt = os.clock()
end

player.CharacterAdded:Connect(attachBeam)
player:GetAttributeChangedSignal("PlotId"):Connect(function()
	local plot = plotModel()
	if plot then
		buildMarker(plot)
		if player.Character then
			task.spawn(attachBeam, player.Character)
		end
	end
end)

-- Ambient particles --------------------------------------------------------------------------------
local emitters: { [ParticleEmitter]: BasePart } = {}

local function emitterFor(part: Instance, kind: string)
	if not part:IsA("BasePart") or part:FindFirstChild("Fx027") then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fx027"
	e.Texture = SPARKLES
	e.LightEmission = 1
	e.Enabled = false
	if kind == "Fx027Leaves" then
		e.Color = ColorSequence.new(Color3.fromRGB(150, 214, 90), Color3.fromRGB(240, 210, 90))
		e.Size = NumberSequence.new(0.35)
		e.Rate, e.Lifetime, e.Speed = 1.2, NumberRange.new(3, 5), NumberRange.new(0.5, 1)
		e.Acceleration = Vector3.new(0.6, -1.4, 0)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LightEmission = 0.3
	elseif kind == "Fx027Coins" then
		e.Color = ColorSequence.new(GOLD)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Rate, e.Lifetime, e.Speed = 4, NumberRange.new(1, 1.6), NumberRange.new(2, 3)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
	else
		e.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 250, 220))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Rate, e.Lifetime, e.Speed = 5, NumberRange.new(1.2, 2), NumberRange.new(0.6, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
	end
	e.Parent = part
	emitters[e] = part
end

for _, kind in { "Fx027Sparkle", "Fx027Coins", "Fx027Leaves" } do
	for _, part in CollectionService:GetTagged(kind) do
		emitterFor(part, kind)
	end
	CollectionService:GetInstanceAddedSignal(kind):Connect(function(part)
		emitterFor(part, kind)
	end)
end

-- One slow loop for everything: distance culling and the YOUR BASE beam.
while true do
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for e, part in emitters do
		if not e.Parent then
			emitters[e] = nil
		elseif eye then
			e.Enabled = (part.Position - eye).Magnitude < FX_RANGE
		end
	end
	if marker == nil and player:GetAttribute("PlotId") then
		local plot = plotModel()
		if plot then
			buildMarker(plot)
			if player.Character then
				task.spawn(attachBeam, player.Character)
			end
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = plotModel()
	if marker and root and plot then
		local away = ((root.Position - plot.PrimaryPart.Position) * Vector3.new(1, 0, 1)).Magnitude > ON_LOT
		local pillar = (marker :: Model):FindFirstChild("Pillar") :: BasePart?
		if pillar then
			pillar.Transparency = if away then 0.72 else 1
			local label = pillar:FindFirstChild("Label") :: BillboardGui?
			if label then
				label.Enabled = away
			end
		end
		if beam then
			local recent = os.clock() - spawnedAt < BEAM_SECONDS
			beam.Enabled = away and (recent or player:GetAttribute("CarryingNPC") == true)
		end
	end
	task.wait(0.4)
end
