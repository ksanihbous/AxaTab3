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
-- Argumen untuk GiveFishFunction / GiveCrystal
local FISH_CODE = "safsafwaetqw3fsa"

-- Remote Indo Beach (Fish)
local GiveFishFunction        = ReplicatedStorage:WaitForChild("GiveFishFunction", 5)
local SellAllFishFunction     = ReplicatedStorage:WaitForChild("SellAllFishFunction", 5)
local Sell1FishFunction       = ReplicatedStorage:WaitForChild("Sell1FishFunction", 5)

-- Remote Mining Indo Beach (Ores)
local GiveCrystalFunction     = ReplicatedStorage:WaitForChild("GiveCrystal", 5)
local Sell1OreFunction        = ReplicatedStorage:WaitForChild("Sell1OreFunction", 5)
local SellOreBackpackFunction = ReplicatedStorage:WaitForChild("SellOreBackpackFunction", 5)

-- Nilai Mining 1-7 (dari contoh user)
local MINING_VALUES = {
    [1] = 6.621987458333024, -- MINING 1
    [2] = 5.556782250001561, -- MINING 2
    [3] = 7.002904208333348, -- MINING 3
    [4] = 5.65479554166086,  -- MINING 4
    [5] = 7.983959916673484, -- MINING 5
    [6] = 8.025635291676736, -- MINING 6
    [7] = 5.65479554166086,  -- MINING 7
}

-- TUNING: agar lebih ringan ke server
local INPUT_DELAY          = 0.01   -- Get Fish Input (N kali)
local NONSTOP_DELAY        = 0.01   -- Get Fish Nonstop
local AUTO_SELL_COOLDOWN   = 0.75   -- minimal jeda antar SellAllFish (≤X Kg / All)

-- Sell This Fish agar lebih gesit (tetap ada delay)
local SELL_THIS_FISH_DELAY = 0.4    -- jeda antar Sell1Fish

-- Mining: jeda antar panggilan GiveCrystal
local MINING_DELAY         = 0.1

-- Auto Sell All Ores loop delay
local ORE_SELL_ALL_DELAY   = 1.0

------------------- STATE UTAMA -------------------
local alive                  = true
local logEntries             = {}

-- FISH: GET FISH
local getFishInputEnabled    = false
local getFishNonstopEnabled  = false
local currentInputTaskId     = 0
local inputTargetCount       = 0
local inputCurrentCount      = 0

-- FISH: SELL MODE ENUM
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

-- BACKPACK / DROPDOWN FISH
local scannedBackpack      = false
local fishCategoryList     = {}
local fishCategoryMap      = {}
local selectedFishCategory = nil
local isSellingThisFish    = false
local sellFishCountByCategory = {}
local lastSellUnderWeightTick = {}

-- LOG RAW TOGGLE
local logRawEnabled = false

-- LOOP TOKENS (tanpa while)
local nonstopLoopId      = 0
local sellThisFishLoopId = 0

-- FARM MINING STATE
local autoMiningEnabled   = false
local autoMiningLoopId    = 0
local miningTargetLoops   = 0   -- 0 = Nonstop
local miningCurrentLoop   = 0

-- ORES STATE (dropdown & sell)
local oreSelectedCategory     = nil
local oreSellCountByCategory  = {}
local isSellingThisOres       = false
local sellThisOresLoopId      = 0
local autoSellAllOresEnabled  = false
local autoSellAllOresLoopId   = 0

------------------- UI REFERENCES -------------------
local headerFrame
local bodyFrame

local fishCard
local sellCard
local miningCard
local logCard

-- FISH UI
local getFishInputToggleBtn
local getFishNonstopToggleBtn
local fishCountInputBox
local lastFishLabel
local inputProgressLabel

local sellModeButtons = {} -- [mode] = button
local sellDropdownButton
local sellDropdownListFrame
local dropdownItemButtons = {}
local currentDropdownKey = "__DISABLE__"
local sellProgressLabel

local logScrollFrame
local logToggleBtn

-- MINING & ORES UI
local miningButtons = {} -- [1..7] = button
local autoMiningToggleBtn
local miningCountInputBox
local miningProgressLabel
local lastOreLabel

local oreSellUnder7Button
local oreSellUnder12Button
local oreSellUnder20Button
local oreSellThisButton

