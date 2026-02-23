-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║   BGS INFINITY — LUNAR HUB  v6.0  |  Rayfield Edition              ║
-- ║   100% Dynamisch — Daten live aus ReplicatedStorage                 ║
-- ║   Korrekte Rift-TP Logik | Egg Dropdown | Minigame Tickets          ║
-- ╚══════════════════════════════════════════════════════════════════════╝

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ── SERVICES ──
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   REMOTE — wrapper identisch zum Spiel                           ║
-- ║   Remote.FireServer(actionName, ...)                             ║
-- ║     → RemoteEvent:FireServer(actionName, ...)                    ║
-- ╚══════════════════════════════════════════════════════════════════╝

local RE, RF

local function fire(action, ...)
    if RE then RE:FireServer(action, ...) end
end

local function initRemotes()
    local ok, mod = pcall(function()
        return ReplicatedStorage
            :WaitForChild("Shared", 8)
            :WaitForChild("Framework", 8)
            :WaitForChild("Network", 8)
            :WaitForChild("Remote", 8)
    end)
    if ok and mod then
        RE = mod:FindFirstChild("RemoteEvent")
        RF = mod:FindFirstChild("RemoteFunction")
        return RE ~= nil
    end
    return false
end

-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   LIVE DATEN aus ReplicatedStorage                               ║
-- ╚══════════════════════════════════════════════════════════════════╝

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Data   = Shared and Shared:WaitForChild("Data", 30)
if not Data then
    warn("[BGS] Data nicht gefunden!")
    return
end

local function safeRequire(inst)
    local ok, r = pcall(require, inst)
    return ok and r or {}
end

local D = {
    Rifts      = safeRequire(Data.Rifts),
    Potions    = safeRequire(Data.Potions),
    Powerups   = safeRequire(Data.Powerups),
    Worlds     = safeRequire(Data.Worlds),
    Minigames  = safeRequire(Data.Minigames),
    Obbys      = safeRequire(Data.Obbys),
    Chests     = safeRequire(Data.Chests),
    Codes      = safeRequire(Data.Codes),
    FishingRods = safeRequire(Data.FishingRods),
    FishingBait = safeRequire(Data.FishingBait),
    Events     = safeRequire(Data.Events),
}

-- ── Hilfsfunktionen ──
local function tableKeys(t)
    local list = {}
    for k in pairs(t) do table.insert(list, k) end
    table.sort(list)
    return list
end

local function sortedByLayout(t)
    local list = {}
    for k, v in pairs(t) do
        table.insert(list, { name = k, data = type(v)=="table" and v or {} })
    end
    table.sort(list, function(a, b)
        local oa = a.data.LayoutOrder or 9999
        local ob = b.data.LayoutOrder or 9999
        if oa ~= ob then return oa < ob end
        return a.name < b.name
    end)
    return list
end

-- Alle Egg-Rifts (Type=="Egg") aus Data.Rifts
local function getEggRifts()
    local list = {}
    for riftName, riftData in pairs(D.Rifts) do
        if type(riftData)=="table" and riftData.Type == "Egg" and riftData.Egg then
            table.insert(list, { rift = riftName, egg = riftData.Egg, areas = riftData.Areas or {} })
        end
    end
    table.sort(list, function(a,b) return a.rift < b.rift end)
    return list
end

-- Alle Egg-Namen aus Workspace.Rendered.Generic live scannen
local function getLiveEggs()
    local list = {}
    local generic = Workspace:FindFirstChild("Rendered") and Workspace.Rendered:FindFirstChild("Generic")
    if not generic then return list end
    for _, child in ipairs(generic:GetChildren()) do
        if child:IsA("Model") and child.Name:find("Egg") then
            table.insert(list, child.Name)
        end
    end
    table.sort(list)
    return list
end

-- Alle normalen (nicht-Egg) Rift-Namen
local function getNonEggRifts()
    local list = {}
    for riftName, riftData in pairs(D.Rifts) do
        if type(riftData)=="table" and riftData.Type ~= "Egg" then
            table.insert(list, riftName)
        end
    end
    table.sort(list)
    return list
end

-- Codes als Liste
local CODES = tableKeys(D.Codes)

-- ╔══════════════════════════╗
-- ║         CONFIG           ║
-- ╚══════════════════════════╝

local Config = {
    -- Farm
    AutoBlow          = false,
    AutoHatch         = false,
    SelectedEgg       = "Common Egg",
    -- Rift
    AutoRiftTP        = false,
    SelectedRift      = "",
    RiftLoopInterval  = 3,
    -- Speed
    WalkSpeedEnabled  = false,
    WalkSpeed         = 32,
    JumpPowerEnabled  = false,
    JumpPower         = 80,
    InfJumpEnabled    = false,
    NoclipEnabled     = false,
    FlyEnabled        = false,
    FlySpeed          = 60,
    -- Misc
    ESPEnabled        = false,
    AntiAFKEnabled    = true,
    CodeDelay         = 1.0,
}

