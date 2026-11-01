--!nocheck
--==================================================================
-- DB 3D Spatial UI · Standalone
-- 獨立三欄 3D 空間 UI 框架
--
-- [更新] 支援點擊左/右面板，自動切換焦點至中間，其餘面板平滑移位。
--==================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat task.wait(0.1) until Players.LocalPlayer
    LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function GetGuiRoot()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    return PlayerGui
end
local GuiRoot = GetGuiRoot()

--==================================================================
-- 配置与状态
--==================================================================
local API = {}

local Assets = { Logo = "rbxassetid://0" }

local Config = {
    Style = "默认",           
    Border = "默认",          
    WorldAnchored = false,
    AnchorOffsetX = 0,
    AnchorOffsetY = 0,
    LogoBackground = true,
    UI_SCALE = 0.60,          
}

local PANEL_DEPTH = 0.03
local BORDER_COLORS = {
    ["默认"] = Color3.fromRGB(0, 0, 0),
    ["黄色"] = Color3.fromRGB(255, 220, 80),
    ["绿色"] = Color3.fromRGB(82, 235, 133),
    ["红色"] = Color3.fromRGB(255, 93, 111),
    ["紫色"] = Color3.fromRGB(183, 116, 255),
    ["白色"] = Color3.fromRGB(238, 242, 250),
    ["橙色"] = Color3.fromRGB(255, 158, 74),
}

local RAINBOW_COLORS = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(224, 42, 92)),
    ColorSequenceKeypoint.new(0.14, Color3.fromRGB(232, 132, 42)),
    ColorSequenceKeypoint.new(0.28, Color3.fromRGB(220, 198, 55)),
    ColorSequenceKeypoint.new(0.43, Color3.fromRGB(50, 205, 128)),
    ColorSequenceKeypoint.new(0.58, Color3.fromRGB(38, 184, 224)),
    ColorSequenceKeypoint.new(0.72, Color3.fromRGB(82, 92, 220)),
    ColorSequenceKeypoint.new(0.86, Color3.fromRGB(194, 55, 220)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(224, 42, 92)),
})

local S = {
    Enabled = false,
    Closing = false,
    Progress = 0,
    Velocity = 0,
    LookVector = nil,
    UpVector = nil,
    Folder = nil,
    Surfaces = {},
    Minimized = false,
    MinimizeTarget = 0,
    MinimizeProgress = 0,
    MinimizeVelocity = 0,
    AnchorTarget = false,
    AnchorBlend = 0,
    AnchorVelocity = 0,
    AnchorLayout = nil,
    Blur = nil,
    BlurOwned = false,
    JoystickTouch = false,
    JoystickInputs = {},
    CurrentPage = "welcome",
    BackGhostAccumulator = 0,
    RenderConnection = nil,
    Pages = {},
    NavButtons = {},
    Mini = nil,
    FocusName = "Center", -- [新增] 當前焦點面板：Left / Center / Right
}

--==================================================================
-- 工具
--==================================================================
local function AddCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

local function StartRainbowFlow(parent, duration)
    local grad = Instance.new("UIGradient")
    grad.Name = "RainbowFlow"
    grad.Color = RAINBOW_COLORS
    grad.Rotation = -180
    grad.Parent = parent
    TweenService:Create(grad, TweenInfo.new(duration or 2.75, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0), { Rotation = 180 }):Play()
    return grad
end

local function WireButton(button, callback)
    local last = 0
    local activeInput = nil
    local startPos = nil
    local startedAt = 0
    local moved = false
    local moveLimit = 20
    local MAX_HOLD = 0.68
    local function fire()
        local now = os.clock()
        if now - last < 0.14 then return end
        last = now
        pcall(callback)
    end
    local function reset()
        activeInput = nil; startPos = nil; startedAt = 0; moved = false
    end
    local function matchesEnd(input)
        if not activeInput then return false end
        if activeInput.UserInputType == Enum.UserInputType.Touch then return input == activeInput end
        return input.UserInputType == Enum.UserInputType.MouseButton1
    end
    button.InputBegan:Connect(function(input)
        if not S.Enabled or S.Closing then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        activeInput = input
        startPos = Vector2.new(input.Position.X, input.Position.Y)
        startedAt = os.clock()
        moved = false
        local cam = workspace.CurrentCamera
        local vh = (cam and cam.ViewportSize.Y) or 720
        moveLimit = math.clamp(vh * 0.028, 16, 24)
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not activeInput or not startPos then return end
        local pos = nil
        if activeInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= activeInput then return end
            pos = Vector2.new(input.Position.X, input.Position.Y)
        else
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            pos = Vector2.new(input.Position.X, input.Position.Y)
        end
        if pos and (pos - startPos).Magnitude > moveLimit then moved = true end
    end)
    local function finish(input)
        if not matchesEnd(input) then return end
        local held = os.clock() - startedAt
        local okTap = (not moved) and held <= MAX_HOLD and S.Enabled and not S.Closing
        reset()
        if okTap then fire() end
    end
    button.InputEnded:Connect(finish)
    UserInputService.InputEnded:Connect(finish)
    return button
end

UserInputService.InputBegan:Connect(function(input)
    if not S.Enabled or input.UserInputType ~= Enum.UserInputType.Touch then return end
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize
    if not vp then return end
    if input.Position.X <= vp.X * 0.36 and input.Position.Y >= vp.Y * 0.53 then
        S.JoystickInputs[input] = true
        S.JoystickTouch = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if S.JoystickInputs[input] then
        S.JoystickInputs[input] = nil
        S.JoystickTouch = next(S.JoystickInputs) ~= nil
    end
end)

--==================================================================
-- 创建 Part 与 SurfaceGui
--==================================================================
local function RemoveStale()
    local old = workspace:FindFirstChild("DB_3D_UI_Framework")
    if old then pcall(function() old:Destroy() end) end
    for _, child in ipairs(GuiRoot:GetChildren()) do
        if child:IsA("SurfaceGui") and child.Name:find("DB_3DUI_", 1, true) then
            pcall(function() child:Destroy() end)
        end
    end
end

local function MakePart(name, w, h)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = true
    p.CastShadow = false
    p.Transparency = 1
    p.Color = Color3.fromRGB(12, 15, 22)
    p.Material = Enum.Material.SmoothPlastic
    p.Size = Vector3.new(w, h, PANEL_DEPTH)
    p.Parent = S.Folder
    return p
end

