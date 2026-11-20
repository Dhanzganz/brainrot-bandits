-- Brainrot Bandits — server init (src/server/init.server.luau)
-- Wires Config / Factory / World, owns bases, spawner, carry/steal/deliver,
-- shop, economy, rebirth, events, lucky blocks, boss, richest board, admin,
-- DataStore persistence and the BGM playlist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local serverFolder = ServerScriptService:WaitForChild("Server")
local Factory = require(serverFolder:WaitForChild("Factory"))
local World = require(serverFolder:WaitForChild("World"))
-- Effects is optional: if a later session adds Shared/Effects, require it;
-- otherwise all effects go through the FX/SFX remotes below.
local Effects = nil
local effectsMod = shared:FindFirstChild("Effects")
if effectsMod then
	local ok, mod = pcall(require, effectsMod)
	if ok then
		Effects = mod
	end
end
local _ = Effects

-- Build the world once, up front.
local world = World.build(workspace)

-- Spawn pad near the richest board, clear of the lane (mirrors the proven
-- build): LoadCharacter needs a real SpawnLocation to land players on.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "BanditSpawn"
spawnPad.Size = Vector3.new(12, 1, 12)
spawnPad.CFrame = CFrame.new(0, 1.12, 44)
spawnPad.Color = Color3.fromRGB(255, 205, 48)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Parent = workspace

-- Remotes ---------------------------------------------------------------
local function getRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local FXEvent = getRemote("FXEvent")
local SFXEvent = getRemote("SFXEvent")
local AdminEvent = getRemote("AdminEvent")
local ShopBuy = getRemote("ShopBuy")

ReplicatedStorage:SetAttribute("EventText", "")
ReplicatedStorage:SetAttribute("EventKind", "")
ReplicatedStorage:SetAttribute("EventEndsAt", 0)
ReplicatedStorage:SetAttribute("BaseClockTime", 13.5)
ReplicatedStorage:SetAttribute("RushHourEndsAt", 0)
ReplicatedStorage:SetAttribute("BossHP", -1)

-- BGM playlist ----------------------------------------------------------
local BGMusic = Instance.new("Sound")
BGMusic.Name = "BGMusic"
BGMusic.Volume = 0.35
BGMusic.Parent = SoundService

local SONG_IDS = { 1843404009, 9044702906, 5410086218 }
task.spawn(function()
	while true do
		for _, id in ipairs(SONG_IDS) do
			BGMusic.SoundId = "rbxassetid://" .. tostring(id)
			BGMusic:Play()
			-- Skip a track that does not load within ~8 seconds.
			local loaded = false
			for _ = 1, 80 do
				task.wait(0.1)
				if BGMusic.IsLoaded then
					loaded = true
					break
				end
			end
			if loaded then
				BGMusic.Ended:Wait()
			else
				task.wait(0.5)
			end
		end
	end
end)

-- Constants from Config -------------------------------------------------
local START_CASH = Config.StartingCash
local LANE_START_X = Config.Lane.FromX
local LANE_END_X = Config.Lane.ToX
local LANE_Z = Config.Lane.Z
local LANE_WIDTH = Config.Lane.Width
local LANE_WALK_SECONDS = Config.Lane.WalkTime
local MAX_LANE = Config.Lane.MaxOnLane
local SPAWN_INTERVAL = Config.Lane.SpawnInterval
local LANE_MIN_GAP = 7 -- minimum studs of travel between consecutive lane walkers
local REBIRTH_COSTS = Config.RebirthCosts
local BOSS_HEALTH = Config.BossHealth
local EVENT_DURATION = Config.EventDuration
local EVENTS_INTERVAL = Config.Events.Interval
local DOUBLE_DURATION = Config.Events.DoubleDuration
local EVENT_ROTATION = Config.Events.Rotation
local CARRY_SLOWDOWN = Config.CarrySlowMultiplier
local DATASTORE_NAME = "BrainrotBandits_v1"

local SHOP_SPEED_PRICES = { 500, 1500, 4000 } -- +4 walk speed per level, max 3
local SHOP_GLOVE_PRICE = 2500 -- one-time, slap x2
local SHOP_LUCK_PRICES = { 5000, 12000 } -- +8% luck per level, max 2
local LUCKY_COOLDOWN = 60
local ROOT_STAND_Y = 2.6 -- Root part height above the ground when standing
local CARRY_OFFSET_Y = 3.4 -- carried model height above the carrier's head
local STEAL_DEBOUNCE = 1
local BOSS_SLAP_DAMAGE = 5
local BOSS_TIMEOUT = 180

-- Exact stand height for a unit model: Factory measures each model's true
-- ground clearance at build time (the "GroundClearance" attribute); the
-- fixed ROOT_STAND_Y above is only a fallback for models built without it.
local function standClearance(model)
	local clearance = model and model:GetAttribute("GroundClearance")
	if type(clearance) == "number" then
		return clearance
	end
	return ROOT_STAND_Y
end

-- Rarity helpers --------------------------------------------------------
local RARITY_ORDER = {}
for name, info in pairs(Config.Rarities) do
	table.insert(RARITY_ORDER, { name = name, order = info.Order or 99 })
end
table.sort(RARITY_ORDER, function(a, b)
	return a.order < b.order
end)
local RARITY_NAMES = {}
for _, entry in ipairs(RARITY_ORDER) do
	table.insert(RARITY_NAMES, entry.name)
end

local function rarityIndex(name)
	for i, n in ipairs(RARITY_NAMES) do
		if n == name then
			return i
		end
	end
	return 1
end

local CHARS_BY_RARITY = {}
for _, def in pairs(Config.Characters) do
	local r = def.Rarity
	CHARS_BY_RARITY[r] = CHARS_BY_RARITY[r] or {}
	table.insert(CHARS_BY_RARITY[r], def)
end

