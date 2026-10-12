-- Studio location: ReplicatedStorage.FxKit (ModuleScript)
-- FxKit  (Milestone 028, D8/D12)
-- Client-side effects shared by the 028 scripts (ParadeClient, JuiceClient). One master per effect,
-- built once in code into ReplicatedStorage.FxMasters (on this client only), cloned per use and
-- cleaned up automatically. Particle textures and sounds are the ones that ship with Roblox.
--   FxKit.burst(at, kind, color?, count?)  one-shot particles at a position or part ("sparkle", "puff", "glow")
--   FxKit.attach(part, kind, color?)        a continuous emitter on a part (caller destroys it)
--   FxKit.coins(at, count?)                 a little fountain of gold coins
--   FxKit.text(at, text, color?, height?)   a short pop of text above a position or part
--   FxKit.shake(strength, duration?)        a light camera shake that fades out
--   FxKit.sound(name)                       a short sound (UIKit's set + a few extra)
--   FxKit.low()                             true when the player chose Low effects
-- Low effects: fewer particles, no coins fountain, half-strength shake. Display only.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local FxKit = {}

local player = Players.LocalPlayer
local TEX = "rbxasset://textures/particles/"

function FxKit.low(): boolean
	return player ~= nil and player:GetAttribute("LowEffects") == true
end

-- Masters -------------------------------------------------------------------------------------------------
local masters = ReplicatedStorage:FindFirstChild("FxMasters")
if not masters then
	masters = Instance.new("Folder")
	masters.Name = "FxMasters"
	masters.Parent = ReplicatedStorage
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end
local function master(name: string, props: { [string]: any }): ParticleEmitter
	local existing = masters:FindFirstChild(name)
	if existing then
		return existing :: ParticleEmitter
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = masters
	return e
end

local MASTERS = {
	sparkle = master("Sparkle", {
		Texture = TEX .. "sparkles_main.dds",
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		LightEmission = 1,
		Rate = 0,
		Rotation = NumberRange.new(0, 360),
	}),
	puff = master("Puff", {
		Texture = TEX .. "smoke_main.dds",
		Size = seq(1.6, 3.4),
		Transparency = seq(0.25, 1),
		Lifetime = NumberRange.new(0.45, 0.7),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 250)),
	}),
	glow = master("Glow", {
		Texture = TEX .. "forcefield_glow_main.dds",
		Size = seq(2.5, 5),
		Transparency = seq(0.55, 1),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(0, 0),
		LightEmission = 1,
		Rate = 0,
	}),
	aura = master("Aura", {
		Texture = TEX .. "sparkles_main.dds",
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		LightEmission = 1,
		Rate = 5,
	}),
	shine = master("Shine", { -- gold-trail sparkles and golden walkers
		Texture = TEX .. "sparkles_main.dds",
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Rate = 6,
	}),
}

-- Every one-shot effect hangs off one invisible anchored part on this client.
local anchorPart: BasePart? = nil
local function anchor(): BasePart
	if anchorPart and anchorPart.Parent then
		return anchorPart
	end
	local p = Instance.new("Part")
	p.Name = "FxAnchor"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(0, -500, 0)
	p.Parent = workspace
	anchorPart = p
	return p
end

local function positionOf(at: Vector3 | Instance): Vector3?
	if typeof(at) == "Vector3" then
		return at
	elseif typeof(at) == "Instance" then
		if at:IsA("BasePart") then
			return at.Position
		elseif at:IsA("Attachment") then
			return at.WorldPosition
		elseif at:IsA("Model") then
			return at:GetPivot().Position
		end
	end
	return nil
end

local function holder(at: Vector3 | Instance, life: number): Attachment?
	local pos = positionOf(at)
	if not pos then
		return nil
	end
	local a = Instance.new("Attachment")
	a.Name = "Fx"
	a.Parent = anchor()
	a.WorldPosition = pos
	Debris:AddItem(a, life)
	return a
end

function FxKit.burst(at: Vector3 | Instance, kind: string, color: Color3?, count: number?)
	local m = MASTERS[kind]
	local a = holder(at, 2.5)
	if not (m and a) then
		return
	end
	local e = m:Clone()
	if color then
		e.Color = ColorSequence.new(color)
	end
	e.Parent = a
	local n = count or 20
	e:Emit(if FxKit.low() then math.max(1, math.floor(n / 3)) else n)
