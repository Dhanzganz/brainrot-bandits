-- Effects.luau
-- Shared visual-effects module for Brainrot Bandits.
-- Client-side only in practice: the server never calls these directly,
-- it only fires RemoteEvents and the client drives the visuals.
-- Safe to require from either side (all services are fetched lazily).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Effects = {}

-- ---------------------------------------------------------------------------
-- Base look: bright daytime (R27b — the owner ordered the night gone:
-- "langitnya terangin aja jangan malam"). Snapshot so events can
-- restore it.
-- ---------------------------------------------------------------------------

local BASE = {
	ClockTime = 13.5,
	FogColor = Color3.fromRGB(168, 196, 232),
	FogStart = 300,
	FogEnd = 900,
	Brightness = 2.2,
	Ambient = Color3.fromRGB(140, 155, 190),
	OutdoorAmbient = Color3.fromRGB(170, 185, 215),
	ExposureCompensation = 0,
	BloomIntensity = 0.05,
	ColorCorrectionSaturation = 0.15,
}

-- The server owns the base time of day (admin day/night toggle); clients
-- read it from a ReplicatedStorage attribute so an event look ending
-- restores the CURRENT base time, not a hard-coded one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function baseClockTime()
	local value = ReplicatedStorage:GetAttribute("BaseClockTime")
	if type(value) == "number" then
		return value
	end
	return BASE.ClockTime
end

local _snapshot = nil

local function snapshotLighting()
	_snapshot = {
		ClockTime = Lighting.ClockTime,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if bloom then
		_snapshot.BloomIntensity = bloom.Intensity
	end
	if cc then
		_snapshot.ColorCorrectionSaturation = cc.Saturation
	end
	if rays then
		_snapshot.SunRaysEnabled = rays.Enabled
	end
	if atmo then
		_snapshot.AtmosphereDensity = atmo.Density
	end
end

local function applyBaseToLighting()
	Lighting.ClockTime = baseClockTime()
	Lighting.FogColor = BASE.FogColor
	Lighting.FogStart = BASE.FogStart
	Lighting.FogEnd = BASE.FogEnd
	Lighting.Brightness = BASE.Brightness
	Lighting.Ambient = BASE.Ambient
	Lighting.OutdoorAmbient = BASE.OutdoorAmbient
	Lighting.ExposureCompensation = BASE.ExposureCompensation
end

local function getOrCreate(className, name)
	local inst = Lighting:FindFirstChild(name)
	if inst and inst:IsA(className) then
		return inst
	end
	if inst then
		inst:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

function Effects.SetupLighting()
	applyBaseToLighting()

	local bloom = getOrCreate("BloomEffect", "BanditsBloom")
	bloom.Intensity = BASE.BloomIntensity
	bloom.Size = 24
	bloom.Threshold = 0.9

	local cc = getOrCreate("ColorCorrectionEffect", "BanditsColor")
	cc.Saturation = BASE.ColorCorrectionSaturation
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 246, 235)

	local rays = getOrCreate("SunRaysEffect", "BanditsSunRays")
	rays.Intensity = 0.08
	rays.Spread = 0.7

	local atmo = getOrCreate("Atmosphere", "BanditsAtmosphere")
	atmo.Density = 0.25
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(168, 196, 232)
	atmo.Decay = Color3.fromRGB(120, 150, 200)
	atmo.Glare = 0.25
	atmo.Haze = 1.2

	snapshotLighting()
end

-- ---------------------------------------------------------------------------
-- Small builders
-- ---------------------------------------------------------------------------

-- Sparkles: a looping sparkle particle emitter on a parent part/model.
-- parent: Instance, color: Color3, rate: number, size: number
function Effects.Sparkles(parent, color, rate, size)
	if not parent then
		return nil
	end
	local attach = parent:IsA("BasePart") and parent or nil
	if not attach then
		local root = parent:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			attach = root
		else
			return nil
		end
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BanditsSparkles"
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = rate or 12
	emitter.Lifetime = NumberRange.new(0.6, 1.4)
	emitter.Size = NumberSequence.new(size or 0.35)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.6
	emitter.Parent = attach
	return emitter
end

-- Glow: a PointLight on a parent part/model.
function Effects.Glow(parent, color, brightness, range)
	if not parent then
		return nil
	end
	local attach = parent:IsA("BasePart") and parent or nil
	if not attach then
		local root = parent:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			attach = root
		else
			return nil
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "BanditsGlow"
	light.Color = color or Color3.fromRGB(255, 220, 100)
	light.Brightness = brightness or 1.5
	light.Range = range or 12
	light.Parent = attach
	return light
end

-- Burst: a one-shot particle explosion at a world position.
function Effects.Burst(position, color)
	local anchor = Instance.new("Part")
	anchor.Name = "BanditsBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 215, 0))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = 0.8
	emitter.Parent = anchor
	emitter:Emit(40)

	Debris:AddItem(anchor, 1.5)
	return anchor
end

