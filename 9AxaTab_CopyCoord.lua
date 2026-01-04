--==========================================================
--  9AxaTab_CopyCoord.lua (UPGRADE: Position + LookAt + Server Info)
--  Env dari CORE:
--    TAB_FRAME, TAB_ID
--    Players, LocalPlayer, RunService, UserInputService, StarterGui
--==========================================================
local frame        = TAB_FRAME
local tabId        = TAB_ID or "copycoord"
local player       = LocalPlayer
local runService   = RunService
local uis          = UserInputService
local starterGui   = StarterGui

local conns        = {}
local live         = true
local updateEvery  = 0.5
local lastUpdate   = 0

-- Payload yang bisa di-copy
local vecPayload       = "Vector3.new(0, 0, 0)"      -- posisi
local lookVecPayload   = "Vector3.new(0, 0, 0)"      -- lookAt
local vecAssignPayload = "position = Vector3.new(0, 0, 0), lookAt = Vector3.new(0, 0, 0)"
local cfPayload        = "CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0))"

-- Server/Game payload
local serverIdPayload  = tostring(game.JobId or "")
local gameIdPayload    = tostring(game.GameId or "")

----------------------------------------------------------------
-- SMALL HELPERS
----------------------------------------------------------------
local function connect(sig, fn)
    local c = sig:Connect(fn)
    conns[#conns+1] = c
    return c
end

local function notify(title, text, dur)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = dur or 3
        })
    end)
end

local function round(n, d)
    local m = 10 ^ (d or 2)
    return math.floor(n * m + 0.5) / m
end

local function getHRP()
    local char = player.Character
    if not char or not char.Parent then
        char = player.Character or player.CharacterAdded:Wait()
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        hrp = char:WaitForChild("HumanoidRootPart", 5)
    end
    return hrp
end

local function makeCorner(gui, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or 8)
    c.Parent = gui
    return c
end

local function makeLabel(parent, name, text, size, pos, props)
    local l = Instance.new("TextLabel")
    l.Name, l.Size, l.Position = name, size, pos or UDim2.new()
    l.BackgroundTransparency = 1
    l.Font       = props and props.Font       or Enum.Font.Gotham
    l.TextSize   = props and props.TextSize   or 12
    l.TextColor3 = props and props.TextColor3 or Color3.fromRGB(40,40,60)
    l.TextXAlignment = props and props.XAlign or Enum.TextXAlignment.Left
    l.TextYAlignment = props and props.YAlign or Enum.TextYAlignment.Center
    l.TextWrapped    = props and props.Wrapped or false
    l.Text = text or ""
    l.Parent = parent
    return l
end

local function makeButton(parent, name, text, size, pos, bg, tc, ts)
    local b = Instance.new("TextButton")
    b.Name, b.Size, b.Position = name, size, pos or UDim2.new()
    b.BackgroundColor3 = bg or Color3.fromRGB(230,230,245)
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = true
    b.Font      = Enum.Font.GothamBold
    b.Text      = text or ""
    b.TextSize  = ts or 13
    b.TextColor3= tc or Color3.fromRGB(40,40,60)
    b.Parent    = parent
    makeCorner(b, 8)
    return b
end

local function makeCard(parent, name, size, pos)
    local f = Instance.new("Frame")
    f.Name, f.Size, f.Position = name, size, pos or UDim2.new()
    f.BackgroundColor3 = Color3.fromRGB(235,235,248)
    f.BorderSizePixel  = 0
    f.Parent = parent
    makeCorner(f, 10)

    local s = Instance.new("UIStroke")
    s.Thickness    = 1
    s.Color        = Color3.fromRGB(210,210,230)
    s.Transparency = 0.3
    s.Parent       = f

    return f
end

----------------------------------------------------------------
-- HEADER DALAM TAB
----------------------------------------------------------------
makeLabel(
    frame,"Header","📍 Copy Coordinate V1",
    UDim2.new(1,-10,0,22),UDim2.new(0,5,0,6),
    {
        Font      = Enum.Font.GothamBold,
        TextSize  = 15,
        TextColor3= Color3.fromRGB(40,40,60),
        XAlign    = Enum.TextXAlignment.Left
    }
)

