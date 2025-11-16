-- ===== SERVICES =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===== PLATFORM DETECTION =====
local IS_MOBILE = UserInputService.TouchEnabled
local IS_DESKTOP = UserInputService.MouseEnabled
local IS_CONSOLE = UserInputService.GamepadEnabled

-- ===== CONFIG =====
local ESPConfig = {
    BoxEnabled=true,
    NameEnabled=true,
    ToolEnabled=true,
    DistanceEnabled=true,
    HealthBarEnabled=true,
    SkeletonEnabled=true,
    ChamsEnabled=true,
    TracersEnabled=true,
    MaxDistance=500,
    BoxColor=Color3.fromRGB(255,0,0),
    NameColor=Color3.fromRGB(255,255,255),
    ToolColor=Color3.fromRGB(255,255,0),
    DistanceColor=Color3.fromRGB(255,255,255),
    HealthBarColor=Color3.fromRGB(0,255,0),
    SkeletonColor=Color3.fromRGB(255,0,0),
    ChamsColor=Color3.fromRGB(255,0,0),
    TracerColor=Color3.fromRGB(255,255,255),
    LineOfSightEnabled=true,
    LineColor=Color3.fromRGB(0,255,255),
    LineThickness=2,
    LineLength=25,
    WallCheckEnabled=true,
    WallCheckColor=Color3.fromRGB(255,255,0),
    VisibilityCheckEnabled=true,
    VisibilityCheckColor=Color3.fromRGB(255,0,0),
    ConeVisionEnabled=true,
    ConeVisionColor=Color3.fromRGB(0, 255, 255),
    ConeVisionTransparency=0.8,
    ConeVisionRange=50,
    ConeVisionFOV=90
}

local ESPObjects = {}

-- ===== CROSS-PLATFORM DRAWING API =====
local DrawingAPI = {}

function DrawingAPI:CreateLine(props)
    if IS_MOBILE then
        -- Use Frame-based line for mobile
        local line = Instance.new("Frame")
        line.BorderSizePixel = 0
        line.BackgroundColor3 = props.Color or Color3.new(1, 1, 1)
        line.Size = UDim2.new(0, props.Thickness or 1, 0, 1)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Visible = props.Visible or false
        line.ZIndex = 10
        return line
    else
        -- Use Drawing library for PC
        local line = Drawing.new("Line")
        for k, v in pairs(props) do
            if line[k] ~= nil then
                line[k] = v
            end
        end
        return line
    end
end

function DrawingAPI:CreateText(props)
    if IS_MOBILE then
        -- Use TextLabel for mobile
        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.TextColor3 = props.Color or Color3.new(1, 1, 1)
        text.TextSize = props.Size or 14
        text.Text = props.Text or ""
        text.Font = Enum.Font.Gotham
        text.TextStrokeTransparency = props.Outline and 0 or 1
        text.TextStrokeColor3 = Color3.new(0, 0, 0)
        text.Size = UDim2.new(0, 100, 0, 20)
        text.Visible = props.Visible or false
        text.ZIndex = 10
        return text
    else
        -- Use Drawing library for PC
        local text = Drawing.new("Text")
        for k, v in pairs(props) do
            if text[k] ~= nil then
                text[k] = v
            end
        end
        return text
    end
end

function DrawingAPI:CreateSquare(props)
    if IS_MOBILE then
        -- Use Frame for mobile
        local square = Instance.new("Frame")
        square.BackgroundColor3 = props.Color or Color3.new(1, 1, 1)
        square.BackgroundTransparency = props.Filled and 0 or 1
        square.BorderSizePixel = props.Filled and 0 or 1
        square.BorderColor3 = props.Color or Color3.new(1, 1, 1)
        square.Size = UDim2.new(0, 10, 0, 10)
        square.Visible = props.Visible or false
        square.ZIndex = 10
        return square
    else
        -- Use Drawing library for PC
        local square = Drawing.new("Square")
        for k, v in pairs(props) do
            if square[k] ~= nil then
                square[k] = v
            end
        end
        return square
    end
end

function DrawingAPI:CreateTriangle(props)
    if IS_MOBILE then
        -- Use ImageLabel with triangle image for mobile
        local triangle = Instance.new("ImageLabel")
        triangle.BackgroundTransparency = 1
        triangle.Image = "rbxassetid://10888330210" -- Triangle image
        triangle.ImageColor3 = props.Color or Color3.new(1, 1, 1)
        triangle.Size = UDim2.new(0, 15, 0, 15)
        triangle.Visible = props.Visible or false
        triangle.ZIndex = 10
        return triangle
    else
        -- Use Drawing library for PC
        local triangle = Drawing.new("Triangle")
        for k, v in pairs(props) do
            if triangle[k] ~= nil then
                triangle[k] = v
            end
        end
        return triangle
    end
end

function DrawingAPI:UpdateLine(line, from, to, color, thickness, visible)
    if IS_MOBILE then
        local direction = (to - from)
        local distance = direction.Magnitude
        local center = (from + to) / 2
        
        line.Position = UDim2.new(0, center.X, 0, center.Y)
        line.Size = UDim2.new(0, thickness or 1, 0, distance)
        line.Rotation = math.deg(math.atan2(direction.Y, direction.X))
        line.BackgroundColor3 = color or line.BackgroundColor3
        line.Visible = visible ~= nil and visible or line.Visible
    else
        line.From = from
        line.To = to
        line.Color = color or line.Color
        line.Thickness = thickness or line.Thickness
        line.Visible = visible ~= nil and visible or line.Visible
    end
