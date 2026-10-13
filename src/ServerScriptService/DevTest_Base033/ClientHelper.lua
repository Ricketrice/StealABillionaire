-- Studio location: ServerScriptService.DevTest_Base033.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Base033 (cloned into PlayerGui during that Studio test only): sends
-- what the screens send (BaseRequest, InventoryAction, RewardsAction), holds the pad prompts like a player, reads
-- the NEW! hint, level badges, shields, the Store cards and the living-base props and poses, and measures frame time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local bridge = ReplicatedStorage:WaitForChild("Test033Bridge") :: RemoteEvent
local baseEvent = ReplicatedStorage:WaitForChild("BaseEvent") :: RemoteEvent
local baseRequest = ReplicatedStorage:WaitForChild("BaseRequest") :: RemoteFunction
local inventoryAction = ReplicatedStorage:WaitForChild("InventoryAction") :: RemoteEvent
local inventoryAck = ReplicatedStorage:WaitForChild("InventoryAck") :: RemoteEvent
local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")

local events: { any } = {}
baseEvent.OnClientEvent:Connect(function(kind, info)
	table.insert(events, { kind = kind, info = info })
end)
local acks: { [number]: any } = {}
inventoryAck.OnClientEvent:Connect(function(id, ok, message, retry)
	acks[id] = { ok = ok, message = message, retry = retry }
end)

local function ownPlot(): Instance?
	local id = player:GetAttribute("PlotId")
	return id and plots:FindFirstChild("Plot" .. id)
end
local function modelByUid(uid: string): Model?
	for _, plot in plots:GetChildren() do
		local placed = plot:FindFirstChild("PlacedNPCs")
		for _, m in (if placed then placed:GetChildren() else {}) do
			if m:GetAttribute("WorkerUid") == uid and m:IsA("Model") then
				return m
			end
		end
	end
	return nil
end
local function hold(prompt: ProximityPrompt)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.25)
	prompt:InputHoldEnd()
	task.wait(1)
end
local function driven(): number
	local n = 0
	local plot = ownPlot()
	local placed = plot and plot:FindFirstChild("PlacedNPCs")
	for _, m in (if placed then placed:GetChildren() else {}) do
		for _, d in m:GetDescendants() do
			local t = if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then (d :: any).Transform :: CFrame else nil
			if t and (t.Position.Magnitude > 0.01 or t.LookVector:Dot(Vector3.new(0, 0, -1)) < 0.9999) then
				n += 1
			end
		end
	end
	return n
end
local function propCount(): number
	local folder = workspace:FindFirstChild("BaseLifeLocal")
	return if folder then #folder:GetChildren() else 0
end
local JOBS = { Earner = "laptop", Fighter = "pushups", Tank = "guard", ["All-rounder"] = "sweep" }

