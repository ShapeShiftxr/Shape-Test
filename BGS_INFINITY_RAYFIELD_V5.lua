-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║   BGS INFINITY — LUNAR HUB  v5.0  |  100% Dynamisch                ║
-- ║   Alle Daten werden zur Laufzeit aus ReplicatedStorage geladen.     ║
-- ║   Neue Eggs, Potions, Events, Rifts etc. erscheinen automatisch!    ║
-- ╚══════════════════════════════════════════════════════════════════════╝

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ── SERVICES ──
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

-- ╔══════════════════════════════════════════╗
-- ║   DATEN DIREKT AUS REPLICATEDSTORAGE     ║
-- ║   Alle Pfade 1:1 aus dem Spiel           ║
-- ╚══════════════════════════════════════════╝

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data   = Shared:WaitForChild("Data")

local function safeRequire(path)
    local ok, result = pcall(require, path)
    return ok and result or {}
end

-- Alle Datenmodule live laden
local D = {
    Potions      = safeRequire(Data.Potions),
    Powerups     = safeRequire(Data.Powerups),
    Worlds       = safeRequire(Data.Worlds),
    Gum          = safeRequire(Data.Gum),
    Chests       = safeRequire(Data.Chests),
    Rifts        = safeRequire(Data.Rifts),
    Obbys        = safeRequire(Data.Obbys),
    Minigames    = safeRequire(Data.Minigames),
    FishingRods  = safeRequire(Data.FishingRods),
    FishingBait  = safeRequire(Data.FishingBait),
    FishingAreas = safeRequire(Data.FishingAreas),
    Fish         = safeRequire(Data.Fish),
    Events       = safeRequire(Data.Events),
    Enchants     = safeRequire(Data.Enchants),
    Runes        = safeRequire(Data.Runes),
    Codes        = safeRequire(Data.Codes),
    Buffs        = safeRequire(Data.Buffs),
    Currency     = safeRequire(Data.Currency),
    Shops        = safeRequire(Data.Shops),
    Benefits     = safeRequire(Data.Benefits),
    Leaderboards = safeRequire(Data.Leaderboards),
    Titles       = safeRequire(Data.Titles),
    Gamepasses   = safeRequire(Data.Gamepasses),
}

-- Schlüssel eines Daten-Tables sortiert als Liste zurückgeben
local function keys(t)
    local list = {}
    for k in pairs(t) do
        table.insert(list, k)
    end
    table.sort(list, function(a,b)
        local oa = type(t[a])=="table" and t[a].LayoutOrder or 9999
        local ob = type(t[b])=="table" and t[b].LayoutOrder or 9999
        if oa ~= ob then return oa < ob end
        return tostring(a) < tostring(b)
    end)
    return list
end

-- Powerups nach Typ filtern
local function powerupsByType(typeName)
    local list = {}
    for name, data in pairs(D.Powerups) do
        if type(data)=="table" and data.Type == typeName then
            table.insert(list, { name=name, data=data })
        end
    end
    table.sort(list, function(a,b)
        local oa = a.data.LayoutOrder or 9999
        local ob = b.data.LayoutOrder or 9999
        return oa < ob
    end)
    return list
end

-- Codes als Liste
local CODES = keys(D.Codes)

-- ╔══════════════════════════════════════╗
-- ║   REMOTE SETUP                       ║
-- ║   FireServer(actionName, ...)        ║
-- ╚══════════════════════════════════════╝

local RE, RF

local function fire(action, ...)
    if RE then RE:FireServer(action, ...) end
end

local function invoke(action, ...)
    if RF then return RF:InvokeServer(action, ...) end
end

local function initRemotes()
    local ok, mod = pcall(function()
        return Shared
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

-- ╔══════════════════════════╗
-- ║         CONFIG           ║
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

local function getHum()   local c=LocalPlayer.Character; return c and c:FindFirstChild("Humanoid") end
local function getRoot()  local c=LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end

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
            local uis=UserInputService
            if uis:IsKeyDown(Enum.KeyCode.W) then d+=cam.CFrame.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.S) then d-=cam.CFrame.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.A) then d-=cam.CFrame.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.D) then d+=cam.CFrame.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.Space) then d+=Vector3.new(0,1,0) end
            if uis:IsKeyDown(Enum.KeyCode.LeftControl) then d-=Vector3.new(0,1,0) end
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
        for _,code in ipairs(CODES) do
            redeemCode(code); task.wait(Config.CodeDelay)
        end
        notify("Codes","Alle "..#CODES.." Codes versucht!",4)
    end)
