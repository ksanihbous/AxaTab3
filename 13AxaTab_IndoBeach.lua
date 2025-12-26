--==========================================================
--  19AxaTab_IndoBeach.lua
--  TAB 19: "Indo Beach - Fish Giver V2.2+"
--==========================================================

------------------- ENV / TAB -------------------
local frame  = TAB_FRAME
local tabId  = TAB_ID or "indobeach"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = HttpService       or game:GetService("HttpService")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- CONFIG -------------------
-- Argumen untuk GiveFishFunction (contoh dari user)
local FISH_CODE = "safsafwaetqw3fsa"

-- Remote Indo Beach
local GiveFishFunction    = ReplicatedStorage:WaitForChild("GiveFishFunction", 5)
local SellAllFishFunction = ReplicatedStorage:WaitForChild("SellAllFishFunction", 5)
local Sell1FishFunction   = ReplicatedStorage:WaitForChild("Sell1FishFunction", 5)

-- TUNING: agar lebih ringan ke server
local INPUT_DELAY          = 0.01   -- Get Fish Input (N kali) 0.03
local NONSTOP_DELAY        = 0.01   -- Get Fish Nonstop (lebih ringan 0.08 ke server)
local AUTO_SELL_COOLDOWN   = 0.75   -- minimal jeda antar SellAllFish (≤X Kg / All)

-- Sell This Fish agar lebih gesit (lebih kecil dari 3 detik, tapi tetap ada delay)
local SELL_THIS_FISH_DELAY = 0.4    -- jeda antar Sell1Fish saat Sell This Fish batch

------------------- STATE UTAMA -------------------
local alive                  = true
local getFishInputEnabled    = false
local getFishNonstopEnabled  = false
local currentInputTaskId     = 0

local logEntries             = {}

-- PROGRESS STATE (Get Fish Input / Nonstop)
local inputTargetCount       = 0
local inputCurrentCount      = 0

-- SELL MODE ENUM (lengkap + siap expand)
local SellMode = {
    Disable   = 1,
    Under10   = 2,
    Under25   = 3,
    Under50   = 4,
    Under100  = 5,
    Under200  = 6,
    Under400  = 7,
    Under600  = 8,
    Under800  = 9,
    ThisFish  = 10,
    AllFish   = 11,
}

local currentSellMode = SellMode.Disable

-- BACKPACK / DROPDOWN STATE
local scannedBackpack      = false
local fishCategoryList     = {}   -- {"ikan koi goshiki", "ikan rambo merah", ...}
local fishCategoryMap      = {}   -- [name] = true
local selectedFishCategory = nil  -- string nama kategori terpilih

local isSellingThisFish    = false

-- SELL PROGRESS STATE
local sellFishCountByCategory = {}  -- [categoryName] = jumlah ikan terjual

-- COOLDOWN SELL ≤ X KG
local lastSellUnderWeightTick = {}  -- [maxWeight] = tick()

-- LOG RAW TOGGLE
local logRawEnabled = false -- default: tidak log supaya ringan

-- LOOP TOKENS (NONSTOP & SELL THIS FISH) UNTUK GANTI GENERASI TANPA while
local nonstopLoopId      = 0
local sellThisFishLoopId = 0

------------------- UI REFERENCES -------------------
local headerFrame
local bodyFrame

local fishCard
local sellCard
local logCard

local getFishInputToggleBtn
local getFishNonstopToggleBtn
local fishCountInputBox
local lastFishLabel
local inputProgressLabel
local logScrollFrame

local sellModeButtons = {} -- [mode] = button

local sellDropdownButton
local sellDropdownListFrame
local dropdownItemButtons = {} -- [key] = button (termasuk "__DISABLE__" & nama fish)

local sellProgressLabel
local logToggleBtn

-- KEY saat ini untuk highlight dropdown ("__DISABLE__" atau nama fish)
local currentDropdownKey = "__DISABLE__"

------------------- HELPER: NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = dur or 5
        })
    end)
end

------------------- HELPER: UI CREATION -------------------
local function createHeader(parent)
    local h = Instance.new("Frame")
    h.Name = "Header"
    h.Parent = parent
    h.BackgroundTransparency = 1
    h.Size = UDim2.new(1, 0, 0, 44)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = h
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 5, 0, 2)
    title.Size = UDim2.new(1, -10, 0, 22)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(235, 235, 245)
    title.Text = "Indo Beach - Fish Giver V2.2++"

    local desc = Instance.new("TextLabel")
    desc.Name = "SubTitle"
    desc.Parent = h
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.new(0, 5, 0, 22)
    desc.Size = UDim2.new(1, -10, 0, 20)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextColor3 = Color3.fromRGB(180, 180, 195)
    desc.Text = "Get Fish Input / Nonstop + Auto Sell Mode"

    return h
end

