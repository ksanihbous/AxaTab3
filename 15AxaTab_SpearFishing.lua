--==========================================================
--  15AxaTab_SpearFishing.lua
--  TAB 15: "Spear Fishing PRO++ (AutoFarm + Harpoon/Basket/Bait Shop + AimLock + ESP + WalkTo)"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "spearfishing"

local Players             = Players             or game:GetService("Players")
local LocalPlayer         = LocalPlayer         or Players.LocalPlayer
local RunService          = RunService          or game:GetService("RunService")
local TweenService        = TweenService        or game:GetService("TweenService")
local HttpService         = HttpService         or game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = UserInputService    or game:GetService("UserInputService")
local StarterGui          = StarterGui          or game:GetService("StarterGui")
local VirtualInputManager = VirtualInputManager or game:GetService("VirtualInputManager")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not PlayerGui then
    pcall(function()
        PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
end

------------------- GLOBAL STATE / AXAHUB -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

local alive              = true
local autoFarm           = false      -- AutoFarm Fish v1
local autoEquip          = false      -- AutoEquip Harpoon
local autoFarmV2         = false      -- AutoFarm Fish V2 (tap trackpad)
local autoFarmV2Mode     = "Center"   -- "Left" / "Center"
local aimLockNearest     = false      -- Aim Lock ke ikan terdekat
local fishESPEnabled     = false      -- ESP ikan
local walkToNearestFish  = false      -- WalkTo ikan terdekat

local AIM_MAX_DISTANCE = 300 -- studs

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local backpack  = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")

local connections = {}
local ToolsData   = nil           -- diisi setelah WaitPlayerData siap

------------------- REMOTES & GAME INSTANCES -------------------
local Remotes        = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE         = Remotes and Remotes:FindFirstChild("FireRE")   -- Fire harpoon
local ToolRE         = Remotes and Remotes:FindFirstChild("ToolRE")   -- Buy / Switch harpoon & basket
local FishRE         = Remotes and Remotes:FindFirstChild("FishRE")   -- Sell spear-fish
local BaitRE         = Remotes and Remotes:FindFirstChild("BaitRE")   -- Buy bait

local GameFolder     = ReplicatedStorage:FindFirstChild("Game")
local FishBaitShop   = GameFolder and GameFolder:FindFirstChild("FishBaitShop") -- NumberValue + atribut stok bait

-- Folder ikan di dunia (WorldSea -> Sea1/Sea2/Sea3 -> Fish*)
local WorldSea = workspace:FindFirstChild("WorldSea")

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
local ResFishBasket = safeRequire(ConfigFolder,  "ResFishBasket")
local ResFishBait   = safeRequire(ConfigFolder,  "ResFishBait")
local MathUtil      = safeRequire(UtilityFolder, "MathUtil")

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

------------------- ID LIST -------------------
local HARPOON_IDS = {
    "Harpoon01","Harpoon02","Harpoon03","Harpoon04","Harpoon05","Harpoon06",
    "Harpoon07","Harpoon08","Harpoon09","Harpoon10","Harpoon11","Harpoon12",
    "Harpoon20","Harpoon21",
}

local BASKET_IDS = {
    "FishBasket2","FishBasket3","FishBasket4",
    "FishBasket5","FishBasket7","FishBasket8",
}

local BAIT_IDS = {
    "Bait1","Bait2","Bait3","Bait4","Bait5",
}

------------------- TOOL / HARPOON / BASKET DETECTION -------------------
local function isHarpoonTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool.Name:match("^Harpoon(%d+)$") ~= nil
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
    if ToolsData and ToolsData:FindFirstChild(id) then
        return true
    end

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
    return isToolOwnedGeneric(id)
end

local function isBasketOwned(id)
    return isToolOwnedGeneric(id)
end

------------------- AIM LOCK: NEAREST FISH DI WORLDSEA -------------------
-- Cari ikan terdekat dari posisi tertentu
local function getNearestFishFromPosition(origin, maxDistance)
    maxDistance = maxDistance or AIM_MAX_DISTANCE
    if maxDistance <= 0 then return nil end
    if not WorldSea then return nil end
    if not origin then return nil end

    local nearestPart
    local nearestDist = maxDistance

    for _, sea in ipairs(WorldSea:GetChildren()) do
        for _, child in ipairs(sea:GetChildren()) do
            if child:IsA("BasePart") and child.Name:sub(1, 4) == "Fish" then
                local dist = (child.Position - origin).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPart = child
                end
            end
        end
    end

    return nearestPart, nearestDist
end

-- Versi untuk AimLock (pakai kamera)
local function getNearestFish(maxDistance)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    return getNearestFishFromPosition(camera.CFrame.Position, maxDistance)
end

local function getNearestFishWorldPos(maxDistance)
    local part = getNearestFish(maxDistance)
    return part and part.Position or nil
end

------------------- FISH ESP (BILLBOARD + JARAK STUDS) -------------------
local fishESPMap = {} -- [BasePart] = {gui = BillboardGui, label = TextLabel}

local function destroyFishESP(part)
    local info = fishESPMap[part]
    if info then
        if info.gui then
            pcall(function()
                info.gui:Destroy()
            end)
        end
        fishESPMap[part] = nil
    end
end

local function createFishESPForPart(part)
    if not part or not part:IsA("BasePart") then return end
    if fishESPMap[part] then return end
    if not PlayerGui then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AxaFishESP"
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 140, 0, 22)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = AIM_MAX_DISTANCE + 50
    billboard.Enabled = false
    billboard.Parent = PlayerGui

    local bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Parent = billboard
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    bg.Size = UDim2.new(1, 0, 1, 0)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = bg

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = bg
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(0, 255, 200)
    label.TextStrokeTransparency = 0.5
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Size = UDim2.new(1, -4, 1, 0)
    label.Position = UDim2.new(0, 2, 0, 0)
    label.Text = part.Name

    fishESPMap[part] = {
        gui   = billboard,
        label = label,
    }
