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

local function makeCylinder(name: string, diameter: number, height: number, position: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, Vector3.new(diameter, height, diameter), position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = part
	return part
end

-- A sphere-mesh part with an arbitrary size: renders as a rounded
-- ellipsoid filling the part's box (squashed balls, rounded torsos).
local function makeEllipsoid(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, size, position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function addSphereMesh(part: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function addCylinderMesh(part: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = part
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

local function buildNameplate(model: Model, root: Part, def, mutation: string?, income: number, plateScale: number)
	local rarity = Config.Rarities[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(176, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4 * plateScale, 0)
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
	-- The rounded Root is the golem's body; on top sits a cappuccino:
	-- a squashed foam dome over a lid disc, a round straw, a handle.
	local foam = makeEllipsoid("Foam", Vector3.new(1.9 * s, 0.55 * s, 1.9 * s), root.Position + Vector3.new(0, 1.12 * s, 0), accent, model)
	local lid = makeCylinder("Lid", 2.0 * s, 0.22 * s, root.Position + Vector3.new(0, 0.92 * s, 0), Color3.fromRGB(60, 40, 25), model)
	local straw = makeCylinder("Straw", 0.28 * s, 1.6 * s, root.Position + Vector3.new(0.5 * s, 1.6 * s, 0), accent, model)
	straw.CFrame = CFrame.new(straw.Position) * CFrame.Angles(0, 0, math.rad(-18))
	local handle = makeCylinder("Handle", 0.3 * s, 1.1 * s, root.Position + Vector3.new(1.15 * s, 0.2 * s, 0), body, model)
	handle.CFrame = CFrame.new(handle.Position) * CFrame.Angles(0, 0, math.rad(35))
	_ = foam
	_ = lid
end

local function buildShark(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Rounded cream belly (the accent pulled a quarter toward the
	-- banana body colour — a shaded underside, not flat white),
	-- wedge teeth and fins on the ellipsoid body.
	-- (No extra eyes here: the constructor's pair is placed for the
	-- rounded body — a second pair used to hide inside the old box.)
	local belly = makeEllipsoid("Belly", Vector3.new(1.5 * s, 1.1 * s, 2.0 * s), root.Position + Vector3.new(0, -0.45 * s, 0.3 * s), accent:Lerp(body, 0.25), model)
	local finTop = makeWedge("DorsalFin", Vector3.new(0.25 * s, 1.1 * s, 1.0 * s), root.Position + Vector3.new(0, 1.5 * s, -0.3 * s), body, model)
	finTop.CFrame = CFrame.new(finTop.Position) * CFrame.Angles(math.rad(-25), 0, 0)
	local tail = makeWedge("TailFin", Vector3.new(0.25 * s, 1.4 * s, 1.2 * s), root.Position + Vector3.new(0, 0.3 * s, -1.6 * s), body, model)
	tail.CFrame = CFrame.new(tail.Position) * CFrame.Angles(0, 0, math.rad(90))
	for i = 1, 3 do
		local tooth = makeWedge("Tooth" .. i, Vector3.new(0.28 * s, 0.4 * s, 0.2 * s), root.Position + Vector3.new((i - 2) * 0.45 * s, -0.4 * s, 1.0 * s), accent, model)
		tooth.CFrame = CFrame.new(tooth.Position) * CFrame.Angles(math.rad(180), 0, 0)
		_ = tooth
	end
	_ = belly
end

local function buildWizard(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Round hat brim with the cone hat mesh, a soft ellipsoid beard and
	-- a round staff with a glowing orb. The Root is his robe — Fabric.
	root.Material = Enum.Material.Fabric
	local hatBase = makeCylinder("HatBrim", 2.4 * s, 0.25 * s, root.Position + Vector3.new(0, 1.15 * s, 0), accent, model)
	local hatCone = makePart("HatCone", Vector3.new(1.2 * s, 1.6 * s, 1.2 * s), root.Position + Vector3.new(0, 2.0 * s, 0), accent, nil, model)
	local coneMesh = Instance.new("SpecialMesh")
	coneMesh.MeshType = Enum.MeshType.FileMesh
	coneMesh.MeshId = "rbxassetid://1033714"
	coneMesh.Scale = Vector3.new(1.1 * s, 1.6 * s, 1.1 * s)
	coneMesh.Parent = hatCone
	hatCone.Size = Vector3.new(1.2 * s, 1.6 * s, 1.2 * s)
	local beard = makeEllipsoid("Beard", Vector3.new(0.95 * s, 1.35 * s, 0.4 * s), root.Position + Vector3.new(0, -0.15 * s, 0.95 * s), Color3.fromRGB(240, 240, 240), model)
	beard.CFrame = CFrame.new(beard.Position) * CFrame.Angles(math.rad(8), 0, 0)
	local staff = makeCylinder("Staff", 0.22 * s, 3.2 * s, root.Position + Vector3.new(1.25 * s, 0.4 * s, 0.2 * s), Color3.fromRGB(120, 75, 35), model)
	local orb = makeBall("StaffOrb", 0.55 * s, root.Position + Vector3.new(1.25 * s, 2.1 * s, 0.2 * s), accent, model)
	orb.Material = Enum.Material.Neon
	_ = hatBase
	_ = staff
end

local function buildToilet(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Round seat and rim discs, a squashed-sphere tank, a flush nub.
	local seat = makeCylinder("Seat", 1.9 * s, 0.3 * s, root.Position + Vector3.new(0, 0.75 * s, 0.3 * s), accent, model)
	local bowlRim = makeCylinder("BowlRim", 1.7 * s, 0.25 * s, root.Position + Vector3.new(0, 0.95 * s, 0.3 * s), Color3.fromRGB(200, 225, 245), model)
	local tank = makeEllipsoid("Tank", Vector3.new(1.9 * s, 1.25 * s, 0.65 * s), root.Position + Vector3.new(0, 0.9 * s, -0.9 * s), body, model)
	local flush = makeCylinder("FlushButton", 0.4 * s, 0.2 * s, root.Position + Vector3.new(0, 1.6 * s, -0.9 * s), accent, model)
	flush.Material = Enum.Material.Neon
	_ = seat
	_ = bowlRim
	_ = tank
end

local function buildDragon(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Rounded snout, teeth, round horns and waffle wings: each wing is
	-- two stacked waffle-tan cylinders, like a round waffle held out.
	local snout = makeEllipsoid("Snout", Vector3.new(1.15 * s, 0.75 * s, 1.2 * s), root.Position + Vector3.new(0, 0.15 * s, 1.15 * s), accent, model)
	for i = 1, 2 do
		local tooth = makePart("Tooth" .. i, Vector3.new(0.22 * s, 0.4 * s, 0.22 * s), root.Position + Vector3.new((i * 2 - 3) * 0.3 * s, -0.25 * s, 1.45 * s), Color3.fromRGB(255, 255, 255), nil, model)
		_ = tooth
	end
	local waffle = Color3.fromRGB(226, 170, 88)
	local waffleDark = Color3.fromRGB(186, 128, 52)
	for _, side in ipairs({ -1, 1 }) do
		local wingName = if side < 0 then "WingL" else "WingR"
		local wing = makeCylinder(wingName, 1.9 * s, 0.2 * s, root.Position + Vector3.new(side * 1.55 * s, 0.95 * s, -0.35 * s), waffle, model)
		wing.CFrame = CFrame.new(wing.Position) * CFrame.Angles(0, 0, math.rad(side * -28))
		local topName = if side < 0 then "WingTopL" else "WingTopR"
		local wingTop = makeCylinder(topName, 1.25 * s, 0.16 * s, root.Position + Vector3.new(side * 1.62 * s, 1.12 * s, -0.35 * s), waffleDark, model)
		wingTop.CFrame = CFrame.new(wingTop.Position) * CFrame.Angles(0, 0, math.rad(side * -28))
	end
	local hornL = makeCylinder("HornL", 0.25 * s, 0.9 * s, root.Position + Vector3.new(-0.6 * s, 1.5 * s, -0.2 * s), Color3.fromRGB(240, 220, 180), model)
	local hornR = makeCylinder("HornR", 0.25 * s, 0.9 * s, root.Position + Vector3.new(0.6 * s, 1.5 * s, -0.2 * s), Color3.fromRGB(240, 220, 180), model)
	_ = snout
	_ = hornL
	_ = hornR
end

local function buildSamurai(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- A cylinder headband sitting low on the rounded head (the band's
	-- radius matches the ellipsoid's cross-section at that height), a
	-- katana, and a rounded shoulder pad.
	local band = makeCylinder("Headband", 2.0 * s, 0.35 * s, root.Position + Vector3.new(0, 0.72 * s, 0), accent, model)
	local knotL = makeCylinder("BandTailL", 0.22 * s, 1.0 * s, root.Position + Vector3.new(-0.7 * s, 0.35 * s, -0.9 * s), accent, model)
	knotL.CFrame = CFrame.new(knotL.Position) * CFrame.Angles(math.rad(15), 0, math.rad(12))
	local blade = makePart("KatanaBlade", Vector3.new(0.18 * s, 2.2 * s, 0.45 * s), root.Position + Vector3.new(1.3 * s, 0.6 * s, 0.3 * s), Color3.fromRGB(220, 225, 235), Enum.Material.Metal, model)
	blade.CFrame = CFrame.new(blade.Position) * CFrame.Angles(math.rad(20), 0, math.rad(-25))
	local grip = makeCylinder("KatanaGrip", 0.28 * s, 0.7 * s, root.Position + Vector3.new(1.05 * s, -0.35 * s, 0.15 * s), Color3.fromRGB(30, 30, 35), model)
	grip.CFrame = CFrame.new(grip.Position) * CFrame.Angles(math.rad(20), 0, math.rad(-25))
	local armor = makeEllipsoid("ShoulderPad", Vector3.new(2.35 * s, 0.5 * s, 1.7 * s), root.Position + Vector3.new(0, 0.8 * s, 0), Color3.fromRGB(40, 40, 45), model)
	armor.Material = Enum.Material.Metal
	_ = band
	_ = armor
end

local function buildCroc(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Long rounded snout (a cylinder laid along Z), nostril balls,
	-- wedge back spikes and a squashed-sphere tail.
	local snout = makeCylinder("Snout", 1.15 * s, 2.0 * s, root.Position + Vector3.new(0, -0.1 * s, 1.55 * s), body, model)
	snout.CFrame = CFrame.new(snout.Position) * CFrame.Angles(math.rad(90), 0, 0)
	local noseL = makeBall("NostrilL", 0.22 * s, root.Position + Vector3.new(-0.35 * s, 0.28 * s, 2.4 * s), accent, model)
	local noseR = makeBall("NostrilR", 0.22 * s, root.Position + Vector3.new(0.35 * s, 0.28 * s, 2.4 * s), accent, model)
	for i = 1, 4 do
		local spike = makeWedge("Spike" .. i, Vector3.new(0.35 * s, 0.7 * s, 0.35 * s), root.Position + Vector3.new(0, 1.15 * s, (i - 2.5) * 0.75 * s), accent, model)
		spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(math.rad(-20), 0, 0)
		_ = spike
	end
	local tail = makeEllipsoid("Tail", Vector3.new(0.95 * s, 0.7 * s, 2.2 * s), root.Position + Vector3.new(0, -0.2 * s, -1.85 * s), body, model)
	tail.CFrame = CFrame.new(tail.Position) * CFrame.Angles(math.rad(6), 0, 0)
	_ = noseL
	_ = noseR
end

local function buildPlane(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Canonical Bombardiro Crocodilo: a crocodile head on a military
	-- BOMBER — olive-drab metal fuselage and wings, a green croc
	-- snout with teeth at the nose, a glass bubble cockpit, twin
	-- spinning propellers (spun by a Heartbeat loop in Factory.new)
	-- and bombs slung under the wings. The constructor's mouth line
	-- goes: on this character the teeth are the mouth.
	local mouthPart = model:FindFirstChild("Mouth")
	if mouthPart then
		mouthPart:Destroy()
	end
	local olive = Color3.fromRGB(105, 110, 70)
	local oliveDark = Color3.fromRGB(84, 90, 56)
	root.Color = olive
	root.Material = Enum.Material.Metal
	local snout = makeEllipsoid("Snout", Vector3.new(1.5 * s, 0.85 * s, 1.7 * s), root.Position + Vector3.new(0, -0.4 * s, 1.3 * s), accent, model)
	for i = 1, 3 do
		local tooth = makeWedge("Tooth" .. i, Vector3.new(0.24 * s, 0.34 * s, 0.18 * s), root.Position + Vector3.new((i - 2) * 0.4 * s, -0.95 * s, 1.95 * s), Color3.fromRGB(245, 245, 240), model)
		tooth.CFrame = CFrame.new(tooth.Position) * CFrame.Angles(math.rad(180), 0, 0)
		_ = tooth
	end
	local cockpit = makeEllipsoid("Cockpit", Vector3.new(1.1 * s, 0.8 * s, 1.4 * s), root.Position + Vector3.new(0, 1.15 * s, 0.15 * s), Color3.fromRGB(35, 40, 55), model)
	cockpit.Material = Enum.Material.Glass
	local propL = makePart("PropellerL", Vector3.new(0.15 * s, 2.2 * s, 0.3 * s), root.Position + Vector3.new(-0.7 * s, 0.2 * s, 1.95 * s), Color3.fromRGB(45, 45, 48), nil, model)
	local propR = makePart("PropellerR", Vector3.new(0.15 * s, 2.2 * s, 0.3 * s), root.Position + Vector3.new(0.7 * s, 0.2 * s, 1.95 * s), Color3.fromRGB(45, 45, 48), nil, model)
	local hubL = makeBall("PropHubL", 0.4 * s, root.Position + Vector3.new(-0.7 * s, 0.2 * s, 1.95 * s), Color3.fromRGB(40, 40, 45), model)
	local hubR = makeBall("PropHubR", 0.4 * s, root.Position + Vector3.new(0.7 * s, 0.2 * s, 1.95 * s), Color3.fromRGB(40, 40, 45), model)
	local wing = makePart("Wing", Vector3.new(4.2 * s, 0.25 * s, 1.2 * s), root.Position + Vector3.new(0, 0.5 * s, -0.2 * s), oliveDark, nil, model)
	wing.Material = Enum.Material.Metal
	local tailWing = makePart("TailWing", Vector3.new(2.0 * s, 0.2 * s, 0.8 * s), root.Position + Vector3.new(0, 0.4 * s, -1.4 * s), oliveDark, nil, model)
	tailWing.Material = Enum.Material.Metal
	for _, side in ipairs({ -1, 1 }) do
		local bomb = makeEllipsoid("Bomb", Vector3.new(0.5 * s, 0.5 * s, 1.1 * s), root.Position + Vector3.new(side * 1.5 * s, 0.05 * s, -0.2 * s), Color3.fromRGB(60, 62, 50), model)
		bomb.Material = Enum.Material.Metal
		local fin = makeWedge("BombFin", Vector3.new(0.42 * s, 0.42 * s, 0.16 * s), root.Position + Vector3.new(side * 1.5 * s, 0.05 * s, -0.85 * s), Color3.fromRGB(60, 62, 50), model)
		fin.Material = Enum.Material.Metal
	end
	_ = snout
	_ = hubL
	_ = hubR
	_ = wing
	_ = tailWing
	return { propL, propR }
end

local function buildLog(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Canonical Tung Tung Sahur: a plain brown wooden LOG standing
	-- upright, a simple face ON the log, stubby limbs (the
	-- constructor's) and his wooden bat. No hat, no costume, and no
	-- drum — the old drum kit conflated a different meme. Swap the
	-- Root's sphere mesh for a cylinder so the body itself is the log,
	-- give it a real Wood material, and re-seat the constructor's
	-- eyes, pupils and mouth on the log's round front.
	local mesh = root:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.MeshType = Enum.MeshType.Cylinder
	end
	root.Material = Enum.Material.Wood
	for _, eyeName in ipairs({ "EyeL", "EyeR" }) do
		local eye = model:FindFirstChild(eyeName)
		if eye then
			local sign = if eyeName == "EyeL" then -1 else 1
			eye.Position = root.Position + Vector3.new(sign * 0.45 * s, 0.45 * s, root.Size.Z * 0.485)
			local pupil = model:FindFirstChild(if sign < 0 then "PupilL" else "PupilR")
			if pupil then
				pupil.Position = eye.Position + Vector3.new(0, 0.02 * s, 0.14 * s)
			end
		end
	end
	local mouth = model:FindFirstChild("Mouth")
	if mouth then
		mouth.Position = root.Position + Vector3.new(0, -0.18 * s, root.Size.Z * 0.49)
	end
	-- The bat: a light-wood cylinder with a knob, held at his side.
	local bat = makeCylinder("Bat", 0.28 * s, 2.2 * s, root.Position + Vector3.new(1.25 * s, 0.45 * s, 0.4 * s), Color3.fromRGB(170, 120, 65), model)
	bat.Material = Enum.Material.WoodPlanks
	bat.CFrame = CFrame.new(bat.Position) * CFrame.Angles(0, 0, math.rad(-30))
	local knob = makeBall("BatKnob", 0.36 * s, root.Position + Vector3.new(0.72 * s, -0.5 * s, 0.4 * s), Color3.fromRGB(140, 95, 45), model)
	knob.Material = Enum.Material.Wood
	-- Growth rings: the top ring from before, plus a darker low ring
	-- (a Lerp-darkened variant of the log's own colour) for grain.
	local rings = makeCylinder("LogRing", 2.55 * s, 0.3 * s, root.Position + Vector3.new(0, 1.05 * s, 0), Color3.fromRGB(90, 55, 25), model)
	rings.Material = Enum.Material.WoodPlanks
	local ringLow = makeCylinder("LogRingLow", 2.5 * s, 0.22 * s, root.Position + Vector3.new(0, -0.95 * s, 0), body:Lerp(Color3.new(0, 0, 0), 0.3), model)
	ringLow.Material = Enum.Material.WoodPlanks
	_ = knob
	_ = rings
	_ = ringLow
end

local function buildDancer(model: Model, root: Part, s: number, body: Color3, accent: Color3)
	-- Canonical Ballerina Cappuccina: a cappuccino CUP for a head —
	-- white cup, coffee surface, little handle — over a pink ballet
	-- tutu with pointe shoes. The Root is her dress (Fabric); the
	-- constructor's thin arms stay as her ballet arms.
	root.Material = Enum.Material.Fabric
	local tutu = makeEllipsoid("Tutu", Vector3.new(2.9 * s, 0.6 * s, 2.9 * s), root.Position + Vector3.new(0, -0.35 * s, 0), body, model)
	tutu.Material = Enum.Material.Fabric
	local tutuTrim = makeCylinder("TutuTrim", 2.5 * s, 0.2 * s, root.Position + Vector3.new(0, -0.52 * s, 0), accent, model)
	tutuTrim.Material = Enum.Material.Fabric
	local shoeL = makeEllipsoid("BalletShoeL", Vector3.new(0.55 * s, 0.35 * s, 0.95 * s), root.Position + Vector3.new(-0.45 * s, -1.15 * s, 0.3 * s), body, model)
	local shoeR = makeEllipsoid("BalletShoeR", Vector3.new(0.55 * s, 0.35 * s, 0.95 * s), root.Position + Vector3.new(0.45 * s, -1.15 * s, 0.3 * s), body, model)
	local bun = makeBall("HairBun", 0.6 * s, root.Position + Vector3.new(0, 1.5 * s, -0.3 * s), Color3.fromRGB(120, 70, 40), model)
	local cupWhite = Color3.fromRGB(245, 242, 238)
	local cupTop = makeCylinder("CupTop", 1.25 * s, 0.55 * s, root.Position + Vector3.new(0, 1.32 * s, 0), cupWhite, model)
	local cupFoam = makeEllipsoid("CupFoam", Vector3.new(1.15 * s, 0.3 * s, 1.15 * s), root.Position + Vector3.new(0, 1.62 * s, 0), Color3.fromRGB(155, 105, 65), model)
	local cupHandle = makeCylinder("CupHandle", 0.16 * s, 0.6 * s, root.Position + Vector3.new(0.72 * s, 1.32 * s, 0), cupWhite, model)
	cupHandle.CFrame = CFrame.new(cupHandle.Position) * CFrame.Angles(0, 0, math.rad(35))
	_ = tutu
	_ = tutuTrim
	_ = shoeL
	_ = shoeR
	_ = bun
	_ = cupTop
	_ = cupFoam
	_ = cupHandle
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
		-- Dances only run on pad / dropped units. If the unit is taken
		-- (carried) mid-dance, bail at the next phase boundary instead
		-- of tweening its root against the carry-follow for ~2s.
		local function stillDancing()
			if not model.Parent then
				return false
			end
			local state = model:GetAttribute("State")
			return state == "pad" or state == "dropped"
		end
		local hopInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _ = 1, 2 do
			if not stillDancing() then
				return
			end
			local up = TweenService:Create(root, hopInfo, { CFrame = startCFrame + Vector3.new(0, 1.6, 0) })
			up:Play()
			up.Completed:Wait()
			if not stillDancing() then
				return
			end
			local down = TweenService:Create(root, hopInfo, { CFrame = startCFrame })
			down:Play()
			down.Completed:Wait()
		end
		if not stillDancing() then
			return
		end
		local spinInfo = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local spin = TweenService:Create(root, spinInfo, { CFrame = startCFrame * CFrame.Angles(0, math.pi * 2, 0) })
		spin:Play()
		spin.Completed:Wait()
		if stillDancing() then
			model:SetAttribute("Status", "Idle")
		end
	end)
end

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

-- Owner asked for bigger characters: normal units are built at
-- UNIT_SCALE x their authored size (every size, offset and the
-- nameplate height scales together, so proportions stay exact). The
-- factor is set by fit, not taste — measured by full bounding box
-- over every accessory, the longest unit (Glorbo's croc) spans 5.53
-- authored studs nose-to-tail and pads sit 6 studs apart, so
-- 6 / 5.53 = 1.085 caps the factor; 1.08 keeps neighbours on
-- adjacent pads (5.97 < 6), the lane's 7-stud minimum gap and the
-- widest wingspan (the dragon's 5.26, pads 6 apart) all clean. The
-- boss passes its own scale (6) and is explicitly excluded, so its
-- size never compounds.
local UNIT_SCALE = 1.08

-- Build a character model from a definition, an optional mutation
-- ("Gold", "Diamond", "Rainbow" or nil) and a scale factor (default 1).
function Factory.new(def, mutation: string?, scale: number?): Model
	local unitFactor = if (scale or 1) < 2 then UNIT_SCALE else 1
	local s = (scale or 1) * unitFactor
	local rarity = Config.Rarities[def.Rarity]
	local mutationInfo = (mutation and mutation ~= "") and Config.Mutations[mutation] or nil
	local income = def.Income * (mutationInfo and mutationInfo.Multiplier or 1)

	local model = Instance.new("Model")
	model.Name = def.Name

	-- Root: the body. Same part, same size (footprint and height are
	-- gameplay contract), but a sphere mesh makes it a rounded
	-- ellipsoid torso instead of a plain box. Size varies a little by
	-- rarity so rarer characters read bigger on the lane.
	local rootSize = Vector3.new(2 * s, 2.2 * s, 2 * s) * (1 + (rarity.Order - 1) * 0.08)
	local root = makePart("Root", rootSize, Vector3.new(0, 2.2 * s, 0), def.BodyColor, nil, model)
	addSphereMesh(root)
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	model.PrimaryPart = root

	-- Eyes on the front of the ellipsoid (0.41 x depth sits them on
	-- the curved surface at eye height instead of floating past it).
	-- Each eye is a white ball with a dark pupil in front of it — the
	-- old single dark ball read as a flat dot. EyeL/EyeR keep their
	-- names: the boss restyle in init finds them by name.
	for _, side in ipairs({ -1, 1 }) do
		local eyePos = root.Position + Vector3.new(side * 0.45 * s, 0.45 * s, rootSize.Z * 0.41)
		makeBall(if side < 0 then "EyeL" else "EyeR", 0.34 * s, eyePos, Color3.fromRGB(245, 245, 245), model)
		makeBall(if side < 0 then "PupilL" else "PupilR", 0.17 * s, eyePos + Vector3.new(0, 0.02 * s, 0.13 * s), Color3.fromRGB(20, 20, 20), model)
	end
	-- A simple mouth line under the eyes (shape builders may move or
	-- remove it — the log builder re-seats it on the log's face, the
	-- plane builder swaps it for croc teeth).
	local mouth = makeEllipsoid("Mouth", Vector3.new(0.55 * s, 0.13 * s, 0.16 * s), root.Position + Vector3.new(0, -0.18 * s, rootSize.Z * 0.47), Color3.fromRGB(35, 25, 25), model)
	_ = mouth

	-- Legs on Motor6D joints so the walk animation can swing them.
	-- Cylinder meshes keep the limbs round like the body. Limbs are a
	-- touch longer than the old build (less chibi); their positions
	-- and joint C0s are unchanged, so the walk cycle is identical.
	local legL = makePart("LegL", Vector3.new(0.6 * s, 1.2 * s, 0.6 * s), root.Position + Vector3.new(-0.5 * s, -1.5 * s, 0), def.AccentColor, nil, model)
	addCylinderMesh(legL)
	local legR = makePart("LegR", Vector3.new(0.6 * s, 1.2 * s, 0.6 * s), root.Position + Vector3.new(0.5 * s, -1.5 * s, 0), def.AccentColor, nil, model)
	addCylinderMesh(legR)
	attachLimb(model, root, legL, CFrame.new(-0.5 * s, -1.1 * s, 0))
	attachLimb(model, root, legR, CFrame.new(0.5 * s, -1.1 * s, 0))

	-- Arms, also jointed.
	local armL = makePart("ArmL", Vector3.new(0.5 * s, 1.55 * s, 0.5 * s), root.Position + Vector3.new(-1.3 * s, 0.1 * s, 0), def.BodyColor, nil, model)
	addCylinderMesh(armL)
	local armR = makePart("ArmR", Vector3.new(0.5 * s, 1.55 * s, 0.5 * s), root.Position + Vector3.new(1.3 * s, 0.1 * s, 0), def.BodyColor, nil, model)
	addCylinderMesh(armR)
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

	-- Optional def tint (the golden event def carries one): recolors
	-- every part including the Root, metallic with sparkles, so the
	-- unit reads as a solid gold statue from across the arena.
	if def.Tint then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Color = def.Tint
				descendant.Material = Enum.Material.Metal
			end
		end
		local tintSparkles = Instance.new("Sparkles")
		tintSparkles.Name = "TintSparkles"
		tintSparkles.SparkleColor = def.Tint
		tintSparkles.Parent = root
	end

	applyRarityEffects(model, root, def)
	buildNameplate(model, root, def, mutation, income, unitFactor)

	-- Gameplay attributes.
	model:SetAttribute("CharacterName", def.Name)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Mutation", mutation or "")
	model:SetAttribute("Price", def.Price)
	model:SetAttribute("Income", income)
	model:SetAttribute("Status", "Idle")

	-- Ground clearance: how far the model's lowest point sits below the
	-- root origin in build orientation. Placement code adds this to the
	-- surface height so every unit stands exactly on its surface at any
	-- scale (a fixed stand height drifted once units were scaled up).
	local lowestY = math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local cf = descendant.CFrame
			if cf.Position.Magnitude < 0.001 and descendant.Position.Magnitude >= 0.001 then
				-- Lune decouples Position and CFrame for parts placed by
				-- Position alone (Roblox keeps them in sync); fall back
				-- to the Position so the measurement is the true one.
				cf = CFrame.new(descendant.Position)
			end
			local half = descendant.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = cf:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
						if corner.Y < lowestY then
							lowestY = corner.Y
						end
					end
				end
			end
		end
	end
	if lowestY < math.huge then
		model:SetAttribute("GroundClearance", root.Position.Y - lowestY)
	end

	return model
end

return Factory
