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
	else -- smoke
		e.Texture = SPRITES.smoke
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(0.5 * scale, 1.5 * scale)
		e.SpreadAngle = Vector2.new(30, 30)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 1.6 * s) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		e.LightEmission = 0.1
	end
	if fx.aura then
		e:SetAttribute("Aura", true)
		e.Enabled = false -- switched on by CreatureAnim.setAura for creatures near the camera
	end
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
		part:SetAttribute("AnimKind", a.kind)
		part:SetAttribute("AnimAxis", a.axis or "X")
		part:SetAttribute("AnimAmp", a.amp)
		part:SetAttribute("AnimSpeed", a.speed or 2)
		part:SetAttribute("AnimPhase", a.phase or 0)
		part:SetAttribute("AnimBase", offset)
		part:SetAttribute("AnimPivot", a.pivot or CFrame.new())
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

	-- body colours
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = (spec.outfit and spec.outfit[part.Name]) or spec.skin
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
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end

	local folder = Instance.new("Folder")
	folder.Name = PROPS_FOLDER
	for _, prop in spec.props do
		local body = bodyOf(model, prop.on)
		if body then
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
		local body = bodyOf(model, fx.on)
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
