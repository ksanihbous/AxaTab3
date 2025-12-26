--==========================================================
--  22AxaTab_WinterQuest.lua
--  TAB 22: "Winter Quest Auto PRO++ (Systematic AutoQuest + Dialog-aware)"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame  = TAB_FRAME
local tabId  = TAB_ID or "winterquest"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = HttpService       or game:GetService("HttpService")
local UserInputService  = UserInputService  or game:GetService("UserInputService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if not (frame and LocalPlayer) then return end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- REMOTES -------------------
local EventsFolder         = ReplicatedStorage:FindFirstChild("Events")
local RemoteFunctionFolder = EventsFolder and EventsFolder:FindFirstChild("RemoteFunction")
local RemoteEventFolder    = EventsFolder and EventsFolder:FindFirstChild("RemoteEvent")

local WinterRemoteFunction   = RemoteFunctionFolder and RemoteFunctionFolder:FindFirstChild("WinterEvent")
local SellFishRemoteFunction = RemoteFunctionFolder and RemoteFunctionFolder:FindFirstChild("SellFish")
local RodRemoteEvent         = RemoteEventFolder    and RemoteEventFolder:FindFirstChild("Rod")

if not WinterRemoteFunction then
    warn("[22AxaTab_WinterQuest] RemoteFunction.Events.WinterEvent tidak ditemukan.")
end
if not SellFishRemoteFunction then
    warn("[22AxaTab_WinterQuest] RemoteFunction.Events.SellFish tidak ditemukan.")
end
if not RodRemoteEvent then
    warn("[22AxaTab_WinterQuest] RemoteEvent.Events.Rod tidak ditemukan (auto fishing spot terbatas).")
end

------------------- DISCORD WEBHOOK CONFIG (Winter Quest) -------------------
local WINTER_WEBHOOK_URL     = "https://discord.com/api/webhooks/1450056625753821235/yq-X8WY279wYMsqmgVxTB318-q9pEq2_2LDUsQMNYZxURazPShS29RBx_KUXyQEa--iV"
local WINTER_WEBHOOK_NAME    = "Winter Quest Notifier"
local WINTER_WEBHOOK_AVATAR  = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png"
local DEFAULT_OWNER_DISCORD = "<@1403052152691101857>"
local WINTER_WEBHOOK_ENABLED = true

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
            Title    = title or "Winter Quest",
            Text     = text or "",
            Duration = dur or 3,
        })
    end)
end

local function makeLabel(parent, text, size, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size      = size or UDim2.new(1,0,0,18)
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
        Name             = "Card",
        BackgroundColor3 = Color3.fromRGB(236, 238, 248),
        BorderSizePixel  = 0,
        Size             = UDim2.new(1,0,0,80),
        AutomaticSize    = Enum.AutomaticSize.Y,
        LayoutOrder      = order or 10,
        Parent           = parent,
    }, {
        New("UICorner", { CornerRadius = UDim.new(0,12) }),
        New("UIStroke", {
            Thickness    = 1,
            Color        = Color3.fromRGB(210,212,230),
            Transparency = 0.3,
        }),
        New("UIPadding", {
            PaddingTop    = UDim.new(0,8),
            PaddingBottom = UDim.new(0,8),
            PaddingLeft   = UDim.new(0,8),
            PaddingRight  = UDim.new(0,8),
        }),
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Padding       = UDim.new(0,4),
        })
    })
    return card
end

local function makeLittleButton(parent, text)
    return New("TextButton", {
        Size             = UDim2.new(0, 110, 0, 26),
        BackgroundColor3 = Color3.fromRGB(228,232,248),
        BorderSizePixel  = 0,
        AutoButtonColor  = true,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextColor3       = Color3.fromRGB(40,44,70),
        Text             = text or "Button",
        Parent           = parent,
    }, {
        New("UICorner", { CornerRadius = UDim.new(0,8) })
    })
end

------------------- STATE -------------------
local alive                = true
local autoQuest            = false
local autoQuestLoopRunning = false
local infoAutoLoopRunning  = false

-- AutoFishing: dipisah Quest vs Farm
local autoFishingQuest           = false   -- default nanti ON di bawah
local autoFishingFarm            = false   -- default OFF
local autoFishingLoopRunning     = false
local autoFishingCasting         = false
local autoFishingReelConn        = nil
local autoFishingRodEventConn    = nil
local autoFishingQuestDelayUntil = 0       -- waktu minimal (os.clock) AutoFishing Quest boleh mulai lempar

local questState = {
    lastRaw           = nil,
    lastDialog        = "-",
    give              = false,
    fishKey           = nil,
    fishKeyNormalized = nil,
    mode              = "other",
    lastUpdated       = 0,

    tokens            = 0,
    lastToken         = 0,

    sellTarget        = nil,
    sellSoldTotal     = 0,

    obtainActive      = false,
    obtainRemaining   = nil,
    obtainHandled     = false,

    fishingInitDone   = false,

    _lastFinishedHash = nil,
}

-- UI refs
local questInfoLabel
local questDetailLabel
local autoQuestBtn
local autoFishingQuestBtn
local autoFishingFarmBtn
local statusLabel
local logLabel
local tokenLabel

-- LOG STATE
local logLines = {}
local lastLogPayload = nil

local function pushLog(msg)
    msg = tostring(msg or "")
    if msg == lastLogPayload then
        return
    end
    lastLogPayload = msg

    local ts = os.date("%H:%M:%S")
    local entry = "["..ts.."] "..msg
    table.insert(logLines, 1, entry)
    if #logLines > 40 then
        table.remove(logLines, #logLines)
    end
    if logLabel then
        logLabel.Text = table.concat(logLines, "\n")
    end
end

------------------- DISCORD WEBHOOK HELPERS -------------------
local function getExecutorHttpRequest()
    local req =
        (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
        or (krnl and krnl.request)

    if type(req) == "function" then
        return req
    end
    return nil
end

local function sendDiscordWebhook(url, payload)
    if not url or url == "" then
        return false, "URL kosong"
    end

    local helper = rawget(_G, "httpRequestDiscord")
    if type(helper) == "function" then
        local ok, err = helper(url, payload)
        return ok, err
    end

    local reqFunc = getExecutorHttpRequest()
    if not reqFunc then
        return false, "Executor HTTP request function tidak tersedia"
    end

    local encoded
    local okEncode, errEncode = pcall(function()
        encoded = HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "JSONEncode error: "..tostring(errEncode)
    end

    local okReq, res = pcall(function()
        return reqFunc({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = encoded,
        })
    end)

    if not okReq then
        return false, "Executor request error: "..tostring(res)
    end

    local status = res and (res.StatusCode or res.Status) or nil
    if status and status ~= 200 and status ~= 204 then
        return false, "HTTP status "..tostring(status)
    end

    return true
end

local function buildWinterEmbed(color, title, description, fields)
    local embed = {
        title       = title,
        description = description,
        color       = color,
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer      = { text = "Winter Quest Auto PRO++" },
        fields      = {},
    }
    if fields then
        for _, f in ipairs(fields) do
            table.insert(embed.fields, f)
        end
    end
    return embed
end

local function getProgressSummaryFromDialog(dialog)
    if type(dialog) ~= "string" then
        return "- (tidak ada info progress)"
    end

    local lower = dialog:lower()

    if lower:find("dapatkan", 1, true) and lower:find("ikan", 1, true) then
        local numStr = lower:match("dapatkan%s+(%d+)%s+ikan")
                     or lower:match("dapatkan%s+(%d+)")
        local remain = tonumber(numStr)
        if remain then
            return string.format("Dapatkan (%d ikan lagi)", remain)
        else
            return "Dapatkan (jumlah tidak terdeteksi)"
        end
    end

    if lower:find("jual", 1, true) and lower:find("ikan", 1, true) and lower:find("lagi", 1, true) then
        local numStr = lower:match("jual%s+(%d+)%s+ikan")
                     or lower:match("jual%s+(%d+)")
        local remain = tonumber(numStr)
        if remain then
            return string.format("Jual (%d ikan lagi)", remain)
        else
            return "Jual (jumlah tidak terdeteksi)"
        end
    end

    if lower:find("berikan", 1, true) and lower:find("ikan", 1, true) and lower:find("lagi", 1, true) then
        local numStr = lower:match("berikan%s+(%d+)%s+ikan")
                     or lower:match("berikan%s+(%d+)")
        local remain = tonumber(numStr)
        if remain then
            return string.format("Berikan (%d ikan lagi)", remain)
        else
            return "Berikan (jumlah tidak terdeteksi)"
        end
    end

    return "- (tidak ada pola 'lagi')"
end

local function sendWinterWebhook(kind, context, extra)
    if not WINTER_WEBHOOK_ENABLED then
        return
    end
    if not WINTER_WEBHOOK_URL or WINTER_WEBHOOK_URL == "" then
        return
    end

    extra = extra or {}

    local playerName  = LocalPlayer and LocalPlayer.Name or "Unknown"
    local displayName = LocalPlayer and LocalPlayer.DisplayName or playerName
    local userId      = LocalPlayer and LocalPlayer.UserId or 0

    local color, title
    if kind == "before_new" then
        color = 0x3498DB
        title = "❄ Winter Quest Sukses ❄"
    elseif kind == "finished" then
        color = 0x2ECC71
        title = "❄ Winter Quest Sukses"
    elseif kind == "new_quest" then
        color = 0x9B59B6
        title = "❄ Winter Quest Info — Quest Baru Diambil"
    elseif kind == "info" then
        color = 0x5B8DEF
        title = "❄ Winter Quest Info"
    else
        color = 0x95A5A6
        title = "Winter Quest - Info"
    end

    local descParts = {}
    table.insert(descParts, string.format("**Player:** %s (`%s`, %d)", tostring(displayName), tostring(playerName), tonumber(userId) or 0))
    if context then
        table.insert(descParts, string.format("**Context:** %s", tostring(context)))
    end
    if extra.note then
        table.insert(descParts, tostring(extra.note))
    end
    local description = table.concat(descParts, "\n")

    local fields = {}

    table.insert(fields, {
        name   = "Mode / Give",
        value  = string.format("`mode = %s`, `give = %s`", tostring(questState.mode), questState.give and "true" or "false"),
        inline = true,
    })

    table.insert(fields, {
        name   = "Fish Target",
        value  = string.format("`%s` (norm: `%s`)", tostring(questState.fishKey or "-"), tostring(questState.fishKeyNormalized or "-")),
        inline = true,
    })

    if questState.tokens ~= nil then
        table.insert(fields, {
            name   = "Tokens",
            value  = string.format("`%s` (last: `%s`)", tostring(questState.tokens), tostring(questState.lastToken)),
            inline = true,
        })
    end

    if questState.sellTarget then
        table.insert(fields, {
            name   = "Sell Target",
            value  = string.format("Target: %d, Terjual: %d", questState.sellTarget or 0, questState.sellSoldTotal or 0),
            inline = true,
        })
    end

    if questState.obtainActive then
        local remain = questState.obtainRemaining
        local txt = remain and string.format("Masih %d ikan lagi", remain) or "Aktif (jumlah tidak terdeteksi)"
        table.insert(fields, {
            name   = "Obtain Info",
            value  = txt,
            inline = true,
        })
    end

    table.insert(fields, {
        name   = "Progress Dialog",
        value  = getProgressSummaryFromDialog(questState.lastDialog),
        inline = false,
    })

    local dlg = questState.lastDialog or "-"
    if #dlg > 500 then
        dlg = dlg:sub(1,497).."..."
    end
    table.insert(fields, {
        name   = "Dialog",
        value  = dlg,
        inline = false,
    })

    if extra.extraFieldName and extra.extraFieldValue then
        table.insert(fields, {
            name   = tostring(extra.extraFieldName),
            value  = tostring(extra.extraFieldValue),
            inline = false,
        })
    end

    local payload = {
        username   = WINTER_WEBHOOK_NAME,
        avatar_url = WINTER_WEBHOOK_AVATAR,
        content    = DEFAULT_OWNER_DISCORD,
        embeds     = {
            buildWinterEmbed(color, title, description, fields)
        }
    }

    local ok, err = sendDiscordWebhook(WINTER_WEBHOOK_URL, payload)
    if not ok then
        pushLog("[WinterWebhook] Gagal kirim ("..tostring(kind).."): "..tostring(err))
    else
        pushLog("[WinterWebhook] Terkirim ("..tostring(kind)..") ke Discord ("..(context or "no-context")..").")
    end
end

local function sendWinterInfoSnapshot(context, statusText)
    sendWinterWebhook("info", context or "Info", {
        note            = statusText or "Winter Quest Info Snapshot",
        extraFieldName  = "Status",
        extraFieldValue = statusText or "Info",
    })
end

------------------- FISHING SPOT (OTHER/FISHING MODE) -------------------
local FISHING_SPOT = {
    position = Vector3.new(-368.31, 113.40, -271.59),
    lookAt   = Vector3.new(-367.80, 113.40, -281.58),
}

local fishingThrowInProgress = false -- slot kalau nanti ingin dipakai lagi
local lastRodTool            = nil   -- cache Rod terakhir yang valid

-- Helper: nama Tool yang benar-benar Rod (tidak kena 'swordfish')
local function isRodToolName(name)
    if not name then return false end
    local n = tostring(name):lower()

    -- nama-nama umum Rod
    if n == "rod" then return true end
    if n:find("wave rod", 1, true) then return true end
    if n:find("piranha rod", 1, true) then return true end
    --if n:find("basic rod", 1, true) then return true end
    if n:find("vip rod", 1, true) then return true end
    if n:find("gopay rod", 1, true) then return true end

    -- pola " rod" (spasi di depan) atau "rod " (spasi di belakang) atau di akhir kata
    if n:find(" rod", 1, true) then return true end
    if n:find("rod ", 1, true) then return true end
    if n:sub(-3) == "rod" then return true end

    -- hindari 'swordfish', 'android', dll (ada 'rod' di tengah tanpa spasi)
    return false
end

local function isRodToolInstance(tool)
    return tool and tool:IsA("Tool") and isRodToolName(tool.Name)
end

-- Cari Rod di Character/Backpack, dengan prioritas:
-- 1) Wave Rod di Character
-- 2) Rod lain di Character
-- 3) Wave Rod di Backpack
-- 4) Rod lain di Backpack
-- 5) lastRodTool kalau masih valid
local function findRodToolForFishing()
    local char = LocalPlayer.Character
    if char then
        local wave = char:FindFirstChild("Wave Rod")
        if isRodToolInstance(wave) then
            lastRodTool = wave
            return wave
        end
        for _, c in ipairs(char:GetChildren()) do
            if isRodToolInstance(c) then
                lastRodTool = c
                return c
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local wave = backpack:FindFirstChild("Wave Rod")
        if isRodToolInstance(wave) then
            lastRodTool = wave
            return wave
        end
        for _, c in ipairs(backpack:GetChildren()) do
            if isRodToolInstance(c) then
                lastRodTool = c
                return c
            end
        end
    end

    if lastRodTool and lastRodTool.Parent and isRodToolInstance(lastRodTool) then
        return lastRodTool
    end

    return nil
