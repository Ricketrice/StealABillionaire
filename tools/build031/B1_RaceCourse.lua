-- Studio location: ServerStorage.Build031.B1_RaceCourse (ModuleScript)
-- Milestone 031 build step (Edit mode, run from the command bar / MCP; re-runnable):
-- builds ServerStorage.RaceCourse031, the Royale Race course template read by RaceService.
--   Visible (cloned into Workspace.World.VelocityRoyale.RaceCourse while the race is on):
--     StartPad (glowing pad on the grid), Sign (two-sided board on top of the start gantry; RaceService
--     adds the text), OddsBoard (two-sided capsule-odds board on the infield stand beside the pad, facing
--     the start straight players walk up), Name1..3 (anchors above the podium steps for the top-3 names),
--     SafeVolume (invisible, tagged PvPSafeZone: no bats on the circuit while the race is on), Walls
--     (032: invisible walls along both track edges, following the circuit's inner/outer barrier chains
--     and the pit wall; RaceService puts them in a collision group that only racers collide with).
--   Server only (stay in ServerStorage): Gates.Finish + Gates.CP1..CP5, boxes across the track in
--     race order. Track direction: from the grid (north) across the start line heading +Z.
-- The centre line was measured from the circuit's inner/outer barriers (lap ~144 studs).

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Y = 72.3 -- track surface (BillionaireHillsIsland.Land3 top)
local GOLD = Color3.fromRGB(240, 186, 58)
local NAVY = Color3.fromRGB(40, 52, 92)

-- Centre line in race order, starting at the start/finish line.
local LINE = {
	Vector3.new(-115.5, Y, -952), -- start / finish line
	Vector3.new(-115.5, Y, -935),
	Vector3.new(-113, Y, -927.5),
	Vector3.new(-105, Y, -925.6), -- CP1
	Vector3.new(-97, Y, -928),
	Vector3.new(-86, Y, -926.6),
	Vector3.new(-79, Y, -931), -- CP2
	Vector3.new(-76.3, Y, -938.7),
	Vector3.new(-78, Y, -946),
	Vector3.new(-82.4, Y, -956), -- CP3
	Vector3.new(-85, Y, -966.4),
	Vector3.new(-95.5, Y, -972), -- CP4
	Vector3.new(-104, Y, -972),
	Vector3.new(-113.5, Y, -965.5), -- CP5
	Vector3.new(-115.5, Y, -958),
}
local CHECKPOINTS = { 4, 7, 10, 12, 14 } -- indexes into LINE
local GATE = Vector3.new(15, 16, 8) -- across, up, along the track

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end
local function ghost(p: BasePart)
	p.Transparency = 1
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
end