local function MakeSurface(name, wStud, hStud, canvasW, canvasH)
    local part = MakePart("DB_3DUI_" .. name .. "_Panel", wStud, hStud)

    local front = Instance.new("SurfaceGui")
    front.ResetOnSpawn = false
    front.Name = "DB_3DUI_" .. name
    front.Adornee = part
    front.Face = Enum.NormalId.Front
    front.Active = true
    front.AlwaysOnTop = (name == "Center")
    front.LightInfluence = 0
    front.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    front.CanvasSize = Vector2.new(canvasW, canvasH)
    front.ClipsDescendants = false
    front.MaxDistance = 0
    front.ZOffset = (name == "Center" and 0.055 or 0.018)
    front.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    front.Parent = GuiRoot

    local back = Instance.new("SurfaceGui")
    back.ResetOnSpawn = false
    back.Name = "DB_3DUI_" .. name .. "_Back"
    back.Adornee = part
    back.Face = Enum.NormalId.Back
    back.Active = false
    back.AlwaysOnTop = false
    back.LightInfluence = 0
    back.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    back.CanvasSize = Vector2.new(canvasW, canvasH)
    back.ClipsDescendants = false
    back.MaxDistance = 0
    back.ZOffset = 0.010
    back.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    back.Parent = GuiRoot

    local root = Instance.new("Frame")
    root.Name = "GlassRoot"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
    root.BackgroundTransparency = (name == "Center" and 0.09 or 0.17)
    root.BorderSizePixel = 0
    root.ClipsDescendants = true
    root.Active = true
    root.ZIndex = 10
    root.Parent = front
    AddCorner(root, 20)

    -- [新增] 點擊面板切換焦點
    root.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if S.Enabled and not S.Closing and S.FocusName ~= name then
                S.FocusName = name
            end
        end
    end)

    local borderHost = Instance.new("Frame")
    borderHost.Position = UDim2.fromOffset(3, 3)
    borderHost.Size = UDim2.new(1, -6, 1, -6)
    borderHost.BackgroundTransparency = 1
    borderHost.BorderSizePixel = 0
    borderHost.ZIndex = 250
    borderHost.Parent = root
    AddCorner(borderHost, 18)

    local stroke = Instance.new("UIStroke")
    stroke.Name = "StaticBorder"
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1.55
    stroke.Transparency = 0.24
    stroke.Color = Color3.new(1, 1, 1)
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = borderHost

    local grad = Instance.new("UIGradient")
    grad.Color = RAINBOW_COLORS
    grad.Transparency = NumberSequence.new(0)
    grad.Rotation = -180
    grad.Enabled = false
    grad.Parent = stroke
    TweenService:Create(grad, TweenInfo.new(2.75, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0), { Rotation = 180 }):Play()

    local logoBg = Instance.new("ImageLabel")
    logoBg.Name = "LogoBg"
    logoBg.AnchorPoint = Vector2.new(0.5, 0.5)
    logoBg.Position = UDim2.fromScale(0.5, 0.54)
    logoBg.Size = UDim2.fromScale(name == "Center" and 0.42 or 0.48, name == "Center" and 0.50 or 0.54)
    logoBg.BackgroundTransparency = 1
    logoBg.BorderSizePixel = 0
    logoBg.Image = Assets.Logo
    logoBg.ImageColor3 = Color3.fromRGB(184, 194, 218)
    logoBg.ImageTransparency = 0.80
    logoBg.ScaleType = Enum.ScaleType.Fit
    logoBg.Active = false
    logoBg.ZIndex = 12
    logoBg.Visible = (Assets.Logo ~= "rbxassetid://0") and Config.LogoBackground
    logoBg.Parent = root

    local header = Instance.new("Frame")
    header.Position = UDim2.fromOffset(8, 7)
    header.Size = UDim2.new(1, -16, 0, 30)
    header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    header.BackgroundTransparency = 0.90
    header.BorderSizePixel = 0
    header.ZIndex = 30
    header.Active = true
    header.Parent = root
    AddCorner(header, 11)

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(10, 0)
    title.Size = UDim2.new(1, -20, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(248, 250, 255)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.ZIndex = 33
    title.Parent = header

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(8, 42)
    content.Size = UDim2.new(1, -16, 1, -50)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Active = true
    content.ZIndex = 20
    content.Parent = root

    local pack = {
        Name = name, Part = part, Front = front, Back = back,
        Root = root, Header = header, Title = title, ContentHost = content,
        BorderStroke = stroke, BorderGradient = grad, LogoBg = logoBg,
        WidthStud = wStud, HeightStud = hStud, BackGhost = nil,
    }
    S.Surfaces[name] = pack
    return pack
end

local function MakeMini(scale)
    scale = scale or 1
    local part = MakePart("DB_3DUI_MiniButton", 2.04 * scale, 0.52 * scale)
    local front = Instance.new("SurfaceGui")
    front.ResetOnSpawn = false
    front.Name = "DB_3DUI_Mini"
    front.Adornee = part
    front.Face = Enum.NormalId.Front
    front.Active = true
    front.AlwaysOnTop = true
    front.LightInfluence = 0
    front.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    front.CanvasSize = Vector2.new(230, 58)
    front.ZOffset = 0.04
    front.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    front.Enabled = false
    front.Parent = GuiRoot

    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
    root.BackgroundTransparency = 0.09
    root.BorderSizePixel = 0
    root.ClipsDescendants = true
    root.Active = true
    root.ZIndex = 10
    root.Parent = front
    AddCorner(root, 999)

    local border = Instance.new("Frame")
    border.Position = UDim2.fromOffset(3, 3)
    border.Size = UDim2.new(1, -6, 1, -6)
    border.BackgroundTransparency = 1
    border.BorderSizePixel = 0
    border.ZIndex = 30
    border.Parent = root
    AddCorner(border, 999)
    local miniStroke = Instance.new("UIStroke")
    miniStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    miniStroke.Thickness = 1.05
    miniStroke.Transparency = 0.56
    miniStroke.Color = Color3.fromRGB(214, 222, 235)
    miniStroke.LineJoinMode = Enum.LineJoinMode.Round
    miniStroke.Parent = border

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromScale(1, 1)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Text = "DB脚本  ·  展开空间面板"
    button.TextColor3 = Color3.fromRGB(250, 250, 253)
    button.TextSize = 13
    button.Font = Enum.Font.GothamBlack
    button.AutoButtonColor = false
    button.Active = true
    button.ZIndex = 35
    button.Parent = root
    WireButton(button, function()
        S.Minimized = false
        S.MinimizeTarget = 0
    end)

    S.Mini = { Part = part, Front = front, Root = root, Button = button, WidthStud = 2.04 * scale, HeightStud = 0.52 * scale }
    return S.Mini
end

--==================================================================
-- 边框样式
--==================================================================
local function RefreshBorderStyle()
    for _, pack in pairs(S.Surfaces) do
        if pack.BorderStroke and pack.BorderGradient then
            if Config.Border == "彩虹" then
                pack.BorderStroke.Color = Color3.new(1, 1, 1)
                pack.BorderStroke.Transparency = 0.18
                pack.BorderGradient.Enabled = true
                pack.BorderGradient.Color = RAINBOW_COLORS
            else
                pack.BorderGradient.Enabled = false
                pack.BorderStroke.Color = BORDER_COLORS[Config.Border] or Color3.fromRGB(0, 0, 0)
                pack.BorderStroke.Transparency = (Config.Border == "默认") and 0.16 or 0.34
            end
        end
    end
end

--==================================================================
-- 内容注入工具
--==================================================================
local function ClearHost(host)
    for _, child in ipairs(host:GetChildren()) do
        child:Destroy()
    end
end

local function MakeHostScroll(host)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(200, 210, 230)
    scroll.ScrollBarImageTransparency = 0.40
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.Active = true
    scroll.ZIndex = 22
    scroll.Parent = host
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = scroll
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)
    pad.Parent = scroll
    return scroll
