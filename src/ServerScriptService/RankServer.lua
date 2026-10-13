-- Studio location: ServerScriptService.RankServer (Script)
-- RankServer  (Milestone 030, D25): net-worth rank per player (RankConfig), from the server-owned Cash and
-- Income attributes. The rank comes from the PEAK net worth, saved as the optional field hub.peak (whole
-- number, schema stays 3), so it never goes down. Publishes player attributes NetWorth / Peak / Rank /
-- RankIndex, puts a rank tag over every head and tells a player when they rank up (RankUp event).
-- Nothing is published until the player's save has loaded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage:WaitForChild("RankConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local rankUp = Instance.new("RemoteEvent")
rankUp.Name = "RankUp"
rankUp.Parent = ReplicatedStorage

-- The tag is a BillboardGui in the character model, adorned to the CURRENT head (033 fix: a tag was seen
-- floating by a shop sign, left on a head part that was no longer the character's). `ensureTag` runs on spawn, when
-- the character's children change and on every rank tick, and puts it right if the head was swapped or removed.
local function ensureTag(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local gui = character:FindFirstChild("RankTag") :: BillboardGui?
	if not (head and head:IsA("BasePart")) then
		if gui then
			gui.Enabled = false
		end
		return
	end
	if not gui then
		local tag = Instance.new("BillboardGui")
		tag.Name = "RankTag"
		tag.Size = UDim2.fromOffset(150, 30)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
		tag.MaxDistance = 90
		tag.LightInfluence = 0
		tag.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 24, 40)
		stroke.Parent = label
		label.Parent = tag
		tag.Parent = character
		gui = tag
	end
	local tag = gui :: BillboardGui
	if tag.Adornee ~= head then
		tag.Adornee = head
	end
	tag.Enabled = humanoid ~= nil and humanoid.Health > 0
	local label = tag:FindFirstChild("Label") :: TextLabel?
	if label then
		local rank = RankConfig.RANKS[player:GetAttribute("RankIndex") or 1]
		local text = string.upper(rank.name)
		local colour = rank.color
		if player:GetAttribute("IsVIP") == true then -- 033 VIP pass: gold tag with VIP in front
			text, colour = "VIP · " .. text, Color3.fromRGB(255, 205, 60)
		end
		if label.Text ~= text then
			label.Text = text
		end
		if label.TextColor3 ~= colour then
			label.TextColor3 = colour
		end
	end
end

local function tagFor(character: Model, player: Player)
	-- an old head tag from before 033 (or a stray one) never stays behind
	local head = character:WaitForChild("Head", 10)
	if head then
		local old = head:FindFirstChild("RankTag")
		if old then
			old:Destroy()
		end
	end
	ensureTag(player)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			ensureTag(player)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "Head" then
			ensureTag(player)
		end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			ensureTag(player)
		end)
	end
	player:GetAttributeChangedSignal("RankIndex"):Connect(function()
		if player.Character == character then
			ensureTag(player)
		end
	end)
	player:GetAttributeChangedSignal("IsVIP"):Connect(function()
		if player.Character == character then
			ensureTag(player)
		end
	end)
end

local known: { [Player]: number } = {}

local function update(player: Player)
	local cash, income = player:GetAttribute("Cash"), player:GetAttribute("Income")
	local data = PlayerData.get(player) :: any
	if type(cash) ~= "number" or not data then
		return -- data still loading
	end
	local worth = RankConfig.worth(cash, if type(income) == "number" then income else 0)
	local saved = data.hub.peak
	local peak = math.floor(math.max(worth, if type(saved) == "number" then saved else 0))
	if peak ~= saved then
		data.hub.peak = peak -- the autosave carries it
	end
	local index = RankConfig.indexFor(peak)
	player:SetAttribute("NetWorth", worth)
	player:SetAttribute("Peak", peak)
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
		ensureTag(player)
	end
	task.wait(RankConfig.INTERVAL)
end
