-- Studio location: ServerStorage.Build027.Masters (ModuleScript)
-- Prop masters in ServerStorage.CityKit_027, one per prop, cloned by the build steps. Pivot = centre
-- of the base on the ground, front = -Z. The tree/stall/vault/rock/lamp masters match the Blender
-- meshes in assets/export/027 (same names, sizes and part names), so once those are imported,
-- Masters.fromImports() swaps them in and the placement steps are simply run again.

local K = require(script.Parent.Kit)
local C = K.C

local M = {}

local function model(name: string): Model
	local old = K.masters():FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function finish(m: Model)
	m.WorldPivot = CFrame.new()
	m.Parent = K.masters()
end

local function cyl(m, name, r, h, y, color, mat, deco)
	return K.part({ name = name, parent = m, shape = "Cylinder", size = Vector3.new(h, r * 2, r * 2), cf = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), color = color, mat = mat, deco = deco })
end

local function tree(name, trunkH, trunkR, blobs)
	local m = model(name)
	cyl(m, "Trunk", trunkR, trunkH, trunkH / 2, C.Trunk)
	for i, b in blobs do
		K.part({ name = "Canopy", parent = m, shape = "Ball", size = Vector3.one * b[2] * 2, pos = b[1], color = ({ C.Canopy, C.CanopyLight, C.CanopyDark })[(i - 1) % 3 + 1], deco = true, shadow = true })
	end
	finish(m)
end

