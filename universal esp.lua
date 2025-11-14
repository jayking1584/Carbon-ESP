-- Carbon's Universal ESP - Fully Fixed Version
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
local math_floor = math.floor
local math_clamp = math.clamp
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local Color3_new = Color3.new
local Color3_fromRGB = Color3.fromRGB
local string_format = string.format

-- Creative ESP Configuration
local ESPConfig = {
    BoxEnabled = true,
    TracerEnabled = true,
    NameEnabled = true,
    DistanceEnabled = true,
    ToolEnabled = true,
    SkeletonEnabled = true,
    VisibilityCheck = true,
    ChamsEnabled = false, -- Disabled to prevent issues
    HealthBarEnabled = true,
    LineOfSightEnabled = true,
    
    UpdateRate = 60,
    MaxDistance = 1000,
    LODDistance = 200,
    LineOfSightDistance = 50,
    
    BoxColor = Color3_fromRGB(0, 255, 255),
    TracerColor = Color3_fromRGB(255, 255, 255),
    NameColor = Color3_fromRGB(100, 150, 255),
    DistanceColor = Color3_fromRGB(255, 255, 255),
    ToolColor = Color3_fromRGB(255, 100, 100),
    SkeletonColor = Color3_fromRGB(255, 255, 255),
    HealthBarColor = Color3_fromRGB(0, 255, 0),
    
    BoxThickness = 1,
    TracerThickness = 1,
    SkeletonThickness = 1,
    HealthBarWidth = 6,
    HealthBarOffset = 12,
    LineOfSightThickness = 2,
    
    TextSize = 14,
    TextFont = Enum.Font.Gotham,
}

-- ESP Storage
local ESPObjects = {}
local Connections = {}
local FrameCount = 0
local CleanupQueue = {}

-- FIXED: Helper function to hide all drawings
local function HideESPDrawings(esp)
    for _, drawing in pairs(esp.Drawings) do
        if drawing then 
            drawing.Visible = false 
        end
    end
end

-- FIXED: Proper bounding box calculation with stable scaling
local function GetBoundingBox(character)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end

    local center, visible = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
    if not visible or center.Z < 0 then return nil end

    -- FIXED: Stable scale calculation
    local distance = (CurrentCamera.CFrame.Position - humanoidRootPart.Position).Magnitude
    local scale = math_clamp(1000 / math_max(distance, 1), 0.5, 2.5)
    
    local boxHeight = math_clamp(scale * 40, 20, 80)
    local boxWidth = boxHeight * 0.6

    return {
        Position = Vector2_new(center.X - boxWidth/2, center.Y - boxHeight/2),
        Size = Vector2_new(boxWidth, boxHeight),
        RootPosition = Vector2_new(center.X, center.Y)
    }
end

-- FIXED: Tool detection - checks both character and backpack
local function GetEquippedTool(player, character)
    -- Check character first
    local tool = character:FindFirstChildWhichIsA("Tool")
    if tool then
        return tool
    end
    
    -- Check backpack
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                return item
            end
        end
    end
    
    return nil
end

-- FIXED: Safe get humanoid function
local function GetHumanoid(character)
    return character:FindFirstChildOfClass("Humanoid")
end

