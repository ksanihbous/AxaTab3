--==========================================================
--  20AxaTab_SpearFishFarm.lua
--  TAB 20: "Spear Fish Farm PRO++"
--  Fitur:
--    - AutoFarm: universal fish Sea1 - Sea7 (Hit remote)
--    - AutoFarm Boss (WorldBoss > Point1 / Point2)
--    - AutoFarm Mythic/Legendary/Secret (Sea4, Sea5)
--    - AutoFarm Illahi/Divine (Sea6, Sea7)
--    - Sea Selector: AutoDetect / Sea1 - Sea7
--    - Rarity Mode: Disabled / Legendary+Mythic+Secret+Illahi / Per Fish
--    - Per Fish list dinamis, sinkron Sea + Climate real time
--    - AimLock Fish + ESP Antena neon kuning (toggle terpisah)
--    - Shooting Range slider (25 - 1000 stud)
--    - Farm Delay slider (0.01 - 0.30 detik)
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame = TAB_FRAME
local tabId = TAB_ID or "spearfishfarm"

local Players             = Players             or game:GetService("Players")
local LocalPlayer         = LocalPlayer         or Players.LocalPlayer
local RunService          = RunService          or game:GetService("RunService")
local UserInputService    = UserInputService    or game:GetService("UserInputService")
local StarterGui          = StarterGui          or game:GetService("StarterGui")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local workspace           = workspace

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

------------------- GLOBAL STATE -------------------
local alive        = true
local connections  = {}

local character    = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local Remotes      = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE       = Remotes and Remotes:FindFirstChild("FireRE")
local ToolRE       = Remotes and Remotes:FindFirstChild("ToolRE")

local WorldSea     = workspace:FindFirstChild("WorldSea")
local WorldBoss    = workspace:FindFirstChild("WorldBoss")

-- Auto farm flags
local autoFarmAll      = false  -- Semua fish sesuai Sea filter
local autoFarmBoss     = false  -- Boss di WorldBoss
local autoFarmRare     = false  -- Mythic/Legendary/Secret Sea4, Secret Sea5
local autoFarmIllahi   = false  -- Illahi Sea6, Sea7

-- Sea mode
local seaModeList = {
    "AutoDetect",
    "Sea1",
    "Sea2",
    "Sea3",
    "Sea4",
    "Sea5",
    "Sea6",
    "Sea7",
}
local seaModeIndex = 1  -- AutoDetect default

-- Rarity mode dropdown
local rarityModeList = {
    "Disabled",                         -- 1
    "Legendary/Mythic/Secret/Illahi",   -- 2
    "Per Fish",                         -- 3
}
local rarityModeIndex = 1  -- default Disabled

-- AimLock + ESP Antena
local aimLockEnabled    = true   -- lock target + label + highlight
local espAntennaEnabled = true   -- khusus garis neon kuning HRP -> fish

-- Shooting range (stud)
local SHOOT_RANGE_MIN = 25
local SHOOT_RANGE_MAX = 1000
local shootRange      = 600   -- default

-- Farm delay (detik)
local FARM_DELAY_MIN  = 0.01
local FARM_DELAY_MAX  = 0.30
local farmDelay       = 0.01

-- Status label UI
local statusLabel

------------------- FISH DATA SETS -------------------
-- Illahi / Divine (Sea6, Sea7)
local ILLAHI_SET = {
    Fish400 = true, -- Nether Barracuda (Sea7)
    Fish401 = true, -- Nether Anglerfish (Sea7)
    Fish402 = true, -- Nether Manta Ray (Sea6)
    Fish403 = true, -- Nether SwordFish (Sea6)
    Fish404 = true, -- Diamond Flying Fish (Sea6)
    Fish405 = true, -- Diamond Flying Fish (Sea6)
}

-- Secret Nether Island (Sea5)
local SECRET_SEA5_SET = {
    Fish500 = true, -- Abyssal Demon Shark (Sea5)
    Fish501 = true, -- Nighfall Demon Shark (Sea5)
    Fish503 = true, -- Ancient Gopala (Sea5)
    Fish504 = true, -- Nighfall Gopala (Sea5)
    Fish505 = true, -- Sharkster (Sea5)
    Fish508 = true, -- Mayfly Dragon (Sea5)
    Fish510 = true, -- Nighfall Sharkster (Sea5)
}

-- Submerged Pond rare list (Sea4) Legendary/Mythic/Secret
local RARE_SEA4_SET = {
    -- Climate Grassland
    Fish55  = true, -- Purple Jellyfish Legendary
    Fish56  = true, -- Prism Jellyfish Legendary
    Fish57  = true, -- Prism Crab Legendary
    Fish98  = true, -- Shark Mythic
    Fish305 = true, -- Christmas Shark Mythic
    Fish201 = true, -- Shimmer Puffer Secret

    -- Climate Marsh
    Fish104 = true, -- Bullfrog Legendary
    Fish105 = true, -- Poison Dart Frog Mythic
    Fish102 = true, -- Swamp Crocodile Mythic
    Fish97  = true, -- Sawtooth Shark Mythic
    Fish202 = true, -- Nebula Lantern Carp Secret

    -- Climate Iceborne
    Fish121 = true, -- Dragon Whisker Fish Legendary
    Fish123 = true, -- Leatherback Turtle Mythic
    Fish111 = true, -- Frost Anglerfish Mythic
    Fish130 = true, -- Devil Ray Mythic
    Fish203 = true, -- Shimmer Unicorn Fish Secret
}

-- Boss IDs di WorldBoss
local BOSS_IDS = {
    Boss01 = true, -- Humpback Whale
    Boss02 = true, -- Whale Shark
    Boss03 = true, -- Crimson Rift Dragon
}

