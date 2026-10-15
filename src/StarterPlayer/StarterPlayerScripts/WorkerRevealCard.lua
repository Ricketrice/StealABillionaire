-- Studio location: StarterPlayer.StarterPlayerScripts.WorkerRevealCard (LocalScript)
-- WorkerRevealCard
-- The moment a steal completes, shows the catching player the worker they got: a large portrait
-- card with the worker's real 3D model (WorkerPreview), name, rarity badge (icon + name + colour),
-- earnings and role. The world sequence is unchanged: the server's 0.7 s spin happens first, then
-- the server sends the chosen worker id and this card appears. A newer reveal replaces an older one.
--
-- Every reveal runs anticipation -> impact -> reward, and each rarity looks different (017B):
--   Common     no wait: a small card pops in, already complete. Gone in about 1.5 s.
--   Rare       no wait: the card slides up with a colour ring and light sweep; earnings pop in after.
--   Epic       0.6 s silhouette under a soft dim and growing glow, then ring + sparkles.
--   Legendary  1.1 s silhouette with sun rays fading in behind the card; then one soft flash, banner,
--              gold sparkles and the earnings counting up.
--   Secret     the screen goes dark, a beam of light widens behind a heartbeat silhouette for 1.8 s;
--              then flash, rays, three sparkle waves, banner and the earnings counting up.
-- Movement and stealing carry on throughout. Epic and above take a tap on the card: during a
-- Legendary/Secret build-up (after 1 s) it skips to the reveal; on a finished card it closes it.
-- Display only: the server decides the worker; details come from WorkerCatalogue.
-- Zone artwork (017C): zones listed in RevealCardArt add a backdrop, frame, rarity crest and banner
-- plate on top of this card. Zones without artwork, and layers that are missing or fail to load,
-- keep the plain card.
-- In Studio only, an "FX" button previews every tier and the steal/place feedback.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local RevealCardArt = require(ReplicatedStorage:WaitForChild("RevealCardArt"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local WorkerPreview = require(ReplicatedStorage:WaitForChild("WorkerPreview"))

local C = UIStyle.Colors
local revealEvent = ReplicatedStorage:WaitForChild("WorkerRevealed") :: RemoteEvent

local W, H, STAGE_H = 340, 470, 300 -- the 3D preview takes the top 300 px of the card
local FIT_H = H + 48 -- plus the banner overhang above and the hint below
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local CENTRE = UDim2.fromScale(0.5, 0.5)
local SKIP_AFTER = 1 -- seconds before a build-up can be skipped
local SPARKLES = 18
local RAY_BARS = 6 -- each bar crosses the centre, so 12 rays
local HALO = { 0.3, 0.18, 0.1 } -- opacity of the three glow layers at full strength

-- size: card scale; build: anticipation seconds; hold: seconds the finished card stays;
-- dim / dimAfter: backdrop transparency during the build-up / after the impact (lower = darker).
local TIER = {
	Common = { size = 0.82, build = 0, hold = 1.3, sound = "pop", eyebrow = "NEW CREATURE" },
	Rare = { size = 0.9, build = 0, hold = 2, sound = "chime", eyebrow = "RARE CATCH", ring = true, shine = true },
	Epic = {
		size = 1,
		build = 0.6,
		hold = 2.4,
		sound = "epic",
		eyebrow = "EPIC CATCH",
		ring = true,
		shine = true,
		sparkles = 10,
		waves = 1,
		glow = 0.6,
		dim = 0.72,
		dimAfter = 0.8,
		tease = "WHO IS IT?",
		tap = true,
	},
	Legendary = {
		size = 1,
		build = 1.1,
		hold = 3.2,
		sound = "legendary",
		eyebrow = "INCREDIBLE CATCH",
		ring = true,
		shine = true,
		sparkles = 16,
		waves = 2,
		glow = 1,
		dim = 0.5,
		dimAfter = 0.6,
		rays = true,
		banner = true,
		flash = 0.6,
		countUp = true,
		tease = "SOMETHING BIG…",
		tap = true,
	},
	Secret = {
		size = 1,
		build = 1.8,
		hold = 3.6,
		sound = "secret",
		eyebrow = "ULTRA RARE FIND",
		ring = true,
		shine = true,
		sparkles = SPARKLES,
		waves = 3,
		glow = 1,
		dim = 0.25,
		dimAfter = 0.45,
		rays = true,
		beam = true,
		banner = true,
		flash = 0.55,
		countUp = true,
		tease = "A SECRET APPROACHES…",
		tap = true,
	},
}

-- Full-screen layer behind the card: the dim and the single soft flash. Never takes input.
local fxGui = UIKit.screen("WorkerRevealFx", UIStyle.DisplayOrder.Reveal - 1)
fxGui.IgnoreGuiInset = true
fxGui.ScreenInsets = Enum.ScreenInsets.None
local dim = UIKit.make(
	"Frame",
	{ Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Overlay, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Parent = fxGui }
) :: Frame
local flash = UIKit.make(
	"Frame",
	{ Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Parent = fxGui }
) :: Frame

local gui = UIKit.screen("WorkerReveal", UIStyle.DisplayOrder.Reveal)
local root = UIKit.root(gui)
-- The card sits just above the screen centre and is scaled to fit the safe area on any device.
local holder = UIKit.make("Frame", {
	Name = "Holder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 1,
	Visible = false,
	Active = false,
	Parent = root,
}) :: Frame
local fit = UIKit.make("UIScale", { Parent = holder }) :: UIScale
UIKit.onResize(root, function(size)
	fit.Scale = math.clamp(math.min(size.Y * 0.94 / FIT_H, size.X * 0.9 / W), 0.6, 1.2)
end)

-- behind the card: light beam (Secret), sun rays (Legendary/Secret), burst ring, glow halo
local beam = UIKit.make("Frame", {
	Name = "Beam",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = CENTRE,
	Size = UDim2.fromOffset(30, H * 2.4),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 1,
	Parent = holder,
}) :: Frame
UIKit.make(
	"UIGradient",
	{ Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }), Parent = beam }
)

