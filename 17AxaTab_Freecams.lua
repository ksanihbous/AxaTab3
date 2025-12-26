--==========================================================
--  17AxaTab_Freecams.lua
--  TAB 17: "Freecams"
--==========================================================
--  PC:
--    - F           : toggle ON/OFF
--    - WASD / Arrow: gerak
--    - Space / E   : naik
--    - Q / Ctrl    : turun
--    - Shift       : sprint
--    - Mouse move  : look
--
--  Mobile (Touch):
--    - Tombol "FREECAM" di atas tengah = ON/OFF
--    - Joystick kiri  = gerak (kiri/kanan/depan/belakang) [atas = maju, bawah = mundur]
--    - Joystick kanan = putar kamera (yaw/pitch)
--    - Dorong joystick kiri hampir penuh = sprint
--    - Tombol UP/DOWN = naik/turun
--    - Drag layar bebas (di luar joystick) = putar kamera
--
--  Icon Mata (Hide Mode):
--    Klik berulang untuk siklus:
--      Mode 0: Normal (tidak hide).
--      Mode 1: Hide semua ScreenGui kamu (AxaHub, dll),
--              FREECAM overlay (bar + joystick + speed panel + icon mata) tetap,
--              CoreGui (capture/record) tetap hidup.
--      Mode 2: Sama seperti Mode 1 + SEMUA UI freecam/joystick/overlay disembunyikan,
--              yang tersisa hanya icon mata + CoreGui Roblox.
--
--  Joystick Speed:
--    - Panel di bawah FREECAM bar:
--         * Speed Joystick Gerak: +/- (LR/FB + naik/turun)
--         * Speed Joystick Putar: +/- (yaw/pitch kamera)
--    - Panel cuma muncul saat FREECAM ON
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "freecams"

local Players              = Players              or game:GetService("Players")
local RunService           = RunService           or game:GetService("RunService")
local UserInputService     = UserInputService     or game:GetService("UserInputService")
local ContextActionService = ContextActionService or game:GetService("ContextActionService")
local LocalPlayer          = LocalPlayer          or Players.LocalPlayer

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.Name = "TAB_" .. tostring(tabId)

local playerGui
pcall(function()
    playerGui = LocalPlayer:WaitForChild("PlayerGui")
end)

------------------- CORE SCREEN GUI (DOCK UTAMA) -------------------
local coreScreenGui
do
    local ancestor = frame
    while ancestor and not ancestor:IsA("ScreenGui") do
        ancestor = ancestor.Parent
    end
    coreScreenGui = ancestor
end

------------------- REGISTER CLEANUP (dari CORE kalau ada) -------------------
local registerCleanup = rawget(_G, "AXA_REGISTER_TAB_CLEANUP")

------------------- CAMERA REF -------------------
local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
end)

--==========================================================
--  KONFIG
--==========================================================

local FREECAM_TOGGLE_KEY = Enum.KeyCode.F
local BASE_MOVE_SPEED    = 40          -- studs/s
local SPRINT_MULTIPLIER  = 2
local MOUSE_SENSITIVITY  = 0.0025      -- rad per pixel

local TOUCH_LOOK_SENS    = 2           -- base kecepatan putar joystick
local JOY_SCALE_MIN      = 0.2
local JOY_SCALE_MAX      = 10
local JOY_SCALE_STEP     = 0.2

--==========================================================
--  STATE GLOBAL
--==========================================================

local freecamEnabled = false

-- Posisi/rotasi kamera freecam
local camCFrame
local yaw   = 0
local pitch = 0

-- Input state (PC)
local keyboardMove     = Vector3.new()
local keyboardVertical = 0

-- Input state (Mobile Joystick)
local mobileMove     = Vector2.new()
local mobileLook     = Vector2.new()
local mobileVertical = 0

-- Joystick speed scale
local joystickMoveScale = 1     -- gerak LR/FB + vertical
local joystickLookScale = 1     -- putar yaw/pitch

-- Mouse backup
local originalMouseBehavior
local originalMouseIconEnabled

-- Overlay GUI (PlayerGui)
local overlayGui
local overlayToggleButton        -- tombol FREECAM: ON/OFF tengah atas
local uiEyeButton                -- icon mata
local joystickSpeedPanel         -- panel speed +/-