local oreDropdownButton
local oreDropdownListFrame
local oreDropdownItemButtons = {}
local oreCurrentDropdownKey = "__DISABLE__"
local oreSellAllToggleBtn
local oreSellProgressLabel

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
    title.Text = "Indo Beach - Fish Giver V2"

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
    desc.Text = "Get Fish Input / Nonstop + Auto Sell Fish + Farm Mining & Sell Ores"

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
    ddButton.Text = "Disable"

    local ddCorner = Instance.new("UICorner")
    ddCorner.CornerRadius = UDim.new(0, 6)
    ddCorner.Parent = ddButton

    local ddStroke = Instance.new("UIStroke")
    ddStroke.Parent = ddButton
    ddStroke.Thickness = 1
    ddStroke.Transparency = 0.3
    ddStroke.Color = Color3.fromRGB(60, 60, 85)

    -- Dropdown list
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
        "Riwayat ikan, sell fish & ores (LOG RAW)",
        order
    )

    local _, toggleBtn = createToggleButton(card, "Log RAW (Fish & Sell & Mining/Ores)")

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

--==================== FARM MINING & SELL ORES CARD ====================
local function createMiningCard(parent, order)
    local card = createCard(
        parent,
        "Farm Mining & Sell Ores",
        "Mining 1–7 + Auto Mining 1→7 + Sell Ores (Under 7/12/20 kg, Sell This Ores, Sell All Ores Loop)",
        order
    )

    -- Grid tombol Mining 1-7
    local btnFrame = Instance.new("Frame")
    btnFrame.Name = "MiningButtonsFrame"
    btnFrame.Parent = card
    btnFrame.BackgroundTransparency = 1
    btnFrame.Size = UDim2.new(1, 0, 0, 0)
    btnFrame.AutomaticSize = Enum.AutomaticSize.Y

    local grid = Instance.new("UIGridLayout")
    grid.Parent = btnFrame
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.CellSize = UDim2.new(0.33, -4, 0, 26)

    local pad = Instance.new("UIPadding")
    pad.Parent = btnFrame
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)

    local function addMiningButton(idx)
        local btn = Instance.new("TextButton")
        btn.Name = "Mining" .. idx
        btn.Parent = btnFrame
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(235, 235, 245)
        btn.Text = "Mining " .. idx

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        local s = Instance.new("UIStroke")
        s.Parent = btn
        s.Thickness = 1
        s.Transparency = 0.4
        s.Color = Color3.fromRGB(60, 60, 85)

        miningButtons[idx] = btn
    end

    for i = 1, 7 do
        addMiningButton(i)
    end

    -- Last Ore result
    local lastOre = Instance.new("TextLabel")
    lastOre.Name = "LastOreLabel"
    lastOre.Parent = card
    lastOre.BackgroundTransparency = 1
    lastOre.Size = UDim2.new(1, 0, 0, 18)
    lastOre.Font = Enum.Font.Gotham
    lastOre.TextSize = 12
    lastOre.TextXAlignment = Enum.TextXAlignment.Left
    lastOre.TextColor3 = Color3.fromRGB(180, 220, 255)
    lastOre.Text = "Last Ore: -"

    -- Auto Mining toggle
    local _, toggleMining = createToggleButton(card, "Auto Mining 1-7 (Loop urut 1→7)")

    -- Input jumlah loop
    local input = Instance.new("TextBox")
    input.Name = "MiningLoopInput"
    input.Parent = card
    input.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    input.Size = UDim2.new(1, 0, 0, 26)
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = Color3.fromRGB(225, 225, 235)
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Text = "0"
    input.PlaceholderText = "Jumlah loop 1→7 (0 = Nonstop, 1 = satu putaran, dst)"
    input.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = input

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Parent = input
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.3
    inputStroke.Color = Color3.fromRGB(60, 60, 85)

    -- Mining progress label
    local miningProg = Instance.new("TextLabel")
    miningProg.Name = "MiningProgressLabel"
    miningProg.Parent = card
    miningProg.BackgroundTransparency = 1
    miningProg.Size = UDim2.new(1, 0, 0, 18)
    miningProg.Font = Enum.Font.Gotham
    miningProg.TextSize = 11
    miningProg.TextXAlignment = Enum.TextXAlignment.Left
    miningProg.TextColor3 = Color3.fromRGB(170, 200, 255)
    miningProg.Text = "Mining Progress: -"

    -- Separator: Sell Ores
    local sep = Instance.new("TextLabel")
    sep.Name = "SellOreTitle"
    sep.Parent = card
    sep.BackgroundTransparency = 1
    sep.Size = UDim2.new(1, 0, 0, 18)
    sep.Font = Enum.Font.GothamBold
    sep.TextSize = 13
    sep.TextXAlignment = Enum.TextXAlignment.Left
    sep.TextColor3 = Color3.fromRGB(220, 220, 235)
    sep.Text = "Sell Ores Control"

    -- Grid tombol Sell Ores (Under 7/12/20 + Sell This Ores)
    local sellOreFrame = Instance.new("Frame")
    sellOreFrame.Name = "SellOreButtonsFrame"
    sellOreFrame.Parent = card
    sellOreFrame.BackgroundTransparency = 1
    sellOreFrame.Size = UDim2.new(1, 0, 0, 0)
    sellOreFrame.AutomaticSize = Enum.AutomaticSize.Y

    local sellGrid = Instance.new("UIGridLayout")
    sellGrid.Parent = sellOreFrame
    sellGrid.FillDirection = Enum.FillDirection.Horizontal
    sellGrid.SortOrder = Enum.SortOrder.LayoutOrder
    sellGrid.CellPadding = UDim2.new(0, 6, 0, 6)
    sellGrid.CellSize = UDim2.new(0.5, -4, 0, 26)

    local sellPad = Instance.new("UIPadding")
    sellPad.Parent = sellOreFrame
    sellPad.PaddingTop = UDim.new(0, 2)
    sellPad.PaddingBottom = UDim.new(0, 4)
    sellPad.PaddingLeft = UDim.new(0, 2)
    sellPad.PaddingRight = UDim.new(0, 2)

    local function addSellOreButton(name, text)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Parent = sellOreFrame
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

        return btn
    end

    local btnUnder7  = addSellOreButton("SellUnder7",  "Sell ≤ 7 Kg Ores")
    local btnUnder12 = addSellOreButton("SellUnder12", "Sell ≤ 12 Kg Ores")
    local btnUnder20 = addSellOreButton("SellUnder20", "Sell ≤ 20 Kg Ores")
    local btnThis    = addSellOreButton("SellThisOres","Sell This Ores")

    -- Label dropdown Ores
    local oreSelLabel = Instance.new("TextLabel")
    oreSelLabel.Name = "SelectedOreLabel"
    oreSelLabel.Parent = card
    oreSelLabel.BackgroundTransparency = 1
    oreSelLabel.Size = UDim2.new(1, 0, 0, 18)
    oreSelLabel.Font = Enum.Font.Gotham
    oreSelLabel.TextSize = 11
    oreSelLabel.TextXAlignment = Enum.TextXAlignment.Left
    oreSelLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
    oreSelLabel.Text = "Selected Ore (Sell This Ores):"

    -- Dropdown Ores
    local oreDdButton = Instance.new("TextButton")
    oreDdButton.Name = "OreDropdownButton"
    oreDdButton.Parent = card
    oreDdButton.Size = UDim2.new(1, 0, 0, 26)
    oreDdButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    oreDdButton.AutoButtonColor = true
    oreDdButton.Font = Enum.Font.Gotham
    oreDdButton.TextSize = 13
    oreDdButton.TextXAlignment = Enum.TextXAlignment.Left
    oreDdButton.TextColor3 = Color3.fromRGB(225, 225, 235)
    oreDdButton.Text = "Disable"

    local oreDdCorner = Instance.new("UICorner")
    oreDdCorner.CornerRadius = UDim.new(0, 6)
    oreDdCorner.Parent = oreDdButton

    local oreDdStroke = Instance.new("UIStroke")
    oreDdStroke.Parent = oreDdButton
    oreDdStroke.Thickness = 1
    oreDdStroke.Transparency = 0.3
    oreDdStroke.Color = Color3.fromRGB(60, 60, 85)

    local oreDdList = Instance.new("ScrollingFrame")
    oreDdList.Name = "OreDropdownList"
    oreDdList.Parent = card
    oreDdList.BackgroundTransparency = 1
    oreDdList.BorderSizePixel = 0
    oreDdList.Size = UDim2.new(1, 0, 0, 0)
    oreDdList.Visible = false
    oreDdList.ScrollBarThickness = 4
    oreDdList.CanvasSize = UDim2.new(0, 0, 0, 0)
    oreDdList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    oreDdList.ScrollBarImageTransparency = 0.2

    local oreDdPad = Instance.new("UIPadding")
    oreDdPad.Parent = oreDdList
    oreDdPad.PaddingTop = UDim.new(0, 2)
    oreDdPad.PaddingBottom = UDim.new(0, 4)
    oreDdPad.PaddingLeft = UDim.new(0, 2)
    oreDdPad.PaddingRight = UDim.new(0, 2)

    local oreDdLayout = Instance.new("UIListLayout")
    oreDdLayout.Parent = oreDdList
    oreDdLayout.FillDirection = Enum.FillDirection.Vertical
    oreDdLayout.SortOrder = Enum.SortOrder.LayoutOrder
    oreDdLayout.Padding = UDim.new(0, 2)

    -- Toggle Sell All Ores
    local _, toggleSellAll = createToggleButton(card, "Sell All Ores (Loop)")

    -- Ore Sell Progress
    local oreProg = Instance.new("TextLabel")
    oreProg.Name = "OreSellProgressLabel"
    oreProg.Parent = card
    oreProg.BackgroundTransparency = 1
    oreProg.Size = UDim2.new(1, 0, 0, 18)
    oreProg.Font = Enum.Font.Gotham
    oreProg.TextSize = 11
    oreProg.TextXAlignment = Enum.TextXAlignment.Left
    oreProg.TextColor3 = Color3.fromRGB(170, 220, 255)
    oreProg.Text = "Sell Ores Progress: -"

    return card,
        toggleMining,
        input,
        miningProg,
        lastOre,
        oreDdButton,
        oreDdList,
        toggleSellAll,
        oreProg,
        btnUnder7,
        btnUnder12,
        btnUnder20,
        btnThis
