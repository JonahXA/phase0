--[[
	MonetizationService — game passes and developer products.

	The ProcessReceipt callback below is the highest-stakes code in the project.
	Two rules govern it:

	  1. It must be IDEMPOTENT. Roblox re-delivers a receipt until you return
	     PurchaseGranted, including across server restarts and rejoins. Without
	     a durable record of honored receipts, a player who buys once during a
	     server hiccup gets granted two, five, twenty times.

	  2. It must return NotProcessedYet on ANY uncertainty. Returning
	     PurchaseGranted when the grant did not durably persist means the player
	     paid Robux and got nothing, and Roblox will not re-deliver. That is a
	     refund request and a one-star review.

	How this satisfies both: the receipt marker lives in the player's own
	profile, so "add the coins" and "mark the receipt honored" are the same
	single DataStore write. There is no window where one landed and the other
	didn't. Sequence:

	    already marked in profile?  -> yes: return PurchaseGranted (replay)
	    mutate coins + mark receipt in memory
	    DataService.save()          -> failed: roll both back, NotProcessedYet
	                                -> ok:     return PurchaseGranted

	Note the deliberate absence of a second DataStore and of UpdateAsync here.
	An earlier draft of this file put the grant and the save inside a
	receipt-store UpdateAsync transform. That throws at runtime: UpdateAsync
	transform callbacks are not permitted to yield, and DataService.save yields.
	It would also have made two stores that can disagree with each other.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Telemetry = require(script.Parent.Telemetry)

local MonetizationService = {}

-- productId -> config key, built at startup from Config.DeveloperProducts.
local productLookup: { [number]: string } = {}
local shopOpened: { [Player]: boolean } = {}

local function isConfigured(id: number?): boolean
	return type(id) == "number" and id > 0
end

-- ============================================================
-- Game passes
-- ============================================================

local function checkDoubleCoins(player: Player)
	local passId = Config.GamePasses.DoubleCoins
	if not isConfigured(passId) then
		EconomyService.setMultiplier(player, 1)
		return
	end

	local owns = false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			owns = result
			break
		end
		warn(
			string.format(
				"[Monetization] pass check %d failed for %s: %s",
				attempt,
				player.Name,
				tostring(result)
			)
		)
		task.wait(attempt)
	end

	EconomyService.setMultiplier(player, if owns then Config.Economy.DoubleCoinsMultiplier else 1)
end

-- ============================================================
-- Developer products
-- ============================================================

local function grantProduct(player: Player, configKey: string): boolean
	local amount = Config.ProductGrants[configKey]
	if not amount then
		warn(string.format("[Monetization] no grant defined for %q", configKey))
		return false
	end
	return EconomyService.addCoins(player, amount, "ProductPurchase", configKey)
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- They left mid-purchase. Roblox re-delivers on their next join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local configKey = productLookup[receiptInfo.ProductId]
	if not configKey then
		-- Unknown product: almost always a Config gap after adding a product in
		-- the dashboard but not here. Do NOT grant, do NOT consume the receipt.
		warn(string.format("[Monetization] unmapped ProductId %d", receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)

	-- Replay of a receipt this profile already honored. The marker was loaded
	-- from the DataStore alongside the coins it granted, so if it's here, the
	-- coins are too.
	if profile.processedReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local amount = Config.ProductGrants[configKey]
	if not grantProduct(player, configKey) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.robuxSpent += receiptInfo.CurrencySpent
	profile.purchaseCount += 1
	DataService.rememberReceipt(profile, purchaseId)

	-- Durability gate. Only claim the receipt once the grant AND the marker
	-- have survived a real write.
	if not DataService.save(player, false) then
		-- Roll everything back so Roblox's retry doesn't double-grant.
		EconomyService.addCoins(player, -amount, "ProductRollback", configKey)
		profile.robuxSpent -= receiptInfo.CurrencySpent
		profile.purchaseCount -= 1
		DataService.forgetReceipt(profile, purchaseId)
		warn(string.format("[Monetization] receipt %s not durable; will retry", purchaseId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Telemetry.onboardingStep(player, Telemetry.OnboardingStep.FirstPurchase)
	Telemetry.funnelStep(player, Telemetry.OnboardingStep.FirstPurchase)
	Telemetry.custom(player, "PurchaseCompleted", receiptInfo.CurrencySpent, {
		product = configKey,
		robux = receiptInfo.CurrencySpent,
	})

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================================
-- Purchase prompts (client-initiated)
-- ============================================================

local function onPurchaseRequest(player: Player, kind: unknown, key: unknown)
	if type(kind) ~= "string" or type(key) ~= "string" then
		return -- malformed remote payload
	end

	if not shopOpened[player] then
		shopOpened[player] = true
		Telemetry.onboardingStep(player, Telemetry.OnboardingStep.FirstShopOpen)
		Telemetry.funnelStep(player, Telemetry.OnboardingStep.FirstShopOpen)
	end

	if kind == "gamepass" then
		local id = Config.GamePasses[key]
		if not isConfigured(id) then
			warn(string.format("[Monetization] game pass %q is not configured (id 0)", key))
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, id)
	elseif kind == "product" then
		local id = Config.DeveloperProducts[key]
		if not isConfigured(id) then
			warn(string.format("[Monetization] product %q is not configured (id 0)", key))
			return
		end
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

function MonetizationService.start()
	for key, id in Config.DeveloperProducts do
		if isConfigured(id) then
			productLookup[id] = key
		end
	end

	-- Must be assigned exactly once, on the server, for the whole game.
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if wasPurchased and passId == Config.GamePasses.DoubleCoins then
			EconomyService.setMultiplier(player, Config.Economy.DoubleCoinsMultiplier)
			Telemetry.custom(player, "GamePassPurchased", 1, { pass = "DoubleCoins" })
			Telemetry.onboardingStep(player, Telemetry.OnboardingStep.FirstPurchase)
		end
	end)

	local requestRemote = Remotes.get("RequestPurchase") :: RemoteEvent
	requestRemote.OnServerEvent:Connect(onPurchaseRequest)

	DataService.ProfileLoaded.Event:Connect(function(player)
		task.spawn(checkDoubleCoins, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		shopOpened[player] = nil
	end)
end

return MonetizationService
