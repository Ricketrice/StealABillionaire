-- Studio location: ServerStorage.Build027.B4_MainStreet (ModuleScript)
-- Zone 1 Main Street (D9): a medium avenue running west from the MAIN STREET arch.
--   entrance -> section 1 (Coin Fountain plaza + garden, 3 catch spots) -> section 2 (Clock Tower plaza +
--   garden, 3 catch spots) -> the reserved boss-vault plot (B7_Reserved) at the far end.
-- The NPC area (Workspace.Zones.MainStreet: ZoneBoundary + SpawnPoints) is the central street; every
-- 3D prop stands outside it plus its 4-stud wander margin, so NPCs never meet one. Shopfronts (the
-- same eight shops) line both sides in pairs; lamps every 24 studs on both sidewalks.

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

local SHOPS = { -- name, colour, roof style
	{ "PENNY'S COFFEE", K.rgb(255, 196, 140), "flat" }, { "BOB'S BARGAINS", K.rgb(150, 206, 255), "peak" },
	{ "COURIER CO.", K.rgb(176, 230, 150), "peak" }, { "MALL MART", K.rgb(255, 170, 190), "flat" },
	{ "GADGET HUT", K.rgb(200, 170, 255), "flat" }, { "SWEET SHOP", K.rgb(255, 222, 120), "peak" },
	{ "COMIC CORNER", K.rgb(130, 220, 210), "peak" }, { "BIKE BARN", K.rgb(255, 160, 120), "flat" },
}

-- One shopfront, front facing the street (-Z of cf), base on the paving.
local function shop(parent: Instance, cf: CFrame, w: number, d: number, h: number, def)
	local m = Instance.new("Model")
	m.Name = def[1]
	local body = def[2]
	K.part({ name = "Body", parent = m, size = Vector3.new(w, h, d), cf = cf * CFrame.new(0, h / 2, 0), color = body })
	K.part({ name = "Plinth", parent = m, size = Vector3.new(w + 0.4, 1, d + 0.4), cf = cf * CFrame.new(0, 0.5, 0), color = C.Stone })
	K.part({ name = "Cornice", parent = m, size = Vector3.new(w + 0.8, 0.8, d + 0.8), cf = cf * CFrame.new(0, h + 0.4, 0), color = C.Trim })
	if def[3] == "peak" then
		K.part({ name = "Roof", parent = m, shape = "Wedge", size = Vector3.new(w, 3.2, d / 2), cf = cf * CFrame.new(0, h + 2.4, -d / 4), color = C.Coral, deco = true })
		K.part({ name = "Roof", parent = m, shape = "Wedge", size = Vector3.new(w, 3.2, d / 2), cf = cf * CFrame.new(0, h + 2.4, d / 4) * CFrame.Angles(0, math.pi, 0), color = C.Coral, deco = true })
	else
		K.part({ name = "Parapet", parent = m, size = Vector3.new(w - 2, 1.4, 0.8), cf = cf * CFrame.new(0, h + 1.5, -d / 2 + 0.6), color = body:Lerp(Color3.new(1, 1, 1), 0.4), deco = true })
	end
	K.part({ name = "Door", parent = m, size = Vector3.new(3.6, 6.4, 0.4), cf = cf * CFrame.new(0, 4.2, -d / 2 - 0.15), color = C.Navy, deco = true })
	for _, sx in { -w / 2 + 3.6, w / 2 - 3.6 } do
		K.part({ name = "Window", parent = m, size = Vector3.new(4.2, 3.8, 0.4), cf = cf * CFrame.new(sx, 4.8, -d / 2 - 0.15), color = K.rgb(200, 236, 255), mat = Enum.Material.Glass, transparency = 0.15, deco = true })
	end
	local awning = K.part({ name = "Awning", parent = m, shape = "Wedge", size = Vector3.new(w - 1, 1.2, 2.6), cf = cf * CFrame.new(0, 8.4, -d / 2 - 1.3) * CFrame.Angles(0, math.pi, 0), color = C.Carpet, deco = true })
	awning.Color = if def[3] == "peak" then C.Sky else C.Carpet
	local sign = K.part({ name = "Sign", parent = m, size = Vector3.new(w - 3, 2.2, 0.4), cf = cf * CFrame.new(0, 10.4, -d / 2 - 0.25), color = C.Curb, deco = true })
	K.text(sign, Enum.NormalId.Front, def[1], C.Navy)
	m.Parent = parent
	return m
