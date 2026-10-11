-- Studio location: ServerScriptService.WorkerAppearance (ModuleScript)
-- WorkerAppearance
-- Turns a mystery NPC into the look of the worker it was revealed as, in place on the same R15 rig,
-- so walking, carrying and placement keep working unchanged.
--
-- A look is: the mystery clothing and accessories removed, body parts recoloured as an outfit, and a
-- few small props (hats, glasses, ties, bags...) built from plain parts and welded to body parts.
-- No external assets. Props are massless and non-colliding so they never affect carrying or physics.
--
-- Prop offsets are in the body part's own space (+X right, +Y up, -Z forward), sized for the
-- MysteryNPC rig's proportions.
--
-- District workers (Milestone 015) use PLACEHOLDERS until they get their own looks: see below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local CustomWorkerRigs = require(script.Parent:WaitForChild("CustomWorkerRigs"))

local WorkerAppearance = {}

type Prop = {
	part: string, -- body part to weld to
	shape: "Block" | "Ball" | "Cylinder" | "Disc", -- Cylinder stands upright; Disc faces forward
	size: Vector3, -- for Cylinder: (diameter, height, diameter); for Disc: (diameter, diameter, thickness)
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	reflectance: number?,
}

type Look = {
	skin: Color3,
	outfit: { [string]: Color3 }, -- body part name -> colour; anything not listed is skin
	props: { Prop },
	light: Color3?, -- optional soft glow, for the very rarest workers
}

local rgb = Color3.fromRGB
local v3 = Vector3.new
local cf = CFrame.new
local rad = math.rad

local PROPS_FOLDER = "WorkerLook"

-- Outfit colours for each body region. Unlisted regions (and always the head) show skin.
local function outfit(o: {
	top: Color3?, -- UpperTorso
	upperArms: Color3?,
	lowerArms: Color3?,
	hands: Color3?,
	waist: Color3?, -- LowerTorso
	upperLegs: Color3?,
	lowerLegs: Color3?,
	feet: Color3?,
}): { [string]: Color3 }
	local colors = {}
	local function both(name: string, color: Color3?)
		colors["Left" .. name] = color
		colors["Right" .. name] = color
	end
	colors.UpperTorso = o.top
	colors.LowerTorso = o.waist
	both("UpperArm", o.upperArms)
	both("LowerArm", o.lowerArms)
	both("Hand", o.hands)
	both("UpperLeg", o.upperLegs)
	both("LowerLeg", o.lowerLegs)
	both("Foot", o.feet)
	return colors
end

-- A cap: crown on the head plus a brim facing forward (or backward).
local function cap(crown: Color3, brim: Color3, backwards: boolean?): { Prop }
	local brimZ = if backwards then 0.72 else -0.72
	return {
		{ part = "Head", shape = "Cylinder", size = v3(1.3, 0.42, 1.3), at = cf(0, 0.48, 0), color = crown },
		{ part = "Head", shape = "Block", size = v3(1.0, 0.08, 0.62), at = cf(0, 0.32, brimZ), color = brim },
	}
end

local function join(...: { Prop }): { Prop }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

-- Colours share a slightly muted, darker palette so the cast reads as one set.
local WHITE = rgb(232, 232, 228)
local BLACK = rgb(24, 24, 30)
local GOLD = rgb(232, 182, 58)