------------------- PER FISH CONFIG -------------------
local PER_FISH_CONFIG = {
    -- Sea4 - Climate Grassland
    { id = "Fish55",  sea = "Sea4", climates = {"Grassland"}, name = "Fish55 Purple Jellyfish Legendary (Sea4 / Grassland)" },
    { id = "Fish56",  sea = "Sea4", climates = {"Grassland"}, name = "Fish56 Prism Jellyfish Legendary (Sea4 / Grassland)" },
    { id = "Fish57",  sea = "Sea4", climates = {"Grassland"}, name = "Fish57 Prism Crab Legendary (Sea4 / Grassland)" },
    { id = "Fish98",  sea = "Sea4", climates = {"Grassland"}, name = "Fish98 Shark Mythic (Sea4 / Grassland)" },
    { id = "Fish305", sea = "Sea4", climates = {"Grassland","Marsh","Iceborne"}, name = "Fish305 Christmas Shark Mythic (Sea4 / All Climate)" },
    { id = "Fish201", sea = "Sea4", climates = {"Grassland"}, name = "Fish201 Shimmer Puffer Secret (Sea4 / Grassland)" },

    -- Sea4 - Climate Marsh
    { id = "Fish104", sea = "Sea4", climates = {"Marsh"}, name = "Fish104 Bullfrog Legendary (Sea4 / Marsh)" },
    { id = "Fish105", sea = "Sea4", climates = {"Marsh"}, name = "Fish105 Poison Dart Frog Mythic (Sea4 / Marsh)" },
    { id = "Fish102", sea = "Sea4", climates = {"Marsh"}, name = "Fish102 Swamp Crocodile Mythic (Sea4 / Marsh)" },
    { id = "Fish97",  sea = "Sea4", climates = {"Marsh"}, name = "Fish97 Sawtooth Shark Mythic (Sea4 / Marsh)" },
    { id = "Fish202", sea = "Sea4", climates = {"Marsh"}, name = "Fish202 Nebula Lantern Carp Secret (Sea4 / Marsh)" },

    -- Sea4 - Climate Iceborne
    { id = "Fish121", sea = "Sea4", climates = {"Iceborne"}, name = "Fish121 Dragon Whisker Fish Legendary (Sea4 / Iceborne)" },
    { id = "Fish123", sea = "Sea4", climates = {"Iceborne"}, name = "Fish123 Leatherback Turtle Mythic (Sea4 / Iceborne)" },
    { id = "Fish111", sea = "Sea4", climates = {"Iceborne"}, name = "Fish111 Frost Anglerfish Mythic (Sea4 / Iceborne)" },
    { id = "Fish130", sea = "Sea4", climates = {"Iceborne"}, name = "Fish130 Devil Ray Mythic (Sea4 / Iceborne)" },
    { id = "Fish203", sea = "Sea4", climates = {"Iceborne"}, name = "Fish203 Shimmer Unicorn Fish Secret (Sea4 / Iceborne)" },

    -- Sea5 Secret
    { id = "Fish500", sea = "Sea5", name = "Fish500 Abyssal Demon Shark Secret (Sea5)" },
    { id = "Fish501", sea = "Sea5", name = "Fish501 Nighfall Demon Shark Secret (Sea5)" },
    { id = "Fish503", sea = "Sea5", name = "Fish503 Ancient Gopala Secret (Sea5)" },
    { id = "Fish504", sea = "Sea5", name = "Fish504 Nighfall Gopala Secret (Sea5)" },
    { id = "Fish505", sea = "Sea5", name = "Fish505 Sharkster Secret (Sea5)" },
    { id = "Fish508", sea = "Sea5", name = "Fish508 Mayfly Dragon Secret (Sea5)" },
    { id = "Fish510", sea = "Sea5", name = "Fish510 Nighfall Sharkster Secret (Sea5)" },

    -- Sea6/Sea7 Illahi/Divine
    { id = "Fish400", sea = "Sea7", name = "Fish400 Nether Barracuda Illahi (Sea7)" },
    { id = "Fish401", sea = "Sea7", name = "Fish401 Nether Anglerfish Illahi (Sea7)" },
    { id = "Fish402", sea = "Sea6", name = "Fish402 Nether Manta Ray Illahi (Sea6)" },
    { id = "Fish403", sea = "Sea6", name = "Fish403 Nether SwordFish Illahi (Sea6)" },
    { id = "Fish404", sea = "Sea6", name = "Fish404 Diamond Flying Fish Illahi (Sea6)" },
    { id = "Fish405", sea = "Sea6", name = "Fish405 Diamond Flying Fish Illahi (Sea6)" },
}

local PER_FISH_FLAGS = {}
for _, cfg in ipairs(PER_FISH_CONFIG) do
    PER_FISH_FLAGS[cfg.id] = false
end

------------------- NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Spear Fish Farm",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

------------------- CHARACTER / HRP -------------------
local function getHRP()
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
end))

------------------- HARPOON TOOL HELPERS -------------------
local lastAutoEquipWarn = 0

local function getEquippedHarpoonTool()
    local char = character
    if not char then
        return nil
    end

    local harpoon22 = char:FindFirstChild("Harpoon22")
    if harpoon22 and harpoon22:IsA("Tool") then
        return harpoon22
    end

    local bestTool
    local bestNum = -1
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local n = child.Name:match("^Harpoon(%d+)$")
            if n then
                local num = tonumber(n) or 0
                if num > bestNum then
                    bestNum  = num
                    bestTool = child
                end
            end
        end
    end

    if bestTool then
        return bestTool
    end

    local anyTool = char:FindFirstChildWhichIsA("Tool")
    return anyTool
end

