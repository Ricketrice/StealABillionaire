-- Studio location: ServerStorage.Build027.B8_Lane (ModuleScript)
-- 030 The Rising Lane. Step 1 (once, attribute Moved030 on World.SkyCity): clears what the lane replaces,
-- moves Main Street (terrace 1) and the whole Velocity Royale strip (terrace 6) as rigid blocks.
-- Step 2 (re-runnable, rebuilds World.SkyCity.Lane): safe line, ramps, portal stops, landing, clouds.
-- Coordinates: Kit.L.lane. North = -Z.

local K = require(script.Parent.Kit)
local C, L = K.C, K.L
local LN = L.lane

local SKY = workspace.World

local function bounds(part: BasePart): (number, number, number, number)
	local h = part.Size / 2
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, 0, h.Z * sz))
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
	end
	return minX, maxX, minZ, maxZ
end

-- Top-level things under a folder tree: models (not inside another model) and loose parts.
local function items(folder: Instance): { Instance }
	local list = {}
	for _, d in folder:GetDescendants() do
		if (d:IsA("Model") or d:IsA("BasePart")) and not d.Parent:IsA("Model") then
			table.insert(list, d)
		end
	end
	return list
end

local function pos(inst: Instance): Vector3
	return if inst:IsA("BasePart") then inst.Position else (inst :: Model):GetPivot().Position
end

local function shift(items: { Instance }, T: CFrame): number
	local n = 0
	for _, inst in items do
		local list = inst:GetDescendants()
		table.insert(list, inst)
		for _, d in list do
			if d:IsA("BasePart") then
				d.CFrame = T * d.CFrame
				n += 1
			end
		end
	end
	return n
end

local function rail(parent: Instance, a: Vector3, b: Vector3, h: number, w: number, colour: Color3, name: string?)
	local mid = (a + b) / 2 + Vector3.new(0, h / 2, 0)
	return K.part({
		name = name or "Rail",
		parent = parent,
		size = Vector3.new(w, h, (b - a).Magnitude),
		cf = CFrame.lookAt(mid, mid + (b - a)),
		color = colour,
	})
end

-- A cream wedge ramp rising toward -Z from (zStart, yStart) to (zEnd, yEnd), with rails and gold edges.
local function ramp(parent: Instance, zStart: number, yStart: number, zEnd: number, yEnd: number, rocks: Folder)
	local x, w = LN.x, LN.rampW
	local len, rise = zStart - zEnd, yEnd - yStart
	local m = Instance.new("Model")
	m.Name = "Ramp"
	K.part({
		name = "Wedge",
		parent = m,
		shape = "Wedge",
		size = Vector3.new(w, rise, len),
		cf = CFrame.new(x, yStart + rise / 2, (zStart + zEnd) / 2) * CFrame.Angles(0, math.pi, 0),
		color = C.Paving,
	})
	for _, side in { -1, 1 } do
		local ex = x + side * (w / 2 - 0.5)
		local a, b = Vector3.new(ex, yStart, zStart), Vector3.new(ex, yEnd, zEnd)
		rail(m, a, b, 3, 1, C.Navy)
		local ox = x + side * (w / 2 - 2)
		local stripe = rail(m, Vector3.new(ox, yStart + 0.05, zStart), Vector3.new(ox, yEnd + 0.05, zEnd), 0.2, 0.8, C.Trim, "Edge")
		stripe.CanCollide, stripe.CanQuery, stripe.CanTouch = false, false, false
	end
	-- a stone block under the high end hides the hollow
	K.place("M_Rock_A", CFrame.new(x, yEnd - 17, zEnd + 8) * CFrame.Angles(0, math.rad(37 * math.abs(zEnd) % 180), 0), rocks, 1.15)
	m.Parent = parent
	return m
end

local function stopRails(parent: Instance, y: number, zNorth: number, zSouth: number, w: number)
	local x = LN.x
	local half, lane = w / 2, LN.rampW / 2
	for _, side in { -1, 1 } do
		rail(parent, Vector3.new(x + side * (half - 0.5), y, zSouth), Vector3.new(x + side * (half - 0.5), y, zNorth), 3, 1, C.Navy)
		for _, z in { zNorth, zSouth } do -- ends beside the ramp mouth
			local a, b = Vector3.new(x + side * (half - 0.5), y, z), Vector3.new(x + side * (lane + 0.5), y, z)
			rail(parent, a, b, 3, 1, C.Navy)
		end
	end
