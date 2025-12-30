--==========================================================
--  15AxaTab_SpearFishing.lua
--  TAB 15: "Spear Fishing PRO++ (AutoFarm + Harpoon/Basket/Bait Shop + Auto Daily Reward + Auto Skill + Album Collect)"
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

------------------- GLOBAL STATE / AXAHUB -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

local alive           = true
local autoFarm        = false      -- AutoFarm Fish v1: default OFF
local autoEquip       = false      -- AutoEquip Harpoon: default OFF
local autoFarmV2      = false      -- AutoFarm Fish V2 (tap trackpad): default OFF
local autoFarmV2Mode  = "Center"   -- "Left" / "Center"
local autoDailyReward = true       -- Auto Daily Reward: default ON

-- Auto Skill (DEFAULT ON)
local autoSkill1      = true       -- Auto Skill 1: default ON
local autoSkill2      = true       -- Auto Skill 2: default ON

-- Auto Album Collect (DEFAULT OFF)
local autoCollectAlbum = false     -- Auto Collect Album: default OFF

local character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local backpack        = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")

local connections     = {}
local ToolsData       = nil           -- WaitPlayerData("Tools")
local DailyData       = nil           -- WaitPlayerData("Daily")
local SpearFishData   = nil           -- WaitPlayerData(...) / Folder spearfish
local spearInitTried  = false

-- Album Data Spear/Fish (PlayerData "Album")
local AlbumData       = nil           -- WaitPlayerData("Album")
local albumInitStarted = false

------------------- REMOTES & GAME INSTANCES -------------------
local Remotes        = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE         = Remotes and Remotes:FindFirstChild("FireRE")   -- Fire harpoon
local ToolRE         = Remotes and Remotes:FindFirstChild("ToolRE")   -- Buy / Switch harpoon & basket
local FishRE         = Remotes and Remotes:FindFirstChild("FishRE")   -- Sell spear-fish + Skill + Album
local BaitRE         = Remotes and Remotes:FindFirstChild("BaitRE")   -- Buy bait
local DailyRE        = Remotes and Remotes:FindFirstChild("DailyRE")  -- Daily reward claim

local GameFolder     = ReplicatedStorage:FindFirstChild("Game")
local FishBaitShop   = GameFolder and GameFolder:FindFirstChild("FishBaitShop") -- NumberValue + atribut stok bait

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

local ItemUtil       = safeRequire(UtilityFolder, "ItemUtil")
local ToolUtil       = safeRequire(UtilityFolder, "ToolUtil")
local FormatUtil     = safeRequire(UtilityFolder, "Format")
local PurchaseUtil   = safeRequire(UtilityFolder, "PurchaseUtil")
local ResFishBasket  = safeRequire(ConfigFolder,  "ResFishBasket") -- Luck/Frequency
local ResFishBait    = safeRequire(ConfigFolder,  "ResFishBait")
local ResDailyReward = safeRequire(ConfigFolder,  "ResDailyReward")
local MathUtil       = safeRequire(UtilityFolder, "MathUtil")

-- Tambahan untuk Album Collect
local ResFish        = safeRequire(ConfigFolder,  "ResFish")
local ResFishPool    = safeRequire(ConfigFolder,  "ResFishPool")
local FishUtil       = safeRequire(UtilityFolder, "FishUtil")
local ResClimate     = safeRequire(ConfigFolder,  "ResClimate")
local ResEvent       = safeRequire(ConfigFolder,  "ResEvent")
local ViewportUtil   = safeRequire(UtilityFolder, "ViewportUtil") -- optional, tidak wajib dipakai

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
    "FishBasket2",
    "FishBasket3",
    "FishBasket4",
    "FishBasket5",
    "FishBasket7",
    "FishBasket8",
}

local BAIT_IDS = {
    "Bait1",
    "Bait2",
    "Bait3",
    "Bait4",
    "Bait5",
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
    -- via PlayerData Tools (jika sudah siap)
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
    return isToolOwnedGeneric(id)
end

local function isBasketOwned(id)
    return isToolOwnedGeneric(id)
end

------------------- UI HELPERS (TAHOE STYLE LIGHT) -------------------
local harpoonCardsById = {}  -- id -> {frame, buyButton, assetType}
local basketCardsById  = {}  -- id -> {frame, buyButton, assetType}
local baitCardsById    = {}  -- id -> {frame, buyButton, stockLabel, noStockLabel}

-- Daily reward UI state
local dailyCardsByIndex = {} -- index -> {frame, claimButton, claimedLabel, dayLabel, nameLabel, countLabel}
local dailyStatusLabel  = nil
local updateAutoDailyUI = nil

-- Skill cooldown UI updater (akan diisi setelah label dibuat)
local updateSkillCooldownUI = nil

-- Album Collect UI state
local albumCardsByFishId   = {}  -- fishId -> {frame, collectButton, ...}
local albumSeaButtons      = {}  -- seaName -> button
local albumSeaList         = {}  -- list of seaName (ALL + climates/events/worlds)
local albumCurrentSea      = nil
local albumStatusLabel     = nil
local albumAutoToggleFn    = nil
local albumCollectBusy     = false
local albumFishSeas        = {}  -- fishId -> { [seaName] = true, ... }
local albumAllFishIds      = {}  -- semua FishID yg muncul di ResFishPool

-- Nama mutation yg digunakan untuk Album (total 6) → total 9 album/task per fish:
-- 1x GetThing + 2x Size (Min/Max) + 6x Mutation di bawah:
local ALBUM_MUTATION_NAMES = { "Marsh", "Rain", "Big", "Iceborne", "Snow", "Iris" }

-- Helper nilai Album (bisa Attribute atau ValueObject)
local function getAlbumRecordValue(record, names)
    if not record then return nil end
    for _, key in ipairs(names) do
        if typeof(key) == "string" and key ~= "" then
            local v = record:GetAttribute(key)
            if v ~= nil then
                return v
            end
            local obj = record:FindFirstChild(key)
            if obj and obj.Value ~= nil then
                return obj.Value
            end
        end
    end
    return nil
end

local function albumValueIsTrue(v)
    if v == nil then return false end
    local t = typeof(v)
    if t == "boolean" then
        return v
    elseif t == "number" then
        return v ~= 0
    elseif t == "string" then
        return v == "true" or v == "True" or v == "TRUE" or v == "1"
    end
    return false
end

------------------- BASIC UI FACTORIES -------------------
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
    title.Text = "Spear Fishing V3.2++"

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
    subtitle.Text = "AutoFarm Spear v1 + v2 (Trackpad) + AutoEquip Harpoon / Auto Skill 1 & 2 + Album Collect"

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

    -- Aim mengikuti pusat layar (GunAim)
    local viewport = camera.ViewportSize
    local centerX, centerY = viewport.X / 2, viewport.Y / 2

    local ray = camera:ScreenPointToRay(centerX, centerY, 0)
    local origin = ray.Origin
    local direction = ray.Direction

    local destination = origin + direction * 300

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

    -- Jangan ganggu kalau sedang mengetik
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

------------------- SPEAR FISH DATA + UIDS HELPER -------------------
local function ensureSpearFishData()
    if SpearFishData or spearInitTried or not alive then
        return SpearFishData
    end
    spearInitTried = true

    -- Coba lewat shared.WaitPlayerData
    local waitFn
    local okFn, fn = pcall(function()
        return shared and shared.WaitPlayerData
    end)
    if okFn and typeof(fn) == "function" then
        waitFn = fn
    end

    if waitFn then
        local keys = {
            "SpearFish",
            "Spearfish",
            "SpearFishing",
            "SpearFishBag",
            "FishSpear",
            "FishSpearBag",
        }
        for _, key in ipairs(keys) do
            local ok, result = pcall(function()
                return waitFn(key)
            end)
            if ok and result and typeof(result) == "Instance" then
                SpearFishData = result
                break
            end
        end
    end

    -- Fallback: cari folder di LocalPlayer
    if not SpearFishData then
        local keys2 = {
            "SpearFish",
            "Spearfish",
            "SpearFishBag",
            "FishSpear",
            "FishBag",
        }
        for _, name in ipairs(keys2) do
            local inst = LocalPlayer:FindFirstChild(name)
            if inst and inst:IsA("Folder") then
                SpearFishData = inst
                break
            end
        end
    end

    return SpearFishData
end

local function collectAllSpearFishUIDs()
    local data = ensureSpearFishData()
    if not data then
        return nil
    end

    local list = {}

    for _, child in ipairs(data:GetChildren()) do
        local uidValue

        -- Prioritas Attribute "UID"
        local attrUID = child:GetAttribute("UID")
        if attrUID ~= nil then
            uidValue = attrUID
        else
            -- Kalau ada ValueObject bernama "UID"
            local uidObj = child:FindFirstChild("UID")
            if uidObj and uidObj.Value then
                uidValue = uidObj.Value
            end
        end

        -- Fallback: pakai Name kalau numeric panjang
        if uidValue == nil then
            if #child.Name >= 12 and tonumber(child.Name) then
                uidValue = child.Name
            end
        end

        if uidValue ~= nil then
            table.insert(list, tostring(uidValue))
        end
    end

    if #list == 0 then
        return nil
    end

    return list
end

------------------- SELL ALL FISH (SPEAR FISHING) -------------------
local lastSellClock  = 0
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

    local uids = collectAllSpearFishUIDs()
    if not uids or #uids == 0 then
        lastSellClock = now
        notify("Spear Fishing", "Tidak ada ikan spear yang bisa dijual.", 3)
        return
    end

    lastSellClock = now

    local args = {
        [1] = "SellAll",
        [2] = {
            ["UIDs"] = uids
        }
    }

    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)

    if ok then
        notify("Spear Fishing", "Sell All Fish (" .. tostring(#uids) .. " ekor) dikirim.", 3)
    else
        warn("[SpearFishing] SellAll gagal:", err)
        notify("Spear Fishing", "Sell All gagal, cek Output/Console.", 4)
    end
end

------------------- AUTO SKILL 1 & 2 (SEQUENCE, COOLDOWN HANYA DI UI) -------------------
-- Cooldown di bawah ini HANYA untuk informasi UI, bukan limiter eksekusi.
local SKILL1_COOLDOWN    = 15  -- detik (informasi UI)
local SKILL2_COOLDOWN    = 20  -- detik (informasi UI)
local SKILL_SEQUENCE_GAP = 3   -- jeda Skill1 -> Skill2 (eksekusi nyata)

-- Waktu terakhir eksekusi skill (untuk UI countdown)
local skill1LastFireTime = 0
local skill2LastFireTime = 0

-- LOGIC AUTO SKILL 1 (Skill03)
local function fireSkill1()
    if not alive or not autoSkill1 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill03" -- Skill03
        }
    }

    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)
    if ok then
        skill1LastFireTime = os.clock()
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
    else
        warn("[SpearFishing] Auto Skill01 gagal:", err)
    end
