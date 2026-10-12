-- Studio location: ServerScriptService.DevTest_V1029.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_V1029 (cloned into PlayerGui during that Studio test
-- only): sends real RewardsAction traffic and reports what this client's screens show.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local bridge = ReplicatedStorage:WaitForChild("Test029Bridge") :: RemoteEvent
local action = ReplicatedStorage:WaitForChild("RewardsAction") :: RemoteEvent
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local WINDOWS = { Daily = "Rewards029", Gifts = "Rewards029", Settings = "Rewards029", Offline = "Rewards029", Store = "Store029", Index = "Index029" }

local function visibleChain(obj: GuiObject): boolean
	local o: Instance? = obj
	while o and o:IsA("GuiObject") do
		if not (o :: GuiObject).Visible then
			return false
		end
		o = o.Parent
	end
	return true
end

local function probe(): any
	local s: any = { answered = true, open = {}, openCount = 0, fits = {}, fitsDetail = {}, windowSmallest = {}, texts = {}, buttons = {}, badges = {} }
	local hud = playerGui:FindFirstChild("Hud")
	s.hud = hud ~= nil and hud:FindFirstChild("Root") ~= nil and #hud.Root:GetChildren() > 0
	local v1 = playerGui:FindFirstChild("HudV1")
	s.hudV1 = v1 ~= nil
	if v1 then
		local left = v1:FindFirstChild("Left", true)
		local pill = left and left:FindFirstChild("CashPill")
		s.cashText = pill and (pill:FindFirstChild("Amount") :: TextLabel).Text
		local grid = left and left:FindFirstChild("Buttons")
		local smallest = math.huge
		for _, b in (grid and grid:GetChildren() or {}) do
			if b:IsA("TextButton") then
				s.buttons[b.Name] = b.Visible
				local badge = b:FindFirstChild("Badge") :: TextLabel?
				s.badges[b.Name] = badge ~= nil and badge.Visible
				if b.Visible then
					smallest = math.min(smallest, b.AbsoluteSize.X, b.AbsoluteSize.Y)
				end
			end
		end
		s.smallest = smallest
	end
	for name, guiName in WINDOWS do
		local gui = playerGui:FindFirstChild(guiName)
		local frame = gui and gui:FindFirstChild(name, true)
		if frame and frame:IsA("Frame") and frame:GetAttribute("Open") == true then
			s.open[name] = true
			s.openCount += 1
			local root = gui:FindFirstChild("Root") :: Frame
			local lo, hi = root.AbsolutePosition, root.AbsolutePosition + root.AbsoluteSize
			local ok, worst, small = true, "", math.huge
			for _, d in frame:GetDescendants() do
				if d:IsA("GuiObject") and visibleChain(d) and d.AbsoluteSize.X > 0 then
					local p, q = d.AbsolutePosition, d.AbsolutePosition + d.AbsoluteSize
					if p.X < lo.X - 1 or p.Y < lo.Y - 1 or q.X > hi.X + 1 or q.Y > hi.Y + 1 then
						ok = false
						worst = d:GetFullName():sub(-60) .. (" %d,%d-%d,%d in %d,%d-%d,%d"):format(p.X, p.Y, q.X, q.Y, lo.X, lo.Y, hi.X, hi.Y)
					end
					if d:IsA("TextButton") and d:GetAttribute("Kind") ~= nil then
						small = math.min(small, d.AbsoluteSize.X, d.AbsoluteSize.Y)
					end
				end
			end
			s.fits[name], s.fitsDetail[name], s.windowSmallest[name] = ok, worst, small
		end
	end
	local rewards = playerGui:FindFirstChild("Rewards029")
	if rewards then
		local daily = rewards:FindFirstChild("Daily", true)
		local claim = daily and daily:FindFirstChild("Claim", true)
		s.texts.dailyButton = claim and (claim :: TextButton).Text
		local off = rewards:FindFirstChild("Offline", true)
		local body = off and off:FindFirstChild("Body", true)
		s.texts.offline = body and (body :: TextLabel).Text
		s.lastClaim = rewards:GetAttribute("LastClaim")
	end
	local burst = playerGui:FindFirstChild("CoinBurst")
	s.coins = burst and #burst:GetChildren() or 0
	local store = playerGui:FindFirstChild("Store029")
	if store then
		s.storeTab = store:GetAttribute("Tab")
		local items = store:FindFirstChild("Items", true)
		s.storeItems, s.storeAvailable = 0, 0
		for _, card in (items and items:GetChildren() or {}) do
			if card:IsA("Frame") then
				s.storeItems += 1
				s.storeAvailable += if card:GetAttribute("Available") == true then 1 else 0
			end
		end
	end
	local index = playerGui:FindFirstChild("Index029")
	s.indexPage = index and index:GetAttribute("Page")
	return s
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	local reply: any = { answered = true }
	if kind == "act" then
		action:FireServer(arg.action, arg.a, arg.b)
	elseif kind == "spam" then
		for _ = 1, arg.n do
			action:FireServer(arg.action)
		end
	elseif kind == "open" then
		local gui = playerGui:FindFirstChild(arg.gui)
		if gui then
			gui:SetAttribute("TestOpen", nil)
			gui:SetAttribute("TestOpen", arg.name)
		end
	elseif kind == "probe" then
		reply = probe()
	elseif kind == "inv" then -- through WorkerState: an id, re-sent until answered
		local WorkerState = require(ReplicatedStorage:WaitForChild("WorkerState")) :: any
		if arg.action ~= "none" then
			WorkerState.request(arg.action, arg.uid)
		end
		reply.pending = WorkerState.pending()
	elseif kind == "invRaw" then -- one message with a chosen id, exactly as given
		ReplicatedStorage:WaitForChild("InventoryAction"):FireServer(arg.action, arg.uid, arg.id)
	elseif kind == "inventory" then
		local UIKit = require(ReplicatedStorage:WaitForChild("UIKit")) :: any
		UIKit.Signals.ToggleInventory:Fire(true)
		task.wait(0.5)
		local inv = playerGui:FindFirstChild("Inventory")
		local card = inv and inv:FindFirstChild(arg.uid, true)
		reply.star = card ~= nil and card:FindFirstChild("Favourite", true) ~= nil
		reply.sort = inv ~= nil and inv:FindFirstChild("Sort", true) ~= nil
		UIKit.Signals.ToggleInventory:Fire(false)
	end
	bridge:FireServer("reply", id, reply)
end)
