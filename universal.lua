--[[ Services ]]--
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--[[ Globals & State Management ]]--
-- Fallback for getgenv() in environments where it might not be available
local sharedState = pcall(getgenv) and getgenv() or {}
local Library = { Flags = {}, activeDropdown = nil, activeKeybind = nil }
local isMobile = UserInputService.TouchEnabled
local componentFuncs = {}
local Lib, ThemeSet

if not sharedState.Config then
    sharedState.Config = {
        AimbotEnabled = false,
        GuiVisible = true,
        AccentColor = Color3.fromRGB(80, 130, 255),
        ToggleKey = Enum.KeyCode.LeftControl,
        Aimbot = {
            Smoothness = 10,
            Fov = 100,
            VisibleCheck = true,
            ShowFovCircle = false,
            TargetClosestPlayer = false,
            TargetPart = "Head",
            TeamCheck = false,
            Triggerbot = false,
            Key = Enum.KeyCode.E,
            ShowMobileButton = true,
        },
        ESP = {
            Enabled = false,
            ShowBoxes = false,
            ShowNames = false,
            ShowHealth = false,
            ShowDistance = false,
            ShowTracers = false,
            TeamCheck = false,
            TracerOrigin = "Bottom",
            EnemyColor = Color3.fromRGB(255, 50, 50),
            TeamColor = Color3.new(0, 1, 0),
        },
        Player = {
            Speed = 16,
            JumpPower = 50,
            InfiniteJump = false,
            FieldOfView = 70,
        },
        Combat = {
            NoRecoil = false,
            RapidFire = false,
            InfiniteAmmo = false, -- Added new config
        },
        BindingFeature = nil, 
    }
end

--[[ Maid Class For Cleanup ]]--
local Maid = {}
Maid.__index = Maid
function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end
function Maid:GiveTask(task)
    if task then table.insert(self._tasks, task) end
    return task
end
function Maid:Destroy()
    for i = #self._tasks, 1, -1 do
        local task = self._tasks[i]
        if typeof(task) == "RBXScriptConnection" then task:Disconnect()
        elseif typeof(task) == "Instance" then task:Destroy()
        elseif type(task) == "function" then pcall(task) end
        table.remove(self._tasks, i)
    end
end
local maid = Maid.new()


--[[  
    UI LIBRARY CORE  
    Handles window creation, themes, and tabs.
]]--
local THEME = {
    MainColor = Color3.fromRGB(0, 180, 255),
    Background = Color3.fromRGB(30, 32, 40),
    ValueColor = Color3.fromRGB(248, 248, 242),
    DropOptionsColor = Color3.fromRGB(68, 71, 90),
    BGTransp = 0.1,
    TextLight = Color3.fromRGB(230, 230, 230),
    TextDark = Color3.fromRGB(107, 107, 107),
    TextMuted = Color3.fromRGB(77, 78, 85),
    ElementBackground = Color3.fromRGB(45, 48, 60),
    ElementInteract = Color3.fromRGB(75, 76, 82),
}

local FONT_SETTINGS = {
    Default = Enum.Font.Gotham,
    Bold = Enum.Font.GothamBold
}

local function create(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties) do
        instance[prop] = value
    end
    return instance
end

