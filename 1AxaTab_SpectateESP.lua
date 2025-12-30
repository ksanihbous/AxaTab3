--==========================================================
--  1AxaTab_SpectateESP.lua (WindUI Edition)
--  Spectate + ESP + TP FORCE + SPECT PRO + SPECT DRONE + ESP ANTENA
--  Env baru (AxaHub Panel WindUI):
--    TAB / AXA_TAB  : objek WindUI:Tab
--    AXA_UI         : WindUI root
--    AXA_WINDOW     : Axa Window
--    Players, LocalPlayer, RunService, Workspace, StarterGui, etc
--==========================================================

--================= ENV & SERVICES =================
local Tab        = TAB or AXA_TAB       -- WindUI Tab object
local Window     = AXA_WINDOW           -- AxaHub Window (WindUI)
local UI         = AXA_UI               -- WindUI root (punya :Notify, dst)

local Players    = Players     or game:GetService("Players")
local RunService = RunService  or game:GetService("RunService")
local Workspace  = Workspace   or workspace
local StarterGui = StarterGui  or game:GetService("StarterGui")
local LocalPlayer= LocalPlayer or Players.LocalPlayer

local Camera     = Camera or Workspace.CurrentCamera

--================= STATE GLOBAL =================
local conns              = {}
local activeESP          = {}   -- [Player] = true/false
local antennaLinks       = {}   -- [Player] = {beam, attachLocal, attachTarget, charConn}
local espAllOn           = false
local espAntennaOn       = false
local STUDS_TO_METERS    = 1

local currentSpectateTarget = nil
local spectateMode          = "none"  -- "none" / "custom" / "free" / "pro" / "drone"
local respawnConn           = nil
local proLastCF             = nil
local currentIndex          = 0
local currentTotal          = 0
local miniNav               = nil

-- FOV
local defaultFOV = (Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView) or 70
local DRONE_FOV  = 80

-- Raycast param drone anti tembok
local droneRayParams = RaycastParams.new()
droneRayParams.FilterType   = Enum.RaycastFilterType.Blacklist
droneRayParams.IgnoreWater  = true

-- Folder antena di Workspace
local antennaFolder = Instance.new("Folder")
antennaFolder.Name = "AxaSpect_AntennaFolder"
antennaFolder.Parent = Workspace

