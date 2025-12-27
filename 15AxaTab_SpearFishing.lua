--==========================================================
--  15AxaTab_SpearFishing.lua
--  TAB 15: "Spear Fishing PRO++ (AutoFarm + Harpoon Shop + Basket Shop + Bait Shop + Auto Daily Reward)"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "spearfishing"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local TweenService      = TweenService      or game:GetService("TweenService")
local HttpService       = HttpService       or game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = UserInputService  or game:GetService("UserInputService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local VirtualInputManager = VirtualInputManager or game:GetService("VirtualInputManager")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

------------------- GLOBAL STATE / AXAHUB -------------------
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

local alive              = true
local autoFarm           = false      -- AutoFarm Fish v1: default OFF
local autoEquip          = false      -- AutoEquip Harpoon: default OFF
local autoFarmV2         = false      -- AutoFarm Fish V2 (tap trackpad): default OFF
local autoFarmV2Mode     = "Center"   -- "Left" / "Center"
local autoDailyReward    = false      -- Auto claim daily reward

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local backpack  = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")

local connections = {}

------------------- REMOTES (SPEAR FISHING / SHOP / DAILY) -------------------
local Remotes    = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE     = Remotes and Remotes:FindFirstChild("FireRE")     -- Fire harpoon
local ToolRE     = Remotes and Remotes:FindFirstChild("ToolRE")     -- Buy / Switch harpoon & basket
local FishRE     = Remotes and Remotes:FindFirstChild("FishRE")     -- Sell spear-fish
local BaitRE     = Remotes and Remotes:FindFirstChild("BaitRE")     -- Buy bait
local DailyRE    = Remotes and Remotes:FindFirstChild("DailyRE")    -- Daily reward

------------------- SAFE REQUIRE UTILITY / CONFIG MODULES -------------------
local UtilityFolder = ReplicatedStorage:FindFirstChild("Utility")
local ConfigFolder  = ReplicatedStorage:FindFirstChild("Config")

local function safeRequire(folder, name)
    if not folder then return nil end
    local obj = folder:FindFirstChild(name)
    if not obj then return nil end
    local ok, result = pcall(require, obj)
    if not ok then
        warn("[SpearFishing] Gagal require", name, ":", result)
        return nil
    end
    return result
end

local ItemUtil      = safeRequire(UtilityFolder, "ItemUtil")
local ToolUtil      = safeRequire(UtilityFolder, "ToolUtil")
local FormatUtil    = safeRequire(UtilityFolder, "Format")
local PurchaseUtil  = safeRequire(UtilityFolder, "PurchaseUtil")
local ColorUtil     = safeRequire(UtilityFolder, "ColorUtil")
local UIUtil        = safeRequire(UtilityFolder, "UIUtil")
local MathUtil      = safeRequire(UtilityFolder, "MathUtil")

local ResFishBasket  = safeRequire(ConfigFolder,  "ResFishBasket")   -- Luck/Frequency basket
local ResFishBait    = safeRequire(ConfigFolder,  "ResFishBait")     -- Bait config
local ResDailyReward = safeRequire(ConfigFolder,  "ResDailyReward")  -- Daily reward config

-- PlayerData Tools (untuk status Owned) - aman, tanpa infinite loop
local ToolsData
do
    local ok, has = pcall(function()
        return shared and shared.WaitPlayerData
    end)
    if ok and typeof(has) == "function" then
        local ok2, result = pcall(function()
            return shared.WaitPlayerData("Tools")
        end)
        if ok2 and result then
            ToolsData = result
        end
    end
end

-- PlayerData Daily untuk auto-claim
local DailyData
do
    local ok, has = pcall(function()
        return shared and shared.WaitPlayerData
    end)
    if ok and typeof(has) == "function" then
        local ok2, result = pcall(function()
            return shared.WaitPlayerData("Daily")
        end)
        if ok2 and result then
            DailyData = result
        end
    end
end

-- FishBaitShop object (stock + timer)
local FishBaitShop
do
    local gameFolder = ReplicatedStorage:FindFirstChild("Game")
    if gameFolder then
        FishBaitShop = gameFolder:FindFirstChild("FishBaitShop")
    end
end

------------------- HELPER: NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Spear Fishing",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

------------------- HARPOON & BASKET ID LIST -------------------
local HARPOON_IDS = {
    "Harpoon01",
    "Harpoon02",
    "Harpoon03",
    "Harpoon04",
    "Harpoon05",
    "Harpoon06",
    "Harpoon07",
    "Harpoon08",
    "Harpoon09",
    "Harpoon10",
    "Harpoon11",
    "Harpoon12",
    "Harpoon20",
    "Harpoon21",
}

local BASKET_IDS = {
    "FishBasket1",
    "FishBasket2",
    "FishBasket3",
    "FishBasket4",
    "FishBasket5",
    "FishBasket7",
    "FishBasket8",
}

local BAIT_IDS = { "Bait1", "Bait2", "Bait3", "Bait4", "Bait5" }

-- Beberapa harpoon/basket default sudah dimiliki (tidak perlu Buy)
local DEFAULT_HARPOON_OWNED = {
    Harpoon01 = true,
    Harpoon02 = true,
    Harpoon03 = true,
    Harpoon04 = true,
    Harpoon09 = true,
    Harpoon10 = true,
    Harpoon11 = true,
}

local DEFAULT_BASKET_OWNED = {
    FishBasket1 = true,
    FishBasket2 = true,
    FishBasket3 = true,
}

------------------- TOOL / HARPOON / BASKET DETECTION -------------------
local function isHarpoonTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool.Name:match("^Harpoon(%d+)$") ~= nil
end

local function isBasketTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool.Name:match("^FishBasket(%d+)$") ~= nil
end

local function getEquippedHarpoonTool()
    if not character then return nil end
    for _, child in ipairs(character:GetChildren()) do
        if isHarpoonTool(child) then
            return child
        end
    end
    return nil
end

local function getEquippedBasketTool()
    if not character then return nil end
    for _, child in ipairs(character:GetChildren()) do
        if isBasketTool(child) then
            return child
        end
    end
    return nil
end

local function getBestHarpoonTool()
    local bestTool, bestRank

    local function scanContainer(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if isHarpoonTool(tool) then
                local num = tonumber(tool.Name:match("^Harpoon(%d+)$")) or 0
                if (not bestRank) or num > bestRank then
                    bestRank = num
                    bestTool = tool
                end
            end
        end
    end

    scanContainer(character)
    scanContainer(backpack)

    return bestTool
end

local function ensureHarpoonEquipped()
    if not character then return end
    if getEquippedHarpoonTool() then return end

    local best = getBestHarpoonTool()
    if best then
        best.Parent = character
    end
end

local function isToolOwnedGeneric(id)
    -- via PlayerData Tools
    if ToolsData and ToolsData:FindFirstChild(id) then
        return true
    end

    -- Fallback: cek di Character / Backpack
    local function hasIn(container)
        if not container then return false end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == id then
                return true
            end
        end
        return false
    end

    if hasIn(character) or hasIn(backpack) then
        return true
    end

    return false
end

local function isHarpoonOwned(id)
    if DEFAULT_HARPOON_OWNED[id] then
        return true
    end
    return isToolOwnedGeneric(id)
end

local function isBasketOwned(id)
    if DEFAULT_BASKET_OWNED[id] then
        return true
    end
    return isToolOwnedGeneric(id)
end

local function requestToolSwitch(id)
    if not ToolRE then
        notify("Spear Fishing", "Remote ToolRE tidak ditemukan.", 4)
        return
    end
    local ok, err = pcall(function()
        ToolRE:FireServer("Switch", { ID = id })
    end)
    if not ok then
        warn("[SpearFishing] ToolRE:Switch gagal:", err)
        notify("Spear Fishing", "Gagal mengirim request Equip, cek Output.", 4)
    end
end

------------------- UI HELPERS (TAHOE STYLE LIGHT) -------------------
local harpoonCardsById = {}  -- id -> {frame, actionButton, assetType}
local basketCardsById  = {}  -- id -> {frame, actionButton, assetType}
local baitCardsById    = {}  -- id -> {frame, button, id}
local dailyCardsByIdx  = {}  -- idx -> {frame, button, claimedLabel}

local function createMainLayout()
    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Parent = frame
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    header.BackgroundTransparency = 0.1
    header.BorderSizePixel = 0
    header.Position = UDim2.new(0, 8, 0, 8)
    header.Size = UDim2.new(1, -16, 0, 46)

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    local headerStroke = Instance.new("UIStroke")
    headerStroke.Thickness = 1
    headerStroke.Color = Color3.fromRGB(70, 70, 70)
    headerStroke.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = header
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Position = UDim2.new(0, 14, 0, 4)
    title.Size = UDim2.new(1, -28, 0, 20)
    title.Text = "Spear Fishing V1"

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Parent = header
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    subtitle.Position = UDim2.new(0, 14, 0, 22)
    subtitle.Size = UDim2.new(1, -28, 0, 18)
    subtitle.Text = "AutoFarm Spear v1 + v2 (Trackpad) + AutoEquip + Harpoon/Basket/Bait Shop + Auto Daily Reward"

    -- Body scroll (vertical)
    local bodyScroll = Instance.new("ScrollingFrame")
    bodyScroll.Name = "BodyScroll"
    bodyScroll.Parent = frame
    bodyScroll.BackgroundTransparency = 1
    bodyScroll.BorderSizePixel = 0
    bodyScroll.Position = UDim2.new(0, 8, 0, 62)
    bodyScroll.Size = UDim2.new(1, -16, 1, -70)
    bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    bodyScroll.ScrollBarThickness = 4
    bodyScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local padding = Instance.new("UIPadding")
    padding.Parent = bodyScroll
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 0)
    padding.PaddingRight = UDim.new(0, 0)

    local layout = Instance.new("UIListLayout")
    layout.Parent = bodyScroll
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        bodyScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end)
    table.insert(connections, conn)

    return header, bodyScroll