local nextId = 900000
bridge.OnClientEvent:Connect(function(kind, id, arg)
	local reply: any = { answered = true }
	if kind == "clear" then
		table.clear(events)
	elseif kind == "events" then
		reply.events = table.clone(events)
		local hint = playerGui:FindFirstChild("Base033") and playerGui.Base033:FindFirstChild("NewHint", true)
		reply.hintVisible = hint ~= nil and hint.Visible
		local text = hint and hint:FindFirstChild("Text")
		reply.hintText = if text then text.Text else nil
	elseif kind == "levelUp" then
		local ok, granted, message = pcall(baseRequest.InvokeServer, baseRequest, "LevelUp", arg)
		reply.ok = ok and granted == true
		reply.message = message
	elseif kind == "unlockRemote" then
		local ok, granted, message = pcall(baseRequest.InvokeServer, baseRequest, "UnlockPad")
		reply.ok = ok and granted == true
		reply.message = message
	elseif kind == "padLevel" then
		task.wait(0.5) -- (BaseClient picks the nearest prompt every 0.15 s)
		local enabled, target = 0, nil
		for _, d in plots:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "LevelPrompt" and d.Enabled then
				enabled += 1
				target = d
			end
		end
		reply.enabled = enabled
		if target then
			hold(target)
		end
	elseif kind == "unlockPrompt" then
		task.wait(0.5)
		local plot = ownPlot()
		local pad = plot and plot:FindFirstChild("PadUnlock")
		local prompt = pad and pad:FindFirstChild("UnlockPrompt") :: ProximityPrompt?
		reply.enabled = prompt ~= nil and prompt.Enabled
		if prompt then
			hold(prompt)
		end
	elseif kind == "inventory" then
		nextId += 1
		local rid = nextId
		for _ = 1, 5 do -- (re-sent like WorkerState when the server says "too fast, try again")
			acks[rid] = nil
			inventoryAction:FireServer(arg.action, arg.uid, rid)
			local t0 = os.clock()
			while not acks[rid] and os.clock() - t0 < 5 do
				task.wait(0.1)
			end
			if not (acks[rid] and acks[rid].retry) then
				break
			end
			task.wait(0.3)
		end
		reply.ok = acks[rid] and acks[rid].ok
	elseif kind == "badge" then
		local m = modelByUid(arg)
		local badge = m and m:FindFirstChild("LevelBadge")
		local label = badge and badge:FindFirstChild("Level")
		reply.badge = if label then label.Text else nil
		reply.glow = m ~= nil and m:FindFirstChild("LevelGlow", true) ~= nil
	elseif kind == "shield" then
		task.wait(0.5)
		local m = modelByUid(arg)
		reply.shield = m ~= nil and m:FindFirstChild("FavShield") ~= nil
	elseif kind == "setIds" then
		local ProductConfig = require(ReplicatedStorage:WaitForChild("ProductConfig")) :: any
		for key, value in arg do
			ProductConfig.BY_KEY[key].id = value
		end
	elseif kind == "favourite" then
		ReplicatedStorage:WaitForChild("RewardsAction"):FireServer("Favourite", arg, true)
		task.wait(1)
		reply.ok = true
	elseif kind == "ui" then
		local store = playerGui:FindFirstChild("Store029")
		local available, owned, open = 0, 0, false
		if store then
			for _, d in store:GetDescendants() do
				if d:IsA("Frame") and d:GetAttribute("Available") == true then
					available += 1
				end
				if d:IsA("Frame") and d:GetAttribute("Owned") == true and d:GetAttribute("Available") ~= nil then
					owned += 1
				end
			end
			local win = store:FindFirstChild("Store", true)
			open = win ~= nil and win:IsA("GuiObject") and win.Visible and store.Enabled
		end
		reply.storeAvailable, reply.owned, reply.storeOpen = available, owned, open
		if store then
			local tabs = store:FindFirstChild("Tabs", true)
			reply.starterTab = tabs ~= nil and tabs:FindFirstChild("Tab_starter", true) ~= nil
		end
	elseif kind == "living" then
		task.wait(0.5)
		reply.props = propCount()
		reply.driven = driven()
		local seen = {}
		local plot = ownPlot()
		local placed = plot and plot:FindFirstChild("PlacedNPCs")
		for _, m in (if placed then placed:GetChildren() else {}) do
			local job = JOBS[m:GetAttribute("Role") or ""]
			if job then
				seen[job] = true
			end
			local stations = plot and plot:FindFirstChild("Stations")
			local pad = nil
			for _, s in (if stations then stations:GetChildren() else {}) do
				if s:GetAttribute("StationIndex") == m:GetAttribute("StationIndex") then
					pad = s
				end
			end
			local padTop = pad and pad.Position.Y + pad.Size.X / 2
			local hand = m:FindFirstChild("RightHand")
			local head = m:FindFirstChild("Head")
			local rootPart = m:FindFirstChild("HumanoidRootPart")
			if job == "pushups" and padTop and hand and head and not reply.pushupHands then
				reply.pushupHands = hand.Position.Y - padTop
				reply.pushupHead = head.Position.Y - padTop
			elseif job == "laptop" and hand and rootPart and not reply.deskGap then
				reply.deskGap = hand.Position.Y - (rootPart.Position.Y + 0.3)
			end
		end
		local list = {}
		for job in seen do
			table.insert(list, job)
		end
		table.sort(list)
		reply.jobsSeen = table.concat(list, ",")
	elseif kind == "perf" then
		local frames, total, worst = 0, 0, 0
		local conn = RunService.RenderStepped:Connect(function(dt)
			frames += 1
			total += dt
			worst = math.max(worst, dt)
		end)
		task.wait(arg.seconds)
		conn:Disconnect()
		reply.avgMs = if frames > 0 then total / frames * 1000 else -1
		reply.worstMs = worst * 1000
		reply.props = propCount()
		reply.driven = driven()
	end
	bridge:FireServer("reply", id, reply)
end)
bridge:FireServer("ready")