function Library:Build(uiData)
    local numTabs = #uiData
    local headerHeight = 68
    local tabButtonHeight = 39
    local padding = 3
    local calculatedTabBarHeight = headerHeight + (numTabs * tabButtonHeight) + (numTabs * padding)

    local Window = { ActiveTab = nil, Flags = Library.Flags }

    local mainSize = isMobile and UDim2.new(0.9, 0, 0.8, 0) or UDim2.new(0, 780, 0, 450)
    
    local ScreenGui = create("ScreenGui", {
        Parent = game:GetService("CoreGui"),
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        ResetOnSpawn = false
    })
    maid:GiveTask(ScreenGui)

    local Main = create("Frame", {
        Name = "Main",
        Parent = ScreenGui,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = mainSize,
        BackgroundColor3 = THEME.Background,
        BackgroundTransparency = THEME.BGTransp,
        BorderSizePixel = 0,
        ZIndex = 1,
        Visible = sharedState.Config.GuiVisible
    })
    create("UICorner", { Parent = Main, CornerRadius = UDim.new(0, 8) })

    local function makeDraggable(gui)
        local dragging = false
        local dragInput
        local dragStart
        local startPos
        local targetPos = gui.Position
        local lerpConnection
        local LERP_SPEED = 0.2

        gui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragInput = input
                dragStart = input.Position
                startPos = gui.Position
                targetPos = gui.Position
                
                if not (lerpConnection and lerpConnection.Connected) then
                    lerpConnection = RunService.RenderStepped:Connect(function()
                        gui.Position = gui.Position:Lerp(targetPos, LERP_SPEED)
                    end)
                end
            end
        end)
        
        gui.InputEnded:Connect(function(input)
            if input == dragInput then
                dragging = false
                if lerpConnection then
                    lerpConnection:Disconnect()
                    lerpConnection = nil
                end
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    makeDraggable(Main)

    local TabBar = create("Frame", { Name = "TabBar", Parent = Main, Position = UDim2.new(0.02, 0, 0.035, 0), Size = UDim2.new(0, 70, 0, calculatedTabBarHeight), BackgroundTransparency = 1, ZIndex = 2 })
    create("UIListLayout", { Parent = TabBar, Padding = UDim.new(0, 3), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })

    local HeaderPFP = create("Frame", { Name = "HeaderPFP", Parent = TabBar, Size = UDim2.new(0, 68, 0, 68), BackgroundColor3 = Color3.fromRGB(45, 48, 62), ZIndex = 2, LayoutOrder = -1, ClipsDescendants = true })
    create("ImageLabel", { Name = "HeaderIcon", Parent = HeaderPFP, Image = "rbxthumb://type=Asset&id=8493766410&w=150&h=150", Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
    create("UICorner", { Parent = HeaderPFP, CornerRadius = UDim.new(1, 0) })

    local NotifHolder = create("Frame", { Name = "NotifHolder", Parent = ScreenGui, Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 300, 1, 0), BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), ZIndex = 9999 })
    create("UIListLayout", { Parent = NotifHolder, Padding = UDim.new(0, 10), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom })

    if isMobile then
        local function makeMobileDraggable(gui)
            local dragging = false
            local dragInput
            local dragStart
            local startPos
            gui.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = gui.Position
                    dragInput = input
                end
            end)
            gui.InputEnded:Connect(function(input)
                if input == dragInput then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if input == dragInput and dragging then
                    local delta = input.Position - dragStart
                    gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
        end
        local MobileToggleHolder = create("Frame", { Name = "MobileToggleHolder", Parent = ScreenGui, Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0.5, -30, 0, 20), BackgroundTransparency = 1, ZIndex = 100, Active = true })
        local MobileToggle = create("ImageButton", { Name = "MobileToggle", Parent = MobileToggleHolder, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Image = "rbxthumb://type=Asset&id=8493766410&w=150&h=150", BackgroundColor3 = THEME.ElementBackground, ZIndex = 102, ScaleType = Enum.ScaleType.Fit, ClipsDescendants = true })
        create("UICorner", { Parent = MobileToggle, CornerRadius = UDim.new(1, 0) })
        create("UIStroke", { Parent = MobileToggle, Color = Color3.fromRGB(80,80,90), Thickness = 1.5})
        MobileToggle.MouseButton1Click:Connect(function() 
            sharedState.Config.GuiVisible = not sharedState.Config.GuiVisible
            Main.Visible = sharedState.Config.GuiVisible
        end)
        makeMobileDraggable(MobileToggleHolder)
    else
        maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == sharedState.Config.ToggleKey then 
                sharedState.Config.GuiVisible = not sharedState.Config.GuiVisible
                Main.Visible = sharedState.Config.GuiVisible
            end
        end))
    end

    function Window:Notify(text, duration)
        duration = duration or 5
        local notification = create("Frame", { Parent = NotifHolder, Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = THEME.Background, BackgroundTransparency = 1, Position = UDim2.new(1.2, 0, 0, 0) })
        notification.ClipsDescendants = true
        create("UICorner", { Parent = notification, CornerRadius = UDim.new(0, 8) })
        local stroke = create("UIStroke", { Parent = notification, Color = THEME.MainColor, Transparency = 1})
        local title = create("TextLabel", { Parent = notification, Position = UDim2.new(0.05, 0, 0.2, 0), Size = UDim2.new(0.9, 0, 0.25, 0), BackgroundTransparency = 1, Font = FONT_SETTINGS.Bold, Text = "Script Hub", TextColor3 = THEME.MainColor, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, TextTransparency = 1 })
        local label = create("TextLabel", { Parent = notification, Position = UDim2.new(0.05, 0, 0.5, 0), Size = UDim2.new(0.9, 0, 0.4, 0), BackgroundTransparency = 1, Font = FONT_SETTINGS.Default, Text = text, TextColor3 = THEME.TextLight, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextSize = 14, TextTransparency = 1 })
        local timerBar = create("Frame", { Parent = notification, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = THEME.MainColor, AnchorPoint = Vector2.new(0, 1), BorderSizePixel = 0 })
        
        local animInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint)
        TweenService:Create(notification, animInfo, {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(stroke, animInfo, {Transparency = 0.5}):Play()
        TweenService:Create(title, animInfo, {TextTransparency = 0}):Play()
        TweenService:Create(label, animInfo, {TextTransparency = 0}):Play()
        notification:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Elastic", 0.5)

        local timerTween = TweenService:Create(timerBar, TweenInfo.new(duration), { Size = UDim2.new(0, 0, 0, 3) }); 
        timerTween:Play()

        timerTween.Completed:Connect(function()
            notification:TweenPosition(UDim2.new(1.2, 0, 0, 0), "In", "Quint", 0.4)
            task.delay(0.4, function() notification:Destroy() end)
        end)
    end

    function Window:checkConflicts(name)
        for _, flag in ipairs(Library.Flags) do
            if flag.Name == name then Window:Notify('"' .. name .. '" is already in use!', 10); return true end
        end
        return false
    end

    function Window:Tab(tabData)
        local canvasSize = UDim2.new(1, -100, 1, -50)
        local tabButton = create("ImageButton", { Parent = TabBar, Size = UDim2.new(1, 0, 0, 39), BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3 })
        local icon = create("ImageLabel", { Parent = tabButton, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 30, 0, 30), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.7, ImageColor3 = Color3.fromRGB(255, 255, 255), Image = "rbxassetid://" .. (tabData.Asset or "0"), ZIndex = 4, ScaleType = Enum.ScaleType.Fit })
        local highlight = create("Frame", { Name = "Highlight", Parent = tabButton, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 6, 0, 36), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, BackgroundColor3 = THEME.MainColor, ZIndex = 4 })
        create("UICorner", { Parent = highlight, CornerRadius = UDim.new(1, 0) })
        local canvas = create("ScrollingFrame", { Parent = Main, Position = UDim2.new(0.15, 0, 0.035, 0), Size = canvasSize, BackgroundTransparency = 1, ScrollBarThickness = 4, ScrollBarImageColor3 = THEME.MainColor, Visible = false, ZIndex = 1 })
        
        if isMobile then
            local canvasLayout = create("UIListLayout", { Parent = canvas, Padding = UDim.new(0, 15), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center })
            local column = create("Frame", { Parent = canvas, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 2 })
            create("UIListLayout", { Parent = column, Padding = UDim.new(0, 15), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center })
            for _, sectionData in ipairs(tabData.Sections) do
                local section = create("Frame", { Parent = column, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = THEME.BGTransp, BackgroundColor3 = THEME.Background })
                create("UICorner", { Parent = section, CornerRadius = UDim.new(0, 6) })
                create("UIListLayout", { Parent = section, Padding = UDim.new(0, 5), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
                local titleHolder = create("Frame", { Name = "TitleHolder", Size = UDim2.new(1, 0, 0, 25), Parent = section, BackgroundTransparency = 1, LayoutOrder = -1})
                create("TextLabel", { Name = "SectionTitle", Parent = titleHolder, Position = UDim2.new(0.046, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0.9, 0, 0.8, 0), BackgroundTransparency = 1, Font = FONT_SETTINGS.Bold, Text = sectionData.Title:upper(), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.MainColor })
                sectionData.Parent = section
            end
        else
            create("UIListLayout", { Parent = canvas, Padding = UDim.new(0, 15), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top })
            local columnWidth = 317
            local leftColumn = create("Frame", { Parent = canvas, Size = UDim2.new(0, columnWidth, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 2 })
            create("UIListLayout", { Parent = leftColumn, Padding = UDim.new(0, 15), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center })
            local rightColumn = create("Frame", { Parent = canvas, Size = UDim2.new(0, columnWidth, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 2 })
            create("UIListLayout", { Parent = rightColumn, Padding = UDim.new(0, 15), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center })
            for _, sectionData in ipairs(tabData.Sections) do
                local parentFrame = sectionData.Side:lower() == "left" and leftColumn or rightColumn
                local section = create("Frame", { Parent = parentFrame, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = THEME.BGTransp, BackgroundColor3 = THEME.Background })
                create("UICorner", { Parent = section, CornerRadius = UDim.new(0, 6) })
                create("UIListLayout", { Parent = section, Padding = UDim.new(0, 5), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
                local titleHolder = create("Frame", { Name = "TitleHolder", Size = UDim2.new(1, 0, 0, 25), Parent = section, BackgroundTransparency = 1, LayoutOrder = -1})
                create("TextLabel", { Name = "SectionTitle", Parent = titleHolder, Position = UDim2.new(0.046, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0.9, 0, 0.8, 0), BackgroundTransparency = 1, Font = FONT_SETTINGS.Bold, Text = sectionData.Title:upper(), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.MainColor })
                sectionData.Parent = section
            end
        end

        local TabInfo = {}; local tweenInfo = TweenInfo.new(0.35)
        function TabInfo:Activate()
            if Window.ActiveTab then Window.ActiveTab:Deactivate() end
            Window.ActiveTab = TabInfo; canvas.Visible = true
            TweenService:Create(highlight, tweenInfo, { BackgroundTransparency = 0 }):Play()
            TweenService:Create(icon, tweenInfo, { ImageTransparency = 0.2, ImageColor3 = THEME.MainColor }):Play()
        end
        function TabInfo:Deactivate()
            canvas.Visible = false
            TweenService:Create(highlight, tweenInfo, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(icon, tweenInfo, { ImageTransparency = 0.7, ImageColor3 = Color3.fromRGB(255, 255, 255) }):Play()
        end
        tabButton.MouseButton1Down:Connect(function() TabInfo:Activate() end)
        if not Window.ActiveTab then TabInfo:Activate() end
        return tabData
    end
    Window.ScreenGui = ScreenGui
    return Window
end

--[[  
    UI COMPONENT FUNCTIONS
    These functions create the individual elements like toggles, sliders, etc.
]]--
local elementHeight = isMobile and 40 or 30
local elementFontSize = isMobile and 16 or 14

function componentFuncs.Toggle(section, options)
    if Lib:checkConflicts(options.Title) then return end
    local info = { Name = options.Title, Value = options.Default, Callback = options.Callback or function() end, Component = "Toggle" }
    local container = create("ImageButton", { Size = UDim2.new(1, -20, 0, elementHeight), Parent = section.Parent, AutoButtonColor = false, BackgroundTransparency = 1 })
    local title = create("TextLabel", { Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0.7, 0, 1, 0), Parent = container, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = options.Title, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.TextDark })
    local switch = create("Frame", { Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 38, 0, 12), Parent = container, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = THEME.ElementBackground })
    create("UICorner", { Parent = switch, CornerRadius = UDim.new(1, 0) })
    local knob = create("Frame", { Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 18, 0, 21), Parent = switch, AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = THEME.ElementInteract })
    create("UICorner", { Parent = knob, CornerRadius = UDim.new(1, 0) })
    create("UIAspectRatioConstraint", { Parent = knob })
    local inner = create("Frame", { Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 12, 0, 12), Parent = knob, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.ElementBackground })
    create("UICorner", { Parent = inner, CornerRadius = UDim.new(1, 0) })
    create("UIAspectRatioConstraint", { Parent = inner })
    local tweenInfo = TweenInfo.new(0.15)
    function info:SetVisual()
        local isEnabled = info.Value
        TweenService:Create(title, tweenInfo, { TextColor3 = isEnabled and THEME.TextLight or THEME.TextDark }):Play()
        TweenService:Create(knob, tweenInfo, { Position = isEnabled and UDim2.new(0.57, 0, 0.5, 0) or UDim2.new(0, 0, 0.5, 0) }):Play()
        TweenService:Create(switch, tweenInfo, { BackgroundColor3 = isEnabled and THEME.MainColor or THEME.ElementBackground, BackgroundTransparency = isEnabled and 0.7 or 0 }):Play()
        TweenService:Create(inner, tweenInfo, { BackgroundColor3 = isEnabled and THEME.MainColor or THEME.ElementBackground }):Play()
        TweenService:Create(knob, tweenInfo, { BackgroundColor3 = isEnabled and THEME.MainColor or THEME.ElementInteract }):Play()
    end
    function info:SetValue(value, noCallback)
        info.Value = value
        info:SetVisual()
        if not noCallback then info.Callback(info.Value) end
    end
    function info:Toggle() info:SetValue(not info.Value) end
    container.MouseButton1Down:Connect(function() 
        if Library.activeKeybind then Library.activeKeybind:StopBinding() end
        info:Toggle() 
    end)
    table.insert(Library.Flags, info)
    info:SetValue(info.Value, true)
end

function componentFuncs.Slider(section, options)
    if Lib:checkConflicts(options.Title) then return end
    local info = { Name = options.Title, Value = options.Default or 0, Min = options.Min or 0, Max = options.Max or 100, Float = options.Float or 1, Suffix = options.Suffix or "", Callback = options.Callback or function() end, Component = "Slider" }
    local main = create("ImageButton", { Size = UDim2.new(1, -20, 0, elementHeight), Parent = section.Parent, BackgroundTransparency = 1, AutoButtonColor = false })
    create("TextLabel", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.5, 0, 1, 0), Parent = main, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = options.Title, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.TextDark })
    local back = create("Frame", { Position = UDim2.new(0.525, 0, 0.5, 0), Size = UDim2.new(0.45, 0, 0, 5), Parent = main, AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = THEME.ElementBackground })
    create("UICorner", { Parent = back, CornerRadius = UDim.new(1, 0) })
    local bar = create("Frame", { Name = "1", Size = UDim2.new(0, 0, 1, 0), Parent = back, BackgroundColor3 = THEME.MainColor })
    create("UICorner", { Parent = bar, CornerRadius = UDim.new(1, 0) })
    local knob = create("Frame", { Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1.5, 0, 1.5, 0), Parent = bar, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
    create("UICorner", { Parent = knob, CornerRadius = UDim.new(1, 0) })
    create("UIAspectRatioConstraint", { Parent = knob })
    local vFrame = create("Frame", { Name = "1", Position = UDim2.new(0.5, 0, 0, -20), Parent = knob, AnchorPoint = Vector2.new(0.5, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = THEME.MainColor, BackgroundTransparency = 1 })
    create("UICorner", { Parent = vFrame, CornerRadius = UDim.new(0, 6) })
    create("UIPadding", { Parent = vFrame, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) })
    local vText = create("TextLabel", { Size = UDim2.new(0, 0, 1, 0), Parent = vFrame, BackgroundTransparency = 1, Font = FONT_SETTINGS.Default, AutomaticSize = Enum.AutomaticSize.X, TextColor3 = THEME.ValueColor, TextTransparency = 1, TextSize = 15 })
    local C
    local function stopDragging()
        if C then
            TweenService:Create(vFrame, TweenInfo.new(.1), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(vText, TweenInfo.new(.1), { TextTransparency = 1 }):Play()
            C:Disconnect()
            C = nil
        end
    end
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then stopDragging() end
    end)
    function info:SetValue(val, noCallback)
        local p = math.clamp((val - info.Min) / (info.Max - info.Min), 0, 1)
        local s = (info.Max - info.Min) / info.Float
        local n = math.floor(p * s + 0.5) / s
        info.Value = info.Min + (info.Max - info.Min) * n
        TweenService:Create(bar, TweenInfo.new(.1), { Size = UDim2.fromScale(n, 1) }):Play()
        local d = tostring(info.Float):match("%.(%d+)")
        local decimalPlaces = d and #d or 0
        vText.Text = string.format("%." .. decimalPlaces .. "f", info.Value) .. info.Suffix
        if not noCallback then info.Callback(info.Value) end
    end
    local function getInputPosition()
        if isMobile then
            local touches = UserInputService:GetTouches()
            if #touches > 0 then return touches[1].Position end
        end
        return UserInputService:GetMouseLocation()
    end
    main.MouseButton1Down:Connect(function()
        if Library.activeKeybind then Library.activeKeybind:StopBinding() end
        stopDragging()
        TweenService:Create(vFrame, TweenInfo.new(.1), { BackgroundTransparency = 0 }):Play()
        TweenService:Create(vText, TweenInfo.new(.1), { TextTransparency = 0 }):Play()
        C = RunService.Heartbeat:Connect(function()
            local inputPos = getInputPosition()
            if not inputPos then return end
            local p = math.clamp((inputPos.X - back.AbsolutePosition.X) / back.AbsoluteSize.X, 0, 1)
            local val = info.Min + (info.Max - info.Min) * p
            info:SetValue(val)
        end)
    end)
    table.insert(Library.Flags, info); info:SetValue(info.Value, true)
end

function componentFuncs.Button(section, options)
    local info = { Callback = options.Callback or function() end }
    local main = create("Frame", { Size = UDim2.new(1, -20, 0, elementHeight), Parent = section.Parent, BackgroundTransparency = 1 })
    create("TextLabel", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.45, 0, 1, 0), Parent = main, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = options.Title, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.TextDark })
    local bgColor = options.isPrimary and THEME.MainColor or THEME.ElementBackground
    local textColor = options.isPrimary and THEME.TextLight or THEME.TextMuted
    local bg = create("ImageButton", { Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.5, 0, 0, 25), Parent = main, BackgroundTransparency = options.isPrimary and 0 or 0.35, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = bgColor })
    create("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 5) })
    local ripple = create("Frame", { Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 0, 1, 0), Parent = bg, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.ElementBackground })
    create("UICorner", { Parent = ripple, CornerRadius = UDim.new(0, 5) })
    local textLabel = create("TextLabel", { Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), Parent = bg, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = options.Text, TextScaled = false, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = textColor })
    bg.MouseButton1Click:Connect(function()
        if Library.activeKeybind then Library.activeKeybind:StopBinding() end
        local r = TweenService:Create(ripple, TweenInfo.new(.2), { Size = UDim2.new(1, 0, 1, 0) }); r.Completed:Connect(function() ripple.Size = UDim2.new(0, 0, 1, 0) end); r:Play(); info.Callback()
    end)
