-- Studio location: ServerScriptService.HubQuests (ModuleScript)
-- HubQuests  (Milestone 026)
-- The City Guide, the Quest Board and the people in the shops.
--   * NPCs: prebuilt avatars (ServerStorage.HubNPCs_026) are stood on the Milestone 025 anchors
--     while their flag is on, each with a Talk prompt. What they say is in HubConfig; the talking
--     itself is on the client (StarterPlayerScripts.HubClient). No free-text chat anywhere.
--   * Tutorial: the client walks a new player through it; the server only remembers it is done.
--   * Daily quests: three from HubConfig.Quests.POOL per player per UTC day. Progress is counted
--     here from what the server sees happen (never from what a client says) and the cash reward
--     is paid once, on request, when the goal is met.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig"))
local HubBase = require(script.Parent:WaitForChild("HubBase"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local PvPBase = require(script.Parent:WaitForChild("PvPBase"))
local PvPSteal = require(script.Parent:WaitForChild("PvPSteal"))

local HubQuests = {}
local QUESTS = HubConfig.Quests
local pool: { [string]: any } = {}
for _, quest in QUESTS.POOL do
	pool[quest.id] = quest
end

-- Days since 1970 (UTC). In Studio a ServerStorage attribute can shift it, to test the daily reset.
function HubQuests.day(): number
	local shift = if RunService:IsStudio() then tonumber(ServerStorage:GetAttribute("StudioHubDayShift")) or 0 else 0
	return os.time() // 86400 + shift
end

local function available(quest: any): boolean
	if quest.needs == "PVP" then
		return PvPBase.stealing() and PvPBase.combat()
	end
	return quest.needs == nil or HubBase.flag(quest.needs)
end

-- Today's quests for a player (rolled on first use each day). nil while their data isn't loaded.
function HubQuests.today(player: Player): any?
	local hub = HubBase.data(player)
	if not hub then
		return nil
	end
	local quests, day = hub.quests, HubQuests.day()
	if quests.day ~= day or type(quests.ids) ~= "table" then
		local choices = {}
		for _, quest in QUESTS.POOL do
			if available(quest) then
				table.insert(choices, quest.id)
			end
		end
		local random = Random.new(player.UserId % 100000 * 31 + day)
		for i = #choices, 2, -1 do
			local j = random:NextInteger(1, i)
			choices[i], choices[j] = choices[j], choices[i]
		end
		quests.day, quests.ids, quests.progress, quests.claimed = day, {}, {}, {}
		for i = 1, math.min(QUESTS.PER_DAY, #choices) do
			quests.ids[i] = choices[i]
		end
	end
	return quests
end

-- Counts `amount` towards every quest of today that listens for `event`.
function HubQuests.progress(player: Player, event: string, amount: number)
	if not (HubBase.flag("NPC_QUESTS_ENABLED") and PlayerData.isLoaded(player)) then
		return
	end
	local quests = HubQuests.today(player)
	local moved = false
	for _, id in (quests and quests.ids or {}) do
		local quest = pool[id]
		local done = tonumber(quests.progress[id]) or 0
		if quest and quest.event == event and done < quest.goal then
			quests.progress[id] = math.min(quest.goal, done + amount)
			moved = true
			if quests.progress[id] >= quest.goal then
				HubBase.notify(player, true, ("Quest done: %s. Claim $%d at the Quest Board!"):format(quest.text, quest.reward), "Quest Board")
			end
		end
	end
	if moved then
		HubBase.push(player) -- (saved with the next autosave; progress is not worth a write of its own)
	end
end

-- Pays a finished quest's reward, once. Returns (paid, message).
function HubQuests.claim(player: Player, id: any): (boolean, string?)
	if not HubBase.flag("NPC_QUESTS_ENABLED") then
		return false, nil
	end
	local quests = HubQuests.today(player)
	local quest = if type(id) == "string" then pool[id] else nil
	if not (quests and quest and table.find(quests.ids, id)) then
		return false, nil
	end
	if quests.claimed[id] then
		return false, "You already collected that reward today."
	end
	if (tonumber(quests.progress[id]) or 0) < quest.goal then
		return false, "That quest isn't finished yet."
	end
	quests.claimed[id] = true -- no yield between marking it and paying
	HubBase.giveCash(player, quest.reward)
	HubBase.changed(player)
	return true, ("Quest reward: +$%d"):format(quest.reward)
end

-- What the client shows on the Quest Board.
local function view(player: Player): any
	if not HubBase.flag("NPC_QUESTS_ENABLED") then
		return nil
	end
	local quests = HubQuests.today(player)
	local list = {}
	for _, id in (quests and quests.ids or {}) do
		local quest = pool[id]
		if quest then
			table.insert(list, { id = id, text = quest.text, goal = quest.goal, reward = quest.reward, progress = tonumber(quests.progress[id]) or 0, claimed = quests.claimed[id] == true })
		end
	end
	return list
end

-- NPCs ----------------------------------------------------------------------------------------------
local FLAG_OF = { Guide = "NPC_QUESTS_ENABLED", QuestBoard = "NPC_QUESTS_ENABLED", BatBoutique = "SHOPS_ENABLED", LotAndDecor = "SHOPS_ENABLED", UpgradeOffice = "SHOPS_ENABLED" }
local function anchorOf(id: string): BasePart?
	local venues = workspace:FindFirstChild("Venues")
	local found
	if id == "Guide" or id == "QuestBoard" then
		found = venues and venues:FindFirstChild("NPCs") and venues.NPCs:FindFirstChild(id)
	else
		local shops = venues and venues:FindFirstChild("Shops")
		found = shops and shops:FindFirstChild(id) and shops[id]:FindFirstChild("KeeperSpot")
	end
	return if found and found:IsA("BasePart") then found else nil
end
local function npcFolder(): Instance
	local venues = workspace:FindFirstChild("Venues") or workspace
	local folder = venues:FindFirstChild("People")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "People"
		folder.Parent = venues
	end
	return folder
end
local function refreshNPCs()
	local folder = if HubBase.anyFlag() then npcFolder() else (workspace:FindFirstChild("Venues") and workspace.Venues:FindFirstChild("People"))
	if not folder then
		return
	end
	local models = ServerStorage:FindFirstChild("HubNPCs_026")
	for id, flagName in FLAG_OF do
		local on = HubBase.flag(flagName) and (id ~= "UpgradeOffice" or HubBase.flag("UPGRADES_ENABLED"))
		local existing = folder:FindFirstChild(id)
		local anchor = anchorOf(id)
		if existing and not on then
			existing:Destroy()
		elseif on and not existing and anchor then
			local holder = Instance.new("Model")
			holder.Name = id
			local spot = Instance.new("Part")
			spot.Name = "TalkSpot"
			spot.Size = Vector3.new(2, 2, 2)
			spot.Transparency = 1
			spot.Anchored, spot.CanCollide, spot.CanTouch, spot.CanQuery = true, false, false, false
			spot.CFrame = anchor.CFrame * CFrame.new(0, 2.5, 0)
			spot.Parent = holder
			local template = models and models:FindFirstChild(id)
			if template and template:IsA("Model") then
				local body = template:Clone()
				body.Name = "Body"
				HubBase.stand(body, anchor.CFrame, anchor.Position.Y - anchor.Size.Y / 2)
				body.Parent = holder
			end
			local info = HubConfig.NPCs[id]
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TalkPrompt"
			prompt.ActionText = if id == "QuestBoard" then "Read" else "Talk"
			prompt.ObjectText = info.name
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = if id == "Guide" or id == "QuestBoard" then 10 else 14
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.Parent = spot
			holder:SetAttribute("NpcId", id)
			CollectionService:AddTag(holder, "HubNPC")
			holder.Parent = folder
		end
	end
end

HubQuests._test = { pool = pool, refreshNPCs = refreshNPCs }

local started = false
function HubQuests.start(arenaWon: RBXScriptSignal?)
	if started then
		return
	end
	started = true
	HubBase.addView("quests", view)
	HubBase.onAction("QuestClaim", function(player, id)
		local ok, message = HubQuests.claim(player, id)
		if message then
			HubBase.notify(player, ok, message, "Quest Board")
		end
	end)
	HubBase.onAction("TutorialDone", function(player)
		local hub = HubBase.data(player)
		if hub and HubBase.flag("NPC_QUESTS_ENABLED") and hub.tutorial ~= true then
			hub.tutorial = true
			HubBase.changed(player)
		end
	end)

	-- What counts as progress, seen on the server:
	-- steals from the street (a worker reserved for the player appears in ClaimedNPCs; PvP thefts don't count)
	local claimed = workspace:WaitForChild("ClaimedNPCs")
	claimed.ChildAdded:Connect(function(npc)
		task.defer(function()
			local player = Players:GetPlayerByUserId(npc:GetAttribute("ClaimedBy") or 0)
			if player and npc:GetAttribute("StolenFrom") == nil and npc:GetAttribute("ClaimPhase") == "Spinning" then
				HubQuests.progress(player, "steal", 1)
				local rarity = npc:GetAttribute("Rarity")
				if rarity and rarity ~= "Common" then
					HubQuests.progress(player, "stealRare", 1)
				end
			end
		end)
	end)
	local function watch(player: Player)
		-- placing: one more model on the player's stations right after they stop carrying
		local function onStations(): number
			local plot = PlotService.getPlot(player)
			local placed = plot and plot:FindFirstChild("PlacedNPCs")
			return placed and #placed:GetChildren() or 0
		end
		local before = 0
		player:GetAttributeChangedSignal("CarryingNPC"):Connect(function()
			if player:GetAttribute("CarryingNPC") == true then
				before = onStations()
			else
				task.delay(0.1, function()
					if onStations() > before then
						HubQuests.progress(player, "place", 1)
					end
				end)
			end
		end)
		-- collecting: cash going up (not counting what the hub itself pays out)
		local last = player:GetAttribute("Cash") or 0
		player:GetAttributeChangedSignal("Cash"):Connect(function()
			local now = player:GetAttribute("Cash") or 0
			local gain = now - last
			last = now
			if gain > 0 and PlayerData.isLoaded(player) then
				gain = HubBase.takeGranted(player, gain)
				if gain > 0 then
					HubQuests.progress(player, "earn", gain)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- defending: the owner's own hit knocked a stolen worker loose
	PvPSteal.Changed:Connect(function(what, info)
		if what == "aborted" and type(info) == "table" and info.outcome == "tagged" and info.byId == info.ownerId then
			local owner = Players:GetPlayerByUserId(info.ownerId or 0)
			if owner then
				HubQuests.progress(owner, "defend", 1)
			end
		end
	end)
	if arenaWon then
		arenaWon:Connect(function(winner)
			HubQuests.progress(winner, "arenaWin", 1)
		end)
	end

	refreshNPCs()
	HubBase.FlagsChanged:Connect(refreshNPCs)
end

return HubQuests