end

local function createCard(parent, titleText, subtitleText, layoutOrder, height)
    height = height or 140

    local card = Instance.new("Frame")
    card.Name = (titleText or "Card")
    card.Parent = parent
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, height)
    card.LayoutOrder = layoutOrder or 1

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 70)
    stroke.Thickness = 1
    stroke.Parent = card

    local padding = Instance.new("UIPadding")
    padding.Parent = card
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = card
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = titleText or "Card"
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Size = UDim2.new(1, 0, 0, 18)

    local subtitle
    if subtitleText and subtitleText ~= "" then
        subtitle = Instance.new("TextLabel")
        subtitle.Name = "Subtitle"
        subtitle.Parent = card
        subtitle.BackgroundTransparency = 1
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextSize = 12
        subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.TextWrapped = true
        subtitle.Text = subtitleText
        subtitle.Position = UDim2.new(0, 0, 0, 20)
        subtitle.Size = UDim2.new(1, 0, 0, 26)
    end

    return card, title, subtitle
end

local function createToggleButton(parent, labelText, initialState)
    local button = Instance.new("TextButton")
    button.Name = (labelText or "Toggle"):gsub("%s+", "") .. "Button"
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextXAlignment = Enum.TextXAlignment.Center
    button.TextYAlignment = Enum.TextYAlignment.Center
    button.Size = UDim2.new(1, 0, 0, 30)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local function update(state)
        if state then
            button.Text = (labelText or "Toggle") .. ": ON"
            button.BackgroundColor3 = Color3.fromRGB(45, 120, 75)
        else
            button.Text = (labelText or "Toggle") .. ": OFF"
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end

    update(initialState)

    return button, update
end

------------------- AUTO FARM V1 (FIRE HARPOON) -------------------
local lastShotClock = 0
local FIRE_INTERVAL = 0.35  -- detik antar tembakan

local function doFireHarpoon()
    if not alive or not autoFarm then return end
    if not FireRE then return end
    if not character then return end

    local now = os.clock()
    if now - lastShotClock < FIRE_INTERVAL then
        return
    end
    lastShotClock = now

    -- Pastikan harpoon ter-equip
    local harpoon = getEquippedHarpoonTool()
    if (not harpoon) and autoEquip then
        ensureHarpoonEquipped()
        harpoon = getEquippedHarpoonTool()
    end
    if not harpoon then
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    -- Aim mengikuti pusat GunAim UI (center screen -> ScreenPointToRay)
    local viewport = camera.ViewportSize
    local centerX, centerY = viewport.X / 2, viewport.Y / 2

    local ray = camera:ScreenPointToRay(centerX, centerY, 0)
    local origin = ray.Origin
    local direction = ray.Direction

    local destination = origin + direction * 300

    local ok, err = pcall(function()
        FireRE:FireServer("Fire", {
            cameraOrigin = origin,
            player       = LocalPlayer,
            toolInstance = harpoon,
            destination  = destination,
            isCharge     = false
        })
    end)
    if not ok then
        warn("[SpearFishing] FireRE:FireServer gagal:", err)
    end
end

------------------- AUTO FARM V2 (TAP TRACKPAD LEFT/CENTER) -------------------
local lastTapClock = 0
local TAP_INTERVAL = 0.35

local function getTapPositionForMode(mode)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local v = camera.ViewportSize
    local y = v.Y * 0.8 -- dekat bawah layar (area trackpad)
    local x
    if mode == "Left" then
        x = v.X * 0.3
    else
        -- default Center
        x = v.X * 0.5
    end
    return Vector2.new(x, y)