--================= SMALL HELPERS =================
local function connect(sig, fn)
    if not sig then return nil end
    local c = sig:Connect(fn)
    conns[#conns+1] = c
    return c
end

local function notifySys(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "AxaHub",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

local function uiNotify(opts)
    opts = opts or {}
    if UI and type(UI)=="table" and UI.Notify then
        pcall(function() UI:Notify({
            Title    = opts.Title or "AxaHub",
            Content  = opts.Content or opts.Desc or "",
            Duration = opts.Duration or 4,
            Icon     = opts.Icon or "info"
        }) end)
    else
        notifySys(opts.Title, opts.Content or opts.Desc, opts.Duration)
    end
end

local function safeSetAudioListener(mode)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if mode == "Camera" or mode == "Character" then
        pcall(function()
            cam.AudioListener = Enum.CameraAudioListener[mode]
        end)
    end
end

local function setDefaultFOV()
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = defaultFOV end
end

local function setDroneFOV()
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = DRONE_FOV end
end

local function getPrettyName(plr)
    if not plr then return "None" end
    return string.format("%s (@%s)", plr.DisplayName or plr.Name, plr.Name)
end

--================= ANTENA MERAH =================
local function getTorsoForAntenna(char)
    if not char then return nil end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function clearAntennaLink(plr, link)
    if not link then return end

    pcall(function()
        if link.beam and link.beam.Parent then
            link.beam:Destroy()
        end
    end)

    pcall(function()
        if link.attachLocal and link.attachLocal.Parent then
            link.attachLocal:Destroy()
        end
    end)

    pcall(function()
        if link.attachTarget and link.attachTarget.Parent then
            link.attachTarget:Destroy()
        end
    end)

    if link.charConn then
        pcall(function() link.charConn:Disconnect() end)
    end
end

local function setAntennaForPlayer(plr, enabled)
    local old = antennaLinks[plr]
    if not enabled then
        if old then clearAntennaLink(plr, old) end
        antennaLinks[plr] = nil
        return
    end

    local localChar  = LocalPlayer.Character
    local torsoLocal = getTorsoForAntenna(localChar)
    if not torsoLocal then return end

    if old then clearAntennaLink(plr, old) end

    local attachLocal = Instance.new("Attachment")
    attachLocal.Name = "AxaSpect_Local_" .. plr.Name
    attachLocal.Position = Vector3.new(0, 0.5, 0)
    attachLocal.Parent = torsoLocal

    local beam = Instance.new("Beam")
    beam.Name = "AxaSpect_Beam_" .. plr.Name
    beam.Attachment0 = attachLocal
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 60, 60))
    beam.Width0 = 0.10
    beam.Width1 = 0.10
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.FaceCamera = true
    beam.Transparency = NumberSequence.new(0.05)
    beam.Segments = 10
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.Parent = antennaFolder

    local link = {
        beam        = beam,
        attachLocal = attachLocal,
        attachTarget= nil,
        charConn    = nil,
    }
    antennaLinks[plr] = link

    local function bindTargetChar(char)
        local torsoTarget = getTorsoForAntenna(char)
        if not torsoTarget then return end

        pcall(function()
            if link.attachTarget and link.attachTarget.Parent then
                link.attachTarget:Destroy()
            end
        end)

        local attachTarget = Instance.new("Attachment")
        attachTarget.Name = "AxaSpect_Target_" .. plr.Name
        attachTarget.Position = Vector3.new(0, 0.5, 0)
        attachTarget.Parent = torsoTarget
        link.attachTarget = attachTarget
        beam.Attachment1 = attachTarget
    end

    if plr.Character then
        bindTargetChar(plr.Character)
    end

    link.charConn = connect(plr.CharacterAdded, function(newChar)
        bindTargetChar(newChar)
    end)
end

-- Rebind attachment LocalPlayer saat respawn
connect(LocalPlayer.CharacterAdded, function(newChar)
    local torsoLocal = getTorsoForAntenna(newChar)
    if not torsoLocal then return end

    for plr, link in pairs(antennaLinks) do
        pcall(function()
            if link.attachLocal and link.attachLocal.Parent then
                link.attachLocal:Destroy()
            end
        end)

        local newAttach = Instance.new("Attachment")
        newAttach.Name = "AxaSpect_Local_" .. plr.Name
        newAttach.Position = Vector3.new(0, 0.5, 0)
        newAttach.Parent = torsoLocal
        link.attachLocal = newAttach

        if link.beam then
            link.beam.Attachment0 = newAttach
        end
    end
end)

--================= MINI NAV SPECTATE =================
local function destroyMiniNav()
    if miniNav and miniNav.Parent then miniNav:Destroy() end
    miniNav = nil
end

local function updateMiniNavInfo()
    if not miniNav then return end
    local label = miniNav:FindFirstChild("Info")
    if not label or not label:IsA("TextLabel") then return end

    if currentSpectateTarget and currentTotal > 0 and currentIndex > 0 then
        local dn = currentSpectateTarget.DisplayName or currentSpectateTarget.Name
        local un = currentSpectateTarget.Name
        label.Text = string.format("%s (@%s)\n%d/%d", dn, un, currentIndex, currentTotal)
    else
        label.Text = "Target: None\n0/0"
    end
end

