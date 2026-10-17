-- Studio location: ServerScriptService.SpeedService (ModuleScript)
-- SpeedService  (Milestone 032, D24): the Speed stat and the cash-only speed trails.
-- Walk speed = SpeedConfig.BASE_WALK x (1 + boost of the equipped trail, capped) on foot, and
-- BASE_WALK x (1 + boost x CARRY_BOOST_SHARE) x CARRY while carrying (a worker, a stolen worker or a Boss Capsule). It is re-applied when the character spawns, a trail is equipped and any of
-- the carry attributes change. Racers are left alone: the Royale Race runs everyone at its fixed speed and puts
-- the old speed back afterwards (attributes Racing / RaceFrozen).
-- With SpeedEnabled off nothing changes for anyone, except that a Boss Capsule carrier (HeistCarrying) is slowed
-- like any carrier and set back to the normal walk speed when the carry ends.
-- Trails: SpeedRequest (RemoteFunction) "Buy" id / "Equip" id / "Unequip" / "State"; all checked here. Buying
-- costs cash (CashService.trySpend), equips the trail and starts a save. Buying an owned trail or equipping the
-- equipped one does nothing (safe to re-send). Save: hub.speed = { owned = { id, ... }, on = id? } (optional
-- field, schema stays 3). Published on the player: SpeedTrail (equipped id), SpeedBoost (0..MAX_BOOST),
-- SpeedOwned ("id,id,..."), SpeedHud (number for the HUD, 100 = normal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LaunchFlag = require(game:GetService("ReplicatedStorage"):WaitForChild("LaunchFlag"))
local SpeedConfig = require(ReplicatedStorage:WaitForChild("SpeedConfig"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local SpeedService = {}

local CARRY = 0.85 -- the same slowdown as NPCCarry's CARRY_SPEED_MULTIPLIER
local CARRY_ATTRIBUTES = { "CarryingNPC", "CarryingStolen", "HeistCarrying" }

function SpeedService.enabled(): boolean
	return LaunchFlag(SpeedConfig.ENABLED, SpeedConfig.STUDIO_ATTRIBUTE)
end

local request = ReplicatedStorage:FindFirstChild("SpeedRequest") :: RemoteFunction?
if not request then
	local r = Instance.new("RemoteFunction")
	r.Name = "SpeedRequest"
	r.Parent = ReplicatedStorage
	request = r
end

SpeedService.stats = { bought = 0, equipped = 0, refused = 0 }

-- hub.speed, cleaned (unknown or repeated ids dropped, `on` only if owned). nil until the data is loaded.
local function record(player: Player): { owned: { string }, on: string? }?
	local data = PlayerData.get(player) :: any
	if not data then
		return nil
	end
	if type(data.hub) ~= "table" then
		data.hub = {}
	end
	local s = data.hub.speed
	if type(s) ~= "table" then
		s = { owned = {} }
		data.hub.speed = s
	end
	local owned, seen = {}, {}
	if type(s.owned) == "table" then
		for _, id in s.owned do
			if type(id) == "string" and SpeedConfig.BY_ID[id] and not seen[id] then
				seen[id] = true
				table.insert(owned, id)
			end
		end
	end
	s.owned = owned
	if not (type(s.on) == "string" and seen[s.on]) then
		s.on = nil
	end
	return s
end

local function owns(s: { owned: { string }, on: string? }, id: string): boolean
	return table.find(s.owned, id) ~= nil
end

function SpeedService.boost(player: Player): number
	if not SpeedService.enabled() then
		return 0
	end
	local s = record(player)
	return SpeedConfig.boost(s and s.on)
end

local function publish(player: Player)
	if not player.Parent then
		return
	end
	local on = SpeedService.enabled()
	local s = if on then record(player) else nil
	local boost = if s then SpeedConfig.boost(s.on) else 0
	player:SetAttribute("SpeedTrail", if s then s.on else nil)
	player:SetAttribute("SpeedBoost", if on then boost else nil)
	player:SetAttribute("SpeedOwned", if s then table.concat(s.owned, ",") else nil)
	player:SetAttribute("SpeedHud", if on then SpeedConfig.hudNumber(boost) else nil)
end

local function carrying(player: Player): boolean
	for _, name in CARRY_ATTRIBUTES do
		if player:GetAttribute(name) == true then
			return true
		end
	end
	return false
end

-- The walk speed this player should have now, or nil = leave it alone.
function SpeedService.target(player: Player, force: boolean?): number?
	if player:GetAttribute("Racing") == true or player:GetAttribute("RaceFrozen") == true then
		return nil
	end
	if not (SpeedService.enabled() or force or player:GetAttribute("HeistCarrying") == true) then
		return nil
	end
	local boost = SpeedService.boost(player)
	if carrying(player) then
		return SpeedConfig.BASE_WALK * (1 + boost * SpeedConfig.CARRY_BOOST_SHARE) * CARRY
	end
	return SpeedConfig.BASE_WALK * (1 + boost)
end

function SpeedService.apply(player: Player, force: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return
	end
	local speed = SpeedService.target(player, force)
	if speed and math.abs(humanoid.WalkSpeed - speed) > 0.001 then
		humanoid.WalkSpeed = speed
	end
end

-- Requests ---------------------------------------------------------------------------------------------------
local function state(player: Player, ok: boolean, text: string?): any
	local s = record(player)
	return { ok = ok, text = text, owned = s and s.owned or {}, on = s and s.on, boost = SpeedService.boost(player) }
end

function SpeedService.handle(player: Player, action: any, id: any): any
	if not SpeedService.enabled() then
		return { ok = false, text = "Trails are not open yet" }
	end
	if not PlayerData.isLoaded(player) then
		return { ok = false, text = "Loading your data, one moment" }
	end
	local s = record(player) :: { owned: { string }, on: string? }
	if action == "State" then
		return state(player, true, nil)
	end
	local trail = type(id) == "string" and SpeedConfig.BY_ID[id] or nil
	if action == "Buy" then
		if not trail then
			SpeedService.stats.refused += 1
			return state(player, false, "Unknown trail")
		end
		if owns(s, trail.id) then
			return state(player, true, nil) -- already yours (a re-sent tap): nothing charged
		end
		if (trail :: any).exclusive then
			SpeedService.stats.refused += 1
			return state(player, false, "This trail comes with a pack") -- (033: never sold for cash)
		end
		if not CashService.trySpend(player, trail.price) then
			SpeedService.stats.refused += 1
			return state(player, false, "Not enough coins yet")
		end
		table.insert(s.owned, trail.id)
		s.on = trail.id
		SpeedService.stats.bought += 1
		task.spawn(PlayerData.save, player)
	elseif action == "Equip" then
		if not (trail and owns(s, trail.id)) then
			SpeedService.stats.refused += 1
			return state(player, false, "Buy this trail first")
		end
		s.on = trail.id
		SpeedService.stats.equipped += 1
	elseif action == "Unequip" then
		s.on = nil
	else
		SpeedService.stats.refused += 1
		return state(player, false, nil)
	end
	publish(player)
	SpeedService.apply(player)
	return state(player, true, nil)
end

-- Gives a trail without charging (033: the Starter Pack's trail). Equips it if nothing is equipped. The caller saves.
-- Returns whether the player owns it afterwards.
function SpeedService.grant(player: Player, id: string): boolean
	local s = record(player)
	if not (s and SpeedConfig.BY_ID[id]) then
		return false
	end
	if not owns(s, id) then
		table.insert(s.owned, id)
		if not s.on then
			s.on = id
		end
		publish(player)
		SpeedService.apply(player)
	end
	return true
end

local started = false
function SpeedService.start()
	if started then
		return
	end
	started = true
	local last: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	(request :: RemoteFunction).OnServerInvoke = function(player, action, id)
		local t = os.clock()
		if last[player] and t - last[player] < 0.15 then
			return { ok = false, text = nil, busy = true }
		end
		last[player] = t
		return SpeedService.handle(player, action, id)
	end

	local function onPlayer(player: Player)
		local function onCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				task.defer(SpeedService.apply, player)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
		for _, name in CARRY_ATTRIBUTES do
			player:GetAttributeChangedSignal(name):Connect(function()
				-- (deferred: the carry code sets its own speed first; this then makes it boost-aware, and a
				-- capsule carrier is set back to walking speed when the carry ends even with Speed off)
				task.defer(SpeedService.apply, player, name == "HeistCarrying")
			end)
		end
		for _, name in { "Racing", "RaceFrozen" } do
			player:GetAttributeChangedSignal(name):Connect(function()
				task.defer(SpeedService.apply, player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	PlayerData.onLoaded(function(player)
		publish(player)
		SpeedService.apply(player)
	end)

	-- The switch (Studio attribute) can change while running: publish and re-apply for everyone when it does.
	task.spawn(function()
		local was: boolean? = nil
		while true do
			local on = SpeedService.enabled()
			if on ~= was then
				ReplicatedStorage:SetAttribute(SpeedConfig.PUBLISHED, if on then true else nil)
				for _, player in Players:GetPlayers() do
					publish(player)
					if was ~= nil then
						SpeedService.apply(player, true) -- (off again: back to the normal walk speed)
					end
				end
				was = on
			end
			task.wait(1)
		end
	end)
end

return SpeedService