end

local function tapScreenPosition(pos)
    if not pos or not VirtualInputManager then return end

    -- Jangan ganggu kalau sedang mengetik di chat / TextBox lain
    if UserInputService:GetFocusedTextBox() then
        return
    end

    local x, y = pos.X, pos.Y

    if isTouch then
        -- Mobile / HP (touch)
        pcall(function()
            VirtualInputManager:SendTouchEvent(x, y, 0, true, workspace.CurrentCamera, 0)
            VirtualInputManager:SendTouchEvent(x, y, 0, false, workspace.CurrentCamera, 0)
        end)
    else
        -- PC / Laptop / Mac (mouse/trackpad)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end
end

local function doAutoTapV2()
    if not alive or not autoFarmV2 then return end

    local now = os.clock()
    if now - lastTapClock < TAP_INTERVAL then
        return
    end
    lastTapClock = now

    local pos = getTapPositionForMode(autoFarmV2Mode)
    if not pos then return end

    tapScreenPosition(pos)
end

------------------- SELL ALL FISH (SPEAR FISHING) -------------------
local lastSellClock = 0
local SELL_COOLDOWN = 2

local function sellAllFish()
    if not FishRE then
        notify("Spear Fishing", "Remote FishRE tidak ditemukan.", 4)
        return
    end

    local now = os.clock()
    if now - lastSellClock < SELL_COOLDOWN then
        notify("Spear Fishing", "Sell All terlalu cepat, tunggu beberapa detik.", 2)
        return
    end
    lastSellClock = now

    local ok, err = pcall(function()
        FishRE:FireServer("SellAll")
    end)

    if ok then
        notify("Spear Fishing", "Sell All Fish request dikirim.", 3)
    else
        warn("[SpearFishing] SellAll gagal:", err)
        notify("Spear Fishing", "Sell All gagal, cek Output/Console.", 4)
    end
end

------------------- HARPOON SHOP: DATA & UI -------------------
local function getHarpoonDisplayData(id)
    local name      = id
    local icon      = ""
    local dmgMin    = "-"
    local dmgMax    = "-"
    local crt       = "-"
    local charge    = "-"
    local priceText = "N/A"
    local assetType = "Currency"

    if ItemUtil then
        local okName, resName = pcall(function()
            return ItemUtil:getName(id)
        end)
        if okName and resName then
            name = resName
        end

        local okIcon, resIcon = pcall(function()
            return ItemUtil:getIcon(id)
        end)
        if okIcon and resIcon then
            icon = resIcon
        end

        local okDef, def = pcall(function()
            return ItemUtil:GetDef(id)
        end)
        if okDef and def and def.AssetType then
            assetType = def.AssetType
        end

        local okPrice, priceVal = pcall(function()
            return ItemUtil:getPrice(id)
        end)
        if okPrice and priceVal then
            if FormatUtil then
                local okFmt, fmtText = pcall(function()
                    return FormatUtil:DesignNumberShort(priceVal)
                end)
                if okFmt and fmtText then
                    priceText = fmtText
                else
                    priceText = tostring(priceVal)
                end
            else
                priceText = tostring(priceVal)
            end
        end
    end

    if ToolUtil then
        local okDmg, minVal, maxVal = pcall(function()
            return ToolUtil:getHarpoonDMG(id)
        end)
        if okDmg and minVal and maxVal then
            dmgMin = tostring(minVal)
            dmgMax = tostring(maxVal)
        end

        local okCharge, chargeVal = pcall(function()
            return ToolUtil:getHarpoonChargeTime(id)
        end)
        if okCharge and chargeVal then
            charge = tostring(chargeVal) .. "s"
        end

        local okCRT, crtVal = pcall(function()
            return ToolUtil:getToolCRT(id)
        end)
        if okCRT and crtVal then
            crt = tostring(crtVal) .. "%"
        end
    end

    return {
        name      = name,
        icon      = icon,
        dmgMin    = dmgMin,
        dmgMax    = dmgMax,
        crt       = crt,
        charge    = charge,
        priceText = priceText,
        assetType = assetType,
    }
end

local function refreshHarpoonOwnership()
    local equippedTool = getEquippedHarpoonTool()
    local equippedName = equippedTool and equippedTool.Name or nil

    for id, entry in pairs(harpoonCardsById) do
        local btn = entry.actionButton
        if btn then
            local owned    = isHarpoonOwned(id)
            local equipped = owned and (equippedName == id)

            if not owned then
                btn.Text = "Buy"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.TextColor3 = Color3.fromRGB(235, 235, 235)
                btn.AutoButtonColor = true
            else
                if equipped then
                    btn.Text = "EQUIPPED"
                    btn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
                    btn.TextColor3 = Color3.fromRGB(255, 230, 230)
                    btn.AutoButtonColor = false
                else
                    btn.Text = "EQUIP"
                    btn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
                    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                    btn.AutoButtonColor = true
                end
            end
        end
    end
end