end

local function MakeSectionLabel(parent, text, height)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, height or 22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(160, 200, 255)
    label.TextSize = 11
    label.Font = Enum.Font.GothamBlack
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 24
    label.Parent = parent
    return label
end

local function MakeActionButton(parent, label, height, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, height or 32)
    btn.BackgroundColor3 = Color3.fromRGB(48, 50, 60)
    btn.BackgroundTransparency = 0.10
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(248, 250, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.AutoButtonColor = false
    btn.ZIndex = 24
    btn.Parent = parent
    AddCorner(btn, 8)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 0.8
    stroke.Transparency = 0.55
    stroke.Color = Color3.fromRGB(220, 230, 245)
    stroke.Parent = btn
    WireButton(btn, callback)
    return btn
end

local function MakeCard(parent, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, height or 60)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.88
    card.BorderSizePixel = 0
    card.ZIndex = 22
    card.Parent = parent
    AddCorner(card, 10)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 0.75
    stroke.Transparency = 0.65
    stroke.Color = Color3.fromRGB(220, 230, 245)
    stroke.Parent = card
    return card
end

--==================================================================
-- 默认页面
--==================================================================
local function BuildPlayerInfo(pack)
    local host = pack.ContentHost
    ClearHost(host)
    local scroll = MakeHostScroll(host)

    local card = MakeCard(scroll, 230)
    card.LayoutOrder = 1

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(10, 8)
    title.Size = UDim2.new(1, -20, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "玩家信息"
    title.TextColor3 = Color3.fromRGB(250, 250, 253)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 24
    title.Parent = card

    local avatar = Instance.new("ImageLabel")
    avatar.Position = UDim2.fromOffset(10, 32)
    avatar.Size = UDim2.new(1, -20, 0, 100)
    avatar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    avatar.BackgroundTransparency = 0.85
    avatar.BorderSizePixel = 0
    avatar.ScaleType = Enum.ScaleType.Crop
    avatar.ZIndex = 24
    avatar.Parent = card
    AddCorner(avatar, 8)
    local avatarStroke = Instance.new("UIStroke")
    avatarStroke.Thickness = 1.2
    avatarStroke.Transparency = 0.18
    avatarStroke.Color = Color3.fromRGB(220, 225, 235)
    avatarStroke.Parent = avatar

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Position = UDim2.fromOffset(10, 138)
    nameLabel.Size = UDim2.new(1, -20, 0, 26)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = LocalPlayer.DisplayName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 24
    nameLabel.Parent = card

    local userLabel = Instance.new("TextLabel")
    userLabel.Position = UDim2.fromOffset(10, 162)
    userLabel.Size = UDim2.new(1, -20, 0, 18)
    userLabel.BackgroundTransparency = 1
    userLabel.Text = "@" .. LocalPlayer.Name
    userLabel.TextColor3 = Color3.fromRGB(200, 205, 215)
    userLabel.TextSize = 9
    userLabel.Font = Enum.Font.GothamMedium
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.TextTruncate = Enum.TextTruncate.AtEnd
    userLabel.ZIndex = 24
    userLabel.Parent = card

    local ageLabel = Instance.new("TextLabel")
    ageLabel.Position = UDim2.fromOffset(10, 184)
    ageLabel.Size = UDim2.new(1, -20, 0, 18)
    ageLabel.BackgroundTransparency = 1
    ageLabel.Text = "账号年龄：" .. tostring(LocalPlayer.AccountAge) .. " 天"
    ageLabel.TextColor3 = Color3.fromRGB(200, 205, 215)
    ageLabel.TextSize = 9
    ageLabel.Font = Enum.Font.GothamMedium
    ageLabel.TextXAlignment = Enum.TextXAlignment.Left
    ageLabel.ZIndex = 24
    ageLabel.Parent = card

    local idLabel = Instance.new("TextLabel")
    idLabel.Position = UDim2.fromOffset(10, 202)
    idLabel.Size = UDim2.new(1, -20, 0, 18)
    idLabel.BackgroundTransparency = 1
    idLabel.Text = "用户ID：" .. tostring(LocalPlayer.UserId)
    idLabel.TextColor3 = Color3.fromRGB(180, 185, 195)
    idLabel.TextSize = 8
    idLabel.Font = Enum.Font.GothamMedium
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.ZIndex = 24
    idLabel.Parent = card

    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok and avatar.Parent then avatar.Image = content end
    end)
end

local function BuildNavPane(pack)
    local host = pack.ContentHost
    ClearHost(host)
    local scroll = MakeHostScroll(host)

    local function AddNav(label, pageName, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 34)
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundTransparency = 0.86
        btn.BorderSizePixel = 0
        btn.Text = label
        btn.TextColor3 = Color3.fromRGB(248, 250, 253)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.LayoutOrder = order
        btn.ZIndex = 24
        btn.Parent = scroll
        AddCorner(btn, 9)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)
        pad.Parent = btn
        WireButton(btn, function() API.ShowPage(pageName) end)
        if pageName == S.CurrentPage then btn.BackgroundTransparency = 0.55 end
        table.insert(S.NavButtons, { Button = btn, Page = pageName })
    end

    local order = 1
    local hasDefault = false
    for name, _ in pairs(S.Pages) do
        if name == "welcome" or name == "settings" or name == "about" then hasDefault = true end
    end
    if hasDefault or next(S.Pages) ~= nil then
        if S.Pages.welcome then AddNav("主页", "welcome", order); order = order + 1 end
        if S.Pages.settings then AddNav("设置", "settings", order); order = order + 1 end
        if S.Pages.about then AddNav("关于", "about", order); order = order + 1 end
        for name, _ in pairs(S.Pages) do
            if name ~= "welcome" and name ~= "settings" and name ~= "about" then
                AddNav(name, name, order)
                order = order + 1
            end
        end
    end
end

local function BuildWelcomePage(host)
    local scroll = MakeHostScroll(host)
    MakeSectionLabel(scroll, "DB 3D 空间 UI", 28)
    local intro = MakeCard(scroll, 130)
    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(14, 12)
    t.Size = UDim2.new(1, -28, 1, -20)
    t.BackgroundTransparency = 1
    t.Text = "欢迎使用 DB 3D 空间 UI 框架\n\n· 支持点击两侧面板切换焦点\n· 支持跟随镜头 / 世界锚定切换\n· 支持 UI 样式 / 边框描边自定义\n· 通过 RegisterPage 注入业务内容"
    t.TextColor3 = Color3.fromRGB(230, 235, 245)
    t.TextSize = 11
    t.Font = Enum.Font.GothamMedium
    t.TextWrapped = true
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Top
    t.ZIndex = 24
    t.Parent = intro
