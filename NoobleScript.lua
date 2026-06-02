-- [[ NOOBLESCRIPT: PREMIUM MONOLITHIC HUB V3.9.7 - MOBILE FLOATING BUTTON ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Конфигурация Supabase
local SUPABASE_URL = "https://jaemknvvetiqqbcxeenr.supabase.co"
local ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphZW1rbnZ2ZXRpcXFiY3hlZW5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxMzM0NzksImV4cCI6MjA5NTcwOTQ3OX0.w6G7Qe2X4IcadD-4YvMhNyKS52tnhulZs1Rk04vQ_-Q"
local KEY_FILE = "nooble_key.txt"

local myHWID = (gethwid and gethwid()) or "STUDIO_TEST_HWID_12345"
local selectedPackets = 50
local manualPodiumText = "" 
local isDupeActive = false

-- Переменные очереди для поочерёдного дюпа
local currentPodiumTargets = {}
local currentQueueIndex = 1

-- Глобальные ссылки UI
local CurrentMainGui = nil
local BackgroundBlur = nil
local consoleLogFunction = nil

local MainFrameInstance = nil
local PodiumFrameInstance = nil

-- Системные уведомления
local function sendSystemNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 4,
            Icon = "rbxassetid://6023426926"
        })
    end)
end

-- Функция перетаскивания (работает на ПК и на мобилках через тач)
local function makeElementDraggable(uiElement)
    local dragging, dragInput, dragStart, startPos
    
    uiElement.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = uiElement.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    uiElement.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            uiElement.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function makePremiumButton(btn, idleColor, hoverColor)
    btn.BackgroundColor3 = idleColor
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = hoverColor}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = idleColor}):Play()
    end)
end

-- Оптимизация промптов
local function SetupPromptOverride(prompt)
    if prompt:IsA("ProximityPrompt") then
        prompt.HoldDuration = 0.5
    end
end
for _, desc in pairs(workspace:GetDescendants()) do SetupPromptOverride(desc) end
workspace.DescendantAdded:Connect(SetupPromptOverride)

-- Базовый метод Supabase
local function supabaseRequest(method, urlSuffix, body)
    local headers = {
        ["apikey"] = ANON_KEY,
        ["Authorization"] = "Bearer " .. ANON_KEY,
        ["Content-Type"] = "application/json",
        ["Prefer"] = "return=representation"
    }
    local requestConfig = { Url = SUPABASE_URL .. urlSuffix, Method = method, Headers = headers }
    if body then requestConfig.Body = HttpService:JSONEncode(body) end
    
    local success, response = pcall(function()
        if typeof(request) == "function" or typeof(http_request) == "function" then
            return (request or http_request)(requestConfig)
        else
            return HttpService:RequestAsync(requestConfig)
        end
    end)
    if success and response and response.Body then
        local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if decodeSuccess then return decoded end
    end
    return nil
end

local DrawLoaderInterface