end

function DrawingAPI:UpdateText(text, position, content, color, size, visible, center)
    if IS_MOBILE then
        text.Position = UDim2.new(0, position.X, 0, position.Y)
        text.Text = content or text.Text
        text.TextColor3 = color or text.TextColor3
        text.TextSize = size or text.TextSize
        text.Visible = visible ~= nil and visible or text.Visible
        
        if center then
            text.AnchorPoint = Vector2.new(0.5, 0.5)
        else
            text.AnchorPoint = Vector2.new(0, 0)
        end
    else
        text.Position = position
        text.Text = content or text.Text
        text.Color = color or text.Color
        text.Size = size or text.Size
        text.Visible = visible ~= nil and visible or text.Visible
        text.Center = center or text.Center
    end
end

function DrawingAPI:UpdateSquare(square, position, size, color, filled, visible)
    if IS_MOBILE then
        square.Position = UDim2.new(0, position.X, 0, position.Y)
        square.Size = UDim2.new(0, size.X, 0, size.Y)
        square.BackgroundColor3 = color or square.BackgroundColor3
        square.BackgroundTransparency = filled and 0 or 1
        square.BorderColor3 = color or square.BorderColor3
        square.Visible = visible ~= nil and visible or square.Visible
    else
        square.Position = position
        square.Size = size
        square.Color = color or square.Color
        square.Filled = filled or square.Filled
        square.Visible = visible ~= nil and visible or square.Visible
    end
end

function DrawingAPI:UpdateTriangle(triangle, pointA, pointB, pointC, color, visible)
    if IS_MOBILE then
        -- Calculate center and size for mobile triangle
        local minX = math.min(pointA.X, pointB.X, pointC.X)
        local minY = math.min(pointA.Y, pointB.Y, pointC.Y)
        local maxX = math.max(pointA.X, pointB.X, pointC.X)
        local maxY = math.max(pointA.Y, pointB.Y, pointC.Y)
        
        triangle.Position = UDim2.new(0, minX, 0, minY)
        triangle.Size = UDim2.new(0, maxX - minX, 0, maxY - minY)
        triangle.ImageColor3 = color or triangle.ImageColor3
        triangle.Visible = visible ~= nil and visible or triangle.Visible
    else
        triangle.PointA = pointA
        triangle.PointB = pointB
        triangle.PointC = pointC
        triangle.Color = color or triangle.Color
        triangle.Visible = visible ~= nil and visible or triangle.Visible
    end
end

function DrawingAPI:RemoveDrawing(drawing)
    if IS_MOBILE then
        if drawing and drawing.Parent then
            drawing:Destroy()
        end
    else
        if drawing then
            drawing:Remove()
        end
    end
end

-- ===== UTILITY FUNCTIONS =====
local function GetHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function GetRoot(char) return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") end
local function GetHead(char) return char:FindFirstChild("Head") end
local function GetTool(player,char)
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool then return tool end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _,i in pairs(backpack:GetChildren()) do if i:IsA("Tool") then return i end end
    end
    return nil
end

local function IsVisible(char,part)
    local dir = (part.Position - Camera.CFrame.Position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character,char}
    local ray = Workspace:Raycast(Camera.CFrame.Position, dir, params)
    return ray==nil
end

local function IsPlayerLookingAtMe(playerChar)
    if not playerChar or not LocalPlayer.Character then return false end
    
    local playerHead = playerChar:FindFirstChild("Head")
    local myHead = LocalPlayer.Character:FindFirstChild("Head")
    if not playerHead or not myHead then return false end
    
    local directionToMe = (myHead.Position - playerHead.Position).Unit
    local playerLookDirection = playerHead.CFrame.LookVector
    
    local dotProduct = directionToMe:Dot(playerLookDirection)
    
    return dotProduct > 0.7
end

local function CreateDrawing(type,props)
    if type == "Line" then
        return DrawingAPI:CreateLine(props)
    elseif type == "Text" then
        return DrawingAPI:CreateText(props)
    elseif type == "Square" then
        return DrawingAPI:CreateSquare(props)
    elseif type == "Triangle" then
        return DrawingAPI:CreateTriangle(props)
    end
end

-- Create container for mobile drawings
local MobileDrawingContainer
if IS_MOBILE then
    MobileDrawingContainer = Instance.new("ScreenGui")
    MobileDrawingContainer.Name = "CarbonXESPDrawings"
    MobileDrawingContainer.DisplayOrder = 10
    MobileDrawingContainer.ResetOnSpawn = false
    MobileDrawingContainer.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function HideESP(esp)
    for _,d in pairs(esp.Drawings) do
        if type(d)=="table" then 
            for _,dd in pairs(d) do 
                if IS_MOBILE then
                    dd.Visible = false
                else
                    dd.Visible = false 
                end
            end
        else 
            if IS_MOBILE then
                d.Visible = false
            else
                d.Visible = false 
            end
        end
    end
    if esp.Highlight then esp.Highlight.Enabled=false end
    if esp.Cone then 
        for _,part in ipairs(esp.Cone) do
            part.Transparency = 1
        end
    end
end