-- Joystick & tombol naik/turun
local leftJoy    -- {outer, inner, vector, activeInput, radius}
local rightJoy
local upButton
local downButton

-- drag-look state (mobile touch di layar bebas)
local touchLookInput    = nil
local touchLookLastPos  = nil

local renderConn

-- Hide mode:
--  0 = normal
--  1 = hide semua ScreenGui kecuali overlay + CoreGui
--  2 = sama + hide semua overlay kecuali icon mata + CoreGui
local uiHideMode    = 0
local eyeHiddenGuis = {}

-- TAB UI di CORE
local tabToggleButton

-- Input connections
local inputBeganConn, inputEndedConn, inputChangedConn

-- Movement-block state (supaya karakter diam saat FREECAM PC)
local movementBound = false

-- Forward declare
local toggleFreecam

--==========================================================
--  UTIL: SET CAMERA KE HUMANOID (TANPA CUSTOM CFRAME)
--==========================================================

local function setCameraToHumanoid()
    if not camera then
        camera = workspace.CurrentCamera
        if not camera then return end
    end

    camera.CameraType = Enum.CameraType.Custom

    local character = LocalPlayer.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum then
        camera.CameraSubject = hum
    else
        camera.CameraSubject = nil
    end
    -- Tidak menyentuh camera.CFrame di sini:
    -- biarkan script kamera default Roblox yang atur POV.
end

--==========================================================
--  UTIL: UPDATE KEYBOARD VECTOR (REALTIME – DIPANGGIL TIAP FRAME)
--==========================================================

local function updateKeyboardVector()
    local forward = 0
    local right   = 0
    local up      = 0

    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
        forward = forward + 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
        forward = forward - 1
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
        right = right + 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
        right = right - 1
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        up = up + 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        up = up - 1
    end

    keyboardMove     = Vector3.new(right, 0, forward)
    keyboardVertical = up
end

--==========================================================
--  TOGGLE LABEL (TAB & OVERLAY)
--==========================================================

local function updateToggleLabels()
    local text = freecamEnabled and "FREECAM: ON" or "FREECAM: OFF"

    if overlayToggleButton then
        overlayToggleButton.Text = text
        overlayToggleButton.BackgroundColor3 = freecamEnabled
            and Color3.fromRGB(40, 170, 60)
            or  Color3.fromRGB(50, 50, 50)
    end

    if tabToggleButton then
        tabToggleButton.Text = text .. " (Key: F)"
        tabToggleButton.BackgroundColor3 = freecamEnabled
            and Color3.fromRGB(40, 170, 60)
            or  Color3.fromRGB(90, 90, 90)
    end
end

--==========================================================
--  JOYSTICK STRUCT
--==========================================================

local function makeJoystick(parent, defaultPosition)
    local outer = Instance.new("Frame")
    outer.Name = "JoystickOuter"
    outer.Size = UDim2.new(0, 150, 0, 150)
    outer.AnchorPoint = Vector2.new(0.5, 0.5)
    outer.Position = defaultPosition or UDim2.new(0.5, 0, 0.5, 0)
    outer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    outer.BackgroundTransparency = 0.6
    outer.BorderSizePixel = 0
    outer.ClipsDescendants = true
    outer.Active = true
    outer.ZIndex = 10
    outer.Parent = parent

    local internal = Instance.new("Frame")
    internal.Name = "JoystickInner"
    internal.Size = UDim2.new(0, 60, 0, 60)
    internal.AnchorPoint = Vector2.new(0.5, 0.5)
    internal.Position = UDim2.new(0.5, 0, 0.5, 0)
    internal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    internal.BackgroundTransparency = 0.1
    internal.BorderSizePixel = 0
    internal.ZIndex = 11
    internal.Parent = outer

    local joy = {
        outer       = outer,
        inner       = internal,
        vector      = Vector2.new(),
        activeInput = nil,
        radius      = 60,
    }

    function joy:updateFromInput(input)
        if not freecamEnabled then return end
        if self.activeInput ~= input then return end
        if not self.outer or not self.inner then return end

        local absPos  = self.outer.AbsolutePosition
        local absSize = self.outer.AbsoluteSize

        local localPos = Vector2.new(input.Position.X, input.Position.Y) - absPos
        local center   = Vector2.new(absSize.X/2, absSize.Y/2)
        local offset   = localPos - center

        if offset.Magnitude > self.radius then
            offset = offset.Unit * self.radius
        end

        -- vector.Y = nilai layar (atas negatif, bawah positif)
        -- nanti dibalik saat dipakai buat maju/mundur
        self.vector = offset / self.radius
        self.inner.Position = UDim2.new(0, center.X + offset.X, 0, center.Y + offset.Y)
    end

    outer.InputBegan:Connect(function(input)
        if not freecamEnabled then return end
        if input.UserInputType == Enum.UserInputType.Touch and not joy.activeInput then
            joy.activeInput = input
            joy:updateFromInput(input)
        end
    end)

    return joy