local function ensureMiniNav()
    local core = rawget(_G,"AxaHubCore")
    if not core then return end
    local root = core.WindowGui or core.Window and core.Window.Base
    if not root then return end

    -- kalau sudah ada
    local existed = root:FindFirstChild("AxaMiniSpectNav")
    if existed then
        miniNav = existed
        updateMiniNavInfo()
        return
    end

    -- buat baru
    local frame = Instance.new("Frame")
    frame.Name = "AxaMiniSpectNav"
    frame.AnchorPoint = Vector2.new(1,1)
    frame.Position = UDim2.new(1,-12,1,-12)
    frame.Size = UDim2.new(0,220,0,52)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,24)
    frame.BorderSizePixel  = 0
    frame.Parent = root

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness     = 1
    stroke.Color         = Color3.fromRGB(70,70,90)
    stroke.Transparency  = 0.35
    stroke.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0,6)
    pad.PaddingBottom = UDim.new(0,6)
    pad.PaddingLeft   = UDim.new(0,8)
    pad.PaddingRight  = UDim.new(0,8)
    pad.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1,-60,1,0)
    infoLabel.Position = UDim2.new(0,0,0,0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.TextColor3 = Color3.fromRGB(230,230,245)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.TextWrapped = true
    infoLabel.Text = "Target: None\n0/0"
    infoLabel.Parent = frame

    local function makeMiniBtn(name, txt, pos)
        local b = Instance.new("TextButton")
        b.Name = name
        b.Size = UDim2.new(0,24,0,24)
        b.Position = pos
        b.BackgroundColor3 = Color3.fromRGB(230,230,240)
        b.BorderSizePixel = 0
        b.AutoButtonColor = true
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Color3.fromRGB(40,40,70)
        b.Text = txt
        b.Parent = frame

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1,0)
        c.Parent = b

        return b
    end

    local prevBtn = makeMiniBtn("Prev","<", UDim2.new(1,-52,0.5,-12))
    local nextBtn = makeMiniBtn("Next",">", UDim2.new(1,-24,0.5,-12))

    connect(prevBtn.MouseButton1Click, function()
        if _G.__AxaSpect_Step then _G.__AxaSpect_Step(-1, true) end
    end)
    connect(nextBtn.MouseButton1Click, function()
        if _G.__AxaSpect_Step then _G.__AxaSpect_Step(1, true) end
    end)

    -- kalau window ditutup (destroy), mini nav ikut hilang otomatis
    miniNav = frame
    updateMiniNavInfo()
end

--================= CAMERA & SPECTATE =================
local function disconnectRespawn()
    if respawnConn then respawnConn:Disconnect() end
    respawnConn = nil
end

local function hardResetCameraToLocal()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    cam.CameraType   = Enum.CameraType.Custom
    cam.CameraSubject= hum or nil
    safeSetAudioListener("Camera")
    setDefaultFOV()
end

local function stopSpectate()
    disconnectRespawn()
    currentSpectateTarget = nil
    spectateMode          = "none"
    currentIndex, currentTotal = 0,0
    proLastCF             = nil
    setDefaultFOV()
    hardResetCameraToLocal()
    destroyMiniNav()
    uiNotify({
        Title   = "Spectate",
        Content = "Spectate berhenti.",
        Duration= 3,
        Icon    = "stop-circle"
    })
end

-- expose ke global core (dipakai tombol dock, dll)
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.StopSpectate   = stopSpectate
_G.AxaHub_StopSpectate   = stopSpectate
_G.AxaSpectate_Stop      = stopSpectate
_G.Axa_StopSpectate      = stopSpectate

-- robust posisi karakter
local function getCharPosition(char)
    if not char or not char:IsA("Model") then return nil, nil end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position, hrp.CFrame
    end

    local primary = char.PrimaryPart
    if primary and primary:IsA("BasePart") then
        return primary.Position, primary.CFrame
    end

    local ok, cf = pcall(function()
        return char:GetPivot()
    end)
    if ok and typeof(cf)=="CFrame" then
        return cf.Position, cf
    end

    return nil, nil
end

