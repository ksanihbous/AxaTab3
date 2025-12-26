--==========================================================
--  16AxaTab_NearestPlayer.lua
--  TAB 16: "Nearest Player Guard PRO++ (Smart Reeling + Emote Duduk + AutoFishing Lokal + Multi Antena)"
--  v10.8 (WINTER) + UPGRADE SMART AUTOFISH AFTER TELEPORT
--  + Friend Monitor (Exclude Friends: ON -> Webhook Friend Radius/Map)
--  PATCH: Friend Join/Leave Map always updated + remove duplicate webhook logic + lighter
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "nearestplayer"

local players           = Players           or game:GetService("Players")
local localPlayer       = LocalPlayer       or players.LocalPlayer
local runService        = RunService        or game:GetService("RunService")
local starterGui        = StarterGui        or game:GetService("StarterGui")
local httpService       = HttpService       or game:GetService("HttpService")
local marketplace       = game:GetService("MarketplaceService")
local replicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local workspaceService  = game:GetService("Workspace")

local virtualInput
pcall(function()
    virtualInput = VirtualInputManager or game:GetService("VirtualInputManager")
end)

if not (frame and localPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- DISCORD WEBHOOK CONFIG -------------------
local WEBHOOK_URL           = "https://discord.com/api/webhooks/1447366981866098689/65gLY7zKYbZCd7K_ED7BUH_ctyJIFSWclpOLDvoJu0r9V20muSgI_H8lBKOo1hh1kMRK"
local BOT_AVATAR_URL        = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png"
local DEFAULT_OWNER_DISCORD = "<@1403052152691101857>"

local ADMIN_IDS = {
    [2918244413] = true, -- ZuVoid / ZuVoidGT DEVELOPER
    [393072708] = true, -- Pamand Arthur / IMightBeUgly DEVELOPER
    [4366735226] = true, -- AamTum / AamTum DEVELOPER
    [6185428576] = true, -- zengss or Jank_1403 / jank_1403 DEVELOPER
    [7147000579] = true, -- Gazell&Pinky / Alergi_PENINGGI DEVELOPER
    [1115333577] = true, -- AngelsNeedHeaven / AngelsNeedHeaven DEVELOPER
    [1201037734] = true, -- SON / POISENIII HEAD ADMIN
    [7331328452] = true, -- BrowwDeCaprio / 16Broww HEAD ADMIN
    [6160156469] = true, -- Ryin / RYIIN100 HEAD ADMIN
    [7864402618] = true, -- Tiktik / tiktik_4924 HEAD ADMIN
    [8147845822] = true, -- Danskuy / danskuyxd ADMIN
    [7449046692] = true, -- Naira / na_iaa5 ADMIN
    [8390121074] = true, -- Zone / DAXAJA0 ADMIN
    [8142551573] = true, -- Glenfiddich / teteyourb4e ADMIN
    [4755470099] = true, -- viziee / dumbziee ADMIN
    [8530851838] = true, -- Minzu / Mrsnk0 ADMIN
    [8473720116] = true, -- Grezly / VloowZ ADMIN
    [1592339934] = true, -- Eryvenith or Lenn, Who? / ethyreaa ADMIN
    [50792373] = true, -- Lilik / LeeLiQs VIP PARTNER
    [8631506826] = true, -- TickTak / TickTackTows TIKTOKER/SELLER
    [8071643164] = true, -- BruceWayne / adityariski8 TIKTOKER
    [8668234444] = true, -- Jiroo / axagaaa TIKTOKERS
    [8087805397] = true, -- SQKanyut / SQKanyut TIKTOKERS
    [8557512299] = true, -- Gala / CrowValhalla TIKTOKERS
    [8585320336] = true, -- JEAN / JEANZ911 TIKTOKERS
    [8706826354] = true, -- SCHxNailoong / Nailoong29 TIKTOKERS
    [8534358330] = true, -- JAKAWI / adudek19 TIKTOKERS
    [9253558926] = true, -- HajiKalcer / Hajididin TIKTOKERS
    [7962844623] = true, -- Awnnn / Awnnn2419 TIKTOKERS
    [8929154385] = true, -- PinkyBoyzt / PinkyBoyzt TIKTOKERS
    [8793426296] = true, -- JekkSlwly / JekkSlwly26 TIKTOKERS
    [8842458435] = true, -- DEDEDEBU / debubintangni TIKTOKERS
    [2926659406] = true, -- PUTTYDAILY / puttydaily TIKTOKERS
    [8910573996] = true, -- PrinceFannzy / PrinceFannzy TIKTOKERS
    [7954687096] = true, -- ZYNNN / ZynnnX02 TIKTOKERS
    [4831020423] = true, -- starvenn / ravennxxz TIKTOKERS
    [8445880187] = true, -- Payy / ZannButterfly TIKTOKERS
    [8468294802] = true, -- Sakura / SakuraKiyu
    [3203237864] = true, -- Ido / vakkamz7
    [122721024] = true, -- Hizo / 2hizo
    [7811490053] = true, -- Eisha / naerynnnuv
    [8358382042] = true, -- Barooon / baroonsteinfeld
    [8609125996] = true, -- Heyv3r / asrev11
    [1525370726] = true, -- Bithond / Bithond
    [8360242865] = true, -- Issyxuuee / kiyomiiii34
    [1398433171] = true, -- CUPE / P23Savior
    [3562063767] = true, -- Grizzly / Lychttttt
    [7869751197] = true, -- HAJIRIO / rioSlebew52
    [5284241320] = true, -- APIPIIIEEEE / apiphbp
    [9058511261] = true, -- Hayyaaa / CHILLBoyxHayaa
    [8956748924] = true, -- SON KE 2? / S0N899
}

------------------- CONFIG -------------------
local MIN_RADIUS             = 5
local MAX_RADIUS             = 1000
local DEFAULT_RADIUS         = 350
local DEFAULT_ANTENNA_RADIUS = 400 -- visual only

local TELEPORT_COOLDOWN      = 0.25
local ALERT_SOUND_ID         = "rbxassetid://12221967"

-- Titik teleport (KOORDINAT + LOOKAT)
local TELEPORT_POINTS = {
    { label = "Dermaga 6", enabled = true, position = Vector3.new(-368.31, 113.40, -271.59), lookAt = Vector3.new(-367.80, 113.40, -281.58) },
    { label = "Air Terjun 1", enabled = true, position = Vector3.new(444.43, 105.31, 121.44), lookAt = Vector3.new(454.11, 105.31, 123.94) },
    { label = "Tebing 1", enabled = true, position = Vector3.new(-541.13, 3.33, -287.76), lookAt = Vector3.new(-550.58, 3.33, -291.02) },
    { label = "Tgh Laut (Atas)", enabled = true, position = Vector3.new(-157.86, 18.84, -2791.60), lookAt = Vector3.new(-157.25, 18.84, -2801.58) },
    { label = "ES Blok 1 (Tgh Laut)", enabled = true, position = Vector3.new(1076.52, 4.12, -2706.71), lookAt = Vector3.new(1084.09, 4.12, -2713.25) },

    { label = "Tebing 2", enabled = true, position = Vector3.new(-454.22, 4.90, 170.74), lookAt = Vector3.new(-463.76, 4.90, 173.76) },
    { label = "ES Blok Tebal 1 (Tgh Laut)", enabled = true, position = Vector3.new(99.24, 1.65, -1939.53), lookAt = Vector3.new(109.16, 1.65, -1938.27) },
    { label = "Air Terjun 2", enabled = true, position = Vector3.new(86.04, 106.88, 206.57),   lookAt = Vector3.new(80.44, 106.88, 198.29) },
    { label = "ES Blok 2 (Tgh Laut 2)", enabled = true, position = Vector3.new(1101.25, 3.01, -2552.80), lookAt = Vector3.new(1111.13, 3.01, -2551.27) },
    { label = "ES Blok 3 (Agak Jauh Menara)",                 enabled = true, position = Vector3.new(-1186.69, 2.94, -242.95), lookAt = Vector3.new(-1196.55, 2.94, -241.30) },

    { label = "Air Terjun 3",            enabled = true, position = Vector3.new(116.39, 165.93, 216.15),  lookAt = Vector3.new(109.42, 165.93, 223.32) },
    { label = "ES Blok 4 (Jauh Menara)",  enabled = true, position = Vector3.new(-2250.39, 3.06, 334.49), lookAt = Vector3.new(-2259.08, 3.06, 339.44) },
    { label = "Dermaga 8 (Atas Bukit)",  enabled = true, position = Vector3.new(116.39, 165.93, 216.15),  lookAt = Vector3.new(109.42, 165.93, 223.32) },
    { label = "Tgh Laut (Bawah)",        enabled = true, position = Vector3.new(-176.23, 2.28, -2745.61), lookAt = Vector3.new(-175.52, 2.28, -2735.64) },
    { label = "Tebing 3",                enabled = true, position = Vector3.new(252.49, 1.88, 384.64), lookAt = Vector3.new(257.99, 1.88, 392.99) },

    { label = "ES Blok Tebal 2 (Tgh Laut)",      enabled = true, position = Vector3.new(-369.41, 15.05, -1564.48), lookAt = Vector3.new(-359.42, 15.05, -1565.08) },
    { label = "Tebing 4",                enabled = true, position = Vector3.new(440.76, 1.23, 201.92), lookAt = Vector3.new(440.11, 1.23, 211.89) },
    { label = "ES Blok Tebal 3 (Tgh Laut)",         enabled = true, position = Vector3.new(1692.04, 3.39, -1297.28), lookAt = Vector3.new(1699.93, 3.39, -1303.42) },
}

local function getPointCFrame(point)
    if not point or not point.position then
        return CFrame.new()
    end
    if point.lookAt and typeof(point.lookAt) == "Vector3" then
        local dir = point.lookAt - point.position
        if dir.Magnitude > 0.001 then
            return CFrame.new(point.position, point.lookAt)
        end
    end
    return CFrame.new(point.position)
end

------------------- TELEPORT POINT SEQUENCE -------------------
local lastTeleportIndex = 0

local function getNextTeleportPoint()
    local active = {}
    for i, p in ipairs(TELEPORT_POINTS) do
        if p.enabled and p.position then
            table.insert(active, i)
        end
    end
    if #active == 0 then return nil, nil end

    local idxInActive
    if lastTeleportIndex ~= 0 then
        for i, idx in ipairs(active) do
            if idx == lastTeleportIndex then
                idxInActive = i
                break
            end
        end
    end

    local nextPos = idxInActive and ((idxInActive % #active) + 1) or 1
    local chosenIndex = active[nextPos]
    lastTeleportIndex = chosenIndex
    return TELEPORT_POINTS[chosenIndex], chosenIndex
end

------------------- REMOTES (AUTO FISHING INDO HANGOUT) -------------------
local RodRemoteEvent
local SellFishRemoteFunction

do
    local ok, eventsFolder = pcall(function()
        return replicatedStorage:WaitForChild("Events", 5)
    end)
    if ok and eventsFolder then
        local remoteFolder = eventsFolder:FindFirstChild("RemoteEvent")
        if remoteFolder then
            RodRemoteEvent         = remoteFolder:FindFirstChild("Rod")
            SellFishRemoteFunction = remoteFolder:FindFirstChild("SellFish")
        else
            warn("[16AxaTab_NearestPlayer] Folder 'RemoteEvent' tidak ditemukan di Events.")
        end
    else
        warn("[16AxaTab_NearestPlayer] Folder 'Events' tidak ditemukan di ReplicatedStorage.")
    end
end

------------------- STATE -------------------
local alive               = true
local connections         = {}

local featureEnabled       = true
local currentRadius        = DEFAULT_RADIUS
local currentAntennaRadius = DEFAULT_ANTENNA_RADIUS
local lastTeleportTime     = 0
local alertSound           = nil

local filterAllPlayers    = true
local filterOnlyAdmin     = true
local excludeFriends      = true
local emoteSitEnabled     = true

local radiusBox, radiusLabel
local antennaRadiusBox, antennaRadiusLabel
local statusLabel, toggleButton
local filterAllBtn, filterAdminBtn, filterFriendsBtn, emoteSitBtn, autoFishBtn

local excludeScroll
local excludedPlayersManual = {} -- [userId] = true
local refreshExcludeList

local placeNameCache = {}
local getWitaTimestamp -- forward declaration

local pendingTeleportData = nil
local pendingTeleportConn = nil

local lastDetectionTick   = 0
local DETECTION_INTERVAL  = 0.1 -- 10x per detik

-- AUTOFISH STATE (LOKAL, LOGIC INDOHANGOUT)
local autoFishingNPEnabled  = false   -- default OFF
local isCasting             = false  -- sedang lempar + minigame aktif
local reelingConn           = nil
local rodEventConn          = nil
local autofishLoopRunning   = false
local teleportAutoFishToken = 0

-- ANTENA VISUAL STATE
local antennaAttachLocal   = nil
local antennaObjects       = {}           -- [player] = {attachTarget, beam, billboard, label}

------------------- LOCAL CHARACTER CACHE -------------------
local currentChar = localPlayer.Character
local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")

------------------- HELPER: CONNECT WRAPPER -------------------
local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(connections, c)
    return c
end

local function onCharacterAdded(char)
    currentChar = char
    currentRoot = nil
    task.spawn(function()
        local hrp = nil
        pcall(function()
            hrp = char:WaitForChild("HumanoidRootPart", 5)
        end)
        if hrp and hrp.Parent == char then
            currentRoot = hrp
        end
    end)
end

if currentChar then
    onCharacterAdded(currentChar)
end

bind(localPlayer.CharacterAdded, onCharacterAdded)

local function getLocalRoot()
    return currentRoot, currentChar
end

------------------- ROD PREFERENCE (SCAN SEKALI DI AWAL) -------------------
local PREFERRED_ROD_NAMES = {
    "wave rod",
    "piranha rod",
    "vip rod",
    "thermo rod",
}

local preferredRodName = nil -- disimpan sekali, berdasarkan scan awal

local function initPreferredRodName()
    if preferredRodName ~= nil then
        return preferredRodName
    end

    local function scanContainer(container)
        if not container then return end
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("Tool") then
                local nameLower = c.Name:lower()
                for _, want in ipairs(PREFERRED_ROD_NAMES) do
                    if nameLower == want then
                        preferredRodName = c.Name
                        return
                    end
                end
            end
        end
    end

    local char     = currentChar or localPlayer.Character
    local backpack = localPlayer:FindFirstChild("Backpack")

    scanContainer(char)
    if not preferredRodName then
        scanContainer(backpack)
    end

    return preferredRodName
end

local function findRodInContainer(container, targetNameLower)
    if not container then return nil end
    local fallback = nil
    for _, c in ipairs(container:GetChildren()) do
        if c:IsA("Tool") then
            local nameLower = c.Name:lower()
            if targetNameLower and nameLower == targetNameLower then
                return c
            end
            if (not fallback) and nameLower:find("rod") then
                fallback = c
            end
        end
    end
    return fallback
end

------------------- HELPER: NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = dur or 3
        })
    end)