end

function componentFuncs.Keybind(section, options)
    if Lib:checkConflicts(options.Title) then return end
    local info = { Name = options.Title, Value = options.Default or "None", Callback = options.Callback or function() end, Component = "Keybind" }
    local main = create("ImageButton", { Size = UDim2.new(1, -20, 0, elementHeight), Parent = section.Parent, AutoButtonColor = false, BackgroundTransparency = 1 })
    local title = create("TextLabel", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.7, 0, 1, 0), Parent = main, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = options.Title, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.TextDark })
    local bg = create("Frame", { Position = UDim2.fromScale(1, 0.5), Parent = main, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(1, 0.5), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = THEME.ElementBackground })
    create("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 5) })
    create("UIPadding", { Parent = bg, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) })
    local selected = create("TextLabel", { Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 20, 1, 0), Parent = bg, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = THEME.TextMuted })
    
    function info:UpdateKey(key, noCallback)
        local keyName = "None"
        if key and typeof(key) == "EnumItem" then
            keyName = key.Name
        end
        selected.Text = keyName
        info.Value = key
        if not noCallback then info.Callback(key) end
    end
    
    function info:StopBinding(keyWasSet)
        if info.Connection then
            info.Connection:Disconnect()
            info.Connection = nil
        end
        if not keyWasSet then
            info:UpdateKey(info.Value, true) 
        end
        if Library.activeKeybind == info then
            Library.activeKeybind = nil
        end
        TweenService:Create(selected, TweenInfo.new(.2), { TextColor3 = THEME.TextMuted }):Play()
        TweenService:Create(title, TweenInfo.new(.2), { TextColor3 = THEME.TextDark }):Play()
    end
    
    main.MouseButton1Down:Connect(function()
        if info.Connection and info.Connection.Connected then
            info:StopBinding()
            return
        end
        if Library.activeKeybind then
            Library.activeKeybind:StopBinding()
        end

        Library.activeKeybind = info
        selected.Text = "..."
        TweenService:Create(selected, TweenInfo.new(.2), { TextColor3 = THEME.TextLight }):Play()
        TweenService:Create(title, TweenInfo.new(.2), { TextColor3 = THEME.TextLight }):Play()

        info.Connection = UserInputService.InputBegan:Connect(function(i, g)
            if g then return end
            
            local key
            if i.UserInputType.Name:find("MouseButton") then
                key = i.UserInputType
            else
                key = i.KeyCode
            end

            if key == Enum.KeyCode.Backspace then
                info:UpdateKey(nil)
            elseif key ~= Enum.KeyCode.Unknown then
                info:UpdateKey(key)
            end
            info:StopBinding(true) 
        end)
    end)
    
    info:UpdateKey(options.Default, true)
    table.insert(Library.Flags, info)
