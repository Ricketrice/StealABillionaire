-- Studio location: ServerStorage.Build034.B5_Kits (ModuleScript)
-- 034: swaps part-built zone props for the Blender meshes in ServerStorage.Imports034 (tools/blender/build_034_imports.py).
-- Run after B1-B4 (they rebuild their folders from parts; run this again afterwards). Re-runnable: a prop already
-- swapped carries attribute Kit034 and is skipped. Every replaced original goes to ServerStorage._Parked034.Kits.
--   KeepTower    -> Knight's Keep wall towers (KnightsKeep.Walls.Tower)
--   ShellPalace  -> the Shell Palace's building parts (its Sign, Steps and Glow stay)
--   Coral, Kelp  -> Sunken Kingdom coral clusters and kelp strands (colour and bob settings kept)
--   WizardTower  -> Ember Academy wizard towers (the floating FireCrystal above each stays, re-skinned)
--   FireCrystal  -> every fire crystal (entrance arch, towers, Spell Run finish, Ember Spire)
--   Spellbook    -> the floating books, and a skin on the Spell Run's sliding books (their Cover stays as the
--                   invisible box you stand on, so the course plays exactly as before)
-- Each mesh is scaled uniformly to the original's world height (or width for books/palace) and stands on the
-- original's footprint (bottom centre).

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local rgb = Color3.fromRGB

-- colour + material per imported part key (the part name after "<Model>_"); "keep" = the original's colour
local LOOK = {
	KeepTower = {
		Body = { rgb(176, 168, 156), Enum.Material.Cobblestone },
		Slits = { rgb(40, 36, 44) },
		Roof = { rgb(196, 54, 60) },
		Finial = { rgb(240, 186, 58) },
	},
	ShellPalace = {
		Dome = { rgb(236, 236, 246), Enum.Material.Marble },
		Fan = { rgb(255, 196, 186) },
		TowerL = { rgb(250, 178, 170) },
		TowerR = { rgb(250, 178, 170) },
		Door = { rgb(40, 170, 190), Enum.Material.Neon },
		Pearl = { rgb(246, 240, 255), Enum.Material.SmoothPlastic },
	},
	Coral = { Coral = { "keep", Enum.Material.Pebble } },
	Kelp = { Kelp = { "keep", Enum.Material.Grass } },
	WizardTower = {
		Body = { rgb(92, 54, 112), Enum.Material.Slate },
		Bands = { rgb(214, 160, 70), Enum.Material.Metal },
		Roof = { rgb(64, 36, 84) },
		Windows = { rgb(255, 150, 60), Enum.Material.Neon },
	},
	FireCrystal = { Crystal = { "keep", Enum.Material.Neon } },
	Spellbook = {
		Cover = { "keep", Enum.Material.Fabric },
		Pages = { rgb(246, 236, 210) },
		Rune = { rgb(255, 140, 60), Enum.Material.Neon },
	},
}

local imports: Folder
local parkedCount = 0

