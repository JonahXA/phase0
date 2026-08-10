--[[
	EconomyService — the only code allowed to change a player's coin balance.

	Everything here is server-authoritative. The ClickCoin remote carries no
	payload precisely so there is nothing for a client to forge; the server
	decides that a click is worth Config.Economy.CoinsPerClick and applies the
	pass multiplier itself.

	The rate limiter is the actual anti-exploit. A hooked client can fire the
	remote thousands of times a second, and without the cooldown that is a
	linear coin printer.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Telemetry = require(script.Parent.Telemetry)

local EconomyService = {}

local lastClick: { [Player]: number } = {}
local rejectedClicks: { [Player]: number } = {}
local suspicionLogged: { [Player]: boolean } = {}
local firstClickDone: { [Player]: boolean } = {}

-- Set by MonetizationService once pass ownership is known. Kept as a plain
-- lookup so the hot click path never touches MarketplaceService.
local multipliers: { [Player]: number } = {}

function EconomyService.setMultiplier(player: Player, multiplier: number)
	multipliers[player] = multiplier
	EconomyService.pushState(player)
end

function EconomyService.getMultiplier(player: Player): number
	return multipliers[player] or 1
end

function EconomyService.buildState(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	return {
		coins = profile.coins,
		multiplier = EconomyService.getMultiplier(player),
		ownsDoubleCoins = EconomyService.getMultiplier(player) > 1,
	}
end

-- Resolved once in start(). pushState runs on every coin change, and
-- Remotes.get does a WaitForChild each call, which has no business being on a
-- hot path.
local stateRemote: RemoteEvent? = nil

function EconomyService.pushState(player: Player)
	if not stateRemote then
		return -- start() hasn't run yet; the GetState fetch will cover this
	end
	local state = EconomyService.buildState(player)
	if not state then
		return
	end
	stateRemote:FireClient(player, state)
end

--[[
	The single mutation point.

	`reason` and `sku` flow straight into the economy analytics event, which is
	what makes the Creator Dashboard economy chart readable later. If you add a
	new way to gain or spend coins, give it a distinct reason string.
]]
function EconomyService.addCoins(
	player: Player,
	amount: number,
	reason: string,
	sku: string?
): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	if amount == 0 then
		return true
	end

	if amount < 0 and profile.coins + amount < 0 then
		return false -- insufficient funds; caller decides how to surface it
	end

	profile.coins += amount
	if amount > 0 then
		profile.totalCoinsEarned += amount
	end

	Telemetry.economy(player, amount > 0, "Coins", amount, profile.coins, reason, sku)
	EconomyService.pushState(player)
	return true
end

--[[
	Single click handler. Both entry points route here — the HUD button (via the
	ClickCoin remote) and the world part (via ClickDetector) — so the rate limit
	and the first-click funnel step can't be bypassed by using the other path.
]]
function EconomyService.handleClick(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local now = os.clock()
	local previous = lastClick[player]
	if previous and (now - previous) < Config.Economy.ClickCooldownSeconds then
		local count = (rejectedClicks[player] or 0) + 1
		rejectedClicks[player] = count
		if count >= Config.Economy.SuspiciousRejectThreshold and not suspicionLogged[player] then
			suspicionLogged[player] = true
			Telemetry.custom(player, "SuspiciousClickRate", count)
			warn(
				string.format("[Economy] %s exceeded click rate limit %d times", player.Name, count)
			)
		end
		return
	end
	lastClick[player] = now

	if not firstClickDone[player] then
		firstClickDone[player] = true
		Telemetry.onboardingStep(player, Telemetry.OnboardingStep.FirstClick)
		Telemetry.funnelStep(player, Telemetry.OnboardingStep.FirstClick)
	end

	local amount = Config.Economy.CoinsPerClick * EconomyService.getMultiplier(player)
	EconomyService.addCoins(player, amount, "ClickReward")
end

function EconomyService.start()
	stateRemote = Remotes.get("StateChanged") :: RemoteEvent

	local clickRemote = Remotes.get("ClickCoin") :: RemoteEvent
	clickRemote.OnServerEvent:Connect(EconomyService.handleClick)

	local getState = Remotes.get("GetState") :: RemoteFunction
	getState.OnServerInvoke = function(player: Player)
		-- Client may invoke before the profile finishes loading. Yield briefly
		-- rather than returning a zeroed state the client would render.
		local deadline = os.clock() + 20
		while not DataService.get(player) and os.clock() < deadline do
			task.wait(0.1)
		end
		return EconomyService.buildState(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastClick[player] = nil
		rejectedClicks[player] = nil
		suspicionLogged[player] = nil
		firstClickDone[player] = nil
		multipliers[player] = nil
	end)
end

return EconomyService
