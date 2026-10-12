-- Studio location: ReplicatedStorage.WorkerState (ModuleScript)
-- WorkerState
-- The client's single copy of this player's worker inventory. Listens to the server's
-- InventorySync snapshots once and shares them with every UI script (HUD, inventory), so no
-- script re-requests or re-parses data on its own. Display only: the server owns the data.
--   WorkerState.snapshot     latest { slots, stations, workers = { { uid, id, loc, station?, level, tier } } }
--   WorkerState.Changed      BindableEvent fired after every new snapshot
--   WorkerState.counts()     stored, equipped, carried
--   WorkerState.carried()    the carried entry, if any
--   WorkerState.request(action, uid?)  sends an InventoryAction to the server; it is sent again (same
--                                      id) until the server answers, so a lost message never leaves a
--                                      carried worker stuck. The server never runs one id twice.
--   WorkerState.Answered     BindableEvent (action, ok?, message?) when a request is answered
--   WorkerState.pending()    how many requests are still waiting for an answer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))

local actionEvent = ReplicatedStorage:WaitForChild("InventoryAction") :: RemoteEvent
local syncEvent = ReplicatedStorage:WaitForChild("InventorySync") :: RemoteEvent
local ackEvent = ReplicatedStorage:WaitForChild("InventoryAck") :: RemoteEvent

local RESEND_AFTER = 3 -- seconds without an answer before sending the same request again
local RETRY_SOON = 0.3 -- the server said "too fast" or "still loading"
local MAX_SENDS = 4

local WorkerState = {}
WorkerState.snapshot = { slots = InventoryConfig.INVENTORY_SLOTS, stations = InventoryConfig.STATION_SLOTS, workers = {} }
WorkerState.loaded = false
local changed = Instance.new("BindableEvent")
WorkerState.Changed = changed.Event
local answered = Instance.new("BindableEvent")
WorkerState.Answered = answered.Event

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

type Pending = { action: string, uid: any, sends: number, nextAt: number }
local pending: { [number]: Pending } = {}
local nextId = 0
local watching = false

local function send(id: number, p: Pending)
	p.sends += 1
	p.nextAt = os.clock() + RESEND_AFTER
	actionEvent:FireServer(p.action, p.uid, id)
end

-- One small loop while anything is waiting (none at all otherwise).
local function watch()
	if watching then
		return
	end
	watching = true
	task.spawn(function()
		while next(pending) do
			task.wait(0.25)
			local now = os.clock()
			for id, p in pending do
				if now >= p.nextAt then
					if p.sends >= MAX_SENDS then
						pending[id] = nil
						answered:Fire(p.action, nil, nil)
					else
						send(id, p)
					end
				end
			end
		end
		watching = false
	end)
end

function WorkerState.request(action: string, uid: any)
	if action == "Refresh" then
		actionEvent:FireServer(action)
		return
	end
	nextId += 1
	local p: Pending = { action = action, uid = uid, sends = 0, nextAt = 0 }
	pending[nextId] = p
	send(nextId, p)
	watch()
end

function WorkerState.pending(): number
	local n = 0
	for _ in pending do
		n += 1
	end
	return n
end

ackEvent.OnClientEvent:Connect(function(id, ok, message, retry)
	local p = type(id) == "number" and pending[id]
	if not p then
		return
	end
	if retry then
		p.nextAt = math.min(p.nextAt, os.clock() + RETRY_SOON)
		return
	end
	pending[id] = nil
	answered:Fire(p.action, ok, message)
end)

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