end

-- A round paved plaza (curb ring under a cream disc) on the grass, top at paving height.
local function plaza(parent, name, x, z, r)
	K.part({ name = name .. "Curb", parent = parent, shape = "Cylinder", size = Vector3.new(0.4, (r + 1) * 2, (r + 1) * 2), cf = CFrame.new(x, L.curbTop - 0.2, z) * CFrame.Angles(0, 0, math.rad(90)), color = C.Curb })
	K.part({ name = name, parent = parent, shape = "Cylinder", size = Vector3.new(0.6, r * 2, r * 2), cf = CFrame.new(x, L.pavingTop - 0.3, z) * CFrame.Angles(0, 0, math.rad(90)), color = C.PavingWarm })
	K.part({ name = name .. "Ring", parent = parent, shape = "Cylinder", size = Vector3.new(0.1, (r - 1.5) * 2, (r - 1.5) * 2), cf = CFrame.new(x, L.pavingTop + 0.02, z) * CFrame.Angles(0, 0, math.rad(90)), color = C.Trim, deco = true })
	K.part({ name = name .. "Inner", parent = parent, shape = "Cylinder", size = Vector3.new(0.1, (r - 2.3) * 2, (r - 2.3) * 2), cf = CFrame.new(x, L.pavingTop + 0.04, z) * CFrame.Angles(0, 0, math.rad(90)), color = C.PavingWarm, deco = true })
end

local function cyl(parent, name, r, h, cf, color, mat, deco)
	return K.part({ name = name, parent = parent, shape = "Cylinder", size = Vector3.new(h, r * 2, r * 2), cf = cf * CFrame.Angles(0, 0, math.rad(90)), color = color, mat = mat, deco = deco })
end

-- Section 1 landmark: a fountain with a giant gold coin.
local function coinFountain(parent, at: Vector3)
	local m = Instance.new("Model")
	m.Name = "CoinFountain"
	local base = CFrame.new(at.X, L.pavingTop, at.Z)
	cyl(m, "Basin", 6, 1.2, base * CFrame.new(0, 0.6, 0), C.Curb)
	cyl(m, "BasinTrim", 6.4, 0.3, base * CFrame.new(0, 1.35, 0), C.Trim, nil, true)
	cyl(m, "Water", 5.3, 0.2, base * CFrame.new(0, 1.15, 0), K.rgb(120, 200, 255), Enum.Material.Glass, true).Transparency = 0.2
	cyl(m, "Pedestal", 1.3, 3.4, base * CFrame.new(0, 2.9, 0), C.Curb)
	local coin = K.part({ name = "Coin", parent = m, shape = "Cylinder", size = Vector3.new(0.9, 6.6, 6.6), cf = base * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0), color = C.Trim, deco = true })
	K.part({ name = "CoinRim", parent = m, shape = "Cylinder", size = Vector3.new(0.7, 7.2, 7.2), cf = coin.CFrame, color = C.TrimDark, deco = true })
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		K.text(coin, face, "$", C.TrimDark).TextStrokeTransparency = 1
	end
	K.tag(coin, "Fx027Sparkle")
	m.Parent = parent
end

