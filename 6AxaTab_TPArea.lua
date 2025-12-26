--==========================================================
--  6AxaTab_TPArea.lua (ringkas)
--==========================================================
local players          = Players or game:GetService("Players")
local player           = LocalPlayer or players.LocalPlayer
local TweenService     = game:GetService("TweenService")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TextChatService  = game:GetService("TextChatService")

local frame = TAB_FRAME

-- KARAKTER
local char = player.Character or player.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")
player.CharacterAdded:Connect(function(c)
    char, hrp = c, c:WaitForChild("HumanoidRootPart")
end)

-- HELPER
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Info",
            Text = text or "",
            Duration = dur or 2
        })
    end)
end

local function ensureReady(timeout)
    timeout = timeout or 5
    local c = player.Character or player.CharacterAdded:Wait()
    local hum = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid")
    local root = c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart")
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if hum.Health > 0 and root and root.Parent == c then break end
        task.wait(0.05)
    end
    if root then
        if root.Anchored then root.Anchored = false end
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if hum then
        hum.Sit = false
        hum.PlatformStand = false
    end
    return c, hum, root
end

local function teleportTo(vec)
    local c, hum, root = ensureReady(5)
    if not (c and hum and root and hum.Health > 0) then
        notify("Teleport", "Karakter belum siap.", 1.2)
        return
    end
    c:PivotTo(CFrame.new(vec)) -- tepat di Vector3, tanpa maju 1cm
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    notify("Teleport", string.format("Ke (%.2f, %.2f, %.2f)", vec.X, vec.Y, vec.Z), 1.2)
end

local function safeSetClipboard(text, labelName)
    local ok = pcall(function() setclipboard(text) end)
    if ok then
        notify("Disalin", (labelName and (labelName .. " → ") or "") .. "Koordinat disalin ke clipboard.", 1.2)
    else
        notify("Clipboard", text, 2.5)
    end
end

-- REJOIN
local function tryRejoin()
    notify("Rejoin", "Menghubungkan ulang...", 1.2)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)
    if not ok then
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end
end

local function handleChatForRejoin(text, fromUserId)
    if not text or fromUserId ~= player.UserId then return end
    local msg = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg:sub(1, 7) == "!rejoin" then
        tryRejoin()
    end
end

if not _G.AxaHub_TP_RejoinHooked then
    _G.AxaHub_TP_RejoinHooked = true
    if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local function hookChannel(ch)
            if ch:IsA("TextChannel") then
                ch.MessageReceived:Connect(function(message)
                    local src = message.TextSource
                    if src and src.UserId == player.UserId then
                        handleChatForRejoin(message.Text, src.UserId)
                    end
                end)
            end
        end
        local chans = TextChatService:FindFirstChild("TextChannels")
        if chans then
            for _, ch in ipairs(chans:GetChildren()) do hookChannel(ch) end
            chans.ChildAdded:Connect(hookChannel)
        end
    end
    player.Chatted:Connect(function(msg)
        handleChatForRejoin(msg, player.UserId)
    end)
end

-- DATA AREA
local AREAS = {
    { name = "Basecamp HG",              vec = Vector3.new(30.00, 41.89, -28.33) },
    { name = "Menara HG",                 vec =Vector3.new(-300.90, 128.67, -671.39) },
    { name = "Sell Fish HG",             vec = Vector3.new(196.72, -0.05, -457.84) },
    { name = "Buy Rod HG",               vec = Vector3.new(229.67, 2.65, -277.26) },
    { name = "Air Terjun HG",               vec = Vector3.new(411.10, 107.32, 120.95) },
    { name = "ES Blok 1 HG (Tgh Laut)",    vec = Vector3.new(1076.52, 4.12, -2706.71)},
    { name = "ES Blok 2 HG (Dkt Menara)",    vec = Vector3.new(-85.79, 3.12, -846.27)},
    { name = "ES Blok 3 HG (Dkt Menara 2)",    vec = Vector3.new(-1186.69, 2.94, -242.95)},
    { name = "ES Blok 4 HG (Dkt Sampan)",    vec = Vector3.new(233.35, 1.78, -1172.34)},
    { name = "Tengah Laut HG (Bawah)",   vec = Vector3.new(-193.03, 6.95, -2769.54) },
    { name = "Tengah Laut HG (Atas)",    vec = Vector3.new(-177.63, 19.19, -2771.63) },
}

-- UI HEADER
local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, -10, 0, 22)
header.Position = UDim2.new(0, 5, 0, 6)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBold
header.TextSize = 15
header.TextColor3 = Color3.fromRGB(40, 40, 60)
header.TextXAlignment = Enum.TextXAlignment.Left
header.Text = "🧭 TP Area"
header.Parent = frame

