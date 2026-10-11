-- Studio location: ServerScriptService.SessionStore (ModuleScript)
-- SessionStore
-- Session-locked load/save of one record per key, on top of any store with a DataStore-style
-- UpdateAsync(key, transform). Every read-modify-write goes through UpdateAsync, so it is atomic.
--
-- Stored record: { data = <payload>, lock = { session = <id>, time = <os.time> }? }
--
-- Rules that keep data safe:
--   * load() takes the lock. While another session holds a fresh lock it waits and retries;
--     on its final attempt it takes the lock over (as ProfileService does), which is safe because:
--   * save() only writes while this session still owns the lock. If the lock was taken over, the
--     write is cancelled and save() reports "session lost" - an old session can never overwrite
--     newer data.
--   * A failed load returns false and takes no lock; the caller must not save anything for that
--     key, so a failed load can never be followed by defaults overwriting real data.
--   * Saving refreshes the lock time; releasing on leave clears it so the next server loads at once.
--   * Each load gets its own lock id ("<sessionId>#<n>"), returned by load() and required by save().
--     So even on the same server, a stale save from a player's previous visit (e.g. an autosave
--     still in flight when they left and rejoined) can never overwrite the data of their new visit.
--     The stored lock format { session, time } is unchanged.

local SessionStore = {}
SessionStore.__index = SessionStore

export type Store = {
	UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any,
}

export type Options = {
	store: Store,
	sessionId: string, -- unique to this server
	lockExpiry: number?, -- seconds after which another session's un-refreshed lock counts as abandoned
	loadAttempts: number?, -- tries while the record is locked elsewhere or requests fail
	saveAttempts: number?, -- tries when a save request fails
	retryDelay: number?, -- seconds between tries
	now: (() -> number)?, -- clock, injectable for tests
	wait: ((number) -> ())?, -- delay, injectable for tests
}

export type SessionStore = typeof(setmetatable({} :: {
	store: Store,
	sessionId: string,
	lockExpiry: number,
	loadAttempts: number,
	saveAttempts: number,
	retryDelay: number,
	now: () -> number,
	wait: (number) -> (),
	loads: number,
}, SessionStore))

function SessionStore.new(options: Options): SessionStore
	return setmetatable({
		store = options.store,
		sessionId = options.sessionId,
		lockExpiry = options.lockExpiry or 600,
		loadAttempts = options.loadAttempts or 5,
		saveAttempts = options.saveAttempts or 3,
		retryDelay = options.retryDelay or 3,
		now = options.now or os.time,
		wait = options.wait or task.wait,
		loads = 0,
	}, SessionStore)
end

-- Loads and locks the record. Returns (true, data, lockId, takenFrom?) where data is nil for a
-- brand-new key, lockId must be passed to save(), and takenFrom is the lock id of another live
-- session this load took over (for logging); or (false, reason) if it could not be loaded safely.
function SessionStore.load(self: SessionStore, key: string): (boolean, any, string?, string?)
	self.loads += 1
	local lockId = self.sessionId .. "#" .. self.loads
	local lastError = "unknown error"
	for attempt = 1, self.loadAttempts do
		local loaded, data, problem, takenFrom = false, nil, nil, nil
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				loaded, data, problem, takenFrom = false, nil, nil, nil
				record = record or {}
				if type(record) ~= "table" or (record.data ~= nil and type(record.data) ~= "table") then
					problem = "stored record is malformed"
					return nil -- never touch data we don't understand
				end
				local lock = record.lock
				local now = self.now()
				local heldElsewhere = type(lock) == "table" and lock.session ~= lockId and now - (tonumber(lock.time) or 0) < self.lockExpiry
				if heldElsewhere and attempt < self.loadAttempts then
					problem = "locked by another session"
					return nil -- leave it alone and try again shortly
				end
				takenFrom = if heldElsewhere then tostring(lock.session) else nil
				record.lock = { session = lockId, time = now }
				loaded, data = true, record.data
				return record
			end)
		end)
		if ok and loaded then
			return true, data, lockId, takenFrom
		end
		lastError = if ok then problem or "not loaded" else tostring(err)
		if problem == "stored record is malformed" then
			break -- retrying won't help
		end
		if attempt < self.loadAttempts then
			self.wait(self.retryDelay)
		end
	end
	return false, lastError
end

-- Writes `data` if the lock taken by load() (`lockId`) is still held. `release` clears the lock
-- afterwards. Returns true, or (false, reason); reason "session lost" means another session owns
-- the data now and nothing was written.
function SessionStore.save(self: SessionStore, key: string, data: any, release: boolean?, lockId: string): (boolean, string?)
	local lastError = "unknown error"
	for attempt = 1, self.saveAttempts do
		local written, lost = false, false
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				written, lost = false, false
				local lock = type(record) == "table" and record.lock
				if type(lock) ~= "table" or lock.session ~= lockId then
					lost = true
					return nil -- not ours any more: never overwrite
				end
				record.data = data
				record.lock = if release then nil else { session = lockId, time = self.now() }
				written = true
				return record
			end)
		end)
		if ok and written then
			return true
		end
		if ok and lost then
			return false, "session lost"
		end
		lastError = tostring(err)
		if attempt < self.saveAttempts then
			self.wait(self.retryDelay)
		end
	end
	return false, lastError
end

return SessionStore