-- World-aligned bounds of the BaseParts under `root` (or of `root` itself).
local function bounds(root: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local list: { Instance } = if root:IsA("BasePart") then { root } else root:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") then
			local cf, h = p.CFrame, p.Size / 2
			local ext = Vector3.new(
				math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
				math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
				math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
			)
			lo = lo:Min(cf.Position - ext)
			hi = hi:Max(cf.Position + ext)
		end
	end
	return lo, hi
end

local function firstColour(root: Instance, prefer: string?): Color3?
	if prefer then
		local p = root:FindFirstChild(prefer, true)
		if p and p:IsA("BasePart") then
			return p.Color
		end
	end
	local p = if root:IsA("BasePart") then root else root:FindFirstChildWhichIsA("BasePart", true)
	return p and (p :: BasePart).Color
end

local function park(inst: Instance)
	local parked = ServerStorage:FindFirstChild("_Parked034") or Instance.new("Folder")
	parked.Name = "_Parked034"
	parked.Parent = ServerStorage
	local kits = parked:FindFirstChild("Kits") or Instance.new("Folder")
	kits.Name = "Kits"
	kits.Parent = parked
	local list: { Instance } = if inst:IsA("BasePart") then { inst } else inst:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") then
			parkedCount += 1
		end
	end
	inst:SetAttribute("ParkedFrom", if inst.Parent then inst.Parent:GetFullName() else "?")
	inst.Parent = kits
end

-- A scaled, coloured copy of Imports034.<kit>: `size` = the target world size along `fit` ("Y" height, "X"/"Z"
-- width, "XZ" = the smaller of the two widths), standing on `foot` (world bottom centre), turned by `yaw`.
local function mesh(kit: string, foot: Vector3, size: number, fit: string, yaw: number?, keep: Color3?): Model
	local src = imports:FindFirstChild(kit)
	assert(src, "Imports034." .. kit .. " is missing")
	local m = src:Clone()
	m.Name = kit
	local lo, hi = bounds(m)
	local ext = hi - lo
	m.WorldPivot = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local k = if fit == "Y" then size / ext.Y elseif fit == "X" then size / ext.X elseif fit == "Z" then size / ext.Z else size / math.min(ext.X, ext.Z)
	m:ScaleTo(k)
	m:PivotTo(CFrame.new(foot) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local look = LOOK[kit] or {}
	for _, p in m:GetDescendants() do
		if p:IsA("MeshPart") then
			local key = p.Name:match("_(.+)$") or p.Name
			p.Name = key
			p.Anchored = true
			local l = look[key]
			if l then
				p.Color = if l[1] == "keep" then (keep or p.Color) else l[1]
				p.Material = l[2] or Enum.Material.SmoothPlastic
			end
			p.CastShadow = p.Size.Magnitude > 6
		elseif not p:IsA("Model") then
			p:Destroy() -- (importer extras)
		end
	end
	m:SetAttribute("Kit034", kit)
	return m
end

local function setCollide(m: Instance, solid: boolean)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = solid, solid, false
			if solid and p:IsA("MeshPart") then
				pcall(function()
					(p :: MeshPart).CollisionFidelity = Enum.CollisionFidelity.Hull
				end)
			end
		end
	end
end

-- copies the bob tag + attributes from `from` (or its first tagged descendant) onto `to`
local function copyBob(from: Instance, to: Instance)
	local src: Instance? = if CollectionService:HasTag(from, "AmbientBob") then from else nil
	if not src then
		for _, d in from:GetDescendants() do
			if CollectionService:HasTag(d, "AmbientBob") then
				src = d
				break
			end
		end
	end
	if src then
		to:AddTag("AmbientBob")
		for _, a in { "Amp", "Speed", "Phase" } do
			to:SetAttribute(a, src:GetAttribute(a))
		end
	end
end

-- Replaces model/part `old` with the kit, same footprint; returns the new model.
local function swap(old: Instance, kit: string, fit: string, opts: any?): Model?
	if old:GetAttribute("Kit034") then
		return nil
	end
	opts = opts or {}
	local lo, hi = bounds(old)
	local ext = hi - lo
	local size = if fit == "Y" then ext.Y elseif fit == "X" then ext.X elseif fit == "Z" then ext.Z else math.min(ext.X, ext.Z)
	local m = mesh(kit, Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2), size * (opts.scale or 1), fit, opts.yaw, firstColour(old, opts.colourFrom))
	setCollide(m, opts.solid == true)
	copyBob(old, m)
	m.Name = old.Name
	m.Parent = old.Parent
	park(old)
	return m
end

local function build(): string
	local found = ServerStorage:FindFirstChild("Imports034")
	assert(found, "ServerStorage.Imports034 is missing (import assets/export/034 first)")
	imports = found :: Folder
	parkedCount = 0
	local W = workspace:WaitForChild("World")
	local added, swapped = 0, 0
	local function count(m: Model?)
		if m then
			swapped += 1
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					added += 1
				end
			end
		end
	end

	-- Knight's Keep: wall towers
	for _, t in W.KnightsKeep.Walls:GetChildren() do
		if t.Name == "Tower" and t:IsA("Model") then
			count(swap(t, "KeepTower", "Y", { solid = true }))
		end
	end

	-- Sunken Kingdom: coral + kelp everywhere, the palace building
	local SK = W.SunkenKingdom
	for _, d in SK:GetDescendants() do
		if d:IsA("Model") and not d:GetAttribute("Kit034") then
			if d.Name == "Coral" then
				count(swap(d, "Coral", "Y", { colourFrom = "Branch" }))
			elseif d.Name == "Kelp" then
				count(swap(d, "Kelp", "Y", { colourFrom = "Frond" }))
			end
		end
	end
	local palace = SK:FindFirstChild("ShellPalace")
	if palace and not palace:FindFirstChild("ShellPalace") then
		local building = Instance.new("Model")
		building.Name = "OldBuilding"
		for _, p in palace:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Sign" and p.Name ~= "Steps" and p.Name ~= "Glow" then
				p.Parent = building
			end
		end
		building.Parent = palace
		local m = swap(building, "ShellPalace", "XZ", { solid = true })
		if m then
			m.Name = "ShellPalace"
			count(m)
		end
	end

	-- Ember Academy: towers (keep their floating crystal), crystals, books
	local EA = W.EmberAcademy
	for _, tower in EA.WizardTowers:GetChildren() do
		if tower:IsA("Model") and not tower:FindFirstChild("WizardTower") then
			local building = Instance.new("Model")
			building.Name = "OldBuilding"
			for _, p in tower:GetChildren() do
				if p:IsA("BasePart") then
					p.Parent = building
				end
			end
			building.Parent = tower
			local m = swap(building, "WizardTower", "Y", { solid = true })
			if m then
				m.Name = "WizardTower"
				count(m)
			end
		end
	end
	local crystals = {}
	for _, d in EA:GetDescendants() do
		if d:IsA("Model") and (d.Name == "FireCrystal" or d.Name == "FinishCrystal" or d.Name == "SpireCrystal") and not d:GetAttribute("Kit034") then
			table.insert(crystals, d)
		end
	end
	for _, c in crystals do
		count(swap(c, "FireCrystal", "Y", { colourFrom = "Facet" }))
	end
	local books = {}
	for _, d in EA:GetDescendants() do
		if d:IsA("Model") and d.Name == "Spellbook" and not d:GetAttribute("Kit034") and d.Parent ~= imports then
			table.insert(books, d)
		end
	end
	for _, b in books do
		count(swap(b, "Spellbook", "XZ", { colourFrom = "Cover" }))
	end

	-- Spell Run sliding books: skin only. Cover = the invisible box you stand on (made 2 thick, top = where the
	-- pages were), the old pages/spine/rune parked, the mesh book inside the model so it slides with it.
	for _, d in EA.SpellRun:GetDescendants() do
		if d:IsA("Model") and d.Name == "SpellBook" and not d:GetAttribute("Kit034") then
			local cover = d.PrimaryPart :: BasePart
			local pages = d:FindFirstChild("Pages") :: BasePart?
			local top = if pages then pages.Position.Y + pages.Size.Y / 2 else cover.Position.Y + cover.Size.Y / 2
			local colour = cover.Color
			local lo, hi = bounds(d)
			local m = mesh("Spellbook", Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2), hi.X - lo.X, "X", 0, colour)
			setCollide(m, false)
			local skinPages = m:FindFirstChild("Pages") :: BasePart?
			if skinPages then
				m:PivotTo(m:GetPivot() + Vector3.new(0, top - (skinPages.Position.Y + skinPages.Size.Y / 2), 0))
			end
			for _, n in { "Pages", "Spine", "Rune" } do
				local p = d:FindFirstChild(n)
				if p then
					park(p)
				end
			end
			cover.Size = Vector3.new(cover.Size.X, 2, cover.Size.Z)
			cover.CFrame = CFrame.new(cover.Position.X, top - 1, cover.Position.Z) * cover.CFrame.Rotation
			cover.Transparency = 1
			m.Name = "Skin"
			m.Parent = d
			d:SetAttribute("Kit034", "Spellbook")
			count(m)
		end
	end

	return ("Kits: %d props swapped, %d mesh parts added, %d parts parked"):format(swapped, added, parkedCount)
end

return { build = build }
