-- Carbon's Universal ESP - Fixed & Hardened Version
-- Merged fixes: bounding box, safe creation, stable GUI toggles, chams, tool detection, and protected update loop

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
local tick = tick

-- ESP configuration
local ESPConfig = {
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

    UpdateRate = 30,          -- updates per second per ESP object (not per frame)
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
    ChamsColor = Color3_fromRGB(0, 255, 100),
    LineOfSightColor = Color3_fromRGB(255, 50, 150),

    BoxThickness = 1,
    TracerThickness = 1,
    SkeletonThickness = 1,
    HealthBarWidth = 6,
    HealthBarOffset = 12,
    LineOfSightThickness = 2,

    TextSize = 14,
    TextFont = Enum.Font.Gotham
}

-- Globals
local ESPObjects = {}   -- player -> esp data
local Connections = {}  -- general connections
local LastUpdate = 0
local FrameCount = 0
local CleanupQueue = {}
local RenderConnection = nil

-- Utility: protected Drawing creation
local function SafeCreateDrawing(kind, props)
    local ok, draw = pcall(function() return Drawing.new(kind) end)
    if not ok or not draw then return nil end
    if props then
        for k, v in pairs(props) do
            pcall(function()
                draw[k] = v
            end)
        end
    end
    return draw
end

-- Safe humanoid / root part getters
local function GetHumanoid(character)
    if not character or not character:IsDescendantOf(game) then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(character)
    if not character or not character:IsDescendantOf(game) then return nil end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
end

-- Stable bounding box: distance-scaled, positive sizes, safe checks
local function GetBoundingBox(character)
    if not character or not character:IsDescendantOf(Workspace) then return nil end
    local hrp = GetRootPart(character)
    if not hrp then return nil end

    local viewportPos, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
    if not onScreen or viewportPos.Z <= 0 then
        return nil
    end

    -- distance scale (empirical)
    local distance = (CurrentCamera.CFrame.Position - hrp.Position).Magnitude
    local scale = math_clamp(distance / 28, 0.5, 12) -- clamp to safe range

    -- default character proportions (works reliably)
    local boxHeight = 5 * scale     -- world units scaled
    local boxWidth = 2 * scale

    -- convert height/width in screen space approx (using viewport zoom)
    local screenHeight = boxHeight * (CurrentCamera.ViewportSize.Y / (40 * scale))
    local screenWidth = boxWidth * (CurrentCamera.ViewportSize.X / (40 * scale))

    -- guarantee minimum sizes
    screenHeight = math_max(24, screenHeight)
    screenWidth = math_max(10, screenWidth)

    return {
        Position = Vector2_new(viewportPos.X - screenWidth / 2, viewportPos.Y - screenHeight / 2),
        Size = Vector2_new(screenWidth, screenHeight),
        RootPosition = Vector2_new(viewportPos.X, viewportPos.Y)
    }
end

-- Visibility check using Raycast (safe)
local function IsPlayerVisible(character, targetPart, distance)
    if not ESPConfig.VisibilityCheck then return true end
    if not character or not targetPart then return false end
    if distance > ESPConfig.LODDistance then return true -- LOD: skip expensive raycast
    local cameraPos = CurrentCamera.CFrame.Position
    if (cameraPos - targetPart.Position).Magnitude > ESPConfig.MaxDistance then return false
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {character, CurrentCamera, LocalPlayer.Character}
    local result = Workspace:Raycast(cameraPos, (targetPart.Position - cameraPos), params)
    return result == nil
end

-- Color getters
local function GetElementColor(elementType, isVisible)
    if not isVisible then return Color3_fromRGB(255, 255, 0) end
    if elementType == "Box" then return ESPConfig.BoxColor end
    if elementType == "Tracer" then return ESPConfig.TracerColor end
    if elementType == "Name" then return ESPConfig.NameColor end
    if elementType == "Distance" then return ESPConfig.DistanceColor end
    if elementType == "Tool" then return ESPConfig.ToolColor end
    if elementType == "Skeleton" then return ESPConfig.SkeletonColor end
    if elementType == "HealthBar" then return ESPConfig.HealthBarColor end
    if elementType == "LineOfSight" then return ESPConfig.LineOfSightColor end
    return ESPConfig.BoxColor
end

