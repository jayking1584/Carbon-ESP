-- Carbon's Universal ESP - Enhanced GUI Edition
-- Added Line of Sight feature and updated fonts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

-- Cache frequently used functions
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local math_clamp = math.clamp
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local Color3_new = Color3.new
local Color3_fromRGB = Color3.fromRGB
local CFrame_new = CFrame.new
local ipairs = ipairs
local pairs = pairs
local string_format = string.format

-- Creative ESP Configuration
local ESPConfig = {
    -- Feature Toggles
    BoxEnabled = true,
    TracerEnabled = true,
    NameEnabled = true,
    DistanceEnabled = true,
    ToolEnabled = true,
    SkeletonEnabled = true,
    VisibilityCheck = true,
    ChamsEnabled = true,
    HealthBarEnabled = true,
    LineOfSightEnabled = true,
    
    -- Performance Settings
    UpdateRate = 60,
    MaxDistance = 1000,
    LODDistance = 200,
    LineOfSightDistance = 50,
    
    -- Creative Colors for ESP Elements
    BoxColor = Color3_fromRGB(0, 255, 255),
    TracerColor = Color3_fromRGB(255, 255, 255),
    NameColor = Color3_fromRGB(100, 150, 255),
    DistanceColor = Color3_fromRGB(255, 255, 255),
    ToolColor = Color3_fromRGB(255, 100, 100),
    SkeletonColor = Color3_fromRGB(255, 255, 255),
    HealthBarColor = Color3_fromRGB(0, 255, 0),
    ChamsColor = Color3_fromRGB(0, 255, 100),
    LineOfSightColor = Color3_fromRGB(255, 50, 150),
    
    -- Sizes
    BoxThickness = 1,
    TracerThickness = 1,
    SkeletonThickness = 1,
    HealthBarWidth = 4,
    HealthBarOffset = 8,
    LineOfSightThickness = 2,
    
    -- Text
    TextSize = 14,
    TextFont = Enum.Font.Gotham,
}

-- Updated Font Options
local FONT_OPTIONS = {
    {"Gotham", Enum.Font.Gotham, "Clean modern font (Default)"},
    {"GothamBold", Enum.Font.GothamBold, "Bold Gotham font"},
    {"Roboto", Enum.Font.Roboto, "Google's Roboto font"},
    {"RobotoBold", Enum.Font.RobotoBold, "Bold Roboto font"},
    {"Arial", Enum.Font.Arial, "Standard Arial font"},
    {"ArialBold", Enum.Font.ArialBold, "Bold Arial font"},
    {"SourceSans", Enum.Font.SourceSans, "Source Sans font"},
    {"SourceSansBold", Enum.Font.SourceSansBold, "Bold Source Sans"},
    {"LuckiestGuy", Enum.Font.LuckiestGuy, "Fun comic style font"},
    {"FredokaOne", Enum.Font.FredokaOne, "Rounded friendly font"}
}

-- ESP Storage
local ESPObjects = {}
local Connections = {}
local LastUpdate = 0
local FrameCount = 0
local CleanupQueue = {}

-- Mobile compatibility
local IsMobile = UserInputService.TouchEnabled
local IsConsole = UserInputService.GamepadEnabled
local IsDesktop = not IsMobile and not IsConsole

-- GUI State
local GUIEnabled = true
local IsGUIVisible = true
local IsDragging = false
local DragStart, StartPosition

-- Slider States
local isFontSliding = false
local isDistanceSliding = false
local isLOSSizing = false

-- Creative Color Palette for GUI
local CreativeColors = {
    Primary = Color3_fromRGB(25, 25, 35),
    Secondary = Color3_fromRGB(40, 40, 55),
    Accent = Color3_fromRGB(0, 150, 255),
    Accent2 = Color3_fromRGB(0, 200, 150),
    Text = Color3_fromRGB(240, 240, 255),
    Success = Color3_fromRGB(0, 230, 100),
    Warning = Color3_fromRGB(255, 180, 0),
    Danger = Color3_fromRGB(255, 80, 80),
    Purple = Color3_fromRGB(180, 100, 255),
    Gold = Color3_fromRGB(255, 215, 0)
}

-- Bone connections for skeleton ESP
local BONE_CONNECTIONS = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightUpperLeg", "RightFoot"}
}

-- Body parts for Chams
local CHAMS_PARTS = {
    "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm",
    "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg",
    "RightUpperLeg", "RightLowerLeg"
}

-- Improved drawing object creation with validation
local function CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for property, value in pairs(properties) do
        if drawing[property] ~= nil then
            drawing[property] = value
        end
    end
    return drawing
end

-- Safe get humanoid function
local function GetHumanoid(character)
    if character and character:IsDescendantOf(game) then
        return character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

-- Safe get root part function
local function GetRootPart(character)
    if character and character:IsDescendantOf(game) then
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    end
    return nil
end

-- Enhanced cleanup system
local function ProcessCleanupQueue()
    for i = #CleanupQueue, 1, -1 do
        local player = CleanupQueue[i]
        if ESPObjects[player] then
            RemoveESP(player)
            CleanupQueue[i] = nil
        end
    end
end

-- World-space bounding box calculation
local function GetBoundingBox(character)
    if not character or not character:IsDescendantOf(Workspace) then
        return nil
    end
    
    local humanoidRootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    
    if not humanoidRootPart or not humanoid then 
        return nil 
    end
    
    local rootPos, rootOnScreen = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
    if not rootOnScreen then return nil end
    
    -- Get head position for height calculation
    local head = character:FindFirstChild("Head")
    local headPos = rootPos
    if head then
        headPos = CurrentCamera:WorldToViewportPoint(head.Position)
    end
    
    -- Calculate proper vertical box dimensions in world space
    local height = math_max(30, (rootPos.Y - headPos.Y) * 2.2)
    local width = height * 0.4
    
    -- Calculate box position (centered on character)
    local boxX = rootPos.X - width / 2
    local boxY = headPos.Y - height * 0.1
    
    return {
        Position = Vector2_new(boxX, boxY),
        Size = Vector2_new(width, height),
        RootPosition = Vector2_new(rootPos.X, rootPos.Y),
        HeadPosition = Vector2_new(headPos.X, headPos.Y)
    }
end

