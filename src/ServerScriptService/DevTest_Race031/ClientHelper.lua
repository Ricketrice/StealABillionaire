-- Studio location: ServerScriptService.DevTest_Race031.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Race031 (cloned into PlayerGui during that Studio test only):
-- runs the circuit with real Humanoid:MoveTo (physics on this client, like a player), records RaceEvent /
-- WorkerRevealed / ClaimFeedback, re-sends fake race messages, checks the race HUD at phone sizes, reads the pad
-- message / billboard and the next-checkpoint arch, and tries to walk or jump (frozen pad, track walls).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local bridge = ReplicatedStorage:WaitForChild("Test031Bridge") :: RemoteEvent
local raceEvent = ReplicatedStorage:WaitForChild("RaceEvent") :: RemoteEvent
local raceAction = ReplicatedStorage:WaitForChild("RaceAction") :: RemoteEvent
local revealEvent = ReplicatedStorage:WaitForChild("WorkerRevealed") :: RemoteEvent
local feedback = ReplicatedStorage:WaitForChild("ClaimFeedback") :: RemoteEvent

local events: { any } = {}
raceEvent.OnClientEvent:Connect(function(kind, info)
	table.insert(events, { kind = kind, info = info })
end)
revealEvent.OnClientEvent:Connect(function(workerId, uid)
	table.insert(events, { kind = "Reveal", info = { workerId = workerId, uid = uid } })
end)
feedback.OnClientEvent:Connect(function(ok, message, title)
	table.insert(events, { kind = "Feedback", info = { ok = ok, message = message, title = title } })
end)

