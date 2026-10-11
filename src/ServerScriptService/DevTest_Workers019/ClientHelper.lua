-- Studio location: ServerScriptService.DevTest_Workers019.ClientHelper (LocalScript)
-- Client half of ServerScriptService.DevTest_Workers019 (cloned into PlayerGui during that Studio
-- test only): sends inventory requests through the real remote and checks the reveal card's preview.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local bridge = ReplicatedStorage:WaitForChild("Test019Bridge")
local action = ReplicatedStorage:WaitForChild("InventoryAction")

local function visible(gui: Instance): boolean
	local node: Instance? = gui
	while node and node ~= playerGui do
		if (node:IsA("GuiObject") and not node.Visible) or (node:IsA("LayerCollector") and not node.Enabled) then
			return false
		end
		node = node.Parent
	end
	return node ~= nil
end

bridge.OnClientEvent:Connect(function(kind, a, b)
	if kind == "inv" then
		action:FireServer(a, b)
	elseif kind == "preview" then
		local deadline, detail = os.clock() + 8, "no preview viewport appeared"
		repeat
			for _, d in playerGui:GetDescendants() do
				local world = d:IsA("ViewportFrame") and d.Name == "Preview" and d:FindFirstChildOfClass("WorldModel")
				local model = world and world:FindFirstChild(a)
				if model and model:IsA("Model") then
					local head = model:FindFirstChild("Head")
					local _, size = model:GetBoundingBox()
					if not (head and head:IsA("MeshPart") and head.MeshId == b) then
						detail = "the preview shows the old model"
					elseif not visible(d) or (d :: ViewportFrame).AbsoluteSize.Y < 40 then
						detail = "the preview is hidden"
					else
						bridge:FireServer("preview", a, true, ("%d px tall, model %.1f studs"):format((d :: ViewportFrame).AbsoluteSize.Y, size.Y))
						return
					end
				end
			end
			task.wait(0.2)
		until os.clock() > deadline
		bridge:FireServer("preview", a, false, detail)
	end
end)
