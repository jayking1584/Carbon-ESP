--==================================================
-- Carbon's Universal ESP - Premium GUI + Animations
-- Features Added: Tab animations, particle accents,
-- category dividers, matching splash-screen intro UI
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

--==================================================
-- CONFIGURATION
--==================================================
local ESPConfig = {
    BoxEnabled = true,
    TracerEnabled = true,
    NameEnabled = true,
    DistanceEnabled = true,
    ToolEnabled = true,
    SkeletonEnabled = true,
    HealthBarEnabled = true,
    ChamsEnabled = true,
    VisibilityCheck = true,
    MaxDistance = 500,

    BoxColor = Color3.fromRGB(0, 170, 255),
    TracerColor = Color3.fromRGB(255, 255, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    DistanceColor = Color3.fromRGB(255, 255, 255),
    ToolColor = Color3.fromRGB(255, 255, 0),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    ChamsColor = Color3.fromRGB(0, 170, 255),

    TextSize = 14,
    TextFont = Enum.Font.Gotham,
}

local ESPObjects = {}
local Connections = {}

--==================================================
-- UTILITY FUNCTIONS
--==================================================
local function GetHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function GetRootPart(char) return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") end

local function GetEquippedTool(player, char)
    local tool = char and char:FindFirstChildWhichIsA("Tool")
    if tool then return tool end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then return item end
        end
    end
    return nil
end

local function IsPlayerVisible(char, target)
    if not ESPConfig.VisibilityCheck then return true end
    local origin = CurrentCamera.CFrame.Position
    local dir = target.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, char}
    local res = Workspace:Raycast(origin, dir, params)
    return res == nil
end

local function GetBoundingBox(char)
    local root = GetRootPart(char)
    if not root then return nil end
    local pos, onScreen = CurrentCamera:WorldToViewportPoint(root.Position)
    if not onScreen then return nil end
    local dist = (CurrentCamera.CFrame.Position - root.Position).Magnitude
    local scale = math.clamp(200 / math.max(dist, 1), 0.5, 2)
    local boxHeight = math.clamp(scale * 40, 20, 80)
    local boxWidth = boxHeight * 0.6
    return {
        TopLeft = Vector2.new(pos.X - boxWidth / 2, pos.Y - boxHeight / 2),
        TopRight = Vector2.new(pos.X + boxWidth / 2, pos.Y - boxHeight / 2),
        BottomLeft = Vector2.new(pos.X - boxWidth / 2, pos.Y + boxHeight / 2),
        BottomRight = Vector2.new(pos.X + boxWidth / 2, pos.Y + boxHeight / 2),
        Root = Vector2.new(pos.X, pos.Y),
        Size = Vector2.new(boxWidth, boxHeight)
    }
end

local function GetHealthColor(health, maxHealth)
    local ratio = math.clamp(health / math.max(maxHealth, 1), 0, 1)
    if ratio > 0.6 then return Color3.fromRGB(0, 255, 0)
    elseif ratio > 0.3 then return Color3.fromRGB(255, 255, 0)
    else return Color3.fromRGB(255, 0, 0) end
end

--==================================================
-- ESP DRAWING
--==================================================
local function CreateDrawing(type, props)
    local d = Drawing.new(type)
    for k, v in pairs(props or {}) do
        if d[k] ~= nil then d[k] = v end
    end
    return d
end

local function HideESP(esp)
    for _, draw in pairs(esp.Drawings) do
        if type(draw) == "table" then
            for _, d in pairs(draw) do if d then pcall(function() d.Visible = false end) end
            end
        else
            if draw then pcall(function() draw.Visible = false end) end
        end
    end
    if esp.Highlight then esp.Highlight.Enabled = false end
end

