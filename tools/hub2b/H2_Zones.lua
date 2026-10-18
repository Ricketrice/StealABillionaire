-- H2_Zones.lua (Hub 2b, part 2): move our zones onto the hub's grey platforms. Run in Studio Edit after H1.
-- DRY = true only lists what would move (and what is left over); DRY = false moves. Undo: tools/hub2b/Undo.lua.
--
-- Two rigid moves (no scaling):
--   Knight's Keep  -> west platform: quarter turn (the Keep's north becomes west); the bridge foot (-157, 0, -115.5)
--                     lands on the end of the junction's west branch, hub-local (-50, 0, -160).
--   Sunken Kingdom -> east platform, Ember Academy chained after it (one move for both, so the Sunken -> Ember
--                     ramp still connects): quarter turn the other way; the Sunken ramp foot (-157, 12.3, -343.5)
--                     lands on the end of the east branch, hub-local (50, 0, -160).
-- Moved with them: their zone folders (ZoneBoundary, SpawnPoints), lane gates (+ attrs Inward/HalfWidth for
-- ZoneProgress), lane pieces, the safe line (+ attr HomeSide for the Boss Heist), terrace/rocks/trees/clouds by
-- position, the ServerStorage templates that hold world positions (HeistVault032, SpellRunCourse034), photo spots.
-- Vector attributes that are directions (Axis, Inward, HomeSide) are turned with the zone.
local DRY = if DRY == nil then true else DRY -- set by the runner's prelude: "local DRY = false"

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local map = workspace:FindFirstChild("HubMap2b")
assert(map and map:GetAttribute("Fit2b"), "run H1 first")
local H: Vector3 = map:GetAttribute("HubOrigin")
local World = workspace.World
local City = World.SkyCity
local FZ = World.FutureZones

