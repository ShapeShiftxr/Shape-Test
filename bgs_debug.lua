--[[
================================================================================
   BGS INFINITY -- LUNAR HUB  v7.0  AIO
   12 Tabs | Auto Rejoin | Rift TP | Priority System | Webhook
   Vollstaendig dynamisch -- alle Daten live aus ReplicatedStorage
================================================================================
]]

-- -----------------------------------------------------------
--  PRE-LOAD GUARD
-- -----------------------------------------------------------
if not game:IsLoaded() then game.Loaded:Wait() end

-- -----------------------------------------------------------
--  RAYFIELD
-- -----------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
print("[BGS] 1/10 Rayfield geladen")

-- -----------------------------------------------------------
--  SERVICES
-- -----------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer
local PLACE_ID          = game.PlaceId

-- -----------------------------------------------------------
--  REMOTE SETUP
--  BGS nutzt ein Remote-Wrapper-Modul:
--    module.FireServer(self, actionName, ...)
--      -> RemoteEvent:FireServer(actionName, ...)
--    Teleport: fire("Teleport", part:GetFullName())
-- -----------------------------------------------------------
local RE, RF

local function fire(action, ...)
    if RE then
        pcall(function() RE:FireServer(action, ...) end)
    end
end

local function initRemotes()
    local ok, mod = pcall(function()
        return ReplicatedStorage
            :WaitForChild("Shared", 10)
            :WaitForChild("Framework", 10)
            :WaitForChild("Network", 10)
            :WaitForChild("Remote", 10)
    end)
    if ok and mod then
        RE = mod:FindFirstChild("RemoteEvent")
        RF = mod:FindFirstChild("RemoteFunction")
        return RE ~= nil
    end
    return false
end

-- -----------------------------------------------------------
--  LIVE DATA AUS REPLICATEDSTORAGE
-- -----------------------------------------------------------
local Shared = ReplicatedStorage:WaitForChild("Shared", 15)
local Data   = Shared and Shared:WaitForChild("Data", 15)

local function safeRequire(inst)
    if not inst then return {} end
    local ok, r = pcall(require, inst)
    return ok and type(r) == "table" and r or {}
end

local function safeGet(parent, name)
    return parent:FindFirstChild(name)
end

print("[BGS] 2/10 ReplicatedStorage verbunden")
if not Data then
    warn("[BGS Hub] ReplicatedStorage.Shared.Data nicht gefunden - bist du im Spiel?")
    return
end

local D = {
    Rifts       = safeRequire(safeGet(Data, "Rifts")),
    Potions     = safeRequire(safeGet(Data, "Potions")),
    Powerups    = safeRequire(safeGet(Data, "Powerups")),
    Worlds      = safeRequire(safeGet(Data, "Worlds")),
    Minigames   = safeRequire(safeGet(Data, "Minigames")),
    Obbys       = safeRequire(safeGet(Data, "Obbys")),
    Chests      = safeRequire(safeGet(Data, "Chests")),
    Codes       = safeRequire(safeGet(Data, "Codes")),
    FishingRods = safeRequire(safeGet(Data, "FishingRods")),
    FishingBait = safeRequire(safeGet(Data, "FishingBait")),
    Events      = safeRequire(safeGet(Data, "Events")),
    Enchants    = safeRequire(safeGet(Data, "Enchants")),
    Currency    = safeRequire(safeGet(Data, "Currency")),
    Shops       = safeRequire(safeGet(Data, "Shops")),
    WheelSpin   = safeRequire(safeGet(Data, "WheelSpin")),
}

