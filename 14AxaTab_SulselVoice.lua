--==========================================================
--  14AxaTab_SulselVoice.lua
--  TAB 14: "Sulsel Voice - Fish Giver V1"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "sulselvoice"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local TweenService      = TweenService      or game:GetService("TweenService")
local HttpService       = HttpService       or game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = UserInputService  or game:GetService("UserInputService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")

if not (frame and LocalPlayer) then return end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- CONSTANTS -------------------
local FALLBACK_HOOK_POSITION = Vector3.new(-915.7169, -3.85, 61.0641)
local HOOK_FORWARD_DISTANCE  = 60

local GET_FISH_DELAY   = 0.15
local SELL_BATCH_LIMIT = 150

-- Drop Money (MIN–MAX 10.000 – 10.000.000)
local MIN_DROP_AMOUNT   = 10000
local MAX_DROP_AMOUNT   = 10000000
local AUTO_DROP_AMOUNT  = 10000000
local MIN_DROP_COOLDOWN = 5       -- detik
local MAX_DROP_COOLDOWN = 8       -- detik

local FISH_NAME_OPTIONS = {
    "Disable",
    "Pumpkin Carved Shark",
    "Boar Fish",
    "Blackcap Basslet",
    "Ancient Relic Crocodile",
    "Ancient Whale",
    "BlueFish",
    "Colossal Squid",
    "Dead Scary Clownfish",
    "Dead Spooky Koi Fish",
    "Fangtooth",
    "Goliath Tiger",
    "Hermit Crab",
    "Jellyfish",
    "Kraken",
    "Lava Megalodon",
    "Lion Fish",
    "Loving Shark",
    "Luminous Fish",
    "Megalodon",
    "Monster Shark",
    "Naga Keramat",
    "Pink Dolphin",
    "Plasma Shark",
    "Queen Crab",
    "Wraithfin Abyssal",
    "Zombie Megalodon",
    "Zombie Shark",
}

