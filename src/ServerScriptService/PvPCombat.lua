-- Studio location: ServerScriptService.PvPCombat (ModuleScript)
-- PvPCombat  (Milestone 022)
-- Bats: equip, swings, the special attack and hits, all decided on the server. A client only asks
-- ("Equip", "ChargeStart", "ChargeRelease", "Special", "Loadout"); the server times the charge,
-- checks cooldowns, who is in reach and in front of the attacker from its own copy of the
-- positions, and applies the result. Hits deal no damage: they push the victim back a little, make
-- them briefly immune, and knock loose a stolen worker (PvPSteal.onPlayerHit).
-- No attacks from or into safe zones, at freshly spawned players, or while carrying a worker.
-- The bat skin and the chosen special are kept per player for as long as this server runs (not
-- saved); the skin changes nothing but the bat's look.
-- Replicated player attributes: BatEquipped, BatSkin, BatSpecial, BatCharging (server time the
-- charge started), SpecialReadyAt (server time).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PvPBat = require(ReplicatedStorage:WaitForChild("PvPBat"))
local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig"))
local PvPBase = require(script.Parent:WaitForChild("PvPBase"))
local PvPSteal = require(script.Parent:WaitForChild("PvPSteal"))

local PvPCombat = {}

local TITLE = "Bat"
-- Where the bat sits in the right hand: pointing forward and a little up.
local GRIP = CFrame.new(0, -0.12, -0.05) * CFrame.Angles(math.rad(-75), 0, 0)

local bats: { [Player]: Model } = {}
local readyAt: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local immuneUntil: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local charging: { [Player]: { at: number } } = setmetatable({}, { __mode = "k" }) :: any
local telegraphs: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
local loadouts: { [number]: { skin: string, special: string } } = {} -- by UserId
PvPCombat.stats = { swings = 0, hits = 0, charged = 0, specials = 0, interrupted = 0 }

local function loadoutOf(player: Player): { skin: string, special: string }
	local loadout = loadouts[player.UserId]
	if not loadout then
		loadout = { skin = PvPConfig.DEFAULT_SKIN, special = PvPConfig.DEFAULT_SPECIAL }
		loadouts[player.UserId] = loadout
	end
	return loadout
end
local function publishLoadout(player: Player)
	local loadout = loadoutOf(player)
	player:SetAttribute("BatSkin", loadout.skin)
	player:SetAttribute("BatSpecial", loadout.special)
end
local function cooldowns(player: Player): { [string]: number }
	local ready = readyAt[player] or {}
	readyAt[player] = ready
	return ready
end