local State = {
    BubblesBlown = 0,
    StartTime    = tick(),
    FlyBV        = nil,
    FlyBG        = nil,
}

-- ╔══════════════════════════╗
-- ║       UTILITIES          ║
-- ╚══════════════════════════╝

local function notify(title, content, duration)
    Rayfield:Notify({ Title=title, Content=content, Duration=duration or 3, Image=4483362458 })
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
    if h>0 then return h.."h "..m.."m "..sec.."s"
    elseif m>0 then return m.."m "..sec.."s"
    else return sec.."s" end
end

local function getHum()  local c=LocalPlayer.Character; return c and c:FindFirstChild("Humanoid") end
local function getRoot() local c=LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   RIFT TELEPORT LOGIK                                            ║
-- ║                                                                  ║
-- ║   1. Finde Rift-Instanz in Workspace.Rendered.Rifts per Name    ║
-- ║   2. Lese zugehöriges Egg aus Data.Rifts                        ║
-- ║   3. Finde Egg-Modell in Workspace.Rendered.Generic per Name    ║
-- ║   4. Teleportiere zur PrimaryPart/BasePart des Eggs             ║
-- ║   5. Fire HatchEgg mit dem Egg-Namen                            ║
-- ╚══════════════════════════════════════════════════════════════════╝

local function findRiftInWorkspace(riftName)
    local riftsFolder = Workspace:FindFirstChild("Rendered")
        and Workspace.Rendered:FindFirstChild("Rifts")
    if not riftsFolder then return nil end
    -- Rifts können direkte Kinder ODER als Attribute benannt sein
    for _, child in ipairs(riftsFolder:GetChildren()) do
        if child.Name == riftName then return child end
        -- Manche Rifts haben den Namen als Attribut
        if child:GetAttribute("RiftId") == riftName then return child end
    end
    return nil
end

local function findEggInWorkspace(eggName)
    local generic = Workspace:FindFirstChild("Rendered")
        and Workspace.Rendered:FindFirstChild("Generic")
    if not generic then return nil end
    return generic:FindFirstChild(eggName)
end

local function getModelPosition(model)
    if not model then return nil end
    -- PrimaryPart ist immer bevorzugt
    if model.PrimaryPart then return model.PrimaryPart.Position end
    -- Fallback: erster BasePart
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then return desc.Position end
    end
    return nil
end

local function teleportToPosition(pos)
    if not pos then return false end
    local root = getRoot()
    if not root then return false end
    -- +3 Y damit wir nicht im Boden spawnen
    root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    return true
end

-- Haupt-Funktion: TP zu Rift → Egg → Hatch
local function doRiftEggTP(riftName)
    if not riftName or riftName == "" then
        notify("Rift", "Kein Rift ausgewählt!", 2); return
    end

    local riftData = D.Rifts[riftName]
    if not riftData or riftData.Type ~= "Egg" then
        notify("Rift", riftName.." ist kein Egg-Rift!", 2); return
    end

    local eggName = riftData.Egg

    -- Schritt 1: Rift im Workspace finden → TP dorthin
    local riftModel = findRiftInWorkspace(riftName)
    if riftModel then
        local riftPos = getModelPosition(riftModel)
        if riftPos then
            teleportToPosition(riftPos)
            task.wait(0.3)
        end
    end

    -- Schritt 2: Egg im Workspace finden → TP dorthin
    local eggModel = findEggInWorkspace(eggName)
    if eggModel then
        local eggPos = getModelPosition(eggModel)
        if eggPos then
            teleportToPosition(eggPos)
            task.wait(0.3)
            -- Schritt 3: Hatch
            fire("HatchEgg", eggName, 1)
            notify("Rift", "✓ "..riftName.." → "..eggName, 2)
            return
        end
    end

    -- Fallback: Egg nicht im Workspace (noch nicht geladen) → nur Fire
    fire("HatchEgg", eggName, 1)
    notify("Rift", "Egg nicht im WS — HatchEgg direkt gefeuert: "..eggName, 3)
end

-- ╔══════════════════════════════════════════════════════════════════╗
-- ║   MINIGAME LOGIK                                                 ║
-- ║   FinishMinigame()          — sofortiger Win                     ║
-- ║   UseItem("Super Ticket")   — Cooldown skippen                   ║
-- ╚══════════════════════════════════════════════════════════════════╝

local function finishMinigame()
    fire("FinishMinigame")
end

-- Super Ticket = Minigame Cooldown skippen
-- Aus Data.Powerups: Super Ticket ist Type="Generic", Consumable=false
-- Remote: fire("UseItem", "Super Ticket") oder fire("UsePowerup", "Super Ticket")
local function useMinigameTicket()
    fire("UseItem", "Super Ticket")
    fire("UsePowerup", "Super Ticket")
end

