-- ╔══════════════════════════════════════════════════════════════════╗
-- ║         BGS INFINITY — LUNAR HUB  |  Self-Contained Script      ║
-- ║         Extracted from: place_85896571713843                     ║
-- ║         Game: Bubble Gum Simulator INFINITY (Lunar Server)       ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ┌─────────────────────────────────────────────────────────────────┐
-- │  DISCLAIMER: Educational / Research purposes only.              │
-- │  Use at your own risk. May violate Roblox ToS.                  │
-- └─────────────────────────────────────────────────────────────────┘

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService    = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace      = game:GetService("Workspace")

local LocalPlayer    = Players.LocalPlayer
local Mouse          = LocalPlayer:GetMouse()

-- ╔══════════════════════════╗
-- ║    REMOTE REFERENCES     ║
-- ╚══════════════════════════╝

local Remote, RemoteEvent, RemoteFunction

local function initRemotes()
    local ok, remoteModule = pcall(function()
        return ReplicatedStorage:WaitForChild("Shared", 5)
            :WaitForChild("Framework", 5)
            :WaitForChild("Network", 5)
            :WaitForChild("Remote", 5)
    end)
    if ok and remoteModule then
        RemoteEvent    = remoteModule:WaitForChild("RemoteEvent", 5)
        RemoteFunction = remoteModule:WaitForChild("RemoteFunction", 5)
        Remote = {
            Fire   = function(action, ...) if RemoteEvent    then RemoteEvent:FireServer(action, ...)    end end,
            Invoke = function(action, ...) if RemoteFunction then return RemoteFunction:InvokeServer(action, ...) end end,
        }
        return true
    end
    return false
end

-- ╔══════════════════════════╗
-- ║   ALL PROMO CODES        ║
-- ╚══════════════════════════╝

local PROMO_CODES = {
    "release", "lucky", "easter", "update2", "update3",
    "sylentlyssorry", "update4", "update5", "update6", "update7",
    "update8", "update9", "update10", "update11", "update12",
    "update13", "update15", "world3", "onemorebonus", "fishe",
    "fishfix", "update16", "season6", "season7", "bugfix",
    "plasma", "milestones", "retroslop", "obby", "autumn",
    "superpuff", "cornmaze", "halloween", "maidnert", "ripsoulofplant",
    "adminabuse", "miniupdate", "shutdown", "ogbgs", "throwback",
    "christmas", "jolly", "elf", "sorryshutdown", "christmasday2025",
    "secretsanta", "circus", "tophats", "heaven", "hell",
    "valentine", "galentine"
}

-- ╔══════════════════════════╗
-- ║    CONFIG / STATE        ║
-- ╚══════════════════════════╝

local Config = {
    -- Auto Farm
    AutoBlow         = false,
    AutoSell         = false,
    AutoHatch        = false,
    AutoCollect      = false,

    -- Speed / Movement
    WalkSpeedEnabled = false,
    WalkSpeed        = 32,
    JumpPowerEnabled = false,
    JumpPower        = 80,
    InfJumpEnabled   = false,
    NoclipEnabled    = false,
    FlyEnabled       = false,

    -- Visuals / Misc
    ESPEnabled       = false,
    NoAnimEnabled    = false,
    AntiAFKEnabled   = true,

    -- Auto Code Redeem
    AutoCodeEnabled  = false,
    CodeDelay        = 1.0,

    -- Teleport targets
    SelectedWorld    = "The Overworld",
    Worlds = {
        "The Overworld",
        "Minigame Paradise",
        "Seven Seas",
        "Christmas World",
    },

    -- UI state
    Visible = true,
    CurrentTab = "Farm",
}

local State = {
    BubblesBlown  = 0,
    CoinsEarned   = 0,
    CodesRedeemed = 0,
    StartTime     = tick(),
    Connections   = {},
    FlyBodyVelocity = nil,
    FlyBodyGyro     = nil,
    LastJumpTick    = 0,
}

-- ╔══════════════════════════╗
-- ║    UTILITY FUNCTIONS     ║
-- ╚══════════════════════════╝

local function log(msg)
    print(("[BGS-HUB] " .. msg))
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then log("Error: " .. tostring(err)) end
end

