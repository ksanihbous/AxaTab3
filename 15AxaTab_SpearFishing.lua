--==========================================================
--  15AxaTab_SpearFishing.lua
--  TAB 15: "Spear Fishing PRO++ (AutoFarm + Harpoon/Basket/Bait Shop + Auto Daily Reward + Auto Skill + Spawn Boss Notifier + HP Boss Notifier + Spawn Illahi Notifier)"
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
local MarketplaceService  = game:GetService("MarketplaceService")

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
-- Spawn Illahi Notifier state (default ON kecuali pernah diset false di _G)
_G.AxaHub.SpawnIllahiNotifier = (_G.AxaHub.SpawnIllahiNotifier ~= false)

local alive              = true
local autoFarm           = false      -- AutoFarm Fish v1: default OFF
local autoEquip          = false      -- AutoEquip Harpoon: default OFF
local autoFarmV2         = false      -- AutoFarm Fish V2 (tap trackpad): default OFF
local autoFarmV2Mode     = "Left"     -- "Left" / "Center"
local spawnBossNotifier  = true       -- Spawn Boss Notifier: default ON
local hpBossNotifier     = true       -- HPBar Boss Notifier: default ON

-- interval click AutoFarm V2 (detik)
local autoFarmV2TapInterval = 0.03    -- default cepat
local TAP_INTERVAL_MIN      = 0.01
local TAP_INTERVAL_MAX      = 1.00

local autoDailyReward = true          -- Auto Daily Reward: default ON

-- Auto Skill (DEFAULT ON)
local autoSkill1      = true          -- Auto Skill 1: default ON (Damage Power II)
local autoSkill2      = true          -- Auto Skill 2: default ON (Damage Power III)
local autoSkill3      = true          -- Auto Skill 3: default ON (Skill01 - Thunder)
local autoSkill4      = true          -- Auto Skill 4: default ON (Skill07 - Laceration Creation)
local autoSkill5      = true          -- Auto Skill 5: default ON (Skill09 - Chain Lightning)

local character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local backpack        = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")

local connections     = {}
local ToolsData       = nil           -- WaitPlayerData("Tools")
local DailyData       = nil           -- WaitPlayerData("Daily")
local SpearFishData   = nil           -- WaitPlayerData(...) / Folder spearfish
local spearInitTried  = false

------------------- REMOTES & GAME INSTANCES -------------------
local RepRemotes    = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE        = RepRemotes and RepRemotes:FindFirstChild("FireRE")   -- Fire harpoon
local ToolRE        = RepRemotes and RepRemotes:FindFirstChild("ToolRE")   -- Buy / Switch harpoon & basket
local FishRE        = RepRemotes and RepRemotes:FindFirstChild("FishRE")   -- Sell spear-fish + Skill
local BaitRE        = RepRemotes and RepRemotes:FindFirstChild("BaitRE")   -- Buy bait
local DailyRE       = RepRemotes and RepRemotes:FindFirstChild("DailyRE")  -- Daily reward claim

local GameFolder    = ReplicatedStorage:FindFirstChild("Game")
local FishBaitShop  = GameFolder and GameFolder:FindFirstChild("FishBaitShop") -- NumberValue + atribut stok bait

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
local ResFishBasket  = safeRequire(ConfigFolder,  "ResFishBasket")
local ResFishBait    = safeRequire(ConfigFolder,  "ResFishBait")
local ResDailyReward = safeRequire(ConfigFolder,  "ResDailyReward")
local MathUtil       = safeRequire(UtilityFolder, "MathUtil")
local FishUtil       = safeRequire(UtilityFolder, "FishUtil")

-- Nama game / map (dipakai di embed)
local GAME_NAME = "Unknown Map"
do
    local okInfo, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if okInfo and info and info.Name then
        GAME_NAME = tostring(info.Name)
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

------------------- UI HELPERS (TAHOE STYLE LIGHT) -------------------
local harpoonCardsById = {}
local basketCardsById  = {}
local baitCardsById    = {}

local dailyCardsByIndex = {}
local dailyStatusLabel  = nil
local updateAutoDailyUI = nil

local updateSkillCooldownUI = nil

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
    title.Text = "Spear Fishing V3.4"

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
    subtitle.Text = "AutoFarm Spear + AutoEquip + Auto Skill 1 ~ 5 + Spawn Notifier + HP Boss Notifier + Spawn Illahi Notifier"

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

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        bodyScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end))

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

        local attrUID = child:GetAttribute("UID")
        if attrUID ~= nil then
            uidValue = attrUID
        else
            local uidObj = child:FindFirstChild("UID")
            if uidObj and uidObj.Value then
                uidValue = uidObj.Value
            end
        end

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

------------------- AUTO SKILL 1 ~ 5 -------------------
local SKILL1_COOLDOWN    = 15
local SKILL2_COOLDOWN    = 20
local SKILL_SEQUENCE_GAP = 3

local skill1LastFireTime = 0
local skill2LastFireTime = 0
local skill3LastFireTime = 0
local skill4LastFireTime = 0
local skill5LastFireTime = 0

local function fireSkill1()
    if not alive or not autoSkill1 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill02"
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
        warn("[SpearFishing] Auto Skill02 gagal:", err)
    end
end

local function fireSkill2()
    if not alive or not autoSkill2 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill08"
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
        warn("[SpearFishing] Auto Skill08 gagal:", err)
    end
end

local function fireSkill3()
    if not alive or not autoSkill3 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill01"
        }
    }

    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)
    if ok then
        skill3LastFireTime = os.clock()
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
    else
        warn("[SpearFishing] Auto Skill01 gagal:", err)
    end
end

local function fireSkill4()
    if not alive or not autoSkill4 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill07"
        }
    }

    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)
    if ok then
        skill4LastFireTime = os.clock()
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
    else
        warn("[SpearFishing] Auto Skill07 gagal:", err)
    end
end