end

local function resetJoystick(joy)
    if not joy then return end
    joy.vector = Vector2.new()
    joy.activeInput = nil
    if joy.inner then
        joy.inner.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end

local function destroyJoystick(joy)
    if not joy then return end
    if joy.outer then
        joy.outer:Destroy()
    end
end

--==========================================================
--  OVERLAY VISIBILITY (ICON MATA, JOYSTICK, SPEED PANEL)
--==========================================================

local function refreshOverlayVisibility()
    if not overlayGui then return end

    -- icon mata
    if uiEyeButton then
        uiEyeButton.Visible = freecamEnabled
        if freecamEnabled then
            if uiHideMode == 0 then
                uiEyeButton.Text = "👁"
                uiEyeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            elseif uiHideMode == 1 then
                uiEyeButton.Text = "👁1"
                uiEyeButton.BackgroundColor3 = Color3.fromRGB(120, 160, 80)
            else
                uiEyeButton.Text = "👁2"
                uiEyeButton.BackgroundColor3 = Color3.fromRGB(200, 130, 50)
            end
        end
    end

    -- tombol FREECAM bar tengah
    if overlayToggleButton then
        local visible = true
        if freecamEnabled and uiHideMode == 2 then
            visible = false
        end
        overlayToggleButton.Visible = visible
    end

    local function setJoyVisible(obj)
        if not obj then return end
        local visible = freecamEnabled
        if freecamEnabled and uiHideMode == 2 then
            visible = false
        end
        obj.Visible = visible
    end

    setJoyVisible(joystickSpeedPanel)

    if leftJoy and leftJoy.outer then
        setJoyVisible(leftJoy.outer)
    end
    if rightJoy and rightJoy.outer then
        setJoyVisible(rightJoy.outer)
    end
    setJoyVisible(upButton)
    setJoyVisible(downButton)
end

--==========================================================
--  HIDE MODE (SCREEN GUI)
--==========================================================

local function applyHideMode()
    if playerGui then
        -- restore dulu semua yang pernah di-hide
        for gui in pairs(eyeHiddenGuis) do
            if gui and gui.Parent == playerGui then
                gui.Enabled = true
            end
        end
        eyeHiddenGuis = {}

        -- jika freecam aktif & mode > 0 → hide semua ScreenGui kecuali overlay
        if freecamEnabled and uiHideMode > 0 then
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui ~= overlayGui and gui.Enabled then
                    eyeHiddenGuis[gui] = true
                    gui.Enabled = false
                end
            end
        end
    end

    refreshOverlayVisibility()
end

--==========================================================
--  JOYSTICK CREATE / DESTROY
--==========================================================

