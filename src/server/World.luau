--[[
	World — builds the (deliberately ugly) test environment in code.

	Everything is generated at runtime rather than committed as a .rbxl so the
	repo stays diffable text. That trade stops being worth it the moment you
	have real art; at that point the place file becomes the source of truth for
	Workspace and Rojo syncs only scripts into it.

	Guards on "does it already exist" let this run against either an empty
	DataModel or the standard Baseplate template without duplicating anything.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local EconomyService = require(script.Parent.EconomyService)

local World = {}

local function ensureBaseplate()
	if Workspace:FindFirstChild("Baseplate") then
		return
	end
	local base = Instance.new("Part")
	base.Name = "Baseplate"
	base.Size = Vector3.new(512, 20, 512)
	base.Position = Vector3.new(0, -10, 0)
	base.Anchored = true
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BrickColor = BrickColor.new("Medium stone grey")
	base.Parent = Workspace
end

local function ensureSpawn()
	if Workspace:FindFirstChildOfClass("SpawnLocation") then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 16)
	spawn.Anchored = true
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.Parent = Workspace
end

local function buildCoinButton()
	local existing = Workspace:FindFirstChild("CoinButton")
	if existing then
		existing:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = "CoinButton"
	part.Size = Vector3.new(8, 8, 8)
	part.Position = Vector3.new(0, 4, 0)
	part.Anchored = true
	part.Material = Enum.Material.Neon
	part.BrickColor = BrickColor.new("Bright yellow")

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 32
	detector.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(8, 2)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "CLICK ME"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard

	detector.MouseClick:Connect(function(player)
		EconomyService.handleClick(player)
	end)

	part.Parent = Workspace
end

function World.start()
	ensureBaseplate()
	ensureSpawn()
	buildCoinButton()

	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 125)
end

return World
