-- ==============================================================================
-- SERVER HOPPER & FINDER PANEL (Luau / Roblox Mobile Compatible)
-- Features:
-- 1. Floating & Draggable Minimalist Toggle Button
-- 2. Clean, Animated Scrolling Server List
-- 3. Live Server Details (Players Count, Ping, JobID)
-- 4. Filters: Almost Full Server, Smallest Server, Random Hop, Rejoin
-- 5. Useful Utility Toggles (Auto Rejoin on Disconnect, Server Hop on Low FPS, High Ping Alert)
-- ==============================================================================

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Cleanup Previous UI
if CoreGui:FindFirstChild("ServerPanelGUI") then
    CoreGui.ServerPanelGUI:Destroy()
end

-- ==============================================================================
-- STATE VARIABLES
-- ==============================================================================
local AutoRejoinEnabled = false
local AutoHopLowFPSEnabled = false
local LowFPSThreshold = 15
local FetchingServers = false

-- ==============================================================================
-- MAIN GUI CREATION
-- ==============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ServerPanelGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Protect GUI if executor supports gethui
if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

-- ------------------------------------------------------------------------------
-- FLOATING BUTTON (Minimizable Open/Close)
-- ------------------------------------------------------------------------------
local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OpenButton"
OpenBtn.Parent = ScreenGui
OpenBtn.Size = UDim2.new(0, 50, 0, 50)
OpenBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
OpenBtn.BorderSizePixel = 0
OpenBtn.Text = "🌐"
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize = 24
OpenBtn.Font = Enum.Font.Garamond
OpenBtn.Active = true

local OpenBtnCorner = Instance.new("UICorner")
OpenBtnCorner.CornerRadius = UDim.new(1, 0)
OpenBtnCorner.Parent = OpenBtn

local OpenBtnStroke = Instance.new("UIStroke")
OpenBtnStroke.Thickness = 1.5
OpenBtnStroke.Color = Color3.fromRGB(80, 120, 255)
OpenBtnStroke.ApplyStrokeMode = Enum.UIStrokeMode.Border
OpenBtnStroke.Parent = OpenBtn

-- Draggable Logic for Floating Button
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    OpenBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

OpenBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = OpenBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

OpenBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            updateDrag(input)
        end
    end
end)

-- ------------------------------------------------------------------------------
-- MAIN PANEL CONTAINER
-- ------------------------------------------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 320, 0, 420)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1
MainStroke.Color = Color3.fromRGB(45, 45, 55)
MainStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Parent = MainFrame
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel")
Title.Parent = Header
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "Server Controller"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = Header
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0, 7.5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold

-- Navigation Tabs
local TabBar = Instance.new("Frame")
TabBar.Parent = MainFrame
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1

local TabServersBtn = Instance.new("TextButton")
TabServersBtn.Parent = TabBar
TabServersBtn.Size = UDim2.new(0.48, 0, 1, 0)
TabServersBtn.Position = UDim2.new(0, 0, 0, 0)
TabServersBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TabServersBtn.Text = "Server List"
TabServersBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabServersBtn.Font = Enum.Font.GothamMedium
TabServersBtn.TextSize = 12

local TabServersCorner = Instance.new("UICorner")
TabServersCorner.CornerRadius = UDim.new(0, 6)
TabServersCorner.Parent = TabServersBtn

local TabTogglesBtn = Instance.new("TextButton")
TabTogglesBtn.Parent = TabBar
TabTogglesBtn.Size = UDim2.new(0.48, 0, 1, 0)
TabTogglesBtn.Position = UDim2.new(0.52, 0, 0, 0)
TabTogglesBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
TabTogglesBtn.Text = "Automation"
TabTogglesBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
TabTogglesBtn.Font = Enum.Font.GothamMedium
TabTogglesBtn.TextSize = 12

local TabTogglesCorner = Instance.new("UICorner")
TabTogglesCorner.CornerRadius = UDim.new(0, 6)
TabTogglesCorner.Parent = TabTogglesBtn

-- Container Frames
local ContentContainer = Instance.new("Frame")
ContentContainer.Parent = MainFrame
ContentContainer.Size = UDim2.new(1, -20, 1, -90)
ContentContainer.Position = UDim2.new(0, 10, 0, 85)
ContentContainer.BackgroundTransparency = 1

