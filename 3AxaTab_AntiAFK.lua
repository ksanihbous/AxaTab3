--==========================================================
--  3AxaTab_AntiAFK.lua
--  Smart AntiAFK + Smart Auto Nonaktif (Jam WITA)
--  + Remote Discord API + Report Players API + Wordban Chat AutoLeave
--==========================================================

------------------- ENV / TAB -------------------
local antiTabFrame = TAB_FRAME
local tabId        = TAB_ID or "antiafk"

local Players     = Players     or game:GetService("Players")
local RunService  = RunService  or game:GetService("RunService")
local StarterGui  = StarterGui  or game:GetService("StarterGui")
local LocalPlayer = LocalPlayer or Players.LocalPlayer
local TeleportService    = game:GetService("TeleportService")
local HttpService        = HttpService or game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

--=============== DISCORD /addtime API CONFIG (Remote AntiAFK) ===============
-- index.js:
--   app.get('/anti-afk/:robloxId', (req, res) => { enabled, expireAt })
-- Roblox script akan GET ke:
--   API_RBLX_BASE .. LocalPlayer.UserId
local API_RBLX_BASE = "https://1081ca71-de88-4d84-ac83-db73011a4dad-00-2kehga2okwiwp.sisko.replit.dev:3000/anti-afk/"

--=============== REPORT PLAYERS API CONFIG ============================
local REPORT_PLAYERS_URL      = "https://1081ca71-de88-4d84-ac83-db73011a4dad-00-2kehga2okwiwp.sisko.replit.dev:3000/report-players"
local REPORT_PLAYERS_ENABLED  = false
local REPORT_PLAYERS_INTERVAL = 60

local function getApiUrlForPlayer()
    return API_RBLX_BASE .. tostring(LocalPlayer.UserId)
end

------------------- HELPER: NOTIFY (GLOBAL) -------------------
local starterGui = StarterGui

local function notify(title, text, dur)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = dur or 3
        })
    end)
end

------------------- API FETCH (REMOTE ANTI AFK) -------------------
local function fetchRemoteAntiAFKConfig()
    local url = getApiUrlForPlayer()

    local ok, body = pcall(function()
        local hasGameHttpGet = false
        pcall(function()
            if typeof(game.HttpGet) == "function" then
                hasGameHttpGet = true
            end
        end)

        if hasGameHttpGet then
            return game:HttpGet(url)
        else
            return HttpService:GetAsync(url)
        end
    end)

    if not ok or not body or body == "" then
        return nil
    end

    local okJson, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not okJson or type(data) ~= "table" then
        return nil
    end

    local enabled = (data.enabled == true)
    local expire  = tonumber(data.expireAt) or 0

    data.enabled  = enabled
    data.expireAt = expire

    return data
end

----------------------------------------------------------------

local okVIM, vimSvc = pcall(function() return game:GetService("VirtualInputManager") end)
local VirtualInputManager = VirtualInputManager or (okVIM and vimSvc) or nil
local VirtualUser = game:GetService("VirtualUser")

if not (antiTabFrame and LocalPlayer) then return end

antiTabFrame:ClearAllChildren()
antiTabFrame.BackgroundTransparency = 1

------------------- ADMIN LIST / WORDBAN CONFIG (UNIVERSAL) -------------------
-- Satu-satunya sumber data: ADMIN_IDS (userId -> info)
local ADMIN_IDS = {
    [2918244413] = {displayName = "ZuVoid",          username = "ZuVoidGT",        role = "DEVELOPER"},
    [393072708]  = {displayName = "Pamand Arthur",   username = "IMightBeUgly",    role = "DEVELOPER"},
    [4366735226] = {displayName = "AamTum",          username = "AamTum",          role = "DEVELOPER"},
    [6185428576] = {displayName = "zengss / Jank_1403", username = "jank_1403",   role = "DEVELOPER"},
    [7147000579] = {displayName = "Gazell&Pinky",    username = "Alergi_PENINGGI", role = "DEVELOPER"},
    [1115333577] = {displayName = "AngelsNeedHeaven",username = "AngelsNeedHeaven",role = "DEVELOPER"},

    [1201037734] = {displayName = "SON",             username = "POISENIII",       role = "HEAD ADMIN"},
    [7331328452] = {displayName = "BrowwDeCaprio",   username = "16Broww",         role = "HEAD ADMIN"},
    [6160156469] = {displayName = "Ryiin_HG",            username = "RYIIN100",        role = "HEAD ADMIN"},
    [7864402618] = {displayName = "Tiktik",          username = "tiktik_4924",     role = "HEAD ADMIN"},

    [8147845822] = {displayName = "Danskuy",         username = "danskuyxd",       role = "ADMIN"},
    [7449046692] = {displayName = "Naira",           username = "na_iaa5",         role = "ADMIN"},
    [8390121074] = {displayName = "Zone",            username = "DAXAJA0",         role = "ADMIN"},
    [8142551573] = {displayName = "Glenfiddich",     username = "teteyourb4e",     role = "ADMIN"},
    [4755470099] = {displayName = "viziee",          username = "dumbziee",        role = "ADMIN"},
    [8530851838] = {displayName = "Minzu",           username = "Mrsnk0",          role = "ADMIN"},
    [8473720116] = {displayName = "Grezly",          username = "VloowZ",          role = "ADMIN"},
    [1592339934] = {displayName = "Eryvenith / Lenn, Who?", username = "ethyreaa", role = "ADMIN"},

    [50792373]   = {displayName = "Lilik",           username = "LeeLiQs",         role = "VIP PARTNER"},

    [8631506826] = {displayName = "TickTak",         username = "TickTackTows",    role = "TIKTOKERS/SELLER"},
    [8071643164] = {displayName = "BruceWayne",      username = "adityariski8",    role = "TIKTOKER"},
    [8668234444] = {displayName = "Jiroo",           username = "axagaaa",         role = "TIKTOKERS"},
    [8087805397] = {displayName = "SQKanyut",        username = "SQKanyut",        role = "TIKTOKERS"},
    [8557512299] = {displayName = "Gala",            username = "CrowValhalla",    role = "TIKTOKERS"},
    [8585320336] = {displayName = "JEAN",            username = "JEANZ911",        role = "TIKTOKERS"},
    [8706826354] = {displayName = "SCHxNailoong",            username = "Nailoong29",        role = "TIKTOKERS"},
    [8534358330] = {displayName = "JAKAWI",          username = "adudek19",        role = "TIKTOKERS"},
    [9253558926] = {displayName = "HajiKalcer",      username = "Hajididin",       role = "TIKTOKERS"},
    [7962844623] = {displayName = "Awnnn",           username = "Awnnn2419",       role = "TIKTOKERS"},
    [8929154385] = {displayName = "PinkyBoyzt",      username = "PinkyBoyzt",      role = "TIKTOKERS"},
    [8793426296] = {displayName = "JekkSlwly",       username = "JekkSlwly26",     role = "TIKTOKERS"},
    [8842458435] = {displayName = "DEDEDEBU",        username = "debubintangni",   role = "TIKTOKERS"},
    [2926659406] = {displayName = "PUTTYDAILY",      username = "puttydaily",      role = "TIKTOKERS"},
    [8910573996] = {displayName = "PrinceFannzy",    username = "PrinceFannzy",    role = "TIKTOKERS"},
    [7954687096] = {displayName = "ZYNNN",           username = "ZynnnX02",        role = "TIKTOKERS"},
    [4831020423] = {displayName = "starvenn",        username = "ravennxxz",       role = "TIKTOKERS"},
    [8445880187] = {displayName = "Payy",            username = "ZannButterfly",   role = "TIKTOKERS"},
    [9232301839] = {displayName = "PDIPxPRAGOS",            username = "Ewinnn29",   role = "TIKTOKERS"},

    [8468294802] = {displayName = "Sakura",          username = "SakuraKiyu",      role = ""},
    [3203237864] = {displayName = "Ido",             username = "vakkamz7",        role = ""},
    [122721024]  = {displayName = "Hizo",            username = "2hizo",           role = ""},
    [7811490053] = {displayName = "Eisha",           username = "naerynnnuv",      role = ""},
    [8358382042] = {displayName = "Barooon",         username = "baroonsteinfeld", role = ""},
    [8609125996] = {displayName = "Heyv3r",          username = "asrev11",         role = ""},
    [1525370726] = {displayName = "Bithond",         username = "Bithond",         role = ""},
    [8360242865] = {displayName = "Issyxuuee",       username = "kiyomiiii34",     role = ""},
    [1398433171] = {displayName = "CUPE",            username = "P23Savior",       role = ""},
    [3562063767] = {displayName = "Grizzly",         username = "Lychttttt",       role = ""},
    [7869751197] = {displayName = "HAJIRIO",         username = "rioSlebew52",     role = ""},
    [5284241320] = {displayName = "APIPIIIEEEE",     username = "apiphbp",         role = ""},
    [9058511261] = {displayName = "Hayyaaa",         username = "CHILLBoyxHayaa",  role = ""},
    [8956748924] = {displayName = "SON KE 2?",       username = "S0N899",          role = ""},
}

-- Helper untuk mengelompokkan role ke label singkat yang dipakai di webhook/title
local function getRoleGroup(info)
    if not info or not info.role then
        return "Admin"
    end
    local r = string.upper(info.role)

    if r:find("DEVELOPER") then
        return "Developer"
    end
    if r:find("HEAD ADMIN") then
        return "Head Admin"
    end
    if r:find("ADMIN") then
        return "Admin"
    end
    if r:find("TIKTOK") then
        return "Tiktokers"
    end
    if r:find("VIP PARTNER") or r:find("VIP") then
        return "VIP Partner"
    end

    return "Staff"
