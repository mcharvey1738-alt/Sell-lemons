--==============================================================
--  🍋 BELLE.SG SELL LEMONS — AUTO FARM  (v4 — Fluent UI)
--  Paste into your executor and run while in "Sell Lemons 🍋".
--==============================================================
local RS=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local LP=Players.LocalPlayer

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

local State={
    AutoBuy=false,AutoUpgradeEarners=false,AutoUpgradePowers=false,
    AutoWake=false,AutoCashDrop=false,AutoPhone=false,AutoFruit=false,
    AutoRebirth=false,AutoEvolve=false,AutoAscend=false,
    AntiAFK=false,SpeedOn=false,SpeedVal=16,
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

-- AUTO FRUIT
local _fruit,_savedCF={},nil
local function gatherFruit()
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

-- FLUENT UI
local Library=loadstring(game:HttpGet("https://raw.githubusercontent.com/Synergy-Coder/Fluent/main/Fluent.lua"))()
local Save=loadstring(game:HttpGet("https://raw.githubusercontent.com/Synergy-Coder/Fluent/main/SaveManager.lua"))()
local Window=Library:CreateWindow({Title="🍋 Belle.sg | Sell Lemons Farm",SubTitle="v4",TabWidth=200,Size=UDim2.new(0,800,0,600),Acrylic=true,Theme="Dark",MinimizeKey=Enum.KeyCode.LeftControl})

local Tabs={}
Tabs.Farm=Window:AddTab("Auto Farm")
Tabs.Progress=Window:AddTab("Progression")
Tabs.Utility=Window:AddTab("Utility")
Tabs.Stats=Window:AddTab("Stats")

Tabs.Farm:AddToggle("AutoBuy",{Title="Auto Buy Tiles",Default=false,Callback=function(v) State.AutoBuy=v end})
Tabs.Farm:AddToggle("AutoUpgradeEarners",{Title="Auto Upgrade Earners",Default=false,Callback=function(v) State.AutoUpgradeEarners=v end})
Tabs.Farm:AddToggle("AutoUpgradePowers",{Title="Auto Upgrade Powers",Default=false,Callback=function(v) State.AutoUpgradePowers=v end})
Tabs.Farm:AddToggle("AutoFruit",{Title="Auto Collect Fruit",Default=false,Callback=function(v) State.AutoFruit=v end})
Tabs.Farm:AddToggle("AutoWake",{Title="Auto Wake Earners",Default=false,Callback=function(v) State.AutoWake=v end})
Tabs.Farm:AddToggle("AutoCashDrop",{Title="Auto Collect Cash Drops",Default=false,Callback=function(v) State.AutoCashDrop=v end})
Tabs.Farm:AddToggle("AutoPhone",{Title="Auto Phone Deals",Default=false,Callback=function(v) State.AutoPhone=v end})

Tabs.Progress:AddToggle("AutoRebirth",{Title="Auto Rebirth",Default=false,Callback=function(v) State.AutoRebirth=v end})
Tabs.Progress:AddToggle("AutoEvolve",{Title="Auto Evolve",Default=false,Callback=function(v) State.AutoEvolve=v end})
Tabs.Progress:AddToggle("AutoAscend",{Title="Auto Ascend",Default=false,Callback=function(v) State.AutoAscend=v end})

Tabs.Utility:AddToggle("AntiAFK",{Title="Anti-AFK",Default=false,Callback=function(v) State.AntiAFK=v end})
Tabs.Utility:AddToggle("SpeedOn",{Title="Walk Speed Enabled",Default=false,Callback=function(v) State.SpeedOn=v end})
Tabs.Utility:AddSlider("Speed",{Title="Walk Speed",Min=16,Max=150,Default=16,Rounding=1,Callback=function(v) State.SpeedVal=v end})

local CashLabel=Tabs.Stats:AddLabel("💰 Cash: --")
local InvLabel=Tabs.Stats:AddLabel("📈 Investors: --")
local RebLabel=Tabs.Stats:AddLabel("♻️ Rebirths: --")
local EvoLabel=Tabs.Stats:AddLabel("⭐ Evolve: --%")
local StatusLabel=Tabs.Stats:AddLabel("Status: Idle")

task.spawn(function()
    while window~=nil do
        local t=getTycoon()
        if t then refreshCaches(t)
            pcall(function()
                local bal=t:GetComponent(ClientTycoonBalances) or t:GetComponent(TycoonBalances)
                if bal then
                    pcall(function() CashLabel:UpdateLabel("💰 Cash: "..Huge.formatShort(bal:GetCash())) end)
                    pcall(function() InvLabel:UpdateLabel("📈 Investors: "..Huge.formatShort(bal:GetInvestors())) end)
                end
                local rb=t:GetComponent(ClientTycoonRebirth) if rb then pcall(function() RebLabel:UpdateLabel("♻️ Rebirths: "..tostring(rb:GetRebirths())) end) end
                local ev=t:GetComponent(ClientTycoonEvolution) if ev then pcall(function() EvoLabel:UpdateLabel("⭐ Evolve: "..string.format("%.0f%%",math.clamp(ev:GetEvolutionProgress()*100,0,100))) end) end
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
                StatusLabel:UpdateLabel("Status: "..(#acts>0 and table.concat(acts,", ") or "Idle"))
            end)
        else StatusLabel:UpdateLabel("Status: Waiting for tycoon...") end
        task.wait(0.1)
    end
end)

print("[Belle.sg Sell Lemons Farm] v4 loaded!")
Library:Notify("Belle.sg Loaded","Sell Lemons Farm v4 - All features ready!")
