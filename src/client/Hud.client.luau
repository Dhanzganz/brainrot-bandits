-- Hud.client.luau
-- Brainrot Bandits HUD: cash / income / rebirths, carrying indicator, mute,
-- emote bar, admin panel, shop panel, overhead carry pose, camera shake.
-- HUD text is kept OUT of the top-left corner (Roblox menu lives there).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Effects = require(Shared:WaitForChild("Effects"))

local FXEvent = ReplicatedStorage:WaitForChild("FXEvent")
local SFXEvent = ReplicatedStorage:WaitForChild("SFXEvent")
local AdminEvent = ReplicatedStorage:WaitForChild("AdminEvent")
local ShopBuy = ReplicatedStorage:WaitForChild("ShopBuy")

-- Sound ids verified 2026-11-19 via Roblox economy API (creator: Roblox, audio).
local SFX_IDS = {
	pickup = 26723422,
	cash = 12221990,
	buy = 12221990, -- buy reuses the verified cash-register id
	slap = 12222152,
	rebirth = 12222253,
	event = 86260684,
	boss = 86260644,
	lucky = 106805906,
	sparkle = 106805906, -- sparkle reuses the verified lucky id
}
local CLICK_ID = 12221967 -- verified Roblox button.wav
local CASH_FALLBACK = 12221990

local EMOTES = {
	Dance = { Id = 507771019, Loop = true },
	Wave = { Id = 507770239, Loop = false },
	Laugh = { Id = 507770818, Loop = false },
}

local SHOP_ITEMS = {
	{ Key = "Speed", Name = "Sepatu Kilat", Desc = "+4 kecepatan per level" },
	{ Key = "Glove", Name = "Sarung Tinju Baja", Desc = "Slap lebih kuat (sekali beli)" },
	{ Key = "Luck", Name = "Jimat Hoki", Desc = "+8% peluang per level" },
}

-- The shop rows are keyed by the ShopBuy action names, but Config.Shop
-- names its entries differently (Shoes / Gloves / LuckyCharm, with
-- Costs / Cost fields). Map row -> Config entry so prices resolve.
local SHOP_CONFIG_KEYS = { Speed = "Shoes", Glove = "Gloves", Luck = "LuckyCharm" }

local GOLD = Color3.fromRGB(255, 215, 0)
local PINK = Color3.fromRGB(255, 120, 200)
local PANEL_BG = Color3.fromRGB(28, 20, 46)
local PANEL_STROKE = Color3.fromRGB(255, 120, 200)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function playSoundById(id, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = volume or 0.6
	sound.Parent = SoundService
	sound:Play()
	task.delay(6, function()
		sound:Destroy()
	end)
	return sound
end

local function playClick()
	playSoundById(CLICK_ID, 0.4)
end

local function formatCash(n)
	n = math.floor(n or 0)
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

local function makeButton(parent, text, size, pos, bg)
	local btn = Instance.new("TextButton")
	btn.Name = text:gsub("%s+", "")
	btn.Size = size
	btn.Position = pos
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.BackgroundColor3 = bg or Color3.fromRGB(60, 40, 90)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 18
	btn.Text = text
	btn.TextWrapped = true
	btn.AutoButtonColor = true
	btn.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Color = PANEL_STROKE
	stroke.Thickness = 1.5
	stroke.Parent = btn
	btn.MouseButton1Click:Connect(playClick)
	return btn
end

local function makeLabel(parent, text, size, pos, textSize, color)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = textSize or 20
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.4
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = parent
	return lbl
end

-- ---------------------------------------------------------------------------
-- ScreenGui + stats (top-right, never top-left)
-- ---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "BanditsHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local stats = Instance.new("Frame")
stats.Name = "StatsPanel"
stats.AnchorPoint = Vector2.new(1, 0)
stats.Position = UDim2.new(1, -14, 0, 78)
stats.Size = UDim2.new(0, 250, 0, 118)
stats.BackgroundColor3 = Color3.fromRGB(20, 14, 34)
stats.BackgroundTransparency = 0.25
stats.BorderSizePixel = 0
stats.Parent = gui
local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 12)
statsCorner.Parent = stats
local statsStroke = Instance.new("UIStroke")
statsStroke.Color = GOLD
statsStroke.Thickness = 2
statsStroke.Parent = stats

