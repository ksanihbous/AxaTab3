--==========================================================
--  10AxaTab_ServerHoops.lua
--  TAB 14: "Server Hoops"
--  Env dari CORE:
--    TAB_FRAME, TAB_ID
--    Players, LocalPlayer, HttpService, UserInputService,
--    StarterGui, TweenService, RunService, Camera, dll
--==========================================================

------------------- ADMIN LIST -------------------
local ADMIN_IDS = {
    [8147845822] = true, -- Danskuy / danskuyxd
    [7449046692] = true, -- Naira / na_iaa5
    [8390121074] = true, -- Zone / DAXAJA0
    [2918244413] = true, -- ZuVoid / ZuVoidGT
    [1201037734] = true, -- SON / POISENIII
    [8473720116] = true, -- Grezly / VloowZ
    [6160156469] = true, -- Ryin / RYIIN100
    [7864402618] = true, -- Tiktik / tiktik_4924
    [1592339934] = true, -- Eryvenith or Lenn, Who? / ethyreaa
}

------------------- SHORTCUT ENV -------------------
local frame        = TAB_FRAME
local tabId        = TAB_ID or "serverhoops"

local players      = Players or game:GetService("Players")
local localPlayer  = LocalPlayer or players.LocalPlayer
local httpService  = HttpService or game:GetService("HttpService")
local uis          = UserInputService or game:GetService("UserInputService")
local starterGui   = StarterGui or game:GetService("StarterGui")
local tweenService = TweenService or game:GetService("TweenService")
local teleportSvc  = game:GetService("TeleportService")
local marketplace  = game:GetService("MarketplaceService")

local alive        = true

if not frame or not localPlayer then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- STATE SERVER LIST -------------------
local serversMap        = {}   -- [serverId] = serverData
local serversLoaded     = 0
local serversShown      = 0
local serversNextCursor = nil

local includeOpen       = true
local includeNear       = true
local includeFull       = true
local includeAdmin      = false -- filter admin
local friendsOnly       = false -- filter hanya server yang ada teman
local sortDesc          = true
local searchText        = ""

-- Filter urutan pemain:
--  "ALL"  = pakai Sort: Desc/Asc biasa
--  "LOW"  = paksa urut dari pemain terendah -> tertinggi
--  "HIGH" = paksa urut dari pemain tertinggi -> terendah
local playerFilterMode  = "ALL"

------------------- STATE FRIEND/KONEKSI -------------------
local friendServers     = {}   -- [jobId] = { {UserId,UserName,DisplayName}, ... }
local friendTotal       = 0

------------------- UI HANDLES -------------------
local serverRowsContainer, serversCountLabel
local searchBox
local btnSrvRefresh, btnSrvLoad5, btnSrvLoadAll
local btnToggleOpen, btnToggleNear, btnToggleFull, btnToggleAdmin, btnFriendsOnly, btnSort, btnPlayerFilter
local btnHoopRandom, btnHoopLow, btnHoop1_5, btnHoop6_20, btnHoop21_40, btnHoop41_48
local friendLabel
local friendTicker
local placeInfoLabel

local connections = {}
local rebuildServersListUI -- forward declare

------------------- HELPERS -------------------
local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(connections, c)
    return c
end

local function notify(title, text, dur)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = dur or 3
        })
    end)
end

local function shortJobId(jobId)
    local seg = tostring(jobId):match("^%x+%-(%x%x%x%x)%-")
    return (seg and seg:upper()) or "????"
end

local function Request()
    return (syn and syn.request)
        or (http_request)
        or (request)
        or (http and http.request)
        or httpService.RequestAsync
end

local function respSucceeded(res)
    if type(res) == "table" then
        if res.Success ~= nil then return res.Success end
        local code = res.StatusCode or res.status_code
        if code then return code >= 200 and code < 300 end
    end
    return true
end

------------------- HTTP: FETCH SERVER PAGE -------------------
local function fetchServerPage(placeId, cursor)
    local req = Request()
    if not req then
        notify("Server Hoops","Executor tidak mendukung HTTP Request.",5)
        return {}, nil
    end

    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s")
        :format(placeId, cursor and ("&cursor=" .. httpService:UrlEncode(cursor)) or "")

    local ok, res = pcall(function()
        if req == httpService.RequestAsync then
            return httpService:RequestAsync({Url = url, Method = "GET"})
        else
            return req({Url = url, Method = "GET"})
        end
    end)

    if not ok or not res then
        notify("Server Hoops","Gagal fetch server list.",3)
        return {}, nil
    end

    local body = res.Body or res.body
    if type(body) ~= "string" or #body == 0 then
        return {}, nil
    end

    local parsedOK, data = pcall(httpService.JSONDecode, httpService, body)
    if not parsedOK or not data or not data.data then
        return {}, nil
    end

    return data.data, data.nextPageCursor
end

------------------- SERVER OCC / FILTER -------------------
local NEAR_FULL_RATIO = 0.80

local function serverOcc(s)
    local playing = tonumber(s.playing) or 0
    local maxp    = tonumber(s.maxPlayers) or 0
    local ratio   = (maxp > 0) and (playing / maxp) or 0
    local isFull  = (maxp > 0) and (playing >= maxp)
    local isNear  = (not isFull) and (ratio >= NEAR_FULL_RATIO)
    local isOpen  = (not isFull) and (ratio <  NEAR_FULL_RATIO)
    return playing, maxp, isOpen, isNear, isFull