local function buildHarpoonShopCard(parent)
    local card, _, _ = createCard(
        parent,
        "Harpoon Shop",
        "Toko Harpoon (Image + DMG + CRT + Charge + Price + Equip).",
        2,
        280
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "HarpoonScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 40)
    scroll.Size = UDim2.new(1, 0, 1, -48)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 8, 0, 0)
    end)
    table.insert(connections, conn)

    for index, id in ipairs(HARPOON_IDS) do
        local data = getHarpoonDisplayData(id)

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 160, 0, 210)
        item.LayoutOrder = index

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 70)
        stroke.Thickness = 1
        stroke.Parent = item

        local img = Instance.new("ImageLabel")
        img.Name = "Icon"
        img.Parent = item
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.Position = UDim2.new(0, 6, 0, 6)
        img.Size = UDim2.new(1, -12, 0, 80)
        img.Image = data.icon or ""
        img.ScaleType = Enum.ScaleType.Fit

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = item
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.Position = UDim2.new(0, 6, 0, 90)
        nameLabel.Size = UDim2.new(1, -12, 0, 16)
        nameLabel.Text = data.name or id

        local stats = Instance.new("TextLabel")
        stats.Name = "Stats"
        stats.Parent = item
        stats.BackgroundTransparency = 1
        stats.Font = Enum.Font.Gotham
        stats.TextSize = 11
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.TextYAlignment = Enum.TextYAlignment.Top
        stats.TextColor3 = Color3.fromRGB(190, 190, 190)
        stats.TextWrapped = true
        stats.Position = UDim2.new(0, 6, 0, 108)
        stats.Size = UDim2.new(1, -12, 0, 64)
        stats.Text = string.format(
            "DMG: %s~%s\nCRT: %s\nCharge: %s\nPrice: %s",
            tostring(data.dmgMin),
            tostring(data.dmgMax),
            tostring(data.crt),
            tostring(data.charge),
            tostring(data.priceText)
        )

        local actionBtn = Instance.new("TextButton")
        actionBtn.Name = "ActionButton"
        actionBtn.Parent = item
        actionBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        actionBtn.BorderSizePixel = 0
        actionBtn.AutoButtonColor = true
        actionBtn.Font = Enum.Font.GothamSemibold
        actionBtn.TextSize = 12
        actionBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        actionBtn.Text = "Buy"
        actionBtn.Position = UDim2.new(0, 6, 1, -32)
        actionBtn.Size = UDim2.new(1, -12, 0, 26)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = actionBtn

        harpoonCardsById[id] = {
            frame        = item,
            actionButton = actionBtn,
            assetType    = data.assetType or "Currency",
        }

        local function onAction()
            local owned = isHarpoonOwned(id)
            if owned then
                requestToolSwitch(id)
                task.delay(0.6, function()
                    if alive then
                        refreshHarpoonOwnership()
                    end
                end)
                return
            end

            if not ToolRE then
                notify("Spear Fishing", "Remote ToolRE tidak ditemukan.", 4)
                return
            end

            local assetType = (harpoonCardsById[id] and harpoonCardsById[id].assetType) or "Currency"

            if assetType == "Robux" and PurchaseUtil then
                local ok, err = pcall(function()
                    PurchaseUtil:getPurchase(id)
                end)
                if not ok then
                    warn("[SpearFishing] PurchaseUtil:getPurchase gagal:", err)
                    notify("Spear Fishing", "Gagal membuka purchase Robux.", 4)
                end
            else
                local ok, err = pcall(function()
                    ToolRE:FireServer("Buy", { ID = id })
                end)

                if ok then
                    notify("Spear Fishing", "Request beli " .. (data.name or id) .. " dikirim.", 4)
                    task.delay(0.7, function()
                        if alive then
                            refreshHarpoonOwnership()
                        end
                    end)
                else
                    warn("[SpearFishing] ToolRE:Buy gagal:", err)
                    notify("Spear Fishing", "Gagal mengirim request beli, cek Output.", 4)
                end
            end
        end

        local connBtn = actionBtn.MouseButton1Click:Connect(onAction)
        table.insert(connections, connBtn)
    end

    refreshHarpoonOwnership()

    if ToolsData then
        local c1 = ToolsData.AttributeChanged:Connect(refreshHarpoonOwnership)
        local c2 = ToolsData.ChildAdded:Connect(refreshHarpoonOwnership)
        local c3 = ToolsData.ChildRemoved:Connect(refreshHarpoonOwnership)
        table.insert(connections, c1)
        table.insert(connections, c2)
        table.insert(connections, c3)
    end

    return card
end

------------------- BASKET SHOP: DATA & UI -------------------
local function getBasketConfig(id)
    if not ResFishBasket or type(ResFishBasket) ~= "table" then
        return nil
    end

    -- Coba akses langsung dengan key string
    if type(ResFishBasket[id]) == "table" then
        return ResFishBasket[id]
    end

    -- Pola umum: __index = { "FishBasket1", ... }, dan data di indeks numerik
    local idxList = ResFishBasket.__index
    if type(idxList) == "table" then
        for i, key in pairs(idxList) do
            if key == id then
                local cfg = ResFishBasket[i]
                if type(cfg) == "table" then
                    return cfg
                end
                break
            end
        end
    end

    return nil
end

local function getBasketDisplayData(id)
    local name      = id
    local icon      = ""
    local luck      = "-"
    local frequency = "-"
    local priceText = "N/A"
    local assetType = "Currency"

    if ItemUtil then
        local okName, resName = pcall(function()
            return ItemUtil:getName(id)
        end)
        if okName and resName then
            name = resName
        end

        local okIcon, resIcon = pcall(function()
            return ItemUtil:getIcon(id)
        end)
        if okIcon and resIcon then
            icon = resIcon
        end

        local okDef, def = pcall(function()
            return ItemUtil:GetDef(id)
        end)
        if okDef and def and def.AssetType then
            assetType = def.AssetType
        end

        local okPrice, priceVal = pcall(function()
            return ItemUtil:getPrice(id)
        end)
        if okPrice and priceVal then
            if FormatUtil then
                local okFmt, fmtText = pcall(function()
                    return FormatUtil:DesignNumberShort(priceVal)
                end)
                if okFmt and fmtText then
                    priceText = fmtText
                else
                    priceText = tostring(priceVal)
                end
            else
                priceText = tostring(priceVal)
            end
        end
    end

    -- Ambil Luck & Frequency dari ResFishBasket jika tersedia
    local cfg = getBasketConfig(id)
    if cfg and type(cfg) == "table" then
        if cfg.Luck ~= nil then
            luck = tostring(cfg.Luck)
        elseif cfg.luck ~= nil then
            luck = tostring(cfg.luck)
        end

        if cfg.Frequency ~= nil then
            frequency = tostring(cfg.Frequency) .. "s"
        elseif cfg.Freq ~= nil then
            frequency = tostring(cfg.Freq) .. "s"
        elseif cfg.Time ~= nil then
            frequency = tostring(cfg.Time) .. "s"
        elseif cfg.Cooldown ~= nil then
            frequency = tostring(cfg.Cooldown) .. "s"
        end
    end

    return {
        name      = name,
        icon      = icon,
        luck      = luck,
        frequency = frequency,
        priceText = priceText,
        assetType = assetType,
    }
end

local function refreshBasketOwnership()
    local equippedTool = getEquippedBasketTool()
    local equippedName = equippedTool and equippedTool.Name or nil

    for id, entry in pairs(basketCardsById) do
        local btn = entry.actionButton
        if btn then
            local owned    = isBasketOwned(id)
            local equipped = owned and (equippedName == id)

            if not owned then
                btn.Text = "Buy"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.TextColor3 = Color3.fromRGB(235, 235, 235)
                btn.AutoButtonColor = true
            else
                if equipped then
                    btn.Text = "EQUIPPED"
                    btn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
                    btn.TextColor3 = Color3.fromRGB(255, 230, 230)
                    btn.AutoButtonColor = false
                else
                    btn.Text = "EQUIP"
                    btn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
                    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                    btn.AutoButtonColor = true
                end
            end
        end
    end
end