local cashLabel = makeLabel(stats, "$0", UDim2.new(1, -16, 0, 34), UDim2.new(0, 12, 0, 6), 26, GOLD)
local incomeLabel = makeLabel(stats, "+$0/detik", UDim2.new(1, -16, 0, 24), UDim2.new(0, 12, 0, 42), 17, Color3.fromRGB(140, 255, 150))
local rebirthLabel = makeLabel(stats, "Rebirth: 0  (x1)", UDim2.new(1, -16, 0, 24), UDim2.new(0, 12, 0, 68), 17, Color3.fromRGB(180, 160, 255))

local carryingLabel = Instance.new("TextLabel")
carryingLabel.Name = "CarryingLabel"
carryingLabel.AnchorPoint = Vector2.new(0.5, 0)
carryingLabel.Position = UDim2.new(0.5, 0, 0, 84)
carryingLabel.Size = UDim2.new(0, 600, 0, 40)
carryingLabel.BackgroundColor3 = Color3.fromRGB(20, 14, 34)
carryingLabel.BackgroundTransparency = 0.25
carryingLabel.BorderSizePixel = 0
carryingLabel.Font = Enum.Font.FredokaOne
carryingLabel.TextSize = 18
carryingLabel.TextColor3 = PINK
carryingLabel.TextStrokeTransparency = 0.4
carryingLabel.TextXAlignment = Enum.TextXAlignment.Center
carryingLabel.TextWrapped = true
carryingLabel.Visible = false
carryingLabel.Parent = gui
local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 10)
carryCorner.Parent = carryingLabel

-- Full-width alert banner (event warnings, admin feedback toasts),
-- below the carrying banner so the two never overlap.
local alertLabel = Instance.new("TextLabel")
alertLabel.Name = "AlertLabel"
alertLabel.AnchorPoint = Vector2.new(0.5, 0)
alertLabel.Position = UDim2.new(0.5, 0, 0, 132)
alertLabel.Size = UDim2.new(0, 720, 0, 44)
alertLabel.BackgroundColor3 = Color3.fromRGB(40, 8, 8)
alertLabel.BackgroundTransparency = 0.2
alertLabel.BorderSizePixel = 0
alertLabel.Font = Enum.Font.FredokaOne
alertLabel.TextSize = 20
alertLabel.TextColor3 = Color3.fromRGB(255, 70, 60)
alertLabel.TextStrokeTransparency = 0.3
alertLabel.TextXAlignment = Enum.TextXAlignment.Center
alertLabel.TextWrapped = true
alertLabel.Visible = false
alertLabel.Parent = gui
local alertCorner = Instance.new("UICorner")
alertCorner.CornerRadius = UDim.new(0, 10)
alertCorner.Parent = alertLabel

local alertToken = 0
local function showAlert(text, color, seconds, bgColor)
	alertToken += 1
	local token = alertToken
	alertLabel.Text = text
	alertLabel.TextColor3 = color
	-- Always set the background (default: the dark-red event style) so
	-- a green admin toast never leaves a red banner behind it or the
	-- other way round.
	alertLabel.BackgroundColor3 = bgColor or Color3.fromRGB(40, 8, 8)
	alertLabel.Visible = true
	task.delay(seconds, function()
		if alertToken == token then
			alertLabel.Visible = false
		end
	end)
end

