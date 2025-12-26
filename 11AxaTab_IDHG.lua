--==========================================================
--  11AxaTab_IDHG.lua
--  TAB 11: "Indo HG"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "idhg"

local Players      = Players      or game:GetService("Players")
local LocalPlayer  = LocalPlayer  or Players.LocalPlayer
local RunService   = RunService   or game:GetService("RunService")
local TweenService = TweenService or game:GetService("TweenService")
local HttpService  = HttpService  or game:GetService("HttpService")
local StarterGui   = StarterGui   or game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService    = UserInputService    or game:GetService("UserInputService")
local VirtualInputManager = VirtualInputManager or game:GetService("VirtualInputManager")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- SPECIAL USERS -------------------
local SPECIAL_USERS = {
    [9154320458] = { username = "@biwwa085",       name = "Bebybolo HG",      discord = "<@1425189351524012092>" },
    [8405726221] = { username = "@yipinsipi",      name = "Yiphin HG",        discord = "<@1400344558059126894>" },
    [7941438813] = { username = "@TripleA_666",    name = "Miaw HG",          discord = "<@1069652543203971174>" },
    [8957393843] = { username = "@AxaXyz999",      name = "AxaXyz999xBBHY",   discord = "<@1403052152691101857>" },
    [7663116646] = { username = "@PIMAAP1",        name = "Pim HG",           discord = "<@759430434391064607>" },
    [9810618823] = { username = "@lonjongbulet05", name = "Avi HG",           discord = "<@556351282789744674>" },
    [9330413171] = { username = "@Exoxyz999",      name = "Exodontia",        discord = "<@1403052152691101857>" },
    [8981188909] = { username = "@DryanBaxia",     name = "Durian HG",        discord = "<@506805856650788874>" },
}

local DEFAULT_OWNER_DISCORD = "<@1403052152691101857>"

------------------- REMOTES -------------------
local RemoteFolder = ReplicatedStorage:FindFirstChild("Events")
    and ReplicatedStorage.Events:FindFirstChild("RemoteEvent")

if not RemoteFolder then
    warn("[15AxaTab_IndoHangout] Folder RemoteEvent tidak ditemukan.")
    return
end

local RodRemoteEvent     = RemoteFolder:FindFirstChild("Rod")
local RodShopRemoteEvent = RemoteFolder:FindFirstChild("RodShop")
    or RemoteFolder:FindFirstChild("RodShopRemote")
    or RemoteFolder:FindFirstChild("RodRemoteShop")

-- SellFish sekarang diambil dari Events.RemoteFunction.SellFish
local SellFishRemoteFunction

-- Folder RemoteFunction
local RemoteFunctionFolder
do
    local ok, res = pcall(function()
        return ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteFunction")
    end)
    if ok then
        RemoteFunctionFolder = res
    else
        warn("[15AxaTab_IndoHangout] Folder RemoteFunction tidak ditemukan (Events.RemoteFunction):", res)
    end
end

local RodShopRemoteFunction, RodIndexRemoteFunction
if RemoteFunctionFolder then
    RodShopRemoteFunction = RemoteFunctionFolder:FindFirstChild("RodShop")
        or RemoteFunctionFolder:FindFirstChild("RodShopRemote")
        or RemoteFunctionFolder:FindFirstChild("RodRemoteShop")

    RodIndexRemoteFunction = RemoteFunctionFolder:FindFirstChild("Index")
    SellFishRemoteFunction = RemoteFunctionFolder:FindFirstChild("SellFish")
end

------------------- UI HELPERS -------------------
local function New(class, props, children)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            o[k] = v
        end
    end
    if children then
        for _, c in ipairs(children) do
            c.Parent = o
        end
    end
    return o
end

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Axa IndoHangout",
            Text     = text or "",
            Duration = dur or 3,
        })
    end)
end

local function makeLabel(parent,name,text,size,pos,props)
    local l = Instance.new("TextLabel")
    l.Name      = name
    l.Size      = size
    l.Position  = pos or UDim2.new()
    l.BackgroundTransparency = 1
    l.Font      = (props and props.Font) or Enum.Font.Gotham
    l.TextSize  = (props and props.TextSize) or 12
    l.TextColor3= (props and props.TextColor3) or Color3.fromRGB(40,40,60)
    l.TextXAlignment = (props and props.XAlign) or Enum.TextXAlignment.Left
    l.TextYAlignment = (props and props.YAlign) or Enum.TextYAlignment.Center
    l.TextWrapped    = (props and props.Wrapped) or false
    l.Text      = text or ""
    l.Parent    = parent
    return l
end

local function makeCard(parent, order)
    local card = New("Frame", {
        Name              = "Card",
        BackgroundColor3  = Color3.fromRGB(236, 238, 248),
        BorderSizePixel   = 0,
        Size              = UDim2.new(1, 0, 0, 80),
        AutomaticSize     = Enum.AutomaticSize.Y,
        LayoutOrder       = order or 10,
        Parent            = parent,
    }, {
        New("UICorner", { CornerRadius = UDim.new(0, 12) }),
        New("UIStroke", {
            Thickness    = 1,
            Color        = Color3.fromRGB(210, 212, 230),
            Transparency = 0.3,
        }),
        New("UIPadding", {
            PaddingTop    = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft   = UDim.new(0, 8),
            PaddingRight  = UDim.new(0, 8),
        }),
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Padding       = UDim.new(0, 4),
        }),
    })
    return card
end

local function makeLittleButton(parent, text, width)
    return New("TextButton", {
        Size              = UDim2.new(0, width or 90, 0, 24),
        BackgroundColor3  = Color3.fromRGB(228, 232, 248),
        BorderSizePixel   = 0,
        AutoButtonColor   = true,
        Font              = Enum.Font.GothamSemibold,
        TextSize          = 12,
        TextColor3        = Color3.fromRGB(40, 44, 70),
        Text              = text,
        Parent            = parent,
    }, {
        New("UICorner", { CornerRadius = UDim.new(0, 8) }),
    })
end

------------------- SOUNDS (Stuffs.Sounds) -------------------
local SoundsFolder
do
    pcall(function()
        local stuffs = ReplicatedStorage:FindFirstChild("Stuffs")
        if stuffs and stuffs:FindFirstChild("Sounds") then
            SoundsFolder = stuffs.Sounds
        end
    end)
end

local function playUISound(soundName)
    if not SoundsFolder or not soundName then return end
    local s = SoundsFolder:FindFirstChild(soundName)
    if s and s:IsA("Sound") then
        s:Play()
    end
end

------------------- STATE: LOCAL AUTO FISH / SELL / STATS -------------------
local autoFishing        = false
local autoSellMode       = "Disable"

local castsCount         = 0
local caughtCount        = 0
local lastCatchName      = "-"

local fishCountsSnapshot = nil
local catchLog           = {}
local lastCatchSentIndexForTimer = 0

local reelEventConn      = nil
local reelBarConn        = nil
local isCasting          = false

local statsCastLabel, statsCaughtLabel, statsLastLabel, statsSellLabel, statsStatusLabel

local reelProgress       = 0
local reelProgressFill   = nil
local reelProgressLabel  = nil
local reelingActive      = false

-- SPEED ROD STATE (hanya untuk hitung durasi reeling, bukan speedup)
local reelStartTick           = nil
local pendingRodSpeedSeconds  = nil
local pendingRodSpeedLabel    = nil
local lastRodSpeedSeconds     = nil
local lastRodSpeedLabel       = nil

local alive              = true

local filterOnlyMe       = false
local filterMode         = 1

local FriendStates       = {}

local sendListCaughtEnabled = false

local sessionFishingStart   = nil
local localFirstCatchTime   = nil

------------------- ROD SELECTION (SCAN BACKPACK, TANPA HOTKEY) -------------------
local ROD_PRIORITY = {
    "Earth Rod",
    "Reindeer Rod",
    "Wave Rod",
    "Piranha Rod",
    "VIP Rod",
    "Thermo Rod",
}

local chosenRodName = nil
local findRodTool   -- forward declaration

local function scanBestRodName()
    local pl = LocalPlayer
    if not pl then return nil end

    local char     = pl.Character
    local backpack = pl:FindFirstChild("Backpack")

    local function findInContainer(container, rodName)
        if not container then return nil end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") and inst.Name == rodName then
                return inst
            end
        end
        return nil
    end

    for _, rodName in ipairs(ROD_PRIORITY) do
        local tool = findInContainer(char, rodName) or findInContainer(backpack, rodName)
        if tool then
            chosenRodName = rodName
            return rodName
        end
    end

    chosenRodName = nil
    return nil
end

local function getEquippedRodFromCharacter(char)
    if not char then return nil end
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("Tool") then
            local nameLower = string.lower(inst.Name or "")
            if nameLower:find("rod", 1, true) then
                return inst
            end
        end
    end
    return nil
end

local function ensureRodEquipped()
    local pl = LocalPlayer
    if not pl then return nil end

    local char = pl.Character
    if not char then return nil end

    -- Jika player sudah memegang rod sendiri, pakai itu dan jadikan default baru
    local equippedRod = getEquippedRodFromCharacter(char)
    if equippedRod then
        chosenRodName = equippedRod.Name
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rod = equippedRod or (findRodTool and findRodTool())
    if not rod then
        return nil
    end

    if rod.Parent ~= char then
        if humanoid then
            pcall(function()
                humanoid:EquipTool(rod)
            end)
        else
            rod.Parent = char
        end
    end

    return rod
end

-- Equip rod berdasarkan chosenRodName / prioritas, TANPA hotkey
local function equipChosenRod()
    local pl = LocalPlayer
    if not pl then return nil end

    local char     = pl.Character
    local backpack = pl:FindFirstChild("Backpack")
    if not char then return nil end

    local humanoid = char:FindFirstChildOfClass("Humanoid")

    local rod

    if chosenRodName then
        local function findInContainer(container)
            if not container then return nil end
            for _, inst in ipairs(container:GetChildren()) do
                if inst:IsA("Tool") and inst.Name == chosenRodName then
                    return inst
                end
            end
            return nil
        end

        rod = findInContainer(char) or findInContainer(backpack)
    end

    if not rod then
        -- fallback ke rod yang sudah dipegang
        rod = getEquippedRodFromCharacter(char)
    end

    if not rod then
        -- fallback ke prioritas (Wave > Piranha > VIP > Thermo > rod lain yang mengandung "rod")
        rod = findRodTool and findRodTool()
    end

    if not rod then
        return nil
    end

    if humanoid and rod.Parent ~= char then
        pcall(function()
            humanoid:EquipTool(rod)
        end)
    else
        rod.Parent = char
    end

    chosenRodName = rod.Name
    return rod
end

-- Scan awal, pilih rod terbaik Wave > Piranha > VIP > Thermo jika ada
scanBestRodName()

------------------- FISH DETECTION (BACKPACK) -------------------
local FISH_KEYWORDS = {
    "ikan", "fish", "mirethos", "kaelvorn", "kraken",
    "shark", "whale", "ray", "eel", "salmon", "tuna", "cod",
    "marlin", "dolphin", "gurame", "lele", "koi"
}

local function isFishName(name)
    local lower = string.lower(tostring(name or ""))
    for _, kw in ipairs(FISH_KEYWORDS) do
        if lower:find(kw, 1, true) then
            return true
        end
    end
    return false
end

local function scanFishCounts(pl)
    local counts = {}
    if not pl then return counts end

    local function scan(container)
        if not container then return end
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("Tool") and isFishName(c.Name) then
                counts[c.Name] = (counts[c.Name] or 0) + 1
            end
        end
    end

    scan(pl:FindFirstChild("Backpack"))
    scan(pl.Character)

    return counts
end

local function copyFishCounts(src)
    local dst = {}
    for name, cnt in pairs(src) do
        dst[name] = cnt
    end
    return dst
end

local function syncLocalSnapshotToCurrent()
    local nowCounts = scanFishCounts(LocalPlayer)

    if not fishCountsSnapshot then
        fishCountsSnapshot = copyFishCounts(nowCounts)
        return
    end

    for name, oldCnt in pairs(fishCountsSnapshot) do
        local newCnt = nowCounts[name] or 0
        if newCnt < oldCnt then
            fishCountsSnapshot[name] = newCnt
        end
    end

    for name, newCnt in pairs(nowCounts) do
        if fishCountsSnapshot[name] == nil then
            fishCountsSnapshot[name] = newCnt
        end
    end
end

------------------- WITA TIME HELPERS -------------------
local function getUtcNow()
    local ok, ts = pcall(function()
        return DateTime.now().UnixTimestamp
    end)
    if ok and ts then
        return ts
    end

    local ok2, ts2 = pcall(function()
        return os.time(os.date("!*t"))
    end)
    if ok2 and ts2 then
        return ts2
    end

    return os.time()
end

local function utcToWitaStruct(utcUnix)
    local t = os.date("!*t", (utcUnix or 0) + 8 * 3600)
    return {
        year  = t.year,
        month = t.month,
        day   = t.day,
        hour  = t.hour,
        min   = t.min,
        sec   = t.sec,
    }
end

local function formatWitaTimestamp(prefix)
    local utcNow = getUtcNow()
    local wita   = utcToWitaStruct(utcNow)
    local base = string.format(
        "%04d-%02d-%02d %02d:%02d:%02d WITA",
        wita.year, wita.month, wita.day,
        wita.hour, wita.min, wita.sec
    )
    if prefix and prefix ~= "" then
        return prefix .. " • " .. base
    end
    return base
end

