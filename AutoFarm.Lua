-- Auto Farm Build A Boat (compacto)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local genv = (getgenv and getgenv()) or _G
genv.__BoatFarmId = (genv.__BoatFarmId or 0) + 1
local myId = genv.__BoatFarmId

-- ========== CONFIG ==========
local CFG = {
    X = 70.02417755126953,
    Y = 138.9026336669922,
    Z0 = 1371.6342,
    STEP = 770,
    SPAWN_DELAY = 1.5,
    END_DELAY = 1.45,
    PLATFORM = true,
    PLATFORM_Y = 136.9,
    CHEST_STEP = 4,
    CHEST_HOLD = 0.6,
    FIRST_STAGE_WAIT = 1.0,
}

local steps = {
    {pre = true,  w = 5.03},
    {pre = true,  w = 1.97},
    {pre = true,  w = 2.10},
    {pre = false, w = 0.51, post = true, w2 = 1.47},
    {pre = true,  w = 2.00},
    {pre = true,  w = 2.01},
    {pre = true,  w = 2.02},
    {pre = true,  w = 2.57},
    {pre = true,  w = CFG.END_DELAY},
}

local running = false
local needReset = false

-- ========== Estadísticas ==========
local goldVal, blockVal
pcall(function()
    local data = lp:WaitForChild("Data", 10)
    goldVal = data:WaitForChild("Gold", 10)
    blockVal = data:WaitForChild("GoldBlock", 10)
end)

local gained, gainedBlocks = 0, 0
local accTime, runStart = 0, 0
local lastGold = goldVal and goldVal.Value or 0
local lastBlock = blockVal and blockVal.Value or 0

if goldVal then
    goldVal:GetPropertyChangedSignal("Value"):Connect(function()
        if genv.__BoatFarmId ~= myId then return end
        local delta = goldVal.Value - lastGold
        lastGold = goldVal.Value
        if running and delta > 0 then gained += delta end
    end)
end
if blockVal then
    blockVal:GetPropertyChangedSignal("Value"):Connect(function()
        if genv.__BoatFarmId ~= myId then return end
        local delta = blockVal.Value - lastBlock
        lastBlock = blockVal.Value
        if running and delta > 0 then gainedBlocks += delta end
    end)
end

local function elapsed()
    return accTime + (running and (tick() - runStart) or 0)
end

local function fmt(n)
    n = math.floor(n + 0.5)
    local s = tostring(n)
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

local function fmtK(n)
    if n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

local function fmtTime(sec)
    sec = math.floor(sec)
    return string.format("%02dh %02dm %02ds", sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- ========== Utilidad de Movimiento ==========
local function restoreMovement()
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.JumpHeight = 7.2
            hum.AutoRotate = true
        end)
    end
end

local function disableMovement(hum)
    if hum then
        pcall(function()
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum.AutoRotate = false
        end)
    end
end

-- ========== GUI ==========
local parent = (gethui and gethui()) or game:GetService("CoreGui")
local old = parent:FindFirstChild("BoatFarm")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "BoatFarm"
gui.ResetOnSpawn = false
gui.Parent = parent

-- colores puros
local NEGRO   = Color3.fromRGB(0, 0, 0)
local CARD    = Color3.fromRGB(14, 14, 14)
local BORDE   = Color3.fromRGB(70, 70, 70)
local BLANCO  = Color3.fromRGB(255, 255, 255)
local GRIS    = Color3.fromRGB(160, 160, 160)
local BTNGRIS = Color3.fromRGB(45, 45, 45)

local BASE_W, BASE_H, BAR_H = 230, 266, 28

local function corner(o, r)
    Instance.new("UICorner", o).CornerRadius = UDim.new(0, r)
end
local function stroke(o)
    local s = Instance.new("UIStroke")
    s.Color = BORDE
    s.Thickness = 1
    s.Parent = o
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
main.Position = UDim2.new(0, 12, 0.5, -BASE_H / 2)
main.BackgroundColor3 = NEGRO
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
corner(main, 10)
stroke(main)

local scale = Instance.new("UIScale")
scale.Scale = 1
scale.Parent = main

-- barra de título
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, BAR_H)
title.BackgroundTransparency = 1
title.Text = "Auto Farm"
title.TextColor3 = BLANCO
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Active = true
title.Parent = main