end

------------------- BUILD UI -------------------
headerFrame = createHeader(frame)
bodyFrame   = createBody(frame)

fishCard, getFishInputToggleBtn, getFishNonstopToggleBtn, fishCountInputBox, lastFishLabel, inputProgressLabel =
    createFishGiverCard(bodyFrame, 1)

sellCard, sellDropdownButton, sellDropdownListFrame, sellProgressLabel =
    createSellFishCard(bodyFrame, 2)

miningCard,
autoMiningToggleBtn,
miningCountInputBox,
miningProgressLabel,
lastOreLabel,
oreDropdownButton,
oreDropdownListFrame,
oreSellAllToggleBtn,
oreSellProgressLabel,
oreSellUnder7Button,
oreSellUnder12Button,
oreSellUnder20Button,
oreSellThisButton =
    createMiningCard(bodyFrame, 3)

logCard, logScrollFrame, logToggleBtn = createFishLogCard(bodyFrame, 4)

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

-- Default visual OFF
updateToggleVisual(getFishInputToggleBtn, false)
updateToggleVisual(getFishNonstopToggleBtn, false)
updateToggleVisual(logToggleBtn, false)
updateToggleVisual(autoMiningToggleBtn, false)
updateToggleVisual(oreSellAllToggleBtn, false)

