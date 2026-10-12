-- Studio location: ServerScriptService.RankServer (Script)
-- RankServer  (Milestone 030, D25): net-worth rank per player (RankConfig), from the server-owned Cash and
-- Income attributes. Publishes player attributes NetWorth / Rank / RankIndex, puts a rank tag over every head
-- and tells a player when they rank up (RankUp event). Read-only: nothing is saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage:WaitForChild("RankConfig"))

local rankUp = Instance.new("RemoteEvent")
rankUp.Name = "RankUp"
rankUp.Parent = ReplicatedStorage

local function tagFor(character: Model, player: Player)
	local head = character:WaitForChild("Head", 10)
	if not (head and head:IsA("BasePart")) then
		return
	end
	local old = head:FindFirstChild("RankTag")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RankTag"
	gui.Size = UDim2.fromOffset(150, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 24, 40)
	stroke.Parent = label
	label.Parent = gui
	local function paint()
		local rank = RankConfig.RANKS[player:GetAttribute("RankIndex") or 1]
		label.Text = string.upper(rank.name)
		label.TextColor3 = rank.color
	end
	paint()
	gui.Adornee = head
	gui.Parent = head
	local connection = player:GetAttributeChangedSignal("RankIndex"):Connect(paint)
	gui.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

local known: { [Player]: number } = {}

local function update(player: Player)
	local cash, income = player:GetAttribute("Cash"), player:GetAttribute("Income")
	if type(cash) ~= "number" then
		return -- data still loading
	end
	local worth = RankConfig.worth(cash, if type(income) == "number" then income else 0)
	local index = RankConfig.indexFor(worth)
	player:SetAttribute("NetWorth", worth)
	player:SetAttribute("Rank", RankConfig.RANKS[index].name)
	player:SetAttribute("RankIndex", index)
	local before = known[player]
	known[player] = index
	if before and index > before then
		rankUp:FireClient(player, RankConfig.RANKS[index].name, index)
	end
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		tagFor(character, player)
	end)
	if player.Character then
		task.spawn(tagFor, player.Character, player)
	end
end
Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	known[player] = nil
end)

while true do
	for _, player in Players:GetPlayers() do
		update(player)
	end
	task.wait(RankConfig.INTERVAL)
end
