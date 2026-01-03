--==========================================================
--  20AxaTab_SpearFishFarm.lua
--  TAB 20: "Spear Fish Farm PRO++"
--  Fitur:
--    - AutoFarm: universal fish Sea1 - Sea7 (Hit remote)
--    - AutoFarm Boss (WorldBoss > Point1 / Point2)
--    - AutoFarm Mythic/Legendary/Secret (Sea4, Sea5)
--    - AutoFarm Illahi/Divine (Sea6, Sea7)
--    - Sea Selector: AutoDetect / Sea1 - Sea7
--    - AimLock Fish + Antena kuning ke target
--    - Shooting Range slider (300 - 1000 stud)
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

-- Aim lock
local aimLockEnabled = true

-- Shooting range (stud)
local SHOOT_RANGE_MIN = 300
local SHOOT_RANGE_MAX = 1000
local shootRange      = 600   -- default di tengah

-- Farm delay (detik)
local FARM_DELAY_MIN  = 0.01
local FARM_DELAY_MAX  = 0.30
local farmDelay       = 0.01

-- Status label UI
local statusLabel

------------------- FISH DATA SETS -------------------
-- Illahi / Divine (Sea6, Sea7)
local ILLAHI_SET = {
    Fish400 = true, -- Nether Barracuda
    Fish401 = true, -- Nether Anglerfish
    Fish402 = true, -- Nether Manta Ray
    Fish403 = true, -- Nether SwordFish
    Fish404 = true, -- Diamond Flying Fish
    Fish405 = true, -- Diamond Flying Fish
}

