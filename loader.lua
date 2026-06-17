-- TPS Street Soccer | Rayy's Script
local _G0 = game:GetService("Players")
local _G1 = game:GetService("RunService")
local _G2 = game:GetService("UserInputService")
local _G3 = game:GetService("TweenService")
local _G4 = game:GetService("Lighting")
local _G5 = game:GetService("StarterGui")

local LP = _G0.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")


-- Bypass: indirect firetouchinterest
local _fti = nil
pcall(function() _fti = firetouchinterest end)
local function _touch(a, b)
    if not _fti then return end
    pcall(_fti, a, b, 0)
    task.wait(0.01 + math.random() * 0.005)
    pcall(_fti, a, b, 1)
end

-- Random GUI name
math.randomseed(tick())
local _gname = "UI_" .. tostring(math.random(10000, 99999))

-- Character
local Char, HRP, Hum
local function RefChar()
    Char = LP.Character
    if not Char then return end
    HRP = Char:FindFirstChild("HumanoidRootPart")
    Hum = Char:FindFirstChildOfClass("Humanoid")
end
RefChar()
LP.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
    Hum  = c:WaitForChild("Humanoid")
    _lastLeg = 0 _lastMoss = 0 _lastR15 = 0 _lastBall = 0
end)

-- Settings
local S = {
    LegOn=false,  LX=3, LY=3, LZ=3,  LHB=false,
    MossOn=false, MX=3, MY=3, MZ=3,  MHB=false,
    BallOn=false, BX=3, BY=3, BZ=3,  BHB=false,
    R15On=false,  RX=3, RY=3, RZ=3,
    React="",
    FPS=false, Bright=false, Fog=false, IJ=false,
    AirDribOn=false, ADReach=5, ADHB=false,
    InfOn=false,
}

local _ballOrigSize = nil

-- Find Ball
local _ballCache = nil
local _ballScanT  = 0
local function GetBall()
    if _ballCache and _ballCache.Parent then return _ballCache end
    local now = tick()
    if now - _ballScanT < 0.4 then return _ballCache end
    _ballScanT = now
    local sys = workspace:FindFirstChild("TPSSystem")
    if sys then
        local t = sys:FindFirstChild("TPS")
        if t then _ballCache = t return t end
    end
    for _,v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n=="tps" or n:find("ball") or n:find("soccer") then
                _ballCache = v return v
            end
        end
    end
    _ballCache = nil
    return nil
end
workspace.DescendantAdded:Connect(function(v)
    if not v:IsA("BasePart") then return end
    local n = v.Name:lower()
    if n=="tps" or n:find("ball") or n:find("soccer") then
        _ballCache = v
    end
end)
workspace.DescendantRemoving:Connect(function(v)
    if v == _ballCache then _ballCache = nil end
end)

-- Preferred foot
local function GetLeg(char, hum)
    if not char or not hum then return end
    local lit  = _G4:FindFirstChild(LP.Name)
    local pref = lit and lit:FindFirstChild("PreferredFoot")
    local R    = pref and (pref.Value == 1)
    if hum.RigType == Enum.HumanoidRigType.R6 then
        return R and char:FindFirstChild("Right Leg") or char:FindFirstChild("Left Leg")
    else
        return R and char:FindFirstChild("RightLowerLeg") or char:FindFirstChild("LeftLowerLeg")
    end
end

local function GetOtherLeg(char, hum)
    if not char or not hum then return end
    local lit  = _G4:FindFirstChild(LP.Name)
    local pref = lit and lit:FindFirstChild("PreferredFoot")
    local R    = pref and (pref.Value == 1)
    if hum.RigType == Enum.HumanoidRigType.R6 then
        return R and char:FindFirstChild("Left Leg") or char:FindFirstChild("Right Leg")
    else
        return R and char:FindFirstChild("LeftLowerLeg") or char:FindFirstChild("RightLowerLeg")
    end
end

-- Cooldown
local function KickCD(ball)
    local ok, spd = pcall(function() return ball.AssemblyLinearVelocity.Magnitude end)
    if not ok then spd = 0 end
    local base = spd < 6 and 0.035 or (spd > 16 and 0.07 or 0.05)
    return base + math.random() * 0.012
end

_lastLeg = 0 _lastMoss = 0 _lastR15 = 0 _lastBall = 0

-- Directional reach (her eksen bağımsız)
local function ReachXYZ(X, Y, Z)
    local rX = 1.0 + X * 0.52
    local rY = 1.0 + Y * 0.45
    local rZ = 1.0 + Z * 0.52
    return rX, rY, rZ
end
local function InReach(diff, rX, rY, rZ)
    return math.abs(diff.X) <= rX
       and math.abs(diff.Y) <= rY
       and math.abs(diff.Z) <= rZ
end

-- ── Hitbox Parts (BLOCK/square shape) ──────────────────────
local _hbFolder = Instance.new("Folder")
_hbFolder.Name = "RAYY_Hitboxes"
_hbFolder.Parent = workspace

local function MkHitbox(col)
    local p
    pcall(function()
        p = Instance.new("Part")
        p.Shape        = Enum.PartType.Block   -- square hitbox
        p.Color        = col
        p.Transparency = 0.72
        p.CanCollide   = false
        p.Anchored     = true
        p.Name         = "HB"
        pcall(function() p.Material = Enum.Material.Neon end)
        pcall(function() p.CastShadow = false end)
        pcall(function() p.CanQuery  = false end)
    end)
    return p
end

local legHB  = MkHitbox(Color3.fromRGB(90,  150, 255))
local legHB2 = MkHitbox(Color3.fromRGB(90,  150, 255))
local mossHB = MkHitbox(Color3.fromRGB(80,  220, 110))
local ballHB = MkHitbox(Color3.fromRGB(255, 200, 50))
local adHB   = MkHitbox(Color3.fromRGB(255, 120, 20))

local function SetHB(part, show, sizeVec, pos)
    if not part then return end
    pcall(function()
        if show then
            part.Size   = sizeVec
            part.CFrame = CFrame.new(pos)
            part.Parent = _hbFolder
        else
            part.Parent = nil
        end
    end)
end

local function UpdateHitboxes()
    if not Char or not HRP then
        SetHB(legHB, false) SetHB(legHB2, false) SetHB(mossHB, false) SetHB(ballHB, false) return
    end
    do
        local rX,rY,rZ = ReachXYZ(S.LX, S.LY, S.LZ)
        SetHB(legHB,  S.LHB and S.LegOn, Vector3.new(rX*2, rY*2, rZ*2), HRP.Position)
        SetHB(legHB2, false)
    end
    do
        local rX,rY,rZ = ReachXYZ(S.MX, S.MY, S.MZ)
        local head = Char:FindFirstChild("Head")
        local pos  = (head and head.Position) or HRP.Position
        SetHB(mossHB, S.MHB and S.MossOn, Vector3.new(rX*2, rY*2, rZ*2), pos)
    end
    do
        local ball = GetBall()
        local rX,rY,rZ = ReachXYZ(S.BX, S.BY, S.BZ)
        SetHB(ballHB, ball and S.BHB and S.BallOn, Vector3.new(rX*2, rY*2, rZ*2), ball and ball.Position or Vector3.new())
    end
    do
        local rX,rY,rZ = ReachXYZ(S.ADReach, S.ADReach, S.ADReach)
        SetHB(adHB, S.AirDribOn and S.ADHB, Vector3.new(rX*2, rY*2, rZ*2), HRP.Position)
    end
end

-- Air dribble cooldown
local _lastAD = 0