end

local function matchesSearch(serverId)
    if searchText == nil or searchText == "" then return true end
    local q     = string.lower(searchText)
    local full  = string.lower(tostring(serverId))
    local short = string.lower(shortJobId(serverId))
    return string.find(full, q, 1, true) ~= nil or string.find(short, q, 1, true) ~= nil
end

local function serversToArray()
    local arr = {}
    for _, s in pairs(serversMap) do table.insert(arr, s) end
    return arr
end

------------------- FRIEND/KONEKSI PRESENCE -------------------
local function countFriendServers()
    local c = 0
    for _ in pairs(friendServers) do c += 1 end
    return c
end

local function rebuildFriendTicker()
    if not friendTicker then return end
    friendTicker:ClearAllChildren()

    -- Grid koneksi:
    --   - 5 pemain per kolom (vertikal)
    --   - Kolom lanjut ke kanan
    local grid = Instance.new("Frame")
    grid.Name = "FriendGrid"
    grid.BackgroundTransparency = 1
    grid.Size = UDim2.new(0,0,1,0)
    grid.AutomaticSize = Enum.AutomaticSize.X
    grid.Parent = friendTicker

    local layout = Instance.new("UIGridLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.FillDirectionMaxCells = 5
    layout.StartCorner = Enum.StartCorner.TopLeft
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.CellPadding = UDim2.new(0, 4, 0, 2)
    layout.CellSize = UDim2.new(0, 180, 0, 18)
    layout.Parent = grid

    local function mkPill(text, jobId)
        local pill = Instance.new("TextButton")
        pill.AutoButtonColor     = true
        pill.Size                = UDim2.new(0, 180, 0, 18)
        pill.BackgroundColor3    = Color3.fromRGB(205, 205, 235)
        pill.Text                = text
        pill.TextColor3          = Color3.fromRGB(40, 40, 80)
        pill.Font                = Enum.Font.GothamSemibold
        pill.TextSize            = 11
        pill.TextXAlignment      = Enum.TextXAlignment.Left
        pill.TextYAlignment      = Enum.TextYAlignment.Center
        pill.Parent              = grid
        local c = Instance.new("UICorner", pill)
        c.CornerRadius = UDim.new(1, 0)

        pill.MouseButton1Click:Connect(function()
            local ok, err = pcall(function()
                teleportSvc:TeleportToPlaceInstance(game.PlaceId, jobId, localPlayer)
            end)
            if not ok then
                notify("Server Hoops","Gagal teleport: "..tostring(err),4)
            end
        end)

        pill.MouseButton2Click:Connect(function()
            local ok = pcall(function()
                if setclipboard then setclipboard(tostring(jobId)) end
            end)
            if ok then
                notify("Server Hoops","ServerId disalin (klik kanan).",1.5)
            end
        end)
    end

    for jobId, list in pairs(friendServers) do
        for _, info in ipairs(list) do
            local dn = info.DisplayName or info.UserName or ("User"..tostring(info.UserId))
            local un = info.UserName and ("@"..info.UserName) or ""
            local star = ADMIN_IDS[info.UserId] and "👑" or "⭐"
            local label = string.format("%s %s %s [%s]", star, dn, un, shortJobId(jobId))
            mkPill(label, jobId)
        end
    end

    local function updateCanvas()
        local size = layout.AbsoluteContentSize
        friendTicker.CanvasSize = UDim2.new(0, size.X + 8, 0, size.Y)
    end

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    task.defer(updateCanvas)
end

local function refreshFriendsPresence()
    friendServers = {}
    friendTotal   = 0

    local ok, online = pcall(function()
        return localPlayer:GetFriendsOnline(200)
    end)

    if not ok or not online then
        if friendLabel then
            friendLabel.Text = "👥 Koneksi: gagal cek teman (API Friends)."
        end
        rebuildFriendTicker()
        return
    end

    for _, info in ipairs(online) do
        if tonumber(info.PlaceId) == game.PlaceId and info.GameId then
            local jobId = tostring(info.GameId)
            friendServers[jobId] = friendServers[jobId] or {}
            table.insert(friendServers[jobId], {
                UserId      = info.UserId,
                UserName    = info.UserName,
                DisplayName = info.DisplayName
            })
            friendTotal += 1
        end
    end

    if friendLabel then
        local srvCount = countFriendServers()
        if friendTotal > 0 then
            friendLabel.Text = string.format("👥 Koneksi: %d teman di %d server map ini.", friendTotal, srvCount)
        else
            friendLabel.Text = "👥 Koneksi: belum ada teman di map ini."
        end
    end

    rebuildFriendTicker()
    if rebuildServersListUI then rebuildServersListUI() end
end

------------------- UI HELPERS -------------------
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
    l.Text      = text or ""
    l.Parent    = parent
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

local function clearChildrenBut(container, keep)
    for _, ch in ipairs(container:GetChildren()) do
        if not keep[ch] then ch:Destroy() end
    end
end

------------------- HEADER TAB (SESUAI CORE) -------------------
makeLabel(
    frame,"Header","🌐 Server Hoops V1",
    UDim2.new(1,-10,0,22),UDim2.new(0,5,0,6),
    { Font=Enum.Font.GothamBold, TextSize=15, TextColor3=Color3.fromRGB(40,40,60), XAlign=Enum.TextXAlignment.Left }
)

makeLabel(
    frame,"Sub",
    "Cari server lain di map ini, filter OPEN / NEAR / FULL / ADMIN / FRIENDS, lalu JOIN atau copy ServerID. Hoop = lompat server (Random/Low/Range).",
    UDim2.new(1,-10,0,32),UDim2.new(0,5,0,26),
    { Font=Enum.Font.Gotham, TextSize=12, TextColor3=Color3.fromRGB(90,90,120), XAlign=Enum.TextXAlignment.Left, YAlign=Enum.TextYAlignment.Top, Wrapped=true }
)

-- BODY (ScrollingFrame vertikal utama)
local body = Instance.new("ScrollingFrame")
body.Name = "BodyScroll"
body.Position = UDim2.new(0,0,0,64)
body.Size = UDim2.new(1,0,1,-64)
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
bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    body.CanvasSize = UDim2.new(0,0,0,bodyLayout.AbsoluteContentSize.Y+8)
end)