end

function componentFuncs.Dropdown(section, options)
    local DropInfo = { Name = options.Title, Options = options.Options or {}, Value = options.Default or "None", Callback = options.Callback or function() end, Component = "Dropdown", IsOpen = false }
    if Lib:checkConflicts(options.Title) then return end
    local DropDown = create("ImageButton", { Name = "DropDown", Size = UDim2.new(1, -20, 0, elementHeight), Parent = section.Parent, BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3 })
    local DropDownTitle = create("TextLabel", { Name = "DropDownTitle", Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.5, 0, 1, 0), Parent = DropDown, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = options.Title, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.TextDark })
    local BG = create("Frame", { Name = "BG", Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.45, 0, 0, 25), Parent = DropDown, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = THEME.ElementBackground })
    create("UICorner", { Parent = BG, CornerRadius = UDim.new(0, 5) })
    local SelectedTitle = create("TextLabel", { Name = "SelectedTitle", Position = UDim2.new(0.1, 0, 0.5, 0), Size = UDim2.new(0.8, 0, 0.9, 0), Parent = BG, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Font = FONT_SETTINGS.Default, Text = DropInfo.Value, TextScaled = false, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 120, 120) })
    local Arrow = create("ImageLabel", { Name = "Arrow", Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 15, 0, 15), Parent = BG, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = THEME.TextMuted, Image = "rbxassetid://6034818372", ZIndex = 6 })
    local OptionsHolder = create("Frame", { Name = "OptionsHolder", Position = UDim2.new(0, 0, 1, 5), Size = UDim2.new(1, 0, 0, 0), Parent = BG, AnchorPoint = Vector2.new(0, 0), Visible = false, BackgroundColor3 = THEME.DropOptionsColor, ZIndex = 1000 })
    create("UICorner", { Parent = OptionsHolder, CornerRadius = UDim.new(0, 5) })
    create("UIListLayout", { Parent = OptionsHolder, Padding = UDim.new(0, 2), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center })
    local CurrentOption
    function DropInfo:SetValue(value, noCallback)
        if CurrentOption then CurrentOption.TextColor3 = THEME.TextLight; CurrentOption.Font = FONT_SETTINGS.Default end
        for _, button in ipairs(OptionsHolder:GetChildren()) do
            if button:IsA("TextButton") and button.Text == value then
                CurrentOption = button; button.TextColor3 = THEME.MainColor; button.Font = FONT_SETTINGS.Bold
                SelectedTitle.Text = value; DropInfo.Value = value; 
                if not noCallback then DropInfo.Callback(value) end
                break
            end
        end
    end
    function DropInfo:ToggleVisibility(forceClose)
        DropInfo.IsOpen = forceClose and false or not DropInfo.IsOpen
        OptionsHolder.Visible = DropInfo.IsOpen
        local openSize = #DropInfo.Options * 22 + 4
        local targetSize = DropInfo.IsOpen and UDim2.new(1, 0, 0, openSize) or UDim2.new(1, 0, 0, 0)
        TweenService:Create(OptionsHolder, TweenInfo.new(.15), { Size = targetSize }):Play()
        TweenService:Create(DropDownTitle, TweenInfo.new(.15), { TextColor3 = DropInfo.IsOpen and THEME.TextLight or THEME.TextDark }):Play()
        if DropInfo.IsOpen then
            if Library.activeDropdown and Library.activeDropdown ~= DropInfo then Library.activeDropdown:ToggleVisibility(true) end
            Library.activeDropdown = DropInfo
        elseif Library.activeDropdown == DropInfo then
            Library.activeDropdown = nil
        end
    end
    for _, optionName in ipairs(DropInfo.Options) do
        local optionButton = create("TextButton", { Name = "OptionButton", Size = UDim2.new(1, -10, 0, 20), Parent = OptionsHolder, BackgroundTransparency = 1, Font = FONT_SETTINGS.Default, Text = optionName, TextSize = elementFontSize, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.TextLight, AutoButtonColor = false, ZIndex = 1001 })
        if optionName == DropInfo.Value then DropInfo:SetValue(optionName, true) end
        optionButton.MouseButton1Click:Connect(function() DropInfo:SetValue(optionName); DropInfo:ToggleVisibility(true) end)
    end
    if DropInfo.Callback then DropInfo.Callback(DropInfo.Value) end
    DropDown.MouseButton1Down:Connect(function() 
        if Library.activeKeybind then Library.activeKeybind:StopBinding() end
        DropInfo:ToggleVisibility() 
    end)
    table.insert(Library.Flags, DropInfo)