------------------- DISCORD WEBHOOK (1-4 + 5 ROD SHOP) -------------------
local WEBHOOK_URL_1 = "https://discord.com/api/webhooks/1450060283937816708/bmOApJlaMKnzFk7TF30Kl5MUvc85bvrUYPZwWB3Bf5u4s-XBWLaDvVUUhiudcxlqLrk5"
local WEBHOOK_URL_2 = "https://discord.com/api/webhooks/1445067682972962927/nZTW2iRFfbzBqKLiu_niW_KQWX-nrd4QX8GpE2dtGTQHH03i7_Mm9iF5Q1wEJagpoKDl"
local WEBHOOK_URL_3 = "https://discord.com/api/webhooks/1445325522295853231/UjT6nOBD6IfvNnsRM4VgLCwyYDeENDELA2oCdoHZYablVsOO53Tk_UBnYFKOQyUtCL4v"
local WEBHOOK_URL_4 = ""
local WEBHOOK_URL_5 = "https://discord.com/api/webhooks/1448926413272125470/rAX-rVkYKyxeIa_-msqcY2DsVu6ZBqmKzrNXhov-nILq4tdMY88WK1G0ETYtuLt2j1L6"

local webhookEnabled1 = false
local webhookEnabled2 = false
local webhookEnabled3 = false
local webhookEnabled4 = false
local webhookEnabled5 = true -- default true

local BOT_USERNAME   = "Caught Notifier New"
local BOT_AVATAR_URL = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png"
local MAX_DESC       = 3600

-- Formatter angka bertitik
local function formatWithDots(amount)
    amount = tonumber(amount)
    if not amount then return "-" end
    amount = math.floor(amount)

    local s = tostring(amount)
    local rev = s:reverse()
    rev = rev:gsub("(%d%d%d)", "%1.")
    local res = rev:reverse()
    if res:sub(1,1) == "." then
        res = res:sub(2)
    end
    return res
end

local function formatRupiah(amount)
    local s = formatWithDots(amount)
    if s == "-" then
        return s
    end
    return "Rp. " .. s
end

local function formatPriceStringAsDots(str)
    str = tostring(str or "")
    if str == "" then return str end

    local firstDigit, lastDigit
    for i = 1, #str do
        local c = str:sub(i,i)
        if c:match("%d") then
            firstDigit = i
            break
        end
    end
    if not firstDigit then
        return str
    end
    for i = #str, 1, -1 do
        local c = str:sub(i,i)
        if c:match("%d") then
            lastDigit = i
            break
        end
    end
    if not lastDigit or lastDigit < firstDigit then
        return str
    end

    local digitSpan = str:sub(firstDigit, lastDigit)
    if digitSpan:find("%.") then
        return str
    end

    local prefix = str:sub(1, firstDigit-1)
    local digits = digitSpan:gsub("[^%d]", "")
    local suffix = str:sub(lastDigit+1)

    if digits == "" then
        return str
    end

    local formattedDigits = formatWithDots(tonumber(digits))
    return prefix .. formattedDigits .. suffix
end

local function getRequestFunction()
    local g = getgenv and getgenv() or _G
    local req =
        (syn and syn.request)
        or (http and http.request)
        or (fluxus and fluxus.request)
        or (krnl and krnl.request)
        or (g and (g.request or g.http_request))
        or http_request
        or request

    if type(req) ~= "function" then
        return nil
    end
    return req
end

