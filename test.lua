local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local player = LocalPlayer
local SETTINGS_FILE = "EpsilonHub_Config.json"
local Library = loadstring(game:HttpGet('https://pastebin.com/raw/Pr7SkYS8'))()
Library:InitAutoSave(SETTINGS_FILE)
local refreshAutoDig
local lastMoveCommandPos = nil
local lastMoveCommandTime = 0
local hasTaskCancel = (type(task) == "table" or type(task) == "userdata")
and type(task.cancel) == "function"
local function notify(title, text, duration)
    pcall(function()
        Library:Notify({
        Title = title or "Notice",
        Text = text or "",
        Duration = duration or 3,
        Type = "Info",
        })
    end)
end
local function resetTable(tbl)
    if type(tbl) ~= "table" then
        return
    end
    if table.clear then
        table.clear(tbl)
    return
    end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end
local function resetMoveCommand()
    lastMoveCommandPos = nil
    lastMoveCommandTime = 0
end
local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function hardTeleportTo(cf)
    local character = LocalPlayer.Character
    local hrp = getHRP()
    if not character or not hrp or typeof(cf) ~= "CFrame" then return end 
    character:PivotTo(cf)
    hrp.AssemblyLinearVelocity = Vector3.zero
end
local function requestMoveTo(pos, bool)
    local character = LocalPlayer.Character
    local hrp = getHRP()
    if not character or not hrp or typeof(cf) ~= "CFrame" then return end
    character.Humanoid:MoveTo(pos)
end

local function formatShort(num)
num = tonumber(num) or 0
local abs = math.abs(num)
local suffix = ""
local div = 1

if abs >= 1e12 then
    suffix, div = "T", 1e12
elseif abs >= 1e9 then
    suffix, div = "B", 1e9
elseif abs >= 1e6 then
    suffix, div = "M", 1e6
elseif abs >= 1e3 then
    suffix, div = "K", 1e3
end
local value = num / div
local fmt
if abs < 1e3 then
    fmt = string.format("%.0f", value)
elseif abs >= 100 * div then
    fmt = string.format("%.0f", value)
elseif abs >= 10 * div then
    fmt = string.format("%.1f", value)
else
    fmt = string.format("%.2f", value)
end
return fmt .. suffix
end
local function loadLifetimeStats()
-- legacy no-op (lifetime stats removed)
end
local function saveLifetimeStats()
-- legacy no-op (lifetime stats removed)
end
loadLifetimeStats()
local defaultWalkSpeed = 16
local defaultJumpPower = 50
local isSpeedEnabled = false
local isJumpEnabled = false
local isNoclipEnabled = false
local isAutoFarmEnabled = false
local isAutoDispenseEnabled = false
local antiAfkEnabled = false
local antiAfkConnection = nil
local isAutoClaimHiveEnabled = false
local currentSpeed = 100
local currentJump = 150
local selectedField = nil
local isDispensing = false
local selectedFieldName = nil
local visitedTokens = {}
local activeToken = nil
local activeTokenIsLink = false
local tokenMetadata = {}
local candidateBuffer = {}
local TOKEN_PASS_RADIUS = 4
local TOKEN_RECENT_DELAY = 0.08
local MAX_PREDICTION_TIME = 0.75
local MIN_SAMPLE_DELTA = 1 / 120
local MAX_TOKEN_TRACK_DISTANCE = 220
local MAX_TRACK_SPEED = 75
local activeTokenScore = 0
local SCORE_RELOCK_THRESHOLD = 8
local wanderTarget = nil
local wanderExpireTime = 0
local wanderDirection = Vector3.new(1, 0, 0)
local lastWanderRotate = 0
local WANDER_ROTATE_INTERVAL = 1.35
local MIN_WANDER_DISTANCE = 18
local wanderLastBase = nil
local MOVE_COMMAND_EPS = 0.85
local MOVE_COMMAND_RETRY = 0.35
local statsGui = nil
local statsLabel = nil
local farmSessionStart = 0
local farmStartPollen = 0
local farmStartHoney = 0
local statsLastUpdate = 0
local isStatsPanelEnabled = false
local isBuffAwareEnabled = false
local lastStuckCheckTime = 0
local lastStuckCheckPosition = nil
local stuckCounter = 0
local MAX_PATH_SEGMENTS = 10
local pathParts = {}
for i = 1, MAX_PATH_SEGMENTS do
local part = Instance.new("Part")
part.Name = "EpsPathLine_" .. i
part.Anchored = true
part.CanCollide = false
part.Color = Color3.fromRGB(0, 255, 0)
part.Material = Enum.Material.Neon
part.Transparency = 1
part.Size = Vector3.new(0.15, 0.15, 0.15)
part.Locked = true
part.Parent = Workspace
pathParts[i] = part
end
local fieldBoundsParts = {}
local fieldBoundsEnabled = false
local FIELD_WALL_HEIGHT = 35
local FIELD_WALL_THICKNESS = 1.5
local FIELD_WALL_MARGIN = 1
local function ensureFieldBounds()
if #fieldBoundsParts > 0 then
return
end
for i = 1, 4 do
local wall = Instance.new("Part")
wall.Name = "EpsFieldWall_" .. i
wall.Anchored = true
wall.CanCollide = true
wall.Transparency = 1
wall.Material = Enum.Material.ForceField
wall.Locked = true
wall.Parent = nil
fieldBoundsParts[i] = wall
end
end
local function refreshFieldBounds()
ensureFieldBounds()
for _, wall in ipairs(fieldBoundsParts) do
wall.Parent = nil
end
if not fieldBoundsEnabled or not selectedField then
return
end

local size = selectedField.Size
local cf = selectedField.CFrame
local halfX = size.X / 2
local halfZ = size.Z / 2
local wallHeight = FIELD_WALL_HEIGHT
local thickness = FIELD_WALL_THICKNESS
local configs = {
    { Vector3.new(0, wallHeight / 2, halfZ - FIELD_WALL_MARGIN), Vector3.new(size.X, wallHeight, thickness) },
    { Vector3.new(0, wallHeight / 2, -halfZ + FIELD_WALL_MARGIN), Vector3.new(size.X, wallHeight, thickness) },
    { Vector3.new(halfX - FIELD_WALL_MARGIN, wallHeight / 2, 0), Vector3.new(thickness, wallHeight, size.Z) },
    { Vector3.new(-halfX + FIELD_WALL_MARGIN, wallHeight / 2, 0), Vector3.new(thickness, wallHeight, size.Z) },
}
for index, data in ipairs(configs) do
    local wall = fieldBoundsParts[index]
    wall.Size = data[2]
    wall.CFrame = cf * CFrame.new(data[1])
    wall.Parent = Workspace
end
end
local function cleanupTokenCaches(now)
for token, expire in pairs(visitedTokens) do
if not token.Parent or expire <= now then
visitedTokens[token] = nil
end
end

for token in pairs(tokenMetadata) do
    if not token.Parent then
        tokenMetadata[token] = nil
        if activeToken == token then
            activeToken = nil
            activeTokenScore = 0
        end
    end
end
end
local fieldHeatCache = {}
local currentFieldHeat = nil
local FIELD_HEAT_GRID = 6
local HEAT_DECAY_INTERVAL = 1
local HEAT_DECAY_RATE = 0.97
local lastHeatDecay = 0
local function getFieldHeatTable(name)
if not name then
return nil
end
if not fieldHeatCache[name] then
fieldHeatCache[name] = {}
end
return fieldHeatCache[name]
end
local function computeFieldCell(position)
if not selectedField then
return nil
end
local size = selectedField.Size
local relX = ((position.X - selectedField.Position.X) / size.X) + 0.5
local relZ = ((position.Z - selectedField.Position.Z) / size.Z) + 0.5
if relX < 0 or relX > 1 or relZ < 0 or relZ > 1 then
return nil
end
local idxX = math.clamp(math.floor(relX * FIELD_HEAT_GRID), 0, FIELD_HEAT_GRID - 1)
local idxZ = math.clamp(math.floor(relZ * FIELD_HEAT_GRID), 0, FIELD_HEAT_GRID - 1)
local key = string.format("%d:%d", idxX, idxZ)
return key, idxX, idxZ
end
local function addHeatSample(position, amount)
if not currentFieldHeat then
return
end
local key = computeFieldCell(position)
if not key then
return
end
local value = currentFieldHeat[key] or 0
currentFieldHeat[key] = value + (amount or 1)
end
local function decayFieldHeat(now)
if not currentFieldHeat then
return
end
if now - lastHeatDecay < HEAT_DECAY_INTERVAL then
return
end
lastHeatDecay = now
for key, value in pairs(currentFieldHeat) do
local newValue = value * HEAT_DECAY_RATE
if newValue < 0.05 then
currentFieldHeat[key] = nil
else
currentFieldHeat[key] = newValue
end
end
end
local function isInField(position)
if not selectedField then return false end
local fieldPos = selectedField.Position
local fieldSize = selectedField.Size
local inX = math.abs(position.X - fieldPos.X) <= (fieldSize.X / 2)
local inZ = math.abs(position.Z - fieldPos.Z) <= (fieldSize.Z / 2)
return inX and inZ
end
local function getHeatSpot()
if not currentFieldHeat or not selectedField then
return nil
end
local bestKey
local bestValue = -math.huge
for key, value in pairs(currentFieldHeat) do
if value > bestValue then
bestKey = key
bestValue = value
end
end
if not bestKey then
return nil
end
local idxX, idxZ = bestKey:match("^(%d+):(%d+)$")
idxX = tonumber(idxX)
idxZ = tonumber(idxZ)
if not idxX or not idxZ then
return nil
end
local size = selectedField.Size
local centerX = ((idxX + 0.5) / FIELD_HEAT_GRID - 0.5) * size.X * 0.9
local centerZ = ((idxZ + 0.5) / FIELD_HEAT_GRID - 0.5) * size.Z * 0.9
local base = selectedField.Position
local randomOffset = Vector3.new(
((math.random() * 2) - 1) * size.X * 0.05,
0,
((math.random() * 2) - 1) * size.Z * 0.05
)
return Vector3.new(base.X + centerX, base.Y + 3, base.Z + centerZ) + randomOffset
end
local function getRandomFieldSpot()
if not selectedField then return nil end
local size = selectedField.Size
local pos = selectedField.Position
local rx = math.random(-size.X / 2 * 0.9, size.X / 2 * 0.9)
local rz = math.random(-size.Z / 2 * 0.9, size.Z / 2 * 0.9)
return Vector3.new(pos.X + rx, pos.Y + 3, pos.Z + rz)
end
local function chooseWanderSpot(origin, nowTime)
local heatTarget = getHeatSpot()
local base = heatTarget or getRandomFieldSpot()
if not base then
return nil
end
if heatTarget then
wanderLastBase = heatTarget
else
wanderLastBase = nil
end
nowTime = nowTime or tick()
if origin then
local delta = base - origin
local dist = delta.Magnitude
if dist < MIN_WANDER_DISTANCE then
local dir = (dist > 0 and delta.Unit) or wanderDirection
base = origin + dir * MIN_WANDER_DISTANCE
end
end
if nowTime - lastWanderRotate > WANDER_ROTATE_INTERVAL then
local jitter = math.rad(math.random(-35, 35))
local currentAngle = math.atan2(wanderDirection.Z, wanderDirection.X)
local newAngle = currentAngle + jitter
wanderDirection = Vector3.new(math.cos(newAngle), 0, math.sin(newAngle))
lastWanderRotate = nowTime
end
local manualOffset = (wanderLastBase and (wanderLastBase - base)) or Vector3.new()
local offset = wanderDirection * math.random(10, 20) + manualOffset * 0.25
local candidate = base + offset
if not isInField(candidate) then
candidate = base
end
return candidate
end
local function getTokenInfo(token)
if not token then
return nil
end
local info = tokenMetadata[token]
if not info then
info = {}
tokenMetadata[token] = info
end
return info
end
local function updateTokenTracking(token, position, now)
local info = getTokenInfo(token)
if not info then
return nil
end
local lastPos = info.LastPos
local lastSeen = info.LastSeen or now
if lastPos then
local delta = math.max(now - lastSeen, MIN_SAMPLE_DELTA)
local rawVelocity = (position - lastPos) / delta
local speed = rawVelocity.Magnitude
if speed > MAX_TRACK_SPEED then
rawVelocity = rawVelocity.Unit * MAX_TRACK_SPEED
end
info.Velocity = rawVelocity
else
info.Velocity = Vector3.new()
end
info.LastPos = position
info.LastSeen = now
info.SpawnTime = info.SpawnTime or now
return info
end
local function predictTokenPosition(info, rootPos, moveSpeed)
if not info or not info.LastPos then
return nil
end
local predicted = info.LastPos
local velocity = info.Velocity or Vector3.new()
local speed = velocity.Magnitude
if speed > 0.01 then
local travelDist = (rootPos - predicted).Magnitude
local travelTime = math.clamp(travelDist / math.max(moveSpeed, 1), 0, MAX_PREDICTION_TIME)
if travelTime > 0 then
local projected = predicted + velocity * travelTime
local blend = math.clamp(travelTime / MAX_PREDICTION_TIME, 0.4, 0.9)
predicted = predicted:Lerp(projected, blend)
end
end
if not isInField(predicted) then
predicted = info.LastPos
end
return predicted
end
local FARM_DATABASE = {
["65867881"] = "Haste",
["1671281844"] = "Beamstorm",
["177997841"] = "Bear Morph / Glob",
["8083436978"] = "Inflate Balloons",
["1104415222"] = "Scratch",
["183390139"] = "Cog",
["4889322534"] = "Fuzz Bombs",
["5877939956"] = "Glitch / Map Corruption",
["1839454544"] = "Gummy Storm",
["2319083910"] = "Impale",
["4519549299"] = "Inferno",
["2000457501"] = "Inspire",
["3080529618"] = "Jelly Bean",
["1874564120"] = "Ability Token",
["4528379338"] = "Mark Surge",
["5877998606"] = "Mind Hack",
["4889470194"] = "Pollen Haze",
["1442725244"] = "Token Link",
["1629547638"] = "Token Link",
["3582501342"] = "Rain Call",
["8173559749"] = "Target Practice",
["8083943936"] = "Surprise Party",
["3582519526"] = "Tornado",
["4519523935"] = "Triangulate",
["1472256444"] = "Baby Love",
["2028574353"] = "Treat",
["4528414666"] = "Summon Frog",
["1472491940"] = "Bear Morph",
["1952740625"] = "Strawberry",
["1472135114"] = "Honey",
["2499514197"] = "Honey Mark",
["2499540966"] = "Pollen Mark",
["1952682401"] = "Sunflower Seed",
["1838129169"] = "Gumdrop",
["1753904608"] = "Tabby Love",
["1629649299"] = "Focus",
["1442863423"] = "Blue Boost",
["2028453802"] = "Blueberry",
["2652424740"] = "Festive Blessing",
["1442859163"] = "Red Boost",
["1952796032"] = "Pineapple",
}
local FARM_PRIORITY_ITEMS = { ["Token Link"] = true }
local TOKEN_PRIORITY_WEIGHT = {
    ["Token Link"] = 500,
    ["Token Link (Duped)"] = 550,
    ["Inspire"] = 70,
    ["Haste"] = 8,
    ["Baby Love"] = 55,
    ["Focus"] = 50,
    ["Melody"] = 50,
    ["Surprise Party"] = 50,
    ["Beamstorm"] = 45,
    ["Glitch"] = 45,
    ["Glitch / Map Corruption"] = 45,
    ["Mind Hack"] = 40,
    ["Mark Surge"] = 38,
    ["Bear Morph / Glob"] = 36,
    ["Bear Morph"] = 36,
    ["Pollen Mark"] = 35,
    ["Honey Mark"] = 34,
    ["Blue Boost"] = 32,
    ["Red Boost"] = 32,
    ["Pollen Haze"] = 32,
    ["Target Practice"] = 32,
    ["Gummy Storm"] = 32,
    ["Inferno"] = 32,
    ["Inflate Balloons"] = 30,
    ["Rain Call"] = 30,
    ["Triangulate"] = 29,
    ["Fuzz Bombs"] = 29,
    ["Summon Frog"] = 28,
    ["Festive Blessing"] = 28,
    ["Impale"] = 28,
    ["Cog"] = 26,
    ["Treat"] = 26,
    ["Blueberry"] = 18,
    ["Strawberry"] = 18,
    ["Pineapple"] = 17,
    ["Sunflower Seed"] = 17,
    ["Honey"] = 20,
    ["Gumdrop"] = 15,
    ["Jelly Bean"] = 15,
    ["Tabby Love"] = 45,
    ["Scratch"] = 33,
    ["Ability Token"] = 14,
    ["Rain Cloud"] = 30,
}
local function getTokenPriorityScore(name)
return TOKEN_PRIORITY_WEIGHT[name] or 12
end
local function computeCandidateScore(baseWeight, travelDist, spawnTime, now, transparency)
    local age = math.max(now - (spawnTime or now), 0)
    -- More points for older tokens that are about to despawn.
    local ageBonus = math.min(age * 3, 25)
    -- Bonus for transparency, also indicating it is about to despawn.
    local transparency = transparency or 0
    local transparencyBonus = transparency ^ 2 * 40 -- Slightly increased base bonus
    
    -- Add a large "emergency" bonus for tokens that are critically close to despawning.
    if transparency > 0.85 then
        transparencyBonus = transparencyBonus + 50
    end

    -- Distance penalty is more significant for further tokens.
    local distancePenalty = travelDist / 3.5
    local score = baseWeight + ageBonus + transparencyBonus - distancePenalty
    return score
