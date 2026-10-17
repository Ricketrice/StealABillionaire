-- Studio location: ServerStorage.BossRigs.Shared.NullVfx (ModuleScript)
-- NullVfx: the Vfx module of a rig that has no effects (the Knight's Keep NPCs). Shared.Client calls new / onClip / step / destroy; all do nothing.

local NullVfx = {}
NullVfx.__index = NullVfx

function NullVfx.new(_model: Model, _data: any, _assets: { [string]: string }?, _opts: { lowFx: boolean? }?)
	return setmetatable({}, NullVfx)
end

function NullVfx:onClip(_clip: string, _elapsed: number) end

function NullVfx:step(_now: number, _dt: number) end

function NullVfx:destroy() end

return NullVfx