end

-- LOGIC AUTO SKILL 2 (Skill01)
local function fireSkill2()
    if not alive or not autoSkill2 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill01" -- Skill01
        }
    }

    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)
    if ok then
        skill2LastFireTime = os.clock()
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
    else
        warn("[SpearFishing] Auto Skill09 gagal:", err)
    end
end

------------------- HELPER: ALBUM DATA / SEA / FISH MAPPING -------------------
local function ensureAlbumData()
    if AlbumData or not alive then
        return AlbumData
    end
    if albumInitStarted then
        return AlbumData
    end
    albumInitStarted = true

    task.spawn(function()
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

        local okAlbum, resultAlbum = pcall(function()
            return waitFn("Album")
        end)
        if okAlbum and resultAlbum and typeof(resultAlbum) == "Instance" then
            AlbumData = resultAlbum
        else
            warn("[SpearFishing] Gagal WaitPlayerData('Album'):", okAlbum and "no result" or resultAlbum)
        end
    end)

    return AlbumData
end

-- List Sea/World/Climate/Event
local function buildAlbumSeaList()
    local seen = {}
    local list = {}

    local function addName(name)
        if type(name) ~= "string" then return end
        if name == "" then return end
        if not seen[name] then
            seen[name] = true
            table.insert(list, name)
        end
    end

    -- Ambil dari ResClimate
    if type(ResClimate) == "table" then
        if type(ResClimate.__index) == "table" then
            for _, name in pairs(ResClimate.__index) do
                addName(name)
            end
        end
        for k, v in pairs(ResClimate) do
            if k ~= "__index" then
                if type(k) == "string" and not tonumber(k) then
                    addName(k)
                end
                addName(v)
            end
        end
    end

    -- Ambil dari ResEvent
    if type(ResEvent) == "table" then
        if type(ResEvent.__index) == "table" then
            for _, name in pairs(ResEvent.__index) do
                addName(name)
            end
        end
        for k, v in pairs(ResEvent) do
            if k ~= "__index" then
                if type(k) == "string" and not tonumber(k) then
                    addName(k)
                end
                addName(v)
            end
        end
    end

    -- Ambil Sea/World langsung dari ResFishPool (Weather/Event/World/Map/Area/Sea/Region)
    if type(ResFishPool) == "table" then
        local keys = { "Weather", "Event", "SeaWorld", "World", "Map", "Area", "Sea", "Region" }
        for _, pool in pairs(ResFishPool) do
            if type(pool) == "table" then
                for _, key in ipairs(keys) do
                    local val = pool[key]
                    if type(val) == "string" then
                        addName(val)
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return tostring(a) < tostring(b)
    end)

    table.insert(list, 1, "ALL")
    albumSeaList = list
end

local function buildAlbumFishMapping()
    albumFishSeas = {}
    albumAllFishIds = {}

    if not ResFishPool then
        return
    end

    local seaKeys = { "Weather", "Event", "SeaWorld", "World", "Map", "Area", "Sea", "Region" }

    for _, pool in pairs(ResFishPool) do
        if type(pool) == "table" then
            local fishId = pool.FishID
            if fishId then
                local seas = albumFishSeas[fishId]
                if not seas then
                    seas = {}
                    albumFishSeas[fishId] = seas
                end
                for _, key in ipairs(seaKeys) do
                    local val = pool[key]
                    if type(val) == "string" then
                        seas[val] = true
                    end
                end
            end
        end
    end

    for fishId, _ in pairs(albumFishSeas) do
        table.insert(albumAllFishIds, fishId)
    end

    table.sort(albumAllFishIds, function(a, b)
        local sa, sb = tostring(a), tostring(b)
        local sortA, sortB = 0, 0
        if ResFish then
            local defA = ResFish[sa] or (ResFish.__index and ResFish.__index[sa])
            local defB = ResFish[sb] or (ResFish.__index and ResFish.__index[sb])
            sortA = defA and defA.Sort or 0
            sortB = defB and defB.Sort or 0
        end
        if sortA == sortB then
            return sa < sb
        else
            return sortA < sortB
        end
    end)
end

local function getFishDisplayName(fishId)
    local name = tostring(fishId)
    if ItemUtil then
        local ok, res = pcall(function()
            return ItemUtil:getName(fishId)
        end)
        if ok and res then
            name = res
        end
    end
    return name
end

local function getFishIcon(fishId)
    local icon = ""
    if ItemUtil then
        local ok, res = pcall(function()
            return ItemUtil:getIcon(fishId)
        end)
        if ok and res then
            icon = res
        end
    end
    return icon
