-- Loading.client.luau
-- Brainrot Bandits loading screen (ReplicatedFirst).
-- Removes the default loading screen immediately, shows a dark-purple splash
-- with a cycling character chip and a gold-to-pink progress bar, then fades
-- out once the game is loaded and the player's character exists.
-- Hard failsafe: gone after 8 seconds no matter what. All guarded by pcall.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local CHARACTER_CHIPS = {
	"Cappuccino Golem",
	"Banana Shark",
	"Tung Tung Sahur",
	"Ballerina Cappuccina",
	"Bombardiro Crocodilo",
}

local ok, err = pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	local gui = Instance.new("ScreenGui")
	gui.Name = "BanditsLoading"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Splash"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = Color3.fromRGB(24, 12, 44)
	root.BorderSizePixel = 0
	root.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.38, 0)
	title.Size = UDim2.new(0, 700, 0, 90)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 64
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextStrokeTransparency = 0.2
	title.Text = "BRAINROT BANDITS"
	title.Parent = root

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.new(0.5, 0, 0.47, 0)
	subtitle.Size = UDim2.new(0, 600, 0, 32)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextSize = 22
	subtitle.TextColor3 = Color3.fromRGB(255, 180, 220)
	subtitle.Text = "Claim brainrots. Carry them home. Get rich."
	subtitle.Parent = root

	local chip = Instance.new("TextLabel")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.new(0.5, 0, 0.58, 0)
	chip.Size = UDim2.new(0, 320, 0, 44)
	chip.BackgroundColor3 = Color3.fromRGB(60, 35, 100)
	chip.BackgroundTransparency = 0.15
	chip.Font = Enum.Font.FredokaOne
	chip.TextSize = 20
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Text = CHARACTER_CHIPS[1]
	chip.Parent = root
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 22)
	chipCorner.Parent = chip
	local chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Color3.fromRGB(255, 120, 200)
	chipStroke.Thickness = 2
	chipStroke.Parent = chip

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.AnchorPoint = Vector2.new(0.5, 0.5)
	barBack.Position = UDim2.new(0.5, 0, 0.68, 0)
	barBack.Size = UDim2.new(0, 420, 0, 18)
	barBack.BackgroundColor3 = Color3.fromRGB(50, 30, 80)
	barBack.BorderSizePixel = 0
	barBack.Parent = root
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 9)
	barCorner.Parent = barBack

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Position = UDim2.new(0, 0, 0, 0)
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 9)
	fillCorner.Parent = barFill

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
	})
	gradient.Parent = barFill

	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "Percent"
	percentLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	percentLabel.Position = UDim2.new(0.5, 0, 0.73, 0)
	percentLabel.Size = UDim2.new(0, 200, 0, 24)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Font = Enum.Font.FredokaOne
	percentLabel.TextSize = 16
	percentLabel.TextColor3 = Color3.fromRGB(200, 190, 220)
	percentLabel.Text = "Loading... 0%"
	percentLabel.Parent = root

	local finished = false
	local startTime = os.clock()

	local function setProgress(pct)
		local clamped = math.clamp(pct, 0, 100)
		barFill.Size = UDim2.new(clamped / 100, 0, 1, 0)
		percentLabel.Text = "Loading... " .. tostring(math.floor(clamped)) .. "%"
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		setProgress(100)
		task.wait(0.15)
		local fade = TweenService:Create(
			root,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		fade:Play()
		-- Fade the text out with the splash.
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("TextLabel") then
				TweenService:Create(desc, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			elseif desc:IsA("Frame") then
				TweenService:Create(desc, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			elseif desc:IsA("UIStroke") then
				TweenService:Create(desc, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.65)
		gui:Destroy()
	end

	-- Chip cycler: a new character name every 0.5s with a pop animation.
	task.spawn(function()
		local i = 1
		while not finished do
			chip.Text = CHARACTER_CHIPS[i]
			chip.TextSize = 16
			TweenService:Create(chip, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 22 }):Play()
			i = i % #CHARACTER_CHIPS + 1
			task.wait(0.5)
		end
	end)

	-- Progress: at least 2.5s, hold at 92% until the game is loaded AND the
	-- player's character exists, then finish. Hard failsafe: 8 seconds.
	task.spawn(function()
		local elapsed = 0
		while elapsed < 2.5 and not finished do
			elapsed += 0.1
			task.wait(0.1)
			setProgress(math.min(92, elapsed / 2.5 * 92))
		end
		setProgress(92)
		while not finished do
			local loaded = game:IsLoaded()
			local hasChar = player.Character ~= nil
			if loaded and hasChar then
				finish()
				return
			end
			if os.clock() - startTime >= 8 then
				finish()
				return
			end
			task.wait(0.2)
		end
	end)

	-- Absolute failsafe: destroy the splash after 8 seconds regardless.
	task.delay(8, function()
		if not finished then
			finished = true
			gui:Destroy()
		end
	end)
end)

if not ok then
	warn("[BanditsLoading] loading screen failed: " .. tostring(err))
end