end

-- Pastikan karakter memegang Rod:
-- - Kalau sudah pegang Rod: pakai itu
-- - Kalau belum: cari di Character/Backpack, lalu Equip
local function ensureRodEquipped()
    local char = LocalPlayer.Character
    if not char then
        return nil, "Character belum siap."
    end

    -- cek dulu Rod di tangan
    for _, inst in ipairs(char:GetChildren()) do
        if isRodToolInstance(inst) then
            lastRodTool = inst
            return inst
        end
    end

    -- belum pegang Rod, cari & equip
    local rod = findRodToolForFishing()
    if not rod then
        return nil, "Rod tidak ditemukan di Character/Backpack."
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:EquipTool(rod)
    else
        rod.Parent = char
    end

    lastRodTool = rod
    return rod
end

local function teleportToFishingSpot()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not (hrp and FISHING_SPOT and FISHING_SPOT.position) then
        return false
    end

    local pos  = FISHING_SPOT.position
    local look = FISHING_SPOT.lookAt or (pos + Vector3.new(0, 0, -10))
    hrp.CFrame = CFrame.new(pos, look)
    pushLog(string.format("AutoQuest Fishing: Teleport ke fishing spot (%.1f, %.1f, %.1f).", pos.X, pos.Y, pos.Z))

    -- Segera usahakan memegang Rod (sigap)
    task.delay(0.2, function()
        if alive then
            local rod, err = ensureRodEquipped()
            if rod then
                pushLog("AutoQuest Fishing: Rod siap di tangan setelah teleport ("..tostring(rod.Name)..").")
            else
                pushLog("AutoQuest Fishing: gagal equip Rod setelah teleport: "..tostring(err))
            end
        end
    end)

    -- Delay AutoFishing Quest 2 detik setelah teleport (hanya untuk Quest)
    if autoFishingQuest then
        autoFishingQuestDelayUntil = os.clock() + 2
        pushLog("AutoFishing Quest: akan mulai 2 detik setelah teleport ke fishing spot.")
    end

    return true
end

------------------- QUEST HELPERS -------------------
local function callWinter(action)
    if not WinterRemoteFunction then
        return nil, "Remote WinterEvent tidak ditemukan."
    end

    local args = { [1] = action }
    local ok, res = pcall(function()
        return WinterRemoteFunction:InvokeServer(unpack(args))
    end)
    if not ok then
        return nil, "Invoke "..tostring(action).." error: "..tostring(res)
    end
    return res
end

local function extractDialog(res)
    if type(res) == "table" then
        return res.dialog or res.Dialog or res.text or res.Text or "-"
    end
    if res == nil then return "-" end
    return tostring(res)
end

local function extractGiveFlag(res)
    if type(res) ~= "table" then return false end
    local v = res.give or res.Give or res.GIVE
    return v and true or false
end

local function normalizeFishName(name)
    if not name then return nil end
    local lower = tostring(name):lower()
    lower = lower:gsub("%b()", " ")
    lower = lower:gsub("favorites", " ")
    lower = lower:gsub("favorite", " ")
    lower = lower:gsub("%d+%s*kg", " ")
    lower = lower:gsub("[^%a%s]", " ")
    lower = lower:gsub("%s+", " ")
    lower = lower:match("^%s*(.-)%s*$")
    return lower
end

local function parseFishKeyFromDialog(dialog)
    if type(dialog) ~= "string" then return nil end
    local lower = dialog:lower()
    local after = lower:match("ikan%s+([%a%s%(%)-]+)") or lower:match("ikan%s+([%a%s%-]+)")
    if not after then
        return nil
    end

    local raw = "ikan "..after
    raw = raw:gsub("lagi", " ")
    raw = raw:gsub("%s+", " ")
    raw = raw:match("^%s*(.-)%s*$")
    if raw == "" then
        return nil
    end
    return raw
end

local function detectModeFromDialog(giveFlag, dialog)
    if type(dialog) ~= "string" then
        return giveFlag and "give" or "other"
    end
    local lower = dialog:lower()

    if giveFlag then
        return "give"
    end

    if lower:find("berikan", 1, true) or lower:find("pegang ikan", 1, true) then
        return "give"
    end

    if lower:find("jual", 1, true) or lower:find("sell", 1, true) then
        return "sell"
    end

    return "other"
end

local function parseSellTargetFromDialog(dialog)
    if type(dialog) ~= "string" then return nil end
    local lower = dialog:lower()

    if not (lower:find("jual", 1, true) or lower:find("sell", 1, true)) then
        return nil
    end

    local numStr = lower:match("jual%s+(%d+)")
                 or lower:match("sell%s+(%d+)")
    if not numStr then
        numStr = lower:match("(%d+)")
    end
    local n = tonumber(numStr)
    return n
end

local function updateQuestUI()
    if questInfoLabel then
        questInfoLabel.Text = string.format(
            "Quest Info: give = %s | mode = %s",
            questState.give and "true" or "false",
            questState.mode
        )
    end

    if questDetailLabel then
        local fishKeyText = questState.fishKey and ("Target Ikan: "..questState.fishKey) or "Target Ikan: (belum terdeteksi)"
        local sellInfo = ""
        if questState.sellTarget then
            sellInfo = string.format(" | Target Jual: %d (script tidak akan melewati ini)", questState.sellTarget)
        end

        questDetailLabel.Text = string.format(
            "%s%s\nDialog: %s",
            fishKeyText,
            sellInfo,
            tostring(questState.lastDialog or "-")
        )
    end

    if tokenLabel then
        tokenLabel.Text = "Token: "..tostring(questState.tokens or 0)
    end
end