end

-- Hitung Param Album yang masih bisa di-collect untuk 1 fish (maks 9 task)
local function computeAlbumTasksForFish(fishId)
    if not AlbumData then
        return nil, 0
    end

    local record = AlbumData:FindFirstChild(fishId)
    if not record then
        return nil, 0
    end

    local params = {}
    local count = 0

    local function addParam(p)
        table.insert(params, p)
        count = count + 1
    end

    -- 1) GetThing (album pertama kali)
    local gotThing = getAlbumRecordValue(record, { "GetThing", "GotThing", "GetAlbum", "GotAlbum" })
    if not albumValueIsTrue(gotThing) then
        addParam("GetThing")
    end

    -- 2) Size Min / Max
    local gotMax = getAlbumRecordValue(record, { "GetMaxThing", "GotMaxThing" })
    if not albumValueIsTrue(gotMax) then
        addParam("GetMaxThing")
    end

    local gotMin = getAlbumRecordValue(record, { "GetMinThing", "GotMinThing" })
    if not albumValueIsTrue(gotMin) then
        addParam("GetMinThing")
    end

    -- 3) Mutation Album: Marsh/Rain/Big/Iceborne/Snow/Iris
    for _, mutName in ipairs(ALBUM_MUTATION_NAMES) do
        local hasMut = getAlbumRecordValue(record, { mutName, "Has" .. mutName })
        if albumValueIsTrue(hasMut) then
            local paramKey = "Get" .. mutName .. "Thing"
            local done = getAlbumRecordValue(record, { paramKey, "Got" .. mutName .. "Thing" })
            if not albumValueIsTrue(done) then
                addParam(paramKey)
            end
        end
    end

    return params, count
end

local function updateAlbumStatus()
    if not albumStatusLabel then
        return
    end
    if not AlbumData then
        albumStatusLabel.Text = "Album: data belum siap (menunggu PlayerData)."
        return
    end

    local totalFish  = 0
    local totalTasks = 0

    for fishId, entry in pairs(albumCardsByFishId) do
        local frame = entry.frame
        if frame and frame.Parent and frame.Visible then
            totalFish = totalFish + 1
            local _, pending = computeAlbumTasksForFish(fishId)
            totalTasks = totalTasks + (pending or 0)
        end
    end

    local seaLabel = albumCurrentSea or "ALL"
    albumStatusLabel.Text = string.format("Album [%s]: %d fish, %d pending task.", seaLabel, totalFish, totalTasks)
end

local function updateAlbumFishRow(fishId)
    local entry = albumCardsByFishId[fishId]
    if not entry then return end

    local frame        = entry.frame
    if not frame or not frame.Parent then return end

    local nameLabel    = entry.nameLabel
    local countLabel   = entry.countLabel
    local minLabel     = entry.minLabel
    local maxLabel     = entry.maxLabel
    local mutLabel     = entry.mutLabel
    local pendingLabel = entry.pendingLabel
    local collectBtn   = entry.collectButton

    if nameLabel then
        nameLabel.Text = getFishDisplayName(fishId)
    end

    local record = AlbumData and AlbumData:FindFirstChild(fishId) or nil

    -- Catch Count
    local count = 0
    if record then
        local v = getAlbumRecordValue(record, { "Count", "CatchCount", "Catch", "TotalCatch" })
        if v ~= nil then
            if typeof(v) == "number" then
                count = v
            else
                local num = tonumber(v)
                if num then
                    count = num
                end
            end
        end
    end
    if countLabel then
        countLabel.Text = "Catch: " .. tostring(count)
    end

    -- Min / Max size
    local minText, maxText = "Min: -", "Max: -"

    if record then
        local minVal = getAlbumRecordValue(record, { "MinWeight", "Min", "MinW", "WeightMin", "MiniWeight" })
        local maxVal = getAlbumRecordValue(record, { "MaxWeight", "Max", "MaxW", "WeightMax" })

        local function formatWeight(val)
            if val == nil then return nil end
            if FishUtil then
                local ok, desc = pcall(function()
                    return FishUtil:getDescWeight(fishId, val)
                end)
                if ok and desc then
                    return desc
                end
            end
            if typeof(val) == "number" then
                return string.format("%.2f Kg", val)
            end
            return tostring(val)
        end

        local descMin = formatWeight(minVal)
        local descMax = formatWeight(maxVal)

        if descMin then
            minText = "Min: " .. descMin
        end
        if descMax then
            maxText = "Max: " .. descMax
        end
    end

    if minLabel then
        minLabel.Text = minText
    end
    if maxLabel then
        maxLabel.Text = maxText
    end

    -- Mutations list
    if mutLabel then
        local mutNames = {}
        if record then
            for _, mutName in ipairs(ALBUM_MUTATION_NAMES) do
                local v = getAlbumRecordValue(record, { mutName, "Has" .. mutName })
                if albumValueIsTrue(v) then
                    table.insert(mutNames, mutName)
                end
            end
        end
        if #mutNames > 0 then
            mutLabel.Text = "Mutations: " .. table.concat(mutNames, ", ")
        else
            mutLabel.Text = "Mutations: -"
        end
    end

    -- Pending tasks
    local pendingCount = 0
    if AlbumData and record then
        local _, p = computeAlbumTasksForFish(fishId)
        pendingCount = p or 0
    end

    if pendingLabel then
        pendingLabel.Text = string.format("Album Pending: %d/9", pendingCount)
    end

    if collectBtn then
        if pendingCount > 0 then
            collectBtn.Text = "Collect"
            collectBtn.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
            collectBtn.AutoButtonColor = true
            collectBtn.Active = true
        else
            collectBtn.Text = "Done"
            collectBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            collectBtn.AutoButtonColor = false
            collectBtn.Active = false
        end
    end
end

local function collectAlbumForFish(fishId)
    if not FishRE then
        notify("Spear Fishing", "Remote FishRE tidak ditemukan.", 4)
        return 0
    end

    ensureAlbumData()
    if not AlbumData then
        notify("Spear Fishing", "Album: data belum siap.", 3)
        return 0
    end

    local record = AlbumData:FindFirstChild(fishId)
    if not record then
        notify("Spear Fishing", getFishDisplayName(fishId) .. ": album belum terbuka (belum pernah ditangkap).", 3)
        return 0
    end

    local params, pendingCount = computeAlbumTasksForFish(fishId)
    if not params or #params == 0 then
        notify("Spear Fishing", getFishDisplayName(fishId) .. ": tidak ada album yang bisa di-collect.", 3)
        return 0
    end

    local sent = 0
    for _, param in ipairs(params) do
        local args = {
            [1] = "AlbumGetThing",
            [2] = {
                ["ID"]    = fishId,
                ["Param"] = param
            }
        }
        local ok, err = pcall(function()
            FishRE:FireServer(unpack(args))
        end)
        if not ok then
            warn("[SpearFishing] AlbumGetThing gagal:", fishId, param, err)
        else
            sent = sent + 1
        end
        task.wait(0.05)
    end

    task.defer(function()
        updateAlbumFishRow(fishId)
        updateAlbumStatus()
    end)

    return sent
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
    local card, _, _ = createCard(
        parent,
        "Harpoon Shop",
        "Toko Harpoon (Image + DMG + CRT + Charge + Price).",
        3,       -- setelah Spear Controls (1) & Auto Daily Reward (2)
        280      -- diperbesar agar tombol terlihat penuh
    )

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
        item.Size = UDim2.new(0, 150, 0, 210) -- diperbesar
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

    -- pertama kali
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

    -- Ambil Luck & Frequency dari ResFishBasket jika tersedia
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
                -- fallback: cari angka pertama
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

            local freqVal = pickNumber(cfg, {"Frequency", "Freq", "FrequencySec", "Cooldown", "CoolDown", "Interval", "Time"})
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
    local card, _, _ = createCard(
        parent,
        "Basket Shop",
        "Toko Basket (Icon + Luck + Frequency + Price).",
        4,       -- setelah Harpoon Shop
        280      -- diperbesar
    )

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
        item.Size = UDim2.new(0, 150, 0, 210) -- diperbesar
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
    -- subtitle sengaja kosong, kita buat label sendiri agar muat Time Reset
    local card, _, _ = createCard(
        parent,
        "Bait Shop",
        "",
        5,       -- setelah Basket Shop
        280      -- diperbesar
    )

    -- Info + Reset time baris bawah title
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

    -- stock awal
    refreshBaitStock()

    -- update reset time & stok
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

