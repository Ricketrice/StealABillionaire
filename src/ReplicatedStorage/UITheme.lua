-- Studio location: ReplicatedStorage.UITheme (ModuleScript)
-- UITheme  (Milestone 028, extended into the UI kit in 029)
-- The ONE place that decides how the game's UI looks: palette, fonts, text sizes, stroke thickness,
-- corner radius, gradients, button style, press squash and the open/close bounce, plus the components
-- built from them. Two looks:
--   Classic  the 028 look (dark navy panels, muted gold); used while the V1 look is off
--   V1       (V1Flags.UI_V1_ENABLED) chunky and bright: charcoal panels with thick dark outlines,
--            cream text, gold ribbon headers, bright gradient buttons, sprite-sheet icons
-- The look is chosen once when the client starts (from the server's published switch). UIStyle and
-- UIKit take their tokens from here too, so every older screen follows the same look.
--
-- 028 API (unchanged): Colors, Rarity, RarityGlyph, Fonts, TextSize, CornerRadius, PillRadius,
--   StrokeThickness, TextStrokeThickness, Padding, TouchTarget, Button, Motion, make, tween, corner,
--   stroke, panel, text, icon, squash, button, bar, topBar, scaleWith
-- 029 kit:
--   UITheme.image{ Icon, Size, Position?, AnchorPoint?, Parent?, LayoutOrder?, ZIndex? }  sprite icon
--   UITheme.button{ ..., Kind = Primary|Secondary|Gold|Danger|Ghost, Icon? }  + UITheme.setEnabled(b, on, text?)
--   UITheme.closeButton{ Parent, Position?, AnchorPoint?, OnActivated }
--   UITheme.iconButton{ Icon, Label, Parent, LayoutOrder?, OnActivated }      HUD side button (+ .badge)
--   UITheme.window{ Name, Title, Icon, Size = Vector2, Parent = root, OnClose? } -> win
--       win.frame, win.content, win.open(), win.close(), win.isOpen()   (ribbon header, overlay, bounce)
--   UITheme.card{ Size, Parent, Rarity?, LayoutOrder?, Color? }           item card
--   UITheme.pill{ Icon, Text, Parent, OnPlus?, LayoutOrder? } -> (frame, label, plus?)  currency pill
--   UITheme.tabs{ Tabs = { {key, title, icon?} }, Parent, Size, Position?, OnSelect } -> (frame, select)
--   UITheme.badge(parent, text?) -> (label, set(text?))                    red notification dot
--   UITheme.popup{ Title, Icon?, Text, Buttons = { {Text, Kind, OnActivated} }, Parent = root } -> win
--   UITheme.toast(kind, title, message)                                    (UIKit's shared toast stack)
--   UITheme.gui(name, displayOrder) -> (ScreenGui, root)                   safe-area screen + root
--   UITheme.registerScreen(name, open, close) / openScreen(name, arg?) / closeScreens()
--   UITheme.coinBurst(fromGuiObject?, count?)                              coins fly to the cash pill
-- Display only: nothing here talks to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local V1Flags = require(ReplicatedStorage:WaitForChild("V1Flags"))

local UITheme = {}

local rgb = Color3.fromRGB

-- Which look ----------------------------------------------------------------------------------------
if RunService:IsClient() then
	V1Flags.waitReady(6)
end
UITheme.v1 = V1Flags.on("UI_V1_ENABLED")
local V1 = UITheme.v1

-- Colours ---------------------------------------------------------------------------------------------
local CLASSIC = {
	Panel = rgb(28, 34, 52),
	PanelDark = rgb(19, 23, 36),
	PanelRaised = rgb(38, 46, 68),
	Stroke = rgb(10, 12, 20),
	Border = rgb(72, 80, 104),
	Text = rgb(240, 232, 214),
	TextMuted = rgb(164, 170, 190),
	TextDim = rgb(116, 122, 144),
	Accent = rgb(214, 176, 104), -- gold
	AccentDark = rgb(122, 96, 52),
	AccentText = rgb(30, 28, 24),
	Cream = rgb(240, 232, 214),
	Cash = rgb(132, 214, 124),
	CashDark = rgb(40, 92, 52),
	Success = rgb(124, 202, 132),
	Danger = rgb(228, 108, 100),
	Info = rgb(120, 172, 232),
	Golden = rgb(255, 204, 64), -- Golden Parade
	GoldenDeep = rgb(170, 110, 20),
	Secondary = rgb(58, 72, 106),
	Track = rgb(19, 23, 36), -- progress bar background
	Fill = rgb(132, 214, 124), -- progress bar fill
	Silhouette = rgb(0, 0, 0),
	Disabled = rgb(50, 54, 68),
	Overlay = rgb(8, 10, 16),
}
local BRIGHT = {
	Panel = rgb(48, 43, 64), -- charcoal (a touch of plum)
	PanelDark = rgb(31, 28, 42),
	PanelRaised = rgb(66, 60, 86),
	Stroke = rgb(17, 14, 24), -- the thick dark outline on everything
	Border = rgb(17, 14, 24),
	Text = rgb(255, 249, 234), -- cream
	TextMuted = rgb(206, 198, 222),
	TextDim = rgb(150, 142, 170),
	Accent = rgb(255, 199, 44), -- gold
	AccentDark = rgb(196, 118, 10),
	AccentText = rgb(48, 30, 6),
	Cream = rgb(255, 244, 214),
	Cash = rgb(120, 236, 90),
	CashDark = rgb(34, 110, 40),
	Success = rgb(86, 214, 92),
	Danger = rgb(244, 72, 72),
	Info = rgb(74, 166, 255),
	Golden = rgb(255, 212, 60),
	GoldenDeep = rgb(176, 104, 10),
	Secondary = rgb(74, 150, 255),
	Track = rgb(24, 21, 32),
	Fill = rgb(120, 236, 90),
	Silhouette = rgb(0, 0, 0),
	Disabled = rgb(96, 92, 110),
	Overlay = rgb(10, 8, 14),
}
UITheme.Colors = if V1 then BRIGHT else CLASSIC

-- Rarity colour + glyph + name always together, so rarity never depends on colour alone.
UITheme.Rarity = if V1
	then {
		Common = rgb(196, 204, 218),
		Rare = rgb(74, 166, 255),
		Epic = rgb(184, 104, 255),
		Legendary = rgb(255, 196, 40),
		Secret = rgb(255, 84, 170),
	}
	else {
		Common = rgb(180, 188, 202),
		Rare = rgb(92, 160, 236),
		Epic = rgb(170, 114, 236),
		Legendary = rgb(236, 184, 76),
		Secret = rgb(236, 98, 156),
	}
UITheme.RarityGlyph = { Common = "●", Rare = "◆", Epic = "▲", Legendary = "★", Secret = "✦" }

-- Type ------------------------------------------------------------------------------------------------
UITheme.Fonts = if V1
	then {
		Display = Enum.Font.FredokaOne, -- titles, big numbers, buttons
		Ribbon = Enum.Font.LuckiestGuy, -- ribbon headers and banners
		Body = Enum.Font.GothamBold,
		Bold = Enum.Font.GothamBlack,
	}
	else {
		Display = Enum.Font.FredokaOne,
		Ribbon = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
	}
UITheme.TextSize = if V1 then { Display = 32, Title = 24, Body = 17, Small = 14 } else { Display = 30, Title = 22, Body = 16, Small = 13 }
local ROLE_FONT = { Display = "Display", Title = "Display", Body = "Body", Small = "Bold" }

-- Shapes ----------------------------------------------------------------------------------------------
UITheme.CornerRadius = UDim.new(0, if V1 then 16 else 12)
UITheme.SmallRadius = UDim.new(0, if V1 then 12 else 8)
UITheme.PillRadius = UDim.new(1, 0)
UITheme.StrokeThickness = if V1 then 3 else 2 -- panels and buttons
UITheme.TextStrokeThickness = if V1 then 2 else 1.5
UITheme.Padding = if V1 then 12 else 10
UITheme.TouchTarget = 44 -- minimum on-screen size of anything tappable (after scaling)

-- Gradients (UIGradient multiplies the colour under it: top light, bottom shaded) ------------------------
UITheme.Gradients = {
	Button = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.78, 0.78, 0.78)),
	Panel = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.86, 0.86, 0.86)),
	Ribbon = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.82, 0.74, 0.6)),
	Fill = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.72)),
}

