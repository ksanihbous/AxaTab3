--==========================================================
--  24AxaTab_ChangeGender.lua
--  TAB 24: "Change Gender"
--  UI Tahoe AxaHub + RemoteFunction Gender (Pilih Laki-laki / Perempuan)
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "changegender"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local TweenService      = TweenService      or game:GetService("TweenService")
local HttpService       = HttpService       or game:GetService("HttpService")
local UserInputService  = UserInputService  or game:GetService("UserInputService")

if not (frame and LocalPlayer) then return end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1

------------------- AXAHUB TAB CLEANUP -------------------
local alive = true
local connections = {}

local function track(conn)
    table.insert(connections, conn)
    return conn
end

_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
end

------------------- REMOTES & SOUNDS -------------------
local EventsFolder       = ReplicatedStorage:WaitForChild("Events")
local GenderRFContainer  = EventsFolder:WaitForChild("RemoteFunction")
local GenderREContainer  = EventsFolder:WaitForChild("RemoteEvent")

local GenderRemote       = GenderRFContainer:WaitForChild("Gender")
local GenderRemoteEvent  = GenderREContainer:WaitForChild("Gender")

local StuffsFolder       = ReplicatedStorage:FindFirstChild("Stuffs")
local SoundsFolder       = StuffsFolder and StuffsFolder:FindFirstChild("Sounds")

local function playUISound(name)
    if not SoundsFolder then return end
    local s = SoundsFolder:FindFirstChild(name)
    if s then
        pcall(function()
            s:Play()
        end)
    end
end

------------------- BODY SCROLL (TAHOE STYLE) -------------------
local bodyScroll = Instance.new("ScrollingFrame")
bodyScroll.Name = "BodyScroll"
bodyScroll.Parent = frame
bodyScroll.BackgroundTransparency = 1
bodyScroll.BorderSizePixel = 0
bodyScroll.Size = UDim2.new(1, 0, 1, 0)
bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
bodyScroll.ScrollBarThickness = 4
bodyScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
bodyScroll.HorizontalScrollBarInset = Enum.ScrollBarInset.None
bodyScroll.ScrollingDirection = Enum.ScrollingDirection.Y
bodyScroll.AutomaticCanvasSize = Enum.AutomaticSize.None

local bodyPadding = Instance.new("UIPadding")
bodyPadding.PaddingTop    = UDim.new(0, 8)
bodyPadding.PaddingBottom = UDim.new(0, 10)
bodyPadding.PaddingLeft   = UDim.new(0, 12)
bodyPadding.PaddingRight  = UDim.new(0, 12)
bodyPadding.Parent = bodyScroll

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.FillDirection = Enum.FillDirection.Vertical
bodyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bodyLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
bodyLayout.Padding = UDim.new(0, 8)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = bodyScroll

local function updateCanvas()
    bodyScroll.CanvasSize = UDim2.new(0, 0, 0, bodyLayout.AbsoluteContentSize.Y + 20)
end
track(bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))

------------------- HEADER LABEL (TITLE TAB) -------------------
local header = Instance.new("TextLabel")
header.Name = "HeaderTitle"
header.LayoutOrder = 1
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundTransparency = 1
header.BorderSizePixel = 0
header.Font = Enum.Font.GothamSemibold
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextColor3 = Color3.fromRGB(235, 235, 245)
header.Text = "TAB 24 · Change Gender"
header.Parent = bodyScroll

------------------- CARD: CHANGE GENDER (TAHOE CARD) -------------------
local card = Instance.new("Frame")
card.Name = "ChangeGenderCard"
card.LayoutOrder = 2
card.Size = UDim2.new(1, 0, 0, 190)
card.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = bodyScroll

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 14)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 1
cardStroke.Transparency = 0.4
cardStroke.Color = Color3.fromRGB(120, 120, 150)
cardStroke.Parent = card