-- Visibility check
local function IsPlayerVisible(character, targetPart, distance)
    if not ESPConfig.VisibilityCheck or distance > ESPConfig.LODDistance then 
        return true 
    end
    
    if not character or not targetPart or not character:IsDescendantOf(Workspace) then
        return false
    end
    
    local cameraPos = CurrentCamera.CFrame.Position
    local targetPos = targetPart.Position
    
    if (cameraPos - targetPos).Magnitude > ESPConfig.MaxDistance then
        return false
    end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {character, CurrentCamera}
    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances[#raycastParams.FilterDescendantsInstances + 1] = LocalPlayer.Character
    end
    
    local raycastResult = Workspace:Raycast(cameraPos, (targetPos - cameraPos).Unit * (targetPos - cameraPos).Magnitude, raycastParams)
    return raycastResult == nil
end

-- Creative color assignments for ESP elements
local function GetElementColor(elementType, isVisible, player)
    if not isVisible then
        return Color3_fromRGB(255, 255, 0)
    end
    
    if elementType == "Box" then
        return ESPConfig.BoxColor
    elseif elementType == "Tracer" then
        return ESPConfig.TracerColor
    elseif elementType == "Name" then
        return ESPConfig.NameColor
    elseif elementType == "Distance" then
        return ESPConfig.DistanceColor
    elseif elementType == "Tool" then
        return ESPConfig.ToolColor
    elseif elementType == "Skeleton" then
        return ESPConfig.SkeletonColor
    elseif elementType == "HealthBar" then
        return ESPConfig.HealthBarColor
    elseif elementType == "LineOfSight" then
        return ESPConfig.LineOfSightColor
    end
    
    return ESPConfig.BoxColor
end

-- Health color with gradient
local healthColorCache = {}
local function GetHealthColor(health, maxHealth)
    local percentage = health / maxHealth
    local cacheKey = math_floor(percentage * 100)
    
    if not healthColorCache[cacheKey] then
        if percentage > 0.6 then
            healthColorCache[cacheKey] = Color3_fromRGB(0, 255, 0)
        elseif percentage > 0.3 then
            healthColorCache[cacheKey] = Color3_fromRGB(255, 255, 0)
        else
            healthColorCache[cacheKey] = Color3_fromRGB(255, 0, 0)
        end
    end
    
    return healthColorCache[cacheKey]
end

-- Enhanced ESP Creation
local function CreateESP(player)
    if player == LocalPlayer or ESPObjects[player] then 
        if ESPObjects[player] then
            RemoveESP(player)
        end
        return 
    end
    
    local esp = {
        Player = player,
        Drawings = {},
        Chams = {},
        Connections = {},
        Character = nil,
        LastUpdate = 0,
        IsValid = true,
        LastBoundingBox = nil
    }
    
    local drawingTypes = {}
    
    if ESPConfig.BoxEnabled then
        for i = 1, 4 do
            drawingTypes["BoxLine"..i] = {"Line", {Thickness = ESPConfig.BoxThickness, Color = ESPConfig.BoxColor, Visible = false}}
        end
    end
    
    if ESPConfig.TracerEnabled then
        drawingTypes.Tracer = {"Line", {Thickness = ESPConfig.TracerThickness, Color = ESPConfig.TracerColor, Visible = false}}
    end
    
    if ESPConfig.NameEnabled then
        drawingTypes.Name = {"Text", {Text = player.Name, Size = ESPConfig.TextSize, Center = true, Outline = true, Font = ESPConfig.TextFont, Visible = false}}
    end
    
    if ESPConfig.DistanceEnabled then
        drawingTypes.Distance = {"Text", {Size = ESPConfig.TextSize, Center = true, Outline = true, Font = ESPConfig.TextFont, Visible = false}}
    end
    
    if ESPConfig.ToolEnabled then
        drawingTypes.Tool = {"Text", {Size = ESPConfig.TextSize - 2, Center = true, Outline = true, Font = ESPConfig.TextFont, Visible = false}}
    end
    
    if ESPConfig.HealthBarEnabled then
        drawingTypes.HealthBarBackground = {"Square", {Thickness = 1, Filled = true, Color = Color3_fromRGB(0, 0, 0), Visible = false}}
        drawingTypes.HealthBar = {"Square", {Thickness = 1, Filled = true, Color = ESPConfig.HealthBarColor, Visible = false}}
        drawingTypes.HealthBarOutline = {"Square", {Thickness = 1, Filled = false, Color = Color3_fromRGB(255, 255, 255), Visible = false}}
    end
    
    if ESPConfig.SkeletonEnabled then
        for i, connection in ipairs(BONE_CONNECTIONS) do
            drawingTypes["Bone_"..i] = {"Line", {Thickness = ESPConfig.SkeletonThickness, Color = ESPConfig.SkeletonColor, Visible = false}}
        end
    end
    
    -- Line of Sight drawings
    if ESPConfig.LineOfSightEnabled then
        drawingTypes.LineOfSight = {"Line", {Thickness = ESPConfig.LineOfSightThickness, Color = ESPConfig.LineOfSightColor, Visible = false}}
        drawingTypes.LineOfSightArrow1 = {"Line", {Thickness = ESPConfig.LineOfSightThickness, Color = ESPConfig.LineOfSightColor, Visible = false}}
        drawingTypes.LineOfSightArrow2 = {"Line", {Thickness = ESPConfig.LineOfSightThickness, Color = ESPConfig.LineOfSightColor, Visible = false}}
    end
    
    for name, drawingInfo in pairs(drawingTypes) do
        local success, drawing = pcall(CreateDrawing, drawingInfo[1], drawingInfo[2])
        if success and drawing then
            esp.Drawings[name] = drawing
        end
    end
    
    ESPObjects[player] = esp

    local function CharacterAdded(character)
        if not character or not character:IsDescendantOf(game) then
            return
        end
        
        local rootPart = GetRootPart(character)
        local humanoid = GetHumanoid(character)
        
        if not rootPart or not humanoid then
            task.delay(1, function()
                if character and character:IsDescendantOf(Workspace) and ESPObjects[player] then
                    CharacterAdded(character)
                end
            end)
            return
        end
        
        esp.Character = character
        
        if ESPConfig.ChamsEnabled then
            for _, partName in ipairs(CHAMS_PARTS) do
                local part = character:FindFirstChild(partName)
                if part and part:IsDescendantOf(Workspace) then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = part
                    highlight.FillColor = ESPConfig.ChamsColor
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Color3_new(0, 0, 0)
                    highlight.OutlineTransparency = 0.8
                    highlight.Parent = CoreGui
                    
                    esp.Chams[partName] = highlight
                end
            end
        end
        
        esp.Connections.HumanoidDied = humanoid.Died:Connect(function()
            for _, drawing in pairs(esp.Drawings) do
                if drawing then
                    drawing.Visible = false
                end
            end
            for _, cham in pairs(esp.Chams) do
                if cham then
                    cham.Enabled = false
                end
            end
        end)
    end
    
    if player.Character and player:IsDescendantOf(Players) then
        pcall(CharacterAdded, player.Character)
    end
    
    esp.Connections.CharacterAdded = player.CharacterAdded:Connect(function(character)
        if character and character:IsDescendantOf(game) then
            pcall(CharacterAdded, character)
        end
    end)
    
    esp.Connections.CharacterRemoving = player.CharacterRemoving:Connect(function()
        for _, drawing in pairs(esp.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        for _, cham in pairs(esp.Chams) do
            if cham then
                cham:Destroy()
            end
        end
        esp.Chams = {}
        esp.Character = nil
    end)
end

-- Enhanced ESP Removal
local function RemoveESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    
    esp.IsValid = false
    
    for name, connection in pairs(esp.Connections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
    
    for name, drawing in pairs(esp.Drawings) do
        if drawing then
            pcall(function() drawing:Remove() end)
        end
    end
    
    for name, cham in pairs(esp.Chams) do
        if cham then
            pcall(function() cham:Destroy() end)
        end
    end
    
    esp.Drawings = {}
    esp.Chams = {}
    esp.Connections = {}
    
    ESPObjects[player] = nil
end

-- World-space ESP update
local function UpdateESP(player, currentTime)
    local esp = ESPObjects[player]
    if not esp or not esp.IsValid then
        table.insert(CleanupQueue, player)
        return
    end
    
    local timeSinceLastUpdate = currentTime - esp.LastUpdate
    if timeSinceLastUpdate < (1 / ESPConfig.UpdateRate) then
        return
    end
    
    esp.LastUpdate = currentTime
    
    local character = esp.Character
    if not character or not character:IsDescendantOf(Workspace) then
        for _, drawing in pairs(esp.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        return
    end
    
    local humanoidRootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    
    if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
        for _, drawing in pairs(esp.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        for _, cham in pairs(esp.Chams) do
            if cham then 
                cham.Enabled = false 
            end
        end
        return
    end
    
    local distance = (humanoidRootPart.Position - CurrentCamera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        for _, drawing in pairs(esp.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        for _, cham in pairs(esp.Chams) do
            if cham then 
                cham.Enabled = false 
            end
        end
        return
    end
    
    local isVisible = IsPlayerVisible(character, humanoidRootPart, distance)
    
    if ESPConfig.ChamsEnabled and distance <= ESPConfig.LODDistance then
        for _, cham in pairs(esp.Chams) do
            if cham then
                cham.Enabled = isVisible
            end
        end
    elseif ESPConfig.ChamsEnabled then
        for _, cham in pairs(esp.Chams) do
            if cham then 
                cham.Enabled = false 
            end
        end
    end
    
    local boundingBox = GetBoundingBox(character)
    local onScreen = boundingBox ~= nil
    
    if onScreen then
        local pos, size = boundingBox.Position, boundingBox.Size
        local rootPos, headPos = boundingBox.RootPosition, boundingBox.HeadPosition
        
        if ESPConfig.BoxEnabled then
            local lines = {
                {pos, pos + Vector2_new(size.X, 0)},
                {pos, pos + Vector2_new(0, size.Y)},
                {pos + Vector2_new(size.X, 0), pos + size},
                {pos + Vector2_new(0, size.Y), pos + size}
            }
            
            for i = 1, 4 do
                local line = esp.Drawings["BoxLine"..i]
                if line then
                    line.From = lines[i][1]
                    line.To = lines[i][2]
                    line.Color = GetElementColor("Box", isVisible, player)
                    line.Visible = true
                end
            end
        end
        
        if ESPConfig.HealthBarEnabled then
            local healthBarX = pos.X - ESPConfig.HealthBarOffset - ESPConfig.HealthBarWidth
            local healthBarY = pos.Y
            local healthBarHeight = size.Y
            
            local healthPercentage = humanoid.Health / humanoid.MaxHealth
            local healthHeight = healthBarHeight * math_max(0, math_min(1, healthPercentage))
            
            local bg = esp.Drawings.HealthBarBackground
            if bg then
                bg.Position = Vector2_new(healthBarX, healthBarY)
                bg.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarHeight)
                bg.Visible = true
            end
            
            local fill = esp.Drawings.HealthBar
            if fill then
                fill.Position = Vector2_new(healthBarX, healthBarY + healthBarHeight - healthHeight)
                fill.Size = Vector2_new(ESPConfig.HealthBarWidth, healthHeight)
                fill.Color = GetHealthColor(humanoid.Health, humanoid.MaxHealth)
                fill.Visible = true
            end
            
            local outline = esp.Drawings.HealthBarOutline
            if outline then
                outline.Position = Vector2_new(healthBarX, healthBarY)
                outline.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarHeight)
                outline.Visible = true
            end
        end
        
        local head = character:FindFirstChild("Head")
        if head then
            local headScreenPos = CurrentCamera:WorldToViewportPoint(head.Position)
            
            if headScreenPos.Z > 0 then
                local screenPos = Vector2_new(headScreenPos.X, headScreenPos.Y)
                
                if ESPConfig.ToolEnabled then
                    local toolDrawing = esp.Drawings.Tool
                    if toolDrawing then
                        local equippedTool = character:FindFirstChildOfClass("Tool")
                        toolDrawing.Position = screenPos - Vector2_new(0, 70)
                        toolDrawing.Text = equippedTool and "Tool: " .. equippedTool.Name or "No Tool"
                        toolDrawing.Color = GetElementColor("Tool", isVisible, player)
                        toolDrawing.Visible = true
                    end
                end
                
                if ESPConfig.NameEnabled then
                    local nameDrawing = esp.Drawings.Name
                    if nameDrawing then
                        nameDrawing.Position = screenPos - Vector2_new(0, 50)
                        nameDrawing.Color = GetElementColor("Name", isVisible, player)
                        nameDrawing.Visible = true
                    end
                end
            else
                if ESPConfig.ToolEnabled then
                    local toolDrawing = esp.Drawings.Tool
                    if toolDrawing then toolDrawing.Visible = false end
                end
                if ESPConfig.NameEnabled then
                    local nameDrawing = esp.Drawings.Name
                    if nameDrawing then nameDrawing.Visible = false end
                end
            end
        end
        
        if ESPConfig.DistanceEnabled then
            local distanceDrawing = esp.Drawings.Distance
            if distanceDrawing then
                local rootScreenPos = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                if rootScreenPos.Z > 0 then
                    distanceDrawing.Position = Vector2_new(rootScreenPos.X, rootScreenPos.Y + 20)
                    distanceDrawing.Text = string_format("%.0f studs", distance)
                    distanceDrawing.Color = GetElementColor("Distance", isVisible, player)
                    distanceDrawing.Visible = true
                else
                    distanceDrawing.Visible = false
                end
            end
        end
        
        if ESPConfig.TracerEnabled then
            local tracer = esp.Drawings.Tracer
            if tracer then
                local rootScreenPos = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                if rootScreenPos.Z > 0 then
                    tracer.From = Vector2_new(CurrentCamera.ViewportSize.X / 2, CurrentCamera.ViewportSize.Y)
                    tracer.To = Vector2_new(rootScreenPos.X, rootScreenPos.Y)
                    tracer.Color = GetElementColor("Tracer", isVisible, player)
                    tracer.Visible = true
                else
                    tracer.Visible = false
                end
            end
        end
        
        if ESPConfig.SkeletonEnabled and distance <= ESPConfig.LODDistance then
            for i, connection in ipairs(BONE_CONNECTIONS) do
                local boneLine = esp.Drawings["Bone_"..i]
                
                if boneLine then
                    local part1 = character:FindFirstChild(connection[1])
                    local part2 = character:FindFirstChild(connection[2])
                    
                    if part1 and part2 and part1:IsA("BasePart") and part2:IsA("BasePart") then
                        local pos1, onScreen1 = CurrentCamera:WorldToViewportPoint(part1.Position)
                        local pos2, onScreen2 = CurrentCamera:WorldToViewportPoint(part2.Position)
                        
                        if onScreen1 and onScreen2 and pos1.Z > 0 and pos2.Z > 0 then
                            boneLine.From = Vector2_new(pos1.X, pos1.Y)
                            boneLine.To = Vector2_new(pos2.X, pos2.Y)
                            boneLine.Color = GetElementColor("Skeleton", isVisible, player)
                            boneLine.Visible = true
                        else
                            boneLine.Visible = false
                        end
                    else
                        boneLine.Visible = false
                    end
                end
            end
        else
            for i = 1, #BONE_CONNECTIONS do
                local boneLine = esp.Drawings["Bone_"..i]
                if boneLine then 
                    boneLine.Visible = false 
                end
            end
        end
        
        -- Line of Sight Feature
        if ESPConfig.LineOfSightEnabled and distance <= ESPConfig.LODDistance then
            local head = character:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                local headCFrame = head.CFrame
                local lookDirection = headCFrame.LookVector
                
                -- Calculate end point of line of sight
                local startPoint = headCFrame.Position
                local endPoint = startPoint + (lookDirection * ESPConfig.LineOfSightDistance)
                
                -- Convert to screen space
                local startScreenPos, startOnScreen = CurrentCamera:WorldToViewportPoint(startPoint)
                local endScreenPos, endOnScreen = CurrentCamera:WorldToViewportPoint(endPoint)
                
                if startOnScreen and endOnScreen and startScreenPos.Z > 0 and endScreenPos.Z > 0 then
                    local startVec = Vector2_new(startScreenPos.X, startScreenPos.Y)
                    local endVec = Vector2_new(endScreenPos.X, endScreenPos.Y)
                    
                    -- Main line of sight
                    local losLine = esp.Drawings.LineOfSight
                    if losLine then
                        losLine.From = startVec
                        losLine.To = endVec
                        losLine.Color = GetElementColor("LineOfSight", isVisible, player)
                        losLine.Visible = true
                    end
                    
                    -- Arrow head
                    local arrowSize = 10
                    local direction = (endVec - startVec).Unit
                    local perpendicular = Vector2_new(-direction.Y, direction.X)
                    
                    local arrow1 = esp.Drawings.LineOfSightArrow1
                    local arrow2 = esp.Drawings.LineOfSightArrow2
                    
                    if arrow1 and arrow2 then
                        arrow1.From = endVec
                        arrow1.To = endVec - (direction * arrowSize) + (perpendicular * arrowSize * 0.5)
                        arrow1.Color = GetElementColor("LineOfSight", isVisible, player)
                        arrow1.Visible = true
                        
                        arrow2.From = endVec
                        arrow2.To = endVec - (direction * arrowSize) - (perpendicular * arrowSize * 0.5)
                        arrow2.Color = GetElementColor("LineOfSight", isVisible, player)
                        arrow2.Visible = true
                    end
                else
                    if esp.Drawings.LineOfSight then esp.Drawings.LineOfSight.Visible = false end
                    if esp.Drawings.LineOfSightArrow1 then esp.Drawings.LineOfSightArrow1.Visible = false end
                    if esp.Drawings.LineOfSightArrow2 then esp.Drawings.LineOfSightArrow2.Visible = false end
                end
            else
                if esp.Drawings.LineOfSight then esp.Drawings.LineOfSight.Visible = false end
                if esp.Drawings.LineOfSightArrow1 then esp.Drawings.LineOfSightArrow1.Visible = false end
                if esp.Drawings.LineOfSightArrow2 then esp.Drawings.LineOfSightArrow2.Visible = false end
            end
        else
            if esp.Drawings.LineOfSight then esp.Drawings.LineOfSight.Visible = false end
            if esp.Drawings.LineOfSightArrow1 then esp.Drawings.LineOfSightArrow1.Visible = false end
            if esp.Drawings.LineOfSightArrow2 then esp.Drawings.LineOfSightArrow2.Visible = false end
        end
        
        esp.LastBoundingBox = boundingBox
        
    else
        for _, drawing in pairs(esp.Drawings) do
            if drawing then
                drawing.Visible = false
            end
        end
        
        if ESPConfig.ChamsEnabled then
            for _, cham in pairs(esp.Chams) do
                if cham then 
                    cham.Enabled = false 
                end
            end
        end
        
        esp.LastBoundingBox = nil
    end
end

-- Enhanced GUI with Font Selection and Line of Sight
local function CreateEnhancedGUI()
    local CarbonESP = Instance.new("ScreenGui")
    CarbonESP.Name = "CarbonESP"
    CarbonESP.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    CarbonESP.ResetOnSpawn = false
    CarbonESP.DisplayOrder = 10
    
    -- Adjust sizes for additional content
    local frameWidth = IsMobile and 420 or 400
    local frameHeight = IsMobile and 720 or 680
    local buttonSize = IsMobile and 100 or 80
    
    -- Main Container
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    MainFrame.Position = UDim2.new(0, 20, 0, 20)
    MainFrame.BackgroundColor3 = CreativeColors.Primary
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = CarbonESP
    MainFrame.ZIndex = 10

    -- Glass Effect
    local GlassEffect = Instance.new("Frame")
    GlassEffect.Size = UDim2.new(1, 0, 1, 0)
    GlassEffect.BackgroundTransparency = 0.9
    GlassEffect.BackgroundColor3 = CreativeColors.Text
    GlassEffect.BorderSizePixel = 0
    GlassEffect.ZIndex = -1
    GlassEffect.Parent = MainFrame

    -- Rounded corners
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 16)
    UICorner.Parent = MainFrame

    -- Border
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = CreativeColors.Accent
    UIStroke.Thickness = 2
    UIStroke.Parent = MainFrame

    -- Title Bar with Gradient
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, IsMobile and 70 or 60)
    TitleBar.BackgroundColor3 = CreativeColors.Secondary
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    TitleBar.ZIndex = 11

    local TitleBarCorner = Instance.new("UICorner")
    TitleBarCorner.CornerRadius = UDim.new(0, 16)
    TitleBarCorner.Parent = TitleBar

    -- Gradient Effect
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, CreativeColors.Accent),
        ColorSequenceKeypoint.new(1, CreativeColors.Accent2)
    })
    Gradient.Rotation = 45
    Gradient.Parent = TitleBar

    -- Title with Icon
    local TitleContainer = Instance.new("Frame")
    TitleContainer.Size = UDim2.new(1, -buttonSize - 10, 1, 0)
    TitleContainer.Position = UDim2.new(0, 15, 0, 0)
    TitleContainer.BackgroundTransparency = 1
    TitleContainer.Parent = TitleBar
    TitleContainer.ZIndex = 12

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, 0, 0.6, 0)
    Title.Position = UDim2.new(0, 0, 0, 5)
    Title.BackgroundTransparency = 1
    Title.Text = "CARBON'S ESP"
    Title.TextColor3 = CreativeColors.Text
    Title.TextSize = IsMobile and 20 or 18
    Title.Font = Enum.Font.GothamBlack
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleContainer
    Title.ZIndex = 13

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, 0, 0.4, 0)
    Subtitle.Position = UDim2.new(0, 0, 0.6, 0)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "LINE OF SIGHT EDITION"
    Subtitle.TextColor3 = CreativeColors.Text
    Subtitle.TextTransparency = 0.3
    Subtitle.TextSize = IsMobile and 12 or 10
    Subtitle.Font = Enum.Font.GothamBold
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Parent = TitleContainer
    Subtitle.ZIndex = 13

    -- FIXED: Hide Button with proper text
    local HideButton = Instance.new("TextButton")
    HideButton.Name = "HideButton"
    HideButton.Size = UDim2.new(0, buttonSize, 0, IsMobile and 35 or 30)
    HideButton.Position = UDim2.new(1, -buttonSize - 5, 0.5, -(IsMobile and 17.5 or 15))
    HideButton.BackgroundColor3 = CreativeColors.Warning
    HideButton.BorderSizePixel = 0
    HideButton.Text = "HIDE"
    HideButton.TextColor3 = CreativeColors.Text
    HideButton.TextSize = IsMobile and 14 or 12
    HideButton.Font = Enum.Font.GothamBold
    HideButton.Parent = TitleBar
    HideButton.ZIndex = 14
    HideButton.AutoButtonColor = true
    HideButton.Active = true

    local HideButtonCorner = Instance.new("UICorner")
    HideButtonCorner.CornerRadius = UDim.new(0, 8)
    HideButtonCorner.Parent = HideButton

    -- Scrollable Content Area
    local ScrollContainer = Instance.new("Frame")
    ScrollContainer.Name = "ScrollContainer"
    ScrollContainer.Size = UDim2.new(1, -20, 1, -(IsMobile and 90 or 80))
    ScrollContainer.Position = UDim2.new(0, 10, 0, IsMobile and 80 or 70)
    ScrollContainer.BackgroundTransparency = 1
    ScrollContainer.Parent = MainFrame
    ScrollContainer.ZIndex = 10

    local ScrollingFrame = Instance.new("ScrollingFrame")
    ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    ScrollingFrame.BackgroundTransparency = 1
    ScrollingFrame.BorderSizePixel = 0
    ScrollingFrame.ScrollBarThickness = IsMobile and 10 or 6
    ScrollingFrame.ScrollBarImageColor3 = CreativeColors.Accent
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 1200)
    ScrollingFrame.Parent = ScrollContainer
    ScrollingFrame.ZIndex = 10

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.Padding = UDim.new(0, IsMobile and 12 or 10)
    ContentLayout.Parent = ScrollingFrame

    -- Feature Categories
    local Categories = {
        {
            Name = "VISUAL FEATURES",
            Color = CreativeColors.Accent,
            Features = {
                {"Box ESP", "BoxEnabled"},
                {"Skeleton", "SkeletonEnabled"},
                {"Chams", "ChamsEnabled"},
                {"Health Bars", "HealthBarEnabled"},
                {"Tracers", "TracerEnabled"},
                {"Line of Sight", "LineOfSightEnabled"}
            }
        },
        {
            Name = "TEXT FEATURES", 
            Color = CreativeColors.Accent2,
            Features = {
                {"Player Names", "NameEnabled"},
                {"Distance", "DistanceEnabled"},
                {"Tool Names", "ToolEnabled"}
            }
        },
        {
            Name = "SETTINGS",
            Color = CreativeColors.Purple,
            Features = {
                {"Visibility Check", "VisibilityCheck"}
            }
        }
    }

    local ToggleButtons = {}

    for _, category in ipairs(Categories) do
        -- Category Header
        local CategoryHeader = Instance.new("Frame")
        CategoryHeader.Size = UDim2.new(1, 0, 0, IsMobile and 30 or 25)
        CategoryHeader.BackgroundTransparency = 1
        CategoryHeader.Parent = ScrollingFrame
        CategoryHeader.ZIndex = 10

        local CategoryLabel = Instance.new("TextLabel")
        CategoryLabel.Size = UDim2.new(1, 0, 1, 0)
        CategoryLabel.BackgroundTransparency = 1
        CategoryLabel.Text = category.Name
        CategoryLabel.TextColor3 = category.Color
        CategoryLabel.TextSize = IsMobile and 14 or 12
        CategoryLabel.Font = Enum.Font.GothamBold
        CategoryLabel.TextXAlignment = Enum.TextXAlignment.Left
        CategoryLabel.Parent = CategoryHeader
        CategoryLabel.ZIndex = 11

        -- Category Features
        for _, feature in ipairs(category.Features) do
            local ToggleContainer = Instance.new("Frame")
            ToggleContainer.Size = UDim2.new(1, 0, 0, IsMobile and 45 or 35)
            ToggleContainer.BackgroundColor3 = CreativeColors.Secondary
            ToggleContainer.BackgroundTransparency = 0.8
            ToggleContainer.Parent = ScrollingFrame
            ToggleContainer.ZIndex = 10

            local ToggleCorner = Instance.new("UICorner")
            ToggleCorner.CornerRadius = UDim.new(0, 8)
            ToggleCorner.Parent = ToggleContainer

            local FeatureLabel = Instance.new("TextLabel")
            FeatureLabel.Size = UDim2.new(0, 200, 1, 0)
            FeatureLabel.BackgroundTransparency = 1
            FeatureLabel.Text = "  " .. feature[1]
            FeatureLabel.TextColor3 = CreativeColors.Text
            FeatureLabel.TextSize = IsMobile and 14 or 12
            FeatureLabel.Font = Enum.Font.Gotham
            FeatureLabel.TextXAlignment = Enum.TextXAlignment.Left
            FeatureLabel.Parent = ToggleContainer
            FeatureLabel.ZIndex = 11

            local ToggleButton = Instance.new("TextButton")
            ToggleButton.Name = feature[2]
            ToggleButton.Size = UDim2.new(0, IsMobile and 70 or 60, 0, IsMobile and 30 or 25)
            ToggleButton.Position = UDim2.new(1, -(IsMobile and 75 or 65), 0.5, -(IsMobile and 15 or 12.5))
            ToggleButton.BackgroundColor3 = ESPConfig[feature[2]] and CreativeColors.Success or CreativeColors.Danger
            ToggleButton.BorderSizePixel = 0
            ToggleButton.Text = ESPConfig[feature[2]] and "ON" or "OFF"
            ToggleButton.TextColor3 = CreativeColors.Text
            ToggleButton.TextSize = IsMobile and 12 or 10
            ToggleButton.Font = Enum.Font.GothamBold
            ToggleButton.Parent = ToggleContainer
            ToggleButton.ZIndex = 12
            ToggleButton.AutoButtonColor = true
            ToggleButton.Active = true

            local ToggleButtonCorner = Instance.new("UICorner")
            ToggleButtonCorner.CornerRadius = UDim.new(0, 6)
            ToggleButtonCorner.Parent = ToggleButton

            ToggleButtons[feature[2]] = ToggleButton
        end
    end

    -- Font Size Slider Section
    local FontSizeContainer = Instance.new("Frame")
    FontSizeContainer.Size = UDim2.new(1, 0, 0, IsMobile and 80 or 70)
    FontSizeContainer.BackgroundColor3 = CreativeColors.Secondary
    FontSizeContainer.BackgroundTransparency = 0.8
    FontSizeContainer.Parent = ScrollingFrame
    FontSizeContainer.ZIndex = 10

    local FontSizeCorner = Instance.new("UICorner")
    FontSizeCorner.CornerRadius = UDim.new(0, 8)
    FontSizeCorner.Parent = FontSizeContainer

    local FontSizeLabel = Instance.new("TextLabel")
    FontSizeLabel.Size = UDim2.new(1, -20, 0, IsMobile and 20 or 18)
    FontSizeLabel.Position = UDim2.new(0, 10, 0, 8)
    FontSizeLabel.BackgroundTransparency = 1
    FontSizeLabel.Text = "FONT SIZE: " .. ESPConfig.TextSize
    FontSizeLabel.TextColor3 = CreativeColors.Text
    FontSizeLabel.TextSize = IsMobile and 14 or 12
    FontSizeLabel.Font = Enum.Font.GothamBold
    FontSizeLabel.TextXAlignment = Enum.TextXAlignment.Left
    FontSizeLabel.Parent = FontSizeContainer
    FontSizeLabel.ZIndex = 11

    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, -20, 0, IsMobile and 6 or 5)
    SliderTrack.Position = UDim2.new(0, 10, 0, IsMobile and 45 or 40)
    SliderTrack.BackgroundColor3 = CreativeColors.Primary
    SliderTrack.BorderSizePixel = 0
    SliderTrack.Parent = FontSizeContainer
    SliderTrack.ZIndex = 11

    local SliderTrackCorner = Instance.new("UICorner")
    SliderTrackCorner.CornerRadius = UDim.new(0, 3)
    SliderTrackCorner.Parent = SliderTrack

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((ESPConfig.TextSize - 8) / 16, 0, 1, 0)
    SliderFill.BackgroundColor3 = CreativeColors.Gold
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderTrack
    SliderFill.ZIndex = 12

    local SliderFillCorner = Instance.new("UICorner")
    SliderFillCorner.CornerRadius = UDim.new(0, 3)
    SliderFillCorner.Parent = SliderFill

    local SliderButton = Instance.new("TextButton")
    SliderButton.Size = UDim2.new(0, IsMobile and 20 or 18, 0, IsMobile and 20 or 18)
    SliderButton.Position = UDim2.new((ESPConfig.TextSize - 8) / 16, -(IsMobile and 10 or 9), 0.5, -(IsMobile and 10 or 9))
    SliderButton.BackgroundColor3 = CreativeColors.Gold
    SliderButton.BorderSizePixel = 0
    SliderButton.Text = ""
    SliderButton.Parent = SliderTrack
    SliderButton.ZIndex = 13
    SliderButton.AutoButtonColor = false
    SliderButton.Active = true

    local SliderButtonCorner = Instance.new("UICorner")
    SliderButtonCorner.CornerRadius = UDim.new(0, IsMobile and 10 or 9)
    SliderButtonCorner.Parent = SliderButton

    -- Max Distance Slider
    local DistanceContainer = Instance.new("Frame")
    DistanceContainer.Size = UDim2.new(1, 0, 0, IsMobile and 80 or 70)
    DistanceContainer.BackgroundColor3 = CreativeColors.Secondary
    DistanceContainer.BackgroundTransparency = 0.8
    DistanceContainer.Parent = ScrollingFrame
    DistanceContainer.ZIndex = 10

    local DistanceCorner = Instance.new("UICorner")
    DistanceCorner.CornerRadius = UDim.new(0, 8)
    DistanceCorner.Parent = DistanceContainer

    local DistanceLabel = Instance.new("TextLabel")
    DistanceLabel.Size = UDim2.new(1, -20, 0, IsMobile and 20 or 18)
    DistanceLabel.Position = UDim2.new(0, 10, 0, 8)
    DistanceLabel.BackgroundTransparency = 1
    DistanceLabel.Text = "MAX DISTANCE: " .. ESPConfig.MaxDistance .. " studs"
    DistanceLabel.TextColor3 = CreativeColors.Text
    DistanceLabel.TextSize = IsMobile and 14 or 12
    DistanceLabel.Font = Enum.Font.GothamBold
    DistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    DistanceLabel.Parent = DistanceContainer
    DistanceLabel.ZIndex = 11

    local DistanceSliderTrack = Instance.new("Frame")
    DistanceSliderTrack.Size = UDim2.new(1, -20, 0, IsMobile and 6 or 5)
    DistanceSliderTrack.Position = UDim2.new(0, 10, 0, IsMobile and 45 or 40)
    DistanceSliderTrack.BackgroundColor3 = CreativeColors.Primary
    DistanceSliderTrack.BorderSizePixel = 0
    DistanceSliderTrack.Parent = DistanceContainer
    DistanceSliderTrack.ZIndex = 11

    local DistanceTrackCorner = Instance.new("UICorner")
    DistanceTrackCorner.CornerRadius = UDim.new(0, 3)
    DistanceTrackCorner.Parent = DistanceSliderTrack

    local DistanceSliderFill = Instance.new("Frame")
    DistanceSliderFill.Size = UDim2.new(ESPConfig.MaxDistance / 1000, 0, 1, 0)
    DistanceSliderFill.BackgroundColor3 = CreativeColors.Purple
    DistanceSliderFill.BorderSizePixel = 0
    DistanceSliderFill.Parent = DistanceSliderTrack
    DistanceSliderFill.ZIndex = 12

    local DistanceFillCorner = Instance.new("UICorner")
    DistanceFillCorner.CornerRadius = UDim.new(0, 3)
    DistanceFillCorner.Parent = DistanceSliderFill

    local DistanceSliderButton = Instance.new("TextButton")
    DistanceSliderButton.Size = UDim2.new(0, IsMobile and 20 or 18, 0, IsMobile and 20 or 18)
    DistanceSliderButton.Position = UDim2.new(ESPConfig.MaxDistance / 1000, -(IsMobile and 10 or 9), 0.5, -(IsMobile and 10 or 9))
    DistanceSliderButton.BackgroundColor3 = CreativeColors.Purple
    DistanceSliderButton.BorderSizePixel = 0
    DistanceSliderButton.Text = ""
    DistanceSliderButton.Parent = DistanceSliderTrack
    DistanceSliderButton.ZIndex = 13
    DistanceSliderButton.AutoButtonColor = false
    DistanceSliderButton.Active = true

    local DistanceButtonCorner = Instance.new("UICorner")
    DistanceButtonCorner.CornerRadius = UDim.new(0, IsMobile and 10 or 9)
    DistanceButtonCorner.Parent = DistanceSliderButton

    -- NEW: Line of Sight Distance Slider
    local LOSDistanceContainer = Instance.new("Frame")
    LOSDistanceContainer.Size = UDim2.new(1, 0, 0, IsMobile and 80 or 70)
    LOSDistanceContainer.BackgroundColor3 = CreativeColors.Secondary
    LOSDistanceContainer.BackgroundTransparency = 0.8
    LOSDistanceContainer.Parent = ScrollingFrame
    LOSDistanceContainer.ZIndex = 10

    local LOSDistanceCorner = Instance.new("UICorner")
    LOSDistanceCorner.CornerRadius = UDim.new(0, 8)
    LOSDistanceCorner.Parent = LOSDistanceContainer

    local LOSDistanceLabel = Instance.new("TextLabel")
    LOSDistanceLabel.Size = UDim2.new(1, -20, 0, IsMobile and 20 or 18)
    LOSDistanceLabel.Position = UDim2.new(0, 10, 0, 8)
    LOSDistanceLabel.BackgroundTransparency = 1
    LOSDistanceLabel.Text = "LINE OF SIGHT RANGE: " .. ESPConfig.LineOfSightDistance .. " studs"
    LOSDistanceLabel.TextColor3 = CreativeColors.Text
    LOSDistanceLabel.TextSize = IsMobile and 14 or 12
    LOSDistanceLabel.Font = Enum.Font.GothamBold
    LOSDistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    LOSDistanceLabel.Parent = LOSDistanceContainer
    LOSDistanceLabel.ZIndex = 11

    local LOSSliderTrack = Instance.new("Frame")
    LOSSliderTrack.Size = UDim2.new(1, -20, 0, IsMobile and 6 or 5)
    LOSSliderTrack.Position = UDim2.new(0, 10, 0, IsMobile and 45 or 40)
    LOSSliderTrack.BackgroundColor3 = CreativeColors.Primary
    LOSSliderTrack.BorderSizePixel = 0
    LOSSliderTrack.Parent = LOSDistanceContainer
    LOSSliderTrack.ZIndex = 11

    local LOSTrackCorner = Instance.new("UICorner")
    LOSTrackCorner.CornerRadius = UDim.new(0, 3)
    LOSTrackCorner.Parent = LOSSliderTrack

    local LOSSliderFill = Instance.new("Frame")
    LOSSliderFill.Size = UDim2.new(ESPConfig.LineOfSightDistance / 100, 0, 1, 0)
    LOSSliderFill.BackgroundColor3 = CreativeColors.Danger
    LOSSliderFill.BorderSizePixel = 0
    LOSSliderFill.Parent = LOSSliderTrack
    LOSSliderFill.ZIndex = 12

    local LOSFillCorner = Instance.new("UICorner")
    LOSFillCorner.CornerRadius = UDim.new(0, 3)
    LOSFillCorner.Parent = LOSSliderFill

    local LOSSliderButton = Instance.new("TextButton")
    LOSSliderButton.Size = UDim2.new(0, IsMobile and 20 or 18, 0, IsMobile and 20 or 18)
    LOSSliderButton.Position = UDim2.new(ESPConfig.LineOfSightDistance / 100, -(IsMobile and 10 or 9), 0.5, -(IsMobile and 10 or 9))
    LOSSliderButton.BackgroundColor3 = CreativeColors.Danger
    LOSSliderButton.BorderSizePixel = 0
    LOSSliderButton.Text = ""
    LOSSliderButton.Parent = LOSSliderTrack
    LOSSliderButton.ZIndex = 13
    LOSSliderButton.AutoButtonColor = false
    LOSSliderButton.Active = true

    local LOSButtonCorner = Instance.new("UICorner")
    LOSButtonCorner.CornerRadius = UDim.new(0, IsMobile and 10 or 9)
    LOSButtonCorner.Parent = LOSSliderButton

    -- NEW: Font Selection Section
    local FontSelectionContainer = Instance.new("Frame")
    FontSelectionContainer.Size = UDim2.new(1, 0, 0, IsMobile and 180 or 150)
    FontSelectionContainer.BackgroundColor3 = CreativeColors.Secondary
    FontSelectionContainer.BackgroundTransparency = 0.8
    FontSelectionContainer.Parent = ScrollingFrame
    FontSelectionContainer.ZIndex = 10

    local FontSelectionCorner = Instance.new("UICorner")
    FontSelectionCorner.CornerRadius = UDim.new(0, 8)
    FontSelectionCorner.Parent = FontSelectionContainer

    local FontSelectionLabel = Instance.new("TextLabel")
    FontSelectionLabel.Size = UDim2.new(1, -20, 0, IsMobile and 25 or 20)
    FontSelectionLabel.Position = UDim2.new(0, 10, 0, 8)
    FontSelectionLabel.BackgroundTransparency = 1
    FontSelectionLabel.Text = "FONT SELECTION"
    FontSelectionLabel.TextColor3 = CreativeColors.Gold
    FontSelectionLabel.TextSize = IsMobile and 16 or 14
    FontSelectionLabel.Font = Enum.Font.GothamBold
    FontSelectionLabel.TextXAlignment = Enum.TextXAlignment.Left
    FontSelectionLabel.Parent = FontSelectionContainer
    FontSelectionLabel.ZIndex = 11

    -- Font Selection Scroll Frame
    local FontScrollFrame = Instance.new("ScrollingFrame")
    FontScrollFrame.Size = UDim2.new(1, -20, 0, IsMobile and 130 or 100)
    FontScrollFrame.Position = UDim2.new(0, 10, 0, IsMobile and 35 or 30)
    FontScrollFrame.BackgroundTransparency = 1
    FontScrollFrame.BorderSizePixel = 0
    FontScrollFrame.ScrollBarThickness = IsMobile and 8 or 6
    FontScrollFrame.ScrollBarImageColor3 = CreativeColors.Gold
    FontScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    FontScrollFrame.Parent = FontSelectionContainer
    FontScrollFrame.ZIndex = 11

    local FontListLayout = Instance.new("UIListLayout")
    FontListLayout.Padding = UDim.new(0, 5)
    FontListLayout.Parent = FontScrollFrame

    -- Create font buttons
    local SelectedFontButton = nil
    
    for i, fontInfo in ipairs(FONT_OPTIONS) do
        local fontName, fontEnum, fontDescription = fontInfo[1], fontInfo[2], fontInfo[3]
        
        local FontButton = Instance.new("TextButton")
        FontButton.Size = UDim2.new(1, 0, 0, IsMobile and 30 or 25)
        FontButton.BackgroundColor3 = ESPConfig.TextFont == fontEnum and CreativeColors.Success or CreativeColors.Secondary
        FontButton.BackgroundTransparency = ESPConfig.TextFont == fontEnum and 0.2 or 0.5
        FontButton.BorderSizePixel = 0
        FontButton.Text = fontName
        FontButton.TextColor3 = CreativeColors.Text
        FontButton.TextSize = IsMobile and 12 or 10
        FontButton.Font = Enum.Font.Gotham
        FontButton.Parent = FontScrollFrame
        FontButton.ZIndex = 12
        FontButton.AutoButtonColor = true
        FontButton.Active = true
        
        local FontButtonCorner = Instance.new("UICorner")
        FontButtonCorner.CornerRadius = UDim.new(0, 6)
        FontButtonCorner.Parent = FontButton
        
        -- Tooltip for font description
        local Tooltip = Instance.new("TextLabel")
        Tooltip.Size = UDim2.new(1, 0, 0, IsMobile and 15 or 12)
        Tooltip.Position = UDim2.new(0, 0, 1, 2)
        Tooltip.BackgroundTransparency = 1
        Tooltip.Text = fontDescription
        Tooltip.TextColor3 = CreativeColors.Text
        Tooltip.TextTransparency = 0.5
        Tooltip.TextSize = IsMobile and 10 or 8
        Tooltip.Font = Enum.Font.Gotham
        Tooltip.TextXAlignment = Enum.TextXAlignment.Left
        Tooltip.Visible = false
        Tooltip.Parent = FontButton
        Tooltip.ZIndex = 13
        
        FontButton.MouseEnter:Connect(function()
            Tooltip.Visible = true
        end)
        
        FontButton.MouseLeave:Connect(function()
            Tooltip.Visible = false
        end)
        
        FontButton.MouseButton1Click:Connect(function()
            -- Update all font buttons
            for _, child in ipairs(FontScrollFrame:GetChildren()) do
                if child:IsA("TextButton") and child ~= FontButton then
                    child.BackgroundColor3 = CreativeColors.Secondary
                    child.BackgroundTransparency = 0.5
                end
            end
            
            -- Highlight selected font
            FontButton.BackgroundColor3 = CreativeColors.Success
            FontButton.BackgroundTransparency = 0.2
            
            -- Update ESP font
            ESPConfig.TextFont = fontEnum
            
            -- Update all ESP objects with new font
            for player, esp in pairs(ESPObjects) do
                if esp.Drawings.Name then
                    esp.Drawings.Name.Font = fontEnum
                end
                if esp.Drawings.Distance then
                    esp.Drawings.Distance.Font = fontEnum
                end
                if esp.Drawings.Tool then
                    esp.Drawings.Tool.Font = fontEnum
                end
            end
            
            SelectedFontButton = FontButton
        end)
        
        -- Set initial selection
        if ESPConfig.TextFont == fontEnum then
            FontButton.BackgroundColor3 = CreativeColors.Success
            FontButton.BackgroundTransparency = 0.2
            SelectedFontButton = FontButton
        end
    end

    -- Auto-update font scroll frame size
    FontListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        FontScrollFrame.CanvasSize = UDim2.new(0, 0, 0, FontListLayout.AbsoluteContentSize.Y)
    end)

    -- FIXED: Universal drag system
    local function StartDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            IsDragging = true
            DragStart = input.Position
            StartPosition = MainFrame.Position
            
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    IsDragging = false
                    connection:Disconnect()
                end
            end)
        end
    end

    local function UpdateDrag(input)
        if IsDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - DragStart
            MainFrame.Position = UDim2.new(0, StartPosition.X.Offset + delta.X, 0, StartPosition.Y.Offset + delta.Y)
        end
    end

    TitleBar.InputBegan:Connect(StartDrag)
    UserInputService.InputChanged:Connect(UpdateDrag)

    -- Toggle button functionality
    for featureName, button in pairs(ToggleButtons) do
        button.MouseButton1Click:Connect(function()
            ESPConfig[featureName] = not ESPConfig[featureName]
            
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local colorTween = TweenService:Create(button, tweenInfo, {
                BackgroundColor3 = ESPConfig[featureName] and CreativeColors.Success or CreativeColors.Danger
            })
            
            colorTween:Play()
            
            button.Text = ESPConfig[featureName] and "ON" or "OFF"
            
            for player in pairs(ESPObjects) do
                RemoveESP(player)
                CreateESP(player)
            end
        end)
    end

    -- FIXED: Universal slider system
    local function UpdateFontSlider(input)
        if not isFontSliding then return end
        
        local inputPos = input.Position
        local trackAbsolutePos = SliderTrack.AbsolutePosition
        local trackAbsoluteSize = SliderTrack.AbsoluteSize
        
        local relativeX = math_clamp((inputPos.X - trackAbsolutePos.X) / trackAbsoluteSize.X, 0, 1)
        local newSize = math_floor(8 + relativeX * 16)
        
        if newSize ~= ESPConfig.TextSize then
            ESPConfig.TextSize = newSize
            FontSizeLabel.Text = "FONT SIZE: " .. newSize
            
            SliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            SliderButton.Position = UDim2.new(relativeX, -(IsMobile and 10 or 9), 0.5, -(IsMobile and 10 or 9))
            
            for player, esp in pairs(ESPObjects) do
                if esp.Drawings.Name then
                    esp.Drawings.Name.Size = newSize
                end
                if esp.Drawings.Distance then
                    esp.Drawings.Distance.Size = newSize
                end
                if esp.Drawings.Tool then
                    esp.Drawings.Tool.Size = newSize - 2
                end
            end
        end
    end

    local function UpdateDistanceSlider(input)
        if not isDistanceSliding then return end
        
        local inputPos = input.Position
        local trackAbsolutePos = DistanceSliderTrack.AbsolutePosition
        local trackAbsoluteSize = DistanceSliderTrack.AbsoluteSize
        
        local relativeX = math_clamp((inputPos.X - trackAbsolutePos.X) / trackAbsoluteSize.X, 0, 1)
        local newDistance = math_floor(relativeX * 1000)
        
        if newDistance ~= ESPConfig.MaxDistance then
            ESPConfig.MaxDistance = newDistance
            DistanceLabel.Text = "MAX DISTANCE: " .. newDistance .. " studs"
            
            DistanceSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            DistanceSliderButton.Position = UDim2.new(relativeX, -(IsMobile and 10 or 9), 0.5, -(IsMobile and 10 or 9))
        end
    end

    local function UpdateLOSSizing(input)
        if not isLOSSizing then return end
        
        local inputPos = input.Position
        local trackAbsolutePos = LOSSliderTrack.AbsolutePosition
        local trackAbsoluteSize = LOSSliderTrack.AbsoluteSize
        
        local relativeX = math_clamp((inputPos.X - trackAbsolutePos.X) / trackAbsoluteSize.X, 0, 1)
        local newDistance = math_floor(relativeX * 100)
        
        if newDistance ~= ESPConfig.LineOfSightDistance then
            ESPConfig.LineOfSightDistance = newDistance
            LOSDistanceLabel.Text = "LINE OF SIGHT RANGE: " .. newDistance .. " studs"
            
            LOSSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            LOSSliderButton.Position = UDim2.new(relativeX, -(IsMobile and 10 or 9), 0.5, -(IsMobile and 10 or 9))
        end
    end

    -- Universal slider input handling
    local function HandleSliderInput(input, sliderType)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if sliderType == "font" then
                isFontSliding = true
            elseif sliderType == "distance" then
                isDistanceSliding = true
            elseif sliderType == "los" then
                isLOSSizing = true
            end
            
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isFontSliding = false
                    isDistanceSliding = false
                    isLOSSizing = false
                    connection:Disconnect()
                end
            end)
        end
    end

    SliderButton.InputBegan:Connect(function(input)
        HandleSliderInput(input, "font")
    end)
    
    DistanceSliderButton.InputBegan:Connect(function(input)
        HandleSliderInput(input, "distance")
    end)
    
    LOSSliderButton.InputBegan:Connect(function(input)
        HandleSliderInput(input, "los")
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            UpdateFontSlider(input)
            UpdateDistanceSlider(input)
            UpdateLOSSizing(input)
        end
    end)

    -- FIXED: Enhanced Hide/Show functionality
    local function ToggleGUI()
        IsGUIVisible = not IsGUIVisible
        
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        if IsGUIVisible then
            -- Show GUI
            HideButton.Text = "HIDE"
            HideButton.BackgroundColor3 = CreativeColors.Warning
            local showTween = TweenService:Create(MainFrame, tweenInfo, {
                Size = UDim2.new(0, frameWidth, 0, frameHeight)
            })
            showTween:Play()
            
            -- Show scroll container
            ScrollContainer.Visible = true
        else
            -- Hide GUI (only show title bar)
            HideButton.Text = "SHOW"
            HideButton.BackgroundColor3 = CreativeColors.Success
            local hideTween = TweenService:Create(MainFrame, tweenInfo, {
                Size = UDim2.new(0, frameWidth, 0, IsMobile and 70 or 60)
            })
            hideTween:Play()
            
            -- Hide scroll container
            ScrollContainer.Visible = false
        end
    end

    -- Connect hide button
    HideButton.MouseButton1Click:Connect(ToggleGUI)
    HideButton.TouchTap:Connect(ToggleGUI)

    -- Auto-update canvas size
    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 20)
    end)

    CarbonESP.Parent = CoreGui
    return CarbonESP
