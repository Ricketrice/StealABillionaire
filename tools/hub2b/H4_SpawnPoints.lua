-- H4_SpawnPoints.lua (Hub 2b, part 4): batches of 8 need 8 spawn points (frozen wanderers never walk off theirs).
-- Knight's Keep and Ember Academy had 6: adds checked points (open ground inside the ZoneBoundary, nothing solid
-- within 4 studs from knee to head height, >= 9 studs from other points and the GuardianPost) until 8.
-- Re-runnable (counts what is there). New points carry attr Created2b (Undo.lua parks them).
local H = workspace.HubMap2b:GetAttribute("HubOrigin")
local out = {}
for _, zone in { "MainStreet", "SunkenKingdom", "BillionaireHills" } do
	local zf = workspace.Zones[zone]
	local b = zf.ZoneBoundary :: BasePart
	local points = zf.SpawnPoints
	local taken, floorY, reuse = {}, {}, {}
	for _, p in points:GetChildren() do
		if p:GetAttribute("Created2b") then
			table.insert(reuse, p) -- ours from an earlier run: placed again below
			p.Parent = nil
		else
			table.insert(taken, p.Position)
			table.insert(floorY, p.Position.Y - p.Size.Y / 2)
		end
	end
	table.sort(floorY)
	local floor = floorY[math.ceil(#floorY / 2)]
	local post = zf:FindFirstChild("GuardianPost")
	if post then
		table.insert(taken, post.Position)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Zones }
	local template: BasePart
	for _, p in points:GetChildren() do
		if not p:GetAttribute("Created2b") then
			template = p :: BasePart
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { workspace.Zones }
	local half = b.Size / 2
	-- visible props nearby (decor is often CanQuery = false, which spatial queries skip)
	local props = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 and math.max(d.Size.X, d.Size.Y, d.Size.Z) < 30 and not d:IsDescendantOf(workspace.Zones) then
			local l = b.CFrame:PointToObjectSpace(d.Position)
			if math.abs(l.X) < half.X + 10 and math.abs(l.Z) < half.Z + 10 then
				table.insert(props, d)
			end
		end
	end
	local cands = {}
	local probe = Instance.new("Part")
	probe.Anchored, probe.CanCollide, probe.CanQuery, probe.CanTouch, probe.Transparency = true, false, false, false, 1
	probe.Size = Vector3.new(8, 5, 8)
	probe.Parent = workspace
	overlap.FilterDescendantsInstances = { workspace.Zones, probe }
	for lx = -half.X + 5, half.X - 5, 3 do
		for lz = -half.Z + 5, half.Z - 5, 3 do
			local w = b.CFrame:PointToWorldSpace(Vector3.new(lx, 0, lz))
			local hit = workspace:Raycast(Vector3.new(w.X, b.Position.Y + 20, w.Z), Vector3.new(0, -60, 0), params)
			if hit and hit.Normal.Y > 0.9 and math.abs(hit.Position.Y - floor) < 1.5 then
				local g = hit.Position
				local blocked = false
				probe.CFrame = CFrame.new(g + Vector3.new(0, 3.5, 0))
				-- exact geometry (a merged mesh's bounding box can cover the whole courtyard): solid parts and small props block
				for _, p in workspace:GetPartsInPart(probe, overlap) do
					if p.CanCollide or (p.Transparency < 0.9 and math.max(p.Size.X, p.Size.Y, p.Size.Z) < 30) then
						blocked = true
						break
					end
				end
				for _, d in props do
					if blocked then
						break
					end
					local top, bottom = d.Position.Y + d.Size.Y / 2, d.Position.Y - d.Size.Y / 2
					local reach = math.max(d.Size.X, d.Size.Z) / 2 + 4
					if bottom < g.Y + 6 and top > g.Y + 0.5 and (Vector3.new(d.Position.X - g.X, 0, d.Position.Z - g.Z)).Magnitude < reach then
						blocked = true
					end
				end
				if not blocked then
					local d = math.huge
					for _, t in taken do
						d = math.min(d, (Vector3.new(t.X, 0, t.Z) - Vector3.new(g.X, 0, g.Z)).Magnitude)
					end
					table.insert(cands, { g = g, d = d })
				end
			end
		end
	end
	probe:Destroy() -- (the script's own temporary probe)
	local added = {}
	while #points:GetChildren() < 8 do
		local best, bestD = nil, 9
		for _, c in cands do
			local d = math.huge
			for _, t in taken do
				d = math.min(d, (Vector3.new(t.X, 0, t.Z) - Vector3.new(c.g.X, 0, c.g.Z)).Magnitude)
			end
			if d > bestD then
				best, bestD = c, d
			end
		end
		if not best then
			break
		end
		local p = table.remove(reuse) or template:Clone()
		p.Name = "Spawn2b_" .. (#points:GetChildren() + 1)
		p.CFrame = CFrame.new(best.g + Vector3.new(0, template.Position.Y - (template.Position.Y - template.Size.Y / 2) , 0))
		p:SetAttribute("Created2b", true)
		p.Parent = points
		table.insert(taken, p.Position)
		table.insert(added, ("(%.0f, %.1f, %.0f) gap %.0f"):format(p.Position.X - H.X, p.Position.Y, p.Position.Z - H.Z, bestD))
	end
	table.insert(out, ("%s: %d points, %d candidates, added %s"):format(zone, #points:GetChildren(), #cands, table.concat(added, "; ")))
end
return table.concat(out, "\n")
