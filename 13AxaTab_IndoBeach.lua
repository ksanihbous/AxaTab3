--==========================================================
--  13AxaTab_IndoBeach.lua
--  TAB 13: "Indo Beach - Fish Giver V1 + Farm Mining & Sell Ores"
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

-- Remote Indo Beach - Fish
local GiveFishFunction    = ReplicatedStorage:WaitForChild("GiveFishFunction", 5)
local SellAllFishFunction = ReplicatedStorage:WaitForChild("SellAllFishFunction", 5)
local Sell1FishFunction   = ReplicatedStorage:WaitForChild("Sell1FishFunction", 5)

-- Remote Indo Beach - Mining / Ores
local GiveCrystalFunction     = ReplicatedStorage:WaitForChild("GiveCrystal", 5)
local SellOreBackpackFunction = ReplicatedStorage:WaitForChild("SellOreBackpackFunction", 5)
local Sell1OreFunction        = ReplicatedStorage:WaitForChild("Sell1OreFunction", 5)

-- KEY / TOKEN mining (sesuai contoh argumen user)
local MINING_KEY = "safsafwaetqw3fsa"

-- MINING VALUES (ANTI NIL) -> dipakai untuk Mining 1..7 / Auto Mining
local MINING_VALUES = {
    [1] = 6.621987458333024,   -- Mining 1
    [2] = 5.556782250001561,   -- Mining 2
    [3] = 7.002904208333348,   -- Mining 3
    [4] = 5.65479554166086,    -- Mining 4
    [5] = 7.983959916673484,   -- Mining 5
    [6] = 8.025635291676736,   -- Mining 6
    [7] = 5.65479554166086,    -- Mining 7
}

-- TUNING Mining (ringan ke server)
local MINING_SINGLE_DELAY     = 0.05   -- jeda antar Mining manual jika nanti dipakai batch
local MINING_AUTO_LOOP_DELAY  = 0.05   -- jeda antar langkah Auto Mining 1–7

-- Sell All Ores loop
local ORE_SELL_ALL_LOOP_DELAY = 0.75   -- jeda antar SellAllOres dalam loop

-- TUNING: agar lebih ringan ke server (Fish)
local INPUT_DELAY          = 0.01   -- Get Fish Input (N kali)
local NONSTOP_DELAY        = 0.01   -- Get Fish Nonstop
local AUTO_SELL_COOLDOWN   = 0.75   -- minimal jeda antar SellAllFish (≤X Kg / All)

-- Sell This Fish agar lebih gesit (lebih kecil dari 3 detik, tapi tetap ada delay)
local SELL_THIS_FISH_DELAY = 0.4    -- jeda antar Sell1Fish saat Sell This Fish batch

-- Sell This Ores batch
local SELL_THIS_ORE_DELAY  = 0.4    -- jeda antar Sell1Ore saat Sell This Ores batch

------------------- STATE UTAMA - FISH -------------------
local alive                  = true
local getFishInputEnabled    = false
local getFishNonstopEnabled  = false
local currentInputTaskId     = 0

local logEntries             = {}

-- PROGRESS STATE (Get Fish Input / Nonstop)
local inputTargetCount       = 0
local inputCurrentCount      = 0

-- SELL MODE ENUM (Fish, siap expand)
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

-- BACKPACK / DROPDOWN STATE (Fish)
local scannedBackpack      = false
local fishCategoryList     = {}   -- {"ikan koi goshiki", "ikan rambo merah", ...}
local fishCategoryMap      = {}   -- [name] = true
local selectedFishCategory = nil  -- string nama kategori terpilih

local isSellingThisFish    = false

-- SELL PROGRESS STATE (Fish)
local sellFishCountByCategory = {}  -- [categoryName] = jumlah ikan terjual

-- COOLDOWN SELL ≤ X KG
local lastSellUnderWeightTick = {}  -- [maxWeight] = tick()

-- LOG RAW TOGGLE
local logRawEnabled = false -- default: tidak log supaya ringan

-- LOOP TOKENS (NONSTOP & SELL THIS FISH) UNTUK GANTI GENERASI TANPA while
local nonstopLoopId      = 0
local sellThisFishLoopId = 0

------------------- STATE MINING & ORES -------------------
-- Mining
local autoMiningEnabled   = false
local autoMiningLoopId    = 0
local autoMiningFromIndex = 1
local autoMiningToIndex   = 7
local miningCountTarget   = 0   -- 0 = unlimited
local miningCountCurrent  = 0
local miningLastResultText = "-"

-- Ores dropdown/cache
local oreCategoryList       = {}
local oreCategoryMap        = {}
local oreDropdownButtons    = {} -- [key] = button
local selectedOreCategory   = nil
local currentOreDropdownKey = "__DISABLE_ORE__"

-- Sell All Ores loop
local sellAllOresLoopEnabled = false
local sellAllOresLoopId      = 0