-- Kompletter Minigame-Loop: Ticket → Finish → warten
local function runMinigameLoop(miniName, useTicket)
    task.spawn(function()
        local data = D.Minigames[miniName]
        local cooldown = (data and data.Cooldown or 300) + 1
        local count = 0
        while Config["AutoMini_"..miniName] do
            if useTicket then
                useMinigameTicket()
                task.wait(0.5)
            end
            finishMinigame()
            count += 1
            notify("Minigame", miniName.." #"..count.." ✓", 2)
            if not useTicket then
                -- Cooldown abwarten wenn kein Ticket
                task.wait(cooldown)
            else
                task.wait(3)
            end
        end
    end)
end

-- ╔══════════════════════════╗
-- ║      CORE FEATURES       ║
-- ╚══════════════════════════╝

local BLOW_INTERVAL = 0.05
local lastBlow = 0

local function applyWalkSpeed()
    local h=getHum(); if h then h.WalkSpeed=Config.WalkSpeedEnabled and Config.WalkSpeed or 16 end
end
local function applyJumpPower()
    local h=getHum(); if h then h.JumpPower=Config.JumpPowerEnabled and Config.JumpPower or 50 end
end

UserInputService.JumpRequest:Connect(function()
    if Config.InfJumpEnabled then local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

RunService.Stepped:Connect(function()
    if Config.NoclipEnabled then
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
        while Config.FlyEnabled and root.Parent do
            local d=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then d+=cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then d-=cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then d-=cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then d+=cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d+=Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d-=Vector3.new(0,1,0) end
            bv.Velocity=d*Config.FlySpeed; bg.CFrame=cam.CFrame; task.wait()
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

task.spawn(function()
    local VU=game:GetService("VirtualUser")
    while true do
        task.wait(60)
        if Config.AntiAFKEnabled then VU:CaptureController(); VU:ClickButton2(Vector2.new()) end
    end
end)

local ESPBoxes={}
local function clearESP()
    for _,h in pairs(ESPBoxes) do if h and h.Parent then h:Destroy() end end; ESPBoxes={}
end

local function redeemCode(code)
    pcall(function() if RE then RE:FireServer("RedeemCode", code) end end)
end
local function redeemAllCodes()
    task.spawn(function()
        for _,c in ipairs(CODES) do redeemCode(c); task.wait(Config.CodeDelay) end
        notify("Codes","Alle "..#CODES.." Codes versucht!",4)
    end)
end

-- ╔══════════════════════════╗
-- ║       MAIN LOOP          ║
-- ╚══════════════════════════╝

RunService.Heartbeat:Connect(function()
    local now = tick()

    if Config.AutoBlow and (now-lastBlow) >= BLOW_INTERVAL then
        pcall(function() if RE then RE:FireServer("BlowBubble"); State.BubblesBlown+=1 end end)
        lastBlow = now
    end

    if Config.WalkSpeedEnabled then local h=getHum(); if h and h.WalkSpeed~=Config.WalkSpeed then h.WalkSpeed=Config.WalkSpeed end end
    if Config.JumpPowerEnabled then local h=getHum(); if h and h.JumpPower~=Config.JumpPower then h.JumpPower=Config.JumpPower end end

    if Config.ESPEnabled then
        for _,player in ipairs(Players:GetPlayers()) do
            if player~=LocalPlayer and player.Character then
                if not ESPBoxes[player.Name] or not ESPBoxes[player.Name].Parent then
                    local sel=Instance.new("SelectionBox")
                    sel.Color3=Color3.fromRGB(255,60,60); sel.LineThickness=0.07
                    sel.SurfaceTransparency=0.75; sel.SurfaceColor3=Color3.fromRGB(255,50,50)
                    sel.Adornee=player.Character; sel.Parent=Workspace
                    ESPBoxes[player.Name]=sel
                else ESPBoxes[player.Name].Adornee=player.Character end
            end
        end
    end
end)

-- ╔══════════════════════════╗
-- ║      RAYFIELD WINDOW     ║
-- ╚══════════════════════════╝

local Window = Rayfield:CreateWindow({
    Name            = "BGS Infinity — Lunar Hub",
    LoadingTitle    = "BGS Infinity Hub",
    LoadingSubtitle = "v6.0  |  100% Dynamisch  |  Korrekte Logik",
    ConfigurationSaving = { Enabled=false },
    Discord   = { Enabled=false },
    KeySystem = false,
})

local Tabs = {
    Farm      = Window:CreateTab("Farm",      "wind"),
    Rifts     = Window:CreateTab("Rifts",     "sparkles"),
    Potions   = Window:CreateTab("Potions",   "flask-conical"),
    Mini      = Window:CreateTab("Minigames", "gamepad-2"),
    Fishing   = Window:CreateTab("Fishing",   "fish"),
    Teleport  = Window:CreateTab("Teleport",  "map-pin"),
    Codes     = Window:CreateTab("Codes",     "ticket"),
    Speed     = Window:CreateTab("Speed",     "zap"),
    Misc      = Window:CreateTab("Misc",      "settings"),
    Info      = Window:CreateTab("Info",      "info"),
}

-- ════════════════════════════════════════════
--                  FARM TAB
-- ════════════════════════════════════════════

Tabs.Farm:CreateSection("Auto Blow")

Tabs.Farm:CreateToggle({
    Name="Auto Blow Bubble", CurrentValue=false, Flag="AutoBlow",
    Callback=function(v) Config.AutoBlow=v end,
})

Tabs.Farm:CreateSection("Auto Hatch — Egg auswählen")

-- Live-Eggs aus Workspace + alle bekannten Eggs
local function buildEggList()
    -- Erst live scannen
    local live = getLiveEggs()
    -- Fallback: bekannte Egg-Namen aus Powerups
    if #live == 0 then
        for name, data in pairs(D.Powerups) do
            if type(data)=="table" and data.Type=="Egg" then
                table.insert(live, name)
            end
        end
        table.sort(live)
    end
    if #live == 0 then live = {"Common Egg"} end
    return live
end

local eggList = buildEggList()
Config.SelectedEgg = eggList[1] or "Common Egg"

Tabs.Farm:CreateDropdown({
    Name     = "Egg auswählen",
    Options  = eggList,
    CurrentOption = {Config.SelectedEgg},
    Flag     = "SelectedEgg",
    Callback = function(v)
        Config.SelectedEgg = type(v)=="table" and v[1] or v
    end,
})

Tabs.Farm:CreateToggle({
    Name="Auto Hatch", CurrentValue=false, Flag="AutoHatch",
    Callback=function(v)
        Config.AutoHatch=v
        if v then
            task.spawn(function()
                while Config.AutoHatch do
                    pcall(function() fire("HatchEgg", Config.SelectedEgg, 1) end)
                    task.wait(0.5)
                end
            end)
        end
    end,
})

Tabs.Farm:CreateSection("Claim Alles")

Tabs.Farm:CreateButton({ Name="ClaimAllPlaytime",           Callback=function() fire("ClaimAllPlaytime");           notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ClaimBenefits (VIP etc)",    Callback=function() fire("ClaimBenefits");              notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="DailyRewardClaimStars",      Callback=function() fire("DailyRewardClaimStars");      notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ChallengePassClaimReward",   Callback=function() fire("ChallengePassClaimReward");   notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ChallengePassFreeSkip",      Callback=function() fire("ChallengePassFreeSkip") end })
Tabs.Farm:CreateButton({ Name="ClaimXLIndexRewards",        Callback=function() fire("ClaimXLIndexRewards");        notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ClaimAllFishingIndexRewards",Callback=function() fire("ClaimAllFishingIndexRewards"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="SellAllFish",                Callback=function() fire("SellAllFish");                notify("Farm","✓",2) end })

Tabs.Farm:CreateSection("Chests — Live aus Data.Chests")
for chestName in pairs(D.Chests) do
    local c=chestName
    Tabs.Farm:CreateButton({ Name=c, Callback=function() fire("ClaimChest",c,true); notify("Chest",c.." ✓",2) end })
end

Tabs.Farm:CreateSection("Mastery")
Tabs.Farm:CreateButton({ Name="Upgrade ×1",  Callback=function() fire("UpgradeMastery",1) end })
Tabs.Farm:CreateButton({
    Name="Upgrade ×50",
    Callback=function()
        task.spawn(function() for i=1,50 do fire("UpgradeMastery",1); task.wait(0.1) end end)
        notify("Mastery","×50 ✓",2)
    end,
})

Tabs.Farm:CreateSection("Genie & Shop")
Tabs.Farm:CreateButton({ Name="StartGenieQuest",  Callback=function() fire("StartGenieQuest") end })
Tabs.Farm:CreateButton({ Name="RerollGenie",      Callback=function() fire("RerollGenie") end })
Tabs.Farm:CreateButton({ Name="ChangeGenieQuest", Callback=function() fire("ChangeGenieQuest") end })
Tabs.Farm:CreateButton({ Name="ShopFreeReroll",   Callback=function() fire("ShopFreeReroll"); notify("Shop","✓",2) end })

-- ════════════════════════════════════════════
--                 RIFTS TAB
-- ════════════════════════════════════════════
-- Logik:
--   EggRifts: TP → Rift → TP → Egg → HatchEgg(eggName)
--   Chest/Gift Rifts: Direkt ClaimChest / interagieren

local eggRifts    = getEggRifts()
local nonEggRifts = getNonEggRifts()

-- Dropdown-Optionen für Egg-Rifts
local riftOptions = {}
for _, r in ipairs(eggRifts) do
    table.insert(riftOptions, r.rift.." → "..r.egg)
end
if #riftOptions == 0 then riftOptions = {"(keine Egg-Rifts gefunden)"} end
Config.SelectedRift = eggRifts[1] and eggRifts[1].rift or ""

Tabs.Rifts:CreateSection("Egg Rifts — Auto TP + Hatch")
Tabs.Rifts:CreateLabel("Teleportiert zum Rift → zum Egg → hatcht automatisch")

Tabs.Rifts:CreateDropdown({
    Name    = "Rift auswählen",
    Options = riftOptions,
    CurrentOption = {riftOptions[1]},
    Flag    = "SelectedRiftDisplay",
    Callback = function(v)
        local sel = type(v)=="table" and v[1] or v
        -- Parse rift name aus "riftname → eggname"
        local riftName = sel:match("^(.-)%s*→") or sel
        Config.SelectedRift = riftName:gsub("%s+$","")
    end,
})

Tabs.Rifts:CreateButton({
    Name = "▶ Jetzt TP + Hatch",
    Callback = function()
        doRiftEggTP(Config.SelectedRift)
    end,
})

Tabs.Rifts:CreateToggle({
    Name = "Auto Rift Loop (wiederholt alle N Sek.)",
    CurrentValue = false,
    Flag = "AutoRiftTP",
    Callback = function(v)
        Config.AutoRiftTP = v
        if v then
            task.spawn(function()
                while Config.AutoRiftTP do
                    doRiftEggTP(Config.SelectedRift)
                    task.wait(Config.RiftLoopInterval)
                end
            end)
        end
    end,
})

Tabs.Rifts:CreateSlider({
    Name="Loop Interval (Sek.)", Range={1,30}, Increment=1, CurrentValue=3, Flag="RiftLoopInterval",
    Callback=function(v) Config.RiftLoopInterval=v end,
})

-- Alle Egg-Rifts einzeln
Tabs.Rifts:CreateSection("Alle Egg-Rifts ("..#eggRifts..")")
for _, r in ipairs(eggRifts) do
    local rn=r.rift; local en=r.egg
    Tabs.Rifts:CreateButton({
        Name = r.rift.." → "..r.egg,
        Callback = function() doRiftEggTP(rn) end,
    })
end

-- Chest/Gift Rifts
if #nonEggRifts > 0 then
    Tabs.Rifts:CreateSection("Chest & Gift Rifts")
    for _, riftName in ipairs(nonEggRifts) do
        local rn=riftName
        local riftData=D.Rifts[rn]
        local dispName = (riftData and riftData.DisplayName) or riftName
        Tabs.Rifts:CreateButton({
            Name = dispName,
            Callback = function()
                -- Chest Rifts: ClaimChest mit dem DisplayName
                if riftData and riftData.Type == "Chest" then
                    fire("ClaimChest", dispName, true)
                elseif riftData and riftData.Type == "Gift" then
                    fire("ClaimGiftRift", rn)
                end
                -- Zusätzlich: TP zum Rift falls er im WS ist
                local model = findRiftInWorkspace(rn)
                if model then
                    local pos = getModelPosition(model)
                    if pos then teleportToPosition(pos) end
                end
                notify("Rift", dispName.." ✓", 2)
            end,
        })
    end
end

-- RiftSummon
Tabs.Rifts:CreateSection("Rift Summon")
Tabs.Rifts:CreateButton({
    Name="RiftSummon ×10",
    Callback=function()
        task.spawn(function()
            for i=1,10 do pcall(function() fire("RiftSummon") end); task.wait(0.2) end
        end)
        notify("Rift","×10 RiftSummon ✓",2)
    end,
})
Tabs.Rifts:CreateButton({
    Name="MoonSummon ×10",
    Callback=function()
        task.spawn(function()
            for i=1,10 do pcall(function() fire("MoonSummon") end); task.wait(0.2) end
        end)
        notify("Rift","×10 MoonSummon ✓",2)
    end,
})

-- ════════════════════════════════════════════
--                POTIONS TAB
-- CraftPotion(name, level, fromInventory=true)
-- ════════════════════════════════════════════

Tabs.Potions:CreateSection("Alle Potions — Live aus Data.Potions")
Tabs.Potions:CreateLabel("fromInventory=true → aus Inventar benutzen (kein Craft nötig)")

Tabs.Potions:CreateButton({
    Name="⚡ ALLE Potions aktivieren",
    Callback=function()
        task.spawn(function()
            local count=0
            for potName, potData in pairs(D.Potions) do
                if type(potData)=="table" then
                    local lv = potData.OneLevel and 1 or 7
                    pcall(function() fire("CraftPotion", potName, lv, true) end)
                    count+=1; task.wait(0.2)
                end
            end
            notify("Potions","Alle "..count.." ✓",4)
        end)
    end,
})

Tabs.Potions:CreateButton({
    Name="Standard Pack (Lucky+Mythic+Speed+Coins+Tickets Lv7)",
    Callback=function()
        task.spawn(function()
            for _,n in ipairs({"Lucky","Mythic","Speed","Coins","Tickets"}) do
                pcall(function() fire("CraftPotion",n,7,true) end); task.wait(0.2)
            end; notify("Potions","Standard Pack ✓",3)
        end)
    end,
})

-- Standard Potions
Tabs.Potions:CreateSection("Standard (Lv7)")
for potName, potData in pairs(D.Potions) do
    if type(potData)=="table" and not potData.OneLevel then
        local n=potName
        Tabs.Potions:CreateButton({
            Name=potName.." Lv7",
            Callback=function() fire("CraftPotion",n,7,true); notify("Potion",n.." ✓",2) end,
        })
    end
end

-- Elixiere
Tabs.Potions:CreateSection("Elixiere (Lv1)")
for potName, potData in pairs(D.Potions) do
    if type(potData)=="table" and potData.OneLevel then
        local n=potName
        Tabs.Potions:CreateButton({
            Name=potName,
            Callback=function() fire("CraftPotion",n,1,true); notify("Elixier",n.." ✓",2) end,
        })
    end
end

-- ════════════════════════════════════════════
--               MINIGAMES TAB
-- FinishMinigame()            — sofortiger Win
-- UseItem("Super Ticket")     — Cooldown skippen
-- ════════════════════════════════════════════

Tabs.Mini:CreateSection("Minigames — Live aus Data.Minigames")
Tabs.Mini:CreateLabel("Super Ticket = Cooldown überspringen")
Tabs.Mini:CreateLabel("Toggle = Loop (Ticket → Finish → repeat)")

for miniName, miniData in pairs(D.Minigames) do
    if type(miniData)=="table" then
        local mn=miniName
        local cost = miniData.Cost and miniData.Cost.Amount or 0
        local cd   = miniData.Cooldown or 300

        Tabs.Mini:CreateSection(miniName.."  |  Cooldown: "..cd.."s")
        if miniData.Description then
            Tabs.Mini:CreateLabel(miniData.Description)
        end

        -- Einmalig finish
        Tabs.Mini:CreateButton({
            Name="FinishMinigame (einmalig)",
            Callback=function()
                finishMinigame()
                notify("Minigame",mn.." Win ✓",2)
            end,
        })

        -- Einmalig Ticket + Finish
        Tabs.Mini:CreateButton({
            Name="Super Ticket → Finish",
            Callback=function()
                useMinigameTicket()
                task.wait(0.5)
                finishMinigame()
                notify("Minigame","Ticket + "..mn.." ✓",2)
            end,
        })

        -- Auto Loop Toggle
        Config["AutoMini_"..mn] = false
        Tabs.Mini:CreateToggle({
            Name="Auto Loop: "..miniName,
            CurrentValue=false,
            Flag="AutoMini_"..mn,
            Callback=function(v)
                Config["AutoMini_"..mn]=v
                if v then runMinigameLoop(mn, true) end
            end,
        })
    end
end

-- DoggyJump & Obbys
Tabs.Mini:CreateSection("DoggyJump")
Tabs.Mini:CreateButton({ Name="DoggyJumpWin", Callback=function() fire("DoggyJumpWin"); notify("Minigame","DoggyJump ✓",2) end })

Tabs.Mini:CreateSection("Obbys — Live aus Data.Obbys")
for obbyName in pairs(D.Obbys) do
    local d=obbyName
    Tabs.Mini:CreateButton({
        Name="Complete: "..obbyName,
        Callback=function()
            task.spawn(function()
                pcall(function() fire("StartObby",d) end)
                task.wait(0.5)
                pcall(function() fire("CompleteObby",d) end)
                task.wait(0.3)
                pcall(function() fire("ClaimObbyChest",d) end)
            end)
            notify("Obby",obbyName.." ✓",3)
        end,
    })
end

Tabs.Mini:CreateSection("Island Race")
Tabs.Mini:CreateButton({ Name="RequestRaceLeave", Callback=function() fire("RequestRaceLeave") end })

-- ════════════════════════════════════════════
--                FISHING TAB
-- ════════════════════════════════════════════

Tabs.Fishing:CreateSection("Quick Actions")
Tabs.Fishing:CreateButton({ Name="SellAllFish",                   Callback=function() fire("SellAllFish"); notify("Fishing","✓",2) end })
Tabs.Fishing:CreateButton({ Name="ClaimAllFishingIndexRewards",   Callback=function() fire("ClaimAllFishingIndexRewards"); notify("Fishing","✓",2) end })

Tabs.Fishing:CreateSection("Rods — Live aus Data.FishingRods")
for rodName in pairs(D.FishingRods) do
    local r=rodName
    Tabs.Fishing:CreateButton({
        Name="Equip: "..rodName,
        Callback=function() fire("SetEquippedRod",r); notify("Fishing",r.." ✓",2) end,
    })
end

Tabs.Fishing:CreateSection("Bait — Live aus Data.FishingBait")
for baitName in pairs(D.FishingBait) do
    local b=baitName
    Tabs.Fishing:CreateButton({
        Name="Equip: "..baitName,
        Callback=function() fire("SetEquippedBait",b); notify("Fishing",b.." ✓",2) end,
    })
end

-- ════════════════════════════════════════════
--               TELEPORT TAB
-- ════════════════════════════════════════════

Tabs.Teleport:CreateSection("Worlds — Live aus Data.Worlds")
for worldName in pairs(D.Worlds) do
    local wn=worldName
    Tabs.Teleport:CreateButton({
        Name=worldName,
        Callback=function() fire("WorldTeleport",wn); notify("Teleport","→ "..wn,2) end,
    })
end

Tabs.Teleport:CreateSection("Plaza — PlazaTeleport(target)")
Tabs.Teleport:CreateButton({ Name="Home",      Callback=function() fire("PlazaTeleport","home");  notify("Teleport","→ Home",2)      end })
Tabs.Teleport:CreateButton({ Name="Plaza",     Callback=function() fire("PlazaTeleport","plaza"); notify("Teleport","→ Plaza",2)     end })
Tabs.Teleport:CreateButton({ Name="Pro Plaza", Callback=function() fire("PlazaTeleport","pro");   notify("Teleport","→ Pro Plaza",2) end })

Tabs.Teleport:CreateSection("Unlock")
Tabs.Teleport:CreateButton({
    Name="Unlock All Worlds",
    Callback=function()
        task.spawn(function()
            for wn in pairs(D.Worlds) do pcall(function() fire("UnlockWorld",wn) end); task.wait(0.3) end
        end)
        notify("Unlock","Alle Worlds ✓",3)
    end,
})

-- ════════════════════════════════════════════
--                 CODES TAB
-- ════════════════════════════════════════════

Tabs.Codes:CreateSection("Promo Codes — Live aus Data.Codes ("..#CODES.." Codes)")
Tabs.Codes:CreateLabel("Automatisch aktuell nach jedem Game-Update!")

Tabs.Codes:CreateButton({ Name="✅ Alle Codes einlösen", Callback=redeemAllCodes })

Tabs.Codes:CreateSlider({
    Name="Delay (Sek.)", Range={0,5}, Increment=0.1, CurrentValue=1, Flag="CodeDelay",
    Callback=function(v) Config.CodeDelay=v end,
})

Tabs.Codes:CreateSection("Einzeln")
for _,code in ipairs(CODES) do
    local c=code
    Tabs.Codes:CreateButton({
        Name=code,
        Callback=function() redeemCode(c); notify("Code",c.." ✓",2) end,
    })
end

-- ════════════════════════════════════════════
--                 SPEED TAB
-- ════════════════════════════════════════════

Tabs.Speed:CreateSection("Walk & Jump")
Tabs.Speed:CreateToggle({ Name="Custom Walk Speed", CurrentValue=false, Flag="WalkSpeedEnabled",
    Callback=function(v) Config.WalkSpeedEnabled=v; applyWalkSpeed() end })
Tabs.Speed:CreateSlider({ Name="Walk Speed", Range={16,300}, Increment=1, CurrentValue=32, Flag="WalkSpeed",
    Callback=function(v) Config.WalkSpeed=v; if Config.WalkSpeedEnabled then applyWalkSpeed() end end })
Tabs.Speed:CreateToggle({ Name="Custom Jump Power", CurrentValue=false, Flag="JumpPowerEnabled",
    Callback=function(v) Config.JumpPowerEnabled=v; applyJumpPower() end })
Tabs.Speed:CreateSlider({ Name="Jump Power", Range={50,500}, Increment=1, CurrentValue=80, Flag="JumpPower",
    Callback=function(v) Config.JumpPower=v; if Config.JumpPowerEnabled then applyJumpPower() end end })
Tabs.Speed:CreateToggle({ Name="Infinite Jump", CurrentValue=false, Flag="InfJump",
    Callback=function(v) Config.InfJumpEnabled=v end })

Tabs.Speed:CreateSection("Advanced")
Tabs.Speed:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="Noclip",
    Callback=function(v) Config.NoclipEnabled=v end })
Tabs.Speed:CreateToggle({ Name="Fly (WASD + Space/LCtrl)", CurrentValue=false, Flag="Fly",
    Callback=function(v) Config.FlyEnabled=v; if v then task.defer(enableFly) else disableFly() end end })
Tabs.Speed:CreateSlider({ Name="Fly Speed", Range={10,300}, Increment=1, CurrentValue=60, Flag="FlySpeed",
    Callback=function(v) Config.FlySpeed=v end })

-- ════════════════════════════════════════════
--                  MISC TAB
-- ════════════════════════════════════════════

Tabs.Misc:CreateSection("Utility")
Tabs.Misc:CreateToggle({ Name="Anti-AFK", CurrentValue=true, Flag="AntiAFK",
    Callback=function(v) Config.AntiAFKEnabled=v end })
Tabs.Misc:CreateToggle({ Name="Player ESP", CurrentValue=false, Flag="ESP",
    Callback=function(v) Config.ESPEnabled=v; if not v then clearESP() end end })

Tabs.Misc:CreateSection("Events — Live aus Data.Events")
Tabs.Misc:CreateButton({
    Name="🎉 Alle Events claimen",
    Callback=function()
        task.spawn(function()
            local n=0
            for evName in pairs(D.Events) do
                pcall(function() fire("ClaimEventPrize",evName) end)
                n+=1; task.wait(0.15)
            end
            notify("Events","Alle "..n.." geclaimed ✓",4)
        end)
    end,
})
for evName in pairs(D.Events) do
    local e=evName
    Tabs.Misc:CreateButton({ Name=evName, Callback=function() fire("ClaimEventPrize",e); notify("Event",e.." ✓",2) end })
end

Tabs.Misc:CreateSection("Competitive & Clans")
Tabs.Misc:CreateButton({ Name="ClanLeave",             Callback=function() fire("ClanLeave") end })
Tabs.Misc:CreateButton({ Name="CompetitiveReroll",     Callback=function() fire("CompetitiveReroll"); notify("Comp","✓",2) end })
Tabs.Misc:CreateButton({ Name="ClaimCompetitivePrize", Callback=function() fire("ClaimCompetitivePrize"); notify("Comp","✓",2) end })

Tabs.Misc:CreateSection("Debug")
Tabs.Misc:CreateButton({
    Name="Remotes neu initialisieren",
    Callback=function()
        local ok=initRemotes()
        notify("Remotes",ok and "✅ Verbunden!" or "❌ Fehlgeschlagen!",4)
    end,
})
Tabs.Misc:CreateButton({ Name="ESP löschen", Callback=function() clearESP(); notify("ESP","✓",2) end })
Tabs.Misc:CreateButton({
    Name="Live Eggs neu scannen",
    Callback=function()
        local eggs=getLiveEggs()
        notify("Eggs",#eggs.." Eggs im WS gefunden",3)
    end,
})

-- ════════════════════════════════════════════
--                  INFO TAB
-- ════════════════════════════════════════════

Tabs.Info:CreateSection("BGS Infinity Lunar Hub v6.0")
Tabs.Info:CreateLabel("100% Dynamisch — alle Daten live aus ReplicatedStorage")

local function countTable(t) local n=0 for _ in pairs(t) do n+=1 end return n end

Tabs.Info:CreateSection("Geladene Daten")
Tabs.Info:CreateLabel("Potions:   "..countTable(D.Potions))
Tabs.Info:CreateLabel("Powerups:  "..countTable(D.Powerups))
Tabs.Info:CreateLabel("Rifts:     "..countTable(D.Rifts).." ("..#eggRifts.." Egg-Rifts)")
Tabs.Info:CreateLabel("Worlds:    "..countTable(D.Worlds))
Tabs.Info:CreateLabel("Minigames: "..countTable(D.Minigames))
Tabs.Info:CreateLabel("Codes:     "..#CODES)
Tabs.Info:CreateLabel("Chests:    "..countTable(D.Chests))
Tabs.Info:CreateLabel("Events:    "..countTable(D.Events))

Tabs.Info:CreateSection("Remote Logik")
Tabs.Info:CreateLabel("BlowBubble()")
Tabs.Info:CreateLabel("HatchEgg(eggName, amount)")
Tabs.Info:CreateLabel("CraftPotion(name, level, true)")
Tabs.Info:CreateLabel("FinishMinigame()")
Tabs.Info:CreateLabel("UseItem('Super Ticket')  ← Cooldown skip")
Tabs.Info:CreateLabel("PlazaTeleport('home'/'plaza'/'pro')")
Tabs.Info:CreateLabel("ClaimChest(name, true)")
Tabs.Info:CreateLabel("ClaimEventPrize(eventName)")

Tabs.Info:CreateSection("Session Stats")
local statsLabel=Tabs.Info:CreateParagraph({Title="Stats",Content="Laedt..."})
task.spawn(function()
    while true do
        task.wait(1)
        local elapsed=tick()-State.StartTime
        local bpm=elapsed>0 and math.floor(State.BubblesBlown/elapsed*60) or 0
        pcall(function()
            statsLabel:Set({Title="Stats",Content="🫧 "..formatNum(State.BubblesBlown).."  |  ⏱ "..formatTime(elapsed).."  |  📊 "..formatNum(bpm).."/min")
        end)
    end
end)

-- ╔══════════════════════════╗
-- ║          INIT            ║
-- ╚══════════════════════════╝

task.defer(function()
    local ok=initRemotes()
    notify(
        "BGS Lunar Hub v6.0",
        ok and ("✅ "..countTable(D.Rifts).." Rifts | "..#eggRifts.." Egg-Rifts | "..countTable(D.Potions).." Potions | "..#CODES.." Codes")
           or "⚠️ Warte auf Game-Load...",
        6
    )
    if not ok then
        task.spawn(function()
            while not RE do
                task.wait(3)
                if initRemotes() then notify("Remotes","✅ Verbunden!",3) end
            end
        end)
    end
end)

Rayfield:LoadConfiguration()