end

-- Admin yang DIKECUALIKAN dari Auto Leave/Rejoin (via checkbox)
-- Default: semua TIDAK ada di table ini => semua dianggap ikut deteksi (☑).
local excludedAdminIds = {}   -- [userId] = true kalau DIKECUALIKAN
local adminExcludeRows = {}   -- [userId] = {button=..., label=..., data=...}

-- Wordban base list (semua default AKTIF, nanti ada checkbox untuk OFF/ON per kata)
local BASE_WORDBAN_WORDS = {
    "cheating",
    "ngecheat",
    "ngechit",
    "ngecheating",
    "ngecit",
    "chit",
    "chiter",
    "cheater",
    "cheat",
    "exploit",
    "cit",
    "cheatt",
    --"terbang",
    "fly",
}

-- Map kata yang AKTIF untuk Wordban (default: semua true)
local wordbanEnabledMap = {}
for _, w in ipairs(BASE_WORDBAN_WORDS) do
    wordbanEnabledMap[string.lower(w)] = true
end

-- Row UI untuk wordban checkbox
local wordbanRows = {}  -- [wordLower] = {button=..., label=..., word=...}

------------------- DISCORD WEBHOOK CONFIG -------------------
local WEBHOOK_URL    = "https://discord.com/api/webhooks/1448119039359717396/c2neTRGsUXarpICRTzsm0lIS5qzqnTKn5uini_AHP1lkBr2UzL3_GvhC4ppzD7PStJHZ"
local BOT_USERNAME   = "AntiAFK Notifier"
local BOT_AVATAR_URL = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png"
local DEFAULT_OWNER_DISCORD = "<@1403052152691101857>"
local sendWebhook

------------------- TAB STATE / CONNECTIONS -------------------
local alive       = true
local connections = {}

local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(connections, c)
    return c
end

------------------- HELPER UI -------------------
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do
        o[k] = v
    end
    o.Parent = parent
    return o
end

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addPadding(parent, left, right, top, bottom)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, left   or 0)
    p.PaddingRight  = UDim.new(0, right  or 0)
    p.PaddingTop    = UDim.new(0, top    or 0)
    p.PaddingBottom = UDim.new(0, bottom or 0)
    p.Parent = parent
    return p
end

------------------- HEADER -------------------
mk("TextLabel",{
    Name="Header",Size=UDim2.new(1,-10,0,22),Position=UDim2.new(0,5,0,6),
    BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=Color3.fromRGB(40,40,60),TextXAlignment=Enum.TextXAlignment.Left,
    Text="🛏️ AntiAFK+ Smart V1"
},antiTabFrame)

mk("TextLabel",{
    Name="Sub",Size=UDim2.new(1,-10,0,34),Position=UDim2.new(0,5,0,26),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=Color3.fromRGB(90,90,120),TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,
    Text="Menahan idle kick Roblox + auto respawn + auto restart route. Ada jadwal Auto Nonaktif (jam WITA), deteksi Admin/Developer/Head Admin/Tiktokers, Discord Webhook, Remote API (/addtime), Report Players API, Wordban Chat AutoLeave, dan daftar ADMIN + Wordban list dengan checkbox exclude/per-kata."
},antiTabFrame)

------------------- BODY SCROLL -------------------
local body = mk("ScrollingFrame",{
    Name="BodyScroll",
    Position=UDim2.new(0,0,0,64),
    Size=UDim2.new(1,0,1,-64),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=4,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0,0,0,0)
}, antiTabFrame)

addPadding(body, 6, 6, 4, 6)

local bodyLayout = mk("UIListLayout",{
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,8),
}, body)

bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    body.CanvasSize = UDim2.new(0,0,0,bodyLayout.AbsoluteContentSize.Y + 8)
end)

------------------- CARD 1: MAIN ANTIAFK + UPTIME -------------------
local mainCard = mk("Frame",{
    Name="MainCard",
    Size=UDim2.new(1,-4,0,110),
    BackgroundColor3=Color3.fromRGB(236,238,248),
    BorderSizePixel=0
}, body)
makeCorner(mainCard,10)
mk("UIStroke",{
    Thickness=1,
    Color=Color3.fromRGB(210,210,230),
    Transparency=0.3
}, mainCard)

local antiToggleBtn = mk("TextButton",{
    Name="Toggle",Size=UDim2.new(0,130,0,26),Position=UDim2.new(0,8,0,10),
    BackgroundColor3=Color3.fromRGB(220,80,80),Font=Enum.Font.GothamBold,
    TextSize=13,TextColor3=Color3.fromRGB(255,255,255),Text="AntiAFK: OFF",
    AutoButtonColor = true, BorderSizePixel = 0
},mainCard)
makeCorner(antiToggleBtn,8)

local antiStatus = mk("TextLabel",{
    Name="Status",Size=UDim2.new(1,-16,0,20),Position=UDim2.new(0,8,0,42),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=Color3.fromRGB(90,90,120),TextXAlignment=Enum.TextXAlignment.Left,
    Text="Status: Idle"
},mainCard)

local antiUptimeAFK = mk("TextLabel",{
    Name="UptimeAFK",Size=UDim2.new(1,-16,0,18),Position=UDim2.new(0,8,0,64),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=Color3.fromRGB(90,90,120),TextXAlignment=Enum.TextXAlignment.Left,
    Text="Uptime AntiAFK: 00:00:00"
},mainCard)

local antiUptimePlay = mk("TextLabel",{
    Name="UptimePlay",Size=UDim2.new(1,-16,0,18),Position=UDim2.new(0,8,0,84),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=Color3.fromRGB(90,90,120),TextXAlignment=Enum.TextXAlignment.Left,
    Text="Uptime Play: 00:00:00"
},mainCard)

------------------- CARD 2: SMART AUTO NONAKTIF (JAM WITA) -------------------
local scheduleCard = mk("Frame",{
    Name="ScheduleCard",
    Size=UDim2.new(1,-4,0,240),
    BackgroundColor3=Color3.fromRGB(236,238,248),
    BorderSizePixel=0
}, body)
makeCorner(scheduleCard,10)
mk("UIStroke",{
    Thickness=1,
    Color=Color3.fromRGB(210,210,230),
    Transparency=0.3
}, scheduleCard)

local scheduleTitle = mk("TextLabel",{
    Name="Title",
    Position=UDim2.new(0,8,0,6),
    Size=UDim2.new(1,-16,0,18),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamSemibold,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(60,60,110),
    Text="⏱️ Smart Auto Nonaktif AntiAFK (Jam WITA + Remote API)"
}, scheduleCard)

local witaClockLabel = mk("TextLabel",{
    Name="WitaClock",
    Position=UDim2.new(0,8,0,24),
    Size=UDim2.new(1,-16,0,18),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(90,90,130),
    Text="Jam WITA sekarang: --:--:--"
}, scheduleCard)

mk("TextLabel",{
    Name="Info",
    Position=UDim2.new(0,8,0,42),
    Size=UDim2.new(1,-16,0,32),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true,
    TextColor3=Color3.fromRGB(90,90,130),
    Text="Checklist durasi di bawah = jadwal lokal. Remote API (/addtime) punya countdown sendiri dan akan override teks di sini kalau aktif."
}, scheduleCard)

local durationScroll = mk("ScrollingFrame",{
    Name="DurationScroll",
    Position=UDim2.new(0,8,0,78),
    Size=UDim2.new(1,-16,0,100),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0,0,0,0)
}, scheduleCard)

addPadding(durationScroll, 0,0,2,2)

local durationLayout = mk("UIListLayout",{
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,6),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top
}, durationScroll)

durationLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local abs = durationLayout.AbsoluteContentSize
    durationScroll.CanvasSize = UDim2.new(0,0,0,abs.Y + 4)
end)

local col1 = mk("Frame",{
    Name="Col1",
    BackgroundTransparency=1,
    Size=UDim2.new(0.5,-3,0,0),
    AutomaticSize = Enum.AutomaticSize.Y
}, durationScroll)

local col1Layout = mk("UIListLayout",{
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,2),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top
}, col1)

local col2 = mk("Frame",{
    Name="Col2",
    BackgroundTransparency=1,
    Size=UDim2.new(0.5,-3,0,0),
    AutomaticSize = Enum.AutomaticSize.Y
}, durationScroll)

local col2Layout = mk("UIListLayout",{
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,2),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top
}, col2)

local durationButtons = {}

local function makeDurationRow(parent, hours)
    local row = mk("Frame",{
        Name = "DurRow_"..hours,
        Size = UDim2.new(1,0,0,22),
        BackgroundTransparency=1
    }, parent)

    mk("UIListLayout",{
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0,6),
        VerticalAlignment = Enum.VerticalAlignment.Center
    }, row)

    local box = mk("TextButton",{
        Name="Check",
        Size=UDim2.new(0,22,0,22),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0,
        Font=Enum.Font.GothamBold,
        TextSize=14,
        TextColor3=Color3.fromRGB(40,40,70),
        Text="☐",
        AutoButtonColor = true
    }, row)
    makeCorner(box,4)

    local lbl = mk("TextLabel",{
        Name="Label",
        Size=UDim2.new(1,-40,1,0),
        BackgroundTransparency=1,
        Font=Enum.Font.Gotham,
        TextSize=11,
        TextColor3=Color3.fromRGB(60,60,110),
        TextXAlignment=Enum.TextXAlignment.Left,
        Text=string.format("%2d Jam", hours)
    }, row)

    local info = {
        hours    = hours,
        button   = box,
        label    = lbl,
        selected = false,
    }
    table.insert(durationButtons, info)

    return info
end

for h = 1, 12 do
    makeDurationRow(col1, h)