-- Sell This Ores batch
local isSellingThisOres      = false
local sellThisOresLoopId     = 0
local oreSellCountByCategory = {} -- [categoryName] = jumlah ores terjual (opsional statistik)

------------------- UI REFERENCES -------------------
local headerFrame
local bodyFrame

-- Fish UI
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

-- KEY saat ini untuk highlight dropdown Fish ("__DISABLE__" atau nama fish)
local currentDropdownKey = "__DISABLE__"

-- Mining & Ores UI
local miningCard
local miningButtons = {}           -- [1..7] = button "Mining 1..7"
local autoMiningToggleBtn
local miningCountInputBox
local miningProgressLabel
local miningLastLabel

local oreSellUnder7Btn
local oreSellUnder12Btn
local oreSellUnder20Btn
local oreSellAllLoopToggleBtn
local oreDropdownButton
local oreDropdownListFrame
local oreSellThisButton

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
    title.TextColor3 = Color3.fromRGB(235, 235, 245) -- ubah ke (0,0,0) jika mau hitam
    title.Text = "Indo Beach - Fish Giver V1"

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
    desc.Text = "Get Fish Input / Nonstop + Auto Sell Mode + Farm Mining & Sell Ores"

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

local function createMiningCard(parent, order)
    local card = createCard(
        parent,
        "Farm Mining & Sell Ores",
        "Mining 1–7 + Sell Ores (Under Kg / This / All)",
        order
    )

    -- Section title: Mining
    local miningTitle = Instance.new("TextLabel")
    miningTitle.Name = "MiningSectionTitle"
    miningTitle.Parent = card
    miningTitle.BackgroundTransparency = 1
    miningTitle.Size = UDim2.new(1, 0, 0, 18)
    miningTitle.Font = Enum.Font.Gotham
    miningTitle.TextSize = 12
    miningTitle.TextXAlignment = Enum.TextXAlignment.Left
    miningTitle.TextColor3 = Color3.fromRGB(180, 200, 230)
    miningTitle.Text = "Mining Controls"

    -- Buttons Mining 1..7 (grid)
    local miningButtonsFrame = Instance.new("Frame")
    miningButtonsFrame.Name = "MiningButtonsFrame"
    miningButtonsFrame.Parent = card
    miningButtonsFrame.BackgroundTransparency = 1
    miningButtonsFrame.Size = UDim2.new(1, 0, 0, 60)

    local grid = Instance.new("UIGridLayout")
    grid.Parent = miningButtonsFrame
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.CellSize = UDim2.new(1/4, -6, 0, 24) -- 4 kolom, auto wrap baris

    local function createMiningButton(idx)
        local btn = Instance.new("TextButton")
        btn.Name = "Mining" .. idx
        btn.Parent = miningButtonsFrame
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
        btn.TextWrapped = true
        btn.Text = "Mining " .. idx
        btn.Size = UDim2.new(1, 0, 0, 24)

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        miningButtons[idx] = btn
    end

    for i = 1, 7 do
        createMiningButton(i)
    end

    -- Toggle Auto Mining
    local _, autoToggle = createToggleButton(card, "Auto Mining 1–7 (Loop)")
    autoMiningToggleBtn = autoToggle

    -- Input jumlah Mining
    local mInput = Instance.new("TextBox")
    mInput.Name = "MiningCountInput"
    mInput.Parent = card
    mInput.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mInput.Size = UDim2.new(1, 0, 0, 26)
    mInput.ClearTextOnFocus = false
    mInput.Font = Enum.Font.Gotham
    mInput.TextSize = 13
    mInput.TextColor3 = Color3.fromRGB(225, 225, 235)
    mInput.TextXAlignment = Enum.TextXAlignment.Left
    mInput.Text = "0"
    mInput.PlaceholderText = "Jumlah Mining (0 = unlimited)"
    mInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)

    local mInputCorner = Instance.new("UICorner")
    mInputCorner.CornerRadius = UDim.new(0, 6)
    mInputCorner.Parent = mInput

    local mInputStroke = Instance.new("UIStroke")
    mInputStroke.Parent = mInput
    mInputStroke.Thickness = 1
    mInputStroke.Transparency = 0.3
    mInputStroke.Color = Color3.fromRGB(60, 60, 85)

    miningCountInputBox = mInput

    -- Label Progress Mining
    local mProg = Instance.new("TextLabel")
    mProg.Name = "MiningProgressLabel"
    mProg.Parent = card
    mProg.BackgroundTransparency = 1
    mProg.Size = UDim2.new(1, 0, 0, 18)
    mProg.Font = Enum.Font.Gotham
    mProg.TextSize = 11
    mProg.TextXAlignment = Enum.TextXAlignment.Left
    mProg.TextColor3 = Color3.fromRGB(170, 200, 255)
    mProg.Text = "Mining Progress: -"
    miningProgressLabel = mProg

    -- Label Last Mining
    local lastMiningLabel = Instance.new("TextLabel")
    lastMiningLabel.Name = "MiningLastLabel"
    lastMiningLabel.Parent = card
    lastMiningLabel.BackgroundTransparency = 1
    lastMiningLabel.Size = UDim2.new(1, 0, 0, 18)
    lastMiningLabel.Font = Enum.Font.Gotham
    lastMiningLabel.TextSize = 11
    lastMiningLabel.TextXAlignment = Enum.TextXAlignment.Left
    lastMiningLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
    lastMiningLabel.Text = "Last Mining: -"
    miningLastLabel = lastMiningLabel

    -- Section title: Sell Ores
    local sellTitle = Instance.new("TextLabel")
    sellTitle.Name = "OresSellSectionTitle"
    sellTitle.Parent = card
    sellTitle.BackgroundTransparency = 1
    sellTitle.Size = UDim2.new(1, 0, 0, 18)
    sellTitle.Font = Enum.Font.Gotham
    sellTitle.TextSize = 12
    sellTitle.TextXAlignment = Enum.TextXAlignment.Left
    sellTitle.TextColor3 = Color3.fromRGB(180, 200, 230)
    sellTitle.Text = "Sell Ores Controls"

    -- Buttons Sell Under Kg
    local oresButtonsFrame = Instance.new("Frame")
    oresButtonsFrame.Name = "OreSellButtonsFrame"
    oresButtonsFrame.Parent = card
    oresButtonsFrame.BackgroundTransparency = 1
    oresButtonsFrame.Size = UDim2.new(1, 0, 0, 30)

    local grid2 = Instance.new("UIGridLayout")
    grid2.Parent = oresButtonsFrame
    grid2.FillDirection = Enum.FillDirection.Horizontal
    grid2.SortOrder = Enum.SortOrder.LayoutOrder
    grid2.CellPadding = UDim2.new(0, 6, 0, 6)
    grid2.CellSize = UDim2.new(1/3, -4, 0, 24)

    local function makeOreSellBtn(name, text)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Parent = oresButtonsFrame
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
        btn.TextWrapped = true
        btn.Text = text
        local c2 = Instance.new("UICorner")
        c2.CornerRadius = UDim.new(0, 6)
        c2.Parent = btn
        return btn
    end

    oreSellUnder7Btn  = makeOreSellBtn("SellUnder7",  "Sell ≤ 7Kg Ores")
    oreSellUnder12Btn = makeOreSellBtn("SellUnder12", "Sell ≤ 12Kg Ores")
    oreSellUnder20Btn = makeOreSellBtn("SellUnder20", "Sell ≤ 20Kg Ores")

    -- Dropdown Selected Ores (Sell This Ores)
    local selLbl = Instance.new("TextLabel")
    selLbl.Name = "SelectedOresLabel"
    selLbl.Parent = card
    selLbl.BackgroundTransparency = 1
    selLbl.Size = UDim2.new(1, 0, 0, 18)
    selLbl.Font = Enum.Font.Gotham
    selLbl.TextSize = 11
    selLbl.TextXAlignment = Enum.TextXAlignment.Left
    selLbl.TextColor3 = Color3.fromRGB(180, 200, 230)
    selLbl.Text = "Selected Ores (Sell This Ores):"

    local ddBtn = Instance.new("TextButton")
    ddBtn.Name = "OresDropdownButton"
    ddBtn.Parent = card
    ddBtn.Size = UDim2.new(1, 0, 0, 26)
    ddBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    ddBtn.AutoButtonColor = true
    ddBtn.Font = Enum.Font.Gotham
    ddBtn.TextSize = 13
    ddBtn.TextXAlignment = Enum.TextXAlignment.Left
    ddBtn.TextColor3 = Color3.fromRGB(225, 225, 235)
    ddBtn.Text = "Disable"

    local ddCorner = Instance.new("UICorner")
    ddCorner.CornerRadius = UDim.new(0, 6)
    ddCorner.Parent = ddBtn

    local ddStroke = Instance.new("UIStroke")
    ddStroke.Parent = ddBtn
    ddStroke.Thickness = 1
    ddStroke.Transparency = 0.3
    ddStroke.Color = Color3.fromRGB(60, 60, 85)

    oreDropdownButton = ddBtn

    local ddList = Instance.new("ScrollingFrame")
    ddList.Name = "OresDropdownList"
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

    oreDropdownListFrame = ddList

    -- Button Sell This Ores
    local sellThisBtn = Instance.new("TextButton")
    sellThisBtn.Name = "SellThisOresButton"
    sellThisBtn.Parent = card
    sellThisBtn.Size = UDim2.new(1, 0, 0, 26)
    sellThisBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    sellThisBtn.AutoButtonColor = true
    sellThisBtn.Font = Enum.Font.GothamBold
    sellThisBtn.TextSize = 12
    sellThisBtn.TextColor3 = Color3.fromRGB(235, 235, 245)
    sellThisBtn.Text = "Sell This Ores (Equip & Sell)"
    local sellThisCorner = Instance.new("UICorner")
    sellThisCorner.CornerRadius = UDim.new(0, 6)
    sellThisCorner.Parent = sellThisBtn

    oreSellThisButton = sellThisBtn

    -- Toggle Sell All Ores Loop
    local _, sellAllToggle = createToggleButton(card, "Sell All Ores Loop (math.huge)")
    oreSellAllLoopToggleBtn = sellAllToggle

    return card
