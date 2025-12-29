--==========================================================
--  18AxaTab_IndoOcean.lua
--  TAB 18: "Indo Ocean - Fish Giver V2 (MiniGame Complete + Auto Sell + Drop Money + Rod Setting + Rod Shop)"
--==========================================================

------------------- ENV / TAB -------------------
local frame  = TAB_FRAME
local tabId  = TAB_ID or "indoocean"

local Players             = Players             or game:GetService("Players")
local LocalPlayer         = LocalPlayer         or Players.LocalPlayer
local RunService          = RunService          or game:GetService("RunService")
local StarterGui          = StarterGui          or game:GetService("StarterGui")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local HttpService         = HttpService         or game:GetService("HttpService")
local MarketplaceService  = game:GetService("MarketplaceService")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- CONFIG (Indo Ocean) -------------------
-- Remote Sell Fish (Indo Ocean)
local RemoteFishFolder = ReplicatedStorage:WaitForChild("RemoteFish", 5)
local JualIkanRemote   = RemoteFishFolder and RemoteFishFolder:WaitForChild("JualIkanRemote", 5)

-- Remote Drop Money
local DropEventFolder = ReplicatedStorage:WaitForChild("DropEvent", 5)
local DropCashEvent   = DropEventFolder and DropEventFolder:WaitForChild("DropCashEvent", 5)

-- Remotes Rod Shop
local RemotesFolder       = ReplicatedStorage:WaitForChild("Remotes", 5)
local GetShopDataRemote   = RemotesFolder and RemotesFolder:WaitForChild("GetShopData", 5)
local BuyItemRemote       = RemotesFolder and RemotesFolder:WaitForChild("BuyItem", 5)

-- TUNING Fish Giver
local INPUT_DELAY             = 0.01
local NONSTOP_DELAY_DEFAULT   = 0.50
local SELL_THIS_FISH_DELAY    = 0.4

-- TUNING Drop Money
local DROP_DELAY_MIN = 5
local DROP_DELAY_MAX = 8

-- LIST ROD (ToolName key)
local rodOptions = {
    "NormalRod",
    "SteakRod",
    "RobotRod",
    "SausageRod",
    "LovingRod",
    "LanternRod",
    "NarwhaleRod",
    "CelebrationRod",
    "RubberDuckRod",
    "CoralRod",
    "CatRod",
    "SakuraRod",
    "BinaryRod",
    "UmbrellaRod",
}

-- Map canonical rod key -> true
local rodOptionsMap = {}
-- Map berbagai nama Tool (dengan / tanpa spasi) -> canonical rod key (NormalRod, dll)
local rodNameToKey  = {}

local function buildRodAliasMaps()
    for _, key in ipairs(rodOptions) do
        rodOptionsMap[key] = true
        -- nama persis
        rodNameToKey[key] = key
        -- nama dengan spasi (NormalRod -> Normal Rod, RubberDuckRod -> Rubber Duck Rod, dll)
        local spaced = key:gsub("(%l)(%u)", "%1 %2")
        rodNameToKey[spaced] = key
    end
end

buildRodAliasMaps()

-- Mapping key -> nama shop (dipakai Rod Shop / alias Character "Robot Rod")
local rodMeta = {
    NormalRod      = { shopName = "Normal Rod" },
    SteakRod       = { shopName = "Steak Rod" },
    RobotRod       = { shopName = "Robot Rod" },
    SausageRod     = { shopName = "Sausage Rod" },
    LovingRod      = { shopName = "Loving Rod" },
    LanternRod     = { shopName = "Lantern Rod" },
    NarwhaleRod    = { shopName = "Narwhale Rod" },
    CelebrationRod = { shopName = "Celebration Rod" },
    RubberDuckRod  = { shopName = "Rubber Duck Rod" },
    CoralRod       = { shopName = "Coral Rod" },
    CatRod         = { shopName = "Cat Rod" },
    SakuraRod      = { shopName = "Sakura Rod" },
    BinaryRod      = { shopName = "Binary Rod" },
    UmbrellaRod    = { shopName = "Umbrella Rod" },
}

local function getShopNameFromTool(toolKey)
    local meta = rodMeta[toolKey]
    return (meta and meta.shopName) or toolKey
end

------------------- STATE UTAMA - FISH -------------------
local alive                  = true
local getFishInputEnabled    = false
local getFishNonstopEnabled  = false
local currentInputTaskId     = 0

local logEntries             = {}

local inputTargetCount       = 0
local inputCurrentCount      = 0

-- Sell Mode:
-- 1. Disable
-- 2. 1–10 Kg
-- 3. 0–100 Kg
-- 4. 100–200 Kg
-- 5. 300–500 Kg
-- 6. 500–1000 Kg
-- 7. 1000–3000 Kg
-- 8. Sell This Fish
-- 9. Sell All Fish
local SellMode = {
    Disable      = 1,
    Kg1_10       = 2,
    Kg0_100      = 3,
    Kg100_200    = 4,
    Kg300_500    = 5,
    Kg500_1000   = 6,
    Kg1000_3000  = 7,
    ThisFish     = 8,
    AllFish      = 9,
}

local currentSellMode = SellMode.Disable

local scannedBackpack      = false
local fishCategoryList     = {}
local fishCategoryMap      = {}
local selectedFishCategory = nil

local isSellingThisFish       = false
local sellFishCountByCategory = {}
local logRawEnabled           = false
local nonstopLoopId           = 0
local sellThisFishLoopId      = 0

local totalFishCount          = 0

------------------- STATE CASH -------------------
local cashValueObj        = nil
local currentCash         = 0
local lastSellIncome      = 0
local totalSellIncome     = 0
local cashConn            = nil

------------------- STATE DROP MONEY -------------------
local dropInputBox
local dropOnceButton
local autoDrop10MToggleBtn
local autoDrop100MToggleBtn
local autoDrop1BToggleBtn

local autoDrop10MEnabled   = false
local autoDrop100MEnabled  = false
local autoDrop1BEnabled    = false

