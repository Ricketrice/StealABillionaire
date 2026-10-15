-- Studio location: ServerScriptService.CreatureBuilder (ModuleScript)
-- CreatureBuilder  (Milestone 035)
-- Builds every creature of ReplicatedStorage.CreatureSpecs ONCE into ReplicatedStorage.CreatureModels (one R15
-- model per id, the MysteryNPC rig recoloured + welded props + particle auras). That folder is the single source:
-- CustomWorkerRigs (wander / carry / pad), WorkerPreview (Index, reveal card, inventory, book) and the parade
-- reveal all clone from it, so a creature looks the same everywhere. Humanoid, Animate and the R15 part names are
-- kept, so carrying, placement, income and animation work unchanged.
-- Idle motion + aura range are driven on the client (StarterPlayerScripts.CreatureClient) from the attributes
-- written on each animated prop (Anim*). Prop offsets are in the body part's own space.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CreatureSpecs = require(ReplicatedStorage:WaitForChild("CreatureSpecs"))

local CreatureBuilder = {}

CreatureBuilder.FOLDER = "CreatureModels"
CreatureBuilder.TAG = "Creature"
local PROPS_FOLDER = "CreatureProps"

local rad = math.rad
local NOOB_YELLOW = Color3.fromRGB(245, 205, 48)
local INK = Color3.fromRGB(14, 14, 20)
-- The classic face, in head space (front = -Z): two big oval eyes and a crescent smile (a black disc with a yellow disc
-- laid over its upper part).
local FACE: { CreatureSpecs.Prop } = {
	{ n = "FaceEyeL", on = "Head", shape = "Ball", size = Vector3.new(0.22, 0.36, 0.14), at = CFrame.new(-0.28, 0.12, -0.6), color = INK },
	{ n = "FaceEyeR", on = "Head", shape = "Ball", size = Vector3.new(0.22, 0.36, 0.14), at = CFrame.new(0.28, 0.12, -0.6), color = INK },
	{ n = "FaceSmile", on = "Head", shape = "Disc", size = Vector3.new(0.58, 0.58, 0.06), at = CFrame.new(0, -0.2, -0.6), color = INK },
	{ n = "FaceSmileMask", on = "Head", shape = "Disc", size = Vector3.new(0.58, 0.58, 0.06), at = CFrame.new(0, -0.08, -0.612), color = NOOB_YELLOW },
}
-- The stern face (Legendary, Secret, Epic knights): the same big dark eyes, brows angled down toward the nose, a flat mouth.
local STERN: { CreatureSpecs.Prop } = {
	{ n = "FaceEyeL", on = "Head", shape = "Ball", size = Vector3.new(0.22, 0.32, 0.14), at = CFrame.new(-0.28, 0.08, -0.6), color = INK },
	{ n = "FaceEyeR", on = "Head", shape = "Ball", size = Vector3.new(0.22, 0.32, 0.14), at = CFrame.new(0.28, 0.08, -0.6), color = INK },
	{ n = "FaceBrowL", on = "Head", shape = "Block", size = Vector3.new(0.4, 0.09, 0.07), at = CFrame.new(-0.28, 0.33, -0.6) * CFrame.Angles(0, 0, rad(-24)), color = INK },
	{ n = "FaceBrowR", on = "Head", shape = "Block", size = Vector3.new(0.4, 0.09, 0.07), at = CFrame.new(0.28, 0.33, -0.6) * CFrame.Angles(0, 0, rad(24)), color = INK },
	{ n = "FaceMouth", on = "Head", shape = "Block", size = Vector3.new(0.42, 0.08, 0.07), at = CFrame.new(0, -0.28, -0.6), color = INK },
}

