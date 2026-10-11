-- Studio location: ServerScriptService.PvPTransfer (ModuleScript)
-- PvPTransfer  (Milestone 022.1)
-- The durable transfer journal that makes handing a stolen worker from one player to another
-- survive a server crash at any moment: the worker always ends up with exactly one owner.
--
-- Two players' saves can't be written together, so the hand-over is decided by one small write
-- instead, and each player's save just follows it:
--
--   journal of the previous owner   sent[uid]      = { to, id, at }          "may be leaving"
--   journal of the new owner        received[id]   = { uid, from, record, at, applied? }
--                                   voided[id]     = time                    "this one never happened"
--
--   1. prepare   write sent[uid] in the previous owner's journal
--   2. commit    write received[id] in the new owner's journal        <- the worker changes hands HERE
--   3. both players' saves are written (in any order), then the two entries are removed
--
-- A crash before step 2 leaves the worker with its previous owner; a crash after it leaves it with
-- the new owner, whatever the two saves contain. Whenever a player's data loads, `replay` puts it
-- right: a `sent` entry asks the new owner's journal whether the commit exists (and, in the same
-- write, voids it if not, so a late commit can never land afterwards) and drops the worker if it
-- does; a `received` entry that has not been applied adds the worker if it is missing. Everything
-- here can be repeated any number of times with the same result.
--
-- Storage: one more key per player, "pvpx_<userId>", in the same DataStore as the player's save
-- (like the zone mirror). It is NOT part of the save: the save schema is unchanged. The journal
-- carries a copy of the worker record, so the worker exists even while neither save has it.
-- Every function takes the store, so tests can run the same code on a copy of the stored data.

local PvPTransfer = {}

local VOID_KEEP = 86400 -- seconds a "never happened" mark is kept (far longer than any server can stay half-alive)

local function key(userId: number): string
	return "pvpx_" .. userId
end
PvPTransfer.key = key

local function normal(journal: any): any
	journal = if type(journal) == "table" then journal else {}
	for _, field in { "sent", "received", "voided" } do
		if type(journal[field]) ~= "table" then
			journal[field] = {}
		end
	end
	return journal
end

-- A fresh copy of a player's journal (never a cached one), or nil if the request failed.
function PvPTransfer.read(store: any, userId: number): any?
	local journal = nil
	local ok = pcall(function()
		store:UpdateAsync(key(userId), function(stored)
			journal = normal(stored)
			return nil -- read only
		end)
	end)
	return if ok then journal or normal(nil) else nil
end

-- Changes a player's journal in one atomic step. `change(journal)` returns whether to write.
-- Returns whether the request went through.
local function update(store: any, userId: number, change: (any) -> boolean): boolean
	local ok = pcall(function()
		store:UpdateAsync(key(userId), function(stored)
			local journal = normal(stored)
			return if change(journal) then journal else nil
		end)
	end)
	return ok
end

-- Step 1. Returns whether it was written.
function PvPTransfer.prepare(store: any, ownerId: number, thiefId: number, uid: string, id: string): boolean
	return update(store, ownerId, function(journal)
		journal.sent[uid] = { to = thiefId, id = id, at = os.time() }
		return true
	end)
end

-- Step 2, the moment the worker changes hands. `entry` = { uid, from, record, at }.
-- Returns "committed", "voided" (refused: the previous owner's side already ruled it out) or
-- "unknown" (the request failed, so it may or may not have been written: ask `decide`).
function PvPTransfer.commit(store: any, thiefId: number, id: string, entry: any): string
	local outcome = "unknown"
	local ok = pcall(function()
		store:UpdateAsync(key(thiefId), function(stored)
			local journal = normal(stored)
			if journal.voided[id] then
				outcome = "voided"
				return nil
			end
			journal.received[id] = entry
			outcome = "committed"
			return journal
		end)
	end)
	return if ok then outcome else "unknown"
end

-- Settles a transfer whose commit is in doubt, in one atomic step on the new owner's journal:
-- "committed" if the commit is there; otherwise it is voided for good and "voided" is returned.
-- nil if the request failed (nothing is known yet).
function PvPTransfer.decide(store: any, thiefId: number, id: string): string?
	local verdict = nil
	local ok = pcall(function()
		store:UpdateAsync(key(thiefId), function(stored)
			local journal = normal(stored)
			if journal.received[id] then
				verdict = "committed"
				return nil
			end
			verdict = "voided"
			if journal.voided[id] then
				return nil
			end
			local now = os.time()
			for other, at in journal.voided do
				if type(at) ~= "number" or now - at > VOID_KEEP then
					journal.voided[other] = nil
				end
			end
			journal.voided[id] = now
			return journal
		end)
	end)
	return if ok then verdict else nil
end

-- Removes the previous owner's entry (their save no longer has the worker, or the transfer never
-- happened). Returns whether the request went through.
function PvPTransfer.clearSent(store: any, ownerId: number, uid: string, id: string): boolean
	return update(store, ownerId, function(journal)
		local entry = journal.sent[uid]
		if type(entry) == "table" and entry.id == id then
			journal.sent[uid] = nil
			return true
		end
		return false
	end)
end

-- Marks the new owner's entry as applied (their save has the worker now), so a later load never
-- adds the worker again. Returns whether the request went through.
function PvPTransfer.markApplied(store: any, thiefId: number, id: string): boolean
	return update(store, thiefId, function(journal)
		local entry = journal.received[id]
		if type(entry) == "table" and not entry.applied then
			entry.applied = true
			return true
		end
		return false
	end)