local autoDrop10MLoopId    = 0
local autoDrop100MLoopId   = 0
local autoDrop1BLoopId     = 0

------------------- STATE ROD SETTING -------------------
local currentRodName      = "NormalRod"
local rodCard
local rodDropdownButton
local rodDropdownListFrame
local rodDropdownButtons  = {}
local rodCurrentLabel
local nonstopDelaySec     = NONSTOP_DELAY_DEFAULT

------------------- STATE ROD SHOP -------------------
local rodShopData           = {}
local rodShopScroll
local rodShopItems          = {} -- [toolKey] = {frame=..., buyButton=..., priceText=..., shopName=..., entry=...}
local ownedRodMap           = {} -- [toolKey] = bool
local rodShopLoaded         = false

------------------- UI REFERENCES -------------------
local headerFrame
local bodyFrame

-- Fish UI
local fishCard
local sellCard
local logCard
local dropCard
local rodShopCard

local getFishInputToggleBtn
local getFishNonstopToggleBtn
local fishCountInputBox
local nonstopDelayInputBox
local lastFishLabel
local inputProgressLabel
local logScrollFrame

local sellModeButtons = {}

local sellDropdownButton
local sellDropdownListFrame
local dropdownItemButtons = {}
local fishRefreshButton

local sellProgressLabel
local totalFishLabel
local logToggleBtn

local cashLabel
local lastSellIncomeLabel
local totalSellIncomeLabel

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
    title.TextColor3 = Color3.fromRGB(0, 0, 0)
    title.Text = "Indo Ocean - Fish Giver V2.3"

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
    desc.Text = "MiniGame Complete + Auto Sell + Drop Money + Rod Shop"

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
        "MiniGame: <Rod>.MiniGame:FireServer(\"Complete\") - Get Fish Input / Nonstop",
        order
    )

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

    local _, toggleInput = createToggleButton(card, "Get Fish Input (Jumlah tertentu)")

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

    local _, toggleNonstop = createToggleButton(card, "Get Fish Nonstop (Loop terus menerus)")

    -- Input Delay Nonstop (UI baru)
    local delayBox = Instance.new("TextBox")
    delayBox.Name = "NonstopDelayInput"
    delayBox.Parent = card
    delayBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    delayBox.Size = UDim2.new(1, 0, 0, 26)
    delayBox.ClearTextOnFocus = false
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 13
    delayBox.TextColor3 = Color3.fromRGB(225, 225, 235)
    delayBox.TextXAlignment = Enum.TextXAlignment.Left
    delayBox.Text = tostring(NONSTOP_DELAY_DEFAULT)
    delayBox.PlaceholderText = "Delay Nonstop (detik, contoh: 0.01 / 0.05 / 0.1)"
    delayBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)

    local delayCorner = Instance.new("UICorner")
    delayCorner.CornerRadius = UDim.new(0, 6)
    delayCorner.Parent = delayBox

    local delayStroke = Instance.new("UIStroke")
    delayStroke.Parent = delayBox
    delayStroke.Thickness = 1
    delayStroke.Transparency = 0.3
    delayStroke.Color = Color3.fromRGB(60, 60, 85)

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

    return card, toggleInput, toggleNonstop, input, lastLbl, prog, delayBox
end

local function createSellFishCard(parent, order)
    local card = createCard(
        parent,
        "Sell Fish Control (Auto Sell Mode + Cash Info)",
        "RemoteFish.JualIkanRemote (1–10 / 0–100 / 100–200 / 300–500 / 500–1000 / 1000–3000 / Hand / All)",
        order
    )

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

    -- Mode 1–9
    addSellButton(SellMode.Disable,      "Disable")
    addSellButton(SellMode.Kg1_10,       "Sell 1–10 Kg")
    addSellButton(SellMode.Kg0_100,      "Sell 0–100 Kg")
    addSellButton(SellMode.Kg100_200,    "Sell 100–200 Kg")
    addSellButton(SellMode.Kg300_500,    "Sell 300–500 Kg")
    addSellButton(SellMode.Kg500_1000,   "Sell 500–1000 Kg")
    addSellButton(SellMode.Kg1000_3000,  "Sell 1000–3000 Kg")
    addSellButton(SellMode.ThisFish,     "Sell This Fish (Hand Loop)")
    addSellButton(SellMode.AllFish,      "Sell All Fish")

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

    local totalLbl = Instance.new("TextLabel")
    totalLbl.Name = "TotalFishLabel"
    totalLbl.Parent = card
    totalLbl.BackgroundTransparency = 1
    totalLbl.Size = UDim2.new(1, 0, 0, 18)
    totalLbl.Font = Enum.Font.Gotham
    totalLbl.TextSize = 11
    totalLbl.TextXAlignment = Enum.TextXAlignment.Left
    totalLbl.TextColor3 = Color3.fromRGB(180, 230, 180)
    totalLbl.Text = "Total Fish (Backpack): 0 Fish"

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Name = "RefreshFishButton"
    refreshBtn.Parent = card
    refreshBtn.Size = UDim2.new(1, 0, 0, 24)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    refreshBtn.AutoButtonColor = true
    refreshBtn.Font = Enum.Font.Gotham
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.fromRGB(220, 220, 235)
    refreshBtn.Text = "Refresh Fish Dropdown (Scan Backpack)"

    local rfCorner = Instance.new("UICorner")
    rfCorner.CornerRadius = UDim.new(0, 6)
    rfCorner.Parent = refreshBtn

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

    local cashLbl = Instance.new("TextLabel")
    cashLbl.Name = "CashLabel"
    cashLbl.Parent = card
    cashLbl.BackgroundTransparency = 1
    cashLbl.Size = UDim2.new(1, 0, 0, 18)
    cashLbl.Font = Enum.Font.Gotham
    cashLbl.TextSize = 11
    cashLbl.TextXAlignment = Enum.TextXAlignment.Left
    cashLbl.TextColor3 = Color3.fromRGB(200, 230, 200)
    cashLbl.Text = "Cash: -"

    local lastSellLbl = Instance.new("TextLabel")
    lastSellLbl.Name = "LastSellIncomeLabel"
    lastSellLbl.Parent = card
    lastSellLbl.BackgroundTransparency = 1
    lastSellLbl.Size = UDim2.new(1, 0, 0, 18)
    lastSellLbl.Font = Enum.Font.Gotham
    lastSellLbl.TextSize = 11
    lastSellLbl.TextXAlignment = Enum.TextXAlignment.Left
    lastSellLbl.TextColor3 = Color3.fromRGB(220, 220, 200)
    lastSellLbl.Text = "Last Sell Income: 0"

    local totalIncomeLbl = Instance.new("TextLabel")
    totalIncomeLbl.Name = "TotalSellIncomeLabel"
    totalIncomeLbl.Parent = card
    totalIncomeLbl.BackgroundTransparency = 1
    totalIncomeLbl.Size = UDim2.new(1, 0, 0, 18)
    totalIncomeLbl.Font = Enum.Font.Gotham
    totalIncomeLbl.TextSize = 11
    totalIncomeLbl.TextXAlignment = Enum.TextXAlignment.Left
    totalIncomeLbl.TextColor3 = Color3.fromRGB(220, 220, 200)
    totalIncomeLbl.Text = "Total Sell Income: 0"

    return card, ddButton, ddList, prog, refreshBtn, cashLbl, lastSellLbl, totalIncomeLbl, totalLbl