local function postDiscord(payload, targetType)
    local okEncode, body = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        warn("[IndoHangout] Gagal JSONEncode payload webhook:", body)
        return false, "JSONEncode error"
    end

    local req = getRequestFunction()

    local function sendOne(url)
        if not url or url == "" then
            return false, "URL kosong"
        end

        if req then
            local ok, res = pcall(function()
                return req({
                    Url     = url,
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = body,
                })
            end)

            if ok then
                local status = res and (res.StatusCode or res.Status) or nil
                if status == nil or status == 200 or status == 204 then
                    return true
                else
                    return false, "HTTP status " .. tostring(status)
                end
            end
        end

        local ok2, err2 = pcall(function()
            return HttpService:PostAsync(
                url,
                body,
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end)

        if not ok2 then
            return false, "HttpService PostAsync error: " .. tostring(err2)
        end

        return true
    end

    local urls = {}
    if targetType == "selected" then
        if webhookEnabled3 and WEBHOOK_URL_3 ~= "" then
            table.insert(urls, WEBHOOK_URL_3)
        end
    else
        if webhookEnabled1 and WEBHOOK_URL_1 ~= "" then
            table.insert(urls, WEBHOOK_URL_1)
        end
        if webhookEnabled2 and WEBHOOK_URL_2 ~= "" then
            table.insert(urls, WEBHOOK_URL_2)
        end
        if webhookEnabled4 and WEBHOOK_URL_4 ~= "" then
            table.insert(urls, WEBHOOK_URL_4)
        end
    end

    if #urls == 0 then
        return false, "Tidak ada webhook yang aktif."
    end

    local allOk    = true
    local firstErr = nil

    for _, url in ipairs(urls) do
        local ok, err = sendOne(url)
        if not ok then
            allOk    = false
            firstErr = firstErr or err
        end
    end

    return allOk, firstErr
end

------------------- LOW LEVEL HTTP UNTUK WEBHOOK 5 -------------------
local function httpRequestDiscord(url, payload)
    if not url or url == "" then return false, "URL kosong" end

    local encoded
    local okEncode, errEncode = pcall(function()
        encoded = HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "JSONEncode error: " .. tostring(errEncode)
    end

    local req =
        (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
        or (krnl and krnl.request)

    if req then
        local ok, res = pcall(function()
            return req({
                Url     = url,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = encoded,
            })
        end)
        if not ok then return false, "Executor request error: " .. tostring(res) end
        local status = res and (res.StatusCode or res.Status) or nil
        if status and status ~= 200 and status ~= 204 then
            return false, "HTTP status " .. tostring(status)
        end
        return true
    end

    local ok2, err2 = pcall(function()
        return HttpService:PostAsync(
            url,
            encoded,
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)
    if not ok2 then return false, "HttpService PostAsync error: " .. tostring(err2) end
    return true
end

local function postDiscordFavorite(payload)
    payload.username   = payload.username   or "Fish Fav/Rod Notifier"
    payload.avatar_url = payload.avatar_url or BOT_AVATAR_URL

    if not webhookEnabled5 or WEBHOOK_URL_5 == "" then
        return false, "Webhook 5 nonaktif."
    end

    local ok, err = httpRequestDiscord(WEBHOOK_URL_5, payload)
    if not ok then
        warn("[IndoHangout] Webhook Favorite Fish/Rod gagal:", err)
    end
    return ok, err
end

----------------------------------------------------------------
-- ROD SPEED CLASSIFIER (untuk teks "Speed Rod" di webhook)
----------------------------------------------------------------
local function classifyRodSpeed(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return "Unknown"
    end
    if seconds <= 4.00 then
        return "Very Fast"
    elseif seconds <= 9.00 then
        return "Fast"
    else
        return "Slow"
    end
end

------------------- FAVORITE FISH MODULE -------------------
local FavoriteFish = (function()
    local F = {}

    local FAV_FISH_NAME = {
        { Name = "Disable"        },
        { Name = "ikan lumba pink"},
        { Name = "ikan kraken"    },
        { Name = "ikan kuda"      },
        { Name = "ikan lele"      },
        { Name = "ikan angler"    },
        { Name = "ikan marlin"    },
        { Name = "ikan hiu"       },
        { Name = "ikan salmon"    },
        { Name = "ikan tuna"      },
        { Name = "ikan sendarat"  },
        { Name = "ikan lemadang"  },
    }

    local range0_300     = false
    local range301_450   = false
    local range451_1000  = true   -- default ON
    local autoFavEnabled = true   -- default ON

    local btnRange0_300
    local btnRange301_450
    local btnRange451_1000
    local btnAutoFav
    local btnFavAll
    local btnUnFavAll

    local favFishButton
    local unfavFishButton
    local favFishSelectedIndex   = 1
    local unfavFishSelectedIndex = 1

    local favDropdownFrame
    local unfavDropdownFrame

    local BackpackRemoteFunction
    if RemoteFunctionFolder then
        BackpackRemoteFunction = RemoteFunctionFolder:WaitForChild("Backpack")
    end

    local function parseWeightFromName(name)
        name = tostring(name or "")
        local lower = string.lower(name)
        local numStr = lower:match("%(([%d%.]+)%s*kg%)")
        if not numStr then
            numStr = lower:match("(%d+)%s*kg")
        end
        local w = tonumber(numStr)
        return w
    end

    local function extractBaseFishName(name)
        name = tostring(name or "")
        local base = name
        base = base:gsub("%s*%(%s*[Ff][Aa][Vv][Oo][Rr][Ii][Tt][Ee]%s*%)", "")
        base = base:gsub("%s*%(%s*[%d%.]+%s*kg%s*%)", "")
        base = base:gsub("%s*%(%s*kg%s*%)", "")
        base = base:gsub("%s+$", "")
        return base
    end

    local function normalizeFishTypeName(name)
        name = tostring(name or "")
        name = name:gsub("^%s+",""):gsub("%s+$","")
        return string.lower(name)
    end

    local function getFishRarityFromTool(tool)
        if not tool or not tool:IsA("Tool") then
            return "Unknown"
        end
        local lower = string.lower(tool.Name or "")
        if lower:find("mythic", 1, true) or lower:find("mythical", 1, true) then
            return "Mythic"
        elseif lower:find("legend", 1, true) then
            return "Legendary"
        elseif lower:find("epic", 1, true) then
            return "Epic"
        elseif lower:find("rare", 1, true) then
            return "Rare"
        elseif lower:find("uncommon", 1, true) then
            return "Uncommon"
        end
        return "Common"
    end

    local function isToolFavorite(tool)
        if not tool or not tool:IsA("Tool") then
            return false
        end
        local lower = string.lower(tool.Name or "")
        return lower:find("favorite", 1, true) ~= nil
    end

    local function isWeightInActiveRanges(w)
        if not w then return false end
        if range0_300 and w >= 0 and w <= 300 then
            return true
        end
        if range301_450 and w >= 301 and w <= 450 then
            return true
        end
        if range451_1000 and w >= 451 and w <= 1000 then
            return true
        end
        return false
    end

    local function anyRangeSelected()
        return range0_300 or range301_450 or range451_1000
    end

    local function getActiveRangeLabel()
        local parts = {}
        if range0_300 then
            table.insert(parts, "0-300 Kg")
        end
        if range301_450 then
            table.insert(parts, "301-450 Kg")
        end
        if range451_1000 then
            table.insert(parts, "451-1000 Kg")
        end
        if #parts == 0 then
            return "semua berat (tidak ada filter range)"
        end
        return table.concat(parts, ", ")
    end

    local function isWeightPassForNameFeature(w)
        if not anyRangeSelected() then
            return true
        end
        if w == nil then
            return true
        end
        return isWeightInActiveRanges(w)
    end

    local function getRangeLabelForWeight(w)
        if not w then return "-" end
        if w >= 0 and w <= 300 then
            return "0-300 Kg"
        elseif w >= 301 and w <= 450 then
            return "301-450 Kg"
        elseif w >= 451 and w <= 1000 then
            return "451-1000 Kg"
        else
            return ">1000 Kg"
        end
    end

    local function collectFishToolsByName(baseName)
        local pl = LocalPlayer
        if not pl then return {} end

        baseName = tostring(baseName or "")
        local targetLower = normalizeFishTypeName(baseName)
        if targetLower == "" or targetLower == "disable" then
            return {}
        end

        local result = {}
        local containers = { pl.Character, pl:FindFirstChild("Backpack") }

        for _, container in ipairs(containers) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and isFishName(tool.Name) then
                        local base = extractBaseFishName(tool.Name)
                        local baseLower = normalizeFishTypeName(base)

                        if baseLower ~= "" then
                            if baseLower == targetLower
                                or baseLower:find(targetLower, 1, true)
                                or targetLower:find(baseLower, 1, true)
                            then
                                table.insert(result, tool)
                            end
                        end
                    end
                end
            end
        end

        return result
    end

    local function toggleFavoriteTool(tool)
        if not BackpackRemoteFunction or not tool then
            return false
        end
        local args = {
            [1] = "ChangeFavoriteStatus",
            [2] = tool,
        }
        local ok, res = pcall(function()
            return BackpackRemoteFunction:InvokeServer(unpack(args))
        end)
        if not ok then
            warn("[IndoHangout] ChangeFavoriteStatus gagal: " .. tostring(res))
            return false
        end
        if res == "Added" or res == "Removed" then
            playUISound("UI - Success")
        end
        return true
    end

    local function sendNewFavoriteFishWebhook(tool, sourceText)
        if not tool then return end

        local pl = LocalPlayer

        local weight  = parseWeightFromName(tool.Name)
        local rarity  = getFishRarityFromTool(tool)
        local baseName = extractBaseFishName(tool.Name)

        local weightText = weight and (tostring(weight) .. " Kg") or "-"
        local rangeText  = getRangeLabelForWeight(weight)

        local desc = string.format(
            "**%s (@%s)**\nFish: **%s**\nWeight: **%s**\nRarity: **%s**\nRange: %s\nSource: %s",
            pl.DisplayName or pl.Name,
            pl.Name,
            baseName,
            weightText,
            rarity or "-",
            rangeText,
            sourceText or "AutoFav"
        )

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = BOT_AVATAR_URL,
            content    = DEFAULT_OWNER_DISCORD,
            embeds = {{
                title       = "⭐ New Favorite Fish",
                description = desc,
                color       = 0xFFD54F,
                footer      = { text = formatWitaTimestamp("IndoHangout Favorite Fish") },
            }}
        }

        postDiscordFavorite(payload)
    end

    local function sendMassFavUnfavWebhook(opLabel, baseName, names, totalCount)
        if not names or totalCount <= 0 then return end

        local pl = LocalPlayer
        local lines = {}
        for i, n in ipairs(names) do
            lines[#lines+1] = string.format("%d. %s", i, n)
        end

        local listText = table.concat(lines, "\n")
        if #listText > (MAX_DESC - 200) then
            listText = listText:sub(1, MAX_DESC - 203) .. "..."
        end

        local desc = string.format(
            "**%s (@%s)**\nAction: %s\nTarget: %s\nTotal Ikan: %d\nRange aktif: %s\n\n%s",
            pl.DisplayName or pl.Name,
            pl.Name,
            opLabel,
            baseName or "-",
            totalCount,
            getActiveRangeLabel(),
            listText
        )

        local isUnfav = string.find(string.lower(opLabel), "unfav", 1, true) ~= nil

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = BOT_AVATAR_URL,
            content    = DEFAULT_OWNER_DISCORD,
            embeds = {{
                title       = isUnfav and "🧹 Favorite Bulk - UnFav" or "⭐ Favorite Bulk - Fav",
                description = desc,
                color       = isUnfav and 0xFF7043 or 0xFFD54F,
                footer      = { text = formatWitaTimestamp("IndoHangout Favorite Fish") },
            }}
        }

        postDiscordFavorite(payload)
    end

    local function shouldAutoFavorite(tool)
        if not autoFavEnabled then return false end
        if not tool or not tool:IsA("Tool") then return false end
        if not isFishName(tool.Name) then return false end
        if isToolFavorite(tool) then return false end

        local w = parseWeightFromName(tool.Name)
        if not isWeightInActiveRanges(w) then
            return false
        end
        return true
    end

    local function autoFavoriteTool(tool, src)
        if shouldAutoFavorite(tool) then
            local ok = toggleFavoriteTool(tool)
            if ok then
                sendNewFavoriteFishWebhook(tool, src or "AutoFav")
                local name = tostring(tool.Name or "?")
                notify("IndoHangout", "[AutoFav] " .. name .. " -> Favorite", 2)
                return true
            end
        end
        return false
    end

    local function autoFavoriteByName(fishName, maxCount)
        if not autoFavEnabled then return end
        fishName = tostring(fishName or "")
        if fishName == "" then return end

        maxCount = tonumber(maxCount) or 1
        if maxCount <= 0 then return end

        local pl = LocalPlayer
        if not pl then return end

        local remaining = maxCount
        local containers = { pl.Character, pl:FindFirstChild("Backpack") }

        for _, container in ipairs(containers) do
            if container and remaining > 0 then
                for _, tool in ipairs(container:GetChildren()) do
                    if remaining <= 0 then
                        break
                    end
                    if tool:IsA("Tool") and tool.Name == fishName then
                        local didFav = autoFavoriteTool(tool, "AutoFav Catch")
                        if didFav then
                            remaining -= 1
                        end
                    end
                end
            end
            if remaining <= 0 then
                break
            end
        end
    end

    function F.OnNewCatchByName(fishName, count)
        local n = tonumber(count) or 1
        if n <= 0 then return end
        autoFavoriteByName(fishName, n)
    end

    local function favoriteAllInRanges()
        local pl = LocalPlayer
        if not pl then return end

        local containers = { pl.Character, pl:FindFirstChild("Backpack") }
        local total = 0
        local names = {}

        for _, container in ipairs(containers) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and isFishName(tool.Name) and not isToolFavorite(tool) then
                        local w = parseWeightFromName(tool.Name)
                        if isWeightInActiveRanges(w) then
                            local ok = toggleFavoriteTool(tool)
                            if ok then
                                total += 1
                                local name = tostring(tool.Name or "?")
                                table.insert(names, name)
                                sendNewFavoriteFishWebhook(tool, "Fav All")
                                notify("IndoHangout", "[Fav All] " .. name .. " -> Favorite", 2)
                            end
                        end
                    end
                end
            end
        end

        if total > 0 then
            local listText = table.concat(names, ", ")
            if #listText > 150 then
                listText = listText:sub(1, 147) .. "..."
            end
            notify("IndoHangout", string.format("Fav All selesai: %d ikan di-Favorite.\n%s", total, listText), 5)
        else
            local info = anyRangeSelected()
                and ("range aktif (" .. getActiveRangeLabel() .. ")")
                or "Backpack/Character"
            notify(
                "IndoHangout",
                "Fav All selesai: tidak ada ikan dalam " .. info .. " yang bisa di-Favorite.",
                4
            )
        end
    end

    local function unFavoriteAllInRanges()
        local pl = LocalPlayer
        if not pl then return end

        local containers = { pl.Character, pl:FindFirstChild("Backpack") }
        local total = 0
        local names = {}

        for _, container in ipairs(containers) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and isFishName(tool.Name) and isToolFavorite(tool) then
                        local w = parseWeightFromName(tool.Name)
                        if isWeightInActiveRanges(w) then
                            local ok = toggleFavoriteTool(tool)
                            if ok then
                                total += 1
                                local name = tostring(tool.Name or "?")
                                table.insert(names, name)
                                notify("IndoHangout", "[UnFav All] " .. name .. " -> Unfavorite", 2)
                            end
                        end
                    end
                end
            end
        end

        if total > 0 then
            local listText = table.concat(names, ", ")
            if #listText > 150 then
                listText = listText:sub(1, 147) .. "..."
            end
            notify("IndoHangout", string.format("UnFav All selesai: %d ikan di-Unfavorite.\n%s", total, listText), 5)
            sendMassFavUnfavWebhook("UnFav All (Range)", "Semua Ikan", names, total)
        else
            local info = anyRangeSelected()
                and ("range aktif (" .. getActiveRangeLabel() .. ")")
                or "Backpack/Character"
            notify(
                "IndoHangout",
                "UnFav All selesai: tidak ada ikan Favorite dalam " .. info .. ".",
                4
            )
        end
    end

    local function favoriteAllByFishName(baseName)
        baseName = tostring(baseName or "")
        if baseName == "" then
            notify("IndoHangout", "Fav All (Fish): Nama ikan kosong.", 3)
            return
        end

        if normalizeFishTypeName(baseName) == "disable" then
            notify("IndoHangout", "Fav All (Fish): Mode Disable, tidak ada aksi.", 3)
            return
        end

        local pl = LocalPlayer
        if not pl then return end

        local anyRange = anyRangeSelected()
        local tools    = collectFishToolsByName(baseName)

        local total       = 0
        local totalByName = 0
        local names       = {}

        for _, tool in ipairs(tools) do
            if not isToolFavorite(tool) then
                totalByName += 1
                local w = parseWeightFromName(tool.Name)
                if isWeightPassForNameFeature(w) then
                    local ok = toggleFavoriteTool(tool)
                    if ok then
                        total += 1
                        local name = tostring(tool.Name or "?")
                        table.insert(names, name)
                        sendNewFavoriteFishWebhook(tool, "Fav All (Fish)")
                        notify("IndoHangout", "[Fav All (Fish)] " .. name .. " -> Favorite", 2)
                    end
                end
            end
        end

        if total > 0 then
            local listText = table.concat(names, ", ")
            if #listText > 150 then
                listText = listText:sub(1, 147) .. "..."
            end

            local rangeInfo = anyRange
                and (" (sesuai range aktif: " .. getActiveRangeLabel() .. ")")
                or " (tanpa filter range)"
            notify(
                "IndoHangout",
                string.format(
                    "Fav All (Fish: %s)%s selesai: %d ikan di-Favorite.\n%s",
                    baseName,
                    rangeInfo,
                    total,
                    listText
                ),
                5
            )

            sendMassFavUnfavWebhook("Fav All (Fish)", baseName, names, total)
        else
            if totalByName > 0 and anyRange then
                notify(
                    "IndoHangout",
                    string.format(
                        "Fav All (Fish: %s) selesai: ada %d ikan dengan nama tersebut, " ..
                        "namun tidak ada yang masuk range checklist aktif (%s). " ..
                        "Coba sesuaikan lagi checkbox range beratnya.",
                        baseName,
                        totalByName,
                        getActiveRangeLabel()
                    ),
                    5
                )
            else
                local suffix
                if anyRange then
                    suffix = "dalam range aktif (" .. getActiveRangeLabel() .. ")"
                else
                    suffix = "dengan nama tersebut di Backpack/Character"
                end
                notify(
                    "IndoHangout",
                    string.format(
                        "Fav All (Fish: %s) selesai: tidak ada ikan yang bisa di-Favorite %s.",
                        baseName,
                        suffix
                    ),
                    4
                )
            end
        end
    end

    local function unFavoriteAllByFishName(baseName)
        baseName = tostring(baseName or "")
        if baseName == "" then
            notify("IndoHangout", "UnFav All (Fish): Nama ikan kosong.", 3)
            return
        end

        if normalizeFishTypeName(baseName) == "disable" then
            notify("IndoHangout", "UnFav All (Fish): Mode Disable, tidak ada aksi.", 3)
            return
        end

        local pl = LocalPlayer
        if not pl then return end

        local anyRange = anyRangeSelected()
        local tools    = collectFishToolsByName(baseName)

        local total       = 0
        local totalByName = 0
        local names       = {}

        for _, tool in ipairs(tools) do
            if isToolFavorite(tool) then
                totalByName += 1
                local w = parseWeightFromName(tool.Name)
                if isWeightPassForNameFeature(w) then
                    local ok = toggleFavoriteTool(tool)
                    if ok then
                        total += 1
                        local name = tostring(tool.Name or "?")
                        table.insert(names, name)
                        notify("IndoHangout", "[UnFav All (Fish)] " .. name .. " -> Unfavorite", 2)
                    end
                end
            end
        end

        if total > 0 then
            local listText = table.concat(names, ", ")
            if #listText > 150 then
                listText = listText:sub(1, 147) .. "..."
            end

            local rangeInfo = anyRange
                and (" (sesuai range aktif: " .. getActiveRangeLabel() .. ")")
                or " (tanpa filter range)"
            notify(
                "IndoHangout",
                string.format(
                    "UnFav All (Fish: %s)%s selesai: %d ikan di-Unfavorite.\n%s",
                    baseName,
                    rangeInfo,
                    total,
                    listText
                ),
                5
            )

            sendMassFavUnfavWebhook("UnFav All (Fish)", baseName, names, total)
        else
            if totalByName > 0 and anyRange then
                notify(
                    "IndoHangout",
                    string.format(
                        "UnFav All (Fish: %s) selesai: ada %d ikan Favorite dengan nama tersebut, " ..
                        "namun tidak ada yang masuk range checklist aktif (%s). " ..
                        "Coba sesuaikan lagi checkbox range beratnya.",
                        baseName,
                        totalByName,
                        getActiveRangeLabel()
                    ),
                    5
                )
            else
                local suffix
                if anyRange then
                    suffix = "dalam range aktif (" .. getActiveRangeLabel() .. ")"
                else
                    suffix = "dengan nama tersebut di Backpack/Character"
                end
                notify(
                    "IndoHangout",
                    string.format(
                        "UnFav All (Fish: %s) selesai: tidak ada ikan Favorite %s.",
                        baseName,
                        suffix
                    ),
                    4
                )
            end
        end
    end

    local function updateButtons()
        if btnRange0_300 then
            if range0_300 then
                btnRange0_300.Text = "0-300 Kg: ON"
                btnRange0_300.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
                btnRange0_300.TextColor3       = Color3.fromRGB(255,255,255)
            else
                btnRange0_300.Text = "0-300 Kg: OFF"
                btnRange0_300.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
                btnRange0_300.TextColor3       = Color3.fromRGB(40,44,70)
            end
        end

        if btnRange301_450 then
            if range301_450 then
                btnRange301_450.Text = "301-450 Kg: ON"
                btnRange301_450.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
                btnRange301_450.TextColor3       = Color3.fromRGB(255,255,255)
            else
                btnRange301_450.Text = "301-450 Kg: OFF"
                btnRange301_450.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
                btnRange301_450.TextColor3       = Color3.fromRGB(40,44,70)
            end
        end

        if btnRange451_1000 then
            if range451_1000 then
                btnRange451_1000.Text = "451-1000 Kg: ON"
                btnRange451_1000.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
                btnRange451_1000.TextColor3       = Color3.fromRGB(255,255,255)
            else
                btnRange451_1000.Text = "451-1000 Kg: OFF"
                btnRange451_1000.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
                btnRange451_1000.TextColor3       = Color3.fromRGB(40,44,70)
            end
        end

        if btnAutoFav then
            if autoFavEnabled then
                btnAutoFav.Text = "AutoFav: ON"
                btnAutoFav.BackgroundColor3 = Color3.fromRGB(80, 160, 96)
                btnAutoFav.TextColor3       = Color3.fromRGB(255,255,255)
            else
                btnAutoFav.Text = "AutoFav: OFF"
                btnAutoFav.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
                btnAutoFav.TextColor3       = Color3.fromRGB(40,44,70)
            end
        end

        if btnFavAll then
            btnFavAll.Text = "Fav All (Once)"
        end

        if btnUnFavAll then
            btnUnFavAll.Text = "UnFav All (Once)"
        end

        local function styleDropdownButton(btn, labelPrefix, idx)
            if not btn then return end
            local entry = FAV_FISH_NAME[idx] or FAV_FISH_NAME[1]
            local name  = entry.Name or "Disable"
            btn.Text = labelPrefix .. ": " .. name

            if normalizeFishTypeName(name) == "disable" then
                btn.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
                btn.TextColor3       = Color3.fromRGB(40,44,70)
            else
                btn.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
                btn.TextColor3       = Color3.fromRGB(255,255,255)
            end
        end

        styleDropdownButton(favFishButton,  "Fav All (Fish)",   favFishSelectedIndex)
        styleDropdownButton(unfavFishButton,"UnFav All (Fish)", unfavFishSelectedIndex)
    end

    function F.CreateFavoriteCard(parent)
        if not parent then return end

        local favCard = makeCard(parent, 3)

        makeLabel(
            favCard,"FavTitle","Favorite Fish — Indo HG",
            UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),
            { Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Color3.fromRGB(35,38,70), XAlign=Enum.TextXAlignment.Left }
        )

        -- DESKRIPSI FAVORITE (AUTO HEIGHT)
        local favDescLabel = makeLabel(
            favCard,"FavDesc",
            "Auto favorite ikan baru berdasarkan range berat.",
            UDim2.new(1,0,0,0),UDim2.new(0,0,0,18),
            { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(92,96,124),
              XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
        )
        favDescLabel.AutomaticSize = Enum.AutomaticSize.Y

        local scroll = New("ScrollingFrame", {
            Name = "FavScroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1,0,0,90),
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Parent = favCard,
        }, {})

        local grid = New("UIGridLayout", {
            CellSize      = UDim2.new(0.5, -4, 0, 24),
            CellPadding   = UDim2.new(0,4,0,4),
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder     = Enum.SortOrder.LayoutOrder,
        })
        grid.Parent = scroll

        btnRange0_300 = makeLittleButton(scroll, "0-300 Kg: OFF", 0)
        btnRange0_300.Size = UDim2.new(0.5, -4, 0, 24)
        btnRange0_300.MouseButton1Click:Connect(function()
            range0_300 = not range0_300
            updateButtons()
        end)

        btnRange301_450 = makeLittleButton(scroll, "301-450 Kg: OFF", 0)
        btnRange301_450.Size = UDim2.new(0.5, -4, 0, 24)
        btnRange301_450.MouseButton1Click:Connect(function()
            range301_450 = not range301_450
            updateButtons()
        end)

        btnRange451_1000 = makeLittleButton(scroll, "451-1000 Kg: ON", 0)
        btnRange451_1000.Size = UDim2.new(0.5, -4, 0, 24)
        btnRange451_1000.MouseButton1Click:Connect(function()
            range451_1000 = not range451_1000
            updateButtons()
        end)

        btnAutoFav = makeLittleButton(scroll, "AutoFav: ON", 0)
        btnAutoFav.Size = UDim2.new(0.5, -4, 0, 24)
        btnAutoFav.MouseButton1Click:Connect(function()
            autoFavEnabled = not autoFavEnabled
            updateButtons()
        end)

        btnFavAll = makeLittleButton(scroll, "Fav All (Once)", 0)
        btnFavAll.Size = UDim2.new(0.5, -4, 0, 24)
        btnFavAll.MouseButton1Click:Connect(function()
            favoriteAllInRanges()
        end)

        btnUnFavAll = makeLittleButton(scroll, "UnFav All (Once)", 0)
        btnUnFavAll.Size = UDim2.new(0.5, -4, 0, 24)
        btnUnFavAll.MouseButton1Click:Connect(function()
            unFavoriteAllInRanges()
        end)

        local fishRow = New("Frame", {
            Name = "FishRow",
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,26),
            Parent = favCard,
        }, {
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder     = Enum.SortOrder.LayoutOrder,
                Padding       = UDim.new(0,6),
            }),
        })

        favFishButton   = makeLittleButton(fishRow, "Fav All (Fish): Disable", 0)
        favFishButton.Size = UDim2.new(0.5, -3, 1, 0)

        unfavFishButton = makeLittleButton(fishRow, "UnFav All (Fish): Disable", 0)
        unfavFishButton.Size = UDim2.new(0.5, -3, 1, 0)

        favDropdownFrame = New("ScrollingFrame", {
            Name = "FavFishDropdown",
            BackgroundColor3 = Color3.fromRGB(244,246,255),
            BorderSizePixel  = 0,
            Visible          = false,
            AnchorPoint      = Vector2.new(0,0),
            Size             = UDim2.new(0, 200, 0, 140),
            CanvasSize       = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness  = 3,
            ZIndex           = 50,
            ClipsDescendants = true,
            Parent           = frame,
        }, {
            New("UICorner", { CornerRadius = UDim.new(0,6) }),
            New("UIStroke", {
                Thickness    = 1,
                Color        = Color3.fromRGB(210,212,230),
                Transparency = 0.3,
            }),
            New("UIPadding", {
                PaddingTop    = UDim.new(0,3),
                PaddingBottom = UDim.new(0,3),
                PaddingLeft   = UDim.new(0,4),
                PaddingRight  = UDim.new(0,4),
            }),
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder     = Enum.SortOrder.LayoutOrder,
                Padding       = UDim.new(0,2),
            }),
        })

        unfavDropdownFrame = New("ScrollingFrame", {
            Name = "UnFavFishDropdown",
            BackgroundColor3 = Color3.fromRGB(244,246,255),
            BorderSizePixel  = 0,
            Visible          = false,
            AnchorPoint      = Vector2.new(0,0),
            Size             = UDim2.new(0, 200, 0, 140),
            CanvasSize       = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness  = 3,
            ZIndex           = 50,
            ClipsDescendants = true,
            Parent           = frame,
        }, {
            New("UICorner", { CornerRadius = UDim.new(0,6) }),
            New("UIStroke", {
                Thickness    = 1,
                Color        = Color3.fromRGB(210,212,230),
                Transparency = 0.3,
            }),
            New("UIPadding", {
                PaddingTop    = UDim.new(0,3),
                PaddingBottom = UDim.new(0,3),
                PaddingLeft   = UDim.new(0,4),
                PaddingRight  = UDim.new(0,4),
            }),
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder     = Enum.SortOrder.LayoutOrder,
                Padding       = UDim.new(0,2),
            }),
        })

        local function buildDropdownOptions(frameDrop, isFavDropdown)
            for _, child in ipairs(frameDrop:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end

            for idx, entry in ipairs(FAV_FISH_NAME) do
                local optBtn = New("TextButton", {
                    Size             = UDim2.new(1,0,0,22),
                    BackgroundColor3 = Color3.fromRGB(228,232,248),
                    BorderSizePixel  = 0,
                    AutoButtonColor  = true,
                    Font             = Enum.Font.Gotham,
                    TextSize         = 12,
                    TextColor3       = Color3.fromRGB(40,44,70),
                    Text             = entry.Name or "Disable",
                    ZIndex           = 51,
                    Parent           = frameDrop,
                }, {
                    New("UICorner", { CornerRadius = UDim.new(0,4) }),
                })

                optBtn.MouseButton1Click:Connect(function()
                    if isFavDropdown then
                        favFishSelectedIndex = idx
                        frameDrop.Visible = false
                        updateButtons()

                        local chosen = entry.Name or "Disable"
                        if normalizeFishTypeName(chosen) ~= "disable" then
                            favoriteAllByFishName(chosen)
                        else
                            notify("IndoHangout", "Fav All (Fish): Mode Disable, tidak ada aksi.", 2)
                        end
                    else
                        unfavFishSelectedIndex = idx
                        frameDrop.Visible = false
                        updateButtons()

                        local chosen = entry.Name or "Disable"
                        if normalizeFishTypeName(chosen) ~= "disable" then
                            unFavoriteAllByFishName(chosen)
                        else
                            notify("IndoHangout", "UnFav All (Fish): Mode Disable, tidak ada aksi.", 2)
                        end
                    end
                end)
            end
        end

        buildDropdownOptions(favDropdownFrame, true)
        buildDropdownOptions(unfavDropdownFrame, false)

        local function showDropdown(dropFrame, anchorButton)
            if not dropFrame or not anchorButton or not frame then return end

            if dropFrame.Visible then
                dropFrame.Visible = false
                return
            end

            if dropFrame == favDropdownFrame and unfavDropdownFrame then
                unfavDropdownFrame.Visible = false
            elseif dropFrame == unfavDropdownFrame and favDropdownFrame then
                favDropdownFrame.Visible = false
            end

            local btnAbs   = anchorButton.AbsolutePosition
            local frameAbs = frame.AbsolutePosition
            local relX     = btnAbs.X - frameAbs.X
            local relY     = btnAbs.Y - frameAbs.Y + anchorButton.AbsoluteSize.Y + 2

            dropFrame.Position = UDim2.new(0, relX, 0, relY)
            dropFrame.Visible  = true
        end

        favFishButton.MouseButton1Click:Connect(function()
            showDropdown(favDropdownFrame, favFishButton)
        end)

        unfavFishButton.MouseButton1Click:Connect(function()
            showDropdown(unfavDropdownFrame, unfavFishButton)
        end)

        updateButtons()
    end

    return F
end)()

