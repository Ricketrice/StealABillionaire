-- Studio location: ServerStorage.Build034.B1_KnightsKeep (ModuleScript)
-- 034 Phase 2: Knight's Keep (terrace 1, the old Main Street, rebuilt in place). Bright castle courtyard:
-- gatehouse (signature landmark) at the arch, crenellated walls with round red-roofed towers on both sides,
-- banners + torches, training yard with dummies and a forge (west), jousting lane and the Hall of Champions
-- statue (east), pennant lines across the courtyard. The street paving, the catch spots, the NPC area
-- (Workspace.Zones.MainStreet) and the heist treasury at the far end are kept.
-- Parks (once): MainStreet Shopfronts / Bunting / Benches / Lamps / Sections and Hub.Zone1Arch -> _Parked034.KnightsKeep.
-- Frame: u across (east +), v north from the arch (z -164), h above the courtyard paving (y 12.3).

local Z = require(script.Parent.Z)
local K = Z.K
local rgb = Z.rgb

local O = Vector3.new(-157, 12.3, -164)
local at = Z.frame(O)

local C = {
	stone = rgb(176, 168, 156),
	stoneDark = rgb(132, 124, 116),
	cap = rgb(206, 198, 184),
	roof = rgb(196, 54, 60),
	red = rgb(200, 48, 56),
	teal = rgb(40, 168, 170),
	gold = rgb(240, 186, 58),
	wood = rgb(140, 96, 58),
	woodDark = rgb(100, 68, 42),
	straw = rgb(226, 196, 110),
	burlap = rgb(196, 160, 110),
	iron = rgb(70, 72, 80),
	slit = rgb(40, 36, 44),
	sand = rgb(226, 206, 160),
	white = rgb(246, 242, 232),
	glow = rgb(255, 170, 70),
}

local WALL_U = 40 -- walls stand at u = +-40
local WALL_H = 14
local TOWER_VS = { 0, 55, 110, 160 }

local function wallSegment(f: Instance, u: number, v0: number, v1: number)
	local len = v1 - v0
	local mid = (v0 + v1) / 2
	Z.block(f, "Wall", Vector3.new(3, WALL_H, len), at(u, WALL_H / 2, mid), C.stone, Enum.Material.Cobblestone)
	Z.block(f, "Plinth", Vector3.new(4, 1.2, len), at(u, 0.6, mid), C.stoneDark, Enum.Material.Slate, true)
	Z.block(f, "Walk", Vector3.new(3.6, 0.8, len), at(u, WALL_H + 0.4, mid), C.cap, Enum.Material.Slate, true)
	local n = math.floor(len / 4)
	for i = 0, n - 1 do
		local v = v0 + (i + 0.5) * (len / n)
		Z.block(f, "Merlon", Vector3.new(3.2, 2.4, 2), at(u, WALL_H + 2, v), C.stone, Enum.Material.Cobblestone, true)
	end
end

local function tower(f: Instance, u: number, v: number, height: number, diameter: number)
	local m = Instance.new("Model")
	m.Name = "Tower"
	Z.cyl(m, "Base", at(u, 0.6, v), diameter + 1.6, 1.2, C.stoneDark, Enum.Material.Slate)
	Z.cyl(m, "Body", at(u, height / 2, v), diameter, height, C.stone, Enum.Material.Cobblestone)
	Z.cyl(m, "Ring", at(u, height + 0.6, v), diameter + 1.4, 1.2, C.cap, Enum.Material.Slate, true)
	Z.cone(m, "Roof", at(u, height + 1.2, v), diameter + 1.8, 8, C.roof, Enum.Material.SmoothPlastic)
	Z.ball(m, "Finial", at(u, height + 10, v), 1.2, C.gold, Enum.Material.SmoothPlastic, true)
	-- two arrow slits facing the courtyard
	local inward = if u < 0 then 1 else -1
	for _, dh in { height * 0.4, height * 0.72 } do
		Z.block(m, "Slit", Vector3.new(0.4, 2.6, 0.8), at(u + inward * (diameter / 2 - 0.1), dh, v), C.slit, nil, true)
	end
	m.Parent = f
	return m
end

