-- Studio location: StarterPlayer.StarterPlayerScripts.GuardianClient (LocalScript)
-- GuardianClient  (Hub 2b): this client's view of the zone guardians (GuardianService). Display only; nothing is sent.
--   * Moves each guardian (Workspace.Guardians.<zone>) from its GPos / GYaw attributes, smoothed; a rig boss animates
--     itself from its VW_* attributes (its own client script), Aquaris through AquarisChaser.
--   * Attack warnings: the Boss Heist's (shared BossWarnings), in workspace.GuardianFxLocal.
--   * Messages to the carrier: woken, attack callouts, hits (cartoon puff + "-20"), got away, knocked out.
-- Kid-safe: no blood or gore, cartoon effects only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AquarisChaser = require(ReplicatedStorage:WaitForChild("AquarisChaser"))
local BossHeist = require(ReplicatedStorage:WaitForChild("BossHeist"))
local BossWarnings = require(ReplicatedStorage:WaitForChild("BossWarnings"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local GuardianConfig = require(ReplicatedStorage:WaitForChild("GuardianConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("GuardianEvent") :: RemoteEvent

local RED = Color3.fromRGB(255, 70, 90)
local GOLD = Color3.fromRGB(255, 214, 92)
local CYAN = Color3.fromRGB(80, 230, 255)
local WHITE = Color3.new(1, 1, 1)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function bossName(zone: string): string
	local entry = BossHeist.BOSSES[zone]
	local worker = entry and WorkerCatalogue.get(entry.creature)
	return if worker then worker.name else "The guardian"
end
local function zoneName(zone: string): string
	local z = ZoneConfig.get(zone)
	return if z then z.name else "zone"
end

-- Message ----------------------------------------------------------------------------------------------------------
local gui, root = UITheme.gui("Guardian2b", 4)
local big = UITheme.text({
	Name = "Big",
	Text = "",
	Role = "Display",
	TextSize = 40,
	TextWrapped = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(640, 110),
	Parent = root,
})
big.Visible = false
big.TextScaled = true
UITheme.make("UITextSizeConstraint", { MaxTextSize = 42, MinTextSize = 16, Parent = big })
UITheme.scaleWith(big, 0.7, 1.1)
local bigScale = UITheme.make("UIScale", { Parent = big })
local token = 0
local function say(text: string, color: Color3, seconds: number?)
	token += 1
	local mine = token
	big.Text = text
	big.TextColor3 = color
	big.Visible = true
	bigScale.Scale = 0.5
	UITheme.tween(bigScale, UITheme.Motion.Normal, { Scale = 1 }, Enum.EasingStyle.Back)
	gui:SetAttribute("LastMessage", text)
	task.delay(seconds or 2.5, function()
		if mine == token then
			big.Visible = false
		end
	end)
end

-- Guardians --------------------------------------------------------------------------------------------------------
type Shown = { model: Model, entry: any, root: BasePart?, lens: Instance?, aquaris: any, pos: Vector3?, yaw: number }
local shown: { [string]: Shown } = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "GuardianFxLocal"
fxFolder.Parent = workspace

local function lensOf(info: any): Vector3?
	local s = info and info.zone and shown[info.zone]
	local r = s and s.root
	if not (s and r) then
		return nil
	end
	local lens = s.lens
	return if lens and lens:IsA("BasePart") then lens.Position else r.Position + Vector3.new(0, 4, 0)
end
local fx = BossWarnings.new(fxFolder, lensOf, function()
	local folder = workspace:FindFirstChild("Guardians")
	return if folder then { folder } else {}
end)

local function track(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Guardian") ~= true then
		return
	end
	local zone = model.Name
	shown[zone] = { model = model, entry = BossHeist.BOSSES[zone], root = nil, lens = nil, aquaris = nil, pos = nil, yaw = 0 }
end

local function untrack(model: Instance)
	local s = shown[model.Name]
	if s and s.model == model then
		shown[model.Name] = nil
	end
end

local function watch(folder: Instance)
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(untrack)
	for _, c in folder:GetChildren() do
		track(c)
	end
end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "Guardians" then
		watch(c)
	end
end)
if workspace:FindFirstChild("Guardians") then
	watch(workspace.Guardians)
end

local function stepGuardian(s: Shown, dt: number, t: number)
	local model = s.model
	if s.root and not s.root:IsDescendantOf(workspace) then -- streamed out
		s.root, s.lens, s.aquaris, s.pos = nil, nil, nil, nil
	end
	if not s.root then
		local r = model:FindFirstChild("HumanoidRootPart")
		if not (r and r:IsA("BasePart")) then
			return
		end
		s.root = r
		s.lens = if s.entry then model:FindFirstChild(s.entry.lens, true) else nil
		if s.entry and not s.entry.rig then
			s.aquaris = AquarisChaser.new(model)
		end
		model:SetAttribute("ClientBound", true) -- (local: lets a Studio check see the guardian is bound)
	end
	local target = model:GetAttribute("GPos")
	if typeof(target) ~= "Vector3" then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - target).Magnitude > 400 then
		return -- far away: not drawn every frame
	end
	local yaw = model:GetAttribute("GYaw") or 0
	local pos = (s.pos or target):Lerp(target, math.clamp(dt * 9, 0, 1))
	s.pos = pos
	local dyaw = (yaw - s.yaw + math.pi) % (2 * math.pi) - math.pi
	s.yaw += dyaw * math.clamp(dt * 8, 0, 1)
	local place = CFrame.new(pos + Vector3.new(0, model:GetAttribute("RootLift") or 0, 0)) * CFrame.Angles(0, s.yaw, 0)
	local r = s.root :: BasePart
	r.CFrame = if s.aquaris then place * s.aquaris:step(t, place) else place
end

RunService.RenderStepped:Connect(function(dt)
	if ReplicatedStorage:GetAttribute(GuardianConfig.PUBLISHED) ~= true then
		return
	end
	local t = now()
	for _, s in shown do
		stepGuardian(s, dt, t)
	end
	fx:step(t)
end)

-- Events -----------------------------------------------------------------------------------------------------------
local function rootOf(userId: number): BasePart?
	local p = Players:GetPlayerByUserId(userId)
	local c = p and p.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

event.OnClientEvent:Connect(function(kind: string, info: any)
	info = info or {}
	local mine = info.userId == player.UserId or info.targetId == player.UserId
	if kind == "Attack" then
		fx:start(info)
		if mine then
			local entry = BossHeist.BOSSES[info.zone or ""]
			local own = entry and (entry.attacks :: any)[info.kind]
			say(
				if own and own.callout
					then own.callout
					elseif info.kind == "Stomp" then "SHOCKWAVE! JUMP!"
					elseif info.kind == "Laser" then "SWEEP! Step aside!"
					else "Get out of the circle!",
				RED,
				1.4
			)
		end
	elseif kind == "Lock" then
		fx:lock(info.id, info.spot)
	elseif kind == "Cancel" then
		fx:finish(info.id)
	elseif kind == "Wake" then
		if mine then
			say(("%s wants that creature back! Run out of %s!"):format(bossName(info.zone), zoneName(info.zone)), GOLD, 3)
			FxKit.sound("deny")
		end
	elseif kind == "Hit" then
		local r = rootOf(info.userId)
		if r then
			FxKit.burst(r, "puff", CYAN, if FxKit.low() then 6 else 16)
			FxKit.text(r, "-" .. tostring(info.damage or 0), WHITE, 3)
		end
		if mine and not info.ko then
			FxKit.sound("deny")
			if not FxKit.low() then
				FxKit.shake(0.35, 0.25)
			end
		end
	elseif kind == "GiveUp" then
		if mine then
			say(("You got away from %s!"):format(bossName(info.zone)), GOLD, 2.5)
			FxKit.sound("chime")
		end
	elseif kind == "KO" then
		local r = rootOf(info.userId)
		if r then
			FxKit.burst(r, "sparkle", GOLD, if FxKit.low() then 8 else 24)
		end
		if mine then
			say(("Knocked out! Your creature ran back into %s. You kept all your coins."):format(zoneName(info.zone)), RED, 4)
		end
	end
end)
