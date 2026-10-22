--// Hemlock Main
--// Universal Da Hood Cheat
--// Supports: Da Hood | Das Hood | Der Hood | Des Hood | Zee Hood

--// Services
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Locals
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()
local Config      = shared.Hemlock

--// Utility
local Util = {}

function Util.GetChar(player)
    return player and player.Character
end

function Util.GetHum(player)
    local c = Util.GetChar(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Util.IsAlive(player)
    local h = Util.GetHum(player)
    return h and h.Health > 0
end

function Util.GetRoot(player)
    local c = Util.GetChar(player)
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Util.GetPart(player, partName)
    local c = Util.GetChar(player)
    if not c then return nil end
    return c:FindFirstChild(partName) or c:FindFirstChild("HumanoidRootPart")
end

function Util.ToScreen(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on, s.Z
end

function Util.Dist2D(a, b)
    return (a - b).Magnitude
end

function Util.GetClosestToCamera()
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not Util.IsAlive(p) then continue end
        local root = Util.GetRoot(p)
        if not root then continue end
        local d = (root.Position - Camera.CFrame.Position).Magnitude
        if d < Config['Silent Aim']['Distance'] and d < bestDist then
            bestDist = d
            best = p
        end
    end
    return best, bestDist
end

function Util.GetClosestToMouse()
    local best, bestDist = nil, math.huge
    local mp = Vector2.new(Mouse.X, Mouse.Y)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not Util.IsAlive(p) then continue end
        local root = Util.GetRoot(p)
        if not root then continue end
        local sp, on = Util.ToScreen(root.Position)
        if not on then continue end
        local d = Util.Dist2D(mp, sp)
        if d < bestDist then
            bestDist = d
            best = p
        end
    end
    return best, bestDist
end

function Util.GetBoundingBox(character)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false
    for _, part in ipairs(character:GetDescendants()) do
        if not part:IsA("BasePart") then continue end
        local sx = part.Size.X / 2
        local sy = part.Size.Y / 2
        local sz = part.Size.Z / 2
        local corners = {
            Vector3.new(-sx, -sy, -sz), Vector3.new( sx, -sy, -sz),
            Vector3.new(-sx,  sy, -sz), Vector3.new( sx,  sy, -sz),
            Vector3.new(-sx, -sy,  sz), Vector3.new( sx, -sy,  sz),
            Vector3.new(-sx,  sy,  sz), Vector3.new( sx,  sy,  sz),
        }
        for _, offset in ipairs(corners) do
            local worldPos = part.CFrame:PointToWorldSpace(offset)
            local sp, on = Camera:WorldToViewportPoint(worldPos)
            if on then
                visible = true
                minX = math.min(minX, sp.X)
                minY = math.min(minY, sp.Y)
                maxX = math.max(maxX, sp.X)
                maxY = math.max(maxY, sp.Y)
            end
        end
    end
    if not visible then return nil end
    return minX, minY, maxX - minX, maxY - minY
end

--// Silent Aim
local SilentAim = {}
SilentAim.Target  = nil
SilentAim.Enabled = Config['Silent Aim']['Enabled']

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if SilentAim.Enabled then
        local target = SilentAim.Target or Util.GetClosestToCamera()

        if target then
            local hitPart = Util.GetPart(target, Config['Silent Aim']['Hit Part'])
            if hitPart then
                if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                    local ray = args[1]
                    if ray then
                        args[1] = Ray.new(
                            ray.Origin,
                            (hitPart.Position - ray.Origin).Unit * ray.Direction.Magnitude
                        )
                        return oldNamecall(self, table.unpack(args))
                    end
                end
                if method == "Raycast" then
                    local origin    = args[1]
                    local direction = args[2]
                    if origin and direction then
                        args[2] = (hitPart.Position - origin).Unit * direction.Magnitude
                        return oldNamecall(self, table.unpack(args))
                    end
                end
            end
        end
    end

    return oldNamecall(self, ...)
end)

--// ESP
local ESP = {}
ESP.Objects = {}

local function NewDrawing(kind, props)
    local d = Drawing.new(kind)
    for k, v in pairs(props) do d[k] = v end
    return d
end

function ESP.Add(player)
    if player == LocalPlayer then return end
    ESP.Objects[player] = {
        Box = NewDrawing("Square", {
            Visible   = false,
            Color     = Config['ESP']['Colors']['Default'],
            Thickness = 1,
            Filled    = false,
        }),
        BoxFill = NewDrawing("Square", {
            Visible      = false,
            Color        = Color3.fromRGB(255, 255, 255),
            Transparency = 0.85,
            Filled       = true,
        }),
        Name = NewDrawing("Text", {
            Visible      = false,
            Color        = Config['ESP']['Colors']['Name'],
            Size         = Config['ESP']['Text Size'],
            Center       = true,
            Outline      = true,
            OutlineColor = Color3.new(0, 0, 0),
            Font         = Drawing.Fonts.Plex,
        }),
        HealthBG = NewDrawing("Square", {
            Visible   = false,
            Color     = Color3.fromRGB(30, 30, 30),
            Filled    = true,
            Thickness = 1,
        }),
        HealthBar = NewDrawing("Square", {
            Visible   = false,
            Color     = Color3.fromRGB(0, 255, 0),
            Filled    = true,
            Thickness = 1,
        }),
        DistText = NewDrawing("Text", {
            Visible      = false,
            Color        = Config['ESP']['Colors']['Distance'],
            Size         = 11,
            Center       = true,
            Outline      = true,
            OutlineColor = Color3.new(0, 0, 0),
            Font         = Drawing.Fonts.Plex,
        }),
    }
end

function ESP.Remove(player)
    if not ESP.Objects[player] then return end
    for _, d in pairs(ESP.Objects[player]) do d:Remove() end
    ESP.Objects[player] = nil
end

function ESP.Update()
    for player, d in pairs(ESP.Objects) do
        local char  = Util.GetChar(player)
        local hum   = Util.GetHum(player)
        local root  = Util.GetRoot(player)
        local alive = char and hum and root and hum.Health > 0

        if not Config['ESP']['Enabled'] or not alive then
            for _, dr in pairs(d) do dr.Visible = false end
            continue
        end

        local camDist = (root.Position - Camera.CFrame.Position).Magnitude
        if camDist > Config['ESP']['MaxDistance'] then
            for _, dr in pairs(d) do dr.Visible = false end
            continue
        end

        local x, y, w, h = Util.GetBoundingBox(char)
        if not x then
            for _, dr in pairs(d) do dr.Visible = false end
            continue
        end

        local col = (SilentAim.Target == player)
            and Config['ESP']['Colors']['Target']
            or  Config['ESP']['Colors']['Default']

        local healthPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        local barH      = h * healthPct
        local hColor    = Color3.fromRGB(
            math.floor(255 * (1 - healthPct)),
            math.floor(255 * healthPct),
            0
        )

        d.Box.Visible   = Config['ESP']['Boxes']
        d.Box.Position  = Vector2.new(x, y)
        d.Box.Size      = Vector2.new(w, h)
        d.Box.Color     = col

        d.BoxFill.Visible  = Config['ESP']['Boxes']
        d.BoxFill.Position = Vector2.new(x, y)
        d.BoxFill.Size     = Vector2.new(w, h)

        d.Name.Visible  = Config['ESP']['Names']
        d.Name.Position = Vector2.new(x + w / 2, y - 16)
        d.Name.Text     = player.DisplayName .. " [" .. player.Name .. "]"
        d.Name.Color    = col

        d.HealthBG.Visible  = Config['ESP']['Health']
        d.HealthBG.Position = Vector2.new(x - 6, y)
        d.HealthBG.Size     = Vector2.new(4, h)

        d.HealthBar.Visible  = Config['ESP']['Health']
        d.HealthBar.Position = Vector2.new(x - 6, y + (h - barH))
        d.HealthBar.Size     = Vector2.new(4, barH)
        d.HealthBar.Color    = hColor

        d.DistText.Visible  = Config['ESP']['Distance']
        d.DistText.Position = Vector2.new(x + w / 2, y + h + 3)
        d.DistText.Text     = string.format("[%dm]", math.floor(camDist))
    end
end

for _, p in ipairs(Players:GetPlayers()) do ESP.Add(p) end
Players.PlayerAdded:Connect(ESP.Add)
Players.PlayerRemoving:Connect(ESP.Remove)

--// Hitbox Expander
local HitboxExpander = {}
HitboxExpander.Applied = {}

function HitboxExpander.Apply(player)
    if not Config['Hitbox Expander']['Enabled'] then return end
    local char = Util.GetChar(player)
    if not char then return end
    local root = Util.GetRoot(player)
    if not root then return end
    local dist = (root.Position - Camera.CFrame.Position).Magnitude
    if dist > Config['Hitbox Expander']['Range'] then return end

    for _, partName in ipairs(Config['Hitbox Expander']['ApplyTo']) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            if Config['Hitbox Expander']['Method'] == 'Size' then
                part.Size = Vector3.new(
                    Config['Hitbox Expander']['Size'],
                    Config['Hitbox Expander']['Size'],
                    Config['Hitbox Expander']['Size']
                )
                part.Transparency = Config['Hitbox Expander']['Transparency']
            elseif Config['Hitbox Expander']['Method'] == 'SelectionBox' then
                local existing = part:FindFirstChild("HmlkHitbox")
                if not existing then
                    local sb = Instance.new("SelectionBox")
                    sb.Name      = "HmlkHitbox"
                    sb.Adornee   = part
                    sb.Color3    = Color3.fromRGB(255, 0, 0)
                    sb.LineThickness = 0
                    sb.SurfaceTransparency = 1
                    sb.Parent    = part
                end
            end
        end
    end
    HitboxExpander.Applied[player] = true
end

function HitboxExpander.Remove(player)
    local char = Util.GetChar(player)
    if not char then return end
    for _, partName in ipairs(Config['Hitbox Expander']['ApplyTo']) do
        local part = char:FindFirstChild(partName)
        if part then
            local sb = part:FindFirstChild("HmlkHitbox")
            if sb then sb:Destroy() end
        end
    end
    HitboxExpander.Applied[player] = nil
end

--// Player Mods
local function ApplyCharMods(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end

    if Config['Player Modifications']['Anti Trip'] then
        hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
    end

    if Config['Player Modifications']['Anti Jump Cooldown'] then
        hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Landed then
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end
        end)
    end

    if Config['Player Modifications']['Anti Stomp'] then
        hum.HealthChanged:Connect(function(hp)
            if hp <= 0 then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part:Destroy() end)
                    end
                end
            end
        end)
    end