end

local function initFishESPWatcher()
    if not WorldSea then return end

    local function handleSea(sea)
        if not sea then return end

        for _, child in ipairs(sea:GetChildren()) do
            if child:IsA("BasePart") and child.Name:sub(1, 4) == "Fish" then
                createFishESPForPart(child)
            end
        end

        local cAdd = sea.ChildAdded:Connect(function(child)
            if not alive then return end
            if child:IsA("BasePart") and child.Name:sub(1, 4) == "Fish" then
                createFishESPForPart(child)
            end
        end)
        table.insert(connections, cAdd)

        local cRem = sea.ChildRemoved:Connect(function(child)
            destroyFishESP(child)
        end)
        table.insert(connections, cRem)
    end

    for _, sea in ipairs(WorldSea:GetChildren()) do
        handleSea(sea)
    end

    local connSeaAdded = WorldSea.ChildAdded:Connect(function(child)
         if not alive then return end
         handleSea(child)
    end)
    table.insert(connections, connSeaAdded)
end

-- Loop update teks ESP (nama + jarak ke kamera)
task.spawn(function()
    while alive do
        if fishESPEnabled then
            local camera = workspace.CurrentCamera
            if camera then
                local camPos = camera.CFrame.Position
                for part, info in pairs(fishESPMap) do
                    if part and part.Parent and info.gui and info.label then
                        local dist = (part.Position - camPos).Magnitude
                        local studs = math.floor(dist + 0.5)
                        info.label.Text = string.format("%s, %d studs", part.Name, studs)
                        info.gui.Enabled = true
                    else
                        destroyFishESP(part)
                    end
                end
            end
        else
            for _, info in pairs(fishESPMap) do
                if info.gui then
                    info.gui.Enabled = false
                end
            end
        end
        task.wait(0.1)
    end
end)

------------------- UI HELPERS (TAHOE STYLE LIGHT) -------------------
local harpoonCardsById = {}
local basketCardsById  = {}
local baitCardsById    = {}

local function createMainLayout()
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
    subtitle.Text = "AutoFarm v1 + v2 (Trackpad) + AutoEquip + Harpoon/Basket/Bait Shop + AimLock + Fish ESP + WalkTo."

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