return function()
	local old = ServerStorage:FindFirstChild("RaceCourse031")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "RaceCourse031"

	-- Gates (server only) ------------------------------------------------------------------------------
	local gates = Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = root
	local function gate(name: string, index: number, order: number)
		local here, nextPoint = LINE[index], LINE[index % #LINE + 1]
		local prev = LINE[(index - 2) % #LINE + 1]
		local dir = ((nextPoint - prev) * Vector3.new(1, 0, 1)).Unit -- along the track at this point
		local centre = here + Vector3.new(0, GATE.Y / 2 - 1, 0)
		local g = part({ Name = name, Size = Vector3.new(GATE.X, GATE.Y, GATE.Z), CFrame = CFrame.lookAt(centre, centre + dir) })
		ghost(g)
		g:SetAttribute("Order", order) -- 0 = finish line, 1.. = checkpoints in race order
		g.Parent = gates
	end
	gate("Finish", 1, 0)
	for order, index in CHECKPOINTS do
		gate("CP" .. order, index, order)
	end
	-- the centre line, for tests (a bot runs it) and the lap measurement
	local line = Instance.new("Folder")
	line.Name = "Line"
	line.Parent = root
	for i, point in LINE do
		local a = Instance.new("Vector3Value")
		a.Name = ("P%02d"):format(i)
		a.Value = point
		a.Parent = line
	end

	-- Start pad: on the grid just before the line ---------------------------------------------------------
	local pad = part({
		Name = "StartPad",
		Size = Vector3.new(9, 0.3, 6.5),
		CFrame = CFrame.new(-115.5, Y + 0.15, -957.6),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	pad.Parent = root
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = GOLD, 12, 1.5
	light.Parent = pad
	-- the zone the server counts as "on the pad" (a little taller than the pad itself)
	pad:SetAttribute("PadHeight", 8)

	-- Sign: on top of the start gantry, readable from the pad and from the approach ------------------------
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(14, 8, 0.4),
		CFrame = CFrame.new(-115.7, 88.6, -950.7),
		Color = NAVY,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	sign.Parent = root
	local trim = part({
		Name = "SignTrim",
		Size = Vector3.new(14.6, 8.6, 0.3),
		CFrame = sign.CFrame,
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	trim.Parent = root

	-- Odds board (032): on top of the infield stand just east of the pad, two-sided, facing the start
	-- straight (players walk up it from the plaza heading -Z; racers on the pad see it to their left).
	local oddsAt = CFrame.lookAt(Vector3.new(-104, 91.4, -962), Vector3.new(-112, 91.4, -930))
	local odds = part({
		Name = "OddsBoard",
		Size = Vector3.new(16, 10, 0.4),
		CFrame = oddsAt,
		Color = NAVY,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	odds.Parent = root
	local oddsTrim = part({
		Name = "OddsTrim",
		Size = Vector3.new(16.6, 10.6, 0.3),
		CFrame = oddsAt,
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	oddsTrim.Parent = root
	for _, x in { -6.5, 6.5 } do
		local post = part({
			Name = "OddsPost",
			Size = Vector3.new(0.6, 9.6, 0.6),
			CFrame = oddsAt * CFrame.new(x, -9.8, 0), -- down to the stand's seating
			Color = GOLD,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		post.Parent = root
	end

	-- Walls (032): along both track edges. The edges are the circuit's barrier chains (Barrier_Inner_01..20,
	-- Barrier_Outer_02..26 in order round the track) and the pit wall on the start straight.
	local circuit = workspace.World.VelocityRoyale.VelocityRoyale_016B.Circuit
	local function chain(prefix: string): { Vector3 }
		local found = {}
		for _, b in circuit.Barriers:GetChildren() do
			local n = tonumber(b.Name:match("^Barrier_" .. prefix .. "_(%d+)$"))
			if n and b:IsA("BasePart") then
				table.insert(found, { n = n, p = b.Position })
			end
		end
		table.sort(found, function(a, b)
			return a.n < b.n
		end)
		local pts = {}
		for _, f in found do
			table.insert(pts, Vector3.new(f.p.X, Y, f.p.Z))
		end
		return pts
	end
	local inner, outer = chain("Inner"), chain("Outer")
	local pit = circuit.PitWall.Wall :: BasePart
	-- the pit wall closes the outer edge between the last outer barrier (north-west) and the first (south-west)
	table.insert(outer, Vector3.new(pit.Position.X, Y, pit.Position.Z - pit.Size.Z / 2))
	table.insert(outer, Vector3.new(pit.Position.X, Y, pit.Position.Z + pit.Size.Z / 2))
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = root
	local WALL_HEIGHT = 12
	local wallSegments = {}
	for _, ring in { { "I", inner }, { "O", outer } } do
		local pts = ring[2]
		for i, a in pts do
			local b = pts[i % #pts + 1]
			local mid = (a + b) / 2 + Vector3.new(0, WALL_HEIGHT / 2, 0)
			local w = part({
				Name = ("Wall_%s%02d"):format(ring[1], i),
				Size = Vector3.new(1, WALL_HEIGHT, (b - a).Magnitude + 1),
				CFrame = CFrame.lookAt(mid, mid + (b - a)),
			})
			w.Transparency = 1
			w.CanCollide, w.CanTouch, w.CanQuery = true, false, false
			w.Parent = walls
			table.insert(wallSegments, { a, b })
		end
	end

	-- Podium names: above the 1st / 2nd / 3rd steps of WinnersPodium -------------------------------------
	local steps = { { -159.2, 80.4 }, { -163.4, 79.4 }, { -155.0, 78.6 } }
	for i, s in steps do
		local anchor = part({ Name = "Name" .. i, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(s[1], s[2], -928.3) })
		ghost(anchor)
		anchor.Parent = root
	end

	-- Safe volume over the circuit (bats off on the track while the race is on) ---------------------------
	local safe = part({ Name = "SafeVolume", Size = Vector3.new(62, 30, 70), CFrame = CFrame.new(-95.5, Y + 13, -948.5) })
	ghost(safe)
	CollectionService:AddTag(safe, "PvPSafeZone")
	safe.Parent = root

	root.Parent = ServerStorage
	local length = 0
	for i, point in LINE do
		length += (LINE[i % #LINE + 1] - point).Magnitude
	end
	-- closest the centre line comes to a wall (a racer is ~2 studs wide)
	local function segDist(p: Vector3, a: Vector3, b: Vector3): number
		local ab = (b - a) * Vector3.new(1, 0, 1)
		local t = math.clamp(((p - a) * Vector3.new(1, 0, 1)):Dot(ab) / ab:Dot(ab), 0, 1)
		return ((a + ab * t - p) * Vector3.new(1, 0, 1)).Magnitude
	end
	local closest = math.huge
	for i, a in LINE do
		local b = LINE[i % #LINE + 1]
		for k = 0, 10 do
			local p = a:Lerp(b, k / 10)
			for _, seg in wallSegments do
				closest = math.min(closest, segDist(p, seg[1], seg[2]))
			end
		end
	end
	return ("RaceCourse031 built: %d gates, centre line %.1f studs, %d walls (inner %d, outer %d), centre line >= %.1f studs from a wall"):format(
		#gates:GetChildren(),
		length,
		#walls:GetChildren(),
		#inner,
		#outer,
		closest
	)
end