local function ensureToolEquipped()
    local tool = getEquippedHarpoonTool()
    if tool then
        return tool
    end

    if ToolRE then
        local args = {
            [1] = "Switch",
            [2] = { ["index"] = 1 }
        }
        pcall(function()
            ToolRE:FireServer(unpack(args))
        end)
        task.wait(0.2)
        tool = getEquippedHarpoonTool()
        if tool then
            return tool
        end
    end

    local now = os.clock()
    if now - lastAutoEquipWarn > 5 then
        lastAutoEquipWarn = now
        notify("Spear Fish Farm", "Equip Harpoon terlebih dahulu sebelum AutoFarm.", 3)
    end
    return nil
end

------------------- SEA HELPERS -------------------
local function getSeaFolderByName(name)
    if not WorldSea then
        WorldSea = workspace:FindFirstChild("WorldSea")
        if not WorldSea then
            return nil
        end
    end
    return WorldSea:FindFirstChild(name)
end

local function detectCurrentSea()
    if not WorldSea then
        WorldSea = workspace:FindFirstChild("WorldSea")
        if not WorldSea then
            return nil, nil
        end
    end

    local hrp = getHRP()
    if not hrp then
        return nil, nil
    end

    local hrpPos = hrp.Position
    local bestSea
    local bestName
    local bestDist = math.huge

    for i = 1, 7 do
        local seaName = "Sea" .. tostring(i)
        local seaFolder = WorldSea:FindFirstChild(seaName)
        if seaFolder then
            local sum = Vector3.new(0, 0, 0)
            local count = 0
            local ok, descendants = pcall(function()
                return seaFolder:GetDescendants()
            end)
            if ok and descendants then
                for _, inst in ipairs(descendants) do
                    if inst:IsA("BasePart") then
                        sum = sum + inst.Position
                        count = count + 1
                    end
                end
            end
            if count > 0 then
                local center = sum / count
                local d = (center - hrpPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestSea  = seaFolder
                    bestName = seaName
                end
            end
        end
    end

    return bestSea, bestName
end

local function getActiveSeaFolder()
    local mode = seaModeList[seaModeIndex] or "AutoDetect"
    if mode == "AutoDetect" then
        return detectCurrentSea()
    else
        local seaFolder = getSeaFolderByName(mode)
        return seaFolder, mode
    end
end

------------------- AIMLOCK + ESP ANTENA (NEON) -------------------
local aimLockTarget        = nil
local aimLockTargetPart    = nil
local aimLockLabelName     = "Target"
local aimLockBillboard     = nil
local aimLockLabel         = nil
local aimLockHighlight     = nil
local antennaPart          = nil

local function clearAimLockVisual()
    if aimLockBillboard then
        pcall(function() aimLockBillboard:Destroy() end)
    end
    if aimLockHighlight then
        pcall(function() aimLockHighlight:Destroy() end)
    end
    if antennaPart then
        pcall(function() antennaPart:Destroy() end)
    end

    aimLockBillboard  = nil
    aimLockLabel      = nil
    aimLockHighlight  = nil
    antennaPart       = nil
    aimLockTargetPart = nil
end

local function setAimLockTarget(newPart, displayName)
    aimLockTarget     = newPart
    aimLockTargetPart = newPart
    aimLockLabelName  = displayName or "Fish"

    clearAimLockVisual()

    if not aimLockEnabled then
        return
    end

    if not aimLockTargetPart or not aimLockTargetPart:IsA("BasePart") then
        return
    end

    -- Billboard teks di atas fish (Nama + jarak)
    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "AxaFarm_Target_Billboard"
    billboard.Size        = UDim2.new(0, 170, 0, 26)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent      = aimLockTargetPart

    local label = Instance.new("TextLabel")
    label.Name                   = "Text"
    label.Parent                 = billboard
    label.BackgroundTransparency = 0.2
    label.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
    label.BorderSizePixel        = 0
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.Font                   = Enum.Font.GothamSemibold
    label.TextSize               = 12
    label.TextColor3             = Color3.fromRGB(255, 255, 0)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    label.TextWrapped            = true
    label.Text                   = aimLockLabelName .. " | 0 suds"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = label

    -- Highlight di fish (merah kuning tipis, supaya jelas)
    local adornee = aimLockTargetPart
    if aimLockTargetPart.Parent and aimLockTargetPart.Parent:IsA("Model") then
        adornee = aimLockTargetPart.Parent
    end

    local highlight = Instance.new("Highlight")
    highlight.Name                = "AxaFarm_Target_Highlight"
    highlight.FillColor           = Color3.fromRGB(255, 40, 40)
    highlight.FillTransparency    = 0.7
    highlight.OutlineColor        = Color3.fromRGB(255, 255, 0)
    highlight.OutlineTransparency = 0
    highlight.Adornee             = adornee
    highlight.Parent              = adornee

    -- Antena neon hanya dibuat kalau ESP Antena aktif
    if espAntennaEnabled then
        antennaPart = Instance.new("Part")
        antennaPart.Name        = "AxaFarm_Antenna"
        antennaPart.Anchored    = true
        antennaPart.CanCollide  = false
        antennaPart.CanQuery    = false
        antennaPart.CanTouch    = false
        antennaPart.Material    = Enum.Material.Neon
        antennaPart.Color       = Color3.fromRGB(255, 255, 0)
        antennaPart.CastShadow  = false
        antennaPart.Size        = Vector3.new(0.15, 1, 0.15)
        antennaPart.Shape       = Enum.PartType.Cylinder
        antennaPart.Transparency = 0
        antennaPart.Parent      = workspace
    else
        antennaPart = nil
    end

    aimLockBillboard = billboard
    aimLockLabel     = label
    aimLockHighlight = highlight
end

local function updateAimLockDistanceLabel()
    if not aimLockEnabled then
        return
    end
    if not aimLockTargetPart then
        return
    end

    local hrp = getHRP()
    if not hrp then
        return
    end

    if aimLockTargetPart.Parent == nil then
        clearAimLockVisual()
        return
    end

    local fromPos = hrp.Position
    local toPos   = aimLockTargetPart.Position
    local diff    = toPos - fromPos
    local dist    = diff.Magnitude

    -- Label jarak tetap update walau ESP Antena OFF
    if aimLockLabel then
        aimLockLabel.Text = string.format("%s | %d suds", aimLockLabelName, math.floor(dist or 0))
    end

    -- Jika ESP Antena OFF: sembunyikan garis kalau ada, lalu selesai
    if not espAntennaEnabled then
        if antennaPart then
            antennaPart.Transparency = 1
        end
        return
    end

    -- ESP Antena ON: pastikan part ada
    if not antennaPart or antennaPart.Parent == nil then
        antennaPart = Instance.new("Part")
        antennaPart.Name        = "AxaFarm_Antenna"
        antennaPart.Anchored    = true
        antennaPart.CanCollide  = false
        antennaPart.CanQuery    = false
        antennaPart.CanTouch    = false
        antennaPart.Material    = Enum.Material.Neon
        antennaPart.Color       = Color3.fromRGB(255, 255, 0)
        antennaPart.CastShadow  = false
        antennaPart.Size        = Vector3.new(0.15, 1, 0.15)
        antennaPart.Shape       = Enum.PartType.Cylinder
        antennaPart.Transparency = 0
        antennaPart.Parent      = workspace
    end

    if dist < 0.1 then
        antennaPart.Transparency = 1
        return
    else
        antennaPart.Transparency = 0
    end

    antennaPart.Size = Vector3.new(0.15, dist, 0.15)
    local mid = fromPos + diff * 0.5
    antennaPart.CFrame = CFrame.lookAt(mid, toPos) * CFrame.Angles(math.rad(90), 0, 0)
end

------------------- HIT HELPERS -------------------
local function getHitPosFromFishInstance(fish)
    if not fish then
        return nil
    end

    if fish:IsA("BasePart") then
        return fish.Position
    end

    if fish:IsA("Model") then
        if fish.PrimaryPart then
            return fish.PrimaryPart.Position
        end
        local part = fish:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.Position
        end
    end

    return nil
end

local function isInRange(pos)
    local hrp = getHRP()
    if not hrp or not pos then
        return false
    end
    local dist = (hrp.Position - pos).Magnitude
    return dist <= shootRange
end

local function sendHit(fishInstance, hitPos, tool)
    if not FireRE then
        return
    end
    if not fishInstance or not hitPos or not tool then
        return
    end

    local args = {
        [1] = "Hit",
        [2] = {
            ["fishInstance"] = fishInstance,
            ["HitPos"]       = hitPos,
            ["toolInstance"] = tool
        }
    }

    pcall(function()
        FireRE:FireServer(unpack(args))
    end)
end

------------------- RARITY FILTER LOGIC -------------------
local function baseFlagsAllowFish(seaName, fishName)
    if autoFarmAll then
        return true
    end

    if autoFarmRare then
        if seaName == "Sea4" and RARE_SEA4_SET[fishName] then
            return true
        end
        if seaName == "Sea5" and SECRET_SEA5_SET[fishName] then
            return true
        end
    end

    if autoFarmIllahi then
        if (seaName == "Sea6" or seaName == "Sea7") and ILLAHI_SET[fishName] then
            return true
        end
    end

    return false
end

local function isRareTypeFish(seaName, fishName)
    if seaName == "Sea4" and RARE_SEA4_SET[fishName] then
        return true
    end
    if seaName == "Sea5" and SECRET_SEA5_SET[fishName] then
        return true
    end
    if (seaName == "Sea6" or seaName == "Sea7") and ILLAHI_SET[fishName] then
        return true
    end
    return false
end

local function shouldTargetFish(seaName, fishName)
    if not fishName or fishName == "" then
        return false
    end

    if BOSS_IDS[fishName] then
        return false
    end

    if not baseFlagsAllowFish(seaName, fishName) then
        return false
    end

    if rarityModeIndex == 1 then
        return true
    elseif rarityModeIndex == 2 then
        return isRareTypeFish(seaName, fishName)
    elseif rarityModeIndex == 3 then
        return PER_FISH_FLAGS[fishName] == true
    end

    return false
end

------------------- AUTO FARM FISH (SEA) -------------------
local currentFishTarget      = nil
local currentFishTargetSea   = nil

local function pickNewFishTarget(seaFolder, seaName)
    if not seaFolder or not seaName then
        return nil
    end

    if not (autoFarmAll or autoFarmRare or autoFarmIllahi) then
        return nil
    end

    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local closestFish
    local closestPart
    local bestDist = math.huge

    for _, obj in ipairs(seaFolder:GetChildren()) do
        if typeof(obj) == "Instance" and obj.Name and obj.Name:sub(1, 4) == "Fish" then
            if shouldTargetFish(seaName, obj.Name) then
                local hitPos = getHitPosFromFishInstance(obj)
                if hitPos and isInRange(hitPos) then
                    local d = (hitPos - hrpPos).Magnitude
                    if d < bestDist then
                        bestDist   = d
                        closestFish = obj

                        if obj:IsA("BasePart") then
                            closestPart = obj
                        elseif obj:IsA("Model") then
                            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                            closestPart = p
                        end
                    end
                end
            end
        end
    end

    if closestFish and closestPart then
        currentFishTarget    = closestFish
        currentFishTargetSea = seaName
        setAimLockTarget(closestPart, closestFish.Name)
        return closestFish
    end

    currentFishTarget    = nil
    currentFishTargetSea = nil
    clearAimLockVisual()
    return nil
end

local function processAutoFarmFishStep()
    if not (autoFarmAll or autoFarmRare or autoFarmIllahi) then
        return
    end

    local tool = ensureToolEquipped()
    if not tool then
        return
    end

    local seaFolder, seaName = getActiveSeaFolder()
    if not seaFolder or not seaName then
        return
    end

    local target = currentFishTarget

    local function isValidTarget(fish)
        if not fish or fish.Parent ~= seaFolder then
            return false
        end
        if not shouldTargetFish(seaName, fish.Name) then
            return false
        end
        local pos = getHitPosFromFishInstance(fish)
        if not pos or not isInRange(pos) then
            return false
        end
        return true
    end

    if aimLockEnabled then
        if not isValidTarget(target) then
            target = pickNewFishTarget(seaFolder, seaName)
            if not target then
                return
            end
        end
    else
        target = pickNewFishTarget(seaFolder, seaName)
        if not target then
            return
        end
    end

    local hitPos = getHitPosFromFishInstance(target)
    if not hitPos then
        currentFishTarget = nil
        return
    end

    sendHit(target, hitPos, tool)
    task.wait(farmDelay)
end

------------------- AUTO FARM BOSS -------------------
local currentBossTarget     = nil
local currentBossTargetPart = nil

local function getBossPartInRegion(region)
    if not region then
        return nil
    end
    local ok, descendants = pcall(function()
        return region:GetDescendants()
    end)
    if not ok or not descendants then
        return nil
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") then
            if BOSS_IDS[inst.Name] then
                return inst
            end
            local hpAttr = inst:GetAttribute("CurHP")
                or inst:GetAttribute("CurHp")
                or inst:GetAttribute("HP")
                or inst:GetAttribute("Hp")
            if hpAttr ~= nil then
                return inst
            end
        end
    end
    return nil
end

local function pickBossTarget()
    if not WorldBoss then
        WorldBoss = workspace:FindFirstChild("WorldBoss")
        if not WorldBoss then
            return nil
        end
    end

    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local bestPart
    local bestDist = math.huge

    for _, pointName in ipairs({"Point1", "Point2"}) do
        local region = WorldBoss:FindFirstChild(pointName)
        if region then
            local bossPart = getBossPartInRegion(region)
            if bossPart and bossPart.Parent then
                local pos = bossPart.Position
                local d = (pos - hrpPos).Magnitude
                if d < bestDist and d <= shootRange then
                    bestDist = d
                    bestPart = bossPart
                end
            end
        end
    end

    if bestPart then
        currentBossTarget     = bestPart
        currentBossTargetPart = bestPart
        setAimLockTarget(bestPart, bestPart.Name or "Boss")
        return bestPart
    end

    currentBossTarget     = nil
    currentBossTargetPart = nil
    return nil
end

local function processAutoFarmBossStep()
    if not autoFarmBoss then
        return
    end

    local tool = ensureToolEquipped()
    if not tool then
        return
    end

    local target = currentBossTarget

    local function isValidBoss(part)
        if not part or part.Parent == nil then
            return false
        end
        local pos = part.Position
        if not isInRange(pos) then
            return false
        end
        local curHp = part:GetAttribute("CurHP")
            or part:GetAttribute("CurHp")
            or part:GetAttribute("HP")
            or part:GetAttribute("Hp")
        if curHp ~= nil and tonumber(curHp) <= 0 then
            return false
        end
        return true
    end

    if not isValidBoss(target) then
        target = pickBossTarget()
        if not target then
            return
        end
    end

    local pos = target.Position
    sendHit(target, pos, tool)
    task.wait(farmDelay)
end

------------------- UI HELPERS -------------------
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
    title.Text = "Spear Fish Farm V2"

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
    subtitle.Text = "Auto Farm Spear + AimLock fish + ESP Antena neon kuning."

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
    height = height or 480

    local card = Instance.new("Frame")
    card.Name = titleText or "Card"
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

    if subtitleText and subtitleText ~= "" then
        local subtitle = Instance.new("TextLabel")
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

    return card
end

local function setToggleButtonState(button, labelText, state)
    if not button then
        return
    end
    labelText = labelText or "Toggle"
    if state then
        button.Text = labelText .. ": ON"
        button.BackgroundColor3 = Color3.fromRGB(45, 120, 75)
    else
        button.Text = labelText .. ": OFF"
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end
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

    setToggleButtonState(button, labelText, initialState)

    return button
end

local function createSliderWithBox(parent, titleText, minValue, maxValue, initialValue, decimals, onChanged)
    decimals = decimals or 0
    local factor = 10 ^ decimals
    local value  = initialValue

    local frame = Instance.new("Frame")
    frame.Name = titleText or "Slider"
    frame.Parent = parent
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 54)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(185, 185, 185)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Size = UDim2.new(0.6, 0, 0, 18)
    label.Text = titleText or "Slider"

    local box = Instance.new("TextBox")
    box.Name = "ValueBox"
    box.Parent = frame
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 11
    box.TextColor3 = Color3.fromRGB(230, 230, 230)
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Position = UDim2.new(0.62, 0, 0, 0)
    box.Size = UDim2.new(0.38, 0, 0, 18)

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box

    local sliderBack = Instance.new("Frame")
    sliderBack.Name = "SliderBack"
    sliderBack.Parent = frame
    sliderBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderBack.BorderSizePixel = 0
    sliderBack.Position = UDim2.new(0, 0, 0, 24)
    sliderBack.Size = UDim2.new(1, 0, 0, 16)

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 6)
    sliderCorner.Parent = sliderBack

    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Parent = sliderBack
    sliderFill.BackgroundColor3 = Color3.fromRGB(120, 180, 80)
    sliderFill.BorderSizePixel = 0
    sliderFill.Size = UDim2.new(0, 0, 1, 0)

    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(0, 6)
    sliderFillCorner.Parent = sliderFill

    local dragging = false

    local function applyValue(newValue)
        if newValue < minValue then
            newValue = minValue
        elseif newValue > maxValue then
            newValue = maxValue
        end
        value = math.floor(newValue * factor + 0.5) / factor
        box.Text = string.format("%." .. decimals .. "f", value)

        local backSize = sliderBack.AbsoluteSize.X
        if backSize > 0 then
            local alpha = (value - minValue) / (maxValue - minValue)
            sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
        end

        if onChanged then
            onChanged(value)
        end
    end

    local function setFromX(x)
        local pos = sliderBack.AbsolutePosition.X
        local size = sliderBack.AbsoluteSize.X
        if size <= 0 then
            return
        end
        local alpha = (x - pos) / size
        if alpha < 0 then
            alpha = 0
        elseif alpha > 1 then
            alpha = 1
        end
        local newValue = minValue + (maxValue - minValue) * alpha
        applyValue(newValue)
    end

    table.insert(connections, sliderBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end))

    table.insert(connections, sliderBack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end))

    table.insert(connections, box.FocusLost:Connect(function()
        local raw = box.Text or ""
        raw = raw:gsub(",", ".")
        local num = tonumber(raw)
        if not num then
            applyValue(value)
            return
        end
        applyValue(num)
    end))

    applyValue(initialValue)

    return frame