local cardPadding = Instance.new("UIPadding")
cardPadding.PaddingTop    = UDim.new(0, 10)
cardPadding.PaddingBottom = UDim.new(0, 10)
cardPadding.PaddingLeft   = UDim.new(0, 12)
cardPadding.PaddingRight  = UDim.new(0, 12)
cardPadding.Parent = card

local cardLayout = Instance.new("UIListLayout")
cardLayout.FillDirection = Enum.FillDirection.Vertical
cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
cardLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
cardLayout.Padding = UDim.new(0, 6)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = card

-- Mini bar Tahoe (judul card)
local miniHeader = Instance.new("Frame")
miniHeader.Name = "MiniHeader"
miniHeader.LayoutOrder = 1
miniHeader.Size = UDim2.new(1, 0, 0, 26)
miniHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
miniHeader.BackgroundTransparency = 0.15
miniHeader.BorderSizePixel = 0
miniHeader.Parent = card

local miniHeaderCorner = Instance.new("UICorner")
miniHeaderCorner.CornerRadius = UDim.new(0, 10)
miniHeaderCorner.Parent = miniHeader

local miniHeaderLabel = Instance.new("TextLabel")
miniHeaderLabel.Name = "MiniHeaderLabel"
miniHeaderLabel.BackgroundTransparency = 1
miniHeaderLabel.BorderSizePixel = 0
miniHeaderLabel.Position = UDim2.new(0, 8, 0, 0)
miniHeaderLabel.Size = UDim2.new(1, -16, 1, 0)
miniHeaderLabel.Font = Enum.Font.GothamSemibold
miniHeaderLabel.TextSize = 14
miniHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
miniHeaderLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
miniHeaderLabel.Text = "Change Gender · Indo Hangout"
miniHeaderLabel.Parent = miniHeader

-- Info text
local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "Info"
infoLabel.LayoutOrder = 2
infoLabel.Size = UDim2.new(1, 0, 0, 38)
infoLabel.BackgroundTransparency = 1
infoLabel.BorderSizePixel = 0
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 13
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.TextColor3 = Color3.fromRGB(190, 190, 205)
infoLabel.Text = "Pilih jenis kelamin Laki-laki atau Perempuan. Saat kamu menekan tombol, pilihan langsung dikirim dan disimpan di server."
infoLabel.Parent = card

-- Container row tombol
local buttonsRow = Instance.new("Frame")
buttonsRow.Name = "ButtonsRow"
buttonsRow.LayoutOrder = 3
buttonsRow.Size = UDim2.new(1, 0, 0, 64)
buttonsRow.BackgroundTransparency = 1
buttonsRow.BorderSizePixel = 0
buttonsRow.Parent = card

local buttonsLayout = Instance.new("UIListLayout")
buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
buttonsLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
buttonsLayout.Padding = UDim.new(0, 10)
buttonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonsLayout.Parent = buttonsRow

local function createGenderButton(name, text)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.5, -5, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(230, 230, 245)
    btn.Text = text
    btn.Parent = buttonsRow

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.4
    btnStroke.Color = Color3.fromRGB(110, 110, 160)
    btnStroke.Parent = btn

    btn.MouseEnter:Connect(function()
        if not alive then return end
        if name == "BtnMale" and btn.BackgroundColor3 == Color3.fromRGB(60, 120, 255) then
            return
        end
        if name == "BtnFemale" and btn.BackgroundColor3 == Color3.fromRGB(200, 90, 180) then
            return
        end
        btn.BackgroundColor3 = Color3.fromRGB(55, 55, 95)
    end)

    btn.MouseLeave:Connect(function()
        if not alive then return end
        if name == "BtnMale" and btn.BackgroundColor3 == Color3.fromRGB(55, 55, 95) and currentGender == "Laki-laki" then
            btn.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
            return
        end
        if name == "BtnFemale" and btn.BackgroundColor3 == Color3.fromRGB(55, 55, 95) and currentGender == "Perempuan" then
            btn.BackgroundColor3 = Color3.fromRGB(200, 90, 180)
            return
        end
        if currentGender ~= "Laki-laki" and name == "BtnMale" then
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
        elseif currentGender ~= "Perempuan" and name == "BtnFemale" then
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
        end
    end)

    return btn
