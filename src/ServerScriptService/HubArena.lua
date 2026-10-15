-- Studio location: ServerScriptService.HubArena (ModuleScript)
-- HubArena  (Milestone 026)
-- Battle Arena (in the plaza, Milestone 027; was Takeover Tower): worker battles, all decided on the server. A player stands on a queue pad and
-- offers one of their workers (on a station or in storage); two workers of similar power are put
-- on the arena platforms and fight by themselves. The winner's owner gets cash and a trophy point.
-- Nobody loses a worker, and the worker never leaves its owner: the fighters are stand-in models.
--   power  = attack + speed + defence (catalogue stats; training from the Upgrade Office adds to them)
--   health = HP_FACTOR x (attack + defence)      damage = max(1, attack - defence x DEFENCE_FACTOR)
--   the faster worker hits first, then they take turns
-- Uses the Milestone 025 anchors: Workspace.Venues.Arena (PlatformA, PlatformB, QueuePads, Scoreboard).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local HubBase = require(script.Parent:WaitForChild("HubBase"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))

local HubArena = {}
local CFG = HubConfig.Arena
local TITLE = "Battle Arena"

type Entry = { player: Player, uid: string, id: string, name: string, attack: number, speed: number, defence: number, power: number, at: number }
local queue: { Entry } = {}
local fight: any = nil -- the fight in progress (one at a time: there is one pair of platforms)
local cooldownUntil: { [number]: number } = {} -- UserId -> os.clock()
local paidPairs: { [string]: number } = {} -- "winner:loser" -> os.clock() of the last paid win
local won = Instance.new("BindableEvent")
HubArena.Won = won.Event -- (winner: Player, loser: Player?)
HubArena.stats = { fights = 0, paid = 0, refused = 0 }

local function venue(): Instance?
	local venues = workspace:FindFirstChild("Venues")
	return venues and venues:FindFirstChild("Arena")
