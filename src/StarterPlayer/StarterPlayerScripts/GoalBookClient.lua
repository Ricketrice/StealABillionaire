-- Studio location: StarterPlayer.StarterPlayerScripts.GoalBookClient (LocalScript)
-- GoalBookClient  (Milestone 028)
-- Two screens, both built only through UITheme (029 restyles them there):
--   * One-goal HUD (ReplicatedStorage.GoalHudOn): always ONE next goal at the top of the screen,
--     big icon + text + progress bar. Goals come from ParadeConfig.GOALS in order; the first one not
--     done is shown, with a pop when it completes. Hidden while the 026 tutorial card is up.
--   * Collection book (ReplicatedStorage.BookOn): a book button; one page per zone; caught workers
--     in colour, missing ones as black silhouettes with their rarity shown.
-- Display only. Caught = the server's book (ParadeEvent "State", saved in the hub field) plus every
-- worker this player owns now (WorkerState), so nothing caught before the book existed is missing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerPreview = require(ReplicatedStorage:WaitForChild("WorkerPreview"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local player = Players.LocalPlayer
local clientEvent = ReplicatedStorage:WaitForChild("ParadeEvent") :: RemoteEvent
local actionEvent = ReplicatedStorage:WaitForChild("ParadeAction") :: RemoteEvent
local T = UITheme.Colors

local serverBook: { [string]: boolean } = {}

local function goalOn(): boolean
	return ReplicatedStorage:GetAttribute("GoalHudOn") == true
end
local function bookOn(): boolean
	return ReplicatedStorage:GetAttribute("BookOn") == true
end

-- What this player has caught: the saved book plus everything owned now.
local function caughtSet(): { [string]: boolean }
	local set = table.clone(serverBook)
	for _, entry in WorkerState.snapshot.workers do
		if type(entry.id) == "string" then
			set[entry.id] = true
		end
	end
	return set
end
local function count(set: { [string]: boolean }): number
	local n = 0
	for id in set do
		if WorkerCatalogue.get(id) then
			n += 1
		end
	end
	return n
end
local TOTAL = 0
for _ in WorkerCatalogue.WORKERS do
	TOTAL += 1
end

local gui = Instance.new("ScreenGui")
gui.Name = "GoalBook"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

-- Goal bar ------------------------------------------------------------------------------------------------------
local goal = UITheme.panel({ Name = "Goal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(360, 58), Parent = gui })
goal.Visible = false
UITheme.scaleWith(goal, 0.75, 1.1)
local goalIcon = UITheme.icon({ Name = "Icon", Text = "🎁", Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(8, 8), Parent = goal })
local popScale = Instance.new("UIScale") -- the completion pop (the panel's own UIScale is for screen size)
popScale.Parent = goalIcon
local goalText =
	UITheme.text({ Name = "Text", Text = "", Role = "Body", TextSize = 17, Align = "Left", Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -66, 0, 22), Parent = goal })
local barFrame, setBar = UITheme.bar({ Name = "Bar", Position = UDim2.fromOffset(58, 32), Size = UDim2.new(1, -124, 0, 16), Parent = goal })
local goalCount = UITheme.text({
	Name = "Count",
	Text = "",
	Role = "Small",
	Align = "Right",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 30),
	Size = UDim2.fromOffset(56, 20),
	Parent = goal,
})

type GoalView = { index: number, text: string, icon: string, have: number, need: number, label: string }

local function unlocked(zoneId: string): boolean
	for id in string.gmatch(player:GetAttribute("UnlockedZones") or "", "[^,]+") do
		if id == zoneId then
			return true
		end
	end
	return zoneId == ZoneConfig.FREE_ZONE
end

local function currentGoal(): GoalView?
	local caught = caughtSet()
	local stored, equipped, carried = WorkerState.counts()
	local owned = stored + equipped + carried
	local cash = player:GetAttribute("Cash") or 0
	for index, g in ParadeConfig.GOALS do
		local have, need, label
		if g.kind == "catch" then
			have, need = math.max(owned, count(caught)), g.goal or 1
		elseif g.kind == "pads" then
			have, need = equipped, g.goal or 1
		elseif g.kind == "zone" then
			local zone = ZoneConfig.get(g.zone)
			if not zone or unlocked(g.zone) then
				continue
			end
			have, need = math.min(cash, zone.price), zone.price
			label = CashFormat.format(have) .. " / " .. CashFormat.format(need)
		elseif g.kind == "book" then
			have, need = count(caught), g.goal or TOTAL
		else
			continue
		end
		if have < need then
			return { index = index, text = g.text, icon = g.icon or "⭐", have = have, need = need, label = label or ("%d/%d"):format(have, need) }
		end
	end
	return nil
end

local shownIndex: number? = nil
local function tutorialUp(): boolean
	local hub = player.PlayerGui:FindFirstChild("Hub")
	return hub ~= nil and hub:GetAttribute("Tutorial") ~= nil
end
local function refreshGoal()
	if not goalOn() then
		goal.Visible = false
		return
	end
	local view = currentGoal()
	goal.Visible = view ~= nil and not tutorialUp()
	gui:SetAttribute("Goal", view and view.text)
	if not view then
		return
	end
	if shownIndex and view.index ~= shownIndex then
		-- The last goal is done: a pop before the next one shows.
		FxKit.sound("chime")
		popScale.Scale = 1.6
		FxKit.burst(player.Character and player.Character:FindFirstChild("HumanoidRootPart") or Vector3.zero, "sparkle", T.Accent, 16)
		UITheme.tween(popScale, UITheme.Motion.Slow, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	shownIndex = view.index
	goalIcon.Text = view.icon
	goalText.Text = view.text
	goalCount.Text = view.label
	local wide = #view.label > 7
	goalCount.Size = UDim2.fromOffset(if wide then 120 else 56, 20)
	barFrame.Size = UDim2.new(1, if wide then -188 else -124, 0, 16)
	setBar(view.have / math.max(1, view.need), true)
end

-- Book ------------------------------------------------------------------------------------------------------------
-- (A holder takes the screen-size scale: the button's own UIScale is its press squash.)
local bookHolder = UITheme.make("Frame", {
	Name = "BookHolder",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 108),
	Size = UDim2.fromOffset(112, UITheme.TouchTarget),
	Parent = gui,
})
UITheme.scaleWith(bookHolder, 0.7, 1.05)
local bookButton = UITheme.button({ Name = "BookButton", Kind = "Secondary", Text = "📖 Book", TextSize = 16, Size = UDim2.fromScale(1, 1), Parent = bookHolder })
bookButton.Visible = false

local book = UITheme.panel({ Name = "Book", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(600, 450), Parent = gui })
book.Visible = false
UITheme.scaleWith(book, 0.55, 1.05)
UITheme.text({ Name = "Title", Text = "📖 COLLECTION BOOK", Role = "Title", Align = "Left", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -90, 0, 30), Parent = book })
local totalLabel = UITheme.text({
	Name = "Total",
	Text = "",
	Role = "Small",
	Color = T.TextMuted,
	Align = "Left",
	Position = UDim2.fromOffset(16, 40),
	Size = UDim2.new(1, -90, 0, 18),
	Parent = book,
})
local closeButton = UITheme.button({
	Name = "Close",
	Kind = "Ghost",
	Text = "✕",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(UITheme.TouchTarget, UITheme.TouchTarget),
	Parent = book,
})

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(12, 64)
tabs.Size = UDim2.new(1, -24, 0, UITheme.TouchTarget)
tabs.Parent = book
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local pageTitle =
	UITheme.text({ Name = "PageTitle", Text = "", Role = "Body", Align = "Left", Position = UDim2.fromOffset(16, 114), Size = UDim2.new(1, -32, 0, 22), Parent = book })
local grid = Instance.new("Frame")
grid.Name = "Grid"
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(12, 140)
grid.Size = UDim2.new(1, -24, 1, -152)
grid.Parent = book
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.25, -6, 0.5, -6)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
local soon = UITheme.text({ Name = "Soon", Text = "Coming soon!", Role = "Title", Color = T.TextMuted, Size = UDim2.fromScale(1, 1), Parent = grid })
soon.Visible = false

local handles: { any } = {}
local tabButtons: { TextButton } = {}
local page = 1

local function releasePreviews()
	for _, h in handles do
		h.release()
	end
	table.clear(handles)
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function zoneWorkers(zoneId: string): { string }
	local roster = WorkerCatalogue.ZONES[zoneId]
	if not roster then
		return {}
	end
	local list = table.clone(roster)
	local rank = {}
	for i, r in WorkerCatalogue.RARITIES do
		rank[r] = i
	end
	table.sort(list, function(a, b)
		local ra, rb = rank[WorkerCatalogue.get(a).rarity], rank[WorkerCatalogue.get(b).rarity]
		return if ra == rb then a < b else ra < rb
	end)
	return list
end

local function showPage(index: number)
	page = index
	releasePreviews()
	local def = ParadeConfig.BOOK_PAGES[index]
	local caught = caughtSet()
	local ids = zoneWorkers(def.zone)
	local have = 0
	for _, id in ids do
		if caught[id] then
			have += 1
		end
	end
	pageTitle.Text = if #ids > 0 then ("%s  ·  %d/%d caught"):format(def.title, have, #ids) else def.title
	totalLabel.Text = ("%d of %d workers caught"):format(count(caught), TOTAL)
	soon.Visible = #ids == 0
	for i, button in tabButtons do
		local style = if i == index then UITheme.Button.Primary else UITheme.Button.Ghost
		button.BackgroundColor3 = style.fill
		button.TextColor3 = style.text
	end
	for order, id in ids do
		local worker = WorkerCatalogue.get(id)
		local got = caught[id] == true
		local rarity = worker.rarity
		local color = UITheme.Rarity[rarity] or T.Text
		local card = UITheme.panel({ Name = id, LayoutOrder = order, Color = T.PanelDark, Stroke = if got then color else nil, Parent = grid })
		card:SetAttribute("Caught", got)
		local stage = Instance.new("Frame")
		stage.Name = "Stage"
		stage.BackgroundTransparency = 1
		stage.Position = UDim2.fromOffset(4, 4)
		stage.Size = UDim2.new(1, -8, 1, -46)
		stage.Parent = card
		local handle = WorkerPreview.mount(stage, id, { rotate = false })
		if not got then
			handle.tint(T.Silhouette)
		end
		table.insert(handles, handle)
		UITheme.text({
			Name = "WorkerName",
			Text = if got then worker.name else "???",
			Role = "Small",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -20),
			Size = UDim2.new(1, -8, 0, 18),
			Parent = card,
		})
		UITheme.text({
			Name = "Rarity",
			Text = (UITheme.RarityGlyph[rarity] or "") .. " " .. rarity,
			Role = "Small",
			TextSize = 12,
			Color = color,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -3),
			Size = UDim2.new(1, -8, 0, 16),
			Parent = card,
		})
	end
	gui:SetAttribute("BookPage", def.zone)
	gui:SetAttribute("BookCaught", have)
