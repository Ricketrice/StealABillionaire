-- Studio location: ServerScriptService.DataStoreMock (ModuleScript)
-- DataStoreMock
-- In-memory stand-in for a DataStore, with UpdateAsync/GetAsync semantics. Used for automated
-- persistence tests and, in Studio only, when API access is disabled (nothing persists then).
-- Values are deep-copied in and out, like a real DataStore, so callers can't share tables with it.
-- Failure injection for tests: set `failNext` to make that many upcoming requests error.
-- Set `latency` (seconds) to make each request yield like a real one, so requests can interleave.

local HttpService = game:GetService("HttpService")

local DataStoreMock = {}
DataStoreMock.__index = DataStoreMock

local function copy(value: any): any
	if value == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(value)) -- also rejects non-saveable values
end

function DataStoreMock.new()
	return setmetatable({ values = {}, failNext = 0, requests = 0, latency = 0 }, DataStoreMock)
end

function DataStoreMock:_request()
	self.requests += 1
	if self.latency > 0 then
		task.wait(self.latency)
	end
	if self.failNext > 0 then
		self.failNext -= 1
		error("DataStoreMock: injected request failure")
	end
end

function DataStoreMock:GetAsync(key: string): any
	self:_request()
	return copy(self.values[key])
end

function DataStoreMock:UpdateAsync(key: string, transform: (any) -> any): any
	self:_request()
	local result = transform(copy(self.values[key]))
	if result == nil then
		return copy(self.values[key]) -- cancelled: nothing written
	end
	self.values[key] = copy(result)
	return copy(result)
end

return DataStoreMock
