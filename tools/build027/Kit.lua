-- Studio location: ServerStorage.Build027.Kit (ModuleScript)
-- Milestone 027 build kit (Edit-mode tool, removed from the place when the build is done):
-- palette, layout numbers and part helpers shared by the build steps B0..B6.
-- Every step rebuilds its own folder under Workspace.World.SkyCity, so a step can be run again.

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local K = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
K.rgb = rgb

-- One palette for the whole hub (D6: bright, saturated, cheerful). TRIM is the one trim colour.
K.C = {
	Grass = rgb(118, 196, 82),
	GrassDark = rgb(92, 168, 66),
	Hedge = rgb(62, 146, 64),
	Paving = rgb(246, 232, 200), -- cream: the safe hub and walkways
	PavingWarm = rgb(240, 220, 182),
	Curb = rgb(255, 251, 242),
	Stone = rgb(222, 212, 196),
	Trim = rgb(240, 186, 58), -- gold, the one trim colour
	TrimDark = rgb(196, 140, 34),
	Carpet = rgb(206, 38, 58), -- the parade lane
	Navy = rgb(40, 52, 92),
	Sky = rgb(86, 176, 238),
	Mint = rgb(80, 204, 160),
	Coral = rgb(255, 120, 96),
	Rock = rgb(132, 112, 96),
	RockDark = rgb(104, 88, 76),
	Trunk = rgb(122, 82, 52),
	Canopy = rgb(88, 178, 72),
	CanopyLight = rgb(130, 204, 84),
	CanopyDark = rgb(64, 150, 70),
	Cloud = rgb(255, 255, 255),
	Glow = rgb(255, 214, 140),
	Dark = rgb(48, 44, 52),
}
-- The twelve lot colours (same shape, different colour), in PlotId order.
K.LOT_COLOURS = {
	rgb(255, 110, 96), rgb(86, 176, 238), rgb(255, 176, 60), rgb(122, 206, 92),
	rgb(176, 120, 236), rgb(60, 196, 186), rgb(255, 128, 180), rgb(250, 214, 64),
	rgb(108, 140, 240), rgb(255, 150, 80), rgb(150, 210, 70), rgb(230, 100, 140),
}

-- Layout (studs). +X runs from the spawn square down the avenue into the plaza.
K.L = {
	laneZ = -4,
	plaza = Vector3.new(172, 0, -4),
	lotXs = { -118, -77, -36, 5, 46, 87 }, -- west -> east
	lotPitch = 41,
	rowNorthZ = 33, -- lots at z > laneZ (their front faces -Z)
	rowSouthZ = -41, -- lots at z < laneZ (front faces +Z)
	lotTrim = 39, -- gold trim square under each lot
	lotBase = 37.6, -- coloured base square
	stripZ = { -21.5, 13.5 }, -- walkway paving between the two rows of lots
	avenueX = { -139.5, 120 },
	squareX = { -174, -139.5 },
	squareZ = { -60.5, 52.5 },
	spawn = Vector3.new(-157, 0, -4),
	zone1GateX = -177,
	mainStreet = Vector3.new(-212, 0, -4), -- ZoneBoundary centre (64 x 66)
	island = { x0 = -266, x1 = 140, z0 = -70, z1 = 62 },
	-- surface tops
	grassTop = 0.0,
	curbTop = 0.2,
	pavingTop = 0.3,
	laneEdgeTop = 0.4,
	laneTop = 0.5,
	lotTrimTop = 0.7,
	lotBaseTop = 0.8,
	lotFloorTop = 1.0,
}

function K.folder(parent: Instance, name: string, fresh: boolean?): Folder
	local f = parent:FindFirstChild(name)
	if f and fresh then
		f:Destroy()
		f = nil
	end
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

function K.root(): Folder
	return K.folder(K.folder(workspace, "World"), "SkyCity")
end

-- part{ name, size, cf | pos, color, mat, shape, parent, deco = true (no collide/query/touch),
--       ghost = true (invisible helper), shadow = false, transparency }
function K.part(o: any): BasePart
	local p: BasePart
	if o.shape == "Wedge" then
		p = Instance.new("WedgePart")
	elseif o.shape == "Corner" then
		p = Instance.new("CornerWedgePart")
	else
		p = Instance.new("Part")
		if o.shape then
			(p :: Part).Shape = Enum.PartType[o.shape]
		end
	end
	p.Name = o.name or "Part"
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cf or CFrame.new(o.pos)
	p.Color = o.color or K.C.Paving
	p.Material = o.mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = o.transparency or 0
	if o.deco or o.ghost then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	if o.ghost then
		p.Transparency = 1
	end
	if o.shadow == false or o.deco then
		p.CastShadow = o.shadow == true
	end
	p.Parent = o.parent
	return p
end

-- A flat slab whose top is at `top`: x0..x1, z0..z1.
function K.slab(parent, name, x0, x1, z0, z1, top, thick, color, mat)
	thick = thick or 0.6
	return K.part({
		name = name, parent = parent, color = color, mat = mat,
		size = Vector3.new(math.abs(x1 - x0), thick, math.abs(z1 - z0)),
		pos = Vector3.new((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2),
	})
end

-- A flat bar between two points on the ground (lines, curbs), top at `top`.
function K.bar(parent, name, a: Vector3, b: Vector3, width, top, thick, color, mat, deco)
	local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local length = (flatB - flatA).Magnitude
	local mid = (flatA + flatB) / 2
	return K.part({
		name = name, parent = parent, color = color, mat = mat, deco = deco,
		size = Vector3.new(width, thick, length),
		cf = CFrame.lookAt(Vector3.new(mid.X, top - thick / 2, mid.Z), Vector3.new(flatB.X, top - thick / 2, flatB.Z)),
	})
end

function K.text(part: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if bg then 0 else 1
	label.BackgroundColor3 = bg or Color3.new(1, 1, 1)
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.08, 0), UDim.new(0.08, 0)
	pad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(60, 40, 20)
	stroke.Transparency = 0.4
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = part
	return label
end

function K.tag(inst: Instance, tag: string)
	CollectionService:AddTag(inst, tag)
end

-- Masters ------------------------------------------------------------------------------------------
function K.masters(): Folder
	return K.folder(ServerStorage, "CityKit_027")
end

-- Clones master `name` and pivots it to `cf` (optionally scaled), into `parent`.
function K.place(name: string, cf: CFrame, parent: Instance, scale: number?): Model
	local master = K.masters():FindFirstChild(name)
	assert(master, "no master " .. name)
	local m = master:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- Ground height under a point (top of the highest surface), for standing props on the ground.
function K.groundY(x: number, z: number, ignore: { Instance }?): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position.Y else 0
end

function K.count(inst: Instance): number
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return K
