-- Studio location: ServerStorage.Build031.B2_Zone6Look (ModuleScript)
-- Milestone 031 Phase 2 (Edit mode; backup = ServerStorage._Backups.Pre031_Zone6): Velocity Royale clean-up and
-- "billionaire racing club" look. Each step reports what it changed; run in order:
--   masters()  the 016 template props that sat in the world (MasterAssets) go to ServerStorage.Zone6Masters016
--   cars()     the two show cars leave the racing line and flank the podium
--   declutter() fewer, bigger props: string lights, bunting, half the lamp banners, the small team flags, two
--              of four display cars, and the tiny orange/teal neon bits go
--   palette()  hub palette + gold: kerbs gold, barriers white, the start line one gold/navy checkered strip
--   route()    big gold arrows on the track before each bend, so the way round is obvious
--   vip()      the north grandstand becomes the small VIP grandstand (navy + gold, "VIP" board)
--   summit()   rocks under the island's rim and clouds below: the top of the climb
-- Everything removed is listed in the report; ServerStorage._Backups.Pre031_Zone6 has the original.

local ServerStorage = game:GetService("ServerStorage")

local GOLD = Color3.fromRGB(240, 186, 58)
local NAVY = Color3.fromRGB(40, 52, 92)
local CURB = Color3.fromRGB(255, 251, 242)
local CHECKER = "rbxassetid://81898318473915" -- UITheme.TEXTURES.Checker (our own)

local B = {}

local function royale(): Instance
	return workspace.World.VelocityRoyale
end
local function v016(): Instance
	return royale().VelocityRoyale_016B
end

function B.masters(): string
	local masters = v016():FindFirstChild("MasterAssets")
	if not masters then
		return "masters: already moved"
	end
	local old = ServerStorage:FindFirstChild("Zone6Masters016")
	if old then
		old:Destroy()
	end
	masters.Name = "Zone6Masters016"
	masters.Parent = ServerStorage
	return "masters: MasterAssets -> ServerStorage.Zone6Masters016"
end

-- Show cars: off the track (they blocked the racing line), either side of the podium stage, facing the plaza.
local CARS = {
	GridCar_SunflareComets = CFrame.new(-145, 73.4, -924),
	TrackCar_FrostcrestWyverns = CFrame.new(-173.4, 73.4, -924),
}
function B.cars(): string
	local out = {}
	for name, cf in CARS do
		local car = royale():FindFirstChild(name, true)
		if car and car:IsA("Model") then
			local pivot = car:GetPivot()
			local box, size = car:GetBoundingBox()
			local _, yaw = box:ToOrientation()
			-- keep the model's own height; turn it so it faces +Z (towards the plaza), centred on the spot
			local turned = CFrame.Angles(0, math.pi - yaw, 0) * pivot.Rotation
			local offset = (CFrame.Angles(0, math.pi - yaw, 0) * (box.Position - pivot.Position)) * Vector3.new(1, 0, 1)
			car:PivotTo(CFrame.new(Vector3.new(cf.X, pivot.Y, cf.Z) - offset) * turned)
			car.Parent = royale().WinnersPodium
			table.insert(out, ("%s -> (%.0f, %.0f) %s"):format(name, cf.X, cf.Z, tostring(size)))
		end
	end
	return "cars: " .. table.concat(out, "; ")
end

local function count(i: Instance): number
	local n = if i:IsA("BasePart") then 1 else 0
	for _, d in i:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end
local function remove(list: { Instance? }): (number, { string })
	local n, names = 0, {}
	for _, i in list do
		if i and i.Parent then
			n += count(i)
			table.insert(names, i.Name)
			i:Destroy()
		end
	end
	return n, names
end

