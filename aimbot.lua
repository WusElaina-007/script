--------------------------------
-- CẤU HÌNH VÀ BIẾN TOÀN CỤC
--------------------------------
local fov = 100
local fovLevels = {10, 40, 50, 70, 90, 100, 130, 150, 170, 200}
local fovIndex = 6
local teamCheck = true
local aimbotEnabled = false
local espEnabled = false
local hitboxEnabled = false
local triggerEnabled = false
local noRecoilEnabled = false
local silentAimEnabled = false
local autoReloadEnabled = false
local aimSmoothness = 0.3
local hitboxSize = 5

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--------------------------------
-- VẼ FOV RING (Drawing API)
--------------------------------
local FOVring = Drawing.new("Circle")
FOVring.Visible = true
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128)
FOVring.Filled = false
FOVring.Radius = fov
FOVring.Position = Vector2.new(0, 0)

local function updateFOVRing()
    if Camera and Camera.ViewportSize then
        FOVring.Radius = fov
        FOVring.Position = Camera.ViewportSize / 2
    end
end

--------------------------------
-- HÀM HỖ TRỢ
--------------------------------
local function isPlayerAlive(player)
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function isEnemy(player)
    if not teamCheck then return true end
    if player == LocalPlayer then return false end
    local localTeam = LocalPlayer.Team
    local playerTeam = player.Team
    return not (localTeam and playerTeam and localTeam == playerTeam)
end

local function canSeeTarget(targetPos)
    local origin = Camera.CFrame.Position
    local direction = (targetPos - origin).Unit * (targetPos - origin).Magnitude
    local ray = Ray.new(origin, direction)
    local hit, pos = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character or {}})
    return hit == nil or (pos - targetPos).Magnitude < 1
end

local function getClosestEnemy()
    local closest = nil
    local shortestDist = math.huge
    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemy(player) and isPlayerAlive(player) then
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if dist < fov and dist < shortestDist and (not silentAimEnabled or canSeeTarget(head.Position)) then
                        shortestDist = dist
                        closest = head
                    end
                end
            end
        end
    end
    return closest
end

local function aimAt(targetPos)
    if targetPos then
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
        Camera.CFrame = currentCFrame:Lerp(targetCFrame, aimSmoothness)
    end
end

local function isMouseOverEnemy()
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemy(player) and isPlayerAlive(player) then
            local head = player.Character and player.Character:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen and (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude < 20 then
                    return true
                end
            end
        end
    end
    return false
end

--------------------------------
-- ESP (LINE, BOX, HEALTH BAR)
--------------------------------
local espLines = {}
local espBoxes = {}
local espHealthBars = {}

local function updateESP()
    for _, line in ipairs(espLines) do line:Remove() end
    for _, box in ipairs(espBoxes) do box:Remove() end
    for _, bar in ipairs(espHealthBars) do bar:Remove() end
    table.clear(espLines)
    table.clear(espBoxes)
    table.clear(espHealthBars)

    if espEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isEnemy(player) and isPlayerAlive(player) then
                local char = player.Character
                local humanoid = char and char:FindFirstChild("Humanoid")
                local rootPart = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                if rootPart and head and humanoid then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local line = Drawing.new("Line")
                        line.Visible = true
                        line.Color = Color3.fromRGB(255, 0, 0)
                        line.Thickness = 1.5
                        line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        line.To = Vector2.new(screenPos.X, screenPos.Y)
                        table.insert(espLines, line)

                        local topPos = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0))
                        local bottomPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                        if topPos.Z > 0 and bottomPos.Z > 0 then
                            local boxWidth = 40
                            local box = Drawing.new("Square")
                            box.Visible = true
                            box.Color = Color3.fromRGB(0, 255, 0)
                            box.Thickness = 2
                            box.Filled = false
                            box.Size = Vector2.new(boxWidth, (bottomPos.Y - topPos.Y))
                            box.Position = Vector2.new(topPos.X - boxWidth / 2, topPos.Y)
                            table.insert(espBoxes, box)

                            local healthPercent = humanoid.Health / humanoid.MaxHealth
                            local bar = Drawing.new("Line")
                            bar.Visible = true
                            bar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                            bar.Thickness = 3
                            bar.From = Vector2.new(topPos.X + boxWidth / 2 + 5, topPos.Y)
                            bar.To = Vector2.new(topPos.X + boxWidth / 2 + 5, topPos.Y + (bottomPos.Y - topPos.Y) * healthPercent)
                            table.insert(espHealthBars, bar)
                        end
                    end
                end
            end
        end
    end
end

--------------------------------
-- HITBOX EXPANDER
--------------------------------
local function updateHitbox()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemy(player) and isPlayerAlive(player) then
            local head = player.Character and player.Character:FindFirstChild("Head")
            if head then
                head.Size = hitboxEnabled and Vector3.new(hitboxSize, hitboxSize, hitboxSize) or Vector3.new(1, 1, 1)
                head.CanCollide = false
            end
        end
    end
end

--------------------------------
-- NO RECOIL
--------------------------------
local function applyNoRecoil()
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid and noRecoilEnabled then
        humanoid.CameraOffset = Vector3.new(0, 0, 0)
    end
end

--------------------------------
-- SILENT AIM
--------------------------------
local function applySilentAim()
    if silentAimEnabled then
        local target = getClosestEnemy()
        if target then
            local ray = Ray.new(Camera.CFrame.Position, (target.Position - Camera.CFrame.Position).Unit * 1000)
            local ignoreList = {LocalPlayer.Character}
            local hit, pos = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
            if hit and hit.Parent:FindFirstChild("Humanoid") then
                -- Silent aim không thay đổi camera
            end
        end
    end