------------------- CARD: RINGKAS + KONEKSI + HOOP -------------------
local summaryCard = Instance.new("Frame")
summaryCard.Name = "SummaryCard"
summaryCard.Size = UDim2.new(1,0,0,156) -- tinggi dinaikkan untuk grid koneksi
summaryCard.BackgroundColor3 = Color3.fromRGB(236,238,248)
summaryCard.BorderSizePixel  = 0
summaryCard.Parent = body
makeCorner(summaryCard,10)
local sumStroke = Instance.new("UIStroke", summaryCard)
sumStroke.Thickness    = 1
sumStroke.Color        = Color3.fromRGB(210,210,230)
sumStroke.Transparency = 0.3

local sumPad = Instance.new("UIPadding", summaryCard)
sumPad.PaddingTop    = UDim.new(0,6)
sumPad.PaddingBottom = UDim.new(0,6)
sumPad.PaddingLeft   = UDim.new(0,6)
sumPad.PaddingRight  = UDim.new(0,6)

local mapName = "Unknown"
do
    local ok, info = pcall(function()
        return marketplace:GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name then mapName = tostring(info.Name) end
end

makeLabel(
    summaryCard,"MapLabel","🗺  "..mapName,
    UDim2.new(1,-10,0,20),UDim2.new(0,4,0,4),
    { Font=Enum.Font.GothamSemibold, TextSize=13, TextColor3=Color3.fromRGB(45,45,80), XAlign=Enum.TextXAlignment.Left }
)

placeInfoLabel = makeLabel(
    summaryCard,"PlaceInfo","",
    UDim2.new(1,-10,0,18),UDim2.new(0,4,0,24),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(85,85,120), XAlign=Enum.TextXAlignment.Left }
)

-- Update teks header: PlaceID • ServerID • Players: X/Y
local function updatePlaceInfo()
    if not placeInfoLabel then return end
    local currentPlayers = #players:GetPlayers()
    local maxPlayers     = players.MaxPlayers or 0
    placeInfoLabel.Text = string.format(
        "PlaceID: %d   •   ServerID: %s   •   Players: %d/%d",
        game.PlaceId,
        shortJobId(game.JobId),
        currentPlayers,
        maxPlayers
    )
end

updatePlaceInfo()
bind(players.PlayerAdded, function() updatePlaceInfo() end)
bind(players.PlayerRemoving, function() updatePlaceInfo() end)

friendLabel = makeLabel(
    summaryCard,"FriendInfo","👥 Koneksi: cek teman online...",
    UDim2.new(1,-10,0,18),UDim2.new(0,4,0,42),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(80,70,130), XAlign=Enum.TextXAlignment.Left }
)

friendTicker = Instance.new("ScrollingFrame")
friendTicker.Name = "FriendTicker"
friendTicker.Size = UDim2.new(1,-4,0,60)
friendTicker.Position = UDim2.new(0,2,0,62)
friendTicker.BackgroundColor3 = Color3.fromRGB(245,246,255)
friendTicker.BorderSizePixel  = 0
friendTicker.ScrollBarThickness = 3
friendTicker.ScrollingDirection = Enum.ScrollingDirection.XY
friendTicker.CanvasSize = UDim2.new(0,0,0,0)
friendTicker.Parent = summaryCard
makeCorner(friendTicker,8)
local ftStroke = Instance.new("UIStroke", friendTicker)
ftStroke.Thickness = 1
ftStroke.Color = Color3.fromRGB(220,224,250)
ftStroke.Transparency = 0.4

-- HOOP BAR
local hoopScroll = Instance.new("ScrollingFrame")
hoopScroll.Name = "HoopScroll"
hoopScroll.Size = UDim2.new(1,-4,0,24)
hoopScroll.Position = UDim2.new(0,2,0,126)
hoopScroll.BackgroundColor3 = Color3.fromRGB(245,246,255)
hoopScroll.BorderSizePixel  = 0
hoopScroll.ScrollBarThickness = 3
hoopScroll.ScrollingDirection = Enum.ScrollingDirection.X
hoopScroll.CanvasSize = UDim2.new(0,0,0,0)
hoopScroll.Parent = summaryCard
makeCorner(hoopScroll,8)
local hsStroke = Instance.new("UIStroke", hoopScroll)
hsStroke.Thickness = 1
hsStroke.Color = Color3.fromRGB(220,224,250)
hsStroke.Transparency = 0.4

