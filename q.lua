--!nocheck
--==================================================================
-- DB UI Framework · 独立精简版
-- 纯 UI 框架，无任何游戏功能。可直接 loadstring 或粘贴运行。
--
-- 用法：
--   DBUI.SetAssets({ Logo = "rbxassetid://...", MoveIcon = "rbxassetid://..." })
--   DBUI.SetWallpapers({ {Name="默认", Url="rbxassetid://..."}, ... })
--   DBUI.SetAnnouncement("自定义公告文本")
--   DBUI.RegisterCategory("射击游戏", function(container, addButton) ... end)
--   DBUI.RegisterPage("通用", function(container) ... end)
--==================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat task.wait(0.1) until Players.LocalPlayer
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==================================================================
-- 1. 资源与配置
--==================================================================
local Assets = {
    Logo = "rbxassetid://0",      -- 主 DB Logo（可 DBUI.SetAssets 覆盖）
    MoveIcon = "rbxassetid://0",  -- 四向移动箭头图标
}

local Wallpapers = {
    -- 通过 DBUI.SetWallpapers 注入；格式 { {Name="默认", Url="rbxassetid://..."}, ... }
}
local CurrentWallpaperIndex = 0

local AnnouncementText = [==[
欢迎使用 DB UI Framework

· 本框架仅提供界面，不含任何游戏功能
· 可通过 DBUI.RegisterCategory / RegisterPage 注入业务页面
· 壁纸、Logo、图标均通过 DBUI.SetAssets / SetWallpapers 覆盖

祝你使用愉快
]==]

--==================================================================
-- 2. 主题常量
--==================================================================
local THEME = {
    Panel = Color3.fromRGB(0, 0, 0),
    Button = Color3.fromRGB(12, 12, 14),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(205, 205, 210),
    CornerRadius = 16,
    ButtonSize = 56,
    FloatingWidth = 150,
    FloatingHeight = 42,
    FloatingDragWidth = 42,
    AnimationTime = 0.35,
    MinPanelWidth = 360,
    MinPanelHeight = 250,
}

local UI = {
    ButtonBackground = Color3.fromRGB(255, 255, 255),
    ButtonTransparency = 0.84,
    ButtonBordersEnabled = false,
    TransitionStyle = "原版",  -- 原版 / 增加模糊 / 老式款
    WallpaperTransparency = 0.45,
    WallpaperTint = Color3.fromRGB(255, 255, 255),
    WallpaperBrightness = 1.00,
}

local RAINBOW_FLOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 82, 126)),
    ColorSequenceKeypoint.new(0.14, Color3.fromRGB(255, 178, 78)),
    ColorSequenceKeypoint.new(0.28, Color3.fromRGB(255, 246, 112)),
    ColorSequenceKeypoint.new(0.43, Color3.fromRGB(102, 255, 176)),
    ColorSequenceKeypoint.new(0.58, Color3.fromRGB(86, 230, 255)),
    ColorSequenceKeypoint.new(0.72, Color3.fromRGB(126, 138, 255)),
    ColorSequenceKeypoint.new(0.86, Color3.fromRGB(236, 92, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 82, 126)),
})

local DEEP_RAINBOW_FLOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(224, 42, 92)),
    ColorSequenceKeypoint.new(0.14, Color3.fromRGB(232, 132, 42)),
    ColorSequenceKeypoint.new(0.28, Color3.fromRGB(220, 198, 55)),
    ColorSequenceKeypoint.new(0.43, Color3.fromRGB(50, 205, 128)),
    ColorSequenceKeypoint.new(0.58, Color3.fromRGB(38, 184, 224)),
    ColorSequenceKeypoint.new(0.72, Color3.fromRGB(82, 92, 220)),
    ColorSequenceKeypoint.new(0.86, Color3.fromRGB(194, 55, 220)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(224, 42, 92)),
})

--==================================================================
-- 3. 基础工具
--==================================================================
local Viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local PanelWidth = math.clamp(Viewport.X * 0.62, 380, 550)
local PanelHeight = math.clamp(PanelWidth * (370 / 550), 260, 370)

local function AddCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

local function StartRainbowFlow(parent, duration, transparency)
    local grad = Instance.new("UIGradient")
    grad.Name = "RainbowFlow"
    grad.Color = RAINBOW_FLOW
    grad.Transparency = transparency or NumberSequence.new(0)
    grad.Rotation = -180
    grad.Parent = parent
    local tw = TweenService:Create(grad, TweenInfo.new(duration or 2.0, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0), { Rotation = 180 })
    tw:Play()
    return grad, tw
end

local function AddRainbowBorder(obj, thickness, transparency, speed)
    local stroke = Instance.new("UIStroke")
    stroke.Name = "DB_RainbowMain"
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = thickness or 0.9
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = transparency or 0.01
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = obj
    local grad = StartRainbowFlow(stroke, speed or 1.95)
    return stroke, grad
end

