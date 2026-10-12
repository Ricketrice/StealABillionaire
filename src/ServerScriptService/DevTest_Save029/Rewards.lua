-- Studio location: ServerScriptService.DevTest_Save029.Rewards (ModuleScript)
-- The "save029:rewards" half of DevTest_Save029: daily streak, playtime gifts, offline earnings, index
-- claims, settings and favourites through a real final save + a real load on the Studio DataStore, and
-- none of them can be claimed twice afterwards. The only thing edited by hand is B's saved "last
-- seen" time, moved one hour back between the save and the load (SIM: an hour away).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

return function(ctx: any)
	local A, B, expect, scenario, waitUntil = ctx.A, ctx.B, ctx.expect, ctx.scenario, ctx.waitUntil
	local RewardsService = ctx.RewardsService
	local PlayerData, CashService, WorkerInventory = ctx.mod("PlayerData"), ctx.mod("CashService"), ctx.mod("WorkerInventory")
	local RewardsConfig = require(ReplicatedStorage:WaitForChild("RewardsConfig")) :: any
	local V1Flags = require(ReplicatedStorage:WaitForChild("V1Flags")) :: any
	local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any
	for _, name in V1Flags.NAMES do
		ServerStorage:SetAttribute(V1Flags.STUDIO_ATTRIBUTES[name], true)
	end
	task.wait(0.5)
	local function hub(p: Player): any
		return (PlayerData.get(p) :: any).hub
	end
	local function give(p: Player, id: string, station: number?): string
		local uid = HttpService:GenerateGUID(false)
		local rec = { uid = uid, id = id, zone = WorkerCatalogue.get(id).zone, level = 1, tier = "Normal", loc = if station then "station" else "inventory", station = station }
		assert(WorkerInventory.give(p, rec, true), "give failed")
		if station then
			WorkerInventory.respawn(p, uid)
		end
		return uid
	end

	local favUid: string? = nil
	local income = 0
	scenario("rewards before the save", function()
		local ok = RewardsService.claimDaily(A)
		expect("A claims today's daily reward", ok)
		RewardsService._test.setSince(A, os.time() - (RewardsConfig.PLAYTIME[1].minutes * 60 + 10))
		ok = RewardsService.claimPlaytime(A, 1)
		expect("A opens playtime gift 1 (SIM: 5 minutes played)", ok, nil, true)
		ok = RewardsService.setSettings(A, { music = false, sfx = true, lowfx = true, lowgfx = false })
		expect("A changes settings", ok)
		favUid = give(A, "broke_bob")
		ok = RewardsService.setFavourite(A, favUid, true)
		expect("A favourites a worker", ok)
		local ids = WorkerCatalogue.ZONES.MainStreet
		for i = 1, math.ceil(#ids / 2) do
			if not RewardsService._test.collected(A)[ids[i]] then
				give(A, ids[i])
			end
		end
		ok = RewardsService.claimIndex(A, "MainStreet")
		expect("A claims the Main Street half-page bonus", ok)
		for _, id in { "crypto_carl", "security_sam" } do
			give(B, id, nil)
		end
		-- B's workers go on stations 1 and 2 so they earn offline
		local n = 0
		for _, w in (PlayerData.get(B) :: any).workers do
			if (w.id == "crypto_carl" or w.id == "security_sam") and w.loc == "inventory" and n < 2 then
				n += 1
				local rec = WorkerInventory.take(B, w.uid)
				rec.loc, rec.station = "station", n
				WorkerInventory.give(B, rec)
				WorkerInventory.respawn(B, w.uid)
			end
		end
		for _, w in (PlayerData.get(B) :: any).workers do
			if w.loc == "station" then
				income += WorkerCatalogue.get(w.id).income
			end
		end
		expect("B has workers on stations", income > 0, income)
	end)

	scenario("real save, an hour away, real load", function()
		local cashA = CashService.get(A)
		PlayerData._test.leave(A)
		PlayerData._test.leave(B)
		local stored = ctx.raw(-1)
		expect(
			"A's save has daily, play, settings, favs, index, seen",
			stored and stored.hub and stored.hub.daily and stored.hub.play and stored.hub.settings and stored.hub.favs and stored.hub.index and stored.hub.seen,
			stored and HttpService:JSONEncode(stored.hub)
		)
		-- SIM: B was away for an hour.
		local store = PlayerData.store()
		store:UpdateAsync("player_-2", function(record)
			if record and record.data and record.data.hub then
				record.data.hub.seen = os.time() - 3600
			end
			return record
		end)
		task.spawn(PlayerData._test.load, A)
		task.spawn(PlayerData._test.load, B)
		expect(
			"both load again",
			waitUntil(40, function()
				return PlayerData.isLoaded(A) and PlayerData.isLoaded(B) and WorkerInventory.isReady(A) and WorkerInventory.isReady(B)
			end)
		)
		expect("A's cash came back", CashService.get(A) >= cashA, ("%d vs %d"):format(CashService.get(A), cashA))
	end)

	scenario("after the rejoin", function()
		local h = hub(A)
		expect("daily streak kept", h.daily and h.daily.streak == 1 and h.daily.day == math.floor(os.time() / 86400), HttpService:JSONEncode(h.daily or {}))
		local ok = RewardsService.claimDaily(A)
		expect("today's daily can't be claimed again", not ok)
		expect("playtime gift 1 still opened", h.play and h.play.got and h.play.got["1"] == true)
		ok = RewardsService.claimPlaytime(A, 1)
		expect("gift 1 can't be opened again", not ok)
		expect("today's playtime kept", h.play.secs >= RewardsConfig.PLAYTIME[1].minutes * 60, h.play.secs)
		expect("settings kept", h.settings and h.settings.music == false and h.settings.lowfx == true)
		expect("favourite kept", h.favs and favUid and h.favs[favUid] == true)
		expect(
			"index claim kept and paid out as a bonus",
			h.index and h.index.MainStreet == 1 and A:GetAttribute("IncomeBonus") == RewardsConfig.INDEX_TIERS[1].bonus,
			A:GetAttribute("IncomeBonus")
		)
		ok = RewardsService.claimIndex(A, "MainStreet")
		expect("the same tier can't be claimed again", not ok)
		local hb = hub(B)
		local want = math.floor(income * RewardsConfig.OFFLINE_RATE * 3600)
		expect(
			"B's hour away is waiting to be collected",
			type(hb.offline) == "number" and math.abs(hb.offline - want) <= income,
			("%s vs %d"):format(tostring(hb.offline), want),
			true
		)
		local cash = CashService.get(B)
		ok = RewardsService.claimOffline(B)
		expect("B collects it", ok and CashService.get(B) - cash >= want - income)
		ok = RewardsService.claimOffline(B)
		expect("B can't collect it twice", not ok)
		PlayerData._test.leave(B)
		task.spawn(PlayerData._test.load, B)
		waitUntil(40, function()
			return PlayerData.isLoaded(B) and WorkerInventory.isReady(B)
		end)
		expect("after another quick rejoin nothing is offered again", (hub(B).offline or 0) == 0, hub(B).offline)
	end)
	for _, name in V1Flags.NAMES do
		ServerStorage:SetAttribute(V1Flags.STUDIO_ATTRIBUTES[name], nil)
	end
end