end
local function getCleanID(str)
return tonumber(string.match(tostring(str), "%d+"))
end
local function dispenseHoney()
if isDispensing then return end
isDispensing = true

local char = LocalPlayer.Character
local humanoid = char and char:FindFirstChildOfClass("Humanoid")
local originalWalkSpeed = humanoid and humanoid.WalkSpeed or nil
local originalJumpPower = humanoid and humanoid.JumpPower or nil
local hivePosValue = LocalPlayer:FindFirstChild("SpawnPos") and LocalPlayer.SpawnPos.Value
local remote = ReplicatedStorage:FindFirstChild("Events", true) and ReplicatedStorage.Events:FindFirstChild("PlayerHiveCommand")
if char and hivePosValue and remote then
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
    hardTeleportTo(CFrame.new(hivePosValue.p + Vector3.new(0, 5, 0)))
    task.wait(1)
    remote:FireServer("ToggleHoneyMaking")
    task.wait(1)
    local pollen = LocalPlayer.CoreStats:FindFirstChild("Pollen")
    while isAutoFarmEnabled and pollen and pollen.Value > 10 do
        task.wait(0.5)
    end
    if isAutoFarmEnabled and pollen then
        task.wait(1)
    end
    remote:FireServer("ToggleHoneyMaking")
    task.wait(0.5)
    if isAutoFarmEnabled and selectedField then
        hardTeleportTo(selectedField.CFrame + Vector3.new(0, 5, 0))
    end
end
if humanoid then
    if originalWalkSpeed then
        humanoid.WalkSpeed = originalWalkSpeed
    end
    if originalJumpPower then
        humanoid.JumpPower = originalJumpPower
    end
end
isDispensing = false
end
local Window = Library:CreateWindow({
Title = "Eps1llon Hub | Bee Swarm Simulator"
})
local function getUIRoot()
local ok, ui = pcall(function()
if typeof(gethui) == "function" then
return gethui()
end
if typeof(get_hidden_gui) == "function" then
return get_hidden_gui()
end
if typeof(gethiddenui) == "function" then
return gethiddenui()
end
return nil
end)

if ok and ui then
    return ui
end
return CoreGui
end
local function protectGui(gui)
if typeof(gui) ~= "Instance" then return end

local ok, fn = pcall(function()
    return syn and syn.protect_gui
end)
if ok and typeof(fn) == "function" then
    pcall(fn, gui)
elseif typeof(protect_gui) == "function" then
    pcall(protect_gui, gui)
end
end
local function destroyStatsPanel()
if statsGui then
statsGui:Destroy()
end
statsGui = nil
statsLabel = nil
end
local function createStatsPanel()
destroyStatsPanel()

local root = getUIRoot()
local gui = Instance.new("ScreenGui")
gui.Name = "Eps_StatsPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(gui)
gui.Parent = root
local frame = Instance.new("Frame")
frame.Name = "StatsFrame"
frame.Size = UDim2.fromOffset(250, 110)
frame.Position = UDim2.new(1, -270, 1, -160)
frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
frame.BorderSizePixel = 0
frame.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 1
stroke.Thickness = 1
stroke.Enabled = false
stroke.Parent = frame
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Parent = frame
title.Size = UDim2.new(1, -16, 0, 18)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(230, 235, 240)
title.Text = "Auto Farm Stats"
local line = Instance.new("Frame")
line.Parent = frame
line.Size = UDim2.new(1, -16, 0, 1)
line.Position = UDim2.fromOffset(8, 28)
line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
line.BackgroundTransparency = 0.9
line.BorderSizePixel = 0
local body = Instance.new("TextLabel")
body.Name = "Body"
body.Parent = frame
body.Size = UDim2.new(1, -16, 1, -38)
body.Position = UDim2.fromOffset(8, 32)
body.BackgroundTransparency = 1
body.Font = Enum.Font.Gotham
body.TextSize = 12
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextColor3 = Color3.fromRGB(170, 176, 186)
body.TextWrapped = true
body.Text = "Waiting for Auto Farm..."
local dragging = false
local dragInput
local dragStart
local startPos
local function update(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        frame.Position.X.Scale,
        startPos.X.Offset + delta.X,
        frame.Position.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
        update(input)
    end
end)
statsGui = gui
statsLabel = body
frame.BackgroundTransparency = 1
title.TextTransparency = 1
body.TextTransparency = 1
line.BackgroundTransparency = 1
local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(frame, ti, { BackgroundTransparency = 0 }):Play()
TweenService:Create(title, ti, { TextTransparency = 0 }):Play()
TweenService:Create(body, ti, { TextTransparency = 0 }):Play()
TweenService:Create(line, ti, { BackgroundTransparency = 0.9 }):Play()
end
-- ESP core state (shared by Player ESP + Game ESP, logic copied from full Bee Swarm script)
local THEME = {
panel = Color3.fromRGB(16, 18, 24),
panel2 = Color3.fromRGB(22, 24, 30),
text = Color3.fromRGB(230, 235, 240),
textDim = Color3.fromRGB(170, 176, 186),
accentA = Color3.fromRGB(64, 156, 255),
accentB = Color3.fromRGB(0, 204, 204),
gold = Color3.fromRGB(255, 215, 0),
}
local function getHudRoot()
local ok, ui = pcall(function()
return gethui and gethui()
end)
if ok and ui then
return ui
end
return game:GetService("CoreGui")
end
local function safeDisconnectConn(conn)
if conn and typeof(conn) == "RBXScriptConnection" then
pcall(function()
conn:Disconnect()
end)
end
end
local function setAntiAfk(state)
antiAfkEnabled = state and true or false
if antiAfkConnection then
safeDisconnectConn(antiAfkConnection)
antiAfkConnection = nil
end
if antiAfkEnabled then
antiAfkConnection = LocalPlayer.Idled:Connect(function()
pcall(function()
VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
task.wait(1)
VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
end)
end)
end
end
local function doAutoClaimHive()
task.spawn(function()
pcall(function()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

        -- Check for existing hive ownership
        local hivePlatforms = Workspace:FindFirstChild("HivePlatforms")
        local alreadyOwnsHive = false
        if hivePlatforms then
            for _, platform in ipairs(hivePlatforms:GetChildren()) do
                local playerRef = platform:FindFirstChild("PlayerRef")
                if playerRef and playerRef.Value == LocalPlayer then
                    alreadyOwnsHive = true
                    break
                end
            end
        end
        if alreadyOwnsHive then
            notify("Auto Claim Hive", "You already own a hive.", 3)
            if uiObjects.autoClaimHiveToggle then
                uiObjects.autoClaimHiveToggle:SetState(false)
            end
            isAutoClaimHiveEnabled = false
            return
        end
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local TweenService = game:GetService("TweenService")

        local Character = LocalPlayer.Character
        if not Character or not isAutoClaimHiveEnabled then return end
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        if not RootPart then return end

        local Events = ReplicatedStorage:FindFirstChild("Events")
        if not Events then return end
        local ClaimHiveEvent = Events:FindFirstChild("ClaimHive")
        local BeeClientLoadedEvent = Events:FindFirstChild("BeeClientLoaded")
        if not ClaimHiveEvent or not BeeClientLoadedEvent then return end
        local function TweenTo(targetPos)
            local tween = TweenService:Create(RootPart, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {CFrame = CFrame.new(targetPos)})
            tween:Play()
            tween.Completed:Wait()
        end
        local honeycombs = Workspace:FindFirstChild("Honeycombs")
        if not honeycombs then return end
        local claimedHive = false
        for _, hive in ipairs(honeycombs:GetChildren()) do
            if not isAutoClaimHiveEnabled then break end
            local owner = hive:FindFirstChild("Owner")
            local hiveID = hive:FindFirstChild("HiveID")
            local spawnPos = hive:FindFirstChild("SpawnPos")
            if owner and hiveID and spawnPos and owner.Value == nil then
                TweenTo(spawnPos.Value.p + Vector3.new(0, 3, 0))

                if not isAutoClaimHiveEnabled then break end
                ClaimHiveEvent:FireServer(hiveID.Value)
                task.wait(0.5)

                BeeClientLoadedEvent:FireServer()

                claimedHive = true
                notify("Auto Claim Hive", "Successfully claimed a hive!", 3)
                break
            end
        end
        if not claimedHive then
            notify("Auto Claim Hive", "No unowned hives found.", 3)
        end
        if uiObjects.autoClaimHiveToggle then
            uiObjects.autoClaimHiveToggle:SetState(false)
        end
        isAutoClaimHiveEnabled = false
    end)
end)
end
local boxEspEnabled = false
local healthEspEnabled = false
local tracersEnabled = false
local teamCheckEnabled = false
local teamColorEnabled = true
local nameEspEnabled = false
local hotbarEspEnabled = false
local hotbarDisplaySet = {}
local BlissfulSettings = {
Box_Color = Color3.fromRGB(255, 0, 0),
Tracer_Color = Color3.fromRGB(255, 0, 0),
Tracer_Thickness = 1,
Box_Thickness = 1,
Tracer_Origin = "Bottom",
Tracer_FollowMouse = false,
}
local BlissfulTeam_Check = {
Green = Color3.fromRGB(0, 255, 0),
Red = Color3.fromRGB(255, 0, 0),
}
local mouse = player:GetMouse()
-- Some executors do not provide the Drawing API.
-- Detect support once and fall back to no-op objects if unavailable.
local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata")
and typeof(Drawing.new) == "function"
-- Sprout ESP configuration (Drawing-based)
local sproutEspEnabled = false
local sproutDrawingCache = {}
local SproutTextSize = 19
local SproutTextOutline = true
local SproutVerticalOffset = 10
local SproutTextFont = hasDrawing
and Drawing.Fonts
and (Drawing.Fonts.Plex or Drawing.Fonts.UI)
or nil
local SproutColors = {
["Default Sprout"] = Color3.fromRGB(180, 190, 186),
["Diamond Sprout"] = Color3.fromRGB(103, 162, 201),
}
local function isColorClose(colorA, colorB)
local tolerance = 0.05
return (
math.abs(colorA.R - colorB.R) < tolerance
and math.abs(colorA.G - colorB.G) < tolerance
and math.abs(colorA.B - colorB.B) < tolerance
)
end
local function NewQuad(thickness, color)
if hasDrawing then
local quad = Drawing.new("Quad")
quad.Visible = false
quad.PointA = Vector2.new(0, 0)
quad.PointB = Vector2.new(0, 0)
quad.PointC = Vector2.new(0, 0)
quad.PointD = Vector2.new(0, 0)
quad.Color = color
quad.Filled = false
quad.Thickness = thickness
quad.Transparency = 1
return quad
end

