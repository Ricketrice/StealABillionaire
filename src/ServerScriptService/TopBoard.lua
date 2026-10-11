-- Studio location: ServerScriptService.TopBoard (Script)
-- TopBoard  (Milestone 027): the "Top Billionaires" board over the parade lane
-- (Workspace.Venues.Leaderboards.TopBillionaires, SurfaceGui "Board" with Row1..Row5) shows the five
-- richest players in this server by their current cash. Display only; it reads the server-owned
-- "Cash" attribute and writes the board only when the ranking text changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))

local REFRESH = 4 -- seconds
local ROWS = 5

local function rows(): { TextLabel }?
	local venues = workspace:FindFirstChild("Venues")
	local boards = venues and venues:FindFirstChild("Leaderboards")
	local board = boards and boards:FindFirstChild("TopBillionaires")
	local gui = board and board:FindFirstChild("Board")
	if not gui then
		return nil
	end
	local list = {}
	for i = 1, ROWS do
		local row = gui:FindFirstChild("Row" .. i)
		if not (row and row:IsA("TextLabel")) then
			return nil
		end
		list[i] = row
	end
	return list
end

local last = table.create(ROWS, "")
while true do
	local labels = rows()
	if labels then
		local ranking = {}
		for _, player in Players:GetPlayers() do
			local cash = player:GetAttribute("Cash")
			if type(cash) == "number" then
				table.insert(ranking, { name = player.DisplayName, cash = cash })
			end
		end
		table.sort(ranking, function(a, b)
			return a.cash > b.cash
		end)
		for i = 1, ROWS do
			local entry = ranking[i]
			local text = if entry then ("%d.  %s  %s"):format(i, entry.name, CashFormat.format(entry.cash)) else ("%d.  —"):format(i)
			if text ~= last[i] then
				labels[i].Text = text
				last[i] = text
			end
		end
	end
	task.wait(REFRESH)
end
