-- Studio location: ServerStorage.Build027.B1_Ground (ModuleScript)
-- The island: grass slabs (one per rectangle of L.islandParts), curbs, cream paving (spawn square +
-- avenue), Main Street's street, the red parade lane, the plaza restyled into the same palette, a hedge
-- and rock underside traced round the whole outline, clouds far below, and the sea cut back so it
-- only surrounds the districts (Zones 2-6), never our island.
-- Surface tops: grass 0.0 < curb 0.2 < paving 0.3 < lane edge 0.4 < lane 0.5 (no two visible faces
-- share a height, so nothing z-fights).

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

return function(): string
	local root = K.folder(K.root(), "Ground", true)

	-- Island slabs (grass), 4 thick. Overlaps are hidden inside each other (same top, same colour).
	for i, r in L.islandParts do
		K.slab(root, "Island" .. i, r[1], r[2], r[3], r[4], L.grassTop, 4, C.Grass, Enum.Material.Plastic)
	end

	-- Paving with a 1-stud curb band underneath (visible as the edge where paving meets grass).
	local function paved(name, x0, x1, z0, z1, color)
		K.slab(root, name .. "Curb", x0 - 1, x1 + 1, z0 - 1, z1 + 1, L.curbTop, 0.4, C.Curb)
		return K.slab(root, name, x0, x1, z0, z1, L.pavingTop, 0.6, color or C.Paving)
	end
	paved("SpawnSquare", L.squareX[1], L.squareX[2], L.squareZ[1], L.squareZ[2], C.PavingWarm)
	paved("Avenue", L.avenueX[1], L.avenueX[2], L.stripZ[1], L.stripZ[2])
	local ms = L.ms
	paved("MainStreet", ms.pavingEnd, ms.x0, ms.streetZ[1], ms.streetZ[2], C.Stone)
	paved("Zone1Gateway", ms.x0, L.squareX[1], L.stripZ[1], L.stripZ[2], C.Stone)
	-- paths from the spawn square to the two reserved plots (between the stalls)
	for _, p in L.reservedHub do
		local north = p.Z > 0
		local z0 = if north then L.squareZ[2] else p.Z + 19.5
		local z1 = if north then p.Z - 19.5 else L.squareZ[1]
		paved(if north then "PathNorth" else "PathSouth", p.X - 3.5, p.X + 3.5, z0, z1, C.PavingWarm)
	end

	-- Hub.Floor: the home anchor ZoneProgress measures districts against (centre of the avenue).
	local hub = workspace.Hub
	local old = hub:FindFirstChild("Floor")
	if old then
		old:Destroy()
	end
	K.part({ name = "Floor", parent = hub, ghost = true, size = Vector3.new(8, 1, 8), pos = Vector3.new(-26, 0, L.laneZ) })

	-- The spawn square is the safe hub (PvP safe zone volume, invisible).
	local safe = K.part({
		name = "SafeHubVolume",
		parent = root,
		ghost = true,
		size = Vector3.new(L.squareX[2] - L.squareX[1], 24, L.squareZ[2] - L.squareZ[1]),
		pos = Vector3.new((L.squareX[1] + L.squareX[2]) / 2, 10, (L.squareZ[1] + L.squareZ[2]) / 2),
	})
	K.tag(safe, "PvPSafeZone")

	-- Parade lane: 16-stud red carpet on an 18-stud gold band, from the Zone 1 arch to the Vault.
	local lane = K.folder(root, "ParadeLane")
	local x0, x1 = L.zone1GateX + 1, L.plaza.X - 26 -- ends 2 studs short of the Vault step
	local hw = L.laneWidth / 2
	K.slab(lane, "LaneEdge", x0, x1, L.laneZ - hw - 1, L.laneZ + hw + 1, L.laneEdgeTop, 0.5, C.Trim)
	local carpet = K.slab(lane, "Lane", x0, x1, L.laneZ - hw, L.laneZ + hw, L.laneTop, 0.5, C.Carpet, Enum.Material.Fabric)
	carpet:SetAttribute("ParadeLane", true) -- Milestone 028 walks workers along this part
	for _, x in L.lotXs do -- thin gold pinstripes level with each pair of lots
		K.slab(lane, "Pinstripe", x - 0.4, x + 0.4, L.laneZ - hw, L.laneZ + hw, L.laneTop + 0.05, 0.1, C.TrimDark).CanCollide = false
	end

	-- Plaza restyled (ours): same palette, same trim; grass discs match the island so overlaps vanish.
	local fz = workspace.World.FutureZones.BillionairePlaza
	local recolour = {
		{ fz:FindFirstChild("ArenaFloor"), C.PavingWarm },
		{ fz:FindFirstChild("ArenaEdge"), C.Trim },
		{ fz:FindFirstChild("BypassRing"), C.Paving },
		{ fz:FindFirstChild("CentreSeal"), C.Trim },
	}
	local pi = workspace.World.Islands:FindFirstChild("PlazaIsland")
	for _, c in (pi and pi:GetChildren() or {}) do
		table.insert(recolour, { c, if c.Name:match("Cliff") then C.Rock else C.Grass })
	end
	for _, pair in recolour do
		local p = pair[1]
		if p and p:IsA("BasePart") then
			if p:GetAttribute("Pre027Color") == nil then
				p:SetAttribute("Pre027Color", p.Color)
				p:SetAttribute("Pre027Material", p.Material.Name)
			end
			p.Color = pair[2]
			p.Material = if p.Name:match("Cliff") then Enum.Material.Slate elseif pair[2] == C.Grass then Enum.Material.Plastic else Enum.Material.SmoothPlastic
		end
	end

	-- Hedge and rocks traced round the outline: walk every rectangle edge in 2-stud steps and keep
	-- the stretches whose outside neighbour is not island (the plaza side stays open).
	local edge = K.folder(root, "Edge")
	local rocks = K.folder(root, "Rocks")
	local hedges, rockCount = 0, 0
	local function run(a: Vector3, b: Vector3, inward: Vector3)
		hedges += 1
		local seg = K.bar(edge, "Hedge", a + inward * 1.3, b + inward * 1.3, 2.4, 2.6, 2.6, C.Hedge, Enum.Material.Plastic)
		seg.CanQuery = false
		for _, e in { -1, 1 } do
			K.part({
				name = "HedgeCap",
				parent = edge,
				shape = "Cylinder",
				size = Vector3.new(2.6, 2.6, 2.6),
				cf = seg.CFrame * CFrame.new(0, 0, e * seg.Size.Z / 2) * CFrame.Angles(0, 0, math.rad(90)),
				color = C.Hedge,
				mat = Enum.Material.Plastic,
				deco = true,
			})
		end
		local dir = (b - a).Unit
		for k = 18, (b - a).Magnitude, 36 do -- rocks under this stretch, half sticking out
			rockCount += 1
			local at = a + dir * k - inward * 2
			local cf = CFrame.lookAt(Vector3.new(at.X, -1.5, at.Z), Vector3.new(at.X, -1.5, at.Z) + dir)
			K.place(if rockCount % 4 == 0 then "M_Rock_B" else "M_Rock_A", cf, rocks, 0.9 + (rockCount % 3) * 0.12)
		end
	end
	for _, r in L.islandParts do
		local sides = { -- edge from a to b, and the inward direction
			{ Vector3.new(r[1], 0, r[4]), Vector3.new(r[2], 0, r[4]), Vector3.new(0, 0, -1) },
			{ Vector3.new(r[1], 0, r[3]), Vector3.new(r[2], 0, r[3]), Vector3.new(0, 0, 1) },
			{ Vector3.new(r[1], 0, r[3]), Vector3.new(r[1], 0, r[4]), Vector3.new(1, 0, 0) },
			{ Vector3.new(r[2], 0, r[3]), Vector3.new(r[2], 0, r[4]), Vector3.new(-1, 0, 0) },
		}
		for _, side in sides do
			local a, b, inward = side[1], side[2], side[3]
			local length = (b - a).Magnitude
			local dir = (b - a).Unit
			local start: Vector3? = nil
			local t = 0
			while t <= length + 0.01 do
				local p = a + dir * math.min(t, length)
				local out, inn = p - inward * 1.5, p + inward * 1.5
				local open = not K.onIsland(out.X, out.Z) and K.onIsland(inn.X, inn.Z)
				local last = t + 2 > length + 0.01
				if open and not start then
					start = p
				end
				if start and (not open or last) then
					local stop = if open then p else p - dir * 2
					if (stop - start).Magnitude > 3 then
						run(start, stop, inward)
					end
					start = nil
				end
				t += 2
			end
		end
	end

	-- Clouds far below (bright, soft, no collisions).
	local clouds = K.folder(root, "Clouds")
	local rng = Random.new(27)
	for _ = 1, 30 do
		local s = rng:NextNumber(70, 150)
		local cloud = K.part({
			name = "Cloud",
			parent = clouds,
			deco = true,
			color = C.Cloud,
			transparency = 0.12,
			size = Vector3.new(s, s * 0.32, s * 0.8),
			cf = CFrame.new(rng:NextNumber(-520, 160), rng:NextNumber(-170, -140), rng:NextNumber(-260, 250)),
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = cloud
	end

	-- The sea now only surrounds the districts east of the plaza; a rock skirt finishes its west edge.
	local sea = workspace:FindFirstChild("Baseplate")
	if sea and sea:GetAttribute("Pre027Size") == nil then
		sea:SetAttribute("Pre027Size", sea.Size)
		sea:SetAttribute("Pre027Position", sea.Position)
		local westEdge = 112
		local east = sea.Position.X + sea.Size.X / 2
		sea.Size = Vector3.new(east - westEdge, sea.Size.Y, sea.Size.Z)
		sea.Position = Vector3.new((east + westEdge) / 2, sea.Position.Y, sea.Position.Z)
	end
	if sea then
		local top = sea.Position.Y + sea.Size.Y / 2
		local skirtX = sea.Position.X - sea.Size.X / 2 - 2
		K.part({
			name = "SeaSkirt",
			parent = root,
			size = Vector3.new(4, 70, sea.Size.Z),
			pos = Vector3.new(skirtX, top - 35, sea.Position.Z),
			color = C.Rock,
			mat = Enum.Material.Slate,
			deco = true,
		})
	end
	return ("ground: %d parts (hedge runs %d, rocks %d, clouds %d)"):format(K.count(root), hedges, rockCount, #clouds:GetChildren())
end
