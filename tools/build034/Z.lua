-- Studio location: ServerStorage.Build034.Z (ModuleScript)
-- Shared helpers for the 034 zone builders (Knight's Keep, Sunken Kingdom, Ember Academy, Spell Run).
-- Builds on Build027.Kit (K.part / K.slab / K.text / K.place). Run a builder from Edit mode:
--   require(game.ServerStorage.Build034:Clone().B1_KnightsKeep).build()
-- Every builder rebuilds its own folder under Workspace.World and parks what it replaces in
-- ServerStorage._Parked034.<Zone> (once), so a rebuild never loses anything.

local ServerStorage = game:GetService("ServerStorage")

local K = require(ServerStorage:WaitForChild("Build027"):WaitForChild("Kit"))

local Z = {}
Z.K = K

local rgb = Color3.fromRGB
Z.rgb = rgb

-- A zone's local frame: u = across (east +), v = forward along the lane (north), h = height above `origin`.
function Z.frame(origin: Vector3): (number, number, number) -> Vector3
	return function(u: number, h: number, v: number): Vector3
		return origin + Vector3.new(u, h, -v)
	end
end

-- Moves `inst` into ServerStorage._Parked034.<group> (kept, never destroyed). Returns its part count.
function Z.park(inst: Instance?, group: string): number
	if not inst then
		return 0
	end
	local folder = K.folder(K.folder(ServerStorage, "_Parked034"), group)
	local n = K.count(inst)
	inst.Parent = folder
	return n
end

-- Ground height under (x, z): the highest collidable surface below `fromY`, ignoring `ignore`.
function Z.ground(x: number, z: number, fromY: number, ignore: { Instance }?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -200, 0), params)
	return hit and hit.Position.Y
end

-- Plain block. o: name, size, cf | pos, color, mat, deco, parent, transparency, shadow
function Z.block(parent: Instance, name: string, size: Vector3, cf: CFrame | Vector3, color: Color3, mat: Enum.Material?, deco: boolean?): BasePart
	return K.part({
		name = name,
		parent = parent,
		size = size,
		cf = if typeof(cf) == "CFrame" then cf else nil,
		pos = if typeof(cf) == "Vector3" then cf else nil,
		color = color,
		mat = mat,
		deco = deco,
	})
end

-- Upright cylinder (Roblox cylinders lie along X).
function Z.cyl(parent: Instance, name: string, pos: Vector3, diameter: number, height: number, color: Color3, mat: Enum.Material?, deco: boolean?): BasePart
	return K.part({
		name = name,
		parent = parent,
		shape = "Cylinder",
		size = Vector3.new(height, diameter, diameter),
		cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		mat = mat,
		deco = deco,
	})
end

-- Cylinder lying along the line a -> b.
function Z.rod(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, mat: Enum.Material?, deco: boolean?): BasePart
	local length = (b - a).Magnitude
	return K.part({
		name = name,
		parent = parent,
		shape = "Cylinder",
		size = Vector3.new(length, diameter, diameter),
		cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		color = color,
		mat = mat,
		deco = deco,
	})
end

function Z.ball(parent: Instance, name: string, pos: Vector3, diameter: number, color: Color3, mat: Enum.Material?, deco: boolean?): BasePart
	return K.part({ name = name, parent = parent, shape = "Ball", size = Vector3.one * diameter, pos = pos, color = color, mat = mat, deco = deco })
end

-- Chunky stepped cone (3 stacked cylinders) standing on `base`: roofs, crystals' bases, hats.
function Z.cone(parent: Instance, name: string, base: Vector3, diameter: number, height: number, color: Color3, mat: Enum.Material?): { BasePart }
	local parts = {}
	local step = height / 3
	for i = 0, 2 do
		local d = diameter * (1 - i * 0.32)
		table.insert(parts, Z.cyl(parent, name, base + Vector3.new(0, step * (i + 0.5), 0), d, step, color, mat, true))
	end
	return parts
end

