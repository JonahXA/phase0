--[[
	HUD — throwaway UI built in code.

	This is intentionally plain. Phase 0 is a pipeline test, and spending time on
	UI polish here would be the exact mistake the feasibility report warns about:
	art and juice matter enormously for retention, but only once you have proof
	the loop and the plumbing work at all.

	The HUD renders state it is given. It never computes a balance locally — the
	server is the only thing that knows how many coins you have.
]]

local Players = game:GetService("Players")

local HUD = {}
HUD.__index = HUD

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function button(text: string, color: Color3, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	corner(b, 8)
	return b
end

function HUD.new()
	local self = setmetatable({}, HUD)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Phase0HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Coin counter
	local counter = Instance.new("TextLabel")
	counter.Name = "Coins"
	counter.Size = UDim2.fromOffset(240, 56)
	counter.Position = UDim2.fromOffset(16, 16)
	counter.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	counter.BackgroundTransparency = 0.15
	counter.BorderSizePixel = 0
	counter.Text = "0 coins"
	counter.TextScaled = true
	counter.Font = Enum.Font.GothamBold
	counter.TextColor3 = Color3.fromRGB(255, 214, 66)
	corner(counter, 10)
	counter.Parent = gui
	self.counter = counter

	-- Multiplier badge, hidden until the pass is owned
	local badge = Instance.new("TextLabel")
	badge.Name = "Multiplier"
	badge.Size = UDim2.fromOffset(110, 32)
	badge.Position = UDim2.fromOffset(16, 80)
	badge.BackgroundColor3 = Color3.fromRGB(46, 120, 60)
	badge.BorderSizePixel = 0
	badge.Text = "2x ACTIVE"
	badge.TextScaled = true
	badge.Font = Enum.Font.GothamBold
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Visible = false
	corner(badge, 8)
	badge.Parent = gui
	self.badge = badge

	-- Main click button
	self.clickButton = button(
		"CLICK",
		Color3.fromRGB(232, 172, 32),
		UDim2.fromOffset(200, 90),
		UDim2.new(0.5, -100, 1, -130)
	)
	self.clickButton.Parent = gui

	-- Shop
	self.shopToggle = button(
		"SHOP",
		Color3.fromRGB(58, 92, 190),
		UDim2.fromOffset(120, 48),
		UDim2.new(1, -136, 0, 16)
	)
	self.shopToggle.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.Size = UDim2.fromOffset(300, 230)
	panel.Position = UDim2.new(1, -316, 0, 76)
	panel.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	corner(panel, 12)
	panel.Parent = gui
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 34)
	title.Position = UDim2.fromOffset(10, 10)
	title.BackgroundTransparency = 1
	title.Text = "Shop"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	self.buyPass = button(
		"2x Coins (Pass)",
		Color3.fromRGB(46, 120, 60),
		UDim2.new(1, -20, 0, 50),
		UDim2.fromOffset(10, 52)
	)
	self.buyPass.Parent = panel

	self.buy100 = button(
		"+100 Coins",
		Color3.fromRGB(58, 92, 190),
		UDim2.new(1, -20, 0, 50),
		UDim2.fromOffset(10, 112)
	)
	self.buy100.Parent = panel

	self.buy500 = button(
		"+500 Coins",
		Color3.fromRGB(58, 92, 190),
		UDim2.new(1, -20, 0, 50),
		UDim2.fromOffset(10, 172)
	)
	self.buy500.Parent = panel

	self.shopToggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	return self
end

function HUD:render(state: { coins: number, multiplier: number, ownsDoubleCoins: boolean }?)
	if not state then
		self.counter.Text = "loading..."
		return
	end
	self.counter.Text = string.format("%d coins", state.coins)
	self.badge.Visible = state.ownsDoubleCoins
	self.buyPass.Visible = not state.ownsDoubleCoins
end

return HUD
