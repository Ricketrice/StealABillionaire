-- Studio location: StarterPlayer.StarterPlayerScripts.InventoryUI (LocalScript)
-- InventoryUI
-- The worker inventory, opened from the HUD's Workers button.
--   Header     title, owned count, close button
--   Capacity   6 station pips, storage meter (20)
--   Grid       Carrying (if any) / On stations (6 slots, empty slots shown) / Storage
--   Detail     selected worker: large rotating 3D preview, rarity, income, level/tier, ATK/SPD/DEF,
--              location and the Equip/Store action
-- Layout follows the screen (via UIKit.root): wide screens show the grid with a detail pane on the
-- right; narrow screens show the grid full width and open the detail as a sheet with a Back button.
-- Cards are kept per worker uid and updated in place. 3D previews (WorkerPreview) are created only for
-- cards on screen and all released when the panel closes. Nothing renders while closed.
-- Display and requests only: the server validates every action, then sends a snapshot + toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BaseConfig = require(ReplicatedStorage:WaitForChild("BaseConfig"))
local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local InventoryConfig = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerPreview = require(ReplicatedStorage:WaitForChild("WorkerPreview"))
local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState"))

local C, S = UIStyle.Colors, UIStyle.Space
-- Milestone 029 (V1 look only): sort by rarity or income, and favourite stars (saved on the server,
-- favourites first within each section).
local V1 = UIStyle.v1 == true
local player = Players.LocalPlayer

-- Worker levels (033, BaseConfig): cards show the type icon, $/s at the worker's level and its level.
local function levelsOn(): boolean
	return BaseConfig.on("LEVELS_ENABLED")
end
local function incomeOf(entry: any): number
	local worker = WorkerCatalogue.get(entry.id)
	if not worker then
		return 0
	end
	return if (entry.level or 1) > 1 then BaseConfig.levelIncome(worker.income, entry.level) else worker.income
end
local sortMode = "rarity" -- or "income"
local favs: { [string]: boolean } = {}
local CAPACITY = InventoryConfig.INVENTORY_SLOTS + InventoryConfig.STATION_SLOTS
local CARD_H, GAP, PREVIEW_H = 212, 10, 108
local DETAIL_W = 300
local WIDE_MIN = Vector2.new(820, 430) -- root size at or above which the detail pane sits beside the grid
local PENDING_TIMEOUT = 2
local PREVIEW_MARGIN = 140 -- px beyond the visible list in which previews stay alive

local rarityRank = {}
for rank, rarity in WorkerCatalogue.RARITIES do
	rarityRank[rarity] = rank
end
local LOC = {
	station = { text = "EARNING", color = C.Cash },
	inventory = { text = "STORED", color = C.TextMuted },
	carried = { text = "CARRYING", color = C.Gold },
}

-- Build -------------------------------------------------------------------------------------------
local gui = UIKit.screen("Inventory", UIStyle.DisplayOrder.Inventory)
local root = UIKit.root(gui)
local overlay = UIKit.make(
	"TextButton",
	{ Name = "Overlay", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Overlay, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = root }
) :: TextButton
local panel = UIKit.panel({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 400), Parent = root })
panel.Visible = false
panel.ClipsDescendants = true
local panelScale = UIKit.make("UIScale", { Parent = panel }) :: UIScale

-- header
local header = UIKit.make("Frame", { Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(S.L, S.M), Size = UDim2.new(1, -S.L * 2, 0, 36), Parent = panel })
UIKit.text({ Text = "Creatures", Role = "Title", TextSize = 24, Size = UDim2.new(0, 120, 1, 0), Parent = header })
local ownedChip, ownedLabel =
	UIKit.chip({ Name = "Owned", Text = "0/" .. CAPACITY, Height = 24, Color = C.Gold, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 116, 0.5, 0), Parent = header })
local closeButton = UIKit.button({
	Name = "Close",
	Kind = "Ghost",
	Text = if V1 then "X" else "✕",
	Size = UDim2.fromOffset(UIStyle.TouchTarget, UIStyle.TouchTarget),
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 4, 0.5, 0),
	Parent = header,
})
local sortCtl = nil
local requestRender: (() -> ())? = nil -- set once render exists (below)
if V1 then
	local _, ctl = UIKit.button({
		Name = "Sort",
		Kind = "Secondary",
		Text = "Sort: Rarity",
		TextSize = 15,
		Size = UDim2.fromOffset(150, UIStyle.TouchTarget),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -UIStyle.TouchTarget - 6, 0.5, 0),
		Parent = header,
		OnActivated = function()
			sortMode = if sortMode == "rarity" then "income" else "rarity"
			sortCtl.setText(if sortMode == "rarity" then "Sort: Rarity" else "Sort: Income")
			if requestRender then
				requestRender()
			end
		end,
	})
	sortCtl = ctl