end

local function BuildSettingsPage(host)
    local scroll = MakeHostScroll(host)

    MakeSectionLabel(scroll, "UI 尺寸缩放 (解決過大)")
    local scaleBtn
    local function refreshScaleBtn()
        if scaleBtn and scaleBtn.Parent then
            scaleBtn.Text = string.format("当前缩放：%.2f (点击切换)", Config.UI_SCALE)
        end
    end
    scaleBtn = MakeActionButton(scroll, string.format("当前缩放：%.2f (点击切换)", Config.UI_SCALE), 34, function()
        Config.UI_SCALE = Config.UI_SCALE - 0.05
        if Config.UI_SCALE < 0.35 then Config.UI_SCALE = 1.0 end
        
        local narrowMode = (Config.Style == "中宽两窄")
        local function updatePackSize(name, bw, bh)
            local p = S.Surfaces[name]
            if p then
                p.WidthStud = bw * Config.UI_SCALE
                p.HeightStud = bh * Config.UI_SCALE
            end
        end
        if narrowMode then
            updatePackSize("Left", 2.28, 4.08)
            updatePackSize("Center", 5.72, 4.28)
            updatePackSize("Right", 2.28, 4.08)
        else
            updatePackSize("Left", 4.28, 4.02)
            updatePackSize("Center", 5.72, 4.28)
            updatePackSize("Right", 4.36, 4.06)
        end
        if S.Mini then
            S.Mini.WidthStud = 2.04 * Config.UI_SCALE
            S.Mini.HeightStud = 0.52 * Config.UI_SCALE
        end
        refreshScaleBtn()
    end)

    MakeSectionLabel(scroll, "UI 样式")
    local styleOptions = { "默认", "中宽两窄" }
    local styleIdx = 1
    for i, name in ipairs(styleOptions) do if name == Config.Style then styleIdx = i end end
    local styleBtn
    styleBtn = MakeActionButton(scroll, "当前样式：" .. Config.Style, 34, function()
        styleIdx = (styleIdx % #styleOptions) + 1
        Config.Style = styleOptions[styleIdx]
        API.SetStyle(Config.Style)
        styleBtn.Text = "当前样式：" .. Config.Style
    end)

    MakeSectionLabel(scroll, "边框描边")
    local borderOptions = { "默认", "彩虹", "黄色", "绿色", "红色", "紫色", "白色", "橙色" }
    local borderIdx = 1
    for i, name in ipairs(borderOptions) do if name == Config.Border then borderIdx = i end end
    local borderBtn
    borderBtn = MakeActionButton(scroll, "当前边框：" .. Config.Border, 34, function()
        borderIdx = (borderIdx % #borderOptions) + 1
        Config.Border = borderOptions[borderIdx]
        RefreshBorderStyle()
        borderBtn.Text = "当前边框：" .. Config.Border
    end)

    MakeSectionLabel(scroll, "世界锚定")
    local anchorBtn
    local function refreshAnchorBtn()
        if anchorBtn and anchorBtn.Parent then
            anchorBtn.Text = Config.WorldAnchored and "已锚定在世界坐标（点击解除）" or "跟随镜头（点击固定到世界）"
        end
    end
    anchorBtn = MakeActionButton(scroll, Config.WorldAnchored and "已锚定在世界坐标（点击解除）" or "跟随镜头（点击固定到世界）", 34, function()
        Config.WorldAnchored = not Config.WorldAnchored
        S.AnchorTarget = Config.WorldAnchored
        if Config.WorldAnchored then S.AnchorLayout = API.BuildAnchorLayout() end
        refreshAnchorBtn()
    end)

    MakeSectionLabel(scroll, "锚定位置微调")
    local offsetLabel = Instance.new("TextLabel")
    offsetLabel.Size = UDim2.new(1, -8, 0, 22)
    offsetLabel.BackgroundTransparency = 1
    offsetLabel.Text = string.format("偏移：X = %.2f · Y = %.2f", Config.AnchorOffsetX, Config.AnchorOffsetY)
    offsetLabel.TextColor3 = Color3.fromRGB(220, 230, 245)
    offsetLabel.TextSize = 11
    offsetLabel.Font = Enum.Font.GothamBold
    offsetLabel.ZIndex = 24
    offsetLabel.Parent = scroll

    local function adjustOffset(dx, dy)
        Config.AnchorOffsetX = math.clamp(Config.AnchorOffsetX + dx, -4.0, 4.0)
        Config.AnchorOffsetY = math.clamp(Config.AnchorOffsetY + dy, -3.0, 3.0)
        offsetLabel.Text = string.format("偏移：X = %.2f · Y = %.2f", Config.AnchorOffsetX, Config.AnchorOffsetY)
        if Config.WorldAnchored then S.AnchorLayout = API.BuildAnchorLayout() end
    end

    local row1 = Instance.new("Frame")
    row1.Size = UDim2.new(1, -8, 0, 40)
    row1.BackgroundTransparency = 1
    row1.ZIndex = 24
    row1.Parent = scroll
    local function makeDirBtn(label, x, w, dx, dy)
        local btn = Instance.new("TextButton")
        btn.Position = UDim2.new(x, 0, 0, 0)
        btn.Size = UDim2.new(w, -4, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(48, 50, 60)
        btn.BackgroundTransparency = 0.10
        btn.BorderSizePixel = 0
        btn.Text = label
        btn.TextColor3 = Color3.fromRGB(248, 250, 255)
        btn.TextSize = 16
        btn.Font = Enum.Font.GothamBlack
        btn.AutoButtonColor = false
        btn.ZIndex = 25
        btn.Parent = row1
        AddCorner(btn, 8)
        WireButton(btn, function() adjustOffset(dx, dy) end)
        return btn
    end
    makeDirBtn("←", 0, 0.25, -0.14, 0)
    makeDirBtn("↑", 0.25, 0.25, 0, 0.12)
    makeDirBtn("↓", 0.5, 0.25, 0, -0.12)
    makeDirBtn("→", 0.75, 0.25, 0.14, 0)

    MakeSectionLabel(scroll, "其他")
    MakeActionButton(scroll, "关闭 3D UI", 34, function() API.Destroy() end)
end

local function BuildAboutPage(host)
    local scroll = MakeHostScroll(host)
    MakeSectionLabel(scroll, "关于")
    local card = MakeCard(scroll, 140)
    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(14, 12)
    t.Size = UDim2.new(1, -28, 1, -20)
    t.BackgroundTransparency = 1
    t.Text = "DB 3D 空间 UI · Standalone\n\n版本：独立精简版\n特性：三栏 SurfaceGui / 世界锚定 / 双重渲染\n说明：纯 UI 框架，不含任何游戏功能"
    t.TextColor3 = Color3.fromRGB(230, 235, 245)
    t.TextSize = 11
    t.Font = Enum.Font.GothamMedium
    t.TextWrapped = true
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Top
    t.ZIndex = 24
    t.Parent = card
end

--==================================================================
-- 页面切换
--==================================================================
local function RenderCurrentPage()
    local center = S.Surfaces.Center
    if not center then return end
    local host = center.ContentHost
    ClearHost(host)
    local builder = S.Pages[S.CurrentPage]
    if type(builder) == "function" then
        pcall(builder, host)
    else
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = "页面不存在：" .. tostring(S.CurrentPage)
        label.TextColor3 = Color3.fromRGB(220, 225, 235)
        label.TextSize = 13
        label.Font = Enum.Font.GothamMedium
        label.ZIndex = 24
        label.Parent = host
    end
    if center.Title then
        local titles = { welcome = "DB 3D 空间 UI", settings = "设置", about = "关于" }
        center.Title.Text = titles[S.CurrentPage] or S.CurrentPage
    end
end

function API.ShowPage(pageName)
    pageName = tostring(pageName or "welcome")
    S.CurrentPage = pageName
    RenderCurrentPage()
    for _, info in ipairs(S.NavButtons) do
        if info.Button and info.Button.Parent then
            if info.Page == pageName then info.Button.BackgroundTransparency = 0.55
            else info.Button.BackgroundTransparency = 0.86 end
        end
    end
end

function API.RegisterPage(name, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then return end
    S.Pages[name] = fn
    if S.Enabled and S.Surfaces.Right then BuildNavPane(S.Surfaces.Right) end
end

function API.RegisterNav(label, pageName)
    if type(label) ~= "string" or type(pageName) ~= "string" then return end
    if not S.Pages[pageName] then
        S.Pages[pageName] = function(host)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromScale(1, 1)
            lbl.BackgroundTransparency = 1
            lbl.Text = pageName
            lbl.TextColor3 = Color3.fromRGB(230, 235, 245)
            lbl.TextSize = 14
            lbl.Font = Enum.Font.GothamBlack
            lbl.ZIndex = 24
            lbl.Parent = host
        end
    end
    if S.Enabled and S.Surfaces.Right then BuildNavPane(S.Surfaces.Right) end
end

--==================================================================
-- 构建主结构
--==================================================================
local function RefreshBackGhost(pack)
    if not pack or not pack.Back or not pack.Root then return end
    if pack.BackGhost and pack.BackGhost.Parent then pcall(function() pack.BackGhost:Destroy() end) end
    local ok, ghost = pcall(function() return pack.Root:Clone() end)
    if not ok or not ghost then return end
    ghost.Name = "BackGhost"
    ghost.Active = false
    for _, d in ipairs(ghost:GetDescendants()) do
        if d:IsA("GuiButton") then
            d.Active = false
            pcall(function() d.Selectable = false end)
            pcall(function() d.AutoButtonColor = false end)
        end
        if d:IsA("ScrollingFrame") then
            d.Active = false
            d.ScrollingEnabled = false
        end
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            d.TextTransparency = math.max(d.TextTransparency, 0.24)
            d.TextStrokeTransparency = 1
            if d.BackgroundTransparency < 1 then d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.38) end
        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
            d.ImageTransparency = math.max(d.ImageTransparency, 0.20)
            if d.BackgroundTransparency < 1 then d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.40) end
        elseif d:IsA("Frame") or d:IsA("CanvasGroup") then
            if d.BackgroundTransparency < 1 then d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.42) end
        elseif d:IsA("UIStroke") then
            d.Transparency = math.max(d.Transparency, 0.74)
        end
    end
    ghost.Parent = pack.Back
    pack.BackGhost = ghost
end

local function BuildAll()
    RemoveStale()
    local folder = Instance.new("Folder")
    folder.Name = "DB_3D_UI_Framework"
    folder.Parent = workspace
    S.Folder = folder

    local narrowMode = (Config.Style == "中宽两窄")
    local sc = Config.UI_SCALE or 1
    
    local left, center, right
    if narrowMode then
        left = MakeSurface("Left", 2.28 * sc, 4.08 * sc, 250, 408)
        center = MakeSurface("Center", 5.72 * sc, 4.28 * sc, 560, 428)
        right = MakeSurface("Right", 2.28 * sc, 4.08 * sc, 250, 408)
    else
        left = MakeSurface("Left", 4.28 * sc, 4.02 * sc, 430, 402)
        center = MakeSurface("Center", 5.72 * sc, 4.28 * sc, 560, 428)
        right = MakeSurface("Right", 4.36 * sc, 4.06 * sc, 440, 406)
    end
    MakeMini(sc)

    local function addHeaderBtn(label, x, w, color, textSize, callback)
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, x, 0.5, 0)
        b.Size = UDim2.fromOffset(w, 24)
        b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        b.BackgroundTransparency = 0.84
        b.BorderSizePixel = 0
        b.Text = label
        b.TextColor3 = color
        b.TextSize = textSize or 14
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.Active = true
        b.ZIndex = 64
        b.Parent = center.Header
        AddCorner(b, 999)
        WireButton(b, callback)
        return b
    end

    local anchorBtn = addHeaderBtn("⇅", -6, 30, Color3.fromRGB(66, 214, 105), 15, function()
        Config.WorldAnchored = not Config.WorldAnchored
        S.AnchorTarget = Config.WorldAnchored
        if Config.WorldAnchored then S.AnchorLayout = API.BuildAnchorLayout() end
        anchorBtn.TextColor3 = Config.WorldAnchored and Color3.fromRGB(54, 235, 103) or Color3.fromRGB(66, 214, 105)
        if S.CurrentPage == "settings" then RenderCurrentPage() end
    end)
    local minBtn = addHeaderBtn("−", -44, 30, Color3.fromRGB(248, 248, 252), 18, function()
        if S.AnchorTarget or S.AnchorBlend > 0.04 then
            Config.WorldAnchored = false
            S.AnchorTarget = false
        end
        S.Minimized = true
        S.MinimizeTarget = 1
    end)
    local closeBtn = addHeaderBtn("×", -80, 30, Color3.fromRGB(255, 128, 128), 16, function() API.Destroy() end)
    center.Title.Size = UDim2.new(1, -120, 1, 0)

    BuildPlayerInfo(left)
    BuildNavPane(right)

    S.Pages.welcome = BuildWelcomePage
    S.Pages.settings = BuildSettingsPage
    S.Pages.about = BuildAboutPage

    RenderCurrentPage()
    RefreshBorderStyle()

    for _, pack in pairs(S.Surfaces) do
        if pack.Name ~= "Mini" then
            task.defer(function() RefreshBackGhost(pack) end)
        end
    end

    task.defer(function() BuildNavPane(S.Surfaces.Right) end)
    return left, center, right