------------------- FISH TABLE (untuk deskripsi & range rarity) -------------------
local FISH_TABLE = {
    { name = "BlueFish",              probability = 0.4,    minKg = 0.5,  maxKg = 50,    rarity = "Common"    },
    { name = "Boar Fish",             probability = 0.4,    minKg = 0.5,  maxKg = 50,    rarity = "Common"    },
    { name = "Blackcap Basslet",      probability = 0.5,    minKg = 0.5,  maxKg = 100,   rarity = "Common"    },
    { name = "Pumpkin Carved Shark",  probability = 0.5,    minKg = 0.5,  maxKg = 100,   rarity = "Common"    },
    { name = "Hermit Crab",           probability = 0.4,    minKg = 1,    maxKg = 100.5, rarity = "Common"    },
    { name = "Goliath Tiger",         probability = 0.4,    minKg = 1,    maxKg = 100.5, rarity = "Common"    },
    { name = "Fangtooth",             probability = 0.4,    minKg = 1,    maxKg = 100.5, rarity = "Common"    },

    { name = "StreakyFish",           probability = 0.4,    minKg = 10,   maxKg = 100,   rarity = "Uncommon"  },
    { name = "Dead Spooky Koi Fish",  probability = 0.4,    minKg = 10,   maxKg = 100,   rarity = "Uncommon"  },
    { name = "Dead Scary Clownfish",  probability = 0.34,   minKg = 10,   maxKg = 100,   rarity = "Uncommon"  },
    { name = "Jellyfish",             probability = 0.34,   minKg = 40,   maxKg = 100,   rarity = "Uncommon"  },

    { name = "Lion Fish",             probability = 0.1,    minKg = 20,   maxKg = 150,   rarity = "Rare"      },
    { name = "Luminous Fish",         probability = 0.1,    minKg = 20,   maxKg = 150,   rarity = "Rare"      },
    { name = "Zombie Shark",          probability = 0.0005, minKg = 50,   maxKg = 150,   rarity = "Rare"      },
    { name = "Wraithfin Abyssal",     probability = 0.1,    minKg = 20,   maxKg = 150,   rarity = "Rare"      },

    { name = "Loving Shark",          probability = 0.05,   minKg = 10,   maxKg = 300,   rarity = "Epic"      },
    { name = "Queen Crab",            probability = 0.05,   minKg = 10,   maxKg = 300,   rarity = "Epic"      },
    { name = "Pink Dolphin",          probability = 0.05,   minKg = 8,    maxKg = 300,   rarity = "Epic"      },

    { name = "Plasma Shark",          probability = 0.02,   minKg = 300,  maxKg = 450,   rarity = "Legendary" },
    { name = "Colossal Squid",        probability = 0.01,   minKg = 40,   maxKg = 450,   rarity = "Legendary" },

    { name = "Ancient Relic Crocodile", probability = 0.0005, minKg = 100,  maxKg = 500,  rarity = "Unknown"   },
    { name = "Ancient Whale",         probability = 0.0005, minKg = 400,  maxKg = 500,  rarity = "Unknown"   },
    { name = "Monster Shark",         probability = 0.0004, minKg = 400,  maxKg = 500,  rarity = "Unknown"   },
    { name = "Lava Megalodon",        probability = 1e-6,   minKg = 1000, maxKg = 1000, rarity = "Unknown"   },
    { name = "Megalodon",             probability = 0.00003,minKg = 900,  maxKg = 1000, rarity = "Unknown"   },
    { name = "Zombie Megalodon",      probability = 0.00001,minKg = 800,  maxKg = 900,  rarity = "Unknown"   },
    { name = "Kraken",                probability = 0.00003,minKg = 800,  maxKg = 850,  rarity = "Unknown"   },
    { name = "Naga Keramat",          probability = 1e-6,   minKg = 1000, maxKg = 1000, rarity = "Unknown"   },
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Unknown" }

------------------- ROD IMAGE MAP (SULSEL VOICE) -------------------
local ROD_IMAGE_MAP = {
    Rod                = "rbxassetid://0",
    DiamondRod         = "rbxassetid://102015657267184",
    DevilRod           = "rbxassetid://124051541965782",
    BebekRod           = "rbxassetid://101891337231830",
    PinkRodlv          = "rbxassetid://127955576842142",
    RodScytheDevil     = "rbxassetid://94880323171355",
    PoseidonWinterRod  = "rbxassetid://106024416728366",
    KristalPinkRod     = "rbxassetid://113333707885382",
    KingRod            = "rbxassetid://0",
    GoldRod            = "rbxassetid://0",
    RedFireRod         = "rbxassetid://0",
    KeyRod             = "rbxassetid://0",
    PinkRod            = "rbxassetid://0",
    ShadowRod          = "rbxassetid://0",
    RedKillRod         = "rbxassetid://0",
    HiuRod             = "rbxassetid://0",
    HiuRodRed          = "rbxassetid://0",
    FeatherRed         = "rbxassetid://0",
    HorizonRod         = "rbxassetid://0",
    PinkyNRod          = "rbxassetid://0",
    PinkNRod           = "rbxassetid://0",
    PoseidonRod        = "rbxassetid://0",
    RedShadowRod       = "rbxassetid://0",
    SwordRedRod        = "rbxassetid://0",
}

------------------- FORMATTERS -------------------
local function formatKg(num)
    if not num then return "?" end
    if math.floor(num) == num then
        return string.format("%d", num)
    else
        return string.format("%.1f", num)
    end
end

local function formatMoney(num)
    if type(num) ~= "number" then return "--" end
    num = math.floor(num)
    local s = tostring(num)
    local result = s
    while true do
        local replaced
        result, replaced = result:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if replaced == 0 then
            break
        end
    end
    return result
end

local function buildRarityOptions()
    local ranges = {}

    for _, fish in ipairs(FISH_TABLE) do
        local r, mn, mx = fish.rarity, fish.minKg, fish.maxKg
        if r and mn and mx then
            local info = ranges[r]
            if not info then
                ranges[r] = { minKg = mn, maxKg = mx }
            else
                if mn < info.minKg then info.minKg = mn end
                if mx > info.maxKg then info.maxKg = mx end
            end
        end
    end

    local labels = { "Disable" }
    local indexToValue = { [1] = "Disable" }

    for _, rarity in ipairs(RARITY_ORDER) do
        local info = ranges[rarity]
        local label
        if info then
            label = string.format("%s (%s - %s Kg)", rarity, formatKg(info.minKg), formatKg(info.maxKg))
        else
            label = rarity
        end
        table.insert(labels, label)
        indexToValue[#labels] = rarity
    end

    return labels, indexToValue
end

local RARITY_OPTIONS, RARITY_INDEX_TO_VALUE = buildRarityOptions()

------------------- REMOTES -------------------
local fishingSystem    = ReplicatedStorage:FindFirstChild("FishingSystem")
local fishGiverRemote  = fishingSystem and fishingSystem:FindFirstChild("FishGiver")
local sellFishRemote   = fishingSystem and fishingSystem:FindFirstChild("SellFish")

-- Drop Money (SESUAIKAN JIKA PATH BERBEDA)
local dropMoneyRemote = ReplicatedStorage:FindFirstChild("DropMoney")
if not dropMoneyRemote then
    local moneyFolder = ReplicatedStorage:FindFirstChild("MoneySystem")
        or ReplicatedStorage:FindFirstChild("EconomySystem")
    if moneyFolder then
        dropMoneyRemote = moneyFolder:FindFirstChild("DropMoney")
    end
end

-- Rod Shop (Sulsel Voice)
local rodShopFolder    = ReplicatedStorage:FindFirstChild("FishingRodShop")
local rodRequestRemote = rodShopFolder and rodShopFolder:FindFirstChild("RequestShopData")
local rodBuyRemote     = rodShopFolder and rodShopFolder:FindFirstChild("BuySkin")
local rodEquipRemote   = rodShopFolder and rodShopFolder:FindFirstChild("EquipSkin")

if not fishingSystem then
    warn("[18AxaTab_SulselVoice] FishingSystem tidak ditemukan.")
end
if not fishGiverRemote then
    warn("[18AxaTab_SulselVoice] Remote FishGiver tidak ditemukan.")
end
if not sellFishRemote then
    warn("[18AxaTab_SulselVoice] Remote SellFish tidak ditemukan.")
end
if not dropMoneyRemote then
    warn("[18AxaTab_SulselVoice] DropMoney remote tidak ditemukan, sesuaikan path.")
end
if not rodShopFolder or not rodRequestRemote or not rodBuyRemote or not rodEquipRemote then
    warn("[18AxaTab_SulselVoice] FishingRodShop remotes tidak lengkap (RequestShopData/BuySkin/EquipSkin).")
end

------------------- STATE -------------------
local alive                 = true

-- Get Fish
local getFishInputEnabled   = false
local getFishNonstopEnabled = false
local targetFishCount       = 0
local currentFishCount      = 0

local selectedFishNameIndex = 1
local selectedRarityIndex   = 1
local selectedWeightText    = ""

local workerRunning         = false

-- Sell
local fishInventoryCache    = {}   -- [name] = { {fishId, rarity, weight}, ... }
local sellNameOptions       = { "ALL" }
local selectedSellNameIndex = 1

-- UI refs
local progressLabel         = nil

-- Drop Money
local dropAmountText        = ""
local autoDropEnabled       = false
local cooldownEndTime       = 0     -- 0 = ready/no cooldown
local dropCountdownLabel    = nil
local dropLoopRunning       = false

-- Rod Shop UI ref
local rodScroll             = nil

------------------- HELPER: NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Sulsel Voice",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

------------------- HELPER UI -------------------
local function createMainLayout(parent)
    local main = Instance.new("Frame")
    main.Name = "SulselVoiceMain"
    main.Parent = parent
    main.Size = UDim2.new(1, 0, 1, 0)
    main.BackgroundTransparency = 1

    local padding = Instance.new("UIPadding")
    padding.Parent = main
    padding.PaddingTop    = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft   = UDim.new(0, 8)
    padding.PaddingRight  = UDim.new(0, 8)

    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Parent = main
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 16
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = Color3.fromRGB(240, 240, 240)
    header.Text = "Sulsel Voice - Fish Giver V1"

    local body = Instance.new("ScrollingFrame")
    body.Name = "BodyScroll"
    body.Parent = main
    body.Position = UDim2.new(0, 0, 0, 30)
    body.Size = UDim2.new(1, 0, 1, -30)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ScrollBarThickness = 4
    body.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    body.ScrollingDirection = Enum.ScrollingDirection.Y
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local layout = Instance.new("UIListLayout")
    layout.Parent = body
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    return main, body
end

local function createCard(parent, titleText)
    local card = Instance.new("Frame")
    card.Name = (titleText or "Card"):gsub(" ", "") .. "Card"
    card.Parent = parent
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, -4, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y

    local corner = Instance.new("UICorner")
    corner.Parent = card
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = card
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.8

    local padding = Instance.new("UIPadding")
    padding.Parent = card
    padding.PaddingTop    = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft   = UDim.new(0, 10)
    padding.PaddingRight  = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = card
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(235, 235, 235)
    title.Text = titleText or "Card"

    local inner = Instance.new("Frame")
    inner.Name = "Inner"
    inner.Parent = card
    inner.BackgroundTransparency = 1
    inner.Position = UDim2.new(0, 0, 0, 24)
    inner.Size = UDim2.new(1, 0, 0, 0)
    inner.AutomaticSize = Enum.AutomaticSize.Y

    local innerLayout = Instance.new("UIListLayout")
    innerLayout.Parent = inner
    innerLayout.FillDirection = Enum.FillDirection.Vertical
    innerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    innerLayout.Padding = UDim.new(0, 6)

    return card, inner
end

local function createToggleRow(parent, labelText, initialState, callback)
    local row = Instance.new("Frame")
    row.Name = labelText:gsub(" ", "") .. "Row"
    row.Parent = parent
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 22)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = labelText

    local button = Instance.new("TextButton")
    button.Parent = row
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    button.Size = UDim2.new(0.35, 0, 0.9, 0)
    button.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
    button.AutoButtonColor = false
    button.TextColor3 = Color3.fromRGB(240, 240, 240)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12

    local corner = Instance.new("UICorner")
    corner.Parent = button
    corner.CornerRadius = UDim.new(0, 8)

    local state = initialState and true or false
    local function render()
        if state then
            button.Text = "ON"
            button.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
        else
            button.Text = "OFF"
            button.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
        end
    end
    render()

    button.MouseButton1Click:Connect(function()
        state = not state
        render()
        if callback then
            task.spawn(callback, state)
        end
    end)

    return {
        row = row,
        setState = function(_, v)
            state = v and true or false
            render()
        end,
        getState = function() return state end,
    }
end

local function createInputRow(parent, labelText, placeholder, defaultValue, callback)
    local row = Instance.new("Frame")
    row.Name = labelText:gsub(" ", "") .. "InputRow"
    row.Parent = parent
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 24)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = labelText

    local box = Instance.new("TextBox")
    box.Parent = row
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.new(0.35, 0, 0.9, 0)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.TextColor3 = Color3.fromRGB(235, 235, 235)
    box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
    box.PlaceholderText = placeholder or ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.Text = defaultValue or ""
    box.ClearTextOnFocus = false

    local corner = Instance.new("UICorner")
    corner.Parent = box
    corner.CornerRadius = UDim.new(0, 8)

    box.FocusLost:Connect(function(enterPressed)
        if callback then
            task.spawn(callback, box.Text, enterPressed)
        end
    end)

    return {
        row = row,
        getText = function() return box.Text end,
        setText = function(_, txt) box.Text = txt or "" end,
    }