------------------- AUTO FARM V1 (FIRE HARPOON + AIM LOCK) -------------------
local lastShotClock = 0
local FIRE_INTERVAL = 0.35

local function doFireHarpoon()
    if not alive or not autoFarm then return end
    if not FireRE then return end
    if not character then return end

    local now = os.clock()
    if now - lastShotClock < FIRE_INTERVAL then
        return
    end
    lastShotClock = now

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

    local origin = camera.CFrame.Position
    local direction

    if aimLockNearest then
        local targetPos = getNearestFishWorldPos(AIM_MAX_DISTANCE)
        if targetPos then
            direction = (targetPos - origin).Unit
        end
    end

    if not direction then
        local viewport = camera.ViewportSize
        local centerX, centerY = viewport.X / 2, viewport.Y / 2
        local ray = camera:ScreenPointToRay(centerX, centerY, 0)
        origin = ray.Origin
        direction = ray.Direction
    end

    local destination = origin + direction * AIM_MAX_DISTANCE

    local args = {
        [1] = "Fire",
        [2] = {
            ["cameraOrigin"] = origin,
            ["player"]       = LocalPlayer,
            ["toolInstance"] = harpoon,
            ["destination"]  = destination,
            ["isCharge"]     = false
        }
    }

    local ok, err = pcall(function()
        FireRE:FireServer(unpack(args))
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
    local y = v.Y * 0.8
    local x
    if mode == "Left" then
        x = v.X * 0.3
    else
        x = v.X * 0.5
    end
    return Vector2.new(x, y)
end

local function tapScreenPosition(pos)
    if not pos or not VirtualInputManager then return end
    if UserInputService:GetFocusedTextBox() then
        return
    end

    local x, y = pos.X, pos.Y

    if isTouch then
        pcall(function()
            VirtualInputManager:SendTouchEvent(x, y, 0, true, workspace.CurrentCamera, 0)
            VirtualInputManager:SendTouchEvent(x, y, 0, false, workspace.CurrentCamera, 0)
        end)
    else
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

------------------- WALKTO NEAREST FISH -------------------
local lastWalkDebugClock = 0

local function debugWalk(msg)
    local now = os.clock()
    if now - lastWalkDebugClock > 3 then
        lastWalkDebugClock = now
        notify("Spear Fishing", "WalkTo: " .. msg, 3)
    end
end

local function doWalkToNearestFish()
    if not alive or not walkToNearestFish then return end
    if not character then
        debugWalk("Character tidak ada.")
        return
    end

    if not WorldSea then
        debugWalk("Folder WorldSea tidak ditemukan.")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        debugWalk("Humanoid tidak ditemukan.")
        return
    end

    if humanoid.Sit or humanoid.SeatPart then
        humanoid.Sit = false
    end

    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("LowerTorso")
    if not root then
        debugWalk("HumanoidRootPart tidak ditemukan.")
        return
    end

    local fishPart, dist = getNearestFishFromPosition(root.Position, AIM_MAX_DISTANCE)
    if fishPart and fishPart.Parent then
        humanoid:MoveTo(fishPart.Position)
        debugWalk(string.format("Menuju %s (%.0f studs).", fishPart.Name, dist or 0))
    else
        debugWalk("Tidak ada ikan dalam " .. tostring(AIM_MAX_DISTANCE) .. " studs.")
    end
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
    for id, entry in pairs(harpoonCardsById) do
        local btn = entry.buyButton
        if btn then
            local owned = isHarpoonOwned(id)
            if owned then
                btn.Text = "Owned"
                btn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
                btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                btn.AutoButtonColor = false
            else
                btn.Text = "Buy"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.TextColor3 = Color3.fromRGB(235, 235, 235)
                btn.AutoButtonColor = true
            end
        end
    end
end

local function buildHarpoonShopCard(parent)
    local card = select(1, createCard(
        parent,
        "Harpoon Shop",
        "Toko Harpoon (Image + DMG + CRT + Charge + Price).",
        2,
        280
    ))

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "HarpoonScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 40)
    scroll.Size = UDim2.new(1, 0, 1, -44)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
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

    for index, id in ipairs(HARPOON_IDS) do
        local data = getHarpoonDisplayData(id)

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 150, 0, 210)
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
        img.Size = UDim2.new(1, -12, 0, 70)
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
        nameLabel.Position = UDim2.new(0, 6, 0, 80)
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
        stats.Position = UDim2.new(0, 6, 0, 98)
        stats.Size = UDim2.new(1, -12, 0, 72)
        stats.Text = string.format(
            "DMG: %s~%s\nCRT: %s\nCharge: %s\nPrice: %s",
            tostring(data.dmgMin),
            tostring(data.dmgMax),
            tostring(data.crt),
            tostring(data.charge),
            tostring(data.priceText)
        )

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyButton"
        buyBtn.Parent = item
        buyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        buyBtn.BorderSizePixel = 0
        buyBtn.AutoButtonColor = true
        buyBtn.Font = Enum.Font.GothamSemibold
        buyBtn.TextSize = 12
        buyBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        buyBtn.Text = "Buy"
        buyBtn.Position = UDim2.new(0, 6, 1, -30)
        buyBtn.Size = UDim2.new(1, -12, 0, 24)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = buyBtn

        harpoonCardsById[id] = {
            frame     = item,
            buyButton = buyBtn,
            assetType = data.assetType or "Currency",
        }

        local function onBuy()
            if isHarpoonOwned(id) then
                notify("Spear Fishing", (data.name or id) .. " sudah dimiliki.", 3)
                refreshHarpoonOwnership()
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
                local args = {
                    [1] = "Buy",
                    [2] = { ["ID"] = id }
                }

                local ok, err = pcall(function()
                    ToolRE:FireServer(unpack(args))
                end)

                if ok then
                    notify("Spear Fishing", "Request beli " .. (data.name or id) .. " dikirim.", 4)
                else
                    warn("[SpearFishing] ToolRE:Buy gagal:", err)
                    notify("Spear Fishing", "Gagal mengirim request beli, cek Output.", 4)
                end
            end
        end

        local conn = buyBtn.MouseButton1Click:Connect(onBuy)
        table.insert(connections, conn)
    end

    refreshHarpoonOwnership()
    return card