local function createBody(parent)
    local body = Instance.new("ScrollingFrame")
    body.Name = "Body"
    body.Parent = parent
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Position = UDim2.new(0, 0, 0, 44)
    body.Size = UDim2.new(1, 0, 1, -44)
    body.ScrollBarThickness = 4
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.ScrollBarImageTransparency = 0.2

    local padding = Instance.new("UIPadding")
    padding.Parent = body
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = body
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 8)

    return body
end

local function createCard(parent, titleText, subtitleText, order)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. (titleText:gsub("%s+", ""))
    card.Parent = parent
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, -4, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.LayoutOrder = order or 1

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Parent = card
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Color = Color3.fromRGB(70, 70, 90)

    local padding = Instance.new("UIPadding")
    padding.Parent = card
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)

    local layout = Instance.new("UIListLayout")
    layout.Parent = card
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    local title = Instance.new("TextLabel")
    title.Name = "CardTitle"
    title.Parent = card
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(220, 220, 235)
    title.Text = titleText

    if subtitleText and subtitleText ~= "" then
        local sub = Instance.new("TextLabel")
        sub.Name = "CardSubTitle"
        sub.Parent = card
        sub.BackgroundTransparency = 1
        sub.Size = UDim2.new(1, 0, 0, 18)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextColor3 = Color3.fromRGB(150, 150, 165)
        sub.Text = subtitleText
    end

    return card
end