end

local function createFishLogCard(parent, order)
    local card = createCard(
        parent,
        "Fish Log (Last 100)",
        "Riwayat Fish Giver & Sell status",
        order
    )

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

local function createDropMoneyCard(parent, order)
    local card = createCard(
        parent,
        "Drop Money Control",
        "Drop manual + Auto Drop 10 jt / 100 jt / 1 Miliar (5–8 detik)",
        order
    )

    local input = Instance.new("TextBox")
    input.Name = "DropAmountInput"
    input.Parent = card
    input.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    input.Size = UDim2.new(1, 0, 0, 26)
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = Color3.fromRGB(225, 225, 235)
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Text = ""
    input.PlaceholderText = "Input Drop Money"
    input.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = input

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Parent = input
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.3
    inputStroke.Color = Color3.fromRGB(60, 60, 85)

    local manualBtn = Instance.new("TextButton")
    manualBtn.Name = "DropOnceButton"
    manualBtn.Parent = card
    manualBtn.Size = UDim2.new(1, 0, 0, 26)
    manualBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    manualBtn.AutoButtonColor = true
    manualBtn.Font = Enum.Font.GothamBold
    manualBtn.TextSize = 12
    manualBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    manualBtn.Text = "Drop Sekali (Manual)"

    local manualCorner = Instance.new("UICorner")
    manualCorner.CornerRadius = UDim.new(0, 6)
    manualCorner.Parent = manualBtn

    local _, auto10Btn = createToggleButton(card, "Auto Drop 10.000.000 (10 jt)")
    local _, auto100Btn = createToggleButton(card, "Auto Drop 100.000.000 (100 jt)")
    local _, auto1BBtn  = createToggleButton(card, "Auto Drop 1.000.000.000 (1 Miliar)")

    return card, input, manualBtn, auto10Btn, auto100Btn, auto1BBtn
end

local function createRodSettingCard(parent, order)
    local card = createCard(
        parent,
        "Rod Setting",
        "Pilih default Rod untuk MiniGame Complete",
        order
    )

    local lbl = Instance.new("TextLabel")
    lbl.Name = "CurrentRodLabel"
    lbl.Parent = card
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(180, 220, 255)
    lbl.Text = "Current Rod: " .. currentRodName

    local ddBtn = Instance.new("TextButton")
    ddBtn.Name = "RodDropdownButton"
    ddBtn.Parent = card
    ddBtn.Size = UDim2.new(1, 0, 0, 26)
    ddBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    ddBtn.AutoButtonColor = true
    ddBtn.Font = Enum.Font.Gotham
    ddBtn.TextSize = 13
    ddBtn.TextXAlignment = Enum.TextXAlignment.Left
    ddBtn.TextColor3 = Color3.fromRGB(225, 225, 235)
    ddBtn.Text = currentRodName

    local ddCorner = Instance.new("UICorner")
    ddCorner.CornerRadius = UDim.new(0, 6)
    ddCorner.Parent = ddBtn

    local ddStroke = Instance.new("UIStroke")
    ddStroke.Parent = ddBtn
    ddStroke.Thickness = 1
    ddStroke.Transparency = 0.3
    ddStroke.Color = Color3.fromRGB(60, 60, 85)

    local ddList = Instance.new("ScrollingFrame")
    ddList.Name = "RodDropdownList"
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

    rodCurrentLabel      = lbl
    rodDropdownButton    = ddBtn
    rodDropdownListFrame = ddList

    return card
end

local function createRodShopCard(parent, order)
    local card = createCard(
        parent,
        "Rod Shop",
        "Data dari Remotes.GetShopData + BuyItem (Owned dari Backpack/Character/StarterGear)",
        order
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "RodShopScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Size = UDim2.new(1, 0, 0, 220)
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarImageTransparency = 0.2

    local pad = Instance.new("UIPadding")
    pad.Parent = scroll
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)

    rodShopScroll = scroll
    return card
end

------------------- BUILD UI -------------------
headerFrame = createHeader(frame)
bodyFrame   = createBody(frame)

fishCard, getFishInputToggleBtn, getFishNonstopToggleBtn, fishCountInputBox,
    lastFishLabel, inputProgressLabel, nonstopDelayInputBox =
    createFishGiverCard(bodyFrame, 1)

sellCard, sellDropdownButton, sellDropdownListFrame, sellProgressLabel,
    fishRefreshButton, cashLabel, lastSellIncomeLabel, totalSellIncomeLabel, totalFishLabel =
    createSellFishCard(bodyFrame, 2)

logCard, logScrollFrame, logToggleBtn =
    createFishLogCard(bodyFrame, 3)

