-- tools/build036/B1_Bridge.lua (036 Knight's Keep polish, step 1): ONE castle bridge from the Hideout Camp lane mouth to the Keep's front gate.
-- Run in Edit (command bar / MCP loadstring). Re-runnable: removes its own Bridge036 and puts back what it parked first.
-- UNDO = true only restores the old ramp, steps and mesh bridge.
-- Replaces (parks in ServerStorage._Parked036.Bridge): the Keep's cream `SkyCity.Lane.Ramp` (the one at z -116..-164), the Access037 steps,
-- side walls and invisible gap/seam plates, and the imported `KeepRuined...Bridge.Bridge2` meshes.
-- Same straight path on x = -157, same length (z -115.5 .. -201), deck top y 0.3 at the lane mouth -> 13.46 at z -164 (the old bridge pad
-- height, so Lane.Start_MainStreet at y 15.3 still lands on it) -> flat 13.46 to the courtyard paving. 16 studs walkable between the rails
-- (= the Boss Heist robot area). Nothing the game reads is moved: SafeLine(Wide), Start_MainStreet, SafeLaneVolume, gates, zone boxes.
local UNDO = false

local ServerStorage = game:GetService("ServerStorage")
local world = workspace:WaitForChild("World")
local kk = world.KnightsKeep
local lane = world.SkyCity.Lane

local parkRoot = ServerStorage:FindFirstChild("_Parked036") or Instance.new("Folder")
parkRoot.Name = "_Parked036"
parkRoot.Parent = ServerStorage
local parked = parkRoot:FindFirstChild("Bridge") or Instance.new("Folder")
parked.Name = "Bridge"
parked.Parent = parkRoot

local function resolve(path: string): Instance?
	local node: Instance? = game
	for _, name in string.split(path, ".") do
		node = node and (node:FindFirstChild(name) or (node == game and game:GetService(name) or nil))
	end
	return node
end
local function park(inst: Instance)
	inst:SetAttribute("Parked036From", (inst.Parent :: Instance):GetFullName())
	inst.Parent = parked
end
local function unparkAll()
	for _, inst in parked:GetChildren() do
		local home = resolve(inst:GetAttribute("Parked036From"))
		if home then
			inst:SetAttribute("Parked036From", nil)
			inst.Parent = home
		end
	end
end

local old = kk:FindFirstChild("Bridge036")
if old then
	old:Destroy()
end
unparkAll()
if UNDO then
	return "B1 undone: old ramp, steps and mesh bridge back"
end

-- Park the old pieces.
local keepRamp
for _, m in lane:GetChildren() do
	local w = m.Name == "Ramp" and m:FindFirstChild("Wedge")
	if w and math.abs(w.Position.Z + 140) < 2 and math.abs(w.Position.X + 157) < 2 then
		keepRamp = m
	end
end
assert(keepRamp, "the Keep's Lane.Ramp (wedge at -157, z -140) is missing")
local rampRotation = (keepRamp.Wedge :: BasePart).CFrame.Rotation -- low end towards +Z (the camp)
park(keepRamp)
for _, name in { "RampWedge", "RampStep1", "RampStep2", "RampStep3", "RampStep4", "RampWallL", "RampWallR", "BridgeSeamPlate", "BridgeGapPlate" } do
	local p = kk.Access037:FindFirstChild(name)
	if p then
		park(p)
	end
end
park(kk.KeepRuined.KnightKeep_Ruined.Bridge.Bridge2)

-- Build.
local folder = Instance.new("Folder")
folder.Name = "Bridge036"
local STONE = Color3.fromRGB(150, 144, 134)
local DECK = Color3.fromRGB(158, 150, 136)
local CAP = Color3.fromRGB(196, 188, 172)
local DARK = Color3.fromRGB(104, 98, 90)
local LAMP = Color3.fromRGB(255, 206, 120)
local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false
	for k, v in props do
		if k ~= "Class" then
			(p :: any)[k] = v
		end
	end
	p.Parent = folder
	return p
end

local X = -157
local Z0, Z1, Z2 = -115.5, -164, -201 -- lane mouth, top of the ramp, onto the courtyard paving
local Y0, Y1 = 0.3, 13.46
local HALF = 9 -- deck half-width; rails 1 stud thick on the edges -> 16 walkable
local rise, run = Y1 - Y0, Z0 - Z1

-- deck: the ramp (same rotation as the old wedge, so the slope runs the same way) and the flat span to the gate
part({ Name = "RampDeck", Class = "WedgePart", Size = Vector3.new(HALF * 2, rise, run), CFrame = CFrame.new(X, Y0 + rise / 2, (Z0 + Z1) / 2) * rampRotation, Material = Enum.Material.Cobblestone, Color = DECK, CastShadow = true })
part({ Name = "SpanDeck", Size = Vector3.new(HALF * 2, 2, Z1 - Z2), CFrame = CFrame.new(X, Y1 - 1, (Z1 + Z2) / 2), Material = Enum.Material.Cobblestone, Color = DECK, CastShadow = true })

-- stone rails: sloped along the ramp, straight along the span; lighter caps on top
local RAIL_H = 2.6
local slopeLen = math.sqrt(rise * rise + run * run)
for _, side in { -1, 1 } do
	local rx = X + side * (HALF - 0.5)
	local a, b = Vector3.new(rx, Y0, Z0), Vector3.new(rx, Y1, Z1)
	local along = CFrame.lookAt((a + b) / 2, b)
	part({ Name = "RampRail", Size = Vector3.new(1, RAIL_H, slopeLen), CFrame = along * CFrame.new(0, RAIL_H / 2 - 0.2, 0), Material = Enum.Material.Brick, Color = STONE })
	part({ Name = "RampRailCap", Size = Vector3.new(1.4, 0.4, slopeLen), CFrame = along * CFrame.new(0, RAIL_H - 0.2 + 0.2, 0), Material = Enum.Material.Slate, Color = CAP, CanQuery = false })
	part({ Name = "SpanRail", Size = Vector3.new(1, RAIL_H, Z1 - Z2), CFrame = CFrame.new(rx, Y1 + RAIL_H / 2 - 0.2, (Z1 + Z2) / 2), Material = Enum.Material.Brick, Color = STONE })
	part({ Name = "SpanRailCap", Size = Vector3.new(1.4, 0.4, Z1 - Z2), CFrame = CFrame.new(rx, Y1 + RAIL_H, (Z1 + Z2) / 2), Material = Enum.Material.Slate, Color = CAP, CanQuery = false })
	-- pillars with a lantern at the start, the top of the ramp and the gate end
	for _, at in { { Z0 - 1, Y0 }, { Z1, Y1 }, { Z2 + 1, Y1 } } do
		local z, y = at[1], at[2]
		part({ Name = "Pillar", Size = Vector3.new(2, 4.6, 2), CFrame = CFrame.new(rx, y + 2.1, z), Material = Enum.Material.Brick, Color = DARK })
		part({ Name = "Lantern", Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(rx, y + 4.95, z), Material = Enum.Material.Neon, Color = LAMP, CanCollide = false, CanQuery = false })
	end
end

-- under the deck: a footing below the top of the ramp and two piers into the chasm, each on a wider foot
part({ Name = "RampFooting", Size = Vector3.new(HALF * 2 - 2, 24, 4), CFrame = CFrame.new(X, Y0 - 12, Z1 + 2.5), Material = Enum.Material.Brick, Color = STONE, CanQuery = false })
for _, z in { -175, -189 } do
	part({ Name = "Pier", Size = Vector3.new(HALF * 2 - 4, 26, 4), CFrame = CFrame.new(X, Y1 - 2 - 13, z), Material = Enum.Material.Brick, Color = STONE, CanQuery = false })
	part({ Name = "PierFoot", Size = Vector3.new(HALF * 2, 6, 6), CFrame = CFrame.new(X, Y1 - 2 - 26 - 1, z), Material = Enum.Material.Slate, Color = DARK, CanQuery = false })
end

folder.Parent = kk
local n = 0
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("B1 bridge built: %d parts; parked %d objects in ServerStorage._Parked036.Bridge"):format(n, #parked:GetChildren())
