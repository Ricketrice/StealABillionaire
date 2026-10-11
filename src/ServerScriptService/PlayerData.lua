-- Studio location: ServerScriptService.PlayerData (ModuleScript)
-- PlayerData
-- Loads, autosaves and saves each player's persistent data through a session-locked SessionStore.
--
-- Saved data (schema 3):
--   { schema = 3, cash = <whole $>, workers = { { uid, id, zone, level, tier, loc, station? } },
--     zones = { <unlocked district id>, ... }, hub = { ... } }
--   hub (schema 3, Milestone 026) belongs to the hub systems (arena trophies, shop purchases, lot
--   decor, upgrades, tutorial, daily quests: see ServerScriptService.HubBase). PlayerData only keeps
--   it safe: a small tree of numbers, booleans and short strings. Schema 2 saves load with it empty.
--   loc is "station" (with station = 1..6) or "inventory". The plot number is not saved.
--   zones lists the districts bought with cash (ZoneConfig); Main Street is free and never listed.
--   Schema 1 saves load with no unlocked districts.
--
-- Zone mirror: every unlock is also written to a second key in the same DataStore,
-- "zones_<userId>" = { zones = { ... } }, and loading merges both. A server still running the
-- schema 1 code would drop `zones` from the main record when it saves, but it never touches the
-- mirror, so an unlock can't be lost to an outdated server. Unlocks are permanent, so merging is
-- always a union.
--
-- Lifecycle:
--   join      load. Loads and releases for the same user on this server run one at a time, so a
--             quick leave + rejoin always loads after the previous visit's final save. Until the
--             load succeeds the player has no profile, so gameplay that changes data is refused
--             (see PlayerData.isLoaded). If loading fails the player is kicked and nothing is ever
--             saved for them, so a failed load can't overwrite their real data with defaults.
--   play      autosave every AUTOSAVE_INTERVAL seconds. Unchanged data is not rewritten, except
--             every LEASE_REFRESH seconds to keep the session lock fresh.
--   leave     final save that releases the lock.
--   shutdown  BindToClose saves and releases everyone still here.
-- If a save finds the session lock taken by another session, the player is kicked and this server
-- stops saving them. Taking over another live session's lock on load is logged.
--
-- Studio uses its own DataStore name, so Studio testing can never touch live players' saves. If
-- Studio's API access is disabled, Studio falls back to an in-memory store and warns that nothing
-- persists between sessions. Live servers always use the real DataStore.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CashService = require(script.Parent:WaitForChild("CashService"))
local DataStoreMock = require(script.Parent:WaitForChild("DataStoreMock"))
local SessionStore = require(script.Parent:WaitForChild("SessionStore"))

local PlayerData = {}

local SCHEMA = 3
local DATASTORE_NAME = if RunService:IsStudio() then "SAB_PlayerData_Studio_v1" else "SAB_PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local LEASE_REFRESH = 300 -- rewrite unchanged data this often (well inside SessionStore's 600s lock expiry)
local SHUTDOWN_TIMEOUT = 25 -- Roblox allows ~30s in BindToClose
local LOADED_ATTRIBUTE = "DataLoaded"

export type WorkerRecord = {
	uid: string,
	id: string,
	zone: string,
	level: number,
	tier: string,
	loc: string, -- "station" | "inventory" (and "carried" in memory only)
	station: number?,
}

export type Data = {
	schema: number,
	cash: number,
	workers: { WorkerRecord },
	zones: { string }, -- unlocked districts (ZoneConfig ids)
	hub: { [string]: any }, -- hub systems' data (see the header)
}

-- Per loaded player: the lock id from SessionStore.load, and what/when this session last wrote.
type Session = { lockId: string, lastJson: string?, lastWrite: number }