------------------- TOKEN HANDLING -------------------
local function extractTokenValue(res)
    if type(res) == "number" then
        return res
    elseif type(res) == "string" then
        local n = tonumber(res)
        if n then return n end
    end

    if type(res) ~= "table" then
        return nil
    end

    local candidate
    local function scanTokenKeys(tbl)
        for k, v in pairs(tbl) do
            if type(k) == "string" and k:lower():find("token") then
                local n = (type(v) == "number") and v or tonumber(v)
                if n then
                    candidate = n
                end
            end
            if type(v) == "table" then
                scanTokenKeys(v)
            end
        end
    end
    scanTokenKeys(res)
    if candidate ~= nil then
        return candidate
    end

    local maxNum
    local function scanNumbers(tbl)
        for _, v in pairs(tbl) do
            if type(v) == "number" then
                maxNum = maxNum and math.max(maxNum, v) or v
            elseif type(v) == "string" then
                local n = tonumber(v)
                if n then
                    maxNum = maxNum and math.max(maxNum, n) or n
                end
            elseif type(v) == "table" then
                scanNumbers(v)
            end
        end
    end
    scanNumbers(res)

    return maxNum
end

local function applyTokenResult(res, sourceTag)
    if not res then return end

    local rawStr
    if type(res) == "table" then
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(res)
        end)
        rawStr = ok and encoded or tostring(res)
    else
        rawStr = tostring(res)
    end
    pushLog(string.format("%s | GetToken raw: %s", sourceTag or "GetToken", rawStr))

    local old = questState.tokens or 0
    local new = extractTokenValue(res)

    if not new then
        pushLog(string.format("%s | Token tidak terbaca, pakai nilai lama (%d).", sourceTag or "GetToken", old))
        updateQuestUI()
        return
    end

    questState.lastToken = old
    questState.tokens    = new
    updateQuestUI()

    local diff = new - old
    if diff > 0 then
        pushLog(string.format("%s | Token: %d → %d ( +%d )", sourceTag or "GetToken", old, new, diff))
    elseif diff < 0 then
        pushLog(string.format("%s | Token: %d → %d (↓%d)", sourceTag or "GetToken", old, new, -diff))
    else
        pushLog(string.format("%s | Token tetap: %d", sourceTag or "GetToken", new))
    end
end

-- silent = true → tanpa notifikasi (untuk flow otomatis, biar tidak spam)
local function updateTokenFromServer(sourceTag, silent)
    local res, err = callWinter("GetToken")
    if not res and err then
        pushLog((sourceTag or "GetToken").." error: "..tostring(err))
        if not silent then
            notify("Winter Quest","GetToken gagal, lihat Output.",3)
        end
        return
    end

    applyTokenResult(res, sourceTag or "GetToken")

    if not silent then
        notify("Winter Quest","Token diperbarui: "..tostring(questState.tokens), 2)
    end
end

------------------- SCAN / EQUIP IKAN -------------------
local function iterLocalTools()
    local list = {}

    local char = LocalPlayer.Character
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") then
                table.insert(list, c)
            end
        end
    end

    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, c in ipairs(bp:GetChildren()) do
            if c:IsA("Tool") then
                table.insert(list, c)
            end
        end
    end

    return list
end

local function getEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then
            return c
        end
    end
    return nil
end

local function isFavoriteToolName(name)
    local lower = string.lower(name or "")
    return lower:find("favorite", 1, true) ~= nil
end

local function isFavoriteTool(tool)
    if not tool then return false end
    return isFavoriteToolName(tool.Name)
end

local function findQuestFishTool(options)
    options = options or {}
    local skipFavorite = options.skipFavorite and true or false

    local tools = iterLocalTools()
    if #tools == 0 then
        return nil
    end

    local fishKeyNorm = questState.fishKeyNormalized

    if fishKeyNorm and fishKeyNorm ~= "" then
        -- exact
        for _, tool in ipairs(tools) do
            if not (skipFavorite and isFavoriteTool(tool)) then
                local nNorm = normalizeFishName(tool.Name or "")
                if nNorm == fishKeyNorm then
                    pushLog("findQuestFishTool: match exact '"..tool.Name.."' (norm='"..tostring(nNorm).."')."
                        ..(skipFavorite and " [skipFavorite]" or ""))
                    return tool
                end
            end
        end
        -- partial
        for _, tool in ipairs(tools) do
            if not (skipFavorite and isFavoriteTool(tool)) then
                local nNorm = normalizeFishName(tool.Name or "")
                if nNorm and nNorm:find(fishKeyNorm, 1, true) then
                    pushLog("findQuestFishTool: match partial '"..tool.Name.."' (norm='"..tostring(nNorm).."', contains '"..fishKeyNorm.."')."
                        ..(skipFavorite and " [skipFavorite]" or ""))
                    return tool
                end
            end
        end
    end

    -- fallback: ikan apapun
    for _, tool in ipairs(tools) do
        if not (skipFavorite and isFavoriteTool(tool)) then
            local nNorm = normalizeFishName(tool.Name or "")
            if nNorm and nNorm:find("ikan ", 1, true) then
                pushLog("findQuestFishTool: fallback ikan '"..tool.Name.."' (norm='"..tostring(nNorm).."')."
                    ..(skipFavorite and " [skipFavorite]" or ""))
                return tool
            end
        end
    end

    if skipFavorite then
        for _, tool in ipairs(tools) do
            if not isFavoriteTool(tool) then
                pushLog("findQuestFishTool: fallback pertama non-favorite '"..tool.Name.."'. [skipFavorite]")
                return tool
            end
        end
        pushLog("findQuestFishTool: semua tool favorite, tidak ada yang dipilih (skipFavorite).")
        return nil
    else
        pushLog("findQuestFishTool: fallback ke tool pertama '"..tools[1].Name.."'.")
        return tools[1]
    end
end

local function equipTool(tool, targetFishNorm)
    if not tool then
        return false, "Tool quest tidak ditemukan."
    end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid:EquipTool(tool)
    else
        tool.Parent = char
    end

    task.wait(isMobile and 0.25 or 0.2)

    local equipped = getEquippedTool()
    if not equipped then
        return false, "Setelah EquipTool tidak ada tool yang dipegang."
    end

    if targetFishNorm and targetFishNorm ~= "" then
        local eqNorm = normalizeFishName(equipped.Name or "")
        if not eqNorm then
            return false, "Nama tool ter-equip tidak bisa dinormalisasi."
        end

        if eqNorm ~= targetFishNorm and not eqNorm:find(targetFishNorm, 1, true) then
            pushLog(string.format(
                "EquipTool: terpegang '%s' (norm='%s') != target '%s'.",
                tostring(equipped.Name),
                tostring(eqNorm),
                tostring(targetFishNorm)
            ))
            return false, "Tool yang dipegang bukan ikan quest."
        end
    end

    pushLog("EquipTool: sekarang memegang '"..tostring(equipped.Name).."' (match ikan quest).")
    return true
end

------------------- ENDQUEST (GIVE IKAN, SKIP FAVORITE) -------------------
local function doEndQuestRaw()
    local res, err = callWinter("EndQuest")
    if not res and err then
        pushLog("EndQuest error: "..tostring(err))
        return nil, err
    end
    return res
end

local function giveQuestFishOnce()
    if questState.mode ~= "give" then
        return false, "Mode quest bukan 'give'."
    end

    local targetNorm = questState.fishKeyNormalized

    local equipped = getEquippedTool()
    if equipped then
        if isFavoriteTool(equipped) then
            pushLog("Give: tool yang sedang dipegang adalah (Favorite), di-skip untuk GIVE: "..tostring(equipped.Name))
            equipped = nil
        elseif targetNorm and targetNorm ~= "" then
            local eqNorm = normalizeFishName(equipped.Name or "")
            if eqNorm == targetNorm or (eqNorm and eqNorm:find(targetNorm, 1, true)) then
                pushLog("Give: sudah memegang ikan quest NON-FAVORITE: "..tostring(equipped.Name))
            else
                equipped = nil
            end
        end
    end

    local tool = equipped or findQuestFishTool({ skipFavorite = true })
    if not tool then
        return false, "Ikan quest non-favorite tidak ditemukan (semua yang cocok mungkin Favorite)."
    end

    local okEquip, equipErr = equipTool(tool, targetNorm)
    if not okEquip then
        return false, equipErr
    end

    local res, err = doEndQuestRaw()
    if not res and err then
        return false, err
    end

    return true
end

local function runEndQuestGiveLoop(maxSteps, fromTag, respectAutoFlag)
    maxSteps        = maxSteps or 50
    fromTag         = fromTag or "GiveLoop"
    respectAutoFlag = respectAutoFlag and true or false

    if questState.mode ~= "give" then
        pushLog(fromTag..": mode quest bukan give, batal.")
        return
    end

    pushLog(fromTag..": mulai serah ikan (give) max "..maxSteps.."x, SKIP (Favorite).")

    for _ = 1, maxSteps do
        if not alive then break end
        if respectAutoFlag and not autoQuest then
            pushLog(fromTag..": AutoQuest OFF, stop GIVE loop.")
            break
        end
        if questState.mode ~= "give" then
            break
        end

        local ok, err = giveQuestFishOnce()
        if not ok then
            pushLog(fromTag..": gagal serah ikan: "..tostring(err))
            break
        end

        local totalWait = 0.4
        local step = 0.1
        local t = 0
        while t < totalWait do
            if not alive then break end
            if respectAutoFlag and not autoQuest then break end
            task.wait(step)
            t = t + step
        end
        if not alive then break end
        if respectAutoFlag and not autoQuest then
            pushLog(fromTag..": AutoQuest OFF saat delay GIVE, stop.")
            break
        end

        local info, err2 = callWinter("GetQuestInfo")
        if not info and err2 then
            pushLog(fromTag..": GetQuestInfo error: "..tostring(err2))
            break
        end

        local tag = fromTag.." → GetQuestInfo"
        local okApply, errApply = pcall(function()
            applyQuestInfo(info, tag, false)
        end)
        if not okApply then
            pushLog(fromTag..": error applyQuestInfo: "..tostring(errApply))
            break
        end

        if questState.mode ~= "give" then
            break
        end
    end

    if questState.mode == "give" then
        pushLog(fromTag..": masih mode give (mungkin ikan non-favorite di backpack sudah habis).")
    else
        pushLog(fromTag..": selesai fase give (quest lanjut fase lain / mungkin selesai).")
    end
end

------------------- SELLFISH -------------------
local function callSellFish()
    if not SellFishRemoteFunction then
        return nil, "Remote SellFish tidak ditemukan."
    end

    local args = {
        [1] = "SellFish",
        [2] = "Sell this fish",
    }

    local ok, res = pcall(function()
        return SellFishRemoteFunction:InvokeServer(unpack(args))
    end)
    if not ok then
        return nil, "Invoke SellFish error: "..tostring(res)
    end
    return res
end

