-- Studio location: StarterPlayer.StarterPlayerScripts.IndexClient (LocalScript)
-- IndexClient  (Milestone 029) -- the Index (ReplicatedStorage.UiV1On; replaces the 028 book button in
-- the V1 look), built through UITheme. One page per zone (tabs): collected workers in colour, missing
-- ones as black silhouettes with their rarity shown, a progress bar, and (IndexBonusOn) the completion
-- bonus tiers from RewardsConfig (D15) with a Claim button once a tier is reached.
-- Collected = the server's list (book + owned, RewardsState) plus everything owned now (WorkerState).
-- Display and requests only: RewardsService checks every claim. 3D previews exist only while the
-- window is open (released on close and on every page change).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig"))
local RewardsConfig = require(ReplicatedStorage:WaitForChild("RewardsConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerPreview = require(ReplicatedStorage:WaitForChild("WorkerPreview"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

local T = UITheme.Colors
local stateEvent = ReplicatedStorage:WaitForChild("RewardsState") :: RemoteEvent
local actionEvent = ReplicatedStorage:WaitForChild("RewardsAction") :: RemoteEvent
local clientEvent = ReplicatedStorage:WaitForChild("RewardsEvent") :: RemoteEvent

local gui, root = UITheme.gui("Index029", 5)
local win = UITheme.window({ Name = "Index", Title = "Index", Icon = "book", Theme = "Index", Size = Vector2.new(800, 340), Parent = root })

-- Pages: the book's zones that have workers in the catalogue, in the book's order.
local pages = {}
for _, def in ParadeConfig.BOOK_PAGES do
	local roster = WorkerCatalogue.ZONES[def.zone]
	if roster and #roster > 0 then
		table.insert(pages, { key = def.zone, title = def.title })
	end
end

local grid =
	UITheme.make("Frame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, -236, 1, -74), ZIndex = 13, Parent = win.content })
UITheme.make("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0.5, -8), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
local side = UITheme.make("Frame", {
	Name = "Side",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 74),
	Size = UDim2.new(0, 226, 1, -74),
	ZIndex = 13,
	Parent = win.content,
})
local progressText = UITheme.text({ Name = "Progress", Text = "", Role = "Title", TextSize = 20, Align = "Left", Size = UDim2.new(1, 0, 0, 24), ZIndex = 14, Parent = side })
local progressBar, setProgress = UITheme.bar({ Name = "Bar", Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(2, 26), ZIndex = 14, Parent = side })
progressBar.ZIndex = 14
local bonusText = UITheme.text({
	Name = "Bonus",
	Text = "",
	Role = "Small",
	Font = UITheme.Fonts.Display,
	TextSize = 16,
	Color = T.Accent,
	Align = "Left",
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.fromOffset(0, 44),
	ZIndex = 14,
	Parent = side,
})

local tierCards = {}
local claimPage: string? = nil
for i, tier in RewardsConfig.INDEX_TIERS do
	local card = UITheme.card({ Name = "Tier" .. i, Size = UDim2.new(1, 0, 0, 72), Position = UDim2.fromOffset(0, 64 + (i - 1) * 76), ZIndex = 13, Parent = side })
	local label = UITheme.text({
		Name = "Label",
		Text = ("%d%%: +%d%% cash%s"):format(math.floor(tier.share * 100 + 0.5), math.floor(tier.bonus * 100 + 0.5), if tier.badge then " + badge" else ""),
		Role = "Small",
		Font = UITheme.Fonts.Display,
		TextSize = 15,
		Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.fromOffset(4, 1),
		ZIndex = 14,
		Parent = card,
	})
	local button = UITheme.button({
		Name = "Claim",
		Kind = "Gold",
		Text = "Claim",
		TextSize = 18,
		Size = UDim2.new(1, -10, 0, 52),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		ZIndex = 14,
		Parent = card,
		OnActivated = function()
			if claimPage then
				actionEvent:FireServer("ClaimIndex", claimPage)
			end
		end,
	})
	tierCards[i] = { card = card, label = label, button = button }
end

local state: any = nil
local handles: { any } = {}
local page = pages[1] and pages[1].key

local function collected(): { [string]: boolean }
	local set = {}
	if state and state.index and state.index.collected then
		for id, v in state.index.collected do
			set[id] = v == true
		end
	end
	for _, entry in WorkerState.snapshot.workers do
		if type(entry.id) == "string" then
			set[entry.id] = true
		end
	end
	return set
end

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

local rank = {}
for i, r in WorkerCatalogue.RARITIES do
	rank[r] = i
end

local function paint()
	if not (win.isOpen() and page) then
		return
	end
	releasePreviews()
	local have = collected()
	local ids = table.clone(WorkerCatalogue.ZONES[page] or {})
	table.sort(ids, function(a, b)
		local ra, rb = rank[WorkerCatalogue.get(a).rarity], rank[WorkerCatalogue.get(b).rarity]
		return if ra == rb then a < b else ra < rb
	end)
	local n = 0
	for order, id in ids do
		local worker = WorkerCatalogue.get(id)
		local got = have[id] == true
		n += if got then 1 else 0
		local card = UITheme.card({ Name = id, LayoutOrder = order, Rarity = if got then worker.rarity else nil, Color = T.PanelDark, ZIndex = 13, Parent = grid })
		card:SetAttribute("Collected", got)
		local stage =
			UITheme.make("Frame", { Name = "Stage", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -42), ZIndex = 14, Parent = card })
		local handle = WorkerPreview.mount(stage, id, { rotate = false })
		if not got then
			handle.tint(T.Silhouette)
		end
		table.insert(handles, handle)
		UITheme.text({
			Name = "WorkerName",
			Text = if got then worker.name else "???",
			Role = "Small",
			TextSize = 14,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -18),
			Size = UDim2.new(1, -8, 0, 18),
			ZIndex = 15,
			Parent = card,
		})
		UITheme.text({
			Name = "Rarity",
			Text = (UITheme.RarityGlyph[worker.rarity] or "") .. " " .. worker.rarity,
			Role = "Small",
			TextSize = 13,
			Color = UITheme.Rarity[worker.rarity] or T.Text,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -2),
			Size = UDim2.new(1, -8, 0, 16),
			ZIndex = 15,
			Parent = card,
		})
	end
	progressText.Text = ("%d / %d collected"):format(n, #ids)
	setProgress(if #ids > 0 then n / #ids else 0, true)
	local zone = state and state.index and state.index.zones and state.index.zones[page]
	local bonusOn = state and state.indexBonus == true
	bonusText.Visible = bonusOn
	if bonusOn then
		local total = state.index.bonus or 0
		bonusText.Text = if total > 0 then ("Your index bonus: +%d%% cash"):format(math.floor(total * 100 + 0.5)) else "Fill pages to earn more cash!"
	end
	claimPage = page
	for i, c in tierCards do
		c.card.Visible = bonusOn
		local tier = RewardsConfig.INDEX_TIERS[i]
		local claimed = zone and zone.claimed or 0
		local reached = if #ids > 0 then n / #ids >= tier.share - 1e-9 else false
		if claimed >= i then
			UITheme.setEnabled(c.button, false, "Claimed!")
		elseif reached and (zone and zone.reached or 0) >= i then
			UITheme.setEnabled(c.button, true, "Claim!")
		else
			UITheme.setEnabled(c.button, false, ("%d more"):format(math.max(1, math.ceil(tier.share * #ids - 1e-9) - n)))
		end
	end
	gui:SetAttribute("Page", page)
	gui:SetAttribute("Collected", n)
end

local tabs, selectTab = UITheme.tabs({
	Name = "Tabs",
	Tabs = pages,
	Size = UDim2.new(1, -60, 0, 58),
	Position = UDim2.fromOffset(0, 10),
	Parent = win.content,
	OnSelect = function(key)
		page = key
		paint()
	end,
})
tabs.ZIndex = 13

UITheme.registerScreen("Index", function(zone: any?)
	if ReplicatedStorage:GetAttribute("UiV1On") ~= true then
		UITheme.screenClosed("Index")
		return
	end
	actionEvent:FireServer("State")
	win.open()
	selectTab(if type(zone) == "string" and WorkerCatalogue.ZONES[zone] then zone else page or pages[1].key)
end, function()
	win.close()
	releasePreviews()
end)
stateEvent.OnClientEvent:Connect(function(s)
	state = s
	paint()
end)
WorkerState.Changed:Connect(paint)
clientEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Claimed" and info.kind == "index" and tierCards[info.tier] then
		local s = tierCards[info.tier].card:FindFirstChildOfClass("UIScale") or UITheme.make("UIScale", { Parent = tierCards[info.tier].card })
		s.Scale = 1.15
		UITheme.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		UITheme.coinBurst(tierCards[info.tier].button, 14)
	end
end)

-- Studio test hook (DevTest_V1029): open a page as a tap would.
if game:GetService("RunService"):IsStudio() then
	gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
		local zone = gui:GetAttribute("TestOpen")
		if type(zone) == "string" and zone ~= "" then
			UITheme.openScreen("Index", zone)
		else
			UITheme.closeScreens()
		end
	end)
end