end

local function createDropdownRow(parent, labelText, options, initialIndex, callback)
    options = options or {}
    local index = initialIndex or 1

    local row = Instance.new("Frame")
    row.Name = labelText:gsub(" ", "") .. "DropdownRow"
    row.Parent = parent
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 24)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = labelText

    local button = Instance.new("TextButton")
    button.Parent = row
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, 0, 0.5, 0)
    button.Size = UDim2.new(0.35, 0, 0.9, 0)
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.AutoButtonColor = true

    local corner = Instance.new("UICorner")
    corner.Parent = button
    corner.CornerRadius = UDim.new(0, 8)

    local function render()
        button.Text = options[index] or "-"
    end
    render()

    button.MouseButton1Click:Connect(function()
        if #options == 0 then return end
        index = index + 1
        if index > #options then
            index = 1
        end
        render()
        if callback then
            task.spawn(callback, index, options[index])
        end
    end)

    return {
        row = row,
        getIndex = function() return index end,
        getValue = function() return options[index] end,
        setOptions = function(_, newOptions, newIndex)
            options = newOptions or {}
            if #options == 0 then
                index = 1
                button.Text = "-"
                return
            end
            index = math.clamp(newIndex or index or 1, 1, #options)
            render()
        end,
        setIndex = function(_, newIndex)
            if #options == 0 then return end
            index = math.clamp(newIndex or 1, 1, #options)
            render()
        end,
    }
end

local function createButtonRow(parent, labelText, buttonText, callback)
    local row = Instance.new("Frame")
    row.Name = labelText:gsub(" ", "") .. "ButtonRow"
    row.Parent = parent
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 24)

    local label = Instance.new("TextLabel")
    label.Parent = row
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = labelText

    local btn = Instance.new("TextButton")
    btn.Parent = row
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0.35, 0, 0.9, 0)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Text = buttonText or "Run"
    btn.AutoButtonColor = true

    local corner = Instance.new("UICorner")
    corner.Parent = btn
    corner.CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        if callback then
            task.spawn(callback)
        end
    end)

    return {
        row = row,
        button = btn,
    }
end

