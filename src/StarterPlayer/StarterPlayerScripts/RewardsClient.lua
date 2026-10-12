-- Studio location: StarterPlayer.StarterPlayerScripts.RewardsClient (LocalScript)
-- RewardsClient  (Milestone 029) -- the V1 reward screens, all built through UITheme:
--   Daily     7-day streak calendar + Claim (ReplicatedStorage.RewardsOn). A missed day is said kindly.
--   Gifts     playtime gifts (minutes played today) with progress and Open buttons (RewardsOn)
--   Offline   "Your workers earned $X while you were away!" popup on join, Collect (RewardsOn)
--   Settings  music, sounds, low effects, low graphics (UiV1On); saved on the server
-- Display and requests only: amounts, times and claims are all decided by RewardsService; this script
-- shows RewardsState and sends RewardsAction requests. Nothing runs per frame: one 1 s loop updates
-- the countdowns, and only while one of these windows is open.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local FxKit = require(ReplicatedStorage:WaitForChild("FxKit"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local player = Players.LocalPlayer
local T = UITheme.Colors
local stateEvent = ReplicatedStorage:WaitForChild("RewardsState") :: RemoteEvent
local actionEvent = ReplicatedStorage:WaitForChild("RewardsAction") :: RemoteEvent
local clientEvent = ReplicatedStorage:WaitForChild("RewardsEvent") :: RemoteEvent

local gui, root = UITheme.gui("Rewards029", 5)
local state: any = nil
local stateAt = 0 -- os.clock() when `state` arrived
local function serverNow(): number
	return (state and state.now or os.time()) + (os.clock() - stateAt)
end
local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
	return if h > 0 then ("%d:%02d:%02d"):format(h, m, s) else ("%d:%02d"):format(m, s)
end
local function ask(action: string, a: any?, b: any?)
	actionEvent:FireServer(action, a, b)
end

-- Daily ------------------------------------------------------------------------------------------------------
local daily = UITheme.window({ Name = "Daily", Title = "Daily Rewards", Icon = "calendar", Size = Vector2.new(700, 340), Parent = root })
local dailyNote = UITheme.text({
	Name = "Note",
	Text = "",
	Role = "Body",
	TextSize = 18,
	TextWrapped = true,
	Size = UDim2.new(1, -40, 0, 40),
	Position = UDim2.fromOffset(20, 12),
	ZIndex = 13,
	Parent = daily.content,
})
local dayRow =
	UITheme.make("Frame", { Name = "Days", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 150), ZIndex = 13, Parent = daily.content })
UITheme.make("UIGridLayout", { CellSize = UDim2.new(1 / 7, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = dayRow })
local dayCards = {}
for day = 1, 7 do
	local card = UITheme.card({ Name = "Day" .. day, LayoutOrder = day, ZIndex = 13, Parent = dayRow })
	local title = UITheme.text({
		Name = "Title",
		Text = "Day " .. day,
		Role = "Small",
		Font = UITheme.Fonts.Display,
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 6),
		ZIndex = 14,
		Parent = card,
	})
	UITheme.image({
		Icon = if day == 7 then "gift" else "coin",
		Size = UDim2.fromOffset(52, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		ZIndex = 14,
		Parent = card,
	})
	local amount = UITheme.text({
		Name = "Amount",
		Text = "",
		Role = "Small",
		Font = UITheme.Fonts.Display,
		TextSize = 17,
		Color = T.Cash,
		Size = UDim2.new(1, -4, 0, 24),
		Position = UDim2.fromOffset(2, 92),
		ZIndex = 14,
		Parent = card,
	})
	local check =
		UITheme.image({ Icon = "check", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), ZIndex = 15, Parent = card })
	local scale = UITheme.make("UIScale", { Parent = card })
	dayCards[day] = { card = card, title = title, amount = amount, check = check, scale = scale, stroke = card:FindFirstChildOfClass("UIStroke") }
end
local dailyButton = UITheme.button({
	Name = "Claim",
	Kind = "Primary",
	Text = "Claim",
	Icon = "gift",
	TextSize = 24,
	Size = UDim2.fromOffset(320, 60),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -4),
	ZIndex = 14,
	Parent = daily.content,
	OnActivated = function()
		ask("ClaimDaily")
	end,
})

local function paintDaily()
	local d = state and state.daily
	if not d then
		return
	end
	local today = d.nextDay -- the day card that is (or was) today's
	for day, c in dayCards do
		c.amount.Text = CashFormat.format(d.rewards[day] or 0)
		local done = if d.claimedToday then day <= d.streak else (day < today and not d.restarted and d.streak > 0 and day <= d.streak)
		c.check.Visible = done
		c.card.BackgroundTransparency = if day > today and not done then 0.35 else 0
		if c.stroke then
			c.stroke.Color = if day == today and not d.claimedToday then T.Accent else T.Stroke
			c.stroke.Thickness = if day == today and not d.claimedToday then 4 else UITheme.StrokeThickness
		end
	end
	if d.canClaim then
		dailyNote.Text = if d.restarted
			then "Welcome back! A new streak starts today. Come back tomorrow to keep it going."
			else ("Come back every day for bigger rewards! Today: Day %d"):format(today)
		UITheme.setEnabled(dailyButton, true, "Claim Day " .. today)
	else
		dailyNote.Text = ("Day %d collected. See you tomorrow!"):format(d.streak)
		UITheme.setEnabled(dailyButton, false, "Next in " .. clock(d.nextAt - serverNow()))
	end