dropCard, dropInputBox, dropOnceButton,
    autoDrop10MToggleBtn, autoDrop100MToggleBtn, autoDrop1BToggleBtn =
    createDropMoneyCard(bodyFrame, 4)

rodCard = createRodSettingCard(bodyFrame, 5)
rodShopCard = createRodShopCard(bodyFrame, 6)

-- Init toggle visual
updateToggleVisual(getFishInputToggleBtn, false)
updateToggleVisual(getFishNonstopToggleBtn, false)
updateToggleVisual(logToggleBtn, false)
updateToggleVisual(autoDrop10MToggleBtn, false)
updateToggleVisual(autoDrop100MToggleBtn, false)
updateToggleVisual(autoDrop1BToggleBtn, false)

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

------------------- HELPER: CLEAN NAMA IKAN -------------------
local function cleanFishName(raw)
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

------------------- HELPER: IGNORE TOOL (ROD/TORCH/PICKAXE) -------------------
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

------------------- BACKPACK SCAN (FISH, BISA REFRESH) -------------------
local function scanBackpack()
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

    fishCategoryList = {}
    fishCategoryMap  = {}
    totalFishCount   = 0

    if not backpack then
        appendLog("[Dropdown] Backpack tidak ditemukan untuk scan.")
        if totalFishLabel then
            totalFishLabel.Text = "Total Fish (Backpack): 0 Fish"
        end
        return
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if not isIgnoredToolForDropdown(tool.Name) then
                totalFishCount += 1
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

    if totalFishLabel then
        totalFishLabel.Text = string.format("Total Fish (Backpack): %d Fish", totalFishCount)
    end
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
                    -- skip
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

------------------- HELPER: HITUNG FISH KATEGORI -------------------
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

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindChild("Backpack")
    if not backpack then
        local ok, res = pcall(function()
            return LocalPlayer:WaitForChild("Backpack", 5)
        end)
        if ok then
            backpack = res
        end
    end
    local char     = LocalPlayer.Character

    countInContainer(char)
    countInContainer(backpack)

    return count
end

------------------- CASH LISTENER -------------------
local function initCashListener()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then
        local ok, res = pcall(function()
            return LocalPlayer:WaitForChild("leaderstats", 10)
        end)
        if ok then
            ls = res
        end
    end

    if not ls then
        appendLog("[Cash] leaderstats tidak ditemukan.")
        return
    end

    local cashNames = { "Cash", "Money", "Coins" }
    for _, name in ipairs(cashNames) do
        local v = ls:FindFirstChild(name)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            cashValueObj = v
            break
        end
    end

    if not cashValueObj then
        appendLog("[Cash] Tidak menemukan value Cash/Money/Coins di leaderstats.")
        return
    end

    currentCash = tonumber(cashValueObj.Value) or 0

    if cashLabel then
        cashLabel.Text = "Cash: " .. tostring(currentCash)
    end
    if lastSellIncomeLabel then
        lastSellIncomeLabel.Text = "Last Sell Income: 0"
    end
    if totalSellIncomeLabel then
        totalSellIncomeLabel.Text = "Total Sell Income: 0"
    end

    cashConn = cashValueObj.Changed:Connect(function(newValue)
        local newCash = tonumber(newValue) or tonumber(cashValueObj.Value) or 0
        local delta   = newCash - currentCash
        currentCash   = newCash

        if cashLabel then
            cashLabel.Text = "Cash: " .. tostring(currentCash)
        end

        if delta > 0 then
            lastSellIncome  = delta
            totalSellIncome = totalSellIncome + delta

            if lastSellIncomeLabel then
                lastSellIncomeLabel.Text = "Last Sell Income: " .. tostring(lastSellIncome)
            end
            if totalSellIncomeLabel then
                totalSellIncomeLabel.Text = "Total Sell Income: " .. tostring(totalSellIncome)
            end
        end
        -- delta < 0 (Drop Money / belanja) hanya update Cash.
    end)
end

initCashListener()

------------------- HELPER: SELL RANGE VIA REMOTEFISH -------------------
local function fireSellRange(rangeKey)
    if not JualIkanRemote then
        appendLog("[Sell] RemoteFish.JualIkanRemote tidak ditemukan.")
        return
    end

    local ok, err = pcall(function()
        local args = { [1] = rangeKey }
        JualIkanRemote:FireServer(unpack(args))
    end)

    if not ok then
        appendLog("[Sell] Error JualIkanRemote(" .. tostring(rangeKey) .. "): " .. tostring(err))
    else
        appendLog("[Sell] JualIkanRemote(" .. tostring(rangeKey) .. ") OK.")
    end
end

------------------- SELL THIS FISH (BATCH dengan Hand) -------------------
local function finishSellThisFishLoop(reason)
    if isSellingThisFish then
        isSellingThisFish = false
        appendLog("[Sell] SellThisFish selesai: " .. tostring(reason or "Selesai"))
    end
end

local function sellThisFishAll()
    if not JualIkanRemote then
        appendLog("[Sell] RemoteFish.JualIkanRemote tidak ditemukan.")
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
    local thisLoopId   = sellThisFishLoopId
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

            local ok, err = pcall(function()
                local args = { [1] = "Hand" }
                JualIkanRemote:FireServer(unpack(args))
            end)

            if not ok then
                appendLog("[Sell] Error JualIkanRemote(\"Hand\"): " .. tostring(err))
                finishSellThisFishLoop("Error Sell Hand")
                return
            else
                appendLog(string.format("[Sell] Sell Hand OK (%s) ke-%d", categoryName, i))
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
    [SellMode.Disable]      = "Disable",
    [SellMode.Kg1_10]       = "Sell 1–10 Kg",
    [SellMode.Kg0_100]      = "Sell 0–100 Kg",
    [SellMode.Kg100_200]    = "Sell 100–200 Kg",
    [SellMode.Kg300_500]    = "Sell 300–500 Kg",
    [SellMode.Kg500_1000]   = "Sell 500–1000 Kg",
    [SellMode.Kg1000_3000]  = "Sell 1000–3000 Kg",
    [SellMode.ThisFish]     = "Sell This Fish",
    [SellMode.AllFish]      = "Sell All Fish",
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
    notify("Indo Ocean - Sell Mode", name, 3)

    if mode ~= SellMode.ThisFish then
        sellThisFishLoopId += 1
        finishSellThisFishLoop("Mode berubah dari ThisFish")
    end

    updateSellProgressLabel()