------------------- INDEX ROD LIST -------------------
local ROD_NAME_INDEX = {
    { Name = "Basic Rod"     },
    { Name = "Party Rod"     },
    { Name = "Shark Rod"     },
    { Name = "Piranha Rod"   },
    { Name = "Thermo Rod"    },
    { Name = "Flowers Rod"   },
    { Name = "Trisula Rod"   },
    { Name = "Feather Rod"   },
    { Name = "Wave Rod"      },
    { Name = "Duck Rod"      },
    { Name = "Planet Rod"    },
    { Name = "Earth Rod"     },
    { Name = "Coconut Rod"   },
    { Name = "Bat Rod"       },
    { Name = "Pumkin Rod"    },
    { Name = "VIP Rod"       },
    { Name = "Reindeer Rod"       },
    { Name = "Canny Rod"       },
    { Name = "Jinggle Rod"       },
    { Name = "Gopay Rod"     },
}

------------------- HELPER: DISCORD MENTION -------------------
local function getDiscordMentionAndLine(pl)
    if not pl then return nil, "" end
    if filterOnlyMe then
        return nil, ""
    end

    local su = SPECIAL_USERS[pl.UserId]
    if su then
        local mentionTag = su.discord or DEFAULT_OWNER_DISCORD
        local line = string.format("\nCaught by: %s", mentionTag)
        return mentionTag, line
    end

    local fallbackMention = DEFAULT_OWNER_DISCORD
    local fallbackLine    = string.format("\nCaught by: %s", fallbackMention)
    return fallbackMention, fallbackLine
end

------------------- STATS UI UPDATE (LOCAL) -------------------
local function getLocalTotalCaught()
    return #catchLog
end

local function updateStatsUI()
    local totalCaught = getLocalTotalCaught()
    caughtCount = totalCaught
    castsCount  = totalCaught

    if statsCastLabel then
        statsCastLabel.Text = string.format("Cast: %d", totalCaught)
    end
    if statsCaughtLabel then
        statsCaughtLabel.Text = string.format("Caught: %d", totalCaught)
    end
    if statsLastLabel then
        statsLastLabel.Text = "Caught Terbaru: " .. (lastCatchName or "-")
    end
    if statsSellLabel then
        statsSellLabel.Text = "Auto Sell: " .. tostring(autoSellMode or "Disable")
    end
end

