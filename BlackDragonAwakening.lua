--========================================================================
--  صحوة التنين الأسود | Black Dragon Awakening
--  مشهد سينمائي متكامل بأسلوب الفانتازيا المظلمة - Roblox (Luau)
--========================================================================
--  طريقة التركيب (مهم جدا):
--   1) افتح Roblox Studio وافتح مكان العمل بتاعك
--   2) من Explorer افتح: StarterPlayer ثم StarterPlayerScripts
--   3) كليك يمين على StarterPlayerScripts ثم Insert Object ثم LocalScript
--   4) امسح أي كود جوه الـ LocalScript والصق هذا الملف كامل من أوله لآخره
--   5) ضع نموذج التنين بتاعك في Workspace وسميه بالظبط: Dragon
--   6) اضغط Play واستمتع بالمشهد من البداية للنهاية
--
--  ملاحظات:
--   - السكربت يبني السماء والقلعة والباب والغرفة والمياه والمباني والكاميرا تلقائيا
--   - التنين نفسه هو موديلك انت (مش مبني من مكعبات)
--   - المشهد يجري على جهاز اللاعب (Client) وده الأنسب للاختبار الفردي والفيديوهات
--   - كل الأرقام المهمة موجودة في CONFIG تحت، عدل عليها براحتك
--========================================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local Debris       = game:GetService("Debris")
local Terrain      = workspace.Terrain

-- ده سكربت سينمائي يعمل على جهاز اللاعب، مش السيرفر
if not RunService:IsClient() then
        warn("[صحوة التنين] السكربت ده لازم يتحط كـ LocalScript جوه StarterPlayerScripts")
        return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--========================================================================
--  الإعدادات العامة - عدل من هنا براحتك
--========================================================================
local CONFIG = {
        DragonName     = "Dragon",  -- اسم نموذج التنين في Workspace
        DragonYaw      = 180,       -- لو التنين ظاهر بعكس الاتجاه غير الرقم (0 / 90 / 180 / 270)
        DragonWaitTime = 60,        -- أقصى مدة انتظار لنموذج التنين بالثواني

        DoorOpenTime   = 9,         -- زمن فتح الباب الكامل بالثواني
        DoorAngle      = 105,       -- زاوية فتح كل نص باب بالدرجات

        GateDistance   = 22,        -- مسافة تفعيل مشهد فتح الباب من البوابة
        DragonDistance = 42,        -- مسافة تفعيل مشهد الإيقاظ من التنين

        SeatLift       = 0.22,      -- ارتفاع مقعد الركوب كنسبة من ارتفاع جسم التنين

        Sounds = {
                -- دي أصوات مضمونة موجودة جوه اللعبة نفسها
                -- وعايز صوت زئير حقيقي؟ هات أي SoundId من Toolbox وحطه مكان القيم دي
                Roar  = "rbxasset://sounds/bass.mp3",
                Growl = "rbxasset://sounds/splat.wav",
                Creak = "rbxasset://sounds/unsheath.wav",
                Boom  = "rbxasset://sounds/impact_water.mp3",
                Flap  = "rbxasset://sounds/swoosh.wav",
                Ping  = "rbxasset://sounds/electronicpingshort.wav",
                Thud  = "rbxasset://sounds/action_jump_land.mp3",
        },
}

-- لوحة ألوان المشهد: أزرق داكن / أسود / بنفسجي
local C = {
        stone      = Color3.fromRGB(52, 52, 62),
        stoneDark  = Color3.fromRGB(36, 36, 46),
        stoneLight = Color3.fromRGB(72, 72, 86),
        iron       = Color3.fromRGB(40, 36, 44),
        ironDark   = Color3.fromRGB(28, 25, 32),
        purple     = Color3.fromRGB(150, 90, 255),
        purpleDeep = Color3.fromRGB(90, 40, 170),
        amber      = Color3.fromRGB(255, 170, 70),
        moonBlue   = Color3.fromRGB(190, 205, 255),
        waterBlue  = Color3.fromRGB(30, 60, 110),
        building   = Color3.fromRGB(44, 44, 56),
}

-- جذر المشهد: كل اللي يتبنى يجتحته
local scene = Instance.new("Model")
scene.Name = "DragonScene"
scene.Parent = workspace

--========================================================================
--  أدوات مساعدة
--========================================================================
local function part(props, parent)
        local p = Instance.new("Part")
        p.Anchored = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Material = Enum.Material.Slate
        p.Color = C.stone
        for k, v in pairs(props) do
                p[k] = v
        end
        p.Parent = parent or scene
        return p
end

local function tween(inst, time, props, style, dir)
        local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.InOut), props)
        t:Play()
        return t
end

-- توين رقم عام: مفيد لتوجيه حركات بأي منطق
local function tweenNumber(from, to, dur, cb, style, dir)
        local nv = Instance.new("NumberValue")
        nv.Value = from
        nv.Changed:Connect(function(v) cb(v) end)
        tween(nv, dur, {Value = to}, style, dir)
        return nv
end

-- تشغيل صوت عند نقطة أو على جزء معين
local function playSound(id, at, speed, volume)
        local s = Instance.new("Sound")
        s.SoundId = id
        s.PlaybackSpeed = speed or 1
        s.Volume = volume or 1
        s.RollOffMaxDistance = 420
        local holder = at
        if typeof(at) == "Vector3" then
                holder = part({Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(at)}, scene)
                Debris:AddItem(holder, 15)
        end
        s.Parent = holder
        s:Play()
        Debris:AddItem(s, 15)
        return s
end

-- منشئ جسيمات سريع
local function emitter(parent, texture, props)
        local e = Instance.new("ParticleEmitter")
        e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
        if props then
                for k, v in pairs(props) do
                        e[k] = v
                end
        end
        e.Parent = parent
        return e
end

local function getHRP()
        local char = player.Character
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
end

--========================================================================
--  حالة المشهد والمتغيرات المشتركة (معرفة بدري عشان كل الأجزاء تشوفها)
--========================================================================
local state = "boot"
local dragon = nil
local dragonSize = Vector3.new(30, 20, 40)
local dragonBase = CFrame.new(0, 24, -168)
local headPart = nil
local awake = false
local motionLock = false
local flying = false
local seat, prompt
local runMountSequence = nil -- تعريف مسبق بيتملّى بعدين

local function dragonPivot()
        if dragon then
                return dragon:GetPivot()
        end
        return CFrame.new(0, 24, -168)
end

local function headWorldPos()
        if headPart then
                return headPart.Position
        end
        return dragonPivot() * CFrame.new(0, dragonSize.Y * 0.25, dragonSize.Z * 0.45)
end

--========================================================================
--  واجهة المستخدم: عنوان + إرشادات + إسود للتلاشي
--========================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "DragonSceneGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local fadeFrame = Instance.new("Frame")
fadeFrame.Size = UDim2.new(1, 0, 1, 0)
fadeFrame.Position = UDim2.new(0, 0, 0, 0)
fadeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 50
fadeFrame.BackgroundTransparency = 1
fadeFrame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.8, 0, 0.16, 0)
title.Position = UDim2.new(0.1, 0, 0.32, 0)
title.BackgroundTransparency = 1
title.Text = "صحوة التنين الأسود"
title.TextColor3 = Color3.fromRGB(200, 170, 255)
title.TextTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.ZIndex = 51
title.Parent = gui

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(70, 20, 130)
titleStroke.Thickness = 2.5
titleStroke.Transparency = 1
titleStroke.ZIndex = 51
titleStroke.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(0.8, 0, 0.06, 0)
subtitle.Position = UDim2.new(0.1, 0, 0.5, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "مشهد سينمائي - فانتازيا مظلمة"
subtitle.TextColor3 = Color3.fromRGB(150, 150, 190)
subtitle.TextTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextScaled = true
subtitle.ZIndex = 51
subtitle.Parent = gui

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0.7, 0, 0.07, 0)
hint.Position = UDim2.new(0.15, 0, 0.86, 0)
hint.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(220, 215, 255)
hint.TextTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.Text = ""
hint.ZIndex = 51
hint.Parent = gui

local function setHint(text)
        hint.Text = text
        tween(hint, 0.4, {TextTransparency = 0, BackgroundTransparency = 0.45})
        if text ~= "" then
                task.delay(6, function()
                        if hint.Text == text then
                                tween(hint, 1.2, {TextTransparency = 1, BackgroundTransparency = 1})
                        end
                end)
        end
end

local function titleShow(main, sub)
        title.Text = main or "صحوة التنين الأسود"
        subtitle.Text = sub or "مشهد سينمائي - فانتازيا مظلمة"
        tween(title, 1.6, {TextTransparency = 0})
        tween(titleStroke, 1.6, {Transparency = 0})
        tween(subtitle, 1.6, {TextTransparency = 0})
        task.delay(4.5, function()
                tween(title, 1.6, {TextTransparency = 1})
                tween(titleStroke, 1.6, {Transparency = 1})
                tween(subtitle, 1.6, {TextTransparency = 1})
        end)
end

-- show=true يغطي الشاشة بسواد، show=false يكشفها
local function fadeBlack(show, dur)
        if show then
                fadeFrame.BackgroundTransparency = 1
                tween(fadeFrame, dur or 0.5, {BackgroundTransparency = 0})
                task.wait(dur or 0.5)
        else
                tween(fadeFrame, dur or 1, {BackgroundTransparency = 1})
        end
end