end

------------------- BUILD UI -------------------
headerFrame = createHeader(frame)
bodyFrame   = createBody(frame)

fishCard, getFishInputToggleBtn, getFishNonstopToggleBtn, fishCountInputBox, lastFishLabel, inputProgressLabel =
    createFishGiverCard(bodyFrame, 1)

sellCard, sellDropdownButton, sellDropdownListFrame, sellProgressLabel =
    createSellFishCard(bodyFrame, 2)

logCard, logScrollFrame, logToggleBtn = createFishLogCard(bodyFrame, 3)

miningCard = createMiningCard(bodyFrame, 4)

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
updateToggleVisual(logToggleBtn, false)
updateToggleVisual(autoMiningToggleBtn, false)
updateToggleVisual(oreSellAllLoopToggleBtn, false)

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

------------------- HELPER: PROGRESS LABEL (MINING) -------------------
local function updateMiningProgressLabel()
    if not miningProgressLabel then return end

    if miningCountTarget > 0 then
        local shown = math.min(miningCountCurrent, miningCountTarget)
        miningProgressLabel.Text = string.format(
            "Mining Progress: %d/%d (Spot %d–%d)",
            shown, miningCountTarget, autoMiningFromIndex, autoMiningToIndex
        )
    elseif autoMiningEnabled then
        miningProgressLabel.Text = string.format(
            "Mining Progress: %d (Spot %d–%d, Unlimited)",
            miningCountCurrent, autoMiningFromIndex, autoMiningToIndex
        )
    else
        miningProgressLabel.Text = "Mining Progress: -"
    end
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

