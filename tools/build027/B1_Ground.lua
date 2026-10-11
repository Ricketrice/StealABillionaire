-- Studio location: ServerStorage.Build027.B1_Ground (ModuleScript)
-- The island: grass slab, curbs, cream paving (spawn square + avenue), the red parade lane, the
-- plaza restyled into the same palette, hedge edge, rock underside, clouds far below, and the sea
-- cut back so it only surrounds the districts (Zones 2-6), never our island.
-- Surface tops: grass 0.0 < curb 0.2 < paving 0.3 < lane edge 0.4 < lane 0.5 (no two visible faces
-- share a height, so nothing z-fights).

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

return function(): string
	local root = K.folder(K.root(), "Ground", true)
	local I = L.island

	-- Island slab (grass), 4 thick.
	K.slab(root, "Island", I.x0, I.x1, I.z0, I.z1, L.grassTop, 4, C.Grass, Enum.Material.Plastic)

	-- Paving with a 1-stud curb band underneath (visible as the edge where paving meets grass).
	local function paved(name, x0, x1, z0, z1, color)
		K.slab(root, name .. "Curb", x0 - 1, x1 + 1, z0 - 1, z1 + 1, L.curbTop, 0.4, C.Curb)
		return K.slab(root, name, x0, x1, z0, z1, L.pavingTop, 0.6, color or C.Paving)
	end
	local square = paved("SpawnSquare", L.squareX[1], L.squareX[2], L.squareZ[1], L.squareZ[2], C.PavingWarm)
	local avenue = paved("Avenue", L.avenueX[1], L.avenueX[2], L.stripZ[1], L.stripZ[2])
	-- Main Street (Zone 1) street paving: the NPC area plus a frame for the shopfronts.
	local ms = L.mainStreet
	paved("MainStreetPaving", ms.X - 36, ms.X + 36, ms.Z - 37, ms.Z + 37, C.Stone)
	paved("Zone1Gateway", ms.X + 36, L.squareX[1], L.stripZ[1], L.stripZ[2], C.Stone)

	-- Hub.Floor: the home anchor ZoneProgress measures districts against (centre of the avenue).
	local hub = workspace.Hub
	local old = hub:FindFirstChild("Floor")
	if old then
		old:Destroy()
	end
	K.part({ name = "Floor", parent = hub, ghost = true, size = Vector3.new(8, 1, 8), pos = Vector3.new(-26, 0, L.laneZ) })

	-- The spawn square is the safe hub (PvP safe zone volume, invisible).
	local safe = K.part({ name = "SafeHubVolume", parent = root, ghost = true,
		size = Vector3.new(L.squareX[2] - L.squareX[1], 24, L.squareZ[2] - L.squareZ[1]),
		pos = Vector3.new((L.squareX[1] + L.squareX[2]) / 2, 10, (L.squareZ[1] + L.squareZ[2]) / 2) })
	K.tag(safe, "PvPSafeZone")

	-- Parade lane: 15-stud red carpet on a 17-stud gold band, from the Zone 1 gate to the Vault.
	local lane = K.folder(root, "ParadeLane")
	local x0, x1 = L.zone1GateX + 1, L.plaza.X - 26 -- ends 2 studs short of the Vault step
	K.slab(lane, "LaneEdge", x0, x1, L.laneZ - 8.5, L.laneZ + 8.5, L.laneEdgeTop, 0.5, C.Trim)
	local carpet = K.slab(lane, "Lane", x0, x1, L.laneZ - 7.5, L.laneZ + 7.5, L.laneTop, 0.5, C.Carpet, Enum.Material.Fabric)
	carpet:SetAttribute("ParadeLane", true) -- Milestone 028 walks workers along this part
	-- thin gold pinstripes every 41 studs, under each lot pair (reads as a carpet runner, not a road)
	for _, x in L.lotXs do
		K.slab(lane, "Pinstripe", x - 0.4, x + 0.4, L.laneZ - 7.5, L.laneZ + 7.5, L.laneTop + 0.05, 0.1, C.TrimDark).CanCollide = false
	end

	-- Plaza restyled (ours): same palette, same trim; grass discs match the island so overlaps vanish.
	local fz = workspace.World.FutureZones.BillionairePlaza
	local recolour = {
		{ fz:FindFirstChild("ArenaFloor"), C.PavingWarm }, { fz:FindFirstChild("ArenaEdge"), C.Trim },
		{ fz:FindFirstChild("BypassRing"), C.Paving }, { fz:FindFirstChild("CentreSeal"), C.Trim },
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

	-- Edge: low hedge along the north, south and west sides (the east side opens into the plaza).
	local edge = K.folder(root, "Edge")
	local function hedge(a: Vector3, b: Vector3)
		local seg = K.bar(edge, "Hedge", a, b, 2.4, 2.6, 2.6, C.Hedge, Enum.Material.Plastic)
		seg.CanQuery = false
		return seg
	end
	local hz0, hz1, hx0 = I.z0 + 1.4, I.z1 - 1.4, I.x0 + 1.4
	local plazaEdgeX = 104
	for x = hx0, plazaEdgeX - 1, 50 do
		local xe = math.min(x + 50, plazaEdgeX)
		hedge(Vector3.new(x, 0, hz1), Vector3.new(xe, 0, hz1))
		hedge(Vector3.new(x, 0, hz0), Vector3.new(xe, 0, hz0))
	end
	hedge(Vector3.new(hx0, 0, hz0), Vector3.new(hx0, 0, hz1))
	-- the north/south hedges bend round to meet the plaza island's shore
	for _, s in { 1, -1 } do
		local z = if s > 0 then hz1 else hz0
		local a = Vector3.new(plazaEdgeX, 0, z)
		local b = Vector3.new(128, 0, L.plaza.Z + s * 57)
		hedge(a, b)
	end
	for _, h in edge:GetChildren() do -- rounded caps hide the joints
		for _, e in { -1, 1 } do
			K.part({ name = "HedgeCap", parent = edge, shape = "Cylinder", size = Vector3.new(2.6, 2.6, 2.6), cf = h.CFrame * CFrame.new(0, 0, e * h.Size.Z / 2) * CFrame.Angles(0, 0, math.rad(90)), color = C.Hedge, mat = Enum.Material.Plastic, deco = true })
		end
	end

	-- Rock underside: cones along the edges, half sticking out so they show from the island edge.
	local rocks = K.folder(root, "Rocks")
	local n = 0
	local function rock(x, z, big, turn)
		n += 1
		K.place(if big then "M_Rock_B" else "M_Rock_A", CFrame.new(x, -1.5, z) * CFrame.Angles(0, turn, 0), rocks, 0.9 + (n % 3) * 0.12)
	end
	for x = I.x0 + 14, 100, 36 do
		rock(x, I.z1 - 6, n % 4 == 0, 0)
		rock(x + 18, I.z0 + 6, n % 4 == 1, math.pi)
	end
	for z = I.z0 + 16, I.z1 - 10, 34 do
		rock(I.x0 + 6, z, true, math.pi / 2)
	end

	-- Clouds far below (bright, soft, no collisions).
	local clouds = K.folder(root, "Clouds")
	local rng = Random.new(27)
	for _ = 1, 26 do
		local s = rng:NextNumber(70, 150)
		local cloud = K.part({ name = "Cloud", parent = clouds, deco = true, color = C.Cloud, transparency = 0.12,
			size = Vector3.new(s, s * 0.32, s * 0.8), cf = CFrame.new(rng:NextNumber(-420, 160), rng:NextNumber(-170, -140), rng:NextNumber(-220, 210)) })
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
		K.part({ name = "SeaSkirt", parent = root, size = Vector3.new(4, 70, sea.Size.Z), pos = Vector3.new(skirtX, top - 35, sea.Position.Z), color = C.Rock, mat = Enum.Material.Slate, deco = true })
	end

	return ("ground: %d parts (rocks %d, clouds %d, hedge %d); square %s; avenue %s"):format(K.count(root), n, #clouds:GetChildren(), #edge:GetChildren(), square.Name, avenue.Name)
end
