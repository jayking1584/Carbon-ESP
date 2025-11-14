--[[
Carbon X ESP Premium - Ultra-Modern GUI
Features: Real-time health bars, proper line of sight arrows, all features functional
Client-side only
]]

-- ===== SERVICES =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

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
    VisibilityCheckColor=Color3.fromRGB(255,0,0)
}

local ESPObjects = {}

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

-- New: Check if player can see local player
local function IsPlayerLookingAtMe(playerChar)
    if not playerChar or not LocalPlayer.Character then return false end
    
    local playerHead = playerChar:FindFirstChild("Head")
    local myHead = LocalPlayer.Character:FindFirstChild("Head")
    if not playerHead or not myHead then return false end
    
    local directionToMe = (myHead.Position - playerHead.Position).Unit
    local playerLookDirection = playerHead.CFrame.LookVector
    
    local dotProduct = directionToMe:Dot(playerLookDirection)
    
    -- If dot product is close to 1, they're looking roughly in our direction
    return dotProduct > 0.7
end

local function CreateDrawing(type,props)
    local d = Drawing.new(type)
    for k,v in pairs(props) do if d[k]~=nil then d[k]=v end end
    return d
end

local function HideESP(esp)
    for _,d in pairs(esp.Drawings) do
        if type(d)=="table" then for _,dd in pairs(d) do dd.Visible=false end
        else d.Visible=false end
    end
    if esp.Highlight then esp.Highlight.Enabled=false end
end

local function RemoveESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    esp.IsValid=false
    for _,conn in pairs(esp.Connections) do if conn then pcall(function() conn:Disconnect() end) end end
    for _,d in pairs(esp.Drawings) do
        if type(d)=="table" then for _,dd in pairs(d) do pcall(function() dd:Remove() end) end
        else pcall(function() d:Remove() end) end
    end
    if esp.Highlight then esp.Highlight:Destroy() end
    ESPObjects[player]=nil
end

