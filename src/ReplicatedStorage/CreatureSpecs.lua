-- Studio location: ReplicatedStorage.CreatureSpecs (ModuleScript)
-- CreatureSpecs  (Milestone 035)
-- The ONE design sheet for every creature: colours, props (the twist), idle motion and aura. Read by
-- ServerScriptService.CreatureBuilder, which builds ReplicatedStorage.CreatureModels (the single source every
-- place clones: wander, carry, pad, parade reveal, Index, reveal card, inventory). Ids, rarities, odds and income
-- live in WorkerCatalogue and are never set here; this file only says how a creature looks.
--
-- Body = the R15 MysteryNPC rig, recoloured. A prop is a part (or a Blender mesh master from
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
		{ n = "ScrollTube", on = "UpperTorso", shape = "Cylinder", size = v3(0.55, 2.3, 0.55), at = cf(0.25, 0.1, 0.7) * CFrame.Angles(0, 0, rad(18)), color = rgb(190, 140, 80) },
		{ n = "ScrollCap", on = "UpperTorso", shape = "Cylinder", size = v3(0.62, 0.16, 0.62), at = cf(-0.1, 1.2, 0.7) * CFrame.Angles(0, 0, rad(18)), color = rgb(190, 40, 40) },
		{ n = "ScrollRoll", on = "LeftHand", shape = "Cylinder", size = v3(0.5, 1.4, 0.5), at = cf(0, -0.35, -0.5) * CFrame.Angles(rad(90), 0, 0), color = rgb(250, 240, 210) },
		{
			n = "ScrollPaper",
			on = "LeftHand",
			size = v3(0.9, 0.04, 2.4),
			at = cf(0, -0.7, -1.9) * CFrame.Angles(rad(-18), 0, 0),
			color = rgb(252, 244, 220),
			anim = { kind = "swing", axis = "X", amp = 14, speed = 2.0, pivot = cf(0, -0.5, -0.6) },
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

-- Aquaris (S): the water dragon, a coiled serpent built from balls along a curve; the rig only walks it.
local function aquaris(): Spec
	local props: { Prop } = {}
	local count = 20
	for i = 1, count do
		local t = i / count -- 0 = tail tip, 1 = neck
		local ang = t * 5.2
		local r = 0.45 + math.sin(t * math.pi) * 0.5
		local pos = v3(math.sin(ang) * 1.5 * (1 - t * 0.35), -2.7 + t * 4.6, math.cos(ang) * 0.9 * (1 - t * 0.35) + 0.4)
		local shade = if i % 2 == 0 then rgb(40, 150, 215) else rgb(70, 190, 235)
		table.insert(props, P("Seg" .. i, "LowerTorso", "Ball", v3(r * 2, r * 2, r * 2), cf(pos), shade, { mat = Enum.Material.SmoothPlastic }))
		if i % 3 == 0 then -- back frills
			table.insert(
				props,
				P(
					"Frill" .. i,
					"LowerTorso",
					"Block",
					v3(0.08, r * 1.3, r * 1.2),
					cf(pos + v3(0, r * 0.95, 0.1)),
					rgb(150, 235, 255),
					{ trans = 0.25, anim = { kind = "swing", axis = "Z", amp = 8, speed = 2.2, phase = i * 0.5 } }
				)
			)
		end
		if i % 4 == 1 then -- pearly belly scales
			table.insert(props, P("Scale" .. i, "LowerTorso", "Ball", v3(r * 0.8, r * 0.8, r * 0.8), cf(pos + v3(0, 0, -r * 0.75)), rgb(240, 250, 255), { neon = true }))
		end
	end
	local head = v3(0, 2.7, -0.8)
	local extra: { Prop } = {
		P("Head", "LowerTorso", "Ball", v3(1.5, 1.2, 1.9), cf(head), rgb(40, 150, 215)),
		P(
			"Jaw",
			"LowerTorso",
			"Block",
			v3(1.0, 0.3, 1.2),
			cf(head + v3(0, -0.55, -0.55)),
			rgb(30, 110, 180),
			{ anim = { kind = "swing", axis = "X", amp = 8, speed = 1.6, pivot = cf(head + v3(0, -0.4, 0.2)) } }
		),
		P("Snout", "LowerTorso", "Block", v3(0.9, 0.55, 0.9), cf(head + v3(0, -0.05, -1.05)), rgb(70, 190, 235)),
		P("Mouth", "LowerTorso", "Block", v3(0.3, 0.3, 0.3), cf(head + v3(0, -0.3, -1.55)), rgb(20, 60, 110)),
		P("EyeL", "LowerTorso", "Ball", v3(0.3, 0.3, 0.3), cf(head + v3(-0.55, 0.3, -0.65)), rgb(255, 240, 120), { neon = true }),
		P("EyeR", "LowerTorso", "Ball", v3(0.3, 0.3, 0.3), cf(head + v3(0.55, 0.3, -0.65)), rgb(255, 240, 120), { neon = true }),
		P("HornL", "LowerTorso", "Block", v3(0.18, 1.1, 0.18), cf(head + v3(-0.5, 0.85, 0.3)) * CFrame.Angles(rad(-20), 0, rad(18)), rgb(255, 235, 180)),
		P("HornR", "LowerTorso", "Block", v3(0.18, 1.1, 0.18), cf(head + v3(0.5, 0.85, 0.3)) * CFrame.Angles(rad(-20), 0, rad(-18)), rgb(255, 235, 180)),
		P(
			"FinL",
			"LowerTorso",
			"Block",
			v3(1.0, 0.1, 0.9),
			cf(head + v3(-1.1, 0.0, 0.5)),
			rgb(150, 235, 255),
			{ trans = 0.25, anim = { kind = "swing", axis = "Z", amp = 18, speed = 2.6 } }
		),
		P(
			"FinR",
			"LowerTorso",
			"Block",
			v3(1.0, 0.1, 0.9),
			cf(head + v3(1.1, 0.0, 0.5)),
			rgb(150, 235, 255),
			{ trans = 0.25, anim = { kind = "swing", axis = "Z", amp = 18, speed = 2.6, phase = 3 } }
		),
		P(
			"TailFinA",
			"LowerTorso",
			"Block",
			v3(1.4, 0.1, 0.9),
			cf(v3(0, -2.9, 0.4)),
			rgb(150, 235, 255),
			{ trans = 0.25, anim = { kind = "swing", axis = "Y", amp = 15, speed = 2.4 } }
		),
		P(
			"TailFinB",
			"LowerTorso",
			"Block",
			v3(0.9, 0.1, 1.4),
			cf(v3(0, -2.9, 0.4)),
			rgb(150, 235, 255),
			{ trans = 0.25, anim = { kind = "swing", axis = "Y", amp = 15, speed = 2.4, phase = 1 } }
		),
		P("Pool", "LowerTorso", "Cylinder", v3(5.4, 0.1, 5.4), cf(0, -3.15, 0.2), rgb(90, 200, 255), { neon = true, trans = 0.5, anim = { kind = "spin", axis = "Y", amp = 25 } }),
	}
	for _, p in extra do
		table.insert(props, p)
	end
	return {
		hideBody = true,
		scale = 3,
		skin = rgb(40, 150, 215),
		props = props,
		fx = {
			{ on = "Mouth", kind = "puff", color = rgb(150, 220, 255), rate = 22, size = 2.2, aura = true }, -- the water breath
			{ on = "Seg10", kind = "bubble", color = rgb(190, 235, 255), rate = 10, size = 1.6, aura = true },
			{ on = "Head", kind = "spark", color = rgb(210, 245, 255), rate = 8, aura = true },
		},
		light = rgb(120, 210, 255),
		halo = rgb(90, 200, 255),
	}
end
CreatureSpecs.aquaris = aquaris()

return CreatureSpecs
