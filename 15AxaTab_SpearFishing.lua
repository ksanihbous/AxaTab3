--==========================================================
--  15AxaTab_SpearFishing.lua
--  TAB 15: "Spear Fishing PRO++"
--  FIX: "Out of local registers ... exceeded limit 200"
--  Cara fix:
--    1) Kurangi jumlah local variable di chunk utama
--    2) Pindahkan mayoritas logic/UI ke dalam function + table state
--    3) Hindari pola: local a,b = func() berulang kali (nambah register)
--  FITUR TETAP SAMA, hanya refactor agar ringan dan tidak mentok limit Luau.
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame = TAB_FRAME
local tabId = TAB_ID or "spearfishing"
if not frame then return end

------------------- SERVICES -------------------
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local HttpService         = game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local StarterGui          = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local MarketplaceService  = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

------------------- UI ROOT RESET -------------------
frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

------------------- GLOBAL STATE / AXAHUB -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

------------------- STATE TABLE (mengurangi local register) -------------------
local S = {
    alive = true,

    -- Flags
    autoFarm       = false,
    autoEquip      = false,
    autoFarmV2     = false,
    autoFarmV2Mode = "Left",

    spawnBossNotifier   = true,
    hpBossNotifier      = true,
    spawnIllahiNotifier = true,
    spawnSecretNotifier = true,

    espBoss   = true,
    espIllahi = false,
    espSecret = false,

    autoSkill1 = true, -- Skill02
    autoSkill2 = true, -- Skill08
    autoSkill3 = true, -- Skill01
    autoSkill4 = true, -- Skill07
    autoSkill5 = true, -- Skill09

    -- Tap interval
    autoFarmV2TapInterval = 0.03,
    TAP_INTERVAL_MIN      = 0.01,
    TAP_INTERVAL_MAX      = 1.00,

    -- Instances
    character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(),
    backpack  = (LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")),

    connections = {},
    ToolsData = nil,
    SpearFishData = nil,
    spearInitTried = false,

    -- Remotes
    RepRemotes = nil,
    FireRE = nil,
    ToolRE = nil,
    FishRE = nil,

    -- Require modules
    ItemUtil = nil,
    ToolUtil = nil,
    FormatUtil = nil,
    PurchaseUtil = nil,
    MathUtil = nil,
    FishUtil = nil,

    -- Game name
    GAME_NAME = "Unknown Map",

    -- Lists/Defs
    HARPOON_IDS = {
        "Harpoon01","Harpoon02","Harpoon03","Harpoon04","Harpoon05","Harpoon06","Harpoon07","Harpoon08","Harpoon09",
        "Harpoon10","Harpoon11","Harpoon12","Harpoon20","Harpoon21",
    },

    ILLAHI_ORDER = {"Fish400","Fish401","Fish402","Fish403","Fish404","Fish405"},
    ILLAHI_FISH_DEFS = {
        Fish400 = { name = "Nether Barracuda",    sea = "Sea7" },
        Fish401 = { name = "Nether Anglerfish",   sea = "Sea7" },
        Fish402 = { name = "Nether Manta Ray",    sea = "Sea6" },
        Fish403 = { name = "Nether SwordFish",    sea = "Sea6" },
        Fish404 = { name = "Diamond Flying Fish", sea = "Sea6" },
        Fish405 = { name = "Diamond Flying Fish", sea = "Sea6" },
    },
    ILLAHI_SEA_SET = { Sea6 = true, Sea7 = true },

    SECRET_ORDER = {"Fish500","Fish501","Fish503","Fish504","Fish505","Fish508","Fish510"},
    SECRET_FISH_DEFS = {
        Fish500 = { name = "Abyssal Demon Shark",  sea = "Sea5" },
        Fish501 = { name = "Nighfall Demon Shark", sea = "Sea5" },
        Fish503 = { name = "Ancient Gopala",       sea = "Sea5" },
        Fish504 = { name = "Nighfall Gopala",      sea = "Sea5" },
        Fish505 = { name = "Sharkster",            sea = "Sea5" },
        Fish508 = { name = "Mayfly Dragon",        sea = "Sea5" },
        Fish510 = { name = "Nighfall Sharkster",   sea = "Sea5" },
    },
    SECRET_SEA_SET = { Sea5 = true },

    -- Per-ikan toggles
    illahiFishEnabled = { Fish400=true,Fish401=true,Fish402=true,Fish403=true,Fish404=true,Fish405=true },
    secretFishEnabled = { Fish500=false,Fish501=false,Fish503=false,Fish504=false,Fish505=false,Fish508=false,Fish510=false },

    espIllahiFishEnabled = { Fish400=false,Fish401=false,Fish402=false,Fish403=false,Fish404=false,Fish405=false },
    espSecretFishEnabled = { Fish500=false,Fish501=false,Fish503=false,Fish504=false,Fish505=false,Fish508=false,Fish510=false },

    -- ESP Maps
    trackedFishEspTargets = {}, -- [part] = {fishId, fishType, displayName}
    fishEspMap = {},            -- [part] = {beam, attachment, billboard, label, displayName, fishType, fishId}
    hrpAttachment = nil,

    -- Harpoon UI map
    harpoonCardsById = {},

    -- Skill timers
    SKILL1_COOLDOWN = 15,
    SKILL2_COOLDOWN = 20,
    SKILL_SEQUENCE_GAP = 3,
    skillLast = { s1=0,s2=0,s3=0,s4=0,s5=0 },

    -- Autofarm v1
    lastShotClock = 0,
    FIRE_INTERVAL = 0.35,

    -- Sell
    lastSellClock = 0,
    SELL_COOLDOWN = 2,

    -- Boss notifier
    SPAWN_BOSS_WEBHOOK_URL  = "https://discord.com/api/webhooks/1435079884073341050/vEy2YQrpQQcN7pMs7isWqPtylN_AyJbzCAo_xDqM7enRacbIBp43SG1IR_hH-3j4zrfW",
    SPAWN_BOSS_BOT_USERNAME = "Spawn Boss Notifier",
    SPAWN_BOSS_BOT_AVATAR   = "https://mylogo.edgeone.app/Logo%20Ax%20(NO%20BG).png",
    DEFAULT_OWNER_DISCORD   = "<@1403052152691101857>",

    HP_BOSS_WEBHOOK_URL  = "https://discord.com/api/webhooks/1456150372686237849/NTDxNaXWeJ1ytvzTo9vnmG5Qvbl6gsvZor4MMb9rWUwKT4fFkRQ9NbNiPsy7-TWogTmR",
    HP_BOSS_BOT_USERNAME = "HP Boss Notifier",

    BOSS_ID_NAME_MAP = {
        Boss01 = "Humpback Whale",
        Boss02 = "Whale Shark",
        Boss03 = "Crimson Rift Dragon",
    },

    NEAR_REMAIN_THRESHOLD = 240,
    bossRegionState = {},
    hpRegionState   = {},
    spawnBossRequestFunc = nil,

    HP_SEND_MIN_INTERVAL = 1.5,
    HP_MIN_DELTA_RATIO   = 0.005,

    -- UI refs
    ui = {
        header = nil,
        bodyScroll = nil,
        statusLabel = nil,
        skillInfo1 = nil,
        skillInfo2 = nil,
        v2ModeButton = nil,
        tapSpeedBox = nil,
    }
}

------------------- SMALL HELPERS -------------------
local function addConn(conn)
    if conn then
        table.insert(S.connections, conn)
    end
end

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Spear Fishing",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

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

------------------- INIT REMOTES & MODULES -------------------
do
    S.RepRemotes = ReplicatedStorage:FindFirstChild("Remotes")
    S.FireRE = S.RepRemotes and S.RepRemotes:FindFirstChild("FireRE")
    S.ToolRE = S.RepRemotes and S.RepRemotes:FindFirstChild("ToolRE")
    S.FishRE = S.RepRemotes and S.RepRemotes:FindFirstChild("FishRE")

    local UtilityFolder = ReplicatedStorage:FindFirstChild("Utility")
    S.ItemUtil     = safeRequire(UtilityFolder, "ItemUtil")
    S.ToolUtil     = safeRequire(UtilityFolder, "ToolUtil")
    S.FormatUtil   = safeRequire(UtilityFolder, "Format")
    S.PurchaseUtil = safeRequire(UtilityFolder, "PurchaseUtil")
    S.MathUtil     = safeRequire(UtilityFolder, "MathUtil")
    S.FishUtil     = safeRequire(UtilityFolder, "FishUtil")

    local okInfo, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if okInfo and info and info.Name then
        S.GAME_NAME = tostring(info.Name)
    end
end

------------------- ESP HELPERS -------------------
local function getHRP()
    local ch = S.character
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
end

local function ensureHRPAttachment()
    local hrp = getHRP()
    if not hrp then
        S.hrpAttachment = nil
        return nil
    end

    if S.hrpAttachment and S.hrpAttachment.Parent == hrp then
        return S.hrpAttachment
    end

    local existing = hrp:FindFirstChild("AxaESP_HRP_Att")
    if existing and existing:IsA("Attachment") then
        S.hrpAttachment = existing
        return S.hrpAttachment
    end

    local att = Instance.new("Attachment")
    att.Name = "AxaESP_HRP_Att"
    att.Parent = hrp
    S.hrpAttachment = att
    return att
end

local function destroyFishEsp(part)
    local data = S.fishEspMap[part]
    if not data then return end
    pcall(function() if data.beam then data.beam:Destroy() end end)
    pcall(function() if data.attachment and data.attachment.Parent then data.attachment:Destroy() end end)
    pcall(function() if data.billboard then data.billboard:Destroy() end end)
    S.fishEspMap[part] = nil
end

local function createEspInstancesForPart(part, displayName, fishType, fishId)
    local hrpAtt = ensureHRPAttachment()
    if not hrpAtt then return end
    if not part or not part:IsA("BasePart") then return end
    if S.fishEspMap[part] then return end

    local fishAttachment = part:FindFirstChild("AxaESP_Attachment")
    if not (fishAttachment and fishAttachment:IsA("Attachment")) then
        fishAttachment = Instance.new("Attachment")
        fishAttachment.Name = "AxaESP_Attachment"
        fishAttachment.Parent = part
    end

    local beam = Instance.new("Beam")
    beam.Name = "AxaESP_Beam"
    beam.Attachment0 = hrpAtt
    beam.Attachment1 = fishAttachment
    beam.FaceCamera = true
    beam.Width0 = 0.12
    beam.Width1 = 0.12
    beam.Segments = 10
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = part

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AxaESP_Billboard"
    billboard.Size = UDim2.new(0, 160, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Parent = billboard
    label.BackgroundTransparency = 0.25
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BorderSizePixel = 0
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(255, 255, 0)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextWrapped = true
    label.Text = displayName or "Fish"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    S.fishEspMap[part] = {
        beam        = beam,
        attachment  = fishAttachment,
        billboard   = billboard,
        label       = label,
        displayName = displayName or "Fish",
        fishType    = fishType,
        fishId      = fishId,
    }
end

local function evaluateEspForPart(part)
    local info = S.trackedFishEspTargets[part]
    if not info or not part or part.Parent == nil then
        destroyFishEsp(part)
        S.trackedFishEspTargets[part] = nil
        return
    end

    local should = false
    if info.fishType == "Boss" then
        should = S.espBoss
    elseif info.fishType == "Illahi" then
        if S.espIllahi and S.espIllahiFishEnabled[info.fishId] == true then
            should = true
        end
    elseif info.fishType == "Secret" then
        if S.espSecret and S.espSecretFishEnabled[info.fishId] == true then
            should = true
        end
    end

    if not should then
        destroyFishEsp(part)
        return
    end

    if not S.fishEspMap[part] then
        createEspInstancesForPart(part, info.displayName, info.fishType, info.fishId)
    end
end

local function refreshAllEsp()
    for part in pairs(S.fishEspMap) do
        destroyFishEsp(part)
    end
    for part in pairs(S.trackedFishEspTargets) do
        evaluateEspForPart(part)
    end
end

local function registerFishPartForEsp(part, fishId, fishType, displayName)
    if not part or not part:IsA("BasePart") then return end

    S.trackedFishEspTargets[part] = {
        fishId      = fishId,
        fishType    = fishType,
        displayName = displayName or fishId or "Fish",
    }

    evaluateEspForPart(part)

    addConn(part.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            S.trackedFishEspTargets[part] = nil
            destroyFishEsp(part)
        end
    end))
end

local function updateEspTextDistances()
    if not next(S.fishEspMap) then return end
    local hrp = getHRP()
    if not hrp then return end
    local hrpPos = hrp.Position

    for part, data in pairs(S.fishEspMap) do
        if not part or part.Parent == nil then
            destroyFishEsp(part)
        else
            local ok, dist = pcall(function()
                return (part.Position - hrpPos).Magnitude
            end)
            if ok and data.label then
                local d = math.floor(dist or 0)
                data.label.Text = string.format("%s | %d suds", data.displayName or "Fish", d)
            end
        end
    end
end

------------------- HARPOON TOOL HELPERS -------------------
local function isHarpoonTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool.Name:match("^Harpoon(%d+)$") ~= nil
end

local function getEquippedHarpoonTool()
    local ch = S.character
    if not ch then return nil end
    for _, child in ipairs(ch:GetChildren()) do
        if isHarpoonTool(child) then return child end
    end
    return nil
end

local function getBestHarpoonTool()
    local bestTool, bestRank

    local function scan(container)
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

    scan(S.character)
    scan(S.backpack)
    return bestTool
end

local function ensureHarpoonEquipped()
    if not S.character then return end
    if getEquippedHarpoonTool() then return end
    local best = getBestHarpoonTool()
    if best then best.Parent = S.character end
end

local function isToolOwnedGeneric(id)
    if S.ToolsData and S.ToolsData:FindFirstChild(id) then
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

    if hasIn(S.character) or hasIn(S.backpack) then return true end
    return false
end

local function isHarpoonOwned(id)
    return isToolOwnedGeneric(id)
end

------------------- AUTO FARM V1 -------------------
local function doFireHarpoon()
    if not S.alive or not S.autoFarm then return end
    if not S.FireRE then return end
    if not S.character then return end

    local now = os.clock()
    if now - S.lastShotClock < S.FIRE_INTERVAL then return end
    S.lastShotClock = now

    local harpoon = getEquippedHarpoonTool()
    if (not harpoon) and S.autoEquip then
        ensureHarpoonEquipped()
        harpoon = getEquippedHarpoonTool()
    end
    if not harpoon then return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local v = cam.ViewportSize
    local centerX, centerY = v.X/2, v.Y/2
    local ray = cam:ScreenPointToRay(centerX, centerY, 0)

    local origin = ray.Origin
    local destination = origin + ray.Direction * 300

    local ok, err = pcall(function()
        S.FireRE:FireServer("Fire", {
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

------------------- AUTO FARM V2 -------------------
local function getTapPositionForMode(mode)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local v = cam.ViewportSize
    local y = v.Y * 0.8
    local x = (mode == "Left") and (v.X * 0.3) or (v.X * 0.5)
    return Vector2.new(x, y)
end

local function tapScreenPosition(pos)
    if not pos or not VirtualInputManager then return end
    if UserInputService:GetFocusedTextBox() then return end

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
    if not S.alive or not S.autoFarmV2 then return end
    local pos = getTapPositionForMode(S.autoFarmV2Mode)
    if not pos then return end
    tapScreenPosition(pos)
end

------------------- SPEAR FISH DATA + SELL ALL -------------------
local function ensureSpearFishData()
    if S.SpearFishData or S.spearInitTried or not S.alive then
        return S.SpearFishData
    end
    S.spearInitTried = true

    local waitFn
    local okFn, fn = pcall(function()
        return shared and shared.WaitPlayerData
    end)
    if okFn and typeof(fn) == "function" then
        waitFn = fn
    end

    if waitFn then
        local keys = {"SpearFish","Spearfish","SpearFishing","SpearFishBag","FishSpear","FishSpearBag"}
        for _, key in ipairs(keys) do
            local ok, result = pcall(function() return waitFn(key) end)
            if ok and result and typeof(result) == "Instance" then
                S.SpearFishData = result
                break
            end
        end
    end

    if not S.SpearFishData then
        local keys2 = {"SpearFish","Spearfish","SpearFishBag","FishSpear","FishBag"}
        for _, name in ipairs(keys2) do
            local inst = LocalPlayer:FindFirstChild(name)
            if inst and inst:IsA("Folder") then
                S.SpearFishData = inst
                break
            end
        end
    end

    return S.SpearFishData
end

local function collectAllSpearFishUIDs()
    local data = ensureSpearFishData()
    if not data then return nil end

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
            list[#list+1] = tostring(uidValue)
        end
    end

    if #list == 0 then return nil end
    return list
end

local function sellAllFish()
    if not S.FishRE then
        notify("Spear Fishing", "Remote FishRE tidak ditemukan.", 4)
        return
    end

    local now = os.clock()
    if now - S.lastSellClock < S.SELL_COOLDOWN then
        notify("Spear Fishing", "Sell All terlalu cepat, tunggu beberapa detik.", 2)
        return
    end

    local uids = collectAllSpearFishUIDs()
    if not uids or #uids == 0 then
        S.lastSellClock = now
        notify("Spear Fishing", "Tidak ada ikan spear yang bisa dijual.", 3)
        return
    end

    S.lastSellClock = now

    local ok, err = pcall(function()
        S.FishRE:FireServer("SellAll", { UIDs = uids })
    end)

    if ok then
        notify("Spear Fishing", "Sell All Fish (" .. tostring(#uids) .. " ekor) dikirim.", 3)
    else
        warn("[SpearFishing] SellAll gagal:", err)
        notify("Spear Fishing", "Sell All gagal, cek Output/Console.", 4)
    end
end

------------------- AUTO SKILLS -------------------
local function fireSkill(skillId, key)
    if not S.alive or not S.FishRE then return end

    local flagOk = false
    if key == "s1" then flagOk = S.autoSkill1
    elseif key == "s2" then flagOk = S.autoSkill2
    elseif key == "s3" then flagOk = S.autoSkill3
    elseif key == "s4" then flagOk = S.autoSkill4
    elseif key == "s5" then flagOk = S.autoSkill5
    end
    if not flagOk then return end

    local ok, err = pcall(function()
        S.FishRE:FireServer("Skill", { ID = skillId })
    end)
    if ok then
        S.skillLast[key] = os.clock()
    else
        warn("[SpearFishing] Auto " .. tostring(skillId) .. " gagal:", err)
    end
end

------------------- WEBHOOK HELPERS (BOSS/HP/ILL/SECRET) -------------------
local function getSpawnBossRequestFunc()
    if S.spawnBossRequestFunc then return S.spawnBossRequestFunc end
    if syn and syn.request then S.spawnBossRequestFunc = syn.request
    elseif http and http.request then S.spawnBossRequestFunc = http.request
    elseif http_request then S.spawnBossRequestFunc = http_request
    elseif request then S.spawnBossRequestFunc = request
    end
    return S.spawnBossRequestFunc
end

local function sendWebhookGeneric(url, username, avatar, embed)
    if not url or url == "" then return end

    local payload = {
        username   = username,
        avatar_url = avatar,
        content    = S.DEFAULT_OWNER_DISCORD,
        embeds     = { embed },
    }

    local encoded
    local okEncode, resEncode = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if okEncode then
        encoded = resEncode
    else
        warn("[SpearFishing] JSONEncode failed:", resEncode)
        return
    end

    local reqFunc = getSpawnBossRequestFunc()
    if reqFunc then
        local okReq, resReq = pcall(reqFunc, {
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = encoded,
        })
        if not okReq then
            warn("[SpearFishing] webhook request failed:", resReq)
        end
    else
        local okPost, errPost = pcall(function()
            HttpService:PostAsync(url, encoded, Enum.HttpContentType.ApplicationJson, false)
        end)
        if not okPost then
            warn("[SpearFishing] HttpService PostAsync failed:", errPost)
        end
    end
end

local function getRegionNameForBoss(region)
    if not region or not region.Name then return "Unknown" end
    local attrName = region:GetAttribute("RegionName")
    if type(attrName) == "string" and attrName ~= "" then
        return attrName
    end
    return region.Name
end

local function getBossNameForRegion(region)
    if not region then return "Unknown Boss" end
    for id, display in pairs(S.BOSS_ID_NAME_MAP) do
        if region:FindFirstChild(id, true) then
            return display
        end
    end

    if S.FishUtil and S.ItemUtil then
        local okDesc, descendants = pcall(function() return region:GetDescendants() end)
        if okDesc and descendants then
            for _, inst in ipairs(descendants) do
                if inst:IsA("BasePart") then
                    local okFish, isFish = pcall(function() return S.FishUtil:isFish(inst) end)
                    if okFish and isFish then
                        local fishId = inst.Name
                        if S.BOSS_ID_NAME_MAP[fishId] then
                            return S.BOSS_ID_NAME_MAP[fishId]
                        end
                        local okName, niceName = pcall(function()
                            return S.ItemUtil:getName(fishId)
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
    if remainSeconds < 0 then remainSeconds = 0 end

    local mmss
    if S.MathUtil then
        local okFmt, res = pcall(function()
            return S.MathUtil:secondsToMMSS(remainSeconds)
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
    local remainingText = (stageKey == "spawn")
        and "Time Now: Guranteed Devine Boss In 00:00 menit"
        or formatBossRemainingText(remainSeconds)

    bossName = bossName or "Unknown Boss"
    local regionName = getRegionNameForBoss(region)

    local stageText, colorInt
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
    if not serverId or serverId == "" then serverId = "N/A" end

    return {
        title       = "Spawn Boss",
        description = S.DEFAULT_OWNER_DISCORD,
        color       = colorInt,
        fields      = {
            { name="Remaining Time", value=remainingText, inline=false },
            { name="Name Boss",      value=bossName,      inline=true  },
            { name="Region",         value=regionName,    inline=true  },
            { name="Stage",          value=stageText,     inline=false },
            { name="Name Map",       value=S.GAME_NAME,   inline=false },
            { name="Player",         value=playerValue,   inline=false },
            { name="Server ID",      value=serverId,      inline=false },
        },
        footer = { text = "Spear Fishing PRO+" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    }
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
    if not serverId or serverId == "" then serverId = "N/A" end

    local description = string.format(
        "%s\nHP %s: %s / %s (%s)",
        S.DEFAULT_OWNER_DISCORD, bossName, curHpText, maxHpText, percentText
    )

    return {
        title       = "HP Boss",
        description = description,
        color       = 0x00FF00,
        fields      = {
            { name="Boss",       value=bossName,                 inline=true  },
            { name="HP",         value=curHpText.." / "..maxHpText, inline=true },
            { name="HP Percent", value=percentText,              inline=true  },
            { name="Region",     value=regionName,               inline=true  },
            { name="Name Map",   value=S.GAME_NAME,              inline=false },
            { name="Player",     value=playerValue,              inline=false },
            { name="Server ID",  value=serverId,                 inline=false },
        },
        footer = { text = "Spear Fishing PRO+ | HP Boss Notifier" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    }
end

local function sendSpawnBossStage(region, stageKey, remainSeconds)
    if not S.alive or not S.spawnBossNotifier then return end
    local bossName = (stageKey == "spawn") and getBossNameForRegion(region) or "Unknown Boss"
    local embed = buildSpawnBossEmbed(region, stageKey, remainSeconds, bossName)
    sendWebhookGeneric(S.SPAWN_BOSS_WEBHOOK_URL, S.SPAWN_BOSS_BOT_USERNAME, S.SPAWN_BOSS_BOT_AVATAR, embed)
end

local function getBossPartInRegion(region)
    if not region then return nil end
    local okDesc, descendants = pcall(function() return region:GetDescendants() end)
    if not okDesc or not descendants then return nil end

    local function hasHpAttr(inst)
        return inst:GetAttribute("CurHP") ~= nil
            or inst:GetAttribute("CurHp") ~= nil
            or inst:GetAttribute("HP") ~= nil
            or inst:GetAttribute("Hp") ~= nil
    end

    if S.FishUtil then
        for _, inst in ipairs(descendants) do
            if inst:IsA("BasePart") then
                local okFish, isFish = pcall(function() return S.FishUtil:isFish(inst) end)
                if okFish and isFish and hasHpAttr(inst) then
                    return inst
                end
            end
        end
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") and hasHpAttr(inst) then
            return inst
        end
    end
    return nil
end

local function detachHpWatcher(region)
    local st = S.hpRegionState[region]
    if not st then return end

    local function safeDisc(conn)
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end

    safeDisc(st.connCurHP)
    safeDisc(st.connCurHp)
    safeDisc(st.connHP)
    safeDisc(st.connHp)

    S.hpRegionState[region] = nil
end

local function sendHpBossProgress(region, bossPart)
    if not S.alive then return end
    local st = S.hpRegionState[region]
    if not st or st.bossPart ~= bossPart then return end

    local rawCur = bossPart:GetAttribute("CurHP") or bossPart:GetAttribute("CurHp")
    local rawMax = bossPart:GetAttribute("HP")   or bossPart:GetAttribute("Hp")

    if rawCur == nil and rawMax ~= nil then rawCur = rawMax end
    if rawCur ~= nil and rawMax == nil then rawMax = rawCur end

    local curHp   = tonumber(rawCur or 0) or 0
    local totalHp = tonumber(rawMax or 0) or 0
    if totalHp <= 0 then totalHp = curHp end
    if totalHp <= 0 and curHp <= 0 then
        detachHpWatcher(region)
        return
    end

    local now = os.clock()
    local lastHp   = st.lastHp
    local lastSend = st.lastSendTime or 0

    if lastHp ~= nil and curHp == lastHp then return end

    local dropRatio = 0
    if totalHp > 0 and lastHp ~= nil and lastHp > 0 then
        dropRatio = math.abs(curHp - lastHp) / totalHp
    end

    if not S.hpBossNotifier then
        st.lastHp = curHp
        return
    end

    local mustSend = false
    if lastHp == nil then
        mustSend = true
    elseif curHp <= 0 and lastHp > 0 then
        mustSend = true
    elseif (now - lastSend) >= S.HP_SEND_MIN_INTERVAL and dropRatio >= S.HP_MIN_DELTA_RATIO then
        mustSend = true
    elseif (now - lastSend) >= 5 then
        mustSend = true
    end

    st.lastHp = curHp
    if not mustSend then return end
    st.lastSendTime = now

    local curText, maxText = tostring(curHp), tostring(totalHp)
    if S.FormatUtil then
        local ok1, r1 = pcall(function() return S.FormatUtil:DesignNumberShort(curHp) end)
        if ok1 and r1 then curText = r1 end
        local ok2, r2 = pcall(function() return S.FormatUtil:DesignNumberShort(totalHp) end)
        if ok2 and r2 then maxText = r2 end
    end

    local percentText = "N/A"
    if totalHp > 0 then
        local percent = math.max(0, math.min(1, curHp / totalHp)) * 100
        percentText = string.format("%.2f%%", percent)
    end

    local bossName = getBossNameForRegion(region)
    local embed = buildHpBossEmbed(region, bossName, curText, maxText, percentText)
    sendWebhookGeneric(S.HP_BOSS_WEBHOOK_URL, S.HP_BOSS_BOT_USERNAME, S.SPAWN_BOSS_BOT_AVATAR, embed)

    if curHp <= 0 then
        detachHpWatcher(region)
    end
end

local function attachHpWatcher(region)
    if not region then return end
    local hasBoss = region:GetAttribute("HasBoss")
    if not hasBoss then
        detachHpWatcher(region)
        return
    end

    local bossPart = getBossPartInRegion(region)
    if not bossPart then return end

    -- Register ESP Boss (selalu)
    registerFishPartForEsp(bossPart, bossPart.Name or "Boss", "Boss", getBossNameForRegion(region))

    local st = S.hpRegionState[region]
    if st and st.bossPart == bossPart then return end

    detachHpWatcher(region)

    st = {
        bossPart = bossPart,
        lastHp = nil,
        lastSendTime = 0,
        connCurHP = nil,
        connCurHp = nil,
        connHP = nil,
        connHp = nil,
    }
    S.hpRegionState[region] = st

    local function onHpChanged()
        if not S.alive then return end
        sendHpBossProgress(region, bossPart)
    end

    st.connCurHP = bossPart:GetAttributeChangedSignal("CurHP"):Connect(onHpChanged); addConn(st.connCurHP)
    st.connCurHp = bossPart:GetAttributeChangedSignal("CurHp"):Connect(onHpChanged); addConn(st.connCurHp)
    st.connHP    = bossPart:GetAttributeChangedSignal("HP"):Connect(onHpChanged);    addConn(st.connHP)
    st.connHp    = bossPart:GetAttributeChangedSignal("Hp"):Connect(onHpChanged);    addConn(st.connHp)

    task.spawn(function() sendHpBossProgress(region, bossPart) end)
end

local function updateWorldBossRegion(region)
    if not region then return end

    local st = S.bossRegionState[region]
    if not st then
        st = { sentStart=false, sentNear=false, sentSpawn=false }
        S.bossRegionState[region] = st
    end

    local hasBoss = region:GetAttribute("HasBoss")
    local remain  = tonumber(region:GetAttribute("RemainTime")) or 0

    if not hasBoss and remain <= 0 then
        st.sentStart = false
        st.sentNear  = false
        st.sentSpawn = false
    end

    if remain > 0 and not hasBoss and not st.sentStart then
        st.sentStart = true
        task.spawn(function() sendSpawnBossStage(region, "start", remain) end)
    end

    if remain > 0
        and remain <= S.NEAR_REMAIN_THRESHOLD
        and remain >= 180
        and st.sentStart
        and not st.sentNear
    then
        st.sentNear = true
        task.spawn(function() sendSpawnBossStage(region, "near", remain) end)
    end

    if hasBoss and not st.sentSpawn then
        st.sentSpawn = true
        task.spawn(function() sendSpawnBossStage(region, "spawn", remain) end)
    end
end

local function registerWorldBossRegion(region)
    if not region then return end

    task.spawn(function()
        updateWorldBossRegion(region)
        attachHpWatcher(region)
    end)

    addConn(region:GetAttributeChangedSignal("HasBoss"):Connect(function()
        if not S.alive then return end
        updateWorldBossRegion(region)
        if region:GetAttribute("HasBoss") then
            attachHpWatcher(region)
        else
            detachHpWatcher(region)
        end
    end))

    addConn(region:GetAttributeChangedSignal("RemainTime"):Connect(function()
        if not S.alive then return end
        updateWorldBossRegion(region)
    end))

    addConn(region:GetAttributeChangedSignal("NextSpawnTime"):Connect(function()
        if not S.alive then return end
        updateWorldBossRegion(region)
    end))

    addConn(region.ChildAdded:Connect(function()
        if not S.alive then return end
        updateWorldBossRegion(region)
        attachHpWatcher(region)
    end))
end

local function initWorldBossNotifier()
    task.spawn(function()
        task.wait(5)
        if not S.alive then return end

        local worldBossFolder = workspace:FindFirstChild("WorldBoss")
        if not worldBossFolder then
            local okWait, inst = pcall(function() return workspace:WaitForChild("WorldBoss", 10) end)
            if okWait and inst then worldBossFolder = inst end
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

        addConn(worldBossFolder.ChildAdded:Connect(function(child)
            if not S.alive then return end
            if child:IsA("BasePart") or child:IsA("Model") then
                registerWorldBossRegion(child)
            end
        end))
    end)
end

------------------- ILLAHI / SECRET SPAWN NOTIFIERS -------------------
local function initIllahiSpawnNotifier()
    task.spawn(function()
        task.wait(3)
        if not S.alive then return end

        local WEBHOOK_URL  = "https://discord.com/api/webhooks/1456157133325209764/ymVmoJR0gV21o_IpvCn6sj2jR31TqZPnWMem7jEmxZLt_Ppn__7j1cdsqna1u1mBq7yWz"
        local BOT_USERNAME = "Spawn Illahi Notifier"

        local function buildIllahiSpawnEmbed(region, fishId, fishName)
            local regionName = getRegionNameForBoss(region)
            local islandName = "Nether Island"

            local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
            local username    = LocalPlayer.Name or "Player"
            local userId      = LocalPlayer.UserId or 0
            local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

            local serverId = game.JobId
            if not serverId or serverId == "" then serverId = "N/A" end

            local fishLabel = fishName or "Unknown"
            if fishId and fishId ~= "" then fishLabel = fishLabel .. " (" .. tostring(fishId) .. ")" end

            return {
                title       = "Spawn Illahi",
                description = S.DEFAULT_OWNER_DISCORD,
                color       = 0x9400D3,
                fields      = {
                    { name="Illahi Fish", value=fishLabel,   inline=true  },
                    { name="Sea",         value=regionName,  inline=true  },
                    { name="Island",      value=islandName,  inline=true  },
                    { name="Name Map",    value=S.GAME_NAME, inline=false },
                    { name="Player",      value=playerValue, inline=false },
                    { name="Server ID",   value=serverId,    inline=false },
                },
                footer = { text = "Spear Fishing PRO+ | Spawn Illahi Notifier" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            }
        end

        local function handleIllahiFish(region, fishPart)
            if not fishPart or not fishPart.Name then return end
            local def = S.ILLAHI_FISH_DEFS[fishPart.Name]
            if not def then return end

            -- ESP register (selalu)
            registerFishPartForEsp(fishPart, fishPart.Name, "Illahi", def.name)

            if not S.alive then return end
            if not S.spawnIllahiNotifier then return end
            if S.illahiFishEnabled[fishPart.Name] == false then return end

            local embed = buildIllahiSpawnEmbed(region, fishPart.Name, def.name or fishPart.Name)
            sendWebhookGeneric(WEBHOOK_URL, BOT_USERNAME, S.SPAWN_BOSS_BOT_AVATAR, embed)
        end

        local function registerIllahiRegion(region)
            if not region or not region.Name then return end
            if not S.ILLAHI_SEA_SET[region.Name] then return end
            if not (region:IsA("BasePart") or region:IsA("Model")) then return end

            local function checkChild(child)
                if not child or not child.Name then return end
                if not child:IsA("BasePart") then return end
                if S.ILLAHI_FISH_DEFS[child.Name] then
                    handleIllahiFish(region, child)
                end
            end

            for _, child in ipairs(region:GetChildren()) do checkChild(child) end
            addConn(region.ChildAdded:Connect(function(child)
                if not S.alive then return end
                checkChild(child)
            end))
        end

        local worldSea = workspace:FindFirstChild("WorldSea")
        if not worldSea then
            local okWait, inst = pcall(function() return workspace:WaitForChild("WorldSea", 10) end)
            if okWait and inst then worldSea = inst end
        end
        if not worldSea then
            warn("[SpearFishing] WorldSea folder tidak ditemukan, Spawn Illahi Notifier idle.")
            return
        end

        for _, child in ipairs(worldSea:GetChildren()) do registerIllahiRegion(child) end
        addConn(worldSea.ChildAdded:Connect(function(child)
            if not S.alive then return end
            registerIllahiRegion(child)
        end))
    end)
end

local function initSecretSpawnNotifier()
    task.spawn(function()
        task.wait(3)
        if not S.alive then return end

        local WEBHOOK_URL  = "https://discord.com/api/webhooks/1456257955682062367/UKn20-hMHwtjd0BNsoH_aV_f30V7jlkTux2QNlwnb259BEEbabIifrYinj1I7XPK_0xK"
        local BOT_USERNAME = "Spawn Secret Notifier"

        local function buildSecretSpawnEmbed(region, fishId, fishName)
            local regionName = getRegionNameForBoss(region)
            local islandName = "Nether Island"

            local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
            local username    = LocalPlayer.Name or "Player"
            local userId      = LocalPlayer.UserId or 0
            local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

            local serverId = game.JobId
            if not serverId or serverId == "" then serverId = "N/A" end

            local fishLabel = fishName or "Unknown"
            if fishId and fishId ~= "" then fishLabel = fishLabel .. " (" .. tostring(fishId) .. ")" end

            return {
                title       = "Spawn Secret",
                description = S.DEFAULT_OWNER_DISCORD,
                color       = 0xFFD700,
                fields      = {
                    { name="Secret Fish", value=fishLabel,   inline=true  },
                    { name="Sea",         value=regionName,  inline=true  },
                    { name="Island",      value=islandName,  inline=true  },
                    { name="Name Map",    value=S.GAME_NAME, inline=false },
                    { name="Player",      value=playerValue, inline=false },
                    { name="Server ID",   value=serverId,    inline=false },
                },
                footer = { text = "Spear Fishing PRO+ | Spawn Secret Notifier" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            }
        end

        local function handleSecretFish(region, fishPart)
            if not fishPart or not fishPart.Name then return end
            local def = S.SECRET_FISH_DEFS[fishPart.Name]
            if not def then return end

            -- ESP register (selalu)
            registerFishPartForEsp(fishPart, fishPart.Name, "Secret", def.name)

            if not S.alive then return end
            if not S.spawnSecretNotifier then return end
            if S.secretFishEnabled[fishPart.Name] ~= true then return end

            local embed = buildSecretSpawnEmbed(region, fishPart.Name, def.name or fishPart.Name)
            sendWebhookGeneric(WEBHOOK_URL, BOT_USERNAME, S.SPAWN_BOSS_BOT_AVATAR, embed)
        end

        local function registerSecretRegion(region)
            if not region or not region.Name then return end
            if not S.SECRET_SEA_SET[region.Name] then return end
            if not (region:IsA("BasePart") or region:IsA("Model")) then return end

            local function checkChild(child)
                if not child or not child.Name then return end
                if not child:IsA("BasePart") then return end
                if S.SECRET_FISH_DEFS[child.Name] then
                    handleSecretFish(region, child)
                end
            end

            for _, child in ipairs(region:GetChildren()) do checkChild(child) end
            addConn(region.ChildAdded:Connect(function(child)
                if not S.alive then return end
                checkChild(child)
            end))
        end

        local worldSea = workspace:FindFirstChild("WorldSea")
        if not worldSea then
            local okWait, inst = pcall(function() return workspace:WaitForChild("WorldSea", 10) end)
            if okWait and inst then worldSea = inst end
        end
        if not worldSea then
            warn("[SpearFishing] WorldSea folder tidak ditemukan, Spawn Secret Notifier idle.")
            return
        end

        for _, child in ipairs(worldSea:GetChildren()) do registerSecretRegion(child) end
        addConn(worldSea.ChildAdded:Connect(function(child)
            if not S.alive then return end
            registerSecretRegion(child)
        end))
    end)
end

------------------- TOOLSDATA WATCHER -------------------
local function refreshHarpoonOwnership()
    for id, entry in pairs(S.harpoonCardsById) do
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

local function initToolsDataWatcher()
    task.spawn(function()
        if S.ToolsData then return end

        local waitFn
        while S.alive and not waitFn do
            local ok, fn = pcall(function()
                return shared and shared.WaitPlayerData
            end)
            if ok and typeof(fn) == "function" then
                waitFn = fn
                break
            end
            task.wait(0.2)
        end
        if not S.alive or not waitFn then return end

        local ok2, result = pcall(function() return waitFn("Tools") end)
        if not ok2 or not result then
            warn("[SpearFishing] Gagal WaitPlayerData('Tools'):", ok2 and "no result" or result)
            return
        end

        S.ToolsData = result

        local function onToolsChanged()
            if not S.alive then return end
            refreshHarpoonOwnership()
        end

        if S.ToolsData.AttributeChanged then
            addConn(S.ToolsData.AttributeChanged:Connect(onToolsChanged))
        end
        addConn(S.ToolsData.ChildAdded:Connect(onToolsChanged))
        addConn(S.ToolsData.ChildRemoved:Connect(onToolsChanged))

        onToolsChanged()
    end)
end

------------------- UI HELPERS (dibuat hemat local) -------------------
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
    title.Text = "Spear Fishing V3.5+"

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
    subtitle.Text = "AutoFarm + Auto Skill + Spawn Boss/HP + Illahi + Secret + ESP Fish."

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

    addConn(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
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

    local pad = Instance.new("UIPadding")
    pad.Parent = card
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = card
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = titleText or "Card"
    title.Size = UDim2.new(1, 0, 0, 18)

    if subtitleText and subtitleText ~= "" then
        local sub = Instance.new("TextLabel")
        sub.Name = "Subtitle"
        sub.Parent = card
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 12
        sub.TextColor3 = Color3.fromRGB(180, 180, 180)
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextWrapped = true
        sub.Text = subtitleText
        sub.Position = UDim2.new(0, 0, 0, 20)
        sub.Size = UDim2.new(1, 0, 0, 26)
    end

    return card
end

-- Toggle hemat register: tidak mengembalikan 2 return, updater tersimpan di closure
local function createToggle(parent, labelText, getState, setState, onChanged)
    local button = Instance.new("TextButton")
    button.Name = (labelText or "Toggle"):gsub("%s+", "") .. "Button"
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.Size = UDim2.new(1, 0, 0, 30)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local function redraw()
        local state = getState()
        if state then
            button.Text = labelText .. ": ON"
            button.BackgroundColor3 = Color3.fromRGB(45, 120, 75)
        else
            button.Text = labelText .. ": OFF"
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end

    redraw()

    addConn(button.MouseButton1Click:Connect(function()
        local newState = not getState()
        setState(newState)
        redraw()
        if onChanged then onChanged(newState) end
    end))

    return button, redraw
end

------------------- HARPOON SHOP (ringkas tapi fitur sama) -------------------
local function getHarpoonDisplayData(id)
    local name      = id
    local icon      = ""
    local dmgMin    = "-"
    local dmgMax    = "-"
    local crt       = "-"
    local charge    = "-"
    local priceText = "N/A"
    local assetType = "Currency"

    if S.ItemUtil then
        local okName, resName = pcall(function() return S.ItemUtil:getName(id) end)
        if okName and resName then name = resName end

        local okIcon, resIcon = pcall(function() return S.ItemUtil:getIcon(id) end)
        if okIcon and resIcon then icon = resIcon end

        local okDef, def = pcall(function() return S.ItemUtil:GetDef(id) end)
        if okDef and def and def.AssetType then assetType = def.AssetType end

        local okPrice, priceVal = pcall(function() return S.ItemUtil:getPrice(id) end)
        if okPrice and priceVal then
            if S.FormatUtil then
                local okFmt, fmtText = pcall(function() return S.FormatUtil:DesignNumberShort(priceVal) end)
                priceText = (okFmt and fmtText) and fmtText or tostring(priceVal)
            else
                priceText = tostring(priceVal)
            end
        end
    end

    if S.ToolUtil then
        local okDmg, minVal, maxVal = pcall(function() return S.ToolUtil:getHarpoonDMG(id) end)
        if okDmg and minVal and maxVal then
            dmgMin, dmgMax = tostring(minVal), tostring(maxVal)
        end

        local okCharge, chargeVal = pcall(function() return S.ToolUtil:getHarpoonChargeTime(id) end)
        if okCharge and chargeVal then charge = tostring(chargeVal) .. "s" end

        local okCRT, crtVal = pcall(function() return S.ToolUtil:getToolCRT(id) end)
        if okCRT and crtVal then crt = tostring(crtVal) .. "%" end
    end

    return { name=name, icon=icon, dmgMin=dmgMin, dmgMax=dmgMax, crt=crt, charge=charge, priceText=priceText, assetType=assetType }
end

local function buildHarpoonShopCard(parent)
    local card = createCard(parent, "Harpoon Shop", "Toko Harpoon (Image + DMG + CRT + Charge + Price).", 4, 280)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "HarpoonScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 40)
    scroll.Size = UDim2.new(1, 0, 1, -44)
    scroll.ScrollBarThickness = 4
    scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local pad = Instance.new("UIPadding")
    pad.Parent = scroll
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    for index, id in ipairs(S.HARPOON_IDS) do
        local data = getHarpoonDisplayData(id)

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 150, 0, 210)
        item.LayoutOrder = index

        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = item
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(70,70,70); st.Thickness = 1; st.Parent = item

        local img = Instance.new("ImageLabel")
        img.Parent = item
        img.BackgroundTransparency = 1
        img.Position = UDim2.new(0, 6, 0, 6)
        img.Size = UDim2.new(1, -12, 0, 70)
        img.Image = data.icon or ""
        img.ScaleType = Enum.ScaleType.Fit

        local nameLabel = Instance.new("TextLabel")
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
        stats.Text = string.format("DMG: %s~%s\nCRT: %s\nCharge: %s\nPrice: %s",
            tostring(data.dmgMin), tostring(data.dmgMax), tostring(data.crt), tostring(data.charge), tostring(data.priceText)
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

        local cb = Instance.new("UICorner"); cb.CornerRadius = UDim.new(0, 6); cb.Parent = buyBtn

        S.harpoonCardsById[id] = { frame=item, buyButton=buyBtn, assetType=data.assetType or "Currency", displayName=data.name or id }

        addConn(buyBtn.MouseButton1Click:Connect(function()
            if isHarpoonOwned(id) then
                notify("Spear Fishing", (data.name or id) .. " sudah dimiliki.", 3)
                refreshHarpoonOwnership()
                return
            end

            if not S.ToolRE then
                notify("Spear Fishing", "Remote ToolRE tidak ditemukan.", 4)
                return
            end

            local assetType = (S.harpoonCardsById[id] and S.harpoonCardsById[id].assetType) or "Currency"
            if assetType == "Robux" and S.PurchaseUtil then
                local ok, err = pcall(function() S.PurchaseUtil:getPurchase(id) end)
                if not ok then
                    warn("[SpearFishing] PurchaseUtil:getPurchase gagal:", err)
                    notify("Spear Fishing", "Gagal membuka purchase Robux.", 4)
                end
                return
            end

            local ok, err = pcall(function()
                S.ToolRE:FireServer("Buy", { ID = id })
            end)
            if ok then
                notify("Spear Fishing", "Request beli " .. (data.name or id) .. " dikirim.", 4)
            else
                warn("[SpearFishing] ToolRE:Buy gagal:", err)
                notify("Spear Fishing", "Gagal mengirim request beli, cek Output.", 4)
            end
        end))
    end

    refreshHarpoonOwnership()
    return card
end

------------------- UI BUILD (INI BAGIAN YANG DULU MELEDAK REGISTER) -------------------
local function buildUI()
    S.ui.header, S.ui.bodyScroll = createMainLayout()

    -- ========== SPEAR CONTROLS ==========
    local controlCard = createCard(
        S.ui.bodyScroll,
        "Spear Controls",
        "AutoFarm v1 + AutoFarm v2 (Tap Trackpad Left/Center) + AutoEquip + Auto Skill 1~5 + Sell All.",
        1,
        260
    )

    local controlsScroll = Instance.new("ScrollingFrame")
    controlsScroll.Parent = controlCard
    controlsScroll.BackgroundTransparency = 1
    controlsScroll.BorderSizePixel = 0
    controlsScroll.Position = UDim2.new(0, 0, 0, 40)
    controlsScroll.Size = UDim2.new(1, 0, 1, -40)
    controlsScroll.ScrollBarThickness = 4
    controlsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local controlsLayout = Instance.new("UIListLayout")
    controlsLayout.Parent = controlsScroll
    controlsLayout.FillDirection = Enum.FillDirection.Vertical
    controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    controlsLayout.Padding = UDim.new(0, 6)

    addConn(controlsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        controlsScroll.CanvasSize = UDim2.new(0, 0, 0, controlsLayout.AbsoluteContentSize.Y + 8)
    end))

    local function updateStatusLabel()
        if not S.ui.statusLabel then return end
        S.ui.statusLabel.Text = string.format(
            "Status: AutoFarm %s, AutoEquip %s, AutoFarm V2 %s (%s, %.2fs), SpawnBossNotifier %s, SpawnIllahiNotifier %s, SpawnSecretNotifier %s, HPBossNotifier %s, ESP Boss %s, ESP Illahi %s, ESP Secret %s, Skill1 %s, Skill2 %s, Skill3 %s, Skill4 %s, Skill5 %s.",
            S.autoFarm and "ON" or "OFF",
            S.autoEquip and "ON" or "OFF",
            S.autoFarmV2 and "ON" or "OFF",
            S.autoFarmV2Mode,
            S.autoFarmV2TapInterval,
            S.spawnBossNotifier and "ON" or "OFF",
            S.spawnIllahiNotifier and "ON" or "OFF",
            S.spawnSecretNotifier and "ON" or "OFF",
            S.hpBossNotifier and "ON" or "OFF",
            S.espBoss and "ON" or "OFF",
            S.espIllahi and "ON" or "OFF",
            S.espSecret and "ON" or "OFF",
            S.autoSkill1 and "ON" or "OFF",
            S.autoSkill2 and "ON" or "OFF",
            S.autoSkill3 and "ON" or "OFF",
            S.autoSkill4 and "ON" or "OFF",
            S.autoSkill5 and "ON" or "OFF"
        )
    end

    createToggle(controlsScroll, "AutoFarm Fish",
        function() return S.autoFarm end,
        function(v) S.autoFarm = v end,
        function() updateStatusLabel() end
    )

    createToggle(controlsScroll, "AutoEquip Harpoon",
        function() return S.autoEquip end,
        function(v) S.autoEquip = v end,
        function(v)
            if v then ensureHarpoonEquipped() end
            updateStatusLabel()
        end
    )

    createToggle(controlsScroll, "AutoFarm Fish V2",
        function() return S.autoFarmV2 end,
        function(v) S.autoFarmV2 = v end,
        function() updateStatusLabel() end
    )

    local v2ModeButton = Instance.new("TextButton")
    v2ModeButton.Parent = controlsScroll
    v2ModeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    v2ModeButton.BorderSizePixel = 0
    v2ModeButton.AutoButtonColor = true
    v2ModeButton.Font = Enum.Font.Gotham
    v2ModeButton.TextSize = 11
    v2ModeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    v2ModeButton.TextWrapped = true
    v2ModeButton.Size = UDim2.new(1, 0, 0, 26)
    local v2ModeCorner = Instance.new("UICorner"); v2ModeCorner.CornerRadius = UDim.new(0, 8); v2ModeCorner.Parent = v2ModeButton
    S.ui.v2ModeButton = v2ModeButton

    local function updateV2ModeButton()
        v2ModeButton.Text = "Mode AutoFarm V2: " .. S.autoFarmV2Mode .. " Trackpad"
    end
    updateV2ModeButton()

    addConn(v2ModeButton.MouseButton1Click:Connect(function()
        S.autoFarmV2Mode = (S.autoFarmV2Mode == "Center") and "Left" or "Center"
        updateV2ModeButton()
        updateStatusLabel()
    end))

    local tapSpeedFrame = Instance.new("Frame")
    tapSpeedFrame.Parent = controlsScroll
    tapSpeedFrame.BackgroundTransparency = 1
    tapSpeedFrame.BorderSizePixel = 0
    tapSpeedFrame.Size = UDim2.new(1, 0, 0, 28)

    local tapSpeedLabel = Instance.new("TextLabel")
    tapSpeedLabel.Parent = tapSpeedFrame
    tapSpeedLabel.BackgroundTransparency = 1
    tapSpeedLabel.Font = Enum.Font.Gotham
    tapSpeedLabel.TextSize = 11
    tapSpeedLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
    tapSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    tapSpeedLabel.Text = "AutoFarm V2 Tap Interval (detik):"
    tapSpeedLabel.Size = UDim2.new(0.6, 0, 1, 0)

    local tapSpeedBox = Instance.new("TextBox")
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
    tapSpeedBox.Text = string.format("%.2f", S.autoFarmV2TapInterval)
    local tapSpeedCorner = Instance.new("UICorner"); tapSpeedCorner.CornerRadius = UDim.new(0, 6); tapSpeedCorner.Parent = tapSpeedBox
    S.ui.tapSpeedBox = tapSpeedBox

    local function applyTapSpeedFromBox()
        local raw = (tapSpeedBox.Text or ""):gsub(",", ".")
        local num = tonumber(raw)
        if not num then
            tapSpeedBox.Text = string.format("%.2f", S.autoFarmV2TapInterval)
            return
        end
        if num < S.TAP_INTERVAL_MIN then num = S.TAP_INTERVAL_MIN end
        if num > S.TAP_INTERVAL_MAX then num = S.TAP_INTERVAL_MAX end
        S.autoFarmV2TapInterval = num
        tapSpeedBox.Text = string.format("%.2f", S.autoFarmV2TapInterval)
        updateStatusLabel()
    end
    addConn(tapSpeedBox.FocusLost:Connect(applyTapSpeedFromBox))

    createToggle(controlsScroll, "Auto Skill 1",
        function() return S.autoSkill1 end,
        function(v) S.autoSkill1 = v end,
        function() updateStatusLabel() end
    )
    createToggle(controlsScroll, "Auto Skill 2",
        function() return S.autoSkill2 end,
        function(v) S.autoSkill2 = v end,
        function() updateStatusLabel() end
    )
    createToggle(controlsScroll, "Auto Skill 3",
        function() return S.autoSkill3 end,
        function(v) S.autoSkill3 = v end,
        function() updateStatusLabel() end
    )
    createToggle(controlsScroll, "Auto Skill 4",
        function() return S.autoSkill4 end,
        function(v) S.autoSkill4 = v end,
        function() updateStatusLabel() end
    )
    createToggle(controlsScroll, "Auto Skill 5",
        function() return S.autoSkill5 end,
        function(v) S.autoSkill5 = v end,
        function() updateStatusLabel() end
    )

    local baseInfo1 = string.format("Skill 1 (Skill02) Cooldown server (perkiraan): %d detik (UI info).", S.SKILL1_COOLDOWN)
    local info1 = Instance.new("TextLabel")
    info1.Parent = controlsScroll
    info1.BackgroundTransparency = 1
    info1.Font = Enum.Font.Gotham
    info1.TextSize = 11
    info1.TextColor3 = Color3.fromRGB(185, 185, 185)
    info1.TextXAlignment = Enum.TextXAlignment.Left
    info1.TextWrapped = true
    info1.Size = UDim2.new(1, 0, 0, 18)
    info1.Text = baseInfo1
    S.ui.skillInfo1 = info1

    local baseInfo2 = string.format(
        "Skill 2 (Skill08) Cooldown server (perkiraan): %d detik (UI info). Jeda antar Skill1 -> Skill2: %d detik.",
        S.SKILL2_COOLDOWN, S.SKILL_SEQUENCE_GAP
    )
    local info2 = Instance.new("TextLabel")
    info2.Parent = controlsScroll
    info2.BackgroundTransparency = 1
    info2.Font = Enum.Font.Gotham
    info2.TextSize = 11
    info2.TextColor3 = Color3.fromRGB(185, 185, 185)
    info2.TextXAlignment = Enum.TextXAlignment.Left
    info2.TextWrapped = true
    info2.Size = UDim2.new(1, 0, 0, 30)
    info2.Text = baseInfo2
    S.ui.skillInfo2 = info2

    local sellButton = Instance.new("TextButton")
    sellButton.Parent = controlsScroll
    sellButton.BackgroundColor3 = Color3.fromRGB(70, 50, 50)
    sellButton.BorderSizePixel = 0
    sellButton.AutoButtonColor = true
    sellButton.Font = Enum.Font.GothamSemibold
    sellButton.TextSize = 12
    sellButton.TextColor3 = Color3.fromRGB(240, 240, 240)
    sellButton.Text = "Sell All Fish (Spear)"
    sellButton.Size = UDim2.new(1, 0, 0, 30)
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 8); sc.Parent = sellButton
    addConn(sellButton.MouseButton1Click:Connect(sellAllFish))

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = controlsScroll
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextWrapped = true
    statusLabel.Size = UDim2.new(1, 0, 0, 70)
    statusLabel.Text = ""
    S.ui.statusLabel = statusLabel

    updateStatusLabel()

    -- ========== SPAWN CONTROLS ==========
    local spawnCard = createCard(
        S.ui.bodyScroll,
        "Spawn Controls",
        "Pengaturan Notifier Spawn (Boss, HP Boss, Illahi, Secret) global + per ikan.",
        2,
        420
    )

    local spawnScroll = Instance.new("ScrollingFrame")
    spawnScroll.Parent = spawnCard
    spawnScroll.BackgroundTransparency = 1
    spawnScroll.BorderSizePixel = 0
    spawnScroll.Position = UDim2.new(0, 0, 0, 40)
    spawnScroll.Size = UDim2.new(1, 0, 1, -40)
    spawnScroll.ScrollBarThickness = 4
    spawnScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local spawnLayout = Instance.new("UIListLayout")
    spawnLayout.Parent = spawnScroll
    spawnLayout.FillDirection = Enum.FillDirection.Vertical
    spawnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    spawnLayout.Padding = UDim.new(0, 6)

    addConn(spawnLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        spawnScroll.CanvasSize = UDim2.new(0, 0, 0, spawnLayout.AbsoluteContentSize.Y + 8)
    end))

    createToggle(spawnScroll, "Spawn Boss Notifier",
        function() return S.spawnBossNotifier end,
        function(v) S.spawnBossNotifier = v end,
        function(v)
            updateStatusLabel()
            notify("Spear Fishing", "Spawn Boss Notifier: " .. (v and "ON" or "OFF"), 2)
        end
    )

    createToggle(spawnScroll, "HPBar Boss Notifier",
        function() return S.hpBossNotifier end,
        function(v) S.hpBossNotifier = v end,
        function(v)
            updateStatusLabel()
            notify("Spear Fishing", "HPBar Boss Notifier: " .. (v and "ON" or "OFF"), 2)
        end
    )

    createToggle(spawnScroll, "Spawn Illahi Notifier",
        function() return S.spawnIllahiNotifier end,
        function(v) S.spawnIllahiNotifier = v end,
        function(v)
            updateStatusLabel()
            notify("Spear Fishing", "Spawn Illahi Notifier: " .. (v and "ON" or "OFF"), 2)
        end
    )

    createToggle(spawnScroll, "Spawn Secret Notifier",
        function() return S.spawnSecretNotifier end,
        function(v) S.spawnSecretNotifier = v end,
        function(v)
            updateStatusLabel()
            notify("Spear Fishing", "Spawn Secret Notifier: " .. (v and "ON" or "OFF"), 2)
        end
    )

    local illahiLabel = Instance.new("TextLabel")
    illahiLabel.Parent = spawnScroll
    illahiLabel.BackgroundTransparency = 1
    illahiLabel.Font = Enum.Font.GothamSemibold
    illahiLabel.TextSize = 12
    illahiLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    illahiLabel.TextXAlignment = Enum.TextXAlignment.Left
    illahiLabel.Size = UDim2.new(1, 0, 0, 18)
    illahiLabel.Text = "Illahi Notifier per Ikan (Nether Island):"

    for _, fishId in ipairs(S.ILLAHI_ORDER) do
        local def = S.ILLAHI_FISH_DEFS[fishId]
        local labelText = "Notifier Illahi " .. (def and def.name or fishId)

        if S.illahiFishEnabled[fishId] == nil then S.illahiFishEnabled[fishId] = true end

        createToggle(spawnScroll, labelText,
            function() return S.illahiFishEnabled[fishId] ~= false end,
            function(v) S.illahiFishEnabled[fishId] = v end
        )
    end

    local secretLabel = Instance.new("TextLabel")
    secretLabel.Parent = spawnScroll
    secretLabel.BackgroundTransparency = 1
    secretLabel.Font = Enum.Font.GothamSemibold
    secretLabel.TextSize = 12
    secretLabel.TextColor3 = Color3.fromRGB(255, 220, 180)
    secretLabel.TextXAlignment = Enum.TextXAlignment.Left
    secretLabel.Size = UDim2.new(1, 0, 0, 18)
    secretLabel.Text = "Secret Notifier per Ikan (Nether Island):"

    for _, fishId in ipairs(S.SECRET_ORDER) do
        local def = S.SECRET_FISH_DEFS[fishId]
        local labelText = "Notifier Secret " .. (def and def.name or fishId)

        if S.secretFishEnabled[fishId] == nil then S.secretFishEnabled[fishId] = false end

        createToggle(spawnScroll, labelText,
            function() return S.secretFishEnabled[fishId] == true end,
            function(v) S.secretFishEnabled[fishId] = v end
        )
    end

    -- ========== ESP FISH CONTROLS ==========
    local espCard = createCard(
        S.ui.bodyScroll,
        "ESP Fish Controls",
        "ESP antena kuning dari karakter ke Boss/Illahi/Secret + nama dan jarak (stud).",
        3,
        420
    )

    local espScroll = Instance.new("ScrollingFrame")
    espScroll.Parent = espCard
    espScroll.BackgroundTransparency = 1
    espScroll.BorderSizePixel = 0
    espScroll.Position = UDim2.new(0, 0, 0, 40)
    espScroll.Size = UDim2.new(1, 0, 1, -40)
    espScroll.ScrollBarThickness = 4
    espScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local espLayout = Instance.new("UIListLayout")
    espLayout.Parent = espScroll
    espLayout.FillDirection = Enum.FillDirection.Vertical
    espLayout.SortOrder = Enum.SortOrder.LayoutOrder
    espLayout.Padding = UDim.new(0, 6)

    addConn(espLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        espScroll.CanvasSize = UDim2.new(0, 0, 0, espLayout.AbsoluteContentSize.Y + 8)
    end))

    createToggle(espScroll, "ESP Boss",
        function() return S.espBoss end,
        function(v) S.espBoss = v end,
        function(v)
            refreshAllEsp()
            updateStatusLabel()
            notify("Spear Fishing", "ESP Boss: " .. (v and "ON" or "OFF"), 2)
        end
    )

    createToggle(espScroll, "ESP Illahi",
        function() return S.espIllahi end,
        function(v) S.espIllahi = v end,
        function(v)
            refreshAllEsp()
            updateStatusLabel()
            notify("Spear Fishing", "ESP Illahi: " .. (v and "ON" or "OFF"), 2)
        end
    )

    createToggle(espScroll, "ESP Secret",
        function() return S.espSecret end,
        function(v) S.espSecret = v end,
        function(v)
            refreshAllEsp()
            updateStatusLabel()
            notify("Spear Fishing", "ESP Secret: " .. (v and "ON" or "OFF"), 2)
        end
    )

    local espIllahiLabel = Instance.new("TextLabel")
    espIllahiLabel.Parent = espScroll
    espIllahiLabel.BackgroundTransparency = 1
    espIllahiLabel.Font = Enum.Font.GothamSemibold
    espIllahiLabel.TextSize = 12
    espIllahiLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    espIllahiLabel.TextXAlignment = Enum.TextXAlignment.Left
    espIllahiLabel.Size = UDim2.new(1, 0, 0, 18)
    espIllahiLabel.Text = "ESP Illahi per Ikan (Nether Island):"

    for _, fishId in ipairs(S.ILLAHI_ORDER) do
        local def = S.ILLAHI_FISH_DEFS[fishId]
        local labelText = "ESP Illahi " .. (def and def.name or fishId)
        if S.espIllahiFishEnabled[fishId] == nil then S.espIllahiFishEnabled[fishId] = false end

        createToggle(espScroll, labelText,
            function() return S.espIllahiFishEnabled[fishId] == true end,
            function(v) S.espIllahiFishEnabled[fishId] = v end,
            function()
                refreshAllEsp()
                updateStatusLabel()
            end
        )
    end

    local espSecretLabel = Instance.new("TextLabel")
    espSecretLabel.Parent = espScroll
    espSecretLabel.BackgroundTransparency = 1
    espSecretLabel.Font = Enum.Font.GothamSemibold
    espSecretLabel.TextSize = 12
    espSecretLabel.TextColor3 = Color3.fromRGB(255, 220, 180)
    espSecretLabel.TextXAlignment = Enum.TextXAlignment.Left
    espSecretLabel.Size = UDim2.new(1, 0, 0, 18)
    espSecretLabel.Text = "ESP Secret per Ikan (Nether Island):"

    for _, fishId in ipairs(S.SECRET_ORDER) do
        local def = S.SECRET_FISH_DEFS[fishId]
        local labelText = "ESP Secret " .. (def and def.name or fishId)
        if S.espSecretFishEnabled[fishId] == nil then S.espSecretFishEnabled[fishId] = false end

        createToggle(espScroll, labelText,
            function() return S.espSecretFishEnabled[fishId] == true end,
            function(v) S.espSecretFishEnabled[fishId] = v end,
            function()
                refreshAllEsp()
                updateStatusLabel()
            end
        )
    end

    -- Shop card
    buildHarpoonShopCard(S.ui.bodyScroll)

    return updateStatusLabel, baseInfo1, baseInfo2
end

local updateStatusLabel, baseInfo1, baseInfo2 = buildUI()

------------------- SKILL COOLDOWN UI UPDATE -------------------
local function updateSkillCooldownUI()
    local now = os.clock()

    if S.ui.skillInfo1 then
        local text1 = baseInfo1
        if (S.skillLast.s1 or 0) > 0 then
            local remaining = S.SKILL1_COOLDOWN - (now - S.skillLast.s1)
            text1 = (remaining > 0)
                and string.format("%s | Sisa: %ds", baseInfo1, math.ceil(remaining))
                or (baseInfo1 .. " | Ready")
        end
        S.ui.skillInfo1.Text = text1
    end

    if S.ui.skillInfo2 then
        local text2 = baseInfo2
        if (S.skillLast.s2 or 0) > 0 then
            local remaining = S.SKILL2_COOLDOWN - (now - S.skillLast.s2)
            text2 = (remaining > 0)
                and string.format("%s | Sisa: %ds", baseInfo2, math.ceil(remaining))
                or (baseInfo2 .. " | Ready")
        end
        S.ui.skillInfo2.Text = text2
    end
end

------------------- HOTKEY G: TOGGLE AUTOFARM V2 -------------------
addConn(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.G then return end
    if UserInputService:GetFocusedTextBox() then return end

    S.autoFarmV2 = not S.autoFarmV2
    updateStatusLabel()
    notify("Spear Fishing", "AutoFarm V2: " .. (S.autoFarmV2 and "ON" or "OFF") .. " (Key G)", 2)
end))

------------------- INIT WATCHERS -------------------
initToolsDataWatcher()
initWorldBossNotifier()
initIllahiSpawnNotifier()
initSecretSpawnNotifier()

------------------- BACKPACK / CHARACTER EVENT -------------------
addConn(LocalPlayer.CharacterAdded:Connect(function(newChar)
    S.character = newChar
    task.delay(1, function()
        if S.alive then
            ensureHarpoonEquipped()
            refreshHarpoonOwnership()
            refreshAllEsp()
        end
    end)
end))

addConn(LocalPlayer.ChildAdded:Connect(function(child)
    if child:IsA("Backpack") then
        S.backpack = child
        task.delay(0.5, function()
            if S.alive then refreshHarpoonOwnership() end
        end)
    end
end))

if S.backpack then
    addConn(S.backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then refreshHarpoonOwnership() end
    end))
    addConn(S.backpack.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then refreshHarpoonOwnership() end
    end))
end

------------------- BACKGROUND LOOPS -------------------
task.spawn(function()
    while S.alive do
        if S.autoEquip then pcall(ensureHarpoonEquipped) end
        task.wait(0.3)
    end
end)

task.spawn(function()
    while S.alive do
        if S.autoFarm then pcall(doFireHarpoon) end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while S.alive do
        if S.autoFarmV2 then
            pcall(doAutoTapV2)
            local interval = S.autoFarmV2TapInterval
            if interval < S.TAP_INTERVAL_MIN then interval = S.TAP_INTERVAL_MIN end
            if interval > S.TAP_INTERVAL_MAX then interval = S.TAP_INTERVAL_MAX end
            task.wait(interval)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while S.alive do
        if S.autoSkill1 or S.autoSkill2 then
            if S.autoSkill1 and S.autoSkill2 then
                pcall(function() fireSkill("Skill02","s1") end)
                local t = 0
                while t < S.SKILL_SEQUENCE_GAP and S.alive and S.autoSkill1 and S.autoSkill2 do
                    task.wait(0.2); t += 0.2
                end
                if S.alive and S.autoSkill1 and S.autoSkill2 then
                    pcall(function() fireSkill("Skill08","s2") end)
                end
            else
                if S.autoSkill1 then pcall(function() fireSkill("Skill02","s1") end) end
                if S.autoSkill2 then pcall(function() fireSkill("Skill08","s2") end) end
            end
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while S.alive do
        if S.autoSkill3 or S.autoSkill4 or S.autoSkill5 then
            if S.autoSkill3 then pcall(function() fireSkill("Skill01","s3") end) end
            task.wait(0.2)
            if not S.alive then break end

            if S.autoSkill4 then pcall(function() fireSkill("Skill07","s4") end) end
            task.wait(0.2)
            if not S.alive then break end

            if S.autoSkill5 then pcall(function() fireSkill("Skill09","s5") end) end
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while S.alive do
        pcall(updateSkillCooldownUI)
        task.wait(0.2)
    end
end)

task.spawn(function()
    while S.alive do
        pcall(updateEspTextDistances)
        task.wait(0.25)
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    S.alive = false

    S.autoFarm  = false
    S.autoEquip = false
    S.autoFarmV2 = false

    S.autoSkill1 = false
    S.autoSkill2 = false
    S.autoSkill3 = false
    S.autoSkill4 = false
    S.autoSkill5 = false

    S.spawnBossNotifier   = false
    S.hpBossNotifier      = false
    S.spawnIllahiNotifier = false
    S.spawnSecretNotifier = false

    S.espBoss   = false
    S.espIllahi = false
    S.espSecret = false

    S.bossRegionState = {}
    S.hpRegionState   = {}
    S.trackedFishEspTargets = {}

    for part in pairs(S.fishEspMap) do
        destroyFishEsp(part)
    end
    S.fishEspMap = {}
    S.hrpAttachment = nil

    for _, conn in ipairs(S.connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    S.connections = {}

    if frame then
        pcall(function() frame:ClearAllChildren() end)
    end
end