makeLabel(
    frame,"Sub",
    "Pantau posisi HumanoidRootPart & salin koordinat ke clipboard sebagai Vector3 atau CFrame. Sekarang juga tampil LookAt (arah hadap) dan CFrame.new(Pos, LookAt). Tekan tombol di bawah atau pakai hotkey [C] untuk copy cepat (position + lookAt).",
    UDim2.new(1,-10,0,40),UDim2.new(0,5,0,26),
    {
        Font      = Enum.Font.Gotham,
        TextSize  = 12,
        TextColor3= Color3.fromRGB(90,90,120),
        XAlign    = Enum.TextXAlignment.Left,
        YAlign    = Enum.TextYAlignment.Top,
        Wrapped   = true
    }
)

----------------------------------------------------------------
-- BODY (SCROLLING FRAME)
----------------------------------------------------------------
local body = Instance.new("ScrollingFrame")
body.Name = "BodyScroll"
body.Position = UDim2.new(0,0,0,72)
body.Size = UDim2.new(1,0,1,-72)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.CanvasSize = UDim2.new(0,0,0,0)
body.Parent = frame

local bodyPad = Instance.new("UIPadding")
bodyPad.PaddingLeft   = UDim.new(0,6)
bodyPad.PaddingRight  = UDim.new(0,6)
bodyPad.PaddingTop    = UDim.new(0,4)
bodyPad.PaddingBottom = UDim.new(0,6)
bodyPad.Parent = body

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.SortOrder     = Enum.SortOrder.LayoutOrder
list.Padding       = UDim.new(0,8)
list.Parent        = body

list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    body.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y+8)
end)

----------------------------------------------------------------
-- CARD KOORDINAT (POS + LOOKAT + CFRAME)
----------------------------------------------------------------
local card = makeCard(body,"CoordCard",UDim2.new(1,0,0,170),UDim2.new(0,0,0,0))

local title = makeLabel(
    card,"CardTitle","Posisi & Arah Hadap HumanoidRootPart",
    UDim2.new(1,-10,0,18),UDim2.new(0,6,0,6),
    {
        Font      = Enum.Font.GothamSemibold,
        TextSize  = 13,
        TextColor3= Color3.fromRGB(45,45,80)
    }
)

local coordLabel = makeLabel(
    card,"CoordLabel","X: -   Y: -   Z: -",
    UDim2.new(1,-12,0,22),UDim2.new(0,6,0,30),
    {
        Font      = Enum.Font.Code,
        TextSize  = 14,
        TextColor3= Color3.fromRGB(30,30,60)
    }
)

local vecLabel = makeLabel(
    card,"VecLabel","Pos: Vector3.new(0, 0, 0)",
    UDim2.new(1,-12,0,20),UDim2.new(0,6,0,56),
    {
        Font      = Enum.Font.Code,
        TextSize  = 12,
        TextColor3= Color3.fromRGB(70,70,110)
    }
)

local lookLabel = makeLabel(
    card,"LookLabel","LookAt: Vector3.new(0, 0, 10)",
    UDim2.new(1,-12,0,20),UDim2.new(0,6,0,78),
    {
        Font      = Enum.Font.Code,
        TextSize  = 12,
        TextColor3= Color3.fromRGB(70,70,110)
    }
)

local cfLabel = makeLabel(
    card,"CFLabel","CFrame.new(Pos, LookAt)",
    UDim2.new(1,-12,0,20),UDim2.new(0,6,0,100),
    {
        Font      = Enum.Font.Code,
        TextSize  = 12,
        TextColor3= Color3.fromRGB(70,70,110)
    }
)

local liveStatus = makeLabel(
    card,"LiveStatus","Live update: ON (0.5s)",
    UDim2.new(1,-12,0,18),UDim2.new(0,6,0,124),
    {
        Font      = Enum.Font.Gotham,
        TextSize  = 11,
        TextColor3= Color3.fromRGB(40,120,60)
    }
)