local sub = Instance.new("TextLabel")
sub.Name = "Sub"
sub.Size = UDim2.new(1, -10, 0, 34)
sub.Position = UDim2.new(0, 5, 0, 26)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextColor3 = Color3.fromRGB(90, 90, 120)
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextYAlignment = Enum.TextYAlignment.Top
sub.TextWrapped = true
sub.Text = "Klik tombol TP untuk teleport ke area favorit. SHIFT + klik kartu = salin Vector3. Ketik !rejoin di chat untuk rejoin server."
sub.Parent = frame

-- LIST AREA
local list = Instance.new("ScrollingFrame")
list.Name = "AreaList"
list.Position = UDim2.new(0, 6, 0, 70)
list.Size = UDim2.new(1, -12, 1, -120)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.ScrollBarImageTransparency = 0.1
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = list
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end)

-- FOOTER
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.Size = UDim2.new(1, -12, 0, 26)
footer.Position = UDim2.new(0, 6, 1, -30)
footer.BackgroundTransparency = 1
footer.Parent = frame

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "Info"
infoLabel.Size = UDim2.new(1, -140, 1, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextColor3 = Color3.fromRGB(90, 90, 120)
infoLabel.Text = "Total area: " .. tostring(#AREAS)
infoLabel.Parent = footer

local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Name = "RejoinButton"
rejoinBtn.Size = UDim2.new(0, 120, 1, 0)
rejoinBtn.Position = UDim2.new(1, -120, 0, 0)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(110, 140, 210)
rejoinBtn.AutoButtonColor = true
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 13
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.Text = "Rejoin Server"
rejoinBtn.Parent = footer
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 8)
rejoinBtn.MouseButton1Click:Connect(tryRejoin)

-- KARTU AREA
local function createAreaCard(idx, data)
    local card = Instance.new("Frame")
    card.Name = "Area_" .. idx
    card.Size = UDim2.new(1, 0, 0, 58)
    card.BackgroundColor3 = Color3.fromRGB(230, 230, 244)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = list

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(200, 200, 225)
    stroke.Transparency = 0.3
    stroke.Parent = card

    local nameLower = string.lower(data.name)
    local isHG = nameLower:find("hg", 1, true) ~= nil
    if isHG then
        card.BackgroundColor3 = Color3.fromRGB(215, 235, 255)
        stroke.Color          = Color3.fromRGB(130, 170, 230)
    end

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -130, 0, 26)
    nameLabel.Position = UDim2.new(0, 10, 0, 6)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextColor3 = Color3.fromRGB(40, 40, 70)
    nameLabel.Text = data.name
    nameLabel.Parent = card

    local coordLabel = Instance.new("TextLabel")
    coordLabel.Name = "Coords"
    coordLabel.Size = UDim2.new(1, -130, 0, 20)
    coordLabel.Position = UDim2.new(0, 10, 0, 32)
    coordLabel.BackgroundTransparency = 1
    coordLabel.Font = Enum.Font.Code
    coordLabel.TextSize = 12
    coordLabel.TextXAlignment = Enum.TextXAlignment.Left
    coordLabel.TextColor3 = Color3.fromRGB(90, 90, 120)
    coordLabel.Text = string.format("(%.2f, %.2f, %.2f)", data.vec.X, data.vec.Y, data.vec.Z)
    coordLabel.Parent = card

    local tpBtn = Instance.new("TextButton")
    tpBtn.Name = "TPButton"
    tpBtn.Size = UDim2.new(0, 80, 0, 28)
    tpBtn.Position = UDim2.new(1, -88, 0.5, -14)
    tpBtn.BackgroundColor3 = Color3.fromRGB(80, 170, 120)
    tpBtn.AutoButtonColor = true
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.TextSize = 13
    tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpBtn.Text = "TP"
    tpBtn.Parent = card
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 10)

    tpBtn.MouseEnter:Connect(function()
        TweenService:Create(tpBtn, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            BackgroundColor3 = Color3.fromRGB(95, 190, 140)
        }):Play()
    end)
    tpBtn.MouseLeave:Connect(function()
        TweenService:Create(tpBtn, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            BackgroundColor3 = Color3.fromRGB(80, 170, 120)
        }):Play()
    end)
    tpBtn.MouseButton1Click:Connect(function()
        teleportTo(data.vec)
    end)

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                local text = string.format("Vector3.new(%.2f, %.2f, %.2f)", data.vec.X, data.vec.Y, data.vec.Z)
                safeSetClipboard(text, data.name)
            end
        end
    end)

    card.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            BackgroundColor3 = card.BackgroundColor3:lerp(Color3.fromRGB(255, 255, 255), 0.08)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Thickness = 2,
            Transparency = 0.1
        }):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            BackgroundColor3 = isHG and Color3.fromRGB(215, 235, 255) or Color3.fromRGB(230, 230, 244)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Thickness = 1,
            Transparency = 0.3
        }):Play()
    end)
end

for i, area in ipairs(AREAS) do
    createAreaCard(i, area)
end

infoLabel.Text = string.format("Total area: %d  |  SHIFT + klik = copy Vector3", #AREAS)