end

------------------- BASKET SHOP: DATA & UI -------------------
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

    if ResFishBasket then
        local okCfg, cfg = pcall(function()
            return ResFishBasket[id] or (ResFishBasket.__index and ResFishBasket.__index[id])
        end)
        if okCfg and type(cfg) == "table" then
            local function pickNumber(tbl, keys)
                for _, key in ipairs(keys) do
                    local v = tbl[key]
                    if type(v) == "number" then
                        return v
                    end
                end
                for _, v in pairs(tbl) do
                    if type(v) == "number" then
                        return v
                    end
                end
                return nil
            end

            local luckVal = pickNumber(cfg, {"Luck", "LuckRate", "LuckValue"})
            if luckVal then
                luck = tostring(luckVal)
            end

            local freqVal = pickNumber(cfg, {"Frequency","Freq","FrequencySec","Cooldown","CoolDown","Interval","Time"})
            if freqVal then
                frequency = tostring(freqVal) .. "s"
            end
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
    for id, entry in pairs(basketCardsById) do
        local btn = entry.buyButton
        if btn then
            local owned = isBasketOwned(id)
            if owned then
                btn.Text = "Owned"
                btn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
                btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                btn.AutoButtonColor = false
            else
                btn.Text = "Buy"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.TextColor3 = Color3.fromRGB(235, 235, 235)
                btn.AutoButtonColor = true
            end
        end
    end
end

