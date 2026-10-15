-- Studio location: ReplicatedStorage.CreatureSpecs (ModuleScript)
-- CreatureSpecs  (Milestone 035)
-- The ONE design sheet for every creature: colours, props (the twist), idle motion and aura. Read by
-- ServerScriptService.CreatureBuilder, which builds ReplicatedStorage.CreatureModels (the single source every
-- place clones: wander, carry, pad, parade reveal, Index, reveal card, inventory). Ids, rarities, odds and income
-- live in WorkerCatalogue and are never set here; this file only says how a creature looks.
--
-- Body = the classic Roblox NOOB on the R15 MysteryNPC rig (owner LOOK RULE): yellow head + smile face, smooth solid-colour
-- block torso/arms/legs (the R15 parts become plain blocks), no hair, no skin tones; `skin` is ignored for noobs. Variety =
-- outfit colours, hat, twist. Non-humanoids set `own = true` (or `hideBody`) and keep their own recoloured shape. A prop is a part (or a Blender mesh master from
-- ServerStorage.Imports035) welded to a body part, in that part's own space (+X right, +Y up, -Z forward).
--   anim  = idle motion of the prop, played on the client near the player (CreatureClient):
--     swing  rotate about `axis` by +-amp degrees (around `pivot`, body-part space)
--     push   slide along `axis` by +-amp studs        bob  slide up and down by amp studs
--     spin   turn about `axis` at amp degrees/second   pulse  grow and shrink by amp (fraction)
--   fx    = a particle emitter on a body part (kind: spark flame smoke bubble puff), `aura = true` for the rarity aura
--   scale = body scale (big creatures); pads cap it at 1.6 and shoulders at 1.3 (CreatureScaler)

local CreatureSpecs = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local cf = CFrame.new
local rad = math.rad

export type Prop = {
	n: string?,
	on: string,
	shape: string?, -- Block Ball Cylinder (stands up) Disc (faces forward) Wedge; default Block
	size: Vector3,
	at: CFrame,
	color: Color3,
	mat: Enum.Material?,
	neon: boolean?,
	trans: number?, -- Transparency
	mesh: string?, -- Imports035 master; size = the stud size it is scaled to
	model: string?, -- Imports035 model (all its mesh parts); fit = { axis, size } scales it, colors / partAnim per mesh part
	fit: { axis: string, size: number }?,
	colors: { [string]: any }?,
	partAnim: { [string]: any }?,
	anim: { kind: string, axis: string?, amp: number, speed: number?, phase: number?, pivot: CFrame? }?,
}

export type Fx = { on: string, kind: string, color: Color3, rate: number?, at: Vector3?, size: number?, aura: boolean? }

export type Spec = {
	scale: number?,
	skin: Color3,
	outfit: { [string]: Color3 }?,
	props: { Prop },
	fx: { Fx }?,
	light: Color3?,
	own: boolean?, -- non-humanoid (fish, owl, snail, newt, golem): keeps the recoloured R15 body instead of the noob
	face: string?, -- humanoids: catalogue face image ("rbxassetid://..."); nil = the default part-built smile
	hideBody: boolean?, -- hide the R15 body (props make the whole creature)
	halo: Color3?, -- spinning ring on the ground
	sound: string?,
}

-- Outfit colours by body region (anything not listed shows skin).
local function outfit(o: { top: Color3?, waist: Color3?, arms: Color3?, hands: Color3?, legs: Color3?, feet: Color3? }): { [string]: Color3 }
	local c = {}
	local function both(name: string, color: Color3?)
		if color then
			c["Left" .. name], c["Right" .. name] = color, color
		end
	end
	c.UpperTorso, c.LowerTorso = o.top, o.waist or o.top
	both("UpperArm", o.arms)
	both("LowerArm", o.arms)
	both("Hand", o.hands or o.arms)
	both("UpperLeg", o.legs)
	both("LowerLeg", o.legs)
	both("Foot", o.feet or o.legs)
	return c
end

local STEEL, STEEL_D, GOLD, WOOD, LEATHER = rgb(170, 178, 192), rgb(86, 92, 108), rgb(255, 196, 40), rgb(120, 78, 40), rgb(96, 62, 36)
local SKIN, SKIN_D = rgb(255, 214, 170), rgb(214, 168, 124)
local METAL = Enum.Material.Metal

-- ================================ KNIGHT'S KEEP ================================
CreatureSpecs.broke_bob = { -- Rookie Squire (C): helmet too big, he keeps pushing it up
	skin = SKIN,
	outfit = outfit({ top = rgb(150, 154, 166), waist = rgb(110, 80, 50), arms = rgb(150, 154, 166), legs = rgb(110, 80, 50), feet = rgb(70, 50, 34) }),
	props = {
		{
			n = "Helmet",
			on = "Head",
			shape = "Ball",
			size = v3(1.6, 1.3, 1.6),
			at = cf(0, 0.36, 0.04),
			color = STEEL,
			mat = METAL,
			anim = { kind = "swing", axis = "X", amp = 9, speed = 1.6, pivot = cf(0, 0.2, 0.6) },
		},
		{
			n = "HelmetRim",
			on = "Head",
			shape = "Cylinder",
			size = v3(1.66, 0.14, 1.66),
			at = cf(0, 0.0, 0.04),
			color = STEEL_D,
			mat = METAL,
			anim = { kind = "swing", axis = "X", amp = 9, speed = 1.6, pivot = cf(0, 0.2, 0.6) },
		},
		{
			n = "SwordBlade",
			on = "RightHand",
			size = v3(0.18, 0.1, 2.0),
			at = cf(0, -0.25, -1.2),
			color = rgb(200, 160, 100),
			mat = Enum.Material.Wood,
			anim = { kind = "swing", axis = "X", amp = 28, speed = 2.2 },
		},
		{ n = "SwordGuard", on = "RightHand", size = v3(0.8, 0.14, 0.16), at = cf(0, -0.25, -0.2), color = WOOD, anim = { kind = "swing", axis = "X", amp = 28, speed = 2.2 } },
		{ n = "BeltBuckle", on = "LowerTorso", size = v3(0.4, 0.3, 0.1), at = cf(0, 0.1, -0.52), color = GOLD, mat = METAL },
	},
}

local SCROLL_WOBBLE = { kind = "swing", axis = "X", amp = 10, speed = 2.0, pivot = cf(0, -0.5, -0.6) }
CreatureSpecs.delivery_dave = { -- Scroll Page (C): a long scroll he unrolls
	skin = SKIN,
	outfit = outfit({ top = rgb(70, 160, 90), waist = rgb(60, 50, 40), arms = rgb(70, 160, 90), legs = rgb(190, 160, 110), feet = rgb(90, 60, 40) }),
	props = {
		{ n = "PageCap", on = "Head", size = v3(1.45, 0.5, 1.45), at = cf(0, 0.55, 0), color = rgb(60, 90, 190) },
		{
			n = "CapFeather",
			on = "Head",
			size = v3(0.12, 0.8, 0.3),
			at = cf(0.5, 0.95, 0.1) * CFrame.Angles(0, 0, rad(-20)),
			color = rgb(250, 240, 220),
			anim = { kind = "swing", axis = "Z", amp = 8, speed = 2.4 },
		},
		-- a rolled parchment held out in front: cream tube, brown end caps, red ribbon (not a blade)
		{
			n = "ScrollRoll",
			on = "LeftHand",
			shape = "Cylinder",
			size = v3(0.8, 1.7, 0.8),
			at = cf(0, -0.5, -0.6) * CFrame.Angles(0, 0, rad(90)),
			color = rgb(250, 238, 200),
			anim = SCROLL_WOBBLE,
		},
		{
			n = "ScrollCapL",
			on = "LeftHand",
			shape = "Cylinder",
			size = v3(0.95, 0.16, 0.95),
			at = cf(0, -0.5, -0.6) * CFrame.Angles(0, 0, rad(90)) * cf(0, 0.9, 0),
			color = rgb(120, 78, 40),
			anim = SCROLL_WOBBLE,
		},
		{
			n = "ScrollCapR",
			on = "LeftHand",
			shape = "Cylinder",
			size = v3(0.95, 0.16, 0.95),
			at = cf(0, -0.5, -0.6) * CFrame.Angles(0, 0, rad(90)) * cf(0, -0.9, 0),
			color = rgb(120, 78, 40),
			anim = SCROLL_WOBBLE,
		},
		{
			n = "ScrollRibbon",
			on = "LeftHand",
			shape = "Cylinder",
			size = v3(0.88, 0.14, 0.88),
			at = cf(0, -0.5, -0.6) * CFrame.Angles(0, 0, rad(90)),
			color = rgb(190, 40, 40),
			anim = SCROLL_WOBBLE,
		},
	},
}

CreatureSpecs.training_dummy = { -- Training Dummy (C): straw scarecrow with a target and wobbling arrows
	skin = rgb(224, 190, 120),
	outfit = outfit({ top = rgb(200, 168, 108), waist = rgb(170, 140, 90), arms = rgb(200, 168, 108), legs = rgb(170, 140, 90), feet = rgb(110, 80, 50) }),
	props = {
		{ n = "CrossBar", on = "UpperTorso", size = v3(3.4, 0.35, 0.35), at = cf(0, 0.5, 0.52), color = WOOD },
		{ n = "TargetRed", on = "UpperTorso", shape = "Disc", size = v3(1.5, 1.5, 0.1), at = cf(0, 0.1, -0.6), color = rgb(210, 50, 50) },
		{ n = "TargetWhite", on = "UpperTorso", shape = "Disc", size = v3(0.95, 0.95, 0.12), at = cf(0, 0.1, -0.62), color = rgb(250, 250, 250) },
		{ n = "TargetEye", on = "UpperTorso", shape = "Disc", size = v3(0.4, 0.4, 0.14), at = cf(0, 0.1, -0.64), color = rgb(210, 50, 50) },
		{
			n = "ArrowA",
			on = "UpperTorso",
			size = v3(0.1, 0.1, 1.3),
			at = cf(0.5, 0.45, -0.95),
			color = rgb(150, 110, 60),
			anim = { kind = "swing", axis = "Y", amp = 10, speed = 3.2, pivot = cf(0.5, 0.45, -0.5) },
		},
		{
			n = "ArrowB",
			on = "UpperTorso",
			size = v3(0.1, 0.1, 1.1),
			at = cf(-0.55, -0.2, -0.9),
			color = rgb(150, 110, 60),
			anim = { kind = "swing", axis = "X", amp = 12, speed = 2.7, phase = 1.3, pivot = cf(-0.55, -0.2, -0.5) },
		},
		{ n = "SackHat", on = "Head", size = v3(1.3, 0.35, 1.3), at = cf(0, 0.55, 0), color = rgb(140, 100, 60) },
		{ n = "SackHatTop", on = "Head", size = v3(0.8, 0.6, 0.8), at = cf(0, 0.95, 0), color = rgb(140, 100, 60) },
	},
}

CreatureSpecs.street_hustler = { -- Apple Archer (R): apple on his head, bow and quiver
	skin = SKIN,
	outfit = outfit({ top = rgb(52, 120, 70), waist = rgb(96, 62, 36), arms = rgb(52, 120, 70), legs = rgb(90, 74, 50), feet = rgb(60, 42, 28) }),
	props = {
		{ n = "Hood", on = "Head", size = v3(1.45, 0.5, 1.45), at = cf(0, 0.5, 0.05), color = rgb(40, 100, 56) },
		{ n = "HoodBack", on = "Head", size = v3(1.3, 1.1, 0.3), at = cf(0, -0.05, 0.62), color = rgb(40, 100, 56) },
		{ n = "Apple", on = "Head", shape = "Ball", size = v3(0.75, 0.75, 0.75), at = cf(0, 1.05, 0), color = rgb(220, 40, 40), anim = { kind = "bob", amp = 0.12, speed = 2.6 } },
		{ n = "AppleLeaf", on = "Head", size = v3(0.3, 0.06, 0.16), at = cf(0.12, 1.5, 0), color = rgb(60, 170, 70), anim = { kind = "bob", amp = 0.12, speed = 2.6 } },
		{ n = "Quiver", on = "UpperTorso", shape = "Cylinder", size = v3(0.55, 1.6, 0.55), at = cf(-0.3, 0.2, 0.68) * CFrame.Angles(0, 0, rad(-14)), color = LEATHER },
		{ n = "QuiverArrows", on = "UpperTorso", size = v3(0.35, 0.5, 0.2), at = cf(-0.45, 1.1, 0.68), color = rgb(240, 230, 200) },
		{ n = "BowMid", on = "LeftHand", size = v3(0.16, 1.0, 0.16), at = cf(0, -0.1, -0.7), color = WOOD },
		{ n = "BowTop", on = "LeftHand", size = v3(0.13, 0.9, 0.13), at = cf(0, 0.8, -0.55) * CFrame.Angles(rad(-22), 0, 0), color = WOOD },
		{ n = "BowBottom", on = "LeftHand", size = v3(0.13, 0.9, 0.13), at = cf(0, -1.0, -0.55) * CFrame.Angles(rad(22), 0, 0), color = WOOD },
		{
			n = "BowString",
			on = "LeftHand",
			size = v3(0.04, 2.3, 0.04),
			at = cf(0, -0.1, -0.35),
			color = rgb(240, 240, 235),
			anim = { kind = "push", axis = "Z", amp = 0.28, speed = 2.6 },
		},
	},
}

CreatureSpecs.business_betty = { -- Banner Bearer (R): a huge waving flag
	skin = SKIN_D,
	outfit = outfit({ top = rgb(200, 44, 52), waist = rgb(240, 200, 60), arms = rgb(240, 236, 226), legs = rgb(60, 60, 90), feet = rgb(70, 50, 40) }),
	props = {
		{ n = "Circlet", on = "Head", shape = "Cylinder", size = v3(1.3, 0.14, 1.3), at = cf(0, 0.5, 0), color = GOLD, mat = METAL },
		{ n = "Pole", on = "RightHand", shape = "Cylinder", size = v3(0.2, 5.4, 0.2), at = cf(0, 1.9, -0.35), color = WOOD },
		{ n = "PoleTip", on = "RightHand", shape = "Ball", size = v3(0.45, 0.45, 0.45), at = cf(0, 4.7, -0.35), color = GOLD, mat = METAL },
		{
			n = "FlagA",
			on = "RightHand",
			size = v3(1.2, 1.6, 0.08),
			at = cf(0.7, 3.8, -0.35),
			color = rgb(200, 44, 52),
			anim = { kind = "swing", axis = "Y", amp = 14, speed = 3.0, pivot = cf(0.1, 3.8, -0.35) },
		},
		{
			n = "FlagB",
			on = "RightHand",
			size = v3(1.1, 1.4, 0.08),
			at = cf(1.85, 3.8, -0.35),
			color = rgb(230, 70, 70),
			anim = { kind = "swing", axis = "Y", amp = 22, speed = 3.0, phase = 1.1, pivot = cf(1.3, 3.8, -0.35) },
		},
		{
			n = "FlagStar",
			on = "RightHand",
			shape = "Disc",
			size = v3(0.7, 0.7, 0.1),
			at = cf(0.7, 3.8, -0.4),
			color = GOLD,
			anim = { kind = "swing", axis = "Y", amp = 14, speed = 3.0, pivot = cf(0.1, 3.8, -0.35) },
		},
	},
}