-- Admin announcement banner: larger and centred on the play area —
-- broadcasts go to every player, so they must be unmissable. Shown via
-- the FX kind "announce" (server-side preset text only).
local announceLabel = Instance.new("TextLabel")
announceLabel.Name = "AnnounceLabel"
announceLabel.AnchorPoint = Vector2.new(0.5, 0.5)
announceLabel.Position = UDim2.new(0.5, 0, 0.38, 0)
announceLabel.Size = UDim2.new(0, 760, 0, 84)
announceLabel.BackgroundColor3 = Color3.fromRGB(24, 16, 48)
announceLabel.BackgroundTransparency = 0.15
announceLabel.BorderSizePixel = 0
announceLabel.Font = Enum.Font.FredokaOne
announceLabel.TextSize = 34
announceLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
announceLabel.TextWrapped = true
announceLabel.Visible = false
announceLabel.Parent = gui
local announceCorner = Instance.new("UICorner")
announceCorner.CornerRadius = UDim.new(0, 14)
announceCorner.Parent = announceLabel

local announceToken = 0
local function showAnnounce(text)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.Visible = true
	task.delay(3, function()
		if announceToken == token then
			announceLabel.Visible = false
		end
	end)
end

local function refreshStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = 0
	local rebirths = 0
	if leaderstats then
		local c = leaderstats:FindFirstChild("Cash")
		local r = leaderstats:FindFirstChild("Rebirths")
		if c then
			cash = c.Value
		end
		if r then
			rebirths = r.Value
		end
	end
	cashLabel.Text = formatCash(cash)
	incomeLabel.Text = "+" .. formatCash(player:GetAttribute("IncomePerSec") or 0) .. "/detik"
	rebirthLabel.Text = "Rebirth: " .. tostring(rebirths) .. "  (x" .. tostring(1 + rebirths) .. ")"

	local carrying = player:GetAttribute("Carrying")
	if carrying and carrying ~= "" then
		carryingLabel.Text = "Carrying: " .. tostring(carrying) .. " — deliver it to the GREEN ZONE at your base!"
		carryingLabel.Visible = true
	else
		carryingLabel.Visible = false
	end
end

player:GetAttributeChangedSignal("Carrying"):Connect(refreshStats)
player:GetAttributeChangedSignal("IncomePerSec"):Connect(refreshStats)
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshStats)
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 30)
	if leaderstats then
		for _, child in ipairs(leaderstats:GetChildren()) do
			child:GetPropertyChangedSignal("Value"):Connect(refreshStats)
		end
		leaderstats.ChildAdded:Connect(function(child)
			child:GetPropertyChangedSignal("Value"):Connect(refreshStats)
		end)
	end
end)
refreshStats()

-- ---------------------------------------------------------------------------
-- Right-side buttons: TOKO + ADMIN
-- ---------------------------------------------------------------------------

local tokoButton = makeButton(gui, "TOKO", UDim2.new(0, 120, 0, 48), UDim2.new(1, -134, 0, 248), Color3.fromRGB(120, 60, 160))
tokoButton.AnchorPoint = Vector2.new(0, 0)
tokoButton.TextSize = 22

-- The admin entry point, deliberately unmissable: a big gold-outlined
-- "⚙ ADMIN" button under the TOKO button. Visible ONLY to admins —
-- refreshAdminVisibility runs the same Config.IsAdmin check the rest
-- of the client uses; the button is pure UI, and the server re-checks
-- IsAdmin on every single action it fires.
local adminButton = makeButton(gui, "⚙ ADMIN", UDim2.new(0, 150, 0, 56), UDim2.new(1, -164, 0, 304), Color3.fromRGB(200, 36, 46))
adminButton.TextSize = 24
local adminButtonStroke = Instance.new("UIStroke")
adminButtonStroke.Color = Color3.fromRGB(255, 200, 40)
adminButtonStroke.Thickness = 2
adminButtonStroke.Parent = adminButton
adminButton.Visible = false

local function refreshAdminVisibility()
	local ok, isAdmin = pcall(Config.IsAdmin, player)
	adminButton.Visible = ok and isAdmin == true
end
refreshAdminVisibility()

-- ---------------------------------------------------------------------------
-- Shop panel (480x420, buttons >= 44px)
-- ---------------------------------------------------------------------------

-- Forward-declared: the shop opener hides the admin panel, declared below.
local adminPanel

