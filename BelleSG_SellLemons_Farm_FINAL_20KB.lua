--==============================================================
--  🍋 BELLE.SG SELL LEMONS — AUTO FARM  (v4 — Rayfield UI)
--  
--  SCRIPT FEATURES:
--  ✓ Auto Buy Tiles - Automatically purchases affordable tiles
--  ✓ Auto Upgrade Earners - Bulk-upgrades income machines using cash
--  ✓ Auto Upgrade Powers - Spends investors on power upgrades
--  ✓ Auto Collect Fruit - Harvests lemons and teleports to trees
--  ✓ Auto Wake Earners - Taps manual machines for rewards
--  ✓ Auto Collect Cash Drops - Instantly grabs falling cash
--  ✓ Auto Phone Deals - Accepts phone cash offers automatically
--  ✓ Auto Rebirth - Rebirths when worth >1 investor
--  ✓ Auto Evolve - Evolves at 100% evolution progress
--  ✓ Auto Ascend - Ascends at 100% (resets all progress!)
--  ✓ Anti-AFK - Prevents idle disconnect with button presses
--  ✓ Walk Speed Control - Adjustable player speed (16-150)
--  
--  UI: Rayfield (modern, responsive, organized tabs)
--  Created for Belle.sg community - optimized for speed
--  Paste into your executor and run while in "Sell Lemons 🍋"
--==============================================================
-- Load required modules from ReplicatedStorage
-- These are core components needed for automation
local RS=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local LP=Players.LocalPlayer

-- Safe require wrapper - prevents errors if module not found
local function req(p) local ok,m=pcall(require,p) return ok and m or nil end
local Tycoon=req(RS.Modules.Tycoon.Tycoon)
local TycoonBalances=req(RS.Modules.Tycoon.Component.TycoonBalances)
local ClientTycoonBalances=req(RS.Modules.Tycoon.Component.Client.ClientTycoonBalances)
local ClientTycoonRebirth=req(RS.Modules.Tycoon.Component.Client.ClientTycoonRebirth)
local ClientTycoonAscension=req(RS.Modules.Tycoon.Component.Client.ClientTycoonAscension)
local ClientTycoonEvolution=req(RS.Modules.Tycoon.Component.Client.ClientTycoonEvolution)
local ClientTycoonPowers=req(RS.Modules.Tycoon.Component.Client.ClientTycoonPowers)
local ClientTycoonPhoneOffers=req(RS.Modules.Tycoon.Component.Client.ClientTycoonPhoneOffers)
local RemoteSignal=req(RS.Core.RemoteSignal)
local RemoteRequest=req(RS.Core.RemoteRequest)
local Entity=req(RS.Core.Entity)
local Huge=req(RS.Modules.Huge)
local Config=req(RS.Config)

-- Global state dictionary - tracks which features are enabled
local State={
    AutoBuy=false,AutoUpgradeEarners=false,AutoUpgradePowers=false,
    AutoWake=false,AutoCashDrop=false,AutoPhone=false,AutoFruit=false,
    AutoRebirth=false,AutoEvolve=false,AutoAscend=false,
    AntiAFK=false,SpeedOn=false,SpeedVal=16,
}
local function getTycoon() return Tycoon and Tycoon.getLocal() end
-- Helper: Returns local player's tycoon instance if available

local function afford(price,cur) local ok,r=pcall(function() return price~=nil and price<=cur end) return ok and r end
-- Helper: Safely checks if player can afford a given price with current currency

-- Cache system for performance - stores references to purchase/earner parts
local _root,_buy,_earn=nil,{},{}
local function refreshCaches(t)
    -- Refreshes cached references to all purchasable items and earning machines
    -- Called each frame to ensure accuracy with game state
    if not t or not t.Instance then return end
    if _root==t.Instance and #_buy>0 then return end
    _root,_buy,_earn=t.Instance,{},{}
    for _,i in CollectionService:GetTagged("Tycoon.Purchase") do if i:IsDescendantOf(_root) then table.insert(_buy,i) end end
    for _,i in CollectionService:GetTagged("Tycoon.Earner") do if i:IsDescendantOf(_root) then table.insert(_earn,i) end end
end