local function RemoveESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    esp.IsValid = false
    for _, conn in pairs(esp.Connections) do if conn then pcall(function() conn:Disconnect() end) end end
    for _, draw in pairs(esp.Drawings) do
        if type(draw) == "table" then
            for _, d in pairs(draw) do if d then pcall(function() d:Remove() end) end end
        else
            if draw then pcall(function() draw:Remove() end) end
        end
    end
    if esp.Highlight then esp.Highlight:Destroy() end
    ESPObjects[player] = nil
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local esp = {Player = player, Drawings = {}, Connections = {}, Character = player.Character, IsValid = true}

    -- Box lines
    for i=1,4 do esp.Drawings["Box"..i] = CreateDrawing("Line",{Thickness=1,Color=ESPConfig.BoxColor,Visible=false}) end

    -- Texts
    esp.Drawings.Name = CreateDrawing("Text",{Text=player.Name,Size=ESPConfig.TextSize,Center=true,Outline=true,Font=ESPConfig.TextFont,Color=ESPConfig.NameColor,Visible=false})
    esp.Drawings.Tool = CreateDrawing("Text",{Text="No Tool",Size=ESPConfig.TextSize-2,Center=true,Outline=true,Font=ESPConfig.TextFont,Color=ESPConfig.ToolColor,Visible=false})
    esp.Drawings.Distance = CreateDrawing("Text",{Text="",Size=ESPConfig.TextSize,Center=true,Outline=true,Font=ESPConfig.TextFont,Color=ESPConfig.DistanceColor,Visible=false})
    esp.Drawings.Health = CreateDrawing("Square",{Filled=true,Thickness=1,Color=ESPConfig.HealthBarColor,Visible=false})

    -- Chams highlight
    if ESPConfig.ChamsEnabled and esp.Character then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = esp.Character
        highlight.FillColor = ESPConfig.ChamsColor
        highlight.FillTransparency = 0.55
        highlight.OutlineTransparency = 1
        highlight.Parent = CoreGui
        esp.Highlight = highlight
    end

    -- Character events
    esp.Connections.CharacterAdded = player.CharacterAdded:Connect(function(char)
        esp.Character = char
        if esp.Highlight then esp.Highlight.Adornee = char esp.Highlight.Enabled = ESPConfig.ChamsEnabled end
    end)
    esp.Connections.CharacterRemoving = player.CharacterRemoving:Connect(function()
        HideESP(esp)
        esp.Character = nil
    end)

    ESPObjects[player] = esp
end

local function UpdateESP(player)
    local esp = ESPObjects[player]
    if not esp or not esp.IsValid then return end
    local character = esp.Character
    if not character then HideESP(esp) return end
    local root = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    if not root or not humanoid or humanoid.Health <= 0 then HideESP(esp) return end

    local dist = (root.Position - CurrentCamera.CFrame.Position).Magnitude
    if dist > ESPConfig.MaxDistance then HideESP(esp) return end
    local visible = IsPlayerVisible(character, root)
    local bbox = GetBoundingBox(character)
    if not bbox then HideESP(esp) return end

    -- Box
    if ESPConfig.BoxEnabled then
        local color = visible and ESPConfig.BoxColor or Color3.fromRGB(255,255,0)
        local corners = {bbox.TopLeft,bbox.TopRight,bbox.BottomRight,bbox.BottomLeft}
        for i=1,4 do
            local line = esp.Drawings["Box"..i]
            if line then line.From=corners[i] line.To=corners[i%4+1] line.Color=color line.Visible=true end
        end
    end

    -- Name
    if ESPConfig.NameEnabled and esp.Drawings.Name then
        esp.Drawings.Name.Position = Vector2.new(bbox.Root.X,bbox.TopLeft.Y-20)
        esp.Drawings.Name.Text = player.Name
        esp.Drawings.Name.Color = ESPConfig.NameColor
        esp.Drawings.Name.Visible = true
    end

    -- Tool
    if ESPConfig.ToolEnabled and esp.Drawings.Tool then
        local tool = GetEquippedTool(player, character)
        esp.Drawings.Tool.Position = Vector2.new(bbox.Root.X,bbox.TopLeft.Y-40)
        esp.Drawings.Tool.Text = tool and ("Tool: "..tool.Name) or "No Tool"
        esp.Drawings.Tool.Color = ESPConfig.ToolColor
        esp.Drawings.Tool.Visible = true
    end

    -- Distance
    if ESPConfig.DistanceEnabled and esp.Drawings.Distance then
        esp.Drawings.Distance.Position = Vector2.new(bbox.Root.X,bbox.BottomLeft.Y+10)
        esp.Drawings.Distance.Text = string.format("%.0f studs",dist)
        esp.Drawings.Distance.Color = ESPConfig.DistanceColor
        esp.Drawings.Distance.Visible = true
    end

    -- Health
    if ESPConfig.HealthBarEnabled and esp.Drawings.Health then
        local hPerc = humanoid.Health / math.max(humanoid.MaxHealth,1)
        esp.Drawings.Health.Position = Vector2.new(bbox.TopLeft.X-6,bbox.BottomLeft.Y-bbox.Size.Y*hPerc)
        esp.Drawings.Health.Size = Vector2.new(4,bbox.Size.Y*hPerc)
        esp.Drawings.Health.Color = GetHealthColor(humanoid.Health,humanoid.MaxHealth)
        esp.Drawings.Health.Visible = true
    end

    -- Chams
    if esp.Highlight then
        esp.Highlight.FillColor = ESPConfig.ChamsColor
        esp.Highlight.Enabled = ESPConfig.ChamsEnabled
    end
