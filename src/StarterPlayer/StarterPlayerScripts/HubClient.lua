-- Studio location: StarterPlayer.StarterPlayerScripts.HubClient (LocalScript)
-- HubClient  (Milestone 026)
-- Screens for the hub gameplay: talking to the City Guide and the shopkeepers (speech bubble with
-- choice buttons, never typed chat), the three shops, the Quest Board, picking a worker on an
-- arena queue pad, the tutorial tracker, arena hit pops and bat trail colours. Requests only: the
-- server decides every purchase, reward and battle. Nothing shows while the hub flags are off.
-- The ScreenGui's attributes (Open, Speaker, Tutorial, States) mirror what is showing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local HubConfig = require(ReplicatedStorage:WaitForChild("HubConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

local player = Players.LocalPlayer
local actionEvent = ReplicatedStorage:WaitForChild("HubAction", 60) :: RemoteEvent?
if not actionEvent then
	return
end
local stateEvent = ReplicatedStorage:WaitForChild("HubState") :: RemoteEvent
local clientEvent = ReplicatedStorage:WaitForChild("HubEvent") :: RemoteEvent
local C = UIStyle.Colors
local state: any = { hub = nil, quests = nil }
local function flag(name: string): boolean
	return ReplicatedStorage:GetAttribute(name) == true
end
local function send(...)
	actionEvent:FireServer(...)
end

local gui = UIKit.screen("Hub", UIStyle.DisplayOrder.Inventory + 2)
local root = UIKit.root(gui)

-- One list panel in the middle of the screen (shops, quests, worker pickers) ---------------------------
local panel = UIKit.panel({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root })
panel.Visible = false
UIKit.padding(panel, UIStyle.Space.L, UIStyle.Space.M)
UIKit.list(panel, Enum.FillDirection.Vertical, UIStyle.Space.S, Enum.HorizontalAlignment.Center)
UIKit.scaled(panel, 0.58, 1.1, root)
local header = UIKit.make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UIStyle.TouchTarget), LayoutOrder = 1, Parent = panel })
local titleLabel = UIKit.text({ Text = "", Role = "Title", Size = UDim2.new(1, -52, 1, 0), Parent = header })
local body = UIKit.make("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel }) :: Frame
UIKit.list(body, Enum.FillDirection.Vertical, 6)
local footer = UIKit.text({ Text = "", Role = "Small", Color = C.TextDim, AlignX = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = panel })
local rebuild: (() -> ())? = nil -- redraws the open panel when the server sends new state

local function closePanel()
	panel.Visible = false
	rebuild = nil
	gui:SetAttribute("Open", nil)
end
UIKit.button({ Name = "Close", Kind = "Ghost", Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(UIStyle.TouchTarget, UIStyle.TouchTarget), Parent = header, OnActivated = closePanel })
local function openPanel(key: string, title: string, note: string, draw: () -> ())
	titleLabel.Text = title
	footer.Text = note
	rebuild = function()
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		draw()
	end
	rebuild()
	panel.Visible = true
	gui:SetAttribute("Open", key)
end
-- one line: name, small note, and a button on the right
local order = 0
local function row(name: string, note: string, buttonText: string?, enabled: boolean, onClick: (() -> ())?)
	order += 1
	local frame = UIKit.make("Frame", { Name = "Row", BackgroundColor3 = C.PanelRaised, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = order, Parent = body }) :: Frame
	UIStyle.corner(frame, UIStyle.Radius.M)
	UIKit.text({ Text = name, Role = "Heading", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 22), Parent = frame })
	UIKit.text({ Text = note, Role = "Small", Color = C.TextMuted, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -170, 0, 20), Parent = frame })
	if buttonText then
		local _, control = UIKit.button({ Name = "Action", Kind = if enabled then "Primary" else "Secondary", Text = buttonText, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(144, 44), Parent = frame, OnActivated = onClick })
		if not enabled then
			control.setEnabled(false, buttonText)
		end
	end
end