local function AddPlainBorder(obj, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = thickness or 0.85
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = transparency or 0.52
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = obj
    return stroke
end

local function StyleLiquidButton(btn, radius)
    radius = radius or 9
    btn.BackgroundColor3 = UI.ButtonBackground
    btn.BackgroundTransparency = UI.ButtonTransparency
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBlack
    btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextStrokeTransparency = 0.62
    AddCorner(btn, radius)
    local stroke = AddPlainBorder(btn, 0.85, 0.52)
    stroke.Name = "DB_StableGlassStroke"
    stroke:SetAttribute("DB_BaseTransparency", 0.52)
    stroke.Transparency = UI.ButtonBordersEnabled and 0.52 or 1
    local scale = Instance.new("UIScale")
    scale.Name = "DB_StableGlassScale"
    scale.Scale = 1
    scale.Parent = btn
    local function Restore()
        if not btn.Parent then return end
        btn.BackgroundColor3 = UI.ButtonBackground
        btn.BackgroundTransparency = UI.ButtonTransparency
        stroke.Transparency = UI.ButtonBordersEnabled and 0.52 or 1
    end
    btn.MouseEnter:Connect(Restore)
    btn.MouseLeave:Connect(function()
        Restore()
        TweenService:Create(scale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Restore()
        TweenService:Create(scale, TweenInfo.new(0.055, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.972 }):Play()
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Restore()
        TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end)
    return stroke
end

--==================================================================
-- 4. 主 ScreenGui
--==================================================================
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "DB_UI_Framework"
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.DisplayOrder = 999
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.Parent = PlayerGui

--==================================================================
-- 5. 主面板（Panel + Body + 三层布局）
--==================================================================
local State = {
    PanelPosition = nil,
    ButtonPosition = nil,
    Animating = false,
    Minimized = false,
    CurrentCategory = "主页",
}

local Panel = Instance.new("CanvasGroup")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.Size = UDim2.fromOffset(PanelWidth, PanelHeight)
Panel.Position = UDim2.fromOffset(Viewport.X / 2, Viewport.Y / 2)
Panel.BackgroundTransparency = 1
Panel.GroupTransparency = 0
Panel.BorderSizePixel = 0
Panel.Active = false
Panel.Visible = false
Panel.Parent = MainGui

local StartupScale = Instance.new("UIScale")
StartupScale.Name = "DB_StartupScale"
StartupScale.Scale = 0.78
StartupScale.Parent = Panel

local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Position = UDim2.fromOffset(2, 2)
Body.Size = UDim2.new(1, -4, 1, -4)
Body.BackgroundColor3 = THEME.Panel
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.ClipsDescendants = true
Body.ZIndex = 2
Body.Parent = Panel
AddCorner(Body, THEME.CornerRadius)

-- 外框彩虹描边
local PanelBorder, PanelBorderGradient
do
    local host = Instance.new("Frame")
    host.Name = "DB_OuterRainbowBorderHost"
    host.Position = UDim2.fromOffset(3, 3)
    host.Size = UDim2.new(1, -6, 1, -6)
    host.BackgroundTransparency = 1
    host.BorderSizePixel = 0
    host.ClipsDescendants = false
    host.ZIndex = 980
    host.Parent = Panel
    AddCorner(host, THEME.CornerRadius - 1)
    PanelBorder, PanelBorderGradient = AddRainbowBorder(host, 2.62, 0.012, 2.75)
    PanelBorderGradient.Color = DEEP_RAINBOW_FLOW
end

-- 壁纸层
local WallpaperLayer = Instance.new("ImageLabel")
WallpaperLayer.Name = "DB_WallpaperLayer"
WallpaperLayer.Position = UDim2.fromOffset(-1, -1)
WallpaperLayer.Size = UDim2.new(1, 2, 1, 2)
WallpaperLayer.BackgroundTransparency = 1
WallpaperLayer.BorderSizePixel = 0
WallpaperLayer.Image = ""
WallpaperLayer.ImageTransparency = UI.WallpaperTransparency
WallpaperLayer.ScaleType = Enum.ScaleType.Crop
WallpaperLayer.ZIndex = 3
WallpaperLayer.ClipsDescendants = true
WallpaperLayer.Parent = Body
AddCorner(WallpaperLayer, THEME.CornerRadius + 1)

local function RefreshWallpaper()
    WallpaperLayer.ImageTransparency = math.clamp(UI.WallpaperTransparency, 0, 1)
    local c = UI.WallpaperTint
    local b = math.clamp(UI.WallpaperBrightness, 0.20, 1.00)
    WallpaperLayer.ImageColor3 = Color3.new(
        math.clamp(c.R * b, 0, 1),
        math.clamp(c.G * b, 0, 1),
        math.clamp(c.B * b, 0, 1)
    )
end

local function ApplyWallpaper(index)
    if type(Wallpapers) ~= "table" or not Wallpapers[index] then return end
    CurrentWallpaperIndex = index
    WallpaperLayer.Image = Wallpapers[index].Url or ""
    RefreshWallpaper()
end

--==================================================================
-- 6. 标题栏
--==================================================================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 28)
Header.BackgroundTransparency = 1
Header.Active = true
Header.ZIndex = 10
Header.Parent = Body

local DragArea = Instance.new("TextButton")
DragArea.Name = "DragArea"
DragArea.Size = UDim2.new(1, -34, 1, 0)
DragArea.BackgroundTransparency = 1
DragArea.BorderSizePixel = 0
DragArea.Text = ""
DragArea.AutoButtonColor = false
DragArea.ZIndex = 20
DragArea.Parent = Header

local HeaderLogo = Instance.new("ImageLabel")
HeaderLogo.Position = UDim2.fromOffset(7, 2)
HeaderLogo.Size = UDim2.fromOffset(24, 24)
HeaderLogo.BackgroundTransparency = 1
HeaderLogo.ScaleType = Enum.ScaleType.Fit
HeaderLogo.Image = Assets.Logo
HeaderLogo.ZIndex = 24
HeaderLogo.Parent = DragArea

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(35, 1)
Title.Size = UDim2.fromOffset(120, 26)
Title.Text = "DB SCRIPT"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 21
Title.Parent = DragArea
StartRainbowFlow(Title, 4.25, NumberSequence.new(0))

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.fromOffset(157, 7)
Subtitle.Size = UDim2.new(1, -200, 0, 15)
Subtitle.Text = "UI Framework"
Subtitle.TextColor3 = THEME.SubText
Subtitle.TextSize = 9
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 21
Subtitle.Parent = DragArea

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(26, 26)
CloseBtn.Position = UDim2.new(1, -30, 0, 1)
CloseBtn.BackgroundTransparency = 1
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "−"
CloseBtn.TextColor3 = THEME.Text
CloseBtn.TextSize = 22
CloseBtn.Font = Enum.Font.GothamMedium
CloseBtn.AutoButtonColor = false
CloseBtn.ZIndex = 30
CloseBtn.Parent = Header

local ExitBtn = Instance.new("TextButton")
ExitBtn.Size = UDim2.fromOffset(26, 26)
ExitBtn.Position = UDim2.new(1, -58, 0, 1)
ExitBtn.BackgroundTransparency = 1
ExitBtn.BorderSizePixel = 0
ExitBtn.Text = "×"
ExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExitBtn.TextSize = 20
ExitBtn.Font = Enum.Font.GothamBold
ExitBtn.AutoButtonColor = false
ExitBtn.ZIndex = 30
ExitBtn.Parent = Header

--==================================================================
-- 7. 三栏布局
--==================================================================
local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(6, 31)
Content.Size = UDim2.new(1, -12, 1, -47)
Content.BackgroundTransparency = 1
Content.ZIndex = 10
Content.Parent = Body

local PROFILE_RAIL_WIDTH = 104
local FUNCTION_RAIL_WIDTH = 130
local COLUMN_GAP = 6
local UNIFIED_SIDE_PAD = 10

-- 左：玩家信息栏
local PlayerProfileRail = Instance.new("Frame")
PlayerProfileRail.Position = UDim2.fromOffset(0, 0)
PlayerProfileRail.Size = UDim2.new(0, PROFILE_RAIL_WIDTH, 1, 0)
PlayerProfileRail.BackgroundTransparency = 1
PlayerProfileRail.ClipsDescendants = true
PlayerProfileRail.ZIndex = 15
PlayerProfileRail.Parent = Content

local ProfileRailDivider = Instance.new("Frame")
ProfileRailDivider.AnchorPoint = Vector2.new(1, 0)
ProfileRailDivider.Position = UDim2.new(1, -1, 0, 4)
ProfileRailDivider.Size = UDim2.new(0, 1, 1, -8)
ProfileRailDivider.BackgroundColor3 = Color3.fromRGB(150, 205, 240)
ProfileRailDivider.BackgroundTransparency = 0.72
ProfileRailDivider.BorderSizePixel = 0
ProfileRailDivider.ZIndex = 16
ProfileRailDivider.Parent = PlayerProfileRail

local PlayerProfileScroll = Instance.new("ScrollingFrame")
PlayerProfileScroll.Position = UDim2.fromOffset(0, 0)
PlayerProfileScroll.Size = UDim2.new(1, -2, 1, 0)
PlayerProfileScroll.BackgroundTransparency = 1
PlayerProfileScroll.BorderSizePixel = 0
PlayerProfileScroll.CanvasSize = UDim2.fromOffset(0, 500)
PlayerProfileScroll.ScrollingDirection = Enum.ScrollingDirection.Y
PlayerProfileScroll.ScrollBarThickness = 2
PlayerProfileScroll.ScrollBarImageColor3 = Color3.fromRGB(225, 225, 232)
PlayerProfileScroll.ScrollBarImageTransparency = 0.58
PlayerProfileScroll.ZIndex = 15
PlayerProfileScroll.Parent = PlayerProfileRail

-- 右：功能导航栏
local LeftMenu = Instance.new("Frame")
LeftMenu.Size = UDim2.new(0, FUNCTION_RAIL_WIDTH, 1, 0)
LeftMenu.Position = UDim2.new(1, -FUNCTION_RAIL_WIDTH, 0, 0)
LeftMenu.BackgroundTransparency = 1
LeftMenu.Parent = Content

local FunctionRailDivider = Instance.new("Frame")
FunctionRailDivider.Position = UDim2.fromOffset(0, 4)
FunctionRailDivider.Size = UDim2.new(0, 1, 1, -8)
FunctionRailDivider.BackgroundColor3 = Color3.fromRGB(150, 205, 240)
FunctionRailDivider.BackgroundTransparency = 0.72
FunctionRailDivider.BorderSizePixel = 0
FunctionRailDivider.ZIndex = 16
FunctionRailDivider.Parent = LeftMenu

local MenuScroll = Instance.new("ScrollingFrame")
MenuScroll.Size = UDim2.new(1, -8, 1, -8)
MenuScroll.Position = UDim2.fromOffset(4, 4)
MenuScroll.BackgroundTransparency = 1
MenuScroll.BorderSizePixel = 0
MenuScroll.ScrollBarThickness = 2
MenuScroll.ScrollBarImageColor3 = Color3.fromRGB(205, 205, 210)
MenuScroll.ScrollBarImageTransparency = 0.55
MenuScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
MenuScroll.CanvasSize = UDim2.new()
MenuScroll.ScrollingDirection = Enum.ScrollingDirection.Y
MenuScroll.Parent = LeftMenu

local MenuLayout = Instance.new("UIListLayout")
MenuLayout.Padding = UDim.new(0, 8)
MenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
MenuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
MenuLayout.Parent = MenuScroll

local MenuPad = Instance.new("UIPadding")
MenuPad.PaddingTop = UDim.new(0, 7)
MenuPad.PaddingBottom = UDim.new(0, 8)
MenuPad.PaddingLeft = UDim.new(0, 2)
MenuPad.PaddingRight = UDim.new(0, 2)
MenuPad.Parent = MenuScroll

-- 中：内容
local RightList = Instance.new("Frame")
RightList.Size = UDim2.new(1, -(PROFILE_RAIL_WIDTH + FUNCTION_RAIL_WIDTH + COLUMN_GAP * 2), 1, 0)
RightList.Position = UDim2.new(0, PROFILE_RAIL_WIDTH + COLUMN_GAP, 0, 0)
RightList.BackgroundTransparency = 1
RightList.Parent = Content

local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Size = UDim2.new(1, -10, 1, -8)
ListScroll.Position = UDim2.fromOffset(5, 4)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel = 0
ListScroll.ScrollBarThickness = 2
ListScroll.ScrollBarImageColor3 = Color3.fromRGB(205, 205, 210)
ListScroll.ScrollBarImageTransparency = 0.55
ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListScroll.CanvasSize = UDim2.new()
ListScroll.Parent = RightList

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ListLayout.Parent = ListScroll

local ListPad = Instance.new("UIPadding")
ListPad.PaddingTop = UDim.new(0, 4)
ListPad.PaddingBottom = UDim.new(0, 4)
ListPad.Parent = ListScroll

--==================================================================
-- 8. 底部移动条 + 右下缩放弧
--==================================================================
local MoveBarHitArea = Instance.new("TextButton")
MoveBarHitArea.AnchorPoint = Vector2.new(0.5, 1)
MoveBarHitArea.Position = UDim2.new(0.5, 0, 1, -2)
MoveBarHitArea.Size = UDim2.new(3/5, 0, 0, 20)
MoveBarHitArea.BackgroundTransparency = 1
MoveBarHitArea.BorderSizePixel = 0
MoveBarHitArea.Text = ""
MoveBarHitArea.AutoButtonColor = false
MoveBarHitArea.ZIndex = 992
MoveBarHitArea.Parent = Body

local MoveBar = Instance.new("Frame")
MoveBar.AnchorPoint = Vector2.new(0.5, 0.5)
MoveBar.Position = UDim2.fromScale(0.5, 0.63)
MoveBar.Size = UDim2.new(1, 0, 0, 3)
MoveBar.BackgroundColor3 = Color3.fromRGB(88, 88, 94)
MoveBar.BackgroundTransparency = 0.20
MoveBar.BorderSizePixel = 0
MoveBar.ZIndex = 993
MoveBar.Parent = MoveBarHitArea
AddCorner(MoveBar, 999)

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.AnchorPoint = Vector2.new(0, 0)
ResizeHandle.Position = UDim2.new(1, -26, 1, -26)
ResizeHandle.Size = UDim2.fromOffset(48, 48)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.BorderSizePixel = 0
ResizeHandle.Text = ""
ResizeHandle.AutoButtonColor = false
ResizeHandle.ZIndex = 994
ResizeHandle.Parent = Panel

local ResizeArcVisual = Instance.new("TextLabel")
ResizeArcVisual.AnchorPoint = Vector2.new(0, 0)
ResizeArcVisual.Position = UDim2.fromOffset(12, 10)
ResizeArcVisual.Size = UDim2.fromOffset(36, 36)
ResizeArcVisual.BackgroundTransparency = 1
ResizeArcVisual.Text = "╯"
ResizeArcVisual.TextColor3 = Color3.fromRGB(150, 150, 156)
ResizeArcVisual.TextTransparency = 0.04
ResizeArcVisual.TextSize = 38
ResizeArcVisual.Font = Enum.Font.GothamMedium
ResizeArcVisual.ZIndex = 995
ResizeArcVisual.Parent = ResizeHandle

--==================================================================
-- 9. 悬浮按钮
--==================================================================
local FloatingButton = Instance.new("Frame")
FloatingButton.AnchorPoint = Vector2.new(0.5, 0.5)
FloatingButton.Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight)
FloatingButton.BackgroundColor3 = Color3.fromRGB(6, 9, 13)
FloatingButton.BackgroundTransparency = 0.06
FloatingButton.BorderSizePixel = 0
FloatingButton.ClipsDescendants = true
FloatingButton.Visible = false
FloatingButton.ZIndex = 1200
FloatingButton.Parent = MainGui
AddCorner(FloatingButton, 999)
AddRainbowBorder(FloatingButton, 1.7, 0.01, 3.1)