local hoopRow = Instance.new("Frame")
hoopRow.Name = "HoopRow"
hoopRow.Size = UDim2.new(0,0,1,0)
hoopRow.BackgroundTransparency = 1
hoopRow.AutomaticSize = Enum.AutomaticSize.X
hoopRow.Parent = hoopScroll

local hoopLayout = Instance.new("UIListLayout", hoopRow)
hoopLayout.FillDirection = Enum.FillDirection.Horizontal
hoopLayout.SortOrder     = Enum.SortOrder.LayoutOrder
hoopLayout.Padding       = UDim.new(0,6)
hoopLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function updateHoopCanvas()
    hoopScroll.CanvasSize = UDim2.new(0, hoopLayout.AbsoluteContentSize.X + 8, 0, 0)
end
hoopLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateHoopCanvas)
task.defer(updateHoopCanvas)

btnHoopRandom = makeButton(hoopRow,"HoopRandom","Hoop (Random)", UDim2.new(0,110,1,0))
btnHoopLow    = makeButton(hoopRow,"HoopLow",   "Hoop (Low Pop)", UDim2.new(0,110,1,0))
btnHoop1_5    = makeButton(hoopRow,"Hoop1_5",   "Hoop (1-5)",     UDim2.new(0,96,1,0))
btnHoop6_20   = makeButton(hoopRow,"Hoop6_20",  "Hoop (6-20)",    UDim2.new(0,100,1,0))
btnHoop21_40  = makeButton(hoopRow,"Hoop21_40", "Hoop (21-40)",   UDim2.new(0,108,1,0))
btnHoop41_48  = makeButton(hoopRow,"Hoop41_48", "Hoop (41-48)",   UDim2.new(0,108,1,0))

------------------- FILTER BAR + SEARCH -------------------
local filterBar = Instance.new("Frame")
filterBar.Name = "FilterBar"
filterBar.Size = UDim2.new(1,0,0,32)
filterBar.BackgroundColor3 = Color3.fromRGB(232,235,248)
filterBar.BorderSizePixel  = 0
filterBar.Parent = body
makeCorner(filterBar,10)
local fbStroke = Instance.new("UIStroke", filterBar)
fbStroke.Thickness = 1
fbStroke.Color = Color3.fromRGB(210,212,232)
fbStroke.Transparency = 0.35
local fbPad = Instance.new("UIPadding", filterBar)
fbPad.PaddingTop    = UDim.new(0,4)
fbPad.PaddingBottom = UDim.new(0,4)
fbPad.PaddingLeft   = UDim.new(0,6)
fbPad.PaddingRight  = UDim.new(0,6)

local filterScroll = Instance.new("ScrollingFrame")
filterScroll.Name = "FilterScroll"
filterScroll.Size = UDim2.new(1,0,1,0)
filterScroll.BackgroundTransparency = 1
filterScroll.BorderSizePixel = 0
filterScroll.ScrollBarThickness = 3
filterScroll.ScrollingDirection = Enum.ScrollingDirection.X
filterScroll.CanvasSize = UDim2.new(0,0,0,0)
filterScroll.Parent = filterBar

local fbInner = Instance.new("Frame")
fbInner.Name = "FilterInner"
fbInner.BackgroundTransparency = 1
fbInner.Size = UDim2.new(0,0,1,0)
fbInner.AutomaticSize = Enum.AutomaticSize.X
fbInner.Parent = filterScroll

local fbLayout = Instance.new("UIListLayout", fbInner)
fbLayout.FillDirection = Enum.FillDirection.Horizontal
fbLayout.SortOrder     = Enum.SortOrder.LayoutOrder
fbLayout.Padding       = UDim.new(0,4)
fbLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function updateFilterCanvas()
    filterScroll.CanvasSize = UDim2.new(0, fbLayout.AbsoluteContentSize.X + 8, 0, 0)
end
fbLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateFilterCanvas)
task.defer(updateFilterCanvas)

btnToggleOpen   = makeButton(fbInner,"BtnOpen","Open: ON",      UDim2.new(0,80,1,0))
btnToggleNear   = makeButton(fbInner,"BtnNear","Near: ON",      UDim2.new(0,80,1,0))
btnToggleFull   = makeButton(fbInner,"BtnFull","Full: ON",      UDim2.new(0,80,1,0))
btnToggleAdmin  = makeButton(fbInner,"BtnAdmin","Admin: OFF",   UDim2.new(0,92,1,0))
btnFriendsOnly  = makeButton(fbInner,"BtnFriendsOnly","Friends: OFF", UDim2.new(0,100,1,0))
btnSort         = makeButton(fbInner,"BtnSort","Sort: Desc",    UDim2.new(0,96,1,0))
btnSort.TextXAlignment = Enum.TextXAlignment.Center
btnPlayerFilter = makeButton(fbInner,"BtnPlayerFilter","Player: ALL", UDim2.new(0,110,1,0))

local searchBar = Instance.new("Frame")
searchBar.Name = "SearchBar"
searchBar.Size = UDim2.new(1,0,0,32)
searchBar.BackgroundColor3 = Color3.fromRGB(235,238,252)
searchBar.BorderSizePixel  = 0
searchBar.Parent = body
makeCorner(searchBar,10)
local sbStroke = Instance.new("UIStroke", searchBar)
sbStroke.Thickness = 1
sbStroke.Color = Color3.fromRGB(214,218,240)
sbStroke.Transparency = 0.35
local sbPad = Instance.new("UIPadding", searchBar)
sbPad.PaddingTop    = UDim.new(0,4)
sbPad.PaddingBottom = UDim.new(0,4)
sbPad.PaddingLeft   = UDim.new(0,6)
sbPad.PaddingRight  = UDim.new(0,6)