local T_K = CFrame.new(H + Vector3.new(-50, 0, -160)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(157, 0, 115.5)
local T_SE = CFrame.new(H + Vector3.new(50, 0, -160)) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(157, -12.3, 343.5)

local log = {}
local function say(s)
	table.insert(log, s)
end
local function centre(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetBoundingBox().Position
	end
	local lo, hi, n = Vector3.one * 1e9, -Vector3.one * 1e9, 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			lo, hi, n = lo:Min(d.Position), hi:Max(d.Position), n + 1
		end
	end
	return if n > 0 then (lo + hi) / 2 else nil
end

-- 1. who goes where ---------------------------------------------------------------------------------------------
local keep: { Instance } = {
	World.KnightsKeep, workspace.Zones.MainStreet, City.MainStreet,
	City.Ground.Island4, City.Ground.MainStreetCurb, City.Ground.MainStreet,
	SS.HeistVault032,
}
local se: { Instance } = {
	World.SunkenKingdom, World.EmberAcademy, FZ.Our_SunkenKingdom, FZ.Zone6_BillionaireHills, World.Bridges,
	World.BridgeGuards, workspace.Zones.SunkenKingdom, workspace.Zones.BillionaireHills,
	City.Lane.T2_SunkenKingdom, City.Lane.T3_EmberAcademy, SS.SpellRunCourse034,
}
for _, c in City.Lane:GetChildren() do
	local n = c.Name
	if n == "Start_MainStreet" or n == "SafeLine" or n == "SafeLineWide" or n == "Sign" or n == "BannerPost" or n == "SafeLaneVolume" then
		table.insert(keep, c)
	elseif n == "Ramp" then
		table.insert(se, c)
	end
end
-- spread-out folders: each child by where it is (plaza east of x 107 and the old hub stay)
for _, f in { City.Ground.Edge, City.Ground.Rocks, City.Dressing.Trees, City.Lane.Rocks, City.Lane.Clouds, World.Islands } do
	for _, c in f:GetChildren() do
		local p = centre(c)
		if p and p.Z <= -112 and p.Z > -350 then
			table.insert(keep, c)
		elseif p and p.Z <= -350 then
			table.insert(se, c)
		end
	end
end
local photo = SS:FindFirstChild("PhotoSpotsDev")
if photo then
	for _, c in photo:GetChildren() do
		local p = centre(c)
		if p and p.Z < -112 and p.Z > -350 then
			table.insert(keep, c)
		elseif p and p.Z <= -350 then
			table.insert(se, c)
		end
	end
end

-- what is left north of the lane mouth and not moving?
local moving = {}
for _, list in { keep, se } do
	for _, i in list do
		moving[i] = true
	end
end
local function isMoving(d: Instance): boolean
	local x = d
	while x do
		if moving[x] then
			return true
		end
		x = x.Parent
	end
	return false
end
local left = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Position.Z < -112 and not d:IsDescendantOf(map) and not isMoving(d) then
		local key = d.Parent:GetFullName()
		left[key] = (left[key] or 0) + 1
	end
end
local nLeft = 0
for k, v in left do
	say(("NOT MOVED: %s (%d parts)"):format(k, v))
	nLeft += 1
end
-- position-like values/attributes inside the moving sets (to be turned/moved too)
local DIRS = { Axis = true, Inward = true, HomeSide = true }
local POINTS = { Hinge = true, WheelCentre = true } -- HeistVault032 door: world points read by HeistClient
local vals, attrs = {}, {}
for _, list in { keep, se } do
	for _, i in list do
		for _, d in i:GetDescendants() do
			if d:IsA("CFrameValue") or d:IsA("Vector3Value") then
				table.insert(vals, d)
			end
		end
		for _, d in { i, table.unpack(i:GetDescendants()) } do
			for k, v in d:GetAttributes() do
				if typeof(v) == "CFrame" or typeof(v) == "Vector3" then
					table.insert(attrs, { d, k, v })
				end
			end
		end
	end
end
local kinds = {}
for _, a in attrs do
	kinds[a[2]] = (kinds[a[2]] or 0) + 1
end
local kl = {}
for k, v in kinds do
	table.insert(kl, k .. "=" .. v .. (if DIRS[k] then "(dir)" else ""))
end
say(("keep %d items, sunken+ember %d items; values %d; vector attrs: %s"):format(#keep, #se, #vals, table.concat(kl, ", ")))
for _, v in vals do
	say("  value " .. v:GetFullName() .. " " .. v.ClassName)
end
if DRY then
	return table.concat(log, "\n")
end

-- 2. move -----------------------------------------------------------------------------------------------------------
local function record(inst: Instance, cf: CFrame)
	if inst:GetAttribute("Pre2bCFrame") == nil then
		inst:SetAttribute("Pre2bCFrame", cf)
		CS:AddTag(inst, "Moved2b")
	end
end
local function moveItem(inst: Instance, T: CFrame)
	if inst:IsA("BasePart") then
		record(inst, inst.CFrame)
		inst.CFrame = T * inst.CFrame
	elseif inst:IsA("Model") then
		record(inst, inst:GetPivot())
		inst:PivotTo(T * inst:GetPivot())
	else
		for _, c in inst:GetChildren() do
			moveItem(c, T)
		end
	end
end
local function turnExtras(inst: Instance, T: CFrame)
	local R = T.Rotation
	for _, d in { inst, table.unpack(inst:GetDescendants()) } do
		for k, v in d:GetAttributes() do
			if DIRS[k] and typeof(v) == "Vector3" then
				d:SetAttribute("Pre2b" .. k, v)
				d:SetAttribute(k, R * v)
			elseif POINTS[k] and typeof(v) == "Vector3" then
				d:SetAttribute("Pre2b" .. k, v)
				d:SetAttribute(k, T * v)
			end
		end
		if d:IsA("CFrameValue") then
			d:SetAttribute("Pre2bValue", d.Value)
			d.Value = T * d.Value
		elseif d:IsA("Vector3Value") then
			d:SetAttribute("Pre2bValue", d.Value)
			d.Value = T * d.Value
		end
	end
end
for _, i in keep do
	turnExtras(i, T_K)
	moveItem(i, T_K)
end
task.wait()
for _, i in se do
	turnExtras(i, T_SE)
	moveItem(i, T_SE)
end
task.wait()

-- 3. gates, safe line, safe volume, Keep's back terrace ------------------------------------------------------------
local function setNew(inst: Instance, k: string, v: any)
	if inst:GetAttribute("Pre2bHad" .. k) == nil then
		inst:SetAttribute("Pre2bHad" .. k, inst:GetAttribute(k) ~= nil)
	end
	inst:SetAttribute(k, v)
end
local sunkenBarrier = FZ.Our_SunkenKingdom.Gate.Barrier
setNew(sunkenBarrier, "Inward", T_SE.Rotation * Vector3.new(0, 0, -1))
setNew(sunkenBarrier, "HalfWidth", 64) -- the Sunken map is 134 wide; the red band starts 65 studs from its axis
local emberBarrier = FZ.Zone6_BillionaireHills.Gate.Barrier
setNew(emberBarrier, "Inward", T_SE.Rotation * Vector3.new(0, 0, -1))
local line = City.Lane.SafeLineWide
setNew(line, "HomeSide", T_K.Rotation * Vector3.new(0, 0, 1))
-- the lane mouth's PvP safe volume: now the junction square (both branches + the parade lane's end)
local vol = City.Lane.SafeLaneVolume :: BasePart
if vol:GetAttribute("Pre2bSize") == nil then
	vol:SetAttribute("Pre2bSize", vol.Size)
end
vol.CFrame = CFrame.new(H + Vector3.new(0, 10, -160))
vol.Size = Vector3.new(100, 24, 30)
-- the Keep's back terrace led to the Sunken ramp: close that edge
local island4 = City.Ground.Island4 :: BasePart
local acc = World.KnightsKeep:FindFirstChild("Access2b") or Instance.new("Folder")
acc.Name = "Access2b"
acc:SetAttribute("Created2b", true)
acc.Parent = World.KnightsKeep
local g = Instance.new("Part")
g.Name = "TerraceEndGuard"
g.Anchored = true
g.Transparency = 1
g.CanTouch = false
g.CastShadow = false
-- the terrace's far edge = Island4's old north face (smallest z before the move), 6 tall from its top
local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
for _, part in { island4, City.Ground.MainStreet :: BasePart } do
	local oldCF: CFrame = part:GetAttribute("Pre2bCFrame")
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = oldCF:PointToWorldSpace(part.Size / 2 * Vector3.new(sx, sy, sz))
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
end
g.Size = Vector3.new(hi.X - lo.X + 2, 6, 1)
g.CFrame = T_K * CFrame.new((lo.X + hi.X) / 2, hi.Y + 3, lo.Z - 0.5)
g.Parent = acc
say(("guard at %s size %s"):format(tostring(g.Position - H), tostring(g.Size)))

map:SetAttribute("Zones2b", true)
say("moved; sunken barrier at " .. tostring(sunkenBarrier.Position - H) .. ", ember barrier at " .. tostring(emberBarrier.Position - H) .. ", safe line at " .. tostring(line.Position - H))
return table.concat(log, "\n")