local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
shopPanel.Size = UDim2.new(0, 480, 0, 420)
shopPanel.BackgroundColor3 = PANEL_BG
shopPanel.BorderSizePixel = 0
shopPanel.Visible = false
shopPanel.Parent = gui
local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 14)
shopCorner.Parent = shopPanel
local shopStroke = Instance.new("UIStroke")
shopStroke.Color = GOLD
shopStroke.Thickness = 2
shopStroke.Parent = shopPanel

makeLabel(shopPanel, "TOKO BRAINROT", UDim2.new(1, -20, 0, 36), UDim2.new(0, 16, 0, 10), 26, GOLD)

local shopClose = makeButton(shopPanel, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 8), Color3.fromRGB(180, 30, 40))
shopClose.TextSize = 22
shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

local shopRows = {}

local function priceList(entry)
	if type(entry) ~= "table" then
		return {}
	end
	if type(entry.Prices) == "table" then
		return entry.Prices
	end
	if type(entry.Price) == "number" then
		return { entry.Price }
	end
	if type(entry.Costs) == "table" then
		return entry.Costs
	end
	if type(entry.Cost) == "number" then
		return { entry.Cost }
	end
	local list = {}
	for i, v in ipairs(entry) do
		if type(v) == "number" then
			list[i] = v
		end
	end
	return list
end

local function refreshShop()
	local shop = Config.Shop or {}
	for _, item in ipairs(SHOP_ITEMS) do
		local row = shopRows[item.Key]
		if row then
			local level = player:GetAttribute("Shop" .. item.Key) or 0
			if type(level) == "boolean" then
				-- ShopGlove is a boolean attribute, not a level count.
				level = level and 1 or 0
			end
			if type(level) ~= "number" then
				level = 0
			end
			local prices = priceList(shop[SHOP_CONFIG_KEYS[item.Key] or item.Key])
			local nextPrice = prices[level + 1]
			if item.Key == "Glove" and level >= 1 then
				row.LevelLabel.Text = "DIMILIKI"
				row.BuyButton.Text = "DIMILIKI"
				row.BuyButton.AutoButtonColor = false
			elseif nextPrice then
				row.LevelLabel.Text = "Level " .. tostring(level) .. "  •  " .. item.Desc
				row.BuyButton.Text = "BELI " .. formatCash(nextPrice)
				row.BuyButton.AutoButtonColor = true
			else
				row.LevelLabel.Text = "Level " .. tostring(level) .. "  •  MAX"
				row.BuyButton.Text = "MAX"
				row.BuyButton.AutoButtonColor = false
			end
		end
	end
end