local function humanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function rootPart(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- Walks to each point in turn (gives up on a point after 6 s, like a stuck player would steer on).
local function walk(points: { Vector3 }): number
	local h, r = humanoid(), rootPart()
	if not (h and r) then
		return 0
	end
	local stuck = 0
	for _, p in points do
		h:MoveTo(p)
		local t0 = os.clock()
		while (r.Position * Vector3.new(1, 0, 1) - p * Vector3.new(1, 0, 1)).Magnitude > 2.5 do
			if os.clock() - t0 > 6 then
				stuck += 1
				break
			end
			task.wait()
			if os.clock() - t0 > 7.5 then
				h:MoveTo(p) -- MoveTo gives up after 8 s
			end
		end
	end
	return stuck
end

-- HUD check: the race pieces fit on screen and stay clear of the shared top piece at phone sizes.
local CASES = { { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 844, 390 }, { 812, 375 }, { 667, 375 }, { 570, 270 } }
local function hudCheck(pieces: { string }, settle: number?): any
	local issues, runs = {}, 0
	local cases = table.clone(CASES)
	if settle then -- short-lived pieces (the countdown): phones first
		table.sort(cases, function(x, y)
			return x[2] < y[2]
		end)
	end
	for _, size in cases do
		playerGui:SetAttribute("UITestViewport", Vector2.new(size[1], size[2]))
		playerGui:SetAttribute("UITestTouch", size[1] < 1100)
		task.wait(settle or 0.6)
		local gui = playerGui:FindFirstChild("Race031")
		local root = gui and gui:FindFirstChild("Root") :: GuiObject?
		if not root then
			table.insert(issues, "no Race031 root")
			break
		end
		local top = playerGui:FindFirstChild("TopBar028")
		local bar = top and top:FindFirstChild("Bar", true) :: GuiObject?
		for _, name in pieces do
			runs += 1
			local g = root:FindFirstChild(name) :: GuiObject?
			if not g then
				table.insert(issues, name .. " missing")
				continue
			end
			if not g.Visible then
				table.insert(issues, ("%dx%d %s not visible"):format(size[1], size[2], name))
				continue
			end
			local min, max = g.AbsolutePosition - root.AbsolutePosition, g.AbsolutePosition - root.AbsolutePosition + g.AbsoluteSize
			if min.X < -1 or min.Y < -1 or max.X > root.AbsoluteSize.X + 1 or max.Y > root.AbsoluteSize.Y + 1 then
				table.insert(issues, ("%dx%d %s off screen (%d,%d)-(%d,%d)"):format(size[1], size[2], name, min.X, min.Y, max.X, max.Y))
			end
			if bar and bar.Visible and bar.AbsoluteSize.X > 0 then
				local bmin, bmax = bar.AbsolutePosition, bar.AbsolutePosition + bar.AbsoluteSize
				local a0, a1 = g.AbsolutePosition, g.AbsolutePosition + g.AbsoluteSize
				if a0.X < bmax.X - 1 and bmin.X < a1.X - 1 and a0.Y < bmax.Y - 1 and bmin.Y < a1.Y - 1 then
					table.insert(issues, ("%dx%d %s overlaps the top piece"):format(size[1], size[2], name))
				end
			end
			-- text readable: at least 14 px tall on screen
			for _, t in g:GetDescendants() do
				if t:IsA("TextLabel") and t.Text ~= "" and t.TextBounds.Y > 0 and t.AbsoluteSize.Y < 14 then
					table.insert(issues, ("%dx%d %s.%s text %d px"):format(size[1], size[2], name, t.Name, t.AbsoluteSize.Y))
				end
			end
		end
	end
	playerGui:SetAttribute("UITestViewport", nil)
	playerGui:SetAttribute("UITestTouch", nil)
	return { runs = runs, issues = issues }
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	local reply: any = { answered = true }
	if kind == "clear" then
		table.clear(events)
	elseif kind == "events" then
		reply.events = table.clone(events)
	elseif kind == "walk" then
		local t0 = os.clock()
		reply.stuck = walk(arg.points)
		reply.time = os.clock() - t0
	elseif kind == "resend" then
		-- what an exploiter could send: there is no finish message, so none of this may give anything
		for _ = 1, 5 do
			raceAction:FireServer("Finish")
			raceAction:FireServer("Lap", 3)
			raceAction:FireServer("Capsule", "Gold")
			raceAction:FireServer("State")
			raceAction:FireServer("Leave") -- not racing: must do nothing
		end
		task.wait(1)
	elseif kind == "hud" then
		reply.hud = hudCheck(arg.pieces, arg.settle)
	elseif kind == "creatures" then
		-- samples each showcase creature's root height and its turning joints over ~1.5 s
		local world = workspace:FindFirstChild("World")
		local showcase = world and world.VelocityRoyale:FindFirstChild("CreatureShowcase")
		local seen = {}
		for _ = 1, 12 do
			for _, m in (showcase and showcase:GetChildren() or {}) do
				if m:IsA("Model") and m.PrimaryPart then
					local rec = seen[m.Name] or { ys = {}, joints = {} }
					seen[m.Name] = rec
					table.insert(rec.ys, m.PrimaryPart.Position.Y)
					for _, w in m:GetDescendants() do
						if w:IsA("Weld") then
							local key = w.Parent and w.Parent.Name or "?"
							rec.joints[key] = rec.joints[key] or {}
							table.insert(rec.joints[key], w.C0)
						end
					end
				end
			end
			task.wait(0.12)
		end
		local result = {}
		for name, rec in seen do
			local minY, maxY = math.huge, -math.huge
			for _, y in rec.ys do
				minY, maxY = math.min(minY, y), math.max(maxY, y)
			end
			local moving = 0
			for _, list in rec.joints do
				for i = 2, #list do
					if (list[i].Position - list[1].Position).Magnitude > 0.01 or list[i].LookVector:Dot(list[1].LookVector) < 0.9999 then
						moving += 1
						break
					end
				end
			end
			result[name] = { bob = maxY - minY, movingJoints = moving }
		end
		reply.creatures = result
	elseif kind == "visible" then
		local gui = playerGui:FindFirstChild("Race031")
		local piece = gui and gui:FindFirstChild("Root") and gui.Root:FindFirstChild(arg.piece)
		reply.visible = piece ~= nil and (piece :: GuiObject).Visible
		local course = workspace.World.VelocityRoyale:FindFirstChild("RaceCourse")
		local status = course and course:FindFirstChild("Sign") and course.Sign:FindFirstChild("SignFront") and course.Sign.SignFront:FindFirstChild("Status")
		reply.sign = status and (status :: TextLabel).Text
	elseif kind == "pad" then
		-- the pad message on screen + the billboard above the pad (032)
		local gui = playerGui:FindFirstChild("Race031")
		local msg = gui and gui:FindFirstChild("Root") and gui.Root:FindFirstChild("PadMessage")
		reply.visible = msg ~= nil and (msg :: GuiObject).Visible
		reply.big = msg and (msg :: any).Big.Text
		reply.small = msg and (msg :: any).Small.Text
		local board = playerGui:FindFirstChild("RacePadBillboard") :: BillboardGui?
		reply.board = board and board.Enabled and board.Adornee ~= nil and (board :: any).Big.Text
	elseif kind == "route" then
		-- the next-checkpoint arch (this client's own parts) and the HUD arrow (032)
		local folder = workspace:FindFirstChild("RaceRouteLocal")
		local parts = folder and folder:GetChildren() or {}
		local sum = Vector3.zero
		for _, part in parts do
			sum += (part :: BasePart).Position
		end
		reply.count = #parts
		reply.centre = if #parts > 0 then sum / #parts else nil
		local gui = playerGui:FindFirstChild("Race031")
		local panel = gui and gui:FindFirstChild("Root") and gui.Root:FindFirstChild("RacePanel")
		local arrow = panel and panel:FindFirstChild("NextArrow")
		reply.arrow = panel ~= nil and (panel :: GuiObject).Visible and arrow ~= nil and (arrow :: GuiObject).Visible
	elseif kind == "push" then
		-- walks (and jumps, if asked) towards a point for a few seconds; reports where the character got to
		local h, r = humanoid(), rootPart()
		if h and r then
			local start, rise = r.Position, 0
			local t0 = os.clock()
			while os.clock() - t0 < (arg.seconds or 2) do
				h:MoveTo(arg.to)
				if arg.jump then
					h.Jump = true
				end
				rise = math.max(rise, r.Position.Y - start.Y)
				task.wait(0.1)
			end
			h:MoveTo(r.Position)
			reply.start, reply.finish, reply.rise = start, r.Position, rise
		end
	elseif kind == "leave" then
		-- the Leave race button: shown while racing; sends what its OnActivated sends (a script can't tap it)
		local gui = playerGui:FindFirstChild("Race031")
		local button = gui and gui:FindFirstChild("Root") and gui.Root:FindFirstChild("LeaveRace")
		reply.visible = button ~= nil and (button :: GuiObject).Visible
		reply.height = button and (button :: GuiObject).AbsoluteSize.Y
		if arg and arg.press then
			raceAction:FireServer("Leave")
			task.wait(0.5)
		end
	elseif kind == "texts" then
		local gui = playerGui:FindFirstChild("Race031")
		local root = gui and gui:FindFirstChild("Root")
		local panel = root and root:FindFirstChild("RacePanel")
		reply.lap = panel and (panel :: any).Lap.Text
		reply.time = panel and (panel :: any).Time.Text
		reply.panel = panel and (panel :: GuiObject).Visible
	end
	bridge:FireServer("reply", id, reply)
end)
bridge:FireServer("ready")