local LOOKS: { [string]: Look } = {
	-- Scruffy casual: worn olive tee with a patch, faded jeans, beanie, paper cup.
	broke_bob = {
		skin = rgb(226, 178, 140),
		outfit = outfit({ top = rgb(118, 110, 82), upperArms = rgb(118, 110, 82), waist = rgb(62, 78, 104), upperLegs = rgb(62, 78, 104), lowerLegs = rgb(62, 78, 104), feet = rgb(88, 62, 44) }),
		props = {
			{ part = "Head", shape = "Cylinder", size = v3(1.3, 0.6, 1.3), at = cf(0, 0.42, 0.02), color = rgb(136, 56, 48) },
			{ part = "Head", shape = "Ball", size = v3(0.34, 0.34, 0.34), at = cf(0, 0.8, 0.02), color = rgb(136, 56, 48) },
			{ part = "UpperTorso", shape = "Block", size = v3(0.42, 0.38, 0.05), at = cf(0.5, 0.15, -0.58), color = rgb(150, 138, 100) },
			{ part = "RightHand", shape = "Cylinder", size = v3(0.36, 0.5, 0.36), at = cf(0, -0.25, -0.38), color = rgb(222, 212, 186) },
		},
	},

	-- Courier: red polo, brown shorts, red cap, satchel strap, parcel under one hand.
	delivery_dave = {
		skin = rgb(196, 140, 100),
		outfit = outfit({ top = rgb(204, 56, 46), upperArms = rgb(204, 56, 46), waist = rgb(96, 70, 46), upperLegs = rgb(96, 70, 46), feet = WHITE }),
		props = join(cap(rgb(186, 44, 38), rgb(150, 34, 30)), {
			{ part = "UpperTorso", shape = "Block", size = v3(0.18, 2.3, 0.06), at = cf(0, 0, -0.58) * CFrame.Angles(0, 0, rad(38)), color = rgb(70, 50, 34) },
			{ part = "LeftHand", shape = "Block", size = v3(1.0, 0.8, 0.8), at = cf(0, -0.35, -0.45), color = rgb(176, 132, 84) },
			{ part = "LeftHand", shape = "Block", size = v3(1.02, 0.14, 0.82), at = cf(0, -0.35, -0.45), color = rgb(212, 182, 122) },
		}),
	},

	-- Sporty streetwear: red hoodie, black track pants with white stripes, backwards cap, gold chain.
	street_hustler = {
		skin = rgb(122, 84, 60),
		outfit = outfit({ top = rgb(200, 42, 54), upperArms = rgb(200, 42, 54), lowerArms = rgb(200, 42, 54), waist = rgb(34, 36, 44), upperLegs = rgb(34, 36, 44), lowerLegs = rgb(34, 36, 44), feet = WHITE }),
		props = join(cap(BLACK, GOLD, true), {
			{ part = "LeftUpperLeg", shape = "Block", size = v3(0.08, 1.3, 0.5), at = cf(-0.34, 0, 0), color = WHITE },
			{ part = "RightUpperLeg", shape = "Block", size = v3(0.08, 1.3, 0.5), at = cf(0.34, 0, 0), color = WHITE },
			{ part = "UpperTorso", shape = "Block", size = v3(0.95, 0.08, 0.05), at = cf(0, 0.6, -0.58), color = GOLD, material = Enum.Material.Metal },
			{ part = "UpperTorso", shape = "Block", size = v3(0.24, 0.24, 0.06), at = cf(0, 0.42, -0.59), color = GOLD, material = Enum.Material.Metal },
		}),
	},

	-- Smart business: navy blazer over a white shirt, charcoal skirt, hair bun, briefcase.
	business_betty = {
		skin = rgb(234, 190, 158),
		outfit = outfit({ top = rgb(38, 50, 92), upperArms = rgb(38, 50, 92), lowerArms = rgb(38, 50, 92), waist = rgb(58, 58, 68), upperLegs = rgb(58, 58, 68), feet = BLACK }),
		props = {
			{ part = "UpperTorso", shape = "Block", size = v3(0.55, 0.9, 0.05), at = cf(0, 0.45, -0.57), color = WHITE },
			{ part = "Head", shape = "Block", size = v3(1.28, 0.34, 1.28), at = cf(0, 0.52, 0.03), color = rgb(92, 56, 36) },
			{ part = "Head", shape = "Block", size = v3(1.26, 0.8, 0.22), at = cf(0, 0.12, 0.56), color = rgb(92, 56, 36) },
			{ part = "Head", shape = "Ball", size = v3(0.62, 0.62, 0.62), at = cf(0, 0.5, 0.72), color = rgb(92, 56, 36) },
			{ part = "RightHand", shape = "Block", size = v3(1.0, 0.75, 0.26), at = cf(0, -0.7, 0), color = rgb(110, 62, 34) },
			{ part = "RightHand", shape = "Block", size = v3(0.42, 0.12, 0.12), at = cf(0, -0.27, 0), color = rgb(70, 40, 22) },
		},
	},

	-- Uniform with a broad silhouette: bulky vest, shoulder pads, badge, radio, peaked cap.
	security_sam = {
		skin = rgb(92, 62, 44),
		outfit = outfit({ top = rgb(52, 58, 72), upperArms = rgb(52, 58, 72), lowerArms = rgb(52, 58, 72), waist = rgb(30, 32, 40), upperLegs = rgb(30, 32, 40), lowerLegs = rgb(30, 32, 40), feet = BLACK }),
		props = join(cap(BLACK, BLACK), {
			{ part = "Head", shape = "Block", size = v3(0.22, 0.22, 0.05), at = cf(0, 0.5, -0.66), color = GOLD, material = Enum.Material.Metal },
			{ part = "UpperTorso", shape = "Block", size = v3(2.3, 1.7, 1.3), at = cf(0, -0.05, 0), color = rgb(30, 32, 40) },
			{ part = "LeftUpperArm", shape = "Block", size = v3(0.95, 0.4, 1.0), at = cf(-0.08, 0.45, 0), color = rgb(30, 32, 40) },
			{ part = "RightUpperArm", shape = "Block", size = v3(0.95, 0.4, 1.0), at = cf(0.08, 0.45, 0), color = rgb(30, 32, 40) },
			{ part = "UpperTorso", shape = "Block", size = v3(0.28, 0.32, 0.05), at = cf(-0.5, 0.35, -0.67), color = GOLD, material = Enum.Material.Metal },
			{ part = "UpperTorso", shape = "Block", size = v3(0.22, 0.42, 0.14), at = cf(0.5, 0.3, -0.71), color = BLACK },
			{ part = "UpperTorso", shape = "Block", size = v3(0.05, 0.32, 0.05), at = cf(0.56, 0.66, -0.71), color = BLACK },
		}),
	},

	-- Tech: graphite hoodie with a glowing coin logo, cyan visor, messy hair, glowing phone.
	crypto_carl = {
		skin = rgb(238, 204, 168),
		outfit = outfit({ top = rgb(46, 48, 62), upperArms = rgb(46, 48, 62), lowerArms = rgb(46, 48, 62), waist = rgb(60, 64, 78), upperLegs = rgb(60, 64, 78), lowerLegs = rgb(60, 64, 78), feet = WHITE }),
		props = {
			{ part = "UpperTorso", shape = "Disc", size = v3(0.75, 0.75, 0.06), at = cf(0, 0.15, -0.58), color = rgb(247, 147, 26), material = Enum.Material.Neon },
			{ part = "Head", shape = "Block", size = v3(1.3, 0.32, 1.25), at = cf(0, 0.55, 0.02), color = rgb(150, 98, 58) },
			{ part = "Head", shape = "Block", size = v3(1.28, 0.14, 1.22), at = cf(0, 0.12, 0.04), color = BLACK },
			{ part = "Head", shape = "Block", size = v3(1.0, 0.3, 0.12), at = cf(0, 0.12, -0.6), color = rgb(40, 220, 255), material = Enum.Material.Neon },
			{ part = "RightHand", shape = "Block", size = v3(0.46, 0.8, 0.08), at = cf(0, -0.35, -0.38), color = BLACK },
			{ part = "RightHand", shape = "Block", size = v3(0.38, 0.68, 0.02), at = cf(0, -0.35, -0.43), color = rgb(60, 255, 140), material = Enum.Material.Neon },
		},
	},

	-- Luxury suit: black suit, white shirt, red tie, sunglasses, slick hair, gold watch.
	ceo_chad = {
		skin = rgb(236, 188, 148),
		outfit = outfit({ top = rgb(26, 28, 38), upperArms = rgb(26, 28, 38), lowerArms = rgb(26, 28, 38), waist = rgb(26, 28, 38), upperLegs = rgb(26, 28, 38), lowerLegs = rgb(26, 28, 38), feet = rgb(18, 18, 22) }),
		props = {
			{ part = "UpperTorso", shape = "Block", size = v3(0.6, 0.95, 0.05), at = cf(0, 0.42, -0.57), color = WHITE },
			{ part = "UpperTorso", shape = "Block", size = v3(0.2, 0.85, 0.06), at = cf(0, 0.32, -0.6), color = rgb(196, 30, 40) },
			{ part = "UpperTorso", shape = "Block", size = v3(0.26, 0.18, 0.07), at = cf(0, 0.8, -0.6), color = rgb(160, 22, 30) },
			{ part = "UpperTorso", shape = "Block", size = v3(0.26, 0.14, 0.05), at = cf(-0.6, 0.45, -0.57), color = GOLD },
			{ part = "Head", shape = "Block", size = v3(1.06, 0.26, 0.08), at = cf(0, 0.12, -0.62), color = BLACK, reflectance = 0.25 },
			{ part = "Head", shape = "Block", size = v3(1.28, 0.3, 1.26), at = cf(0, 0.52, 0.03), color = rgb(42, 32, 26) },
			{ part = "Head", shape = "Block", size = v3(1.0, 0.24, 0.36), at = cf(0, 0.64, -0.44), color = rgb(42, 32, 26) },
			{ part = "LeftLowerArm", shape = "Block", size = v3(0.88, 0.18, 0.92), at = cf(0, -0.32, 0), color = GOLD, material = Enum.Material.Metal },
		},
	},

	-- Secret: purple tuxedo, white gloves, gold masquerade mask, gold-banded top hat, cape, gold
	-- cane and a soft golden glow. Meant to be unmistakable at a glance.
	mystery_millionaire = {
		skin = rgb(228, 188, 156),
		outfit = outfit({ top = rgb(58, 26, 92), upperArms = rgb(58, 26, 92), lowerArms = rgb(58, 26, 92), hands = WHITE, waist = rgb(18, 16, 24), upperLegs = rgb(18, 16, 24), lowerLegs = rgb(18, 16, 24), feet = BLACK }),
		props = {
			{ part = "UpperTorso", shape = "Block", size = v3(0.55, 0.9, 0.05), at = cf(0, 0.45, -0.57), color = WHITE },
			{ part = "UpperTorso", shape = "Block", size = v3(0.46, 0.2, 0.08), at = cf(0, 0.78, -0.6), color = GOLD, material = Enum.Material.Neon },
			{ part = "UpperTorso", shape = "Block", size = v3(2.2, 2.8, 0.12), at = cf(0, -0.45, 0.62), color = rgb(44, 14, 70) },
			{ part = "UpperTorso", shape = "Block", size = v3(2.26, 0.16, 0.16), at = cf(0, 0.92, 0.62), color = GOLD, material = Enum.Material.Neon },
			{ part = "Head", shape = "Block", size = v3(1.08, 0.36, 0.1), at = cf(0, 0.12, -0.62), color = GOLD, material = Enum.Material.Neon },
			{ part = "Head", shape = "Cylinder", size = v3(1.8, 0.1, 1.8), at = cf(0, 0.62, 0), color = BLACK },
			{ part = "Head", shape = "Cylinder", size = v3(1.12, 1.0, 1.12), at = cf(0, 1.16, 0), color = BLACK },
			{ part = "Head", shape = "Cylinder", size = v3(1.14, 0.2, 1.14), at = cf(0, 0.78, 0), color = GOLD, material = Enum.Material.Neon },
			{ part = "RightHand", shape = "Cylinder", size = v3(0.14, 2.4, 0.14), at = cf(0, -0.9, -0.3), color = GOLD, material = Enum.Material.Metal },
			{ part = "RightHand", shape = "Ball", size = v3(0.34, 0.34, 0.34), at = cf(0, 0.32, -0.3), color = GOLD, material = Enum.Material.Neon },
		},
		light = GOLD,
	},
}