local function buildBasketShopCard(parent)
    local card, _, _ = createCard(
        parent,
        "Basket Shop",
        "Toko Basket (Icon + Luck + Frequency + Price + Equip).",
        3,
        280
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "BasketScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 40)
    scroll.Size = UDim2.new(1, 0, 1, -48)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 8, 0, 0)
    end)
    table.insert(connections, conn)

    for index, id in ipairs(BASKET_IDS) do
        local data = getBasketDisplayData(id)

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 160, 0, 210)
        item.LayoutOrder = index

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 70)
        stroke.Thickness = 1
        stroke.Parent = item

        local img = Instance.new("ImageLabel")
        img.Name = "Icon"
        img.Parent = item
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.Position = UDim2.new(0, 6, 0, 6)
        img.Size = UDim2.new(1, -12, 0, 80)
        img.Image = data.icon or ""
        img.ScaleType = Enum.ScaleType.Fit

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = item
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.Position = UDim2.new(0, 6, 0, 90)
        nameLabel.Size = UDim2.new(1, -12, 0, 16)
        nameLabel.Text = data.name or id

        local stats = Instance.new("TextLabel")
        stats.Name = "Stats"
        stats.Parent = item
        stats.BackgroundTransparency = 1
        stats.Font = Enum.Font.Gotham
        stats.TextSize = 11
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.TextYAlignment = Enum.TextYAlignment.Top
        stats.TextColor3 = Color3.fromRGB(190, 190, 190)
        stats.TextWrapped = true
        stats.Position = UDim2.new(0, 6, 0, 108)
        stats.Size = UDim2.new(1, -12, 0, 64)
        stats.Text = string.format(
            "Luck: %s\nFrequency: %s\nPrice: %s",
            tostring(data.luck),
            tostring(data.frequency),
            tostring(data.priceText)
        )

        local actionBtn = Instance.new("TextButton")
        actionBtn.Name = "ActionButton"
        actionBtn.Parent = item
        actionBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        actionBtn.BorderSizePixel = 0
        actionBtn.AutoButtonColor = true
        actionBtn.Font = Enum.Font.GothamSemibold
        actionBtn.TextSize = 12
        actionBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        actionBtn.Text = "Buy"
        actionBtn.Position = UDim2.new(0, 6, 1, -32)
        actionBtn.Size = UDim2.new(1, -12, 0, 26)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = actionBtn

        basketCardsById[id] = {
            frame        = item,
            actionButton = actionBtn,
            assetType    = data.assetType or "Currency",
        }

        local function onAction()
            local owned = isBasketOwned(id)
            if owned then
                requestToolSwitch(id)
                task.delay(0.6, function()
                    if alive then
                        refreshBasketOwnership()
                    end
                end)
                return
            end

            if not ToolRE then
                notify("Spear Fishing", "Remote ToolRE tidak ditemukan.", 4)
                return
            end

            local assetType = (basketCardsById[id] and basketCardsById[id].assetType) or "Currency"

            if assetType == "Robux" and PurchaseUtil then
                local ok, err = pcall(function()
                    PurchaseUtil:getPurchase(id)
                end)
                if not ok then
                    warn("[SpearFishing] PurchaseUtil:getPurchase Basket gagal:", err)
                    notify("Spear Fishing", "Gagal membuka purchase Robux.", 4)
                end
            else
                local ok, err = pcall(function()
                    ToolRE:FireServer("Buy", { ID = id })
                end)

                if ok then
                    notify("Spear Fishing", "Request beli " .. (data.name or id) .. " dikirim.", 4)
                    task.delay(0.7, function()
                        if alive then
                            refreshBasketOwnership()
                        end
                    end)
                else
                    warn("[SpearFishing] ToolRE:Buy Basket gagal:", err)
                    notify("Spear Fishing", "Gagal mengirim request beli basket, cek Output.", 4)
                end
            end
        end

        local connBtn = actionBtn.MouseButton1Click:Connect(onAction)
        table.insert(connections, connBtn)
    end

    refreshBasketOwnership()

    if ToolsData then
        local c1 = ToolsData.AttributeChanged:Connect(refreshBasketOwnership)
        local c2 = ToolsData.ChildAdded:Connect(refreshBasketOwnership)
        local c3 = ToolsData.ChildRemoved:Connect(refreshBasketOwnership)
        table.insert(connections, c1)
        table.insert(connections, c2)
        table.insert(connections, c3)
    end

    return card
end

------------------- BAIT SHOP: DATA & UI -------------------
local function getBaitIds()
    if ResFishBait and type(ResFishBait.__index) == "table" then
        local list = {}
        for _, id in pairs(ResFishBait.__index) do
            table.insert(list, id)
        end
        return list
    end
    return BAIT_IDS
end