------------------- LOGIC: PROGRESS FISH LABEL -------------------
local function updateProgressLabel()
    if not progressLabel then return end

    local fishName = FISH_NAME_OPTIONS[selectedFishNameIndex] or "Any Fish"
    local modeText

    if getFishNonstopEnabled then
        modeText = string.format("Nonstop: %d %s", currentFishCount, fishName)
    elseif getFishInputEnabled and targetFishCount > 0 then
        modeText = string.format("Input: %d / %d %s", currentFishCount, targetFishCount, fishName)
    else
        modeText = "Idle"
    end

    progressLabel.Text = "Progress Fish: " .. modeText
end

------------------- LOGIC: DROP MONEY HELPERS -------------------
local function parseDropAmount(text)
    text = tostring(text or "")
    local digits = text:gsub("[^%d]", "")
    local num = tonumber(digits)
    if not num then return nil end
    num = math.clamp(num, MIN_DROP_AMOUNT, MAX_DROP_AMOUNT)
    return num
end

local function updateDropCountdownLabel()
    if not dropCountdownLabel then return end

    local now = tick()
    if cooldownEndTime > 0 and now < cooldownEndTime then
        local remaining = math.ceil(cooldownEndTime - now)
        dropCountdownLabel.Text = string.format("Drop Cooldown: %ds", remaining)
    else
        if autoDropEnabled then
            dropCountdownLabel.Text = "Drop Ready (Auto 10,000,000)"
        else
            dropCountdownLabel.Text = "Drop Ready"
        end
    end
end

local function performDropMoney(amount)
    amount = math.floor(amount or 0)
    if amount <= 0 then return end

    if not dropMoneyRemote then
        warn("[18AxaTab_SulselVoice] DropMoney remote tidak ditemukan, sesuaikan path.")
        notify("Drop Money", "Remote DropMoney tidak ditemukan.", 4)
        return
    end

    local ok, err = pcall(function()
        if dropMoneyRemote.FireServer then
            dropMoneyRemote:FireServer(amount)
        else
            dropMoneyRemote:InvokeServer(amount)
        end
    end)

    if not ok then
        warn("[18AxaTab_SulselVoice] DropMoney error:", err)
    end
end

local function ensureDropLoop()
    if not dropLoopRunning and (autoDropEnabled or (cooldownEndTime > 0)) then
        task.spawn(function()
            dropLoopRunning = true
            while alive and dropLoopRunning do
                local now = tick()

                if autoDropEnabled then
                    if cooldownEndTime == 0 or now >= cooldownEndTime then
                        performDropMoney(AUTO_DROP_AMOUNT)
                        cooldownEndTime = now + math.random(MIN_DROP_COOLDOWN, MAX_DROP_COOLDOWN)
                    end
                end

                if (not autoDropEnabled) and cooldownEndTime > 0 and now >= cooldownEndTime then
                    cooldownEndTime = 0
                end

                updateDropCountdownLabel()

                if (not autoDropEnabled) and cooldownEndTime == 0 then
                    break
                end

                task.wait(0.2)
            end
            dropLoopRunning = false
        end)
    else
        updateDropCountdownLabel()
    end
end

------------------- LOGIC: WEIGHT PARSER -------------------
local function parseWeight(text)
    text = tostring(text or ""):lower()
    local numStr = text:match("([%d%.]+)")
    local num = tonumber(numStr)
    if num and num > 0 then
        return num
    end
    return nil
end

------------------- LOGIC: HOOK POSITION DINAMIS -------------------
local function getDynamicHookPosition()
    local character = LocalPlayer.Character
    if not character then
        return FALLBACK_HOOK_POSITION
    end

    local root = character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")

    if not root then
        return FALLBACK_HOOK_POSITION
    end

    local forward = root.CFrame.LookVector
    local pos = root.Position + forward * HOOK_FORWARD_DISTANCE
    return Vector3.new(pos.X, pos.Y, pos.Z)
end

------------------- LOGIC: BUILD FISH REQUEST -------------------
local function buildFishRequest()
    if not fishGiverRemote then
        return nil, "FishGiver remote tidak ada"
    end

    local payload = {
        hookPosition = getDynamicHookPosition(),
    }

    local fishName = FISH_NAME_OPTIONS[selectedFishNameIndex] or "Disable"
    if fishName ~= "Disable" then
        payload.name = fishName
    end

    local rarityKey = RARITY_INDEX_TO_VALUE[selectedRarityIndex] or "Disable"
    if rarityKey ~= "Disable" then
        payload.rarity = rarityKey
    end

    local weightNumber = parseWeight(selectedWeightText)
    if weightNumber then
        payload.weight = weightNumber
    end

    return payload
end

local function requestOneFish()
    if not fishGiverRemote then return end

    local payload, err = buildFishRequest()
    if not payload then
        warn("[18AxaTab_SulselVoice] buildFishRequest gagal:", err)
        return
    end

    local args = { [1] = payload }

    local ok, e = pcall(function()
        fishGiverRemote:FireServer(unpack(args))
    end)

    if not ok then
        warn("[18AxaTab_SulselVoice] FishGiver FireServer error:", e)
    end
end

------------------- LOGIC: GET FISH WORKER -------------------
local function workerLoop()
    workerRunning = true

    while alive do
        local needWork =
            getFishNonstopEnabled
            or (getFishInputEnabled and targetFishCount > 0 and currentFishCount < targetFishCount)

        if not needWork then
            break
        end

        requestOneFish()
        currentFishCount += 1
        updateProgressLabel()

        if getFishInputEnabled
            and not getFishNonstopEnabled
            and targetFishCount > 0
            and currentFishCount >= targetFishCount
        then
            getFishInputEnabled = false
            notify("Get Fish Input", "Target tercapai: " .. tostring(targetFishCount) .. " ikan.", 4)
            updateProgressLabel()
            if not getFishNonstopEnabled then
                break
            end
        end

        task.wait(GET_FISH_DELAY)
    end

    workerRunning = false
end