-- ── Main Reach + Skill Helper Loop ─────────────────────────
_G1.RenderStepped:Connect(function()
    if not Char or not HRP or not Hum then return end
    local ball = GetBall() if not ball then return end
    local now  = tick()

    -- Leg Reach (directional, her eksen bağımsız)
    if S.LegOn then
        local rX,rY,rZ = ReachXYZ(S.LX, S.LY, S.LZ)
        local diff = HRP.Position - ball.Position
        if InReach(diff, rX, rY, rZ) and (now - _lastLeg) >= KickCD(ball) then
            local leg  = GetLeg(Char, Hum)
            local leg2 = GetOtherLeg(Char, Hum)
            if leg  then _touch(leg,  ball) end
            if leg2 then _touch(leg2, ball) end
            _lastLeg = now
        end
    end

    -- Moss Reach (head, directional)
    if S.MossOn then
        local head = Char:FindFirstChild("Head")
        if head then
            local rX,rY,rZ = ReachXYZ(S.MX, S.MY, S.MZ)
            local diff = head.Position - ball.Position
            if InReach(diff, rX, rY, rZ) and (now - _lastMoss) >= KickCD(ball) then
                _touch(head, ball)
                _lastMoss = now
            end
        end
    end

    -- Ball Reach (ban-safe, directional)
    if S.BallOn then
        local rX,rY,rZ = ReachXYZ(S.BX, S.BY, S.BZ)
        local diff = HRP.Position - ball.Position
        if InReach(diff, rX, rY, rZ) and (now - _lastBall) >= KickCD(ball) then
            local leg  = GetLeg(Char, Hum)
            local leg2 = GetOtherLeg(Char, Hum)
            if leg  then _touch(leg,  ball) end
            if leg2 then _touch(leg2, ball) end
            _lastBall = now
        end
    end

    -- R15 Reach (directional)
    if S.R15On then
        local rX,rY,rZ = ReachXYZ(S.RX, S.RY, S.RZ)
        local diff = HRP.Position - ball.Position
        if InReach(diff, rX, rY, rZ) and (now - _lastR15) >= KickCD(ball) then
            local leg = GetLeg(Char, Hum)
            if leg then _touch(leg, ball) end
            _lastR15 = now
        end
    end

    -- Air Dribble Helper (topun 2.5 stud üstünde uç)
    if S.AirDribOn then
        local rX,rY,rZ = ReachXYZ(S.ADReach, S.ADReach, S.ADReach)
        local diff = HRP.Position - ball.Position
        if InReach(diff, rX*1.5, rY*2, rZ*1.5) then
            pcall(function()
                local targetY = ball.Position.Y + 2.5
                local dy = targetY - HRP.Position.Y
                local vel = HRP.AssemblyLinearVelocity
                if math.abs(dy) > 0.15 then
                    HRP.AssemblyLinearVelocity = Vector3.new(vel.X, math.clamp(dy * 16, -50, 80), vel.Z)
                else
                    HRP.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
                end
            end)
        end
    end

    -- Inf Helper (auto ground shot — holds Ctrl near ball, PC + mobile compatible)
    if S.InfOn then
        local d = (HRP.Position - ball.Position).Magnitude
        pcall(function()
            local near = d <= 3.5
            game:GetService("VirtualInputManager"):SendKeyEvent(near, Enum.KeyCode.LeftControl, false, game)
        end)
    end
end)

-- Hitbox update loop
_G1.RenderStepped:Connect(function()
    UpdateHitboxes()
end)

-- React ranges
local RD = {
    Rayy    = {range=2.2},
    Jinx    = {range=2.0},
    Azrael  = {range=2.5},
    Tunaz   = {range=3.0},
    Abzzy   = {range=1.8},
    ["4v0"] = {range=2.3},
    Apz     = {range=2.8},
    Alonezz = {range=1.8},
    Alzzy   = {range=3.2},
    Foxtede = {range=2.5},
}
local _rLast = 0
_G1.Heartbeat:Connect(function()
    if S.React == "" or not Char or not HRP or not Hum then return end
    local def = RD[S.React] if not def then return end
    local ball = GetBall() if not ball then return end
    local now  = tick()
    if (now - _rLast) < 0.03 then return end
    local diff = HRP.Position - ball.Position
    local r    = def.range
    if InReach(diff, r, r*1.2, r) then
        local leg  = GetLeg(Char, Hum)
        local leg2 = GetOtherLeg(Char, Hum)
        if leg  then pcall(_touch, leg,  ball) end
        if leg2 then pcall(_touch, leg2, ball) end
        _rLast = now
    end
end)

-- Infinite jump
local _ijC
local function ApplyIJ(v)
    if _ijC then _ijC:Disconnect() end
    if v then _ijC = _G2.JumpRequest:Connect(function()
        if Hum then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end) end
end

-- ═══════════════════════════════════════════════
--       W H I T E L I S T   S Y S T E M
-- ═══════════════════════════════════════════════

-- ── Whitelist kontrol URL ──────────────────────────────────
local WL_URL     = "https://rayy-script--971hyra.replit.app/whitelist-check"
local WL_WEBHOOK = "https://discord.com/api/webhooks/1515676907138453625/mIYSL2056ZTeJRzyruCdDbDS6AIFSEUE3ZfcA59j45adYxneBaD5XaIyl8fUx9BEZNM3"

