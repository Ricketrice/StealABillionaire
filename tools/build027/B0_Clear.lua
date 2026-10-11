-- Studio location: ServerStorage.Build027.B0_Clear (ModuleScript)
-- Removes everything the D6 map replaces (a full copy is in ServerStorage._Backups.Pre027_Phase2_2026-10-12).
-- Never touches Zones 2-5, Zone 6 (VelocityRoyale, Zone6_BillionaireHills, BillionaireCity.Zone6Plaza),
-- the Billionaire Plaza floor or any district gate.

local K = require(script.Parent.Kit)

return function(): string
	local world = workspace.World
	local removed = {}
	local function drop(inst: Instance?, label: string)
		if inst then
			table.insert(removed, ("%s(%d)"):format(label, K.count(inst) + (if inst:IsA("BasePart") then 1 else 0)))
			inst:Destroy()
		end
	end
	drop(world:FindFirstChild("MainStreet"), "World.MainStreet")
	drop(world:FindFirstChild("Scenery"), "Scenery")
	drop(world:FindFirstChild("AssetKit"), "AssetKit")
	drop(world.Islands:FindFirstChild("HomeIsland"), "HomeIsland")
	drop(world.Bridges:FindFirstChild("HomeBridge"), "HomeBridge")
	for _, name in { "HomeBridgeGuard1", "HomeBridgeGuard-1" } do
		drop(world.BridgeGuards:FindFirstChild(name), name)
	end
	local bounds = 0
	for _, b in world.WorldBounds:GetChildren() do
		if b.Name:match("^HubRing") or b.Name:match("^PlazaRing1_") or b.Name:match("^PlazaRing5_") or b.Name == "BridgeN" or b.Name == "BridgeS" then
			b:Destroy()
			bounds += 1
		end
	end
	table.insert(removed, "west bounds(" .. bounds .. ")")
	local plaza = world.FutureZones.BillionairePlaza
	drop(plaza:FindFirstChild("EntranceArch"), "Plaza.EntranceArch")
	drop(plaza:FindFirstChild("BridgeDeck"), "Plaza.BridgeDeck")
	local city = world:FindFirstChild("BillionaireCity")
	if city then
		for _, c in city:GetChildren() do
			if c.Name ~= "Zone6Plaza" then
				drop(c, "City." .. c.Name)
			end
		end
	end
	for _, name in { "FloorRim", "StreetPath", "SafeZone" } do
		drop(workspace.Hub:FindFirstChild(name), "Hub." .. name)
	end
	-- Venues: one anchor of each name (025 left four copies of some)
	local dupes = 0
	for _, f in workspace.Venues:GetDescendants() do
		if f:IsA("Folder") then
			local seen = {}
			for _, c in f:GetChildren() do
				if c:IsA("BasePart") then
					if seen[c.Name] then
						c:Destroy()
						dupes += 1
					else
						seen[c.Name] = true
					end
				end
			end
		end
	end
	drop(workspace.Venues:FindFirstChild("Leaderboards"), "Venues.Leaderboards(025 tickers)")
	table.insert(removed, "venue duplicates(" .. dupes .. ")")
	return "removed: " .. table.concat(removed, ", ")
end
