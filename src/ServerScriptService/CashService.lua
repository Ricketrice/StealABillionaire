-- Studio location: ServerScriptService.CashService (ModuleScript)
-- CashService
-- Session-only cash balances, in whole dollars. The balance lives on the player's "Cash"
-- attribute so clients can display it; only the server ever writes it (a client changing its own
-- copy doesn't replicate). No persistence yet: the balance is lost when the player leaves.

local Players = game:GetService("Players")

local CashService = {}

local ATTRIBUTE = "Cash"

function CashService.get(player: Player): number
	return player:GetAttribute(ATTRIBUTE) or 0
end

-- Adds a whole, non-negative amount to the player's balance.
function CashService.add(player: Player, amount: number)
	assert(amount >= 0 and amount == math.floor(amount), "cash amounts must be whole and non-negative")
	if amount > 0 then
		player:SetAttribute(ATTRIBUTE, CashService.get(player) + amount)
	end
end

-- Takes a whole, positive amount from the player's balance if they can afford it, and returns
-- whether it did. It never yields, so nothing can change the balance between the check and the
-- deduction, and a balance can never go negative.
function CashService.trySpend(player: Player, amount: number): boolean
	assert(amount > 0 and amount == math.floor(amount), "cash amounts must be whole and positive")
	local balance = CashService.get(player)
	if balance < amount then
		return false
	end
	player:SetAttribute(ATTRIBUTE, balance - amount)
	return true
end

local function initialise(player: Player)
	if player:GetAttribute(ATTRIBUTE) == nil then
		player:SetAttribute(ATTRIBUTE, 0)
	end
end

Players.PlayerAdded:Connect(initialise)
for _, player in Players:GetPlayers() do
	initialise(player)
end

return CashService
