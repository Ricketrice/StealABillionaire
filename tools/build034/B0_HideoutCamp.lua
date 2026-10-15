-- Studio location: ServerStorage.Build034.B0_HideoutCamp (ModuleScript)
-- 034 Phase 1: Hideout Camp, the start area (bases, spawn, parade, shops) dressed as a camp of little forts.
-- Decoration only (CanCollide/CanQuery/CanTouch off): nothing here changes a lot, its fence, gate, stations or the
-- safe zone. Builds World.HideoutCamp (rebuilt fresh every run):
--   * every lot (Workspace.Hub.Plots.PlotN) gets four log watchtowers on its fence corners, roofed in that lot's
--     colour (Kit.LOT_COLOURS[N]), with pennants on the two back towers and on both gate posts;
--   * a log arch "HIDEOUT CAMP" over the path out of the camp (the lane mouth, south of the safe line);
--   * campfires and tents at candidate spots, each skipped when its spot is already taken by anything solid.

local Z = require(script.Parent.Z)
local K = Z.K
local rgb = Z.rgb

local C = {
	log = rgb(132, 92, 56),
	logDark = rgb(98, 66, 40),
	canvas = rgb(232, 220, 190),
	stone = rgb(150, 144, 136),
	ember = rgb(255, 150, 60),
	gold = rgb(240, 196, 70),
	sign = rgb(92, 60, 36),
}

local TOWER_H = 6.5
local TOWER_D = 2.2

local function pennant(f: Instance, top: Vector3, colour: Color3, outward: Vector3)
	Z.rod(f, "PennantPole", top, top + Vector3.new(0, 3.2, 0), 0.25, C.logDark, Enum.Material.Wood, true)
	local flag = K.part({
		name = "Pennant",
		parent = f,
		shape = "Wedge",
		size = Vector3.new(0.15, 1.4, 2.2),
		cf = CFrame.lookAt(top + Vector3.new(0, 2.5, 0) + outward * 1.1, top + Vector3.new(0, 2.5, 0) + outward * 3) * CFrame.Angles(math.pi / 2, 0, 0),
		color = colour,
		mat = Enum.Material.Fabric,
		deco = true,
	})
	flag.CastShadow = false
end

local function watchtower(f: Instance, foot: Vector3, roof: Color3)
	Z.cyl(f, "Log", foot + Vector3.new(0, TOWER_H / 2, 0), TOWER_D, TOWER_H, C.log, Enum.Material.Wood, true)
	Z.cyl(f, "Roof", foot + Vector3.new(0, TOWER_H + 0.5, 0), TOWER_D + 1.4, 1, roof, Enum.Material.SmoothPlastic, true)
	Z.cyl(f, "RoofTop", foot + Vector3.new(0, TOWER_H + 1.5, 0), TOWER_D * 0.7, 1, roof, Enum.Material.SmoothPlastic, true)
end

-- Is this box free of anything solid (other than the ground), with ground under all four of its corners?
local function free(cf: CFrame, size: Vector3, groundTop: number): boolean
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local p = cf * Vector3.new(c[1] * size.X / 2, 0, c[2] * size.Z / 2)
		local g = Z.ground(p.X, p.Z, groundTop + 20)
		if not g or math.abs(g - groundTop) > 0.6 then
			return false
		end
	end
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	for _, hit in workspace:GetPartBoundsInBox(cf, size, params) do
		if hit.Position.Y + hit.Size.Y / 2 > groundTop + 0.5 then
			return false
		end
	end
	return true
end

local function campfire(f: Instance, at: Vector3)
	Z.cyl(f, "FireRing", at + Vector3.new(0, 0.3, 0), 4, 0.6, C.stone, Enum.Material.Slate, true)
	for _, yaw in { 30, -30 } do
		Z.block(f, "FireLog", Vector3.new(0.6, 0.6, 3), CFrame.new(at + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, math.rad(yaw), 0), C.logDark, Enum.Material.Wood, true)
	end
	local embers = Z.block(f, "Embers", Vector3.new(1.4, 0.3, 1.4), at + Vector3.new(0, 0.8, 0), C.ember, Enum.Material.Neon, true)
	embers.CastShadow = false
	Z.flame(embers, 2.4)
	Z.light(embers, C.ember, 14, 1.2)
end