local function buildCatchLinesForLog(log)
    local lines = {}
    lines[#lines+1] = "**__Riwayat Caught:__**"
    for i, name in ipairs(log) do
        lines[#lines+1] = string.format("%d. %s", i, name)
    end
    return lines
end

-- Generic chunk builder (dipakai List Caught & Index Rod)
local function buildDescChunks(header, lines)
    local chunks = {}
    local currentLines = {}
    local currentLen   = #header

    for _, line in ipairs(lines) do
        local addLen = #line
        if #currentLines > 0 then
            addLen = addLen + 1
        end

        if currentLen + addLen > MAX_DESC then
            local listPart = table.concat(currentLines, "\n")
            chunks[#chunks+1] = header .. listPart
            currentLines = { line }
            currentLen   = #header + #line
        else
            table.insert(currentLines, line)
            currentLen = currentLen + addLen
        end
    end

    if #currentLines > 0 then
        local listPart = table.concat(currentLines, "\n")
        chunks[#chunks+1] = header .. listPart
    elseif #chunks == 0 then
        chunks[#chunks+1] = header
    end

    return chunks
end

local function buildCatchDescChunks(header, log)
    local lines = buildCatchLinesForLog(log)
    return buildDescChunks(header, lines)
end

local function buildFavoritesDescChunks(header, lines)
    return buildDescChunks(header, lines)
end

------------------- START FISHING SUMMARY -------------------
local function getStartFishingSummaryLine(startTime)
    if not startTime then
        return "Start Fishing: -"
    end

    local now = os.time()
    if now < startTime then
        now = startTime
    end

    local startW = os.date("!*t", startTime + 8 * 3600)
    local nowW   = os.date("!*t", now + 8 * 3600)

    local startStr = string.format("%02d.%02d", startW.hour, startW.min)
    local nowStr   = string.format("%02d.%02d", nowW.hour, nowW.min)

    local diff = now - startTime
    if diff < 0 then diff = 0 end

    local hours = math.floor(diff / 3600)
    local mins  = math.floor((diff % 3600) / 60)

    local durText
    if hours > 0 and mins > 0 then
        durText = string.format(" (%d jam %d menit)", hours, mins)
    else
        if hours > 0 then
            durText = string.format(" (%d jam)", hours)
        else
            durText = string.format(" (%d menit)", mins)
        end
    end

    return string.format("Start Fishing: Jam %s - %s WITA%s", startStr, nowStr, durText)
end

------------------- FRIEND / STRANGER CLASSIFICATION -------------------
local function isSpecialFriendPlayer(pl)
    return pl and SPECIAL_USERS[pl.UserId] ~= nil
end

local function isRobloxFriendPlayer(pl)
    if not pl or pl == LocalPlayer then return false end
    local ok, isFr = pcall(function()
        return pl:IsFriendsWith(LocalPlayer.UserId)
    end)
    if not ok then
        return false
    end
    return isFr
end

local function isTrackedByFilter(pl)
    if not pl or pl == LocalPlayer then return false end

    if filterMode == 2 then
        return isSpecialFriendPlayer(pl)
    elseif filterMode == 3 then
        return isRobloxFriendPlayer(pl)
    elseif filterMode == 4 then
        return true
    end

    return false
end

local function getEmbedKindForPlayer(pl)
    if not pl then
        return "Stranger"
    end
    if pl == LocalPlayer then
        return "Friend"
    end
    if isSpecialFriendPlayer(pl) or isRobloxFriendPlayer(pl) then
        return "Friend"
    end
    return "Stranger"
end

------------------- SEND LIST CAUGHT MULTI PART -------------------
local function sendCatchListMultiPart(titleBase, warnTag, pl, log, lastName, mentionContent, extraLine, startTime, colorOverride, targetType)
    if not pl or not log or #log == 0 then return end

    local startLine = getStartFishingSummaryLine(startTime)

    local header = string.format(
        "**%s (@%s)**\n%s\nJumlah Caught: %d\nCaught Terbaru: %s%s\n\n",
        pl.DisplayName or pl.Name,
        pl.Name,
        startLine,
        #log,
        tostring(lastName or "-"),
        extraLine or ""
    )

    local chunks     = buildCatchDescChunks(header, log)
    local totalParts = #chunks

    for idx, desc in ipairs(chunks) do
        local title = titleBase
        if totalParts > 1 then
            title = string.format("%s (Part %d/%d)", titleBase, idx, totalParts)
        end

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = BOT_AVATAR_URL,
            content    = DEFAULT_OWNER_DISCORD,
            embeds = {{
                title       = title,
                description = desc,
                color       = colorOverride or 0x5b8def,
                footer      = { text = formatWitaTimestamp("IndoHangout") },
            }}
        }

        if mentionContent and idx == 1 then
            payload.content = mentionContent
        end

        local ok, err = postDiscord(payload, targetType)
        if not ok then
            warn(string.format("[IndoHangout] Webhook %s gagal (Part %d/%d): %s", warnTag, idx, totalParts, tostring(err)))
        end
    end
end

------------------- FRIEND STATES HELPER -------------------
local function removeFriendState(pl)
    FriendStates[pl] = nil
end

local function ensureFriendState(pl)
    if not pl then return nil end
    if pl == LocalPlayer then
        FriendStates[pl] = nil
        return nil
    end

    local tracked = isTrackedByFilter(pl)
    if not tracked then
        FriendStates[pl] = nil
        return nil
    end

    local st = FriendStates[pl]
    if not st then
        st = {
            fishSnapshot       = scanFishCounts(pl),
            catchLog           = {},
            lastCatchName      = "-",
            lastCatchSentIndex = 0,
            startTime          = nil,
        }
        FriendStates[pl] = st
    end
    return st
end

local function rebuildFriendStates()
    for pl,_ in pairs(FriendStates) do
        FriendStates[pl] = nil
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        ensureFriendState(pl)
    end
end

for _, pl in ipairs(Players:GetPlayers()) do
    ensureFriendState(pl)
end

Players.PlayerAdded:Connect(function(pl)
    ensureFriendState(pl)
end)

Players.PlayerRemoving:Connect(function(pl)
    removeFriendState(pl)
end)

------------------- CATCH DETECTION LOCAL -------------------
local function updateCatchFromBackpack()
    local nowCounts = scanFishCounts(LocalPlayer)

    if not fishCountsSnapshot then
        fishCountsSnapshot = copyFishCounts(nowCounts)
        return false
    end

    local addedTotal  = 0
    local lastNewName = lastCatchName

    for name, newCnt in pairs(nowCounts) do
        local oldCnt = fishCountsSnapshot[name] or 0
        if newCnt > oldCnt then
            local delta = newCnt - oldCnt

            for _ = 1, delta do
                table.insert(catchLog, name)
                addedTotal  = addedTotal + 1
                lastNewName = name
            end

            if FavoriteFish and FavoriteFish.OnNewCatchByName then
                FavoriteFish.OnNewCatchByName(name, delta)
            end
        end
    end

    fishCountsSnapshot = copyFishCounts(nowCounts)

    if addedTotal > 0 then
        lastCatchName = lastNewName

        if not localFirstCatchTime then
            localFirstCatchTime = os.time()
        end

        if pendingRodSpeedSeconds then
            lastRodSpeedSeconds = pendingRodSpeedSeconds
            lastRodSpeedLabel   = pendingRodSpeedLabel
        else
            lastRodSpeedSeconds = nil
            lastRodSpeedLabel   = nil
        end
        pendingRodSpeedSeconds = nil
        pendingRodSpeedLabel   = nil

        updateStatsUI()

        local pl = LocalPlayer
        local mentionContent, extraLine = getDiscordMentionAndLine(pl)
        local startTime = sessionFishingStart or localFirstCatchTime

        local speedLine = ""
        if lastRodSpeedSeconds and lastRodSpeedLabel then
            speedLine = string.format("\nSpeed Rod: %.2f detik (%s)", lastRodSpeedSeconds, lastRodSpeedLabel)
        end

        local desc = string.format(
            "**%s (@%s)**\n%s\nJumlah Caught: %d%s\nCaught Terbaru: **%s**%s",
            pl.DisplayName or pl.Name,
            pl.Name,
            getStartFishingSummaryLine(startTime),
            #catchLog,
            speedLine,
            tostring(lastCatchName or "-"),
            extraLine or ""
        )

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = BOT_AVATAR_URL,
            content    = DEFAULT_OWNER_DISCORD,
            embeds = {{
                title       = "🎣 Caught Terbaru",
                description = desc,
                color       = 0xFFC832,
                footer      = { text = formatWitaTimestamp("IndoHangout") },
            }}
        }

        if mentionContent then
            payload.content = mentionContent
        end

        task.spawn(function()
            if sendListCaughtEnabled then
                -- list uptodate dikirim oleh loop 60 detik
            end
            local ok, err = postDiscord(payload)
            if not ok then
                warn("[IndoHangout] Webhook Caught Terbaru (Local) gagal:", err)
            end
        end)

        return true
    end

    return false
end

------------------- CATCH DETECTION FRIEND/STRANGER -------------------
local function updateFriendCatchFromBackpack(pl)
    if filterMode == 1 then return false end
    if not pl or pl == LocalPlayer then return false end

    local tracked  = isTrackedByFilter(pl)
    if not tracked then
        return false
    end

    local st = ensureFriendState(pl)
    if not st then return false end

    local nowCounts = scanFishCounts(pl)

    if not st.fishSnapshot then
        st.fishSnapshot = copyFishCounts(nowCounts)
        return false
    end

    local addedTotal  = 0
    local lastNewName = st.lastCatchName

    for name, newCnt in pairs(nowCounts) do
        local oldCnt = st.fishSnapshot[name] or 0
        if newCnt > oldCnt then
            local delta = newCnt - oldCnt
            for _ = 1, delta do
                table.insert(st.catchLog, name)
                addedTotal  = addedTotal + 1
                lastNewName = name
            end
        end
    end

    st.fishSnapshot = copyFishCounts(nowCounts)

    if addedTotal > 0 then
        st.lastCatchName = lastNewName

        if not st.startTime then
            st.startTime = os.time()
        end

        local mentionContent, extraLine = getDiscordMentionAndLine(pl)
        local embedKind = getEmbedKindForPlayer(pl)

        local color = 0xFFC832
        if embedKind == "Stranger" then
            color = 0xFF4C4C
        end

        local desc = string.format(
            "**%s (@%s)**\n%s\nJumlah Caught: %d\nCaught Terbaru: **%s**%s",
            pl.DisplayName or pl.Name,
            pl.Name,
            getStartFishingSummaryLine(st.startTime),
            #st.catchLog,
            tostring(st.lastCatchName or "-"),
            extraLine or ""
        )

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = BOT_AVATAR_URL,
            embeds = {{
                title       = "🎣 Caught Terbaru ("..embedKind..")",
                description = desc,
                color       = color,
                footer      = { text = formatWitaTimestamp("IndoHangout") },
            }}
        }

        if mentionContent then
            payload.content = mentionContent
        end

        task.spawn(function()
            if sendListCaughtEnabled then
                -- list friend periodik
            end

            local targetType = (embedKind == "Stranger") and "selected" or nil
            local ok, err = postDiscord(payload, targetType)
            if not ok then
                warn("[IndoHangout] Webhook Caught Terbaru ("..embedKind..") gagal:", err)
            end
        end)

        return true
    end

    return false
end

------------------- MINI PROGRESS BAR REELING -------------------
local function setReelProgress(p)
    local v = math.clamp(tonumber(p) or 0, 0, 1)

    reelProgress = v
    if reelProgressFill then
        reelProgressFill.Size = UDim2.new(reelProgress, 0, 1, 0)
    end
    if reelProgressLabel then
        local percent = math.floor(reelProgress * 100 + 0.5)
        reelProgressLabel.Text = string.format("Reeling Progress: %d%%", percent)
    end
end

------------------- HEADER TAB -------------------
local headerScroll = Instance.new("ScrollingFrame")
headerScroll.Name = "HeaderScroll"
headerScroll.Position = UDim2.new(0,0,0,0)
headerScroll.Size = UDim2.new(1,0,0,64)
headerScroll.BackgroundTransparency = 1
headerScroll.BorderSizePixel = 0
headerScroll.ScrollBarThickness = 3
headerScroll.ScrollingDirection = Enum.ScrollingDirection.Y
headerScroll.CanvasSize = UDim2.new(0,0,0,0)
headerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
headerScroll.Parent = frame

local hPad = Instance.new("UIPadding", headerScroll)
hPad.PaddingLeft   = UDim.new(0,5)
hPad.PaddingRight  = UDim.new(0,5)
hPad.PaddingTop    = UDim.new(0,4)
hPad.PaddingBottom = UDim.new(0,4)

local hLayout = Instance.new("UIListLayout", headerScroll)
hLayout.FillDirection = Enum.FillDirection.Vertical
hLayout.SortOrder     = Enum.SortOrder.LayoutOrder
hLayout.Padding       = UDim.new(0,4)

makeLabel(
    headerScroll,"Header","🎣 Indo HG — Auto Fishing",
    UDim2.new(1,-10,0,20),UDim2.new(),
    { Font=Enum.Font.GothamBold, TextSize=15, TextColor3=Color3.fromRGB(40,40,60), XAlign=Enum.TextXAlignment.Left }
)

-- DESKRIPSI HEADER (AUTO HEIGHT)
local headerSubLabel = makeLabel(
    headerScroll,"Sub",
    "Auto Fishing + Auto Sell Under (v1 LITE) + Rod Shop. Filter: Only Me / Filter Friends / Filter All Friend / Filter All Player. Stranger embed merah",
    UDim2.new(1,-10,0,0),UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(90,90,120),
      XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
)
headerSubLabel.AutomaticSize = Enum.AutomaticSize.Y

do
    local container = New("Frame", {
        Name = "ReelMiniBarContainer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-10,0,18),
        Parent = headerScroll,
    })

    local bg = New("Frame", {
        Name = "ReelMiniBarBG",
        BackgroundColor3 = Color3.fromRGB(230,234,250),
        BorderSizePixel  = 0,
        Size             = UDim2.new(1,0,1,0),
        Parent           = container,
    }, {
        New("UICorner", { CornerRadius = UDim.new(0,8) }),
        New("UIStroke", {
            Thickness    = 1,
            Color        = Color3.fromRGB(200,204,230),
            Transparency = 0.35,
        }),
    })

    reelProgressFill = New("Frame", {
        Name = "Fill",
        BackgroundColor3 = Color3.fromRGB(120,160,255),
        BorderSizePixel  = 0,
        Size             = UDim2.new(0,0,1,0),
        Parent           = bg,
    }, {
        New("UICorner", { CornerRadius = UDim.new(0,8) })
    })

    reelProgressLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-8,1,0),
        Position = UDim2.new(0,4,0,0),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = Color3.fromRGB(40,44,80),
        Text = "Reeling Progress: 0%",
        Parent = bg,
    })
end

------------------- BODY SCROLL -------------------
local body = Instance.new("ScrollingFrame")
body.Name = "BodyScroll"
body.Position = UDim2.new(0,0,0,64)
body.Size = UDim2.new(1,0,1,-64)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.CanvasSize = UDim2.new(0,0,0,0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = frame

local bodyPad = Instance.new("UIPadding", body)
bodyPad.PaddingLeft   = UDim.new(0,6)
bodyPad.PaddingRight  = UDim.new(0,6)
bodyPad.PaddingTop    = UDim.new(0,4)
bodyPad.PaddingBottom = UDim.new(0,6)

local bodyLayout = Instance.new("UIListLayout", body)
bodyLayout.FillDirection = Enum.FillDirection.Vertical
bodyLayout.SortOrder     = Enum.SortOrder.LayoutOrder
bodyLayout.Padding       = UDim.new(0,8)

------------------- CARD: AUTO FISHING -------------------
local autoCard = makeCard(body, 1)

local autoHeaderScroll = New("ScrollingFrame", {
    Name = "AutoHeaderScroll",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1,0,0,180),
    CanvasSize = UDim2.new(0,0,0,0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    Parent = autoCard,
}, {
    New("UIPadding", {
        PaddingLeft   = UDim.new(0,0),
        PaddingRight  = UDim.new(0,0),
        PaddingTop    = UDim.new(0,0),
        PaddingBottom = UDim.new(0,0),
    })
})

local autoHeaderLayout = New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0,4),
    Parent = autoHeaderScroll,
})