local sbLayout = Instance.new("UIListLayout", searchBar)
sbLayout.FillDirection     = Enum.FillDirection.Horizontal
sbLayout.SortOrder         = Enum.SortOrder.LayoutOrder
sbLayout.Padding           = UDim.new(0,4)
sbLayout.VerticalAlignment = Enum.VerticalAlignment.Center

searchBox = Instance.new("TextBox")
searchBox.Name = "ServerSearch"
searchBox.Size = UDim2.new(1,-180,1,0)
searchBox.BackgroundColor3 = Color3.fromRGB(248,250,255)
searchBox.BorderSizePixel  = 0
searchBox.ClearTextOnFocus = false
searchBox.TextXAlignment   = Enum.TextXAlignment.Left
searchBox.Font             = Enum.Font.Gotham
searchBox.TextSize         = 12
searchBox.PlaceholderText  = "Search ServerID / short (4 hex) ..."
searchBox.Text             = ""
searchBox.TextColor3       = Color3.fromRGB(40,40,70)
searchBox.Parent           = searchBar
makeCorner(searchBox,8)
local sPadInner = Instance.new("UIPadding", searchBox)
sPadInner.PaddingLeft  = UDim.new(0,6)
sPadInner.PaddingRight = UDim.new(0,6)

local btnClearSearch = makeButton(searchBar,"BtnClearSearch","Clear",   UDim2.new(0,58,1,0))
btnSrvRefresh        = makeButton(searchBar,"BtnSrvRefresh","Refresh",  UDim2.new(0,58,1,0))
btnSrvLoad5          = makeButton(searchBar,"BtnSrvLoad5",  "Load+5",   UDim2.new(0,58,1,0))

local ctlBar = Instance.new("Frame")
ctlBar.Name = "CtlBar"
ctlBar.Size = UDim2.new(1,0,0,28)
ctlBar.BackgroundTransparency = 1
ctlBar.Parent = body

local ctlLayout = Instance.new("UIListLayout", ctlBar)
ctlLayout.FillDirection = Enum.FillDirection.Horizontal
ctlLayout.SortOrder     = Enum.SortOrder.LayoutOrder
ctlLayout.Padding       = UDim.new(0,4)
ctlLayout.VerticalAlignment = Enum.VerticalAlignment.Center

btnSrvLoadAll = makeButton(ctlBar,"BtnSrvLoadAll","Load Banyak", UDim2.new(0,110,1,0))
serversCountLabel = makeLabel(
    ctlBar,"SrvCount","🌐 0 shown / 0 loaded",
    UDim2.new(1,-(110+4),1,0),UDim2.new(),
    { Font=Enum.Font.Gotham, TextSize=11, TextColor3=Color3.fromRGB(70,70,110), XAlign=Enum.TextXAlignment.Right }
)

------------------- HEADER KOLUMN + LIST SERVER -------------------
local headerRow = Instance.new("Frame")
headerRow.Name = "HeaderRow"
headerRow.Size = UDim2.new(1,0,0,20)
headerRow.BackgroundTransparency = 1
headerRow.Parent = body

local hdrLayout = Instance.new("UIListLayout", headerRow)
hdrLayout.FillDirection = Enum.FillDirection.Horizontal
hdrLayout.SortOrder     = Enum.SortOrder.LayoutOrder
hdrLayout.Padding       = UDim.new(0,3)

makeLabel(headerRow,"HdrNo","#", UDim2.new(0.12,0,1,0),UDim2.new(), {
    Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(50,50,80)
})
makeLabel(headerRow,"HdrOcc","Jumlah", UDim2.new(0.34,0,1,0),UDim2.new(), {
    Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(50,50,80)
})
makeLabel(headerRow,"HdrId","Server ID", UDim2.new(0.22,0,1,0),UDim2.new(), {
    Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(50,50,80)
})
makeLabel(headerRow,"HdrAct","Join & Copy", UDim2.new(0.32,0,1,0),UDim2.new(), {
    Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(50,50,80)
})

serverRowsContainer = Instance.new("Frame")
serverRowsContainer.Name = "ServerRows"
serverRowsContainer.Size = UDim2.new(1,0,0,0)
serverRowsContainer.AutomaticSize = Enum.AutomaticSize.Y
serverRowsContainer.BackgroundTransparency = 1
serverRowsContainer.BorderSizePixel = 0
serverRowsContainer.Parent = body

local srvLayout = Instance.new("UIListLayout", serverRowsContainer)
srvLayout.FillDirection = Enum.FillDirection.Vertical
srvLayout.SortOrder     = Enum.SortOrder.LayoutOrder
srvLayout.Padding       = UDim.new(0,3)
srvLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    serverRowsContainer.Size = UDim2.new(1,0,0,srvLayout.AbsoluteContentSize.Y)
end)

------------------- ADMIN DETECTION HELPERS -------------------
local function hasAdminInFriendList(jobId)
    local list = friendServers[jobId]
    if not list then return false end
    for _, info in ipairs(list) do
        if ADMIN_IDS[info.UserId] then return true end
    end
    return false