end

-- capacity
local capRow = UIKit.make("Frame", { Name = "Capacity", BackgroundTransparency = 1, Position = UDim2.fromOffset(S.L, 54), Size = UDim2.new(1, -S.L * 2, 0, 38), Parent = panel })
local stationsBox = UIKit.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -8, 1, 0), Parent = capRow })
local stationsLabel = UIKit.text({ Text = "", Role = "Small", Font = UIStyle.FontBold, Color = C.TextMuted, Size = UDim2.new(1, 0, 0, 16), Parent = stationsBox })
local pips = UIKit.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 12), Parent = stationsBox })
UIKit.list(pips, Enum.FillDirection.Horizontal, 4)
local pipFrames = {}
for i = 1, InventoryConfig.STATION_SLOTS do
	local p = UIKit.make(
		"Frame",
		{ Name = "Pip" .. i, BackgroundColor3 = C.PanelDark, BorderSizePixel = 0, Size = UDim2.new(1 / InventoryConfig.STATION_SLOTS, -4, 1, 0), LayoutOrder = i, Parent = pips }
	)
	UIStyle.corner(p, UIStyle.Radius.Pill)
	pipFrames[i] = p
end
local storageBox = UIKit.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), Parent = capRow })
local storageLabel = UIKit.text({ Text = "", Role = "Small", Font = UIStyle.FontBold, Color = C.TextMuted, Size = UDim2.new(1, 0, 0, 16), Parent = storageBox })
local _, storageMeter = UIKit.meter({ Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 20), Color = C.Gold, Parent = storageBox })

-- body: grid (scrolling) + detail
local body = UIKit.make("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(S.L, 102), Size = UDim2.new(1, -S.L * 2, 1, -102 - S.M), Parent = panel })
local scroll = UIKit.make("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.TextDim,
	Parent = body,
}) :: ScrollingFrame
UIKit.list(scroll, Enum.FillDirection.Vertical, S.M)
UIKit.make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8), Parent = scroll })