-- Buttons ---------------------------------------------------------------------------------------------
UITheme.Button = if V1
	then {
		Primary = { fill = rgb(86, 214, 76), text = rgb(255, 255, 255), stroke = rgb(17, 14, 24) }, -- green: claim, buy, place
		Secondary = { fill = rgb(74, 150, 255), text = rgb(255, 255, 255), stroke = rgb(17, 14, 24) }, -- blue
		Gold = { fill = rgb(255, 196, 40), text = rgb(255, 255, 255), stroke = rgb(17, 14, 24) },
		Danger = { fill = rgb(244, 72, 72), text = rgb(255, 255, 255), stroke = rgb(17, 14, 24) },
		Ghost = { fill = rgb(31, 28, 42), text = rgb(255, 249, 234), stroke = rgb(17, 14, 24) },
		Disabled = { fill = rgb(96, 92, 110), text = rgb(200, 196, 212), stroke = rgb(17, 14, 24) },
		PressScale = 0.9, -- squash on press
		Font = "Display",
		TextSize = 20,
		TextStroke = true, -- white text with a dark outline
	}
	else {
		Primary = { fill = rgb(198, 160, 86), text = rgb(30, 28, 24), stroke = rgb(122, 96, 52) },
		Secondary = { fill = rgb(58, 72, 106), text = rgb(240, 232, 214), stroke = rgb(10, 12, 20) },
		Gold = { fill = rgb(198, 160, 86), text = rgb(30, 28, 24), stroke = rgb(122, 96, 52) },
		Danger = { fill = rgb(160, 70, 64), text = rgb(240, 232, 214), stroke = rgb(10, 12, 20) },
		Ghost = { fill = rgb(19, 23, 36), text = rgb(240, 232, 214), stroke = rgb(72, 80, 104) },
		Disabled = { fill = rgb(50, 54, 68), text = rgb(116, 122, 144), stroke = rgb(10, 12, 20) },
		PressScale = 0.92,
		Font = "Display",
		TextSize = 18,
		TextStroke = false,
	}