WorkerAppearance.LOOKS = LOOKS

-- Temporary looks for district workers. Each reuses the Main Street look of the same roster slot
-- (`base`): its shirt colour becomes `top`, its trouser colour becomes `legs` (every outfit part and
-- prop of that colour changes, so vests and suits follow), and it gets armbands in the district's
-- accent colour so it never reads as the Main Street worker.
-- To give a worker its real look: add a full entry for it to LOOKS (it wins over its placeholder),
-- remove its line here, and re-bake its model in ReplicatedStorage.WorkerPreviews.
type Placeholder = { base: string, top: Color3, legs: Color3?, band: Color3 }

local BEACH = rgb(62, 140, 146)
local TOY = rgb(184, 92, 108)
local NEON = rgb(110, 80, 168)
local HILLS = rgb(44, 112, 82)

local PLACEHOLDERS: { [string]: Placeholder } = {
	-- Beach Boardwalk
	surfer_sid = { base = "broke_bob", top = rgb(236, 150, 60), legs = rgb(64, 150, 170), band = BEACH },
	lifeguard_lucy = { base = "delivery_dave", top = rgb(210, 48, 48), legs = rgb(220, 200, 90), band = BEACH },
	volleyball_vic = { base = "street_hustler", top = rgb(240, 200, 70), legs = rgb(40, 90, 140), band = BEACH },
	ice_cream_ivy = { base = "business_betty", top = rgb(236, 150, 180), legs = rgb(240, 236, 226), band = BEACH },
	pier_bouncer_bruno = { base = "security_sam", top = rgb(40, 110, 120), legs = rgb(32, 70, 80), band = BEACH },
	yacht_broker_yara = { base = "crypto_carl", top = rgb(240, 240, 236), legs = rgb(30, 50, 90), band = BEACH },
	boardwalk_baron = { base = "ceo_chad", top = rgb(226, 214, 186), band = BEACH },
	captain_goldbeard = { base = "mystery_millionaire", top = rgb(30, 50, 96), legs = rgb(30, 30, 40), band = BEACH },
	-- Toy Town
	toy_soldier_tom = { base = "broke_bob", top = rgb(196, 40, 48), legs = rgb(30, 40, 90), band = TOY },
	balloon_bella = { base = "delivery_dave", top = rgb(250, 170, 200), legs = rgb(120, 190, 230), band = TOY },
	robo_rex = { base = "street_hustler", top = rgb(150, 160, 176), legs = rgb(80, 88, 100), band = TOY },
	yoyo_yuki = { base = "business_betty", top = rgb(250, 210, 60), legs = rgb(70, 140, 220), band = TOY },
	nutcracker_ned = { base = "security_sam", top = rgb(170, 30, 40), legs = rgb(30, 40, 90), band = TOY },
	toymaker_tilly = { base = "crypto_carl", top = rgb(120, 80, 50), legs = rgb(80, 120, 90), band = TOY },
	toy_tycoon_theo = { base = "ceo_chad", top = rgb(120, 40, 110), band = TOY },
	golden_teddy = { base = "mystery_millionaire", top = rgb(196, 140, 60), legs = rgb(150, 100, 50), band = TOY },
	-- Neon Downtown
	night_courier_nia = { base = "broke_bob", top = rgb(30, 30, 40), legs = rgb(60, 60, 80), band = NEON },
	arcade_andy = { base = "delivery_dave", top = rgb(60, 200, 220), legs = rgb(40, 40, 60), band = NEON },
	dj_dynamo = { base = "street_hustler", top = rgb(150, 60, 220), legs = rgb(25, 25, 35), band = NEON },
	neon_nate = { base = "business_betty", top = rgb(240, 60, 170), legs = rgb(40, 40, 60), band = NEON },
	bouncer_blaze = { base = "security_sam", top = rgb(20, 20, 26), legs = rgb(70, 30, 100), band = NEON },
	hacker_hex = { base = "crypto_carl", top = rgb(20, 60, 40), legs = rgb(20, 22, 28), band = NEON },
	neon_mogul_max = { base = "ceo_chad", top = rgb(80, 40, 140), band = NEON },
	midnight_magnate = { base = "mystery_millionaire", top = rgb(18, 18, 40), legs = rgb(10, 10, 20), band = NEON },
	-- Billionaire Hills
	butler_barnaby = { base = "broke_bob", top = rgb(20, 20, 24), legs = rgb(20, 20, 24), band = HILLS },
	caddie_gus = { base = "delivery_dave", top = rgb(240, 240, 232), legs = rgb(190, 170, 120), band = HILLS },
	polo_pro_penny = { base = "street_hustler", top = rgb(40, 110, 80), legs = rgb(240, 236, 226), band = HILLS },
	chef_pierre = { base = "business_betty", top = rgb(244, 244, 240), legs = rgb(50, 50, 56), band = HILLS },
	bodyguard_boris = { base = "security_sam", top = rgb(16, 16, 20), legs = rgb(16, 16, 20), band = HILLS },
	hedge_fund_hank = { base = "crypto_carl", top = rgb(60, 70, 90), legs = rgb(60, 70, 90), band = HILLS },
	oil_baron_oswald = { base = "ceo_chad", top = rgb(240, 236, 220), band = HILLS },
	the_trillionaire = { base = "mystery_millionaire", top = rgb(20, 60, 46), legs = rgb(16, 20, 18), band = HILLS },
}

