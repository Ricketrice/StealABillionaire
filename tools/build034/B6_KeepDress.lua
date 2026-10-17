-- Studio location: ServerStorage.Build034.B6_KeepDress (ModuleScript)
-- 036 Part C: Knight's Keep dress-up. LOOK ONLY and additive: every part is a ghost-free decoration (CanCollide / CanQuery / CanTouch false, no shadows), so nothing the game reads moves
-- (paths, spawns, pads, teleports, gates, the NPC area, the treasury). It sits in Workspace.World.KnightsKeep.Dress036 and never touches the B1 folders; delete that folder to undo.
-- Frame and palette are B1's: u across (east +), v north from the arch (z -164), h above the courtyard paving (y 12.3); walls at u = +-40, towers at v 0 / 55 / 110 / 160.
-- Adds: stone pilasters + heraldic shields on both inner wall faces, tower cornices / lit windows / pennants, gate crests and north-face torches, four courtyard braziers,
-- flower planters by the gate, barrel / crate clusters. Six warm lights in all (no shadows); no global lighting change (the sky and mood are shared with the teammates' zones).
-- Run from Edit mode:  require(game.ServerStorage.Build034:Clone().B6_KeepDress).build()

local Z = require(script.Parent.Z)
local K = Z.K
local rgb = Z.rgb

local O = Vector3.new(-157, 12.3, -164)
local at = Z.frame(O)

local C = {
	stone = rgb(176, 168, 156),
	stoneDark = rgb(132, 124, 116),
	cap = rgb(206, 198, 184),
	red = rgb(200, 48, 56),
	teal = rgb(40, 168, 170),
	gold = rgb(240, 186, 58),
	wood = rgb(140, 96, 58),
	woodDark = rgb(100, 68, 42),
	straw = rgb(226, 196, 110),
	iron = rgb(70, 72, 80),
	glow = rgb(255, 170, 70),
	window = rgb(255, 214, 120),
	grass = rgb(84, 156, 72),
	soil = rgb(110, 78, 52),
}
local FLOWERS = { rgb(244, 120, 160), rgb(250, 214, 70), rgb(246, 246, 240), rgb(170, 120, 230), rgb(250, 140, 60) }

local WALL_U, WALL_H = 40, 14
local TOWER_VS = { 0, 55, 110, 160 }

-- a round shield on a wall face (axis along u), `side` = which wall (-1 west / +1 east); faces the courtyard
local function shield(f: Instance, side: number, v: number, h: number, color: Color3)
	local face = side * (WALL_U - 1.5) -- the inner wall face
	local inward = -side
	K.part({ name = "Shield", parent = f, shape = "Cylinder", size = Vector3.new(0.3, 2.8, 2.8), pos = at(face + inward * 0.2, h, v), color = color, deco = true })
	K.part({ name = "ShieldRim", parent = f, shape = "Cylinder", size = Vector3.new(0.2, 3.3, 3.3), pos = at(face + inward * 0.1, h, v), color = C.gold, deco = true })
	K.part({ name = "ShieldStripe", parent = f, size = Vector3.new(0.12, 2.6, 0.6), pos = at(face + inward * 0.42, h, v), color = C.cap, deco = true })
end

local function pilaster(f: Instance, side: number, v: number)
	local u = side * (WALL_U - 2.3)
	Z.block(f, "PilasterBase", Vector3.new(2.4, 1.2, 2.4), at(u, 0.6, v), C.stoneDark, Enum.Material.Slate, true)
	Z.block(f, "Pilaster", Vector3.new(1.6, WALL_H - 1.6, 1.6), at(u, 1.2 + (WALL_H - 1.6) / 2, v), C.stone, Enum.Material.Cobblestone, true)
	Z.block(f, "PilasterCap", Vector3.new(2.2, 0.8, 2.2), at(u, WALL_H - 0.4, v), C.cap, Enum.Material.Slate, true)
end

local function torch(f: Instance, pos: Vector3, facing: Vector3)
	Z.block(f, "Sconce", Vector3.new(0.6, 1.8, 0.6), CFrame.lookAt(pos, pos + facing), C.iron, Enum.Material.Metal, true)
	local cup = Z.cyl(f, "TorchCup", pos + Vector3.new(0, 1.1, 0) + facing * 0.4, 1, 0.6, C.iron, Enum.Material.Metal, true)
	Z.flame(cup, 1.6)
	Z.light(cup, C.glow, 14, 1.1)
end

local function brazier(f: Instance, base: Vector3)
	for k = 0, 2 do
		local a = math.rad(k * 120)
		Z.rod(
			f,
			"BrazierLeg",
			base + Vector3.new(math.cos(a) * 1.1, 0, math.sin(a) * 1.1),
			base + Vector3.new(math.cos(a) * 0.5, 3, math.sin(a) * 0.5),
			0.28,
			C.iron,
			Enum.Material.Metal,
			true
		)
	end
	local bowl = Z.cyl(f, "BrazierBowl", base + Vector3.new(0, 3.2, 0), 2.4, 0.9, C.iron, Enum.Material.Metal, true)
	Z.cyl(f, "BrazierTrim", base + Vector3.new(0, 3.7, 0), 2.7, 0.2, C.gold, nil, true)
	Z.flame(bowl, 2.2)
	Z.light(bowl, C.glow, 16, 1.2)
end

local function planter(f: Instance, pos: Vector3, seed: number)
	Z.block(f, "Planter", Vector3.new(3.4, 1.3, 1.5), pos + Vector3.new(0, 0.65, 0), C.stoneDark, Enum.Material.Brick, true)
	Z.block(f, "PlanterRim", Vector3.new(3.7, 0.25, 1.8), pos + Vector3.new(0, 1.4, 0), C.cap, Enum.Material.Slate, true)
	Z.block(f, "Greens", Vector3.new(3.1, 0.6, 1.2), pos + Vector3.new(0, 1.65, 0), C.grass, Enum.Material.Grass, true)
	for i = -2, 2 do
		Z.ball(
			f,
			"Flower",
			pos + Vector3.new(i * 0.62, 2.15 + ((i + seed) % 2) * 0.2, ((i + seed) % 3 - 1) * 0.25),
			0.8,
			FLOWERS[(i + seed) % #FLOWERS + 1],
			Enum.Material.SmoothPlastic,
			true
		)
	end
end

local function cluster(f: Instance, pos: Vector3, turn: number)
	local r = CFrame.Angles(0, math.rad(turn), 0)
	local function off(x: number, y: number, z: number): Vector3
		return pos + (r * CFrame.new(x, y, z)).Position
	end
	for _, b in { { 0, 0 }, { 2.1, 0.4 } } do
		Z.cyl(f, "Barrel", off(b[1], 1.1, b[2]), 1.8, 2.2, C.wood, Enum.Material.Wood, true)
		Z.cyl(f, "BarrelBand", off(b[1], 1.1, b[2]), 1.95, 0.25, C.iron, Enum.Material.Metal, true)
	end
	Z.block(f, "Crate", Vector3.new(2, 2, 2), CFrame.new(off(-1.6, 1, 0.6)) * r, C.woodDark, Enum.Material.WoodPlanks, true)
	Z.block(f, "CrateLid", Vector3.new(2.2, 0.25, 2.2), CFrame.new(off(-1.6, 2.1, 0.6)) * r, C.wood, Enum.Material.Wood, true)
end

local function build(): string
	local keep = workspace:WaitForChild("World"):WaitForChild("KnightsKeep")
	local f = K.folder(keep, "Dress036", true)

	for _, side in { -1, 1 } do
		-- stone pilasters and shields on the inner wall faces (clear of the banners at v 28 / 82 / 135, the torches at 55 / 110 and the tower footprints)
		for _, v in { 16, 41, 68, 96, 124, 150 } do
			pilaster(f, side, v)
		end
		for i, v in { 10, 34, 76, 89, 120, 142 } do
			shield(f, side, v, 9.5, if (i + (side + 1) / 2) % 2 == 0 then C.red else C.teal)
		end
		-- tower cornice, lit window and pennant
		for i, v in TOWER_VS do
			local height = if i == 1 or i == #TOWER_VS then 22 else 19
			local u = side * WALL_U
			local inward = -side
			Z.cyl(f, "Cornice", at(u, height - 3, v), 11.4, 0.5, C.gold, nil, true)
			Z.block(f, "WindowFrame", Vector3.new(0.3, 3.6, 2.4), at(u + inward * 4.85, height * 0.56, v), C.stoneDark, Enum.Material.Slate, true)
			Z.block(f, "WindowGlow", Vector3.new(0.3, 2.8, 1.6), at(u + inward * 5, height * 0.56, v), C.window, Enum.Material.Neon, true).CastShadow = false
			Z.rod(f, "Pole", at(u, height + 10.6, v), at(u, height + 14.8, v), 0.3, C.iron, Enum.Material.Metal, true)
			K.part({
				name = "Pennant",
				parent = f,
				size = Vector3.new(0.2, 2.2, 3.4),
				pos = at(u, height + 13.6, v + 1.9),
				color = if (i + side) % 2 == 0 then C.red else C.teal,
				mat = Enum.Material.Fabric,
				deco = true,
			})
		end
		-- gatehouse crests (south face = the approach, north face = the courtyard) and north-face torches
		for _, face in { -1, 1 } do
			local v = face * 5.25
			local turn = CFrame.Angles(0, math.rad(90), 0)
			K.part({
				name = "CrestRim",
				parent = f,
				shape = "Cylinder",
				size = Vector3.new(0.2, 4.8, 4.8),
				cf = CFrame.new(at(side * 18, 20.5, v)) * turn,
				color = C.gold,
				deco = true,
			})
			K.part({
				name = "Crest",
				parent = f,
				shape = "Cylinder",
				size = Vector3.new(0.3, 4.2, 4.2),
				cf = CFrame.new(at(side * 18, 20.5, v + face * 0.15)) * turn,
				color = if side < 0 then C.red else C.teal,
				deco = true,
			})
			K.part({ name = "CrestStar", parent = f, shape = "Ball", size = Vector3.one * 1.5, pos = at(side * 18, 20.5, v + face * 0.4), color = C.gold, deco = true })
		end
		torch(f, at(side * 12.4, 8, 5.3), Vector3.new(0, 0, -1))
		-- courtyard braziers, planters at the gate and barrel clusters on the strips
		brazier(f, at(side * 22, 0, 22))
		brazier(f, at(side * 22, 0, 100))
		planter(f, at(side * 15, 0, 8.5), side + 2)
		planter(f, at(side * 29, 0, 8.5), side + 4)
		cluster(f, at(side * 36, 0, 118), if side < 0 then 20 else -20)
		cluster(f, at(side * 36.5, 0, 9.5), if side < 0 then -15 else 15)
	end

	local lights = 0
	for _, d in f:GetDescendants() do
		if d:IsA("PointLight") then
			lights += 1
		end
	end
	return ("Dress036: %d parts, %d lights"):format(K.count(f), lights)
end

return { build = build }