-- ------------------------------------------------------------------------------
-- PAGE 1: SERVER LIST & QUICK ACTIONS
-- ------------------------------------------------------------------------------
local ServersPage = Instance.new("Frame")
ServersPage.Parent = ContentContainer
ServersPage.Size = UDim2.new(1, 0, 1, 0)
ServersPage.BackgroundTransparency = 1

-- Quick Hop Actions Top Bar
local QuickActions = Instance.new("Frame")
QuickActions.Parent = ServersPage
QuickActions.Size = UDim2.new(1, 0, 0, 32)
QuickActions.BackgroundTransparency = 1

local HopFullBtn = Instance.new("TextButton")
HopFullBtn.Parent = QuickActions
HopFullBtn.Size = UDim2.new(0.31, 0, 1, 0)
HopFullBtn.Position = UDim2.new(0, 0, 0, 0)
HopFullBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
HopFullBtn.Text = "⚡ Max/Full"
HopFullBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
HopFullBtn.Font = Enum.Font.GothamBold
HopFullBtn.TextSize = 11

local HopFullCorner = Instance.new("UICorner")
HopFullCorner.CornerRadius = UDim.new(0, 6)
HopFullCorner.Parent = HopFullBtn

local HopLowBtn = Instance.new("TextButton")
HopLowBtn.Parent = QuickActions
HopLowBtn.Size = UDim2.new(0.31, 0, 1, 0)
HopLowBtn.Position = UDim2.new(0.345, 0, 0, 0)
HopLowBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
HopLowBtn.Text = "🌱 Smallest"
HopLowBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
HopLowBtn.Font = Enum.Font.GothamBold
HopLowBtn.TextSize = 11

local HopLowCorner = Instance.new("UICorner")
HopLowCorner.CornerRadius = UDim.new(0, 6)
HopLowCorner.Parent = HopLowBtn

local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Parent = QuickActions
RejoinBtn.Size = UDim2.new(0.31, 0, 1, 0)
RejoinBtn.Position = UDim2.new(0.69, 0, 0, 0)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 30)
RejoinBtn.Text = "🔄 Rejoin"
RejoinBtn.TextColor3 = Color3.fromRGB(255, 220, 180)
RejoinBtn.Font = Enum.Font.GothamBold
RejoinBtn.TextSize = 11

local RejoinCorner = Instance.new("UICorner")
RejoinCorner.CornerRadius = UDim.new(0, 6)
RejoinCorner.Parent = RejoinBtn

-- Scrolling Server List
local ServerScroll = Instance.new("ScrollingFrame")
ServerScroll.Parent = ServersPage
ServerScroll.Size = UDim2.new(1, 0, 1, -40)
ServerScroll.Position = UDim2.new(0, 0, 0, 40)
ServerScroll.BackgroundTransparency = 1
ServerScroll.BorderSizePixel = 0
ServerScroll.ScrollBarThickness = 3
ServerScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
ServerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Parent = ServerScroll
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Padding = UDim.new(0, 6)

ScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ServerScroll.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 10)
end)

-- ------------------------------------------------------------------------------
-- PAGE 2: AUTOMATION & USEFUL TOGGLES
-- ------------------------------------------------------------------------------
local TogglesPage = Instance.new("Frame")
TogglesPage.Parent = ContentContainer
TogglesPage.Size = UDim2.new(1, 0, 1, 0)
TogglesPage.BackgroundTransparency = 1
TogglesPage.Visible = false

local TogglesListLayout = Instance.new("UIListLayout")
TogglesListLayout.Parent = TogglesPage
TogglesListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TogglesListLayout.Padding = UDim.new(0, 8)