----------------------------------------------------------------
-- INFO BAR
----------------------------------------------------------------
local infoCard = makeCard(body,"InfoCard",UDim2.new(1,0,0,50),UDim2.new(0,0,0,0))
makeLabel(
    infoCard,"Info",
    "LookAt dihitung dari posisi HRP + LookVector * 10 studs ke depan. Tombol & hotkey menyalin: position = Vector3(...), lookAt = Vector3(...) untuk dipaste langsung ke TELEPORT_POINTS.",
    UDim2.new(1,-12,1,-8),UDim2.new(0,6,0,4),
    {
        Font      = Enum.Font.Gotham,
        TextSize  = 11,
        TextColor3= Color3.fromRGB(70,70,110),
        Wrapped   = true
    }
)

----------------------------------------------------------------
-- BUTTON CARD (2 KOLOM, SCROLL VERTIKAL)
----------------------------------------------------------------
local btnCard = makeCard(body,"ButtonCard",UDim2.new(1,0,0,120),UDim2.new(0,0,0,0))

local btnCardTitle = makeLabel(
    btnCard,"BtnTitle","Actions: Copy Coord & Server Info",
    UDim2.new(1,-10,0,18),UDim2.new(0,6,0,6),
    {
        Font      = Enum.Font.GothamSemibold,
        TextSize  = 13,
        TextColor3= Color3.fromRGB(45,45,80)
    }
)

local btnScroll = Instance.new("ScrollingFrame")
btnScroll.Name = "BtnScroll"
btnScroll.Position = UDim2.new(0,6,0,28)
btnScroll.Size = UDim2.new(1,-12,1,-36)
btnScroll.BackgroundTransparency = 1
btnScroll.BorderSizePixel = 0
btnScroll.ScrollBarThickness = 3
btnScroll.ScrollingDirection = Enum.ScrollingDirection.Y
btnScroll.CanvasSize = UDim2.new(0,0,0,0)
btnScroll.Parent = btnCard

local btnScrollPad = Instance.new("UIPadding")
btnScrollPad.PaddingLeft   = UDim.new(0,0)
btnScrollPad.PaddingRight  = UDim.new(0,0)
btnScrollPad.PaddingTop    = UDim.new(0,2)
btnScrollPad.PaddingBottom = UDim.new(0,2)
btnScrollPad.Parent = btnScroll

local btnGrid = Instance.new("UIGridLayout")
btnGrid.CellSize           = UDim2.new(0.5,-4,0,28) -- 2 kolom
btnGrid.CellPadding        = UDim2.new(0,4,0,4)
btnGrid.FillDirection      = Enum.FillDirection.Horizontal
btnGrid.FillDirectionMaxCells = 2
btnGrid.SortOrder          = Enum.SortOrder.LayoutOrder
btnGrid.HorizontalAlignment= Enum.HorizontalAlignment.Left
btnGrid.VerticalAlignment  = Enum.VerticalAlignment.Top
btnGrid.Parent             = btnScroll

btnGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    btnScroll.CanvasSize = UDim2.new(0,0,0,btnGrid.AbsoluteContentSize.Y + 4)
end)

-- Tombol-tombol (akan otomatis di-grid 2 kolom)
local btnRefresh = makeButton(
    btnScroll,"RefreshBtn","Refresh",
    UDim2.new(0,0,0,28),UDim2.new()
)

local btnCopyVec = makeButton(
    btnScroll,"CopyVecBtn","Copy position + lookAt",
    UDim2.new(0,0,0,28),UDim2.new()
)

local btnCopyCF = makeButton(
    btnScroll,"CopyCFBtn","Copy CFrame(Pos,Look)",
    UDim2.new(0,0,0,28),UDim2.new()
)

local btnCopyServerId = makeButton(
    btnScroll,"CopyServerIdBtn","Copy Server ID",
    UDim2.new(0,0,0,28),UDim2.new()
)

local btnCopyGameId = makeButton(
    btnScroll,"CopyGameIdBtn","Copy GameId",
    UDim2.new(0,0,0,28),UDim2.new()
)