CreatureSpecs.security_sam = { -- Shield Knight (E): steel plate and a big tower shield
	skin = SKIN,
	outfit = outfit({ top = STEEL, waist = STEEL_D, arms = STEEL, legs = STEEL_D, feet = STEEL }),
	props = {
		{ n = "Helm", on = "Head", shape = "Cylinder", size = v3(1.45, 1.3, 1.45), at = cf(0, 0.12, 0), color = STEEL, mat = METAL },
		{ n = "HelmTop", on = "Head", shape = "Ball", size = v3(1.45, 1.0, 1.45), at = cf(0, 0.6, 0), color = STEEL, mat = METAL },
		{ n = "Visor", on = "Head", size = v3(1.0, 0.14, 0.1), at = cf(0, 0.1, -0.68), color = rgb(20, 24, 40) },
		{ n = "Crest", on = "Head", size = v3(0.2, 0.55, 1.1), at = cf(0, 1.2, 0), color = rgb(40, 110, 230) },
		{ n = "PauldronL", on = "LeftUpperArm", shape = "Ball", size = v3(1.2, 0.85, 1.2), at = cf(0, 0.4, 0), color = STEEL, mat = METAL },
		{ n = "PauldronR", on = "RightUpperArm", shape = "Ball", size = v3(1.2, 0.85, 1.2), at = cf(0, 0.4, 0), color = STEEL, mat = METAL },
		{ n = "ChestPlate", on = "UpperTorso", size = v3(2.15, 1.5, 1.25), at = cf(0, 0.05, 0), color = STEEL, mat = METAL },
		{ n = "ChestStripe", on = "UpperTorso", size = v3(0.4, 1.5, 0.12), at = cf(0, 0.05, -0.66), color = rgb(40, 110, 230) },
		{
			n = "ShieldBorder",
			on = "LeftLowerArm",
			size = v3(2.5, 3.3, 0.18),
			at = cf(-0.5, 0.4, -1.1),
			color = GOLD,
			mat = METAL,
			anim = { kind = "push", axis = "Z", amp = 0.6, speed = 1.8 },
		},
		{
			n = "Shield",
			on = "LeftLowerArm",
			size = v3(2.2, 3.0, 0.25),
			at = cf(-0.5, 0.4, -1.15),
			color = rgb(40, 110, 230),
			anim = { kind = "push", axis = "Z", amp = 0.6, speed = 1.8 },
		},
		{
			n = "ShieldBoss",
			on = "LeftLowerArm",
			shape = "Ball",
			size = v3(0.7, 0.7, 0.45),
			at = cf(-0.5, 0.4, -1.35),
			color = GOLD,
			mat = METAL,
			anim = { kind = "push", axis = "Z", amp = 0.6, speed = 1.8 },
		},
		{ n = "Sword", on = "RightHand", size = v3(0.2, 0.1, 2.4), at = cf(0, -0.25, -1.4), color = rgb(225, 232, 240), mat = METAL },
		{ n = "SwordGuard", on = "RightHand", size = v3(0.9, 0.16, 0.18), at = cf(0, -0.25, -0.2), color = GOLD },
	},
	fx = { { on = "UpperTorso", kind = "spark", color = rgb(110, 180, 255), rate = 3, aura = true } },
	light = rgb(110, 170, 255),
}

CreatureSpecs.crypto_carl = { -- Forge Master (E): glowing hammer, sparks
	skin = rgb(214, 160, 120),
	outfit = outfit({ top = rgb(70, 56, 52), waist = rgb(60, 40, 28), arms = rgb(214, 160, 120), legs = rgb(50, 44, 48), feet = rgb(40, 30, 28) }),
	props = {
		{ n = "Goggles", on = "Head", size = v3(1.3, 0.32, 0.12), at = cf(0, 0.38, -0.62), color = rgb(60, 40, 28) },
		{ n = "LensL", on = "Head", shape = "Disc", size = v3(0.34, 0.34, 0.1), at = cf(-0.3, 0.38, -0.68), color = rgb(255, 170, 60), neon = true },
		{ n = "LensR", on = "Head", shape = "Disc", size = v3(0.34, 0.34, 0.1), at = cf(0.3, 0.38, -0.68), color = rgb(255, 170, 60), neon = true },
		{ n = "Apron", on = "UpperTorso", size = v3(1.7, 1.9, 0.2), at = cf(0, -0.3, -0.62), color = LEATHER },
		{ n = "ApronPocket", on = "LowerTorso", size = v3(1.0, 0.5, 0.12), at = cf(0, -0.1, -0.56), color = rgb(120, 80, 48) },
		{ n = "Beard", on = "Head", size = v3(1.1, 0.6, 0.3), at = cf(0, -0.45, -0.5), color = rgb(90, 50, 30) },
		{
			n = "HammerHandle",
			on = "RightHand",
			shape = "Cylinder",
			size = v3(0.26, 2.6, 0.26),
			at = cf(0, 0.6, -0.3),
			color = WOOD,
			anim = { kind = "swing", axis = "X", amp = 55, speed = 2.3 },
		},
		{
			n = "HammerHead",
			on = "RightHand",
			size = v3(1.5, 0.95, 0.95),
			at = cf(0, 2.0, -0.3),
			color = rgb(50, 52, 62),
			mat = METAL,
			anim = { kind = "swing", axis = "X", amp = 55, speed = 2.3 },
		},
		{
			n = "HammerGlow",
			on = "RightHand",
			size = v3(1.56, 0.5, 1.0),
			at = cf(0, 2.0, -0.3),
			color = rgb(255, 120, 30),
			neon = true,
			anim = { kind = "swing", axis = "X", amp = 55, speed = 2.3 },
		},
	},
	fx = { { on = "RightHand", kind = "spark", color = rgb(255, 150, 50), rate = 5, at = v3(0, 2.0, -0.3), aura = true } },
	light = rgb(255, 140, 50),
}

CreatureSpecs.ceo_chad = { -- Golden Paladin (L): Ironclad's champion, gold plate and a glowing sword
	scale = 1.25,
	skin = SKIN,
	outfit = outfit({ top = GOLD, waist = rgb(220, 160, 30), arms = GOLD, legs = rgb(230, 170, 36), feet = GOLD }),
	props = {
		{ n = "Helm", on = "Head", shape = "Cylinder", size = v3(1.5, 1.35, 1.5), at = cf(0, 0.12, 0), color = GOLD, mat = METAL },
		{ n = "HelmTop", on = "Head", shape = "Ball", size = v3(1.5, 1.1, 1.5), at = cf(0, 0.62, 0), color = GOLD, mat = METAL },
		{ n = "Visor", on = "Head", size = v3(1.05, 0.14, 0.1), at = cf(0, 0.1, -0.7), color = rgb(30, 26, 20) },
		{ n = "Plume", on = "Head", size = v3(0.25, 0.9, 1.3), at = cf(0, 1.3, 0.1), color = rgb(220, 40, 50), anim = { kind = "swing", axis = "X", amp = 8, speed = 2.2 } },
		{ n = "PauldronL", on = "LeftUpperArm", shape = "Ball", size = v3(1.45, 1.0, 1.45), at = cf(0, 0.4, 0), color = GOLD, mat = METAL },
		{ n = "PauldronR", on = "RightUpperArm", shape = "Ball", size = v3(1.45, 1.0, 1.45), at = cf(0, 0.4, 0), color = GOLD, mat = METAL },
		{ n = "ChestPlate", on = "UpperTorso", size = v3(2.2, 1.55, 1.3), at = cf(0, 0.05, 0), color = GOLD, mat = METAL },
		{ n = "Emblem", on = "UpperTorso", shape = "Disc", size = v3(0.8, 0.8, 0.1), at = cf(0, 0.1, -0.68), color = rgb(220, 40, 50) },
		{
			n = "Cape",
			on = "UpperTorso",
			size = v3(2.0, 3.4, 0.1),
			at = cf(0, -0.9, 0.7),
			color = rgb(200, 36, 48),
			anim = { kind = "swing", axis = "X", amp = 7, speed = 1.9, pivot = cf(0, 0.8, 0.7) },
		},
		{
			n = "Blade",
			on = "RightHand",
			size = v3(0.3, 0.12, 3.0),
			at = cf(0, -0.25, -1.7),
			color = rgb(255, 240, 170),
			neon = true,
			anim = { kind = "swing", axis = "X", amp = 45, speed = 1.7 },
		},
		{
			n = "BladeGuard",
			on = "RightHand",
			size = v3(1.1, 0.18, 0.2),
			at = cf(0, -0.25, -0.25),
			color = GOLD,
			mat = METAL,
			anim = { kind = "swing", axis = "X", amp = 45, speed = 1.7 },
		},
	},
	fx = { { on = "UpperTorso", kind = "spark", color = rgb(255, 220, 90), rate = 7, aura = true } },
	light = rgb(255, 210, 90),
	halo = rgb(255, 210, 90),
}

CreatureSpecs.mystery_millionaire = { -- Sir Ironclad (S): the boss, giant dark iron knight
	scale = 2.2,
	skin = rgb(200, 170, 140),
	outfit = outfit({ top = rgb(68, 72, 86), waist = rgb(52, 55, 68), arms = rgb(68, 72, 86), legs = rgb(52, 55, 68), feet = rgb(40, 42, 52) }),
	props = {
		{ n = "Helm", on = "Head", shape = "Cylinder", size = v3(1.6, 1.4, 1.6), at = cf(0, 0.12, 0), color = rgb(80, 86, 104), mat = METAL },
		{ n = "HelmTop", on = "Head", shape = "Ball", size = v3(1.6, 1.2, 1.6), at = cf(0, 0.66, 0), color = rgb(80, 86, 104), mat = METAL },
		{ n = "VisorGlow", on = "Head", size = v3(1.1, 0.16, 0.1), at = cf(0, 0.1, -0.74), color = rgb(255, 236, 140), neon = true },
		{
			n = "Plume",
			on = "Head",
			size = v3(0.3, 1.1, 1.5),
			at = cf(0, 1.5, 0.1),
			color = rgb(210, 40, 50),
			neon = true,
			anim = { kind = "swing", axis = "X", amp = 12, speed = 2.6 },
		},
		{ n = "PauldronL", on = "LeftUpperArm", shape = "Ball", size = v3(1.7, 1.2, 1.7), at = cf(0, 0.4, 0), color = rgb(80, 86, 104), mat = METAL },
		{ n = "PauldronR", on = "RightUpperArm", shape = "Ball", size = v3(1.7, 1.2, 1.7), at = cf(0, 0.4, 0), color = rgb(80, 86, 104), mat = METAL },
		{ n = "ChestPlate", on = "UpperTorso", size = v3(2.3, 1.6, 1.4), at = cf(0, 0.05, 0), color = rgb(80, 86, 104), mat = METAL },
		{ n = "ChestCrest", on = "UpperTorso", shape = "Disc", size = v3(0.9, 0.9, 0.1), at = cf(0, 0.1, -0.73), color = GOLD, mat = METAL },
		{
			n = "Cape",
			on = "UpperTorso",
			size = v3(2.2, 3.6, 0.1),
			at = cf(0, -1.0, 0.78),
			color = rgb(150, 24, 34),
			anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5, pivot = cf(0, 0.8, 0.78) },
		},
		{ n = "ShieldRim", on = "LeftLowerArm", size = v3(3.0, 3.9, 0.22), at = cf(-0.7, 0.4, -1.3), color = GOLD, mat = METAL },
		{
			n = "Shield",
			on = "LeftLowerArm",
			size = v3(2.7, 3.6, 0.3),
			at = cf(-0.7, 0.4, -1.36),
			color = rgb(150, 24, 34),
			anim = { kind = "push", axis = "Z", amp = 0.5, speed = 1.2 },
		},
		{
			n = "ShieldStar",
			on = "LeftLowerArm",
			shape = "Disc",
			size = v3(1.1, 1.1, 0.12),
			at = cf(-0.7, 0.4, -1.55),
			color = GOLD,
			mat = METAL,
			anim = { kind = "push", axis = "Z", amp = 0.5, speed = 1.2 },
		},
		{
			n = "Blade",
			on = "RightHand",
			size = v3(0.42, 0.14, 4.4),
			at = cf(0, -0.25, -2.4),
			color = rgb(225, 232, 240),
			mat = METAL,
			anim = { kind = "swing", axis = "X", amp = 35, speed = 1.2 },
		},
		{
			n = "BladeGuard",
			on = "RightHand",
			size = v3(1.5, 0.22, 0.24),
			at = cf(0, -0.25, -0.3),
			color = GOLD,
			mat = METAL,
			anim = { kind = "swing", axis = "X", amp = 35, speed = 1.2 },
		},
	},
	fx = {
		{ on = "UpperTorso", kind = "flame", color = rgb(255, 120, 40), rate = 10, aura = true },
		{ on = "Head", kind = "spark", color = rgb(255, 230, 140), rate = 8, aura = true },
	},
	light = rgb(255, 150, 60),
	halo = rgb(255, 120, 40),
}

-- ================================ SUNKEN KINGDOM ================================
-- Short prop constructor for the zones below: P(name, body part, shape, size, at, colour, extra fields).
local function P(n: string, on: string, shape: string, size: Vector3, at: CFrame, color: Color3, extra: { [string]: any }?): Prop
	local prop: any = { n = n, on = on, shape = shape, size = size, at = at, color = color }
	for k, v in extra or {} do
		prop[k] = v
	end
	return prop
end
local TEAL, NAVY, PEARL, SAND = rgb(40, 170, 180), rgb(30, 70, 120), rgb(250, 240, 245), rgb(230, 205, 150)
local GLASS = Enum.Material.Glass

CreatureSpecs.bubble_fish = { -- Bubble Fish (C): diver in a goldfish-bowl helmet, blows bubbles
	own = true,
	skin = SKIN,
	outfit = outfit({ top = TEAL, waist = NAVY, arms = TEAL, legs = NAVY, feet = rgb(255, 150, 40) }),
	props = {
		P("Bowl", "Head", "Ball", v3(2.1, 2.1, 2.1), cf(0, 0.1, 0), rgb(170, 225, 255), { trans = 0.7, mat = GLASS }),
		P("Goldfish", "Head", "Ball", v3(0.45, 0.4, 0.8), cf(0.5, 1.15, 0), rgb(255, 150, 30), { anim = { kind = "bob", amp = 0.1, speed = 2.2 } }),
		P("Tank", "UpperTorso", "Cylinder", v3(0.7, 1.7, 0.7), cf(0, 0.2, 0.75), rgb(250, 200, 40), { mat = METAL }),
		P("FinL", "LeftFoot", "Block", v3(0.9, 0.1, 1.5), cf(0, -0.2, -0.6), rgb(255, 150, 40), { anim = { kind = "swing", axis = "X", amp = 8, speed = 3 } }),
		P("FinR", "RightFoot", "Block", v3(0.9, 0.1, 1.5), cf(0, -0.2, -0.6), rgb(255, 150, 40), { anim = { kind = "swing", axis = "X", amp = 8, speed = 3, phase = 2 } }),
	},
	fx = { { on = "Head", kind = "bubble", color = rgb(190, 235, 255), rate = 3, at = v3(0, 1.1, 0) } },
}

CreatureSpecs.hermit_porter = { -- Hermit Porter (C): a shell backpack stacked with crates
	skin = SKIN_D,
	outfit = outfit({ top = rgb(160, 110, 70), waist = rgb(110, 80, 50), arms = rgb(160, 110, 70), legs = rgb(110, 80, 50), feet = rgb(70, 50, 34) }),
	props = {
		P("Shell", "UpperTorso", "Ball", v3(2.3, 2.1, 1.9), cf(0, 0.2, 1.0), rgb(255, 205, 190)),
		P("ShellStripe", "UpperTorso", "Ball", v3(1.5, 1.45, 1.3), cf(0, 0.2, 1.3), rgb(240, 150, 140)),
		P(
			"CrateA",
			"UpperTorso",
			"Block",
			v3(1.5, 1.0, 1.2),
			cf(0, 1.65, 1.0),
			rgb(160, 110, 60),
			{ mat = Enum.Material.Wood, anim = { kind = "swing", axis = "Z", amp = 3, speed = 1.6 } }
		),
		P(
			"CrateB",
			"UpperTorso",
			"Block",
			v3(1.1, 0.8, 0.9),
			cf(0.1, 2.5, 1.0),
			rgb(190, 135, 75),
			{ mat = Enum.Material.Wood, anim = { kind = "swing", axis = "Z", amp = 5, speed = 1.6, phase = 1 } }
		),
		P("HatBrim", "Head", "Cylinder", v3(2.0, 0.1, 2.0), cf(0, 0.5, 0), SAND),
		P("HatTop", "Head", "Ball", v3(1.2, 0.8, 1.2), cf(0, 0.75, 0), SAND),
	},
}

