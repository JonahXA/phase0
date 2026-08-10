--[[
	Server bootstrap.

	Start order matters and is not arbitrary:
	  1. Remotes.init()  — instances must exist before any client asks for them.
	  2. DataService     — connects PlayerAdded; everything else depends on
	                       profiles existing, so it must be listening first.
	  3. EconomyService  — owns the click handler World will bind to.
	  4. Monetization    — subscribes to DataService.ProfileLoaded.
	  5. World           — binds the ClickDetector into EconomyService.
	  6. Session hooks   — telemetry for join/leave.

	If you add a service, give it an explicit .start() and put it in this list
	rather than letting module require order decide. Implicit init order is how
	"works in Studio, breaks in production" bugs get in.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.DataService)
local EconomyService = require(script.EconomyService)
local MonetizationService = require(script.MonetizationService)
local Telemetry = require(script.Telemetry)
local World = require(script.World)

Remotes.init()

DataService.start()
EconomyService.start()
MonetizationService.start()
World.start()

-- ============================================================
-- Session + retention telemetry
-- ============================================================

DataService.ProfileLoaded.Event:Connect(function(player: Player, profile: any, unsaved: boolean)
	Telemetry.beginSession(player)
	Telemetry.onboardingStep(player, Telemetry.OnboardingStep.Joined)
	Telemetry.onboardingStep(player, Telemetry.OnboardingStep.DataLoaded)
	Telemetry.funnelStep(player, Telemetry.OnboardingStep.Joined)
	Telemetry.funnelStep(player, Telemetry.OnboardingStep.DataLoaded)

	if unsaved then
		-- Watch this one. A nonzero rate here means your retention numbers are
		-- being polluted by players whose progress silently vanishes.
		Telemetry.custom(player, "DataLoadFailed", 1)
	end

	local isNew = profile.sessionCount <= 1
	Telemetry.custom(player, if isNew then "NewPlayer" else "ReturningPlayer", 1, {
		sessionCount = profile.sessionCount,
		distinctDays = #profile.daysSeen,
	})

	local bucket = Telemetry.reportRetention(player, profile)
	if bucket then
		print(string.format("[Phase0] %s returned on D%d bucket", player.Name, bucket))
	end

	EconomyService.pushState(player)
end)

-- Periodic heartbeat so a server crash still leaves a session-length floor on
-- the dashboard rather than losing the session entirely.
task.spawn(function()
	while true do
		task.wait(Config.Analytics.SessionHeartbeatSeconds)
		for _, player in Players:GetPlayers() do
			if DataService.get(player) then
				Telemetry.custom(player, "SessionHeartbeat", 1)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local profile = DataService.get(player)
	if profile then
		Telemetry.custom(player, "SessionEnd", 1, {
			coins = profile.coins,
			purchases = profile.purchaseCount,
		})
	end
	Telemetry.endSession(player)
end)

print(string.format("[Phase0] server up (data v%d)", Config.DataVersion))