local function ensureWorker()
    if not workerRunning and (getFishNonstopEnabled or getFishInputEnabled) then
        task.spawn(workerLoop)
    else
        updateProgressLabel()
    end
end

------------------- LOGIC: INVENTORY SCAN UNTUK SELL -------------------
local function extractFishInfoFromTool(tool)
    if not tool then return nil end
    local source = tool

    local idVal     = source:FindFirstChild("fishId") or source:FindFirstChild("FishId")
    local rarityVal = source:FindFirstChild("rarity") or source:FindFirstChild("Rarity")
    local weightVal = source:FindFirstChild("weight") or source:FindFirstChild("Weight")

    local fishId = idVal and idVal.Value or tool:GetAttribute("fishId") or tool:GetAttribute("FishId")
    local rarity = rarityVal and rarityVal.Value or tool:GetAttribute("rarity") or tool:GetAttribute("Rarity") or "Common"
    local weight = weightVal and weightVal.Value or tool:GetAttribute("weight") or tool:GetAttribute("Weight") or 1

    if not fishId then
        return nil
    end

    return {
        fishId = fishId,
        rarity = rarity,
        weight = weight,
        name   = tool.Name,
    }
end

local function rebuildFishInventory()
    table.clear(fishInventoryCache)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then
        notify("Sulsel Voice", "Backpack tidak ditemukan.", 3)
        return
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local info = extractFishInfoFromTool(tool)
            if info and info.fishId then
                local name = info.name or tool.Name
                if not fishInventoryCache[name] then
                    fishInventoryCache[name] = {}
                end
                table.insert(fishInventoryCache[name], {
                    fishId = info.fishId,
                    rarity = info.rarity,
                    weight = info.weight,
                })
            end
        end
    end

    table.clear(sellNameOptions)
    table.insert(sellNameOptions, "ALL")
    for name in pairs(fishInventoryCache) do
        table.insert(sellNameOptions, name)
    end

    if selectedSellNameIndex > #sellNameOptions then
        selectedSellNameIndex = 1
    end
end

local function buildSellBatchForName(targetName)
    local batch = {}

    if targetName == "ALL" then
        for _, list in pairs(fishInventoryCache) do
            for _, fish in ipairs(list) do
                table.insert(batch, {
                    fishId = fish.fishId,
                    rarity = fish.rarity,
                    weight = fish.weight,
                })
            end
        end
    else
        local list = fishInventoryCache[targetName]
        if list then
            for _, fish in ipairs(list) do
                table.insert(batch, {
                    fishId = fish.fishId,
                    rarity = fish.rarity,
                    weight = fish.weight,
                })
            end
        end
    end

    return batch
end

local function sellSingleByName(targetName)
    if not sellFishRemote then
        notify("Sell Single", "Remote SellFish tidak ditemukan.", 4)
        return
    end

    rebuildFishInventory()
    targetName = targetName or sellNameOptions[selectedSellNameIndex] or "ALL"

    local chosenList
    if targetName == "ALL" then
        for _, list in pairs(fishInventoryCache) do
            if #list > 0 then
                chosenList = list
                break
            end
        end
    else
        chosenList = fishInventoryCache[targetName]
    end

    if not chosenList or #chosenList == 0 then
        notify("Sell Single", "Tidak ada ikan yang cocok untuk dijual.", 4)
        return
    end

    local fish = chosenList[1]
    local args = {
        [1] = "SellSingle",
        [2] = {
            fishId = fish.fishId,
            rarity = fish.rarity,
            weight = fish.weight,
        }
    }

    local ok, err = pcall(function()
        sellFishRemote:FireServer(unpack(args))
    end)
    if not ok then
        warn("[18AxaTab_SulselVoice] SellSingle error:", err)
    end
end