------------------- HELPER: CEK TOOL YANG DIKELUARKAN DARI DROPDOWN (ROD / TORCH / PICKAXE) -------------------
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

------------------- HELPER: CEK TOOL ORES (Diamond / Gold / Iron / dll) -------------------
local function isOreToolName(toolName)
    if type(toolName) ~= "string" then return false end
    local lower = toolName:lower()

    -- jenis ore umum
    if lower:find("diamond") or lower:find("gold") or lower:find("iron") or lower:find("ore")
        or lower:find("copper") or lower:find("stone") or lower:find("coal") or lower:find("crystal") then
        return true
    end

    -- jelas bukan ore (ikan)
    if lower:find("ikan") or lower:find("fish") then
        return false
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
            fishName = tostring(res)
        end
    else
        fishName = tostring(res)
    end

    return fishName
end

------------------- BACKPACK SCAN (FISH - SEKALI DIAWAL, KECUALI ROD/TORCH/PICAXE) -------------------
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

------------------- HELPER: SELL IMPLEMENTATION (FISH) -------------------
local function sellUnderWeight(maxWeight)
    if not SellAllFishFunction then
        appendLog("[Sell] SellAllFishFunction tidak ditemukan.")
        return
    end

    -- Cooldown per maxWeight agar tidak spam remote
    local now = tick()
    local last = lastSellUnderWeightTick[maxWeight]
    if last and (now - last) < AUTO_SELL_COOLDOWN then
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
                return Sell1FishFunction:InvokeServer(math.huge)
            end)

            if not ok then
                appendLog("[Sell] Error Sell1Fish(math.huge): " .. tostring(res))
                finishSellThisFishLoop("Error Sell1Fish")
                return
            else
                appendLog(string.format("[Sell] Sell1Fish OK (%s) ke-%d", categoryName, i))

                sellFishCountByCategory[categoryName] =
                    (sellFishCountByCategory[categoryName] or 0) + 1
                updateSellProgressLabel()
            end

            if i < total then
                task.wait(SELL_THIS_FISH_DELAY)
            end
        end

        if alive and currentSellMode == SellMode.ThisFish and thisLoopId == sellThisFishLoopId then
            finishSellThisFishLoop("Selesai jual semua ikan kategori " .. tostring(categoryName))
        else
            finishSellThisFishLoop("Dihentikan sebelum selesai")
        end
    end)
end

------------------- SELL MODE HANDLER (FISH) -------------------
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

    if mode ~= SellMode.ThisFish then
        sellThisFishLoopId += 1
        finishSellThisFishLoop("Mode berubah dari ThisFish")
    end

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
        sellThisFishAll()
    elseif currentSellMode == SellMode.AllFish then
        sellAllFish()
    end
end