end

local function claimAll()
    pcall(function() fire("ClaimAllPlaytime") end)            task.wait(0.2)
    pcall(function() fire("ClaimBenefits") end)               task.wait(0.2)
    pcall(function() fire("ChallengePassClaimReward") end)     task.wait(0.2)
    pcall(function() fire("DailyRewardClaimStars") end)        task.wait(0.2)
    pcall(function() fire("ClaimAllFishingIndexRewards") end)  task.wait(0.2)
    pcall(function() fire("ClaimXLIndexRewards") end)          task.wait(0.2)
    -- Alle Chests dynamisch
    for chestName in pairs(D.Chests) do
        pcall(function() fire("ClaimChest", chestName, true) end); task.wait(0.15)
    end
    notify("Farm","Alle Rewards geclaimed ✓",3)
end

-- ╔══════════════════════════╗
-- ║       MAIN LOOP          ║
-- ╚══════════════════════════╝

RunService.Heartbeat:Connect(function()
    local now=tick()
    if Config.AutoBlow and (now-lastBlow)>=BLOW_INTERVAL then
        pcall(function() if RE then RE:FireServer("BlowBubble"); State.BubblesBlown+=1 end end)
        lastBlow=now
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
    LoadingSubtitle = "v5.0  |  100% Dynamisch  |  by Lunar",
    ConfigurationSaving = { Enabled=true, FolderName="BGS-LunarHub", FileName="Config" },
    Discord   = { Enabled=false },
    KeySystem = false,
})

local Tabs = {
    Farm      = Window:CreateTab("Farm",      "wind"),
    Potions   = Window:CreateTab("Potions",   "flask-conical"),
    Eggs      = Window:CreateTab("Eggs",      "egg"),
    Mini      = Window:CreateTab("Minigames", "gamepad-2"),
    Fishing   = Window:CreateTab("Fishing",   "fish"),
    Teleport  = Window:CreateTab("Teleport",  "map-pin"),
    Codes     = Window:CreateTab("Codes",     "ticket"),
    Speed     = Window:CreateTab("Speed",     "zap"),
    Misc      = Window:CreateTab("Misc",      "settings"),
    Info      = Window:CreateTab("Info",      "info"),
}

-- ════════════════════════════════
--            FARM TAB
-- ════════════════════════════════

Tabs.Farm:CreateSection("Auto Farm")

Tabs.Farm:CreateToggle({
    Name="Auto Blow Bubble", CurrentValue=false, Flag="AutoBlow",
    Callback=function(v) Config.AutoBlow=v end,
})

Tabs.Farm:CreateToggle({
    Name="Auto Hatch Egg", CurrentValue=false, Flag="AutoHatch",
    Callback=function(v)
        Config.AutoHatch=v
        if v then
            task.spawn(function()
                while Config.AutoHatch do
                    pcall(function() fire("HatchEgg") end); task.wait(0.5)
                end
            end)
        end
    end,
})

Tabs.Farm:CreateSection("Claim Alles")

Tabs.Farm:CreateButton({
    Name="🎁 Alle Rewards claimen",
    Callback=function() task.spawn(claimAll) end,
})