end

------------------- BUILD SERVER LIST UI -------------------
rebuildServersListUI = function()
    if not serverRowsContainer then return end
    local layout = serverRowsContainer:FindFirstChildOfClass("UIListLayout")
    local keep = {}; if layout then keep[layout] = true end
    clearChildrenBut(serverRowsContainer, keep)

    local arr = serversToArray()
    local filtered = {}

    for _, s in ipairs(arr) do
        if s.id ~= game.JobId then
            local _,_,isOpen,isNear,isFull = serverOcc(s)
            local passType = (includeOpen and isOpen) or (includeNear and isNear) or (includeFull and isFull)

            if passType and matchesSearch(s.id) then
                local list = friendServers[s.id]
                local hasFriend = list and #list > 0

                -- Jika Friends filter aktif, wajib punya teman di server tsb
                if friendsOnly and not hasFriend then
                    -- skip
                else
                    if includeAdmin then
                        if hasAdminInFriendList(s.id) then
                            table.insert(filtered, s)
                        end
                    else
                        table.insert(filtered, s)
                    end
                end
            end
        end
    end

    table.sort(filtered, function(a,b)
        local pa = tonumber(a.playing) or 0
        local pb = tonumber(b.playing) or 0

        if playerFilterMode == "LOW" then
            if pa ~= pb then return pa < pb end
        elseif playerFilterMode == "HIGH" then
            if pa ~= pb then return pa > pb end
        else
            if sortDesc then
                if pa ~= pb then return pa > pb end
            else
                if pa ~= pb then return pa < pb end
            end
        end

        return tostring(a.id) < tostring(b.id)
    end)

    local index = 0
    for _, s in ipairs(filtered) do
        index += 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,22)
        row.BackgroundColor3 = Color3.fromRGB(230,234,250)
        row.Parent = serverRowsContainer
        makeCorner(row,6)
        local pad = Instance.new("UIPadding", row)
        pad.PaddingLeft  = UDim.new(0,6)
        pad.PaddingRight = UDim.new(0,6)

        local hl = Instance.new("UIListLayout", row)
        hl.FillDirection = Enum.FillDirection.Horizontal
        hl.SortOrder     = Enum.SortOrder.LayoutOrder
        hl.Padding       = UDim.new(0,3)

        makeLabel(row,"Idx",tostring(index), UDim2.new(0.12,0,1,0),UDim2.new(), {
            Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(40,40,70)
        })

        local playing,maxp,isOpen,isNear,isFull = serverOcc(s)
        local tag = isFull and "FULL" or (isNear and "NEAR" or "OPEN")
        local colorTag = isFull and Color3.fromRGB(200,60,80)
            or (isNear and Color3.fromRGB(210,150,60)
            or Color3.fromRGB(60,150,80))

        local suffix = ""
        local list = friendServers[s.id]
        if list and #list > 0 then
            local adminCount, friendCount = 0, #list
            for _, info in ipairs(list) do
                if ADMIN_IDS[info.UserId] then adminCount += 1 end
            end
            local hasAdmin = adminCount > 0
            if friendCount == 1 then
                local info = list[1]
                local dn = info.DisplayName or info.UserName or ("User"..tostring(info.UserId))
                local un = info.UserName and (" @"..info.UserName) or ""
                suffix = string.format(" • %s %s%s", hasAdmin and "👑" or "⭐", dn, un)
            else
                suffix = string.format(" • %s %d friends", hasAdmin and "👑" or "⭐", friendCount)
            end
            if hasAdmin then colorTag = Color3.fromRGB(120,60,160) end
        end

        local occText = string.format("%d/%d (%s)%s", playing, maxp, tag, suffix)

        local occHolder = Instance.new("Frame")
        occHolder.Name = "OccHolder"
        occHolder.Size = UDim2.new(0.34,0,1,0)
        occHolder.BackgroundTransparency = 1
        occHolder.Parent = row

        local occScroll = Instance.new("ScrollingFrame")
        occScroll.Name = "OccScroll"
        occScroll.Size = UDim2.new(1,0,1,0)
        occScroll.BackgroundTransparency = 1
        occScroll.BorderSizePixel = 0
        occScroll.ScrollBarThickness = 2
        occScroll.ScrollingDirection = Enum.ScrollingDirection.X
        occScroll.CanvasSize = UDim2.new(0,0,0,0)
        occScroll.Parent = occHolder

        local occLayout = Instance.new("UIListLayout")
        occLayout.FillDirection = Enum.FillDirection.Horizontal
        occLayout.SortOrder     = Enum.SortOrder.LayoutOrder
        occLayout.Parent        = occScroll

        local occLabel = Instance.new("TextLabel")
        occLabel.Name = "OccText"
        occLabel.BackgroundTransparency = 1
        occLabel.Font = Enum.Font.Gotham
        occLabel.TextSize = 11
        occLabel.TextColor3 = colorTag
        occLabel.TextXAlignment = Enum.TextXAlignment.Left
        occLabel.TextYAlignment = Enum.TextYAlignment.Center
        occLabel.TextWrapped = false
        occLabel.AutomaticSize = Enum.AutomaticSize.X
        occLabel.Size = UDim2.new(0,0,1,0)
        occLabel.Text = occText
        occLabel.Parent = occScroll

        local function updateOccCanvas()
            occScroll.CanvasSize = UDim2.new(0, occLayout.AbsoluteContentSize.X + 4, 0, 0)
        end
        bind(occLayout:GetPropertyChangedSignal("AbsoluteContentSize"), updateOccCanvas)
        task.defer(updateOccCanvas)

        makeLabel(row,"ShortId",shortJobId(s.id), UDim2.new(0.22,0,1,0),UDim2.new(), {
            Font=Enum.Font.GothamSemibold,TextSize=11,TextColor3=Color3.fromRGB(40,40,90),
            XAlign=Enum.TextXAlignment.Center
        })

        local actHolder = Instance.new("Frame")
        actHolder.Size = UDim2.new(0.32,0,1,0)
        actHolder.BackgroundTransparency = 1
        actHolder.Parent = row
        local actLayout = Instance.new("UIListLayout", actHolder)
        actLayout.FillDirection = Enum.FillDirection.Horizontal
        actLayout.SortOrder     = Enum.SortOrder.LayoutOrder
        actLayout.Padding       = UDim.new(0,4)
        actLayout.VerticalAlignment = Enum.VerticalAlignment.Center

        local btnJoin = makeButton(actHolder,"Join","Join", UDim2.new(0.5,-2,1,0))
        local btnCopy = makeButton(actHolder,"Copy","Copy", UDim2.new(0.5,-2,1,0))

        bind(btnJoin.MouseButton1Click, function()
            local ok,err = pcall(function()
                teleportSvc:TeleportToPlaceInstance(game.PlaceId, s.id, localPlayer)
            end)
            if not ok then notify("Server Hoops","Gagal teleport: "..tostring(err),4) end
        end)

        bind(btnCopy.MouseButton1Click, function()
            local ok = pcall(function()
                if setclipboard then setclipboard(tostring(s.id)) end
            end)
            if ok then
                notify("Server Hoops","ServerId disalin ke clipboard.",1.5)
            else
                notify("Server Hoops","Clipboard tidak tersedia, ID dicetak di Output.",3)
                print("[Axa ServerHoops] ServerId:", s.id)
            end
        end)
    end

    serversShown = index
    if serversCountLabel then
        local suffix = serversNextCursor and " (more…)" or ""
        serversCountLabel.Text = string.format("🌐 %d shown / %d loaded%s", serversShown, serversLoaded, suffix)
    end
