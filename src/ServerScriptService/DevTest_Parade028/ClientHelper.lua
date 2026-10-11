-- Studio location: ServerScriptService.DevTest_Parade028.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Parade028 (cloned into PlayerGui during that Studio test
-- only): walks to parade workers, sends the same ParadeAction "Catch" the Catch prompt sends, and
-- reports what this client is showing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local bridge = ReplicatedStorage:WaitForChild("Test028Bridge")
local paradeAction = ReplicatedStorage:WaitForChild("ParadeAction")
local player = Players.LocalPlayer

local events = {}
ReplicatedStorage:WaitForChild("ParadeEvent").OnClientEvent:Connect(function(kind, info)
	table.insert(events, kind .. (if type(info) == "table" and info.rarity then ":" .. tostring(info.rarity) else ""))
end)
local feedback = {}
ReplicatedStorage:WaitForChild("ClaimFeedback").OnClientEvent:Connect(function(_ok, message)
	table.insert(feedback, tostring(message))
end)

local function nearestWalker(root: BasePart): (Model?, number)
	local folder = workspace:FindFirstChild("Parade") and workspace.Parade:FindFirstChild("Walkers")
	local best, bd = nil, math.huge
	if folder then
		for _, m in folder:GetChildren() do
			local r = m:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - root.Position).Magnitude
				if d < bd then
					best, bd = m, d
				end
			end
		end
	end
	return best, bd
end

-- Walks to the nearest walker and catches it like a player would (Catch is sent once in range).
local function chase(limit: number): { [string]: any }
	local t0 = os.clock()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local result = { inRange = nil, sent = nil, carry = nil, sends = 0 }
	local lastSend = 0
	while os.clock() - t0 < limit do
		if player:GetAttribute("CarryingNPC") then
			result.carry = os.clock() - t0
			break
		end
		local walker, distance = nearestWalker(root)
		if walker then
			local wr = walker:FindFirstChild("HumanoidRootPart") :: BasePart
			humanoid:MoveTo(wr.Position + wr.CFrame.LookVector * 2)
			if distance <= 8 then
				result.inRange = result.inRange or (os.clock() - t0)
				if os.clock() - lastSend > 1.1 then
					lastSend = os.clock()
					result.sent = result.sent or (os.clock() - t0)
					result.sends += 1
					paradeAction:FireServer("Catch", walker)
				end
			end
		end
		task.wait(0.05)
	end
	humanoid:MoveTo(root.Position)
	return result
end

local function frameStats(seconds: number): (number, number)
	local total, worst, n = 0, 0, 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		total += dt
		worst = math.max(worst, dt)
		n += 1
	end)
	task.wait(seconds)
	conn:Disconnect()
	return (if n > 0 then total / n else 0) * 1000, worst * 1000
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	if kind == "chase" then
		bridge:FireServer("reply", id, chase(arg or 12))
	elseif kind == "inv" then -- an inventory request, as the inventory screen sends it
		ReplicatedStorage:WaitForChild("InventoryAction"):FireServer(arg.action, arg.uid)
		bridge:FireServer("reply", id, { sent = true })
	elseif kind == "catch" then -- fire Catch at a given walker straight away
		paradeAction:FireServer("Catch", arg)
		bridge:FireServer("reply", id, { sent = true })
	elseif kind == "probe" then
		local pg = player:WaitForChild("PlayerGui")
		local parade, goal, juice = pg:FindFirstChild("Parade"), pg:FindFirstChild("GoalBook"), pg:FindFirstChild("Juice")
		local state: { [string]: any } = { answered = true, events = table.concat(events, ","), feedback = table.concat(feedback, " | ") }
		state.paradeGui = parade and parade.Enabled
		state.walkersShown = parade and parade:GetAttribute("Walkers")
		state.free = parade and parade:GetAttribute("Free")
		state.pill = parade and parade:FindFirstChild("GoldenPill") and parade.GoldenPill.Text.Text
		state.goal = goal and goal:GetAttribute("Goal")
		state.goalVisible = goal and goal:FindFirstChild("Goal") and goal.Goal.Visible
		state.bookButton = goal and goal:FindFirstChild("BookButton", true) and goal:FindFirstChild("BookButton", true).Visible
		state.juiceGui = juice and juice.Enabled
		local banner = juice and juice:FindFirstChild("RevealBanner")
		state.banner = banner and banner.Visible and banner.WorkerName.Text
		state.sign = workspace:FindFirstChild("ParadeLaneSign") ~= nil
		local foil = 0
		local folder = workspace:FindFirstChild("Parade") and workspace.Parade:FindFirstChild("Walkers")
		if folder then
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") and d.Material == Enum.Material.Foil then
					foil += 1
				end
			end
		end
		state.foil = foil
		if arg == "perf" then
			state.frameAvg, state.frameWorst = frameStats(4)
			local parts, all = 0, 0
			for _, d in workspace:GetDescendants() do
				all += 1
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			state.parts, state.instances = parts, all
			local emitters = 0
			for _, d in workspace:GetDescendants() do
				if d:IsA("ParticleEmitter") and d.Enabled then
					emitters += 1
				end
			end
			state.emitters = emitters
		end
		if arg == "book" and goal then -- open the book (Studio test hook) and read the first page
			goal:SetAttribute("TestOpen", true)
			task.wait(0.6)
			state.bookOpen = goal:GetAttribute("BookOpen")
			state.bookPage = goal:GetAttribute("BookPage")
			state.bookCaught = goal:GetAttribute("BookCaught")
			local colour, silhouettes = 0, 0
			local grid = goal:FindFirstChild("Grid", true)
			if grid then
				for _, card in grid:GetChildren() do
					if card:GetAttribute("Caught") == true then
						colour += 1
					elseif card:GetAttribute("Caught") == false then
						silhouettes += 1
					end
				end
			end
			state.cards = ("%d colour, %d silhouettes"):format(colour, silhouettes)
			goal:SetAttribute("TestOpen", nil)
		end
		events, feedback = {}, {}
		bridge:FireServer("reply", id, state)
	end
end)