-- Motion ----------------------------------------------------------------------------------------------
UITheme.Motion = { Fast = 0.15, Normal = 0.25, Slow = 0.45, Open = 0.32 }

-- Icons (D14: two 1024 px sprite sheets of 256 px tiles, assets/export/ui) ------------------------------
-- Image asset ids of the uploaded sheets. 0 = not uploaded yet: icons fall back to emoji/text.
UITheme.ICON_SHEETS = { 0, 0 }
UITheme.ICON_TILE = 256
-- name = { sheet, x, y } (from tools/blender/pack_029_icons.py)
UITheme.ICONS = {
	cash = { 1, 0, 0 },
	coin = { 1, 256, 0 },
	gem = { 1, 512, 0 },
	shop = { 1, 768, 0 },
	backpack = { 1, 0, 256 },
	book = { 1, 256, 256 },
	gift = { 1, 512, 256 },
	calendar = { 1, 768, 256 },
	clock = { 1, 0, 512 },
	settings = { 1, 256, 512 },
	close = { 1, 512, 512 },
	lock = { 1, 768, 512 },
	check = { 1, 0, 768 },
	star = { 1, 256, 768 },
	trophy = { 1, 512, 768 },
	arena = { 1, 768, 768 },
	base = { 2, 0, 0 },
	parade = { 2, 256, 0 },
	x2 = { 2, 512, 0 },
	vip = { 2, 768, 0 },
	slots = { 2, 0, 256 },
	plus = { 2, 256, 256 },
	hourglass = { 2, 512, 256 },
	moon = { 2, 768, 256 },
	music = { 2, 0, 512 },
	sound = { 2, 256, 512 },
	sparkle = { 2, 512, 512 },
	quest = { 2, 768, 512 },
	bolt = { 2, 0, 768 },
	flag = { 2, 256, 768 },
	heart = { 2, 512, 768 },
}
UITheme.ICON_FALLBACK = {
	cash = "💵",
	coin = "🪙",
	gem = "💎",
	shop = "🏪",
	backpack = "🎒",
	book = "📖",
	gift = "🎁",
	calendar = "📅",
	clock = "⏰",
	settings = "⚙️",
	close = "X",
	lock = "🔒",
	check = "✔️",
	star = "⭐",
	trophy = "🏆",
	arena = "🏏",
	base = "🏠",
	parade = "❓",
	x2 = "2x",
	vip = "👑",
	slots = "🗃️",
	plus = "+",
	hourglass = "⏳",
	moon = "🌙",
	music = "🎵",
	sound = "🔊",
	sparkle = "✨",
	quest = "📋",
	bolt = "⚡",
	flag = "🚩",
	heart = "❤️",
}

-- Helpers ---------------------------------------------------------------------------------------------
local function make(className: string, props: { [string]: any }): any
	local obj = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(obj :: any)[key] = value
		end
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end
UITheme.make = make

