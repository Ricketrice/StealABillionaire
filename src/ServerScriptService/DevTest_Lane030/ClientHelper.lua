-- Studio location: ServerScriptService.DevTest_Lane030.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Lane030 (cloned into PlayerGui during that Studio test only):
-- holds real ProximityPrompts, reports the last LaneNotice, and runs the HUD layout check.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local bridge = ReplicatedStorage:WaitForChild("Test030Bridge") :: RemoteEvent
local notice = ReplicatedStorage:WaitForChild("LaneNotice") :: RemoteEvent

local lastNotice: any = nil
notice.OnClientEvent:Connect(function(ok, title, message)
	lastNotice = { ok = ok, title = title, message = message }
end)

-- Layout check ------------------------------------------------------------------------------------------------
-- 14 landscape screens x normal / worst-case right column (protected + bat out + charging, SIM attributes).
local CASES = {
	{ 1920, 1080 },
	{ 1366, 768 },
	{ 1280, 720 },
	{ 1133, 744 },
	{ 1024, 768 },
	{ 960, 540 },
	{ 932, 430 },
	{ 896, 414 },
	{ 844, 390 },
	{ 812, 375 },
	{ 740, 360 },
	{ 705, 338 },
	{ 667, 375 },
	{ 570, 270 },
}
local function rectOf(g: GuiObject, root: GuiObject): Rect
	local p = g.AbsolutePosition - root.AbsolutePosition
	return Rect.new(p, p + g.AbsoluteSize)
end
local function overlap(a: Rect, b: Rect): boolean
	return a.Min.X < b.Max.X - 1 and b.Min.X < a.Max.X - 1 and a.Min.Y < b.Max.Y - 1 and b.Min.Y < a.Max.Y - 1
end
local function visible(g: Instance): boolean
	local o: Instance? = g
	while o and o:IsA("GuiObject") do
		if not (o :: GuiObject).Visible then
			return false
		end
		o = o.Parent
	end
	return true
end
local function layoutOnce(w: number, h: number, worst: boolean): { string }
	local issues = {}
	playerGui:SetAttribute("UITestViewport", Vector2.new(w, h))
	playerGui:SetAttribute("UITestTouch", w < 1100)
	player:SetAttribute("BatEquipped", if worst then true else nil)
	player:SetAttribute("BatCharging", if worst then true else nil)
	task.wait(0.9)
	local hud = playerGui:FindFirstChild("HudV1")
	local root = hud and hud:FindFirstChild("Root") :: GuiObject?
	if not root then
		return { "no HudV1 root" }
	end
	local groups: { [string]: { { name: string, rect: Rect } } } = { left = {}, right = {}, top = {} }
	local left = hud:FindFirstChild("Left", true)
	local grid = left and left:FindFirstChild("Buttons")
	for _, b in (grid and grid:GetChildren() or {}) do
		if b:IsA("GuiButton") and visible(b) then
			table.insert(groups.left, { name = "menu:" .. b.Name, rect = rectOf(b, root) })
			if math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y) < 44 then
				table.insert(issues, ("button %s under 44 px (%d)"):format(b.Name, math.min(b.AbsoluteSize.X, b.AbsoluteSize.Y)))
			end
		end
	end
	local pill = left and left:FindFirstChild("CashPill", true)
	if pill and pill:IsA("GuiObject") and visible(pill) then
		table.insert(groups.left, { name = "cash", rect = rectOf(pill, root) })
	end
	local pvp = playerGui:FindFirstChild("PvP")
	local actions = pvp and pvp:FindFirstChild("Actions", true)
	for _, item in (actions and actions:GetChildren() or {}) do
		if item:IsA("GuiObject") and visible(item) and item.AbsoluteSize.Y > 1 then
			table.insert(groups.right, { name = "pvp:" .. item.Name, rect = rectOf(item, root) })
		end
	end
	local topGui = playerGui:FindFirstChild("TopBar028")
	local bar = topGui and topGui:FindFirstChild("Bar", true)
	if bar and bar:IsA("GuiObject") and visible(bar) and bar.AbsoluteSize.X > 1 then
		table.insert(groups.top, { name = "top", rect = rectOf(bar, root) })
	end
	local all = {}
	for g, list in groups do
		for _, e in list do
			table.insert(all, { g = g, e = e })
			local r = e.rect
			if r.Min.X < -1 or r.Min.Y < -1 or r.Max.X > w + 1 or r.Max.Y > h + 1 then
				table.insert(issues, ("%s off screen (%d,%d,%d,%d)"):format(e.name, r.Min.X, r.Min.Y, r.Max.X, r.Max.Y))
			end
		end
	end
	for i = 1, #all do
		for j = i + 1, #all do
			if all[i].g ~= all[j].g and overlap(all[i].e.rect, all[j].e.rect) then
				table.insert(issues, ("%s overlaps %s"):format(all[i].e.name, all[j].e.name))
			end
		end
	end
	return issues
end
local function layoutAll(): any
	local result = { cases = 0, issues = {}, menuButtons = 0 }
	for _, c in CASES do
		for _, worst in { false, true } do
			result.cases += 1
			for _, issue in layoutOnce(c[1], c[2], worst) do
				table.insert(result.issues, ("%dx%d%s: %s"):format(c[1], c[2], if worst then " worst" else "", issue))
			end
		end
	end
	playerGui:SetAttribute("UITestViewport", nil)
	playerGui:SetAttribute("UITestTouch", nil)
	player:SetAttribute("BatEquipped", nil)
	player:SetAttribute("BatCharging", nil)
	local grid = playerGui.HudV1:FindFirstChild("Buttons", true)
	for _, b in (grid and grid:GetChildren() or {}) do
		if b:IsA("GuiButton") and b.Visible then
			result.menuButtons += 1
		end
	end
	return result
end

bridge.OnClientEvent:Connect(function(kind, id, arg)
	local reply: any = { answered = true }
	if kind == "layout" then
		reply = layoutAll()
		reply.answered = true
	elseif kind == "clearNotice" then
		lastNotice = nil
	elseif kind == "notice" then
		reply.notice = lastNotice
	elseif kind == "prompt" then
		-- hold the real prompt of the portal for this zone, as a player would
		local found: ProximityPrompt? = nil
		for _, trigger in CollectionService:GetTagged("LanePortal") do
			if trigger:GetAttribute("ZoneId") == arg.zone then
				found = trigger:FindFirstChildOfClass("ProximityPrompt")
			end
		end
		reply.found = found ~= nil
		if found then
			lastNotice = nil
			found:InputHoldBegin()
			task.wait(found.HoldDuration + 0.4)
			found:InputHoldEnd()
			task.wait(1)
			reply.notice = lastNotice
		end
	end
	bridge:FireServer("reply", id, reply)
end)
bridge:FireServer("ready")