makeLabel(
    autoHeaderScroll,"AutoTitle","Auto Fishing & Auto Sell — Indo HG",
    UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),
    { Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Color3.fromRGB(35,38,70), XAlign=Enum.TextXAlignment.Left }
)

-- DESKRIPSI AUTO FISH (AUTO HEIGHT)
local autoDescLabel = makeLabel(
    autoHeaderScroll,"AutoDesc",
    "Auto Fishing + minigame reeling otomatis. Filter: Only Me / Filter Friends / Filter All Friend (Roblox Friend) / Filter All Player. Stranger embed merah)",
    UDim2.new(1,0,0,0),UDim2.new(0,0,0,18),
    { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(92,96,124),
      XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
)
autoDescLabel.AutomaticSize = Enum.AutomaticSize.Y

-- Kontrol utama (Auto Fishing, Auto Sell, Send Discord, List Caught, Webhook 1-4, Rod Selector)
local controlRow = New("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Parent = autoHeaderScroll,
}, {})

local controlsGrid = New("UIGridLayout", {
    CellSize            = UDim2.new(1/3, -8, 0, 24),
    CellPadding         = UDim2.new(0,6,0,6),
    FillDirection       = Enum.FillDirection.Horizontal,
    SortOrder           = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top,
})
controlsGrid.Parent = controlRow

local autoFishBtn     = makeLittleButton(controlRow, "Auto Fishing: OFF")
local autoSellBtn     = makeLittleButton(controlRow, "Auto Sell: Disable")
local sendDiscordBtn  = makeLittleButton(controlRow, "Send Discord")
local sendListBtn     = makeLittleButton(controlRow, "List Caught: OFF")
local webhook1Btn     = makeLittleButton(controlRow, "Webhook 1: ON")
local webhook2Btn     = makeLittleButton(controlRow, "Webhook 2: ON")
local webhook3Btn     = makeLittleButton(controlRow, "Webhook 3: OFF")
local webhook4Btn     = makeLittleButton(controlRow, "Webhook 4: OFF")
local rodModeBtn      = makeLittleButton(controlRow, "Rod: Auto")

-- Mode UI rod: Auto / Wave / Piranha / VIP / Thermo, semua via scan Backpack/Character
local ROD_UI_MODES = {
    { label = "Auto Rod", chosen = nil },
    { label = "Earth Rod",                       chosen = "Earth Rod" },
    { label = "Reindeer Rod",                       chosen = "Reindeer Rod" },
    { label = "Wave Rod",                       chosen = "Wave Rod" },
    { label = "Piranha Rod",                    chosen = "Piranha Rod" },
    { label = "VIP Rod",                        chosen = "VIP Rod" },
    { label = "Thermo Rod",                     chosen = "Thermo Rod" },
}

local rodUiModeIndex = 1

local function updateRodModeButtonUI()
    if not rodModeBtn then return end
    local mode = ROD_UI_MODES[rodUiModeIndex] or ROD_UI_MODES[1]
    rodModeBtn.Text = "Rod: " .. (mode.label or "Auto")
end

local function applyRodSelectionFromUI()
    local mode = ROD_UI_MODES[rodUiModeIndex] or ROD_UI_MODES[1]
    chosenRodName = mode.chosen  -- nil = Auto (pakai prioritas Wave>Piranha>VIP>Thermo)
    local rod = equipChosenRod()
    if rod then
        if statsStatusLabel then
            statsStatusLabel.Text =
                "Status: Rod aktif = " .. (rod.Name or "Rod") ..
                " (mode: " .. (mode.label or "Auto") .. ")."
        end
    else
        if statsStatusLabel then
            statsStatusLabel.Text =
                "Status: Rod mode '" .. (mode.label or "Auto") .. "' tidak menemukan rod di Backpack/Character."
        end
    end
end

rodModeBtn.MouseButton1Click:Connect(function()
    rodUiModeIndex += 1
    if rodUiModeIndex > #ROD_UI_MODES then
        rodUiModeIndex = 1
    end
    updateRodModeButtonUI()
    applyRodSelectionFromUI()
    notify("IndoHangout", "Rod mode: " .. (ROD_UI_MODES[rodUiModeIndex].label or "Auto"), 2)
end)

updateRodModeButtonUI()

local function updateWebhookButtonsUI()
    local function style(btn, enabled, label)
        btn.Text = label .. (enabled and "ON" or "OFF")
        if enabled then
            btn.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
            btn.TextColor3       = Color3.fromRGB(255,255,255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
            btn.TextColor3       = Color3.fromRGB(40, 44, 70)
        end
    end

    style(webhook1Btn, webhookEnabled1, "Webhook 1: ")
    style(webhook2Btn, webhookEnabled2, "Webhook 2: ")
    style(webhook3Btn, webhookEnabled3, "Webhook 3: ")
    style(webhook4Btn, webhookEnabled4, "Webhook 4: ")
end

webhook1Btn.MouseButton1Click:Connect(function()
    webhookEnabled1 = not webhookEnabled1
    updateWebhookButtonsUI()
    notify("IndoHangout", "Webhook 1: " .. (webhookEnabled1 and "ON" or "OFF"), 2)
end)

webhook2Btn.MouseButton1Click:Connect(function()
    webhookEnabled2 = not webhookEnabled2
    updateWebhookButtonsUI()
    notify("IndoHangout", "Webhook 2: " .. (webhookEnabled2 and "ON" or "OFF"), 2)
end)

webhook3Btn.MouseButton1Click:Connect(function()
    webhookEnabled3 = not webhookEnabled3
    updateWebhookButtonsUI()
    notify("IndoHangout", "Webhook 3: " .. (webhookEnabled3 and "ON" or "OFF"), 2)
end)

webhook4Btn.MouseButton1Click:Connect(function()
    webhookEnabled4 = not webhookEnabled4
    updateWebhookButtonsUI()
    notify("IndoHangout", "Webhook 4: " .. (webhookEnabled4 and "ON" or "OFF"), 2)
end)

updateWebhookButtonsUI()

------------------- FILTER ROW -------------------
-- Dibuat 2 kolom dengan UIGridLayout supaya ukuran tombol seragam & rapi
local filterRow = New("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Parent = autoHeaderScroll,
}, {})

local filterGrid = New("UIGridLayout", {
    CellSize            = UDim2.new(0.5, -4, 0, 24),
    CellPadding         = UDim2.new(0,8,0,6),
    FillDirection       = Enum.FillDirection.Horizontal,
    SortOrder           = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top,
})
filterGrid.Parent = filterRow

local onlyMeBtn      = makeLittleButton(filterRow, "☐ Only Me")
local friendsBtn     = makeLittleButton(filterRow, "☐ Filter Friends")
local allFriendsBtn  = makeLittleButton(filterRow, "☐ Filter All Friend")
local allPlayersBtn  = makeLittleButton(filterRow, "☐ Filter All Player")

local function styleFilterBtn(btn, isOn, label)
    if not btn then return end
    btn.Text = (isOn and "☑ " or "☐ ") .. label
    if isOn then
        btn.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
        btn.TextColor3       = Color3.fromRGB(255,255,255)
    else
        btn.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
        btn.TextColor3       = Color3.fromRGB(40, 44, 70)
    end
end

local function applyFilterButtons()
    styleFilterBtn(onlyMeBtn,     filterMode == 1, "Only Me")
    styleFilterBtn(friendsBtn,    filterMode == 2, "Filter Friends")
    styleFilterBtn(allFriendsBtn, filterMode == 3, "Filter All Friend")
    styleFilterBtn(allPlayersBtn, filterMode == 4, "Filter All Player")
end

local function setFilterMode(mode)
    filterMode   = mode
    filterOnlyMe = (mode == 1)

    applyFilterButtons()

    if mode == 1 then
        for pl,_ in pairs(FriendStates) do
            FriendStates[pl] = nil
        end
    else
        rebuildFriendStates()
    end

    if statsStatusLabel then
        if mode == 1 then
            statsStatusLabel.Text = "Status: Filter Webhook = Only Me."
        elseif mode == 2 then
            statsStatusLabel.Text = "Status: Filter Webhook = Filter Friends (SPECIAL_USERS)."
        elseif mode == 3 then
            statsStatusLabel.Text = "Status: Filter Webhook = Filter All Friend (Roblox Friends)."
        elseif mode == 4 then
            statsStatusLabel.Text = "Status: Filter Webhook = Filter All Player (server)."
        end
    end
end

onlyMeBtn.MouseButton1Click:Connect(function()
    setFilterMode(1)
end)

friendsBtn.MouseButton1Click:Connect(function()
    setFilterMode(2)
end)

allFriendsBtn.MouseButton1Click:Connect(function()
    setFilterMode(3)
end)

allPlayersBtn.MouseButton1Click:Connect(function()
    setFilterMode(4)
end)

setFilterMode(filterMode)

------------------- WEBHOOK 4 INPUT -------------------
local webhook4Row = New("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,26),
    Parent = autoHeaderScroll,
}, {
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0,6),
    }),
})

local webhook4Box = New("TextBox", {
    BackgroundColor3 = Color3.fromRGB(244, 246, 255),
    BorderSizePixel  = 0,
    Size             = UDim2.new(1,0,1,0),
    ClearTextOnFocus = false,
    Font             = Enum.Font.Gotham,
    TextSize         = 12,
    TextXAlignment   = Enum.TextXAlignment.Left,
    TextYAlignment   = Enum.TextYAlignment.Center,
    TextColor3       = Color3.fromRGB(40,44,80),
    PlaceholderText  = "Put webhooks (Webhook 4)",
    Text             = "",
    Parent           = webhook4Row,
}, {
    New("UICorner", { CornerRadius = UDim.new(0,8) }),
    New("UIPadding", {
        PaddingLeft   = UDim.new(0,6),
        PaddingRight  = UDim.new(0,6),
    })
})

webhook4Box.FocusLost:Connect(function()
    local txt = (webhook4Box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    WEBHOOK_URL_4 = txt
    if txt ~= "" then
        notify("IndoHangout", "Webhook 4 diupdate.", 2)
    else
        notify("IndoHangout", "Webhook 4 dikosongkan.", 2)
    end
end)

------------------- STATS BLOCK -------------------
local statsRow = New("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,72),
    Parent = autoCard,
}, {
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0,2),
    }),
})

statsCastLabel   = New("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,16),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(50,54,90),
    Text = "Cast: 0",
    Parent = statsRow,
})

statsCaughtLabel = New("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,16),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(50,54,90),
    Text = "Caught: 0",
    Parent = statsRow,
})

statsLastLabel   = New("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,16),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(50,54,90),
    Text = "Caught Terbaru: -",
    Parent = statsRow,
})

statsSellLabel   = New("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,16),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(80,84,120),
    Text = "Auto Sell Under: Disable",
    Parent = statsRow,
})

statsStatusLabel = New("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,0,32),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    TextColor3 = Color3.fromRGB(110,114,140),
    Text = "Status: Idle.",
    Parent = statsRow,
})

updateStatsUI()
setReelProgress(0)

----------------------------------------------------------------
-- AUTO SELL OPTIONS + doAutoSell
----------------------------------------------------------------
local AUTO_SELL_OPTIONS = {
    "Disable",
    "Sell This Fish",
    "All under 50 Kg",
    "All under 100 Kg",
    "All under 400 Kg",
    "All under 600 Kg",
    "Sell All Fish",
}

local function findAutoSellIndex(value)
    for i, v in ipairs(AUTO_SELL_OPTIONS) do
        if v == value then return i end
    end
    return 1
end

local function cycleAutoSellMode()
    local idx = findAutoSellIndex(autoSellMode)
    idx = idx + 1
    if idx > #AUTO_SELL_OPTIONS then idx = 1 end
    autoSellMode = AUTO_SELL_OPTIONS[idx]
    autoSellBtn.Text = "Auto Sell: " .. autoSellMode
    updateStatsUI()
end

autoSellBtn.MouseButton1Click:Connect(cycleAutoSellMode)

------------------- SEND LIST CAUGHT TOGGLE -------------------
local function updateSendListBtn()
    if sendListCaughtEnabled then
        sendListBtn.Text = "List Caught: ON"
        sendListBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 96)
        sendListBtn.TextColor3 = Color3.fromRGB(255,255,255)
    else
        sendListBtn.Text = "List Caught: OFF"
        sendListBtn.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
        sendListBtn.TextColor3 = Color3.fromRGB(40, 44, 70)
    end
end

sendListBtn.MouseButton1Click:Connect(function()
    sendListCaughtEnabled = not sendListCaughtEnabled
    updateSendListBtn()
    notify("IndoHangout", "List Caught: " .. (sendListCaughtEnabled and "ON" or "OFF"), 2)
end)

updateSendListBtn()

