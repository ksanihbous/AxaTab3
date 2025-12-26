--==========================================================
--  2AxaTab_Caught.lua
--  Env: TAB_ID, TAB_FRAME, CONTENT_HOLDER, Players, HttpService, dll
--==========================================================

---------------------- SERVICE / ENV -----------------------
local Players           = Players           or game:GetService("Players")
local HttpService       = HttpService       or game:GetService("HttpService")
local RunService        = RunService        or game:GetService("RunService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local UserInputService  = UserInputService  or game:GetService("UserInputService")
local TweenService      = TweenService      or game:GetService("TweenService")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")

local LocalPlayer = LocalPlayer or Players.LocalPlayer or Players.PlayerAdded:Wait()

local WEBHOOK_URL    = "https://discord.com/api/webhooks/1448916289656586262/8zBQ-9lFuNrLFsD1DPl3OMve-KJjvl98m-bYtumWHg8ISjiNSiKdZQiBgP-62h59gkEK"
local BOT_USERNAME   = "Caught Notifier"
local BOT_AVATAR_URL = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png"
local MAX_DESC       = 3600

local FISH_KEYWORDS = {
    "ikan","fish","mirethos","kaelvorn","kraken",
    "shark","whale","ray","eel","salmon","tuna","cod"
}

-- masih disimpan kalau nanti mau dipakai lagi
local FAVORITE_FISH_NAMES = {
    "lumba pink",
    "lele",
    "mirethos",
    "kaelvorn",
}

---------------------- HELPER BASIC ------------------------
local function ui(class, props, parent, children)
    local o = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            o[k] = v
        end
    end
    if parent then
        o.Parent = parent
    end
    if children then
        for _,c in ipairs(children) do
            c.Parent = o
        end
    end
    return o
end

local function safeLower(s)
    return (typeof(s) == "string") and s:lower() or ""
end

local function isFavoriteBaseName(baseName)
    local l = safeLower(baseName)
    for _, fav in ipairs(FAVORITE_FISH_NAMES) do
        if l:find(fav, 1, true) then
            return true
        end
    end
    return false
end

local function extractFishWeightKg(name)
    if not name then return nil end
    local lower  = name:lower()
    local numStr = lower:match("(%d+%.?%d*)%s*kg") or lower:match("(%d+%.?%d*)")
    local w      = numStr and tonumber(numStr) or nil
    return w
end

local function getFishBaseName(rawName)
    if not rawName or rawName == "" then
        return "Unknown Fish"
    end
    local name = rawName
    name = name:gsub("%b[]", "")
    name = name:gsub("%b()", "")
    name = name:gsub("%s*%d+[%d%.]*%s*kg", "")
    name = name:gsub("%s*%d+[%d%.]*$", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = rawName end
    return name
end

---------------------- FRAME TAB / FALLBACK ----------------
local frame = TAB_FRAME
if not frame or not frame.Parent then
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local holder = CONTENT_HOLDER
    if not holder then
        holder = ui("Frame", {
            Name = "ContentHolder_Fallback",
            Size = UDim2.new(0, 480, 0, 280),
            Position = UDim2.new(0.5, -240, 0.5, -140),
            BackgroundColor3 = Color3.fromRGB(22,22,28),
        }, pg, {
            ui("UICorner", { CornerRadius = UDim.new(0,12) })
        })
    end

    frame = ui("Frame", {
        Name = "TabContent_webhook",
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = Color3.fromRGB(240,240,248),
        BorderSizePixel = 0,
    }, holder, {
        ui("UICorner", { CornerRadius = UDim.new(0,12) }),
        ui("UIStroke", { Thickness = 1, Color = Color3.fromRGB(210,210,225), Transparency = 0.3 })
    })
end

-- bersihkan isi TAB, tapi pertahankan corner/stroke bawaan CORE
for _, child in ipairs(frame:GetChildren()) do
    if not child:IsA("UICorner") and not child:IsA("UIStroke") then
        child:Destroy()
    end
end

---------------------- UI HEADER (CARD TAHOE STYLE) --------
local HEADER_CARD_HEIGHT = 92
local LIST_BOTTOM_MARGIN = 30

local headerCard = ui("Frame", {
    Name = "HeaderCard",
    Position = UDim2.new(0, 8, 0, 8),
    Size = UDim2.new(1, -16, 0, HEADER_CARD_HEIGHT),
    BackgroundColor3 = Color3.fromRGB(252,252,255),
    BorderSizePixel = 0,
}, frame, {
    ui("UICorner", { CornerRadius = UDim.new(0, 10) }),
    ui("UIStroke", {
        Thickness    = 1,
        Color        = Color3.fromRGB(220,220,235),
        Transparency = 0.15,
    }),
    ui("UIPadding", {
        PaddingTop    = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft   = UDim.new(0, 10),
        PaddingRight  = UDim.new(0, 10),
    })
})

local header = ui("TextLabel", {
    Name = "Header",
    Size = UDim2.new(1, -120, 0, 20),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = Color3.fromRGB(30,30,55),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "📡 Webhook Caught V2",
}, headerCard)

local sub = ui("TextLabel", {
    Name = "Sub",
    Size = UDim2.new(1, -10, 0, 32),
    Position = UDim2.new(0, 0, 0, 20),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(90,90,120),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    Text = "Pilih player (checkbox). Rod & Ikan dinomori per kategori. Auto split Part ke Discord + Total & Ikan Favorite di Part terakhir.",
}, headerCard)

-- Baris kontrol di bawah card: [SelectAll] [SearchBox] [Send DC]
local controlRow = ui("Frame", {
    Name = "ControlRow",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, -4),
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
}, headerCard)

local selectAllBtn = ui("TextButton", {
    Name = "SelectAll",
    Size = UDim2.new(0, 80, 1, 0),
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(232,234,246),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(60,60,90),
    Text = "Select All",
    AutoButtonColor = true,
}, controlRow, {
    ui("UICorner", { CornerRadius = UDim.new(0, 8) })
})

local sendBtn = ui("TextButton", {
    Name = "SendBtn",
    Size = UDim2.new(0, 90, 1, 0),
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(68, 137, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(255,255,255),
    Text = "Send DC",
    AutoButtonColor = true,
}, controlRow, {
    ui("UICorner", { CornerRadius = UDim.new(0, 8) })
})

local searchBox = ui("TextBox", {
    Name = "SearchBox",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 0),
    Size = UDim2.new(1, -(80 + 90 + 16), 1, 0), -- full width dikurangi SelectAll + Send DC + margin
    BackgroundColor3 = Color3.fromRGB(240,240,250),
    TextColor3 = Color3.fromRGB(80,80,110),
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Text = "",
    PlaceholderText = "Search player...",
}, controlRow, {
    ui("UICorner", { CornerRadius = UDim.new(0, 8) }),
    ui("UIPadding", {
        PaddingLeft  = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 4),
    })
})