--================= LIST PLAYER UNTUK SPECTATE =================
local function getSpectateList()
    local arr = {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(arr, plr)
        end
    end
    table.sort(arr, function(a,b)
        return string.lower(a.Name) < string.lower(b.Name)
    end)
    return arr
end

local function locateIndexInList(plr)
    local lp = getSpectateList()
    local n  = #lp
    currentTotal = n
    currentIndex = 0
    if n == 0 or not plr then
        updateMiniNavInfo()
        return
    end
    for i,p in ipairs(lp) do
        if p == plr then
            currentIndex = i
            break
        end
    end
    updateMiniNavInfo()
end

local function selectStep(dir)
    local lp = getSpectateList()
    local n  = #lp
    if n == 0 then
        currentSpectateTarget = nil
        currentIndex, currentTotal = 0,0
        updateMiniNavInfo()
        uiNotify({
            Title   = "Spectate",
            Content = "Tidak ada player lain.",
            Duration= 3,
            Icon    = "alert-triangle"
        })
        return
    end

    dir = dir or 1
    local idx

    if currentSpectateTarget then
        for i,p in ipairs(lp) do
            if p == currentSpectateTarget then
                idx = i
                break
            end
        end
    end

    if not idx then
        idx = (dir >= 0) and 1 or n
    else
        idx = idx + dir
        if idx < 1 then idx = n end
        if idx > n then idx = 1 end
    end

    local target = lp[idx]
    currentSpectateTarget = target
    currentIndex  = idx
    currentTotal  = n
    updateMiniNavInfo()

    uiNotify({
        Title   = "Target Selected",
        Content = getPrettyName(target),
        Duration= 3,
        Icon    = "user"
    })
end

-- versi yang memulai spectate free langsung (dipakai mini nav)
local function spectateStep(dir, fromMiniNav)
    selectStep(dir)
    if fromMiniNav and currentSpectateTarget then
        -- mini nav: auto SPECT FREE
        spectateMode = "none"
        _G.__AxaSpect_LastMode = "free"
        -- jalankan free
        local t = currentSpectateTarget
        if t then
            -- calling after tiny delay untuk jaga camera ready
            task.defer(function()
                if t == currentSpectateTarget then
                    -- re-check
                    if t then
                        _G.__AxaSpect_StartFree(t)
                    end
                end
            end)
        end
    end
end

_G.__AxaSpect_Step = spectateStep

--================= SPECT MODES =================
local function startCustomSpectate(plr)
    if not plr then
        uiNotify({Title="Spectate",Content="Pilih target dulu.",Duration=3,Icon="alert-triangle"})
        return
    end
    disconnectRespawn()
    setDefaultFOV()
    currentSpectateTarget = plr
    spectateMode          = "custom"
    proLastCF             = nil
    locateIndexInList(plr)
    ensureMiniNav()

    uiNotify({
        Title   = "Spectate",
        Content = "SPECT POV → " .. getPrettyName(plr),
        Duration= 3,
        Icon    = "video"
    })
end

local function startFreeSpectate(plr)
    if not plr then
        uiNotify({Title="Spectate",Content="Pilih target dulu.",Duration=3,Icon="alert-triangle"})
        return
    end
    disconnectRespawn()
    setDefaultFOV()
    currentSpectateTarget = plr
    spectateMode          = "free"
    proLastCF             = nil

    local cam = Workspace.CurrentCamera
    local char = plr.Character
    if cam and char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            cam.CameraSubject = hum
            cam.CameraType    = Enum.CameraType.Custom
            safeSetAudioListener("Character")
        end
    end

    respawnConn = connect(plr.CharacterAdded, function(char)
        local hum2 = char:WaitForChild("Humanoid")
        local cam2 = Workspace.CurrentCamera
        if cam2 and hum2 then
            cam2.CameraSubject = hum2
            cam2.CameraType    = Enum.CameraType.Custom
            safeSetAudioListener("Character")
        end
    end)

    locateIndexInList(plr)
    ensureMiniNav()

    uiNotify({
        Title   = "Spectate",
        Content = "SPECT FREE → " .. getPrettyName(plr),
        Duration= 3,
        Icon    = "camera"
    })
end

local function startProSpectate(plr)
    if not plr then
        uiNotify({Title="Spectate",Content="Pilih target dulu.",Duration=3,Icon="alert-triangle"})
        return
    end
    disconnectRespawn()
    setDefaultFOV()
    currentSpectateTarget = plr
    spectateMode          = "pro"
    proLastCF             = nil
    locateIndexInList(plr)
    ensureMiniNav()

    uiNotify({
        Title   = "Spectate",
        Content = "SPECT PRO → " .. getPrettyName(plr),
        Duration= 3,
        Icon    = "focus"
    })
end

local function startDroneSpectate(plr)
    if not plr then
        uiNotify({Title="Spectate",Content="Pilih target dulu.",Duration=3,Icon="alert-triangle"})
        return
    end
    disconnectRespawn()
    currentSpectateTarget = plr
    spectateMode          = "drone"
    proLastCF             = nil
    setDroneFOV()
    locateIndexInList(plr)
    ensureMiniNav()

    uiNotify({
        Title   = "Spectate",
        Content = "SPECT DRONE → " .. getPrettyName(plr),
        Duration= 3,
        Icon    = "drone"
    })
end

_G.__AxaSpect_StartFree = startFreeSpectate

--================= ESP =================
local function setESPOnTarget(plr, enabled)
    if not plr then return end
    activeESP[plr] = enabled or nil

    -- antena per-player kalau global OFF
    if not espAntennaOn then
        setAntennaForPlayer(plr, enabled and true or false)
    end

    local char = plr.Character
    if not char then return end

    local hl   = char:FindFirstChild("AxaESPHighlight")
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char
    local bb   = head and head:FindFirstChild("AxaESPDistGui") or nil

    if enabled then
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "AxaESPHighlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillColor = Color3.fromRGB(90,180,255)
            hl.FillTransparency = 0.7
            hl.OutlineColor = Color3.fromRGB(40,130,255)
            hl.OutlineTransparency = 0.1
            hl.Parent = char
        end
        if head and not bb then
            bb = Instance.new("BillboardGui")
            bb.Name = "AxaESPDistGui"
            bb.Size = UDim2.new(0,260,0,26)
            bb.StudsOffset = Vector3.new(0,3,0)
            bb.AlwaysOnTop = true
            bb.MaxDistance = 2000
            bb.Parent = head

            local t = Instance.new("TextLabel")
            t.Name = "Text"
            t.Size = UDim2.new(1,0,1,0)
            t.BackgroundColor3 = Color3.fromRGB(0,0,0)
            t.BackgroundTransparency = 0.35
            t.BorderSizePixel = 0
            t.Font = Enum.Font.GothamBold
            t.TextSize = 13
            t.TextColor3 = Color3.fromRGB(255,255,255)
            t.TextStrokeTransparency = 0.4
            t.TextStrokeColor3 = Color3.fromRGB(0,0,0)
            t.TextWrapped = true
            t.TextXAlignment = Enum.TextXAlignment.Center
            t.TextYAlignment = Enum.TextYAlignment.Center
            t.ZIndex = 2
            t.Parent = bb

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0,6)
            c.Parent = t
        end
    else
        if hl then hl:Destroy() end
        if head and bb then bb:Destroy() end
    end