local function buildBasketShopCard(parent)
    local card = select(1, createCard(
        parent,
        "Basket Shop",
        "Toko Basket (Icon + Luck + Frequency + Price).",
        3,
        280
    ))

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "BasketScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 40)
    scroll.Size = UDim2.new(1, 0, 1, -44)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
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

    for index, id in ipairs(BASKET_IDS) do
        local data = getBasketDisplayData(id)

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 150, 0, 210)
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
        img.Size = UDim2.new(1, -12, 0, 70)
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
        nameLabel.Position = UDim2.new(0, 6, 0, 80)
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
        stats.Position = UDim2.new(0, 6, 0, 98)
        stats.Size = UDim2.new(1, -12, 0, 72)
        stats.Text = string.format(
            "Luck: %s\nFrequency: %s\nPrice: %s",
            tostring(data.luck),
            tostring(data.frequency),
            tostring(data.priceText)
        )

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyButton"
        buyBtn.Parent = item
        buyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        buyBtn.BorderSizePixel = 0
        buyBtn.AutoButtonColor = true
        buyBtn.Font = Enum.Font.GothamSemibold
        buyBtn.TextSize = 12
        buyBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        buyBtn.Text = "Buy"
        buyBtn.Position = UDim2.new(0, 6, 1, -30)
        buyBtn.Size = UDim2.new(1, -12, 0, 24)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = buyBtn

        basketCardsById[id] = {
            frame     = item,
            buyButton = buyBtn,
            assetType = data.assetType or "Currency",
        }

        local function onBuy()
            if isBasketOwned(id) then
                notify("Spear Fishing", (data.name or id) .. " sudah dimiliki.", 3)
                refreshBasketOwnership()
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
                    warn("[SpearFishing] PurchaseUtil:getPurchase gagal:", err)
                    notify("Spear Fishing", "Gagal membuka purchase Robux.", 4)
                end
            else
                local args = {
                    [1] = "Buy",
                    [2] = { ["ID"] = id }
                }

                local ok, err = pcall(function()
                    ToolRE:FireServer(unpack(args))
                end)

                if ok then
                    notify("Spear Fishing", "Request beli " .. (data.name or id) .. " dikirim.", 4)
                else
                    warn("[SpearFishing] ToolRE:Buy Basket gagal:", err)
                    notify("Spear Fishing", "Gagal mengirim request beli basket, cek Output.", 4)
                end
            end
        end

        local conn = buyBtn.MouseButton1Click:Connect(onBuy)
        table.insert(connections, conn)
    end

    refreshBasketOwnership()
    return card
end

------------------- BAIT SHOP: DATA & UI -------------------
local function refreshBaitStock()
    if not FishBaitShop then return end
    for id, entry in pairs(baitCardsById) do
        local stockVal = FishBaitShop:GetAttribute(id)
        if typeof(stockVal) ~= "number" then
            stockVal = 0
        end
        if entry.stockLabel then
            entry.stockLabel.Text = "Stock: " .. stockVal
        end
        local hasStock = stockVal > 0
        if entry.buyButton then
            entry.buyButton.Visible = hasStock
        end
        if entry.noStockLabel then
            entry.noStockLabel.Visible = not hasStock
        end
    end
end