-- Skeleton bone connections
local SKELETON_BONES = {
    -- Torso
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    
    -- Left Arm
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    
    -- Right Arm
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    
    -- Left Leg
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    
    -- Right Leg
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local function CreateESP(player)
    if player==LocalPlayer or ESPObjects[player] then return end
    local esp={Player=player,Drawings={},Connections={},Character=player.Character,IsValid=true}

    -- ESP Elements - Now independent
    if ESPConfig.BoxEnabled then for i=1,4 do esp.Drawings["Box"..i]=CreateDrawing("Line",{Color=ESPConfig.BoxColor,Thickness=1,Visible=false}) end end
    if ESPConfig.NameEnabled then esp.Drawings.Name=CreateDrawing("Text",{Text=player.Name,Size=14,Center=true,Outline=true,Color=ESPConfig.NameColor,Visible=false}) end
    if ESPConfig.ToolEnabled then esp.Drawings.Tool=CreateDrawing("Text",{Text="No Tool",Size=12,Center=true,Outline=true,Color=ESPConfig.ToolColor,Visible=false}) end
    if ESPConfig.DistanceEnabled then esp.Drawings.Distance=CreateDrawing("Text",{Text="",Size=14,Center=true,Outline=true,Color=ESPConfig.DistanceColor,Visible=false}) end
    if ESPConfig.HealthBarEnabled then 
        esp.Drawings.Health = CreateDrawing("Square",{Filled=true,Thickness=1,Color=ESPConfig.HealthBarColor,Visible=false})
        esp.Drawings.HealthBackground = CreateDrawing("Square",{Filled=true,Thickness=1,Color=Color3.fromRGB(50,50,50),Visible=false})
    end
    
    -- Skeleton ESP - Create lines for all bones
    if ESPConfig.SkeletonEnabled then
        esp.Drawings.Skeleton = {}
        for i, bonePair in ipairs(SKELETON_BONES) do
            esp.Drawings.Skeleton[i] = CreateDrawing("Line", {
                Color = ESPConfig.SkeletonColor,
                Thickness = 2,
                Visible = false
            })
        end
    end
    
    -- Tracers
    if ESPConfig.TracersEnabled then
        esp.Drawings.Tracer = CreateDrawing("Line", {
            Color = ESPConfig.TracerColor,
            Thickness = 1,
            Visible = false
        })
    end
    
    -- Line of Sight with Arrow
    if ESPConfig.LineOfSightEnabled then
        esp.Drawings.LineOfSight = CreateDrawing("Line",{Color=ESPConfig.LineColor,Thickness=ESPConfig.LineThickness,Visible=false})
        esp.Drawings.LOSArrow = CreateDrawing("Triangle",{Color=ESPConfig.LineColor,Filled=true,Visible=false})
    end
    
    -- Chams Highlight
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
    end)
    
    esp.Connections.CharacterRemoving=player.CharacterRemoving:Connect(function() 
        HideESP(esp) 
        esp.Character=nil 
        if esp.Highlight then
            esp.Highlight.Adornee = nil
            esp.Highlight.Enabled = false
        end
    end)
    
    -- Set initial highlight adornee
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
    
    -- New: Wall check and visibility check
    local isBehindWall = not visible
    local isLookingAtMe = IsPlayerLookingAtMe(char)
    
    local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not onScreen then HideESP(esp) return end
    local scale = math.clamp(200/math.max(dist,1),0.5,2)
    local h = math.clamp(scale*40,20,80)
    local w = h*0.6

    -- Determine colors based on wall and visibility checks
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

    -- Box (Independent from health bar)
    if ESPConfig.BoxEnabled then
        local corners={Vector2.new(pos.X-w/2,pos.Y-h/2),Vector2.new(pos.X+w/2,pos.Y-h/2),
                       Vector2.new(pos.X+w/2,pos.Y+h/2),Vector2.new(pos.X-w/2,pos.Y+h/2)}
        for i=1,4 do
            local line=esp.Drawings["Box"..i]
            if line then 
                line.From=corners[i] 
                line.To=corners[i%4+1] 
                line.Color=boxColor
                line.Visible=true 
            end
        end
    end

    -- Name (Independent)
    if ESPConfig.NameEnabled then 
        esp.Drawings.Name.Position=Vector2.new(pos.X,pos.Y-h/2-20) 
        esp.Drawings.Name.Text=player.Name 
        esp.Drawings.Name.Color = nameColor
        esp.Drawings.Name.Visible=true 
    end
    
    -- Tool (Independent)
    if ESPConfig.ToolEnabled then
        local tool=GetTool(player,char)
        esp.Drawings.Tool.Position=Vector2.new(pos.X,pos.Y-h/2-40)
        esp.Drawings.Tool.Text=tool and ("Tool: "..tool.Name) or "No Tool"
        esp.Drawings.Tool.Color = toolColor
        esp.Drawings.Tool.Visible=true
    end
    
    -- Distance (Independent)
    if ESPConfig.DistanceEnabled then 
        esp.Drawings.Distance.Position=Vector2.new(pos.X,pos.Y+h/2+10) 
        esp.Drawings.Distance.Text=string.format("%.0f studs",dist) 
        esp.Drawings.Distance.Color = distanceColor
        esp.Drawings.Distance.Visible=true 
    end

    -- Health Bar (Now completely independent with real-time health)
    if ESPConfig.HealthBarEnabled then
        local corners={Vector2.new(pos.X-w/2,pos.Y-h/2),Vector2.new(pos.X+w/2,pos.Y-h/2),
                       Vector2.new(pos.X+w/2,pos.Y+h/2),Vector2.new(pos.X-w/2,pos.Y+h/2)}
        local ratio=hum.Health/math.max(hum.MaxHealth,1)
        
        -- Health bar background
        if esp.Drawings.HealthBackground then
            esp.Drawings.HealthBackground.Position=Vector2.new(corners[1].X-6,corners[1].Y)
            esp.Drawings.HealthBackground.Size=Vector2.new(4,h)
            esp.Drawings.HealthBackground.Visible=true
        end
        
        -- Health bar fill with real-time health
        if esp.Drawings.Health then
            local healthHeight = h * ratio
            esp.Drawings.Health.Position=Vector2.new(corners[1].X-6,corners[1].Y + (h - healthHeight))
            esp.Drawings.Health.Size=Vector2.new(4,healthHeight)
            
            -- Dynamic health color based on health percentage
            if ratio > 0.6 then
                esp.Drawings.Health.Color = Color3.fromRGB(0, 255, 0) -- Green
            elseif ratio > 0.3 then
                esp.Drawings.Health.Color = Color3.fromRGB(255, 255, 0) -- Yellow
            else
                esp.Drawings.Health.Color = Color3.fromRGB(255, 0, 0) -- Red
            end
            
            esp.Drawings.Health.Visible=true
        end
    end

    -- Skeleton ESP (Fixed with proper bone connections)
    if ESPConfig.SkeletonEnabled and esp.Drawings.Skeleton then
        for i, bonePair in ipairs(SKELETON_BONES) do
            local part1 = char:FindFirstChild(bonePair[1])
            local part2 = char:FindFirstChild(bonePair[2])
            
            if part1 and part2 then
                local pos1, onScreen1 = Camera:WorldToViewportPoint(part1.Position)
                local pos2, onScreen2 = Camera:WorldToViewportPoint(part2.Position)
                
                if onScreen1 and onScreen2 then
                    local boneLine = esp.Drawings.Skeleton[i]
                    boneLine.From = Vector2.new(pos1.X, pos1.Y)
                    boneLine.To = Vector2.new(pos2.X, pos2.Y)
                    boneLine.Color = skeletonColor
                    boneLine.Visible = true
                else
                    if esp.Drawings.Skeleton[i] then
                        esp.Drawings.Skeleton[i].Visible = false
                    end
                end
            else
                if esp.Drawings.Skeleton[i] then
                    esp.Drawings.Skeleton[i].Visible = false
                end
            end
        end
    elseif esp.Drawings.Skeleton then
        for i = 1, #SKELETON_BONES do
            if esp.Drawings.Skeleton[i] then
                esp.Drawings.Skeleton[i].Visible = false
            end
        end
    end

    -- Tracers (New Feature)
    if ESPConfig.TracersEnabled and esp.Drawings.Tracer then
        local tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        local tracerEnd = Vector2.new(pos.X, pos.Y)
        
        esp.Drawings.Tracer.From = tracerStart
        esp.Drawings.Tracer.To = tracerEnd
        esp.Drawings.Tracer.Color = tracerColor
        esp.Drawings.Tracer.Visible = true
    elseif esp.Drawings.Tracer then
        esp.Drawings.Tracer.Visible = false
    end

    -- Chams (Fixed and working)
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

    -- Line of Sight with Arrow (Fixed - Proper arrow at tip)
    if ESPConfig.LineOfSightEnabled and head and esp.Drawings.LineOfSight then
        local startPos = head.Position
        local lookVector = head.CFrame.LookVector
        local endPos = startPos + lookVector * ESPConfig.LineLength

        local start2D, onScreenStart = Camera:WorldToViewportPoint(startPos)
        local end2D, onScreenEnd = Camera:WorldToViewportPoint(endPos)
        
        if onScreenStart and onScreenEnd then
            local line = esp.Drawings.LineOfSight
            line.From = Vector2.new(start2D.X, start2D.Y)
            line.To = Vector2.new(end2D.X, end2D.Y)
            line.Color = lineColor
            line.Visible = true

            -- Create proper arrow at the end of the line
            local arrow = esp.Drawings.LOSArrow
            local dir = (line.To - line.From).Unit
            local length = 15 -- Arrow size
            local width = 8   -- Arrow width
            
            -- Calculate arrow points
            local back = line.To - dir * length
            local perp = Vector2.new(-dir.Y, dir.X)
            
            arrow.PointA = line.To
            arrow.PointB = back + perp * width
            arrow.PointC = back - perp * width
            arrow.Color = lineColor
            arrow.Visible = true
        else
            esp.Drawings.LineOfSight.Visible = false
            esp.Drawings.LOSArrow.Visible = false
        end
    elseif esp.Drawings.LineOfSight then
        esp.Drawings.LineOfSight.Visible = false
        esp.Drawings.LOSArrow.Visible = false
    end