local function sellQuestFishOnce()
    if questState.mode ~= "sell" then
        return false, "Mode quest bukan 'sell'."
    end

    if questState.sellTarget and questState.sellSoldTotal >= questState.sellTarget then
        return false, string.format(
            "Target jual sudah tercapai (%d ikan). Script tidak akan jual lebih banyak.",
            questState.sellTarget
        )
    end

    local targetNorm = questState.fishKeyNormalized

    local equipped = getEquippedTool()
    if equipped then
        if isFavoriteTool(equipped) then
            pushLog("Sell: tool yang sedang dipegang adalah (Favorite), di-skip untuk SELL: "..tostring(equipped.Name))
            equipped = nil
        elseif targetNorm and targetNorm ~= "" then
            local eqNorm = normalizeFishName(equipped.Name or "")
            if eqNorm == targetNorm or (eqNorm and eqNorm:find(targetNorm, 1, true)) then
                pushLog("Sell: sudah memegang ikan quest (non-favorite): "..tostring(equipped.Name))
            else
                equipped = nil
            end
        end
    end

    local tool = equipped or findQuestFishTool({ skipFavorite = true })
    if not tool then
        return false, "Ikan quest non-favorite tidak ditemukan (semua yang cocok mungkin Favorite)."
    end

    local okEquip, equipErr = equipTool(tool, targetNorm)
    if not okEquip then
        return false, equipErr
    end

    local res, err = callSellFish()
    if not res and err then
        return false, err
    end

    if questState.sellTarget then
        questState.sellSoldTotal = (questState.sellSoldTotal or 0) + 1
        pushLog(string.format(
            "SellQuest: terjual %d/%d ikan quest (script akan stop saat mencapai target).",
            questState.sellSoldTotal,
            questState.sellTarget
        ))
    end

    return true
end

local function runSellLoop(maxSteps, fromTag, respectAutoFlag)
    maxSteps        = maxSteps or 50
    fromTag         = fromTag or "SellLoop"
    respectAutoFlag = respectAutoFlag and true or false

    if questState.mode ~= "sell" then
        pushLog(fromTag..": mode quest bukan sell, batal.")
        return
    end

    pushLog(fromTag..": mulai jual ikan (sell) max "..maxSteps.."x (skip Favorite, patuh jumlah dialog).")

    for _ = 1, maxSteps do
        if not alive then break end
        if respectAutoFlag and not autoQuest then
            pushLog(fromTag..": AutoQuest OFF, stop SELL loop.")
            break
        end
        if questState.mode ~= "sell" then
            break
        end

        if questState.sellTarget and questState.sellSoldTotal >= questState.sellTarget then
            pushLog(fromTag..": target jual tercapai ("..tostring(questState.sellTarget).." ikan), stop loop SELL.")
            break
        end

        local ok, err = sellQuestFishOnce()
        if not ok then
            pushLog(fromTag..": gagal jual ikan: "..tostring(err))
            break
        end

        local totalWait = 0.4
        local step = 0.1
        local t = 0
        while t < totalWait do
            if not alive then break end
            if respectAutoFlag and not autoQuest then break end
            if questState.sellTarget and questState.sellSoldTotal >= questState.sellTarget then
                break
            end
            task.wait(step)
            t = t + step
        end
        if not alive then break end
        if respectAutoFlag and not autoQuest then
            pushLog(fromTag..": AutoQuest OFF saat delay SELL, stop.")
            break
        end
        if questState.sellTarget and questState.sellSoldTotal >= questState.sellTarget then
            pushLog(fromTag..": target jual tercapai ("..tostring(questState.sellTarget).." ikan) saat delay, stop SELL.")
            break
        end

        local info, err2 = callWinter("GetQuestInfo")
        if not info and err2 then
            pushLog(fromTag..": GetQuestInfo error: "..tostring(err2))
            break
        end

        local tag = fromTag.." → GetQuestInfo"
        local okApply, errApply = pcall(function()
            applyQuestInfo(info, tag, false)
        end)
        if not okApply then
            pushLog(fromTag..": error applyQuestInfo: "..tostring(errApply))
            break
        end

        if questState.mode ~= "sell" then
            break
        end
    end

    if questState.sellTarget and questState.sellSoldTotal >= questState.sellTarget then
        pushLog(fromTag..": selesai SELL karena target dialog tercapai ("..tostring(questState.sellTarget).." ikan). Script tidak jual lebih dari itu.")
    elseif questState.mode == "sell" then
        pushLog(fromTag..": masih mode sell (kemungkinan ikan non-favorite kurang / habis).")
    else
        pushLog(fromTag..": selesai fase sell (quest lanjut fase lain / mungkin selesai).")
    end
end

------------------- QUEST SELESAI (TERIMAKASIH) - MANUAL FLOW -------------------
local function isQuestFinished()
    local dialog = questState.lastDialog
    if type(dialog) ~= "string" then
        return false
    end
    local lower = dialog:lower()
    if lower:find("terimakasih", 1, true) or lower:find("terima kasih", 1, true) then
        return true
    end
    return false
end

local function refreshQuestIfFinished(sourceTag)
    if not isQuestFinished() then
        return
    end

    sourceTag = sourceTag or "QuestFinish"

    if autoQuest then
        pushLog(sourceTag..": dialog selesai (Terimakasih) terdeteksi, tetapi AutoQuest ON. Flow AutoQuest yang akan handle.")
        return
    end

    pushLog(sourceTag..": dialog terdeteksi selesai (Terimakasih). Panggil EndQuest → GetQuest → GetQuestInfo (manual).")

    local resEnd, errEnd = doEndQuestRaw()
    if not resEnd and errEnd then
        pushLog(sourceTag..": EndQuest error: "..tostring(errEnd))
        return
    end

    -- Setelah EndQuest manual sukses, segarkan token sekali (silent)
    updateTokenFromServer(sourceTag.." → RefreshQuestIfFinished → GetToken", true)

    sendWinterWebhook("before_new", sourceTag.." → RefreshQuestIfFinished", {
        note            = "Quest sebelumnya selesai (dialog Terimakasih). Script akan memanggil GetQuest untuk quest baru (manual / AutoQuest OFF).",
        extraFieldName  = "Status",
        extraFieldValue = "Sebelum ambil quest baru (manual).",
    })

    local res, err = callWinter("GetQuest")
    if not res and err then
        pushLog(sourceTag..": GetQuest (quest baru) error: "..tostring(err))
        return
    end
    pushLog(sourceTag..": GetQuest OK (quest baru diambil).")

    local info, err2 = callWinter("GetQuestInfo")
    if info then
        applyQuestInfo(info, sourceTag.." → GetQuestInfo (Quest Baru)", true)
    elseif err2 then
        pushLog(sourceTag..": GetQuestInfo (Quest Baru) error: "..tostring(err2))
    end
end

------------------- APPLY QUEST INFO + OBTAIN/FISHING -------------------
function applyQuestInfo(res, sourceTag, isNewQuest)
    if res == nil then
        return
    end

    isNewQuest = isNewQuest and true or false

    local prevMode = questState.mode

    questState.lastRaw    = res
    questState.lastDialog = extractDialog(res)
    questState.give       = extractGiveFlag(res)
    questState.fishKey    = parseFishKeyFromDialog(questState.lastDialog)
    questState.fishKeyNormalized = questState.fishKey and normalizeFishName(questState.fishKey) or nil
    questState.mode       = detectModeFromDialog(questState.give, questState.lastDialog)
    questState.lastUpdated= os.time()

    -- SELL LIMIT
    if questState.mode == "sell" then
        if isNewQuest or not questState.sellTarget or prevMode ~= "sell" then
            local target = parseSellTargetFromDialog(questState.lastDialog)
            if target then
                questState.sellTarget    = target
                questState.sellSoldTotal = 0
                pushLog(string.format(
                    "INIT SellTarget: script hanya akan menjual maks %d ikan untuk quest SELL ini (manual + auto).",
                    target
                ))
            else
                questState.sellTarget    = nil
                questState.sellSoldTotal = 0
            end
        end
    else
        if questState.sellTarget or questState.sellSoldTotal ~= 0 then
            pushLog("RESET SellTarget/SellCount karena mode quest bukan 'sell' lagi.")
        end
        questState.sellTarget    = nil
        questState.sellSoldTotal = 0
    end

    updateQuestUI()

    if sourceTag then
        pushLog(string.format(
            "%s | mode=%s | give=%s | fishKey='%s' | dialog='%s'%s",
            sourceTag,
            questState.mode,
            questState.give and "true" or "false",
            tostring(questState.fishKey or "-"),
            tostring(questState.lastDialog or "-"),
            questState.sellTarget and (" | SellTarget="..questState.sellTarget.." Sold="..questState.sellSoldTotal) or ""
        ))
    end

    -- WEBHOOK: quest selesai (dialog Terimakasih)
    if isQuestFinished() then
        local hash = tostring(questState.lastDialog or "").."|"..tostring(questState.fishKeyNormalized or "")
        if questState._lastFinishedHash ~= hash then
            questState._lastFinishedHash = hash

            -- Segarkan token sekali tepat saat quest dinyatakan selesai
            updateTokenFromServer((sourceTag or "applyQuestInfo").." → GetToken (QuestFinished)", true)

            sendWinterWebhook("finished", sourceTag or "applyQuestInfo", {
                note            = "Quest terdeteksi selesai (dialog mengandung 'Terimakasih').",
                extraFieldName  = "Status",
                extraFieldValue = "Quest Selesai / Sukses",
            })
        end
    end

    -- 'Dapatkan X ikan lagi' tracking
    do
        local dialog = questState.lastDialog
        if type(dialog) ~= "string" then
            questState.obtainActive    = false
            questState.obtainRemaining = nil
        else
            local lower = dialog:lower()
            if not (lower:find("dapatkan", 1, true) and lower:find("ikan", 1, true)) then
                questState.obtainActive    = false
                questState.obtainRemaining = nil
            else
                local oldRemain = questState.obtainRemaining
                local numStr = lower:match("dapatkan%s+(%d+)%s+ikan")
                             or lower:match("dapatkan%s+(%d+)")
                local remain = tonumber(numStr)

                questState.obtainActive = true
                questState.obtainRemaining = remain

                -- reset flag kalau quest baru / jumlah berubah & masih > 0
                if remain == nil or remain > 0 then
                    questState.obtainHandled = false
                end

                if remain then
                    if (not questState.obtainHandled) or (remain > 0 and oldRemain ~= remain) then
                        pushLog(string.format("ObtainQuest: dialog 'Dapatkan %d ikan lagi'.", remain))
                    end
                end

                if remain == 0 and not questState.obtainHandled then
                    questState.obtainHandled = true

                    if autoQuest then
                        pushLog("ObtainQuest: sisa 0 ikan (AutoQuest ON). Menunggu siklus AutoQuest memanggil EndQuest → GetQuest.")
                    else
                        questState.obtainActive = false
                        pushLog("ObtainQuest: sisa 0 ikan. Auto EndQuest (Makasih) + GetQuest baru (mode manual).")

                        local okRuntime, errRuntime = pcall(function()
                            local resEnd, errEnd = doEndQuestRaw()
                            if not resEnd and errEnd then
                                pushLog("ObtainQuest auto EndQuest error: "..tostring(errEnd))
                                return
                            end

                            -- Setelah EndQuest otomatis ini, update token (silent)
                            updateTokenFromServer("ObtainQuest Auto Flow → GetToken", true)

                            sendWinterWebhook("before_new", "ObtainQuest Auto Flow", {
                                note            = "Dialog 'Dapatkan X ikan lagi' mencapai 0 (AutoQuest OFF). Script memanggil GetQuest untuk quest baru.",
                                extraFieldName  = "Status",
                                extraFieldValue = "ObtainQuest: ambil quest baru (manual auto).",
                            })

                            local resGet, errGet = callWinter("GetQuest")
                            if not resGet and errGet then
                                pushLog("ObtainQuest auto GetQuest error: "..tostring(errGet))
                                return
                            end
                            pushLog("ObtainQuest auto: GetQuest OK (quest baru).")

                            local infoNew, errInfo = callWinter("GetQuestInfo")
                            if infoNew then
                                applyQuestInfo(infoNew, "ObtainQuest → GetQuestInfo (Quest Baru)", true)
                            elseif errInfo then
                                pushLog("ObtainQuest auto GetQuestInfo error: "..tostring(errInfo))
                            end
                        end)

                        if not okRuntime then
                            pushLog("ObtainQuest auto runtime error: "..tostring(errRuntime))
                        end
                    end
                end
            end
        end
    end

    -- NEW QUEST: jika mode OTHER/Fishing & AutoQuest ON, teleport ke fishing spot
    if isNewQuest then
        sendWinterWebhook("new_quest", sourceTag or "ApplyQuestInfo(NewQuest)", {
            note            = "Quest baru diambil. Event dikirim segera setelah GetQuestInfo (isNewQuest=true).",
            extraFieldName  = "Status",
            extraFieldValue = "Quest Baru Diambil.",
        })

        if autoQuest and questState.mode == "other" then
            questState.fishingInitDone = true
            pushLog("AutoQuest: Quest baru mode OTHER/FISHING. Teleport ke fishing spot. AutoFishing Quest/Farm akan menangani lempar otomatis.")
            if not teleportToFishingSpot() then
                pushLog("AutoQuest: Gagal teleport ke fishing spot (HumanoidRootPart tidak ditemukan).")
            end
        else
            questState.fishingInitDone = false
        end
    end