end

local function DestroyAll()
    for _, pack in pairs(S.Surfaces) do
        if pack.BackGhost then pcall(function() pack.BackGhost:Destroy() end) end
        if pack.Back then pcall(function() pack.Back:Destroy() end) end
        if pack.Front then pcall(function() pack.Front:Destroy() end) end
    end
    S.Surfaces = {}
    if S.Mini and S.Mini.Front then pcall(function() S.Mini.Front:Destroy() end) end
    S.Mini = nil
    if S.Folder then pcall(function() S.Folder:Destroy() end) end
    S.Folder = nil
    if S.BlurOwned and S.Blur then pcall(function() S.Blur:Destroy() end) end
    S.Blur = nil
    S.BlurOwned = false
end

--==================================================================
-- 世界锚定布局
--==================================================================
function API.BuildAnchorLayout()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local center = S.Surfaces.Center
    local left = S.Surfaces.Left
    local rightP = S.Surfaces.Right
    if not (center and left and rightP) then return nil end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return nil end
    local head = char and char:FindFirstChild("Head")
    local refPos = hrp.Position

    local f = cam.CFrame.LookVector
    f = Vector3.new(f.X, 0, f.Z)
    if f.Magnitude < 0.08 then
        local q = hrp.CFrame.LookVector
        f = Vector3.new(q.X, 0, q.Z)
    end
    if f.Magnitude < 0.08 then f = Vector3.new(0, 0, -1) else f = f.Unit end

    local anchorDistance = 6.00
    local front = refPos + f * anchorDistance
    local desiredCenterY = (head and (head.Position.Y + 0.18)) or (hrp.Position.Y + 2.25)
    local centerPos = Vector3.new(front.X, desiredCenterY, front.Z)

    local toward = Vector3.new(refPos.X - centerPos.X, 0, refPos.Z - centerPos.Z)
    if toward.Magnitude < 0.08 then toward = -f else toward = toward.Unit end

    local xOffset = math.clamp(tonumber(Config.AnchorOffsetX) or 0, -4.0, 4.0)
    local yOffset = math.clamp(tonumber(Config.AnchorOffsetY) or 0, -3.0, 3.0)
    local screenRight = cam.CFrame.RightVector
    screenRight = Vector3.new(screenRight.X, 0, screenRight.Z)
    if screenRight.Magnitude < 0.08 then screenRight = Vector3.new(-f.Z, 0, f.X) else screenRight = screenRight.Unit end
    centerPos = centerPos + screenRight * xOffset + Vector3.new(0, yOffset, 0)

    local baseCf = CFrame.lookAt(centerPos, centerPos + toward, Vector3.new(0, 1, 0))
    local pitch = math.rad(-7.5)
    local centerCf = baseCf * CFrame.Angles(pitch, 0, 0)

    local gap = 0.07
    local leftOffset = center.WidthStud * 0.5 + left.WidthStud * 0.5 + gap
    local rightOffset = center.WidthStud * 0.5 + rightP.WidthStud * 0.5 + gap
    local leftY = (left.HeightStud - center.HeightStud) * 0.5
    local rightY = (rightP.HeightStud - center.HeightStud) * 0.5
    local narrowMode = (Config.Style == "中宽两窄")
    local wing = narrowMode and math.rad(13.5) or math.rad(17.5)
    local wingForward = narrowMode and -0.18 or -0.24

    return {
        Center = { CFrame = centerCf, Size = Vector3.new(center.WidthStud, center.HeightStud, PANEL_DEPTH) },
        Left = { CFrame = centerCf * CFrame.new(-leftOffset, leftY, wingForward) * CFrame.Angles(0, -wing, 0), Size = Vector3.new(left.WidthStud, left.HeightStud, PANEL_DEPTH) },
        Right = { CFrame = centerCf * CFrame.new(rightOffset, rightY, wingForward) * CFrame.Angles(0, wing, 0), Size = Vector3.new(rightP.WidthStud, rightP.HeightStud, PANEL_DEPTH) },
    }