WorkerAppearance.PLACEHOLDERS = PLACEHOLDERS

local function armbands(color: Color3): { Prop }
	return {
		{ part = "LeftUpperArm", shape = "Block", size = v3(1.04, 0.26, 1.04), at = cf(0, -0.15, 0), color = color },
		{ part = "RightUpperArm", shape = "Block", size = v3(1.04, 0.26, 1.04), at = cf(0, -0.15, 0), color = color },
	}
end

local function deriveLook(placeholder: Placeholder): Look?
	local base = LOOKS[placeholder.base]
	if not base then
		return nil
	end
	local swaps: { [string]: Color3 } = {}
	local baseTop, baseLegs = base.outfit.UpperTorso, base.outfit.LeftUpperLeg
	if baseTop then
		swaps[baseTop:ToHex()] = placeholder.top
	end
	if baseLegs and placeholder.legs and not swaps[baseLegs:ToHex()] then
		swaps[baseLegs:ToHex()] = placeholder.legs
	end
	local function swap(color: Color3): Color3
		return swaps[color:ToHex()] or color
	end

	local colors = {}
	for partName, color in base.outfit do
		colors[partName] = swap(color)
	end
	local props = {}
	for _, prop in base.props do
		local copy = table.clone(prop)
		copy.color = swap(prop.color)
		table.insert(props, copy)
	end
	return { skin = base.skin, outfit = colors, props = join(props, armbands(placeholder.band)), light = base.light }
