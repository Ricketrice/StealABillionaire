-- Studio location: ServerStorage.CustomWorkerLooks (ModuleScript)
-- CustomWorkerLooks  (Milestone 019R)
-- The catalogue look of every custom worker, as a real Roblox avatar: one line per item, so any item
-- can be swapped by editing its id. The Edit-mode avatar builder reads this and bakes each look into
-- a rig, so after changing a line the builder has to be run again.
-- Slots:  Head = dynamic head (the face)      Hair, Hat, Face (glasses...), Neck, Front, Back, Waist
--         TShirt, Shirt, Sweater, Jacket, Pants, Shorts, Skirt, LeftShoe, RightShoe = layered clothing
--         ClassicShirt, ClassicPants = classic 2D clothing
-- height / width are the avatar body scales (0.9-1.05 / 0.7-1.0); skin is a hex colour.
-- props are the Milestone 019 prop meshes (ServerStorage.WorkerImports019.<id>.<name>), held as
-- hand or chest accessories; names ending in _Glow are that worker's emissive accent.
-- Every id below is an item made by Roblox (checked against the catalogue on 2026-10-11).

local CustomWorkerLooks = {}

CustomWorkerLooks.WORKERS = {
	-- Main Street -----------------------------------------------------------------------------
	broke_bob = {
		height = 0.95,
		width = 0.95,
		skin = "E2B28C",
		props = { "Acc_RightHand_Coffee" },
		items = {
			{ "Head", 12946305202 }, -- YAAAWWN - Head
			{ "Hair", 26658141 }, -- Messy Hair
			{ "Hat", 27456067 }, -- Bright Beanie
			{ "Jacket", 8516620262 }, -- Hooded Jacket - Gray
			{ "TShirt", 9112474888 }, -- Basic T-Shirt - Gray
			{ "Pants", 7192664790 }, -- Casual Sweats - Gray
			{ "LeftShoe", 9483690316 }, -- Canvas Shoes - Gray
			{ "RightShoe", 9483697460 },
		},
	},
	delivery_dave = {
		height = 1.0,
		width = 1.0,
		skin = "C48C64",
		props = { "Acc_RightHand_Scissors", "Acc_LeftHand_Coupons" },
		items = {
			{ "Head", 13692975981 }, -- Friendly Smile - Head
			{ "Hair", 7193419595 }, -- Side Part - Brown
			{ "Face", 12520031 }, -- John's Glasses
			{ "Sweater", 6984769289 }, -- Knit Sweater - Beige
			{ "Shirt", 9728271806 }, -- Roblox Button Down - Green
			{ "Pants", 6984740059 }, -- Cargo Pants - Brown
			{ "LeftShoe", 9482987287 }, -- Sneakers - White
			{ "RightShoe", 9482991343 },
		},
	},
	street_hustler = {
		height = 0.97,
		width = 0.9,
		skin = "7A543C",
		props = { "Acc_UpperTorso_Tray" },
		items = {
			{ "Head", 79654074199621 }, -- Overjoyed Smile - Head
			{ "Hair", 7193454569 }, -- Braided Hair - Black
			{ "Jacket", 8516609675 }, -- Denim Jacket - Light Wash
			{ "TShirt", 9112483644 }, -- Striped T-Shirt - White
			{ "Shorts", 7192687500 }, -- Jean Shorts - Light Wash
			{ "LeftShoe", 9542380884 }, -- High Tops - White
			{ "RightShoe", 9542391112 },
		},
	},
	business_betty = {
		height = 0.97,
		width = 0.85,
		skin = "EABE9E",
		props = { "Acc_RightHand_SelfieStick" },
		items = {
			{ "Head", 113569146339346 }, -- Award-Winning Smile - Head
			{ "Hair", 2042026822 }, -- Brunette Action Ponytail
			{ "Face", 52452708 }, -- Butterfly Sunglasses
			{ "Jacket", 7192546798 }, -- Collared Leather Jacket - White
			{ "Shirt", 9240752338 }, -- Tie-Front Top - White
			{ "Skirt", 9240772455 }, -- Chiffon Skirt - Light Pink
			{ "LeftShoe", 7193163373 }, -- Roblox Sneakers - Pink
			{ "RightShoe", 7193164471 },
		},
	},
	security_sam = {
		height = 0.9,
		width = 1.0,
		skin = "B98A60",
		props = { "Acc_LeftHand_Keys", "Acc_RightHand_Clipboard" },
		items = {
			{ "Head", 101398692064661 }, -- I Am Not Amused - Head
			{ "Hair", 880450257 }, -- Slick Salesman Hair
			{ "Face", 987022351 }, -- Master of Disguise Mustache
			{ "Sweater", 9240758221 }, -- Knit Sweater - Gray
			{ "Shirt", 9620950227 }, -- Roblox Button Down - Gray
			{ "ClassicPants", 129459077 }, -- Black Slacks
			{ "LeftShoe", 8044823721 }, -- Dress Shoes - Brown
			{ "RightShoe", 8044826993 },
		},
	},
	crypto_carl = {
		height = 1.05,
		width = 0.8,
		skin = "EECCA8",
		props = { "Acc_LeftHand_Tablet" },
		items = {
			{ "Head", 84987410068512 }, -- Mischievous - Head
			{ "Hair", 7193424874 }, -- Medium Middle Part - Blonde
			{ "Hat", 30200159 }, -- Bluetooth Headset
			{ "ClassicShirt", 667687733 }, -- Suspenders Shirt
			{ "Neck", 30379217 }, -- Skinny Tie
			{ "ClassicPants", 667684668 }, -- Black Cuffed Pants
			{ "LeftShoe", 8044838872 }, -- Dress Shoes - B&W
			{ "RightShoe", 8044840214 },
		},
	},
	ceo_chad = {
		height = 1.05,
		width = 1.0,
		skin = "ECBC94",
		props = { "Acc_RightHand_Phone" },
		items = {
			{ "Head", 76823042879558 }, -- Toughguy - Head
			{ "Hair", 29781229 }, -- Slick Attorney
			{ "Face", 63247316 }, -- Golden Aviators
			{ "Jacket", 8516638468 }, -- Business Coat - Gray
			{ "Neck", 38322903 }, -- Superstar Tie
			{ "ClassicPants", 129459077 }, -- Black Slacks
			{ "LeftShoe", 8044843668 }, -- Dress Shoes - Black
			{ "RightShoe", 8044852814 },
		},
	},
	mystery_millionaire = {
		height = 0.95,
		width = 0.85,
		skin = "F0D2BC",
		props = { "Acc_LeftHand_PoodleBag" },
		items = {
			{ "Head", 11829189575 }, -- Old School Smile - Head
			{ "Hair", 17981858 }, -- Ye Olde Powdered Whig (white curls; 027: replaces the tall "Grey - Hair" 7548992599)
			{ "Face", 30390853 }, -- Monocle
			{ "Neck", 14205066264 }, -- Pearl Necklace
			{ "Jacket", 8648397446 }, -- Parka - Brown
			{ "Skirt", 7192696851 }, -- Long Ruffle Skirt - Red
			{ "LeftShoe", 7193104827 }, -- Flats - Black
			{ "RightShoe", 7193106211 },
		},
	},

	-- Velocity Royale (zone id BillionaireHills) -----------------------------------------------
	butler_barnaby = {
		height = 1.0,
		width = 1.0,
		skin = "8D5A3B",
		props = { "Acc_RightHand_WheelGun", "Acc_RightHand_Glow" },
		items = {
			{ "Head", 13692975981 }, -- Friendly Smile - Head
			{ "Hair", 7193405096 }, -- Curly Fade - Black
			{ "Hat", 26423439 }, -- Gamer Headset
			{ "Jacket", 104893588564095 }, -- Creator Showdown Orange Uniform - Jumpsuit
			{ "ClassicPants", 75130319284544 }, -- Creator Showdown Orange Uniform - Pants
			{ "Waist", 133024351363182 }, -- Gear Hoarder Loadout Belt
			{ "LeftShoe", 9542395442 }, -- Work Boots - Black
			{ "RightShoe", 9542450828 },
		},
	},
	caddie_gus = {
		height = 0.97,
		width = 0.9,
		skin = "E8B890",
		props = { "Acc_RightHand_Flag" },
		items = {
			{ "Head", 79654074199621 }, -- Overjoyed Smile - Head
			{ "Hair", 9244122897 }, -- Straight Bangs - Red
			{ "Hat", 1046312258 }, -- Retro Disc Jockey Headphones
			{ "ClassicShirt", 6531997736 }, -- Construction Outfit Shirt
			{ "ClassicPants", 6532001141 }, -- Construction Outfit Pants
			{ "LeftShoe", 7193170137 }, -- Work Boots - Tan
			{ "RightShoe", 7193171232 },
		},
	},
	polo_pro_penny = {
		height = 0.9,
		width = 1.0,
		skin = "C68E5E",
		props = { "Acc_UpperTorso_Camera", "Acc_UpperTorso_Glow" },
		items = {
			{ "Head", 84987410068512 }, -- Mischievous - Head
			{ "Hair", 9244010432 }, -- Curly Fade - Brown
			{ "Hat", 116073839 }, -- Lightning Baseball Cap
			{ "Jacket", 17514359426 }, -- Treasure Finder - Vest
			{ "TShirt", 9120031517 }, -- Baseball Long Sleeve - B&W
			{ "Shorts", 7192684373 }, -- Cargo Shorts - Green
			{ "LeftShoe", 8722108564 }, -- Roblox Running Shoes - Red
			{ "RightShoe", 8722044460 },
		},
	},
	chef_pierre = {
		height = 1.05,
		width = 0.8,
		skin = "5E3F2B",
		props = { "Acc_LeftHand_KeyTray", "Acc_LeftHand_Glow" },
		items = {
			{ "Head", 13692975981 }, -- Friendly Smile - Head
			{ "Hair", 9244021842 }, -- Side Part - Black
			{ "Hat", 35396084 }, -- Bellhop
			{ "Jacket", 7192535654 }, -- Trench Coat - Red
			{ "Neck", 162372840 }, -- Midnight Blue Checkered Bow Tie
			{ "ClassicPants", 129459077 }, -- Black Slacks
			{ "LeftShoe", 8044843668 }, -- Dress Shoes - Black
			{ "RightShoe", 8044852814 },
		},
	},
	bodyguard_boris = {
		height = 1.0,
		width = 0.9,
		skin = "D9A066",
		props = { "Acc_LeftHand_Tablet", "Acc_LeftHand_Glow" },
		items = {
			{ "Head", 101398692064661 }, -- I Am Not Amused - Head
			{ "Hair", 80922343 }, -- Black Symmetrical Bob
			{ "Hat", 100425864 }, -- Deluxe Game Headset
			{ "Jacket", 118820479451814 }, -- Roblox Varsity Jacket
			{ "Pants", 7192681239 }, -- Textured Leather Pants - White
			{ "LeftShoe", 9614791602 }, -- High Tops - Black
			{ "RightShoe", 9614793581 },
		},
	},
	hedge_fund_hank = {
		height = 1.03,
		width = 0.95,
		skin = "F2C9A0",
		props = { "Acc_LeftHand_Helmet", "Acc_LeftHand_Glow" },
		items = {
			{ "Head", 113569146339346 }, -- Award-Winning Smile - Head
			{ "Hair", 7193445686 }, -- Wavy Middle Part - Blonde
			{ "Jacket", 84760111182637 }, -- Creator Showdown Yellow Uniform - Jumpsuit
			{ "ClassicPants", 137923473928520 }, -- Creator Showdown Yellow Uniform - Pants
			{ "Neck", 3690452532 }, -- Triple Threat Gold Medals
			{ "LeftShoe", 9542483996 }, -- Military Boots - Beige
			{ "RightShoe", 9542491319 },
		},
	},
	oil_baron_oswald = {
		height = 1.0,
		width = 1.0,
		skin = "C99B77",
		props = { "Acc_RightHand_Keys", "Acc_RightHand_Glow" },
		items = {
			{ "Head", 11829189575 }, -- Old School Smile - Head
			{ "Hair", 65941340 }, -- Super Slick Hair
			{ "Hat", 131592357 }, -- Fall Flat Cap
			{ "Face", 113326752 }, -- Fancy Goggles
			{ "Face", 16464787717 }, -- Silver Mustache
			{ "Neck", 57781259 }, -- Hipster Scarf
			{ "Jacket", 7192532009 }, -- Trench Coat - Beige
			{ "Pants", 6984740059 }, -- Cargo Pants - Brown (Motorcycle Pants - Brown 8721985925 has no attachment and can't be worn)
			{ "LeftShoe", 9542367726 }, -- Military Boots - Brown
			{ "RightShoe", 9542376078 },
		},
	},
	the_trillionaire = {
		height = 1.05,
		width = 0.85,
		skin = "B07A50",
		props = { "Acc_RightHand_TrophyStaff", "Acc_RightHand_Glow" },
		items = {
			{ "Head", 76823042879558 }, -- Toughguy - Head
			{ "Hair", 7193386173 }, -- Side Part - Blonde
			{ "Hat", 11453654 }, -- Royal Crown
			{ "Face", 134087261 }, -- Gold Visor
			{ "Neck", 689379883 }, -- Necklace O' Gold
			{ "Back", 1340205609 }, -- Glorious Cape of Stars
			{ "Jacket", 7192549218 }, -- Leather Jacket - Black
			{ "ClassicPants", 129459077 }, -- Black Slacks
			{ "LeftShoe", 9614836327 }, -- Military Boots - Black
			{ "RightShoe", 9614841343 },
		},
	},
}

return CustomWorkerLooks
