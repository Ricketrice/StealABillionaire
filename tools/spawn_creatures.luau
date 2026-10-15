-- Screenshot row: one Common, Rare, Epic, Legendary and Secret creature for each zone, three rows in front of you.
-- Run in Studio while playing (Play Solo), in the command bar with the SERVER side selected. Not part of the game.
-- Rows: Knight's Keep (front), Sunken Kingdom (middle), Ember Academy (back). Delete them with: workspace.CreatureRows:Destroy()
local Players = game:GetService("Players")
local models = game.ReplicatedStorage:WaitForChild("CreatureModels")
local ROWS = {
	{ "broke_bob", "street_hustler", "security_sam", "ceo_chad", "mystery_millionaire" }, -- Keep: C R E L S
	{ "bubble_fish", "puffer_guard", "shark_knight", "tide_warden", "aquaris" }, -- Sunken
	{ "butler_barnaby", "chef_pierre", "bodyguard_boris", "oil_baron_oswald", "the_trillionaire" }, -- Ember
}
local root = Players:GetPlayers()[1].Character.HumanoidRootPart
local folder = workspace:FindFirstChild("CreatureRows") or Instance.new("Folder")
folder.Name, folder.Parent = "CreatureRows", workspace
local origin = root.CFrame * CFrame.new(0, 0, -14)
for r, ids in ROWS do
	for i, id in ids do
		local m = models[id]:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = true end
		end
		m:PivotTo(origin * CFrame.new((i - 3) * 14, 0, -(r - 1) * 30) * CFrame.Angles(0, math.rad(180), 0) * CFrame.new(0, (m:GetExtentsSize().Y - 5) / 2, 0))
		m.Parent = folder -- the Creature tag makes CreatureClient play the idles + auras (within ~70 studs)
	end
end
return "spawned " .. #folder:GetChildren()