------------------- DAILY REWARD: DATA & UI -------------------
local function findNextClaimableDailyIndex()
    if not ResDailyReward then return nil end
    if not DailyData then return nil end

    for index = 1, #ResDailyReward do
        local child = DailyData:FindFirstChild(tostring(index))
        if child then
            local claimedAttr = child:GetAttribute("claimed")
            if not claimedAttr then
                return index
            end
        end
    end

    return nil
end

local function updateDailyStatusLabel()
    if not dailyStatusLabel then return end

    if not ResDailyReward then
        dailyStatusLabel.Text = "Config ResDailyReward tidak ditemukan."
        return
    end

    local idx = findNextClaimableDailyIndex()
    if idx then
        dailyStatusLabel.Text = "Next klaim tersedia: Day " .. tostring(idx) .. "."
    else
        dailyStatusLabel.Text = "Next klaim tersedia: - (menunggu reset harian)."
    end
end

local function refreshDailyUI()
    if not ResDailyReward then
        updateDailyStatusLabel()
        return
    end

    for index, entry in pairs(dailyCardsByIndex) do
        local claimBtn   = entry.claimButton
        local claimedLbl = entry.claimedLabel

        local child = DailyData and DailyData:FindFirstChild(tostring(index)) or nil
        local claimed  = false
        local claimable = false

        if child then
            local claimedAttr = child:GetAttribute("claimed")
            claimed = (claimedAttr == true)
            claimable = not claimed
        else
            claimed = false
            claimable = false
        end

        if claimBtn then
            claimBtn.Visible = claimable
            claimBtn.Active  = claimable
        end
        if claimedLbl then
            claimedLbl.Visible = claimed
        end
    end

    updateDailyStatusLabel()
end

local function claimDailyReward(index)
    if not DailyRE then
        notify("Spear Fishing", "Remote DailyRE tidak ditemukan.", 4)
        return
    end

    local payload = { index = index }

    local ok, err = pcall(function()
        DailyRE:FireServer(payload)
    end)

    if ok then
        notify("Spear Fishing", "Claim Daily Reward Day " .. tostring(index) .. " dikirim.", 3)
    else
        warn("[SpearFishing] DailyRE:FireServer gagal:", err)
        notify("Spear Fishing", "Gagal claim Daily Reward (Day " .. tostring(index) .. ").", 4)
    end
end

local function initDailyDataWatcher()
    task.spawn(function()
        if DailyData then return end

        -- tunggu sampai shared.WaitPlayerData siap
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
            return waitFn("Daily")
        end)
        if not ok2 or not result then
            warn("[SpearFishing] Gagal WaitPlayerData('Daily'):", ok2 and "no result" or result)
            return
        end

        DailyData = result

        local function onDailyChanged()
            if not alive then return end
            pcall(refreshDailyUI)
        end

        -- Listener existing child
        for _, child in ipairs(DailyData:GetChildren()) do
            if child.AttributeChanged then
                local c = child.AttributeChanged:Connect(function()
                    onDailyChanged()
                end)
                table.insert(connections, c)
            end
        end

        -- Listener child added
        if DailyData.ChildAdded then
            local cAdd = DailyData.ChildAdded:Connect(function(child)
                if not alive then return end
                onDailyChanged()
                if child and child.AttributeChanged then
                    local c = child.AttributeChanged:Connect(function()
                        onDailyChanged()
                    end)
                    table.insert(connections, c)
                end
            end)
            table.insert(connections, cAdd)
        end

        onDailyChanged()
    end)
end

local function buildDailyRewardCard(parent)
    local card, _, _ = createCard(
        parent,
        "Auto Daily Reward",
        "Auto claim + manual claim Daily Reward (Day 1 ~ 30).",
        2,     -- setelah Spear Controls
        320    -- dipanjangkan supaya tulisan CLAIMED tidak kepotong
    )

    local content = Instance.new("Frame")
    content.Name = "DailyContent"
    content.Parent = card
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, 40)
    content.Size = UDim2.new(1, 0, 1, -40)

    -- Toggle Auto Daily Reward (default ON)
    local autoBtn, updateFn = createToggleButton(content, "Auto Daily Reward", autoDailyReward)
    autoBtn.Position = UDim2.new(0, 0, 0, 0)
    autoBtn.Size     = UDim2.new(1, 0, 0, 30)
    updateAutoDailyUI = updateFn
    updateAutoDailyUI(autoDailyReward)

    -- Status label (next klaim day ke berapa)
    local status = Instance.new("TextLabel")
    status.Name = "DailyStatus"
    status.Parent = content
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextColor3 = Color3.fromRGB(185, 185, 185)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextWrapped = true
    status.Position = UDim2.new(0, 0, 0, 34)
    status.Size = UDim2.new(1, 0, 0, 24)
    status.Text = "Next klaim tersedia: --."
    dailyStatusLabel = status

    -- Scroll berisi list Day 1..N (maksimal 30)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "DailyScroll"
    scroll.Parent = content
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 62)
    scroll.Size = UDim2.new(1, 0, 1, -66)
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

    -- Bangun item Day berdasarkan ResDailyReward, maksimal 30
    local totalDays = 0
    if ResDailyReward then
        totalDays = math.min(30, #ResDailyReward)
    else
        totalDays = 0
    end

    for index = 1, totalDays do
        local cfg = ResDailyReward[index]
        local thingId    = cfg and cfg.ThingId
        local thingCount = cfg and cfg.ThingCount or 1
        local iconName   = cfg and cfg.IconName
        local rewardName = cfg and cfg.Name

        local iconImage = ""
        if ItemUtil then
            if not rewardName and thingId then
                local okName, nameRes = pcall(function()
                    return ItemUtil:getName(thingId)
                end)
                if okName and nameRes then
                    rewardName = nameRes
                end
            end

            local iconKey = iconName or thingId
            if iconKey then
                local okIcon, iconRes = pcall(function()
                    return ItemUtil:getIcon(iconKey)
                end)
                if okIcon and iconRes then
                    iconImage = iconRes
                end
            end
        end

        rewardName = rewardName or ("Reward Day " .. tostring(index))

        local item = Instance.new("Frame")
        item.Name = "Day" .. index
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 150, 0, 190)
        item.LayoutOrder = index

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 70)
        stroke.Thickness = 1
        stroke.Parent = item

        local dayLabel = Instance.new("TextLabel")
        dayLabel.Name = "DayLabel"
        dayLabel.Parent = item
        dayLabel.BackgroundTransparency = 1
        dayLabel.Font = Enum.Font.GothamSemibold
        dayLabel.TextSize = 11
        dayLabel.TextXAlignment = Enum.TextXAlignment.Left
        dayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        dayLabel.Position = UDim2.new(0, 6, 0, 6)
        dayLabel.Size = UDim2.new(1, -12, 0, 16)
        dayLabel.Text = "Day " .. tostring(index)

        local img = Instance.new("ImageLabel")
        img.Name = "Icon"
        img.Parent = item
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.Position = UDim2.new(0, 6, 0, 26)
        img.Size = UDim2.new(1, -12, 0, 60)
        img.Image = iconImage or ""
        img.ScaleType = Enum.ScaleType.Fit

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = item
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextYAlignment = Enum.TextYAlignment.Top
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.TextWrapped = true
        nameLabel.Position = UDim2.new(0, 6, 0, 88)
        nameLabel.Size = UDim2.new(1, -12, 0, 30)
        nameLabel.Text = rewardName

        local countLabel = Instance.new("TextLabel")
        countLabel.Name = "Count"
        countLabel.Parent = item
        countLabel.BackgroundTransparency = 1
        countLabel.Font = Enum.Font.Gotham
        countLabel.TextSize = 11
        countLabel.TextXAlignment = Enum.TextXAlignment.Left
        countLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        countLabel.Position = UDim2.new(0, 6, 0, 120)
        countLabel.Size = UDim2.new(1, -12, 0, 16)
        countLabel.Text = "x" .. tostring(thingCount)

        local claimedLabel = Instance.new("TextLabel")
        claimedLabel.Name = "Claimed"
        claimedLabel.Parent = item
        claimedLabel.BackgroundTransparency = 1
        claimedLabel.Font = Enum.Font.GothamSemibold
        claimedLabel.TextSize = 11
        claimedLabel.TextXAlignment = Enum.TextXAlignment.Center
        claimedLabel.TextColor3 = Color3.fromRGB(120, 210, 120)
        claimedLabel.Position = UDim2.new(0, 6, 0, 138)
        claimedLabel.Size = UDim2.new(1, -12, 0, 18)
        claimedLabel.Text = "CLAIMED"
        claimedLabel.Visible = false

        local claimBtn = Instance.new("TextButton")
        claimBtn.Name = "ClaimButton"
        claimBtn.Parent = item
        claimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        claimBtn.BorderSizePixel = 0
        claimBtn.AutoButtonColor = true
        claimBtn.Font = Enum.Font.GothamSemibold
        claimBtn.TextSize = 12
        claimBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        claimBtn.Text = "Claim"
        claimBtn.Position = UDim2.new(0, 6, 1, -26)
        claimBtn.Size = UDim2.new(1, -12, 0, 22)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = claimBtn

        dailyCardsByIndex[index] = {
            frame        = item,
            claimButton  = claimBtn,
            claimedLabel = claimedLabel,
            dayLabel     = dayLabel,
            nameLabel    = nameLabel,
            countLabel   = countLabel,
        }

        local conn = claimBtn.MouseButton1Click:Connect(function()
            claimDailyReward(index)
        end)
        table.insert(connections, conn)
    end

    -- Toggle handler
    local connToggle = autoBtn.MouseButton1Click:Connect(function()
        autoDailyReward = not autoDailyReward
        if updateAutoDailyUI then
            updateAutoDailyUI(autoDailyReward)
        end
        updateDailyStatusLabel()
        notify("Spear Fishing", "Auto Daily Reward: " .. (autoDailyReward and "ON" or "OFF"), 2)
    end)
    table.insert(connections, connToggle)

    updateDailyStatusLabel()

    return card