end

------------------- STATUS LABEL -------------------
local function updateStatusLabel()
    if not statusLabel then
        return
    end

    local seaModeText   = seaModeList[seaModeIndex]   or "AutoDetect"
    local rarityModeTxt = rarityModeList[rarityModeIndex] or "Disabled"

    statusLabel.Text = string.format(
        "Status: AutoFarm %s, Boss %s, Rare %s, Illahi %s, SeaMode %s, Rarity %s, AimLock %s, ESP Antena %s, Range %.0f stud, Delay %.3fs.",
        autoFarmAll and "ON" or "OFF",
        autoFarmBoss and "ON" or "OFF",
        autoFarmRare and "ON" or "OFF",
        autoFarmIllahi and "ON" or "OFF",
        seaModeText,
        rarityModeTxt,
        aimLockEnabled and "ON" or "OFF",
        espAntennaEnabled and "ON" or "OFF",
        shootRange,
        farmDelay
    )
end

------------------- CLIMATE + PER FISH UI SYNC -------------------
local perFishContainer
local perFishInfoLabel
local lastPerFishSeaName   = nil
local lastPerFishClimate   = nil

local function normalizeClimateName(raw)
    if not raw then
        return nil
    end
    local s = string.lower(tostring(raw))
    if s:find("grass") then
        return "Grassland"
    end
    if s:find("marsh") or s:find("swamp") then
        return "Marsh"
    end
    if s:find("ice") or s:find("frost") or s:find("snow") then
        return "Iceborne"
    end
    return nil