end

--================= TELEPORT =================
local function teleportToPlayer(target)
    if not target then
        uiNotify({Title="Teleport",Content="Pilih target dulu.",Duration=3,Icon="alert-triangle"})
        return
    end

    local targetChar = target.Character
    if not targetChar then return end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local thrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

    if hrp and thrp then
        hrp.AssemblyLinearVelocity  = Vector3.new(0,0,0)
        hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
        hrp.CFrame = thrp.CFrame
    end
end

local function teleportToPlayerForce(target)
    if not target then
        uiNotify({Title="Teleport Force",Content="Pilih target dulu.",Duration=3,Icon="alert-triangle"})
        return
    end

    local targetChar = target.Character
    if not targetChar then return end

    local targetPos = getCharPosition(targetChar)
    if not targetPos then return end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.AssemblyLinearVelocity  = Vector3.new(0,0,0)
    hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
    hrp.CFrame = CFrame.new(targetPos)
end

--================= CAMERA / ESP UPDATE LOOP =================
connect(RunService.RenderStepped, function()
    -- Camera follow
    if currentSpectateTarget and spectateMode ~= "none" then
        local cam = Workspace.CurrentCamera
        local char = currentSpectateTarget.Character
        if not cam then return end

        if spectateMode == "custom" and char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                cam.CameraType = Enum.CameraType.Scriptable
                local offset = hrp.CFrame.LookVector * -8 + Vector3.new(0,4,0)
                cam.CFrame = CFrame.new(hrp.Position + offset, hrp.Position)
                safeSetAudioListener("Camera")
            end

        elseif spectateMode == "free" and char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                cam.CameraType   = Enum.CameraType.Custom
                cam.CameraSubject= hum
                safeSetAudioListener("Character")
            end

        elseif spectateMode == "pro" then
            cam.CameraType = Enum.CameraType.Scriptable
            local pos, cf = nil, nil
            if char then
                local p, fullCF = getCharPosition(char)
                if p and fullCF then
                    pos, cf = p, fullCF
                    proLastCF = fullCF
                end
            end
            if not cf and proLastCF then
                cf  = proLastCF
                pos = proLastCF.Position
            end
            if cf and pos then
                local offset   = cf.LookVector * -10 + Vector3.new(0,5,0)
                local targetCF = CFrame.new(pos + offset, pos)
                if cam.CFrame then
                    cam.CFrame = cam.CFrame:Lerp(targetCF, 0.25)
                else
                    cam.CFrame = targetCF
                end
                safeSetAudioListener("Camera")
            end

        elseif spectateMode == "drone" then
            cam.CameraType = Enum.CameraType.Scriptable
            local pos, cf = nil, nil
            if char then
                local p, fullCF = getCharPosition(char)
                if p and fullCF then
                    pos, cf = p, fullCF
                    proLastCF = fullCF
                end
            end
            if not cf and proLastCF then
                cf  = proLastCF
                pos = proLastCF.Position
            end
            if cf and pos then
                local from    = pos + Vector3.new(0,3,0)
                local lookDir = (-cf.LookVector).Unit
                local baseOffset = lookDir * 28 + Vector3.new(0,40,0)
                local desiredPos = pos + baseOffset
                local dir = desiredPos - from
                local finalPos = desiredPos

                if dir.Magnitude > 1e-3 then
                    droneRayParams.FilterDescendantsInstances = {
                        char,
                        LocalPlayer.Character
                    }
                    local result = Workspace:Raycast(from, dir, droneRayParams)
                    if result then
                        finalPos = result.Position - dir.Unit * 2
                    end
                end

                local targetCF = CFrame.new(finalPos, pos)
                if cam.CFrame then
                    cam.CFrame = cam.CFrame:Lerp(targetCF, 0.25)
                else
                    cam.CFrame = targetCF
                end
                cam.FieldOfView = DRONE_FOV
                safeSetAudioListener("Camera")
            end
        end
    end

    -- Update teks jarak ESP
    local myChar = LocalPlayer.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    for plr in pairs(activeESP) do
        local char = plr.Character
        if char then
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head") or hrp
            if hrp and head then
                local gui = head:FindFirstChild("AxaESPDistGui")
                if gui then
                    local label = gui:FindFirstChild("Text")
                    if label and label:IsA("TextLabel") then
                        local distStuds = (hrp.Position - myHRP.Position).Magnitude
                        local meters = math.floor(distStuds * STUDS_TO_METERS + 0.5)
                        label.Text = string.format("%s | @%s | %d meter",
                            plr.DisplayName or plr.Name, plr.Name, meters)
                    end
                end
            end
        end
    end
end)