local grids = {}
local function section(key: string, title: string, order: number)
	local holder =
		UIKit.make("Frame", { Name = key, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll })
	UIKit.list(holder, Enum.FillDirection.Vertical, 6)
	local head = UIKit.text({ Text = string.upper(title), Role = "Micro", Font = UIStyle.FontBold, Color = C.Gold, LayoutOrder = 1, Parent = holder })
	local grid =
		UIKit.make("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = holder })
	local layout =
		UIKit.make("UIGridLayout", { CellSize = UDim2.fromOffset(160, CARD_H), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local empty = UIKit.text({
		Text = "",
		Role = "Small",
		Color = C.TextDim,
		Wrap = true,
		Truncate = false,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = holder,
	})
	grids[key] = { holder = holder, head = head, grid = grid, layout = layout, empty = empty }
end
section("carried", "Carrying", 1)
section("station", "On stations · earning", 2)
section("inventory", "Storage", 3)
grids.inventory.empty.Text = "Storage is empty. Steal creatures in Knight's Keep, then store them here."

-- whole-inventory empty state
local emptyAll = UIKit.make("Frame", { Name = "EmptyAll", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 0, Visible = false, Parent = scroll })
UIKit.text({
	Text = "★",
	Role = "Display",
	TextSize = 40,
	Color = C.Gold,
	AlignX = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 50),
	Position = UDim2.fromOffset(0, 10),
	Stroke = false,
	Parent = emptyAll,
})
UIKit.text({ Text = "No creatures yet", Role = "Title", TextSize = 20, AlignX = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Parent = emptyAll })
UIKit.text({
	Text = "Steal a mystery creature in Knight's Keep and bring it home to start earning.",
	Role = "Body",
	Color = C.TextMuted,
	AlignX = Enum.TextXAlignment.Center,
	Wrap = true,
	Truncate = false,
	Position = UDim2.fromOffset(0, 92),
	Size = UDim2.new(1, 0, 0, 40),
	Parent = emptyAll,
})

-- detail view (pane on wide screens, sheet on narrow)
local detail = UIKit.panel({ Name = "Detail", Color = C.PanelDark, Radius = UIStyle.Radius.L, Size = UDim2.fromOffset(DETAIL_W, 300), Parent = body })
detail.ClipsDescendants = true
local detailEmpty = UIKit.text({
	Text = "Select a creature to see its details.",
	Role = "Body",
	Color = C.TextDim,
	AlignX = Enum.TextXAlignment.Center,
	Wrap = true,
	Truncate = false,
	Size = UDim2.new(1, -24, 0, 60),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Parent = detail,
})
local detailContent = UIKit.make("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = detail })
local backButton =
	UIKit.button({ Name = "Back", Kind = "Ghost", Text = "‹  Back", Size = UDim2.fromOffset(96, UIStyle.TouchTarget), Position = UDim2.fromOffset(8, 8), Parent = detailContent })
backButton.ZIndex = 4
local dStage =
	UIKit.make("Frame", { Name = "Stage", BackgroundColor3 = C.Panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0.44, 0), ClipsDescendants = true, Parent = detailContent })
local dBackdrop = UIKit.make("UIGradient", { Rotation = 90, Parent = dStage }) :: UIGradient
local dModel = UIKit.make("Frame", { Name = "Model", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = dStage })
local dInfo = UIKit.make("ScrollingFrame", {
	Name = "Info",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 0.44, 0),
	Size = UDim2.new(1, 0, 0.56, -60),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.TextDim,
	Parent = detailContent,
}) :: ScrollingFrame
UIKit.padding(dInfo, 14, 10)
UIKit.list(dInfo, Enum.FillDirection.Vertical, 6)
local dName = UIKit.text({ Name = "WorkerName", Role = "Display", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = dInfo })
local dTags = UIKit.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2, Parent = dInfo })
UIKit.list(dTags, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
local _, dRarity = UIKit.rarityTag({ Height = 22, LayoutOrder = 1, Parent = dTags })
local _, dRole = UIKit.chip({ Height = 22, Color = C.Text, LayoutOrder = 2, Parent = dTags })
local _, dLoc = UIKit.chip({ Height = 22, LayoutOrder = 3, Parent = dTags })
local dIncome = UIKit.text({ Name = "Income", Role = "Heading", TextSize = 18, Rich = true, LayoutOrder = 3, Parent = dInfo })
local dLevel = UIKit.text({ Role = "Small", Color = C.TextMuted, LayoutOrder = 4, Parent = dInfo })
local statBars = {}
for i, s in { { "ATK", "attack", UIStyle.Stats.Attack }, { "SPD", "speed", UIStyle.Stats.Speed }, { "DEF", "defence", UIStyle.Stats.Defence } } do
	local row = UIKit.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 + i, Parent = dInfo })
	row.Visible = WorkerCatalogue.SHOW_BATTLE_STATS -- (034, D42: hidden in V1)
	local label = UIKit.text({ Role = "Micro", Font = UIStyle.FontBold, Color = s[3], Size = UDim2.new(0, 64, 1, 0), Parent = row })
	local _, meter = UIKit.meter({ Size = UDim2.new(1, -70, 0, 8), Position = UDim2.new(0, 70, 0.5, -4), Color = s[3], Parent = row })
	statBars[i] = { key = s[2], short = s[1], label = label, meter = meter }
end
local dAction, dActionCtl
dAction, dActionCtl = UIKit.button({
	Name = "Action",
	Kind = "Primary",
	Text = "Equip",
	Size = UDim2.new(1, -24, 0, 48),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Parent = detailContent,
})

-- (033) Level up, above the action button, while levels are on and shown to this player (D28)
local dLevelUp, dLevelUpCtl
dLevelUp, dLevelUpCtl = UIKit.button({
	Name = "LevelUp",
	Kind = "Primary",
	Text = "Level up",
	Size = UDim2.new(1, -24, 0, 48),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Parent = detailContent,
})
dLevelUp.Visible = false
local levelBusy = false

-- Cards -------------------------------------------------------------------------------------------
local cards: { [string]: any } = {} -- uid -> card controller
local slots: { any } = {} -- empty station placeholders by station index
local selectedUid: string? = nil
local isOpen, wide = false, true
local detailPreview = nil
local requestAction, selectWorker, queuePreviews -- forward declared (used before their definitions)