end

--==================================================================
-- 模糊效果
--==================================================================
local function GetBlur()
    local blur = Lighting:FindFirstChild("DB_3DUI_Blur")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Name = "DB_3DUI_Blur"
        blur.Size = 0
        blur.Parent = Lighting
        S.BlurOwned = true
    end
    S.Blur = blur
    return blur
end

local function SetBlur(amount)
    local blur = S.Blur or GetBlur()
    if blur then pcall(function() blur.Size = math.clamp(amount or 0, 0, 14) end) end
end

--==================================================================
-- 主更新循环
--==================================================================
local function CameraBasis(cam, dt)
    local currentLook = cam.CFrame.LookVector
    local currentUp = cam.CFrame.UpVector
    if not S.LookVector then
        S.LookVector = currentLook
        S.UpVector = currentUp
    end
    if S.LookVector:Dot(currentLook) < 0.48 then
        S.LookVector = currentLook
        S.UpVector = currentUp
    else
        local a = 1 - math.exp(-dt * 12.5)
        S.LookVector = (S.LookVector:Lerp(currentLook, a)).Unit
        S.UpVector = (S.UpVector:Lerp(currentUp, a)).Unit
    end
    return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + S.LookVector, S.UpVector)
end

local function SetMainSurfaceEnabled(enabled)
    for name, p in pairs(S.Surfaces) do
        if name ~= "Mini" and p.Front then p.Front.Enabled = enabled end
    end
end

local function Smooth(v)
    v = math.clamp(v or 0, 0, 1)
    return v * v * (3 - 2 * v)
end

