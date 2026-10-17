-- Studio location: ServerStorage.VaultWizardTest.RuntimeSrc.Driver (ModuleScript)
-- Driver: code-driven animation for the Vault wizard rig (Motor6D.Transform from converted clip tables).
-- Runs on every CLIENT (cosmetic, no server cost): the server only sets four replicated attributes on the model
--   VW_Base (string, looping clip) / VW_BaseT0 (server time)   VW_Clip (string, one-shot or loop) / VW_ClipT0 (server time)
-- and each client plays the same clip at the same server-time offset, so late joiners join mid-clip.
-- Clip tables (see tools/blender/vault/vw_convert.py): joints[name] = { stride, t, qx, qy, qz, qw [, px, py, pz], t, ... } (stride 5 = rotation only, 8 = rotation + position, studs).

local Driver = {}
Driver.__index = Driver

local FADE = 0.15 -- cross-fade between clips, seconds

-- i = index of the key's time value; the quaternion follows it (and the position after that when stride = 8)
local function cfAt(track: { number }, i: number, stride: number): CFrame
	if stride == 8 then
		return CFrame.new(track[i + 5], track[i + 6], track[i + 7], track[i + 1], track[i + 2], track[i + 3], track[i + 4])
	end
	return CFrame.new(0, 0, 0, track[i + 1], track[i + 2], track[i + 3], track[i + 4])
end