end
for h = 13, 24 do
    makeDurationRow(col2, h)
end

local minuteBox = mk("TextBox",{
    Name="MinuteBox",
    Position=UDim2.new(0,8,0,184),
    Size=UDim2.new(0,80,0,22),
    BackgroundColor3=Color3.fromRGB(255,255,255),
    BorderSizePixel=0,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextColor3=Color3.fromRGB(40,40,70),
    TextXAlignment=Enum.TextXAlignment.Center,
    ClearTextOnFocus=false,
    Text="0",
    PlaceholderText="Menit (0-60)"
}, scheduleCard)
makeCorner(minuteBox,6)

local minuteLabel = mk("TextLabel",{
    Name="MinuteLabel",
    Position=UDim2.new(0,92,0,184),
    Size=UDim2.new(1,-100,0,22),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(90,90,130),
    Text="Menit jadwal: bisa input menit atau ditambah ke jam yang dipilih."
}, scheduleCard)

local countdownLabel = mk("TextLabel",{
    Name="Countdown",
    Position=UDim2.new(0,8,0,208),
    Size=UDim2.new(1,-16,0,20),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(90,90,130),
    Text="Auto Nonaktif: Tidak ada jadwal (pakai tombol AntiAFK di atas)."
}, scheduleCard)

------------------- CARD 3: ADMIN & FRIENDS DETECT + WORDBAN -------------------
local adminCard = mk("Frame",{
    Name="AdminCard",
    Size=UDim2.new(1,-4,0,320),
    BackgroundColor3=Color3.fromRGB(236,238,248),
    BorderSizePixel=0
}, body)
makeCorner(adminCard,10)
mk("UIStroke",{
    Thickness=1,
    Color=Color3.fromRGB(210,210,230),
    Transparency=0.3
}, adminCard)

mk("TextLabel",{
    Name="AdminTitle",
    Position=UDim2.new(0,8,0,6),
    Size=UDim2.new(1,-16,0,18),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamSemibold,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(60,60,110),
    Text="🚨 Smart Admin/Friends Detect + Report Players + Wordban"
}, adminCard)

mk("TextLabel",{
    Name="AdminSub",
    Position=UDim2.new(0,8,0,24),
    Size=UDim2.new(1,-16,0,30),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true,
    TextColor3=Color3.fromRGB(90,90,130),
    Text="Admin/Developer/Head Admin/Tiktokers (ADMIN_IDS) bisa Auto Rejoin / Auto Leave. Friends bisa notif. Report Players: kirim list player ke API. Wordban: AutoLeave saat kata terlarang muncul di chat publik (All Player kecuali Friendlist). Ada daftar ADMIN dengan checkbox exclude, dan Wordban list dengan checkbox per-kata."
}, adminCard)

local adminBtnScroll = mk("ScrollingFrame",{
    Name="AdminBtnScroll",
    Position=UDim2.new(0,8,0,58),
    Size=UDim2.new(1,-16,0,40),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollingDirection=Enum.ScrollingDirection.X,
    CanvasSize=UDim2.new(0,0,0,0)
}, adminCard)

local adminBtnLayout = mk("UIListLayout",{
    FillDirection=Enum.FillDirection.Horizontal,
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,6),
    VerticalAlignment=Enum.VerticalAlignment.Center
}, adminBtnScroll)

adminBtnLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local abs = adminBtnLayout.AbsoluteContentSize
    adminBtnScroll.CanvasSize = UDim2.new(0,abs.X + 4,0,abs.Y)
end)

local function makeToggleButton(name,text,parent)
    local b = mk("TextButton",{
        Name=name,
        Size=UDim2.new(0,130,1,0),
        BackgroundColor3=Color3.fromRGB(200,200,210),
        BorderSizePixel=0,
        Font=Enum.Font.GothamBold,
        TextSize=11,
        TextColor3=Color3.fromRGB(60,60,80),
        Text=text,
        AutoButtonColor=true
    }, parent)
    makeCorner(b,8)
    return b
end

local onlyAdminBtn      = makeToggleButton("OnlyAdminBtn","Only Admin: OFF", adminBtnScroll)
local autoRejoinBtn     = makeToggleButton("AutoRejoinBtn","Auto Rejoin: OFF", adminBtnScroll)
local autoLeaveBtn      = makeToggleButton("AutoLeaveBtn","Auto Leave: OFF", adminBtnScroll)
local wordbanBtn        = makeToggleButton("WordbanBtn","Wordban: ON", adminBtnScroll)
local friendsBtn        = makeToggleButton("FriendsBtn","Friends: OFF", adminBtnScroll)
local reportPlayersBtn  = makeToggleButton("ReportPlayersBtn","Report Players: OFF", adminBtnScroll)

local adminStatusLabel = mk("TextLabel",{
    Name="AdminStatus",
    Position=UDim2.new(0,8,0,100),
    Size=UDim2.new(1,-16,0,20),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(90,90,130),
    Text="Status Admin/Friends: Idle."
}, adminCard)

-- Daftar ADMIN + checkbox (default semua ☑ = ikut deteksi; ☐ = DIKECUALIKAN)
local adminListScroll = mk("ScrollingFrame",{
    Name="AdminListScroll",
    Position=UDim2.new(0,8,0,122),
    Size=UDim2.new(1,-16,0,90),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0,0,0,0)
}, adminCard)

addPadding(adminListScroll, 0,0,2,2)

local adminListLayout = mk("UIListLayout",{
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,2),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top
}, adminListScroll)

adminListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local abs = adminListLayout.AbsoluteContentSize
    adminListScroll.CanvasSize = UDim2.new(0,0,0,abs.Y + 4)
end)

-- Buat array dari ADMIN_IDS agar urut & mudah di-loop
local adminArray = {}
for userId, info in pairs(ADMIN_IDS) do
    table.insert(adminArray, {
        userId      = userId,
        displayName = info.displayName or info.username or ("User "..tostring(userId)),
        username    = info.username or ("User"..tostring(userId)),
        role        = info.role or ""
    })
end
table.sort(adminArray, function(a,b)
    return (a.displayName or a.username) < (b.displayName or b.username)
end)

for _, info in ipairs(adminArray) do
    local row = mk("Frame",{
        Name = "AdminRow_" .. tostring(info.userId),
        Size = UDim2.new(1,0,0,20),
        BackgroundTransparency = 1,
    }, adminListScroll)

    mk("UIListLayout",{
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0,6),
        VerticalAlignment = Enum.VerticalAlignment.Center
    }, row)

    local box = mk("TextButton",{
        Name="ExcludeCheck",
        Size=UDim2.new(0,20,0,20),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0,
        Font=Enum.Font.GothamBold,
        TextSize=14,
        TextColor3=Color3.fromRGB(40,40,70),
        Text="☑", -- DEFAULT: semua admin IKUT deteksi
        AutoButtonColor=true
    }, row)
    makeCorner(box,4)

    local labelText
    local roleLabel = info.role or ""
    if roleLabel ~= "" then
        labelText = string.format("%s (@%s) %s", info.displayName, info.username, roleLabel)
    else
        labelText = string.format("%s (@%s)", info.displayName, info.username)
    end

    local label = mk("TextLabel",{
        Name="AdminLabel",
        Size=UDim2.new(1,-26,1,0),
        BackgroundTransparency=1,
        Font=Enum.Font.Gotham,
        TextSize=11,
        TextColor3=Color3.fromRGB(60,60,110),
        TextXAlignment=Enum.TextXAlignment.Left,
        Text=labelText
    }, row)

    adminExcludeRows[info.userId] = {
        button = box,
        label  = label,
        data   = info
    }

    bind(box.MouseButton1Click, function()
        local id = info.userId
        local isExcluded = excludedAdminIds[id] == true

        if isExcluded then
            excludedAdminIds[id] = nil
            box.Text = "☑"
            notify("Smart AntiAFK", string.format("Aktifkan lagi deteksi: %s (@%s).", info.displayName, info.username), 4)
        else
            excludedAdminIds[id] = true
            box.Text = "☐"
            notify("Smart AntiAFK", string.format("Kecualikan dari Auto Leave/Rejoin: %s (@%s).", info.displayName, info.username), 4)
        end
    end)
end

-- Wordban list UI: default semua kata Wordban AKTIF (☑)
local wordbanTitle = mk("TextLabel",{
    Name="WordbanListTitle",
    Position=UDim2.new(0,8,0,214),
    Size=UDim2.new(1,-16,0,18),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamSemibold,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(60,60,110),
    Text="Wordban List (kata yang diawasi):"
}, adminCard)

local wordbanListScroll = mk("ScrollingFrame",{
    Name="WordbanListScroll",
    Position=UDim2.new(0,8,0,234),
    Size=UDim2.new(1,-16,0,80),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0,0,0,0)
}, adminCard)

addPadding(wordbanListScroll, 0,0,2,2)

local wordbanListLayout = mk("UIListLayout",{
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,2),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top
}, wordbanListScroll)

wordbanListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local abs = wordbanListLayout.AbsoluteContentSize
    wordbanListScroll.CanvasSize = UDim2.new(0,0,0,abs.Y + 4)
end)