for i, item in ipairs(SHOP_ITEMS) do
	local y = 56 + (i - 1) * 108
	local row = Instance.new("Frame")
	row.Name = item.Key .. "Row"
	row.Size = UDim2.new(1, -32, 0, 96)
	row.Position = UDim2.new(0, 16, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(45, 30, 70)
	row.BorderSizePixel = 0
	row.Parent = shopPanel
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	makeLabel(row, item.Name, UDim2.new(1, -16, 0, 28), UDim2.new(0, 12, 0, 8), 20, Color3.new(1, 1, 1))
	local levelLabel = makeLabel(row, "", UDim2.new(1, -16, 0, 22), UDim2.new(0, 12, 0, 38), 15, Color3.fromRGB(200, 190, 220))
	local buyButton = makeButton(row, "BELI", UDim2.new(0, 170, 0, 48), UDim2.new(1, -182, 0, 40), Color3.fromRGB(30, 160, 70))
	buyButton.TextSize = 18
	buyButton.MouseButton1Click:Connect(function()
		ShopBuy:FireServer(item.Key)
		refreshStats()
	end)
	shopRows[item.Key] = { LevelLabel = levelLabel, BuyButton = buyButton }
end

makeLabel(shopPanel, "Beli lewat konter toko atau tombol TOKO. Harga dibayar dari Cash.", UDim2.new(1, -32, 0, 40), UDim2.new(0, 16, 0, 380), 14, Color3.fromRGB(180, 170, 200))

local function openShop()
	refreshShop()
	shopPanel.Visible = true
	adminPanel.Visible = false
end

tokoButton.MouseButton1Click:Connect(openShop)

-- Server replies to ShopBuy with the shop state; refresh from attributes.
ShopBuy.OnClientEvent:Connect(function()
	refreshShop()
	refreshStats()
end)

-- Open the shop when the counter prompt is used (prompt lives in the world).
task.spawn(function()
	local prompt = nil
	for _ = 1, 60 do
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.Name == "ShopPrompt" then
				prompt = desc
				break
			end
		end
		if prompt then
			break
		end
		task.wait(0.5)
	end
	if prompt then
		prompt.Triggered:Connect(function(otherPlayer)
			if otherPlayer == player then
				openShop()
			end
		end)
	end
end)

-- ---------------------------------------------------------------------------
-- Admin panel (only for admins; server re-verifies every action)
-- ---------------------------------------------------------------------------

-- The panel is a fixed outer frame (title + close always visible)
-- with an inner scrolling frame for the sections — previously the
-- title and close button were children of the scroller itself and
-- scrolled away with the content, leaving no way to close the panel
-- once you had scrolled down.
adminPanel = Instance.new("Frame")
adminPanel.Name = "AdminPanel"
adminPanel.AnchorPoint = Vector2.new(0.5, 0.5)
adminPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
adminPanel.Size = UDim2.new(0, 360, 0, 420)
adminPanel.BackgroundColor3 = PANEL_BG
adminPanel.BorderSizePixel = 0
adminPanel.Visible = false
adminPanel.Parent = gui
local adminCorner = Instance.new("UICorner")
adminCorner.CornerRadius = UDim.new(0, 14)
adminCorner.Parent = adminPanel
local adminStroke = Instance.new("UIStroke")
adminStroke.Color = Color3.fromRGB(255, 60, 60)
adminStroke.Thickness = 2
adminStroke.Parent = adminPanel

makeLabel(adminPanel, "ADMIN PANEL", UDim2.new(1, -20, 0, 36), UDim2.new(0, 16, 0, 10), 26, Color3.fromRGB(255, 90, 90))
local adminClose = makeButton(adminPanel, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 8), Color3.fromRGB(180, 30, 40))
adminClose.TextSize = 22
adminClose.MouseButton1Click:Connect(function()
	adminPanel.Visible = false
end)

local adminScroll = Instance.new("ScrollingFrame")
adminScroll.Name = "AdminScroll"
adminScroll.Position = UDim2.new(0, 0, 0, 54)
adminScroll.Size = UDim2.new(1, 0, 1, -54)
adminScroll.BackgroundTransparency = 1
adminScroll.BorderSizePixel = 0
adminScroll.ScrollBarThickness = 6
adminScroll.Parent = adminPanel