local function formatNum(n)
    if n >= 1e12 then return string.format("%.2fT", n/1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

local function formatTime(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    if h > 0 then return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChild("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ╔══════════════════════════╗
-- ║    CORE FEATURE FUNCS    ║
-- ╚══════════════════════════╝

-- ── BLOW BUBBLE ──
local function blowBubble()
    if Remote then
        Remote.Fire("BlowBubble")
        Remote.Fire("SellBubble")
        State.BubblesBlown = State.BubblesBlown + 1
    end
end

-- ── HATCH EGG ──
local function hatchEgg()
    if Remote then
        Remote.Fire("HatchEgg")
    end
end

-- ── TELEPORT TO WORLD ──
local function teleportToWorld(worldName)
    if Remote then
        Remote.Fire("WorldTeleport", worldName)
        log("Teleporting to: " .. worldName)
    end
end

-- ── TELEPORT UTILITIES ──
local function teleportToPlaza()
    if Remote then Remote.Fire("PlazaTeleport") end
end

local function teleportHome()
    if Remote then Remote.Fire("home") end
end

-- ── CLAIM ALL PRIZES ──
local function claimAllPrizes()
    if not Remote then return end
    local actions = {
        "ClaimPrize", "ClaimWorldReward", "ClaimObbyChest",
        "ClaimEventPrize", "ClaimCompetitivePrize", "ClaimAllPlaytime"
    }
    for _, action in ipairs(actions) do
        safeCall(function() Remote.Fire(action) end)
        task.wait(0.2)
    end
    log("Claimed all available prizes!")
end

-- ── WALK SPEED ──
local function applyWalkSpeed()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = Config.WalkSpeedEnabled and Config.WalkSpeed or 16
    end
end

-- ── JUMP POWER ──
local function applyJumpPower()
    local hum = getHumanoid()
    if hum then
        hum.JumpPower = Config.JumpPowerEnabled and Config.JumpPower or 50
    end
end

-- ── INFINITE JUMP ──
local function setupInfJump()
    UserInputService.JumpRequest:Connect(function()
        if Config.InfJumpEnabled then
            local hum = getHumanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end

-- ── NOCLIP ──
local function setupNoclip()
    RunService.Stepped:Connect(function()
        if Config.NoclipEnabled then
            local char = getCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

-- ── FLY ──
local FLY_SPEED = 60
local function enableFly()
    local root = getRootPart()
    local char = getCharacter()
    if not root or not char then return end

    local hum = getHumanoid()
    if hum then hum.PlatformStand = true end

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.D = 50
    bg.Parent = root
    State.FlyBodyGyro = bg

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root
    State.FlyBodyVelocity = bv

    local cam = Workspace.CurrentCamera

    task.spawn(function()
        while Config.FlyEnabled and root.Parent do
            local direction = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end

            bv.Velocity = direction * FLY_SPEED
            bg.CFrame = cam.CFrame

            task.wait()
        end
        -- cleanup
        if bv and bv.Parent then bv:Destroy() end
        if bg and bg.Parent then bg:Destroy() end
        local h = getHumanoid()
        if h then h.PlatformStand = false end
        State.FlyBodyVelocity = nil
        State.FlyBodyGyro = nil
    end)
end

local function disableFly()
    if State.FlyBodyVelocity then State.FlyBodyVelocity:Destroy() end
    if State.FlyBodyGyro then State.FlyBodyGyro:Destroy() end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

-- ── ANTI AFK ──
local function setupAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    task.spawn(function()
        while true do
            task.wait(60)
            if Config.AntiAFKEnabled then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end
    end)
end

-- ── AUTO REDEEM ALL CODES ──
local function redeemCode(code)
    -- BGS uses a RemoteFunction or chat command for codes
    -- Based on decompiled source, codes are entered through the UI -> server
    -- We'll fire via the chat system as fallback
    if Remote then
        -- Try direct invoke if it exists
        safeCall(function()
            local result = Remote.Invoke("RedeemCode", code)
            if result then
                State.CodesRedeemed = State.CodesRedeemed + 1
                log("Redeemed code: " .. code)
            end
        end)
    end
    -- Also try chat command method
    safeCall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("Shared")
            :WaitForChild("Framework")
            :WaitForChild("Network")
            :WaitForChild("Remote")
            :WaitForChild("RemoteEvent")
            :FireServer("RedeemCode", code)
    end)
end

local function redeemAllCodes()
    log("Starting code redemption for " .. #PROMO_CODES .. " codes...")
    task.spawn(function()
        for _, code in ipairs(PROMO_CODES) do
            redeemCode(code)
            task.wait(Config.CodeDelay)
        end
        log("All codes attempted!")
    end)
end

-- ── ESP ──
local ESPHighlights = {}

local function clearESP()
    for _, h in pairs(ESPHighlights) do
        if h and h.Parent then h:Destroy() end
    end
    ESPHighlights = {}
end

local function updateESP()
    if not Config.ESPEnabled then
        clearESP()
        return
    end
    -- Highlight all other players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local existing = ESPHighlights[player.Name]
            if not existing or not existing.Parent then
                local h = Instance.new("SelectionBox")
                h.Color3 = Color3.fromRGB(255, 80, 80)
                h.LineThickness = 0.08
                h.SurfaceTransparency = 0.7
                h.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
                h.Adornee = player.Character
                h.Parent = Workspace
                ESPHighlights[player.Name] = h
            else
                existing.Adornee = player.Character
            end
        end
    end
end

-- ╔══════════════════════════╗
-- ║      MAIN GAME LOOP      ║
-- ╚══════════════════════════╝

local BLOW_INTERVAL  = 0.05  -- seconds between bubbles
local lastBlow       = 0
local lastCodeIndex  = 1

RunService.Heartbeat:Connect(function(dt)
    local now = tick()

    -- Auto blow + sell
    if Config.AutoBlow and (now - lastBlow) >= BLOW_INTERVAL then
        safeCall(blowBubble)
        lastBlow = now
    end

    -- Maintain walk speed
    if Config.WalkSpeedEnabled then
        local hum = getHumanoid()
        if hum and hum.WalkSpeed ~= Config.WalkSpeed then
            hum.WalkSpeed = Config.WalkSpeed
        end
    end

    -- Maintain jump power
    if Config.JumpPowerEnabled then
        local hum = getHumanoid()
        if hum and hum.JumpPower ~= Config.JumpPower then
            hum.JumpPower = Config.JumpPower
        end
    end

    -- ESP update (throttled)
    if math.floor(now) ~= math.floor(now - dt) then
        updateESP()
    end
end)

-- ╔══════════════════════════╗
-- ║    GUI CONSTRUCTION      ║
-- ╚══════════════════════════╝

-- Remove old instances of this hub
for _, old in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
    if old.Name == "BGSHUB" then old:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BGSHUB"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer.PlayerGui

-- ── THEME ──
local THEME = {
    Bg           = Color3.fromRGB(10, 10, 18),
    Panel        = Color3.fromRGB(16, 16, 28),
    Card         = Color3.fromRGB(22, 22, 38),
    CardHover    = Color3.fromRGB(30, 30, 52),
    Accent       = Color3.fromRGB(120, 80, 255),
    AccentGlow   = Color3.fromRGB(160, 110, 255),
    AccentDim    = Color3.fromRGB(60, 40, 130),
    Green        = Color3.fromRGB(60, 220, 120),
    Red          = Color3.fromRGB(240, 70, 70),
    Yellow       = Color3.fromRGB(255, 210, 60),
    Text         = Color3.fromRGB(230, 230, 255),
    TextDim      = Color3.fromRGB(130, 130, 160),
    Border       = Color3.fromRGB(40, 40, 70),
}

local FONT_TITLE = Enum.Font.GothamBold
local FONT_BODY  = Enum.Font.Gotham
local FONT_MONO  = Enum.Font.Code

-- ── HELPER: Create UI instances ──
local function make(cls, props, parent)
    local obj = Instance.new(cls)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(r, parent)
    return make("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
end

local function stroke(thickness, color, transparency, parent)
    return make("UIStroke", {
        Thickness = thickness,
        Color = color or THEME.Border,
        Transparency = transparency or 0,
    }, parent)
end

local function padding(top, right, bottom, left, parent)
    return make("UIPadding", {
        PaddingTop    = UDim.new(0, top    or 6),
        PaddingRight  = UDim.new(0, right  or 6),
        PaddingBottom = UDim.new(0, bottom or 6),
        PaddingLeft   = UDim.new(0, left   or 6),
    }, parent)
end

local function label(text, size, color, font, parent)
    return make("TextLabel", {
        Text = text,
        TextSize = size or 13,
        TextColor3 = color or THEME.Text,
        Font = font or FONT_BODY,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
    }, parent)
end

local function tween(obj, props, time, style, dir)
    local ti = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
end

-- ╔══════════════════════════╗
-- ║       MAIN WINDOW        ║
-- ╚══════════════════════════╝

local WINDOW_W = 480
local WINDOW_H = 520
local TITLEBAR_H = 36
local SIDEBAR_W = 110

local MainFrame = make("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
    Position = UDim2.new(0, 60, 0, 80),
    BackgroundColor3 = THEME.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, ScreenGui)
corner(10, MainFrame)
stroke(1.5, THEME.Border, 0, MainFrame)

-- Glow behind window
local glow = make("ImageLabel", {
    Size = UDim2.new(1, 80, 1, 80),
    Position = UDim2.new(0, -40, 0, -40),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageColor3 = THEME.Accent,
    ImageTransparency = 0.88,
    ZIndex = 0,
}, MainFrame)

-- ── TITLE BAR ──
local TitleBar = make("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, TITLEBAR_H),
    BackgroundColor3 = THEME.Panel,
    BorderSizePixel = 0,
    ZIndex = 10,
}, MainFrame)
corner(10, TitleBar)
-- fill bottom corners
make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = THEME.Panel,
    BorderSizePixel = 0,
    ZIndex = 9,
}, TitleBar)

-- Accent stripe
local accentStripe = make("Frame", {
    Size = UDim2.new(0, 3, 1, -12),
    Position = UDim2.new(0, 10, 0, 6),
    BackgroundColor3 = THEME.Accent,
    BorderSizePixel = 0,
    ZIndex = 11,
}, TitleBar)
corner(2, accentStripe)

-- Title text
make("TextLabel", {
    Text = "🫧  BGS INFINITY — LUNAR HUB",
    TextSize = 14,
    Font = FONT_TITLE,
    TextColor3 = THEME.Text,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -130, 1, 0),
    Position = UDim2.new(0, 22, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 11,
}, TitleBar)

-- Version badge
local verBadge = make("TextLabel", {
    Text = "v2.5",
    TextSize = 10,
    Font = FONT_MONO,
    TextColor3 = THEME.Accent,
    BackgroundColor3 = THEME.AccentDim,
    Size = UDim2.new(0, 36, 0, 18),
    Position = UDim2.new(1, -130, 0.5, -9),
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 11,
}, TitleBar)
corner(4, verBadge)

-- Close / Minimize buttons
local CloseBtn = make("TextButton", {
    Text = "✕",
    TextSize = 13,
    Font = FONT_TITLE,
    TextColor3 = THEME.Red,
    BackgroundColor3 = Color3.fromRGB(50, 20, 20),
    Size = UDim2.new(0, 26, 0, 20),
    Position = UDim2.new(1, -36, 0.5, -10),
    ZIndex = 12,
}, TitleBar)
corner(4, CloseBtn)

local MinBtn = make("TextButton", {
    Text = "—",
    TextSize = 13,
    Font = FONT_TITLE,
    TextColor3 = THEME.Yellow,
    BackgroundColor3 = Color3.fromRGB(50, 45, 10),
    Size = UDim2.new(0, 26, 0, 20),
    Position = UDim2.new(1, -68, 0.5, -10),
    ZIndex = 12,
}, TitleBar)
corner(4, MinBtn)

-- ── SIDEBAR ──
local Sidebar = make("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0, SIDEBAR_W, 1, -TITLEBAR_H),
    Position = UDim2.new(0, 0, 0, TITLEBAR_H),
    BackgroundColor3 = THEME.Panel,
    BorderSizePixel = 0,
    ZIndex = 5,
}, MainFrame)

local SidebarList = make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
}, Sidebar)
padding(8, 6, 8, 6, Sidebar)