local function torch(f: Instance, pos: Vector3, facing: Vector3, lit: boolean)
	local holder = Z.block(f, "Sconce", Vector3.new(0.6, 1.8, 0.6), CFrame.lookAt(pos, pos + facing), C.iron, Enum.Material.Metal, true)
	local cup = Z.cyl(f, "TorchCup", pos + Vector3.new(0, 1.1, 0) + facing * 0.4, 1, 0.6, C.iron, Enum.Material.Metal, true)
	Z.flame(cup, 1.6)
	if lit then
		Z.light(cup, C.glow, 14, 1.1)
	end
	return holder
end

local function dummy(f: Instance, pos: Vector3, yaw: number)
	local m = Instance.new("Model")
	m.Name = "TrainingDummy"
	local turn = CFrame.Angles(0, math.rad(yaw), 0)
	Z.cyl(m, "Post", pos + Vector3.new(0, 2.4, 0), 0.7, 4.8, C.wood, Enum.Material.Wood)
	Z.block(m, "Body", Vector3.new(2.4, 2.8, 1.6), CFrame.new(pos + Vector3.new(0, 4.4, 0)) * turn, C.burlap, Enum.Material.Fabric)
	Z.ball(m, "Head", pos + Vector3.new(0, 6.5, 0), 1.6, C.burlap, Enum.Material.Fabric)
	Z.block(m, "Arms", Vector3.new(4.8, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 5.1, 0)) * turn, C.woodDark, Enum.Material.Wood, true)
	for i, d in { 1.5, 0.8 } do
		local disc = K.part({
			name = "Target",
			parent = m,
			shape = "Cylinder",
			size = Vector3.new(0.1 + i * 0.05, d, d),
			cf = CFrame.new(pos + Vector3.new(0, 4.5, 0)) * turn * CFrame.new(0, 0, -0.85 - i * 0.04) * CFrame.Angles(0, math.rad(90), 0),
			color = if i == 1 then C.white else C.red,
			deco = true,
		})
		disc.CastShadow = false
	end
	m.Parent = f
end

local function fence(f: Instance, u: number, v0: number, v1: number, striped: boolean)
	local len = v1 - v0
	local posts = math.max(2, math.floor(len / 8) + 1)
	for i = 0, posts - 1 do
		local v = v0 + len * i / (posts - 1)
		Z.block(
			f,
			"FencePost",
			Vector3.new(0.8, 3.4, 0.8),
			at(u, 1.7, v),
			if striped and i % 2 == 1 then C.white else (if striped then C.red else C.wood),
			Enum.Material.Wood,
			true
		)
	end
	for _, h in { 1.4, 2.8 } do
		Z.block(f, "FenceRail", Vector3.new(0.4, 0.4, len), at(u, h, (v0 + v1) / 2), C.wood, Enum.Material.Wood, true)
	end
end