local FloatingTransitionScale = Instance.new("UIScale")
FloatingTransitionScale.Scale = 1
FloatingTransitionScale.Parent = FloatingButton

local FloatingDragZone = Instance.new("TextButton")
FloatingDragZone.Size = UDim2.fromOffset(THEME.FloatingDragWidth, THEME.FloatingHeight)
FloatingDragZone.BackgroundTransparency = 1
FloatingDragZone.Text = ""
FloatingDragZone.AutoButtonColor = false
FloatingDragZone.ZIndex = 103
FloatingDragZone.Parent = FloatingButton

local FloatingMoveIcon = Instance.new("ImageLabel")
FloatingMoveIcon.AnchorPoint = Vector2.new(0.5, 0.5)
FloatingMoveIcon.Position = UDim2.fromScale(0.5, 0.5)
FloatingMoveIcon.Size = UDim2.fromOffset(20, 20)
FloatingMoveIcon.BackgroundTransparency = 1
FloatingMoveIcon.Image = Assets.MoveIcon
FloatingMoveIcon.ImageColor3 = Color3.fromRGB(242, 242, 246)
FloatingMoveIcon.ScaleType = Enum.ScaleType.Fit
FloatingMoveIcon.ZIndex = 105
FloatingMoveIcon.Parent = FloatingDragZone

local FloatingSeparator = Instance.new("Frame")
FloatingSeparator.Position = UDim2.fromOffset(THEME.FloatingDragWidth, 7)
FloatingSeparator.Size = UDim2.fromOffset(1, THEME.FloatingHeight - 12)
FloatingSeparator.BackgroundColor3 = Color3.fromRGB(150, 155, 165)
FloatingSeparator.BackgroundTransparency = 0.62
FloatingSeparator.BorderSizePixel = 0
FloatingSeparator.ZIndex = 102
FloatingSeparator.Parent = FloatingButton

local FloatingOpenZone = Instance.new("TextButton")
FloatingOpenZone.Position = UDim2.fromOffset(THEME.FloatingDragWidth + 1, 0)
FloatingOpenZone.Size = UDim2.new(1, -(THEME.FloatingDragWidth + 1), 1, 0)
FloatingOpenZone.BackgroundTransparency = 1
FloatingOpenZone.Text = ""
FloatingOpenZone.AutoButtonColor = false
FloatingOpenZone.ZIndex = 1203
FloatingOpenZone.Parent = FloatingButton

local FloatingBrandLogo = Instance.new("ImageLabel")
FloatingBrandLogo.AnchorPoint = Vector2.new(0, 0.5)
FloatingBrandLogo.Position = UDim2.new(0, 12, 0.5, 0)
FloatingBrandLogo.Size = UDim2.fromOffset(29, 29)
FloatingBrandLogo.BackgroundTransparency = 1
FloatingBrandLogo.ScaleType = Enum.ScaleType.Fit
FloatingBrandLogo.Image = Assets.Logo
FloatingBrandLogo.ZIndex = 1204
FloatingBrandLogo.Parent = FloatingOpenZone

local FloatingBrandName = Instance.new("TextLabel")
FloatingBrandName.Position = UDim2.fromOffset(49, 0)
FloatingBrandName.Size = UDim2.new(1, -54, 1, 0)
FloatingBrandName.BackgroundTransparency = 1
FloatingBrandName.Text = "DB脚本"
FloatingBrandName.TextColor3 = Color3.fromRGB(255, 246, 220)
FloatingBrandName.TextSize = 13
FloatingBrandName.Font = Enum.Font.GothamBlack
FloatingBrandName.TextXAlignment = Enum.TextXAlignment.Left
FloatingBrandName.ZIndex = 1204
FloatingBrandName.Parent = FloatingOpenZone

--==================================================================
-- 10. Apple 弹簧过渡动画
--==================================================================
local AppleTransition = {
    Progress = 1,
    Velocity = 0,
    Target = 1,
    Running = false,
    PanelTarget = Vector2.new(Viewport.X / 2, Viewport.Y / 2),
    ButtonTarget = Vector2.new(Viewport.X * 0.5, THEME.FloatingHeight / 2 + 10),
    Direction = Vector2.new(0, 1),
    ButtonMorphTween = nil,
    ButtonMorphing = false,
    SceneBlur = nil,
}

local BlurOverlay = Instance.new("Frame")
BlurOverlay.Name = "DB_TransitionSoftFocus"
BlurOverlay.Size = UDim2.fromScale(1, 1)
BlurOverlay.BackgroundColor3 = Color3.fromRGB(226, 229, 235)
BlurOverlay.BackgroundTransparency = 1
BlurOverlay.BorderSizePixel = 0
BlurOverlay.Active = false
BlurOverlay.Visible = false
BlurOverlay.ZIndex = 970
BlurOverlay.Parent = Panel
AddCorner(BlurOverlay, THEME.CornerRadius)

local function GetCollapsedPanelScale()
    local w = math.max(PanelWidth, 1)
    local h = math.max(PanelHeight, 1)
    local fit = math.min(THEME.FloatingWidth / w, THEME.FloatingHeight / h)
    return math.clamp(fit, 0.075, 0.18)
end

local function GetSceneBlur()
    if AppleTransition.SceneBlur and AppleTransition.SceneBlur.Parent then return AppleTransition.SceneBlur end
    local blur = Instance.new("BlurEffect")
    blur.Name = "DB_TransitionBlur"
    blur.Size = 0
    blur.Enabled = false
    blur.Parent = Lighting
    AppleTransition.SceneBlur = blur
    return blur
end

local function ApplySoftFocus(p)
    p = math.clamp(p or AppleTransition.Progress, 0, 1)
    if UI.TransitionStyle ~= "增加模糊" then
        BlurOverlay.Visible = false
        BlurOverlay.BackgroundTransparency = 1
        Panel.GroupTransparency = 0
        if AppleTransition.SceneBlur and AppleTransition.SceneBlur.Parent then
            AppleTransition.SceneBlur.Size = 0
            AppleTransition.SceneBlur.Enabled = false
        end
        return
    end
    local amount
    if AppleTransition.Target == 0 then
        amount = math.clamp((0.88 - p) / 0.70, 0, 1)
        amount = amount * amount * (3 - 2 * amount)
    else
        local clear = math.clamp((p - 0.62) / 0.30, 0, 1)
        clear = clear * clear * (3 - 2 * clear)
        amount = 1 - clear
    end
    BlurOverlay.Visible = AppleTransition.Running and amount > 0.025
    BlurOverlay.BackgroundTransparency = 1 - amount * 0.10
    Panel.GroupTransparency = amount * 0.028
    local sceneBlur = GetSceneBlur()
    sceneBlur.Enabled = AppleTransition.Running and amount > 0.03
    sceneBlur.Size = math.floor(amount * 5 + 0.5)
end

local function ClearSoftFocus()
    BlurOverlay.Visible = false
    BlurOverlay.BackgroundTransparency = 1
    Panel.GroupTransparency = 0
    if AppleTransition.SceneBlur and AppleTransition.SceneBlur.Parent then
        AppleTransition.SceneBlur.Size = 0
        AppleTransition.SceneBlur.Enabled = false
    end
end

local function BeginGeometry()
    AppleTransition.PanelTarget = State.PanelPosition or Vector2.new(Viewport.X / 2, Viewport.Y / 2)
    AppleTransition.ButtonTarget = State.ButtonPosition or Vector2.new(Viewport.X / 2, THEME.FloatingHeight / 2 + 10)
    local delta = AppleTransition.PanelTarget - AppleTransition.ButtonTarget
    AppleTransition.Direction = delta.Magnitude < 1 and Vector2.new(0, 1) or delta.Unit
    Panel.AnchorPoint = Vector2.new(0.5, 0.5)
end

local function ApplyTransition()
    local p = AppleTransition.Progress
    local travelP = math.clamp(p, 0, 1)
    local panelTarget = AppleTransition.PanelTarget
    local buttonTarget = AppleTransition.ButtonTarget
    local direction = AppleTransition.Direction
    local collapsedScale = GetCollapsedPanelScale()

    if UI.TransitionStyle == "老式款" then
        local buttonStage = 0.18
        Panel.AnchorPoint = Vector2.new(0.5, 0.5)
        Panel.Position = UDim2.fromOffset(panelTarget.X, panelTarget.Y)
        FloatingButton.Position = UDim2.fromOffset(buttonTarget.X, buttonTarget.Y)
        if travelP <= buttonStage then
            local bt = math.clamp(travelP / buttonStage, 0, 1)
            bt = bt * bt * (3 - 2 * bt)
            local width = math.max(2, THEME.FloatingWidth * (1 - bt) + 2 * bt)
            FloatingButton.Size = UDim2.fromOffset(width, THEME.FloatingHeight)
            FloatingButton.Visible = true
            Panel.Visible = false
            StartupScale.Scale = 0.08
            Panel.GroupTransparency = 0
        else
            local pt = math.clamp((travelP - buttonStage) / (1 - buttonStage), 0, 1)
            pt = 1 - (1 - pt) * (1 - pt) * (1 - pt)
            FloatingButton.Visible = false
            FloatingButton.Size = UDim2.fromOffset(2, THEME.FloatingHeight)
            Panel.Visible = true
            StartupScale.Scale = math.max(0.08, 0.08 + 0.92 * pt)
            Panel.GroupTransparency = (1 - pt) * 0.08
        end
        ApplySoftFocus(travelP)
        return
    end

    local smoothP = travelP * travelP * (3 - 2 * travelP)
    local pos = Vector2.new(
        buttonTarget.X + (panelTarget.X - buttonTarget.X) * smoothP,
        buttonTarget.Y + (panelTarget.Y - buttonTarget.Y) * smoothP
    )
    local leadCurve = math.sin(math.pi * smoothP)
    local leadDistance = math.clamp(math.min(PanelWidth, PanelHeight) * 0.055, 14, 30)
    pos = pos + direction * (leadCurve * leadDistance)

    Panel.AnchorPoint = Vector2.new(0.5, 0.5)
    Panel.Position = UDim2.fromOffset(pos.X, pos.Y)
    StartupScale.Scale = math.max(0.04, collapsedScale + (1 - collapsedScale) * smoothP)

    local buttonExitPoint = 0.055
    if AppleTransition.Target == 0 then
        FloatingButton.Visible = false
        Panel.Visible = true
    else
        Panel.Visible = true
        FloatingButton.Visible = travelP <= buttonExitPoint and not AppleTransition.ButtonMorphing
    end
    ApplySoftFocus(travelP)