local function fireSkill5()
    if not alive or not autoSkill5 then return end
    if not FishRE then return end

    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = "Skill09"
        }
    }

    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)
    if ok then
        skill5LastFireTime = os.clock()
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
    else
        warn("[SpearFishing] Auto Skill09 gagal:", err)
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
    local card, _, _ = createCard(
        parent,
        "Harpoon Shop",
        "Toko Harpoon (Image + DMG + CRT + Charge + Price).",
        3,
        280
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

        table.insert(connections, buyBtn.MouseButton1Click:Connect(onBuy))
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
        4,
        280
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

        table.insert(connections, buyBtn.MouseButton1Click:Connect(onBuy))
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
    local card, _, _ = createCard(
        parent,
        "Bait Shop",
        "",
        5,
        280
    )

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

        table.insert(connections, buyBtn.MouseButton1Click:Connect(onBuy))
    end

    refreshBaitStock()

    if FishBaitShop then
        table.insert(connections, FishBaitShop.Changed:Connect(function(value)
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
        end))

        table.insert(connections, FishBaitShop.AttributeChanged:Connect(function()
            if not alive then return end
            refreshBaitStock()
        end))
    end

    return card
end

------------------- SPAWN BOSS / HP BOSS NOTIFIER: DISCORD EMBED -------------------
local SPAWN_BOSS_WEBHOOK_URL   = "https://discord.com/api/webhooks/1435079884073341050/vEy2YQrpQQcN7pMs7isWqPtylN_AyJbzCAo_xDqM7enRacbIBp43SG1IR_hH-3j4zrfW"
local SPAWN_BOSS_BOT_USERNAME  = "Spawn Boss Notifier"
local SPAWN_BOSS_BOT_AVATAR    = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png"
local DEFAULT_OWNER_DISCORD    = "<@1403052152691101857>"

local HP_BOSS_WEBHOOK_URL      = "https://discord.com/api/webhooks/1456150372686237849/NTDxNaXWeJ1ytvzTo9vnmG5Qvbl6gsvZor4MMb9rWUwKT4fFkRQ9NbNiPsy7-TWogTmR"
local HP_BOSS_BOT_USERNAME     = "HP Boss Notifier"

local BOSS_ID_NAME_MAP = {
    Boss01 = "Humpback Whale",
    Boss02 = "Whale Shark",
    Boss03 = "Crimson Rift Dragon",
}

local NEAR_REMAIN_THRESHOLD = 240

local bossRegionState        = {}
local hpRegionState          = {}
local spawnBossRequestFunc   = nil

local function getSpawnBossRequestFunc()
    if spawnBossRequestFunc then
        return spawnBossRequestFunc
    end

    if syn and syn.request then
        spawnBossRequestFunc = syn.request
    elseif http and http.request then
        spawnBossRequestFunc = http.request
    elseif http_request then
        spawnBossRequestFunc = http_request
    elseif request then
        spawnBossRequestFunc = request
    end

    return spawnBossRequestFunc
end

local function sendSpawnBossWebhookEmbed(embed)
    if not SPAWN_BOSS_WEBHOOK_URL or SPAWN_BOSS_WEBHOOK_URL == "" then
        return
    end

    local payload = {
        username   = SPAWN_BOSS_BOT_USERNAME,
        avatar_url = SPAWN_BOSS_BOT_AVATAR,
        content    = DEFAULT_OWNER_DISCORD,
        embeds     = { embed },
    }

    local encoded
    local okEncode, resEncode = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if okEncode then
        encoded = resEncode
    else
        warn("[SpearFishing] SpawnBoss JSONEncode failed:", resEncode)
        return
    end

    local reqFunc = getSpawnBossRequestFunc()
    if reqFunc then
        local okReq, resReq = pcall(reqFunc, {
            Url     = SPAWN_BOSS_WEBHOOK_URL,
            Method  = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body    = encoded,
        })
        if not okReq then
            warn("[SpearFishing] SpawnBoss webhook request failed:", resReq)
        end
    else
        local okPost, errPost = pcall(function()
            HttpService:PostAsync(SPAWN_BOSS_WEBHOOK_URL, encoded, Enum.HttpContentType.ApplicationJson, false)
        end)
        if not okPost then
            warn("[SpearFishing] SpawnBoss HttpService PostAsync failed:", errPost)
        end
    end
end

local function sendHpBossWebhookEmbed(embed)
    if not HP_BOSS_WEBHOOK_URL or HP_BOSS_WEBHOOK_URL == "" then
        return
    end

    local payload = {
        username   = HP_BOSS_BOT_USERNAME,
        avatar_url = SPAWN_BOSS_BOT_AVATAR,
        content    = DEFAULT_OWNER_DISCORD,
        embeds     = { embed },
    }

    local encoded
    local okEncode, resEncode = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if okEncode then
        encoded = resEncode
    else
        warn("[SpearFishing] HPBoss JSONEncode failed:", resEncode)
        return
    end

    local reqFunc = getSpawnBossRequestFunc()
    if reqFunc then
        local okReq, resReq = pcall(reqFunc, {
            Url     = HP_BOSS_WEBHOOK_URL,
            Method  = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body    = encoded,
        })
        if not okReq then
            warn("[SpearFishing] HPBoss webhook request failed:", resReq)
        end
    else
        local okPost, errPost = pcall(function()
            HttpService:PostAsync(HP_BOSS_WEBHOOK_URL, encoded, Enum.HttpContentType.ApplicationJson, false)
        end)
        if not okPost then
            warn("[SpearFishing] HPBoss HttpService PostAsync failed:", errPost)
        end
    end
end

local function getRegionNameForBoss(region)
    if not region or not region.Name then
        return "Unknown"
    end

    local attrName = region:GetAttribute("RegionName")
    if type(attrName) == "string" and attrName ~= "" then
        return attrName
    end

    return region.Name
end

local function getBossNameForRegion(region)
    if not region then
        return "Unknown Boss"
    end

    for id, display in pairs(BOSS_ID_NAME_MAP) do
        local found = region:FindFirstChild(id, true)
        if found then
            return display
        end
    end

    if FishUtil and ItemUtil then
        local okDesc, descendants = pcall(function()
            return region:GetDescendants()
        end)
        if okDesc and descendants then
            for _, inst in ipairs(descendants) do
                if inst:IsA("BasePart") then
                    local okFish, isFish = pcall(function()
                        return FishUtil:isFish(inst)
                    end)
                    if okFish and isFish then
                        local fishId = inst.Name
                        if BOSS_ID_NAME_MAP[fishId] then
                            return BOSS_ID_NAME_MAP[fishId]
                        end
                        local okName, niceName = pcall(function()
                            return ItemUtil:getName(fishId)
                        end)
                        if okName and type(niceName) == "string" and niceName ~= "" then
                            return niceName
                        end
                    end
                end
            end
        end
    end

    return "Unknown Boss"
end

local function formatBossRemainingText(remainSeconds)
    remainSeconds = tonumber(remainSeconds) or 0
    if remainSeconds < 0 then
        remainSeconds = 0
    end

    local mmss
    if MathUtil then
        local okFmt, res = pcall(function()
            return MathUtil:secondsToMMSS(remainSeconds)
        end)
        if okFmt and type(res) == "string" and res ~= "" then
            mmss = res
        end
    end

    if not mmss then
        local total = math.floor(remainSeconds + 0.5)
        local m = math.floor(total / 60)
        local s = total % 60
        mmss = string.format("%02d:%02d", m, s)
    end

    return "Time Now: Guranteed Devine Boss In " .. mmss .. " menit"
end

local function buildSpawnBossEmbed(region, stageKey, remainSeconds, bossName)
    local remainingText

    if stageKey == "spawn" then
        remainingText = "Time Now: Guranteed Devine Boss In 00:00 menit"
    else
        remainingText = formatBossRemainingText(remainSeconds)
    end

    bossName = bossName or "Unknown Boss"

    local regionName = getRegionNameForBoss(region)

    local stageText
    local colorInt

    if stageKey == "start" then
        stageText = "Timer mulai"
        colorInt  = 0x00BFFF
    elseif stageKey == "near" then
        stageText = "Sisa waktu 3-4 menit"
        colorInt  = 0xFFA500
    elseif stageKey == "spawn" then
        stageText = "Boss Spawned"
        colorInt  = 0xFF0000
    else
        stageText = tostring(stageKey)
        colorInt  = 0xFFFFFF
    end

    local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
    local username    = LocalPlayer.Name or "Player"
    local userId      = LocalPlayer.UserId or 0

    local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

    local serverId = game.JobId
    if not serverId or serverId == "" then
        serverId = "N/A"
    end

    local embed = {
        title       = "Spawn Boss",
        description = DEFAULT_OWNER_DISCORD,
        color       = colorInt,
        fields      = {
            {
                name   = "Remaining Time",
                value  = remainingText,
                inline = false,
            },
            {
                name   = "Name Boss",
                value  = bossName,
                inline = true,
            },
            {
                name   = "Region",
                value  = regionName,
                inline = true,
            },
            {
                name   = "Stage",
                value  = stageText,
                inline = false,
            },
            {
                name   = "Name Map",
                value  = GAME_NAME,
                inline = false,
            },
            {
                name   = "Player",
                value  = playerValue,
                inline = false,
            },
            {
                name   = "Server ID",
                value  = serverId,
                inline = false,
            },
        },
        footer = {
            text = "Spear Fishing PRO+",
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    }

    return embed
end

local function buildHpBossEmbed(region, bossName, curHpText, maxHpText, percentText)
    bossName    = bossName or "Unknown Boss"
    curHpText   = curHpText or "0"
    maxHpText   = maxHpText or "0"
    percentText = percentText or "0%"

    local regionName = getRegionNameForBoss(region)

    local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
    local username    = LocalPlayer.Name or "Player"
    local userId      = LocalPlayer.UserId or 0
    local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

    local serverId = game.JobId
    if not serverId or serverId == "" then
        serverId = "N/A"
    end

    local description = string.format(
        "%s\nHP %s: %s / %s (%s)",
        DEFAULT_OWNER_DISCORD,
        bossName,
        curHpText,
        maxHpText,
        percentText
    )

    local embed = {
        title       = "HP Boss",
        description = description,
        color       = 0x00FF00,
        fields      = {
            {
                name   = "Boss",
                value  = bossName,
                inline = true,
            },
            {
                name   = "HP",
                value  = curHpText .. " / " .. maxHpText,
                inline = true,
            },
            {
                name   = "HP Percent",
                value  = percentText,
                inline = true,
            },
            {
                name   = "Region",
                value  = regionName,
                inline = true,
            },
            {
                name   = "Name Map",
                value  = GAME_NAME,
                inline = false,
            },
            {
                name   = "Player",
                value  = playerValue,
                inline = false,
            },
            {
                name   = "Server ID",
                value  = serverId,
                inline = false,
            },
        },
        footer = {
            text = "Spear Fishing PRO+ | HP Boss Notifier",
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    }

    return embed
end

local function sendSpawnBossStage(region, stageKey, remainSeconds)
    if not alive then
        return
    end
    if not spawnBossNotifier then
        return
    end

    local bossName
    if stageKey == "spawn" then
        bossName = getBossNameForRegion(region)
    else
        bossName = "Unknown Boss"
    end

    local embed = buildSpawnBossEmbed(region, stageKey, remainSeconds, bossName)
    sendSpawnBossWebhookEmbed(embed)
end

local function updateWorldBossRegion(region)
    if not region then
        return
    end

    local state = bossRegionState[region]
    if not state then
        state = {
            sentStart = false,
            sentNear  = false,
            sentSpawn = false,
        }
        bossRegionState[region] = state
    end

    local hasBoss   = region:GetAttribute("HasBoss")
    local remainRaw = region:GetAttribute("RemainTime")
    local remain    = tonumber(remainRaw) or 0

    if not hasBoss and remain <= 0 then
        state.sentStart = false
        state.sentNear  = false
        state.sentSpawn = false
    end

    if remain > 0 and not hasBoss and not state.sentStart then
        state.sentStart = true
        task.spawn(function()
            sendSpawnBossStage(region, "start", remain)
        end)
    end

    if remain > 0
        and remain <= NEAR_REMAIN_THRESHOLD
        and remain >= 180
        and state.sentStart
        and not state.sentNear
    then
        state.sentNear = true
        task.spawn(function()
            sendSpawnBossStage(region, "near", remain)
        end)
    end

    if hasBoss and not state.sentSpawn then
        state.sentSpawn = true
        task.spawn(function()
            sendSpawnBossStage(region, "spawn", remain)
        end)
    end
end

------------------- HP BOSS NOTIFIER -------------------
local HP_SEND_MIN_INTERVAL = 1.5
local HP_MIN_DELTA_RATIO   = 0.005

local function getBossPartInRegion(region)
    if not region then
        return nil
    end

    local okDesc, descendants = pcall(function()
        return region:GetDescendants()
    end)
    if not okDesc or not descendants then
        return nil
    end

    if FishUtil then
        for _, inst in ipairs(descendants) do
            if inst:IsA("BasePart") then
                local isFish = false
                local okFish, resFish = pcall(function()
                    return FishUtil:isFish(inst)
                end)
                if okFish and resFish then
                    isFish = true
                end

                if isFish then
                    local hpAttr = inst:GetAttribute("CurHP") or inst:GetAttribute("CurHp") or inst:GetAttribute("HP") or inst:GetAttribute("Hp")
                    if hpAttr ~= nil then
                        return inst
                    end
                end
            end
        end
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") then
            local hpAttr = inst:GetAttribute("CurHP") or inst:GetAttribute("CurHp") or inst:GetAttribute("HP") or inst:GetAttribute("Hp")
            if hpAttr ~= nil then
                return inst
            end
        end
    end

    return nil
end

local function detachHpWatcher(region)
    local state = hpRegionState[region]
    if not state then
        return
    end

    local function safeDisc(conn)
        if conn and conn.Disconnect then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end

    safeDisc(state.conn)
    safeDisc(state.connCurHP)
    safeDisc(state.connHP)
    safeDisc(state.connHp)

    hpRegionState[region] = nil
end

local function sendHpBossProgress(region, bossPart)
    if not alive then
        return
    end

    local state = hpRegionState[region]
    if not state or state.bossPart ~= bossPart then
        return
    end

    local rawCur = bossPart:GetAttribute("CurHP") or bossPart:GetAttribute("CurHp")
    local rawMax = bossPart:GetAttribute("HP")   or bossPart:GetAttribute("Hp")

    if rawCur == nil and rawMax ~= nil then
        rawCur = rawMax
    elseif rawCur ~= nil and rawMax == nil then
        rawMax = rawCur
    end

    local curHp   = tonumber(rawCur or 0) or 0
    local totalHp = tonumber(rawMax or 0) or 0
    if totalHp <= 0 then
        totalHp = curHp
    end

    if totalHp <= 0 and curHp <= 0 then
        detachHpWatcher(region)
        return
    end

    local now      = os.clock()
    local lastHp   = state.lastHp
    local lastSend = state.lastSendTime or 0

    local changed
    if lastHp == nil then
        changed = true
    else
        changed = (curHp ~= lastHp)
    end

    if not changed then
        return
    end

    local dropRatio = 0
    if totalHp > 0 and lastHp ~= nil and lastHp > 0 then
        dropRatio = math.abs(curHp - lastHp) / totalHp
    end

    if not hpBossNotifier then
        state.lastHp = curHp
        return
    end

    local mustSend = false

    if lastHp == nil then
        mustSend = true
    elseif curHp <= 0 and lastHp > 0 then
        mustSend = true
    elseif (now - lastSend) >= HP_SEND_MIN_INTERVAL and dropRatio >= HP_MIN_DELTA_RATIO then
        mustSend = true
    elseif (now - lastSend) >= 5 then
        mustSend = true
    end

    state.lastHp = curHp
    if not mustSend then
        return
    end
    state.lastSendTime = now

    local curText   = tostring(curHp)
    local maxText   = tostring(totalHp)
    if FormatUtil then
        local ok1, res1 = pcall(function()
            return FormatUtil:DesignNumberShort(curHp)
        end)
        if ok1 and res1 then
            curText = res1
        end

        local ok2, res2 = pcall(function()
            return FormatUtil:DesignNumberShort(totalHp)
        end)
        if ok2 and res2 then
            maxText = res2
        end
    end

    local percentText = "N/A"
    if totalHp > 0 then
        local percent = math.max(0, math.min(1, curHp / totalHp)) * 100
        percentText = string.format("%.2f%%", percent)
    end

    local bossName = getBossNameForRegion(region)
    local embed    = buildHpBossEmbed(region, bossName, curText, maxText, percentText)
    sendHpBossWebhookEmbed(embed)

    if curHp <= 0 then
        detachHpWatcher(region)
    end
end

local function attachHpWatcher(region)
    if not region then
        return
    end

    local hasBoss = region:GetAttribute("HasBoss")
    if not hasBoss then
        detachHpWatcher(region)
        return
    end

    local bossPart = getBossPartInRegion(region)
    if not bossPart then
        return
    end

    local state = hpRegionState[region]
    if state and state.bossPart == bossPart and (state.conn or state.connCurHP or state.connHP or state.connHp) then
        return
    end

    detachHpWatcher(region)

    state = {
        bossPart     = bossPart,
        lastHp       = nil,
        lastSendTime = 0,
        conn         = nil,
        connCurHP    = nil,
        connHP       = nil,
        connHp       = nil,
    }
    hpRegionState[region] = state

    local function onHpAttributeChanged()
        if not alive then return end
        sendHpBossProgress(region, bossPart)
    end

    local connCur = bossPart:GetAttributeChangedSignal("CurHP"):Connect(onHpAttributeChanged)
    state.connCurHP = connCur
    table.insert(connections, connCur)

    local connCur2 = bossPart:GetAttributeChangedSignal("CurHp"):Connect(onHpAttributeChanged)
    state.conn = connCur2
    table.insert(connections, connCur2)

    local connHP = bossPart:GetAttributeChangedSignal("HP"):Connect(onHpAttributeChanged)
    state.connHP = connHP
    table.insert(connections, connHP)

    local connHp = bossPart:GetAttributeChangedSignal("Hp"):Connect(onHpAttributeChanged)
    state.connHp = connHp
    table.insert(connections, connHp)

    task.spawn(function()
        sendHpBossProgress(region, bossPart)
    end)
end

local function registerWorldBossRegion(region)
    if not region then
        return
    end

    task.spawn(function()
        updateWorldBossRegion(region)
        attachHpWatcher(region)
    end)

    table.insert(connections, region:GetAttributeChangedSignal("HasBoss"):Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
        local hasBoss = region:GetAttribute("HasBoss")
        if hasBoss then
            attachHpWatcher(region)
        else
            detachHpWatcher(region)
        end
    end))

    table.insert(connections, region:GetAttributeChangedSignal("RemainTime"):Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
    end))

    table.insert(connections, region:GetAttributeChangedSignal("NextSpawnTime"):Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
    end))

    table.insert(connections, region.ChildAdded:Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
        attachHpWatcher(region)
    end))