---------------------- STATUS LABEL & LIST -----------------
local statusLabel = ui("TextLabel", {
    Name = "Status",
    Size = UDim2.new(1, -10, 0, 18),
    Position = UDim2.new(0, 5, 1, -24),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(90,90,120),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Status: Ready",
}, frame)

local listTopOffset = 8 + HEADER_CARD_HEIGHT + 8

local list = ui("ScrollingFrame", {
    Name = "WebhookList",
    Position = UDim2.new(0, 8, 0, listTopOffset),
    Size = UDim2.new(1, -16, 1, -(listTopOffset + LIST_BOTTOM_MARGIN)),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0,0,0,0),
}, frame)

local layout = ui("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.Name,
    Padding = UDim.new(0,4),
}, list)

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    list.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 10)
end)

local function setStatus(msg)
    statusLabel.Text = "Status: " .. msg
end

---------------------- ROW & FILTER ------------------------
local rows      = {}
local selected  = {}
local selectAll = false

local function matchSearch(pl)
    local q = (searchBox.Text or ""):lower()
    if q == "" then return true end
    local dn = (pl.DisplayName or pl.Name):lower()
    local un = pl.Name:lower()
    return dn:find(q,1,true) or un:find(q,1,true)
end

local function applyFilter()
    for pl, row in pairs(rows) do
        local vis = matchSearch(pl)
        row.Visible = vis
        row.Size = vis and UDim2.new(1,0,0,32) or UDim2.new(1,0,0,0)
    end
end