CreatureSpecs.coral_snail = { -- Coral Snail (C): coral shell, eye stalks on its hat
	own = true,
	skin = rgb(255, 180, 190),
	outfit = outfit({ top = rgb(255, 160, 170), waist = rgb(240, 130, 150), arms = rgb(255, 180, 190), legs = rgb(240, 130, 150), feet = rgb(220, 110, 130) }),
	props = {
		P("Shell", "UpperTorso", "Ball", v3(2.1, 1.9, 1.8), cf(0, 0.1, 0.95), rgb(255, 120, 110)),
		P("ShellSwirl", "UpperTorso", "Ball", v3(1.2, 1.1, 1.0), cf(0, 0.1, 1.5), rgb(255, 200, 170)),
		P("SpikeA", "UpperTorso", "Block", v3(0.25, 0.7, 0.25), cf(0, 1.25, 1.0) * CFrame.Angles(rad(15), 0, 0), rgb(255, 170, 60)),
		P("SpikeB", "UpperTorso", "Block", v3(0.25, 0.7, 0.25), cf(0.8, 0.9, 1.0) * CFrame.Angles(0, 0, rad(-40)), rgb(255, 170, 60)),
		P("SpikeC", "UpperTorso", "Block", v3(0.25, 0.7, 0.25), cf(-0.8, 0.9, 1.0) * CFrame.Angles(0, 0, rad(40)), rgb(255, 170, 60)),
		P(
			"StalkL",
			"Head",
			"Cylinder",
			v3(0.14, 0.9, 0.14),
			cf(-0.3, 0.95, 0),
			rgb(255, 160, 170),
			{ anim = { kind = "swing", axis = "Z", amp = 12, speed = 2.1, pivot = cf(-0.3, 0.5, 0) } }
		),
		P(
			"StalkR",
			"Head",
			"Cylinder",
			v3(0.14, 0.9, 0.14),
			cf(0.3, 0.95, 0),
			rgb(255, 160, 170),
			{ anim = { kind = "swing", axis = "Z", amp = 12, speed = 2.1, phase = 1.5, pivot = cf(0.3, 0.5, 0) } }
		),
		P(
			"EyeL",
			"Head",
			"Ball",
			v3(0.4, 0.4, 0.4),
			cf(-0.3, 1.45, 0),
			rgb(255, 255, 255),
			{ anim = { kind = "swing", axis = "Z", amp = 12, speed = 2.1, pivot = cf(-0.3, 0.5, 0) } }
		),
		P(
			"EyeR",
			"Head",
			"Ball",
			v3(0.4, 0.4, 0.4),
			cf(0.3, 1.45, 0),
			rgb(255, 255, 255),
			{ anim = { kind = "swing", axis = "Z", amp = 12, speed = 2.1, phase = 1.5, pivot = cf(0.3, 0.5, 0) } }
		),
	},
}

CreatureSpecs.puffer_guard = { -- Puffer Guard (R): spiky round belly that puffs, spear
	skin = rgb(255, 225, 120),
	outfit = outfit({ top = rgb(255, 215, 90), waist = rgb(230, 170, 50), arms = rgb(255, 215, 90), legs = rgb(230, 170, 50), feet = rgb(200, 140, 40) }),
	props = {
		P("Belly", "UpperTorso", "Ball", v3(2.5, 2.3, 1.7), cf(0, -0.1, -0.2), rgb(255, 240, 170), { anim = { kind = "pulse", amp = 0.07, speed = 1.8 } }),
		P("SpikeTop", "UpperTorso", "Block", v3(0.16, 0.6, 0.16), cf(0, 1.15, -0.2), rgb(255, 150, 40)),
		P("SpikeL", "UpperTorso", "Block", v3(0.6, 0.16, 0.16), cf(-1.35, -0.1, -0.2), rgb(255, 150, 40)),
		P("SpikeR", "UpperTorso", "Block", v3(0.6, 0.16, 0.16), cf(1.35, -0.1, -0.2), rgb(255, 150, 40)),
		P("SpikeFL", "UpperTorso", "Block", v3(0.16, 0.16, 0.6), cf(-0.6, 0.5, -1.0), rgb(255, 150, 40)),
		P("SpikeFR", "UpperTorso", "Block", v3(0.16, 0.16, 0.6), cf(0.6, 0.5, -1.0), rgb(255, 150, 40)),
		P("SpikeBottom", "UpperTorso", "Block", v3(0.16, 0.16, 0.6), cf(0, -0.7, -1.0), rgb(255, 150, 40)),
		P("Helm", "Head", "Ball", v3(1.5, 0.9, 1.5), cf(0, 0.5, 0), rgb(150, 160, 175), { mat = METAL }),
		P("HelmFin", "Head", "Block", v3(0.15, 0.7, 0.9), cf(0, 1.0, 0), rgb(255, 150, 40)),
		P("SpearShaft", "RightHand", "Block", v3(0.16, 0.16, 3.6), cf(0, -0.25, -1.6), WOOD, { anim = { kind = "push", axis = "Z", amp = 0.4, speed = 2.2 } }),
		P(
			"SpearTip",
			"RightHand",
			"Block",
			v3(0.35, 0.12, 0.7),
			cf(0, -0.25, -3.5),
			rgb(210, 220, 230),
			{ mat = METAL, anim = { kind = "push", axis = "Z", amp = 0.4, speed = 2.2 } }
		),
	},
	fx = { { on = "SpearTip", kind = "bubble", color = rgb(200, 235, 255), rate = 2 } },
}

CreatureSpecs.mermaid_mage = { -- Mermaid Mage (R): fin skirt, pearl staff, bubble spells
	skin = rgb(255, 214, 190),
	outfit = outfit({ top = rgb(150, 90, 200), waist = TEAL, arms = rgb(255, 214, 190), legs = TEAL, feet = TEAL }),
	props = {
		P("Skirt", "LowerTorso", "Block", v3(2.0, 1.8, 1.3), cf(0, -1.3, 0), TEAL),
		P(
			"TailFin",
			"LowerTorso",
			"Block",
			v3(2.1, 0.15, 1.7),
			cf(0, -2.4, 0.2),
			rgb(90, 220, 200),
			{ anim = { kind = "swing", axis = "X", amp = 10, speed = 2.4, pivot = cf(0, -2.0, 0) } }
		),
		P("ShellL", "UpperTorso", "Ball", v3(0.6, 0.5, 0.4), cf(-0.4, 0.5, -0.6), rgb(255, 190, 200)),
		P("ShellR", "UpperTorso", "Ball", v3(0.6, 0.5, 0.4), cf(0.4, 0.5, -0.6), rgb(255, 190, 200)),
		P(
			"Hair",
			"Head",
			"Block",
			v3(1.4, 2.2, 0.45),
			cf(0, -0.8, 0.55),
			rgb(60, 190, 190),
			{ anim = { kind = "swing", axis = "X", amp = 6, speed = 1.7, pivot = cf(0, 0.4, 0.5) } }
		),
		P("Crown", "Head", "Block", v3(1.3, 0.3, 1.3), cf(0, 0.55, 0), rgb(255, 215, 100), { mat = METAL }),
		P("StaffShaft", "RightHand", "Cylinder", v3(0.2, 4.6, 0.2), cf(0, 1.7, -0.45), rgb(220, 190, 150)),
		P("StaffPearl", "RightHand", "Ball", v3(0.8, 0.8, 0.8), cf(0, 4.2, -0.45), PEARL, { neon = true, anim = { kind = "bob", amp = 0.12, speed = 2.6 } }),
	},
	fx = { { on = "StaffPearl", kind = "bubble", color = rgb(190, 235, 255), rate = 6 } },
}

CreatureSpecs.shark_knight = { -- Shark Knight (E): shark-helm, fin, sword; wave aura
	skin = SKIN,
	outfit = outfit({ top = rgb(110, 130, 160), waist = rgb(70, 85, 110), arms = rgb(110, 130, 160), legs = rgb(70, 85, 110), feet = rgb(110, 130, 160) }),
	props = {
		P("SharkHood", "Head", "Ball", v3(1.85, 1.6, 1.95), cf(0, 0.25, 0.05), rgb(120, 140, 165)),
		P("Snout", "Head", "Block", v3(1.0, 0.7, 1.1), cf(0, -0.05, -0.95), rgb(185, 200, 215)),
		P("Teeth", "Head", "Block", v3(0.95, 0.12, 0.12), cf(0, -0.38, -1.4), rgb(255, 255, 255)),
		P("EyeL", "Head", "Disc", v3(0.22, 0.22, 0.1), cf(-0.5, 0.3, -0.92), rgb(20, 20, 30)),
		P("EyeR", "Head", "Disc", v3(0.22, 0.22, 0.1), cf(0.5, 0.3, -0.92), rgb(20, 20, 30)),
		P("DorsalHead", "Head", "Block", v3(0.18, 1.1, 0.9), cf(0, 1.0, 0.45) * CFrame.Angles(rad(-25), 0, 0), rgb(95, 115, 140)),
		P("PauldronL", "LeftUpperArm", "Ball", v3(1.25, 0.9, 1.25), cf(0, 0.4, 0), STEEL, { mat = METAL }),
		P("PauldronR", "RightUpperArm", "Ball", v3(1.25, 0.9, 1.25), cf(0, 0.4, 0), STEEL, { mat = METAL }),
		P("Chest", "UpperTorso", "Block", v3(2.15, 1.5, 1.25), cf(0, 0.05, 0), STEEL, { mat = METAL }),
		P(
			"BackFin",
			"UpperTorso",
			"Block",
			v3(0.2, 1.7, 1.1),
			cf(0, 0.5, 0.85) * CFrame.Angles(rad(-20), 0, 0),
			rgb(95, 115, 140),
			{ anim = { kind = "swing", axis = "X", amp = 5, speed = 2.0, pivot = cf(0, -0.3, 0.7) } }
		),
		P("Blade", "RightHand", "Block", v3(0.25, 0.1, 2.7), cf(0, -0.25, -1.5), rgb(215, 235, 250), { mat = METAL, anim = { kind = "swing", axis = "X", amp = 40, speed = 2.0 } }),
		P("Guard", "RightHand", "Block", v3(0.9, 0.16, 0.18), cf(0, -0.25, -0.2), GOLD, { anim = { kind = "swing", axis = "X", amp = 40, speed = 2.0 } }),
	},
	fx = { { on = "Blade", kind = "bubble", color = rgb(170, 225, 255), rate = 4, aura = true } },
	light = rgb(120, 190, 255),
}

CreatureSpecs.pearl_seahorse = { -- Pearl Seahorse (E): a seahorse riding a bubble, pearl in its tail
	hideBody = true,
	skin = PEARL,
	props = {
		P("Bubble", "LowerTorso", "Ball", v3(4.3, 4.3, 4.3), cf(0, 0.1, 0), rgb(170, 225, 255), { trans = 0.78, mat = GLASS, anim = { kind = "pulse", amp = 0.03, speed = 1.4 } }),
		P("Belly", "LowerTorso", "Ball", v3(1.3, 1.7, 1.1), cf(0, -0.2, 0), rgb(255, 215, 235)),
		P("Neck", "LowerTorso", "Ball", v3(1.0, 1.3, 0.9), cf(0, 0.9, -0.25), rgb(255, 200, 225)),
		P("Head", "LowerTorso", "Ball", v3(1.1, 1.0, 1.4), cf(0, 1.6, -0.55), PEARL),
		P("Snout", "LowerTorso", "Block", v3(0.4, 0.35, 0.9), cf(0, 1.5, -1.35), rgb(255, 215, 235)),
		P("Eye", "LowerTorso", "Ball", v3(0.25, 0.25, 0.25), cf(0.4, 1.8, -0.9), rgb(20, 20, 40)),
		P("CrownA", "LowerTorso", "Block", v3(0.14, 0.5, 0.2), cf(0, 2.2, -0.4), rgb(255, 200, 80), { neon = true }),
		P("CrownB", "LowerTorso", "Block", v3(0.14, 0.4, 0.2), cf(0, 2.15, -0.1), rgb(255, 200, 80), { neon = true }),
		P(
			"Dorsal",
			"LowerTorso",
			"Block",
			v3(0.1, 0.9, 0.6),
			cf(0, 0.2, 0.65),
			rgb(255, 150, 190),
			{ anim = { kind = "swing", axis = "X", amp = 14, speed = 3.0, pivot = cf(0, 0, 0.5) } }
		),
		P("Tail1", "LowerTorso", "Ball", v3(0.85, 0.85, 0.85), cf(0, -1.1, 0.3), rgb(255, 200, 225)),
		P("Tail2", "LowerTorso", "Ball", v3(0.65, 0.65, 0.65), cf(0, -1.55, 0.75), rgb(255, 200, 225)),
		P("Tail3", "LowerTorso", "Ball", v3(0.5, 0.5, 0.5), cf(0, -1.3, 1.25), rgb(255, 200, 225)),
		P("TailPearl", "LowerTorso", "Ball", v3(0.65, 0.65, 0.65), cf(0, -0.8, 1.35), PEARL, { neon = true, anim = { kind = "bob", amp = 0.1, speed = 2.5 } }),
	},
	fx = { { on = "Bubble", kind = "bubble", color = rgb(210, 240, 255), rate = 4, aura = true }, { on = "TailPearl", kind = "spark", color = rgb(255, 245, 255), rate = 3 } },
	light = rgb(255, 225, 245),
}

CreatureSpecs.tide_warden = { -- Tide Warden (L): Aquaris's champion; coral crown, trident, water swirl
	scale = 1.3,
	skin = SKIN,
	outfit = outfit({ top = rgb(30, 110, 160), waist = rgb(20, 70, 110), arms = rgb(30, 110, 160), legs = rgb(20, 80, 120), feet = rgb(30, 110, 160) }),
	props = {
		P("Helm", "Head", "Cylinder", v3(1.5, 1.3, 1.5), cf(0, 0.12, 0), rgb(60, 170, 190), { mat = METAL }),
		P("HelmTop", "Head", "Ball", v3(1.5, 1.0, 1.5), cf(0, 0.58, 0), rgb(60, 170, 190), { mat = METAL }),
		P("Visor", "Head", "Block", v3(1.05, 0.14, 0.1), cf(0, 0.1, -0.7), rgb(15, 25, 50)),
		P("Coral1", "Head", "Block", v3(0.2, 1.0, 0.2), cf(0, 1.3, 0), rgb(255, 120, 110)),
		P("Coral2", "Head", "Block", v3(0.2, 0.8, 0.2), cf(0.5, 1.1, 0) * CFrame.Angles(0, 0, rad(-30)), rgb(255, 150, 120)),
		P("Coral3", "Head", "Block", v3(0.2, 0.8, 0.2), cf(-0.5, 1.1, 0) * CFrame.Angles(0, 0, rad(30)), rgb(255, 150, 120)),
		P("Coral4", "Head", "Block", v3(0.2, 0.6, 0.2), cf(0.85, 0.9, 0) * CFrame.Angles(0, 0, rad(-60)), rgb(255, 120, 110)),
		P("Coral5", "Head", "Block", v3(0.2, 0.6, 0.2), cf(-0.85, 0.9, 0) * CFrame.Angles(0, 0, rad(60)), rgb(255, 120, 110)),
		P("ShellPauldronL", "LeftUpperArm", "Ball", v3(1.6, 1.1, 1.6), cf(0, 0.4, 0), rgb(255, 215, 215)),
		P("ShellPauldronR", "RightUpperArm", "Ball", v3(1.6, 1.1, 1.6), cf(0, 0.4, 0), rgb(255, 215, 215)),
		P("Chest", "UpperTorso", "Block", v3(2.2, 1.55, 1.3), cf(0, 0.05, 0), rgb(60, 170, 190), { mat = METAL }),
		P("ChestPearl", "UpperTorso", "Ball", v3(0.7, 0.7, 0.4), cf(0, 0.1, -0.68), PEARL, { neon = true }),
		P(
			"Kelp",
			"UpperTorso",
			"Block",
			v3(2.0, 3.4, 0.1),
			cf(0, -0.9, 0.72),
			rgb(40, 150, 80),
			{ anim = { kind = "swing", axis = "X", amp = 7, speed = 1.9, pivot = cf(0, 0.8, 0.7) } }
		),
		P("TridentShaft", "RightHand", "Cylinder", v3(0.24, 5.6, 0.24), cf(0, 2.0, -0.45), GOLD, { mat = METAL, anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5 } }),
		P("TridentMid", "RightHand", "Block", v3(0.18, 1.1, 0.18), cf(0, 5.3, -0.45), GOLD, { mat = METAL, anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5 } }),
		P("TridentL", "RightHand", "Block", v3(0.18, 0.9, 0.18), cf(-0.5, 5.15, -0.45), GOLD, { mat = METAL, anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5 } }),
		P("TridentR", "RightHand", "Block", v3(0.18, 0.9, 0.18), cf(0.5, 5.15, -0.45), GOLD, { mat = METAL, anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5 } }),
		P("TridentBar", "RightHand", "Block", v3(1.2, 0.18, 0.18), cf(0, 4.7, -0.45), GOLD, { mat = METAL, anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5 } }),
	},
	fx = {
		{ on = "UpperTorso", kind = "bubble", color = rgb(150, 220, 255), rate = 8, size = 1.3, aura = true },
		{ on = "TridentMid", kind = "spark", color = rgb(160, 230, 255), rate = 6 },
	},
	light = rgb(110, 210, 255),
	halo = rgb(90, 200, 255),
}