end

-- Where the climb ends: z of the last ramp's top and the ground height of the Royale landing.
local function royaleSpot(): (number, number)
	local z = LN.archZ - LN.streetLength
	for _, stop in LN.stops do
		z -= LN.rampLen + stop.len
	end
	z -= LN.rampLen
	return z, LN.base + LN.rise * (#LN.stops + 2) - 0.3
end

local function hedge(parent: Instance, a: Vector3, b: Vector3, lift: number?)
	local h = K.bar(parent, "Hedge", a, b, 2.4, 2.6 + (lift or 0), 2.6, C.Hedge, Enum.Material.Plastic)
	h.CanQuery = false
	return h
end

local function lampSign(parent: Instance, cf: CFrame, size: Vector3, text: string, colour: Color3, textColour: Color3)
	local sign = K.part({ name = "Sign", parent = parent, size = size, cf = cf, color = colour })
	K.text(sign, Enum.NormalId.Front, text, textColour)
	K.text(sign, Enum.NormalId.Back, text, textColour)
	return sign
end

-- Step 1 ------------------------------------------------------------------------------------------------
local function moveBlocks(): string
	local sky = K.root()
	if sky:GetAttribute("Moved030") then
		return "already moved"
	end
	local ground, dressing = sky.Ground, sky.Dressing
	local report = {}

	-- what the lane replaces: reserved plot 2 + its path, the boss plot, Zone 1 gateway, trees in the lane mouth
	local gone = 0
	local function kill(inst: Instance?)
		if inst then
			inst:Destroy()
			gone += 1
		end
	end
	kill(sky.ReservedPlots:FindFirstChild("Reserved2"))
	kill(sky.ReservedPlots:FindFirstChild("BossVaultPlot"))
	for _, name in { "PathSouth", "PathSouthCurb", "Zone1Gateway", "Zone1GatewayCurb" } do
		kill(ground:FindFirstChild(name))
	end
	for _, tree in items(dressing) do
		local at = pos(tree)
		if at.X > -174 and at.X < -141 and at.Z < -60.5 and at.Z > -118 then
			kill(tree)
		end
	end
	-- the bump-out's north hedge (the lane leaves through it)
	for _, h in ground.Edge:GetChildren() do
		if h.Name == "Hedge" and math.abs(h.Position.Z + 115) < 1.5 and math.abs(h.Position.X + 157) < 1.5 then
			kill(h)
		end
	end

	-- terrace 1: Main Street as one rigid block, rotated to run north, +12 up
	local arch = Vector3.new(-179, 0, -4)
	local T1 = CFrame.new(LN.x, LN.rise, LN.archZ) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(-arch)
	local set: { Instance } = {}
	local function inMS(p: Vector3): boolean
		return p.X < -175.5 and p.Z > -59 and p.Z < 53
	end
	for _, name in { "Island4", "MainStreet", "MainStreetCurb" } do
		table.insert(set, ground[name])
	end
	for _, folder in { ground.Edge, ground.Rocks } do
		for _, c in items(folder) do
			if inMS(pos(c)) then
				table.insert(set, c)
			end
		end
	end
	table.insert(set, sky.MainStreet)
	table.insert(set, sky.Hub.Zone1Arch)
	for _, c in items(dressing) do
		if inMS(pos(c)) then
			table.insert(set, c)
		end
	end
	table.insert(set, workspace.Zones.MainStreet)
	table.insert(report, ("Main Street block: %d parts"):format(shift(set, T1)))

	-- terrace 6: the plaza gate + bridge + Velocity Royale strip as one block, turned so the gate faces north
	local W = SKY
	local gate = W.FutureZones.Zone6_BillionaireHills.Gate
	local barrier = gate.Barrier
	local plaza = W.FutureZones.BillionairePlaza.ArenaFloor.Position
	local out = Vector3.new(barrier.Position.X - plaza.X, 0, barrier.Position.Z - plaza.Z).Unit
	local topZ, groundY = royaleSpot()
	local R = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1)) * CFrame.lookAt(Vector3.zero, out):Inverse()
	local gateOld = Vector3.new(barrier.Position.X, 0, barrier.Position.Z)
	local T6 = CFrame.new(LN.x, groundY, topZ - LN.gateOffset) * R * CFrame.new(-gateOld)
	local set6: { Instance } = { W.VelocityRoyale, W.BillionaireCity.Zone6Plaza, W.FutureZones.Zone6_BillionaireHills }
	table.insert(set6, W.Islands.BillionaireHillsIsland)
	table.insert(set6, W.Bridges.BillionaireHillsBridge)
	table.insert(set6, W.DistrictArchitecture.BillionaireHills)
	table.insert(set6, W.LockedZoneEntrances.BillionaireHills)
	table.insert(set6, workspace.Zones.BillionaireHills)
	for _, g in W.BridgeGuards:GetChildren() do
		if g.Name:find("BillionaireHills") then
			table.insert(set6, g)
		end
	end
	table.insert(report, ("Royale block: %d parts"):format(shift(set6, T6)))
	-- Zone 6 is ours and its gate is the top of the lane: open it
	barrier.CanCollide, barrier.Transparency = false, 1
	local plate = gate:FindFirstChild("LockPlate")
	if plate and plate:IsA("BasePart") then
		plate.CanCollide, plate.Transparency = false, 1
		for _, d in plate:GetDescendants() do
			if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
	end
	sky:SetAttribute("Moved030", true)
	table.insert(report, ("removed %d old pieces"):format(gone))
	return table.concat(report, "; ")