local SPRITES = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	flame = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- Emitter looks. Sizes are for scale 1; the builder multiplies by the creature's scale.
local function makeEmitter(fx: CreatureSpecs.Fx, scale: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fx_" .. fx.kind
	e.Color = ColorSequence.new(fx.color)
	e.LightEmission = 1
	e.LockedToPart = false
	e.Rate = (fx.rate or 4) * (if fx.aura then 1 else 1)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	local s = (fx.size or 1) * scale
	if fx.kind == "spark" then
		e.Texture = SPRITES.spark
		e.Lifetime = NumberRange.new(0.7, 1.4)
		e.Speed = NumberRange.new(2 * scale, 5 * scale)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 0) })
		e.Acceleration = Vector3.new(0, 2 * scale, 0)
	elseif fx.kind == "flame" then
		e.Texture = SPRITES.flame
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(1 * scale, 2.5 * scale)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0 * s), NumberSequenceKeypoint.new(1, 0) })
		e.Acceleration = Vector3.new(0, 4 * scale, 0)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	elseif fx.kind == "puff" then -- tiny breath puffs forward (-Z of the part)
		e.Texture = SPRITES.flame
		e.EmissionDirection = Enum.NormalId.Front
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(3 * scale, 5 * scale)
		e.SpreadAngle = Vector2.new(10, 10)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 * s), NumberSequenceKeypoint.new(1, 0.7 * s) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Shape = Enum.ParticleEmitterShape.Box
	elseif fx.kind == "bubble" then
		e.Texture = SPRITES.spark
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(0.8 * scale, 1.8 * scale)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * s), NumberSequenceKeypoint.new(1, 0.6 * s) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Acceleration = Vector3.new(0, 3 * scale, 0)
		e.LightEmission = 0.5
	elseif fx.kind == "drop" then -- falling water droplets
		e.Texture = SPRITES.spark
		e.Lifetime = NumberRange.new(0.9, 1.5)
		e.Speed = NumberRange.new(0.5 * scale, 1.5 * scale)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * s), NumberSequenceKeypoint.new(1, 0.1 * s) })
		e.Acceleration = Vector3.new(0, -14 * scale, 0)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
		e.LightEmission = 0.4
	else -- smoke
		e.Texture = SPRITES.smoke
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(0.5 * scale, 1.5 * scale)
		e.SpreadAngle = Vector2.new(30, 30)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 1.6 * s) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		e.LightEmission = 0.1
	end
	e:SetAttribute("Aura", true) -- every emitter is gated by distance (CreatureAnim.setAura), not only the rarity aura
	e.Enabled = false
	return e
end

local function meshMaster(name: string): MeshPart?
	local imports = ServerStorage:FindFirstChild("Imports035")
	local found = imports and imports:FindFirstChild(name, true)
	if found and found:IsA("MeshPart") then
		return found
	end
	return found and found:FindFirstChildWhichIsA("MeshPart", true)
end

local function setAnim(part: BasePart, a: any, offset: CFrame)
	part:SetAttribute("AnimKind", a.kind)
	part:SetAttribute("AnimAxis", a.axis or "X")
	part:SetAttribute("AnimAmp", a.amp)
	part:SetAttribute("AnimSpeed", a.speed or 2)
	part:SetAttribute("AnimPhase", a.phase or 0)
	part:SetAttribute("AnimBase", offset)
	part:SetAttribute("AnimPivot", a.pivot or CFrame.new())
end