end

local function initWorldBossNotifier()
    task.spawn(function()
        task.wait(5)
        if not alive then
            return
        end

        local worldBossFolder = workspace:FindFirstChild("WorldBoss")
        if not worldBossFolder then
            local okWait, inst = pcall(function()
                return workspace:WaitForChild("WorldBoss", 10)
            end)
            if okWait and inst then
                worldBossFolder = inst
            end
        end

        if not worldBossFolder then
            warn("[SpearFishing] WorldBoss folder tidak ditemukan, Spawn/HP Boss Notifier idle.")
            return
        end

        for _, child in ipairs(worldBossFolder:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                registerWorldBossRegion(child)
            end
        end

        table.insert(connections, worldBossFolder.ChildAdded:Connect(function(child)
            if not alive then return end
            if child:IsA("BasePart") or child:IsA("Model") then
                registerWorldBossRegion(child)
            end
        end))
    end)
end

------------------- SPAWN ILLAHI NOTIFIER (NETHER ISLAND) -------------------
local function initIllahiSpawnNotifier()
    task.spawn(function()
        task.wait(3)
        if not alive then
            return
        end

        local WEBHOOK_URL = "https://discord.com/api/webhooks/1456157133325209764/ymVmoJR0gV21o_IpvCn6sj2jR31TqZPnWMem7jEmxZLt_Pn__7j1cdsqna1u1mBq7yWz"
        local BOT_USERNAME = "Spawn Illahi Notifier"

        local ILLAHI_FISH_MAP = {
            Fish400 = { name = "Nether Barracuda",  sea = "Sea7" },
            Fish401 = { name = "Nether Anglerfish", sea = "Sea7" },
            Fish402 = { name = "Nether Manta Ray", sea = "Sea6" },
            Fish403 = { name = "Nether SwordFish", sea = "Sea6" },
            Fish404 = { name = "Diamond Flying Fish", sea = "Sea6" },
            Fish405 = { name = "Diamond Flying Fish", sea = "Sea6" },
        }

        local ILLAHI_SEA_SET = {
            Sea6 = true,
            Sea7 = true,
        }

        local function sendIllahiWebhookEmbed(embed)
            if not WEBHOOK_URL or WEBHOOK_URL == "" then
                return
            end

            local payload = {
                username   = BOT_USERNAME,
                avatar_url = SPAWN_BOSS_BOT_AVATAR,
                content    = DEFAULT_OWNER_DISCORD,
                embeds     = { embed },
            }

            local encoded
            local okEncode, resEncode = pcall(function()
                return HttpService:JSONEncode(payload)
            end)
            if okEncode then
                encoded = resEncode
            else
                warn("[SpearFishing] Illahi JSONEncode failed:", resEncode)
                return
            end

            local reqFunc = getSpawnBossRequestFunc()
            if reqFunc then
                local okReq, resReq = pcall(reqFunc, {
                    Url     = WEBHOOK_URL,
                    Method  = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                    },
                    Body    = encoded,
                })
                if not okReq then
                    warn("[SpearFishing] Illahi webhook request failed:", resReq)
                end
            else
                local okPost, errPost = pcall(function()
                    HttpService:PostAsync(WEBHOOK_URL, encoded, Enum.HttpContentType.ApplicationJson, false)
                end)
                if not okPost then
                    warn("[SpearFishing] Illahi HttpService PostAsync failed:", errPost)
                end
            end
        end

        local function buildIllahiSpawnEmbed(region, fishId, fishName)
            local regionName = getRegionNameForBoss(region)
            local islandName = "Nether Island"

            local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
            local username    = LocalPlayer.Name or "Player"
            local userId      = LocalPlayer.UserId or 0
            local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

            local serverId = game.JobId
            if not serverId or serverId == "" then
                serverId = "N/A"
            end

            local fishLabel = fishName or "Unknown"
            if fishId and fishId ~= "" then
                fishLabel = fishLabel .. " (" .. tostring(fishId) .. ")"
            end

            local embed = {
                title       = "Spawn Illahi",
                description = DEFAULT_OWNER_DISCORD,
                color       = 0x9400D3,
                fields      = {
                    {
                        name   = "Illahi Fish",
                        value  = fishLabel,
                        inline = true,
                    },
                    {
                        name   = "Sea",
                        value  = regionName,
                        inline = true,
                    },
                    {
                        name   = "Island",
                        value  = islandName,
                        inline = true,
                    },
                    {
                        name   = "Name Map",
                        value  = GAME_NAME,
                        inline = false,
                    },
                    {
                        name   = "Player",
                        value  = playerValue,
                        inline = false,
                    },
                    {
                        name   = "Server ID",
                        value  = serverId,
                        inline = false,
                    },
                },
                footer = {
                    text = "Spear Fishing PRO+ | Spawn Illahi Notifier",
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            }

            return embed
        end

        local function handleIllahiFish(region, fishPart)
            if not alive then
                return
            end
            if not _G.AxaHub or _G.AxaHub.SpawnIllahiNotifier == false then
                return
            end
            if not fishPart or not fishPart.Name then
                return
            end

            local def = ILLAHI_FISH_MAP[fishPart.Name]
            if not def then
                return
            end

            local fishName = def.name or fishPart.Name
            local embed = buildIllahiSpawnEmbed(region, fishPart.Name, fishName)
            sendIllahiWebhookEmbed(embed)
        end

        local function registerIllahiRegion(region)
            if not region or not region.Name then
                return
            end
            if not ILLAHI_SEA_SET[region.Name] then
                return
            end
            if not (region:IsA("BasePart") or region:IsA("Model")) then
                return
            end

            local function checkChild(child)
                if not child or not child.Name then
                    return
                end
                if not child:IsA("BasePart") then
                    return
                end
                if ILLAHI_FISH_MAP[child.Name] then
                    handleIllahiFish(region, child)
                end
            end

            for _, child in ipairs(region:GetChildren()) do
                checkChild(child)
            end

            table.insert(connections, region.ChildAdded:Connect(function(child)
                if not alive then return end
                checkChild(child)
            end))
        end

        local worldSea = workspace:FindFirstChild("WorldSea")
        if not worldSea then
            local okWait, inst = pcall(function()
                return workspace:WaitForChild("WorldSea", 10)
            end)
            if okWait and inst then
                worldSea = inst
            end
        end

        if not worldSea then
            warn("[SpearFishing] WorldSea folder tidak ditemukan, Spawn Illahi Notifier idle.")
            return
        end

        for _, child in ipairs(worldSea:GetChildren()) do
            registerIllahiRegion(child)
        end

        table.insert(connections, worldSea.ChildAdded:Connect(function(child)
            if not alive then return end
            registerIllahiRegion(child)
        end))
    end)
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

        for _, child in ipairs(DailyData:GetChildren()) do
            if child.AttributeChanged then
                table.insert(connections, child.AttributeChanged:Connect(function()
                    onDailyChanged()
                end))
            end
        end

        if DailyData.ChildAdded then
            table.insert(connections, DailyData.ChildAdded:Connect(function(child)
                if not alive then return end
                onDailyChanged()
                if child and child.AttributeChanged then
                    table.insert(connections, child.AttributeChanged:Connect(function()
                        onDailyChanged()
                    end))
                end
            end))
        end

        onDailyChanged()
    end)