end

for i, def in ParadeConfig.BOOK_PAGES do
	local button = UITheme.button({
		Name = def.zone,
		Kind = "Ghost",
		Text = def.title,
		TextSize = 12,
		TextWrapped = true,
		LayoutOrder = i,
		Size = UDim2.new(1 / #ParadeConfig.BOOK_PAGES, -4, 1, 0),
		Parent = tabs,
	})
	button.Activated:Connect(function()
		FxKit.sound("pop")
		showPage(i)
	end)
	tabButtons[i] = button
end

local function openBook()
	book.Visible = true
	book.Position = UDim2.fromScale(0.5, 0.6)
	UITheme.tween(book, UITheme.Motion.Normal, { Position = UDim2.fromScale(0.5, 0.52) }, Enum.EasingStyle.Back)
	FxKit.sound("pop")
	showPage(page)
	gui:SetAttribute("BookOpen", true)
end
local function closeBook()
	book.Visible = false
	releasePreviews()
	gui:SetAttribute("BookOpen", nil)
end
bookButton.Activated:Connect(function()
	if book.Visible then
		closeBook()
	else
		openBook()
	end
end)
closeButton.Activated:Connect(closeBook)
if game:GetService("RunService"):IsStudio() then -- test hook (DevTest_Parade028): opens the book as a tap would
	gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
		if gui:GetAttribute("TestOpen") then
			openBook()
		else
			closeBook()
		end
	end)
