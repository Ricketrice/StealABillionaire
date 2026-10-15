-- Studio location: StarterPlayer.StarterPlayerScripts.ZoneAmbience (LocalScript)
-- ZoneAmbience  (Milestone 034): this client's motion and mood for the 034 zones. Display only; nothing is sent.
--   * "AmbientBob" (parts or models; attrs Amp, Speed, Phase): bob up and down around where the map put them
--     (kelp, fish, floating fire crystals, floating spellbooks). Only within BOB_RANGE studs of the camera;
--     with Low effects (029 Settings, player attr LowGraphics) they stay still.
--   * "SpellBook" (Spell Run moving platforms; attrs Axis, Amp, Period, Phase): slide back and forth along Axis,
--     always (even on Low effects: the course needs them) and in step with the server clock, so every racer sees the
--     same book in the same place. The cover's velocity is set too, so a player standing on a book rides with it.
--   * A ghost part with attribute Ambience = "Underwater" (Sunken Kingdom): while the camera is inside it, the
--     sky turns sea-blue (a ColorCorrection tint + denser blue Atmosphere), and back when it leaves.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local BOB_RANGE = 160
local MOOD_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Sine)

-- Bobbing -----------------------------------------------------------------------------------------
type Bob = { home: CFrame, amp: number, speed: number, phase: number, moved: boolean }
local bobs: { [Instance]: Bob } = {}

local function pivotOf(inst: Instance): CFrame?
	if inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return nil
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

local function addBob(inst: Instance)
	local home = pivotOf(inst)
	if home and not bobs[inst] then
		bobs[inst] = {
			home = home,
			amp = tonumber(inst:GetAttribute("Amp")) or 0.5,
			speed = tonumber(inst:GetAttribute("Speed")) or 1,
			phase = tonumber(inst:GetAttribute("Phase")) or 0,
			moved = false,
		}
	end
end

local function removeBob(inst: Instance)
	local b = bobs[inst]
	if b and inst.Parent then
		setPivot(inst, b.home)
	end
	bobs[inst] = nil
end

-- Spellbooks --------------------------------------------------------------------------------------
type Book = { model: Model, home: CFrame, axis: Vector3, amp: number, period: number, phase: number }
local books: { [Model]: Book } = {}

local function addBook(inst: Instance)
	if not inst:IsA("Model") or books[inst] or not inst.PrimaryPart then
		return
	end
	local axis = inst:GetAttribute("Axis")
	books[inst] = {
		model = inst,
		home = inst:GetPivot(),
		axis = if typeof(axis) == "Vector3" and axis.Magnitude > 0 then axis.Unit else Vector3.xAxis,
		amp = tonumber(inst:GetAttribute("Amp")) or 4,
		period = math.max(1, tonumber(inst:GetAttribute("Period")) or 6),
		phase = tonumber(inst:GetAttribute("Phase")) or 0,
	}
end

local function removeBook(inst: Instance)
	books[inst :: Model] = nil
end

local function watch(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end
watch("AmbientBob", addBob, removeBob)
watch("SpellBook", addBook, removeBook)

RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for model, b in books do
		if not model.Parent then
			books[model] = nil
			continue
		end
		local w = 2 * math.pi / b.period
		local offset = math.sin(now * w + b.phase) * b.amp
		model:PivotTo(b.home + b.axis * offset)
		local cover = model.PrimaryPart
		if cover then
			cover.AssemblyLinearVelocity = b.axis * (math.cos(now * w + b.phase) * b.amp * w)
		end
	end

	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local still = player:GetAttribute("LowGraphics") == true
	local t = os.clock()
	for inst, b in bobs do
		if not inst.Parent then
			bobs[inst] = nil
			continue
		end
		local near = eye ~= nil and (b.home.Position - eye).Magnitude < BOB_RANGE
		if near and not still then
			setPivot(inst, b.home + Vector3.new(0, math.sin(t * b.speed + b.phase) * b.amp, 0))
			b.moved = true
		elseif b.moved then
			setPivot(inst, b.home)
			b.moved = false
		end
	end
end)

-- Underwater mood ---------------------------------------------------------------------------------
local volumes: { BasePart } = {}
local function addVolume(inst: Instance)
	if inst:IsA("BasePart") and inst:GetAttribute("Ambience") == "Underwater" and not table.find(volumes, inst) then
		table.insert(volumes, inst)
	end
end
local world = Workspace:WaitForChild("World")
for _, d in world:GetDescendants() do
	addVolume(d)
end
world.DescendantAdded:Connect(addVolume)

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "ZoneAmbienceTint"
tint.Enabled = false
tint.TintColor = Color3.new(1, 1, 1)
tint.Parent = Lighting

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local dry = if atmosphere then { Color = atmosphere.Color, Decay = atmosphere.Decay, Density = atmosphere.Density, Haze = atmosphere.Haze } else nil
local WET = { Color = Color3.fromRGB(110, 190, 230), Decay = Color3.fromRGB(40, 110, 170), Density = 0.42, Haze = 2.2 }

local function inside(part: BasePart, p: Vector3): boolean
	local o = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return math.abs(o.X) <= h.X and math.abs(o.Y) <= h.Y and math.abs(o.Z) <= h.Z
end

local underwater = false
local function setUnderwater(on: boolean)
	if on == underwater then
		return
	end
	underwater = on
	tint.Enabled = true
	TweenService:Create(tint, MOOD_TWEEN, {
		TintColor = if on then Color3.fromRGB(196, 228, 255) else Color3.new(1, 1, 1),
		Saturation = if on then 0.08 else 0,
	}):Play()
	if atmosphere and dry then
		TweenService:Create(atmosphere, MOOD_TWEEN, if on then WET else dry):Play()
	end
end

while true do
	task.wait(0.4)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local wet = false
	if eye then
		for i = #volumes, 1, -1 do
			local v = volumes[i]
			if not v.Parent then
				table.remove(volumes, i)
			elseif inside(v, eye) then
				wet = true
			end
		end
	end
	setUnderwater(wet)
end