------------------- DROPDOWN BUILD (FISH) -------------------
local function buildFishDropdownItems()
    if not sellDropdownListFrame then return end

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

            for key, b in pairs(dropdownItemButtons) do
                if key == currentDropdownKey then
                    b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                    b.TextColor3       = Color3.fromRGB(245, 245, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    b.TextColor3       = Color3.fromRGB(220, 220, 230)
                end
            end

            updateSellProgressLabel()

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

            for key, b in pairs(dropdownItemButtons) do
                if key == currentDropdownKey then
                    b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                    b.TextColor3       = Color3.fromRGB(245, 245, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    b.TextColor3       = Color3.fromRGB(220, 220, 230)
                end
            end

            updateSellProgressLabel()

            if sellDropdownListFrame then
                sellDropdownListFrame.Visible = false
                sellDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
            end

            appendLog("[Dropdown] Selected Fish diubah ke: " .. selectedFishCategory)

            if currentSellMode == SellMode.ThisFish then
                sellThisFishAll()
            end
        end)
    end

    if not selectedFishCategory then
        currentDropdownKey = "__DISABLE__"
        if sellDropdownButton then
            sellDropdownButton.Text = "Disable"
        end
    end

    for key, b in pairs(dropdownItemButtons) do
        if key == currentDropdownKey then
            b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            b.TextColor3       = Color3.fromRGB(245, 245, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            b.TextColor3       = Color3.fromRGB(220, 220, 230)
        end
    end

    updateSellProgressLabel()
end

local function initFishDropdown()
    if not sellDropdownButton or not sellDropdownListFrame then return end
    scanBackpackOnce()

    if #fishCategoryList == 0 then
        if sellDropdownButton then
            sellDropdownButton.Text = "Disable (Backpack kosong / fish tidak ditemukan)"
        end
        buildFishDropdownItems()
        return
    end

    buildFishDropdownItems()
end

------------------- HELPER ORES: HITUNG & CARI TOOL PER KATEGORI -------------------
local function countOresByCategory()
    local counts = {}

    local function scanContainer(container)
        if not container then return end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") and not isIgnoredToolForDropdown(inst.Name) and isOreToolName(inst.Name) then
                local cname = cleanFishName(inst.Name)
                if cname ~= "" then
                    counts[cname] = (counts[cname] or 0) + 1
                end
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    local char     = LocalPlayer.Character

    scanContainer(char)
    scanContainer(backpack)

    return counts
end

local function findOreToolByCategory(categoryName)
    if not categoryName or categoryName == "" then return nil end

    local function search(container)
        if not container then return nil end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") and not isIgnoredToolForDropdown(inst.Name) and isOreToolName(inst.Name) then
                local cname = cleanFishName(inst.Name)
                if cname == categoryName then
                    return inst
                end
            end
        end
        return nil
    end

    local char     = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")

    return search(char) or search(backpack)
end

local function countOresInCategory(categoryName)
    local counts = countOresByCategory()
    return counts[categoryName] or 0
end

------------------- HELPER: BUILD ORES DROPDOWN -------------------
local function buildOreDropdownItems()
    if not oreDropdownListFrame then return end

    for _, child in ipairs(oreDropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    oreDropdownButtons = {}

    -- Disable
    local disableBtn = Instance.new("TextButton")
    disableBtn.Name = "OreItem_Disable"
    disableBtn.Parent = oreDropdownListFrame
    disableBtn.Size = UDim2.new(1, 0, 0, 22)
    disableBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    disableBtn.AutoButtonColor = true
    disableBtn.Font = Enum.Font.Gotham
    disableBtn.TextSize = 12
    disableBtn.TextXAlignment = Enum.TextXAlignment.Left
    disableBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
    disableBtn.Text = "Disable"

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = disableBtn

    oreDropdownButtons["__DISABLE_ORE__"] = disableBtn

    disableBtn.MouseButton1Click:Connect(function()
        selectedOreCategory   = nil
        currentOreDropdownKey = "__DISABLE_ORE__"
        if oreDropdownButton then
            oreDropdownButton.Text = "Disable"
        end

        for key, b in pairs(oreDropdownButtons) do
            if key == currentOreDropdownKey then
                b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                b.TextColor3       = Color3.fromRGB(245, 245, 255)
            else
                b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                b.TextColor3       = Color3.fromRGB(220, 220, 230)
            end
        end

        appendLog("[Ores] Selected Ores diubah ke: Disable")
    end)

    local counts = countOresByCategory()
    oreCategoryList = {}
    for cname, _ in pairs(counts) do
        table.insert(oreCategoryList, cname)
    end
    table.sort(oreCategoryList, function(a, b)
        return a:lower() < b:lower()
    end)

    for _, cname in ipairs(oreCategoryList) do
        local btn = Instance.new("TextButton")
        btn.Name = "OreItem_" .. cname
        btn.Parent = oreDropdownListFrame
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left

        local initialCount = counts[cname] or 0
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Text = string.format("%dx %s", initialCount, cname)

        local c2 = Instance.new("UICorner")
        c2.CornerRadius = UDim.new(0, 4)
        c2.Parent = btn

        oreDropdownButtons[cname] = btn

        btn.MouseButton1Click:Connect(function()
            selectedOreCategory   = cname
            currentOreDropdownKey = cname

            local currentCount = countOresInCategory(cname)
            if oreDropdownButton then
                oreDropdownButton.Text = string.format("%dx %s", currentCount, cname)
            end

            for key, b in pairs(oreDropdownButtons) do
                if key == currentOreDropdownKey then
                    b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                    b.TextColor3       = Color3.fromRGB(245, 245, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    b.TextColor3       = Color3.fromRGB(220, 220, 230)
                end
            end

            appendLog("[Ores] Selected Ores diubah ke: " .. tostring(selectedOreCategory))
        end)
    end

    if not selectedOreCategory then
        currentOreDropdownKey = "__DISABLE_ORE__"
        if oreDropdownButton then
            oreDropdownButton.Text = "Disable"
        end
    end

    for key, b in pairs(oreDropdownButtons) do
        if key == currentOreDropdownKey then
            b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            b.TextColor3       = Color3.fromRGB(245, 245, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            b.TextColor3       = Color3.fromRGB(220, 220, 230)
        end
    end
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

    applyAutoSellAfterCatch()

    return fishName, res
end

------------------- HELPER: GET MINING VALUE -------------------
local function getMiningValue(index)
    local value = MINING_VALUES[index]
    if type(value) ~= "number" then
        appendLog(string.format("[Mining] Mining value #%d masih kosong / nil.", index))
        notify("Indo Beach - Mining", "Mining #" .. tostring(index) .. " belum punya value (nil). Cek MINING_VALUES.", 4)
        return nil
    end
    return value
end

------------------- HELPER: MINING SEKALI -------------------
local function doSingleMining(index)
    if not (alive and GiveCrystalFunction) then
        appendLog("[Mining] GiveCrystalFunction tidak tersedia.")
        return
    end

    local value = getMiningValue(index)
    if not value then
        return
    end

    local ok, res = pcall(function()
        local args = {
            [1] = MINING_KEY,
            [2] = value
        }
        return GiveCrystalFunction:InvokeServer(unpack(args))
    end)

    if not ok then
        appendLog(string.format("[Mining] Error Mining #%d (value %.12f): %s", index, value, tostring(res)))
        return
    end

    -- Deskripsi hasil Mining (jika server mengembalikan data)
    local resultText = "-"
    if res == nil then
        resultText = "Success (no data)"
    elseif typeof(res) == "table" then
        local oreName = tostring(res.OreName or res.Name or res.name or "Unknown Ore")
        local amount  = tonumber(res.Amount or res.Count or res.amount or res.count or 1) or 1
        local weight  = tonumber(res.Weight or res.weight or res.Kg or res.kg)

        if weight then
            resultText = string.format("%d %s %.2fkg", amount, oreName, weight)
        else
            resultText = string.format("%d %s", amount, oreName)
        end
    else
        resultText = tostring(res)
    end

    miningLastResultText = string.format("Mining #%d → %s", index, resultText)

    if miningLastLabel then
        miningLastLabel.Text = "Last Mining: " .. miningLastResultText
    end

    appendLog("[Mining] " .. miningLastResultText)
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

            task.wait(INPUT_DELAY)
        end

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

------------------- LOGIC: AUTO MINING LOOP (1–7) -------------------
local function scheduleAutoMiningStep(loopId, spotIndex)
    task.spawn(function()
        if not alive then return end
        if not autoMiningEnabled then return end
        if loopId ~= autoMiningLoopId then return end

        if spotIndex < autoMiningFromIndex or spotIndex > autoMiningToIndex then
            spotIndex = autoMiningFromIndex
        end

        doSingleMining(spotIndex)

        miningCountCurrent += 1
        updateMiningProgressLabel()

        if miningCountTarget > 0 and miningCountCurrent >= miningCountTarget then
            autoMiningEnabled = false
            updateToggleVisual(autoMiningToggleBtn, false)
            notify("Indo Beach - Mining", "Auto Mining selesai / berhenti.", 4)
            return
        end

        task.wait(MINING_AUTO_LOOP_DELAY)

        if not alive then return end
        if not autoMiningEnabled then return end
        if loopId ~= autoMiningLoopId then return end

        local nextIndex = spotIndex + 1
        if nextIndex > autoMiningToIndex then
            nextIndex = autoMiningFromIndex
        end

        scheduleAutoMiningStep(loopId, nextIndex)
    end)
end

local function startAutoMining()
    if not alive then return end

    miningCountCurrent = 0
    updateMiningProgressLabel()

    autoMiningLoopId += 1
    local thisLoopId = autoMiningLoopId

    notify("Indo Beach - Mining", string.format(
        "Auto Mining dimulai (Spot %d–%d%s).",
        autoMiningFromIndex,
        autoMiningToIndex,
        miningCountTarget > 0 and (" x" .. tostring(miningCountTarget)) or " Unlimited"
    ), 4)

    scheduleAutoMiningStep(thisLoopId, autoMiningFromIndex)
end

------------------- HELPER: SELL ORES -------------------
local function sellOresUnderWeight(rawMaxParam)
    if not SellOreBackpackFunction then
        appendLog("[Ores] SellOreBackpackFunction tidak ditemukan.")
        return
    end

    local ok, res = pcall(function()
        local args = { [1] = rawMaxParam }
        return SellOreBackpackFunction:InvokeServer(unpack(args))
    end)

    if not ok then
        appendLog(string.format("[Ores] Error SellOreBackpack(%s): %s", tostring(rawMaxParam), tostring(res)))
    else
        appendLog(string.format("[Ores] SellOreBackpack(%s) OK.", tostring(rawMaxParam)))
    end
end

local function sellAllOresOnce()
    sellOresUnderWeight(math.huge)
end

local function scheduleSellAllOresLoop(loopId)
    task.spawn(function()
        if not alive then return end
        if not sellAllOresLoopEnabled then return end
        if loopId ~= sellAllOresLoopId then return end

        sellAllOresOnce()

        task.wait(ORE_SELL_ALL_LOOP_DELAY)

        if not alive then return end
        if not sellAllOresLoopEnabled then return end
        if loopId ~= sellAllOresLoopId then return end

        scheduleSellAllOresLoop(loopId)
    end)
end

local function startSellAllOresLoop()
    if not alive then return end

    sellAllOresLoopId += 1
    local thisLoopId = sellAllOresLoopId

    notify("Indo Beach - Ores", "Sell All Ores Loop dimulai.", 4)
    scheduleSellAllOresLoop(thisLoopId)
end

------------------- SELL THIS ORES (BATCH EQUIP + SELL1) -------------------
local function finishSellThisOresLoop(reason)
    if isSellingThisOres then
        isSellingThisOres = false
        appendLog("[Ores] SellThisOres selesai: " .. tostring(reason or "Selesai"))
    end
end

local function sellThisOresAll()
    if not Sell1OreFunction then
        appendLog("[Ores] Sell1OreFunction tidak ditemukan.")
        return
    end

    if not selectedOreCategory or selectedOreCategory == "" then
        appendLog("[Ores] Selected Ores belum dipilih (dropdown).")
        return
    end

    if isSellingThisOres then
        appendLog("[Ores] SellThisOres loop sudah berjalan.")
        return
    end

    local total = countOresInCategory(selectedOreCategory)
    if total <= 0 then
        appendLog("[Ores] Tidak ada Ores kategori '" .. selectedOreCategory .. "' di Backpack/Character.")
        return
    end

    isSellingThisOres = true
    sellThisOresLoopId += 1
    local thisLoopId = sellThisOresLoopId
    local categoryName = selectedOreCategory

    appendLog(string.format("[Ores] Mulai SellThisOres batch: %s (total ± %d)", categoryName, total))

    task.spawn(function()
        for i = 1, total do
            if not alive then
                finishSellThisOresLoop("Tab tidak aktif")
                return
            end
            if thisLoopId ~= sellThisOresLoopId then
                finishSellThisOresLoop("Diganti batch lain")
                return
            end

            local char = LocalPlayer.Character
            if not char then
                finishSellThisOresLoop("Character belum siap")
                return
            end

            local tool = findOreToolByCategory(categoryName)
            if not tool then
                finishSellThisOresLoop("Ores kategori '" .. categoryName .. "' sudah habis sebelum selesai batch.")
                return
            end

            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
            else
                tool.Parent = char
            end

            local ok, res = pcall(function()
                local args = {
                    [1] = math.huge,
                    [2] = true
                }
                return Sell1OreFunction:InvokeServer(unpack(args))
            end)

            if not ok then
                appendLog("[Ores] Error Sell1Ore(math.huge,true): " .. tostring(res))
                finishSellThisOresLoop("Error Sell1Ore")
                return
            else
                appendLog(string.format("[Ores] Sell1Ore OK (%s) ke-%d", categoryName, i))
                oreSellCountByCategory[categoryName] =
                    (oreSellCountByCategory[categoryName] or 0) + 1
            end

            if i < total then
                task.wait(SELL_THIS_ORE_DELAY)
            end
        end

        if alive and thisLoopId == sellThisOresLoopId then
            finishSellThisOresLoop("Selesai jual semua ores kategori " .. tostring(categoryName))
        else
            finishSellThisOresLoop("Dihentikan sebelum selesai")
        end
    end)
end

------------------- UI EVENTS -------------------
-- Inisialisasi dropdown Fish (scan Backpack sekali diawal)
initFishDropdown()

-- Toggle list dropdown Fish (buka/tutup)
if sellDropdownButton then
    sellDropdownButton.MouseButton1Click:Connect(function()
        if not sellDropdownListFrame then return end

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

-- Input jumlah Fish
if fishCountInputBox then
    fishCountInputBox.FocusLost:Connect(function()
        local n = tonumber(fishCountInputBox.Text)
        if not n or n <= 0 then
            fishCountInputBox.Text = "10"
        end
    end)
end

-- Toggle Get Fish Input
if getFishInputToggleBtn then
    getFishInputToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        getFishInputEnabled = not getFishInputEnabled
        updateToggleVisual(getFishInputToggleBtn, getFishInputEnabled)

        if getFishInputEnabled then
            startGetFishInput()
        else
            notify("Indo Beach", "Get Fish Input dimatikan oleh user.", 3)
        end
    end)
end

-- Toggle Get Fish Nonstop
if getFishNonstopToggleBtn then
    getFishNonstopToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        getFishNonstopEnabled = not getFishNonstopEnabled
        updateToggleVisual(getFishNonstopToggleBtn, getFishNonstopEnabled)

        if getFishNonstopEnabled then
            startGetFishNonstop()
        else
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

-- Event untuk semua tombol Sell Mode (Fish)
for mode, btn in pairs(sellModeButtons) do
    btn.MouseButton1Click:Connect(function()
        if not alive then return end
        setSellMode(mode)
        applyAutoSellAfterCatch()
    end)
end

-- Set default sell mode = Disable
setSellMode(SellMode.Disable)

-- Mining: inisialisasi label
updateMiningProgressLabel()
if miningLastLabel then
    miningLastLabel.Text = "Last Mining: -"
end

-- Tombol Mining 1..7 (sekali klik)
for idx, btn in ipairs(miningButtons) do
    btn.MouseButton1Click:Connect(function()
        if not alive then return end
        doSingleMining(idx)
    end)
end

-- Input jumlah Mining (0 = unlimited)
if miningCountInputBox then
    miningCountInputBox.FocusLost:Connect(function()
        local n = tonumber(miningCountInputBox.Text)
        if not n or n < 0 then
            miningCountInputBox.Text = "0"
            n = 0
        end
        miningCountTarget = n or 0
        updateMiningProgressLabel()
    end)
end

-- Toggle Auto Mining
if autoMiningToggleBtn then
    autoMiningToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        autoMiningEnabled = not autoMiningEnabled
        updateToggleVisual(autoMiningToggleBtn, autoMiningEnabled)

        if autoMiningEnabled then
            startAutoMining()
        else
            notify("Indo Beach - Mining", "Auto Mining dimatikan oleh user.", 3)
        end
    end)
end

-- Buttons Sell Ores Under Kg
if oreSellUnder7Btn then
    oreSellUnder7Btn.MouseButton1Click:Connect(function()
        if not alive then return end
        sellOresUnderWeight(6)   -- sesuai contoh: maxparam = 6 → ≤7kg
    end)
end

if oreSellUnder12Btn then
    oreSellUnder12Btn.MouseButton1Click:Connect(function()
        if not alive then return end
        sellOresUnderWeight(11)  -- sesuai contoh: 11 → ≤12kg
    end)
end

if oreSellUnder20Btn then
    oreSellUnder20Btn.MouseButton1Click:Connect(function()
        if not alive then return end
        sellOresUnderWeight(19)  -- sesuai contoh: 19 → ≤20kg
    end)
end

-- Dropdown Ores (buka/tutup + rebuild setiap buka supaya jumlah update)
if oreDropdownButton then
    oreDropdownButton.MouseButton1Click:Connect(function()
        if not alive then return end
        if not oreDropdownListFrame then return end

        buildOreDropdownItems()

        local open = not oreDropdownListFrame.Visible
        oreDropdownListFrame.Visible = open
        if open then
            oreDropdownListFrame.Size = UDim2.new(1, 0, 0, 120)
        else
            oreDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end)
end

-- Button Sell This Ores (batch sekali)
if oreSellThisButton then
    oreSellThisButton.MouseButton1Click:Connect(function()
        if not alive then return end
        sellThisOresAll()
    end)
end

-- Toggle Sell All Ores Loop
if oreSellAllLoopToggleBtn then
    oreSellAllLoopToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        sellAllOresLoopEnabled = not sellAllOresLoopEnabled
        updateToggleVisual(oreSellAllLoopToggleBtn, sellAllOresLoopEnabled)

        if sellAllOresLoopEnabled then
            startSellAllOresLoop()
        else
            notify("Indo Beach - Ores", "Sell All Ores Loop dimatikan oleh user.", 3)
        end
    end)
end

------------------- TAB CLEANUP (INTEGRASI CORE) -------------------
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    -- Fish
    getFishInputEnabled   = false
    getFishNonstopEnabled = false
    isSellingThisFish     = false
    sellThisFishLoopId    = sellThisFishLoopId + 1
    nonstopLoopId         = nonstopLoopId + 1

    -- Mining
    autoMiningEnabled     = false
    autoMiningLoopId      = autoMiningLoopId + 1

    -- Ores
    sellAllOresLoopEnabled = false
    sellAllOresLoopId      = sellAllOresLoopId + 1
    isSellingThisOres      = false
    sellThisOresLoopId     = sellThisOresLoopId + 1
end