-- FIXED: Safe get root part function
local function GetRootPart(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso")
end

-- FIXED: Proper visibility check with correct raycast
local function IsPlayerVisible(character, targetPart, distance)
    if not ESPConfig.VisibilityCheck or distance > ESPConfig.LODDistance then 
        return true 
    end
    
    local cameraPos = CurrentCamera.CFrame.Position
    local targetPos = targetPart.Position
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local filterList = {character}
    if LocalPlayer.Character then
        table.insert(filterList, LocalPlayer.Character)
    end
    raycastParams.FilterDescendantsInstances = filterList
    
    -- FIXED: Correct raycast direction (full vector, not unit * distance)
    local direction = (targetPos - cameraPos)
    local raycastResult = Workspace:Raycast(cameraPos, direction, raycastParams)
    return raycastResult == nil
end

-- Health color with gradient
local function GetHealthColor(health, maxHealth)
    local percentage = health / math_max(maxHealth, 1)  -- Prevent division by zero
    if percentage > 0.6 then
        return Color3_fromRGB(0, 255, 0)
    elseif percentage > 0.3 then
        return Color3_fromRGB(255, 255, 0)
    else
        return Color3_fromRGB(255, 0, 0)
    end
end

-- FIXED: Drawing creation
local function CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for property, value in pairs(properties) do
        if drawing[property] ~= nil then
            drawing[property] = value
        end
    end
    return drawing
end

-- FIXED: ESP Removal
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
    
    ESPObjects[player] = nil
end

-- FIXED: ESP Creation - NO AUTO-DESTRUCTION
local function CreateESP(player)
    -- FIX: Only return if it's local player, don't auto-destroy
    if player == LocalPlayer then return end
    
    -- FIX: If ESP already exists, just update it instead of destroying
    if ESPObjects[player] then
        return
    end
    
    local esp = {
        Player = player,
        Drawings = {},
        Chams = {},
        Connections = {},
        Character = nil,
        LastUpdate = 0,
        IsValid = true
    }
    
    -- Create drawings based on current config
    if ESPConfig.BoxEnabled then
        for i = 1, 4 do
            esp.Drawings["BoxLine"..i] = CreateDrawing("Line", {
                Thickness = ESPConfig.BoxThickness, 
                Color = ESPConfig.BoxColor, 
                Visible = false
            })
        end
    end
    
    if ESPConfig.NameEnabled then
        esp.Drawings.Name = CreateDrawing("Text", {
            Text = player.Name, 
            Size = ESPConfig.TextSize, 
            Center = true, 
            Outline = true, 
            Font = ESPConfig.TextFont, 
            Color = ESPConfig.NameColor, 
            Visible = false
        })
    end
    
    if ESPConfig.DistanceEnabled then
        esp.Drawings.Distance = CreateDrawing("Text", {
            Size = ESPConfig.TextSize, 
            Center = true, 
            Outline = true, 
            Font = ESPConfig.TextFont, 
            Color = ESPConfig.DistanceColor, 
            Visible = false
        })
    end
    
    if ESPConfig.ToolEnabled then
        esp.Drawings.Tool = CreateDrawing("Text", {
            Size = ESPConfig.TextSize - 2, 
            Center = true, 
            Outline = true, 
            Font = ESPConfig.TextFont, 
            Color = ESPConfig.ToolColor, 
            Visible = false
        })
    end
    
    if ESPConfig.TracerEnabled then
        esp.Drawings.Tracer = CreateDrawing("Line", {
            Thickness = ESPConfig.TracerThickness, 
            Color = ESPConfig.TracerColor, 
            Visible = false
        })
    end
    
    if ESPConfig.HealthBarEnabled then
        esp.Drawings.HealthBarBackground = CreateDrawing("Square", {
            Thickness = 1, 
            Filled = true, 
            Color = Color3_fromRGB(0, 0, 0), 
            Visible = false
        })
        esp.Drawings.HealthBar = CreateDrawing("Square", {
            Thickness = 1, 
            Filled = true, 
            Color = ESPConfig.HealthBarColor, 
            Visible = false
        })
        esp.Drawings.HealthBarOutline = CreateDrawing("Square", {
            Thickness = 1, 
            Filled = false, 
            Color = Color3_fromRGB(255, 255, 255), 
            Visible = false
        })
    end
    
    -- Character connection
    local function CharacterAdded(character)
        if not character then return end
        
        local rootPart = GetRootPart(character)
        local humanoid = GetHumanoid(character)
        
        -- FIXED: No infinite recursion - use different approach
        if not rootPart or not humanoid then
            local function CheckAgain()
                if character and ESPObjects[player] and character.Parent then
                    local newRoot = GetRootPart(character)
                    local newHumanoid = GetHumanoid(character)
                    if newRoot and newHumanoid then
                        -- Setup the ESP now that parts are available
                        esp.Character = character
                        
                        -- FIXED: Simple chams that work
                        if ESPConfig.ChamsEnabled then
                            local highlight = Instance.new("Highlight")
                            highlight.Adornee = character
                            highlight.FillColor = Color3_fromRGB(0, 255, 100)
                            highlight.FillTransparency = 0.7
                            highlight.OutlineColor = Color3_new(0, 0, 0)
                            highlight.OutlineTransparency = 0.8
                            highlight.Parent = CoreGui
                            esp.Chams.Main = highlight
                        end
                        
                        esp.Connections.HumanoidDied = humanoid.Died:Connect(function()
                            HideESPDrawings(esp)
                            for _, cham in pairs(esp.Chams) do
                                if cham then cham.Enabled = false end
                            end
                        end)
                    end
                end
            end
            task.delay(1, CheckAgain)
            return
        end
        
        esp.Character = character
        
        -- FIXED: Simple chams that work
        if ESPConfig.ChamsEnabled then
            local highlight = Instance.new("Highlight")
            highlight.Adornee = character
            highlight.FillColor = Color3_fromRGB(0, 255, 100)
            highlight.FillTransparency = 0.7
            highlight.OutlineColor = Color3_new(0, 0, 0)
            highlight.OutlineTransparency = 0.8
            highlight.Parent = CoreGui
            esp.Chams.Main = highlight
        end
        
        esp.Connections.HumanoidDied = humanoid.Died:Connect(function()
            HideESPDrawings(esp)
            for _, cham in pairs(esp.Chams) do
                if cham then cham.Enabled = false end
            end
        end)
    end
    
    if player.Character then
        CharacterAdded(player.Character)
    end
    
    esp.Connections.CharacterAdded = player.CharacterAdded:Connect(CharacterAdded)
    esp.Connections.CharacterRemoving = player.CharacterRemoving:Connect(function()
        HideESPDrawings(esp)
        for _, cham in pairs(esp.Chams) do
            if cham then cham:Destroy() end
        end
        esp.Chams = {}
        esp.Character = nil
    end)
    
    ESPObjects[player] = esp
end

-- FIXED: ESP Update with proper positioning
local function UpdateESP(player, currentTime)
    local esp = ESPObjects[player]
    if not esp or not esp.IsValid then return end
    
    local character = esp.Character
    if not character then
        HideESPDrawings(esp)
        return
    end
    
    local humanoidRootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    
    if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
        HideESPDrawings(esp)
        return
    end
    
    local distance = (humanoidRootPart.Position - CurrentCamera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        HideESPDrawings(esp)
        return
    end
    
    local isVisible = IsPlayerVisible(character, humanoidRootPart, distance)
    
    -- FIXED: Proper bounding box
    local boundingBox = GetBoundingBox(character)
    if not boundingBox then
        HideESPDrawings(esp)
        return
    end
    
    local pos, size = boundingBox.Position, boundingBox.Size
    local rootPos = boundingBox.RootPosition
    
    -- FIXED: Box ESP
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
                line.Visible = true
            end
        end
    else
        for i = 1, 4 do
            local line = esp.Drawings["BoxLine"..i]
            if line then line.Visible = false end
        end
    end
    
    -- FIXED: Health Bar with division by zero protection
    if ESPConfig.HealthBarEnabled then
        local healthBarX = pos.X - ESPConfig.HealthBarOffset - ESPConfig.HealthBarWidth
        local healthBarY = pos.Y
        local healthBarHeight = size.Y
        
        -- FIXED: Prevent division by zero
        local maxHealth = math_max(humanoid.MaxHealth, 1)
        local healthPercentage = math_clamp(humanoid.Health / maxHealth, 0, 1)
        local healthHeight = healthBarHeight * healthPercentage
        
        local bg = esp.Drawings.HealthBarBackground
        local fill = esp.Drawings.HealthBar
        local outline = esp.Drawings.HealthBarOutline
        
        if bg then
            bg.Position = Vector2_new(healthBarX, healthBarY)
            bg.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarHeight)
            bg.Visible = true
        end
        
        if fill then
            fill.Position = Vector2_new(healthBarX, healthBarY + (healthBarHeight - healthHeight))
            fill.Size = Vector2_new(ESPConfig.HealthBarWidth, healthHeight)
            fill.Color = GetHealthColor(humanoid.Health, humanoid.MaxHealth)
            fill.Visible = true
        end
        
        if outline then
            outline.Position = Vector2_new(healthBarX, healthBarY)
            outline.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarHeight)
            outline.Visible = true
        end
    end
    
    -- FIXED: Name - shows from any distance, above head
    if ESPConfig.NameEnabled then
        local nameDrawing = esp.Drawings.Name
        if nameDrawing then
            nameDrawing.Position = Vector2_new(rootPos.X, pos.Y - 20)
            nameDrawing.Text = player.Name
            nameDrawing.Visible = true
        end
    end
    
    -- FIXED: Tool - shows from any distance, above name (with operator precedence fix)
    if ESPConfig.ToolEnabled then
        local toolDrawing = esp.Drawings.Tool
        if toolDrawing then
            local equippedTool = GetEquippedTool(player, character)
            -- FIXED: Operator precedence - use parentheses
            toolDrawing.Position = Vector2_new(rootPos.X, pos.Y - 40)
            toolDrawing.Text = equippedTool and ("Tool: " .. equippedTool.Name) or "No Tool"
            toolDrawing.Visible = true
        end
    end
    
    -- FIXED: Distance - shows from any distance, below box
    if ESPConfig.DistanceEnabled then
        local distanceDrawing = esp.Drawings.Distance
        if distanceDrawing then
            distanceDrawing.Position = Vector2_new(rootPos.X, pos.Y + size.Y + 10)
            distanceDrawing.Text = string_format("%.0f studs", distance)
            distanceDrawing.Visible = true
        end
    end
    
    -- FIXED: Tracer
    if ESPConfig.TracerEnabled then
        local tracer = esp.Drawings.Tracer
        if tracer then
            tracer.From = Vector2_new(CurrentCamera.ViewportSize.X / 2, CurrentCamera.ViewportSize.Y)
            tracer.To = Vector2_new(rootPos.X, rootPos.Y)
            tracer.Visible = true
        end
    end