local wheel = UIKit.make("Frame", {
	Name = "Rays",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = holder,
}) :: Frame
local rayBars: { Frame } = {}
for i = 1, RAY_BARS do
	local bar = UIKit.make("Frame", {
		Name = "Ray",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = CENTRE,
		Size = UDim2.fromOffset(W * 2.6, if i % 2 == 0 then 20 else 36),
		Rotation = (i - 1) * (180 / RAY_BARS),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = wheel,
	}) :: Frame
	UIKit.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.8),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = bar,
	})
	rayBars[i] = bar
end

local ring = UIKit.make("Frame", {
	Name = "Ring",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(60, 60),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 3,
	Parent = holder,
}) :: Frame
UIStyle.corner(ring, UIStyle.Radius.Pill)
local ringStroke = UIStyle.outline(ring, WHITE, 7)

local halo: { Frame } = {}
for i, grow in { 16, 38, 66 } do
	local layer = UIKit.make("Frame", {
		Name = "Glow" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = CENTRE,
		Size = UDim2.new(1, grow, 1, grow),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = holder,
	}) :: Frame
	UIStyle.corner(layer, UDim.new(0, 16 + grow / 2))
	halo[i] = layer
end

-- the card
local card = UIKit.make(
	"Frame",
	{ Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = CENTRE, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = holder }
) :: Frame
local pop = UIKit.make("UIScale", { Parent = card }) :: UIScale
local panel = UIKit.panel({ Name = "Panel", Size = UDim2.fromScale(1, 1), Radius = UDim.new(0, 20), Parent = card })
panel.ClipsDescendants = true
local stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
stroke.Thickness = 2.5

local stage =
	UIKit.make("Frame", { Name = "Stage", Size = UDim2.new(1, 0, 0, STAGE_H), BackgroundColor3 = C.PanelDark, BorderSizePixel = 0, ClipsDescendants = true, Parent = panel })