end

------------------- HELPER: PLACE NAME + JOB SHORT -------------------
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
        return marketplace:GetProductInfo(placeId)
    end)
    if ok and info and info.Name then
        name = tostring(info.Name)
    end

    placeNameCache[placeId] = name
    return name
end

------------------- HELPER: UI CREATOR -------------------
local function makeCorner(gui, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or 8)
    c.Parent = gui
    return c
end

local function makeLabel(parent, name, text, size, pos, props)
    local l = Instance.new("TextLabel")
    l.Name      = name
    l.Size      = size
    l.Position  = pos or UDim2.new()
    l.BackgroundTransparency = 1
    l.Font      = props and props.Font      or Enum.Font.Gotham
    l.TextSize  = props and props.TextSize  or 12
    l.TextColor3= props and props.TextColor3 or Color3.fromRGB(40,40,60)
    l.TextXAlignment = props and props.XAlign or Enum.TextXAlignment.Left
    l.TextYAlignment = props and props.YAlign or Enum.TextYAlignment.Center
    l.TextWrapped    = props and props.Wrapped or false
    l.TextTruncate   = props and props.Truncate or Enum.TextTruncate.None
    l.Text           = text or ""
    l.Parent         = parent
    return l
end

local function makeButton(parent, name, text, size, pos, bg, tc, ts)
    local b = Instance.new("TextButton")
    b.Name     = name
    b.Size     = size
    b.Position = pos or UDim2.new()
    b.BackgroundColor3 = bg or Color3.fromRGB(228,232,248)
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = true
    b.Font      = Enum.Font.GothamBold
    b.Text      = text or ""
    b.TextSize  = ts or 13
    b.TextColor3= tc or Color3.fromRGB(45,45,70)
    b.Parent    = parent
    makeCorner(b, 8)
    return b
end

------------------- HELPER: ALERT SOUND -------------------
local function ensureAlertSound()
    if alertSound and alertSound.Parent then
        return alertSound
    end

    local s = Instance.new("Sound")
    s.Name   = "NearestPlayerAlert"
    s.SoundId= ALERT_SOUND_ID
    s.Volume = 1
    s.PlayOnRemove = false
    s.Parent = frame
    alertSound = s
    return s
end

local function playAlert()
    local s = ensureAlertSound()
    pcall(function()
        s:Play()
    end)
end

------------------- HELPER: RADIUS -------------------
local function clampRadius(r)
    r = tonumber(r) or DEFAULT_RADIUS
    if r < MIN_RADIUS then r = MIN_RADIUS end
    if r > MAX_RADIUS then r = MAX_RADIUS end
    return math.floor(r + 0.5)
end

local function setRadiusFromText(text)
    local n = tonumber(text)
    if not n then
        notify("Nearest Player", "Input Studs tidak valid, gunakan angka.", 2)
        if radiusBox then
            radiusBox.Text = tostring(currentRadius)
        end
        return
    end

    local newR = clampRadius(n)
    currentRadius = newR
    if radiusBox then
        radiusBox.Text = tostring(newR)
    end
    if radiusLabel then
        radiusLabel.Text = string.format("Radius aktif: %d studs", newR)
    end
end

local function setAntennaRadiusFromText(text)
    local n = tonumber(text)
    if not n then
        notify("Nearest Player", "Input Antena Studs tidak valid, gunakan angka.", 2)
        if antennaRadiusBox then
            antennaRadiusBox.Text = tostring(currentAntennaRadius)
        end
        return
    end

    local newR = clampRadius(n)
    currentAntennaRadius = newR
    if antennaRadiusBox then
        antennaRadiusBox.Text = tostring(newR)
    end
    if antennaRadiusLabel then
        antennaRadiusLabel.Text = string.format("Antena radius: %d studs", newR)
    end
end

------------------- HELPER: FILTER MODE -------------------
local function getDetectionMode()
    if filterOnlyAdmin and not filterAllPlayers then
        return "admin"
    elseif filterAllPlayers then
        return "all"
    else
        return "none"
    end
end

local function modeToText(mode)
    if mode == "admin" then
        return "Only Admin"
    elseif mode == "all" then
        return "All Players"
    else
        return "Disabled"
    end
end

------------------- HELPER: FRIEND CHECK (CACHED) -------------------
local friendCache = {}
local friendStates = {} -- [userId] = { inRadius, everInRadius, lastDistance, displayName, userName }
local lastFriendLeaveMapSent = {} -- anti-duplikasi leaveMap

-- PATCH: daftar friend yang sedang ada di server (lebih ringan daripada scan semua tiap tick)
local friendPlayers = {} -- [userId] = Player
local friendSession = 0
local friendSessionSeen = {} -- [userId] = sessionId

local function isFriend(userId)
    local cached = friendCache[userId]
    if cached ~= nil then
        return cached
    end

    local ok, res = pcall(function()
        return localPlayer:IsFriendsWith(userId)
    end)
    local val = ok and res or false
    friendCache[userId] = val
    return val
end

------------------- WEBHOOK SENDER (SINGLE, NO DOUBLE) -------------------
local REQUEST_FUNC =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (fluxus and fluxus.request)
    or (krnl and krnl.request)

local lastWebhookWarn = 0
local function postDiscordAsync(payload)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    task.spawn(function()
        local ok, err = pcall(function()
            local json = httpService:JSONEncode(payload)
            if REQUEST_FUNC then
                REQUEST_FUNC({
                    Url     = WEBHOOK_URL,
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = json,
                })
            else
                httpService:PostAsync(WEBHOOK_URL, json, Enum.HttpContentType.ApplicationJson)
            end
        end)
        if not ok then
            local now = os.clock()
            if (now - lastWebhookWarn) > 5 then
                lastWebhookWarn = now
                warn("[NearestPlayer] Gagal kirim webhook:", err)
            end
        end
    end)