----------------------------------------------------------------
-- LOGIC KOORDINAT
----------------------------------------------------------------
local function setLiveText()
    if live then
        liveStatus.Text = string.format("Live update: ON (%.1fs)", updateEvery)
        liveStatus.TextColor3 = Color3.fromRGB(40,120,60)
    else
        liveStatus.Text = "Live update: OFF (pakai tombol Refresh)"
        liveStatus.TextColor3 = Color3.fromRGB(140,90,60)
    end
end

local function applyCoords(hrp)
    local pos    = hrp.Position
    local lookAt = pos + hrp.CFrame.LookVector * 10 -- 10 studs di depan

    local x,y,z    = round(pos.X,2),    round(pos.Y,2),    round(pos.Z,2)
    local lx,ly,lz = round(lookAt.X,2), round(lookAt.Y,2), round(lookAt.Z,2)

    coordLabel.Text = string.format("X: %.2f   Y: %.2f   Z: %.2f", x,y,z)

    vecPayload     = string.format("Vector3.new(%.2f, %.2f, %.2f)", x,y,z)
    lookVecPayload = string.format("Vector3.new(%.2f, %.2f, %.2f)", lx,ly,lz)

    -- Assignment siap paste:
    -- position = Vector3.new(...), lookAt = Vector3.new(...)
    vecAssignPayload = string.format(
        "position = %s, lookAt = %s",
        vecPayload,
        lookVecPayload
    )

    -- CFrame.new(Pos, LookAt)
    cfPayload      = string.format(
        "CFrame.new(%s, %s)",
        vecPayload,
        lookVecPayload
    )

    vecLabel.Text   = "Pos: " .. vecPayload
    lookLabel.Text  = "LookAt: " .. lookVecPayload
    cfLabel.Text    = cfPayload
end

local function updateCoords(force)
    local now = os.clock()
    if not force and (now - lastUpdate) < updateEvery then return end
    lastUpdate = now

    local hrp = getHRP()
    if not hrp then return end
    applyCoords(hrp)
end

----------------------------------------------------------------
-- COPY HANDLERS
----------------------------------------------------------------
local function doCopy(payload, labelForUser)
    updateCoords(true)
    local ok = pcall(function() setclipboard(payload) end)
    if ok then
        notify("Copy Coord", labelForUser.." disalin ke clipboard", 1.5)
    else
        notify("Copy Coord", "Clipboard tidak tersedia, payload dicetak di Output", 3)
        print("[Axa CopyCoord] "..payload)
    end
end

----------------------------------------------------------------
-- BUTTON & HOTKEY
----------------------------------------------------------------
connect(btnRefresh.MouseButton1Click, function()
    updateCoords(true)
    notify("Copy Coord","Koordinat di-refresh dari posisi terbaru.",1.2)
end)

-- Copy: position = Vector3(...), lookAt = Vector3(...)
connect(btnCopyVec.MouseButton1Click, function()
    doCopy(vecAssignPayload,"position + lookAt")
end)

-- Copy CFrame.new(Vector3(Pos), Vector3(LookAt))
connect(btnCopyCF.MouseButton1Click, function()
    doCopy(cfPayload,"CFrame(Pos, LookAt)")
end)

-- Copy Server ID (JobId)
connect(btnCopyServerId.MouseButton1Click, function()
    doCopy(serverIdPayload,"Server ID")
end)

-- Copy GameId
connect(btnCopyGameId.MouseButton1Click, function()
    doCopy(gameIdPayload,"GameId")
end)

-- Hotkey: C → copy assignment yang sama (selama tidak sedang ketik di TextBox)
connect(uis.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.C and not uis:GetFocusedTextBox() then
        doCopy(vecAssignPayload,"position + lookAt")
    end
end)

-- Respawn: paksa refresh lagi
connect(player.CharacterAdded, function()
    task.delay(0.5, function()
        if live then updateCoords(true) end
    end)
end)

-- Loop live update
connect(runService.RenderStepped, function()
    if live then
        updateCoords(false)
    end
end)

setLiveText()
updateCoords(true)

----------------------------------------------------------------
-- TAB CLEANUP
----------------------------------------------------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

_G.AxaHub.TabCleanup[tabId] = function()
    for _,c in ipairs(conns) do
        pcall(function()
            if c and c.Disconnect then c:Disconnect() end
        end)
    end
end