-- Aquaris (S): a real water dragon from the reusable DragonKit (ReplicatedStorage.DragonKit): long-snouted head with an opening
-- jaw and swept-back gold horns, S-curve neck, rounded body with light belly plates and dorsal spikes, four clawed legs standing
-- on the ground, big finger-boned wings with glowing membrane panels (they flap), a spiked tail that sways. The rig only walks it.
-- DRAGON_MESHES: false = every piece from plain parts; true = the Blender head, wings and tail tip from ServerStorage.Imports035.
local DragonKit = require(script.Parent:WaitForChild("DragonKit"))
local DRAGON_MESHES = true
local function aquaris(): Spec
	local props, fx = DragonKit.build({ u = 1, colors = DragonKit.WATER, meshes = DRAGON_MESHES })
	return {
		hideBody = true,
		scale = 3,
		skin = rgb(18, 84, 176),
		props = props,
		fx = fx,
		light = rgb(120, 210, 255),
		halo = rgb(90, 200, 255),
		sound = "boss_roar",
	}
end
CreatureSpecs.aquaris = aquaris()

-- ================================ EMBER ACADEMY ================================
local FIRE, FLAME, EMBER_RED, ROBE, STONE = rgb(255, 140, 40), rgb(255, 210, 70), rgb(200, 50, 40), rgb(170, 40, 40), rgb(130, 128, 140)

CreatureSpecs.butler_barnaby = { -- Candle Imp (C): a candle with a flame on its head, wax drips
	scale = 0.95,
	skin = rgb(250, 232, 200),
	outfit = outfit({ top = rgb(235, 80, 60), waist = rgb(150, 40, 40), arms = rgb(250, 232, 200), legs = rgb(150, 40, 40), feet = rgb(90, 30, 30) }),
	props = {
		P("Candle", "Head", "Cylinder", v3(0.85, 1.0, 0.85), cf(0, 0.95, 0), rgb(255, 245, 215)),
		P("Flame", "Head", "Ball", v3(0.45, 0.8, 0.45), cf(0, 1.7, 0), FLAME, { neon = true, anim = { kind = "pulse", amp = 0.18, speed = 7 } }),
		P("HornL", "Head", "Block", v3(0.2, 0.5, 0.2), cf(-0.55, 0.55, 0.1) * CFrame.Angles(0, 0, rad(25)), EMBER_RED),
		P("HornR", "Head", "Block", v3(0.2, 0.5, 0.2), cf(0.55, 0.55, 0.1) * CFrame.Angles(0, 0, rad(-25)), EMBER_RED),
		P("DripA", "Head", "Ball", v3(0.28, 0.4, 0.28), cf(0.3, 0.42, -0.2), rgb(255, 245, 215)),
		P("DripB", "Head", "Ball", v3(0.22, 0.34, 0.22), cf(-0.25, 0.4, 0.15), rgb(255, 245, 215)),
		P(
			"Tail",
			"LowerTorso",
			"Block",
			v3(0.14, 0.14, 1.4),
			cf(0, -0.3, 0.9),
			EMBER_RED,
			{ anim = { kind = "swing", axis = "Y", amp = 18, speed = 3, pivot = cf(0, -0.3, 0.3) } }
		),
		P(
			"TailTip",
			"LowerTorso",
			"Block",
			v3(0.4, 0.1, 0.4),
			cf(0, -0.3, 1.7) * CFrame.Angles(0, rad(45), 0),
			EMBER_RED,
			{ anim = { kind = "swing", axis = "Y", amp = 18, speed = 3, pivot = cf(0, -0.3, 0.3) } }
		),
	},
	fx = { { on = "Flame", kind = "flame", color = FIRE, rate = 5, size = 0.5 } },
	light = FLAME,
}

CreatureSpecs.caddie_gus = { -- Ember Newt (C): a newt with a tail lantern that breathes tiny flame puffs
	own = true,
	skin = rgb(255, 150, 70),
	outfit = outfit({ top = rgb(255, 130, 50), waist = rgb(200, 90, 40), arms = rgb(255, 150, 70), legs = rgb(200, 90, 40), feet = rgb(150, 70, 30) }),
	props = {
		P("Hood", "Head", "Block", v3(1.45, 0.55, 1.55), cf(0, 0.5, 0.05), rgb(255, 120, 45)),
		P("EyeL", "Head", "Ball", v3(0.4, 0.4, 0.4), cf(-0.4, 0.8, -0.3), rgb(255, 245, 160)),
		P("EyeR", "Head", "Ball", v3(0.4, 0.4, 0.4), cf(0.4, 0.8, -0.3), rgb(255, 245, 160)),
		P("Snout", "Head", "Block", v3(0.85, 0.4, 0.8), cf(0, -0.1, -0.85), rgb(255, 120, 45)),
		P("Spots", "UpperTorso", "Block", v3(1.5, 0.12, 1.3), cf(0, 0.8, 0.05), rgb(120, 40, 30)),
		P(
			"Tail",
			"LowerTorso",
			"Block",
			v3(0.45, 0.35, 2.0),
			cf(0, -0.4, 1.4),
			rgb(255, 130, 50),
			{ anim = { kind = "swing", axis = "Y", amp = 14, speed = 2.6, pivot = cf(0, -0.4, 0.4) } }
		),
		P(
			"Lantern",
			"LowerTorso",
			"Ball",
			v3(0.6, 0.6, 0.6),
			cf(0, -0.4, 2.6),
			FLAME,
			{ neon = true, anim = { kind = "swing", axis = "Y", amp = 14, speed = 2.6, pivot = cf(0, -0.4, 0.4) } }
		),
		P(
			"LanternCap",
			"LowerTorso",
			"Block",
			v3(0.5, 0.1, 0.5),
			cf(0, -0.05, 2.6),
			rgb(70, 50, 40),
			{ anim = { kind = "swing", axis = "Y", amp = 14, speed = 2.6, pivot = cf(0, -0.4, 0.4) } }
		),
	},
	fx = { { on = "Snout", kind = "puff", color = FIRE, rate = 5, size = 0.7 } }, -- tiny dragon-breath puffs
}

CreatureSpecs.bookling = { -- Bookling (C): a spellbook that chomps
	skin = rgb(200, 170, 140),
	outfit = outfit({ top = rgb(110, 60, 150), waist = rgb(80, 40, 110), arms = rgb(110, 60, 150), legs = rgb(80, 40, 110), feet = rgb(60, 30, 80) }),
	props = {
		P("BookSpine", "UpperTorso", "Block", v3(1.9, 2.2, 0.3), cf(0, 0.1, -0.78), rgb(120, 40, 50)),
		P("Pages", "UpperTorso", "Block", v3(1.7, 0.2, 1.2), cf(0, 0.0, -1.35), rgb(255, 245, 215)),
		P(
			"CoverTop",
			"UpperTorso",
			"Block",
			v3(1.9, 0.3, 1.6),
			cf(0, 0.25, -1.55),
			rgb(130, 50, 160),
			{ anim = { kind = "swing", axis = "X", amp = 16, speed = 3.2, pivot = cf(0, 0.2, -0.85) } }
		),
		P(
			"CoverBottom",
			"UpperTorso",
			"Block",
			v3(1.9, 0.3, 1.6),
			cf(0, -0.3, -1.55),
			rgb(130, 50, 160),
			{ anim = { kind = "swing", axis = "X", amp = -16, speed = 3.2, pivot = cf(0, -0.25, -0.85) } }
		),
		P(
			"TeethTop",
			"UpperTorso",
			"Block",
			v3(1.5, 0.2, 0.25),
			cf(0, 0.05, -2.2),
			rgb(255, 255, 255),
			{ anim = { kind = "swing", axis = "X", amp = 16, speed = 3.2, pivot = cf(0, 0.2, -0.85) } }
		),
		P(
			"TeethBottom",
			"UpperTorso",
			"Block",
			v3(1.5, 0.2, 0.25),
			cf(0, -0.1, -2.2),
			rgb(255, 255, 255),
			{ anim = { kind = "swing", axis = "X", amp = -16, speed = 3.2, pivot = cf(0, -0.25, -0.85) } }
		),
		P(
			"EyeL",
			"UpperTorso",
			"Ball",
			v3(0.4, 0.4, 0.3),
			cf(-0.45, 0.45, -2.0),
			rgb(255, 255, 255),
			{ anim = { kind = "swing", axis = "X", amp = 16, speed = 3.2, pivot = cf(0, 0.2, -0.85) } }
		),
		P(
			"EyeR",
			"UpperTorso",
			"Ball",
			v3(0.4, 0.4, 0.3),
			cf(0.45, 0.45, -2.0),
			rgb(255, 255, 255),
			{ anim = { kind = "swing", axis = "X", amp = 16, speed = 3.2, pivot = cf(0, 0.2, -0.85) } }
		),
		P("Rune", "UpperTorso", "Disc", v3(0.5, 0.5, 0.08), cf(0, 0.1, -0.95), FLAME, { neon = true }),
	},
}

CreatureSpecs.polo_pro_penny = { -- Ember Owl (R): burning quill, big eyes, flapping wings
	own = true,
	skin = rgb(190, 140, 90),
	outfit = outfit({ top = rgb(150, 100, 60), waist = rgb(120, 80, 50), arms = rgb(150, 100, 60), legs = rgb(120, 80, 50), feet = rgb(255, 170, 60) }),
	props = {
		P("Cap", "Head", "Ball", v3(1.75, 1.5, 1.75), cf(0, 0.25, 0.05), rgb(150, 100, 60)),
		P("TuftL", "Head", "Block", v3(0.25, 0.6, 0.25), cf(-0.6, 0.95, 0) * CFrame.Angles(0, 0, rad(18)), rgb(110, 70, 40)),
		P("TuftR", "Head", "Block", v3(0.25, 0.6, 0.25), cf(0.6, 0.95, 0) * CFrame.Angles(0, 0, rad(-18)), rgb(110, 70, 40)),
		P("EyeL", "Head", "Disc", v3(0.6, 0.6, 0.1), cf(-0.35, 0.2, -0.82), rgb(255, 225, 90)),
		P("EyeR", "Head", "Disc", v3(0.6, 0.6, 0.1), cf(0.35, 0.2, -0.82), rgb(255, 225, 90)),
		P("PupilL", "Head", "Disc", v3(0.28, 0.28, 0.1), cf(-0.35, 0.2, -0.87), rgb(20, 15, 15)),
		P("PupilR", "Head", "Disc", v3(0.28, 0.28, 0.1), cf(0.35, 0.2, -0.87), rgb(20, 15, 15)),
		P("Beak", "Head", "Block", v3(0.3, 0.35, 0.4), cf(0, -0.1, -0.9), rgb(255, 170, 60)),
		P(
			"WingL",
			"UpperTorso",
			"Block",
			v3(0.2, 1.9, 1.2),
			cf(-1.4, -0.1, 0.2),
			rgb(120, 80, 50),
			{ anim = { kind = "swing", axis = "Z", amp = 10, speed = 3, pivot = cf(-1.2, 0.8, 0) } }
		),
		P(
			"WingR",
			"UpperTorso",
			"Block",
			v3(0.2, 1.9, 1.2),
			cf(1.4, -0.1, 0.2),
			rgb(120, 80, 50),
			{ anim = { kind = "swing", axis = "Z", amp = -10, speed = 3, pivot = cf(1.2, 0.8, 0) } }
		),
		P(
			"Quill",
			"RightHand",
			"Cylinder",
			v3(0.1, 1.8, 0.1),
			cf(0, 0.2, -0.5) * CFrame.Angles(rad(30), 0, 0),
			rgb(255, 245, 225),
			{ anim = { kind = "swing", axis = "X", amp = 18, speed = 2.4 } }
		),
		P("QuillFlame", "RightHand", "Ball", v3(0.35, 0.6, 0.35), cf(0, 1.0, -0.95), FIRE, { neon = true, anim = { kind = "swing", axis = "X", amp = 18, speed = 2.4 } }),
	},
	fx = { { on = "QuillFlame", kind = "flame", color = FIRE, rate = 5, size = 0.5 } },
}

CreatureSpecs.chef_pierre = { -- Fire Apprentice (R): oversized hat, flames from both hands
	skin = SKIN,
	outfit = outfit({ top = rgb(210, 60, 50), waist = rgb(255, 200, 70), arms = rgb(210, 60, 50), legs = rgb(150, 40, 40), feet = rgb(90, 30, 30) }),
	props = {
		P("Brim", "Head", "Cylinder", v3(3.0, 0.12, 3.0), cf(0, 0.5, 0), rgb(150, 40, 40)),
		P("Hat1", "Head", "Cylinder", v3(1.8, 0.8, 1.8), cf(0, 0.95, 0), rgb(170, 45, 45)),
		P("Hat2", "Head", "Cylinder", v3(1.25, 0.8, 1.25), cf(0.05, 1.7, 0), rgb(170, 45, 45)),
		P("Hat3", "Head", "Cylinder", v3(0.7, 0.8, 0.7), cf(0.2, 2.45, 0), rgb(170, 45, 45), { anim = { kind = "swing", axis = "Z", amp = 6, speed = 2, pivot = cf(0, 1.5, 0) } }),
		P("HatBand", "Head", "Cylinder", v3(1.9, 0.2, 1.9), cf(0, 0.65, 0), rgb(255, 200, 70)),
		P("Robe", "LowerTorso", "Block", v3(1.95, 1.7, 1.2), cf(0, -1.2, 0), rgb(190, 50, 45)),
		P("FireL", "LeftHand", "Ball", v3(0.55, 0.7, 0.55), cf(0, -0.5, -0.1), FIRE, { neon = true, anim = { kind = "pulse", amp = 0.2, speed = 6 } }),
		P("FireR", "RightHand", "Ball", v3(0.55, 0.7, 0.55), cf(0, -0.5, -0.1), FIRE, { neon = true, anim = { kind = "pulse", amp = 0.2, speed = 6, phase = 2 } }),
	},
	fx = { { on = "FireL", kind = "flame", color = FIRE, rate = 6, size = 0.7 }, { on = "FireR", kind = "flame", color = FIRE, rate = 6, size = 0.7 } },
}

CreatureSpecs.bodyguard_boris = { -- Rune Golem (E): stone giant with glowing runes
	own = true,
	skin = STONE,
	outfit = outfit({ top = rgb(120, 118, 130), waist = rgb(100, 98, 110), arms = STONE, legs = rgb(100, 98, 110), feet = rgb(90, 88, 100) }),
	props = {
		P("TorsoRock", "UpperTorso", "Block", v3(2.5, 1.9, 1.6), cf(0, 0.05, 0), rgb(135, 132, 145)),
		P("HeadRock", "Head", "Block", v3(1.6, 1.5, 1.5), cf(0, 0.1, 0), rgb(150, 147, 160)),
		P("EyeL", "Head", "Block", v3(0.35, 0.18, 0.1), cf(-0.35, 0.2, -0.77), rgb(255, 180, 60), { neon = true }),
		P("EyeR", "Head", "Block", v3(0.35, 0.18, 0.1), cf(0.35, 0.2, -0.77), rgb(255, 180, 60), { neon = true }),
		P("ShoulderL", "LeftUpperArm", "Block", v3(1.5, 1.2, 1.5), cf(0, 0.35, 0), rgb(120, 118, 130)),
		P("ShoulderR", "RightUpperArm", "Block", v3(1.5, 1.2, 1.5), cf(0, 0.35, 0), rgb(120, 118, 130)),
		P("FistL", "LeftHand", "Block", v3(1.15, 1.15, 1.15), cf(0, -0.3, 0), rgb(135, 132, 145), { anim = { kind = "bob", amp = 0.08, speed = 2 } }),
		P("FistR", "RightHand", "Block", v3(1.15, 1.15, 1.15), cf(0, -0.3, 0), rgb(135, 132, 145), { anim = { kind = "bob", amp = 0.08, speed = 2, phase = 3 } }),
		P("ChestRune", "UpperTorso", "Disc", v3(0.95, 0.95, 0.1), cf(0, 0.15, -0.85), FIRE, { neon = true, anim = { kind = "pulse", amp = 0.12, speed = 2.5 } }),
		P("RuneArmL", "LeftLowerArm", "Block", v3(0.15, 0.7, 0.3), cf(-0.4, 0, -0.1), rgb(90, 220, 255), { neon = true }),
		P("RuneArmR", "RightLowerArm", "Block", v3(0.15, 0.7, 0.3), cf(0.4, 0, -0.1), rgb(90, 220, 255), { neon = true }),
		P("BackCrystal", "UpperTorso", "Block", v3(0.7, 1.4, 0.7), cf(0, 0.6, 1.0) * CFrame.Angles(0, rad(45), 0), FIRE, { neon = true, trans = 0.2 }),
	},
	fx = { { on = "ChestRune", kind = "spark", color = FIRE, rate = 5, aura = true } },
	light = FIRE,
	halo = FIRE,
}

