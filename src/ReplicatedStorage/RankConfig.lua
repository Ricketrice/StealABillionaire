-- Studio location: ReplicatedStorage.RankConfig (ModuleScript)
-- RankConfig  (Milestone 030, D25): net-worth ranks over every player's head and on the Top Billionaires board.
-- Net worth = Cash + Income x INCOME_SECONDS (a worker bought with cash keeps its value in income). The rank is
-- never lowered: it comes from the PEAK net worth, saved in the optional field hub.peak (schema stays 3).
-- Thresholds approved by the owner (2026-10-13).

local RankConfig = {}

RankConfig.INCOME_SECONDS = 300
RankConfig.INTERVAL = 2 -- seconds between rank checks

RankConfig.RANKS = {
	{ name = "Peasant", from = 0, color = Color3.fromRGB(190, 190, 200) },
	{ name = "Squire", from = 1000, color = Color3.fromRGB(120, 205, 255) },
	{ name = "Knight", from = 25000, color = Color3.fromRGB(110, 230, 140) },
	{ name = "Captain", from = 250000, color = Color3.fromRGB(255, 170, 60) },
	{ name = "Lord", from = 1000000, color = Color3.fromRGB(200, 120, 255) },
	{ name = "Boss", from = 100000000, color = Color3.fromRGB(255, 220, 60) },
} :: { { name: string, from: number, color: Color3 } }

function RankConfig.worth(cash: number, income: number): number
	return math.max(0, cash) + math.max(0, income) * RankConfig.INCOME_SECONDS
end

-- Index (1..#RANKS) of the rank for this net worth.
function RankConfig.indexFor(worth: number): number
	local index = 1
	for i, rank in RankConfig.RANKS do
		if worth >= rank.from then
			index = i
		end
	end
	return index
end

return RankConfig