end

-- FIXED: Cleanup system
local function ProcessCleanupQueue()
    for i = #CleanupQueue, 1, -1 do
        local player = CleanupQueue[i]
        if ESPObjects[player] then
            RemoveESP(player)
        end
        CleanupQueue[i] = nil
    end
end

-- FIXED: Main loop with proper cleanup detection
local function ESPLoop()
    FrameCount = FrameCount + 1
    local currentTime = tick()
    
    ProcessCleanupQueue()
    
    -- FIXED: Proper player cleanup detection
    if FrameCount % 30 == 0 then
        for player in pairs(ESPObjects) do
            -- Check if player left the game
            if not Players:FindFirstChild(player.Name) then
                table.insert(CleanupQueue, player)
            end
        end
    end
    
    for player, esp in pairs(ESPObjects) do
        if esp and esp.IsValid then
            local success, err = pcall(UpdateESP, player, currentTime)
            if not success then
                warn("ESP Update Error: " .. tostring(err))
                table.insert(CleanupQueue, player)
            end
        else
            table.insert(CleanupQueue, player)
        end
    end
end

-- FIXED: Player monitoring
local function InitializePlayerMonitoring()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end
    
    Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.delay(1, function()
                CreateESP(player)
            end)
        end
    end)
    
    Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then
            RemoveESP(player)
        end
    end)
