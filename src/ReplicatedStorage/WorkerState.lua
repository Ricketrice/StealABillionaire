-- Studio location: ReplicatedStorage.WorkerState (ModuleScript)
-- WorkerState
-- The client's single copy of this player's worker inventory. Listens to the server's
-- InventorySync snapshots once and shares them with every UI script (HUD, inventory), so no
-- script re-requests or re-parses data on its own. Display only: the server owns the data.
--   WorkerState.snapshot     latest { slots, stations, workers = { { uid, id, loc, station?, level, tier } } }
--   WorkerState.Changed      BindableEvent fired after every new snapshot
--   WorkerState.counts()     stored, equipped, carried
--   WorkerState.carried()    the carried entry, if any
--   WorkerState.request(action, uid?)  sends an InventoryAction to the server

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))

local actionEvent = ReplicatedStorage:WaitForChild("InventoryAction") :: RemoteEvent
local syncEvent = ReplicatedStorage:WaitForChild("InventorySync") :: RemoteEvent

local WorkerState = {}
WorkerState.snapshot = { slots = InventoryConfig.INVENTORY_SLOTS, stations = InventoryConfig.STATION_SLOTS, workers = {} }
WorkerState.loaded = false
local changed = Instance.new("BindableEvent")
WorkerState.Changed = changed.Event

function WorkerState.counts(): (number, number, number)
	local stored, equipped, carried = 0, 0, 0
	for _, e in WorkerState.snapshot.workers do
		if e.loc == "inventory" then
			stored += 1
		elseif e.loc == "station" then
			equipped += 1
		else
			carried += 1
		end
	end
	return stored, equipped, carried
end

function WorkerState.carried()
	for _, e in WorkerState.snapshot.workers do
		if e.loc == "carried" then
			return e
		end
	end
	return nil
end

function WorkerState.request(action: string, uid: string?)
	actionEvent:FireServer(action, uid)
end

syncEvent.OnClientEvent:Connect(function(snap)
	if type(snap) ~= "table" or type(snap.workers) ~= "table" then
		return
	end
	WorkerState.snapshot = snap
	WorkerState.loaded = true
	changed:Fire(snap)
end)

actionEvent:FireServer("Refresh") -- in case data loaded before any UI script started

return WorkerState
