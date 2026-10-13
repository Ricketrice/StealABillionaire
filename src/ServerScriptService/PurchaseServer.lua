-- Studio location: ServerScriptService.PurchaseServer (Script)
-- PurchaseServer  (Milestone 033): entry point for Robux purchases (PurchaseService). Off unless
-- ProductConfig.PURCHASES_ENABLED (or, in Studio only, ServerStorage attribute StudioPurchases = true).

local PurchaseService = require(script.Parent:WaitForChild("PurchaseService"))

PurchaseService.start()