local function RemoveESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    esp.IsValid=false
    for _,conn in pairs(esp.Connections) do 
        if conn then 
            pcall(function() conn:Disconnect() end) 
        end 
    end
    for _,d in pairs(esp.Drawings) do
        if type(d)=="table" then 
            for _,dd in pairs(d) do 
                DrawingAPI:RemoveDrawing(dd)
            end
        else 
            DrawingAPI:RemoveDrawing(d)
        end
    end
    if esp.Highlight then esp.Highlight:Destroy() end
    if esp.Cone then
        for _,part in ipairs(esp.Cone) do
            part:Destroy()
        end
    end
    ESPObjects[player]=nil
end

-- Skeleton bone connections
local SKELETON_BONES = {
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
    {"RightLowerLeg", "RightFoot"}
}

local function CreateConeVision(esp, char)
    if not ESPConfig.ConeVisionEnabled then return end
    
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    esp.Cone = {}
    
    -- Create cone parts (using wedges for the cone shape)
    local conePart = Instance.new("Part")
    conePart.Name = "ConeVision"
    conePart.Anchored = true
    conePart.CanCollide = false
    conePart.CastShadow = false
    conePart.Material = Enum.Material.Neon
    conePart.BrickColor = BrickColor.new(ESPConfig.ConeVisionColor)
    conePart.Transparency = ESPConfig.ConeVisionTransparency
    conePart.Parent = char
    
    -- Create wedge mesh for cone shape
    local mesh = Instance.new("SpecialMesh", conePart)
    mesh.MeshType = Enum.MeshType.Wedge
    mesh.Scale = Vector3.new(0.5, 1, 1)
    
    esp.Cone[1] = conePart
end

local function UpdateConeVision(esp, char, head)
    if not ESPConfig.ConeVisionEnabled or not esp.Cone or not esp.Cone[1] then return end
    
    local conePart = esp.Cone[1]
    
    -- Calculate cone dimensions based on FOV and range
    local fovRad = math.rad(ESPConfig.ConeVisionFOV)
    local range = ESPConfig.ConeVisionRange
    local baseWidth = math.tan(fovRad / 2) * range * 2
    
    -- Position cone at head
    conePart.Size = Vector3.new(range, baseWidth / 2, range)
    conePart.CFrame = head.CFrame * CFrame.new(0, 0, -range / 2) * CFrame.Angles(0, math.pi, 0)
    
    -- Raycast to check if cone hits wall
    local rayOrigin = head.Position
    local rayDirection = head.CFrame.LookVector * range
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
    
    local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    
    -- Change color if wall is hit
    if rayResult then
        conePart.BrickColor = BrickColor.new(ESPConfig.WallCheckColor)
    else
        conePart.BrickColor = BrickColor.new(ESPConfig.ConeVisionColor)
    end
    
    -- Gradient transparency (more transparent at far end)
    conePart.Transparency = ESPConfig.ConeVisionTransparency
end