end

-- Removes the new owner's entry once nothing needs it any more: it is applied and the previous
-- owner's entry is gone. Returns whether it was removed.
function PvPTransfer.tidy(store: any, thiefId: number, id: string): boolean
	local journal = PvPTransfer.read(store, thiefId)
	local entry = journal and journal.received[id]
	if not (type(entry) == "table" and entry.applied) then
		return false
	end
	local previous = PvPTransfer.read(store, entry.from)
	if not previous then
		return false
	end
	local sent = previous.sent[entry.uid]
	if type(sent) == "table" and sent.id == id then
		return false -- the previous owner's side still needs this entry as proof of the commit
	end
	local removed = false
	local ok = update(store, thiefId, function(current)
		removed = current.received[id] ~= nil
		current.received[id] = nil
		return removed
	end)
	return ok and removed
end

-- Brings one player's workers in line with the journal. `ops` is how to look at and change their
-- workers: { has = (uid) -> boolean, drop = (uid, entry), add = (record, entry) }.
-- Returns (true, { out = { [uid] = { id, to } }, inc = { [id] = { uid, from } } }) where `out` and
-- `inc` are the entries still waiting for this player's next save (see afterSave), or false if a
-- request failed (whatever was already done is correct; just run it again).
function PvPTransfer.replay(store: any, userId: number, ops: any): (boolean, any)
	local journal = PvPTransfer.read(store, userId)
	if not journal then
		return false, nil
	end
	local steps = {}
	for uid, entry in journal.sent do
		if type(entry) == "table" and type(entry.id) == "string" and type(entry.to) == "number" then
			table.insert(steps, { sent = true, uid = uid, entry = entry, at = tonumber(entry.at) or 0 })
		end
	end
	for id, entry in journal.received do
		if type(entry) == "table" and type(entry.uid) == "string" and type(entry.from) == "number" and type(entry.record) == "table" then
			table.insert(steps, { sent = false, id = id, entry = entry, at = tonumber(entry.at) or 0 })
		end
	end
	table.sort(steps, function(a, b) -- oldest first, so a worker that left and came back ends up right
		return a.at < b.at
	end)

	local result = { out = {}, inc = {} }
	for _, step in steps do
		local entry = step.entry
		if step.sent then
			local verdict = PvPTransfer.decide(store, entry.to, entry.id)
			if not verdict then
				return false, nil
			end
			if verdict == "committed" then
				if ops.has(step.uid) then
					ops.drop(step.uid, entry)
				end
				result.out[step.uid] = { id = entry.id, to = entry.to }
			else
				PvPTransfer.clearSent(store, userId, step.uid, entry.id) -- if this fails it is simply decided again next time
			end
		elseif not entry.applied then
			if not ops.has(entry.uid) then
				local record = table.clone(entry.record)
				record.uid = entry.uid
				ops.add(record, entry)
			end
			result.inc[step.id] = { uid = entry.uid, from = entry.from }
		else
			PvPTransfer.tidy(store, userId, step.id)
		end
	end
	return true, result
end

-- Call after one of the player's saves has been written; `json` is what was written. Clears the
-- journal entries that save has made unnecessary: `out` entries once the save no longer has the
-- worker, `inc` entries once it has. `out` and `inc` are the tables from replay (or the same
-- shape, filled in by a live transfer); finished entries are removed from them. Entries created
-- after the save's copy was taken (`since` > `snapshotAt`) are left for the next save.
function PvPTransfer.afterSave(store: any, userId: number, json: string, out: any, inc: any, snapshotAt: number, onStep: ((string, any) -> ())?)
	local function step(name: string, info: any)
		if onStep then
			onStep(name, info)
		end
	end
	local sent, received = {}, {}
	for uid, entry in out do
		if not entry.busy and (entry.since or 0) <= snapshotAt and not json:find(uid, 1, true) then
			entry.busy = true
			sent[uid] = entry
		end
	end
	for id, entry in inc do
		if not entry.busy and (entry.since or 0) <= snapshotAt and json:find(entry.uid, 1, true) then
			entry.busy = true
			received[id] = entry
		end
	end
	for uid, entry in sent do
		local info = { id = entry.id, uid = uid }
		step("owner saved", info)
		if PvPTransfer.clearSent(store, userId, uid, entry.id) then
			if out[uid] == entry then
				out[uid] = nil
			end
			step("owner done", info)
			if PvPTransfer.tidy(store, entry.to, entry.id) then
				step("finished", info)
			end
		else
			entry.busy = false
		end
	end
	for id, entry in received do
		local info = { id = id, uid = entry.uid }
		step("thief saved", info)
		if PvPTransfer.markApplied(store, userId, id) then
			if inc[id] == entry then
				inc[id] = nil
			end
			step("applied", info)
			if PvPTransfer.tidy(store, userId, id) then
				step("finished", info)
			end
		else
			entry.busy = false
		end
	end
end

-- Whether a player's journal has nothing in flight (for tests and diagnostics). nil = unknown.
function PvPTransfer.isClear(store: any, userId: number): boolean?
	local journal = PvPTransfer.read(store, userId)
	if not journal then
		return nil
	end
	return next(journal.sent) == nil and next(journal.received) == nil
end

return PvPTransfer