end

local derived: { [string]: Look } = {}

-- The look for a worker: its own entry in LOOKS, else its placeholder, else nil.
function WorkerAppearance.getLook(workerId: string): Look?
	local look = LOOKS[workerId] or derived[workerId]
	if look then
		return look
	end
	local placeholder = PLACEHOLDERS[workerId]
	local built = placeholder and deriveLook(placeholder)
	if built then
		derived[workerId] = built
	end
	return built
end

for workerId in WorkerCatalogue.WORKERS do
	if not WorkerAppearance.getLook(workerId) then
		warn("[WorkerAppearance] worker", workerId, "has no look; it will keep the mystery look")
	end
end

local function makeProp(prop: Prop, bodyPart: BasePart, index: number): BasePart
	local part = Instance.new("Part")
	part.Name = ("%s_%d"):format(prop.part, index)
	part.Color = prop.color
	part.Material = prop.material or Enum.Material.SmoothPlastic
	part.Reflectance = prop.reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false

	local offset = prop.at
	if prop.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = prop.size
	elseif prop.shape == "Cylinder" then -- Roblox cylinders run along X; stand it up
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(prop.size.Y, prop.size.X, prop.size.Z)
		offset *= CFrame.Angles(0, 0, rad(90))
	elseif prop.shape == "Disc" then -- turn the cylinder's axis to face forward
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(prop.size.Z, prop.size.Y, prop.size.X)
		offset *= CFrame.Angles(0, rad(90), 0)
	else
		part.Size = prop.size
	end

	part.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = bodyPart
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	return part
end