end

------------------- DATA OPS -------------------
local function resetServersData()
    serversMap        = {}
    serversLoaded     = 0
    serversNextCursor = nil
    serversShown      = 0
    rebuildServersListUI()
end

local function addServers(list)
    for _, s in ipairs(list) do
        if s and s.id and not serversMap[s.id] then
            serversMap[s.id] = s
            serversLoaded += 1
        end
    end
end

local function loadPages(numPages)
    numPages = math.max(1, math.floor(numPages))
    local cursor = serversNextCursor
    if serversLoaded == 0 and cursor == nil then
        cursor = nil
    end

    for _ = 1, numPages do
        local data, nxt = fetchServerPage(game.PlaceId, cursor)
        if #data == 0 then
            serversNextCursor = nil
            break
        end
        addServers(data)
        cursor = nxt
        serversNextCursor = nxt
        if not serversNextCursor then break end
    end

    rebuildServersListUI()
end

------------------- HOOP LOGIC -------------------
local function gatherCandidates()
    local all = serversToArray()
    local candidates, currentId = {}, game.JobId
    for _, s in ipairs(all) do
        if s.id ~= currentId then
            local playing, maxp = tonumber(s.playing) or 0, tonumber(s.maxPlayers) or 0
            if maxp > 0 and playing < maxp then
                table.insert(candidates, s)
            end
        end
    end
    return candidates
end

