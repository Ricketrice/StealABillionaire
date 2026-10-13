-- Studio location: ServerScriptService.DevTest_Heist032.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Heist032 (cloned into PlayerGui during that Studio test only):
-- holds the vault's grab prompt like a player, walks with real Humanoid:MoveTo, jumps / steps out of attacks at
-- the shown time, records HeistEvent + WorkerRevealed (with the server time they arrived), reads the heist HUD,
-- the Speed row and the Store's Trails tab, checks the HUD at phone sizes, sends SpeedRequest (what the Store's
-- buttons send; a script can't tap them) and measures frame time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local bridge = ReplicatedStorage:WaitForChild("Test032Bridge") :: RemoteEvent
local heistEvent = ReplicatedStorage:WaitForChild("HeistEvent") :: RemoteEvent
local revealEvent = ReplicatedStorage:WaitForChild("WorkerRevealed") :: RemoteEvent
local speedRequest = ReplicatedStorage:WaitForChild("SpeedRequest") :: RemoteFunction
local raceAction = ReplicatedStorage:WaitForChild("RaceAction") :: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

local events: { any } = {}
heistEvent.OnClientEvent:Connect(function(kind, info)
	table.insert(events, { kind = kind, info = info, at = now() })
end)
revealEvent.OnClientEvent:Connect(function(workerId, uid)
	table.insert(events, { kind = "Reveal", info = { workerId = workerId, uid = uid }, at = now() })
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

local function walk(points: { Vector3 }, perPoint: number?): number
	local h, r = humanoid(), rootPart()
	if not (h and r) then
		return -1
	end
	local stuck = 0
	for _, p in points do
		h:MoveTo(p)
		local t0 = os.clock()
		while (r.Position * Vector3.new(1, 0, 1) - p * Vector3.new(1, 0, 1)).Magnitude > 2.5 do
			if os.clock() - t0 > (perPoint or 12) then
				stuck += 1
				break
			end
			task.wait()
			if os.clock() - t0 > 7.5 then
				h:MoveTo(p)
			end
		end
	end
	return stuck
end

local function heistFolder(): Instance?
	local world = workspace:FindFirstChild("World")
	local city = world and world:FindFirstChild("SkyCity")
	return city and city:FindFirstChild("Heist")
end

local function rect(g: GuiObject, root: GuiObject): string
	local a = g.AbsolutePosition - root.AbsolutePosition
	return ("(%d,%d %dx%d)"):format(a.X, a.Y, g.AbsoluteSize.X, g.AbsoluteSize.Y)
end

-- HUD check at phone/tablet/PC sizes: each piece visible, on screen, text >= 12 px, and the heist panel and big
-- message clear of the shared top piece.
local CASES = { { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 844, 390 }, { 812, 375 }, { 667, 375 }, { 570, 270 } }
local function hudCheck(): any
	local issues, runs, sizes = {}, 0, {}
	-- the big centre message only shows for a moment: hold a typical one up while measuring
	local heistGui = playerGui:FindFirstChild("Heist032")
	local bigLabel = heistGui and heistGui:FindFirstChild("Big", true) :: TextLabel?
	local bigText = bigLabel and bigLabel.Text
	if bigLabel then
		bigLabel.Text = "SHIELD POPPED! One more hit and the capsule flies back!"
		bigLabel.Visible = true
	end
	for _, size in CASES do
		playerGui:SetAttribute("UITestViewport", Vector2.new(size[1], size[2]))
		playerGui:SetAttribute("UITestTouch", size[1] < 1100)
		task.wait(0.7)
		if bigLabel then
			bigLabel.Visible = true -- (a message timer may have hidden it)
		end
		task.wait(0.1)
		local heist = playerGui:FindFirstChild("Heist032")
		local root = heist and heist:FindFirstChild("Root") :: GuiObject?
		local top = playerGui:FindFirstChild("TopBar028")
		local bar = top and top:FindFirstChild("Bar", true) :: GuiObject?
		local hud = playerGui:FindFirstChild("HudV1")
		local pieces: { GuiObject } = {}
		if root then
			table.insert(pieces, root:FindFirstChild("CarryPanel") :: GuiObject)
			table.insert(pieces, root:FindFirstChild("Big") :: GuiObject)
		end
		if bar then
			table.insert(pieces, bar:FindFirstChild("VaultPill") :: GuiObject)
		end
		local speedRow = hud and hud:FindFirstChild("SpeedRow", true) :: GuiObject?
		if speedRow then
			table.insert(pieces, speedRow)
		end
		for _, g in pieces do
			runs += 1
			if not (g and g.Visible) then
				table.insert(issues, ("%dx%d %s not visible"):format(size[1], size[2], g and g.Name or "?"))
				continue
			end
			local screen = (root or g.Parent) :: GuiObject
			local a0, a1 = g.AbsolutePosition - screen.AbsolutePosition, g.AbsolutePosition - screen.AbsolutePosition + g.AbsoluteSize
			if a0.X < -1 or a0.Y < -1 or a1.X > screen.AbsoluteSize.X + 1 or a1.Y > screen.AbsoluteSize.Y + 1 then
				table.insert(issues, ("%dx%d %s off screen %s"):format(size[1], size[2], g.Name, rect(g, screen)))
			end
			if bar and g.Name ~= "VaultPill" and bar.Visible and bar.AbsoluteSize.X > 0 then
				local b0, b1 = bar.AbsolutePosition, bar.AbsolutePosition + bar.AbsoluteSize
				local c0, c1 = g.AbsolutePosition, g.AbsolutePosition + g.AbsoluteSize
				if c0.X < b1.X - 1 and b0.X < c1.X - 1 and c0.Y < b1.Y - 1 and b0.Y < c1.Y - 1 and g.Name ~= "SpeedRow" then
					table.insert(issues, ("%dx%d %s overlaps the top piece"):format(size[1], size[2], g.Name))
				end
			end
			for _, t in g:GetDescendants() do
				if t:IsA("TextLabel") and t.Text ~= "" and t.TextBounds.Y > 0 and t.TextBounds.Y < 12 then
					table.insert(issues, ("%dx%d %s.%s text %d px"):format(size[1], size[2], g.Name, t.Name, t.TextBounds.Y))
				end
			end
			if size[1] == 667 then
				sizes[g.Name] = rect(g, screen)
			end
		end
	end
	playerGui:SetAttribute("UITestViewport", nil)
	playerGui:SetAttribute("UITestTouch", nil)
	if bigLabel then
		bigLabel.Visible = false
		bigLabel.Text = bigText or ""
	end
	return { runs = runs, issues = issues, phone = sizes }
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	local reply: any = { answered = true }
	if kind == "clear" then
		table.clear(events)
	elseif kind == "events" then
		reply.events = table.clone(events)
		reply.now = now()
	elseif kind == "grab" then
		local folder = heistFolder()
		local spot = folder and folder:FindFirstChild("GrabSpot")
		local prompt = spot and spot:FindFirstChild("GrabPrompt")
		task.wait(0.4) -- (the HUD loop refreshes the prompt's local state every 0.25 s)
		reply.enabled = prompt ~= nil and (prompt :: ProximityPrompt).Enabled
		if prompt and prompt:IsA("ProximityPrompt") then
			-- what holding the prompt does (the hold works even while it's hidden here: the server decides)
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.25)
			prompt:InputHoldEnd()
			task.wait(0.8)
		end
		reply.carrying = player:GetAttribute("HeistCarrying") == true
	elseif kind == "walk" then
		local t0 = os.clock()
		reply.stuck = walk(arg.points, arg.perPoint)
		reply.time = os.clock() - t0
		local r = rootPart()
		reply.pos = r and r.Position
	elseif kind == "jumpAt" then
		-- wait for the shown moment (server time), then jump
		while now() < arg.at do
			task.wait()
		end
		local h, r = humanoid(), rootPart()
		reply.jumpedAt = now()
		if h and r then
			local y0, top, leftAt = r.Position.Y, 0, nil
			-- (the default controls overwrite Humanoid.Jump every frame; the jump state is what a jump press does)
			h:ChangeState(Enum.HumanoidStateType.Jumping)
			local t0 = os.clock()
			while os.clock() - t0 < 1.2 do
				top = math.max(top, r.Position.Y - y0)
				if not leftAt and h.FloorMaterial == Enum.Material.Air then
					leftAt = now()
				end
				task.wait()
			end
			reply.rise, reply.leftAt, reply.jumpPower, reply.jumpHeight = top, leftAt, h.JumpPower, h.JumpHeight
		end
	elseif kind == "stepAt" then
		-- at the shown moment, walk this far (studs, world offset)
		while now() < arg.at do
			task.wait()
		end
		local r = rootPart()
		if r then
			reply.stuck = walk({ r.Position + arg.offset }, 4)
		end
	elseif kind == "ui" then
		local heist = playerGui:FindFirstChild("Heist032")
		local root = heist and heist:FindFirstChild("Root")
		local panel = root and root:FindFirstChild("CarryPanel")
		reply.panel = panel ~= nil and (panel :: GuiObject).Visible
		reply.message = heist and heist:GetAttribute("LastMessage")
		local top = playerGui:FindFirstChild("TopBar028")
		local pill = top and top:FindFirstChild("VaultPill", true)
		reply.pill = pill ~= nil and (pill :: GuiObject).Visible
		reply.pillText = pill and (pill :: any).Text.Text
		local hud = playerGui:FindFirstChild("HudV1")
		local row = hud and hud:FindFirstChild("SpeedRow", true)
		reply.speedRow = row ~= nil and (row :: GuiObject).Visible
		reply.speedText = row and (row :: any).Speed.Text
		local shields = {}
		if panel then
			for i = 1, 2 do
				local s = panel:FindFirstChild("Shield" .. i)
				shields[i] = s and s:IsA("ImageLabel") and s.ImageTransparency or -1
			end
		end
		reply.shields = shields
		local folder = heistFolder()
		local vault = folder and folder:FindFirstChild("Vault")
		local sign = vault and vault:FindFirstChild("Sign")
		local g = sign and sign:FindFirstChild("SignFront")
		reply.signStatus = g and (g :: any).Status.Text
		reply.signOdds = g and (g :: any).Odds.Text
		local door = vault and vault:FindFirstChild("Door")
		local d = door and door:FindFirstChild("Door")
		reply.doorLookX = d and (d :: BasePart).CFrame.LookVector.X -- closed = 1 (faces +X)
		local robot = folder and folder:FindFirstChild("Robot")
		local torso = robot and robot:FindFirstChild("Torso")
		reply.robotPos = torso and (torso :: BasePart).Position
		local bubbles = 0
		local fx = workspace:FindFirstChild("HeistFxLocal")
		for _, c in (if fx then fx:GetChildren() else {}) do
			if c.Name == "Shield" then
				bubbles += 1
			end
		end
		reply.bubbles = bubbles
		local r = rootPart()
		reply.pos = r and r.Position
		local h = humanoid()
		reply.walkSpeed = h and h.WalkSpeed
	elseif kind == "hud" then
		reply.hud = hudCheck()
	elseif kind == "store" then
		local store = playerGui:FindFirstChild("Store029")
		if store then
			store:SetAttribute("TestOpen", "trails")
			task.wait(1)
			reply.tab = store:GetAttribute("Tab")
			local cards = {}
			for _, c in store:GetDescendants() do
				if c:IsA("Frame") and c:GetAttribute("Owned") ~= nil then
					local button = c:FindFirstChild("Buy")
					cards[c.Name] = { owned = c:GetAttribute("Owned"), equipped = c:GetAttribute("Equipped"), button = button and (button :: TextButton).Text }
				end
			end
			reply.cards = cards
			store:SetAttribute("TestOpen", "")
			task.wait(0.3)
		end
	elseif kind == "speed" then
		local ok, result = pcall(function()
			return speedRequest:InvokeServer(arg.action, arg.id)
		end)
		reply.ok, reply.result = ok, result
		task.wait(0.3)
	elseif kind == "trails" then
		local seen = {}
		for _, p in Players:GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local t = r and r:FindFirstChild("SpeedTrail")
			seen[tostring(p.UserId)] = t ~= nil
		end
		reply.seen = seen
	elseif kind == "leaveRace" then
		raceAction:FireServer("Leave")
		task.wait(0.6)
	elseif kind == "perf" then
		-- frame time over `seconds` (this Studio client, not a phone) + what the heist has in the world
		local frames, total, worst = 0, 0, 0
		local conn = RunService.RenderStepped:Connect(function(dt)
			frames += 1
			total += dt
			worst = math.max(worst, dt)
		end)
		local fxMax = 0
		local t0 = os.clock()
		while os.clock() - t0 < arg.seconds do
			local fx = workspace:FindFirstChild("HeistFxLocal")
			fxMax = math.max(fxMax, fx and #fx:GetChildren() or 0)
			task.wait(0.1)
		end
		conn:Disconnect()
		local folder = heistFolder()
		local parts = 0
		for _, d in (if folder then folder:GetDescendants() else {}) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		reply.avgMs = if frames > 0 then total / frames * 1000 else -1
		reply.worstMs = worst * 1000
		reply.heistParts = parts
		reply.fxMax = fxMax
	end
	bridge:FireServer("reply", id, reply)
end)
bridge:FireServer("ready")
