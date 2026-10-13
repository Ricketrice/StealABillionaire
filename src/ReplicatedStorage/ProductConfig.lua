-- Studio location: ReplicatedStorage.ProductConfig (ModuleScript)
-- ProductConfig  (Milestone 029, purchases wired in 033 (D13, D19, D20))
-- What the Store screen shows and what each purchase gives. Until an item has a real id (gamepass id / developer
-- product id from the Creator Dashboard), its card says "Coming soon" and can't be pressed.
-- Perks, Robux prices, cash pack sizes and starter pack contents: D40 (033 Checkpoint 1). `robux` = the price set on the
-- Creator Dashboard (the Store shows the dashboard's real price). `id` / `image` = the dashboard's pass or product id and
-- its icon's IMAGE id (shown on the Store card; the same art as our icon sheet). Not the decal id: a decal id shows
-- nothing on an ImageLabel (the owner's decals, e.g. 2x Cash 75660006931436, resolved to their images in Studio).
-- Rules (CLAUDE.md, RETENTION_AND_JUICE.md): Robux never buys arena gear, zone unlocks or a PvP advantage; no
-- pressure wording, no fake timers, no "only X left"; packs speed up, never skip. Descriptions say plainly what you get.
-- Switch PURCHASES_ENABLED (Studio ServerStorage StudioPurchases, published PurchasesOn): OFF = no receipts handled,
-- no pass perks, every card "Coming soon" (029 behaviour). Server: PurchaseService.
-- Save (optional fields, schema stays 3): hub.receipts = last RECEIPTS_KEPT purchase ids (a receipt never grants
-- twice), hub.passes = { key = true } (cache of owned passes), hub.starter = true once bought, hub.born = first join.

local CashFormat = require(script.Parent:WaitForChild("CashFormat"))

local ProductConfig = {}

ProductConfig.PURCHASES_ENABLED = false
ProductConfig.STUDIO_ATTRIBUTE = "StudioPurchases"
ProductConfig.PUBLISHED = "PurchasesOn"
ProductConfig.RECEIPTS_KEPT = 50
ProductConfig.STARTER_DAYS = 3 -- the Starter Pack shows for this many days after a player's first visit (no timer shown)

-- kind = "pass" (gamepass, owned forever) | "product" (developer product, bought each time)
ProductConfig.TABS = {
	{ key = "passes", title = "Passes", icon = "vip" },
	{ key = "cash", title = "Cash", icon = "cash" },
	{ key = "starter", title = "Starter", icon = "gift" },
}

ProductConfig.ITEMS = {
	passes = {
		{
			key = "x2cash",
			kind = "pass",
			id = 2033726439,
			image = 127119917266817,
			robux = 349, -- (design range 300-500)
			name = "2x Cash",
			icon = "x2",
			text = "All your workers earn double cash, forever.",
			income = 2, -- income multiplier
		},
		{
			key = "slots",
			kind = "pass",
			id = 2032784431,
			image = 78461610662957,
			robux = 249, -- (design range 250-400)
			name = "Extra Slots",
			icon = "slots",
			text = "+2 pads on your base and +10 storage slots, forever.",
			storage = 10, -- extra storage slots (the 2 pads: BaseConfig.PASS_PADS)
		},
		{
			key = "vip",
			kind = "pass",
			id = 2032880454,
			image = 94085601107802,
			robux = 399, -- (design range 300-600)
			name = "VIP",
			icon = "vip",
			text = "Gold VIP name tag, [VIP] in chat and +10% cash from your workers.",
			income = 1.1,
		},
	},
	cash = {
		-- Cash = this many minutes of the player's income right now (D20), never less than `min`.
		{ key = "cash_s", kind = "product", id = 3718403577, image = 135172755442871, robux = 25, minutes = 10, min = 5000, name = "Cash Stack", icon = "cash" },
		{ key = "cash_m", kind = "product", id = 3718403637, image = 73796793747790, robux = 75, minutes = 40, min = 20000, name = "Cash Bag", icon = "coin" },
		{ key = "cash_l", kind = "product", id = 3718403689, image = 124355440961295, robux = 199, minutes = 120, min = 75000, name = "Cash Vault", icon = "cash" },
	},
	starter = {
		{
			key = "starter",
			kind = "product",
			id = 3718403719,
			image = 97190772594635,
			robux = 49,
			minutes = 30,
			min = 15000,
			trail = "starter", -- SpeedConfig trail given with it (looks only: the same speed as the Bubble Trail)
			name = "Starter Pack",
			icon = "gift",
			text = "One time: 30 minutes of your income (at least $15,000) and the Starter Sparkle trail.",
			oneTime = true,
		},
	},
}

ProductConfig.BY_KEY = {}
for _, list in ProductConfig.ITEMS do
	for _, item in list do
		ProductConfig.BY_KEY[item.key] = item
		if item.minutes and not item.text then
			item.text = ("%d minutes of your income (at least %s)."):format(item.minutes, CashFormat.format(item.min))
		end
	end
end

-- True when the item can be bought (it has a real id).
function ProductConfig.available(item: any): boolean
	return type(item.id) == "number" and item.id > 0
end

-- Cash a product gives a player who earns `income` $/s now.
function ProductConfig.cashFor(item: any, income: number): number
	return math.max(item.min or 0, math.floor((item.minutes or 0) * 60 * math.max(0, income)))
end

-- Whether purchases are on. Server: config or (Studio) the ServerStorage attribute. Client: the published attribute.
function ProductConfig.on(): boolean
	local RunService = game:GetService("RunService")
	if RunService:IsServer() then
		return ProductConfig.PURCHASES_ENABLED == true or (RunService:IsStudio() and game:GetService("ServerStorage"):GetAttribute(ProductConfig.STUDIO_ATTRIBUTE) == true)
	end
	return game:GetService("ReplicatedStorage"):GetAttribute(ProductConfig.PUBLISHED) == true
end

return ProductConfig