function UITheme.tween(obj: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function UITheme.corner(obj: GuiObject, radius: UDim?): UICorner
	return make("UICorner", { CornerRadius = radius or UITheme.CornerRadius, Parent = obj })
end

function UITheme.stroke(obj: GuiObject, color: Color3?, thickness: number?): UIStroke
	local isText = obj:IsA("TextLabel") or obj:IsA("TextButton") and (obj :: TextButton).BackgroundTransparency >= 1
	return make("UIStroke", {
		Color = color or (if isText then UITheme.Colors.Stroke else UITheme.Colors.Border),
		Thickness = thickness or (if isText then UITheme.TextStrokeThickness else UITheme.StrokeThickness),
		Transparency = if isText and not color and not V1 then 0.3 else 0,
		ApplyStrokeMode = if isText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = obj,
	})
end

-- A light-top shading gradient (V1 look only; Classic stays flat).
function UITheme.shade(obj: GuiObject, preset: string?): UIGradient?
	if not V1 then
		return nil
	end
	return make("UIGradient", { Color = UITheme.Gradients[preset or "Panel"], Rotation = 90, Parent = obj })
end

-- A rounded panel. props: the Frame's own properties plus Color (fill) and Stroke (false = none).
function UITheme.panel(props: { [string]: any }): Frame
	local color, stroke = props.Color, props.Stroke
	props.Color, props.Stroke = nil, nil
	props.BackgroundColor3 = color or UITheme.Colors.Panel
	props.BorderSizePixel = 0
	local frame = make("Frame", props)
	UITheme.corner(frame)
	if stroke ~= false then
		UITheme.stroke(frame, if typeof(stroke) == "Color3" then stroke else nil)
	end
	UITheme.shade(frame, "Panel")
	return frame
end

-- Text. props: the TextLabel's own properties plus Role, Color, Align ("Left"|"Center"|"Right").
function UITheme.text(props: { [string]: any }): TextLabel
	local role = props.Role or "Body"
	local color, align = props.Color, props.Align
	props.Role, props.Color, props.Align = nil, nil, nil
	props.BackgroundTransparency = 1
	props.Font = props.Font or UITheme.Fonts[ROLE_FONT[role] or "Body"]
	props.TextSize = props.TextSize or UITheme.TextSize[role] or UITheme.TextSize.Body
	props.TextColor3 = color or UITheme.Colors.Text
	props.TextXAlignment = Enum.TextXAlignment[align or "Center"]
	if props.TextWrapped == nil then
		props.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local label = make("TextLabel", props)
	UITheme.stroke(label)
	return label
end

-- An emoji or glyph icon, sized to its box.
function UITheme.icon(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextScaled = true
	props.Font = props.Font or UITheme.Fonts.Display
	props.TextColor3 = props.TextColor3 or UITheme.Colors.Text
	return make("TextLabel", props)
end

-- A sprite-sheet icon by name; an emoji/text stand-in until the sheet is uploaded.
function UITheme.image(props: { [string]: any }): GuiObject
	local name = props.Icon
	props.Icon = nil
	local tile = UITheme.ICONS[name]
	local sheet = tile and UITheme.ICON_SHEETS[tile[1]]
	props.BackgroundTransparency = 1
	if tile and sheet and sheet > 0 then
		props.Image = "rbxassetid://" .. sheet
		props.ImageRectOffset = Vector2.new(tile[2], tile[3])
		props.ImageRectSize = Vector2.new(UITheme.ICON_TILE, UITheme.ICON_TILE)
		props.ScaleType = Enum.ScaleType.Fit
		local image = make("ImageLabel", props)
		image:SetAttribute("Icon", name)
		return image
	end
	props.Text = UITheme.ICON_FALLBACK[name] or "?"
	props.TextScaled = true
	props.Font = UITheme.Fonts.Display
	props.TextColor3 = UITheme.Colors.Text
	local label = make("TextLabel", props)
	label:SetAttribute("Icon", name)
	UITheme.stroke(label, UITheme.Colors.Stroke, 1.5)
	return label
end

-- The press bounce: shrink while held, spring back on release.
function UITheme.squash(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		UITheme.tween(scale, UITheme.Motion.Fast, { Scale = UITheme.Button.PressScale })
	end)
	local function release()
		UITheme.tween(scale, UITheme.Motion.Normal, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- A button. props: the TextButton's own properties plus Kind, Icon and OnActivated.
-- A disabled button (UITheme.setEnabled) ignores presses.
function UITheme.button(props: { [string]: any }): TextButton
	local kind = props.Kind or "Primary"
	local style = UITheme.Button[kind] or UITheme.Button.Primary
	local onActivated, icon = props.OnActivated, props.Icon
	props.Kind, props.OnActivated, props.Icon = nil, nil, nil
	props.BackgroundColor3 = style.fill
	props.TextColor3 = style.text
	props.Font = props.Font or UITheme.Fonts[UITheme.Button.Font]
	props.TextSize = props.TextSize or UITheme.Button.TextSize
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local button = make("TextButton", props)
	button:SetAttribute("Kind", kind)
	UITheme.corner(button)
	UITheme.stroke(button, style.stroke)
	UITheme.shade(button, "Button")
	if UITheme.Button.TextStroke then
		make("UIStroke", { Color = UITheme.Colors.Stroke, Thickness = UITheme.TextStrokeThickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = button })
	end
	if icon then
		local h = (props.Size and props.Size.Y.Offset or 44) - 12
		UITheme.image({ Icon = icon, Size = UDim2.fromOffset(h, h), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Parent = button })
		make("UIPadding", { PaddingLeft = UDim.new(0, h + 4), Parent = button })
	end
	UITheme.squash(button)
	if onActivated then
		button.Activated:Connect(function(...)
			if button:GetAttribute("Disabled") ~= true then
				onActivated(...)
			end
		end)
	end
	return button
end

-- Greys a UITheme button out (and back). text = what it says while disabled.
function UITheme.setEnabled(button: TextButton, on: boolean, text: string?)
	local kind = button:GetAttribute("Kind") or "Primary"
	local style = if on then UITheme.Button[kind] or UITheme.Button.Primary else UITheme.Button.Disabled
	button:SetAttribute("Disabled", if on then nil else true)
	button.Active = on
	button.BackgroundColor3 = style.fill
	button.TextColor3 = style.text
	if text then
		button.Text = text
	end
end

-- The round red close button.
function UITheme.closeButton(props: { [string]: any }): TextButton
	local size = props.Size or UDim2.fromOffset(52, 52)
	local b = UITheme.button({
		Name = props.Name or "Close",
		Kind = "Danger",
		Text = if UITheme.ICON_SHEETS[1] > 0 then "" else "X",
		TextSize = 26,
		Size = size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		Parent = props.Parent,
		OnActivated = props.OnActivated,
	})
	b:FindFirstChildOfClass("UICorner").CornerRadius = UITheme.PillRadius
	if UITheme.ICON_SHEETS[1] > 0 then
		UITheme.image({
			Icon = "close",
			Size = UDim2.fromScale(0.7, 0.7),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = props.ZIndex,
			Parent = b,
		})
	end
	return b
end

-- A red notification dot (optionally with a number or "!"). set(nil) hides it.
function UITheme.badge(parent: GuiObject, text: string?): (TextLabel, (string?) -> ())
	local dot = make("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UITheme.Colors.Danger,
		Font = UITheme.Fonts.Display,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text or "!",
		ZIndex = (parent.ZIndex or 1) + 3,
		Visible = text ~= nil,
		Parent = parent,
	})
	UITheme.corner(dot, UITheme.PillRadius)
	UITheme.stroke(dot, UITheme.Colors.Stroke, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = dot })
	local function set(value: string?)
		dot.Visible = value ~= nil
		if value then
			dot.Text = value
		end
	end
	return dot, set
end

-- A big square HUD button: icon over a short label. Returns the button; .Badge via UITheme.badge.
function UITheme.iconButton(props: { [string]: any }): TextButton
	local size = props.Size or UDim2.fromOffset(66, 66)
	local b = UITheme.button({
		Name = props.Name or (props.Icon .. "Button"),
		Kind = props.Kind or "Ghost",
		Text = "",
		Size = size,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
		OnActivated = props.OnActivated,
	})
	UITheme.image({ Icon = props.Icon, Size = UDim2.new(1, -14, 1, -24), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Parent = b })
	if props.Label then
		UITheme.text({
			Name = "Label",
			Text = props.Label,
			Role = "Small",
			Font = UITheme.Fonts.Display,
			TextSize = 14,
			Size = UDim2.new(1, 4, 0, 16),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Parent = b,
		})
	end
	return b
end

-- A progress bar. Returns the bar and set(fraction 0..1, animate?).
function UITheme.bar(props: { [string]: any }): (Frame, (number, boolean?) -> ())
	local fillColor = props.Color or UITheme.Colors.Fill
	props.Color = nil
	props.BackgroundColor3 = UITheme.Colors.Track
	props.BorderSizePixel = 0
	local track = make("Frame", props)
	UITheme.corner(track, UITheme.PillRadius)
	UITheme.stroke(track, UITheme.Colors.Stroke, if V1 then 2.5 else nil)
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = fillColor, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track })
	UITheme.corner(fill, UITheme.PillRadius)
	if V1 then
		make("UIGradient", { Color = UITheme.Gradients.Fill, Rotation = 90, Parent = fill })
	end
	local function set(fraction: number, animate: boolean?)
		local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.Visible = fraction > 0
		if animate then
			UITheme.tween(fill, UITheme.Motion.Slow, { Size = goal })
		else
			fill.Size = goal
		end
	end
	return track, set
