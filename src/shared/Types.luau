--!strict
--[[
	Types — the saved-data schema and the state shape pushed to clients.

	Profile is what lives in the DataStore. Every field must be JSON-serializable
	(no Instances, no mixed-key tables, no NaN). Adding a field means bumping
	Config.DataVersion and handling it in DataService.migrate().
]]

export type Profile = {
	version: number,

	-- Economy
	coins: number,
	totalCoinsEarned: number,

	-- Retention primitives. Unix seconds, server clock (os.time()).
	firstJoinTime: number,
	lastJoinTime: number,
	sessionCount: number,
	totalPlaytimeSeconds: number,

	-- Distinct UTC day-stamps on which this player joined, as "YYYY-MM-DD".
	-- Used to compute return-day buckets without a second datastore read.
	-- Capped at 40 entries so the profile can't grow without bound.
	daysSeen: { string },

	-- Retention day buckets already reported, so a player who joins twice on
	-- day 1 only counts once.
	retentionReported: { [string]: boolean },

	-- Monetization
	robuxSpent: number,
	purchaseCount: number,

	-- Receipt idempotency. PurchaseId -> true for every developer product
	-- receipt already honored. Lives in the profile rather than a separate
	-- store so that "grant the coins" and "mark the receipt" are one write and
	-- therefore atomic. Bounded; see DataService.rememberReceipt.
	processedReceipts: { [string]: boolean },
	receiptOrder: { string },
}

export type ClientState = {
	coins: number,
	multiplier: number,
	ownsDoubleCoins: boolean,
}

return {}