UIStyle.corner(stage, UDim.new(0, 20))
local backdrop = UIKit.make("UIGradient", { Rotation = 90, Parent = stage }) :: UIGradient
-- optional zone artwork behind the worker; 20 px taller than the stage so only its top corners round
local backdropArt = UIKit.make(
	"ImageLabel",
	{ Name = "BackdropArt", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 20), ScaleType = Enum.ScaleType.Crop, Visible = false, Parent = stage }
) :: ImageLabel
UIStyle.corner(backdropArt, UDim.new(0, 20))
local modelHolder = UIKit.make("Frame", { Name = "Model", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 4), Parent = stage })

-- optional frame artwork: drawn over the preview and under the text (it carries the text plates)
local frameArt = UIKit.make(
	"ImageLabel",
	{ Name = "FrameArt", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Stretch, Visible = false, Parent = panel }
) :: ImageLabel

local body = UIKit.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, STAGE_H), Size = UDim2.new(1, 0, 1, -STAGE_H), Parent = panel })
local bodyPad = UIKit.padding(body, 16, 10)
bodyPad.PaddingTop = UDim.new(0, 22) -- room for the rarity badge on the seam
UIKit.list(body, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
local eyebrow = UIKit.text({
	Text = "NEW CREATURE",
	Role = "Micro",
	Font = UIStyle.FontBold,
	TextSize = 13,
	Color = C.Gold,
	AlignX = Enum.TextXAlignment.Center,
	LayoutOrder = 1,
	Parent = body,
})
local nameLabel = UIKit.text({
	Name = "WorkerName",
	Role = "Display",
	TextSize = 30,
	AlignX = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 36),
	Truncate = false,
	LayoutOrder = 2,
	Parent = body,
})
nameLabel.TextScaled = true -- long names shrink instead of being cut off
UIKit.make("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 16, Parent = nameLabel })
local nameScale = UIKit.make("UIScale", { Parent = nameLabel }) :: UIScale
local incomeLabel = UIKit.text({
	Name = "Income",
	Role = "Display",
	TextSize = 24,
	Color = C.Cash,
	AlignX = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 30),
	LayoutOrder = 3,
	Parent = body,
})
local incomeScale = UIKit.make("UIScale", { Parent = incomeLabel }) :: UIScale
local secondary = UIKit.text({ Name = "Secondary", Role = "Small", TextSize = 14, Color = C.TextMuted, AlignX = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = body })

-- rarity badge centred on the seam between the preview and the text
local badge, rarityTag = UIKit.rarityTag({ Height = 30, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, STAGE_H), Parent = panel })
badge.Name = "RarityBadge"
badge.ZIndex = 4
do
	local label = badge:FindFirstChildOfClass("TextLabel")
	if label then
		label.TextSize = 15
	end
end

-- optional rarity crest on the seam; once loaded it replaces the badge pill (never both)
local emblemArt = UIKit.make("ImageLabel", {
	Name = "EmblemArt",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, STAGE_H),
	Size = UDim2.fromOffset(50, 50),
	ZIndex = 4,
	Visible = false,
	Parent = panel,
}) :: ImageLabel

-- light sweep across the card on impact
local shine = UIKit.make(
	"Frame",
	{ Name = "Shine", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, Visible = false, ZIndex = 5, Parent = panel }
) :: Frame
local shineGrad = UIKit.make("UIGradient", {
	Rotation = 20,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.65),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = shine,
}) :: UIGradient

-- big banner on the card's top edge (Legendary/Secret)
local banner = UIKit.make("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.Panel,
	Visible = false,
	ZIndex = 6,
	Parent = holder,
}) :: Frame
UIStyle.corner(banner, UIStyle.Radius.Pill)
local bannerStroke = UIStyle.outline(banner, C.Gold, 2.5)
UIKit.padding(banner, 20, 0)
local bannerText = UIKit.text({
	Text = "",
	Role = "Title",
	TextSize = 22,
	AlignX = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	Truncate = false,
	Parent = banner,
})
local bannerScale = UIKit.make("UIScale", { Parent = banner }) :: UIScale
-- optional plate artwork behind the banner text; once loaded it replaces the plain pill
local bannerArt = UIKit.make("ImageLabel", {
	Name = "BannerArt",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(300, 45),
	ZIndex = 0,
	Visible = false,
	Parent = banner,
}) :: ImageLabel