-- Complete panel: every admin action the server recognises, grouped
-- into labelled sections with human-readable button text. The Action
-- strings are the exact names the AdminEvent handler in
-- init.server.luau dispatches on — do not rename them here. The panel
-- only renders for admins (the ADMIN button is hidden otherwise) and
-- the server re-checks IsAdmin — plus a shared 5s debounce for the
-- event triggers — on every request, so this visibility is cosmetic.
local ADMIN_SECTIONS = {
	{
		Title = "EVENTS",
		Color = Color3.fromRGB(120, 80, 20),
		Buttons = {
			{ Text = "Spawn Golden", Action = "spawnGolden" },
			{ Text = "Double Income 30s", Action = "doubleIncome" },
			{ Text = "Rainbow Event", Action = "startRainbow" },
			{ Text = "Mythic Event", Action = "startMythic" },
			{ Text = "Spawn Boss", Action = "spawnBoss" },
			{ Text = "End Event", Action = "endEvent" },
		},
	},
	{
		Title = "SERU & EVENT",
		Color = Color3.fromRGB(170, 90, 30),
		Buttons = {
			{ Text = "🎆 Fireworks", Action = "fireworks" },
			{ Text = "🚕 Rush Hour 60s", Action = "rushHour" },
			{ Text = "💸 Cash Rain +500", Action = "cashRain" },
		},
	},
	{
		Title = "SPAWN",
		Color = Color3.fromRGB(70, 40, 110),
		Buttons = {
			{ Text = "Spawn Legendary", Action = "spawnLegendary" },
			{ Text = "Spawn Mythic", Action = "spawnMythic" },
			{ Text = "Spawn Diamond", Action = "spawnDiamond" },
			{ Text = "Spawn 5 Random", Action = "spawn5" },
		},
	},
	{
		Title = "CASH & PROGRESS",
		Color = Color3.fromRGB(30, 110, 60),
		Buttons = {
			{ Text = "+$1,000", Action = "giveCash1000" },
			{ Text = "+$10,000", Action = "addCash10k" },
			{ Text = "+$1,000,000", Action = "addCash1m" },
			{ Text = "+1 Rebirth", Action = "addRebirth" },
			{ Text = "Toggle Speed", Action = "toggleSpeed" },
		},
	},
	{
		Title = "TELEPORT",
		Color = Color3.fromRGB(40, 80, 140),
		Buttons = {
			{ Text = "Teleport: My Base", Action = "tpBase" },
			{ Text = "Teleport: Lane", Action = "tpLane" },
		},
	},
	{
		Title = "ANNOUNCE",
		Color = Color3.fromRGB(140, 90, 20),
		Buttons = {
			{ Text = "📣 Event Soon", Action = "announce1" },
			{ Text = "☠ Boss Coming", Action = "announce2" },
			{ Text = "⭐ Golden Hour", Action = "announce3" },
		},
	},
	{
		Title = "WORLD",
		Color = Color3.fromRGB(30, 90, 120),
		Buttons = {
			{ Text = "Day / Night", Action = "toggleDayNight" },
		},
	},
}

local layoutY = 0
for _, section in ipairs(ADMIN_SECTIONS) do
	local band = Instance.new("Frame")
	band.Name = "Section_" .. section.Title:gsub("[^%w]+", "")
	band.Size = UDim2.new(1, -32, 0, 26)
	band.Position = UDim2.new(0, 16, 0, layoutY)
	band.BackgroundColor3 = Color3.fromRGB(16, 10, 28)
	band.BorderSizePixel = 0
	band.Parent = adminScroll
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, 8)
	bandCorner.Parent = band
	makeLabel(band, section.Title, UDim2.new(1, -16, 1, 0), UDim2.new(0, 10, 0, 0), 15, Color3.fromRGB(255, 190, 40))
	layoutY += 26 + 8
	for _, entry in ipairs(section.Buttons) do
		local btn = makeButton(adminScroll, entry.Text, UDim2.new(1, -32, 0, 44), UDim2.new(0, 16, 0, layoutY), section.Color)
		btn.Name = "Admin_" .. entry.Action
		btn.TextSize = 17
		btn.MouseButton1Click:Connect(function()
			AdminEvent:FireServer(entry.Action)
		end)
		layoutY += 44 + 8
	end
	layoutY += 6
end
adminScroll.CanvasSize = UDim2.new(0, 0, 0, layoutY + 6)

adminButton.MouseButton1Click:Connect(function()
	adminPanel.Visible = not adminPanel.Visible
	if adminPanel.Visible then
		shopPanel.Visible = false
	end
end)

-- ---------------------------------------------------------------------------
-- Mute button (bottom-right) + emote bar (bottom-left)
-- ---------------------------------------------------------------------------

local bgMusic = nil
task.spawn(function()
	bgMusic = SoundService:WaitForChild("BGMusic", 30)
end)

local muted = false
local muteButton = makeButton(gui, "♪ ON", UDim2.new(0, 90, 0, 48), UDim2.new(1, -104, 1, -62), Color3.fromRGB(40, 30, 60))
muteButton.AnchorPoint = Vector2.new(0, 0)
muteButton.TextSize = 20
muteButton.MouseButton1Click:Connect(function()
	muted = not muted
	if bgMusic then
		bgMusic.Volume = muted and 0 or 0.35
	end
	muteButton.Text = muted and "♪ OFF" or "♪ ON"
end)