--================= PLAYER ADDED / REMOVED =================
connect(Players.PlayerAdded, function(plr)
    if espAllOn and plr ~= LocalPlayer then
        setESPOnTarget(plr, true)
    end
    if espAntennaOn and plr ~= LocalPlayer then
        setAntennaForPlayer(plr, true)
    end
end)

connect(Players.PlayerRemoving, function(plr)
    if activeESP[plr] then
        setESPOnTarget(plr, false)
        activeESP[plr] = nil
    end

    local link = antennaLinks[plr]
    if link then
        clearAntennaLink(plr, link)
        antennaLinks[plr] = nil
    end

    if plr == currentSpectateTarget then
        stopSpectate()
    end
end)

--================= WINDUI: BUILD TAB UI =================
Tab:Section({
    Title  = "Spectate + ESP",
    Opened = true
})

Tab:Paragraph({
    Title  = "Deskripsi",
    Desc   = "• Pilih target player, lalu jalankan mode Spectate (POV / FREE / PRO / DRONE)." ..
             "\n• ESP bisa per-target atau semua player." ..
             "\n• ESP Antena = beam merah dari karakter kamu ke semua player.",
    Color  = "Blue",
    Image  = "info",
    ImageSize = 22
})

-- PILIH / GANTI TARGET
Tab:Section({
    Title  = "Target Player",
    Opened = true
})