end

------------------- AUTO QUEST -------------------
local function updateAutoQuestBtnUI()
    if not autoQuestBtn then return end
    if autoQuest then
        autoQuestBtn.Text = "AutoQuest: ON"
        autoQuestBtn.BackgroundColor3 = Color3.fromRGB(80,160,96)
        autoQuestBtn.TextColor3       = Color3.fromRGB(255,255,255)
    else
        autoQuestBtn.Text = "AutoQuest: OFF"
        autoQuestBtn.BackgroundColor3 = Color3.fromRGB(228,232,248)
        autoQuestBtn.TextColor3       = Color3.fromRGB(40,44,70)
    end
end

local function setStatus(text)
    if statusLabel then
        statusLabel.Text = "Status: "..tostring(text or "Idle.")
    end
end

local function getProgressInfoFromDialog()
    local dialog = questState.lastDialog
    if type(dialog) ~= "string" then
        return nil, nil
    end
    local lower = dialog:lower()

    -- Dapatkan X ikan lagi
    if lower:find("dapatkan", 1, true) and lower:find("ikan", 1, true) then
        local numStr = lower:match("dapatkan%s+(%d+)%s+ikan")
                     or lower:match("dapatkan%s+(%d+)")
        local remain = tonumber(numStr)
        return "obtain", remain
    end

    -- Jual X ikan ... lagi
    if lower:find("jual", 1, true) and lower:find("ikan", 1, true) and lower:find("lagi", 1, true) then
        local numStr = lower:match("jual%s+(%d+)%s+ikan")
                     or lower:match("jual%s+(%d+)")
        local remain = tonumber(numStr)
        return "sell", remain
    end

    -- Berikan X ikan ... lagi
    if lower:find("berikan", 1, true) and lower:find("ikan", 1, true) and lower:find("lagi", 1, true) then
        local numStr = lower:match("berikan%s+(%d+)%s+ikan")
                     or lower:match("berikan%s+(%d+)")
        local remain = tonumber(numStr)
        return "give", remain
    end

    return nil, nil
end

------------------- AUTOFISHING (Quest & Farm) -------------------
local function isObtainQuestActive()
    return questState.obtainActive == true
end

local function anyAutoFishingEnabled()
    return autoFishingQuest or autoFishingFarm
end

local function updateAutoFishingQuestBtnUI()
    if not autoFishingQuestBtn then return end
    if autoFishingQuest then
        autoFishingQuestBtn.Text = "AutoFishing Quest: ON"
        autoFishingQuestBtn.BackgroundColor3 = Color3.fromRGB(80,160,96)
        autoFishingQuestBtn.TextColor3       = Color3.fromRGB(255,255,255)
    else
        autoFishingQuestBtn.Text = "AutoFishing Quest: OFF"
        autoFishingQuestBtn.BackgroundColor3 = Color3.fromRGB(228,232,248)
        autoFishingQuestBtn.TextColor3       = Color3.fromRGB(40,44,70)
    end
end

local function updateAutoFishingFarmBtnUI()
    if not autoFishingFarmBtn then return end
    if autoFishingFarm then
        autoFishingFarmBtn.Text = "AutoFishing Farm: ON"
        autoFishingFarmBtn.BackgroundColor3 = Color3.fromRGB(80,160,96)
        autoFishingFarmBtn.TextColor3       = Color3.fromRGB(255,255,255)
    else
        autoFishingFarmBtn.Text = "AutoFishing Farm: OFF"
        autoFishingFarmBtn.BackgroundColor3 = Color3.fromRGB(228,232,248)
        autoFishingFarmBtn.TextColor3       = Color3.fromRGB(40,44,70)
    end
end

-- TRUE kalau saat ini AutoFishing boleh aktif
local function isAutoFishingNow()
    if autoFishingFarm then
        return true
    end

    if autoFishingQuest and isObtainQuestActive() then
        local now = os.clock()
        if autoFishingQuestDelayUntil > 0 and now < autoFishingQuestDelayUntil then
            return false
        end
        return true
    end

    return false
end

local function getReelingGuiState()
    local pg
    pcall(function()
        pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)
    if not pg then return nil end

    local reelingGui = pg:FindFirstChild("Reeling")
    if not (reelingGui and reelingGui.Enabled) then
        return nil
    end

    local frameGui   = reelingGui:FindFirstChild("Frame")
    if not frameGui then
        return nil
    end

    local midFrame   = frameGui:FindFirstChild("Frame")
    local whiteBar   = midFrame and midFrame:FindFirstChild("WhiteBar")
    local redBar     = midFrame and midFrame:FindFirstChild("RedBar")
    local progressBg = frameGui:FindFirstChild("ProgressBg")
    local progressBar= progressBg and progressBg:FindFirstChild("ProgressBar")

    local ratio = 0
    if progressBg and progressBar then
        local bgSize = progressBg.AbsoluteSize.X
        if bgSize > 0 then
            ratio = math.clamp(progressBar.AbsoluteSize.X / bgSize, 0, 1)
        else
            ratio = progressBar.Size.X.Scale
        end
    end

    return {
        gui         = reelingGui,
        frame       = frameGui,
        midFrame    = midFrame,
        whiteBar    = whiteBar,
        redBar      = redBar,
        progressBg  = progressBg,
        progressBar = progressBar,
        ratio       = ratio,
    }
end

local function stopSmartReelingAuto()
    if autoFishingReelConn then
        pcall(function() autoFishingReelConn:Disconnect() end)
        autoFishingReelConn = nil
    end
end

-- Smart Reeling SELALU aktif saat AutoFishing ON, langsung baca redbar kapan pun muncul
local function startSmartReelingAuto()
    stopSmartReelingAuto()
    if not (RunService and RodRemoteEvent) then return end

    autoFishingReelConn = RunService.RenderStepped:Connect(function()
        if not alive or not isAutoFishingNow() then
            return
        end

        local state = getReelingGuiState()
        if not state then return end

        local char = LocalPlayer.Character
        if not char then return end

        -- Cari Rod yang benar di tangan dulu
        local rodTool
        for _, inst in ipairs(char:GetChildren()) do
            if isRodToolInstance(inst) then
                rodTool = inst
                break
            end
        end

        if not rodTool then
            -- fallback: pakai cache atau cari lagi
            if lastRodTool and lastRodTool.Parent and isRodToolInstance(lastRodTool) then
                rodTool = lastRodTool
            else
                rodTool = findRodToolForFishing()
            end
        end

        if not rodTool then
            return
        end
        lastRodTool = rodTool

        local whiteBar   = state.whiteBar
        local redBar     = state.redBar
        local progressBg = state.progressBg
        local progressBar= state.progressBar

        if whiteBar and redBar then
            local targetCenter = redBar.Position.X.Scale + redBar.Size.X.Scale * 0.5
            local halfWidth    = whiteBar.Size.X.Scale * 0.5
            local newX         = math.clamp(targetCenter - halfWidth, 0, 1 - whiteBar.Size.X.Scale)
            whiteBar.Position  = UDim2.new(newX, 0, whiteBar.Position.Y.Scale, whiteBar.Position.Y.Offset)
        end

        if progressBg and progressBar then
            local sx = state.ratio or 0
            if sx >= 1 then
                pcall(function()
                    RodRemoteEvent:FireServer("Reeling", rodTool, true)
                end)
            end
        end
    end)
end

local function throwRodAuto(rodTool)
    if not RodRemoteEvent or not rodTool then return end

    local hitCFrame
    local okHit, errHit = pcall(function()
        local mouse = LocalPlayer:GetMouse()
        hitCFrame = mouse and mouse.Hit
    end)

    if not okHit or not hitCFrame then
        pushLog("AutoFishing: gagal mendapatkan Mouse.Hit (Throw batal) - "..tostring(errHit))
        return
    end

    pcall(function()
        RodRemoteEvent:FireServer("Throw", rodTool, hitCFrame)
    end)
    autoFishingCasting = true
    lastRodTool        = rodTool
    pushLog("AutoFishing: Throw (AutoFishing Quest/Farm) via Mouse.Hit dengan Rod '"..tostring(rodTool.Name).."'.")