end

local function buildDailyRewardCard(parent)
    local card, _, _ = createCard(
        parent,
        "Auto Daily Reward",
        "Auto claim + manual claim Daily Reward (Day 1 ~ 30).",
        2,
        320
    )

    local content = Instance.new("Frame")
    content.Name = "DailyContent"
    content.Parent = card
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0, 0, 0, 40)
    content.Size = UDim2.new(1, 0, 1, -40)

    local autoBtn, updateFn = createToggleButton(content, "Auto Daily Reward", autoDailyReward)
    autoBtn.Position = UDim2.new(0, 0, 0, 0)
    autoBtn.Size     = UDim2.new(1, 0, 0, 30)
    updateAutoDailyUI = updateFn
    updateAutoDailyUI(autoDailyReward)

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

        table.insert(connections, claimBtn.MouseButton1Click:Connect(function()
            claimDailyReward(index)
        end))
    end

    table.insert(connections, autoBtn.MouseButton1Click:Connect(function()
        autoDailyReward = not autoDailyReward
        if updateAutoDailyUI then
            updateAutoDailyUI(autoDailyReward)
        end
        updateDailyStatusLabel()
        notify("Spear Fishing", "Auto Daily Reward: " .. (autoDailyReward and "ON" or "OFF"), 2)
    end))

    updateDailyStatusLabel()

    return card
