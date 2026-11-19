-- Brainrot Bandits — world builder.
-- Builds the whole arena in Workspace and returns a description table with
-- every handle the gameplay scripts need (bases, pads, shrine, shop, boards).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local World = {}

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

local function part(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance): Part
	local p = part(name, Vector3.new(diameter, diameter, diameter), position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinder(name: string, diameter: number, height: number, position: Vector3, color: Color3, parent: Instance): Part
	local p = part(name, Vector3.new(diameter, height, diameter), position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = p
	return p
end

local function wedge(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local p = part(name, size, position, color, nil, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Parent = p
	return p
end

local function label(
	name: string,
	text: string,
	size: UDim2,
	textSize: number,
	color: Color3,
	parent: Instance,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = bold and Enum.Font.FredokaOne or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextWrapped = true
	l.TextStrokeTransparency = 0.15
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function billboard(name: string, size: UDim2, offset: Vector3, parent: Instance): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = parent
	return gui
end

--------------------------------------------------------------------------------
-- Floor defence — FIRST thing in build(): the starter Baseplate must never
-- poke through the arena floor.
--------------------------------------------------------------------------------

local function defendFloor()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "Baseplate" then
				-- Sink it so its top sits at y = -5 (centre y = -15, 20 tall).
				local size = descendant.Size
				descendant.Position = Vector3.new(descendant.Position.X, -15, descendant.Position.Z)
				descendant.Size = Vector3.new(math.max(size.X, 512), 20, math.max(size.Z, 512))
				descendant.Anchored = true
			elseif descendant.Size.X > 100 or descendant.Size.Z > 100 then
				-- Any other huge slab: sink it until its top is at y = -5.
				local size = descendant.Size
				descendant.Position = Vector3.new(
					descendant.Position.X,
					-5 - size.Y / 2,
					descendant.Position.Z
				)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Decor helpers
--------------------------------------------------------------------------------

local function makeTree(parent: Instance, position: Vector3, scale: number)
	local trunk = cylinder("Trunk", 1.2 * scale, 3 * scale, position + Vector3.new(0, 1.5 * scale, 0), Color3.fromRGB(120, 75, 35), parent)
	local leaves = ball("Leaves", 4.5 * scale, position + Vector3.new(0, 4.6 * scale, 0), Color3.fromRGB(45, 160, 70), parent)
	leaves.Material = Enum.Material.Neon
	_ = trunk
end

local function makeRock(parent: Instance, position: Vector3, scale: number)
	local rock = ball("Rock", 2.2 * scale, position + Vector3.new(0, 0.4 * scale, 0), Color3.fromRGB(140, 140, 145), parent)
	rock.Material = Enum.Material.Slate
end

local function makeLamp(parent: Instance, position: Vector3)
	local pole = cylinder("LampPole", 0.35, 5, position + Vector3.new(0, 2.5, 0), Color3.fromRGB(50, 50, 55), parent)
	local bulb = ball("LampBulb", 0.9, position + Vector3.new(0, 5.2, 0), Color3.fromRGB(255, 220, 130), parent)
	bulb.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = bulb
	_ = pole
end

local function makeFlower(parent: Instance, position: Vector3, color: Color3)
	local stem = cylinder("Stem", 0.15, 0.9, position + Vector3.new(0, 0.45, 0), Color3.fromRGB(40, 150, 60), parent)
	local bloom = ball("Bloom", 0.55, position + Vector3.new(0, 1.0, 0), color, parent)
	bloom.Material = Enum.Material.Neon
	_ = stem
end

--------------------------------------------------------------------------------
-- build()
--------------------------------------------------------------------------------

function World.build(): { [string]: any }
	defendFloor()

	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace

	---------------------------------------------------------------------------
	-- Ground: grass island 232x232 with its top at y = 0.5, plus rock trim.
	---------------------------------------------------------------------------
	local grass = part("GrassIsland", Vector3.new(232, 4, 232), Vector3.new(0, -1.5, 0), Color3.fromRGB(85, 190, 90), Enum.Material.Grass, arena)
	grass.CanCollide = true
	-- Rock trim around the edge.
	for i = 1, 24 do
		local angle = (i - 1) * (math.pi * 2 / 24)
		local x = math.cos(angle) * 114
		local z = math.sin(angle) * 114
		makeRock(arena, Vector3.new(x, 0.5, z), 0.9 + (i % 3) * 0.25)
	end

	---------------------------------------------------------------------------
	-- Central concrete plaza (round), top at y = 0.62.
	---------------------------------------------------------------------------
	local plaza = cylinder("Plaza", 70, 0.24, Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 200, 205), arena)
	plaza.Material = Enum.Material.Concrete
	local plazaRing = cylinder("PlazaRing", 72, 0.1, Vector3.new(0, 0.58, 0), Color3.fromRGB(255, 200, 40), arena)
	plazaRing.Material = Enum.Material.Neon

	---------------------------------------------------------------------------
	-- Conveyor lane: asphalt strip across the middle, glowing edges,
	-- yellow chevrons, top at y = 0.9.
	---------------------------------------------------------------------------
	local lane = Config.Lane
	local laneLength = lane.ToX - lane.FromX
	local laneCenterX = (lane.FromX + lane.ToX) / 2
	local asphalt = part("Lane", Vector3.new(laneLength, 0.6, lane.Width), Vector3.new(laneCenterX, 0.6, lane.Z), Color3.fromRGB(60, 60, 68), Enum.Material.Asphalt, arena)
	_ = asphalt
	local edgeNorth = part("LaneEdgeNorth", Vector3.new(laneLength, 0.25, 0.4), Vector3.new(laneCenterX, 0.95, lane.Z - lane.Width / 2), Color3.fromRGB(60, 220, 255), Enum.Material.Neon, arena)
	local edgeSouth = part("LaneEdgeSouth", Vector3.new(laneLength, 0.25, 0.4), Vector3.new(laneCenterX, 0.95, lane.Z + lane.Width / 2), Color3.fromRGB(60, 220, 255), Enum.Material.Neon, arena)
	_ = edgeNorth
	_ = edgeSouth
	-- Yellow chevrons pointing along the lane.
	for i = 0, 11 do
		local x = lane.FromX + 8 + i * 15
		local chevron = wedge("LaneChevron", Vector3.new(2.2, 0.3, 3.2), Vector3.new(x, 0.95, lane.Z), Color3.fromRGB(255, 210, 40), arena)
		chevron.Material = Enum.Material.Neon
		chevron.CFrame = CFrame.new(chevron.Position) * CFrame.Angles(0, math.rad(90), 0)
	end

	---------------------------------------------------------------------------
	-- Spawn gate: two pillars and a big arch reading BRAINROT BANDITS.
	---------------------------------------------------------------------------
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "SpawnGate"
	gateFolder.Parent = arena
	local pillarL = part("GatePillarL", Vector3.new(2, 12, 2), Vector3.new(lane.FromX - 3, 6.5, -9), Color3.fromRGB(255, 200, 40), Enum.Material.Metal, gateFolder)
	local pillarR = part("GatePillarR", Vector3.new(2, 12, 2), Vector3.new(lane.FromX - 3, 6.5, 9), Color3.fromRGB(255, 200, 40), Enum.Material.Metal, gateFolder)
	_ = pillarL
	_ = pillarR
	local arch = part("GateArch", Vector3.new(2.5, 2.5, 20), Vector3.new(lane.FromX - 3, 13, 0), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, gateFolder)
	local archGui = Instance.new("SurfaceGui")
	archGui.Name = "ArchText"
	archGui.Face = Enum.NormalId.Front
	archGui.Parent = arch
	local archLabel = label("ArchLabel", "BRAINROT BANDITS", UDim2.new(1, 0, 1, 0), 48, Color3.fromRGB(255, 255, 255), archGui, true)
	archLabel.TextStrokeColor3 = Color3.fromRGB(40, 0, 80)

	---------------------------------------------------------------------------
	-- Neon chevron arrows on the plaza, spawn -> lane.
	---------------------------------------------------------------------------
	for i = 1, 5 do
		local arrow = wedge("PlazaArrow", Vector3.new(2.4, 0.3, 3.4), Vector3.new(lane.FromX + 12 + i * 6, 0.75, lane.Z), Color3.fromRGB(255, 110, 200), arena)
		arrow.Material = Enum.Material.Neon
		arrow.CFrame = CFrame.new(arrow.Position) * CFrame.Angles(0, math.rad(90), 0)
	end

	---------------------------------------------------------------------------
	-- Six player bases around the ring.
	---------------------------------------------------------------------------
	local bases = {}
	for index = 1, Config.BaseCount do
		local baseCFrame = Config.GetBaseCFrame(index)
		local center = baseCFrame.Position
		local folder = Instance.new("Folder")
		folder.Name = "Base" .. index
		folder.Parent = arena

		-- Floor plot (round slab).
		local plot = cylinder("Plot", 26, 0.5, Vector3.new(center.X, 0.75, center.Z), Color3.fromRGB(210, 210, 215), folder)
		plot.Material = Enum.Material.Concrete
		local plotRing = cylinder("PlotRing", 27, 0.15, Vector3.new(center.X, 1.0, center.Z), Color3.fromRGB(255, 200, 40), folder)
		plotRing.Material = Enum.Material.Neon

		-- Six display pads in two rows of three, each with a PadIndex attribute.
		local pads = {}
		for padIndex = 1, Config.PadsPerBase do
			local row = math.floor((padIndex - 1) / 3)
			local col = (padIndex - 1) % 3
			-- Pads sit in base-local space: forward is toward the centre.
			local localOffset = Vector3.new((col - 1) * 6, 0, (row - 0.5) * 6 + 2)
			local padPosition = baseCFrame:PointToWorldSpace(localOffset)
			local pad = cylinder("Pad" .. padIndex, 4.4, 0.4, Vector3.new(padPosition.X, 1.15, padPosition.Z), Color3.fromRGB(90, 200, 255), folder)
			pad.Material = Enum.Material.Neon
			pad:SetAttribute("PadIndex", padIndex)
			table.insert(pads, pad)
		end

		-- Delivery zone: glowing strip at the base edge facing the centre.
		local deliveryLocal = Vector3.new(0, 0, -11)
		local deliveryPos = baseCFrame:PointToWorldSpace(deliveryLocal)
		local delivery = part("DeliveryZone", Vector3.new(10, 0.4, 4), Vector3.new(deliveryPos.X, 1.1, deliveryPos.Z), Color3.fromRGB(80, 255, 130), Enum.Material.Neon, folder)
		delivery.CanCollide = false
		delivery.CanTouch = true

		-- Owner sign: billboard on a beam showing the owner's display name
		-- (or FOR RENT while unclaimed).
		local beam = part("SignBeam", Vector3.new(0.6, 7, 0.6), Vector3.new(center.X, 4.5, center.Z), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, folder)
		local signGui = billboard("OwnerSign", UDim2.fromOffset(208, 58), Vector3.new(0, 8.2, 0), beam)
		local signFrame = Instance.new("Frame")
		signFrame.Size = UDim2.new(1, 0, 1, 0)
		signFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		signFrame.BorderSizePixel = 4
		signFrame.BorderColor3 = Color3.fromRGB(255, 200, 40)
		signFrame.Parent = signGui
		local signLabel = label("SignLabel", "FOR RENT", UDim2.new(1, 0, 1, 0), 32, Color3.fromRGB(255, 255, 255), signFrame, true)

		-- Carpet from the delivery zone into the base.
		local carpetLocal = Vector3.new(0, 0, -6)
		local carpetPos = baseCFrame:PointToWorldSpace(carpetLocal)
		local carpet = part("Carpet", Vector3.new(5, 0.15, 8), Vector3.new(carpetPos.X, 1.05, carpetPos.Z), Color3.fromRGB(200, 60, 80), Enum.Material.Fabric, folder)
		carpet.CFrame = CFrame.new(carpet.Position) * CFrame.Angles(0, math.rad(Config.BaseAngles[index]), 0)

		-- Low fence around the back half of the plot.
		for f = 1, 5 do
			local fenceAngle = math.rad(Config.BaseAngles[index] + 180 + (f - 3) * 18)
			local fx = center.X + math.cos(fenceAngle) * 12.5
			local fz = center.Z + math.sin(fenceAngle) * 12.5
			part("Fence", Vector3.new(4.5, 1.1, 0.3), Vector3.new(fx, 1.55, fz), Color3.fromRGB(240, 240, 240), Enum.Material.Wood, folder).CFrame =
				CFrame.new(fx, 1.55, fz) * CFrame.Angles(0, -fenceAngle + math.rad(90), 0)
		end

		-- Lamp and a plant.
		local lampLocal = Vector3.new(10, 0, 8)
		local lampPos = baseCFrame:PointToWorldSpace(lampLocal)
		makeLamp(folder, Vector3.new(lampPos.X, 1, lampPos.Z))
		local plantLocal = Vector3.new(-10, 0, 8)
		local plantPos = baseCFrame:PointToWorldSpace(plantLocal)
		makeTree(folder, Vector3.new(plantPos.X, 1, plantPos.Z), 0.7)

		table.insert(bases, {
			CFrame = baseCFrame,
			Plot = plot,
			Pads = pads,
			DeliveryZone = delivery,
			SignLabel = signLabel,
		})
	end

	---------------------------------------------------------------------------
	-- Rebirth shrine (middle of the arena, south of the lane).
	---------------------------------------------------------------------------
	local shrinePos = Config.ShrinePosition
	local shrineFolder = Instance.new("Folder")
	shrineFolder.Name = "RebirthShrine"
	shrineFolder.Parent = arena
	local shrineBase = cylinder("ShrineBase", 10, 0.8, Vector3.new(shrinePos.X, 1.0, shrinePos.Z), Color3.fromRGB(255, 200, 40), shrineFolder)
	local shrinePillar = cylinder("ShrinePillar", 4, 5, Vector3.new(shrinePos.X, 3.5, shrinePos.Z), Color3.fromRGB(170, 80, 255), shrineFolder)
	local shrineOrb = ball("ShrineOrb", 3, Vector3.new(shrinePos.X, 7.5, shrinePos.Z), Color3.fromRGB(255, 110, 200), shrineFolder)
	shrineOrb.Material = Enum.Material.Neon
	shrineBase.Material = Enum.Material.Metal
	shrinePillar.Material = Enum.Material.Neon
	local shrineLight = Instance.new("PointLight")
	shrineLight.Color = Color3.fromRGB(255, 110, 200)
	shrineLight.Range = 20
	shrineLight.Brightness = 2
	shrineLight.Parent = shrineOrb
	local shrinePrompt = Instance.new("ProximityPrompt")
	shrinePrompt.Name = "RebirthPrompt"
	shrinePrompt.ActionText = "Rebirth"
	shrinePrompt.ObjectText = "Reset Cash for a permanent income boost!"
	shrinePrompt.HoldDuration = 0.5
	shrinePrompt.MaxActivationDistance = 10
	shrinePrompt.Parent = shrinePillar
	_ = shrineBase

	---------------------------------------------------------------------------
	-- Three lucky stands on the north side of the plaza.
	---------------------------------------------------------------------------
	local luckyStands = {}
	for i, standPos in ipairs(Config.LuckyStandPositions) do
		local stand = Instance.new("Folder")
		stand.Name = "LuckyStand" .. i
		stand.Parent = arena
		local counter = part("Counter", Vector3.new(6, 2.5, 3), Vector3.new(standPos.X, 1.85, standPos.Z), Color3.fromRGB(60, 140, 255), Enum.Material.Wood, stand)
		local roof = part("Roof", Vector3.new(7, 0.4, 4.5), Vector3.new(standPos.X, 4.2, standPos.Z), Color3.fromRGB(255, 110, 200), Enum.Material.Neon, stand)
		roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(0, 0, math.rad(4))
		local dice = ball("LuckyDice", 1.2, Vector3.new(standPos.X, 3.6, standPos.Z), Color3.fromRGB(255, 255, 255), stand)
		dice.Material = Enum.Material.Neon
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LuckyPrompt"
		prompt.ActionText = "Try Your Luck"
		prompt.ObjectText = "Roll for a free brainrot!"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.Parent = counter
		table.insert(luckyStands, {
			Folder = stand,
			Counter = counter,
			Prompt = prompt,
		})
	end

	---------------------------------------------------------------------------
	-- Richest-players board (south plaza).
	---------------------------------------------------------------------------
	local richestPos = Config.RichestBoardPosition
	local richestFolder = Instance.new("Folder")
	richestFolder.Name = "RichestBoard"
	richestFolder.Parent = arena
	local richestBack = part("BoardBack", Vector3.new(12, 8, 0.6), Vector3.new(richestPos.X, 5, richestPos.Z), Color3.fromRGB(35, 35, 45), Enum.Material.Wood, richestFolder)
	local richestGui = Instance.new("SurfaceGui")
	richestGui.Name = "RichestGui"
	richestGui.Face = Enum.NormalId.Front
	richestGui.Parent = richestBack
	local richestTitle = label("TitleLabel", "RICHEST BANDITS", UDim2.new(1, 0, 0.18, 0), 36, Color3.fromRGB(255, 200, 40), richestGui, true)
	richestTitle.Position = UDim2.new(0, 0, 0.02, 0)
	local richestLabels = {}
	for i = 1, 5 do
		local row = label("Entry" .. i, i .. ". ---", UDim2.new(0.94, 0, 0.14, 0), 28, Color3.fromRGB(255, 255, 255), richestGui, false)
		row.Position = UDim2.new(0.03, 0, 0.2 + (i - 1) * 0.15, 0)
		row.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(richestLabels, row)
	end

	---------------------------------------------------------------------------
	-- Welcome board with three instruction lines (near the spawn gate).
	---------------------------------------------------------------------------
	local welcomeFolder = Instance.new("Folder")
	welcomeFolder.Name = "WelcomeBoard"
	welcomeFolder.Parent = arena
	local welcomeBack = part("BoardBack", Vector3.new(14, 7, 0.6), Vector3.new(lane.FromX + 6, 4.5, -16), Color3.fromRGB(35, 35, 45), Enum.Material.Wood, welcomeFolder)
	welcomeBack.CFrame = CFrame.new(welcomeBack.Position) * CFrame.Angles(0, math.rad(25), 0)
	local welcomeGui = Instance.new("SurfaceGui")
	welcomeGui.Name = "WelcomeGui"
	welcomeGui.Face = Enum.NormalId.Front
	welcomeGui.Parent = welcomeBack
	local welcomeTitle = label("TitleLabel", "HOW TO PLAY", UDim2.new(1, 0, 0.22, 0), 36, Color3.fromRGB(255, 200, 40), welcomeGui, true)
	welcomeTitle.Position = UDim2.new(0, 0, 0.03, 0)
	local welcomeLines = {
		"1. Touch a brainrot on the lane to buy it",
		"2. Carry it home — don't get slapped!",
		"3. Drop it on your base pad to earn $/sec",
	}
	local welcomeLabels = {}
	for i, text in ipairs(welcomeLines) do
		local row = label("Line" .. i, text, UDim2.new(0.94, 0, 0.2, 0), 24, Color3.fromRGB(255, 255, 255), welcomeGui, false)
		row.Position = UDim2.new(0.03, 0, 0.26 + (i - 1) * 0.22, 0)
		row.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(welcomeLabels, row)
	end

	---------------------------------------------------------------------------
	-- SHOP stall west of the plaza.
	---------------------------------------------------------------------------
	local shopFolder = Instance.new("Folder")
	shopFolder.Name = "Shop"
	shopFolder.Parent = arena
	local shopCenter = Vector3.new(-42, 0, 0)
	local shopCounter = part("Counter", Vector3.new(8, 2.5, 3), Vector3.new(shopCenter.X, 1.85, shopCenter.Z), Color3.fromRGB(170, 80, 255), Enum.Material.Wood, shopFolder)
	local shopCounterCFrame = shopCounter.CFrame
	local shopCanopy = part("Canopy", Vector3.new(10, 0.4, 5), Vector3.new(shopCenter.X, 4.4, shopCenter.Z), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, shopFolder)
	shopCanopy.CFrame = CFrame.new(shopCanopy.Position) * CFrame.Angles(0, 0, math.rad(-4))
	-- Canopy stripes.
	for i = 1, 4 do
		local stripe = part("CanopyStripe" .. i, Vector3.new(1.6, 0.45, 5), Vector3.new(shopCenter.X - 3.75 + (i - 1) * 2.5, 4.42, shopCenter.Z), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, shopFolder)
		stripe.CFrame = CFrame.new(stripe.Position) * CFrame.Angles(0, 0, math.rad(-4))
	end
	-- Shop sign.
	local shopSign = part("ShopSign", Vector3.new(8, 2, 0.5), Vector3.new(shopCenter.X, 6, shopCenter.Z), Color3.fromRGB(35, 35, 45), Enum.Material.Wood, shopFolder)
	local shopGui = Instance.new("SurfaceGui")
	shopGui.Name = "ShopGui"
	shopGui.Face = Enum.NormalId.Front
	shopGui.Parent = shopSign
	local shopTitle = label("ShopTitle", "TOKO", UDim2.new(1, 0, 1, 0), 48, Color3.fromRGB(255, 200, 40), shopGui, true)
	_ = shopTitle
	-- Floor mat + trigger zone in front of the counter.
	local shopMat = part("ShopMat", Vector3.new(6, 0.15, 4), Vector3.new(shopCenter.X, 0.7, shopCenter.Z + 5), Color3.fromRGB(200, 60, 80), Enum.Material.Fabric, shopFolder)
	_ = shopMat
	local shopZone = part("ShopZone", Vector3.new(10, 4, 8), Vector3.new(shopCenter.X, 2.5, shopCenter.Z + 4), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, shopFolder)
	shopZone.Transparency = 0.85
	shopZone.CanCollide = false
	shopZone.CanTouch = true
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Open Shop"
	shopPrompt.ObjectText = "Shoes, gloves & lucky charms!"
	shopPrompt.HoldDuration = 0.3
	shopPrompt.MaxActivationDistance = 10
	shopPrompt.Parent = shopCounter

	---------------------------------------------------------------------------
	-- Decor: trees, rocks, horizon mountains, clouds, street lamps,
	-- bunting and flowers, stepping stones.
	---------------------------------------------------------------------------
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = arena

	-- Trees and rocks scattered outside the plaza ring.
	local treeSpots = {
		Vector3.new(-60, 0, -55), Vector3.new(55, 0, -60), Vector3.new(-70, 0, 40),
		Vector3.new(70, 0, 45), Vector3.new(-45, 0, 70), Vector3.new(50, 0, 72),
		Vector3.new(-95, 0, -20), Vector3.new(95, 0, 20), Vector3.new(20, 0, -85),
		Vector3.new(-25, 0, 88),
	}
	for i, spot in ipairs(treeSpots) do
		makeTree(decor, spot, 0.9 + (i % 3) * 0.2)
	end
	local rockSpots = {
		Vector3.new(-85, 0, 60), Vector3.new(85, 0, -55), Vector3.new(-40, 0, -80),
		Vector3.new(40, 0, 85), Vector3.new(100, 0, -5),
	}
	for i, spot in ipairs(rockSpots) do
		makeRock(decor, spot, 0.8 + (i % 2) * 0.4)
	end

	-- Horizon mountains (big grey wedges just outside the island).
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8) + 0.3
		local mx = math.cos(angle) * 150
		local mz = math.sin(angle) * 150
		local mountain = wedge("Mountain" .. i, Vector3.new(40, 55, 40), Vector3.new(mx, 20, mz), Color3.fromRGB(120, 120, 135), decor)
		mountain.Material = Enum.Material.Slate
		mountain.CFrame = CFrame.new(mountain.Position) * CFrame.Angles(0, -angle, 0)
		local cap = ball("SnowCap" .. i, 12, Vector3.new(mx, 46, mz), Color3.fromRGB(245, 245, 250), decor)
		_ = cap
	end

	-- Clouds drifting high above.
	for i = 1, 6 do
		local cloud = Instance.new("Folder")
		cloud.Name = "Cloud" .. i
		cloud.Parent = decor
		local cx = -90 + i * 36
		local cz = -80 + (i % 3) * 55
		ball("Puff1", 10, Vector3.new(cx, 55, cz), Color3.fromRGB(255, 255, 255), cloud).Material = Enum.Material.SmoothPlastic
		ball("Puff2", 7, Vector3.new(cx + 6, 53, cz + 2), Color3.fromRGB(245, 245, 250), cloud)
		ball("Puff3", 8, Vector3.new(cx - 6, 53, cz - 2), Color3.fromRGB(250, 250, 255), cloud)
	end

	-- Street lamps along the lane.
	for i = 0, 5 do
		local x = lane.FromX + 10 + i * 32
		makeLamp(decor, Vector3.new(x, 0.9, -12))
		makeLamp(decor, Vector3.new(x + 16, 0.9, 12))
	end

	-- Bunting strung across the plaza (coloured flags on a line).
	local buntingColors = {
		Color3.fromRGB(255, 110, 200), Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(60, 220, 255), Color3.fromRGB(80, 255, 130),
	}
	for i = 1, 12 do
		local t = (i - 1) / 11
		local bx = -30 + t * 60
		local flag = wedge("BuntingFlag" .. i, Vector3.new(1.4, 1.6, 0.2), Vector3.new(bx, 8.5 - math.sin(t * math.pi) * 1.5, -20), buntingColors[((i - 1) % 4) + 1], decor)
		flag.Material = Enum.Material.Neon
		flag.CFrame = CFrame.new(flag.Position) * CFrame.Angles(math.rad(180), 0, 0)
	end

	-- Flowers and stepping stones near the plaza.
	local flowerColors = {
		Color3.fromRGB(255, 110, 200), Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(170, 80, 255), Color3.fromRGB(255, 255, 255),
	}
	for i = 1, 16 do
		local angle = (i - 1) * (math.pi * 2 / 16)
		local fx = math.cos(angle) * 42
		local fz = math.sin(angle) * 42
		makeFlower(decor, Vector3.new(fx, 0.62, fz), flowerColors[((i - 1) % 4) + 1])
	end
	for i = 1, 6 do
		local stone = cylinder("SteppingStone" .. i, 3, 0.3, Vector3.new(-20 + i * 5, 0.75, 26 + (i % 2) * 2), Color3.fromRGB(180, 180, 185), decor)
		stone.Material = Enum.Material.Slate
	end

	---------------------------------------------------------------------------
	-- Return every handle gameplay needs.
	---------------------------------------------------------------------------
	return {
		Bases = bases,
		ShrinePrompt = shrinePrompt,
		LuckyStands = luckyStands,
		RichestLabel = richestTitle,
		RichestLabels = richestLabels,
		RichestTitle = richestTitle,
		BannerLabels = { archLabel, welcomeTitle },
		ArchLabel = archLabel,
		WelcomeLabel = welcomeTitle,
		WelcomeLabels = welcomeLabels,
		ShopZone = shopZone,
		ShopCounterCFrame = shopCounterCFrame,
		ShopPrompt = shopPrompt,
		Arena = arena,
	}
end

return World