local function CreateESP(player)
    if player==LocalPlayer or ESPObjects[player] then return end
    local esp={Player=player,Drawings={},Connections={},Character=player.Character,IsValid=true, Cone=nil}

    -- Parent mobile drawings to container
    if IS_MOBILE then
        esp.MobileParent = Instance.new("Frame")
        esp.MobileParent.BackgroundTransparency = 1
        esp.MobileParent.Size = UDim2.new(1, 0, 1, 0)
        esp.MobileParent.Parent = MobileDrawingContainer
    end

    -- ESP Elements with proper stacking order
    if ESPConfig.BoxEnabled then 
        for i=1,4 do 
            local line = CreateDrawing("Line",{Color=ESPConfig.BoxColor,Thickness=1,Visible=false})
            if IS_MOBILE and line then
                line.Parent = esp.MobileParent
            end
            esp.Drawings["Box"..i] = line
        end 
    end
    
    if ESPConfig.NameEnabled then 
        local text = CreateDrawing("Text",{Text=player.Name,Size=14,Center=true,Outline=true,Color=ESPConfig.NameColor,Visible=false})
        if IS_MOBILE and text then
            text.Parent = esp.MobileParent
        end
        esp.Drawings.Name = text
    end
    
    if ESPConfig.ToolEnabled then 
        local text = CreateDrawing("Text",{Text="No Tool",Size=12,Center=true,Outline=true,Color=ESPConfig.ToolColor,Visible=false})
        if IS_MOBILE and text then
            text.Parent = esp.MobileParent
        end
        esp.Drawings.Tool = text
    end
    
    if ESPConfig.DistanceEnabled then 
        local text = CreateDrawing("Text",{Text="",Size=14,Center=true,Outline=true,Color=ESPConfig.DistanceColor,Visible=false})
        if IS_MOBILE and text then
            text.Parent = esp.MobileParent
        end
        esp.Drawings.Distance = text
    end
    
    -- FIXED HEALTH BAR: Create background first, then health fill
    if ESPConfig.HealthBarEnabled then 
        local bg = CreateDrawing("Square",{Filled=true,Thickness=1,Color=Color3.fromRGB(50,50,50),Visible=false})
        local health = CreateDrawing("Square",{Filled=true,Thickness=1,Color=Color3.fromRGB(0,255,0),Visible=false})
        if IS_MOBILE then
            if bg then bg.Parent = esp.MobileParent end
            if health then health.Parent = esp.MobileParent end
        end
        esp.Drawings.HealthBackground = bg
        esp.Drawings.Health = health
    end
    
    if ESPConfig.SkeletonEnabled then
        esp.Drawings.Skeleton = {}
        for i, bonePair in ipairs(SKELETON_BONES) do
            local line = CreateDrawing("Line", {
                Color = ESPConfig.SkeletonColor,
                Thickness = 2,
                Visible = false
            })
            if IS_MOBILE and line then
                line.Parent = esp.MobileParent
            end
            esp.Drawings.Skeleton[i] = line
        end
    end
    
    if ESPConfig.TracersEnabled then
        local line = CreateDrawing("Line", {
            Color = ESPConfig.TracerColor,
            Thickness = 1,
            Visible = false
        })
        if IS_MOBILE and line then
            line.Parent = esp.MobileParent
        end
        esp.Drawings.Tracer = line
    end
    
    -- FIXED LINE OF SIGHT: Create line first, then arrow
    if ESPConfig.LineOfSightEnabled then
        local line = CreateDrawing("Line",{
            Color=ESPConfig.LineColor,
            Thickness=ESPConfig.LineThickness,
            Visible=false
        })
        local arrow = CreateDrawing("Triangle",{
            Color=ESPConfig.LineColor,
            Filled=true,
            Visible=false
        })
        if IS_MOBILE then
            if line then line.Parent = esp.MobileParent end
            if arrow then arrow.Parent = esp.MobileParent end
        end
        esp.Drawings.LineOfSight = line
        esp.Drawings.LOSArrow = arrow
    end
    
    -- Cone Vision
    if ESPConfig.ConeVisionEnabled and esp.Character then
        CreateConeVision(esp, esp.Character)
    end
    
    if ESPConfig.ChamsEnabled then
        esp.Highlight = Instance.new("Highlight")
        esp.Highlight.FillColor = ESPConfig.ChamsColor
        esp.Highlight.OutlineColor = ESPConfig.ChamsColor
        esp.Highlight.FillTransparency = 0.5
        esp.Highlight.OutlineTransparency = 0
        esp.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        esp.Highlight.Parent = Camera
        esp.Highlight.Enabled = false
    end

    esp.Connections.CharacterAdded=player.CharacterAdded:Connect(function(char)
        esp.Character=char
        if esp.Highlight then
            esp.Highlight.Adornee = char
        end
        -- Create cone vision when character is added
        if ESPConfig.ConeVisionEnabled then
            CreateConeVision(esp, char)
        end
    end)
    
    esp.Connections.CharacterRemoving=player.CharacterRemoving:Connect(function() 
        HideESP(esp) 
        esp.Character=nil 
        if esp.Highlight then
            esp.Highlight.Adornee = nil
            esp.Highlight.Enabled = false
        end
        if esp.Cone then
            for _,part in ipairs(esp.Cone) do
                part:Destroy()
            end
            esp.Cone = nil
        end
    end)
    
    if esp.Character and esp.Highlight then
        esp.Highlight.Adornee = esp.Character
    end
    
    ESPObjects[player]=esp
end

