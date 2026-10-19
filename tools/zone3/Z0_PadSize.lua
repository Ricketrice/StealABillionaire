-- Z0_PadSize.lua (Hub 2b, 2026-10-20): shrinks every lot's six station pads so 14 pads fit the hub 2b base with
-- >= 1.5 studs clear of every base part (BaseConfig.PAD_SPOTS has the measured grid; tools/zone3/pad_*.py).
-- Pad disc 6 -> 5.4 wide, ring 6.8 -> 6.2 (cylinders: Size.X is the thickness). Bought / unlock / pass pads are
-- run-time clones of Station1, so they follow. Run in Studio Edit; re-runnable; UNDO = true restores the sizes.
local UNDO = UNDO or false
local PAD, RING = 5.4, 6.2

local n = 0
for _, plot in workspace.Hub.Plots:GetChildren() do
	local stations = plot:FindFirstChild("Stations")
	for _, pad in (if stations then stations:GetChildren() else {}) do
		if not (pad:IsA("BasePart") and pad:GetAttribute("StationIndex")) then
			continue
		end
		for _, part in { pad, pad:FindFirstChild("Ring") } do
			if not (part and part:IsA("BasePart")) then
				continue
			end
			local pre = part:GetAttribute("PreZ0Size")
			if UNDO then
				if typeof(pre) == "Vector3" then
					part.Size = pre
					part:SetAttribute("PreZ0Size", nil)
					n += 1
				end
			else
				if typeof(pre) ~= "Vector3" then
					part:SetAttribute("PreZ0Size", part.Size)
				end
				local d = if part == pad then PAD else RING
				part.Size = Vector3.new(part.Size.X, d, d)
				n += 1
			end
		end
	end
end
return (if UNDO then "Z0 undone: " else "Z0 ok: ") .. n .. " pad/ring parts"
