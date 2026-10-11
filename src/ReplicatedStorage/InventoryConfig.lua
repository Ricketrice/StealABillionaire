-- Studio location: ReplicatedStorage.InventoryConfig (ModuleScript)
-- InventoryConfig
-- Worker storage limits, shared by the server (enforcement) and the inventory UI (display).

return {
	-- Workers a player can keep in storage (not earning).
	INVENTORY_SLOTS = 20,
	-- Workers a player can have on their base's stations (earning). Matches the stations per plot.
	STATION_SLOTS = 6,
}