-- ── CONTENT AREA ──
local ContentArea = make("Frame", {
    Name = "ContentArea",
    Size = UDim2.new(1, -SIDEBAR_W, 1, -TITLEBAR_H),
    Position = UDim2.new(0, SIDEBAR_W, 0, TITLEBAR_H),
    BackgroundColor3 = THEME.Bg,
    BorderSizePixel = 0,
    ZIndex = 4,
    ClipsDescendants = true,
}, MainFrame)

-- Separator line
make("Frame", {
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = THEME.Border,
    BorderSizePixel = 0,
    ZIndex = 6,
}, ContentArea)

-- ── TAB SYSTEM ──
local Tabs = {}
local TabButtons = {}
local ActiveTab = nil

local function switchTab(name)
    if ActiveTab == name then return end
    ActiveTab = name
    Config.CurrentTab = name

    for tabName, tabFrame in pairs(Tabs) do
        tabFrame.Visible = (tabName == name)
    end
    for tabName, tabBtn in pairs(TabButtons) do
        if tabName == name then
            tween(tabBtn, {BackgroundColor3 = THEME.AccentDim}, 0.15)
            tabBtn.TextLabel.TextColor3 = THEME.AccentGlow
        else
            tween(tabBtn, {BackgroundColor3 = THEME.Card}, 0.15)
            tabBtn.TextLabel.TextColor3 = THEME.TextDim
        end
    end