local function createToggleButton(parent, labelText)
    local row = Instance.new("Frame")
    row.Name = "ToggleRow"
    row.Parent = parent
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 26)

    local layout = Instance.new("UIListLayout")
    layout.Parent = row
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Parent = row
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(200, 200, 215)
    lbl.Text = labelText

    local btn = Instance.new("TextButton")
    btn.Name = "Toggle"
    btn.Parent = row
    btn.Size = UDim2.new(0, 70, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(235, 235, 245)
    btn.Text = "OFF"

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    return row, btn
end

local function createFishGiverCard(parent, order)
    local card = createCard(
        parent,
        "Fish Giver Control",
        "Get Fish Input (N kali) & Get Fish Nonstop via GiveFishFunction",
        order
    )

    -- Last Fish
    local lastLbl = Instance.new("TextLabel")
    lastLbl.Name = "LastFishLabel"
    lastLbl.Parent = card
    lastLbl.BackgroundTransparency = 1
    lastLbl.Size = UDim2.new(1, 0, 0, 18)
    lastLbl.Font = Enum.Font.Gotham
    lastLbl.TextSize = 12
    lastLbl.TextXAlignment = Enum.TextXAlignment.Left
    lastLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
    lastLbl.Text = "Last Fish: -"

    -- Get Fish Input toggle
    local _, toggleInput = createToggleButton(card, "Get Fish Input (Jumlah tertentu)")

    -- Input jumlah
    local input = Instance.new("TextBox")
    input.Name = "FishCountInput"
    input.Parent = card
    input.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    input.Size = UDim2.new(1, 0, 0, 26)
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = Color3.fromRGB(225, 225, 235)
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Text = "10"
    input.PlaceholderText = "Jumlah Ikan (contoh: 10, 100, 1000 tanpa batas)"
    input.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = input

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Parent = input
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.3
    inputStroke.Color = Color3.fromRGB(60, 60, 85)

    -- Get Fish Nonstop toggle
    local _, toggleNonstop = createToggleButton(card, "Get Fish Nonstop (Loop terus menerus)")

    -- Progress label
    local prog = Instance.new("TextLabel")
    prog.Name = "InputProgressLabel"
    prog.Parent = card
    prog.BackgroundTransparency = 1
    prog.Size = UDim2.new(1, 0, 0, 18)
    prog.Font = Enum.Font.Gotham
    prog.TextSize = 11
    prog.TextXAlignment = Enum.TextXAlignment.Left
    prog.TextColor3 = Color3.fromRGB(170, 200, 255)
    prog.Text = "Progress: -"

    return card, toggleInput, toggleNonstop, input, lastLbl, prog
end

local function createSellFishCard(parent, order)
    local card = createCard(
        parent,
        "Sell Fish Control (Auto Sell Mode)",
        "Mode jual otomatis setiap berhasil Get Fish (2 kolom, scrollable) + klik tombol = langsung Sell sekali",
        order
    )

    -- Grid mode sell
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "SellScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Size = UDim2.new(1, 0, 0, 110)
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarImageTransparency = 0.2

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 2)

    local grid = Instance.new("UIGridLayout")
    grid.Parent = scroll
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.CellSize = UDim2.new(0.5, -4, 0, 26)

    local function addSellButton(mode, text)
        local btn = Instance.new("TextButton")
        btn.Name = "SellMode_" .. tostring(mode)
        btn.Parent = scroll
        btn.Size = UDim2.new(1, 0, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
        btn.TextWrapped = true
        btn.Text = text

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        local s = Instance.new("UIStroke")
        s.Parent = btn
        s.Thickness = 1
        s.Transparency = 0.4
        s.Color = Color3.fromRGB(60, 60, 85)

        sellModeButtons[mode] = btn
    end

    -- 2 kolom, vertikal scroll + mode lengkap
    addSellButton(SellMode.Disable,  "Disable")
    addSellButton(SellMode.Under10,  "Sell ≤ 10 Kg")
    addSellButton(SellMode.Under25,  "Sell ≤ 25 Kg")
    addSellButton(SellMode.Under50,  "Sell ≤ 50 Kg")
    addSellButton(SellMode.Under100, "Sell ≤ 100 Kg")
    addSellButton(SellMode.Under200, "Sell ≤ 200 Kg")
    addSellButton(SellMode.Under400, "Sell ≤ 400 Kg")
    addSellButton(SellMode.Under600, "Sell ≤ 600 Kg")
    addSellButton(SellMode.Under800, "Sell ≤ 800 Kg")
    addSellButton(SellMode.ThisFish, "Sell This Fish")
    addSellButton(SellMode.AllFish,  "Sell All Fish")

    -- Label dropdown
    local selLabel = Instance.new("TextLabel")
    selLabel.Name = "SelectedFishLabel"
    selLabel.Parent = card
    selLabel.BackgroundTransparency = 1
    selLabel.Size = UDim2.new(1, 0, 0, 18)
    selLabel.Font = Enum.Font.Gotham
    selLabel.TextSize = 11
    selLabel.TextXAlignment = Enum.TextXAlignment.Left
    selLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
    selLabel.Text = "Selected Fish (Sell This Fish):"

    -- Dropdown button
    local ddButton = Instance.new("TextButton")
    ddButton.Name = "FishDropdownButton"
    ddButton.Parent = card
    ddButton.Size = UDim2.new(1, 0, 0, 26)
    ddButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    ddButton.AutoButtonColor = true
    ddButton.Font = Enum.Font.Gotham
    ddButton.TextSize = 13
    ddButton.TextXAlignment = Enum.TextXAlignment.Left
    ddButton.TextColor3 = Color3.fromRGB(225, 225, 235)
    ddButton.Text = "Disable"  -- default teks: Disable

    local ddCorner = Instance.new("UICorner")
    ddCorner.CornerRadius = UDim.new(0, 6)
    ddCorner.Parent = ddButton

    local ddStroke = Instance.new("UIStroke")
    ddStroke.Parent = ddButton
    ddStroke.Thickness = 1
    ddStroke.Transparency = 0.3
    ddStroke.Color = Color3.fromRGB(60, 60, 85)

    -- Dropdown list frame
    local ddList = Instance.new("ScrollingFrame")
    ddList.Name = "FishDropdownList"
    ddList.Parent = card
    ddList.BackgroundTransparency = 1
    ddList.BorderSizePixel = 0
    ddList.Size = UDim2.new(1, 0, 0, 0)
    ddList.Visible = false
    ddList.ScrollBarThickness = 4
    ddList.CanvasSize = UDim2.new(0, 0, 0, 0)
    ddList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ddList.ScrollBarImageTransparency = 0.2

    local ddPad = Instance.new("UIPadding")
    ddPad.Parent = ddList
    ddPad.PaddingTop = UDim.new(0, 2)
    ddPad.PaddingBottom = UDim.new(0, 4)
    ddPad.PaddingLeft = UDim.new(0, 2)
    ddPad.PaddingRight = UDim.new(0, 2)

    local ddLayout = Instance.new("UIListLayout")
    ddLayout.Parent = ddList
    ddLayout.FillDirection = Enum.FillDirection.Vertical
    ddLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ddLayout.Padding = UDim.new(0, 2)

    -- Sell Progress label
    local prog = Instance.new("TextLabel")
    prog.Name = "SellProgressLabel"
    prog.Parent = card
    prog.BackgroundTransparency = 1
    prog.Size = UDim2.new(1, 0, 0, 18)
    prog.Font = Enum.Font.Gotham
    prog.TextSize = 11
    prog.TextXAlignment = Enum.TextXAlignment.Left
    prog.TextColor3 = Color3.fromRGB(190, 220, 255)
    prog.Text = "Sell Progress: -"

    return card, ddButton, ddList, prog
end

local function createFishLogCard(parent, order)
    local card = createCard(
        parent,
        "Fish Log (Last 100)",
        "Riwayat ikan & sell status",
        order
    )

    -- Toggle Log RAW
    local _, toggleBtn = createToggleButton(card, "Log RAW (Fish & Sell)")

    local logFrame = Instance.new("ScrollingFrame")
    logFrame.Name = "LogScroll"
    logFrame.Parent = card
    logFrame.BackgroundTransparency = 1
    logFrame.BorderSizePixel = 0
    logFrame.Size = UDim2.new(1, 0, 0, 200)
    logFrame.ScrollBarThickness = 4
    logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logFrame.ScrollBarImageTransparency = 0.2

    local padding = Instance.new("UIPadding")
    padding.Parent = logFrame
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 2)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = logFrame
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)

    return card, logFrame, toggleBtn