CreatureSpecs.hedge_fund_hank = { -- Phoenix (E): a fire bird with wings of flame
	hideBody = true,
	skin = EMBER_RED,
	props = {
		P("Body", "LowerTorso", "Ball", v3(1.9, 1.7, 2.5), cf(0, 0.2, 0.1), rgb(235, 70, 40)),
		P("Breast", "LowerTorso", "Ball", v3(1.4, 1.3, 1.6), cf(0, 0.0, -0.5), rgb(255, 170, 60)),
		P("Head", "LowerTorso", "Ball", v3(1.1, 1.1, 1.1), cf(0, 1.25, -1.2), rgb(240, 80, 45)),
		P("Beak", "LowerTorso", "Block", v3(0.3, 0.3, 0.65), cf(0, 1.15, -1.9), rgb(255, 215, 80)),
		P("EyeL", "LowerTorso", "Ball", v3(0.2, 0.2, 0.2), cf(-0.35, 1.4, -1.65), rgb(20, 15, 15)),
		P("EyeR", "LowerTorso", "Ball", v3(0.2, 0.2, 0.2), cf(0.35, 1.4, -1.65), rgb(20, 15, 15)),
		P("Crest1", "LowerTorso", "Block", v3(0.15, 0.8, 0.3), cf(0, 2.05, -1.1), FLAME, { neon = true, anim = { kind = "swing", axis = "X", amp = 10, speed = 5 } }),
		P(
			"Crest2",
			"LowerTorso",
			"Block",
			v3(0.15, 0.6, 0.3),
			cf(0, 1.95, -0.8) * CFrame.Angles(rad(25), 0, 0),
			FIRE,
			{ neon = true, anim = { kind = "swing", axis = "X", amp = 10, speed = 5, phase = 1 } }
		),
		P("LegL", "LowerTorso", "Block", v3(0.22, 2.2, 0.22), cf(-0.5, -1.55, -0.1), rgb(255, 215, 80)),
		P("LegR", "LowerTorso", "Block", v3(0.22, 2.2, 0.22), cf(0.5, -1.55, -0.1), rgb(255, 215, 80)),
		P(
			"WingL",
			"LowerTorso",
			"Block",
			v3(2.6, 0.12, 1.9),
			cf(-2.2, 0.7, 0.2),
			rgb(255, 100, 40),
			{ neon = true, trans = 0.1, anim = { kind = "swing", axis = "Z", amp = 28, speed = 3.4, pivot = cf(-0.9, 0.7, 0) } }
		),
		P(
			"WingTipL",
			"LowerTorso",
			"Block",
			v3(2.2, 0.1, 1.5),
			cf(-4.3, 0.7, 0.3),
			FLAME,
			{ neon = true, trans = 0.3, anim = { kind = "swing", axis = "Z", amp = 28, speed = 3.4, pivot = cf(-0.9, 0.7, 0) } }
		),
		P(
			"WingR",
			"LowerTorso",
			"Block",
			v3(2.6, 0.12, 1.9),
			cf(2.2, 0.7, 0.2),
			rgb(255, 100, 40),
			{ neon = true, trans = 0.1, anim = { kind = "swing", axis = "Z", amp = -28, speed = 3.4, pivot = cf(0.9, 0.7, 0) } }
		),
		P(
			"WingTipR",
			"LowerTorso",
			"Block",
			v3(2.2, 0.1, 1.5),
			cf(4.3, 0.7, 0.3),
			FLAME,
			{ neon = true, trans = 0.3, anim = { kind = "swing", axis = "Z", amp = -28, speed = 3.4, pivot = cf(0.9, 0.7, 0) } }
		),
		P(
			"TailA",
			"LowerTorso",
			"Block",
			v3(0.5, 0.1, 2.4),
			cf(0, 0.1, 2.2),
			rgb(255, 120, 40),
			{ neon = true, trans = 0.1, anim = { kind = "swing", axis = "Y", amp = 12, speed = 2.2, pivot = cf(0, 0.1, 1.0) } }
		),
		P(
			"TailB",
			"LowerTorso",
			"Block",
			v3(0.5, 0.1, 2.2),
			cf(-0.5, 0.1, 2.1) * CFrame.Angles(0, rad(-12), 0),
			FLAME,
			{ neon = true, trans = 0.2, anim = { kind = "swing", axis = "Y", amp = 12, speed = 2.2, phase = 1, pivot = cf(0, 0.1, 1.0) } }
		),
		P(
			"TailC",
			"LowerTorso",
			"Block",
			v3(0.5, 0.1, 2.2),
			cf(0.5, 0.1, 2.1) * CFrame.Angles(0, rad(12), 0),
			FLAME,
			{ neon = true, trans = 0.2, anim = { kind = "swing", axis = "Y", amp = 12, speed = 2.2, phase = 2, pivot = cf(0, 0.1, 1.0) } }
		),
	},
	fx = {
		{ on = "WingTipL", kind = "flame", color = FIRE, rate = 8, size = 1.1, aura = true },
		{ on = "WingTipR", kind = "flame", color = FIRE, rate = 8, size = 1.1, aura = true },
		{ on = "Body", kind = "spark", color = FLAME, rate = 5, aura = true },
	},
	light = FIRE,
}

CreatureSpecs.oil_baron_oswald = { -- Flame Archmage (L): Ignis's champion; staff spells, orbiting runes
	scale = 1.3,
	skin = SKIN,
	outfit = outfit({ top = ROBE, waist = rgb(255, 200, 70), arms = ROBE, legs = rgb(120, 30, 30), feet = rgb(90, 25, 25) }),
	props = {
		P("Brim", "Head", "Cylinder", v3(3.1, 0.14, 3.1), cf(0, 0.5, 0), rgb(120, 28, 30)),
		P("Hat1", "Head", "Cylinder", v3(1.9, 0.9, 1.9), cf(0, 1.0, 0), rgb(150, 36, 36)),
		P("Hat2", "Head", "Cylinder", v3(1.35, 0.9, 1.35), cf(0, 1.85, 0), rgb(150, 36, 36)),
		P("Hat3", "Head", "Cylinder", v3(0.8, 0.9, 0.8), cf(0.1, 2.7, 0), rgb(150, 36, 36)),
		P("HatBand", "Head", "Cylinder", v3(2.0, 0.22, 2.0), cf(0, 0.68, 0), rgb(255, 200, 70), { mat = METAL }),
		P("HatFlame", "Head", "Ball", v3(0.5, 0.9, 0.5), cf(0.1, 3.55, 0), FLAME, { neon = true, anim = { kind = "pulse", amp = 0.2, speed = 6 } }),
		P("Beard", "Head", "Block", v3(1.1, 1.0, 0.4), cf(0, -0.75, -0.5), rgb(245, 245, 250)),
		P("Skirt", "LowerTorso", "Block", v3(2.2, 2.7, 1.4), cf(0, -1.7, 0), rgb(140, 32, 32)),
		P("Mantle", "UpperTorso", "Block", v3(2.7, 0.7, 1.7), cf(0, 0.85, 0), rgb(255, 200, 70), { mat = METAL }),
		P("MantleBadge", "UpperTorso", "Disc", v3(0.7, 0.7, 0.1), cf(0, 0.1, -0.7), rgb(255, 200, 70), { neon = true }),
		P("StaffShaft", "RightHand", "Cylinder", v3(0.24, 5.4, 0.24), cf(0, 1.9, -0.45), rgb(90, 55, 35), { anim = { kind = "swing", axis = "X", amp = 8, speed = 1.4 } }),
		P(
			"StaffRing",
			"RightHand",
			"Cylinder",
			v3(1.4, 0.1, 1.4),
			cf(0, 4.6, -0.45),
			rgb(255, 200, 70),
			{ neon = true, anim = { kind = "swing", axis = "X", amp = 8, speed = 1.4 } }
		),
		P("StaffOrb", "RightHand", "Ball", v3(1.0, 1.0, 1.0), cf(0, 4.9, -0.45), FIRE, { neon = true, anim = { kind = "pulse", amp = 0.15, speed = 3 } }),
		P("RuneA", "UpperTorso", "Block", v3(0.5, 0.5, 0.12), cf(2.4, 0.4, 0), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 70, pivot = cf(0, 0, 0) } }),
		P("RuneB", "UpperTorso", "Block", v3(0.5, 0.5, 0.12), cf(-1.2, 1.4, 2.1), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 70, pivot = cf(0, 0, 0) } }),
		P("RuneC", "UpperTorso", "Block", v3(0.5, 0.5, 0.12), cf(-1.2, -0.6, -2.1), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 70, pivot = cf(0, 0, 0) } }),
	},
	fx = {
		{ on = "StaffOrb", kind = "flame", color = FIRE, rate = 14, size = 1.2, aura = true },
		{ on = "StaffOrb", kind = "spark", color = FLAME, rate = 8, aura = true },
	},
	light = FIRE,
	halo = FIRE,
}

-- Ignis the Pyromancer (S): the Ember Academy boss; huge hat, staff, a spell circle at his feet.
CreatureSpecs.the_trillionaire = {
	scale = 2.5,
	skin = rgb(255, 214, 170),
	outfit = outfit({ top = rgb(110, 25, 40), waist = rgb(255, 190, 60), arms = rgb(110, 25, 40), legs = rgb(80, 20, 30), feet = rgb(60, 15, 20) }),
	props = {
		P("Brim", "Head", "Cylinder", v3(3.6, 0.15, 3.6), cf(0, 0.5, 0), rgb(90, 20, 35)),
		P("Hat1", "Head", "Cylinder", v3(2.1, 1.0, 2.1), cf(0, 1.05, 0), rgb(120, 28, 42)),
		P("Hat2", "Head", "Cylinder", v3(1.65, 1.0, 1.65), cf(0, 2.0, 0), rgb(120, 28, 42)),
		P("Hat3", "Head", "Cylinder", v3(1.2, 1.0, 1.2), cf(0.1, 2.95, 0), rgb(120, 28, 42)),
		P("Hat4", "Head", "Cylinder", v3(0.75, 1.0, 0.75), cf(0.25, 3.9, 0), rgb(120, 28, 42)),
		P("HatBand", "Head", "Cylinder", v3(2.25, 0.25, 2.25), cf(0, 0.7, 0), rgb(255, 200, 70), { mat = METAL }),
		P("HatGem", "Head", "Ball", v3(0.5, 0.5, 0.4), cf(0, 0.7, -1.1), FIRE, { neon = true }),
		P("HatFlame", "Head", "Ball", v3(0.6, 1.1, 0.6), cf(0.3, 4.85, 0), FLAME, { neon = true, anim = { kind = "pulse", amp = 0.22, speed = 6 } }),
		P("EyeL", "Head", "Disc", v3(0.25, 0.25, 0.08), cf(-0.3, 0.1, -0.62), FLAME, { neon = true }),
		P("EyeR", "Head", "Disc", v3(0.25, 0.25, 0.08), cf(0.3, 0.1, -0.62), FLAME, { neon = true }),
		P("BeardFlame", "Head", "Block", v3(1.0, 1.2, 0.35), cf(0, -0.8, -0.5), FIRE, { neon = true, trans = 0.15, anim = { kind = "pulse", amp = 0.1, speed = 4 } }),
		P("Robe", "LowerTorso", "Block", v3(2.3, 2.8, 1.5), cf(0, -1.7, 0), rgb(90, 20, 32)),
		P("RobeHem", "LowerTorso", "Block", v3(2.4, 0.3, 1.6), cf(0, -3.0, 0), rgb(255, 190, 60), { neon = true }),
		P("SpikeL", "LeftUpperArm", "Block", v3(0.3, 1.0, 0.3), cf(-0.3, 0.9, 0) * CFrame.Angles(0, 0, rad(25)), rgb(255, 190, 60), { mat = METAL }),
		P("SpikeR", "RightUpperArm", "Block", v3(0.3, 1.0, 0.3), cf(0.3, 0.9, 0) * CFrame.Angles(0, 0, rad(-25)), rgb(255, 190, 60), { mat = METAL }),
		P("Mantle", "UpperTorso", "Block", v3(2.9, 0.8, 1.8), cf(0, 0.85, 0), rgb(255, 190, 60), { mat = METAL }),
		P(
			"Cape",
			"UpperTorso",
			"Block",
			v3(2.2, 3.4, 0.1),
			cf(0, -0.9, 0.85),
			rgb(130, 25, 40),
			{ anim = { kind = "swing", axis = "X", amp = 6, speed = 1.5, pivot = cf(0, 0.8, 0.85) } }
		),
		P("StaffShaft", "RightHand", "Cylinder", v3(0.28, 6.4, 0.28), cf(0, 2.4, -0.5), rgb(70, 40, 30), { anim = { kind = "swing", axis = "X", amp = 10, speed = 1.2 } }),
		P(
			"StaffClawA",
			"RightHand",
			"Block",
			v3(0.2, 1.1, 0.2),
			cf(0.35, 5.7, -0.5) * CFrame.Angles(0, 0, rad(-20)),
			rgb(255, 190, 60),
			{ mat = METAL, anim = { kind = "swing", axis = "X", amp = 10, speed = 1.2 } }
		),
		P(
			"StaffClawB",
			"RightHand",
			"Block",
			v3(0.2, 1.1, 0.2),
			cf(-0.35, 5.7, -0.5) * CFrame.Angles(0, 0, rad(20)),
			rgb(255, 190, 60),
			{ mat = METAL, anim = { kind = "swing", axis = "X", amp = 10, speed = 1.2 } }
		),
		P("StaffOrb", "RightHand", "Ball", v3(1.3, 1.3, 1.3), cf(0, 5.9, -0.5), FIRE, { neon = true, anim = { kind = "pulse", amp = 0.15, speed = 2.6 } }),
		P("StaffCore", "RightHand", "Ball", v3(0.7, 0.7, 0.7), cf(0, 5.9, -0.5), FLAME, { neon = true, anim = { kind = "pulse", amp = 0.25, speed = 5 } }),
		P("OrbitA", "UpperTorso", "Ball", v3(0.6, 0.6, 0.6), cf(2.6, 0.5, 0), FIRE, { neon = true, anim = { kind = "spin", axis = "Y", amp = 60, pivot = cf(0, 0, 0) } }),
		P("OrbitB", "UpperTorso", "Ball", v3(0.6, 0.6, 0.6), cf(-1.3, 0.5, 2.25), FIRE, { neon = true, anim = { kind = "spin", axis = "Y", amp = 60, pivot = cf(0, 0, 0) } }),
		P("OrbitC", "UpperTorso", "Ball", v3(0.6, 0.6, 0.6), cf(-1.3, 0.5, -2.25), FIRE, { neon = true, anim = { kind = "spin", axis = "Y", amp = 60, pivot = cf(0, 0, 0) } }),
		-- the spell circle at his feet: two counter-turning rings + four runes
		P("CircleOuter", "LowerTorso", "Cylinder", v3(6.6, 0.07, 6.6), cf(0, -3.15, 0), FIRE, { neon = true, trans = 0.45, anim = { kind = "spin", axis = "Y", amp = 25 } }),
		P("CircleInner", "LowerTorso", "Cylinder", v3(4.4, 0.08, 4.4), cf(0, -3.12, 0), FLAME, { neon = true, trans = 0.4, anim = { kind = "spin", axis = "Y", amp = -40 } }),
		P("CircleRuneA", "LowerTorso", "Block", v3(0.7, 0.08, 0.7), cf(3.0, -3.1, 0), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 25 } }),
		P("CircleRuneB", "LowerTorso", "Block", v3(0.7, 0.08, 0.7), cf(-3.0, -3.1, 0), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 25 } }),
		P("CircleRuneC", "LowerTorso", "Block", v3(0.7, 0.08, 0.7), cf(0, -3.1, 3.0), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 25 } }),
		P("CircleRuneD", "LowerTorso", "Block", v3(0.7, 0.08, 0.7), cf(0, -3.1, -3.0), FLAME, { neon = true, anim = { kind = "spin", axis = "Y", amp = 25 } }),
	},
	fx = {
		{ on = "StaffOrb", kind = "flame", color = FIRE, rate = 18, size = 1.6, aura = true },
		{ on = "StaffCore", kind = "spark", color = FLAME, rate = 12, aura = true },
		{ on = "CircleOuter", kind = "flame", color = FIRE, rate = 8, size = 0.8, aura = true },
		{ on = "HatFlame", kind = "smoke", color = rgb(90, 60, 60), rate = 3, aura = true },
	},
	light = FIRE,
}