end

local function addTab(name, icon)
    local btn = make("TextButton", {
        Name = name,
        Text = "",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = #TabButtons + 1,
        AutoButtonColor = false,
        ZIndex = 6,
    }, Sidebar)
    corner(7, btn)

    local ico = make("TextLabel", {
        Text = icon,
        TextSize = 16,
        Font = FONT_BODY,
        TextColor3 = THEME.TextDim,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 26, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        ZIndex = 7,
    }, btn)

    local lbl = make("TextLabel", {
        Name = "TextLabel",
        Text = name,
        TextSize = 12,
        Font = FONT_BODY,
        TextColor3 = THEME.TextDim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 32, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
    }, btn)

    local tabFrame = make("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(1, -4, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 5,
        ClipsDescendants = true,
    }, ContentArea)

    local listLayout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, tabFrame)
    padding(8, 6, 8, 6, tabFrame)

    btn.MouseButton1Click:Connect(function() switchTab(name) end)
    btn.MouseEnter:Connect(function()
        if ActiveTab ~= name then
            tween(btn, {BackgroundColor3 = THEME.CardHover}, 0.1)
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= name then
            tween(btn, {BackgroundColor3 = THEME.Card}, 0.1)
        end
    end)

    Tabs[name] = tabFrame
    TabButtons[name] = btn
    return tabFrame
end

-- ── WIDGET BUILDERS ──