end

------------------- UI HEADER -------------------
makeLabel(
    frame, "Header", "🧭 Nearest Player v10.8 (❄ Winter)",
    UDim2.new(1,-10,0,22), UDim2.new(0,5,0,6),
    { Font=Enum.Font.GothamBold, TextSize=15, TextColor3=Color3.fromRGB(40,40,60), XAlign=Enum.TextXAlignment.Left }
)

makeLabel(
    frame,"Sub","Jika ada player lain mendekat radius tertentu di sekitar karakter-mu, otomatis teleport berurutan ke titik aman + kirim log ke Discord. Bila kamu lagi Reeling, teleport DI-TUNGGU sampai progress 100% dulu. Setelah teleport, Emote Duduk (ON) + Auto Fishing lokal akan jalan otomatis. Di luar radius teleport tapi masih dekat, akan muncul antena biru dari badanmu ke badan player + namebox di atas kepala (visual saja). Antena tidak hilang selama target masih dalam Antena Radius.",
    UDim2.new(1,-10,0,62),UDim2.new(0,5,0,26),
    { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(90,90,120),XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
)

------------------- BODY SCROLL (GLOBAL) -------------------
local body = Instance.new("ScrollingFrame")
body.Name = "BodyScroll"
body.Position = UDim2.new(0,0,0,74)
body.Size = UDim2.new(1,0,1,-74)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.CanvasSize = UDim2.new(0,0,0,0)
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
bind(bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    body.CanvasSize = UDim2.new(0,0,0,bodyLayout.AbsoluteContentSize.Y+8)
end)

------------------- CARD 1: CONTROL & STATUS -------------------
local ctrlCard = Instance.new("Frame")
ctrlCard.Name = "CtrlCard"
ctrlCard.Size = UDim2.new(1,0,0,340)
ctrlCard.BackgroundColor3 = Color3.fromRGB(236,238,248)
ctrlCard.BorderSizePixel  = 0
ctrlCard.Parent = body
makeCorner(ctrlCard,10)
local ctrlStroke = Instance.new("UIStroke", ctrlCard)
ctrlStroke.Thickness    = 1
ctrlStroke.Color        = Color3.fromRGB(210,210,230)
ctrlStroke.Transparency = 0.3

local ctrlScroll = Instance.new("ScrollingFrame")
ctrlScroll.Name = "CtrlScroll"
ctrlScroll.Position = UDim2.new(0,0,0,0)
ctrlScroll.Size = UDim2.new(1,0,1,0)
ctrlScroll.BackgroundTransparency = 1
ctrlScroll.BorderSizePixel = 0
ctrlScroll.ScrollBarThickness = 3
ctrlScroll.ScrollingDirection = Enum.ScrollingDirection.XY
ctrlScroll.CanvasSize = UDim2.new(0,0,0,0)
ctrlScroll.Parent = ctrlCard

local ctrlPad = Instance.new("UIPadding", ctrlScroll)
ctrlPad.PaddingTop    = UDim.new(0,6)
ctrlPad.PaddingBottom = UDim.new(0,6)
ctrlPad.PaddingLeft   = UDim.new(0,6)
ctrlPad.PaddingRight  = UDim.new(0,6)

local ctrlLayout = Instance.new("UIListLayout", ctrlScroll)
ctrlLayout.FillDirection = Enum.FillDirection.Vertical
ctrlLayout.SortOrder     = Enum.SortOrder.LayoutOrder
ctrlLayout.Padding       = UDim.new(0,6)
ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
bind(ctrlLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    local abs = ctrlLayout.AbsoluteContentSize
    ctrlScroll.CanvasSize = UDim2.new(0, abs.X + 4, 0, abs.Y + 4)
end)

-- Toggle utama
toggleButton = makeButton(
    ctrlScroll,
    "ToggleNearest",
    "Nearest Player: ON",
    UDim2.new(1,-10,0,28),
    UDim2.new(),
    Color3.fromRGB(70,180,110),
    Color3.fromRGB(255,255,255),
    13
)

-- Radius label
radiusLabel = makeLabel(
    ctrlScroll,
    "RadiusLabel",
    string.format("Radius aktif: %d studs", currentRadius),
    UDim2.new(1,-10,0,18),
    UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(70,70,115), XAlign=Enum.TextXAlignment.Left }
)

-- Radius row
local radiusRow = Instance.new("Frame")
radiusRow.Name = "RadiusRow"
radiusRow.Size = UDim2.new(1,-10,0,26)
radiusRow.BackgroundTransparency = 1
radiusRow.Parent = ctrlScroll

local rrLayout = Instance.new("UIListLayout", radiusRow)
rrLayout.FillDirection = Enum.FillDirection.Horizontal
rrLayout.SortOrder     = Enum.SortOrder.LayoutOrder
rrLayout.Padding       = UDim.new(0,6)
rrLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local rrLabel = makeLabel(
    radiusRow,
    "Label",
    "Input Studs Teleport (10–1000):",
    UDim2.new(0,170,1,0),
    UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(80,80,120), XAlign=Enum.TextXAlignment.Left }
)

radiusBox = Instance.new("TextBox")
radiusBox.Name = "RadiusBox"
radiusBox.Size = UDim2.new(0,70,1,0)
radiusBox.BackgroundColor3 = Color3.fromRGB(255,255,255)
radiusBox.BorderSizePixel  = 0
radiusBox.Font = Enum.Font.Gotham
radiusBox.TextSize = 11
radiusBox.TextColor3 = Color3.fromRGB(40,40,70)
radiusBox.TextXAlignment = Enum.TextXAlignment.Center
radiusBox.Text = tostring(currentRadius)
radiusBox.PlaceholderText = "Teleport"
radiusBox.ClearTextOnFocus = false
radiusBox.Parent = radiusRow
makeCorner(radiusBox,6)

-- Antena label
antennaRadiusLabel = makeLabel(
    ctrlScroll,
    "AntennaLabel",
    string.format("Antena radius: %d studs", currentAntennaRadius),
    UDim2.new(1,-10,0,18),
    UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(50,90,150), XAlign=Enum.TextXAlignment.Left }
)

-- Antena row
local antennaRow = Instance.new("Frame")
antennaRow.Name = "AntennaRow"
antennaRow.Size = UDim2.new(1,-10,0,26)
antennaRow.BackgroundTransparency = 1
antennaRow.Parent = ctrlScroll

local arLayout = Instance.new("UIListLayout", antennaRow)
arLayout.FillDirection = Enum.FillDirection.Horizontal
arLayout.SortOrder     = Enum.SortOrder.LayoutOrder
arLayout.Padding       = UDim.new(0,6)
arLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local arLabel = makeLabel(
    antennaRow,
    "Label",
    "Input Antena Studs (visual):",
    UDim2.new(0,170,1,0),
    UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(80,80,120), XAlign=Enum.TextXAlignment.Left }
)

antennaRadiusBox = Instance.new("TextBox")
antennaRadiusBox.Name = "AntennaRadiusBox"
antennaRadiusBox.Size = UDim2.new(0,70,1,0)
antennaRadiusBox.BackgroundColor3 = Color3.fromRGB(255,255,255)
antennaRadiusBox.BorderSizePixel  = 0
antennaRadiusBox.Font = Enum.Font.Gotham
antennaRadiusBox.TextSize = 11
antennaRadiusBox.TextColor3 = Color3.fromRGB(40,40,70)
antennaRadiusBox.TextXAlignment = Enum.TextXAlignment.Center
antennaRadiusBox.Text = tostring(currentAntennaRadius)
antennaRadiusBox.PlaceholderText = "Antena"
antennaRadiusBox.ClearTextOnFocus = false
antennaRadiusBox.Parent = antennaRow
makeCorner(antennaRadiusBox,6)

-- Status
statusLabel = makeLabel(
    ctrlScroll,
    "StatusLabel",
    "Status: Menunggu player mendekat...",
    UDim2.new(1,-10,0,18),
    UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(90,90,130), XAlign=Enum.TextXAlignment.Left }
)

-- Filter row
local filterScroll = Instance.new("ScrollingFrame")
filterScroll.Name = "FilterScroll"
filterScroll.Size = UDim2.new(1,-10,0,28)
filterScroll.BackgroundTransparency = 1
filterScroll.BorderSizePixel = 0
filterScroll.ScrollBarThickness = 3
filterScroll.ScrollingDirection = Enum.ScrollingDirection.X
filterScroll.CanvasSize = UDim2.new(0,0,0,0)
filterScroll.Parent = ctrlScroll

local frPad = Instance.new("UIPadding", filterScroll)
frPad.PaddingLeft  = UDim.new(0,0)
frPad.PaddingRight = UDim.new(0,0)

local frLayout = Instance.new("UIListLayout", filterScroll)
frLayout.FillDirection = Enum.FillDirection.Horizontal
frLayout.SortOrder     = Enum.SortOrder.LayoutOrder
frLayout.Padding       = UDim.new(0,6)
frLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bind(frLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    local abs = frLayout.AbsoluteContentSize
    filterScroll.CanvasSize = UDim2.new(0, abs.X + 4, 0, abs.Y)
end)

filterAllBtn = makeButton(
    filterScroll,
    "FilterAll",
    "All Players: ON",
    UDim2.new(0,110,1,0),
    UDim2.new(),
    Color3.fromRGB(90,150,220),
    Color3.fromRGB(255,255,255),
    11
)

filterAdminBtn = makeButton(
    filterScroll,
    "FilterAdmin",
    "Only Admin: ON",
    UDim2.new(0,110,1,0),
    UDim2.new(),
    Color3.fromRGB(180,130,70),
    Color3.fromRGB(255,255,255),
    11
)

filterFriendsBtn = makeButton(
    filterScroll,
    "FilterFriends",
    "Exclusion Friends: ON",
    UDim2.new(0,150,1,0),
    UDim2.new(),
    Color3.fromRGB(110,190,140),
    Color3.fromRGB(255,255,255),
    11
)

emoteSitBtn = makeButton(
    filterScroll,
    "EmoteSit",
    "Emote Duduk: ON",
    UDim2.new(0,140,1,0),
    UDim2.new(),
    Color3.fromRGB(150,120,220),
    Color3.fromRGB(255,255,255),
    11
)

