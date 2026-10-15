-- Studio location: ServerScriptService.DevTest_SpellRun034.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_SpellRun034 (cloned into PlayerGui during that Studio test only): runs
-- the Spell Run course like a player on this client (Humanoid:MoveTo, physics here): it jumps whenever there is a gap
-- ahead or a step too high to walk up, rides the sliding books, records RaceEvent / WorkerRevealed, and presses Leave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local bridge = ReplicatedStorage:WaitForChild("Test034SBridge") :: RemoteEvent
local raceEvent = ReplicatedStorage:WaitForChild("RaceEvent") :: RemoteEvent
local raceAction = ReplicatedStorage:WaitForChild("RaceAction") :: RemoteEvent
local revealEvent = ReplicatedStorage:WaitForChild("WorkerRevealed") :: RemoteEvent

local events: { any } = {}
raceEvent.OnClientEvent:Connect(function(kind, info)
	table.insert(events, { kind = kind, info = info })
end)
revealEvent.OnClientEvent:Connect(function(workerId, uid)
	table.insert(events, { kind = "Reveal", info = { workerId = workerId, uid = uid } })
end)

local function parts(): (Humanoid?, BasePart?)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return h, if r and r:IsA("BasePart") then r else nil
end

-- Runs through `points` in order. Each frame: if the ground 3 studs ahead (towards the point) is missing or more
-- than a walkable step higher, jump. Gives up on a point after 8 s (a stuck player steers on).
local function run(points: { Vector3 }): any
	local h, r = parts()
	if not (h and r) then
		return { stuck = -1, jumps = 0, falls = 0 }
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	params.RespectCanCollide = true
	local stuck, jumps, falls = 0, 0, 0
	local lowest = math.huge
	for _, p in points do
		h:MoveTo(p)
		local t0, lastMove = os.clock(), os.clock()
		while ((r.Position - p) * Vector3.new(1, 0, 1)).Magnitude > 2 do
			local now = os.clock()
			if now - t0 > 8 then
				stuck += 1
				break
			end
			if now - lastMove > 6 then
				h:MoveTo(p) -- (MoveTo gives up after 8 s)
				lastMove = now
			end
			local flat = (p - r.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.5 and h.FloorMaterial ~= Enum.Material.Air then
				local ahead = r.Position + flat.Unit * 3
				local hit = workspace:Raycast(ahead + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
				local feet = r.Position.Y - h.HipHeight - r.Size.Y / 2
				if not hit or hit.Position.Y > feet + 1.2 or hit.Position.Y < feet - 1.5 then
					h.Jump = true
					jumps += 1
				end
			end
			lowest = math.min(lowest, r.Position.Y)
			task.wait()
		end
		if r.Position.Y < p.Y - 12 then
			falls += 1
		end
	end
	return { stuck = stuck, jumps = jumps, falls = falls, lowest = lowest }
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	local reply: any = { answered = true }
	if kind == "clear" then
		table.clear(events)
	elseif kind == "events" then
		reply.events = table.clone(events)
	elseif kind == "run" then
		local t0 = os.clock()
		local result = run(arg.points)
		for k, v in result do
			reply[k] = v
		end
		reply.time = os.clock() - t0
	elseif kind == "leave" then
		raceAction:FireServer("Leave")
		task.wait(0.5)
	end
	bridge:FireServer("reply", id, reply)
end)
bridge:FireServer("ready")