-- Fallback: simple table that accepts the same fields/methods
local quad = {
    Visible = false,
    PointA = Vector2.new(0, 0),
    PointB = Vector2.new(0, 0),
    PointC = Vector2.new(0, 0),
    PointD = Vector2.new(0, 0),
    Color = color,
    Filled = false,
    Thickness = thickness,
    Transparency = 1,
}
function quad:Remove() end
return quad
end
local function NewLine(thickness, color)
if hasDrawing then
local line = Drawing.new("Line")
line.Visible = false
line.From = Vector2.new(0, 0)
line.To = Vector2.new(0, 0)
line.Color = color
line.Thickness = thickness
line.Transparency = 1
return line
end

local line = {
    Visible = false,
    From = Vector2.new(0, 0),
    To = Vector2.new(0, 0),
    Color = color,
    Thickness = thickness,
    Transparency = 1,
}
function line:Remove() end
return line
end
local function Visibility(state, lib)
for u, x in pairs(lib) do
if u == "healthbar" or u == "greenhealth" then
x.Visible = state and healthEspEnabled
elseif u == "blacktracer" or u == "tracer" then
x.Visible = state and tracersEnabled
elseif u == "black" or u == "box" then
x.Visible = state and boxEspEnabled
else
x.Visible = state
end
end
end
local function ToColor3(col)
local r = col.r
local g = col.g
local b = col.b
return Color3.new(r, g, b)
end
local skeletonEspEnabled = false
local trackedPlayers = {}
local black = Color3.fromRGB(0, 0, 0)
local function ESP(plr)
local library = {
blacktracer = NewLine(BlissfulSettings.Tracer_Thickness * 2, black),
tracer = NewLine(
BlissfulSettings.Tracer_Thickness,
BlissfulSettings.Tracer_Color
),
black = NewQuad(BlissfulSettings.Box_Thickness * 2, black),
box = NewQuad(
BlissfulSettings.Box_Thickness,
BlissfulSettings.Box_Color
),
healthbar = NewLine(5, black),
greenhealth = NewLine(3, black),
nametext = nil,
hotbartext = nil,
teamtext = nil,
}

local function Colorize(color)
    for u, x in pairs(library) do
        if
            x ~= library.blacktracer
            and x ~= library.black
            and x ~= library.healthbar
        then
            x.Color = color
        end
    end
end
local hotbarGui = nil
local hotbarFrame = nil
local hotbarViewport = nil
local hotbarCam = nil
local lastToolName = nil
local function ensureHotbarGui(anchorPart)
    if hotbarGui and hotbarGui.Parent == nil then
        hotbarGui = nil
    end
    if hotbarGui then
        return
    end
    hotbarGui = Instance.new("BillboardGui")
    hotbarGui.Name = "HotbarBillboard_" .. plr.Name
    hotbarGui.AlwaysOnTop = true
    hotbarGui.Size = UDim2.fromOffset(64, 64)
    hotbarGui.StudsOffset = Vector3.new(0, -3.8, 0)
    hotbarGui.MaxDistance = 500
    hotbarGui.Adornee = anchorPart
    hotbarGui.Parent = getHudRoot()
    hotbarFrame = Instance.new("Frame")
    hotbarFrame.Size = UDim2.fromScale(1, 1)
    hotbarFrame.BackgroundColor3 = THEME.panel
    hotbarFrame.BackgroundTransparency = 0.35
    hotbarFrame.BorderSizePixel = 0
    hotbarFrame.Parent = hotbarGui
    local corner = Instance.new("UICorner", hotbarFrame)
    corner.CornerRadius = UDim.new(0, 10)
    hotbarViewport = Instance.new("ViewportFrame")
    hotbarViewport.AnchorPoint = Vector2.new(0.5, 0.5)
    hotbarViewport.Position = UDim2.fromScale(0.5, 0.5)
    hotbarViewport.Size = UDim2.fromScale(0.9, 0.9)
    hotbarViewport.BackgroundTransparency = 1
    hotbarViewport.Ambient = Color3.fromRGB(200, 200, 200)
    hotbarViewport.LightColor = Color3.fromRGB(255, 255, 255)
    hotbarViewport.LightDirection = Vector3.new(0, -1, -1)
    hotbarViewport.Parent = hotbarFrame
    hotbarCam = Instance.new("Camera")
    hotbarCam.FieldOfView = 40
    hotbarCam.Parent = hotbarViewport
    hotbarViewport.CurrentCamera = hotbarCam
end
local function clearViewport()
    if hotbarViewport then
        for _, ch in ipairs(hotbarViewport:GetChildren()) do
            if ch:IsA("Model") or ch:IsA("BasePart") then
                ch:Destroy()
            end
        end
    end
end
local function setViewportToTool(tool)
    if not tool then
        return
    end
    clearViewport()
    local model = Instance.new("Model")
    model.Name = "ToolPreview"
    model.Parent = hotbarViewport
    local function cloneParts(instance)
        for _, d in ipairs(instance:GetDescendants()) do
            if d:IsA("BasePart") then
                local cp = d:Clone()
                cp.Anchored = true
                cp.CanCollide = false
                cp.Parent = model
            end
        end
    end
    pcall(cloneParts, tool)
    local handle = tool:FindFirstChild("Handle")
    if handle and #model:GetChildren() == 0 then
        local h = handle:Clone()
        h.Anchored = true
        h.CanCollide = false
        h.Parent = model
    end
    local cf, size = model:GetBoundingBox()
    local center = cf.Position
    local maxDim = math.max(size.X, size.Y, size.Z)
    local distance = (maxDim == 0 and 2) or (maxDim * 2.2)
    local viewPos = (cf * CFrame.new(0, 0, distance)).Position
    hotbarCam.CFrame = CFrame.new(viewPos, center)
end
local function destroyHotbarGui()
    if hotbarGui then
        pcall(function()
            hotbarGui:Destroy()
        end)
    end
    hotbarGui, hotbarFrame, hotbarViewport, hotbarCam = nil, nil, nil, nil
    lastToolName = nil