-- Secret Nether Island (Sea5)
local SECRET_SEA5_SET = {
    Fish500 = true, -- Abyssal Demon Shark
    Fish501 = true, -- Nighfall Demon Shark
    Fish503 = true, -- Ancient Gopala
    Fish504 = true, -- Nighfall Gopala
    Fish505 = true, -- Sharkster
    Fish508 = true, -- Mayfly Dragon
    Fish510 = true, -- Nighfall Sharkster
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
    -- Fish305 lagi (Christmas Shark Mythic)
    Fish202 = true, -- Nebula Lantern Carp Secret

    -- Climate Iceborne
    Fish121 = true, -- Dragon Whisker Fish Legendary
    -- Fish305 lagi (Christmas Shark Mythic)
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

------------------- HELPERS: NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Spear Fish Farm",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

------------------- HELPERS: CHARACTER / HRP -------------------
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
local function getEquippedHarpoonTool()
    local char = character
    if not char then
        return nil
    end

    -- Prioritas Harpoon22 kalau ada
    local harpoon22 = char:FindFirstChild("Harpoon22")
    if harpoon22 and harpoon22:IsA("Tool") then
        return harpoon22
    end

    -- Harpoon dengan nama pola HarpoonXX
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

    -- Fallback pertama tool di character
    if bestTool then
        return bestTool
    end

    local anyTool = char:FindFirstChildWhichIsA("Tool")
    return anyTool
end

-- Optional: pakai ToolRE "Switch" index 1 agar lebih mudah equip
local lastAutoEquipWarn = 0
local function ensureToolEquipped()
    local tool = getEquippedHarpoonTool()
    if tool then
        return tool
    end

    if ToolRE then
        local args = {
            [1] = "Switch",
            [2] = {
                ["index"] = 1
            }
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

------------------- FISH FILTER HELPERS -------------------
local function shouldTargetFish(seaName, fishName)
    if not fishName or fishName == "" then
        return false
    end

    -- Boss tidak lewat sini
    if BOSS_IDS[fishName] then
        return false
    end

    -- All universal
    if autoFarmAll then
        return true
    end

    -- Rare Mythic/Legendary/Secret Sea4, Secret Sea5
    if autoFarmRare then
        if seaName == "Sea4" and RARE_SEA4_SET[fishName] then
            return true
        end
        if seaName == "Sea5" and SECRET_SEA5_SET[fishName] then
            return true
        end
    end

    -- Illahi Sea6, Sea7
    if autoFarmIllahi then
        if (seaName == "Sea6" or seaName == "Sea7") and ILLAHI_SET[fishName] then
            return true
        end
    end

    return false
end

------------------- AIMLOCK ANTENA -------------------
local aimLockTarget        = nil  -- Instance target fish atau boss
local aimLockTargetPart    = nil  -- BasePart target
local aimLockLabelName     = "Target"
local aimLockBeam          = nil
local aimLockAttachment    = nil
local aimLockBillboard     = nil
local aimLockLabel         = nil
local hrpAttachment        = nil

local function ensureHRPAttachment()
    local hrp = getHRP()
    if not hrp then
        hrpAttachment = nil
        return nil
    end

    if hrpAttachment and hrpAttachment.Parent == hrp then
        return hrpAttachment
    end

    local existing = hrp:FindFirstChild("AxaFarm_HRP_Att")
    if existing and existing:IsA("Attachment") then
        hrpAttachment = existing
    else
        local att = Instance.new("Attachment")
        att.Name = "AxaFarm_HRP_Att"
        att.Parent = hrp
        hrpAttachment = att
    end
    return hrpAttachment
end

local function clearAimLockVisual()
    if aimLockBeam then
        pcall(function() aimLockBeam:Destroy() end)
    end
    if aimLockAttachment then
        pcall(function() aimLockAttachment:Destroy() end)
    end
    if aimLockBillboard then
        pcall(function() aimLockBillboard:Destroy() end)
    end

    aimLockBeam       = nil
    aimLockAttachment = nil
    aimLockBillboard  = nil
    aimLockLabel      = nil
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

    local hrpAtt = ensureHRPAttachment()
    if not hrpAtt then
        return
    end

    if not aimLockTargetPart or not aimLockTargetPart:IsA("BasePart") then
        return
    end

    local fishAttachment = Instance.new("Attachment")
    fishAttachment.Name   = "AxaFarm_Target_Att"
    fishAttachment.Parent = aimLockTargetPart

    local beam = Instance.new("Beam")
    beam.Name         = "AxaFarm_Target_Beam"
    beam.Attachment0  = hrpAtt
    beam.Attachment1  = fishAttachment
    beam.FaceCamera   = true
    beam.Width0       = 0.12
    beam.Width1       = 0.12
    beam.Segments     = 10
    beam.Color        = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new(0)
    beam.Parent       = aimLockTargetPart

    local billboard = Instance.new("BillboardGui")
    billboard.Name          = "AxaFarm_Target_Billboard"
    billboard.Size          = UDim2.new(0, 160, 0, 24)
    billboard.StudsOffset   = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop   = true
    billboard.Parent        = aimLockTargetPart

    local label = Instance.new("TextLabel")
    label.Name                  = "Text"
    label.Parent                = billboard
    label.BackgroundTransparency = 0.25
    label.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
    label.BorderSizePixel       = 0
    label.Size                  = UDim2.new(1, 0, 1, 0)
    label.Font                  = Enum.Font.GothamSemibold
    label.TextSize              = 12
    label.TextColor3            = Color3.fromRGB(255, 255, 0)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
    label.TextWrapped           = true
    label.Text                  = aimLockLabelName .. " | Target"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = label

    aimLockBeam       = beam
    aimLockAttachment = fishAttachment
    aimLockBillboard  = billboard
    aimLockLabel      = label
end

local function updateAimLockDistanceLabel()
    if not aimLockLabel or not aimLockTargetPart then
        return
    end
    local hrp = getHRP()
    if not hrp then
        return
    end
    if not aimLockTargetPart or aimLockTargetPart.Parent == nil then
        clearAimLockVisual()
        return
    end

    local dist = (aimLockTargetPart.Position - hrp.Position).Magnitude
    local d    = math.floor(dist or 0)
    aimLockLabel.Text = string.format("%s | %d suds", aimLockLabelName, d)
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
                        -- ambil BasePart untuk antena
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

    -- Validasi target sekarang
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
    title.Text = "Spear Fish Farm V1.0"

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
    subtitle.Text = "Auto Farm Spear Fishing: Sea1 - Sea7 + Boss + Rare + Illahi."

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
    height = height or 220

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

-- Slider dengan input box
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

    local seaModeText = seaModeList[seaModeIndex] or "AutoDetect"

    statusLabel.Text = string.format(
        "Status: AutoFarm %s, Boss %s, Rare %s, Illahi %s, SeaMode %s, AimLock %s, Range %.0f stud, Delay %.3fs.",
        autoFarmAll and "ON" or "OFF",
        autoFarmBoss and "ON" or "OFF",
        autoFarmRare and "ON" or "OFF",
        autoFarmIllahi and "ON" or "OFF",
        seaModeText,
        aimLockEnabled and "ON" or "OFF",
        shootRange,
        farmDelay
    )
end

------------------- BUILD UI CARD: AUTO FARM SPEAR -------------------
local function buildAutoFarmCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "Auto Farm - Spear Fishing",
        "Auto Hit Spear untuk semua Sea, Boss, Rare, dan Illahi dengan AimLock dan antena.",
        1,
        300
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

    local autoFarmAllButton   = createToggleButton(scroll, "AutoFarm Universal (Sea1 - Sea7)", autoFarmAll)
    local autoFarmBossButton  = createToggleButton(scroll, "AutoFarm Boss (WorldBoss)", autoFarmBoss)
    local autoFarmRareButton  = createToggleButton(scroll, "AutoFarm Mythic/Legendary/Secret", autoFarmRare)
    local autoFarmIllahiButton = createToggleButton(scroll, "AutoFarm Illahi/Divine", autoFarmIllahi)

    local aimLockButton       = createToggleButton(scroll, "AimLock Fish + Antena", aimLockEnabled)

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
            desc = "AutoDetect Sea: ON (pilih Sea otomatis)"
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

    createSliderWithBox(
        scroll,
        "Shooting Range (stud) 300 - 1000",
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

    -- Events
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
        setToggleButtonState(aimLockButton, "AimLock Fish + Antena", aimLockEnabled)
        if not aimLockEnabled then
            clearAimLockVisual()
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "AimLock: " .. (aimLockEnabled and "ON" or "OFF"), 2)
    end))

    table.insert(connections, seaModeButton.MouseButton1Click:Connect(function()
        seaModeIndex = seaModeIndex + 1
        if seaModeIndex > #seaModeList then
            seaModeIndex = 1
        end
        updateSeaModeButtonText()
        updateStatusLabel()
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
        task.wait(0.25)
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    autoFarmAll    = false
    autoFarmBoss   = false
    autoFarmRare   = false
    autoFarmIllahi = false
    aimLockEnabled = false

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