local function Update(dt)
    if not S.Enabled or S.Closing then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local target = 1
    local accel = (target - S.Progress) * 86 - S.Velocity * 19
    S.Velocity = S.Velocity + accel * dt
    S.Progress = math.clamp(S.Progress + S.Velocity * dt, -0.02, 1.03)
    if math.abs(target - S.Progress) < 0.002 and math.abs(S.Velocity) < 0.02 then
        S.Progress = target
        S.Velocity = 0
    end
    local openP = 1 - (1 - math.clamp(S.Progress, 0, 1)) ^ 3

    local mTarget = math.clamp(S.MinimizeTarget or 0, 0, 1)
    local mAccel = (mTarget - S.MinimizeProgress) * 90 - S.MinimizeVelocity * 19
    S.MinimizeVelocity = S.MinimizeVelocity + mAccel * dt
    S.MinimizeProgress = math.clamp(S.MinimizeProgress + S.MinimizeVelocity * dt, -0.025, 1.025)
    if math.abs(mTarget - S.MinimizeProgress) < 0.002 and math.abs(S.MinimizeVelocity) < 0.028 then
        S.MinimizeProgress = mTarget
        S.MinimizeVelocity = 0
    end
    local collapse = math.clamp(S.MinimizeProgress, 0, 1)

    local anchorGoal = S.AnchorTarget and 1 or 0
    local anchorAccel = (anchorGoal - S.AnchorBlend) * 82 - S.AnchorVelocity * 17.5
    S.AnchorVelocity = S.AnchorVelocity + anchorAccel * dt
    S.AnchorBlend = math.clamp(S.AnchorBlend + S.AnchorVelocity * dt, -0.02, 1.02)
    if math.abs(anchorGoal - S.AnchorBlend) < 0.0025 and math.abs(S.AnchorVelocity) < 0.025 then
        S.AnchorBlend = anchorGoal
        S.AnchorVelocity = 0
    end
    local anchorMix = Smooth(math.clamp(S.AnchorBlend, 0, 1))
    if not S.AnchorTarget and anchorMix < 0.002 then S.AnchorLayout = nil end
    if S.AnchorTarget and not S.AnchorLayout then S.AnchorLayout = API.BuildAnchorLayout() end

    local basis = CameraBasis(cam, dt)
    local origin = basis.Position
    local right = basis.RightVector
    local up = basis.UpVector
    local look = basis.LookVector
    local hover = math.sin(os.clock() * 1.05) * 0.014 * (1 - collapse)
    origin = origin + up * (0.30 + hover)

    local center = S.Surfaces.Center
    local left = S.Surfaces.Left
    local rightP = S.Surfaces.Right
    local mini = S.Mini

    local focus = origin + look * 0.72 + up * 0.20
    local narrowMode = (Config.Style == "中宽两窄")

    local a = Smooth(math.clamp(collapse / 0.50, 0, 1))
    local c = Smooth(math.clamp((collapse - 0.70) / 0.30, 0, 1))
    local merge = origin + look * 4.40 + up * 0.04
    local finalY = math.max(0.045, 1 - 0.955 * c)
    local finalX = 1 - 0.18 * c
    local follow = 1 - math.exp(-dt * 13.8)

    local function applyTransform(pack, targetCf, targetSize, top)
        if not pack or not pack.Part then return end
        local finalCf = targetCf
        local finalSize = targetSize
        local anchor = S.AnchorLayout and S.AnchorLayout[pack.Name]
        if anchor and anchorMix > 0 then
            finalCf = targetCf:Lerp(anchor.CFrame, anchorMix)
            finalSize = targetSize:Lerp(anchor.Size, anchorMix)
        end
        pack.MotionCFrame = pack.MotionCFrame or finalCf
        pack.MotionCFrame = pack.MotionCFrame:Lerp(finalCf, follow)
        pack.Part.CFrame = pack.MotionCFrame
        
        -- [新增] Size 的平滑過渡，讓切換面板時尺寸變化不突兀
        pack.MotionSize = pack.MotionSize or finalSize
        pack.MotionSize = pack.MotionSize:Lerp(finalSize, follow)
        pack.Part.Size = pack.MotionSize

        if pack.Front then
            pack.Front.AlwaysOnTop = (anchorMix <= 0.10) and top
        end
        if pack.Back then
            pack.Back.AlwaysOnTop = false
            pack.Back.Enabled = (anchorMix > 0.035)
        end
    end

    if center and left and rightP then
        if narrowMode then
            local centerPos = origin + look * (4.48 - (1 - openP) * 0.28) + up * 0.04
            local gap = 0.08
            local leftOffset = (center.WidthStud * 0.5 + left.WidthStud * 0.5 + gap) * openP
            local rightOffset = (center.WidthStud * 0.5 + rightP.WidthStud * 0.5 + gap) * openP
            
            local poseCenter = { cf = CFrame.lookAt(centerPos, focus, up), size = Vector3.new(center.WidthStud, center.HeightStud, PANEL_DEPTH) }
            local poseLeft = { cf = CFrame.lookAt(centerPos - right * leftOffset + look * 0.04, focus, up), size = Vector3.new(left.WidthStud, left.HeightStud, PANEL_DEPTH) }
            local poseRight = { cf = CFrame.lookAt(centerPos + right * rightOffset + look * 0.04, focus, up), size = Vector3.new(rightP.WidthStud, rightP.HeightStud, PANEL_DEPTH) }
            
            local sizeScale = (1 - 0.05 * a) * finalX
            poseCenter.size = poseCenter.size * Vector3.new(sizeScale, finalY, 1)
            poseLeft.size = poseLeft.size * Vector3.new(sizeScale, finalY, 1)
            poseRight.size = poseRight.size * Vector3.new(sizeScale, finalY, 1)

            local tLeft, tCenter, tRight
            if S.FocusName == "Left" then
                tLeft = poseCenter; tCenter = poseLeft; tRight = poseRight
            elseif S.FocusName == "Right" then
                tLeft = poseLeft; tCenter = poseRight; tRight = poseCenter
            else
                tLeft = poseLeft; tCenter = poseCenter; tRight = poseRight
            end

            applyTransform(center, tCenter.cf, tCenter.size, true)
            applyTransform(left, tLeft.cf, tLeft.size, false)
            applyTransform(rightP, tRight.cf, tRight.size, false)
        else
            local centerPos = origin + look * (4.48 - (1 - openP) * 0.28) + up * 0.04
            local sidePos = origin + look * 5.45
            local sideOffset = 3.55 * (Config.UI_SCALE or 1) * openP
            
            local poseCenter = { cf = CFrame.lookAt(centerPos:Lerp(merge, a), focus, up) * CFrame.Angles(0, 0, math.rad(-1.4 * a)), size = Vector3.new(center.WidthStud, center.HeightStud, PANEL_DEPTH) }
            local poseLeft = { cf = CFrame.lookAt((sidePos - right * sideOffset):Lerp(merge + right * 0.045 + look * 0.09, a), focus, up) * CFrame.Angles(0, 0, math.rad(1.4 * a)), size = Vector3.new(left.WidthStud, left.HeightStud, PANEL_DEPTH) }
            local poseRight = { cf = CFrame.lookAt((sidePos + right * sideOffset):Lerp(merge - right * 0.045 + look * 0.09, a), focus, up) * CFrame.Angles(0, 0, math.rad(-1.4 * a)), size = Vector3.new(rightP.WidthStud, rightP.HeightStud, PANEL_DEPTH) }

            local centerSizeScale = (1 - 0.07 * a) * finalX
            local sideSizeScale = (1 - 0.08 * a) * finalX
            poseCenter.size = poseCenter.size * Vector3.new(centerSizeScale, finalY, 1)
            poseLeft.size = poseLeft.size * Vector3.new(sideSizeScale, finalY, 1)
            poseRight.size = poseRight.size * Vector3.new(sideSizeScale, finalY, 1)

            local tLeft, tCenter, tRight
            if S.FocusName == "Left" then
                tLeft = poseCenter; tCenter = poseLeft; tRight = poseRight
            elseif S.FocusName == "Right" then
                tLeft = poseLeft; tCenter = poseRight; tRight = poseCenter
            else
                tLeft = poseLeft; tCenter = poseCenter; tRight = poseRight
            end

            applyTransform(center, tCenter.cf, tCenter.size, true)
            applyTransform(left, tLeft.cf, tLeft.size, false)
            applyTransform(rightP, tRight.cf, tRight.size, false)
        end
    end

    if mini and mini.Part and mini.Front then
        local miniP = Smooth(math.clamp((collapse - 0.855) / 0.145, 0, 1))
        local miniPos = origin + look * 4.36 + up * 2.40
        mini.Part.CFrame = CFrame.lookAt(miniPos, origin + look * 0.50 + up * 0.35, up)
        mini.Part.Size = Vector3.new(
            mini.WidthStud * math.max(0.055, miniP),
            mini.HeightStud * math.max(0.07, miniP),
            PANEL_DEPTH
        )
        mini.Front.Enabled = miniP > 0.035
    end

    local blurPhase = 0
    if collapse > 0.62 and collapse < 0.995 then blurPhase = math.sin(math.clamp((collapse - 0.62) / 0.375, 0, 1) * math.pi) end
    SetBlur(10.5 * blurPhase)
    SetMainSurfaceEnabled(collapse < 0.988)

    if anchorMix > 0.06 then
        S.BackGhostAccumulator = S.BackGhostAccumulator + dt
        if S.BackGhostAccumulator >= 0.85 then
            S.BackGhostAccumulator = 0
            for _, pack in pairs(S.Surfaces) do
                if pack.Name ~= "Mini" then RefreshBackGhost(pack) end
            end
        end
    else
        S.BackGhostAccumulator = 0
    end

    if left and left.Front and left.Part then
        local moving = false
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then moving = hum.MoveDirection.Magnitude > 0.025 end
        left.Front.Active = (not moving) and (not S.JoystickTouch) and collapse < 0.96
        left.Part.CanQuery = (not moving) and (not S.JoystickTouch) and collapse < 0.96
    end