autoFishBtn = makeButton(
    filterScroll,
    "AutoFishNP",
    "AutoFishing Lokal: ON",
    UDim2.new(0,160,1,0),
    UDim2.new(),
    Color3.fromRGB(70,180,110),
    Color3.fromRGB(255,255,255),
    11
)

local function updateToggleVisual()
    if not toggleButton then return end

    if featureEnabled then
        toggleButton.Text = "Nearest Player: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(70, 180, 110)
        toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        toggleButton.Text = "Nearest Player: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
        toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function refreshFilterVisual()
    if filterAllBtn then
        if filterAllPlayers then
            filterAllBtn.Text = "All Players: ON"
            filterAllBtn.BackgroundColor3 = Color3.fromRGB(90, 150, 220)
            filterAllBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            filterAllBtn.Text = "All Players: OFF"
            filterAllBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
            filterAllBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if filterAdminBtn then
        if filterOnlyAdmin then
            filterAdminBtn.Text = "Only Admin: ON"
            filterAdminBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 70)
            filterAdminBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            filterAdminBtn.Text = "Only Admin: OFF"
            filterAdminBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
            filterAdminBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if filterFriendsBtn then
        if excludeFriends then
            filterFriendsBtn.Text = "Exclusion Friends: ON"
            filterFriendsBtn.BackgroundColor3 = Color3.fromRGB(110, 190, 140)
            filterFriendsBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            filterFriendsBtn.Text = "Exclusion Friends: OFF"
            filterFriendsBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
            filterFriendsBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if emoteSitBtn then
        if emoteSitEnabled then
            emoteSitBtn.Text = "Emote Duduk: ON"
            emoteSitBtn.BackgroundColor3 = Color3.fromRGB(150, 120, 220)
            emoteSitBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            emoteSitBtn.Text = "Emote Duduk: OFF"
            emoteSitBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
            emoteSitBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end

    if autoFishBtn then
        if autoFishingNPEnabled then
            autoFishBtn.Text = "AutoFishing Lokal: ON"
            autoFishBtn.BackgroundColor3 = Color3.fromRGB(70,180,110)
            autoFishBtn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            autoFishBtn.Text = "AutoFishing Lokal: OFF"
            autoFishBtn.BackgroundColor3 = Color3.fromRGB(200,200,210)
            autoFishBtn.TextColor3 = Color3.fromRGB(60,60,80)
        end
    end
end

updateToggleVisual()
refreshFilterVisual()

-- Header Exclude Players lainnya
makeLabel(
    ctrlScroll,
    "ExcludeHeader",
    "Exclude Players lainnya (non-friend). Centang untuk mengabaikan player tersebut dari deteksi / antena:",
    UDim2.new(1,-10,0,30),
    UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(80,80,120),
      XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
)

excludeScroll = Instance.new("ScrollingFrame")
excludeScroll.Name = "ExcludePlayersScroll"
excludeScroll.Size = UDim2.new(1,-10,0,100)
excludeScroll.BackgroundTransparency = 1
excludeScroll.BorderSizePixel = 0
excludeScroll.ScrollBarThickness = 3
excludeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
excludeScroll.CanvasSize = UDim2.new(0,0,0,0)
excludeScroll.Parent = ctrlScroll

local exPad = Instance.new("UIPadding", excludeScroll)
exPad.PaddingTop    = UDim.new(0,2)
exPad.PaddingBottom = UDim.new(0,2)
exPad.PaddingLeft   = UDim.new(0,0)
exPad.PaddingRight  = UDim.new(0,2)

local exLayout = Instance.new("UIListLayout")
exLayout.Parent = excludeScroll
exLayout.FillDirection = Enum.FillDirection.Vertical
exLayout.SortOrder     = Enum.SortOrder.LayoutOrder
exLayout.Padding       = UDim.new(0,4)
exLayout.VerticalAlignment = Enum.VerticalAlignment.Top
bind(exLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    local abs = exLayout.AbsoluteContentSize
    excludeScroll.CanvasSize = UDim2.new(0, 0, 0, abs.Y + 4)
end)

------------------- SMART REELING HELPER (UNTUK TELEPORT GATE) -------------------
getWitaTimestamp = function()
    local utcNow = os.time(os.date("!*t"))
    local witaNow = utcNow + (8 * 60 * 60)
    local t = os.date("!*t", witaNow)
    return string.format("%02d-%02d-%04d %02d:%02d:%02d WITA", t.day, t.month, t.year, t.hour, t.min, t.sec)
end