--========================================================================
--  نظام الكاميرا السينمائية + الرعشة
--========================================================================
local camShot = nil       -- دالة ترجع CFrame كل فريم (أو nil)
local shakePower = 0

local blur = Lighting:FindFirstChildOfClass("BlurEffect") or Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

local function shake(power, dur)
        shakePower = math.max(shakePower, power)
        task.delay(dur or 0.5, function()
                shakePower = 0
        end)
end

RunService.RenderStepped:Connect(function(dt)
        if camShot then
                local ok, cf = pcall(camShot, dt)
                if ok and typeof(cf) == "CFrame" then
                        if shakePower > 0.01 then
                                local m = shakePower
                                cf = cf
                                        * CFrame.Angles((math.random() - 0.5) * 0.05 * m, (math.random() - 0.5) * 0.05 * m, (math.random() - 0.5) * 0.03 * m)
                                        * CFrame.new((math.random() - 0.5) * 0.8 * m, (math.random() - 0.5) * 0.8 * m, 0)
                        end
                        camera.CFrame = cf
                end
        end
        shakePower = math.max(0, shakePower - dt * 1.8)
end)

-- لقطة ثابتة
local function shotStatic(cf)
        return function()
                return cf
        end
end

-- لقطة سكة: الكاميرا تتحرك من CFrame لـ CFrame
local function shotRail(cf0, cf1, dur)
        local t0 = os.clock()
        return function()
                local a = math.clamp((os.clock() - t0) / dur, 0, 1)
                a = a * a * (3 - 2 * a) -- smoothstep
                return cf0:Lerp(cf1, a)
        end
end

-- لقطة سكة بتبص على هدف ثابت
local function shotRailLook(p0, p1, target, dur)
        local t0 = os.clock()
        return function()
                local a = math.clamp((os.clock() - t0) / dur, 0, 1)
                a = a * a * (3 - 2 * a)
                local pos = p0:Lerp(p1, a)
                return CFrame.lookAt(pos, target)
        end
end

-- لقطة تتبع: نقطة ثابتة بتبص على هدف متحرك
local function shotTrack(pos, getTarget)
        return function()
                return CFrame.lookAt(pos, getTarget())
        end
end

-- لقطة متابعة: كاميرا بتطير جانب الهدف بشكل ناعم
local function shotFollow(getOffset, lookAhead, smooth)
        local cur = nil
        return function(dt)
                local goal = dragonPivot().Position + getOffset()
                if cur == nil then
                        cur = goal
                else
                        cur = cur:Lerp(goal, math.clamp(dt * (smooth or 3), 0, 1))
                end
                local la = lookAhead or Vector3.new(0, 0, 0)
                return CFrame.lookAt(cur, dragonPivot().Position + la)
        end
end

-- لقطة مدارية حوالين هدف
local function shotOrbit(getCenter, radius, height, a0, a1, dur)
        local t0 = os.clock()
        return function()
                local a = math.clamp((os.clock() - t0) / dur, 0, 1)
                local ang = a0 + (a1 - a0) * a
                local c = getCenter()
                return CFrame.lookAt(c + Vector3.new(math.cos(ang) * radius, height, math.sin(ang) * radius), c)
        end
end

local function playShot(fn, dur)
        camShot = fn
        task.wait(dur)
        if camShot == fn then
                camShot = nil
        end
end

local function setFrozen(f)
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp then hrp.Anchored = f end
        if hum then hum.WalkSpeed = f and 0 or 16 end
end

local function startCut()
        camera.CameraType = Enum.CameraType.Scriptable
        blur.Size = 4
        setFrozen(true)
end

local function endCut()
        camShot = nil
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = 70
        blur.Size = 0
        setFrozen(false)
end

--========================================================================
--  المرحلة 1: الجو الليلي - سماء، نجوم، قمر عملاق، سحاب، ضباب
--========================================================================
local function buildLighting()
        Lighting.ClockTime = 0
        Lighting.Brightness = 1.4
        Lighting.Ambient = Color3.fromRGB(8, 10, 22)
        Lighting.OutdoorAmbient = Color3.fromRGB(18, 22, 45)
        Lighting.EnvironmentDiffuseScale = 0.25
        Lighting.EnvironmentSpecularScale = 0.35
        Lighting.GlobalShadows = true
        Lighting.GeographicLatitude = 30
        Lighting.ExposureCompensation = 0.15

        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if not atmo then
                atmo = Instance.new("Atmosphere")
                atmo.Parent = Lighting
        end
        atmo.Density = 0.35
        atmo.Offset = 0.2
        atmo.Color = Color3.fromRGB(110, 105, 160)
        atmo.Decay = Color3.fromRGB(70, 60, 110)
        atmo.Glare = 0.25
        atmo.Haze = 2.2

        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
                sky = Instance.new("Sky")
                sky.Parent = Lighting
        end
        sky.StarCount = 2500
        sky.MoonAngularSize = 40
        sky.CelestialBodiesShown = true

        local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
        if not bloom then
                bloom = Instance.new("BloomEffect")
                bloom.Parent = Lighting
        end
        bloom.Intensity = 0.7
        bloom.Size = 32
        bloom.Threshold = 1.05

        local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if not cc then
                cc = Instance.new("ColorCorrectionEffect")
                cc.Parent = Lighting
        end
        cc.TintColor = Color3.fromRGB(155, 160, 225)
        cc.Saturation = -0.08
        cc.Contrast = 0.12
        cc.Brightness = -0.03

        local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
        if not rays then
                rays = Instance.new("SunRaysEffect")
                rays.Parent = Lighting
        end
        rays.Intensity = 0.05

        local clouds = Terrain:FindFirstChildOfClass("Clouds")
        if not clouds then
                clouds = Instance.new("Clouds")
                clouds.Parent = Terrain
        end
        clouds.Cover = 0.62
        clouds.Density = 0.7
        clouds.Color = Color3.fromRGB(175, 178, 215)

        -- القمر العملاق
        part({
                Name = "BigMoon", Shape = Enum.PartType.Ball, Size = Vector3.new(260, 260, 260),
                Material = Enum.Material.Neon, Color = Color3.fromRGB(232, 238, 255),
                CFrame = CFrame.new(140, 560, -1150), CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
        }, scene)
        part({
                Name = "MoonHalo", Shape = Enum.PartType.Ball, Size = Vector3.new(340, 340, 340),
                Material = Enum.Material.Neon, Color = Color3.fromRGB(190, 200, 240), Transparency = 0.93,
                CFrame = CFrame.new(140, 560, -1150), CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
        }, scene)
end

--========================================================================
--  المرحلة 2: الساحة الكبرى والدرج العملاق
--========================================================================
local function buildGroundAndStairs()
        -- الساحة
        part({
                Name = "Plaza", Size = Vector3.new(240, 2, 270), CFrame = CFrame.new(0, 1, 5),
                Material = Enum.Material.Slate, Color = C.stoneDark,
        }, scene)
        -- أطر حجرية فاتحة للساحة
        part({Size = Vector3.new(240, 0.2, 6), CFrame = CFrame.new(0, 2.1, -127), Material = Enum.Material.Slate, Color = C.stoneLight}, scene)
        part({Size = Vector3.new(240, 0.2, 6), CFrame = CFrame.new(0, 2.1, 137), Material = Enum.Material.Slate, Color = C.stoneLight}, scene)
        part({Size = Vector3.new(6, 0.2, 270), CFrame = CFrame.new(-117, 2.1, 5), Material = Enum.Material.Slate, Color = C.stoneLight}, scene)
        part({Size = Vector3.new(6, 0.2, 270), CFrame = CFrame.new(117, 2.1, 5), Material = Enum.Material.Slate, Color = C.stoneLight}, scene)

        -- الدرج العملاق: 28 درجة بيرفعك من ارتفاع 2 لارتفاع 24
        local STEP_COUNT = 28
        local STEP_H = 22 / STEP_COUNT
        local STEP_D = 2.8
        for i = 1, STEP_COUNT do
                local topY = 2 + i * STEP_H
                local zc = -100 + (STEP_COUNT - i + 0.5) * STEP_D
                part({
                        Size = Vector3.new(34, STEP_H, STEP_D),
                        CFrame = CFrame.new(0, topY - STEP_H / 2, zc),
                        Material = Enum.Material.Basalt, Color = C.stone,
                }, scene)
        end
end

--========================================================================
--  المرحلة 3: واجهة القلعة + الباب المزدوج المصمت + الأبراج
--========================================================================
local hingeL, hingeR, cfvL, cfvR
local relL, relR = {}, {}
local doorDust
local doorOpenedAnim = false
local doorOpened = false
local brazierLights = {}