local function createJoysticks()
    if not UserInputService.TouchEnabled then return end
    if not overlayGui then return end
    if leftJoy or rightJoy then return end

    -- Kiri bawah (gerak)
    leftJoy  = makeJoystick(overlayGui, UDim2.new(0, 120, 1, -120))
    -- Kanan bawah (look)
    rightJoy = makeJoystick(overlayGui, UDim2.new(1, -120, 1, -120))

    -- tombol UP/DOWN
    upButton = Instance.new("TextButton")
    upButton.Name = "FreecamUpButton"
    upButton.Size = UDim2.new(0, 60, 0, 60)
    upButton.AnchorPoint = Vector2.new(1, 1)
    upButton.Position = UDim2.new(1, -200, 1, -200)
    upButton.Text = "UP"
    upButton.Font = Enum.Font.GothamBold
    upButton.TextSize = 16
    upButton.TextColor3 = Color3.new(1, 1, 1)
    upButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    upButton.BackgroundTransparency = 0.1
    upButton.BorderSizePixel = 0
    upButton.ZIndex = 10
    upButton.Parent = overlayGui

    downButton = Instance.new("TextButton")
    downButton.Name = "FreecamDownButton"
    downButton.Size = UDim2.new(0, 60, 0, 60)
    downButton.AnchorPoint = Vector2.new(1, 1)
    downButton.Position = UDim2.new(1, -200, 1, -130)
    downButton.Text = "DOWN"
    downButton.Font = Enum.Font.GothamBold
    downButton.TextSize = 16
    downButton.TextColor3 = Color3.new(1, 1, 1)
    downButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    downButton.BackgroundTransparency = 0.1
    downButton.BorderSizePixel = 0
    downButton.ZIndex = 10
    downButton.Parent = overlayGui

    upButton.MouseButton1Down:Connect(function()
        if freecamEnabled then
            mobileVertical = 1
        end
    end)
    upButton.MouseButton1Up:Connect(function()
        if mobileVertical == 1 then
            mobileVertical = 0
        end
    end)
    upButton.MouseLeave:Connect(function()
        if mobileVertical == 1 then
            mobileVertical = 0
        end
    end)

    downButton.MouseButton1Down:Connect(function()
        if freecamEnabled then
            mobileVertical = -1
        end
    end)
    downButton.MouseButton1Up:Connect(function()
        if mobileVertical == -1 then
            mobileVertical = 0
        end
    end)
    downButton.MouseLeave:Connect(function()
        if mobileVertical == -1 then
            mobileVertical = 0
        end
    end)

    refreshOverlayVisibility()
end

local function destroyJoysticks()
    mobileMove     = Vector2.new()
    mobileLook     = Vector2.new()
    mobileVertical = 0

    destroyJoystick(leftJoy)
    destroyJoystick(rightJoy)
    leftJoy  = nil
    rightJoy = nil

    if upButton then
        upButton:Destroy()
        upButton = nil
    end
    if downButton then
        downButton:Destroy()
        downButton = nil
    end

    refreshOverlayVisibility()
end

--==========================================================
--  GLOBAL TOUCH MOVE / END → JOYSTICK + DRAG LOOK
--==========================================================

if UserInputService.TouchEnabled then
    UserInputService.TouchMoved:Connect(function(input)
        if not freecamEnabled then return end

        -- Prioritas: joystick dulu
        if leftJoy and leftJoy.activeInput == input then
            leftJoy:updateFromInput(input)
            return
        end
        if rightJoy and rightJoy.activeInput == input then
            rightJoy:updateFromInput(input)
            return
        end

        -- drag-look di layar (selain joystick)
        if not touchLookInput then
            touchLookInput   = input
            touchLookLastPos = Vector2.new(input.Position.X, input.Position.Y)
            return
        end

        if input == touchLookInput and touchLookLastPos then
            local currentPos = Vector2.new(input.Position.X, input.Position.Y)
            local delta      = currentPos - touchLookLastPos
            touchLookLastPos = currentPos

            local touchSens = MOUSE_SENSITIVITY * 1.5 * joystickLookScale
            yaw   = yaw   - delta.X * touchSens
            pitch = math.clamp(
                pitch - delta.Y * touchSens,
                -math.rad(89),
                math.rad(89)
            )
        end
    end)

    UserInputService.TouchEnded:Connect(function(input)
        if leftJoy and leftJoy.activeInput == input then
            resetJoystick(leftJoy)
        end
        if rightJoy and rightJoy.activeInput == input then
            resetJoystick(rightJoy)
        end
        if touchLookInput == input then
            touchLookInput   = nil
            touchLookLastPos = nil
        end
    end)
end

--==========================================================
--  OVERLAY GUI (FREECAM BAR + ICON MATA + SPEED PANEL)
--==========================================================