function B.declutter(): string
	local atmo = v016().Atmosphere
	local doomed: { Instance? } = { atmo:FindFirstChild("Cluster_PlazaLights"), workspace.World.BillionaireCity.Zone6Plaza:FindFirstChild("Bunting") }
	local banners = atmo:FindFirstChild("Cluster_BoulevardBanners")
	if banners then
		table.insert(doomed, banners:FindFirstChild("LightRig_Boulevard"))
		for _, b in banners:GetChildren() do
			local n = tonumber(b.Name:match("^LampBanner_(%d+)$"))
			if n and n % 2 == 0 then
				table.insert(doomed, b)
			end
		end
	end
	local flags = atmo:FindFirstChild("Cluster_CircuitFlags")
	if flags then
		for _, f in flags:GetChildren() do
			if f.Name:match("^TeamFlag_%d+$") then
				table.insert(doomed, f)
			end
		end
	end
	local cars = atmo:FindFirstChild("Cluster_DisplayCars")
	if cars then
		table.insert(doomed, cars:FindFirstChild("DisplayCar_Starquill"))
		table.insert(doomed, cars:FindFirstChild("DisplayCar_Aerowisp"))
		table.insert(doomed, cars:FindFirstChild("DisplayPlinth_04"))
	end
	local parts, names = remove(doomed)
	-- tiny orange / teal neon bits (not on cars, the gate or the podium)
	local tiny = {}
	for _, root in { royale(), workspace.World.BillionaireCity.Zone6Plaza } do
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Size.Magnitude < 2.2 then
				local h, sat = d.Color:ToHSV()
				local orangeOrTeal = sat >= 0.25 and (h < 0.11 or (h >= 0.45 and h < 0.55))
				local keep = d:FindFirstAncestor("Gateway")
					or d:FindFirstAncestor("WinnersPodium")
					or d:FindFirstAncestor("RaceCourse")
					or d:FindFirstAncestorWhichIsA("Model") and d:FindFirstAncestorWhichIsA("Model").Name:find("Car")
				if orangeOrTeal and not keep then
					table.insert(tiny, d)
				end
			end
		end
	end
	local tinyCount = remove(tiny)
	return ("declutter: -%d parts (%s) and -%d tiny orange/teal neon bits"):format(parts, table.concat(names, ", "), tinyCount)
end

function B.palette(): string
	local circuit = v016().Circuit
	local kerbs, barriers = 0, 0
	for _, c in circuit:GetChildren() do
		if c:IsA("BasePart") and c.Name:match("^Kerb") then
			c.Color = GOLD
			kerbs += 1
		end
	end
	for _, b in circuit.Barriers:GetDescendants() do
		if b:IsA("BasePart") then
			b.Color = CURB
			barriers += 1
		end
	end
	-- start/finish: one gold/navy checkered strip instead of the 9 painted squares
	local startLine = circuit:FindFirstChild("StartLine")
	local removed = 0
	if startLine and not startLine:FindFirstChild("Checkered") then
		removed = count(startLine)
		startLine:ClearAllChildren()
		local line = Instance.new("Part")
		line.Name = "Checkered"
		line.Anchored = true
		line.CanCollide, line.CanQuery, line.CanTouch = false, false, false
		line.Size = Vector3.new(11, 0.1, 2.4)
		line.CFrame = CFrame.new(-115.5, 72.36, -952)
		line.Color = NAVY
		line.Material = Enum.Material.SmoothPlastic
		line.TopSurface = Enum.SurfaceType.Smooth
		line.Parent = startLine
		local tex = Instance.new("Texture")
		tex.Texture = CHECKER
		tex.Face = Enum.NormalId.Top
		tex.Color3 = GOLD
		tex.StudsPerTileU, tex.StudsPerTileV = 2.4, 2.4
		tex.Parent = line
		if startLine:IsA("Model") then
			startLine.PrimaryPart = line
		end
	end
	return ("palette: %d kerbs gold, %d barriers white, start line %d parts -> 1 checkered strip"):format(kerbs, barriers, removed)
end

