-- Studio location: ReplicatedStorage.EconomyConfig (ModuleScript)
-- EconomyConfig
-- Central tuning for the cash economy. All currency is whole dollars.
-- Each worker's own income per second lives in WorkerCatalogue.

return {
	-- Seconds between payouts. Each payout adds every placed worker's income * EARN_INTERVAL.
	EARN_INTERVAL = 1,
}