------------------- AUTOFISH CORE -------------------
findRodTool = function()
    local pl = LocalPlayer
    if not pl then return nil end

    local char     = pl.Character
    local backpack = pl:FindFirstChild("Backpack")

    local function searchByName(name)
        if not name then return nil end
        if char then
            for _, inst in ipairs(char:GetChildren()) do
                if inst:IsA("Tool") and inst.Name == name then
                    return inst
                end
            end
        end
        if backpack then
            for _, inst in ipairs(backpack:GetChildren()) do
                if inst:IsA("Tool") and inst.Name == name then
                    return inst
                end
            end
        end
        return nil
    end

    -- 1) Prioritas: rod yang sudah dipilih (chosenRodName)
    if chosenRodName then
        local rod = searchByName(chosenRodName)
        if rod then
            return rod
        end
    end

    -- 2) Kalau belum ada, cari sesuai ROD_PRIORITY (Wave > Piranha > VIP > Thermo)
    if not chosenRodName then
        for _, rodName in ipairs(ROD_PRIORITY) do
            local rod = searchByName(rodName)
            if rod then
                chosenRodName = rodName
                return rod
            end
        end
    end

    -- 3) Fallback: cari tool apa pun yang namanya mengandung "rod"
    local function searchRodInContainer(container)
        if not container then return nil end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") and string.lower(inst.Name):find("rod", 1, true) then
                return inst
            end
        end
        return nil
    end

    local rod = searchRodInContainer(char) or searchRodInContainer(backpack)
    if rod then
        chosenRodName = rod.Name
        return rod
    end

    return nil
end

local function stopReelBar()
    if reelBarConn then
        reelBarConn:Disconnect()
        reelBarConn = nil
    end
    reelingActive = false
    setReelProgress(0)
    reelStartTick = nil
end

local function startReelBar(tool)
    stopReelBar()
    if not RunService or not RodRemoteEvent then return end

    reelStartTick           = nil
    pendingRodSpeedSeconds  = nil
    pendingRodSpeedLabel    = nil

    reelBarConn = RunService.RenderStepped:Connect(function()
        if not autoFishing then
            reelingActive = false
            setReelProgress(0)
            return
        end

        local pg         = LocalPlayer:FindFirstChild("PlayerGui")
        local reelingGui = pg and pg:FindFirstChild("Reeling")
        if not (reelingGui and reelingGui.Enabled) then
            reelingActive = false
            setReelProgress(0)
            return
        end

        reelingActive = true

        local frameGui   = reelingGui:FindFirstChild("Frame")
        local midFrame   = frameGui and frameGui:FindFirstChild("Frame")
        local whiteBar   = midFrame and midFrame:FindFirstChild("WhiteBar")
        local redBar     = midFrame and midFrame:FindFirstChild("RedBar")
        local progressBg = frameGui and frameGui:FindFirstChild("ProgressBg")
        local progressBar= progressBg and progressBg:FindFirstChild("ProgressBar")

        if whiteBar and redBar then
            local targetCenter = redBar.Position.X.Scale + redBar.Size.X.Scale * 0.5
            local halfWidth    = whiteBar.Size.X.Scale * 0.5
            local newX = math.clamp(targetCenter - halfWidth, 0, 1 - whiteBar.Size.X.Scale)
            whiteBar.Position = UDim2.new(
                newX, 0,
                whiteBar.Position.Y.Scale,
                whiteBar.Position.Y.Offset
            )
        end

        if progressBar then
            local prog = math.clamp(progressBar.Size.X.Scale or 0, 0, 1)

            if reelStartTick == nil and prog > 0 then
                reelStartTick = os.clock()
            end

            setReelProgress(prog)

            -- Tidak ada lagi "Speedup Reeling". Reeling hanya di-trigger saat progress 100%.
            if prog >= 1 then
                pcall(function()
                    RodRemoteEvent:FireServer("Reeling", tool, true)
                end)
            end
        else
            setReelProgress(0)
        end
    end)
end

local function doAutoSell()
    if not SellFishRemoteFunction then return end
    if not autoSellMode or autoSellMode == "Disable" then return end

    local args = { [1] = "SellFish" }

    if autoSellMode == "Sell This Fish" then
        local char = LocalPlayer.Character
        if not char then return end

        local holdingFish = nil
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") and isFishName(inst.Name) then
                holdingFish = inst
                break
            end
        end

        if not holdingFish then
            return
        end

        args[2] = "Sell This Fish"

    elseif autoSellMode == "All under 50 Kg" then
        args[2] = "All under 50 Kg"
    elseif autoSellMode == "All under 100 Kg" then
        args[2] = "All under 100 Kg"
    elseif autoSellMode == "All under 400 Kg" then
        args[2] = "All under 400 Kg"
    elseif autoSellMode == "All under 600 Kg" then
        args[2] = "All under 600 Kg"
    elseif autoSellMode == "Sell All Fish" then
        args[2] = "Sell All Fish"
    else
        return
    end

    pcall(function()
        SellFishRemoteFunction:InvokeServer(unpack(args))
    end)
end

------------------- THROW -------------------
local function doThrow(tool)
    if not RodRemoteEvent or not tool then return end

    local hitCFrame
    local ok, hit = pcall(function()
        return LocalPlayer:GetMouse().Hit
    end)

    if ok and hit then
        hitCFrame = hit
    else
        local cam = workspace.CurrentCamera
        if cam then
            hitCFrame = cam.CFrame + cam.CFrame.LookVector * 60
        else
            hitCFrame = CFrame.new()
        end
    end

    if _G.AxaHub and _G.AxaHub.IndoHangout then
        _G.AxaHub.IndoHangout.LastThrowTick = os.clock()
    end

    pcall(function()
        RodRemoteEvent:FireServer("Throw", tool, hitCFrame)
    end)
end

local function startOneCastCycle(optionalRod)
    if not autoFishing or isCasting then return end
    isCasting = true

    local rod = optionalRod or ensureRodEquipped()

    if not rod then
        isCasting = false
        if statsStatusLabel then
            statsStatusLabel.Text = "Status: Rod tidak ditemukan. Pastikan Wave/Piranha/VIP/Thermo ada di Backpack."
        end
        return
    end

    if statsStatusLabel then
        statsStatusLabel.Text = "Status: Melempar (Throw) dengan " .. (rod.Name or "Rod") .. "…"
    end

    setReelProgress(0)
    doThrow(rod)

    task.delay(1.0, function()
        if autoFishing and isCasting then
            startReelBar(rod)
        end
    end)
end

local function detachReelEvent()
    if reelEventConn then
        reelEventConn:Disconnect()
        reelEventConn = nil
    end
end

local function attachReelEvent()
    if not RodRemoteEvent then return end
    if reelEventConn then return end

    reelEventConn = RodRemoteEvent.OnClientEvent:Connect(function(action, tool, flag)
        local a = tostring(action)
        local completed = (a == "Reeling" and flag) or (a == "StopShake") or (a == "Stopshake")
        if not completed then return end
        
        local ownerPlayer = nil
        if typeof(tool) == "Instance" then
            local parent = tool.Parent
            if parent and parent:IsA("Model") then
                ownerPlayer = Players:GetPlayerFromCharacter(parent)
            end
        end

        if ownerPlayer == nil or ownerPlayer == LocalPlayer then
            local speedSeconds
            if reelStartTick then
                speedSeconds = os.clock() - reelStartTick
            end
            reelStartTick = nil

            if speedSeconds and speedSeconds > 0 then
                if speedSeconds < 0 then speedSeconds = 0 end
                if speedSeconds > 999 then speedSeconds = 999 end

                local label = classifyRodSpeed(speedSeconds)

                pendingRodSpeedSeconds = speedSeconds
                pendingRodSpeedLabel   = label
            else
                pendingRodSpeedSeconds = nil
                pendingRodSpeedLabel   = nil
            end

            isCasting = false
            stopReelBar()
            setReelProgress(1)

            local didCatch = updateCatchFromBackpack()

            if autoFishing then
                doAutoSell()
                syncLocalSnapshotToCurrent()

                if statsStatusLabel then
                    if didCatch then
                        statsStatusLabel.Text = "Status: Caught + Auto Sell, siap lempar lagi…"
                    else
                        statsStatusLabel.Text = "Status: Selesai reeling, siap lempar lagi…"
                    end
                end

                task.delay(0.5, function()
                    if autoFishing then
                        startOneCastCycle()
                    end
                end)
            else
                if statsStatusLabel then
                    statsStatusLabel.Text = "Status: Selesai reeling (Auto Fishing OFF)."
                end
            end
        else
            if ownerPlayer and ownerPlayer ~= LocalPlayer then
                updateFriendCatchFromBackpack(ownerPlayer)
            end
        end
    end)
end

------------------- AUTOFISH TOGGLE -------------------
local function setAutoFishing(state)
    if state == autoFishing then return end
    autoFishing = state

    if autoFishing then
        if autoFishBtn then
            autoFishBtn.Text = "Auto Fishing: ON"
            autoFishBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 96)
            autoFishBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        end

        sessionFishingStart = os.time()

        if not fishCountsSnapshot then
            fishCountsSnapshot = scanFishCounts(LocalPlayer)
        end

        attachReelEvent()

        if statsStatusLabel then
            statsStatusLabel.Text = "Status: Auto Fishing ON, memilih rod awal (Wave/Piranha/VIP/Thermo atau rod yang kamu pegang)…"
        end

        task.delay(0.25, function()
            if not autoFishing then
                if statsStatusLabel then
                    statsStatusLabel.Text = "Status: Auto Fishing dimatikan sebelum lempar."
                end
                return
            end

            -- Gunakan preferensi rod UI (chosenRodName) + prioritas via equipChosenRod
            local rod = equipChosenRod()
            if not rod then
                if statsStatusLabel then
                    statsStatusLabel.Text = "Status: Rod tidak ditemukan di Backpack/Character (Wave/Piranha/VIP/Thermo)."
                end
                return
            end

            startOneCastCycle(rod)
        end)

        notify("IndoHangout", "Auto Fishing ON (rod auto via scan Backpack/Character: Wave > Piranha > VIP > Thermo, mengikuti mode Rod di UI).", 4)
    else
        if autoFishBtn then
            autoFishBtn.Text = "Auto Fishing: OFF"
            autoFishBtn.BackgroundColor3 = Color3.fromRGB(228, 232, 248)
            autoFishBtn.TextColor3       = Color3.fromRGB(40, 44, 70)
        end

        sessionFishingStart   = nil
        isCasting             = false

        stopReelBar()
        detachReelEvent()
        setReelProgress(0)

        if statsStatusLabel then
            statsStatusLabel.Text = "Status: Auto Fishing dimatikan."
        end

        notify("IndoHangout", "Auto Fishing OFF.")
    end
end

_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.IndoHangout = _G.AxaHub.IndoHangout or {}

do
    local hub = _G.AxaHub.IndoHangout

    hub.SetAutoFishing = function(state)
        setAutoFishing(state)
    end

    hub.IsAutoFishing = function()
        return autoFishing
    end

    hub.GetReelProgress = function()
        return reelProgress
    end

    hub.IsReeling = function()
        return reelingActive
    end

    hub.IsCasting = function()
        return isCasting
    end

    hub.LastThrowTick = hub.LastThrowTick or 0

    if type(hub.GetLastThrowTick) ~= "function" then
        function hub.GetLastThrowTick()
            return hub.LastThrowTick or 0
        end
    end
end

autoFishBtn.MouseButton1Click:Connect(function()
    setAutoFishing(not autoFishing)
end)

------------------- SEND LIST CAUGHT HELPERS -------------------
local sendLocalListCaught
local sendFriendListCaught

sendLocalListCaught = function(force)
    local pl = LocalPlayer
    if not pl or #catchLog == 0 then return end

    if not force and not sendListCaughtEnabled then
        return
    end

    if not force and #catchLog <= lastCatchSentIndexForTimer then
        return
    end

    local mentionContent, extraLine = getDiscordMentionAndLine(pl)
    local startTime = sessionFishingStart or localFirstCatchTime

    sendCatchListMultiPart(
        "📊 List Caught (Uptodate)",
        "List Caught (Local)",
        pl,
        catchLog,
        lastCatchName,
        mentionContent,
        extraLine,
        startTime,
        0xFFC832
    )

    lastCatchSentIndexForTimer = #catchLog
end

sendFriendListCaught = function(plFriend, st, force)
    if not plFriend or plFriend.Parent ~= Players then return end
    if plFriend == LocalPlayer then return end
    if not st or not st.catchLog or #st.catchLog == 0 then return end

    if not force and not sendListCaughtEnabled then
        return
    end

    local embedKind = getEmbedKindForPlayer(plFriend)
    local mentionContent, extraLine = getDiscordMentionAndLine(plFriend)

    local lastIdx = st.lastCatchSentIndex or 0
    if not force and #st.catchLog <= lastIdx then
        return
    end

    local color = 0xFFC832
    local targetType = nil
    if embedKind == "Stranger" then
        color = 0xFF4C4C
        targetType = "selected"
    end

    sendCatchListMultiPart(
        "📊 List Caught ("..embedKind..")",
        "List Caught "..embedKind,
        plFriend,
        st.catchLog,
        st.lastCatchName,
        mentionContent,
        extraLine,
        st.startTime,
        color,
        targetType
    )

    st.lastCatchSentIndex = #st.catchLog
end

local function sendCatchListToDiscord()
    sendLocalListCaught(true)

    if filterMode ~= 1 then
        for pl, st in pairs(FriendStates) do
            if pl.Parent == Players then
                sendFriendListCaught(pl, st, true)
            end
        end
    end
end

sendDiscordBtn.MouseButton1Click:Connect(function()
    sendCatchListToDiscord()
end)

------------------------------------------------------------
-- CARD: FAVORITE FISH — INDO HG
------------------------------------------------------------
if FavoriteFish and FavoriteFish.CreateFavoriteCard then
    FavoriteFish.CreateFavoriteCard(body)
end