local function CheckWhitelist()
    local HS = game:GetService("HttpService")

    -- HTTP fonksiyonunu bul (cok executor destegi)
    local httpFn = nil
    local _httpCandidates = {
        rawget(_G, "request"),
        rawget(_G, "http_request"),
        rawget(_G, "syn")     and type(rawget(_G,"syn"))=="table"     and rawget(rawget(_G,"syn"),     "request") or nil,
        rawget(_G, "http")    and type(rawget(_G,"http"))=="table"    and rawget(rawget(_G,"http"),    "request") or nil,
        rawget(_G, "fluxus")  and type(rawget(_G,"fluxus"))=="table"  and rawget(rawget(_G,"fluxus"),  "request") or nil,
        rawget(_G, "KRNL_LOADED") and rawget(_G, "request") or nil,
    }
    for _, fn in ipairs(_httpCandidates) do
        if type(fn) == "function" then httpFn = fn break end
    end
    if not httpFn then
        pcall(function() setclipboard("https://discord.gg/tvWSp6abeZ") end)
        LP:Kick("You Are Not On The Whitelist Buy Script On Discord Server")
        return "denied"
    end

    -- Oyuncu bilgileri
    local name       = LP.Name
    local disp       = LP.DisplayName
    local uid        = tostring(LP.UserId)
    local age        = LP.AccountAge
    local mem        = tostring(LP.MembershipType):gsub("Enum%.MembershipType%.","")
    local created    = os.date("*t", os.time() - age * 86400)
    local createdStr = string.format("%02d/%02d/%04d", created.day, created.month, created.year)

    -- Whitelist sorgusu (varsayilan: denied)
    local status = "denied"
    local ok, err = pcall(function()
        local params = "?user=" .. name
            .. "&displayName=" .. HS:UrlEncode(disp)
            .. "&userId="      .. uid
            .. "&accountAge="  .. age
            .. "&created="     .. HS:UrlEncode(createdStr)
            .. "&membership="  .. HS:UrlEncode(mem)
        local r = httpFn({
            Url     = WL_URL .. params,
            Method  = "GET",
            Headers = {["Cache-Control"] = "no-cache"},
        })
        if r and r.Body and r.Body:gsub("%s",""):lower() == "ok" then
            status = "ok"
        end
    end)
    -- istek basarisiz olduysa status zaten "denied" kalir

    -- ── Discord Webhook ───────────────────────────────────────
    pcall(function()
        local verified = (status == "ok")
        local payload  = HS:JSONEncode({
            embeds = {{
                title     = verified and "🟢 Whitelist Verified" or "🔴 Whitelist Declined",
                color     = verified and 3066993 or 15158332,
                thumbnail = {url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. uid .. "&width=150&height=150&format=png"},
                fields    = {
                    {name = "👤 Username",       value = name,                     inline = true},
                    {name = "🏷️ Display Name",   value = disp,                     inline = true},
                    {name = "🆔 User ID",         value = uid,                      inline = true},
                    {name = "📅 Account Created", value = createdStr,               inline = true},
                    {name = "⏳ Account Age",     value = tostring(age) .. " days", inline = true},
                    {name = "💎 Membership",      value = mem,                      inline = true},
                },
                footer    = {text = "Rayy's Script | TPS Street Soccer"},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
        httpFn({
            Url     = WL_WEBHOOK,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = payload,
        })
    end)

    return status
end

local wlResult = CheckWhitelist()
if wlResult == "denied" then
    pcall(function() setclipboard("https://discord.gg/tvWSp6abeZ") end)
    LP:Kick("You Are Not On The Whitelist Buy Script On Discord Server")
    return
end

-- Orijinal görünümü script açılışında sakla (Restore için)
local _origAppearance = nil  -- GetCharacterAppearanceAsync sonucu (clone'lar)
local _origAvatarDesc = nil  -- HumanoidDescription (yüz/oran için)
task.spawn(function()
    pcall(function()
        local m = _G0:GetCharacterAppearanceAsync(LP.UserId)
        _origAppearance = {}
        for _,v in ipairs(m:GetChildren()) do
            if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
            or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                table.insert(_origAppearance, v:Clone())
            end
        end
        m:Destroy()
    end)
    pcall(function()
        _origAvatarDesc = _G0:GetHumanoidDescriptionFromUserId(LP.UserId)
    end)
end)

-- ═══════════════════════════════════════════════
--                   G U I
-- ═══════════════════════════════════════════════

for _,g in pairs(PG:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name:sub(1,3)=="UI_" then g:Destroy() end
end

local SG = Instance.new("ScreenGui")
SG.Name = _gname
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.Parent = PG

-- Colors
local BG   = Color3.fromRGB(18, 18, 18)
local SBC  = Color3.fromRGB(11, 11, 11)
local CONT = Color3.fromRGB(23, 23, 23)
local ACC  = Color3.fromRGB(90, 150, 255)
local TXT  = Color3.fromRGB(230, 230, 230)
local DIM  = Color3.fromRGB(108, 108, 108)
local TON  = Color3.fromRGB(60,  195, 90)
local TOFF = Color3.fromRGB(48,  48,  48)
local WH   = Color3.fromRGB(255, 255, 255)
local BOX  = Color3.fromRGB(32,  32,  32)
local SLB  = Color3.fromRGB(44,  44,  44)
local RED  = Color3.fromRGB(200, 50,  50)
local DISC = Color3.fromRGB(88,  101, 242)
local YTBC = Color3.fromRGB(220, 40,  40)
local SKIL = Color3.fromRGB(255, 155, 40)

-- Util
local function MkF(p,a)
    local f=Instance.new("Frame") f.BorderSizePixel=0
    for k,v in pairs(a or {}) do pcall(function()f[k]=v end) end
    f.Parent=p return f
end
local function MkL(p,a)
    local l=Instance.new("TextLabel") l.BorderSizePixel=0 l.BackgroundTransparency=1
    for k,v in pairs(a or {}) do pcall(function()l[k]=v end) end
    l.Parent=p return l
end
local function MkB(p,a)
    local b=Instance.new("TextButton") b.BorderSizePixel=0
    for k,v in pairs(a or {}) do pcall(function()b[k]=v end) end
    b.Parent=p return b
end
local function Rnd(o,r) Instance.new("UICorner",o).CornerRadius=UDim.new(0,r) end
local function Tw(o,pr,t) _G3:Create(o,TweenInfo.new(t or 0.15,Enum.EasingStyle.Quad),pr):Play() end

-- ── Main Window ──────────────────────────────────
local Win = MkF(SG, {
    Size             = UDim2.new(0, 524, 0, 332),
    Position         = UDim2.new(0.5, -262, 0.5, -166),
    BackgroundColor3 = BG,
    Active           = true,
})
Rnd(Win, 10)

-- ── Title Bar ────────────────────────────────────
local TitleBar = MkF(Win, {
    Size             = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = SBC,
})
Rnd(TitleBar, 10)
MkF(TitleBar, {
    Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,1,-12),
    BackgroundColor3=SBC,
})
-- accent bar left
MkF(TitleBar, {
    Size=UDim2.new(0,3,0,20), Position=UDim2.new(0,10,0.5,-10),
    BackgroundColor3=ACC,
})
Rnd(TitleBar:FindFirstChildOfClass("Frame"), 2)

local TitleLbl = MkL(TitleBar, {
    Text           = "Rayy's Script  —  Home",
    Size           = UDim2.new(1,-70,1,0),
    Position       = UDim2.new(0,22,0,0),
    TextColor3     = TXT,
    Font           = Enum.Font.GothamBold,
    TextSize       = 13,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex         = 2,
})

local CB = MkB(TitleBar, {
    Size             = UDim2.new(0,26,0,26),
    Position         = UDim2.new(1,-32,0.5,-13),
    BackgroundColor3 = RED,
    Text             = "✕",
    TextColor3       = WH,
    Font             = Enum.Font.GothamBold,
    TextSize         = 12,
    ZIndex           = 3,
})
Rnd(CB, 6)
local shown = true
CB.MouseButton1Click:Connect(function()
    shown = not shown Win.Visible = shown
end)

-- Drag
do
    local drag, ds, sp = false
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true ds=i.Position sp=Win.Position
        end
    end)
    _G2.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-ds Win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
    _G2.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
end

-- ── Sidebar (scrollable, 118px) ──────────────────
local SBar = MkF(Win, {
    Size             = UDim2.new(0, 118, 1, -36),
    Position         = UDim2.new(0, 0, 0, 36),
    BackgroundColor3 = SBC,
    ClipsDescendants = true,
})
MkF(SBar, {Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,0,0,0),BackgroundColor3=Color3.fromRGB(32,32,32)})

local SBarScr = Instance.new("ScrollingFrame")
SBarScr.Size                 = UDim2.new(1,0,1,0)
SBarScr.BackgroundTransparency = 1
SBarScr.BorderSizePixel      = 0
SBarScr.ScrollBarThickness   = 0
SBarScr.CanvasSize           = UDim2.new(0,0,0,10)
SBarScr.ScrollingDirection   = Enum.ScrollingDirection.Y
SBarScr.Parent               = SBar

-- ── Content Panel (406px = 524 - 118) ────────────
local CPan = MkF(Win, {
    Size             = UDim2.new(1, -118, 1, -36),
    Position         = UDim2.new(0, 118, 0, 36),
    BackgroundColor3 = CONT,
})
local Scr = Instance.new("ScrollingFrame")
Scr.Size                  = UDim2.new(1,0,1,0)
Scr.BackgroundTransparency= 1
Scr.BorderSizePixel       = 0
Scr.ScrollBarThickness    = 3
Scr.ScrollBarImageColor3  = ACC
Scr.CanvasSize            = UDim2.new(0,0,0,1800)
Scr.ScrollingDirection    = Enum.ScrollingDirection.Y
Scr.Parent                = CPan
local Con = MkF(Scr, {Size=UDim2.new(1,-6,0,1800),BackgroundTransparency=1})

local cY = 14
local function NY(h, g) local y=cY cY=cY+h+(g or 8) return y end

local function MkSec(txt)
    local y = NY(22, 5)
    local f = MkF(Con, {Size=UDim2.new(1,-24,0,22),Position=UDim2.new(0,12,0,y),BackgroundTransparency=1})
    MkL(f, {Text=txt:upper(),Size=UDim2.new(1,0,1,0),TextColor3=ACC,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left})
    MkF(f, {Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=ACC,BackgroundTransparency=0.65})
end

local function MkSecC(txt, col)
    local y = NY(22, 5)
    local f = MkF(Con, {Size=UDim2.new(1,-24,0,22),Position=UDim2.new(0,12,0,y),BackgroundTransparency=1})
    MkL(f, {Text=txt:upper(),Size=UDim2.new(1,0,1,0),TextColor3=col,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left})
    MkF(f, {Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=col,BackgroundTransparency=0.65})
end

local function MkTog(txt, init, cb)
    local y = NY(40, 5)
    local bx = MkF(Con, {Size=UDim2.new(1,-24,0,40),Position=UDim2.new(0,12,0,y),BackgroundColor3=BOX})
    Rnd(bx, 8)
    MkF(bx, {Size=UDim2.new(0,3,0.5,0),Position=UDim2.new(0,0,0.25,0),BackgroundColor3=ACC,BackgroundTransparency=0.3})
    MkL(bx, {Text=txt,Size=UDim2.new(1,-64,1,0),Position=UDim2.new(0,14,0,0),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
    local TW,TH = 44,24
    local trk = MkF(bx, {Size=UDim2.new(0,TW,0,TH),Position=UDim2.new(1,-(TW+10),0.5,-TH/2),BackgroundColor3=init and TON or TOFF})
    Rnd(trk, 12)
    local KS = 18
    local knob = MkF(trk, {Size=UDim2.new(0,KS,0,KS),Position=init and UDim2.new(0,TW-KS-3,0.5,-KS/2) or UDim2.new(0,3,0.5,-KS/2),BackgroundColor3=WH})
    Rnd(knob, 9)
    local st = init
    MkB(bx, {Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""}).MouseButton1Click:Connect(function()
        st = not st
        Tw(trk,  {BackgroundColor3=st and TON or TOFF})
        Tw(knob, {Position=st and UDim2.new(0,TW-KS-3,0.5,-KS/2) or UDim2.new(0,3,0.5,-KS/2)})
        cb(st)
    end)
end

local function MkSld(txt, mn, mx, ini, cb)
    local y = NY(60, 5)
    local bx = MkF(Con, {Size=UDim2.new(1,-24,0,60),Position=UDim2.new(0,12,0,y),BackgroundColor3=BOX})
    Rnd(bx, 8)
    MkF(bx, {Size=UDim2.new(0,3,0.5,0),Position=UDim2.new(0,0,0.25,0),BackgroundColor3=ACC,BackgroundTransparency=0.3})
    MkL(bx, {Text=txt,Size=UDim2.new(0.65,0,0,20),Position=UDim2.new(0,14,0,8),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
    local vl = MkL(bx, {Text=tostring(ini),Size=UDim2.new(0.3,-4,0,20),Position=UDim2.new(0.7,0,0,8),TextColor3=ACC,Font=Enum.Font.GothamBold,TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
    local sbg = MkF(bx, {Size=UDim2.new(1,-28,0,5),Position=UDim2.new(0,14,0,40),BackgroundColor3=SLB})
    Rnd(sbg, 3)
    local p0 = (ini-mn)/(mx-mn)
    local fill = MkF(sbg, {Size=UDim2.new(p0,0,1,0),BackgroundColor3=ACC}) Rnd(fill,3)
    local kn   = MkF(sbg, {Size=UDim2.new(0,14,0,14),Position=UDim2.new(p0,-7,0.5,-7),BackgroundColor3=WH}) Rnd(kn,7)
    local drag = false
    local function upd(x)
        local p = math.clamp((x-sbg.AbsolutePosition.X)/sbg.AbsoluteSize.X,0,1)
        local v = math.floor((mn+(mx-mn)*p)*2+0.5)/2
        local ps = (v-mn)/(mx-mn)
        fill.Size=UDim2.new(ps,0,1,0) kn.Position=UDim2.new(ps,-7,0.5,-7)
        vl.Text = (v==math.floor(v)) and tostring(math.floor(v)) or tostring(v)
        cb(v)
    end
    sbg.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true upd(i.Position.X) end
    end)
    _G2.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i.Position.X) end
    end)
    _G2.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
end

-- ── Tab System ─────────────────────────────────
local Tabs   = {}
local CurTab = nil
local sbY    = 5

local function RegTab(name, bld)
    local btn = MkB(SBarScr, {
        Size             = UDim2.new(1,-2,0,31),
        Position         = UDim2.new(0,0,0,sbY),
        BackgroundColor3 = SBC,
        Text             = name,
        TextColor3       = DIM,
        Font             = Enum.Font.Gotham,
        TextSize         = 11,
        TextWrapped      = true,
    })
    sbY = sbY + 32
    SBarScr.CanvasSize = UDim2.new(0,0,0,sbY+8)
    Tabs[name] = {btn=btn, bld=bld}

    btn.MouseButton1Click:Connect(function()
        if CurTab == name then return end
        if CurTab and Tabs[CurTab] then
            Tw(Tabs[CurTab].btn, {BackgroundColor3=SBC, TextColor3=DIM})
        end
        CurTab = name
        TitleLbl.Text = "Rayy's Script  —  " .. name
        Tw(btn, {BackgroundColor3=Color3.fromRGB(28,28,28), TextColor3=TXT})
        for _,ch in pairs(Con:GetChildren()) do
            if not ch:IsA("UIPadding") then ch:Destroy() end
        end
        cY = 12
        Scr.CanvasPosition = Vector2.new(0,0)
        bld()
    end)
    btn.MouseEnter:Connect(function() if CurTab~=name then Tw(btn,{BackgroundColor3=Color3.fromRGB(18,18,18)}) end end)
    btn.MouseLeave:Connect(function() if CurTab~=name then Tw(btn,{BackgroundColor3=SBC}) end end)
end

-- ═══ TAB CONTENTS ═══════════════════════════════════════════

-- HOME
local function BldHome()
    local ay = NY(68, 6)
    local av = Instance.new("ImageLabel")
    av.Size             = UDim2.new(0,60,0,60)
    av.Position         = UDim2.new(0.5,-30,0,ay)
    av.BackgroundColor3 = Color3.fromRGB(55,55,55)
    av.BorderSizePixel  = 0
    av.Image            = "https://cdn.discordapp.com/avatars/1511061502201827399/291c0be66627f5c9c777ddec127a77a4.webp?size=2048"
    av.Parent           = Con
    Rnd(av, 30)

    local oy = NY(20, 3)
    MkL(Con, {
        Text           = "Rayy's Script",
        Size           = UDim2.new(1,-20,0,20),
        Position       = UDim2.new(0,10,0,oy),
        TextColor3     = TXT,
        Font           = Enum.Font.GothamBold,
        TextSize       = 15,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local sy = NY(14, 8)
    MkL(Con, {
        Text           = "TPS Street Soccer",
        Size           = UDim2.new(1,-20,0,14),
        Position       = UDim2.new(0,10,0,sy),
        TextColor3     = DIM,
        Font           = Enum.Font.Gotham,
        TextSize       = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    for _, s in ipairs({
        {"D","Discord Server", DISC, "https://discord.gg/tvWSp6abeZ"},
        {"Y","Youtube Channel",YTBC, "https://youtube.com/@rayy1081?si=2OFJ2BkkP_vZ9ugu"},
    }) do
        local sy2 = NY(42, 5)
        local bx = MkB(Con, {
            Size=UDim2.new(1,-20,0,42), Position=UDim2.new(0,10,0,sy2),
            BackgroundColor3=BOX, Text=""
        })
        Rnd(bx, 8)
        local lbox = MkF(bx, {Size=UDim2.new(0,42,1,0),BackgroundColor3=Color3.fromRGB(24,24,24)})
        Rnd(lbox, 8)
        MkF(lbox, {Size=UDim2.new(0,6,1,0),Position=UDim2.new(1,-6,0,0),BackgroundColor3=Color3.fromRGB(24,24,24)})
        MkL(lbox, {Text=s[1],Size=UDim2.new(1,0,1,0),TextColor3=s[3],Font=Enum.Font.GothamBold,TextSize=15,TextXAlignment=Enum.TextXAlignment.Center})
        MkL(bx,   {Text=s[2],Size=UDim2.new(1,-56,1,0),Position=UDim2.new(0,50,0,0),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
        local _url = s[4]
        bx.MouseButton1Click:Connect(function() pcall(function() setclipboard(_url) end) end)
        bx.MouseEnter:Connect(function() Tw(bx,{BackgroundColor3=Color3.fromRGB(40,40,40)}) end)
        bx.MouseLeave:Connect(function() Tw(bx,{BackgroundColor3=BOX}) end)
    end
end

-- LEG REACH
local function BldLeg()
    MkSec("Leg Reach")
    MkTog("Leg Reach", S.LegOn, function(v) S.LegOn=v _lastLeg=0 end)
    MkSec("Hitbox")
    MkTog("Show Hitbox  (Blue)", S.LHB, function(v) S.LHB=v end)
    MkSec("Distance (0-10)")
    MkSld("X - Horizontal", 0,10,S.LX, function(v) S.LX=v end)
    MkSld("Y - Vertical",   0,10,S.LY, function(v) S.LY=v end)
    MkSld("Z - Depth",      0,10,S.LZ, function(v) S.LZ=v end)
end

-- MOSS REACH
local function BldMoss()
    MkSec("Moss Reach - Head")
    MkTog("Moss Reach", S.MossOn, function(v) S.MossOn=v _lastMoss=0 end)
    MkSec("Hitbox")
    MkTog("Show Hitbox  (Green)", S.MHB, function(v) S.MHB=v end)
    MkSec("Distance (0-10)")
    MkSld("X - Horizontal", 0,10,S.MX, function(v) S.MX=v end)
    MkSld("Y - Vertical",   0,10,S.MY, function(v) S.MY=v end)
    MkSld("Z - Depth",      0,10,S.MZ, function(v) S.MZ=v end)
end

-- BALL REACH (client-side reach detection only, no ball resize)
local function BldBall()
    MkSec("Ball Reach")
    MkTog("Ball Reach", S.BallOn, function(v) S.BallOn=v _lastBall=0 end)
    MkSec("Hitbox")
    MkTog("Show Hitbox  (Yellow)", S.BHB, function(v) S.BHB=v end)
    MkSec("Reach Distance (0-10)")
    MkSld("X - Horizontal", 0,10,S.BX, function(v) S.BX=v end)
    MkSld("Y - Vertical",   0,10,S.BY, function(v) S.BY=v end)
    MkSld("Z - Depth",      0,10,S.BZ, function(v) S.BZ=v end)
    local iy = NY(34,4)
    local ib = MkF(Con,{Size=UDim2.new(1,-20,0,34),Position=UDim2.new(0,10,0,iy),BackgroundColor3=Color3.fromRGB(12,24,12)})
    Rnd(ib,8)
    MkL(ib,{
        Text="✓  Ban-safe: uses local touch detection only — ball is NOT resized",
        Size=UDim2.new(1,-14,1,0),Position=UDim2.new(0,8,0,0),
        TextColor3=Color3.fromRGB(80,200,100),Font=Enum.Font.Gotham,TextSize=10,
        TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left
    })
end

-- PLAYERS REACT
local function BldReact()
    MkSec("Ball Hit Reacts")
    local rlist = {"Rayy","Jinx","Azrael","Tunaz","Abzzy","4v0","Apz","Alonezz","Alzzy","Foxtede"}
    local TW, TH, KS = 42, 22, 16
    local tRefs = {}

    for _, rn in ipairs(rlist) do
        local isOn = (S.React == rn)
        local ry = NY(34, 4)
        local bx = MkF(Con, {
            Size=UDim2.new(1,-20,0,34), Position=UDim2.new(0,10,0,ry),
            BackgroundColor3=isOn and Color3.fromRGB(26,34,26) or BOX
        })
        Rnd(bx, 7)
        local rangeTxt = tostring(RD[rn] and RD[rn].range or "?").." st"
        MkL(bx, {Text=rn,Size=UDim2.new(1,-88,1,0),Position=UDim2.new(0,12,0,0),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
        MkL(bx, {Text=rangeTxt,Size=UDim2.new(0,34,1,0),Position=UDim2.new(1,-(TW+10+36),0,0),TextColor3=DIM,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Right})
        local trk = MkF(bx, {Size=UDim2.new(0,TW,0,TH),Position=UDim2.new(1,-(TW+8),0.5,-TH/2),BackgroundColor3=isOn and TON or TOFF})
        Rnd(trk, 11)
        local knob = MkF(trk, {Size=UDim2.new(0,KS,0,KS),Position=isOn and UDim2.new(0,TW-KS-3,0.5,-KS/2) or UDim2.new(0,3,0.5,-KS/2),BackgroundColor3=WH})
        Rnd(knob, 8)
        tRefs[rn] = {trk=trk, knob=knob, bx=bx}

        MkB(bx, {Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""}).MouseButton1Click:Connect(function()
            local was = (S.React == rn)
            S.React = ""
            for _,ref in pairs(tRefs) do
                Tw(ref.trk,  {BackgroundColor3=TOFF})
                Tw(ref.knob, {Position=UDim2.new(0,3,0.5,-KS/2)})
                Tw(ref.bx,   {BackgroundColor3=BOX})
            end
            if not was then
                S.React = rn
                Tw(trk,  {BackgroundColor3=TON})
                Tw(knob, {Position=UDim2.new(0,TW-KS-3,0.5,-KS/2)})
                Tw(bx,   {BackgroundColor3=Color3.fromRGB(26,34,26)})
            end
        end)
    end
end

-- SKILL HELPER
local function BldSkill()
    -- Air Dribble Helper
    MkSecC("Air Dribble Helper", SKIL)
    MkTog("Air Dribble Helper", S.AirDribOn, function(v) S.AirDribOn=v _lastAD=0 end)
    MkTog("Show Hitbox",        S.ADHB,      function(v) S.ADHB=v end)
    local ady = NY(36, 4)
    local adbx = MkF(Con, {Size=UDim2.new(1,-20,0,36),Position=UDim2.new(0,10,0,ady),BackgroundColor3=Color3.fromRGB(28,22,12)})
    Rnd(adbx, 8)
    MkL(adbx, {
        Text     = "When ball enters your reach zone and is above you → auto-jumps to ball height",
        Size     = UDim2.new(1,-14,1,0), Position=UDim2.new(0,8,0,0),
        TextColor3=Color3.fromRGB(185,135,60), Font=Enum.Font.Gotham, TextSize=10,
        TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
    })
    MkSec("Reach Size (1-10)")
    MkSld("Reach Zone", 1,10,S.ADReach, function(v) S.ADReach=v end)

    -- Inf Helper
    MkSecC("Inf Helper (Ground Shot)", SKIL)
    MkTog("Inf Helper", S.InfOn, function(v)
        S.InfOn = v
        if not v then pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end) end
    end)
    local ihy = NY(36, 4)
    local ihbx = MkF(Con, {Size=UDim2.new(1,-20,0,36),Position=UDim2.new(0,10,0,ihy),BackgroundColor3=Color3.fromRGB(28,22,12)})
    Rnd(ihbx, 8)
    MkL(ihbx, {
        Text     = "Auto-holds Ctrl when near the ball → automatic ground/low shots in TPS",
        Size     = UDim2.new(1,-14,1,0), Position=UDim2.new(0,8,0,0),
        TextColor3=Color3.fromRGB(185,135,60), Font=Enum.Font.Gotham, TextSize=10,
        TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
    })
end

-- PLAYER SETTINGS
local function BldSettings()
    MkSec("Performance")
    MkTog("FPS Boost", S.FPS, function(v)
        S.FPS = v
        pcall(function()
            settings().Rendering.QualityLevel = v and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
            _G4.GlobalShadows = not v
        end)
        if v then for _,o in pairs(workspace:GetDescendants()) do
            if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Fire") or o:IsA("Smoke") then
                pcall(function() o.Enabled=false end) end end end
    end)
    MkTog("FullBright", S.Bright, function(v)
        S.Bright = v
        pcall(function()
            if v then _G4.Brightness=10 _G4.GlobalShadows=false _G4.Ambient=Color3.new(1,1,1) _G4.OutdoorAmbient=Color3.new(1,1,1)
            else _G4.Brightness=1 _G4.GlobalShadows=true _G4.Ambient=Color3.fromRGB(70,70,70) _G4.OutdoorAmbient=Color3.fromRGB(140,140,140) end
        end)
    end)
    MkTog("No Fog", S.Fog, function(v)
        S.Fog = v
        pcall(function() _G4.FogEnd = v and 9e8 or 1000 _G4.FogStart = v and 9e8 or 0 end)
    end)
    MkSec("Movement")
    MkTog("Infinite Jump", S.IJ, function(v) S.IJ=v ApplyIJ(v) end)

    -- Ball Teleport
    local bty = NY(40, 5)
    local btbx = MkF(Con, {Size=UDim2.new(1,-24,0,40),Position=UDim2.new(0,12,0,bty),BackgroundColor3=BOX})
    Rnd(btbx, 8)
    MkF(btbx, {Size=UDim2.new(0,3,0.5,0),Position=UDim2.new(0,0,0.25,0),BackgroundColor3=ACC,BackgroundTransparency=0.3})
    MkL(btbx, {Text="Ball Teleport  [H]",Size=UDim2.new(1,-100,1,0),Position=UDim2.new(0,14,0,0),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
    local btBtn = MkB(btbx, {
        Size=UDim2.new(0,68,0,24),Position=UDim2.new(1,-(68+10),0.5,-12),
        BackgroundColor3=ACC,Text="Teleport",TextColor3=WH,Font=Enum.Font.GothamBold,TextSize=11
    })
    Rnd(btBtn, 6)
    local btSt = MkL(btbx, {Text="",Size=UDim2.new(0,20,0,24),Position=UDim2.new(1,-86,0.5,-12),TextColor3=TON,Font=Enum.Font.GothamBold,TextSize=13})
    local function DoBallTp()
        pcall(function()
            if not HRP then return end
            local ball = GetBall()
            if not ball then btSt.Text="?" btSt.TextColor3=RED task.delay(1,function()btSt.Text=""end) return end
            local dir = HRP.Position - ball.Position
            local mag = dir.Magnitude
            local offset = mag < 0.1 and Vector3.new(0,0,3) or (dir/mag)*3
            HRP.CFrame = CFrame.new(ball.Position + offset + Vector3.new(0,1,0))
            btSt.Text="✓" btSt.TextColor3=TON task.delay(0.6,function()btSt.Text=""end)
        end)
    end
    btBtn.MouseButton1Click:Connect(DoBallTp)
    btBtn.MouseEnter:Connect(function() Tw(btBtn,{BackgroundColor3=Color3.fromRGB(110,165,255)}) end)
    btBtn.MouseLeave:Connect(function() Tw(btBtn,{BackgroundColor3=ACC}) end)
    _BallTpFn = DoBallTp

    -- Ping Spoofer
    MkSec("Ping Spoofer")

    -- Deger girisi kutusu
    local pvY = NY(36, 4)
    local pvBx = MkF(Con,{Size=UDim2.new(1,-24,0,36),Position=UDim2.new(0,12,0,pvY),BackgroundColor3=BOX})
    Rnd(pvBx,8)
    MkL(pvBx,{Text="Fake Ping (ms):",Size=UDim2.new(0,115,1,0),Position=UDim2.new(0,10,0,0),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
    local pingTB = Instance.new("TextBox")
    pingTB.Size=UDim2.new(0,90,0,22) pingTB.Position=UDim2.new(0,128,0.5,-11)
    pingTB.BackgroundColor3=Color3.fromRGB(22,22,22) pingTB.BorderSizePixel=0
    pingTB.Text="10" pingTB.TextColor3=WH pingTB.Font=Enum.Font.GothamBold pingTB.TextSize=13
    pingTB.PlaceholderText="ms..." pingTB.PlaceholderColor3=DIM pingTB.ClearTextOnFocus=false
    pingTB.Parent=pvBx Rnd(pingTB,5)

    -- Toggle satiri
    local psy = NY(40, 5)
    local pbx = MkF(Con,{Size=UDim2.new(1,-24,0,40),Position=UDim2.new(0,12,0,psy),BackgroundColor3=BOX})
    Rnd(pbx,8)
    MkF(pbx,{Size=UDim2.new(0,3,0.5,0),Position=UDim2.new(0,0,0.25,0),BackgroundColor3=ACC,BackgroundTransparency=0.3})
    MkL(pbx,{Text="Ping Spoofer",Size=UDim2.new(0.55,0,1,0),Position=UDim2.new(0,14,0,0),TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
    local pingSt = MkL(pbx,{Text="OFF",Size=UDim2.new(0,55,1,0),Position=UDim2.new(0.55,0,0,0),TextColor3=DIM,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
    local PTW,PTH=44,22 local PKS=18
    local ptrk=MkF(pbx,{Size=UDim2.new(0,PTW,0,PTH),Position=UDim2.new(1,-(PTW+10),0.5,-PTH/2),BackgroundColor3=TOFF})
    Rnd(ptrk,11)
    local pknob=MkF(ptrk,{Size=UDim2.new(0,PKS,0,PKS),Position=UDim2.new(0,3,0.5,-PKS/2),BackgroundColor3=WH})
    Rnd(pknob,9)
    local pingOn=false
    MkB(pbx,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""}).MouseButton1Click:Connect(function()
        pingOn=not pingOn
        Tw(ptrk, {BackgroundColor3=pingOn and TON or TOFF})
        Tw(pknob,{Position=pingOn and UDim2.new(0,PTW-PKS-3,0.5,-PKS/2) or UDim2.new(0,3,0.5,-PKS/2)})
        pingSt.Text=pingOn and "ON" or "OFF"
        pingSt.TextColor3=pingOn and TON or DIM
    end)

    -- CoreGui ping label spoofer loop
    task.spawn(function()
        local cg = game:GetService("CoreGui")
        while true do
            task.wait(0.12)
            if pingOn then
                local fakeMs = tostring(math.abs(math.floor(tonumber(pingTB.Text) or 10)))
                pcall(function()
                    for _, v in ipairs(cg:GetDescendants()) do
                        if v:IsA("TextLabel") or v:IsA("TextButton") then
                            local t = v.Text
                            if t and t ~= "" then
                                local tl = t:lower()
                                if tl:find("ping") or tl:find("latency") or tl:find("network") then
                                    v.Text = t:gsub("%d+%.?%d*", fakeMs, 1)
                                elseif t:match("^%s*%d+%.?%d*%s*ms%s*$") then
                                    v.Text = fakeMs .. " ms"
                                elseif t:match("%d+%.?%d*%s*ms") then
                                    v.Text = t:gsub("%d+%.?%d*(%s*ms)", fakeMs .. "%1", 1)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)

    -- Avatar Stealer
    MkSec("Avatar Stealer")
    local ky = NY(58, 4)
    local kavt = MkF(Con, {Size=UDim2.new(1,-20,0,58),Position=UDim2.new(0,10,0,ky),BackgroundColor3=BOX})
    Rnd(kavt, 8)
    MkL(kavt, {
        Text="Enter player name to copy avatar:",
        Size=UDim2.new(1,-14,0,15),Position=UDim2.new(0,8,0,4),
        TextColor3=DIM,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left
    })
    local nTB = Instance.new("TextBox")
    nTB.Size=UDim2.new(0,188,0,24) nTB.Position=UDim2.new(0,8,0,27)
    nTB.BackgroundColor3=Color3.fromRGB(22,22,22) nTB.BorderSizePixel=0
    nTB.Text="" nTB.TextColor3=WH nTB.Font=Enum.Font.Gotham nTB.TextSize=12
    nTB.PlaceholderText="Player name..." nTB.PlaceholderColor3=DIM nTB.ClearTextOnFocus=false
    nTB.Parent=kavt Rnd(nTB,5)
    local kbtn = MkB(kavt,{
        Size=UDim2.new(0,100,0,24),Position=UDim2.new(0,202,0,27),
        BackgroundColor3=ACC,Text="Copy Avatar",TextColor3=WH,Font=Enum.Font.GothamBold,TextSize=10
    })
    Rnd(kbtn,5)
    local kSt = MkL(kavt,{
        Text="",Size=UDim2.new(0,50,0,24),Position=UDim2.new(1,-54,0,27),
        TextColor3=TON,Font=Enum.Font.GothamBold,TextSize=11
    })
    kbtn.MouseButton1Click:Connect(function()
        local nm = nTB.Text:gsub("%s","")
        if nm == "" then return end
        kSt.Text="..." kSt.TextColor3=DIM
        task.spawn(function()
            local mc  = LP.Character
            local hum = mc and mc:FindFirstChildOfClass("Humanoid")
            if not mc or not hum then
                kSt.Text="No Char" kSt.TextColor3=RED
                task.delay(2,function()kSt.Text=""end) return
            end

            -- Sayısal girdi → User ID, metin → isim araması
            local targetUserId = nil
            local targetName   = nm

            local numId = tonumber(nm)
            if numId then
                targetUserId = numId
                for _,p in ipairs(_G0:GetPlayers()) do
                    if p.UserId == numId then targetName = p.Name break end
                end
            else
                for _,p in ipairs(_G0:GetPlayers()) do
                    if p.Name:lower() == nm:lower() then
                        targetUserId = p.UserId
                        targetName   = p.Name
                        break
                    end
                end
                if not targetUserId then
                    local ok2, uid2 = pcall(function()
                        return _G0:GetUserIdFromNameAsync(nm)
                    end)
                    if ok2 and uid2 then targetUserId = uid2 end
                end
            end

            if not targetUserId then
                kSt.Text="Not Found" kSt.TextColor3=RED
                task.delay(2,function()kSt.Text=""end) return
            end

            -- Eski aksesuarları, kıyafetleri ve renkleri temizle
            for _,v in ipairs(mc:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
                or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                    pcall(function() v:Destroy() end)
                end
            end

            -- GetCharacterAppearanceAsync → aksesuar + kıyafet + renkler
            -- ApplyDescription gerektirmez, sunucu izni olmadan çalışır
            local ok3, appModel = pcall(function()
                return _G0:GetCharacterAppearanceAsync(targetUserId)
            end)
            if ok3 and appModel then
                for _,v in ipairs(appModel:GetChildren()) do
                    pcall(function()
                        local c = v:Clone()
                        if c:IsA("Accessory") then
                            hum:AddAccessory(c)
                        elseif c:IsA("Shirt") or c:IsA("Pants")
                            or c:IsA("ShirtGraphic") or c:IsA("BodyColors") then
                            c.Parent = mc
                        end
                    end)
                end
                appModel:Destroy()
            end

            -- Yedek: HumanoidDescription ile yüz + vücut şeklini de uygula
            pcall(function()
                local ok4, desc = pcall(function()
                    return _G0:GetHumanoidDescriptionFromUserId(targetUserId)
                end)
                if ok4 and desc then
                    -- Sadece yüz, saç ve vücut şeklini al (kıyafet zaten yukarıda)
                    local myDesc = hum:GetAppliedDescription()
                    myDesc.Face            = desc.Face
                    myDesc.Head            = desc.Head
                    myDesc.Torso           = desc.Torso
                    myDesc.RightArm        = desc.RightArm
                    myDesc.LeftArm         = desc.LeftArm
                    myDesc.RightLeg        = desc.RightLeg
                    myDesc.LeftLeg         = desc.LeftLeg
                    myDesc.HeadScale       = desc.HeadScale
                    myDesc.BodyTypeScale   = desc.BodyTypeScale
                    myDesc.ProportionScale = desc.ProportionScale
                    myDesc.WidthScale      = desc.WidthScale
                    myDesc.HeightScale     = desc.HeightScale
                    myDesc.DepthScale      = desc.DepthScale
                    pcall(function() hum:ApplyDescription(myDesc) end)
                end
            end)

            kSt.Text="✓" kSt.TextColor3=TON
            pcall(function()
                _G5:SetCore("SendNotification",{
                    Title="Rayy's Script",
                    Text=targetName.."'in avatarı kopyalandı",
                    Duration=4
                })
            end)
            task.delay(2,function()kSt.Text=""end)
        end)
    end)
    kbtn.MouseEnter:Connect(function() Tw(kbtn,{BackgroundColor3=Color3.fromRGB(110,165,255)}) end)
    kbtn.MouseLeave:Connect(function() Tw(kbtn,{BackgroundColor3=ACC}) end)

    -- Restore butonu
    local ry2 = NY(34, 4)
    local rbx = MkF(Con, {Size=UDim2.new(1,-20,0,34),Position=UDim2.new(0,10,0,ry2),BackgroundColor3=Color3.fromRGB(28,22,12)})
    Rnd(rbx, 8)
    MkF(rbx, {Size=UDim2.new(0,3,0.5,0),Position=UDim2.new(0,0,0.25,0),BackgroundColor3=SKIL,BackgroundTransparency=0.3})
    MkL(rbx, {
        Text="Restore My Avatar",
        Size=UDim2.new(1,-130,1,0),Position=UDim2.new(0,14,0,0),
        TextColor3=TXT,Font=Enum.Font.GothamSemibold,TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    local rSt = MkL(rbx, {
        Text="",Size=UDim2.new(0,26,1,0),Position=UDim2.new(1,-118,0,0),
        TextColor3=TON,Font=Enum.Font.GothamBold,TextSize=12
    })
    local rBtn = MkB(rbx, {
        Size=UDim2.new(0,84,0,22),Position=UDim2.new(1,-(84+8),0.5,-11),
        BackgroundColor3=SKIL,Text="🔄 Restore",
        TextColor3=Color3.fromRGB(0,0,0),Font=Enum.Font.GothamBold,TextSize=10
    })
    Rnd(rBtn, 6)
    rBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            local mc  = LP.Character
            local hum = mc and mc:FindFirstChildOfClass("Humanoid")
            if not mc or not hum then
                rSt.Text="✗" rSt.TextColor3=RED
                task.delay(2,function()rSt.Text=""end) return
            end
            rSt.Text="..." rSt.TextColor3=DIM

            -- Saklanan appearance yoksa şimdi çek
            if not _origAppearance then
                pcall(function()
                    local m = _G0:GetCharacterAppearanceAsync(LP.UserId)
                    _origAppearance = {}
                    for _,v in ipairs(m:GetChildren()) do
                        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
                        or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                            table.insert(_origAppearance, v:Clone())
                        end
                    end
                    m:Destroy()
                end)
            end
            if not _origAvatarDesc then
                pcall(function()
                    _origAvatarDesc = _G0:GetHumanoidDescriptionFromUserId(LP.UserId)
                end)
            end

            if not _origAppearance then
                rSt.Text="✗" rSt.TextColor3=RED
                task.delay(2,function()rSt.Text=""end) return
            end

            -- Eski kopyaları temizle
            for _,v in ipairs(mc:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
                or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                    pcall(function() v:Destroy() end)
                end
            end

            -- Orijinal görünümü geri yükle
            for _,v in ipairs(_origAppearance) do
                pcall(function()
                    local c = v:Clone()
                    if c:IsA("Accessory") then
                        hum:AddAccessory(c)
                    else
                        c.Parent = mc
                    end
                end)
            end

            -- Yüz + vücut oranları
            if _origAvatarDesc then
                pcall(function()
                    local myDesc = hum:GetAppliedDescription()
                    myDesc.Face            = _origAvatarDesc.Face
                    myDesc.Head            = _origAvatarDesc.Head
                    myDesc.Torso           = _origAvatarDesc.Torso
                    myDesc.RightArm        = _origAvatarDesc.RightArm
                    myDesc.LeftArm         = _origAvatarDesc.LeftArm
                    myDesc.RightLeg        = _origAvatarDesc.RightLeg
                    myDesc.LeftLeg         = _origAvatarDesc.LeftLeg
                    myDesc.HeadScale       = _origAvatarDesc.HeadScale
                    myDesc.BodyTypeScale   = _origAvatarDesc.BodyTypeScale
                    myDesc.ProportionScale = _origAvatarDesc.ProportionScale
                    myDesc.WidthScale      = _origAvatarDesc.WidthScale
                    myDesc.HeightScale     = _origAvatarDesc.HeightScale
                    myDesc.DepthScale      = _origAvatarDesc.DepthScale
                    pcall(function() hum:ApplyDescription(myDesc) end)
                end)
            end

            rSt.Text="✓" rSt.TextColor3=TON
            pcall(function()
                _G5:SetCore("SendNotification",{
                    Title="Rayy's Script",
                    Text="Avatarın geri yüklendi",
                    Duration=3
                })
            end)
            task.delay(2,function()rSt.Text=""end)
        end)
    end)
    rBtn.MouseEnter:Connect(function() Tw(rBtn,{BackgroundColor3=Color3.fromRGB(255,185,70)}) end)
    rBtn.MouseLeave:Connect(function() Tw(rBtn,{BackgroundColor3=SKIL}) end)
end

-- R15 REACH
local function BldR15()
    MkSec("R15 Reach")
    MkTog("R15 Reach", S.R15On, function(v) S.R15On=v _lastR15=0 end)
    MkSec("Distance (0-10)")
    MkSld("X - Horizontal", 0,10,S.RX, function(v) S.RX=v end)
    MkSld("Y - Vertical",   0,10,S.RY, function(v) S.RY=v end)
    MkSld("Z - Depth",      0,10,S.RZ, function(v) S.RZ=v end)
end

-- FFLAG SETTING
local SF = {
    ["FIntActivatedCountTimerMSMouse"]    = "0",
    ["FIntCLI20390_2"]                    = "0",
    ["FIntActivatedCountTimerMSTouch"]    = "0",
    ["DFIntTargetTimeDelayFacctorTenths"] = "7",
    ["FIntActivatedCountTimerMSKeyboard"] = "0",
    ["FIntInterpolationMaxDelayMSec"]     = "1",
}
for k,v in pairs(SF) do pcall(function() setfflag(k,v) end) end

local function BldFFlag()
    local hasFF = type(setfflag)=="function"
    if not hasFF then
        local wy = NY(48, 4)
        local wb = MkF(Con,{Size=UDim2.new(1,-20,0,48),Position=UDim2.new(0,10,0,wy),BackgroundColor3=Color3.fromRGB(34,18,18)})
        Rnd(wb,8)
        MkL(wb,{
            Text="⚠  Your executor does not support setfflag.\nFFlag Settings are unavailable.",
            Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,8,0,0),
            TextColor3=Color3.fromRGB(200,110,50),Font=Enum.Font.Gotham,TextSize=11,
            TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left
        })
        return
    end

    -- ── FFlag Settings (sadece 2 flag) ─────────────────────────
    MkSec("FFlag Settings")

    local _ffTbx = {}
    local ffFlags = {
        "DFIntTargetTimeDelayFacctorTenths",
        "FIntInterpolationMaxDelayMSec",
    }
    for _, fname in ipairs(ffFlags) do
        local fy = NY(38, 3)
        local bx = MkF(Con,{Size=UDim2.new(1,-20,0,38),Position=UDim2.new(0,10,0,fy),BackgroundColor3=BOX})
        Rnd(bx,7)
        MkL(bx,{Text=fname,Size=UDim2.new(1,-14,0,14),Position=UDim2.new(0,8,0,3),
            TextColor3=TXT,Font=Enum.Font.GothamBold,TextSize=9,
            TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
        local tbx = Instance.new("TextBox")
        tbx.Size=UDim2.new(1,-16,0,18) tbx.Position=UDim2.new(0,8,0,18)
        tbx.BackgroundColor3=Color3.fromRGB(20,20,20) tbx.BorderSizePixel=0
        tbx.Text="" tbx.TextColor3=WH tbx.Font=Enum.Font.Gotham tbx.TextSize=12
        tbx.PlaceholderText="Enter value..." tbx.PlaceholderColor3=DIM tbx.ClearTextOnFocus=false
        tbx.Parent=bx Rnd(tbx,4)
        tbx:GetPropertyChangedSignal("Text"):Connect(function()
            SF[fname] = tbx.Text
        end)
        _ffTbx[fname] = tbx
    end

    -- ── Bloxstrap Export ──────────────────────────────────────
    MkSec("Bloxstrap Export")
    local bsY = NY(90, 4)
    local bsBx = MkF(Con,{Size=UDim2.new(1,-20,0,90),Position=UDim2.new(0,10,0,bsY),BackgroundColor3=Color3.fromRGB(22,18,8)})
    Rnd(bsBx,8)
    MkL(bsBx,{
        Text="Copy JSON → Paste into Bloxstrap:",
        Size=UDim2.new(1,-14,0,15),Position=UDim2.new(0,8,0,5),
        TextColor3=Color3.fromRGB(230,180,60),Font=Enum.Font.GothamBold,TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    MkL(bsBx,{
        Text="%LocalAppData%\\Bloxstrap\\Modifications\\ClientSettings\\ClientAppSettings.json",
        Size=UDim2.new(1,-14,0,16),Position=UDim2.new(0,8,0,20),
        TextColor3=Color3.fromRGB(150,150,150),Font=Enum.Font.Gotham,TextSize=9,
        TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left
    })
    local bsBtn = MkB(bsBx,{
        Size=UDim2.new(1,-16,0,24),Position=UDim2.new(0,8,0,38),
        BackgroundColor3=Color3.fromRGB(240,160,30),Text="📋 Copy Bloxstrap JSON",
        TextColor3=Color3.fromRGB(0,0,0),Font=Enum.Font.GothamBold,TextSize=11
    })
    Rnd(bsBtn,6)
    bsBtn.MouseButton1Click:Connect(function()
        local HS = game:GetService("HttpService")
        local t = {}
        for _, fname in ipairs(ffFlags) do
            local v = (_ffTbx[fname] and _ffTbx[fname].Text ~= "") and _ffTbx[fname].Text or nil
            if v then t[fname] = v end
        end
        local ok,json = pcall(function() return HS:JSONEncode(t) end)
        if ok and json then
            pcall(function() setclipboard(json) end)
            bsBtn.Text="✓ Copied! Paste it into Bloxstrap file"
        else
            bsBtn.Text="✗ Error"
        end
        task.delay(3,function() bsBtn.Text="📋 Copy Bloxstrap JSON" end)
    end)
    bsBtn.MouseEnter:Connect(function() Tw(bsBtn,{BackgroundColor3=Color3.fromRGB(255,190,60)}) end)
    bsBtn.MouseLeave:Connect(function() Tw(bsBtn,{BackgroundColor3=Color3.fromRGB(240,160,30)}) end)

    -- Bloxstrap Script button
    local bsScY = NY(34, 4)
    local bsScBtn = MkB(Con,{
        Size=UDim2.new(1,-20,0,34),Position=UDim2.new(0,10,0,bsScY),
        BackgroundColor3=Color3.fromRGB(50,120,230),Text="🔗 Bloxstrap Script",
        TextColor3=WH,Font=Enum.Font.GothamBold,TextSize=13
    })
    Rnd(bsScBtn,8)
    bsScBtn.MouseButton1Click:Connect(function()
        bsScBtn.Text="⏳ Executing..."
        task.spawn(function()
            getgenv().autosetup = {
                path = "Bloxstrap",
                setup = true
            }
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/Bloxstrap/main/Initiate.lua","lol"))()
            end)
        end)
        task.delay(3,function() bsScBtn.Text="🔗 Bloxstrap Script" end)
    end)
    bsScBtn.MouseEnter:Connect(function() Tw(bsScBtn,{BackgroundColor3=Color3.fromRGB(70,150,255)}) end)
    bsScBtn.MouseLeave:Connect(function() Tw(bsScBtn,{BackgroundColor3=Color3.fromRGB(50,120,230)}) end)
end

-- ── Tab Registration ──────────────────────────
RegTab("Home",           BldHome)
RegTab("Leg Reach",      BldLeg)
RegTab("Moss Reach",     BldMoss)
RegTab("Ball Reach",     BldBall)
RegTab("Players React",  BldReact)
RegTab("Skill Helper",   BldSkill)
RegTab("Plyr Settings",  BldSettings)
RegTab("R15 Reach",      BldR15)
RegTab("FFlag Setting",  BldFFlag)

-- Open Home by default
CurTab = "Home"
Tw(Tabs["Home"].btn, {BackgroundColor3=Color3.fromRGB(28,28,28), TextColor3=TXT})
cY = 12
BldHome()

-- ── Toggle Button (mobile draggable) ──────────
local TB = MkB(SG, {
    Size             = UDim2.new(0,86,0,46),
    Position         = UDim2.new(0,10,0,48),
    BackgroundColor3 = Color3.fromRGB(18,18,18),
    Text             = "MENU",
    TextColor3       = TXT,
    Font             = Enum.Font.GothamBold,
    TextSize         = 13,
    ZIndex           = 20,
    Active           = true,
})
Rnd(TB, 6)
MkF(TB, {Size=UDim2.new(0,2,0.6,0),Position=UDim2.new(0,0,0.2,0),BackgroundColor3=ACC,ZIndex=21})

local tbDrag, tbDS, tbSP, tbT = false
TB.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        tbDrag=true tbDS=i.Position tbSP=TB.Position tbT=tick()
    end
end)
_G2.InputChanged:Connect(function(i)
    if tbDrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-tbDS
        TB.Position=UDim2.new(tbSP.X.Scale,tbSP.X.Offset+d.X,tbSP.Y.Scale,tbSP.Y.Offset+d.Y)
    end
end)
_G2.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        if tbDrag then
            local d=i.Position-tbDS
            if d.Magnitude < 8 and (tick()-tbT) < 0.3 then
                shown=not shown Win.Visible=shown
            end
        end
        tbDrag=false
    end
end)

-- RightShift toggle + H key ball tp
_G2.InputBegan:Connect(function(i,p)
    if p then return end
    if i.KeyCode==Enum.KeyCode.RightShift then
        shown=not shown Win.Visible=shown
    end
    if i.KeyCode==Enum.KeyCode.H then
        if _BallTpFn then _BallTpFn() end
    end
end)

pcall(function() _RAYY = true end)