end

-- Gifts (playtime) -------------------------------------------------------------------------------------------
local gifts = UITheme.window({ Name = "Gifts", Title = "Playtime Gifts", Icon = "gift", Size = Vector2.new(800, 340), Parent = root })
local giftNote = UITheme.text({
	Name = "Note",
	Text = "",
	Role = "Body",
	TextSize = 18,
	Size = UDim2.new(1, -40, 0, 28),
	Position = UDim2.fromOffset(20, 14),
	ZIndex = 13,
	Parent = gifts.content,
})
local giftGrid =
	UITheme.make("Frame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -52), ZIndex = 13, Parent = gifts.content })
UITheme.make("UIGridLayout", { CellSize = UDim2.new(1 / 6, -8, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = giftGrid })
local giftCards = {}
local function giftCard(index: number)
	local card = UITheme.card({ Name = "Gift" .. index, LayoutOrder = index, ZIndex = 13, Parent = giftGrid })
	UITheme.image({ Icon = "gift", Size = UDim2.fromOffset(62, 62), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), ZIndex = 14, Parent = card })
	local mins = UITheme.text({
		Name = "Minutes",
		Text = "",
		Role = "Small",
		Font = UITheme.Fonts.Display,
		TextSize = 19,
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.fromOffset(4, 72),
		ZIndex = 14,
		Parent = card,
	})
	local amount = UITheme.text({
		Name = "Amount",
		Text = "",
		Role = "Small",
		Font = UITheme.Fonts.Display,
		TextSize = 19,
		Color = T.Cash,
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.fromOffset(4, 98),
		ZIndex = 14,
		Parent = card,
	})
	local bar, setBar = UITheme.bar({ Name = "Progress", Size = UDim2.new(1, -16, 0, 12), Position = UDim2.fromOffset(8, 130), ZIndex = 14, Parent = card })
	bar.ZIndex = 14
	local button = UITheme.button({
		Name = "Open",
		Kind = "Primary",
		Text = "Open",
		TextSize = 18,
		Size = UDim2.new(1, -12, 0, 54),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		ZIndex = 14,
		Parent = card,
		OnActivated = function()
			ask("ClaimPlaytime", index)
		end,
	})
	giftCards[index] = { card = card, mins = mins, amount = amount, setBar = setBar, button = button }
end
local function paintGifts()
	local p = state and state.play
	if not p then
		return
	end
	local played = p.secs + (os.clock() - stateAt)
	giftNote.Text = ("Played today: %d min  ·  gifts reset each day"):format(math.floor(played / 60))
	for i, gift in p.gifts do
		if not giftCards[i] then
			giftCard(i)
		end
		local c = giftCards[i]
		local got = p.got[tostring(i)] == true
		local need = gift.minutes * 60
		c.mins.Text = gift.minutes .. " min"
		c.amount.Text = CashFormat.format(gift.cash)
		c.setBar(math.clamp(played / need, 0, 1))
		if got then
			UITheme.setEnabled(c.button, false, "Opened")
		elseif played >= need then
			UITheme.setEnabled(c.button, true, "Open!")
		else
			UITheme.setEnabled(c.button, false, clock(need - played))
		end
	end
end

-- Offline earnings popup ---------------------------------------------------------------------------------
local offline = UITheme.popup({
	Name = "Offline",
	Title = "Welcome back!",
	Icon = "moon",
	Text = "",
	Size = Vector2.new(460, 280),
	Parent = root,
	Buttons = {
		{
			Text = "Collect",
			Kind = "Primary",
			Icon = "coin",
			Width = 230,
			KeepOpen = true,
			OnActivated = function()
				ask("ClaimOffline")
			end,
		},
	},
})
local offlineShown = false
local function paintOffline()
	local o = state and state.offline
	if not (o and o.pending > 0) then
		if offline.isOpen() then
			offline.close()
		end
		return
	end
	local away = o.away or 0
	local h, m = math.floor(away / 3600), math.floor(away % 3600 / 60)
	local awayText = if h > 0 then ("%dh %dm"):format(h, m) else ("%d min"):format(m)
	offline.body.Text = ("Your workers earned %s while you were away! (%s)"):format(CashFormat.format(o.pending), awayText)
	if not offlineShown and UITheme.openScreenName() == nil then
		offlineShown = true -- once per visit; uncollected cash waits for the next one
		task.delay(1.5, function()
			UITheme.openScreen("Offline")
		end)
	end
end
UITheme.registerScreen("Offline", offline.open, offline.close)

-- Settings ------------------------------------------------------------------------------------------------------
local settingsWin = UITheme.window({ Name = "Settings", Title = "Settings", Icon = "settings", Size = Vector2.new(640, 310), Parent = root })
local settings = { music = true, sfx = true, lowfx = false, lowgfx = false }
local SETTING_ROWS = {
	{ key = "music", icon = "music", text = "Music" },
	{ key = "sfx", icon = "sound", text = "Sounds" },
	{ key = "lowfx", icon = "sparkle", text = "Low effects" },
	{ key = "lowgfx", icon = "bolt", text = "Low graphics" },
}
local settingsList = UITheme.make(
	"Frame",
	{ Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 22), Size = UDim2.new(1, -8, 1, -26), ZIndex = 13, Parent = settingsWin.content }
)
UITheme.make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0.5, -6), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = settingsList })
local toggles = {}
local mapShadows = Lighting.GlobalShadows -- what the map uses; Low graphics only ever turns it off
local function apply()
	UITheme.soundGroup("Music").Volume = if settings.music then 1 else 0
	UITheme.soundGroup("SFX").Volume = if settings.sfx then 1 else 0
	player:SetAttribute("LowEffects", settings.lowfx)
	player:SetAttribute("LowGraphics", settings.lowgfx)
	Lighting.GlobalShadows = mapShadows and not settings.lowgfx
	for key, b in toggles do
		local onNow = settings[key] == true
		b:SetAttribute("Kind", if onNow then "Primary" else "Ghost")
		UITheme.setEnabled(b, true, if onNow then "ON" else "OFF")
	end