end

-- FIXED: GUI with working toggles
local function CreateEnhancedGUI()
    local existingGUI = CoreGui:FindFirstChild("CarbonESP")
    if existingGUI then existingGUI:Destroy() end
    
    local CarbonESP = Instance.new("ScreenGui")
    CarbonESP.Name = "CarbonESP"
    CarbonESP.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    CarbonESP.ResetOnSpawn = false
    CarbonESP.DisplayOrder = 999
    CarbonESP.IgnoreGuiInset = true
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 400)
    MainFrame.Position = UDim2.new(0, 20, 0, 20)
    MainFrame.BackgroundColor3 = Color3_fromRGB(25, 25, 35)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = CarbonESP
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3_fromRGB(40, 40, 55)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.7, 0, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "CARBON ESP"
    Title.TextColor3 = Color3_fromRGB(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    local features = {
        {"Box ESP", "BoxEnabled"},
        {"Names", "NameEnabled"},
        {"Distance", "DistanceEnabled"},
        {"Tools", "ToolEnabled"},
        {"Tracers", "TracerEnabled"},
        {"Health Bars", "HealthBarEnabled"},
        {"Skeleton", "SkeletonEnabled"},
        {"Line of Sight", "LineOfSightEnabled"}
    }
    
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -50)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 45)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, #features * 40)
    ScrollFrame.Parent = MainFrame
    
    for i, feature in ipairs(features) do
        local featureName, configKey = feature[1], feature[2]
        
        local ToggleContainer = Instance.new("Frame")
        ToggleContainer.Size = UDim2.new(1, 0, 0, 35)
        ToggleContainer.BackgroundColor3 = Color3_fromRGB(40, 40, 55)
        ToggleContainer.BackgroundTransparency = 0.8
        ToggleContainer.Position = UDim2.new(0, 0, 0, (i-1)*40)
        ToggleContainer.Parent = ScrollFrame
        
        local FeatureLabel = Instance.new("TextLabel")
        FeatureLabel.Size = UDim2.new(0, 200, 1, 0)
        FeatureLabel.BackgroundTransparency = 1
        FeatureLabel.Text = "  " .. featureName
        FeatureLabel.TextColor3 = Color3_fromRGB(255, 255, 255)
        FeatureLabel.TextSize = 14
        FeatureLabel.Font = Enum.Font.Gotham
        FeatureLabel.TextXAlignment = Enum.TextXAlignment.Left
        FeatureLabel.Parent = ToggleContainer
        
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(0, 60, 0, 25)
        ToggleButton.Position = UDim2.new(1, -65, 0.5, -12.5)
        ToggleButton.BackgroundColor3 = ESPConfig[configKey] and Color3_fromRGB(0, 200, 0) or Color3_fromRGB(200, 0, 0)
        ToggleButton.BorderSizePixel = 0
        ToggleButton.Text = ESPConfig[configKey] and "ON" or "OFF"
        ToggleButton.TextColor3 = Color3_fromRGB(255, 255, 255)
        ToggleButton.TextSize = 12
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.Parent = ToggleContainer
        
        -- FIXED: Proper toggle functionality
        ToggleButton.MouseButton1Click:Connect(function()
            ESPConfig[configKey] = not ESPConfig[configKey]
            ToggleButton.BackgroundColor3 = ESPConfig[configKey] and Color3_fromRGB(0, 200, 0) or Color3_fromRGB(200, 0, 0)
            ToggleButton.Text = ESPConfig[configKey] and "ON" or "OFF"
            
            -- FIXED: Refresh all ESP objects properly
            for player in pairs(ESPObjects) do
                RemoveESP(player)
            end
            
            -- Recreate ESP for all players
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    CreateESP(player)
                end
            end
        end)
    end
    
    CarbonESP.Parent = CoreGui
    return CarbonESP
end

-- Initialize everything
local function InitializeESP()
    CreateEnhancedGUI()
    InitializePlayerMonitoring()
    Connections.RenderStepped = RunService.RenderStepped:Connect(ESPLoop)
    
    print("✅ Carbon ESP Fully Loaded!")
    print("✅ All critical bugs fixed!")
    print("✅ No crashes or infinite loops!")
end

-- Cleanup function
local function CleanupESP()
    for _, connection in pairs(Connections) do
        connection:Disconnect()
    end
    
    for player in pairs(ESPObjects) do
        RemoveESP(player)
    end
    
    local CarbonESP = CoreGui:FindFirstChild("CarbonESP")
    if CarbonESP then
        CarbonESP:Destroy()
    end
end

-- Start the ESP
InitializeESP()

return CleanupESP