local function addSectionHeader(parent, text)
    local lbl = make("TextLabel", {
        Text = "  " .. text,
        TextSize = 11,
        Font = FONT_TITLE,
        TextColor3 = THEME.Accent,
        BackgroundColor3 = THEME.AccentDim,
        Size = UDim2.new(1, 0, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    }, parent)
    corner(5, lbl)
    return lbl
end

local function addToggle(parent, title, desc, getValue, onToggle, order)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = order or 1,
        ZIndex = 6,
    }, parent)
    corner(7, card)
    padding(6, 8, 6, 8, card)

    make("TextLabel", {
        Text = title,
        TextSize = 13,
        Font = FONT_BODY,
        TextColor3 = THEME.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -50, 0, 18),
        ZIndex = 7,
    }, card)

    if desc and #desc > 0 then
        make("TextLabel", {
            Text = desc,
            TextSize = 10,
            Font = FONT_BODY,
            TextColor3 = THEME.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -50, 0, 14),
            Position = UDim2.new(0, 0, 0, 20),
            ZIndex = 7,
        }, card)
    end

    -- Toggle pill
    local pillBg = make("Frame", {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = getValue() and THEME.Green or THEME.Border,
        ZIndex = 7,
    }, card)
    corner(10, pillBg)

    local pillDot = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = getValue() and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.new(1,1,1),
        ZIndex = 8,
    }, pillBg)
    corner(7, pillDot)

    local toggleBtn = make("TextButton", {
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 9,
    }, pillBg)

    local function refresh()
        local val = getValue()
        tween(pillBg, {BackgroundColor3 = val and THEME.Green or THEME.Border}, 0.15)
        tween(pillDot, {Position = val and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}, 0.15)
    end

    toggleBtn.MouseButton1Click:Connect(function()
        onToggle()
        refresh()
    end)

    return card, refresh
end

local function addButton(parent, text, color, onClick, order)
    local btn = make("TextButton", {
        Text = text,
        TextSize = 13,
        Font = FONT_BODY,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = color or THEME.Accent,
        Size = UDim2.new(1, 0, 0, 36),
        AutoButtonColor = false,
        LayoutOrder = order or 1,
        ZIndex = 6,
    }, parent)
    corner(7, btn)

    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = (color or THEME.Accent):Lerp(Color3.new(1,1,1), 0.1)}, 0.12) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = color or THEME.Accent}, 0.12) end)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

local function addSlider(parent, title, min, max, getValue, onChange, order)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = order or 1,
        ZIndex = 6,
    }, parent)
    corner(7, card)
    padding(6, 8, 6, 8, card)

    local titleRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        ZIndex = 7,
    }, card)

    make("TextLabel", {
        Text = title,
        TextSize = 13,
        Font = FONT_BODY,
        TextColor3 = THEME.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.7, 0, 1, 0),
        ZIndex = 7,
    }, titleRow)

    local valueLabel = make("TextLabel", {
        Text = tostring(getValue()),
        TextSize = 13,
        Font = FONT_MONO,
        TextColor3 = THEME.Accent,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.7, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 7,
    }, titleRow)

    -- Slider track
    local track = make("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = THEME.Border,
        ZIndex = 7,
    }, card)
    corner(3, track)

    local fill = make("Frame", {
        Size = UDim2.new((getValue() - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = THEME.Accent,
        ZIndex = 8,
    }, track)
    corner(3, fill)

    local handle = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new((getValue() - min) / (max - min), -7, 0.5, -7),
        BackgroundColor3 = Color3.new(1,1,1),
        ZIndex = 9,
    }, track)
    corner(7, handle)

    -- Interaction
    local dragging = false
    local trackBtn = make("TextButton", {
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
    }, track)

    local function setVal(absX)
        local rel = math.clamp((absX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + rel * (max - min))
        local fillRatio = (val - min) / (max - min)
        fill.Size = UDim2.new(fillRatio, 0, 1, 0)
        handle.Position = UDim2.new(fillRatio, -7, 0.5, -7)
        valueLabel.Text = tostring(val)
        onChange(val)
    end

    trackBtn.MouseButton1Down:Connect(function() dragging = true end)
    Mouse.Button1Up:Connect(function() dragging = false end)
    Mouse.Move:Connect(function()
        if dragging then setVal(Mouse.X) end
    end)
    trackBtn.MouseButton1Down:Connect(function() setVal(Mouse.X) end)

    return card
end

local function addInfoCard(parent, lines, order)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = THEME.Card,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order or 1,
        ZIndex = 6,
    }, parent)
    corner(7, card)
    padding(8, 8, 8, 8, card)
    stroke(1, THEME.Border, 0, card)

    local list = make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, card)

    local labels = {}
    for i, line in ipairs(lines) do
        local lbl = make("TextLabel", {
            Text = line,
            TextSize = 12,
            Font = FONT_BODY,
            TextColor3 = THEME.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            RichText = true,
            LayoutOrder = i,
            ZIndex = 7,
        }, card)
        labels[i] = lbl
    end

    return card, labels
end

-- ╔══════════════════════════╗
-- ║       BUILD TABS         ║
-- ╚══════════════════════════╝

-- ────── TAB: Farm ──────
local farmTab = addTab("Farm", "🌀")

addSectionHeader(farmTab, "AUTO FARM").LayoutOrder = 1

addToggle(farmTab,
    "Auto Blow & Sell",
    "Blows + sells bubble every 50ms",
    function() return Config.AutoBlow end,
    function() Config.AutoBlow = not Config.AutoBlow; log("AutoBlow: " .. tostring(Config.AutoBlow)) end,
    2)

