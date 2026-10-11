-- Studio location: ServerScriptService.PvPSteal (ModuleScript)
-- PvPSteal  (Milestone 022)
-- Stealing a placed worker from another player's base, all decided on the server.
--
-- A theft:  hold the Steal prompt on a worker in someone else's base -> the worker rides the thief's
-- shoulder (the normal NPCCarry, with its speed penalty) -> it is delivered when the thief sets foot
-- in their own base. Until then NOTHING changes in anyone's saved data: the victim still owns the
-- worker and its station is kept for it. If the thief is hit, dies, resets, teleports or leaves, if
-- the owner leaves, or if the hand-over fails, the worker is simply rebuilt on its owner's station.
--
-- Delivery (the transfer) is decided by one write to a durable journal (see PvPTransfer): before
-- that write the worker is its previous owner's, after it the thief's, and both players' saves
-- simply follow. If the server stops at any point, the journal is replayed when each player's data
-- next loads, so the worker always ends up with exactly one owner: never lost, never copied.
-- No save schema change: the journal is a separate key beside each player's save.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PvPConfig = require(ReplicatedStorage:WaitForChild("PvPConfig"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local NPCCarry = require(script.Parent:WaitForChild("NPCCarry"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local PvPBase = require(script.Parent:WaitForChild("PvPBase"))
local PvPTransfer = require(script.Parent:WaitForChild("PvPTransfer"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))

local PvPSteal = {}

local CFG = PvPConfig.Steal
local TITLE = "Steal"
local PROMPT_NAME = "PvPStealPrompt"

