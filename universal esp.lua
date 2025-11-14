-- Carbon's Universal ESP - Enhanced GUI Edition
-- Fixed GUI Popup

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
    ChamsEnabled = false,
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
    HealthBarWidth = 6,
    HealthBarOffset = 12,
    LineOfSightThickness = 2,
    
    -- Text
    TextSize = 14,
    TextFont = Enum.Font.Gotham,
}

-- Updated Font Options - Only working Roblox fonts
local FONT_OPTIONS = {
    {"Gotham", Enum.Font.Gotham, "Clean modern font (Default)"},
    {"Arial", Enum.Font.Arial, "Standard Arial font"},
    {"SourceSans", Enum.Font.SourceSans, "Source Sans font"},
    {"SciFi", Enum.Font.SciFi, "SciFi style font"},
    {"Code", Enum.Font.Code, "Monospace code font"}
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
    local filterList = {character, CurrentCamera}
    if LocalPlayer.Character then
        table.insert(filterList, LocalPlayer.Character)
    end
    raycastParams.FilterDescendantsInstances = filterList
    
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
        drawingTypes.Name = {"Text", {Text = player.Name, Size = ESPConfig.TextSize, Center = true, Outline = true, Font = ESPConfig.TextFont, Color = ESPConfig.NameColor, Visible = false}}
    end
    
    if ESPConfig.DistanceEnabled then
        drawingTypes.Distance = {"Text", {Size = ESPConfig.TextSize, Center = true, Outline = true, Font = ESPConfig.TextFont, Color = ESPConfig.DistanceColor, Visible = false}}
    end
    
    if ESPConfig.ToolEnabled then
        drawingTypes.Tool = {"Text", {Size = ESPConfig.TextSize - 2, Center = true, Outline = true, Font = ESPConfig.TextFont, Color = ESPConfig.ToolColor, Visible = false}}
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
                if part and part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
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
        
        -- BOX ESP (Independent)
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
        else
            for i = 1, 4 do
                local line = esp.Drawings["BoxLine"..i]
                if line then line.Visible = false end
            end
        end
        
        -- HEALTH BAR (Independent)
        if ESPConfig.HealthBarEnabled then
            local healthBarX = pos.X - ESPConfig.HealthBarOffset - ESPConfig.HealthBarWidth
            local healthBarY = pos.Y
            local healthBarHeight = size.Y
            
            local healthPercentage = math_clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            local healthHeight = healthBarHeight * healthPercentage
            
            local bg = esp.Drawings.HealthBarBackground
            if bg then
                bg.Position = Vector2_new(healthBarX, healthBarY)
                bg.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarHeight)
                bg.Visible = true
            end
            
            local fill = esp.Drawings.HealthBar
            if fill then
                fill.Position = Vector2_new(healthBarX, healthBarY + (healthBarHeight - healthHeight))
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
        else
            if esp.Drawings.HealthBarBackground then esp.Drawings.HealthBarBackground.Visible = false end
            if esp.Drawings.HealthBar then esp.Drawings.HealthBar.Visible = false end
            if esp.Drawings.HealthBarOutline then esp.Drawings.HealthBarOutline.Visible = false end
        end
        
        -- NAME TEXT (Independent)
        if ESPConfig.NameEnabled then
            local nameDrawing = esp.Drawings.Name
            if nameDrawing then
                local head = character:FindFirstChild("Head")
                if head then
                    local headScreenPos = CurrentCamera:WorldToViewportPoint(head.Position)
                    if headScreenPos.Z > 0 then
                        nameDrawing.Position = Vector2_new(headScreenPos.X, headScreenPos.Y - 45)
                        nameDrawing.Text = player.Name
                        nameDrawing.Color = GetElementColor("Name", isVisible, player)
                        nameDrawing.Visible = true
                    else
                        nameDrawing.Visible = false
                    end
                else
                    nameDrawing.Visible = false
                end
            end
        else
            if esp.Drawings.Name then esp.Drawings.Name.Visible = false end
        end
        
        -- TOOL TEXT (Independent)
        if ESPConfig.ToolEnabled then
            local toolDrawing = esp.Drawings.Tool
            if toolDrawing then
                local head = character:FindFirstChild("Head")
                if head then
                    local headScreenPos = CurrentCamera:WorldToViewportPoint(head.Position)
                    if headScreenPos.Z > 0 then
                        local equippedTool = character:FindFirstChildOfClass("Tool")
                        toolDrawing.Position = Vector2_new(headScreenPos.X, headScreenPos.Y - 30)
                        toolDrawing.Text = equippedTool and "Tool: " .. equippedTool.Name or "No Tool"
                        toolDrawing.Color = GetElementColor("Tool", isVisible, player)
                        toolDrawing.Visible = true
                    else
                        toolDrawing.Visible = false
                    end
                else
                    toolDrawing.Visible = false
                end
            end
        else
            if esp.Drawings.Tool then esp.Drawings.Tool.Visible = false end
        end
        
        -- DISTANCE TEXT (Independent)
        if ESPConfig.DistanceEnabled then
            local distanceDrawing = esp.Drawings.Distance
            if distanceDrawing then
                local rootScreenPos = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                if rootScreenPos.Z > 0 then
                    distanceDrawing.Position = Vector2_new(rootScreenPos.X, rootScreenPos.Y + 25)
                    distanceDrawing.Text = string_format("%.0f studs", distance)
                    distanceDrawing.Color = GetElementColor("Distance", isVisible, player)
                    distanceDrawing.Visible = true
                else
                    distanceDrawing.Visible = false
                end
            end
        else
            if esp.Drawings.Distance then esp.Drawings.Distance.Visible = false end
        end
        
        -- TRACER (Independent)
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
        else
            if esp.Drawings.Tracer then esp.Drawings.Tracer.Visible = false end
        end
        
        -- SKELETON (Independent)
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
        
        -- LINE OF SIGHT (Independent)
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
        -- All features off-screen
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

