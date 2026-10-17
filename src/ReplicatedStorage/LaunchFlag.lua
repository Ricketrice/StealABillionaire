-- Studio location: ReplicatedStorage.LaunchFlag (ModuleScript)
-- LaunchFlag (036): the one rule every feature switch follows, on the server.
--   Live: the value in the feature's config (the soft-launch set is D46 in docs/GAME_DESIGN.md).
--   Studio: the ServerStorage attribute wins whenever it is set, true OR false, so a test can still turn a live feature off;
--           an unset attribute means the config value.
-- Clients never call this: they read what the server published on ReplicatedStorage.
local RunService = game:GetService("RunService")

return function(configured: boolean?, studioAttribute: string?): boolean
	if studioAttribute and RunService:IsStudio() then
		local value = game:GetService("ServerStorage"):GetAttribute(studioAttribute)
		if value ~= nil then
			return value == true
		end
	end
	return configured == true
end
