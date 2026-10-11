-- Studio location: ServerStorage.Build027.B2_Lots (ModuleScript)
-- Moves the 12 plot models (whole models: pads, gate, fence and PvP bounds keep their relative
-- positions) into two rows facing the parade lane, PlotId 1/2 nearest the spawn, alternating sides,
-- and gives each a raised coloured base with the gold trim. Plot models are recoloured in place
-- (old colours kept in Pre027Color attributes).

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

local function tint(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), t)
end

return function(): string
	local root = K.folder(K.root(), "LotBases", true)
	local plots = {}
	for _, p in workspace.Hub.Plots:GetChildren() do
		if p:IsA("Model") and p:GetAttribute("PlotId") then
			plots[p:GetAttribute("PlotId")] = p
		end
	end
	local moved = 0
	for id = 1, 12 do
		local plot = plots[id]
		assert(plot and plot.PrimaryPart, "missing Plot" .. id)
		local column = math.ceil(id / 2)
		local north = id % 2 == 1
		local x = L.lotXs[column]
		local z = if north then L.rowNorthZ else L.rowSouthZ
		local floor = plot.PrimaryPart
		local target = CFrame.new(x, L.lotFloorTop - floor.Size.Y / 2, z) * (if north then CFrame.new() else CFrame.Angles(0, math.pi, 0))
		if plot:GetAttribute("Pre027Pivot") == nil then
			plot:SetAttribute("Pre027Pivot", plot:GetPivot())
		end
		local delta = target * floor.CFrame:Inverse()
		plot:PivotTo(delta * plot:GetPivot())
		moved += 1

		local colour = K.LOT_COLOURS[id]
		local function paint(part: BasePart?, c: Color3, mat: Enum.Material?)
			if part then
				if part:GetAttribute("Pre027Color") == nil then
					part:SetAttribute("Pre027Color", part.Color)
					part:SetAttribute("Pre027Material", part.Material.Name)
				end
				part.Color = c
				part.Material = mat or Enum.Material.SmoothPlastic
			end
		end
		paint(floor, tint(colour, 0.72))
		for _, f in plot.Fence:GetChildren() do
			paint(f :: BasePart, colour)
		end
		for _, g in plot.Gate:GetChildren() do
			paint(g :: BasePart, if g.Name == "Sign" then C.Curb else colour)
		end
		plot:SetAttribute("LotColor", colour)

		-- raised base: gold trim band, then the lot colour band, then the plot floor on top
		local base = Instance.new("Model")
		base.Name = "Lot" .. id
		K.part({ name = "Trim", parent = base, size = Vector3.new(L.lotTrim, 0.8, L.lotTrim), pos = Vector3.new(x, L.lotTrimTop - 0.4, z), color = C.Trim })
		K.part({
			name = "Base",
			parent = base,
			size = Vector3.new(L.lotBase, 0.8, L.lotBase),
			pos = Vector3.new(x, L.lotBaseTop - 0.4, z),
			color = colour:Lerp(Color3.new(0, 0, 0), 0.08),
		})
		-- a ramp-free step: the base is only 0.5 above the walkway, so players simply walk on
		base.Parent = root
	end
	return ("lots: %d moved, base parts %d"):format(moved, K.count(root))
end