end

local btnMale   = createGenderButton("BtnMale",   "Laki-laki")
local btnFemale = createGenderButton("BtnFemale", "Perempuan")
btnFemale.LayoutOrder = 2

-- Status text di bawah tombol
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.LayoutOrder = 4
statusLabel.Size = UDim2.new(1, 0, 0, 26)
statusLabel.BackgroundTransparency = 1
statusLabel.BorderSizePixel = 0
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(170, 170, 200)
statusLabel.Text = "Status: Memuat status gender dari server..."
statusLabel.Parent = card

------------------- LOGIC GENDER -------------------
local currentGender = nil

local function setLocalGenderState(gender)
    currentGender = gender

    -- Reset warna dasar
    btnMale.BackgroundColor3   = Color3.fromRGB(40, 40, 70)
    btnFemale.BackgroundColor3 = Color3.fromRGB(40, 40, 70)

    if gender == "Laki-laki" then
        btnMale.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
    elseif gender == "Perempuan" then
        btnFemale.BackgroundColor3 = Color3.fromRGB(200, 90, 180)
    end

    if gender then
        statusLabel.Text = "Status: " .. gender .. " (tersimpan di server)."
    else
        statusLabel.Text = "Status: belum memilih gender."
    end
end

local function chooseGender(gender)
    if not alive then return end

    playUISound("UI - Success")

    statusLabel.Text = "Status: mengirim pilihan \"" .. gender .. "\" ke server..."
    local ok, result = pcall(function()
        -- Sesuai contoh asli: InvokeServer("Pilih", "Laki-laki"/"Perempuan")
        return GenderRemote:InvokeServer("Pilih", gender)
    end)

    if not ok then
        warn("[24AxaTab_ChangeGender] Gagal InvokeServer:", result)
        statusLabel.Text = "Status: gagal mengirim ke server, coba lagi."
        return
    end

    setLocalGenderState(gender)
end

------------------- BUTTON EVENTS -------------------
track(btnMale.Activated:Connect(function()
    chooseGender("Laki-laki")
end))

track(btnFemale.Activated:Connect(function()
    chooseGender("Perempuan")
end))

------------------- REMOTE EVENT: ShowGUI (optional notifikasi) -------------------
track(GenderRemoteEvent.OnClientEvent:Connect(function(msg)
    if not alive then return end
    if msg == "ShowGUI" then
        -- Di GUI lama: v_u_7.Enabled = true
        -- Di AxaHub Tahoe: cukup kasih hint di status / info
        playUISound("UI - Open")
        infoLabel.Text = "Server meminta kamu memilih gender sekarang. Silakan pilih Laki-laki atau Perempuan di bawah."
    end
end))

------------------- STATUS AWAL: HasGender -------------------
task.spawn(function()
    local hasGender = false
    local ok, result = pcall(function()
        return GenderRemote:InvokeServer("HasGender")
    end)

    if ok then
        if typeof(result) == "boolean" then
            hasGender = result
        elseif typeof(result) == "string" and (result == "Laki-laki" or result == "Perempuan") then
            hasGender = true
            setLocalGenderState(result)
            return
        end
    else
        warn("[24AxaTab_ChangeGender] HasGender error:", result)
    end

    if hasGender then
        statusLabel.Text = "Status: Gender sudah dipilih di server (awal join)."
        setLocalGenderState(nil) -- tidak tahu detailnya, netral
    else
        statusLabel.Text = "Status: Belum memilih gender (data server)."
        setLocalGenderState(nil)
    end
end)

-- Pastikan CanvasSize awal benar
updateCanvas()