for _, w in ipairs(BASE_WORDBAN_WORDS) do
    local lowerWord = string.lower(w)
    local row = mk("Frame",{
        Name = "WordbanRow_" .. lowerWord,
        Size = UDim2.new(1,0,0,20),
        BackgroundTransparency = 1,
    }, wordbanListScroll)

    mk("UIListLayout",{
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0,6),
        VerticalAlignment = Enum.VerticalAlignment.Center
    }, row)

    local box = mk("TextButton",{
        Name="WordCheck",
        Size=UDim2.new(0,20,0,20),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0,
        Font=Enum.Font.GothamBold,
        TextSize=14,
        TextColor3=Color3.fromRGB(40,40,70),
        Text="☑", -- DEFAULT: semua wordban aktif
        AutoButtonColor=true
    }, row)
    makeCorner(box,4)

    local label = mk("TextLabel",{
        Name="WordLabel",
        Size=UDim2.new(1,-26,1,0),
        BackgroundTransparency=1,
        Font=Enum.Font.Gotham,
        TextSize=11,
        TextColor3=Color3.fromRGB(60,60,110),
        TextXAlignment=Enum.TextXAlignment.Left,
        Text=w
    }, row)

    wordbanRows[lowerWord] = {
        button = box,
        label  = label,
        word   = w
    }

    bind(box.MouseButton1Click, function()
        local enabled = wordbanEnabledMap[lowerWord] == true
        if enabled then
            wordbanEnabledMap[lowerWord] = nil
            box.Text = "☐"
            label.TextColor3 = Color3.fromRGB(130,130,130)
            notify("Smart AntiAFK", "Wordban OFF untuk kata: '"..w.."'.", 4)
        else
            wordbanEnabledMap[lowerWord] = true
            box.Text = "☑"
            label.TextColor3 = Color3.fromRGB(60,60,110)
            notify("Smart AntiAFK", "Wordban ON untuk kata: '"..w.."'.", 4)
        end
    end)
end

