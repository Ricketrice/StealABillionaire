-- Studio location: ServerScriptService.StudioDevToolsServer (Script)
-- StudioDevToolsServer  (032): entry point for the Studio-only dev tools (see StudioDevTools). Does nothing
-- in a live server; in Studio nothing is active unless ServerStorage.StudioDevTools = true.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

require(script.Parent:WaitForChild("StudioDevTools")).start()
