-- Brainrot Bandits — shared game configuration.
-- Single source of truth for rarities, characters, mutations, economy,
-- arena layout, shop, boss/events and admin access.

local Config = {}

--------------------------------------------------------------------------------
-- Rarities
--------------------------------------------------------------------------------

Config.Rarities = {
	Common = {
		Order = 1,
		Color = Color3.fromRGB(170, 170, 170),
	},
	Rare = {
		Order = 2,
		Color = Color3.fromRGB(60, 140, 255),
	},
	Epic = {
		Order = 3,
		Color = Color3.fromRGB(170, 80, 255),
	},
	Legendary = {
		Order = 4,
		Color = Color3.fromRGB(255, 200, 40),
	},
	Mythic = {
		Order = 5,
		Color = Color3.fromRGB(255, 110, 200),
	},
}

-- Spawn weights out of 100 (Common 55, Rare 25, Epic 12, Legendary 6, Mythic 2).
Config.SpawnWeights = {
	Common = 55,
	Rare = 25,
	Epic = 12,
	Legendary = 6,
	Mythic = 2,
}

--------------------------------------------------------------------------------
-- Characters (10)
-- Fields: Name, Rarity, Price, Income (cash per second), Shape,
-- BodyColor, AccentColor.
--------------------------------------------------------------------------------

Config.Characters = {
	{
		Name = "Cappuccino Golem",
		Rarity = "Common",
		Price = 100,
		Income = 1,
		Shape = "cup",
		BodyColor = Color3.fromRGB(160, 110, 60),
		AccentColor = Color3.fromRGB(245, 235, 210),
	},
	{
		Name = "Banana Shark",
		Rarity = "Common",
		Price = 175,
		Income = 2,
		Shape = "shark",
		BodyColor = Color3.fromRGB(250, 210, 60),
		AccentColor = Color3.fromRGB(255, 255, 255),
	},
	{
		Name = "Pickle Wizard",
		Rarity = "Common",
		Price = 250,
		Income = 3,
		Shape = "wizard",
		BodyColor = Color3.fromRGB(80, 180, 70),
		AccentColor = Color3.fromRGB(120, 60, 180),
	},
	{
		Name = "Toilet Titan",
		Rarity = "Rare",
		Price = 750,
		Income = 8,
		Shape = "toilet",
		BodyColor = Color3.fromRGB(240, 240, 240),
		AccentColor = Color3.fromRGB(60, 140, 220),
	},
	{
		Name = "Waffle Dragon",
		Rarity = "Rare",
		Price = 1100,
		Income = 11,
		Shape = "dragon",
		BodyColor = Color3.fromRGB(210, 150, 60),
		AccentColor = Color3.fromRGB(220, 80, 60),
	},
	{
		Name = "Skibidi Samurai",
		Rarity = "Epic",
		Price = 3000,
		Income = 26,
		Shape = "samurai",
		BodyColor = Color3.fromRGB(200, 60, 60),
		AccentColor = Color3.fromRGB(200, 200, 210),
	},
	{
		Name = "Glorbo Fruttodrillo",
		Rarity = "Epic",
		Price = 4200,
		Income = 34,
		Shape = "croc",
		BodyColor = Color3.fromRGB(60, 160, 80),
		AccentColor = Color3.fromRGB(240, 140, 40),
	},
	{
		Name = "Bombardiro Crocodilo",
		Rarity = "Legendary",
		Price = 12000,
		Income = 95,
		Shape = "plane",
		BodyColor = Color3.fromRGB(140, 150, 160),
		AccentColor = Color3.fromRGB(60, 160, 90),
	},
	{
		Name = "Tung Tung Sahur",
		Rarity = "Legendary",
		Price = 16000,
		Income = 120,
		Shape = "log",
		BodyColor = Color3.fromRGB(120, 75, 35),
		AccentColor = Color3.fromRGB(200, 160, 90),
	},
	{
		Name = "Ballerina Cappuccina",
		Rarity = "Mythic",
		Price = 50000,
		Income = 360,
		Shape = "dancer",
		BodyColor = Color3.fromRGB(250, 150, 200),
		AccentColor = Color3.fromRGB(255, 245, 250),
	},
}

--------------------------------------------------------------------------------
-- Mutations
--------------------------------------------------------------------------------