end

local function getCurrentClimateTag()
    local ws = workspace
    local v = ws:GetAttribute("Climate") or ws:GetAttribute("ClimateName") or ws:GetAttribute("CurClimate")
    local tag = normalizeClimateName(v)
    if tag then
        return tag
    end

    local plr = LocalPlayer
    if plr then
        v = plr:GetAttribute("Climate") or plr:GetAttribute("CurClimate")
        tag = normalizeClimateName(v)
        if tag then
            return tag
        end
    end

    local rs = ReplicatedStorage
    local cands = {"Climate","CurClimate","ClimateName"}
    for _, name in ipairs(cands) do
        local inst = rs:FindFirstChild(name)
        if inst and inst:IsA("StringValue") then
            tag = normalizeClimateName(inst.Value)
            if tag then
                return tag
            end
        end
    end

    return nil
end

local function getPerFishCandidates()
    local _, seaName = getActiveSeaFolder()
    if not seaName or (seaName ~= "Sea4" and seaName ~= "Sea5" and seaName ~= "Sea6" and seaName ~= "Sea7") then
        return {}, seaName, nil
    end

    local climateTag = getCurrentClimateTag()
    local result = {}

    for _, cfg in ipairs(PER_FISH_CONFIG) do
        if (not cfg.sea or cfg.sea == seaName) then
            if not cfg.climates or not climateTag then
                table.insert(result, cfg)
            else
                for _, c in ipairs(cfg.climates) do
                    if c == climateTag then
                        table.insert(result, cfg)
                        break
                    end
                end
            end
        end
    end

    return result, seaName, climateTag
