--[[
	Client bootstrap.

	Responsibilities, and nothing beyond them:
	  - build the HUD
	  - fetch initial state, then render whatever the server pushes
	  - forward intent (clicked, wants to buy) to the server

	It does not track coins, apply multipliers, or decide whether a purchase
	succeeded. Every one of those is a server answer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HUD = require(script.HUD)

local clickRemote = Remotes.get("ClickCoin") :: RemoteEvent
local purchaseRemote = Remotes.get("RequestPurchase") :: RemoteEvent
local stateRemote = Remotes.get("StateChanged") :: RemoteEvent
local getState = Remotes.get("GetState") :: RemoteFunction

local hud = HUD.new()
hud:render(nil)

stateRemote.OnClientEvent:Connect(function(state)
	hud:render(state)
end)

hud.clickButton.Activated:Connect(function()
	-- No payload. The server decides what a click is worth; sending an amount
	-- here would just be a number an exploiter edits.
	clickRemote:FireServer()
end)

hud.buyPass.Activated:Connect(function()
	purchaseRemote:FireServer("gamepass", "DoubleCoins")
end)

hud.buy100.Activated:Connect(function()
	purchaseRemote:FireServer("product", "Coins100")
end)

hud.buy500.Activated:Connect(function()
	purchaseRemote:FireServer("product", "Coins500")
end)

-- Initial pull. The server yields until the profile is loaded, so this can take
-- a couple of seconds on a cold DataStore.
task.spawn(function()
	local ok, state = pcall(function()
		return getState:InvokeServer()
	end)
	if ok then
		hud:render(state)
	else
		warn("[Phase0] initial state fetch failed: " .. tostring(state))
	end
end)