local function initOverlayGui()
    if overlayGui or not playerGui then
        return
    end

    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "Axa_FreecamOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    overlayGui.Parent = playerGui

    -- FREECAM toggle (bar tengah atas)
    overlayToggleButton = Instance.new("TextButton")
    overlayToggleButton.Name = "ToggleFreecamButton"
    overlayToggleButton.Size = UDim2.new(0, 140, 0, 40)
    overlayToggleButton.AnchorPoint = Vector2.new(0.5, 0)
    overlayToggleButton.Position = UDim2.new(0.5, 0, 0, 10)
    overlayToggleButton.Text = "FREECAM: OFF"
    overlayToggleButton.Font = Enum.Font.GothamBold
    overlayToggleButton.TextSize = 16
    overlayToggleButton.TextColor3 = Color3.new(1, 1, 1)
    overlayToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    overlayToggleButton.BackgroundTransparency = 0.2
    overlayToggleButton.BorderSizePixel = 0
    overlayToggleButton.ZIndex = 20
    overlayToggleButton.Parent = overlayGui

    overlayToggleButton.MouseButton1Click:Connect(function()
        if toggleFreecam then
            toggleFreecam()
        end
    end)

    -- ICON MATA di samping FREECAM
    uiEyeButton = Instance.new("TextButton")
    uiEyeButton.Name = "HideUiEyeButton"
    uiEyeButton.Size = UDim2.new(0, 36, 0, 36)
    uiEyeButton.AnchorPoint = Vector2.new(0, 0)
    uiEyeButton.Position = UDim2.new(0.5, 80, 0, 12)
    uiEyeButton.Text = "👁"
    uiEyeButton.Font = Enum.Font.GothamBold
    uiEyeButton.TextSize = 18
    uiEyeButton.TextColor3 = Color3.new(1, 1, 1)
    uiEyeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    uiEyeButton.BackgroundTransparency = 0.1
    uiEyeButton.BorderSizePixel = 0
    uiEyeButton.ZIndex = 21
    uiEyeButton.Visible = false
    uiEyeButton.Parent = overlayGui

    local eyeCorner = Instance.new("UICorner")
    eyeCorner.CornerRadius = UDim.new(1, 0)
    eyeCorner.Parent = uiEyeButton

    local eyeStroke = Instance.new("UIStroke")
    eyeStroke.Thickness = 1
    eyeStroke.Color = Color3.fromRGB(200, 200, 200)
    eyeStroke.Parent = uiEyeButton

    uiEyeButton.MouseButton1Click:Connect(function()
        if not freecamEnabled then return end
        uiHideMode = (uiHideMode + 1) % 3
        applyHideMode()
    end)

    -- PANEL SPEED JOYSTICK (di bawah FREECAM bar)
    joystickSpeedPanel = Instance.new("Frame")
    joystickSpeedPanel.Name = "JoystickSpeedPanel"
    joystickSpeedPanel.Size = UDim2.new(0, 260, 0, 60)
    joystickSpeedPanel.AnchorPoint = Vector2.new(0.5, 0)
    joystickSpeedPanel.Position = UDim2.new(0.5, 0, 0, 60)
    joystickSpeedPanel.BackgroundTransparency = 1
    joystickSpeedPanel.ZIndex = 21
    joystickSpeedPanel.Parent = overlayGui

    local panelLayout = Instance.new("UIListLayout")
    panelLayout.FillDirection = Enum.FillDirection.Vertical
    panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    panelLayout.Padding = UDim.new(0, 2)
    panelLayout.Parent = joystickSpeedPanel

    local moveValueLabel
    local lookValueLabel

    local function refreshSpeedLabels()
        if moveValueLabel then
            moveValueLabel.Text = string.format("x%.1f", joystickMoveScale)
        end
        if lookValueLabel then
            lookValueLabel.Text = string.format("x%.1f", joystickLookScale)
        end
    end

    local function createSpeedRow(order, labelText, which)
        local row = Instance.new("Frame")
        row.Name = "Row_" .. which
        row.LayoutOrder = order
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.ZIndex = 21
        row.Parent = joystickSpeedPanel

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Parent = row
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(210, 210, 210)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = labelText

        local minus = Instance.new("TextButton")
        minus.Name = "Minus"
        minus.Parent = row
        minus.Size = UDim2.new(0, 26, 0, 26)
        minus.Position = UDim2.new(0.6, 0, 0, 1)
        minus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        minus.TextColor3 = Color3.new(1, 1, 1)
        minus.Font = Enum.Font.GothamBold
        minus.TextSize = 16
        minus.Text = "-"

        local value = Instance.new("TextLabel")
        value.Name = "Value"
        value.Parent = row
        value.Size = UDim2.new(0, 60, 0, 26)
        value.Position = UDim2.new(0.6, 28, 0, 1)
        value.BackgroundTransparency = 1
        value.Font = Enum.Font.GothamBold
        value.TextSize = 13
        value.TextColor3 = Color3.fromRGB(230, 230, 230)
        value.TextXAlignment = Enum.TextXAlignment.Center

        local plus = Instance.new("TextButton")
        plus.Name = "Plus"
        plus.Parent = row
        plus.Size = UDim2.new(0, 26, 0, 26)
        plus.Position = UDim2.new(1, -28, 0, 1)
        plus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        plus.TextColor3 = Color3.new(1, 1, 1)
        plus.Font = Enum.Font.GothamBold
        plus.TextSize = 16
        plus.Text = "+"

        if which == "move" then
            moveValueLabel = value

            minus.MouseButton1Click:Connect(function()
                joystickMoveScale = math.clamp(
                    joystickMoveScale - JOY_SCALE_STEP,
                    JOY_SCALE_MIN,
                    JOY_SCALE_MAX
                )
                refreshSpeedLabels()
            end)

            plus.MouseButton1Click:Connect(function()
                joystickMoveScale = math.clamp(
                    joystickMoveScale + JOY_SCALE_STEP,
                    JOY_SCALE_MIN,
                    JOY_SCALE_MAX
                )
                refreshSpeedLabels()
            end)
        else
            lookValueLabel = value

            minus.MouseButton1Click:Connect(function()
                joystickLookScale = math.clamp(
                    joystickLookScale - JOY_SCALE_STEP,
                    JOY_SCALE_MIN,
                    JOY_SCALE_MAX
                )
                refreshSpeedLabels()
            end)

            plus.MouseButton1Click:Connect(function()
                joystickLookScale = math.clamp(
                    joystickLookScale + JOY_SCALE_STEP,
                    JOY_SCALE_MIN,
                    JOY_SCALE_MAX
                )
                refreshSpeedLabels()
            end)
        end
    end

    createSpeedRow(1, "Speed Joystick Gerak:", "move")
    createSpeedRow(2, "Speed Joystick Putar:", "look")
    refreshSpeedLabels()

    updateToggleLabels()
    applyHideMode()