local function createRow(pl)
    local row = ui("Frame", {
        Name = pl.Name,
        Size = UDim2.new(1,0,0,32),
        BackgroundColor3 = Color3.fromRGB(230,230,244),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
    }, list, {
        ui("UICorner", { CornerRadius = UDim.new(0,8) })
    })

    ui("TextLabel", {
        Name = "Name",
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(60,60,90),
        Text = string.format("%s (@%s)", pl.DisplayName or pl.Name, pl.Name),
    }, row)

    local chk = ui("TextButton", {
        Name = "Check",
        Size = UDim2.new(0, 28, 0, 24),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(215,215,230),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(60,60,90),
        Text = "☐",
    }, row, {
        ui("UICorner", { CornerRadius = UDim.new(0,6) })
    })

    local function applyState()
        local sel = not not selected[pl]
        chk.Text = sel and "☑" or "☐"
        chk.BackgroundColor3 = sel and Color3.fromRGB(140,190,255) or Color3.fromRGB(215,215,230)
    end

    chk.MouseButton1Click:Connect(function()
        selected[pl] = not selected[pl]
        applyState()
    end)

    rows[pl] = row
    selected[pl] = false
    applyState()
end

local function removeRow(pl)
    local row = rows[pl]
    if row then row:Destroy() end
    rows[pl] = nil
    selected[pl] = nil
end

local function refreshList()
    for _, pl in ipairs(Players:GetPlayers()) do
        if not rows[pl] then
            createRow(pl)
        end
    end
    for pl in pairs(rows) do
        local still = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p == pl then
                still = true
                break
            end
        end
        if not still then
            removeRow(pl)
        end
    end
    applyFilter()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

Players.PlayerAdded:Connect(function(pl)
    createRow(pl)
    applyFilter()
end)
Players.PlayerRemoving:Connect(removeRow)

refreshList()

selectAllBtn.MouseButton1Click:Connect(function()
    selectAll = not selectAll
    for pl, row in pairs(rows) do
        selected[pl] = selectAll
        local chk = row:FindFirstChild("Check")
        if chk and chk:IsA("TextButton") then
            chk.Text = selectAll and "☑" or "☐"
            chk.BackgroundColor3 = selectAll and Color3.fromRGB(140,190,255)
                or Color3.fromRGB(215,215,230)
        end
    end
    selectAllBtn.Text = selectAll and "Unselect All" or "Select All"
end)