end

local function ensureRodEventListenerAuto()
    if autoFishingRodEventConn then
        pcall(function() autoFishingRodEventConn:Disconnect() end)
    end
    autoFishingRodEventConn = nil

    if not RodRemoteEvent then
        return
    end

    autoFishingRodEventConn = RodRemoteEvent.OnClientEvent:Connect(function(eventName, _, flag)
        if (eventName == "Reeling" and flag) or eventName == "StopShake" or eventName == "Stopshake" then
            autoFishingCasting = false
            if not alive or not isAutoFishingNow() then return end

            task.delay(0.5, function()
                if not alive or not isAutoFishingNow() then return end

                local rod, err = ensureRodEquipped()
                if not rod then
                    pushLog("AutoFishing: Rod tidak ditemukan saat rethrow (OnClientEvent): "..tostring(err))
                    return
                end

                throwRodAuto(rod)
                task.wait(1)
                startSmartReelingAuto()
            end)
        end
    end)
end

local function startAutoFishingLoop()
    if autoFishingLoopRunning then return end
    autoFishingLoopRunning = true

    task.spawn(function()
        while alive do
            if isAutoFishingNow() and not autoFishingCasting then
                local rod, err = ensureRodEquipped()
                if rod then
                    throwRodAuto(rod)
                    task.wait(1)
                    startSmartReelingAuto()
                else
                    pushLog("AutoFishing: Rod tidak ditemukan di loop utama: "..tostring(err))
                    task.wait(2)
                end
            end
            task.wait(0.5)
        end
        autoFishingLoopRunning = false
    end)
end

local function stopAutoFishing()
    autoFishingCasting = false
    stopSmartReelingAuto()
    if autoFishingRodEventConn then
        pcall(function() autoFishingRodEventConn:Disconnect() end)
        autoFishingRodEventConn = nil
    end
end

local function refreshAutoFishingEngine()
    if anyAutoFishingEnabled() then
        ensureRodEventListenerAuto()
        startAutoFishingLoop()
        startSmartReelingAuto()  -- Smart Reeling aktif sejak toggle ON
    else
        stopAutoFishing()
    end
end

local function setAutoFishingQuest(state)
    state = state and true or false
    if state == autoFishingQuest then
        updateAutoFishingQuestBtnUI()
        return
    end

    autoFishingQuest = state
    updateAutoFishingQuestBtnUI()

    if autoFishingQuest then
        autoFishingQuestDelayUntil = 0
        setStatus("AutoFishing Quest: ON (ikuti dialog 'Dapatkan X ikan lagi').")
        pushLog("AutoFishing Quest ON: auto lempar + Smart Reeling hanya saat quest 'Dapatkan X ikan lagi' aktif.\n"..
            "- Begitu dialog muncul, AutoFishing Quest langsung aktif (kecuali sedang delay 2 detik setelah teleport AutoQuest).\n"..
            "- Rod akan dicek dulu, kalau sudah di tangan tidak di-equip ulang.")
        notify("Winter Quest","AutoFishing Quest: ON (mengikuti dialog Dapatkan X ikan lagi).",3)
        sendWinterInfoSnapshot("Toggle AutoFishing Quest", "AutoFishing Quest: ON")
    else
        autoFishingQuestDelayUntil = 0
        setStatus("AutoFishing Quest: OFF.")
        pushLog("AutoFishing Quest OFF.")
        notify("Winter Quest","AutoFishing Quest: OFF.",2)
        sendWinterInfoSnapshot("Toggle AutoFishing Quest", "AutoFishing Quest: OFF")
    end

    refreshAutoFishingEngine()
end

local function setAutoFishingFarm(state)
    state = state and true or false
    if state == autoFishingFarm then
        updateAutoFishingFarmBtnUI()
        return
    end

    autoFishingFarm = state
    updateAutoFishingFarmBtnUI()

    if autoFishingFarm then
        setStatus("AutoFishing Farm: ON (auto fishing bebas, tidak tergantung quest).")
        pushLog("AutoFishing Farm ON: auto lempar + Smart Reeling meskipun tidak ada dialog quest (mode farm bebas).\n"..
            "- Rod dicek dulu, kalau sudah di tangan langsung dipakai.")
        notify("Winter Quest","AutoFishing Farm: ON (auto fishing mandiri).",3)
        sendWinterInfoSnapshot("Toggle AutoFishing Farm", "AutoFishing Farm: ON")
    else
        setStatus("AutoFishing Farm: OFF.")
        pushLog("AutoFishing Farm OFF.")
        notify("Winter Quest","AutoFishing Farm: OFF.",2)
        sendWinterInfoSnapshot("Toggle AutoFishing Farm", "AutoFishing Farm: OFF")
    end

    refreshAutoFishingEngine()
end

------------------- AUTO QUEST CYCLE -------------------
local function runAutoQuestCycle()
    if not autoQuest or not alive then return end

    setStatus("AutoQuest: CheckQuest → GetQuestInfo → cek dialog → aksi…")

    -- 1) CheckQuest
    local cq, errCq = callWinter("CheckQuest")
    if cq then
        applyQuestInfo(cq, "AutoQuest → CheckQuest", false)
    elseif errCq then
        pushLog("AutoQuest: CheckQuest error: "..tostring(errCq))
    end

    if not autoQuest or not alive then return end

    -- 2) GetQuestInfo awal
    local info1, errInfo1 = callWinter("GetQuestInfo")
    if info1 then
        applyQuestInfo(info1, "AutoQuest → GetQuestInfo (Before Progress Check)", false)
    elseif errInfo1 then
        pushLog("AutoQuest: GetQuestInfo (Before Progress Check) error: "..tostring(errInfo1))
    end

    if not autoQuest or not alive then return end

    -- 3) Baca dialog progress
    local kind, remain = getProgressInfoFromDialog()

    --------------------------------------------------
    -- SPECIAL CASE: "Berikan 1 ikan ... lagi"
    --------------------------------------------------
    if kind == "give" and remain == 1 then
        pushLog("AutoQuest GIVE special: dialog 'Berikan 1 ikan ... lagi' dianggap selesai, langsung GetQuest quest baru (tanpa EndQuest tambahan).")
        setStatus("AutoQuest: 'Berikan 1 ikan ... lagi' → langsung ambil quest baru.")

        -- segarkan token sebelum ambil quest baru (silent)
        updateTokenFromServer("AutoQuest GIVE special → GetToken (Before GetQuest)", true)

        sendWinterWebhook("before_new", "AutoQuest GIVE special ('Berikan 1 ikan ... lagi')", {
            note            = "AutoQuest mendeteksi dialog 'Berikan 1 ikan ... lagi' dan langsung mengambil quest baru tanpa EndQuest ekstra.",
            extraFieldName  = "Status",
            extraFieldValue = "AutoQuest GIVE special → akan ambil quest baru.",
        })

        local resGet, errGet = callWinter("GetQuest")
        if not resGet and errGet then
            pushLog("AutoQuest GIVE special: GetQuest error: "..tostring(errGet))
            return
        else
            pushLog("AutoQuest GIVE special: GetQuest dipanggil untuk quest baru.")
        end

        if not autoQuest or not alive then return end

        local info2, errInfo2 = callWinter("GetQuestInfo")
        if info2 then
            applyQuestInfo(info2, "AutoQuest GIVE special → GetQuestInfo (Quest Baru)", true)
        elseif errInfo2 then
            pushLog("AutoQuest GIVE special: GetQuestInfo error: "..tostring(errInfo2))
        end

        return
    end
    --------------------------------------------------

    -- 3a) DAPATKAN X ikan lagi → HANYA NUNGGU (AutoFishing Quest/Farm yang menyelesaikan)
    if kind == "obtain" then
        local remainText = remain and tostring(remain) or "?"
        if remain == nil or remain > 0 then
            pushLog("AutoQuest: quest 'Dapatkan "..remainText.." ikan lagi' masih berjalan. Menunggu, tanpa EndQuest/GetQuest.\n"..
                "- AutoFishing Quest (ON) akan auto Throw + Smart Reeling mengikuti dialog ini.")
            setStatus("AutoQuest: menunggu quest 'Dapatkan "..remainText.." ikan lagi' selesai (AutoFishing Quest/Farm kalau ON).")
            return
        end
    end

    -- 3b) SELL progress dialog
    if kind == "sell" then
        local remainText = remain and tostring(remain) or "?"
        if remain == nil or remain > 0 then
            setStatus("AutoQuest: menyelesaikan quest 'Jual "..remainText.." ikan ... lagi'.")
            pushLog("AutoQuest SELL progress: '"..tostring(questState.lastDialog or "-").."'. Mulai SellLoop (progress).")

            local maxSteps = remain or 50
            maxSteps = math.clamp(maxSteps, 1, 50)

            runSellLoop(maxSteps, "AutoQuest SELL (progress)", true)

            if not autoQuest or not alive then return end

            local infoAfter, errAfter = callWinter("GetQuestInfo")
            if infoAfter then
                applyQuestInfo(infoAfter, "AutoQuest → GetQuestInfo (After SELL progress)", false)
            elseif errAfter then
                pushLog("AutoQuest SELL (progress): GetQuestInfo error: "..tostring(errAfter))
            end

            local kind2, remain2 = getProgressInfoFromDialog()
            if kind2 == "sell" and (remain2 == nil or remain2 > 0) then
                local r2 = remain2 and tostring(remain2) or "?"
                local anyQuestFish = findQuestFishTool({ skipFavorite = true })
                if anyQuestFish then
                    pushLog("AutoQuest SELL (progress): masih 'Jual "..r2.." ikan ... lagi' dan masih ada ikan quest. Skip EndQuest/GetQuest di siklus ini.")
                    setStatus("AutoQuest: menunggu quest 'Jual "..r2.." ikan ... lagi' selesai.")
                    return
                else
                    pushLog("AutoQuest SELL (progress): dialog masih 'Jual "..r2.." ikan ... lagi' tapi ikan quest non-favorite di backpack/char sudah habis. Anggap progress selesai, lanjut finalize EndQuest → GetQuest.")
                end
            end
        end
    end

    -- 3c) GIVE progress dialog
    if kind == "give" then
        local remainText = remain and tostring(remain) or "?"
        if remain == nil or remain > 0 then
            setStatus("AutoQuest: menyelesaikan quest 'Berikan "..remainText.." ikan ... lagi'.")
            pushLog("AutoQuest GIVE progress: '"..tostring(questState.lastDialog or "-").."'. Mulai GiveLoop (progress).")

            local maxSteps = remain or 50
            maxSteps = math.clamp(maxSteps, 1, 50)

            runEndQuestGiveLoop(maxSteps, "AutoQuest GIVE (progress)", true)

            if not autoQuest or not alive then return end

            local infoAfter, errAfter = callWinter("GetQuestInfo")
            if infoAfter then
                applyQuestInfo(infoAfter, "AutoQuest → GetQuestInfo (After GIVE progress)", false)
            elseif errAfter then
                pushLog("AutoQuest GIVE (progress): GetQuestInfo error: "..tostring(errAfter))
            end

            local kind2, remain2 = getProgressInfoFromDialog()
            if kind2 == "give" and (remain2 == nil or remain2 > 0) then
                local r2 = remain2 and tostring(remain2) or "?"
                local anyQuestFish = findQuestFishTool({ skipFavorite = true })
                if anyQuestFish then
                    pushLog("AutoQuest GIVE (progress): masih 'Berikan "..r2.." ikan ... lagi' dan masih ada ikan quest. Skip EndQuest/GetQuest di siklus ini.")
                    setStatus("AutoQuest: menunggu quest 'Berikan "..r2.." ikan ... lagi' selesai.")
                    return
                else
                    pushLog("AutoQuest GIVE (progress): dialog masih 'Berikan "..r2.." ikan ... lagi' tapi ikan quest non-favorite di backpack/char sudah habis. Anggap progress selesai, lanjut finalize EndQuest → GetQuest.")
                end
            end
        end
    end

    -- 4) FINAL STEP sesuai mode
    if questState.mode == "sell" then
        local okSell, errSell = sellQuestFishOnce()
        if not okSell and errSell then
            pushLog("AutoQuest SELL (final-step): "..tostring(errSell))
        end
    elseif questState.mode == "give" then
        local okGive, errGive = giveQuestFishOnce()
        if not okGive and errGive then
            pushLog("AutoQuest GIVE (final-step): "..tostring(errGive))
        end
    end

    if not autoQuest or not alive then return end

    local resEnd, errEnd = doEndQuestRaw()
    if not resEnd and errEnd then
        pushLog("AutoQuest: EndQuest error: "..tostring(errEnd))
    else
        pushLog("AutoQuest: EndQuest dipanggil (siklus).")
    end

    -- Setelah EndQuest berhasil di siklus AutoQuest, segarkan token sekali (silent)
    if resEnd then
        updateTokenFromServer("AutoQuest Cycle → GetToken (Post EndQuest)", true)
    end

    if not autoQuest or not alive then return end

    sendWinterWebhook("before_new", "AutoQuest Cycle → EndQuest → GetQuest", {
        note            = "AutoQuest selesai 1 siklus dan akan memanggil GetQuest untuk lanjut quest berikutnya.",
        extraFieldName  = "Status",
        extraFieldValue = "AutoQuest: sebelum ambil quest baru.",
    })

    local resGet, errGet = callWinter("GetQuest")
    if not resGet and errGet then
        pushLog("AutoQuest: GetQuest error: "..tostring(errGet))
        return
    else
        pushLog("AutoQuest: GetQuest dipanggil (quest lanjut / quest baru).")
    end

    if not autoQuest or not alive then return end

    local info2, errInfo2 = callWinter("GetQuestInfo")
    if info2 then
        applyQuestInfo(info2, "AutoQuest → GetQuestInfo (After GetQuest)", true)
    elseif errInfo2 then
        pushLog("AutoQuest: GetQuestInfo (After GetQuest) error: "..tostring(errInfo2))
    end