end

-- A continuous emitter on `part`. Returns it; destroy it (or the part) to stop.
function FxKit.attach(part: BasePart, kind: string, color: Color3?): ParticleEmitter?
	local m = MASTERS[kind]
	if not m then
		return nil
	end
	local e = m:Clone()
	e.Name = "Fx_" .. kind
	if color then
		e.Color = ColorSequence.new(color)
	end
	if FxKit.low() then
		e.Rate = math.max(1, e.Rate / 3)
	end
	e.Enabled = true
	e.Parent = part
	return e
end

-- Coins -------------------------------------------------------------------------------------------------
local COIN = Color3.fromRGB(255, 205, 70)
function FxKit.coins(at: Vector3 | Instance, count: number?)
	local pos = positionOf(at)
	if not pos or FxKit.low() then
		return
	end
	for i = 1, count or 6 do
		local coin = Instance.new("Part")
		coin.Name = "FxCoin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.12, 0.7, 0.7)
		coin.Color = COIN
		coin.Material = Enum.Material.Neon
		coin.Anchored, coin.CanCollide, coin.CanTouch, coin.CanQuery, coin.CastShadow = true, false, false, false, false
		local angle = (i / (count or 6)) * math.pi * 2 + math.random() * 0.6
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (1.5 + math.random() * 1.5)
		coin.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, math.rad(90))
		coin.Parent = workspace
		local top = pos + out * 0.6 + Vector3.new(0, 3 + math.random() * 1.5, 0)
		local land = pos + out + Vector3.new(0, -1, 0)
		local up = TweenService:Create(
			coin,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(top) * CFrame.Angles(math.random() * 6, angle, math.rad(90)) }
		)
		up:Play()
		up.Completed:Once(function()
			TweenService:Create(
				coin,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = CFrame.new(land) * CFrame.Angles(math.random() * 6, angle, math.rad(90)), Transparency = 1 }
			):Play()
		end)
		Debris:AddItem(coin, 0.8)
	end
end

-- Text pops -------------------------------------------------------------------------------------------------
function FxKit.text(at: Vector3 | Instance, text: string, color: Color3?, height: number?)
	local adornee: Instance? = nil
	if typeof(at) == "Instance" and (at:IsA("BasePart") or at:IsA("Attachment")) then
		adornee = at
	else
		adornee = holder(at, 2)
	end
	UIKit.worldPop(adornee, text, color, height)
end

-- Camera shake ------------------------------------------------------------------------------------------------
local shakeUntil, shakeStrength, shakeLength = 0, 0, 0.4
local shakeBound = false
function FxKit.shake(strength: number, duration: number?)
	shakeLength = duration or 0.4
	shakeUntil = os.clock() + shakeLength
	shakeStrength = if FxKit.low() then strength / 2 else strength
	if shakeBound then
		return
	end
	shakeBound = true
	RunService:BindToRenderStep("FxKitShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		local camera = workspace.CurrentCamera
		if left <= 0 or not camera then
			RunService:UnbindFromRenderStep("FxKitShake")
			shakeBound = false
			return
		end
		local s = shakeStrength * (left / shakeLength)
		camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * s * 0.05)
	end)
end

-- Sounds -------------------------------------------------------------------------------------------------------
-- Extra sounds on top of UIKit's: Roblox's own built-in sounds at other pitches.
local EXTRA = {
	coin = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.45, speed = 2.4 },
	whoosh = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.35, speed = 0.8 },
	poof = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.4, speed = 0.7 },
	safe = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.5, speed = 1.6 },
	golden = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.35, speed = 1.7 },
	hop = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.25, speed = 1.6 },
}
local pool: { [string]: Sound } = {}
function FxKit.sound(name: string)
	local def = EXTRA[name]
	if not def then
		UIKit.sound(name)
		return
	end
	local s = pool[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Fx_" .. name
		s.SoundId = def.id
		s.Volume = def.volume
		s.PlaybackSpeed = def.speed
		s.SoundGroup = UITheme.soundGroup("SFX") -- (029 Settings: Sounds on/off)
		s.Parent = workspace
		pool[name] = s
	end
	s.TimePosition = 0
	s:Play()
end

return FxKit