end
for i, row in SETTING_ROWS do
	local line = UITheme.card({ Name = row.key, LayoutOrder = i, ZIndex = 13, Parent = settingsList })
	UITheme.image({ Icon = row.icon, Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 14, Parent = line })
	UITheme.text({
		Text = row.text,
		Role = "Title",
		TextSize = 21,
		Align = "Left",
		TextWrapped = true,
		Size = UDim2.new(1, -186, 1, 0),
		Position = UDim2.fromOffset(70, 0),
		ZIndex = 14,
		Parent = line,
	})
	toggles[row.key] = UITheme.button({
		Name = "Toggle",
		Kind = "Primary",
		Text = "ON",
		TextSize = 20,
		Size = UDim2.fromOffset(104, 54),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		ZIndex = 14,
		Parent = line,
		OnActivated = function()
			settings[row.key] = not settings[row.key]
			apply()
			ask("Settings", settings)
		end,
	})
end
local settingsLoaded = false

-- Screens, state and events -------------------------------------------------------------------------------------
local wins = { Daily = daily, Gifts = gifts, Settings = settingsWin }
for name, win in wins do
	UITheme.registerScreen(name, function()
		ask("State")
		win.open()
	end, win.close)
end

local function paint()
	paintDaily()
	paintGifts()
	paintOffline()
end
stateEvent.OnClientEvent:Connect(function(s)
	state, stateAt = s, os.clock()
	if s.settings and not settingsLoaded then
		settingsLoaded = true
		for key in settings do
			if type(s.settings[key]) == "boolean" then
				settings[key] = s.settings[key]
			end
		end
		apply()
	end
	paint()
	gui:SetAttribute("StateAt", s.now)
end)
clientEvent.OnClientEvent:Connect(function(kind, info)
	if kind ~= "Claimed" then
		return
	end
	local from = if info.kind == "daily"
		then dailyButton
		elseif info.kind == "offline" then offline.buttons[1]
		elseif info.kind == "playtime" and giftCards[info.index] then giftCards[info.index].button
		else nil
	UITheme.coinBurst(from, if info.kind == "daily" and info.day == 7 then 18 else 10)
	FxKit.sound(if info.kind == "index" then "legendary" else "chime")
	if info.kind == "daily" and dayCards[info.day] then
		local s = dayCards[info.day].scale
		s.Scale = 1.25
		UITheme.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	elseif info.kind == "offline" then
		task.delay(0.6, offline.close)
	end
	gui:SetAttribute("LastClaim", info.kind)
end)

-- Countdowns: once a second, only while a window here is open.
task.spawn(function()
	while gui.Parent do
		if daily.isOpen() then
			paintDaily()
		end
		if gifts.isOpen() then
			paintGifts()
		end
		task.wait(1)
	end
end)

-- Visibility: Daily/Gifts/Offline need RewardsOn; Settings needs UiV1On.
local function refresh()
	if ReplicatedStorage:GetAttribute("RewardsOn") ~= true then
		daily.close()
		gifts.close()
		offline.close()
	end
	if ReplicatedStorage:GetAttribute("UiV1On") ~= true then
		settingsWin.close()
	end
end
ReplicatedStorage:GetAttributeChangedSignal("RewardsOn"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("UiV1On"):Connect(refresh)
refresh()
ask("State")

-- Studio test hook (DevTest_V1029): open a window as a tap would.
if game:GetService("RunService"):IsStudio() then
	gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
		local name = gui:GetAttribute("TestOpen")
		if type(name) == "string" and name ~= "" then
			UITheme.openScreen(name)
		else
			UITheme.closeScreens()
		end
	end)
end