end

local function applyAutoSellAfterCatch()
    if currentSellMode == SellMode.Disable then
        return
    elseif currentSellMode == SellMode.Kg1_10 then
        fireSellRange("1-10")
    elseif currentSellMode == SellMode.Kg0_100 then
        fireSellRange("0-100")
    elseif currentSellMode == SellMode.Kg100_200 then
        fireSellRange("100-200")
    elseif currentSellMode == SellMode.Kg300_500 then
        fireSellRange("300-500")
    elseif currentSellMode == SellMode.Kg500_1000 then
        fireSellRange("500-1000")
    elseif currentSellMode == SellMode.Kg1000_3000 then
        fireSellRange("1000-3000")
    elseif currentSellMode == SellMode.ThisFish then
        sellThisFishAll()
    elseif currentSellMode == SellMode.AllFish then
        fireSellRange("All")
    end
end

------------------- DROPDOWN FISH -------------------
local function buildFishDropdownItems()
    if not sellDropdownListFrame then return end

    for _, child in ipairs(sellDropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    dropdownItemButtons = {}

    -- Disable option
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
        btn.Text = string.format("%d ikan %s", initialCount, cname)

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn

        dropdownItemButtons[cname] = btn

        btn.MouseButton1Click:Connect(function()
            selectedFishCategory = cname
            currentDropdownKey   = cname

            if sellDropdownButton then
                local currentCount = countFishToolsInCategory(cname)
                sellDropdownButton.Text = string.format("%d ikan %s", currentCount, cname)
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
    scanBackpack()

    if #fishCategoryList == 0 then
        if sellDropdownButton then
            sellDropdownButton.Text = "Disable (Backpack kosong / fish tidak ditemukan)"
        end
        buildFishDropdownItems()
        return
    end

    buildFishDropdownItems()
end

------------------- OWNED ROD (DARI BACKPACK/CHAR/STARTERGEAR) -------------------
local function rescanOwnedRods()
    for _, key in ipairs(rodOptions) do
        ownedRodMap[key] = false
    end

    local function scan(container)
        if not container then return end
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Tool") then
                local key = rodNameToKey[inst.Name]
                if key then
                    ownedRodMap[key] = true
                end
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    local char     = LocalPlayer.Character
    local starter  = LocalPlayer:FindFirstChild("StarterGear")

    scan(backpack)
    scan(char)
    scan(starter)
end

local function refreshRodShopOwnedVisual()
    if not rodShopScroll then return end
    for toolKey, info in pairs(rodShopItems) do
        local owned = ownedRodMap[toolKey]
        local btn = info and info.buyButton
        if btn then
            if owned then
                btn.Text = "Owned"
                btn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            else
                if info.priceText then
                    btn.Text = info.priceText
                else
                    btn.Text = "Buy"
                end
                btn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
            end
        end
    end
end

local function watchRodContainer(container)
    if not container then return end

    container.ChildAdded:Connect(function(inst)
        if not alive then return end
        if inst:IsA("Tool") then
            local key = rodNameToKey[inst.Name]
            if key then
                ownedRodMap[key] = true
                refreshRodShopOwnedVisual()
            end
        end
    end)

    container.ChildRemoved:Connect(function(inst)
        if not alive then return end
        if inst:IsA("Tool") then
            local key = rodNameToKey[inst.Name]
            if key then
                rescanOwnedRods()
                refreshRodShopOwnedVisual()
            end
        end
    end)
end

local function initOwnedRodWatch()
    rescanOwnedRods()

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    watchRodContainer(backpack)

    if LocalPlayer.Character then
        watchRodContainer(LocalPlayer.Character)
    end

    local starter = LocalPlayer:FindFirstChild("StarterGear")
    watchRodContainer(starter)

    LocalPlayer.CharacterAdded:Connect(function(char)
        if not alive then return end
        watchRodContainer(char)
        rescanOwnedRods()
        refreshRodShopOwnedVisual()
    end)
end

------------------- ROD SHOP DATA & BUILD -------------------
local function getFormattedPriceString(entry)
    if not entry then
        return "Buy"
    end
    if entry.Type == "Cash" then
        local value = tonumber(entry.Price) or 0
        local s = tostring(math.floor(value))
        local formatted = s
        local k
        repeat
            formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        until k == 0
        return "Rp." .. formatted
    elseif entry.Type == "GamePass" then
        return "GamePass"
    end
    return "Buy"
end

local function buildRodShopUI()
    if not rodShopScroll or rodShopLoaded then return end
    rodShopLoaded = true

    -- Panggil GetShopData
    if GetShopDataRemote then
        local ok, res = pcall(function()
            return GetShopDataRemote:InvokeServer()
        end)
        if ok and type(res) == "table" then
            rodShopData = res
        else
            rodShopData = {}
        end
    end

    -- Bersihkan isi scroll
    for _, child in ipairs(rodShopScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    rodShopItems = {}

    for _, toolKey in ipairs(rodOptions) do
        local shopName = getShopNameFromTool(toolKey)
        local entry    = rodShopData[shopName]

        local row = Instance.new("Frame")
        row.Name = "RodRow_" .. toolKey
        row.Parent = rodShopScroll
        row.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        row.BackgroundTransparency = 0
        row.Size = UDim2.new(1, -4, 0, 64)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = row

        local pad = Instance.new("UIPadding")
        pad.Parent = row
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 4)
        pad.PaddingLeft = UDim.new(0, 6)
        pad.PaddingRight = UDim.new(0, 6)

        local img = Instance.new("ImageLabel")
        img.Name = "Icon"
        img.Parent = row
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, 52, 0, 52)
        img.Position = UDim2.new(0, 0, 0, 0)
        img.Image = entry and tostring(entry.ImageId or "") or ""
        img.ScaleType = Enum.ScaleType.Fit

        local imgCorner = Instance.new("UICorner")
        imgCorner.CornerRadius = UDim.new(0, 6)
        imgCorner.Parent = img

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "NameLabel"
        nameLbl.Parent = row
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.new(0, 60, 0, 2)
        nameLbl.Size = UDim2.new(1, -160, 0, 18)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextColor3 = Color3.fromRGB(220, 220, 235)
        nameLbl.Text = shopName

        local infoLbl = Instance.new("TextLabel")
        infoLbl.Name = "InfoLabel"
        infoLbl.Parent = row
        infoLbl.BackgroundTransparency = 1
        infoLbl.Position = UDim2.new(0, 60, 0, 22)
        infoLbl.Size = UDim2.new(1, -160, 0, 36)
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.TextSize = 11
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextYAlignment = Enum.TextYAlignment.Top
        infoLbl.TextWrapped = true
        infoLbl.TextColor3 = Color3.fromRGB(180, 200, 230)

        local minW, maxW, rarityText = "-", "-", "Common"
        if entry and entry.Stats and entry.Stats.WeightTiers then
            local tiers = entry.Stats.WeightTiers
            local minVal, maxVal = 999999, 0
            for _, t in pairs(tiers) do
                if t.MinWeight and t.MinWeight < minVal then
                    minVal = t.MinWeight
                end
                if t.MaxWeight and t.MaxWeight > maxVal then
                    maxVal = t.MaxWeight
                end
            end
            if minVal < 999999 then
                minW = tostring(minVal) .. " KG"
            end
            if maxVal > 0 then
                maxW = tostring(maxVal) .. " KG"
            end
        end

        if entry and entry.Stats and entry.Stats.Probabilities then
            local probs = entry.Stats.Probabilities
            local parts = {}
            local order = { "Mythical", "Legendary", "Epic", "Rare" }
            for _, key in ipairs(order) do
                local val = probs[key]
                if val and val > 0 then
                    table.insert(parts, key .. " " .. tostring(val) .. "%")
                end
            end
            if #parts > 0 then
                rarityText = table.concat(parts, " | ")
            end
        end

        infoLbl.Text = string.format("Min %s\nMax %s\n%s", minW, maxW, rarityText)

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyButton"
        buyBtn.Parent = row
        buyBtn.Size = UDim2.new(0, 90, 0, 26)
        buyBtn.Position = UDim2.new(1, -96, 0.5, -13)
        buyBtn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
        buyBtn.AutoButtonColor = true
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextSize = 12
        buyBtn.TextColor3 = Color3.fromRGB(235, 235, 245)

        local buyCorner = Instance.new("UICorner")
        buyCorner.CornerRadius = UDim.new(0, 6)
        buyCorner.Parent = buyBtn

        local priceText = getFormattedPriceString(entry)

        rodShopItems[toolKey] = {
            frame      = row,
            buyButton  = buyBtn,
            priceText  = priceText,
            shopName   = shopName,
            entry      = entry,
        }
    end

    refreshRodShopOwnedVisual()
end

------------------- HELPER: CARI MiniGame Rod (sesuai currentRodName) -------------------
local function getRodMiniGameForCurrent()
    local char = LocalPlayer.Character
    if not char then
        return nil, nil, "Character belum siap."
    end

    local candidates = {}

    -- 1) key langsung (NormalRod)
    table.insert(candidates, currentRodName)

    -- 2) versi spasi (Normal Rod)
    local spaced = currentRodName:gsub("(%l)(%u)", "%1 %2")
    if spaced ~= currentRodName then
        table.insert(candidates, spaced)
    end

    -- 3) shopName (Robot Rod, dsb)
    local shopName = getShopNameFromTool(currentRodName)
    if shopName ~= currentRodName and shopName ~= spaced then
        table.insert(candidates, shopName)
    end

    local rod
    for _, name in ipairs(candidates) do
        local inst = char:FindFirstChild(name)
        if inst and inst:IsA("Tool") then
            rod = inst
            break
        end
    end

    -- 4) Fallback: scan semua Tool di Character dan cocokkan via rodNameToKey
    if not rod then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then
                local key = rodNameToKey[inst.Name]
                if key == currentRodName then
                    rod = inst
                    break
                end
            end
        end
    end

    if not rod then
        return nil, nil, "Rod " .. tostring(currentRodName) .. " tidak ditemukan di Character."
    end

    local miniRemote = rod:FindFirstChild("MiniGame")
    if not miniRemote then
        return nil, rod.Name, tostring(rod.Name) .. ".MiniGame tidak ditemukan."
    end

    return miniRemote, rod.Name, nil