local emoteBar = Instance.new("Frame")
emoteBar.Name = "EmoteBar"
emoteBar.AnchorPoint = Vector2.new(0, 1)
emoteBar.Position = UDim2.new(0, 14, 1, -14)
emoteBar.Size = UDim2.new(0, 300, 0, 56)
emoteBar.BackgroundColor3 = Color3.fromRGB(20, 14, 34)
emoteBar.BackgroundTransparency = 0.25
emoteBar.BorderSizePixel = 0
emoteBar.Parent = gui
local emoteCorner = Instance.new("UICorner")
emoteCorner.CornerRadius = UDim.new(0, 12)
emoteCorner.Parent = emoteBar

local emoteTracks = {}
local danceTrack = nil

local function getAnimator()
	local char = player.Character
	if not char then
		return nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return humanoid:FindFirstChildOfClass("Animator")
end

local function stopDance()
	if danceTrack then
		danceTrack:Stop()
		danceTrack:Destroy()
		danceTrack = nil
	end
end

local function playEmote(name)
	local def = EMOTES[name]
	if not def then
		return
	end
	local animator = getAnimator()
	if not animator then
		return
	end
	if name == "Dance" then
		if danceTrack then
			stopDance()
			return
		end
		stopDance()
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(def.Id)
		danceTrack = animator:LoadAnimation(anim)
		danceTrack.Looped = true
		danceTrack:Play()
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(def.Id)
	local track = animator:LoadAnimation(anim)
	track.Looped = false
	track:Play()
	emoteTracks[name] = track
end

local emoteNames = { "Dance", "Wave", "Laugh" }
for i, name in ipairs(emoteNames) do
	local btn = makeButton(emoteBar, name, UDim2.new(0, 88, 0, 44), UDim2.new(0, 8 + (i - 1) * 96, 0, 6), Color3.fromRGB(60, 40, 90))
	btn.TextSize = 17
	btn.MouseButton1Click:Connect(function()
		playEmote(name)
	end)
end

player.CharacterAdded:Connect(function()
	stopDance()
end)

-- ---------------------------------------------------------------------------
-- SFX + camera shake
-- ---------------------------------------------------------------------------

SFXEvent.OnClientEvent:Connect(function(name)
	local id = SFX_IDS[name]
	if not id then
		return
	end
	playSoundById(id, 0.7)
end)

local shakeStrength = 0
local shakeTime = 0

-- Positional burst kinds the server fires at world positions. These
-- had no client branch and fell through silently, so the particle
-- bursts never rendered.
local BURST_COLORS = {
	gold = Color3.fromRGB(255, 190, 40),
	deliver = Color3.fromRGB(80, 255, 130),
	luckUp = Color3.fromRGB(120, 255, 170),
	lucky = Color3.fromRGB(255, 110, 200),
	luckyCash = Color3.fromRGB(255, 215, 80),
	rebirth = Color3.fromRGB(170, 110, 255),
	bossBoom = Color3.fromRGB(255, 90, 40),
}