-- SpawnPortal: ring + light + sparkles where a character spawns.
function Effects.SpawnPortal(position, color)
	local portalColor = color or Color3.fromRGB(255, 120, 220)
	local anchor = Instance.new("Part")
	anchor.Name = "BanditsPortal"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	anchor.Parent = workspace

	local ring = Instance.new("Part")
	ring.Name = "PortalRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 6, 6)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = portalColor
	ring.Transparency = 0.2
	ring.Parent = anchor

	local light = Instance.new("PointLight")
	light.Color = portalColor
	light.Brightness = 3
	light.Range = 16
	light.Parent = anchor

	Effects.Sparkles(anchor, portalColor, 30, 0.5)

	local tween = TweenService:Create(
		ring,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, 0.5, 0.5), Transparency = 1 }
	)
	tween:Play()
	Debris:AddItem(anchor, 1.2)
	return anchor
end

-- Flash: a brief white flash across a model (used on pickup / delivery).
function Effects.Flash(model)
	if not model then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "BanditsFlash"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1 }
	)
	tween:Play()
	Debris:AddItem(highlight, 0.8)
end

-- IncomePopup: floating "+$X" text at a world position.
function Effects.IncomePopup(position, text)
	local anchor = Instance.new("Part")
	anchor.Name = "BanditsPopup"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Name = "PopupGui"
	gui.Size = UDim2.new(0, 120, 0, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui

	local tween = TweenService:Create(
		anchor,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) }
	)
	tween:Play()
	Debris:AddItem(anchor, 1.3)
	return anchor
end

-- AuraRing: golden ring + orbiting orbs for Mythic characters.
function Effects.AuraRing(model, color)
	if not model then
		return nil
	end
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local auraColor = color or Color3.fromRGB(255, 215, 0)

	local folder = Instance.new("Folder")
	folder.Name = "BanditsAura"
	folder.Parent = model

	local ring = Instance.new("Part")
	ring.Name = "AuraRing"
	ring.Anchored = false
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Massless = true
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, 5, 5)
	ring.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = auraColor
	ring.Transparency = 0.35
	ring.Parent = folder

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring

	-- Orbiting orbs (animated by a lightweight heartbeat-free spin via Tween loop).
	local orbs = {}
	for i = 1, 3 do
		local orb = Instance.new("Part")
		orb.Name = "AuraOrb" .. i
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(0.7, 0.7, 0.7)
		orb.Material = Enum.Material.Neon
		orb.Color = auraColor
		orb.Parent = folder
		orbs[i] = orb
	end

	-- Spin the orbs around the root with a coroutine (stops when the model leaves).
	task.spawn(function()
		local angle = 0
		while folder.Parent == model and root.Parent == model do
			angle += 0.06
			for i, orb in ipairs(orbs) do
				local a = angle + (i - 1) * (math.pi * 2 / 3)
				local pos = root.Position + Vector3.new(math.cos(a) * 2.6, 1.2 + math.sin(angle * 2 + i) * 0.4, math.sin(a) * 2.6)
				orb.CFrame = CFrame.new(pos)
			end
			task.wait(0.03)
		end
	end)

	Effects.Glow(root, auraColor, 1.2, 10)
	return folder
end

-- ---------------------------------------------------------------------------
-- Events: recolor the world for a live event, restore afterwards.
-- ---------------------------------------------------------------------------

local EVENT_LOOKS = {
	Rainbow = {
		FogColor = Color3.fromRGB(255, 180, 220),
		Ambient = Color3.fromRGB(200, 130, 180),
		OutdoorAmbient = Color3.fromRGB(220, 150, 200),
		BloomIntensity = 0.6,
		ColorCorrectionSaturation = 0.6,
		ExposureCompensation = 0,
	},
	Mythic = {
		FogColor = Color3.fromRGB(120, 90, 200),
		Ambient = Color3.fromRGB(90, 70, 150),
		OutdoorAmbient = Color3.fromRGB(110, 80, 180),
		BloomIntensity = 0.55,
		ColorCorrectionSaturation = 0.45,
		ExposureCompensation = -0.05,
	},
}

function Effects.StartEventFX(kind)
	if not _snapshot then
		snapshotLighting()
	end
	local look = EVENT_LOOKS[kind]
	if not look then
		return
	end
	Lighting.FogColor = look.FogColor
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.ExposureCompensation = look.ExposureCompensation
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = look.BloomIntensity
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.Saturation = look.ColorCorrectionSaturation
	end
end

function Effects.StopEventFX()
	if _snapshot then
		Lighting.ClockTime = _snapshot.ClockTime
		Lighting.FogColor = _snapshot.FogColor
		Lighting.FogStart = _snapshot.FogStart
		Lighting.FogEnd = _snapshot.FogEnd
		Lighting.Brightness = _snapshot.Brightness
		Lighting.Ambient = _snapshot.Ambient
		Lighting.OutdoorAmbient = _snapshot.OutdoorAmbient
		Lighting.ExposureCompensation = _snapshot.ExposureCompensation
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if bloom and _snapshot.BloomIntensity then
			bloom.Intensity = _snapshot.BloomIntensity
		end
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc and _snapshot.ColorCorrectionSaturation then
			cc.Saturation = _snapshot.ColorCorrectionSaturation
		end
	else
		applyBaseToLighting()
	end
	-- Whatever the snapshot held, the base clock follows the server's
	-- current BaseClockTime (an admin may have flipped day/night while
	-- the event look was up).
	Lighting.ClockTime = baseClockTime()
end

return Effects