local function buildBaitShopCard(parent)
    local card = select(1, createCard(
        parent,
        "Bait Shop",
        "",
        4,
        280
    ))

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Parent = card
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Text = "Beli Bait (Stock + Attracts Rarity Fish + Price)."
    infoLabel.Position = UDim2.new(0, 0, 0, 20)
    infoLabel.Size = UDim2.new(0.6, 0, 0, 18)

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "ResetLabel"
    timeLabel.Parent = card
    timeLabel.BackgroundTransparency = 1
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 11
    timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    timeLabel.Text = "Reset in: --:--"
    timeLabel.Position = UDim2.new(0.4, 0, 0, 20)
    timeLabel.Size = UDim2.new(0.6, -2, 0, 18)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "BaitScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 44)
    scroll.Size = UDim2.new(1, 0, 1, -48)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
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

    for index, id in ipairs(BAIT_IDS) do
        local name   = id
        local icon   = ""
        local rarityName = "?"
        local priceText  = "N/A"

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
            if okDef and def then
                local okRarName, rName = pcall(function()
                    return ItemUtil:getRarityName(def.Rarity)
                end)
                if okRarName and rName then
                    rarityName = rName
                end
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

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 150, 0, 210)
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
        img.Size = UDim2.new(1, -12, 0, 70)
        img.Image = icon or ""
        img.ScaleType = Enum.ScaleType.Fit

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = item
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.Position = UDim2.new(0, 6, 0, 80)
        nameLabel.Size = UDim2.new(1, -12, 0, 16)
        nameLabel.Text = name

        local attrLabel = Instance.new("TextLabel")
        attrLabel.Name = "Attr"
        attrLabel.Parent = item
        attrLabel.BackgroundTransparency = 1
        attrLabel.Font = Enum.Font.Gotham
        attrLabel.TextSize = 11
        attrLabel.TextXAlignment = Enum.TextXAlignment.Left
        attrLabel.TextYAlignment = Enum.TextYAlignment.Top
        attrLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        attrLabel.TextWrapped = true
        attrLabel.Position = UDim2.new(0, 6, 0, 98)
        attrLabel.Size = UDim2.new(1, -12, 0, 36)
        attrLabel.Text = "Attracts " .. tostring(rarityName) .. " fish"

        local stockLabel = Instance.new("TextLabel")
        stockLabel.Name = "Stock"
        stockLabel.Parent = item
        stockLabel.BackgroundTransparency = 1
        stockLabel.Font = Enum.Font.Gotham
        stockLabel.TextSize = 11
        stockLabel.TextXAlignment = Enum.TextXAlignment.Left
        stockLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        stockLabel.Position = UDim2.new(0, 6, 0, 136)
        stockLabel.Size = UDim2.new(1, -12, 0, 16)
        stockLabel.Text = "Stock: -"

        local priceLabel = Instance.new("TextLabel")
        priceLabel.Name = "Price"
        priceLabel.Parent = item
        priceLabel.BackgroundTransparency = 1
        priceLabel.Font = Enum.Font.Gotham
        priceLabel.TextSize = 11
        priceLabel.TextXAlignment = Enum.TextXAlignment.Left
        priceLabel.TextColor3 = Color3.fromRGB(200, 200, 0)
        priceLabel.Position = UDim2.new(0, 6, 0, 154)
        priceLabel.Size = UDim2.new(1, -12, 0, 16)
        priceLabel.Text = "Price: " .. priceText

        local noStockLabel = Instance.new("TextLabel")
        noStockLabel.Name = "NoStock"
        noStockLabel.Parent = item
        noStockLabel.BackgroundTransparency = 1
        noStockLabel.Font = Enum.Font.GothamSemibold
        noStockLabel.TextSize = 11
        noStockLabel.TextXAlignment = Enum.TextXAlignment.Center
        noStockLabel.TextColor3 = Color3.fromRGB(220, 100, 100)
        noStockLabel.Position = UDim2.new(0, 6, 1, -46)
        noStockLabel.Size = UDim2.new(1, -12, 0, 18)
        noStockLabel.Text = "No Stock"
        noStockLabel.Visible = false

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyButton"
        buyBtn.Parent = item
        buyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        buyBtn.BorderSizePixel = 0
        buyBtn.AutoButtonColor = true
        buyBtn.Font = Enum.Font.GothamSemibold
        buyBtn.TextSize = 12
        buyBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        buyBtn.Text = "Buy"
        buyBtn.Position = UDim2.new(0, 6, 1, -26)
        buyBtn.Size = UDim2.new(1, -12, 0, 22)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = buyBtn

        baitCardsById[id] = {
            frame       = item,
            buyButton   = buyBtn,
            stockLabel  = stockLabel,
            noStockLabel= noStockLabel,
        }

        local function onBuy()
            if not BaitRE then
                notify("Spear Fishing", "Remote BaitRE tidak ditemukan.", 4)
                return
            end

            local args = {
                [1] = "Buy",
                [2] = { ["ID"] = id }
            }

            local ok, err = pcall(function()
                BaitRE:FireServer(unpack(args))
            end)

            if ok then
                notify("Spear Fishing", "Request beli " .. name .. " dikirim.", 4)
            else
                warn("[SpearFishing] BaitRE:Buy gagal:", err)
                notify("Spear Fishing", "Gagal mengirim request beli bait, cek Output.", 4)
            end
        end

        local conn = buyBtn.MouseButton1Click:Connect(onBuy)
        table.insert(connections, conn)
    end

    refreshBaitStock()

    if FishBaitShop then
        local connChanged = FishBaitShop.Changed:Connect(function(value)
            if not alive then return end
            local txt
            if MathUtil and type(value) == "number" then
                local okFmt, mmss = pcall(function()
                    return MathUtil:secondsToMMSS(value)
                end)
                txt = okFmt and mmss or tostring(value) .. "s"
            else
                txt = tostring(value)
            end
            timeLabel.Text = "Reset in: " .. txt
        end)
        table.insert(connections, connChanged)

        local connAttr = FishBaitShop.AttributeChanged:Connect(function()
            if not alive then return end
            refreshBaitStock()
        end)
        table.insert(connections, connAttr)
    end

    return card