function M.build()
	tree("M_Tree_A", 3.5, 0.55, { { Vector3.new(0, 6.2, 0), 2.9 }, { Vector3.new(1.4, 5.3, 0.6), 2.0 } })
	tree("M_Tree_B", 5.0, 0.7, { { Vector3.new(0, 8.6, 0), 3.6 }, { Vector3.new(2.2, 7.4, 0.4), 2.6 }, { Vector3.new(-2.0, 7.6, 0.9), 2.5 } })
	tree("M_Tree_C", 6.5, 0.8, { { Vector3.new(0, 9.4, 0), 3.8 }, { Vector3.new(0, 13.0, 0), 2.9 } })

	do -- stall: 12 wide, 7 deep, front -Z
		local m = model("M_Stall")
		K.part({ name = "Base", parent = m, size = Vector3.new(13, 0.5, 8), pos = Vector3.new(0, 0.25, 0), color = C.Stone })
		K.part({ name = "Counter", parent = m, size = Vector3.new(11.4, 3, 2), pos = Vector3.new(0, 2, -2.3), color = C.Paving })
		K.part({ name = "Counter", parent = m, size = Vector3.new(11.8, 0.3, 2.4), pos = Vector3.new(0, 3.6, -2.3), color = C.Trim })
		K.part({ name = "Counter", parent = m, size = Vector3.new(11.4, 5, 0.6), pos = Vector3.new(0, 3, 3.1), color = C.Paving })
		for _, x in { -5.6, 5.6 } do
			for _, z in { -3.1, 3.1 } do
				cyl(m, "Posts", 0.3, 7.5, 4.0, C.Trim).Position = Vector3.new(x, 4.0, z)
			end
		end
		for i = 0, 7 do -- striped awning, sloping to the front
			K.part({ name = if i % 2 == 0 then "AwningA" else "AwningB", parent = m, size = Vector3.new(13.2 / 8, 0.25, 8.6),
				cf = CFrame.new(-6.6 + 13.2 / 16 + i * 13.2 / 8, 7.4, -0.35) * CFrame.Angles(math.rad(-10.5), 0, 0), color = if i % 2 == 0 then C.Curb else C.Carpet })
		end
		finish(m)
	end

	do -- vault: drum r14 h10, gold dome, lantern
		local m = model("M_Vault")
		cyl(m, "Drum", 14, 10, 5, C.Paving)
		cyl(m, "Drum", 14.6, 0.8, 10.4, C.Trim)
		K.part({ name = "Dome", parent = m, shape = "Ball", size = Vector3.one * 27.6, pos = Vector3.new(0, 10.2, 0), color = C.Trim, mat = Enum.Material.SmoothPlastic })
		cyl(m, "Lantern", 2.2, 2.0, 24.5, C.Trim)
		K.part({ name = "Lantern", parent = m, shape = "Ball", size = Vector3.one * 3.2, pos = Vector3.new(0, 26.8, 0), color = C.Glow, mat = Enum.Material.Neon, deco = true })
		finish(m)
	end

	for _, r in { { "M_Rock_A", 20, 13 }, { "M_Rock_B", 15, 17 } } do -- upside-down cone under the island edge
		local m = model(r[1])
		local radius, depth = r[2], r[3] * 2
		cyl(m, "Rock", radius, depth * 0.35, -depth * 0.175, C.Rock, Enum.Material.Slate)
		cyl(m, "Rock", radius * 0.68, depth * 0.35, -depth * 0.5, C.RockDark, Enum.Material.Slate)
		cyl(m, "Rock", radius * 0.32, depth * 0.3, -depth * 0.82, C.RockDark, Enum.Material.Slate)
		finish(m)
	end

	do -- lamp: post 0..10.6, lantern 11..13.7
		local m = model("M_Lamp")
		cyl(m, "Post", 0.85, 0.8, 0.4, C.Navy)
		cyl(m, "Post", 0.3, 10, 5.5, C.Navy)
		cyl(m, "Head", 0.95, 0.3, 11, C.Trim)
		K.part({ name = "Head", parent = m, shape = "Wedge", size = Vector3.new(2.2, 0.9, 1.1), cf = CFrame.new(0, 13.4, -0.55), color = C.Trim, deco = true })
		K.part({ name = "Head", parent = m, shape = "Wedge", size = Vector3.new(2.2, 0.9, 1.1), cf = CFrame.new(0, 13.4, 0.55) * CFrame.Angles(0, math.pi, 0), color = C.Trim, deco = true })
		K.part({ name = "Glass", parent = m, size = Vector3.new(1.5, 1.9, 1.5), pos = Vector3.new(0, 12.1, 0), color = C.Glow, mat = Enum.Material.Neon, deco = true })
		finish(m)
	end

	do -- bush and flower bed (Studio parts only)
		local m = model("M_Bush")
		K.part({ name = "Leaves", parent = m, shape = "Ball", size = Vector3.new(3.2, 3.2, 3.2), pos = Vector3.new(0, 1.1, 0), color = C.CanopyDark, deco = true })
		K.part({ name = "Leaves", parent = m, shape = "Ball", size = Vector3.new(2.4, 2.4, 2.4), pos = Vector3.new(1.3, 0.8, 0.6), color = C.Canopy, deco = true })
		finish(m)
		local f = model("M_Flowers")
		K.part({ name = "Bed", parent = f, shape = "Ball", size = Vector3.new(2.6, 2.6, 2.6), pos = Vector3.new(0, 0.4, 0), color = C.Hedge, deco = true })
		for i, col in { C.Carpet, C.Trim, C.Curb } do
			local a = i * math.pi * 2 / 3
			K.part({ name = "Bloom", parent = f, shape = "Ball", size = Vector3.one * 0.9, pos = Vector3.new(math.cos(a) * 0.7, 1.5, math.sin(a) * 0.7), color = col, deco = true })
		end
		finish(f)
	end

	-- decoration never collides except where a player would walk into it (trunks, posts, counters)
	for _, m in K.masters():GetChildren() do
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local solid = p.Name == "Trunk" or p.Name == "Post" or p.Name == "Posts" or p.Name == "Counter" or p.Name == "Base" or p.Name == "Drum"
				p.CanCollide = solid
				p.CanQuery, p.CanTouch = solid, false
				if p:IsA("MeshPart") then
					p.CollisionFidelity = Enum.CollisionFidelity.Box
				end
			end
		end
	end
	return ("masters: %d"):format(#K.masters():GetChildren())
end

-- After the owner imports assets/export/027/*.fbx (Home > Import 3D), the eight imported models sit in
-- Workspace under their file names. This turns each into its master (replacing the part-built
-- stand-in), keeps the import in ServerStorage.CityKit_027_Imports, and reports what it found.
local COLOURS = {
	Trunk = { C.Trunk }, Canopy = { C.Canopy }, Counter = { C.Paving }, Posts = { C.Trim }, AwningA = { C.Curb },
	AwningB = { C.Carpet }, Base = { C.Stone }, Drum = { C.Paving }, Dome = { C.Trim }, Ribs = { C.TrimDark },
	Lantern = { C.Glow, Enum.Material.Neon }, Rock = { C.Rock, Enum.Material.Slate }, Post = { C.Navy }, Head = { C.Trim },
	Glass = { C.Glow, Enum.Material.Neon },
}
local IMPORTS = { "Tree_A", "Tree_B", "Tree_C", "Stall", "Vault", "Rock_A", "Rock_B", "Lamp" }

function M.fromImports(): string
	local store = K.folder(game:GetService("ServerStorage"), "CityKit_027_Imports")
	local lines = {}
	for _, name in IMPORTS do
		local import = workspace:FindFirstChild(name)
		if not import then
			table.insert(lines, name .. ": not imported (stand-in kept)")
			continue
		end
		local meshes = {}
		for _, d in import:GetDescendants() do
			if d:IsA("MeshPart") then
				table.insert(meshes, d)
			end
		end
		if #meshes == 0 then
			table.insert(lines, name .. ": no MeshParts inside")
			continue
		end
		-- world-space box from part corners (the importer's pivot is rotated, so don't trust it)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, p in meshes do
			local h = p.Size / 2
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
				lo, hi = lo:Min(w), hi:Max(w)
			end end end
		end
		local rockLike = name:match("^Rock") ~= nil -- rocks hang below the island: pivot on their flat top
		local pivot = Vector3.new((lo.X + hi.X) / 2, if rockLike then hi.Y else lo.Y, (lo.Z + hi.Z) / 2)
		local m = model("M_" .. name)
		for _, p in meshes do
			local c = p:Clone()
			c:ClearAllChildren()
			c.Anchored = true
			local look = COLOURS[c.Name]
			if look then
				c.Color = look[1]
				c.Material = look[2] or Enum.Material.SmoothPlastic
			end
			c.TextureID = ""
			local solid = c.Name == "Trunk" or c.Name == "Post" or c.Name == "Posts" or c.Name == "Counter" or c.Name == "Base" or c.Name == "Drum"
			c.CanCollide, c.CanQuery, c.CanTouch = solid, solid, false
			c.CollisionFidelity = Enum.CollisionFidelity.Box
			c.CastShadow = c.Name ~= "Glass" and c.Name ~= "Lantern"
			c.Parent = m
		end
		m.WorldPivot = CFrame.new(pivot)
		m.Parent = K.masters()
		local size = hi - lo
		table.insert(lines, ("%s: %d meshes, %.1f x %.1f x %.1f"):format(name, #meshes, size.X, size.Y, size.Z))
		import.Parent = store
	end
	return table.concat(lines, "\n")
end

return M