local function sellAllByName(targetName)
    if not sellFishRemote then
        notify("Sell All", "Remote SellFish tidak ditemukan.", 4)
        return
    end

    rebuildFishInventory()
    targetName = targetName or sellNameOptions[selectedSellNameIndex] or "ALL"

    local batch = buildSellBatchForName(targetName)
    if #batch == 0 then
        notify("Sell All", "Tidak ada ikan yang bisa dijual.", 4)
        return
    end

    local index = 1
    while index <= #batch do
        local temp = {}
        local limit = math.min(index + SELL_BATCH_LIMIT - 1, #batch)
        for i = index, limit do
            table.insert(temp, batch[i])
        end
        index = limit + 1

        local args = {
            [1] = "SellAllBatch",
            [2] = temp
        }

        local ok, err = pcall(function()
            sellFishRemote:FireServer(unpack(args))
        end)
        if not ok then
            warn("[18AxaTab_SulselVoice] SellAllBatch error:", err)
        end

        task.wait(0.05)
    end

    notify("Sell All", "Permintaan jual dikirim (" .. tostring(#batch) .. " ikan).", 4)
end

------------------- ROD SHOP LOGIC -------------------
local function clearRodScroll()
    if not rodScroll then return end
    for _, child in ipairs(rodScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function createRodItemFrame(item)
    if not rodScroll or not item then return end

    local name        = item.Name or "Rod"
    local displayName = item.DisplayName or name
    local price       = item.Price
    local owned       = item.Owned
    local equipped    = item.Equipped
    local typeStr     = item.Type or "Money"

    local frame = Instance.new("Frame")
    frame.Name = name .. "RodItem"
    frame.Parent = rodScroll
    frame.Size = UDim2.new(1, -4, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    frame.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.Parent = frame
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = frame
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Transparency = 0.6

    if equipped then
        frame.BackgroundColor3 = Color3.fromRGB(40, 50, 80)
        stroke.Color = Color3.fromRGB(100, 200, 255)
        stroke.Transparency = 0.1
        stroke.Thickness = 2
    elseif owned then
        frame.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    end

    local img = Instance.new("ImageLabel")
    img.Name = "RodImage"
    img.Parent = frame
    img.BackgroundTransparency = 1
    img.Size = UDim2.new(0, 56, 0, 56)
    img.Position = UDim2.new(0, 6, 0.5, 0)
    img.AnchorPoint = Vector2.new(0, 0.5)
    img.Image = ROD_IMAGE_MAP[name] or "rbxassetid://0"
    img.ScaleType = Enum.ScaleType.Fit

    local textFrame = Instance.new("Frame")
    textFrame.Name = "TextFrame"
    textFrame.Parent = frame
    textFrame.BackgroundTransparency = 1
    textFrame.Position = UDim2.new(0, 70, 0, 4)
    textFrame.Size = UDim2.new(1, -150, 1, -8)

    local textLayout = Instance.new("UIListLayout")
    textLayout.Parent = textFrame
    textLayout.FillDirection = Enum.FillDirection.Vertical
    textLayout.SortOrder = Enum.SortOrder.LayoutOrder
    textLayout.Padding = UDim.new(0, 2)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Parent = textFrame
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 18)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
    nameLabel.Text = displayName

    local priceLabel = Instance.new("TextLabel")
    priceLabel.Parent = textFrame
    priceLabel.BackgroundTransparency = 1
    priceLabel.Size = UDim2.new(1, 0, 0, 16)
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.TextSize = 12
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.TextColor3 = Color3.fromRGB(180, 255, 180)

    if typeStr == "Money" and price then
        priceLabel.Text = "Price: " .. formatMoney(price) .. " Money"
    elseif typeStr == "Gamepass" and item.GamepassId then
        priceLabel.Text = "Gamepass ID: " .. tostring(item.GamepassId)
    else
        priceLabel.Text = "Price: -"
    end

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = textFrame
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, 0, 0, 16)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)

    if equipped then
        statusLabel.Text = "Status: Equipped"
    elseif owned then
        statusLabel.Text = "Status: Owned"
    else
        statusLabel.Text = "Status: Not Owned"
    end

    local btn = Instance.new("TextButton")
    btn.Name = "ActionButton"
    btn.Parent = frame
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, -8, 0.5, 0)
    btn.Size = UDim2.new(0, 90, 0, 30)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0

    local btnCorner = Instance.new("UICorner")
    btnCorner.Parent = btn
    btnCorner.CornerRadius = UDim.new(0, 8)

    if equipped then
        btn.Text = "EQUIPPED"
        btn.BackgroundColor3 = Color3.fromRGB(60, 150, 80)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.AutoButtonColor = false
        btn.Active = false
    elseif owned then
        btn.Text = "EQUIP"
        btn.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        btn.Text = "BUY NOW"
        btn.BackgroundColor3 = Color3.fromRGB(150, 80, 220)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    btn.MouseButton1Click:Connect(function()
        if equipped then
            return
        elseif owned then
            if not rodEquipRemote then
                notify("Rod Shop", "Remote EquipSkin tidak ditemukan.", 3)
                return
            end
            notify("Rod Shop", "Request Equip: " .. displayName, 3)
            pcall(function()
                rodEquipRemote:FireServer(name)
            end)
        else
            if not rodBuyRemote then
                notify("Rod Shop", "Remote BuySkin tidak ditemukan.", 3)
                return
            end
            notify("Rod Shop", "Request Buy: " .. displayName, 3)
            pcall(function()
                rodBuyRemote:FireServer(name)
            end)
        end

        task.delay(0.4, function()
            if alive then
                -- akan di-override oleh refreshRodShop yang didefinisikan di bawah (closure)
                -- tapi kita panggil via global lokal: refreshRodShop() akan ada di scope luar
            end
        end)
    end)

    return frame, btn
end

local refreshRodShop -- dideklarasi dulu, implement di bawah setelah UI dibuat

------------------- BUILD UI -------------------
local main, bodyScroll = createMainLayout(frame)

-- CARD: SULSEL VOICE - FISH GIVER V1 (GET CONTROLLER)
local getCard, getInner = createCard(bodyScroll, "Sulsel Voice - Fish Giver V1")

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Parent = getInner
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, 0, 0, 28)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.TextWrapped = true
infoLabel.Text = "Controller Get Fish: pilih Name, Rarity (dengan contoh min-max Kg), Weight opsional, lalu aktifkan Get Fish Input (target) atau Get Fish Nonstop."

local toggleGetInput
local toggleGetNonstop
local inputCount
local dropdownName
local dropdownRarity
local inputWeight

toggleGetInput = createToggleRow(getInner, "Get Fish Input (Target Count)", false, function(state)
    getFishInputEnabled = state
    currentFishCount = 0
    if state then
        getFishNonstopEnabled = false
        if toggleGetNonstop then
            toggleGetNonstop:setState(false)
        end
    end
    ensureWorker()
end)

inputCount = createInputRow(getInner, "Target Fish (1 - tak terbatas)", "contoh: 100", "", function(text)
    local num = tonumber(text)
    if num and num > 0 then
        targetFishCount = num
    else
        targetFishCount = 0
    end
    updateProgressLabel()
end)

toggleGetNonstop = createToggleRow(getInner, "Get Fish Nonstop", false, function(state)
    getFishNonstopEnabled = state
    if state then
        getFishInputEnabled = false
        if toggleGetInput then
            toggleGetInput:setState(false)
        end
    end
    ensureWorker()
end)

dropdownName = createDropdownRow(getInner, "Name Fish (Get Name Fish)", FISH_NAME_OPTIONS, selectedFishNameIndex, function(idx, value)
    selectedFishNameIndex = idx
    updateProgressLabel()
end)

dropdownRarity = createDropdownRow(getInner, "Rarity Fish (Get Rarity Fish)", RARITY_OPTIONS, selectedRarityIndex, function(idx, value)
    selectedRarityIndex = idx
end)

inputWeight = createInputRow(getInner, "Weight (Kg)", "contoh: 10, 10kg, 10 kg", "", function(text)
    selectedWeightText = text or ""
end)