end

-- Optimized main loop
local function ESPLoop()
    FrameCount = FrameCount + 1
    local currentTime = tick()
    
    ProcessCleanupQueue()
    
    if FrameCount % 30 == 0 then
        for player in pairs(ESPObjects) do
            if not player:IsDescendantOf(Players) then
                table.insert(CleanupQueue, player)
            end
        end
    end
    
    for player, esp in pairs(ESPObjects) do
        if esp and esp.IsValid then
            local success, err = pcall(UpdateESP, player, currentTime)
            if not success then
                warn("ESP Update Error for " .. player.Name .. ": " .. err)
                table.insert(CleanupQueue, player)
            end
        else
            table.insert(CleanupQueue, player)
        end
    end
end

-- Enhanced player monitoring
local function InitializePlayerMonitoring()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end
    
    Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.delay(1, function()
                if player:IsDescendantOf(Players) then
                    CreateESP(player)
                end
            end)
        end
    end)
    
    Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then
            RemoveESP(player)
        end
    end)
end

-- Initialize ESP
local function InitializeESP()
    CreateEnhancedGUI()
    InitializePlayerMonitoring()
    Connections.RenderStepped = RunService.RenderStepped:Connect(ESPLoop)
    
    print("Carbon's Universal ESP - LINE OF SIGHT EDITION Loaded!")
    print("Added: Line of Sight feature with adjustable range")
    print("Updated: 10 popular ESP fonts including Gotham, Roboto, Arial, etc.")
    print("Enhanced: Scrollable interface with better organization")
end

-- Cleanup function
local function CleanupESP()
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    for player in pairs(ESPObjects) do
        RemoveESP(player)
    end
    
    healthColorCache = {}
    CleanupQueue = {}
    
    local CarbonESP = CoreGui:FindFirstChild("CarbonESP")
    if CarbonESP then
        CarbonESP:Destroy()
    end
    
    print("Carbon's ESP cleaned up")
end

-- Initialize
InitializeESP()

return CleanupESP