local function makeEmptySlot(index: number)
	local f = UIKit.panel({ Name = "EmptySlot" .. index, Color = C.PanelDark, Radius = UIStyle.Radius.M, BorderColor = C.Border })
	f:FindFirstChildOfClass("UIStroke").Transparency = 0.4
	UIKit.text({
		Text = "+",
		Role = "Display",
		TextSize = 34,
		Color = C.TextDim,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0.5, -46),
		Stroke = false,
		Parent = f,
	})
	UIKit.text({
		Text = "Station " .. index,
		Role = "Heading",
		TextSize = 14,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.5, -2),
		Parent = f,
	})
	UIKit.text({ Text = "Empty · equip from storage", Role = "Micro", Color = C.TextDim, AlignX = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.5, 20), Parent = f })
	return { frame = f }
end

local function newCard(uid: string)
	local ctl = { uid = uid }
	local card = UIKit.panel({ Name = uid, Color = C.PanelRaised, Radius = UIStyle.Radius.M })
	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	local selectBtn =
		UIKit.make("TextButton", { Name = "Select", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -50), Parent = card }) :: TextButton
	local stage = UIKit.make("Frame", {
		Name = "Stage",
		BackgroundColor3 = C.PanelDark,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 0, PREVIEW_H),
		Position = UDim2.fromOffset(6, 6),
		ClipsDescendants = true,
		Parent = card,
	})
	UIStyle.corner(stage, UIStyle.Radius.M)
	local backdrop = UIKit.make("UIGradient", { Rotation = 90, Parent = stage }) :: UIGradient
	local modelHolder = UIKit.make("Frame", { Name = "Model", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = stage })
	local _, tag = UIKit.rarityTag({ Height = 20, Position = UDim2.fromOffset(6, 6), Parent = stage })
	local locChip, locLabel = UIKit.chip({ Height = 20, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Parent = stage })
	local name =
		UIKit.text({ Name = "WorkerName", Role = "Heading", TextSize = 15, Position = UDim2.fromOffset(10, PREVIEW_H + 12), Size = UDim2.new(1, -20, 0, 20), Parent = card })
	-- (033) type icon + level, bottom-left of the preview, while levels are on
	local typeRow = UIKit.make("Frame", {
		Name = "TypeLevel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 6, 1, -4),
		Size = UDim2.fromOffset(84, 26),
		Visible = false,
		ZIndex = 3,
		Parent = stage,
	})
	local typeIcon: GuiObject? = nil
	local levelLabel = UIKit.text({
		Name = "Level",
		Role = "Small",
		Font = UIStyle.FontBold,
		Color = C.Gold,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.fromOffset(56, 26),
		Parent = typeRow,
	})
	levelLabel.ZIndex = 3
	local star = nil
	if V1 then
		star = UIKit.make("TextButton", {
			Name = "Favourite",
			Text = "☆",
			Font = UIStyle.Font,
			TextSize = 30,
			TextColor3 = C.TextMuted,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, 2),
			Size = UDim2.fromOffset(44, 44),
			ZIndex = 3,
			Parent = stage,
		}) :: TextButton
		UIStyle.outline(star, C.Outline, 2)
		star.Activated:Connect(function()
			local on = not favs[uid]
			if on and ReplicatedStorage:GetAttribute("FairStealOn") == true then
				-- (033 fair stealing: one favourite, which can't be stolen; the star moves to this one)
				table.clear(favs)
				for _, other in cards do
					if other ~= ctl then
						other.paintStar()
					end
				end
				UITheme.toast("success", "Favourite", "Your favourite creature can't be stolen.")
			end
			favs[uid] = if on then true else nil
			ctl.paintStar()
			ReplicatedStorage:WaitForChild("RewardsAction"):FireServer("Favourite", uid, on)
		end)
	end
	function ctl.paintStar()
		if star then
			star.Text = if favs[uid] then "★" else "☆"
			star.TextColor3 = if favs[uid] then C.Gold else C.TextMuted
			ctl.frame:SetAttribute("Favourite", favs[uid] == true)
		end
	end
	local income = UIKit.text({
		Name = "Income",
		Role = "Small",
		Font = UIStyle.FontBold,
		Rich = true,
		Position = UDim2.fromOffset(10, PREVIEW_H + 33),
		Size = UDim2.new(1, -20, 0, 18),
		Parent = card,
	})
	local _, actionCtl = UIKit.button({
		Name = "Action",
		Kind = "Primary",
		Text = "Equip",
		Size = UDim2.new(1, -12, 0, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Parent = card,
		OnActivated = function()
			requestAction(ctl)
		end,
	})
	ctl.actionCtl = actionCtl
	selectBtn.Activated:Connect(function()
		selectWorker(uid)
	end)
	card.MouseEnter:Connect(function()
		if selectedUid ~= uid then
			stroke.Color = C.Gold:Lerp(C.Border, 0.4)
		end
	end)
	card.MouseLeave:Connect(function()
		ctl.paintBorder()
	end)

	function ctl.paintBorder()
		if selectedUid == uid then
			stroke.Color, stroke.Thickness = C.Gold, 2.5
		else
			stroke.Color, stroke.Thickness = ctl.borderColor or C.Border, UIStyle.BorderThickness
		end
	end
	function ctl.update(entry, canStore: boolean, canEquip: boolean)
		ctl.entry, ctl.canStore, ctl.canEquip = entry, canStore, canEquip
		ctl.pending = nil
		local worker = WorkerCatalogue.get(entry.id)
		ctl.worker = worker
		local rarity = worker and worker.rarity or "Common"
		local color = UIStyle.Rarity[rarity] or C.Border
		tag.set(rarity)
		backdrop.Color = ColorSequence.new(color:Lerp(C.PanelDark, 0.72), C.PanelDark)
		local loc = LOC[entry.loc] or LOC.inventory
		locLabel.Text, locLabel.TextColor3 = loc.text, loc.color
		ctl.borderColor = if entry.loc == "station"
			then C.Cash:Lerp(C.PanelRaised, 0.5)
			elseif entry.loc == "carried" then C.Gold:Lerp(C.PanelRaised, 0.4)
			else color:Lerp(C.PanelRaised, 0.6)
		ctl.paintBorder()
		name.Text = worker and worker.name or entry.id
		typeRow.Visible = levelsOn() and worker ~= nil
		if worker and typeRow.Visible and (not typeIcon or typeIcon:GetAttribute("Icon") ~= WorkerCatalogue.ROLE_ICONS[worker.role]) then
			if typeIcon then
				typeIcon:Destroy()
			end
			typeIcon = UITheme.image({ Icon = WorkerCatalogue.ROLE_ICONS[worker.role], Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = typeRow })
		end
		levelLabel.Text = "Lv " .. tostring(entry.level or 1)
		local rate = "+" .. CashFormat.format(incomeOf(entry)) .. "/s"
		income.Text = if entry.loc == "station"
			then ('<font color="#%s">%s</font>'):format(C.Cash:ToHex(), rate)
			else ('<font color="#%s">%s</font> <font color="#%s">when placed</font>'):format(C.TextMuted:ToHex(), rate, C.TextDim:ToHex())
		ctl.paintStar()
		if ctl.preview and ctl.previewId ~= entry.id then
			ctl.preview.set(entry.id)
			ctl.previewId = entry.id
		end
		ctl.refresh()
	end
	function ctl.refresh()
		local entry = ctl.entry
		if entry.loc == "inventory" then
			ctl.action = "Equip"
			actionCtl.setText("Equip")
			actionCtl.setEnabled(ctl.canEquip and ctl.worker ~= nil, "Stations full")
		else
			ctl.action = if entry.loc == "carried" then "StoreCarried" else "Store"
			actionCtl.setText("Store")
			actionCtl.setEnabled(ctl.canStore, "Storage full")
		end
	end
	function ctl.showPreview(on: boolean)
		if on and not ctl.preview then
			ctl.preview = WorkerPreview.mount(modelHolder, ctl.entry.id)
			ctl.previewId = ctl.entry.id
		elseif not on and ctl.preview then
			ctl.preview.release()
			ctl.preview = nil
		end
	end
	ctl.frame = card
	return ctl
end

-- Detail ------------------------------------------------------------------------------------------
local function paintDetail()
	local ctl = selectedUid and cards[selectedUid]
	detailEmpty.Visible = ctl == nil
	detailContent.Visible = ctl ~= nil
	backButton.Visible = not wide
	if not ctl then
		if detailPreview then
			detailPreview.release()
			detailPreview = nil
		end
		return
	end
	local entry, worker = ctl.entry, ctl.worker
	local rarity = worker and worker.rarity or "Common"
	local color = UIStyle.Rarity[rarity] or C.Border
	dBackdrop.Color = ColorSequence.new(color:Lerp(C.PanelDark, 0.6), C.PanelDark)
	dName.Text = worker and worker.name or entry.id
	dRarity.set(rarity)
	dRole.Text = worker and worker.role or "?"
	local loc = LOC[entry.loc] or LOC.inventory
	dLoc.Text, dLoc.TextColor3 = (if entry.loc == "station" and entry.station then loc.text .. " · STATION " .. entry.station else loc.text), loc.color
	local rate = "+" .. CashFormat.format(incomeOf(entry)) .. "/s"
	dIncome.Text = if entry.loc == "station"
		then ('<font color="#%s">%s</font>  <font color="#%s" size="13">earning now</font>'):format(C.Cash:ToHex(), rate, C.TextMuted:ToHex())
		else ('<font color="#%s">%s</font>  <font color="#%s" size="13">once on a station</font>'):format(C.TextMuted:ToHex(), rate, C.TextDim:ToHex())
	dLevel.Text = ("Level %d  ·  %s tier"):format(entry.level or 1, tostring(entry.tier or "Normal"))
	local level = entry.level or 1
	local cost = worker and BaseConfig.levelCost(worker.income, level)
	local canLevel = levelsOn() and player:GetAttribute("LevelsShown") == true and worker ~= nil and entry.loc ~= "carried"
	dLevelUp.Visible = canLevel
	dInfo.Size = if canLevel then UDim2.new(1, 0, 0.56, -118) else UDim2.new(1, 0, 0.56, -60)
	if canLevel and worker then
		if cost then
			local next = BaseConfig.levelIncome(worker.income, level + 1) - incomeOf(entry)
			dLevel.Text = ("Level %d/%d  ·  next level +%s/s"):format(level, BaseConfig.MAX_LEVEL, if next % 1 == 0 then tostring(next) else ("%.1f"):format(next))
			dLevelUpCtl.setText("Level up  " .. CashFormat.format(cost))
			dLevelUpCtl.setEnabled(not levelBusy and (player:GetAttribute("Cash") or 0) >= cost, if levelBusy then "…" else "Need " .. CashFormat.format(cost))
		else
			dLevel.Text = ("Level %d  ·  top level"):format(level)
			dLevelUpCtl.setText("Top level")
			dLevelUpCtl.setEnabled(false, "Top level")
		end
	end
	for _, s in statBars do
		local v = worker and worker[s.key] or 0
		s.label.Text = s.short .. "  " .. v
		s.meter.set(v / 100)
	end
	local ac = ctl.actionCtl
	dActionCtl.setText(if ctl.action == "Equip" then "Equip to a station" else "Move to storage")
	dActionCtl.setEnabled(ac.button.Active, if ctl.action == "Equip" then "All 6 stations are full" else "Storage is full (20/20)")
	if detailPreview then
		detailPreview.set(entry.id)
	else
		detailPreview = WorkerPreview.mount(dModel, entry.id, { rotate = true, yaw = 180 })
	end
end

local function showSheet(on: boolean)
	if wide then
		detail.Visible = true
		return
	end
	if on then
		detail.Visible = true
		detail.Position = UDim2.fromScale(0, 1)
		TweenService:Create(detail, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 0) }):Play()
	else
		detail.Visible = false
	end
