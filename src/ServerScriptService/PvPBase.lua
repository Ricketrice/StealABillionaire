-- Studio location: ServerScriptService.PvPBase (ModuleScript)
-- PvPBase  (Milestone 022)
-- Shared server state for PvP: the two feature flags, the PvP remotes (rate-limited), which plot is
-- whose, base lock, new-player protection, safe zones and spawn immunity. Everything here is decided
-- on the server; clients only read the replicated attributes:
--   ReplicatedStorage  PvPStealing / WeaponCombat          effective flags
--   plot and player    LockedUntil / LockCooldownUntil / ProtectedUntil   (server time, see PvPBase.now)
--   player             PvPSpawnSafeUntil

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local PvPBase = {}

local TITLE = "Base"
local TIMERS = { "LockedUntil", "LockCooldownUntil", "ProtectedUntil" }

local function getRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: RemoteEvent
end
-- Client -> server: (action: string, ...). Server -> client: (kind: string, info: table?).
local actionEvent = getRemote("PvPAction")
local clientEvent = getRemote("PvPEvent")

local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
local flagsChanged = Instance.new("BindableEvent")
PvPBase.FlagsChanged = flagsChanged.Event
PvPBase.stats = { dropped = 0, handled = 0 } -- requests refused by the rate limit / passed on

-- Flags ---------------------------------------------------------------------------------------------
local function flag(configured: boolean, studioAttribute: string): boolean
	return configured or (RunService:IsStudio() and ServerStorage:GetAttribute(studioAttribute) == true)
end
function PvPBase.stealing(): boolean
	return flag(PvPConfig.PVP_STEALING_ENABLED, PvPConfig.STUDIO_STEALING_ATTRIBUTE)
end
function PvPBase.combat(): boolean
	return flag(PvPConfig.WEAPON_COMBAT_ENABLED, PvPConfig.STUDIO_COMBAT_ATTRIBUTE)
end

-- Server time, the same clock clients read with Workspace:GetServerTimeNow().
function PvPBase.now(): number
	return workspace:GetServerTimeNow()
end
local now = PvPBase.now

function PvPBase.notify(player: Player, success: boolean, message: string, title: string?)
	NPCClaim.notify(player, success, message, title or TITLE)
end
function PvPBase.event(player: Player, kind: string, info: any?)
	if player.Parent then
		clientEvent:FireClient(player, kind, info)
	end
end
function PvPBase.broadcast(kind: string, info: any?)
	clientEvent:FireAllClients(kind, info)
end

-- Requests --------------------------------------------------------------------------------------------
local handlers: { [string]: (Player, ...any) -> () } = {}
local budget: { [Player]: { tokens: number, at: number } } = setmetatable({}, { __mode = "k" }) :: any
function PvPBase.onAction(name: string, handler: (Player, ...any) -> ())
	handlers[name] = handler
end
-- One entry point for every PvP request, so a spamming client is cut off in one place.
function PvPBase.handleAction(player: Player, name: any, ...: any)
	local rate = PvPConfig.ACTION_RATE
	local t = os.clock()
	local b = budget[player]
	if not b then
		b = { tokens = rate, at = t }
		budget[player] = b
	end
	b.tokens = math.min(rate, b.tokens + (t - b.at) * rate)
	b.at = t
	if b.tokens < 1 then
		PvPBase.stats.dropped += 1
		return
	end
	b.tokens -= 1
	local handler = if type(name) == "string" then handlers[name] else nil
	if handler then
		PvPBase.stats.handled += 1
		handler(player, ...)
	end
end
actionEvent.OnServerEvent:Connect(PvPBase.handleAction)

-- Plots ---------------------------------------------------------------------------------------------
function PvPBase.plots(): Instance
	return plots
end
function PvPBase.ownerOf(plot: Instance): Player?
	local userId = plot:GetAttribute("OwnerUserId")
	return if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end
-- The plot a placed worker model stands in, if it is one.
function PvPBase.plotOfWorker(npc: Instance): Model?
	local folder = npc.Parent
	local plot = if folder and folder.Name == "PlacedNPCs" then folder.Parent else nil
	return if plot and plot:IsA("Model") and plot.Parent == plots then plot else nil