-------------------------------------------------------------------------------
-- 💻 ОСНОВНОЙ ИНТЕРФЕЙС ХАБА (ЗОЛОТОЙ ПРЕМИУМ СТИЛЬ)
-------------------------------------------------------------------------------
local function LaunchMainScript(keyRecord)
    local subTier = keyRecord.tier or "Premium"
    local expirationDate = keyRecord.expires_at and keyRecord.expires_at:sub(1, 10) or "Never"

    local userAvatarIcon = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    pcall(function()
        userAvatarIcon = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)

    CurrentMainGui = Instance.new("ScreenGui")
    CurrentMainGui.Name = "NooblePremiumHub"
    CurrentMainGui.ResetOnSpawn = false
    CurrentMainGui.Parent = PlayerGui

    -- Главный Фрейм
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 480, 0, 300)
    MainFrame.Position = UDim2.new(0.5, -240, 0.5, -150)
    MainFrame.BackgroundColor3 = Color3.fromRGB(9, 13, 23)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true -- По умолчанию открыт при инжекте
    MainFrame.Parent = CurrentMainGui
    MainFrameInstance = MainFrame
    
    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = UDim.new(0, 12)
    
    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Color3.fromRGB(212, 143, 56) -- Премиум золото
    MainStroke.Thickness = 1.2
    makeElementDraggable(MainFrame)

    -- Сайдбар
    local Sidebar = Instance.new("Frame", MainFrame)
    Sidebar.Size = UDim2.new(0, 135, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(6, 9, 16)
    Sidebar.BorderSizePixel = 0
    
    local SideCorner = Instance.new("UICorner", Sidebar)
    SideCorner.CornerRadius = UDim.new(0, 12)

    local SidebarCover = Instance.new("Frame", Sidebar)
    SidebarCover.Size = UDim2.new(0, 20, 1, 0)
    SidebarCover.Position = UDim2.new(1, -20, 0, 0)
    SidebarCover.BackgroundColor3 = Color3.fromRGB(6, 9, 16)
    SidebarCover.BorderSizePixel = 0

    local Title = Instance.new("TextLabel", Sidebar)
    Title.Size = UDim2.new(1, 0, 0, 45)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextColor3 = Color3.fromRGB(212, 143, 56)
    Title.TextSize = 13
    Title.Text = "NOOBLE HUB"

    local ContentFrame = Instance.new("Frame", MainFrame)
    ContentFrame.Size = UDim2.new(1, -135, 1, 0)
    ContentFrame.Position = UDim2.new(0, 135, 0, 0)
    ContentFrame.BackgroundTransparency = 1

    -- Вкладки
    local tabs = { Main = Instance.new("Frame"), Settings = Instance.new("Frame"), Info = Instance.new("Frame"), Profile = Instance.new("Frame") }
    for name, f in pairs(tabs) do
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundTransparency = 1
        f.Visible = false
        f.Parent = ContentFrame
        
        local padding = Instance.new("UIPadding", f)
        padding.PaddingTop = UDim.new(0, 15)
        padding.PaddingBottom = UDim.new(0, 15)
        padding.PaddingLeft = UDim.new(0, 20)
        padding.PaddingRight = UDim.new(0, 20)
    end

    local tabButtons = {}
    local ProfileBtn = nil

    local function switchTab(tabName)
        for name, f in pairs(tabs) do f.Visible = (name == tabName) end
        
        for name, btn in pairs(tabButtons) do
            if name == tabName then
                btn.BackgroundColor3 = Color3.fromRGB(43, 31, 18)
                btn.TextColor3 = Color3.fromRGB(212, 143, 56)
                local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
                stroke.Color = Color3.fromRGB(212, 143, 56)
            else
                btn.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
                btn.TextColor3 = Color3.fromRGB(120, 120, 130)
                local stroke = btn:FindFirstChildOfClass("UIStroke")
                if stroke then stroke:Destroy() end
            end
        end

        if ProfileBtn then
            if tabName == "Profile" then
                ProfileBtn.BackgroundColor3 = Color3.fromRGB(43, 31, 18)
                ProfileBtn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(212, 143, 56)
            else
                ProfileBtn.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
                ProfileBtn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(20, 28, 45)
            end
        end
    end

    local function createTabBtn(name, text, posy)
        local b = Instance.new("TextButton", Sidebar)
        b.Size = UDim2.new(0, 115, 0, 34)
        b.Position = UDim2.new(0, 10, 0, posy)
        b.Text = "   " .. text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextXAlignment = Enum.TextXAlignment.Left
        
        local btnCorner = Instance.new("UICorner", b)
        btnCorner.CornerRadius = UDim.new(0, 8)
        
        tabButtons[name] = b
        b.MouseButton1Click:Connect(function() switchTab(name) end)
    end
    
    createTabBtn("Main", "👤 Главная", 60)
    createTabBtn("Settings", "⚙️ Настройки", 100)
    createTabBtn("Info", "💾 Инфо", 140)

    -- Профиль в сайдбаре
    ProfileBtn = Instance.new("TextButton", Sidebar)
    ProfileBtn.Size = UDim2.new(0, 115, 0, 44)
    ProfileBtn.Position = UDim2.new(0, 10, 1, -54)
    ProfileBtn.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
    ProfileBtn.Text = ""
    
    local profCorner = Instance.new("UICorner", ProfileBtn)
    profCorner.CornerRadius = UDim.new(0, 8)
    
    local pBtnStroke = Instance.new("UIStroke", ProfileBtn)
    pBtnStroke.Color = Color3.fromRGB(20, 28, 45)

    local AvatarContainer = Instance.new("Frame", ProfileBtn)
    AvatarContainer.Size = UDim2.new(0, 28, 0, 28)
    AvatarContainer.Position = UDim2.new(0, 8, 0.5, -14)
    AvatarContainer.BackgroundColor3 = Color3.fromRGB(15, 22, 38)
    
    local avCorner = Instance.new("UICorner", AvatarContainer)
    avCorner.CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", AvatarContainer).Color = Color3.fromRGB(212, 143, 56)

    local AvatarImg = Instance.new("ImageLabel", AvatarContainer)
    AvatarImg.Size = UDim2.new(1, 0, 1, 0)
    AvatarImg.BackgroundTransparency = 1
    AvatarImg.Image = userAvatarIcon
    
    local imgCorner = Instance.new("UICorner", AvatarImg)
    imgCorner.CornerRadius = UDim.new(1, 0)

    local PName = Instance.new("TextLabel", ProfileBtn)
    PName.Size = UDim2.new(1, -44, 0, 16)
    PName.Position = UDim2.new(0, 42, 0, 6)
    PName.BackgroundTransparency = 1
    PName.Font = Enum.Font.GothamBold
    PName.TextSize = 11
    PName.TextColor3 = Color3.fromRGB(240, 240, 245)
    PName.Text = LocalPlayer.Name
    PName.TextXAlignment = Enum.TextXAlignment.Left

    local PTier = Instance.new("TextLabel", ProfileBtn)
    PTier.Size = UDim2.new(1, -44, 0, 14)
    PTier.Position = UDim2.new(0, 42, 0, 22)
    PTier.BackgroundTransparency = 1
    PTier.Font = Enum.Font.GothamBlack
    PTier.TextSize = 8
    PTier.TextColor3 = Color3.fromRGB(254, 190, 16)
    PTier.Text = subTier:upper()
    PTier.TextXAlignment = Enum.TextXAlignment.Left

    ProfileBtn.MouseButton1Click:Connect(function() switchTab("Profile") end)

    -- Вкладка Main (логи изменений)
    local MainTitleLabel = Instance.new("TextLabel", tabs.Main)
    MainTitleLabel.Size = UDim2.new(1, 0, 0, 25)
    MainTitleLabel.BackgroundTransparency = 1
    MainTitleLabel.Font = Enum.Font.GothamBold
    MainTitleLabel.TextSize = 16
    MainTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MainTitleLabel.Text = "Добро пожаловать!"
    MainTitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local MainDescLabel = Instance.new("TextLabel", tabs.Main)
    MainDescLabel.Size = UDim2.new(1, 0, 0, 35)
    MainDescLabel.Position = UDim2.new(0, 0, 0, 28)
    MainDescLabel.BackgroundTransparency = 1
    MainDescLabel.Font = Enum.Font.Gotham
    MainDescLabel.TextSize = 11
    MainDescLabel.TextColor3 = Color3.fromRGB(130, 140, 160)
    MainDescLabel.Text = "Nooble Premium Hub V3.9.7 | MOBILE EDITION"
    MainDescLabel.TextWrapped = true
    MainDescLabel.TextXAlignment = Enum.TextXAlignment.Left

    local LogFrame = Instance.new("Frame", tabs.Main)
    LogFrame.Size = UDim2.new(1, 0, 1, -75)
    LogFrame.Position = UDim2.new(0, 0, 0, 75)
    LogFrame.BackgroundColor3 = Color3.fromRGB(12, 17, 30)
    
    local logCorner = Instance.new("UICorner", LogFrame)
    logCorner.CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", LogFrame).Color = Color3.fromRGB(45, 35, 25)

    local LogScroll = Instance.new("ScrollingFrame", LogFrame)
    LogScroll.Size = UDim2.new(1, 0, 1, 0)
    LogScroll.BackgroundTransparency = 1
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 300)
    LogScroll.ScrollBarThickness = 3
    LogScroll.ScrollBarImageColor3 = Color3.fromRGB(212, 143, 56)
    
    local LogPadding = Instance.new("UIPadding", LogScroll)
    LogPadding.PaddingLeft = UDim.new(0, 12)
    LogPadding.PaddingTop = UDim.new(0, 10)
    
    local LogList = Instance.new("UIListLayout", LogScroll)
    LogList.Padding = UDim.new(0, 5)

    local function addLogLine(text, isHeader)
        local line = Instance.new("TextLabel", LogScroll)
        line.Size = UDim2.new(1, 0, 0, 16)
        line.BackgroundTransparency = 1
        line.Font = isHeader and Enum.Font.GothamBold or Enum.Font.Gotham
        line.TextColor3 = isHeader and Color3.fromRGB(212, 143, 56) or Color3.fromRGB(180, 180, 180)
        line.TextSize = isHeader and 12 or 11
        line.Text = text
        line.TextXAlignment = Enum.TextXAlignment.Left
    end

    task.spawn(function()
        addLogLine("Получение списка изменений с сервера...", false)
        local logsData = supabaseRequest("GET", "/rest/v1/updates?order=id.desc&limit=1")
        for _, child in pairs(LogScroll:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
        if logsData and #logsData > 0 then
            addLogLine("СПИСОК ИЗМЕНЕНИЙ ХАБА:", true)
            addLogLine(logsData[1].changes or "• Стабильная мобильная версия софта.", false)
        else
            addLogLine("Лог изменений временно не найден.", true)
        end
    end)

    -- Вкладка Profile
    local LargeAvatarFrame = Instance.new("Frame", tabs.Profile)
    LargeAvatarFrame.Size = UDim2.new(0, 68, 0, 68)
    LargeAvatarFrame.Position = UDim2.new(0, 5, 0, 5)
    LargeAvatarFrame.BackgroundColor3 = Color3.fromRGB(15, 22, 38)
    
    local laCorner = Instance.new("UICorner", LargeAvatarFrame)
    laCorner.CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", LargeAvatarFrame).Color = Color3.fromRGB(212, 143, 56)

    local LargeAvatarImg = Instance.new("ImageLabel", LargeAvatarFrame)
    LargeAvatarImg.Size = UDim2.new(1, 0, 1, 0)
    LargeAvatarImg.BackgroundTransparency = 1
    LargeAvatarImg.Image = userAvatarIcon
    Instance.new("UICorner", LargeAvatarImg).CornerRadius = UDim.new(1, 0)

    local InfoLayoutFrame = Instance.new("Frame", tabs.Profile)
    InfoLayoutFrame.Size = UDim2.new(1, -95, 1, 0)
    InfoLayoutFrame.Position = UDim2.new(0, 95, 0, 5)
    InfoLayoutFrame.BackgroundTransparency = 1
    Instance.new("UIListLayout", InfoLayoutFrame).Padding = UDim.new(0, 12)

    local function createProfilePageLine(title, val, customValueColor)
        local frame = Instance.new("Frame", InfoLayoutFrame)
        frame.Size = UDim2.new(1, 0, 0, 18)
        frame.BackgroundTransparency = 1
        
        local t = Instance.new("TextLabel", frame)
        t.Size = UDim2.new(0, 130, 1, 0)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.Gotham
        t.TextColor3 = Color3.fromRGB(140, 145, 155)
        t.TextSize = 13
        t.Text = title
        t.TextXAlignment = Enum.TextXAlignment.Left
        
        local v = Instance.new("TextLabel", frame)
        v.Size = UDim2.new(1, -135, 1, 0)
        v.Position = UDim2.new(0, 135, 0, 0)
        v.BackgroundTransparency = 1
        v.Font = Enum.Font.GothamBold
        v.TextColor3 = customValueColor or Color3.fromRGB(255, 255, 255)
        v.TextSize = 13
        v.Text = val
        v.TextXAlignment = Enum.TextXAlignment.Left
    end

    createProfilePageLine("Имя аккаунта:", LocalPlayer.Name)
    createProfilePageLine("Идентификатор:", tostring(LocalPlayer.UserId))
    createProfilePageLine("Тип лицензии:", '"' .. subTier .. '"', Color3.fromRGB(254, 190, 16))
    createProfilePageLine("Активность:", "Действителен", Color3.fromRGB(0, 200, 100))
    createProfilePageLine("Окончание:", expirationDate)

    -- Вкладка Settings (настройки)
    local DropdownBtn = Instance.new("TextButton", tabs.Settings)
    DropdownBtn.Size = UDim2.new(1, 0, 0, 42)
    DropdownBtn.BackgroundColor3 = Color3.fromRGB(14, 20, 35)
    DropdownBtn.Font = Enum.Font.Gotham
    DropdownBtn.TextColor3 = Color3.fromRGB(170, 180, 195)
    DropdownBtn.TextSize = 13
    DropdownBtn.Text = "  Лимит пакетов за раз: 50"
    DropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
    DropdownBtn.ZIndex = 3
    Instance.new("UICorner", DropdownBtn).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", DropdownBtn).Color = Color3.fromRGB(54, 42, 28)

    local DropdownScroll = Instance.new("ScrollingFrame", tabs.Settings)
    DropdownScroll.Size = UDim2.new(1, 0, 0, 125)
    DropdownScroll.Position = UDim2.new(0, 0, 0, 46)
    DropdownScroll.BackgroundColor3 = Color3.fromRGB(11, 15, 28)
    DropdownScroll.Visible = false
    DropdownScroll.ZIndex = 10
    DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 260)
    Instance.new("UICorner", DropdownScroll).CornerRadius = UDim.new(0, 8)
    Instance.new("UIListLayout", DropdownScroll).Padding = UDim.new(0, 0)
    
    for _, size in ipairs({50, 150, 350, 500, 750, 1200, 1500, 2000}) do
        local Item = Instance.new("TextButton", DropdownScroll)
        Item.Size = UDim2.new(1, 0, 0, 32)
        Item.BackgroundColor3 = Color3.fromRGB(14, 20, 35)
        Item.BorderSizePixel = 0
        Item.Font = Enum.Font.Gotham
        Item.TextColor3 = Color3.fromRGB(200, 210, 225)
        Item.Text = "   " .. size .. " PKTS"
        Item.TextXAlignment = Enum.TextXAlignment.Left
        Item.ZIndex = 11
        Item.MouseButton1Click:Connect(function()
            selectedPackets = size
            DropdownBtn.Text = "  Лимит пакетов за раз: " .. size
            DropdownScroll.Visible = false
            if consoleLogFunction then consoleLogFunction("Лимит пакетов изменён на: " .. size) end
        end)
    end
    DropdownBtn.MouseButton1Click:Connect(function() DropdownScroll.Visible = not DropdownScroll.Visible end)

    local MainPodiumInput = Instance.new("TextBox", tabs.Settings)
    MainPodiumInput.Size = UDim2.new(1, 0, 0, 42)
    MainPodiumInput.Position = UDim2.new(0, 0, 0, 54)
    MainPodiumInput.BackgroundColor3 = Color3.fromRGB(14, 20, 35)
    MainPodiumInput.PlaceholderText = "Номер подиума (Пусто = автопоиск)..."
    MainPodiumInput.PlaceholderColor3 = Color3.fromRGB(80, 95, 120)
    MainPodiumInput.Text = ""
    MainPodiumInput.Font = Enum.Font.Gotham
    MainPodiumInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    MainPodiumInput.TextSize = 13
    MainPodiumInput.TextXAlignment = Enum.TextXAlignment.Left
    MainPodiumInput.ZIndex = 2
    Instance.new("UICorner", MainPodiumInput).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", MainPodiumInput).Color = Color3.fromRGB(54, 42, 28)
    Instance.new("UIPadding", MainPodiumInput).PaddingLeft = UDim.new(0, 12)

    -- Кнопка СТАРТ / СТОП
    local ButtonFrame = Instance.new("Frame", tabs.Settings)
    ButtonFrame.Size = UDim2.new(1, 0, 0, 44)
    ButtonFrame.Position = UDim2.new(0, 0, 1, -44)
    ButtonFrame.BackgroundTransparency = 1

    local ActionBtn = Instance.new("TextButton", ButtonFrame)
    ActionBtn.Size = UDim2.new(1, 0, 1, 0)
    ActionBtn.Text = "СТАРТ"
    ActionBtn.Font = Enum.Font.GothamBold
    ActionBtn.TextSize = 13
    ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", ActionBtn).CornerRadius = UDim.new(0, 10)
    makePremiumButton(ActionBtn, Color3.fromRGB(213, 105, 30), Color3.fromRGB(243, 135, 60))

    -- Вкладка Info (консоль)
    local ConsoleFrame = Instance.new("ScrollingFrame", tabs.Info)
    ConsoleFrame.Size = UDim2.new(1, 0, 1, 0)
    ConsoleFrame.BackgroundColor3 = Color3.fromRGB(7, 10, 18)
    ConsoleFrame.CanvasSize = UDim2.new(0, 0, 0, 1000)
    Instance.new("UICorner", ConsoleFrame).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", ConsoleFrame).Color = Color3.fromRGB(45, 35, 25)
    Instance.new("UIPadding", ConsoleFrame).PaddingLeft = UDim.new(0, 10)
    local ConsoleList = Instance.new("UIListLayout", ConsoleFrame)

    consoleLogFunction = function(msg)
        local logItem = Instance.new("TextLabel", ConsoleFrame)
        logItem.Size = UDim2.new(1, -15, 0, 18)
        logItem.BackgroundTransparency = 1
        logItem.Font = Enum.Font.Code
        logItem.TextColor3 = Color3.fromRGB(212, 143, 56)
        logItem.TextSize = 11
        logItem.Text = " [SYSTEM]: " .. msg
        logItem.TextXAlignment = Enum.TextXAlignment.Left
        
        task.wait(0.05)
        ConsoleFrame.CanvasPosition = Vector2.new(0, ConsoleFrame.CanvasSize.Y.Offset)
    end

    switchTab("Main")

    -- МИНИ-ФРЕЙМ "NUMBER PODIUM"
    local PodiumMiniFrame = Instance.new("Frame")
    PodiumMiniFrame.Size = UDim2.new(0, 180, 0, 75)
    PodiumMiniFrame.Position = UDim2.new(0.5, 260, 0.5, -37)
    PodiumMiniFrame.BackgroundColor3 = Color3.fromRGB(9, 13, 23)
    PodiumMiniFrame.BorderSizePixel = 0
    PodiumMiniFrame.Visible = false
    PodiumMiniFrame.Parent = CurrentMainGui
    PodiumFrameInstance = PodiumMiniFrame
    Instance.new("UICorner", PodiumMiniFrame).CornerRadius = UDim.new(0, 10)
    
    local MiniStroke = Instance.new("UIStroke", PodiumMiniFrame)
    MiniStroke.Color = Color3.fromRGB(212, 143, 56)
    MiniStroke.Thickness = 1.2
    makeElementDraggable(PodiumMiniFrame)

    local MiniTitle = Instance.new("TextLabel", PodiumMiniFrame)
    MiniTitle.Size = UDim2.new(1, 0, 0, 25)
    MiniTitle.BackgroundTransparency = 1
    MiniTitle.Font = Enum.Font.GothamBold
    MiniTitle.TextSize = 11
    MiniTitle.TextColor3 = Color3.fromRGB(212, 143, 56)
    MiniTitle.Text = "NUMBER PODIUM"

    local MiniInput = Instance.new("TextBox", PodiumMiniFrame)
    MiniInput.Size = UDim2.new(1, -20, 0, 32)
    MiniInput.Position = UDim2.new(0, 10, 0, 30)
    MiniInput.BackgroundColor3 = Color3.fromRGB(14, 20, 35)
    MiniInput.PlaceholderText = "Номер стенда..."
    MiniInput.PlaceholderColor3 = Color3.fromRGB(80, 95, 120)
    MiniInput.Text = ""
    MiniInput.Font = Enum.Font.GothamBold
    MiniInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    MiniInput.TextSize = 13
    Instance.new("UICorner", MiniInput).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", MiniInput).Color = Color3.fromRGB(54, 42, 28)

    local function UpdateGlobalTargetText(newText)
        manualPodiumText = newText:gsub(" ", "")
        if MainPodiumInput.Text ~= manualPodiumText then MainPodiumInput.Text = manualPodiumText end
        if MiniInput.Text ~= manualPodiumText then MiniInput.Text = manualPodiumText end
        if consoleLogFunction then consoleLogFunction("Установлена цель: " .. (manualPodiumText ~= "" and manualPodiumText or "автопоиск")) end
    end
    MainPodiumInput:GetPropertyChangedSignal("Text"):Connect(function() UpdateGlobalTargetText(MainPodiumInput.Text) end)
    MiniInput:GetPropertyChangedSignal("Text"):Connect(function() UpdateGlobalTargetText(MiniInput.Text) end)

    ---------------------------------------------------------------------------
    -- 📱 СОЗДАНИЕ ПЛАВАЮЩЕЙ МОБИЛЬНОЙ КНОПКИ (FLOATING ACTION BUTTON)
    ---------------------------------------------------------------------------
    local FloatingMobileButton = Instance.new("TextButton")
    FloatingMobileButton.Name = "NoobleFloatingButton"
    FloatingMobileButton.Size = UDim2.new(0, 46, 0, 46)
    -- Безопасная дефолтная позиция слева, чтобы не накладываться на управление
    FloatingMobileButton.Position = UDim2.new(0, 25, 0.4, 0) 
    FloatingMobileButton.BackgroundColor3 = Color3.fromRGB(11, 16, 28)
    FloatingMobileButton.Text = "⚙️"
    FloatingMobileButton.TextSize = 18
    FloatingMobileButton.TextColor3 = Color3.fromRGB(212, 143, 56)
    FloatingMobileButton.ZIndex = 10000
    FloatingMobileButton.Parent = CurrentMainGui

    local fbCorner = Instance.new("UICorner", FloatingMobileButton)
    fbCorner.CornerRadius = UDim.new(1, 0) -- Идеальный круг

    local fbStroke = Instance.new("UIStroke", FloatingMobileButton)
    fbStroke.Color = Color3.fromRGB(212, 143, 56) -- Золотой контур кнопки
    fbStroke.Thickness = 1.5

    -- Делаем кнопку перетаскиваемой по всему экрану тачем
    makeElementDraggable(FloatingMobileButton)

    -- Переключение видимости основного меню при клике на плавающую кнопку
    FloatingMobileButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    -- Хоткеи клавиатуры для ПК-тестов
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.M then
            MainFrame.Visible = not MainFrame.Visible
        elseif input.KeyCode == Enum.KeyCode.J then
            PodiumMiniFrame.Visible = not PodiumMiniFrame.Visible
            if PodiumMiniFrame.Visible then MiniInput:CaptureFocus() end
        end
    end)

    ---------------------------------------------------------------------------
    -- 🔁 ЛОГИКА ОЧЕРЕДИ ДЮПА
    ---------------------------------------------------------------------------
    local function SendPackets(podiumTarget)
        pcall(function()
            local Net = require(ReplicatedStorage.Packages.Net)
            local GrabRemote = Net:RemoteEvent("StealService/Grab")
            for i = 1, selectedPackets do
                task.spawn(function() 
                    pcall(function() 
                        GrabRemote:FireServer("Place", podiumTarget)
                    end)
                end)
            end
        end)
    end

    local function UpdatePodiumQueue()
        if manualPodiumText ~= "" then
            local targets = {}
            for part in string.gmatch(manualPodiumText, "[^,]+") do
                table.insert(targets, tonumber(part) or part)
            end
            currentPodiumTargets = targets
            currentQueueIndex = 1
            if consoleLogFunction then consoleLogFunction("🔍 Очередь обновлена (ручной ввод): " .. HttpService:JSONEncode(targets)) end
            return true
        end
        
        local targets = {}
        local foundPlotModel = nil
        local l_Packages = ReplicatedStorage:WaitForChild("Packages", 5)
        local synchronizer = l_Packages and l_Packages:FindFirstChild("Synchronizer") and require(l_Packages.Synchronizer)
        
        if synchronizer then
            for _, obj in pairs(workspace:GetChildren()) do
                local channel = synchronizer:Get(obj.Name)
                if channel and channel.Get then
                    if channel:Get("Owner") == LocalPlayer then
                        foundPlotModel = obj
                        break
                    end
                end
            end
        end
        
        if not foundPlotModel then
            for _, obj in pairs(workspace:GetChildren()) do
                if obj:FindFirstChild("AnimalPodiums") and obj:GetAttribute("Tier") ~= nil then
                    foundPlotModel = obj
                    break
                end
            end
        end

        if foundPlotModel then
            local podiumsFolder = foundPlotModel:FindFirstChild("AnimalPodiums")
            if podiumsFolder then
                for _, podium in pairs(podiumsFolder:GetChildren()) do
                    table.insert(targets, tonumber(podium.Name) or podium.Name)
                end
            end
        end
        
        if #targets > 0 then
            table.sort(targets, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
            currentPodiumTargets = targets
            currentQueueIndex = 1
            if consoleLogFunction then consoleLogFunction("🟢 ОЧЕРЕДЬ ЗАПОЛНЕНА. Найдено подиумов: " .. #targets) end
            return true
        else
            currentPodiumTargets = {}
            if consoleLogFunction then consoleLogFunction("❌ Нет доступных подиумов.") end
            return false
        end
    end

    local dupeListener = ProximityPromptService.PromptTriggered:Connect(function(activatedPrompt, player)
        if player ~= LocalPlayer then return end
        if not isDupeActive then return end
        if #currentPodiumTargets == 0 then return end
        
        local target = currentPodiumTargets[currentQueueIndex]
        if target then
            if consoleLogFunction then 
                consoleLogFunction("🚀 Спам в подиум: " .. tostring(target) .. " (" .. currentQueueIndex .. "/" .. #currentPodiumTargets .. ")") 
            end
            SendPackets(target)
            
            currentQueueIndex = currentQueueIndex + 1
            if currentQueueIndex > #currentPodiumTargets then
                currentQueueIndex = 1
            end
        end
    end)

    local function ToggleDupeMode()
        if not isDupeActive then
            local ready = UpdatePodiumQueue()
            if not ready then return end
            isDupeActive = true
            ActionBtn.Text = "СТОП"
            makePremiumButton(ActionBtn, Color3.fromRGB(200, 50, 50), Color3.fromRGB(230, 80, 80))
            sendSystemNotification("Queue Dupe", "Включено! Кликай промпты.", 3)
        else
            isDupeActive = false
            ActionBtn.Text = "СТАРТ"
            makePremiumButton(ActionBtn, Color3.fromRGB(213, 105, 30), Color3.fromRGB(243, 135, 60))
            currentPodiumTargets = {}
            sendSystemNotification("Queue Dupe", "Остановлено.", 3)
        end
    end

    ActionBtn.MouseButton1Click:Connect(ToggleDupeMode)
end

-------------------------------------------------------------------------------
-- СИСТЕМА ЛОАДЕРА (ЗОЛОТОЙ ДИЗАЙН)
-------------------------------------------------------------------------------
DrawLoaderInterface = function()
    if not BackgroundBlur then
        BackgroundBlur = Instance.new("BlurEffect", Lighting)
        BackgroundBlur.Size = 15
    end

    local LoaderGui = Instance.new("ScreenGui")
    LoaderGui.Name = "NoobleLoader"
    LoaderGui.ResetOnSpawn = false
    LoaderGui.Parent = PlayerGui

    local LF = Instance.new("Frame")
    LF.Size = UDim2.new(0, 340, 0, 220)
    LF.Position = UDim2.new(0.5, -170, 0.5, -110)
    LF.BackgroundColor3 = Color3.fromRGB(9, 13, 23)
    LF.Parent = LoaderGui
    Instance.new("UICorner", LF).CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", LF)
    stroke.Color = Color3.fromRGB(212, 143, 56)
    stroke.Thickness = 1.2
    makeElementDraggable(LF)

    local LTitle = Instance.new("TextLabel", LF)
    LTitle.Size = UDim2.new(1, 0, 0, 45)
    LTitle.Position = UDim2.new(0, 0, 0, 10)
    LTitle.BackgroundTransparency = 1
    LTitle.Text = "NOOBLE SCRIPT | LICENSE"
    LTitle.Font = Enum.Font.GothamBold
    LTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    LTitle.TextSize = 13

    local KInput = Instance.new("TextBox", LF)
    KInput.Size = UDim2.new(1, -40, 0, 42)
    KInput.Position = UDim2.new(0, 20, 0, 65)
    KInput.BackgroundColor3 = Color3.fromRGB(14, 20, 35)
    KInput.PlaceholderText = "Введите лицензионный ключ..."
    KInput.PlaceholderColor3 = Color3.fromRGB(80, 95, 120)
    KInput.Font = Enum.Font.Gotham
    KInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KInput.TextSize = 13
    Instance.new("UICorner", KInput).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", KInput).Color = Color3.fromRGB(54, 42, 28)
    Instance.new("UIPadding", KInput).PaddingLeft = UDim.new(0, 12)

    local LoginBtn = Instance.new("TextButton", LF)
    LoginBtn.Size = UDim2.new(1, -40, 0, 44)
    LoginBtn.Position = UDim2.new(0, 20, 1, -65)
    LoginBtn.Text = "ПРОВЕРИТЬ ЛИЦЕНЗИЮ"
    LoginBtn.Font = Enum.Font.GothamBold
    LoginBtn.TextSize = 12
    LoginBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", LoginBtn).CornerRadius = UDim.new(0, 10)
    makePremiumButton(LoginBtn, Color3.fromRGB(213, 105, 30), Color3.fromRGB(243, 135, 60))

    local function verify(enteredKey)
        LoginBtn.Text = "СВЯЗЬ С БАЗОЙ..."
        local res = supabaseRequest("GET", "/rest/v1/keys?key=eq." .. enteredKey)
        if res and #res > 0 then
            local record = res[1]
            if record.status ~= "active" then LoginBtn.Text = "ОШИБКА" return end
            
            local y, m, d, h, mn, s = record.expires_at:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if os.time() > os.time({year=y, month=m, day=d, hour=h, min=mn, sec=s}) then LoginBtn.Text = "ОШИБКА" return end
            
            if record.hwid ~= nil and record.hwid ~= "" and record.hwid ~= myHWID then
                LoginBtn.Text = "ОШИБКА"
                return
            elseif record.hwid == nil or record.hwid == "" then
                supabaseRequest("PATCH", "/rest/v1/keys?key=eq." .. enteredKey, { hwid = myHWID })
            end
            
            if writefile then pcall(function() writefile(KEY_FILE, enteredKey) end) end
            if BackgroundBlur then BackgroundBlur:Destroy() BackgroundBlur = nil end
            LoaderGui:Destroy()
            LaunchMainScript(record)
        else
            LoginBtn.Text = "НЕВЕРНЫЙ КЛЮЧ"
            task.wait(1.5)
            LoginBtn.Text = "ПРОВЕРИТЬ ЛИЦЕНЗИЮ"
        end
    end

    LoginBtn.MouseButton1Click:Connect(function()
        local k = KInput.Text:gsub(" ", "")
        if k ~= "" then verify(k) end
    end)
end

-- Авто-вход
local fileExists, savedKey = pcall(function() return readfile and readfile(KEY_FILE) end)
if fileExists and savedKey and savedKey:gsub(" ", "") ~= "" then
    task.spawn(function()
        local cleanKey = savedKey:gsub(" ", "")
        local check = supabaseRequest("GET", "/rest/v1/keys?key=eq." .. cleanKey)
        if check and #check > 0 and check[1].status == "active" then
            local y, m, d, h, mn, s = check[1].expires_at:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if os.time() < os.time({year=y, month=m, day=d, hour=h, min=mn, sec=s}) and (check[1].hwid == nil or check[1].hwid == myHWID) then
                LaunchMainScript(check[1])
                return
            end
        end
        DrawLoaderInterface()
    end)
else
    DrawLoaderInterface()
end