end
local function Updater()
    local connection
    connection = game:GetService("RunService").RenderStepped
        :Connect(function()
            if
                plr.Character ~= nil
                and plr.Character:FindFirstChild("Humanoid") ~= nil
                and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil
                and plr.Character.Humanoid.Health > 0
                and plr.Character:FindFirstChild("Head") ~= nil
            then
                local humanoid = plr.Character.Humanoid
                local hrp = plr.Character.HumanoidRootPart
                local shakeOffset = humanoid.CameraOffset
                local stable_hrp_pos_3d = hrp.Position - shakeOffset
                local HumPos, OnScreen =
                    camera:WorldToViewportPoint(stable_hrp_pos_3d)
                if OnScreen then
                    local box_top_3d = stable_hrp_pos_3d
                        + Vector3.new(0, 3, 0)
                    local box_bottom_3d = stable_hrp_pos_3d
                        + Vector3.new(0, -3, 0)
                    local box_top_2d =
                        camera:WorldToViewportPoint(box_top_3d)
                    local box_bottom_2d =
                        camera:WorldToViewportPoint(box_bottom_3d)
                    local proj_height = box_bottom_2d.Y - box_top_2d.Y
                    local half_height = proj_height / 2
                    local half_width = half_height / 2
                    half_height = math.clamp(half_height, 2, math.huge)
                    half_width = math.clamp(half_width, 1, math.huge)
                    local center_x = HumPos.X
                    local center_y = HumPos.Y
                    local yTop = center_y - half_height
                    local scale = math.clamp(half_height, 8, 220)
                    local nameSize =
                        math.floor(math.clamp(scale * 0.30, 10, 18))
                    local hotbarSize =
                        math.floor(math.clamp(scale * 0.28, 9, 16))
                    local teamSize =
                        math.floor(math.clamp(scale * 0.22, 8, 13))
                    local margin =
                        math.floor(math.clamp(scale * 0.10, 5, 12))
                    local spacing =
                        math.floor(math.clamp(scale * 0.06, 2, 7))
                    do
                        if nameEspEnabled then
                            if not library.nametext then
                                local t = Drawing.new("Text")
                                t.Visible = false
                                t.Center = true
                                t.Outline = true
                                t.Size = nameSize
                                t.Color = Color3.fromRGB(255, 255, 255)
                                library.nametext = t
                            end
                            local t = library.nametext
                            t.Size = nameSize
                            t.Text = plr.DisplayName or plr.Name
                            t.Position = Vector2.new(
                                center_x,
                                yTop
                                    - (margin + math.floor(nameSize * 0.60))
                            )
                            t.Visible = true
                        elseif library.nametext then
                            library.nametext.Visible = false
                        end
                    end
                    if boxEspEnabled then
                        local function Size(item)
                            item.PointA = Vector2.new(
                                center_x + half_width,
                                center_y - half_height
                            )
                            item.PointB = Vector2.new(
                                center_x - half_width,
                                center_y - half_height
                            )
                            item.PointC = Vector2.new(
                                center_x - half_width,
                                center_y + half_height
                            )
                            item.PointD = Vector2.new(
                                center_x + half_width,
                                center_y + half_height
                            )
                        end
                        Size(library.box)
                        Size(library.black)
                        library.box.Color = Color3.new(1, 1, 1)
                        library.box.Visible = true
                        library.black.Visible = true
                    else
                        library.box.Visible = false
                        library.black.Visible = false
                    end
                    if tracersEnabled then
                        if BlissfulSettings.Tracer_Origin == "Middle" then
                            library.tracer.From = camera.ViewportSize * 0.5
                            library.blacktracer.From = camera.ViewportSize
                                * 0.5
                        elseif
                            BlissfulSettings.Tracer_Origin == "Bottom"
                        then
                            library.tracer.From = Vector2.new(
                                camera.ViewportSize.X * 0.5,
                                camera.ViewportSize.Y
                            )
                            library.blacktracer.From = Vector2.new(
                                camera.ViewportSize.X * 0.5,
                                camera.ViewportSize.Y
                            )
                        end
                        if BlissfulSettings.Tracer_FollowMouse then
                            library.tracer.From =
                                Vector2.new(mouse.X, mouse.Y + 36)
                            library.blacktracer.From =
                                Vector2.new(mouse.X, mouse.Y + 36)
                        end
                        library.tracer.To =
                            Vector2.new(center_x, center_y + half_height)
                        library.blacktracer.To =
                            Vector2.new(center_x, center_y + half_height)
                        library.tracer.Visible = true
                        library.blacktracer.Visible = true
                    else
                        library.tracer.Visible = false
                        library.blacktracer.Visible = false
                    end
                    if healthEspEnabled then
                        local d = 2 * half_height
                        local healthoffset = plr.Character.Humanoid.Health
                            / plr.Character.Humanoid.MaxHealth
                            * d
                        local healthbar_x = center_x - half_width - 4
                        local healthbar_top_y = center_y - half_height
                        local healthbar_bottom_y = center_y + half_height
                        library.greenhealth.From =
                            Vector2.new(healthbar_x, healthbar_bottom_y)
                        library.greenhealth.To = Vector2.new(
                            healthbar_x,
                            healthbar_bottom_y - healthoffset
                        )
                        library.healthbar.From =
                            Vector2.new(healthbar_x, healthbar_bottom_y)
                        library.healthbar.To =
                            Vector2.new(healthbar_x, healthbar_top_y)
                        local green = Color3.fromRGB(0, 255, 0)
                        local red = Color3.fromRGB(255, 0, 0)
                        library.greenhealth.Color = red:lerp(
                            green,
                            plr.Character.Humanoid.Health
                                / plr.Character.Humanoid.MaxHealth
                        )
                        library.healthbar.Visible = true
                        library.greenhealth.Visible = true
                    else
                        library.healthbar.Visible = false
                        library.greenhealth.Visible = false
                    end
                    do
                        local tool = nil
                        pcall(function()
                            tool =
                                plr.Character:FindFirstChildOfClass("Tool")
                        end)
                        if hotbarEspEnabled and hotbarDisplaySet.Text then
                            if not library.hotbartext then
                                local ht = Drawing.new("Text")
                                ht.Visible = false
                                ht.Center = true
                                ht.Outline = true
                                ht.Size = hotbarSize
                                ht.Color = Color3.fromRGB(200, 200, 200)
                                library.hotbartext = ht
                            end
                            local ht = library.hotbartext
                            ht.Size = hotbarSize
                            local label = (tool and tool.Name) or ""
                            ht.Text = label
                            local yBottom = center_y + half_height
                            local y = yBottom
                                + math.max(
                                    1,
                                    margin - math.floor(hotbarSize * 0.35)
                                )
                            ht.Position = Vector2.new(center_x, y)
                            ht.Visible = (label ~= "")
                        elseif library.hotbartext then
                            library.hotbartext.Visible = false
                        end
                        if
                            hotbarEspEnabled
                            and hotbarDisplaySet.Image
                            and tool
                        then
                            ensureHotbarGui(plr.Character.HumanoidRootPart)
                            if hotbarGui then
                                local px = math.floor(
                                    math.clamp(half_width * 1.2, 26, 84)
                                )
                                hotbarGui.Size = UDim2.fromOffset(px, px)
                                local currName = tool.Name
                                if currName ~= lastToolName then
                                    lastToolName = currName
                                    setViewportToTool(tool)
                                end
                            end
                        else
                            destroyHotbarGui()
                        end
                    end
                    do
                        local teamLabel = nil
                        local teamObj = plr.Team
                        if
                            teamObj
                            and teamObj.Name
                            and teamObj.Name ~= ""
                        then
                            teamLabel = teamObj.Name
                        elseif plr.TeamColor then
                            teamLabel = tostring(plr.TeamColor)
                        end
                        if teamLabel then
                            if not library.teamtext then
                                local tt = Drawing.new("Text")
                                tt.Visible = false
                                tt.Center = false
                                tt.Outline = true
                                tt.Size = teamSize
                                tt.Color = Color3.fromRGB(200, 200, 200)
                                library.teamtext = tt
                            end
                            local tt = library.teamtext
                            tt.Size = teamSize
                            tt.Text = teamLabel
                            tt.Position = Vector2.new(
                                center_x + half_width + 4,
                                yTop
                                    + math.max(
                                        2,
                                        math.floor(teamSize * 0.3)
                                    )
                            )
                            tt.Visible = true
                        elseif library.teamtext then
                            library.teamtext.Visible = false
                        end
                    end
                    library.tracer.Color = BlissfulSettings.Tracer_Color
                    library.box.Color = Color3.new(1, 1, 1)
                else
                    library.box.Visible = false
                    library.black.Visible = false
                    library.tracer.Visible = false
                    library.blacktracer.Visible = false
                    library.healthbar.Visible = false
                    library.greenhealth.Visible = false
                    if library.nametext then
                        library.nametext.Visible = false
                    end
                    if library.hotbartext then
                        library.hotbartext.Visible = false
                    end
                    if library.teamtext then
                        library.teamtext.Visible = false
                    end
                    destroyHotbarGui()
                end
            else
                library.box.Visible = false
                library.black.Visible = false
                library.tracer.Visible = false
                library.blacktracer.Visible = false
                library.healthbar.Visible = false
                library.greenhealth.Visible = false
                if library.nametext then
                    library.nametext.Visible = false
                end
                if library.hotbartext then
                    library.hotbartext.Visible = false
                end
                if library.teamtext then
                    library.teamtext.Visible = false
                end
                if game.Players:FindFirstChild(plr.Name) == nil then
                    connection:Disconnect()
                    pcall(function()
                        if destroyHotbarGui then
                            destroyHotbarGui()
                        end
                    end)
                    for _, drawing in pairs(library) do
                        pcall(function()
                            if drawing and drawing.Remove then
                                drawing:Remove()
                            end
                        end)
                    end
                    library = nil
                end
            end
        end)
end
coroutine.wrap(Updater)()
end
local function DrawSkeletonESP(plr)
local data = trackedPlayers[plr]
if not data then
return
end

local function DrawLine()
    if hasDrawing then
        local l = Drawing.new("Line")
        l.Visible = false
        l.From = Vector2.new(0, 0)
        l.To = Vector2.new(1, 1)
        l.Color = Color3.fromRGB(255, 255, 255)
        l.Thickness = 1
        l.Transparency = 1
        return l
    end
    local l = {
        Visible = false,
        From = Vector2.new(0, 0),
        To = Vector2.new(0, 0),
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1,
        Transparency = 1,
    }
    function l:Remove() end
    return l
end
repeat
    task.wait()
until plr.Character ~= nil
    and plr.Character:FindFirstChild("Humanoid") ~= nil

local limbs = {}
local isR15 = (plr.Character.Humanoid.RigType == Enum.HumanoidRigType.R15)
if isR15 then
    limbs = {
        Head_UpperTorso = DrawLine(),
        UpperTorso_LowerTorso = DrawLine(),
        UpperTorso_LeftUpperArm = DrawLine(),
        LeftUpperArm_LeftLowerArm = DrawLine(),
        LeftLowerArm_LeftHand = DrawLine(),
        UpperTorso_RightUpperArm = DrawLine(),
        RightUpperArm_RightLowerArm = DrawLine(),
        RightLowerArm_RightHand = DrawLine(),
        LowerTorso_LeftUpperLeg = DrawLine(),
        LeftUpperLeg_LeftLowerLeg = DrawLine(),
        LeftLowerLeg_LeftFoot = DrawLine(),
        LowerTorso_RightUpperLeg = DrawLine(),
        RightUpperLeg_RightLowerLeg = DrawLine(),
        RightLowerLeg_RightFoot = DrawLine(),
    }
else
    limbs = {
        Head_Spine = DrawLine(),
        Spine = DrawLine(),
        LeftArm = DrawLine(),
        LeftArm_UpperTorso = DrawLine(),
        RightArm = DrawLine(),
        RightArm_UpperTorso = DrawLine(),
        LeftLeg = DrawLine(),
        LeftLeg_LowerTorso = DrawLine(),
        RightLeg = DrawLine(),
        RightLeg_LowerTorso = DrawLine(),
    }
end
local function SetVisible(state)
    if limbs then
        for _, v in pairs(limbs) do
            if v and v.Visible ~= state then
                v.Visible = state
            end
        end
    end
end
data.SkeletonVisibilityFunc = SetVisible
data.SkeletonLimbs = limbs
if isR15 then
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not skeletonEspEnabled then
            SetVisible(false)
            return
        end
        if
            plr.Character
            and plr.Character:FindFirstChild("Humanoid")
            and plr.Character:FindFirstChild("HumanoidRootPart")
            and plr.Character.Humanoid.Health > 0
        then
            local _, onScreen = camera:WorldToViewportPoint(
                plr.Character.HumanoidRootPart.Position
            )
            if onScreen then
                pcall(function()
                    local H = camera:WorldToViewportPoint(
                        plr.Character.Head.Position
                    )
                    local UT = camera:WorldToViewportPoint(
                        plr.Character.UpperTorso.Position
                    )
                    local LT = camera:WorldToViewportPoint(
                        plr.Character.LowerTorso.Position
                    )
                    local LUA = camera:WorldToViewportPoint(
                        plr.Character.LeftUpperArm.Position
                    )
                    local LLA = camera:WorldToViewportPoint(
                        plr.Character.LeftLowerArm.Position
                    )
                    local LH = camera:WorldToViewportPoint(
                        plr.Character.LeftHand.Position
                    )
                    local RUA = camera:WorldToViewportPoint(
                        plr.Character.RightUpperArm.Position
                    )
                    local RLA = camera:WorldToViewportPoint(
                        plr.Character.RightLowerArm.Position
                    )
                    local RH = camera:WorldToViewportPoint(
                        plr.Character.RightHand.Position
                    )
                    local LUL = camera:WorldToViewportPoint(
                        plr.Character.LeftUpperLeg.Position
                    )
                    local LLL = camera:WorldToViewportPoint(
                        plr.Character.LeftLowerLeg.Position
                    )
                    local LF = camera:WorldToViewportPoint(
                        plr.Character.LeftFoot.Position
                    )
                    local RUL = camera:WorldToViewportPoint(
                        plr.Character.RightUpperLeg.Position
                    )
                    local RLL = camera:WorldToViewportPoint(
                        plr.Character.RightLowerLeg.Position
                    )
                    local RF = camera:WorldToViewportPoint(
                        plr.Character.RightFoot.Position
                    )
                    limbs.Head_UpperTorso.From, limbs.Head_UpperTorso.To =
                        Vector2.new(H.X, H.Y), Vector2.new(UT.X, UT.Y)
                    limbs.UpperTorso_LowerTorso.From, limbs.UpperTorso_LowerTorso.To =
                        Vector2.new(UT.X, UT.Y), Vector2.new(LT.X, LT.Y)
                    limbs.UpperTorso_LeftUpperArm.From, limbs.UpperTorso_LeftUpperArm.To =
                        Vector2.new(UT.X, UT.Y), Vector2.new(LUA.X, LUA.Y)
                    limbs.LeftUpperArm_LeftLowerArm.From, limbs.LeftUpperArm_LeftLowerArm.To =
                        Vector2.new(LUA.X, LUA.Y), Vector2.new(LLA.X, LLA.Y)
                    limbs.LeftLowerArm_LeftHand.From, limbs.LeftLowerArm_LeftHand.To =
                        Vector2.new(LLA.X, LLA.Y), Vector2.new(LH.X, LH.Y)
                    limbs.UpperTorso_RightUpperArm.From, limbs.UpperTorso_RightUpperArm.To =
                        Vector2.new(UT.X, UT.Y), Vector2.new(RUA.X, RUA.Y)
                    limbs.RightUpperArm_RightLowerArm.From, limbs.RightUpperArm_RightLowerArm.To =
                        Vector2.new(RUA.X, RUA.Y), Vector2.new(RLA.X, RLA.Y)
                    limbs.RightLowerArm_RightHand.From, limbs.RightLowerArm_RightHand.To =
                        Vector2.new(RLA.X, RLA.Y), Vector2.new(RH.X, RH.Y)
                    limbs.LowerTorso_LeftUpperLeg.From, limbs.LowerTorso_LeftUpperLeg.To =
                        Vector2.new(LT.X, LT.Y), Vector2.new(LUL.X, LUL.Y)
                    limbs.LeftUpperLeg_LeftLowerLeg.From, limbs.LeftUpperLeg_LeftLowerLeg.To =
                        Vector2.new(LUL.X, LUL.Y), Vector2.new(LLL.X, LLL.Y)
                    limbs.LeftLowerLeg_LeftFoot.From, limbs.LeftLowerLeg_LeftFoot.To =
                        Vector2.new(LLL.X, LLL.Y), Vector2.new(LF.X, LF.Y)
                    limbs.LowerTorso_RightUpperLeg.From, limbs.LowerTorso_RightUpperLeg.To =
                        Vector2.new(LT.X, LT.Y), Vector2.new(RUL.X, RUL.Y)
                    limbs.RightUpperLeg_RightLowerLeg.From, limbs.RightUpperLeg_RightLowerLeg.To =
                        Vector2.new(RUL.X, RUL.Y), Vector2.new(RLL.X, RLL.Y)
                    limbs.RightLowerLeg_RightFoot.From, limbs.RightLowerLeg_RightFoot.To =
                        Vector2.new(RLL.X, RLL.Y), Vector2.new(RF.X, RF.Y)
                end)
                if not limbs.Head_UpperTorso.Visible then
                    SetVisible(true)
                end
            else
                if limbs.Head_UpperTorso.Visible then
                    SetVisible(false)
                end
            end
        else
            if limbs.Head_UpperTorso and limbs.Head_UpperTorso.Visible then
                SetVisible(false)
            end
            if not Players:FindFirstChild(plr.Name) then
                for _, v in pairs(limbs) do
                    pcall(function()
                        v:Remove()
                    end)
                end
                limbs = nil
                safeDisconnectConn(connection)
            end
        end
    end)
    data.SkeletonConnection = connection