local function barBtn(text, x, color, txtColor)
    local b = Instance.new("TextButton")
    b.Position = x
    b.Size = UDim2.new(0, 24, 0, 20)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = txtColor or BLANCO
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.BorderSizePixel = 0
    b.ZIndex = 3
    b.Parent = main
    corner(b, 5)
    return b
end

-- Botones: minimizar (gris), cerrar (blanco con texto negro)
local btnMin   = barBtn("-", UDim2.new(0, 4, 0, 4), BTNGRIS, BLANCO)
local btnClose = barBtn("X", UDim2.new(1, -28, 0, 4), BLANCO, NEGRO)

-- arrastrar desde el título
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- cuerpo
local body = Instance.new("Frame")
body.Position = UDim2.new(0, 0, 0, BAR_H)
body.Size = UDim2.new(1, 0, 1, -BAR_H)
body.BackgroundTransparency = 1
body.Parent = main

local function label(p, text, x, y, w, h, size, color, font, align)
    local l = Instance.new("TextLabel")
    l.Position = UDim2.new(0, x, 0, y)
    l.Size = UDim2.new(0, w, 0, h)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.Font = font
    l.TextSize = size
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = p
    return l
end

local card = Instance.new("Frame")
card.Position = UDim2.new(0, 6, 0, 2)
card.Size = UDim2.new(1, -12, 0, 176)
card.BackgroundColor3 = CARD
card.BorderSizePixel = 0
card.Parent = body
corner(card, 8)
stroke(card)

