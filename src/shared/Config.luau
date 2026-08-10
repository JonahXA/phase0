--!strict
--[[
	Config — every tunable and every Roblox asset ID lives here.

	IMPORTANT: the IDs below are placeholders (0). Monetization is inert until you
	fill them in. See docs/SETUP.md step 4 for where to get each ID.
]]

local Config = {}

-- ============================================================
-- Identity
-- ============================================================

Config.GameName = "Phase0"

-- Bump this when you change the shape of saved player data. Any profile with an
-- older version runs through DataService's migration path on load.
Config.DataVersion = 1

-- DataStore name. Changing this orphans all existing player data, which is
-- exactly what you want when resetting a test. Add a suffix like "_test2".
--
-- There is deliberately no separate receipt store: purchase receipts are
-- recorded inside the player profile so that granting and marking are a single
-- atomic write. See MonetizationService.
Config.PlayerDataStore = "PlayerData_v1"

-- ============================================================
-- Monetization
--
-- Live IDs for the EXP1 experience, universe 10673593342.
-- All three are priced at 1 Robux so self-testing purchases costs nothing
-- meaningful. Managed pricing is deliberately OFF on all of them — regional
-- price optimization would make the purchase test non-deterministic.
-- ============================================================

Config.GamePasses = {
	-- 2x coins on every earn, permanent.
	DoubleCoins = 1943641498,
}

Config.DeveloperProducts = {
	-- One-time consumable coin grants.
	Coins100 = 3700511457,
	Coins500 = 3700519374,
}

-- How many coins each developer product grants. Keyed by the same names above.
Config.ProductGrants = {
	Coins100 = 100,
	Coins500 = 500,
}

-- ============================================================
-- Economy tuning
-- ============================================================

Config.Economy = {
	CoinsPerClick = 1,
	DoubleCoinsMultiplier = 2,

	-- Server-side rate limit. The client can spam the remote all it likes; the
	-- server silently drops anything faster than this.
	ClickCooldownSeconds = 0.15,

	-- If a player exceeds this many rejected clicks in a session, log a
	-- suspicion event. Not a ban — just a signal that something is scripted.
	SuspiciousRejectThreshold = 200,
}

-- ============================================================
-- Persistence
-- ============================================================

Config.Data = {
	AutosaveIntervalSeconds = 120,
	MaxLoadRetries = 4,
	RetryBaseDelaySeconds = 1, -- exponential: 1, 2, 4, 8
}

-- ============================================================
-- Analytics
-- ============================================================

Config.Analytics = {
	-- Heartbeat cadence for session-length tracking. Session length is derived
	-- from join/leave, but a heartbeat means a server crash still leaves a
	-- reasonable lower bound on the dashboard.
	SessionHeartbeatSeconds = 60,

	-- Retention day buckets we emit as discrete custom events. These are what
	-- you read to evaluate the Phase 1 kill criteria.
	RetentionDaysTracked = { 1, 2, 3, 7, 14, 28 },

	OnboardingFunnelName = "Onboarding",
}

-- ============================================================
-- Kill criteria — the numbers from the feasibility report.
-- Nothing reads these at runtime; they live here so the bar is written down
-- before you build, not rationalized after.
-- ============================================================

Config.KillCriteria = {
	MinD1RetentionPercent = 20,
	EvaluateAfterOrganicVisits = 5000,
	MinCCUWithinTwoWeeks = 50,
}

return Config