end

local function startAutoQuestLoop()
    if autoQuestLoopRunning then return end
    autoQuestLoopRunning = true

    task.spawn(function()
        while alive do
            if autoQuest then
                local ok, err = pcall(runAutoQuestCycle)
                if not ok then
                    pushLog("AutoQuest runtime error: "..tostring(err))
                end
            end

            for _ = 1, 4 do
                if not alive then break end
                if not autoQuest then break end
                task.wait(1)
            end

            if not autoQuest then
                task.wait(1)
            end
        end
    end)
end

local function setAutoQuest(state)
    if state == autoQuest then return end
    autoQuest = state and true or false
    updateAutoQuestBtnUI()

    if autoQuest then
        setStatus("AutoQuest: ON (dialog-aware semua: Dapatkan / Jual / Berikan ... lagi).")
        pushLog("AutoQuest ON: flow sistematik + anti nyangkut GIVE/SELL.\n"..
            "- 'Dapatkan X ikan lagi' → nunggu (AutoFishing Quest/Farm yang bantu tangkap ikan kalau ON).\n"..
            "- 'Jual X ikan ... lagi' → SellLoop sampai selesai.\n"..
            "- 'Berikan X ikan ... lagi' → GiveLoop sampai selesai.\n"..
            "- KHUSUS 'Berikan 1 ikan ... lagi' → langsung GetQuest baru.")
        startAutoQuestLoop()
        notify("Winter Quest","AutoQuest ON (dialog-aware, anti spam, smart Sell/Give).",3)
        sendWinterInfoSnapshot("Toggle AutoQuest", "AutoQuest: ON")
    else
        setStatus("AutoQuest: OFF.")
        pushLog("AutoQuest OFF.")
        notify("Winter Quest","AutoQuest OFF (loop auto berhenti).",2)
        sendWinterInfoSnapshot("Toggle AutoQuest", "AutoQuest: OFF")
    end
end

------------------- AUTO REFRESH INFO -------------------
local function autoInitialSync()
    local ok, err = pcall(function()
        local info, errInfo = callWinter("GetQuestInfo")
        if info then
            applyQuestInfo(info, "InitialSync → GetQuestInfo", false)
        elseif errInfo then
            pushLog("InitialSync GetQuestInfo error: "..tostring(errInfo))
        end

        -- Sinkron token di awal tanpa notifikasi (ringan)
        updateTokenFromServer("InitialSync → GetToken", true)

        setStatus("Data quest & token tersinkron dari server (auto awal, tanpa loop).")
    end)
    if not ok then
        pushLog("InitialSync runtime error: "..tostring(err))
    end
end

local function startInfoAutoLoop()
    if infoAutoLoopRunning then return end
    infoAutoLoopRunning = true

    task.spawn(function()
        while alive do
            if not autoQuest then
                local ok, err = pcall(function()
                    local info, errInfo = callWinter("GetQuestInfo")
                    if info then
                        applyQuestInfo(info, "AutoRefresh → GetQuestInfo", false)
                    elseif errInfo then
                        pushLog("AutoRefresh GetQuestInfo error: "..tostring(errInfo))
                    end
                end)
                if not ok then
                    pushLog("AutoRefresh runtime error: "..tostring(err))
                end
            end

            for _ = 1, 20 do
                if not alive then break end
                task.wait(1)
            end
        end
    end)
end

------------------- UI BUILD -------------------
local body = Instance.new("ScrollingFrame")
body.Name = "BodyScroll"
body.Position = UDim2.new(0,0,0,0)
body.Size = UDim2.new(1,0,1,0)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.CanvasSize = UDim2.new(0,0,0,0)
body.Parent = frame

local bodyPad = Instance.new("UIPadding", body)
bodyPad.PaddingLeft   = UDim.new(0,6)
bodyPad.PaddingRight  = UDim.new(0,6)
bodyPad.PaddingTop    = UDim.new(0,6)
bodyPad.PaddingBottom = UDim.new(0,6)

local bodyLayout = Instance.new("UIListLayout", body)
bodyLayout.FillDirection = Enum.FillDirection.Vertical
bodyLayout.SortOrder     = Enum.SortOrder.LayoutOrder
bodyLayout.Padding       = UDim.new(0,8)

bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    body.CanvasSize = UDim2.new(0,0,0, bodyLayout.AbsoluteContentSize.Y + 8)
end)

-- Header
do
    local headerCard = makeCard(body, 1)

    makeLabel(headerCard, "❄ Winter Quest V7.4+ — Indo Hangout", UDim2.new(1,0,0,20), {
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(35,38,70),
        XAlign = Enum.TextXAlignment.Left
    })

    local desc = makeLabel(headerCard,
        "TAB ini mengontrol Event Winter dengan (AutoQuest dialog-aware + AutoFishing Quest/Farm + SMART RodTool + Discord Webhook + Auto Token)",
        UDim2.new(1,0,0,0),
        {
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(92,96,124),
            XAlign = Enum.TextXAlignment.Left,
            YAlign = Enum.TextYAlignment.Top,
            Wrapped = true,
        }
    )
    desc.AutomaticSize = Enum.AutomaticSize.Y
end

-- Controls card
local getQuestBtn, getInfoBtn, endQuestBtn, getQuestNewBtn, checkTokenBtn, sellFishBtn
do
    local controlsCard = makeCard(body, 2)

    makeLabel(controlsCard, "Main Controls", UDim2.new(1,0,0,18), {
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(35,38,70),
        XAlign = Enum.TextXAlignment.Left,
    })

    local descControl = makeLabel(controlsCard,
        "Tombol utama Winter Quest. AutoQuest baca dialog",
        UDim2.new(1,0,0,0),
        {
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(92,96,124),
            XAlign = Enum.TextXAlignment.Left,
            YAlign = Enum.TextYAlignment.Top,
            Wrapped = true,
        }
    )
    descControl.AutomaticSize = Enum.AutomaticSize.Y

    local controlsScroll = New("ScrollingFrame", {
        Name = "ControlsScroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,130),
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = controlsCard,
    }, {
        New("UIPadding", {
            PaddingLeft   = UDim.new(0,0),
            PaddingRight  = UDim.new(0,2),
            PaddingTop    = UDim.new(0,2),
            PaddingBottom = UDim.new(0,2),
        })
    })

    local grid = Instance.new("UIGridLayout")
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.SortOrder     = Enum.SortOrder.LayoutOrder
    grid.CellPadding   = UDim2.new(0,6,0,6)
    grid.CellSize      = UDim2.new(0.5, -6, 0, 28)
    grid.Parent        = controlsScroll

    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        controlsScroll.CanvasSize = UDim2.new(0,0,0, grid.AbsoluteContentSize.Y + 4)
    end)

    getQuestBtn         = makeLittleButton(controlsScroll, "GetQuest (CheckQuest)")
    getInfoBtn          = makeLittleButton(controlsScroll, "GetQuestInfo")
    endQuestBtn         = makeLittleButton(controlsScroll, "EndQuest (Give)")
    getQuestNewBtn      = makeLittleButton(controlsScroll, "GetQuest (New Quest)")
    autoQuestBtn        = makeLittleButton(controlsScroll, "AutoQuest: OFF")
    autoFishingQuestBtn = makeLittleButton(controlsScroll, "AutoFishing Quest: OFF")
    autoFishingFarmBtn  = makeLittleButton(controlsScroll, "AutoFishing Farm: OFF")
    checkTokenBtn       = makeLittleButton(controlsScroll, "Check Token")
    sellFishBtn         = makeLittleButton(controlsScroll, "Sell Fish (Manual)")