local function UpdateESP(player)
    local esp=ESPObjects[player]
    if not esp or not esp.IsValid then return end
    local char=esp.Character
    if not char then HideESP(esp) return end
    local root=GetRoot(char)
    local hum=GetHumanoid(char)
    local head=GetHead(char)
    if not root or not hum or hum.Health<=0 then HideESP(esp) return end
    local dist=(root.Position-Camera.CFrame.Position).Magnitude
    if dist>ESPConfig.MaxDistance then HideESP(esp) return end
    local visible=IsVisible(char,root)
    
    local isBehindWall = not visible
    local isLookingAtMe = IsPlayerLookingAtMe(char)
    
    local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not onScreen then HideESP(esp) return end
    local scale = math.clamp(200/math.max(dist,1),0.5,2)
    local h = math.clamp(scale*40,20,80)
    local w = h*0.6

    -- Determine colors (excluding health bar from wall/visibility colors)
    local boxColor = ESPConfig.BoxColor
    local nameColor = ESPConfig.NameColor
    local toolColor = ESPConfig.ToolColor
    local distanceColor = ESPConfig.DistanceColor
    local skeletonColor = ESPConfig.SkeletonColor
    local tracerColor = ESPConfig.TracerColor
    local lineColor = ESPConfig.LineColor
    
    if ESPConfig.WallCheckEnabled and isBehindWall then
        boxColor = ESPConfig.WallCheckColor
        nameColor = ESPConfig.WallCheckColor
        toolColor = ESPConfig.WallCheckColor
        distanceColor = ESPConfig.WallCheckColor
        skeletonColor = ESPConfig.WallCheckColor
        tracerColor = ESPConfig.WallCheckColor
        lineColor = ESPConfig.WallCheckColor
    end
    
    if ESPConfig.VisibilityCheckEnabled and isLookingAtMe then
        boxColor = ESPConfig.VisibilityCheckColor
        nameColor = ESPConfig.VisibilityCheckColor
        toolColor = ESPConfig.VisibilityCheckColor
        distanceColor = ESPConfig.VisibilityCheckColor
        skeletonColor = ESPConfig.VisibilityCheckColor
        tracerColor = ESPConfig.VisibilityCheckColor
        lineColor = ESPConfig.VisibilityCheckColor
    end

    -- Box
    if ESPConfig.BoxEnabled then
        local corners={
            Vector2.new(pos.X-w/2,pos.Y-h/2),
            Vector2.new(pos.X+w/2,pos.Y-h/2),
            Vector2.new(pos.X+w/2,pos.Y+h/2),
            Vector2.new(pos.X-w/2,pos.Y+h/2)
        }
        for i=1,4 do
            local line=esp.Drawings["Box"..i]
            if line then 
                DrawingAPI:UpdateLine(line, corners[i], corners[i%4+1], boxColor, 1, true)
            end
        end
    end

    -- Name
    if ESPConfig.NameEnabled and esp.Drawings.Name then 
        DrawingAPI:UpdateText(esp.Drawings.Name, Vector2.new(pos.X,pos.Y-h/2-20), player.Name, nameColor, 14, true, true)
    end
    
    -- Tool
    if ESPConfig.ToolEnabled and esp.Drawings.Tool then
        local tool=GetTool(player,char)
        DrawingAPI:UpdateText(esp.Drawings.Tool, Vector2.new(pos.X,pos.Y-h/2-40), 
            tool and ("Tool: "..tool.Name) or "No Tool", toolColor, 12, true, true)
    end
    
    -- Distance
    if ESPConfig.DistanceEnabled and esp.Drawings.Distance then 
        DrawingAPI:UpdateText(esp.Drawings.Distance, Vector2.new(pos.X,pos.Y+h/2+10), 
            string.format("%.0f studs",dist), distanceColor, 14, true, true)
    end

    -- FIXED HEALTH BAR
    if ESPConfig.HealthBarEnabled then
        local corners={
            Vector2.new(pos.X-w/2,pos.Y-h/2),
            Vector2.new(pos.X+w/2,pos.Y-h/2),
            Vector2.new(pos.X+w/2,pos.Y+h/2),
            Vector2.new(pos.X-w/2,pos.Y+h/2)
        }
        
        local hp = hum.Health
        local max = hum.MaxHealth
        
        if max > 0 then
            local ratio = math.clamp(hp / max, 0, 1)
            local healthHeight = math.max(h * ratio, 1)
            
            -- Health bar background
            if esp.Drawings.HealthBackground then
                DrawingAPI:UpdateSquare(esp.Drawings.HealthBackground, 
                    Vector2.new(corners[1].X - 6, corners[1].Y), 
                    Vector2.new(4, h), 
                    Color3.fromRGB(50,50,50), true, true)
            end
            
            -- Health bar fill
            if esp.Drawings.Health then
                local healthY = corners[1].Y + h - healthHeight
                local healthColor
                if ratio > 0.6 then
                    healthColor = Color3.fromRGB(0, 255, 0)
                elseif ratio > 0.3 then
                    healthColor = Color3.fromRGB(255, 255, 0)
                else
                    healthColor = Color3.fromRGB(255, 0, 0)
                end
                
                DrawingAPI:UpdateSquare(esp.Drawings.Health,
                    Vector2.new(corners[1].X - 6, healthY),
                    Vector2.new(4, healthHeight),
                    healthColor, true, true)
            end
        else
            if esp.Drawings.HealthBackground then
                DrawingAPI:UpdateSquare(esp.Drawings.HealthBackground, Vector2.new(0,0), Vector2.new(0,0), Color3.new(0,0,0), true, false)
            end
            if esp.Drawings.Health then
                DrawingAPI:UpdateSquare(esp.Drawings.Health, Vector2.new(0,0), Vector2.new(0,0), Color3.new(0,0,0), true, false)
            end
        end
    end

    -- Skeleton ESP
    if ESPConfig.SkeletonEnabled and esp.Drawings.Skeleton then
        for i, bonePair in ipairs(SKELETON_BONES) do
            local part1 = char:FindFirstChild(bonePair[1])
            local part2 = char:FindFirstChild(bonePair[2])
            
            if part1 and part2 then
                local pos1, onScreen1 = Camera:WorldToViewportPoint(part1.Position)
                local pos2, onScreen2 = Camera:WorldToViewportPoint(part2.Position)
                
                if onScreen1 and onScreen2 then
                    local boneLine = esp.Drawings.Skeleton[i]
                    DrawingAPI:UpdateLine(boneLine, Vector2.new(pos1.X, pos1.Y), Vector2.new(pos2.X, pos2.Y), skeletonColor, 2, true)
                else
                    if esp.Drawings.Skeleton[i] then
                        DrawingAPI:UpdateLine(esp.Drawings.Skeleton[i], Vector2.new(0,0), Vector2.new(0,0), skeletonColor, 2, false)
                    end
                end
            else
                if esp.Drawings.Skeleton[i] then
                    DrawingAPI:UpdateLine(esp.Drawings.Skeleton[i], Vector2.new(0,0), Vector2.new(0,0), skeletonColor, 2, false)
                end
            end
        end
    end

    -- Tracers
    if ESPConfig.TracersEnabled and esp.Drawings.Tracer then
        local tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        local tracerEnd = Vector2.new(pos.X, pos.Y)
        
        DrawingAPI:UpdateLine(esp.Drawings.Tracer, tracerStart, tracerEnd, tracerColor, 1, true)
    elseif esp.Drawings.Tracer then
        DrawingAPI:UpdateLine(esp.Drawings.Tracer, Vector2.new(0,0), Vector2.new(0,0), tracerColor, 1, false)
    end

    -- Chams
    if ESPConfig.ChamsEnabled and esp.Highlight then
        if isBehindWall and ESPConfig.WallCheckEnabled then
            esp.Highlight.FillColor = ESPConfig.WallCheckColor
            esp.Highlight.OutlineColor = ESPConfig.WallCheckColor
        elseif isLookingAtMe and ESPConfig.VisibilityCheckEnabled then
            esp.Highlight.FillColor = ESPConfig.VisibilityCheckColor
            esp.Highlight.OutlineColor = ESPConfig.VisibilityCheckColor
        else
            esp.Highlight.FillColor = ESPConfig.ChamsColor
            esp.Highlight.OutlineColor = ESPConfig.ChamsColor
        end
        esp.Highlight.Enabled = true
    elseif esp.Highlight then
        esp.Highlight.Enabled = false
    end

    -- FIXED LINE OF SIGHT
    if ESPConfig.LineOfSightEnabled and head and esp.Drawings.LineOfSight then
        local origin = head.Position
        local direction = head.CFrame.LookVector * ESPConfig.LineLength
        
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {LocalPlayer.Character, char}
        local result = Workspace:Raycast(origin, direction, params)
        
        local endPoint = result and result.Position or (origin + direction)

        local start2D, onScreenStart = Camera:WorldToViewportPoint(origin)
        local end2D, onScreenEnd = Camera:WorldToViewportPoint(endPoint)
        
        if onScreenStart and onScreenEnd then
            DrawingAPI:UpdateLine(esp.Drawings.LineOfSight, 
                Vector2.new(start2D.X, start2D.Y), 
                Vector2.new(end2D.X, end2D.Y), 
                lineColor, ESPConfig.LineThickness, true)

            if esp.Drawings.LOSArrow then
                local direction2D = (Vector2.new(end2D.X, end2D.Y) - Vector2.new(start2D.X, start2D.Y))
                local length = direction2D.Magnitude
                
                if length > 5 then
                    local dir = direction2D.Unit
                    local arrowLength = 15
                    local arrowWidth = 8
                    
                    local perp = Vector2.new(-dir.Y, dir.X)
                    local base = Vector2.new(end2D.X, end2D.Y) - dir * arrowLength
                    
                    local pointA = Vector2.new(end2D.X, end2D.Y)
                    local pointB = base + perp * arrowWidth
                    local pointC = base - perp * arrowWidth
                    
                    DrawingAPI:UpdateTriangle(esp.Drawings.LOSArrow, pointA, pointB, pointC, lineColor, true)
                else
                    DrawingAPI:UpdateTriangle(esp.Drawings.LOSArrow, Vector2.new(0,0), Vector2.new(0,0), Vector2.new(0,0), lineColor, false)
                end
            end
        else
            DrawingAPI:UpdateLine(esp.Drawings.LineOfSight, Vector2.new(0,0), Vector2.new(0,0), lineColor, ESPConfig.LineThickness, false)
            if esp.Drawings.LOSArrow then
                DrawingAPI:UpdateTriangle(esp.Drawings.LOSArrow, Vector2.new(0,0), Vector2.new(0,0), Vector2.new(0,0), lineColor, false)
            end
        end
    else
        if esp.Drawings.LineOfSight then
            DrawingAPI:UpdateLine(esp.Drawings.LineOfSight, Vector2.new(0,0), Vector2.new(0,0), lineColor, ESPConfig.LineThickness, false)
        end
        if esp.Drawings.LOSArrow then
            DrawingAPI:UpdateTriangle(esp.Drawings.LOSArrow, Vector2.new(0,0), Vector2.new(0,0), Vector2.new(0,0), lineColor, false)
        end
    end

    -- Update Cone Vision
    if head then
        UpdateConeVision(esp, char, head)
    end