------------------- HELPER: LOG -------------------
local function appendLog(text)
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
    if #logEntries > 100 then
        local oldest = table.remove(logEntries, 1)
        if oldest then
            oldest:Destroy()
        end
    end
end

------------------- HELPER: PROGRESS LABEL FISH -------------------
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

local function updateSellProgressLabel()
    if not sellProgressLabel then return end
    if not selectedFishCategory or selectedFishCategory == "" then
        sellProgressLabel.Text = "Sell Progress: -"
        return
    end
    local count = sellFishCountByCategory[selectedFishCategory] or 0
    sellProgressLabel.Text = string.format("Sell Progress: %d %s", count, selectedFishCategory)
end

------------------- HELPER: PROGRESS LABEL MINING/ORE -------------------
local function updateMiningProgressLabel()
    if not miningProgressLabel then return end

    if not autoMiningEnabled then
        miningProgressLabel.Text = "Mining Progress: -"
        return
    end

    if miningTargetLoops > 0 then
        local shown = math.min(miningCurrentLoop, miningTargetLoops)
        miningProgressLabel.Text =
            string.format("Mining Progress: loop %d/%d (1→7)", shown, miningTargetLoops)
    else
        miningProgressLabel.Text =
            string.format("Mining Progress: loop %d (Nonstop 1→7)", miningCurrentLoop)
    end
end

local function updateOreSellProgressLabel()
    if not oreSellProgressLabel then return end

    if not oreSelectedCategory or oreSelectedCategory == "" then
        oreSellProgressLabel.Text = "Sell Ores Progress: -"
        return
    end

    local count = oreSellCountByCategory[oreSelectedCategory] or 0
    oreSellProgressLabel.Text = string.format("Sell Ores Progress: %d %s", count, oreSelectedCategory)
end