local function buildBaitShopCard(parent)
    local card, _, _ = createCard(
        parent,
        "Bait Shop",
        "Beli Bait (Icon + Attracts Rarity + Stock/NoStock + Price + Reset timer).",
        4,
        260
    )

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Parent = card
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Text = "Auto update Stock & Reset timer mengikuti FishBaitShop."
    infoLabel.Position = UDim2.new(0, 0, 0, 22)
    infoLabel.Size = UDim2.new(0.6, 0, 0, 18)

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "Timer"
    timeLabel.Parent = card
    timeLabel.BackgroundTransparency = 1
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 11
    timeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    timeLabel.Text = ""
    timeLabel.Position = UDim2.new(0.45, 0, 0, 22)
    timeLabel.Size = UDim2.new(0.55, -4, 0, 18)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "BaitScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 46)
    scroll.Size = UDim2.new(1, 0, 1, -54)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 8, 0, 0)
    end)
    table.insert(connections, conn)

    local baitIds = getBaitIds()

    local function updateStockVisual()
        if not FishBaitShop then return end
        for _, id in ipairs(baitIds) do
            local entry = baitCardsById[id]
            if entry and entry.stockLabel and entry.noStockLabel and entry.button then
                local stock = FishBaitShop:GetAttribute(id) or 0
                entry.stockLabel.Text = tostring(stock) .. " Stock"
                local hasStock = stock > 0
                entry.button.Visible   = hasStock
                entry.noStockLabel.Visible = not hasStock
            end
        end
    end

    for index, id in ipairs(baitIds) do
        local def
        if ItemUtil then
            local okDef, resDef = pcall(function()
                return ItemUtil:GetDef(id)
            end)
            if okDef then
                def = resDef
            end
        end

        local rarityName, rarityColorSeq
        if def and ItemUtil then
            local rarity = def.Rarity
            if rarity then
                local okName, resName = pcall(function()
                    return ItemUtil:getRarityName(rarity)
                end)
                if okName then
                    rarityName = resName
                end
                local okColor, colorSeq = pcall(function()
                    return ItemUtil:getTipRarityColorSeq(rarity)
                end)
                if okColor then
                    rarityColorSeq = colorSeq
                end
            end
        end

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 170, 0, 190)
        item.LayoutOrder = index

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 70)
        stroke.Thickness = 1
        stroke.Parent = item

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Parent = item
        icon.BackgroundTransparency = 1
        icon.BorderSizePixel = 0
        icon.Position = UDim2.new(0, 6, 0, 6)
        icon.Size = UDim2.new(1, -12, 0, 64)
        icon.Image = (ItemUtil and ItemUtil:getIcon(id)) or ""

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = item
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.Position = UDim2.new(0, 6, 0, 74)
        nameLabel.Size = UDim2.new(1, -12, 0, 16)
        nameLabel.Text = (def and def.Name) or (ItemUtil and ItemUtil:getName(id)) or id

        local desc = Instance.new("TextLabel")
        desc.Name = "Desc"
        desc.Parent = item
        desc.BackgroundTransparency = 1
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 11
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextYAlignment = Enum.TextYAlignment.Top
        desc.TextColor3 = Color3.fromRGB(190, 190, 190)
        desc.TextWrapped = true
        desc.Position = UDim2.new(0, 6, 0, 92)
        desc.Size = UDim2.new(1, -12, 0, 48)

        if rarityName then
            if ColorUtil and rarityColorSeq then
                local ok, txt = pcall(function()
                    return ColorUtil:createGradientText(rarityName, rarityColorSeq)
                end)
                if ok and txt then
                    desc.Text = "Attracts " .. txt .. " fish"
                else
                    desc.Text = "Attracts " .. rarityName .. " fish"
                end
            else
                desc.Text = "Attracts " .. rarityName .. " fish"
            end
        else
            desc.Text = "Special bait untuk menarik ikan rare."
        end

        local stockLabel = Instance.new("TextLabel")
        stockLabel.Name = "Stock"
        stockLabel.Parent = item
        stockLabel.BackgroundTransparency = 1
        stockLabel.Font = Enum.Font.Gotham
        stockLabel.TextSize = 11
        stockLabel.TextXAlignment = Enum.TextXAlignment.Left
        stockLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
        stockLabel.Position = UDim2.new(0, 6, 0, 142)
        stockLabel.Size = UDim2.new(0.6, 0, 0, 16)
        stockLabel.Text = "0 Stock"

        local noStockLabel = Instance.new("TextLabel")
        noStockLabel.Name = "NoStock"
        noStockLabel.Parent = item
        noStockLabel.BackgroundTransparency = 1
        noStockLabel.Font = Enum.Font.GothamSemibold
        noStockLabel.TextSize = 11
        noStockLabel.TextXAlignment = Enum.TextXAlignment.Right
        noStockLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
        noStockLabel.Position = UDim2.new(0.4, 0, 0, 142)
        noStockLabel.Size = UDim2.new(0.6, -6, 0, 16)
        noStockLabel.Text = "NO STOCK"
        noStockLabel.Visible = false

        local btn = Instance.new("TextButton")
        btn.Name = "BuyButton"
        btn.Parent = item
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(235, 235, 235)
        btn.Text = "Buy"
        btn.Position = UDim2.new(0, 6, 1, -30)
        btn.Size = UDim2.new(1, -12, 0, 24)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = btn

        baitCardsById[id] = {
            frame       = item,
            button      = btn,
            stockLabel  = stockLabel,
            noStockLabel= noStockLabel,
        }

        local function onBuy()
            if not BaitRE then
                notify("Spear Fishing", "Remote BaitRE tidak ditemukan.", 4)
                return
            end
            local ok, err = pcall(function()
                BaitRE:FireServer("Buy", { ID = id })
            end)
            if not ok then
                warn("[SpearFishing] BaitRE:Buy gagal:", err)
                notify("Spear Fishing", "Gagal mengirim request beli bait, cek Output.", 4)
            end
        end

        local connBtn = btn.MouseButton1Click:Connect(onBuy)
        table.insert(connections, connBtn)

        if UIUtil then
            pcall(function()
                UIUtil:onGuiObjectRegisterMouseEnterLeaveTweenScale(item)
            end)
        end
    end

    if FishBaitShop then
        updateStockVisual()
        local connAttr = FishBaitShop.AttributeChanged:Connect(updateStockVisual)
        table.insert(connections, connAttr)

        local function updateTimer()
            if not MathUtil then return end
            local value = FishBaitShop.Value or FishBaitShop:GetAttribute("ResetTime")
            if typeof(value) ~= "number" then
                timeLabel.Text = ""
                return
            end
            local ok, txt = pcall(function()
                return MathUtil:secondsToMMSS(value)
            end)
            if ok and txt then
                timeLabel.Text = "Reset in " .. txt
            else
                timeLabel.Text = ""
            end
        end

        local connChanged = FishBaitShop.Changed:Connect(updateTimer)
        table.insert(connections, connChanged)
        updateTimer()
    end

    return card
end

------------------- DAILY REWARD: UI CARD + AUTO CLAIM -------------------
local function refreshDailyVisual()
    if not ResDailyReward or not dailyCardsByIdx then return end

    for idx, entry in pairs(dailyCardsByIdx) do
        local btn        = entry.button
        local claimedLbl = entry.claimedLabel

        local node
        if DailyData then
            node = DailyData:FindFirstChild(idx) or DailyData:FindFirstChild(tostring(idx))
        end

        local claimed   = false
        local canClaim  = false

        if node then
            claimed  = node:GetAttribute("claimed") == true
            canClaim = not claimed
        end

        if btn then
            btn.Visible = canClaim
        end
        if claimedLbl then
            claimedLbl.Visible = claimed
        end
    end
end