-- Arrows: before each bend, pointing the way round (race direction = +Z down the start straight).
local ARROWS = {
	{ Vector3.new(-115.5, 72.38, -937), Vector3.new(0.3, 0, 1) },
	{ Vector3.new(-96, 72.38, -927.8), Vector3.new(1, 0, 0.1) },
	{ Vector3.new(-77, 72.38, -940), Vector3.new(-0.2, 0, -1) },
	{ Vector3.new(-84.5, 72.38, -964), Vector3.new(-0.5, 0, -1) },
	{ Vector3.new(-102, 72.38, -972), Vector3.new(-1, 0, 0.4) },
}
function B.route(): string
	local circuit = v016().Circuit
	local old = circuit:FindFirstChild("RouteArrows")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "RouteArrows"
	-- each arrow = two flat gold chevrons (">" made of two bars) pointing along the race direction
	local ARM, ANGLE = 3, math.rad(42)
	local n = 0
	for i, a in ARROWS do
		local frame = CFrame.lookAt(a[1], a[1] + a[2].Unit) -- forward = -Z
		for _, tipZ in { -2.2, 0.6 } do
			for _, side in { -1, 1 } do
				local dir = Vector3.new(side * math.sin(ANGLE), 0, math.cos(ANGLE)) -- from the tip, backwards and out
				local centre = Vector3.new(0, 0, tipZ) + dir * (ARM / 2)
				local bar = Instance.new("Part")
				bar.Name = ("Arrow%d"):format(i)
				bar.Anchored = true
				bar.CanCollide, bar.CanQuery, bar.CanTouch = false, false, false
				bar.CastShadow = false
				bar.Size = Vector3.new(0.8, 0.06, ARM)
				bar.CFrame = frame * CFrame.lookAt(centre, centre + dir)
				bar.Color = GOLD
				bar.Material = Enum.Material.SmoothPlastic
				bar.Parent = folder
				n += 1
			end
		end
	end
	folder.Parent = circuit
	return ("route: %d arrows (%d parts)"):format(#ARROWS, n)
end

function B.vip(): string
	local stand = v016().Circuit.Stands:FindFirstChild("Stand_North_01")
	if not stand then
		return "vip: no Stand_North_01"
	end
	local recoloured = 0
	for _, p in stand:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "VIPBoard" then
			local h, sat, v = p.Color:ToHSV()
			p.Color = if v > 0.8 and sat < 0.2 then CURB elseif p.Name:find("Tier") or p.Name:find("Seat") then NAVY else GOLD
			p.Material = Enum.Material.SmoothPlastic
			recoloured += 1
			local _ = h
		end
	end
	local old = stand:FindFirstChild("VIPBoard")
	if old then
		old:Destroy()
	end
	local cf, size = stand:GetBoundingBox()
	local board = Instance.new("Part")
	board.Name = "VIPBoard"
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(math.max(size.X, size.Z) * 0.8, 3, 0.4)
	board.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y / 2 + 2, 0), cf.Position + Vector3.new(0, size.Y / 2 + 2, -10))
	board.Color = NAVY
	board.Parent = stand
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.Text = "VIP GRANDSTAND"
		label.TextScaled = true
		label.TextColor3 = GOLD
		label.Parent = gui
	end
	return ("vip: %d stand parts recoloured, board added"):format(recoloured)
end

-- Rocks under the rim of the island and clouds below it.
function B.summit(): string
	local old = royale():FindFirstChild("Summit031")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Summit031"
	local masters = ServerStorage:FindFirstChild("CityKit_027")
	local rocks = 0
	local rim = { { -228, -905 }, { -222, -960 }, { -180, -985 }, { -125, -982 }, { -72, -950 }, { -85, -890 }, { -200, -850 } }
	for i, xz in rim do
		local master = masters and masters:FindFirstChild(if i % 2 == 0 then "M_Rock_A" else "M_Rock_B")
		if master then
			local m = master:Clone()
			m:ScaleTo(if i % 2 == 0 then 1.6 else 1.9)
			m:PivotTo(CFrame.new(xz[1], 50, xz[2]) * CFrame.Angles(0, math.rad(61 * i), 0))
			m.Parent = folder
			rocks += 1
		end
	end
	local clouds = 0
	for i, c in { { -250, 38, -930, 110 }, { -60, 34, -985, 90 }, { -150, 30, -1030, 120 }, { -40, 40, -880, 80 } } do
		local p = Instance.new("Part")
		p.Name = "Cloud" .. i
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = false
		p.Color = Color3.new(1, 1, 1)
		p.Transparency = 0.12
		p.Size = Vector3.new(c[4], c[4] * 0.3, c[4] * 0.7)
		p.CFrame = CFrame.new(c[1], c[2], c[3])
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		p.Parent = folder
		clouds += 1
	end
	folder.Parent = royale()
	return ("summit: %d rocks (%d parts), %d clouds"):format(rocks, count(folder) - clouds, clouds)
end

return B