label(card, "MÉTRICAS DE FARMEO", 10, 7, 190, 16, 11, BLANCO, Enum.Font.GothamBold)
label(card, "Duración de sesión", 12, 28, 100, 14, 10, BLANCO, Enum.Font.Gotham)
local lblTime = label(card, "00h 00m 00s", 108, 28, 98, 14, 11, BLANCO, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

local function makeBox(x, y, name, color)
    local box = Instance.new("Frame")
    box.Position = UDim2.new(0, x, 0, y)
    box.Size = UDim2.new(0, 97, 0, 56)
    box.BackgroundColor3 = CARD
    box.BorderSizePixel = 0
    box.Parent = card
    corner(box, 6)
    stroke(box)
    label(box, name, 8, 6, 84, 12, 10, BLANCO, Enum.Font.Gotham)
    local v = label(box, "0", 8, 24, 84, 24, 15, color, Enum.Font.GothamBold)
    v.TextScaled = true
    local c = Instance.new("UITextSizeConstraint")
    c.MaxTextSize = 16
    c.MinTextSize = 8
    c.Parent = v
    return v
end

local lblGold  = makeBox(6, 50, "Oro ganado", BLANCO)
local lblBlock = makeBox(105, 50, "Bloques de oro", BLANCO)
local lblHour  = makeBox(6, 112, "Ritmo / Hora", BLANCO)
local lblDay   = makeBox(105, 112, "Ritmo / 24 Horas", BLANCO)

-- Botón principal (Iniciar: blanco con texto negro, Detener: gris oscuro con texto blanco)
local btn = Instance.new("TextButton")
btn.Position = UDim2.new(0, 6, 0, 184)
btn.Size = UDim2.new(1, -12, 0, 32)
btn.BackgroundColor3 = BLANCO
btn.Text = "Iniciar"
btn.TextColor3 = NEGRO
btn.Font = Enum.Font.GothamBold
btn.TextSize = 13
btn.BorderSizePixel = 0
btn.Parent = body
corner(btn, 6)

btn.MouseButton1Click:Connect(function()
    if not running then
        running = true
        needReset = true
        runStart = tick()
        lastGold = goldVal and goldVal.Value or lastGold
        lastBlock = blockVal and blockVal.Value or lastBlock
        btn.Text = "Detener"
        btn.BackgroundColor3 = BTNGRIS
        btn.TextColor3 = BLANCO
    else
        accTime += tick() - runStart
        running = false
        restoreMovement() -- Restaurar movimiento al detener
        btn.Text = "Iniciar"
        btn.BackgroundColor3 = BLANCO
        btn.TextColor3 = NEGRO
    end
end)

-- minimizar
local minimized = false
local handle
do
    local down, moved, startPos, startMain
    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    btnMin.InputBegan:Connect(function(i)
        if isPress(i) then
            down, moved, startPos, startMain = true, false, i.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if down and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startPos
            if moved or d.Magnitude > 6 then
                moved = true
                main.Position = UDim2.new(startMain.X.Scale, startMain.X.Offset + d.X, startMain.Y.Scale, startMain.Y.Offset + d.Y)
            end
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if isPress(i) then down = false end
    end)
    btnMin.MouseButton1Click:Connect(function()
        if moved then return end
        minimized = not minimized
        body.Visible = not minimized
        title.Visible = not minimized
        btnClose.Visible = not minimized
        if handle then handle.Visible = not minimized end
        
        if minimized then
            main.Size = UDim2.new(0, 28, 0, 28)
            btnMin.Position = UDim2.new(0, 0, 0, 0)
            btnMin.Size = UDim2.new(0, 28, 0, 28)
            btnMin.Text = "+"
            main.BackgroundTransparency = 1
            if main:FindFirstChild("UIStroke") then main.UIStroke.Enabled = false end
        else
            main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
            btnMin.Position = UDim2.new(0, 4, 0, 4)
            btnMin.Size = UDim2.new(0, 24, 0, 20)
            btnMin.Text = "-"
            main.BackgroundTransparency = 0
            if main:FindFirstChild("UIStroke") then main.UIStroke.Enabled = true end
        end
    end)
end

-- cerrar
local platform
local function clearPlatform()
    if platform then platform:Destroy() platform = nil end
end
btnClose.MouseButton1Click:Connect(function()
    running = false
    genv.__BoatFarmId = (genv.__BoatFarmId or 0) + 1
    clearPlatform()
    restoreMovement() -- Restaurar movimiento al cerrar
    gui:Destroy()
end)

-- redimensionar
handle = Instance.new("Frame")
handle.Size = UDim2.new(0, 18, 0, 18)
handle.Position = UDim2.new(1, -20, 1, -20)
handle.BackgroundColor3 = BTNGRIS
handle.BorderSizePixel = 0
handle.Active = true
handle.ZIndex = 3
handle.Parent = main
corner(handle, 5)

local function gripLine(len, cx, cy)
    local l = Instance.new("Frame")
    l.Size = UDim2.new(0, len, 0, 2)
    l.Position = UDim2.new(0, cx - len / 2, 0, cy - 1)
    l.Rotation = -45
    l.BackgroundColor3 = BLANCO
    l.BorderSizePixel = 0
    l.ZIndex = 4
    l.Parent = handle
end
gripLine(12, 8, 8)
gripLine(6, 12, 12)

do
    local resizing, startPos, startScale
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            resizing, startPos, startScale = true, i.Position, scale.Scale
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startPos
            local s = startScale + ((d.X / BASE_W) + (d.Y / BASE_H)) / 2
            scale.Scale = math.clamp(s, 0.55, 1.6)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
end

-- actualizar panel
task.spawn(function()
    while genv.__BoatFarmId == myId do
        local t = elapsed()
        local rate = (t > 5) and (gained / t * 3600) or 0
        lblTime.Text = fmtTime(t)
        lblGold.Text = "+" .. fmt(gained)
        lblBlock.Text = "+" .. fmt(gainedBlocks) .. (gainedBlocks == 1 and " bloque" or " bloques")
        lblHour.Text = t > 5 and ("~" .. fmtK(rate) .. " /h") or "..."
        lblDay.Text = t > 5 and ("~" .. fmtK(rate * 24) .. " /24h") or "..."
        task.wait(0.5)
    end
end)

-- ========== Utilidades del farm ==========
local function setPlatform(z)
    if not CFG.PLATFORM then return end
    if not platform then
        platform = Instance.new("Part")
        platform.Anchored = true
        platform.CanCollide = true
        platform.Transparency = 1
        platform.Size = Vector3.new(40, 1, 40)
        platform.Name = "FarmPlatform"
    end
    platform.CFrame = CFrame.new(CFG.X, CFG.PLATFORM_Y, z)
    platform.Parent = workspace
end

local function claim()
    local r = workspace:FindFirstChild("ClaimRiverResultsGold")
    if r then pcall(function() r:FireServer() end) end
end

local function alive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return hum and root and hum.Health > 0 and char.Parent ~= nil
end

local function active(char)
    return genv.__BoatFarmId == myId and running and alive(char)
end

local function sleep(t, char)
    local t0 = tick()
    while tick() - t0 < t do
        if not active(char) then return false end
        task.wait(0.05)
    end
    return active(char)
end

local function touchFirstStage(root)
    pcall(function()
        local stages = workspace.BoatStages.NormalStages
        local st = stages:FindFirstChild("CaveStage1")
        if not st then return end
        local part = st:FindFirstChild("DarknessPart") or st:FindFirstChildWhichIsA("BasePart", true)
        if part and firetouchinterest then
            firetouchinterest(root, part, 0)
            task.wait()
            firetouchinterest(root, part, 1)
        end
    end)
end

local function pullChest(root)
    local ok, trig = pcall(function()
        return workspace.BoatStages.NormalStages.TheEnd.GoldenChest.Trigger
    end)
    if not (ok and trig) then return function() end end

    local original = trig.CFrame
    local conn
    pcall(function() trig.CanTouch = true end)
    conn = RunService.Heartbeat:Connect(function()
        if root and root.Parent and trig.Parent then
            trig.CFrame = root.CFrame
        end
    end)
    trig.CFrame = root.CFrame

    if firetouchinterest then
        pcall(function()
            firetouchinterest(root, trig, 0)
            task.wait()
            firetouchinterest(root, trig, 1)
        end)
    end

    return function()
        if conn then conn:Disconnect() conn = nil end
        pcall(function() trig.CFrame = original end)
    end
end

local function resetCharacter()
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.Health = 0 end) end
    local t0 = tick()
    local forced = false
    repeat
        task.wait(0.2)
        if not forced and char and lp.Character == char and tick() - t0 > 3 then
            forced = true
            pcall(function() char:BreakJoints() end)
        end
    until genv.__BoatFarmId ~= myId or not running
        or (lp.Character and lp.Character ~= char and alive(lp.Character))
        or tick() - t0 > 15