end

------------------- HELPER: REQUEST 1 FISH (MiniGame Complete dengan Rod dinamis) -------------------
local function requestOneFish()
    if not alive then return nil end

    local miniRemote, rodUsedName, errMsg = getRodMiniGameForCurrent()
    if not miniRemote then
        appendLog("[Fish] " .. tostring(errMsg))
        return nil
    end

    local ok, err = pcall(function()
        local args = { [1] = "Complete" }
        miniRemote:FireServer(unpack(args))
    end)

    if not ok then
        local msg = "Error MiniGame Complete: " .. tostring(err)
        warn("[IndoOcean] " .. msg)
        appendLog(msg)
        return nil
    end

    local fishName = "Fish (Complete)"
    if lastFishLabel then
        lastFishLabel.Text = "Last Fish: " .. fishName
    end

    appendLog("Got Fish via MiniGame: " .. fishName .. " (" .. tostring(rodUsedName or currentRodName) .. ")")

    applyAutoSellAfterCatch()

    return fishName
end

------------------- GET FISH INPUT (N KALI) -------------------
local function startGetFishInput()
    if not alive then return end

    local rawText = fishCountInputBox and fishCountInputBox.Text or ""
    local count   = tonumber(rawText)

    if not count or count <= 0 then
        notify("Indo Ocean", "Jumlah ikan tidak valid. Isi angka > 0.", 5)
        getFishInputEnabled = false
        updateToggleVisual(getFishInputToggleBtn, false)
        inputTargetCount  = 0
        inputCurrentCount = 0
        updateInputProgressLabel()
        return
    end

    notify("Indo Ocean", "Mulai Get Fish Input x" .. tostring(count), 4)

    currentInputTaskId = currentInputTaskId + 1
    local thisTaskId   = currentInputTaskId

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
            notify("Indo Ocean", "Get Fish Input selesai / berhenti.", 4)
        end
    end)