Tab:Button({
    Title    = "Pilih Target Berikutnya",
    Desc     = "Urut alfabet (skip diri sendiri).",
    Icon     = "chevron-right",
    Locked   = false,
    Callback = function()
        selectStep(1)
    end
})

Tab:Button({
    Title    = "Pilih Target Sebelumnya",
    Desc     = "Urut alfabet mundur.",
    Icon     = "chevron-left",
    Locked   = false,
    Callback = function()
        selectStep(-1)
    end
})

Tab:Button({
    Title    = "Info Target Saat Ini",
    Desc     = "Tampilkan info target yang sedang dipilih.",
    Icon     = "user",
    Locked   = false,
    Callback = function()
        if not currentSpectateTarget then
            uiNotify({
                Title   = "Target",
                Content = "Belum ada target yang dipilih.",
                Duration= 3,
                Icon    = "alert-circle"
            })
            return
        end
        uiNotify({
            Title   = "Target Saat Ini",
            Content = getPrettyName(currentSpectateTarget),
            Duration= 4,
            Icon    = "user"
        })
    end
})

-- MODE SPECTATE
Tab:Section({
    Title  = "Mode Spectate",
    Opened = true
})

Tab:Button({
    Title    = "SPECT POV (Custom Cam)",
    Desc     = "Kamera di belakang kepala target (third person).",
    Icon     = "video",
    Locked   = false,
    Callback = function()
        startCustomSpectate(currentSpectateTarget)
    end
})

Tab:Button({
    Title    = "SPECT FREE (Follow Humanoid)",
    Desc     = "Kamera sama seperti kamu jadi player target.",
    Icon     = "camera",
    Locked   = false,
    Callback = function()
        startFreeSpectate(currentSpectateTarget)
    end
})

Tab:Button({
    Title    = "SPECT PRO (Cinematic Smooth)",
    Desc     = "Gerakan kamera smooth, angle sinematik.",
    Icon     = "focus",
    Locked   = false,
    Callback = function()
        startProSpectate(currentSpectateTarget)
    end
})

Tab:Button({
    Title    = "SPECT DRONE (Overhead + Anti Tembok)",
    Desc     = "Drone tinggi di belakang target, FOV lebih lebar.",
    Icon     = "drone",
    Locked   = false,
    Callback = function()
        startDroneSpectate(currentSpectateTarget)
    end
})

Tab:Button({
    Title    = "Stop Spectate",
    Desc     = "Reset kamera ke karakter kamu.",
    Icon     = "x-octagon",
    Locked   = false,
    Callback = function()
        stopSpectate()
    end
})

-- ESP SETTINGS
Tab:Section({
    Title  = "ESP Settings",
    Opened = true
})