end

selectWorker = function(uid: string?)
	local previous = selectedUid and cards[selectedUid]
	selectedUid = uid
	if previous then
		previous.paintBorder()
	end
	if uid and cards[uid] then
		cards[uid].paintBorder()
	end
	paintDetail()
	showSheet(uid ~= nil)
	queuePreviews() -- closing the phone sheet uncovers the grid again
end

requestAction = function(ctl)
	if not ctl.action or ctl.pending then
		return
	end
	ctl.pending = os.clock()
	ctl.actionCtl.setEnabled(false, "…")
	if selectedUid == ctl.uid then
		dActionCtl.setEnabled(false, "…")
	end
	WorkerState.request(ctl.action, ctl.uid)
	task.delay(PENDING_TIMEOUT, function()
		if ctl.pending and os.clock() - ctl.pending >= PENDING_TIMEOUT - 0.05 then
			ctl.pending = nil
			ctl.refresh()
			if selectedUid == ctl.uid then
				paintDetail()
			end
		end
	end)
end
dAction.Activated:Connect(function()
	local ctl = selectedUid and cards[selectedUid]
	if ctl and dAction.Active then
		requestAction(ctl)
	end
end)
backButton.Activated:Connect(function()
	selectWorker(nil)
end)
dLevelUp.Activated:Connect(function()
	local uid = selectedUid
	local request = ReplicatedStorage:FindFirstChild("BaseRequest") :: RemoteFunction?
	if not (uid and request and dLevelUp.Active) or levelBusy then
		return
	end
	levelBusy = true
	paintDetail()
	pcall(function()
		request:InvokeServer("LevelUp", uid) -- the inventory snapshot that follows repaints the card
	end)
	levelBusy = false
	paintDetail()
end)
player:GetAttributeChangedSignal("Cash"):Connect(function()
	if dLevelUp.Visible then
		paintDetail()
	end
end)
player:GetAttributeChangedSignal("LevelsShown"):Connect(function()
	paintDetail()
end)