------------------- UPTIME FORMATTER -------------------
local function formatHMS(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    sec = sec % 3600
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

------------------- STATE UPTIME / PERIODIC -------------------
local playSeconds, antiAFKSeconds, uptimeUpdateAcc = 0, 0, 0
local clockAcc = 0
local statusWebhookAcc = 0
local reportPlayersAcc, reportPlayersInitSent = 0, false

-- Interval periodik acak (5m, 10m, 20m, 30m, 1h)
local STATUS_INTERVAL_OPTIONS = {300, 600, 1200, 1800, 3600}
local statusNextInterval = STATUS_INTERVAL_OPTIONS[1]
local periodicStopped = false

pcall(function()
    math.randomseed(tick() * 1000)
end)

local function pickNextStatusInterval()
    local idx = math.random(1, #STATUS_INTERVAL_OPTIONS)
    statusNextInterval = STATUS_INTERVAL_OPTIONS[idx]
end

-- STATE REMOTE API (Discord /addtime)
local API_ACTIVE_INTERVAL = 10
local API_IDLE_INTERVAL   = 60
local apiPollAcc          = 0
local currentApiInterval  = API_IDLE_INTERVAL

local remoteEnabled       = false
local remoteExpireUtc     = nil
local remoteJsonLoadedNotified = false
local remoteTotalSec      = 0
local remoteStartUtc      = nil

------------------- ANTI AFK LOGIC -------------------
local player = LocalPlayer
local BRAND = "AxaXyz"
local BUTTON_ROOT_NAME = "AxaXyzReplayUI"

local lastState, lastNotifyAt = nil, 0
local NOTIFY_MIN_GAP = 6

local AUTO_START             = true
local AUTO_RESPAWN           = true
local STOP_DELAY             = 25
local RESPAWN_DELAY          = 10
local MOVE_THRESHOLD         = 0.05
local RETRY_INTERVAL         = 10
local COOLDOWN_AFTER_RESPAWN = 30

local hrp, toggleBtn, lastPos
local stillTime, totalDist = 0, 0
local lastAutoStart, justRestarted = 0, false
local afterRespawn = false

local antiEnabled, antiLoopStarted = false, false
local antiIdleConn

local function BrandTitle()
    return BRAND .. " AntiAFK+"
end

local function push(msg, dur)
    local now = time()
    if now - lastNotifyAt >= NOTIFY_MIN_GAP then
        notify(BrandTitle(), msg, dur or 6)
        lastNotifyAt = now
    end
end

_G.AxaXyzStatus = function(text, color)
    if antiStatus then
        antiStatus.Text = "Status: " .. text
        if color then antiStatus.TextColor3 = color end
    end
end

local function setStatus(text, color)
    _G.AxaXyzStatus(text, color)
end

local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    char:WaitForChild("Humanoid")
    return char:WaitForChild("HumanoidRootPart")
end

local function clickButton(btn)
    if not (btn and btn.Parent) then return end
    if pcall(function() btn:Activate() end) then return end
    if VirtualInputManager then
        local c = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
        VirtualInputManager:SendMouseButtonEvent(c.X,c.Y,0,true,game,0)
        VirtualInputManager:SendMouseButtonEvent(c.X,c.Y,0,false,game,0)
    end
end

local function getButtonText()
    return (toggleBtn and toggleBtn.Parent and (toggleBtn.Text or ""):lower()) or ""
end

local function findToggleButtonOnce()
    for _, g in ipairs(game:GetDescendants()) do
        if g:IsA("TextButton") then
            local txt = g.Text or ""
            if (txt:find("Start") or txt:find("Stop")) then
                local p = g.Parent
                if p and (p.Name == BUTTON_ROOT_NAME or (p.Parent and p.Parent.Name == BUTTON_ROOT_NAME)) then
                    return g
                end
            end
        end
    end
end

local function waitForToggleButton()
    local ui
    repeat
        task.wait(0.5)
        ui = findToggleButtonOnce()
    until ui or not alive
    if not ui then return nil end
    print("["..BrandTitle().."] Tombol replay ditemukan:", ui.Text)
    return ui
end

local function setAntiEnabledUI(state)
    antiEnabled = state
    if state then
        antiToggleBtn.BackgroundColor3 = Color3.fromRGB(80,180,80)
        antiToggleBtn.Text             = "AntiAFK: ON"
        setStatus("Menahan idle kick...", Color3.fromRGB(90,150,90))
    else
        antiToggleBtn.BackgroundColor3 = Color3.fromRGB(220,80,80)
        antiToggleBtn.Text             = "AntiAFK: OFF"
        setStatus("Idle", Color3.fromRGB(90,90,120))
    end
end

local function respawnChar()
    if not antiEnabled or not alive then return end

    local char = player.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if hum then
        setStatus("🔴 Respawning...", Color3.fromRGB(255,100,100))
        push("Respawning...")
        hum.Health = 0
    end

    if not alive then return end
    player.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
    task.wait(10)

    if not alive then return end
    hrp = getHRP()
    afterRespawn = true
    toggleBtn = findToggleButtonOnce() or waitForToggleButton()

    if not toggleBtn then return end

    local txt = getButtonText()
    if txt:find("stop") then
        clickButton(toggleBtn)
        task.wait(0.5)
    end
    if getButtonText():find("start") then
        clickButton(toggleBtn)
        setStatus("🟢 Auto Start after Respawn", Color3.fromRGB(100,255,100))
        push("Auto-start setelah respawn ✅")
        lastState = "running"
    end

    task.spawn(function()
        task.wait(COOLDOWN_AFTER_RESPAWN)
        afterRespawn = false
    end)
end

local function startAntiLoop()
    if antiLoopStarted then return end
    antiLoopStarted = true

    task.spawn(function()
        while alive do
            task.wait(1)
            if not alive then break end
            if not antiEnabled then continue end

            if not (hrp and hrp.Parent) then
                hrp = getHRP()
                if hrp then lastPos = hrp.Position end
                stillTime, totalDist, justRestarted, lastState = 0,0,false,nil
                continue
            end

            local dist = (hrp.Position - lastPos).Magnitude
            totalDist += dist
            lastPos = hrp.Position

            if dist < MOVE_THRESHOLD then
                stillTime += 1
            else
                stillTime, totalDist, justRestarted = 0,0,false
            end

            if afterRespawn then
                stillTime = 0
                continue
            end

            if stillTime == 0 then
                setStatus("🟢 Running", Color3.fromRGB(100,255,100))
                if lastState ~= "running" then
                    push("Running ✅")
                    lastState = "running"
                end
            elseif stillTime < RESPAWN_DELAY then
                setStatus(("🟡 Idle %ds"):format(stillTime), Color3.fromRGB(255,255,150))
                if lastState ~= "idle" and stillTime >= math.max(2, math.floor(RESPAWN_DELAY/2)) then
                    push(("Idle %ds"):format(stillTime))
                    lastState = "idle"
                end
            end

            if AUTO_RESPAWN and stillTime >= RESPAWN_DELAY then
                respawnChar()
                stillTime, totalDist, justRestarted = 0,0,false
                continue
            end

            local now = time()
            if AUTO_START and stillTime >= STOP_DELAY and totalDist < 0.5 and (now - lastAutoStart > RETRY_INTERVAL) then
                if not (toggleBtn and toggleBtn.Parent) then
                    toggleBtn = waitForToggleButton()
                end
                if not toggleBtn then
                    continue
                end

                if justRestarted and (now - lastAutoStart) > (RETRY_INTERVAL * 2) then
                    justRestarted = false
                end

                if not justRestarted then
                    setStatus("🔵 Restarting Route...", Color3.fromRGB(100,150,255))
                    push("Restarting route... 🔄")

                    local t2 = getButtonText()
                    if t2:find("stop") then
                        clickButton(toggleBtn)
                        task.wait(0.6)
                    end
                    if getButtonText():find("start") then
                        lastAutoStart = now
                        justRestarted = true
                        setStatus("🟢 Running", Color3.fromRGB(100,255,100))
                        push("Running ✅")
                        lastState = "running"
                    end
                end
                stillTime, totalDist = 0,0
            end
        end
    end)
end

------------------- WITA / MAP INFO HELPERS -------------------
local WITA_OFFSET = 8 * 60 * 60

local function getUtcNow()
    return os.time(os.date("!*t"))
end

local function utcToWitaStruct(utc)
    return os.date("!*t", utc + WITA_OFFSET)
end

local function fmtHM(h,m)
    return string.format("%02d.%02d", h, m)
end

local placeNameCache = {}

local function shortJobId(jobId)
    if not jobId then return "????" end
    local seg = tostring(jobId):match("^%x+%-(%x%x%x%x)%-")
    return (seg and seg:upper()) or "????"
end

local function getPlaceName(placeId)
    if not placeId or placeId == 0 then
        return "Unknown Place"
    end
    if placeNameCache[placeId] then
        return placeNameCache[placeId]
    end

    local name = ("Place %d"):format(placeId)
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(placeId)
    end)
    if ok and info and info.Name then
        name = tostring(info.Name)
    end

    placeNameCache[placeId] = name
    return name
end

------------------- REPORT PLAYERS SENDER (POST ke API) ----------------------
local reportPlayersEnabled = REPORT_PLAYERS_ENABLED

local function sendReportPlayers(reason)
    if not reportPlayersEnabled then return end
    if not REPORT_PLAYERS_URL or REPORT_PLAYERS_URL == "" then return end

    local payload = {
        serverId  = game.JobId,
        placeId   = game.PlaceId,
        placeName = getPlaceName(game.PlaceId),
        players   = {},
        reason    = reason or "interval",
    }

    for _, plr in ipairs(Players:GetPlayers()) do
        table.insert(payload.players, {
            userId      = plr.UserId,
            username    = plr.Name,
            displayName = plr.DisplayName,
        })
    end

    local encoded = HttpService:JSONEncode(payload)

    local ok, err = pcall(function()
        local req =
            (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
            or (fluxus and fluxus.request)
            or (krnl and krnl.request)

        if req then
            req({
                Url     = REPORT_PLAYERS_URL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = encoded,
            })
        else
            HttpService:PostAsync(
                REPORT_PLAYERS_URL,
                encoded,
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end
    end)

    if not ok then
        warn("[AntiAFK] Gagal POST /report-players:", err)
    end
end

------------------- SCHEDULE STATE -------------------
local scheduleActive      = false
local scheduleStartUtc    = nil
local scheduleEndUtc      = nil
local scheduleDurationSec = 0

_G.__AntiAFK_ScheduleDuration = 0
_G.__AntiAFK_RemoteTotal      = 0

------------------- WORDBAN HIGHLIGHT HELPERS -------------------
local function highlightWordbanInMessage(msg)
    if not msg or msg == "" then return msg end
    if not BASE_WORDBAN_WORDS then return msg end

    local lower = msg:lower()
    local spans = {}

    for _, w in ipairs(BASE_WORDBAN_WORDS) do
        local wl = tostring(w or ""):lower()
        if wl ~= "" then
            local from = 1
            while true do
                local i, j = lower:find(wl, from, true)
                if not i then break end
                table.insert(spans, {i, j})
                from = j + 1
            end
        end
    end

    if #spans == 0 then
        return msg
    end

    table.sort(spans, function(a,b) return a[1] < b[1] end)

    local merged = {}
    for _, span in ipairs(spans) do
        local last = merged[#merged]
        if not last then
            table.insert(merged, {span[1], span[2]})
        else
            if span[1] <= last[2] + 1 then
                if span[2] > last[2] then
                    last[2] = span[2]
                end
            else
                table.insert(merged, {span[1], span[2]})
            end
        end
    end

    local parts = {}
    local pos = 1
    for _, span in ipairs(merged) do
        local s, e = span[1], span[2]
        if pos < s then
            table.insert(parts, msg:sub(pos, s-1))
        end
        table.insert(parts, "**" .. msg:sub(s, e) .. "**")
        pos = e + 1
    end
    if pos <= #msg then
        table.insert(parts, msg:sub(pos))
    end

    return table.concat(parts)
end

------------------- WEBHOOK SENDER -------------------
local webhookErrorCount = 0

sendWebhook = function(eventType, data)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end

    local ok, err = pcall(function()
        local utcNow = getUtcNow()
        local wita = utcToWitaStruct(utcNow)
        local timeStr = string.format(
            "%02d-%02d-%04d %02d:%02d:%02d WITA",
            wita.day, wita.month, wita.year,
            wita.hour, wita.min, wita.sec
        )

        local placeId   = game.PlaceId
        local placeName = getPlaceName(placeId)
        local serverShort = shortJobId(game.JobId)

        local localDn = LocalPlayer.DisplayName or LocalPlayer.Name
        local localUn = LocalPlayer.Name
        local localId = LocalPlayer.UserId

        local scheduleText
        if data and data.scheduleTextOverride then
            scheduleText = data.scheduleTextOverride
        else
            if _G.__AntiAFK_ScheduleDuration and _G.__AntiAFK_ScheduleDuration > 0 then
                scheduleText = formatHMS(_G.__AntiAFK_ScheduleDuration)
            else
                scheduleText = "Tidak ada / 0"
            end
        end

        local antiUptimeText = formatHMS(antiAFKSeconds or 0)
        local playUptimeText = formatHMS(playSeconds or 0)

        local titleMap = {
            AntiAFK_ON      = "AntiAFK: ON",
            AntiAFK_OFF     = "AntiAFK: OFF",
            Admin_Join      = "Admin Detected",
            Friend_Join     = "Friend Detected",
            Schedule_Update = "Jadwal Auto Nonaktif",
            Periodic_Status = "Status Periodik",
            Wordban_Leave   = "Wordban Auto Leave",
        }

        local title = (data and data.titleOverride)
                    or titleMap[eventType]
                    or (eventType or "AntiAFK Event")

        local descText = (data and data.description) or ""

        local reasonText = (data and (data.reason or "-")) or "-"
        local eventInfoValue = string.format(
            "Event: `%s`\nReason: `%s`\nWaktu: `%s`",
            eventType or "-",
            reasonText,
            timeStr
        )

        if eventType == "Wordban_Leave" and data and data.messageText then
            local highlighted = highlightWordbanInMessage(data.messageText)
            eventInfoValue = eventInfoValue .. "\nWord: " .. highlighted
        end

        local fields = {
            {
                name  = "Local Player",
                value = string.format(
                    "%s (@%s)\nUserId: `%d`",
                    localDn, localUn, localId
                ),
                inline = true
            },
            {
                name  = "Map Info",
                value = string.format(
                    "Map: **%s**\nPlaceId: `%d`\nServer: `%s`",
                    placeName, placeId, serverShort
                ),
                inline = true
            },
            {
                name  = "Uptime",
                value = string.format(
                    "Play: `%s`\nAntiAFK: `%s`",
                    playUptimeText, antiUptimeText
                ),
                inline = true
            },
            {
                name  = "Jadwal Auto Nonaktif",
                value = string.format(
                    "Durasi (H:M:S): `%s`",
                    scheduleText
                ),
                inline = true
            },
            {
                name  = "Event Info",
                value = eventInfoValue,
                inline = false
            },
            {
                name  = "Owner",
                value = DEFAULT_OWNER_DISCORD,
                inline = false
            }
        }

        if data and data.targetPlayer then
            local plr = data.targetPlayer
            local tDn = plr.DisplayName or plr.Name
            local tUn = plr.Name
            local tId = plr.UserId
            local isAdminStr  = data.isAdmin  and "YA" or "TIDAK"
            local isFriendStr = data.isFriend and "YA" or "TIDAK"

            local roleExtra = ""
            if data.roleGroup or data.rawRole then
                roleExtra = string.format("\nRole: **%s**", data.roleGroup or data.rawRole)
            end

            table.insert(fields, 1, {
                name  = "Target Player",
                value = string.format(
                    "%s (@%s)\nUserId: `%d`\nAdminList: **%s**\nFriend: **%s**%s",
                    tDn, tUn, tId, isAdminStr, isFriendStr, roleExtra
                ),
                inline = true
            })
        end

        if data and data.modeText then
            table.insert(fields, {
                name  = "Mode Deteksi",
                value = data.modeText,
                inline = false
            })
        end

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = (BOT_AVATAR_URL ~= "" and BOT_AVATAR_URL) or nil,
            content    = DEFAULT_OWNER_DISCORD,
            embeds     = {
                {
                    title       = title,
                    description = descText,
                    color       = (data and data.color) or 0x5C7AEA,
                    fields      = fields
                }
            }
        }

        local req =
            (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
            or (fluxus and fluxus.request)
            or (krnl and krnl.request)

        local bodyJson = HttpService:JSONEncode(payload)

        if req then
            req({
                Url     = WEBHOOK_URL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = bodyJson,
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, bodyJson, Enum.HttpContentType.ApplicationJson)
        end
    end)

    if not ok then
        webhookErrorCount += 1
        warn("[AntiAFK] Gagal kirim webhook:", err)
    else
        webhookErrorCount = 0
    end
end

------------------- SCHEDULE / DURASI (LOKAL UI) -------------------
local function sanitizeMinuteBox()
    local n = tonumber(minuteBox.Text)
    if not n then n = 0 end
    n = math.floor(n)
    if n < 0 then n = 0 end
    if n > 60 then n = 60 end
    minuteBox.Text = tostring(n)
    return n
end

local function getMaxSelectedHours()
    local maxH
    for _, info in ipairs(durationButtons) do
        if info.selected then
            if (not maxH) or info.hours > maxH then
                maxH = info.hours
            end
        end
    end
    return maxH
end

local function recalcScheduleFromUI()
    local hadActive = scheduleActive
    local maxH      = getMaxSelectedHours()
    local extraMin  = sanitizeMinuteBox()

    if (not maxH) and extraMin <= 0 then
        scheduleActive      = false
        scheduleStartUtc    = nil
        scheduleEndUtc      = nil
        scheduleDurationSec = 0
        _G.__AntiAFK_ScheduleDuration = 0
        if countdownLabel and (not remoteEnabled) then
            countdownLabel.Text = "Auto Nonaktif: Tidak ada jadwal (pakai tombol AntiAFK di atas)."
        end
        if hadActive then
            notify("Smart AntiAFK", "Jadwal Auto Nonaktif dibatalkan (tidak ada durasi terpilih).", 4)
            sendWebhook("Schedule_Update",{
                reason      = "Schedule_Cleared",
                description = "Jadwal Auto Nonaktif dibatalkan (tidak ada jam/menit aktif).",
                color       = 0xFFAA00,
                scheduleTextOverride = "Tidak ada / 0"
            })
        end
        return
    end

    local hoursUsed = maxH or 0
    local dur       = hoursUsed*3600 + extraMin*60

    if dur <= 0 then
        scheduleActive      = false
        scheduleStartUtc    = nil
        scheduleEndUtc      = nil
        scheduleDurationSec = 0
        _G.__AntiAFK_ScheduleDuration = 0
        if countdownLabel and (not remoteEnabled) then
            countdownLabel.Text = "Auto Nonaktif: Durasi 0, jadwal diabaikan."
        end

        sendWebhook("Schedule_Update",{
            reason      = "Schedule_Zero",
            description = "Input jadwal menghasilkan durasi 0 detik, jadwal diabaikan.",
            color       = 0xFFAA00,
            scheduleTextOverride = "0"
        })
        return
    end

    local utcNow = getUtcNow()
    scheduleStartUtc    = utcNow
    scheduleEndUtc      = utcNow + dur
    scheduleDurationSec = dur
    scheduleActive      = true
    _G.__AntiAFK_ScheduleDuration = dur

    local endWita = utcToWitaStruct(scheduleEndUtc)
    if countdownLabel and (not remoteEnabled) then
        countdownLabel.Text = string.format(
            "Auto Nonaktif: AntiAFK OFF dalam %s (sekitar %02d:%02d WITA).",
            formatHMS(dur),
            endWita.hour, endWita.min
        )
    end

    local desc = string.format(
        "Jadwal Auto Nonaktif diubah menjadi %d jam %d menit. AntiAFK akan dimatikan sekitar %02d:%02d WITA.",
        hoursUsed, extraMin, endWita.hour, endWita.min
    )

    notify("Smart AntiAFK", desc, 5)

    sendWebhook("Schedule_Update",{
        reason      = "Schedule_Changed_LocalUI",
        description = desc,
        color       = 0x5C7AEA,
        scheduleTextOverride = formatHMS(dur)
    })
end

for _, info in ipairs(durationButtons) do
    bind(info.button.MouseButton1Click, function()
        if info.selected then
            info.selected = false
            info.button.Text = "☐"
        else
            for _, other in ipairs(durationButtons) do
                if other ~= info and other.selected then
                    other.selected = false
                    other.button.Text = "☐"
                end
            end
            info.selected = true
            info.button.Text = "☑"
        end
        recalcScheduleFromUI()
    end)
end

bind(minuteBox.FocusLost, function()
    recalcScheduleFromUI()
end)

------------------- ADMIN & FRIENDS DETECT + REPORT + WORDBAN TOGGLE ---------
local adminDetectEnabled   = true
local autoRejoinOnAdmin    = false
local autoLeaveOnAdmin     = true
local friendsDetectEnabled = false
local wordbanEnabled       = true

local function refreshAdminButtons()
    if onlyAdminBtn then
        if adminDetectEnabled then
            onlyAdminBtn.Text = "Only Admin: ON"
            onlyAdminBtn.BackgroundColor3 = Color3.fromRGB(180,130,70)
            onlyAdminBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            onlyAdminBtn.Text = "Only Admin: OFF"
            onlyAdminBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            onlyAdminBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if autoRejoinBtn then
        if autoRejoinOnAdmin then
            autoRejoinBtn.Text = "Auto Rejoin: ON"
            autoRejoinBtn.BackgroundColor3 = Color3.fromRGB(90,150,220)
            autoRejoinBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            autoRejoinBtn.Text = "Auto Rejoin: OFF"
            autoRejoinBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            autoRejoinBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if autoLeaveBtn then
        if autoLeaveOnAdmin then
            autoLeaveBtn.Text = "Auto Leave: ON"
            autoLeaveBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
            autoLeaveBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            autoLeaveBtn.Text = "Auto Leave: OFF"
            autoLeaveBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            autoLeaveBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if wordbanBtn then
        if wordbanEnabled then
            wordbanBtn.Text = "Wordban: ON"
            wordbanBtn.BackgroundColor3 = Color3.fromRGB(150,110,190)
            wordbanBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            wordbanBtn.Text = "Wordban: OFF"
            wordbanBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            wordbanBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if friendsBtn then
        if friendsDetectEnabled then
            friendsBtn.Text = "Friends: ON"
            friendsBtn.BackgroundColor3 = Color3.fromRGB(110,190,140)
            friendsBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            friendsBtn.Text = "Friends: OFF"
            friendsBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            friendsBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if reportPlayersBtn then
        if reportPlayersEnabled then
            reportPlayersBtn.Text = "Report Players: ON"
            reportPlayersBtn.BackgroundColor3 = Color3.fromRGB(120,120,220)
            reportPlayersBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            reportPlayersBtn.Text = "Report Players: OFF"
            reportPlayersBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            reportPlayersBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end
end

refreshAdminButtons()

bind(onlyAdminBtn.MouseButton1Click, function()
    adminDetectEnabled = not adminDetectEnabled
    refreshAdminButtons()
    notify("Smart AntiAFK", "Only Admin Detect: " .. (adminDetectEnabled and "ON" or "OFF"), 4)
end)

bind(autoRejoinBtn.MouseButton1Click, function()
    autoRejoinOnAdmin = not autoRejoinOnAdmin
    refreshAdminButtons()
    notify("Smart AntiAFK", "Auto Rejoin saat Admin join: " .. (autoRejoinOnAdmin and "ON" or "OFF"), 4)
end)

bind(autoLeaveBtn.MouseButton1Click, function()
    autoLeaveOnAdmin = not autoLeaveOnAdmin
    refreshAdminButtons()
    notify("Smart AntiAFK", "Auto Leave saat Admin join: " .. (autoLeaveOnAdmin and "ON" or "OFF"), 4)
end)

bind(wordbanBtn.MouseButton1Click, function()
    wordbanEnabled = not wordbanEnabled
    refreshAdminButtons()
    notify(
        "Smart AntiAFK",
        "Wordban Chat: " .. (wordbanEnabled and "ON (Auto Leave saat kata terlarang muncul)" or "OFF"),
        4
    )
end)

bind(friendsBtn.MouseButton1Click, function()
    friendsDetectEnabled = not friendsDetectEnabled
    refreshAdminButtons()
    notify("Smart AntiAFK", "Friends Detect: " .. (friendsDetectEnabled and "ON" or "OFF"), 4)
end)

bind(reportPlayersBtn.MouseButton1Click, function()
    reportPlayersEnabled = not reportPlayersEnabled
    if not reportPlayersEnabled then
        reportPlayersAcc       = 0
        reportPlayersInitSent  = false
    end
    refreshAdminButtons()
    notify(
        "Smart AntiAFK",
        "Report Players: " .. (reportPlayersEnabled and "ON (kirim list player ke API)" or "OFF (stop kirim ke API)"),
        4
    )
end)

local function isFriend(userId)
    local ok, res = pcall(function()
        return LocalPlayer:IsFriendsWith(userId)
    end)
    return ok and res
end

------------------- WORDBAN CHAT HANDLER -------------------
local function checkMessageForWordban(plr, msg)
    if not alive then return end
    if not wordbanEnabled then return end
    if not plr or not plr.UserId then return end
    if plr == LocalPlayer then return end
    if isFriend(plr.UserId) then return end

    local text = tostring(msg or "")
    if text == "" then return end
    local lower = text:lower()

    for _, w in ipairs(BASE_WORDBAN_WORDS) do
        local wl = tostring(w or ""):lower()
        if wl ~= "" and wordbanEnabledMap[wl] and lower:find(wl, 1, true) then
            local dn = plr.DisplayName or plr.Name
            local uname = plr.Name

            local adminInfoWB = ADMIN_IDS[plr.UserId]
            local roleGroupWB = adminInfoWB and getRoleGroup(adminInfoWB) or nil
            local rawRoleWB   = adminInfoWB and adminInfoWB.role or nil

            notify(
                "Smart AntiAFK",
                ("Wordban: '%s' terdeteksi di chat publik oleh %s, Auto Leave..."):format(w, dn),
                5
            )

            periodicStopped = true

            sendWebhook("Wordban_Leave",{
                reason       = "Wordban_Detected",
                description  = string.format(
                    "Kata terlarang '%s' terdeteksi di chat publik oleh %s (@%s). Auto Leave di-trigger.",
                    w, dn, uname
                ),
                color        = 0xFF4444,
                targetPlayer = plr,
                isAdmin      = (adminInfoWB ~= nil),
                isFriend     = false,
                messageText  = text,
                roleGroup    = roleGroupWB,
                rawRole      = rawRoleWB,
            })

            task.delay(0.3, function()
                if alive then
                    LocalPlayer:Kick("[Axa AntiAFK] Wordban chat publik terdeteksi, auto leave.")
                end
            end)

            break
        end
    end
end

local function attachChatListenerToPlayer(plr)
    if not plr or not plr:IsA("Player") then return end
    if plr == LocalPlayer then return end

    local ok, conn = pcall(function()
        return plr.Chatted:Connect(function(msg)
            checkMessageForWordban(plr, msg)
        end)
    end)

    if ok and conn then
        table.insert(connections, conn)
    end
end

local okTCS, TextChatService = pcall(function()
    return game:GetService("TextChatService")
end)

if okTCS and TextChatService then
    local okConn, conn = pcall(function()
        return TextChatService.MessageReceived:Connect(function(message)
            local source = message.TextSource
            if not source then return end
            local userId = source.UserId
            if not userId then return end

            local plr = Players:GetPlayerByUserId(userId)
            if not plr then return end

            checkMessageForWordban(plr, message.Text)
        end)
    end)
    if okConn and conn then
        table.insert(connections, conn)
    end
end

------------------- ADMIN / FRIEND JOIN HANDLER -------------------
local function handleAdminOrFriendJoin(plr)
    if not alive then return end
    if plr == LocalPlayer then return end

    local uid = plr.UserId
    local adminInfo = ADMIN_IDS[uid]
    local isAdminList = (adminInfo ~= nil)
    local isExcluded  = excludedAdminIds[uid] == true
    local isAdmin     = isAdminList and (not isExcluded)
    local friend      = isFriend(uid)

    if isAdmin and adminDetectEnabled then
        local dn = plr.DisplayName or plr.Name
        local roleGroup = getRoleGroup(adminInfo)
        local rawRole   = adminInfo and adminInfo.role or nil

        adminStatusLabel.Text = string.format("Status Admin/Friends: %s join (%s).", roleGroup, dn)
        push(roleGroup .. " terdeteksi join: "..dn.." (@ "..plr.Name..")", 5)
        setStatus("🚨 "..roleGroup.." join: "..dn, Color3.fromRGB(255,120,120))

        local modeText = string.format(
            "AdminDetect=%s | AutoRejoin=%s | AutoLeave=%s | FriendsDetect=%s | Wordban=%s | Excluded=%s",
            adminDetectEnabled and "ON" or "OFF",
            autoRejoinOnAdmin and "ON" or "OFF",
            autoLeaveOnAdmin and "ON" or "OFF",
            friendsDetectEnabled and "ON" or "OFF",
            wordbanEnabled and "ON" or "OFF",
            isExcluded and "YA" or "TIDAK"
        )

        local titleOverride = string.format("%s Detected", roleGroup)
        local descText = string.format("%s **%s (@%s)** terdeteksi join.", roleGroup, dn, plr.Name)

        sendWebhook("Admin_Join",{
            reason       = roleGroup .. " join server",
            description  = descText,
            color        = 0xFF8800,
            targetPlayer = plr,
            isAdmin      = isAdminList,
            isFriend     = friend,
            modeText     = modeText,
            titleOverride= titleOverride,
            roleGroup    = roleGroup,
            rawRole      = rawRole,
            excluded     = isExcluded
        })

        if autoLeaveOnAdmin then
            periodicStopped = true
            notify("Smart AntiAFK", "Auto Leave: "..roleGroup.." terdeteksi, keluar dari game.", 5)
            task.delay(0.3, function()
                if alive then
                    LocalPlayer:Kick("[Axa AntiAFK] "..roleGroup.." terdeteksi, auto leave.")
                end
            end)
            return
        elseif autoRejoinOnAdmin then
            periodicStopped = true
            notify("Smart AntiAFK", "Auto Rejoin: "..roleGroup.." terdeteksi, teleport ke server baru.", 5)
            task.delay(0.3, function()
                if alive then
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
            return
        end
    end

    if friendsDetectEnabled and friend then
        local dn = plr.DisplayName or plr.Name
        adminStatusLabel.Text = string.format("Status Admin/Friends: Friend join (%s).", dn)
        notify("Smart AntiAFK", "Friend bergabung: "..dn.." (@ "..plr.Name..")", 4)

        local modeText = string.format(
            "FriendsDetect=%s | AdminDetect=%s | Wordban=%s",
            friendsDetectEnabled and "ON" or "OFF",
            adminDetectEnabled and "ON" or "OFF",
            wordbanEnabled and "ON" or "OFF"
        )

        local friendAdminInfo = ADMIN_IDS[uid]
        local friendRoleGroup = friendAdminInfo and getRoleGroup(friendAdminInfo) or nil
        local friendRawRole   = friendAdminInfo and friendAdminInfo.role or nil

        sendWebhook("Friend_Join",{
            reason       = "Friend join server",
            description  = string.format("Friend %s (@%s) bergabung ke map yang sama.", dn, plr.Name),
            color        = 0x34C3FF,
            targetPlayer = plr,
            isAdmin      = (friendAdminInfo ~= nil),
            isFriend     = true,
            modeText     = modeText,
            roleGroup    = friendRoleGroup,
            rawRole      = friendRawRole
        })
    end
end

bind(Players.PlayerAdded, function(plr)
    task.defer(function()
        handleAdminOrFriendJoin(plr)
        attachChatListenerToPlayer(plr)
    end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    handleAdminOrFriendJoin(plr)
    attachChatListenerToPlayer(plr)
end

------------------- ENABLE / DISABLE ANTIAFK -------------------
local function enableAntiAFK()
    if not alive then return end

    hrp = getHRP()
    if not (toggleBtn and toggleBtn.Parent) then
        toggleBtn = findToggleButtonOnce()
    end

    if not antiIdleConn then
        antiIdleConn = Players.LocalPlayer.Idled:Connect(function()
            if not antiEnabled or not alive then return end
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(
                Vector2.new(0,0),
                (workspace.CurrentCamera and workspace.CurrentCamera.CFrame) or CFrame.new()
            )
        end)
        table.insert(connections, antiIdleConn)
    end

    setAntiEnabledUI(true)
    push("UI AntiAFK+ aktif ✅")

    sendWebhook("AntiAFK_ON",{
        reason      = "AntiAFK_ON",
        description = "AntiAFK diaktifkan dari UI atau oleh Remote API.",
        color       = 0x00C896
    })

    startAntiLoop()
end

local function disableAntiAFK(reason)
    local wasEnabled    = antiEnabled
    local isScheduleOff = (type(reason) == "string") and (reason:match("ScheduleTimeUp") ~= nil)

    setAntiEnabledUI(false)
    stillTime, totalDist, justRestarted = 0,0,false
    lastState, afterRespawn = nil, false

    antiAFKSeconds = 0
    if antiUptimeAFK then
        antiUptimeAFK.Text = "Uptime AntiAFK: " .. formatHMS(0)
    end

    if wasEnabled or isScheduleOff then
        push("AntiAFK+ dimatikan ⛔️")
        sendWebhook("AntiAFK_OFF",{
            reason      = reason or "ManualToggle_OFF",
            description = "AntiAFK dimatikan.",
            color       = 0xFF5555
        })
    end
end

bind(antiToggleBtn.MouseButton1Click, function()
    if antiEnabled then
        disableAntiAFK("ManualToggle_OFF")
    else
        enableAntiAFK()
    end
end)

_G.AxaHub_AntiAFK_Disable = disableAntiAFK

------------------- HEARTBEAT: UPTIME, WITA, API, PERIODIC -------------------
bind(RunService.Heartbeat, function(dt)
    if not alive then return end

    playSeconds   += dt
    if antiEnabled then
        antiAFKSeconds += dt
    end

    uptimeUpdateAcc  += dt
    clockAcc         += dt
    apiPollAcc       += dt
    reportPlayersAcc = reportPlayersAcc + dt

    --------- REMOTE API /addtime POLLING ----------
    if apiPollAcc >= currentApiInterval then
        apiPollAcc = 0
        task.spawn(function()
            local cfg = fetchRemoteAntiAFKConfig()
            if not cfg then
                currentApiInterval = API_IDLE_INTERVAL
                return
            end

            local utcNow     = getUtcNow()
            local newEnabled = (cfg.enabled == true)
            local newExpire  = tonumber(cfg.expireAt) or 0

            if newExpire > 0 and not remoteJsonLoadedNotified then
                remoteJsonLoadedNotified = true
                notify(
                    "Load AntiAFK",
                    ("Berhasil load JSON AntiAFK (UserId: %d)"):format(LocalPlayer.UserId),
                    4
                )
            end

            local prevEnabled = remoteEnabled
            local prevExpire  = remoteExpireUtc

            if (not newEnabled) or newExpire <= utcNow then
                if remoteEnabled then
                    remoteEnabled   = false
                    remoteExpireUtc = nil
                    remoteTotalSec  = 0
                    remoteStartUtc  = nil
                    _G.__AntiAFK_RemoteTotal = 0

                    if antiEnabled then
                        disableAntiAFK("RemoteAPI_ExpiredOrOff")
                    end

                    sendWebhook("Schedule_Update",{
                        reason      = "RemoteAPI_DisabledOrExpired",
                        description = "Jadwal Auto Nonaktif via API dimatikan atau sudah habis.",
                        color       = 0xFF8800,
                        scheduleTextOverride = "Remote API OFF"
                    })

                    if (not scheduleActive) and countdownLabel then
                        countdownLabel.Text = "Auto Nonaktif: Jadwal Remote (API) selesai."
                    end
                end

                currentApiInterval = API_IDLE_INTERVAL
                return
            end

            remoteEnabled   = true
            remoteExpireUtc = newExpire
            currentApiInterval = API_ACTIVE_INTERVAL

            local changed = (not prevEnabled)
                         or (not prevExpire)
                         or (math.abs((prevExpire or 0) - newExpire) > 1)

            if changed then
                local remain    = math.max(0, newExpire - utcNow)
                local endWita   = utcToWitaStruct(newExpire)
                local remainStr = formatHMS(remain)

                if not prevEnabled or not prevExpire then
                    remoteStartUtc  = utcNow
                    remoteTotalSec  = remain
                else
                    remoteTotalSec  = math.max(remoteTotalSec, remain)
                end
                _G.__AntiAFK_RemoteTotal = remoteTotalSec

                local desc = string.format(
                    "Jadwal Auto Nonaktif Diubah melalui API.\nSisa waktu: %s (sekitar %02d:%02d WITA).",
                    remainStr,
                    endWita.hour, endWita.min
                )

                sendWebhook("Schedule_Update",{
                    reason      = "Schedule_Changed_API",
                    description = desc,
                    color       = 0x00FFC0,
                    scheduleTextOverride = remainStr
                })

                notify("Smart AntiAFK", "Jadwal Auto Nonaktif Diubah melalui API ("..remainStr..")", 5)
            end

            if not antiEnabled then
                enableAntiAFK()
            end
        end)
    end

    --------- REPORT PLAYERS LOOP ----------
    if reportPlayersEnabled then
        if not reportPlayersInitSent and playSeconds >= 3 then
            reportPlayersInitSent = true
            reportPlayersAcc = 0
            task.spawn(function()
                sendReportPlayers("initial")
            end)
        elseif reportPlayersInitSent and reportPlayersAcc >= REPORT_PLAYERS_INTERVAL then
            reportPlayersAcc = 0
            task.spawn(function()
                sendReportPlayers("interval")
            end)
        end
    end

    --------- UPTIME LABEL UPDATE ----------
    if uptimeUpdateAcc >= 1 then
        uptimeUpdateAcc = 0
        if antiUptimePlay then
            antiUptimePlay.Text = "Uptime Play: " .. formatHMS(playSeconds)
        end
        if antiUptimeAFK then
            antiUptimeAFK.Text = "Uptime AntiAFK: " .. formatHMS(antiAFKSeconds)
        end
    end

    --------- WITA CLOCK + SCHEDULE COUNTDOWN ----------
    if clockAcc >= 1 then
        clockAcc = 0

        local utcNow = getUtcNow()
        local wita   = utcToWitaStruct(utcNow)

        if witaClockLabel then
            witaClockLabel.Text = string.format(
                "Jam WITA sekarang: %02d:%02d:%02d",
                wita.hour, wita.min, wita.sec
            )
        end

        local startH = wita.hour
        local startM = wita.min
        for _, info in ipairs(durationButtons) do
            if info.label and info.hours then
                local endH = (startH + info.hours) % 24
                local endM = startM
                info.label.Text = string.format(
                    "%2d Jam (%s-%s)",
                    info.hours,
                    fmtHM(startH, startM),
                    fmtHM(endH, endM)
                )
            end
        end

        local remoteHandled = false
        if remoteEnabled and remoteExpireUtc then
            local remainRemote = remoteExpireUtc - utcNow
            if remainRemote <= 0 then
                remoteEnabled   = false
                remoteExpireUtc = nil
                remoteTotalSec  = 0
                remoteStartUtc  = nil
                _G.__AntiAFK_RemoteTotal = 0

                if antiEnabled then
                    disableAntiAFK("RemoteAPI_TimeUp")
                end

                if not scheduleActive and countdownLabel then
                    countdownLabel.Text = "Auto Nonaktif: Jadwal Remote (Discord) selesai, AntiAFK dimatikan."
                end
            else
                remoteHandled = true
                if countdownLabel then
                    local endWitaR = utcToWitaStruct(remoteExpireUtc)
                    countdownLabel.Text = string.format(
                        "Auto Nonaktif (Discord API): AntiAFK OFF dalam %s (sekitar %02d:%02d WITA).",
                        formatHMS(remainRemote),
                        endWitaR.hour, endWitaR.min
                    )
                end
            end
        end

        if (not remoteHandled) and scheduleActive and scheduleEndUtc then
            local remain = scheduleEndUtc - utcNow
            if remain <= 0 then
                scheduleActive      = false
                scheduleStartUtc    = nil
                scheduleEndUtc      = nil
                scheduleDurationSec = 0
                _G.__AntiAFK_ScheduleDuration = 0
                if countdownLabel then
                    countdownLabel.Text = "Auto Nonaktif: Jadwal selesai, AntiAFK dimatikan."
                end

                disableAntiAFK("ScheduleTimeUp (Auto Nonaktif)")

                antiEnabled = false
                if antiToggleBtn then
                    antiToggleBtn.BackgroundColor3 = Color3.fromRGB(220,80,80)
                    antiToggleBtn.Text             = "AntiAFK: OFF"
                end
                setStatus("Idle", Color3.fromRGB(90,90,120))

                notify("Smart AntiAFK", "AntiAFK dimatikan oleh jadwal Auto Nonaktif (waktu habis).", 5)
            else
                if countdownLabel then
                    local endWitaS = utcToWitaStruct(scheduleEndUtc)
                    countdownLabel.Text = string.format(
                        "Auto Nonaktif: AntiAFK OFF dalam %s (sekitar %02d:%02d WITA).",
                        formatHMS(remain),
                        endWitaS.hour, endWitaS.min
                    )
                end
            end
        elseif (not remoteHandled) and (not scheduleActive) and (not remoteEnabled) and countdownLabel then
            countdownLabel.Text = "Auto Nonaktif: Tidak ada jadwal aktif."
        end
    end

    --------- PERIODIC STATUS WEBHOOK (RANDOM, RINGAN) ----------
    if not periodicStopped then
        statusWebhookAcc += dt
        if statusWebhookAcc >= statusNextInterval then
            statusWebhookAcc = 0

            if (antiEnabled or scheduleActive or remoteEnabled) and webhookErrorCount < 3 then
                local utcNow = getUtcNow()

                local localTotalDur = _G.__AntiAFK_ScheduleDuration or 0
                local totalText     = localTotalDur > 0 and formatHMS(localTotalDur) or "Tidak ada / 0"

                local localRemainSec = 0
                if scheduleActive and scheduleEndUtc then
                    localRemainSec = math.max(0, scheduleEndUtc - utcNow)
                end
                local localRemainText = (scheduleActive and localRemainSec > 0)
                    and formatHMS(localRemainSec) or "Tidak ada / 0"

                local scheduleDesc
                if scheduleActive and scheduleEndUtc then
                    local endWita = utcToWitaStruct(scheduleEndUtc)
                    scheduleDesc = string.format(
                        "Schedule lokal aktif: AntiAFK akan dimatikan dalam %s (sekitar %02d:%02d WITA).",
                        localRemainText ~= "Tidak ada / 0" and localRemainText or "0",
                        endWita.hour, endWita.min
                    )
                else
                    scheduleDesc = "Schedule lokal tidak aktif."
                end

                local finalTotalText  = totalText
                local finalRemainText = localRemainText

                if remoteEnabled and remoteExpireUtc then
                    local remainRemote      = math.max(0, remoteExpireUtc - utcNow)
                    local remainRemoteText  = formatHMS(remainRemote)
                    local endWitaRemote     = utcToWitaStruct(remoteExpireUtc)
                    local remoteLine = string.format(
                        "Remote API aktif: AntiAFK akan dimatikan dalam %s (sekitar %02d:%02d WITA).",
                        remainRemoteText, endWitaRemote.hour, endWitaRemote.min
                    )
                    scheduleDesc = scheduleDesc .. "\n" .. remoteLine

                    local remoteTotalText
                    if remoteTotalSec and remoteTotalSec > 0 then
                        remoteTotalText = formatHMS(remoteTotalSec)
                    else
                        remoteTotalText = remainRemoteText
                    end

                    finalTotalText  = remoteTotalText
                    finalRemainText = remainRemoteText
                end

                local statusStr = antiEnabled and "ON" or "OFF"
                local modeText = string.format(
                    "AntiAFK=%s | AdminDetect=%s | AutoRejoin=%s | AutoLeave=%s | FriendsDetect=%s | RemoteAPI=%s | Wordban=%s",
                    statusStr,
                    adminDetectEnabled and "ON" or "OFF",
                    autoRejoinOnAdmin and "ON" or "OFF",
                    autoLeaveOnAdmin and "ON" or "OFF",
                    friendsDetectEnabled and "ON" or "OFF",
                    remoteEnabled and "ON" or "OFF",
                    wordbanEnabled and "ON" or "OFF"
                )

                local desc = string.format(
                    "Status periodik.\n- AntiAFK: %s\n- Uptime Play: %s\n- Uptime AntiAFK: %s\n- Auto NonAktif: %s",
                    statusStr,
                    formatHMS(playSeconds),
                    formatHMS(antiAFKSeconds),
                    scheduleDesc
                )

                sendWebhook("Periodic_Status",{
                    reason      = "Periodic_StatusUpdate",
                    description = desc,
                    color       = antiEnabled and 0x00C896 or 0xFFAA00,
                    scheduleTextOverride = string.format("Total: %s | Sisa: %s", finalTotalText, finalRemainText),
                    modeText    = modeText
                })
            end

            pickNextStatusInterval()
        end
    end
end)

------------------- DEFAULT: AUTO ON --------------------
enableAntiAFK()

------------------- TAB CLEANUP REGISTER -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive = false
    periodicStopped = true

    disableAntiAFK("TabCleanup")

    if antiIdleConn then
        pcall(function()
            antiIdleConn:Disconnect()
        end)
        antiIdleConn = nil
    end

    for _, c in ipairs(connections) do
        pcall(function()
            if c and c.Disconnect then
                c:Disconnect()
            end
        end)
    end
end