-- Core automation function: Purchase affordable items from shop
local function doAutoBuy(t)
    -- Iterates through all purchasable items and buys if affordable
    -- Skips special/locked items automatically
    local bal=t:GetComponent(TycoonBalances) if not bal then return end
    for _,inst in _buy do
        if not State.AutoBuy then return end
        if inst:GetAttribute("Shown") and not inst:GetAttribute("Purchased") then
            local e=Entity.getUnsafe(inst)
            if e and not e.Special then
                local okp,price=pcall(function() return e:GetPrice() end)
                if okp and afford(price,bal:GetCash()) then pcall(function() e:TryPurchaseAsync(false) end) end
            end
        end
    end
end
local function doUpgradeEarners(t)
    local bal=t:GetComponent(TycoonBalances) if not bal then return end
    for _,inst in _earn do
        if not State.AutoUpgradeEarners then return end
        local e=Entity.getUnsafe(inst)
        if e then
            local okl,lvl=pcall(function() return e:GetUpgradeLevel() end)
            if okl then
                local ok,price,count=pcall(function() return e:GetUpgradePrice(lvl,math.huge,bal:GetCash()) end)
                if ok and count and count>0 then pcall(function() e:UpgradeAsync(count) end) end
            end
        end
    end
end
local function doUpgradePowers(t)
    local bal=t:GetComponent(ClientTycoonBalances) if not bal then return end
    local pw=t:GetComponent(ClientTycoonPowers) if not (pw and Config) then return end
    for name in pairs(Config.Powers) do
        if not State.AutoUpgradePowers then return end
        local okl,lvl=pcall(function() return pw:GetLevel(name) end)
        local okm,maxl=pcall(function() return pw:GetMaxLevel(name) end)
        if okl and okm and maxl and lvl<maxl then
            local okp,price=pcall(function() return pw:GetUpgradePrice(name) end)
            local oki,inv=pcall(function() return bal:GetInvestors() end)
            if okp and price and oki and afford(price,inv) then pcall(function() pw:UpgradeAsync(name) end) end
        end
    end
end
local function doWake(t)
    for _,inst in _earn do
        if not State.AutoWake then return end
        local e=Entity.getUnsafe(inst)
        if e and e.WakeAsync then pcall(function() e:WakeAsync() end) end
    end
end
local _phoneCd=0
local function doPhone(t)
    if os.clock()<_phoneCd then return end
    local po=t:GetComponent(ClientTycoonPhoneOffers) if not po then return end
    local ok,offer=pcall(function() return po:GetCurrentOffer() end)
    if ok and type(offer)=="number" then pcall(function() po:AcceptOffer() end) _phoneCd=os.clock()+1.5 end
end
local function tryRebirth(t)
    local rb=t:GetComponent(ClientTycoonRebirth) if not rb then return end
    local ok,pot=pcall(function() return rb:GetPotentialInvestors() end) if not ok then return end
    local cok,ready=pcall(function() return Huge.one<pot end)
    if cok and ready then pcall(function() rb:RebirthAsync(false) end) end
end
local function tryEvolve(t)
    local ev=t:GetComponent(ClientTycoonEvolution) if not ev then return end
    local ok,p=pcall(function() return ev:GetEvolutionProgress() end)
    if ok and type(p)=="number" and p>=1 then pcall(function() ev:EvolveAsync() end) end
end
local function tryAscend(t)
    local a=t:GetComponent(ClientTycoonAscension) if not a then return end
    local okd,d=pcall(function() return a:IsDiscovered() end) if not(okd and d) then return end
    local ok,p=pcall(function() return a:GetAscension() end)
    if ok and type(p)=="number" and p>=1 then pcall(function() a:AscendAsync() end) end
end

-- Cash drops
do
    local ok,redeem=pcall(function() return RemoteRequest.new("CashDropService.Redeem") end)
    local ok2,newSig=pcall(function() return RemoteSignal.new("CashDropService.New") end)
    if ok and ok2 and redeem and newSig then
        newSig.OnClientEvent:Connect(function(id) if State.AutoCashDrop and id~=nil then pcall(function() redeem:InvokeServer(id) end) end end)
    end
end
-- Anti-AFK
do local vu=game:GetService("VirtualUser")
    LP.Idled:Connect(function() if State.AntiAFK then pcall(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end) end end)
end
-- Walk speed
RunService.Heartbeat:Connect(function()
    if State.SpeedOn then local c=LP.Character local h=c and c:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed~=State.SpeedVal then h.WalkSpeed=State.SpeedVal end end
end)