end

local function CancelButtonMorph(makeFull)
    if AppleTransition.ButtonMorphTween then
        pcall(function() AppleTransition.ButtonMorphTween:Cancel() end)
        AppleTransition.ButtonMorphTween = nil
    end
    AppleTransition.ButtonMorphing = false
    if makeFull then
        FloatingButton.Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight)
    end
end

local function RevealFloatingButton()
    CancelButtonMorph(false)
    AppleTransition.ButtonMorphing = true
    FloatingButton.Position = UDim2.fromOffset(AppleTransition.ButtonTarget.X, AppleTransition.ButtonTarget.Y)
    FloatingButton.Size = UDim2.fromOffset(2, THEME.FloatingHeight)
    FloatingButton.Visible = true
    FloatingTransitionScale.Scale = 1
    local tween = TweenService:Create(
        FloatingButton,
        TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight) }
    )
    AppleTransition.ButtonMorphTween = tween
    tween:Play()
    task.spawn(function()
        tween.Completed:Wait()
        if AppleTransition.ButtonMorphTween ~= tween then return end
        AppleTransition.ButtonMorphTween = nil
        AppleTransition.ButtonMorphing = false
        FloatingButton.Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight)
        if AppleTransition.Target == 0 and not AppleTransition.Running and AppleTransition.Progress <= 0.001 then
            State.Minimized = true
            State.Animating = false
        end
    end)
end

local function SetAppleTarget(expanded)
    if not AppleTransition.Running then BeginGeometry() end
    if expanded and AppleTransition.ButtonMorphing then CancelButtonMorph(true) end
    AppleTransition.Target = expanded and 1 or 0
    AppleTransition.Running = true
    State.Animating = true
    if expanded then
        FloatingButton.Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight)
        FloatingButton.Visible = true
        Panel.Visible = true
    end
end

local function Minimize()
    if State.Minimized and not AppleTransition.Running then return end
    SetAppleTarget(false)
end

local function Restore()
    if (not State.Minimized) and (not AppleTransition.Running) and AppleTransition.Progress >= 0.999 then return end
    SetAppleTarget(true)
end

--==================================================================
-- 11. 拖动与位置限制
--==================================================================
local function ClampPanelPos(pos, size)
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local hx, hy = size.X / 2, size.Y / 2
    local keepX = math.min(96, size.X * 0.32)
    local keepY = math.min(76, size.Y * 0.32)
    return Vector2.new(
        math.clamp(pos.X, keepX - hx, vp.X - keepX + hx),
        math.clamp(pos.Y, keepY - hy, vp.Y - keepY + hy)
    )
end

local function SetPanelPosition(pos)
    local safe = ClampPanelPos(pos, Vector2.new(PanelWidth, PanelHeight))
    State.PanelPosition = safe
    Panel.Position = UDim2.fromOffset(safe.X, safe.Y)
end

local function SetButtonPosition(pos)
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local halfW, halfH = THEME.FloatingWidth / 2, THEME.FloatingHeight / 2
    local new = Vector2.new(
        math.clamp(pos.X, -halfW, vp.X + halfW),
        math.clamp(pos.Y, halfH, vp.Y - halfH)
    )
    State.ButtonPosition = new
    FloatingButton.Position = UDim2.fromOffset(new.X, new.Y)
end

SetPanelPosition(Vector2.new(Viewport.X / 2, Viewport.Y / 2))
SetButtonPosition(Vector2.new(Viewport.X * 0.5, THEME.FloatingHeight / 2 + 10))

-- 拖动面板
do
    local dragState = { active = false, start = nil, startPos = nil, touch = nil }
    local function StartDrag(input)
        if State.Animating then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragState.active = true
        dragState.start = input.Position
        dragState.startPos = State.PanelPosition or Vector2.new(Viewport.X / 2, Viewport.Y / 2)
        if input.UserInputType == Enum.UserInputType.Touch then dragState.touch = input end
    end
    DragArea.InputBegan:Connect(StartDrag)
    MoveBarHitArea.InputBegan:Connect(StartDrag)
    UserInputService.InputChanged:Connect(function(input)
        if not dragState.active or not dragState.start then return end
        local valid = input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragState.touch)
        if not valid then return end
        local delta = Vector2.new(input.Position.X - dragState.start.X, input.Position.Y - dragState.start.Y)
        SetPanelPosition(dragState.startPos + delta)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and input == dragState.touch) then
            dragState.active = false
            dragState.start = nil
            dragState.touch = nil
        end
    end)
end

-- 拖动悬浮按钮
do
    local dragState = { active = false, start = nil, startPos = nil, touch = nil, moved = false, suppressUntil = 0 }
    FloatingButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragState.active = true
        dragState.start = input.Position
        dragState.startPos = State.ButtonPosition or Vector2.new(Viewport.X / 2, THEME.FloatingHeight / 2 + 10)
        dragState.moved = false
        if input.UserInputType == Enum.UserInputType.Touch then dragState.touch = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragState.active or not dragState.start then return end
        local valid = input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragState.touch)
        if not valid then return end
        local delta = Vector2.new(input.Position.X - dragState.start.X, input.Position.Y - dragState.start.Y)
        if delta.Magnitude >= 7 then dragState.moved = true end
        SetButtonPosition(dragState.startPos + delta)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragState.active and dragState.moved then dragState.suppressUntil = os.clock() + 0.28 end
        dragState.active = false
        dragState.touch = nil
    end)
    FloatingOpenZone.Activated:Connect(function()
        if dragState.moved or os.clock() < dragState.suppressUntil then
            dragState.moved = false
            return
        end
        Restore()
    end)
end

-- 右下缩放
do
    local state = { resizing = false, startSize = nil, startPos = nil, startPointer = nil, touch = nil }
    ResizeHandle.InputBegan:Connect(function(input)
        if State.Animating or State.Minimized then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        state.resizing = true
        state.startSize = Vector2.new(Panel.AbsoluteSize.X, Panel.AbsoluteSize.Y)
        state.startPos = State.PanelPosition
        state.startPointer = input.Position
        if input.UserInputType == Enum.UserInputType.Touch then state.touch = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not state.resizing then return end
        local valid = input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == state.touch)
        if not valid then return end
        local dx = input.Position.X - state.startPointer.X
        local dy = input.Position.Y - state.startPointer.Y
        local newW = math.clamp(state.startSize.X + dx, THEME.MinPanelWidth, Viewport.X * 0.9)
        local newH = math.clamp(state.startSize.Y + dy, THEME.MinPanelHeight, Viewport.Y * 0.9)
        Panel.Size = UDim2.fromOffset(newW, newH)
        if state.startPos then SetPanelPosition(state.startPos + Vector2.new(dx / 2, dy / 2)) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and input == state.touch) then
            state.resizing = false
            state.touch = nil
        end
    end)
end

-- 悬浮按钮点击
CloseBtn.Activated:Connect(Minimize)
ExitBtn.Activated:Connect(function()
    MainGui:Destroy()
end)

--==================================================================
-- 12. 弹簧驱动（RenderStepped）
--==================================================================
RunService.RenderStepped:Connect(function(dt)
    if not AppleTransition.Running then return end
    dt = math.min(dt, 1 / 30)
    local stiffness = 135
    local damping = 19
    local displacement = AppleTransition.Target - AppleTransition.Progress
    local acceleration = displacement * stiffness - AppleTransition.Velocity * damping
    AppleTransition.Velocity = AppleTransition.Velocity + acceleration * dt
    AppleTransition.Progress = AppleTransition.Progress + AppleTransition.Velocity * dt
    AppleTransition.Progress = math.clamp(AppleTransition.Progress, -0.018, 1.028)

    local collapseCutoff = 0.13
    if UI.TransitionStyle ~= "老式款"
        and AppleTransition.Target == 0
        and AppleTransition.Velocity <= 0
        and AppleTransition.Progress <= collapseCutoff then
        AppleTransition.Progress = 0
        AppleTransition.Velocity = 0
        AppleTransition.Running = false
        ClearSoftFocus()
        Panel.Visible = false
        Panel.AnchorPoint = Vector2.new(0.5, 0.5)
        Panel.Position = UDim2.fromOffset(AppleTransition.PanelTarget.X, AppleTransition.PanelTarget.Y)
        StartupScale.Scale = 1
        FloatingButton.Visible = false
        State.Minimized = true
        RevealFloatingButton()
        return
    end

    ApplyTransition()

    local nearTarget = math.abs(AppleTransition.Target - AppleTransition.Progress) < 0.0022
    local slowEnough = math.abs(AppleTransition.Velocity) < 0.024
    if nearTarget and slowEnough then
        AppleTransition.Progress = AppleTransition.Target
        AppleTransition.Velocity = 0
        AppleTransition.Running = false
        ApplyTransition()

        if AppleTransition.Target == 0 then
            ClearSoftFocus()
            Panel.Visible = false
            Panel.AnchorPoint = Vector2.new(0.5, 0.5)
            Panel.Position = UDim2.fromOffset(AppleTransition.PanelTarget.X, AppleTransition.PanelTarget.Y)
            StartupScale.Scale = 1
            State.Minimized = true
            if UI.TransitionStyle == "老式款" then
                FloatingButton.Position = UDim2.fromOffset(AppleTransition.ButtonTarget.X, AppleTransition.ButtonTarget.Y)
                FloatingButton.Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight)
                FloatingButton.Visible = true
                FloatingTransitionScale.Scale = 1
                State.Animating = false
            else
                FloatingButton.Visible = false
                if State.Minimized then RevealFloatingButton() end
            end
        else
            ClearSoftFocus()
            Panel.AnchorPoint = Vector2.new(0.5, 0.5)
            Panel.Position = UDim2.fromOffset(AppleTransition.PanelTarget.X, AppleTransition.PanelTarget.Y)
            StartupScale.Scale = 1
            Panel.Visible = true
            FloatingButton.Visible = false
            FloatingButton.Size = UDim2.fromOffset(THEME.FloatingWidth, THEME.FloatingHeight)
            FloatingTransitionScale.Scale = 1
            State.Minimized = false
            CancelButtonMorph(true)
            State.Animating = false
        end
    end