-- Interpolated Transform of one joint at time t (clamped to the track).
local function sampleTrack(track: { number }, t: number): CFrame
	local stride = track[1]
	local n = (#track - 1) // stride
	local first = 2
	if n == 1 or t <= track[first] then
		return cfAt(track, first, stride)
	end
	local lastIdx = first + (n - 1) * stride
	if t >= track[lastIdx] then
		return cfAt(track, lastIdx, stride)
	end
	local lo, hi = 0, n - 1
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if track[first + mid * stride] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = first + lo * stride, first + hi * stride
	local u = (t - track[a]) / (track[b] - track[a])
	return cfAt(track, a, stride):Lerp(cfAt(track, b, stride), u)
end

local function sampleScale(track: { number }?, t: number): number
	if not track then
		return 1
	end
	local n = #track // 2
	if t <= track[1] then
		return track[2]
	end
	if t >= track[(n - 1) * 2 + 1] then
		return track[n * 2]
	end
	for i = 0, n - 2 do
		local t0, t1 = track[i * 2 + 1], track[i * 2 + 3]
		if t >= t0 and t <= t1 then
			local u = (t - t0) / (t1 - t0)
			return track[i * 2 + 2] + (track[i * 2 + 4] - track[i * 2 + 2]) * u
		end
	end
	return 1
end

-- Pure function (used by the tests): the pose table { jointName = CFrame } of a clip at time t (looped when the clip loops).
function Driver.samplePose(clip: any, t: number): { [string]: CFrame }
	local tt = t
	if clip.loop then
		tt = t % clip.length
	end
	local pose = {}
	for name, track in clip.joints do
		pose[name] = sampleTrack(track, tt)
	end
	return pose
end

function Driver.new(model: Model, data: any, clips: { [string]: any })
	local self = setmetatable({}, Driver)
	self.model = model
	self.data = data
	self.clips = clips
	self.motors = {} :: { [string]: Motor6D }
	for jointName, j in data.joints do
		local part1 = model:FindFirstChild(j.p1)
		local motor = part1 and part1:FindFirstChild(jointName)
		if motor and motor:IsA("Motor6D") then
			self.motors[jointName] = motor
		else
			warn("[VaultDriver] missing Motor6D", jointName)
		end
	end
	-- parts whose SIZE follows a clip scale track (the halo and its neon trim)
	self.scaled = {} :: { [string]: { parts: { BasePart }, sizes: { Vector3 }, last: number } }
	for _, w in data.welds do
		local base = model:FindFirstChild(w.p0)
		local neon = model:FindFirstChild(w.p1)
		if base and neon and base:IsA("BasePart") and neon:IsA("BasePart") then
			local e = self.scaled[w.p0]
			if not e then
				e = { parts = { base }, sizes = { base.Size }, last = 1 }
				self.scaled[w.p0] = e
			end
			table.insert(e.parts, neon)
			table.insert(e.sizes, neon.Size)
		end
	end
	-- cosmetic spinners (FX_ joints: halo, gem) are n-fold symmetric by contract: they never cross-fade their rotation (a 135 deg -> 0 slerp would spin visibly), only their position
	self.spin = {} :: { [string]: boolean }
	for _, jn in data.spin do
		self.spin[jn] = true
	end
	self.base = "Idle"
	self.baseT0 = 0
	self.clip = nil :: string?
	self.clipT0 = 0
	self.from = nil :: { [string]: CFrame }?
	self.fadeT0 = -1
	self.listeners = {} :: { (string, number) -> () }
	self.lastPose = {} :: { [string]: CFrame }
	return self
end

function Driver:onClipStart(fn: (string, number) -> ())
	table.insert(self.listeners, fn)
end

function Driver:_snapshot()
	local snap = {}
	for name, motor in self.motors do
		snap[name] = motor.Transform
	end
	self.from = snap
end

function Driver:setBase(name: string, t0: number)
	if self.base == name then
		return
	end
	if not self.clips[name] then
		return
	end
	self:_snapshot()
	self.fadeT0 = t0
	self.base, self.baseT0 = name, t0
end

-- Start (or restart) a clip whose server start time was t0; now = current server time.
function Driver:playAt(name: string, t0: number, now: number)
	local clip = self.clips[name]
	if not clip then
		return
	end
	if not clip.loop and now - t0 >= clip.length then
		return -- already over (late join)
	end
	self:_snapshot()
	self.fadeT0 = now
	self.clip, self.clipT0 = name, t0
	for _, fn in self.listeners do
		fn(name, math.max(0, now - t0))
	end
end

-- Follow the server's replicated attributes. Call once; then call step(now) every frame.
function Driver:bind(getNow: () -> number)
	local model = self.model
	local function readBase()
		local b, t0 = model:GetAttribute("VW_Base"), model:GetAttribute("VW_BaseT0")
		if typeof(b) == "string" then
			self:setBase(b, if typeof(t0) == "number" then t0 else getNow())
		end
	end
	local function readClip()
		local c, t0 = model:GetAttribute("VW_Clip"), model:GetAttribute("VW_ClipT0")
		if typeof(c) == "string" and c ~= "" and typeof(t0) == "number" then
			self:playAt(c, t0, getNow())
		end
	end
	local conns = {
		model:GetAttributeChangedSignal("VW_Base"):Connect(readBase),
		model:GetAttributeChangedSignal("VW_BaseT0"):Connect(readBase),
		model:GetAttributeChangedSignal("VW_ClipT0"):Connect(readClip),
	}
	readBase()
	readClip()
	self.conns = conns
end

-- Applies a pose table and the halo scale at once (used by the freeze mode and by step).
function Driver:_apply(pose: { [string]: CFrame }, clip: any, t: number)
	for name, motor in self.motors do
		local target = pose[name] or CFrame.identity
		motor.Transform = target
		self.lastPose[name] = target
	end
	local tt = if clip.loop then t % clip.length else t
	for partName, e in self.scaled do
		local s = sampleScale(if clip.scales then clip.scales[partName] else nil, tt)
		if math.abs(s - e.last) > 0.002 then
			e.last = s
			for i, p in e.parts do
				p.Size = e.sizes[i] * s
			end
		end
	end
end

function Driver:step(now: number)
	-- test hook: VW_Freeze (number) holds the clip named by VW_Clip at that time, no blending
	local frozen = self.model:GetAttribute("VW_Freeze")
	if typeof(frozen) == "number" then
		local fc = self.clips[self.model:GetAttribute("VW_Clip")]
		if fc then
			self:_apply(Driver.samplePose(fc, frozen), fc, frozen)
			self.from = nil
			return
		end
	end
	local clipName = self.clip
	local clip = if clipName then self.clips[clipName] else nil
	local t, scales
	if clip and clipName then
		local el = now - self.clipT0
		if el >= clip.length and not clip.loop then
			self.clip = nil
			self:_snapshot()
			self.fadeT0 = now
			clip = nil
		else
			t = el
		end
	end
	if not clip then
		clip = self.clips[self.base]
		t = now - self.baseT0
	end
	if not clip then
		return
	end
	local pose = Driver.samplePose(clip, t :: number)
	scales = clip.scales
	local alpha = 1
	local from = self.from
	if from then
		alpha = math.clamp((now - self.fadeT0) / FADE, 0, 1)
		if alpha >= 1 then
			self.from = nil
		end
	end
	for name, motor in self.motors do
		local target = pose[name] or CFrame.identity
		if from and alpha < 1 then
			local a = alpha * alpha * (3 - 2 * alpha)
			local blended = (from[name] or CFrame.identity):Lerp(target, a)
			target = if self.spin[name] then CFrame.new(blended.Position) * target.Rotation else blended
		end
		motor.Transform = target
		self.lastPose[name] = target
	end
	local tt = if clip.loop then t % clip.length else t :: number
	for partName, e in self.scaled do
		local s = sampleScale(if scales then scales[partName] else nil, tt)
		if math.abs(s - e.last) > 0.002 then
			e.last = s
			for i, p in e.parts do
				p.Size = e.sizes[i] * s
			end
		end
	end
end

function Driver:destroy()
	if self.conns then
		for _, c in self.conns do
			c:Disconnect()
		end
	end
	table.clear(self.listeners)
end

return Driver