addToggle(farmTab,
    "Auto Hatch Egg",
    "Continuously hatches eggs",
    function() return Config.AutoHatch end,
    function()
        Config.AutoHatch = not Config.AutoHatch
        if Config.AutoHatch then
            task.spawn(function()
                while Config.AutoHatch do
                    safeCall(hatchEgg)
                    task.wait(0.5)
                end
            end)
        end
    end, 3)

addSectionHeader(farmTab, "CLAIM REWARDS").LayoutOrder = 4

addButton(farmTab, "🎁  Claim All Prizes", THEME.Green, function()
    safeCall(claimAllPrizes)
end, 5)

addButton(farmTab, "⭐  Claim Playtime Rewards", THEME.Accent, function()
    if Remote then
        task.spawn(function()
            Remote.Fire("ClaimAllPlaytime")
            local r = Remote.Invoke("ClaimPlaytime")
            log("Playtime claim: " .. tostring(r))
        end)
    end
end, 6)

addButton(farmTab, "🏆  Claim World Reward", THEME.AccentDim, function()
    if Remote then Remote.Fire("ClaimWorldReward") end
end, 7)

addButton(farmTab, "📦  Claim Obby Chest", Color3.fromRGB(180, 100, 40), function()
    if Remote then Remote.Fire("ClaimObbyChest") end
end, 8)

addSectionHeader(farmTab, "STATS").LayoutOrder = 9

local _, statsLabels = addInfoCard(farmTab, {
    "🫧 Bubbles Blown:  <b>0</b>",
    "⏱ Session Time:   <b>0s</b>",
    "📊 Bubbles/min:    <b>0</b>",
}, 10)

-- Update stats every second
task.spawn(function()
    while true do
        task.wait(1)
        local elapsed = tick() - State.StartTime
        local bpm = elapsed > 0 and math.floor(State.BubblesBlown / elapsed * 60) or 0
        if statsLabels[1] then
            statsLabels[1].Text = "🫧 Bubbles Blown:  <b>" .. formatNum(State.BubblesBlown) .. "</b>"
            statsLabels[2].Text = "⏱ Session Time:   <b>" .. formatTime(elapsed) .. "</b>"
            statsLabels[3].Text = "📊 Bubbles/min:    <b>" .. formatNum(bpm) .. "</b>"
        end
    end
end)

-- ────── TAB: Speed ──────
local speedTab = addTab("Speed", "💨")

addSectionHeader(speedTab, "MOVEMENT").LayoutOrder = 1

addToggle(speedTab,
    "Custom Walk Speed",
    "Override humanoid walk speed",
    function() return Config.WalkSpeedEnabled end,
    function()
        Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
        applyWalkSpeed()
    end, 2)

addSlider(speedTab, "Walk Speed", 16, 300,
    function() return Config.WalkSpeed end,
    function(val)
        Config.WalkSpeed = val
        if Config.WalkSpeedEnabled then applyWalkSpeed() end
    end, 3)

addToggle(speedTab,
    "Custom Jump Power",
    "Override jump height",
    function() return Config.JumpPowerEnabled end,
    function()
        Config.JumpPowerEnabled = not Config.JumpPowerEnabled
        applyJumpPower()
    end, 4)

addSlider(speedTab, "Jump Power", 50, 500,
    function() return Config.JumpPower end,
    function(val)
        Config.JumpPower = val
        if Config.JumpPowerEnabled then applyJumpPower() end
    end, 5)

addToggle(speedTab,
    "Infinite Jump",
    "Re-jump instantly on keypress",
    function() return Config.InfJumpEnabled end,
    function() Config.InfJumpEnabled = not Config.InfJumpEnabled end,
    6)

addSectionHeader(speedTab, "ADVANCED MOVEMENT").LayoutOrder = 7

addToggle(speedTab,
    "Noclip",
    "Pass through all parts",
    function() return Config.NoclipEnabled end,
    function() Config.NoclipEnabled = not Config.NoclipEnabled end,
    8)

addToggle(speedTab,
    "Fly Mode (WASD + Space/Ctrl)",
    "Free-fly around the map",
    function() return Config.FlyEnabled end,
    function()
        Config.FlyEnabled = not Config.FlyEnabled
        if Config.FlyEnabled then
            task.defer(enableFly)
        else
            disableFly()
        end
    end, 9)

addSlider(speedTab, "Fly Speed", 10, 300,
    function() return FLY_SPEED end,
    function(val) FLY_SPEED = val end,
    10)

-- ────── TAB: Teleport ──────
local tpTab = addTab("Teleport", "🌀")

addSectionHeader(tpTab, "WORLDS").LayoutOrder = 1

for i, worldName in ipairs(Config.Worlds) do
    addButton(tpTab, "🌍  " .. worldName, THEME.AccentDim, function()
        safeCall(teleportToWorld, worldName)
    end, i + 1)
end

addSectionHeader(tpTab, "LOCATIONS").LayoutOrder = 10

addButton(tpTab, "🏡  Teleport Home",  THEME.Card,  function() safeCall(teleportHome) end, 11)
addButton(tpTab, "🏪  Teleport Plaza", THEME.Card,  function() safeCall(teleportToPlaza) end, 12)