FXEvent.OnClientEvent:Connect(function(message, strength)
	if message == "Shake" then
		shakeStrength = tonumber(strength) or 1
		shakeTime = 0.45
	elseif message == "adminToast" then
		-- Server feedback for the acting admin only (fx is per-player):
		-- the text rides in the second argument.
		showAlert(tostring(strength), Color3.fromRGB(120, 255, 140), 2.2, Color3.fromRGB(16, 40, 20))
	elseif message == "adminToastFail" then
		showAlert(tostring(strength), Color3.fromRGB(255, 80, 70), 2.2)
	elseif message == "golden" then
		showAlert("⭐ GOLDEN BRAINROT ON THE LANE — GRAB IT!", Color3.fromRGB(255, 190, 40), 5)
	elseif message == "doubleStart" then
		showAlert("💰 DOUBLE INCOME — 30 SECONDS!", Color3.fromRGB(170, 255, 90), 4)
	elseif message == "doubleEnd" then
		showAlert("Double income ended.", Color3.fromRGB(170, 170, 170), 2)
	elseif message == "rainbowStart" then
		showAlert("🌈 RAINBOW RUSH — every spawn is Rainbow x10!", Color3.fromRGB(255, 110, 200), 5)
	elseif message == "mythicStart" then
		showAlert("👑 MYTHIC HUNT — Epic and better spawns only!", Color3.fromRGB(170, 80, 255), 5)
	elseif message == "bossSpawn" then
		showAlert("👹 BOSS APPEARED — slap it down for big cash!", Color3.fromRGB(255, 90, 40), 5)
	elseif message == "announce" then
		showAnnounce(tostring(strength))
	elseif message == "incomePopup" then
		local amount = tonumber(strength)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if amount and hrp then
			Effects.IncomePopup(hrp.Position + Vector3.new(0, 3, 0), "+$" .. formatCash(amount))
		end
	elseif message == "openShop" then
		openShop()
	else
		local burstColor = BURST_COLORS[message]
		if burstColor and typeof(strength) == "Vector3" then
			Effects.Burst(strength, burstColor)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if shakeTime > 0 then
		shakeTime -= 0.016
		local s = shakeStrength * (shakeTime / 0.45)
		local offset = Vector3.new(
			(math.random() - 0.5) * 0.5 * s,
			(math.random() - 0.5) * 0.5 * s,
			0
		)
		camera.CFrame = camera.CFrame * CFrame.new(offset)
		if shakeTime <= 0 then
			shakeStrength = 0
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Event lighting + carry pose
-- ---------------------------------------------------------------------------

Effects.SetupLighting()

local function applyEventFX()
	local kind = ReplicatedStorage:GetAttribute("EventKind")
	if kind == nil or kind == "" then
		Effects.StopEventFX()
		return
	end
	local k = tostring(kind)
	if string.find(k, "Rainbow") then
		Effects.StartEventFX("Rainbow")
	elseif string.find(k, "Mythic") then
		Effects.StartEventFX("Mythic")
	else
		Effects.StopEventFX()
	end
end

ReplicatedStorage:GetAttributeChangedSignal("EventKind"):Connect(applyEventFX)
applyEventFX()

-- Admin day/night flips the server-owned base clock; re-apply the BASE
-- look when no event look is active (an active event keeps overriding
-- and picks the new base up when it ends, via StopEventFX).
ReplicatedStorage:GetAttributeChangedSignal("BaseClockTime"):Connect(function()
	local kind = ReplicatedStorage:GetAttribute("EventKind")
	if kind == nil or kind == "" then
		Effects.SetupLighting()
	end
end)

-- Overhead two-hand carry pose via shoulder Motor6D Transforms.
local leftShoulder = nil
local rightShoulder = nil
local carryingPose = false

local function findShoulders()
	leftShoulder = nil
	rightShoulder = nil
	local char = player.Character
	if not char then
		return
	end
	leftShoulder = char:FindFirstChild("LeftShoulder")
		or char:FindFirstChild("Left Shoulder")
	rightShoulder = char:FindFirstChild("RightShoulder")
		or char:FindFirstChild("Right Shoulder")
end

local function bindCharacter(char)
	findShoulders()
	char.DescendantAdded:Connect(function()
		findShoulders()
	end)
end

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

RunService.Heartbeat:Connect(function()
	local carrying = player:GetAttribute("Carrying")
	local isCarrying = carrying ~= nil and carrying ~= ""
	if isCarrying then
		if not leftShoulder or not rightShoulder then
			findShoulders()
		end
		local t = os.clock()
		local sway = math.sin(t * 2.2) * 0.08
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.Angles(sway, 0, math.rad(155))
		end
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.Transform = CFrame.Angles(-sway, 0, math.rad(-155))
		end
		carryingPose = true
	elseif carryingPose then
		-- Restore exactly once when the carry ends.
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.new()
		end
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.Transform = CFrame.new()
		end
		carryingPose = false
	end
end)

-- Keep the HUD honest on a slow tick too (leaderstats can change server-side).
task.spawn(function()
	while true do
		task.wait(1)
		refreshStats()
	end
end)
