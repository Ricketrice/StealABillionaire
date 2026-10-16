-- Studio location: ReplicatedStorage.CreatureAnim (ModuleScript)
-- CreatureAnim  (Milestone 035)
-- Code-driven idles for creature models (no uploaded animations). Each animated prop carries Anim* attributes
-- written by CreatureBuilder from CreatureSpecs; this module moves the prop's Weld.C0 around its build pose.
-- Local only (the welds are changed on this client, nothing replicates): used by StarterPlayerScripts.CreatureClient
-- for creatures in the world and by WorkerPreview for Index / reveal / inventory previews.
--   local state = CreatureAnim.bind(model)     collect animated props + aura emitters (call again after a rescale)
--   CreatureAnim.step(state, t)                 pose every prop at time t
--   CreatureAnim.setAura(state, on, tier?)      aura particles on/off (distance / Low effects); emitters with an AuraTier only run for that tier
--   CreatureAnim.setFx(state, tier?)            effect PARTS (attribute FxTier = World / Captured) shown for that tier, hidden when nil. Bind hides
--                                               them, so previews (Index / reveal, which never call setFx) show only the static model
--   CreatureAnim.rest(state)                    back to the build pose
-- Kit models (035 roster, CreatureKitData) use AnimKind = "chain": the attribute AnimChain is a JSON list of tracks, root joint first
-- ({ k = kind, ax = axis, a = amp, sp = speed, ph = phase, pv = pivot in the body part's space, sig = signature timing }), and the
-- part's weld is posed by the product of the tracks (idle = continuous sin(t*sp+ph); signature = once per period, see weight()).
-- The same maths runs in tools/blender/kit035/char.py (the preview renders), so what the owner approved is what plays.

local CreatureAnim = {}

export type Track = { kind: string, axis: Vector3, amp: number, speed: number, phase: number, pv: CFrame, pvInv: CFrame, sig: any? }
export type Item = {
	part: BasePart,
	weld: Weld,
	kind: string,
	axis: string,
	amp: number,
	speed: number,
	phase: number,
	base: CFrame,
	pivot: CFrame,
	size: Vector3,
	chain: { Track }?,
	pops: boolean?,
}
export type State = { model: Model, scale: number, items: { Item }, auras: { ParticleEmitter }, fx: { BasePart }, tier: string?, offset: number }

local HttpService = game:GetService("HttpService")
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
local MIN_POP = 0.001

-- Weight of one track at time t (signature tracks are 0 outside their window). Mirrors Char.weight in char.py.
local function weight(tr: Track, t: number): number
	local sg = tr.sig
	if not sg then
		return math.sin(t * tr.speed + tr.phase)
	end
	local u = ((t - sg.start) % sg.period) / sg.dur
	if u >= 1 then
		return 0
	end
	local u0 = sg.u0 or 0
	if u < u0 then
		return 0
	end
	u = (u - u0) / (1 - u0)
	local shape = sg.shape or "hump"
	local imp = sg.imp or -0.15
	if shape == "strike" then
		if u < 0.55 then
			return math.sin(math.pi / 2 * u / 0.55)
		elseif u < 0.72 then
			local q = (u - 0.55) / 0.17
			return 1 - (1 - imp) * q * q * (3 - 2 * q)
		end
		local q = (u - 0.72) / 0.28
		return imp * (1 - q * q * (3 - 2 * q))
	elseif shape == "spring" then
		return math.sin(2 * math.pi * (sg.cycles or 2) * u) * math.exp(-3 * u)
	elseif shape == "snap" then
		return math.sin(math.pi * u) ^ 0.5
	elseif shape == "wave" then
		return math.sin(math.pi * u) * math.sin(2 * math.pi * (sg.cycles or 2) * u)
	end
	return math.sin(math.pi * u)
end

local function parseChain(json: string, s: number): { Track }
	local ok, list = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	local out: { Track } = {}
	if not ok then
		return out
	end
	for _, d in list do
		local pv = CFrame.new(Vector3.new(d.pv[1], d.pv[2], d.pv[3]) * s)
		table.insert(out, { kind = d.k, axis = AXES[d.ax] or Vector3.xAxis, amp = d.a, speed = d.sp or 0, phase = d.ph or 0, pv = pv, pvInv = pv:Inverse(), sig = d.sig })
	end
	return out
end

-- A CFrame from the build scale (1) to the model's current scale: only the position is stretched.
local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * (cf - cf.Position)
end

function CreatureAnim.bind(model: Model): State
	local s = model:GetAttribute("CreatureScale") or 1
	local state: State = { model = model, scale = s, items = {}, auras = {}, fx = {}, tier = nil, offset = math.random() * 10 } -- offset: creatures do not all slam at once
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("AnimKind") == "chain" then
			local weld = d:FindFirstChildOfClass("Weld")
			local json = d:GetAttribute("AnimChain")
			if weld and type(json) == "string" then
				local chain = parseChain(json, s)
				local ks = d:GetAttribute("KitSize") -- the scale-1 size (a popped-out part is tiny right now, so d.Size is not it)
				local full: Vector3 = if typeof(ks) == "Vector3" then ks * s else d.Size
				local pops = false
				for _, tr in chain do
					if tr.kind == "pop" then
						pops = true
					end
				end
				table.insert(state.items, {
					part = d,
					weld = weld,
					kind = "chain",
					axis = "X",
					amp = 0,
					speed = 0,
					phase = 0,
					base = scaled(d:GetAttribute("AnimBase") or CFrame.new(), s),
					pivot = CFrame.new(),
					size = full,
					chain = chain,
					pops = pops,
				})
				if pops then
					d.Size = full * MIN_POP -- hidden until its signature move pops it
				end
			end
		elseif d:IsA("BasePart") and d:GetAttribute("AnimKind") then
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
		if d:IsA("BasePart") and d:GetAttribute("FxTier") then
			table.insert(state.fx, d)
			d.LocalTransparencyModifier = 1
		end
	end
	return state
end

-- Poses one chain item: rigid tracks multiply root -> leaf (each about its own rest-frame pivot); grow / pop tracks scale the part itself
-- about their pivot first (they are always last in a chain).
local function stepChain(it: Item, t: number, s: number)
	local m = CFrame.identity
	local sx, sy, sz = 1, 1, 1
	local spv: Vector3? = nil
	for _, tr in it.chain :: { Track } do
		local w = weight(tr, t)
		local k = tr.kind
		if k == "swing" then
			m = m * (tr.pv * CFrame.fromAxisAngle(tr.axis, math.rad(tr.amp * w)) * tr.pvInv)
		elseif k == "spin" then
			m = m * (tr.pv * CFrame.fromAxisAngle(tr.axis, math.rad(tr.amp * t)) * tr.pvInv)
		elseif k == "push" then
			m = m * CFrame.new(tr.axis * (tr.amp * s * w))
		elseif k == "bob" then
			m = m * CFrame.new(Vector3.yAxis * (tr.amp * s * w))
		elseif k == "grow" then
			local f = 1 + (tr.amp - 1) * w
			sx, sy, sz = sx * (if tr.axis == Vector3.xAxis then f else 1), sy * (if tr.axis == Vector3.yAxis then f else 1), sz * (if tr.axis == Vector3.zAxis then f else 1)
			spv = tr.pv.Position
		elseif k == "pop" then
			local f = math.max(tr.amp * w, MIN_POP)
			sx, sy, sz = sx * f, sy * f, sz * f
			spv = tr.pv.Position
		end
	end
	if spv then
		local c0 = it.base.Position
		local centre = spv + Vector3.new((c0.X - spv.X) * sx, (c0.Y - spv.Y) * sy, (c0.Z - spv.Z) * sz)
		it.part.Size = it.size * Vector3.new(sx, sy, sz)
		it.weld.C0 = m * (CFrame.new(centre) * (it.base - c0))
	else
		it.weld.C0 = m * it.base
	end
end

function CreatureAnim.step(state: State, t: number)
	local s = state.scale
	for _, it in state.items do
		if it.chain then
			stepChain(it, t + state.offset, s)
			continue
		end
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
		elseif it.chain then
			it.part.Size = if it.pops then it.size * MIN_POP else it.size
		end
	end
end

function CreatureAnim.setAura(state: State, on: boolean, tier: string?)
	for _, e in state.auras do
		local t = e:GetAttribute("AuraTier")
		local want = on and (t == nil or t == tier)
		if e.Enabled ~= want then
			e.Enabled = want
		end
	end
end

function CreatureAnim.setFx(state: State, tier: string?)
	if state.tier == tier then
		return
	end
	state.tier = tier
	for _, p in state.fx do
		p.LocalTransparencyModifier = if tier ~= nil and p:GetAttribute("FxTier") == tier then 0 else 1
	end
end

return CreatureAnim
