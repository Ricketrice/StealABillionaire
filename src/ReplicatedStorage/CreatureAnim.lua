-- Studio location: ReplicatedStorage.CreatureAnim (ModuleScript)
-- CreatureAnim  (Milestone 035)
-- Code-driven idles for creature models (no uploaded animations). Each animated prop carries Anim* attributes
-- written by CreatureBuilder from CreatureSpecs; this module moves the prop's Weld.C0 around its build pose.
-- Local only (the welds are changed on this client, nothing replicates): used by StarterPlayerScripts.CreatureClient
-- for creatures in the world and by WorkerPreview for Index / reveal / inventory previews.
--   local state = CreatureAnim.bind(model)     collect animated props + aura emitters (call again after a rescale)
--   CreatureAnim.step(state, t)                 pose every prop at time t
--   CreatureAnim.setAura(state, on)             aura particles on/off (distance / Low effects)
--   CreatureAnim.rest(state)                    back to the build pose

local CreatureAnim = {}

export type Item = { part: BasePart, weld: Weld, kind: string, axis: string, amp: number, speed: number, phase: number, base: CFrame, pivot: CFrame, size: Vector3 }
export type State = { model: Model, scale: number, items: { Item }, auras: { ParticleEmitter } }

local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

-- A CFrame from the build scale (1) to the model's current scale: only the position is stretched.
local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * (cf - cf.Position)
end

function CreatureAnim.bind(model: Model): State
	local s = model:GetAttribute("CreatureScale") or 1
	local state: State = { model = model, scale = s, items = {}, auras = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("AnimKind") then
			local weld = d:FindFirstChildOfClass("Weld")
			if weld then
				table.insert(state.items, {
					part = d,
					weld = weld,
					kind = d:GetAttribute("AnimKind"),
					axis = d:GetAttribute("AnimAxis") or "X",
					amp = d:GetAttribute("AnimAmp") or 0,
					speed = d:GetAttribute("AnimSpeed") or 2,
					phase = d:GetAttribute("AnimPhase") or 0,
					base = scaled(d:GetAttribute("AnimBase") or CFrame.new(), s),
					pivot = CFrame.new((d:GetAttribute("AnimPivot") or CFrame.new()).Position * s),
					size = d.Size,
				})
			end
		elseif d:IsA("ParticleEmitter") and d:GetAttribute("Aura") then
			table.insert(state.auras, d)
		end
	end
	return state
end

function CreatureAnim.step(state: State, t: number)
	local s = state.scale
	for _, it in state.items do
		local w = math.sin(t * it.speed + it.phase)
		local axis = AXES[it.axis] or Vector3.xAxis
		if it.kind == "swing" then
			it.weld.C0 = it.pivot * CFrame.fromAxisAngle(axis, math.rad(it.amp * w)) * it.pivot:Inverse() * it.base
		elseif it.kind == "spin" then
			it.weld.C0 = it.pivot * CFrame.fromAxisAngle(axis, math.rad(it.amp * t)) * it.pivot:Inverse() * it.base
		elseif it.kind == "push" or it.kind == "bob" then
			local dir = if it.kind == "bob" then Vector3.yAxis else axis
			it.weld.C0 = CFrame.new(dir * (it.amp * s * w)) * it.base
		elseif it.kind == "pulse" then
			it.part.Size = it.size * (1 + it.amp * w)
		end
	end
end

function CreatureAnim.rest(state: State)
	for _, it in state.items do
		it.weld.C0 = it.base
		if it.kind == "pulse" then
			it.part.Size = it.size
		end
	end
end

function CreatureAnim.setAura(state: State, on: boolean)
	for _, e in state.auras do
		if e.Enabled ~= on then
			e.Enabled = on
		end
	end
end

return CreatureAnim