end

RunService.RenderStepped:Connect(function()
    for p,esp in pairs(ESPObjects) do 
        pcall(UpdateESP, p) 
    end
end)

for _,p in pairs(Players:GetPlayers()) do 
    if p~=LocalPlayer then 
        CreateESP(p) 
    end 
end

Players.PlayerAdded:Connect(function(p) 
    if p~=LocalPlayer then 
        p.CharacterAdded:Connect(function() 
            CreateESP(p) 
        end) 
    end 
end)

Players.PlayerRemoving:Connect(RemoveESP)

-- ===== MULTI-PLATFORM GUI =====
local function CreateModernGUI()
    local GUI = Instance.new("ScreenGui")
    GUI.Name = "CarbonXESP_UltraModern"
    GUI.IgnoreGuiInset = true
    GUI.ResetOnSpawn = false
    GUI.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Main Container with modern styling
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 450, 0, 600)
    Main.Position = UDim2.new(0, 50, 0.5, -300)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    Main.BorderSizePixel = 0
    Main.Parent = GUI
    Main.Active = true
    Main.Draggable = not IS_MOBILE -- Only draggable on desktop

    -- Modern rounded corners effect
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = Main

    -- Drop shadow effect
    local Shadow = Instance.new("ImageLabel")
    Shadow.Size = UDim2.new(1, 20, 1, 20)
    Shadow.Position = UDim2.new(0, -10, 0, -10)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.8
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(23,23,277,277)
    Shadow.Parent = Main
    Shadow.ZIndex = -1

    -- Header with gradient
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 60)
    Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Header.BorderSizePixel = 0
    Header.Parent = Main

    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 12)
    HeaderCorner.Parent = Header

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "CARBON X ESP"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = IS_MOBILE and Enum.Font.Gotham or Enum.Font.GothamBold
    Title.TextSize = IS_MOBILE and 18 or 20
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextYAlignment = Enum.TextYAlignment.Center
    Title.Parent = Header

    -- Control buttons container
    local ControlButtons = Instance.new("Frame")
    ControlButtons.Size = UDim2.new(0, 70, 1, 0)
    ControlButtons.Position = UDim2.new(1, -75, 0, 0)
    ControlButtons.BackgroundTransparency = 1
    ControlButtons.Parent = Header

    -- Minimize button
    local Minimize = Instance.new("TextButton")
    Minimize.Size = UDim2.new(0, 25, 0, 25)
    Minimize.Position = UDim2.new(0, 5, 0.5, -12)
    Minimize.Text = "_"
    Minimize.Font = Enum.Font.GothamBold
    Minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
    Minimize.TextSize = 16
    Minimize.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    Minimize.BorderSizePixel = 0
    Minimize.Parent = ControlButtons

    local MinimizeCorner = Instance.new("UICorner")
    MinimizeCorner.CornerRadius = UDim.new(0, 6)
    MinimizeCorner.Parent = Minimize

    -- Close button
    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 25, 0, 25)
    Close.Position = UDim2.new(0, 35, 0.5, -12)
    Close.Text = "×"
    Close.Font = Enum.Font.GothamBold
    Close.TextColor3 = Color3.fromRGB(255, 255, 255)
    Close.TextSize = 18
    Close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    Close.BorderSizePixel = 0
    Close.Parent = ControlButtons

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = Close

    -- Content area
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -40, 1, -100)
    Content.Position = UDim2.new(0, 20, 0, 80)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    -- Scrollable content
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, 0, 1, 0)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 4
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 1000)
    Scroll.Parent = Content

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 12)
    Layout.Parent = Scroll

    -- Function to create modern toggle switches
    local function CreateToggle(label, configKey, order)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, IS_MOBILE and 60 or 50)
        Container.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        Container.BorderSizePixel = 0
        Container.Parent = Scroll
        Container.LayoutOrder = order
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = Container
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, -10, 1, 0)
        Label.Position = UDim2.new(0, 15, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = label
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.Font = IS_MOBILE and Enum.Font.Gotham or Enum.Font.Gotham
        Label.TextSize = IS_MOBILE and 16 or 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Container
        
        -- Toggle background
        local ToggleBg = Instance.new("Frame")
        ToggleBg.Size = UDim2.new(0, IS_MOBILE and 60 or 50, 0, IS_MOBILE and 30 or 24)
        ToggleBg.Position = UDim2.new(1, -65, 0.5, -IS_MOBILE and 15 or 12)
        ToggleBg.BackgroundColor3 = ESPConfig[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 100)
        ToggleBg.BorderSizePixel = 0
        ToggleBg.Parent = Container
        
        local ToggleCorner = Instance.new("UICorner")
        ToggleCorner.CornerRadius = UDim.new(0, 12)
        ToggleCorner.Parent = ToggleBg
        
        -- Toggle knob
        local ToggleKnob = Instance.new("Frame")
        ToggleKnob.Size = UDim2.new(0, IS_MOBILE and 26 or 20, 0, IS_MOBILE and 26 or 20)
        ToggleKnob.Position = UDim2.new(0, ESPConfig[configKey] and (IS_MOBILE and 30 or 26) or (IS_MOBILE and 2 or 2), 0.5, IS_MOBILE and -13 or -10)
        ToggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ToggleKnob.BorderSizePixel = 0
        ToggleKnob.Parent = ToggleBg
        
        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(0, 10)
        KnobCorner.Parent = ToggleKnob
        
        -- Toggle button
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(1, 0, 1, 0)
        ToggleButton.BackgroundTransparency = 1
        ToggleButton.Text = ""
        ToggleButton.Parent = Container
        
        ToggleButton.MouseButton1Click:Connect(function()
            ESPConfig[configKey] = not ESPConfig[configKey]
            
            -- Animate toggle
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local bgTween = TweenService:Create(ToggleBg, tweenInfo, {
                BackgroundColor3 = ESPConfig[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 100)
            })
            local knobTween = TweenService:Create(ToggleKnob, tweenInfo, {
                Position = UDim2.new(0, ESPConfig[configKey] and (IS_MOBILE and 30 or 26) or (IS_MOBILE and 2 or 2), 0.5, IS_MOBILE and -13 or -10)
            })
            
            bgTween:Play()
            knobTween:Play()
        end)
        
        return Container
    end

    -- Function to create modern slider
    local function CreateSlider(label, configKey, min, max, defaultValue, order)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, IS_MOBILE and 80 or 70)
        Container.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        Container.BorderSizePixel = 0
        Container.Parent = Scroll
        Container.LayoutOrder = order
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = Container
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -30, 0, 20)
        Label.Position = UDim2.new(0, 15, 0, 10)
        Label.BackgroundTransparency = 1
        Label.Text = label
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.Font = IS_MOBILE and Enum.Font.Gotham or Enum.Font.Gotham
        Label.TextSize = IS_MOBILE and 16 or 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Container
        
        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0, 60, 0, 20)
        ValueLabel.Position = UDim2.new(1, -75, 0, 10)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(ESPConfig[configKey])
        ValueLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
        ValueLabel.Font = Enum.Font.GothamBold
        ValueLabel.TextSize = IS_MOBILE and 16 or 14
        ValueLabel.Parent = Container
        
        -- Slider track
        local Track = Instance.new("Frame")
        Track.Size = UDim2.new(1, -30, 0, IS_MOBILE and 8 or 6)
        Track.Position = UDim2.new(0, 15, 0, IS_MOBILE and 45 or 40)
        Track.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        Track.BorderSizePixel = 0
        Track.Parent = Container
        
        local TrackCorner = Instance.new("UICorner")
        TrackCorner.CornerRadius = UDim.new(0, 3)
        TrackCorner.Parent = Track
        
        -- Slider fill
        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((ESPConfig[configKey] - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        Fill.BorderSizePixel = 0
        Fill.Parent = Track
        
        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(0, 3)
        FillCorner.Parent = Fill
        
        -- Slider knob
        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, IS_MOBILE and 20 or 16, 0, IS_MOBILE and 20 or 16)
        Knob.Position = UDim2.new((ESPConfig[configKey] - min) / (max - min), IS_MOBILE and -10 or -8, 0.5, IS_MOBILE and -10 or -8)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Track
        
        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(0, 8)
        KnobCorner.Parent = Knob
        
        -- Improved slider button for mobile and desktop
        local SliderButton = Instance.new("TextButton")
        SliderButton.Size = UDim2.new(1, 0, 3, 0)
        SliderButton.Position = UDim2.new(0, 0, -1, 0)
        SliderButton.BackgroundTransparency = 1
        SliderButton.Text = ""
        SliderButton.Parent = Track
        
        local dragging = false
        
        local function updateSlider(input)
            local relativeX = (input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X
            local value = math.floor(min + (max - min) * math.clamp(relativeX, 0, 1))
            
            ESPConfig[configKey] = value
            ValueLabel.Text = tostring(value)
            
            local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local fillTween = TweenService:Create(Fill, tweenInfo, {Size = UDim2.new((value - min) / (max - min), 0, 1, 0)})
            local knobTween = TweenService:Create(Knob, tweenInfo, {Position = UDim2.new((value - min) / (max - min), IS_MOBILE and -10 or -8, 0.5, IS_MOBILE and -10 or -8)})
            
            fillTween:Play()
            knobTween:Play()
        end
        
        -- Universal input handling for both mouse and touch
        SliderButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateSlider(input)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(input)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
            end
        end)
        
        return Container
    end

    -- Create all toggles and sliders
    CreateToggle("Player Box ESP", "BoxEnabled", 1)
    CreateToggle("Player Names", "NameEnabled", 2)
    CreateToggle("Tool Display", "ToolEnabled", 3)
    CreateToggle("Distance Display", "DistanceEnabled", 4)
    CreateToggle("Health Bar", "HealthBarEnabled", 5)
    CreateToggle("Skeleton ESP", "SkeletonEnabled", 6)
    CreateToggle("Player Chams", "ChamsEnabled", 7)
    CreateToggle("Tracers", "TracersEnabled", 8)
    CreateToggle("Line of Sight", "LineOfSightEnabled", 9)
    CreateToggle("Cone Vision", "ConeVisionEnabled", 10)
    CreateToggle("Wall Check", "WallCheckEnabled", 11)
    CreateToggle("Visibility Check", "VisibilityCheckEnabled", 12)

    CreateSlider("ESP Distance", "MaxDistance", 1, 1000, 500, 13)
    CreateSlider("LOS Length", "LineLength", 10, 100, 25, 14)
    CreateSlider("Cone Range", "ConeVisionRange", 10, 100, 50, 15)
    CreateSlider("Cone FOV", "ConeVisionFOV", 30, 120, 90, 16)

    -- UI State management
    local isMinimized = false
    local originalSize = Main.Size

    Minimize.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        if isMinimized then
            Content.Visible = false
            Shadow.Visible = false
            local tween = TweenService:Create(Main, tweenInfo, {Size = UDim2.new(0, 450, 0, 60)})
            tween:Play()
            Minimize.Text = "+"
            Minimize.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
        else
            Content.Visible = true
            Shadow.Visible = true
            local tween = TweenService:Create(Main, tweenInfo, {Size = originalSize})
            tween:Play()
            Minimize.Text = "_"
            Minimize.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        end
    end)

    Close.MouseButton1Click:Connect(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(Main, tweenInfo, {Size = UDim2.new(0, 0, 0, 0)})
        tween:Play()
        
        tween.Completed:Connect(function()
            GUI:Destroy()
        end)
    end)

    -- Auto-adjust canvas size
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Scroll.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 20)
    end)

    return GUI
end

-- Create the GUI
local success, result = pcall(CreateModernGUI)
if success then
    print("✅ Carbon X ESP Multi-Platform Loaded!")
    print("📱 Platform: " .. (IS_MOBILE and "Mobile" or IS_DESKTOP and "Desktop" or "Console"))
else
    warn("❌ Failed to create GUI: " .. tostring(result))
end