-- Artwork state. The badge pill and the plain banner pill stay until their artwork has really
-- loaded, so a missing or moderated image never leaves a hole in the card.
local art: { [string]: string }? = nil
local badgeShown = false
local function syncArt()
	local hasCrest = art ~= nil and art.emblem ~= nil
	emblemArt.Visible = badgeShown and hasCrest
	badge.Visible = badgeShown and not (hasCrest and emblemArt.IsLoaded)
	local plate = art ~= nil and art.banner ~= nil and bannerArt.IsLoaded
	banner.BackgroundTransparency = if plate then 1 else 0
	bannerStroke.Transparency = if plate then 1 else 0
end
emblemArt:GetPropertyChangedSignal("IsLoaded"):Connect(syncArt)
bannerArt:GetPropertyChangedSignal("IsLoaded"):Connect(syncArt)
task.spawn(function()
	-- preloaded through ImageLabels: bare id strings are not fetched as images
	local holders = {}
	for _, id in RevealCardArt.all() do
		table.insert(holders, UIKit.make("ImageLabel", { Image = id }))
	end
	if #holders > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(holders)
		end)
		for _, h in holders do
			h:Destroy()
		end
	end
end)

-- pooled confetti (reused by every burst). Plain coloured pieces, no font glyph: "✦" has no glyph in the
-- V1 fonts and drew as black boxes (033 fix).
local sparkles: { Frame } = {}
for i = 1, SPARKLES do
	local s = Instance.new("Frame")
	s.Name = "Sparkle"
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Size = UDim2.fromOffset(12, 12)
	s.BorderSizePixel = 0
	s.ZIndex = 10
	s.Visible = false
	if i % 2 == 0 then
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = s
	end
	s.Parent = holder
	sparkles[i] = s
end

local hint = UIKit.text({
	Name = "Hint",
	Text = "Tap card to skip",
	Role = "Small",
	TextSize = 14,
	Color = C.TextMuted,
	AlignX = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 8),
	Size = UDim2.new(1, 0, 0, 20),
	Parent = holder,
})
hint.Visible = false
-- the whole card is the tap target (Epic and above only)
local tap = UIKit.make(
	"TextButton",
	{ Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Visible = false, Parent = holder }
) :: TextButton

UIKit.mount(fxGui)
UIKit.mount(gui)

local rng = Random.new()
local showCount = 0
local state = nil -- the reveal on screen: { token, worker, rarity, tier, color, started, revealed, revealedAt, closing }
local preview = nil
local tweens: { Tween } = {}
local function stopTweens()
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
end
local function tw(obj: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, repeats: number?, reverses: boolean?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, repeats or 0, reverses or false), goal)
	table.insert(tweens, t)
	t:Play()
	return t
end

-- The earnings count up through one tweened value (no loop).
local incomeValue = Instance.new("NumberValue")
incomeValue.Changed:Connect(function(value)
	incomeLabel.Text = "+" .. CashFormat.format(math.floor(value + 0.5)) .. "/s"
end)

local function setGlow(strength: number, time: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, repeats: number?, reverses: boolean?)
	for i, layer in halo do
		tw(layer, time, { BackgroundTransparency = 1 - strength * HALO[i] }, style, dir, repeats, reverses)
	end
end
local function setRays(transparency: number, time: number)
	for _, bar in rayBars do
		tw(bar, time, { BackgroundTransparency = transparency })
	end
end

local function resetFx(keepDim: boolean)
	for _, s in sparkles do
		s.Visible = false
	end
	for _, layer in halo do
		layer.BackgroundTransparency = 1
	end
	for _, bar in rayBars do
		bar.BackgroundTransparency = 1
	end
	wheel.Rotation = 0
	beam.Visible = false
	beam.BackgroundTransparency = 1
	ring.Visible = false
	shine.Visible = false
	banner.Visible = false
	hint.Visible = false
	flash.BackgroundTransparency = 1
	card.Position = CENTRE
	nameScale.Scale = 1
	incomeScale.Scale = 1
	if not keepDim then
		dim.BackgroundTransparency = 1
	end
end

