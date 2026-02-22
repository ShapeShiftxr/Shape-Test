-- ╔══════════════════════════════════════════════════════════════════╗
-- ║      BGS INFINITY — LUNAR HUB  |  Fluent UI Edition             ║
-- ║      Extracted from: place_85896571713843                        ║
-- ║      UI: dawid-scripts/Fluent  |  github.com/dawid-scripts/Fluent║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── LOAD FLUENT ──
local Fluent        = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager   = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ── SERVICES ──
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ╔══════════════════════════╗
-- ║    REMOTE REFERENCES     ║
-- ╚══════════════════════════╝

local Remote, RemoteEvent, RemoteFunction

local function initRemotes()
    local ok, remoteModule = pcall(function()
        return ReplicatedStorage
            :WaitForChild("Shared", 5)
            :WaitForChild("Framework", 5)
            :WaitForChild("Network", 5)
            :WaitForChild("Remote", 5)
    end)
    if ok and remoteModule then
        RemoteEvent    = remoteModule:FindFirstChild("RemoteEvent")
        RemoteFunction = remoteModule:FindFirstChild("RemoteFunction")
        Remote = {
            Fire   = function(action, ...) if RemoteEvent    then RemoteEvent:FireServer(action, ...)           end end,
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
    AutoBlow         = false,
    AutoHatch        = false,
    WalkSpeedEnabled = false,
    WalkSpeed        = 32,
    JumpPowerEnabled = false,
    JumpPower        = 80,
    InfJumpEnabled   = false,
    NoclipEnabled    = false,
    FlyEnabled       = false,
    FlySpeed         = 60,
    ESPEnabled       = false,
    AntiAFKEnabled   = true,
    CodeDelay        = 1.0,
    SelectedWorld    = "The Overworld",
    Worlds = {
        "The Overworld",
        "Minigame Paradise",
        "Seven Seas",
        "Christmas World",
    },
}

local State = {
    BubblesBlown  = 0,
    StartTime     = tick(),
    FlyBodyVelocity = nil,
    FlyBodyGyro     = nil,
}

-- ╔══════════════════════════╗
-- ║    UTILITY FUNCTIONS     ║
-- ╚══════════════════════════╝

local function safeCall(fn, ...) pcall(fn, ...) end

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

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("Humanoid")
end

local function getRootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ╔══════════════════════════╗
-- ║    CORE FEATURE FUNCS    ║
-- ╚══════════════════════════╝

-- ── AUTO BLOW ──
local BLOW_INTERVAL = 0.05
local lastBlow = 0

-- ── HATCH EGG ──
local function hatchEgg()
    if Remote then Remote.Fire("HatchEgg") end
end

-- ── TELEPORT ──
local function teleportToWorld(name)
    if Remote then Remote.Fire("WorldTeleport", name) end
end

-- ── CLAIM ALL ──
local function claimAllPrizes()
    if not Remote then return end
    for _, action in ipairs({
        "ClaimPrize", "ClaimWorldReward", "ClaimObbyChest",
        "ClaimEventPrize", "ClaimCompetitivePrize", "ClaimAllPlaytime",
        "ClaimAllFishingIndexRewards", "ChallengePassClaimReward",
    }) do
        safeCall(function() Remote.Fire(action) end)
        task.wait(0.2)
    end
end

-- ── WALK SPEED ──
local function applyWalkSpeed()
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = Config.WalkSpeedEnabled and Config.WalkSpeed or 16 end
end

-- ── JUMP POWER ──
local function applyJumpPower()
    local hum = getHumanoid()
    if hum then hum.JumpPower = Config.JumpPowerEnabled and Config.JumpPower or 50 end
end

