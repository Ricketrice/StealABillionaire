-- Studio location: ServerScriptService.WorkerInventory (ModuleScript)
-- WorkerInventory
-- Which workers each player owns and where each one is. The player's saved data (PlayerData) is
-- the source of truth; worker models on stations are rebuilt from it.
--
-- Locations: "station" (a model on that station of the player's plot, earning), "inventory"
-- (data only, earning nothing) or "carried" (on their shoulder; in memory only - it is saved as
-- stored, so a crash or disconnect while carrying never loses it).
--
-- Capacity policy: a player owns at most INVENTORY_SLOTS + STATION_SLOTS workers (plus any slots
-- and stations bought at the Milestone 026 Upgrade Office), counting the
-- one being carried. A steal can't start once they're at that limit, so every claimed or carried
-- worker always has somewhere to go and is never destroyed:
--   * place it on a free station, or store it from the inventory panel while carrying;
--   * if the carry is cancelled (death, respawn, leaving) it goes to the inventory, or to a free
--     station if the inventory is full.
--
-- Transfers (Store, Equip, StoreCarried) come from the owner's client as requests and are fully
-- validated here. Each runs to completion without yielding, so two requests can never interleave,
-- and every one checks the worker's current location first, so repeating a request can't
-- duplicate or lose a worker.
-- Delivery (029): each request carries an id and is answered on InventoryAck. A client that hears
-- nothing within a few seconds sends the same request again (WorkerState); a repeated id gets the
-- first answer back without running again. "Place" (station index) is the client's backup for a
-- Place prompt press that got no result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local NPCCarry = require(script.Parent:WaitForChild("NPCCarry"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local NPCPlacement = require(script.Parent:WaitForChild("NPCPlacement"))
local NPCWanderer = require(script.Parent:WaitForChild("NPCWanderer"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local WorkerAppearance = require(script.Parent:WaitForChild("WorkerAppearance"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))

type WorkerRecord = PlayerData.WorkerRecord
type Data = PlayerData.Data

local WorkerInventory = {}

local INVENTORY_SLOTS = InventoryConfig.INVENTORY_SLOTS
local STATION_SLOTS = InventoryConfig.STATION_SLOTS
local TITLE = "Workers"
local REQUEST_COOLDOWN = 0.2 -- seconds between a player's transfer requests
local REFRESH_COOLDOWN = 1 -- seconds between a player's snapshot requests (each one is a full snapshot)
local PLOT_WAIT = 10 -- seconds to wait for a plot before restoring workers

local function getOrCreateRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: RemoteEvent
end

-- Client -> server: (action: "Refresh" | "Store" | "Equip" | "StoreCarried", uid: string?)
local actionEvent = getOrCreateRemote("InventoryAction")
-- Server -> owner: a snapshot { slots, stations, workers = { { uid, id, level, tier, loc, station? } } }
local syncEvent = getOrCreateRemote("InventorySync")
-- Server -> owner: (requestId, ok?, message?, retry?) the answer to a request that carried an id.
local ackEvent = getOrCreateRemote("InventoryAck")
local RECENT_KEPT = 24 -- answers remembered per player, for repeated ids
local recent: { [Player]: { answers: { [number]: { any } }, order: { number } } } = {}
local dropNext: { [Player]: number } = {} -- Studio tests: requests to ignore as if lost on the way

local byUid: { [Player]: { [string]: WorkerRecord } } = {}
local lastRequest: { [Player]: number } = {}
local lastRefresh: { [Player]: number } = {}
local template = ServerStorage:WaitForChild("NPCModels"):WaitForChild("MysteryNPC") :: Model
-- Set by PvPSteal (Milestone 022); see setBusyCheck and setBeforePlaced near the end.
local busyCheck: ((Player, WorkerRecord) -> string?)? = nil
local beforePlaced: ((Player, Model, BasePart) -> ())? = nil

local function notify(player: Player, success: boolean, message: string)
	NPCClaim.notify(player, success, message, TITLE)
end

local function workerName(record: WorkerRecord): string
	local worker = WorkerCatalogue.get(record.id)
	return if worker then worker.name else record.id
end

-- How many of the player's workers are stored, on stations, carried, and in total.
function WorkerInventory.count(player: Player): (number, number, number, number)
	local data = PlayerData.get(player)
	local stored, onStations, carried = 0, 0, 0
	if data then
		for _, w in data.workers do
			if w.loc == "inventory" then
				stored += 1
			elseif w.loc == "station" then
				onStations += 1
			else
				carried += 1
			end
		end
	end
	return stored, onStations, carried, stored + onStations + carried
end

-- Extra storage slots a player has (Milestone 026 Upgrade Office). 0 unless a system sets a bonus.
local slotBonus: ((Player) -> number)? = nil
local function slotsFor(player: Player): number
	local bonus = if slotBonus then slotBonus(player) else 0
	return INVENTORY_SLOTS + math.max(0, math.floor(bonus))
end
-- Extra stations a player has (Milestone 026 Upgrade Office). 0 unless a system sets a bonus; that
-- system also builds the extra pads, and `stationPrepare` lets it do so before workers are rebuilt.
local stationBonus: ((Player) -> number)? = nil
local stationPrepare: ((Player, Model) -> ())? = nil
local function stationsFor(player: Player): number
	local bonus = if stationBonus then stationBonus(player) else 0
	return STATION_SLOTS + math.max(0, math.floor(bonus))
end

local function push(player: Player)
	local data = PlayerData.get(player)
	if not data or not player.Parent then
		return
	end
	local list = table.create(#data.workers)
	for _, w in data.workers do
		table.insert(list, { uid = w.uid, id = w.id, level = w.level, tier = w.tier, loc = w.loc, station = w.station })
	end
	syncEvent:FireClient(player, { slots = slotsFor(player), stations = stationsFor(player), workers = list })
end

local function findStation(plot: Model, index: number): BasePart?
	for _, station in plot.Stations:GetChildren() do
		if station:GetAttribute("StationIndex") == index and station:IsA("BasePart") then
			return station
		end
	end
	return nil
end

local function findPlacedModel(plot: Model, uid: string): Model?
	for _, npc in plot.PlacedNPCs:GetChildren() do
		if npc:GetAttribute("WorkerUid") == uid then
			return npc
		end
	end
	return nil
end

-- Lowest station index no worker of this player is assigned to, if any.
local function freeStationIndex(data: Data, stations: number): number?
	local used = {}
	for _, w in data.workers do
		if w.loc == "station" and w.station then
			used[w.station] = true
		end
	end
	for index = 1, stations do
		if not used[index] then
			return index
		end
	end
	return nil
end

-- Builds a saved worker's model, with its own look and identity, standing on a station.
-- Returns nil (and builds nothing) if the record can't be built, e.g. an unknown worker id.
local function spawnOnStation(record: WorkerRecord, plot: Model, station: BasePart): Model?
	if not WorkerCatalogue.get(record.id) then
		warn("[WorkerInventory] unknown worker id", record.id, "- kept in data, not spawned")
		return nil
	end
	local npc = NPCWanderer.cloneRig(template)
	local ok, err = pcall(function()
		WorkerService.apply(npc, { uid = record.uid, workerId = record.id, zoneId = record.zone, level = record.level, tier = record.tier })
		WorkerAppearance.apply(npc, record.id)
	end)
	if not ok then
		warn("[WorkerInventory] couldn't build worker", record.uid, "-", err)
		npc:Destroy()
		return nil
	end
	npc:SetAttribute("Claimed", true)
	NPCPlacement.placeOnStation(npc, station, plot)
	return npc
end

-- Puts a worker that must be put away somewhere safe: the inventory if it has room, otherwise a
-- free station (built there if the player's plot is still theirs). Returns where it went.
local function stash(player: Player, data: Data, record: WorkerRecord): string
	local stored = WorkerInventory.count(player)
	if stored < slotsFor(player) then
		record.loc, record.station = "inventory", nil
		return "inventory"
	end
	local index = freeStationIndex(data, stationsFor(player))
	if index then
		record.loc, record.station = "station", index
		local plot = PlotService.getPlot(player)
		local station = plot and findStation(plot, index)
		if plot and station and station:GetAttribute("Occupied") ~= true then
			spawnOnStation(record, plot, station)
		end
		return "base"
	end
	-- Can't happen while the capacity rule holds; keep the worker rather than lose it.
	warn("[WorkerInventory]", player.Name, "is over capacity; storing", record.uid, "beyond the slot limit")
	record.loc, record.station = "inventory", nil
	return "inventory"
end

-- NPCClaim reserve check: data loaded, a base to bring it to, and room for one more worker.
function WorkerInventory.canClaim(player: Player): (boolean, string?)
	if not PlayerData.isLoaded(player) then
		return false, "Your data is still loading."
	end
	if not PlotService.getPlot(player) then
		return false, "You need a base first."
	end
	if NPCCarry.getCarried(player) then
		return false, "You already have a worker in hand. Place or store it first."
	end
	local _, _, _, total = WorkerInventory.count(player)
	local capacity = slotsFor(player) + stationsFor(player)
	if total >= capacity then
		return false, ("You have no room (%d/%d). Store or free up space first."):format(total, capacity)
	end
	return true
end

-- A steal completed and the player is now carrying this revealed worker: they own it.
function WorkerInventory.onClaimed(player: Player, npc: Model)
	local data = PlayerData.get(player)
	local identity = WorkerService.getIdentity(npc)
	local index = byUid[player]
	if not (data and identity and index) or index[identity.uid] then
		return
	end
	local record: WorkerRecord = {
		uid = identity.uid,
		id = identity.workerId,
		zone = identity.zoneId,
		level = identity.level,
		tier = identity.tier,
		loc = "carried",
	}
	table.insert(data.workers, record)
	index[record.uid] = record
	push(player)
end

-- NPCPlacement placed handler: the carried worker is now on a station.
local function onPlaced(player: Player, npc: Model, station: BasePart)
	if beforePlaced then
		beforePlaced(player, npc, station)
	end
	local record = byUid[player] and byUid[player][npc:GetAttribute("WorkerUid")]
	if record then
		record.loc, record.station = "station", station:GetAttribute("StationIndex")
		push(player)
	end
end

-- NPCCarry drop handler: the carry was cancelled, so send the worker home instead of losing it.
local function onDropped(player: Player, npc: Model)
	local data = PlayerData.get(player)
	local record = byUid[player] and byUid[player][npc:GetAttribute("WorkerUid")]
	if not (data and record and record.loc == "carried") then
		return
	end
	local where = stash(player, data, record)
	if player.Parent then
		notify(player, true, ("%s went back to your %s."):format(workerName(record), where))
		push(player)
	end
end

-- Each transfer validates everything first and only then changes state; none of them yield.
local function store(player: Player, data: Data, record: WorkerRecord): (boolean, string)
	if record.loc ~= "station" then
		return false, "That worker isn't on a station."
	end
	if WorkerInventory.count(player) >= slotsFor(player) then
		return false, ("Your inventory is full (%d/%d)."):format(slotsFor(player), slotsFor(player))
	end
	local plot = PlotService.getPlot(player)
	local model = plot and findPlacedModel(plot, record.uid)
	if model then
		model:Destroy() -- frees the station and stops its income
	end
	record.loc, record.station = "inventory", nil
	return true, workerName(record) .. " was stored."
end

local function equip(player: Player, data: Data, record: WorkerRecord): (boolean, string)
	if record.loc ~= "inventory" then
		return false, "That worker isn't in your inventory."
	end
	if not WorkerCatalogue.get(record.id) then
		return false, "That worker can't be equipped."
	end
	local plot = PlotService.getPlot(player)
	if not plot then
		return false, "You need a base first."
	end
	local index = freeStationIndex(data, stationsFor(player))
	local station = index and findStation(plot, index)
	if not (station and station:GetAttribute("Occupied") ~= true) then
		return false, ("All %d stations are full. Store a worker first."):format(stationsFor(player))
	end
	if not spawnOnStation(record, plot, station) then
		return false, "That worker can't be equipped."
	end
	record.loc, record.station = "station", index
	return true, ("%s is working on station %d."):format(workerName(record), index :: number)
end

local function storeCarried(player: Player, data: Data): (boolean, string)
	local npc = NPCCarry.getCarried(player)
	local record = npc and byUid[player][npc:GetAttribute("WorkerUid")]
	if not (npc and record and record.loc == "carried") then
		return false, "You're not carrying a worker."
	end
	if WorkerInventory.count(player) >= INVENTORY_SLOTS then
		return false, ("Your inventory is full (%d/%d). Place it on a station instead."):format(INVENTORY_SLOTS, INVENTORY_SLOTS)
	end
	local detached = NPCCarry.detach(player) -- ends the carry and releases the steal reservation
	if detached then
		detached:Destroy()
	end
	record.loc, record.station = "inventory", nil
	return true, workerName(record) .. " was stored."
end

-- The client's backup for a Place prompt press: the same checks as the prompt (NPCPlacement.tryPlace).
local function placeRequest(player: Player, stationIndex: any): (boolean, string?)
	local plot = PlotService.getPlot(player)
	local station = plot and type(stationIndex) == "number" and stationIndex % 1 == 0 and findStation(plot, stationIndex)
	if not station then
		return false, "That isn't one of your stations."
	end
	return NPCPlacement.tryPlace(player, station)
end

local function remember(player: Player, id: number, answer: { any })
	local r = recent[player]
	if not r then
		r = { answers = {}, order = {} }
		recent[player] = r
	end
	r.answers[id] = answer
	table.insert(r.order, id)
	if #r.order > RECENT_KEPT then
		r.answers[table.remove(r.order, 1)] = nil
	end
end

local function onAction(player: Player, action: any, uid: any, requestId: any)
	local now = os.clock()
	if action == "Refresh" then
		if now - (lastRefresh[player] or -math.huge) >= REFRESH_COOLDOWN then
			lastRefresh[player] = now
			push(player)
		end
		return
	end
	local id = if type(requestId) == "number" and requestId % 1 == 0 and requestId > 0 and requestId < 2 ^ 31 then requestId else nil
	if (dropNext[player] or 0) > 0 then
		dropNext[player] -= 1
		return -- (Studio tests only: as if the message never arrived)
	end
	if id then
		local seen = recent[player] and recent[player].answers[id]
		if seen then
			ackEvent:FireClient(player, id, seen[1], seen[2]) -- a repeat: same answer, nothing runs again
			return
		end
	end
	if now - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN then
		if id then
			ackEvent:FireClient(player, id, nil, nil, true) -- too fast: try again in a moment
		end
		return
	end
	lastRequest[player] = now

	local data = PlayerData.get(player)
	local index = byUid[player]
	if not (data and index) then
		if id then
			ackEvent:FireClient(player, id, nil, nil, true) -- still loading
		end
		return
	end
	local function answer(ok: boolean, message: string?)
		if id then
			remember(player, id, { ok, message })
			ackEvent:FireClient(player, id, ok, message)
		end
	end
	local ok, message
	if action == "Place" then
		ok, message = placeRequest(player, uid)
		if ok then
			notify(player, true, ("Placed on station %d."):format(uid))
			push(player)
		end
		answer(ok, message) -- (a refused backup stays quiet: the prompt press already said why)
		return
	elseif action == "StoreCarried" then
		ok, message = storeCarried(player, data)
	elseif action == "Store" or action == "Equip" then
		local record = type(uid) == "string" and index[uid]
		if not record then
			answer(false, nil)
			return -- not one of this player's workers
		end
		local busy = busyCheck and busyCheck(player, record)
		if busy then
			notify(player, false, busy)
			answer(false, busy)
			return
		end
		if action == "Store" then
			ok, message = store(player, data, record)
		else
			ok, message = equip(player, data, record)
		end
	else
		return
	end
	notify(player, ok, message)
	answer(ok, message)
	push(player)
end

-- PlayerData serializer: what to save. A carried worker is saved as stored (or on a free
-- station if storage is full), without changing the live data.
local function serialize(player: Player, data: Data): Data
	local stored, used = 0, {}
	for _, w in data.workers do
		if (w :: any).escrow then
			continue
		end
		if w.loc == "inventory" then
			stored += 1
		elseif w.loc == "station" and w.station then
			used[w.station] = true
		end
	end
	local workers = table.create(#data.workers)
	for _, w in data.workers do
		if (w :: any).escrow then
			continue -- received from another player and not confirmed yet: never saved (see give)
		end
		local copy = table.clone(w)
		if copy.loc == "carried" then
			copy.loc, copy.station = "inventory", nil
			if stored >= slotsFor(player) then
				for index = 1, stationsFor(player) do
					if not used[index] then
						copy.loc, copy.station = "station", index
						used[index] = true
						break
					end
				end
			end
			if copy.loc == "inventory" then
				stored += 1
			end
		end
		table.insert(workers, copy)
	end
	return { schema = data.schema, cash = data.cash, workers = workers, zones = data.zones, hub = data.hub }
end
WorkerInventory._serialize = serialize -- exposed for tests

-- Once a player's data loads: index their workers and rebuild the ones on stations.
local function onLoaded(player: Player, data: Data)
	local index = {}
	for _, w in data.workers do
		index[w.uid] = w
	end
	byUid[player] = index

	local waited = 0
	while not PlotService.getPlot(player) and player.Parent and waited < PLOT_WAIT do
		waited += task.wait(0.2)
	end
	local plot = PlotService.getPlot(player)
	if plot and player.Parent and PlayerData.get(player) == data then
		if stationPrepare then
			stationPrepare(player, plot) -- must not yield
		end
		local displaced = {}
		for _, w in data.workers do
			if w.loc == "station" then
				local station = w.station and findStation(plot, w.station)
				if station and station:GetAttribute("Occupied") ~= true and WorkerCatalogue.get(w.id) then
					spawnOnStation(w, plot, station)
				else
					table.insert(displaced, w) -- bad or doubled-up station index
				end
			end
		end
		for _, w in displaced do
			if WorkerCatalogue.get(w.id) then
				w.loc, w.station = "carried", nil -- briefly, so stash() can re-home it
				stash(player, data, w)
			end
		end
	end
	push(player)
end

-- Transfers between players (Milestone 022: PvP stealing) -------------------------------------------
-- These only move records in memory; PvPSteal decides when, and keeps the transfer journal.

-- `check(player, record)` returns a message while a worker can't be moved (e.g. it is being stolen).
function WorkerInventory.setBusyCheck(check: (Player, WorkerRecord) -> string?)
	busyCheck = check
end

-- `hook(player, npc, station)` runs just before a placed worker is recorded on its station.
function WorkerInventory.setBeforePlaced(hook: (Player, Model, BasePart) -> ())
	beforePlaced = hook
end

-- `bonus(player)` = extra storage slots for that player (Milestone 026 Upgrade Office).
function WorkerInventory.setSlotBonus(bonus: ((Player) -> number)?)
	slotBonus = bonus
end
-- Extra stations: how many a player has beyond STATION_SLOTS, and what builds their pads on the
-- player's plot just before saved workers are stood on them.
function WorkerInventory.setStationBonus(bonus: ((Player) -> number)?, prepare: ((Player, Model) -> ())?)
	stationBonus, stationPrepare = bonus, prepare
end

-- Whether the player's loaded workers have been indexed yet (take/give work from then on).
function WorkerInventory.isReady(player: Player): boolean
	return byUid[player] ~= nil
end

function WorkerInventory.getRecord(player: Player, uid: string): WorkerRecord?
	return byUid[player] and byUid[player][uid]
end

-- Sends the player's UI a fresh snapshot.
WorkerInventory.refresh = push

-- Rebuilds the model of a worker that is recorded on a station but has no model there.
function WorkerInventory.respawn(player: Player, uid: string): Model?
	local record = WorkerInventory.getRecord(player, uid)
	local plot = PlotService.getPlot(player)
	if not (record and plot and record.loc == "station" and record.station) or findPlacedModel(plot, uid) then
		return nil
	end
	local station = findStation(plot, record.station)
	return if station then spawnOnStation(record, plot, station) else nil
end

-- Takes a worker out of a player's data (and its model off its station). Returns its record.
function WorkerInventory.take(player: Player, uid: string): WorkerRecord?
	local data, index = PlayerData.get(player), byUid[player]
	local record = index and index[uid]
	if not (data and index and record) then
		return nil
	end
	local position = table.find(data.workers, record)
	if position then
		table.remove(data.workers, position)
	end
	index[uid] = nil
	local plot = PlotService.getPlot(player)
	local model = plot and findPlacedModel(plot, uid)
	if model then
		model:Destroy()
	end
	push(player)
	return record
end

-- Adds a worker record to a player's data. Refuses a uid they already have and (unless `force`)
-- one more than they can hold. A record with `escrow = true` is theirs in play but is left out of
-- their saves until whoever gave it clears the flag.
function WorkerInventory.give(player: Player, record: WorkerRecord, force: boolean?): boolean
	local data, index = PlayerData.get(player), byUid[player]
	if not (data and index) or index[record.uid] then
		return false
	end
	local _, _, _, total = WorkerInventory.count(player)
	if total >= slotsFor(player) + stationsFor(player) and not force then
		return false
	end
	table.insert(data.workers, record)
	index[record.uid] = record
	push(player)
	return true
end

-- Puts away a worker held as "carried" with no model: back on `preferredStation` if that is free,
-- otherwise wherever a cancelled carry would go. Returns where it went.
function WorkerInventory.putAway(player: Player, uid: string, preferredStation: number?): string?
	local data, record = PlayerData.get(player), WorkerInventory.getRecord(player, uid)
	if not (data and record and record.loc == "carried") then
		return nil
	end
	local plot = PlotService.getPlot(player)
	local station = plot and preferredStation and findStation(plot, preferredStation)
	local where
	if plot and station and station:GetAttribute("Occupied") ~= true then
		local free = true
		for _, w in data.workers do
			if w ~= record and w.loc == "station" and w.station == preferredStation then
				free = false
			end
		end
		if free and spawnOnStation(record, plot, station) then
			record.loc, record.station = "station", preferredStation
			where = "base"
		end
	end
	where = where or stash(player, data, record)
	push(player)
	return where
end

-- Whether the player can own one more worker (the same capacity rule a steal checks).
function WorkerInventory.hasRoom(player: Player): boolean
	local _, _, _, total = WorkerInventory.count(player)
	return PlayerData.isLoaded(player) and total < slotsFor(player) + stationsFor(player)
end

-- Gives a brand-new worker straight to the player, with no carry (Royale Race capsules, 031): onto a
-- free station if there is one, otherwise into storage. Never refuses for space (callers check
-- hasRoom first; a full player keeps it in storage over the limit rather than lose it). The record is
-- in the player's data before anything can yield. Returns where it went, or nil (data not ready, uid owned).
function WorkerInventory.grant(player: Player, record: WorkerRecord): string?
	local data, index = PlayerData.get(player), byUid[player]
	if not (data and index) or index[record.uid] then
		return nil
	end
	record.loc, record.station = "carried", nil -- saved as stored until it is put away below
	table.insert(data.workers, record)
	index[record.uid] = record
	return WorkerInventory.putAway(player, record.uid, freeStationIndex(data, stationsFor(player)))
end

-- Studio tests only: ignore this player's next `count` requests, as if they were lost on the way.
WorkerInventory._test = {
	dropNext = function(player: Player, count: number)
		if game:GetService("RunService"):IsStudio() then
			dropNext[player] = count
		end
	end,
}

-- Hooks into placement, carrying and saving, then starts loading player data.
function WorkerInventory.start()
	NPCPlacement.setPlacedHandler(onPlaced)
	NPCCarry.setDropHandler(onDropped)
	PlayerData.setSerializer(serialize)
	PlayerData.onLoaded(onLoaded)
	actionEvent.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		-- After PlayerData's own PlayerRemoving handler has taken its snapshot.
		task.defer(function()
			byUid[player] = nil
			lastRequest[player] = nil
			lastRefresh[player] = nil
			recent[player], dropNext[player] = nil, nil
		end)
	end)
	PlayerData.start()
end

return WorkerInventory
