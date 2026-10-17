-- Studio location: ServerScriptService.StudioPhotoMode (Script)
-- StudioPhotoMode  (036): STUDIO-ONLY. Copies the camera spots in ServerStorage.PhotoSpotsDev (invisible parts; each
-- part's CFrame is a camera pose, looking along its front) to ReplicatedStorage so the client's PhotoModeClient can
-- cycle them with P, and streams the world in around a spot when the client asks (remote PhotoModeFocus, Studio only).
-- Live servers never copy them, so players never get the folder.
-- To move a spot: drag its part from ServerStorage into Workspace, place it, then move it back.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local spots = ServerStorage:FindFirstChild("PhotoSpotsDev")
if spots and not ReplicatedStorage:FindFirstChild("PhotoSpotsDev") then
	local copy = spots:Clone()
	local focus = Instance.new("RemoteEvent")
	focus.Name = "PhotoModeFocus"
	focus.Parent = copy
	focus.OnServerEvent:Connect(function(player, position)
		if typeof(position) == "Vector3" then
			pcall(player.RequestStreamAroundAsync, player, position)
		end
	end)
	copy.Parent = ReplicatedStorage
end