addSectionHeader(tpTab, "QUICK TELEPORT").LayoutOrder = 13

addButton(tpTab, "🔑  Unlock All Worlds (attempt)", THEME.Red, function()
    if Remote then
        for _, w in ipairs(Config.Worlds) do
            task.spawn(function()
                safeCall(function() Remote.Fire("UnlockWorld", w) end)
            end)
            task.wait(0.3)
        end
        log("Sent UnlockWorld for all worlds")
    end
end, 14)

addButton(tpTab, "🔓  Unlock All Hatching Zones", THEME.Accent, function()
    if Remote then
        for i = 1, 20 do
            safeCall(function() Remote.Fire("UnlockHatchingZone", i) end)
            task.wait(0.1)
        end
    end
end, 15)

-- ────── TAB: Codes ──────
local codesTab = addTab("Codes", "🎟️")

addSectionHeader(codesTab, "ALL PROMO CODES (" .. #PROMO_CODES .. ")").LayoutOrder = 1

addButton(codesTab, "✅  Redeem ALL Codes", THEME.Green, function()
    safeCall(redeemAllCodes)
end, 2)

addInfoCard(codesTab, {
    "<b>Note:</b> Codes already redeemed will be skipped",
    "by the server. Safe to run multiple times.",
}, 3)

addSectionHeader(codesTab, "CODE LIST").LayoutOrder = 4

for i, code in ipairs(PROMO_CODES) do
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = i + 4,
        ZIndex = 6,
    }, codesTab)
    corner(5, card)
    padding(4, 8, 4, 8, card)

    make("TextLabel", {
        Text = "🎟  " .. code,
        TextSize = 12,
        Font = FONT_MONO,
        TextColor3 = THEME.TextDim,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.65, 0, 1, 0),
        ZIndex = 7,
    }, card)

    local singleBtn = make("TextButton", {
        Text = "Redeem",
        TextSize = 11,
        Font = FONT_BODY,
        TextColor3 = THEME.Accent,
        BackgroundColor3 = THEME.AccentDim,
        Size = UDim2.new(0, 64, 0, 20),
        Position = UDim2.new(1, -72, 0.5, -10),
        AutoButtonColor = false,
        ZIndex = 7,
    }, card)
    corner(4, singleBtn)
    local capturedCode = code
    singleBtn.MouseButton1Click:Connect(function()
        safeCall(redeemCode, capturedCode)
    end)
end

-- ────── TAB: Misc ──────
local miscTab = addTab("Misc", "⚙️")

addSectionHeader(miscTab, "UTILITY").LayoutOrder = 1

addToggle(miscTab,
    "Anti-AFK",
    "Prevents kick from AFK detection",
    function() return Config.AntiAFKEnabled end,
    function() Config.AntiAFKEnabled = not Config.AntiAFKEnabled end,
    2)

addToggle(miscTab,
    "Player ESP",
    "Highlights all players in red",
    function() return Config.ESPEnabled end,
    function()
        Config.ESPEnabled = not Config.ESPEnabled
        if not Config.ESPEnabled then clearESP() end
    end, 3)

addSectionHeader(miscTab, "MASTERY / UPGRADES").LayoutOrder = 4

addButton(miscTab, "⬆️  Upgrade Mastery (x1)", THEME.Accent, function()
    if Remote then Remote.Fire("UpgradeMastery", 1) end
end, 5)

addButton(miscTab, "⬆️  Upgrade Mastery (x10)", THEME.AccentDim, function()
    if Remote then
        task.spawn(function()
            for i = 1, 10 do
                Remote.Fire("UpgradeMastery", 1)
                task.wait(0.15)
            end
        end)
    end
end, 6)

addSectionHeader(miscTab, "EVENTS").LayoutOrder = 7

addButton(miscTab, "🎪  Unlock Event Chest", Color3.fromRGB(180, 80, 200), function()
    if Remote then Remote.Fire("UnlockEventChest") end
end, 8)

addButton(miscTab, "🎯  Claim Event Prize", THEME.Green, function()
    if Remote then Remote.Fire("ClaimEventPrize") end
end, 9)

addButton(miscTab, "🏅  Claim Competitive Prize", THEME.Yellow, function()
    if Remote then Remote.Fire("ClaimCompetitivePrize") end
end, 10)

addButton(miscTab, "🎪  Claim Challenge Pass Reward", THEME.Accent, function()
    if Remote then Remote.Fire("ChallengePassClaimReward") end
end, 11)

addSectionHeader(miscTab, "FISHING").LayoutOrder = 12

addButton(miscTab, "🐟  Sell All Fish", Color3.fromRGB(60, 120, 220), function()
    if Remote then Remote.Fire("SellAllFish") end
end, 13)

addButton(miscTab, "🎣  Claim All Fishing Rewards", Color3.fromRGB(40, 160, 200), function()
    if Remote then Remote.Fire("ClaimAllFishingIndexRewards") end
end, 14)

addSectionHeader(miscTab, "DEBUG").LayoutOrder = 15