local function build(): string
	local world = workspace:WaitForChild("World")
	local sky = world:WaitForChild("SkyCity")
	local ms = sky:WaitForChild("MainStreet")
	local parked = 0
	for _, name in { "Shopfronts", "Bunting", "Benches", "Lamps", "Sections" } do
		parked += Z.park(ms:FindFirstChild(name), "KnightsKeep")
	end
	parked += Z.park(sky.Hub:FindFirstChild("Zone1Arch"), "KnightsKeep")

	local f = K.folder(world, "KnightsKeep", true)
	f:SetAttribute("Zone", "MainStreet")

	-- walls + towers ---------------------------------------------------------------------------------
	local walls = K.folder(f, "Walls")
	for _, side in { -1, 1 } do
		local u = side * WALL_U
		for i = 1, #TOWER_VS - 1 do
			wallSegment(walls, u, TOWER_VS[i] + 5, TOWER_VS[i + 1] - 5)
		end
		for i, v in TOWER_VS do
			tower(walls, u, v, if i == 1 or i == #TOWER_VS then 22 else 19, 10)
		end
		-- front wall from the corner tower to the gatehouse
		local len = WALL_U - 5 - 23
		local mid = side * (23 + len / 2)
		Z.block(walls, "Wall", Vector3.new(len, WALL_H, 3), at(mid, WALL_H / 2, 0), C.stone, Enum.Material.Cobblestone)
		Z.block(walls, "Walk", Vector3.new(len, 0.8, 3.6), at(mid, WALL_H + 0.4, 0), C.cap, Enum.Material.Slate, true)
		for k = 0, 2 do
			Z.block(walls, "Merlon", Vector3.new(2, 2.4, 3.2), at(side * (25 + k * 4.4), WALL_H + 2, 0), C.stone, Enum.Material.Cobblestone, true)
		end
		-- banners and torches on the inner face
		local inner = Vector3.new(-side, 0, 0)
		for _, v in { 28, 82, 135 } do
			Z.banner(walls, at(u - side * 1.7, WALL_H - 1, v), inner, 5, 8, C.red, C.gold, C.teal)
		end
		for _, v in { 55, 110 } do
			torch(walls, at(u - side * 5.4, 7, v), inner, true)
		end
	end

	-- gatehouse (signature landmark) -------------------------------------------------------------------
	local gate = K.folder(f, "Gatehouse")
	for _, side in { -1, 1 } do
		local u = side * 18
		Z.block(gate, "GateTower", Vector3.new(10, 24, 10), at(u, 12, 0), C.stone, Enum.Material.Cobblestone)
		Z.block(gate, "GateTowerBase", Vector3.new(11.4, 1.4, 11.4), at(u, 0.7, 0), C.stoneDark, Enum.Material.Slate, true)
		Z.block(gate, "GateTowerTop", Vector3.new(11, 0.8, 11), at(u, 24.4, 0), C.cap, Enum.Material.Slate, true)
		for _, c in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
			Z.block(gate, "Merlon", Vector3.new(2.4, 2.6, 2.4), at(u + c[1], 26.1, c[2]), C.stone, Enum.Material.Cobblestone, true)
		end
		Z.block(gate, "Window", Vector3.new(2.6, 4, 0.4), at(u, 16, 5.1), C.slit, nil, true)
		Z.block(gate, "Window", Vector3.new(2.6, 4, 0.4), at(u, 16, -5.1), C.slit, nil, true)
		torch(gate, at(side * 12.4, 8, -5.3), Vector3.new(0, 0, 1), true)
		-- flag pole + pennant on top
		Z.rod(gate, "FlagPole", at(u, 27, 0), at(u, 36, 0), 0.5, C.iron, Enum.Material.Metal, true)
		K.part({ name = "Flag", parent = gate, size = Vector3.new(5, 3, 0.2), cf = CFrame.new(at(u + side * 2.6, 34.4, 0)), color = C.red, mat = Enum.Material.Fabric, deco = true })
	end
	Z.block(gate, "ArchBeam", Vector3.new(26, 6, 9), at(0, 19, 0), C.stone, Enum.Material.Cobblestone)
	Z.block(gate, "ArchTrim", Vector3.new(26.4, 0.8, 9.4), at(0, 16.2, 0), C.gold, nil, true)
	for k = -2, 2 do
		Z.block(gate, "Merlon", Vector3.new(2.6, 2.4, 2.4), at(k * 5, 23.2, -3.4), C.stone, Enum.Material.Cobblestone, true)
	end
	Z.block(gate, "Portcullis", Vector3.new(22, 2.6, 0.6), at(0, 14.8, 0), C.iron, Enum.Material.DiamondPlate, true)
	for k = -5, 5 do
		Z.block(gate, "Spike", Vector3.new(0.4, 1.6, 0.4), at(k * 2, 12.8, 0), C.iron, Enum.Material.Metal, true)
	end
	Z.sign(gate, CFrame.lookAt(at(0, 19.4, -4.7), at(0, 19.4, -20)), Vector3.new(20, 3.6, 0.4), "KNIGHT'S KEEP", C.red, C.gold)
	Z.banner(gate, at(0, 15.6, 4.7), Vector3.new(0, 0, -1), 6, 7, C.red, C.gold, C.teal)

	-- training yard + forge (west strip u -27..-38) -----------------------------------------------------
	local west = K.folder(f, "TrainingYard")
	K.slab(west, "YardSand", O.X - 38, O.X - 27, O.Z - 95, O.Z - 15, O.Y + 0.08, 0.1, C.sand, Enum.Material.Sand).CanCollide = false
	fence(west, -26.5, 15, 95, false)
	for i, v in { 25, 45, 65, 85 } do
		dummy(west, at(-33, 0, v), 90 + (i % 2) * 18)
	end
	for _, v in { 35, 75 } do
		Z.block(west, "Rack", Vector3.new(0.6, 3.6, 5), at(-37.3, 1.8, v), C.woodDark, Enum.Material.Wood, true)
		for k = -1, 1 do
			Z.block(west, "WoodenSword", Vector3.new(0.3, 3.8, 0.7), CFrame.new(at(-36.7, 2.4, v + k * 1.5)) * CFrame.Angles(0, 0, math.rad(8)), C.wood, Enum.Material.Wood, true)
		end
	end
	for _, v in { 18, 92 } do
		Z.block(west, "HayBale", Vector3.new(3, 2, 2), at(-35, 1, v), C.straw, Enum.Material.Grass, true)
	end
	Z.sign(west, CFrame.lookAt(at(-27, 4.6, 18), at(0, 4.6, 18)), Vector3.new(7, 1.6, 0.3), "TRAINING YARD", C.woodDark, C.white)

	local forge = K.folder(f, "Forge")
	local fu, fv = -33, 132
	Z.block(forge, "Hearth", Vector3.new(7, 5, 6), at(fu - 1, 2.5, fv), C.stoneDark, Enum.Material.Brick)
	Z.block(forge, "Opening", Vector3.new(0.4, 2.4, 3.6), at(fu + 2.55, 2.4, fv), C.slit, nil, true)
	local coals = Z.block(forge, "Coals", Vector3.new(0.5, 0.8, 3), at(fu + 2.6, 1.4, fv), C.glow, Enum.Material.Neon, true)
	coals.CastShadow = false
	Z.flame(coals, 2.2)
	Z.light(coals, C.glow, 16, 1.6)
	local chimney = Z.block(forge, "Chimney", Vector3.new(3, 12, 3), at(fu - 2.5, 11, fv), C.stoneDark, Enum.Material.Brick)
	Z.particles(chimney, "smoke", 2).EmissionDirection = Enum.NormalId.Top
	for _, dv in { -6, 6 } do
		Z.block(forge, "AwningPost", Vector3.new(0.8, 8, 0.8), at(fu + 4.5, 4, fv + dv), C.woodDark, Enum.Material.Wood)
	end
	K.part({
		name = "Awning",
		parent = forge,
		shape = "Wedge",
		size = Vector3.new(14, 1.8, 10),
		cf = CFrame.new(at(fu + 1, 8.9, fv)) * CFrame.Angles(0, math.rad(-90), 0),
		color = C.roof,
		mat = Enum.Material.WoodPlanks,
		deco = true,
	})
	Z.block(forge, "AnvilBase", Vector3.new(1.4, 1.6, 1.4), at(fu + 6, 0.8, fv + 3), C.woodDark, Enum.Material.Wood, true)
	Z.block(forge, "Anvil", Vector3.new(1.4, 0.9, 2.6), at(fu + 6, 2.05, fv + 3), C.iron, Enum.Material.Metal, true)
	K.part({
		name = "AnvilHorn",
		parent = forge,
		shape = "Wedge",
		size = Vector3.new(1, 0.9, 1.4),
		cf = CFrame.new(at(fu + 6, 2.05, fv + 4.9)) * CFrame.Angles(0, math.pi, 0),
		color = C.iron,
		mat = Enum.Material.Metal,
		deco = true,
	})
	Z.cyl(forge, "WaterBarrel", at(fu + 6, 1.3, fv - 4), 2.4, 2.6, C.wood, Enum.Material.Wood, true)
	Z.sign(forge, CFrame.lookAt(at(fu + 5.4, 9.6, fv), at(0, 9.6, fv)), Vector3.new(6, 1.6, 0.3), "FORGE", C.woodDark, C.gold)

	-- jousting lane + Hall of Champions (east strip u 27..38) -------------------------------------------
	local east = K.folder(f, "JoustingLane")
	K.slab(east, "LaneDirt", O.X + 27, O.X + 38, O.Z - 105, O.Z - 15, O.Y + 0.08, 0.1, rgb(196, 170, 128), Enum.Material.Ground).CanCollide = false
	fence(east, 32.5, 20, 100, true)
	for _, v in { 16, 104 } do
		Z.rod(east, "FlagPole", at(32.5, 0, v), at(32.5, 9, v), 0.4, C.iron, Enum.Material.Metal, true)
		K.part({
			name = "Flag",
			parent = east,
			size = Vector3.new(0.2, 2.4, 3.6),
			cf = CFrame.new(at(32.5, 7.6, v - 1.9)),
			color = if v < 50 then C.red else C.teal,
			mat = Enum.Material.Fabric,
			deco = true,
		})
	end
	Z.block(east, "LanceRack", Vector3.new(4.5, 0.6, 1), at(36.5, 4, 60), C.woodDark, Enum.Material.Wood, true)
	for k = -1, 1 do
		Z.rod(east, "Lance", at(36.5 + k * 1.4, 0.2, 60.2), at(36.5 + k * 1.4, 10, 59.6), 0.5, if k == 0 then C.teal else C.red, nil, true)
	end
	-- quintain (spinning target post)
	Z.cyl(east, "QuintainPost", at(29, 3, 60), 0.8, 6, C.wood, Enum.Material.Wood, true)
	Z.block(east, "QuintainArm", Vector3.new(0.4, 0.4, 5), at(29, 6, 60), C.woodDark, Enum.Material.Wood, true)
	K.part({
		name = "QuintainShield",
		parent = east,
		shape = "Cylinder",
		size = Vector3.new(0.3, 2.4, 2.4),
		cf = CFrame.new(at(29, 5.6, 62.6)) * CFrame.Angles(0, math.rad(90), 0),
		color = C.red,
		deco = true,
	})
	Z.sign(east, CFrame.lookAt(at(27, 4.6, 18), at(0, 4.6, 18)), Vector3.new(7, 1.6, 0.3), "JOUSTING LANE", C.woodDark, C.white)

	local hall = K.folder(f, "HallOfChampions")
	local hu, hv = 33, 135
	Z.cyl(hall, "Plinth", at(hu, 1, hv), 7, 2, C.cap, Enum.Material.Marble)
	Z.cyl(hall, "PlinthTrim", at(hu, 2.2, hv), 6.2, 0.4, C.gold, nil, true)
	local s = 1.4 -- statue scale
	Z.block(hall, "Legs", Vector3.new(2 * s, 3 * s, 1.2 * s), at(hu, 2.4 + 1.5 * s, hv), C.cap, Enum.Material.Marble)
	Z.block(hall, "Body", Vector3.new(2.6 * s, 2.6 * s, 1.4 * s), at(hu, 2.4 + 4.3 * s, hv), C.cap, Enum.Material.Marble)
	Z.ball(hall, "Helmet", at(hu, 2.4 + 6.4 * s, hv), 2 * s, C.cap, Enum.Material.Marble)
	Z.block(hall, "Plume", Vector3.new(0.4 * s, 1.4 * s, 1.6 * s), at(hu, 2.4 + 7.6 * s, hv), C.red, Enum.Material.Fabric, true)
	Z.rod(hall, "Sword", at(hu - 1.8 * s, 2.4 + 3 * s, hv), at(hu - 1.8 * s, 2.4 + 8 * s, hv), 0.4 * s, C.gold, Enum.Material.Metal, true)
	K.part({
		name = "Shield",
		parent = hall,
		shape = "Cylinder",
		size = Vector3.new(0.4, 2.6 * s, 2.6 * s),
		cf = CFrame.new(at(hu - 1.7 * s, 2.4 + 4.3 * s, hv)) * CFrame.Angles(0, 0, 0),
		color = C.teal,
		deco = true,
	})
	Z.sign(hall, CFrame.lookAt(at(hu - 3.7, 1.2, hv), at(0, 1.2, hv)), Vector3.new(5, 1.1, 0.2), "HALL OF CHAMPIONS", C.red, C.gold)
	Z.particles(Z.cyl(hall, "Glint", at(hu, 2.5, hv), 0.2, 0.2, C.gold, nil, true), "sparkle", 2)

	-- pennant lines across the courtyard ----------------------------------------------------------------
	local pennants = K.folder(f, "Pennants")
	for _, v in { 50, 105 } do
		Z.rod(pennants, "Rope", at(-WALL_U + 1.5, WALL_H + 3, v), at(WALL_U - 1.5, WALL_H + 3, v), 0.15, C.woodDark, nil, true)
		for k = -3, 3 do
			local p = K.part({
				name = "Pennant",
				parent = pennants,
				shape = "Wedge",
				size = Vector3.new(0.15, 2.4, 2.6),
				cf = CFrame.new(at(k * 10, WALL_H + 1.8, v)) * CFrame.Angles(math.pi, 0, 0),
				color = if k % 2 == 0 then C.red else C.teal,
				mat = Enum.Material.Fabric,
				deco = true,
			})
			p.CastShadow = false
		end
	end

	return ("Knight's Keep: %d parts (parked %d)"):format(K.count(f), parked)
end

return { build = build }
