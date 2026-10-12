-- Studio location: ReplicatedStorage.ProductConfig (ModuleScript)
-- ProductConfig  (Milestone 029)
-- What the Store screen shows. Purchases are wired in Milestone 031: until an item has a real id
-- (gamepass id / developer product id), its card says "Coming soon" and can't be pressed.
-- Rules (CLAUDE.md, RETENTION_AND_JUICE.md): Robux never buys arena gear or zone unlocks; no pressure
-- wording, no fake timers, no "only X left". Descriptions say plainly what you get.

local ProductConfig = {}

-- kind = "pass" (gamepass, owned forever) | "product" (developer product, bought each time)
ProductConfig.TABS = {
	{ key = "passes", title = "Passes", icon = "vip" },
	{ key = "cash", title = "Cash", icon = "cash" },
	{ key = "starter", title = "Starter", icon = "gift" },
}

ProductConfig.ITEMS = {
	passes = {
		{ key = "x2cash", kind = "pass", id = 0, name = "2x Cash", icon = "x2", text = "All your workers earn double cash, forever." },
		{ key = "slots", kind = "pass", id = 0, name = "Extra Slots", icon = "slots", text = "More storage slots for your workers." },
		{ key = "vip", kind = "pass", id = 0, name = "VIP", icon = "vip", text = "VIP perks for supporters. Details coming soon." },
	},
	cash = {
		{ key = "cash_s", kind = "product", id = 0, name = "Cash Stack", icon = "cash", text = "A stack of cash to spend in the city." },
		{ key = "cash_m", kind = "product", id = 0, name = "Cash Bag", icon = "coin", text = "A bag of cash to spend in the city." },
		{ key = "cash_l", kind = "product", id = 0, name = "Cash Vault", icon = "gem", text = "A vault of cash to spend in the city." },
	},
	starter = {
		{ key = "starter", kind = "product", id = 0, name = "Starter Pack", icon = "gift", text = "A one-time bundle for new players: cash and a head start.", oneTime = true },
	},
}

-- True when the item can be bought (it has a real id). 029: always false.
function ProductConfig.available(item: any): boolean
	return type(item.id) == "number" and item.id > 0
end

return ProductConfig
