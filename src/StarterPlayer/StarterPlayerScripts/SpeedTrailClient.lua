-- Studio location: StarterPlayer.StarterPlayerScripts.SpeedTrailClient (LocalScript)
-- SpeedTrailClient  (Milestone 032, D24) -- draws every player's equipped speed trail (player attribute
-- SpeedTrail, while ReplicatedStorage.SpeedOn). Client only and cheap: one Trail ribbon behind the character
-- plus a few particles of the trail's kind while they are moving. Low effects: a thin, short ribbon and no
-- particles. Characters more than CULL studs from the camera get none.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local SpeedConfig = require(ReplicatedStorage:WaitForChild("SpeedConfig"))

local CULL = 160
local TEX = "rbxasset://textures/particles/"

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Ribbon colours and particle look per trail.
local LOOK = {
	bubble = { texture = TEX .. "forcefield_glow_main.dds", size = 0.9, rate = 6 },
	leaf = { texture = TEX .. "sparkles_main.dds", size = 0.8, rate = 6, spin = true },
	star = { texture = TEX .. "sparkles_main.dds", size = 1.0, rate = 8 },
	comet = { texture = TEX .. "fire_sparks_main.dds", size = 0.7, rate = 10 },
	rainbow = { texture = TEX .. "sparkles_main.dds", size = 0.9, rate = 10, rainbow = true },
	gold = { texture = TEX .. "sparkles_main.dds", size = 1.1, rate = 12 },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 235, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 220, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 100, 240)),
})

type Fx = { id: string, low: boolean, root: BasePart, objects: { Instance }, emitter: ParticleEmitter? }
local active: { [Player]: Fx } = {}

local function clear(p: Player)
	local fx = active[p]
	if fx then
		active[p] = nil
		for _, o in fx.objects do
			o:Destroy()
		end
	end
end

local function build(p: Player, id: string, root: BasePart, low: boolean): Fx
	local def = SpeedConfig.BY_ID[id]
	local look = LOOK[id] or LOOK.star
	local colour = rgb(def.colour)
	local a0 = Instance.new("Attachment")
	a0.Name = "SpeedTrailTop"
	a0.Position = Vector3.new(0, 0.6, 0.4)
	local a1 = Instance.new("Attachment")
	a1.Name = "SpeedTrailBottom"
	a1.Position = Vector3.new(0, if low then 0 else -1.6, 0.4)
	a0.Parent, a1.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = if low then 0.25 else 0.45
	trail.MinLength = 0.2
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Color = if look.rainbow then RAINBOW else ColorSequence.new(colour, colour:Lerp(Color3.new(1, 1, 1), 0.5))
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = root
	local objects: { Instance } = { a0, a1, trail }
	local emitter = nil
	if not low then
		local e = Instance.new("ParticleEmitter")
		e.Name = "SpeedTrailBits"
		e.Texture = look.texture
		e.Color = if look.rainbow then RAINBOW else ColorSequence.new(colour)
		e.LightEmission = 0.7
		e.Size = NumberSequence.new(look.size, 0)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Rate = 0
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = if look.spin then NumberRange.new(-180, 180) else NumberRange.new(0, 0)
		e.Parent = a1
		emitter = e
		table.insert(objects, e)
	end
	return { id = id, low = low, root = root, objects = objects, emitter = emitter }
end

local function update()
	local speedOn = ReplicatedStorage:GetAttribute(SpeedConfig.PUBLISHED) == true
	local low = FxKit.low()
	local cam = workspace.CurrentCamera
	for _, p in Players:GetPlayers() do
		local id = p:GetAttribute("SpeedTrail")
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local want = speedOn and type(id) == "string" and SpeedConfig.BY_ID[id] ~= nil and root ~= nil and root:IsA("BasePart")
		if want and cam and (cam.CFrame.Position - (root :: BasePart).Position).Magnitude > CULL then
			want = false
		end
		local fx = active[p]
		if fx and (not want or fx.id ~= id or fx.low ~= low or fx.root ~= root) then
			clear(p)
			fx = nil
		end
		if want and not fx then
			fx = build(p, id, root :: BasePart, low)
			active[p] = fx
		end
		if fx and fx.emitter then
			local moving = (fx.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 4
			local look = LOOK[fx.id] or LOOK.star
			fx.emitter.Rate = if moving then look.rate else 0
		end
	end
	for p in active do
		if not p.Parent then
			clear(p)
		end
	end
end

while true do
	update()
	task.wait(0.2)
end