local function buildCastleFront()
        -- منصة البوابة
        part({
                Name = "GatePlatform", Size = Vector3.new(48, 22, 26), CFrame = CFrame.new(0, 13, -113),
                Material = Enum.Material.Basalt, Color = C.stone,
        }, scene)

        -- جدار الواجهة (فتحة الباب من -12 لـ 12 عرضا ومن 24 لـ 46 ارتفاعا)
        part({Size = Vector3.new(52, 46, 4), CFrame = CFrame.new(-38, 47, -100), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        part({Size = Vector3.new(52, 46, 4), CFrame = CFrame.new(38, 47, -100), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        part({Size = Vector3.new(24, 24, 4), CFrame = CFrame.new(0, 58, -100), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)

        -- إطار الباب وقوسه
        part({Size = Vector3.new(3, 24, 5), CFrame = CFrame.new(-13.5, 36, -100), Material = Enum.Material.Basalt, Color = C.stoneLight}, scene)
        part({Size = Vector3.new(3, 24, 5), CFrame = CFrame.new(13.5, 36, -100), Material = Enum.Material.Basalt, Color = C.stoneLight}, scene)
        part({Size = Vector3.new(33, 3, 5), CFrame = CFrame.new(0, 49.5, -100), Material = Enum.Material.Basalt, Color = C.stoneLight}, scene)
        -- رموز سحرية بنفسجية على القوس
        for _, sx in ipairs({-13.5, 13.5}) do
                for _, sy in ipairs({30, 40}) do
                        part({Size = Vector3.new(0.7, 7, 0.3), CFrame = CFrame.new(sx, sy, -97.3), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.2, CanCollide = false}, scene)
                end
        end

        -- برجان جانبيان
        for _, sx in ipairs({-72, 72}) do
                part({Size = Vector3.new(16, 66, 16), CFrame = CFrame.new(sx, 57, -100), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
                part({Size = Vector3.new(18, 2, 18), CFrame = CFrame.new(sx, 91, -100), Material = Enum.Material.Basalt, Color = C.stoneLight}, scene)
                for _, ox in ipairs({-6, 6}) do
                        part({Size = Vector3.new(3.5, 3.5, 3.5), CFrame = CFrame.new(sx + ox, 93.8, -100 + ox * 0), Material = Enum.Material.Basalt, Color = C.stone}, scene)
                        part({Size = Vector3.new(3.5, 3.5, 3.5), CFrame = CFrame.new(sx, 93.8, -100 + ox), Material = Enum.Material.Basalt, Color = C.stone}, scene)
                end
        end
        -- شرفات أعلى الجدار
        for x = -58, -16, 8.4 do
                part({Size = Vector3.new(4.5, 4, 4), CFrame = CFrame.new(x, 72, -100), Material = Enum.Material.Basalt, Color = C.stone}, scene)
        end
        for x = 16, 58, 8.4 do
                part({Size = Vector3.new(4.5, 4, 4), CFrame = CFrame.new(x, 72, -100), Material = Enum.Material.Basalt, Color = C.stone}, scene)
        end

        -- الباب المزدوج المصمت: نصين بيتقابلوا في الوسط بتراكب بسيط يضمن عدم وجود أي فجوة
        local function buildDoorPanel(width, centerX)
                local m = Instance.new("Model")
                m.Name = "DoorPanel"
                m.Parent = scene
                local base = CFrame.new(centerX, 35, -100)
                part({Size = Vector3.new(width, 22, 2.4), CFrame = base, Material = Enum.Material.Metal, Color = C.iron}, m)
                for i = 0, 3 do
                        part({Size = Vector3.new(width * 0.94, 1.4, 0.6), CFrame = base * CFrame.new(0, -8 + i * 5.4, 1.55), Material = Enum.Material.CorrodedMetal, Color = C.ironDark, CanCollide = false}, m)
                        part({Size = Vector3.new(width * 0.94, 1.4, 0.6), CFrame = base * CFrame.new(0, -8 + i * 5.4, -1.55), Material = Enum.Material.CorrodedMetal, Color = C.ironDark, CanCollide = false}, m)
                end
                part({Size = Vector3.new(1.2, 21.4, 0.5), CFrame = base * CFrame.new(-width / 2 + 1.1, 0, 1.6), Material = Enum.Material.CorrodedMetal, Color = C.ironDark, CanCollide = false}, m)
                part({Size = Vector3.new(1.2, 21.4, 0.5), CFrame = base * CFrame.new(width / 2 - 1.1, 0, 1.6), Material = Enum.Material.CorrodedMetal, Color = C.ironDark, CanCollide = false}, m)
                return m
        end

        local panelL = buildDoorPanel(12.2, -6)
        local panelR = buildDoorPanel(12.2, 6)

        -- مفصلات الباب: نقاط الدوران الصحيحة عند الحافة الخارجية لكل نص
        hingeL = part({Name = "HingeL", Size = Vector3.new(1.4, 1.4, 1.4), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(-12.1, 35, -100)}, scene)
        hingeR = part({Name = "HingeR", Size = Vector3.new(1.4, 1.4, 1.4), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(12.1, 35, -100)}, scene)

        for _, p in ipairs(panelL:GetDescendants()) do
                if p:IsA("BasePart") then relL[p] = hingeL.CFrame:ToObjectSpace(p.CFrame) end
        end
        for _, p in ipairs(panelR:GetDescendants()) do
                if p:IsA("BasePart") then relR[p] = hingeR.CFrame:ToObjectSpace(p.CFrame) end
        end

        cfvL = Instance.new("CFrameValue")
        cfvL.Value = hingeL.CFrame
        cfvL.Changed:Connect(function(v)
                for p, rel in pairs(relL) do p.CFrame = v * rel end
        end)
        cfvR = Instance.new("CFrameValue")
        cfvR.Value = hingeR.CFrame
        cfvR.Changed:Connect(function(v)
                for p, rel in pairs(relR) do p.CFrame = v * rel end
        end)

        -- غبار البيئة فوق البوابة (بيتفرقع لما الباب يفتح)
        local dustPart = part({Size = Vector3.new(26, 1, 4), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(0, 47, -98)}, scene)
        doorDust = emitter(dustPart, "rbxasset://textures/particles/smoke_main.dds", {
                Color = ColorSequence.new(Color3.fromRGB(120, 118, 130)),
                Rate = 0, Enabled = false,
                Speed = NumberRange.new(1.5, 4),
                Lifetime = NumberRange.new(1.4, 2.6),
                Size = NumberSequence.new(2, 6),
                Transparency = NumberSequence.new(0.6, 1),
                SpreadAngle = Vector2.new(25, 8),
        })
end

local function openDoors()
        if doorOpenedAnim then return end
        doorOpenedAnim = true
        -- صرير الباب مع الفتح البطيء
        for _, t in ipairs({0, 2.2, 4.4, 6.6}) do
                task.delay(t, function()
                        playSound(CONFIG.Sounds.Creak, Vector3.new(0, 36, -100), 0.26, 1.4)
                end)
        end
        doorDust.Enabled = true
        doorDust:Emit(90)
        doorDust.Enabled = false
        -- مشاعل الغرفة الداخلية بتولّي مع الفتح
        for _, l in ipairs(brazierLights) do
                tween(l, 3, {Brightness = 1.8})
        end
        -- الدوران بطيء حول المفصلات (مش حوالين مركز الباب)
        tween(cfvL, CONFIG.DoorOpenTime, {Value = hingeL.CFrame * CFrame.Angles(0, math.rad(CONFIG.DoorAngle), 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        tween(cfvR, CONFIG.DoorOpenTime, {Value = hingeR.CFrame * CFrame.Angles(0, -math.rad(CONFIG.DoorAngle), 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        task.delay(CONFIG.DoorOpenTime - 0.15, function()
                playSound(CONFIG.Sounds.Thud, Vector3.new(0, 30, -100), 0.55, 1.6)
                shake(0.7, 0.5)
        end)
end

--========================================================================
--  المرحلة 4: تماثيل التنين الحجرية المتناظرة
--========================================================================
local function buildDragonStatue(baseCF, tint)
        local m = Instance.new("Model")
        m.Name = "DragonStatue"
        m.Parent = scene
        local mat = Enum.Material.Basalt
        local col = tint or C.stoneDark
        local function sp(props)
                props.Material = mat
                props.Color = col
                return part(props, m)
        end
        -- القاعدة
        sp({Size = Vector3.new(10, 6, 10), CFrame = baseCF * CFrame.new(0, 3, 0)})
        sp({Size = Vector3.new(8, 1.5, 8), CFrame = baseCF * CFrame.new(0, 6.75, 0)})
        -- الذيل
        sp({Size = Vector3.new(3, 2.5, 9), CFrame = baseCF * CFrame.new(0, 10.5, 5) * CFrame.Angles(0.25, 0, 0)})
        -- الجسم
        sp({Size = Vector3.new(6.5, 6, 13), CFrame = baseCF * CFrame.new(0, 14, 2) * CFrame.Angles(0.18, 0, 0)})
        sp({Size = Vector3.new(5, 4, 2), CFrame = baseCF * CFrame.new(0, 13.5, -4.2)})
        -- الرقبة والراس
        sp({Size = Vector3.new(3.2, 3.2, 6.5), CFrame = baseCF * CFrame.new(0, 19.5, -5) * CFrame.Angles(0.75, 0, 0)})
        sp({Size = Vector3.new(4.6, 3.6, 6), CFrame = baseCF * CFrame.new(0, 23, -7.5) * CFrame.Angles(0.15, 0, 0)})
        sp({Size = Vector3.new(2.4, 2, 3), CFrame = baseCF * CFrame.new(0, 22.7, -11)})
        -- القرون
        sp({Size = Vector3.new(0.9, 3.6, 0.9), CFrame = baseCF * CFrame.new(1.7, 25.4, -6) * CFrame.Angles(0, 0, 0.5)})
        sp({Size = Vector3.new(0.9, 3.6, 0.9), CFrame = baseCF * CFrame.new(-1.7, 25.4, -6) * CFrame.Angles(0, 0, -0.5)})
        -- الأجنحة المطوية
        sp({Size = Vector3.new(1.2, 7.5, 4.5), CFrame = baseCF * CFrame.new(4.2, 17, 1) * CFrame.Angles(0, 0.35, 0.5)})
        sp({Size = Vector3.new(1.2, 7.5, 4.5), CFrame = baseCF * CFrame.new(-4.2, 17, 1) * CFrame.Angles(0, -0.35, -0.5)})
        -- المخالب الأمامية
        sp({Size = Vector3.new(2.2, 6, 2.2), CFrame = baseCF * CFrame.new(3, 11, -6.5)})
        sp({Size = Vector3.new(2.2, 6, 2.2), CFrame = baseCF * CFrame.new(-3, 11, -6.5)})
        sp({Size = Vector3.new(2.6, 1, 3), CFrame = baseCF * CFrame.new(3, 8.2, -7.5)})
        sp({Size = Vector3.new(2.6, 1, 3), CFrame = baseCF * CFrame.new(-3, 8.2, -7.5)})
        -- إضاءة بنفسجية خفيفة للتمثال
        local lp = part({Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = baseCF * CFrame.new(0, 26, 0)}, scene)
        local l = Instance.new("PointLight")
        l.Color = C.purple
        l.Range = 26
        l.Brightness = 0.8
        l.Parent = lp
        return m
end

local function buildStatues()
        buildDragonStatue(CFrame.new(-26, 2, -40) * CFrame.Angles(0, math.rad(-90), 0), C.stoneDark)
        buildDragonStatue(CFrame.new(26, 2, -40) * CFrame.Angles(0, math.rad(90), 0), C.stoneDark)
end

--========================================================================
--  المرحلة 5: المشاعل بالنار والدخان المتحرك
--========================================================================
local torchLights = {}

local function buildTorch(cf, opts)
        opts = opts or {}
        local poleH = opts.poleH or 12
        local purple = opts.purple or false
        local m = Instance.new("Model")
        m.Name = "Torch"
        m.Parent = scene
        if poleH > 0 then
                part({Size = Vector3.new(0.9, poleH, 0.9), CFrame = cf * CFrame.new(0, poleH / 2, 0), Material = Enum.Material.CorrodedMetal, Color = C.ironDark}, m)
        end
        local bowlY = poleH
        part({Size = Vector3.new(2.2, 0.9, 2.2), CFrame = cf * CFrame.new(0, bowlY, 0), Material = Enum.Material.CorrodedMetal, Color = C.ironDark}, m)
        local fp = part({Size = Vector3.new(0.6, 0.6, 0.6), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = cf * CFrame.new(0, bowlY + 0.7, 0)}, m)
        local fireColor1 = purple and C.purple or Color3.fromRGB(255, 190, 90)
        local fireColor2 = purple and C.purpleDeep or Color3.fromRGB(255, 80, 20)
        emitter(fp, "rbxasset://textures/particles/fire_main.dds", {
                Color = ColorSequence.new(fireColor1, fireColor2),
                Rate = 28,
                Speed = NumberRange.new(2.5, 4),
                Lifetime = NumberRange.new(0.45, 0.85),
                Size = NumberSequence.new(1.7, 0.2),
                Transparency = NumberSequence.new(0.1, 1),
                LightEmission = 1,
                LightInfluence = 0,
                SpreadAngle = Vector2.new(12, 12),
        })
        emitter(fp, "rbxasset://textures/particles/smoke_main.dds", {
                Color = ColorSequence.new(Color3.fromRGB(60, 60, 68)),
                Rate = 7,
                Speed = NumberRange.new(1.2, 2.2),
                Lifetime = NumberRange.new(2, 3.2),
                Size = NumberSequence.new(2.2, 5),
                Transparency = NumberSequence.new(0.55, 1),
                SpreadAngle = Vector2.new(15, 15),
        })
        emitter(fp, "rbxasset://textures/particles/sparkles_main.dds", {
                Color = ColorSequence.new(fireColor1),
                Rate = 4,
                Speed = NumberRange.new(2, 5),
                Lifetime = NumberRange.new(0.4, 0.8),
                Size = NumberSequence.new(0.3, 0),
                LightEmission = 1,
                SpreadAngle = Vector2.new(180, 180),
        })
        local l = Instance.new("PointLight")
        l.Color = purple and C.purple or Color3.fromRGB(255, 150, 60)
        l.Range = purple and 18 or 16
        l.Brightness = 1.2
        l.Parent = fp
        table.insert(torchLights, l)
        return m
end

local function buildTorches()
        -- مشاعل جنبي الدرج على الساحة
        for _, sx in ipairs({-20, 20}) do
                buildTorch(CFrame.new(sx, 2, -36), {poleH = 14})
                buildTorch(CFrame.new(sx, 2, -68), {poleH = 14})
        end
        -- مشاعل جنب البوابة (مثبتة على الواجهة)
        for _, sx in ipairs({-14.5, 14.5}) do
                buildTorch(CFrame.new(sx, 38, -97.6), {poleH = 0})
        end
        -- مشاعل الساحة جنب البرك
        for _, sx in ipairs({-34, 34}) do
                buildTorch(CFrame.new(sx, 2, -6), {poleH = 11})
        end
        -- لهب النار بيرفرف
        task.spawn(function()
                while true do
                        for _, l in ipairs(torchLights) do
                                l.Brightness = 1.0 + math.random() * 0.7
                        end
                        task.wait(0.09)
                end
        end)
end

--========================================================================
--  المرحلة 6: المياه الضحلة العاكسة (في مناطق محددة بس - ممنوع غمر الخريطة)
--========================================================================
local function buildPool(cx, cz)
        local m = Instance.new("Model")
        m.Name = "ReflectingPool"
        m.Parent = scene
        -- حوض حجري
        part({Size = Vector3.new(20.8, 1.6, 1.6), CFrame = CFrame.new(cx, 2.8, cz - 9.2), Material = Enum.Material.Slate, Color = C.stoneLight}, m)
        part({Size = Vector3.new(20.8, 1.6, 1.6), CFrame = CFrame.new(cx, 2.8, cz + 9.2), Material = Enum.Material.Slate, Color = C.stoneLight}, m)
        part({Size = Vector3.new(1.6, 1.6, 20.8), CFrame = CFrame.new(cx - 9.2, 2.8, cz), Material = Enum.Material.Slate, Color = C.stoneLight}, m)
        part({Size = Vector3.new(1.6, 1.6, 20.8), CFrame = CFrame.new(cx + 9.2, 2.8, cz), Material = Enum.Material.Slate, Color = C.stoneLight}, m)
        -- قاع الحوض
        part({Size = Vector3.new(18.4, 0.3, 18.4), CFrame = CFrame.new(cx, 2.15, cz), Material = Enum.Material.Slate, Color = C.stoneDark}, m)
        -- شرائط توهج بنفسجي تحت الماء للانعكاس السحري
        part({Size = Vector3.new(0.6, 0.1, 8), CFrame = CFrame.new(cx - 3, 2.35, cz), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.3, CanCollide = false}, m)
        part({Size = Vector3.new(0.6, 0.1, 8), CFrame = CFrame.new(cx + 3, 2.35, cz), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.3, CanCollide = false}, m)
        -- الماء الضحل عبر التضاريس (بديل زجاجي لو فشل)
        local ok = pcall(function()
                Terrain:FillBlock(CFrame.new(cx, 2.9, cz), Vector3.new(18.6, 1.4, 18.6), Enum.Material.Water)
        end)
        if not ok then
                part({Size = Vector3.new(18.4, 1.2, 18.4), CFrame = CFrame.new(cx, 3.0, cz), Material = Enum.Material.Glass, Color = C.waterBlue, Transparency = 0.25, Reflectance = 0.4, CanCollide = false}, m)
        end
end

local function setupWater()
        pcall(function()
                Terrain.WaterReflectance = 0.5
                Terrain.WaterTransparency = 0.25
                Terrain.WaterWaveSize = 0.12
                Terrain.WaterWaveSpeed = 12
        end)
        buildPool(-52, -20)
        buildPool(52, -20)
end

--========================================================================
--  المرحلة 7: المباني القلعية المحيطة بالساحة
--========================================================================
local function buildHouse(cf)
        local m = Instance.new("Model")
        m.Name = "CastleBuilding"
        m.Parent = scene
        local col = C.building
        -- برج
        part({Size = Vector3.new(13, 32, 13), CFrame = cf * CFrame.new(0, 16, -2), Material = Enum.Material.Basalt, Color = col}, m)
        part({Size = Vector3.new(14.5, 1.5, 14.5), CFrame = cf * CFrame.new(0, 32.7, -2), Material = Enum.Material.Basalt, Color = C.stoneLight}, m)
        -- قاعة
        part({Size = Vector3.new(24, 15, 18), CFrame = cf * CFrame.new(0, 7.5, 8), Material = Enum.Material.Basalt, Color = col}, m)
        -- سقف مدبب
        part({Shape = Enum.PartType.Wedge, Size = Vector3.new(26, 9, 20), CFrame = cf * CFrame.new(0, 19.5, 8), Material = Enum.Material.Slate, Color = C.stoneDark}, m)
        -- شباك بنفسجي مضيء
        for _, wx in ipairs({-6, 0, 6}) do
                part({Size = Vector3.new(2.2, 3, 0.4), CFrame = cf * CFrame.new(wx, 7, -1.2), Material = Enum.Material.Neon, Color = C.amber, Transparency = 0.15, CanCollide = false}, m)
        end
        part({Size = Vector3.new(1.2, 4, 0.4), CFrame = cf * CFrame.new(0, 22, -8.6), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.2, CanCollide = false}, m)
        -- باب
        part({Size = Vector3.new(5, 8, 0.5), CFrame = cf * CFrame.new(0, 4, -1.3), Material = Enum.Material.Wood, Color = C.ironDark}, m)
        return m
end

local function buildBuildings()
        local plazaCenter = Vector3.new(0, 0, 10)
        local houses = {
                {pos = Vector3.new(-108, 2, 40), yaw = -90},
                {pos = Vector3.new(-108, 2, -55), yaw = -90},
                {pos = Vector3.new(108, 2, 40), yaw = 90},
                {pos = Vector3.new(108, 2, -55), yaw = 90},
                {pos = Vector3.new(-70, 2, 132), yaw = 0},
                {pos = Vector3.new(70, 2, 132), yaw = 0},
                {pos = Vector3.new(-95, 2, -92), yaw = 180},
                {pos = Vector3.new(95, 2, -92), yaw = 180},
        }
        for _, h in ipairs(houses) do
                local cf = CFrame.lookAt(h.pos, Vector3.new(plazaCenter.X, h.pos.Y, plazaCenter.Z))
                buildHouse(cf)
        end
        -- أبراج بعيدة على الأفق
        local skylines = {
                {Vector3.new(-185, 0, 60), 34, 80},
                {Vector3.new(190, 0, 90), 30, 68},
                {Vector3.new(-160, 0, -60), 26, 56},
                {Vector3.new(170, 0, -30), 36, 88},
                {Vector3.new(-40, 0, 210), 30, 72},
                {Vector3.new(60, 0, 215), 26, 60},
        }
        for _, s in ipairs(skylines) do
                part({Size = Vector3.new(s[2], s[3], s[2]), CFrame = CFrame.new(s[1] + Vector3.new(0, s[3] / 2, 0)), Material = Enum.Material.Basalt, Color = Color3.fromRGB(30, 30, 40)}, scene)
        end
end

--========================================================================
--  المرحلة 8: حرم التنين - الأعمدة العملاقة والإضاءة البنفسجية وفتحات القمر
--========================================================================
local roomLights = {}   -- إضاءة بنفسجية بتتولي مع الإيقاظ
local chunks = {}       -- شظايا السقف القابلة للتحطم
local ceilDust
local holeCenter = Vector3.new(0, 60, -168)
local beamSpots = {}

local function buildRoom()
        -- الأرضية
        part({Size = Vector3.new(128, 2, 108), CFrame = CFrame.new(0, 23, -180), Material = Enum.Material.Slate, Color = C.stoneDark}, scene)
        -- دائرة استدعاء متوهجة تحت التنين
        part({Size = Vector3.new(26, 0.12, 26), CFrame = CFrame.new(0, 24.12, -168) * CFrame.Angles(0, 0, 0), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.55, CanCollide = false}, scene)
        part({Size = Vector3.new(19, 0.12, 19), CFrame = CFrame.new(0, 24.2, -168) * CFrame.Angles(0, math.rad(45), 0), Material = Enum.Material.Neon, Color = C.purpleDeep, Transparency = 0.7, CanCollide = false}, scene)

        -- الجدران
        part({Size = Vector3.new(4, 38, 132), CFrame = CFrame.new(-62, 43, -168), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        part({Size = Vector3.new(4, 38, 132), CFrame = CFrame.new(62, 43, -168), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        part({Size = Vector3.new(128, 38, 4), CFrame = CFrame.new(0, 43, -232), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)

        -- السقف: ألواح حوالين فتحة مركزية (اللي هتتكسر بعدين)
        part({Size = Vector3.new(36, 4, 132), CFrame = CFrame.new(-44, 60, -168), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        part({Size = Vector3.new(36, 4, 132), CFrame = CFrame.new(44, 60, -168), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        -- اللوح الأمامي فيه 3 فتحات ضيقة لشعاع القمر
        for _, sx in ipairs({-21, -7, 7, 21}) do
                part({Size = Vector3.new(10, 4, 48), CFrame = CFrame.new(sx, 60, -126), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)
        end
        part({Size = Vector3.new(52, 4, 48), CFrame = CFrame.new(0, 60, -210), Material = Enum.Material.Basalt, Color = C.stoneDark}, scene)

        -- شظايا السقف فوق الفتحة (شكلها سقف عادي لحد ما تتحطم)
        local holeW = 52
        local holeD = 36
        local cols = math.ceil(holeW / 13)
        local rows = math.ceil(holeD / 9)
        local cw = holeW / cols
        local cd = holeD / rows
        for ix = 0, cols - 1 do
                for iz = 0, rows - 1 do
                        local cxx = -holeW / 2 + cw * (ix + 0.5)
                        local czz = -168 - holeD / 2 + cd * (iz + 0.5)
                        local shade = 30 + math.random(0, 8)
                        local c = part({
                                Name = "CeilingChunk",
                                Size = Vector3.new(cw, 4, cd),
                                CFrame = CFrame.new(cxx, 60, czz),
                                Material = Enum.Material.Basalt,
                                Color = Color3.fromRGB(shade, shade, shade + 10),
                        }, scene)
                        table.insert(chunks, c)
                end
        end
        -- صخور حطام على حواف الفتحة (تبان بعد الكسر)
        for i = 1, 10 do
                local edgeX = (math.random() < 0.5 and -1 or 1) * (24 + math.random() * 2)
                local edgeZ = -168 + (math.random() - 0.5) * 34
                part({Size = Vector3.new(1.5 + math.random() * 2, 1 + math.random(), 1.5 + math.random() * 2), CFrame = CFrame.new(edgeX, 57.6 + math.random(), edgeZ) * CFrame.Angles(math.random() * 0.6, math.random() * 3, math.random() * 0.6), Material = Enum.Material.Basalt, Color = C.ironDark}, scene)
        end

        -- الأعمدة الحجرية العملاقة
        for _, sx in ipairs({-52, 52}) do
                for _, sz in ipairs({-118, -148, -178, -208}) do
                        part({Size = Vector3.new(10.5, 2, 10.5), CFrame = CFrame.new(sx, 25, sz), Material = Enum.Material.Basalt, Color = C.stoneLight}, scene)
                        part({Size = Vector3.new(8, 34, 8), CFrame = CFrame.new(sx, 41, sz), Material = Enum.Material.Basalt, Color = C.stone}, scene)
                        part({Size = Vector3.new(11, 3, 11), CFrame = CFrame.new(sx, 56.5, sz), Material = Enum.Material.Basalt, Color = C.stoneLight}, scene)
                        local lp = part({Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(sx, 54, sz)}, scene)
                        local l = Instance.new("PointLight")
                        l.Color = C.purple
                        l.Range = 38
                        l.Brightness = 0.55
                        l.Parent = lp
                        table.insert(roomLights, l)
                end
        end

        -- مصابيح جدارية بنفسجية
        for _, sz in ipairs({-130, -190}) do
                for _, sx in ipairs({-59.3, 59.3}) do
                        part({Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(sx, 50, sz), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.1, CanCollide = false}, scene)
                        local lp = part({Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(sx, 50, sz)}, scene)
                        local l = Instance.new("PointLight")
                        l.Color = C.purple
                        l.Range = 26
                        l.Brightness = 0.45
                        l.Parent = lp
                        table.insert(roomLights, l)
                end
        end

        -- مشاعل بنفسجية جوه الغرفة جنب المدخل (النور بيولي لما الباب يفتح)
        for _, sx in ipairs({-20, 20}) do
                local m = Instance.new("Model")
                m.Name = "Brazier"
                m.Parent = scene
                part({Size = Vector3.new(1.4, 2.2, 1.4), CFrame = CFrame.new(sx, 25.1, -112), Material = Enum.Material.CorrodedMetal, Color = C.ironDark}, m)
                part({Size = Vector3.new(2.6, 1, 2.6), CFrame = CFrame.new(sx, 26.4, -112), Material = Enum.Material.CorrodedMetal, Color = C.ironDark}, m)
                local fp = part({Size = Vector3.new(0.6, 0.6, 0.6), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(sx, 27.2, -112)}, m)
                emitter(fp, "rbxasset://textures/particles/fire_main.dds", {
                        Color = ColorSequence.new(C.purple, C.purpleDeep),
                        Rate = 22,
                        Speed = NumberRange.new(2, 3.5),
                        Lifetime = NumberRange.new(0.4, 0.8),
                        Size = NumberSequence.new(1.5, 0.2),
                        Transparency = NumberSequence.new(0.1, 1),
                        LightEmission = 1,
                        SpreadAngle = Vector2.new(12, 12),
                })
                local l = Instance.new("PointLight")
                l.Color = C.purple
                l.Range = 18
                l.Brightness = 0.3
                l.Parent = fp
                table.insert(brazierLights, l)
        end

        -- أشعة القمر من الفتحات المعمارية العليا
        for _, sx in ipairs({-14, 0, 14}) do
                local topPos = Vector3.new(sx, 57.5, -126)
                local dir = Vector3.new(0.3, -1, 0.25).Unit
                local len = 74
                local center = topPos + dir * (len / 2)
                local beam = part({
                        Size = Vector3.new(3.4, 3.4, len),
                        CFrame = CFrame.lookAt(center, center + dir),
                        Material = Enum.Material.Neon, Color = C.moonBlue, Transparency = 0.86,
                        CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
                }, scene)
                local spot = Instance.new("SpotLight")
                spot.Color = C.moonBlue
                spot.Angle = 42
                spot.Range = 60
                spot.Brightness = 1.1
                spot.Face = Enum.NormalId.Front
                spot.Parent = beam
                table.insert(beamSpots, spot)
                -- ذرات غبار جوه الشعاع
                emitter(beam, "rbxasset://textures/particles/sparkles_main.dds", {
                        Color = ColorSequence.new(C.moonBlue),
                        Rate = 2,
                        Speed = NumberRange.new(0.1, 0.4),
                        Lifetime = NumberRange.new(3, 6),
                        Size = NumberSequence.new(0.3, 0.1),
                        Transparency = NumberSequence.new(0.4, 1),
                        LightEmission = 1,
                })
        end

        -- غبار السقف (بيتفرقق عند الكسر والزئير)
        local dustP = part({Size = Vector3.new(50, 1, 34), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(0, 56, -168)}, scene)
        ceilDust = emitter(dustP, "rbxasset://textures/particles/smoke_main.dds", {
                Color = ColorSequence.new(Color3.fromRGB(130, 126, 140)),
                Rate = 0, Enabled = false,
                Speed = NumberRange.new(2, 7),
                Lifetime = NumberRange.new(1.6, 3),
                Size = NumberSequence.new(2.5, 7),
                Transparency = NumberSequence.new(0.5, 1),
                SpreadAngle = Vector2.new(60, 20),
        })

        -- جسيمات سحرية بنفسجية عائمة في الغرفة كلها
        local amb = part({Size = Vector3.new(70, 34, 70), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(0, 41, -168)}, scene)
        emitter(amb, "rbxasset://textures/particles/sparkles_main.dds", {
                Color = ColorSequence.new(C.purple),
                Rate = 9,
                Speed = NumberRange.new(0.3, 0.6),
                Lifetime = NumberRange.new(6, 9),
                Size = NumberSequence.new(0.32, 0.05),
                Transparency = NumberSequence.new(0.3, 1),
                LightEmission = 1,
                ZOffset = -1,
        })
end

local function breakCeiling()
        -- شظايا بتطير وبتقع فيزيائيا (بدون أي teleport للتنين أو اللاعب)
        for _, c in ipairs(chunks) do
                c.Anchored = false
                c.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, math.random(6, 20), (math.random() - 0.5) * 30)
                c.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 8, (math.random() - 0.5) * 8, (math.random() - 0.5) * 8)
                Debris:AddItem(c, 8)
                task.delay(5, function()
                        tween(c, 2.5, {Transparency = 1})
                end)
        end
        ceilDust.Enabled = true
        ceilDust:Emit(260)
        ceilDust.Enabled = false
        playSound(CONFIG.Sounds.Boom, holeCenter, 0.55, 2.4)
        playSound(CONFIG.Sounds.Roar, holeCenter, 0.24, 2)
        playSound(CONFIG.Sounds.Thud, holeCenter, 0.5, 2)
        shake(2.8, 2)
        -- شعاع ضوء القمر الكبير بينزل من الفتحة
        local beam = part({
                Size = Vector3.new(34, 120, 34),
                CFrame = CFrame.new(0, 30, -168),
                Material = Enum.Material.Neon, Color = C.moonBlue, Transparency = 0.88,
                CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
        }, scene)
        tween(beam, 3, {Transparency = 0.8})
        local sp = part({Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(0, 84, -168)}, scene)
        local sl = Instance.new("SpotLight")
        sl.Color = C.moonBlue
        sl.Angle = 60
        sl.Range = 60
        sl.Brightness = 2.4
        sl.Face = Enum.NormalId.Bottom
        sl.Parent = sp
end

--========================================================================
--  المرحلة 9: تجهيز نموذج التنين بتاعك + العيون البنفسجية + الأجنحة + الراس
--========================================================================
local eyeParts, eyeLights, eyeSparkles = {}, {}, {}
local leftWings, rightWings = {}, {}
local wingSetL, wingSetR = nil, nil
local headSet = nil

-- دوران مجموعة أجزاء حوالين نقطة مفصلة ثابتة
local function makeSpin(parts, pivotCF)
        local originals = {}
        for _, p in ipairs(parts) do
                originals[p] = p.CFrame
        end
        return function(angleCF)
                for p, cf0 in pairs(originals) do
                        p.CFrame = pivotCF * angleCF * pivotCF:Inverse() * cf0
                end
        end
end

local function groupPivot(parts, axis, innerMin)
        local minv, maxv
        for _, p in ipairs(parts) do
                local pos = p.Position
                if minv == nil then
                        minv = pos
                        maxv = pos
                else
                        minv = Vector3.new(math.min(minv.X, pos.X), math.min(minv.Y, pos.Y), math.min(minv.Z, pos.Z))
                        maxv = Vector3.new(math.max(maxv.X, pos.X), math.max(maxv.Y, pos.Y), math.max(maxv.Z, pos.Z))
                end
        end
        local c = (minv + maxv) / 2
        local v = innerMin and minv[axis] or maxv[axis]
        if axis == "X" then
                return CFrame.new(v, c.Y, c.Z)
        elseif axis == "Y" then
                return CFrame.new(c.X, v, c.Z)
        end
        return CFrame.new(c.X, c.Y, v)
end

local function findDragon()
        local names = {CONFIG.DragonName, "BlackDragon", "DragonModel", "التنين", "التنين الأسود", "dragon"}
        for _, nm in ipairs(names) do
                local m = workspace:FindFirstChild(nm, true)
                if m and m:IsA("Model") then
                        return m
                end
        end
        local m = workspace:WaitForChild(CONFIG.DragonName, CONFIG.DragonWaitTime)
        if m and m:IsA("Model") then
                return m
        end
        return nil
end

local function prepareDragon()
        if not dragon then
                warn("[صحوة التنين] مفيش نموذج تنين اسمه Dragon في Workspace! المشهد هيشتغل من غير التنين.")
                return
        end
        -- تثبيت كل أجزاء الموديل عشان نتحكم فيها كاميرا وحركة
        for _, d in ipairs(dragon:GetDescendants()) do
                if d:IsA("BasePart") then
                        d.Anchored = true
                        d.CanCollide = false
                        d.CanTouch = false
                        d.CanQuery = false
                end
        end
        -- تمركز التنين في وسط الحرم مواجها المدخل
        dragon:PivotTo(CFrame.new(0, 24, -168) * CFrame.Angles(0, math.rad(CONFIG.DragonYaw), 0))
        local cf, size = dragon:GetBoundingBox()
        local bottomY = cf.Position.Y - size.Y / 2
        dragon:PivotTo(dragon:GetPivot() * CFrame.new(0, 24 - bottomY, 0))
        cf, size = dragon:GetBoundingBox()
        dragonSize = size
        dragonBase = dragon:GetPivot()

        -- اكتشاف العيون (بالاسم) وإلا نضيف عينين متوهجين عند مقدمة الراس
        local pivot = dragon:GetPivot()
        for _, d in ipairs(dragon:GetDescendants()) do
                if d:IsA("BasePart") then
                        local n = string.lower(d.Name)
                        if string.find(n, "eye", 1, true) or string.find(d.Name, "عين", 1, true) then
                                table.insert(eyeParts, d)
                        end
                end
        end
        if #eyeParts == 0 then
                local offs = {
                        CFrame.new(dragonSize.X * 0.10, dragonSize.Y * 0.16, -dragonSize.Z * 0.46),
                        CFrame.new(-dragonSize.X * 0.10, dragonSize.Y * 0.16, -dragonSize.Z * 0.46),
                }
                for _, o in ipairs(offs) do
                        local e = Instance.new("Part")
                        e.Name = "AwakenedEye"
                        e.Shape = Enum.PartType.Ball
                        e.Size = Vector3.new(1.4, 1.4, 1.4)
                        e.Material = Enum.Material.Neon
                        e.Color = C.purple
                        e.Anchored = true
                        e.CanCollide = false
                        e.CanQuery = false
                        e.CanTouch = false
                        e.CastShadow = false
                        e.CFrame = pivot * o
                        e.Parent = dragon
                        table.insert(eyeParts, e)
                end
        end
        for _, e in ipairs(eyeParts) do
                pcall(function()
                        e.Material = Enum.Material.Neon
                        e.Color = C.purple
                end)
                local l = Instance.new("PointLight")
                l.Color = C.purple
                l.Range = 10
                l.Brightness = 0.12
                l.Parent = e
                table.insert(eyeLights, l)
                local sp = emitter(e, "rbxasset://textures/particles/sparkles_main.dds", {
                        Color = ColorSequence.new(C.purple),
                        Rate = 0, Enabled = false,
                        Speed = NumberRange.new(0.3, 1),
                        Lifetime = NumberRange.new(0.8, 1.6),
                        Size = NumberSequence.new(0.35, 0.05),
                        LightEmission = 1,
                        SpreadAngle = Vector2.new(180, 180),
                })
                table.insert(eyeSparkles, sp)
        end

        -- اكتشاف الأجنحة والراس بالأسماء
        local pivotX = dragon:GetPivot().Position.X
        for _, d in ipairs(dragon:GetDescendants()) do
                if d:IsA("BasePart") then
                        local n = string.lower(d.Name)
                        if string.find(n, "wing", 1, true) or string.find(d.Name, "جناح", 1, true) then
                                if d.Position.X >= pivotX then
                                        table.insert(leftWings, d)
                                else
                                        table.insert(rightWings, d)
                                end
                        elseif string.find(n, "head", 1, true) or string.find(n, "neck", 1, true) or string.find(d.Name, "راس", 1, true) or string.find(d.Name, "رأس", 1, true) then
                                if headPart == nil then
                                        headPart = d
                                end
                        end
                end
        end

        -- مفصلات الأجنحة (فلاپ حوالين الحافة الداخلية)
        if #leftWings > 0 and #rightWings > 0 then
                wingSetL = makeSpin(leftWings, groupPivot(leftWings, "X", true))
                wingSetR = makeSpin(rightWings, groupPivot(rightWings, "X", false))
        end

        -- مفصلة الراس: دوران حوالين مؤخرة الراس عشان يرفع قدامه لفوق
        if headPart then
                local headPartsList = {headPart}
                headSet = makeSpin(headPartsList, groupPivot(headPartsList, "Z", true))
        end
end

-- المقعد على ظهر التنين + زر الركوب
local function makeSeat()
        if not dragon then return end
        local pos = dragonPivot() * CFrame.new(0, dragonSize.Y * CONFIG.SeatLift, -dragonSize.Z * 0.06)
        local seatPos = pos.Position
        seat = Instance.new("Seat")
        seat.Name = "RideSeat"
        seat.Size = Vector3.new(4.5, 0.7, 5.5)
        seat.Transparency = 1
        seat.Anchored = true
        seat.CanCollide = false
        seat.CFrame = CFrame.lookAt(seatPos, seatPos + Vector3.new(0, 0, 1))
        seat.Parent = dragon

        prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "اركب التنين"
        prompt.ObjectText = "التنين الأسود"
        prompt.HoldDuration = 0.35
        prompt.MaxActivationDistance = 16
        prompt.RequiresLineOfSight = false
        prompt.Parent = seat
        prompt.Triggered:Connect(function(pl)
                if pl == player then
                        task.spawn(runMountSequence)
                end
        end)
end

-- تنفس التنين النائم (وبعد الإيقاظ بيبقى أعمق وأسرع)
task.spawn(function()
        while true do
                RunService.Heartbeat:Wait()
                if dragon and not motionLock then
                        local t = os.clock()
                        local amp = awake and 0.9 or 0.35
                        local spd = awake and 1.6 or 0.9
                        dragon:PivotTo(dragonBase * CFrame.new(0, math.sin(t * spd) * amp, 0) * CFrame.Angles(0, 0, math.sin(t * 0.7) * (awake and 0.02 or 0.008)))
                end
        end
end)

--========================================================================
--  المرحلة 10: الإيقاظ التدريجي خطوة بخطوة
--========================================================================
local function dragonTremble(dur)
        if not dragon then return end
        motionLock = true
        local t0 = os.clock()
        local base = dragon:GetPivot()
        playSound(CONFIG.Sounds.Roar, headWorldPos(), 0.18, 1.2)
        while os.clock() - t0 < dur do
                dragon:PivotTo(base * CFrame.new((math.random() - 0.5) * 0.5, math.random() * 0.3, (math.random() - 0.5) * 0.5) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.015))
                RunService.Heartbeat:Wait()
        end
        dragon:PivotTo(base)
        dragonBase = base
        motionLock = false
end

local function eyesWakeUp()
        for _, l in ipairs(eyeLights) do
                tween(l, 2.4, {Brightness = 3, Range = 14})
        end
        for _, s in ipairs(eyeSparkles) do
                s.Enabled = true
        end
        playSound(CONFIG.Sounds.Growl, headWorldPos(), 0.5, 0.8)
end

local function headRise()
        if headSet then
                tweenNumber(0.15, -0.34, 2.6, function(v)
                        headSet(CFrame.Angles(v, 0, 0))
                end, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        elseif dragon then
                motionLock = true
                tweenNumber(0, 1, 2.6, function(v)
                        dragon:PivotTo(dragonBase * CFrame.new(0, v * 3, 0))
                end)
                task.delay(2.7, function()
                        dragonBase = dragon:GetPivot()
                        motionLock = false
                end)
        end
end

local function roar()
        local mouth = headWorldPos() + Vector3.new(0, 0.5, 2)
        playSound(CONFIG.Sounds.Roar, mouth, 0.32, 2.2)
        playSound(CONFIG.Sounds.Growl, mouth, 0.4, 1.6)
        shake(2.4, 1.6)
        tween(camera, 0.25, {FieldOfView = 88}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        task.delay(0.55, function()
                tween(camera, 1.4, {FieldOfView = 70})
        end)
        -- موجة الصدمة
        local ring = part({Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Material = Enum.Material.Neon, Color = C.purple, Transparency = 0.5, CanCollide = false, CanQuery = false, CastShadow = false, CFrame = CFrame.new(mouth)}, scene)
        tween(ring, 0.9, {Size = Vector3.new(70, 70, 70), Transparency = 1})
        Debris:AddItem(ring, 1.2)
        -- انفجار جسيمات بنفسجية عند الفم
        local p = part({Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(mouth)}, scene)
        local e = emitter(p, "rbxasset://textures/particles/sparkles_main.dds", {
                Color = ColorSequence.new(C.purple),
                Rate = 0, Enabled = false,
                Speed = NumberRange.new(14, 26),
                Lifetime = NumberRange.new(0.5, 1),
                Size = NumberSequence.new(1.6, 0.2),
                LightEmission = 1,
                SpreadAngle = Vector2.new(180, 180),
        })
        e:Emit(140)
        Debris:AddItem(p, 2)
        -- غبار بينزل من السقف مع الزئير
        ceilDust.Enabled = true
        ceilDust:Emit(120)
        ceilDust.Enabled = false
        -- إضاءة الحرم بتنور بالكامل
        for _, l in ipairs(roomLights) do
                tween(l, 1.5, {Brightness = 2.2})
        end
        for _, s in ipairs(beamSpots) do
                tween(s, 1.5, {Brightness = 1.8})
        end
        awake = true
end

local function wingsFlare()
        if not (wingSetL and wingSetR) then
                dragonTremble(1.2)
                return
        end
        playSound(CONFIG.Sounds.Flap, headWorldPos(), 0.7, 1)
        tweenNumber(0, 0.75, 0.8, function(v)
                wingSetL(CFrame.Angles(0, 0, v))
                wingSetR(CFrame.Angles(0, 0, -v))
        end, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        task.wait(0.8)
        tweenNumber(0.75, 0.12, 1.2, function(v)
                wingSetL(CFrame.Angles(0, 0, v))
                wingSetR(CFrame.Angles(0, 0, -v))
        end)
end

--========================================================================
--  المرحلة 11: فتح الباب السينمائي
--========================================================================
local function runGateScene()
        if state ~= "gate_wait" or doorOpenedAnim then return end
        state = "gate_cine"
        startCut()
        setHint("البوابة العملاقة بتفتح...")
        local hrp = getHRP()
        local p = hrp and hrp.Position or Vector3.new(0, 26, -70)
        -- لقطة 1: خلف اللاعب والباب قدامه
        playShot(shotRail(
                CFrame.lookAt(p + Vector3.new(0, 6, 14), Vector3.new(0, 34, -100)),
                CFrame.lookAt(p + Vector3.new(0, 10, 2), Vector3.new(0, 34, -100)),
                3.2
        ), 3.2)
        -- فتح الباب فعلي بالتوازي مع لقطة المفصلة
        task.spawn(openDoors)
        -- لقطة 2: جانبية قريبة على المفصلة والدوران البطيء
        playShot(shotRail(
                CFrame.lookAt(Vector3.new(-30, 40, -84), Vector3.new(-10, 35, -100)),
                CFrame.lookAt(Vector3.new(24, 44, -86), Vector3.new(8, 36, -100)),
                4
        ), 4)
        -- لقطة 3: من فوق الباب والباب بيتفتح تحته
        playShot(shotRail(
                CFrame.lookAt(Vector3.new(0, 78, -80), Vector3.new(0, 30, -100)),
                CFrame.lookAt(Vector3.new(0, 60, -140), Vector3.new(0, 30, -100)),
                4
        ), 4)
        endCut()
        doorOpened = true
        state = "awaken_wait"
        setHint("ادخل حرم التنين من البوابة...")
end

--========================================================================
--  المرحلة 12: مشهد الإيقاظ الكامل بالكاميرا السينمائية
--========================================================================
local function runAwakening()
        if state ~= "awaken_wait" then return end
        state = "awaken_cine"
        startCut()
        motionLock = true
        setHint("شيء عظيم بيصحى...")
        -- 1) رجفة الجسم
        task.spawn(dragonTremble, 3)
        playShot(shotTrack(Vector3.new(0, 34, -104), function()
                return dragonPivot().Position
        end), 3.5)
        -- 2) توهج العيون البنفسجية
        task.spawn(eyesWakeUp)
        playShot(shotFollow(function()
                return Vector3.new(16, 6, 26)
        end), 4)
        -- 3) رفع الراس بالبطء
        task.spawn(headRise)
        playShot(shotRail(
                CFrame.lookAt(Vector3.new(-30, 30, -130), headWorldPos()),
                CFrame.lookAt(Vector3.new(30, 34, -140), headWorldPos()),
                4.5
        ), 4.5)
        -- 4) الزئير المذعور
        task.spawn(roar)
        playShot(shotTrack(Vector3.new(0, 28, -126), function()
                return headWorldPos()
        end), 3.2)
        -- 5) رفرفة الأجنحة
        task.spawn(wingsFlare)
        playShot(shotOrbit(function()
                return dragonPivot().Position
        end, 55, 18, 0.6, 2.4, 5), 5)
        motionLock = false
        endCut()
        state = "mount_wait"
        setHint("اقترب من ظهر التنين واضغط E للركوب")
end

--========================================================================
--  المرحلة 13: الركوب + كسر السقف + الطيران السينمائي
--========================================================================
local function sitPlayer()
        local char = player.Character
        if not (char and seat) then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp) then return end
        local ok = pcall(function()
                seat:Sit(hum)
        end)
        if not ok or not hum.Sit then
                hrp.CFrame = seat.CFrame * CFrame.new(0, 3.2, 0)
                local w = Instance.new("WeldConstraint")
                w.Part0 = seat
                w.Part1 = hrp
                w.Parent = seat
                hum.Sit = true
        end
        playSound(CONFIG.Sounds.Thud, seat.Position, 0.9, 0.8)
end

local function flyThrough(points)
        task.spawn(function()
                local cfv = Instance.new("CFrameValue")
                cfv.Value = CFrame.lookAt(points[1], points[2])
                cfv.Changed:Connect(function(v)
                        local t = os.clock()
                        dragon:PivotTo(v * CFrame.new(0, math.sin(t * 2.2) * 1.6, 0))
                end)
                for i = 2, #points do
                        local from = points[i - 1]
                        local to = points[i]
                        local nextP = points[i + 1] or to + (to - from)
                        local b = CFrame.lookAt(to, nextP)
                        local dist = (to - from).Magnitude
                        local dur = math.max(4, math.min(dist / 26, 16))
                        local tw = tween(cfv, dur, {Value = b}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                        tw.Completed:Wait()
                end
                flying = false
        end)
end

local function flapLoop()
        task.spawn(function()
                local lastSign = 1
                while flying do
                        local t = os.clock() * 1.5
                        local s = math.sin(t)
                        if wingSetL and wingSetR then
                                wingSetL(CFrame.Angles(0, 0, s * 0.5))
                                wingSetR(CFrame.Angles(0, 0, -s * 0.5))
                        end
                        local sign = s >= 0 and 1 or -1
                        if sign ~= lastSign then
                                lastSign = sign
                                playSound(CONFIG.Sounds.Flap, headWorldPos(), 0.85, 0.6)
                        end
                        RunService.Heartbeat:Wait()
                end
                if wingSetL and wingSetR then
                        wingSetL(CFrame.Angles(0, 0, 0.12))
                        wingSetR(CFrame.Angles(0, 0, -0.12))
                end
        end)
end

runMountSequence = function()
        if state ~= "mount_wait" then return end
        state = "mount_cine"
        startCut()
        motionLock = true
        if prompt then prompt.Enabled = false end
        sitPlayer()
        setHint("متمسك بظهر التنين...")
        -- لقطة جانبية للفارس
        playShot(shotFollow(function()
                return Vector3.new(26, 7, 14)
        end), 3)
        setHint("التنين بيجهز لكسر السقف!")
        -- انحناء قبل الصعود
        local base = dragon:GetPivot()
        tweenNumber(0, 1, 1.2, function(v)
                dragon:PivotTo(base * CFrame.new(0, -3 * v, 0))
        end)
        dragonBase = base * CFrame.new(0, -3, 0)
        task.wait(1.4)
        -- كسر السقف بشظايا وغبار
        task.spawn(breakCeiling)
        playShot(shotTrack(Vector3.new(-34, 66, -140), function()
                return holeCenter
        end), 3.5)
        -- الصعود عبر الفتحة (حركة مرئية كاملة، بدون teleport)
        task.spawn(function()
                local target = Vector3.new(0, 115, -168)
                local targetCF = CFrame.new(target) * (dragonBase - dragonBase.Position)
                tweenNumber(0, 1, 7, function(v)
                        dragon:PivotTo(dragonBase:Lerp(targetCF, v))
                end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                dragonBase = targetCF
        end)
        playShot(shotFollow(function()
                return Vector3.new(30, 10, 34)
        end), 6)
        -- الطيران السينمائي متعدد اللقطات
        flying = true
        flyThrough({
                Vector3.new(0, 115, -168),
                Vector3.new(0, 150, -60),
                Vector3.new(90, 190, 60),
                Vector3.new(-90, 235, -20),
                Vector3.new(30, 330, -520),
                Vector3.new(150, 430, -960),
        })
        flapLoop()
        -- لقطة من قدام القلعة والتنين طاير فوقها
        playShot(shotTrack(Vector3.new(0, 40, 40), function()
                return dragonPivot().Position
        end), 7)
        -- لقطة جانبية متابعة
        playShot(shotFollow(function()
                return Vector3.new(42, 6, 0)
        end), 8)
        -- لقطة قريبة على الراس والفارس
        playShot(shotFollow(function()
                return Vector3.new(14, 3, 20)
        end, nil, 6), 7)
        -- لقطة جوية من فوق
        playShot(shotFollow(function()
                return Vector3.new(0, 55, 12)
        end), 7)
        -- لقطة مدارية
        playShot(shotOrbit(function()
                return dragonPivot().Position
        end, 46, 10, 0, 2.2, 9), 9)
        -- اللقطة الختامية: ظل التنين في ضوء القمر
        camera.FieldOfView = 55
        camShot = shotTrack(Vector3.new(235, 425, -1005), function()
                return dragonPivot().Position
        end)
        while flying do
                task.wait(0.5)
        end
        task.wait(3)
        dragonBase = dragon:GetPivot()
        motionLock = false
        -- النهاية: مدار بطيء حوالين التنين تحت ضوء القمر
        local t0 = os.clock()
        camShot = function()
                local c = dragonPivot().Position
                local a = (os.clock() - t0) * 0.15
                return CFrame.lookAt(c + Vector3.new(math.cos(a) * 40, 12, math.sin(a) * 40), c)
        end
        titleShow("صحوة التنين الأسود", "اكتمل المشهد - اضغط Esc ثم Reset للعودة")
        state = "end"
end

--========================================================================
--  حالة اللعبة + مشغلات الاقتراب
--========================================================================
RunService.Heartbeat:Connect(function()
        if state == "gate_wait" and not doorOpenedAnim then
                local hrp = getHRP()
                if hrp then
                        local d = (Vector2.new(hrp.Position.X, hrp.Position.Z) - Vector2.new(0, -92)).Magnitude
                        if d < CONFIG.GateDistance then
                                task.spawn(runGateScene)
                        end
                end
        elseif state == "awaken_wait" and dragon then
                local hrp = getHRP()
                if hrp then
                        local d = (Vector2.new(hrp.Position.X, hrp.Position.Z) - Vector2.new(0, -160)).Magnitude
                        if d < CONFIG.DragonDistance then
                                task.spawn(runAwakening)
                        end
                end
        end
end)

local introDone = false

player.CharacterAdded:Connect(function(char)
        if not introDone then return end
        task.wait(0.6)
        local hrp = char:WaitForChild("HumanoidRootPart", 10)
        if hrp then
                char:PivotTo(CFrame.lookAt(Vector3.new(0, 5, 92), Vector3.new(0, 5, 0)))
        end
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = 70
        camShot = nil
        player.CameraMode = Enum.CameraMode.LockFirstPerson
        if state == "end" then
                setHint("المشهد خلص - اضغط Esc واعمل Reset تاني عشان تفرج من الأول")
        elseif doorOpened then
                state = "awaken_wait"
                setHint("ادخل حرم التنين")
        else
                state = "gate_wait"
                setHint("اتقدم ناحية البوابة العملاقة")
        end
end)

--========================================================================
--  البداية: لقطة افتتاحية جوية ثم منظور شخص أول
--========================================================================
local function runIntro()
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart", 10)
        if hrp then
                char:PivotTo(CFrame.lookAt(Vector3.new(0, 5, 92), Vector3.new(0, 5, 0)))
        end
        camera.CameraType = Enum.CameraType.Scriptable
        task.spawn(titleShow)
        fadeBlack(true, 0.4)
        fadeBlack(false, 2)
        -- لقطة افتتاحية جوية من بعيد لحد فوق اللاعب
        playShot(shotRailLook(
                Vector3.new(170, 130, 230),
                Vector3.new(6, 34, 58),
                Vector3.new(0, 42, -100),
                6.5
        ), 6.5)
        player.CameraMode = Enum.CameraMode.LockFirstPerson
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = 70
        introDone = true
        state = "gate_wait"
        setHint("اتقدم ناحية البوابة العملاقة للقلعة")
        if not dragon then
                setHint("مفيش موديل اسمه Dragon في Workspace! حط موديل التنين واعمل Reset")
        end
end

--========================================================================
--  تشغيل كل حاجة
--========================================================================
buildLighting()
buildGroundAndStairs()
buildCastleFront()
buildStatues()
buildTorches()
setupWater()
buildBuildings()
buildRoom()

dragon = findDragon()
prepareDragon()
makeSeat()

-- وضع النوم: الراس منخفضة شوية والعيون شبه مطفية
if headSet then
        headSet(CFrame.Angles(0.15, 0, 0))
end

task.spawn(runIntro)