local function getReelingGuiState()
    local pg
    pcall(function()
        pg = localPlayer:FindFirstChildOfClass("PlayerGui")
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

local function isReelingActiveAndProgress()
    local state = getReelingGuiState()
    if not state then
        return false, 0
    end
    return true, state.ratio or 0
end

local function clearPendingTeleportMonitor()
    if pendingTeleportConn then
        pcall(function()
            pendingTeleportConn:Disconnect()
        end)
    end
    pendingTeleportConn = nil
    pendingTeleportData = nil
end

------------------- AUTOFISH CORE (INDOHANGOUT STYLE) -------------------
local function stopSmartReeling()
    if reelingConn then
        pcall(function()
            reelingConn:Disconnect()
        end)
        reelingConn = nil
    end
end

local function getRodTool()
    local char     = currentChar or localPlayer.Character
    local backpack = localPlayer:FindFirstChild("Backpack")

    local pref = initPreferredRodName()
    if pref then
        local prefLower = pref:lower()
        local tool = findRodInContainer(char, prefLower) or findRodInContainer(backpack, prefLower)
        if tool then
            return tool
        end

        preferredRodName = nil
        pref = initPreferredRodName()
        if pref then
            local prefLower2 = pref:lower()
            tool = findRodInContainer(char, prefLower2) or findRodInContainer(backpack, prefLower2)
            if tool then
                return tool
            end
        end
    end

    local anyRod = findRodInContainer(char, nil)
    if anyRod then
        return anyRod
    end
    return findRodInContainer(backpack, nil)
end

local function ensureRodEquipped(preferredRod)
    local rod = preferredRod or getRodTool()
    if not rod then
        return nil
    end

    local char = currentChar or localPlayer.Character
    if char and rod.Parent ~= char then
        rod.Parent = char
    end

    return rod
end

local function startSmartReeling(rodTool)
    stopSmartReeling()
    if not runService or not RodRemoteEvent or not rodTool then return end

    reelingConn = runService.RenderStepped:Connect(function()
        if not alive or not featureEnabled or not autoFishingNPEnabled then
            return
        end

        local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
        local reelingGui = pg and pg:FindFirstChild("Reeling")
        if not (reelingGui and reelingGui.Enabled) then
            return
        end

        local frameGui = reelingGui:FindFirstChild("Frame")
        if not frameGui then return end

        local midFrame   = frameGui:FindFirstChild("Frame")
        local whiteBar   = midFrame and midFrame:FindFirstChild("WhiteBar")
        local redBar     = midFrame and midFrame:FindFirstChild("RedBar")
        local progressBg = frameGui:FindFirstChild("ProgressBg")
        local progressBar= progressBg and progressBg:FindFirstChild("ProgressBar")

        if whiteBar and redBar then
            local targetCenter = redBar.Position.X.Scale + redBar.Size.X.Scale * 0.5
            local halfWidth    = whiteBar.Size.X.Scale * 0.5
            local newX         = math.clamp(targetCenter - halfWidth, 0, 1 - whiteBar.Size.X.Scale)
            whiteBar.Position  = UDim2.new(newX, 0, whiteBar.Position.Y.Scale, whiteBar.Position.Y.Offset)
        end

        if progressBar then
            local sx = progressBar.Size.X.Scale
            if sx >= 1 then
                pcall(function()
                    RodRemoteEvent:FireServer("Reeling", rodTool, true)
                end)
            end
        end
    end)
end

local function throwRod(rodTool)
    if not RodRemoteEvent or not rodTool then return end

    local mouse
    local hitCFrame
    local ok = pcall(function()
        mouse = localPlayer:GetMouse()
        hitCFrame = mouse and mouse.Hit
    end)

    if not ok or not hitCFrame then
        return
    end

    pcall(function()
        RodRemoteEvent:FireServer("Throw", rodTool, hitCFrame)
    end)
    isCasting = true
end

local function setupRodEventListener()
    if rodEventConn then
        pcall(function()
            rodEventConn:Disconnect()
        end)
        rodEventConn = nil
    end
    if not RodRemoteEvent then return end

    rodEventConn = RodRemoteEvent.OnClientEvent:Connect(function(eventName, _, flag)
        if (eventName == "Reeling" and flag) or eventName == "StopShake" or eventName == "Stopshake" then
            isCasting = false
            if not alive or not featureEnabled or not autoFishingNPEnabled then return end

            task.delay(0.5, function()
                if not alive or not featureEnabled or not autoFishingNPEnabled then return end

                local rod = ensureRodEquipped()
                if not rod then
                    if statusLabel then
                        statusLabel.Text = "Status: Rod tidak ditemukan (setelah Reeling)."
                    end
                    return
                end

                if statusLabel then
                    statusLabel.Text = "Status: AutoThrow (setelah Reeling selesai)..."
                end

                throwRod(rod)
                task.wait(1)
                startSmartReeling(rod)
            end)
        end
    end)
end

local function startAutofishLoop()
    if autofishLoopRunning then return end
    if not RodRemoteEvent then return end

    autofishLoopRunning = true
    task.spawn(function()
        while alive and featureEnabled and autoFishingNPEnabled do
            if not isCasting then
                local rod = ensureRodEquipped()
                if rod then
                    if statusLabel then
                        statusLabel.Text = "Status: Melempar (Throw)..."
                    end

                    throwRod(rod)
                    task.wait(1)
                    startSmartReeling(rod)
                else
                    if statusLabel then
                        statusLabel.Text = "Status: Rod tidak ditemukan (AutoFishing)."
                    end
                end
            end
            task.wait(0.5)
        end
        autofishLoopRunning = false
    end)
end

local function stopAutofish()
    autoFishingNPEnabled = false
    isCasting = false
    stopSmartReeling()
    if rodEventConn then
        pcall(function()
            rodEventConn:Disconnect()
        end)
        rodEventConn = nil
    end
end

local function ensureAutoFishingAfterTeleport()
    if not RodRemoteEvent then
        return
    end

    teleportAutoFishToken += 1
    local myToken = teleportAutoFishToken

    isCasting = true
    stopSmartReeling()

    task.delay(3, function()
        if not alive or not featureEnabled then return end
        if myToken ~= teleportAutoFishToken then return end

        local rod = ensureRodEquipped()
        if not rod then
            if statusLabel then
                statusLabel.Text = "Status: Rod tidak ditemukan setelah teleport."
            end
            isCasting = false
            return
        end

        if statusLabel then
            statusLabel.Text = "Status: AutoThrow setelah teleport..."
        end

        throwRod(rod)
        task.wait(1)

        if autoFishingNPEnabled then
            setupRodEventListener()
            startSmartReeling(rod)
            if featureEnabled then
                startAutofishLoop()
            end
        else
            isCasting = false
        end
    end)
end

------------------- EMOTE DUDUK -------------------
local function playSitEmoteIfEnabled()
    if not emoteSitEnabled then return end
    if not virtualInput then return end

    task.spawn(function()
        pcall(function()
            virtualInput:SendKeyEvent(true, Enum.KeyCode.Period, false, game)
            task.wait(0.05)
            virtualInput:SendKeyEvent(false, Enum.KeyCode.Period, false, game)
        end)

        task.wait(0.15)

        pcall(function()
            virtualInput:SendKeyEvent(true, Enum.KeyCode.One, false, game)
            task.wait(0.05)
            virtualInput:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        end)
    end)
end

------------------- BODY PART HELPER -------------------
local function getBodyPart(char)
    if not char then return nil end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

------------------- ANTENA VISUAL (MULTI PLAYER) -------------------
local function destroyAntennaForPlayer(plr)
    local obj = antennaObjects[plr]
    if not obj then return end

    if obj.beam then pcall(function() obj.beam:Destroy() end) end
    if obj.attachTarget then pcall(function() obj.attachTarget:Destroy() end) end
    if obj.billboard then pcall(function() obj.billboard:Destroy() end) end

    antennaObjects[plr] = nil
end

local function clearAllAntennas()
    for plr, _ in pairs(antennaObjects) do
        destroyAntennaForPlayer(plr)
    end
    antennaObjects = {}

    if antennaAttachLocal then
        pcall(function() antennaAttachLocal:Destroy() end)
    end
    antennaAttachLocal = nil
end

local function ensureAntennaForPlayer(plr, charLocal, rootLocal, charTarget, hrpTarget, distance)
    if not (plr and charLocal and rootLocal and charTarget and hrpTarget) then return end

    local localBody  = getBodyPart(charLocal)   or rootLocal
    local targetBody = getBodyPart(charTarget)  or hrpTarget
    if not (localBody and targetBody) then return end

    if (not antennaAttachLocal) or antennaAttachLocal.Parent ~= localBody then
        if antennaAttachLocal then pcall(function() antennaAttachLocal:Destroy() end) end
        antennaAttachLocal = Instance.new("Attachment")
        antennaAttachLocal.Name = "AxaNearest_AntennaLocal"
        antennaAttachLocal.Position = Vector3.new(0, 0, 0)
        antennaAttachLocal.Parent = localBody
    end

    local obj = antennaObjects[plr]
    if not obj then
        obj = {}
        antennaObjects[plr] = obj
    end

    if (not obj.attachTarget) or obj.attachTarget.Parent ~= targetBody then
        if obj.attachTarget then pcall(function() obj.attachTarget:Destroy() end) end
        obj.attachTarget = Instance.new("Attachment")
        obj.attachTarget.Name = "AxaNearest_AntennaTarget"
        obj.attachTarget.Position = Vector3.new(0, 0, 0)
        obj.attachTarget.Parent = targetBody
    end

    if (not obj.beam) or (not obj.beam.Parent) then
        if obj.beam then pcall(function() obj.beam:Destroy() end) end
        obj.beam = Instance.new("Beam")
        obj.beam.Name = "AxaNearest_AntennaBeam"
        obj.beam.FaceCamera = true
        obj.beam.Width0 = 0.15
        obj.beam.Width1 = 0.15
        obj.beam.LightEmission = 1
        obj.beam.LightInfluence = 0
        obj.beam.Color = ColorSequence.new(Color3.fromRGB(80,170,255))
        obj.beam.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 0.2),
        }
        obj.beam.Segments = 16
        obj.beam.TextureMode = Enum.TextureMode.Stretch
        obj.beam.CurveSize0 = 0
        obj.beam.CurveSize1 = 0
        obj.beam.Parent = charTarget
    end

    obj.beam.Attachment0 = antennaAttachLocal
    obj.beam.Attachment1 = obj.attachTarget
    obj.beam.Enabled = true

    local head = charTarget:FindFirstChild("Head") or targetBody
    if (not obj.billboard) or (obj.billboard.Parent ~= head) then
        if obj.billboard then pcall(function() obj.billboard:Destroy() end) end

        obj.billboard = Instance.new("BillboardGui")
        obj.billboard.Name = "AxaNearest_NameTag"
        obj.billboard.Size = UDim2.new(0, 220, 0, 40)
        obj.billboard.StudsOffset = Vector3.new(0, 3, 0)
        obj.billboard.AlwaysOnTop = true
        obj.billboard.MaxDistance = 0
        obj.billboard.Adornee = head
        obj.billboard.Enabled = true
        obj.billboard.Parent = head

        local bg = Instance.new("Frame")
        bg.Name = "BG"
        bg.AnchorPoint = Vector2.new(0.5, 0.5)
        bg.Position = UDim2.new(0.5, 0, 0.5, 0)
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.35
        bg.BorderSizePixel = 0
        bg.Parent = obj.billboard
        makeCorner(bg, 8)

        local txt = Instance.new("TextLabel")
        txt.Name = "Label"
        txt.Size = UDim2.new(1,-8,1,-4)
        txt.Position = UDim2.new(0,4,0,2)
        txt.BackgroundTransparency = 1
        txt.Font = Enum.Font.GothamSemibold
        txt.TextSize = 12
        txt.TextColor3 = Color3.fromRGB(255,255,255)
        txt.TextWrapped = true
        txt.TextXAlignment = Enum.TextXAlignment.Center
        txt.TextYAlignment = Enum.TextYAlignment.Center
        txt.Text = ""
        txt.Parent = bg

        obj.label = txt
    else
        obj.billboard.MaxDistance = 0
        obj.billboard.StudsOffset = Vector3.new(0, 3, 0)
        obj.billboard.Adornee = head
        obj.billboard.Enabled = true
    end

    if obj.label then
        local dispName = plr.DisplayName or plr.Name
        local uname    = plr.Name
        local d        = distance or 0
        obj.label.Text = string.format("%s (@%s), %.1f studs", dispName, uname, d)
    end
end

local function updateAntennasForAllPlayers(mode)
    local rootLocal, charLocal = getLocalRoot()
    if not (rootLocal and charLocal) then
        clearAllAntennas()
        return nil, nil
    end

    local nearestPlr
    local nearestDist

    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= localPlayer then
            local obj = antennaObjects[plr]
            local showThis = false
            local distance

            local c   = plr.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")

            if c and hrp then
                local manualExcluded = excludedPlayersManual[plr.UserId] == true
                if not manualExcluded then
                    local isAdmin = ADMIN_IDS[plr.UserId] == true
                    local friend  = isFriend(plr.UserId)

                    if not (excludeFriends and friend) then
                        distance = (hrp.Position - rootLocal.Position).Magnitude
                        local passMode = (mode == "admin") and isAdmin or (mode == "all")
                        if passMode and distance > currentRadius and distance <= currentAntennaRadius then
                            showThis = true
                            ensureAntennaForPlayer(plr, charLocal, rootLocal, c, hrp, distance)
                            obj = antennaObjects[plr]

                            if (not nearestDist) or distance < nearestDist then
                                nearestDist = distance
                                nearestPlr  = plr
                            end
                        end
                    end
                end
            end

            obj = antennaObjects[plr]
            if obj then
                if showThis then
                    if obj.beam then obj.beam.Enabled = true end
                    if obj.billboard then obj.billboard.Enabled = true end
                else
                    if obj.beam then obj.beam.Enabled = false end
                    if obj.billboard then obj.billboard.Enabled = false end
                end
            end
        end
    end

    return nearestPlr, nearestDist
end

------------------- EXCLUDE PLAYERS LIST (UI + LOGIC) -------------------
local excludeRefreshToken = 0
local function scheduleExcludeRefresh()
    excludeRefreshToken += 1
    local t = excludeRefreshToken
    task.delay(0.15, function()
        if not alive then return end
        if t ~= excludeRefreshToken then return end
        if refreshExcludeList then
            refreshExcludeList()
        end
    end)
end

refreshExcludeList = function()
    if not excludeScroll then
        return
    end

    for _, child in ipairs(excludeScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= localPlayer then
            local friend = isFriend(plr.UserId)
            if not friend then
                local row = Instance.new("Frame")
                row.Name = "ExcludeRow_" .. tostring(plr.UserId)
                row.Size = UDim2.new(1,-4,0,24)
                row.BackgroundTransparency = 1
                row.Parent = excludeScroll

                local layout = Instance.new("UIListLayout")
                layout.Parent = row
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Padding = UDim.new(0,6)
                layout.VerticalAlignment = Enum.VerticalAlignment.Center

                local boxBtn = Instance.new("TextButton")
                boxBtn.Name = "Check"
                boxBtn.Size = UDim2.new(0,22,0,22)
                boxBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
                boxBtn.BorderSizePixel  = 0
                boxBtn.AutoButtonColor  = true
                boxBtn.Font = Enum.Font.GothamBold
                boxBtn.TextSize = 14
                boxBtn.TextColor3 = Color3.fromRGB(40,40,70)
                boxBtn.Parent = row
                makeCorner(boxBtn,4)

                local infoLabel = makeLabel(
                    row,
                    "Info",
                    string.format("%s (@%s) [Id: %d]", plr.DisplayName or plr.Name, plr.Name, plr.UserId),
                    UDim2.new(1,-30,1,0),
                    UDim2.new(),
                    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(60,60,110), XAlign=Enum.TextXAlignment.Left }
                )

                local function refreshBox()
                    if excludedPlayersManual[plr.UserId] then
                        boxBtn.Text = "☑"
                        infoLabel.TextColor3 = Color3.fromRGB(120,120,150)
                    else
                        boxBtn.Text = "☐"
                        infoLabel.TextColor3 = Color3.fromRGB(60,60,110)
                    end
                end

                refreshBox()

                bind(boxBtn.MouseButton1Click, function()
                    if excludedPlayersManual[plr.UserId] then
                        excludedPlayersManual[plr.UserId] = nil
                    else
                        excludedPlayersManual[plr.UserId] = true
                    end
                    refreshBox()
                end)
            end
        end
    end
