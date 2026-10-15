-- Studio location: ReplicatedStorage.CashFormat (ModuleScript)
-- CashFormat
-- Formats whole-dollar amounts for display, on both server (pad labels) and client (HUD).
--   12345      -> "$12,345"   (full value below one million)
--   1250000    -> "$1.25M"
--   3400000000 -> "$3.4B"

local CashFormat = {}

-- The money sign on every amount in the game (034: one place to change it; 035 swaps it for a coin symbol).
CashFormat.SYMBOL = "$"

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }
local ABBREVIATE_FROM = 1e6

-- "1234567" -> "1,234,567"
function CashFormat.commas(amount: number): string
	local digits = tostring(math.floor(amount))
	return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function CashFormat.format(amount: number): string
	amount = math.max(0, math.floor(amount))
	if amount < ABBREVIATE_FROM then
		return CashFormat.SYMBOL .. CashFormat.commas(amount)
	end

	local tier = math.min(math.floor(math.log10(amount) / 3), #SUFFIXES)
	local value = amount / 10 ^ (3 * tier)
	if value >= 999.5 and tier < #SUFFIXES then -- would round up to "1000M"
		tier += 1
		value /= 1000
	end

	local text = string.format(if value >= 100 then "%.0f" elseif value >= 10 then "%.1f" else "%.2f", value)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "") -- "1.50" -> "1.5", "2.00" -> "2"
	end
	return CashFormat.SYMBOL .. text .. SUFFIXES[tier]
end

return CashFormat