end

function BuildUIFromData(data)
    for _, tabData in ipairs(data) do
        Lib:Tab(tabData)
        for _, sectionData in ipairs(tabData.Sections) do
            for i = #sectionData.Elements, 1, -1 do
                local elementData = sectionData.Elements[i]
                if (isMobile and elementData.DesktopOnly) or (not isMobile and elementData.MobileOnly) then
                    table.remove(sectionData.Elements, i)
                end
            end
            for _, elementData in ipairs(sectionData.Elements) do
                if componentFuncs[elementData.Type] then
                    componentFuncs[elementData.Type](sectionData, elementData)
                end
            end
        end
    end
end

--[[  
    UI LAYOUT DATA
    Defines the tabs, sections, and elements of the GUI.
]]--
local UI_DATA = {
    { Asset = "10734977012", Sections = { -- AIMBOT
        { Title = "Aimbot Settings", Side = "Left", Elements = {
            { Type = "Toggle", Title = "Aimbot Enabled", Default = sharedState.Config.AimbotEnabled, Callback = function(v) sharedState.Config.AimbotEnabled = v end },
            { Type = "Toggle", Title = "Triggerbot", Default = sharedState.Config.Aimbot.Triggerbot, Callback = function(v) sharedState.Config.Aimbot.Triggerbot = v end },
            { Type = "Keybind", Title = "Aimbot Key", Default = sharedState.Config.Aimbot.Key, Callback = function(v) sharedState.Config.Aimbot.Key = v end, DesktopOnly = true },
            { Type = "Toggle", Title = "Show Aim Button", Default = sharedState.Config.Aimbot.ShowMobileButton, Callback = function(v) sharedState.Config.Aimbot.ShowMobileButton = v end, MobileOnly = true },
            { Type = "Dropdown", Title = "Aim Part", Options = {"Head", "Torso", "HumanoidRootPart"}, Default = sharedState.Config.Aimbot.TargetPart, Callback = function(v) sharedState.Config.Aimbot.TargetPart = v end },
            { Type = "Slider", Title = "Smoothness", Default = sharedState.Config.Aimbot.Smoothness, Min = 1, Max = 20, Float = 1, Callback = function(v) sharedState.Config.Aimbot.Smoothness = v end },
            { Type = "Slider", Title = "FOV", Default = sharedState.Config.Aimbot.Fov, Min = 10, Max = 500, Float = 1, Suffix = "px", Callback = function(v) sharedState.Config.Aimbot.Fov = v end },
        }},
        { Title = "Aimbot Filters", Side = "Right", Elements = {
            { Type = "Toggle", Title = "Show FOV Circle", Default = sharedState.Config.Aimbot.ShowFovCircle, Callback = function(v) sharedState.Config.Aimbot.ShowFovCircle = v end },
            { Type = "Toggle", Title = "Team Check", Default = sharedState.Config.Aimbot.TeamCheck, Callback = function(v) sharedState.Config.Aimbot.TeamCheck = v end },
            { Type = "Toggle", Title = "Visible Check", Default = sharedState.Config.Aimbot.VisibleCheck, Callback = function(v) sharedState.Config.Aimbot.VisibleCheck = v end },
            { Type = "Toggle", Title = "Aim At Closest Player", Default = sharedState.Config.Aimbot.TargetClosestPlayer, Callback = function(v) sharedState.Config.Aimbot.TargetClosestPlayer = v end },
        }},
    }},
    { Asset = "10723346959", Sections = { -- VISUALS
        { Title = "ESP Toggles", Side = "Left", Elements = {
            { Type = "Toggle", Title = "ESP Enabled", Default = sharedState.Config.ESP.Enabled, Callback = function(v) sharedState.Config.ESP.Enabled = v end },
            { Type = "Toggle", Title = "Box ESP", Default = sharedState.Config.ESP.ShowBoxes, Callback = function(v) sharedState.Config.ESP.ShowBoxes = v end },
            { Type = "Toggle", Title = "Name ESP", Default = sharedState.Config.ESP.ShowNames, Callback = function(v) sharedState.Config.ESP.ShowNames = v end },
            { Type = "Toggle", Title = "Health ESP", Default = sharedState.Config.ESP.ShowHealth, Callback = function(v) sharedState.Config.ESP.ShowHealth = v end },
            { Type = "Toggle", Title = "Distance ESP", Default = sharedState.Config.ESP.ShowDistance, Callback = function(v) sharedState.Config.ESP.ShowDistance = v end },
            { Type = "Toggle", Title = "Tracers", Default = sharedState.Config.ESP.ShowTracers, Callback = function(v) sharedState.Config.ESP.ShowTracers = v end },
        }},
        { Title = "ESP Settings", Side = "Right", Elements = {
            { Type = "Toggle", Title = "Team Check", Default = sharedState.Config.ESP.TeamCheck, Callback = function(v) sharedState.Config.ESP.TeamCheck = v end },
            { Type = "Dropdown", Title = "Tracer Origin", Options = {"Bottom", "Middle", "Top"}, Default = sharedState.Config.ESP.TracerOrigin, Callback = function(v) sharedState.Config.ESP.TracerOrigin = v end },
            { Type = "Slider", Title = "Field of View", Default = sharedState.Config.Player.FieldOfView, Min = 70, Max = 120, Float = 1, Callback = function(v) sharedState.Config.Player.FieldOfView = v end },
        }},
    }},
    { Asset = "10734920149", Sections = { -- PLAYER
        { Title = "Movement", Side = "Left", Elements = {
            { Type = "Slider", Title = "WalkSpeed", Default = sharedState.Config.Player.Speed, Min = 16, Max = 200, Float = 1, Callback = function(v) sharedState.Config.Player.Speed = v end },
            { Type = "Slider", Title = "Jump Power", Default = sharedState.Config.Player.JumpPower, Min = 50, Max = 300, Float = 1, Callback = function(v) sharedState.Config.Player.JumpPower = v end },
            { Type = "Toggle", Title = "Infinite Jump", Default = sharedState.Config.Player.InfiniteJump, Callback = function(v) sharedState.Config.Player.InfiniteJump = v end },
        }},
    }},
    { Asset = "10723424505", Sections = { -- COMBAT
        { Title = "Weapon Mods", Side = "Left", Elements = {
            { Type = "Toggle", Title = "No Recoil", Default = sharedState.Config.Combat.NoRecoil, Callback = function(v) sharedState.Config.Combat.NoRecoil = v end },
            { Type = "Toggle", Title = "Rapid Fire", Default = sharedState.Config.Combat.RapidFire, Callback = function(v) sharedState.Config.Combat.RapidFire = v end },
            -- Added Infinite Ammo Toggle to UI
            { Type = "Toggle", Title = "Infinite Ammo", Default = sharedState.Config.Combat.InfiniteAmmo, Callback = function(v) sharedState.Config.Combat.InfiniteAmmo = v end },
        }},
    }},
    { Asset = "10734950309", Sections = { -- SETTINGS
        { Title = "Application", Side = "Left", Elements = {
            { Type = "Keybind", Title = "Toggle UI Key", Default = sharedState.Config.ToggleKey, Callback = function(v) sharedState.Config.ToggleKey = v or Enum.KeyCode.LeftControl end, DesktopOnly = true },
            { Type = "Button", Title = "Kill Script", Text = "Kill", Callback = function() maid:Destroy() end },
            { Type = "Button", Title = "Credits", Text = "Show", Callback = function() Lib:Notify("UI and Features by Auaqa", 5) end },
        }},
    }},
}