progressLabel = Instance.new("TextLabel")
progressLabel.Name = "ProgressLabel"
progressLabel.Parent = getInner
progressLabel.BackgroundTransparency = 1
progressLabel.Size = UDim2.new(1, 0, 0, 20)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 12
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
progressLabel.Text = "Progress Fish: Idle"

------------------- CARD: SELL FISH CONTROLLER -------------------
local sellCard, sellInner = createCard(bodyScroll, "Sell Fish Controller")

createButtonRow(sellInner, "Fish Cache (Scan Backpack 1x)", "Refresh Cache", function()
    rebuildFishInventory()
    notify("Sulsel Voice", "Cache ikan diperbarui.", 3)
end)

local sellDropdown = createDropdownRow(sellInner, "Sell Name Fish", sellNameOptions, selectedSellNameIndex, function(idx, value)
    selectedSellNameIndex = idx
end)

createButtonRow(sellInner, "Sell Single Fish (Selected)", "Sell Single", function()
    local targetName = sellNameOptions[selectedSellNameIndex] or "ALL"
    sellSingleByName(targetName)
end)

createButtonRow(sellInner, "Sell All Fish (Selected)", "Sell All", function()
    local targetName = sellNameOptions[selectedSellNameIndex] or "ALL"
    sellAllByName(targetName)
end)

local function refreshSellDropdown()
    sellDropdown:setOptions(sellNameOptions, selectedSellNameIndex)
end

local _rebuild = rebuildFishInventory
rebuildFishInventory = function()
    _rebuild()
    refreshSellDropdown()
end

------------------- CARD: DROP MONEY CONTROLLER -------------------
local dropCard, dropInner = createCard(bodyScroll, "Drop Money Controller")

local dropInfo = Instance.new("TextLabel")
dropInfo.Name = "DropInfo"
dropInfo.Parent = dropInner
dropInfo.BackgroundTransparency = 1
dropInfo.Size = UDim2.new(1, 0, 0, 32)
dropInfo.Font = Enum.Font.Gotham
dropInfo.TextSize = 12
dropInfo.TextXAlignment = Enum.TextXAlignment.Left
dropInfo.TextYAlignment = Enum.TextYAlignment.Top
dropInfo.TextWrapped = true
dropInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
dropInfo.Text = "Drop Money Controller: isi jumlah drop (10.000 - 10.000.000) lalu tekan Drop, atau aktifkan Auto Drop (otomatis 10.000.000) dengan cooldown acak 15-30 detik."

createInputRow(dropInner, "Drop Money Amount", "10000 - 10000000", "", function(text)
    dropAmountText = text or ""
end)

createButtonRow(dropInner, "Manual Drop Money", "Drop", function()
    local amount = parseDropAmount(dropAmountText)
    if not amount then
        notify("Drop Money", "Masukkan jumlah 10000 - 10000000.", 4)
        return
    end

    local now = tick()
    if cooldownEndTime > 0 and now < cooldownEndTime then
        local remaining = math.ceil(cooldownEndTime - now)
        notify("Drop Money", "Masih cooldown " .. tostring(remaining) .. " detik.", 3)
        return
    end

    performDropMoney(amount)
    cooldownEndTime = now + math.random(MIN_DROP_COOLDOWN, MAX_DROP_COOLDOWN)
    ensureDropLoop()
end)

createToggleRow(dropInner, "Auto Drop 10000000", false, function(state)
    autoDropEnabled = state
    if autoDropEnabled and cooldownEndTime == 0 then
        cooldownEndTime = tick() + math.random(MIN_DROP_COOLDOWN, MAX_DROP_COOLDOWN)
    end
    ensureDropLoop()
end)

dropCountdownLabel = Instance.new("TextLabel")
dropCountdownLabel.Name = "DropCountdownLabel"
dropCountdownLabel.Parent = dropInner
dropCountdownLabel.BackgroundTransparency = 1
dropCountdownLabel.Size = UDim2.new(1, 0, 0, 20)
dropCountdownLabel.Font = Enum.Font.Gotham
dropCountdownLabel.TextSize = 12
dropCountdownLabel.TextXAlignment = Enum.TextXAlignment.Left
dropCountdownLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
dropCountdownLabel.Text = "Drop Ready"

------------------- CARD: SULSEL VOICE - ROD SHOP -------------------
local rodCard, rodInner = createCard(bodyScroll, "Sulsel Voice - Rod Shop")

local rodInfo = Instance.new("TextLabel")
rodInfo.Name = "RodInfo"
rodInfo.Parent = rodInner
rodInfo.BackgroundTransparency = 1
rodInfo.Size = UDim2.new(1, 0, 0, 32)
rodInfo.Font = Enum.Font.Gotham
rodInfo.TextSize = 12
rodInfo.TextXAlignment = Enum.TextXAlignment.Left
rodInfo.TextYAlignment = Enum.TextYAlignment.Top
rodInfo.TextWrapped = true
rodInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
rodInfo.Text = "Rod Shop: lihat list skin rod, harga, lalu BUY NOW atau EQUIP. Data diambil dari FishingRodShop (RequestShopData/BuySkin/EquipSkin)."

createButtonRow(rodInner, "Rod Shop Data", "Refresh Rod Shop", function()
    if refreshRodShop then
        refreshRodShop()
    end
end)

local rodListFrame = Instance.new("Frame")
rodListFrame.Name = "RodListFrame"
rodListFrame.Parent = rodInner
rodListFrame.BackgroundTransparency = 1
rodListFrame.Size = UDim2.new(1, 0, 0, 200)

rodScroll = Instance.new("ScrollingFrame")
rodScroll.Name = "RodShopScroll"
rodScroll.Parent = rodListFrame
rodScroll.BackgroundTransparency = 1
rodScroll.BorderSizePixel = 0
rodScroll.Position = UDim2.new(0, 0, 0, 0)
rodScroll.Size = UDim2.new(1, 0, 1, 0)
rodScroll.ScrollBarThickness = 4
rodScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
rodScroll.ScrollingDirection = Enum.ScrollingDirection.Y
rodScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
rodScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local rodListLayout = Instance.new("UIListLayout")
rodListLayout.Parent = rodScroll
rodListLayout.FillDirection = Enum.FillDirection.Vertical
rodListLayout.SortOrder = Enum.SortOrder.LayoutOrder
rodListLayout.Padding = UDim.new(0, 4)

