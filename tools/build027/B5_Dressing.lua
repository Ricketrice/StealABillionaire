-- Studio location: ServerStorage.Build027.B5_Dressing (ModuleScript)
-- Street dressing, all clones of the CityKit_027 masters: lamps along the lane every 24 studs (every
-- other one lit, no shadows), tree clusters (2-3 trees of different sizes) behind the lots and at the
-- corners, bushes and flowers at the lot corners and building bases. Nothing goes on the lane.

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

return function(): string
	local root = K.folder(K.root(), "Dressing", true)
	local rng = Random.new(2027)
	local top = L.pavingTop

	-- Lamps on both walkways, staggered, just outside the lane's gold band.
	local lamps = K.folder(root, "Lamps")
	local lit = 0
	local n = 0
	for x = L.avenueX[1] + 9, L.avenueX[2] - 14, 24 do
		for _, side in { 1, -1 } do
			n += 1
			local lx = x + (if side < 0 then 12 else 0)
			if lx < L.avenueX[2] - 12 then
				local z = L.laneZ + side * 10.6
				local lamp = K.place("M_Lamp", CFrame.new(lx, top, z), lamps)
				if n % 2 == 1 then
					local glass = lamp:FindFirstChild("Glass", true)
					local light = Instance.new("PointLight")
					light.Range, light.Brightness, light.Color, light.Shadows = 20, 1.1, C.Glow, false
					light.Parent = glass
					lit += 1
				end
			end
		end
	end

	-- Tree clusters: 2-3 trees, different sizes and turns.
	local trees = K.folder(root, "Trees")
	local leafy = 0
	local function cluster(x, z, count, squeeze)
		for k = 1, count do
			local kind = ({ "M_Tree_A", "M_Tree_B", "M_Tree_C" })[rng:NextInteger(1, 3)]
			local a = rng:NextNumber(0, math.pi * 2)
			local r = if k == 1 then 0 else rng:NextNumber(3.5, 5.5)
			local px, pz = x + math.cos(a) * r, z + math.sin(a) * r * (squeeze or 1)
			local t = K.place(kind, CFrame.new(px, K.groundY(px, pz, { trees }), pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), trees, rng:NextNumber(0.95, 1.35))
			local shade = ({ C.Canopy, C.CanopyLight, C.CanopyDark })[rng:NextInteger(1, 3)]
			for _, p in t:GetChildren() do
				if p:IsA("MeshPart") and p.Name == "Canopy" then
					p.Color = shade -- one mesh canopy per tree: vary the green between trees
				end
			end
			if leafy < 4 and k == 1 and math.abs(x) < 120 then
				local canopy = t:FindFirstChild("Canopy")
				if canopy then
					K.tag(canopy, "Fx027Leaves")
					leafy += 1
				end
			end
		end
	end
	local backN = (L.rowNorthZ + L.lotTrim / 2 + L.hubZ[2] - 1.4) / 2
	local backS = (L.rowSouthZ - L.lotTrim / 2 + L.hubZ[1] + 1.4) / 2
	for idx, x in L.lotXs do
		cluster(x - L.lotPitch / 2, backN, 2 + idx % 2, 0.3) -- squeeze: stay in the strip behind the lots
		cluster(x - L.lotPitch / 2 + 6, backS, 2 + (idx + 1) % 2, 0.3)
	end
	cluster(L.lotXs[6] + L.lotPitch / 2 + 2, backN, 3, 0.3)
	cluster(L.lotXs[6] + L.lotPitch / 2 + 2, backS, 2, 0.3)
	cluster(114, 38, 3) -- plaza junction corners
	cluster(114, -46, 3)
	cluster(-170, 57, 2, 0.4) -- spawn square corners (grass behind the stalls)
	cluster(-145, 58, 2, 0.4)
	cluster(-170, -65, 3, 0.4)
	cluster(-145, -66, 2, 0.4)
	local ms = L.ms -- Main Street: behind the shops and round the boss plot
	for _, x in { -197, -253, -313 } do
		cluster(x, ms.streetZ[2] + 21, 2, 0.5)
		cluster(x + 6, ms.streetZ[1] - 20, 2, 0.5)
	end
	cluster(-360, 40, 2, 0.5)
	cluster(-360, -48, 3, 0.5)

	-- Bushes and flowers: lot front corners (the grass gaps between lots) and building bases.
	local beds = K.folder(root, "Beds")
	local function bed(x, z, flowers)
		K.place(if flowers then "M_Flowers" else "M_Bush", CFrame.new(x, K.groundY(x, z, { beds, trees }), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), beds, rng:NextNumber(0.9, 1.2))
	end
	for idx = 0, #L.lotXs do
		local gx = L.lotXs[1] - L.lotPitch / 2 + idx * L.lotPitch
		bed(gx, L.stripZ[2] + 1.2, idx % 2 == 0)
		bed(gx, L.stripZ[1] - 1.2, idx % 2 == 1)
	end
	for _, p in { { -173.4, 41.5 }, { -139.6, 41.5 }, { -173.4, -49.5 }, { -139.6, -49.5 } } do -- stall corners
		bed(p[1], p[2], true)
	end
	for _, a in { 45, 135, 225, 315 } do -- round the Vault plinth
		local r = math.rad(a)
		bed(L.plaza.X + math.cos(r) * 23.5, L.plaza.Z + math.sin(r) * 23.5, a % 90 == 45)
	end
	for _, z in { L.laneZ - 15, L.laneZ + 15 } do -- Zone 1 arch feet
		bed(L.zone1GateX, z, true)
	end
	return ("dressing: %d parts, %d lamps (%d lit), %d trees, %d beds"):format(K.count(root), #lamps:GetChildren(), lit, #trees:GetChildren(), #beds:GetChildren())
end