end

------------------- TOOLSDATA INIT (UNTUK OWNERSHIP REFRESH) -------------------
local function initToolsDataWatcher()
    task.spawn(function()
        if ToolsData then return end

        local waitFn
        while alive and not waitFn do
            local ok, fn = pcall(function()
                return shared and shared.WaitPlayerData
            end)
            if ok and typeof(fn) == "function" then
                waitFn = fn
                break
            end
            task.wait(0.2)
        end

        if not alive or not waitFn then
            return
        end

        local ok2, result = pcall(function()
            return waitFn("Tools")
        end)
        if not ok2 or not result then
            warn("[SpearFishing] Gagal WaitPlayerData('Tools'):", ok2 and "no result" or result)
            return
        end

        ToolsData = result

        local function onToolsChanged()
            if not alive then return end
            refreshHarpoonOwnership()
            refreshBasketOwnership()
        end

        if ToolsData.AttributeChanged then
            local c1 = ToolsData.AttributeChanged:Connect(onToolsChanged)
            table.insert(connections, c1)
        end
        local c2 = ToolsData.ChildAdded:Connect(onToolsChanged)
        local c3 = ToolsData.ChildRemoved:Connect(onToolsChanged)
        table.insert(connections, c2)
        table.insert(connections, c3)

        onToolsChanged()
    end)
end

------------------- BUILD UI: CONTROL CARD (DENGAN SCROLLINGFRAME) -------------------
local header, bodyScroll = createMainLayout()

local controlCard = select(1, createCard(
    bodyScroll,
    "Spear Controls",
    "AutoFarm v1/v2 + AutoEquip + Sell All + AimLock Nearest + Fish ESP + WalkTo Nearest.",
    1,
    260
))

local controlsScroll = Instance.new("ScrollingFrame")
controlsScroll.Name = "ControlsScroll"
controlsScroll.Parent = controlCard
controlsScroll.BackgroundTransparency = 1
controlsScroll.BorderSizePixel = 0
controlsScroll.Position = UDim2.new(0, 0, 0, 40)
controlsScroll.Size = UDim2.new(1, 0, 1, -40)
controlsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
controlsScroll.ScrollBarThickness = 4
controlsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local controlsPadding = Instance.new("UIPadding")
controlsPadding.Parent = controlsScroll
controlsPadding.PaddingTop = UDim.new(0, 2)
controlsPadding.PaddingBottom = UDim.new(0, 4)

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.Parent = controlsScroll
controlsLayout.FillDirection = Enum.FillDirection.Vertical
controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlsLayout.Padding = UDim.new(0, 6)

local connControls = controlsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    controlsScroll.CanvasSize = UDim2.new(0, 0, 0, controlsLayout.AbsoluteContentSize.Y + 4)
end)
table.insert(connections, connControls)

