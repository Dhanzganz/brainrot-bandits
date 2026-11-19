-- Brainrot Bandits — character factory.
-- Builds a brainrot character Model from a Config character definition,
-- an optional mutation and a scale. Every model has one Root part as its
-- PrimaryPart, a two-line nameplate, gameplay attributes, shape-specific
-- parts, Motor6D walk/idle animation and a short dance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Factory = {}

local WALK_STEP = 0.55 -- seconds per walk swing (one full stride cycle)

--------------------------------------------------------------------------------
-- Small part helpers
--------------------------------------------------------------------------------

local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function makeBall(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, Vector3.new(diameter, diameter, diameter), position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function makeWedge(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, size, position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Parent = part
	return part
end

-- Attach a limb to the root with a Motor6D so it can swing.
local function attachLimb(model: Model, root: Part, limb: Part, c0: CFrame): Motor6D
	limb.Anchored = false
	local motor = Instance.new("Motor6D")
	motor.Name = limb.Name .. "Joint"
	motor.Part0 = root
	motor.Part1 = limb
	motor.C0 = c0
	motor.Parent = root
	return motor
end

--------------------------------------------------------------------------------
-- Nameplate
--------------------------------------------------------------------------------

local function buildNameplate(model: Model, root: Part, def, mutation: string?, income: number)
	local rarity = Config.Rarities[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(176, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 19
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextColor3 = rarity.Color
	nameLabel.Text = def.Name
	nameLabel.Parent = gui

	local info = string.format("$%d/s · %s", income, string.upper(def.Rarity))
	if mutation and mutation ~= "" then
		info ..= " · " .. string.upper(mutation)
	end
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, 0, 0.45, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.55, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextSize = 14
	infoLabel.TextStrokeTransparency = 0.2
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.Text = info
	infoLabel.Parent = gui
end

--------------------------------------------------------------------------------
-- Shape builders — each adds its signature parts around the Root.
-- `s` is the scale factor; `body` / `accent` are the character colours.
--------------------------------------------------------------------------------

local function buildCup(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Coffee cup body is the Root itself; add a straw and a handle.
	local straw = makePart("Straw", Vector3.new(0.28 * s, 1.6 * s, 0.28 * s), root.Position + Vector3.new(0.5 * s, 1.6 * s, 0), accent, nil, model)
	straw.CFrame = CFrame.new(straw.Position) * CFrame.Angles(0, 0, math.rad(-18))
	local handle = makePart("Handle", Vector3.new(0.3 * s, 1.1 * s, 0.3 * s), root.Position + Vector3.new(1.15 * s, 0.2 * s, 0), body, nil, model)
	handle.CFrame = CFrame.new(handle.Position) * CFrame.Angles(0, 0, math.rad(35))
	local foam = makePart("Foam", Vector3.new(1.7 * s, 0.3 * s, 1.7 * s), root.Position + Vector3.new(0, 1.05 * s, 0), accent, nil, model)
	local lid = makePart("Lid", Vector3.new(1.9 * s, 0.25 * s, 1.9 * s), root.Position + Vector3.new(0, 0.9 * s, 0), Color3.fromRGB(60, 40, 25), nil, model)
	_ = foam
	_ = lid
end

local function buildShark(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- White belly, teeth and a tail fin.
	local belly = makePart("Belly", Vector3.new(1.3 * s, 1.0 * s, 1.9 * s), root.Position + Vector3.new(0, -0.5 * s, 0.35 * s), accent, nil, model)
	local finTop = makeWedge("DorsalFin", Vector3.new(0.25 * s, 1.1 * s, 1.0 * s), root.Position + Vector3.new(0, 1.5 * s, -0.3 * s), body, model)
	finTop.CFrame = CFrame.new(finTop.Position) * CFrame.Angles(math.rad(-25), 0, 0)
	local tail = makeWedge("TailFin", Vector3.new(0.25 * s, 1.4 * s, 1.2 * s), root.Position + Vector3.new(0, 0.3 * s, -1.6 * s), body, model)
	tail.CFrame = CFrame.new(tail.Position) * CFrame.Angles(0, 0, math.rad(90))
	for i = 1, 3 do
		local tooth = makePart("Tooth" .. i, Vector3.new(0.25 * s, 0.35 * s, 0.2 * s), root.Position + Vector3.new((i - 2) * 0.45 * s, -0.35 * s, 1.05 * s), accent, nil, model)
		_ = tooth
	end
	local eyeL = makeBall("EyeL", 0.3 * s, root.Position + Vector3.new(-0.45 * s, 0.55 * s, 0.95 * s), Color3.fromRGB(20, 20, 20), model)
	local eyeR = makeBall("EyeR", 0.3 * s, root.Position + Vector3.new(0.45 * s, 0.55 * s, 0.95 * s), Color3.fromRGB(20, 20, 20), model)
	_ = belly
	_ = eyeL
	_ = eyeR
end

local function buildWizard(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Pointy hat and a long beard.
	local hatBase = makePart("HatBrim", Vector3.new(2.4 * s, 0.25 * s, 2.4 * s), root.Position + Vector3.new(0, 1.15 * s, 0), accent, nil, model)
	local hatCone = makePart("HatCone", Vector3.new(1.2 * s, 1.6 * s, 1.2 * s), root.Position + Vector3.new(0, 2.0 * s, 0), accent, nil, model)
	local coneMesh = Instance.new("SpecialMesh")
	coneMesh.MeshType = Enum.MeshType.FileMesh
	coneMesh.MeshId = "rbxassetid://1033714"
	coneMesh.Scale = Vector3.new(1.1 * s, 1.6 * s, 1.1 * s)
	coneMesh.Parent = hatCone
	hatCone.Size = Vector3.new(1.2 * s, 1.6 * s, 1.2 * s)
	local beard = makePart("Beard", Vector3.new(0.9 * s, 1.3 * s, 0.35 * s), root.Position + Vector3.new(0, -0.15 * s, 1.0 * s), Color3.fromRGB(240, 240, 240), nil, model)
	beard.CFrame = CFrame.new(beard.Position) * CFrame.Angles(math.rad(8), 0, 0)
	local staff = makePart("Staff", Vector3.new(0.22 * s, 3.2 * s, 0.22 * s), root.Position + Vector3.new(1.25 * s, 0.4 * s, 0.2 * s), Color3.fromRGB(120, 75, 35), nil, model)
	local orb = makeBall("StaffOrb", 0.55 * s, root.Position + Vector3.new(1.25 * s, 2.1 * s, 0.2 * s), accent, model)
	orb.Material = Enum.Material.Neon
	_ = hatBase
	_ = staff
end

local function buildToilet(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Open seat and a water tank.
	local seat = makePart("Seat", Vector3.new(1.9 * s, 0.3 * s, 1.6 * s), root.Position + Vector3.new(0, 0.75 * s, 0.3 * s), accent, nil, model)
	local bowlRim = makePart("BowlRim", Vector3.new(1.7 * s, 0.25 * s, 1.4 * s), root.Position + Vector3.new(0, 0.95 * s, 0.3 * s), Color3.fromRGB(200, 225, 245), nil, model)
	local tank = makePart("Tank", Vector3.new(1.9 * s, 1.2 * s, 0.6 * s), root.Position + Vector3.new(0, 0.9 * s, -0.95 * s), body, nil, model)
	local flush = makePart("FlushButton", Vector3.new(0.4 * s, 0.2 * s, 0.4 * s), root.Position + Vector3.new(0, 1.6 * s, -0.95 * s), accent, nil, model)
	flush.Material = Enum.Material.Neon
	_ = seat
	_ = bowlRim
	_ = tank
end

local function buildDragon(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Snout, teeth and wings.
	local snout = makePart("Snout", Vector3.new(1.1 * s, 0.7 * s, 1.1 * s), root.Position + Vector3.new(0, 0.2 * s, 1.2 * s), accent, nil, model)
	for i = 1, 2 do
		local tooth = makePart("Tooth" .. i, Vector3.new(0.22 * s, 0.4 * s, 0.22 * s), root.Position + Vector3.new((i * 2 - 3) * 0.3 * s, -0.2 * s, 1.5 * s), Color3.fromRGB(255, 255, 255), nil, model)
		_ = tooth
	end
	local wingL = makeWedge("WingL", Vector3.new(0.2 * s, 1.4 * s, 1.8 * s), root.Position + Vector3.new(-1.5 * s, 0.9 * s, -0.4 * s), accent, model)
	wingL.CFrame = CFrame.new(wingL.Position) * CFrame.Angles(0, 0, math.rad(35))
	local wingR = makeWedge("WingR", Vector3.new(0.2 * s, 1.4 * s, 1.8 * s), root.Position + Vector3.new(1.5 * s, 0.9 * s, -0.4 * s), accent, model)
	wingR.CFrame = CFrame.new(wingR.Position) * CFrame.Angles(0, 0, math.rad(-35))
	local hornL = makePart("HornL", Vector3.new(0.25 * s, 0.9 * s, 0.25 * s), root.Position + Vector3.new(-0.6 * s, 1.5 * s, -0.2 * s), Color3.fromRGB(240, 220, 180), nil, model)
	local hornR = makePart("HornR", Vector3.new(0.25 * s, 0.9 * s, 0.25 * s), root.Position + Vector3.new(0.6 * s, 1.5 * s, -0.2 * s), Color3.fromRGB(240, 220, 180), nil, model)
	_ = snout
	_ = hornL
	_ = hornR
end

local function buildSamurai(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Headband and a katana.
	local band = makePart("Headband", Vector3.new(1.9 * s, 0.35 * s, 1.9 * s), root.Position + Vector3.new(0, 1.05 * s, 0), accent, nil, model)
	local knotL = makePart("BandTailL", Vector3.new(0.25 * s, 1.0 * s, 0.15 * s), root.Position + Vector3.new(-0.7 * s, 0.6 * s, -0.95 * s), accent, nil, model)
	knotL.CFrame = CFrame.new(knotL.Position) * CFrame.Angles(math.rad(15), 0, math.rad(12))
	local blade = makePart("KatanaBlade", Vector3.new(0.18 * s, 2.2 * s, 0.45 * s), root.Position + Vector3.new(1.3 * s, 0.6 * s, 0.3 * s), Color3.fromRGB(220, 225, 235), Enum.Material.Metal, model)
	blade.CFrame = CFrame.new(blade.Position) * CFrame.Angles(math.rad(20), 0, math.rad(-25))
	local grip = makePart("KatanaGrip", Vector3.new(0.25 * s, 0.7 * s, 0.3 * s), root.Position + Vector3.new(1.05 * s, -0.35 * s, 0.15 * s), Color3.fromRGB(30, 30, 35), nil, model)
	grip.CFrame = CFrame.new(grip.Position) * CFrame.Angles(math.rad(20), 0, math.rad(-25))
	local armor = makePart("ShoulderPad", Vector3.new(2.3 * s, 0.4 * s, 1.6 * s), root.Position + Vector3.new(0, 0.85 * s, 0), Color3.fromRGB(40, 40, 45), Enum.Material.Metal, model)
	_ = band
	_ = armor
end

local function buildCroc(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Long snout and back spikes.
	local snout = makePart("Snout", Vector3.new(1.2 * s, 0.6 * s, 2.0 * s), root.Position + Vector3.new(0, -0.1 * s, 1.6 * s), body, nil, model)
	local noseL = makeBall("NostrilL", 0.22 * s, root.Position + Vector3.new(-0.35 * s, 0.3 * s, 2.5 * s), accent, model)
	local noseR = makeBall("NostrilR", 0.22 * s, root.Position + Vector3.new(0.35 * s, 0.3 * s, 2.5 * s), accent, model)
	for i = 1, 4 do
		local spike = makePart("Spike" .. i, Vector3.new(0.35 * s, 0.7 * s, 0.35 * s), root.Position + Vector3.new(0, 1.15 * s, (i - 2.5) * 0.75 * s), accent, nil, model)
		spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(math.rad(-20), 0, 0)
		_ = spike
	end
	local tail = makePart("Tail", Vector3.new(0.9 * s, 0.7 * s, 2.2 * s), root.Position + Vector3.new(0, -0.2 * s, -1.9 * s), body, nil, model)
	tail.CFrame = CFrame.new(tail.Position) * CFrame.Angles(math.rad(6), 0, 0)
	_ = noseL
	_ = noseR
end

local function buildPlane(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Twin spinning propellers (spun by a Heartbeat loop in Factory.new).
	local propL = makePart("PropellerL", Vector3.new(0.15 * s, 2.2 * s, 0.3 * s), root.Position + Vector3.new(-0.7 * s, 0.2 * s, 1.6 * s), accent, nil, model)
	local propR = makePart("PropellerR", Vector3.new(0.15 * s, 2.2 * s, 0.3 * s), root.Position + Vector3.new(0.7 * s, 0.2 * s, 1.6 * s), accent, nil, model)
	local hubL = makeBall("PropHubL", 0.4 * s, root.Position + Vector3.new(-0.7 * s, 0.2 * s, 1.6 * s), Color3.fromRGB(40, 40, 45), model)
	local hubR = makeBall("PropHubR", 0.4 * s, root.Position + Vector3.new(0.7 * s, 0.2 * s, 1.6 * s), Color3.fromRGB(40, 40, 45), model)
	local wing = makePart("Wing", Vector3.new(4.2 * s, 0.25 * s, 1.2 * s), root.Position + Vector3.new(0, 0.5 * s, -0.2 * s), body, nil, model)
	local tailWing = makePart("TailWing", Vector3.new(2.0 * s, 0.2 * s, 0.8 * s), root.Position + Vector3.new(0, 0.4 * s, -1.4 * s), body, nil, model)
	_ = hubL
	_ = hubR
	_ = wing
	_ = tailWing
	return { propL, propR }
end

local function buildLog(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- A drumstick and a drum beater.
	local stick = makePart("Drumstick", Vector3.new(0.25 * s, 2.0 * s, 0.25 * s), root.Position + Vector3.new(1.2 * s, 0.5 * s, 0.4 * s), accent, nil, model)
	stick.CFrame = CFrame.new(stick.Position) * CFrame.Angles(0, 0, math.rad(-30))
	local beater = makeBall("Beater", 0.55 * s, root.Position + Vector3.new(1.55 * s, 1.5 * s, 0.4 * s), Color3.fromRGB(240, 220, 180), model)
	local drum = makePart("Drum", Vector3.new(1.4 * s, 0.9 * s, 0.9 * s), root.Position + Vector3.new(0, -0.6 * s, 1.0 * s), accent, nil, model)
	local rings = makePart("LogRing", Vector3.new(2.05 * s, 0.3 * s, 2.05 * s), root.Position + Vector3.new(0, 0.9 * s, 0), Color3.fromRGB(90, 55, 25), nil, model)
	_ = beater
	_ = drum
	_ = rings
end

local function buildDancer(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Tutu and ballet shoes.
	local tutu = makePart("Tutu", Vector3.new(2.8 * s, 0.3 * s, 2.8 * s), root.Position + Vector3.new(0, -0.35 * s, 0), accent, nil, model)
	local tutuTrim = makePart("TutuTrim", Vector3.new(2.5 * s, 0.2 * s, 2.5 * s), root.Position + Vector3.new(0, -0.5 * s, 0), body, nil, model)
	local shoeL = makePart("BalletShoeL", Vector3.new(0.5 * s, 0.3 * s, 0.9 * s), root.Position + Vector3.new(-0.45 * s, -1.15 * s, 0.3 * s), accent, nil, model)
	local shoeR = makePart("BalletShoeR", Vector3.new(0.5 * s, 0.3 * s, 0.9 * s), root.Position + Vector3.new(0.45 * s, -1.15 * s, 0.3 * s), accent, nil, model)
	local bun = makeBall("HairBun", 0.6 * s, root.Position + Vector3.new(0, 1.5 * s, -0.3 * s), Color3.fromRGB(120, 70, 40), model)
	local cupTop = makePart("CupTop", Vector3.new(1.2 * s, 0.5 * s, 1.2 * s), root.Position + Vector3.new(0, 1.3 * s, 0), body, nil, model)
	_ = tutuTrim
	_ = shoeL
	_ = shoeR
	_ = bun
	_ = cupTop
end

local SHAPE_BUILDERS = {
	cup = buildCup,
	shark = buildShark,
	wizard = buildWizard,
	toilet = buildToilet,
	dragon = buildDragon,
	samurai = buildSamurai,
	croc = buildCroc,
	plane = buildPlane,
	log = buildLog,
	dancer = buildDancer,
}

--------------------------------------------------------------------------------
-- Mutation visuals
--------------------------------------------------------------------------------

local function applyMutation(model: Model, root: Part, mutation: string?)
	if not mutation or mutation == "" then
		return
	end
	local info = Config.Mutations[mutation]
	if not info then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			if mutation == "Gold" then
				descendant.Color = info.Color
				descendant.Material = Enum.Material.Metal
			elseif mutation == "Diamond" then
				descendant.Color = info.Color
				descendant.Material = Enum.Material.Glass
				descendant.Transparency = 0.15
			end
		end
	end
	if mutation == "Rainbow" then
		task.spawn(function()
			local hue = 0
			while model.Parent do
				hue = (hue + 0.01) % 1
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
						descendant.Color = Color3.fromHSV(hue, 0.7, 1)
					end
				end
				task.wait(0.1)
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Rarity effects: Epic+ gets sparkles + a point light; Mythic also gets an
-- aura ring and orbiting orbs.
--------------------------------------------------------------------------------

local function applyRarityEffects(model: Model, root: Part, def)
	local order = Config.Rarities[def.Rarity].Order
	if order < 3 then
		return
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "RaritySparkles"
	sparkles.SparkleColor = Config.Rarities[def.Rarity].Color
	sparkles.Parent = root

	local light = Instance.new("PointLight")
	light.Name = "RarityLight"
	light.Color = Config.Rarities[def.Rarity].Color
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = root

	if def.Rarity ~= "Mythic" then
		return
	end

	-- Aura ring lying flat under the character.
	local ring = makePart("AuraRing", Vector3.new(3.4, 0.15, 3.4), root.Position + Vector3.new(0, -1.2, 0), Config.Rarities.Mythic.Color, Enum.Material.Neon, model)
	local ringMesh = Instance.new("SpecialMesh")
	ringMesh.MeshType = Enum.MeshType.Cylinder
	ringMesh.Parent = ring

	-- Orbiting orbs.
	local orbs = {}
	for i = 1, 3 do
		local orb = makeBall("OrbitOrb" .. i, 0.45, root.Position + Vector3.new(2, 0.5, 0), Config.Rarities.Mythic.Color, model)
		orb.Material = Enum.Material.Neon
		orb.Anchored = true
		table.insert(orbs, orb)
	end
	task.spawn(function()
		local angle = 0
		while model.Parent do
			angle += 0.045
			for i, orb in ipairs(orbs) do
				local a = angle + (i - 1) * (math.pi * 2 / 3)
				local base = root.Position
				orb.Position = Vector3.new(
					base.X + math.cos(a) * 2.1,
					base.Y + 0.5 + math.sin(angle * 2 + i) * 0.3,
					base.Z + math.sin(a) * 2.1
				)
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

--------------------------------------------------------------------------------
-- Animation: Motor6D walk (legs swing, body bobs), idle breathing, dance.
--------------------------------------------------------------------------------

-- Starts the walk loop on a model built by Factory.new.
-- Returns a stop function.
function Factory.StartWalk(model: Model)
	local root = model.PrimaryPart
	if not root then
		return function() end
	end
	local legL = root:FindFirstChild("LegLJoint") :: Motor6D?
	local legR = root:FindFirstChild("LegRJoint") :: Motor6D?
	local running = true
	model:SetAttribute("Status", "Walking")
	task.spawn(function()
		local t = 0
		while running and model.Parent do
			t += RunService.Heartbeat:Wait()
			local swing = math.sin(t * (math.pi * 2 / WALK_STEP)) * 0.6
			if legL then
				legL.Transform = CFrame.Angles(swing, 0, 0)
			end
			if legR then
				legR.Transform = CFrame.Angles(-swing, 0, 0)
			end
		end
		if legL then
			legL.Transform = CFrame.new()
		end
		if legR then
			legR.Transform = CFrame.new()
		end
	end)
	return function()
		running = false
		model:SetAttribute("Status", "Idle")
	end
end

-- Gentle idle breathing: the root slowly scales/pulses via a small Y bob.
-- Returns a stop function.
function Factory.PlayIdle(model: Model)
	local root = model.PrimaryPart
	if not root then
		return function() end
	end
	local running = true
	model:SetAttribute("Status", "Idle")
	task.spawn(function()
		local t = 0
		local lastBreath = 0
		while running and model.Parent do
			t += RunService.Heartbeat:Wait()
			local breath = math.sin(t * 1.8) * 0.08
			local pos = root.Position
			root.Position = Vector3.new(pos.X, pos.Y + (breath - lastBreath), pos.Z)
			lastBreath = breath
		end
	end)
	return function()
		running = false
	end
end

-- Short dance: two hops, then a full 360-degree spin.
function Factory.PlayDance(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	model:SetAttribute("Status", "Dancing")
	task.spawn(function()
		local startCFrame = root.CFrame
		local hopInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _ = 1, 2 do
			if not model.Parent then
				return
			end
			local up = TweenService:Create(root, hopInfo, { CFrame = startCFrame + Vector3.new(0, 1.6, 0) })
			up:Play()
			up.Completed:Wait()
			local down = TweenService:Create(root, hopInfo, { CFrame = startCFrame })
			down:Play()
			down.Completed:Wait()
		end
		if not model.Parent then
			return
		end
		local spinInfo = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local spin = TweenService:Create(root, spinInfo, { CFrame = startCFrame * CFrame.Angles(0, math.pi * 2, 0) })
		spin:Play()
		spin.Completed:Wait()
		if model.Parent then
			model:SetAttribute("Status", "Idle")
		end
	end)
end

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

-- Build a character model from a definition, an optional mutation
-- ("Gold", "Diamond", "Rainbow" or nil) and a scale factor (default 1).
function Factory.new(def, mutation: string?, scale: number?): Model
	local s = scale or 1
	local rarity = Config.Rarities[def.Rarity]
	local mutationInfo = (mutation and mutation ~= "") and Config.Mutations[mutation] or nil
	local income = def.Income * (mutationInfo and mutationInfo.Multiplier or 1)

	local model = Instance.new("Model")
	model.Name = def.Name

	-- Root: the body block. Size varies a little by rarity so rarer
	-- characters read bigger on the lane.
	local rootSize = Vector3.new(2 * s, 2.2 * s, 2 * s) * (1 + (rarity.Order - 1) * 0.08)
	local root = makePart("Root", rootSize, Vector3.new(0, 2.2 * s, 0), def.BodyColor, nil, model)
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	model.PrimaryPart = root

	-- Eyes on the front face.
	local eyeL = makeBall("EyeL", 0.32 * s, root.Position + Vector3.new(-0.45 * s, 0.45 * s, rootSize.Z / 2), Color3.fromRGB(20, 20, 20), model)
	local eyeR = makeBall("EyeR", 0.32 * s, root.Position + Vector3.new(0.45 * s, 0.45 * s, rootSize.Z / 2), Color3.fromRGB(20, 20, 20), model)
	_ = eyeL
	_ = eyeR

	-- Legs on Motor6D joints so the walk animation can swing them.
	local legL = makePart("LegL", Vector3.new(0.6 * s, 1.0 * s, 0.6 * s), root.Position + Vector3.new(-0.5 * s, -1.5 * s, 0), def.AccentColor, nil, model)
	local legR = makePart("LegR", Vector3.new(0.6 * s, 1.0 * s, 0.6 * s), root.Position + Vector3.new(0.5 * s, -1.5 * s, 0), def.AccentColor, nil, model)
	attachLimb(model, root, legL, CFrame.new(-0.5 * s, -1.1 * s, 0))
	attachLimb(model, root, legR, CFrame.new(0.5 * s, -1.1 * s, 0))

	-- Arms, also jointed.
	local armL = makePart("ArmL", Vector3.new(0.5 * s, 1.4 * s, 0.5 * s), root.Position + Vector3.new(-1.3 * s, 0.1 * s, 0), def.BodyColor, nil, model)
	local armR = makePart("ArmR", Vector3.new(0.5 * s, 1.4 * s, 0.5 * s), root.Position + Vector3.new(1.3 * s, 0.1 * s, 0), def.BodyColor, nil, model)
	attachLimb(model, root, armL, CFrame.new(-1.05 * s, 0.9 * s, 0))
	attachLimb(model, root, armR, CFrame.new(1.05 * s, 0.9 * s, 0))

	-- Shape-specific signature parts.
	local builder = SHAPE_BUILDERS[def.Shape]
	local propellers = nil
	if builder then
		local result = builder(model, root, s, def.BodyColor, def.AccentColor)
		if def.Shape == "plane" then
			propellers = result
		end
	end

	-- Twin propellers spin forever on the plane.
	if propellers then
		task.spawn(function()
			local angle = 0
			while model.Parent do
				angle += 0.35
				for _, prop in ipairs(propellers) do
					prop.CFrame = CFrame.new(prop.Position) * CFrame.Angles(0, 0, angle)
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end

	applyMutation(model, root, mutation)
	applyRarityEffects(model, root, def)
	buildNameplate(model, root, def, mutation, income)

	-- Gameplay attributes.
	model:SetAttribute("CharacterName", def.Name)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Mutation", mutation or "")
	model:SetAttribute("Price", def.Price)
	model:SetAttribute("Income", income)
	model:SetAttribute("Status", "Idle")

	return model
end

return Factory