end

if LocalPlayer.Character then ApplyCharMods(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    ApplyCharMods(char)
    if Config['Hitbox Expander']['Apply Respawn'] then
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            HitboxExpander.Apply(p)
        end
    end
end)

--// Fly
local Fly = {}
Fly.Enabled  = false
Fly.Velocity = nil
Fly.Gyro     = nil

function Fly.Enable()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    Fly.Velocity = Instance.new("BodyVelocity")
    Fly.Velocity.Velocity = Vector3.zero
    Fly.Velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    Fly.Velocity.Parent   = root

    Fly.Gyro = Instance.new("BodyGyro")
    Fly.Gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    Fly.Gyro.D         = 100
    Fly.Gyro.Parent    = root

    Fly.Enabled = true
end

function Fly.Disable()
    if Fly.Velocity then Fly.Velocity:Destroy() Fly.Velocity = nil end
    if Fly.Gyro     then Fly.Gyro:Destroy()     Fly.Gyro     = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    Fly.Enabled = false
end

function Fly.Update()
    if not Fly.Enabled or not Fly.Velocity or not Fly.Gyro then return end
    local speed = Config['Player Modifications']['Flying']['Speed']
    local dir   = Vector3.zero
    Fly.Gyro.CFrame = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
    Fly.Velocity.Velocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero
end

--// Wall Hop
if Config['Player Modifications']['Wall Hop']['Enabled'] then
    UserInputService.JumpRequest:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if hum:GetState() ~= Enum.HumanoidStateType.Freefall then return end
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.new(
            root.AssemblyLinearVelocity.X,
            Config['Player Modifications']['Wall Hop']['Jump Strength'],
            root.AssemblyLinearVelocity.Z
        )
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.P        = math.huge
        bv.Parent   = root
        game:GetService("Debris"):AddItem(bv, 0.12)
    end)
end

--// Trigger Bot
local TBot = {}
TBot.Active   = false
TBot.LastFire = 0

function TBot.TryFire()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local fired = false
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("fire") or v.Name:lower():find("shoot")) then
            pcall(function() v:FireServer() end)
            fired = true
            break
        end
    end
    if not fired then
        pcall(function() tool:Activate() end)
        pcall(function() mouse1click() end)
    end
end

--// Aim Assist
local AimAssist = {}

function AimAssist.Update()
    if not Config['Aim Assist']['Enabled'] then return end
    local target, _ = Util.GetClosestToMouse()
    if not target then return end
    local part = Util.GetPart(target, Config['Aim Assist']['Hit Part'])
    if not part then return end
    local sp, on = Util.ToScreen(part.Position)
    if not on then return end
    local mp = Vector2.new(Mouse.X, Mouse.Y)
    if Util.Dist2D(mp, sp) > Config['Aim Assist']['FOV'] then return end
    local smooth = Config['Aim Assist']['Smoothness']
    local newX   = mp.X + (sp.X - mp.X) * smooth
    local newY   = mp.Y + (sp.Y - mp.Y) * smooth
    mousemoverel(newX - mp.X, newY - mp.Y)