end

--==========================================================
--  FREECAM ENABLE / DISABLE
--==========================================================

local function bindMovementBlock()
    if movementBound then return end

    local HIGH = Enum.ContextActionPriority.High.Value

    ContextActionService:BindActionAtPriority(
        "Freecam_BlockMovement",
        function(_, _, _)
            if not freecamEnabled then
                return Enum.ContextActionResult.Pass
            end
            -- Saat freecam aktif, telan semua input gerak karakter
            return Enum.ContextActionResult.Sink
        end,
        false,
        HIGH,
        Enum.KeyCode.W,
        Enum.KeyCode.A,
        Enum.KeyCode.S,
        Enum.KeyCode.D,
        Enum.KeyCode.Space,
        Enum.KeyCode.E,
        Enum.KeyCode.Q,
        Enum.KeyCode.Up,
        Enum.KeyCode.Down,
        Enum.KeyCode.Left,
        Enum.KeyCode.Right
    )

    movementBound = true
end

local function unbindMovementBlock()
    if not movementBound then return end
    pcall(function()
        ContextActionService:UnbindAction("Freecam_BlockMovement")
    end)
    movementBound = false
end

local function enableFreecam()
    if freecamEnabled then return end

    if not camera then
        camera = workspace.CurrentCamera
        if not camera then return end
    end

    freecamEnabled = true

    camCFrame = camera.CFrame
    local x, y, _ = camCFrame:ToEulerAnglesYXZ()
    pitch = x
    yaw   = y

    camera.CameraType    = Enum.CameraType.Scriptable
    camera.CameraSubject = nil

    originalMouseBehavior    = UserInputService.MouseBehavior
    originalMouseIconEnabled = UserInputService.MouseIconEnabled

    if not UserInputService.TouchEnabled then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    end

    if UserInputService.TouchEnabled then
        createJoysticks()
    end

    updateKeyboardVector()
    updateToggleLabels()
    applyHideMode()
    bindMovementBlock()

    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not freecamEnabled or not camera or not camCFrame then return end

        -- BACA KEYBOARD *TIAP FRAME* → realtime
        updateKeyboardVector()

        local move = Vector3.new()

        -- Keyboard (WASD/Arrow + naik/turun)
        move = move + keyboardMove * BASE_MOVE_SPEED
        move = move + Vector3.new(0, keyboardVertical * BASE_MOVE_SPEED, 0)

        -- Mobile joystick gerak + vertical
        local mobileJoyMag = 0
        if UserInputService.TouchEnabled and leftJoy then
            mobileMove = leftJoy.vector

            -- BALIK Sumbu Y untuk movement:
            --   Atas (screen Y negatif)  → maju (Z positif)
            --   Bawah (screen Y positif) → mundur (Z negatif)
            local joyVec = Vector2.new(mobileMove.X, -mobileMove.Y)

            mobileJoyMag = joyVec.Magnitude
            local joyBase = BASE_MOVE_SPEED * joystickMoveScale
            move = move + Vector3.new(joyVec.X, 0, joyVec.Y) * joyBase
            move = move + Vector3.new(0, mobileVertical * joyBase, 0)
        end

        -- Sprint PC (Shift)
        local speedMult = 1
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            speedMult = SPRINT_MULTIPLIER
        end

        -- Sprint Mobile via joystick kiri (dorong hampir penuh)
        local mobileSpeedMult = 1
        if UserInputService.TouchEnabled and leftJoy and mobileJoyMag > 0 then
            if mobileJoyMag > 0.75 then
                mobileSpeedMult = SPRINT_MULTIPLIER
            end
        end

        local totalSpeedMult = speedMult * mobileSpeedMult

        -- Rotasi dari joystick kanan (Mobile)
        if UserInputService.TouchEnabled and rightJoy then
            mobileLook = rightJoy.vector
            local yawSpeed   = math.rad(TOUCH_LOOK_SENS * joystickLookScale) * 60
            local pitchSpeed = math.rad(TOUCH_LOOK_SENS * joystickLookScale) * 60
            yaw = yaw + (-mobileLook.X) * yawSpeed * dt
            pitch = math.clamp(
                pitch + (-mobileLook.Y) * pitchSpeed * dt,
                -math.rad(89),
                math.rad(89)
            )
        end

        local rot = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)

        if move.Magnitude > 0 then
            local dir = move.Unit * move.Magnitude * totalSpeedMult * dt
            local forwardVec = rot.LookVector
            local rightVec   = rot.RightVector
            local upVec      = Vector3.new(0, 1, 0)

            local moveWorld = rightVec * dir.X + upVec * dir.Y + forwardVec * dir.Z
            camCFrame = camCFrame + moveWorld
        end

        camCFrame     = CFrame.new(camCFrame.Position) * rot
        camera.CFrame = camCFrame
        camera.Focus  = camCFrame
    end)