local profiles: { [Player]: Data } = {}
local sessions: { [Player]: Session } = {}
local busyUsers: { [number]: boolean } = {} -- userId -> a load or final save is in progress
local stats = { writes = 0, unchangedSkipped = 0, failed = 0 } -- for tests and diagnostics
local loadedCallbacks: { (Player, Data) -> () } = {}
local serializer: ((Player, Data) -> Data)? = nil
local session: SessionStore.SessionStore? = nil
local persistent = true -- false when Studio fell back to the in-memory store
-- Hooks for systems that move workers between players (Milestone 022). None of them changes what is saved.
local newPlayers: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- joined with no saved data
local savedCallbacks: { (Player, boolean, number, string) -> () } = {}
local finalSaveHooks: { (Player, Data) -> () } = {}

local function key(userId: number): string
	return "player_" .. userId
end

local function mirrorKey(userId: number): string
	return "zones_" .. userId
end

-- Picks the store once: the real DataStore, or (Studio only) the in-memory mock when API access is off
-- or the ServerStorage attribute "StudioMemoryStore" is true (so test harnesses never touch real saves).
local function getSession(): SessionStore.SessionStore
	if session then
		return session
	end
	local store: any = DataStoreService:GetDataStore(DATASTORE_NAME)
	if RunService:IsStudio() then
		local forced = ServerStorage:GetAttribute("StudioMemoryStore") == true
		local ok, err = true, nil
		if not forced then
			ok, err = pcall(store.GetAsync, store, "__api_probe")
		end
		if forced or (not ok and tostring(err):find("Studio access to APIs is not allowed", 1, true)) then
			warn(if forced then "[PlayerData] ServerStorage.StudioMemoryStore is set: using a temporary in-memory store (Studio test)." else "[PlayerData] Studio API access is disabled: using a temporary in-memory store. NOTHING WILL BE SAVED between Studio sessions. Enable it in Game Settings > Security to test real saving.")
			store = DataStoreMock.new()
			persistent = false
			-- TEST HOOKS (Studio + in-memory store only, so never a real DataStore):
			--   ServerStorage "StudioTestSeed"      JSON of saved data every player starts from
			--   ServerStorage "StudioTestFailLoads" number of upcoming store requests that fail
			local seed = ServerStorage:GetAttribute("StudioTestSeed")
			if type(seed) == "string" then
				local seedData = HttpService:JSONDecode(seed)
				local original = store.UpdateAsync
				store.UpdateAsync = function(self, key, transform)
					if self.values[key] == nil then
						self.values[key] = { data = seedData }
					end
					return original(self, key, transform)
				end
				print("[PlayerData] Studio test seed active")
			end
			local failLoads = ServerStorage:GetAttribute("StudioTestFailLoads")
			if type(failLoads) == "number" then
				store.failNext = failLoads
				print("[PlayerData] Studio test: next", failLoads, "store requests will fail")
			end
		end
	end
	if session then
		return session -- another thread finished picking while we probed
	end
	session = SessionStore.new({ store = store, sessionId = HttpService:GenerateGUID(false) })
	return session :: SessionStore.SessionStore
end

local function defaults(): Data
	return { schema = SCHEMA, cash = 0, workers = {}, zones = {}, hub = {} }
end

-- Brings older saved data up to the current schema.
local function migrate(data: any): any
	if data.schema == nil then
		data.schema = 1
	end
	if data.schema == 1 then
		data.zones = data.zones or {} -- schema 2 adds unlocked districts; older saves have none
		data.schema = 2
	end
	if data.schema == 2 then
		data.hub = data.hub or {} -- schema 3 adds the hub systems' data; older saves have none
		data.schema = 3
	end
	return data
end

local function wholeNumber(value: any, fallback: number): number
	if type(value) == "number" and value == value and value >= 0 and value < 2 ^ 53 then
		return math.floor(value)
	end
	return fallback
end

local MAX_ZONES = 32

-- A clean list of district ids: unique, plain ids only. Unknown ids are kept (never deleted), so
-- districts added by a future update survive an older catalogue.
local function cleanZones(value: any): { string }
	local zones, seen = {}, {}
	if type(value) == "table" then
		for _, id in value do
			if type(id) == "string" and #id <= 40 and id:match("^[%w_]+$") and not seen[id] and #zones < MAX_ZONES then
				seen[id] = true
				table.insert(zones, id)
			end
		end
	end
	return zones
