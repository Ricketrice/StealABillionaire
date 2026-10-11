-- Studio location: ServerScriptService.DevTest_PvP022.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_PvP022 (cloned into PlayerGui during that Studio test
-- only): sends real remote traffic that a server script cannot produce by itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local bridge = ReplicatedStorage:WaitForChild("Test022Bridge")
bridge.OnClientEvent:Connect(function(kind, a, b)
	if kind == "inv" then
		ReplicatedStorage:WaitForChild("InventoryAction"):FireServer(a, b)
	elseif kind == "spam" then
		local pvp = ReplicatedStorage:WaitForChild("PvPAction")
		for i = 1, a do
			if i % 4 == 0 then
				pvp:FireServer("Lock")
			elseif i % 4 == 1 then
				pvp:FireServer("Attack", "basic")
			elseif i % 4 == 2 then
				pvp:FireServer("Equip", true)
			else
				pvp:FireServer({ junk = i }, "basic", i, {}, string.rep("x", 200))
			end
		end
		bridge:FireServer("spammed")
	elseif kind == "loadout" then
		ReplicatedStorage:WaitForChild("PvPAction"):FireServer("Loadout", a, b)
	elseif kind == "probe" then
		-- What this client is showing: read from the markers PvPAlerts, PvPClient and PvPFx keep.
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local alerts, locker = playerGui:FindFirstChild("PvPAlerts"), playerGui:FindFirstChild("PvPLocker")
		local state = { answered = true, barrier = {}, sign = {}, plotAlarm = {}, stolenTags = 0, bannerCount = 0, lockerCards = 0 }
		if alerts then
			state.alarm, state.stolen, state.banner = alerts:GetAttribute("Alarm"), alerts:GetAttribute("Stolen"), alerts:GetAttribute("Banner")
			state.bannerCount = alerts:GetAttribute("BannerCount") or 0
		end
		if locker then
			state.lockerSkin, state.lockerSpecial = locker:GetAttribute("Skin"), locker:GetAttribute("Special")
			for _, d in locker:GetDescendants() do
				if d:IsA("TextButton") and d:GetAttribute("Chosen") ~= nil then
					state.lockerCards += 1
				end
			end
		end
		local fx = workspace:FindFirstChild("PvPLocalFx")
		for _, holder in (fx and fx:GetChildren() or {}) do
			state.barrier[holder.Name], state.sign[holder.Name], state.plotAlarm[holder.Name] = holder:GetAttribute("Barrier"), holder:GetAttribute("Sign"), holder:GetAttribute("Alarm")
		end
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and child.Name == "StolenTag" and child.Enabled and child.Adornee then
				state.stolenTags += 1
			end
		end
		bridge:FireServer("probe", a, state)
	end
end)