end

------------------- BUILD UI -------------------
headerFrame = createHeader(frame)
bodyFrame   = createBody(frame)

fishCard, getFishInputToggleBtn, getFishNonstopToggleBtn, fishCountInputBox, lastFishLabel, inputProgressLabel =
    createFishGiverCard(bodyFrame, 1)

sellCard, sellDropdownButton, sellDropdownListFrame, sellProgressLabel =
    createSellFishCard(bodyFrame, 2)

logCard, logScrollFrame, logToggleBtn = createFishLogCard(bodyFrame, 3)

------------------- HELPER: TOGGLE VISUAL -------------------
local function updateToggleVisual(button, state)
    if not button then return end
    if state then
        button.Text = "ON"
        button.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    else
        button.Text = "OFF"
        button.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
    end
end

-- Set default visual OFF
updateToggleVisual(getFishInputToggleBtn, false)
updateToggleVisual(getFishNonstopToggleBtn, false)
updateToggleVisual(logToggleBtn, false) -- LOG RAW default OFF

------------------- HELPER: LOG -------------------
local function appendLog(text)
    -- Hanya log jika:
    -- 1) tab masih alive
    -- 2) log frame ada
    -- 3) logRawEnabled = true (LOG RAW ON)
    if not (alive and logScrollFrame and logRawEnabled) then
        return
    end

    local lbl = Instance.new("TextLabel")
    lbl.Name = "LogItem"
    lbl.Parent = logScrollFrame
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -4, 0, 16)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.Text = text

    table.insert(logEntries, lbl)

    -- Batasi 100 baris terakhir
    if #logEntries > 100 then
        local oldest = table.remove(logEntries, 1)
        if oldest then
            oldest:Destroy()
        end
    end
end

------------------- HELPER: PROGRESS LABEL (GET FISH) -------------------
local function updateInputProgressLabel()
    if not inputProgressLabel then return end

    if inputTargetCount > 0 then
        local shown = math.min(inputCurrentCount, inputTargetCount)
        inputProgressLabel.Text = string.format("Progress: %d/%d fish", shown, inputTargetCount)
    else
        if getFishNonstopEnabled then
            inputProgressLabel.Text = string.format("Progress: %d fish (Nonstop)", inputCurrentCount)
        else
            inputProgressLabel.Text = "Progress: -"
        end
    end
end

------------------- HELPER: PROGRESS LABEL (SELL THIS FISH) -------------------
local function updateSellProgressLabel()
    if not sellProgressLabel then return end

    if not selectedFishCategory or selectedFishCategory == "" then
        sellProgressLabel.Text = "Sell Progress: -"
        return
    end

    local count = sellFishCountByCategory[selectedFishCategory] or 0
    sellProgressLabel.Text = string.format("Sell Progress: %d %s", count, selectedFishCategory)
end

------------------- HELPER: CLEAN NAMA IKAN (KATEGORI) -------------------
local function cleanFishName(raw)
    if type(raw) ~= "string" then
        return ""
    end

    local name = raw

    -- hapus (Favorite)
    name = name:gsub("%(Favorite%)", "")
    -- kompres spasi
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")

    -- ambil sebelum '(' (berat, dll)
    local base = name:match("^(.-)%s*%(")
    if base and base ~= "" then
        name = base:gsub("%s+$", "")
    end

    return name
end

------------------- HELPER: CEK TOOL YANG DIKELUARKAN DARI DROPDOWN -------------------
local function isIgnoredToolForDropdown(toolName)
    if type(toolName) ~= "string" then return false end

    local lower   = toolName:lower()
    local compact = lower:gsub("%s+", "")

    -- semua jenis Rod di akhir nama (NormalRod, VIP Rod, WaveRod, dsb)
    if compact:sub(-3) == "rod" then
        return true
    end

    -- Torch
    if lower:find("torch") then
        return true
    end

    -- Pickaxe / Picaxe
    if lower:find("pickaxe") or lower:find("picaxe") then
        return true
    end

    return false
end

------------------- HELPER: PARSE NAMA IKAN (RAW RESULT) -------------------
local function getFishNameFromResult(res)
    local fishName = "Unknown Fish"
    local t = typeof(res)

    if t == "string" then
        fishName = res
    elseif t == "table" then
        if res.FishName then
            fishName = tostring(res.FishName)
        elseif res.Name then
            fishName = tostring(res.Name)
        elseif res.name then
            fishName = tostring(res.name)
        elseif res[1] and typeof(res[1]) == "string" then
            fishName = res[1]
        else
            -- fallback cukup tostring table, tanpa JSONEncode agar lebih ringan
            fishName = tostring(res)
        end
    else
        fishName = tostring(res)
    end

    return fishName
