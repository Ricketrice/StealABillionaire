-- Studio location: ServerScriptService.ParadeService (ModuleScript)
-- ParadeService  (Milestone 028, D7)
-- The Worker Parade: mystery workers walk down the red lane from the spawn to the plaza. Walk up,
-- press Catch, pay (the first worker ever is free), the rarity is rolled on the server, the worker
-- spins, is revealed and goes on your shoulder: the same steal -> reveal -> carry pipeline as the
-- zone workers (NPCClaim, WorkerReveal, NPCCarry, WorkerInventory), so placing and saving are unchanged.
--
-- Movement costs nothing on the server: a walker is an anchored rig whose server copy never moves.
-- Its path is a pure function of time (attributes SpawnT, Speed, Offset + the lane attributes on
-- Workspace.Parade.Walkers), so every client draws it walking (ParadeClient) and the server works out
-- where it is only when someone tries to catch it. No Humanoid movement, no pathfinding.
--
-- Catching: the client relays its Catch prompt (ParadeAction "Catch", walker). Catching is race-safe: tryCatch validates (flag, still free, cooldown, data loaded, cash, distance)
-- and reserves through NPCClaim.tryReserve without yielding, so of two players pressing at once
-- exactly one wins; the other is told "Too slow!". The price is taken only after the reservation
-- succeeded, and refunded if the catch is cancelled before the reveal (death, leaving).
--
-- Golden Parade: every GOLDEN_INTERVAL seconds for GOLDEN_LENGTH seconds every parade catch rolls
-- with ParadeConfig.GOLDEN_PER_MILLE and walkers look gold (clients). Window = Workspace.Parade
-- attributes GoldenStart / GoldenEnd / NextGolden (server time, workspace:GetServerTimeNow()).
--
-- Also (Milestone 028): server-wide message for Legendary/Secret catches (parade and zones), and the
-- collection book (`hub.book` = { [workerId] = true } in the save's existing hub field; schema stays 3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CashFormat = require(ReplicatedStorage:WaitForChild("CashFormat"))
local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local NPCClaim = require(script.Parent:WaitForChild("NPCClaim"))
local NPCWanderer = require(script.Parent:WaitForChild("NPCWanderer"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local WorkerInventory = require(script.Parent:WaitForChild("WorkerInventory"))
local WorkerReveal = require(script.Parent:WaitForChild("WorkerReveal"))

local ParadeService = {}

local FLAGS = { "PARADE_ENABLED", "JUICE_ENABLED", "GOAL_HUD_ENABLED", "BOOK_ENABLED" }
local PROMPT_NAME = "StealPrompt" -- NPCClaim removes a prompt with this name when it reserves
local WALKER_NAME = "MysteryWorker"
local WRAP_FOLDER = "WorkerLook" -- WorkerAppearance's fallback look removes a folder with this name

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function ParadeService.flag(name: string): boolean
	return ParadeConfig[name] == true or (RunService:IsStudio() and ServerStorage:GetAttribute(ParadeConfig.STUDIO_ATTRIBUTES[name]) == true)
end

local function getRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: RemoteEvent
end
local clientEvent = getRemote("ParadeEvent") -- server -> client: (kind, info)
local actionEvent = getRemote("ParadeAction") -- client -> server: ("State") | ("Catch", walker)

-- World -----------------------------------------------------------------------------------------------
-- Workspace.Parade is only in the world while the parade runs (flag off = nothing added).
local paradeFolder = Instance.new("Folder")
paradeFolder.Name = "Parade"
local walkers = Instance.new("Folder")
walkers.Name = "Walkers"
walkers.Parent = paradeFolder
ParadeService.walkers = walkers

-- NPCClaim/WorkerReveal read zone.folder.Name (the roster) and zone.npcFolder; odds = Golden Parade.
local rosterTag = Instance.new("Folder")
rosterTag.Name = ParadeConfig.ZONE
local normalZone = { folder = rosterTag, npcFolder = walkers, odds = nil }
local goldenZone = { folder = rosterTag, npcFolder = walkers, odds = ParadeConfig.GOLDEN_PER_MILLE }

type Lane = { start: Vector3, dir: Vector3, side: Vector3, length: number, top: number }
local lane: Lane? = nil

local function findLanePart(): BasePart?
	local world = workspace:FindFirstChild("World")
	local direct = world and world:FindFirstChild("SkyCity") and world.SkyCity:FindFirstChild("Ground")
	direct = direct and direct:FindFirstChild("ParadeLane")
	direct = direct and direct:FindFirstChild("Lane")
	if direct and direct:IsA("BasePart") and direct:GetAttribute("ParadeLane") then
		return direct
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("ParadeLane") == true then
			return d
		end
	end
	return nil
end

-- Lane geometry from the lane part: its long axis, west (-X) end to east end.
local function readLane(): Lane?
	local part = findLanePart()
	if not part then
		return nil
	end
	local cf, size = part.CFrame, part.Size
	local long = if size.X >= size.Z then cf.RightVector * size.X else cf.LookVector * size.Z
	local across = if size.X >= size.Z then cf.LookVector else cf.RightVector
	local dir = long.Unit
	if dir.X < 0 then -- always walk towards +X (spawn -> plaza)
		dir = -dir
	end
	local half = long.Magnitude / 2
	local top = cf.Position.Y + size.Y / 2
	local start = Vector3.new(cf.Position.X, top, cf.Position.Z) - dir * (half - ParadeConfig.START_INSET)
	return {
		start = start,
		dir = dir,
		side = Vector3.new(across.X, 0, across.Z).Unit,
		length = 2 * half - ParadeConfig.START_INSET - ParadeConfig.END_INSET,
		top = top,
	}
end

-- Template --------------------------------------------------------------------------------------------
local template: Model? = nil
local rootLift = 3 -- studs from the lane top to the walker's root centre (measured from the template)

local function prop(parent: Instance, bodyPart: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, wrap: boolean?)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.CanCollide, part.CanTouch, part.CanQuery, part.Massless, part.Anchored = false, false, false, true, false
	part.CastShadow = false
	part.CFrame = bodyPart.CFrame * offset
	if wrap then
		part:SetAttribute("Wrap", true) -- ParadeClient turns these gold during a Golden Parade
	end
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = bodyPart, part, offset
	weld.Parent = part
	part.Parent = parent
	return part
end

local function questionMark(box: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Mark" .. face.Name
	gui.Face = face
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 0
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "?"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(90, 30, 120)
	label.Parent = gui
end

-- A mystery figure: the MysteryNPC rig as a plain purple silhouette in gift-wrap, head inside a gift
-- box with a "?" on every side and a bow on top. Same look for everyone; the real worker is hidden.
local PAPER, RIBBON, BODY = Color3.fromRGB(236, 72, 150), Color3.fromRGB(255, 214, 92), Color3.fromRGB(86, 58, 168)
local function buildTemplate(): Model?
	local source = ServerStorage:FindFirstChild("NPCModels") and ServerStorage.NPCModels:FindFirstChild("MysteryNPC")
	if not (source and source:IsA("Model")) then
		warn("[ParadeService] ServerStorage.NPCModels.MysteryNPC is missing; no parade")
		return nil
	end
	local rig = NPCWanderer.cloneRig(source)
	rig.Name = WALKER_NAME
	for _, child in rig:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child.Name == "Animate" then
			child:Destroy()
		end
	end
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name ~= "HumanoidRootPart" then
				part.Color = if part.Name == "UpperTorso" or part.Name == "LowerTorso" then PAPER else BODY
				part.Material = Enum.Material.SmoothPlastic
				if part.Name == "UpperTorso" or part.Name == "LowerTorso" then
					part:SetAttribute("Wrap", true)
				end
			end
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		elseif part:IsA("Decal") then
			part:Destroy() -- the face hides inside the box anyway
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	root.Transparency = 1

	local look = Instance.new("Folder")
	look.Name = WRAP_FOLDER
	look.Parent = rig
	local head = rig:FindFirstChild("Head") :: BasePart
	local torso = rig:FindFirstChild("UpperTorso") :: BasePart
	if head then
		local box = prop(look, head, "GiftBox", Vector3.new(2, 1.9, 2), CFrame.new(0, 0.15, 0), PAPER, nil, true)
		prop(look, head, "RibbonA", Vector3.new(2.06, 1.96, 0.35), CFrame.new(0, 0.15, 0), RIBBON)
		prop(look, head, "RibbonB", Vector3.new(0.35, 1.96, 2.06), CFrame.new(0, 0.15, 0), RIBBON)
		prop(look, head, "BowL", Vector3.new(0.7, 0.7, 0.7), CFrame.new(-0.35, 1.3, 0), RIBBON, Enum.PartType.Ball)
		prop(look, head, "BowR", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0.35, 1.3, 0), RIBBON, Enum.PartType.Ball)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
			questionMark(box, face)
		end
	end
	if torso then
		prop(look, torso, "Sash", Vector3.new(torso.Size.X + 0.08, 0.3, torso.Size.Z + 0.08), CFrame.new(0, -0.1, 0), RIBBON)
	end

	-- Measure: root centre height above the feet, so walkers stand on the lane.
	local low = math.huge
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = rig:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			low = math.min(low, foot.Position.Y - foot.Size.Y / 2)
		end
	end
	if low < math.huge then
		rootLift = root.Position.Y - low
	end
	return rig
end

-- Walkers ---------------------------------------------------------------------------------------------
local nextId = 0

-- Where a walker is at server time `now` (root centre), and whether it has reached the end.
function ParadeService.position(npc: Model, now: number?): (Vector3, boolean)
	local l = lane :: Lane
	local t = (now or serverNow()) - (npc:GetAttribute("SpawnT") or 0)
	local distance = math.clamp(t * (npc:GetAttribute("Speed") or ParadeConfig.WALK_SPEED), 0, l.length)
	local offset = npc:GetAttribute("Offset") or 0
	return l.start + l.dir * distance + l.side * offset + Vector3.new(0, rootLift, 0), distance >= l.length
end

local catchHandler: (Player, Model) -> ()
local function addPrompt(npc: Model)
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Catch " .. CashFormat.format(ParadeConfig.CATCH_PRICE)
	prompt.ObjectText = "Mystery Worker"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ParadeConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt:SetAttribute("Parade", true)
	prompt.Parent = root
	-- No server Triggered handler: Roblox checks a prompt's distance against the server's copy of the
	-- part, which never moves. The client relays its trigger (ParadeAction "Catch") and tryCatch does
	-- the real checks against where the walker is now.
end

-- Puts a new walker on the lane. `age` seconds of walking already done (to spread them out at start).
function ParadeService.spawn(age: number?): Model?
	if not (template and lane) then
		return nil
	end
	nextId += 1
	local npc = (template :: Model):Clone()
	npc:SetAttribute("ParadeId", nextId)
	npc:SetAttribute("SpawnT", serverNow() - (age or 0))
	npc:SetAttribute("Speed", ParadeConfig.WALK_SPEED)
	npc:SetAttribute("Offset", (math.random() * 2 - 1) * ParadeConfig.LANE_SPREAD)
	local pos, done = ParadeService.position(npc)
	if done then
		npc:Destroy()
		return nil
	end
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local l = lane :: Lane
	npc:PivotTo(CFrame.lookAt(pos, pos + l.dir) * root.CFrame:ToObjectSpace(npc:GetPivot()))
	addPrompt(npc)
	npc.Parent = walkers
	local remaining = (l.length - ((serverNow() - npc:GetAttribute("SpawnT")) * ParadeConfig.WALK_SPEED)) / ParadeConfig.WALK_SPEED
	task.delay(math.max(0, remaining), function()
		if npc.Parent == walkers and npc:GetAttribute("Claimed") ~= true then
			npc:Destroy() -- reached the plaza
		end
	end)
	return npc
end

function ParadeService.clear()
	for _, npc in walkers:GetChildren() do
		npc:Destroy()
	end
end

-- Golden Parade -----------------------------------------------------------------------------------------
function ParadeService.isGolden(now: number?): boolean
	local t = now or serverNow()
	local s, e = paradeFolder:GetAttribute("GoldenStart"), paradeFolder:GetAttribute("GoldenEnd")
	return s ~= nil and e ~= nil and t >= s and t < e
end

function ParadeService.startGolden()
	local now = serverNow()
	paradeFolder:SetAttribute("GoldenStart", now)
	paradeFolder:SetAttribute("GoldenEnd", now + ParadeConfig.GOLDEN_LENGTH)
	paradeFolder:SetAttribute("NextGolden", now + ParadeConfig.GOLDEN_INTERVAL)
	clientEvent:FireAllClients("Golden", { on = true, ends = now + ParadeConfig.GOLDEN_LENGTH })
end

function ParadeService.endGolden()
	local now = serverNow()
	paradeFolder:SetAttribute("GoldenStart", nil)
	paradeFolder:SetAttribute("GoldenEnd", nil)
	-- Next one counts from the start of this one, but never sooner than a full length from now.
	local nextAt = paradeFolder:GetAttribute("NextGolden") or (now + ParadeConfig.GOLDEN_INTERVAL)
	paradeFolder:SetAttribute("NextGolden", math.max(nextAt, now + ParadeConfig.GOLDEN_LENGTH))
	clientEvent:FireAllClients("Golden", { on = false })
end

-- Save data: first free catch, collection book -------------------------------------------------------------
local function hubOf(player: Player): any?
	local data = PlayerData.get(player) :: any
	if not data then
		return nil
	end
	if type(data.hub) ~= "table" then
		data.hub = {}
	end
	return data.hub
end

function ParadeService.isFree(player: Player): boolean
	if not ParadeConfig.FIRST_CATCH_FREE then
		return false
	end
	local hub = hubOf(player)
	if not hub or hub.paradeFree == true then
		return false
	end
	local _, _, _, total = WorkerInventory.count(player)
	return total == 0
end

local function bookList(player: Player): { string }
	local hub = hubOf(player)
	local list = {}
	if hub and type(hub.book) == "table" then
		for id, caught in hub.book do
			if caught == true and type(id) == "string" then
				table.insert(list, id)
			end
		end
	end
	table.sort(list)
	return list
end

function ParadeService.addToBook(player: Player, workerId: string): boolean
	if not ParadeService.flag("BOOK_ENABLED") or not WorkerCatalogue.get(workerId) then
		return false
	end
	local hub = hubOf(player)
	if not hub then
		return false
	end
	if type(hub.book) ~= "table" then
		hub.book = {}
	end
	if hub.book[workerId] == true then
		return false
	end
	local count = 0
	for _ in hub.book do
		count += 1
	end
	if count >= ParadeConfig.BOOK_MAX then
		return false
	end
	hub.book[workerId] = true
	return true
end

function ParadeService.pushState(player: Player)
	if not (player.Parent and PlayerData.isLoaded(player)) then
		return
	end
	clientEvent:FireClient(player, "State", {
		free = ParadeService.flag("PARADE_ENABLED") and ParadeService.isFree(player),
		book = if ParadeService.flag("BOOK_ENABLED") then bookList(player) else {},
	})
end

-- Catching ------------------------------------------------------------------------------------------------
local lastTry: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastState: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
ParadeService.stats = { caught = 0, refused = 0, refunded = 0 }

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Validates and starts a catch. Never yields up to and including the reservation, so only one
-- player can win a walker. Returns ok, or false and a message for the player.
function ParadeService.tryCatch(player: Player, npc: Model): (boolean, string?)
	if not (ParadeService.flag("PARADE_ENABLED") and lane) then
		return false, "The parade is closed."
	end
	if npc.Parent ~= walkers or npc:GetAttribute("Claimed") == true then
		return false, "Too slow! Someone else caught that one."
	end
	local now = os.clock()
	if lastTry[player] and now - lastTry[player] < ParadeConfig.CATCH_COOLDOWN then
		return false, "One at a time!"
	end
	lastTry[player] = now
	if not PlayerData.isLoaded(player) then
		return false, "Your data is still loading."
	end
	local golden = ParadeService.isGolden()
	local free = ParadeService.isFree(player)
	local price = if golden then ParadeConfig.GOLDEN_PRICE else ParadeConfig.CATCH_PRICE
	if not free and price > 0 and CashService.get(player) < price then
		return false, ("You need %s to catch a parade worker. Your workers earn cash on your pads!"):format(CashFormat.format(price))
	end
	local playerRoot = livingRoot(player)
	if not playerRoot then
		return false, "You can't catch right now."
	end
	local pos, done = ParadeService.position(npc)
	if done then
		return false, "Too late, it reached the plaza!"
	end
	if (playerRoot.Position - pos).Magnitude > ParadeConfig.PROMPT_DISTANCE + ParadeConfig.DISTANCE_TOLERANCE then
		return false, "Get closer to catch it."
	end

	-- Stand the server copy where everyone sees it now, then reserve (spin, reveal, carry follow).
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local l = lane :: Lane
	root.CFrame = CFrame.lookAt(pos, pos + l.dir)
	local ok, message = NPCClaim.tryReserve(player, npc, if golden then goldenZone else normalZone)
	if not ok then
		return false, message
	end

	-- Pay (can't fail: nothing yielded since the cash check).
	local paid = 0
	local hub = hubOf(player)
	if free then
		hub.paradeFree = true
	elseif price > 0 and CashService.trySpend(player, price) then
		paid = price
	end
	npc:SetAttribute("CaughtGolden", golden)
	ParadeService.stats.caught += 1
	-- Refund if the catch is cancelled before the reveal (the catcher died or left mid-spin).
	npc.Destroying:Once(function()
		if npc:GetAttribute("WorkerUid") == nil then
			ParadeService.stats.refunded += 1
			if paid > 0 and player.Parent then
				CashService.add(player, paid)
			elseif free and hub then
				hub.paradeFree = nil
			end
		end
	end)
	clientEvent:FireAllClients("Caught", { id = npc:GetAttribute("ParadeId"), by = player.UserId, pos = pos, golden = golden })
	return true
end

catchHandler = function(player: Player, npc: Model)
	local ok, message = ParadeService.tryCatch(player, npc)
	if not ok then
		ParadeService.stats.refused += 1
		if message then
			NPCClaim.notify(player, false, message)
		end
	end
end

-- After every reveal (parade or zone): collection book and the server-wide message.
WorkerReveal.onAnnounce(function(player, identity, npc)
	local worker = WorkerCatalogue.get(identity.workerId)
	if not worker then
		return
	end
	if ParadeService.addToBook(player, identity.workerId) or ParadeService.flag("PARADE_ENABLED") then
		task.defer(ParadeService.pushState, player) -- the free catch is used up too
	end
	if ParadeService.flag("PARADE_ENABLED") and ParadeConfig.ANNOUNCE[worker.rarity] then
		clientEvent:FireAllClients("Announce", {
			player = player.DisplayName,
			userId = player.UserId,
			worker = worker.name,
			workerId = identity.workerId,
			rarity = worker.rarity,
			golden = npc:GetAttribute("CaughtGolden") == true,
		})
	end
end)

-- Start ---------------------------------------------------------------------------------------------------
local function publish()
	for _, name in FLAGS do
		ReplicatedStorage:SetAttribute(ParadeConfig.PUBLISHED[name], if ParadeService.flag(name) then true else nil)
	end
end

local started = false
function ParadeService.start()
	if started then
		return
	end
	started = true
	publish()
	for _, name in FLAGS do
		ServerStorage:GetAttributeChangedSignal(ParadeConfig.STUDIO_ATTRIBUTES[name]):Connect(function()
			publish()
			for _, player in Players:GetPlayers() do
				ParadeService.pushState(player)
			end
		end)
	end
	PlayerData.onLoaded(function(player, data: any)
		if ParadeService.flag("BOOK_ENABLED") and type(data.workers) == "table" then
			for _, w in data.workers do -- workers owned before the book existed count as caught
				if type(w.id) == "string" then
					ParadeService.addToBook(player, w.id)
				end
			end
		end
		task.delay(1, ParadeService.pushState, player)
	end)
	actionEvent.OnServerEvent:Connect(function(player, action, npc)
		local t = os.clock()
		if action == "State" and (not lastState[player] or t - lastState[player] > 0.5) then
			lastState[player] = t
			ParadeService.pushState(player)
		elseif action == "Catch" and typeof(npc) == "Instance" and npc:IsA("Model") and npc:GetAttribute("ParadeId") ~= nil then
			catchHandler(player, npc) -- (a walker someone else just caught gets "Too slow!")
		end
	end)
	if RunService:IsStudio() then -- Studio test hook: ServerStorage StudioGoldenNow = true starts one now
		ServerStorage:GetAttributeChangedSignal("StudioGoldenNow"):Connect(function()
			if ServerStorage:GetAttribute("StudioGoldenNow") == true then
				ServerStorage:SetAttribute("StudioGoldenNow", nil)
				if ParadeService.flag("PARADE_ENABLED") then
					ParadeService.startGolden()
				end
			end
		end)
	end

	task.spawn(function()
		local running = false
		local lastSpawn = 0
		while true do
			local on = ParadeService.flag("PARADE_ENABLED")
			if on and not running then
				lane = lane or readLane()
				template = template or (if lane then buildTemplate() else nil)
				if lane and template then
					running = true
					local l = lane :: Lane
					walkers:SetAttribute("LaneStart", l.start)
					walkers:SetAttribute("LaneDir", l.dir)
					walkers:SetAttribute("LaneSide", l.side)
					walkers:SetAttribute("LaneLength", l.length)
					walkers:SetAttribute("RootLift", rootLift)
					paradeFolder:SetAttribute("NextGolden", serverNow() + ParadeConfig.GOLDEN_FIRST)
					paradeFolder.Parent = workspace
					-- Fill the lane straight away, spread out, so the first player never waits.
					for k = ParadeConfig.MAX_ON_LANE - 1, 1, -1 do
						ParadeService.spawn(k * ParadeConfig.SPAWN_INTERVAL)
					end
					lastSpawn = os.clock()
				else
					warn("[ParadeService] no lane part (attribute ParadeLane) or MysteryNPC; parade stays off")
					on = false
				end
			elseif not on and running then
				running = false
				ParadeService.clear()
				if ParadeService.isGolden() then
					ParadeService.endGolden()
				end
				paradeFolder:SetAttribute("NextGolden", nil)
				paradeFolder.Parent = nil
			end
			if running then
				local now = serverNow()
				local golden = ParadeService.isGolden(now)
				if not golden and paradeFolder:GetAttribute("GoldenEnd") ~= nil then
					ParadeService.endGolden()
				elseif not golden and now >= (paradeFolder:GetAttribute("NextGolden") or math.huge) then
					ParadeService.startGolden()
					golden = true
				end
				local interval = if golden then ParadeConfig.GOLDEN_SPAWN_INTERVAL else ParadeConfig.SPAWN_INTERVAL
				if #walkers:GetChildren() < ParadeConfig.MAX_ON_LANE and os.clock() - lastSpawn >= interval then
					ParadeService.spawn(0)
					lastSpawn = os.clock()
				end
			end
			task.wait(0.25)
		end
	end)
end

ParadeService._test = {
	bookList = bookList,
	hubOf = hubOf,
	lane = function()
		return lane
	end,
	readLane = readLane,
}

return ParadeService