addButton(miscTab, "🔌  Re-initialize Remotes", Color3.fromRGB(80, 80, 80), function()
    local ok = initRemotes()
    log("Remote init: " .. (ok and "SUCCESS" or "FAILED"))
end, 16)

addButton(miscTab, "🗑️  Clear ESP Highlights", Color3.fromRGB(80, 80, 80), function()
    clearESP()
    log("ESP cleared")
end, 17)

-- ────── TAB: Info ──────
local infoTab = addTab("Info", "📋")

addSectionHeader(infoTab, "ABOUT THIS SCRIPT").LayoutOrder = 1

addInfoCard(infoTab, {
    "<b>BGS Infinity — Lunar Hub</b>",
    "Extracted from game ID: 85896571713843",
    "Version: 2.5  |  Build: 2026-02-23",
    "",
    "636 scripts analyzed from live game files",
    "All remote actions extracted from decompiled source",
}, 2)

addSectionHeader(infoTab, "REMOTE ACTIONS AVAILABLE").LayoutOrder = 3

local remoteList = {
    "BlowBubble", "SellBubble", "HatchEgg", "UnlockWorld",
    "UnlockHatchingZone", "Teleport", "WorldTeleport", "PlazaTeleport",
    "ClaimPrize", "ClaimWorldReward", "ClaimEventPrize",
    "ClaimCompetitivePrize", "ClaimAllPlaytime", "ClaimObbyChest",
    "ClaimAllFishingIndexRewards", "SellAllFish", "UpgradeMastery",
    "ChallengePassClaimReward", "UnlockEventChest", "ClaimGift",
    "ClaimIndex", "ClaimChest", "ClaimXLIndexRewards", "CompetitiveReroll",
    "DoggyJumpWin", "FinishMinigame", "EggPrizeClaim", "ClaimBenefits",
    "DailyRewardClaimStars", "DailyRewardsBuyItem", "RerollGenie",
    "ChangeGenieQuest", "StartGenieQuest", "StartObby", "CompleteObby",
}

for i, action in ipairs(remoteList) do
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = (i % 2 == 0) and THEME.Card or THEME.Panel,
        LayoutOrder = i + 3,
        ZIndex = 6,
    }, infoTab)
    corner(4, row)
    padding(3, 6, 3, 6, row)

    make("TextLabel", {
        Text = "⚡ " .. action,
        TextSize = 11,
        Font = FONT_MONO,
        TextColor3 = THEME.TextDim,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 7,
    }, row)
end

-- ╔══════════════════════════╗
-- ║    DRAGGING LOGIC        ║
-- ╚══════════════════════════╝

do
    local dragging, dragInput, mousePos, framePos

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            MainFrame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ╔══════════════════════════╗
-- ║    WINDOW CONTROLS       ║
-- ╚══════════════════════════╝

local minimized = false

CloseBtn.MouseButton1Click:Connect(function()
    tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, 0)}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.wait(0.25)
    ScreenGui:Destroy()
    log("Hub closed.")
end)

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, TITLEBAR_H)}, 0.25, Enum.EasingStyle.Back)
    else
        tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end
end)

-- Keybind: RightShift to toggle visibility
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Config.Visible = not Config.Visible
        MainFrame.Visible = Config.Visible
    end
end)

-- ╔══════════════════════════╗
-- ║    INIT & OPEN ANIM      ║
-- ╚══════════════════════════╝

-- Initialize
switchTab("Farm")
setupInfJump()
setupNoclip()
setupAntiAFK()

-- Boot animation
MainFrame.Size = UDim2.new(0, WINDOW_W, 0, 0)
tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Init remotes
task.defer(function()
    local ok = initRemotes()
    if ok then
        log("✅ Remotes connected successfully!")
    else
        log("⚠️ Remotes not found – some features disabled until game loads")
        -- Retry loop
        task.spawn(function()
            while not Remote do
                task.wait(3)
                initRemotes()
            end
        end)
    end
end)

-- Notify on screen
task.spawn(function()
    task.wait(0.5)
    local notif = make("TextLabel", {
        Text = "🫧  BGS Infinity Hub loaded! Press [RShift] to toggle.",
        TextSize = 13,
        Font = FONT_BODY,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = THEME.Accent,
        Size = UDim2.new(0, 360, 0, 36),
        Position = UDim2.new(0.5, -180, 1, -60),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 100,
    }, ScreenGui)
    corner(8, notif)
    tween(notif, {Position = UDim2.new(0.5, -180, 1, -80)}, 0.4, Enum.EasingStyle.Back)
    task.wait(3.5)
    tween(notif, {Position = UDim2.new(0.5, -180, 1, -20), BackgroundTransparency = 1, TextTransparency = 1}, 0.4)
    task.wait(0.5)
    notif:Destroy()
end)

log("BGS Infinity Lunar Hub v2.5 — Fully loaded!")
log("→ " .. #PROMO_CODES .. " promo codes ready")
log("→ " .. #remoteList .. " remote actions mapped")
log("→ Press [RightShift] to show/hide")