------------------- HELPER: CLEAN NAMA ITEM -------------------
local function cleanItemName(raw)
    if type(raw) ~= "string" then
        return ""
    end

    local name = raw
    name = name:gsub("%(Favorite%)", "")
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")

    local base = name:match("^(.-)%s*%(")
    if base and base ~= "" then
        name = base:gsub("%s+$", "")
    end

    return name
end

------------------- HELPER: FISH DROPDOWN FILTER -------------------
local function isIgnoredToolForDropdown(toolName)
    if type(toolName) ~= "string" then return false end

    local lower   = toolName:lower()
    local compact = lower:gsub("%s+", "")

    if compact:sub(-3) == "rod" then
        return true
    end

    if lower:find("torch") then
        return true
    end

    if lower:find("pickaxe") or lower:find("picaxe") then
        return true
    end

    return false
end

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

------------------- BACKPACK FISH SCAN (SEKALI) -------------------
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
        appendLog("[Dropdown] Backpack tidak ditemukan untuk scan (Fish).")
        return
    end

    fishCategoryList = {}
    fishCategoryMap  = {}

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if not isIgnoredToolForDropdown(tool.Name) then
                local cname = cleanItemName(tool.Name)
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
                if not isIgnoredToolForDropdown(inst.Name) then
                    local cname = cleanItemName(inst.Name)
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
                    local cname = cleanItemName(inst.Name)
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

------------------- SELL FISH IMPLEMENTATION -------------------
local function sellUnderWeight(maxWeight)
    if not SellAllFishFunction then
        appendLog("[Sell] SellAllFishFunction tidak ditemukan.")
        return
    end

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
                finishSellThisFishLoop("Fish kategori '" .. categoryName .. "' sudah habis.")
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