Config.Mutations = {
	Gold = {
		Multiplier = 5,
		Chance = 0.08,
		Color = Color3.fromRGB(255, 200, 40),
	},
	Diamond = {
		Multiplier = 12,
		Chance = 0.02,
		Color = Color3.fromRGB(170, 220, 255),
	},
	-- Rainbow only appears during events.
	Rainbow = {
		Multiplier = 10,
		Chance = 0,
		Color = Color3.fromRGB(255, 110, 200),
	},
}

--------------------------------------------------------------------------------
-- Economy
--------------------------------------------------------------------------------

Config.StartingCash = 300

-- Rebirth costs in order; income multiplier = 1 + Rebirths.
Config.RebirthCosts = { 10000, 50000, 250000, 1000000, 5000000, 25000000 }

function Config.GetRebirthMultiplier(rebirths: number): number
	return 1 + rebirths
end

--------------------------------------------------------------------------------
-- Arena / lane / bases
--------------------------------------------------------------------------------

Config.ArenaSize = 220

Config.Lane = {
	FromX = -95,
	ToX = 95,
	Z = 0,
	Width = 14,
	WalkTime = 42,
	MaxOnLane = 8,
	SpawnInterval = 4,
}

Config.BaseCount = 6
Config.BaseRadius = 60
Config.BaseAngles = { 30, 90, 150, 210, 270, 330 }
Config.PadsPerBase = 6

Config.ShrinePosition = Vector3.new(0, 0, 34)

-- Three lucky stands on the north side of the plaza.
Config.LuckyStandPositions = {
	Vector3.new(-24.1, 0, -34.4),
	Vector3.new(0, 0, -42),
	Vector3.new(24.1, 0, -34.4),
}

Config.RichestBoardPosition = Vector3.new(0, 0, 56)

--------------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------------

Config.Shop = {
	Shoes = {
		Costs = { 500, 1500, 4000 },
		WalkSpeedBonus = 4, -- added walk speed per level
	},
	Gloves = {
		Cost = 2500, -- one-time purchase
	},
	LuckyCharm = {
		Costs = { 5000, 12000 },
		LuckBonus = 0.08, -- added mutation chance per level
	},
}

--------------------------------------------------------------------------------
-- Boss / events / carry
--------------------------------------------------------------------------------

Config.BossInterval = 360
Config.BossHealth = 120

Config.EventInterval = 180
Config.EventDuration = 60

-- Fun live events, driven by the unified event director in init.server
-- and also triggerable from the admin panel: a GOLDEN brainrot (a cloned
-- Epic/Legendary def at a bargain price with multiplied income and a
-- gold tint), Double Income (all pad income x2 for the duration), the
-- legacy Rainbow Rush / Mythic Hunt events (which run for
-- Config.EventDuration) and the boss. One rotation slot fires every
-- Interval seconds; the "boss" slot only spawns the boss on alternating
-- full passes through the list and falls back to a golden spawn on the
-- passes in between.
Config.Events = {
	Interval = 120,
	DoubleDuration = 30,
	GoldenPrice = 500,
	GoldenIncomeMult = 5,
	Rotation = { "golden", "double", "rainbow", "golden", "mythic", "double", "boss" },
}

-- Carrying a character makes the carrier walk 10% slower.
Config.CarrySlowMultiplier = 0.90

--------------------------------------------------------------------------------
-- Admins
--------------------------------------------------------------------------------

Config.AdminUsernames = { "7Dhanzz_inst", "stemma_boy" }
Config.AdminUserIds = { 8350974631 }

function Config.IsAdmin(player: Player): boolean
	if table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	return table.find(Config.AdminUsernames, player.Name) ~= nil
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Find a character definition by its exact name. Returns nil when unknown.
function Config.GetCharacter(name: string)
	for _, def in ipairs(Config.Characters) do
		if def.Name == name then
			return def
		end
	end
	return nil
end

-- Placement frame for base number `index` (1..6), facing the arena centre.
function Config.GetBaseCFrame(index: number): CFrame
	local angle = Config.BaseAngles[((index - 1) % Config.BaseCount) + 1]
	local radians = math.rad(angle)
	local position = Vector3.new(
		Config.BaseRadius * math.cos(radians),
		0,
		Config.BaseRadius * math.sin(radians)
	)
	return CFrame.lookAt(position, Vector3.new(0, 0, 0))
end

return Config