end

local function refreshPerFishButtons(force)
    if not perFishContainer then
        return
    end

    local configs, seaName, climateTag = getPerFishCandidates()

    if not force and seaName == lastPerFishSeaName and climateTag == lastPerFishClimate then
        return
    end
    lastPerFishSeaName = seaName
    lastPerFishClimate = climateTag

    for _, child in ipairs(perFishContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    if perFishInfoLabel then
        local seaText     = seaName or "Unknown"
        local climateText = climateTag or "All"
        perFishInfoLabel.Text = string.format("Per Fish (Sea: %s, Climate: %s) – %d opsi.", seaText, climateText, #configs)
    end

    for _, cfg in ipairs(configs) do
        local btn = createToggleButton(perFishContainer, cfg.name, PER_FISH_FLAGS[cfg.id])
        table.insert(connections, btn.MouseButton1Click:Connect(function()
            local newState = not PER_FISH_FLAGS[cfg.id]
            PER_FISH_FLAGS[cfg.id] = newState
            setToggleButtonState(btn, cfg.name, newState)
        end))
    end
end

------------------- BUILD UI CARD: AUTO FARM SPEAR -------------------
local function buildAutoFarmCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "Auto Farm - Spear Fishing",
        "Auto Hit Spear Sea1 - Sea7 + Boss + Rare + Illahi. AimLock fish + ESP Antena neon dari body ke target.",
        1,
        540
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "AutoFarmScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 40)
    scroll.Size = UDim2.new(1, 0, 1, -40)
    scroll.ScrollBarThickness = 4
    scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingTop = UDim.new(0, 0)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 0)
    padding.PaddingRight = UDim.new(0, 0)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end))

    local autoFarmAllButton    = createToggleButton(scroll, "AutoFarm Universal (Sea1 - Sea7)", autoFarmAll)
    local autoFarmBossButton   = createToggleButton(scroll, "AutoFarm Boss (WorldBoss)", autoFarmBoss)
    local autoFarmRareButton   = createToggleButton(scroll, "AutoFarm Mythic/Legendary/Secret", autoFarmRare)
    local autoFarmIllahiButton = createToggleButton(scroll, "AutoFarm Illahi/Divine", autoFarmIllahi)

    local aimLockButton        = createToggleButton(scroll, "AimLock Fish + Label", aimLockEnabled)
    local espAntennaButton     = createToggleButton(scroll, "ESP Antena (Neon Line)", espAntennaEnabled)

    local seaModeButton = Instance.new("TextButton")
    seaModeButton.Name = "SeaModeButton"
    seaModeButton.Parent = scroll
    seaModeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    seaModeButton.BorderSizePixel  = 0
    seaModeButton.AutoButtonColor  = true
    seaModeButton.Font             = Enum.Font.Gotham
    seaModeButton.TextSize         = 11
    seaModeButton.TextColor3       = Color3.fromRGB(220, 220, 220)
    seaModeButton.TextWrapped      = true
    seaModeButton.Size             = UDim2.new(1, 0, 0, 26)

    local seaModeCorner = Instance.new("UICorner")
    seaModeCorner.CornerRadius = UDim.new(0, 8)
    seaModeCorner.Parent = seaModeButton

    local function updateSeaModeButtonText()
        local mode = seaModeList[seaModeIndex] or "AutoDetect"
        local desc
        if mode == "AutoDetect" then
            desc = "AutoDetect Sea (pilih otomatis)"
        elseif mode == "Sea1" then
            desc = "Sea1: Beginner River"
        elseif mode == "Sea2" or mode == "Sea3" then
            desc = mode .. ": Island Center / Lake"
        elseif mode == "Sea4" then
            desc = "Sea4: Submerged Pond"
        elseif mode == "Sea5" or mode == "Sea6" or mode == "Sea7" then
            desc = mode .. ": Nether Island"
        else
            desc = mode
        end
        seaModeButton.Text = "Sea Mode: " .. desc
    end

    updateSeaModeButtonText()

    local rarityModeButton = Instance.new("TextButton")
    rarityModeButton.Name = "RarityModeButton"
    rarityModeButton.Parent = scroll
    rarityModeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    rarityModeButton.BorderSizePixel  = 0
    rarityModeButton.AutoButtonColor  = true
    rarityModeButton.Font             = Enum.Font.Gotham
    rarityModeButton.TextSize         = 11
    rarityModeButton.TextColor3       = Color3.fromRGB(220, 220, 220)
    rarityModeButton.TextWrapped      = true
    rarityModeButton.Size             = UDim2.new(1, 0, 0, 26)

    local rarityModeCorner = Instance.new("UICorner")
    rarityModeCorner.CornerRadius = UDim.new(0, 8)
    rarityModeCorner.Parent = rarityModeButton

    local function updateRarityModeButtonText()
        local mode = rarityModeList[rarityModeIndex] or "Disabled"
        local desc
        if rarityModeIndex == 1 then
            desc = "Disabled (Universal, pakai pengaturan AutoFarm di atas)"
        elseif rarityModeIndex == 2 then
            desc = "Legendary/Mythic/Secret/Illahi berdasarkan Sea"
        elseif rarityModeIndex == 3 then
            desc = "Per Fish (list dinamis Sea + Climate)"
        else
            desc = mode
        end
        rarityModeButton.Text = "Rarity Mode: " .. desc
    end

    updateRarityModeButtonText()

    createSliderWithBox(
        scroll,
        "Shooting Range (stud) 25 - 1000",
        SHOOT_RANGE_MIN,
        SHOOT_RANGE_MAX,
        shootRange,
        0,
        function(val)
            shootRange = val
            updateStatusLabel()
        end
    )

    createSliderWithBox(
        scroll,
        "Farm Delay (detik) 0.01 - 0.30",
        FARM_DELAY_MIN,
        FARM_DELAY_MAX,
        farmDelay,
        3,
        function(val)
            farmDelay = val
            updateStatusLabel()
        end
    )

    local perFishLabel = Instance.new("TextLabel")
    perFishLabel.Name = "PerFishLabel"
    perFishLabel.Parent = scroll
    perFishLabel.BackgroundTransparency = 1
    perFishLabel.Font = Enum.Font.GothamSemibold
    perFishLabel.TextSize = 12
    perFishLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    perFishLabel.TextXAlignment = Enum.TextXAlignment.Left
    perFishLabel.Size = UDim2.new(1, 0, 0, 18)
    perFishLabel.Text = "Per Fish Selection (Sea4/Sea5/Sea6/Sea7, sinkron Sea + Climate):"

    perFishContainer = Instance.new("Frame")
    perFishContainer.Name = "PerFishContainer"
    perFishContainer.Parent = scroll
    perFishContainer.BackgroundTransparency = 1
    perFishContainer.BorderSizePixel = 0
    perFishContainer.Size = UDim2.new(1, 0, 0, 0)
    perFishContainer.AutomaticSize = Enum.AutomaticSize.Y

    local perFishLayout = Instance.new("UIListLayout")
    perFishLayout.Parent = perFishContainer
    perFishLayout.FillDirection = Enum.FillDirection.Vertical
    perFishLayout.SortOrder = Enum.SortOrder.LayoutOrder
    perFishLayout.Padding = UDim.new(0, 4)

    perFishInfoLabel = Instance.new("TextLabel")
    perFishInfoLabel.Name = "PerFishInfo"
    perFishInfoLabel.Parent = perFishContainer
    perFishInfoLabel.BackgroundTransparency = 1
    perFishInfoLabel.Font = Enum.Font.Gotham
    perFishInfoLabel.TextSize = 11
    perFishInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
    perFishInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    perFishInfoLabel.TextWrapped = true
    perFishInfoLabel.Size = UDim2.new(1, 0, 0, 30)
    perFishInfoLabel.Text = "Per Fish (Sea: -, Climate: -)."

    statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = scroll
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextWrapped = true
    statusLabel.Size = UDim2.new(1, 0, 0, 52)
    statusLabel.Text = ""

    updateStatusLabel()
    refreshPerFishButtons(true)

    table.insert(connections, autoFarmAllButton.MouseButton1Click:Connect(function()
        autoFarmAll = not autoFarmAll
        setToggleButtonState(autoFarmAllButton, "AutoFarm Universal (Sea1 - Sea7)", autoFarmAll)
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Universal: " .. (autoFarmAll and "ON" or "OFF"), 2)
    end))

    table.insert(connections, autoFarmBossButton.MouseButton1Click:Connect(function()
        autoFarmBoss = not autoFarmBoss
        setToggleButtonState(autoFarmBossButton, "AutoFarm Boss (WorldBoss)", autoFarmBoss)
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Boss: " .. (autoFarmBoss and "ON" or "OFF"), 2)
    end))

    table.insert(connections, autoFarmRareButton.MouseButton1Click:Connect(function()
        autoFarmRare = not autoFarmRare
        setToggleButtonState(autoFarmRareButton, "AutoFarm Mythic/Legendary/Secret", autoFarmRare)
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Rare: " .. (autoFarmRare and "ON" or "OFF"), 2)
    end))

    table.insert(connections, autoFarmIllahiButton.MouseButton1Click:Connect(function()
        autoFarmIllahi = not autoFarmIllahi
        setToggleButtonState(autoFarmIllahiButton, "AutoFarm Illahi/Divine", autoFarmIllahi)
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Illahi: " .. (autoFarmIllahi and "ON" or "OFF"), 2)
    end))

    table.insert(connections, aimLockButton.MouseButton1Click:Connect(function()
        aimLockEnabled = not aimLockEnabled
        setToggleButtonState(aimLockButton, "AimLock Fish + Label", aimLockEnabled)
        if not aimLockEnabled then
            clearAimLockVisual()
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "AimLock: " .. (aimLockEnabled and "ON" or "OFF"), 2)
    end))

    table.insert(connections, espAntennaButton.MouseButton1Click:Connect(function()
        espAntennaEnabled = not espAntennaEnabled
        setToggleButtonState(espAntennaButton, "ESP Antena (Neon Line)", espAntennaEnabled)
        if not espAntennaEnabled and antennaPart then
            antennaPart.Transparency = 1
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "ESP Antena: " .. (espAntennaEnabled and "ON" or "OFF"), 2)
    end))

    table.insert(connections, seaModeButton.MouseButton1Click:Connect(function()
        seaModeIndex = seaModeIndex + 1
        if seaModeIndex > #seaModeList then
            seaModeIndex = 1
        end
        updateSeaModeButtonText()
        updateStatusLabel()
        refreshPerFishButtons(true)
    end))

    table.insert(connections, rarityModeButton.MouseButton1Click:Connect(function()
        rarityModeIndex = rarityModeIndex + 1
        if rarityModeIndex > #rarityModeList then
            rarityModeIndex = 1
        end
        updateRarityModeButtonText()
        updateStatusLabel()
        refreshPerFishButtons(true)
    end))