local function buildDailyRewardCard(parent)
    local card, _, _ = createCard(
        parent,
        "Auto Daily Reward",
        "",
        5,
        260
    )

    local autoBtn, updateAutoUI = createToggleButton(card, "Auto Claim Daily Reward", false)
    autoBtn.Size     = UDim2.new(0.5, -6, 0, 26)
    autoBtn.Position = UDim2.new(0, 0, 0, 22)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Parent = card
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextWrapped = true
    infoLabel.Position = UDim2.new(0, 0, 0, 52)
    infoLabel.Size = UDim2.new(1, 0, 0, 28)
    infoLabel.Text = "Tampilkan reward harian (Day 1, Day 2, ...) + tombol Claim. Auto Claim akan menekan DailyRE jika reward tersedia."

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "DailyScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 82)
    scroll.Size = UDim2.new(1, 0, 1, -90)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    local connLayout = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 8, 0, 0)
    end)
    table.insert(connections, connLayout)

    if ResDailyReward and type(ResDailyReward) == "table" then
        for idx = 1, #ResDailyReward do
            local def = ResDailyReward[idx]
            local btnFrame = Instance.new("Frame")
            btnFrame.Name = "Day" .. idx
            btnFrame.Parent = scroll
            btnFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            btnFrame.BackgroundTransparency = 0.1
            btnFrame.BorderSizePixel = 0
            btnFrame.Size = UDim2.new(0, 170, 0, 190)
            btnFrame.LayoutOrder = idx

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = btnFrame

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(70, 70, 70)
            stroke.Thickness = 1
            stroke.Parent = btnFrame

            local dayLabel = Instance.new("TextLabel")
            dayLabel.Name = "DayLabel"
            dayLabel.Parent = btnFrame
            dayLabel.BackgroundTransparency = 1
            dayLabel.Font = Enum.Font.GothamSemibold
            dayLabel.TextSize = 12
            dayLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
            dayLabel.TextXAlignment = Enum.TextXAlignment.Left
            dayLabel.Position = UDim2.new(0, 6, 0, 4)
            dayLabel.Size = UDim2.new(1, -12, 0, 16)
            dayLabel.Text = "Day " .. tostring(idx)

            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.Parent = btnFrame
            icon.BackgroundTransparency = 1
            icon.BorderSizePixel = 0
            icon.Position = UDim2.new(0, 6, 0, 24)
            icon.Size = UDim2.new(0, 48, 0, 48)
            icon.Image = ""

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "Name"
            nameLabel.Parent = btnFrame
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.GothamSemibold
            nameLabel.TextSize = 12
            nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Position = UDim2.new(0, 60, 0, 28)
            nameLabel.Size = UDim2.new(1, -66, 0, 18)
            nameLabel.Text = "Reward"

            local countLabel = Instance.new("TextLabel")
            countLabel.Name = "Count"
            countLabel.Parent = btnFrame
            countLabel.BackgroundTransparency = 1
            countLabel.Font = Enum.Font.Gotham
            countLabel.TextSize = 11
            countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            countLabel.TextXAlignment = Enum.TextXAlignment.Left
            countLabel.Position = UDim2.new(0, 60, 0, 46)
            countLabel.Size = UDim2.new(1, -66, 0, 16)
            countLabel.Text = ""

            local claimedLabel = Instance.new("TextLabel")
            claimedLabel.Name = "Claimed"
            claimedLabel.Parent = btnFrame
            claimedLabel.BackgroundTransparency = 1
            claimedLabel.Font = Enum.Font.GothamSemibold
            claimedLabel.TextSize = 11
            claimedLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
            claimedLabel.TextXAlignment = Enum.TextXAlignment.Left
            claimedLabel.Position = UDim2.new(0, 6, 0, 70)
            claimedLabel.Size = UDim2.new(1, -12, 0, 18)
            claimedLabel.Text = "Claimed"
            claimedLabel.Visible = false

            local btn = Instance.new("TextButton")
            btn.Name = "ClaimButton"
            btn.Parent = btnFrame
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = true
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 12
            btn.TextColor3 = Color3.fromRGB(235, 235, 235)
            btn.Text = "Claim"
            btn.Position = UDim2.new(0, 6, 1, -30)
            btn.Size = UDim2.new(1, -12, 0, 24)

            local cornerBtn = Instance.new("UICorner")
            cornerBtn.CornerRadius = UDim.new(0, 6)
            cornerBtn.Parent = btn

            -- Isi data reward
            local thingId  = def.ThingId
            local thingCnt = def.ThingCount
            local iconName = def.IconName
            local displayName = def.Name

            if ItemUtil then
                if not displayName then
                    local okName, nm = pcall(function()
                        return ItemUtil:getName(thingId)
                    end)
                    if okName then
                        displayName = nm
                    end
                end
                local iconId = iconName or thingId
                local okIcon, ic = pcall(function()
                    return ItemUtil:getIcon(iconId)
                end)
                if okIcon then
                    icon.Image = ic
                end
            end

            nameLabel.Text = displayName or tostring(thingId)
            countLabel.Text = "x" .. tostring(thingCnt or 1)

            dailyCardsByIdx[idx] = {
                frame        = btnFrame,
                button       = btn,
                claimedLabel = claimedLabel,
            }

            local function claim()
                if not DailyRE then
                    notify("Spear Fishing", "Remote DailyRE tidak ditemukan.", 4)
                    return
                end
                local ok, err = pcall(function()
                    DailyRE:FireServer({ index = idx })
                end)
                if not ok then
                    warn("[SpearFishing] DailyRE:FireServer gagal:", err)
                    notify("Spear Fishing", "Gagal claim daily reward, cek Output.", 4)
                end
            end

            local connBtn = btn.MouseButton1Click:Connect(claim)
            table.insert(connections, connBtn)
        end

        refreshDailyVisual()

        if DailyData then
            for _, child in ipairs(DailyData:GetChildren()) do
                local connAttr = child.AttributeChanged:Connect(refreshDailyVisual)
                table.insert(connections, connAttr)
            end
            local connAdd = DailyData.ChildAdded:Connect(function(newChild)
                local connAttr = newChild.AttributeChanged:Connect(refreshDailyVisual)
                table.insert(connections, connAttr)
                refreshDailyVisual()
            end)
            table.insert(connections, connAdd)
            local connRem = DailyData.ChildRemoved:Connect(refreshDailyVisual)
            table.insert(connections, connRem)
        end
    end

    local connToggle = autoBtn.MouseButton1Click:Connect(function()
        autoDailyReward = not autoDailyReward
        updateAutoUI(autoDailyReward)
        notify("Spear Fishing", "Auto Daily Reward: " .. (autoDailyReward and "ON" or "OFF"), 2)
    end)
    table.insert(connections, connToggle)

    return card
end

------------------- BUILD UI: CONTROL CARD -------------------
local header, bodyScroll = createMainLayout()

local controlCard, _, _ = createCard(
    bodyScroll,
    "Spear Controls",
    "AutoFarm v1 + AutoFarm v2 (Tap Trackpad Left/Center) + AutoEquip + Sell All.",
    1,
    250
)

local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "Controls"
controlsFrame.Parent = controlCard
controlsFrame.BackgroundTransparency = 1
controlsFrame.BorderSizePixel = 0
controlsFrame.Position = UDim2.new(0, 0, 0, 40)
controlsFrame.Size = UDim2.new(1, 0, 1, -40)

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.Parent = controlsFrame
controlsLayout.FillDirection = Enum.FillDirection.Vertical
controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlsLayout.Padding = UDim.new(0, 6)

local autoFarmButton,   updateAutoFarmUI   = createToggleButton(controlsFrame, "AutoFarm Fish", false)
local autoEquipButton,  updateAutoEquipUI  = createToggleButton(controlsFrame, "AutoEquip Harpoon", false)
local autoFarmV2Button, updateAutoFarmV2UI = createToggleButton(controlsFrame, "AutoFarm Fish V2", false)