end

------------------- TOOLSDATA INIT (UNTUK OWNERSHIP REFRESH) -------------------
local function initToolsDataWatcher()
    task.spawn(function()
        if ToolsData then return end

        -- tunggu sampai shared.WaitPlayerData siap
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

------------------- ALBUM COLLECT CARD (UI + LOGIC) -------------------
local function buildAlbumCollectCard(parent)
    -- siapkan list Sea dan mapping fish
    buildAlbumSeaList()
    buildAlbumFishMapping()

    local card, _, _ = createCard(
        parent,
        "Album Collect - Spear Fishing",
        "Collect Album reward per ikan (GetThing, Size, Mutations) + Auto Collect Album.",
        6,   -- setelah Bait Shop
        340
    )

    local content = Instance.new("Frame")
    content.Name = "AlbumContent"
    content.Parent = card
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, 40)
    content.Size = UDim2.new(1, 0, 1, -40)

    -- Collect All + Auto Collect
    local collectAllBtn = Instance.new("TextButton")
    collectAllBtn.Name = "CollectAllButton"
    collectAllBtn.Parent = content
    collectAllBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    collectAllBtn.BorderSizePixel = 0
    collectAllBtn.AutoButtonColor = true
    collectAllBtn.Font = Enum.Font.GothamSemibold
    collectAllBtn.TextSize = 12
    collectAllBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    collectAllBtn.Text = "Collect All Album"
    collectAllBtn.Position = UDim2.new(0, 0, 0, 0)
    collectAllBtn.Size = UDim2.new(0.5, -4, 0, 28)

    local caCorner = Instance.new("UICorner")
    caCorner.CornerRadius = UDim.new(0, 8)
    caCorner.Parent = collectAllBtn

    local autoBtn, autoUpdateFn = createToggleButton(content, "Auto Collect Album", autoCollectAlbum)
    autoBtn.Position = UDim2.new(0.5, 4, 0, 0)
    autoBtn.Size     = UDim2.new(0.5, -4, 0, 28)
    albumAutoToggleFn = autoUpdateFn
    if albumAutoToggleFn then
        albumAutoToggleFn(autoCollectAlbum)
    end

    albumStatusLabel = Instance.new("TextLabel")
    albumStatusLabel.Name = "AlbumStatus"
    albumStatusLabel.Parent = content
    albumStatusLabel.BackgroundTransparency = 1
    albumStatusLabel.Font = Enum.Font.Gotham
    albumStatusLabel.TextSize = 11
    albumStatusLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
    albumStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    albumStatusLabel.TextWrapped = true
    albumStatusLabel.Position = UDim2.new(0, 0, 0, 32)
    albumStatusLabel.Size = UDim2.new(1, 0, 0, 22)
    albumStatusLabel.Text = "Album: data belum siap (menunggu PlayerData)."

    -- Tabs Sea / Climate / Event / World
    local seaScroll = Instance.new("ScrollingFrame")
    seaScroll.Name = "SeaTabs"
    seaScroll.Parent = content
    seaScroll.BackgroundTransparency = 1
    seaScroll.BorderSizePixel = 0
    seaScroll.Position = UDim2.new(0, 0, 0, 56)
    seaScroll.Size = UDim2.new(1, 0, 0, 28)
    seaScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    seaScroll.ScrollBarThickness = 4
    seaScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    seaScroll.ScrollingDirection = Enum.ScrollingDirection.XY
    seaScroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local seaPadding = Instance.new("UIPadding")
    seaPadding.Parent = seaScroll
    seaPadding.PaddingLeft = UDim.new(0, 4)
    seaPadding.PaddingRight = UDim.new(0, 4)

    local seaLayout = Instance.new("UIListLayout")
    seaLayout.Parent = seaScroll
    seaLayout.FillDirection = Enum.FillDirection.Horizontal
    seaLayout.SortOrder = Enum.SortOrder.LayoutOrder
    seaLayout.Padding = UDim.new(0, 6)

    local seaConn = seaLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        seaScroll.CanvasSize = UDim2.new(0, seaLayout.AbsoluteContentSize.X + 8, 0, 0)
    end)
    table.insert(connections, seaConn)

    -- List Fish
    local fishScroll = Instance.new("ScrollingFrame")
    fishScroll.Name = "FishList"
    fishScroll.Parent = content
    fishScroll.BackgroundTransparency = 1
    fishScroll.BorderSizePixel = 0
    fishScroll.Position = UDim2.new(0, 0, 0, 88)
    fishScroll.Size = UDim2.new(1, 0, 1, -92)
    fishScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    fishScroll.ScrollBarThickness = 4
    fishScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local fishPadding = Instance.new("UIPadding")
    fishPadding.Parent = fishScroll
    fishPadding.PaddingLeft = UDim.new(0, 4)
    fishPadding.PaddingRight = UDim.new(0, 4)
    fishPadding.PaddingTop = UDim.new(0, 4)
    fishPadding.PaddingBottom = UDim.new(0, 4)

    local fishLayout = Instance.new("UIListLayout")
    fishLayout.Parent = fishScroll
    fishLayout.FillDirection = Enum.FillDirection.Vertical
    fishLayout.SortOrder = Enum.SortOrder.LayoutOrder
    fishLayout.Padding = UDim.new(0, 4)

    local fishConn = fishLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        fishScroll.CanvasSize = UDim2.new(0, 0, 0, fishLayout.AbsoluteContentSize.Y + 8)
    end)
    table.insert(connections, fishConn)

    -- Helper: filter visible fish by Sea
    local function applySeaFilter()
        for fishId, entry in pairs(albumCardsByFishId) do
            local frame = entry.frame
            if frame and frame.Parent == fishScroll then
                local visible = true
                if albumCurrentSea and albumCurrentSea ~= "ALL" then
                    local seas = entry.seaSet
                    visible = seas and seas[albumCurrentSea] == true
                end
                frame.Visible = visible
            end
        end
        updateAlbumStatus()
    end

    albumSeaButtons = {}

    local function selectSea(seaName)
        albumCurrentSea = seaName
        for name, btn in pairs(albumSeaButtons) do
            if btn and btn.Parent then
                if name == seaName then
                    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 110)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                end
            end
        end
        applySeaFilter()
    end

    -- Build Sea Tabs (termasuk Sea World seperti Nather Island)
    for _, seaName in ipairs(albumSeaList) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. seaName
        btn.Parent = seaScroll
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = true
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.TextXAlignment = Enum.TextXAlignment.Center
        btn.Text = (seaName == "ALL") and "ALL Sea" or seaName
        btn.Size = UDim2.new(0, 90, 1, 0)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        albumSeaButtons[seaName] = btn

        local conn = btn.MouseButton1Click:Connect(function()
            selectSea(seaName)
        end)
        table.insert(connections, conn)
    end

    -- Build Fish Rows (ALL FishID sekali, lalu hanya di-filter Visible)
    albumCardsByFishId = {}

    for idx, fishId in ipairs(albumAllFishIds) do
        local row = Instance.new("Frame")
        row.Name = fishId
        row.Parent = fishScroll
        row.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        row.BackgroundTransparency = 0.1
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, -4, 0, 72)
        row.LayoutOrder = idx

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = row

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 70)
        stroke.Thickness = 1
        stroke.Parent = row

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Parent = row
        icon.BackgroundTransparency = 1
        icon.BorderSizePixel = 0
        icon.Position = UDim2.new(0, 6, 0, 6)
        icon.Size = UDim2.new(0, 60, 1, -12)
        icon.Image = getFishIcon(fishId)
        icon.ScaleType = Enum.ScaleType.Fit

        local infoFrame = Instance.new("Frame")
        infoFrame.Name = "Info"
        infoFrame.Parent = row
        infoFrame.BackgroundTransparency = 1
        infoFrame.BorderSizePixel = 0
        infoFrame.Position = UDim2.new(0, 72, 0, 4)
        infoFrame.Size = UDim2.new(1, -72 - 96, 1, -8)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = infoFrame
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.Size = UDim2.new(1, 0, 0, 16)
        nameLabel.Text = getFishDisplayName(fishId)

        local countLabel = Instance.new("TextLabel")
        countLabel.Name = "Count"
        countLabel.Parent = infoFrame
        countLabel.BackgroundTransparency = 1
        countLabel.Font = Enum.Font.Gotham
        countLabel.TextSize = 11
        countLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        countLabel.TextXAlignment = Enum.TextXAlignment.Left
        countLabel.Position = UDim2.new(0, 0, 0, 18)
        countLabel.Size = UDim2.new(1, 0, 0, 14)
        countLabel.Text = "Catch: -"

        local minLabel = Instance.new("TextLabel")
        minLabel.Name = "Min"
        minLabel.Parent = infoFrame
        minLabel.BackgroundTransparency = 1
        minLabel.Font = Enum.Font.Gotham
        minLabel.TextSize = 11
        minLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        minLabel.TextXAlignment = Enum.TextXAlignment.Left
        minLabel.Position = UDim2.new(0, 0, 0, 34)
        minLabel.Size = UDim2.new(0.48, -2, 0, 14)
        minLabel.Text = "Min: -"

        local maxLabel = Instance.new("TextLabel")
        maxLabel.Name = "Max"
        maxLabel.Parent = infoFrame
        maxLabel.BackgroundTransparency = 1
        maxLabel.Font = Enum.Font.Gotham
        maxLabel.TextSize = 11
        maxLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        maxLabel.TextXAlignment = Enum.TextXAlignment.Left
        maxLabel.Position = UDim2.new(0.5, 0, 0, 34)
        maxLabel.Size = UDim2.new(0.48, -2, 0, 14)
        maxLabel.Text = "Max: -"

        local mutLabel = Instance.new("TextLabel")
        mutLabel.Name = "Mutations"
        mutLabel.Parent = infoFrame
        mutLabel.BackgroundTransparency = 1
        mutLabel.Font = Enum.Font.Gotham
        mutLabel.TextSize = 11
        mutLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        mutLabel.TextXAlignment = Enum.TextXAlignment.Left
        mutLabel.TextTruncate = Enum.TextTruncate.AtEnd
        mutLabel.Position = UDim2.new(0, 0, 0, 50)
        mutLabel.Size = UDim2.new(1, 0, 0, 16)
        mutLabel.Text = "Mutations: -"

        local actionFrame = Instance.new("Frame")
        actionFrame.Name = "Action"
        actionFrame.Parent = row
        actionFrame.BackgroundTransparency = 1
        actionFrame.BorderSizePixel = 0
        actionFrame.Position = UDim2.new(1, -90, 0, 8)
        actionFrame.Size = UDim2.new(0, 84, 1, -16)

        local pendingLabel = Instance.new("TextLabel")
        pendingLabel.Name = "Pending"
        pendingLabel.Parent = actionFrame
        pendingLabel.BackgroundTransparency = 1
        pendingLabel.Font = Enum.Font.Gotham
        pendingLabel.TextSize = 10
        pendingLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        pendingLabel.TextXAlignment = Enum.TextXAlignment.Center
        pendingLabel.Position = UDim2.new(0, 0, 0, 0)
        pendingLabel.Size = UDim2.new(1, 0, 0, 24)
        pendingLabel.Text = "Album Pending: -/9"

        local collectBtn = Instance.new("TextButton")
        collectBtn.Name = "CollectButton"
        collectBtn.Parent = actionFrame
        collectBtn.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
        collectBtn.BorderSizePixel = 0
        collectBtn.AutoButtonColor = true
        collectBtn.Font = Enum.Font.GothamSemibold
        collectBtn.TextSize = 12
        collectBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        collectBtn.Text = "Collect"
        collectBtn.Position = UDim2.new(0, 0, 1, -24)
        collectBtn.Size = UDim2.new(1, 0, 0, 22)

        local collectCorner = Instance.new("UICorner")
        collectCorner.CornerRadius = UDim.new(0, 6)
        collectCorner.Parent = collectBtn

        albumCardsByFishId[fishId] = {
            frame         = row,
            icon          = icon,
            nameLabel     = nameLabel,
            countLabel    = countLabel,
            minLabel      = minLabel,
            maxLabel      = maxLabel,
            mutLabel      = mutLabel,
            pendingLabel  = pendingLabel,
            collectButton = collectBtn,
            seaSet        = albumFishSeas[fishId],
        }

        local connCollect = collectBtn.MouseButton1Click:Connect(function()
            collectAlbumForFish(fishId)
        end)
        table.insert(connections, connCollect)

        -- Initial fill (Name sudah ada, Catch/Min/Max/Mut akan terisi setelah AlbumData siap)
        updateAlbumFishRow(fishId)
    end

    -- default Sea = ALL
    albumCurrentSea = albumSeaList[1] or "ALL"
    selectSea(albumCurrentSea)

    -- Collect All Button
    local connCollectAll = collectAllBtn.MouseButton1Click:Connect(function()
        if albumCollectBusy then
            notify("Spear Fishing", "Album Collect masih berjalan...", 2)
            return
        end

        ensureAlbumData()
        if not AlbumData then
            notify("Spear Fishing", "Album: data belum siap.", 3)
            return
        end

        albumCollectBusy = true
        notify("Spear Fishing", "Collect All Album (" .. (albumCurrentSea or "ALL") .. ") dimulai...", 3)

        task.spawn(function()
            for fishId, entry in pairs(albumCardsByFishId) do
                if not alive then break end
                if entry.frame and entry.frame.Visible then
                    collectAlbumForFish(fishId)
                    task.wait(0.15)
                end
            end
            albumCollectBusy = false
            updateAlbumStatus()
            notify("Spear Fishing", "Collect All Album selesai.", 3)
        end)
    end)
    table.insert(connections, connCollectAll)

    -- Auto Collect Toggle
    local connAutoCollect = autoBtn.MouseButton1Click:Connect(function()
        autoCollectAlbum = not autoCollectAlbum
        if albumAutoToggleFn then
            albumAutoToggleFn(autoCollectAlbum)
        end
        notify("Spear Fishing", "Auto Collect Album: " .. (autoCollectAlbum and "ON" or "OFF"), 2)
    end)
    table.insert(connections, connAutoCollect)

    updateAlbumStatus()

    return card