Tabs.Farm:CreateButton({ Name="ClaimAllPlaytime",          Callback=function() fire("ClaimAllPlaytime"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ClaimBenefits",             Callback=function() fire("ClaimBenefits"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="DailyRewardClaimStars",     Callback=function() fire("DailyRewardClaimStars"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ChallengePassClaimReward",  Callback=function() fire("ChallengePassClaimReward"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ChallengePassFreeSkip",     Callback=function() fire("ChallengePassFreeSkip") end })
Tabs.Farm:CreateButton({ Name="ClaimXLIndexRewards",       Callback=function() fire("ClaimXLIndexRewards"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="ClaimAllFishingIndexRewards", Callback=function() fire("ClaimAllFishingIndexRewards"); notify("Farm","✓",2) end })
Tabs.Farm:CreateButton({ Name="SellAllFish",               Callback=function() fire("SellAllFish"); notify("Farm","SellAllFish ✓",2) end })

Tabs.Farm:CreateSection("Chests — Live aus Data.Chests")

for chestName in pairs(D.Chests) do
    local c=chestName
    Tabs.Farm:CreateButton({
        Name=chestName,
        Callback=function() fire("ClaimChest",c,true); notify("Chest",c.." ✓",2) end,
    })
end

Tabs.Farm:CreateSection("World Rewards — Live aus Data.Worlds")

for worldName in pairs(D.Worlds) do
    local w=worldName
    Tabs.Farm:CreateButton({
        Name="WorldReward: "..worldName,
        Callback=function() fire("ClaimWorldReward",w); notify("WorldReward",w.." ✓",2) end,
    })
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

-- ════════════════════════════════
--           POTIONS TAB
-- Direkt aus Data.Potions geladen
-- Signatur: CraftPotion(name, level, fromInventory)
-- fromInventory=true → aus Inventar (empfohlen)
-- ════════════════════════════════

Tabs.Potions:CreateSection("Alle Potions — Live aus Data.Potions")
Tabs.Potions:CreateLabel("Automatisch aktuell — neue Potions erscheinen sofort")

Tabs.Potions:CreateButton({
    Name="⚡ ALLE Potions aktivieren",
    Callback=function()
        task.spawn(function()
            local count=0
            for potName, potData in pairs(D.Potions) do
                if type(potData)=="table" then
                    local level = potData.OneLevel and 1 or 7
                    pcall(function() fire("CraftPotion", potName, level, true) end)
                    count+=1; task.wait(0.25)
                end
            end
            notify("Potions","Alle "..count.." Potions gefeuert!",4)
        end)
    end,
})

Tabs.Potions:CreateButton({
    Name="Standard Pack (Lucky+Mythic+Speed+Coins+Tickets Lv7)",
    Callback=function()
        task.spawn(function()
            for _,n in ipairs({"Lucky","Mythic","Speed","Coins","Tickets"}) do
                pcall(function() fire("CraftPotion",n,7,true) end); task.wait(0.2)
            end
            notify("Potions","Standard Pack ✓",3)
        end)
    end,
})

-- Standard Potions (nicht OneLevel)
Tabs.Potions:CreateSection("Standard Potions (Lv7)")

for potName, potData in pairs(D.Potions) do
    if type(potData)=="table" and not potData.OneLevel then
        local n=potName
        Tabs.Potions:CreateButton({
            Name=potName.." (Lv7)",
            Callback=function() fire("CraftPotion",n,7,true); notify("Potion",n.." ✓",2) end,
        })
    end
end

-- Elixiere (OneLevel=true)
Tabs.Potions:CreateSection("Elixiere & Special (Lv1)")

for potName, potData in pairs(D.Potions) do
    if type(potData)=="table" and potData.OneLevel then
        local n=potName
        Tabs.Potions:CreateButton({
            Name=potName,
            Callback=function() fire("CraftPotion",n,1,true); notify("Elixier",n.." ✓",2) end,
        })
    end
end

-- ════════════════════════════════
--              EGGS TAB
-- Direkt aus Data.Powerups geladen
-- Signatur: EggPrizeClaim(name, data)
-- ════════════════════════════════

Tabs.Eggs:CreateSection("Auto Hatch")

Tabs.Eggs:CreateToggle({
    Name="Auto Hatch", CurrentValue=false, Flag="AutoHatchEgg",
    Callback=function(v)
        Config.AutoHatch=v
        if v then
            task.spawn(function()
                while Config.AutoHatch do pcall(function() fire("HatchEgg") end); task.wait(0.5) end
            end)
        end
    end,
})

-- Season Eggs
local seasonEggs = powerupsByType("Egg")
Tabs.Eggs:CreateSection("Season & Series Eggs — Live aus Data.Powerups ("..#seasonEggs.." Eggs)")
Tabs.Eggs:CreateLabel("Automatisch aktuell — neue Eggs erscheinen sofort")

Tabs.Eggs:CreateButton({
    Name="🥚 Alle Eggs claimen",
    Callback=function()
        task.spawn(function()
            for _,egg in ipairs(seasonEggs) do
                pcall(function() fire("EggPrizeClaim", egg.name, {Name=egg.name}) end)
                task.wait(0.2)
            end
            notify("Eggs","Alle "..#seasonEggs.." Eggs geclaimed ✓",4)
        end)
    end,
})

for _,egg in ipairs(seasonEggs) do
    local en=egg.name
    Tabs.Eggs:CreateButton({
        Name=egg.name,
        Callback=function()
            fire("EggPrizeClaim",en,{Name=en})
            notify("Egg",en.." ✓",2)
        end,
    })
end

Tabs.Eggs:CreateSection("Infinity Egg")

Tabs.Eggs:CreateButton({
    Name="UpdateInfinityEggIndex",
    Callback=function() fire("UpdateInfinityEggIndex"); notify("Egg","InfinityEggIndex ✓",2) end,
})

-- ════════════════════════════════
--           MINIGAMES TAB
-- Direkt aus Data.Minigames geladen
-- Signatur: FinishMinigame() — kein Argument
-- ════════════════════════════════

Tabs.Mini:CreateSection("Minigames — Live aus Data.Minigames")

for miniName, miniData in pairs(D.Minigames) do
    if type(miniData)=="table" then
        local mn=miniName
        Tabs.Mini:CreateSection(miniName)
        if miniData.Description then
            Tabs.Mini:CreateLabel(miniData.Description)
        end
        Tabs.Mini:CreateButton({
            Name="FinishMinigame",
            Callback=function()
                fire("FinishMinigame")
                notify("Minigame","FinishMinigame ✓ ("..mn..")",2)
            end,
        })
    end
end

Tabs.Mini:CreateSection("DoggyJump")
Tabs.Mini:CreateButton({
    Name="DoggyJumpWin",
    Callback=function() fire("DoggyJumpWin"); notify("Minigame","DoggyJump ✓",2) end,
})

-- Obbys aus Data.Obbys
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
            notify("Obby",obbyName.." Complete+Claim ✓",3)
        end,
    })
end

Tabs.Mini:CreateSection("Island Race")
Tabs.Mini:CreateButton({ Name="RequestRaceLeave", Callback=function() fire("RequestRaceLeave") end })

-- ════════════════════════════════
--            FISHING TAB
-- Direkt aus Data.FishingRods/Bait geladen
-- ════════════════════════════════

Tabs.Fishing:CreateSection("Quick Actions")

Tabs.Fishing:CreateButton({ Name="SellAllFish",                   Callback=function() fire("SellAllFish"); notify("Fishing","✓",2) end })
Tabs.Fishing:CreateButton({ Name="ClaimAllFishingIndexRewards",   Callback=function() fire("ClaimAllFishingIndexRewards"); notify("Fishing","✓",2) end })
Tabs.Fishing:CreateButton({ Name="Reel",                          Callback=function() fire("Reel"); notify("Fishing","Reel ✓",1) end })

Tabs.Fishing:CreateSection("Rods — Live aus Data.FishingRods")

for rodName in pairs(D.FishingRods) do
    local r=rodName
    Tabs.Fishing:CreateButton({
        Name="Equip: "..rodName,
        Callback=function()
            fire("SetEquippedRod",r); fire("EquipRod",r)
            notify("Fishing","Rod: "..r.." ✓",2)
        end,
    })
end

Tabs.Fishing:CreateSection("Bait — Live aus Data.FishingBait")

for baitName in pairs(D.FishingBait) do
    local b=baitName
    Tabs.Fishing:CreateButton({
        Name="Equip: "..baitName,
        Callback=function()
            fire("SetEquippedBait",b)
            notify("Fishing","Bait: "..b.." ✓",2)
        end,
    })
end

-- ════════════════════════════════
--           TELEPORT TAB
-- Direkt aus Data.Worlds geladen
-- ════════════════════════════════

Tabs.Teleport:CreateSection("Worlds — Live aus Data.Worlds")

for worldName in pairs(D.Worlds) do
    local wn=worldName
    Tabs.Teleport:CreateButton({
        Name=worldName,
        Callback=function()
            fire("WorldTeleport",wn)
            notify("Teleport","→ "..wn,2)
        end,
    })
end

Tabs.Teleport:CreateSection("Plaza — PlazaTeleport(target)")

Tabs.Teleport:CreateButton({ Name="Home",     Callback=function() fire("PlazaTeleport","home");  notify("Teleport","→ Home",2)      end })
Tabs.Teleport:CreateButton({ Name="Plaza",    Callback=function() fire("PlazaTeleport","plaza"); notify("Teleport","→ Plaza",2)     end })
Tabs.Teleport:CreateButton({ Name="Pro Plaza",Callback=function() fire("PlazaTeleport","pro");   notify("Teleport","→ Pro Plaza",2) end })

Tabs.Teleport:CreateSection("Unlock")

Tabs.Teleport:CreateButton({
    Name="Unlock All Worlds",
    Callback=function()
        task.spawn(function()
            for worldName in pairs(D.Worlds) do
                pcall(function() fire("UnlockWorld",worldName) end); task.wait(0.3)
            end
        end)
        notify("Unlock","Alle Worlds ✓",3)
    end,
})

Tabs.Teleport:CreateButton({
    Name="Unlock All Hatching Zones",
    Callback=function()
        task.spawn(function()
            for i=1,20 do pcall(function() fire("UnlockHatchingZone",i) end); task.wait(0.1) end
        end)
        notify("Unlock","Hatching Zones ✓",3)
    end,
})

-- ════════════════════════════════
--             CODES TAB
-- Direkt aus Data.Codes geladen
-- ════════════════════════════════

Tabs.Codes:CreateSection("Promo Codes — Live aus Data.Codes ("..#CODES.." Codes)")
Tabs.Codes:CreateLabel("Neue Codes erscheinen automatisch nach jedem Game-Update!")

Tabs.Codes:CreateButton({
    Name="✅ Alle Codes einlösen",
    Callback=redeemAllCodes,
})

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

-- ════════════════════════════════
--             SPEED TAB
-- ════════════════════════════════

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

-- ════════════════════════════════
--              MISC TAB
-- ════════════════════════════════

Tabs.Misc:CreateSection("Utility")

Tabs.Misc:CreateToggle({ Name="Anti-AFK", CurrentValue=true, Flag="AntiAFK",
    Callback=function(v) Config.AntiAFKEnabled=v end })
Tabs.Misc:CreateToggle({ Name="Player ESP", CurrentValue=false, Flag="ESP",
    Callback=function(v) Config.ESPEnabled=v; if not v then clearESP() end end })
Tabs.Misc:CreateToggle({ Name="Auto Delete Bubbles", CurrentValue=false, Flag="AutoDelete",
    Callback=function(v) fire("ToggleAutoDelete",v) end })

Tabs.Misc:CreateSection("Events — Live aus Data.Events")
Tabs.Misc:CreateLabel("Alle Events direkt aus dem Spiel geladen")

Tabs.Misc:CreateButton({
    Name="🎉 Alle Event Prizes claimen",
    Callback=function()
        task.spawn(function()
            local count=0
            for eventName in pairs(D.Events) do
                pcall(function() fire("ClaimEventPrize",eventName) end)
                count+=1; task.wait(0.15)
            end
            notify("Events","Alle "..count.." Events geclaimed ✓",4)
        end)
    end,
})

for eventName in pairs(D.Events) do
    local e=eventName
    Tabs.Misc:CreateButton({
        Name=eventName,
        Callback=function()
            fire("ClaimEventPrize",e)
            notify("Event",e.." ✓",2)
        end,
    })
end

Tabs.Misc:CreateSection("Competitive & Clans")

Tabs.Misc:CreateButton({ Name="ClanLeave",             Callback=function() fire("ClanLeave") end })
Tabs.Misc:CreateButton({ Name="ClanDelete",            Callback=function() fire("ClanDelete") end })
Tabs.Misc:CreateButton({ Name="CompetitiveReroll",     Callback=function() fire("CompetitiveReroll"); notify("Competitive","✓",2) end })
Tabs.Misc:CreateButton({ Name="ClaimCompetitivePrize", Callback=function() fire("ClaimCompetitivePrize"); notify("Competitive","✓",2) end })

Tabs.Misc:CreateSection("Daily & Shop")

Tabs.Misc:CreateButton({ Name="DailyRewardsForfeitStreak", Callback=function() fire("DailyRewardsForfeitStreak") end })
Tabs.Misc:CreateButton({ Name="DailyRewardsBuyItem",       Callback=function() fire("DailyRewardsBuyItem") end })
Tabs.Misc:CreateButton({ Name="ShopFreeReroll",            Callback=function() fire("ShopFreeReroll") end })

Tabs.Misc:CreateSection("Trading Terminal")

Tabs.Misc:CreateButton({ Name="TradingTerminalLoadPosts",  Callback=function() fire("TradingTerminalLoadPosts") end })
Tabs.Misc:CreateButton({ Name="TradingTerminalResetPost",  Callback=function() fire("TradingTerminalResetPost") end })

Tabs.Misc:CreateSection("Debug")

Tabs.Misc:CreateButton({
    Name="Remotes neu initialisieren",
    Callback=function()
        local ok=initRemotes()
        notify("Remotes",ok and "✅ Verbunden!" or "❌ Fehlgeschlagen!",4)
    end,
})

Tabs.Misc:CreateButton({
    Name="ESP löschen",
    Callback=function() clearESP(); notify("ESP","Gelöscht",2) end,
})

-- ════════════════════════════════
--              INFO TAB
-- ════════════════════════════════

Tabs.Info:CreateSection("BGS Infinity Lunar Hub v5.0")
Tabs.Info:CreateLabel("100% Dynamisch — Daten direkt aus ReplicatedStorage")
Tabs.Info:CreateLabel("Neue Inhalte erscheinen automatisch ohne Script-Update!")

Tabs.Info:CreateSection("Geladene Daten")

-- Live-Zähler der geladenen Daten
local function countTable(t) local n=0 for _ in pairs(t) do n+=1 end return n end
Tabs.Info:CreateLabel("Potions:    "..countTable(D.Potions))
Tabs.Info:CreateLabel("Powerups:   "..countTable(D.Powerups))
Tabs.Info:CreateLabel("Worlds:     "..countTable(D.Worlds))
Tabs.Info:CreateLabel("Chests:     "..countTable(D.Chests))
Tabs.Info:CreateLabel("Minigames:  "..countTable(D.Minigames))
Tabs.Info:CreateLabel("Events:     "..countTable(D.Events))
Tabs.Info:CreateLabel("Fish:       "..countTable(D.Fish))
Tabs.Info:CreateLabel("FishRods:   "..countTable(D.FishingRods))
Tabs.Info:CreateLabel("FishBait:   "..countTable(D.FishingBait))
Tabs.Info:CreateLabel("Codes:      "..#CODES)
Tabs.Info:CreateLabel("Rifts:      "..countTable(D.Rifts))
Tabs.Info:CreateLabel("Enchants:   "..countTable(D.Enchants))

Tabs.Info:CreateSection("Remote Signatur (Korrekt)")
Tabs.Info:CreateLabel("BlowBubble()                    — kein Sell nötig")
Tabs.Info:CreateLabel("HatchEgg(name, amount)")
Tabs.Info:CreateLabel("CraftPotion(name, level, true)")
Tabs.Info:CreateLabel("PlazaTeleport('home'/'plaza'/'pro')")
Tabs.Info:CreateLabel("ClaimChest(name, true)")
Tabs.Info:CreateLabel("ClaimEventPrize(eventName)")
Tabs.Info:CreateLabel("EggPrizeClaim(name, {Name=name})")
Tabs.Info:CreateLabel("FinishMinigame()                — kein Argument")

Tabs.Info:CreateSection("Session Stats")

local statsLabel=Tabs.Info:CreateLabel("Lade...")
task.spawn(function()
    while true do
        task.wait(1)
        local elapsed=tick()-State.StartTime
        local bpm=elapsed>0 and math.floor(State.BubblesBlown/elapsed*60) or 0
        pcall(function()
            statsLabel:Set(
                "🫧 "..formatNum(State.BubblesBlown)
                .."  |  ⏱ "..formatTime(elapsed)
                .."  |  📊 "..formatNum(bpm).."/min"
            )
        end)
    end
end)

-- ╔══════════════════════════╗
-- ║          INIT            ║
-- ╚══════════════════════════╝

task.defer(function()
    local ok=initRemotes()
    local eggCount=#powerupsByType("Egg")
    local potCount=countTable(D.Potions)
    local codeCount=#CODES
    notify(
        "BGS Lunar Hub v5.0",
        ok
            and ("✅ Verbunden! "..potCount.." Potions | "..eggCount.." Eggs | "..codeCount.." Codes geladen")
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
