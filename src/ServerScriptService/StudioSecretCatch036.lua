-- Studio location: ServerScriptService.StudioSecretCatch036 (Script)
-- StudioSecretCatch036  (036 boss sweep) -- STUDIO-ONLY remote control for a REAL catch of a Secret creature from the Studio MCP (its own require() cache is separate from the game's).
-- Inert in live servers and unless ServerStorage attribute StudioSecretCatch036 = true (and StudioMemoryStore = true: nothing reaches a real save). Real accounts only (UserId > 0).
-- Write a creature id (mystery_millionaire / the_trillionaire / aquaris, or any roster id) to ServerStorage attribute SecretCatchCmd; the result text appears in SecretCatchResult
-- ("RUNNING ..." while it works, then lines "PASS|FAIL name | detail" and a final "DONE passed=N failed=N").
-- The scenario uses the game's own code: ZoneSpawner's spawn call (NPCWanderer.spawn + WorkerReveal.adoptRolled + NPCClaim.attach), NPCClaim.tryReserve (spin, reveal),
-- NPCCarry (carried), NPCPlacement.tryPlace (pad) and PassiveIncome (coins). Wherever the player has to stand, the script asks first for a server-side teleport and, when the
-- client keeps the character where it was (Play Solo), publishes workspace attribute SecretCatchNeed (Vector3) for the MCP's client side to apply.
-- It records the visible height of the creature when wild, carried and on the pad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local FLAG, CMD, RESULT = "StudioSecretCatch036", "SecretCatchCmd", "SecretCatchResult"
local ZONE_OF = { mystery_millionaire = "MainStreet", the_trillionaire = "BillionaireHills", aquaris = "SunkenKingdom" }

local function mod(name: string): any
	return require(script.Parent:WaitForChild(name))
end
local PlayerData, PlotService, WorkerInventory = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory")
local NPCClaim, NPCCarry, NPCPlacement, NPCWanderer = mod("NPCClaim"), mod("NPCCarry"), mod("NPCPlacement"), mod("NPCWanderer")
local ZoneArea, WorkerReveal, WorkerService, CustomWorkerRigs = mod("ZoneArea"), mod("WorkerReveal"), mod("WorkerService"), mod("CustomWorkerRigs")
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

local busy = false

local function visibleHeight(model: Instance): number
	local lo, hi = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			local half = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local y = d.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)).Y
						lo, hi = math.min(lo, y), math.max(hi, y)
					end
				end
			end
		end
	end
	return if hi > lo then hi - lo else 0
end