end

local function runCycle()
    if needReset then
        needReset = false
        resetCharacter()
        return
    end

    local char = lp.Character
    if not alive(char) then
        task.wait(0.5)
        return
    end
    local root = char.HumanoidRootPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    local restoreChest

    -- Bloquear movimiento del jugador mientras farmea
    disableMovement(hum)

    if not sleep(CFG.SPAWN_DELAY, char) then return end

    for i, s in ipairs(steps) do
        if not active(char) then
            if restoreChest then restoreChest() end
            clearPlatform()
            return
        end

        local z = CFG.Z0 + CFG.STEP * (i - 1)
        if s.pre then claim() end
        setPlatform(z)
        root.CFrame = CFrame.new(CFG.X, CFG.Y, z)
        root.AssemblyLinearVelocity = Vector3.zero

        local extra = 0
        if i == 1 then
            touchFirstStage(root)
            extra = CFG.FIRST_STAGE_WAIT
        end

        if i == CFG.CHEST_STEP then
            restoreChest = pullChest(root)
            if not sleep(CFG.CHEST_HOLD, char) then
                restoreChest() clearPlatform() return
            end
        end

        if not sleep(math.max(s.w - (i == CFG.CHEST_STEP and CFG.CHEST_HOLD or 0), 0) + extra, char) then
            if restoreChest then restoreChest() end
            clearPlatform()
            return
        end
        if s.post then
            claim()
            if not sleep(s.w2 or 0, char) then
                if restoreChest then restoreChest() end
                clearPlatform()
                return
            end
        end
        if i == CFG.CHEST_STEP and restoreChest then
            restoreChest()
            restoreChest = nil
        end
    end

    clearPlatform()
    hum.Health = 0

    local t0 = tick()
    repeat task.wait(0.2) until (lp.Character and lp.Character ~= char and alive(lp.Character))
        or tick() - t0 > 15 or genv.__BoatFarmId ~= myId
end

task.spawn(function()
    while genv.__BoatFarmId == myId do
        if running then
            local ok, err = pcall(runCycle)
            if not ok then
                warn("Error autofarm:", err)
                task.wait(1)
            end
        else
            task.wait(0.3)
        end
    end
    clearPlatform()
end)