end

--------------------------------
-- AUTO RELOAD
--------------------------------
local function applyAutoReload()
    if autoReloadEnabled then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            local ammo = tool:FindFirstChild("Ammo") or tool:FindFirstChild("Clip")
            if ammo and ammo.Value <= 0 then
                tool:Activate()
            end
        end
    end
end

--------------------------------
-- TẠO MENU GUI NGANG VỚI BACKGROUND VÀ ICON
--------------------------------
local CoreGui = game:GetService("CoreGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimbotESP_Menu"
screenGui.Parent = CoreGui
screenGui.ResetOnSpawn = false

-- Nút mở/đóng menu với icon
local openButton = Instance.new("ImageButton") -- Dùng ImageButton thay TextButton
openButton.Size = UDim2.new(0, 50, 0, 50)
openButton.Position = UDim2.new(0, 10, 0, 10)
openButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
openButton.Image = "rbxassetid://87203291544706" -- Thay bằng ID icon của Oni Chan~~
openButton.Parent = screenGui
openButton.Active = true
openButton.Draggable = true

-- Frame menu ngang
local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 600, 0, 80) -- Nằm ngang, dài 600, cao 80
menuFrame.Position = UDim2.new(0, 100, 0, 100)
menuFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
menuFrame.BorderSizePixel = 2
menuFrame.BorderColor3 = Color3.fromRGB(0, 255, 255)
menuFrame.Parent = screenGui
menuFrame.Visible = false
menuFrame.Active = true
menuFrame.Draggable = true

-- Background ảnh cho menu
local backgroundImage = Instance.new("ImageLabel")
backgroundImage.Size = UDim2.new(1, 0, 1, 0)
backgroundImage.Position = UDim2.new(0, 0, 0, 0)
backgroundImage.BackgroundTransparency = 1
backgroundImage.Image = "rbxassetid://YOUR_BACKGROUND_ID_HERE" -- Thay bằng ID ảnh background
backgroundImage.Parent = menuFrame
backgroundImage.ZIndex = 0 -- Để nút đè lên ảnh

-- Hàm tạo nút trong menu ngang
local function createMenuButton(text, posX, toggleVar)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 60) -- Nhỏ gọn, nằm ngang
    btn.Position = UDim2.new(0, posX, 0, 10)
    btn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 14
    btn.Parent = menuFrame
    btn.ZIndex = 1 -- Đè lên background
    btn.MouseButton1Click:Connect(function()
        if toggleVar == "fov" then
            fovIndex = (fovIndex % #fovLevels) + 1
            fov = fovLevels[fovIndex]
            btn.Text = "FOV: " .. tostring(fov)
        else
            _G[toggleVar] = not _G[toggleVar]
            btn.Text = text:match("^[^:]+") .. ": " .. (_G[toggleVar] and "ON" or "OFF")
            btn.BackgroundColor3 = _G[toggleVar] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        end
    end)
    return btn
end

-- Toggle menu
local menuVisible = false
openButton.MouseButton1Click:Connect(function()
    menuVisible = not menuVisible
    menuFrame.Visible = menuVisible
end)

-- Gán biến toàn cục
_G.aimbotEnabled = aimbotEnabled
_G.espEnabled = espEnabled
_G.hitboxEnabled = hitboxEnabled
_G.triggerEnabled = triggerEnabled
_G.noRecoilEnabled = noRecoilEnabled
_G.silentAimEnabled = silentAimEnabled
_G.autoReloadEnabled = autoReloadEnabled

-- Tạo các nút nằm ngang
createMenuButton("Aimbot: OFF", 10, "aimbotEnabled")
createMenuButton("ESP: OFF", 90, "espEnabled")
createMenuButton("FOV: "..fov, 170, "fov")
createMenuButton("Hitbox: OFF", 250, "hitboxEnabled")
createMenuButton("Trigger: OFF", 330, "triggerEnabled")
createMenuButton("No Recoil: OFF", 410, "noRecoilEnabled")
createMenuButton("Silent: OFF", 490, "silentAimEnabled")
createMenuButton("Reload: OFF", 570, "autoReloadEnabled")

--------------------------------
-- XỬ LÝ KHI PLAYER RESPAWN
--------------------------------
LocalPlayer.CharacterAdded:Connect(function()
    Camera = Workspace.CurrentCamera
end)

--------------------------------
-- VÒNG LẶP CHÍNH
--------------------------------
RunService.RenderStepped:Connect(function()
    if not Camera or not LocalPlayer.Character then return end
    
    aimbotEnabled = _G.aimbotEnabled
    espEnabled = _G.espEnabled
    hitboxEnabled = _G.hitboxEnabled
    triggerEnabled = _G.triggerEnabled
    noRecoilEnabled = _G.noRecoilEnabled
    silentAimEnabled = _G.silentAimEnabled
    autoReloadEnabled = _G.autoReloadEnabled

    updateFOVRing()
    
    if aimbotEnabled then
        local target = getClosestEnemy()
        if target then
            aimAt(target.Position)
        end
    end
    
    updateESP()
    updateHitbox()
    applyNoRecoil()
    applySilentAim()
    applyAutoReload()
    
    if triggerEnabled and isMouseOverEnemy() then
        mouse1press()
        wait(0.05)
        mouse1release()
    end
end)
