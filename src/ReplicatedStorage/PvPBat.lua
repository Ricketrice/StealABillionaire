-- Studio location: ReplicatedStorage.PvPBat (ModuleScript)
-- PvPBat  (Milestone 022)
-- Builds the bat models from plain parts: an original design, no imported assets. The three skins
-- differ only in colour and material; nothing about how a bat plays depends on its skin.
--   PvPBat.build(skin) -> Model with PrimaryPart "Grip" (the bat points along the Grip's +Y)

local PvPBat = {}

local rgb = Color3.fromRGB
PvPBat.SKINS = {
	Starter = { name = "Starter Bat", body = rgb(184, 132, 78), dark = rgb(122, 82, 46), tape = rgb(62, 66, 82), material = Enum.Material.Wood, trail = rgb(240, 232, 214) },
	Neon = { name = "Neon Bat", body = rgb(26, 28, 42), dark = rgb(16, 18, 28), tape = rgb(64, 226, 255), band = rgb(255, 84, 196), material = Enum.Material.SmoothPlastic, trail = rgb(64, 226, 255) },
	Golden = { name = "Golden Bat", body = rgb(236, 190, 84), dark = rgb(178, 132, 44), tape = rgb(250, 240, 214), band = rgb(255, 232, 150), material = Enum.Material.Metal, reflectance = 0.25, trail = rgb(255, 214, 110) },
}

local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, y: number, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Color, p.Material = name, shape, size, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.Anchored = false, false, false, true, false
	-- Roblox cylinders run along X: stand them up so the bat runs along Y.
	p.CFrame = CFrame.new(0, y, 0) * (if shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.new())
	p.Parent = model
	return p
end

function PvPBat.build(skinName: string?): Model
	local skin = PvPBat.SKINS[skinName or ""] or PvPBat.SKINS.Starter
	local cylinder, ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	local model = Instance.new("Model")
	model.Name = "PvPBat"
	local grip = piece(model, "Grip", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), 0, skin.dark, Enum.Material.SmoothPlastic)
	grip.Transparency = 1
	local parts = {
		piece(model, "Knob", cylinder, Vector3.new(0.16, 0.48, 0.48), -0.66, skin.dark, skin.material),
		piece(model, "Handle", cylinder, Vector3.new(1.3, 0.27, 0.27), 0, skin.tape, Enum.Material.Fabric),
		piece(model, "Neck", cylinder, Vector3.new(0.95, 0.38, 0.38), 1.1, skin.body, skin.material),
		piece(model, "Barrel", cylinder, Vector3.new(1.5, 0.6, 0.6), 2.3, skin.body, skin.material),
		piece(model, "Cap", ball, Vector3.new(0.6, 0.6, 0.6), 3.05, skin.body, skin.material),
	}
	if skin.band then
		table.insert(parts, piece(model, "BandLow", cylinder, Vector3.new(0.14, 0.64, 0.64), 1.75, skin.band, Enum.Material.Neon))
		table.insert(parts, piece(model, "BandHigh", cylinder, Vector3.new(0.14, 0.64, 0.64), 2.85, skin.band, Enum.Material.Neon))
	end
	for _, p in parts do
		p.Reflectance = skin.reflectance or 0
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = grip, p
		weld.Parent = p
	end
	-- Ends of the barrel, for the swing trail the client adds.
	for name, y in { TrailTip = 3.3, TrailBase = 1.5 } do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(0, y, 0)
		a.Parent = grip
	end
	model.PrimaryPart = grip
	model:SetAttribute("Skin", if PvPBat.SKINS[skinName or ""] then skinName else "Starter")
	return model
end

return PvPBat