end

--==================================================================
-- 启动 / 销毁
--==================================================================
function API.Destroy()
    if not S.Enabled then return end
    S.Closing = true
    if S.RenderConnection then pcall(function() S.RenderConnection:Disconnect() end); S.RenderConnection = nil end
    DestroyAll()
    S.Enabled = false
    S.Closing = false
    S.Progress = 0
    S.Velocity = 0
    S.Minimized = false
    S.MinimizeTarget = 0
    S.MinimizeProgress = 0
    S.MinimizeVelocity = 0
    S.AnchorTarget = false
    S.AnchorBlend = 0
    S.AnchorVelocity = 0
    S.AnchorLayout = nil
    SetBlur(0)
end

function API.SetAssets(t)
    if type(t) ~= "table" then return end
    if type(t.Logo) == "string" then
        Assets.Logo = t.Logo
        for _, pack in pairs(S.Surfaces) do
            if pack.LogoBg then
                pack.LogoBg.Image = Assets.Logo
                pack.LogoBg.Visible = (Assets.Logo ~= "rbxassetid://0") and Config.LogoBackground
            end
        end
    end
end

function API.SetStyle(style)
    style = tostring(style or "默认")
    if style ~= "默认" and style ~= "中宽两窄" then style = "默认" end
    if Config.Style == style then return end
    Config.Style = style
    if S.Enabled then
        local currentPage = S.CurrentPage
        DestroyAll()
        BuildAll()
        S.CurrentPage = currentPage
        RenderCurrentPage()
    end
end

function API.SetBorder(border)
    border = tostring(border or "默认")
    if not BORDER_COLORS[border] and border ~= "彩虹" then border = "默认" end
    Config.Border = border
    RefreshBorderStyle()
end

function API.SetWorldAnchored(v)
    Config.WorldAnchored = v == true
    S.AnchorTarget = Config.WorldAnchored
    if Config.WorldAnchored then S.AnchorLayout = API.BuildAnchorLayout() end
end

function API.SetMinimized(v)
    if not S.Enabled then return end
    S.Minimized = v == true
    S.MinimizeTarget = S.Minimized and 1 or 0
    if not S.Minimized then SetMainSurfaceEnabled(true) end
end

function API.Notify(title, content, success)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0, 24)
    frame.Size = UDim2.fromOffset(300, 58)
    frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.ZIndex = 5000
    frame.Parent = pg
    AddCorner(frame, 12)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Color = success and Color3.fromRGB(120, 235, 140) or Color3.fromRGB(255, 120, 130)
    stroke.Parent = frame
    local t1 = Instance.new("TextLabel")
    t1.Size = UDim2.new(1, -20, 0, 18)
    t1.Position = UDim2.fromOffset(10, 5)
    t1.BackgroundTransparency = 1
    t1.Text = title or ""
    t1.TextColor3 = success and Color3.fromRGB(120, 235, 140) or Color3.fromRGB(255, 120, 130)
    t1.TextSize = 12
    t1.Font = Enum.Font.GothamBlack
    t1.TextXAlignment = Enum.TextXAlignment.Left
    t1.Parent = frame
    local t2 = Instance.new("TextLabel")
    t2.Size = UDim2.new(1, -20, 0, 26)
    t2.Position = UDim2.fromOffset(10, 25)
    t2.BackgroundTransparency = 1
    t2.Text = content or ""
    t2.TextColor3 = Color3.fromRGB(200, 210, 230)
    t2.TextSize = 10
    t2.Font = Enum.Font.GothamMedium
    t2.TextWrapped = true
    t2.TextXAlignment = Enum.TextXAlignment.Left
    t2.Parent = frame
    task.delay(3.5, function()
        if frame and frame.Parent then
            TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            task.delay(0.35, function()
                if frame and frame.Parent then frame:Destroy() end
            end)
        end
    end)
end

function API.IsEnabled()
    return S.Enabled == true
end

function API.SetEnabled(v)
    if v then
        if S.Enabled then return end
        BuildAll()
        S.Enabled = true
        S.Closing = false
        S.Progress = 0.04
        S.Velocity = 0
        S.LookVector = nil
        S.UpVector = nil
        S.Minimized = false
        S.MinimizeTarget = 0
        S.MinimizeProgress = 0
        S.MinimizeVelocity = 0
        S.AnchorTarget = Config.WorldAnchored
        S.AnchorBlend = Config.WorldAnchored and 1 or 0
        S.AnchorVelocity = 0
        S.AnchorLayout = Config.WorldAnchored and API.BuildAnchorLayout() or nil
        S.FocusName = "Center" -- 初始化焦點為中間
        GetBlur()
        SetBlur(0)
        if S.RenderConnection then pcall(function() S.RenderConnection:Disconnect() end) end
        S.RenderConnection = RunService.RenderStepped:Connect(function(dt)
            dt = math.min(dt, 1 / 30)
            local ok, err = pcall(Update, dt)
            if not ok then warn("[DB3DUI] Update error:", err) end
        end)
    else
        API.Destroy()
    end
end

--==================================================================
-- 初始化
--==================================================================
LocalPlayer.CharacterAdded:Connect(function(character)
    if not S.Enabled then return end
    task.wait(0.7)
    if not S.Enabled then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    if Config.WorldAnchored then
        Config.WorldAnchored = false
        S.AnchorTarget = false
        S.AnchorBlend = 0
        S.AnchorVelocity = 0
        S.AnchorLayout = nil
    end
end)

API.SetEnabled(true)

_G.DB3DUI = API
print("[DB 3D Spatial UI] Standalone loaded — 支援點擊切換焦點")
return API