-- AUTO FRUIT (teleport-harvest the orchard)
-- Automatically collects all fruit from lemon trees by teleporting
local _fruit,_savedCF={},nil
local function gatherFruit()
    -- Scans workspace for all ClickPart objects in Fruit containers
    -- Identifies which fruits belong to player's tycoon
    -- Stores references for automated harvesting loop
    _fruit={}
    local myT=getTycoon() and getTycoon().Instance
    for _,d in workspace:GetDescendants() do
        if d:IsA("BasePart") and d.Name=="ClickPart" and d.Parent and d.Parent.Name=="Fruit" then
            local a=d while a.Parent and a.Parent~=workspace do a=a.Parent end
            local mine=(a.Name=="LemonTree") or (myT and d:IsDescendantOf(myT))
            if mine then local cd=d:FindFirstChildOfClass("ClickDetector") if cd then table.insert(_fruit,{part=d,cd=cd}) end end
        end
    end
end
task.spawn(function()
    -- Main fruit harvesting loop - runs continuously
    -- Teleports player to each fruit location and clicks detector
    -- Respects saved player position when feature disabled
    local idx=1
    while true do
        if State.AutoFruit then
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not _savedCF and hrp then _savedCF=hrp.CFrame gatherFruit() idx=1 end
            if hrp and #_fruit>0 then
                local f=_fruit[idx]
                if f and f.part and f.part.Parent then
                    hrp.CFrame=CFrame.new(f.part.Position+Vector3.new(0,4,0))
                    task.wait(0.1)
                    local o=hrp.Position
                    for _,g in _fruit do
                        if g.part and g.part.Parent and (g.part.Position-o).Magnitude<=g.cd.MaxActivationDistance then
                            pcall(function() fireclickdetector(g.cd) end)
                        end
                    end
                end
                idx=idx+8 if idx>#_fruit then idx=1 end
            end
            task.wait(0.05)
        else
            if _savedCF then local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then pcall(function() hrp.CFrame=_savedCF end) end _savedCF=nil end
            task.wait(0.2)
        end
    end
end)

--========================= RAYFIELD GUI =========================
local Rayfield=loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window=Rayfield:CreateWindow({Name="🍋 Belle.sg | Sell Lemons Farm",LoadingTitle="Loading...",LoadingSubtitle="by ruey",ConfigurationSaving={Enabled=false},KeySystem=false})

-- UI Color Scheme (kept for reference, used in Rayfield theme)
local ACCENT=Color3.fromRGB(242,201,76)
local BG=Color3.fromRGB(22,23,28)
local BG2=Color3.fromRGB(31,33,40)
local BG3=Color3.fromRGB(45,47,56)
local TXT=Color3.fromRGB(236,238,243)
local SUB=Color3.fromRGB(146,150,162)
local OFFCOL=Color3.fromRGB(66,68,78)

local MainTab=Window:CreateTab("Auto Farm",4483345998)
local S1=MainTab:CreateSection("Buy & Upgrade")
S1:CreateToggle({Name="Auto Buy Tiles",CurrentValue=false,Flag="AutoBuy",Callback=function(v) State.AutoBuy=v end})
S1:CreateToggle({Name="Auto Upgrade Earners",CurrentValue=false,Flag="AutoUpgradeEarners",Callback=function(v) State.AutoUpgradeEarners=v end})
S1:CreateToggle({Name="Auto Upgrade Powers",CurrentValue=false,Flag="AutoUpgradePowers",Callback=function(v) State.AutoUpgradePowers=v end})

local S2=MainTab:CreateSection("Harvest & Collect")
S2:CreateToggle({Name="Auto Collect Fruit",CurrentValue=false,Flag="AutoFruit",Callback=function(v) State.AutoFruit=v end})
S2:CreateToggle({Name="Auto Wake Earners",CurrentValue=false,Flag="AutoWake",Callback=function(v) State.AutoWake=v end})
S2:CreateToggle({Name="Auto Collect Cash Drops",CurrentValue=false,Flag="AutoCashDrop",Callback=function(v) State.AutoCashDrop=v end})
S2:CreateToggle({Name="Auto Phone Deals",CurrentValue=false,Flag="AutoPhone",Callback=function(v) State.AutoPhone=v end})