end)

--==================================================================
-- 13. 通知与对话框
--==================================================================
local function Notify(title, content, success)
    local frame = Instance.new("Frame")
    frame.Name = "DB_Notify"
    frame.AnchorPoint = Vector2.new(1, 1)
    frame.Position = UDim2.new(1, -16, 1, -16)
    frame.Size = UDim2.fromOffset(300, 58)
    frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.ZIndex = 5000
    frame.Parent = MainGui
    AddCorner(frame, 12)
    AddPlainBorder(frame, 1, 0.35)
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
            task.delay(0.35, function() if frame and frame.Parent then frame:Destroy() end end)
        end
    end)
end

--==================================================================
-- 14. 通用组件
--==================================================================
local function DBClearRightList()
    for _, child in ipairs(ListScroll:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    ListScroll.CanvasPosition = Vector2.new(0, 0)
end

local function MakeRightTitle(textValue, order, large)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 0, large and 31 or 23)
    label.BackgroundTransparency = 1
    label.Text = textValue
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = large and 18 or 13
    label.Font = Enum.Font.GothamBlack
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.ZIndex = 22
    label.Parent = ListScroll
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = label
    return label
end

local function MakeRightCard(height, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -12, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.84
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 20
    card.Parent = ListScroll
    AddCorner(card, 11)
    AddPlainBorder(card, 0.8, 0.56)
    return card
end

local function MakeRightButton(title, height, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, height or 34)
    btn.BackgroundColor3 = UI.ButtonBackground
    btn.BackgroundTransparency = UI.ButtonTransparency
    btn.BorderSizePixel = 0
    btn.Text = title
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamMedium
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 20
    StyleLiquidButton(btn, 9)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = btn
    btn.Activated:Connect(function()
        if callback then pcall(callback) end
    end)
    btn.Parent = ListScroll
    return btn
end

--==================================================================
-- 15. 主页
--==================================================================
local HomePanel = Instance.new("Frame")
HomePanel.Name = "DB_Home_Panel"
HomePanel.Size = UDim2.new(1, 0, 1, -4)
HomePanel.Position = UDim2.new(0, 0, 0, 2)
HomePanel.BackgroundTransparency = 1
HomePanel.Visible = false
HomePanel.ZIndex = 20
HomePanel.Parent = RightList

local HomeScroll = Instance.new("ScrollingFrame")
HomeScroll.Size = UDim2.fromScale(1, 1)
HomeScroll.BackgroundTransparency = 1
HomeScroll.BorderSizePixel = 0
HomeScroll.ScrollBarThickness = 2
HomeScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 205)
HomeScroll.ScrollBarImageTransparency = 0.58
HomeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
HomeScroll.CanvasSize = UDim2.new()
HomeScroll.ZIndex = 21
HomeScroll.Parent = HomePanel

local HomeLayout = Instance.new("UIListLayout")
HomeLayout.Padding = UDim.new(0, 8)
HomeLayout.SortOrder = Enum.SortOrder.LayoutOrder
HomeLayout.Parent = HomeScroll

local HomePad = Instance.new("UIPadding")
HomePad.PaddingTop = UDim.new(0, 7)
HomePad.PaddingBottom = UDim.new(0, 8)
HomePad.PaddingLeft = UDim.new(0, 2)
HomePad.PaddingRight = UDim.new(0, 2)
HomePad.Parent = HomeScroll

local function CreateHomeCard(titleText, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -2, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.82
    card.BorderSizePixel = 0
    card.ZIndex = 22
    card.Parent = HomeScroll
    AddCorner(card, 11)
    AddPlainBorder(card, 0.85, 0.56)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 7)
    title.Size = UDim2.new(1, -24, 0, 20)
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 23
    title.Parent = card
    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.Position = UDim2.fromOffset(12, 29)
    value.Size = UDim2.new(1, -24, 1, -36)
    value.Text = ""
    value.TextColor3 = Color3.fromRGB(255, 255, 255)
    value.TextSize = 11
    value.Font = Enum.Font.GothamMedium
    value.TextWrapped = true
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.TextYAlignment = Enum.TextYAlignment.Top
    value.ZIndex = 23
    value.Parent = card
    return card, value
end

-- 玩家信息卡（左侧栏）
local PlayerInfoCard = Instance.new("Frame")
PlayerInfoCard.Size = UDim2.new(1, -10, 0, 238)
PlayerInfoCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PlayerInfoCard.BackgroundTransparency = 0.76
PlayerInfoCard.BorderSizePixel = 0
PlayerInfoCard.LayoutOrder = 1
PlayerInfoCard.Position = UDim2.fromOffset(5, 4)
PlayerInfoCard.ZIndex = 22
PlayerInfoCard.Parent = PlayerProfileScroll
AddCorner(PlayerInfoCard, 12)
AddPlainBorder(PlayerInfoCard, 1.05, 0.38)

local PlayerInfoTitle = Instance.new("TextLabel")
PlayerInfoTitle.BackgroundTransparency = 1
PlayerInfoTitle.Position = UDim2.fromOffset(8, 7)
PlayerInfoTitle.Size = UDim2.new(1, -16, 0, 19)
PlayerInfoTitle.Text = "玩家信息"
PlayerInfoTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerInfoTitle.TextSize = 11
PlayerInfoTitle.Font = Enum.Font.GothamBold
PlayerInfoTitle.TextXAlignment = Enum.TextXAlignment.Left
PlayerInfoTitle.ZIndex = 24
PlayerInfoTitle.Parent = PlayerInfoCard

local PlayerAvatar = Instance.new("ImageLabel")
PlayerAvatar.Position = UDim2.fromOffset(8, 31)
PlayerAvatar.Size = UDim2.new(1, -16, 0, 86)
PlayerAvatar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PlayerAvatar.BackgroundTransparency = 0.82
PlayerAvatar.BorderSizePixel = 0
PlayerAvatar.ScaleType = Enum.ScaleType.Crop
PlayerAvatar.ZIndex = 24
PlayerAvatar.Parent = PlayerInfoCard
AddCorner(PlayerAvatar, 8)
AddPlainBorder(PlayerAvatar, 1.15, 0.12)

local PlayerNameLabel = Instance.new("TextLabel")
PlayerNameLabel.BackgroundTransparency = 1
PlayerNameLabel.Position = UDim2.fromOffset(8, 124)
PlayerNameLabel.Size = UDim2.new(1, -16, 0, 31)
PlayerNameLabel.Text = "玩家名字：读取中..."
PlayerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerNameLabel.TextSize = 10
PlayerNameLabel.Font = Enum.Font.GothamBold
PlayerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerNameLabel.TextWrapped = true
PlayerNameLabel.ZIndex = 24
PlayerNameLabel.Parent = PlayerInfoCard

local PlayerAgeLabel = Instance.new("TextLabel")
PlayerAgeLabel.BackgroundTransparency = 1
PlayerAgeLabel.Position = UDim2.fromOffset(8, 157)
PlayerAgeLabel.Size = UDim2.new(1, -16, 0, 28)
PlayerAgeLabel.Text = "账号年龄：读取中..."
PlayerAgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerAgeLabel.TextSize = 9
PlayerAgeLabel.Font = Enum.Font.GothamMedium
PlayerAgeLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerAgeLabel.TextWrapped = true
PlayerAgeLabel.ZIndex = 24
PlayerAgeLabel.Parent = PlayerInfoCard

local PlayerUsernameLabel = Instance.new("TextLabel")
PlayerUsernameLabel.BackgroundTransparency = 1
PlayerUsernameLabel.Position = UDim2.fromOffset(8, 188)
PlayerUsernameLabel.Size = UDim2.new(1, -16, 0, 40)
PlayerUsernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerUsernameLabel.TextSize = 9
PlayerUsernameLabel.Font = Enum.Font.GothamBold
PlayerUsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerUsernameLabel.TextWrapped = true
PlayerUsernameLabel.ZIndex = 24
PlayerUsernameLabel.Parent = PlayerInfoCard

task.spawn(function()
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok and PlayerAvatar.Parent then
        PlayerAvatar.Image = content
    end
end)
PlayerNameLabel.Text = "玩家名字：\n" .. tostring(LocalPlayer.DisplayName)
PlayerAgeLabel.Text = "账号年龄：\n" .. tostring(LocalPlayer.AccountAge) .. " 天"
PlayerUsernameLabel.Text = "玩家用户名：\n" .. tostring(LocalPlayer.Name)

-- 主页内容卡
local ProcessCard, ProcessValue = CreateHomeCard("运行状态", 92)
ProcessCard.LayoutOrder = 2

local ServerCard, ServerValue = CreateHomeCard("服务器在线人数", 58)
ServerCard.LayoutOrder = 3

local PlayersCard, PlayersValue = CreateHomeCard("服务器玩家", 118)
PlayersCard.LayoutOrder = 4
PlayersValue.Visible = false