-- Speech bubble with choices --------------------------------------------------------------------------
local bubble = UIKit.panel({ Name = "Dialogue", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(440, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root })
bubble.Visible = false
UIKit.padding(bubble, UIStyle.Space.L, UIStyle.Space.M)
UIKit.list(bubble, Enum.FillDirection.Vertical, UIStyle.Space.S, Enum.HorizontalAlignment.Center)
UIKit.scaled(bubble, 0.6, 1.1, root)
local speakerLabel = UIKit.text({ Name = "Speaker", Text = "", Role = "Heading", Color = C.Gold, LayoutOrder = 1, Parent = bubble })
local lineLabel = UIKit.text({ Name = "Line", Text = "", Role = "Body", Wrap = true, Truncate = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = bubble })
local choicesFrame = UIKit.make("Frame", { Name = "Choices", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = bubble }) :: Frame
UIKit.list(choicesFrame, Enum.FillDirection.Vertical, 6)
local function closeBubble()
	bubble.Visible = false
	gui:SetAttribute("Speaker", nil)
end
local function say(speaker: string, line: string, choices: { { any } })
	speakerLabel.Text, lineLabel.Text = speaker, line
	for _, child in choicesFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, choice in choices do
		UIKit.button({ Name = "Choice" .. index, Kind = if index == 1 then "Primary" else "Secondary", Text = choice[1], Size = UDim2.new(1, 0, 0, UIStyle.TouchTarget), LayoutOrder = index, Parent = choicesFrame, OnActivated = function()
			closeBubble()
			if choice[2] then
				choice[2]()
			end
		end })
	end
	bubble.Visible = true
	gui:SetAttribute("Speaker", speaker)
	gui:SetAttribute("Line", line)
end

-- Shops ---------------------------------------------------------------------------------------------
local function money(amount: number): string
	return CashFormat.format(amount)
end
local function workerName(entry: any): string
	local worker = WorkerCatalogue.get(entry.id)
	return if worker then worker.name else entry.id
end
local function pickSpot(item: any)
	openPanel("Spots", "PLACE: " .. string.upper(item.name), "Decor spots are on your own lot.", function()
		local decor = state.hub and state.hub.decor or {}
		for index = 1, #HubConfig.DECOR_SPOTS do
			local there = decor[tostring(index)]
			local label = if index <= 2 then "front" elseif index <= 4 then "back" else "back, middle"
			row(("Spot %d (%s)"):format(index, label), if there == item.id then "This one is here now" elseif there then "Something else is here (it will be put away)" else "Empty", if there == item.id then "REMOVE" else "PLACE HERE", true, function()
				send("ShopUse", if there == item.id then "" else item.id, index)
			end)
		end
	end)
end
local function pickWorkerToTrain(item: any)
	openPanel("Training", "ARENA TRAINING", "Training only changes battle stats.", function()
		local training = state.hub and state.hub.upgrades and state.hub.upgrades.training or {}
		for _, entry in WorkerState.snapshot.workers do
			local level = tonumber(training[entry.uid]) or 0
			local price = item.levels[level + 1]
			row(workerName(entry), ("Training level %d of %d"):format(level, #item.levels), if price then money(price) else "MAX", price ~= nil, function()
				send("ShopBuy", item.id, entry.uid)
			end)
		end
	end)
end
local function openShop(id: string)
	local shop = HubConfig.Shops[id]
	if not (shop and flag("HubShops") and (shop.flag == nil or flag("HubUpgrades"))) then
		return
	end
	openPanel(id, shop.title, "Prices are in game cash. " .. (if id == "UpgradeOffice" then "" else "Looks only."), function()
		local hub = state.hub or {}
		local owned, upgrades = hub.owned or {}, hub.upgrades or {}
		for _, item in shop.items do
			if item.kind == "upgrade" and item.perWorker then
				row(item.name, item.note, "CHOOSE", true, function()
					pickWorkerToTrain(item)
				end)
			elseif item.kind == "upgrade" then
				local level = tonumber(upgrades[item.key]) or 0
				local price = item.levels[level + 1]
				row(item.name, ("%s  ·  level %d of %d"):format(item.note, level, #item.levels), if price then money(price) else "MAX", price ~= nil, function()
					send("ShopBuy", item.id)
				end)
			elseif not owned[item.id] then
				row(item.name, item.note, money(item.price), true, function()
					send("ShopBuy", item.id)
				end)
			elseif item.kind == "decor" then
				row(item.name, "Owned", "PLACE", true, function()
					pickSpot(item)
				end)
			else
				local inUse = if item.kind == "skin" then hub.skin == item.value else hub.trail == item.id
				row(item.name, "Owned", if inUse then "IN USE" else "USE", not inUse, function()
					send("ShopUse", item.id)
				end)
			end
		end
		if id == "BatBoutique" then
			row("Starter Bat", "The classic wooden bat, no trail colour", "USE", true, function()
				send("ShopUse", "skin:Starter")
				send("ShopUse", "")
			end)
		end
	end)
end

-- Quest Board ---------------------------------------------------------------------------------------
local function openQuests()
	if not flag("HubNpcQuests") then
		return
	end
	openPanel("Quests", "QUEST BOARD", "Three new quests every day.", function()
		for _, quest in state.quests or {} do
			local done = quest.progress >= quest.goal
			row(quest.text, ("%s / %s   ·   reward %s"):format(if quest.goal > 99 then money(quest.progress) else tostring(quest.progress), if quest.goal > 99 then money(quest.goal) else tostring(quest.goal), money(quest.reward)), if quest.claimed then "COLLECTED" elseif done then "CLAIM" else "IN PROGRESS", done and not quest.claimed, function()
				send("QuestClaim", quest.id)
			end)
		end
		if #(state.quests or {}) == 0 then
			row("No quests yet", "Come back in a moment.", nil, false, nil)
		end
	end)
end

-- Tutorial ------------------------------------------------------------------------------------------
local tracker = UIKit.panel({ Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root })
tracker.Visible = false
UIKit.padding(tracker, UIStyle.Space.M, UIStyle.Space.S)
UIKit.list(tracker, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
UIKit.scaled(tracker, 0.6, 1.05, root)
local stepTitle = UIKit.text({ Text = "", Role = "Heading", Color = C.Gold, LayoutOrder = 1, Parent = tracker })
local stepText = UIKit.text({ Text = "", Role = "Body", Wrap = true, Truncate = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = tracker })
local stepButtons = UIKit.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UIStyle.TouchTarget), LayoutOrder = 3, Parent = tracker })
local tutorialStep = 0
local stepStart = { stations = 0, cash = 0 }
local showStep: (number) -> ()
local function endTutorial()
	tutorialStep = 0
	tracker.Visible = false
	gui:SetAttribute("Tutorial", nil)
	send("TutorialDone")
end
local _, nextControl = UIKit.button({ Name = "Next", Kind = "Primary", Text = "NEXT", Size = UDim2.new(0.5, -4, 1, 0), Parent = stepButtons, OnActivated = function()
	if tutorialStep >= #HubConfig.Tutorial then
		endTutorial()
	else
		showStep(tutorialStep + 1)
	end
end })
UIKit.button({ Name = "Skip", Kind = "Secondary", Text = "SKIP TUTORIAL", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Parent = stepButtons, OnActivated = endTutorial })
local function onStations(): number
	local count = 0
	for _, entry in WorkerState.snapshot.workers do
		if entry.loc == "station" then
			count += 1
		end
	end
	return count
end
showStep = function(index: number)
	local step = HubConfig.Tutorial[index]
	tutorialStep = index
	stepStart.stations, stepStart.cash = onStations(), player:GetAttribute("Cash") or 0
	stepTitle.Text = ("TUTORIAL %d/%d  ·  %s"):format(index, #HubConfig.Tutorial, string.upper(step.title))
	stepText.Text = step.text
	nextControl.setText(if index >= #HubConfig.Tutorial then "FINISH" elseif step.wait then "NEXT (or just do it)" else "NEXT")
	tracker.Visible = true
	gui:SetAttribute("Tutorial", index)
end
local function startTutorial()
	showStep(1)
end
local function tutorialTick()
	local step = HubConfig.Tutorial[tutorialStep]
	if not (step and step.wait) then
		return
	end
	local done = (step.wait == "carry" and player:GetAttribute("CarryingNPC") == true)
		or (step.wait == "place" and onStations() > stepStart.stations)
		or (step.wait == "cash" and (player:GetAttribute("Cash") or 0) > stepStart.cash)
	if done then
		UIKit.sound("chime")
		showStep(tutorialStep + 1)
	end
end

-- Talking ---------------------------------------------------------------------------------------------
local function pick(lines: { string }): string
	return lines[math.random(1, #lines)]
end
local function tellStory(index: number)
	local last = index >= #HubConfig.Story
	say(HubConfig.NPCs.Guide.name, HubConfig.Story[index], { { if last then "Wow!" else "Go on...", if last then nil else function()
		tellStory(index + 1)
	end } })
end
local function talk(id: string)
	local npc = HubConfig.NPCs[id]
	if not npc then
		return
	end
	closePanel()
	if id == "QuestBoard" then
		openQuests()
	elseif id == "Guide" then
		say(npc.name, pick(npc.hello), {
			{ if state.hub and state.hub.tutorial then "Show me the tutorial again" else "Show me the ropes!", startTutorial },
			{ "Tell me about this city", function()
				tellStory(1)
			end },
			{ "Any tips?", function()
				say(npc.name, pick(HubConfig.Tips), { { "Thanks!" } })
			end },
			{ "Bye!" },
		})
	else
		say(npc.name, pick(npc.hello), { { "Show me the shop", function()
			openShop(id)
		end }, { "Bye!" } })
	end
end
local function hook(model: Instance)
	local prompt = model:FindFirstChild("TalkPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("Hooked") then
		prompt:SetAttribute("Hooked", true)
		prompt.Triggered:Connect(function()
			talk(model:GetAttribute("NpcId"))
		end)
	end
end
for _, model in CollectionService:GetTagged("HubNPC") do
	hook(model)
end
CollectionService:GetInstanceAddedSignal("HubNPC"):Connect(function(model)
	task.defer(hook, model)
end)

-- Arena: worker picker while standing on a queue pad ------------------------------------------------------
local queuedWorker: string? = nil
local pickerFor: Instance? = nil
local function padUnderfoot(): Instance?
	local venues = workspace:FindFirstChild("Venues")
	local pads = venues and venues:FindFirstChild("Arena") and venues.Arena:FindFirstChild("QueuePads")
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, pad in (pads and rootPart and pads:GetChildren() or {}) do
		if pad:IsA("BasePart") and ((pad.Position - rootPart.Position) * Vector3.new(1, 0, 1)).Magnitude <= HubConfig.Arena.PAD_REACH then
			return pad
		end
	end
	return nil
end
local function openPicker()
	openPanel("Arena", "PICK A WORKER TO BATTLE", "Nobody loses a worker. The winner earns cash and a trophy point.", function()
		if queuedWorker then
			row(queuedWorker .. " is in the queue", "Waiting for a worker of similar power...", "LEAVE QUEUE", true, function()
				send("ArenaLeave")
			end)
			return
		end
		local training = state.hub and state.hub.upgrades and state.hub.upgrades.training or {}
		local listed = 0
		for _, entry in WorkerState.snapshot.workers do
			local worker = WorkerCatalogue.get(entry.id)
			if worker and (entry.loc == "station" or entry.loc == "inventory") and listed < 8 then
				listed += 1
				local scale = 1 + (if flag("HubUpgrades") then tonumber(training[entry.uid]) or 0 else 0) * HubConfig.Arena.TRAINING_BONUS
				local power = math.floor(worker.attack * scale + 0.5) + math.floor(worker.speed * scale + 0.5) + math.floor(worker.defence * scale + 0.5)
				row(worker.name, ("Power %d   ·   attack %d  speed %d  defence %d"):format(power, worker.attack, worker.speed, worker.defence), "BATTLE", true, function()
					send("ArenaJoin", entry.uid)
				end)
			end
		end
		if listed == 0 then
			row("No workers yet", "Steal a worker on Main Street first.", nil, false, nil)
		end
	end)
end
local function fighterOf(userId: number): BasePart?
	local other = Players:GetPlayerByUserId(userId)
	local venues = workspace:FindFirstChild("Venues")
	local fighters = venues and venues:FindFirstChild("Arena") and venues.Arena:FindFirstChild("Fighters")
	local model = other and fighters and fighters:FindFirstChild("Fighter_" .. other.Name)
	return model and model:FindFirstChildWhichIsA("BasePart", true)
end

clientEvent.OnClientEvent:Connect(function(kind, info)
	info = if type(info) == "table" then info else {}
	if kind == "ArenaQueue" then
		queuedWorker = if info.queued then tostring(info.worker) else nil
		if gui:GetAttribute("Open") == "Arena" and rebuild then
			rebuild()
		end
	elseif kind == "ArenaStart" then
		if info.a == player.UserId or info.b == player.UserId then
			closePanel()
			UIKit.toast("info", "Takeover Tower", ("%s vs %s: fight!"):format(tostring(info.workerA), tostring(info.workerB)))
		end
	elseif kind == "ArenaHit" then
		UIKit.worldPop(fighterOf(info.victim), "-" .. tostring(info.damage), C.Danger, 5)
	elseif kind == "ArenaEnd" then
		UIKit.worldPop(fighterOf(info.winner), "WINNER!", C.Gold, 6)
		if info.winner == player.UserId then
			UIKit.sound("epic")
		end
	elseif kind == "TestOpen" and RunService:IsStudio() then -- test hook: opens a screen as a tap would
		if info.what == "shop" then
			openShop(info.id)
		elseif info.what == "quests" then
			openQuests()
		elseif info.what == "tutorial" then
			startTutorial()
		elseif info.what == "next" then
			showStep(math.min(#HubConfig.Tutorial, tutorialStep + 1))
		elseif info.what == "finish" then
			endTutorial()
		else
			talk(info.id)
		end
	end
end)

local offered = false
local states = 0
stateEvent.OnClientEvent:Connect(function(new)
	state = if type(new) == "table" then new else state
	states += 1
	gui:SetAttribute("States", states)
	if rebuild then
		rebuild()
	end
	if not offered and flag("HubNpcQuests") and state.hub and state.hub.tutorial ~= true then
		offered = true -- once per visit: a new player is offered the tutorial
		say(HubConfig.NPCs.Guide.name, "New in town? I can show you the ropes. It only takes a minute!", { { "Yes please!", startTutorial }, { "No thanks", function()
			send("TutorialDone")
		end } })
	end
end)

UIKit.mount(gui)
send("Refresh")
while true do
	task.wait(0.3)
	tutorialTick()
	-- arena picker follows the pads
	local pad = if flag("HubArena") then padUnderfoot() else nil
	if pad and pickerFor ~= pad and not panel.Visible then
		pickerFor = pad
		openPicker()
	elseif not pad then
		if pickerFor and gui:GetAttribute("Open") == "Arena" then
			closePanel()
		end
		pickerFor = nil
	end
	-- the 022 weapon locker only shows the bat looks this player owns while the shops are open
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local lockerGui = playerGui and playerGui:FindFirstChild("PvPLocker")
	local skins = lockerGui and lockerGui:FindFirstChild("Skins", true)
	if skins then
		local owned = state.hub and state.hub.owned or {}
		for _, card in skins:GetChildren() do
			if card:IsA("GuiButton") then
				card.Visible = not flag("HubShops") or card.Name == "Starter" or owned["skin:" .. card.Name] == true
			end
		end
	end
	-- bat trail colours bought at the Bat Boutique
	for _, other in Players:GetPlayers() do
		local colour = other:GetAttribute("BatTrail")
		local bat = other.Character and other.Character:FindFirstChild("PvPBat")
		local trail = bat and bat:FindFirstChild("SwingTrail", true)
		if trail and trail:IsA("Trail") and type(colour) == "string" then
			local r, g, b = string.match(colour, "(%d+),(%d+),(%d+)")
			if r then
				trail.Color = ColorSequence.new(Color3.fromRGB(tonumber(r) :: number, tonumber(g) :: number, tonumber(b) :: number))
			end
		end
	end
end