-- A Blender model from ServerStorage.Imports035 (prop.model, e.g. DragonHead): every MeshPart is welded to `body`, placed
-- relative to the model's "<Name>_Anchor" part (its origin) at prop.at and scaled so the model is `fit.size` studs long
-- along `fit.axis` (X / Y / Z, in the model's own axes). prop.colors[<part name>] = Color3 or { color, neon, trans, mat };
-- prop.partAnim[<part name>] overrides prop.anim for one part (the jaw). Returns the parts (empty if the import is missing).
local function makeModelParts(prop: any, body: BasePart): { BasePart }
	local out: { BasePart } = {}
	local imports = ServerStorage:FindFirstChild("Imports035")
	local src = imports and imports:FindFirstChild(prop.model, true)
	if not src then
		warn("[CreatureBuilder] missing import", prop.model)
		return out
	end
	local meshes: { BasePart } = {}
	local anchor: BasePart? = nil
	for _, d in src:GetDescendants() do
		if d:IsA("MeshPart") then
			if d.Name:match("Anchor$") then
				anchor = d
			else
				table.insert(meshes, d)
			end
		end
	end
	if not anchor or #meshes == 0 then
		warn("[CreatureBuilder] import", prop.model, "needs an Anchor part and at least one mesh")
		return out
	end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, m in meshes do
		local rel = anchor.CFrame:ToObjectSpace(m.CFrame)
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local c = rel * Vector3.new(m.Size.X * sx, m.Size.Y * sy, m.Size.Z * sz)
					lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
					hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
				end
			end
		end
	end
	local ext = hi - lo
	local fit = prop.fit or { axis = "Z", size = ext.Z }
	local k = fit.size / (if fit.axis == "X" then ext.X elseif fit.axis == "Y" then ext.Y else ext.Z)
	for _, m in meshes do
		local key = m.Name:match("_(.+)$") or m.Name
		local look: any = prop.colors and prop.colors[key]
		if look and type(look) == "table" and look.skip then
			continue -- a mesh part the spec replaces with plain parts
		end
		local part = m:Clone()
		for _, c in part:GetChildren() do
			if not (c:IsA("SpecialMesh") or c:IsA("SurfaceAppearance")) then
				c:Destroy()
			end
		end
		part.Name = key
		part.Size = m.Size * k
		local rel = anchor.CFrame:ToObjectSpace(m.CFrame)
		local offset = prop.at * CFrame.new(rel.Position * k) * rel.Rotation
		part.CFrame = body.CFrame * offset
		if typeof(look) == "Color3" then
			look = { color = look }
		end
		part.Color = look and look.color or part.Color
		part.Transparency = look and look.trans or 0
		part.Material = if look and look.neon then Enum.Material.Neon else (look and look.mat or Enum.Material.SmoothPlastic)
		part.TextureID = ""
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.Anchored = false
		part.CastShadow = false
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1, weld.C0 = body, part, offset
		weld.Parent = part
		local a = (prop.partAnim and prop.partAnim[key]) or prop.anim
		if a then
			setAnim(part, a, offset)
		end
		table.insert(out, part)
	end
	return out
end

local function makeProp(prop: CreatureSpecs.Prop, body: BasePart): BasePart?
	local part: BasePart
	local offset = prop.at
	local shape = prop.shape or "Block"
	if prop.mesh then
		local master = meshMaster(prop.mesh)
		if not master then
			warn("[CreatureBuilder] missing mesh", prop.mesh)
			return nil
		end
		local m = master:Clone()
		for _, c in m:GetChildren() do
			if not (c:IsA("SpecialMesh") or c:IsA("SurfaceAppearance")) then
				c:Destroy()
			end
		end
		m.Size = prop.size
		part = m
	else
		local p = Instance.new("Part")
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = prop.size
		elseif shape == "Cylinder" then -- Roblox cylinders run along X; stand it up
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(prop.size.Y, prop.size.X, prop.size.Z)
			offset *= CFrame.Angles(0, 0, rad(90))
		elseif shape == "Disc" then -- axis turned to face forward
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(prop.size.Z, prop.size.Y, prop.size.X)
			offset *= CFrame.Angles(0, rad(90), 0)
		elseif shape == "Wedge" then
			local w = Instance.new("WedgePart")
			w.Size = prop.size
			p = w :: any
		else
			p.Size = prop.size
		end
		part = p
	end
	part.Name = prop.n or prop.on
	part.Color = prop.color
	part.Transparency = prop.trans or 0
	part.Material = if prop.neon then Enum.Material.Neon else (prop.mat or Enum.Material.SmoothPlastic)
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = prop.size.Magnitude > 1.6
	part.CFrame = body.CFrame * offset

	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = body, part, offset
	weld.Parent = part

	local a = prop.anim
	if a then
		setAnim(part, a, offset)
	end
	return part
end

local function bodyOf(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- Builds one creature model from its spec.
function CreatureBuilder.build(id: string, spec: CreatureSpecs.Spec): Model
	local source = ServerStorage:WaitForChild("NPCModels"):WaitForChild("MysteryNPC") :: Model
	local model = source:Clone()
	model.Name = id
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child:IsA("HumanoidDescription") then
			child:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	for _, d in humanoid:GetChildren() do
		if d:IsA("HumanoidDescription") then
			d:Destroy()
		end
	end

	-- Noob body (owner LOOK RULE): the R15 meshes become plain blocks of the same size and name (same joints, same
	-- part count), yellow head, solid colours from the outfit, never a skin tone. Non-humanoids keep their R15 body.
	local noob = not spec.own and not spec.hideBody
	if noob then
		local joints = {}
		for _, d in model:GetDescendants() do
			if d:IsA("JointInstance") and d.Part0 and d.Part1 then
				table.insert(joints, { d, d.Part0.Name, d.Part1.Name })
			end
		end
		for _, old in model:GetChildren() do
			if old:IsA("MeshPart") and old.Name ~= "Head" and old.Name ~= "HumanoidRootPart" then
				local p = Instance.new("Part")
				p.Name, p.Size, p.CFrame = old.Name, old.Size, old.CFrame
				p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.Anchored = old.CanCollide, old.CanTouch, old.CanQuery, old.Massless, old.Anchored
				p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				for _, c in old:GetChildren() do
					if c:IsA("BaseWrap") or c:IsA("WrapTarget") then -- layered-clothing cages only work on a MeshPart
						c:Destroy()
					else
						c.Parent = p
					end
				end
				p.Parent = model
				old:Destroy()
			end
		end
		for _, j in joints do
			local a, b = model:FindFirstChild(j[2]), model:FindFirstChild(j[3])
			if a and b then
				j[1].Part0, j[1].Part1 = a, b
			end
		end
		-- Classic noob proportions: torso 2x2x1 (upper 1.6 + lower 0.4), arms and legs 1x2x1 hanging straight, a head a little
		-- wider than tall. The parts are re-sized and re-stacked and every joint attachment moved to the new seam, so the
		-- rig still animates.
		local function part(name: string): BasePart
			return model:FindFirstChild(name) :: BasePart
		end
		local lt, ut, head0 = part("LowerTorso"), part("UpperTorso"), part("Head")
		local ltC = lt.Position
		local sign = {} :: { [string]: number }
		for _, side in { "Left", "Right" } do
			sign[side] = if part(side .. "UpperArm").Position.X >= ut.Position.X then 1 else -1
		end
		local function put(name: string, size: Vector3, center: Vector3)
			local pt = part(name)
			pt.Size = size
			pt.CFrame = CFrame.new(center) * pt.CFrame.Rotation
		end
		local utC = Vector3.new(ltC.X, ltC.Y + 1.0, ltC.Z)
		local utTop = utC.Y + 0.8
		local ltBottom = ltC.Y - 0.2
		put("LowerTorso", Vector3.new(2, 0.4, 1), ltC)
		put("UpperTorso", Vector3.new(2, 1.6, 1), utC)
		put("Head", Vector3.new(1.32, 1.2, 1.2), Vector3.new(utC.X, utTop + 0.6, utC.Z))
		local joint = {} :: { [string]: Vector3 }
		joint.Waist = Vector3.new(utC.X, ltC.Y + 0.2, utC.Z)
		joint.Neck = Vector3.new(utC.X, utTop, utC.Z)
		for _, side in { "Left", "Right" } do
			local sx = utC.X + sign[side] * 1.5
			local lx = utC.X + sign[side] * 0.5
			put(side .. "UpperArm", Vector3.new(1, 0.9, 1), Vector3.new(sx, utTop - 0.45, utC.Z))
			put(side .. "LowerArm", Vector3.new(1, 0.8, 1), Vector3.new(sx, utTop - 1.3, utC.Z))
			put(side .. "Hand", Vector3.new(1, 0.3, 1), Vector3.new(sx, utTop - 1.85, utC.Z))
			joint[side .. "Shoulder"] = Vector3.new(sx, utTop - 0.3, utC.Z)
			joint[side .. "Elbow"] = Vector3.new(sx, utTop - 0.9, utC.Z)
			joint[side .. "Wrist"] = Vector3.new(sx, utTop - 1.7, utC.Z)
			put(side .. "UpperLeg", Vector3.new(1, 0.9, 1), Vector3.new(lx, ltBottom - 0.45, utC.Z))
			put(side .. "LowerLeg", Vector3.new(1, 0.75, 1), Vector3.new(lx, ltBottom - 1.275, utC.Z))
			put(side .. "Foot", Vector3.new(1, 0.35, 1.2), Vector3.new(lx, ltBottom - 1.825, utC.Z - 0.1))
			joint[side .. "Hip"] = Vector3.new(lx, ltBottom, utC.Z)
			joint[side .. "Knee"] = Vector3.new(lx, ltBottom - 0.9, utC.Z)
			joint[side .. "Ankle"] = Vector3.new(lx, ltBottom - 1.65, utC.Z)
		end
		for _, c in model:GetDescendants() do
			if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
				local at0, at1 = c.Attachment0, c.Attachment1
				local world = joint[c.Name]
				if c.Name == "Root" then
					world = at0.WorldPosition -- the root part did not move
				end
				if world then
					local p0, p1 = at0.Parent :: BasePart, at1.Parent :: BasePart
					at0.Position = p0.CFrame:PointToObjectSpace(world)
					at1.Position = p1.CFrame:PointToObjectSpace(world)
				end
			end
		end
		head0.Name = "Head"
	end
	local out = spec.outfit or {}
	local top = out.UpperTorso or Color3.fromRGB(80, 120, 200)
	local function pick(name: string, fallback: Color3): Color3 -- skin-toned outfit entries (hands, bare arms) fall back
		local c = out[name]
		if not c or c == spec.skin then
			return fallback
		end
		return c
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if noob then
				local arm = pick("LeftUpperArm", top)
				local leg = pick("LeftUpperLeg", out.LowerTorso or top)
				local fallback = if part.Name:find("Arm") or part.Name:find("Hand") then arm elseif part.Name:find("Leg") or part.Name:find("Foot") then leg else top
				part.Color = if part.Name == "Head" then NOOB_YELLOW else pick(part.Name, fallback)
			else
				part.Color = out[part.Name] or spec.skin
			end
			part.Material = Enum.Material.SmoothPlastic
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
		end
	end
	local head = bodyOf(model, "Head")
	if head then
		for _, d in head:GetChildren() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
		if not noob then
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png"
			face.Face = Enum.NormalId.Front
			face.Parent = head
		end
	end

	if spec.hideBody then -- the creature is built entirely from props (seahorse, serpent); the rig only walks it
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 1
			end
		end
		local face = head and head:FindFirstChild("face")
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = PROPS_FOLDER
	local all: { CreatureSpecs.Prop } = table.clone(spec.props)
	if noob then -- a clear face made of parts (renders in the card viewports too): big black eyes + a smile, or stern brows + flat mouth
		for _, f in (if spec.face == "stern" then STERN else FACE) do
			table.insert(all, f)
		end
	end
	for _, prop in all do
		local body = bodyOf(model, prop.on)
		if body and (prop :: any).model then
			for _, part in makeModelParts(prop, body) do
				part.Parent = folder
			end
		elseif body then
			local part = makeProp(prop, body)
			if part then
				part.Parent = folder
			end
		else
			warn("[CreatureBuilder]", id, "prop needs missing body part", prop.on)
		end
	end
	folder.Parent = model

	local scale = spec.scale or 1
	for _, fx in spec.fx or {} do
		local body = bodyOf(model, fx.on) or (folder:FindFirstChild(fx.on) :: BasePart?)
		if body then
			local att = Instance.new("Attachment")
			att.Name = "FxAttachment"
			att.Position = fx.at or Vector3.zero
			att.Parent = body
			makeEmitter(fx, scale).Parent = att
		end
	end
	local torso = bodyOf(model, "UpperTorso")
	if spec.light and torso then
		local light = Instance.new("PointLight")
		light.Name = "CreatureGlow"
		light.Color = spec.light
		light.Range = 8 * scale
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = torso
	end
	if spec.halo then
		local lower = bodyOf(model, "LowerTorso")
		local feet = math.huge
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Name:match("Foot$") then
				feet = math.min(feet, p.Position.Y - p.Size.Y / 2)
			end
		end
		if lower and feet < math.huge then
			local ring = makeProp({
				n = "Halo",
				on = "LowerTorso",
				shape = "Cylinder",
				size = Vector3.new(4.4, 0.08, 4.4),
				at = CFrame.new(0, feet - lower.Position.Y + 0.08, 0),
				color = spec.halo,
				neon = true,
				anim = { kind = "spin", axis = "Y", amp = 50 },
			}, lower)
			if ring then
				ring.Transparency = 0.45
				ring.Parent = folder
			end
		end
	end

	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:SetAttribute("CreatureId", id)
	model:SetAttribute("CreatureScale", scale)
	model:SetAttribute("SoundHook", spec.sound) -- Legendary / Secret: a name for the audio pass (no asset yet)
	CollectionService:AddTag(model, CreatureBuilder.TAG)
	return model
end

-- Builds (or rebuilds) every creature in the spec table into ReplicatedStorage.CreatureModels.
function CreatureBuilder.buildAll(): Folder
	local old = ReplicatedStorage:FindFirstChild(CreatureBuilder.FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CreatureBuilder.FOLDER
	for id, spec in CreatureSpecs do
		if type(spec) == "table" then
			local ok, result = pcall(CreatureBuilder.build, id, spec)
			if ok then
				result.Parent = folder
			else
				warn("[CreatureBuilder] couldn't build", id, "-", result)
			end
		end
	end
	folder.Parent = ReplicatedStorage
	return folder
end

CreatureBuilder.buildAll()

return CreatureBuilder