end

RunService.RenderStepped:Connect(function()
    for p,_ in pairs(ESPObjects) do pcall(UpdateESP,p) end
end)

for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer then CreateESP(p) end end
Players.PlayerAdded:Connect(function(p) if p~=LocalPlayer then p.CharacterAdded:Connect(function() CreateESP(p) end) end end)
Players.PlayerRemoving:Connect(RemoveESP)

-- ===== ULTRA MODERN GUI =====
local GUI = Instance.new("ScreenGui",CoreGui)
GUI.Name = "CarbonXESP_UltraModern"
GUI.IgnoreGuiInset = true

-- Main Container with modern styling
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 450, 0, 600)
Main.Position = UDim2.new(0, 50, 0.5, -300)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Parent = GUI
Main.Active = true
Main.Draggable = true

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
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
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
    Container.Size = UDim2.new(1, 0, 0, 50)
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
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    -- Toggle background
    local ToggleBg = Instance.new("Frame")
    ToggleBg.Size = UDim2.new(0, 50, 0, 24)
    ToggleBg.Position = UDim2.new(1, -65, 0.5, -12)
    ToggleBg.BackgroundColor3 = ESPConfig[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 100)
    ToggleBg.BorderSizePixel = 0
    ToggleBg.Parent = Container
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 12)
    ToggleCorner.Parent = ToggleBg
    
    -- Toggle knob
    local ToggleKnob = Instance.new("Frame")
    ToggleKnob.Size = UDim2.new(0, 20, 0, 20)
    ToggleKnob.Position = UDim2.new(0, ESPConfig[configKey] and 26 or 2, 0.5, -10)
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
            Position = UDim2.new(0, ESPConfig[configKey] and 26 or 2, 0.5, -10)
        })
        
        bgTween:Play()
        knobTween:Play()
    end)
    
    return Container