end

------------------- TOOLSDATA INIT -------------------
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
            table.insert(connections, ToolsData.AttributeChanged:Connect(onToolsChanged))
        end
        table.insert(connections, ToolsData.ChildAdded:Connect(onToolsChanged))
        table.insert(connections, ToolsData.ChildRemoved:Connect(onToolsChanged))

        onToolsChanged()
    end)
end

------------------- BUILD UI: CONTROL CARD -------------------
local header, bodyScroll = createMainLayout()

local controlCard, _, _ = createCard(
    bodyScroll,
    "Spear Controls",
    "AutoFarm v1 + AutoFarm v2 (Tap Trackpad Left/Center) + AutoEquip + Spawn Boss Notifier + HP Boss Notifier + Spawn Illahi Notifier + Sell All + Auto Skill 1 ~ 5.",
    1,
    260
)

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

table.insert(connections, controlsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    controlsScroll.CanvasSize = UDim2.new(0, 0, 0, controlsLayout.AbsoluteContentSize.Y + 8)
end))

local autoFarmButton,   updateAutoFarmUI   = createToggleButton(controlsScroll, "AutoFarm Fish", autoFarm)
local autoEquipButton,  updateAutoEquipUI  = createToggleButton(controlsScroll, "AutoEquip Harpoon", autoEquip)
local autoFarmV2Button, updateAutoFarmV2UI = createToggleButton(controlsScroll, "AutoFarm Fish V2", autoFarmV2)

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