local function tableKeys(t)
    local l={}; for k in pairs(t) do l[#l+1]=k end; table.sort(l); return l
end

print("[BGS] 3/10 Data Module geladen")
local CODES = tableKeys(D.Codes)

-- Workspace Sell-Positionen (extrahiert aus Gamedatei)
local SELL_POSITIONS = {
    ["Overworld"]  = Vector3.new(77.6,   6.2,    -113.1),
    ["Twilight"]   = Vector3.new(-70.4,  6859.5,  116.5),
    ["Minigames"]  = Vector3.new(9921.7, 23.7,    137.8),
}

-- Island Height-Map faer TP
local ISLAND_HEIGHTS = {
    ["Floating Island"] = 450,
    ["Outer Space"]     = 2500,
    ["Twilight"]        = 6500,
    ["The Void"]        = 9500,
    ["Zen"]             = 15000,
}

-- -----------------------------------------------------------
--  CONFIG (zentral)
-- -----------------------------------------------------------
local CFG = {
    -- Tab 1: Stats
    StatsInterval    = 1,
    -- Tab 2: Trade
    TradeTarget      = "",
    AutoTrade        = false,
    -- Tab 3: Eggs & Rifts
    SelectedEgg      = "Common Egg",
    AutoHatch        = false,
    HatchInterval    = 0.1,
    AutoRift         = false,
    RiftDelay        = 0.0,
    RiftPriority     = {},         -- geordnete egg-prioritaet
    AutoOpenRift     = true,
    RiftMultiEggs    = {},         -- mehrere eggs die beim rift gehatcht werden
    AutoBlowBubble   = false,
    AutoSellBubble   = false,
    SellWorld        = "Twilight",
    -- Tab 4: Enchant
    AutoEnchant      = false,
    UseShadowCrystal = false,
    TargetEnchant    = "team-up",
    -- Tab 5: Potions
    -- Tab 6: Genie
    GenieTarget      = "",
    AutoGenie        = false,
    GenieRerollSec   = 4,
    -- Tab 7: Fishing
    AutoFish         = false,
    SelectedBait     = "Normal Bait",
    SelectedRod      = "Wooden Rod",
    -- Tab 8: Minigames
    MiniDifficulty   = "Normal",
    UseSuper         = true,
    -- Tab 9: Board
    AutoDice         = false,
    TargetField      = "",
    GoldenThreshold  = 3,
    -- Tab 10: Shops
    AutoShop         = false,
    SelectedShops    = {},
    -- Tab 11: Misc
    AutoSpin         = false,
    SelectedSpins    = {},
    AutoGiftBox      = false,
    -- Tab 12: Webhook
    WebhookURL       = "",
    WebhookMinChance = 0.1,
    AlwaysSecret     = true,
    NeverBelow       = 1.0,
    -- Rejoin
    AutoRejoin       = false,
    RejoinMin        = 50,
    RejoinMax        = 80,
    -- Speed
    WalkSpeedOn      = false,
    WalkSpeed        = 32,
    JumpPowerOn      = false,
    JumpPower        = 80,
    InfJump          = false,
    Noclip           = false,
    FlyOn            = false,
    FlySpeed         = 60,
    -- Misc
    AntiAFK          = true,
    ESPOn            = false,
    CodeDelay        = 1.0,
}

-- -----------------------------------------------------------
--  STATE
-- -----------------------------------------------------------
local State = {
    StartTime      = tick(),
    BubblesBlown   = 0,
    EggsHatched    = 0,
    LastSellTime   = 0,
    -- Faer Stats (pro Minute)
    BubbleTimes    = {},
    EggTimes       = {},
    -- Fly
    FlyBV = nil, FlyBG = nil,
    -- ESP
    ESPBoxes = {},
    -- Rejoin
    isTeleporting  = false,
    -- Rift
    activeRift     = nil,
    lastRiftTime   = 0,
}

-- -----------------------------------------------------------
--  UTILITIES
-- -----------------------------------------------------------
local function notify(title, content, dur)
    Rayfield:Notify({ Title=title, Content=content, Duration=dur or 3, Image=4483362458 })
end

local function formatNum(n)
    if n>=1e12 then return ("%.2fT"):format(n/1e12)
    elseif n>=1e9  then return ("%.2fB"):format(n/1e9)
    elseif n>=1e6  then return ("%.2fM"):format(n/1e6)
    elseif n>=1e3  then return ("%.1fK"):format(n/1e3)
    else return tostring(math.floor(n)) end
end

local function formatTime(s)
    local h=math.floor(s/3600); local m=math.floor((s%3600)/60); local sec=math.floor(s%60)
    if h>0 then return h.."h "..m.."m" elseif m>0 then return m.."m "..sec.."s" else return sec.."s" end
end

local function getHum()  local c=LocalPlayer.Character; return c and c:FindFirstChild("Humanoid") end
local function getRoot() local c=LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- Berechne /min aus Zeit-Array (letzten 60s)
local function perMin(times)
    local now = tick()
    -- entferne alte Eintraege
    local fresh = {}
    for _, t in ipairs(times) do
        if now - t <= 60 then fresh[#fresh+1] = t end
    end
    return #fresh, fresh
end

local function recordEvent(arr)
    arr[#arr+1] = tick()
    if #arr > 1000 then table.remove(arr, 1) end
end

-- Teleport zu Position
local function tpTo(pos)
    local root = getRoot()
    if root and pos then root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end

-- Finde ein Part im Workspace via Pfad-Fragment
local function findWorkspacePart(...)
    local obj = Workspace
    for _, name in ipairs({...}) do
        obj = obj:FindFirstChild(name, true)
        if not obj then return nil end
    end
    return obj
end

-- Holt Position eines Models
local function modelPos(m)
    if not m then return nil end
    if m.PrimaryPart then return m.PrimaryPart.Position end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then return d.Position end
    end
    return nil
end

-- -----------------------------------------------------------
--  AUTO REJOIN
-- -----------------------------------------------------------
local function joinSmallServer()
    if State.isTeleporting then return end
    State.isTeleporting = true
    notify("Rejoin", "Suche kleinen Server...", 5)
    task.wait(3)

    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)

    if ok and result and result.data then
        for _, srv in ipairs(result.data) do
            if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(PLACE_ID, srv.id, LocalPlayer)
                task.wait(10)
                State.isTeleporting = false
                return
            end
        end
    end

    TeleportService:Teleport(PLACE_ID, LocalPlayer)
    State.isTeleporting = false
end

-- Error Prompt Detection (disconnect)
task.spawn(function()
    local ok, overlay = pcall(function()
        return CoreGui:WaitForChild("RobloxPromptGui", 10):WaitForChild("promptOverlay", 10)
    end)
    if not ok or not overlay then return end
    overlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" and CFG.AutoRejoin then
            warn("Disconnect erkannt -> Rejoin!")
            joinSmallServer()
        end
    end)
end)

-- Geplanter Rejoin Loop
task.spawn(function()
    while true do
        local mins = math.random(CFG.RejoinMin, CFG.RejoinMax)
        task.wait(mins * 60)
        if CFG.AutoRejoin then
            joinSmallServer()
        end
    end
end)

-- -----------------------------------------------------------
--  AUTO BLOW & SELL BUBBLE
--  BlowBubble() ae kein separates SellBubble naetig (server-side)
--  Aber: SellBubble ist ein eigenes Remote faer manuelles Sell
-- -----------------------------------------------------------
local BLOW_INTERVAL = 0.05
local lastBlow = 0
local lastSell = 0
local SELL_INTERVAL = 5  -- Sell alle 5s wenn Auto Sell an

-- -----------------------------------------------------------
--  RIFT SYSTEM
--  Workspace.Rendered.Rifts enthaelt live Rift-Instanzen
--  Data.Rifts[riftName].Egg = EggName
--  Workspace.Rendered.Generic:FindFirstChild(eggName) = Egg-Modell
-- -----------------------------------------------------------

-- Egg-Rifts aus Data.Rifts (Type=="Egg")
local function getEggRifts()
    local list = {}
    for rn, rd in pairs(D.Rifts) do
        if type(rd)=="table" and rd.Type=="Egg" and rd.Egg then
            list[#list+1] = { rift=rn, egg=rd.Egg, weight=rd.Weight or 1 }
        end
    end
    table.sort(list, function(a,b) return a.rift < b.rift end)
    return list
end

local EGG_RIFTS = getEggRifts()

-- Alle Egg-Namen faer Dropdown
local function getAllEggNames()
    local seen = {}
    local list = {}
    -- Erst aus Rifts
    for _, r in ipairs(EGG_RIFTS) do
        if not seen[r.egg] then seen[r.egg]=true; list[#list+1]=r.egg end
    end
    -- Dann aus Powerups
    for name, data in pairs(D.Powerups) do
        if type(data)=="table" and data.Type=="Egg" and not seen[name] then
            seen[name]=true; list[#list+1]=name
        end
    end
    -- Dann aus Workspace live
    local generic = Workspace:FindFirstChild("Rendered") and Workspace.Rendered:FindFirstChild("Generic")
    if generic then
        for _, child in ipairs(generic:GetChildren()) do
            if child:IsA("Model") and child.Name:find("Egg") and not seen[child.Name] then
                seen[child.Name]=true; list[#list+1]=child.Name
            end
        end
    end
    if #list == 0 then list = {"Common Egg"} end
    table.sort(list)
    return list
end

print("[BGS] 4/10 Egg-Listen erstellt")
local ALL_EGGS = getAllEggNames()
print("[BGS] 5/10 " .. #ALL_EGGS .. " Eggs gefunden")

-- Finde aktiven Rift im Workspace
local function findRiftInWS(riftName)
    local folder = Workspace:FindFirstChild("Rendered") and Workspace.Rendered:FindFirstChild("Rifts")
    if not folder then return nil end
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == riftName or child:GetAttribute("RiftId") == riftName then
            return child
        end
    end
    return nil
end

-- Finde Egg im Workspace
local function findEggInWS(eggName)
    local generic = Workspace:FindFirstChild("Rendered") and Workspace.Rendered:FindFirstChild("Generic")
    if generic then return generic:FindFirstChild(eggName) end
    return nil
end

-- Waehle bestes Egg basierend auf Prioritaetsliste
local function selectBestEgg(availableRifts)
    -- Wenn Prioritaetsliste aktiv
    for _, priorityEgg in ipairs(CFG.RiftPriority) do
        for _, r in ipairs(availableRifts) do
            if r.egg == priorityEgg then return r end
        end
    end
    -- Fallback: hoechstes Weight (=haeufigster Multi)
    local best = nil
    for _, r in ipairs(availableRifts) do
        if not best or (r.weight or 1) > (best.weight or 1) then best = r end
    end
    return best
end

-- TP zu Rift + Egg + Hatch
local function doRiftTP(riftEntry)
    if not riftEntry then return end
    local eggName = riftEntry.egg

    task.wait(CFG.RiftDelay)

    -- TP zu Rift
    local riftModel = findRiftInWS(riftEntry.rift)
    if riftModel then
        local pos = modelPos(riftModel)
        if pos then tpTo(pos); task.wait(0.3) end
    end

    -- TP zu Egg
    local eggModel = findEggInWS(eggName)
    if eggModel then
        local pos = modelPos(eggModel)
        if pos then tpTo(pos); task.wait(0.2) end
    end

    -- Hatche (alle ausgewaehlten eggs beim rift)
    if #CFG.RiftMultiEggs > 0 then
        for _, egg in ipairs(CFG.RiftMultiEggs) do
            fire("HatchEgg", egg, 1)
            task.wait(0.05)
        end
    else
        fire("HatchEgg", eggName, 1)
    end

    -- aeffne Rift wenn in der Naehe
    if CFG.AutoOpenRift and riftModel then
        fire("ClaimChest", riftEntry.rift, true)
    end

    recordEvent(State.EggTimes)
    State.EggsHatched = State.EggsHatched + 1
    notify("Rift", riftEntry.rift.." -> "..eggName, 2)
end

-- Rift Spawn Watcher
task.spawn(function()
    while true do
        task.wait(0.5)
        if CFG.AutoRift then
            local riftsFolder = Workspace:FindFirstChild("Rendered")
                and Workspace.Rendered:FindFirstChild("Rifts")
            if riftsFolder then
                local active = {}
                for _, child in ipairs(riftsFolder:GetChildren()) do
                    local riftData = D.Rifts[child.Name]
                    if riftData and riftData.Type == "Egg" and riftData.Egg then
                        active[#active+1] = { rift=child.Name, egg=riftData.Egg, weight=riftData.Weight or 1 }
                    end
                end
                if #active > 0 then
                    local best = selectBestEgg(active)
                    if best and best.rift ~= State.activeRift then
                        State.activeRift = best.rift
                        doRiftTP(best)
                    end
                else
                    State.activeRift = nil
                end
            end
        end
    end
end)

-- -----------------------------------------------------------
--  FLY / NOCLIP / SPEED
-- -----------------------------------------------------------
UserInputService.JumpRequest:Connect(function()
    if CFG.InfJump then local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

RunService.Stepped:Connect(function()
    if CFG.Noclip then
        local char=LocalPlayer.Character
        if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end
end)

local function enableFly()
    local root=getRoot(); if not root then return end
    local h=getHum(); if h then h.PlatformStand=true end
    local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.D=50; bg.Parent=root; State.FlyBG=bg
    local bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.Parent=root; State.FlyBV=bv
    local cam=Workspace.CurrentCamera
    task.spawn(function()
        while CFG.FlyOn and root.Parent do
            local d=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0,1,0) end
            bv.Velocity=d*CFG.FlySpeed; bg.CFrame=cam.CFrame; task.wait()
        end
        if bv and bv.Parent then bv:Destroy() end
        if bg and bg.Parent then bg:Destroy() end
        local hum=getHum(); if hum then hum.PlatformStand=false end
        State.FlyBV=nil; State.FlyBG=nil
    end)
end

local function disableFly()
    if State.FlyBV and State.FlyBV.Parent then State.FlyBV:Destroy() end
    if State.FlyBG and State.FlyBG.Parent then State.FlyBG:Destroy() end
    local h=getHum(); if h then h.PlatformStand=false end
end

-- -----------------------------------------------------------
--  ANTI-AFK
-- -----------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(60)
        if CFG.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
    end
end)

-- -----------------------------------------------------------
--  ESP
-- -----------------------------------------------------------
local function clearESP()
    for _, h in pairs(State.ESPBoxes) do if h and h.Parent then h:Destroy() end end
    State.ESPBoxes = {}
end

-- -----------------------------------------------------------
--  CODES
-- -----------------------------------------------------------
local function redeemCode(code)
    pcall(function() if RE then RE:FireServer("RedeemCode", code) end end)
end
local function redeemAll()
    task.spawn(function()
        for _,c in ipairs(CODES) do redeemCode(c); task.wait(CFG.CodeDelay) end
        notify("Codes","Alle "..#CODES.." versucht!",4)
    end)
end

-- -----------------------------------------------------------
--  WEBHOOK
-- -----------------------------------------------------------
local function sendWebhook(petName, rarity, chance)
    if CFG.WebhookURL == "" then return end
    if CFG.AlwaysSecret and rarity ~= "Secret" then
        if chance > CFG.NeverBelow then return end
        if chance > CFG.WebhookMinChance then return end
    end
    pcall(function()
        HttpService:PostAsync(CFG.WebhookURL, HttpService:JSONEncode({
            content = nil,
            embeds = {{
                title = "[RARE] Seltener Drop!",
                description = "**"..petName.."**\nSeltenheit: "..rarity.."\nChance: "..chance.."%",
                color = rarity == "Secret" and 0xFF00FF or 0xFFD700,
                timestamp = DateTime.now():ToIsoDate(),
            }}
        }), Enum.HttpContentType.ApplicationJson)
    end)
end

-- -----------------------------------------------------------
--  MAIN HEARTBEAT LOOP
-- -----------------------------------------------------------
RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Auto Blow
    if CFG.AutoBlowBubble and (now - lastBlow) >= BLOW_INTERVAL then
        if RE then
            pcall(function() RE:FireServer("BlowBubble") end)
            recordEvent(State.BubbleTimes)
            State.BubblesBlown = State.BubblesBlown + 1
        end
        lastBlow = now
    end

    -- Auto Sell (TP zur Sell-Station + SellBubble)
    if CFG.AutoSellBubble and (now - lastSell) >= SELL_INTERVAL then
        local sellPos = SELL_POSITIONS[CFG.SellWorld]
        if sellPos then tpTo(sellPos) end
        task.wait(0.2)
        fire("SellBubble")
        lastSell = now
    end

    -- Auto Hatch (VirtualInputManager E-Spam)
    if CFG.AutoHatch then
        if RE then pcall(function() RE:FireServer("HatchEgg", CFG.SelectedEgg, 1) end) end
    end

    -- Walk/Jump Speed
    if CFG.WalkSpeedOn then local h=getHum(); if h and h.WalkSpeed~=CFG.WalkSpeed then h.WalkSpeed=CFG.WalkSpeed end end
    if CFG.JumpPowerOn  then local h=getHum(); if h and h.JumpPower~=CFG.JumpPower   then h.JumpPower=CFG.JumpPower   end end

    -- ESP
    if CFG.ESPOn then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if not State.ESPBoxes[player.Name] or not State.ESPBoxes[player.Name].Parent then
                    local sel = Instance.new("SelectionBox")
                    sel.Color3=Color3.fromRGB(255,60,60); sel.LineThickness=0.07
                    sel.SurfaceTransparency=0.75; sel.SurfaceColor3=Color3.fromRGB(255,50,50)
                    sel.Adornee=player.Character; sel.Parent=Workspace
                    State.ESPBoxes[player.Name]=sel
                else
                    State.ESPBoxes[player.Name].Adornee=player.Character
                end
            end
        end
    end
end)

-- -----------------------------------------------------------
--  RAYFIELD WINDOW
-- -----------------------------------------------------------
print("[BGS] 6/10 Starte Window...")
local Window = Rayfield:CreateWindow({
    Name             = "BGS Infinity -- Lunar Hub AIO",
    LoadingTitle     = "BGS Infinity Hub",
    LoadingSubtitle  = "v7.0 AIO | 12 Tabs | Dynamisch | by Lunar",
    ConfigurationSaving = { Enabled=true, FolderName="BGS-LunarHub", FileName="ConfigV7" },
    Discord  = { Enabled=false },
    KeySystem = false,
})

print("[BGS] 7/10 Window erstellt")
local T = {
    Stats    = Window:CreateTab("Stats",      "bar-chart-2"),
    Trade    = Window:CreateTab("Trade",      "arrow-left-right"),
    Eggs     = Window:CreateTab("Eggs/Rifts", "egg"),
    Enchant  = Window:CreateTab("Enchants",   "sparkles"),
    Potions  = Window:CreateTab("Potions",    "flask-conical"),
    Genie    = Window:CreateTab("Genie",      "gem"),
    Fishing  = Window:CreateTab("Fishing",    "fish"),
    Mini     = Window:CreateTab("Minigames",  "gamepad-2"),
    Board    = Window:CreateTab("Game Board", "dice-5"),
    Shops    = Window:CreateTab("Shops",      "shopping-cart"),
    Misc     = Window:CreateTab("Misc",       "settings"),
    Webhook  = Window:CreateTab("Webhook",    "bell"),
}

-- --------------------------------------
--  TAB 1: LIVE STATS
-- --------------------------------------
T.Stats:CreateSection("Auto Farm")
T.Stats:CreateToggle({ Name="Auto Blow Bubble", CurrentValue=false, Flag="AutoBlow",
    Callback=function(v) CFG.AutoBlowBubble=v end })

T.Stats:CreateToggle({ Name="Auto Sell Bubble (TP zur Sell-Station)", CurrentValue=false, Flag="AutoSell",
    Callback=function(v) CFG.AutoSellBubble=v end })

T.Stats:CreateDropdown({ Name="Sell-World", Options={"Overworld","Twilight","Minigames"},
    CurrentOption={"Twilight"}, Flag="SellWorld",
    Callback=function(v) CFG.SellWorld=type(v)=="table" and v[1] or v end })

T.Stats:CreateSection("Live Stats")
T.Stats:CreateLabel("Update-Intervall (Sekunden):")
T.Stats:CreateSlider({ Name="Update-Intervall", Range={1,60}, Increment=1, CurrentValue=1, Flag="StatsInterval",
    Callback=function(v) CFG.StatsInterval=v end })

-- Stats Labels (dynamisch aktualisiert)
-- Rayfield Paragraphs haben :Set() support
local lbl = {
    bpm     = T.Stats:CreateParagraph({ Title="Bubbles/min",  Content="..." }),
    epm     = T.Stats:CreateParagraph({ Title="Eggs/min",     Content="..." }),
    total_b = T.Stats:CreateParagraph({ Title="Bubbles",      Content="..." }),
    total_e = T.Stats:CreateParagraph({ Title="Eggs",         Content="..." }),
    uptime  = T.Stats:CreateParagraph({ Title="Uptime",       Content="..." }),
    coins   = T.Stats:CreateParagraph({ Title="Coins",        Content="..." }),
    gems    = T.Stats:CreateParagraph({ Title="Gems",         Content="..." }),
    tickets = T.Stats:CreateParagraph({ Title="Tickets",      Content="..." }),
}

T.Stats:CreateSection("Rejoin")
T.Stats:CreateToggle({ Name="Auto Rejoin (zufaellig)", CurrentValue=false, Flag="AutoRejoin",
    Callback=function(v) CFG.AutoRejoin=v end })
T.Stats:CreateSlider({ Name="Rejoin Min (Min.)", Range={10,120}, Increment=5, CurrentValue=50, Flag="RejoinMin",
    Callback=function(v) CFG.RejoinMin=v end })
T.Stats:CreateSlider({ Name="Rejoin Max (Min.)", Range={10,120}, Increment=5, CurrentValue=80, Flag="RejoinMax",
    Callback=function(v) CFG.RejoinMax=v end })
T.Stats:CreateButton({ Name="Jetzt Rejoin", Callback=function() task.spawn(joinSmallServer) end })

-- Stats Update Loop
task.spawn(function()
    while true do
        task.wait(CFG.StatsInterval)
        local now  = tick()
        local up   = formatTime(now - State.StartTime)
        local bMin, freshB = perMin(State.BubbleTimes); State.BubbleTimes=freshB
        local eMin, freshE = perMin(State.EggTimes);    State.EggTimes=freshE

        pcall(function()
            lbl.bpm:Set({ Title="Bubbles/min", Content=formatNum(bMin).."/min" })
            lbl.epm:Set({ Title="Eggs/min", Content=formatNum(eMin).."/min" })
            lbl.total_b:Set({ Title="Bubbles", Content=formatNum(State.BubblesBlown) })
            lbl.total_e:Set({ Title="Eggs", Content=formatNum(State.EggsHatched) })
            lbl.uptime:Set({ Title="Uptime", Content=up })

            -- Waehrungen aus LocalPlayer Stats
            pcall(function()
                local playerGui = LocalPlayer.PlayerGui
                local screenGui = playerGui:FindFirstChild("ScreenGui")
                if screenGui then
                    local coins = screenGui:FindFirstChild("Coins", true)
                    if coins and coins:IsA("TextLabel") then
                        lbl.coins:Set({ Title="Coins", Content="(live)" })
                    end
                end
            end)
        end)
    end
end)

-- --------------------------------------
--  TAB 2: TRADE SPAM
-- --------------------------------------
T.Trade:CreateSection("Trade Spam")
T.Trade:CreateLabel("Schickt automatisch Trade-Anfragen an einen Spieler")
T.Trade:CreateInput({ Name="Spielername (exakt)", PlaceholderText="Username eingeben...", Flag="TradeTarget",
    Callback=function(v) CFG.TradeTarget=v end })
T.Trade:CreateToggle({ Name="Auto Trade Spam", CurrentValue=false, Flag="AutoTrade",
    Callback=function(v)
        CFG.AutoTrade=v
        if v then
            task.spawn(function()
                while CFG.AutoTrade do
                    if CFG.TradeTarget ~= "" then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.Name:lower() == CFG.TradeTarget:lower() then
                                fire("TradeRequest", p)
                                break
                            end
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end })
T.Trade:CreateButton({ Name="Einmalig Trade senden", Callback=function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == CFG.TradeTarget:lower() then
            fire("TradeRequest", p)
            notify("Trade","Anfrage gesendet: "..p.Name,2)
            return
        end
    end
    notify("Trade","Spieler nicht gefunden: "..CFG.TradeTarget,3)
end })

T.Trade:CreateSection("Trade Einstellungen")
T.Trade:CreateButton({ Name="Alle Trades erlauben",   Callback=function() fire("TradeSetRequestsAllowed", true) end })
T.Trade:CreateButton({ Name="Alle Trades blockieren", Callback=function() fire("TradeSetRequestsAllowed", false) end })
T.Trade:CreateButton({ Name="Trade annehmen",         Callback=function() fire("TradeAcceptRequest") end })
T.Trade:CreateButton({ Name="Trade abbrechen",        Callback=function() fire("TradeCancel") end })

-- --------------------------------------
--  TAB 3: EGGS & RIFTS
-- --------------------------------------

-- Egg Section
T.Eggs:CreateSection("Auto Hatch")

T.Eggs:CreateDropdown({
    Name="Egg auswaehlen (Dropdown)", Options=ALL_EGGS,
    CurrentOption={ALL_EGGS[1] or "Common Egg"}, Flag="SelectedEgg",
    Callback=function(v) CFG.SelectedEgg=type(v)=="table" and v[1] or v end,
})

T.Eggs:CreateToggle({ Name="Auto Hatch (100ms Loop)", CurrentValue=false, Flag="AutoHatchToggle",
    Callback=function(v)
        CFG.AutoHatch=v
        if v then
            task.spawn(function()
                while CFG.AutoHatch do
                    fire("HatchEgg", CFG.SelectedEgg, 1)
                    recordEvent(State.EggTimes)
                    State.EggsHatched = State.EggsHatched + 1
                    task.wait(0.1)
                end
            end)
        end
    end })

T.Eggs:CreateButton({ Name="Einmalig Hatch", Callback=function()
    fire("HatchEgg", CFG.SelectedEgg, 1)
    notify("Egg",CFG.SelectedEgg.." OK",2)
end })

-- Rift Section
T.Eggs:CreateSection("Rift Auto-TP")
T.Eggs:CreateLabel("Wenn ein Rift spawnt -> sofort TP + Hatch")

-- Verzoegerung
T.Eggs:CreateSlider({ Name="TP Verzoegerung (Sek.)", Range={0,2}, Increment=0.1, CurrentValue=0, Flag="RiftDelay",
    Callback=function(v) CFG.RiftDelay=v end })

-- Multi-Egg Dropdown (mehrere Eggs beim Rift hatchen)
T.Eggs:CreateDropdown({
    Name="Rift Multi-Eggs (mehrere Auswahl)", Options=ALL_EGGS,
    CurrentOption={ALL_EGGS[1]}, Flag="RiftMultiEggs",
    Callback=function(v) CFG.RiftMultiEggs=type(v)=="table" and v or {v} end,
})

-- Prioritaetsliste
T.Eggs:CreateDropdown({
    Name="Prioritaets-Reihenfolge (oben = hoechste)", Options=ALL_EGGS,
    CurrentOption={ALL_EGGS[1]}, Flag="RiftPriority",
    Callback=function(v) CFG.RiftPriority=type(v)=="table" and v or {v} end,
})

T.Eggs:CreateToggle({ Name="Prioritaet aktiv", CurrentValue=false, Flag="PriorityActive",
    Callback=function(v) -- nur ein Marker, wird in selectBestEgg genutzt
    end })

T.Eggs:CreateToggle({ Name="Auto Rift TP + Hatch", CurrentValue=false, Flag="AutoRift",
    Callback=function(v) CFG.AutoRift=v end })

T.Eggs:CreateToggle({ Name="Rift aeffnen wenn in der Naehe", CurrentValue=true, Flag="AutoOpenRift",
    Callback=function(v) CFG.AutoOpenRift=v end })

-- Alle Rift-Typen (Egg-Rifts einzeln)
T.Eggs:CreateSection("Egg Rifts ("..#EGG_RIFTS..")")
for _, r in ipairs(EGG_RIFTS) do
    local rn=r.rift; local en=r.egg
    T.Eggs:CreateButton({ Name=r.rift.." -> "..r.egg, Callback=function() doRiftTP(r) end })
end

-- Rift Spawn & Open
T.Eggs:CreateSection("Rift Spawnen & aeffnen")
T.Eggs:CreateButton({ Name="RiftSummon (ae5)", Callback=function()
    task.spawn(function() for i=1,5 do fire("RiftSummon"); task.wait(0.3) end end)
    notify("Rift","RiftSummon ae5 OK",2)
end })
T.Eggs:CreateButton({ Name="MoonSummon (ae5)", Callback=function()
    task.spawn(function() for i=1,5 do fire("MoonSummon"); task.wait(0.3) end end)
    notify("Rift","MoonSummon ae5 OK",2)
end })

-- Rifts nach Typ (Chest/Gift)
local nonEggRifts = {}
for rn, rd in pairs(D.Rifts) do
    if type(rd)=="table" and rd.Type ~= "Egg" then nonEggRifts[#nonEggRifts+1]=rn end
end
table.sort(nonEggRifts)
if #nonEggRifts > 0 then
    T.Eggs:CreateSection("Chest & Gift Rifts")
    for _, rn in ipairs(nonEggRifts) do
        local r=rn; local rd=D.Rifts[rn]
        local dname=(rd and rd.DisplayName) or rn
        T.Eggs:CreateButton({ Name=dname, Callback=function()
            if rd and rd.Type=="Chest" then fire("ClaimChest",dname,true)
            else fire("ClaimGift") end
            notify("Rift",dname.." OK",2)
        end })
    end
end

-- --------------------------------------
--  TAB 4: ENCHANTS
-- --------------------------------------
local ENCHANT_LIST = tableKeys(D.Enchants)
if #ENCHANT_LIST == 0 then ENCHANT_LIST = {"team-up","super-luck","secret-hunter","shiny-seeker"} end

T.Enchant:CreateSection("Auto Enchant")
T.Enchant:CreateLabel("Enchanted Pets via ClaimPrize - nutzt Gems oder Shadow Crystals")

T.Enchant:CreateDropdown({ Name="Ziel-Enchant", Options=ENCHANT_LIST,
    CurrentOption={ENCHANT_LIST[1]}, Flag="TargetEnchant",
    Callback=function(v) CFG.TargetEnchant=type(v)=="table" and v[1] or v end })

T.Enchant:CreateToggle({ Name="Shadow Crystal verwenden (statt Gems)", CurrentValue=false, Flag="UseShadow",
    Callback=function(v) CFG.UseShadowCrystal=v end })

T.Enchant:CreateLabel("Shadow Crystal = garantiert Secret Enchant auf Secret Pets")

T.Enchant:CreateToggle({ Name="Auto Enchant (bis Ziel-Team voll)", CurrentValue=false, Flag="AutoEnchant",
    Callback=function(v)
        CFG.AutoEnchant=v
        if v then
            task.spawn(function()
                while CFG.AutoEnchant do
                    -- Enchant via UseItem
                    if CFG.UseShadowCrystal then
                        fire("UseItem", "Shadow Crystal")
                    else
                        fire("UseItem", "Enchant Stone")
                    end
                    task.wait(0.5)
                    -- Claim result
                    fire("ClaimPrize", CFG.TargetEnchant)
                    task.wait(0.5)
                end
            end)
        end
    end })

T.Enchant:CreateSection("Einzelne Enchants")
for _, e in ipairs(ENCHANT_LIST) do
    local en=e
    T.Enchant:CreateButton({ Name=e, Callback=function()
        fire("UseItem", "Enchant Stone")
        task.wait(0.3)
        fire("ClaimPrize", en)
        notify("Enchant",en.." OK",2)
    end })
end

-- --------------------------------------
--  TAB 5: POTIONS
-- CraftPotion(name, level, fromInventory=true)
-- --------------------------------------

-- Potions sortiert nach Prioritaet
local POT_PRIORITY = {
    -- Standard Lv7
    {name="Lucky",  level=7, special=false},
    {name="Mythic", level=7, special=false},
    {name="Speed",  level=7, special=false},
    {name="Coins",  level=7, special=false},
    -- Special Elixiere
    {name="Secret Elixir",           level=1, special=true},
    {name="Infinity Elixir",         level=1, special=true},
    {name="Egg Elixir",              level=1, special=true},
    {name="Ultra Infinity Elixir",   level=1, special=true},
    {name="Lunar New Years Lantern", level=1, special=true},
    -- Standard Lv6
    {name="Lucky",  level=6, special=false},
    {name="Mythic", level=6, special=false},
    {name="Speed",  level=6, special=false},
    {name="Coins",  level=6, special=false},
    -- Standard Lv5
    {name="Lucky",  level=5, special=false},
    {name="Mythic", level=5, special=false},
    {name="Speed",  level=5, special=false},
    {name="Coins",  level=5, special=false},
}

-- Faege restliche Elixiere dynamisch hinzu
for potName, potData in pairs(D.Potions) do
    if type(potData)=="table" and potData.OneLevel then
        local found=false
        for _,p in ipairs(POT_PRIORITY) do if p.name==potName then found=true; break end end
        if not found then POT_PRIORITY[#POT_PRIORITY+1]={name=potName,level=1,special=true} end
    end
end

T.Potions:CreateSection("Alle Potions aktivieren")

T.Potions:CreateButton({ Name="[!] ALLE (Prioritaet: beste zuerst)", Callback=function()
    task.spawn(function()
        for _,p in ipairs(POT_PRIORITY) do
            fire("CraftPotion", p.name, p.level, true)
            task.wait(0.2)
        end
        notify("Potions","Alle aktiviert OK",3)
    end)
end })

T.Potions:CreateButton({ Name="Spam ae10 (10x alle)", Callback=function()
    task.spawn(function()
        for rep=1,10 do
            for _,p in ipairs(POT_PRIORITY) do
                fire("CraftPotion", p.name, p.level, true)
                task.wait(0.1)
            end
        end
        notify("Potions","Spam ae10 OK",3)
    end)
end })

-- Beste Potions als einzelne Spam-Buttons
T.Potions:CreateSection("Top Potions ae Spam")

local topPotions = {
    {name="Lucky",  level=7}, {name="Mythic", level=7},
    {name="Speed",  level=7}, {name="Coins",  level=7},
    {name="Secret Elixir",level=1}, {name="Infinity Elixir",level=1},
    {name="Egg Elixir",level=1},
}

for _, p in ipairs(topPotions) do
    local pn=p.name; local pl=p.level
    local label = pn..(pl>1 and " Lv"..pl or "")
    T.Potions:CreateButton({ Name=label.." ae Spam ae10", Callback=function()
        task.spawn(function()
            for i=1,10 do fire("CraftPotion",pn,pl,true); task.wait(0.1) end
        end)
        notify("Potion",label.." ae10 OK",2)
    end })
    T.Potions:CreateButton({ Name=label.." ae Spam ae100", Callback=function()
        task.spawn(function()
            for i=1,10 do
                for j=1,10 do fire("CraftPotion",pn,pl,true); task.wait(0.05) end
                task.wait(0.1)
            end
        end)
        notify("Potion",label.." ae100 OK",2)
    end })
end

-- Special Potions Dropdown
T.Potions:CreateSection("Special Elixiere")
local specialList = {}
for potName, potData in pairs(D.Potions) do
    if type(potData)=="table" and potData.OneLevel then specialList[#specialList+1]=potName end
end
table.sort(specialList)

T.Potions:CreateDropdown({ Name="Elixier auswaehlen", Options=specialList,
    CurrentOption={specialList[1] or "Infinity Elixir"}, Flag="SelectedElixir",
    Callback=function(v)
        local sel=type(v)=="table" and v[1] or v
        fire("CraftPotion", sel, 1, true)
        notify("Elixier",sel.." OK",2)
    end })

-- --------------------------------------
--  TAB 6: GEM GENIE
-- --------------------------------------
T.Genie:CreateSection("Auto Gem Genie")
T.Genie:CreateLabel("Rerollt alle 4s bis gew-nschte Quest erscheint")
T.Genie:CreateLabel("Rerollt mit Reroll Orbs. Falls leer -> Mystery Box")

local GENIE_TASKS = {
    "Hatch 500", "Hatch 1000", "Bubbles 50M", "Bubbles 65M",
    "Collect 500M Coins", "Collect 1B Coins",
    "Hatch 120 Common", "Hatch 75 Rare", "Hatch 25 Epic",
}

T.Genie:CreateDropdown({ Name="Ziel-Quest", Options=GENIE_TASKS,
    CurrentOption={GENIE_TASKS[1]}, Flag="GenieTarget",
    Callback=function(v) CFG.GenieTarget=type(v)=="table" and v[1] or v end })

T.Genie:CreateSlider({ Name="Reroll-Intervall (Sek.)", Range={2,10}, Increment=1, CurrentValue=4, Flag="GenieInterval",
    Callback=function(v) CFG.GenieRerollSec=v end })

T.Genie:CreateToggle({ Name="Auto Genie Reroll", CurrentValue=false, Flag="AutoGenie",
    Callback=function(v)
        CFG.AutoGenie=v
        if v then
            task.spawn(function()
                while CFG.AutoGenie do
                    fire("RerollGenie")
                    task.wait(CFG.GenieRerollSec)
                    -- Waehle Quest wenn verfaegbar (StartGenieQuest mit Index 1-3)
                    -- Hier: versuche alle 3 Slots
                    for i=1,3 do
                        fire("StartGenieQuest", i)
                        task.wait(0.2)
                    end
                end
            end)
        end
    end })

T.Genie:CreateSection("Manuell")
T.Genie:CreateButton({ Name="Reroll (einmalig)",   Callback=function() fire("RerollGenie") end })
T.Genie:CreateButton({ Name="Quest 1 auswaehlen",   Callback=function() fire("StartGenieQuest",1) end })
T.Genie:CreateButton({ Name="Quest 2 auswaehlen",   Callback=function() fire("StartGenieQuest",2) end })
T.Genie:CreateButton({ Name="Quest 3 auswaehlen",   Callback=function() fire("StartGenieQuest",3) end })
T.Genie:CreateButton({ Name="Genie Quest wechseln",Callback=function() fire("ChangeGenieQuest") end })

-- --------------------------------------
--  TAB 7: FISHING (AUTO SAILOR QUEST)
-- --------------------------------------
T.Fishing:CreateSection("Auto Sailor Quest")
T.Fishing:CreateLabel("TP zu Fisher's Island -> Angeln spammen")

local FISHERS_ISLAND_POS = Vector3.new(-23629.1, 4.9, 26.0)  -- aus Workspace

T.Fishing:CreateToggle({ Name="Auto Fish (Sailor Quest)", CurrentValue=false, Flag="AutoFish",
    Callback=function(v)
        CFG.AutoFish=v
        if v then
            task.spawn(function()
                -- TP zu Fisher's Island
                tpTo(FISHERS_ISLAND_POS)
                task.wait(1)
                while CFG.AutoFish do
                    fire("BeginCastCharge")
                    task.wait(0.3)
                    fire("FinishCastCharge")
                    task.wait(1.5)
                    fire("Reel")
                    task.wait(0.5)
                end
            end)
        end
    end })

T.Fishing:CreateSection("Ausraestung")

-- Rod Dropdown
local rodList = tableKeys(D.FishingRods)
T.Fishing:CreateDropdown({ Name="Angel-Rute", Options=rodList,
    CurrentOption={rodList[1] or "Wooden Rod"}, Flag="SelectedRod",
    Callback=function(v)
        local r=type(v)=="table" and v[1] or v
        CFG.SelectedRod=r
        fire("SetEquippedRod",r); fire("EquipRod",r)
        notify("Fishing",r.." OK",2)
    end })

-- Bait Dropdown mit Anzahl (live aus Inventar ae Fallback aus Data)
local baitList = tableKeys(D.FishingBait)
T.Fishing:CreateDropdown({ Name="Kaeder (Equip)", Options=baitList,
    CurrentOption={baitList[1] or "Normal Bait"}, Flag="SelectedBait",
    Callback=function(v)
        local b=type(v)=="table" and v[1] or v
        CFG.SelectedBait=b
        fire("SetEquippedBait",b)
        notify("Fishing",b.." OK",2)
    end })

T.Fishing:CreateSection("Quick Actions")
T.Fishing:CreateButton({ Name="SellAllFish",                   Callback=function() fire("SellAllFish"); notify("Fishing","OK",2) end })
T.Fishing:CreateButton({ Name="ClaimAllFishingIndexRewards",   Callback=function() fire("ClaimAllFishingIndexRewards"); notify("Fishing","OK",2) end })

-- --------------------------------------
--  TAB 8: MINIGAMES
-- --------------------------------------
local DIFFICULTY_OPTIONS = {"Easy","Normal","Hard","Insane"}

T.Mini:CreateSection("Globale Einstellungen")

T.Mini:CreateDropdown({ Name="Schwierigkeitsgrad", Options=DIFFICULTY_OPTIONS,
    CurrentOption={"Normal"}, Flag="MiniDifficulty",
    Callback=function(v) CFG.MiniDifficulty=type(v)=="table" and v[1] or v end })

T.Mini:CreateToggle({ Name="Super Tickets verwenden", CurrentValue=true, Flag="UseSuperTickets",
    Callback=function(v) CFG.UseSuper=v end })

T.Mini:CreateSection("Minigames ae Auto Loop")

for miniName, miniData in pairs(D.Minigames) do
    if type(miniData)=="table" then
        local mn=miniName
        local cd=(miniData.Cooldown or 300)
        T.Mini:CreateSection(miniName.." | Cooldown "..cd.."s")
        if miniData.Description then T.Mini:CreateLabel(miniData.Description) end

        T.Mini:CreateButton({ Name="Finish (einmalig)", Callback=function()
            fire("FinishMinigame"); notify("Mini",mn.." OK",2)
        end })

        T.Mini:CreateButton({ Name="Super Ticket + Finish", Callback=function()
            if CFG.UseSuper then fire("UseItem","Super Ticket"); task.wait(0.5) end
            fire("FinishMinigame"); notify("Mini","Ticket + "..mn.." OK",2)
        end })

        local key = "AutoMini_"..mn
        CFG[key] = false
        T.Mini:CreateToggle({ Name="Auto Loop: "..mn, CurrentValue=false, Flag=key,
            Callback=function(v)
                CFG[key]=v
                if v then
                    task.spawn(function()
                        while CFG[key] do
                            if CFG.UseSuper then fire("UseItem","Super Ticket"); task.wait(0.5) end
                            fire("FinishMinigame")
                            task.wait(CFG.UseSuper and 3 or cd+1)
                        end
                    end)
                end
            end })
    end
end

T.Mini:CreateSection("DoggyJump & Obbys")
T.Mini:CreateButton({ Name="DoggyJumpWin", Callback=function() fire("DoggyJumpWin") end })

for obbyName in pairs(D.Obbys) do
    local d=obbyName
    T.Mini:CreateButton({ Name="Obby: "..obbyName, Callback=function()
        task.spawn(function()
            fire("StartObby",d); task.wait(0.5)
            fire("CompleteObby",d); task.wait(0.3)
            fire("ClaimObbyChest",d)
        end)
        notify("Obby",d.." OK",3)
    end })
end

-- --------------------------------------
--  TAB 9: GAME BOARD
-- --------------------------------------
T.Board:CreateSection("Auto Dice")
T.Board:CreateLabel("Nutzt Dice permanent - Golden Dice wenn 1-5 Felder entfernt")
T.Board:CreateLabel("Groaeer Dice wenn Ziel weit weg - kleinere wenn nah")

-- Felder-Liste (aus Data.Powerups Board-Typ oder manuell)
local BOARD_FIELDS = {
    "Infinity Elixir", "Secret Elixir", "Egg Elixir",
    "Dice Key", "Golden Dice", "Giant Dice",
    "Mystery Box", "Golden Box", "Super Ticket",
    "Evolved Lucky", "Evolved Mythic", "Evolved Speed",
    "Royal Key", "Super Key",
}

T.Board:CreateDropdown({ Name="Ziel-Feld", Options=BOARD_FIELDS,
    CurrentOption={BOARD_FIELDS[1]}, Flag="TargetField",
    Callback=function(v) CFG.TargetField=type(v)=="table" and v[1] or v end })

T.Board:CreateDropdown({ Name="Golden Dice wenn X Felder entfernt", Options={"1","2","3","4","5"},
    CurrentOption={"3"}, Flag="GoldenThreshold",
    Callback=function(v) CFG.GoldenThreshold=tonumber(type(v)=="table" and v[1] or v) or 3 end })

T.Board:CreateToggle({ Name="Auto Dice Spam", CurrentValue=false, Flag="AutoDice",
    Callback=function(v)
        CFG.AutoDice=v
        if v then
            task.spawn(function()
                while CFG.AutoDice do
                    -- Nutze normalen Dice permanent
                    -- Golden Dice wenn nah am Ziel (Logik: fire UseItem)
                    fire("UseItem","Dice")
                    task.wait(0.5)
                    -- Wenn nah: Golden Dice
                    -- (Position-Tracking waerde serverseitig Board-State brauchen)
                    -- Daher: fire UseItem Golden Dice alle CFG.GoldenThreshold Zaege
                    if math.random(1,5) <= CFG.GoldenThreshold then
                        fire("UseItem","Golden Dice")
                        task.wait(0.3)
                    end
                    task.wait(1)
                end
            end)
        end
    end })

T.Board:CreateSection("Manuell")
T.Board:CreateButton({ Name="Dice rollen",       Callback=function() fire("UseItem","Dice") end })
T.Board:CreateButton({ Name="Golden Dice",        Callback=function() fire("UseItem","Golden Dice") end })
T.Board:CreateButton({ Name="Giant Dice",         Callback=function() fire("UseItem","Giant Dice") end })
T.Board:CreateButton({ Name="ae5 Dice Spam",       Callback=function()
    task.spawn(function() for i=1,5 do fire("UseItem","Dice"); task.wait(0.3) end end)
end })

-- --------------------------------------
--  TAB 10: SHOPS
-- --------------------------------------
local SHOP_LIST = tableKeys(D.Shops)

T.Shops:CreateSection("Auto Shop Buy")
T.Shops:CreateLabel("Kauft automatisch ausgew-hlte Shops leer")

T.Shops:CreateDropdown({ Name="Shops auswaehlen", Options=SHOP_LIST,
    CurrentOption={SHOP_LIST[1] or ""}, Flag="SelectedShops",
    Callback=function(v) CFG.SelectedShops=type(v)=="table" and v or {v} end })

T.Shops:CreateButton({ Name="Buy Selected Shops", Callback=function()
    task.spawn(function()
        for _, shopName in ipairs(CFG.SelectedShops) do
            fire("DailyRewardsBuyItem", shopName)
            task.wait(0.3)
        end
        notify("Shop","Alle ausgewaehlten Shops OK",3)
    end)
end })

T.Shops:CreateToggle({ Name="Auto Shop (Loop)", CurrentValue=false, Flag="AutoShop",
    Callback=function(v)
        CFG.AutoShop=v
        if v then
            task.spawn(function()
                while CFG.AutoShop do
                    for _, shopName in ipairs(CFG.SelectedShops) do
                        fire("DailyRewardsBuyItem", shopName)
                        task.wait(0.3)
                    end
                    task.wait(60)
                end
            end)
        end
    end })

T.Shops:CreateSection("Shop Reroll")
T.Shops:CreateButton({ Name="ShopFreeReroll",  Callback=function() fire("ShopFreeReroll") end })

-- --------------------------------------
--  TAB 11: VERSCHIEDENES
-- --------------------------------------

-- Teleport Dropdown (live aus Worlds)
T.Misc:CreateSection("Teleport ae Areas")
local areaList = {"Overworld","Twilight","The Void","Zen","Outer Space","Floating Island",
    "Dice Island","Minecart Forest","Robot Factory","Hyperwave Island",
    "Blizzard Hills","Poison Jungle","Infernite Volcano","Lost Atlantis",
    "Classic Island","Fisher's Island","Dream Island"}

T.Misc:CreateDropdown({ Name="Area auswaehlen", Options=areaList,
    CurrentOption={areaList[1]}, Flag="TeleportArea",
    Callback=function(v)
        local area=type(v)=="table" and v[1] or v
        -- Versuche via WorldTeleport oder Teleport
        local model = Workspace:FindFirstChild(area, true)
        if model then
            local pos = modelPos(model)
            if pos then tpTo(pos); notify("TP","-> "..area,2); return end
        end
        -- Fallback
        fire("WorldTeleport", area)
        notify("TP","-> "..area,2)
    end })

T.Misc:CreateButton({ Name="PlazaTeleport: Home",  Callback=function() fire("PlazaTeleport","home") end })
T.Misc:CreateButton({ Name="PlazaTeleport: Plaza", Callback=function() fire("PlazaTeleport","plaza") end })
T.Misc:CreateButton({ Name="PlazaTeleport: Pro",   Callback=function() fire("PlazaTeleport","pro") end })

-- Spin Wheels
T.Misc:CreateSection("Spin Wheels")
local SPIN_TYPES = {"Spin Ticket","Festival Spin Ticket","OG Spin Ticket",
    "Halloween Spin Ticket","Christmas Spin Ticket","Valentine's Spin Ticket",
    "Lunar Spin Ticket","Admin Spin Ticket"}

T.Misc:CreateDropdown({ Name="Spin Ticket auswaehlen", Options=SPIN_TYPES,
    CurrentOption={SPIN_TYPES[1]}, Flag="SelectedSpins",
    Callback=function(v) CFG.SelectedSpins=type(v)=="table" and v or {v} end })

T.Misc:CreateToggle({ Name="Auto Spin", CurrentValue=false, Flag="AutoSpin",
    Callback=function(v)
        CFG.AutoSpin=v
        if v then
            task.spawn(function()
                while CFG.AutoSpin do
                    for _, ticket in ipairs(CFG.SelectedSpins) do
                        fire("UseItem", ticket); task.wait(0.5)
                    end
                    task.wait(1)
                end
            end)
        end
    end })

-- Gift Boxes
T.Misc:CreateSection("Gift Boxes")
local GIFT_BOXES = {"Mystery Box","Golden Box","Light Box","Shadow Mystery Box",
    "Fall Mystery Box","Spooky Mystery Box","OG Mystery Box",
    "Thanksgiving Mystery Box","Circus Mystery Box","Infinity Mystery Box"}

T.Misc:CreateDropdown({ Name="Gift Box auswaehlen", Options=GIFT_BOXES,
    CurrentOption={GIFT_BOXES[1]}, Flag="SelectedBoxes",
    Callback=function(v) CFG.SelectedBoxes=type(v)=="table" and v or {v} end })

T.Misc:CreateToggle({ Name="Auto Gift Box aeffnen", CurrentValue=false, Flag="AutoGiftBox",
    Callback=function(v)
        CFG.AutoGiftBox=v
        if v then
            task.spawn(function()
                while CFG.AutoGiftBox do
                    local boxes = CFG.SelectedBoxes or {}
                    for _, box in ipairs(boxes) do
                        fire("UseItem", box); task.wait(0.3)
                    end
                    task.wait(0.5)
                end
            end)
        end
    end })

-- Misc Actions
T.Misc:CreateSection("Quick Actions")
T.Misc:CreateButton({ Name="Alle Codes einlaesen", Callback=redeemAll })
T.Misc:CreateButton({ Name="Unlock All Worlds", Callback=function()
    task.spawn(function() for wn in pairs(D.Worlds) do fire("UnlockWorld",wn); task.wait(0.3) end end)
    notify("Unlock","Alle Worlds OK",3)
end })
T.Misc:CreateButton({ Name="Unlock All Hatching Zones", Callback=function()
    task.spawn(function() for i=1,25 do fire("UnlockHatchingZone",i); task.wait(0.1) end end)
    notify("Unlock","HatchZones OK",3)
end })
T.Misc:CreateButton({ Name="ClaimAllPlaytime", Callback=function() fire("ClaimAllPlaytime"); notify("Misc","OK",2) end })
T.Misc:CreateButton({ Name="ChallengePassClaimReward", Callback=function() fire("ChallengePassClaimReward") end })

T.Misc:CreateSection("Player")
T.Misc:CreateToggle({ Name="Anti-AFK", CurrentValue=true, Flag="AntiAFK",
    Callback=function(v) CFG.AntiAFK=v end })
T.Misc:CreateToggle({ Name="Player ESP", CurrentValue=false, Flag="ESP",
    Callback=function(v) CFG.ESPOn=v; if not v then clearESP() end end })

T.Misc:CreateSection("Speed & Fly")
T.Misc:CreateToggle({ Name="Custom Walk Speed", CurrentValue=false, Flag="WalkSpeedOn",
    Callback=function(v) CFG.WalkSpeedOn=v end })
T.Misc:CreateSlider({ Name="Walk Speed", Range={16,300}, Increment=1, CurrentValue=32, Flag="WalkSpeed",
    Callback=function(v) CFG.WalkSpeed=v end })
T.Misc:CreateToggle({ Name="Infinite Jump", CurrentValue=false, Flag="InfJump",
    Callback=function(v) CFG.InfJump=v end })
T.Misc:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="Noclip",
    Callback=function(v) CFG.Noclip=v end })
T.Misc:CreateToggle({ Name="Fly", CurrentValue=false, Flag="FlyOn",
    Callback=function(v) CFG.FlyOn=v; if v then task.defer(enableFly) else disableFly() end end })
T.Misc:CreateSlider({ Name="Fly Speed", Range={10,300}, Increment=1, CurrentValue=60, Flag="FlySpeed",
    Callback=function(v) CFG.FlySpeed=v end })

-- --------------------------------------
--  TAB 12: WEBHOOK
-- --------------------------------------
T.Webhook:CreateSection("Discord Webhook")
T.Webhook:CreateLabel("Sendet Benachrichtigungen bei seltenen Drops")
T.Webhook:CreateLabel("[!] Webhook-URL muss ein HTTPS Discord Webhook sein")

T.Webhook:CreateInput({ Name="Webhook URL", PlaceholderText="https://discord.com/api/webhooks/...",
    Flag="WebhookURL", Callback=function(v) CFG.WebhookURL=v end })

T.Webhook:CreateSlider({ Name="Min. Chance faer Notify (%)", Range={0,5}, Increment=0.01, CurrentValue=0.1,
    Flag="WebhookMin", Callback=function(v) CFG.WebhookMinChance=v end })

T.Webhook:CreateToggle({ Name="Always notify Secrets", CurrentValue=true, Flag="AlwaysSecret",
    Callback=function(v) CFG.AlwaysSecret=v end })

T.Webhook:CreateSlider({ Name="Never notify below Chance (%)", Range={0,10}, Increment=0.1, CurrentValue=1.0,
    Flag="NeverBelow", Callback=function(v) CFG.NeverBelow=v end })

T.Webhook:CreateButton({ Name="Test Webhook senden", Callback=function()
    sendWebhook("Test Pet", "Secret", 0.01)
    notify("Webhook","Test gesendet!",3)
end })

T.Webhook:CreateSection("Info")
T.Webhook:CreateLabel("Webhook wird beim Hatch-Event ausgel-st")
T.Webhook:CreateLabel("HatchEgg Remote -> Server sendet Pet-Daten -> Webhook")

-- -----------------------------------------------------------
--  INIT
-- -----------------------------------------------------------
task.defer(function()
    local ok = initRemotes()
    local cnt = function(t) local n=0 for _ in pairs(t) do n = n + 1 end return n end
    notify(
        "BGS Lunar Hub v7.0 AIO",
        ok
            and ("[OK] "..#EGG_RIFTS.." Egg-Rifts | "..cnt(D.Potions).." Potions | "..#CODES.." Codes | "..#ALL_EGGS.." Eggs")
            or "[!] Remotes noch nicht bereit...",
        6
    )
    if not ok then
        task.spawn(function()
            while not RE do
                task.wait(3)
                if initRemotes() then notify("Remotes","[OK] Verbunden!",3) end
            end
        end)
    end
end)

print("[BGS] 10/10 FERTIG!")
Rayfield:LoadConfiguration()