-- ================================ POLISH PASS (owner: every creature) ================================
-- Shared kit: every list below returns props; POLISH[id] (bottom) says which pieces each creature gets, so the look
-- stays data-driven. Rules: dark base + ONE bright accent + metal trim, never one colour head to toe; hands and feet get
-- their own colour (gloves, boots); faces stay visible (helmets are open caps, visors sit on the forehead).
local Kit = {}
local INK = rgb(26, 28, 40)

local function lay(cfr: CFrame): CFrame -- a standing cylinder laid along the hand's forward axis
	return cfr * CFrame.Angles(rad(90), 0, 0)
end

function Kit.scarf(color: Color3): { Prop }
	return {
		P("ScarfBand", "UpperTorso", "Block", v3(2.1, 0.32, 1.12), cf(0, 0.72, 0), color),
		P(
			"ScarfTail",
			"UpperTorso",
			"Block",
			v3(0.42, 1.2, 0.12),
			cf(0.5, 0.15, 0.6),
			color,
			{ anim = { kind = "swing", axis = "X", amp = 8, speed = 2.4, pivot = cf(0.5, 0.7, 0.6) } }
		),
	}
end

function Kit.sash(color: Color3): { Prop }
	return { P("Sash", "UpperTorso", "Block", v3(2.6, 0.34, 0.1), cf(0, 0.05, -0.54) * CFrame.Angles(0, 0, rad(38)), color) }
end

function Kit.belt(color: Color3, buckle: Color3): { Prop }
	return {
		P("Belt", "LowerTorso", "Block", v3(2.08, 0.34, 1.08), cf(0, -0.02, 0), color),
		P("Buckle", "LowerTorso", "Block", v3(0.42, 0.3, 0.1), cf(0, -0.02, -0.56), buckle, { mat = METAL }),
	}
end

function Kit.badge(color: Color3): { Prop }
	return { P("Badge", "UpperTorso", "Disc", v3(0.42, 0.42, 0.08), cf(0.58, 0.38, -0.54), color, { mat = METAL }) }
end

function Kit.pads(color: Color3): { Prop }
	return {
		P("PadL", "LeftUpperArm", "Ball", v3(0.95, 0.56, 0.95), cf(0, 0.38, 0), color),
		P("PadR", "RightUpperArm", "Ball", v3(0.95, 0.56, 0.95), cf(0, 0.38, 0), color),
	}
end

-- A flowing cape in three widening tiers with a bright hem (stepped blocks that sway).
function Kit.cape(color: Color3, hem: Color3, w: number, h: number): { Prop }
	local out: { Prop } = {}
	local step = h / 3
	for i = 1, 3 do
		table.insert(
			out,
			P(
				"Cape" .. i,
				"UpperTorso",
				"Block",
				v3(w * (0.82 + 0.16 * i), step, 0.1),
				cf(0, 0.6 - step * (i - 0.5), 0.56 + 0.07 * i),
				color,
				{ anim = { kind = "swing", axis = "X", amp = 3 + 3 * i, speed = 1.8, phase = i * 0.4, pivot = cf(0, 0.7, 0.62) } }
			)
		)
	end
	table.insert(
		out,
		P(
			"CapeHem",
			"UpperTorso",
			"Block",
			v3(w * 1.3, 0.16, 0.12),
			cf(0, 0.6 - h, 0.62 + 0.28),
			hem,
			{ anim = { kind = "swing", axis = "X", amp = 12, speed = 1.8, phase = 1.6, pivot = cf(0, 0.7, 0.62) } }
		)
	)
	return out
end

-- A real sword on the right hand: grip, pommel, crossguard with drooping ends, tapered blade with a diamond tip and an
-- optional Neon fuller. Returns the props and a trail emitter for the swing.
function Kit.sword(o: { name: string, len: number, w: number, blade: Color3, edge: Color3?, guard: Color3, grip: Color3, amp: number?, speed: number? }): ({ Prop }, Fx)
	local anim = { kind = "swing", axis = "X", amp = o.amp or 40, speed = o.speed or 2.0 }
	local y = -0.02
	local out: { Prop } = {
		P("Grip", "RightHand", "Cylinder", v3(0.22, 0.85, 0.22), lay(cf(0, y, 0.1)), o.grip, { anim = anim }),
		P("Pommel", "RightHand", "Ball", v3(0.34, 0.34, 0.34), cf(0, y, 0.55), o.guard, { mat = METAL, anim = anim }),
		P("Guard", "RightHand", "Block", v3(1.15, 0.16, 0.2), cf(0, y, -0.4), o.guard, { mat = METAL, anim = anim }),
		P("GuardL", "RightHand", "Block", v3(0.16, 0.5, 0.2), cf(-0.58, y - 0.14, -0.4), o.guard, { mat = METAL, anim = anim }),
		P("GuardR", "RightHand", "Block", v3(0.16, 0.5, 0.2), cf(0.58, y - 0.14, -0.4), o.guard, { mat = METAL, anim = anim }),
		P(o.name, "RightHand", "Block", v3(0.14, o.w, o.len), cf(0, y, -0.5 - o.len / 2), o.blade, { mat = METAL, anim = anim }),
		P("BladeTip", "RightHand", "Block", v3(0.14, o.w * 0.72, o.w * 0.72), cf(0, y, -0.5 - o.len) * CFrame.Angles(rad(45), 0, 0), o.blade, { mat = METAL, anim = anim }),
	}
	if o.edge then
		table.insert(out, P("BladeEdge", "RightHand", "Block", v3(0.18, o.w * 0.22, o.len * 0.92), cf(0, y, -0.5 - o.len / 2), o.edge, { neon = true, anim = anim }))
	end
	return out, { on = o.name, kind = "spark", color = o.edge or o.blade, rate = 9, at = v3(0, 0, -o.len / 2), size = 0.8 }
end

-- A shield on the left forearm: rim, face, emblem disc and a boss.
function Kit.shield(o: { w: number, h: number, face: Color3, rim: Color3, emblem: Color3, at: CFrame, neon: boolean? }): { Prop }
	local anim = { kind = "push", axis = "Z", amp = 0.5, speed = 1.5 }
	return {
		P("ShieldRim", "LeftLowerArm", "Block", v3(o.w + 0.35, o.h + 0.35, 0.2), o.at * cf(0, 0, 0.06), o.rim, { mat = METAL, anim = anim }),
		P("Shield", "LeftLowerArm", "Block", v3(o.w, o.h, 0.26), o.at, o.face, { anim = anim }),
		P("ShieldEmblem", "LeftLowerArm", "Disc", v3(o.w * 0.55, o.w * 0.55, 0.1), o.at * cf(0, 0, -0.16), o.emblem, { neon = o.neon, mat = METAL, anim = anim }),
		P("ShieldBoss", "LeftLowerArm", "Ball", v3(0.42, 0.42, 0.3), o.at * cf(0, 0, -0.24), o.rim, { mat = METAL, anim = anim }),
	}
end

-- Hammer: grooved head with Neon grooves and glowing strike faces, brass caps and handle rings.
function Kit.hammer(o: { head: Color3, glow: Color3, brass: Color3, handle: Color3 }): ({ Prop }, Fx)
	local anim = { kind = "swing", axis = "X", amp = 55, speed = 2.3 }
	local y = 2.0
	local out: { Prop } = {
		P("HammerHandle", "RightHand", "Cylinder", v3(0.28, 2.7, 0.28), cf(0, 0.65, -0.3), o.handle, { anim = anim }),
		P("HandleRingA", "RightHand", "Cylinder", v3(0.36, 0.14, 0.36), cf(0, 0.1, -0.3), o.brass, { mat = METAL, anim = anim }),
		P("HandleRingB", "RightHand", "Cylinder", v3(0.36, 0.14, 0.36), cf(0, 1.2, -0.3), o.brass, { mat = METAL, anim = anim }),
		P("HammerHead", "RightHand", "Block", v3(1.9, 1.05, 1.05), cf(0, y, -0.3), o.head, { mat = METAL, anim = anim }),
		P("GrooveA", "RightHand", "Block", v3(0.1, 1.12, 1.12), cf(-0.4, y, -0.3), o.glow, { neon = true, anim = anim }),
		P("GrooveB", "RightHand", "Block", v3(0.1, 1.12, 1.12), cf(0.4, y, -0.3), o.glow, { neon = true, anim = anim }),
		P("HammerCapL", "RightHand", "Block", v3(0.3, 1.3, 1.3), cf(-1.05, y, -0.3), o.brass, { mat = METAL, anim = anim }),
		P("HammerCapR", "RightHand", "Block", v3(0.3, 1.3, 1.3), cf(1.05, y, -0.3), o.brass, { mat = METAL, anim = anim }),
		P("HammerGlow", "RightHand", "Block", v3(0.12, 0.8, 0.8), cf(-1.25, y, -0.3), o.glow, { neon = true, anim = anim }),
	}
	return out, { on = "HammerHead", kind = "spark", color = o.glow, rate = 8, at = v3(0, 0, 0), size = 1 }
end

-- Layered armour. groups picks pieces: helm shoulders chest belt gauntlets boots cape. tier 1 = Epic, 2 = Legendary, 3 = Secret
-- (more spikes, bigger crest). Helmets are open caps: the face and its smile stay visible.
export type Armor = {
	main: Color3,
	trim: Color3,
	accent: Color3,
	glow: Color3,
	tier: number,
	crest: string?, -- plume horns fins spikes none
	crestColor: Color3?,
	cape: Color3?,
	capeHem: Color3?,
	helmName: string?,
	groups: { string }?,
	belt: Color3?,
}

function Kit.armor(o: Armor): { Prop }
	local out: { Prop } = {}
	local groups = {}
	local wanted: { string } = o.groups or { "helm", "shoulders", "chest", "belt", "gauntlets", "boots", "cape" }
	for _, g in wanted do
		groups[g] = true
	end
	local function add(p: Prop)
		table.insert(out, p)
	end
	local t = o.tier
	local crestColor = o.crestColor or o.trim
	if groups.helm then
		add(P(o.helmName or "HelmCap", "Head", "Ball", v3(1.5, 0.95, 1.4), cf(0, 0.72, 0.02), o.main, { mat = METAL }))
		add(P("HelmBrim", "Head", "Cylinder", v3(1.4, 0.12, 1.3), cf(0, 0.46, 0.02), o.trim, { mat = METAL }))
		add(P("CheekL", "Head", "Block", v3(0.14, 0.7, 0.5), cf(-0.72, -0.02, 0.15), o.main, { mat = METAL }))
		add(P("CheekR", "Head", "Block", v3(0.14, 0.7, 0.5), cf(0.72, -0.02, 0.15), o.main, { mat = METAL }))
		add(P("VisorGlow", "Head", "Block", v3(0.9, 0.09, 0.08), cf(0, 0.56, -0.62), o.glow, { neon = true }))
		local crest = o.crest or "plume"
		if crest == "plume" then
			add(P("Plume", "Head", "Block", v3(0.22, 0.7 + 0.25 * t, 1.3), cf(0, 1.25, 0.1), crestColor, { anim = { kind = "swing", axis = "X", amp = 9, speed = 2.2 } }))
			add(P("PlumeBase", "Head", "Block", v3(0.3, 0.3, 0.6), cf(0, 1.05, -0.1), o.trim, { mat = METAL }))
		elseif crest == "horns" then
			for _, s in { -1, 1 } do
				add(P("HornBase" .. s, "Head", "Block", v3(0.3, 0.55, 0.3), cf(s * 0.58, 0.95, 0) * CFrame.Angles(0, 0, rad(-s * 25)), crestColor))
				add(P("HornTip" .. s, "Head", "Wedge", v3(0.26, 0.5 + 0.2 * t, 0.3), cf(s * 0.9, 1.4 + 0.08 * t, 0) * CFrame.Angles(0, 0, rad(-s * 50)), crestColor))
			end
		elseif crest == "fins" then
			add(
				P(
					"Fin",
					"Head",
					"Block",
					v3(0.18, 1.1, 0.9),
					cf(0, 1.0, 0.45) * CFrame.Angles(rad(-25), 0, 0),
					crestColor,
					{ anim = { kind = "swing", axis = "X", amp = 5, speed = 2.0 } }
				)
			)
			for _, s in { -1, 1 } do
				add(P("FinSide" .. s, "Head", "Block", v3(0.14, 0.7, 0.6), cf(s * 0.7, 0.7, 0.4) * CFrame.Angles(rad(-20), 0, rad(-s * 25)), crestColor))
			end
		elseif crest == "spikes" then
			for i = -1, 1 do
				add(P("HelmSpike" .. i, "Head", "Wedge", v3(0.26, 0.6 + 0.15 * t, 0.36), cf(0, 1.12, i * 0.38), crestColor))
			end
		end
	end
	if groups.shoulders then
		for _, s in { -1, 1 } do
			local side = if s < 0 then "Left" else "Right"
			add(P("Pauldron" .. s, side .. "UpperArm", "Ball", v3(1.05 + 0.1 * t, 0.72 + 0.06 * t, 1.05 + 0.1 * t), cf(0, 0.38, 0), o.main, { mat = METAL }))
			add(P("PauldronRim" .. s, side .. "UpperArm", "Cylinder", v3(1.05 + 0.1 * t, 0.1, 1.05 + 0.1 * t), cf(0, 0.12, 0), o.trim, { mat = METAL }))
			add(P("PauldronSpike" .. s, side .. "UpperArm", "Wedge", v3(0.26, 0.45 + 0.16 * t, 0.26), cf(0, 0.78 + 0.05 * t, 0), o.trim, { mat = METAL }))
			if t >= 2 then
				add(
					P(
						"PauldronSpikeB" .. s,
						side .. "UpperArm",
						"Wedge",
						v3(0.28, 0.5, 0.28),
						cf(s * 0.62, 0.8, 0) * CFrame.Angles(0, 0, rad(-s * 45)),
						o.accent,
						{ neon = t >= 3 }
					)
				)
			end
		end
	end
	if groups.chest then
		add(P("ChestPlate", "UpperTorso", "Block", v3(2.15, 1.5, 1.25), cf(0, 0.05, 0), o.main, { mat = METAL }))
		add(P("Collar", "UpperTorso", "Block", v3(2.2, 0.26, 1.3), cf(0, 0.72, 0), o.trim, { mat = METAL }))
		add(P("Emblem", "UpperTorso", "Disc", v3(0.8, 0.8, 0.1), cf(0, 0.15, -0.66), o.accent, { neon = t >= 2, mat = METAL }))
		add(P("ChestStripeL", "UpperTorso", "Block", v3(0.14, 1.3, 0.12), cf(-0.75, 0.05, -0.66), o.trim, { mat = METAL }))
		add(P("ChestStripeR", "UpperTorso", "Block", v3(0.14, 1.3, 0.12), cf(0.75, 0.05, -0.66), o.trim, { mat = METAL }))
		if t >= 2 then
			add(P("BackSpikeL", "UpperTorso", "Wedge", v3(0.3, 0.8, 0.3), cf(-0.6, 0.5, 0.75) * CFrame.Angles(rad(30), 0, 0), o.trim, { mat = METAL }))
			add(P("BackSpikeR", "UpperTorso", "Wedge", v3(0.3, 0.8, 0.3), cf(0.6, 0.5, 0.75) * CFrame.Angles(rad(30), 0, 0), o.trim, { mat = METAL }))
		end
	end
	if groups.belt then
		for _, p in Kit.belt(o.belt or INK, o.trim) do
			add(p)
		end
		add(P("TassetL", "LowerTorso", "Block", v3(0.85, 0.9, 0.18), cf(-0.55, -0.5, -0.5), o.main, { mat = METAL }))
		add(P("TassetR", "LowerTorso", "Block", v3(0.85, 0.9, 0.18), cf(0.55, -0.5, -0.5), o.main, { mat = METAL }))
	end
	if groups.gauntlets then
		for _, s in { "Left", "Right" } do
			add(P("Gauntlet" .. s, s .. "LowerArm", "Block", v3(1.14, 0.85, 1.14), cf(0, -0.02, 0), o.main, { mat = METAL }))
			add(P("GauntletRim" .. s, s .. "LowerArm", "Cylinder", v3(1.24, 0.12, 1.24), cf(0, 0.36, 0), o.trim, { mat = METAL }))
		end
	end
	if groups.boots then
		for _, s in { "Left", "Right" } do
			add(P("Boot" .. s, s .. "Foot", "Block", v3(1.15, 0.55, 1.4), cf(0, 0.1, -0.1), o.main, { mat = METAL }))
			add(P("Greave" .. s, s .. "LowerLeg", "Block", v3(1.1, 0.85, 1.1), cf(0, 0, 0), o.main, { mat = METAL }))
			if t >= 2 then
				add(P("Knee" .. s, s .. "UpperLeg", "Ball", v3(0.95, 0.95, 0.95), cf(0, -0.45, -0.4), o.trim, { mat = METAL }))
			end
		end
	end
	if groups.cape and o.cape then
		for _, p in Kit.cape(o.cape, o.capeHem or o.trim, 1.9 + 0.1 * t, 3.0 + 0.4 * t) do
			add(p)
		end
	end
	return out