local tapSpeedFrame = Instance.new("Frame")
tapSpeedFrame.Name = "TapSpeedFrame"
tapSpeedFrame.Parent = controlsScroll
tapSpeedFrame.BackgroundTransparency = 1
tapSpeedFrame.BorderSizePixel = 0
tapSpeedFrame.Size = UDim2.new(1, 0, 0, 28)

local tapSpeedLabel = Instance.new("TextLabel")
tapSpeedLabel.Name = "TapSpeedLabel"
tapSpeedLabel.Parent = tapSpeedFrame
tapSpeedLabel.BackgroundTransparency = 1
tapSpeedLabel.Font = Enum.Font.Gotham
tapSpeedLabel.TextSize = 11
tapSpeedLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
tapSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
tapSpeedLabel.Text = "AutoFarm V2 Tap Interval (detik):"
tapSpeedLabel.Position = UDim2.new(0, 0, 0, 0)
tapSpeedLabel.Size = UDim2.new(0.6, 0, 1, 0)

local tapSpeedBox = Instance.new("TextBox")
tapSpeedBox.Name = "TapSpeedBox"
tapSpeedBox.Parent = tapSpeedFrame
tapSpeedBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tapSpeedBox.BorderSizePixel = 0
tapSpeedBox.Font = Enum.Font.GothamSemibold
tapSpeedBox.TextSize = 11
tapSpeedBox.TextColor3 = Color3.fromRGB(230, 230, 230)
tapSpeedBox.ClearTextOnFocus = false
tapSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
tapSpeedBox.Position = UDim2.new(0.62, 0, 0, 0)
tapSpeedBox.Size = UDim2.new(0.38, 0, 1, 0)
tapSpeedBox.Text = string.format("%.2f", autoFarmV2TapInterval)

