-- Studio location: ReplicatedStorage.UIStyle (ModuleScript)
-- UIStyle
-- Design tokens for all game UI: colours, rarity colours + glyphs, typography, spacing, radii and
-- sizes, plus the small helpers every screen shares. Reusable components live in UIKit.
-- Look: dark navy/charcoal panels, warm cream text, muted gold accents, rarity colour used sparingly.

local UIStyle = {}

UIStyle.Colors = {
	Panel = Color3.fromRGB(28, 34, 52), -- main panel fill
	PanelDark = Color3.fromRGB(19, 23, 36), -- wells, chips, tracks
	PanelRaised = Color3.fromRGB(38, 46, 68), -- cards on a panel
	Outline = Color3.fromRGB(10, 12, 20), -- text strokes
	Border = Color3.fromRGB(72, 80, 104), -- subtle panel borders
	Gold = Color3.fromRGB(214, 176, 104), -- accent
	GoldDark = Color3.fromRGB(122, 96, 52),
	Text = Color3.fromRGB(240, 232, 214), -- warm cream
	TextMuted = Color3.fromRGB(164, 170, 190),
	TextDim = Color3.fromRGB(116, 122, 144),
	Cash = Color3.fromRGB(132, 214, 124),
	CashDark = Color3.fromRGB(40, 92, 52),
	Success = Color3.fromRGB(124, 202, 132),
	Danger = Color3.fromRGB(228, 108, 100),
	Info = Color3.fromRGB(120, 172, 232),
	Primary = Color3.fromRGB(198, 160, 86), -- primary buttons
	PrimaryText = Color3.fromRGB(30, 28, 24),
	Secondary = Color3.fromRGB(58, 72, 106), -- secondary buttons
	Disabled = Color3.fromRGB(50, 54, 68),
	Overlay = Color3.fromRGB(8, 10, 16),
}

-- Rarity: colour + glyph + name together, so rarity never depends on colour alone.
UIStyle.Rarity = {
	Common = Color3.fromRGB(180, 188, 202),
	Rare = Color3.fromRGB(92, 160, 236),
	Epic = Color3.fromRGB(170, 114, 236),
	Legendary = Color3.fromRGB(236, 184, 76),
	Secret = Color3.fromRGB(236, 98, 156),
}
UIStyle.RarityGlyph = { Common = "●", Rare = "◆", Epic = "▲", Legendary = "★", Secret = "✦" }

UIStyle.Stats = {
	Attack = Color3.fromRGB(232, 120, 104),
	Speed = Color3.fromRGB(104, 196, 236),
	Defence = Color3.fromRGB(232, 196, 96),
}

UIStyle.Font = Enum.Font.FredokaOne -- display (titles, big numbers)
UIStyle.FontBody = Enum.Font.GothamMedium
UIStyle.FontBold = Enum.Font.GothamBold
UIStyle.TextSize = { Display = 30, Title = 22, Heading = 17, Body = 15, Small = 13, Micro = 11 }
UIStyle.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }
UIStyle.Radius = { S = UDim.new(0, 8), M = UDim.new(0, 12), L = UDim.new(0, 16), Pill = UDim.new(1, 0) }
UIStyle.CornerRadius = UIStyle.Radius.M
UIStyle.TouchTarget = 44 -- minimum height of anything tappable
UIStyle.BorderThickness = 1.5
UIStyle.OutlineThickness = UIStyle.BorderThickness
UIStyle.TextStrokeThickness = 1.5
UIStyle.DisplayOrder = { Hud = 2, Inventory = 4, Reveal = 6, Toast = 8 }

function UIStyle.corner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UIStyle.CornerRadius
	corner.Parent = parent
	return corner
end

-- Border for frames/buttons, or a soft dark stroke for text.
function UIStyle.outline(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local isText = parent:IsA("TextLabel") or parent:IsA("TextButton")
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or (if isText then UIStyle.Colors.Outline else UIStyle.Colors.Border)
	stroke.Thickness = thickness or (if isText then UIStyle.TextStrokeThickness else UIStyle.BorderThickness)
	stroke.Transparency = if isText and not color then 0.35 else 0
	stroke.ApplyStrokeMode = if isText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

-- Keeps a UIScale proportional to the screen's short side (UI is authored for a ~700px-tall
-- screen), clamped so phones stay readable and large monitors don't get oversized UI.
local REFERENCE_SHORT_SIDE = 700
function UIStyle.viewportScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local v = camera.ViewportSize
	return math.min(v.X, v.Y) / REFERENCE_SHORT_SIDE
end
function UIStyle.scaleWithViewport(scale: UIScale, minScale: number?, maxScale: number?)
	local function update()
		scale.Scale = math.clamp(UIStyle.viewportScale(), minScale or 0.8, maxScale or 1.2)
	end
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

-- A transparent text label in the display font (kept for older callers; UIKit.text is preferred).
function UIStyle.label(text: string, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = UIStyle.Font
	label.Text = text
	label.TextColor3 = color or UIStyle.Colors.Text
	label.TextScaled = true
	UIStyle.outline(label)
	return label
end

return UIStyle