end

refreshExcludeList()

------------------- DISCORD WEBHOOK (Nearest + Friend) -------------------
local function sendNearestWebhook(data)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end

    local payload = {
        username   = "Nearest Player Notifier",
        avatar_url = BOT_AVATAR_URL,
        content    = DEFAULT_OWNER_DISCORD,
        embeds     = {
            {
                title = "Nearest Player Detected",
                description = string.format(
                    "**%s (@%s)** terdeteksi dalam radius *%.1f* studs dari karakter-mu.\nTeleport ke: **[%d] %s**",
                    data.targetDisplayName or "Unknown",
                    data.targetUserName    or "-",
                    data.distance or 0,
                    data.teleportIndex or 0,
                    data.teleportLabel or "Unknown"
                ),
                color = data.isAdmin and 0xFF8800 or 0x00C896,
                fields = {
                    {
                        name  = "Target Player",
                        value = string.format(
                            "%s (@%s)\nUserId: `%s`\nAdmin: **%s**\nFriend: **%s**",
                            data.targetDisplayName or "-",
                            data.targetUserName    or "-",
                            tostring(data.targetUserId or "-"),
                            data.isAdmin and "YA" or "TIDAK",
                            data.isFriend and "YA" or "TIDAK"
                        ),
                        inline = true
                    },
                    {
                        name  = "Local Player",
                        value = string.format(
                            "%s (@%s)\nUserId: `%s`",
                            data.localDisplayName or "-",
                            data.localUserName    or "-",
                            tostring(data.localUserId or "-")
                        ),
                        inline = true
                    },
                    {
                        name  = "Distance & Radius",
                        value = string.format(
                            "Jarak: `%.1f` studs\nRadius aktif: `%d` studs",
                            data.distance or 0,
                            data.radius or 0
                        ),
                        inline = true
                    },
                    {
                        name  = "Teleport Target",
                        value = string.format("[%d] %s", data.teleportIndex or 0, data.teleportLabel or "-"),
                        inline = true
                    },
                    {
                        name  = "Map Info",
                        value = string.format(
                            "Map: **%s**\nPlaceId: `%d`\nServer: `%s`",
                            data.placeName or "-",
                            data.placeId or 0,
                            data.serverShort or "????"
                        ),
                        inline = true
                    },
                    {
                        name  = "Mode Deteksi",
                        value = string.format("Mode: `%s`\nWaktu: `%s`", data.modeText or "-", data.witaTime or "-"),
                        inline = false
                    }
                }
            }
        }
    }

    postDiscordAsync(payload)
end

local function sendFriendWebhook(kind, data)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    if not featureEnabled or not excludeFriends then
        return
    end

    local friendDisplayName  = data.friendDisplayName or "Unknown"
    local friendUserName     = data.friendUserName or "-"
    local rawFriendId        = data.friendUserId
    local friendUserId       = tostring(rawFriendId or "-")
    local friendUserIdNumber = tonumber(rawFriendId)
    local distance           = data.distance
    local radius             = data.radius or currentRadius
    local placeId            = data.placeId or game.PlaceId
    local placeName          = data.placeName or getPlaceName(placeId)
    local serverShort        = data.serverShort or shortJobId(game.JobId)
    local witaTime           = data.witaTime or getWitaTimestamp()

    if kind == "leaveMap" and friendUserIdNumber then
        local now  = os.clock()
        local last = lastFriendLeaveMapSent[friendUserIdNumber]
        if last and (now - last) < 5 then
            return
        end
        lastFriendLeaveMapSent[friendUserIdNumber] = now
    end

    local localDisplayName  = localPlayer.DisplayName or localPlayer.Name
    local localUserName     = localPlayer.Name
    local localUserId       = tostring(localPlayer.UserId)

    local title, description, color

    if kind == "joinMap" then
        title = "Friend Masuk Map"
        description = string.format(
            "Temanmu **%s (@%s)** baru saja MASUK map yang sama denganmu.\n" ..
            "Status radius saat join: dianggap di luar radius pengamanan (menunggu pergerakan).",
            friendDisplayName,
            friendUserName
        )
        color = 0x3498DB
    elseif kind == "leaveMap" then
        title = "Friend Keluar Map"
        local radiusNote = data.everInRadius and
            "Selama berada di map, friend ini **PERNAH** masuk radius pengamanan." or
            "Selama berada di map, friend ini **TIDAK PERNAH** masuk radius pengamanan."
        description = string.format(
            "Temanmu **%s (@%s)** baru saja KELUAR dari map yang sama denganmu.\n%s",
            friendDisplayName,
            friendUserName,
            radiusNote
        )
        color = 0x95A5A6
    elseif kind == "enterRadius" then
        title = "Friend Masuk Radius"
        description = string.format(
            "Temanmu **%s (@%s)** saat ini **BERADA di dalam radius pengamanan**.\n" ..
            "Jarak sekarang: `%.1f` studs (radius: `%d`).",
            friendDisplayName,
            friendUserName,
            tonumber(distance or 0),
            radius
        )
        color = 0x2ECC71
    elseif kind == "leaveRadius" then
        title = "Friend Keluar Radius"
        description = string.format(
            "Temanmu **%s (@%s)** baru saja **KELUAR dari radius pengamanan**.\n" ..
            "Jarak sekarang: `%.1f` studs (radius: `%d`).",
            friendDisplayName,
            friendUserName,
            tonumber(distance or 0),
            radius
        )
        color = 0xE67E22
    else
        title = "Friend Status"
        description = string.format("Update status untuk friend **%s (@%s)**.", friendDisplayName, friendUserName)
        color = 0x7289DA
    end

    local fields = {
        {
            name  = "Friend",
            value = string.format("%s (@%s)\nUserId: `%s`", friendDisplayName, friendUserName, friendUserId),
            inline = true
        },
        {
            name  = "Local Player",
            value = string.format("%s (@%s)\nUserId: `%s`", localDisplayName, localUserName, localUserId),
            inline = true
        },
        {
            name  = "Map Info",
            value = string.format("Map: **%s**\nPlaceId: `%d`\nServer: `%s`", placeName, placeId, serverShort),
            inline = true
        },
        {
            name  = "Waktu",
            value = witaTime,
            inline = false
        }
    }

    if distance then
        table.insert(fields, 3, {
            name  = "Distance & Radius",
            value = string.format("Jarak terakhir: `%.1f` studs\nRadius aktif: `%d` studs", tonumber(distance or 0), radius),
            inline = true
        })
    end

    local payload = {
        username   = "Nearest Player - Friend Monitor",
        avatar_url = BOT_AVATAR_URL,
        content    = DEFAULT_OWNER_DISCORD,
        embeds     = {
            { title = title, description = description, color = color, fields = fields }
        }
    }

    postDiscordAsync(payload)
end

------------------- FRIEND MONITOR (PATCHED, LIGHTER & ALWAYS UPDATED) -------------------
local function ensureFriendStateForPlayer(plr, distOpt)
    if not plr then return nil end
    local uid = plr.UserId
    friendPlayers[uid] = plr

    local state = friendStates[uid]
    if not state then
        state = {
            inRadius     = false,
            everInRadius = false,
            lastDistance = distOpt,
            displayName  = plr.DisplayName or plr.Name,
            userName     = plr.Name,
        }
        friendStates[uid] = state
    else
        state.displayName  = plr.DisplayName or plr.Name
        state.userName     = plr.Name
        if distOpt ~= nil then
            state.lastDistance = distOpt
        end
    end
    return state
end

local function computeDistanceToLocal(plr, rootLocal)
    if not (plr and rootLocal) then return nil end
    local c = plr.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return (hrp.Position - rootLocal.Position).Magnitude
end

local function syncFriendsInServer(sendJoinForAllInThisSession)
    if not excludeFriends then return end

    local rootLocal = select(1, getLocalRoot())
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= localPlayer then
            local uid = plr.UserId
            if isFriend(uid) then
                local dist = computeDistanceToLocal(plr, rootLocal)
                local state = ensureFriendStateForPlayer(plr, dist)

                if sendJoinForAllInThisSession and (friendSessionSeen[uid] ~= friendSession) then
                    friendSessionSeen[uid] = friendSession

                    sendFriendWebhook("joinMap", {
                        friendDisplayName = state.displayName,
                        friendUserName    = state.userName,
                        friendUserId      = uid,
                        distance          = dist,
                        radius            = currentRadius,
                        placeId           = game.PlaceId,
                        placeName         = getPlaceName(game.PlaceId),
                        serverShort       = shortJobId(game.JobId),
                        witaTime          = getWitaTimestamp(),
                    })

                    if dist and dist <= currentRadius then
                        state.inRadius     = true
                        state.everInRadius = true
                        sendFriendWebhook("enterRadius", {
                            friendDisplayName = state.displayName,
                            friendUserName    = state.userName,
                            friendUserId      = uid,
                            distance          = dist,
                            radius            = currentRadius,
                            placeId           = game.PlaceId,
                            placeName         = getPlaceName(game.PlaceId),
                            serverShort       = shortJobId(game.JobId),
                            witaTime          = getWitaTimestamp(),
                        })
                    end
                end
            end
        end
    end
end

local lastFriendTick = 0
local FRIEND_UPDATE_INTERVAL = 0.25