end

local function disableFreecam()
    if not freecamEnabled then return end

    freecamEnabled = false

    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end

    unbindMovementBlock()

    -- Balik ke kamera Humanoid bawaan Roblox, tanpa custom CFrame
    setCameraToHumanoid()

    if originalMouseBehavior then
        UserInputService.MouseBehavior = originalMouseBehavior
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end

    if originalMouseIconEnabled ~= nil then
        UserInputService.MouseIconEnabled = originalMouseIconEnabled
    else
        UserInputService.MouseIconEnabled = true
    end

    keyboardMove     = Vector3.new()
    keyboardVertical = 0
    mobileMove       = Vector2.new()
    mobileLook       = Vector2.new()
    mobileVertical   = 0

    touchLookInput   = nil
    touchLookLastPos = nil

    destroyJoysticks()

    uiHideMode = 0
    applyHideMode()
    updateToggleLabels()
end

toggleFreecam = function()
    if freecamEnabled then
        disableFreecam()
    else
        enableFreecam()
    end
end

--==========================================================
--  INPUT HANDLERS
--==========================================================

inputBeganConn = UserInputService.InputBegan:Connect(function(input, _)
    -- F SELALU toggle freecam (sama persis dengan tombol FREECAM bar)
    if input.UserInputType == Enum.UserInputType.Keyboard
        and input.KeyCode == FREECAM_TOGGLE_KEY then
        toggleFreecam()
        return
    end
end)