end

------------------- GET FISH NONSTOP (NO while) -------------------
local function scheduleNonstopStep(loopId)
    task.spawn(function()
        if not alive then return end
        if not getFishNonstopEnabled then return end
        if loopId ~= nonstopLoopId then return end

        requestOneFish()

        inputCurrentCount = inputCurrentCount + 1
        updateInputProgressLabel()

        task.wait(nonstopDelaySec)

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

    notify("Indo Ocean", "Get Fish Nonstop dimulai.", 4)
    scheduleNonstopStep(thisLoopId)
end

------------------- DROP MONEY LOGIC -------------------
local function dropCashOnce(amount)
    if not DropCashEvent then
        appendLog("[Drop] DropCashEvent tidak ditemukan.")
        return
    end
    if not amount or amount <= 0 then
        notify("Indo Ocean - Drop Money", "Nominal drop tidak valid (>0).", 4)
        return
    end

    local ok, err = pcall(function()
        local args = { [1] = amount }
        DropCashEvent:FireServer(unpack(args))
    end)

    if not ok then
        appendLog("[Drop] Error DropCash(" .. tostring(amount) .. "): " .. tostring(err))
    else
        appendLog("[Drop] DropCash(" .. tostring(amount) .. ") OK.")
    end
end

local function scheduleAutoDrop(loopType, loopId, amount)
    task.spawn(function()
        if not alive then return end
        if loopType == "10M" and (not autoDrop10MEnabled or loopId ~= autoDrop10MLoopId) then return end
        if loopType == "100M" and (not autoDrop100MEnabled or loopId ~= autoDrop100MLoopId) then return end
        if loopType == "1B" and (not autoDrop1BEnabled or loopId ~= autoDrop1BLoopId) then return end

        dropCashOnce(amount)

        local delaySec = math.random(DROP_DELAY_MIN, DROP_DELAY_MAX)
        task.wait(delaySec)

        if not alive then return end
        if loopType == "10M" and (not autoDrop10MEnabled or loopId ~= autoDrop10MLoopId) then return end
        if loopType == "100M" and (not autoDrop100MEnabled or loopId ~= autoDrop100MLoopId) then return end
        if loopType == "1B" and (not autoDrop1BEnabled or loopId ~= autoDrop1BLoopId) then return end

        scheduleAutoDrop(loopType, loopId, amount)
    end)
end

local function startAutoDrop10M()
    autoDrop10MLoopId += 1
    local thisId = autoDrop10MLoopId
    scheduleAutoDrop("10M", thisId, 10000000)
end

local function startAutoDrop100M()
    autoDrop100MLoopId += 1
    local thisId = autoDrop100MLoopId
    scheduleAutoDrop("100M", thisId, 100000000)
end

local function startAutoDrop1B()
    autoDrop1BLoopId += 1
    local thisId = autoDrop1BLoopId
    scheduleAutoDrop("1B", thisId, 1000000000)
end

------------------- ROD DROPDOWN BUILD -------------------
local function buildRodDropdownItems()
    if not rodDropdownListFrame then return end

    for _, child in ipairs(rodDropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    rodDropdownButtons = {}

    for _, rodName in ipairs(rodOptions) do
        local btn = Instance.new("TextButton")
        btn.Name = "Rod_" .. rodName
        btn.Parent = rodDropdownListFrame
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Text = rodName

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn

        rodDropdownButtons[rodName] = btn

        btn.MouseButton1Click:Connect(function()
            currentRodName = rodName
            if rodDropdownButton then
                rodDropdownButton.Text = rodName
            end
            if rodCurrentLabel then
                rodCurrentLabel.Text = "Current Rod: " .. rodName
            end

            for name, b in pairs(rodDropdownButtons) do
                if name == currentRodName then
                    b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                    b.TextColor3       = Color3.fromRGB(245, 245, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                    b.TextColor3       = Color3.fromRGB(220, 220, 230)
                end
            end

            rodDropdownListFrame.Visible = false
            rodDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)

            appendLog("[Rod] Current Rod diubah ke: " .. currentRodName)
        end)
    end

    -- highlight current
    for name, b in pairs(rodDropdownButtons) do
        if name == currentRodName then
            b.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            b.TextColor3       = Color3.fromRGB(245, 245, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            b.TextColor3       = Color3.fromRGB(220, 220, 230)
        end
    end
end

buildRodDropdownItems()
initOwnedRodWatch()
buildRodShopUI()

------------------- UI EVENTS -------------------
initFishDropdown()

-- Refresh button dropdown fish
if fishRefreshButton then
    fishRefreshButton.MouseButton1Click:Connect(function()
        if not alive then return end
        scanBackpack()
        buildFishDropdownItems()
        appendLog("[Dropdown] Manual Refresh Fish Dropdown (Backpack discan ulang).")
    end)
end

-- Buka dropdown Fish
if sellDropdownButton then
    sellDropdownButton.MouseButton1Click:Connect(function()
        if not sellDropdownListFrame then return end

        scanBackpack()
        buildFishDropdownItems()

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

-- Delay Nonstop input
if nonstopDelayInputBox then
    nonstopDelayInputBox.FocusLost:Connect(function()
        local raw = nonstopDelayInputBox.Text
        local v   = tonumber(raw)
        if not v or v <= 0 then
            nonstopDelaySec            = NONSTOP_DELAY_DEFAULT
            nonstopDelayInputBox.Text  = tostring(NONSTOP_DELAY_DEFAULT)
        else
            nonstopDelaySec = v
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
            notify("Indo Ocean", "Get Fish Input dimatikan oleh user.", 3)
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
            notify("Indo Ocean", "Get Fish Nonstop berhenti.", 4)
        end
    end)
end

if logToggleBtn then
    logToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end
        logRawEnabled = not logRawEnabled
        updateToggleVisual(logToggleBtn, logRawEnabled)
    end)
end

for mode, btn in pairs(sellModeButtons) do
    btn.MouseButton1Click:Connect(function()
        if not alive then return end
        setSellMode(mode)
        -- Klik tombol juga langsung eksekusi sekali (kecuali Disable)
        applyAutoSellAfterCatch()
    end)
end

setSellMode(SellMode.Disable)

-- Drop Money UI events
if dropInputBox then
    dropInputBox.FocusLost:Connect(function()
        local raw = dropInputBox.Text
        if raw == "" then
            return
        end
        local n = tonumber(raw)
        if not n or n <= 0 then
            dropInputBox.Text = ""
        end
    end)
end

if dropOnceButton then
    dropOnceButton.MouseButton1Click:Connect(function()
        if not alive then return end
        local raw = dropInputBox and dropInputBox.Text or ""
        local amount = tonumber(raw)
        if not amount or amount <= 0 then
            notify("Indo Ocean - Drop Money", "Masukkan nominal drop > 0.", 4)
            return
        end
        dropCashOnce(amount)
    end)
end

if autoDrop10MToggleBtn then
    autoDrop10MToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end
        autoDrop10MEnabled = not autoDrop10MEnabled
        updateToggleVisual(autoDrop10MToggleBtn, autoDrop10MEnabled)
        if autoDrop10MEnabled then
            startAutoDrop10M()
            notify("Indo Ocean - Drop Money", "Auto Drop 10 jt dimulai.", 3)
        else
            notify("Indo Ocean - Drop Money", "Auto Drop 10 jt dimatikan.", 3)
        end
    end)
end

if autoDrop100MToggleBtn then
    autoDrop100MToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end
        autoDrop100MEnabled = not autoDrop100MEnabled
        updateToggleVisual(autoDrop100MToggleBtn, autoDrop100MEnabled)
        if autoDrop100MEnabled then
            startAutoDrop100M()
            notify("Indo Ocean - Drop Money", "Auto Drop 100 jt dimulai.", 3)
        else
            notify("Indo Ocean - Drop Money", "Auto Drop 100 jt dimatikan.", 3)
        end
    end)
end

if autoDrop1BToggleBtn then
    autoDrop1BToggleBtn.MouseButton1Click:Connect(function()
        if not alive then return end
        autoDrop1BEnabled = not autoDrop1BEnabled
        updateToggleVisual(autoDrop1BToggleBtn, autoDrop1BEnabled)
        if autoDrop1BEnabled then
            startAutoDrop1B()
            notify("Indo Ocean - Drop Money", "Auto Drop 1 Miliar dimulai.", 3)
        else
            notify("Indo Ocean - Drop Money", "Auto Drop 1 Miliar dimatikan.", 3)
        end
    end)
end

-- Rod dropdown open/close
if rodDropdownButton and rodDropdownListFrame then
    rodDropdownButton.MouseButton1Click:Connect(function()
        if not alive then return end
        local open = not rodDropdownListFrame.Visible
        rodDropdownListFrame.Visible = open
        if open then
            rodDropdownListFrame.Size = UDim2.new(1, 0, 0, 160)
        else
            rodDropdownListFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end)
end

-- Rod Shop Buy events
for toolKey, info in pairs(rodShopItems) do
    local btn = info.buyButton
    if btn then
        btn.MouseButton1Click:Connect(function()
            if not alive then return end

            if ownedRodMap[toolKey] then
                notify("Rod Shop", toolKey .. " sudah Owned (dari Backpack).", 3)
                return
            end

            local shopName = info.shopName
            local entry    = info.entry

            if not (BuyItemRemote and shopName and entry) then
                notify("Rod Shop", "Data Rod/Remote tidak lengkap.", 3)
                return
            end

            if entry.Type == "GamePass" then
                MarketplaceService:PromptGamePassPurchase(LocalPlayer, entry.Price)
                return
            end

            local ok, result, errMsg = pcall(function()
                local s, err = BuyItemRemote:InvokeServer(shopName)
                return s, err
            end)

            if not ok then
                notify("Rod Shop", "Error BuyItem: " .. tostring(result), 4)
                appendLog("[RodShop] Error BuyItem(" .. tostring(shopName) .. "): " .. tostring(result))
                return
            end

            if result == "Success" then
                appendLog("[RodShop] Pembelian " .. tostring(shopName) .. " Success.")
                ownedRodMap[toolKey] = true
                rescanOwnedRods()
                refreshRodShopOwnedVisual()
            elseif result == "Failed" then
                notify("Rod Shop", "Gagal: " .. tostring(errMsg), 4)
                appendLog("[RodShop] Failed " .. tostring(shopName) .. ": " .. tostring(errMsg))
            elseif result == "PromptPurchase" then
                appendLog("[RodShop] PromptPurchase " .. tostring(shopName))
            end
        end)
    end
end

------------------- TAB CLEANUP -------------------
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    getFishInputEnabled   = false
    getFishNonstopEnabled = false
    isSellingThisFish     = false

    sellThisFishLoopId = sellThisFishLoopId + 1
    nonstopLoopId      = nonstopLoopId + 1

    autoDrop10MEnabled  = false
    autoDrop100MEnabled = false
    autoDrop1BEnabled   = false
    autoDrop10MLoopId   = autoDrop10MLoopId + 1
    autoDrop100MLoopId  = autoDrop100MLoopId + 1
    autoDrop1BLoopId    = autoDrop1BLoopId + 1

    if cashConn then
        cashConn:Disconnect()
        cashConn = nil
    end
end