end
function PvPBase.isInside(plot: Model, position: Vector3, margin: number?): boolean
	local floor = plot.PrimaryPart :: BasePart
	local p = floor.CFrame:PointToObjectSpace(position)
	local m = margin or 0
	return math.abs(p.X) <= floor.Size.X / 2 + m and math.abs(p.Z) <= floor.Size.Z / 2 + m and p.Y > -4 and p.Y < 30
end
function PvPBase.findStation(plot: Model, index: number?): BasePart?
	local stations = plot:FindFirstChild("Stations")
	for _, station in (stations and stations:GetChildren() or {}) do
		if station:IsA("BasePart") and station:GetAttribute("StationIndex") == index then
			return station
		end
	end
	return nil
end

-- Base lock and new-player protection -----------------------------------------------------------------
-- Kept by UserId for as long as this server runs, so leaving and rejoining neither resets a lock's
-- cooldown nor renews protection.
local locks: { [number]: { lockedUntil: number, cooldownUntil: number } } = {}
local protectedUntil: { [number]: number } = {}
local seen: { [number]: boolean } = {}
local publishedPlot: { [Player]: Model } = {}

local function publish(player: Player)
	local on = PvPBase.stealing()
	local lock = locks[player.UserId]
	local t = now()
	local values = {
		LockedUntil = if on and lock and lock.lockedUntil > t then lock.lockedUntil else nil,
		LockCooldownUntil = if on and lock and lock.cooldownUntil > t then lock.cooldownUntil else nil,
		ProtectedUntil = if on and (protectedUntil[player.UserId] or 0) > t then protectedUntil[player.UserId] else nil,
	}
	local plot = PlotService.getPlot(player)
	local previous = publishedPlot[player]
	if previous and previous ~= plot then
		for _, name in TIMERS do
			previous:SetAttribute(name, nil)
		end
	end
	publishedPlot[player] = plot :: Model
	for _, name in TIMERS do
		player:SetAttribute(name, values[name])
		if plot then
			plot:SetAttribute(name, values[name])
		end
	end
end
PvPBase.publish = publish

function PvPBase.isLocked(userId: number): boolean
	local lock = locks[userId]
	return lock ~= nil and lock.lockedUntil > now()
end
function PvPBase.isProtected(userId: number): boolean
	return (protectedUntil[userId] or 0) > now()
end

-- Locks the player's base against new steals. Returns (locked, message).
function PvPBase.tryLock(player: Player): (boolean, string?)
	if not PvPBase.stealing() then
		return false, nil
	end
	if not PlotService.getPlot(player) then
		return false, "You need a base first."
	end
	local lock, t = locks[player.UserId], now()
	if lock and lock.lockedUntil > t then
		return false, ("Your base is already locked (%d s left)."):format(math.ceil(lock.lockedUntil - t))
	end
	if lock and lock.cooldownUntil > t then
		return false, ("The base lock is recharging (%d s)."):format(math.ceil(lock.cooldownUntil - t))
	end
	local duration = PvPConfig.Lock.DURATION
	locks[player.UserId] = { lockedUntil = t + duration, cooldownUntil = t + duration + PvPConfig.Lock.COOLDOWN }
	publish(player)
	return true, ("Base locked for %d seconds: nobody can start a steal here."):format(duration)
end

-- An owner who leaves while being robbed can't lock straight away when they come back.
function PvPBase.penalise(userId: number)
	local t = now()
	local lock = locks[userId] or { lockedUntil = 0, cooldownUntil = 0 }
	lock.cooldownUntil = math.max(lock.cooldownUntil, t + PvPConfig.Lock.LEAVE_PENALTY)
	locks[userId] = lock
end

-- A safety bubble (033 fair stealing, StealGuard): protection for `seconds` from now, shown like new-player
-- protection. Never shortens protection the player already has.
local bubbled: { [number]: boolean } = {}
function PvPBase.shield(userId: number, seconds: number)
	local untilTime = now() + seconds
	if (protectedUntil[userId] or 0) < untilTime then
		protectedUntil[userId] = untilTime
		bubbled[userId] = true
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		publish(player)
	end