end

--// Safety
if Config['Safety Mode']['Report Detector']['Enabled'] then
    task.spawn(function()
        local reportNames = {"Report", "ReportPlayer", "PlayerReport", "SendReport"}
        for _, name in ipairs(reportNames) do
            local remote = ReplicatedStorage:FindFirstChild(name, true)
            if remote and remote:IsA("RemoteEvent") then
                remote.OnClientEvent:Connect(function(reporter)
                    warn("[Hemlock] Report detected from: " .. tostring(reporter))
                    if Config['Safety Mode']['Report Detector']['Auto Kick'] then
                        LocalPlayer:Kick("[Hemlock] Auto-kicked: report detected")
                    end
                end)
            end
        end
    end)
end

--// Keybinds
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = input.KeyCode.Name

    if key == Config['General']['Binds']['Panic'] then
        SilentAim.Enabled                        = false
        TBot.Active                               = false
        Config['ESP']['Enabled']                  = false
        Config['Aim Assist']['Enabled']           = false
        Config['Hitbox Expander']['Enabled']      = false
        Fly.Disable()
        LocalPlayer:Kick("[Hemlock] Panic activated")
        return
    end

    if key == Config['General']['Binds']['Fly'] then
        if Fly.Enabled then Fly.Disable() else Fly.Enable() end
    end

    if key == Config['General']['Binds']['ESP'] then
        Config['ESP']['Enabled'] = not Config['ESP']['Enabled']
    end

    if key == Config['General']['Binds']['Silent Aim Target'] then
        SilentAim.Enabled = not SilentAim.Enabled
    end

    if key == Config['General']['Binds']['Trigger Bot'] then
        TBot.Active = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if input.KeyCode.Name == Config['General']['Binds']['Trigger Bot'] then
        TBot.Active = false
    end
end)

--// Main Loop
RunService.RenderStepped:Connect(function()
    -- Silent Aim target update
    if SilentAim.Enabled then
        SilentAim.Target = Util.GetClosestToCamera()
    end

    -- ESP
    ESP.Update()

    -- Fly
    if Fly.Enabled then Fly.Update() end

    -- Aim Assist
    AimAssist.Update()

    -- Speed
    if Config['Player Modifications']['Speed']['Enabled'] then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = Config['Player Modifications']['Speed']['Default']['Value'] end
        end
    end

    -- Trigger Bot
    if TBot.Active and Config['Trigger Bot']['Enabled'] then
        local now = tick()
        if now - TBot.LastFire >= Config['Trigger Bot']['Cooldown'] then
            local target, dist = Util.GetClosestToMouse()
            local fovSize = Config['Trigger Bot']['FOV']['2D']['X'] or 50
            if target and dist <= fovSize then
                TBot.TryFire()
                TBot.LastFire = now
            end
        end
    end

    -- Hitbox Expander
    if Config['Hitbox Expander']['Enabled'] then
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if Config['Hitbox Expander']['Link'] and SilentAim.Target ~= p then continue end
            if not HitboxExpander.Applied[p] then
                HitboxExpander.Apply(p)
            end
        end
    end
end)

-- Apply hitbox on join
Players.PlayerAdded:Connect(function(p)
    ESP.Add(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
        HitboxExpander.Applied[p] = nil
        HitboxExpander.Apply(p)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    ESP.Remove(p)
    HitboxExpander.Applied[p] = nil
end)

print("[Hemlock] Loaded successfully")