end

-- A bow in the left hand: grip, three curved limb segments per side bending toward the archer, and a taut string.
function Kit.bow(wood: Color3, string: Color3): { Prop }
	local out: { Prop } = {
		P("BowMid", "LeftHand", "Block", v3(0.2, 0.9, 0.22), cf(0, 0, -0.6), wood),
		P("BowString", "LeftHand", "Block", v3(0.04, 3.3, 0.04), cf(0, 0, -0.18), string, { anim = { kind = "push", axis = "Z", amp = 0.28, speed = 2.6 } }),
	}
	local segs = { { 0.62, -0.56, 12 }, { 1.2, -0.45, 28 }, { 1.7, -0.27, 46 } } -- y, z, tilt toward the archer (degrees)
	for i, sg in segs do
		for _, d in { 1, -1 } do
			table.insert(
				out,
				P("BowLimb" .. i .. (if d > 0 then "T" else "B"), "LeftHand", "Block", v3(0.15, 0.7, 0.18), cf(0, d * sg[1], sg[2]) * CFrame.Angles(rad(d * sg[3]), 0, 0), wood)
			)
		end
	end
	return out
end

local function sharkTeeth(): { Prop }
	local out: { Prop } = {}
	for i = -2, 2 do
		table.insert(out, P("Tooth" .. i, "Head", "Wedge", v3(0.16, 0.28, 0.16), cf(i * 0.22, 0.27, -0.68), rgb(255, 255, 255)))
	end
	return out
end

type Polish = {
	outfit: { top: Color3?, waist: Color3?, arms: Color3?, hands: Color3?, legs: Color3?, feet: Color3? }?,
	skin: Color3?,
	drop: { string }?,
	recolor: { [string]: any }?, -- name -> Color3 or { color, neon }
	tweak: { [string]: { [string]: any } }?,
	add: { { Prop } }?,
	fx: { Fx }?,
	set: { [string]: any }?, -- spec fields: light, halo, sound
}

-- Face catalogue (free Creator Store face decals, each checked to load in Studio on 2026-10-16; the ids are the IMAGE ids the
-- decals resolve to). One field per creature below (`faceOf`), change them here. The builder falls back to the default smile
-- if one ever fails to load.
local FACES = {
	angry = "rbxassetid://91718245554912", -- angry frown, brows down
	angry2 = "rbxassetid://115235921239202", -- grumpy frown
	stern = "rbxassetid://15539331496", -- serious, heavy brows
	suspicious = "rbxassetid://80659697191573", -- narrow eyes, scheming frown
	happy = "rbxassetid://155406534", -- big goofy grin
	cool = "rbxassetid://139147174838791", -- sunglasses and a smirk
	scholar = "rbxassetid://308995820", -- round glasses, calm
	neutral = "rbxassetid://926088892", -- dots and a line
}
local faceOf = {
	broke_bob = "happy",
	delivery_dave = "happy",
	training_dummy = "neutral",
	street_hustler = "cool",
	business_betty = "happy",
	security_sam = "stern",
	crypto_carl = "angry2",
	ceo_chad = "cool",
	mystery_millionaire = "angry",
	puffer_guard = "stern",
	mermaid_mage = "scholar",
	shark_knight = "angry",
	tide_warden = "stern",
	butler_barnaby = "happy",
	bookling = "scholar",
	chef_pierre = "happy",
	oil_baron_oswald = "scholar",
	the_trillionaire = "suspicious",
}
local YELLOW = rgb(245, 205, 48)
local NEON_CYAN = rgb(80, 255, 230)

local function sword(name: string, len: number, w: number, blade: Color3, edge: Color3?, guard: Color3, grip: Color3, amp: number?): ({ Prop }, Fx)
	return Kit.sword({ name = name, len = len, w = w, blade = blade, edge = edge, guard = guard, grip = grip, amp = amp })
end
local function swordParts(...: any): { Prop }
	local props = sword(...)
	return props
end

