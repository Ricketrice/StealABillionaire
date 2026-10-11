-- Studio location: ServerScriptService.DevTest_Hub026.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Hub026 (cloned into PlayerGui during that Studio test
-- only): sends real remote traffic and reports what this client is showing.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local bridge = ReplicatedStorage:WaitForChild("Test026Bridge")
bridge.OnClientEvent:Connect(function(kind, a, ...)
	if kind == "hub" then
		ReplicatedStorage:WaitForChild("HubAction"):FireServer(a, ...)
	elseif kind == "pvp" then
		ReplicatedStorage:WaitForChild("PvPAction"):FireServer(a, ...)
	elseif kind == "probe" then
		local player = Players.LocalPlayer
		local gui = player:WaitForChild("PlayerGui"):FindFirstChild("Hub")
		local state = { answered = true, npcs = #CollectionService:GetTagged("HubNPC"), decor = 0 }
		if gui then
			state.open, state.speaker, state.line = gui:GetAttribute("Open"), gui:GetAttribute("Speaker"), gui:GetAttribute("Line")
			state.tutorial, state.states = gui:GetAttribute("Tutorial"), gui:GetAttribute("States") or 0
		end
		local okState, WorkerState = pcall(require, ReplicatedStorage:WaitForChild("WorkerState"))
		state.slots = if okState then WorkerState.snapshot.slots else nil
		state.stations = if okState then WorkerState.snapshot.stations else nil
		local lockerGui = player.PlayerGui:FindFirstChild("PvPLocker")
		local skins = lockerGui and lockerGui:FindFirstChild("Skins", true)
		if skins then -- the bat looks the weapon locker offers, e.g. "Neon,Starter"
			local shown = {}
			for _, card in skins:GetChildren() do
				if card:IsA("GuiButton") and card.Visible then
					table.insert(shown, card.Name)
				end
			end
			table.sort(shown)
			state.locker = table.concat(shown, ",")
		end
		local city = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("BillionaireCity")
		local decor = city and city:FindFirstChild("LotDecor")
		local mine = decor and decor:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotId")))
		state.decor = if mine then #mine:GetChildren() else 0
		bridge:FireServer("probe", a, state)
	end
end)