end

-- A currency pill: icon, amount, optional green "+" (e.g. opens the Store's cash tab).
function UITheme.pill(props: { [string]: any }): (Frame, TextLabel, TextButton?)
	local height = props.Height or 50
	local frame = make("Frame", {
		Name = props.Name or "Pill",
		BackgroundColor3 = UITheme.Colors.PanelDark,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.Width or 190, height),
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
	})
	UITheme.corner(frame, UITheme.PillRadius)
	UITheme.stroke(frame, UITheme.Colors.Stroke)
	UITheme.shade(frame, "Panel")
	UITheme.image({
		Icon = props.Icon or "cash",
		Size = UDim2.fromOffset(height + 8, height + 8),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -10, 0.5, 0),
		ZIndex = 2,
		Parent = frame,
	})
	local right = if props.OnPlus then height - 4 else 8
	local label = UITheme.text({
		Name = "Amount",
		Text = props.Text or "",
		Role = "Display",
		TextSize = math.floor(height * 0.56),
		Align = "Left",
		Size = UDim2.new(1, -(height + 4) - right, 1, 0),
		Position = UDim2.fromOffset(height + 2, 0),
		Parent = frame,
	})
	local plus = nil
	if props.OnPlus then
		plus = UITheme.button({
			Name = "Plus",
			Kind = "Primary",
			Text = "+",
			TextSize = 28,
			Size = UDim2.fromOffset(height - 6, height - 6),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -3, 0.5, 0),
			OnActivated = props.OnPlus,
			Parent = frame,
		})
		plus:FindFirstChildOfClass("UICorner").CornerRadius = UITheme.PillRadius
	end
	return frame, label, plus