-- Health color
local function GetHealthColor(health, maxHealth)
    local percentage = 0
    if maxHealth and maxHealth > 0 then percentage = health / maxHealth end
    if percentage > 0.6 then return Color3_fromRGB(0, 255, 0)
    elseif percentage > 0.3 then return Color3_fromRGB(255, 255, 0)
    else return Color3_fromRGB(255, 0, 0) end
end

-- Remove all ESP data for player
local function RemoveESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    esp.IsValid = false

    -- disconnect connections
    for _, c in pairs(esp.Connections or {}) do
        if c and c.Disconnect then
            pcall(function() c:Disconnect() end)
        end
    end

    -- remove drawings
    for _, d in pairs(esp.Drawings or {}) do
        if d then
            pcall(function() d:Remove() end)
        end
    end

    -- destroy highlight if exists
    if esp.Highlight and esp.Highlight.Destroy then
        pcall(function() esp.Highlight:Destroy() end)
    end

    ESPObjects[player] = nil
end

-- Create ESP for a player (safe)
local function CreateESP(player)
    if not player or player == LocalPlayer or ESPObjects[player] then return end

    local esp = {
        Player = player,
        Drawings = {},
        Connections = {},
        Character = nil,
        LastUpdate = 0,
        IsValid = true,
        Highlight = nil
    }

    -- helper create drawing with default props
    local function createIfAllowed(name, kind, props)
        local d = esp.Drawings[name]
        if d and d.Remove == nil then -- not a drawing (safety)
            d = nil
        end
        if not d then
            local success, created = pcall(SafeCreateDrawing, kind, props)
            if success and created then
                esp.Drawings[name] = created
            end
        end
    end

    -- Prepare drawing templates but only create what's enabled
    if ESPConfig.BoxEnabled then
        for i = 1, 4 do
            createIfAllowed("BoxLine"..i, "Line", {Thickness = ESPConfig.BoxThickness, Color = ESPConfig.BoxColor, Visible = false})
        end
    end

    if ESPConfig.TracerEnabled then
        createIfAllowed("Tracer", "Line", {Thickness = ESPConfig.TracerThickness, Color = ESPConfig.TracerColor, Visible = false})
    end

    if ESPConfig.NameEnabled then
        createIfAllowed("Name", "Text", {Text = player.Name, Size = ESPConfig.TextSize, Center = true, Outline = true, Font = ESPConfig.TextFont, Color = ESPConfig.NameColor, Visible = false})
    end

    if ESPConfig.DistanceEnabled then
        createIfAllowed("Distance", "Text", {Text = "", Size = ESPConfig.TextSize, Center = true, Outline = true, Font = ESPConfig.TextFont, Color = ESPConfig.DistanceColor, Visible = false})
    end

    if ESPConfig.ToolEnabled then
        createIfAllowed("Tool", "Text", {Text = "", Size = math_max(10, ESPConfig.TextSize - 2), Center = true, Outline = true, Font = ESPConfig.TextFont, Color = ESPConfig.ToolColor, Visible = false})
    end

    if ESPConfig.HealthBarEnabled then
        createIfAllowed("HealthBarBackground", "Square", {Thickness = 1, Filled = true, Color = Color3_fromRGB(0,0,0), Visible = false})
        createIfAllowed("HealthBar", "Square", {Thickness = 1, Filled = true, Color = ESPConfig.HealthBarColor, Visible = false})
        createIfAllowed("HealthBarOutline", "Square", {Thickness = 1, Filled = false, Color = Color3_fromRGB(255,255,255), Visible = false})
    end

    if ESPConfig.SkeletonEnabled then
        for i = 1, # ( {
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
        } ) do
            createIfAllowed("Bone_"..i, "Line", {Thickness = ESPConfig.SkeletonThickness, Color = ESPConfig.SkeletonColor, Visible = false})
        end
    end

    if ESPConfig.LineOfSightEnabled then
        createIfAllowed("LineOfSight", "Line", {Thickness = ESPConfig.LineOfSightThickness, Color = ESPConfig.LineOfSightColor, Visible = false})
        createIfAllowed("LineOfSightArrow1", "Line", {Thickness = ESPConfig.LineOfSightThickness, Color = ESPConfig.LineOfSightColor, Visible = false})
        createIfAllowed("LineOfSightArrow2", "Line", {Thickness = ESPConfig.LineOfSightThickness, Color = ESPConfig.LineOfSightColor, Visible = false})
    end

    ESPObjects[player] = esp

    -- Character added handling
    local function CharacterAdded(character)
        if not character or not character:IsDescendantOf(game) then return end

        local rootPart = GetRootPart(character)
        local humanoid = GetHumanoid(character)

        -- Wait for root/humanoid if necessary (safe retry)
        if not rootPart or not humanoid then
            task.delay(0.7, function()
                if character and character:IsDescendantOf(Workspace) and ESPObjects[player] then
                    CharacterAdded(character)
                end
            end)
            return
        end

        esp.Character = character

        -- highlight/adorn whole character if chams enabled
        if ESPConfig.ChamsEnabled then
            if esp.Highlight and esp.Highlight.Destroy then
                pcall(function() esp.Highlight:Destroy() end)
            end
            local ok, highlight = pcall(function()
                local h = Instance.new("Highlight")
                h.Adornee = character
                h.FillColor = ESPConfig.ChamsColor
                h.FillTransparency = 0.5
                h.OutlineTransparency = 0.8
                h.Parent = CoreGui
                return h
            end)
            if ok then esp.Highlight = highlight end
        end

        -- humanoid death handler
        esp.Connections.HumanoidDied = humanoid.Died:Connect(function()
            for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
            if esp.Highlight and esp.Highlight.Enabled ~= nil then pcall(function() esp.Highlight.Enabled = false end) end
        end)
    end

    -- Attach initial character if present
    if player.Character and player.Character:IsDescendantOf(Workspace) then
        pcall(CharacterAdded, player.Character)
    end

    -- Connections to update on character spawn/remove
    esp.Connections.CharacterAdded = player.CharacterAdded:Connect(function(c)
        pcall(function() CharacterAdded(c) end)
    end)
    esp.Connections.CharacterRemoving = player.CharacterRemoving:Connect(function()
        for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
        if esp.Highlight and esp.Highlight.Destroy then pcall(function() esp.Highlight:Destroy() end) end
        esp.Highlight = nil
        esp.Character = nil
    end)
