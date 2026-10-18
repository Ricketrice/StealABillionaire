-- H3_GuardianPosts.lua (Hub 2b, part 3): one invisible GuardianPost part per zone (Workspace.Zones.<zone>), where
-- that zone's guardian stands and returns to: inside the ZoneBoundary, 30% of the way to its far end (away from the
-- hub), on the ground, facing the zone's entrance. Re-runnable (moves existing posts). Undo.lua parks them.
local H = workspace.HubMap2b:GetAttribute("HubOrigin")
local out = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { workspace.Zones }
for _, zone in { "MainStreet", "SunkenKingdom", "BillionaireHills" } do
	local zf = workspace.Zones[zone]
	local b = zf.ZoneBoundary :: BasePart
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = b.CFrame:PointToWorldSpace(b.Size / 2 * Vector3.new(sx, 0, sz))
			lo, hi = lo:Min(w), hi:Max(w)
		end
	end
	local c = b.Position
	local towardHub = if H.X > c.X then 1 else -1
	local x = c.X - towardHub * 0.3 * (hi.X - lo.X) / 2
	local hit = workspace:Raycast(Vector3.new(x, c.Y + 30, c.Z), Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y else c.Y
	local p = zf:FindFirstChild("GuardianPost") or Instance.new("Part")
	p.Name = "GuardianPost"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(4, 1, 4)
	p.CFrame = CFrame.lookAt(Vector3.new(x, y + 0.5, c.Z), Vector3.new(x + towardHub * 10, y + 0.5, c.Z))
	p:SetAttribute("Created2b", true)
	p.Parent = zf
	table.insert(out, ("%s post at hub (%.1f, %.1f, %.1f) on %s"):format(zone, x - H.X, y, c.Z - H.Z, hit and hit.Instance.Name or "NOTHING"))
end
return table.concat(out, "\n")