---------------------- BACKPACK → KATEGORI -----------------
local function getBackpackCategories(pl)
    local rods, fish, others = {}, {}, {}

    local function classify(tool)
        local name  = tool.Name
        local lower = name:lower()

        if lower:find("rod", 1, true) or lower:find("pancing", 1, true) then
            rods[#rods+1] = name
            return
        end

        for _, kw in ipairs(FISH_KEYWORDS) do
            if lower:find(kw, 1, true) then
                fish[#fish+1] = name
                return
            end
        end

        others[#others+1] = name
    end

    local function scan(container)
        if not container then return end
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("Tool") then
                classify(c)
            end
        end
    end

    scan(pl:FindFirstChild("Backpack"))
    scan(pl.Character)

    return rods, fish, others
end

local function buildBlock(pl, rods, fish, others)
    if not rods or not fish or not others then
        rods, fish, others = getBackpackCategories(pl)
    end

    local parts = {}
    parts[#parts+1] = string.format("**%s (@%s)**", pl.DisplayName or pl.Name, pl.Name)

    local function addCat(label, list)
        if #list == 0 then return end
        parts[#parts+1] = label .. ":"
        for i, name in ipairs(list) do
            parts[#parts+1] = string.format("  %d. %s", i, name)
        end
    end

    addCat("Rod",     rods)
    addCat("Ikan",    fish)
    addCat("Lainnya", others)

    return table.concat(parts, "\n")
end

---------------------- HTTP → DISCORD (UNIVERSAL) ----------
local function httpRequestDiscord(url, payload)
    if not url or url == "" then
        return false, "URL kosong"
    end

    local encoded = HttpService:JSONEncode(payload)

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

        if not ok then
            return false, "Executor request error: " .. tostring(res)
        end

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

    if not ok2 then
        return false, "HttpService PostAsync error: " .. tostring(err2)
    end

    return true
end

local function postDiscord(payload)
    payload.username   = payload.username   or BOT_USERNAME
    payload.avatar_url = payload.avatar_url or BOT_AVATAR_URL

    local ok, err = httpRequestDiscord(WEBHOOK_URL, payload)
    if not ok then
        warn("[Axa Backview] Gagal kirim webhook:", err)
    end
    return ok, err
end

---------------------- SPLIT TEKS --------------------------
local function splitText(text, maxLen)
    if #text <= maxLen then
        return { text }
    end

    local chunks  = {}
    local current = ""

    for line in (text .. "\n"):gmatch("(.-)\n") do
        if current == "" then
            current = line
        else
            local candidate = current .. "\n" .. line
            if #candidate > maxLen then
                table.insert(chunks, current)
                current = line
            else
                current = candidate
            end
        end
    end

    if current ~= "" then
        table.insert(chunks, current)
    end

    return chunks
end

---------------------- KUMPUL & KIRIM ----------------------
local function sendWebhookBackview()
    local blocks = {}

    local totalRods   = 0
    local totalFish   = 0
    local totalOthers = 0

    local range_1_100    = 0
    local range_101_400  = 0
    local range_401_599  = 0
    local range_600_799  = 0
    local range_801_1000 = 0

    local fishNameCounts    = {}
    local fishMaxWeight     = {}
    local favoriteCounts    = {}
    local favoriteMaxWeight = {}

    for pl, _ in pairs(rows) do
        if selected[pl] and pl and pl.Parent == Players then
            local rods, fish, others = getBackpackCategories(pl)

            totalRods   = totalRods   + #rods
            totalFish   = totalFish   + #fish
            totalOthers = totalOthers + #others

            for _, fishName in ipairs(fish) do
                local baseName = getFishBaseName(fishName)
                fishNameCounts[baseName] = (fishNameCounts[baseName] or 0) + 1

                local w = extractFishWeightKg(fishName)
                if w then
                    local curMax = fishMaxWeight[baseName]
                    if not curMax or w > curMax then
                        fishMaxWeight[baseName] = w
                    end

                    if w >= 1   and w <= 100  then range_1_100    = range_1_100    + 1
                    elseif w >= 101 and w <= 400 then range_101_400  = range_101_400  + 1
                    elseif w >= 401 and w <= 599 then range_401_599  = range_401_599  + 1
                    elseif w >= 600 and w <= 799 then range_600_799  = range_600_799  + 1
                    elseif w >= 800 and w <= 1000 then range_801_1000 = range_801_1000 + 1
                    end
                end

                local lowerFishName = fishName:lower()
                if lowerFishName:find("(favorite)", 1, true) then
                    favoriteCounts[baseName] = (favoriteCounts[baseName] or 0) + 1
                    if w and w > (favoriteMaxWeight[baseName] or 0) then
                        favoriteMaxWeight[baseName] = w
                    end
                end
            end

            blocks[#blocks+1] = buildBlock(pl, rods, fish, others)
        end
    end

    if #blocks == 0 then
        setStatus("Tidak ada player yang dicentang.")
        return
    end

    local baseDesc = table.concat(blocks, "\n\n")
    local summaryLines = {}

    local totalTools = totalOthers

    summaryLines[#summaryLines+1] = string.format(
        "**Total Rod:** %d  |  **Total Ikan:** %d  |  **Total Tools (Lainnya):** %d",
        totalRods, totalFish, totalTools
    )

    summaryLines[#summaryLines+1] = string.format(
        "**Total Berat Ikan (range):** 1-100 kg: %d, 101-400 kg: %d, 401-599 kg: %d, 600-799 kg: %d, 801-1000 kg: %d",
        range_1_100, range_101_400, range_401_599, range_600_799, range_801_1000
    )

    if next(fishNameCounts) ~= nil then
        summaryLines[#summaryLines+1] = ""
        summaryLines[#summaryLines+1] = "**Jumlah per Nama Ikan:**"

        local arr = {}
        for name, count in pairs(fishNameCounts) do
            arr[#arr+1] = {
                name      = name,
                count     = count,
                maxWeight = fishMaxWeight[name] or 0
            }
        end

        table.sort(arr, function(a,b)
            if a.count == b.count then
                return a.name:lower() < b.name:lower()
            end
            return a.count > b.count
        end)

        local MAX_FISH_SUMMARY = 25
        local shown        = 0
        local totalSpecies = #arr

        for _, e in ipairs(arr) do
            if shown >= MAX_FISH_SUMMARY then
                local remaining = totalSpecies - shown
                if remaining > 0 then
                    summaryLines[#summaryLines+1] = string.format("  ...(+%d jenis ikan lainnya)", remaining)
                end
                break
            end

            if e.maxWeight > 0 then
                summaryLines[#summaryLines+1] = string.format(
                    "  - %s: %d (max %.1f Kg)",
                    e.name, e.count, e.maxWeight
                )
            else
                summaryLines[#summaryLines+1] = string.format(
                    "  - %s: %d",
                    e.name, e.count
                )
            end
            shown = shown + 1
        end
    end

    if next(favoriteCounts) ~= nil then
        summaryLines[#summaryLines+1] = ""
        summaryLines[#summaryLines+1] = "**Ikan Favorite:**"

        local favArr = {}
        for name, count in pairs(favoriteCounts) do
            favArr[#favArr+1] = {
                name      = name,
                count     = count,
                maxWeight = favoriteMaxWeight[name] or 0
            }
        end

        table.sort(favArr, function(a,b)
            if a.count == b.count then
                return a.name:lower() < b.name:lower()
            end
            return a.count > b.count
        end)

        local idx = 1
        for _, e in ipairs(favArr) do
            if e.maxWeight > 0 then
                summaryLines[#summaryLines+1] = string.format(
                    "%d. %s: %d (max %.1f Kg) (Favorite)",
                    idx, e.name, e.count, e.maxWeight
                )
            else
                summaryLines[#summaryLines+1] = string.format(
                    "%d. %s: %d (Favorite)",
                    idx, e.name, e.count
                )
            end
            idx = idx + 1
        end
    end

    local totalsText    = table.concat(summaryLines, "\n")
    local baseChunks    = baseDesc   ~= "" and splitText(baseDesc,   MAX_DESC) or {}
    local summaryChunks = totalsText ~= "" and splitText(totalsText, MAX_DESC) or {}

    local totalParts = #baseChunks + #summaryChunks
    if totalParts == 0 then
        setStatus("Tidak ada data backpack untuk dikirim.")
        return
    end

    local allOk, firstErr = true, nil
    local partIndex = 0

    local function sendPart(desc, isSummary)
        partIndex = partIndex + 1
        local title
        if isSummary then
            title = (totalParts > 1)
                and string.format("📊 Ringkasan & Ikan Favorite (Part %d/%d)", partIndex, totalParts)
                or "📊 Ringkasan & Ikan Favorite"
        else
            title = (totalParts > 1)
                and string.format("🎒 Backpack View (Part %d/%d)", partIndex, totalParts)
                or "🎒 Backpack View"
        end

        local payload = {
            username   = BOT_USERNAME,
            avatar_url = BOT_AVATAR_URL,
            embeds = {{
                title       = title,
                description = desc,
                color       = 0x5b8def
            }}
        }

        local ok, err = postDiscord(payload)
        if not ok then
            allOk    = false
            firstErr = firstErr or err
        end
    end

    for _, d in ipairs(baseChunks) do
        sendPart(d, false)
        task.wait(0.15)
    end
    for _, d in ipairs(summaryChunks) do
        sendPart(d, true)
        task.wait(0.15)
    end

    if allOk then
        setStatus(totalParts == 1 and "Terkirim ✅" or ("Terkirim " .. totalParts .. " Part ✅"))
    else
        setStatus("Sebagian error: " .. tostring(firstErr or "unknown"))
    end
end

---------------------- REFRESH BAG VIEW SAFE ---------------
local function refreshBagViewSafe()
    local f = (_G and _G.AxaHub_BagView_Refresh)
           or (_G and _G.refreshBagAll)
           or rawget(_G or {}, "AxaHub_BagView_Refresh")
    if type(f) == "function" then
        pcall(f)
    end
end

---------------------- BUTTON SEND -------------------------
sendBtn.MouseButton1Click:Connect(function()
    if sendBtn.Text == "Sending..." then return end

    sendBtn.Text = "Sending..."
    setStatus("Mengirim ke Discord...")

    task.spawn(function()
        local ok, err = pcall(sendWebhookBackview)
        if not ok then
            warn("[Axa Backview] Error fatal:", err)
            setStatus("Error: " .. tostring(err))
        end

        refreshBagViewSafe()
        refreshList()

        task.wait(0.4)
        if sendBtn then
            sendBtn.Text = "Send DC"
        end
    end)
end)