end

------------------- BACKPACK SCAN (SEKALI DIAWAL, KECUALI ROD/TORCH/PICAXE) -------------------
local function scanBackpackOnce()
    if scannedBackpack then return end
    scannedBackpack = true

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    if not backpack then
        local ok, res = pcall(function()
            return LocalPlayer:WaitForChild("Backpack", 5)
        end)
        if ok then
            backpack = res
        end
    end

    if not backpack then
        appendLog("[Dropdown] Backpack tidak ditemukan untuk scan.")
        return
    end

    fishCategoryList = {}
    fishCategoryMap  = {}

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Keluarkan NormalRod / Rod lain, Torch, Picaxe/Pickaxe dari kategori fish
            if not isIgnoredToolForDropdown(tool.Name) then
                local cname = cleanFishName(tool.Name)
                if cname ~= "" and not fishCategoryMap[cname] then
                    fishCategoryMap[cname] = true
                    table.insert(fishCategoryList, cname)
                end
            end
        end
    end

    table.sort(fishCategoryList, function(a, b)
        return a:lower() < b:lower()
    end)
end

------------------- HELPER: CARI TOOL FISH PER KATEGORI -------------------
local function findFishToolByCategory(categoryName)
    if not categoryName or categoryName == "" then
        return nil
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    local char     = LocalPlayer.Character

    local function searchContainer(container)
        if not container then return nil end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") then
                if isIgnoredToolForDropdown(inst.Name) then
                    -- lewati Rod/Torch/Picaxe
                else
                    local cname = cleanFishName(inst.Name)
                    if cname == categoryName then
                        return inst
                    end
                end
            end
        end
        return nil
    end

    local t = searchContainer(char)
    if t then return t end
    return searchContainer(backpack)
end

------------------- HELPER: HITUNG JUMLAH FISH KATEGORI (BACKPACK + CHARACTER) -------------------
local function countFishToolsInCategory(categoryName)
    if not categoryName or categoryName == "" then
        return 0
    end

    local count = 0

    local function countInContainer(container)
        if not container then return end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") then
                if not isIgnoredToolForDropdown(inst.Name) then
                    local cname = cleanFishName(inst.Name)
                    if cname == categoryName then
                        count += 1
                    end
                end
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    local char     = LocalPlayer.Character

    countInContainer(char)
    countInContainer(backpack)

    return count
end

------------------- HELPER: SELL IMPLEMENTATION -------------------
local function sellUnderWeight(maxWeight)
    if not SellAllFishFunction then
        appendLog("[Sell] SellAllFishFunction tidak ditemukan.")
        return
    end

    -- Cooldown per maxWeight agar tidak spam remote
    local now = tick()
    local last = lastSellUnderWeightTick[maxWeight]
    if last and (now - last) < AUTO_SELL_COOLDOWN then
        -- Masih dalam cooldown, lewati saja
        return
    end
    lastSellUnderWeightTick[maxWeight] = now

    local ok, res = pcall(function()
        return SellAllFishFunction:InvokeServer(maxWeight)
    end)

    if not ok then
        appendLog("[Sell] Error SellAllFish(" .. tostring(maxWeight) .. "): " .. tostring(res))
    else
        appendLog("[Sell] SellAllFish ≤ " .. tostring(maxWeight) .. " Kg OK.")
    end
end

local function sellAllFish()
    -- SELL ALL (contoh: 10000)
    sellUnderWeight(10000)
end

------------------- SELL THIS FISH (LOGIC BARU, LEBIH GESIT) -------------------
local function finishSellThisFishLoop(reason)
    if isSellingThisFish then
        isSellingThisFish = false
        appendLog("[Sell] SellThisFish selesai: " .. tostring(reason or "Selesai"))
    end
end