end

-- A clean copy of the hub data: tables up to 4 deep holding finite numbers, booleans and short
-- strings under short string keys (or list positions). Anything else is dropped.
local HUB_DEPTH, HUB_ENTRIES, HUB_TEXT = 4, 300, 60
local function cleanTree(value: any, depth: number): any
	if type(value) == "number" then
		return if value == value and math.abs(value) < 2 ^ 53 then value else nil
	elseif type(value) == "boolean" then
		return value
	elseif type(value) == "string" then
		return if #value <= HUB_TEXT then value else nil
	elseif type(value) == "table" and depth < HUB_DEPTH then
		local clean, count = {}, 0
		for k, v in value do
			local key = if type(k) == "string" and #k <= HUB_TEXT then k elseif type(k) == "number" and k % 1 == 0 and k >= 1 and k <= HUB_ENTRIES then k else nil
			local item = if key ~= nil then cleanTree(v, depth + 1) else nil
			if item ~= nil and count < HUB_ENTRIES then
				clean[key] = item
				count += 1
			end
		end
		return clean
	end
	return nil
end

-- Repairs anything malformed without discarding valid workers. Unknown worker ids are kept
-- (never deleted) so data from a future catalogue survives; the inventory just skips spawning them.
local function sanitize(data: any): Data
	local clean = defaults()
	clean.cash = wholeNumber(data.cash, 0)
	local seen = {}
	if type(data.workers) == "table" then
		for _, w in data.workers do
			if type(w) == "table" and type(w.uid) == "string" and type(w.id) == "string" and not seen[w.uid] then
				seen[w.uid] = true
				local station = if w.loc == "station" then wholeNumber(w.station, 0) else 0
				table.insert(clean.workers, {
					uid = w.uid,
					id = w.id,
					zone = if type(w.zone) == "string" then w.zone else "",
					level = math.max(1, wholeNumber(w.level, 1)),
					tier = if type(w.tier) == "string" then w.tier else "Normal",
					loc = if station >= 1 then "station" else "inventory",
					station = if station >= 1 then station else nil,
				})
			end
		end
	end
	clean.zones = cleanZones(data.zones)
	clean.hub = cleanTree(data.hub, 0) or {}
	return clean
end

PlayerData._sanitize = sanitize -- exposed for tests
PlayerData._migrate = migrate

-- Zone mirror (see the header) ---------------------------------------------------------------------
local MIRROR_ATTEMPTS = 3

-- The mirror's districts, or nil if the request failed.
local function readZoneMirror(userId: number): { string }?
	local zones = nil
	local ok, err = pcall(function()
		getSession().store:UpdateAsync(mirrorKey(userId), function(record)
			zones = cleanZones(type(record) == "table" and record.zones)
			return nil -- read only: nothing is written
		end)
	end)
	if not ok then
		warn("[PlayerData] couldn't read the zone mirror for", userId, "-", err)
		return nil
	end
	return zones or {}
end

-- Adds `zones` to the mirror. A union: nothing is ever removed. Returns whether it was written.
local function writeZoneMirror(userId: number, zones: { string }): boolean
	for attempt = 1, MIRROR_ATTEMPTS do
		local ok, err = pcall(function()
			getSession().store:UpdateAsync(mirrorKey(userId), function(record)
				local merged = cleanZones(type(record) == "table" and record.zones)
				for _, id in cleanZones(zones) do
					if not table.find(merged, id) then
						table.insert(merged, id)
					end
				end
				return { zones = merged }
			end)
		end)
		if ok then
			return true
		end
		warn("[PlayerData] zone mirror write failed for", userId, "-", err)
		if attempt < MIRROR_ATTEMPTS then
			task.wait(2)
		end
	end
	return false
end

-- Adds the mirror's districts to the loaded data. Returns whether the mirror is missing any of the
-- data's districts (so it should be repaired).
local function mergeZones(data: Data, mirrored: { string }?): boolean
	local mirrorBehind = mirrored == nil and #data.zones > 0
	for _, id in data.zones do
		if mirrored and not table.find(mirrored, id) then
			mirrorBehind = true
		end
	end
	for _, id in mirrored or {} do
		if not table.find(data.zones, id) then
			table.insert(data.zones, id)
		end
	end
	data.zones = cleanZones(data.zones)
	return mirrorBehind