local function tent(f: Instance, at: Vector3, yaw: number, colour: Color3)
	local turn = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0)
	for _, side in { -1, 1 } do
		K.part({
			name = "TentSide",
			parent = f,
			shape = "Wedge",
			size = Vector3.new(6, 4.5, 3),
			cf = turn * CFrame.new(0, 2.25, side * 1.5) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
			color = if side > 0 then C.canvas else colour,
			mat = Enum.Material.Fabric,
			deco = true,
		})
	end
	Z.block(f, "TentFlap", Vector3.new(0.2, 3, 1.4), turn * CFrame.new(3.05, 1.5, 0), C.logDark, Enum.Material.Fabric, true)
end

local function build(): string
	local world = workspace:WaitForChild("World")
	local f = K.folder(world, "HideoutCamp", true)

	-- forts --------------------------------------------------------------------------------------------
	local forts = K.folder(f, "Forts")
	local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	local lots = 0
	for _, plot in plots:GetChildren() do
		local n = tonumber(plot.Name:match("^Plot(%d+)$"))
		local floor = plot:FindFirstChild("Floor")
		local gate = plot:FindFirstChild("Gate")
		if not (n and floor and floor:IsA("BasePart") and gate) then
			continue
		end
		local fort = K.folder(forts, plot.Name)
		local roof = K.LOT_COLOURS[((n - 1) % #K.LOT_COLOURS) + 1]
		local c = floor.Position
		local half = floor.Size.X / 2 - 0.3
		local foot = c.Y + floor.Size.Y / 2
		-- the gate side faces the avenue: the back is the side away from it
		local gatePost = gate:FindFirstChild("Post")
		local front = if gatePost and gatePost:IsA("BasePart") then math.sign(gatePost.Position.Z - c.Z) else 1
		for _, dx in { -1, 1 } do
			for _, dz in { -1, 1 } do
				local corner = Vector3.new(c.X + dx * half, foot, c.Z + dz * half)
				watchtower(fort, corner, roof)
				if dz ~= front then
					pennant(fort, corner + Vector3.new(0, TOWER_H + 2, 0), roof, Vector3.new(dx, 0, 0))
				end
			end
		end
		for _, post in gate:GetChildren() do
			if post.Name == "Post" and post:IsA("BasePart") then
				pennant(fort, post.Position + Vector3.new(0, post.Size.Y / 2, 0), roof, Vector3.new(math.sign(post.Position.X - c.X), 0, 0))
			end
		end
		lots += 1
	end

	-- camp arch over the lane mouth -----------------------------------------------------------------------
	local LN = K.L.lane
	local archZ = -70
	local arch = K.folder(f, "CampArch")
	local span = LN.rampW + 6
	for _, side in { -1, 1 } do
		Z.cyl(arch, "ArchLog", Vector3.new(LN.x + side * span / 2, LN.base + 6, archZ), 1.8, 12, C.log, Enum.Material.Wood, true)
		Z.cyl(arch, "ArchCap", Vector3.new(LN.x + side * span / 2, LN.base + 12.4, archZ), 2.4, 0.8, C.logDark, Enum.Material.Wood, true)
	end
	Z.block(arch, "ArchBeam", Vector3.new(span + 2, 1.2, 1.2), Vector3.new(LN.x, LN.base + 11.4, archZ), C.logDark, Enum.Material.Wood, true)
	Z.sign(arch, CFrame.new(LN.x, LN.base + 9.4, archZ), Vector3.new(16, 2.6, 0.4), "HIDEOUT CAMP", C.sign, C.gold)

	-- campfires + tents at free spots (spawn square edges, around the island) ----------------------------
	local props = K.folder(f, "Props")
	local placed, skipped = 0, 0
	for _, spot in { { -168, -64 }, { -146, -64 }, { 122, -64 }, { 122, 58 }, { -150, 58 } } do
		local at = Vector3.new(spot[1], LN.base, spot[2])
		if free(CFrame.new(at + Vector3.new(0, 2, 0)), Vector3.new(5, 3.6, 5), LN.base) then
			campfire(props, at)
			placed += 1
		else
			skipped += 1
		end
	end
	for k, spot in { { 128, -50, 90 }, { 128, 46, 90 }, { -170, 60, 0 }, { 112, 58, 0 } } do
		local at = Vector3.new(spot[1], 0, spot[2])
		if free(CFrame.new(at + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(spot[3]), 0), Vector3.new(7, 4.5, 7), 0.3) then
			tent(props, at, spot[3], K.LOT_COLOURS[k * 2])
			placed += 1
		else
			skipped += 1
		end
	end

	return ("Hideout Camp: %d parts (%d forts, %d props placed, %d spots taken)"):format(K.count(f), lots, placed, skipped)
end

return { build = build }