local autoFarmButton,   updateAutoFarmUI   = createToggleButton(controlsScroll, "AutoFarm Fish", false)
local autoEquipButton,  updateAutoEquipUI  = createToggleButton(controlsScroll, "AutoEquip Harpoon", false)
local autoFarmV2Button, updateAutoFarmV2UI = createToggleButton(controlsScroll, "AutoFarm Fish V2", false)
local aimLockButton,    updateAimLockUI    = createToggleButton(controlsScroll, "Aim Lock Nearest", false)
local fishESPButton,    updateFishESPUI    = createToggleButton(controlsScroll, "Fish ESP", false)
local walkToButton,     updateWalkToUI     = createToggleButton(controlsScroll, "WalkTo Nearest Fish", false)

local v2ModeButton = Instance.new("TextButton")
v2ModeButton.Name = "AutoFarmV2ModeButton"
v2ModeButton.Parent = controlsScroll
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
sellButton.Parent = controlsScroll
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
statusLabel.Parent = controlsScroll
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Size = UDim2.new(1, 0, 0, 40)
statusLabel.Text = "Status: AutoFarm OFF, AutoEquip OFF, AutoFarm V2 OFF (Center), AimLock OFF, ESP OFF, WalkTo OFF."

local function updateStatusLabel()
    statusLabel.Text = string.format(
        "Status: AutoFarm %s, AutoEquip %s, AutoFarm V2 %s (%s), AimLock %s, ESP %s, WalkTo %s.",
        autoFarm and "ON" or "OFF",
        autoEquip and "ON" or "OFF",
        autoFarmV2 and "ON" or "OFF",
        autoFarmV2Mode,
        aimLockNearest and "ON" or "OFF",
        fishESPEnabled and "ON" or "OFF",
        walkToNearestFish and "ON" or "OFF"
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

    local connAim = aimLockButton.MouseButton1Click:Connect(function()
        aimLockNearest = not aimLockNearest
        updateAimLockUI(aimLockNearest)
        updateStatusLabel()
    end)
    table.insert(connections, connAim)

    local connESP = fishESPButton.MouseButton1Click:Connect(function()
        fishESPEnabled = not fishESPEnabled
        updateFishESPUI(fishESPEnabled)
        updateStatusLabel()
    end)
    table.insert(connections, connESP)

    local connWalk = walkToButton.MouseButton1Click:Connect(function()
        walkToNearestFish = not walkToNearestFish
        updateWalkToUI(walkToNearestFish)
        updateStatusLabel()
    end)
    table.insert(connections, connWalk)

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
    if UserInputService:GetFocusedTextBox() then return end

    autoFarmV2 = not autoFarmV2
    updateAutoFarmV2UI(autoFarmV2)
    updateStatusLabel()
    notify("Spear Fishing", "AutoFarm V2: " .. (autoFarmV2 and "ON" or "OFF") .. " (Key F)", 2)
end

do
    local connInput = UserInputService.InputBegan:Connect(onInputBegan)
    table.insert(connections, connInput)
end

------------------- BUILD UI: SHOP CARDS -------------------
buildHarpoonShopCard(bodyScroll)
buildBasketShopCard(bodyScroll)
buildBaitShopCard(bodyScroll)

initToolsDataWatcher()
initFishESPWatcher()

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
task.spawn(function()
    while alive do
        if autoEquip then
            pcall(ensureHarpoonEquipped)
        end
        task.wait(0.3)
    end
end)

task.spawn(function()
    while alive do
        if autoFarm then
            pcall(doFireHarpoon)
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while alive do
        if autoFarmV2 then
            pcall(doAutoTapV2)
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while alive do
        if walkToNearestFish then
            pcall(doWalkToNearestFish)
        end
        task.wait(0.2)
    end
end)

------------------- TAB CLEANUP INTEGRASI CORE -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive              = false
    autoFarm           = false
    autoEquip          = false
    autoFarmV2         = false
    aimLockNearest     = false
    fishESPEnabled     = false
    walkToNearestFish  = false

    for _, conn in ipairs(connections) do
        if conn and conn.Disconnect then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end
    connections = {}

    for _, info in pairs(fishESPMap) do
        if info.gui then
            pcall(function()
                info.gui:Destroy()
            end)
        end
    end
    fishESPMap = {}

    if frame then
        pcall(function()
            frame:ClearAllChildren()
        end)
    end
end
