-- Studio location: ReplicatedStorage.RevealCardArt (ModuleScript)
-- RevealCardArt
-- Roblox image ids for the reveal card artwork (source files: assets/reveal_cards in the project
-- folder, one folder per zone and rarity). Read by StarterPlayerScripts.WorkerRevealCard.
--   * Only zones listed in ZONES get artwork. Every other zone keeps the plain card.
--   * A layer left as "" (not uploaded yet) is skipped: the card keeps its plain look for it.
--   * WORKERS can override any layer for one worker id (unique art or accents later on).
-- 035: MainStreet and BillionaireHills no longer carry a skyline backdrop; WorkerRevealCard paints a zone-themed gradient instead.
-- Layers: backdrop (behind the 3D worker), frame (border, corners, text plates), emblem (rarity
-- crest on the seam), banner (plate behind the Legendary / Secret banner text).
-- Display only: nothing here affects workers, odds, income or saved data.

local RevealCardArt = {}

local LAYERS = { "backdrop", "frame", "emblem", "banner" }

local ZONES: { [string]: { [string]: { [string]: string } } } = {
	MainStreet = { -- uploaded from assets/reveal_cards/upload/MainStreet_<Rarity>_<layer>.png
		Common = { frame = "rbxassetid://96060357389988", emblem = "rbxassetid://138400261537868" },
		Rare = { frame = "rbxassetid://108294966283334", emblem = "rbxassetid://136527459253602" },
		Epic = { frame = "rbxassetid://139924150538075", emblem = "rbxassetid://83969166555893" },
		Legendary = { frame = "rbxassetid://71267891360889", emblem = "rbxassetid://91380025643635", banner = "rbxassetid://119139822743544" },
		Secret = { frame = "rbxassetid://94002315409776", emblem = "rbxassetid://73946549668287", banner = "rbxassetid://137896114884215" },
	},
	BillionaireHills = { -- Velocity Royale: upload/VelocityRoyale_<Rarity>_<layer>.png
		Common = { frame = "rbxassetid://90415781773797", emblem = "rbxassetid://98390866758673" },
		Rare = { frame = "rbxassetid://123202146865591", emblem = "rbxassetid://100653759383720" },
		Epic = { frame = "rbxassetid://108501986030351", emblem = "rbxassetid://116818836890030" },
		Legendary = { frame = "rbxassetid://112837782574053", emblem = "rbxassetid://102426515162048", banner = "rbxassetid://101269411087817" },
		Secret = { frame = "rbxassetid://73656709194635", emblem = "rbxassetid://101010935210272", banner = "rbxassetid://72371807977331" },
	},
}

-- Per-worker overrides, e.g. ceo_chad = { backdrop = "rbxassetid://123" }
local WORKERS: { [string]: { [string]: string } } = {}

local function valid(id: any): boolean
	return type(id) == "string" and id ~= ""
end

-- The artwork for one worker, as { backdrop?, frame?, emblem?, banner? }, or nil if it has none.
function RevealCardArt.get(workerId: string, zoneId: string?, rarity: string): { [string]: string }?
	local zone = zoneId and ZONES[zoneId]
	local set = zone and zone[rarity]
	local override = WORKERS[workerId]
	local out, any = {}, false
	for _, layer in LAYERS do
		local id = override and override[layer]
		if not valid(id) then
			id = set and set[layer]
		end
		if valid(id) then
			out[layer] = id
			any = true
		end
	end
	return if any then out else nil
end

-- Every image id in use, for preloading.
function RevealCardArt.all(): { string }
	local ids, seen = {}, {}
	local function add(set)
		for _, id in set do
			if valid(id) and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	for _, zone in ZONES do
		for _, set in zone do
			add(set)
		end
	end
	for _, set in WORKERS do
		add(set)
	end
	return ids
end

return RevealCardArt
