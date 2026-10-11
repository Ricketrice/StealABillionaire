-- Studio location: ServerStorage.Build027.B7_Reserved (ModuleScript)
-- Reserved plots for future features (D9): two in the hub (behind the stalls, on the paths from the
-- spawn square) and one at the far end of Main Street for the future boss vault. Each is finished and
-- empty: gold-trimmed raised base, cream floor with a gold medallion, low navy fence, a gate facing its
-- path and a "COMING SOON" sign. Not plots in the PlotService sense (no PlotId), so nobody is assigned one.

local K = require(script.Parent.Kit)
local C, L = K.C, K.L

local function reserved(parent: Instance, name: string, centre: Vector3, facing: Vector3, title: string)
	local m = Instance.new("Model")
	m.Name = name
	local cf = CFrame.lookAt(Vector3.new(centre.X, 0, centre.Z), Vector3.new(centre.X, 0, centre.Z) + facing) -- front = -Z = facing
	K.part({ name = "Trim", parent = m, size = Vector3.new(L.lotTrim, 0.8, L.lotTrim), cf = cf * CFrame.new(0, L.lotTrimTop - 0.4, 0), color = C.Trim })
	K.part({ name = "Base", parent = m, size = Vector3.new(L.lotBase, 0.8, L.lotBase), cf = cf * CFrame.new(0, L.lotBaseTop - 0.4, 0), color = C.Navy })
	K.part({ name = "Floor", parent = m, size = Vector3.new(36, 0.2, 36), cf = cf * CFrame.new(0, L.lotFloorTop - 0.1, 0), color = C.PavingWarm })
	for k, r in { 7, 6 } do
		K.part({
			name = "Medallion",
			parent = m,
			shape = "Cylinder",
			size = Vector3.new(0.1, r * 2, r * 2),
			cf = cf * CFrame.new(0, L.lotFloorTop + 0.02 * k, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = if k == 1 then C.Trim else C.PavingWarm,
			deco = true,
		})
	end
	local fy = L.lotFloorTop + 1.15
	local function fence(n, size, at)
		K.part({ name = n, parent = m, size = size, cf = cf * CFrame.new(at.X, fy, at.Z), color = C.Navy })
	end
	fence("FenceBack", Vector3.new(36, 2.5, 0.6), Vector3.new(0, 0, 17.7))
	fence("FenceLeft", Vector3.new(0.6, 2.5, 36), Vector3.new(-17.7, 0, 0))
	fence("FenceRight", Vector3.new(0.6, 2.5, 36), Vector3.new(17.7, 0, 0))
	fence("FenceFrontLeft", Vector3.new(13, 2.5, 0.6), Vector3.new(-11.5, 0, -17.7))
	fence("FenceFrontRight", Vector3.new(13, 2.5, 0.6), Vector3.new(11.5, 0, -17.7))
	for _, x in { -5.5, 5.5 } do
		K.part({ name = "Post", parent = m, size = Vector3.new(1, 9, 1), cf = cf * CFrame.new(x, L.lotFloorTop + 4.5, -17.7), color = C.Trim })
	end
	local sign = K.part({ name = "Sign", parent = m, size = Vector3.new(12, 2.4, 0.4), cf = cf * CFrame.new(0, L.lotFloorTop + 8.6, -17.7), color = C.Navy })
	K.text(sign, Enum.NormalId.Front, title, C.Trim)
	K.text(sign, Enum.NormalId.Back, title, C.Trim)
	m.Parent = parent
	return m
end

return function(): string
	local root = K.folder(K.root(), "ReservedPlots", true)
	for i, p in L.reservedHub do
		reserved(root, "Reserved" .. i, p, Vector3.new(0, 0, if p.Z > 0 then -1 else 1), "COMING SOON")
	end
	reserved(root, "BossVaultPlot", L.ms.bossPlot, Vector3.new(1, 0, 0), "BOSS VAULT · SOON")
	return ("reserved plots: %d, %d parts"):format(#root:GetChildren(), K.count(root))
end