end

-- A card (shop item, worker, reward). Rarity tints the outline and backdrop.
function UITheme.card(props: { [string]: any }): Frame
	local rarity, color = props.Rarity, props.Color
	props.Rarity, props.Color = nil, nil
	props.BackgroundColor3 = color or UITheme.Colors.PanelRaised
	props.BorderSizePixel = 0
	local frame = make("Frame", props)
	UITheme.corner(frame, UITheme.SmallRadius)
	local rc = rarity and UITheme.Rarity[rarity]
	UITheme.stroke(frame, if V1 then UITheme.Colors.Stroke else (rc or UITheme.Colors.Border))
	if rc then
		make("UIGradient", { Color = ColorSequence.new(rc:Lerp(Color3.new(1, 1, 1), 0.15), rc:Lerp(UITheme.Colors.PanelDark, 0.55)), Rotation = 90, Parent = frame })
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
	else
		UITheme.shade(frame, "Panel")
	end
	return frame
end

-- A tab row. Tabs = { { key, title, icon? } }. Returns the row and select(key).
function UITheme.tabs(props: { [string]: any }): (Frame, (string) -> ())
	local row = make("ScrollingFrame", {
		Name = props.Name or "Tabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, 48),
		Position = props.Position,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Parent = props.Parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = row,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = row })
	local buttons = {}
	local current = nil
	local function choose(key: string)
		current = key
		for k, b in buttons do
			local style = if k == key then UITheme.Button.Gold else UITheme.Button.Ghost
			b.BackgroundColor3, b.TextColor3 = style.fill, style.text
			b:SetAttribute("Selected", k == key)
		end
		if props.OnSelect then
			props.OnSelect(key)
		end
	end
	local height = (props.Size and props.Size.Y.Offset or 48) - 4
	for i, tab in props.Tabs do
		local b = UITheme.button({
			Name = "Tab_" .. tab.key,
			Kind = "Ghost",
			Text = tab.title,
			Icon = tab.icon,
			TextSize = 18,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
			Parent = row,
			OnActivated = function()
				if current ~= tab.key then
					choose(tab.key)
				end
			end,
		})
		local pad = b:FindFirstChildOfClass("UIPadding") or make("UIPadding", { Parent = b })
		pad.PaddingRight = UDim.new(0, 14)
		if not tab.icon then
			pad.PaddingLeft = UDim.new(0, 14)
		end
		buttons[tab.key] = b
	end
	return row, choose
end

-- Screens: one window open at a time ------------------------------------------------------------------
local screens: { [string]: { open: (any?) -> (), close: () -> () } } = {}
local openName: string? = nil
local screenChanged = Instance.new("BindableEvent")
UITheme.ScreenChanged = screenChanged.Event -- (name: string?) the window now open, nil = none

function UITheme.registerScreen(name: string, open: (any?) -> (), close: () -> ())
	screens[name] = { open = open, close = close }
end
function UITheme.openScreen(name: string, arg: any?)
	local s = screens[name]
	if not s then
		return
	end
	if openName and openName ~= name and screens[openName] then
		screens[openName].close()
	end
	openName = name
	s.open(arg)
	screenChanged:Fire(name)
end
function UITheme.screenClosed(name: string)
	if openName == name then
		openName = nil
		screenChanged:Fire(nil)
	end
end
function UITheme.closeScreens()
	if openName and screens[openName] then
		screens[openName].close()
	end
end
function UITheme.openScreenName(): string?
	return openName
end

-- A ScreenGui clear of the Roblox top bar and device notches, with a Root frame filling the safe area.
function UITheme.gui(name: string, displayOrder: number): (ScreenGui, Frame)
	local gui = make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, root