-- Tombol pilih mode V2: Left / Center
local v2ModeButton = Instance.new("TextButton")
v2ModeButton.Name = "AutoFarmV2ModeButton"
v2ModeButton.Parent = controlsFrame
v2ModeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
v2ModeButton.BorderSizePixel = 0
v2ModeButton.AutoButtonColor = true
v2ModeButton.Font = Enum.Font.Gotham
v2ModeButton.TextSize = 11
v2ModeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
v2ModeButton.TextWrapped = true
v2ModeButton.Size = UDim2.new(1, 0, 0, 26)

local v2ModeCorner = Instance.new("UICorner")
v2ModeCorner.CornerRadius = UDim.new(0, 8)
v2ModeCorner.Parent = v2ModeButton

local function updateV2ModeButton()
    v2ModeButton.Text = "Mode AutoFarm V2: " .. autoFarmV2Mode .. " Trackpad"
end
updateV2ModeButton()

local sellButton = Instance.new("TextButton")
sellButton.Name = "SellAllButton"
sellButton.Parent = controlsFrame
sellButton.BackgroundColor3 = Color3.fromRGB(70, 50, 50)
sellButton.BorderSizePixel = 0
sellButton.AutoButtonColor = true
sellButton.Font = Enum.Font.GothamSemibold
sellButton.TextSize = 12
sellButton.TextColor3 = Color3.fromRGB(240, 240, 240)
sellButton.Text = "Sell All Fish (Spear)"
sellButton.Size = UDim2.new(1, 0, 0, 30)

local sellCorner = Instance.new("UICorner")
sellCorner.CornerRadius = UDim.new(0, 8)
sellCorner.Parent = sellButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Parent = controlsFrame
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Size = UDim2.new(1, 0, 0, 40)
statusLabel.Text = "Status: AutoFarm OFF, AutoEquip OFF, AutoFarm V2 OFF (Center)."

local function updateStatusLabel()
    statusLabel.Text = string.format(
        "Status: AutoFarm %s, AutoEquip %s, AutoFarm V2 %s (%s).",
        autoFarm and "ON" or "OFF",
        autoEquip and "ON" or "OFF",
        autoFarmV2 and "ON" or "OFF",
        autoFarmV2Mode
    )
end

do
    local conn1 = autoFarmButton.MouseButton1Click:Connect(function()
        autoFarm = not autoFarm
        updateAutoFarmUI(autoFarm)
        updateStatusLabel()
    end)
    table.insert(connections, conn1)

    local conn2 = autoEquipButton.MouseButton1Click:Connect(function()
        autoEquip = not autoEquip
        updateAutoEquipUI(autoEquip)
        if autoEquip then
            ensureHarpoonEquipped()
        end
        updateStatusLabel()
    end)
    table.insert(connections, conn2)

    local connV2 = autoFarmV2Button.MouseButton1Click:Connect(function()
        autoFarmV2 = not autoFarmV2
        updateAutoFarmV2UI(autoFarmV2)
        updateStatusLabel()
    end)
    table.insert(connections, connV2)

    local connMode = v2ModeButton.MouseButton1Click:Connect(function()
        autoFarmV2Mode = (autoFarmV2Mode == "Center") and "Left" or "Center"
        updateV2ModeButton()
        updateStatusLabel()
    end)
    table.insert(connections, connMode)

    local conn3 = sellButton.MouseButton1Click:Connect(function()
        sellAllFish()
    end)
    table.insert(connections, conn3)
end

------------------- KEY F HOTKEY (TOGGLE AUTOFARM V2) -------------------
local function onInputBegan(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.F then return end

    autoFarmV2 = not autoFarmV2
    updateAutoFarmV2UI(autoFarmV2)
    updateStatusLabel()
    notify("Spear Fishing", "AutoFarm V2: " .. (autoFarmV2 and "ON" or "OFF") .. " (Key F)", 2)
end

do
    local connInput = UserInputService.InputBegan:Connect(onInputBegan)
    table.insert(connections, connInput)
end

------------------- BUILD UI: HARPOON, BASKET, BAIT, DAILY CARDS -------------------
buildHarpoonShopCard(bodyScroll)
buildBasketShopCard(bodyScroll)
buildBaitShopCard(bodyScroll)
buildDailyRewardCard(bodyScroll)

------------------- BACKPACK / CHARACTER EVENT UNTUK OWNED / EQUIP -------------------
do
    local connCharAdded = LocalPlayer.CharacterAdded:Connect(function(newChar)
        character = newChar
        task.delay(1, function()
            if alive then
                ensureHarpoonEquipped()
                refreshHarpoonOwnership()
                refreshBasketOwnership()
            end
        end)
    end)
    table.insert(connections, connCharAdded)

    local connBackpackAdded = LocalPlayer.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            backpack = child
            task.delay(0.5, function()
                if alive then
                    refreshHarpoonOwnership()
                    refreshBasketOwnership()
                end
            end)
        end
    end)
    table.insert(connections, connBackpackAdded)

    if backpack then
        local connB1 = backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                refreshHarpoonOwnership()
                refreshBasketOwnership()
            end
        end)
        table.insert(connections, connB1)

        local connB2 = backpack.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                refreshHarpoonOwnership()
                refreshBasketOwnership()
            end
        end)
        table.insert(connections, connB2)
    end
end

------------------- BACKGROUND LOOPS (RINGAN) -------------------
-- Loop AutoEquip (cek 0.3s sekali)
task.spawn(function()
    while alive do
        if autoEquip then
            pcall(ensureHarpoonEquipped)
        end
        task.wait(0.3)
    end
end)

-- Loop AutoFarm v1 (tembak harpoon)
task.spawn(function()
    while alive do
        if autoFarm then
            pcall(doFireHarpoon)
        end
        task.wait(0.1)
    end
end)

-- Loop AutoFarm v2 (tap trackpad Left/Center)
task.spawn(function()
    while alive do
        if autoFarmV2 then
            pcall(doAutoTapV2)
        end
        task.wait(0.1)
    end
end)

-- Loop Auto Daily Reward (ringan, cek tiap 5 detik)
task.spawn(function()
    while alive do
        if autoDailyReward and DailyRE and DailyData and ResDailyReward and type(ResDailyReward) == "table" then
            for idx = 1, #ResDailyReward do
                local node = DailyData:FindFirstChild(idx) or DailyData:FindFirstChild(tostring(idx))
                if node and not node:GetAttribute("claimed") then
                    pcall(function()
                        DailyRE:FireServer({ index = idx })
                    end)
                end
            end
        end
        task.wait(5)
    end
end)

------------------- TAB CLEANUP INTEGRASI CORE -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive             = false
    autoFarm          = false
    autoEquip         = false
    autoFarmV2        = false
    autoDailyReward   = false

    for _, conn in ipairs(connections) do
        if conn and conn.Disconnect then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end
    connections = {}

    if frame then
        pcall(function()
            frame:ClearAllChildren()
        end)
    end
end