end

local function initAlbumDataWatcher()
    task.spawn(function()
        if not AlbumData then
            ensureAlbumData()
            while alive and not AlbumData do
                task.wait(0.2)
            end
        end

        if not alive or not AlbumData then
            return
        end

        if albumStatusLabel then
            albumStatusLabel.Text = "Album: data siap. Filter Sea & Collect Album."
        end

        local function hookValue(record, valueObj)
            if not valueObj or not valueObj.Changed then
                return
            end
            local fishId = record.Name
            local conn = valueObj.Changed:Connect(function()
                if not alive then return end
                updateAlbumFishRow(fishId)
                updateAlbumStatus()
            end)
            table.insert(connections, conn)
        end

        local function hookRecord(record)
            if not record then return end
            local fishId = record.Name

            if record.AttributeChanged then
                local cAttr = record.AttributeChanged:Connect(function()
                    if not alive then return end
                    updateAlbumFishRow(fishId)
                    updateAlbumStatus()
                end)
                table.insert(connections, cAttr)
            end

            if record.ChildAdded then
                local cAdd = record.ChildAdded:Connect(function(v)
                    if not alive then return end
                    if v then
                        hookValue(record, v)
                    end
                    updateAlbumFishRow(fishId)
                    updateAlbumStatus()
                end)
                table.insert(connections, cAdd)
            end

            if record.ChildRemoved then
                local cRem = record.ChildRemoved:Connect(function()
                    if not alive then return end
                    updateAlbumFishRow(fishId)
                    updateAlbumStatus()
                end)
                table.insert(connections, cRem)
            end

            for _, v in ipairs(record:GetChildren()) do
                hookValue(record, v)
            end

            updateAlbumFishRow(fishId)
        end

        for _, child in ipairs(AlbumData:GetChildren()) do
            hookRecord(child)
        end
        updateAlbumStatus()

        local connAddRecord = AlbumData.ChildAdded:Connect(function(child)
            if not alive then return end
            hookRecord(child)
            updateAlbumFishRow(child.Name)
            updateAlbumStatus()
        end)
        table.insert(connections, connAddRecord)

        local connRemoveRecord = AlbumData.ChildRemoved:Connect(function(child)
            if not alive then return end
            if child then
                updateAlbumFishRow(child.Name)
            end
            updateAlbumStatus()
        end)
        table.insert(connections, connRemoveRecord)
    end)