end

-- Update function for a single player's ESP (safe, robust)
local function UpdateESP(player, currentTime)
    local esp = ESPObjects[player]
    if not esp or not esp.IsValid then
        table.insert(CleanupQueue, player)
        return
    end

    -- Rate limit per ESP
    if currentTime - esp.LastUpdate < (1 / math_max(ESPConfig.UpdateRate, 1)) then return end
    esp.LastUpdate = currentTime

    local character = esp.Character
    if not character or not character:IsDescendantOf(Workspace) then
        for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
        if esp.Highlight and esp.Highlight.Enabled ~= nil then pcall(function() esp.Highlight.Enabled = false end) end
        return
    end

    local humanoidRootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    if not humanoidRootPart or not humanoid then
        for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
        if esp.Highlight and esp.Highlight.Enabled ~= nil then pcall(function() esp.Highlight.Enabled = false end) end
        return
    end

    if humanoid.Health <= 0 then
        for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
        if esp.Highlight and esp.Highlight.Enabled ~= nil then pcall(function() esp.Highlight.Enabled = false end) end
        return
    end

    local distance = (humanoidRootPart.Position - CurrentCamera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
        if esp.Highlight and esp.Highlight.Enabled ~= nil then pcall(function() esp.Highlight.Enabled = false end) end
        return
    end

    local isVisible = IsPlayerVisible(character, humanoidRootPart, distance)
    if esp.Highlight and esp.Highlight.FillTransparency ~= nil then
        pcall(function() esp.Highlight.Enabled = ESPConfig.ChamsEnabled and isVisible end)
    end

    local boundingBox = GetBoundingBox(character)
    local onScreen = boundingBox ~= nil

    if onScreen then
        local pos, size = boundingBox.Position, boundingBox.Size
        local rootPos = boundingBox.RootPosition

        -- Box
        if ESPConfig.BoxEnabled then
            local lines = {
                {Vector2_new(pos.X, pos.Y), Vector2_new(pos.X + size.X, pos.Y)},
                {Vector2_new(pos.X, pos.Y), Vector2_new(pos.X, pos.Y + size.Y)},
                {Vector2_new(pos.X + size.X, pos.Y), Vector2_new(pos.X + size.X, pos.Y + size.Y)},
                {Vector2_new(pos.X, pos.Y + size.Y), Vector2_new(pos.X + size.X, pos.Y + size.Y)}
            }
            for i = 1, 4 do
                local line = esp.Drawings["BoxLine"..i]
                if line then
                    pcall(function()
                        line.From = lines[i][1]
                        line.To = lines[i][2]
                        line.Color = GetElementColor("Box", isVisible)
                        line.Visible = true
                    end)
                end
            end
        else
            for i = 1, 4 do local l = esp.Drawings["BoxLine"..i] if l then pcall(function() l.Visible = false end) end end
        end

        -- Health bar
        if ESPConfig.HealthBarEnabled then
            local healthPct = math_clamp(humanoid.Health / math_max(humanoid.MaxHealth, 1), 0, 1)
            local healthBarX = pos.X - ESPConfig.HealthBarOffset - ESPConfig.HealthBarWidth
            local healthBarY = pos.Y
            local healthBarH = size.Y
            local bg = esp.Drawings.HealthBarBackground
            local fill = esp.Drawings.HealthBar
            local outline = esp.Drawings.HealthBarOutline
            pcall(function()
                if bg then
                    bg.Position = Vector2_new(healthBarX, healthBarY)
                    bg.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarH)
                    bg.Visible = true
                end
                if fill then
                    local fillH = healthBarH * healthPct
                    fill.Position = Vector2_new(healthBarX, healthBarY + (healthBarH - fillH))
                    fill.Size = Vector2_new(ESPConfig.HealthBarWidth, fillH)
                    fill.Color = GetHealthColor(humanoid.Health, humanoid.MaxHealth)
                    fill.Visible = true
                end
                if outline then
                    outline.Position = Vector2_new(healthBarX, healthBarY)
                    outline.Size = Vector2_new(ESPConfig.HealthBarWidth, healthBarH)
                    outline.Visible = true
                end
            end)
        else
            for _, k in ipairs({"HealthBarBackground","HealthBar","HealthBarOutline"}) do local d=esp.Drawings[k] if d then pcall(function() d.Visible=false end) end end
        end

        -- Name
        if ESPConfig.NameEnabled then
            local nameD = esp.Drawings.Name
            if nameD then
                -- find head for nicer offset if exists
                local head = character:FindFirstChild("Head")
                if head then
                    local headScreen, headOn = CurrentCamera:WorldToViewportPoint(head.Position)
                    if headOn and headScreen.Z > 0 then
                        pcall(function()
                            nameD.Position = Vector2_new(headScreen.X, headScreen.Y - 25)
                            nameD.Text = player.Name
                            nameD.Color = GetElementColor("Name", isVisible)
                            nameD.Visible = true
                        end)
                    else
                        pcall(function() nameD.Visible = false end)
                    end
                else
                    pcall(function()
                        nameD.Position = Vector2_new(rootPos.X, rootPos.Y - 25)
                        nameD.Text = player.Name
                        nameD.Color = GetElementColor("Name", isVisible)
                        nameD.Visible = true
                    end)
                end
            end
        else
            if esp.Drawings.Name then pcall(function() esp.Drawings.Name.Visible = false end) end
        end

        -- Tool
        if ESPConfig.ToolEnabled then
            local toolD = esp.Drawings.Tool
            if toolD then
                local head = character:FindFirstChild("Head")
                local headScreen, headOn = head and CurrentCamera:WorldToViewportPoint(head.Position) or nil, false
                if head then headScreen, headOn = CurrentCamera:WorldToViewportPoint(head.Position) end
                if headOn and headScreen and headScreen.Z > 0 then
                    -- improved tool detection: check character, then backpack
                    local equippedTool = nil
                    for _, v in pairs(character:GetChildren()) do
                        if v:IsA("Tool") then equippedTool = v break end
                    end
                    if not equippedTool and player:FindFirstChild("Backpack") then
                        for _, v in pairs(player.Backpack:GetChildren()) do
                            if v:IsA("Tool") then equippedTool = v break end
                        end
                    end
                    pcall(function()
                        toolD.Position = Vector2_new(headScreen.X, headScreen.Y - 45)
                        toolD.Text = equippedTool and ("Tool: " .. tostring(equippedTool.Name)) or "No Tool"
                        toolD.Color = GetElementColor("Tool", isVisible)
                        toolD.Visible = true
                    end)
                else
                    pcall(function() toolD.Visible = false end)
                end
            end
        else
            if esp.Drawings.Tool then pcall(function() esp.Drawings.Tool.Visible = false end) end
        end

        -- Distance
        if ESPConfig.DistanceEnabled then
            local distD = esp.Drawings.Distance
            if distD then
                local rootScreen, rootOn = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                if rootOn and rootScreen and rootScreen.Z > 0 then
                    pcall(function()
                        distD.Position = Vector2_new(rootScreen.X, pos.Y + size.Y + 10)
                        distD.Text = string_format("%.0f studs", distance)
                        distD.Color = GetElementColor("Distance", isVisible)
                        distD.Visible = true
                    end)
                else
                    pcall(function() distD.Visible = false end)
                end
            end
        else
            if esp.Drawings.Distance then pcall(function() esp.Drawings.Distance.Visible = false end) end
        end

        -- Tracer
        if ESPConfig.TracerEnabled then
            local tracer = esp.Drawings.Tracer
            if tracer then
                local rootScreen, rootOn = CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                if rootOn and rootScreen and rootScreen.Z > 0 then
                    pcall(function()
                        tracer.From = Vector2_new(CurrentCamera.ViewportSize.X / 2, CurrentCamera.ViewportSize.Y)
                        tracer.To = Vector2_new(rootScreen.X, rootScreen.Y)
                        tracer.Color = GetElementColor("Tracer", isVisible)
                        tracer.Visible = true
                    end)
                else
                    pcall(function() tracer.Visible = false end)
                end
            end
        else
            if esp.Drawings.Tracer then pcall(function() esp.Drawings.Tracer.Visible = false end) end
        end

        -- Skeleton (using safe bone list)
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
        if ESPConfig.SkeletonEnabled and distance <= ESPConfig.LODDistance then
            for i, conn in ipairs(BONE_CONNECTIONS) do
                local boneLine = esp.Drawings["Bone_"..i]
                if boneLine then
                    local part1 = character:FindFirstChild(conn[1])
                    local part2 = character:FindFirstChild(conn[2])
                    if part1 and part2 and part1:IsA("BasePart") and part2:IsA("BasePart") then
                        local p1, o1 = CurrentCamera:WorldToViewportPoint(part1.Position)
                        local p2, o2 = CurrentCamera:WorldToViewportPoint(part2.Position)
                        if o1 and o2 and p1.Z > 0 and p2.Z > 0 then
                            pcall(function()
                                boneLine.From = Vector2_new(p1.X, p1.Y)
                                boneLine.To = Vector2_new(p2.X, p2.Y)
                                boneLine.Color = GetElementColor("Skeleton", isVisible)
                                boneLine.Visible = true
                            end)
                        else
                            pcall(function() boneLine.Visible = false end)
                        end
                    else
                        pcall(function() boneLine.Visible = false end)
                    end
                end
            end
        else
            for i = 1, #BONE_CONNECTIONS do local b = esp.Drawings["Bone_"..i] if b then pcall(function() b.Visible = false end) end end
        end

        -- Line of Sight
        if ESPConfig.LineOfSightEnabled and distance <= ESPConfig.LODDistance then
            local head = character:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                local startP = head.Position
                local dir = head.CFrame.LookVector
                local endP = startP + dir * ESPConfig.LineOfSightDistance
                local startS, sOn = CurrentCamera:WorldToViewportPoint(startP)
                local endS, eOn = CurrentCamera:WorldToViewportPoint(endP)
                if sOn and eOn and startS.Z > 0 and endS.Z > 0 then
                    local startV = Vector2_new(startS.X, startS.Y)
                    local endV = Vector2_new(endS.X, endS.Y)
                    local losLine = esp.Drawings.LineOfSight
                    if losLine then pcall(function() losLine.From = startV losLine.To = endV losLine.Color = GetElementColor("LineOfSight", isVisible) losLine.Visible = true end) end

                    local arrowSize = 10
                    local direction = (endV - startV).Unit
                    local perp = Vector2_new(-direction.Y, direction.X)
                    local a1, a2 = esp.Drawings.LineOfSightArrow1, esp.Drawings.LineOfSightArrow2
                    if a1 and a2 then
                        pcall(function()
                            a1.From = endV
                            a1.To = endV - (direction * arrowSize) + (perp * arrowSize * 0.5)
                            a1.Color = GetElementColor("LineOfSight", isVisible)
                            a1.Visible = true

                            a2.From = endV
                            a2.To = endV - (direction * arrowSize) - (perp * arrowSize * 0.5)
                            a2.Color = GetElementColor("LineOfSight", isVisible)
                            a2.Visible = true
                        end)
                    end
                else
                    if esp.Drawings.LineOfSight then pcall(function() esp.Drawings.LineOfSight.Visible = false end) end
                    if esp.Drawings.LineOfSightArrow1 then pcall(function() esp.Drawings.LineOfSightArrow1.Visible = false end) end
                    if esp.Drawings.LineOfSightArrow2 then pcall(function() esp.Drawings.LineOfSightArrow2.Visible = false end) end
                end
            end
        else
            if esp.Drawings.LineOfSight then pcall(function() esp.Drawings.LineOfSight.Visible = false end) end
            if esp.Drawings.LineOfSightArrow1 then pcall(function() esp.Drawings.LineOfSightArrow1.Visible = false end) end
            if esp.Drawings.LineOfSightArrow2 then pcall(function() esp.Drawings.LineOfSightArrow2.Visible = false end) end
        end

    else
        -- off-screen: hide everything
        for _, d in pairs(esp.Drawings) do if d then pcall(function() d.Visible = false end) end end
        if esp.Highlight and esp.Highlight.Enabled ~= nil then pcall(function() esp.Highlight.Enabled = false end) end
    end