local function updateFriendStates(rootLocal, nowClock)
    if not excludeFriends then return end
    if not rootLocal then return end

    local now = nowClock or os.clock()
    if (now - lastFriendTick) < FRIEND_UPDATE_INTERVAL then
        return
    end
    lastFriendTick = now

    for uid, plr in pairs(friendPlayers) do
        if plr and plr.Parent == players then
            local state = friendStates[uid]
            if state then
                state.displayName = plr.DisplayName or plr.Name
                state.userName    = plr.Name

                local dist = computeDistanceToLocal(plr, rootLocal)
                if dist then
                    state.lastDistance = dist
                    local inside = dist <= currentRadius

                    if inside and not state.inRadius then
                        state.inRadius     = true
                        state.everInRadius = true
                        sendFriendWebhook("enterRadius", {
                            friendDisplayName = state.displayName,
                            friendUserName    = state.userName,
                            friendUserId      = uid,
                            distance          = dist,
                            radius            = currentRadius,
                            placeId           = game.PlaceId,
                            placeName         = getPlaceName(game.PlaceId),
                            serverShort       = shortJobId(game.JobId),
                            witaTime          = getWitaTimestamp(),
                        })
                    elseif (not inside) and state.inRadius then
                        state.inRadius = false
                        sendFriendWebhook("leaveRadius", {
                            friendDisplayName = state.displayName,
                            friendUserName    = state.userName,
                            friendUserId      = uid,
                            distance          = dist,
                            radius            = currentRadius,
                            placeId           = game.PlaceId,
                            placeName         = getPlaceName(game.PlaceId),
                            serverShort       = shortJobId(game.JobId),
                            witaTime          = getWitaTimestamp(),
                        })
                    end
                end
            end
        end
    end
end

bind(players.PlayerAdded, function(plr)
    scheduleExcludeRefresh()

    if excludeFriends and isFriend(plr.UserId) then
        friendPlayers[plr.UserId] = plr
        local rootLocal = select(1, getLocalRoot())
        local dist = computeDistanceToLocal(plr, rootLocal)

        local state = ensureFriendStateForPlayer(plr, dist)

        if friendSessionSeen[plr.UserId] ~= friendSession then
            friendSessionSeen[plr.UserId] = friendSession
            sendFriendWebhook("joinMap", {
                friendDisplayName = state.displayName,
                friendUserName    = state.userName,
                friendUserId      = plr.UserId,
                distance          = dist,
                radius            = currentRadius,
                placeId           = game.PlaceId,
                placeName         = getPlaceName(game.PlaceId),
                serverShort       = shortJobId(game.JobId),
                witaTime          = getWitaTimestamp(),
            })
        end

        if dist and dist <= currentRadius and not state.inRadius then
            state.inRadius     = true
            state.everInRadius = true
            sendFriendWebhook("enterRadius", {
                friendDisplayName = state.displayName,
                friendUserName    = state.userName,
                friendUserId      = plr.UserId,
                distance          = dist,
                radius            = currentRadius,
                placeId           = game.PlaceId,
                placeName         = getPlaceName(game.PlaceId),
                serverShort       = shortJobId(game.JobId),
                witaTime          = getWitaTimestamp(),
            })
        end
    end
end)

bind(players.PlayerRemoving, function(plr)
    excludedPlayersManual[plr.UserId] = nil
    destroyAntennaForPlayer(plr)
    scheduleExcludeRefresh()

    local uid = plr.UserId
    if excludeFriends and isFriend(uid) then
        local state = friendStates[uid]
        local displayName  = (state and state.displayName) or plr.DisplayName or plr.Name
        local userName     = (state and state.userName) or plr.Name
        local lastDistance = state and state.lastDistance

        sendFriendWebhook("leaveMap", {
            friendDisplayName = displayName,
            friendUserName    = userName,
            friendUserId      = uid,
            distance          = lastDistance,
            everInRadius      = state and state.everInRadius,
            radius            = currentRadius,
            placeId           = game.PlaceId,
            placeName         = getPlaceName(game.PlaceId),
            serverShort       = shortJobId(game.JobId),
            witaTime          = getWitaTimestamp(),
        })
    end

    friendPlayers[uid] = nil
    friendStates[uid]  = nil
    friendSessionSeen[uid] = nil
end)

-- PATCH: initial sync supaya friend yang sudah ada di server tetap kirim joinMap
task.delay(0.35, function()
    if not alive then return end
    if excludeFriends then
        friendSession += 1
        syncFriendsInServer(true)
    end
end)

------------------- CARD 2: TELEPORT POINTS -------------------
local tpCard = Instance.new("Frame")
tpCard.Name = "TeleportCard"
tpCard.Size = UDim2.new(1,0,0,240)
tpCard.BackgroundColor3 = Color3.fromRGB(236,238,248)
tpCard.BorderSizePixel  = 0
tpCard.Parent = body
makeCorner(tpCard,10)
local tpStroke = Instance.new("UIStroke", tpCard)
tpStroke.Thickness    = 1
tpStroke.Color        = Color3.fromRGB(210,210,230)
tpStroke.Transparency = 0.3

local tpScroll = Instance.new("ScrollingFrame")
tpScroll.Name = "TPScroll"
tpScroll.Position = UDim2.new(0,0,0,0)
tpScroll.Size = UDim2.new(1,0,1,0)
tpScroll.BackgroundTransparency = 1
tpScroll.BorderSizePixel = 0
tpScroll.ScrollBarThickness = 3
tpScroll.ScrollingDirection = Enum.ScrollingDirection.Y
tpScroll.CanvasSize = UDim2.new(0,0,0,0)
tpScroll.Parent = tpCard

local tpPad = Instance.new("UIPadding", tpScroll)
tpPad.PaddingTop    = UDim.new(0,6)
tpPad.PaddingBottom = UDim.new(0,6)
tpPad.PaddingLeft   = UDim.new(0,6)
tpPad.PaddingRight  = UDim.new(0,6)

local tpScrollLayout = Instance.new("UIListLayout")
tpScrollLayout.Parent = tpScroll
tpScrollLayout.FillDirection = Enum.FillDirection.Vertical
tpScrollLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tpScrollLayout.Padding       = UDim.new(0,4)
tpScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
bind(tpScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    local abs = tpScrollLayout.AbsoluteContentSize
    tpScroll.CanvasSize = UDim2.new(0, abs.X + 4, 0, abs.Y + 4)
end)

makeLabel(
    tpScroll,"TPHeader","📍 Titik Teleport (Urutan Berputar)",
    UDim2.new(1,-10,0,18),UDim2.new(),
    { Font=Enum.Font.GothamSemibold, TextSize=12, TextColor3=Color3.fromRGB(60,60,110), XAlign=Enum.TextXAlignment.Left }
)

makeLabel(
    tpScroll,"TPSub",
    "Urutan mengikuti list di bawah. Hanya titik yang dicentang & punya posisi yang akan dipakai.",
    UDim2.new(1,-10,0,32),UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(100,100,140),
      XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
)

local tpList = Instance.new("Frame")
tpList.Name = "TPList"
tpList.Size = UDim2.new(1,-4,0,0)
tpList.BackgroundTransparency = 1
tpList.AutomaticSize = Enum.AutomaticSize.Y
tpList.Parent = tpScroll

local tpLayout = Instance.new("UIListLayout")
tpLayout.Parent = tpList
tpLayout.FillDirection = Enum.FillDirection.Vertical
tpLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tpLayout.Padding       = UDim.new(0,4)