local function randomCharDef(rarity)
	local list = CHARS_BY_RARITY[rarity]
	if not list or #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function rollRarityMin(minIdx)
	local total = 0
	for i = minIdx, #RARITY_NAMES do
		total += (Config.SpawnWeights[RARITY_NAMES[i]] or 0)
	end
	if total <= 0 then
		return RARITY_NAMES[#RARITY_NAMES]
	end
	local roll = math.random() * total
	local acc = 0
	for i = minIdx, #RARITY_NAMES do
		acc += (Config.SpawnWeights[RARITY_NAMES[i]] or 0)
		if roll <= acc then
			return RARITY_NAMES[i]
		end
	end
	return RARITY_NAMES[#RARITY_NAMES]
end

local function rollRarity()
	return rollRarityMin(1)
end

-- Golden event def: a shallow clone of an existing character def with a
-- bargain price, multiplied income and a gold tint (honored by Factory).
local function goldenDefFrom(baseDef)
	if not baseDef then
		return nil
	end
	local def = table.clone(baseDef)
	def.Name = "GOLDEN " .. baseDef.Name
	def.Price = Config.Events.GoldenPrice
	def.Income = baseDef.Income * Config.Events.GoldenIncomeMult
	def.Tint = Color3.fromRGB(255, 190, 40)
	return def
end

local function randomGoldenDef()
	local rarity = math.random(1, 2) == 1 and "Epic" or "Legendary"
	local baseDef = randomCharDef(rarity) or randomCharDef("Rare")
	return goldenDefFrom(baseDef)
end

-- State -----------------------------------------------------------------
local playerData = {} -- [Player] = data table
local baseMembers = {} -- [baseIndex] = { Players }
local baseMarkers = {} -- [baseIndex] = BillboardGui
for i = 1, 6 do
	baseMembers[i] = {}
end
local laneChars = {} -- { {model, t0} }
local danceSet = {} -- [Model] = { next, until, dancing }
local boss = nil -- { model, hp, max, lastHit = { [Player] = clock } }
local currentEvent = nil -- "Rainbow" | "Mythic" | nil
local eventEndsAt = 0
local eventToken = 0 -- bumped on every event start/end; invalidates stale timed-end timers (same pattern as doubleToken)
local incomeMult = 1 -- 2 while a Double Income fun event is running
local doubleToken = 0 -- invalidates stale Double Income end timers
local doubleActive = false -- a Double Income window is open
local rushActive = false -- an admin Rush Hour is running
local rushToken = 0 -- invalidates stale Rush Hour end timers
local spawnIntervalNow = SPAWN_INTERVAL -- halved while Rush Hour runs
-- The income multiplier is 2 while EITHER Double Income or Rush Hour
-- is open, and never stacks past 2 — the two windows compose here,
-- in exactly one place, instead of fighting over incomeMult.
local function updateIncomeMult()
	incomeMult = (doubleActive or rushActive) and 2 or 1
end
local lastAdminEventAt = {} -- [Player] = os.clock() of last admin event action

-- Small helpers ---------------------------------------------------------
local function setText(inst, text)
	if not inst then
		return
	end
	pcall(function()
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			inst.Text = text
		elseif inst:IsA("StringValue") then
			inst.Value = text
		end
	end)
end

-- Ground height at a position. Never assume the floor is at y = 0:
-- lane 0.9, plaza 0.62, grass 0.5.
local function groundHeightAt(pos)
	if math.abs(pos.Z - LANE_Z) <= LANE_WIDTH / 2 and pos.X >= LANE_START_X and pos.X <= LANE_END_X then
		return 0.9
	elseif math.abs(pos.X) <= 25 and pos.Z >= -12 and pos.Z <= 40 then
		return 0.62
	else
		return 0.5
	end
end

local function sfx(player, name)
	pcall(function()
		SFXEvent:FireClient(player, name)
	end)
end

local function sfxAll(name)
	pcall(function()
		SFXEvent:FireAllClients(name)
	end)
end

local function fx(player, name, pos)
	pcall(function()
		FXEvent:FireClient(player, name, pos)
	end)
end

local function fxAll(name, pos)
	pcall(function()
		FXEvent:FireAllClients(name, pos)
	end)
end

local function getPrompt(model, name)
	local root = model.PrimaryPart
	if root then
		return root:FindFirstChild(name)
	end
	return nil
end

local function setPrompts(model, claimOn, sellOn, takeOn, shopOn)
	local c = getPrompt(model, "ClaimPrompt")
	if c then
		c.Enabled = claimOn
	end
	local s = getPrompt(model, "SellPrompt")
	if s then
		s.Enabled = sellOn
	end
	local t = getPrompt(model, "TakePrompt")
	if t then
		t.Enabled = takeOn
	end
	local sh = getPrompt(model, "ShopSellPrompt")
	if sh then
		sh.Enabled = shopOn
	end
end

local function ensurePrompt(host, actionText, objectText, hold)
	if not host then
		return nil
	end
	if host:IsA("ProximityPrompt") then
		return host
	end
	local target = nil
	if host:IsA("BasePart") or host:IsA("Attachment") then
		target = host
	elseif host:IsA("Model") then
		target = host.PrimaryPart or host:FindFirstChildWhichIsA("BasePart", true)
	else
		target = host:FindFirstChildWhichIsA("BasePart", true)
	end
	if not target then
		return nil
	end
	local existing = target:FindFirstChildOfClass("ProximityPrompt")
	if existing then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText or ""
	p.HoldDuration = hold or 0.3
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 14
	p.Parent = target
	return p
end

-- Forward declarations (mutually recursive handlers) --------------------
local saveData
local placeOnPad
local carryModel
local attachCharPrompts
local removeLane
local spawnLaneCharacter
local deliverCharacter
local dropCarried
local startEvent
local endEvent
local spawnBoss
local killBoss
local damageBoss
local giveLuckyReward
local updateBanner
local teleportPlayer
local teleportToBase
local applySave
local onClaim
local onSellPad
local onTakePad
local onShopSell
local registerDance
local unregisterDance
local triggerGolden
local triggerDoubleIncome
local triggerFireworks
local triggerRushHour

-- Player data / economy -------------------------------------------------
local function padIncome(player)
	local data = playerData[player]
	if not data then
		return 0
	end
	local sum = 0
	for _, entry in pairs(data.pads) do
		if entry.model and entry.model.Parent then
			sum += (entry.model:GetAttribute("Income") or 0)
		end
	end
	return sum
end

local function rebirthMult(player)
	local data = playerData[player]
	return Config.GetRebirthMultiplier(data and data.rebirths or 0)
end

local function updateWalkSpeed(player)
	local data = playerData[player]
	if not data then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local speed = (data.speedBoost and 42 or 26) + 4 * data.shop.speed
	if data.carrying then
		speed = speed * CARRY_SLOWDOWN
	end
	hum.WalkSpeed = speed
end

local function syncPlayer(player)
	local data = playerData[player]
	if not data then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local cash = ls:FindFirstChild("Cash")
		if cash then
			cash.Value = math.floor(data.cash)
		end
		local rb = ls:FindFirstChild("Rebirths")
		if rb then
			rb.Value = data.rebirths
		end
	end
	player:SetAttribute("IncomePerSec", math.floor(padIncome(player) * rebirthMult(player)))
	player:SetAttribute("Carrying", data.carrying and (data.carrying:GetAttribute("CharacterName") or "") or "")
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("SpeedBoost", data.speedBoost)
	player:SetAttribute("ShopSpeed", data.shop.speed)
	player:SetAttribute("ShopGlove", data.shop.glove)
	player:SetAttribute("ShopLuck", data.shop.luck)
end

-- DataStore -------------------------------------------------------------
local dataStore = nil
pcall(function()
	dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
end)

saveData = function(player)
	local data = playerData[player]
	if not data or not dataStore then
		return false
	end
	local pads = {}
	for padIndex, entry in pairs(data.pads) do
		if entry.model and entry.model.Parent then
			table.insert(pads, { pad = padIndex, name = entry.name, mutation = entry.mutation or "" })
		end
	end
	local blob = {
		cash = math.floor(data.cash),
		rebirths = data.rebirths,
		pads = pads,
		shop = { speed = data.shop.speed, glove = data.shop.glove, luck = data.shop.luck },
	}
	local ok, err = pcall(function()
		dataStore:SetAsync("player_" .. tostring(player.UserId), blob)
	end)
	if not ok then
		warn("[BrainrotBandits] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

local function loadData(player)
	if not dataStore then
		return nil
	end
	local ok, blob = pcall(function()
		return dataStore:GetAsync("player_" .. tostring(player.UserId))
	end)
	if not ok or type(blob) ~= "table" then
		return nil
	end
	return blob
end

-- Dance registry (pad + dropped only; never lane or carried) -----------
registerDance = function(model)
	danceSet[model] = { next = os.clock() + math.random(20, 40), untilT = 0, dancing = false }
end

unregisterDance = function(model)
	danceSet[model] = nil
end

-- Bases -----------------------------------------------------------------
local function destroyBaseMarker(idx)
	local m = baseMarkers[idx]
	if m then
		m:Destroy()
	end
	baseMarkers[idx] = nil
end

local function createBaseMarker(idx, player)
	destroyBaseMarker(idx)
	local base = world.Bases[idx]
	if not base or not base.Plot then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerMarker"
	gui.Size = UDim2.fromOffset(110, 110)
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = base.Plot
	gui.Parent = base.Plot
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Parent = gui
	local fallback = Instance.new("TextLabel")
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
	fallback.TextColor3 = Color3.fromRGB(255, 255, 255)
	fallback.TextScaled = true
	fallback.Font = Enum.Font.GothamBold
	fallback.Text = string.sub(player.DisplayName, 1, 1)
	fallback.Parent = gui
	baseMarkers[idx] = gui
	-- Headshot loads async; the coloured initial stays as fallback.
	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and typeof(thumb) == "string" and thumb ~= "" and gui.Parent then
			img.Image = thumb
			fallback:Destroy()
		end
	end)
end

local function assignBase(player)
	local idx = nil
	for i = 1, 6 do
		if #baseMembers[i] == 0 then
			idx = i
			break
		end
	end
	if not idx then
		idx = math.random(1, 6) -- all taken: share a random base
	end
	table.insert(baseMembers[idx], player)
	local data = playerData[player]
	data.baseIndex = idx
	local base = world.Bases[idx]
	if base and base.SignLabel then
		setText(base.SignLabel, player.DisplayName .. "'s Base")
	end
	createBaseMarker(idx, player)
	return idx
end

local function releaseBase(player)
	local data = playerData[player]
	if not data or not data.baseIndex then
		return
	end
	local idx = data.baseIndex
	local members = baseMembers[idx]
	for i, p in ipairs(members) do
		if p == player then
			table.remove(members, i)
			break
		end
	end
	local base = world.Bases[idx]
	if #members == 0 then
		if base and base.SignLabel then
			setText(base.SignLabel, "FOR RENT")
		end
		destroyBaseMarker(idx)
	else
		if base and base.SignLabel then
			setText(base.SignLabel, members[1].DisplayName .. "'s Base")
		end
		createBaseMarker(idx, members[1])
	end
end

-- Animation handles -------------------------------------------------------
-- Factory.StartWalk / Factory.PlayIdle return stop functions. Keep them
-- per model (weak keys, so destroyed models clean up on their own) and
-- always stop the previous animation before starting the next: dropping
-- the handles left lane walkers swinging their legs forever after a
-- claim, and stacked one more idle loop on a model at every state
-- transition (pad -> carry -> pad -> ...), each writing root.Position
-- with its own phase.
local animStops = setmetatable({}, { __mode = "k" })
local function stopAnims(model)
	local stops = animStops[model]
	if stops then
		if stops.walk then
			pcall(stops.walk)
		end
		if stops.idle then
			pcall(stops.idle)
		end
		animStops[model] = nil
	end
end
local function startWalkAnim(model)
	stopAnims(model)
	local ok, stop = pcall(Factory.StartWalk, model)
	if ok and type(stop) == "function" then
		animStops[model] = { walk = stop }
	end
end
local function startIdleAnim(model)
	stopAnims(model)
	local ok, stop = pcall(Factory.PlayIdle, model)
	if ok and type(stop) == "function" then
		animStops[model] = { idle = stop }
	end
end

-- Character placement ---------------------------------------------------
placeOnPad = function(model, player, padIndex)
	local data = playerData[player]
	if not data then
		return false
	end
	local base = world.Bases[data.baseIndex]
	if not base or not base.Pads then
		return false
	end
	local padPart = nil
	for _, part in ipairs(base.Pads) do
		if part:GetAttribute("PadIndex") == padIndex then
			padPart = part
			break
		end
	end
	if not padPart then
		return false
	end
	local standY = padPart.Position.Y + padPart.Size.Y / 2 + standClearance(model)
	model:PivotTo(CFrame.new(padPart.Position.X, standY, padPart.Position.Z))
	model:SetAttribute("State", "pad")
	model:SetAttribute("PadId", padIndex)
	model:SetAttribute("Status", "Idle")
	model:SetAttribute("FreeClaim", false)
	startIdleAnim(model)
	setPrompts(model, false, true, true, false)
	local sell = getPrompt(model, "SellPrompt")
	if sell then
		local income = model:GetAttribute("Income") or 0
		sell.ObjectText = "$" .. tostring(math.floor(income * 60 + 0.5))
	end
	registerDance(model)
	return true
end

carryModel = function(player, model)
	local data = playerData[player]
	if not data then
		return
	end
	data.carrying = model
	model:SetAttribute("State", "carried")
	model:SetAttribute("Status", "Idle")
	model:SetAttribute("FreeClaim", false)
	setPrompts(model, false, false, false, false)
	startIdleAnim(model)
	unregisterDance(model)
	updateWalkSpeed(player)
	syncPlayer(player)
end

removeLane = function(model)
	for i, entry in ipairs(laneChars) do
		if entry.model == model then
			table.remove(laneChars, i)
			return
		end
	end
end

-- Proximity guard: ProximityPrompt.Triggered can be fired by exploiters
-- from any distance, so location-bound prompt actions re-check on the
-- server that the player is actually standing next to the target.
local function isNearPart(player, part, maxDist)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not part then
		return false
	end
	return (hrp.Position - part.Position).Magnitude <= maxDist
end

local function isNearModel(player, model, maxDist)
	if not model then
		return false
	end
	return isNearPart(player, model.PrimaryPart or model:FindFirstChild("Root"), maxDist)
end

-- Claim / sell / take / shop-sell ---------------------------------------
onClaim = function(model, player)
	local data = playerData[player]
	if not data then
		return
	end
	if data.carrying then
		sfx(player, "error")
		return
	end
	if not model or not model.Parent then
		return
	end
	if not isNearModel(player, model, 18) then
		return
	end
	local state = model:GetAttribute("State")
	if state ~= "lane" and state ~= "dropped" then
		return
	end
	local free = model:GetAttribute("FreeClaim") == true
	local price = model:GetAttribute("Price") or 0
	if not free and data.cash < price then
		sfx(player, "error")
		return
	end
	-- Jimat Hoki: rolled at lane claim. On success the claimed character
	-- is destroyed and replaced by one rarity tier higher (same mutation).
	if state == "lane" and data.shop.luck > 0 then
		local chance = data.shop.luck * 0.08
		local rarity = model:GetAttribute("Rarity")
		if rarity ~= "Mythic" and math.random() < chance then
			local idx = rarityIndex(rarity)
			local upRarity = RARITY_NAMES[math.min(idx + 1, #RARITY_NAMES)]
			local def = randomCharDef(upRarity)
			if def then
				local mutation = model:GetAttribute("Mutation")
				if mutation == "" then
					mutation = nil
				end
				removeLane(model)
				local newModel = Factory.new(def, mutation, 1)
				newModel:SetAttribute("State", "lane")
				newModel:SetAttribute("Status", "Walking")
				newModel.Parent = workspace
				attachCharPrompts(newModel)
				model:Destroy()
				if not free then
					data.cash -= price
				end
				carryModel(player, newModel)
				sfx(player, "pickup")
				fx(player, "luckUp", newModel:GetPivot().Position)
				syncPlayer(player)
				return
			end
		end
	end
	if not free then
		data.cash -= price
	end
	if state == "lane" then
		removeLane(model)
	end
	-- Anti re-steal: the last owner cannot snatch it straight back.
	if state == "dropped" then
		local lastOwner = model:GetAttribute("LastOwner")
		if lastOwner then
			model:SetAttribute("NoStealFrom", lastOwner)
			model:SetAttribute("NoStealUntil", os.clock() + 5)
		end
	end
	carryModel(player, model)
	sfx(player, "pickup")
	syncPlayer(player)
end

onSellPad = function(model, player)
	local data = playerData[player]
	if not data then
		return
	end
	if not isNearModel(player, model, 18) then
		return
	end
	if model:GetAttribute("State") ~= "pad" then
		return
	end
	local padId = model:GetAttribute("PadId")
	local entry = padId and data.pads[padId]
	if not entry or entry.model ~= model then
		sfx(player, "error")
		return
	end
	local income = model:GetAttribute("Income") or 0
	local price = math.floor(income * 60 + 0.5)
	data.cash += price
	data.pads[padId] = nil
	local pos = model:GetPivot().Position
	unregisterDance(model)
	model:Destroy()
	sfx(player, "cash")
	fx(player, "gold", pos)
	syncPlayer(player)
	saveData(player)
end

onTakePad = function(model, player)
	local data = playerData[player]
	if not data or data.carrying then
		return
	end
	if not isNearModel(player, model, 18) then
		return
	end
	if model:GetAttribute("State") ~= "pad" then
		return
	end
	local padId = model:GetAttribute("PadId")
	local entry = padId and data.pads[padId]
	if not entry or entry.model ~= model then
		return
	end
	data.pads[padId] = nil
	carryModel(player, model)
	sfx(player, "pickup")
end

onShopSell = function(model, player)
	local data = playerData[player]
	if not data then
		return
	end
	if data.carrying ~= model then
		return
	end
	if model:GetAttribute("State") ~= "carried" then
		return
	end
	local income = model:GetAttribute("Income") or 0
	local price = math.floor(income * 60 + 0.5)
	data.cash += price
	data.carrying = nil
	unregisterDance(model)
	model:Destroy()
	sfx(player, "cash")
	updateWalkSpeed(player)
	syncPlayer(player)
	saveData(player)
end

attachCharPrompts = function(model)
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return
	end
	local price = model:GetAttribute("Price") or 0
	local displayName = model:GetAttribute("CharacterName") or "Brainrot"
	local income = model:GetAttribute("Income") or 0

	local claim = Instance.new("ProximityPrompt")
	claim.Name = "ClaimPrompt"
	claim.ActionText = "Claim"
	claim.ObjectText = displayName .. " — $" .. tostring(price)
	claim.HoldDuration = 0.35
	claim.KeyboardKeyCode = Enum.KeyCode.E
	claim.RequiresLineOfSight = false
	claim.MaxActivationDistance = 14
	claim.Parent = root

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Jual"
	sell.ObjectText = "$" .. tostring(math.floor(income * 60 + 0.5))
	sell.HoldDuration = 0.75
	sell.KeyboardKeyCode = Enum.KeyCode.E
	sell.RequiresLineOfSight = false
	sell.MaxActivationDistance = 14
	sell.Enabled = false
	sell.Parent = root

	local take = Instance.new("ProximityPrompt")
	take.Name = "TakePrompt"
	take.ActionText = "Ambil"
	take.ObjectText = displayName
	take.HoldDuration = 0.5
	take.KeyboardKeyCode = Enum.KeyCode.E
	take.RequiresLineOfSight = false
	take.MaxActivationDistance = 14
	take.Enabled = false
	take.Parent = root

	local shopSell = Instance.new("ProximityPrompt")
	shopSell.Name = "ShopSellPrompt"
	shopSell.ActionText = "Jual di Toko"
	shopSell.ObjectText = "$" .. tostring(math.floor(income * 60 + 0.5))
	shopSell.HoldDuration = 0.2
	shopSell.KeyboardKeyCode = Enum.KeyCode.E
	shopSell.RequiresLineOfSight = false
	shopSell.MaxActivationDistance = 14
	shopSell.Enabled = false
	shopSell.Parent = root

	claim.Triggered:Connect(function(p)
		onClaim(model, p)
	end)
	sell.Triggered:Connect(function(p)
		onSellPad(model, p)
	end)
	take.Triggered:Connect(function(p)
		onTakePad(model, p)
	end)
	shopSell.Triggered:Connect(function(p)
		onShopSell(model, p)
	end)
end

-- Spawner ---------------------------------------------------------------
-- The single lane-entry path: every unit on the lane — normal, admin or
-- event — is built and registered here, so downstream claim / carry /
-- deliver logic never special-cases where a unit came from.
local function placeLaneModel(def, mutation)
	if not def then
		return nil
	end
	local model = Factory.new(def, mutation, 1)
	model:SetAttribute("State", "lane")
	model:SetAttribute("Status", "Walking")
	model:SetAttribute("FreeClaim", false)
	model.Parent = workspace
	model:PivotTo(CFrame.new(LANE_START_X, 0.9 + standClearance(model), LANE_Z) * CFrame.Angles(0, math.rad(-90), 0))
	attachCharPrompts(model)
	startWalkAnim(model)
	table.insert(laneChars, { model = model, t0 = os.clock(), dist = 0, clearance = model:GetAttribute("GroundClearance") })
	return model
end

spawnLaneCharacter = function(forceRarity, forceMutation, allowOverCap)
	if not allowOverCap and #laneChars >= MAX_LANE then
		return nil
	end
	local rarity = forceRarity or (currentEvent == "Mythic" and rollRarityMin(3) or rollRarity())
	local def = randomCharDef(rarity)
	if not def then
		return nil
	end
	local mutation = forceMutation
	if mutation == nil then
		if currentEvent == "Rainbow" then
			mutation = "Rainbow"
		else
			local r = math.random()
			if r < 0.02 then
				mutation = "Diamond"
			elseif r < 0.10 then
				mutation = "Gold"
			end
		end
	end
	return placeLaneModel(def, mutation)
end

-- Deliver / steal -------------------------------------------------------
deliverCharacter = function(player)
	local data = playerData[player]
	if not data then
		return
	end
	local model = data.carrying
	if not model or not model.Parent then
		return
	end
	local freePad = nil
	for i = 1, 6 do
		if not data.pads[i] then
			freePad = i
			break
		end
	end
	if not freePad then
		sfx(player, "error")
		return
	end
	data.carrying = nil
	data.pads[freePad] = {
		model = model,
		name = model:GetAttribute("CharacterName") or "",
		mutation = model:GetAttribute("Mutation") or "",
	}
	placeOnPad(model, player, freePad)
	sfx(player, "cash")
	fx(player, "deliver", model:GetPivot().Position)
	updateWalkSpeed(player)
	syncPlayer(player)
	saveData(player)
end

dropCarried = function(victim, stealer)
	local data = playerData[victim]
	if not data then
		return
	end
	local model = data.carrying
	if not model or not model.Parent then
		return
	end
	local char = victim.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local dropPos = Vector3.new(0, 3, 0)
	if hrp then
		dropPos = hrp.Position + hrp.CFrame.LookVector * 3
	end
	local y = groundHeightAt(dropPos) + standClearance(model)
	model:PivotTo(CFrame.new(dropPos.X, y, dropPos.Z))
	model:SetAttribute("State", "dropped")
	model:SetAttribute("Status", "Idle")
	model:SetAttribute("FreeClaim", true)
	model:SetAttribute("LastOwner", victim.UserId)
	data.carrying = nil
	setPrompts(model, true, false, false, false)
	startIdleAnim(model)
	registerDance(model)
	updateWalkSpeed(victim)
	syncPlayer(victim)
	sfx(victim, "slap")
	if stealer then
		sfx(stealer, "slap")
	end
	fx(victim, "Shake", Vector3.new(dropPos.X, y, dropPos.Z))
end

-- Boss ------------------------------------------------------------------
killBoss = function()
	if not boss then
		return
	end
	local model = boss.model
	local income = model:GetAttribute("Income") or 0
	local pos = model:GetPivot().Position
	model:Destroy()
	boss = nil
	ReplicatedStorage:SetAttribute("BossHP", -1)
	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerData[player]
		if data then
			data.cash += income * rebirthMult(player) * 5
			syncPlayer(player)
		end
	end
	sfxAll("boss")
	fxAll("bossBoom", pos)
end

damageBoss = function(player)
	if not boss or not boss.model or not boss.model.Parent then
		return
	end
	local now = os.clock()
	if boss.lastHit[player] and now - boss.lastHit[player] < 0.6 then
		return
	end
	boss.lastHit[player] = now
	local dmg = BOSS_SLAP_DAMAGE
	local data = playerData[player]
	if data and data.shop.glove then
		dmg = dmg * 2 -- Sarung Tinju Baja doubles slap power
	end
	boss.hp -= dmg
	ReplicatedStorage:SetAttribute("BossHP", math.max(boss.hp / boss.max, 0))
	sfx(player, "slap")
	if boss.hp <= 0 then
		killBoss()
	end
end

spawnBoss = function()
	if boss and boss.model and boss.model.Parent then
		return
	end
	local def = Config.GetCharacter("Tung Tung Sahur")
	if not def then
		def = randomCharDef("Legendary")
	end
	if not def then
		return
	end
	local model = Factory.new(def, nil, 6)
	model:SetAttribute("State", "boss")
	model:SetAttribute("Status", "Idle")
	model.Parent = workspace
	local y = groundHeightAt(Vector3.new(0, 0, 0)) + standClearance(model)
	model:PivotTo(CFrame.new(0, y, 0))
	-- Nightmare restyle (appearance only — HP, damage, rewards and the
	-- timeout below are untouched): charcoal body, blood-red accents,
	-- glowing red eyes, horns, a dark smoke aura and a scary nameplate.
	local bossRoot = model.PrimaryPart
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "EyeL" or part.Name == "EyeR" then
				part.Color = Color3.fromRGB(255, 35, 35)
				part.Material = Enum.Material.Neon
				part.Size = part.Size * 1.5
			elseif part.Color == def.BodyColor then
				part.Color = Color3.fromRGB(66, 60, 78)
			elseif part.Color == def.AccentColor then
				part.Color = Color3.fromRGB(120, 18, 24)
			else
				local lum = 0.299 * part.Color.R + 0.587 * part.Color.G + 0.114 * part.Color.B
				if lum > 0.55 then
					part.Color = Color3.fromRGB(70, 14, 18)
				elseif lum < 0.12 then
					-- Near-black parts (horns, dark trim) read as a black
					-- blob against the sky; lift them to a dark slate.
					part.Color = Color3.fromRGB(48, 42, 58)
				end
			end
		end
	end
	if bossRoot then
		local bossLight = Instance.new("PointLight")
		bossLight.Color = Color3.fromRGB(255, 45, 45)
		bossLight.Brightness = 1
		bossLight.Range = 10
		bossLight.Parent = bossRoot
		for _, sideSign in ipairs({ -1, 1 }) do
			local horn = Instance.new("Part")
			horn.Name = "BossHorn"
			horn.Size = Vector3.new(1.6, 3.2, 1.6)
			horn.Color = Color3.fromRGB(18, 16, 20)
			horn.Material = Enum.Material.SmoothPlastic
			horn.Anchored = true
			horn.CanCollide = false
			horn.CanTouch = false
			horn.CanQuery = false
			local hornMesh = Instance.new("SpecialMesh")
			hornMesh.MeshType = Enum.MeshType.FileMesh
			hornMesh.MeshId = "rbxassetid://1033714"
			hornMesh.Scale = Vector3.new(1.5, 3, 1.5)
			hornMesh.Parent = horn
			horn.CFrame = CFrame.new(bossRoot.Position + Vector3.new(sideSign * 0.6 * 6, 1.5 * 6, -0.2 * 6))
				* CFrame.Angles(0, 0, math.rad(sideSign * -12))
			horn.Parent = model
		end
		local aura = Instance.new("Smoke")
		aura.Name = "BossAura"
		aura.Color = Color3.fromRGB(140, 25, 30)
		aura.Opacity = 0.3
		aura.Size = 7
		aura.RiseVelocity = 2.5
		aura.Parent = bossRoot
		local plate = bossRoot:FindFirstChild("Nameplate")
		local nameLabel = plate and plate:FindFirstChild("NameLabel")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = "☠ NIGHTMARE " .. def.Name
			nameLabel.TextColor3 = Color3.fromRGB(255, 45, 45)
		end
	end
	startIdleAnim(model)
	boss = { model = model, hp = BOSS_HEALTH, max = BOSS_HEALTH, lastHit = {} }
	ReplicatedStorage:SetAttribute("BossHP", 1)
	sfxAll("boss")
	fxAll("bossSpawn", model:GetPivot().Position)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(otherPart)
				local player = Players:GetPlayerFromCharacter(otherPart.Parent)
				if player then
					damageBoss(player)
				end
			end)
		end
	end
	task.delay(BOSS_TIMEOUT, function()
		if boss and boss.model == model then
			model:Destroy()
			boss = nil
			ReplicatedStorage:SetAttribute("BossHP", -1)
		end
	end)
end

-- Lucky Blocks ----------------------------------------------------------
giveLuckyReward = function(player)
	local data = playerData[player]
	if not data then
		return
	end
	local freePad = nil
	for i = 1, 6 do
		if not data.pads[i] then
			freePad = i
			break
		end
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pos = hrp and hrp.Position or Vector3.new(0, 3, 0)
	if freePad and math.random() < 0.5 then
		local def = randomCharDef(rollRarity())
		if def then
			local model = Factory.new(def, nil, 1)
			model.Parent = workspace
			attachCharPrompts(model)
			data.pads[freePad] = { model = model, name = def.Name, mutation = "" }
			placeOnPad(model, player, freePad)
			sfx(player, "lucky")
			fx(player, "lucky", model:GetPivot().Position)
			syncPlayer(player)
			saveData(player)
			return
		end
	end
	local amount = math.random(100, 1000) * (1 + data.rebirths)
	data.cash += amount
	sfx(player, "lucky")
	fx(player, "luckyCash", pos)
	syncPlayer(player)
	saveData(player)
end

-- Events + banner -------------------------------------------------------
-- Event lighting is owned by the client: Hud watches the EventKind
-- attribute and Effects.StartEventFX / StopEventFX apply and restore
-- the event look from the client's own snapshot. The server used to
-- also write Lighting.Ambient / FogColor here and restore a boot-time
-- snapshot on endEvent — two owners with different palettes, and the
-- replicated server restore could stomp the client's base look after
-- every event. These handlers now only publish state (attributes,
-- banner, sfx/fx); they never touch Lighting.

updateBanner = function()
	local archText = "BRAINROT BANDITS"
	if currentEvent == "Rainbow" then
		archText = "🌈 RAINBOW RUSH!"
	elseif currentEvent == "Mythic" then
		archText = "👑 MYTHIC HUNT!"
	end
	setText(world.ArchLabel, archText)
	if world.BannerLabels then
		if world.BannerLabels[1] then
			setText(world.BannerLabels[1], archText)
		end
		if world.BannerLabels[2] then
			setText(world.BannerLabels[2], "BRAINROT BANDITS")
		end
	end
end

startEvent = function(kind)
	eventToken += 1
	currentEvent = kind
	eventEndsAt = os.clock() + EVENT_DURATION
	ReplicatedStorage:SetAttribute("EventKind", kind)
	if kind == "Rainbow" then
		ReplicatedStorage:SetAttribute("EventText", "🌈 RAINBOW RUSH — all spawns Rainbow x10!")
	else
		ReplicatedStorage:SetAttribute("EventText", "👑 MYTHIC HUNT — Epic+ spawns only!")
	end
	ReplicatedStorage:SetAttribute("EventEndsAt", os.time() + EVENT_DURATION)
	updateBanner()
	sfxAll("event")
	fxAll(kind == "Rainbow" and "rainbowStart" or "mythicStart", nil)
	return eventToken
end

endEvent = function()
	eventToken += 1
	currentEvent = nil
	ReplicatedStorage:SetAttribute("EventKind", "")
	ReplicatedStorage:SetAttribute("EventText", "")
	ReplicatedStorage:SetAttribute("EventEndsAt", 0)
	updateBanner()
end

-- Teleport --------------------------------------------------------------
teleportPlayer = function(player, pos)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(pos)
	end
end

teleportToBase = function(player)
	local data = playerData[player]
	if not data or not data.baseIndex then
		return
	end
	local cf = Config.GetBaseCFrame(data.baseIndex)
	local pos = cf.Position
	local dir = Vector3.new(-pos.X, 0, -pos.Z)
	if dir.Magnitude > 0.01 then
		dir = dir.Unit
	else
		dir = Vector3.new(0, 0, 1)
	end
	teleportPlayer(player, pos + dir * 10 + Vector3.new(0, 3, 0))
end

-- Save restore ----------------------------------------------------------
applySave = function(player, blob)
	local data = playerData[player]
	if not data or not blob then
		return
	end
	if typeof(blob.cash) == "number" then
		data.cash = blob.cash
	end
	if typeof(blob.rebirths) == "number" then
		data.rebirths = blob.rebirths
	end
	if type(blob.shop) == "table" then
		data.shop.speed = blob.shop.speed or 0
		data.shop.glove = blob.shop.glove == true
		data.shop.luck = blob.shop.luck or 0
	end
	if type(blob.pads) == "table" then
		for _, saved in ipairs(blob.pads) do
			local padIndex = saved.pad
			local def = saved.name and Config.GetCharacter(saved.name) or nil
			if not def and saved.name and string.sub(saved.name, 1, 7) == "GOLDEN " then
				-- Golden event units are runtime defs, not Config entries:
				-- rebuild the golden def from its base character.
				def = goldenDefFrom(Config.GetCharacter(string.sub(saved.name, 8)))
			end
			if def and padIndex and padIndex >= 1 and padIndex <= 6 and not data.pads[padIndex] then
				local mutation = saved.mutation
				if mutation == "" then
					mutation = nil
				end
				local model = Factory.new(def, mutation, 1)
				model.Parent = workspace
				attachCharPrompts(model)
				data.pads[padIndex] = { model = model, name = def.Name, mutation = saved.mutation or "" }
				placeOnPad(model, player, padIndex)
			end
		end
	end
	syncPlayer(player)
end

-- Character wiring (steal touch, respawn reload) ------------------------
local function wireCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if hum then
		updateWalkSpeed(player)
		hum.Died:Connect(function()
			task.wait(1)
			if player.Parent then
				pcall(function()
					player:LoadCharacter()
				end)
			end
		end)
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		hrp.Touched:Connect(function(otherPart)
			local otherPlayer = Players:GetPlayerFromCharacter(otherPart.Parent)
			if not otherPlayer or otherPlayer == player then
				return
			end
			local victimData = playerData[player]
			local stealerData = playerData[otherPlayer]
			if not victimData or not stealerData then
				return
			end
			if not victimData.carrying then
				return
			end
			if stealerData.carrying then
				return
			end
			local now = os.clock()
			if victimData.lastStealAt and now - victimData.lastStealAt < STEAL_DEBOUNCE then
				return
			end
			local model = victimData.carrying
			local noFrom = model:GetAttribute("NoStealFrom")
			local noUntil = model:GetAttribute("NoStealUntil") or 0
			if noFrom == otherPlayer.UserId and now < noUntil then
				return
			end
			victimData.lastStealAt = now
			dropCarried(player, otherPlayer)
		end)
	end
end

-- Player lifecycle ------------------------------------------------------
local function onPlayerAdded(player)
	local data = {
		cash = START_CASH,
		rebirths = 0,
		pads = {},
		carrying = nil,
		baseIndex = nil,
		shop = { speed = 0, glove = false, luck = 0 },
		speedBoost = false,
		lastStealAt = 0,
		lastDeliverAt = 0,
		luckyAt = {},
	}
	playerData[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashVal = Instance.new("IntValue")
	cashVal.Name = "Cash"
	cashVal.Value = START_CASH
	cashVal.Parent = leaderstats
	local rbVal = Instance.new("IntValue")
	rbVal.Name = "Rebirths"
	rbVal.Value = 0
	rbVal.Parent = leaderstats
	leaderstats.Parent = player

	player:SetAttribute("IncomePerSec", 0)
	player:SetAttribute("Carrying", "")
	player:SetAttribute("Rebirths", 0)
	player:SetAttribute("SpeedBoost", false)
	player:SetAttribute("ShopSpeed", 0)
	player:SetAttribute("ShopGlove", false)
	player:SetAttribute("ShopLuck", 0)

	assignBase(player)
	local blob = loadData(player)
	if blob then
		applySave(player, blob)
	end
	syncPlayer(player)

	player.CharacterAdded:Connect(function(char)
		wireCharacter(player, char)
	end)
	-- CharacterAutoLoads is off: load explicitly, and again on every respawn
	-- (wireCharacter reloads after Humanoid.Died).
	task.spawn(function()
		pcall(function()
			player:LoadCharacter()
		end)
	end)
end

local function onPlayerRemoving(player)
	local data = playerData[player]
	if data then
		-- A carried character is destroyed, never saved.
		if data.carrying and data.carrying.Parent then
			data.carrying:Destroy()
		end
		data.carrying = nil
		saveData(player)
		-- Pad units are rebuilt from the save on rejoin; destroy the
		-- live models (after saving — saveData reads their Parent) so
		-- they don't linger on the base for its next owner, dancing
		-- forever and duplicating when this player returns.
		for _, entry in pairs(data.pads) do
			if entry.model and entry.model.Parent then
				unregisterDance(entry.model)
				entry.model:Destroy()
			end
		end
		data.pads = {}
		releaseBase(player)
	end
	playerData[player] = nil
	lastAdminEventAt[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		saveData(p)
	end
end)

-- World wiring: delivery zones, shop zone, shrine, lucky stands --------
for i, base in ipairs(world.Bases) do
	local function tryDeliver(otherPart)
		local player = Players:GetPlayerFromCharacter(otherPart.Parent)
		if not player then
			return
		end
		local data = playerData[player]
		if not data or not data.carrying then
			return
		end
		if data.baseIndex ~= i then
			return
		end
		local now = os.clock()
		if data.lastDeliverAt and now - data.lastDeliverAt < 1 then
			return
		end
		data.lastDeliverAt = now
		deliverCharacter(player)
	end
	if base.DeliveryZone then
		base.DeliveryZone.Touched:Connect(tryDeliver)
	end
	-- Forgiving delivery: stepping on any of your own pads also delivers.
	if base.Pads then
		for _, pad in ipairs(base.Pads) do
			pad.Touched:Connect(tryDeliver)
		end
	end
end

if world.ShopZone then
	world.ShopZone.Touched:Connect(function(otherPart)
		local player = Players:GetPlayerFromCharacter(otherPart.Parent)
		if not player then
			return
		end
		local data = playerData[player]
		if not data or not data.carrying then
			return
		end
		local prompt = getPrompt(data.carrying, "ShopSellPrompt")
		if prompt then
			local income = data.carrying:GetAttribute("Income") or 0
			prompt.ObjectText = "$" .. tostring(math.floor(income * 60 + 0.5))
			prompt.Enabled = true
		end
	end)
	world.ShopZone.TouchEnded:Connect(function(otherPart)
		local player = Players:GetPlayerFromCharacter(otherPart.Parent)
		if not player then
			return
		end
		local data = playerData[player]
		if not data or not data.carrying then
			return
		end
		local prompt = getPrompt(data.carrying, "ShopSellPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end)
end

local shopPrompt = ensurePrompt(world.ShopPrompt, "Toko", "Sepatu Kilat • Sarung Tinju • Jimat Hoki", 0.3)
if shopPrompt then
	shopPrompt.Triggered:Connect(function(player)
		local data = playerData[player]
		if not data then
			return
		end
		FXEvent:FireClient(player, "openShop", {
			speed = data.shop.speed,
			glove = data.shop.glove,
			luck = data.shop.luck,
			cash = math.floor(data.cash),
			speedPrices = SHOP_SPEED_PRICES,
			glovePrice = SHOP_GLOVE_PRICE,
			luckPrices = SHOP_LUCK_PRICES,
		})
	end)
end

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local grouped = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local shrinePrompt = ensurePrompt(world.ShrinePrompt, "Rebirth", "Rebirth · $" .. withCommas(REBIRTH_COSTS[1]), 0.5)
if shrinePrompt then
	shrinePrompt.ObjectText = "Rebirth · $" .. withCommas(REBIRTH_COSTS[1])
	shrinePrompt.Triggered:Connect(function(player)
		local data = playerData[player]
		if not data then
			return
		end
		local cost = REBIRTH_COSTS[data.rebirths + 1]
		if not cost then
			sfx(player, "error")
			return
		end
		if data.cash < cost then
			sfx(player, "error")
			return
		end
		data.cash = START_CASH
		data.rebirths += 1
		syncPlayer(player)
		sfx(player, "rebirth")
		fx(player, "rebirth", Vector3.new(0, 3, 34))
		if shrinePrompt:IsA("ProximityPrompt") then
			local nextCost = REBIRTH_COSTS[data.rebirths + 1]
			if nextCost then
				shrinePrompt.ObjectText = "Rebirth · $" .. withCommas(nextCost)
			else
				shrinePrompt.ObjectText = "Rebirth — now x" .. tostring(1 + data.rebirths)
			end
		end
		saveData(player)
	end)
end

if world.LuckyStands then
	for idx, stand in ipairs(world.LuckyStands) do
		local prompt = ensurePrompt(stand.Prompt, "Lucky Block", "Free reward!", 0.5)
		if prompt then
			prompt.Triggered:Connect(function(player)
				local data = playerData[player]
				if not data then
					return
				end
				if not isNearPart(player, stand.Counter, 16) then
					return
				end
				local now = os.clock()
				if data.luckyAt[idx] and now - data.luckyAt[idx] < LUCKY_COOLDOWN then
					sfx(player, "error")
					return
				end
				data.luckyAt[idx] = now
				giveLuckyReward(player)
			end)
		end
	end
end

-- Shop purchases (full server-side validation from player data) ---------
ShopBuy.OnServerEvent:Connect(function(player, item)
	local data = playerData[player]
	if not data then
		return
	end
	if item == "Speed" then
		local level = data.shop.speed
		if level >= 3 then
			sfx(player, "error")
			return
		end
		local price = SHOP_SPEED_PRICES[level + 1]
		if data.cash < price then
			sfx(player, "error")
			return
		end
		data.cash -= price
		data.shop.speed = level + 1
	elseif item == "Glove" then
		if data.shop.glove then
			sfx(player, "error")
			return
		end
		if data.cash < SHOP_GLOVE_PRICE then
			sfx(player, "error")
			return
		end
		data.cash -= SHOP_GLOVE_PRICE
		data.shop.glove = true
	elseif item == "Luck" then
		local level = data.shop.luck
		if level >= 2 then
			sfx(player, "error")
			return
		end
		local price = SHOP_LUCK_PRICES[level + 1]
		if data.cash < price then
			sfx(player, "error")
			return
		end
		data.cash -= price
		data.shop.luck = level + 1
	else
		return
	end
	updateWalkSpeed(player)
	syncPlayer(player)
	sfx(player, "buy")
	saveData(player)
end)

-- Admin (every action re-checked with Config.IsAdmin) -------------------
-- Every handled action answers the acting admin with a feedback toast
-- (fx kinds "adminToast" / "adminToastFail") so a tap never lands in
-- silence; unknown actions and debounce-blocked taps get a red toast.
-- Announcement presets live server-side so clients can only pick one of
-- the three canned broadcasts, never free text.
local ANNOUNCE_PRESETS = {
	announce1 = "🎉 EVENT STARTING SOON!",
	announce2 = "☠ A BOSS IS COMING…",
	announce3 = "⭐ GOLDEN HOUR — RARE SPAWNS!",
}
AdminEvent.OnServerEvent:Connect(function(player, action)
	if not Config.IsAdmin(player) then
		return
	end
	local data = playerData[player]
	local handled = false
	local function toast(text)
		fx(player, "adminToast", text)
	end
	local function toastFail(text)
		fx(player, "adminToastFail", text)
	end
	-- Manual event controls: the same trigger functions the automatic
	-- loops use, behind one shared 5s per-admin debounce.
	if action == "spawnGolden" or action == "doubleIncome" or action == "giveCash1000" or action == "fireworks" or action == "rushHour" or action == "cashRain" or ANNOUNCE_PRESETS[action] then
		local now = os.clock()
		if lastAdminEventAt[player] and now - lastAdminEventAt[player] < 5 then
			toastFail("✗ Too fast — 5s cooldown")
			return
		end
		lastAdminEventAt[player] = now
		if action == "spawnGolden" then
			task.spawn(triggerGolden)
			toast("✓ Golden brainrot spawned")
		elseif action == "doubleIncome" then
			triggerDoubleIncome()
			toast("✓ Double income — 30 seconds")
		elseif ANNOUNCE_PRESETS[action] then
			fxAll("announce", ANNOUNCE_PRESETS[action])
			toast("✓ Announcement sent")
		elseif action == "giveCash1000" then
			if data then
				data.cash += 1000
				syncPlayer(player)
				toast("✓ +$1,000")
			else
				toastFail("✗ Action failed")
			end
		elseif action == "fireworks" then
			task.spawn(triggerFireworks)
			toast("✓ Fireworks")
		elseif action == "rushHour" then
			triggerRushHour()
			toast("✓ Rush Hour — 60 seconds")
		elseif action == "cashRain" then
			-- Every player in the server gets +500, each with their
			-- own income popup; the banner goes to everyone.
			for _, p in ipairs(Players:GetPlayers()) do
				local pdata = playerData[p]
				if pdata then
					pdata.cash += 500
					syncPlayer(p)
					fx(p, "incomePopup", 500)
				end
			end
			fxAll("announce", "💸 CASH RAIN! +500 FOR EVERYONE")
			toast("✓ Cash rain: +$500 for everyone")
		end
		return
	end
	if action == "addCash10k" then
		if data then
			data.cash += 10000
			syncPlayer(player)
			handled = "✓ +$10,000"
		end
	elseif action == "addCash1m" then
		if data then
			data.cash += 1000000
			syncPlayer(player)
			handled = "✓ +$1,000,000"
		end
	elseif action == "spawnLegendary" then
		spawnLaneCharacter("Legendary", nil, true)
		handled = "✓ Legendary spawned"
	elseif action == "spawnMythic" then
		spawnLaneCharacter("Mythic", nil, true)
		handled = "✓ Mythic spawned"
	elseif action == "spawnDiamond" then
		spawnLaneCharacter(nil, "Diamond", true)
		handled = "✓ Diamond spawned"
	elseif action == "spawn5" then
		for _ = 1, 5 do
			spawnLaneCharacter(nil, nil, true)
		end
		handled = "✓ 5 random spawned"
	elseif action == "startRainbow" then
		startEvent("Rainbow")
		handled = "✓ Rainbow event started"
	elseif action == "startMythic" then
		startEvent("Mythic")
		handled = "✓ Mythic event started"
	elseif action == "spawnBoss" then
		local hadBoss = boss ~= nil
		spawnBoss()
		if not hadBoss and boss then
			handled = "✓ Boss spawned"
		elseif hadBoss then
			toastFail("✗ Boss already active")
			return
		else
			toastFail("✗ Boss spawn failed")
			return
		end
	elseif action == "endEvent" then
		endEvent()
		handled = "✓ Event ended"
	elseif action == "toggleSpeed" then
		if data then
			data.speedBoost = not data.speedBoost
			updateWalkSpeed(player)
			syncPlayer(player)
			handled = data.speedBoost and "✓ Speed boost ON" or "✓ Speed boost OFF"
		end
	elseif action == "addRebirth" then
		if data then
			data.rebirths += 1
			syncPlayer(player)
			saveData(player)
			handled = "✓ +1 Rebirth"
		end
	elseif action == "tpBase" then
		teleportToBase(player)
		handled = "✓ Teleported to base"
	elseif action == "tpLane" then
		teleportPlayer(player, Vector3.new(LANE_START_X, 3.5, LANE_Z))
		handled = "✓ Teleported to lane"
	elseif action == "toggleDayNight" then
		-- Base-time override only: the attribute is what clients' Effects
		-- BASE look reads, so event looks still override while active and
		-- the flip back restores this base time, not a hard-coded one.
		local current = ReplicatedStorage:GetAttribute("BaseClockTime") or 0.2
		local nextTime = (current == 14) and 0.2 or 14
		ReplicatedStorage:SetAttribute("BaseClockTime", nextTime)
		Lighting.ClockTime = nextTime
		handled = nextTime == 14 and "✓ Day mode" or "✓ Night mode"
	end
	if handled then
		toast(handled)
	else
		toastFail("✗ Action failed")
	end
end)

-- Heartbeat: lane walking, despawn at lane end, carry follow ------------
local lastLaneTick = nil
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local dt = lastLaneTick and (now - lastLaneTick) or 0
	lastLaneTick = now
	local laneLength = LANE_END_X - LANE_START_X
	local laneSpeed = laneLength / LANE_WALK_SECONDS
	-- Each walker advances its own travel distance, clamped to stay at
	-- least LANE_MIN_GAP studs behind the walker ahead of it, so units
	-- can never catch up, overlap, or stack their nameplates.
	local leaderDist = nil
	local i = 1
	while i <= #laneChars do
		local entry = laneChars[i]
		local model = entry.model
		if not model or not model.Parent then
			table.remove(laneChars, i)
		else
			entry.dist = (entry.dist or 0) + laneSpeed * dt
			if leaderDist then
				entry.dist = math.max(0, math.min(entry.dist, leaderDist - LANE_MIN_GAP))
			end
			if entry.dist >= laneLength then
				model:Destroy()
				table.remove(laneChars, i)
			else
				local x = LANE_START_X + entry.dist
				model:PivotTo(CFrame.new(x, 0.9 + (entry.clearance or standClearance(model)), LANE_Z) * CFrame.Angles(0, math.rad(-90), 0))
				leaderDist = entry.dist
				i += 1
			end
		end
	end
	for player, data in pairs(playerData) do
		local model = data.carrying
		local char = player.Character
		if model and model.Parent and char then
			local head = char:FindFirstChild("Head")
			if head then
				model:PivotTo(head.CFrame * CFrame.new(0, CARRY_OFFSET_Y, 0))
			end
		end
	end
end)

-- Loops -----------------------------------------------------------------
-- Spawner (interval is read every cycle: Rush Hour halves it live)
task.spawn(function()
	while true do
		task.wait(spawnIntervalNow)
		spawnLaneCharacter(nil, nil, false)
	end
end)

-- Economy tick: 1s, pad income x rebirth multiplier; popup every 5s.
task.spawn(function()
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				local income = padIncome(player) * rebirthMult(player) * incomeMult
				if income > 0 then
					data.cash += income
					if tick % 5 == 0 then
						fx(player, "incomePopup", math.floor(income * 5))
					end
				end
				syncPlayer(player)
			end
		end
	end
end)

-- Dance: pad + dropped characters dance briefly every 20-40s.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for model, st in pairs(danceSet) do
			if not model.Parent then
				danceSet[model] = nil
			elseif st.dancing then
				if now >= st.untilT then
					st.dancing = false
					st.next = now + math.random(20, 40)
					pcall(Factory.PlayIdle, model)
				end
			elseif now >= st.next then
				st.dancing = true
				st.untilT = now + 3
				pcall(Factory.PlayDance, model)
			end
		end
	end
end)

-- (Rainbow Rush / Mythic Hunt and the boss used to run on their own
-- scheduler loops; they are slots in the unified event director below.)

-- Fun events: Golden Brainrot + Double Income. The trigger functions
-- are shared with the admin panel's event buttons.
triggerGolden = function()
	local def = randomGoldenDef()
	if not def then
		return
	end
	local ok, model = pcall(placeLaneModel, def, nil)
	if ok and model then
		fxAll("golden", model:GetPivot().Position)
		sfxAll("event")
	end
end

triggerDoubleIncome = function()
	doubleToken += 1
	local token = doubleToken
	doubleActive = true
	updateIncomeMult()
	fxAll("doubleStart", nil)
	sfxAll("event")
	task.delay(DOUBLE_DURATION, function()
		-- A retrigger (director or admin) supersedes this timer.
		if doubleToken == token then
			doubleActive = false
			updateIncomeMult()
			fxAll("doubleEnd", nil)
		end
	end)
end

-- Fireworks (admin "SERU & EVENT"): five anchored, invisible
-- anchors high above the plaza's north side carry particle emitters
-- that burst in waves for ~15 seconds. Pure show — no gameplay
-- state — and Debris removes the anchors afterwards.
local FIREWORK_POINTS = {
	Vector3.new(-21, 27, -14), Vector3.new(-7, 31, -27),
	Vector3.new(7, 29, -14), Vector3.new(21, 27, -27),
	Vector3.new(0, 33, -20),
}
local FIREWORK_COLORS = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(90, 220, 255), Color3.fromRGB(150, 255, 130),
	Color3.fromRGB(220, 130, 255), Color3.fromRGB(255, 130, 200),
}
triggerFireworks = function()
	fxAll("announce", "🎆 FIREWORKS!")
	sfxAll("event")
	local anchors = {}
	for i, point in ipairs(FIREWORK_POINTS) do
		local anchor = Instance.new("Part")
		anchor.Name = "BanditsFirework"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(point)
		anchor.Parent = workspace
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(FIREWORK_COLORS[((i - 1) % #FIREWORK_COLORS) + 1])
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Lifetime = NumberRange.new(0.7, 1.3)
		emitter.Speed = NumberRange.new(9, 17)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 0
		emitter.LightEmission = 0.85
		emitter.Parent = anchor
		table.insert(anchors, emitter)
		Debris:AddItem(anchor, 18)
	end
	task.spawn(function()
		for wave = 1, 9 do
			for j, emitter in ipairs(anchors) do
				if wave == 1 or (wave + j) % 2 == 0 then
					emitter.Color = ColorSequence.new(FIREWORK_COLORS[((wave + j - 1) % #FIREWORK_COLORS) + 1])
					emitter:Emit(28)
				end
			end
			task.wait(1.6)
		end
	end)
end

-- Rush Hour (admin "SERU & EVENT"): 60 seconds of halved lane spawn
-- interval and doubled income. The income side composes with Double
-- Income through updateIncomeMult (2 while either window is open,
-- never more), and the end timer is rushToken-guarded exactly like
-- doubleToken, so a retrigger supersedes the old timer cleanly.
triggerRushHour = function()
	rushToken += 1
	local token = rushToken
	rushActive = true
	spawnIntervalNow = SPAWN_INTERVAL / 2
	updateIncomeMult()
	ReplicatedStorage:SetAttribute("RushHourEndsAt", os.time() + 60)
	fxAll("announce", "🚕 RUSH HOUR! Fast spawns + double income — 60 seconds!")
	sfxAll("event")
	task.delay(60, function()
		if rushToken == token then
			rushActive = false
			spawnIntervalNow = SPAWN_INTERVAL
			updateIncomeMult()
			ReplicatedStorage:SetAttribute("RushHourEndsAt", 0)
			fxAll("announce", "Rush Hour over — back to normal.")
		end
	end)
end

-- Unified event director: one rotation (Config.Events.Rotation) drives
-- every live event on the EVENTS_INTERVAL beat — golden brainrot,
-- double income, Rainbow Rush, Mythic Hunt and the boss. Every slot
-- calls the same trigger functions the admin panel uses, so scheduled
-- and manual events behave identically. Rainbow/Mythic run for
-- EVENT_DURATION; the delayed end only fires if that same event is
-- still the active one, so an admin endEvent or a different event
-- started meanwhile is never cut short. The boss slot spawns the boss
-- only on alternating full passes through the rotation and falls back
-- to a golden spawn on the passes in between.
local function runTimedEvent(kind)
	local ok, token = pcall(startEvent, kind)
	if not ok then
		return
	end
	task.delay(EVENT_DURATION, function()
		-- Only end the event this timer started: if an admin ended it
		-- and started a fresh event of the same kind meanwhile, the
		-- token has moved on and the new event keeps its full run.
		if currentEvent == kind and eventToken == token then
			endEvent()
		end
	end)
end

task.spawn(function()
	local slot = 0
	local cycle = 0
	while true do
		task.wait(EVENTS_INTERVAL)
		slot += 1
		if slot > #EVENT_ROTATION then
			slot = 1
			cycle += 1
		end
		local kind = EVENT_ROTATION[slot]
		if kind == "golden" then
			pcall(triggerGolden)
		elseif kind == "double" then
			pcall(triggerDoubleIncome)
		elseif kind == "rainbow" then
			runTimedEvent("Rainbow")
		elseif kind == "mythic" then
			runTimedEvent("Mythic")
		elseif kind == "boss" then
			if cycle % 2 == 0 then
				pcall(spawnBoss)
			else
				pcall(triggerGolden)
			end
		end
	end
end)

-- Richest board + banner refresh.
task.spawn(function()
	while true do
		task.wait(5)
		local ranked = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				table.insert(ranked, { name = player.DisplayName, cash = math.floor(data.cash) })
			end
		end
		table.sort(ranked, function(a, b)
			return a.cash > b.cash
		end)
		-- Rows only: world.RichestLabel is the board's TITLE label
		-- ("RICHEST BANDITS") — writing the joined ranking into it
		-- stomped the title with a squeezed duplicate of these rows.
		if world.RichestLabels then
			for i, label in ipairs(world.RichestLabels) do
				setText(label, ranked[i] and string.format("%d. %s — $%d", i, ranked[i].name, ranked[i].cash) or "")
			end
		end
		updateBanner()
	end
end)

-- Autosave every 120s.
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

print("[BrainrotBandits] init.server loaded")