end
end
-- Sprout ESP loop
RunService.RenderStepped:Connect(function()
if not hasDrawing then
-- Hard cleanup if Drawing is unavailable
for inst, drawing in pairs(sproutDrawingCache) do
pcall(function()
if drawing.Remove then
drawing:Remove()
end
end)
sproutDrawingCache[inst] = nil
end
return
end

if not sproutEspEnabled then
    for _, drawing in pairs(sproutDrawingCache) do
        drawing.Visible = false
    end
    return
end
-- Cleanup / hide old labels
for inst, drawing in pairs(sproutDrawingCache) do
    if not inst or not inst.Parent then
        pcall(function()
            if drawing.Remove then
                drawing:Remove()
            end
        end)
        sproutDrawingCache[inst] = nil
    else
        drawing.Visible = false
    end
end
local sproutsFolder = Workspace:FindFirstChild("Sprouts")
if not sproutsFolder then
    return
end
for _, sprout_item in ipairs(sproutsFolder:GetChildren()) do
    pcall(function()
        if sprout_item.Name ~= "Sprout" then
            return
        end
        local rootPart
        if sprout_item:IsA("Model") then
            rootPart = sprout_item.PrimaryPart
            if not rootPart then
                rootPart =
                    sprout_item:FindFirstChildWhichIsA("BasePart", true)
            end
        elseif sprout_item:IsA("BasePart") then
            rootPart = sprout_item
        end
        if not rootPart then
            return
        end
        local valueLabel
        for _, d in ipairs(sprout_item:GetDescendants()) do
            if d:IsA("TextLabel") then
                valueLabel = d
                break
            end
        end
        if not valueLabel then
            return
        end
        local displayText = ""
        local displayColor = Color3.fromRGB(255, 255, 255)
        local isSpecialType = false
        for name, color in pairs(SproutColors) do
            if isColorClose(valueLabel.TextColor3, color) then
                displayText = name
                displayColor = color
                isSpecialType = true
                break
            end
        end
        if not isSpecialType then
            local health = valueLabel.Text:match("([%d,]+)$")
            if health then
                displayText = "Sprout (" .. health .. ")"
            else
                displayText = "Sprout"
            end
        end
        if displayText ~= "" then
            local screenPos, onScreen = camera:WorldToViewportPoint(
                rootPart.Position + Vector3.new(0, SproutVerticalOffset, 0)
            )
            if onScreen then
                local drawing = sproutDrawingCache[sprout_item]
                if not drawing then
                    drawing = Drawing.new("Text")
                    sproutDrawingCache[sprout_item] = drawing
                end
                drawing.Text = displayText
                drawing.Color = displayColor
                drawing.Size = SproutTextSize
                if SproutTextFont then
                    drawing.Font = SproutTextFont
                end
                drawing.Center = true
                drawing.Outline = SproutTextOutline
                drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                drawing.Visible = true
            end
        end
    end)
end
end)
for _, v in pairs(Players:GetPlayers()) do
if v.Name ~= player.Name then
trackedPlayers[v] = trackedPlayers[v] or {}
coroutine.wrap(ESP)(v)
task.spawn(DrawSkeletonESP, v)
end
end
Players.PlayerAdded:Connect(function(newplr)
if newplr.Name ~= player.Name then
trackedPlayers[newplr] = trackedPlayers[newplr] or {}
coroutine.wrap(ESP)(newplr)
task.spawn(DrawSkeletonESP, newplr)
end
end)
Players.PlayerRemoving:Connect(function(rem)
local data = trackedPlayers[rem]
if data then
if data.SkeletonConnection then
safeDisconnectConn(data.SkeletonConnection)
end
if data.SkeletonLimbs then
for _, line in pairs(data.SkeletonLimbs) do
pcall(function()
line:Remove()
end)
end
end
trackedPlayers[rem] = nil
end
end)
local PlayerPage = Window:CreatePage({
Title = "Player",
Icon = "rbxassetid://110673269470793"
})
local FarmingPage = Window:CreatePage({
Title = "Farming",
Icon = "rbxassetid://105067681602444"
})
local HelperPage = Window:CreatePage({
Title = "Helper",
Icon = "rbxassetid://102233250280118"
})
local CombatPage = Window:CreatePage({
Title = "Combat",
Icon = "rbxassetid://133154037851337"
})
local TeleportPage = Window:CreatePage({
Title = "Teleport",
Icon = "rbxassetid://119605181458611"
})
local MiscPage = Window:CreatePage({
Title = "Miscellaneous",
Icon = "rbxassetid://81683171903925"
})
local CombatSettingsPage = Window:CreatePage({
Title = "Settings",
Icon = "rbxassetid://135452049601292"
})
Library:CreateGUISettingsSection({
Page = CombatSettingsPage,
SectionTitle = "Settings",
Icon = "rbxassetid://135452049601292",
FileName = SETTINGS_FILE,
ToggleKeySaveKey = "combat_ui_toggle_key",
HelpText = "Configure combat-related UI options directly from the library.",
})
local uiObjects = {}
local MovementSection = PlayerPage:CreateSection({ Title = "Movement" })
MovementSection:CreateSliderToggle({
Title = "Custom WalkSpeed",
DefaultToggle = false,
Min = 16, Max = 300, Default = 100,
SaveKey = "player_speed_control",
OnToggleChange = function(state)
isSpeedEnabled = state
if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
LocalPlayer.Character.Humanoid.WalkSpeed = defaultWalkSpeed
end
end,
OnSliderChange = function(value) currentSpeed = value end
})
MovementSection:CreateSliderToggle({
Title = "Custom JumpPower",
DefaultToggle = false,
Min = 50, Max = 500, Default = 150,
SaveKey = "player_jump_control",
OnToggleChange = function(state)
isJumpEnabled = state
if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
LocalPlayer.Character.Humanoid.JumpPower = defaultJumpPower
end
end,
OnSliderChange = function(value) currentJump = value end
})
MovementSection:CreateToggle({
Title = "Enable Noclip",
SaveKey = "player_noclip_enabled",
Callback = function(state) isNoclipEnabled = state end
})
local AutoFarmSection = FarmingPage:CreateSection({
Title = "Auto Farm",
Icon = "rbxassetid://105067681602444"
})
local fieldNames, fieldObjects = {}, {}
local flowerZones = Workspace:WaitForChild("FlowerZones")
for _, part in ipairs(flowerZones:GetChildren()) do
if part:IsA("BasePart") then
table.insert(fieldNames, part.Name)
fieldObjects[part.Name] = part
end
end
table.sort(fieldNames)
local fieldRoute = {}
local fieldRouteThread = nil
local fieldRouteEnabled = false
local fieldRouteSelectedField = fieldNames[1]
local fieldRouteStepDuration = 60
local fieldRouteDisplay
local function clearList(t)
for k in pairs(t) do
t[k] = nil
end
end
local function findFirstBasePart(instance)
if not instance then return nil end
if instance:IsA("BasePart") then
return instance
end
if instance:IsA("Model") and instance.PrimaryPart then
return instance.PrimaryPart
end
for _, desc in ipairs(instance:GetDescendants()) do
if desc:IsA("BasePart") then
return desc
end
end
return nil
end
local function teleportCharacterToCFrame(targetCFrame)
if typeof(targetCFrame) ~= "CFrame" then return end
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if not (character and root) then return end
if not character.PrimaryPart then
character.PrimaryPart = root
end
character:SetPrimaryPartCFrame(targetCFrame)
end
local function getCharacterMass(character)
local total = 0
if not character then
return total
end
for _, part in ipairs(character:GetDescendants()) do
if part:IsA("BasePart") then
total = total + part:GetMass()
end
end
return total
end
local npcNames, npcTargets = {}, {}
local preferredNPCOrder = {
"Ant Challenge Info", "Black Bear", "Brown Bear", "Bubble Bee Man 2",
"Bucko Bee", "Dapper Bear", "Gummy Bear", "Honey Bee", "Mother Bear",
"Onett", "Panda Bear", "Polar Bear", "Riley Bee", "Robo Bear",
"Science Bear", "Spirit Bear", "Stick Bug", "Wind Shrine"
}
local function refreshNPCList()
clearList(npcNames)
npcTargets = {}
local folders = {}
local npcFolder = Workspace:FindFirstChild("NPCs")
if npcFolder then
table.insert(folders, npcFolder)
end
local npcBeesFolder = Workspace:FindFirstChild("NPCBees")
if npcBeesFolder then
table.insert(folders, npcBeesFolder)
end

local registered = {}
local function registerNPC(name, instance)
    if registered[name] then return end
    registered[name] = true
    local part = findFirstBasePart(instance)
    if part then
        npcTargets[name] = part
    end
    table.insert(npcNames, name)
end
for _, name in ipairs(preferredNPCOrder) do
    for _, folder in ipairs(folders) do
        local npc = folder:FindFirstChild(name)
        if npc then
            registerNPC(name, npc)
            break
        end
    end
end
for _, folder in ipairs(folders) do
    for _, npc in ipairs(folder:GetChildren()) do
        if not registered[npc.Name] then
            registerNPC(npc.Name, npc)
        end
    end
end
if #npcNames == 0 then
    for _, name in ipairs(preferredNPCOrder) do
        table.insert(npcNames, name)
    end
end
end
refreshNPCList()
local npcFolderRoot = Workspace:FindFirstChild("NPCs")
if npcFolderRoot then
npcFolderRoot.ChildAdded:Connect(refreshNPCList)
npcFolderRoot.ChildRemoved:Connect(refreshNPCList)
end
local npcBeesFolderRoot = Workspace:FindFirstChild("NPCBees")
if npcBeesFolderRoot then
npcBeesFolderRoot.ChildAdded:Connect(refreshNPCList)
npcBeesFolderRoot.ChildRemoved:Connect(refreshNPCList)
end
local playerDropdownItems = {}
local function refreshPlayerDropdownItems()
clearList(playerDropdownItems)
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer then
table.insert(playerDropdownItems, plr.Name)
end
end
table.sort(playerDropdownItems)
end
refreshPlayerDropdownItems()
Players.PlayerAdded:Connect(refreshPlayerDropdownItems)
Players.PlayerRemoving:Connect(refreshPlayerDropdownItems)
local shopNames, shopTargets = {}, {}
local preferredShopOrder = {
"BadgeBearersGuild", "BasicShop", "BlueHQ", "CoconutShop", "DapperItemShop",
"DapperPlanterShop", "DiamondMaskShop", "EggDispenser", "GumdropDispenser",
"GummyBearShop", "JellyDispenser", "LavaShop", "MagicBeanDispenser",
"MasterRoomShop", "Mountaintop", "Petal Shop", "ProShop", "RedHQ",
"RoboBearChallenge", "Sticker-SeekerShop", "StingerShop", "TicketDispenser",
"TicketShop", "TreatShop"
}
local function refreshShopList()
clearList(shopNames)
shopTargets = {}
local shopsFolder = Workspace:FindFirstChild("Shops")
if not shopsFolder then
for _, name in ipairs(preferredShopOrder) do
table.insert(shopNames, name)
end
return
end

local registered = {}
local function registerShop(name, instance)
    if registered[name] then return end
    registered[name] = true
    local part = findFirstBasePart(instance)
    if part then
        shopTargets[name] = part
    end
    table.insert(shopNames, name)
end
for _, name in ipairs(preferredShopOrder) do
    local shop = shopsFolder:FindFirstChild(name)
    if shop then
        registerShop(name, shop)
    end
end
for _, shop in ipairs(shopsFolder:GetChildren()) do
    if not registered[shop.Name] then
        registerShop(shop.Name, shop)
    end
end
end
refreshShopList()
local shopsFolderRoot = Workspace:FindFirstChild("Shops")
if shopsFolderRoot then
shopsFolderRoot.ChildAdded:Connect(refreshShopList)
shopsFolderRoot.ChildRemoved:Connect(refreshShopList)
end
local betterGraphicsState = {
connection = nil,
original = nil,
customSky = nil,
createdEffects = {},
}
local betterGraphicsEnabled = false
local BETTER_GRAPHICS_SKY_ID = "rbxassetid://6000000000"
local function captureLightingState()
local function captureEffect(className, props)
local instance = Lighting:FindFirstChildOfClass(className)
if not instance then return nil end
local data = { instance = instance, properties = {} }
for _, prop in ipairs(props) do
data.properties[prop] = instance[prop]
end
return data
end