local ProgressTab=Window:CreateTab("Progression",4483345998)
local S3=ProgressTab:CreateSection("Resets & Upgrades")
S3:CreateToggle({Name="Auto Rebirth",CurrentValue=false,Flag="AutoRebirth",Callback=function(v) State.AutoRebirth=v end})
S3:CreateToggle({Name="Auto Evolve",CurrentValue=false,Flag="AutoEvolve",Callback=function(v) State.AutoEvolve=v end})
S3:CreateToggle({Name="Auto Ascend",CurrentValue=false,Flag="AutoAscend",Callback=function(v) State.AutoAscend=v end})

local UtilityTab=Window:CreateTab("Utility",4483345998)
local S4=UtilityTab:CreateSection("Protection & Speed")
S4:CreateToggle({Name="Anti-AFK",CurrentValue=false,Flag="AntiAFK",Callback=function(v) State.AntiAFK=v end})
S4:CreateToggle({Name="Walk Speed Enabled",CurrentValue=false,Flag="SpeedOn",Callback=function(v) State.SpeedOn=v end})
S4:CreateSlider({Name="Walk Speed",Min=16,Max=150,Default=16,Color=Color3.fromRGB(255,85,127),Increment=1,Suffix="",Callback=function(v) State.SpeedVal=v end})

local StatsTab=Window:CreateTab("Stats",4483345998)
local S5=StatsTab:CreateSection("Tycoon Status")
local CashL=S5:CreateLabel("💰 Cash: --")
local InvL=S5:CreateLabel("📈 Investors: --")
local RebL=S5:CreateLabel("♻️ Rebirths: --")
local EvoL=S5:CreateLabel("⭐ Evolve: --%")
local StatL=S5:CreateLabel("Status: Idle")

-- Main automation loop - executes all enabled features
-- Updates UI with current tycoon statistics in real-time
-- Runs every 0.1 seconds to balance responsiveness and performance
task.spawn(function()
    while Window do
        local t=getTycoon()
        if t then refreshCaches(t)
            pcall(function()
                -- Update balance displays from tycoon component
                local bal=t:GetComponent(ClientTycoonBalances) or t:GetComponent(TycoonBalances)
                if bal then
                    pcall(function() CashL:Set("💰 Cash: "..Huge.formatShort(bal:GetCash())) end)
                    pcall(function() InvL:Set("📈 Investors: "..Huge.formatShort(bal:GetInvestors())) end)
                end
                
                -- Update progression displays
                local rb=t:GetComponent(ClientTycoonRebirth) if rb then pcall(function() RebL:Set("♻️ Rebirths: "..tostring(rb:GetRebirths())) end) end
                local ev=t:GetComponent(ClientTycoonEvolution) if ev then pcall(function() EvoL:Set("⭐ Evolve: "..string.format("%.0f%%",math.clamp(ev:GetEvolutionProgress()*100,0,100))) end) end
                
                -- Execute enabled automation features
                local acts={}
                if State.AutoBuy then doAutoBuy(t) table.insert(acts,"buy") end
                if State.AutoUpgradeEarners then doUpgradeEarners(t) table.insert(acts,"upg") end
                if State.AutoUpgradePowers then doUpgradePowers(t) table.insert(acts,"pow") end
                if State.AutoWake then doWake(t) table.insert(acts,"wake") end
                if State.AutoPhone then doPhone(t) table.insert(acts,"deal") end
                if State.AutoFruit then table.insert(acts,"fruit") end
                if State.AutoRebirth then tryRebirth(t) table.insert(acts,"rebirth") end
                if State.AutoEvolve then tryEvolve(t) table.insert(acts,"evolve") end
                if State.AutoAscend then tryAscend(t) table.insert(acts,"ascend") end
                
                -- Update status label with currently running features
                StatL:Set("Status: "..(#acts>0 and table.concat(acts,", ") or "Idle"))
            end)
        else StatL:Set("Status: Waiting for tycoon...") end
        task.wait(0.1)
    end
end)

print("[Belle.sg Sell Lemons Farm] v4 Rayfield Edition loaded!")
Rayfield:Notify({Title="Belle.sg Loaded",Content="Sell Lemons Farm v4 - All features ready!",Duration=5,Image=4483345998})

-- ============================================================
-- BELLE.SG SELL LEMONS FARM v4 - RAYFIELD UI EDITION
-- All gameplay features fully preserved from original script
-- UI completely replaced with modern Rayfield interface
-- Maintains 100% functionality with improved user experience
-- Visit https://discord.gg/belleSG for updates and support
-- ============================================================