-- Replaces the mystery look on `npc` with the worker's look. Unknown worker ids are left as they are.
function WorkerAppearance.apply(npc: Model, workerId: string)
	if CustomWorkerRigs.apply(npc, workerId) then
		return -- custom character model (Milestone 019); the look below stays as its fallback
	end
	local look = WorkerAppearance.getLook(workerId)
	if not look then
		warn("[WorkerAppearance] no look for", workerId)
		return
	end

	for _, child in npc:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child.Name == PROPS_FOLDER then
			child:Destroy()
		end
	end

	for _, part in npc:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = look.outfit[part.Name] or look.skin
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = PROPS_FOLDER
	for index, prop in look.props do
		local bodyPart = npc:FindFirstChild(prop.part)
		if bodyPart and bodyPart:IsA("BasePart") then
			makeProp(prop, bodyPart, index).Parent = folder
		else
			warn("[WorkerAppearance]", workerId, "prop needs missing body part", prop.part)
		end
	end
	folder.Parent = npc

	if look.light then
		local torso = npc:FindFirstChild("UpperTorso")
		if torso then
			local light = Instance.new("PointLight")
			light.Name = "WorkerGlow"
			light.Color = look.light
			light.Range = 8
			light.Brightness = 0.8
			light.Shadows = false
			light.Parent = torso
		end
	end
end

return WorkerAppearance
