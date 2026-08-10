--!strict
--[[
	Remotes — single source of truth for the client/server boundary.

	The server calls Remotes.init() once at startup to build the instances.
	The client calls Remotes.get(name) and yields until they exist.

	Every remote listed here is untrusted input. The server validates on receipt;
	nothing in this table is authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

-- name -> class
local DEFINITIONS: { [string]: string } = {
	-- Client -> Server: "I clicked the button." Carries no payload; the server
	-- decides what a click is worth. Never trust a client-supplied amount.
	ClickCoin = "RemoteEvent",

	-- Client -> Server: "Prompt me to buy X." Server calls MarketplaceService.
	RequestPurchase = "RemoteEvent",

	-- Server -> Client: authoritative state push (coins, multiplier, owned passes).
	StateChanged = "RemoteEvent",

	-- Client -> Server, yields: fetch full state on join.
	GetState = "RemoteFunction",
}

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	f.Parent = ReplicatedStorage
	return f
end

--[[ Server only. Creates every remote instance. Idempotent. ]]
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() is server-only")
	local f = folder()
	for name, className in DEFINITIONS do
		if not f:FindFirstChild(name) then
			local inst = Instance.new(className)
			inst.Name = name
			inst.Parent = f
		end
	end
end

--[[ Either side. Yields until the remote replicates. ]]
function Remotes.get(name: string): Instance
	assert(DEFINITIONS[name], string.format("unknown remote %q", name))
	local f = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	assert(f, "Remotes folder never replicated - is the server bootstrap running?")
	local inst = f:WaitForChild(name, 30)
	assert(inst, string.format("remote %q never replicated", name))
	return inst
end

return Remotes
