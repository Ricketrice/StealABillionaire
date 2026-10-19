-- Z2_IslandRail.lua (after Z1): Ember's Balustrade is the island's edge rail (3 studs high) and Ember036EndRail closes
-- the island's east end; Z1 parked both with Ember. This puts back the rail pieces outside the new map (east of its
-- east wall, x >= 453.5) and Ember036EndRail, and cuts the 4 long rails that cross into the map so they start at the
-- wall. Pieces inside the map stay parked in ServerStorage._ParkedEmber.Balustrade.
-- Run in Studio Edit; re-runnable. UNDO = true moves them back to _ParkedEmber (run it before Z1_Undo.lua).
local UNDO = UNDO or false
local SS = game:GetService("ServerStorage")
local E = workspace.World.EmberAcademy
local pe = SS._ParkedEmber
local EDGE = 453.5

local function ext(p: BasePart): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			for _, c in { -1, 1 } do
				local w = p.CFrame:PointToWorldSpace(Vector3.new(a * p.Size.X / 2, b * p.Size.Y / 2, c * p.Size.Z / 2))
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	return lo, hi
end

if UNDO then
	local live = E:FindFirstChild("Balustrade")
	for _, p in (if live then live:GetChildren() else {}) do
		local cf, size = p:GetAttribute("PreZ2CFrame"), p:GetAttribute("PreZ2Size")
		if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			p.Size, p.CFrame = size, cf
			p:SetAttribute("PreZ2CFrame", nil)
			p:SetAttribute("PreZ2Size", nil)
		end
		p.Parent = pe.Balustrade
	end
	if live then
		live:Destroy()
	end
	local rail = E:FindFirstChild("Ember036EndRail")
	if rail then
		rail:SetAttribute("ParkedFrom", "World.EmberAcademy")
		rail.Parent = pe
	end
	return "Z2 undone"
end

local live = E:FindFirstChild("Balustrade") or Instance.new("Folder")
live.Name = "Balustrade"
local back, cutN = 0, 0
for _, p in pe.Balustrade:GetChildren() do
	if not p:IsA("BasePart") then
		continue
	end
	local lo, hi = ext(p)
	local outside = lo.X >= EDGE or hi.Z <= 464 or lo.Z >= 617
	if outside then
		p.Parent = live
		back += 1
	elseif lo.X < EDGE and hi.X > EDGE then -- long rail running along world X: keep the part east of the wall
		local axis = if p.Size.X >= p.Size.Z then Vector3.xAxis else Vector3.zAxis
		if math.abs(p.CFrame:VectorToWorldSpace(axis).X) < 0.95 then
			continue
		end
		p:SetAttribute("PreZ2CFrame", p.CFrame)
		p:SetAttribute("PreZ2Size", p.Size)
		local newLen = hi.X - EDGE
		p.Size = if axis == Vector3.xAxis then Vector3.new(newLen, p.Size.Y, p.Size.Z) else Vector3.new(p.Size.X, p.Size.Y, newLen)
		p.CFrame = p.CFrame.Rotation + Vector3.new(EDGE + newLen / 2, p.Position.Y, p.Position.Z)
		p.Parent = live
		cutN += 1
	end
end
live.Parent = E
local rail = pe:FindFirstChild("Ember036EndRail")
if rail and rail:IsA("Model") then
	rail:SetAttribute("ParkedFrom", nil)
	rail.Parent = E
end
return ("Z2 ok: %d rail pieces back, %d cut at x %.1f, end rail %s; %d stay parked"):format(back, cutN, EDGE, rail and "back" or "missing", #pe.Balustrade:GetChildren())