-- 玩家列表滚动区
local ServerPlayersScroll = Instance.new("ScrollingFrame")
ServerPlayersScroll.Position = UDim2.fromOffset(10, 28)
ServerPlayersScroll.Size = UDim2.new(1, -18, 1, -34)
ServerPlayersScroll.BackgroundTransparency = 1
ServerPlayersScroll.BorderSizePixel = 0
ServerPlayersScroll.ScrollBarThickness = 3
ServerPlayersScroll.ScrollBarImageColor3 = Color3.fromRGB(125, 205, 255)
ServerPlayersScroll.ScrollBarImageTransparency = 0.18
ServerPlayersScroll.CanvasSize = UDim2.new()
ServerPlayersScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ServerPlayersScroll.ZIndex = 24
ServerPlayersScroll.Parent = PlayersCard

local ServerPlayersContent = Instance.new("Frame")
ServerPlayersContent.Size = UDim2.new(1, -5, 0, 0)
ServerPlayersContent.BackgroundTransparency = 1
ServerPlayersContent.BorderSizePixel = 0
ServerPlayersContent.ZIndex = 24
ServerPlayersContent.Parent = ServerPlayersScroll

local ServerPlayersLayout = Instance.new("UIListLayout")
ServerPlayersLayout.Padding = UDim.new(0, 3)
ServerPlayersLayout.SortOrder = Enum.SortOrder.LayoutOrder
ServerPlayersLayout.Parent = ServerPlayersContent

