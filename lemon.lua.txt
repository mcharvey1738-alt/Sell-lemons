-- ================================================
-- 🍋 SELL LEMONS — AUTO FARM (Rayfield UI Version)
-- ================================================

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "🍋 Sell Lemons Farm",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by BELLE.SG",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

local RS=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local LP=Players.LocalPlayer

local function req(p) local ok,m=pcall(require,p) return ok and m or nil end
local Tycoon                = req(RS.Modules.Tycoon.Tycoon)
local TycoonBalances        = req(RS.Modules.Tycoon.Component.TycoonBalances)
local ClientTycoonBalances  = req(RS.Modules.Tycoon.Component.Client.ClientTycoonBalances)
local ClientTycoonRebirth   = req(RS.Modules.Tycoon.Component.Client.ClientTycoonRebirth)
local ClientTycoonAscension = req(RS.Modules.Tycoon.Component.Client.ClientTycoonAscension)
local ClientTycoonEvolution = req(RS.Modules.Tycoon.Component.Client.ClientTycoonEvolution)
local ClientTycoonPowers    = req(RS.Modules.Tycoon.Component.Client.ClientTycoonPowers)
local ClientTycoonPhoneOffers=req(RS.Modules.Tycoon.Component.Client.ClientTycoonPhoneOffers)
local RemoteSignal          = req(RS.Core.RemoteSignal)
local RemoteRequest         = req(RS.Core.RemoteRequest)
local Entity                = req(RS.Core.Entity)
local Huge                  = req(RS.Modules.Huge)
local Config                = req(RS.Config)

local State={
    AutoBuy=false, AutoUpgradeEarners=false, AutoUpgradePowers=false,
    AutoWake=false, AutoCashDrop=false, AutoPhone=false, AutoFruit=false,
    AutoRebirth=false, AutoEvolve=false, AutoAscend=false,
    AntiAFK=false, SpeedOn=false, SpeedVal=16,
}

local function getTycoon() return Tycoon and Tycoon.getLocal() end
local function afford(price,cur) local ok,r=pcall(function() return price~=nil and price<=cur end) return ok and r end

local _root,_buy,_earn=nil,{},{}
local function refreshCaches(t)
    if not t or not t.Instance then return end
    if _root==t.Instance and #_buy>0 then return end
    _root,_buy,_earn=t.Instance,{},{}
    for _,i in CollectionService:GetTagged("Tycoon.Purchase") do if i:IsDescendantOf(_root) then table.insert(_buy,i) end end
    for _,i in CollectionService:GetTagged("Tycoon.Earner") do if i:IsDescendantOf(_root) then table.insert(_earn,i) end end
end

local function doAutoBuy(t)
    local bal=t:GetComponent(TycoonBalances); if not bal then return end
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
    local bal=t:GetComponent(TycoonBalances); if not bal then return end
    for _,inst in _earn do
        if not State.AutoUpgradeEarners then return end
        local e=Entity.getUnsafe(inst)
        if e then
            local okl,lvl=pcall(function() return e:GetUpgradeLevel() end)
            if okl then
                local ok,price,count=pcall(function() return e:GetUpgradePrice(lvl, math.huge, bal:GetCash()) end)
                if ok and count and count>0 then pcall(function() e:UpgradeAsync(count) end) end
            end
        end
    end
end

local function doUpgradePowers(t)
    local bal=t:GetComponent(ClientTycoonBalances); if not bal then return end
    local pw=t:GetComponent(ClientTycoonPowers); if not (pw and Config) then return end
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
    local ph=t:GetComponent(ClientTycoonPhoneOffers); if not ph then return end
    pcall(function() local o=ph:GetOffer() if o and o.Amount then ph:AcceptOfferAsync() _phoneCd=os.clock()+0.5 end end)
end

local function doFruit(t)
    local ws=LP.Character and LP.Character:FindFirstChild("Humanoid") if not ws then return end
    for _,i in CollectionService:GetTagged("TreeFruit") do
        if not State.AutoFruit then return end
        if i and i:IsDescendantOf(workspace) then
            local pf=i:FindFirstChildOfClass("ProximityPrompt")
            if pf then pcall(function() fireproximityprompt(pf) end) task.wait(0.1) end
        end
    end
end

local function doCashDrop(t)
    for _,i in CollectionService:GetTagged("CashDrop") do
        if not State.AutoCashDrop then return end
        if i and i:IsDescendantOf(workspace) then
            local pf=i:FindFirstChildOfClass("ProximityPrompt")
            if pf then pcall(function() fireproximityprompt(pf) end) end
        end
    end
end

local function tryRebirth(t)
    local rb=t:GetComponent(ClientTycoonRebirth); if not rb then return end
    local bal=t:GetComponent(ClientTycoonBalances) or t:GetComponent(TycoonBalances)
    if bal and bal:GetInvestors()>1 then pcall(function() rb:RebirthAsync() end) end
