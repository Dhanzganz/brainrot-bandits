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
				-- Sink it so its top sits at y = -5 (centre y = -15, 20 tall),
				-- and restyle it as open water so the island reads as an
				-- island from every angle instead of floating on grey void.
				local size = descendant.Size
				descendant.Position = Vector3.new(descendant.Position.X, -15, descendant.Position.Z)
				descendant.Size = Vector3.new(math.max(size.X, 512), 20, math.max(size.Z, 512))
				descendant.Anchored = true
				descendant.Color = Color3.fromRGB(52, 110, 160)
				descendant.Material = Enum.Material.SmoothPlastic
				descendant.TopSurface = Enum.SurfaceType.Smooth
				descendant.BottomSurface = Enum.SurfaceType.Smooth
			elseif descendant.Size.X > 100 or descendant.Size.Z > 100 then
				-- Any other huge slab: sink it until its top is at y = -5
				-- and give it the same water finish (it is part of the
				-- surround, never of the gameplay ground).
				local size = descendant.Size
				descendant.Position = Vector3.new(
					descendant.Position.X,
					-5 - size.Y / 2,
					descendant.Position.Z
				)
				descendant.Color = Color3.fromRGB(52, 110, 160)
				descendant.Material = Enum.Material.SmoothPlastic
				descendant.TopSurface = Enum.SurfaceType.Smooth
				descendant.BottomSurface = Enum.SurfaceType.Smooth
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Decor helpers
--------------------------------------------------------------------------------

-- Softens a neon colour toward its own-luminance grey (and a touch
-- darker) so accent glows read as soft signage, not laser beams. amount
-- is the fraction of the way to grey.
local function soften(color: Color3, amount: number): Color3
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	local grey = Color3.new(lum, lum, lum)
	return color:Lerp(grey, amount):Lerp(Color3.new(0, 0, 0), amount * 0.25)
end

-- Natural tree: a thick wooden trunk and a canopy of four overlapping
-- balls in varied natural greens. Never Neon — nature does not glow.
local treeGreens = {
	Color3.fromRGB(58, 128, 62), Color3.fromRGB(72, 142, 70),
	Color3.fromRGB(50, 115, 58), Color3.fromRGB(66, 134, 66),
}
local treeCanopy = {
	{ 0, 6.4, 0, 6.2 }, { 1.6, 5.6, 0.6, 4.6 },
	{ -1.5, 5.8, -0.5, 4.8 }, { 0.2, 5.4, 1.6, 4.2 },
}
local function makeTree(parent: Instance, position: Vector3, scale: number)
	local trunk = cylinder("Trunk", 1.6 * scale, 5 * scale, position + Vector3.new(0, 2.5 * scale, 0), Color3.fromRGB(101, 74, 48), parent)
	trunk.Material = Enum.Material.Wood
	-- Colour pick hashed from the position so mirrored trees match.
	local pick = (math.floor(math.abs(position.X) + math.abs(position.Z)) % 4) + 1
	for j, c in ipairs(treeCanopy) do
		local canopyBall = ball(
			"Canopy",
			c[4] * scale,
			position + Vector3.new(c[1] * scale, c[2] * scale, c[3] * scale),
			treeGreens[((pick + j - 2) % 4) + 1],
			parent
		)
		canopyBall.Material = Enum.Material.SmoothPlastic
		canopyBall.CanCollide = false
	end
end

-- (R26: every street lamp is GONE — the owner read the lamp heads in
-- game as floating glowing orbs and asked for them all removed. The
-- scene is lit by the raised ambient in Effects.BASE — bright
-- daytime since R27b.)

local function makeFlower(parent: Instance, position: Vector3, color: Color3)
	local stem = cylinder("Stem", 0.15, 0.9, position + Vector3.new(0, 0.45, 0), Color3.fromRGB(40, 150, 60), parent)
	local bloom = ball("Bloom", 0.42, position + Vector3.new(0, 1.0, 0), color, parent)
	_ = bloom
	_ = stem
end