end

-- Process cleanup queue safely
local function ProcessCleanupQueue()
    for i = #CleanupQueue, 1, -1 do
        local p = CleanupQueue[i]
        if p and ESPObjects[p] then
            RemoveESP(p)
            CleanupQueue[i] = nil
        elseif p then
            CleanupQueue[i] = nil
        end
    end
end

-- Main loop
local function ESPLoop()
    FrameCount = FrameCount + 1
    local currentTime = tick()

    ProcessCleanupQueue()

    -- occasionally remove players that left
    if FrameCount % 60 == 0 then
        for p, _ in pairs(ESPObjects) do
            if not p or not p.Parent then
                table.insert(CleanupQueue, p)
            end
        end
    end

    for player, esp in pairs(ESPObjects) do
        if esp and esp.IsValid then
            local ok, err = pcall(UpdateESP, player, currentTime)
            if not ok then
                warn("ESP Update Error for " .. (player and player.Name or "unknown") .. ": " .. tostring(err))
                table.insert(CleanupQueue, player)
            end
        else
            table.insert(CleanupQueue, player)
        end
    end
end

-- Initialize monitoring: create ESP for all players (except local)
local function InitializePlayerMonitoring()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end

    Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.delay(0.5, function()
                if player:IsDescendantOf(Players) then CreateESP(player) end
            end)
        end
    end)

    Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then RemoveESP(player) end
    end)