Tab:Toggle({
    Title    = "ESP ALL",
    Desc     = "Nyalakan ESP untuk semua player (kecuali kamu).",
    Icon     = "scan-eye",
    Type     = "Checkbox",
    Value    = false,
    Callback = function(state)
        espAllOn = state and true or false
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                setESPOnTarget(plr, espAllOn)
            end
        end
        uiNotify({
            Title   = "ESP ALL",
            Content = espAllOn and "ESP ALL: ON" or "ESP ALL: OFF",
            Duration= 3,
            Icon    = "scan-eye"
        })
    end
})

Tab:Toggle({
    Title    = "ESP ANTENA Global",
    Desc     = "Tampilkan beam merah dari kamu ke semua player.",
    Icon     = "radar",
    Type     = "Checkbox",
    Value    = false,
    Callback = function(state)
        espAntennaOn = state and true or false

        if espAntennaOn then
            local char = LocalPlayer.Character
            local torso = char and getTorsoForAntenna(char)
            if not torso then
                espAntennaOn = false
                uiNotify({
                    Title   = "ESP ANTENA",
                    Content = "Gagal ON: badan karakter belum siap.",
                    Duration= 4,
                    Icon    = "alert-triangle"
                })
                return
            end
            for _,plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    setAntennaForPlayer(plr, true)
                end
            end
            uiNotify({
                Title   = "ESP ANTENA",
                Content = "ESP ANTENA: ON (semua player).",
                Duration= 3,
                Icon    = "radar"
            })
        else
            for plr, link in pairs(antennaLinks) do
                clearAntennaLink(plr, link)
            end
            table.clear(antennaLinks)
            uiNotify({
                Title   = "ESP ANTENA",
                Content = "ESP ANTENA: OFF",
                Duration= 3,
                Icon    = "radar"
            })
        end
    end
})

Tab:Button({
    Title    = "Toggle ESP Target (On/Off)",
    Desc     = "ESP hanya untuk target yang sedang dipilih.",
    Icon     = "user-check",
    Locked   = false,
    Callback = function()
        if not currentSpectateTarget then
            uiNotify({
                Title   = "ESP Target",
                Content = "Belum ada target yang dipilih.",
                Duration= 3,
                Icon    = "alert-triangle"
            })
            return
        end
        local cur = activeESP[currentSpectateTarget] and true or false
        setESPOnTarget(currentSpectateTarget, not cur)
        uiNotify({
            Title   = "ESP Target",
            Content = string.format("%s → %s",
                getPrettyName(currentSpectateTarget),
                (not cur) and "ESP ON" or "ESP OFF"),
            Duration= 3,
            Icon    = "user-check"
        })
    end
})

-- TELEPORT
Tab:Section({
    Title  = "Teleport",
    Opened = true
})

Tab:Button({
    Title    = "TP ke Target",
    Desc     = "Teleport HRP kamu ke HRP target (0 stud).",
    Icon     = "navigation",
    Locked   = false,
    Callback = function()
        teleportToPlayer(currentSpectateTarget)
    end
})

Tab:Button({
    Title    = "TP FORCE ke Target",
    Desc     = "Versi lebih paksa (pakai GetPivot / PrimaryPart).",
    Icon     = "navigation-2",
    Locked   = false,
    Callback = function()
        teleportToPlayerForce(currentSpectateTarget)
    end
})

--================= TAB CLEANUP =================
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}
_G.AxaHub.TabCleanup[TAB_ID or "spectateespp"] = function()
    -- Matikan spectate
    stopSpectate()

    -- Matikan semua ESP
    for plr in pairs(activeESP) do
        setESPOnTarget(plr, false)
    end
    table.clear(activeESP)

    -- Bersihkan antena
    for plr, link in pairs(antennaLinks) do
        clearAntennaLink(plr, link)
    end
    table.clear(antennaLinks)

    pcall(function()
        if antennaFolder and antennaFolder.Parent then
            antennaFolder:Destroy()
        end
    end)

    -- Disconnect semua koneksi
    for _,c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
end