end

------------------- BUILD UI: CONTROL CARD (DIBERI SCROLLINGFRAME) -------------------
local header, bodyScroll = createMainLayout()

local controlCard, _, _ = createCard(
    bodyScroll,
    "Spear Controls",
    "AutoFarm v1 + AutoFarm v2 (Tap Trackpad Left/Center) + AutoEquip + Sell All + Auto Skill 1 & 2.",
    1,
    260 -- tinggi cukup, isi di-scroll
)

-- ScrollingFrame untuk tombol2 di Spear Controls supaya tidak numbuk
local controlsScroll = Instance.new("ScrollingFrame")
controlsScroll.Name = "ControlsScroll"
controlsScroll.Parent = controlCard
controlsScroll.BackgroundTransparency = 1
controlsScroll.BorderSizePixel = 0
controlsScroll.Position = UDim2.new(0, 0, 0, 40)
controlsScroll.Size = UDim2.new(1, 0, 1, -40)
controlsScroll.ScrollBarThickness = 4
controlsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
controlsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local controlsPadding = Instance.new("UIPadding")
controlsPadding.Parent = controlsScroll
controlsPadding.PaddingTop = UDim.new(0, 0)
controlsPadding.PaddingBottom = UDim.new(0, 8)
controlsPadding.PaddingLeft = UDim.new(0, 0)
controlsPadding.PaddingRight = UDim.new(0, 0)

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.Parent = controlsScroll
controlsLayout.FillDirection = Enum.FillDirection.Vertical
controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlsLayout.Padding = UDim.new(0, 6)

local controlsConn = controlsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    controlsScroll.CanvasSize = UDim2.new(0, 0, 0, controlsLayout.AbsoluteContentSize.Y + 8)
end)
table.insert(connections, controlsConn)

local autoFarmButton,   updateAutoFarmUI   = createToggleButton(controlsScroll, "AutoFarm Fish", autoFarm)
local autoEquipButton,  updateAutoEquipUI  = createToggleButton(controlsScroll, "AutoEquip Harpoon", autoEquip)
local autoFarmV2Button, updateAutoFarmV2UI = createToggleButton(controlsScroll, "AutoFarm Fish V2", autoFarmV2)

-- Tombol pilih mode V2: Left / Center
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

-- Toggle Auto Skill 1 & 2 (terpisah)
local autoSkill1Button, updateAutoSkill1UI = createToggleButton(controlsScroll, "Auto Skill 1", autoSkill1)
local autoSkill2Button, updateAutoSkill2UI = createToggleButton(controlsScroll, "Auto Skill 2", autoSkill2)

-- Info cooldown skill (base text, hanya info + akan dipakai untuk countdown UI)
local skill1BaseInfoText = string.format(
    "Skill 1 (Skill01) Cooldown server (perkiraan): %d detik (UI info).",
    SKILL1_COOLDOWN
)

local skillInfo1 = Instance.new("TextLabel")
skillInfo1.Name = "Skill1Info"
skillInfo1.Parent = controlsScroll
skillInfo1.BackgroundTransparency = 1
skillInfo1.Font = Enum.Font.Gotham
skillInfo1.TextSize = 11
skillInfo1.TextColor3 = Color3.fromRGB(185, 185, 185)
skillInfo1.TextXAlignment = Enum.TextXAlignment.Left
skillInfo1.TextWrapped = true
skillInfo1.Size = UDim2.new(1, 0, 0, 18)
skillInfo1.Text = skill1BaseInfoText

