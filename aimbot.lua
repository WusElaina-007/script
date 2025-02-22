--------------------------------
-- CẤU HÌNH VÀ BIẾN TOÀN CỤC
--------------------------------
local fov = 100               -- Mặc định FOV
local fovLevels = {10, 40, 50, 70, 90, 100, 130, 150, 170, 200}
local fovIndex = 6            -- Ứng với giá trị 100
local teamCheck = true        -- Không aim đồng đội
local aimbotEnabled = false
local espEnabled = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--------------------------------
-- VẼ FOV RING (Drawing API)
--------------------------------
local FOVring = Drawing.new("Circle")
FOVring.Visible = true
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128)
FOVring.Filled = false                         -- Không tô kín
FOVring.Radius = fov
FOVring.Position = Camera.ViewportSize / 2

local function updateFOVRing()
    FOVring.Radius = fov
    FOVring.Position = Camera.ViewportSize / 2
end

--------------------------------
-- HÀM HỖ TRỢ
--------------------------------
-- Kiểm tra người chơi còn sống
local function isPlayerAlive(player)
    local char = player.Character
    return char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
end

-- Kiểm tra có phải kẻ địch hay không
local function isEnemy(player)
    if teamCheck then
        return player.Team ~= LocalPlayer.Team
    else
        return true
    end
end

-- Lấy địch gần nhất trong FOV
local function getClosestEnemy()
    local closest = nil
    local shortestDist = math.huge
    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemy(player) and isPlayerAlive(player) then
            local head = player.Character and player.Character:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if onScreen and dist < fov and dist < shortestDist then
                    shortestDist = dist
                    closest = head
                end
            end
        end
    end
    return closest
end

-- Aim camera về phía target
local function aimAt(target)
    if target then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target)
    end
end

--------------------------------
-- ESP LINE
--------------------------------
-- Lưu các đường line của ESP để xoá mỗi frame
local espLines = {}

local function updateESP()
    -- Xoá line cũ
    for _, line in ipairs(espLines) do
        line:Remove()
    end
    table.clear(espLines)

    -- Nếu ESP bật, vẽ line
    if espEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isEnemy(player) and isPlayerAlive(player) then
                local head = player.Character and player.Character:FindFirstChild("Head")
                if head then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local line = Drawing.new("Line")
                        line.Visible = true
                        line.Color = Color3.fromRGB(255, 0, 0)
                        line.Thickness = 1.5
                        -- Vẽ từ giữa cạnh dưới màn hình đến đầu địch
                        line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        line.To = Vector2.new(screenPos.X, screenPos.Y)
                        table.insert(espLines, line)
                    end
                end
            end
        end
    end
end

--------------------------------
-- TẠO UI (BUTTON DRAGGABLE)
--------------------------------
local CoreGui = game:GetService("CoreGui")

-- Tạo ScreenGui cha
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimbotESP_GUI"
screenGui.Parent = CoreGui

-- Hàm tạo button
local function createButton(initText, pos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 40)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = initText
    btn.Parent = screenGui
    btn.Active = true
    btn.Draggable = true
    return btn
end

-- Button Aimbot
local aimbotButton = createButton("Aimbot: OFF", UDim2.new(0, 50, 0, 50))
aimbotButton.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    if aimbotEnabled then
        aimbotButton.Text = "Aimbot: ON"
        aimbotButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    else
        aimbotButton.Text = "Aimbot: OFF"
        aimbotButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- Button ESP
local espButton = createButton("ESP: OFF", UDim2.new(0, 50, 0, 100))
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espButton.Text = "ESP: ON"
        espButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    else
        espButton.Text = "ESP: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- Button FOV
local fovButton = createButton("FOV: "..fov, UDim2.new(0, 50, 0, 150))
fovButton.MouseButton1Click:Connect(function()
    fovIndex = (fovIndex % #fovLevels) + 1
    fov = fovLevels[fovIndex]
    fovButton.Text = "FOV: "..tostring(fov)
end)

--------------------------------
-- VÒNG LẶP CHÍNH
--------------------------------
RunService.RenderStepped:Connect(function()
    -- Cập nhật vòng FOV
    updateFOVRing()
    -- Aimbot
    if aimbotEnabled then
        local target = getClosestEnemy()
        if target then
            aimAt(target.Position)
        end
    end
    -- Cập nhật ESP
    updateESP()
end)

