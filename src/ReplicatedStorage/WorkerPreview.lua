-- Studio location: ReplicatedStorage.WorkerPreview (ModuleScript)
-- WorkerPreview
-- 3D worker previews for UI: a ViewportFrame + WorldModel + Camera showing the worker's actual look
-- (static models baked into ReplicatedStorage.WorkerPreviews from the real NPC template and
-- WorkerAppearance). Shared by the inventory and the reveal card.
--   local handle = WorkerPreview.mount(container, workerId, { rotate = true?, yaw = degrees? })
--   handle.set(workerId)  -- swap the worker shown
--   handle.release()      -- returns the viewport to the pool (always call when hidden)
--   handle.tint(color)    -- multiplies the rendered image (black = silhouette, white = normal)
-- Performance: viewports are pooled; at most MAX_ACTIVE are live at once (fewer on touch devices),
-- extra requests get a lightweight placeholder; static by default, and every rotating preview is
-- driven by one shared RenderStepped connection that only runs while something rotates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local templates = ReplicatedStorage:WaitForChild("WorkerPreviews")
local CustomWorkers = require(ReplicatedStorage:WaitForChild("CustomWorkers"))
local CreatureAnim = require(ReplicatedStorage:WaitForChild("CreatureAnim"))

local WorkerPreview = {}
WorkerPreview.MAX_ACTIVE = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 12 else 24
WorkerPreview.active = 0

local FOV = 26
local BASE_YAW = 200 -- slight three-quarter turn toward the camera
local SPIN_SPEED = 40 -- degrees per second for rotating previews

local pool: { ViewportFrame } = {}
local spinning: { [any]: boolean } = {}
local spinConn: RBXScriptConnection? = nil

local function newViewport(): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(150, 150, 165)
	vp.LightColor = Color3.fromRGB(255, 240, 222)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.7)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

-- Fits the whole model (head to boots, wings, staff) in the view for the container's shape; a rotating model is fitted
-- by its widest side so it never clips as it turns.
local function frame(model: Model, cam: Camera, aspect: number)
	local cf, size = model:GetBoundingBox()
	local tanHalf = math.tan(math.rad(FOV / 2))
	local wide = math.max(size.X, size.Z)
	local needV = (size.Y / 2) / tanHalf
	local needH = (wide / 2) / (tanHalf * math.max(aspect, 0.3))
	local dist = math.max(needV, needH) * 1.2 + wide / 2
	local target = cf.Position
	cam.CFrame = CFrame.lookAt(target + Vector3.new(0, size.Y * 0.05, dist), target)
end

local function ensureSpinLoop()
	if spinConn or next(spinning) == nil then
		return
	end
	spinConn = RunService.RenderStepped:Connect(function(dt)
		if next(spinning) == nil then
			spinConn:Disconnect()
			spinConn = nil
			return
		end
		for handle in spinning do
			handle._yaw += SPIN_SPEED * dt
			if handle._model then
				handle._model:PivotTo(CFrame.Angles(0, math.rad(handle._yaw), 0))
			end
		end
	end)
end

-- 035: previews of creatures play the same code-driven idle as in the world (one shared loop while any is live).
local animating: { [any]: CreatureAnim.State } = {}
local animConn: RBXScriptConnection? = nil
local function ensureAnimLoop()
	if animConn or next(animating) == nil then
		return
	end
	animConn = RunService.RenderStepped:Connect(function()
		if next(animating) == nil then
			animConn:Disconnect()
			animConn = nil
			return
		end
		local t = os.clock()
		for _, state in animating do
			CreatureAnim.step(state, t)
		end
	end)
end

local function placeholder(container: GuiObject, workerId: string?)
	local worker = workerId and WorkerCatalogue.get(workerId)
	local color = worker and UIStyle.Rarity[worker.rarity] or UIStyle.Colors.TextMuted
	local f = Instance.new("TextLabel")
	f.Name = "PreviewFallback"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.Font = UIStyle.Font
	f.TextScaled = true
	f.Text = worker and (UIStyle.RarityGlyph[worker.rarity] or "?") or "?"
	f.TextColor3 = color
	f.TextTransparency = 0.35
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 44
	c.Parent = f
	f.Parent = container
	return f
end

function WorkerPreview.mount(container: GuiObject, workerId: string, opts: { rotate: boolean?, yaw: number? }?)
	local options = opts or {}
	local handle = { _yaw = options.yaw or BASE_YAW }
	local vp: ViewportFrame? = nil
	local fallback: Instance? = nil

	local function clear()
		animating[handle] = nil
		if handle._model then
			handle._model:Destroy()
			handle._model = nil
		end
		if fallback then
			fallback:Destroy()
			fallback = nil
		end
	end

	function handle.set(id: string)
		clear()
		-- Custom character models (Milestone 019) win over the baked original look.
		local entry = CustomWorkers.get(id)
		local avatars = entry and entry.rig == "avatar" and ReplicatedStorage:FindFirstChild("WorkerPreviews019R")
		local custom = entry and ReplicatedStorage:FindFirstChild("WorkerPreviews019")
		local creatures = ReplicatedStorage:FindFirstChild("CreatureModels")
		local creature = creatures and creatures:FindFirstChild(id)
		local templ = creature or (avatars and avatars:FindFirstChild(id)) or (custom and custom:FindFirstChild(id)) or templates:FindFirstChild(id)
		if not templ then
			if vp then
				vp.Visible = false
			end
			fallback = placeholder(container, id)
			return
		end
		if not vp then
			if WorkerPreview.active >= WorkerPreview.MAX_ACTIVE then
				fallback = placeholder(container, id)
				return
			end
			vp = table.remove(pool) or newViewport()
			WorkerPreview.active += 1
		end
		vp.Visible = true
		vp.ImageColor3 = handle._tint or Color3.new(1, 1, 1)
		local model = templ:Clone()
		if creature then
			for _, d in model:GetChildren() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
		end
		model:PivotTo(CFrame.Angles(0, math.rad(handle._yaw), 0))
		model.Parent = vp:FindFirstChildOfClass("WorldModel")
		handle._model = model
		if creature then
			local state = CreatureAnim.bind(model)
			CreatureAnim.setAura(state, true)
			animating[handle] = state
			ensureAnimLoop()
		end
		local abs = container.AbsoluteSize
		frame(model, vp.CurrentCamera, if abs.Y > 0 then abs.X / abs.Y else 1)
		vp.Parent = container
	end

	function handle.tint(color: Color3)
		handle._tint = color
		if vp then
			vp.ImageColor3 = color
		end
	end

	function handle.release()
		spinning[handle] = nil
		clear()
		if vp then
			vp.ImageColor3 = Color3.new(1, 1, 1)
			vp.Parent = nil
			table.insert(pool, vp)
			vp = nil
			WorkerPreview.active -= 1
		end
	end

	handle.set(workerId)
	if options.rotate then
		spinning[handle] = true
		ensureSpinLoop()
	end
	return handle
end

return WorkerPreview
