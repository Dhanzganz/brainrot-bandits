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

local ADMIN_ACTIONS = {
	"cash", "cashbig", "legendary", "spawnmythic", "spawndiamond", "spawn5",
	"rainbow", "mythic", "boss", "endevent", "speed", "rebirth", "tphome", "tplane",
}

local SHOP_ITEMS = {
	{ Key = "Speed", Name = "Sepatu Kilat", Desc = "+4 kecepatan per level" },
	{ Key = "Glove", Name = "Sarung Tinju Baja", Desc = "Slap lebih kuat (sekali beli)" },
	{ Key = "Luck", Name = "Jimat Hoki", Desc = "+8% peluang per level" },
}

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
stats.Position = UDim2.new(1, -14, 0, 14)
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
carryingLabel.AnchorPoint = Vector2.new(1, 0)
carryingLabel.Position = UDim2.new(1, -14, 0, 140)
carryingLabel.Size = UDim2.new(0, 250, 0, 36)
carryingLabel.BackgroundColor3 = Color3.fromRGB(20, 14, 34)
carryingLabel.BackgroundTransparency = 0.25
carryingLabel.BorderSizePixel = 0
carryingLabel.Font = Enum.Font.FredokaOne
carryingLabel.TextSize = 16
carryingLabel.TextColor3 = PINK
carryingLabel.TextStrokeTransparency = 0.4
carryingLabel.TextWrapped = true
carryingLabel.Visible = false
carryingLabel.Parent = gui
local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 10)
carryCorner.Parent = carryingLabel

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
		carryingLabel.Text = "Carrying: " .. tostring(carrying) .. " — deliver it home!"
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

local tokoButton = makeButton(gui, "TOKO", UDim2.new(0, 120, 0, 48), UDim2.new(1, -134, 0, 184), Color3.fromRGB(120, 60, 160))
tokoButton.AnchorPoint = Vector2.new(0, 0)
tokoButton.TextSize = 22

local adminButton = makeButton(gui, "ADMIN", UDim2.new(0, 120, 0, 48), UDim2.new(1, -134, 0, 240), Color3.fromRGB(180, 30, 40))
adminButton.TextSize = 22
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
			if type(level) ~= "number" then
				level = 0
			end
			local prices = priceList(shop[item.Key])
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

adminPanel = Instance.new("ScrollingFrame")
adminPanel.Name = "AdminPanel"
adminPanel.AnchorPoint = Vector2.new(0.5, 0.5)
adminPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
adminPanel.Size = UDim2.new(0, 360, 0, 420)
adminPanel.BackgroundColor3 = PANEL_BG
adminPanel.BorderSizePixel = 0
adminPanel.ScrollBarThickness = 6
adminPanel.CanvasSize = UDim2.new(0, 0, 0, 60 + #ADMIN_ACTIONS * 52)
adminPanel.Visible = false
adminPanel.Parent = gui
local adminCorner = Instance.new("UICorner")
adminCorner.CornerRadius = UDim.new(0, 14)
adminCorner.Parent = adminPanel
local adminStroke = Instance.new("UIStroke")
adminStroke.Color = Color3.fromRGB(255, 60, 60)
adminStroke.Thickness = 2
adminStroke.Parent = adminPanel

makeLabel(adminPanel, "ADMIN", UDim2.new(1, -20, 0, 36), UDim2.new(0, 16, 0, 10), 26, Color3.fromRGB(255, 90, 90))
local adminClose = makeButton(adminPanel, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 8), Color3.fromRGB(180, 30, 40))
adminClose.TextSize = 22
adminClose.MouseButton1Click:Connect(function()
	adminPanel.Visible = false
end)

for i, action in ipairs(ADMIN_ACTIONS) do
	local btn = makeButton(adminPanel, action, UDim2.new(1, -32, 0, 44), UDim2.new(0, 16, 0, 52 + (i - 1) * 52), Color3.fromRGB(90, 30, 40))
	btn.TextSize = 18
	btn.MouseButton1Click:Connect(function()
		AdminEvent:FireServer(action)
	end)
end

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

FXEvent.OnClientEvent:Connect(function(message, strength)
	if message == "Shake" then
		shakeStrength = tonumber(strength) or 1
		shakeTime = 0.45
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