--[[  
    MAIN LOGIC & INITIALIZATION
    Builds the UI and runs the feature logic.
]]--

if not (pcall(getgenv) and getgenv().Drawing) then
    warn("Warning: Your executor is missing a Drawing library. ESP will not work.")
end

Lib = Library:Build(UI_DATA)
if not Lib then
    warn("Script Hub UI Failed to build.")
    return
end

BuildUIFromData(UI_DATA)

-- Mobile aimbot button
local MobileAimButton
if isMobile then
    local function makeMobileDraggable(gui)
        local dragging = false
        local dragInput
        local dragStart
        local startPos
        gui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = gui.Position
                dragInput = input
            end
        end)
        gui.InputEnded:Connect(function(input)
            if input == dragInput then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    MobileAimButton = create("ImageButton", {
        Name = "MobileAimButton",
        Parent = Lib.ScreenGui,
        Size = UDim2.new(0, 80, 0, 80),
        Position = UDim2.new(1, -100, 0.5, -40),
        BackgroundColor3 = THEME.ElementBackground,
        BackgroundTransparency = 0.3,
        ZIndex = 101,
        Visible = false,
        ClipsDescendants = true,
    })
    create("UICorner", { Parent = MobileAimButton, CornerRadius = UDim.new(1, 0) })
    create("UIStroke", { Parent = MobileAimButton, Color = Color3.fromRGB(150,150,160), Thickness = 1.5, Transparency = 0.5})
    create("ImageLabel", {
        Parent = MobileAimButton,
        Image = "rbxassetid://6034825941", -- Crosshair icon
        Size = UDim2.fromScale(0.6, 0.6),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ImageColor3 = Color3.new(1,1,1),
        ImageTransparency = 0.3
    })
    makeMobileDraggable(MobileAimButton)
    maid:GiveTask(MobileAimButton)
end

-- FOV Circle
local FovCircle = create("Frame", {
    Parent = Lib.ScreenGui,
    Size = UDim2.fromOffset(sharedState.Config.Aimbot.Fov, sharedState.Config.Aimbot.Fov),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 0.9,
    ZIndex = -1,
    Visible = sharedState.Config.Aimbot.ShowFovCircle
})
create("UIStroke", { Parent = FovCircle, Color = Color3.new(1,1,1), Thickness = 1 })
create("UICorner", { Parent = FovCircle, CornerRadius = UDim.new(1,0) })
maid:GiveTask(FovCircle)

-- ESP Logic
local PlayerDrawings = {}
maid:GiveTask(function()
    for _, drawings in pairs(PlayerDrawings) do
        for _, drawing in pairs(drawings) do pcall(function() drawing:Remove() end) end
    end
    PlayerDrawings = nil
end)

maid:GiveTask(RunService:BindToRenderStep("ScriptHub_ESP", Enum.RenderPriority.Character.Value, function()
    if not PlayerDrawings or not (pcall(getgenv) and getgenv().Drawing) then return end

    for userId, drawings in pairs(PlayerDrawings) do
        local player = Players:GetPlayerByUserId(userId)
        if not (player and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0) then
            for _, drawing in pairs(drawings) do drawing.Visible = false end
        end
    end
    
    if not sharedState.Config.ESP.Enabled then
        for _, drawings in pairs(PlayerDrawings) do
            for _, drawing in pairs(drawings) do drawing.Visible = false end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == Players.LocalPlayer then continue end
        local character = player.Character
        if not character then continue end
        local head, humanoid, rootPart = character:FindFirstChild("Head"), character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
        if not (head and humanoid and rootPart and humanoid.Health > 0) then continue end
        local isTeammate = (player.Team and player.Team == Players.LocalPlayer.Team)
        if sharedState.Config.ESP.TeamCheck and isTeammate then continue end
        
        local headScreenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(head.Position)
        if not onScreen then 
            if PlayerDrawings[player.UserId] then
                for _, drawing in pairs(PlayerDrawings[player.UserId]) do drawing.Visible = false end
            end
            continue 
        end

        local userId = player.UserId
        if not PlayerDrawings[userId] then
            PlayerDrawings[userId] = { Box = Drawing.new("Square"), Name = Drawing.new("Text"), Info = Drawing.new("Text"), Tracer = Drawing.new("Line") }
        end
        local drawings, espColor, distance = PlayerDrawings[userId], isTeammate and sharedState.Config.ESP.TeamColor or sharedState.Config.ESP.EnemyColor, (workspace.CurrentCamera.CFrame.Position - rootPart.Position).magnitude
        local boxHeight = math.abs((workspace.CurrentCamera:WorldToViewportPoint(rootPart.Position - Vector3.new(0,3,0))).Y - headScreenPos.Y)
        local boxWidth = boxHeight * 0.6
        local boxPosition = Vector2.new(headScreenPos.X - boxWidth / 2, headScreenPos.Y)

        if sharedState.Config.ESP.ShowBoxes then drawings.Box.Visible = true; drawings.Box.Color = espColor; drawings.Box.Thickness = 2; drawings.Box.Size = Vector2.new(boxWidth, boxHeight); drawings.Box.Position = boxPosition; drawings.Box.Filled = false else drawings.Box.Visible = false end
        if sharedState.Config.ESP.ShowNames then drawings.Name.Visible = true; drawings.Name.Text = player.Name; drawings.Name.Size = 16; drawings.Name.Color = espColor; drawings.Name.Center = true; drawings.Name.Outline = true; drawings.Name.Position = Vector2.new(headScreenPos.X, boxPosition.Y - 16 - 2) else drawings.Name.Visible = false end
        
        local infoText = ""
        if sharedState.Config.ESP.ShowHealth then infoText = infoText .. "HP: " .. math.floor(humanoid.Health) end
        if sharedState.Config.ESP.ShowDistance then infoText = infoText .. (infoText == "" and "" or " | ") .. math.floor(distance) .. "m" end
        if infoText ~= "" then drawings.Info.Visible = true; drawings.Info.Text = infoText; drawings.Info.Size = 14; drawings.Info.Color = Color3.new(1, 1, 1); drawings.Info.Center = true; drawings.Info.Outline = true; drawings.Info.Position = Vector2.new(headScreenPos.X, boxPosition.Y + boxHeight + 2) else drawings.Info.Visible = false end
        
        if sharedState.Config.ESP.ShowTracers then
            local tracerFrom
            if sharedState.Config.ESP.TracerOrigin == "Top" then tracerFrom = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, 0)
            elseif sharedState.Config.ESP.TracerOrigin == "Middle" then tracerFrom = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
            else tracerFrom = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y) end
            drawings.Tracer.Visible = true; drawings.Tracer.Thickness = 1; drawings.Tracer.Color = espColor; drawings.Tracer.From = tracerFrom; drawings.Tracer.To = Vector2.new(headScreenPos.X, headScreenPos.Y)
        else
            drawings.Tracer.Visible = false
        end
    end
end))

