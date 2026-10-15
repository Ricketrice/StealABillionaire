-- Studio location: ServerScriptService.StudioAquarisTest (Script)
-- StudioAquarisTest  (035) -- STUDIO-ONLY play-check helper for the Aquaris boss art. Does nothing in a live server
-- (RunService:IsStudio() first) and nothing in Studio unless ServerStorage attribute "StudioAquarisTest" = true
-- (default unset = off; read when a player joins and again if the flag is switched on during Play).
-- Only real accounts (UserId > 0, the developer in Play Solo) get it; test clients (negative ids) never do.
-- For the player it makes, once per run:
--   * one wild Aquaris (world FX) standing ~30 studs in front of where the character spawned (anchored, not stealable)
--   * one Aquaris on the first free base pad (captured FX)    -- needs the in-memory save (ServerStorage.StudioMemoryStore = true),
--   * one Aquaris in the inventory, to carry from the Creatures menu  -- otherwise refused so nothing reaches a real save.
-- It never touches odds, spawn logic, income formulas or other creatures. The two granted copies live in the player's in-memory data only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local ATTRIBUTE = "StudioAquarisTest"
local ID, ZONE = "aquaris", "SunkenKingdom"
local AHEAD = 30
local WAIT_READY = 60

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))
local WorkerService = require(script.Parent:WaitForChild("WorkerService"))
local NPCWanderer = require(script.Parent:WaitForChild("NPCWanderer"))
local CustomWorkerRigs = require(script.Parent:WaitForChild("CustomWorkerRigs"))

local done: { [Player]: boolean } = {}

local function say(...)
	print("[StudioAquarisTest]", ...)
end

local function enabledFor(player: Player): boolean
	return player.UserId > 0 and ServerStorage:GetAttribute(ATTRIBUTE) == true
end

local function folder(): Folder
	local f = Workspace:FindFirstChild("StudioAquarisTest")
	if not f then
		f = Instance.new("Folder")
		f.Name = "StudioAquarisTest"
		f.Parent = Workspace
	end
	return f :: Folder
end

-- one wild Aquaris, standing still (anchored) in front of the character's spawn, FX world tier (no ClaimPhase)
local function spawnWild(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local template = CustomWorkerRigs.getTemplate(ID)
	if not (hrp and template and template:GetAttribute("CreatureId")) then
		say("no Aquaris template (CreatureModels.aquaris) - nothing spawned")
		return
	end
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local target = hrp.Position + look * AHEAD
	local npc = NPCWanderer.cloneRig(template)
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, npc }
	local hit = Workspace:Raycast(Vector3.new(target.X, hrp.Position.Y + 200, target.Z), Vector3.new(0, -400, 0), params)
	local groundY = if hit then hit.Position.Y else hrp.Position.Y - 3
	local rootCFrame = CFrame.lookAt(Vector3.new(target.X, groundY + humanoid.HipHeight + root.Size.Y / 2, target.Z), Vector3.new(hrp.Position.X, groundY + humanoid.HipHeight + root.Size.Y / 2, hrp.Position.Z))
	npc:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(npc:GetPivot())) -- faces the player
	npc:SetAttribute("CreatureBuiltScale", npc:GetAttribute("CreatureScale"))
	npc.Name = "Aquaris_WildTest"
	npc.Parent = folder()
	root.Anchored = true
	say(("wild Aquaris at %s (%d studs in front of you, facing you)"):format(tostring(target), AHEAD))
end

local function newRecord(location: string): any
	local identity = WorkerService.newIdentity(ID, ZONE)
	return { uid = identity.uid, id = ID, zone = ZONE, level = identity.level, tier = identity.tier, loc = location }
end

local function grantCopies(player: Player)
	if PlayerData.isPersistent() then
		say("REFUSED pad + inventory copies: this session saves to the real DataStore. Set ServerStorage.StudioMemoryStore = true and press Play again.")
		return
	end
	local waited = 0
	while not (WorkerInventory.isReady(player) and PlotService.getPlot(player)) and waited < WAIT_READY and player.Parent do
		task.wait(0.5)
		waited += 0.5
	end
	if not (WorkerInventory.isReady(player) and PlotService.getPlot(player)) then
		say("data / base not ready after", WAIT_READY, "s - no pad or inventory copy")
		return
	end
	local pad = newRecord("carried")
	local where = WorkerInventory.grant(player, pad)
	local plot = PlotService.getPlot(player)
	say(("pad copy: %s | your base is %s at %s"):format(tostring(where), plot and plot.Name or "?", plot and tostring(plot:GetPivot().Position) or "?"))
	local inv = newRecord("inventory")
	local ok = WorkerInventory.give(player, inv, true)
	say("inventory copy:", if ok then "in your Creatures menu (carry it from there)" else "refused (uid clash)")
end

local function run(player: Player)
	if done[player] or not enabledFor(player) then
		return
	end
	done[player] = true
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		task.wait(1) -- let the character land on its spawn
		spawnWild(character)
		grantCopies(player)
	end)
end

Players.PlayerAdded:Connect(run)
for _, p in Players:GetPlayers() do
	run(p)
end
ServerStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
	for _, p in Players:GetPlayers() do
		run(p)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	done[p] = nil
end)