-- SIMPLIFIED GUI CREATION - GUARANTEED TO POP UP
local function CreateEnhancedGUI()
    -- Clean up any existing GUI first
    local existingGUI = CoreGui:FindFirstChild("CarbonESP")
    if existingGUI then
        existingGUI:Destroy()
    end
    
    -- Create the main GUI
    local CarbonESP = Instance.new("ScreenGui")
    CarbonESP.Name = "CarbonESP"
    CarbonESP.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    CarbonESP.ResetOnSpawn = false
    CarbonESP.DisplayOrder = 999
    CarbonESP.IgnoreGuiInset = true
    
    -- Create main frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 400, 0, 500)
    MainFrame.Position = UDim2.new(0, 20, 0, 20)
    MainFrame.BackgroundColor3 = CreativeColors.Primary
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = CarbonESP
    
    -- Add rounded corners
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    -- Add border
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = CreativeColors.Accent
    UIStroke.Thickness = 2
    UIStroke.Parent = MainFrame
    
    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundColor3 = CreativeColors.Secondary
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleBarCorner = Instance.new("UICorner")
    TitleBarCorner.CornerRadius = UDim.new(0, 12)
    TitleBarCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(0.7, 0, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "CARBON'S ESP v2.0"
    Title.TextColor3 = CreativeColors.Text
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    local HideButton = Instance.new("TextButton")
    HideButton.Name = "HideButton"
    HideButton.Size = UDim2.new(0, 80, 0, 30)
    HideButton.Position = UDim2.new(1, -85, 0.5, -15)
    HideButton.BackgroundColor3 = CreativeColors.Warning
    HideButton.BorderSizePixel = 0
    HideButton.Text = "HIDE"
    HideButton.TextColor3 = CreativeColors.Text
    HideButton.TextSize = 14
    HideButton.Font = Enum.Font.GothamBold
    HideButton.Parent = TitleBar
    
    local HideButtonCorner = Instance.new("UICorner")
    HideButtonCorner.CornerRadius = UDim.new(0, 6)
    HideButtonCorner.Parent = HideButton
    
    -- Content area
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -60)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 55)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = CreativeColors.Accent
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 800)
    ScrollFrame.Parent = MainFrame
    
    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.Padding = UDim.new(0, 8)
    ContentLayout.Parent = ScrollFrame
    
    -- Create toggle buttons for features
    local features = {
        {"Box ESP", "BoxEnabled", CreativeColors.Accent},
        {"Tracers", "TracerEnabled", CreativeColors.Accent},
        {"Names", "NameEnabled", CreativeColors.Accent2},
        {"Distance", "DistanceEnabled", CreativeColors.Accent2},
        {"Tools", "ToolEnabled", CreativeColors.Accent2},
        {"Skeleton", "SkeletonEnabled", CreativeColors.Purple},
        {"Health Bars", "HealthBarEnabled", CreativeColors.Purple},
        {"Line of Sight", "LineOfSightEnabled", CreativeColors.Purple},
        {"Visibility Check", "VisibilityCheck", CreativeColors.Gold},
        {"Chams", "ChamsEnabled", CreativeColors.Gold}
    }
    
    for i, feature in ipairs(features) do
        local featureName, configKey, color = feature[1], feature[2], feature[3]
        
        local ToggleContainer = Instance.new("Frame")
        ToggleContainer.Size = UDim2.new(1, 0, 0, 35)
        ToggleContainer.BackgroundColor3 = CreativeColors.Secondary
        ToggleContainer.BackgroundTransparency = 0.8
        ToggleContainer.Parent = ScrollFrame
        
        local ToggleCorner = Instance.new("UICorner")
        ToggleCorner.CornerRadius = UDim.new(0, 8)
        ToggleCorner.Parent = ToggleContainer
        
        local FeatureLabel = Instance.new("TextLabel")
        FeatureLabel.Size = UDim2.new(0, 200, 1, 0)
        FeatureLabel.BackgroundTransparency = 1
        FeatureLabel.Text = "  " .. featureName
        FeatureLabel.TextColor3 = color
        FeatureLabel.TextSize = 14
        FeatureLabel.Font = Enum.Font.Gotham
        FeatureLabel.TextXAlignment = Enum.TextXAlignment.Left
        FeatureLabel.Parent = ToggleContainer
        
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Name = configKey
        ToggleButton.Size = UDim2.new(0, 60, 0, 25)
        ToggleButton.Position = UDim2.new(1, -65, 0.5, -12.5)
        ToggleButton.BackgroundColor3 = ESPConfig[configKey] and CreativeColors.Success or CreativeColors.Danger
        ToggleButton.BorderSizePixel = 0
        ToggleButton.Text = ESPConfig[configKey] and "ON" or "OFF"
        ToggleButton.TextColor3 = CreativeColors.Text
        ToggleButton.TextSize = 12
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.Parent = ToggleContainer
        
        local ToggleButtonCorner = Instance.new("UICorner")
        ToggleButtonCorner.CornerRadius = UDim.new(0, 6)
        ToggleButtonCorner.Parent = ToggleButton
        
        -- Toggle functionality
        ToggleButton.MouseButton1Click:Connect(function()
            ESPConfig[configKey] = not ESPConfig[configKey]
            ToggleButton.BackgroundColor3 = ESPConfig[configKey] and CreativeColors.Success or CreativeColors.Danger
            ToggleButton.Text = ESPConfig[configKey] and "ON" or "OFF"
            
            -- Refresh ESP for all players
            for player in pairs(ESPObjects) do
                RemoveESP(player)
                CreateESP(player)
            end
        end)
    end
    
    -- Drag functionality
    local dragging = false
    local dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(0, startPos.X.Offset + delta.X, 0, startPos.Y.Offset + delta.Y)
    end
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
    
    -- Hide/show functionality
    local function ToggleGUI()
        IsGUIVisible = not IsGUIVisible
        if IsGUIVisible then
            MainFrame.Size = UDim2.new(0, 400, 0, 500)
            HideButton.Text = "HIDE"
            HideButton.BackgroundColor3 = CreativeColors.Warning
            ScrollFrame.Visible = true
        else
            MainFrame.Size = UDim2.new(0, 400, 0, 50)
            HideButton.Text = "SHOW"
            HideButton.BackgroundColor3 = CreativeColors.Success
            ScrollFrame.Visible = false
        end
    end
    
    HideButton.MouseButton1Click:Connect(ToggleGUI)
    
    -- Auto-update canvas size
    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 10)
    end)
    
    -- PARENT THE GUI - THIS IS CRITICAL!
    CarbonESP.Parent = CoreGui
    
    print("✅ Carbon ESP GUI created successfully!")
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
    print("🚀 Initializing Carbon's Universal ESP...")
    
    -- Create GUI FIRST - This ensures it pops up immediately
    local guiSuccess, guiError = pcall(CreateEnhancedGUI)
    if not guiSuccess then
        warn("❌ GUI Creation Failed: " .. tostring(guiError))
        -- Create a simple fallback GUI
        local fallbackGUI = Instance.new("ScreenGui")
        fallbackGUI.Name = "CarbonESP_Fallback"
        fallbackGUI.Parent = CoreGui
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 300, 0, 60)
        label.Position = UDim2.new(0, 20, 0, 20)
        label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Text = "Carbon ESP Loaded\n(GUI Error - Features Still Work)"
        label.TextWrapped = true
        label.Parent = fallbackGUI
    else
        print("✅ GUI created successfully!")
    end
    
    -- Initialize ESP monitoring
    InitializePlayerMonitoring()
    
    -- Start main loop
    Connections.RenderStepped = RunService.RenderStepped:Connect(ESPLoop)
    
    print("🎉 Carbon's Universal ESP - LINE OF SIGHT EDITION Fully Loaded!")
    print("📊 Features: Box ESP, Tracers, Names, Distance, Tools, Skeletons, Health Bars, Line of Sight")
    print("🎮 GUI should be visible in the top-left corner!")
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
    
    local FallbackGUI = CoreGui:FindFirstChild("CarbonESP_Fallback")
    if FallbackGUI then
        FallbackGUI:Destroy()
    end
    
    print("🧹 Carbon's ESP cleaned up")
end

-- MAIN EXECUTION - THIS MAKES THE GUI POP UP
print("🔧 Starting Carbon ESP...")
local success, err = pcall(InitializeESP)
if not success then
    warn("💥 ESP Initialization Error: " .. tostring(err))
    
    -- Even if main ESP fails, try to create at least a GUI
    local errorGUI = Instance.new("ScreenGui")
    errorGUI.Name = "CarbonESP_Error"
    errorGUI.Parent = CoreGui
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 350, 0, 80)
    label.Position = UDim2.new(0, 20, 0, 20)
    label.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = "Carbon ESP Error:\n" .. tostring(err)
    label.TextWrapped = true
    label.Parent = errorGUI
else
    print("✅ Carbon ESP initialized successfully!")
end

return CleanupESP
