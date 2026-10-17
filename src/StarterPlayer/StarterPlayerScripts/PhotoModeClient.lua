-- Studio location: StarterPlayer.StarterPlayerScripts.PhotoModeClient (LocalScript)
-- PhotoModeClient  (036): STUDIO-ONLY photo mode for the owner's game pictures. P moves the camera to the next spot in
-- ReplicatedStorage.PhotoSpotsDev (copied there by StudioPhotoMode, sorted by name: Knight's Keep courtyard,
-- Malgrave chase, Aquaris, a full base) and hides the HUD; after the last spot P gives the normal camera and HUD back.
-- Does nothing outside Studio or without the folder.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local folder = ReplicatedStorage:WaitForChild("PhotoSpotsDev", 15)
if not folder then
	return
end
local player = Players.LocalPlayer
local index = 0
local hidden: { ScreenGui } = {}

local function spots(): { BasePart }
	local list = {}
	for _, p in (folder :: Instance):GetChildren() do
		if p:IsA("BasePart") then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function setHud(visible: boolean)
	if visible then
		for _, g in hidden do
			g.Enabled = true
		end
		table.clear(hidden)
	elseif #hidden == 0 then
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.P then
		return
	end
	local list = spots()
	local camera = workspace.CurrentCamera
	index += 1
	if index > #list then
		index = 0
		camera.CameraType = Enum.CameraType.Custom
		setHud(true)
		print("[PhotoMode] off")
		return
	end
	setHud(false)
	local focus = folder:FindFirstChild("PhotoModeFocus")
	if focus and focus:IsA("RemoteEvent") then
		focus:FireServer(list[index].Position + list[index].CFrame.LookVector * 40) -- stream in what the camera sees
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = list[index].CFrame
	print(("[PhotoMode] %d/%d %s (P = next)"):format(index, #list, list[index].Name))
end)