end
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root else nil
end
function HubArena.onPad(player: Player): boolean
	local arena, root = venue(), rootOf(player)
	local pads = arena and arena:FindFirstChild("QueuePads")
	for _, pad in (pads and root and pads:GetChildren() or {}) do
		if pad:IsA("BasePart") and ((pad.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= CFG.PAD_REACH then
			return true
		end
	end
	return false
end

-- A worker's battle numbers, or nil if the player can't field it.
function HubArena.statsOf(player: Player, uid: any): Entry?
	local record = if type(uid) == "string" then WorkerInventory.getRecord(player, uid) :: any else nil
	local worker = record and WorkerCatalogue.get(record.id)
	if not (record and worker and (record.loc == "station" or record.loc == "inventory")) then
		return nil
	end
	local hub = HubBase.data(player)
	local level = if hub and HubBase.flag("UPGRADES_ENABLED") then tonumber(hub.upgrades.training[uid]) or 0 else 0
	local scale = 1 + level * CFG.TRAINING_BONUS
	local attack, speed, defence = math.floor(worker.attack * scale + 0.5), math.floor(worker.speed * scale + 0.5), math.floor(worker.defence * scale + 0.5)
	return { player = player, uid = uid, id = record.id, name = worker.name, attack = attack, speed = speed, defence = defence, power = attack + speed + defence, at = os.clock() }
end
function HubArena.inRange(a: number, b: number): boolean
	return math.min(a, b) >= math.max(a, b) * (1 - CFG.POWER_RANGE)
end

local function queued(player: Player): number?
	for index, entry in queue do
		if entry.player == player then
			return index
		end
	end
	return nil
end
function HubArena.isBusy(player: Player): boolean
	return queued(player) ~= nil or (fight ~= nil and (fight.a.player == player or fight.b.player == player))
end
function HubArena.leave(player: Player, quiet: boolean?)
	local index = queued(player)
	if index then
		table.remove(queue, index)
		HubBase.event(player, "ArenaQueue", { queued = false })
		if not quiet then
			HubBase.notify(player, true, "You left the battle queue.", TITLE)
		end
	end
end

-- Offers a worker for battle. Returns (queued, message).
function HubArena.join(player: Player, uid: any): (boolean, string?)
	if not HubBase.flag("ARENA_ENABLED") then
		return false, nil
	end
	if HubArena.isBusy(player) then
		return false, "You are already in the queue."
	end
	local wait = (cooldownUntil[player.UserId] or 0) - os.clock()
	if wait > 0 then
		return false, ("Your team is resting. Come back in %d seconds."):format(math.ceil(wait))
	end
	if not HubArena.onPad(player) then
		return false, "Stand on a Join Battle pad first."
	end
	local entry = HubArena.statsOf(player, uid)
	if not entry then
		return false, "Pick a creature from your stations or storage."
	end
	table.insert(queue, entry)
	HubBase.event(player, "ArenaQueue", { queued = true, worker = entry.name, power = entry.power })
	return true, ("%s (power %d) is in the queue. Waiting for a creature of similar power..."):format(entry.name, entry.power)
end

-- Stand-in model of a worker on a platform, with a name and a health bar above it.
local function fighterModel(entry: Entry, platform: BasePart, folder: Instance): (Model?, Frame?)
	local id = entry.id
	local source = nil
	for _, name in { "CreatureModels", "WorkerPreviews019R", "WorkerPreviews019", "WorkerPreviews" } do
		local previews = ReplicatedStorage:FindFirstChild(name)
		source = source or (previews and previews:FindFirstChild(id))
	end
	local previews = ReplicatedStorage:FindFirstChild("WorkerPreviews")
	source = source or (previews and previews:FindFirstChild("_Mystery"))
	if not (source and source:IsA("Model")) then
		return nil, nil
	end
	local model = source:Clone()
	model.Name = "Fighter_" .. entry.player.Name
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	HubBase.stand(model, platform.CFrame, platform.Position.Y - platform.Size.Y / 2) -- facing the other platform
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "ArenaTag"
	gui.Size = UDim2.fromOffset(170, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.55)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 232, 214)
	label.TextStrokeTransparency = 0.3
	label.Text = ("%s (%s)"):format(entry.name, entry.player.DisplayName)
	label.Parent = gui
	local track = Instance.new("Frame")
	track.Name = "Health"
	track.Position = UDim2.fromScale(0.05, 0.62)
	track.Size = UDim2.fromScale(0.9, 0.3)
	track.BackgroundColor3 = Color3.fromRGB(19, 23, 36)
	track.BorderSizePixel = 0
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(124, 202, 132)
	fill.BorderSizePixel = 0
	fill.Parent = track
	track.Parent = gui
	gui.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	gui.Parent = model
	model.Parent = folder
	return model, fill
end

local function scoreboard(text: string)
	local arena = venue()
	local face = arena and arena:FindFirstChild("Scoreboard")
	local label = face and face:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function finish(f: any, winner: Entry, loser: Entry, reason: string)
	if fight ~= f then
		return
	end
	fight = nil
	HubArena.stats.fights += 1
	local now = os.clock()
	cooldownUntil[winner.player.UserId] = now + CFG.COOLDOWN
	cooldownUntil[loser.player.UserId] = now + CFG.COOLDOWN
	local key = winner.player.UserId .. ":" .. loser.player.UserId
	local paid = now - (paidPairs[key] or -math.huge) >= CFG.PAIR_COOLDOWN
	local beaten = WorkerCatalogue.get(loser.id)
	local cash = if paid then math.max(CFG.REWARD_MIN, math.floor((beaten and beaten.income or 0) * CFG.REWARD_INCOME_SECONDS)) else 0
	local hub = HubBase.data(winner.player)
	if hub and winner.player.Parent then
		if paid then
			paidPairs[key] = now
			hub.trophies += 1
			HubBase.giveCash(winner.player, cash)
			HubArena.stats.paid += 1
		end
		HubBase.changed(winner.player)
		HubBase.notify(
			winner.player,
			true,
			if paid
				then ("%s won! +%s%d and a trophy point."):format(winner.name, CashFormat.SYMBOL, cash)
				else ("%s won! (No reward: you beat this player a moment ago.)"):format(winner.name),
			TITLE
		)
		won:Fire(winner.player, loser.player)
	end
	if loser.player.Parent then
		HubBase.notify(loser.player, false, if reason == "left" then "You left the battle." else ("%s lost this one. Your creature is safe at home."):format(loser.name), TITLE)
	end
	HubBase.broadcast("ArenaEnd", { winner = winner.player.UserId, loser = loser.player.UserId, worker = winner.name, cash = cash, reason = reason })
	scoreboard(("WINNER\n%s  (%s)"):format(winner.name, winner.player.DisplayName))
	task.delay(CFG.OUTRO_TIME, function()
		if f.folder then
			f.folder:Destroy()
		end
		if fight == nil then
			scoreboard("CREATURE BATTLES\nstep on a pad to join")
		end
	end)
end

local function run(a: Entry, b: Entry)
	local arena = venue()
	local platformA, platformB = arena and arena:FindFirstChild("PlatformA"), arena and arena:FindFirstChild("PlatformB")
	local folder = Instance.new("Folder")
	folder.Name = "Fighters"
	folder.Parent = arena or workspace
	local f = { a = a, b = b, folder = folder }
	fight = f
	local hp = { [a] = CFG.HP_FACTOR * (a.attack + a.defence), [b] = CFG.HP_FACTOR * (b.attack + b.defence) }
	local max = { [a] = hp[a], [b] = hp[b] }
	local bars = {}
	if platformA and platformB and platformA:IsA("BasePart") and platformB:IsA("BasePart") then
		local _, barA = fighterModel(a, platformA, folder)
		local _, barB = fighterModel(b, platformB, folder)
		bars[a], bars[b] = barA, barB
	end
	local function show()
		scoreboard(("%s  %d / %d\nvs\n%s  %d / %d"):format(a.name, math.max(0, hp[a]), max[a], b.name, math.max(0, hp[b]), max[b]))
		for entry, bar in bars do
			bar.Size = UDim2.fromScale(math.clamp(hp[entry] / max[entry], 0, 1), 1)
		end
	end
	show()
	for _, entry in { a, b } do
		HubBase.event(entry.player, "ArenaQueue", { queued = false })
	end
	HubBase.broadcast("ArenaStart", { a = a.player.UserId, b = b.player.UserId, workerA = a.name, workerB = b.name })
	task.wait(CFG.INTRO_TIME)
	local attacker, defender = a, b
	if b.speed > a.speed or (b.speed == a.speed and math.random() < 0.5) then
		attacker, defender = b, a
	end
	local hits = 0
	while fight == f do
		local damage = math.max(1, math.floor(attacker.attack - defender.defence * CFG.DEFENCE_FACTOR))
		hp[defender] -= damage
		hits += 1
		show()
		HubBase.broadcast("ArenaHit", { attacker = attacker.player.UserId, victim = defender.player.UserId, damage = damage })
		if hp[defender] <= 0 then
			finish(f, attacker, defender, "knockout")
			break
		elseif hits >= CFG.MAX_HITS then
			local first = if hp[a] / max[a] >= hp[b] / max[b] then a else b
			finish(f, first, if first == a then b else a, "time")
			break
		end
		attacker, defender = defender, attacker
		task.wait(CFG.HIT_INTERVAL)
	end
end

-- Pairs up queued workers of similar power, oldest first.
local function match()
	if fight or not HubBase.flag("ARENA_ENABLED") then
		return
	end
	for i = 1, #queue do
		for j = i + 1, #queue do
			if HubArena.inRange(queue[i].power, queue[j].power) then
				local a, b = queue[i], queue[j]
				table.remove(queue, j)
				table.remove(queue, i)
				task.spawn(run, a, b)
				return
			end
		end
	end
end

HubArena._test = {
	queue = queue,
	match = match,
	fight = function()
		return fight
	end,
	cooldowns = cooldownUntil,
	paidPairs = paidPairs,
}

local started = false
function HubArena.start()
	if started then
		return
	end
	started = true
	HubBase.onAction("ArenaJoin", function(player, uid)
		local ok, message = HubArena.join(player, uid)
		if message then
			HubBase.notify(player, ok, message, TITLE)
		end
		if not ok then
			HubArena.stats.refused += 1
		end
	end)
	HubBase.onAction("ArenaLeave", function(player)
		HubArena.leave(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		HubArena.leave(player, true)
		local f = fight
		if f and (f.a.player == player or f.b.player == player) then -- leaving mid-fight: the other worker wins
			local leaver = if f.a.player == player then f.a else f.b
			finish(f, if leaver == f.a then f.b else f.a, leaver, "left")
		end
	end)
	HubBase.FlagsChanged:Connect(function()
		if not HubBase.flag("ARENA_ENABLED") then
			for i = #queue, 1, -1 do
				HubArena.leave(queue[i].player, true)
			end
			scoreboard("CREATURE BATTLES\ncoming soon")
		else
			scoreboard("CREATURE BATTLES\nstep on a pad to join")
		end
	end)
	if HubBase.flag("ARENA_ENABLED") then
		scoreboard("CREATURE BATTLES\nstep on a pad to join")
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			for i = #queue, 1, -1 do -- stepping off the pad, or the worker being taken away, leaves the queue
				local entry = queue[i]
				if not entry.player.Parent or not HubArena.onPad(entry.player) or not HubArena.statsOf(entry.player, entry.uid) then
					HubArena.leave(entry.player, false)
				end
			end
			match()
		end
	end)
end

return HubArena