local function burst(count: number, color: Color3)
	local n = math.min(count, #sparkles)
	for i = 1, n do
		local s = sparkles[i]
		local angle = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dist = rng:NextNumber(150, 260)
		s.Position = UDim2.new(0.5, 0, 0, STAGE_H * 0.5)
		s.BackgroundColor3 = if i % 3 == 0 then WHITE else color
		local size = rng:NextInteger(8, 16)
		s.Size = if i % 2 == 0 then UDim2.fromOffset(size, size) else UDim2.fromOffset(size, math.floor(size * 0.55))
		s.BackgroundTransparency = 0
		s.Rotation = rng:NextInteger(0, 90)
		s.Visible = true
		tw(s, rng:NextNumber(0.6, 1), {
			Position = UDim2.new(0.5, math.cos(angle) * dist, 0, STAGE_H * 0.5 + math.sin(angle) * dist),
			BackgroundTransparency = 1,
			Rotation = s.Rotation + rng:NextInteger(-180, 180),
		})
	end
end

local function close(token: number)
	local st = state
	if showCount ~= token or not st or st.closing then
		return
	end
	st.closing = true
	tap.Visible = false
	hint.Visible = false
	banner.Visible = false -- outside the card's scale, so hide it before the card shrinks
	ring.Visible = false
	beam.Visible = false
	setGlow(0, 0.18)
	setRays(1, 0.18)
	tw(dim, 0.25, { BackgroundTransparency = 1 })
	local out = TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	out.Completed:Once(function()
		if showCount == token then
			holder.Visible = false
			stopTweens()
			resetFx(false)
			if preview then
				preview.release()
				preview = nil
			end
		end
	end)
	out:Play()
end

-- Impact, then reward. Runs once per reveal: at the end of the build-up, at once for tiers with
-- no build-up, or early when the build-up is skipped.
local function impact(token: number)
	local st = state
	if showCount ~= token or not st or st.revealed or st.closing then
		return
	end
	st.revealed = true
	st.revealedAt = os.clock()
	local worker, rarity, tier, color = st.worker, st.rarity, st.tier, st.color
	local teased = tier.build > 0
	local function later(delay: number, fn: () -> ())
		task.delay(delay, function()
			if showCount == token and not st.closing then
				fn()
			end
		end)
	end

	-- the worker is shown
	card.Position = CENTRE
	nameLabel.Text = worker.name
	badgeShown = true
	syncArt()
	-- with a crest instead of the badge pill, the rarity is still named in words
	local named = tier.banner or string.find(tier.eyebrow, string.upper(rarity), 1, true) ~= nil
	eyebrow.Text = if art and art.emblem and not named then string.upper(rarity) .. "  ·  " .. tier.eyebrow else tier.eyebrow
	eyebrow.TextColor3 = if tier.banner then color else C.Gold
	if preview then
		preview.tint(WHITE)
	end
	if st.sound then
		-- this zone's own effect has been playing since the build-up began; on a skip, jump to its hit
		if os.clock() - st.started < tier.build - 0.08 then
			st.sound.TimePosition = st.soundHit
		end
	else
		UIKit.sound(tier.sound, worker.zone)
	end

	if rarity == "Common" then
		-- complete at once: fast and out of the way
		secondary.Text = worker.role
		incomeLabel.Text = "+" .. CashFormat.format(worker.income) .. "/s"
		pop.Scale = tier.size * 0.8
		tw(pop, 0.16, { Scale = tier.size }, Enum.EasingStyle.Back)
		task.delay(tier.hold, close, token)
		return
	end

	-- impact
	secondary.Text = if WorkerCatalogue.SHOW_BATTLE_STATS
		then ("%s  ·  ATK %d  ·  SPD %d  ·  DEF %d"):format(worker.role, worker.attack, worker.speed, worker.defence)
		else ("%s  ·  +%s/s"):format(worker.role, CashFormat.format(worker.income))
	incomeLabel.Text = ""
	if teased then
		pop.Scale = tier.size * 1.12
		tw(pop, 0.28, { Scale = tier.size }, Enum.EasingStyle.Back)
	else
		pop.Scale = tier.size * 0.7
		card.Position = UDim2.new(0.5, 0, 0.5, 40)
		tw(pop, 0.26, { Scale = tier.size }, Enum.EasingStyle.Back)
		tw(card, 0.26, { Position = CENTRE })
	end
	nameScale.Scale = 0.6
	tw(nameScale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
	if tier.ring then
		ringStroke.Color = color
		ringStroke.Transparency = 0
		ring.Size = UDim2.fromOffset(60, 60)
		ring.Visible = true
		tw(ring, 0.55, { Size = UDim2.fromOffset(W * 1.9, W * 1.9) })
		tw(ringStroke, 0.55, { Transparency = 1 })
	end
	if tier.shine then
		shine.BackgroundColor3 = color:Lerp(WHITE, 0.6)
		shineGrad.Offset = Vector2.new(-1, 0)
		shine.Visible = true
		tw(shineGrad, 0.6, { Offset = Vector2.new(1, 0) })
	end
	if tier.glow then
		for i, layer in halo do
			layer.BackgroundTransparency = 1 - tier.glow * HALO[i]
		end
		setGlow(tier.glow * 0.55, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true) -- slow breathing
	end
	if tier.sparkles then
		burst(tier.sparkles, color)
		for wave = 2, tier.waves or 1 do
			later(0.4 * (wave - 1), function()
				burst(tier.sparkles, color)
			end)
		end
	end
	if tier.flash then
		flash.BackgroundColor3 = color:Lerp(WHITE, 0.6)
		flash.BackgroundTransparency = tier.flash -- one soft flash, never full white
		tw(flash, 0.4, { BackgroundTransparency = 1 })
	end
	if tier.rays then
		setRays(0.1, 0.3)
		tw(wheel, tier.hold + 1, { Rotation = wheel.Rotation + 70 }, Enum.EasingStyle.Linear)
	end
	if tier.beam then
		beam.Visible = true
		tw(beam, 0.4, { Size = UDim2.fromOffset(W * 1.5, H * 2.4), BackgroundTransparency = 0.5 })
	end
	if tier.banner then
		bannerScale.Scale = 0.3
		banner.Position = UDim2.new(0.5, 0, 0, -36)
		banner.Visible = true
		tw(bannerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		tw(banner, 0.3, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Back)
	end
	if tier.dimAfter then
		tw(dim, 0.4, { BackgroundTransparency = tier.dimAfter })
	end

	-- reward: the earnings land a beat after the worker
	later(0.22, function()
		incomeScale.Scale = 0.5
		tw(incomeScale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		if tier.countUp then
			incomeValue.Value = 0
			incomeLabel.Text = "+" .. CashFormat.format(0) .. "/s"
			tw(incomeValue, 0.5, { Value = worker.income })
		else
			incomeLabel.Text = "+" .. CashFormat.format(worker.income) .. "/s"
		end
	end)
	if tier.tap then
		hint.Text = "Tap card to close"
		hint.Visible = true
	end
	task.delay(tier.hold, close, token)
end

local function show(workerId: string)
	local worker = WorkerCatalogue.get(workerId)
	if not worker then
		return
	end
	showCount += 1
	local token = showCount
	local rarity = worker.rarity
	local tier = TIER[rarity] or TIER.Common
	local color = UIStyle.Rarity[rarity] or C.Text
	stopTweens()
	resetFx(tier.dim ~= nil)
	if state and state.sound then
		state.sound:Stop() -- a long reveal effect must not run on under the next card
	end
	local st = {
		token = token,
		worker = worker,
		rarity = rarity,
		tier = tier,
		color = color,
		started = os.clock(),
		revealed = false,
		revealedAt = 0,
		closing = false,
		sound = nil :: Sound?,
		soundHit = 0,
	}
	state = st

	-- zone artwork, if this worker's zone (or the worker itself) has any
	art = RevealCardArt.get(workerId, worker.zone, rarity)
	for layer, label in { backdrop = backdropArt, frame = frameArt, emblem = emblemArt, banner = bannerArt } do
		local id = art and art[layer]
		label.Image = id or ""
		label.Visible = id ~= nil
	end
	secondary.TextColor3 = if art and art.frame then C.Text else C.TextMuted -- the frame has a plate behind the stats
	secondary.Font = if art and art.frame then UIStyle.FontBold else UIStyle.FontBody
	task.delay(0.5, syncArt)

	-- colours for this rarity
	rarityTag.set(rarity)
	stroke.Color = color:Lerp(C.Panel, if rarity == "Common" then 0.6 else 0.15)
	backdrop.Color = ColorSequence.new(color:Lerp(C.PanelDark, if rarity == "Common" then 0.8 elseif tier.banner then 0.4 else 0.55), C.PanelDark)
	local glyph = UIStyle.RarityGlyph[rarity] or ""
	bannerText.Text = if art and art.banner then string.upper(rarity) else glyph .. "  " .. string.upper(rarity) .. "  " .. glyph -- the plate has its own ornaments
	bannerText.TextColor3 = color
	bannerStroke.Color = color
	beam.BackgroundColor3 = color:Lerp(WHITE, 0.5)
	for _, layer in halo do
		layer.BackgroundColor3 = color
	end
	for _, bar in rayBars do
		bar.BackgroundColor3 = color:Lerp(WHITE, 0.35)
	end

	if preview then
		preview.set(workerId)
	else
		preview = WorkerPreview.mount(modelHolder, workerId, { rotate = true, yaw = 180 })
	end
	holder.Visible = true
	tap.Visible = tier.tap == true

	if tier.build <= 0 then
		impact(token)
		return
	end

	-- anticipation: a silhouette of the worker with every detail hidden
	local function during(delay: number, fn: () -> ())
		task.delay(delay, function()
			if showCount == token and not st.revealed and not st.closing then
				fn()
			end
		end)
	end
	preview.tint(BLACK)
	nameLabel.Text = "? ? ?"
	incomeLabel.Text = ""
	secondary.Text = ""
	badgeShown = false
	syncArt()
	eyebrow.Text = tier.tease
	eyebrow.TextColor3 = C.TextMuted
	pop.Scale = tier.size * 0.7
	tw(pop, 0.25, { Scale = tier.size * 0.96 }, Enum.EasingStyle.Back)
	setGlow(tier.glow * 0.8, tier.build, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw(dim, 0.3, { BackgroundTransparency = tier.dim })
	local own = UIKit.customSound(tier.sound, worker.zone)
	if own and own.hit then
		-- our zones: one effect carries the build-up and the reveal; start it so its hit lands on the impact
		st.soundHit = own.hit
		st.sound = UIKit.sound(tier.sound, worker.zone, math.max(0, own.hit - tier.build))
	else
		UIKit.sound("build")
	end

	if tier.beam then
		-- Secret: a beam of light widens behind a slow heartbeat
		beam.Size = UDim2.fromOffset(30, H * 2.4)
		beam.BackgroundTransparency = 0.7
		beam.Visible = true
		tw(beam, tier.build, { Size = UDim2.fromOffset(W * 0.9, H * 2.4), BackgroundTransparency = 0.55 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		setRays(0.75, tier.build)
		tw(wheel, tier.build, { Rotation = 25 }, Enum.EasingStyle.Linear)
		during(0.3, function()
			tw(pop, 0.28, { Scale = tier.size * 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		end)
	elseif tier.rays then
		-- Legendary: sun rays fade in while the card swells
		setRays(0.6, tier.build)
		tw(wheel, tier.build, { Rotation = 25 }, Enum.EasingStyle.Linear)
		during(0.27, function()
			tw(pop, tier.build - 0.27, { Scale = tier.size * 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end)
	else
		-- Epic: a short, gentle bob
		during(0.27, function()
			tw(card, 0.08, { Position = UDim2.new(0.5, 0, 0.5, -6) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true)
		end)
	end
	if tier.build > SKIP_AFTER + 0.4 then -- no point flashing the hint just before the reveal
		during(SKIP_AFTER, function()
			hint.Text = "Tap card to skip"
			hint.Visible = true
		end)
	end
	during(tier.build, function()
		stopTweens()
		impact(token)
	end)
end

tap.Activated:Connect(function()
	local st = state
	if not st or st.closing or not holder.Visible then
		return
	end
	if not st.revealed then
		if os.clock() - st.started >= SKIP_AFTER then
			stopTweens()
			impact(st.token)
		end
	elseif os.clock() - st.revealedAt >= 0.4 then
		close(st.token)
	end
end)

revealEvent.OnClientEvent:Connect(show)

-- Studio-only review helper: an "FX" button that previews each rarity's reveal and the steal /
-- place / refusal feedback. Nothing here exists in live servers, and it only plays local visuals.
-- (Not with the V1 look: its button sat on the right-hand HUD column; Low effects is in Settings.)
if RunService:IsStudio() and not UIStyle.v1 then
	local ids: { [string]: string } = {}
	local function scan(list: any, depth: number)
		for key, w in list do
			if type(w) == "table" then
				local id = if type(w.id) == "string" then w.id elseif type(key) == "string" then key else nil
				if id and type(w.rarity) == "string" and WorkerCatalogue.get(id) then
					ids[w.rarity] = ids[w.rarity] or id
				elseif depth < 2 then
					scan(w, depth + 1)
				end
			end
		end
	end
	scan(WorkerCatalogue.WORKERS, 0)

	local devPanel = UIKit.make("Frame", {
		Name = "DevFxPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -64, 0.5, 0),
		Size = UDim2.fromOffset(132, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}) :: Frame
	UIKit.list(devPanel, Enum.FillDirection.Vertical, 4)
	local order = 0
	local function add(label: string, fn: () -> ())
		order += 1
		UIKit.button({
			Name = "Dev_" .. label,
			Kind = "Secondary",
			Text = label,
			TextSize = 13,
			Size = UDim2.fromOffset(132, UIStyle.TouchTarget),
			LayoutOrder = order,
			Parent = devPanel,
			OnActivated = fn,
		})
	end
	-- which zone's workers (and so which artwork) the rarity buttons preview
	local PREVIEW_ZONES = { { id = "MainStreet", label = "Knight's Keep" }, { id = "BillionaireHills", label = "Ember Academy" }, { id = "", label = "Plain card" } }
	local zoneIndex = 1
	local function pick(rarity: string): string?
		for _, id in WorkerCatalogue.ZONES[PREVIEW_ZONES[zoneIndex].id] or {} do
			local w = WorkerCatalogue.get(id)
			if w and w.rarity == rarity then
				return id
			end
		end
		-- "Plain card": any worker of that rarity from a zone without artwork
		for id, w in WorkerCatalogue.WORKERS do
			if w.rarity == rarity and not RevealCardArt.get(id, w.zone, rarity) then
				return id
			end
		end
		return ids[rarity]
	end
	order += 1
	local zoneCtl -- assigned below; the click handler needs it as an upvalue
	local _, ctl = UIKit.button({
		Name = "Dev_Zone",
		Kind = "Primary",
		Text = PREVIEW_ZONES[1].label,
		TextSize = 13,
		Size = UDim2.fromOffset(132, UIStyle.TouchTarget),
		LayoutOrder = order,
		Parent = devPanel,
		OnActivated = function()
			zoneIndex = zoneIndex % #PREVIEW_ZONES + 1
			zoneCtl.setText(PREVIEW_ZONES[zoneIndex].label)
		end,
	})
	zoneCtl = ctl
	for _, rarity in WorkerCatalogue.RARITIES do
		add(rarity, function()
			local id = pick(rarity)
			if id then
				show(id)
			end
		end)
	end
	add("Steal pop", function()
		UIKit.Signals.DebugFx:Fire("steal")
	end)
	add("Place pop", function()
		UIKit.Signals.DebugFx:Fire("place")
	end)
	add("Refusal", function()
		UIKit.Signals.DebugFx:Fire("refuse")
	end)
	UIKit.button({
		Name = "DevFxToggle",
		Kind = "Ghost",
		Text = "FX",
		Size = UDim2.fromOffset(UIStyle.TouchTarget, UIStyle.TouchTarget),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Parent = root,
		OnActivated = function()
			devPanel.Visible = not devPanel.Visible
		end,
	})
end