-- Section 2 landmark: a small clock tower.
local function clockTower(parent, at: Vector3)
	local m = Instance.new("Model")
	m.Name = "ClockTower"
	local base = CFrame.new(at.X, L.pavingTop, at.Z)
	K.part({ name = "Base", parent = m, size = Vector3.new(7.4, 2, 7.4), cf = base * CFrame.new(0, 1, 0), color = C.Stone })
	K.part({ name = "Shaft", parent = m, size = Vector3.new(5.6, 16, 5.6), cf = base * CFrame.new(0, 10, 0), color = C.Curb })
	for _, y in { 6, 18.3 } do
		K.part({ name = "Band", parent = m, size = Vector3.new(6.2, 0.6, 6.2), cf = base * CFrame.new(0, y, 0), color = C.Trim, deco = true })
	end
	K.part({ name = "Housing", parent = m, size = Vector3.new(6.8, 6.2, 6.8), cf = base * CFrame.new(0, 21.7, 0), color = C.Coral })
	for _, side in { 1, -1 } do
		local faceCf = base * CFrame.new(0, 21.7, side * 3.45) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
		K.part({ name = "ClockRim", parent = m, shape = "Cylinder", size = Vector3.new(0.2, 5.6, 5.6), cf = faceCf * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, math.rad(90), 0), color = C.Trim, deco = true })
		K.part({ name = "ClockFace", parent = m, shape = "Cylinder", size = Vector3.new(0.25, 4.8, 4.8), cf = faceCf * CFrame.new(0, 0, 0.05) * CFrame.Angles(0, math.rad(90), 0), color = C.Curb, deco = true })
		K.part({ name = "HandHour", parent = m, size = Vector3.new(0.35, 1.6, 0.1), cf = faceCf * CFrame.new(0.35, 0.55, 0.22) * CFrame.Angles(0, 0, math.rad(-40)), color = C.Navy, deco = true })
		K.part({ name = "HandMinute", parent = m, size = Vector3.new(0.25, 2.1, 0.1), cf = faceCf * CFrame.new(0, 1.0, 0.24), color = C.Navy, deco = true })
	end
	K.part({ name = "Cap", parent = m, size = Vector3.new(7.4, 0.8, 7.4), cf = base * CFrame.new(0, 25.2, 0), color = C.Trim })
	K.part({ name = "Dome", parent = m, shape = "Ball", size = Vector3.new(6, 6, 6), cf = base * CFrame.new(0, 26, 0), color = C.Sky, deco = true })
	cyl(m, "Spire", 0.3, 3.4, base * CFrame.new(0, 30.4, 0), C.Trim, nil, true)
	K.part({ name = "SpireBall", parent = m, shape = "Ball", size = Vector3.new(1.1, 1.1, 1.1), cf = base * CFrame.new(0, 32.4, 0), color = C.Glow, mat = Enum.Material.Neon, deco = true })
	m.Parent = parent
end