local function RefreshPlayersList()
    for _, child in ipairs(ServerPlayersContent:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
    for index, player in ipairs(players) do
        local row = Instance.new("TextLabel")
        row.LayoutOrder = index
        row.Size = UDim2.new(1, -2, 0, 20)
        row.BackgroundColor3 = Color3.fromRGB(18, 24, 33)
        row.BackgroundTransparency = index % 2 == 0 and 0.82 or 0.92
        row.BorderSizePixel = 0
        row.Text = index .. ". " .. player.DisplayName .. "  (@" .. player.Name .. ")"
        row.TextColor3 = Color3.fromRGB(242, 246, 252)
        row.TextSize = 10
        row.Font = Enum.Font.GothamMedium
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextTruncate = Enum.TextTruncate.AtEnd
        row.ZIndex = 25
        row.Parent = ServerPlayersContent
        AddCorner(row, 5)
    end
    local height = ServerPlayersLayout.AbsoluteContentSize.Y + 9
    ServerPlayersContent.Size = UDim2.new(1, -5, 0, height)
    ServerPlayersScroll.CanvasSize = UDim2.fromOffset(0, height)
end

local AuthorCard, AuthorValue = CreateHomeCard("DB作者", 108)
AuthorCard.LayoutOrder = 5
AuthorValue.Text = "开发者：DB Team\nUI设计：DB Team\n框架版本：独立精简版\n本框架不含任何游戏功能"

local TimeCard, TimeValue = CreateHomeCard("现实时间 · 北京时间", 66)
TimeCard.LayoutOrder = 6

local function GetBeijingTime()
    local unixNow = nil
    local ok, value = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(value) == "number" and value > 1000000000 then unixNow = value else unixNow = os.time() end
    return os.date("!%Y-%m-%d %H:%M:%S", math.floor(unixNow + 8 * 60 * 60))
end

--==================================================================
-- 16. 性能卡（FPS/Ping）
--==================================================================
local function CreatePerformanceCard()
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -2, 0, 288)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.82
    card.BorderSizePixel = 0
    card.LayoutOrder = 7
    card.ZIndex = 22
    card.Parent = HomeScroll
    AddCorner(card, 12)
    AddPlainBorder(card, 0.85, 0.56)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(13, 7)
    title.Size = UDim2.new(1, -26, 0, 20)
    title.Text = "实时帧率 / 网络延迟"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 24
    title.Parent = card

    local live = Instance.new("TextLabel")
    live.BackgroundTransparency = 1
    live.Position = UDim2.fromOffset(13, 29)
    live.Size = UDim2.new(0.55, -4, 0, 20)
    live.Text = "FPS：--    Ping：-- ms"
    live.TextColor3 = Color3.fromRGB(255, 255, 255)
    live.TextSize = 10
    live.Font = Enum.Font.GothamMedium
    live.TextXAlignment = Enum.TextXAlignment.Left
    live.ZIndex = 24
    live.Parent = card

    local stats = Instance.new("Frame")
    stats.Position = UDim2.fromOffset(10, 53)
    stats.Size = UDim2.new(1, -20, 0, 43)
    stats.BackgroundTransparency = 1
    stats.ZIndex = 24
    stats.Parent = card
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 2)
    layout.Parent = stats
    local statValues = {}
    for _, name in ipairs({"MAX", "MIN", "AVG", "JITTER", "5% LOW"}) do
        local cell = Instance.new("Frame")
        cell.Size = UDim2.new(0.2, -2, 1, 0)
        cell.BackgroundTransparency = 1
        cell.ZIndex = 24
        cell.Parent = stats
        local n = Instance.new("TextLabel")
        n.Size = UDim2.new(1, 0, 0, 14)
        n.BackgroundTransparency = 1
        n.Text = name
        n.TextColor3 = Color3.fromRGB(145, 148, 158)
        n.TextSize = 7
        n.ZIndex = 25
        n.Parent = cell
        local v = Instance.new("TextLabel")
        v.Position = UDim2.fromOffset(0, 14)
        v.Size = UDim2.new(1, 0, 0, 20)
        v.BackgroundTransparency = 1
        v.Text = "--"
        v.TextColor3 = Color3.fromRGB(255, 255, 255)
        v.TextSize = 11
        v.Font = Enum.Font.GothamBold
        v.ZIndex = 25
        v.Parent = cell
        statValues[name] = v
    end

    local chart = Instance.new("Frame")
    chart.Position = UDim2.fromOffset(33, 102)
    chart.Size = UDim2.new(1, -39, 1, -122)
    chart.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    chart.BackgroundTransparency = 0.88
    chart.BorderSizePixel = 0
    chart.ZIndex = 23
    chart.Parent = card
    AddCorner(chart, 7)

    local lineLayer = Instance.new("Frame")
    lineLayer.Size = UDim2.fromScale(1, 1)
    lineLayer.BackgroundTransparency = 1
    lineLayer.ClipsDescendants = true
    lineLayer.ZIndex = 29
    lineLayer.Parent = chart

    local MAX_POINTS = 121
    local segments = {}
    for i = 1, MAX_POINTS - 1 do
        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Size = UDim2.fromOffset(0, 1)
        line.BackgroundColor3 = Color3.fromRGB(176, 178, 183)
        line.BorderSizePixel = 0
        line.Visible = false
        line.ZIndex = 30
        line.Parent = lineLayer
        segments[i] = line
    end

    local samples = {}
    local frameTimes = {}
    local SMOOTH_WINDOW = 0.75
    local SAMPLE_INTERVAL = 0.5
    local MAX_HISTORY = 121
    local HISTORY_WINDOW = 60
    local FPS_CAP = 60
    local AXIS_MAX = 120
    local sessionStart = time()
    local sampleClock = 0
    local lastStatsUpdate = 0
    local smoothedFPS = nil
    local smoothedPing = nil

    local function getWindowFPS(now)
        local cutoff = now - SMOOTH_WINDOW
        while #frameTimes > 0 and frameTimes[1].T < cutoff do table.remove(frameTimes, 1) end
        if #frameTimes < 2 then return nil end
        local totalDt = 0
        for _, f in ipairs(frameTimes) do totalDt = totalDt + f.Dt end
        if totalDt <= 0 then return nil end
        return math.clamp(#frameTimes / totalDt, 1, 240)
    end

    local function refreshGraph()
        local count = #samples
        local first = math.max(1, count - MAX_POINTS + 1)
        local plot = {}
        for i = first, count do plot[#plot + 1] = samples[i] end
        local w = math.max(1, lineLayer.AbsoluteSize.X)
        local h = math.max(1, lineLayer.AbsoluteSize.Y)
        local elapsed = math.max(0, time() - sessionStart)
        local rightTime = elapsed
        local leftTime = math.max(0, rightTime - HISTORY_WINDOW)
        local span = math.max(1, rightTime - leftTime)
        for i, line in ipairs(segments) do
            local a, b = plot[i], plot[i + 1]
            if a and b and HomePanel.Visible and Panel.Visible then
                local x1 = math.clamp((a.T - leftTime) / span, 0, 1) * w
                local x2 = math.clamp((b.T - leftTime) / span, 0, 1) * w
                local y1 = (1 - math.clamp(a.FPS / AXIS_MAX, 0, 1)) * h
                local y2 = (1 - math.clamp(b.FPS / AXIS_MAX, 0, 1)) * h
                local dx, dy = x2 - x1, y2 - y1
                local len = math.sqrt(dx * dx + dy * dy)
                line.Position = UDim2.fromOffset((x1 + x2) * 0.5, (y1 + y2) * 0.5)
                line.Size = UDim2.fromOffset(math.max(0.5, len), 1)
                line.Rotation = math.deg(math.atan2(dy, dx))
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end

    local function updateStats()
        local count = #samples
        if count == 0 then return end
        local sum, mx, mn = 0, -math.huge, math.huge
        local values = {}
        for i, s in ipairs(samples) do
            values[i] = s.FPS
            sum = sum + s.FPS
            mx = math.max(mx, s.FPS)
            mn = math.min(mn, s.FPS)
        end
        local avg = sum / count
        local variance = 0
        for _, v in ipairs(values) do
            local d = v - avg
            variance = variance + d * d
        end
        local deviation = math.sqrt(variance / math.max(1, count))
        local jitter = avg > 0 and (deviation / avg * 100) or 0
        table.sort(values)
        local lowCount = math.max(1, math.floor(count * 0.05 + 0.5))
        local lowSum = 0
        for i = 1, lowCount do lowSum = lowSum + values[i] end
        local low5 = lowSum / lowCount
        statValues["MAX"].Text = string.format("%.1f", mx)
        statValues["MIN"].Text = string.format("%.1f", mn)
        statValues["AVG"].Text = string.format("%.1f", avg)
        statValues["JITTER"].Text = string.format("%.1f%%", jitter)
        statValues["5% LOW"].Text = string.format("%.1f", low5)
    end

    local function takeSample()
        local now = time()
        local raw = getWindowFPS(now)
        if not raw then return end
        raw = math.clamp(raw, 1, FPS_CAP)
        smoothedFPS = raw
        local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
        if ok and type(ping) == "number" then
            local pingMS = ping * 1000
            if not smoothedPing then smoothedPing = pingMS
            else smoothedPing = smoothedPing + (pingMS - smoothedPing) * 0.30 end
        end
        local elapsed = now - sessionStart
        table.insert(samples, { FPS = smoothedFPS, T = elapsed })
        local cutoff = math.max(0, elapsed - HISTORY_WINDOW)
        while #samples > 0 and samples[1].T < cutoff do table.remove(samples, 1) end
        while #samples > MAX_HISTORY do table.remove(samples, 1) end
        live.Text = string.format("FPS：%d    Ping：%d ms", math.floor(smoothedFPS + 0.5), math.floor((smoothedPing or 0) + 0.5))
        refreshGraph()
        if now - lastStatsUpdate >= 1.5 then
            lastStatsUpdate = now
            updateStats()
        end
    end

    RunService.RenderStepped:Connect(function(dt)
        local now = time()
        table.insert(frameTimes, { T = now, Dt = dt })
        sampleClock = sampleClock + dt
        while sampleClock >= SAMPLE_INTERVAL do
            sampleClock = sampleClock - SAMPLE_INTERVAL
            takeSample()
        end
    end)

    HomePanel:GetPropertyChangedSignal("Visible"):Connect(function()
        if HomePanel.Visible then refreshGraph() end
    end)
end

CreatePerformanceCard()

-- 主页刷新
local function RefreshHomePage()
    if not ProcessValue or not ProcessValue.Parent then return end
    ProcessValue.Text = "DB UI Framework · 运行中\n仅提供界面，业务页面通过 API 注入"
    ServerValue.Text = "当前在线：" .. tostring(#Players:GetPlayers()) .. " 人"
    RefreshPlayersList()
    TimeValue.Text = GetBeijingTime() .. "\nUTC+8 · 中国标准时间"
end

Players.PlayerAdded:Connect(function()
    if HomePanel.Visible then task.defer(RefreshHomePage) end
end)
Players.PlayerRemoving:Connect(function()
    if HomePanel.Visible then task.defer(RefreshHomePage) end
end)

local function ShowHomePage()
    ListScroll.Visible = false
    HomePanel.Visible = true
    State.CurrentCategory = "主页"
    RefreshHomePage()
end

--==================================================================
-- 17. UI界面（壁纸/透明度/颜色/亮度）
--==================================================================
local UIInterface = {}

function UIInterface.ShowWallpaperSelection()
    DBClearRightList()
    State.CurrentCategory = "UI界面/壁纸"
    local back = MakeRightButton("←  返回UI界面", 32, 1, function() UIInterface.Show() end)
    MakeRightTitle("选择壁纸", 2)
    for index, item in ipairs(Wallpapers) do
        local card = Instance.new("ImageButton")
        card.Size = UDim2.new(1, -12, 0, 92)
        card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        card.BackgroundTransparency = 0.91
        card.BorderSizePixel = 0
        card.Image = item.Url or ""
        card.ImageTransparency = 0.05
        card.ScaleType = Enum.ScaleType.Crop
        card.AutoButtonColor = false
        card.LayoutOrder = index + 2
        card.ZIndex = 20
        card.Parent = ListScroll
        AddCorner(card, 10)
        local stroke = AddPlainBorder(card, CurrentWallpaperIndex == index and 1.5 or 0.8, CurrentWallpaperIndex == index and 0.18 or 0.62)
        local shade = Instance.new("Frame")
        shade.Size = UDim2.fromScale(1, 1)
        shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shade.BackgroundTransparency = 0.67
        shade.BorderSizePixel = 0
        shade.ZIndex = 21
        shade.Parent = card
        AddCorner(shade, 10)
        local label = Instance.new("TextLabel")
        label.Position = UDim2.fromOffset(12, 0)
        label.Size = UDim2.new(1, -24, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = item.Name or ("壁纸 " .. index)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 22
        label.Parent = card
        card.Activated:Connect(function()
            ApplyWallpaper(index)
            UIInterface.ShowWallpaperSelection()
        end)
    end
end

function UIInterface.Show()
    DBClearRightList()
    State.CurrentCategory = "UI界面"
    MakeRightTitle("UI界面", 1)

    MakeRightButton("壁纸", 44, 2, function() UIInterface.ShowWallpaperSelection() end)

    -- 壁纸透明度滑条
    local transRow = MakeRightCard(64, 3)
    local transLabel = Instance.new("TextLabel")
    transLabel.Position = UDim2.fromOffset(12, 4)
    transLabel.Size = UDim2.new(1, -24, 0, 18)
    transLabel.BackgroundTransparency = 1
    transLabel.Text = "壁纸透明度：" .. math.floor(UI.WallpaperTransparency * 100) .. "%"
    transLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    transLabel.TextSize = 13
    transLabel.Font = Enum.Font.GothamBlack
    transLabel.TextXAlignment = Enum.TextXAlignment.Left
    transLabel.ZIndex = 21
    transLabel.Parent = transRow
    local transTrack = Instance.new("Frame")
    transTrack.Position = UDim2.new(0, 14, 0, 41)
    transTrack.Size = UDim2.new(1, -28, 0, 6)
    transTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    transTrack.BackgroundTransparency = 0.72
    transTrack.BorderSizePixel = 0
    transTrack.ZIndex = 22
    transTrack.Parent = transRow
    AddCorner(transTrack, 999)
    local transFill = Instance.new("Frame")
    transFill.Size = UDim2.new(UI.WallpaperTransparency, 0, 1, 0)
    transFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    transFill.BorderSizePixel = 0
    transFill.ZIndex = 23
    transFill.Parent = transTrack
    AddCorner(transFill, 999)
    local transKnob = Instance.new("Frame")
    transKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    transKnob.Position = UDim2.new(UI.WallpaperTransparency, 0, 0.5, 0)
    transKnob.Size = UDim2.fromOffset(16, 16)
    transKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    transKnob.BorderSizePixel = 0
    transKnob.ZIndex = 24
    transKnob.Parent = transTrack
    AddCorner(transKnob, 999)
    local dragging = false
    local function setFromX(x)
        local w = math.max(1, transTrack.AbsoluteSize.X)
        local ratio = math.clamp((x - transTrack.AbsolutePosition.X) / w, 0, 1)
        transFill.Size = UDim2.new(ratio, 0, 1, 0)
        transKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
        transLabel.Text = "壁纸透明度：" .. math.floor(ratio * 100) .. "%"
        UI.WallpaperTransparency = ratio
        RefreshWallpaper()
    end
    transTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- 按钮边框开关
    local borderRow = MakeRightCard(44, 4)
    local borderTitle = Instance.new("TextLabel")
    borderTitle.Position = UDim2.fromOffset(12, 0)
    borderTitle.Size = UDim2.new(1, -88, 1, 0)
    borderTitle.BackgroundTransparency = 1
    borderTitle.Text = "按钮边框"
    borderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    borderTitle.TextSize = 13
    borderTitle.Font = Enum.Font.GothamBlack
    borderTitle.TextXAlignment = Enum.TextXAlignment.Left
    borderTitle.ZIndex = 21
    borderTitle.Parent = borderRow
    local switch = Instance.new("TextButton")
    switch.AnchorPoint = Vector2.new(1, 0.5)
    switch.Position = UDim2.new(1, -12, 0.5, 0)
    switch.Size = UDim2.fromOffset(48, 24)
    switch.BackgroundColor3 = UI.ButtonBordersEnabled and Color3.fromRGB(205, 210, 220) or Color3.fromRGB(62, 65, 72)
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.ZIndex = 22
    switch.Parent = borderRow
    AddCorner(switch, 999)
    local switchKnob = Instance.new("Frame")
    switchKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    switchKnob.Position = UI.ButtonBordersEnabled and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 12, 0.5, 0)
    switchKnob.Size = UDim2.fromOffset(19, 19)
    switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchKnob.BorderSizePixel = 0
    switchKnob.ZIndex = 23
    switchKnob.Parent = switch
    AddCorner(switchKnob, 999)
    switch.Activated:Connect(function()
        UI.ButtonBordersEnabled = not UI.ButtonBordersEnabled
        TweenService:Create(switchKnob, TweenInfo.new(0.18), {
            Position = UI.ButtonBordersEnabled and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 12, 0.5, 0)
        }):Play()
        TweenService:Create(switch, TweenInfo.new(0.18), {
            BackgroundColor3 = UI.ButtonBordersEnabled and Color3.fromRGB(205, 210, 220) or Color3.fromRGB(62, 65, 72)
        }):Play()
    end)
end

--==================================================================
-- 18. 公告
--==================================================================
local Announcement = {}
function Announcement.Show()
    DBClearRightList()
    State.CurrentCategory = "公告"
    MakeRightTitle("公告", 1)
    local card = MakeRightCard(430, 2)
    local header = Instance.new("TextLabel")
    header.Position = UDim2.fromOffset(14, 9)
    header.Size = UDim2.new(1, -28, 0, 28)
    header.BackgroundTransparency = 1
    header.Text = "公告"
    header.TextColor3 = Color3.fromRGB(255, 255, 255)
    header.TextSize = 17
    header.Font = Enum.Font.GothamBlack
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 20
    header.Parent = card
    local line = Instance.new("Frame")
    line.Position = UDim2.fromOffset(14, 40)
    line.Size = UDim2.new(1, -28, 0, 1)
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BackgroundTransparency = 0.70
    line.BorderSizePixel = 0
    line.ZIndex = 20
    line.Parent = card
    local content = Instance.new("TextLabel")
    content.Position = UDim2.fromOffset(14, 50)
    content.Size = UDim2.new(1, -28, 1, -62)
    content.BackgroundTransparency = 1
    content.Text = AnnouncementText
    content.TextColor3 = Color3.fromRGB(255, 255, 255)
    content.TextSize = 12
    content.Font = Enum.Font.GothamMedium
    content.TextWrapped = true
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.ZIndex = 20
    content.Parent = card
end

--==================================================================
-- 19. 设置
--==================================================================
local Settings = {}
function Settings.Show()
    DBClearRightList()
    State.CurrentCategory = "设置"
    MakeRightTitle("设置", 1)

    -- 过渡动画样式
    local row = MakeRightCard(58, 2)
    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(10, 0)
    label.Size = UDim2.new(0.44, -14, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "过渡动画样式"
    label.TextColor3 = Color3.fromRGB(250, 250, 252)
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 21
    label.Parent = row
    local options = { "原版", "增加模糊", "老式款" }
    local index = 1
    for i, name in ipairs(options) do
        if name == UI.TransitionStyle then index = i end
    end
    local selector = Instance.new("TextButton")
    selector.AnchorPoint = Vector2.new(1, 0.5)
    selector.Position = UDim2.new(1, -10, 0.5, 0)
    selector.Size = UDim2.new(0.40, 0, 0, 30)
    selector.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
    selector.BorderSizePixel = 0
    selector.AutoButtonColor = false
    selector.Text = ""
    selector.ZIndex = 22
    selector.Parent = row
    AddCorner(selector, 999)
    local selectorLabel = Instance.new("TextLabel")
    selectorLabel.Position = UDim2.fromOffset(12, 0)
    selectorLabel.Size = UDim2.new(1, -44, 1, 0)
    selectorLabel.BackgroundTransparency = 1
    selectorLabel.Text = UI.TransitionStyle
    selectorLabel.TextColor3 = Color3.fromRGB(242, 242, 246)
    selectorLabel.TextSize = 11
    selectorLabel.Font = Enum.Font.GothamBold
    selectorLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectorLabel.ZIndex = 23
    selectorLabel.Parent = selector
    selector.Activated:Connect(function()
        index = (index % #options) + 1
        UI.TransitionStyle = options[index]
        selectorLabel.Text = UI.TransitionStyle
    end)

    local note = Instance.new("TextLabel")
    note.Size = UDim2.new(1, -18, 0, 40)
    note.BackgroundTransparency = 1
    note.Text = "提示：本框架仅含界面。如需注入业务页面，请调用 DBUI.RegisterCategory / DBUI.RegisterPage。"
    note.TextColor3 = Color3.fromRGB(170, 176, 190)
    note.TextSize = 9
    note.Font = Enum.Font.GothamMedium
    note.TextWrapped = true
    note.TextXAlignment = Enum.TextXAlignment.Left
    note.TextYAlignment = Enum.TextYAlignment.Top
    note.LayoutOrder = 3
    note.ZIndex = 20
    note.Parent = ListScroll
end

--==================================================================
-- 20. 脚本合集外壳
--==================================================================
local ScriptCollection = {}
local scriptCategories = {}

local function ApplyRightFullWidthButton(btn, height)
    btn.Size = UDim2.new(1, -12, 0, height or 30)
end

function ScriptCollection.ShowCategory(name)
    DBClearRightList()
    State.CurrentCategory = "脚本合集/" .. name
    ListScroll.Visible = true
    local detail = Instance.new("Frame")
    detail.Position = UDim2.fromOffset(5, 4)
    detail.Size = UDim2.new(1, -10, 1, -8)
    detail.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    detail.BackgroundTransparency = 0.91
    detail.BorderSizePixel = 0
    detail.ClipsDescendants = true
    detail.ZIndex = 40
    detail.Parent = RightList
    AddCorner(detail, 12)
    AddPlainBorder(detail, 0.9, 0.48)

    local back = Instance.new("TextButton")
    back.Position = UDim2.fromOffset(8, 7)
    back.Size = UDim2.fromOffset(31, 31)
    back.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    back.BackgroundTransparency = 0.84
    back.BorderSizePixel = 0
    back.Text = "←"
    back.TextColor3 = Color3.fromRGB(255, 255, 255)
    back.TextSize = 18
    back.Font = Enum.Font.GothamBlack
    back.AutoButtonColor = false
    back.ZIndex = 43
    back.Parent = detail
    AddCorner(back, 999)
    back.Activated:Connect(function()
        detail:Destroy()
        ScriptCollection.Show()
    end)

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(48, 7)
    title.Size = UDim2.new(1, -58, 0, 31)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 43
    title.Parent = detail

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.fromOffset(7, 45)
    scroll.Size = UDim2.new(1, -14, 1, -52)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
    scroll.ScrollBarImageTransparency = 0.50
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.ZIndex = 42
    scroll.Parent = detail
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = scroll
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 3)
    pad.PaddingRight = UDim.new(0, 3)
    pad.Parent = scroll

    local loader = scriptCategories[name]
    if type(loader) == "function" then
        -- 提供统一的 addButton 让业务方注入条目
        local function addButton(label, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, 34)
            btn.BackgroundColor3 = UI.ButtonBackground
            btn.BackgroundTransparency = UI.ButtonTransparency
            btn.BorderSizePixel = 0
            btn.Text = label
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 13
            btn.Font = Enum.Font.GothamMedium
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            btn.AutoButtonColor = false
            btn.ZIndex = 43
            btn.Parent = scroll
            StyleLiquidButton(btn, 9)
            local p = Instance.new("UIPadding")
            p.PaddingLeft = UDim.new(0, 12)
            p.PaddingRight = UDim.new(0, 12)
            p.Parent = btn
            btn.Activated:Connect(function() if callback then pcall(callback) end end)
            return btn
        end
        pcall(loader, scroll, addButton)
    else
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -8, 0, 42)
        empty.BackgroundTransparency = 1
        empty.Text = "该分类尚未注册脚本"
        empty.TextColor3 = Color3.fromRGB(235, 235, 240)
        empty.TextSize = 13
        empty.Font = Enum.Font.GothamMedium
        empty.ZIndex = 43
        empty.Parent = scroll
    end
end

function ScriptCollection.Show()
    ListScroll.Visible = true
    MakeRightTitle("脚本合集", 1)
    local names = {}
    for name in pairs(scriptCategories) do table.insert(names, name) end
    table.sort(names)
    for index, name in ipairs(names) do
        local btn = Instance.new("TextButton")
        ApplyRightFullWidthButton(btn, 38)
        btn.BackgroundColor3 = UI.ButtonBackground
        btn.BackgroundTransparency = UI.ButtonTransparency
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBlack
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.LayoutOrder = index + 1
        btn.ZIndex = 18
        StyleLiquidButton(btn, 10)
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 12)
        p.PaddingRight = UDim.new(0, 12)
        p.Parent = btn
        btn.Activated:Connect(function() ScriptCollection.ShowCategory(name) end)
        btn.Parent = ListScroll
    end
end

--==================================================================
-- 21. 导航栏构建
--==================================================================
local navButtons = {}
local function AddNavButton(label, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 34)
    btn.BackgroundColor3 = UI.ButtonBackground
    btn.BackgroundTransparency = UI.ButtonTransparency
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBlack
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 16
    StyleLiquidButton(btn, 11)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 10)
    p.PaddingRight = UDim.new(0, 10)
    p.Parent = btn
    btn.Activated:Connect(function() if callback then pcall(callback) end end)
    btn.Parent = MenuScroll
    navButtons[#navButtons + 1] = btn
    return btn
end

AddNavButton("主页", 1, ShowHomePage)
AddNavButton("公告", 2, function() Announcement.Show() end)
AddNavButton("脚本合集", 3, function() ScriptCollection.Show() end)
AddNavButton("UI界面", 4, function() UIInterface.Show() end)
AddNavButton("设置", 5, function() Settings.Show() end)

--==================================================================
-- 22. 公共 API
--==================================================================
local DBUI = {}
DBUI.Window = Panel
DBUI.FloatingButton = FloatingButton
DBUI.Notify = Notify
DBUI.Theme = UI
DBUI.State = State
DBUI.ShowHome = ShowHomePage
DBUI.Minimize = Minimize
DBUI.Restore = Restore
DBUI.Close = function() MainGui:Destroy() end

function DBUI.SetAssets(newAssets)
    if type(newAssets) ~= "table" then return end
    if type(newAssets.Logo) == "string" then
        Assets.Logo = newAssets.Logo
        HeaderLogo.Image = Assets.Logo
        FloatingBrandLogo.Image = Assets.Logo
    end
    if type(newAssets.MoveIcon) == "string" then
        Assets.MoveIcon = newAssets.MoveIcon
        FloatingMoveIcon.Image = Assets.MoveIcon
    end
end

function DBUI.SetWallpapers(list)
    if type(list) ~= "table" then return end
    Wallpapers = list
    if CurrentWallpaperIndex > 0 and #Wallpapers > 0 then
        ApplyWallpaper(math.min(CurrentWallpaperIndex, #Wallpapers))
    end
end

function DBUI.SetWallpaper(index)
    ApplyWallpaper(index)
end

function DBUI.SetAnnouncement(text)
    AnnouncementText = tostring(text or "")
end

function DBUI.RegisterCategory(name, loader)
    if type(name) ~= "string" or type(loader) ~= "function" then return end
    scriptCategories[name] = loader
end

function DBUI.RegisterPage(label, buildFn)
    if type(label) ~= "string" or type(buildFn) ~= "function" then return end
    AddNavButton(label, #navButtons + 2, function()
        DBClearRightList()
        HomePanel.Visible = false
        ListScroll.Visible = true
        State.CurrentCategory = label
        pcall(buildFn, ListScroll)
    end)
end

--==================================================================
-- 23. 初始化
--==================================================================
if not DBUI_Initialized then
    _G.DBUI = DBUI
    DBUI_Initialized = true
end

-- 启动动画：从悬浮状态展开
task.spawn(function()
    task.wait(0.1)
    Restore()
end)

print("[DB UI Framework] 独立精简版已加载 — 仅 UI，无游戏功能")
return DBUI