end

------------------- BUILD UI -------------------
local function buildAllUI()
    local _, bodyScroll = createMainLayout()
    buildAutoFarmCard(bodyScroll)
end

buildAllUI()

------------------- BACKGROUND LOOPS -------------------
task.spawn(function()
    while alive do
        local ok, err = pcall(function()
            processAutoFarmFishStep()
        end)
        if not ok then
            warn("[SpearFishFarm] AutoFarmFish error:", err)
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while alive do
        local ok, err = pcall(function()
            processAutoFarmBossStep()
        end)
        if not ok then
            warn("[SpearFishFarm] AutoFarmBoss error:", err)
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while alive do
        pcall(updateAimLockDistanceLabel)
        task.wait(0.05)
    end
end)

-- Sinkron Sea + Climate untuk Per Fish UI (ringan)
task.spawn(function()
    while alive do
        local ok = pcall(function()
            refreshPerFishButtons(false)
        end)
        if not ok then
        end
        task.wait(3)
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    autoFarmAll        = false
    autoFarmBoss       = false
    autoFarmRare       = false
    autoFarmIllahi     = false
    aimLockEnabled     = false
    espAntennaEnabled  = false

    currentFishTarget      = nil
    currentFishTargetSea   = nil
    currentBossTarget      = nil
    currentBossTargetPart  = nil

    clearAimLockVisual()

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
