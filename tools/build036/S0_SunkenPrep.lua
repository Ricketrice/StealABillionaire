-- S0_SunkenPrep.lua (D49, before S1): prepares the owner's Import 3D of sunken_kingdom_clean.glb.
-- Run in Studio Edit. Finds SunkenKingdomMap in Workspace or ServerStorage, clones it as imported into
-- ServerStorage._Backups.Pre049_SunkenMap (+ Zones.SunkenKingdom ZoneBoundary/SpawnPoints and the Underwater
-- AmbienceVolume), anchors every part, restores GLB material colours (linear -> sRGB, by name suffix) and moves the
-- map to ServerStorage.SunkenKingdomMap. Undo: delete the map and use the _AsImported clone.
local SS = game:GetService("ServerStorage")
local map = workspace:FindFirstChild("SunkenKingdomMap") or SS:FindFirstChild("SunkenKingdomMap")
assert(map, "SunkenKingdomMap missing")

local bk = SS:FindFirstChild("_Backups") or Instance.new("Folder")
bk.Name = "_Backups"
bk.Parent = SS
local pre = bk:FindFirstChild("Pre049_SunkenMap")
if not pre then
	pre = Instance.new("Folder")
	pre.Name = "Pre049_SunkenMap"
	local c = map:Clone()
	c.Name = "SunkenKingdomMap_AsImported"
	c.Parent = pre
	local z = workspace.Zones.SunkenKingdom
	z.ZoneBoundary:Clone().Parent = pre
	z.SpawnPoints:Clone().Parent = pre
	workspace.World.SunkenKingdom.Ambience.AmbienceVolume:Clone().Parent = pre
	pre.Parent = bk
end

-- { r, g, b, material } from the GLB's baseColorFactor
local MAT = {
	Coral_Orange = { 240, 145, 78, "Plastic" },
	Shell_Pearl = { 241, 226, 207, "SmoothPlastic" },
	Coral_Purple = { 142, 111, 208, "Plastic" },
	Coral_Pink = { 233, 121, 143, "Plastic" },
	Glow_Sea = { 143, 247, 234, "Neon" },
	Gold_Trim = { 224, 177, 72, "Metal" },
	Stone_Sunken = { 111, 149, 144, "Plastic" },
	Kelp = { 61, 138, 79, "Plastic" },
	Path_Mosaic = { 226, 214, 182, "SmoothPlastic" },
	Reef_Rock = { 75, 95, 98, "Plastic" },
	Stone_Deep = { 47, 79, 92, "Plastic" },
	Glass_Dome = { 174, 238, 242, "Glass" },
	Driftwood = { 122, 102, 80, "Wood" },
	FX_LightShaft = { 216, 255, 248, "Neon" },
	Cloth_Teal = { 43, 141, 153, "Fabric" },
	Verdigris = { 79, 174, 156, "SmoothPlastic" },
	Sand_Seabed = { 205, 187, 140, "Sand" },
	Dragon_Scale = { 29, 107, 120, "SmoothPlastic" },
}
local done, unknown = 0, {}
for _, model in map:GetChildren() do
	local base = model.Name:gsub("_%-?%d+_%-?%d+$", "") -- Props_<mat>_<cellx>_<cellz>
	local key
	for k in MAT do
		if base:sub(-#k - 1) == "_" .. k and (not key or #k > #key) then
			key = k
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			p.Anchored = true
			p.Name = model.Name
			if key then
				local m = MAT[key]
				p.Color = Color3.fromRGB(m[1], m[2], m[3])
				p.Material = Enum.Material[m[4]]
				if key == "Glass_Dome" then
					p.Transparency = 0.6
				elseif key == "FX_LightShaft" then
					p.Transparency = 0.9
				end
				done += 1
			else
				table.insert(unknown, model.Name)
			end
		end
	end
end
map.Parent = SS
return ("S0 ok: coloured %d, unknown %d %s"):format(done, #unknown, table.concat(unknown, ","))