end

-- The loaded data for a player, or nil while loading / if loading failed.
function PlayerData.get(player: Player): Data?
	return profiles[player]
end

function PlayerData.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Whether saves actually persist (false only in Studio without API access).
function PlayerData.isPersistent(): boolean
	return persistent
end

-- Whether this visit started with no saved data at all (a brand-new player). In memory only.
function PlayerData.isNew(player: Player): boolean
	return newPlayers[player] == true
end

-- Runs `callback(player, ok, snapshotAt, json)` after every save attempt: `json` is the copy of the
-- data that was (or would have been) written and `snapshotAt` the os.clock() it was taken at.
function PlayerData.onSaved(callback: (Player, boolean, number, string) -> ())
	table.insert(savedCallbacks, callback)
end

-- Runs `hook(player, data)` just before a leaving player's final save takes its copy of the data.
-- A hook may yield for a few seconds (it delays only that player's final save), e.g. to let a
-- transfer between two players settle first.
function PlayerData.beforeFinalSave(hook: (Player, Data) -> ())
	table.insert(finalSaveHooks, hook)
end

-- The store the saves live in, for small records kept beside a player's save under their own keys
-- (the zone mirror above, the PvP transfer journal). Never use it on a "player_" key.
function PlayerData.store(): any
	return getSession().store
end

-- Runs `callback(player, data)` once each player's data has loaded.
function PlayerData.onLoaded(callback: (Player, Data) -> ())
	table.insert(loadedCallbacks, callback)
	for player, data in profiles do
		task.spawn(callback, player, data)
	end
end

-- Sets the function that turns live data into the data to save (e.g. stores a carried worker).
function PlayerData.setSerializer(fn: (Player, Data) -> Data)
	serializer = fn
end

-- The data to save, as JSON: a detached copy, so play can continue while the save is in flight,
-- and directly comparable with the last write to skip unchanged autosaves.
local function encodeForSave(player: Player, data: Data): string
	data.cash = CashService.get(player)
	local toSave = if serializer then serializer(player, data) else data
	return HttpService:JSONEncode(toSave)
end

-- Writes a player's data through their session. `release` gives up the lock (final save).
-- A non-final save of unchanged data is skipped while the lock was written recently.
local function saveData(player: Player, data: Data, s: Session, release: boolean?): boolean
	local snapshotAt = os.clock()
	local json = encodeForSave(player, data)
	local function report(saved: boolean)
		for _, callback in savedCallbacks do
			task.spawn(callback, player, saved, snapshotAt, json)
		end
	end
	if not release and json == s.lastJson and os.clock() - s.lastWrite < LEASE_REFRESH then
		stats.unchangedSkipped += 1
		report(true)
		return true
	end

	local ok, reason = getSession():save(key(player.UserId), HttpService:JSONDecode(json), release, s.lockId)
	if ok then
		stats.writes += 1
		s.lastJson, s.lastWrite = json, os.clock()
		report(true)
		return true
	end

	stats.failed += 1
	report(false)
	if not release and profiles[player] ~= data then
		-- An autosave that finished after this visit's final save: refusing it is correct, because
		-- the final save already wrote newer data.
		print("[PlayerData] discarded a stale autosave for", player.Name, "-", reason)
		return false
	end
	warn("[PlayerData]", if release then "final save" else "save", "failed for", player.Name, "-", reason)
	if reason == "session lost" and profiles[player] == data then
		profiles[player], sessions[player] = nil, nil -- another session owns this data now; stop saving it here
		player:Kick("Your data was opened on another server. Please rejoin.")
	end
	return false
end

-- Saves a player now, keeping the session lock (skipped if unchanged and the lock is fresh).
-- Returns whether the data is saved.
function PlayerData.save(player: Player): boolean
	local data, s = profiles[player], sessions[player]
	return data ~= nil and s ~= nil and saveData(player, data, s, false)
end

-- Saves a newly unlocked district: the zone mirror first, then the main record. Returns whether
-- both were written; anything missed is retried by later saves and repaired on the next load.
function PlayerData.saveZones(player: Player): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	local mirrored = writeZoneMirror(player.UserId, data.zones)
	local saved = PlayerData.save(player)
	return mirrored and saved
end

-- Loads and final saves of the same user on this server run one at a time.
local function claimUser(userId: number)
	local waited = 0
	while busyUsers[userId] and waited < SHUTDOWN_TIMEOUT do
		waited += task.wait(0.1)
	end
	busyUsers[userId] = true -- no yield since the check, so no other thread can slip in
end

local function load(player: Player)
	local userId = player.UserId
	claimUser(userId) -- e.g. their previous visit's final save must land first
	local ok, result, lockId, takenFrom = getSession():load(key(userId))
	-- Read while this user is still claimed, so leaving mid-load is handled below exactly as before.
	local mirroredZones = if ok then readZoneMirror(userId) else nil
	if ok and takenFrom then
		warn("[PlayerData] took over", player.Name, "'s data from another session that didn't release it:", takenFrom)
	end
	if ok and not player.Parent then
		-- Left while loading: put the data back unchanged and release the lock.
		getSession():save(key(userId), result, true, lockId :: string)
	end
	busyUsers[userId] = nil

	if not player.Parent then
		return
	end
	if not ok then
		warn("[PlayerData] load failed for", player.Name, "-", result)
		player:Kick("We couldn't load your saved data, so we stopped before changing anything. Please rejoin.")
		return
	end

	newPlayers[player] = result == nil -- nothing was saved for them yet (see PlayerData.isNew)
	local data = sanitize(migrate(result or defaults()))
	if mergeZones(data, mirroredZones) then
		task.spawn(writeZoneMirror, userId, data.zones) -- repair a mirror that is missing districts
	end
	player:SetAttribute("Cash", data.cash)
	profiles[player] = data
	-- Loading just wrote the lock, so an autosave of this exact data would be redundant.
	sessions[player] = { lockId = lockId :: string, lastJson = encodeForSave(player, data), lastWrite = os.clock() }
	player:SetAttribute(LOADED_ATTRIBUTE, true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

-- Final save that releases the lock. Taking the profile out first means it runs once per player
-- even if both PlayerRemoving and BindToClose ask, and no later autosave can follow it.
local function onLeaving(player: Player)
	local data, s = profiles[player], sessions[player]
	if not (data and s) then
		return
	end
	profiles[player], sessions[player] = nil, nil
	claimUser(player.UserId) -- before the hooks: a rejoin's load waits until this save has landed
	for _, hook in finalSaveHooks do
		local ok, err = pcall(hook, player, data)
		if not ok then
			warn("[PlayerData] final-save hook failed:", err)
		end
	end
	saveData(player, data, s, true)
	busyUsers[player.UserId] = nil
end

-- Test seams (used by Studio test scripts only): swap in a SessionStore over a mock store, and
-- drive the lifecycle with stand-in players.
PlayerData._test = {
	setSession = function(s: SessionStore.SessionStore)
		session = s
	end,
	load = load,
	leave = onLeaving,
	mirrorKey = mirrorKey,
	readZoneMirror = readZoneMirror,
	stats = stats,
	isBusy = function(userId: number): boolean
		return busyUsers[userId] == true
	end,
	ageSession = function(player: Player, seconds: number)
		local s = sessions[player]
		if s then
			s.lastWrite -= seconds
		end
	end,
	counts = function(): (number, number)
		local p, s = 0, 0
		for _ in profiles do
			p += 1
		end
		for _ in sessions do
			s += 1
		end
		return p, s
	end,
}

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(onLeaving)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				if player.Parent then
					task.spawn(PlayerData.save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				onLeaving(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < SHUTDOWN_TIMEOUT do
			waited += task.wait(0.1)
		end
	end)
end

return PlayerData