return function(): string
	local root = K.folder(K.root(), "MainStreet", true)
	local ms = L.ms
	local top = L.pavingTop

	-- The NPC area: the central street, from just past the arch to the boss plot.
	local zone = workspace.Zones.MainStreet
	local boundary = zone.ZoneBoundary :: BasePart
	if boundary:GetAttribute("Pre027Size") == nil then
		boundary:SetAttribute("Pre027Size", boundary.Size)
		boundary:SetAttribute("Pre027Position", boundary.Position)
	end
	local bx0, bx1 = ms.streetEnd, ms.x0 - 2
	boundary.Size = Vector3.new(bx1 - bx0, boundary.Size.Y, ms.npcZ[2] - ms.npcZ[1])
	boundary.Position = Vector3.new((bx0 + bx1) / 2, boundary.Position.Y, (ms.npcZ[1] + ms.npcZ[2]) / 2)
	-- Catch spots: three per section, each marked by a flat gold ring (walk-through, NPC area safe).
	local spots = {
		Vector2.new(ms.section1 + 9, -14), Vector2.new(ms.section1 - 7, 6), Vector2.new(ms.section1, -4),
		Vector2.new(ms.section2 + 8, 6), Vector2.new(ms.section2 - 9, -14), Vector2.new(ms.section2, -4),
	}
	local catch = K.folder(root, "CatchSpots")
	local points = zone.SpawnPoints:GetChildren()
	table.sort(points, function(a, b)
		return a.Name < b.Name
	end)
	for i, sp in points do
		local s = spots[(i - 1) % #spots + 1]
		if sp:IsA("BasePart") then
			sp.Position = Vector3.new(s.X, top + sp.Size.Y / 2, s.Y)
		end
	end
	for _, s in spots do
		K.part({ name = "SpotRing", parent = catch, shape = "Cylinder", size = Vector3.new(0.1, 7, 7), cf = CFrame.new(s.X, top + 0.12, s.Y) * CFrame.Angles(0, 0, math.rad(90)), color = C.Trim, deco = true }) -- above the runner
		K.part({ name = "SpotInner", parent = catch, shape = "Cylinder", size = Vector3.new(0.1, 5.8, 5.8), cf = CFrame.new(s.X, top + 0.14, s.Y) * CFrame.Angles(0, 0, math.rad(90)), color = C.Stone, deco = true })
	end

	-- The street's centre band: warm terracotta runner with gold edges (flat, walk-through, NPC-safe).
	local band = K.folder(root, "CentreBand")
	local mid = (ms.npcZ[1] + ms.npcZ[2]) / 2
	K.slab(band, "Runner", ms.streetEnd, ms.x0, mid - 6, mid + 6, top + 0.06, 0.1, K.rgb(232, 168, 116)).CanCollide = false
	for _, side in { -1, 1 } do
		K.slab(band, "RunnerEdge", ms.streetEnd, ms.x0, mid + side * 6 - 0.4, mid + side * 6 + 0.4, top + 0.08, 0.1, C.Trim).CanCollide = false
	end
	for _, p in band:GetChildren() do
		p.CanQuery, p.CanTouch = false, false
	end

	-- Bunting across the street at both ends of each section (high above the NPCs and carried workers).
	local bunting = K.folder(root, "Bunting")
	local colours = { C.Carpet, C.Trim, C.Sky, C.Mint, C.Coral }
	for _, sx in { ms.section1 + 15, ms.section1 - 15, ms.section2 + 15, ms.section2 - 15 } do
		local zA, zB, y = ms.npcZ[2] + 4.5, ms.npcZ[1] - 4.5, 13.2
		K.bar(bunting, "Rope", Vector3.new(sx, 0, zA), Vector3.new(sx, 0, zB), 0.15, y, 0.15, C.Curb, nil, true)
		local n = 11
		for k = 1, n do
			local z = zA + (zB - zA) * k / (n + 1)
			K.part({ name = "Pennant", parent = bunting, shape = "Wedge", size = Vector3.new(0.1, 1.4, 1.1), cf = CFrame.new(sx, y - 0.8, z) * CFrame.Angles(math.pi, 0, 0), color = colours[(k - 1) % #colours + 1], deco = true })
		end
	end

	-- Shops in pairs facing the street.
	local fronts = K.folder(root, "Shopfronts")
	local i = 0
	for col, x in ms.shopXs do
		i += 1
		shop(fronts, CFrame.new(x, top, ms.streetZ[2] + 6.5), 19, 13, 11 + (col % 2) * 2, SHOPS[i])
		i += 1
		shop(fronts, CFrame.new(x, top, ms.streetZ[1] - 6.5) * CFrame.Angles(0, math.pi, 0), 19, 13, 12 - (col % 2) * 1.5, SHOPS[i])
	end

	-- Section plazas: a landmark plaza on one side, a garden on the other.
	local sections = K.folder(root, "Sections")
	local nZ, sZ = ms.streetZ[2] + 13, ms.streetZ[1] - 11.5
	plaza(sections, "Section1Plaza", ms.section1, nZ, 12)
	coinFountain(sections, Vector3.new(ms.section1, 0, nZ + 1))
	plaza(sections, "Section1Garden", ms.section1, sZ, 11)
	plaza(sections, "Section2Garden", ms.section2, nZ, 11)
	plaza(sections, "Section2Plaza", ms.section2, sZ, 12)
	clockTower(sections, Vector3.new(ms.section2, 0, sZ - 1))
	-- benches round the gardens and plazas, facing their centres
	local benches = K.folder(root, "Benches")
	for _, g in { { ms.section1, sZ, 11 }, { ms.section2, nZ, 11 }, { ms.section1, nZ, 12 }, { ms.section2, sZ, 12 } } do
		for _, a in { 210, 270, 330 } do
			local ang = math.rad(a + (if g[2] > 0 then 0 else 180))
			local p = Vector3.new(g[1] + math.cos(ang) * (g[3] - 3), top, g[2] + math.sin(ang) * (g[3] - 3))
			K.place("M_Bench", CFrame.lookAt(p, Vector3.new(g[1], top, g[2])), benches)
		end
	end

	-- Lamps every 24 studs on both sidewalks (three lit), just outside the NPC area.
	local lamps = K.folder(root, "Lamps")
	local lit = 0
	for x = ms.x0 - 6, ms.streetEnd + 6, -24 do
		for _, z in { ms.npcZ[2] + 4.5, ms.npcZ[1] - 4.5 } do
			local lamp = K.place("M_Lamp", CFrame.new(x, top, z), lamps)
			if (x == ms.x0 - 30 and z > 0) or (x == ms.x0 - 78 and z < 0) or (x == ms.x0 - 126 and z > 0) then
				local light = Instance.new("PointLight")
				light.Range, light.Brightness, light.Color, light.Shadows = 20, 1.1, C.Glow, false
				light.Parent = lamp:FindFirstChild("Glass", true)
				lit += 1
			end
		end
	end
	return ("main street: NPC area x %.0f..%.0f (%d x %d), %d catch spots, %d parts, %d lamps (%d lit)"):format(bx0, bx1, boundary.Size.X, boundary.Size.Z, #spots, K.count(root), #lamps:GetChildren(), lit)
end