end

-- Scales a fixed-size window so it fits `root` (with a margin) and never grows past maxScale.
local function fitScale(scale: UIScale, size: Vector2, root: GuiObject, maxScale: number?)
	local function update()
		local avail = root.AbsoluteSize
		if avail.X < 1 then
			return
		end
		local s = math.min((avail.X - 16) / size.X, (avail.Y - 16) / size.Y, maxScale or 1.15, math.min(avail.X, avail.Y) / 520)
		scale.Scale = math.max(s, 0.4)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	task.defer(update)
end

-- A window: dim overlay, panel with a gold ribbon header (icon + title) and a red close button.
-- props: Name, Title, Icon, Size (Vector2, authored px), Parent (a root frame), OnClose?, MaxScale?
function UITheme.window(props: { [string]: any }): any
	local size: Vector2 = props.Size or Vector2.new(600, 400)
	local root: GuiObject = props.Parent
	local overlay = make("TextButton", {
		Name = (props.Name or "Window") .. "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = UITheme.Colors.Overlay,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	-- frame: invisible, sized and fitted to the screen (UIScale "Fit"); panel: what you see, bounced.
	local frame = make("Frame", {
		Name = props.Name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
		Parent = root,
	})
	fitScale(make("UIScale", { Name = "Fit", Parent = frame }), size + Vector2.new(0, 34), root, props.MaxScale)
	local holder = UITheme.panel({ Name = "Panel", Size = UDim2.fromScale(1, 1), ZIndex = 11, Parent = frame })
	local scale = make("UIScale", { Name = "Bounce", Parent = holder })

	-- ribbon header
	local ribbon = make("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UITheme.Colors.Accent,
		BorderSizePixel = 0,
		ZIndex = 13,
		Parent = holder,
	})
	UITheme.corner(ribbon, UITheme.SmallRadius)
	UITheme.stroke(ribbon, UITheme.Colors.Stroke)
	if V1 then
		make("UIGradient", { Color = UITheme.Gradients.Ribbon, Rotation = 90, Parent = ribbon })
	end
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ribbon,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, if props.Icon then 6 else 22), PaddingRight = UDim.new(0, 22), Parent = ribbon })
	if props.Icon then
		UITheme.image({ Icon = props.Icon, Size = UDim2.fromOffset(46, 46), LayoutOrder = 1, ZIndex = 14, Parent = ribbon })
	end
	local title = UITheme.text({
		Name = "Title",
		Text = props.Title or "",
		Role = "Title",
		Font = UITheme.Fonts.Ribbon,
		TextSize = 28,
		Color = if V1 then Color3.new(1, 1, 1) else UITheme.Colors.AccentText,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = 14,
		Parent = ribbon,
	})
	title.TextTruncate = Enum.TextTruncate.None

	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(UITheme.Padding, 34),
		Size = UDim2.new(1, -UITheme.Padding * 2, 1, -34 - UITheme.Padding),
		ZIndex = 12,
		Parent = holder,
	})

	local win: any = { frame = frame, content = content, title = title, overlay = overlay, holder = holder }
	local isOpen = false
	function win.isOpen(): boolean
		return isOpen
	end
	function win.open()
		if isOpen then
			return
		end
		isOpen = true
		frame.Visible, overlay.Visible = true, true
		overlay.BackgroundTransparency = 1
		scale.Scale = 0.6
		UITheme.tween(scale, UITheme.Motion.Open, { Scale = 1 }, Enum.EasingStyle.Back)
		UITheme.tween(overlay, UITheme.Motion.Normal, { BackgroundTransparency = 0.45 })
		frame:SetAttribute("Open", true)
	end
	function win.close()
		if not isOpen then
			return
		end
		isOpen = false
		frame:SetAttribute("Open", nil)
		UITheme.tween(overlay, UITheme.Motion.Fast, { BackgroundTransparency = 1 })
		UITheme.tween(scale, UITheme.Motion.Fast, { Scale = 0.75 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
			if not isOpen then
				frame.Visible, overlay.Visible = false, false
			end
		end)
		if props.Name then
			UITheme.screenClosed(props.Name)
		end
		if props.OnClose then
			props.OnClose()
		end
	end
	win.closeButton = UITheme.closeButton({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), ZIndex = 15, Parent = holder, OnActivated = win.close })
	overlay.Activated:Connect(win.close)
	return win
end