-- Implementasi refreshRodShop sekarang (setelah rodScroll ada)
refreshRodShop = function()
    clearRodScroll()

    if not rodRequestRemote then
        local lbl = Instance.new("TextLabel")
        lbl.Parent = rodScroll
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -4, 0, 20)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(220, 180, 180)
        lbl.Text = "FishingRodShop remotes tidak lengkap (RequestShopData tidak ditemukan)."
        return
    end

    local ok, data = pcall(function()
        return rodRequestRemote:InvokeServer()
    end)

    if not ok or not data then
        local lbl = Instance.new("TextLabel")
        lbl.Parent = rodScroll
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -4, 0, 20)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(220, 180, 180)
        lbl.Text = "Gagal memuat data Rod Shop."
        warn("[18AxaTab_SulselVoice] RequestShopData error:", ok and "nil data" or data)
        return
    end

    if type(data) ~= "table" then
        local lbl = Instance.new("TextLabel")
        lbl.Parent = rodScroll
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -4, 0, 20)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(220, 180, 180)
        lbl.Text = "Format data Rod Shop tidak valid."
        return
    end

    -- sort: Equipped -> Owned -> Price ascending
    local list = {}
    for _, item in ipairs(data) do
        table.insert(list, item)
    end

    table.sort(list, function(a, b)
        if a.Equipped == b.Equipped then
            if a.Owned == b.Owned then
                return (a.Price or 999999999) < (b.Price or 999999999)
            else
                return a.Owned and not b.Owned
            end
        else
            return a.Equipped and not b.Equipped
        end
    end)

    for _, item in ipairs(list) do
        local _, btn = createRodItemFrame(item)
        if btn then
            btn.MouseButton1Click:Connect(function()
                -- override click supaya auto-refresh bener
                if item.Equipped then
                    return
                elseif item.Owned then
                    if not rodEquipRemote then
                        notify("Rod Shop", "Remote EquipSkin tidak ditemukan.", 3)
                        return
                    end
                    notify("Rod Shop", "Request Equip: " .. (item.DisplayName or item.Name or "Rod"), 3)
                    pcall(function()
                        rodEquipRemote:FireServer(item.Name)
                    end)
                else
                    if not rodBuyRemote then
                        notify("Rod Shop", "Remote BuySkin tidak ditemukan.", 3)
                        return
                    end
                    notify("Rod Shop", "Request Buy: " .. (item.DisplayName or item.Name or "Rod"), 3)
                    pcall(function()
                        rodBuyRemote:FireServer(item.Name)
                    end)
                end

                task.delay(0.5, function()
                    if alive then
                        refreshRodShop()
                    end
                end)
            end)
        end
    end
end

------------------- CARD: FISH TABLE DESKRIPSI -------------------
local tableCard, tableInner = createCard(bodyScroll, "Fish Table (Name / Rarity / Kg / Probability)")

local descLabel = Instance.new("TextLabel")
descLabel.Name = "DescLabel"
descLabel.Parent = tableInner
descLabel.BackgroundTransparency = 1
descLabel.Size = UDim2.new(1, 0, 0, 32)
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = 12
descLabel.TextXAlignment = Enum.TextXAlignment.Left
descLabel.TextYAlignment = Enum.TextYAlignment.Top
descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
descLabel.TextWrapped = true
descLabel.Text = "Ringkasan FishTable: setiap baris menampilkan Name, Rarity, range Kg (min-max), dan Probability."

local listFrame = Instance.new("Frame")
listFrame.Name = "FishTableListFrame"
listFrame.Parent = tableInner
listFrame.BackgroundTransparency = 1
listFrame.Size = UDim2.new(1, 0, 0, 160)

local listScroll = Instance.new("ScrollingFrame")
listScroll.Name = "FishTableScroll"
listScroll.Parent = listFrame
listScroll.BackgroundTransparency = 1
listScroll.BorderSizePixel = 0
listScroll.Position = UDim2.new(0, 0, 0, 0)
listScroll.Size = UDim2.new(1, 0, 1, 0)
listScroll.ScrollBarThickness = 4
listScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
listScroll.ScrollingDirection = Enum.ScrollingDirection.Y
listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = listScroll
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)

for _, fish in ipairs(FISH_TABLE) do
    local row = Instance.new("TextLabel")
    row.Name = fish.name .. "Row"
    row.Parent = listScroll
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, -4, 0, 18)
    row.Font = Enum.Font.Gotham
    row.TextSize = 11
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextColor3 = Color3.fromRGB(210, 210, 210)

    local probText = string.format("%.4f", (fish.probability or 0))
    row.Text = string.format(
        "%s | %s | %s - %s Kg | Prob: %s",
        fish.name,
        tostring(fish.rarity or "?"),
        formatKg(fish.minKg),
        formatKg(fish.maxKg),
        probText
    )
end

------------------- INITIAL SCAN & LABEL STATE -------------------
task.spawn(function()
    rebuildFishInventory()
end)

updateProgressLabel()
updateDropCountdownLabel()

-- Auto load rod shop sekali di awal (jika remote tersedia)
task.spawn(function()
    task.wait(0.2)
    if rodRequestRemote and refreshRodShop then
        refreshRodShop()
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    alive                 = false
    workerRunning         = false

    getFishInputEnabled   = false
    getFishNonstopEnabled = false
    targetFishCount       = 0
    currentFishCount      = 0
    selectedWeightText    = ""
    updateProgressLabel()

    table.clear(fishInventoryCache)
    sellNameOptions = { "ALL" }

    autoDropEnabled    = false
    cooldownEndTime    = 0
    dropLoopRunning    = false
    dropAmountText     = ""
    updateDropCountdownLabel()
end