local function run(id: string)
	local lines, passed, failed = {}, 0, 0
	local function publish(prefix: string?)
		ServerStorage:SetAttribute(RESULT, (prefix or "") .. table.concat(lines, "\n"))
	end
	local function check(name: string, ok: any, detail: any?)
		if ok then
			passed += 1
		else
			failed += 1
		end
		table.insert(lines, ("%s %s | %s"):format(if ok then "PASS" else "FAIL", name, tostring(detail or "")))
		publish("RUNNING\n")
	end
	local function info(name: string, detail: any)
		table.insert(lines, ("INFO %s | %s"):format(name, tostring(detail)))
		publish("RUNNING\n")
	end
	local function waitUntil(seconds: number, fn: () -> any): any
		local deadline = os.clock() + seconds
		repeat
			local v = fn()
			if v then
				return v
			end
			task.wait(0.1)
		until os.clock() > deadline
		return nil
	end

	local player
	for _, p in Players:GetPlayers() do
		if p.UserId > 0 then
			player = p
			break
		end
	end
	local worker = WorkerCatalogue.get(id)
	local zoneName = ZONE_OF[id] or (worker and worker.zone)
	if not (player and worker and zoneName) then
		check("setup", false, "needs a real player, a roster id and its zone")
		publish("DONE passed=" .. passed .. " failed=" .. failed .. "\n")
		return
	end
	check("persistence is the in-memory store", not PlayerData.isPersistent(), "set ServerStorage StudioMemoryStore = true")
	waitUntil(60, function()
		local c = player.Character
		return PlayerData.isLoaded(player) and PlotService.getPlot(player) and WorkerInventory.isReady(player) and c and c:FindFirstChild("HumanoidRootPart")
	end)
	local function root(): BasePart
		return player.Character.HumanoidRootPart :: BasePart
	end
	local function bring(pos: Vector3)
		pcall(function()
			player.Character:PivotTo(CFrame.new(pos))
		end)
		task.wait(0.5)
		if (root().Position - pos).Magnitude > 8 then
			workspace:SetAttribute("SecretCatchNeed", pos)
			waitUntil(40, function()
				return (root().Position - pos).Magnitude <= 8
			end)
		end
	end

	-- 1. a wild one, spawned exactly the way ZoneSpawner spawns a rolled wanderer
	local zone = ZoneArea.new(workspace.Zones[zoneName])
	local spawnPoint = zone:getSpawnPoints()[1]
	local template = CustomWorkerRigs.getTemplate(id)
	check("the creature has a model", template ~= nil and template:GetAttribute("CreatureId") ~= nil)
	if not (template and spawnPoint) then
		publish("DONE passed=" .. passed .. " failed=" .. failed .. "\n")
		return
	end
	bring(spawnPoint.Position + Vector3.new(0, 4, 8))
	local npc = NPCWanderer.spawn(template, zone, spawnPoint, 5)
	WorkerReveal.adoptRolled(npc, zoneName, id)
	NPCClaim.attach(npc, zone)
	task.wait(1)
	info("wild visible height (studs)", ("%.1f"):format(visibleHeight(npc)))
	local wildH = visibleHeight(npc)
	local rootNpc = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	rootNpc.CFrame = root().CFrame * CFrame.new(0, 0, -3) -- right next to the player (the wander would otherwise walk it off)

	-- 2. the steal: reserve -> spin -> reveal -> carried
	local ok, msg = NPCClaim.tryReserve(player, npc, zone)
	check("steal reserved", ok, msg)
	local carried = waitUntil(20, function()
		return npc:GetAttribute("ClaimPhase") == "Carrying" and npc:GetAttribute("WorkerUid") ~= nil
	end)
	check("revealed and carried after the spin", carried, npc:GetAttribute("ClaimPhase"))
	check("the reveal gave the rolled creature", npc:GetAttribute("WorkerId") == id, npc:GetAttribute("WorkerId"))
	task.wait(1)
	check("NPCCarry holds it", NPCCarry.getCarried(player) == npc)
	local carriedH = visibleHeight(npc)
	info("carried visible height (studs)", ("%.1f (scale attr %s)"):format(carriedH, tostring(npc:GetAttribute("CreatureScale"))))
	check("carried size is normal (within 1.3x of wild)", carriedH <= wildH * 1.31 + 0.2 and carriedH >= wildH * 0.5, ("%.1f vs wild %.1f"):format(carriedH, wildH))

	-- 3. place it on a free pad of the player's base
	local plot = PlotService.getPlot(player)
	local station
	for _, s in plot.Stations:GetChildren() do
		if s:IsA("BasePart") and s:GetAttribute("Occupied") ~= true then
			station = s
			break
		end
	end
	check("a free pad exists", station ~= nil)
	if station then
		bring(station.Position + Vector3.new(0, 4, 0))
		local placed, pmsg = NPCPlacement.tryPlace(player, station)
		check("placed on a pad", placed, pmsg)
		task.wait(1)
		local padH = visibleHeight(npc)
		info("pad visible height (studs)", ("%.1f (scale attr %s)"):format(padH, tostring(npc:GetAttribute("CreatureScale"))))
		check("pad size is normal (within 1.6x of wild)", padH <= wildH * 1.61 + 0.2 and padH >= wildH * 0.5, ("%.1f vs wild %.1f"):format(padH, wildH))
		check("pad copy is the right creature", npc:GetAttribute("WorkerId") == id)
		check("a boss rig, if any, kept its joints", (npc:FindFirstChild("BossRig") == nil) or (npc.BossRig:FindFirstChildWhichIsA("Motor6D", true) ~= nil))

		-- 4. it earns: the Cash attribute rises by about the creature's income per second
		local cash0 = player:GetAttribute("Cash") or 0
		local expected = WorkerService.getIncome(npc)
		task.wait(6)
		local gained = (player:GetAttribute("Cash") or 0) - cash0
		info("income", ("expected %s/s, gained %s in 6 s"):format(tostring(expected), tostring(gained)))
		check("it earns coins on the pad", gained >= expected * 3, ("gained %s, income %s/s"):format(tostring(gained), tostring(expected)))
	end
	publish("DONE passed=" .. passed .. " failed=" .. failed .. "\n")
end

ServerStorage:GetAttributeChangedSignal(CMD):Connect(function()
	local id = ServerStorage:GetAttribute(CMD)
	if ServerStorage:GetAttribute(FLAG) ~= true or type(id) ~= "string" or id == "" or busy then
		return
	end
	busy = true
	ServerStorage:SetAttribute(CMD, "")
	ServerStorage:SetAttribute(RESULT, "RUNNING\n")
	local ok, err = pcall(run, id)
	if not ok then
		ServerStorage:SetAttribute(RESULT, "ERROR " .. tostring(err))
	end
	busy = false
end)