end

local function tryEvolve(t)
    local ev=t:GetComponent(ClientTycoonEvolution); if not ev then return end
    if ev:GetEvolutionProgress()>=1 then pcall(function() ev:EvolveAsync() end) end
end

local function tryAscend(t)
    local as=t:GetComponent(ClientTycoonAscension); if not as then return end
    if as:GetAscensionProgress()>=1 then pcall(function() as:AscendAsync() end) end
end

-- ================================================
-- RAYFIELD TABS & TOGGLES
-- ================================================

local AutoFarmTab = Window:CreateTab("Auto Farm", 0)
local ProgressionTab = Window:CreateTab("Progression", 0)
local UtilityTab = Window:CreateTab("Utility", 0)

-- Auto Farm Section
AutoFarmTab:CreateToggle({
    Name = "Auto Buy Tiles",
    Callback = function(v) State.AutoBuy = v end,
    Default = false
}):CreateLabel("Buys affordable purchase tiles")

AutoFarmTab:CreateToggle({
    Name = "Auto Upgrade Earners",
    Callback = function(v) State.AutoUpgradeEarners = v end,
    Default = false
}):CreateLabel("Bulk-levels income machines (cash)")

AutoFarmTab:CreateToggle({
    Name = "Auto Upgrade Powers",
    Callback = function(v) State.AutoUpgradePowers = v end,
    Default = false
}):CreateLabel("Spends investors on powers")

AutoFarmTab:CreateToggle({
    Name = "Auto Collect Fruit",
    Callback = function(v) State.AutoFruit = v end,
    Default = false
}):CreateLabel("Harvests lemons (moves you to trees)")

AutoFarmTab:CreateToggle({
    Name = "Auto Wake Earners",
    Callback = function(v) State.AutoWake = v end,
    Default = false
}):CreateLabel("Taps manual machines")

AutoFarmTab:CreateToggle({
    Name = "Auto Collect Cash Drops",
    Callback = function(v) State.AutoCashDrop = v end,
    Default = false
}):CreateLabel("Instantly grabs cash drops")

AutoFarmTab:CreateToggle({
    Name = "Auto Phone Deals",
    Callback = function(v) State.AutoPhone = v end,
    Default = false
}):CreateLabel("Accepts phone cash offers")

-- Progression Section
ProgressionTab:CreateToggle({
    Name = "Auto Rebirth",
    Callback = function(v) State.AutoRebirth = v end,
    Default = false
}):CreateLabel("Rebirths when worth >1 investor")

ProgressionTab:CreateToggle({
    Name = "Auto Evolve",
    Callback = function(v) State.AutoEvolve = v end,
    Default = false
}):CreateLabel("Evolves at 100% progress")

ProgressionTab:CreateToggle({
    Name = "Auto Ascend",
    Callback = function(v) State.AutoAscend = v end,
    Default = false
}):CreateLabel("Ascends at 100% (resets all!)")

-- Utility Section
UtilityTab:CreateToggle({
    Name = "Anti-AFK",
    Callback = function(v) State.AntiAFK = v end,
    Default = false
}):CreateLabel("Prevents idle disconnect")

UtilityTab:CreateSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 150,
    Default = 16,
    Callback = function(v)
        State.SpeedVal = v
        if LP.Character and LP.Character:FindFirstChild("Humanoid") then
            LP.Character.Humanoid.WalkSpeed = v
        end
    end
})

-- ================================================
-- MAIN LOOP
-- ================================================

task.spawn(function()
    while Window ~= nil do
        local t=getTycoon()
        if t then
            refreshCaches(t)
            pcall(function()
                if State.AutoBuy then doAutoBuy(t) end
                if State.AutoUpgradeEarners then doUpgradeEarners(t) end
                if State.AutoUpgradePowers then doUpgradePowers(t) end
                if State.AutoWake then doWake(t) end
                if State.AutoPhone then doPhone(t) end
                if State.AutoFruit then doFruit(t) end
                if State.AutoRebirth then tryRebirth(t) end
                if State.AutoEvolve then tryEvolve(t) end
                if State.AutoAscend then tryAscend(t) end
                if State.AntiAFK then
                    if LP.Character and LP.Character:FindFirstChild("Humanoid") then
                        LP.Character.Humanoid:MoveTo(LP.Character.HumanoidRootPart.Position)
                    end
                end
                if State.SpeedOn and LP.Character and LP.Character:FindFirstChild("Humanoid") then
                    LP.Character.Humanoid.WalkSpeed = State.SpeedVal
                end
            end)
        end
        task.wait(0.1)
    end
end)

print("[Sell Lemons Farm] Rayfield version loaded")
Rayfield:Notify({
    Title = "Loaded!",
    Content = "Sell Lemons Farm is ready",
    Duration = 2
})