end

-- Safely refresh all ESP objects (suspend render loop to avoid mid-frame deletion)
local function RefreshESPAll()
    -- disconnect render loop
    if RenderConnection and RenderConnection.Connected then
        pcall(function() RenderConnection:Disconnect() end)
        RenderConnection = nil
    end

    -- remove all existing ESP objects
    for p, _ in pairs(ESPObjects) do
        pcall(function() RemoveESP(p) end)
    end

    -- recreate
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            pcall(function() CreateESP(player) end)
        end
    end

    -- resume render loop
    RenderConnection = RunService.RenderStepped:Connect(ESPLoop)
end

-- Minimal GUI creation (keeps your original style) and toggles hooked to RefreshESPAll
local function CreateEnhancedGUI()
    -- remove existing
    local existing = CoreGui:FindFirstChild("CarbonESP")
    if existing then existing:Destroy() end

    -- build
    local CarbonESP = Instance.new("ScreenGui")
    CarbonESP.Name = "CarbonESP"
    CarbonESP.ResetOnSpawn = false
    CarbonESP.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 400, 0, 500)
    MainFrame.Position = UDim2.new(0, 20, 0, 20)
    MainFrame.BackgroundColor3 = Color3_fromRGB(25,25,35)
    MainFrame.Parent = CarbonESP

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1,0,0,50)
    TitleBar.BackgroundColor3 = Color3_fromRGB(40,40,55)
    TitleBar.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.7,0,1,0)
    Title.Position = UDim2.new(0,15,0,0)
    Title.BackgroundTransparency = 1
    Title.Text = "CARBON'S ESP v2.0"
    Title.TextColor3 = Color3_fromRGB(240,240,255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Parent = TitleBar

    local HideButton = Instance.new("TextButton")
    HideButton.Size = UDim2.new(0,80,0,30)
    HideButton.Position = UDim2.new(1, -95, 0.5, -15)
    HideButton.BackgroundColor3 = Color3_fromRGB(255,180,0)
    HideButton.Text = "HIDE"
    HideButton.Parent = TitleBar

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -60)
    ScrollFrame.Position = UDim2.new(0,5,0,55)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.Parent = MainFrame

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.Parent = ScrollFrame
    ContentLayout.Padding = UDim.new(0,8)

    local features = {
        {"Box ESP", "BoxEnabled"},
        {"Tracers", "TracerEnabled"},
        {"Names", "NameEnabled"},
        {"Distance", "DistanceEnabled"},
        {"Tools", "ToolEnabled"},
        {"Skeleton", "SkeletonEnabled"},
        {"Health Bars", "HealthBarEnabled"},
        {"Line of Sight", "LineOfSightEnabled"},
        {"Visibility Check", "VisibilityCheck"},
        {"Chams", "ChamsEnabled"}
    }

    for i, feat in ipairs(features) do
        local labelText, key = feat[1], feat[2]

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,36)
        row.BackgroundColor3 = Color3_fromRGB(40,40,55)
        row.Parent = ScrollFrame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0,220,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "  "..labelText
        lbl.TextColor3 = Color3_fromRGB(240,240,255)
        lbl.TextSize = 14
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,70,0,26)
        btn.Position = UDim2.new(1, -80, 0.5, -13)
        btn.Text = ESPConfig[key] and "ON" or "OFF"
        btn.BackgroundColor3 = ESPConfig[key] and Color3_fromRGB(0,230,100) or Color3_fromRGB(255,80,80)
        btn.Parent = row

        btn.MouseButton1Click:Connect(function()
            ESPConfig[key] = not ESPConfig[key]
            btn.Text = ESPConfig[key] and "ON" or "OFF"
            btn.BackgroundColor3 = ESPConfig[key] and Color3_fromRGB(0,230,100) or Color3_fromRGB(255,80,80)
            -- Refresh all ESPs safely
            pcall(function() RefreshESPAll() end)
        end)
    end

    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollFrame.CanvasSize = UDim2.new(0,0,0,ContentLayout.AbsoluteContentSize.Y + 10)
    end)

    HideButton.MouseButton1Click:Connect(function()
        if ScrollFrame.Visible then
            ScrollFrame.Visible = false
            HideButton.Text = "SHOW"
            HideButton.BackgroundColor3 = Color3_fromRGB(0,230,100)
        else
            ScrollFrame.Visible = true
            HideButton.Text = "HIDE"
            HideButton.BackgroundColor3 = Color3_fromRGB(255,180,0)
        end
    end)

    CarbonESP.Parent = CoreGui
    return CarbonESP
end

-- Cleanup routine
local function CleanupESP()
    if RenderConnection and RenderConnection.Connected then
        pcall(function() RenderConnection:Disconnect() end)
        RenderConnection = nil
    end

    for _, c in pairs(Connections) do
        if c and c.Disconnect then pcall(function() c:Disconnect() end) end
    end
    for p, _ in pairs(ESPObjects) do
        pcall(function() RemoveESP(p) end)
    end

    local gui = CoreGui:FindFirstChild("CarbonESP")
    if gui then gui:Destroy() end

    print("🧹 Carbon's ESP cleaned up")
end

-- Initialize everything
local function InitializeESP()
    print("🚀 Initializing Carbon's ESP (fixed)...")
    pcall(CreateEnhancedGUI)
    InitializePlayerMonitoring()
    RenderConnection = RunService.RenderStepped:Connect(ESPLoop)
    print("✅ Carbon's ESP initialized.")
end

-- Start
local ok, err = pcall(InitializeESP)
if not ok then
    warn("ESP Initialization error: " .. tostring(err))
end

-- expose cleanup
return CleanupESP