local skill2BaseInfoText = string.format(
    "Skill 2 (Skill09) Cooldown server (perkiraan): %d detik (UI info). Jeda antar Skill1 -> Skill2: %d detik.",
    SKILL2_COOLDOWN,
    SKILL_SEQUENCE_GAP
)

local skillInfo2 = Instance.new("TextLabel")
skillInfo2.Name = "Skill2Info"
skillInfo2.Parent = controlsScroll
skillInfo2.BackgroundTransparency = 1
skillInfo2.Font = Enum.Font.Gotham
skillInfo2.TextSize = 11
skillInfo2.TextColor3 = Color3.fromRGB(185, 185, 185)
skillInfo2.TextXAlignment = Enum.TextXAlignment.Left
skillInfo2.TextWrapped = true
skillInfo2.Size = UDim2.new(1, 0, 0, 30)
skillInfo2.Text = skill2BaseInfoText

-- Fungsi untuk update tulisan cooldown Skill1 & Skill2 (hanya UI)
updateSkillCooldownUI = function()
    local now = os.clock()

    if skillInfo1 then
        local text1 = skill1BaseInfoText
        if skill1LastFireTime > 0 then
            local elapsed = now - skill1LastFireTime
            local remaining = SKILL1_COOLDOWN - elapsed
            if remaining > 0 then
                text1 = string.format("%s | Sisa: %ds", skill1BaseInfoText, math.ceil(remaining))
            else
                text1 = string.format("%s | Ready", skill1BaseInfoText)
            end
        end
        skillInfo1.Text = text1
    end

    if skillInfo2 then
        local text2 = skill2BaseInfoText
        if skill2LastFireTime > 0 then
            local elapsed = now - skill2LastFireTime
            local remaining = SKILL2_COOLDOWN - elapsed
            if remaining > 0 then
                text2 = string.format("%s | Sisa: %ds", skill2BaseInfoText, math.ceil(remaining))
            else
                text2 = string.format("%s | Ready", skill2BaseInfoText)
            end
        end
        skillInfo2.Text = text2
    end
end

-- Inisialisasi tampilan cooldown awal
updateSkillCooldownUI()

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
statusLabel.Text = ""

local function updateStatusLabel()
    statusLabel.Text = string.format(
        "Status: AutoFarm %s, AutoEquip %s, AutoFarm V2 %s (%s), Skill1 %s, Skill2 %s, AutoAlbum %s.",
        autoFarm and "ON" or "OFF",
        autoEquip and "ON" or "OFF",
        autoFarmV2 and "ON" or "OFF",
        autoFarmV2Mode,
        autoSkill1 and "ON" or "OFF",
        autoSkill2 and "ON" or "OFF",
        autoCollectAlbum and "ON" or "OFF"
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

    local connSkill1 = autoSkill1Button.MouseButton1Click:Connect(function()
        autoSkill1 = not autoSkill1
        updateAutoSkill1UI(autoSkill1)
        updateStatusLabel()
    end)
    table.insert(connections, connSkill1)

    local connSkill2 = autoSkill2Button.MouseButton1Click:Connect(function()
        autoSkill2 = not autoSkill2
        updateAutoSkill2UI(autoSkill2)
        updateStatusLabel()
    end)
    table.insert(connections, connSkill2)

    local conn3 = sellButton.MouseButton1Click:Connect(function()
        sellAllFish()
    end)
    table.insert(connections, conn3)

    updateStatusLabel()
end

------------------- KEY G HOTKEY (TOGGLE AUTOFARM V2) -------------------
local function onInputBegan(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.G then return end
    if UserInputService:GetFocusedTextBox() then return end

    autoFarmV2 = not autoFarmV2
    updateAutoFarmV2UI(autoFarmV2)
    updateStatusLabel()
    notify("Spear Fishing", "AutoFarm V2: " .. (autoFarmV2 and "ON" or "OFF") .. " (Key G)", 2)
end

do
    local connInput = UserInputService.InputBegan:Connect(onInputBegan)
    table.insert(connections, connInput)
end

------------------- BUILD UI: DAILY REWARD + SHOP + ALBUM CARDS -------------------
buildDailyRewardCard(bodyScroll)
buildHarpoonShopCard(bodyScroll)
buildBasketShopCard(bodyScroll)
buildBaitShopCard(bodyScroll)
buildAlbumCollectCard(bodyScroll)

-- setelah semua card terbentuk, inisialisasi ToolsData, DailyData, dan AlbumData watcher
initToolsDataWatcher()
initDailyDataWatcher()
initAlbumDataWatcher()

------------------- BACKPACK / CHARACTER EVENT UNTUK OWNED / EQUIP + DAILY -------------------
do
    local connCharAdded = LocalPlayer.CharacterAdded:Connect(function(newChar)
        character = newChar
        task.delay(1, function()
            if alive then
                ensureHarpoonEquipped()
                refreshHarpoonOwnership()
                refreshBasketOwnership()
                refreshDailyUI()
                updateAlbumStatus()
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

-- Loop Auto Daily Reward (cek periodik, sangat ringan)
task.spawn(function()
    while alive do
        if autoDailyReward then
            local idx = findNextClaimableDailyIndex()
            if idx then
                claimDailyReward(idx)
            end
        end
        task.wait(5) -- cukup jarang agar tidak berat
    end
end)

-- Loop Auto Skill sequence:
--  - Jika Skill1 dan Skill2 ON: Skill1 -> wait 3s -> Skill2 -> wait 3s -> ulang
--  - Jika hanya salah satu ON: skill itu di-try setiap ~1s
task.spawn(function()
    while alive do
        if autoSkill1 or autoSkill2 then
            if autoSkill1 and autoSkill2 then
                -- Sequence penuh 1 -> 2
                pcall(fireSkill1)
                local t = 0
                while t < SKILL_SEQUENCE_GAP and alive and autoSkill1 and autoSkill2 do
                    task.wait(0.2)
                    t = t + 0.2
                end
                if not alive then break end
                if autoSkill1 and autoSkill2 then
                    pcall(fireSkill2)
                    t = 0
                    while t < SKILL_SEQUENCE_GAP and alive and autoSkill1 and autoSkill2 do
                        task.wait(0.2)
                        t = t + 0.2
                    end
                end
            else
                -- Hanya satu skill aktif, spam ringan (1 detik interval)
                if autoSkill1 then
                    pcall(fireSkill1)
                elseif autoSkill2 then
                    pcall(fireSkill2)
                end
                local t = 0
                while t < 1 and alive and (autoSkill1 or autoSkill2) do
                    task.wait(0.2)
                    t = t + 0.2
                end
            end
        else
            task.wait(0.5)
        end
    end
end)

-- Loop UI Cooldown Skill (murni visual, sangat ringan)
task.spawn(function()
    while alive do
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
        task.wait(0.2)
    end
end)

-- Loop Auto Collect Album (cek album yang pending di Sea aktif, ringan)
task.spawn(function()
    while alive do
        if autoCollectAlbum and AlbumData and not albumCollectBusy then
            local processed = 0
            for fishId, entry in pairs(albumCardsByFishId) do
                if not alive or not autoCollectAlbum then break end
                if entry.frame and entry.frame.Visible then
                    local _, pending = computeAlbumTasksForFish(fishId)
                    if pending and pending > 0 then
                        collectAlbumForFish(fishId)
                        processed = processed + 1
                        if processed >= 3 then
                            break
                        end
                    end
                end
            end
        end
        task.wait(6)
    end
end)

------------------- TAB CLEANUP INTEGRASI CORE -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive            = false
    autoFarm         = false
    autoEquip        = false
    autoFarmV2       = false
    autoDailyReward  = false
    autoSkill1       = false
    autoSkill2       = false
    autoCollectAlbum = false

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