end
-- Whether the player's protection is a safety bubble (not new-player protection).
function PvPBase.isBubble(userId: number): boolean
	return bubbled[userId] == true and PvPBase.isProtected(userId)
end

function PvPBase.endProtection(player: Player, message: string?)
	if PvPBase.isProtected(player.UserId) then
		protectedUntil[player.UserId] = nil
		publish(player)
		if message then
			PvPBase.notify(player, true, message)
		end
	end
end

-- Safe zones and spawn immunity -----------------------------------------------------------------------
function PvPBase.isSafe(position: Vector3): boolean
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("BasePart") and ((position - spawn.Position) * Vector3.new(1, 0, 1)).Magnitude <= PvPConfig.Safe.SPAWN_RADIUS then
		return true
	end
	for _, zone in CollectionService:GetTagged(PvPConfig.Safe.TAG) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(position)
			if math.abs(p.X) <= zone.Size.X / 2 and math.abs(p.Y) <= zone.Size.Y / 2 and math.abs(p.Z) <= zone.Size.Z / 2 then
				return true
			end
		end
	end
	return false
end
function PvPBase.spawnSafe(player: Player): boolean
	return (player:GetAttribute("PvPSpawnSafeUntil") or 0) > now()
end
function PvPBase.endSpawnSafe(player: Player)
	if player:GetAttribute("PvPSpawnSafeUntil") ~= nil then
		player:SetAttribute("PvPSpawnSafeUntil", nil)
	end
end

-- Test seams (Studio test scripts only).
PvPBase._test = {
	locks = locks,
	setProtection = function(player: Player, seconds: number?)
		protectedUntil[player.UserId] = if seconds then now() + seconds else nil
		publish(player)
	end,
	protectedUntil = protectedUntil,
	seen = seen,
}

local started = false
function PvPBase.start()
	if started then
		return
	end
	started = true

	local function publishFlags()
		ReplicatedStorage:SetAttribute("PvPStealing", PvPBase.stealing())
		ReplicatedStorage:SetAttribute("WeaponCombat", PvPBase.combat())
	end
	publishFlags()
	for _, attribute in { PvPConfig.STUDIO_STEALING_ATTRIBUTE, PvPConfig.STUDIO_COMBAT_ATTRIBUTE } do
		ServerStorage:GetAttributeChangedSignal(attribute):Connect(function()
			publishFlags()
			for _, player in Players:GetPlayers() do
				publish(player)
			end
			flagsChanged:Fire()
		end)
	end

	-- Protection starts when a brand-new player's data first loads here, once per UserId.
	PlayerData.onLoaded(function(player)
		local userId = player.UserId
		if not seen[userId] then
			seen[userId] = true
			local forced = if RunService:IsStudio() then ServerStorage:GetAttribute(PvPConfig.STUDIO_PROTECTION_ATTRIBUTE) else nil
			if type(forced) == "number" then
				protectedUntil[userId] = now() + forced
			elseif forced ~= false and PlayerData.isNew(player) then
				protectedUntil[userId] = now() + PvPConfig.Protection.DURATION
			end
		end
		local waited = 0
		while not PlotService.getPlot(player) and player.Parent and waited < 10 do
			waited += task.wait(0.2)
		end
		if player.Parent then
			publish(player)
		end
	end)

	local function onCharacter(player: Player)
		if PvPBase.combat() then
			player:SetAttribute("PvPSpawnSafeUntil", now() + PvPConfig.Safe.SPAWN_IMMUNITY)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local plot = publishedPlot[player]
		publishedPlot[player] = nil
		if plot then
			for _, name in TIMERS do
				plot:SetAttribute(name, nil)
			end
		end
	end)

	PvPBase.onAction("Lock", function(player)
		local ok, message = PvPBase.tryLock(player)
		if message then
			PvPBase.notify(player, ok, message)
		end
	end)
end

return PvPBase
