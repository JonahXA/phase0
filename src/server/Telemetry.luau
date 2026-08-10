--[[
	Telemetry — every analytics call in the game goes through here.

	Why a wrapper instead of calling AnalyticsService directly:
	  1. AnalyticsService throws if you pass a malformed argument, and an
	     analytics failure must never take down a gameplay path. Everything is
	     pcall-wrapped.
	  2. Event names become a typo surface. Centralizing them means the
	     dashboard doesn't end up with "FirstPurchase" and "First_Purchase".
	  3. Retention bucketing is real logic, not a passthrough.

	Where to read the results: Creator Dashboard -> your experience -> Analytics.
	  - Engagement tab gives D1/D7/D28 retention natively.
	  - Custom events show under Custom Events (up to ~1h ingest delay).
	  - Funnels show under Funnels, keyed by Config.Analytics.OnboardingFunnelName.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Telemetry = {}

-- Onboarding funnel steps. Order matters; these are the numbers the dashboard
-- charts drop-off against.
Telemetry.OnboardingStep = {
	Joined = { 1, "Joined" },
	DataLoaded = { 2, "DataLoaded" },
	FirstClick = { 3, "FirstClick" },
	FirstShopOpen = { 4, "FirstShopOpen" },
	FirstPurchase = { 5, "FirstPurchase" },
}

-- Per-player funnel session id. A funnel session groups steps into one journey;
-- reusing one id across two visits would merge them into a single funnel run.
local funnelSessions: { [Player]: string } = {}

local function safe(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(string.format("[Telemetry] %s failed: %s", label, tostring(err)))
	end
end

function Telemetry.beginSession(player: Player)
	funnelSessions[player] = HttpService:GenerateGUID(false)
end

function Telemetry.endSession(player: Player)
	funnelSessions[player] = nil
end

--[[
	Onboarding funnel. Roblox has a dedicated onboarding funnel that is
	first-session-only by definition, so call this for new players; for returning
	players it is a no-op on the dashboard side but harmless.
]]
function Telemetry.onboardingStep(player: Player, step: { any })
	safe("onboardingStep", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step[1], step[2])
	end)
end

--[[ Generic funnel — use for repeatable journeys (shop -> prompt -> bought). ]]
function Telemetry.funnelStep(player: Player, step: { any })
	safe("funnelStep", function()
		local sessionId = funnelSessions[player]
		if not sessionId then
			return
		end
		AnalyticsService:LogFunnelStepEvent(
			player,
			Config.Analytics.OnboardingFunnelName,
			sessionId,
			step[1],
			step[2]
		)
	end)
end

--[[
	Economy event. `amount` is always positive; direction comes from flowType.
	`endingBalance` must be the balance AFTER the transaction — the dashboard
	uses it to detect currency inflation and duplication exploits, so passing a
	stale value quietly poisons the chart.
]]
function Telemetry.economy(
	player: Player,
	isSource: boolean,
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string?
)
	safe("economy", function()
		local flow = if isSource
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			math.abs(amount),
			endingBalance,
			transactionType,
			itemSku
		)
	end)
end

function Telemetry.custom(
	player: Player,
	eventName: string,
	value: number?,
	fields: { [string]: any }?
)
	safe("custom:" .. eventName, function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, fields)
	end)
end

--[[
	Retention.

	Roblox's built-in Engagement tab already gives you D1/D7/D28 and it is the
	number you should trust for the kill criteria. This function exists because
	the built-in chart cannot be segmented, and during Phase 1 you want to ask
	"did the players who reached FirstPurchase retain better?" — which needs a
	custom event carrying the day bucket.

	Returns the day bucket reported this join, or nil if none was due.
]]
function Telemetry.reportRetention(player: Player, profile: any): number?
	local daysSinceFirst = math.floor((os.time() - profile.firstJoinTime) / 86400)
	if daysSinceFirst <= 0 then
		return nil
	end

	-- Snap to the largest tracked bucket this join qualifies for, so a player
	-- returning on day 5 counts toward D3 rather than falling through the gaps.
	local bucket: number? = nil
	for _, day in Config.Analytics.RetentionDaysTracked do
		if daysSinceFirst >= day then
			bucket = day
		end
	end
	if not bucket then
		return nil
	end

	local key = "d" .. tostring(bucket)
	if profile.retentionReported[key] then
		return nil -- already counted; a second join same day is not a second retain
	end
	profile.retentionReported[key] = true

	Telemetry.custom(player, "Retention_D" .. tostring(bucket), 1, {
		sessionCount = profile.sessionCount,
		totalPlaytimeMinutes = math.floor(profile.totalPlaytimeSeconds / 60),
		paid = profile.purchaseCount > 0,
	})

	return bucket
end

return Telemetry