local function hopServer(preferLowPop)
    local candidates = gatherCandidates()
    if #candidates == 0 and serversLoaded == 0 then
        notify("Server Hoops","Belum ada data server, fetching dulu...",2)
        loadPages(3)
        candidates = gatherCandidates()
    end
    if #candidates == 0 then
        notify("Server Hoops","Tidak ada server lain yang bisa di-join.",4)
        return
    end
    local target
    if preferLowPop then
        table.sort(candidates, function(a,b)
            return (tonumber(a.playing) or 0) < (tonumber(b.playing) or 0)
        end)
        target = candidates[1]
    else
        target = candidates[math.random(1,#candidates)]
    end
    if not target or not target.id then
        notify("Server Hoops","Target server tidak valid.",3)
        return
    end
    notify("Server Hoops","Teleport ke server lain...",2)
    local ok,err = pcall(function()
        teleportSvc:TeleportToPlaceInstance(game.PlaceId, target.id, localPlayer)
    end)
    if not ok then notify("Server Hoops","Gagal teleport: "..tostring(err),5) end
end

local function hopByRange(minPlayers, maxPlayers)
    local candidates = gatherCandidates()
    if #candidates == 0 and serversLoaded == 0 then
        notify("Server Hoops","Belum ada data server, fetching dulu...",2)
        loadPages(3)
        candidates = gatherCandidates()
    end
    local rangeCandidates = {}
    for _, s in ipairs(candidates) do
        local playing = tonumber(s.playing) or 0
        if playing >= minPlayers and playing <= maxPlayers then
            table.insert(rangeCandidates, s)
        end
    end

    if #rangeCandidates == 0 then
        notify("Server Hoops", string.format("Tidak ada server dengan %d-%d player (dan masih ada slot).", minPlayers, maxPlayers), 3)
        return
    end

    table.sort(rangeCandidates, function(a,b)
        return (tonumber(a.playing) or 0) < (tonumber(b.playing) or 0)
    end)

    local target = rangeCandidates[1]
    if not target or not target.id then
        notify("Server Hoops","Target server (range) tidak valid.",3)
        return
    end

    local playing, maxp = serverOcc(target)
    notify("Server Hoops", string.format("Teleport ke server (%d/%d player).", playing, maxp), 2)

    local ok,err = pcall(function()
        teleportSvc:TeleportToPlaceInstance(game.PlaceId, target.id, localPlayer)
    end)
    if not ok then
        notify("Server Hoops","Gagal teleport: "..tostring(err),5)
    end
end

------------------- WIRING BUTTONS / SEARCH / FILTER -------------------
bind(btnToggleOpen.MouseButton1Click,  function()
    includeOpen  = not includeOpen
    btnToggleOpen.Text  = "Open: "..(includeOpen and "ON" or "OFF")
    rebuildServersListUI()
end)

bind(btnToggleNear.MouseButton1Click,  function()
    includeNear  = not includeNear
    btnToggleNear.Text  = "Near: "..(includeNear and "ON" or "OFF")
    rebuildServersListUI()
end)

bind(btnToggleFull.MouseButton1Click,  function()
    includeFull  = not includeFull
    btnToggleFull.Text  = "Full: "..(includeFull and "ON" or "OFF")
    rebuildServersListUI()
end)

bind(btnToggleAdmin.MouseButton1Click, function()
    includeAdmin = not includeAdmin
    btnToggleAdmin.Text = "Admin: "..(includeAdmin and "ON" or "OFF")
    rebuildServersListUI()
end)

bind(btnFriendsOnly.MouseButton1Click, function()
    friendsOnly = not friendsOnly
    btnFriendsOnly.Text = "Friends: "..(friendsOnly and "ON" or "OFF")
    rebuildServersListUI()
end)

bind(btnSort.MouseButton1Click, function()
    sortDesc = not sortDesc
    btnSort.Text = "Sort: "..(sortDesc and "Desc" or "Asc")
    rebuildServersListUI()
end)

bind(btnPlayerFilter.MouseButton1Click, function()
    if playerFilterMode == "ALL" then
        playerFilterMode = "LOW"
    elseif playerFilterMode == "LOW" then
        playerFilterMode = "HIGH"
    else
        playerFilterMode = "ALL"
    end

    if playerFilterMode == "ALL" then
        btnPlayerFilter.Text = "Player: ALL"
    elseif playerFilterMode == "LOW" then
        btnPlayerFilter.Text = "Player: LOW"
    else
        btnPlayerFilter.Text = "Player: HIGH"
    end

    rebuildServersListUI()
end)

local function updateSearch()
    searchText = searchBox.Text or ""
    rebuildServersListUI()
end

bind(searchBox:GetPropertyChangedSignal("Text"), updateSearch)
bind(searchBox.FocusLost, updateSearch)

bind(btnClearSearch.MouseButton1Click, function()
    searchBox.Text = ""
    updateSearch()
end)

bind(btnSrvRefresh.MouseButton1Click, function()
    notify("Server Hoops","Refresh semua server (fetch ulang)...",2)
    resetServersData()
    loadPages(25)
    refreshFriendsPresence()
end)

bind(btnSrvLoad5.MouseButton1Click, function()
    if not serversNextCursor and serversLoaded > 0 then
        notify("Server Hoops","Tidak ada page berikutnya.",2)
        return
    end
    loadPages(5)
    notify("Server Hoops","Load hingga 5 page tambahan.",2)
end)

bind(btnSrvLoadAll.MouseButton1Click, function()
    -- BUGFIX: pakai 'and' (Lua) bukan '&&'
    if not serversNextCursor and serversLoaded > 0 then
        notify("Server Hoops","Semua server yang tersedia sudah diload.",2)
        return
    end
    notify("Server Hoops","Load banyak page (limit internal).",2)
    local maxLoop = 25
    for _ = 1, maxLoop do
        if not alive then break end
        loadPages(1)
        if not serversNextCursor then break end
        task.wait(0.01)
    end
end)

bind(btnHoopRandom.MouseButton1Click, function()
    hopServer(false)
end)

bind(btnHoopLow.MouseButton1Click, function()
    hopServer(true)
end)

bind(btnHoop1_5.MouseButton1Click, function()
    hopByRange(1, 5)
end)

bind(btnHoop6_20.MouseButton1Click, function()
    hopByRange(6, 20)
end)

bind(btnHoop21_40.MouseButton1Click, function()
    hopByRange(21, 40)
end)

bind(btnHoop41_48.MouseButton1Click, function()
    hopByRange(41, 48)
end)

------------------- INITIAL LOAD -------------------
resetServersData()
loadPages(3)
refreshFriendsPresence()
updatePlaceInfo()

task.spawn(function()
    while alive do
        task.wait(30)
        if not alive then break end
        refreshFriendsPresence()
        updatePlaceInfo()
    end
end)

------------------- TAB CLEANUP REGISTER -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive = false
    for _,c in ipairs(connections) do
        pcall(function()
            if c and c.Disconnect then c:Disconnect() end
        end)
    end
end