end

-- Main render loop
RunService.RenderStepped:Connect(function()
    for player,_ in pairs(ESPObjects) do pcall(UpdateESP,player) end
end)

-- PLAYER MONITORING
local function InitializePlayers()
    for _,player in ipairs(Players:GetPlayers()) do if player~=LocalPlayer then CreateESP(player) end end
    Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player) if player~=LocalPlayer then CreateESP(player) end end)
    Connections.PlayerRemoving = Players.PlayerRemoving:Connect(RemoveESP)
end

--==================================================
-- HELPER: Light UI Particle Accent (UI-based)
--==================================================
local function SpawnUIParticles(container, colorOverride)
    -- container is a Frame or any GuiObject parent (should be one created by Rayfield such as a Section label)
    -- This spawns a few tiny circles that float and fade (lightweight)
    pcall(function()
        if not container then return end
        local limit = 6
        for i = 1, limit do
            spawn(function()
                local dot = Instance.new("ImageLabel")
                dot.Name = "AccentParticle"
                dot.Image = "rbxassetid://3926305904" -- small circle asset (UI)
                dot.ScaleType = Enum.ScaleType.Fit
                dot.Size = UDim2.new(0,6,0,6)
                dot.AnchorPoint = Vector2.new(0.5,0.5)
                dot.BackgroundTransparency = 1
                dot.Position = UDim2.new(math.random(), 0, math.random(), 0)
                dot.ZIndex = 10
                dot.ImageColor3 = colorOverride or ESPConfig.BoxColor
                dot.Parent = container

                local tweenInfo = TweenInfo.new(1.1 + math.random() * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                local targetPos = UDim2.new(math.clamp(dot.Position.X.Scale + (math.random()-0.5)*0.12, 0, 1), 0,
                                            math.clamp(dot.Position.Y.Scale - (0.2 + math.random()*0.3), 0, 1), 0)
                pcall(function()
                    local t1 = TweenService:Create(dot, tweenInfo, {Position = targetPos, Size = UDim2.new(0, 22, 0, 22), ImageTransparency = 1})
                    t1:Play()
                    t1.Completed:Wait()
                end)
                pcall(function() dot:Destroy() end)
            end)
            wait(0.06)
        end
    end)
end

--==================================================
-- PREMIUM RAYFIELD USER INTERFACE + ANIMATIONS
--==================================================
local success, Rayfield = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))() end)
if success and Rayfield then

    -- Accent colors
    local Accent = Color3.fromRGB(0, 170, 255)
    local Glow = Color3.fromRGB(0, 205, 255)

    local Window = Rayfield:CreateWindow({
        Name = "💎 Carbon ESP – Premium Edition",
        LoadingTitle = "Carbon Visual Suite",
        LoadingSubtitle = "Polished, fast, premium",
        Icon = 4483362456,
        Theme = "Dark",
        Acrylic = true,
        Transparency = 0,
        Color = Accent,
        ConfigurationSaving = {Enabled = true, FileName = "CarbonPremiumConfig"}
    })

    -- Create a little internal mapping for animated labels
    local AnimatedLabels = {} -- flag -> label reference

    local function PulseLabel(flag)
        local label = AnimatedLabels[flag]
        if not label then return end
        -- animate scale & text color for a pulse
        local origSize = label.TextSize
        local origColor = label.TextColor3
        local tween1 = TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = Glow})
        tween1:Play()
        spawn(function()
            wait(0.18)
            local tween2 = TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = origColor})
            tween2:Play()
        end)
    end

    -- Matching splash-screen (ScreenGui)
    local function CreateSplash()
        local splashGui = Instance.new("ScreenGui")
        splashGui.Name = "CarbonSplash"
        splashGui.ResetOnSpawn = false
        splashGui.IgnoreGuiInset = true
        splashGui.Parent = CoreGui

        local root = Instance.new("Frame")
        root.Size = UDim2.new(0,540,0,280)
        root.Position = UDim2.new(0.5,0,0.22,0)
        root.AnchorPoint = Vector2.new(0.5,0)
        root.BackgroundTransparency = 0
        root.BackgroundColor3 = Color3.fromRGB(12,12,14)
        root.BorderSizePixel = 0
        root.Parent = splashGui
        root.ClipsDescendants = true

        local uicorner = Instance.new("UICorner", root)
        uicorner.CornerRadius = UDim.new(0,18)

        local logo = Instance.new("TextLabel")
        logo.Size = UDim2.new(1,-40,0,64)
        logo.Position = UDim2.new(0,20,0,18)
        logo.BackgroundTransparency = 1
        logo.Text = "Carbon Visual Suite"
        logo.TextColor3 = Color3.fromRGB(235,235,235)
        logo.Font = Enum.Font.GothamBold
        logo.TextSize = 30
        logo.TextXAlignment = Enum.TextXAlignment.Left
        logo.Parent = root

        local subtitle = Instance.new("TextLabel")
        subtitle.Size = UDim2.new(1,-40,0,26)
        subtitle.Position = UDim2.new(0,20,0,70)
        subtitle.BackgroundTransparency = 1
        subtitle.Text = "Premium ESP • Modern UI • Fast Performance"
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextSize = 15
        subtitle.TextColor3 = Color3.fromRGB(190,190,190)
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.Parent = root

        -- Decorative accent bar
        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0,240,0,6)
        accent.Position = UDim2.new(0,20,0,108)
        accent.BackgroundColor3 = Accent
        accent.BackgroundTransparency = 0
        accent.BorderSizePixel = 0
        accent.Parent = root
        local aCorner = Instance.new("UICorner", accent)
        aCorner.CornerRadius = UDim.new(0,6)

        -- Animated gradient on accent
        local grad = Instance.new("UIGradient", accent)
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Accent),
            ColorSequenceKeypoint.new(1, Glow)
        }
        grad.Rotation = 0

        -- Splash description box
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1,-40,0,84)
        card.Position = UDim2.new(0,20,0,128)
        card.BackgroundColor3 = Color3.fromRGB(18,18,22)
        card.BorderSizePixel = 0
        card.Parent = root
        local cCorner = Instance.new("UICorner", card)
        cCorner.CornerRadius = UDim.new(0,10)

        local cardTxt = Instance.new("TextLabel")
        cardTxt.Size = UDim2.new(1,-24,1,-20)
        cardTxt.Position = UDim2.new(0,12,0,10)
        cardTxt.BackgroundTransparency = 1
        cardTxt.Text = "Welcome to Carbon's Premium ESP.\nElegant visuals, intuitive controls, and minimal overhead. Enjoy."
        cardTxt.TextColor3 = Color3.fromRGB(200,200,200)
        cardTxt.TextSize = 14
        cardTxt.Font = Enum.Font.Gotham
        cardTxt.TextWrapped = true
        cardTxt.Parent = card

        -- Particle accents in splash (makes it feel premium)
        spawn(function() SpawnUIParticles(card, Accent) end)
        spawn(function() SpawnUIParticles(root, Glow) end)

        -- Intro animations
        root.AnchorPoint = Vector2.new(0.5, 0)
        root.Position = UDim2.new(0.5,0,-0.5,0)
        root.Size = UDim2.new(0,540,0,280)
        local inTween = TweenService:Create(root, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0.22,0)})
        local fadeIn = TweenService:Create(root, TweenInfo.new(0.6), {BackgroundTransparency = 0})
        inTween:Play(); fadeIn:Play()
        wait(2.1)
        -- exit animations
        local outTween = TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5,0,-0.6,0), BackgroundTransparency = 1})
        outTween:Play()
        outTween.Completed:Wait()
        splashGui:Destroy()
    end

    -- Create the splash on load (do not block UI creation)
    spawn(CreateSplash)

    -- Create tabs
    local ESPTab = Window:CreateTab("ESP", 4483362456)
    local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362456)

    -- Visual Elements with category divider and small decorative label
    ESPTab:CreateSection("Visual Elements")
    -- custom divider label (fancy)
    ESPTab:CreateLabel("────────────────────────  Visuals  ────────────────────────")

    local toggleList = {
        {"Box ESP", "BoxEnabled"},
        {"Names", "NameEnabled"},
        {"Tools", "ToolEnabled"},
        {"Distance", "DistanceEnabled"},
        {"Health Bars", "HealthBarEnabled"},
        {"Skeleton", "SkeletonEnabled"},
        {"Chams", "ChamsEnabled"},
    }

    for _, t in ipairs(toggleList) do
        -- create a small decorative label per toggle to animate
        ESPTab:CreateLabel(" ") -- spacer
        local flag = t[2]
        local label = ESPTab:CreateLabel(" "..t[1]) -- this returns a label inside Rayfield's layout (used for pulse)
        AnimatedLabels[flag] = label

        ESPTab:CreateToggle({
            Name = t[1],
            CurrentValue = ESPConfig[flag],
            Flag = flag,
            Callback = function(value)
                ESPConfig[flag] = value
                -- pulse animation
                pcall(PulseLabel, flag)
                -- particle accent near visuals area (lightweight)
                spawn(function()
                    -- Try to get the last created section container from CoreGui and spawn particles
                    -- This is a best-effort: runtime chooses a place in UI, particles are lightweight
                    wait(0.02)
                    SpawnUIParticles(label, Accent)
                end)
            end
        })
    end

    -- Divider
    ESPTab:CreateLabel("────────────────────────  Colors  ────────────────────────")
    ESPTab:CreateSection("Color Customization")

    local colorList = {
        {"Box Color", "BoxColor"},
        {"Name Color", "NameColor"},
        {"Tool Color", "ToolColor"},
        {"Distance Color", "DistanceColor"},
        {"Health Color", "HealthBarColor"},
        {"Skeleton Color", "SkeletonColor"},
        {"Chams Color", "ChamsColor"},
    }

    for _, c in ipairs(colorList) do
        local flag = c[2]
        ESPTab:CreateColorPicker({
            Name = c[1],
            Color = ESPConfig[flag],
            Flag = flag,
            Callback = function(color)
                ESPConfig[flag] = color
                -- small particle accent and label pulse on color change
                pcall(PulseLabel, flag)
                spawn(function() SpawnUIParticles(ESPTab, color) end)
            end
        })
    end

    ESPTab:CreateLabel("────────────────────────  Performance  ────────────────────────")
    ESPTab:CreateSection("Performance")

    ESPTab:CreateSlider({
        Name = "ESP Max Distance",
        Min = 50,
        Max = 2000,
        CurrentValue = ESPConfig.MaxDistance,
        Flag = "MaxDistance",
        Callback = function(v) ESPConfig.MaxDistance = v end
    })

    -- Settings tab (with dividers & particle accent)
    SettingsTab:CreateSection("Configuration")
    SettingsTab:CreateLabel("────────────────────────  Settings  ────────────────────────")

    SettingsTab:CreateButton({
        Name = "💾 Save Settings",
        Callback = function() Window:SaveConfiguration() spawn(function() SpawnUIParticles(SettingsTab, Accent) end) end
    })

    SettingsTab:CreateButton({
        Name = "📁 Load Settings",
        Callback = function() Window:LoadConfiguration() spawn(function() SpawnUIParticles(SettingsTab, Glow) end) end
    })

    SettingsTab:CreateParagraph({
        Title = "Premium Carbon ESP",
        Content = "Designed for clarity, speed, and crisp visuals. Tabs animate lightly and accent particles show on interactions."
    })

    -- Quick tab animation when tab is opened/used (best-effort)
    -- Rayfield doesn't expose an official 'TabSelected' in all builds; we add a tiny interaction animation on button click using a utility button
    local function QuickTabPulse(tabName)
        -- Create a temporary floating highlight frame near the screen center to suggest tab animation
        local pulseGui = Instance.new("ScreenGui")
        pulseGui.Name = "TabPulse"
        pulseGui.ResetOnSpawn = false
        pulseGui.Parent = CoreGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 180, 0, 46)
        frame.Position = UDim2.new(0.5, -90, 0.08, 0)
        frame.AnchorPoint = Vector2.new(0.5,0)
        frame.BackgroundTransparency = 1
        frame.Parent = pulseGui

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Opened • "..tabName
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 16
        lbl.TextColor3 = Accent
        lbl.Parent = frame

        local tweenIn = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        local tweenOut = TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundTransparency = 1})
        tweenIn:Play()
        wait(0.8)
        tweenOut:Play()
        tweenOut.Completed:Wait()
        pcall(function() pulseGui:Destroy() end)
    end

    -- Simple UI hook: add a small "open tab" helper button in Settings so user can trigger the demonstration
    SettingsTab:CreateButton({
        Name = "Demo Tab Animation",
        Callback = function()
            QuickTabPulse("ESP")
            SpawnUIParticles(SettingsTab, Glow)
        end
    })
end

-- Initialize players after UI ready
InitializePlayers()
print("💎 Carbon Premium ESP (Animated) Loaded Successfully!")