end

local function refreshBook()
	bookButton.Visible = bookOn()
	if not bookOn() and book.Visible then
		closeBook()
	elseif book.Visible then
		showPage(page)
	end
end

-- Wiring -------------------------------------------------------------------------------------------------------------
clientEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "State" and type(info) == "table" and type(info.book) == "table" then
		table.clear(serverBook)
		for _, id in info.book do
			if type(id) == "string" then
				serverBook[id] = true
			end
		end
		refreshGoal()
		refreshBook()
	end
end)
WorkerState.Changed:Connect(function()
	refreshGoal()
	if book.Visible then
		showPage(page)
	end
end)
player:GetAttributeChangedSignal("Cash"):Connect(refreshGoal)
player:GetAttributeChangedSignal("UnlockedZones"):Connect(refreshGoal)
for _, name in { "GoalHudOn", "BookOn" } do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
		refreshGoal()
		refreshBook()
		if goalOn() or bookOn() then
			actionEvent:FireServer("State")
		end
	end)
end
task.spawn(function() -- the tutorial card comes and goes
	local hub = player.PlayerGui:WaitForChild("Hub", 30)
	if hub then
		hub:GetAttributeChangedSignal("Tutorial"):Connect(refreshGoal)
	end
end)
refreshGoal()
refreshBook()
if goalOn() or bookOn() then
	actionEvent:FireServer("State")
end