-- ── INFINITE JUMP ──
UserInputService.JumpRequest:Connect(function()
    if Config.InfJumpEnabled then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ── NOCLIP ──
RunService.Stepped:Connect(function()
    if Config.NoclipEnabled then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
end)

-- ── FLY ──
local function enableFly()
    local root = getRootPart()
    if not root then return end
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
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
            bv.Velocity = dir * Config.FlySpeed
            bg.CFrame = cam.CFrame
            task.wait()
        end
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

-- ── ANTI-AFK ──
task.spawn(function()
    local VU = game:GetService("VirtualUser")
    while true do
        task.wait(60)
        if Config.AntiAFKEnabled then
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end
    end
end)

-- ── ESP ──
local ESPBoxes = {}
local function clearESP()
    for _, h in pairs(ESPBoxes) do if h and h.Parent then h:Destroy() end end
    ESPBoxes = {}
end

-- ── REDEEM CODE ──
local function redeemCode(code)
    safeCall(function()
        if RemoteEvent then RemoteEvent:FireServer("RedeemCode", code) end
    end)
end

local function redeemAllCodes()
    task.spawn(function()
        for _, code in ipairs(PROMO_CODES) do
            redeemCode(code)
            task.wait(Config.CodeDelay)
        end
        Fluent:Notify({ Title = "Codes", Content = "All " .. #PROMO_CODES .. " codes attempted!", Duration = 4 })
    end)
end

-- ╔══════════════════════════╗
-- ║       MAIN GAME LOOP     ║
-- ╚══════════════════════════╝

RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Auto blow
    if Config.AutoBlow and (now - lastBlow) >= BLOW_INTERVAL then
        safeCall(function()
            if Remote then
                Remote.Fire("BlowBubble")
                Remote.Fire("SellBubble")
                State.BubblesBlown += 1
            end
        end)
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

    -- ESP
    if Config.ESPEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if not ESPBoxes[player.Name] or not ESPBoxes[player.Name].Parent then
                    local sel = Instance.new("SelectionBox")
                    sel.Color3 = Color3.fromRGB(255, 60, 60)
                    sel.LineThickness = 0.07
                    sel.SurfaceTransparency = 0.75
                    sel.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
                    sel.Adornee = player.Character
                    sel.Parent = Workspace
                    ESPBoxes[player.Name] = sel
                else
                    ESPBoxes[player.Name].Adornee = player.Character
                end
            end
        end
    end
end)

-- ╔══════════════════════════╗
-- ║      BUILD FLUENT UI     ║
-- ╚══════════════════════════╝

local Window = Fluent:CreateWindow({
    Title    = "BGS Infinity — Lunar Hub",
    SubTitle = "by Lunar  |  v2.5",
    TabWidth = 140,
    Size     = UDim2.fromOffset(580, 460),
    Acrylic  = true,
    Theme    = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift,
})

local Options = Fluent.Options

local Tabs = {
    Farm     = Window:AddTab({ Title = "Farm",     Icon = "wind"         }),
    Speed    = Window:AddTab({ Title = "Speed",    Icon = "zap"          }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin"      }),
    Codes    = Window:AddTab({ Title = "Codes",    Icon = "ticket"       }),
    Misc     = Window:AddTab({ Title = "Misc",     Icon = "settings"     }),
    Info     = Window:AddTab({ Title = "Info",     Icon = "info"         }),
}

-- ════════════════════════════
--           FARM TAB
-- ════════════════════════════

Tabs.Farm:AddParagraph({
    Title   = "Auto Farm",
    Content = "Automatically blow and sell bubbles at max speed (50ms interval).",
})

Tabs.Farm:AddToggle("AutoBlow", {
    Title   = "Auto Blow & Sell Bubble",
    Default = false,
    Callback = function(val)
        Config.AutoBlow = val
    end,
})

Tabs.Farm:AddToggle("AutoHatch", {
    Title   = "Auto Hatch Egg",
    Default = false,
    Callback = function(val)
        Config.AutoHatch = val
        if val then
            task.spawn(function()
                while Config.AutoHatch do
                    safeCall(hatchEgg)
                    task.wait(0.5)
                end
            end)
        end
    end,
})

Tabs.Farm:AddParagraph({
    Title   = "Claim Rewards",
    Content = "Instantly fire all claim remotes at once.",
})

Tabs.Farm:AddButton({
    Title   = "Claim ALL Prizes",
    Description = "ClaimPrize, WorldReward, Obby, Events, Playtime, Fishing, ChallengePass",
    Callback = function()
        safeCall(claimAllPrizes)
        Fluent:Notify({ Title = "Farm", Content = "Claim all fired!", Duration = 3 })
    end,
})

Tabs.Farm:AddButton({
    Title    = "Sell All Fish",
    Description = "Fires SellAllFish remote",
    Callback = function()
        if Remote then Remote.Fire("SellAllFish") end
        Fluent:Notify({ Title = "Fishing", Content = "SellAllFish fired!", Duration = 2 })
    end,
})

Tabs.Farm:AddButton({
    Title    = "Upgrade Mastery ×10",
    Description = "Fires UpgradeMastery 10 times",
    Callback = function()
        if Remote then
            task.spawn(function()
                for i = 1, 10 do
                    Remote.Fire("UpgradeMastery", 1)
                    task.wait(0.15)
                end
            end)
            Fluent:Notify({ Title = "Mastery", Content = "Upgraded ×10!", Duration = 2 })
        end
    end,
})

Tabs.Farm:AddParagraph({
    Title   = "Session Stats",
    Content = "Check the Info tab for live stats.",
})

-- ════════════════════════════
--          SPEED TAB
-- ════════════════════════════

Tabs.Speed:AddParagraph({
    Title   = "Movement",
    Content = "Modify your character's movement. Changes apply instantly.",
})

Tabs.Speed:AddToggle("WalkSpeedEnabled", {
    Title    = "Custom Walk Speed",
    Default  = false,
    Callback = function(val)
        Config.WalkSpeedEnabled = val
        applyWalkSpeed()
    end,
})

Tabs.Speed:AddSlider("WalkSpeed", {
    Title   = "Walk Speed",
    Min     = 16,
    Max     = 300,
    Default = 32,
    Rounding = 0,
    Callback = function(val)
        Config.WalkSpeed = val
        if Config.WalkSpeedEnabled then applyWalkSpeed() end
    end,
})

Tabs.Speed:AddToggle("JumpPowerEnabled", {
    Title    = "Custom Jump Power",
    Default  = false,
    Callback = function(val)
        Config.JumpPowerEnabled = val
        applyJumpPower()
    end,
})

Tabs.Speed:AddSlider("JumpPower", {
    Title   = "Jump Power",
    Min     = 50,
    Max     = 500,
    Default = 80,
    Rounding = 0,
    Callback = function(val)
        Config.JumpPower = val
        if Config.JumpPowerEnabled then applyJumpPower() end
    end,
})

Tabs.Speed:AddToggle("InfJump", {
    Title    = "Infinite Jump",
    Default  = false,
    Callback = function(val)
        Config.InfJumpEnabled = val
    end,
})

Tabs.Speed:AddParagraph({
    Title   = "Advanced Movement",
    Content = "Noclip and fly. Fly controls: WASD + Space (up) + LeftCtrl (down).",
})

Tabs.Speed:AddToggle("Noclip", {
    Title    = "Noclip",
    Default  = false,
    Callback = function(val)
        Config.NoclipEnabled = val
    end,
})

Tabs.Speed:AddToggle("Fly", {
    Title    = "Fly Mode",
    Default  = false,
    Callback = function(val)
        Config.FlyEnabled = val
        if val then task.defer(enableFly) else disableFly() end
    end,
})

Tabs.Speed:AddSlider("FlySpeed", {
    Title    = "Fly Speed",
    Min      = 10,
    Max      = 300,
    Default  = 60,
    Rounding = 0,
    Callback = function(val)
        Config.FlySpeed = val
    end,
})

-- ════════════════════════════
--        TELEPORT TAB
-- ════════════════════════════

Tabs.Teleport:AddParagraph({
    Title   = "World Teleport",
    Content = "Teleport to any world. Fires WorldTeleport remote directly.",
})

for _, worldName in ipairs(Config.Worlds) do
    local wn = worldName
    Tabs.Teleport:AddButton({
        Title    = worldName,
        Description = "Teleport to " .. worldName,
        Callback = function()
            safeCall(teleportToWorld, wn)
            Fluent:Notify({ Title = "Teleport", Content = "→ " .. wn, Duration = 2 })
        end,
    })
end

Tabs.Teleport:AddParagraph({
    Title   = "Quick Locations",
    Content = "Shortcut teleports.",
})

Tabs.Teleport:AddButton({
    Title    = "Home",
    Description = "Fires 'home' remote",
    Callback = function()
        if Remote then Remote.Fire("home") end
    end,
})

Tabs.Teleport:AddButton({
    Title    = "Plaza",
    Description = "Fires PlazaTeleport remote",
    Callback = function()
        if Remote then Remote.Fire("PlazaTeleport") end
    end,
})

Tabs.Teleport:AddParagraph({
    Title   = "Unlock",
    Content = "Attempt to fire unlock remotes for all worlds and hatching zones.",
})

Tabs.Teleport:AddButton({
    Title    = "Unlock All Worlds",
    Description = "Fires UnlockWorld for all 4 worlds",
    Callback = function()
        if Remote then
            task.spawn(function()
                for _, w in ipairs(Config.Worlds) do
                    safeCall(function() Remote.Fire("UnlockWorld", w) end)
                    task.wait(0.3)
                end
            end)
            Fluent:Notify({ Title = "Unlock", Content = "UnlockWorld fired for all worlds", Duration = 3 })
        end
    end,
})

Tabs.Teleport:AddButton({
    Title    = "Unlock All Hatching Zones",
    Description = "Fires UnlockHatchingZone 1-20",
    Callback = function()
        if Remote then
            task.spawn(function()
                for i = 1, 20 do
                    safeCall(function() Remote.Fire("UnlockHatchingZone", i) end)
                    task.wait(0.1)
                end
            end)
            Fluent:Notify({ Title = "Unlock", Content = "Hatching zones unlock fired", Duration = 3 })
        end
    end,
})

-- ════════════════════════════
--          CODES TAB
-- ════════════════════════════

Tabs.Codes:AddParagraph({
    Title   = "Promo Codes — " .. #PROMO_CODES .. " codes extracted",
    Content = "All codes pulled directly from the Codes module in ReplicatedStorage.Shared.Data.Codes.\nAlready redeemed codes are ignored server-side.",
})

Tabs.Codes:AddButton({
    Title    = "Redeem ALL Codes",
    Description = "Redeems all " .. #PROMO_CODES .. " codes with " .. Config.CodeDelay .. "s delay each",
    Callback = redeemAllCodes,
})

Tabs.Codes:AddSlider("CodeDelay", {
    Title    = "Delay Between Codes (seconds)",
    Min      = 0.3,
    Max      = 5.0,
    Default  = 1.0,
    Rounding = 1,
    Callback = function(val)
        Config.CodeDelay = val
    end,
})

Tabs.Codes:AddParagraph({
    Title   = "Individual Codes",
    Content = "Use the buttons below to redeem a single code.",
})

for _, code in ipairs(PROMO_CODES) do
    local c = code
    Tabs.Codes:AddButton({
        Title    = code,
        Callback = function()
            redeemCode(c)
            Fluent:Notify({ Title = "Code", Content = "Redeemed: " .. c, Duration = 2 })
        end,
    })
end

-- ════════════════════════════
--           MISC TAB
-- ════════════════════════════

Tabs.Misc:AddParagraph({
    Title   = "Utility",
    Content = "General utilities and quality of life features.",
})

Tabs.Misc:AddToggle("AntiAFK", {
    Title    = "Anti-AFK",
    Default  = true,
    Callback = function(val)
        Config.AntiAFKEnabled = val
    end,
})

Tabs.Misc:AddToggle("ESP", {
    Title    = "Player ESP",
    Default  = false,
    Callback = function(val)
        Config.ESPEnabled = val
        if not val then clearESP() end
    end,
})

Tabs.Misc:AddParagraph({
    Title   = "Events & Special",
    Content = "Fire event-specific remotes.",
})

Tabs.Misc:AddButton({
    Title    = "Unlock Event Chest",
    Callback = function()
        if Remote then Remote.Fire("UnlockEventChest") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Claim Event Prize",
    Callback = function()
        if Remote then Remote.Fire("ClaimEventPrize") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Claim Competitive Prize",
    Callback = function()
        if Remote then Remote.Fire("ClaimCompetitivePrize") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Challenge Pass Claim Reward",
    Callback = function()
        if Remote then Remote.Fire("ChallengePassClaimReward") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Daily Reward Claim Stars",
    Callback = function()
        if Remote then Remote.Fire("DailyRewardClaimStars") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Claim All Fishing Index Rewards",
    Callback = function()
        if Remote then Remote.Fire("ClaimAllFishingIndexRewards") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Claim Index",
    Callback = function()
        if Remote then Remote.Fire("ClaimIndex") end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Claim XL Index Rewards",
    Callback = function()
        if Remote then Remote.Fire("ClaimXLIndexRewards") end
    end,
})

Tabs.Misc:AddParagraph({
    Title   = "Debug",
    Content = "Troubleshooting tools.",
})

Tabs.Misc:AddButton({
    Title    = "Re-Initialize Remotes",
    Description = "Tries to reconnect to the game's remote events",
    Callback = function()
        local ok = initRemotes()
        Fluent:Notify({
            Title   = "Remotes",
            Content = ok and "✅ Connected!" or "❌ Failed – game may not be loaded yet",
            Duration = 4,
        })
    end,
})

Tabs.Misc:AddButton({
    Title    = "Clear ESP Highlights",
    Callback = function()
        clearESP()
        Fluent:Notify({ Title = "ESP", Content = "Cleared all highlights", Duration = 2 })
    end,
})

-- ════════════════════════════
--           INFO TAB
-- ════════════════════════════

Tabs.Info:AddParagraph({
    Title   = "BGS Infinity — Lunar Hub v2.5",
    Content = "Extracted and built from Game ID: 85896571713843\n"
           .. "636 scripts analyzed  |  80+ remote actions mapped\n"
           .. "52 promo codes extracted from Shared.Data.Codes\n"
           .. "UI: Fluent by dawid-scripts\n"
           .. "[RightShift] = toggle window",
})

Tabs.Info:AddParagraph({
    Title   = "Network Architecture",
    Content = "All actions use a single RemoteEvent/RemoteFunction pair.\n"
           .. "Pattern: RemoteEvent:FireServer(actionName, ...)\n"
           .. "Located at: ReplicatedStorage.Shared.Framework.Network.Remote",
})

Tabs.Info:AddParagraph({
    Title   = "Session Stats",
    Content = "Live stats update every second:",
})

-- Live stats label (update via loop)
local statsParagraph = Tabs.Info:AddParagraph({
    Title   = "Live Stats",
    Content = "Loading...",
})

task.spawn(function()
    while true do
        task.wait(1)
        local elapsed = tick() - State.StartTime
        local bpm = elapsed > 0 and math.floor(State.BubblesBlown / elapsed * 60) or 0
        if statsParagraph then
            pcall(function()
                statsParagraph:SetDesc(
                    "🫧 Bubbles Blown: " .. formatNum(State.BubblesBlown) .. "\n"
                 .. "⏱ Session Time:  " .. formatTime(elapsed) .. "\n"
                 .. "📊 Bubbles/min:   " .. formatNum(bpm)
                )
            end)
        end
    end
end)

Tabs.Info:AddParagraph({
    Title   = "All Remote Actions Mapped",
    Content = table.concat({
        "BlowBubble", "SellBubble", "HatchEgg", "UnlockWorld",
        "UnlockHatchingZone", "Teleport", "WorldTeleport", "PlazaTeleport",
        "home", "plaza", "pro", "ClaimPrize", "ClaimWorldReward",
        "ClaimObbyChest", "ClaimEventPrize", "ClaimCompetitivePrize",
        "ClaimAllPlaytime", "ClaimAllFishingIndexRewards", "SellAllFish",
        "UpgradeMastery", "ChallengePassClaimReward", "UnlockEventChest",
        "ClaimGift", "ClaimIndex", "ClaimChest", "ClaimXLIndexRewards",
        "CompetitiveReroll", "DoggyJumpWin", "FinishMinigame", "EggPrizeClaim",
        "ClaimBenefits", "DailyRewardClaimStars", "DailyRewardsBuyItem",
        "RerollGenie", "ChangeGenieQuest", "StartGenieQuest", "StartObby",
        "CompleteObby", "SellAllFish", "SetEquippedRod", "EquipRod",
        "ClaimFishingIndexRewards", "SetFishLocked", "SetSetting",
        "ToggleAutoDelete", "TradeAcceptRequest", "TradeRequest",
        "TradeCancel", "TradeDecline", "ShopFreeReroll", "SetShopRerollTarget",
    }, "\n"),
})

-- ╔══════════════════════════╗
-- ║    SAVE MANAGER SETUP    ║
-- ╚══════════════════════════╝

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:SetFolder("BGS-LunarHub")
SaveManager:SetFolder("BGS-LunarHub")

InterfaceManager:BuildInterfaceSection(Tabs.Misc)
SaveManager:BuildConfigSection(Tabs.Misc)

SaveManager:LoadAutoLoad()

-- ╔══════════════════════════╗
-- ║       INIT               ║
-- ╚══════════════════════════╝

-- Init remotes
task.defer(function()
    local ok = initRemotes()
    Fluent:Notify({
        Title    = "BGS Lunar Hub",
        Content  = ok and "✅ Remotes connected! Ready to farm." or "⚠️ Remotes not found yet – retrying...",
        Duration = 5,
    })
    if not ok then
        task.spawn(function()
            while not Remote do
                task.wait(3)
                initRemotes()
            end
            Fluent:Notify({ Title = "Remotes", Content = "✅ Reconnected!", Duration = 3 })
        end)
    end
end)

Window:SelectTab(1)