-- Preview visibility: only cards inside (or just beyond) the visible list get a live 3D preview.
local visQueued = false
local function updatePreviews()
	visQueued = false
	if not isOpen then
		return
	end
	local top = scroll.AbsolutePosition.Y - PREVIEW_MARGIN
	local bottom = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y + PREVIEW_MARGIN
	local sheetCovers = not wide and selectedUid ~= nil
	for _, ctl in cards do
		local f = ctl.frame
		local y = f.AbsolutePosition.Y
		local visible = not sheetCovers and f.Parent ~= nil and f.Parent.Visible and y + f.AbsoluteSize.Y > top and y < bottom
		ctl.showPreview(visible)
	end
end
queuePreviews = function()
	if not visQueued then
		visQueued = true
		task.defer(updatePreviews)
	end
end
scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(queuePreviews)

-- Render ------------------------------------------------------------------------------------------
local dirty = true
local function render()
	dirty = false
	local snap = WorkerState.snapshot
	local stored, equipped, carried = WorkerState.counts()
	ownedLabel.Text = ("%d/%d"):format(stored + equipped + carried, math.max(CAPACITY, snap.slots + snap.stations))
	for i = 1, math.max(#pipFrames, snap.stations) do -- stations bought at the Upgrade Office add pips
		if not pipFrames[i] then
			pipFrames[i] = pipFrames[1]:Clone()
			pipFrames[i].Name = "Pip" .. i
			pipFrames[i].LayoutOrder = i
			pipFrames[i].Parent = pips
		end
		pipFrames[i].Visible = i <= snap.stations
		pipFrames[i].Size = UDim2.new(1 / snap.stations, -4, 1, 0)
	end
	for i, slot in slots do
		if i > snap.stations then
			slot.frame.Parent = nil
		end
	end
	stationsLabel.Text = ("Stations  %d/%d"):format(equipped, snap.stations)
	storageLabel.Text = ("Storage  %d/%d"):format(stored, snap.slots)
	storageMeter.set(stored / math.max(snap.slots, 1), if stored >= snap.slots then C.Danger else C.Gold)

	local entries = table.clone(snap.workers)
	table.sort(entries, function(a, b)
		local fa, fb = favs[a.uid] == true, favs[b.uid] == true
		if fa ~= fb then
			return fa
		end -- favourites first (only ever set in the V1 look)
		local wa, wb = WorkerCatalogue.get(a.id), WorkerCatalogue.get(b.id)
		local ra, rb = wa and rarityRank[wa.rarity] or 0, wb and rarityRank[wb.rarity] or 0
		local ia, ib = wa and wa.income or 0, wb and wb.income or 0
		if sortMode == "income" and ia ~= ib then
			return ia > ib
		end
		if ra ~= rb then
			return ra > rb
		end
		if ia ~= ib then
			return ia > ib
		end
		return a.uid < b.uid
	end)
	local canStore, canEquip = stored < snap.slots, equipped < snap.stations
	local seen, count, byStation = {}, { carried = 0, station = 0, inventory = 0 }, {}
	for order, entry in entries do
		seen[entry.uid] = true
		local ctl = cards[entry.uid] or newCard(entry.uid)
		cards[entry.uid] = ctl
		local key = if grids[entry.loc] then entry.loc else "inventory"
		count[key] += 1
		if key == "station" and entry.station then
			byStation[entry.station] = ctl
			ctl.frame.LayoutOrder = entry.station
		else
			ctl.frame.LayoutOrder = order
		end
		ctl.frame.Parent = grids[key].grid
		ctl.update(entry, canStore, canEquip)
	end
	for uid, ctl in cards do
		if not seen[uid] then
			ctl.showPreview(false)
			ctl.frame:Destroy()
			cards[uid] = nil
			if selectedUid == uid then
				selectedUid = nil
			end
		end
	end
	-- stations: always 6 cells, empty ones as placeholders
	for i = 1, snap.stations do
		pipFrames[i].BackgroundColor3 = if byStation[i] then C.Cash else C.PanelDark
		slots[i] = slots[i] or makeEmptySlot(i)
		slots[i].frame.LayoutOrder = i
		slots[i].frame.Parent = if byStation[i] then nil else grids.station.grid
	end
	grids.carried.holder.Visible = count.carried > 0
	grids.inventory.empty.Visible = count.inventory == 0
	emptyAll.Visible = #entries == 0
	grids.station.holder.Visible = true
	grids.inventory.holder.Visible = true
	paintDetail()
	queuePreviews()
end

-- Layout: panel size, grid columns and detail placement follow the root size.
local function relayout(size: Vector2)
	wide = size.X >= WIDE_MIN.X and size.Y >= WIDE_MIN.Y
	local pw = if wide then math.min(size.X - 48, 1120) else size.X - 12
	local ph = if wide then math.min(size.Y - 40, 680) else size.Y - 12
	panel.Size = UDim2.fromOffset(math.max(pw, 280), math.max(ph, 240))
	local bodyW = panel.Size.X.Offset - S.L * 2
	local listW
	if wide then
		detail.Size = UDim2.new(0, DETAIL_W, 1, 0)
		detail.Position = UDim2.new(1, -DETAIL_W, 0, 0)
		scroll.Size = UDim2.new(1, -DETAIL_W - S.M, 1, 0)
		detail.Visible = true
		listW = bodyW - DETAIL_W - S.M
	else
		detail.Size = UDim2.fromScale(1, 1)
		detail.Position = UDim2.fromScale(0, 0)
		scroll.Size = UDim2.fromScale(1, 1)
		detail.Visible = selectedUid ~= nil
		listW = bodyW
	end
	local inner = listW - 10 - 6
	local minW = if wide then 166 else 150
	local cols = math.clamp(math.floor((inner + GAP) / (minW + GAP)), 1, 6)
	local cellW = math.floor((inner - GAP * (cols - 1)) / cols)
	for _, g in grids do
		g.layout.CellSize = UDim2.fromOffset(cellW, CARD_H)
	end
	if isOpen then
		paintDetail()
		queuePreviews()
	end
end
UIKit.onResize(root, relayout)

local function setOpen(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	panel.Visible = open
	overlay.Visible = open
	if open then
		relayout(root.AbsoluteSize)
		if dirty then
			render()
		end
		if wide and not selectedUid then
			-- start with the best worker selected on wide screens
			local best, bestRank = nil, -1
			for uid, ctl in cards do
				local r = ctl.worker and (rarityRank[ctl.worker.rarity] or 0) * 1e6 + ctl.worker.income or 0
				if r > bestRank then
					best, bestRank = uid, r
				end
			end
			selectWorker(best)
		end
		queuePreviews()
		panelScale.Scale = 0.96
		overlay.BackgroundTransparency = 1
		TweenService:Create(panelScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(overlay, TweenInfo.new(0.16), { BackgroundTransparency = 0.5 }):Play()
	else
		for _, ctl in cards do
			ctl.showPreview(false)
		end
		if detailPreview then
			detailPreview.release()
			detailPreview = nil
		end
		if not wide then
			selectWorker(nil)
		end
	end
end

UIKit.Signals.ToggleInventory.Event:Connect(function(open: boolean?)
	if open == nil then
		setOpen(not isOpen)
	else
		setOpen(open)
	end
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
overlay.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and isOpen then
		if not wide and selectedUid then
			selectWorker(nil)
		else
			setOpen(false)
		end
	end
end)

WorkerState.Changed:Connect(function()
	dirty = true
	if isOpen then
		render()
	end
end)
if V1 then
	requestRender = function()
		dirty = true
		if isOpen then
			render()
		end
	end
	-- Favourites come from the server's rewards state (RewardsService keeps them in the save).
	ReplicatedStorage:WaitForChild("RewardsState").OnClientEvent:Connect(function(state)
		if type(state) == "table" and type(state.favs) == "table" then
			favs = {}
			for uid, v in state.favs do
				favs[uid] = v == true or nil
			end
			dirty = true
			if isOpen then
				render()
			end
		end
	end)
end

UIKit.mount(gui)