------------------- DROPDOWN FISH BUILD -------------------
local function buildFishDropdownItems()
    if not sellDropdownListFrame then return end

    for _, child in ipairs(sellDropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    dropdownItemButtons = {}

    -- DISABLE ITEM
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

------------------- GET FISH INPUT / NONSTOP -------------------
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

------------------- ORES HELPER -------------------
local function getOreDisplayFromResult(res)
    local t = typeof(res)
    if t == "string" then
        return res
    elseif t == "table" then
        local name = res.OreName or res.Name or res.name
        if not name and res[1] and typeof(res[1]) == "string" then
            name = res[1]
        end

        local weight = res.Weight or res.weight
        if not weight and res[2] and tonumber(res[2]) then
            weight = tonumber(res[2])
        end

        if not name then
            name = "Unknown Ore"
        end

        if weight then
            return string.format("%s (%.2f kg)", tostring(name), tonumber(weight) or 0)
        else
            return tostring(name)
        end
    else
        return tostring(res)
    end
end

local function isIgnoredToolForOres(toolName)
    if type(toolName) ~= "string" then return true end
    local lower = toolName:lower()
    local compact = lower:gsub("%s+", "")

    if compact:sub(-3) == "rod" then return true end
    if lower:find("torch") then return true end
    if lower:find("pickaxe") or lower:find("picaxe") then return true end
    if lower:find("fish") or lower:find("ikan") then return true end

    return false
end

local function isOreName(toolName)
    if type(toolName) ~= "string" then return false end
    local lower = toolName:lower()
    if lower:find("ore") or lower:find("iron") or lower:find("gold") or lower:find("diamond") or lower:find("crystal") or lower:find("gem") then
        return true
    end
    return false
end

local function buildOreCategoryList()
    local list = {}
    local map  = {}

    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")

    local function scan(container)
        if not container then return end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") then
                local name = inst.Name
                if not isIgnoredToolForOres(name) and isOreName(name) then
                    local cname = cleanItemName(name)
                    if cname ~= "" and not map[cname] then
                        map[cname] = true
                        table.insert(list, cname)
                    end
                end
            end
        end
    end

    scan(char)
    scan(backpack)

    table.sort(list, function(a, b)
        return a:lower() < b:lower()
    end)

    return list
end

local function countOreToolsInCategory(categoryName)
    if not categoryName or categoryName == "" then
        return 0
    end

    local count = 0

    local function countInContainer(container)
        if not container then return end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") then
                if not isIgnoredToolForOres(inst.Name) and isOreName(inst.Name) then
                    local cname = cleanItemName(inst.Name)
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

local function findOreToolByCategory(categoryName)
    if not categoryName or categoryName == "" then
        return nil
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    local char     = LocalPlayer.Character

    local function search(container)
        if not container then return nil end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") then
                if not isIgnoredToolForOres(inst.Name) and isOreName(inst.Name) then
                    local cname = cleanItemName(inst.Name)
                    if cname == categoryName then
                        return inst
                    end
                end
            end
        end
        return nil
    end

    local t = search(char)
    if t then return t end
    return search(backpack)
end

local function sellOreUnderWeight(maxWeight)
    if not SellOreBackpackFunction then
        appendLog("[Ores] SellOreBackpackFunction tidak ditemukan.")
        return
    end

    local ok, res = pcall(function()
        return SellOreBackpackFunction:InvokeServer(maxWeight)
    end)

    if not ok then
        appendLog(string.format("[Ores] Error SellOreBackpack(%d): %s", maxWeight, tostring(res)))
    else
        appendLog(string.format("[Ores] SellOreBackpack ≤ %d Kg OK.", maxWeight))
    end
end

local function sellAllOresOnce()
    if not SellOreBackpackFunction then
        appendLog("[Ores] SellOreBackpackFunction tidak ditemukan (Sell All).")
        return
    end

    local ok, res = pcall(function()
        return SellOreBackpackFunction:InvokeServer(math.huge)
    end)

    if not ok then
        appendLog("[Ores] Error SellOreBackpack(math.huge): " .. tostring(res))
    else
        appendLog("[Ores] SellOreBackpack ALL OK.")
    end
end

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

    if not oreSelectedCategory or oreSelectedCategory == "" then
        appendLog("[Ores] Selected Ore belum dipilih (dropdown).")
        return
    end

    if isSellingThisOres then
        appendLog("[Ores] SellThisOres loop sudah berjalan.")
        return
    end

    local total = countOreToolsInCategory(oreSelectedCategory)
    if total <= 0 then
        appendLog("[Ores] Tidak ada ore kategori '" .. oreSelectedCategory .. "' di Backpack/Character.")
        return
    end

    isSellingThisOres = true
    sellThisOresLoopId += 1
    local thisLoopId = sellThisOresLoopId
    local categoryName = oreSelectedCategory

    appendLog(string.format("[Ores] Mulai SellThisOres batch: %s (total ± %d)", categoryName, total))

    task.spawn(function()
        for i = 1, total do
            if not alive then
                finishSellThisOresLoop("Tab tidak aktif")
                return
            end
            if thisLoopId ~= sellThisOresLoopId then
                return
            end

            local char = LocalPlayer.Character
            if not char then
                finishSellThisOresLoop("Character belum siap")
                return
            end

            local tool = findOreToolByCategory(categoryName)
            if not tool then
                finishSellThisOresLoop("Ore kategori '" .. categoryName .. "' sudah habis.")
                return
            end

            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
            else
                tool.Parent = char
            end

            local ok, res = pcall(function()
                return Sell1OreFunction:InvokeServer(math.huge, true)
            end)

            if not ok then
                appendLog("[Ores] Error Sell1Ore(math.huge, true): " .. tostring(res))
                finishSellThisOresLoop("Error Sell1Ore")
                return
            else
                oreSellCountByCategory[categoryName] =
                    (oreSellCountByCategory[categoryName] or 0) + 1
                updateOreSellProgressLabel()
                appendLog(string.format("[Ores] Sell1Ore OK (%s) ke-%d", categoryName, i))
            end

            if i < total then
                task.wait(SELL_THIS_FISH_DELAY)
            end
        end

        if alive and thisLoopId == sellThisOresLoopId then
            finishSellThisOresLoop("Selesai jual semua ore kategori " .. tostring(categoryName))
        else
            finishSellThisOresLoop("Dihentikan sebelum selesai")
        end
    end)
end

local function updateOreDropdownHighlight()
    for key, b in pairs(oreDropdownItemButtons) do
        if key == oreCurrentDropdownKey then
            b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            b.TextColor3       = Color3.fromRGB(245, 245, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            b.TextColor3       = Color3.fromRGB(220, 220, 230)
        end
    end
end

local function buildOreDropdownItems()
    if not oreDropdownListFrame then return end

    for _, child in ipairs(oreDropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    oreDropdownItemButtons = {}

    -- Disable item
    do
        local btn = Instance.new("TextButton")
        btn.Name = "OreItem_Disable"
        btn.Parent = oreDropdownListFrame
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

        oreDropdownItemButtons["__DISABLE__"] = btn

        btn.MouseButton1Click:Connect(function()
            oreSelectedCategory   = nil
            oreCurrentDropdownKey = "__DISABLE__"
            if oreDropdownButton then
                oreDropdownButton.Text = "Disable"
            end
            updateOreDropdownHighlight()
            updateOreSellProgressLabel()

            if oreDropdownListFrame then
                oreDropdownListFrame.Visible = false
                oreDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
            end

            appendLog("[Ores] Selected Ore diubah ke: Disable")
        end)
    end

    local oreCategories = buildOreCategoryList()

    for _, cname in ipairs(oreCategories) do
        local btn = Instance.new("TextButton")
        btn.Name = "OreItem_" .. cname
        btn.Parent = oreDropdownListFrame
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left

        local initialCount = countOreToolsInCategory(cname)
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Text = string.format("%dx %s", initialCount, cname)

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn

        oreDropdownItemButtons[cname] = btn

        btn.MouseButton1Click:Connect(function()
            oreSelectedCategory   = cname
            oreCurrentDropdownKey = cname

            if oreDropdownButton then
                local currentCount = countOreToolsInCategory(cname)
                oreDropdownButton.Text = string.format("%dx %s", currentCount, cname)
            end

            updateOreDropdownHighlight()
            updateOreSellProgressLabel()

            if oreDropdownListFrame then
                oreDropdownListFrame.Visible = false
                oreDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
            end

            appendLog("[Ores] Selected Ore diubah ke: " .. tostring(oreSelectedCategory))
        end)
    end

    if not oreSelectedCategory then
        oreCurrentDropdownKey = "__DISABLE__"
        if oreDropdownButton then
            oreDropdownButton.Text = "Disable"
        end
    end

    updateOreDropdownHighlight()
    updateOreSellProgressLabel()
end

------------------- AUTO SELL ALL ORES LOOP -------------------
local function scheduleAutoSellAllOresStep(loopId)
    task.spawn(function()
        if not alive then return end
        if not autoSellAllOresEnabled then return end
        if loopId ~= autoSellAllOresLoopId then return end

        sellAllOresOnce()

        task.wait(ORE_SELL_ALL_DELAY)

        if not alive then return end
        if not autoSellAllOresEnabled then return end
        if loopId ~= autoSellAllOresLoopId then return end

        scheduleAutoSellAllOresStep(loopId)
    end)
end

local function startAutoSellAllOres()
    if not alive then return end

    autoSellAllOresLoopId += 1
    local thisLoopId = autoSellAllOresLoopId

    notify("Indo Beach - Ores", "Auto Sell All Ores dimulai.", 4)
    scheduleAutoSellAllOresStep(thisLoopId)
end

------------------- MINING LOGIC -------------------
local function doMining(index)
    if not alive then return end
    if not GiveCrystalFunction then
        appendLog("[Mining] GiveCrystal remote tidak ditemukan.")
        return
    end

    local v = MINING_VALUES[index]
    if not v then
        appendLog("[Mining] Index mining tidak valid: " .. tostring(index))
        return
    end

    local ok, res = pcall(function()
        return GiveCrystalFunction:InvokeServer(FISH_CODE, v)
    end)

    if not ok then
        appendLog(string.format("[Mining] Error Mining %d: %s", index, tostring(res)))
    else
        local oreText = getOreDisplayFromResult(res)
        if lastOreLabel then
            lastOreLabel.Text = "Last Ore: " .. oreText
        end
        appendLog(string.format("[Mining] Mining %d OK: %s", index, oreText))
    end
end

local function scheduleAutoMiningStep(loopId, currentIndex)
    task.spawn(function()
        if not alive then return end
        if not autoMiningEnabled then return end
        if loopId ~= autoMiningLoopId then return end

        doMining(currentIndex)

        local nextIndex = currentIndex + 1
        local nextLoop  = miningCurrentLoop

        if nextIndex > 7 then
            nextIndex = 1
            nextLoop  = nextLoop + 1
            miningCurrentLoop = nextLoop
            updateMiningProgressLabel()

            if miningTargetLoops > 0 and nextLoop >= miningTargetLoops then
                autoMiningEnabled = false
                updateToggleVisual(autoMiningToggleBtn, false)
                notify("Indo Beach - Mining", "Auto Mining 1-7 selesai.", 4)
                return
            end
        end

        task.wait(MINING_DELAY)

        if not alive then return end
        if not autoMiningEnabled then return end
        if loopId ~= autoMiningLoopId then return end

        scheduleAutoMiningStep(loopId, nextIndex)
    end)
end

local function startAutoMining()
    if not alive then return end

    local loops = 0
    if miningCountInputBox and miningCountInputBox.Text and miningCountInputBox.Text ~= "" then
        local n = tonumber(miningCountInputBox.Text)
        if n and n > 0 then
            loops = math.floor(n)
        end
    end

    miningTargetLoops = loops
    miningCurrentLoop = 0
    updateMiningProgressLabel()

    autoMiningLoopId = autoMiningLoopId + 1
    local thisLoopId = autoMiningLoopId

    if loops > 0 then
        notify("Indo Beach - Mining", "Auto Mining 1-7 x" .. tostring(loops) .. " loop dimulai.", 4)
    else
        notify("Indo Beach - Mining", "Auto Mining 1-7 Nonstop dimulai.", 4)
    end

    scheduleAutoMiningStep(thisLoopId, 1)
end

------------------- UI EVENTS -------------------

-- FISH DROPDOWN
initFishDropdown()

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

-- FISH INPUT VALIDATION
if fishCountInputBox then
    fishCountInputBox.FocusLost:Connect(function()
        local n = tonumber(fishCountInputBox.Text)
        if not n or n <= 0 then
            fishCountInputBox.Text = "10"
        end
    end)
end

-- GET FISH INPUT
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

-- GET FISH NONSTOP
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

-- LOG RAW TOGGLE
if logToggleBtn then
    logToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end
        logRawEnabled = not logRawEnabled
        updateToggleVisual(logToggleBtn, logRawEnabled)
    end)
end

-- SELL MODE BUTTONS
for mode, btn in pairs(sellModeButtons) do
    btn.MouseButton1Click:Connect(function()
        if not alive then return end
        setSellMode(mode)
        applyAutoSellAfterCatch()
    end)
end

-- MINING LOOP INPUT VALIDATION
if miningCountInputBox then
    miningCountInputBox.FocusLost:Connect(function()
        local txt = miningCountInputBox.Text
        local n = tonumber(txt)
        if not n or n < 0 then
            miningCountInputBox.Text = "0"
        else
            miningCountInputBox.Text = tostring(math.floor(n))
        end
    end)
end

-- MANUAL MINING 1-7
for idx, btn in pairs(miningButtons) do
    if btn then
        btn.MouseButton1Click:Connect(function()
            if not alive then return end
            doMining(idx)
        end)
    end
end

-- AUTO MINING TOGGLE
if autoMiningToggleBtn then
    autoMiningToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        autoMiningEnabled = not autoMiningEnabled
        updateToggleVisual(autoMiningToggleBtn, autoMiningEnabled)

        if autoMiningEnabled then
            startAutoMining()
        else
            autoMiningLoopId = autoMiningLoopId + 1
            updateMiningProgressLabel()
            notify("Indo Beach - Mining", "Auto Mining 1-7 dihentikan oleh user.", 3)
        end
    end)
end

-- ORES DROPDOWN BUTTON
if oreDropdownButton then
    oreDropdownButton.MouseButton1Click:Connect(function()
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

-- SELL UNDER 7 / 12 / 20 KG ORES
if oreSellUnder7Button then
    oreSellUnder7Button.MouseButton1Click:Connect(function()
        if not alive then return end
        sellOreUnderWeight(6)   -- ≤ 6 kg = Under 7
    end)
end

if oreSellUnder12Button then
    oreSellUnder12Button.MouseButton1Click:Connect(function()
        if not alive then return end
        sellOreUnderWeight(11)  -- ≤ 11 kg = Under 12
    end)
end

if oreSellUnder20Button then
    oreSellUnder20Button.MouseButton1Click:Connect(function()
        if not alive then return end
        sellOreUnderWeight(19)  -- ≤ 19 kg = Under 20
    end)
end

-- SELL THIS ORES BUTTON
if oreSellThisButton then
    oreSellThisButton.MouseButton1Click:Connect(function()
        if not alive then return end
        sellThisOresAll()
    end)
end

-- SELL ALL ORES LOOP TOGGLE
if oreSellAllToggleBtn then
    oreSellAllToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end

        autoSellAllOresEnabled = not autoSellAllOresEnabled
        updateToggleVisual(oreSellAllToggleBtn, autoSellAllOresEnabled)

        if autoSellAllOresEnabled then
            startAutoSellAllOres()
        else
            autoSellAllOresLoopId = autoSellAllOresLoopId + 1
            notify("Indo Beach - Ores", "Auto Sell All Ores dihentikan oleh user.", 3)
        end
    end)
end

-- Set default sell mode fish = Disable
setSellMode(SellMode.Disable)

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
    isSellingThisOres     = false
    sellThisOresLoopId    = sellThisOresLoopId + 1
    autoSellAllOresEnabled = false
    autoSellAllOresLoopId  = autoSellAllOresLoopId + 1
end
