-- Studio location: ServerScriptService.DevTest_Vault035 (Script)
-- DevTest_Vault035 -- STUDIO-ONLY two-client test of the Vault wizard test rig (ServerStorage.VaultWizardTest). Inert unless Studio started the session with
-- StudioTestService and the argument "vault035" (launch from Edit: task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, "vault035") end),
-- watch with TAG=TVW tools/test_guard.sh vault035). Cosmetic only: no save data, economy or gameplay is touched; the wizard lives on a temporary sky platform.
-- Checks, on BOTH clients: (1) the wizard is replicated and posed from the clip tables (frozen poses of all 8 clips against glTF forward-kinematics positions),
-- (2) halo scale, (3) live clips: effects appear (beam / temporaries) and every temporary effect is gone afterwards, (4) info: does a server-set Motor6D.Transform replicate?
-- Results: "@@TVW|".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and args == "vault035") then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local lines, passed, failed = {}, 0, 0
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s | %s"):format(kind, name, tostring(detail or ""))
	table.insert(lines, line)
	if kind == "PASS" then
		passed += 1
	elseif kind == "FAIL" then
		failed += 1
	end
	print("@@TVW|" .. line)
end
local function finish(state: string)
	local summary = ("%s passed=%d failed=%d"):format(state, passed, failed)
	print("@@TVW|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end
local function waitUntil(timeout: number, fn: () -> any): any
	local t = os.clock()
	while os.clock() - t < timeout do
		local v = fn()
		if v then
			return v
		end
		task.wait(0.1)
	end
	return nil
end

local ok, err = pcall(function()
	local root = ServerStorage.VaultWizardTest
	local H = require(root.Harness)
	local C = require(root.Tests.Checks)

	local bridge = Instance.new("RemoteEvent")
	bridge.Name = "VW_Bridge"
	bridge.Parent = ReplicatedStorage
	local replies, ready = {}, {}
	bridge.OnServerEvent:Connect(function(p: Player, id: any, reply: any)
		if id == "ready" then
			ready[p] = true
		else
			replies[id] = replies[id] or {}
			replies[id][p] = reply
		end
	end)

	local players
	waitUntil(60, function()
		players = Players:GetPlayers()
		return #players >= 2 and players[1].Character and players[2].Character
	end)
	if not (players and #players >= 2) then
		note("FAIL", "setup", "fewer than 2 players joined")
		return
	end
	note("INFO", "setup", ("%d clients joined: %s"):format(#players, players[1].Name .. ", " .. players[2].Name))

	local m = H.spawn()
	for _, p in players do
		for _, d in (p.Character :: Model):GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
			end
		end
	end
	H.bringPlayers(m)
	for _, p in players do
		local helper = script:WaitForChild("ClientHelper"):Clone()
		helper.Disabled = false
		helper.Parent = p:WaitForChild("PlayerGui")
	end
	waitUntil(30, function()
		return ready[players[1]] and ready[players[2]]
	end)
	task.wait(2)

	local nextId = 0
	-- ask both clients at once; returns { [player] = reply }
	local function askAll(kind: string, arg: any, timeout: number)
		nextId += 1
		local id = "q" .. nextId
		replies[id] = {}
		for _, p in players do
			bridge:FireClient(p, id, kind, arg)
		end
		waitUntil(timeout, function()
			return replies[id][players[1]] and replies[id][players[2]]
		end)
		return replies[id]
	end

	-- 1. both clients see the wizard
	local hello = askAll("hello", nil, 20)
	for i, p in players do
		local r = hello[p]
		if r and r.sees and r.motors == 19 then
			note("PASS", "client " .. i .. " sees the wizard", ("%d parts, %d Motor6D, driver script present=%s"):format(r.parts, r.motors, tostring(r.driver)))
		else
			note("FAIL", "client " .. i .. " sees the wizard", HttpService:JSONEncode(r or "no reply"))
		end
	end

	-- 2. frozen poses of every clip against glTF forward kinematics
	local frozen = {
		{ "Idle", 2 },
		{ "Walk", 2 },
		{ "Steal_Grab", 2 },
		{ "Normal_Repossess", 2 },
		{ "Event_MarketCrash", 2 },
		{ "Event_VaultLock", 3 },
		{ "Event_HostileTakeover", 2 },
		{ "Event_BankruptNova", 3 },
	}
	for _, f in frozen do
		local t = C.freeze(m, f[1], f[2])
		task.wait(0.8)
		local rs = askAll("measure", nil, 15)
		for i, p in players do
			local r = rs[p]
			if r and r.err < 0.02 then
				note("PASS", ("pose %s t=%.2f on client %d"):format(f[1], t, i), ("max pivot error %.4f studs (%s), halo %.2f"):format(r.err, r.part, r.halo))
			else
				note("FAIL", ("pose %s t=%.2f on client %d"):format(f[1], t, i), HttpService:JSONEncode(r or "no reply"))
			end
			if f[1] == "Event_VaultLock" and r then
				if math.abs(r.halo - 5.586) < 0.05 then
					note("PASS", "halo scale 1.9 on client " .. i, r.halo)
				else
					note("FAIL", "halo scale 1.9 on client " .. i, r.halo)
				end
			end
		end
	end
	C.unfreeze(m)
	m:SetAttribute("VW_Clip", nil)
	task.wait(1)

	-- 3. live clips: effects on both clients, temporaries cleaned up
	local live = {
		{ "Normal_Repossess", 1.6, false },
		{ "Event_MarketCrash", 2.4, false },
		{ "Event_VaultLock", 2.4, false },
		{ "Event_HostileTakeover", 2.0, true },
		{ "Event_BankruptNova", 2.8, false },
	}
	for _, l in live do
		nextId += 1
		local id = "q" .. nextId
		replies[id] = {}
		for _, p in players do
			bridge:FireClient(p, id, "watch", l[2] + 3.6)
		end
		task.wait(0.3)
		H.play(m, l[1])
		waitUntil(l[2] + 12, function()
			return replies[id][players[1]] and replies[id][players[2]]
		end)
		for i, p in players do
			local r = replies[id][p]
			local good = r and r.maxTemps > 0 and r.finalTemps == 0 and r.finalEnabled == r.baseEnabled and (not l[3] or r.maxBeams >= 2)
			note(
				good and "PASS" or "FAIL",
				("live %s on client %d"):format(l[1], i),
				r
						and ("effects seen: max temporaries %d, max beams %d, first seen +%.2fs; after the clip: temporaries %d, enabled emitters %d (aura baseline %d)"):format(
							r.maxTemps,
							r.maxBeams,
							r.first,
							r.finalTemps,
							r.finalEnabled,
							r.baseEnabled
						)
					or "no reply"
			)
		end
	end

	-- 4. info: a server-set Transform on a wizard WITHOUT the client driver
	local probe = root.Template:Clone()
	probe.Name = "ProbeNoClient"
	probe.Client:Destroy()
	probe:PivotTo(CFrame.new(Vector3.new(14, 900 + 2.485, 0)))
	probe.Parent = m.Parent
	task.wait(1.5)
	probe.LeftUpperArm.LeftShoulder.Transform = CFrame.Angles(math.rad(80), 0, 0)
	task.wait(1.5)
	local rs = askAll("probe", nil, 15)
	for i, p in players do
		local r = rs[p]
		note(
			"INFO",
			"server-set Motor6D.Transform replication, client " .. i,
			r and ("client sees LeftShoulder x=%.1f deg (server set 80): %s"):format(r.deg, math.abs(r.deg) > 40 and "REPLICATES" or "does NOT replicate") or "no reply"
		)
	end
	probe:Destroy()
end)
if not ok then
	note("FAIL", "test script error", err)
end
finish(failed == 0 and "PASS" or "FAIL")