-- Two square pyramids base to base (a gem / crystal), standing on `base`, `height` tall.
function Z.crystal(parent: Instance, name: string, base: Vector3, width: number, height: number, color: Color3, yaw: number?): Model
	local m = Instance.new("Model")
	m.Name = name
	local half = height / 2
	local turn = CFrame.Angles(0, math.rad(yaw or 0), 0)
	for _, up in { 1, -1 } do
		for k = 0, 3 do
			local wedge = K.part({
				name = "Facet",
				parent = m,
				shape = "Wedge",
				size = Vector3.new(width, half, width / 2),
				cf = CFrame.new(base + Vector3.new(0, half, 0)) * turn * CFrame.Angles(0, math.rad(90 * k), 0) * (if up > 0
					then CFrame.new(0, half / 2, width / 4)
					else CFrame.new(0, -half / 2, width / 4) * CFrame.Angles(0, 0, math.pi)),
				color = color,
				mat = Enum.Material.Neon,
				deco = true,
			})
			wedge.CastShadow = false
		end
	end
	m.Parent = parent
	return m
end

-- Warm point light on a part.
function Z.light(part: BasePart, color: Color3, range: number, brightness: number?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.2
	l.Shadows = false
	l.Parent = part
	return l
end

-- Small classic flame (cheap, readable on phones).
function Z.flame(part: BasePart, size: number, color: Color3?, second: Color3?)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.5
	f.Color = color or rgb(255, 150, 40)
	f.SecondaryColor = second or rgb(255, 220, 120)
	f.Parent = part
	return f
end

-- Rising particles (bubbles, embers, smoke). kind: "bubbles" | "embers" | "smoke" | "sparkle"
function Z.particles(part: BasePart, kind: string, rate: number?): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Name = "Fx_" .. kind
	p.Rate = rate or 4
	p.LightEmission = 0.3
	if kind == "bubbles" then
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(rgb(200, 240, 255))
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.7) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		p.Lifetime = NumberRange.new(3, 5)
		p.Speed = NumberRange.new(2, 4)
		p.SpreadAngle = Vector2.new(15, 15)
		p.Acceleration = Vector3.new(0, 1, 0)
	elseif kind == "embers" then
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(rgb(255, 170, 60), rgb(255, 90, 30))
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(1.5, 3)
		p.Speed = NumberRange.new(2, 5)
		p.SpreadAngle = Vector2.new(30, 30)
	elseif kind == "smoke" then
		p.Texture = "rbxasset://textures/particles/smoke_main.dds"
		p.Color = ColorSequence.new(rgb(120, 116, 112))
		p.LightEmission = 0
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		p.Lifetime = NumberRange.new(3, 5)
		p.Speed = NumberRange.new(3, 5)
		p.SpreadAngle = Vector2.new(10, 10)
	else
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(rgb(255, 240, 180))
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(1, 2)
		p.Speed = NumberRange.new(0.5, 1.5)
		p.SpreadAngle = Vector2.new(180, 180)
	end
	p.Parent = part
	return p
end

-- A hanging banner: cloth with a trim border and a simple emblem disc, facing `facing` (unit vector).
function Z.banner(parent: Instance, top: Vector3, facing: Vector3, w: number, h: number, cloth: Color3, trim: Color3, emblem: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Banner"
	local cf = CFrame.lookAt(top, top + facing)
	K.part({ name = "Rod", parent = m, size = Vector3.new(w + 1.2, 0.5, 0.5), cf = cf, color = trim, deco = true })
	K.part({ name = "Trim", parent = m, size = Vector3.new(w + 0.5, h + 0.4, 0.15), cf = cf * CFrame.new(0, -h / 2 - 0.1, 0.05), color = trim, deco = true })
	K.part({ name = "Cloth", parent = m, size = Vector3.new(w, h, 0.2), cf = cf * CFrame.new(0, -h / 2, -0.05), color = cloth, mat = Enum.Material.Fabric, deco = true })
	local disc = K.part({
		name = "Emblem",
		parent = m,
		shape = "Cylinder",
		size = Vector3.new(0.2, w * 0.6, w * 0.6),
		cf = cf * CFrame.new(0, -h * 0.45, -0.2) * CFrame.Angles(0, math.rad(90), 0),
		color = emblem,
		deco = true,
	})
	disc.CastShadow = false
	m.Parent = parent
	return m
end

-- A readable sign board with text on both faces.
function Z.sign(parent: Instance, cf: CFrame, size: Vector3, text: string, board: Color3, ink: Color3): BasePart
	local s = K.part({ name = "Sign", parent = parent, size = size, cf = cf, color = board, deco = true })
	K.text(s, Enum.NormalId.Front, text, ink)
	K.text(s, Enum.NormalId.Back, text, ink)
	return s
end

return Z
