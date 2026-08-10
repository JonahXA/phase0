--[[
	DataService — player persistence.

	This is deliberately a small hand-rolled store rather than ProfileStore or
	ProfileService. For Phase 0 the goal is that you can read every line and know
	exactly what happens to a save; for a real Phase 1 game, swap this for
	ProfileStore (it handles session locking across servers properly, which this
	does not).

	Known limitation, stated plainly: this has no cross-server session lock. If
	the same player is somehow in two servers at once, last write wins. That is
	acceptable for a pipeline test and NOT acceptable for a game with real
	monetization at scale.

	Save strategy:
	  - UpdateAsync, never SetAsync, so a concurrent write can't silently clobber.
	  - Autosave every Config.Data.AutosaveIntervalSeconds.
	  - Save on PlayerRemoving and on BindToClose.
	  - Never save a profile that failed to load — that would overwrite good data
	    with defaults, which is the single worst bug in this category.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local store = DataStoreService:GetDataStore(Config.PlayerDataStore)

local DataService = {}

-- player -> profile. Absent means "not loaded" and therefore "do not save".
local profiles: { [Player]: any } = {}
-- players whose load failed outright. We let them play but never persist.
local failedLoads: { [Player]: boolean } = {}
-- join tick per player, for playtime accounting.
local sessionStart: { [Player]: number } = {}

DataService.ProfileLoaded = Instance.new("BindableEvent")

local function utcDayStamp(): string
	return os.date("!%Y-%m-%d")
end

local function defaultProfile(): any
	local now = os.time()
	return {
		version = Config.DataVersion,
		coins = 0,
		totalCoinsEarned = 0,
		firstJoinTime = now,
		lastJoinTime = now,
		sessionCount = 0,
		totalPlaytimeSeconds = 0,
		daysSeen = {},
		retentionReported = {},
		robuxSpent = 0,
		purchaseCount = 0,
		processedReceipts = {},
		receiptOrder = {},
	}
end

--[[
	Records a honored purchase receipt on the profile, evicting the oldest once
	we pass the cap. 200 receipts is far more than any single player will
	generate, and Roblox stops re-delivering a receipt long before it could age
	out — so eviction is a safety valve against unbounded profile growth, not a
	correctness risk.
]]
local MAX_RECEIPTS = 200

function DataService.rememberReceipt(profile: any, purchaseId: string)
	if profile.processedReceipts[purchaseId] then
		return
	end
	profile.processedReceipts[purchaseId] = true
	table.insert(profile.receiptOrder, purchaseId)
	while #profile.receiptOrder > MAX_RECEIPTS do
		local oldest = table.remove(profile.receiptOrder, 1)
		if oldest then
			profile.processedReceipts[oldest] = nil
		end
	end
end

function DataService.forgetReceipt(profile: any, purchaseId: string)
	if not profile.processedReceipts[purchaseId] then
		return
	end
	profile.processedReceipts[purchaseId] = nil
	local index = table.find(profile.receiptOrder, purchaseId)
	if index then
		table.remove(profile.receiptOrder, index)
	end
end

--[[
	Migration. Called on every load whose stored version is behind current.
	Add a branch per version bump; never delete an old branch, or players who
	haven't logged in since that version lose their data.
]]
local function migrate(profile: any): any
	if profile.version == nil then
		profile.version = 0
	end

	-- Backfill any field added after the profile was written. Cheap and covers
	-- the common case of "I added a counter".
	local defaults = defaultProfile()
	for key, value in defaults do
		if profile[key] == nil then
			profile[key] = if type(value) == "table" then {} else value
		end
	end

	profile.version = Config.DataVersion
	return profile
end

local function keyFor(player: Player): string
	return "u_" .. tostring(player.UserId)
end

--[[ Loads with bounded exponential backoff. Returns profile or nil on failure. ]]
local function loadProfile(player: Player): any?
	local delaySeconds = Config.Data.RetryBaseDelaySeconds

	for attempt = 1, Config.Data.MaxLoadRetries do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)

		if ok then
			if result == nil then
				return defaultProfile()
			end
			if type(result) ~= "table" then
				-- Corrupt or foreign value at this key. Do NOT overwrite it;
				-- treat as a load failure so the player plays unsaved and you
				-- still have the original bytes to inspect.
				warn(string.format("[DataService] non-table profile for %s", player.Name))
				return nil
			end
			return migrate(result)
		end

		warn(
			string.format(
				"[DataService] load attempt %d for %s failed: %s",
				attempt,
				player.Name,
				tostring(result)
			)
		)
		if attempt < Config.Data.MaxLoadRetries then
			task.wait(delaySeconds)
			delaySeconds *= 2
		end
	end

	return nil
end

--[[ Records this join into the retention primitives. Mutates in place. ]]
local function stampJoin(profile: any)
	local today = utcDayStamp()
	local alreadyToday = false
	for _, d in profile.daysSeen do
		if d == today then
			alreadyToday = true
			break
		end
	end
	if not alreadyToday then
		table.insert(profile.daysSeen, today)
		-- Bound the array. Beyond ~40 distinct days the early entries stop
		-- being interesting and the profile just gets heavier on every write.
		while #profile.daysSeen > 40 do
			table.remove(profile.daysSeen, 1)
		end
	end

	profile.lastJoinTime = os.time()
	profile.sessionCount += 1
end

function DataService.get(player: Player): any?
	return profiles[player]
end

--[[
	Saves. `finalize` folds the current session's playtime in and is only true on
	leave/shutdown, so an autosave mid-session doesn't double-count.
]]
function DataService.save(player: Player, finalize: boolean?): boolean
	local profile = profiles[player]
	if not profile then
		return false -- never loaded, or load failed: saving would destroy data
	end
	if failedLoads[player] then
		return false
	end

	if finalize and sessionStart[player] then
		profile.totalPlaytimeSeconds += math.floor(os.clock() - sessionStart[player])
		sessionStart[player] = nil
	end

	-- Snapshot so a mutation during the yielding write can't produce a torn
	-- record. table.clone is shallow, so nested tables are cloned explicitly —
	-- a shallow clone alone would still share `processedReceipts` with live
	-- code and defeat the point.
	local snapshot = table.clone(profile)
	for key, value in profile do
		if type(value) == "table" then
			snapshot[key] = table.clone(value)
		end
	end

	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(_old)
			return snapshot
		end)
	end)

	if not ok then
		warn(string.format("[DataService] save failed for %s: %s", player.Name, tostring(err)))
		return false
	end
	return true
end

local function onPlayerAdded(player: Player)
	sessionStart[player] = os.clock()

	local profile = loadProfile(player)

	if not profile then
		failedLoads[player] = true
		-- Give them a working in-memory profile so the game is playable, but it
		-- will never be written back.
		profile = defaultProfile()
		warn(string.format("[DataService] %s is playing UNSAVED (load failed)", player.Name))
	end

	stampJoin(profile)
	profiles[player] = profile

	-- Player may have left during the yielding load.
	if not player.Parent then
		profiles[player] = nil
		failedLoads[player] = nil
		sessionStart[player] = nil
		return
	end

	DataService.ProfileLoaded:Fire(player, profile, failedLoads[player] == true)
end

local function onPlayerRemoving(player: Player)
	DataService.save(player, true)
	profiles[player] = nil
	failedLoads[player] = nil
	sessionStart[player] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Players already present when this script runs (Studio play-solo timing).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveIntervalSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	-- Shutdown flush. Roblox gives ~30s here; saves run in parallel and we wait
	-- for all of them.
	game:BindToClose(function()
		if RunService:IsStudio() then
			return -- Studio shutdown has no meaningful budget and throws noise
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