local tapSpeedCorner = Instance.new("UICorner")
tapSpeedCorner.CornerRadius = UDim.new(0, 6)
tapSpeedCorner.Parent = tapSpeedBox

local function applyTapSpeedFromBox()
    local raw = tapSpeedBox.Text or ""
    raw = raw:gsub(",", ".")
    local num = tonumber(raw)
    if not num then
        tapSpeedBox.Text = string.format("%.2f", autoFarmV2TapInterval)
        return
    end
    if num < TAP_INTERVAL_MIN then
        num = TAP_INTERVAL_MIN
    elseif num > TAP_INTERVAL_MAX then
        num = TAP_INTERVAL_MAX
    end
    autoFarmV2TapInterval = num
    tapSpeedBox.Text = string.format("%.2f", autoFarmV2TapInterval)
end

table.insert(connections, tapSpeedBox.FocusLost:Connect(function()
    applyTapSpeedFromBox()
end))

local spawnBossToggleButton, updateSpawnBossNotifierUI =
    createToggleButton(controlsScroll, "Spawn Boss Notifier", spawnBossNotifier)

local spawnIllahiToggleButton, updateSpawnIllahiNotifierUI =
    createToggleButton(controlsScroll, "Spawn Illahi Notifier", _G.AxaHub.SpawnIllahiNotifier)

local hpBossToggleButton, updateHpBossNotifierUI =
    createToggleButton(controlsScroll, "HPBar Boss Notifier", hpBossNotifier)

local autoSkill1Button, updateAutoSkill1UI = createToggleButton(controlsScroll, "Auto Skill 1", autoSkill1)
local autoSkill2Button, updateAutoSkill2UI = createToggleButton(controlsScroll, "Auto Skill 2", autoSkill2)
local autoSkill3Button, updateAutoSkill3UI = createToggleButton(controlsScroll, "Auto Skill 3", autoSkill3)
local autoSkill4Button, updateAutoSkill4UI = createToggleButton(controlsScroll, "Auto Skill 4", autoSkill4)
local autoSkill5Button, updateAutoSkill5UI = createToggleButton(controlsScroll, "Auto Skill 5", autoSkill5)