------------------------------------------------------------
-- CARD: ROD SHOP
------------------------------------------------------------
local function createRodShopCard(parent)
    local ROD_SHOP_ITEMS = {
        { Name = "Party Rod"   },
        { Name = "Shark Rod"   },
        { Name = "Piranha Rod" },
        { Name = "Thermo Rod"  },
        { Name = "Flowers Rod" },
        { Name = "Trisula Rod" },
        { Name = "Feather Rod" },
        { Name = "Wave Rod"    },
        { Name = "Duck Rod"    },
        { Name = "Planet Rod"  },
        { Name = "Earth Rod"   },
    }

    local shopCard = makeCard(parent, 4)

    makeLabel(
        shopCard,"ShopTitle","Rod Shop — Indo HG",
        UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),
        { Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Color3.fromRGB(35,38,70), XAlign=Enum.TextXAlignment.Left }
    )

    -- DESKRIPSI SHOP (AUTO HEIGHT)
    local shopDescLabel = makeLabel(
        shopCard,"ShopDesc",
        "Ambil harga rod langsung dari server via RemoteFunction.RodShop (GetRodPrice & GetRodLureSpeed)",
        UDim2.new(1,0,0,0),UDim2.new(0,0,0,18),
        { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(92,96,124),
          XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
    )
    shopDescLabel.AutomaticSize = Enum.AutomaticSize.Y

    if not RodShopRemoteFunction then
        local warnLabel = makeLabel(
            shopCard,"ShopWarn",
            "⚠ RemoteFunction.RodShop tidak ditemukan di ReplicatedStorage.Events.RemoteFunction.",
            UDim2.new(1,0,0,0),UDim2.new(0,0,0,60),
            { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(180,70,70),
              XAlign=Enum.TextXAlignment.Left, Wrapped=true }
        )
        warnLabel.AutomaticSize = Enum.AutomaticSize.Y
        return
    end

    local function getRodPrice(rodName)
        local args = {
            [1] = "GetRodPrice",
            [2] = rodName,
        }
        local ok, res = pcall(function()
            return RodShopRemoteFunction:InvokeServer(unpack(args))
        end)
        if not ok then
            warn("[IndoHangout] GetRodPrice error for "..tostring(rodName)..": "..tostring(res))
            return nil
        end

        local v = res
        if type(res) == "table" then
            v = res.Price or res.price or res.Coin or res.coin or res.Coins or res.coins or res[1]
        end

        if type(v) == "number" then
            return v
        elseif type(v) == "string" then
            local clean = v:gsub("[^%d]", "")
            local n = tonumber(clean)
            if n then
                return n
            end
        end

        return nil
    end

    local function getRodLureSpeed(rodName)
        local args = {
            [1] = "GetRodLureSpeed",
            [2] = rodName,
        }
        local ok, res = pcall(function()
            return RodShopRemoteFunction:InvokeServer(unpack(args))
        end)
        if not ok then
            warn("[IndoHangout] GetRodLureSpeed error for "..tostring(rodName)..": "..tostring(res))
            return nil
        end

        local speed
        if type(res) == "number" then
            speed = res
        elseif type(res) == "table" then
            speed = res.LureSpeed or res.lureSpeed or res.Speed or res.speed
        else
            speed = res
        end

        if type(speed) == "string" then
            local clean = speed:gsub("[^%d]", "")
            speed = tonumber(clean)
        end

        if type(speed) ~= "number" then
            return nil
        end
        return speed
    end

    local function getRodProgressSpeed(rodName)
        if not RodIndexRemoteFunction then
            return nil
        end

        local args = {
            [1] = "GetRodProgressSpeed",
            [2] = rodName,
        }
        local ok, res = pcall(function()
            return RodIndexRemoteFunction:InvokeServer(unpack(args))
        end)
        if not ok then
            warn("[IndoHangout] GetRodProgressSpeed error for "..tostring(rodName)..": "..tostring(res))
            return nil
        end

        local speed
        if type(res) == "number" then
            speed = res
        elseif type(res) == "table" then
            speed = res.ProgressSpeed or res.progressSpeed or res.Speed or res.speed
        else
            speed = res
        end

        if type(speed) == "string" then
            local clean = speed:gsub("[^%d]", "")
            speed = tonumber(clean)
        end

        if type(speed) ~= "number" then
            return nil
        end
        return speed
    end

    local function sendRodBuyWebhook(rodItem, statusText)
        if not rodItem then return end

        local pl = LocalPlayer

        local priceVal = rodItem.Price
        if type(priceVal) ~= "number" then
            priceVal = getRodPrice(rodItem.Name)
            rodItem.Price = priceVal
        end

        local priceText = priceVal and formatRupiah(priceVal) or "-"

        local lureVal = rodItem.LureSpeed
        if type(lureVal) ~= "number" then
            lureVal = getRodLureSpeed(rodItem.Name)
            rodItem.LureSpeed = lureVal
        end

        local lureText  = lureVal and (tostring(lureVal) .. "%") or "-"

        local desc = string.format(
            "**%s (@%s)**\nRod Name: **%s**\nPrice: %s\nRod Lure Speed: %s\nStatus: %s",
            pl.DisplayName or pl.Name,
            pl.Name,
            tostring(rodItem.Name),
            priceText,
            lureText,
            statusText or "Sukses"
        )

        local payload = {
            embeds = {{
                title       = "🛒 Rod Shop Purchase",
                description = desc,
                color       = 0x5b8def,
                footer      = { text = os.date("IndoHangout • %Y-%m-%d %H:%M:%S") },
            }}
        }

        postDiscordFavorite(payload)
    end

    local indexRow = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,26),
        Parent = shopCard,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Padding       = UDim.new(0,6),
        }),
    })

    local sendIndexBtn = makeLittleButton(indexRow, "Send Index Rod", 130)
    sendIndexBtn.Size = UDim2.new(0,130,1,0)

    local function sendRodIndexToDiscord()
        if not ROD_NAME_INDEX or #ROD_NAME_INDEX == 0 then
            notify("IndoHangout", "ROD_NAME_INDEX kosong, tidak ada rod untuk dikirim.", 2)
            return
        end

        local lines = {}
        local count = 0

        for _, info in ipairs(ROD_NAME_INDEX) do
            local name = tostring(info.Name or "")
            if name ~= "" then
                count += 1

                local priceVal = getRodPrice(name)
                local lureVal  = getRodLureSpeed(name)
                local progVal  = getRodProgressSpeed(name)

                local priceText = priceVal and formatRupiah(priceVal) or "-"
                local lureText  = lureVal and (tostring(lureVal) .. "%") or "-"
                local progText  = progVal and tostring(progVal) or "-"

                lines[#lines+1] = string.format(
                    "%d. %s • %s • Lure: %s • Progress: %s",
                    count, name, priceText, lureText, progText
                )
            end
        end

        if #lines == 0 then
            notify("IndoHangout", "Tidak ada rod valid di ROD_NAME_INDEX.", 2)
            return
        end

        local pl = LocalPlayer
        local header = string.format(
            "**%s (@%s)**\nIndex Rod Indo HG (Nama, Price, Lure, Progress)\nTotal Rod: %d\n\n",
            pl.DisplayName or pl.Name,
            pl.Name,
            count
        )

        local chunks = buildFavoritesDescChunks(header, lines)
        local totalParts = #chunks

        for partIdx, desc in ipairs(chunks) do
            local title = "📑 Index Rod Indo HG"
            if totalParts > 1 then
                title = title .. string.format(" (Part %d/%d)", partIdx, totalParts)
            end

            local payload = {
                embeds = {{
                    title       = title,
                    description = desc,
                    color       = 0x5b8def,
                    footer      = { text = os.date("IndoHangout • %Y-%m-%d %H:%M:%S") },
                }}
            }

            postDiscordFavorite(payload)
        end

        notify("IndoHangout", "Index Rod dikirim ke Discord (Webhook 5).", 3)
    end

    sendIndexBtn.MouseButton1Click:Connect(sendRodIndexToDiscord)

    local function hasRodOwned(rodName)
        rodName = tostring(rodName or "")
        if rodName == "" then return false end

        local function checkContainer(container)
            if not container then return false end
            for _, inst in ipairs(container:GetChildren()) do
                if inst:IsA("Tool") and inst.Name == rodName then
                    return true
                end
            end
            return false
        end

        local char = LocalPlayer.Character
        if checkContainer(char) then return true end

        local bp = LocalPlayer:FindFirstChild("Backpack")
        if checkContainer(bp) then return true end

        return false
    end

    local shopScroll = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,150),
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        Parent = shopCard,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Padding       = UDim.new(0,4),
        }),
    })

    for i, item in ipairs(ROD_SHOP_ITEMS) do
        local row = New("Frame", {
            BackgroundColor3 = Color3.fromRGB(244, 246, 255),
            BorderSizePixel  = 0,
            Size             = UDim2.new(1,0,0,24),
            Parent           = shopScroll,
        }, {
            New("UICorner", { CornerRadius = UDim.new(0,6) }),
            New("UIPadding", {
                PaddingLeft  = UDim.new(0,6),
                PaddingRight = UDim.new(0,6),
            }),
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder     = Enum.SortOrder.LayoutOrder,
                Padding       = UDim.new(0,4),
            }),
        })

        New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.07,0,1,0),
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Color3.fromRGB(70,74,110),
            Text = tostring(i)..".",
            Parent = row,
        })

        New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.33,0,1,0),
            Font = Enum.Font.GothamSemibold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Color3.fromRGB(40,44,80),
            Text = item.Name,
            Parent = row,
        })

        local priceValue = getRodPrice(item.Name)
        item.Price      = priceValue
        item.LureSpeed  = getRodLureSpeed(item.Name)

        local priceText = "Price: -"
        if priceValue and type(priceValue) == "number" then
            priceText = "Price: " .. formatRupiah(priceValue)
        end

        New("TextLabel", {
            BackgroundTransparency = 1,
            Size             = UDim2.new(0.30,0,1,0),
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextColor3       = Color3.fromRGB(60,100,60),
            Text             = priceText,
            Parent           = row,
        })

        New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.03,0,1,0),
            Parent = row,
        })

        local buyBtn = makeLittleButton(row, "Beli", 70)
        buyBtn.Size = UDim2.new(0.20,0,1,0)

        local function refreshOwnedUI(forceOwned)
            if forceOwned == true then
                item.Owned = true
            else
                item.Owned = hasRodOwned(item.Name)
            end

            if item.Owned then
                buyBtn.Text = "Owned"
                buyBtn.AutoButtonColor = false
                buyBtn.BackgroundColor3 = Color3.fromRGB(200,205,220)
                buyBtn.TextColor3       = Color3.fromRGB(80,80,100)
            else
                buyBtn.Text = "Beli"
                buyBtn.AutoButtonColor = true
                buyBtn.BackgroundColor3 = Color3.fromRGB(228,232,248)
                buyBtn.TextColor3       = Color3.fromRGB(40,44,70)
            end
        end

        refreshOwnedUI()

        buyBtn.MouseButton1Click:Connect(function()
            if hasRodOwned(item.Name) then
                refreshOwnedUI(true)
                notify("IndoHangout", "Kamu sudah memiliki "..tostring(item.Name).." (Owned).", 2)
                playUISound("UI - Cancel")
                return
            end

            task.spawn(function()
                local args = {
                    [1] = "Buy",
                    [2] = item.Name,
                }
                local ok, res = pcall(function()
                    return RodShopRemoteFunction:InvokeServer(unpack(args))
                end)
                if not ok then
                    warn("[IndoHangout] RodShop Buy error ("..tostring(item.Name).."):", res)
                    notify("IndoHangout", "Gagal membeli "..tostring(item.Name)..". Lihat Output.", 3)
                    playUISound("UI - Cancel")
                else
                    if res then
                        notify("IndoHangout", "Berhasil membeli: "..tostring(item.Name), 2)
                        refreshOwnedUI(true)
                        playUISound("Buy")
                        sendRodBuyWebhook(item, "Sukses")
                    else
                        notify("IndoHangout", "Gagal membeli "..tostring(item.Name)..".", 3)
                        playUISound("UI - Cancel")
                        task.delay(1.5, function()
                            refreshOwnedUI()
                        end)
                    end
                end
            end)
        end)
    end
end

createRodShopCard(body)

------------------- BACKGROUND LOOPS -------------------
task.spawn(function()
    while alive do
        task.wait(10)
        if not alive then break end

        if filterMode ~= 1 then
            for pl,_ in pairs(FriendStates) do
                if pl.Parent == Players then
                    updateFriendCatchFromBackpack(pl)
                end
            end
        end
    end
end)

task.spawn(function()
    while alive do
        task.wait(10)
        if not alive then break end
        syncLocalSnapshotToCurrent()
    end
end)

task.spawn(function()
    while alive do
        task.wait(60)
        if not alive then break end

        if sendListCaughtEnabled then
            sendLocalListCaught(false)

            if filterMode ~= 1 then
                for pl, st in pairs(FriendStates) do
                    if pl.Parent == Players then
                        sendFriendListCaught(pl, st, false)
                    end
                end
            end
        end
    end
end)

------------------- INITIAL SNAPSHOT -------------------
fishCountsSnapshot = scanFishCounts(LocalPlayer)
updateStatsUI()
setReelProgress(0)

------------------------------------------------------------
-- TAB CLEANUP
------------------------------------------------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive           = false
    autoFishing     = false
    isCasting       = false
    webhookEnabled1 = false
    webhookEnabled2 = false
    webhookEnabled3 = false
    webhookEnabled4 = false
    webhookEnabled5 = false
    sendListCaughtEnabled = false
    sessionFishingStart   = nil
    localFirstCatchTime   = nil

    stopReelBar()
    detachReelEvent()
    setReelProgress(0)
end

notify("IndoHangout","TAB Indo HG siap. Auto Fishing + Auto Sell",4)