local function living(player: Player): (BasePart?, Humanoid?, Model?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid, character
	end
	return nil, nil, nil
end

function PvPCombat.isEquipped(player: Player): boolean
	local bat = bats[player]
	return bat ~= nil and bat.Parent ~= nil and bat.Parent == player.Character
end

function PvPCombat.isImmune(player: Player): boolean
	return (immuneUntil[player] or 0) > os.clock()
end

-- Stops a charge without a swing. reason: "released" | "hit" | "fizzled" | "unequip" | "special"
local function cancelCharge(player: Player, reason: string): boolean
	if not charging[player] then
		return false
	end
	charging[player] = nil
	if player.Parent then
		player:SetAttribute("BatCharging", nil)
	end
	if reason == "hit" then
		local ready = cooldowns(player)
		ready.charged = math.max(ready.charged or 0, os.clock() + PvPConfig.Attacks.charged.interruptCooldown)
		PvPCombat.stats.interrupted += 1
	end
	if reason == "hit" or reason == "fizzled" then
		PvPBase.event(player, "ChargeEnded", { reason = reason })
	end
	return true
end
local function cancelTelegraph(player: Player)
	if telegraphs[player] then
		telegraphs[player] = nil
		PvPBase.broadcast("TelegraphEnd", { user = player.UserId })
	end
end

function PvPCombat.unequip(player: Player)
	cancelCharge(player, "unequip")
	cancelTelegraph(player)
	local bat = bats[player]
	bats[player] = nil
	if bat then
		bat:Destroy()
	end
	if player.Parent and player:GetAttribute("BatEquipped") ~= nil then
		player:SetAttribute("BatEquipped", nil)
	end
end

-- Puts the player's bat in their hand. Returns (equipped, message).
function PvPCombat.equip(player: Player): (boolean, string?)
	if not PvPBase.combat() then
		return false, nil
	end
	local root, _, character = living(player)
	if not (root and character) then
		return false, nil
	end
	if player:GetAttribute("CarryingNPC") == true or player:GetAttribute("HeistCarrying") == true then
		return false, "You can't use your bat while carrying a worker."
	end
	if PvPCombat.isEquipped(player) then
		return true, nil
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not (hand and hand:IsA("BasePart")) then
		return false, nil
	end
	PvPCombat.unequip(player)
	publishLoadout(player)
	local bat = PvPBat.build(loadoutOf(player).skin)
	local grip = bat.PrimaryPart :: BasePart
	bat:PivotTo(hand.CFrame * GRIP)
	local weld = Instance.new("Weld")
	weld.Name = "BatGrip"
	weld.Part0, weld.Part1, weld.C0 = hand, grip, GRIP
	weld.Parent = grip
	bat.Parent = character
	bats[player] = bat
	player:SetAttribute("BatEquipped", true)
	return true, nil
end

-- Players this attack reaches, nearest first. shape "radial" ignores facing.
local function targets(attacker: Player, root: BasePart, def): { Player }
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local found = {}
	for _, other in Players:GetPlayers() do
		local otherRoot = if other ~= attacker then living(other) else nil
		if not otherRoot or PvPCombat.isImmune(other) or PvPBase.spawnSafe(other) or PvPBase.isSafe(otherRoot.Position) then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local flat = offset * Vector3.new(1, 0, 1)
		local inArc = def.shape == "radial" or flat.Magnitude < 1.5 or flat.Unit:Dot(look) >= (def.arcDot or 0)
		if flat.Magnitude <= def.range and math.abs(offset.Y) <= def.height and inArc then
			table.insert(found, { player = other, distance = flat.Magnitude })
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local list = {}
	for i = 1, math.min(#found, def.maxTargets) do
		list[i] = found[i].player
	end
	return list
end

-- A short, capped shove: a velocity held for a moment, then removed. No ragdoll, no spin.
local function knockback(root: BasePart, velocity: Vector3, duration: number)
	local old = root:FindFirstChild("PvPKnockback")
	if old then
		old:Destroy()
	end
	local attachment = root:FindFirstChild("RootAttachment")
	if not (attachment and attachment:IsA("Attachment")) then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "PvPKnockback"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = root.AssemblyMass * 600
	push.Parent = root
	Debris:AddItem(push, duration)
end

-- Applies one hit. `from` is where the push comes from.
local function hit(attacker: Player, victim: Player, def, kind: string, from: Vector3)
	local root = living(victim)
	if not root then
		return
	end
	immuneUntil[victim] = os.clock() + def.immunity
	cancelCharge(victim, "hit") -- a charge can be interrupted
	local away = (root.Position - from) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.05 then away.Unit else Vector3.new(0, 0, -1)
	knockback(root, away * def.knockback + Vector3.new(0, def.lift, 0), def.duration)
	PvPCombat.stats.hits += 1
	local dropped = PvPSteal.onPlayerHit(victim, attacker)
	PvPBase.broadcast("Hit", { victim = victim.UserId, attacker = attacker.UserId, kind = kind, direction = away, dropped = dropped })
end

-- Whether this player may attack right now. Returns (ok, root, message).
local function canAttack(player: Player): (boolean, BasePart?, string?)
	if not PvPBase.combat() then
		return false, nil, nil
	end
	local root = living(player)
	if not (root and PvPCombat.isEquipped(player)) then
		return false, nil, nil
	end
	if player:GetAttribute("CarryingNPC") == true or player:GetAttribute("HeistCarrying") == true then
		return false, nil, "You can't attack while carrying a worker."
	end
	if PvPBase.isSafe(root.Position) then
		return false, nil, "No fighting in the safe zone."
	end
	return true, root, nil
end

-- One swing of `kind` ("basic" | "charged"). Returns (swung, message).
local function swing(player: Player, kind: string): (boolean, string?)
	local def = PvPConfig.Attacks[kind]
	local ok, _, message = canAttack(player)
	if not ok then
		return false, message
	end
	if telegraphs[player] then
		return false, nil
	end
	local now = os.clock()
	local ready = cooldowns(player)
	if now < (ready[kind] or 0) then
		return false, nil -- still cooling down: ignored quietly
	end
	ready[kind] = now + def.cooldown
	if kind == "charged" then
		ready.basic = math.max(ready.basic or 0, now + PvPConfig.Attacks.basic.cooldown)
		PvPCombat.stats.charged += 1
	end
	PvPBase.endSpawnSafe(player)
	PvPCombat.stats.swings += 1
	PvPBase.broadcast("Swing", { user = player.UserId, kind = kind })
	task.delay(def.windup, function()
		local stillOk, root = canAttack(player)
		if stillOk and root then
			for _, victim in targets(player, root, def) do
				hit(player, victim, def, kind, root.Position)
			end
		end
	end)
	return true, nil
end

-- A basic swing asked for directly. Returns (swung, message).
function PvPCombat.attack(player: Player, kind: any): (boolean, string?)
	if kind ~= "basic" or charging[player] then
		return false, nil
	end
	return swing(player, "basic")
end

-- The attack input went down: the charge is timed here, never by the client.
function PvPCombat.chargeStart(player: Player): (boolean, string?)
	local ok, _, message = canAttack(player)
	if not ok then
		return false, message
	end
	if charging[player] or telegraphs[player] then
		return false, nil
	end
	local entry = { at = os.clock() }
	charging[player] = entry
	PvPBase.endSpawnSafe(player)
	player:SetAttribute("BatCharging", workspace:GetServerTimeNow())
	task.delay(PvPConfig.Attacks.charged.maxCharge, function()
		if charging[player] == entry then
			cancelCharge(player, "fizzled") -- held too long
		end
	end)
	return true, nil
end

-- The attack input was let go: a charged swing if it was held long enough, otherwise a basic one.
-- Returns (swung, message, kind).
function PvPCombat.chargeRelease(player: Player): (boolean, string?, string?)
	local entry = charging[player]
	if not entry then
		return false, nil, nil
	end
	local held = os.clock() - entry.at
	cancelCharge(player, "released")
	local def = PvPConfig.Attacks.charged
	local kind = if held >= def.chargeTime - def.chargeTolerance and os.clock() >= (cooldowns(player).charged or 0) then "charged" else "basic"
	local swung, message = swing(player, kind)
	return swung, message, kind
end

function PvPCombat.isCharging(player: Player): boolean
	return charging[player] ~= nil
end

-- The player's chosen special: marked on the attacker for `telegraph` seconds, then it lands
-- wherever they stand at that moment. Returns (started, message).
function PvPCombat.special(player: Player): (boolean, string?)
	local ok, _, message = canAttack(player)
	if not ok then
		return false, message
	end
	if telegraphs[player] then
		return false, nil
	end
	local name = loadoutOf(player).special
	local def = PvPConfig.Specials[name]
	local now = os.clock()
	local ready = cooldowns(player)
	if not def or now < (ready.special or 0) then
		return false, nil
	end
	cancelCharge(player, "special")
	ready.special = now + def.cooldown -- one cooldown for all specials: switching doesn't reset it
	player:SetAttribute("SpecialReadyAt", workspace:GetServerTimeNow() + def.cooldown)
	PvPBase.endSpawnSafe(player)
	PvPCombat.stats.specials += 1
	local token = {}
	telegraphs[player] = token
	PvPBase.broadcast("Telegraph", { user = player.UserId, special = name, duration = def.telegraph })
	task.delay(def.telegraph, function()
		if telegraphs[player] ~= token then
			return
		end
		telegraphs[player] = nil
		local stillOk, root = canAttack(player)
		if not (stillOk and root) then
			PvPBase.broadcast("TelegraphEnd", { user = player.UserId })
			return
		end
		local victims = targets(player, root, def)
		PvPBase.broadcast("Special", { user = player.UserId, special = name, hits = #victims })
		for _, victim in victims do
			hit(player, victim, def, name, root.Position)
		end
	end)
	return true, nil
end

-- Bat look ("skin") or special attack ("special"). Returns whether the choice was accepted.
function PvPCombat.setLoadout(player: Player, what: any, value: any): boolean
	if not PvPBase.combat() or type(value) ~= "string" then
		return false
	end
	local loadout = loadoutOf(player)
	if what == "skin" and table.find(PvPConfig.SKIN_ORDER, value) then
		if loadout.skin ~= value then
			loadout.skin = value
			if PvPCombat.isEquipped(player) then
				PvPCombat.unequip(player)
				PvPCombat.equip(player)
			end
		end
	elseif what == "special" and table.find(PvPConfig.SPECIAL_ORDER, value) then
		loadout.special = value
	else
		return false
	end
	publishLoadout(player)
	return true
end
function PvPCombat.getLoadout(player: Player): (string, string)
	local loadout = loadoutOf(player)
	return loadout.skin, loadout.special
end

PvPCombat._test = { immuneUntil = immuneUntil, readyAt = readyAt, bats = bats, charging = charging, loadouts = loadouts }

local started = false
function PvPCombat.start()
	if started then
		return
	end
	started = true

	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal("CarryingNPC"):Connect(function()
			if player:GetAttribute("CarryingNPC") == true then
				PvPCombat.unequip(player) -- hands full
			end
		end)
		player:GetAttributeChangedSignal("HeistCarrying"):Connect(function()
			if player:GetAttribute("HeistCarrying") == true then
				PvPCombat.unequip(player) -- hands full (Boss Capsule, 032)
			end
		end)
		player.CharacterRemoving:Connect(function()
			PvPCombat.unequip(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(PvPCombat.unequip)
	PvPBase.FlagsChanged:Connect(function()
		if not PvPBase.combat() then
			for player in bats do
				PvPCombat.unequip(player)
			end
			for _, player in Players:GetPlayers() do
				for _, attribute in { "BatSkin", "BatSpecial", "BatCharging", "SpecialReadyAt" } do
					player:SetAttribute(attribute, nil)
				end
			end
		end
	end)

	PvPBase.onAction("Equip", function(player, on)
		if on == true then
			local ok, message = PvPCombat.equip(player)
			if not ok and message then
				PvPBase.notify(player, false, message, TITLE)
			end
		elseif on == false then
			PvPCombat.unequip(player)
		end
	end)
	local function report(player: Player, ok: boolean, message: string?)
		if not ok and message then
			PvPBase.notify(player, false, message, TITLE)
		end
	end
	PvPBase.onAction("Attack", function(player, kind)
		report(player, PvPCombat.attack(player, kind))
	end)
	PvPBase.onAction("ChargeStart", function(player)
		report(player, PvPCombat.chargeStart(player))
	end)
	PvPBase.onAction("ChargeRelease", function(player)
		report(player, PvPCombat.chargeRelease(player))
	end)
	PvPBase.onAction("Special", function(player)
		report(player, PvPCombat.special(player))
	end)
	PvPBase.onAction("Loadout", function(player, what, value)
		PvPCombat.setLoadout(player, what, value)
	end)
end

return PvPCombat