-- Thefts in progress: one per worker and one per thief.
local theftByUid: { [string]: any } = {}
local theftByThief: { [Player]: any } = {}
-- Journal entries of committed transfers that are waiting for a player's next save, per player
-- on this server (see PvPTransfer.afterSave): pendingOut[owner][uid], pendingIn[thief][transferId].
local pendingOut: { [Player]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any
local pendingIn: { [Player]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any
-- Whether a player's journal has been replayed since their data loaded (true), or is being (false).
local replayed: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local leaving: { [Player]: any } = {} -- the data of players whose final save is waiting for a hand-over
local saveOrder = "owner" -- which of the two saves is written first after a hand-over
local stepHook: ((string, any) -> ())? = nil -- tests watch the steps of a hand-over through this
local holds: { [Player]: { prompt: ProximityPrompt, at: number } } = setmetatable({}, { __mode = "k" }) :: any
local saver: (Player) -> boolean = PlayerData.save
local teleportCheck = true
local claimedFolder = workspace:WaitForChild("ClaimedNPCs")
local changed = Instance.new("BindableEvent")
PvPSteal.Changed = changed.Event -- (what, info) for tests and later systems

local function livingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

local function step(name: string, info: any)
	if stepHook then
		stepHook(name, info)
	end
end

-- Whether a worker's last hand-over is still being written down (it can't be stolen meanwhile).
local function isSettling(uid: string): boolean
	for _, list in pendingOut do
		if list[uid] then
			return true
		end
	end
	for _, list in pendingIn do
		for _, entry in list do
			if entry.uid == uid then
				return true
			end
		end
	end
	return false
end

local function nameOf(record: any): string
	local worker = WorkerCatalogue.get(record.id)
	return if worker then worker.name else record.id
end

local function say(player: Player, success: boolean, message: string)
	if player.Parent then
		PvPBase.notify(player, success, message, TITLE)
	end
end

-- Keeps the victim's station for the stolen worker, so nothing else can be placed there meanwhile.
local function reserve(theft, on: boolean)
	local station = PvPBase.findStation(theft.plot, theft.station)
	if not station then
		return
	end
	if on then
		station:SetAttribute("StolenUid", theft.uid)
		station:SetAttribute("Occupied", true)
	elseif station:GetAttribute("StolenUid") == theft.uid then
		station:SetAttribute("StolenUid", nil)
		if theft.plot:GetAttribute("OwnerUserId") == theft.ownerId then
			station:SetAttribute("Occupied", false)
		end
	end
end

-- The robbery alarm that everyone can see on the victim's plot.
local function setAlarm(theft, on: boolean)
	local plot = theft.plot
	if on then
		plot:SetAttribute("AlarmThief", theft.thief.DisplayName)
		plot:SetAttribute("AlarmWorker", theft.workerName)
		return
	end
	for _, other in theftByUid do
		if other.plot == plot then
			plot:SetAttribute("AlarmThief", other.thief.DisplayName)
			plot:SetAttribute("AlarmWorker", other.workerName)
			return
		end
	end
	plot:SetAttribute("AlarmThief", nil)
	plot:SetAttribute("AlarmWorker", nil)
end

-- Takes a theft off the books. Returns false if it had already ended (every ending is idempotent).
local function finish(theft): boolean
	if theftByUid[theft.uid] ~= theft then
		return false
	end
	theftByUid[theft.uid] = nil
	if theftByThief[theft.thief] == theft then
		theftByThief[theft.thief] = nil
	end
	if theft.connection then
		theft.connection:Disconnect()
	end
	if theft.thief.Parent then
		theft.thief:SetAttribute("CarryingStolen", nil)
		theft.thief:SetAttribute("StolenWorker", nil)
	end
	reserve(theft, false)
	setAlarm(theft, false)
	return true
end

-- Ends a theft without a hand-over: the worker goes back on its owner's station.
-- reason: "tagged" | "dropped" | "teleported" | "safe zone" | "timeout" | "owner left" | "failed" | "disabled"
local function abort(theft, reason: string, by: Player?)
	if theft.delivering then
		-- The hand-over is being written to the journal: it decides, not this (see deliver).
		theft.pendingAbort = theft.pendingAbort or { reason = reason, by = by }
		return
	end
	if not finish(theft) then
		return
	end
	local thief, owner, npc, worker = theft.thief, theft.owner, theft.npc, theft.workerName
	if NPCCarry.getCarried(thief) == npc then
		NPCCarry.cancel(thief) -- removes the model; the thief has no record of it, so nothing is stashed
	elseif npc.Parent then
		npc:Destroy()
	end
	-- The owner's record never moved, so the worker is simply rebuilt where it stood.
	local restored = false
	if owner.Parent and PlotService.getPlot(owner) == theft.plot then
		restored = WorkerInventory.respawn(owner, theft.uid) ~= nil
	end

	if reason == "tagged" then
		say(thief, false, ("You were hit and dropped %s! It went back to %s."):format(worker, owner.DisplayName))
		say(owner, true, if by == owner then ("You got %s back!"):format(worker) else ("%s knocked %s loose. It's back on your station."):format(by and by.DisplayName or "Someone", worker))
	elseif reason == "owner left" then
		say(thief, false, ("%s left the game, so the steal was cancelled."):format(owner.DisplayName))
	else
		local text = if reason == "teleported" then "No shortcuts with a stolen worker! %s went back to %s."
			elseif reason == "safe zone" then "No hiding in the safe zone with a stolen worker! %s went back to %s."
			elseif reason == "timeout" then "Too slow! %s went back to %s."
			elseif reason == "dropped" then "You dropped %s. It went back to %s."
			else "The steal didn't go through. %s went back to %s."
		say(thief, false, text:format(worker, owner.DisplayName))
		say(owner, true, ("%s is back on its station."):format(worker))
	end
	local info = { uid = theft.uid, worker = worker, outcome = reason, restored = restored, thief = thief.DisplayName, owner = owner.DisplayName, by = by and by.DisplayName, thiefId = thief.UserId, ownerId = theft.ownerId, byId = by and by.UserId }
	PvPBase.event(owner, "TheftEnded", info)
	PvPBase.event(thief, "StealEnded", info)
	if by and by ~= owner and by ~= thief then
		PvPBase.event(by, "TheftEnded", info)
	end
	changed:Fire("aborted", info)
end

-- Hand-over ------------------------------------------------------------------------------------------
-- The journal says the worker is the thief's now: make it so in memory, then save both players.
-- No yields. Works whether each player is still here, is in their final save, or has gone (then
-- the journal entry does it when their data next loads).
local function finalize(theft, id: string, record: any, info: any)
	local thief, owner, uid, npc = theft.thief, theft.owner, theft.uid, theft.npc
	theft.delivering = false
	finish(theft)
	local since = os.clock()

	if PlayerData.isLoaded(owner) then
		WorkerInventory.take(owner, uid)
	elseif leaving[owner] then
		for index, w in leaving[owner].workers do
			if w.uid == uid then
				table.remove(leaving[owner].workers, index)
				break
			end
		end
	end
	pendingOut[owner] = pendingOut[owner] or {}
	pendingOut[owner][uid] = { id = id, to = thief.UserId, since = since }

	record.loc, record.station = "carried", nil
	if PlayerData.isLoaded(thief) then
		local holding = NPCCarry.getCarried(thief) == npc
		if not holding and theft.placedStation and npc.Parent then
			record.loc, record.station = "station", theft.placedStation -- already put on one of their stations
		end
		WorkerInventory.give(thief, record, true)
		if npc.Parent then
			npc:SetAttribute("ClaimedBy", thief.UserId)
			npc:SetAttribute("StolenFrom", nil)
		end
		if record.loc == "carried" and not holding then
			-- They lost hold of it while the hand-over was being written (hit, died): it is theirs anyway.
			if npc.Parent then
				npc:Destroy()
			end
			WorkerInventory.putAway(thief, uid)
		end
	else
		if leaving[thief] then
			record.loc = "inventory"
			table.insert(leaving[thief].workers, record)
		end
		if npc.Parent then
			npc:Destroy()
		end
	end
	pendingIn[thief] = pendingIn[thief] or {}
	pendingIn[thief][id] = { uid = uid, from = theft.ownerId, since = since }
	step("swapped", info)

	local worker = theft.workerName
	say(thief, true, ("You stole %s from %s!"):format(worker, owner.DisplayName))
	say(owner, false, ("%s got away with %s."):format(thief.DisplayName, worker))
	local ended = { uid = uid, worker = worker, outcome = "delivered", thief = thief.DisplayName, owner = owner.DisplayName, thiefId = thief.UserId, ownerId = theft.ownerId }
	PvPBase.event(thief, "StealEnded", ended)
	PvPBase.event(owner, "TheftEnded", ended)
	changed:Fire("delivered", ended)

	-- Both saves follow; the journal entries are cleared as each one lands (see onSaved in start).
	task.spawn(function()
		local order = if saveOrder == "thief" then { thief, owner } else { owner, thief }
		for _, player in order do
			if player.Parent and PlayerData.isLoaded(player) then
				saver(player)
			end
		end
	end)
end

-- Hands a stolen worker over to the thief, who is standing in their own base with it. Yields while
-- the journal is written; until that is settled the theft can't be ended any other way.
local function deliver(theft): boolean
	if theftByUid[theft.uid] ~= theft or theft.delivering then
		return false
	end
	local thief, owner, uid = theft.thief, theft.owner, theft.uid
	local held = if owner.Parent then WorkerInventory.getRecord(owner, uid) else nil
	if not (held and PlayerData.isLoaded(thief) and PlayerData.isLoaded(owner)) then
		abort(theft, "failed")
		return false
	end
	theft.delivering = true
	local store = PlayerData.store()
	local id = HttpService:GenerateGUID(false)
	local record = { uid = held.uid, id = held.id, zone = held.zone, level = held.level, tier = held.tier }
	local info = { id = id, uid = uid, ownerId = theft.ownerId, thiefId = thief.UserId }
	step("started", info)

	local outcome = "not written"
	if PvPTransfer.prepare(store, theft.ownerId, thief.UserId, uid, id) then
		step("prepared", info)
		if not theft.pendingAbort then -- (the thief lost it while that was being written: no hand-over)
			outcome = PvPTransfer.commit(store, thief.UserId, id, { uid = uid, from = theft.ownerId, record = record, at = os.time() })
		end
	end
	-- A commit request that failed may still have been written. Ask until it is known; a "no" is
	-- final (it is voided in the same step), so the two answers can never both come true.
	while outcome == "unknown" do
		outcome = PvPTransfer.decide(store, thief.UserId, id) or "unknown"
		if outcome == "unknown" then
			if not (thief.Parent or owner.Parent) then
				break -- both have gone: the journal settles it when their data next loads
			end
			task.wait(CFG.CONFIRM_RETRY)
		end
	end
	if outcome == "committed" then
		step("committed", info)
		finalize(theft, id, record, info)
		return true
	end

	if outcome ~= "unknown" then
		task.spawn(PvPTransfer.clearSent, store, theft.ownerId, uid, id)
	end
	theft.delivering = false
	local pending = theft.pendingAbort
	abort(theft, if pending then pending.reason else "failed", if pending then pending.by else nil)
	return false
end

-- Replays a player's journal once their data has loaded here: drops a worker that was handed over
-- before a crash, adds one that was received. Keeps trying while the store can't be reached.
local function replay(player: Player)
	if replayed[player] ~= nil then
		return
	end
	replayed[player] = false
	while player.Parent and PlayerData.isLoaded(player) and not WorkerInventory.isReady(player) do
		task.wait(0.1)
	end
	while player.Parent and PlayerData.isLoaded(player) and PvPBase.stealing() do
		local ok, result = PvPTransfer.replay(PlayerData.store(), player.UserId, {
			has = function(uid: string): boolean
				return WorkerInventory.getRecord(player, uid) ~= nil
			end,
			drop = function(uid: string)
				local record = WorkerInventory.take(player, uid)
				if record then
					say(player, false, ("%s was stolen from you just before the server restarted."):format(nameOf(record)))
				end
			end,
			add = function(record: any)
				record.loc = "inventory"
				if WorkerInventory.give(player, record, true) then
					say(player, true, ("%s is yours: your steal went through just before the server restarted."):format(nameOf(record)))
				end
			end,
		})
		if ok then
			local out, inc = pendingOut[player] or {}, pendingIn[player] or {}
			pendingOut[player], pendingIn[player] = out, inc
			local waiting = false
			for uid, entry in result.out do
				out[uid] = out[uid] or { id = entry.id, to = entry.to, since = 0 }
				waiting = true
			end
			for id, entry in result.inc do
				inc[id] = inc[id] or { uid = entry.uid, from = entry.from, since = 0 }
				waiting = true
			end
			replayed[player] = true
			if waiting then
				task.spawn(PlayerData.save, player) -- lets the journal entries be cleared
			end
			return
		end
		task.wait(5)
	end
	if replayed[player] == false then
		replayed[player] = nil
	end
end

-- Starting a theft ------------------------------------------------------------------------------------
-- Validates and starts a theft with no yields, so two thieves can never both get one worker.
-- Returns (started, message for the player).
function PvPSteal.tryBegin(thief: Player, npc: Model): (boolean, string?)
	if not PvPBase.stealing() then
		return false, nil
	end
	local plot = PvPBase.plotOfWorker(npc)
	local owner = plot and PvPBase.ownerOf(plot)
	local uid = npc:GetAttribute("WorkerUid")
	if not (plot and owner and type(uid) == "string") then
		return false, "That worker can't be stolen."
	end
	if owner == thief then
		return false, nil
	end
	local thiefRoot = livingRoot(thief)
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	if not thiefRoot then
		return false, "You can't steal right now."
	end
	if not (npcRoot and npcRoot:IsA("BasePart")) or (thiefRoot.Position - npcRoot.Position).Magnitude > CFG.DISTANCE + CFG.DISTANCE_TOLERANCE then
		return false, "Get closer to steal it."
	end
	if theftByThief[thief] or NPCCarry.getCarried(thief) or NPCClaim.getReservation(thief) then
		return false, "You already have a worker in hand. Place or store it first."
	end
	if theftByUid[uid] then
		return false, "Someone else is already stealing this one!"
	end
	local record = WorkerInventory.getRecord(owner, uid) :: any
	if not (record and record.loc == "station") or isSettling(uid) or replayed[owner] ~= true or replayed[thief] ~= true then
		return false, "That worker can't be stolen right now."
	end
	if PvPBase.isProtected(owner.UserId) then
		return false, ("%s is new here and protected for now."):format(owner.DisplayName)
	end
	if PvPBase.isLocked(owner.UserId) then
		return false, ("%s's base is locked."):format(owner.DisplayName)
	end
	local room, why = WorkerInventory.canClaim(thief)
	if not room then
		return false, why
	end

	if PvPConfig.Protection.ENDS_ON_STEAL then
		PvPBase.endProtection(thief, "You started a steal, so your new-player protection is over.")
	end
	PvPBase.endSpawnSafe(thief)
	local theft = { uid = uid, npc = npc, owner = owner, ownerId = owner.UserId, thief = thief, plot = plot, station = record.station, workerName = nameOf(record), startedAt = os.clock() }
	theftByUid[uid], theftByThief[thief] = theft, theft
	local prompt = npcRoot:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end
	npc:SetAttribute("ClaimedBy", thief.UserId)
	npc:SetAttribute("ClaimPhase", "Spinning") -- the thief's client shows its usual "STOLEN!" pop for this
	npc:SetAttribute("StolenFrom", owner.UserId)
	npc.Parent = claimedFolder -- off the station: its income stops
	reserve(theft, true)
	theft.connection = npc.AncestryChanged:Connect(function()
		if not npc:IsDescendantOf(workspace) then
			abort(theft, "dropped") -- the carry was cancelled (death, reset, leaving)
		end
	end)
	NPCCarry.start(thief, npc)
	if NPCCarry.getCarried(thief) ~= npc then
		abort(theft, "failed")
		return false, "The steal didn't go through."
	end
	local _, humanoid = livingRoot(thief)
	theft.maxSpeed = if humanoid then humanoid.WalkSpeed else nil
	theft.maxJumpHeight = if humanoid then humanoid.JumpHeight else nil
	theft.maxJumpPower = if humanoid then humanoid.JumpPower else nil
	theft.lastPosition = thiefRoot.Position
	theft.safeTime = 0
	thief:SetAttribute("CarryingStolen", true)
	thief:SetAttribute("StolenWorker", theft.workerName)
	setAlarm(theft, true)

	say(thief, true, ("You grabbed %s! Carry it into your own base to keep it."):format(theft.workerName))
	say(owner, false, ("%s is stealing %s! Hit them with your bat to get it back."):format(thief.DisplayName, theft.workerName))
	local info = { uid = uid, worker = theft.workerName, thief = thief.DisplayName, owner = owner.DisplayName, station = theft.station, thiefId = thief.UserId, ownerId = theft.ownerId }
	PvPBase.event(owner, "TheftStarted", info)
	PvPBase.event(thief, "StealStarted", info)
	changed:Fire("started", info)
	return true, nil
end

-- A hit on a player (from PvPCombat). Knocks loose the stolen worker they carry, if any.
function PvPSteal.onPlayerHit(victim: Player, attacker: Player): boolean
	local theft = theftByThief[victim]
	if theft and not theft.delivering and (attacker == theft.owner or CFG.THIRD_PARTY_CAN_TAG) then
		abort(theft, "tagged", attacker)
		return true
	end
	return false
end

function PvPSteal.isStealing(player: Player): boolean
	return theftByThief[player] ~= nil
end

-- Watching thieves: delivery, shortcuts, and the station reservation ------------------------------------
local lastCheck = os.clock()
local function check()
	local t = os.clock()
	local dt = math.min(t - lastCheck, 0.25)
	lastCheck = t
	local list = {}
	for _, theft in theftByThief do
		table.insert(list, theft)
	end
	for _, theft in list do
		local thief = theft.thief
		local root, humanoid = livingRoot(thief)
		if not (root and humanoid) or theftByUid[theft.uid] ~= theft or theft.delivering then
			continue -- death and leaving end the carry, which ends the theft
		end
		local station = PvPBase.findStation(theft.plot, theft.station)
		if station and station:GetAttribute("Occupied") ~= true then
			station:SetAttribute("Occupied", true)
		end
		-- No speed or jump boosts, no seats or vehicles, and no teleports while carrying someone
		-- else's worker.
		if theft.maxSpeed and humanoid.WalkSpeed > theft.maxSpeed + 0.01 then
			humanoid.WalkSpeed = theft.maxSpeed
		end
		if CFG.BLOCK_JUMP_BOOSTS then
			if theft.maxJumpHeight and humanoid.JumpHeight > theft.maxJumpHeight + 0.01 then
				humanoid.JumpHeight = theft.maxJumpHeight
			end
			if theft.maxJumpPower and humanoid.JumpPower > theft.maxJumpPower + 0.01 then
				humanoid.JumpPower = theft.maxJumpPower
			end
		end
		if CFG.BLOCK_SEATS and humanoid.SeatPart then
			humanoid.Sit = false
		end
		local moved = (root.Position - theft.lastPosition).Magnitude
		theft.lastPosition = root.Position
		if teleportCheck and moved > CFG.TELEPORT_STUDS then
			abort(theft, "teleported")
			continue
		end
		-- Nobody can be hit in a safe zone, so a thief may cross one but not wait in it.
		if PvPBase.isSafe(root.Position) then
			theft.safeTime += dt
			if theft.safeTime > CFG.SAFE_ZONE_LIMIT then
				abort(theft, "safe zone")
				continue
			end
		end
		if CFG.MAX_CARRY > 0 and t - theft.startedAt > CFG.MAX_CARRY then
			abort(theft, "timeout")
			continue
		end
		local home = PlotService.getPlot(thief)
		if home and PvPBase.isInside(home, root.Position) then
			task.spawn(deliver, theft) -- yields while the journal is written
		end
	end
end

-- Steal prompts on placed workers -----------------------------------------------------------------------
local function addPrompt(npc: Instance)
	if not (PvPBase.stealing() and npc:IsA("Model") and PvPBase.plotOfWorker(npc)) then
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or root:FindFirstChild(PROMPT_NAME) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Steal"
	prompt.ObjectText = npc.Name
	prompt.HoldDuration = CFG.HOLD -- the prompt's own ring is the progress indicator
	prompt.MaxActivationDistance = CFG.DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.Parent = root
	-- The hold is timed here too: a Triggered that arrives without a full hold is ignored.
	prompt.PromptButtonHoldBegan:Connect(function(player)
		holds[player] = { prompt = prompt, at = os.clock() }
	end)
	prompt.Triggered:Connect(function(player)
		local hold = holds[player]
		holds[player] = nil
		if not (hold and hold.prompt == prompt and os.clock() - hold.at >= CFG.HOLD - CFG.HOLD_TOLERANCE) then
			return
		end
		local ok, message = PvPSteal.tryBegin(player, npc :: Model)
		if not ok and message then
			say(player, false, message)
		end
	end)
end

local function refreshPrompts()
	local on = PvPBase.stealing()
	for _, plot in PvPBase.plots():GetChildren() do
		local placed = plot:FindFirstChild("PlacedNPCs")
		for _, npc in (placed and placed:GetChildren() or {}) do
			if on then
				addPrompt(npc)
			else
				local root = npc:FindFirstChild("HumanoidRootPart")
				local prompt = root and root:FindFirstChild(PROMPT_NAME)
				if prompt then
					prompt:Destroy()
				end
			end
		end
	end
end

-- Test seams (Studio test scripts only).
PvPSteal._test = {
	thefts = theftByUid,
	-- journal[uid] is true while that worker's last hand-over still has journal entries waiting here
	journal = setmetatable({}, {
		__index = function(_, uid)
			return if isSettling(uid) then true else nil
		end,
	}),
	holds = holds,
	check = check,
	setSaver = function(fn: ((Player) -> boolean)?)
		saver = fn or PlayerData.save
	end,
	setSaveOrder = function(first: string?)
		saveOrder = first or "owner"
	end,
	setStepHook = function(fn: ((string, any) -> ())?)
		stepHook = fn
	end,
	setTeleportCheck = function(on: boolean)
		teleportCheck = on
	end,
	deliver = function(thief: Player): boolean
		local theft = theftByThief[thief]
		return theft ~= nil and deliver(theft)
	end,
	replayNow = function(player: Player) -- what the next time their data loads would do
		replayed[player] = nil
		replay(player)
	end,
}

local started = false
function PvPSteal.start()
	if started then
		return
	end
	started = true

	for _, plot in PvPBase.plots():GetChildren() do
		local placed = plot:FindFirstChild("PlacedNPCs")
		if placed then
			placed.ChildAdded:Connect(function(npc)
				task.defer(addPrompt, npc)
			end)
		end
	end
	refreshPrompts()
	PvPBase.FlagsChanged:Connect(function()
		refreshPrompts()
		if not PvPBase.stealing() then
			local list = {}
			for _, theft in theftByUid do
				table.insert(list, theft)
			end
			for _, theft in list do
				abort(theft, "disabled")
			end
		end
	end)

	-- The owner can't store or move a worker while it is on a thief's shoulder.
	WorkerInventory.setBusyCheck(function(_player, record)
		return if theftByUid[record.uid] then "That worker is being stolen! Hit the thief to get it back." else nil
	end)
	-- A thief who reaches one of their own stations before the hand-over is done: it is recorded on
	-- that station when the hand-over completes (and taken off it again if it does not).
	WorkerInventory.setBeforePlaced(function(player, npc, station)
		local theft = theftByUid[npc:GetAttribute("WorkerUid")]
		if theft and theft.thief == player then
			theft.placedStation = station:GetAttribute("StationIndex")
			deliver(theft)
		end
	end)

	-- Each save that lands lets the journal entries it has made unnecessary be cleared.
	PlayerData.onSaved(function(player, ok, snapshotAt, json)
		local out, inc = pendingOut[player], pendingIn[player]
		if ok and ((out and next(out)) or (inc and next(inc))) then
			PvPTransfer.afterSave(PlayerData.store(), player.UserId, json, out or {}, inc or {}, snapshotAt, step)
		end
	end)
	-- A player who leaves while a hand-over they are part of is being written: their final save
	-- waits a moment for it, and the hand-over is applied to the data that save is about to write.
	-- If it takes longer, the journal entry puts their data right the next time it loads.
	PlayerData.beforeFinalSave(function(player, data)
		leaving[player] = data
		local deadline = os.clock() + CFG.FINAL_SAVE_WAIT
		while os.clock() < deadline do
			local waiting = false
			for _, theft in theftByUid do
				if theft.delivering and (theft.owner == player or theft.thief == player) then
					waiting = true
				end
			end
			if not waiting then
				break
			end
			task.wait(0.1)
		end
		leaving[player] = nil
	end)
	-- Journal replay, once per load (and for everyone already here when stealing is switched on).
	PlayerData.onLoaded(function(player)
		replay(player)
	end)
	PvPBase.FlagsChanged:Connect(function()
		if PvPBase.stealing() then
			for _, player in Players:GetPlayers() do
				if PlayerData.isLoaded(player) then
					task.spawn(replay, player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local list = {}
		for _, theft in theftByUid do
			if theft.owner == player or theft.thief == player then
				table.insert(list, theft)
			end
		end
		for _, theft in list do
			if theft.owner == player then
				PvPBase.penalise(player.UserId) -- leaving doesn't dodge the robbery for free
				abort(theft, "owner left")
			else
				abort(theft, "dropped")
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CFG.CHECK_INTERVAL then
			elapsed = 0
			if next(theftByThief) ~= nil then
				check()
			end
		end
	end)
end

return PvPSteal