local function polishList(): { [string]: Polish }
	local L: { [string]: Polish } = {}
	local WHITE = rgb(255, 255, 255)

	-- ===== KNIGHT'S KEEP =====
	L.broke_bob = { -- Rookie Squire: blue tunic, yellow scarf, practice sword, open helmet
		outfit = { top = rgb(60, 110, 210), waist = rgb(70, 50, 40), arms = rgb(60, 110, 210), hands = rgb(120, 80, 44), legs = rgb(50, 56, 80), feet = rgb(34, 30, 40) },
		drop = { "SwordBlade", "SwordGuard", "BeltBuckle" },
		tweak = { Helmet = { size = v3(1.5, 1.0, 1.5), at = cf(0, 0.62, 0.04) }, HelmetRim = { at = cf(0, 0.3, 0.04) } },
		add = { Kit.scarf(rgb(255, 200, 50)), Kit.belt(rgb(70, 46, 30), GOLD), swordParts("SwordBlade", 2.1, 0.42, rgb(205, 212, 226), nil, GOLD, LEATHER, 28) },
	}
	L.delivery_dave = { -- Scroll Page: green tunic, indigo legs, red boots, shaped beret, ribbon scroll
		outfit = { top = rgb(40, 160, 110), waist = rgb(60, 50, 40), arms = rgb(40, 160, 110), hands = rgb(245, 240, 225), legs = rgb(60, 56, 100), feet = rgb(200, 60, 60) },
		drop = { "PageCap" },
		add = {
			{
				P("PageCap", "Head", "Ball", v3(1.55, 0.65, 1.55), cf(0, 0.62, 0.02), rgb(60, 90, 200)),
				P("BeretStalk", "Head", "Block", v3(0.14, 0.25, 0.14), cf(0.1, 0.98, 0), rgb(255, 200, 50)),
			},
			Kit.belt(rgb(120, 70, 30), GOLD),
			Kit.badge(GOLD),
		},
	}
	L.training_dummy = { -- Training Dummy: red patched shirt, denim legs, straw hat with a band
		outfit = { top = rgb(180, 60, 50), waist = rgb(60, 90, 150), arms = rgb(180, 60, 50), hands = rgb(235, 205, 100), legs = rgb(60, 90, 150), feet = rgb(60, 44, 36) },
		tweak = { SackHat = { shape = "Cylinder", size = v3(1.9, 0.14, 1.9) }, SackHatTop = { shape = "Ball", size = v3(1.0, 0.8, 1.0) } },
		recolor = { SackHat = rgb(230, 195, 85), SackHatTop = rgb(230, 195, 85) },
		add = {
			{ P("SackBand", "Head", "Cylinder", v3(1.04, 0.14, 1.04), cf(0, 0.75, 0), rgb(60, 170, 90)) },
			Kit.scarf(rgb(60, 180, 90)),
			Kit.belt(rgb(200, 160, 70), rgb(150, 60, 40)),
		},
	}
	L.street_hustler = { -- Apple Archer (R)
		outfit = { top = rgb(34, 120, 70), waist = rgb(70, 50, 36), arms = rgb(34, 120, 70), hands = rgb(210, 170, 60), legs = rgb(56, 60, 80), feet = rgb(48, 34, 28) },
		drop = { "BowMid", "BowTop", "BowBottom", "BowString" },
		add = { Kit.sash(rgb(230, 60, 50)), Kit.pads(rgb(120, 76, 40)), Kit.belt(rgb(70, 50, 36), GOLD), Kit.bow(rgb(150, 98, 52), rgb(245, 245, 238)) },
		fx = { { on = "Apple", kind = "spark", color = rgb(255, 90, 80), rate = 2 } },
	}
	L.business_betty = { -- Banner Bearer (R)
		outfit = { top = rgb(200, 44, 52), waist = rgb(240, 200, 60), arms = rgb(200, 44, 52), hands = rgb(255, 210, 70), legs = rgb(40, 50, 110), feet = rgb(30, 30, 50) },
		add = { Kit.pads(rgb(255, 200, 60)), Kit.cape(rgb(40, 50, 130), GOLD, 1.8, 2.2), Kit.badge(WHITE) },
		fx = { { on = "FlagStar", kind = "spark", color = rgb(255, 230, 120), rate = 3 } },
	}
	do
		local blade, trail = sword("Sword", 2.6, 0.5, rgb(225, 232, 242), rgb(90, 200, 255), rgb(205, 212, 226), LEATHER, 35)
		local shield = Kit.shield({ w = 2.2, h = 3.0, face = rgb(40, 100, 220), rim = rgb(205, 212, 226), emblem = WHITE, at = cf(-0.45, 0.1, -0.75) })
		L.security_sam = { -- Shield Knight (E)
			outfit = { top = rgb(38, 48, 90), waist = rgb(28, 32, 60), arms = rgb(38, 48, 90), hands = STEEL, legs = rgb(28, 34, 62), feet = STEEL_D },
			drop = { "Helm", "HelmTop", "Visor", "Crest", "PauldronL", "PauldronR", "ChestPlate", "ChestStripe", "ShieldBorder", "Shield", "ShieldBoss", "Sword", "SwordGuard" },
			add = {
				Kit.armor({
					main = rgb(44, 56, 104),
					trim = rgb(205, 212, 226),
					accent = rgb(60, 170, 255),
					glow = rgb(90, 200, 255),
					tier = 1,
					crest = "plume",
					crestColor = rgb(60, 170, 255),
					cape = rgb(30, 70, 170),
					capeHem = rgb(205, 212, 226),
				}),
				shield,
				blade,
			},
			fx = { trail },
			set = { halo = rgb(80, 180, 255) },
		}
	end
	do
		local hammer, trail = Kit.hammer({ head = rgb(60, 62, 74), glow = rgb(255, 130, 30), brass = rgb(205, 160, 70), handle = rgb(110, 70, 40) })
		L.crypto_carl = { -- Forge Master (E)
			outfit = { top = rgb(46, 44, 52), waist = rgb(30, 28, 34), arms = rgb(86, 52, 40), hands = rgb(205, 160, 70), legs = rgb(34, 34, 42), feet = rgb(205, 160, 70) },
			drop = { "Goggles", "LensL", "LensR", "Apron", "ApronPocket", "Beard", "HammerHandle", "HammerHead", "HammerGlow" },
			add = {
				Kit.armor({
					main = rgb(52, 50, 60),
					trim = rgb(205, 160, 70),
					accent = rgb(255, 110, 30),
					glow = rgb(255, 140, 40),
					tier = 1,
					crest = "horns",
					crestColor = rgb(205, 160, 70),
				}),
				{
					P("Goggles", "Head", "Block", v3(1.3, 0.2, 0.12), cf(0, 0.55, -0.76), rgb(70, 50, 40)),
					P("LensL", "Head", "Disc", v3(0.36, 0.36, 0.1), cf(-0.3, 0.55, -0.82), rgb(255, 170, 60), { neon = true }),
					P("LensR", "Head", "Disc", v3(0.36, 0.36, 0.1), cf(0.3, 0.55, -0.82), rgb(255, 170, 60), { neon = true }),
					P("Apron", "LowerTorso", "Block", v3(1.5, 1.4, 0.15), cf(0, -0.7, -0.6), rgb(112, 62, 40)),
				},
				hammer,
			},
			fx = { trail },
			set = { halo = rgb(255, 120, 30) },
		}
	end
	do
		local blade, trail = sword("Blade", 3.6, 0.7, rgb(250, 250, 255), rgb(255, 230, 130), GOLD, rgb(120, 24, 36), 45)
		L.ceo_chad = { -- Golden Paladin (L): gold plate over dark-red and white under-layers
			outfit = { top = rgb(120, 24, 36), waist = rgb(90, 18, 30), arms = rgb(236, 232, 224), hands = GOLD, legs = rgb(120, 24, 36), feet = GOLD },
			drop = { "Helm", "HelmTop", "Visor", "Plume", "PauldronL", "PauldronR", "ChestPlate", "Emblem", "Cape", "Blade", "BladeGuard" },
			add = {
				Kit.armor({
					main = GOLD,
					trim = rgb(245, 245, 250),
					accent = rgb(220, 40, 50),
					glow = rgb(255, 240, 160),
					tier = 2,
					crest = "plume",
					crestColor = rgb(220, 40, 50),
					cape = rgb(150, 24, 36),
					capeHem = GOLD,
					belt = rgb(90, 18, 30),
				}),
				blade,
			},
			fx = { trail },
			set = { sound = "legendary_chime" },
		}
	end
	do
		local blade, trail = sword("Blade", 4.8, 0.95, rgb(205, 212, 226), rgb(255, 110, 30), GOLD, rgb(60, 40, 40), 35)
		local shield = Kit.shield({ w = 2.7, h = 3.6, face = rgb(100, 18, 28), rim = GOLD, emblem = rgb(255, 110, 30), at = cf(-0.55, 0.15, -0.85), neon = true })
		L.mystery_millionaire = { -- Sir Ironclad (S): dark iron, lava accents, horns
			outfit = { top = rgb(40, 42, 54), waist = rgb(28, 30, 40), arms = rgb(40, 42, 54), hands = rgb(30, 30, 36), legs = rgb(30, 32, 42), feet = rgb(20, 20, 26) },
			drop = {
				"Helm",
				"HelmTop",
				"VisorGlow",
				"Plume",
				"PauldronL",
				"PauldronR",
				"ChestPlate",
				"ChestCrest",
				"Cape",
				"ShieldRim",
				"Shield",
				"ShieldStar",
				"Blade",
				"BladeGuard",
			},
			add = {
				Kit.armor({
					main = rgb(52, 55, 70),
					trim = GOLD,
					accent = rgb(255, 100, 30),
					glow = rgb(255, 120, 40),
					tier = 3,
					crest = "horns",
					crestColor = rgb(200, 200, 210),
					cape = rgb(110, 18, 26),
					capeHem = rgb(255, 100, 30),
				}),
				shield,
				blade,
				{ -- a tall red plume on a gold crest holder, with gold trim down its spine
					P("PlumeHolder", "Head", "Block", v3(0.5, 0.45, 0.9), cf(0, 1.3, 0.05), GOLD, { mat = METAL }),
					P(
						"TallPlume",
						"Head",
						"Block",
						v3(0.34, 2.4, 1.7),
						cf(0, 2.65, 0.15),
						rgb(205, 28, 40),
						{ anim = { kind = "swing", axis = "X", amp = 10, speed = 2.0, pivot = cf(0, 1.4, 0.1) } }
					),
					P(
						"PlumeTip",
						"Head",
						"Block",
						v3(0.26, 1.1, 1.2),
						cf(0, 4.2, 0.45),
						rgb(235, 60, 50),
						{ neon = true, anim = { kind = "swing", axis = "X", amp = 16, speed = 2.0, pivot = cf(0, 1.4, 0.1) } }
					),
					P(
						"PlumeGold",
						"Head",
						"Block",
						v3(0.4, 2.2, 0.16),
						cf(0, 2.65, -0.7),
						GOLD,
						{ mat = METAL, anim = { kind = "swing", axis = "X", amp = 10, speed = 2.0, pivot = cf(0, 1.4, 0.1) } }
					),
				},
			},
			fx = { trail },
			set = { sound = "boss_roar" },
		}
	end

	-- ===== SUNKEN KINGDOM =====
	L.bubble_fish = {
		skin = YELLOW,
		outfit = { top = rgb(30, 160, 170), waist = rgb(20, 60, 110), arms = rgb(30, 160, 170), hands = rgb(255, 150, 40), legs = rgb(20, 60, 110), feet = rgb(255, 150, 40) },
		add = {
			Kit.belt(rgb(250, 200, 40), WHITE),
			{
				P("BigEyeL", "Head", "Ball", v3(0.55, 0.62, 0.3), cf(-0.3, 0.14, -0.58), WHITE),
				P("BigEyeR", "Head", "Ball", v3(0.55, 0.62, 0.3), cf(0.3, 0.14, -0.58), WHITE),
				P("PupilL", "Head", "Ball", v3(0.28, 0.36, 0.14), cf(-0.3, 0.14, -0.7), INK),
				P("PupilR", "Head", "Ball", v3(0.28, 0.36, 0.14), cf(0.3, 0.14, -0.7), INK),
				P("DorsalFin", "UpperTorso", "Wedge", v3(0.16, 1.3, 1.0), cf(0, 0.2, 0.75), rgb(255, 120, 40), { anim = { kind = "swing", axis = "X", amp = 8, speed = 3 } }),
				P("TailFin", "LowerTorso", "Block", v3(0.14, 1.0, 0.9), cf(0, -0.35, 0.8), rgb(255, 150, 40), { anim = { kind = "swing", axis = "Y", amp = 14, speed = 3.2 } }),
				P("ArmFinL", "LeftUpperArm", "Block", v3(0.1, 0.8, 0.8), cf(-0.55, -0.1, 0.1), rgb(255, 150, 40)),
				P("ArmFinR", "RightUpperArm", "Block", v3(0.1, 0.8, 0.8), cf(0.55, -0.1, 0.1), rgb(255, 150, 40)),
			},
		},
		fx = { { on = "Tank", kind = "bubble", color = rgb(190, 235, 255), rate = 8, size = 1.5, aura = true } },
	}
	L.hermit_porter = {
		outfit = { top = rgb(40, 110, 160), waist = rgb(30, 40, 90), arms = rgb(40, 110, 160), hands = rgb(240, 140, 40), legs = rgb(30, 40, 90), feet = rgb(40, 36, 50) },
		recolor = { HatBrim = rgb(250, 200, 40), HatTop = rgb(250, 200, 40), Shell = rgb(240, 130, 90), ShellStripe = rgb(255, 240, 210) },
		add = { Kit.sash(rgb(240, 120, 40)), Kit.belt(rgb(40, 40, 60), GOLD), Kit.badge(WHITE) },
	}
	L.coral_snail = {
		skin = rgb(255, 190, 200),
		outfit = { top = rgb(255, 110, 130), waist = rgb(255, 200, 60), arms = rgb(255, 110, 130), hands = rgb(255, 230, 230), legs = rgb(40, 160, 170), feet = rgb(40, 160, 170) },
		recolor = { Shell = rgb(255, 150, 70), ShellSwirl = rgb(150, 80, 200) },
		add = { Kit.belt(rgb(150, 80, 200), GOLD) },
	}
	L.puffer_guard = {
		outfit = { top = rgb(35, 70, 140), waist = rgb(30, 40, 100), arms = rgb(35, 70, 140), hands = rgb(255, 200, 60), legs = rgb(30, 40, 100), feet = rgb(240, 120, 40) },
		add = { Kit.pads(rgb(240, 120, 40)), Kit.belt(rgb(30, 40, 100), rgb(255, 200, 60)) },
		fx = { { on = "Belly", kind = "bubble", color = rgb(255, 235, 150), rate = 2 } },
	}
	L.mermaid_mage = {
		outfit = { top = rgb(130, 70, 200), waist = TEAL, arms = rgb(130, 70, 200), hands = rgb(250, 230, 255), legs = rgb(30, 90, 130), feet = TEAL },
		drop = { "Hair" },
		add = { Kit.cape(rgb(40, 170, 190), PEARL, 1.6, 2.0), Kit.badge(PEARL) },
		fx = { { on = "StaffPearl", kind = "spark", color = rgb(255, 245, 255), rate = 3 } },
	}
	do
		local blade, trail = sword("Blade", 2.8, 0.5, rgb(215, 232, 245), rgb(70, 220, 255), rgb(200, 212, 226), rgb(40, 60, 90), 40)
		local fx: { Fx } = { trail }
		L.shark_knight = { -- Shark Knight (E)
			outfit = { top = rgb(34, 52, 84), waist = rgb(24, 36, 60), arms = rgb(34, 52, 84), hands = rgb(190, 205, 220), legs = rgb(24, 38, 64), feet = rgb(190, 205, 220) },
			drop = { "SharkHood", "Snout", "Teeth", "EyeL", "EyeR", "DorsalHead", "PauldronL", "PauldronR", "Chest", "BackFin", "Blade", "Guard" },
			add = {
				Kit.armor({
					main = rgb(60, 86, 124),
					trim = rgb(200, 212, 226),
					accent = rgb(70, 220, 255),
					glow = rgb(70, 220, 255),
					tier = 1,
					crest = "fins",
					crestColor = rgb(90, 112, 140),
					cape = rgb(24, 70, 110),
					capeHem = rgb(70, 220, 255),
					helmName = "SharkHood",
				}),
				sharkTeeth(),
				{
					P("SharkEyeL", "Head", "Disc", v3(0.22, 0.22, 0.1), cf(-0.4, 0.78, -0.62), rgb(70, 220, 255), { neon = true }),
					P("SharkEyeR", "Head", "Disc", v3(0.22, 0.22, 0.1), cf(0.4, 0.78, -0.62), rgb(70, 220, 255), { neon = true }),
				},
				blade,
			},
			fx = fx,
			set = { halo = rgb(70, 200, 255) },
		}
	end
	L.pearl_seahorse = {
		recolor = {
			Belly = rgb(240, 110, 170),
			Neck = rgb(235, 100, 160),
			Snout = rgb(245, 130, 180),
			Tail1 = rgb(235, 100, 160),
			Tail2 = rgb(235, 100, 160),
			Tail3 = rgb(235, 100, 160),
			Dorsal = rgb(60, 210, 210),
			Eye = { rgb(80, 255, 230), true },
		},
		add = {
			{
				P("BellyPlate1", "LowerTorso", "Block", v3(0.8, 0.22, 0.5), cf(0, 0.3, -0.5), GOLD, { mat = METAL }),
				P("BellyPlate2", "LowerTorso", "Block", v3(0.75, 0.22, 0.5), cf(0, -0.1, -0.52), GOLD, { mat = METAL }),
				P("BellyPlate3", "LowerTorso", "Block", v3(0.7, 0.22, 0.5), cf(0, -0.5, -0.46), GOLD, { mat = METAL }),
				P("DorsalSpikeA", "LowerTorso", "Wedge", v3(0.2, 0.5, 0.3), cf(0, 0.9, 0.5), rgb(60, 210, 210), { neon = true }),
				P("DorsalSpikeB", "LowerTorso", "Wedge", v3(0.2, 0.5, 0.3), cf(0, 0.4, 0.62), rgb(60, 210, 210), { neon = true }),
				P("DorsalSpikeC", "LowerTorso", "Wedge", v3(0.2, 0.5, 0.3), cf(0, -0.1, 0.62), rgb(60, 210, 210), { neon = true }),
			},
		},
		set = { halo = rgb(255, 200, 235) },
	}
	do
		local tips = {}
		local tipAnim = { kind = "swing", axis = "X", amp = 6, speed = 1.5 }
		for i, d in { { 0, 5.95 }, { -0.5, 5.6 }, { 0.5, 5.6 } } do
			table.insert(tips, P("TridentTip" .. i, "RightHand", "Block", v3(0.16, 0.55, 0.16), cf(d[1], d[2], -0.45), rgb(90, 230, 255), { neon = true, anim = tipAnim }))
		end
		L.tide_warden = { -- Tide Warden (L)
			outfit = { top = rgb(16, 70, 110), waist = rgb(10, 44, 76), arms = rgb(16, 70, 110), hands = GOLD, legs = rgb(12, 50, 86), feet = GOLD },
			drop = { "Helm", "HelmTop", "Visor", "Chest", "Kelp" },
			recolor = { ShellPauldronL = rgb(255, 150, 130), ShellPauldronR = rgb(255, 150, 130) },
			add = {
				Kit.armor({
					main = rgb(16, 70, 110),
					trim = GOLD,
					accent = rgb(255, 110, 100),
					glow = rgb(90, 230, 255),
					tier = 2,
					crest = "none",
					cape = rgb(20, 110, 90),
					capeHem = rgb(255, 215, 100),
					groups = { "helm", "chest", "belt", "gauntlets", "boots", "cape" },
				}),
				tips,
			},
			set = { sound = "legendary_chime" },
		}
	end

	-- ===== EMBER ACADEMY =====
	L.butler_barnaby = {
		outfit = { top = rgb(235, 70, 55), waist = rgb(60, 40, 80), arms = rgb(235, 70, 55), hands = rgb(250, 235, 200), legs = rgb(60, 40, 80), feet = rgb(255, 170, 40) },
		add = { Kit.scarf(rgb(255, 215, 60)), Kit.belt(rgb(255, 200, 40), WHITE) },
	}
	L.caddie_gus = {
		skin = rgb(255, 140, 60),
		outfit = { top = rgb(255, 120, 40), waist = rgb(40, 100, 110), arms = rgb(255, 120, 40), hands = rgb(255, 220, 80), legs = rgb(40, 100, 110), feet = rgb(40, 60, 80) },
		add = { Kit.belt(rgb(40, 200, 210), WHITE) },
	}
	L.bookling = {
		outfit = { top = rgb(110, 60, 150), waist = rgb(80, 40, 110), arms = rgb(110, 60, 150), hands = rgb(255, 210, 70), legs = rgb(60, 60, 130), feet = rgb(255, 210, 70) },
		add = { { P("Bookmark", "UpperTorso", "Block", v3(0.3, 1.2, 0.1), cf(0.6, -0.5, -1.0), rgb(255, 200, 60)) }, Kit.belt(rgb(255, 200, 60), WHITE) },
	}
	L.polo_pro_penny = {
		skin = rgb(150, 100, 170),
		outfit = { top = rgb(110, 70, 150), waist = rgb(90, 50, 120), arms = rgb(110, 70, 150), hands = rgb(255, 160, 40), legs = rgb(255, 160, 40), feet = rgb(255, 160, 40) },
		add = { { P("OwlBelly", "UpperTorso", "Ball", v3(1.5, 1.4, 0.4), cf(0, -0.1, -0.5), rgb(250, 230, 190)) }, Kit.scarf(rgb(255, 160, 40)), Kit.pads(rgb(255, 160, 40)) },
	}
	L.chef_pierre = {
		outfit = { top = rgb(210, 50, 50), waist = rgb(255, 200, 70), arms = rgb(210, 50, 50), hands = rgb(255, 150, 40), legs = rgb(46, 38, 70), feet = rgb(255, 170, 40) },
		add = { Kit.pads(rgb(255, 200, 70)), Kit.cape(rgb(110, 30, 120), rgb(255, 150, 40), 1.7, 2.0) },
	}
	L.bodyguard_boris = { -- Rune Golem (E)
		skin = rgb(78, 74, 92),
		outfit = { top = rgb(86, 82, 102), waist = rgb(60, 58, 76), arms = rgb(78, 74, 92), hands = rgb(255, 190, 60), legs = rgb(60, 58, 76), feet = rgb(40, 40, 52) },
		recolor = {
			TorsoRock = rgb(70, 66, 86),
			HeadRock = rgb(90, 86, 106),
			ShoulderL = rgb(96, 92, 112),
			ShoulderR = rgb(96, 92, 112),
			FistL = rgb(60, 58, 76),
			FistR = rgb(60, 58, 76),
			EyeL = { NEON_CYAN, true },
			EyeR = { NEON_CYAN, true },
			ChestRune = { NEON_CYAN, true },
			RuneArmL = { NEON_CYAN, true },
			RuneArmR = { NEON_CYAN, true },
			BackCrystal = { NEON_CYAN, true },
		},
		add = {
			{
				P("SpikeShoulderL", "LeftUpperArm", "Wedge", v3(0.4, 0.9, 0.4), cf(0, 1.0, 0), GOLD, { mat = METAL }),
				P("SpikeShoulderR", "RightUpperArm", "Wedge", v3(0.4, 0.9, 0.4), cf(0, 1.0, 0), GOLD, { mat = METAL }),
				P("GoldBelt", "LowerTorso", "Block", v3(2.3, 0.4, 1.3), cf(0, 0, 0), GOLD, { mat = METAL }),
				P("KnuckleL", "LeftHand", "Block", v3(1.2, 0.3, 1.2), cf(0, -0.1, 0), GOLD, { mat = METAL }),
				P("KnuckleR", "RightHand", "Block", v3(1.2, 0.3, 1.2), cf(0, -0.1, 0), GOLD, { mat = METAL }),
			},
		},
		set = { halo = NEON_CYAN },
	}
	L.hedge_fund_hank = { -- Phoenix (E)
		add = { { P("Core", "LowerTorso", "Ball", v3(0.8, 0.8, 0.5), cf(0, 0.4, -0.6), rgb(255, 250, 200), { neon = true, anim = { kind = "pulse", amp = 0.2, speed = 4 } }) } },
		set = { halo = FLAME },
	}
	L.oil_baron_oswald = { -- Flame Archmage (L)
		outfit = { top = rgb(58, 30, 92), waist = rgb(255, 200, 70), arms = rgb(58, 30, 92), hands = rgb(255, 200, 70), legs = rgb(36, 22, 60), feet = rgb(255, 200, 70) },
		drop = { "Beard" },
		recolor = { Brim = rgb(44, 26, 78), Hat1 = rgb(58, 30, 92), Hat2 = rgb(58, 30, 92), Hat3 = rgb(58, 30, 92), Skirt = rgb(58, 30, 92) },
		add = {
			Kit.armor({
				main = rgb(44, 26, 78),
				trim = GOLD,
				accent = FIRE,
				glow = FLAME,
				tier = 2,
				groups = { "shoulders", "gauntlets", "belt", "cape" },
				cape = rgb(36, 18, 64),
				capeHem = FIRE,
				belt = rgb(44, 26, 78),
			}),
			{ P("Beard", "Head", "Block", v3(0.9, 0.7, 0.3), cf(0, -0.95, -0.45), rgb(245, 245, 250)) },
		},
		set = { sound = "legendary_chime" },
	}
	L.the_trillionaire = { -- Ignis (S)
		drop = { "EyeL", "EyeR" },
		tweak = { BeardFlame = { at = cf(0, -1.25, -0.4) } },
		outfit = { top = rgb(40, 16, 30), waist = rgb(255, 170, 40), arms = rgb(40, 16, 30), hands = rgb(255, 170, 40), legs = rgb(30, 12, 22), feet = rgb(255, 170, 40) },
		recolor = {
			Brim = rgb(40, 14, 34),
			Hat1 = rgb(60, 20, 44),
			Hat2 = rgb(60, 20, 44),
			Hat3 = rgb(60, 20, 44),
			Hat4 = rgb(60, 20, 44),
			Cape = rgb(90, 16, 24),
			Robe = rgb(40, 16, 30),
		},
		add = { Kit.armor({ main = rgb(40, 16, 30), trim = GOLD, accent = FIRE, glow = FLAME, tier = 3, groups = { "shoulders", "gauntlets", "belt" }, belt = rgb(40, 16, 30) }) },
		set = { sound = "boss_roar" },
	}
	return L
end

local HEAD_KEEP = { Beard = true, BeardFlame = true, HoodBack = true } -- sit on the chin / back of the head

local function applyPolish()
	for id, pol in polishList() do
		local spec = CreatureSpecs[id]
		if not spec then
			warn("[CreatureSpecs] polish for unknown creature", id)
			continue
		end
		if pol.skin then
			spec.skin = pol.skin
		end
		if pol.outfit then
			spec.outfit = outfit(pol.outfit)
		end
		local props = spec.props
		if pol.drop then
			local gone = {}
			for _, n in pol.drop do
				gone[n] = true
			end
			local kept = {}
			for _, p in props do
				if not gone[p.n or p.on] then
					table.insert(kept, p)
				end
			end
			props = kept
		end
		for _, p in props do
			local name = p.n or p.on
			local c = pol.recolor and pol.recolor[name]
			if c then
				if typeof(c) == "table" then
					p.color, p.neon = c[1], c[2]
				else
					p.color = c
				end
			end
			local tw = pol.tweak and pol.tweak[name]
			if tw then
				for k, v in tw do
					(p :: any)[k] = v
				end
			end
		end
		if not spec.own and not spec.hideBody then -- classic noob: the head reads, so hats and head decor are 20% smaller
			for _, p in props do
				if p.on == "Head" and not HEAD_KEEP[p.n or ""] then
					local at = p.at.Position
					p.size = p.size * 0.8
					p.at = CFrame.new(at.X * 0.8, at.Y * 0.8 + 0.1, at.Z * 0.8) * p.at.Rotation
				end
			end
		end
		for _, list in pol.add or {} do
			for _, p in list do
				table.insert(props, p)
			end
		end
		spec.props = props
		if pol.fx then
			spec.fx = spec.fx or {}
			for _, f in pol.fx do
				table.insert(spec.fx, f)
			end
		end
		local face = faceOf[id]
		if face and not spec.own and not spec.hideBody then
			spec.face = FACES[face]
		end
		for k, v in pol.set or {} do
			(spec :: any)[k] = v
		end
	end
end
applyPolish()

return CreatureSpecs
