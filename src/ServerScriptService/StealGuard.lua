-- Studio location: ServerScriptService.StealGuard (ModuleScript)
-- StealGuard  (Milestone 033): fair-stealing rules from ReplicatedStorage.StealConfig, asked by PvPSteal before a steal
-- starts and told when one is delivered. Off (StealConfig.FAIR_ENABLED / Studio StudioFairSteal) = no extra rules.
--   favourite  the owner's one starred worker (hub.favs, RewardsService) can't be stolen. Its placed model gets the
--              attribute FavShield = true (clients draw a shield) and its Steal prompt is turned off.
--   same base  thief -> victim: one delivered steal per SAME_BASE_COOLDOWN
--   victim cap VICTIM_MAX_LOSSES delivered steals per VICTIM_WINDOW, then a BUBBLE-second safety bubble (PvPBase.shield)
-- Counters are per server, by UserId (leaving and rejoining doesn't reset them).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local StealConfig = require(ReplicatedStorage:WaitForChild("StealConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local PvPBase = require(script.Parent:WaitForChild("PvPBase"))

local StealGuard = {}

local lastSteal: { [string]: number } = {} -- "thiefId:victimId" -> time of the last delivered steal
local losses: { [number]: { number } } = {} -- victimId -> times of delivered steals inside the window

StealGuard.on = StealConfig.on

-- The uid of the player's protected favourite, or nil.
function StealGuard.favourite(player: Player): string?
	if not (StealConfig.on() and StealConfig.FAVOURITE_PROTECTED) then
		return nil
	end
	local data = PlayerData.get(player) :: any
	local favs = data and type(data.hub) == "table" and data.hub.favs
	if type(favs) ~= "table" then
		return nil
	end
	local found = nil
	for uid, on in favs do
		if on == true and type(uid) == "string" then
			if found then
				return nil -- (more than one star from before 033: none is protected until they star one)
			end
			found = uid
		end
	end
	return found
end

-- Marks the owner's placed favourite (FavShield) and turns its Steal prompt off; clears it from the others.
function StealGuard.refresh(player: Player)
	local plot = PlotService.getPlot(player)
	local placed = plot and plot:FindFirstChild("PlacedNPCs")
	if not placed then
		return
	end
	local fav = StealGuard.favourite(player)
	for _, npc in placed:GetChildren() do
		local shielded = fav ~= nil and npc:GetAttribute("WorkerUid") == fav
		if npc:GetAttribute("FavShield") ~= (shielded or nil) then
			npc:SetAttribute("FavShield", shielded or nil)
		end
		local root = npc:FindFirstChild("HumanoidRootPart")
		local prompt = root and root:FindFirstChild("PvPStealPrompt")
		if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled == shielded then
			prompt.Enabled = not shielded
		end
	end
end

local function now(): number
	return PvPBase.now()
end

-- Why `thief` can't start stealing worker `uid` from `owner` now, or nil when the fair rules allow it.
function StealGuard.check(thief: Player, owner: Player, uid: string): string?
	if not StealConfig.on() then
		return nil
	end
	if StealGuard.favourite(owner) == uid then
		return ("That's %s's favourite worker: it can't be stolen."):format(owner.DisplayName)
	end
	local t = now()
	local last = lastSteal[thief.UserId .. ":" .. owner.UserId]
	if last and t - last < StealConfig.SAME_BASE_COOLDOWN then
		local left = math.ceil(StealConfig.SAME_BASE_COOLDOWN - (t - last))
		return ("You stole from %s not long ago. Try another base (or come back in %d:%02d)."):format(owner.DisplayName, left // 60, left % 60)
	end
	return nil
end

-- A steal from `owner` was delivered to `thief`.
function StealGuard.onDelivered(thief: Player, ownerId: number)
	if not StealConfig.on() then
		return
	end
	local t = now()
	lastSteal[thief.UserId .. ":" .. ownerId] = t
	local list = losses[ownerId] or {}
	for i = #list, 1, -1 do
		if t - list[i] >= StealConfig.VICTIM_WINDOW then
			table.remove(list, i)
		end
	end
	table.insert(list, t)
	losses[ownerId] = list
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		owner:SetAttribute("LastLossAt", os.time())
	end
	if #list >= StealConfig.VICTIM_MAX_LOSSES then
		table.clear(list)
		PvPBase.shield(ownerId, StealConfig.BUBBLE)
		if owner then
			PvPBase.notify(owner, true, ("Your base has a safety bubble for %d minutes. Nobody can steal from you."):format(math.floor(StealConfig.BUBBLE / 60)))
		end
	end
end

local function publish()
	ReplicatedStorage:SetAttribute(StealConfig.PUBLISHED, StealConfig.on())
	for _, player in Players:GetPlayers() do
		StealGuard.refresh(player)
	end
end

local started = false
function StealGuard.start()
	if started then
		return
	end
	started = true
	publish()
	local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		local placed = plot:WaitForChild("PlacedNPCs", 10)
		if placed then
			local function changed()
				local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
				if owner then
					task.defer(StealGuard.refresh, owner) -- (after the Steal prompt has been added)
				end
			end
			placed.ChildAdded:Connect(changed)
		end
	end
	if RunService:IsStudio() then
		ServerStorage:GetAttributeChangedSignal(StealConfig.STUDIO_ATTRIBUTE):Connect(publish)
	end
end

-- Studio tests only.
StealGuard._test = {
	reset = function()
		table.clear(lastSteal)
		table.clear(losses)
	end,
	losses = losses,
	lastSteal = lastSteal,
}

return StealGuard