end

-- Step 2 ------------------------------------------------------------------------------------------------
local function buildLane(): string
	local sky = K.root()
	local lane = K.folder(sky, "Lane", true)
	local rocks = K.folder(lane, "Rocks")
	local edge = K.folder(lane, "Edge")
	local x, rw = LN.x, LN.rampW
	local base = LN.base

	-- paving from the spawn square to the line, 24 wide, on a curb
	K.slab(lane, "MouthCurb", x - rw / 2 - 1, x + rw / 2 + 1, LN.rampAStartZ, L.squareZ[1] - 0.5, L.curbTop, 0.4, C.Curb)
	K.slab(lane, "MouthPaving", x - rw / 2, x + rw / 2, LN.rampAStartZ, L.squareZ[1] - 0.5, base, 0.6, C.Paving)

	-- SAFE ZONE: gold line, banner, invisible volume (PvPSafeZone) from the spawn square to the line
	local lineZ = LN.safeLineZ
	K.slab(lane, "SafeLine", x - rw / 2 - 1, x + rw / 2 + 1, lineZ - 2, lineZ + 2, base + 0.1, 0.2, C.Trim)
	local line2 = K.slab(lane, "SafeLineWide", -180, -134, lineZ - 0.5, lineZ + 0.5, base + 0.05, 0.1, C.Trim)
	line2.CanCollide = false
	for _, side in { -1, 1 } do
		K.part({ name = "BannerPost", parent = lane, size = Vector3.new(1.4, 12, 1.4), pos = Vector3.new(x + side * 14, 6, lineZ), color = C.Trim })
	end
	lampSign(lane, CFrame.lookAt(Vector3.new(x, 11.5, lineZ), Vector3.new(x, 11.5, lineZ - 10)), Vector3.new(26, 4, 0.8), "SAFE ZONE ENDS HERE", C.Navy, C.Trim)
	-- (the sign's back faces the bases)
	local volume = K.part({
		name = "SafeLaneVolume",
		parent = lane,
		ghost = true,
		size = Vector3.new(46, 24, (L.squareZ[1] - 0.5) - (lineZ - 2)),
		pos = Vector3.new(-157, 10, ((L.squareZ[1] - 0.5) + (lineZ - 2)) / 2),
	})
	K.tag(volume, "PvPSafeZone")

	-- hub west edge, closed where Main Street used to join
	hedge(edge, Vector3.new(-174.7, 0, -58), Vector3.new(-174.7, 0, 52))
	for i, z in { -40, 0, 36 } do
		K.place(if i == 2 then "M_Rock_B" else "M_Rock_A", CFrame.new(-177, -1.5, z) * CFrame.Angles(0, math.pi / 2, 0), rocks, 0.9)
	end
	-- bump-out north end: hedge either side of the ramp mouth
	for _, side in { -1, 1 } do
		local a = Vector3.new(x + side * (rw / 2 + 0.5), 0, -114.7)
		local b = Vector3.new(x + side * 23, 0, -114.7)
		hedge(edge, a, b)
	end

	-- terrace 1 edges: south edge either side of the ramp, north edge either side of the ramp to terrace 2
	local isl = sky.Ground:FindFirstChild("Island4")
	if isl then
		local minX, maxX, minZ, maxZ = bounds(isl :: BasePart)
		for _, side in { -1, 1 } do
			local far = if side < 0 then minX + 1 else maxX - 1
			hedge(edge, Vector3.new(x + side * (rw / 2 + 0.5), 0, maxZ - 1.3), Vector3.new(far, 0, maxZ - 1.3), LN.rise)
		end
		for _, h in sky.Ground.Edge:GetChildren() do -- the old north-edge hedge crosses the ramp mouth: split it
			if h.Name == "Hedge" and h:IsA("BasePart") and h.Size.Z > 90 and math.abs(h.CFrame.LookVector.X) > 0.9 and math.abs(h.Position.Z - (minZ + 1.3)) < 2 then
				local cx0, cx1 = h.Position.X - h.Size.Z / 2, h.Position.X + h.Size.Z / 2
				h:Destroy()
				for _, side in { -1, 1 } do
					local far = if side < 0 then cx0 else cx1
					hedge(edge, Vector3.new(x + side * (rw / 2 + 0.5), 0, minZ + 1.3), Vector3.new(far, 0, minZ + 1.3), LN.rise)
				end
				break
			end
		end
	end

	-- the climb ----------------------------------------------------------------------------------------
	local y = base
	local z = LN.rampAStartZ
	ramp(lane, z, y, LN.archZ, base + LN.rise, rocks)
	y = base + LN.rise
	z = LN.archZ - LN.streetLength -- end of Main Street's paving
	local startMarks: { [string]: CFrame } = {}
	startMarks.MainStreet = CFrame.lookAt(Vector3.new(x, y + 3, LN.archZ - 4), Vector3.new(x, y + 3, LN.archZ - 20))
	for i, stop in LN.stops do
		ramp(lane, z, y, z - LN.rampLen, y + LN.rise, rocks)
		z -= LN.rampLen
		y += LN.rise
		local zN, zS = z - stop.len, z
		local sf = Instance.new("Folder")
		sf.Name = "Stop" .. (i + 1) .. "_" .. stop.id
		sf:SetAttribute("ZoneId", stop.id)
		sf:SetAttribute("Terrace", i + 1)
		sf:SetAttribute("TopY", y)
		sf:SetAttribute("SouthZ", zS)
		sf:SetAttribute("NorthZ", zN)
		sf.Parent = lane
		local zc = (zN + zS) / 2
		K.slab(sf, "Island", x - stop.w / 2, x + stop.w / 2, zN, zS, y - 0.3, 4, C.Grass, Enum.Material.Plastic)
		K.slab(sf, "Paving", x - rw / 2, x + rw / 2, zN, zS, y, 0.6, C.Paving)
		K.slab(sf, "Accent", x - rw / 2, x + rw / 2, zc - 2, zc + 2, y + 0.05, 0.2, stop.colour).CanCollide = false
		stopRails(sf, y, zN, zS, stop.w)
		K.place("M_Rock_B", CFrame.new(x, y - 20, zc) * CFrame.Angles(0, math.rad(53 * i), 0), rocks, 1.2)
		K.place("M_Rock_A", CFrame.new(x + 10, y - 17, zc - 8) * CFrame.Angles(0, math.rad(97 * i), 0), rocks, 0.9)
		-- portal on the west side: pad, arch, glow, sign, prompt
		local px = x - 19.5
		K.part({
			name = "PadBase",
			parent = sf,
			shape = "Cylinder",
			size = Vector3.new(0.4, 14, 14),
			cf = CFrame.new(px, y + 0.2, zc) * CFrame.Angles(0, 0, math.rad(90)),
			color = C.Trim,
			deco = true,
		})
		K.part({
			name = "Pad",
			parent = sf,
			shape = "Cylinder",
			size = Vector3.new(0.3, 11.6, 11.6),
			cf = CFrame.new(px, y + 0.35, zc) * CFrame.Angles(0, 0, math.rad(90)),
			color = stop.colour,
			deco = true,
		})
		for _, s in { -1, 1 } do
			K.part({ name = "Pillar", parent = sf, size = Vector3.new(1.8, 13, 1.8), pos = Vector3.new(px, y + 6.5, zc + s * 6.5), color = stop.colour })
			K.part({ name = "PillarCap", parent = sf, size = Vector3.new(2.6, 0.8, 2.6), pos = Vector3.new(px, y + 13.4, zc + s * 6.5), color = C.Trim })
		end
		K.part({ name = "Beam", parent = sf, size = Vector3.new(2, 2, 15), pos = Vector3.new(px, y + 12, zc), color = stop.colour })
		K.part({ name = "BeamTrim", parent = sf, size = Vector3.new(2.4, 0.5, 15.4), pos = Vector3.new(px, y + 13.1, zc), color = C.Trim })
		K.part({
			name = "Glow",
			parent = sf,
			size = Vector3.new(0.3, 10.2, 11.2),
			pos = Vector3.new(px, y + 5.6, zc),
			color = stop.colour,
			mat = Enum.Material.Neon,
			transparency = 0.55,
			deco = true,
		})
		lampSign(sf, CFrame.lookAt(Vector3.new(px, y + 17, zc), Vector3.new(px + 10, y + 17, zc)), Vector3.new(18, 3.6, 0.8), stop.label, C.Navy, stop.colour)
		local trig = K.part({ name = "PortalTrigger", parent = sf, ghost = true, size = Vector3.new(8, 6, 8), pos = Vector3.new(px + 2, y + 3, zc) })
		trig.CanQuery = true
		trig:SetAttribute("ZoneId", stop.id)
		K.tag(trig, "LanePortal")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Travel"
		prompt.ObjectText = stop.label
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = trig
		z = zN
	end
	-- last ramp up to the Royale landing
	ramp(lane, z, y, z - LN.rampLen, y + LN.rise, rocks)
	z -= LN.rampLen
	y += LN.rise
	local landing = Instance.new("Folder")
	landing.Name = "Stop6_Royale"
	landing:SetAttribute("ZoneId", "BillionaireHills")
	landing:SetAttribute("Terrace", 6)
	landing:SetAttribute("TopY", y)
	landing.Parent = lane
	local lw = LN.landing
	K.slab(landing, "Island", x - lw.w / 2, x + lw.w / 2, z - lw.len, z, y - 0.3, 4, C.Grass, Enum.Material.Plastic)
	K.slab(landing, "Paving", x - rw / 2, x + rw / 2, z - lw.len, z, y, 0.6, C.Paving)
	K.place("M_Rock_B", CFrame.new(x, y - 20, z - 6), rocks, 1.2)
	startMarks.BillionaireHills = CFrame.lookAt(Vector3.new(x, y + 3, z - 2), Vector3.new(x, y + 3, z - 30))

	for id, cf in startMarks do
		local m = K.part({ name = "Start_" .. id, parent = lane, ghost = true, size = Vector3.new(2, 1, 2), cf = cf })
		m:SetAttribute("ZoneId", id)
		K.tag(m, "LaneStart")
	end

	-- cheap clouds beside the climb
	local clouds = K.folder(lane, "Clouds")
	local rng = Random.new(30)
	for i = 1, 14 do
		local zz = -120 - i * 55
		local yy = base + math.clamp((-zz - 116) / 11, 0, 72) - rng:NextNumber(26, 40)
		local s = rng:NextNumber(60, 110)
		local cloud = K.part({
			name = "Cloud",
			parent = clouds,
			deco = true,
			color = C.Cloud,
			transparency = 0.12,
			size = Vector3.new(s, s * 0.3, s * 0.7),
			cf = CFrame.new(x + (if i % 2 == 0 then 1 else -1) * rng:NextNumber(70, 120), yy, zz),
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = cloud
	end

	lane:SetAttribute("TopZ", z)
	return ("lane: %d parts, top y %.1f, landing z %.0f"):format(K.count(lane), y, z)
end

return {
	move = moveBlocks,
	build = buildLane,
}