end

-- Quest status/log card
do
    local questCard = makeCard(body, 3)

    makeLabel(questCard, "Quest Status & Token", UDim2.new(1,0,0,18), {
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(35,38,70),
        XAlign = Enum.TextXAlignment.Left,
    })

    questInfoLabel = makeLabel(questCard, "Quest Info: belum ada data.", UDim2.new(1,0,0,18), {
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(50,54,90),
        XAlign = Enum.TextXAlignment.Left,
    })

    tokenLabel = makeLabel(questCard, "Token: 0", UDim2.new(1,0,0,18), {
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(60,120,80),
        XAlign = Enum.TextXAlignment.Left,
    })

    questDetailLabel = makeLabel(questCard, "Target Ikan: -\nDialog: -", UDim2.new(1,0,0,40), {
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(80,84,120),
        XAlign = Enum.TextXAlignment.Left,
        YAlign = Enum.TextYAlignment.Top,
        Wrapped = true,
    })

    statusLabel = makeLabel(questCard, "Status: Idle.", UDim2.new(1,0,0,18), {
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(110,114,140),
        XAlign = Enum.TextXAlignment.Left,
    })

    makeLabel(questCard, "Log:", UDim2.new(1,0,0,16), {
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(80,84,120),
        XAlign = Enum.TextXAlignment.Left,
    })

    local logScroll = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,160),
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = questCard,
    }, {
        New("UIPadding", {
            PaddingLeft   = UDim.new(0,0),
            PaddingRight  = UDim.new(0,2),
            PaddingTop    = UDim.new(0,0),
            PaddingBottom = UDim.new(0,0),
        })
    })

    logLabel = makeLabel(logScroll, "", UDim2.new(1,-4,0,0), {
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(70,72,110),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Wrapped = true,
    })

    logLabel.Size = UDim2.new(1,-4,0,0)
    logLabel.AutomaticSize = Enum.AutomaticSize.Y

    logLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        logScroll.CanvasSize = UDim2.new(0,0,0, logLabel.AbsoluteSize.Y + 4)
    end)
end

updateQuestUI()
updateAutoQuestBtnUI()
updateAutoFishingQuestBtnUI()
updateAutoFishingFarmBtnUI()
setStatus("Idle.")

------------------- BUTTON CALLBACKS -------------------
getQuestBtn.MouseButton1Click:Connect(function()
    local res, err = callWinter("CheckQuest")
    if not res and err then
        pushLog("GetQuest / CheckQuest error: "..tostring(err))
        notify("Winter Quest","CheckQuest gagal, lihat Output.",3)
        return
    end

    applyQuestInfo(res, "CheckQuest", false)
    setStatus("CheckQuest dipanggil.")
    notify("Winter Quest","CheckQuest dipanggil.",2)

    sendWinterInfoSnapshot("Button: CheckQuest", "CheckQuest dipanggil (manual).")
end)

getInfoBtn.MouseButton1Click:Connect(function()
    local res, err = callWinter("GetQuestInfo")
    if not res and err then
        pushLog("GetQuestInfo error: "..tostring(err))
        notify("Winter Quest","GetQuestInfo gagal, lihat Output.",3)
        return
    end

    applyQuestInfo(res, "GetQuestInfo", false)
    setStatus("GetQuestInfo diperbarui.")
    notify("Winter Quest","GetQuestInfo berhasil.",2)

    sendWinterInfoSnapshot("Button: GetQuestInfo", "GetQuestInfo diperbarui (manual).")
end)

endQuestBtn.MouseButton1Click:Connect(function()
    local info, err = callWinter("GetQuestInfo")
    if not info and err then
        pushLog("EndQuest (manual) GetQuestInfo error: "..tostring(err))
        notify("Winter Quest","GetQuestInfo gagal sebelum EndQuest.",3)
        return
    end

    applyQuestInfo(info, "Manual EndQuest → GetQuestInfo", false)

    if questState.mode ~= "give" then
        pushLog("Manual EndQuest: mode quest '"..questState.mode.."' (bukan 'give'). EndQuest tetap dipanggil sekali jika game ada efek lain.")
        local _ = doEndQuestRaw()
        setStatus("Manual EndQuest dipanggil (mode bukan give).")
        notify("Winter Quest","EndQuest dipanggil (mode bukan give).",2)
        refreshQuestIfFinished("Manual EndQuest (non-give)")

        sendWinterInfoSnapshot("Button: Manual EndQuest (Non-Give)", "EndQuest dipanggil (mode bukan give).")
        return
    end

    setStatus("Manual EndQuest: mulai serah ikan (mode give, skip Favorite).")
    runEndQuestGiveLoop(40, "Manual EndQuest", false)
    refreshQuestIfFinished("Manual EndQuest")
    notify("Winter Quest","Manual EndQuest (give) selesai, cek log.",3)

    sendWinterInfoSnapshot("Button: Manual EndQuest", "EndQuest (Give) selesai / berhenti.")
end)

getQuestNewBtn.MouseButton1Click:Connect(function()
    -- Sebelum ambil quest baru manual, segarkan token (silent)
    updateTokenFromServer("Manual GetQuest (New Quest Button) → GetToken (Before GetQuest)", true)

    sendWinterWebhook("before_new", "Manual GetQuest (NewQuest Button)", {
        note            = "User menekan tombol 'GetQuest (New Quest)' untuk mengambil quest baru.",
        extraFieldName  = "Status",
        extraFieldValue = "Manual GetQuest (New Quest) – sebelum GetQuest.",
    })

    local res, err = callWinter("GetQuest")
    if not res and err then
        pushLog("GetQuest (NewQuest) error: "..tostring(err))
        notify("Winter Quest","GetQuest (New Quest) gagal, lihat Output.",3)
        return
    end

    pushLog("GetQuest (NewQuest): WinterEvent 'GetQuest' berhasil dipanggil (quest baru).")

    local info, err2 = callWinter("GetQuestInfo")
    if info then
        applyQuestInfo(info, "Manual GetQuest → GetQuestInfo (Quest Baru)", true)
        setStatus("GetQuest (New Quest) berhasil, info quest diperbarui.")
        notify("Winter Quest","GetQuest (New Quest) OK, dialog quest baru sudah di UI.",3)

        sendWinterInfoSnapshot("Button: GetQuest (New Quest)", "GetQuest (New Quest) berhasil.")
    elseif err2 then
        pushLog("GetQuest (NewQuest) GetQuestInfo error: "..tostring(err2))
        setStatus("GetQuest (New Quest) dipanggil, tapi gagal baca info quest.")
        notify("Winter Quest","GetQuestInfo gagal setelah GetQuest.",3)
    end
end)

checkTokenBtn.MouseButton1Click:Connect(function()
    -- manual: dengan notifikasi
    updateTokenFromServer("Manual GetToken", false)
    sendWinterInfoSnapshot("Button: Check Token", "Token diperbarui: "..tostring(questState.tokens or 0))
end)

sellFishBtn.MouseButton1Click:Connect(function()
    local info, err = callWinter("GetQuestInfo")
    if not info and err then
        pushLog("Manual SellFish: GetQuestInfo error: "..tostring(err))
        notify("Winter Quest","GetQuestInfo gagal sebelum SellFish.",3)
        return
    end

    applyQuestInfo(info, "Manual SellFish → GetQuestInfo", false)

    if questState.mode ~= "sell" then
        pushLog("Manual SellFish: mode quest '"..questState.mode.."' (bukan 'sell'), batal auto jual.")
        notify("Winter Quest","Mode quest bukan 'sell'. Tidak auto jual.",3)
        return
    end

    local kind, remain = getProgressInfoFromDialog()
    if kind ~= "sell" then
        pushLog("Manual SellFish: dialog saat ini bukan pola 'Jual X ikan ... lagi'. Tetap mencoba jual sebisa mungkin.")
    end

    if remain and remain > 0 then
        questState.sellTarget    = remain
        questState.sellSoldTotal = 0
        pushLog(string.format("Manual SellFish: reset SellTarget ke %d ikan dari dialog & reset counter.", remain))
    else
        questState.sellTarget    = nil
        questState.sellSoldTotal = 0
        pushLog("Manual SellFish: jumlah dari dialog tidak jelas, SellTarget direset (script akan jual sebisa mungkin tanpa limit internal).")
    end

    setStatus("Manual SellFish: mulai jual ikan (mode sell, skip Favorite, cache direset seperti AutoQuest).")

    local maxSteps = remain or 50
    maxSteps = math.clamp(maxSteps, 1, 50)

    runSellLoop(maxSteps, "Manual SellFish", false)

    if not alive then return end

    local infoAfter, errAfter = callWinter("GetQuestInfo")
    if infoAfter then
        applyQuestInfo(infoAfter, "Manual SellFish → GetQuestInfo (After SELL)", false)
    elseif errAfter then
        pushLog("Manual SellFish: GetQuestInfo (After SELL) error: "..tostring(errAfter))
    end

    refreshQuestIfFinished("Manual SellFish")
    notify("Winter Quest","Manual SellFish selesai / berhenti, cek log.",3)

    sendWinterInfoSnapshot("Button: Manual SellFish", "Manual SellFish selesai / berhenti.")
end)

autoQuestBtn.MouseButton1Click:Connect(function()
    setAutoQuest(not autoQuest)
end)

if autoFishingQuestBtn then
    autoFishingQuestBtn.MouseButton1Click:Connect(function()
        setAutoFishingQuest(not autoFishingQuest)
    end)
end

if autoFishingFarmBtn then
    autoFishingFarmBtn.MouseButton1Click:Connect(function()
        setAutoFishingFarm(not autoFishingFarm)
    end)
end

------------------- TAB CLEANUP -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive                      = false
    autoQuest                  = false
    autoFishingQuest           = false
    autoFishingFarm            = false
    autoFishingQuestDelayUntil = 0
    stopAutoFishing()
end

pushLog("TAB Winter Quest siap. AutoQuest FULL dialog-aware + AutoFishing Quest/Farm + SMART RodTool + TOKEN AUTO-UPDATE")

notify("Winter Quest","TAB Winter Quest siap (AutoQuest dialog-aware + AutoFishing Quest/Farm + SMART RodTool + Discord Webhook + Auto Token).",3)

-- Default: AutoFishing Quest ON, Farm OFF
setAutoFishingQuest(true)

task.spawn(function()
    task.wait(0.5)
    autoInitialSync()
    startInfoAutoLoop()
end)