end

-- Function to create modern slider
local function CreateSlider(label, configKey, min, max, defaultValue, order)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 70)
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
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0, 60, 0, 20)
    ValueLabel.Position = UDim2.new(1, -75, 0, 10)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(ESPConfig[configKey])
    ValueLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.TextSize = 14
    ValueLabel.Parent = Container
    
    -- Slider track
    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -30, 0, 6)
    Track.Position = UDim2.new(0, 15, 0, 40)
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
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = UDim2.new((ESPConfig[configKey] - min) / (max - min), -8, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Track
    
    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(0, 8)
    KnobCorner.Parent = Knob
    
    -- Improved slider button for mobile and desktop
    local SliderButton = Instance.new("TextButton")
    SliderButton.Size = UDim2.new(1, 0, 3, 0) -- Even taller for mobile touch
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
        local knobTween = TweenService:Create(Knob, tweenInfo, {Position = UDim2.new((value - min) / (max - min), -8, 0.5, -8)})
        
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
CreateToggle("Wall Check", "WallCheckEnabled", 10)
CreateToggle("Visibility Check", "VisibilityCheckEnabled", 11)

CreateSlider("ESP Distance", "MaxDistance", 1, 1000, 500, 12)
CreateSlider("LOS Length", "LineLength", 10, 100, 25, 13)
CreateSlider("LOS Thickness", "LineThickness", 1, 5, 2, 14)

-- UI State management
local isMinimized = false
local originalSize = Main.Size

Minimize.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if isMinimized then
        -- Hide everything except header and show restore button
        Content.Visible = false
        Shadow.Visible = false
        local tween = TweenService:Create(Main, tweenInfo, {Size = UDim2.new(0, 450, 0, 60)})
        tween:Play()
        Minimize.Text = "+"
        Minimize.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    else
        -- Show everything and change back to minimize button
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

print("✅ Carbon X ESP Ultra-Modern GUI Loaded!")