local function makeCheckboxRow(index, cfg)
    local row = Instance.new("Frame")
    row.Name = "TPRow_"..tostring(index)
    row.Size = UDim2.new(1,0,0,26)
    row.BackgroundTransparency = 1
    row.Parent = tpList

    local layout = Instance.new("UIListLayout", row)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder     = Enum.SortOrder.LayoutOrder
    layout.Padding       = UDim.new(0,6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local boxBtn = Instance.new("TextButton")
    boxBtn.Name = "Check"
    boxBtn.Size = UDim2.new(0,22,0,22)
    boxBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
    boxBtn.BorderSizePixel  = 0
    boxBtn.Text = cfg.enabled and "☑" or "☐"
    boxBtn.Font = Enum.Font.GothamBold
    boxBtn.TextSize = 14
    boxBtn.TextColor3 = Color3.fromRGB(40,40,70)
    boxBtn.AutoButtonColor = true
    boxBtn.Parent = row
    makeCorner(boxBtn,4)

    local nameLabel = makeLabel(
        row,
        "Name",
        string.format("%d) %s", index, cfg.label),
        UDim2.new(0,190,1,0),UDim2.new(),
        { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(60,60,110), XAlign=Enum.TextXAlignment.Left }
    )

    local posLabel = makeLabel(
        row,
        "PosInfo",
        cfg.position and "Pos: SIAP" or "Pos: BELUM DIISI",
        UDim2.new(1,-240,1,0),UDim2.new(),
        { Font=Enum.Font.Gotham, TextSize=10, TextColor3=Color3.fromRGB(110,110,150), XAlign=Enum.TextXAlignment.Left }
    )

    local function refreshVisual()
        boxBtn.Text = cfg.enabled and "☑" or "☐"
        if cfg.position then
            if cfg.lookAt then
                posLabel.Text = string.format(
                    "Pos: (%.1f, %.1f, %.1f) | LookAt: (%.1f, %.1f, %.1f)",
                    cfg.position.X, cfg.position.Y, cfg.position.Z,
                    cfg.lookAt.X,   cfg.lookAt.Y,   cfg.lookAt.Z
                )
            else
                posLabel.Text = string.format(
                    "Pos: (%.1f, %.1f, %.1f) | LookAt: -",
                    cfg.position.X, cfg.position.Y, cfg.position.Z
                )
            end
            posLabel.TextColor3 = Color3.fromRGB(70,130,90)
        else
            posLabel.Text = "Pos: BELUM DIISI"
            posLabel.TextColor3 = Color3.fromRGB(150,90,90)
        end
    end

    refreshVisual()

    bind(boxBtn.MouseButton1Click, function()
        cfg.enabled = not cfg.enabled
        refreshVisual()
    end)
end

for i, cfg in ipairs(TELEPORT_POINTS) do
    makeCheckboxRow(i, cfg)
end

------------------- DETEKSI NEAREST PLAYER (UNTUK TELEPORT) -------------------
local function getNearestPlayerWithinRadius(radius, mode)
    local rootPart = select(1, getLocalRoot())
    if not rootPart then
        return nil, nil, nil, nil
    end

    local nearestPlayer, nearestDist, nearestIsAdmin, nearestIsFriend

    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= localPlayer then
            local c   = plr.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local manualExcluded = excludedPlayersManual[plr.UserId] == true
                if not manualExcluded then
                    local isAdmin  = ADMIN_IDS[plr.UserId] == true
                    local friend   = isFriend(plr.UserId)

                    if not (excludeFriends and friend) then
                        local d = (hrp.Position - rootPart.Position).Magnitude
                        if d <= radius then
                            if mode == "admin" then
                                if isAdmin and (not nearestDist or d < nearestDist) then
                                    nearestDist     = d
                                    nearestPlayer   = plr
                                    nearestIsAdmin  = true
                                    nearestIsFriend = friend
                                end
                            else
                                if not nearestDist or d < nearestDist then
                                    nearestDist     = d
                                    nearestPlayer   = plr
                                    nearestIsAdmin  = isAdmin
                                    nearestIsFriend = friend
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nearestPlayer, nearestDist, nearestIsAdmin, nearestIsFriend
end

------------------- TELEPORT & REELING GATE -------------------
local function doImmediateTeleport(data)
    local nearestPlayer  = data.nearestPlayer
    local dist           = data.distance
    local isAdmin        = data.isAdmin
    local isFriendFlag   = data.isFriendFlag

    if not nearestPlayer or not dist then return end

    local rootLocal = select(1, getLocalRoot())
    if not rootLocal then
        notify("Nearest Player", "Gagal teleport: HumanoidRootPart tidak ditemukan.", 3)
        return
    end

    local point, idx = getNextTeleportPoint()
    if not point then
        notify("Nearest Player", "Tidak ada titik teleport aktif atau posisi semua kosong.", 4)
        if statusLabel then
            statusLabel.Text = "Tidak ada titik teleport aktif / posisi kosong."
        end
        return
    end

    if not point.position then
        notify("Nearest Player", "Posisi untuk "..point.label.." belum diisi.", 4)
        if statusLabel then
            statusLabel.Text = "Posisi tujuan kosong ("..point.label..")"
        end
        return
    end

    clearAllAntennas()

    rootLocal.CFrame = getPointCFrame(point)
    lastTeleportTime = os.clock()
    isCasting = true

    local dn = nearestPlayer.DisplayName or nearestPlayer.Name
    if statusLabel then
        statusLabel.Text = string.format(
            "Teleport ke [%d] %s (target: %s). Menunggu deteksi berikutnya...",
            idx, point.label, dn
        )
    end

    ensureAutoFishingAfterTeleport()
    task.wait(0.03)
    playSitEmoteIfEnabled()

    local localDn  = localPlayer.DisplayName or localPlayer.Name
    local localUn  = localPlayer.Name
    local targetUn = nearestPlayer.Name

    local mode      = getDetectionMode()
    local modeText  = modeToText(mode)
    local placeId   = game.PlaceId
    local placeName = getPlaceName(placeId)
    local serverShort = shortJobId(game.JobId)
    local witaTime  = getWitaTimestamp()

    sendNearestWebhook({
        targetDisplayName = dn,
        targetUserName    = targetUn,
        targetUserId      = nearestPlayer.UserId,
        localDisplayName  = localDn,
        localUserName     = localUn,
        localUserId       = localPlayer.UserId,
        distance          = dist,
        radius            = currentRadius,
        teleportIndex     = idx,
        teleportLabel     = point.label,
        placeId           = placeId,
        placeName         = placeName,
        serverShort       = serverShort,
        isAdmin           = isAdmin and true or false,
        isFriend          = isFriendFlag and true or false,
        modeText          = modeText,
        witaTime          = witaTime,
    })
end

local function scheduleTeleportAfterReeling(data)
    clearPendingTeleportMonitor()
    pendingTeleportData = data

    pendingTeleportConn = runService.RenderStepped:Connect(function()
        if not alive or not featureEnabled then
            clearPendingTeleportMonitor()
            return
        end

        if not pendingTeleportData then
            clearPendingTeleportMonitor()
            return
        end

        local reeling, prog = isReelingActiveAndProgress()
        if (not reeling) or prog >= 1 then
            local teleData = pendingTeleportData
            clearPendingTeleportMonitor()
            task.defer(function()
                doImmediateTeleport(teleData)
            end)
        end
    end)
end

local function handleDetection(nearestPlayer, dist, isAdmin, isFriendFlag)
    if not nearestPlayer or not dist then return end

    local now = os.clock()
    if now - lastTeleportTime < TELEPORT_COOLDOWN then
        return
    end
    if pendingTeleportData then
        return
    end

    playAlert()

    local dn = nearestPlayer.DisplayName or nearestPlayer.Name
    local reeling, prog = isReelingActiveAndProgress()
    if reeling and prog < 1 then
        local percent = math.floor(prog * 100 + 0.5)
        if statusLabel then
            statusLabel.Text = string.format(
                "Terdeteksi %s dalam TELEPORT_RADIUS (%.1f studs), tapi kamu lagi Reeling (%d%%). Menunggu 100%% lalu teleport...",
                dn, dist, percent
            )
        end

        scheduleTeleportAfterReeling({
            nearestPlayer = nearestPlayer,
            distance      = dist,
            isAdmin       = isAdmin,
            isFriendFlag  = isFriendFlag,
        })
        return
    end

    if statusLabel then
        statusLabel.Text = string.format(
            "Terdeteksi %s dalam TELEPORT_RADIUS (%.1f studs). Teleport ke titik aman...",
            dn, dist
        )
    end

    doImmediateTeleport({
        nearestPlayer = nearestPlayer,
        distance      = dist,
        isAdmin       = isAdmin,
        isFriendFlag  = isFriendFlag,
    })
end

------------------- UI EVENT WIRING -------------------
bind(toggleButton.MouseButton1Click, function()
    featureEnabled = not featureEnabled
    updateToggleVisual()

    if featureEnabled then
        statusLabel.Text = "Status: Menunggu player mendekat..."
        if autoFishingNPEnabled then
            setupRodEventListener()
            startAutofishLoop()
        end
    else
        statusLabel.Text = "Status: Fitur dimatikan (Nearest Player: OFF)."
        clearAllAntennas()
        stopAutofish()
    end

    refreshFilterVisual()
end)

bind(radiusBox.FocusLost, function()
    setRadiusFromText(radiusBox.Text)
end)

bind(antennaRadiusBox.FocusLost, function()
    setAntennaRadiusFromText(antennaRadiusBox.Text)
end)

bind(filterAllBtn.MouseButton1Click, function()
    filterAllPlayers = not filterAllPlayers
    refreshFilterVisual()
end)

bind(filterAdminBtn.MouseButton1Click, function()
    filterOnlyAdmin = not filterOnlyAdmin
    refreshFilterVisual()
end)

bind(filterFriendsBtn.MouseButton1Click, function()
    excludeFriends = not excludeFriends
    refreshFilterVisual()

    -- PATCH: saat Exclusion Friends ON kembali, lakukan sync ulang supaya joinMap tidak miss
    if excludeFriends then
        friendSession += 1
        syncFriendsInServer(true)
    else
        -- bila OFF, tetap bersihkan tracking supaya saat ON lagi dianggap sesi baru (lebih konsisten)
        friendPlayers = {}
        friendStates  = {}
        friendSessionSeen = {}
    end
end)

bind(emoteSitBtn.MouseButton1Click, function()
    emoteSitEnabled = not emoteSitEnabled
    refreshFilterVisual()
    notify("Nearest Player","Emote Duduk: " .. (emoteSitEnabled and "ON (akan dijalankan setelah teleport)" or "OFF"),3)
end)

bind(autoFishBtn.MouseButton1Click, function()
    if autoFishingNPEnabled then
        stopAutofish()
        if statusLabel then
            statusLabel.Text = "Status: AutoFishing Lokal: OFF (menunggu diaktifkan)."
        end
    else
        autoFishingNPEnabled = true
        setupRodEventListener()
        if statusLabel then
            statusLabel.Text = "Status: AutoFishing Lokal: ON (logic IndoHangout)."
        end
        if featureEnabled then
            startAutofishLoop()
        end
    end
    refreshFilterVisual()
end)

------------------- LOOP DETEKSI (HEARTBEAT + THROTTLE) -------------------
bind(runService.Heartbeat, function()
    if not alive then return end
    if not featureEnabled then return end

    local now = os.clock()
    if now - lastDetectionTick < DETECTION_INTERVAL then
        return
    end
    lastDetectionTick = now

    local rootLocal = select(1, getLocalRoot())
    if not rootLocal then
        clearAllAntennas()
        if statusLabel then
            statusLabel.Text = "Status: Menunggu karakter respawn..."
        end
        return
    end

    local mode = getDetectionMode()
    if mode == "none" then
        clearAllAntennas()
        if statusLabel then
            statusLabel.Text = "Status: Filter deteksi OFF (All Players & Only Admin mati)."
        end
        return
    end

    -- MONITOR KHUSUS FRIEND (Exclude Friends: ON)
    updateFriendStates(rootLocal, now)

    local nearestTeleport, distTeleport, isAdminTeleport, isFriendTeleport =
        getNearestPlayerWithinRadius(currentRadius, mode)

    if nearestTeleport and distTeleport then
        handleDetection(nearestTeleport, distTeleport, isAdminTeleport, isFriendTeleport)
    end

    local nearestAntena, distAntena = updateAntennasForAllPlayers(mode)

    if (not nearestTeleport) and (not pendingTeleportData) and statusLabel and featureEnabled then
        if nearestAntena and distAntena then
            local dn = nearestAntena.DisplayName or nearestAntena.Name
            statusLabel.Text = string.format(
                "Antena: %s terdeteksi (%.1f studs) dalam ANTENA_RADIUS (visual saja, tanpa teleport).",
                dn, distAntena
            )
        else
            statusLabel.Text = "Status: Menunggu player mendekat..."
        end
    end
end)

------------------- INFO AWAL -------------------
notify("Nearest Player","TAB 16 aktif (Lite+Stable). Exclusion Friends: ON. Antena biru muncul dari badanmu ke badan player lain dalam ANTENA_RADIUS.",6)

task.delay(1.5, function()
    if alive and featureEnabled and autoFishingNPEnabled then
        setupRodEventListener()
        startAutofishLoop()
    end
end)

------------------- TAB CLEANUP REGISTER -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive = false
    stopAutofish()
    clearPendingTeleportMonitor()
    clearAllAntennas()

    for _, c in ipairs(connections) do
        pcall(function()
            if c and c.Disconnect then
                c:Disconnect()
            end
        end)
    end
end