local function sellThisFishAll()
    if not Sell1FishFunction then
        appendLog("[Sell] Sell1FishFunction tidak ditemukan.")
        return
    end

    if not selectedFishCategory or selectedFishCategory == "" then
        appendLog("[Sell] Selected Fish belum dipilih (dropdown).")
        return
    end

    if isSellingThisFish then
        appendLog("[Sell] SellThisFish loop sudah berjalan.")
        return
    end

    if currentSellMode ~= SellMode.ThisFish then
        appendLog("[Sell] Mode sekarang bukan 'Sell This Fish'.")
        return
    end

    local total = countFishToolsInCategory(selectedFishCategory)
    if total <= 0 then
        appendLog("[Sell] Tidak ada fish kategori '" .. selectedFishCategory .. "' di Backpack/Character.")
        return
    end

    isSellingThisFish = true
    sellThisFishLoopId += 1
    local thisLoopId = sellThisFishLoopId
    local categoryName = selectedFishCategory

    appendLog(string.format("[Sell] Mulai SellThisFish batch: %s (total ± %d ikan)", categoryName, total))

    task.spawn(function()
        for i = 1, total do
            if not alive then
                finishSellThisFishLoop("Tab tidak aktif")
                return
            end
            if currentSellMode ~= SellMode.ThisFish then
                finishSellThisFishLoop("Mode berubah dari ThisFish")
                return
            end
            if thisLoopId ~= sellThisFishLoopId then
                -- Generasi loop sudah diganti, hentikan batch ini
                return
            end

            local char = LocalPlayer.Character
            if not char then
                finishSellThisFishLoop("Character belum siap")
                return
            end

            local tool = findFishToolByCategory(categoryName)
            if not tool then
                finishSellThisFishLoop("Fish kategori '" .. categoryName .. "' sudah habis sebelum selesai batch.")
                return
            end

            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
            else
                tool.Parent = char
            end

            local ok, res = pcall(function()
                -- SELL THIS FISH (math.huge) sesuai contoh user
                return Sell1FishFunction:InvokeServer(math.huge)
            end)

            if not ok then
                appendLog("[Sell] Error Sell1Fish(math.huge): " .. tostring(res))
                finishSellThisFishLoop("Error Sell1Fish")
                return
            else
                appendLog(string.format("[Sell] Sell1Fish OK (%s) ke-%d", categoryName, i))

                -- Update counter & progress label
                sellFishCountByCategory[categoryName] =
                    (sellFishCountByCategory[categoryName] or 0) + 1
                updateSellProgressLabel()
            end

            -- Jeda kecil antar jualan supaya tetap ringan tapi gesit
            if i < total then
                task.wait(SELL_THIS_FISH_DELAY)
            end
        end

        -- Jika sampai sini, batch selesai normal
        if alive and currentSellMode == SellMode.ThisFish and thisLoopId == sellThisFishLoopId then
            finishSellThisFishLoop("Selesai jual semua ikan kategori " .. tostring(categoryName))
        else
            finishSellThisFishLoop("Dihentikan sebelum selesai")
        end
    end)
end

------------------- SELL MODE HANDLER -------------------
local sellModeName = {
    [SellMode.Disable]  = "Disable",
    [SellMode.Under10]  = "Sell ≤ 10 Kg",
    [SellMode.Under25]  = "Sell ≤ 25 Kg",
    [SellMode.Under50]  = "Sell ≤ 50 Kg",
    [SellMode.Under100] = "Sell ≤ 100 Kg",
    [SellMode.Under200] = "Sell ≤ 200 Kg",
    [SellMode.Under400] = "Sell ≤ 400 Kg",
    [SellMode.Under600] = "Sell ≤ 600 Kg",
    [SellMode.Under800] = "Sell ≤ 800 Kg",
    [SellMode.ThisFish] = "Sell This Fish",
    [SellMode.AllFish]  = "Sell All Fish",
}