-- One flower bush: a natural-green ball sunk into the grass with three
-- small soft blooms nestled on its top half. Never collides, never Neon.
local bushBloomOffsets = {
	Vector3.new(0.35, 0.5, 0.15), Vector3.new(-0.32, 0.55, -0.18), Vector3.new(0.02, 0.62, 0.33),
}
local function makeFlowerBush(parent: Instance, position: Vector3, colors: { Color3 })
	local center = Vector3.new(position.X, 0.85, position.Z)
	local bush = ball("FlowerBush", 1.3, center, Color3.fromRGB(102, 176, 94), parent)
	bush.CanCollide = false
	for j, off in ipairs(bushBloomOffsets) do
		local bloom = ball("FlowerBushBloom", 0.42, center + off, colors[((j - 1) % #colors) + 1], parent)
		bloom.CanCollide = false
	end
end

-- Flat stone walkway from one ground point to another (width 5, height
-- 0.12). centreY is the part's centre height; the strip is rotated so its
-- length runs from fromPos to toPos.
local function makePath(parent: Instance, fromPos: Vector3, toPos: Vector3, centreY: number)
	local mid = Vector3.new((fromPos.X + toPos.X) / 2, centreY, (fromPos.Z + toPos.Z) / 2)
	local length = (Vector3.new(toPos.X, 0, toPos.Z) - Vector3.new(fromPos.X, 0, fromPos.Z)).Magnitude
	local path = part("Path", Vector3.new(5, 0.12, length), mid, Color3.fromRGB(208, 200, 190), Enum.Material.Cobblestone, parent)
	path.CFrame = CFrame.lookAt(mid, Vector3.new(toPos.X, centreY, toPos.Z))
	return path
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
	-- Ground: grass island 232x232 with its top at y = 0.5. The edge is
	-- clean grass all the way round (no rock trim — the owner asked for
	-- the scattered edge rocks to go).
	---------------------------------------------------------------------------
	local grass = part("GrassIsland", Vector3.new(232, 4, 232), Vector3.new(0, -1.5, 0), Color3.fromRGB(85, 190, 90), Enum.Material.Grass, arena)
	grass.CanCollide = true

	---------------------------------------------------------------------------
	-- Central concrete plaza (round), top at y = 0.62.
	---------------------------------------------------------------------------
	local plaza = cylinder("Plaza", 70, 0.24, Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 200, 205), arena)
	plaza.Material = Enum.Material.Concrete
	local plazaRing = cylinder("PlazaRing", 72, 0.1, Vector3.new(0, 0.58, 0), Color3.fromRGB(255, 200, 40), arena)
	plazaRing.Material = Enum.Material.SmoothPlastic

	---------------------------------------------------------------------------
	-- Conveyor lane: asphalt strip across the middle, painted edges,
	-- yellow chevrons, top at y = 0.9.
	---------------------------------------------------------------------------
	local lane = Config.Lane
	local laneLength = lane.ToX - lane.FromX
	local laneCenterX = (lane.FromX + lane.ToX) / 2
	local asphalt = part("Lane", Vector3.new(laneLength, 0.6, lane.Width), Vector3.new(laneCenterX, 0.6, lane.Z), Color3.fromRGB(60, 60, 68), Enum.Material.Asphalt, arena)
	_ = asphalt
	local edgeNorth = part("LaneEdgeNorth", Vector3.new(laneLength, 0.25, 0.4), Vector3.new(laneCenterX, 0.95, lane.Z - lane.Width / 2), soften(Color3.fromRGB(60, 220, 255), 0.45), Enum.Material.SmoothPlastic, arena)
	local edgeSouth = part("LaneEdgeSouth", Vector3.new(laneLength, 0.25, 0.4), Vector3.new(laneCenterX, 0.95, lane.Z + lane.Width / 2), soften(Color3.fromRGB(60, 220, 255), 0.45), Enum.Material.SmoothPlastic, arena)
	_ = edgeNorth
	_ = edgeSouth
	-- Yellow chevrons pointing along the lane.
	for i = 0, 11 do
		local x = lane.FromX + 8 + i * 15
		local chevron = wedge("LaneChevron", Vector3.new(2.2, 0.3, 3.2), Vector3.new(x, 0.95, lane.Z), soften(Color3.fromRGB(255, 210, 40), 0.15), arena)
		chevron.Material = Enum.Material.Neon
		chevron.CFrame = CFrame.new(chevron.Position) * CFrame.Angles(0, math.rad(90), 0)
	end
	-- Outer trim: matte painted strips on the ground beside the belt
	-- (SmoothPlastic, heavily softened — the lane reads as a path, not
	-- a laser), with short dark posts every ~20 studs. Purely
	-- decorative (no collision) so crossing to the lane is never blocked.
	for _, side in ipairs({ -1, 1 }) do
		local strip = part("LaneTrim", Vector3.new(laneLength, 0.3, 0.5), Vector3.new(laneCenterX, 0.65, lane.Z + side * (lane.Width / 2 + 0.75)), soften(Color3.fromRGB(60, 220, 255), 0.45), Enum.Material.SmoothPlastic, arena)
		strip.CanCollide = false
		for i = 0, 9 do
			local px = lane.FromX + 5 + i * 20
			local post = cylinder("LanePost", 0.3, 2.2, Vector3.new(px, 1.6, lane.Z + side * (lane.Width / 2 + 2.5)), Color3.fromRGB(50, 50, 55), arena)
			post.CanCollide = false
		end
	end

	---------------------------------------------------------------------------
	-- Lane gates: four pastel arches over the conveyor, evenly spaced
	-- along its length. Posts stand on the grass beside the belt (clear
	-- of the asphalt, the trim strips and their posts); the beam's
	-- underside is ~9.6 studs above the belt surface, so walking units
	-- pass straight under. Nothing collides. R27d float audit: the
	-- beam used to hover 0.25 above the post tops — it now sits 0.05
	-- INTO them.
	---------------------------------------------------------------------------
	local laneGateFolder = Instance.new("Folder")
	laneGateFolder.Name = "LaneGates"
	laneGateFolder.Parent = arena
	local gateColors = {
		Color3.fromRGB(255, 110, 200), Color3.fromRGB(60, 220, 255),
		Color3.fromRGB(255, 200, 40), Color3.fromRGB(170, 80, 255),
	}
	for g, gateX in ipairs({ -57, -19, 19, 57 }) do
		local gateColor = soften(gateColors[((g - 1) % #gateColors) + 1], 0.45)
		for _, side in ipairs({ -1, 1 }) do
			local post = part("GatePost", Vector3.new(1.3, 10, 1.3), Vector3.new(gateX, 5.5, side * 10.5), gateColor, Enum.Material.SmoothPlastic, laneGateFolder)
			post.CanCollide = false
		end
		local beam = part("GateBeam", Vector3.new(1.3, 1.3, 22.6), Vector3.new(gateX, 11.1, 0), gateColor, Enum.Material.SmoothPlastic, laneGateFolder)
		beam.CanCollide = false
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
	local arch = part("GateArch", Vector3.new(2.5, 2.5, 20), Vector3.new(lane.FromX - 3, 13, 0), Color3.fromRGB(170, 80, 255), Enum.Material.SmoothPlastic, gateFolder)
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
		arrow.Material = Enum.Material.SmoothPlastic
		arrow.CFrame = CFrame.new(arrow.Position) * CFrame.Angles(0, math.rad(90), 0)
	end

	-- Stone path across the plaza: shrine medallion edge -> lane edge.
	-- It lies on the plaza surface (top 0.7, just above the plaza's 0.62).
	makePath(arena, Vector3.new(0, 0, 12.5), Vector3.new(0, 0, 7.2), 0.64)

	---------------------------------------------------------------------------
	-- Six player bases around the ring, "Neon Podium" theme: a dark
	-- charcoal slab with ONE accent glow per base (plot ring and pads
	-- in the base's accent; carpet in a darker shade of it) plus the
	-- little house-garage at the back of every plot (R27c), so plots
	-- are easy to tell apart without clashing.
	---------------------------------------------------------------------------
	local baseAccents = {
		Color3.fromRGB(220, 60, 70), -- red
		Color3.fromRGB(255, 140, 40), -- orange
		Color3.fromRGB(255, 200, 40), -- gold
		Color3.fromRGB(70, 200, 90), -- green
		Color3.fromRGB(60, 160, 255), -- blue
		Color3.fromRGB(170, 80, 255), -- purple
	}
	---------------------------------------------------------------------------
	-- One tidy house-garage per base (R27c — the owner ordered every
	-- base to have its own little house, "kayak garasi", and the old
	-- bases tidied up). Built once here in base-local space (front =
	-- local -Z, toward the pads and the arena centre; back = +Z) and
	-- instantiated identically for all six bases; only the wall colour
	-- follows the base's accent. The structure stands at the BACK of
	-- the plot, behind the back pad row: foundation, back + side
	-- walls, four corner posts, a panelled garage door facing the
	-- pads, one window per side wall, and a flat roof with overhang.
	-- The old back-arc fence is gone — the house's own walls are the
	-- back boundary now. Every offset below was checked against the
	-- pads (back row reaches local z 7.2), the delivery zone and the
	-- plot edge (radius 13): nothing overlaps, nothing floats — the
	-- foundation's bottom (0.45) stays embedded where its back
	-- corners pass the round slab's edge onto the grass.
	---------------------------------------------------------------------------
	local function buildHouse(folder: Instance, baseCFrame: CFrame, accent: Color3): Part
		local house = Instance.new("Folder")
		house.Name = "House"
		house.Parent = folder
		local wallColor = soften(accent, 0.35)
		local roofColor = Color3.fromRGB(58, 56, 64)
		local trimColor = Color3.fromRGB(70, 70, 78)
		local doorColor = Color3.fromRGB(203, 203, 208)
		local function hpart(name: string, size: Vector3, localPos: Vector3, color: Color3, material: Enum.Material?): Part
			local cf = baseCFrame * CFrame.new(localPos)
			local p = part(name, size, cf.Position, color, material, house)
			p.CFrame = cf
			return p
		end
		-- Foundation slab: top flush with the plot top (1.0).
		hpart("HouseFloor", Vector3.new(16.1, 0.55, 5.2), Vector3.new(0, 0.725, 9.9), Color3.fromRGB(150, 150, 155), Enum.Material.Concrete)
		-- Back wall and the two side walls (height 7.2, tops at 8.2).
		hpart("HouseWallBack", Vector3.new(15.5, 7.2, 0.5), Vector3.new(0, 4.6, 11.95), wallColor, Enum.Material.SmoothPlastic)
		for _, sx in ipairs({ -1, 1 }) do
			hpart("HouseWallSide", Vector3.new(0.5, 7.2, 3.7), Vector3.new(sx * 7.5, 4.6, 9.85), wallColor, Enum.Material.SmoothPlastic)
			-- Corner posts, front pair and back pair, carrying the roof.
			hpart("HousePost", Vector3.new(0.55, 7.2, 0.55), Vector3.new(sx * 7.5, 4.6, 8), trimColor, Enum.Material.Wood)
			hpart("HousePost", Vector3.new(0.55, 7.2, 0.55), Vector3.new(sx * 7.5, 4.6, 11.7), trimColor, Enum.Material.Wood)
			-- One window centred on each side wall: dark frame, warm glass.
			hpart("HouseWindowFrame", Vector3.new(0.12, 2.1, 2.1), Vector3.new(sx * 7.78, 4.9, 9.85), trimColor, Enum.Material.SmoothPlastic)
			local win = hpart("HouseWindow", Vector3.new(0.14, 1.8, 1.8), Vector3.new(sx * 7.81, 4.9, 9.85), Color3.fromRGB(255, 230, 170), Enum.Material.Glass)
			win.CanCollide = false
		end
		-- Garage door on the front (local z = 8), facing the pads: a
		-- dark backing panel, six light-grey horizontal slats with thin
		-- shadow gaps, darker jambs and a handle strip.
		hpart("GarageBacking", Vector3.new(12, 5.3, 0.1), Vector3.new(0, 3.65, 8.2), Color3.fromRGB(40, 40, 46), Enum.Material.SmoothPlastic)
		for s = 1, 6 do
			hpart("GarageSlat", Vector3.new(12, 0.85, 0.25), Vector3.new(0, 1.44 + (s - 1) * 0.88, 8), doorColor, Enum.Material.SmoothPlastic)
		end
		for _, sx in ipairs({ -1, 1 }) do
			hpart("GarageJamb", Vector3.new(0.35, 5.3, 0.4), Vector3.new(sx * 6.18, 3.65, 8), trimColor, Enum.Material.Metal)
		end
		hpart("GarageHandle", Vector3.new(1.6, 0.18, 0.12), Vector3.new(0, 3.3, 7.82), trimColor, Enum.Material.Metal)
		-- Frieze panel above the door — this is the owner name board's
		-- mount (the part keeps the name SignBeam, so the board's
		-- instance path is unchanged; the board now sits on the house
		-- front instead of floating over the plot centre).
		local frieze = hpart("SignBeam", Vector3.new(14.5, 1.1, 0.5), Vector3.new(0, 6.85, 8), wallColor, Enum.Material.SmoothPlastic)
		-- Header beam and the flat roof slab with its overhang.
		hpart("HouseHeader", Vector3.new(16.1, 0.8, 0.6), Vector3.new(0, 7.8, 8), trimColor, Enum.Material.Wood)
		hpart("HouseRoof", Vector3.new(17.1, 0.45, 6.4), Vector3.new(0, 8.42, 9.9), roofColor, Enum.Material.Slate)
		-- Welcome mat in front of the door (clear of the back pad row,
		-- which reaches z 7.2; the mat starts at 7.255).
		local mat = hpart("HouseMat", Vector3.new(8, 0.12, 0.55), Vector3.new(0, 1.06, 7.53), Color3.new(accent.R * 0.7, accent.G * 0.7, accent.B * 0.7), Enum.Material.Fabric)
		mat.CanCollide = false
		return frieze
	end

	local bases = {}
	for index = 1, Config.BaseCount do
		local accent = baseAccents[((index - 1) % #baseAccents) + 1]
		local accentDark = Color3.new(accent.R * 0.7, accent.G * 0.7, accent.B * 0.7)
		local baseCFrame = Config.GetBaseCFrame(index)
		local center = baseCFrame.Position
		local folder = Instance.new("Folder")
		folder.Name = "Base" .. index
		folder.Parent = arena

		-- Floor plot (round slab).
		local plot = cylinder("Plot", 26, 0.5, Vector3.new(center.X, 0.75, center.Z), Color3.fromRGB(52, 52, 62), folder)
		plot.Material = Enum.Material.Slate
		local plotRing = cylinder("PlotRing", 27, 0.15, Vector3.new(center.X, 1.0, center.Z), soften(accent, 0.30), folder)
		plotRing.Material = Enum.Material.SmoothPlastic

		-- (No corner posts: the old square-corner posts stood at local
		-- (±11, ±11) — radius 15.6, OFF the round plot (radius 13) — so
		-- they read in-game as loose accent sticks scattered on the
		-- grass around every base. The ring and pads carry the accent.)

		-- Six display pads in two rows of three, each with a PadIndex attribute.
		local pads = {}
		for padIndex = 1, Config.PadsPerBase do
			local row = math.floor((padIndex - 1) / 3)
			local col = (padIndex - 1) % 3
			-- Pads sit in base-local space: forward is toward the centre.
			local localOffset = Vector3.new((col - 1) * 6, 0, (row - 0.5) * 6 + 2)
			local padPosition = baseCFrame:PointToWorldSpace(localOffset)
			local pad = cylinder("Pad" .. padIndex, 4.4, 0.4, Vector3.new(padPosition.X, 1.15, padPosition.Z), soften(accent, 0.30), folder)
			pad.Material = Enum.Material.SmoothPlastic
			pad:SetAttribute("PadIndex", padIndex)
			table.insert(pads, pad)
		end

		-- Delivery zone: glowing strip at the base edge facing the centre.
		-- Heavily softened (0.5): at 0.18 this big neon slab blew out to
		-- a white-hot rectangle under the client's bloom.
		local deliveryLocal = Vector3.new(0, 0, -11)
		local deliveryPos = baseCFrame:PointToWorldSpace(deliveryLocal)
		local delivery = part("DeliveryZone", Vector3.new(14, 0.4, 7), Vector3.new(deliveryPos.X, 1.1, deliveryPos.Z), soften(Color3.fromRGB(80, 255, 130), 0.5), Enum.Material.SmoothPlastic, folder)
		delivery.CanCollide = false
		delivery.CanTouch = true

		-- The zone marks itself: DELIVER lettered flat on the slab's
		-- top face, dark green on the mint neon. (The old floating
		-- DELIVER HERE billboard was a second glowing board per base —
		-- gone, so each base carries just its one name board now.)
		local deliverGui = Instance.new("SurfaceGui")
		deliverGui.Name = "DeliverSign"
		deliverGui.Face = Enum.NormalId.Top
		deliverGui.LightInfluence = 0
		deliverGui.Parent = delivery
		label("DeliverLabel", "DELIVER", UDim2.new(1, 0, 1, 0), 21, Color3.fromRGB(16, 44, 24), deliverGui, true)

		-- The base's house-garage at the back of the plot (R27c).
		local frieze = buildHouse(folder, baseCFrame, accent)

		-- Owner sign: the name board on the house front, above the
		-- garage door (or FOR RENT while unclaimed). Same BillboardGui,
		-- frame and SignLabel as before — only the mount moved, from a
		-- lone beam over the plot centre onto the house's frieze panel.
		local signGui = billboard("OwnerSign", UDim2.fromOffset(176, 48), Vector3.new(0, 0, 0), frieze)
		local signFrame = Instance.new("Frame")
		signFrame.Size = UDim2.new(1, 0, 1, 0)
		signFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		signFrame.BorderSizePixel = 4
		signFrame.BorderColor3 = accent
		signFrame.Parent = signGui
		local signLabel = label("SignLabel", "FOR RENT", UDim2.new(1, 0, 1, 0), 32, Color3.fromRGB(255, 255, 255), signFrame, true)

		-- Carpet from the delivery zone into the base.
		local carpetLocal = Vector3.new(0, 0, -6)
		local carpetPos = baseCFrame:PointToWorldSpace(carpetLocal)
		local carpet = part("Carpet", Vector3.new(5, 0.15, 8), Vector3.new(carpetPos.X, 1.05, carpetPos.Z), accentDark, Enum.Material.Fabric, folder)
		carpet.CFrame = CFrame.new(carpet.Position) * CFrame.Angles(0, math.rad(Config.BaseAngles[index]), 0)

		-- (No back fence any more: the house's back and side walls are
		-- the plot's back boundary now — the old radius-12 fence arc
		-- crossed exactly the ground the house stands on.)

		-- A plant at the plot's front corner, beside the delivery zone
		-- (it stood at the back before R27c, where the house now is).
		local plantLocal = Vector3.new(-10.5, 0, -5)
		local plantPos = baseCFrame:PointToWorldSpace(plantLocal)
		makeTree(folder, Vector3.new(plantPos.X, 1, plantPos.Z), 0.7)

		-- Stone path from the central plaza edge to this base's plot edge
		-- (top 0.58, just above the grass). It slides under the plaza
		-- medallion, stands and boards on the way — all of those sit higher.
		local outDir = Vector3.new(center.X, 0, center.Z)
		if outDir.Magnitude > 0.01 then
			local unit = outDir / outDir.Magnitude
			makePath(arena, unit * 36.5, center - unit * 14, 0.52)
		end

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
	-- Paved medallion under the shrine area (top 0.62, level with the
	-- central plaza so the two read as one paved ground).
	local shrinePlaza = cylinder("ShrinePlaza", 44, 0.25, Vector3.new(shrinePos.X, 0.495, shrinePos.Z), Color3.fromRGB(208, 200, 190), arena)
	shrinePlaza.Material = Enum.Material.Cobblestone
	local shrineFolder = Instance.new("Folder")
	shrineFolder.Name = "RebirthShrine"
	shrineFolder.Parent = arena
	-- The monument (replaces the old gold base + neon ring + pink orb
	-- stack): a two-step circular stone dais, four stone columns
	-- carrying a square ring beam, and a slowly rotating rebirth
	-- crystal over a low central pedestal. Stone/slate throughout;
	-- the crystal, its light and the beam trim are the one purple
	-- accent. Fully symmetric about both axes.
	local shrineStone = Color3.fromRGB(168, 165, 158)
	local shrineStoneDark = Color3.fromRGB(128, 125, 118)
	local shrineAccent = soften(Color3.fromRGB(170, 80, 255), 0.18)
	-- Two shallow steps on the medallion (its top is y 0.62).
	local step1 = cylinder("ShrineStep1", 14, 0.35, Vector3.new(shrinePos.X, 0.80, shrinePos.Z), shrineStone, shrineFolder)
	step1.Material = Enum.Material.Slate
	local step2 = cylinder("ShrineStep2", 11, 0.35, Vector3.new(shrinePos.X, 1.15, shrinePos.Z), shrineStoneDark, shrineFolder)
	step2.Material = Enum.Material.Slate
	-- Four columns on the dais diagonals (diagonals keep the spawn
	-- approach south of the shrine clear), with capitals. R27d float
	-- audit: at radius 6.5 the columns stand past step 2's disc (r
	-- 5.5), so their feet rest on STEP 1 (top 0.975) — the shafts run
	-- 0.975 -> 5.53 (capital underside), not from step 2.
	for _, off in ipairs({ { 4.6, 4.6 }, { 4.6, -4.6 }, { -4.6, 4.6 }, { -4.6, -4.6 } }) do
		local px = shrinePos.X + off[1]
		local pz = shrinePos.Z + off[2]
		local column = cylinder("ShrineColumn", 1.1, 4.56, Vector3.new(px, 3.25, pz), shrineStone, shrineFolder)
		column.Material = Enum.Material.Slate
		local capital = cylinder("ShrineCapital", 1.6, 0.3, Vector3.new(px, 5.68, pz), shrineStoneDark, shrineFolder)
		capital.Material = Enum.Material.Slate
	end
	-- Square ring beam between the column tops, with a thin purple
	-- trim line under each side.
	for _, side in ipairs({ -1, 1 }) do
		local beamX = part("ShrineBeam", Vector3.new(9.7, 0.55, 0.55), Vector3.new(shrinePos.X, 6.05, shrinePos.Z + side * 4.6), shrineStoneDark, Enum.Material.Slate, shrineFolder)
		_ = beamX
		local beamZ = part("ShrineBeam", Vector3.new(0.55, 0.55, 9.7), Vector3.new(shrinePos.X + side * 4.6, 6.05, shrinePos.Z), shrineStoneDark, Enum.Material.Slate, shrineFolder)
		_ = beamZ
		local trimX = part("ShrineBeamTrim", Vector3.new(9.7, 0.16, 0.66), Vector3.new(shrinePos.X, 5.70, shrinePos.Z + side * 4.6), shrineAccent, Enum.Material.Neon, shrineFolder)
		trimX.CanCollide = false
		local trimZ = part("ShrineBeamTrim", Vector3.new(0.66, 0.16, 9.7), Vector3.new(shrinePos.X + side * 4.6, 5.70, shrinePos.Z), shrineAccent, Enum.Material.Neon, shrineFolder)
		trimZ.CanCollide = false
	end
	-- Central pedestal (carries the Rebirth prompt, as the old centre
	-- pillar did) and the crystal: two pyramids base-to-base — an
	-- octahedron — tilted slightly, turning slowly over the pedestal.
	local pedestal = cylinder("ShrinePedestal", 2.4, 0.5, Vector3.new(shrinePos.X, 1.57, shrinePos.Z), shrineStoneDark, shrineFolder)
	pedestal.Material = Enum.Material.Slate
	-- Centre low enough that the lower pyramid's tip embeds into the
	-- pedestal top (1.82): the crystal reads as growing out of the
	-- pedestal, not hovering over it. It still spins about this centre.
	local crystalCenter = Vector3.new(shrinePos.X, 3.33, shrinePos.Z)
	local function crystalHalf(name: string): Part
		local half = part(name, Vector3.new(1.5, 1.7, 1.5), crystalCenter, shrineAccent, Enum.Material.SmoothPlastic, shrineFolder)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = half
		half.CanCollide = false
		half.CanTouch = false
		return half
	end
	local crystalUpper = crystalHalf("CrystalUpper")
	local crystalLower = crystalHalf("CrystalLower")
	local crystalLight = Instance.new("PointLight")
	crystalLight.Color = Color3.fromRGB(170, 110, 255)
	crystalLight.Brightness = 0.9
	crystalLight.Range = 16
	crystalLight.Parent = crystalUpper
	local crystalSparkles = Instance.new("Sparkles")
	crystalSparkles.SparkleColor = Color3.fromRGB(205, 170, 255)
	crystalSparkles.Parent = crystalUpper
	local upperOffset = CFrame.new(0, 0.85, 0)
	local lowerOffset = CFrame.new(0, -0.85, 0) * CFrame.Angles(0, 0, math.rad(180))
	local function crystalCFrame(angle: number): CFrame
		return CFrame.new(crystalCenter) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(12))
	end
	crystalUpper.CFrame = crystalCFrame(0) * upperOffset
	crystalLower.CFrame = crystalCFrame(0) * lowerOffset
	local RunService = game:GetService("RunService")
	task.spawn(function()
		local angle = 0
		while shrineFolder.Parent do
			local dt = RunService.Heartbeat:Wait()
			angle += dt * 0.5
			local spin = crystalCFrame(angle)
			crystalUpper.CFrame = spin * upperOffset
			crystalLower.CFrame = spin * lowerOffset
		end
	end)
	-- One tidy REBIRTH board above the ring, same family as the base
	-- name boards, on a slim post at the dais' south edge.
	local boardPost = part("ShrineBoardPost", Vector3.new(0.35, 5.6, 0.35), Vector3.new(shrinePos.X, 3.77, shrinePos.Z + 5.4), shrineStoneDark, Enum.Material.Slate, shrineFolder)
	local boardGui = billboard("ShrineBoard", UDim2.fromOffset(150, 40), Vector3.new(0, 3.9, 0), boardPost)
	local boardFrame = Instance.new("Frame")
	boardFrame.Size = UDim2.new(1, 0, 1, 0)
	boardFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	boardFrame.BorderSizePixel = 4
	boardFrame.BorderColor3 = shrineAccent
	boardFrame.Parent = boardGui
	label("ShrineBoardLabel", "REBIRTH", UDim2.new(1, 0, 1, 0), 24, Color3.fromRGB(255, 255, 255), boardFrame, true)
	local shrinePrompt = Instance.new("ProximityPrompt")
	shrinePrompt.Name = "RebirthPrompt"
	shrinePrompt.ActionText = "Rebirth"
	shrinePrompt.ObjectText = "Reset Cash for a permanent income boost!"
	shrinePrompt.HoldDuration = 0.5
	shrinePrompt.MaxActivationDistance = 10
	shrinePrompt.Parent = pedestal

	---------------------------------------------------------------------------
	-- Three lucky stands on the north side of the plaza.
	---------------------------------------------------------------------------
	local luckyStands = {}
	for i, standPos in ipairs(Config.LuckyStandPositions) do
		local stand = Instance.new("Folder")
		stand.Name = "LuckyStand" .. i
		stand.Parent = arena
		local counter = part("Counter", Vector3.new(6, 2.5, 3), Vector3.new(standPos.X, 1.75, standPos.Z), Color3.fromRGB(60, 140, 255), Enum.Material.Wood, stand)
		local roof = part("Roof", Vector3.new(7, 0.4, 4.5), Vector3.new(standPos.X, 4.2, standPos.Z), Color3.fromRGB(255, 110, 200), Enum.Material.SmoothPlastic, stand)
		roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(0, 0, math.rad(4))
		local dice = ball("LuckyDice", 1.2, Vector3.new(standPos.X, 3.6, standPos.Z), Color3.fromRGB(255, 255, 255), stand)
		dice.Material = Enum.Material.SmoothPlastic
		-- Roof posts (R27d float audit: the roof slab rested only on
		-- the dice at its centre and its corners hung in the air).
		-- Four slim posts carry it from the counter top; their tops
		-- meet the tilted underside without poking through the top.
		for _, ox in ipairs({ -2.6, 2.6 }) do
			for _, oz in ipairs({ -1.1, 1.1 }) do
				part("RoofPost", Vector3.new(0.28, 0.95, 0.28), Vector3.new(standPos.X + ox, 3.475, standPos.Z + oz), Color3.fromRGB(45, 105, 190), Enum.Material.Wood, stand)
			end
		end
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
	-- Gold trim frame behind the board face and two support posts, so the
	-- board stands finished instead of floating as a bare slab.
	local richestFrame = part("BoardFrame", Vector3.new(13, 9, 0.3), Vector3.new(richestPos.X, 5, richestPos.Z + 0.45), Color3.fromRGB(255, 200, 40), Enum.Material.Metal, richestFolder)
	_ = richestFrame
	for _, side in ipairs({ -1, 1 }) do
		local post = part("BoardPost", Vector3.new(0.8, 8, 0.8), Vector3.new(richestPos.X + side * 4, 4.5, richestPos.Z + 0.5), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, richestFolder)
		_ = post
	end
	-- Trophy pedestal beside the board: a stone drum with a sparkling
	-- gold trophy ball. It stands on the shrine medallion's edge at
	-- (9.5, 52) — clear of the board's face and posts (x <= 6.4), the
	-- base path along x = 0, the shrine ring and the flower patches.
	local pedestal = cylinder("TrophyPedestal", 3, 1.2, Vector3.new(9.5, 1.22, 52), Color3.fromRGB(150, 150, 158), richestFolder)
	pedestal.Material = Enum.Material.Slate
	local trophyBall = ball("TrophyBall", 1.6, Vector3.new(9.5, 2.5, 52), Color3.fromRGB(255, 200, 40), richestFolder)
	trophyBall.Material = Enum.Material.Metal
	local trophySparkles = Instance.new("Sparkles")
	trophySparkles.SparkleColor = Color3.fromRGB(255, 220, 120)
	trophySparkles.Parent = trophyBall
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
	-- Two support posts (same pattern as the Richest board), planted on
	-- the grass so the board stands instead of floating as a bare slab.
	for _, side in ipairs({ -1, 1 }) do
		local post = part("WelcomePost", Vector3.new(0.8, 7.5, 0.8), Vector3.new(0, 0, 0), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, welcomeFolder)
		post.CFrame = welcomeBack.CFrame * CFrame.new(side * 4, -0.25, 0.5)
		_ = post
	end
	local welcomeGui = Instance.new("SurfaceGui")
	welcomeGui.Name = "WelcomeGui"
	welcomeGui.Face = Enum.NormalId.Front
	welcomeGui.Parent = welcomeBack
	local welcomeTitle = label("TitleLabel", "BRAINROT BANDITS", UDim2.new(1, 0, 0.22, 0), 36, Color3.fromRGB(255, 200, 40), welcomeGui, true)
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
	-- SHOP stall: a market corner west of the shrine medallion, beside
	-- the spawn approach, so arriving players see it on their way in
	-- (it used to sit west of the plaza at (-42, 0), cluttering the
	-- centre). The whole stall is built in shop-local space and carried
	-- by one CFrame, so the counter, zone, prompt and signage can never
	-- drift apart; it faces +X (east) toward the spawn pad and shrine.
	-- Verified clear of the shrine medallion (nearest part 23+ studs
	-- from its centre, radius 22), the spawn pad, the lane, base paths
	-- and flower patches.
	---------------------------------------------------------------------------
	local shopFolder = Instance.new("Folder")
	shopFolder.Name = "Shop"
	shopFolder.Parent = arena
	local shopCF = CFrame.new(Vector3.new(-29, 0, 44)) * CFrame.Angles(0, math.rad(90), 0)
	local function shopPart(p: Part, localOffset: Vector3, localTilt: CFrame?): Part
		p.CFrame = shopCF * CFrame.new(localOffset) * (localTilt or CFrame.new())
		return p
	end
	-- Cobblestone ground mat under the stall (top 0.58, level with the
	-- paths) so the corner reads as a deliberate market spot.
	local shopGround = part("ShopGround", Vector3.new(10, 0.12, 10), Vector3.new(-29, 0.52, 44), Color3.fromRGB(208, 200, 190), Enum.Material.Cobblestone, shopFolder)
	_ = shopGround
	-- Part sizes below are authored in shop-local axes (the stall's old
	-- unrotated layout); shopCF rotates them into their world place.
	local shopCounter = shopPart(part("Counter", Vector3.new(8, 2.5, 3), Vector3.new(-29, 1.85, 44), Color3.fromRGB(170, 80, 255), Enum.Material.Wood, shopFolder), Vector3.new(0, 1.85, 0))
	local shopCounterCFrame = shopCounter.CFrame
	local shopCanopy = shopPart(part("Canopy", Vector3.new(10, 0.4, 5), Vector3.new(-29, 4.4, 44), Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic, shopFolder), Vector3.new(0, 4.4, 0), CFrame.Angles(0, 0, math.rad(-4)))
	_ = shopCanopy
	-- Canopy stripes.
	for i = 1, 4 do
		shopPart(part("CanopyStripe" .. i, Vector3.new(1.6, 0.45, 5), Vector3.new(-29, 4.42, 44), Color3.fromRGB(238, 232, 218), Enum.Material.SmoothPlastic, shopFolder), Vector3.new(-3.75 + (i - 1) * 2.5, 4.42, 0), CFrame.Angles(0, 0, math.rad(-4)))
	end
	-- Shop sign, lettered on both broad faces so TOKO reads from the
	-- customer side (east, toward spawn) and from behind alike.
	local shopSign = shopPart(part("ShopSign", Vector3.new(8, 2, 0.5), Vector3.new(-29, 6, 44), Color3.fromRGB(35, 35, 45), Enum.Material.Wood, shopFolder), Vector3.new(0, 6, 0))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local shopGui = Instance.new("SurfaceGui")
		shopGui.Name = "ShopGui"
		shopGui.Face = face
		shopGui.Parent = shopSign
		label("ShopTitle", "TOKO", UDim2.new(1, 0, 1, 0), 48, Color3.fromRGB(255, 200, 40), shopGui, true)
	end
	-- Canopy + sign posts (R27d float audit: the canopy hovered 0.75
	-- above the counter with nothing holding it up, and the sign
	-- floated just over the canopy's high corner). Four posts carry
	-- the canopy from the ground slab — the pair on the canopy's low
	-- side is shorter, matching its -4 deg tilt — and two short posts
	-- tie the sign down to the canopy.
	for _, pz in ipairs({ -1.6, 1.6 }) do
		shopPart(part("CanopyPost", Vector3.new(0.3, 3.6, 0.3), Vector3.new(-29, 2.38, 44), Color3.fromRGB(70, 70, 78), Enum.Material.Wood, shopFolder), Vector3.new(3.6, 2.38, pz))
		shopPart(part("CanopyPost", Vector3.new(0.3, 3.95, 0.3), Vector3.new(-29, 2.56, 44), Color3.fromRGB(70, 70, 78), Enum.Material.Wood, shopFolder), Vector3.new(-3.6, 2.56, pz))
	end
	for _, px in ipairs({ -3, 3 }) do
		shopPart(part("SignPost", Vector3.new(0.25, 1.4, 0.25), Vector3.new(-29, 5, 44), Color3.fromRGB(70, 70, 78), Enum.Material.Wood, shopFolder), Vector3.new(px, 5, 0))
	end
	-- Floor mat + trigger zone in front of the counter (east side).
	local shopMat = shopPart(part("ShopMat", Vector3.new(6, 0.15, 4), Vector3.new(-24, 0.7, 44), Color3.fromRGB(200, 60, 80), Enum.Material.Fabric, shopFolder), Vector3.new(0, 0.7, 5))
	_ = shopMat
	local shopZone = shopPart(part("ShopZone", Vector3.new(10, 4, 8), Vector3.new(-25, 2.5, 44), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, shopFolder), Vector3.new(0, 2.5, 4))
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
	-- Decor: mirrored tree clusters, horizon hills,
	-- clouds and flowers, stepping stones.
	---------------------------------------------------------------------------
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = arena

	-- Trees in tidy mirrored clusters: one 3-tree cluster per quadrant
	-- (centre + two satellites, offsets mirrored with the quadrant) plus
	-- one midline tree per side. No random scatter, no loose rocks —
	-- every spot below was checked clear of bases, paths and the road.
	local treeSpots = {}
	for _, sx in ipairs({ 1, -1 }) do
		for _, sz in ipairs({ 1, -1 }) do
			table.insert(treeSpots, Vector3.new(56 * sx, 0, 52 * sz))
			table.insert(treeSpots, Vector3.new(51 * sx, 0, 55 * sz))
			table.insert(treeSpots, Vector3.new(59 * sx, 0, 47 * sz))
		end
	end
	table.insert(treeSpots, Vector3.new(88, 0, 16))
	table.insert(treeSpots, Vector3.new(88, 0, -16))
	table.insert(treeSpots, Vector3.new(-88, 0, 16))
	table.insert(treeSpots, Vector3.new(-88, 0, -16))
	for i, spot in ipairs(treeSpots) do
		makeTree(decor, spot, 0.9 + (i % 3) * 0.2)
	end

	-- Horizon hills: six large, heavily flattened balls sunk into the
	-- water outside the island — soft blue-green domes on the horizon,
	-- no sharp wedge "mountains".
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6) + 0.35
		local d = 84 + (i % 3) * 14
		local r = 152 + (i % 3) * 9
		local hill = ball("Hill" .. i, d, Vector3.new(math.cos(angle) * r, 1.5, math.sin(angle) * r), Color3.fromRGB(76, 104, 112), decor)
		hill.Material = Enum.Material.Grass
		hill.CanCollide = false
		local hillMesh = hill:FindFirstChildOfClass("SpecialMesh")
		if hillMesh then
			hillMesh.Scale = Vector3.new(1, 0.32, 1)
		end
	end

	-- (R27b: the four nebula wash spheres are GONE — they were
	-- night-only dressing, and in daylight the huge transparent
	-- spheres read as floating blobs, which is exactly what the
	-- owner keeps flagging. The BanditsSky Sky instance went with
	-- them; the day sky is plain Roblox sky + clouds below.)

	-- Clouds drifting high above.
	for i = 1, 6 do
		local cloud = Instance.new("Folder")
		cloud.Name = "Cloud" .. i
		cloud.Parent = decor
		local cx = -90 + i * 36
		local cz = -80 + (i % 3) * 55
		local puff1 = ball("Puff1", 13, Vector3.new(cx, 67, cz), Color3.fromRGB(255, 255, 255), cloud)
		puff1.Material = Enum.Material.SmoothPlastic
		puff1.Transparency = 0.15
		puff1.CanCollide = false
		local puff1Mesh = puff1:FindFirstChildOfClass("SpecialMesh")
		if puff1Mesh then
			puff1Mesh.Scale = Vector3.new(1.25, 0.6, 1.1)
		end
		local puff2 = ball("Puff2", 9.5, Vector3.new(cx + 8, 65, cz + 2), Color3.fromRGB(245, 245, 250), cloud)
		puff2.Material = Enum.Material.SmoothPlastic
		puff2.Transparency = 0.15
		puff2.CanCollide = false
		local puff2Mesh = puff2:FindFirstChildOfClass("SpecialMesh")
		if puff2Mesh then
			puff2Mesh.Scale = Vector3.new(1.25, 0.6, 1.1)
		end
		local puff3 = ball("Puff3", 10.5, Vector3.new(cx - 8, 65, cz - 2), Color3.fromRGB(250, 250, 255), cloud)
		puff3.Material = Enum.Material.SmoothPlastic
		puff3.Transparency = 0.15
		puff3.CanCollide = false
		local puff3Mesh = puff3:FindFirstChildOfClass("SpecialMesh")
		if puff3Mesh then
			puff3Mesh.Scale = Vector3.new(1.25, 0.6, 1.1)
		end
	end

	-- Surface height under a point, mirroring the built geometry: lane
	-- belt top 0.9, plaza + shrine medallion 0.62, base plots 1.0, open
	-- grass 0.5. Hand-planted flowers use it so nothing stands on a
	-- guessed height.
	local function groundY(x: number, z: number): number
		if math.abs(z) <= 7 and math.abs(x) <= 95 then
			return 0.9
		end
		local dxs, dzs = x - shrinePos.X, z - shrinePos.Z
		if dxs * dxs + dzs * dzs <= 22 * 22 then
			return 0.62
		end
		if x * x + z * z <= 35 * 35 then
			return 0.62
		end
		for i = 1, Config.BaseCount do
			local c = Config.GetBaseCFrame(i).Position
			local dx, dz = x - c.X, z - c.Z
			if dx * dx + dz * dz <= 13 * 13 then
				return 1
			end
		end
		return 0.5
	end

	-- (The old plaza bunting line is gone: it hung at z=-20 with no
	-- visible wire or support, so the flags read as floating.)

	-- Flowers and stepping stones near the plaza. Soft, natural flower
	-- colours only — no neon confetti on the grass.
	local flowerColors = {
		Color3.fromRGB(245, 240, 235), Color3.fromRGB(240, 175, 195),
		Color3.fromRGB(245, 220, 140), Color3.fromRGB(190, 175, 225),
	}
	-- A flower spot is skipped if it would land within 5 studs of a
	-- lucky stand (the stands sit in this band on the north side).
	local function nearLuckyStand(x: number, z: number): boolean
		for _, standPos in ipairs(Config.LuckyStandPositions) do
			local dx = x - standPos.X
			local dz = z - standPos.Z
			if dx * dx + dz * dz < 25 then
				return true
			end
		end
		return false
	end
	for i = 1, 16 do
		local angle = (i - 1) * (math.pi * 2 / 16)
		-- Same lane guard as the second ring: the 0/180-degree spots sit
		-- on the conveyor asphalt, so no flowers are planted there.
		if math.abs(math.sin(angle)) > 0.2 then
			local fx = math.cos(angle) * 42
			local fz = math.sin(angle) * 42
			if not nearLuckyStand(fx, fz) then
				makeFlower(decor, Vector3.new(fx, groundY(fx, fz), fz), flowerColors[((i - 1) % 4) + 1])
			end
		end
	end
	-- Second flower ring, slightly further out. Spots that would land on
	-- the conveyor lane (angles 0 and 180) or on a base path (which the
	-- +Z path also covers for the spawn pad) are skipped.
	for i = 1, 16 do
		local angle = (i - 1) * (math.pi * 2 / 16)
		if math.abs(math.sin(angle)) > 0.2 then
			local fx = math.cos(angle) * 45.5
			local fz = math.sin(angle) * 45.5
			local onPath = false
			for _, baseAngle in ipairs(Config.BaseAngles) do
				local rad = math.rad(baseAngle)
				local ux, uz = math.cos(rad), math.sin(rad)
				local proj = fx * ux + fz * uz
				local perp = math.abs(fx * uz - fz * ux)
				if proj >= 35 and proj <= 67 and perp < 3.2 then
					onPath = true
					break
				end
			end
			if not onPath and not nearLuckyStand(fx, fz) then
				makeFlower(decor, Vector3.new(fx, 0.5, fz), flowerColors[(i % 4) + 1])
			end
		end
	end
	-- Flower patches: a neat ring of eight bushes around the plaza at
	-- radius 39, offset 22.5 degrees so none sits on a base path, the
	-- lane or a lucky stand; nothing in a patch ever collides.
	local patchSpots = {}
	for k = 0, 7 do
		local theta = math.rad(22.5 + k * 45)
		table.insert(patchSpots, Vector3.new(math.cos(theta) * 39, 0, math.sin(theta) * 39))
	end
	-- Three blooms nestled on the top half of each bush ball.
	local bloomOffsets = {
		Vector3.new(0.35, 0.5, 0.15), Vector3.new(-0.32, 0.55, -0.18), Vector3.new(0.02, 0.62, 0.33),
	}
	for s, spot in ipairs(patchSpots) do
		local bushCenter = Vector3.new(spot.X, 0.85, spot.Z)
		local bush = ball("FlowerPatch", 1.3, bushCenter, Color3.fromRGB(102, 176, 94), decor)
		bush.CanCollide = false
		for j, off in ipairs(bloomOffsets) do
			local bloom = ball("FlowerPatchBloom", 0.42, bushCenter + off, flowerColors[((s + j - 2) % 4) + 1], decor)
			bloom.CanCollide = false
		end
	end
	for i = 1, 6 do
		-- Two studs further from the shrine than the original row, so the
		-- end stones clear the shrine's monument dais instead of
		-- grazing its edge.
		local stone = cylinder("SteppingStone" .. i, 3, 0.3, Vector3.new(-20 + i * 5, 0.75, 24 + (i % 2) * 2), Color3.fromRGB(180, 180, 185), decor)
		stone.Material = Enum.Material.Slate
	end

	---------------------------------------------------------------------------
	-- Outer field: a ring road around the arena, and tidy mirrored
	-- clusters of trees and flower bushes beyond the bases, so the
	-- high ground no longer reads as empty grass.
	-- The bases sit at radius 60 and their plots reach radius 73, so the
	-- road ring runs at radius 81 — the same offset from the plot edges
	-- as before, well inside the island edge (116).
	---------------------------------------------------------------------------
	local RING_RADIUS = 81
	local RING_SEGMENTS = 28
	local ringHalfPitch = math.pi / RING_SEGMENTS
	local ringCentreRadius = RING_RADIUS * math.cos(ringHalfPitch)
	local ringSegLength = 2 * RING_RADIUS * math.sin(ringHalfPitch)
	for i = 1, RING_SEGMENTS do
		local theta = (i - 1) * (math.pi * 2 / RING_SEGMENTS)
		-- Chord-fitted segments: each centre sits at R*cos(half-pitch)
		-- with length 2*R*sin(half-pitch), so neighbouring segments meet
		-- exactly on the circle — no gaps and no overlapping faces to
		-- flicker. All tops at y = 0.58, level with the base paths.
		local cx = math.cos(theta) * ringCentreRadius
		local cz = math.sin(theta) * ringCentreRadius
		local seg = part("RingRoad", Vector3.new(6, 0.12, ringSegLength), Vector3.new(cx, 0.52, cz), Color3.fromRGB(208, 200, 190), Enum.Material.Cobblestone, decor)
		seg.CFrame = CFrame.new(seg.Position) * CFrame.Angles(0, -theta, 0)
	end

	-- Clearance guard for outer scatter, in the same style as the
	-- flower-ring path check: nothing lands on the lane strip, the ring
	-- road, a base plot's apron or a base path.
	local function outerSpotClear(x: number, z: number): boolean
		if math.abs(z) < 10 and math.abs(x) <= 95 then
			return false -- on the conveyor lane strip
		end
		local r = math.sqrt(x * x + z * z)
		if math.abs(r - RING_RADIUS) < 5 then
			return false -- on the ring road
		end
		for _, baseAngle in ipairs(Config.BaseAngles) do
			local rad = math.rad(baseAngle)
			local bx = math.cos(rad) * Config.BaseRadius
			local bz = math.sin(rad) * Config.BaseRadius
			local dx = x - bx
			local dz = z - bz
			if dx * dx + dz * dz < 18 * 18 then
				return false -- too close to a base centre
			end
			local ux, uz = math.cos(rad), math.sin(rad)
			local proj = x * ux + z * uz
			local perp = math.abs(x * uz - z * ux)
			if proj >= 35 and proj <= 67 and perp < 4 then
				return false -- on a base path
			end
		end
		return true
	end

	-- Outer decor in a fixed 4-fold mirrored pattern (no scatter, no
	-- rocks): twelve trees in three mirrored rings beyond the road, and
	-- flower beds flanking every base path plus a pair at the shop corner.
	local outerTreeSpots = {}
	for _, ringSpec in ipairs({
		{ 94, { 25, 155, 205, 335 } },
		{ 88, { 65, 115, 245, 295 } },
		{ 88, { 10, 170, 190, 350 } },
	}) do
		for _, deg in ipairs(ringSpec[2]) do
			local theta = math.rad(deg)
			table.insert(outerTreeSpots, Vector3.new(math.cos(theta) * ringSpec[1], 0, math.sin(theta) * ringSpec[1]))
		end
	end
	for i, spot in ipairs(outerTreeSpots) do
		if outerSpotClear(spot.X, spot.Z) then
			makeTree(decor, spot, 0.9 + (i % 3) * 0.2)
		end
	end
	local outerBushSpots = {}
	for b = 1, Config.BaseCount do
		local baseAngle = Config.BaseAngles[b]
		if baseAngle ~= 90 then
			local rad = math.rad(baseAngle)
			local ux, uz = math.cos(rad), math.sin(rad)
			for _, s in ipairs({ 1, -1 }) do
				table.insert(outerBushSpots, Vector3.new(42 * ux - s * 6 * uz, 0, 42 * uz + s * 6 * ux))
			end
		end
	end
	table.insert(outerBushSpots, Vector3.new(-35.5, 0, 39.5))
	table.insert(outerBushSpots, Vector3.new(-35.5, 0, 48.5))
	for s, spot in ipairs(outerBushSpots) do
		if outerSpotClear(spot.X, spot.Z) then
			makeFlowerBush(decor, spot, {
				flowerColors[((s - 1) % 4) + 1],
				flowerColors[(s % 4) + 1],
				flowerColors[((s + 1) % 4) + 1],
			})
		end
	end

	---------------------------------------------------------------------------
	-- Perimeter guard wall ("penjaga tembok"): a neat square stone wall
	-- on the grass edge at ±108, so the island reads as one guarded
	-- territory. Posts every 13.5 studs carry the wall segments; taller
	-- towers cap the four corners. Every side is
	-- generated from the same numbers, so the wall is perfectly
	-- symmetric on both axes. The ring road (r=81) and the outer tree
	-- band (r=88-94) stay inside it; the hills stay outside as scenery.
	-- All parts collide — it is a real boundary, not a decoration.
	---------------------------------------------------------------------------
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "PerimeterWall"
	wallFolder.Parent = arena
	local WALL_POST_SPACING = 13.5
	local wallStone = Color3.fromRGB(148, 146, 140)
	local wallDark = Color3.fromRGB(116, 114, 108)
	-- Each side: start corner (x, z) + unit direction along the side.
	-- Joints 0 and 16 of a side are the corner towers (built below);
	-- posts stand on joints 1..15, segments span every joint pair.
	local wallSides = {
		{ -108, -108, 1, 0 },
		{ 108, -108, 0, 1 },
		{ 108, 108, -1, 0 },
		{ -108, 108, 0, -1 },
	}
	for _, side in ipairs(wallSides) do
		local sx, sz, dx, dz = side[1], side[2], side[3], side[4]
		for k = 1, 15 do
			local px = sx + dx * k * WALL_POST_SPACING
			local pz = sz + dz * k * WALL_POST_SPACING
			part("WallPost", Vector3.new(1.2, 4.2, 1.2), Vector3.new(px, 2.6, pz), wallDark, Enum.Material.Slate, wallFolder)
			part("WallPostCap", Vector3.new(1.7, 0.35, 1.7), Vector3.new(px, 4.87, pz), wallStone, Enum.Material.Slate, wallFolder)
		end
		for k = 0, 15 do
			local mx = sx + dx * (k + 0.5) * WALL_POST_SPACING
			local mz = sz + dz * (k + 0.5) * WALL_POST_SPACING
			local segSize = if dx ~= 0 then Vector3.new(12.5, 3, 0.8) else Vector3.new(0.8, 3, 12.5)
			part("WallSegment", segSize, Vector3.new(mx, 2.0, mz), wallStone, Enum.Material.Slate, wallFolder)
		end
	end
	-- Corner towers (plain stone caps — R26 removed their lamp balls
	-- along with every other lamp in the world).
	for _, cx in ipairs({ -108, 108 }) do
		for _, cz in ipairs({ -108, 108 }) do
			part("CornerTower", Vector3.new(2.6, 6, 2.6), Vector3.new(cx, 3.5, cz), wallDark, Enum.Material.Slate, wallFolder)
			part("CornerCap", Vector3.new(3.2, 0.4, 3.2), Vector3.new(cx, 6.7, cz), wallStone, Enum.Material.Slate, wallFolder)
		end
	end

	---------------------------------------------------------------------------
	-- Lighting: bright daytime (R27b). No Sky instance — the night
	-- galaxy sky (BanditsSky) and its star field are gone; the default
	-- Roblox day sky shows instead. ClockTime mid-afternoon. The
	-- client's Effects.SetupLighting applies the matching day BASE
	-- look locally (identical values); these server defaults are kept
	-- coherent with it. The Atmosphere reuses the "BanditsAtmosphere"
	-- name so the client finds and reuses this instance instead of
	-- stacking a second one.
	---------------------------------------------------------------------------
	local Lighting = game:GetService("Lighting")
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 13.5
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(140, 155, 190)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 185, 215)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmo = Instance.new("Atmosphere")
		atmo.Name = "BanditsAtmosphere"
		atmo.Density = 0.22
		atmo.Haze = 1.2
		atmo.Color = Color3.fromRGB(255, 240, 220)
		atmo.Parent = Lighting
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