-- A small message window with buttons. Buttons = { { Text, Kind, OnActivated } } (each closes it).
function UITheme.popup(props: { [string]: any }): any
	local win = UITheme.window({ Name = props.Name or "Popup", Title = props.Title, Icon = props.Icon, Size = props.Size or Vector2.new(420, 250), Parent = props.Parent })
	local body = UITheme.text({
		Name = "Body",
		Text = props.Text or "",
		Role = "Body",
		TextSize = 20,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 1, -80),
		Position = UDim2.fromOffset(8, 12),
		ZIndex = 13,
		Parent = win.content,
	})
	body.TextYAlignment = Enum.TextYAlignment.Center
	win.body = body
	local row = make("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 56),
		ZIndex = 13,
		Parent = win.content,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	win.buttons = {}
	for i, def in props.Buttons or {} do
		win.buttons[i] = UITheme.button({
			Name = "Button" .. i,
			Kind = def.Kind or "Primary",
			Text = def.Text,
			Icon = def.Icon,
			TextSize = 22,
			Size = UDim2.fromOffset(def.Width or 190, 56),
			LayoutOrder = i,
			ZIndex = 14,
			Parent = row,
			OnActivated = function()
				if def.OnActivated then
					def.OnActivated()
				end
				if def.KeepOpen ~= true then
					win.close()
				end
			end,
		})
	end
	return win
end

-- The shared toast stack (built by UIKit; loaded on first use to keep the modules independent).
function UITheme.toast(kind: string, title: string?, message: string?)
	local UIKit = require(ReplicatedStorage:WaitForChild("UIKit")) :: any
	UIKit.toast(kind, title, message)
end

-- Coins fly from `from` (a GuiObject, or the screen centre) to the registered cash pill.
local cashTarget: GuiObject? = nil
function UITheme.setCashTarget(obj: GuiObject?)
	cashTarget = obj
end
local burstGui: ScreenGui? = nil
function UITheme.coinBurst(from: GuiObject?, count: number?)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if Players.LocalPlayer:GetAttribute("LowEffects") == true then
		count = math.min(count or 10, 4)
	end
	if not burstGui then
		burstGui = make("ScreenGui", { Name = "CoinBurst", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
	end
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local start = if from then from.AbsolutePosition + from.AbsoluteSize / 2 + Vector2.new(0, 36) else view / 2
	local target = if cashTarget then cashTarget.AbsolutePosition + Vector2.new(24, cashTarget.AbsoluteSize.Y / 2 + 36) else Vector2.new(60, 70)
	for i = 1, count or 10 do
		local coin = UITheme.image({
			Icon = "coin",
			Size = UDim2.fromOffset(38, 38),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(start.X, start.Y),
			ZIndex = 50,
			Parent = burstGui,
		})
		local angle = math.random() * math.pi * 2
		local spread = start + Vector2.new(math.cos(angle), math.sin(angle)) * (60 + math.random() * 80)
		task.delay((i - 1) * 0.03, function()
			UITheme.tween(coin, 0.25, { Position = UDim2.fromOffset(spread.X, spread.Y) }, Enum.EasingStyle.Back)
			task.delay(0.3, function()
				UITheme.tween(coin, 0.45, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed
					:Once(function()
						coin:Destroy()
						if cashTarget then
							local s = cashTarget:FindFirstChild("Bump") :: UIScale?
							if s then
								s.Scale = 1.08
								UITheme.tween(s, 0.15, { Scale = 1 })
							end
						end
					end)
			end)
		end)
	end
end

-- The shared top bar (ScreenGui "TopBar028"): one centred row under the Roblox top bar, clear of the
-- HUD on the left and the PvP buttons on the right. Items: Golden Parade pill (1), goal (2), book (3),
-- effects toggle (4). Hidden while the 026 tutorial card (same spot) is up. Client only.
function UITheme.topBar(): Frame
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("TopBar028")
	if gui then
		return gui:WaitForChild("Bar") :: Frame
	end
	gui = make("ScreenGui", { Name = "TopBar028", ResetOnSpawn = false, DisplayOrder = 3, Parent = playerGui })
	local bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bar,
	})
	UITheme.scaleWith(bar, 0.75, 1.1)
	bar.Parent = gui
	local function follow(hub: Instance)
		local function update()
			bar.Visible = hub:GetAttribute("Tutorial") == nil
		end
		hub:GetAttributeChangedSignal("Tutorial"):Connect(update)
		update()
	end
	local hub = playerGui:FindFirstChild("Hub")
	if hub then
		follow(hub)
	else
		playerGui.ChildAdded:Connect(function(child)
			if child.Name == "Hub" then
				follow(child)
			end
		end)
	end
	return bar
end

-- Scales a phone-first layout: UI is authored for a ~700 px short side.
function UITheme.scaleWith(obj: GuiObject, minScale: number?, maxScale: number?): UIScale
	local scale = make("UIScale", { Parent = obj })
	local function update()
		local camera = workspace.CurrentCamera
		local v = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(v.X, v.Y) / 700, minScale or 0.75, maxScale or 1.15)
	end
	local function watch()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
	return scale
end

return UITheme