local skill1BaseInfoText = string.format(
    "Skill 1 (Skill04) Cooldown server (perkiraan): %d detik (UI info).",
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
    "Skill 2 (Skill08) Cooldown server (perkiraan): %d detik (UI info). Jeda antar Skill1 -> Skill2: %d detik.",
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
statusLabel.Size = UDim2.new(1, 0, 0, 60)
statusLabel.Text = ""

local function updateStatusLabel()
    statusLabel.Text = string.format(
        "Status: AutoFarm %s, AutoEquip %s, AutoFarm V2 %s (%s, %.2fs), SpawnBossNotifier %s, SpawnIllahiNotifier %s, HPBossNotifier %s, Skill1 %s, Skill2 %s, Skill3 %s, Skill4 %s, Skill5 %s.",
        autoFarm and "ON" or "OFF",
        autoEquip and "ON" or "OFF",
        autoFarmV2 and "ON" or "OFF",
        autoFarmV2Mode,
        autoFarmV2TapInterval,
        spawnBossNotifier and "ON" or "OFF",
        (_G.AxaHub and _G.AxaHub.SpawnIllahiNotifier) and "ON" or "OFF",
        hpBossNotifier and "ON" or "OFF",
        autoSkill1 and "ON" or "OFF",
        autoSkill2 and "ON" or "OFF",
        autoSkill3 and "ON" or "OFF",
        autoSkill4 and "ON" or "OFF",
        autoSkill5 and "ON" or "OFF"
    )
end

table.insert(connections, autoFarmButton.MouseButton1Click:Connect(function()
    autoFarm = not autoFarm
    updateAutoFarmUI(autoFarm)
    updateStatusLabel()
end))

table.insert(connections, autoEquipButton.MouseButton1Click:Connect(function()
    autoEquip = not autoEquip
    updateAutoEquipUI(autoEquip)
    if autoEquip then
        ensureHarpoonEquipped()
    end
    updateStatusLabel()
end))

table.insert(connections, autoFarmV2Button.MouseButton1Click:Connect(function()
    autoFarmV2 = not autoFarmV2
    updateAutoFarmV2UI(autoFarmV2)
    updateStatusLabel()
end))

table.insert(connections, v2ModeButton.MouseButton1Click:Connect(function()
    autoFarmV2Mode = (autoFarmV2Mode == "Center") and "Left" or "Center"
    updateV2ModeButton()
    updateStatusLabel()
end))

table.insert(connections, spawnBossToggleButton.MouseButton1Click:Connect(function()
    spawnBossNotifier = not spawnBossNotifier
    updateSpawnBossNotifierUI(spawnBossNotifier)
    updateStatusLabel()
    notify("Spear Fishing", "Spawn Boss Notifier: " .. (spawnBossNotifier and "ON" or "OFF"), 2)
end))

table.insert(connections, spawnIllahiToggleButton.MouseButton1Click:Connect(function()
    _G.AxaHub.SpawnIllahiNotifier = not _G.AxaHub.SpawnIllahiNotifier
    updateSpawnIllahiNotifierUI(_G.AxaHub.SpawnIllahiNotifier)
    updateStatusLabel()
    notify("Spear Fishing", "Spawn Illahi Notifier: " .. (_G.AxaHub.SpawnIllahiNotifier and "ON" or "OFF"), 2)
end))

table.insert(connections, hpBossToggleButton.MouseButton1Click:Connect(function()
    hpBossNotifier = not hpBossNotifier
    updateHpBossNotifierUI(hpBossNotifier)
    updateStatusLabel()
    notify("Spear Fishing", "HPBar Boss Notifier: " .. (hpBossNotifier and "ON" or "OFF"), 2)
end))

table.insert(connections, autoSkill1Button.MouseButton1Click:Connect(function()
    autoSkill1 = not autoSkill1
    updateAutoSkill1UI(autoSkill1)
    updateStatusLabel()
end))

table.insert(connections, autoSkill2Button.MouseButton1Click:Connect(function()
    autoSkill2 = not autoSkill2
    updateAutoSkill2UI(autoSkill2)
    updateStatusLabel()
end))

table.insert(connections, autoSkill3Button.MouseButton1Click:Connect(function()
    autoSkill3 = not autoSkill3
    updateAutoSkill3UI(autoSkill3)
    updateStatusLabel()
end))

table.insert(connections, autoSkill4Button.MouseButton1Click:Connect(function()
    autoSkill4 = not autoSkill4
    updateAutoSkill4UI(autoSkill4)
    updateStatusLabel()
end))

table.insert(connections, autoSkill5Button.MouseButton1Click:Connect(function()
    autoSkill5 = not autoSkill5
    updateAutoSkill5UI(autoSkill5)
    updateStatusLabel()
end))

table.insert(connections, sellButton.MouseButton1Click:Connect(function()
    sellAllFish()
end))

updateStatusLabel()

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

table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))

------------------- BUILD UI: DAILY REWARD + SHOP CARDS -------------------
buildDailyRewardCard(bodyScroll)
buildHarpoonShopCard(bodyScroll)
buildBasketShopCard(bodyScroll)
buildBaitShopCard(bodyScroll)

initToolsDataWatcher()
initDailyDataWatcher()
initWorldBossNotifier()
initIllahiSpawnNotifier()

------------------- BACKPACK / CHARACTER EVENT -------------------
table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    task.delay(1, function()
        if alive then
            ensureHarpoonEquipped()
            refreshHarpoonOwnership()
            refreshBasketOwnership()
            refreshDailyUI()
        end
    end)
end))

table.insert(connections, LocalPlayer.ChildAdded:Connect(function(child)
    if child:IsA("Backpack") then
        backpack = child
        task.delay(0.5, function()
            if alive then
                refreshHarpoonOwnership()
                refreshBasketOwnership()
            end
        end)
    end
end))

if backpack then
    table.insert(connections, backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            refreshHarpoonOwnership()
            refreshBasketOwnership()
        end
    end))

    table.insert(connections, backpack.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            refreshHarpoonOwnership()
            refreshBasketOwnership()
        end
    end))
end

------------------- BACKGROUND LOOPS -------------------
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
            local interval = autoFarmV2TapInterval
            if interval < TAP_INTERVAL_MIN then
                interval = TAP_INTERVAL_MIN
            elseif interval > TAP_INTERVAL_MAX then
                interval = TAP_INTERVAL_MAX
            end
            task.wait(interval)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while alive do
        if autoDailyReward then
            local idx = findNextClaimableDailyIndex()
            if idx then
                claimDailyReward(idx)
            end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while alive do
        if autoSkill1 or autoSkill2 then
            if autoSkill1 and autoSkill2 then
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

task.spawn(function()
    while alive do
        if autoSkill3 or autoSkill4 or autoSkill5 then
            if autoSkill3 then
                pcall(fireSkill3)
            end
            task.wait(0.2)
            if not alive then break end

            if autoSkill4 then
                pcall(fireSkill4)
            end
            task.wait(0.2)
            if not alive then break end

            if autoSkill5 then
                pcall(fireSkill5)
            end

            local t = 0
            while t < 1 and alive and (autoSkill3 or autoSkill4 or autoSkill5) do
                task.wait(0.2)
                t = t + 0.2
            end
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while alive do
        if updateSkillCooldownUI then
            pcall(updateSkillCooldownUI)
        end
        task.wait(0.2)
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive              = false
    autoFarm           = false
    autoEquip          = false
    autoFarmV2         = false
    autoDailyReward    = false
    autoSkill1         = false
    autoSkill2         = false
    autoSkill3         = false
    autoSkill4         = false
    autoSkill5         = false
    spawnBossNotifier  = false
    hpBossNotifier     = false
    bossRegionState    = {}
    hpRegionState      = {}
    _G.AxaHub.SpawnIllahiNotifier = false

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