inputEndedConn = UserInputService.InputEnded:Connect(function(_, _)
    -- WASD realtime lewat updateKeyboardVector() di RenderStepped
end)

inputChangedConn = UserInputService.InputChanged:Connect(function(input, processed)
    if not freecamEnabled then return end

    -- Mouse look (PC)
    if not UserInputService.TouchEnabled and input.UserInputType == Enum.UserInputType.MouseMovement then
        if processed then return end
        local delta = input.Delta
        yaw   = yaw   - delta.X * MOUSE_SENSITIVITY
        pitch = math.clamp(pitch - delta.Y * MOUSE_SENSITIVITY, -math.rad(89), math.rad(89))
    end
end)

--==========================================================
--  RESPAWN SAFETY
--==========================================================
LocalPlayer.CharacterAdded:Connect(function()
    if freecamEnabled then
        -- Saat respawn, matikan freecam dan langsung serahkan kamera ke humanoid baru
        disableFreecam()
    else
        -- Pastikan kamera tetap normal ke humanoid setelah respawn
        setCameraToHumanoid()
    end
end)

--==========================================================
--  TAB UI (CORE DOCK)
--==========================================================

local function setupTabUI()
    local container = Instance.new("Frame")
    container.Name = "FreecamContainer"
    container.Parent = frame
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.Size = UDim2.new(1, -20, 1, -20)
    container.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = container

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = container
    title.LayoutOrder = 1
    title.Size = UDim2.new(1, 0, 0, 26)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(250, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Freecam (PC + Mobile Joystick) V4"

    local desc = Instance.new("TextLabel")
    desc.Name = "Description"
    desc.Parent = container
    desc.LayoutOrder = 2
    desc.Size = UDim2.new(1, 0, 0, 130)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 14
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.TextWrapped = true
    desc.Text = table.concat({
        "PC: F toggle, WASD/Arrow, Space/E naik, Q turun, Shift sprint, mouse look.",
        "Mobile: FREECAM bar di atas tengah ON → joystick kiri (gerak), joystick kanan (putar), tombol UP/DOWN (naik/turun).",
        "Icon mata: 0=normal, 1=hide semua ScreenGui (kecuali overlay + CoreGui), 2=hide semua ScreenGui + overlay (sisa icon mata + CoreGui).",
        "Speed joystick +/− ada di bawah FREECAM bar (overlay), muncul saat FREECAM ON.",
        "FREECAM PC: karakter tidak bergerak (WASD diblok lewat ContextActionService)."
    }, "\n")

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "TabToggleFreecam"
    toggleBtn.Parent = container
    toggleBtn.LayoutOrder = 3
    toggleBtn.Size = UDim2.new(0, 260, 0, 32)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    toggleBtn.AutoButtonColor = true
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Text = "FREECAM: OFF (Key: F)"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toggleBtn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(40, 40, 40)
    stroke.Parent = toggleBtn

    tabToggleButton = toggleBtn
    toggleBtn.MouseButton1Click:Connect(function()
        toggleFreecam()
    end)

    updateToggleLabels()
end

--==========================================================
--  STARTUP
--==========================================================
initOverlayGui()
setupTabUI()
updateToggleLabels()
applyHideMode()
setCameraToHumanoid()  -- pastikan awalnya kamera ke Humanoid juga

--==========================================================
--  CLEANUP DARI CORE
--==========================================================
if type(registerCleanup) == "function" then
    registerCleanup(tabId, function()
        disableFreecam()
        if inputBeganConn   then pcall(function() inputBeganConn:Disconnect() end)   end
        if inputEndedConn   then pcall(function() inputEndedConn:Disconnect() end)   end
        if inputChangedConn then pcall(function() inputChangedConn:Disconnect() end) end
        if overlayGui       then pcall(function() overlayGui:Destroy() end)          end
    end)
end

frame.AncestryChanged:Connect(function(_, parent)
    if not parent then
        disableFreecam()
        if overlayGui then
            pcall(function() overlayGui:Destroy() end)
            overlayGui = nil
        end
    end
end)