local function setSellMode(mode)
    currentSellMode = mode

    for m, btn in pairs(sellModeButtons) do
        if m == mode then
            btn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            btn.TextColor3 = Color3.fromRGB(245, 245, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        end
    end

    local name = sellModeName[mode] or ("Mode " .. tostring(mode))
    appendLog("[Sell] Mode diubah: " .. name)
    notify("Indo Beach - Sell Mode", name, 3)

    -- Jika keluar dari mode ThisFish, pastikan loop dimatikan
    if mode ~= SellMode.ThisFish then
        sellThisFishLoopId += 1 -- batalkan batch lama
        finishSellThisFishLoop("Mode berubah dari ThisFish")
    end

    -- Update label progress sesuai kategori terpilih
    updateSellProgressLabel()
end

local function applyAutoSellAfterCatch()
    if currentSellMode == SellMode.Disable then
        return
    elseif currentSellMode == SellMode.Under10 then
        sellUnderWeight(10)
    elseif currentSellMode == SellMode.Under25 then
        sellUnderWeight(25)
    elseif currentSellMode == SellMode.Under50 then
        sellUnderWeight(50)
    elseif currentSellMode == SellMode.Under100 then
        sellUnderWeight(100)
    elseif currentSellMode == SellMode.Under200 then
        sellUnderWeight(200)
    elseif currentSellMode == SellMode.Under400 then
        sellUnderWeight(400)
    elseif currentSellMode == SellMode.Under600 then
        sellUnderWeight(600)
    elseif currentSellMode == SellMode.Under800 then
        sellUnderWeight(800)
    elseif currentSellMode == SellMode.ThisFish then
        -- Jual semua fish kategori terpilih, batch cepat
        sellThisFishAll()
    elseif currentSellMode == SellMode.AllFish then
        sellAllFish()
    end
end

------------------- DROPDOWN BUILD -------------------
local function buildFishDropdownItems()
    if not sellDropdownListFrame then return end

    -- hapus item lama (hanya TextButton)
    for _, child in ipairs(sellDropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    dropdownItemButtons = {}

    -- ITEM PERTAMA: DISABLE
    do
        local btn = Instance.new("TextButton")
        btn.Name = "FishItem_Disable"
        btn.Parent = sellDropdownListFrame
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Text = "Disable"

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn

        dropdownItemButtons["__DISABLE__"] = btn

        btn.MouseButton1Click:Connect(function()
            selectedFishCategory = nil
            currentDropdownKey   = "__DISABLE__"
            if sellDropdownButton then
                sellDropdownButton.Text = "Disable"
            end

            -- highlight
            for key, b in pairs(dropdownItemButtons) do
                if key == currentDropdownKey then
                    b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                    b.TextColor3       = Color3.fromRGB(245, 245, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    b.TextColor3       = Color3.fromRGB(220, 220, 230)
                end
            end

            -- progress reset
            updateSellProgressLabel()

            -- tutup dropdown
            if sellDropdownListFrame then
                sellDropdownListFrame.Visible = false
                sellDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
            end

            appendLog("[Dropdown] Selected Fish diubah ke: Disable")
        end)
    end

    -- ITEM FISH: TAMPILKAN "jumlah x nama"
    for _, cname in ipairs(fishCategoryList) do
        local btn = Instance.new("TextButton")
        btn.Name = "FishItem_" .. cname
        btn.Parent = sellDropdownListFrame
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left

        local initialCount = countFishToolsInCategory(cname)
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Text = string.format("%dx %s", initialCount, cname)

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn

        dropdownItemButtons[cname] = btn

        btn.MouseButton1Click:Connect(function()
            selectedFishCategory = cname
            currentDropdownKey   = cname

            if sellDropdownButton then
                local currentCount = countFishToolsInCategory(cname)
                sellDropdownButton.Text = string.format("%dx %s", currentCount, cname)
            end

            -- highlight pilihan
            for key, b in pairs(dropdownItemButtons) do
                if key == currentDropdownKey then
                    b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                    b.TextColor3       = Color3.fromRGB(245, 245, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    b.TextColor3       = Color3.fromRGB(220, 220, 230)
                end
            end

            -- update progress label untuk kategori baru
            updateSellProgressLabel()

            -- tutup dropdown
            if sellDropdownListFrame then
                sellDropdownListFrame.Visible = false
                sellDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
            end

            appendLog("[Dropdown] Selected Fish diubah ke: " .. selectedFishCategory)

            -- Jika mode Sell This Fish aktif, langsung mulai batch jual semua ikan kategori ini
            if currentSellMode == SellMode.ThisFish then
                sellThisFishAll()
            end
        end)
    end

    -- DEFAULT: jika belum pernah pilih, tetap di "__DISABLE__"
    if not selectedFishCategory then
        currentDropdownKey = "__DISABLE__"
        if sellDropdownButton then
            sellDropdownButton.Text = "Disable"
        end
    end

    -- highlight sesuai currentDropdownKey
    for key, b in pairs(dropdownItemButtons) do
        if key == currentDropdownKey then
            b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            b.TextColor3       = Color3.fromRGB(245, 245, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            b.TextColor3       = Color3.fromRGB(220, 220, 230)
        end
    end

    -- sync progress label
    updateSellProgressLabel()
end

local function initFishDropdown()
    if not sellDropdownButton or not sellDropdownListFrame then return end
    scanBackpackOnce()

    if #fishCategoryList == 0 then
        if sellDropdownButton then
            sellDropdownButton.Text = "Disable (Backpack kosong / fish tidak ditemukan)"
        end
        -- tetap bisa buka dropdown, hanya ada tombol Disable
        buildFishDropdownItems()
        return
    end

    -- build item dengan Disable di atas + daftar fish
    buildFishDropdownItems()
end

------------------- HELPER: REQUEST 1 FISH -------------------
local function requestOneFish()
    if not (alive and GiveFishFunction) then
        appendLog("GiveFishFunction tidak tersedia.")
        return nil
    end

    local ok, res = pcall(function()
        return GiveFishFunction:InvokeServer(FISH_CODE)
    end)

    if not ok then
        local msg = "Error GiveFishFunction: " .. tostring(res)
        warn("[IndoBeach] " .. msg)
        appendLog(msg)
        return nil
    end

    local fishName = getFishNameFromResult(res)

    if lastFishLabel then
        lastFishLabel.Text = "Last Fish: " .. fishName
    end

    appendLog("Got Fish: " .. fishName)

    -- Auto Sell setelah dapat ikan (mode sesuai pilihan)
    applyAutoSellAfterCatch()

    return fishName, res
end

------------------- LOGIC: GET FISH INPUT (N KALI) -------------------
local function startGetFishInput()
    if not alive then return end

    local rawText = fishCountInputBox and fishCountInputBox.Text or ""
    local count = tonumber(rawText)

    if not count or count <= 0 then
        notify("Indo Beach", "Jumlah ikan tidak valid. Isi angka > 0.", 5)
        getFishInputEnabled = false
        updateToggleVisual(getFishInputToggleBtn, false)
        inputTargetCount  = 0
        inputCurrentCount = 0
        updateInputProgressLabel()
        return
    end

    notify("Indo Beach", "Mulai Get Fish Input x" .. tostring(count), 4)

    currentInputTaskId = currentInputTaskId + 1
    local thisTaskId = currentInputTaskId

    inputTargetCount  = count
    inputCurrentCount = 0
    updateInputProgressLabel()

    task.spawn(function()
        for i = 1, count do
            if not alive then break end
            if not getFishInputEnabled then break end
            if currentInputTaskId ~= thisTaskId then break end

            requestOneFish()

            inputCurrentCount = i
            updateInputProgressLabel()

            task.wait(INPUT_DELAY) -- jeda kecil agar tetap ringan
        end

        -- Jika masih task yang sama, matikan toggle & info selesai
        if alive and currentInputTaskId == thisTaskId then
            getFishInputEnabled = false
            updateToggleVisual(getFishInputToggleBtn, false)
            notify("Indo Beach", "Get Fish Input selesai / berhenti.", 4)
        end
    end)
end

------------------- LOGIC: GET FISH NONSTOP (TANPA while) -------------------
local function scheduleNonstopStep(loopId)
    task.spawn(function()
        if not alive then return end
        if not getFishNonstopEnabled then return end
        if loopId ~= nonstopLoopId then return end

        requestOneFish()

        inputCurrentCount = inputCurrentCount + 1
        updateInputProgressLabel()

        task.wait(NONSTOP_DELAY)

        if not alive then return end
        if not getFishNonstopEnabled then return end
        if loopId ~= nonstopLoopId then return end

        scheduleNonstopStep(loopId)
    end)
end

local function startGetFishNonstop()
    if not alive then return end

    inputTargetCount  = 0
    inputCurrentCount = 0
    updateInputProgressLabel()

    nonstopLoopId += 1
    local thisLoopId = nonstopLoopId

    notify("Indo Beach", "Get Fish Nonstop dimulai.", 4)
    scheduleNonstopStep(thisLoopId)
end

------------------- UI EVENTS -------------------
-- Inisialisasi dropdown (scan Backpack sekali diawal)
initFishDropdown()

-- Toggle list dropdown (buka/tutup)
if sellDropdownButton then
    sellDropdownButton.MouseButton1Click:Connect(function()
        if not sellDropdownListFrame then return end

        -- kalau belum pernah scan (jaga-jaga), coba lagi
        if not scannedBackpack then
            initFishDropdown()
        end

        local open = not sellDropdownListFrame.Visible
        sellDropdownListFrame.Visible = open
        if open then
            sellDropdownListFrame.Size = UDim2.new(1, 0, 0, 120)
        else
            sellDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end)
end

if fishCountInputBox then
    fishCountInputBox.FocusLost:Connect(function()
        local n = tonumber(fishCountInputBox.Text)
        if not n or n <= 0 then
            fishCountInputBox.Text = "10"
        end
    end)
end

if getFishInputToggleBtn then
    getFishInputToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        getFishInputEnabled = not getFishInputEnabled
        updateToggleVisual(getFishInputToggleBtn, getFishInputEnabled)

        if getFishInputEnabled then
            startGetFishInput()
        else
            notify("Indo Beach", "Get Fish Input dimatikan oleh user.", 3)
            -- progress dibiarkan menampilkan hasil terakhir
        end
    end)
end

if getFishNonstopToggleBtn then
    getFishNonstopToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        getFishNonstopEnabled = not getFishNonstopEnabled
        updateToggleVisual(getFishNonstopToggleBtn, getFishNonstopEnabled)

        if getFishNonstopEnabled then
            startGetFishNonstop()
        else
            -- stop: cukup matikan flag, loop akan berhenti sendiri
            notify("Indo Beach", "Get Fish Nonstop berhenti.", 4)
        end
    end)
end

-- Toggle LOG RAW
if logToggleBtn then
    logToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end
        logRawEnabled = not logRawEnabled
        updateToggleVisual(logToggleBtn, logRawEnabled)
    end)
end

-- Event untuk semua tombol Sell Mode
for mode, btn in pairs(sellModeButtons) do
    btn.MouseButton1Click:Connect(function()
        if not alive then return end
        -- 1) Ubah mode auto sell
        setSellMode(mode)
        -- 2) Langsung jalankan Sell sesuai mode saat ini
        applyAutoSellAfterCatch()
    end)
end

-- Set default sell mode = Disable
setSellMode(SellMode.Disable)

------------------- TAB CLEANUP (INTEGRASI CORE) -------------------
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive = false
    getFishInputEnabled   = false
    getFishNonstopEnabled = false
    isSellingThisFish     = false
    sellThisFishLoopId    = sellThisFishLoopId + 1
    nonstopLoopId         = nonstopLoopId + 1
end
