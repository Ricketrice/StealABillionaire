-- Studio location: ServerScriptService.CreatureShowcase (Script)
-- CreatureShowcase  (Milestone 031, D26 prototypes, showcase only): a Studio-only stand in Velocity Royale with the
-- three creature prototypes from ServerStorage.Prototypes.Creatures (Slime Rookie, Dragon Pup, Mech Beast).
-- Off by default and never on in a live server: only in Studio with ServerStorage attribute StudioCreatures = true.
-- The creatures are NOT in any catch pool, capsule, parade or index (adding them needs its own decision, D26).
--
-- Each copy is rigged like a worker could be carried later: one root part (the *_Body MeshPart, PrimaryPart),
-- every other piece welded to it with a Weld (C0 = its offset), nothing collides. The client
-- (CreatureShowcaseClient) plays the code-driven idles by moving the root and turning a few welds.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local ATTRIBUTE = "StudioCreatures"
local ORDER = { "SlimeRookie", "DragonPup", "MechBeast" }
local LOOK = { SlimeRookie = "Common", DragonPup = "Epic", MechBeast = "Legendary" } -- rarity look only
local RARITY_COLOR = { Common = Color3.fromRGB(196, 200, 208), Epic = Color3.fromRGB(176, 92, 255), Legendary = Color3.fromRGB(255, 196, 40) }
-- The stand: a row of plinths on the plaza in front of the podium, facing the plaza (+Z).
local STAND = CFrame.new(-159.2, 72.3, -912) -- centre of the row, on the ground
local SPACING = 9

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- A rigged copy: root = the body, everything else welded to it, nothing anchored but the root.
local function rig(source: Model): Model?
	local name = source.Name
	local model = source:Clone()
	local body = model:FindFirstChild(name .. "_Body")
	if not (body and body:IsA("BasePart")) then
		warn("[CreatureShowcase] " .. name .. " has no " .. name .. "_Body")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = body
	for _, c in model:GetDescendants() do
		if c:IsA("WeldConstraint") or c:IsA("JointInstance") then
			c:Destroy() -- the import's WeldConstraints: replaced by Welds the idles can turn
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.Massless = p ~= body
			p.Anchored = p == body
			if p ~= body then
				local weld = Instance.new("Weld")
				weld.Name = "Joint"
				weld.Part0, weld.Part1 = body, p
				weld.C0 = body.CFrame:ToObjectSpace(p.CFrame)
				weld.Parent = p
			end
		end
	end
	model:SetAttribute("Creature", name)
	model:SetAttribute("LooksLike", LOOK[name])
	return model
end

local folder: Folder? = nil
local function build()
	local source = ServerStorage:FindFirstChild("Prototypes") and ServerStorage.Prototypes:FindFirstChild("Creatures")
	local royale = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("VelocityRoyale")
	if not (source and royale) then
		warn("[CreatureShowcase] ServerStorage.Prototypes.Creatures or World.VelocityRoyale missing")
		return
	end
	local f = Instance.new("Folder")
	f.Name = "CreatureShowcase"
	for i, name in ORDER do
		local src = source:FindFirstChild(name)
		local model = src and src:IsA("Model") and rig(src)
		if model then
			local spot = STAND * CFrame.new((i - 2) * SPACING, 0, 0)
			local rarity = LOOK[name]
			local plinth = part({
				Name = name .. "_Plinth",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.6, 6.5, 6.5),
				CFrame = spot * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(40, 52, 92),
			})
			plinth.Parent = f
			local ring = part({
				Name = name .. "_Ring",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 6.9, 6.9),
				CFrame = spot * CFrame.new(0, 1.65, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = RARITY_COLOR[rarity],
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			ring.Parent = f
			-- The imports lie pitched -90 deg; the body's own axes are right (up +Y, face -Z): stand the body
			-- upright facing the plaza (+Z), then lift so the lowest piece sits on the plinth.
			local body = model.PrimaryPart :: BasePart
			model:PivotTo(CFrame.new(spot.Position) * CFrame.Angles(0, math.pi, 0) * body.PivotOffset)
			local low = math.huge
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					local h = p.Size / 2
					for _, corner in
						{
							Vector3.new(h.X, h.Y, h.Z),
							Vector3.new(-h.X, -h.Y, -h.Z),
							Vector3.new(h.X, -h.Y, h.Z),
							Vector3.new(-h.X, -h.Y, h.Z),
							Vector3.new(h.X, -h.Y, -h.Z),
							Vector3.new(-h.X, h.Y, -h.Z),
						}
					do
						low = math.min(low, (p.CFrame * corner).Y)
					end
				end
			end
			model:PivotTo(model:GetPivot() + Vector3.new(0, spot.Y + 1.6 + 0.05 - low, 0))
			local _, size = model:GetBoundingBox()
			model.Parent = f
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromScale(8, 1.4)
			tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.6, 0)
			tag.Adornee = model.PrimaryPart
			tag.LightInfluence = 0
			tag.MaxDistance = 80
			tag.Parent = model
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = RARITY_COLOR[rarity]
			label.TextStrokeTransparency = 0.2
			label.Text = ("%s  (%s look)"):format((name:gsub("(%l)(%u)", "%1 %2")), rarity)
			label.Parent = tag
		end
	end
	local sign =
		part({ Name = "ShowcaseSign", Size = Vector3.new(14, 2.4, 0.4), CFrame = STAND * CFrame.new(0, 7.2, -4.2), Color = Color3.fromRGB(40, 52, 92), CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 214, 92)
	text.Text = "CREATURE PROTOTYPES (Studio only)"
	text.Parent = gui
	sign.Parent = f
	f.Parent = royale
	folder = f
end

local function apply()
	local on = ServerStorage:GetAttribute(ATTRIBUTE) == true
	if on and not folder then
		build()
	elseif not on and folder then
		folder:Destroy()
		folder = nil
	end
end
ServerStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(apply)
apply()