return {
    renderingQuality = settings().Rendering.QualityLevel,
    lightingProps = {
        Technology = Lighting.Technology,
        GlobalShadows = Lighting.GlobalShadows,
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    },
    effects = {
        Atmosphere = captureEffect("Atmosphere", { "Density", "Haze", "Color", "Offset" }),
        BloomEffect = captureEffect("BloomEffect", { "Enabled", "Intensity", "Size", "Threshold" }),
        ColorCorrectionEffect = captureEffect("ColorCorrectionEffect", { "Enabled", "TintColor", "Saturation", "Contrast" }),
        DepthOfFieldEffect = captureEffect("DepthOfFieldEffect", { "Enabled", "FarIntensity", "InFocusRadius" }),
    },
}
end
local function getOrCreateLightingEffect(className)
local effect = Lighting:FindFirstChildOfClass(className)
if not effect then
effect = Instance.new(className)
effect.Parent = Lighting
betterGraphicsState.createdEffects[className] = true
end
return effect
end
local function applyBetterGraphicsSettings()
if settings().Rendering.QualityLevel ~= Enum.QualityLevel.Level21 then
settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
end

Lighting.Technology = Enum.Technology.Future
Lighting.GlobalShadows = true
Lighting.ClockTime = 22
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(60, 50, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(80, 70, 100)
Lighting.EnvironmentDiffuseScale = 2.5
Lighting.EnvironmentSpecularScale = 3.0
if not betterGraphicsState.customSky or betterGraphicsState.customSky.Parent ~= Lighting then
    if betterGraphicsState.customSky then
        betterGraphicsState.customSky:Destroy()
    end
    for _, sky in ipairs(Lighting:GetChildren()) do
        if sky:IsA("Sky") then
            sky:Destroy()
        end
    end
    local clientSky = Instance.new("Sky")
    clientSky.Name = "ClientDeepSpaceSky"
    clientSky.SkyboxBk = BETTER_GRAPHICS_SKY_ID
    clientSky.SkyboxDn = BETTER_GRAPHICS_SKY_ID
    clientSky.SkyboxFt = BETTER_GRAPHICS_SKY_ID
    clientSky.SkyboxLf = BETTER_GRAPHICS_SKY_ID
    clientSky.SkyboxRt = BETTER_GRAPHICS_SKY_ID
    clientSky.SkyboxUp = BETTER_GRAPHICS_SKY_ID
    clientSky.Parent = Lighting
    betterGraphicsState.customSky = clientSky
end
local atmosphere = getOrCreateLightingEffect("Atmosphere")
atmosphere.Density = 0.25
atmosphere.Haze = 1.2
atmosphere.Color = Color3.fromRGB(110, 120, 135)
atmosphere.Offset = 0.05
local bloom = getOrCreateLightingEffect("BloomEffect")
bloom.Enabled = true
bloom.Intensity = 0.2
bloom.Size = 24
bloom.Threshold = 1.9
local colorCorrection = getOrCreateLightingEffect("ColorCorrectionEffect")
colorCorrection.Enabled = true
colorCorrection.TintColor = Color3.fromRGB(230, 240, 255)
colorCorrection.Saturation = 0.2
colorCorrection.Contrast = 0.25
local depthOfField = getOrCreateLightingEffect("DepthOfFieldEffect")
depthOfField.Enabled = true
depthOfField.FarIntensity = 0.35
depthOfField.InFocusRadius = 120
end
local function enableBetterGraphics()
if betterGraphicsState.original then return end
betterGraphicsState.original = captureLightingState()
applyBetterGraphicsSettings()
if betterGraphicsState.connection then
betterGraphicsState.connection:Disconnect()
end
betterGraphicsState.connection = RunService.Heartbeat:Connect(applyBetterGraphicsSettings)
end
local function disableBetterGraphics()
if betterGraphicsState.connection then
betterGraphicsState.connection:Disconnect()
betterGraphicsState.connection = nil
end
if betterGraphicsState.customSky then
betterGraphicsState.customSky:Destroy()
betterGraphicsState.customSky = nil
end
if betterGraphicsState.original then
for prop, value in pairs(betterGraphicsState.original.lightingProps) do
Lighting[prop] = value
end
settings().Rendering.QualityLevel = betterGraphicsState.original.renderingQuality
for effectClass, data in pairs(betterGraphicsState.original.effects) do
local instance = data and data.instance
if instance and instance.Parent ~= Lighting then
instance.Parent = Lighting
end
if instance and data.properties then
for prop, value in pairs(data.properties) do
instance[prop] = value
end
end
end
end
for effectClass, created in pairs(betterGraphicsState.createdEffects) do
if created then
local inst = Lighting:FindFirstChildOfClass(effectClass)
if inst then
inst:Destroy()
end
end
end
betterGraphicsState.createdEffects = {}
betterGraphicsState.original = nil
end
local function setBetterGraphics(state)
betterGraphicsEnabled = state and true or false
if betterGraphicsEnabled then
enableBetterGraphics()
else
disableBetterGraphics()
end
end
uiObjects.farmFieldDropdown = AutoFarmSection:CreateDropdown({
Title = "Select Field",
Items = fieldNames,
SaveKey = "farm_field_selection",
Searchable = true,
Callback = function(name)
selectedField = fieldObjects[name]
selectedFieldName = name
currentFieldHeat = getFieldHeatTable(name)
wanderTarget = nil
wanderExpireTime = 0
wanderLastBase = nil
activeToken = nil
activeTokenIsLink = false
activeTokenScore = 0
resetTable(visitedTokens)
resetTable(tokenMetadata)
refreshFieldBounds()
resetMoveCommand()
if isAutoFarmEnabled and selectedField and LocalPlayer.Character then
LocalPlayer.Character:SetPrimaryPartCFrame(selectedField.CFrame + Vector3.new(0, 5, 0))
end
fieldRouteSelectedField = name
end
})
AutoFarmSection:CreateToggle({
Title = "Enable Auto Farm",
Default = false,
SaveKey = "farm_enabled",
Callback = function(state)
isAutoFarmEnabled = state
wanderTarget = nil
wanderExpireTime = 0
if state and selectedFieldName and not currentFieldHeat then
currentFieldHeat = getFieldHeatTable(selectedFieldName)
end
if state and selectedField and LocalPlayer.Character then
LocalPlayer.Character:SetPrimaryPartCFrame(selectedField.CFrame + Vector3.new(0, 5, 0))
resetMoveCommand()
elseif not state then
wanderTarget, activeToken, isDispensing = nil, nil, false
activeTokenIsLink = false
activeTokenScore = 0
wanderExpireTime = 0
wanderLastBase = nil
resetTable(visitedTokens)
resetTable(tokenMetadata)
resetMoveCommand()
end
fieldBoundsEnabled = state and true or false
refreshFieldBounds()

    if state then
        local coreStats = LocalPlayer:FindFirstChild("CoreStats")
        local pollen = coreStats and coreStats:FindFirstChild("Pollen")
        local honey = coreStats and coreStats:FindFirstChild("Honey")
        farmSessionStart = tick()
        farmStartPollen = pollen and pollen.Value or 0
        farmStartHoney = honey and honey.Value or 0
    else
        farmSessionStart = 0
    end
    refreshAutoDig()
end
})
AutoFarmSection:CreateToggle({
Title = "Auto Dispense Honey",
Default = true,
SaveKey = "farm_auto_dispense",
Callback = function(state)
isAutoDispenseEnabled = state and true or false
end
})
AutoFarmSection:CreateToggle({
    Title = "Stats Panel",
    Default = false,
    SaveKey = "farm_stats_panel",
    Callback = function(state)
        isStatsPanelEnabled = state
        if state then
            createStatsPanel()
        else
            destroyStatsPanel()
        end
    end
})
AutoFarmSection:CreateToggle({
    Title = "Buff-Aware Farming",
    Default = false,
    SaveKey = "farm_buff_aware_enabled",
    HelpText = "EXPERIMENTAL: Prioritizes tokens for buffs you don't have. May slightly reduce overall token speed for better buff uptime.",
    Callback = function(state)
        isBuffAwareEnabled = state
    end
})local function rebuildFieldRouteLabel()
if not fieldRouteDisplay then return end
if #fieldRoute == 0 then
fieldRouteDisplay.SetText("No steps queued")
return
end
local parts = {}
for i, step in ipairs(fieldRoute) do
table.insert(parts, string.format("%d) %s (%ds)", i, step.Field, step.Duration))
end
fieldRouteDisplay.SetText(table.concat(parts, " | "))
end
local function stopFieldRoute()
fieldRouteEnabled = false
if fieldRouteThread then
if hasTaskCancel then
pcall(function()
task.cancel(fieldRouteThread)
end)
end
fieldRouteThread = nil
end
end
local function startFieldRoute()
if fieldRouteThread or #fieldRoute == 0 then
if #fieldRoute == 0 then
notify("Field Route", "Add at least one step before enabling.", 4)
end
if uiObjects.fieldRouteToggle and uiObjects.fieldRouteToggle.SetState then
pcall(function()
uiObjects.fieldRouteToggle:SetState(false)
end)
end
return
end

fieldRouteEnabled = true
fieldRouteThread = task.spawn(function()
    local index = 1
    while fieldRouteEnabled and #fieldRoute > 0 do
        local step = fieldRoute[index]
        if not step then
            index = 1
            step = fieldRoute[index]
        end
        farmSelectedField = step.Field
        if uiObjects.farmFieldDropdown and uiObjects.farmFieldDropdown.SetSelection then
            pcall(function()
                uiObjects.farmFieldDropdown:SetSelection(step.Field)
            end)
        end
        local fieldPart = fieldObjects[step.Field]
        if fieldPart and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            pcall(function()
                LocalPlayer.Character:SetPrimaryPartCFrame(fieldPart.CFrame + Vector3.new(0, 5, 0))
            end)
        end
        local elapsed = 0
        local duration = math.max(5, math.floor(step.Duration or fieldRouteStepDuration))
        while fieldRouteEnabled and elapsed < duration do
            task.wait(1)
            elapsed = elapsed + 1
        end
        index = index + 1
        if index > #fieldRoute then
            index = 1
        end
    end
    fieldRouteThread = nil
    fieldRouteEnabled = false
    if uiObjects.fieldRouteToggle and uiObjects.fieldRouteToggle.SetState then
        pcall(function()
            uiObjects.fieldRouteToggle:SetState(false)
        end)
    end
end)
end
local function removeLastRouteStep()
if #fieldRoute > 0 then
fieldRoute[#fieldRoute] = nil
rebuildFieldRouteLabel()
end
end
local function clearFieldRoute()
for i = #fieldRoute, 1, -1 do
fieldRoute[i] = nil
end
rebuildFieldRouteLabel()
end
local FieldRouteSection = FarmingPage:CreateSection({
Title = "Field Route Manager",
Icon = "rbxassetid://110882457725395",
HelpText = "Queue fields and automatically cycle between them."
})
uiObjects.fieldRouteDropdown = FieldRouteSection:CreateDropdown({
Title = "Field Step",
Items = fieldNames,
Default = 1,
Searchable = true,
Callback = function(name)
fieldRouteSelectedField = name
end
})
uiObjects.fieldRouteDuration = FieldRouteSection:CreateSlider({
Title = "Step Duration (seconds)",
Min = 10,
Max = 600,
Default = fieldRouteStepDuration,
Decimals = 0,
Callback = function(value)
local numberValue = tonumber(value)
if numberValue then
fieldRouteStepDuration = math.max(10, math.floor(numberValue))
end
end
})
FieldRouteSection:CreateButton({
Title = "Add Step",
Callback = function()
local fieldName = fieldRouteSelectedField or fieldNames[1]
if not fieldName then
notify("Field Route", "No field selected.", 3)
return
end
table.insert(fieldRoute, {
Field = fieldName,
Duration = math.max(5, math.floor(fieldRouteStepDuration)),
})
rebuildFieldRouteLabel()
end
})
FieldRouteSection:CreateButton({
Title = "Remove Last Step",
Callback = function()
removeLastRouteStep()
end
})
FieldRouteSection:CreateButton({
Title = "Clear Route",
Callback = function()
clearFieldRoute()
end
})
fieldRouteDisplay = FieldRouteSection:CreateInputBox({
Title = "Route Preview",
Placeholder = "No steps queued"
})
fieldRouteDisplay.Object.TextEditable = false
fieldRouteDisplay.Object.ClearTextOnFocus = false
fieldRouteDisplay.SetText("No steps queued")
uiObjects.fieldRouteToggle = FieldRouteSection:CreateToggle({
Title = "Enable Route Loop",
Default = false,
Callback = function(state)
if state then
if #fieldRoute == 0 then
notify("Field Route", "Add at least one step before enabling.", 4)
uiObjects.fieldRouteToggle:SetState(false)
return
end
startFieldRoute()
else
stopFieldRoute()
end
end
})
local function getNpcTarget(name)
local target = npcTargets[name]
if target and target.Parent then
return target
end
local folders = { Workspace:FindFirstChild("NPCs"), Workspace:FindFirstChild("NPCBees") }
for _, folder in ipairs(folders) do
local npc = folder and folder:FindFirstChild(name)
if npc then
local part = findFirstBasePart(npc)
if part then
npcTargets[name] = part
return part
end
end
end
return nil
end
local function getShopTarget(name)
local target = shopTargets[name]
if target and target.Parent then
return target
end
local shopsFolder = Workspace:FindFirstChild("Shops")
if not shopsFolder then
return nil
end
local shop = shopsFolder:FindFirstChild(name)
if not shop then
return nil
end
local part = findFirstBasePart(shop)
if part then
shopTargets[name] = part
end
return part
end
local TeleportSection = TeleportPage:CreateSection({
Title = "Teleports",
Icon = "rbxassetid://6634488405"
})
TeleportSection:CreateDropdown({
Title = "Teleport To Field",
Items = fieldNames,
Searchable = true,
SaveKey = "teleport_field_choice",
Callback = function(name)
local field = fieldObjects[name]
if field then
teleportCharacterToCFrame(field.CFrame + Vector3.new(0, 5, 0))
end
end
})
TeleportSection:CreateDropdown({
Title = "Teleport To NPC",
Items = npcNames,
Searchable = true,
SaveKey = "teleport_npc_choice",
Callback = function(name)
local target = getNpcTarget(name)
if target then
teleportCharacterToCFrame(CFrame.new(target.Position + Vector3.new(0, 5, 0)))
end
end
})
TeleportSection:CreateDropdown({
Title = "Teleport To Player",
Items = playerDropdownItems,
Searchable = true,
SaveKey = "teleport_player_choice",
Callback = function(name)
local targetPlayer = Players:FindFirstChild(name)
local character = targetPlayer and targetPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if root then
teleportCharacterToCFrame(root.CFrame + Vector3.new(0, 5, 0))
end
end
})
TeleportSection:CreateDropdown({
Title = "Teleport To Shop",
Items = shopNames,
Searchable = true,
SaveKey = "teleport_shop_choice",
Callback = function(name)
local target = getShopTarget(name)
if target then
teleportCharacterToCFrame(target.CFrame + Vector3.new(0, 5, 0))
end
end
})
-- Extra Automation (buff items + actives) ------------------------
local function safeFire(event, ...)
if not event then return end
local args = { ... }
pcall(function()
if #args == 0 then
event:FireServer()
else
event:FireServer(table.unpack(args))
end
end)
end
local function getPlayerActivesCommand()
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
or ReplicatedStorage:WaitForChild("Events", 1)
return eventsFolder and eventsFolder:FindFirstChild("PlayerActivesCommand")
end
local function firePlayerActives(name)
local ev = getPlayerActivesCommand()
if not ev then return end
safeFire(ev, { Name = tostring(name) })
end
local function startAutoLoop(stateRef, threadRef, interval, callback)
if threadRef[1] then return end
threadRef[1] = task.spawn(function()
while stateRef[1] do
callback()
task.wait(interval)
end
threadRef[1] = nil
end)
end
local function stopAutoLoop(stateRef, threadRef)
stateRef[1] = false
if threadRef[1] then
if hasTaskCancel then
pcall(function()
task.cancel(threadRef[1])
end)
end
threadRef[1] = nil
end
end
-- Auto Dig: repeatedly fires Events/ToolCollect
local autoDigEnabled = false
local autoDigThread
local autoDigManualEnabled = false
local function startAutoDig()
if autoDigThread then
return
end
autoDigEnabled = true
autoDigThread = task.spawn(function()
local args = {}
while autoDigEnabled do
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
or ReplicatedStorage:WaitForChild("Events", 1)
local toolCollectRemote = eventsFolder and eventsFolder:FindFirstChild("ToolCollect")
if toolCollectRemote then
pcall(function()
toolCollectRemote:FireServer(table.unpack(args))
end)
end
task.wait(0.1)
end
autoDigThread = nil
end)
end
local function stopAutoDig()
autoDigEnabled = false
if autoDigThread then
if hasTaskCancel then
pcall(function()
task.cancel(autoDigThread)
end)
end
autoDigThread = nil
end
end
refreshAutoDig = function()
local shouldRun = isAutoFarmEnabled or autoDigManualEnabled
if shouldRun and not autoDigEnabled then
startAutoDig()
elseif not shouldRun and autoDigEnabled then
stopAutoDig()
end
end
local ExtraSection = HelperPage:CreateSection({
Title = "Extra Automation",
Icon = "rbxassetid://132944044601566",
HelpText = "Miscellaneous automation like item buffs and gumdrops."
})
local autoBuffItemsState = { false }
local autoBuffItemsThread = { nil }
local function releaseBuffs()
local buffs = {
"Blue Extract",
"Red Extract",
"Oil",
"Enzymes",
"Glue",
"Glitter",
"Tropical Drink",
}
for _, name in ipairs(buffs) do
firePlayerActives(name)
task.wait(0.1)
end
end
ExtraSection:CreateToggle({
Title = "Auto Item Buffs",
Default = false,
SaveKey = "helper_auto_item_buffs",
Callback = function(enabled)
autoBuffItemsState[1] = enabled and true or false
if autoBuffItemsState[1] then
startAutoLoop(autoBuffItemsState, autoBuffItemsThread, 600, releaseBuffs)
else
stopAutoLoop(autoBuffItemsState, autoBuffItemsThread)
end
end
})
uiObjects.autoDig = ExtraSection:CreateToggle({
Title = "Auto Dig (Helper Control)",
Default = false,
SaveKey = "auto_dig_enabled",
HelpText = "Toggle allows manual digging when Auto Farm is off.",
Callback = function(enabled)
autoDigManualEnabled = enabled and true or false
refreshAutoDig()
end
})
local function createActiveToggle(title, saveKey, interval, activeName)
local state = { false }
local threadRef = { nil }
ExtraSection:CreateToggle({
Title = title,
Default = false,
SaveKey = saveKey,
Callback = function(enabled)
state[1] = enabled and true or false
if state[1] then
startAutoLoop(state, threadRef, interval, function()
firePlayerActives(activeName)
end)
else
stopAutoLoop(state, threadRef)
end
end
})
end
createActiveToggle("Auto Gumdrops", "helper_auto_gumdrops", 2, "Gumdrops")
createActiveToggle("Auto Glitter", "helper_auto_glitter", 920, "Glitter")
createActiveToggle("Auto Coconut", "helper_auto_coconut", 11, "Coconut")
createActiveToggle("Auto Stinger", "helper_auto_stinger", 30, "Stinger")
createActiveToggle("Auto Magic Bean", "helper_auto_magic_bean", 0.3, "Magic Bean")
local autoSprinklerEnabled = false
uiObjects.autoSprinkler = ExtraSection:CreateToggle({
Title = "Auto Sprinkler",
Default = false,
SaveKey = "auto_sprinkler_enabled",
Callback = function(enabled)
autoSprinklerEnabled = enabled and true or false
end,
})
local espSection = HelperPage:CreateSection({
Title = "Player ESP",
Icon = "rbxassetid://132944044601566",
HelpText = "Visual assistance features.",
})
uiObjects.boxEspToggle = espSection:CreateToggle({
Title = "Box ESP",
Default = false,
SaveKey = "box_esp_enabled",
Callback = function(v)
boxEspEnabled = v
end,
})
uiObjects.healthEspToggle = espSection:CreateToggle({
Title = "Health ESP",
Default = false,
SaveKey = "health_esp_enabled",
Callback = function(value)
healthEspEnabled = value
end,
})
uiObjects.tracersToggle = espSection:CreateToggle({
Title = "Tracers",
Default = false,
SaveKey = "tracers_enabled",
Callback = function(value)
tracersEnabled = value
end,
})
uiObjects.teamCheckToggle = espSection:CreateToggle({
Title = "Team Check",
Default = false,
SaveKey = "team_check_enabled",
Callback = function(value)
teamCheckEnabled = value
end,
})
uiObjects.teamColorToggle = espSection:CreateToggle({
Title = "Team Color",
Default = true,
SaveKey = "team_color_enabled",
Callback = function(value)
teamColorEnabled = value
end,
})
uiObjects.skeletonEspToggle = espSection:CreateToggle({
Title = "Skeleton ESP",
Default = false,
SaveKey = "skeleton_esp_enabled",
Callback = function(value)
skeletonEspEnabled = value
end,
})
uiObjects.nameEspToggle = espSection:CreateToggle({
Title = "Name ESP",
Default = false,
SaveKey = "name_esp_enabled",
Callback = function(value)
nameEspEnabled = value
end,
})
uiObjects.hotbarEspToggle = espSection:CreateToggle({
Title = "Hotbar ESP",
Default = false,
SaveKey = "hotbar_esp_enabled",
Callback = function(value)
hotbarEspEnabled = value
if value then
if not next(hotbarDisplaySet) then
hotbarDisplaySet = { Text = true }

            local ctrl = uiObjects.hotbarDisplay
            if ctrl and ctrl.SetState then
                pcall(function()
                    if ctrl.SetSelected then
                        ctrl:SetSelected("Text", true)
                    end
                    if ctrl.Select then
                        ctrl:Select("Text", true)
                    end
                    if ctrl.SetValues then
                        ctrl:SetValues({ "Text" })
                    end
                    if ctrl.Set then
                        ctrl:Set({ "Text" })
                    end
                end)
            end
        end
    end
end,
})
uiObjects.hotbarDisplay = espSection:CreateMultiSelectDropdown({
Title = "Hotbar Display",
Items = { "Image", "Text" },
SaveKey = "hotbar_display_types",
Callback = function(list)
local set = {}
if type(list) == "table" then
for _, name in ipairs(list) do
set[tostring(name)] = true
end
end

    hotbarDisplaySet = set
end,
})
local gameEspSection = HelperPage:CreateSection({
Title = "Game ESP",
Icon = "rbxassetid://132944044601566",
HelpText = "World and game ESP.",
})
uiObjects.sproutEspToggle = gameEspSection:CreateToggle({
Title = "Sprout ESP",
Default = false,
SaveKey = "sprout_esp_enabled",
Callback = function(v)
sproutEspEnabled = v and true or false
end,
})
local EnvironmentSection = MiscPage:CreateSection({
Title = "Environment",
Icon = "rbxassetid://4483345998",
HelpText = "Visual tweaks that only affect the local client."
})
EnvironmentSection:CreateToggle({
Title = "Better Graphics",
Default = false,
SaveKey = "misc_better_graphics",
Callback = function(state)
setBetterGraphics(state)
end
})
local UtilitySection = MiscPage:CreateSection({
Title = "Utility",
Icon = "rbxassetid://133154037851337",
HelpText = "Quality-of-life helpers that keep the session active."
})
UtilitySection:CreateToggle({
Title = "Anti AFK",
Default = false,
SaveKey = "misc_anti_afk",
Callback = function(state)
setAntiAfk(state)
end
})
uiObjects.autoClaimHiveToggle = UtilitySection:CreateToggle({
Title = "Auto Claim Hive",
Default = false,
SaveKey = "misc_auto_claim_hive",
Callback = function(state)
isAutoClaimHiveEnabled = state
if state then
doAutoClaimHive()
end
end
})

local buffLogicState = {}
RunService.Stepped:Connect(function()
local char = LocalPlayer.Character
if not char or not char:FindFirstChild("Humanoid") then return end
local humanoid = char.Humanoid
local rootPart = char.HumanoidRootPart

local now = tick()
local currentTargetPosition = nil
local candidates = candidateBuffer
if isSpeedEnabled and not isDispensing then humanoid.WalkSpeed = currentSpeed end
if isJumpEnabled and not isDispensing then humanoid.JumpPower = currentJump end
if isNoclipEnabled then
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
    end
end
if not isAutoFarmEnabled or isDispensing then
    for i = 1, #pathParts do
        pathParts[i].Transparency = 1
    end
    return
end
-- Simplified stuck logic: if wandering and not moving, find a new spot.
if not activeToken and wanderTarget and now - lastMoveCommandTime > 4 then
    wanderTarget = chooseWanderSpot(rootPart.Position, now)
    if wanderTarget then
        wanderExpireTime = now + 2.75
        requestMoveTo(wanderTarget, true) -- Force move
    end
end
local coreStats = LocalPlayer:FindFirstChild("CoreStats")
local pollen = coreStats and coreStats:FindFirstChild("Pollen")
local capacity = coreStats and coreStats:FindFirstChild("Capacity")
local honey = coreStats and coreStats:FindFirstChild("Honey")
if coreStats and farmSessionStart > 0 then
    if now - statsLastUpdate > 0.5 then
        statsLastUpdate = now
        local currentPollen = pollen and pollen.Value or 0
        local currentHoney = honey and honey.Value or 0
        local elapsed = math.max(now - farmSessionStart, 1)
        local pollenGained = currentPollen - farmStartPollen
        local honeyGained = currentHoney - farmStartHoney
        local pollenPerMin = (pollenGained / elapsed) * 60
        local honeyPerHour = (honeyGained / elapsed) * 3600
        local capValue = capacity and capacity.Value or 0
        local percent = (capValue > 0) and (currentPollen / capValue * 100) or 0
        local minutes = math.floor(elapsed / 60)
        local seconds = math.floor(elapsed % 60)
        if isStatsPanelEnabled and statsLabel then
            local statsText = string.format(
                "Session: %02d:%02d\nPollen: %s / %s (%.1f%%%%)\nPollen Gain: %s (%s/min)\nHoney Gain: %s (%s/hr)",
                minutes, seconds,
                formatShort(currentPollen), formatShort(capValue), percent,
                formatShort(pollenGained), formatShort(pollenPerMin),
                formatShort(honeyGained), formatShort(honeyPerHour)
            )
            statsLabel.Text = statsText
        end
    end
end
if isAutoDispenseEnabled and pollen and capacity and pollen.Value >= capacity.Value then
    task.spawn(dispenseHoney)
    return
end
if not selectedField then return end
humanoid.WalkSpeed = 90
if not isInField(rootPart.Position) then
    if not char.PrimaryPart then
        char.PrimaryPart = rootPart
    end
    char:SetPrimaryPartCFrame(selectedField.CFrame + Vector3.new(0, 5, 0))
end
local collectibles = Workspace:FindFirstChild("Collectibles")
if not collectibles then return end
decayFieldHeat(now)
cleanupTokenCaches(now)
local function requestMoveTo(targetPos, force)
    if not targetPos then
        return
    end
    local delta = lastMoveCommandPos and (targetPos - lastMoveCommandPos).Magnitude or math.huge
    local shouldMove = force or not lastMoveCommandPos or delta > MOVE_COMMAND_EPS
    if not shouldMove then
        local elapsed = now - lastMoveCommandTime
        if elapsed > MOVE_COMMAND_RETRY then
            shouldMove = true
        end
    end
    if shouldMove then
        humanoid:MoveTo(targetPos)
        lastMoveCommandPos = targetPos
        lastMoveCommandTime = now
    end
end
local function releaseActiveToken()
    if activeToken then
        local info = tokenMetadata[activeToken]
        if info and info.LastPos then
            addHeatSample(info.LastPos, 0.5)
        end
        if activeTokenIsLink then
            resetTable(visitedTokens)
            resetTable(tokenMetadata)
        else
            visitedTokens[activeToken] = now + TOKEN_RECENT_DELAY
        end
        activeToken = nil
        activeTokenIsLink = false
        activeTokenScore = 0
    end
    wanderTarget = nil
    wanderExpireTime = 0
    wanderLastBase = nil
    currentTargetPosition = nil
    resetMoveCommand()
end
local function lockActiveCandidate(candidate, forceIsLink)
    if not candidate or not candidate.Part then
        return
    end
    activeToken = candidate.Part
    activeTokenIsLink = forceIsLink and true
        or (candidate.TokenName and string.find(candidate.TokenName, "Token Link") ~= nil)
    wanderTarget = nil
    wanderExpireTime = 0
    local targetPos = candidate.Pos
    currentTargetPosition = targetPos
    requestMoveTo(targetPos, true)
    local info = getTokenInfo(activeToken)
    if info then
        info.TargetedAt = now
        info.LastScore = candidate.Score or candidate.BaseWeight or 0
        info.TokenName = candidate.TokenName
        activeTokenScore = info.LastScore or 0
    else
        activeTokenScore = candidate.Score or candidate.BaseWeight or 0
    end
end
if activeToken then
    local tokenPos
    if activeToken.Parent then
        tokenPos = activeToken:GetPivot().Position
        updateTokenTracking(activeToken, tokenPos, now)
    end
    local info = tokenMetadata[activeToken]
    if not tokenPos or activeToken.Transparency >= 0.9 then
        releaseActiveToken()
    elseif not isInField(tokenPos) then
        releaseActiveToken()
    else
        local predicted = predictTokenPosition(info, rootPart.Position, humanoid.WalkSpeed)
        local targetPos = predicted or tokenPos
        local tokenDist = (rootPart.Position - targetPos).Magnitude
        local rawDist = info and info.LastPos and (rootPart.Position - info.LastPos).Magnitude or tokenDist
        local targetedAt = info and info.TargetedAt or now
        local chaseTime = now - targetedAt
        local closeEnough = tokenDist <= TOKEN_PASS_RADIUS
            or rawDist <= (TOKEN_PASS_RADIUS + 1.5)
            or (chaseTime > 0.35 and tokenDist <= TOKEN_PASS_RADIUS * 1.75)
            or chaseTime > 0.9
        if closeEnough then
            releaseActiveToken()
        else
            requestMoveTo(targetPos)
            currentTargetPosition = targetPos
        end
    end
end
resetTable(candidates)
for _, part in ipairs(collectibles:GetChildren()) do
    local recentlyVisited = visitedTokens[part] and visitedTokens[part] > now
    if not recentlyVisited and part.Name == "C" and part.Transparency < 0.9 and part ~= activeToken then
        local pos = part:GetPivot().Position
        if isInField(pos) and (pos.Y - rootPart.Position.Y) < 3 then
            local dist = (rootPart.Position - pos).Magnitude
            if dist < MAX_TOKEN_TRACK_DISTANCE then
                local info = updateTokenTracking(part, pos, now)
                if info then
                    local decal = part:FindFirstChildOfClass("Decal")
                    local id = decal and getCleanID(decal.Texture)
                    local name = id and (FARM_DATABASE[tostring(id)] or FARM_DATABASE[tostring(id - 1)] or FARM_DATABASE[tostring(id + 1)]) or "Unknown"
                    local predicted = predictTokenPosition(info, rootPart.Position, humanoid.WalkSpeed)
                    if predicted then
                        addHeatSample(predicted, 0.05)
                    end
                    local targetPos = predicted or pos
                    local travelDist = (rootPart.Position - targetPos).Magnitude
                    local weight = getTokenPriorityScore(name)
                    if isBuffAwareEnabled then
                        -- Safely initialize state on first run
                        if not buffLogicState.initialized then
                            buffLogicState.initialized = true
                            buffLogicState.activeBuffs = {}
                            buffLogicState.lastScan = 0
                            buffLogicState.scanInterval = 4 -- Scan slightly more often
                            buffLogicState.modulesLoaded = false
                        end
                        
                        local now_tick = tick()
                        
                        -- Attempt to load modules if not already loaded
                        if not buffLogicState.modulesLoaded and (now_tick - buffLogicState.lastScan > buffLogicState.scanInterval) then
                            local ReplicatedStorage = game:GetService("ReplicatedStorage")
                            if ReplicatedStorage then
                                local ok_os, res_os = pcall(require, ReplicatedStorage:WaitForChild("OsTime", 0.5))
                                local ok_buffs, res_buffs = pcall(require, ReplicatedStorage:WaitForChild("Buffs", 0.5))
                                local ok_events, res_events = pcall(require, ReplicatedStorage:WaitForChild("Events", 0.5))
                                if ok_os and ok_buffs and ok_events and res_os and res_buffs and res_events then
                                    buffLogicState.OsTime = res_os
                                    buffLogicState.BuffsModule = res_buffs
                                    buffLogicState.Events = res_events
                                    buffLogicState.modulesLoaded = true
                                else
                                    buffLogicState.lastScan = now_tick + 30
                                end
                            end
                        end
                        
                        -- Periodically scan for buffs
                        if buffLogicState.modulesLoaded and (now_tick - buffLogicState.lastScan > buffLogicState.scanInterval) then
                            buffLogicState.lastScan = now_tick
                            task.spawn(function()
                                local s, r = pcall(buffLogicState.Events.ClientCall, "RetrievePlayerStats")
                                if s and r then
                                    local now_os = buffLogicState.OsTime()
                                    local newBuffs = {} -- Scan into a temp table to prevent race conditions
                                    if r.Modifiers then
                                        for _, v in pairs(r.Modifiers) do for _, d in pairs(v) do if d.Mods then for _, m in ipairs(d.Mods) do if m.Src then
                                            local def = buffLogicState.BuffsModule.Get(m.Src)
                                            if def then
                                                local dur = m.Dur or def.Dur
                                                if dur then
                                                    local st, tl = m.Start, dur
                                                    if st and now_os then tl = dur - (now_os - st) end
                                                    if tl > 0 then newBuffs[m.Src] = tl end -- Store time left
                                                end
                                            end
                                        end end end end end
                                    end
                                    -- Atomically update the buffs table for the main thread
                                    buffLogicState.activeBuffs = newBuffs
                                end
                            end)
                        end

                        -- Apply smarter dynamic weight if modules are loaded
                        if buffLogicState.modulesLoaded then
                            local timeLeft = buffLogicState.activeBuffs[name]

                            if name == "Token Link" then
                                weight = weight * 15 -- Overwhelming priority
                            elseif timeLeft then
                                -- Buff is active, check if it's expiring
                                if timeLeft < 7 then
                                    -- High priority to refresh
                                    weight = weight * 3.0
                                else
                                    -- Buff is healthy, low priority
                                    weight = weight * 0.25
                                end
                            else
                                -- Buff is not active, medium priority to acquire
                                weight = weight * 1.5
                            end
                        end
                    end
                    local score = computeCandidateScore(weight, travelDist, info.SpawnTime or now, now, part.Transparency)
                    addHeatSample(pos, 0.1)
                    table.insert(candidates, {
                        Part = part,
                        Pos = targetPos,
                        RawPos = pos,
                        Dist = travelDist,
                        SpawnTime = info.SpawnTime or now,
                        IsPriority = FARM_PRIORITY_ITEMS[name] == true,
                        TokenName = name,
                        BaseWeight = weight,
                        Score = score,
                    })
                end
            end
        end
    end
end
-- Boost scores based on token density to favor clusters
for i, c1 in ipairs(candidates) do
    local clusterBonus = 0
    for j, c2 in ipairs(candidates) do
        if i ~= j then
            local dist = (c1.RawPos - c2.RawPos).Magnitude
            local radius = 45 -- Studs
            if dist < radius then
                -- Bonus is proportional to neighbor's base value and proximity
                local proximityFactor = (1 - (dist / radius))^2 -- squared for stronger falloff
                clusterBonus = clusterBonus + (c2.BaseWeight or 0) * proximityFactor * 0.45 -- 45% cluster effect
            end
        end
    end
    c1.Score = (c1.Score or 0) + clusterBonus
end

table.sort(candidates, function(a, b)
    -- Primarily sort by score
    if math.abs((a.Score or 0) - (b.Score or 0)) > 0.1 then
        return (a.Score or 0) > (b.Score or 0)
    end
    -- As a final tie-breaker, take the closer one
    return a.Dist < b.Dist
end)
local topCandidate = candidates[1]
if activeToken and not activeTokenIsLink and topCandidate and activeToken ~= topCandidate.Part then
    local info = tokenMetadata[activeToken]
    local currentScore = (info and info.LastScore) or activeTokenScore or 0
    local bestScore = topCandidate.Score or topCandidate.BaseWeight or 0
    if bestScore - currentScore >= SCORE_RELOCK_THRESHOLD then
        releaseActiveToken()
        lockActiveCandidate(topCandidate)
    end
end
if not activeToken then
    if topCandidate then
        lockActiveCandidate(topCandidate)
    else
        if (not wanderTarget) or (rootPart.Position - wanderTarget).Magnitude < 10 or now > wanderExpireTime then
            wanderTarget = chooseWanderSpot(rootPart.Position, now)
            if wanderTarget then
                wanderExpireTime = now + 2.75
            end
        end
        if not wanderTarget then
            wanderTarget = rootPart.Position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
            wanderExpireTime = now + 1.5
        end
        requestMoveTo(wanderTarget)
        currentTargetPosition = wanderTarget
    end
elseif not currentTargetPosition then
    local info = tokenMetadata[activeToken]
    if info and info.LastPos then
        currentTargetPosition = predictTokenPosition(info, rootPart.Position, humanoid.WalkSpeed) or info.LastPos
    end
end
local pathPoints = {}
table.insert(pathPoints, rootPart.Position)
if currentTargetPosition then
    table.insert(pathPoints, currentTargetPosition)
end
local lastPoint = pathPoints[#pathPoints]
if #candidates > 0 and lastPoint then
    local maxExtra = MAX_PATH_SEGMENTS - 1
    for i = 1, math.min(#candidates, maxExtra) do
        local pos = candidates[i].Pos
        if (pos - lastPoint).Magnitude > 1 then
            table.insert(pathPoints, pos)
            lastPoint = pos
        end
    end
end
local segmentCount = #pathPoints - 1
for i = 1, #pathParts do
    local part = pathParts[i]
    if i <= segmentCount then
        local startPos = pathPoints[i]
        local endPos = pathPoints[i + 1]
        local direction = endPos - startPos
        local distance = direction.Magnitude
        if distance > 1 then
            part.Transparency = 0.25
            part.Size = Vector3.new(0.15, 0.15, distance)
            part.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
        else
            part.Transparency = 1
        end
    else
        part.Transparency = 1
    end
end
end)
local function onCharacterAdded(character)
local humanoid = character:WaitForChild("Humanoid")
defaultWalkSpeed, defaultJumpPower = humanoid.WalkSpeed, humanoid.JumpPower
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
