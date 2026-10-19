-- ==============================================================================
-- ZEN SERVER HOPPER & FINDER (Simple & Minimalist Single-Page)
-- ==============================================================================

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Cleanup Previous UI
if CoreGui:FindFirstChild("SimpleServerPanel") then
    CoreGui.SimpleServerPanel:Destroy()
end

-- State
local AutoRejoin = false
local AutoHopFPS = false
local IsFetching = false

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SimpleServerPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = gethui and gethui() or CoreGui

-- Floating Toggle Button
local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 45, 0, 45)
OpenBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
OpenBtn.Text = "🌐"
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize = 20
OpenBtn.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(1, 0)
OpenCorner.Parent = OpenBtn

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(70, 130, 255)
OpenStroke.Parent = OpenBtn

-- Draggable Floating Button
local dragging, dragStart, startPos
OpenBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = OpenBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        OpenBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Main Panel
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(40, 40, 50)
MainStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Server Controller"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Master Scrolling Container (Single Page)
local MasterScroll = Instance.new("ScrollingFrame")
MasterScroll.Size = UDim2.new(1, -16, 1, -55)
MasterScroll.Position = UDim2.new(0, 8, 0, 48)
MasterScroll.BackgroundTransparency = 1
MasterScroll.ScrollBarThickness = 3
MasterScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 90)
MasterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MasterScroll.Parent = MainFrame

local MasterLayout = Instance.new("UIListLayout")
MasterLayout.SortOrder = Enum.SortOrder.LayoutOrder
MasterLayout.Padding = UDim.new(0, 8)
MasterLayout.Parent = MasterScroll

MasterLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    MasterScroll.CanvasSize = UDim2.new(0, 0, 0, MasterLayout.AbsoluteContentSize.Y + 10)
end)

-- ==============================================================================
-- UI COMPONENTS (QUICK ACTIONS & TOGGLES)
-- ==============================================================================
-- Quick Actions Row
local ActionRow = Instance.new("Frame")
ActionRow.Size = UDim2.new(1, 0, 0, 32)
ActionRow.BackgroundTransparency = 1
ActionRow.LayoutOrder = 1
ActionRow.Parent = MasterScroll

local function CreateButton(parent, text, color, posScale, sizeW)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(sizeW, -3, 1, 0)
    btn.Position = UDim2.new(posScale, 0, 0, 0)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local HopFullBtn = CreateButton(ActionRow, "🔥 Penuh", Color3.fromRGB(50, 35, 70), 0, 0.32)
local HopSmallBtn = CreateButton(ActionRow, "❄️ Kosong", Color3.fromRGB(30, 55, 45), 0.34, 0.32)
local RejoinBtn = CreateButton(ActionRow, "🔄 Rejoin", Color3.fromRGB(60, 45, 30), 0.68, 0.32)

-- Section Divider
local function CreateHeaderLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(130, 130, 145)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

CreateHeaderLabel("PENGATURAN OTOMATIS").LayoutOrder = 2
MasterScroll.ChildAdded:Connect(function() end)

-- Toggles Container
local TogglesContainer = Instance.new("Frame")
TogglesContainer.Size = UDim2.new(1, 0, 0, 75)
TogglesContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
TogglesContainer.LayoutOrder = 3
TogglesContainer.Parent = MasterScroll

local TogglesCorner = Instance.new("UICorner")
TogglesCorner.CornerRadius = UDim.new(0, 8)
TogglesCorner.Parent = TogglesContainer

local function CreateToggleItem(parent, title, yPos, callback)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 0, 30)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 34, 0, 18)
    toggle.Position = UDim2.new(1, -44, 0, yPos + 6)
    toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    toggle.Text = ""
    toggle.Parent = parent

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = toggle

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 12, 0, 12)
    dot.Position = UDim2.new(0, 3, 0.5, -6)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.Parent = toggle

    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(1, 0)
    dCorner.Parent = dot

    local active = false
    toggle.MouseButton1Click:Connect(function()
        active = not active
        dot.Position = active and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        toggle.BackgroundColor3 = active and Color3.fromRGB(60, 170, 90) or Color3.fromRGB(45, 45, 55)
        callback(active)
    end)
end

CreateToggleItem(TogglesContainer, "Auto Rejoin saat Disconnect", 5, function(v) AutoRejoin = v end)
CreateToggleItem(TogglesContainer, "Auto Hop jika FPS < 15", 40, function(v) AutoHopFPS = v end)

CreateHeaderLabel("DAFTAR SERVER AKTIF").LayoutOrder = 4

-- Server List Container Frame inside Master Scroll
local ServerListContainer = Instance.new("Frame")
ServerListContainer.Size = UDim2.new(1, 0, 0, 180)
ServerListContainer.BackgroundTransparency = 1
ServerListContainer.LayoutOrder = 5
ServerListContainer.Parent = MasterScroll

local ServerListLayout = Instance.new("UIListLayout")
ServerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ServerListLayout.Padding = UDim.new(0, 5)
ServerListLayout.Parent = ServerListContainer

ServerListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ServerListContainer.Size = UDim2.new(1, 0, 0, math.max(180, ServerListLayout.AbsoluteContentSize.Y + 10))
end)

-- ==============================================================================
-- LOGIC & FUNCTIONS
-- ==============================================================================
local function FetchServers(cursor)
    local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/0?sortOrder=Desc&limit=100"
    if cursor then url = url .. "&cursor=" .. cursor end
    local success, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if success and res and res.data then return res.data, res.nextPageCursor end
    return nil, nil
end

local function ClearList()
    for _, child in ipairs(ServerListContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function LoadServers()
    if IsFetching then return end
    IsFetching = true
    ClearList()

    local loading = Instance.new("TextLabel")
    loading.Size = UDim2.new(1, 0, 0, 30)
    loading.BackgroundTransparency = 1
    loading.Text = "Mencari server..."
    loading.TextColor3 = Color3.fromRGB(150, 150, 150)
    loading.Font = Enum.Font.Gotham
    loading.TextSize = 11
    loading.Parent = ServerListContainer

    task.spawn(function()
        local servers = FetchServers()
        loading:Destroy()

        if not servers or #servers == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 30)
            empty.BackgroundTransparency = 1
            empty.Text = "Tidak ada server ditemukan."
            empty.TextColor3 = Color3.fromRGB(150, 150, 150)
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 11
            empty.Parent = ServerListContainer
            IsFetching = false
            return
        end

        for i, srv in ipairs(servers) do
            if srv.id ~= JobId and srv.playing < srv.maxPlayers then
                local card = Instance.new("Frame")
                card.Size = UDim2.new(1, 0, 0, 40)
                card.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                card.Parent = ServerListContainer

                local cCorner = Instance.new("UICorner")
                cCorner.CornerRadius = UDim.new(0, 6)
                cCorner.Parent = card

                local info = Instance.new("TextLabel")
                info.Size = UDim2.new(0.65, 0, 1, 0)
                info.Position = UDim2.new(0, 10, 0, 0)
                info.BackgroundTransparency = TypeError and 0 or 1
                info.Text = "#" .. i .. " | Pemain: " .. srv.playing .. "/" .. srv.maxPlayers
                info.TextColor3 = Color3.fromRGB(210, 210, 220)
                info.Font = Enum.Font.Gotham
                info.TextSize = 11
                info.TextXAlignment = Enum.TextXAlignment.Left
                info.Parent = card

                local join = Instance.new("TextButton")
                join.Size = UDim2.new(0, 55, 0, 24)
                join.Position = UDim2.new(1, -63, 0.5, -12)
                join.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
                join.Text = "Join"
                join.TextColor3 = Color3.fromRGB(255, 255, 255)
                join.Font = Enum.Font.GothamBold
                join.TextSize = 10
                join.Parent = card

                local jCorner = Instance.new("UICorner")
                jCorner.CornerRadius = UDim.new(0, 4)
                jCorner.Parent = join

                join.MouseButton1Click:Connect(function()
                    join.Text = "..."
                    TeleportService:TeleportToPlaceInstance(PlaceId, srv.id, LocalPlayer)
                end)
            end
        end
        IsFetching = false
    end)
end

local function SmartHop(mode)
    if IsFetching then return end
    IsFetching = true
    task.spawn(function()
        local cursor = nil
        local target = nil
        for _ = 1, 3 do
            local servers, nextCursor = FetchServers(cursor)
            cursor = nextCursor
            if servers then
                if mode == "Full" then
                    table.sort(servers, function(a, b) return a.playing > b.playing end)
                else
                    table.sort(servers, function(a, b) return a.playing < b.playing end)
                end
                for _, srv in ipairs(servers) do
                    if srv.id ~= JobId and srv.playing < srv.maxPlayers then
                        target = srv
                        break
                    end
                end
            end
            if target or not cursor then break end
        end
        if target then
            TeleportService:TeleportToPlaceInstance(PlaceId, target.id, LocalPlayer)
        else
            IsFetching = false
        end
    end)
end

-- ==============================================================================
-- EVENT CONNECTIONS
-- ==============================================================================
OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    if MainFrame.Visible then LoadServers() end
end)

HopFullBtn.MouseButton1Click:Connect(function() SmartHop("Full") end)
HopSmallBtn.MouseButton1Click:Connect(function() SmartHop("Smallest") end)
RejoinBtn.MouseButton1Click:Connect(function() TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer) end)

-- Auto Rejoin
CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if AutoRejoin and child.Name == "ErrorPrompt" then
        task.wait(1)
        TeleportService:Teleport(PlaceId, LocalPlayer)
    end
end)

-- Auto Hop Low FPS
task.spawn(function()
    local last = os.clock()
    local frames = 0
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - last >= 1 then
            local fps = frames / (now - last)
            frames = 0
            last = now
            if AutoHopFPS and fps < 15 and not IsFetching then
                SmartHop("Smallest")
            end
        end
    end)
end)
 