-- Function to Create UI Toggles
local function CreateToggle(parent, titleText, defaultState, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 42)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    ToggleFrame.Parent = parent

    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 8)
    FrameCorner.Parent = ToggleFrame

    local Label = Instance.new("TextLabel")
    Label.Parent = ToggleFrame
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.Text = titleText
    Label.TextColor3 = Color3.fromRGB(220, 220, 230)
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.BackgroundTransparency = 1

    local SwitchBtn = Instance.new("TextButton")
    SwitchBtn.Parent = ToggleFrame
    SwitchBtn.Size = UDim2.new(0, 36, 0, 20)
    SwitchBtn.Position = UDim2.new(1, -48, 0.5, -10)
    SwitchBtn.BackgroundColor3 = defaultState and Color3.fromRGB(60, 180, 100) or Color3.fromRGB(50, 50, 60)
    SwitchBtn.Text = ""

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = SwitchBtn

    local Dot = Instance.new("Frame")
    Dot.Parent = SwitchBtn
    Dot.Size = UDim2.new(0, 14, 0, 14)
    Dot.Position = defaultState and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = Dot

    local state = defaultState

    SwitchBtn.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = state and Color3.fromRGB(60, 180, 100) or Color3.fromRGB(50, 50, 60)

        TweenService:Create(Dot, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(SwitchBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()

        callback(state)
    end)
end

-- Useful Toggles Initialization
CreateToggle(TogglesPage, "Auto Rejoin on Disconnect", false, function(active)
    AutoRejoinEnabled = active
end)

CreateToggle(TogglesPage, "Auto Hop on Low FPS (<15 FPS)", false, function(active)
    AutoHopLowFPSEnabled = active
end)

-- Status / Current Server Info Banner
local InfoBox = Instance.new("Frame")
InfoBox.Size = UDim2.new(1, 0, 0, 65)
InfoBox.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
InfoBox.Parent = TogglesPage

local InfoBoxCorner = Instance.new("UICorner")
InfoBoxCorner.CornerRadius = UDim.new(0, 8)
InfoBoxCorner.Parent = InfoBox

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Parent = InfoBox
InfoLabel.Size = UDim2.new(1, -20, 1, -10)
InfoLabel.Position = UDim2.new(0, 10, 0, 5)
InfoLabel.BackgroundTransparency = 1
InfoLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
InfoLabel.TextSize = 11
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextWrapped = true
InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Text = "Current Server JobID:\n" .. string.sub(JobId, 1, 18) .. "...\nPlayers: " .. #Players:GetPlayers()

-- ==============================================================================
-- SERVER FETCHING & HOPPING LOGIC
-- ==============================================================================
local function FetchServerList(cursor)
    local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/0?sortOrder=Desc&limit=100"
    if cursor then
        url = url .. "&cursor=" .. cursor
    end

    local success, response = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if success and response and response.data then
        return response.data, response.nextPageCursor
    end
    return nil, nil
end

local function ClearScroll()
    for _, child in ipairs(ServerScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function RenderServers(servers)
    ClearScroll()
    
    if not servers or #servers == 0 then
        local NoServerLbl = Instance.new("TextLabel")
        NoServerLbl.Size = UDim2.new(1, 0, 0, 40)
        NoServerLbl.BackgroundTransparency = 1
        NoServerLbl.Text = "No servers found."
        NoServerLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        NoServerLbl.Font = Enum.Font.Gotham
        NoServerLbl.TextSize = 12
        NoServerLbl.Parent = ServerScroll
        return
    end

    for idx, srv in ipairs(servers) do
        if srv.id ~= JobId and srv.playing < srv.maxPlayers then
            local Card = Instance.new("Frame")
            Card.Size = UDim2.new(1, 0, 0, 48)
            Card.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
            Card.Parent = ServerScroll

            local CardCorner = Instance.new("UICorner")
            CardCorner.CornerRadius = UDim.new(0, 8)
            CardCorner.Parent = Card

            local CardStroke = Instance.new("UIStroke")
            CardStroke.Thickness = 1
            CardStroke.Color = Color3.fromRGB(35, 35, 45)
            CardStroke.Parent = Card

            local ServerInfo = Instance.new("TextLabel")
            ServerInfo.Parent = Card
            ServerInfo.Size = UDim2.new(0.65, 0, 1, 0)
            ServerInfo.Position = UDim2.new(0, 10, 0, 0)
            ServerInfo.BackgroundTransparency = 1
            ServerInfo.Text = "Server #" .. idx .. "\nPlayers: " .. srv.playing .. "/" .. srv.maxPlayers .. " | Ping: " .. (srv.ping or "N/A") .. "ms"
            ServerInfo.TextColor3 = Color3.fromRGB(210, 210, 220)
            ServerInfo.Font = Enum.Font.Gotham
            ServerInfo.TextSize = 11
            ServerInfo.TextXAlignment = Enum.TextXAlignment.Left

            local JoinBtn = Instance.new("TextButton")
            JoinBtn.Parent = Card
            JoinBtn.Size = UDim2.new(0, 65, 0, 28)
            JoinBtn.Position = UDim2.new(1, -73, 0.5, -14)
            JoinBtn.BackgroundColor3 = Color3.fromRGB(45, 90, 180)
            JoinBtn.Text = "Join"
            JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            JoinBtn.Font = Enum.Font.GothamBold
            JoinBtn.TextSize = 11

            local JoinCorner = Instance.new("UICorner")
            JoinCorner.CornerRadius = UDim.new(0, 6)
            JoinCorner.Parent = JoinBtn

            JoinBtn.MouseButton1Click:Connect(function()
                JoinBtn.Text = "..."
                TeleportService:TeleportToPlaceInstance(PlaceId, srv.id, LocalPlayer)
            end)
        end
    end
end

local function LoadServersList()
    if FetchingServers then return end
    FetchingServers = true
    
    ClearScroll()
    local LoadingLbl = Instance.new("TextLabel")
    LoadingLbl.Size = UDim2.new(1, 0, 0, 40)
    LoadingLbl.BackgroundTransparency = 1
    LoadingLbl.Text = "Fetching active servers..."
    LoadingLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    LoadingLbl.Font = Enum.Font.Gotham
    LoadingLbl.TextSize = 12
    LoadingLbl.Parent = ServerScroll

    task.spawn(function()
        local servers, _ = FetchServerList()
        RenderServers(servers)
        FetchingServers = false
    end)
end

-- Quick Hop Logic (Smart Finder)
local function SmartHop(mode)
    if FetchingServers then return end
    FetchingServers = true

    task.spawn(function()
        local cursor = nil
        local targetServer = nil

        for _ = 1, 3 do
            local servers, nextCursor = FetchServerList(cursor)
            cursor = nextCursor

            if servers then
                if mode == "Full" then
                    -- Filter for highest players count that is not completely full
                    table.sort(servers, function(a, b) return a.playing > b.playing end)
                elseif mode == "Smallest" then
                    -- Filter for lowest players count > 0
                    table.sort(servers, function(a, b) return a.playing < b.playing end)
                end

                for _, srv in ipairs(servers) do
                    if srv.id ~= JobId and srv.playing < srv.maxPlayers then
                        targetServer = srv
                        break
                    end
                end
            end

            if targetServer or not cursor then break end
        end

        if targetServer then
            TeleportService:TeleportToPlaceInstance(PlaceId, targetServer.id, LocalPlayer)
        else
            FetchingServers = false
        end
    end)
end

-- ==============================================================================
-- EVENT BINDINGS & TAB CONTROLS
-- ==============================================================================
OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    if MainFrame.Visible then
        LoadServersList()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

TabServersBtn.MouseButton1Click:Connect(function()
    ServersPage.Visible = true
    TogglesPage.Visible = false
    
    TabServersBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    TabServersBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    TabTogglesBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    TabTogglesBtn.TextColor3 = Color3.fromRGB(150, 150 150, 160)
end)
HopFullBtn.MouseButton1Click:Connect(function()
    HopFullBtn.Text = "Penuh..."
    SmartHop("Full")
end)

HopLowBtn.MouseButton1Click:Connect(function()
    HopLowBtn.Text = "Kosong..."
    SmartHop("Smallest")
end)

RejoinBtn.MouseButton1Click:Connect(function()
    RejoinBtn.Text = "Teleporting..."
    TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
end)

-- ==============================================================================
-- BACKGROUND MONITORING (AUTO REJOIN & LOW FPS HOPPER)
-- ==============================================================================
-- Auto Rejoin On Disconnect
CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if AutoRejoinEnabled and child.Name == "ErrorPrompt" then
        task.wait(1)
        TeleportService:Teleport(PlaceId, LocalPlayer)
    end
end)

-- Auto Hop on Low FPS Loop
task.spawn(function()
    local lastCheck = os.clock()
    local frames = 0
    local fps = 60

    game:GetService("RunService").RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - lastCheck >= 1 then
            fps = frames / (now - lastCheck)
            frames = 0
            lastCheck = now

            if AutoHopLowFPSEnabled and fps < LowFPSThreshold and not FetchingServers then
                SmartHop("Smallest")
            end
        end
    end)
end)