-- Aimbot & Player Mods Logic
local aimbotKeyIsHeld = false
if isMobile and MobileAimButton then
    MobileAimButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then aimbotKeyIsHeld = true end
    end)
    MobileAimButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then aimbotKeyIsHeld = false end
    end)
end

maid:GiveTask(RunService.RenderStepped:Connect(function()
    FovCircle.Visible = sharedState.Config.Aimbot.ShowFovCircle and sharedState.Config.AimbotEnabled
    FovCircle.Size = UDim2.fromOffset(sharedState.Config.Aimbot.Fov, sharedState.Config.Aimbot.Fov)

    if not isMobile then
        aimbotKeyIsHeld = false
        if sharedState.Config.Aimbot.Key and typeof(sharedState.Config.Aimbot.Key) == "EnumItem" then
            if sharedState.Config.Aimbot.Key.EnumType == Enum.KeyCode then
                aimbotKeyIsHeld = UserInputService:IsKeyDown(sharedState.Config.Aimbot.Key)
            elseif sharedState.Config.Aimbot.Key.EnumType == Enum.UserInputType then
                aimbotKeyIsHeld = UserInputService:IsMouseButtonPressed(sharedState.Config.Aimbot.Key)
            end
        end
    elseif MobileAimButton then
        MobileAimButton.Visible = sharedState.Config.AimbotEnabled and sharedState.Config.Aimbot.ShowMobileButton
    end

    if sharedState.Config.AimbotEnabled and aimbotKeyIsHeld then
        local closestPlayer, closestDist = nil, math.huge
        local mouseLocation = UserInputService:GetMouseLocation()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") and player.Character.Humanoid.Health > 0 then
                if sharedState.Config.Aimbot.TeamCheck and Players.LocalPlayer.Team and player.Team == Players.LocalPlayer.Team then continue end
                local targetPart = player.Character:FindFirstChild(sharedState.Config.Aimbot.TargetPart)
                if not targetPart then continue end
                local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPart.Position)
                if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude <= sharedState.Config.Aimbot.Fov / 2 then
                    if sharedState.Config.Aimbot.VisibleCheck then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {Players.LocalPlayer.Character}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local res = workspace:Raycast(workspace.CurrentCamera.CFrame.Position, (targetPart.Position - workspace.CurrentCamera.CFrame.Position), rayParams)
                        if res and res.Instance and not res.Instance:IsDescendantOf(player.Character) then continue end
                    end
                    local dist = sharedState.Config.Aimbot.TargetClosestPlayer and (Players.LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude or (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude
                    if dist < closestDist then closestPlayer, closestDist = player, dist end
                end
            end
        end
        if closestPlayer then
            local targetPart = closestPlayer.Character:FindFirstChild(sharedState.Config.Aimbot.TargetPart)
            if targetPart then
                local targetCFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, targetPart.Position)
                workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCFrame, 1 / math.max(1, sharedState.Config.Aimbot.Smoothness))
            end
        end
    end

    if Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local humanoid = Players.LocalPlayer.Character.Humanoid
        if humanoid.WalkSpeed ~= sharedState.Config.Player.Speed then humanoid.WalkSpeed = sharedState.Config.Player.Speed end
        if humanoid.JumpPower ~= sharedState.Config.Player.JumpPower then humanoid.JumpPower = sharedState.Config.Player.JumpPower end
        if workspace.CurrentCamera.FieldOfView ~= sharedState.Config.Player.FieldOfView then workspace.CurrentCamera.FieldOfView = sharedState.Config.Player.FieldOfView end
    end
end))

maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if sharedState.Config.Player.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        if Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

--[[
    NEWLY IMPLEMENTED COMBAT FEATURES
    This section handles the logic for No Recoil, Rapid Fire, and Infinite Ammo.
]]--

-- No Recoil & Infinite Ammo Logic (runs every frame)
maid:GiveTask(RunService.Heartbeat:Connect(function()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer.Character
    local camera = workspace.CurrentCamera

    -- No Recoil
    if sharedState.Config.Combat.NoRecoil and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        -- This counteracts vertical camera movement (recoil) by applying a small downward rotation.
        -- The value '0.1' might need tuning depending on the game's recoil strength.
        camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-0.1), 0, 0)
    end

    -- Infinite Ammo
    if sharedState.Config.Combat.InfiniteAmmo and character then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            -- Recursively search for any value object named "Ammo" inside the tool.
            local ammo = tool:FindFirstChild("Ammo", true)
            if ammo and ammo:IsA("ValueBase") then
                -- Constantly set the ammo to a high value.
                ammo.Value = 999
            end
        end
    end
end))

-- Rapid Fire Logic
maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not sharedState.Config.Combat.RapidFire then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- We run this in a new thread so it doesn't interrupt other game processes.
        task.spawn(function()
            local character = Players.LocalPlayer.Character
            -- The loop continues as long as the mouse button is held down and the feature is enabled.
            while sharedState.Config.Combat.RapidFire and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                if character then
                    local tool = character:FindFirstChildOfClass("Tool")
                    if tool and tool:IsA("Tool") and tool.Enabled then
                        -- Repeatedly call the tool's Activate function to simulate rapid clicking.
                        tool:Activate()
                    end
                end
                task.wait() -- A small delay is crucial to prevent crashing.
            end
        end)
    end
end))


