-- Grow a Garden 2 Auto Harvester & Seller by Antigravity
-- (Optimized: Safe Ultra Potato + Freeze + ANTI-AFK + BLACK SCREEN + MUTE + INSTANT MAX BATCH HARVEST + GARDEN MONITOR + SAVE CONFIG SAFE LOAD + MOBILE AUTO SCALE + AUTO KICK WEATHER + CUSTOM MINIMIZE LOGO + MUTATION FILTER)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FruitValueCalc = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("FruitValueCalc"))
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")



-- ==========================================
-- TUTORIAL BYPASS (COPIED FROM MAIN KAITUN)
-- ==========================================
task.spawn(function()
    for attempt = 1, 15 do
        if workspace:GetAttribute("InTutorial") ~= true and LocalPlayer:GetAttribute("TutorialCompleted") == true then
            break
        end
        pcall(function()
            local Networking = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Networking"))
            if Networking and Networking.Tutorial and Networking.Tutorial.Complete then
                Networking.Tutorial.Complete:Fire()
            end
        end)
        pcall(function() workspace:SetAttribute("InTutorial", nil) end)
        pcall(function() LocalPlayer:SetAttribute("TutorialCompleted", true) end)
        pcall(function()
            local ui = LocalPlayer:WaitForChild("PlayerGui", 5)
            local tutUi = ui and ui:FindFirstChild("TutorialUI")
            if tutUi then tutUi.Enabled = false end
        end)
        task.wait(1.5)
    end
end)

-- ==========================================
-- AUTO RECONNECT (ANTI-DISCONNECT)
-- ==========================================
task.spawn(function()
    local TeleportService = game:GetService("TeleportService")
    local CoreGui = game:GetService("CoreGui")
    
    local function Reconnect()
        task.wait(2)
        -- Jika hanya sendirian, masuk server baru
        if #Players:GetPlayers() <= 1 then
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        else
            -- Coba gabung kembali ke server yang sama
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
            task.wait(2)
            -- Fallback masuk server random
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
    end
    
    pcall(function()
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 10):WaitForChild("promptOverlay", 10)
        if promptOverlay then
            -- Handle jika error sudah muncul sebelum script selesai diload
            for _, child in ipairs(promptOverlay:GetChildren()) do
                if child.Name == 'ErrorPrompt' then
                    Reconnect()
                end
            end
            -- Deteksi jika error muncul tiba-tiba saat AFK
            promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == 'ErrorPrompt' then
                    Reconnect()
                end
            end)
        end
    end)
end)


-- Menunggu elemen map penting termuat sebelum melanjutkan agar tidak crash
local Terrain = Workspace:WaitForChild("Terrain", 30)
local Gardens = Workspace:WaitForChild("Gardens", 30)

-- ==========================================
-- PINDAH & BARINGKAN PAPAN NAMA + PAGAR (ULTIMATE JEMBATAN RAPAT)
-- ==========================================
task.spawn(function()
    if Gardens then
        local myPlot = nil
        for _, plot in ipairs(Gardens:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId or plot:GetAttribute("Owner") == LocalPlayer.Name then
                myPlot = plot
                break
            end
        end
        
        if myPlot then
            local signsFolder = myPlot:FindFirstChild("Signs")
            local gardenSign = signsFolder and signsFolder:FindFirstChild("Garden")
            local expandSign = signsFolder and signsFolder:FindFirstChild("Expand")
            
            local hardcodedCFrame = CFrame.new(401.185547, 146.503998 - 3.2, -131.671997, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            local baseCFrame = hardcodedCFrame
            
            local plot1 = nil
            for _, p in ipairs(Gardens:GetChildren()) do
                local num = string.match(p.Name, "%d+")
                if num == "1" then plot1 = p; break end
            end
            if not plot1 then plot1 = Gardens:GetChildren()[1] end
            
            if plot1 and myPlot ~= plot1 then
                pcall(function()
                    local relative = plot1:GetPivot():ToObjectSpace(hardcodedCFrame)
                    baseCFrame = myPlot:GetPivot() * relative
                end)
            end
            
            local rotatedBase = baseCFrame * CFrame.Angles(0, math.rad(-90), 0)
            
            if gardenSign then
                local gardenTarget = rotatedBase * CFrame.Angles(math.rad(90), 0, 1.6)
                pcall(function()
                    if gardenSign:IsA("Model") then gardenSign:PivotTo(gardenTarget) else gardenSign.CFrame = gardenTarget end
                end)
            end
            
            if expandSign then
                local expandTarget = rotatedBase * CFrame.new(-6, 0, -5) * CFrame.Angles(math.rad(90), 0, 0)
                pcall(function()
                    if expandSign:IsA("Model") then expandSign:PivotTo(expandTarget) else expandSign.CFrame = expandTarget end
                end)
            end
            
            local visual = myPlot:FindFirstChild("Visual")
            if visual then
                local fences = {}
                for _, child in ipairs(visual:GetChildren()) do
                    if string.find(child.Name, "Fence") then
                        table.insert(fences, child)
                    end
                end
                
                if #fences > 0 then
                    -- JEMBATAN SUPER RAPAT & PAS TENGAH
                    local cols = 3 -- Lebar jembatan (2 lajur)
                    local spacingForward = 2 -- Dibuat menumpuk rapat agar celah tertutup total!
                    local spacingSide = 3.2 
                    
                    -- SETTING GESER: Angka ini akan menarik jembatan pas ke garis tengah
                    local geserKeKanan = 0 
                    
                    for i, fence in ipairs(fences) do
                        local row = math.floor((i-1) / cols)
                        local col = (i-1) % cols
                        
                        local forwardOffset = -10 - (row * spacingForward)
                        local sideOffset = ((col - (cols-1)/2) * spacingSide) + geserKeKanan
                        
                        local targetCFrame = rotatedBase * CFrame.new(forwardOffset, 0, sideOffset) 
                                             * CFrame.Angles(math.rad(90), 0, 0)
                        
                        pcall(function()
                            if fence:IsA("Model") then
                                fence:PivotTo(targetCFrame)
                            elseif fence:IsA("BasePart") then
                                fence.CFrame = targetCFrame
                            end
                        end)
                    end
                end
            end
        end
    end
end)

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local FruitVisualizer
pcall(function()
    FruitVisualizer = require(LocalPlayer.PlayerScripts.Controllers.FruitVisualizerController)
end)

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules", 5)
local Packet = SharedModules and SharedModules:WaitForChild("Packet", 5)
local RemoteEvent = Packet and Packet:WaitForChild("RemoteEvent", 5)
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ==========================================
-- ANTI-VOID & ANTI-DEATH FAILSAFE
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local char = game.Players.LocalPlayer.Character
            if not char then return end
            
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            if root and hum then
                -- Anggap jatuh jika Y < -15, anggap mau mati jika HP < 20
                local isFalling = root.Position.Y < -15
                local isDying = hum.Health > 0 and hum.Health < 20
                
                if isFalling or isDying then
                    -- 1. Hentikan momentum jatuh
                    root.Velocity = Vector3.new(0, 0, 0)
                    
                    -- 2. Teleport ke Steven atau ke udara sebagai tempat aman
                    local steven = workspace:FindFirstChild("Steven", true)
                    if steven and (steven:IsA("Model") and steven.PrimaryPart) then
                        root.CFrame = steven.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
                    else
                        root.CFrame = CFrame.new(0, 100, 0)
                    end
                    
                    print("[!] ANTI-VOID / ANTI-DEATH ACTIVATED! Teleported to safety.")
                    task.wait(3) -- Jeda agar tidak spam
                end
            end
        end)
    end
end)
local function createSprinklerBuffer(pos, plotId, sprinklerName)
    local nameLen = string.len(sprinklerName)
    local buf = buffer.create(15 + nameLen + 1)
    buffer.writeu16(buf, 0, 20)
    buffer.writef32(buf, 2, pos.X)
    buffer.writef32(buf, 6, pos.Y)
    buffer.writef32(buf, 10, pos.Z)
    buffer.writeu8(buf, 14, nameLen)
    buffer.writestring(buf, 15, sprinklerName)
    buffer.writeu8(buf, 15 + nameLen, plotId)
    return buf
end

local function createWaterBuffer(pos, toolName)
    local nameLen = string.len(toolName)
    local buf = buffer.create(15 + nameLen)
    buffer.writeu16(buf, 0, 67)
    buffer.writef32(buf, 2, pos.X)
    buffer.writef32(buf, 6, pos.Y)
    buffer.writef32(buf, 10, pos.Z)
    buffer.writeu8(buf, 14, nameLen)
    buffer.writestring(buf, 15, toolName)
    return buf
end

local function equipTool(toolName)
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local function matchTool(name)
        if name == toolName then return true end
        
        if string.find(toolName, "Water") then
            if string.find(toolName, "Common") and string.find(name, "Common") and string.find(name, "Water") then return true end
            if string.find(toolName, "Super") and string.find(name, "Super") and string.find(name, "Water") then return true end
        end
        
        if string.find(toolName, "Sprinkler") and string.find(name, "Sprinkler") then
            local tier = string.split(toolName, " ")[1]
            if tier and string.find(name, tier) then return true end
        end
        
        return false
    end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and matchTool(child.Name) then
            return child
        end
    end

    for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if child:IsA("Tool") and matchTool(child.Name) then
            pcall(function() 
                humanoid:UnequipTools()
                task.wait(0.1)
                humanoid:EquipTool(child) 
            end)
            task.wait(0.2)
            return child
        end
    end
    return nil
end

local function flyToTarget(targetPos)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return false end
    
    local root = char.HumanoidRootPart
    local hum = char.Humanoid
    local finalTarget = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    local distance = (root.Position - finalTarget).Magnitude
    if distance <= 8 then return true end 
    
    hum.PlatformStand = true 
    
    local noclipConnection
    noclipConnection = game:GetService("RunService").Stepped:Connect(function()
        if char then
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end
    end)
    
    local speed = 30 -- Diubah jadi 30 sesuai request user (Flight Mode lambat aman)
    local tweenTime = distance / speed
    if tweenTime > 15 then tweenTime = 15 end -- Maksimal tunggu 15 detik kalau terlalu jauh banget
    
    local TweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(finalTarget)})
    
    tween:Play()
    tween.Completed:Wait()
    
    if noclipConnection then noclipConnection:Disconnect() end
    root.Velocity = Vector3.zero
    hum.PlatformStand = false 
    
    task.wait(0.2)
    return (root.Position - finalTarget).Magnitude <= 20
end

local function ensureAtTarget(targetPos)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if not char or not root or not hum or hum.Health <= 0 then
        -- Tunggu respawn maksimal 8 detik
        local elapsed = 0
        while elapsed < 8 do
            task.wait(1)
            elapsed = elapsed + 1
            char = LocalPlayer.Character
            hum = char and char:FindFirstChild("Humanoid")
            root = char and char:FindFirstChild("HumanoidRootPart")
            if char and root and hum and hum.Health > 0 then
                break
            end
        end
        if char and root and hum and hum.Health > 0 then
            flyToTarget(targetPos)
            task.wait(0.5)
        end
    else
        local target3D = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
        if (root.Position - target3D).Magnitude > 4 then
            flyToTarget(targetPos)
            task.wait(0.5)
        end
    end
end

local plotCache = {}
local lastSprinklerTime = {}

-- SplashRadius resmi dari ReplicatedStorage.SharedModules.WateringcanData.
-- Kalengnya cuma dua kelas: biasa/syrup 5 stud, super 8 stud.
local Siram = {}
Siram.RADIUS = {
    ["Common Watering Can"] = 5,
    ["Syrup Watering Can"] = 5,
    ["Super Watering Can"] = 8,
    ["Super Syrup Watering Can"] = 8,
}
Siram.RADIUS_BAWAAN = 5

-- Radius terkecil di antara kaleng yang dipilih. Sengaja yang terkecil: titik
-- yang bagus untuk radius 5 tetap bagus dipakai kaleng radius 8, sebaliknya
-- tidak -- titik yang dioptimalkan untuk 8 bisa meleset kalau yang kepakai
-- ternyata kaleng syrup biasa.
function Siram.radius(daftarTool)
    local r = nil
    if type(daftarTool) == "table" then
        for _, nama in ipairs(daftarTool) do
            local v = Siram.RADIUS[nama]
            if v and (not r or v < r) then r = v end
        end
    end
    return r or Siram.RADIUS_BAWAAN
end

-- Titik yang mencakup tanaman sejenis TERBANYAK dalam satu semprotan.
--
-- Dulu cache hanya menyimpan satu posisi per nama seed dan ditimpa terus oleh
-- tanaman terakhir yang kebetulan diiterasi -- praktis acak. Dengan ratusan
-- tanaman yang tidak ditanam rapat, yang tersiram sering justru yang berdiri
-- sendirian.
--
-- Perbandingan jarak dilakukan di bidang XZ saja: semprotan menyebar mendatar,
-- dan beda tinggi antar tanaman tidak menentukan kena atau tidak.
function Siram.titikTerpadat(daftar, radius)
    local n = #daftar
    if n == 0 then return nil, 0 end
    if n == 1 then return daftar[1], 1 end

    -- Grid spasial. Tanpa ini pencariannya O(n^2) -- pada 600 tanaman itu
    -- 360.000 pengukuran jarak tiap kali dihitung, tiap detik, per akun.
    -- Sisi sel = radius, jadi tetangga dalam radius pasti berada di 3x3 sel
    -- di sekitarnya dan tidak ada yang terlewat.
    local sel = {}
    for i = 1, n do
        local p = daftar[i]
        local kunci = math.floor(p.X / radius) .. ":" .. math.floor(p.Z / radius)
        local isi = sel[kunci]
        if not isi then isi = {}; sel[kunci] = isi end
        isi[#isi + 1] = i
    end

    local r2 = radius * radius
    local terbaik, jumlahTerbaik = daftar[1], -1
    for i = 1, n do
        local p = daftar[i]
        local gx, gz = math.floor(p.X / radius), math.floor(p.Z / radius)
        local jumlah = 0
        for dx = -1, 1 do
            for dz = -1, 1 do
                local isi = sel[(gx + dx) .. ":" .. (gz + dz)]
                if isi then
                    for _, j in ipairs(isi) do
                        local q = daftar[j]
                        local ddx, ddz = q.X - p.X, q.Z - p.Z
                        if ddx * ddx + ddz * ddz <= r2 then
                            jumlah = jumlah + 1
                        end
                    end
                end
            end
        end
        if jumlah > jumlahTerbaik then
            jumlahTerbaik = jumlah
            terbaik = p
        end
    end
    return terbaik, jumlahTerbaik
end

-- Rekam SEMUA posisi per nama seed, bukan satu.
--
-- Tabelnya dibangun baru lalu ditukar, tidak ditambahkan ke yang lama: fungsi
-- ini dipanggil berulang dari loop tiap detik, dan menambah ke daftar yang
-- sudah ada akan membuatnya tumbuh tanpa henti sampai memori habis.
function Siram.rekam(cData, plants)
    if not plants then return end
    local baru = {}
    for _, p in ipairs(plants:GetChildren()) do
        local sName = p:GetAttribute("SeedName")
        local root = p:FindFirstChild("HumanoidRootPart") or p:FindFirstChildWhichIsA("BasePart")
        if sName and root then
            local daftar = baru[sName]
            if not daftar then daftar = {}; baru[sName] = daftar end
            daftar[#daftar + 1] = root.Position
        end
    end
    cData.Plants = baru
end

task.spawn(function()
    while task.wait(1) do
        local gardens = Workspace:FindFirstChild("Gardens")
        if gardens then
            for _, plot in ipairs(gardens:GetChildren()) do
                local ownerAttr = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
                if ownerAttr then
                    if not plotCache[ownerAttr] then plotCache[ownerAttr] = { Plants = {} } end
                    local cData = plotCache[ownerAttr]
                    cData.PlotNum = tonumber(string.match(plot.Name, "%d+")) or 1
                    
                    local visual = plot:FindFirstChild("Visual")
                    Siram.rekam(cData, plot:FindFirstChild("Plants"))

                    if visual then
                        local pp = visual:FindFirstChild("PullPoint")
                        if pp and pp:FindFirstChild("TouchInterest") then
                            cData.PullCenter = pp.Position
                        end
                    end
                end
            end
        end
    end
end)

local function getPlotByOwner(ownerName)
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens or not ownerName or ownerName == "None" then return nil end
    for _, plot in pairs(gardens:GetChildren()) do
        local ownerAttr = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
        if ownerAttr == ownerName then
            if not plotCache[ownerName] then plotCache[ownerName] = { Plants = {} } end
            local cData = plotCache[ownerName]
            cData.PlotNum = tonumber(string.match(plot.Name, "%d+")) or 1
            
            local visual = plot:FindFirstChild("Visual")
            Siram.rekam(cData, plot:FindFirstChild("Plants"))

            -- PullCenter dulu dihitung ulang untuk SETIAP tanaman, lalu yang
            -- tersimpan adalah hasil tanaman terakhir -- ikut acak seperti
            -- posisi targetnya. Biayanya juga jumlah_tanaman x jumlah_PlantArea
            -- tiap panggilan, dan fungsi ini dipanggil tiap detik.
            --
            -- Sekarang: titik tengah seluruh PlantArea, dihitung sekali saja.
            -- Pemakainya cuma butuh ARAH ke tengah kebun untuk menggeser posisi
            -- berdiri dan sprinkler, jadi titik tengah justru lebih stabil.
            if visual and not cData.PullCenter then
                local jml, sx, sy, sz = 0, 0, 0, 0
                for _, obj in ipairs(visual:GetChildren()) do
                    if obj:IsA("BasePart") and string.find(obj.Name, "PlantArea") then
                        jml = jml + 1
                        sx, sy, sz = sx + obj.Position.X, sy + obj.Position.Y, sz + obj.Position.Z
                    end
                end
                if jml > 0 then
                    cData.PullCenter = Vector3.new(sx / jml, sy / jml, sz / jml)
                end
            end
            return plot
        end
    end
    return nil
end

-- Hasilnya di-cache: pencarian titik terpadat tidak perlu diulang tiap detik
-- karena kebun tidak berubah secepat itu, dan loop ini jalan di 8-10 akun
-- sekaligus pada satu perangkat.
Siram.cacheTitik = {}

local function getPlantPos(ownerName, seedName, radius)
    getPlotByOwner(ownerName)   -- dipanggil demi efek sampingnya: menyegarkan plotCache
    local cData = plotCache[ownerName]
    if not cData or not cData.Plants then return nil, 0 end

    local daftar = cData.Plants[seedName]
    if not daftar or #daftar == 0 then return nil, 0 end

    radius = radius or Siram.RADIUS_BAWAAN
    local kunci = ownerName .. "|" .. seedName .. "|" .. tostring(radius)
    local simpan = Siram.cacheTitik[kunci]

    -- Dihitung ulang kalau jumlah tanamannya berubah (ada yang panen/tanam) atau
    -- hasil lama sudah lebih dari 15 detik.
    if simpan and simpan.n == #daftar and (os.clock() - simpan.t) < 15 then
        return simpan.pos, simpan.cakupan
    end

    local pos, cakupan = Siram.titikTerpadat(daftar, radius)
    Siram.cacheTitik[kunci] = { pos = pos, cakupan = cakupan, n = #daftar, t = os.clock() }
    return pos, cakupan
end

local function getActiveSprinklerCount(plot, sprinklerName)
    local count = 0
    if plot then
        local sprs = plot:FindFirstChild("Sprinklers")
        if sprs then
            for _, obj in pairs(sprs:GetChildren()) do
                local sprName = obj:GetAttribute("SprinklerName")
                if sprName == sprinklerName or string.find(obj.Name, sprinklerName) then
                    count = count + 1
                end
            end
        end
    end
    return count
end


-- ==========================================
-- CALCULATION LOGIC & PARSING (REVISI FINAL)
-- ==========================================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function formatPrice(n)
    if type(n) ~= "number" then return "0" end
    n = math.floor(n)
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    if not left then return tostring(n) end
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function parseNumber(str)
    str = string.lower(str)
    str = string.gsub(str, ",", "")
    local numStr, suffix = string.match(str, "^%s*([%d%.]+)%s*([kmb]?)")
    if not numStr then return 0 end
    local num = tonumber(numStr)
    if not num then return 0 end
    if suffix == "k" then num = num * 1000
    elseif suffix == "m" then num = num * 1000000
    elseif suffix == "b" then num = num * 1000000000
    end
    return num
end

local function getStockMultiplier(fruitName)
    local gui = PlayerGui:FindFirstChild("FruitStockPrice")
    if gui then
        local scroll = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("ScrollingFrame")
        if scroll then
            for _, child in ipairs(scroll:GetChildren()) do
                if child.Name == "FruitCard" then
                    local tooltip = child:GetAttribute("SeedToolTip") or ""
                    if tooltip == fruitName or tooltip == (fruitName .. " Seed") or tooltip == (fruitName .. " Spores") then
                        local frame = child:FindFirstChild("Frame")
                        if frame and frame:FindFirstChild("Multiplier") then
                            local text = frame.Multiplier.Text
                            local num = tonumber(string.match(text, "[%d%.]+"))
                            if num then return num end
                        end
                    end
                end
            end
        end
    end
    return 1
end

local function getFruitBasePrice(fruitName)
    local gui = PlayerGui:FindFirstChild("FruitStockPrice")
    if gui then
        local scroll = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("ScrollingFrame")
        if scroll then
            for _, child in ipairs(scroll:GetChildren()) do
                if child.Name == "FruitCard" then
                    local tooltip = child:GetAttribute("SeedToolTip") or ""
                    if tooltip == fruitName or tooltip == (fruitName .. " Seed") or tooltip == (fruitName .. " Spores") then
                        local frame = child:FindFirstChild("Frame")
                        if frame then
                            local priceLabel = frame:FindFirstChild("Price") or frame:FindFirstChild("BasePrice")
                            if priceLabel and priceLabel:IsA("TextLabel") then
                                return parseNumber(priceLabel.Text)
                            end
                            -- Fallback cari label yang menunjukkan harga
                            for _, lbl in ipairs(frame:GetDescendants()) do
                                if lbl:IsA("TextLabel") and (lbl.Name:lower():match("price") or lbl.Name:lower():match("value")) then
                                    local parsed = parseNumber(lbl.Text)
                                    if parsed > 0 then return parsed end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return 0 
end
-- ==========================================
-- MUTATION DATA (dari wiki: growagarden2.fandom.com/wiki/Mutations)
-- ==========================================
local MUTATION_LIST = {
    -- Standard Mutations
    {Name = "Gold", Multiplier = 10, Category = "Standard"},
    {Name = "Rainbow", Multiplier = 30, Category = "Standard"},
    -- Environmental Mutations
    {Name = "Bloodlit", Multiplier = 60, Category = "Environmental"},
    {Name = "Electric", Multiplier = 25, Category = "Environmental"},
    {Name = "Starstruck", Multiplier = 50, Category = "Environmental"},
    {Name = "Frozen", Multiplier = 14, Category = "Environmental"},
    {Name = "Aurora", Multiplier = 1.5, Category = "Environmental"},
    {Name = "Ignited", Multiplier = 60, Category = "Environmental"},
    {Name = "Eclipsed", Multiplier = 80, Category = "Environmental"},
    {Name = "Glow", Multiplier = 100, Category = "Environmental"},
    -- Unreleased Mutations
    {Name = "Secret", Multiplier = 0, Category = "Unreleased"},
    {Name = "Solarflare", Multiplier = 5, Category = "Unreleased"},
    {Name = "Pizza", Multiplier = 5, Category = "Unreleased"},
    {Name = "Chained", Multiplier = 8, Category = "Unreleased"},
}

-- Warna untuk tiap mutasi
local MUTATION_COLORS = {
    ["Gold"] = Color3.fromRGB(255, 214, 0),
    ["Rainbow"] = Color3.fromRGB(255, 100, 100),
    ["Bloodlit"] = Color3.fromRGB(204, 0, 0),
    ["Electric"] = Color3.fromRGB(100, 200, 255),
    ["Starstruck"] = Color3.fromRGB(255, 238, 0),
    ["Frozen"] = Color3.fromRGB(131, 255, 230),
    ["Aurora"] = Color3.fromRGB(0, 255, 157),
    ["Ignited"] = Color3.fromRGB(255, 102, 0),
    ["Eclipsed"] = Color3.fromRGB(80, 5, 184),
    ["Glow"] = Color3.fromRGB(255, 226, 130),
    ["Secret"] = Color3.fromRGB(180, 180, 180),
    ["Solarflare"] = Color3.fromRGB(244, 255, 100),
    ["Pizza"] = Color3.fromRGB(255, 180, 100),
    ["Chained"] = Color3.fromRGB(160, 0, 255),
}

-- ==========================================
-- UTILS & CONFIG VARIABLES
-- ==========================================
local autoHarvestEnabled = false
local autoHarvestMode = "Any"
local autoHarvestThreshold = 0.0
local duplicateHarvestEnabled = false
local multiHarvestBatchAmount = 10 -- BRUTAL SPEED: 20 buah sekaligus
local autoSellEnabled = false
local sellThreshold = 0.0
local sellBlacklist = {} -- {["Gold"] = true, ...}
local sellNoMutation = true -- Jika true, kita BOLEH jual buah normal. Jika false, buah normal di-blacklist.
local fruitsHidden = false 
local ultraBoostEnabled = false
local antiAfkEnabled = false
local autoNukeOthersEnabled = false
local destroyAllPlantsEnabled = false
local muteAudioEnabled = false

-- Mutation Filter State
local mutationFilterEnabled = false
local selectedMutations = {} -- {["Gold"] = true, ["Rainbow"] = true, ...}
local harvestNoMutation = false -- Jika true, juga panen buah TANPA mutasi

local autoWaterEnabled = false
local autoWaterDelay = 30
local commonWaterCount = 5
local superWaterCount = 1
local selectedWaterTool = {"Super Watering Can"}
local selectedSprinklerTool = {"Super Sprinkler"}
local selectedWaterOwner = "None"
local selectedWaterSeed = "None"

local selectedKickWeathers = {}
local weatherPhaseOptions = {
    "-- MOON WEATHER --",
    "Goldmoon", "Bloodmoon", "Rainbow Moon", "Mega Moon", "Chained Moon", "Pizza Moon",
    "-- NORMAL WEATHER --",
    "Lightning", "Lightning Storm", "Rain", "Snowfall", "Aurora", "Starfall", 
    "Eclipse", "Sunburst", "Rainbow", "Blizzard"
}

-- ==========================================
-- AUTO TROWEL CONFIG + UI (satu tabel hemat local)
-- ==========================================
local Trowel = {
    -- config
    enabled = false,
    mode = "Good", -- "Good" / "Player" / "Saved" / "Random"
    seedFilter = "All", -- "All" atau nama seed spesifik (misal "Coconut")
    savedPos = nil, -- Vector3, disimpan via tombol Save
    moved = {}, -- plantModel → true, dedup pohon yang sudah dipindah
    retries = {}, -- plantId → count, retry limit per pohon
    pendingVerify = {}, -- plantId → {prePos, target}, async verification
    delay = 0.1, -- delay antar move (detik), throttle server
}

local recentlyHarvested = setmetatable({}, {__mode = "k"})
local originalVolumes = {}
local CONFIG_FILE = "GardenHelper_Config.json"

local utilityTools = {
    ["Basic Pot"] = true, ["Watering Can"] = true, ["Trowel"] = true,
    ["Super Trowel"] = true, ["Golden Trowel"] = true,
    ["Infinite Watering Can"] = true, ["Seed Bag"] = true,
}

local function isSellableFruit(item)
    if item:IsA("Configuration") and item:GetAttribute("HarvestedFruit") == true then return true end
    if item:IsA("Tool") and item:GetAttribute("HarvestedFruit") == true then return true end
    if not item:IsA("Tool") then return false end
    if utilityTools[item.Name] then return false end
    local patterns = {"Pot", "Can", "Trowel", "Bag", "Fertilizer", "Axe", "Pickaxe", "Shovel"}
    for _, p in ipairs(patterns) do
        if item.Name:find(p) then return false end
    end
    return true
end

-- ==========================================
-- CONFIG SYSTEM (SAVE/LOAD)
-- ==========================================
local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local success, decoded = pcall(function() 
            return HttpService:JSONDecode(readfile(CONFIG_FILE)) 
        end)
        if success and type(decoded) == "table" then
            autoHarvestEnabled = decoded.autoHarvest or false
            autoHarvestMode = decoded.autoHarvestMode or "Any"
            autoHarvestThreshold = decoded.autoHarvestThreshold or 0.0
            duplicateHarvestEnabled = decoded.duplicateHarvest or false
            autoSellEnabled = decoded.autoSell or false
            sellThreshold = decoded.sellThreshold or 0.0
            if decoded.sellBlacklist ~= nil then sellBlacklist = decoded.sellBlacklist end
            if decoded.sellNoMutation ~= nil then sellNoMutation = decoded.sellNoMutation end
            fruitsHidden = decoded.fruitsHidden or false
            ultraBoostEnabled = decoded.ultraBoost or false
            antiAfkEnabled = decoded.antiAfk or false
            autoNukeOthersEnabled = decoded.autoNukeOthers or false
            destroyAllPlantsEnabled = decoded.destroyAllPlants or false
            muteAudioEnabled = decoded.mute or false
            selectedKickWeathers = decoded.kickWeathers or {}
            
            -- Muat mutation filter config
            mutationFilterEnabled = decoded.mutationFilter or false
            selectedMutations = decoded.selectedMutations or {}
            harvestNoMutation = decoded.harvestNoMutation or false
            
            autoWaterEnabled = decoded.autoWaterEnabled or false
            autoWaterDelay = decoded.autoWaterDelay or 30
            commonWaterCount = decoded.commonWaterCount or 5
            superWaterCount = decoded.superWaterCount or 1
            selectedWaterTool = decoded.selectedWaterTool or {"Super Watering Can"}
            if type(selectedWaterTool) == "string" then
                if selectedWaterTool == "None" then selectedWaterTool = {} else selectedWaterTool = {selectedWaterTool} end
            end
            selectedSprinklerTool = decoded.selectedSprinklerTool or {"Super Sprinkler"}
            if type(selectedSprinklerTool) == "string" then
                if selectedSprinklerTool == "None" then selectedSprinklerTool = {} else selectedSprinklerTool = {selectedSprinklerTool} end
            end
            selectedWaterOwner = decoded.selectedWaterOwner or "None"
            selectedWaterSeed = decoded.selectedWaterSeed or "None"

            -- Memuat posisi logo jika ada
            if decoded.logoPosition then
                logoPos = UDim2.new(decoded.logoPosition.X.Scale, decoded.logoPosition.X.Offset, decoded.logoPosition.Y.Scale, decoded.logoPosition.Y.Offset)
                if MinimizedLogo then MinimizedLogo.Position = logoPos end
            end

            -- Auto Trowel config
            Trowel.enabled = decoded.autoTrowel or false
            Trowel.mode = decoded.trowelMode or "Good"
            Trowel.seedFilter = decoded.trowelSelectedSeed or "All"
            if decoded.trowelSavedPos then
                Trowel.savedPos = Vector3.new(decoded.trowelSavedPos.X, decoded.trowelSavedPos.Y, decoded.trowelSavedPos.Z)
            end
            Trowel.delay = math.min(decoded.trowelDelay or 0.1, 0.3)
        end
    end
end

local function saveConfig()
    if writefile then
        local config = {
            autoHarvest = autoHarvestEnabled,
            autoHarvestMode = autoHarvestMode,
            autoHarvestThreshold = autoHarvestThreshold,
            duplicateHarvest = duplicateHarvestEnabled,
            autoSell = autoSellEnabled,
            sellThreshold = sellThreshold,
            sellBlacklist = sellBlacklist,
            sellNoMutation = sellNoMutation,
            fruitsHidden = fruitsHidden,
            ultraBoost = ultraBoostEnabled,
            antiAfk = antiAfkEnabled,
            autoNukeOthers = autoNukeOthersEnabled,
            destroyAllPlants = destroyAllPlantsEnabled,
            mute = muteAudioEnabled,
            kickWeathers = selectedKickWeathers,
            mutationFilter = mutationFilterEnabled,
            selectedMutations = selectedMutations,
            harvestNoMutation = harvestNoMutation,
            autoWaterEnabled = autoWaterEnabled,
            autoWaterDelay = autoWaterDelay,
            commonWaterCount = commonWaterCount,
            superWaterCount = superWaterCount,
            selectedWaterTool = selectedWaterTool,
            selectedSprinklerTool = selectedSprinklerTool,
            selectedWaterOwner = selectedWaterOwner,
            selectedWaterSeed = selectedWaterSeed,
            autoTrowel = Trowel.enabled,
            trowelMode = Trowel.mode,
            trowelSelectedSeed = Trowel.seedFilter,
            trowelSavedPos = Trowel.savedPos and {X = Trowel.savedPos.X, Y = Trowel.savedPos.Y, Z = Trowel.savedPos.Z} or nil,
            trowelDelay = Trowel.delay,
            logoPosition = {
                X = {Scale = 0.5, Offset = 0}, 
                Y = {Scale = 0.5, Offset = 0}
            }
        }
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end)
    end
end

-- Muat konfigurasi sebelum UI dibuat
loadConfig()

-- ==========================================
-- HIDE FRUITS & PROPS FUNCTION
-- ==========================================
local function toggleFruits(hide)
    if not Gardens then return end
    
    for _, plot in ipairs(Gardens:GetChildren()) do
        local props = plot:FindFirstChild("Props")
        if props then
            for _, desc in ipairs(props:GetDescendants()) do
                if desc:IsA("BasePart") and desc.Name ~= "HarvestPart" then
                    desc.LocalTransparencyModifier = hide and 1 or 0
                    if hide then
                        desc.Anchored = true
                        desc.CanCollide = false
                        desc.CanTouch = false
                        desc.CanQuery = false
                    end
                end
            end
        end
        
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local fruitsFolder = plant:FindFirstChild("Fruits")
                if fruitsFolder then
                    for _, desc in ipairs(fruitsFolder:GetDescendants()) do
                        if desc:IsA("BasePart") and desc.Name ~= "HarvestPart" then
                            desc.LocalTransparencyModifier = hide and 1 or 0
                            if hide then
                                desc.Anchored = true
                                desc.CanCollide = false
                                desc.CanTouch = false
                                desc.CanQuery = false
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ==========================================
-- UI SETUP (WAJIB PAKAI PLAYERGUI)
-- ==========================================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("GardenHarvesterSellerUI") then
    PlayerGui.GardenHarvesterSellerUI:Destroy()
end
if PlayerGui:FindFirstChild("GardenHarvesterBlackScreen") then
    PlayerGui.GardenHarvesterBlackScreen:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GardenHarvesterSellerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- BLACK SCREEN UI (GPU Saver)
local BlackScreenGui = Instance.new("ScreenGui")
BlackScreenGui.Name = "GardenHarvesterBlackScreen"
BlackScreenGui.ResetOnSpawn = false
BlackScreenGui.DisplayOrder = -99
BlackScreenGui.IgnoreGuiInset = true
BlackScreenGui.Enabled = false
BlackScreenGui.Parent = PlayerGui

local BlackScreen = Instance.new("Frame")
BlackScreen.Name = "BlackScreenSaver"
BlackScreen.Size = UDim2.new(1, 0, 1, 0)
BlackScreen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BlackScreen.Visible = true
BlackScreen.Parent = BlackScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 675)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5) 
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ZIndex = 10000 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(36, 47, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- LOGO MINIMIZE SETUP
local MinimizedLogo = Instance.new("ImageButton")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Size = UDim2.new(0, 75, 0, 75)
MinimizedLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizedLogo.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizedLogo.Image = "rbxassetid://104624206636533"
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
MinimizedLogo.BackgroundTransparency = 0
MinimizedLogo.BorderSizePixel = 0
MinimizedLogo.Visible = false
MinimizedLogo.ZIndex = 10005
MinimizedLogo.Parent = ScreenGui

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 15)
LogoCorner.Parent = MinimizedLogo

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = Color3.fromRGB(36, 47, 65)
LogoStroke.Thickness = 2
LogoStroke.Parent = MinimizedLogo

-- ==========================================
-- AUTO SCALE UNTUK MOBILE SUPPORT
-- ==========================================
local UIScale = Instance.new("UIScale")
UIScale.Parent = MainFrame

local function updateScale()
    local viewportSize = Workspace.CurrentCamera.ViewportSize
    local padding = 40
    
    local scaleX = (viewportSize.X - padding) / 360
    local scaleY = (viewportSize.Y - padding) / 675
    
    UIScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.3, 1)
end

Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale() 

local DropShadow = Instance.new("ImageLabel")
DropShadow.Name = "DropShadow"
DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
DropShadow.Size = UDim2.new(1, 40, 1, 40)
DropShadow.BackgroundTransparency = 1
DropShadow.Image = "rbxassetid://6014261993"
DropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
DropShadow.ImageTransparency = 0.55
DropShadow.ScaleType = Enum.ScaleType.Slice
DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
DropShadow.ZIndex = 9999
DropShadow.Parent = MainFrame

local dragging = false
local dragStart, startPos
local logoDragging = false
local logoDragStart, logoStartPos

local HeaderFrame = Instance.new("Frame")
HeaderFrame.Size = UDim2.new(1, 0, 0, 48)
HeaderFrame.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
HeaderFrame.BorderSizePixel = 0
HeaderFrame.ZIndex = 10001
HeaderFrame.Parent = MainFrame
Instance.new("UICorner", HeaderFrame).CornerRadius = UDim.new(0, 12)

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 15)
HeaderCover.Position = UDim2.new(0, 0, 1, -15)
HeaderCover.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 10001
HeaderCover.Parent = HeaderFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "FRAME HARVEST"
TitleLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 10002
TitleLabel.Parent = HeaderFrame


local ModeBtn = Instance.new("TextButton")
ModeBtn.Size = UDim2.new(0, 32, 0, 32)
ModeBtn.Position = UDim2.new(1, -120, 0.5, -16)
ModeBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 65)
ModeBtn.Text = "🔄"
ModeBtn.TextColor3 = Color3.fromRGB(156, 163, 175)
ModeBtn.Font = Enum.Font.GothamBold
ModeBtn.TextSize = 16
ModeBtn.ZIndex = 10002
ModeBtn.Parent = HeaderFrame
Instance.new("UICorner", ModeBtn).CornerRadius = UDim.new(0, 8)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 32, 0, 32)
MinimizeBtn.Position = UDim2.new(1, -80, 0.5, -16)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 65)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(251, 191, 36)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.ZIndex = 10002
MinimizeBtn.Parent = HeaderFrame
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
CloseBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 65)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.ZIndex = 10002
CloseBtn.Parent = HeaderFrame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- ==========================================
-- LOGIKA MINIMIZE & RESTORE
-- ==========================================
local function toggleMenu(show)
    MainFrame.Visible = show
    MinimizedLogo.Visible = not show
    
    if show then
        MainFrame.ZIndex = 10000 
    end
end

ModeBtn.MouseButton1Click:Connect(function()
    local ts = game:GetService("TweenService")
    local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    if MainFrame.Size.X.Offset == 360 then
        -- To Landscape
        ts:Create(MainFrame, ti, {Size = UDim2.new(0, 650, 0, 360)}):Play()
    else
        -- To Portrait
        ts:Create(MainFrame, ti, {Size = UDim2.new(0, 360, 0, 675)}):Play()
    end
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    toggleMenu(false)
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    if BlackScreenGui then BlackScreenGui:Destroy() end
end)

-- ==========================================
-- DRAG LOGIC UNTUK UI & LOGO (DIPERBAIKI)
-- ==========================================
local isLogoMoved = false

HeaderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

MinimizedLogo.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        logoDragging = true
        isLogoMoved = false
        logoDragStart = input.Position
        logoStartPos = MinimizedLogo.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        if logoDragging then
            logoDragging = false
            saveConfig()
            if not isLogoMoved then
                toggleMenu(true)
            end
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + (delta.X / UIScale.Scale), 
            startPos.Y.Scale, startPos.Y.Offset + (delta.Y / UIScale.Scale)
        )
    end
    
    if logoDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - logoDragStart
        if delta.Magnitude > 5 then
            isLogoMoved = true
        end
        if isLogoMoved then
            MinimizedLogo.Position = UDim2.new(
                logoStartPos.X.Scale, logoStartPos.X.Offset + delta.X, 
                logoStartPos.Y.Scale, logoStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

-- ==========================================
-- SCROLLING FRAME & BUTTON LOGIC
-- ==========================================
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -30, 0, 30)
TabContainer.Position = UDim2.new(0, 15, 0, 55)
TabContainer.BackgroundTransparency = 1
TabContainer.ZIndex = 10001
TabContainer.Parent = MainFrame

local TabHarvest = Instance.new("TextButton")
TabHarvest.Size = UDim2.new(0.5, -5, 1, 0)
TabHarvest.Position = UDim2.new(0, 0, 0, 0)
TabHarvest.BackgroundColor3 = Color3.fromRGB(31, 41, 65)
TabHarvest.Text = "HARVEST MODE"
TabHarvest.TextColor3 = Color3.fromRGB(59, 130, 246)
TabHarvest.Font = Enum.Font.GothamBold
TabHarvest.TextSize = 11
TabHarvest.ZIndex = 10002
TabHarvest.Parent = TabContainer
Instance.new("UICorner", TabHarvest).CornerRadius = UDim.new(0, 6)

local TabMoze = Instance.new("TextButton")
TabMoze.Size = UDim2.new(0.5, -5, 1, 0)
TabMoze.Position = UDim2.new(0.5, 5, 0, 0)
TabMoze.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
TabMoze.Text = "MOZE MODE"
TabMoze.TextColor3 = Color3.fromRGB(100, 116, 139)
TabMoze.Font = Enum.Font.GothamBold
TabMoze.TextSize = 11
TabMoze.ZIndex = 10002
TabMoze.Parent = TabContainer
Instance.new("UICorner", TabMoze).CornerRadius = UDim.new(0, 6)

local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, -30, 1, -135)
ContentFrame.Position = UDim2.new(0, 15, 0, 95)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ScrollBarThickness = 2
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentFrame.ZIndex = 10001
ContentFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = ContentFrame

local DiscordFooter = Instance.new("TextButton")
DiscordFooter.Name = "DiscordFooter"
DiscordFooter.Size = UDim2.new(1, -30, 0, 30)
DiscordFooter.Position = UDim2.new(0, 15, 1, -35)
DiscordFooter.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
DiscordFooter.Text = "Join Discord untuk Update (Klik Copy)"
DiscordFooter.TextColor3 = Color3.fromRGB(255, 255, 255)
DiscordFooter.Font = Enum.Font.GothamBold
DiscordFooter.TextSize = 11
DiscordFooter.ZIndex = 10002
DiscordFooter.Parent = MainFrame

local DiscordCorner = Instance.new("UICorner", DiscordFooter)
DiscordCorner.CornerRadius = UDim.new(0, 6)

DiscordFooter.MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard("https://discord.gg/vWm3FF4NWU")
            DiscordFooter.Text = "Link Tercopy ke Clipboard!"
            task.wait(2)
            DiscordFooter.Text = "Join Discord untuk Update (Klik Copy)"
        end
    end)
end)

-- ==========================================
-- KICK WEATHER LOGIC INITIALIZATION
-- ==========================================
local function checkWeatherKick()
    local shouldKick = false
    local kickReason = ""

    -- 1. Cek Metode Lama (Workspace)
    local currentPhase = Workspace:GetAttribute("ActivePhase") or ""
    local currentWeather = Workspace:GetAttribute("ActiveWeather") or ""
    
    if currentPhase ~= "" and selectedKickWeathers[currentPhase] then
        shouldKick = true
        kickReason = currentPhase
    elseif currentWeather ~= "" and selectedKickWeathers[currentWeather] then
        shouldKick = true
        kickReason = currentWeather
    end

    -- 2. Cek Metode Baru (ReplicatedStorage.WeatherValues)
    local WeatherValues = game:GetService("ReplicatedStorage"):FindFirstChild("WeatherValues")
    if WeatherValues and not shouldKick then
        for weatherName, isSelected in pairs(selectedKickWeathers) do
            if isSelected then
                local attr1 = weatherName .. "_Playing"
                local attr2 = weatherName
                
                if WeatherValues:GetAttribute(attr1) == true or WeatherValues:GetAttribute(attr2) == true then
                    shouldKick = true
                    kickReason = weatherName
                    break
                end
            end
        end
    end

    if shouldKick then
        pcall(function()
            LocalPlayer:Kick("Auto-Kicked: Server memasuki cuaca/fase [" .. kickReason .. "]")
        end)
        task.wait(2)
        pcall(function() game:Shutdown() end)
    end
end

Workspace:GetAttributeChangedSignal("ActivePhase"):Connect(checkWeatherKick)
Workspace:GetAttributeChangedSignal("ActiveWeather"):Connect(checkWeatherKick)
pcall(function()
    game:GetService("ReplicatedStorage"):WaitForChild("WeatherValues").AttributeChanged:Connect(checkWeatherKick)
end)

-- LOOP BRUTAL UNTUK MEMASTIKAN TIDAK ADA YANG LOLOS (CEK TIAP 1 DETIK)
task.spawn(function()
    while true do
        task.wait(1)
        checkWeatherKick()
    end
end)

-- ==========================================
-- MUTE AUDIO FUNCTION
-- ==========================================
local function updateAudioMute()
    for _, obj in pairs(game:GetDescendants()) do
        if obj:IsA("Sound") then
            if muteAudioEnabled then
                if originalVolumes[obj] == nil then originalVolumes[obj] = obj.Volume end
                obj.Volume = 0
            else
                if originalVolumes[obj] ~= nil then obj.Volume = originalVolumes[obj] end
            end
        end
    end
end

game.DescendantAdded:Connect(function(obj)
    if obj:IsA("Sound") then
        task.wait()
        if muteAudioEnabled then
            if originalVolumes[obj] == nil then originalVolumes[obj] = obj.Volume end
            obj.Volume = 0
        end
    end
end)

-- ==========================================
-- DROPDOWN OVERLAY (GLOBAL)
-- ==========================================
local DropdownOverlay = Instance.new("Frame")
DropdownOverlay.Size = UDim2.new(1, 0, 1, 0)
DropdownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DropdownOverlay.BackgroundTransparency = 0.6
DropdownOverlay.ZIndex = 20000
DropdownOverlay.Visible = false
DropdownOverlay.Parent = MainFrame

local DropdownModal = Instance.new("Frame")
DropdownModal.Size = UDim2.new(0.85, 0, 0.7, 0)
DropdownModal.Position = UDim2.new(0.5, 0, 0.5, 0)
DropdownModal.AnchorPoint = Vector2.new(0.5, 0.5)
DropdownModal.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
DropdownModal.BorderSizePixel = 0
DropdownModal.ZIndex = 20001
DropdownModal.Parent = DropdownOverlay
Instance.new("UICorner", DropdownModal).CornerRadius = UDim.new(0, 12)
local modalStroke = Instance.new("UIStroke", DropdownModal)
modalStroke.Color = Color3.fromRGB(59, 130, 246)
modalStroke.Thickness = 1.5

local DropdownTitle = Instance.new("TextLabel")
DropdownTitle.Size = UDim2.new(1, -40, 0, 40)
DropdownTitle.Position = UDim2.new(0, 15, 0, 0)
DropdownTitle.BackgroundTransparency = 1
DropdownTitle.Text = "PILIH OPSI"
DropdownTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownTitle.Font = Enum.Font.GothamBold
DropdownTitle.TextSize = 13
DropdownTitle.TextXAlignment = Enum.TextXAlignment.Left
DropdownTitle.ZIndex = 20002
DropdownTitle.Parent = DropdownModal

local DropdownCloseIcon = Instance.new("TextButton")
DropdownCloseIcon.Size = UDim2.new(0, 30, 0, 30)
DropdownCloseIcon.Position = UDim2.new(1, -35, 0, 5)
DropdownCloseIcon.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
DropdownCloseIcon.BackgroundTransparency = 1
DropdownCloseIcon.Text = "X"
DropdownCloseIcon.TextColor3 = Color3.fromRGB(239, 68, 68)
DropdownCloseIcon.Font = Enum.Font.GothamBold
DropdownCloseIcon.TextSize = 16
DropdownCloseIcon.ZIndex = 20002
DropdownCloseIcon.Parent = DropdownModal
DropdownCloseIcon.MouseButton1Click:Connect(function() DropdownOverlay.Visible = false end)

local DropdownLine = Instance.new("Frame")
DropdownLine.Size = UDim2.new(1, -30, 0, 1)
DropdownLine.Position = UDim2.new(0, 15, 0, 38)
DropdownLine.BackgroundColor3 = Color3.fromRGB(36, 47, 65)
DropdownLine.BorderSizePixel = 0
DropdownLine.ZIndex = 20002
DropdownLine.Parent = DropdownModal

local DropdownScroll = Instance.new("ScrollingFrame")
DropdownScroll.Size = UDim2.new(1, -20, 1, -55)
DropdownScroll.Position = UDim2.new(0, 10, 0, 45)
DropdownScroll.BackgroundTransparency = 1
DropdownScroll.BorderSizePixel = 0
DropdownScroll.ScrollBarThickness = 3
DropdownScroll.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
DropdownScroll.ZIndex = 20002
DropdownScroll.Parent = DropdownModal

local DropdownListLayout = Instance.new("UIListLayout")
DropdownListLayout.SortOrder = Enum.SortOrder.LayoutOrder
DropdownListLayout.Padding = UDim.new(0, 5)
DropdownListLayout.Parent = DropdownScroll

local function openDropdown(title, options, onSelect)
    DropdownTitle.Text = string.upper(title)
    for _, child in ipairs(DropdownScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local contentHeight = 0
    for _, opt in ipairs(options) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
        btn.Text = "  " .. tostring(opt)
        btn.TextColor3 = Color3.fromRGB(226, 232, 240)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 20003
        btn.Parent = DropdownScroll
        
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        btn.MouseButton1Click:Connect(function()
            DropdownOverlay.Visible = false
            onSelect(opt)
        end)
        contentHeight = contentHeight + 37
    end
    DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 5)
    DropdownOverlay.Visible = true
end

local function openMultiDropdown(title, options, currentSelections, onApply)
    DropdownTitle.Text = string.upper(title)
    for _, child in ipairs(DropdownScroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
    end
    
    local tempSelected = {}
    if type(currentSelections) == "table" then
        for _, v in ipairs(currentSelections) do
            tempSelected[v] = true
        end
    elseif type(currentSelections) == "string" and currentSelections ~= "None" then
        tempSelected[currentSelections] = true
    end

    local contentHeight = 0
    for _, opt in ipairs(options) do
        if opt == "None" then continue end
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
        btn.Text = "  " .. tostring(opt)
        btn.TextColor3 = Color3.fromRGB(226, 232, 240)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 20003
        btn.Parent = DropdownScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        local check = Instance.new("Frame")
        check.Size = UDim2.new(0, 16, 0, 16)
        check.Position = UDim2.new(1, -26, 0.5, -8)
        check.BackgroundColor3 = tempSelected[opt] and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
        check.ZIndex = 20004
        check.Parent = btn
        Instance.new("UICorner", check).CornerRadius = UDim.new(0, 4)
        
        btn.MouseButton1Click:Connect(function()
            tempSelected[opt] = not tempSelected[opt]
            check.BackgroundColor3 = tempSelected[opt] and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
        end)
        contentHeight = contentHeight + 37
    end
    
    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(1, -10, 0, 36)
    applyBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
    applyBtn.Text = "TERAPKAN"
    applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 13
    applyBtn.ZIndex = 20003
    applyBtn.Parent = DropdownScroll
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 6)
    
    applyBtn.MouseButton1Click:Connect(function()
        DropdownOverlay.Visible = false
        local results = {}
        for _, opt in ipairs(options) do
            if tempSelected[opt] then
                table.insert(results, opt)
            end
        end
        onApply(results)
    end)
    
    contentHeight = contentHeight + 45
    DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 5)
    DropdownOverlay.Visible = true
end

-- ==========================================
-- UI CARDS CREATION HELPERS
-- ==========================================
local function createCard(name, height, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 10001
    card.Parent = ContentFrame
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card)
    stroke.Color = Color3.fromRGB(31, 41, 55)
    return card
end

local function createToggle(label, card, yPos, defaultState, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 30)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.ZIndex = 10002
    row.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(226, 232, 240)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10002
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Name = "Toggle_" .. label:gsub("%s+", "")
    btn.Size = UDim2.new(0, 60, 0, 26)
    btn.Position = UDim2.new(1, -60, 0.5, -13)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
    btn.Text = defaultState and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.ZIndex = 10002
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 13)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = defaultState and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(75, 85, 99)

    local isOn = defaultState
    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        btn.Text = isOn and "ON" or "OFF"
        btn.BackgroundColor3 = isOn and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
        stroke.Color = isOn and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(75, 85, 99)
        onToggle(isOn)
    end)
    return btn
end

-- ==========================================
-- UI CONTENT CREATION
-- ==========================================
-- 1. HARVEST CARD
local HarvestCard = createCard("HarvestCard", 150, 1)
local HarvestLabel = Instance.new("TextLabel", HarvestCard)
HarvestLabel.Size = UDim2.new(1, -20, 0, 25)
HarvestLabel.Position = UDim2.new(0, 10, 0, 5)
HarvestLabel.BackgroundTransparency = 1
HarvestLabel.Text = "AUTO HARVEST CONFIG"
HarvestLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
HarvestLabel.Font = Enum.Font.GothamBold
HarvestLabel.TextSize = 11
HarvestLabel.TextXAlignment = Enum.TextXAlignment.Left
HarvestLabel.ZIndex = 10002

createToggle("Enable Auto-Harvest", HarvestCard, 32, autoHarvestEnabled, function(state) autoHarvestEnabled = state end)

local ModeRow = Instance.new("Frame", HarvestCard)
ModeRow.Size = UDim2.new(1, -20, 0, 30)
ModeRow.Position = UDim2.new(0, 10, 0, 68)
ModeRow.BackgroundTransparency = 1
ModeRow.ZIndex = 10002

local ModeLabel = Instance.new("TextLabel", ModeRow)
ModeLabel.Size = UDim2.new(0.5, 0, 1, 0)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "Harvest Weight Mode"
ModeLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ModeLabel.Font = Enum.Font.GothamMedium
ModeLabel.TextSize = 12
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ModeLabel.ZIndex = 10002

local CycleBtn = Instance.new("TextButton", ModeRow)
CycleBtn.Size = UDim2.new(0, 130, 0, 28)
CycleBtn.Position = UDim2.new(1, -130, 0.5, -14)
CycleBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
CycleBtn.Text = autoHarvestMode .. (autoHarvestMode == "Any" and " Weight" or " Threshold")
CycleBtn.TextColor3 = Color3.fromRGB(241, 245, 249)
CycleBtn.Font = Enum.Font.GothamMedium
CycleBtn.TextSize = 11
CycleBtn.ZIndex = 10002
Instance.new("UICorner", CycleBtn).CornerRadius = UDim.new(0, 6)

local modes = {"Any Weight", "Above Threshold", "Below Threshold"}
local currentModeIndex = 1
for i, m in ipairs(modes) do
    if m:find(autoHarvestMode) then currentModeIndex = i end
end

CycleBtn.MouseButton1Click:Connect(function()
    currentModeIndex = currentModeIndex % #modes + 1
    CycleBtn.Text = modes[currentModeIndex]
    autoHarvestMode = modes[currentModeIndex]:split(" ")[1]
end)

local ThresholdRow = Instance.new("Frame", HarvestCard)
ThresholdRow.Size = UDim2.new(1, -20, 0, 30)
ThresholdRow.Position = UDim2.new(0, 10, 0, 104)
ThresholdRow.BackgroundTransparency = 1
ThresholdRow.ZIndex = 10002

local ThresholdLabel = Instance.new("TextLabel", ThresholdRow)
ThresholdLabel.Size = UDim2.new(0.6, 0, 1, 0)
ThresholdLabel.BackgroundTransparency = 1
ThresholdLabel.Text = "Weight Threshold (kg)"
ThresholdLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ThresholdLabel.Font = Enum.Font.GothamMedium
ThresholdLabel.TextSize = 12
ThresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
ThresholdLabel.ZIndex = 10002

local ThresholdInput = Instance.new("TextBox", ThresholdRow)
ThresholdInput.Size = UDim2.new(0, 80, 0, 28)
ThresholdInput.Position = UDim2.new(1, -80, 0.5, -14)
ThresholdInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
ThresholdInput.Text = tostring(autoHarvestThreshold)
ThresholdInput.TextColor3 = Color3.fromRGB(255, 255, 255)
ThresholdInput.Font = Enum.Font.GothamMedium
ThresholdInput.TextSize = 12
ThresholdInput.ZIndex = 10002
Instance.new("UICorner", ThresholdInput).CornerRadius = UDim.new(0, 6)

ThresholdInput.Focused:Connect(function()
    -- MATIKAN AUTO HARVEST SECARA OTOMATIS SAAT USER KLIK KOTAK (MULAI MENGETIK)
    if autoHarvestEnabled then
        autoHarvestEnabled = false
        local autoHarvestToggleBtn = HarvestCard:FindFirstChild("Toggle_EnableAuto-Harvest", true)
        if autoHarvestToggleBtn then
            autoHarvestToggleBtn.Text = "OFF"
            autoHarvestToggleBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
            local stroke = autoHarvestToggleBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
        end
    end
end)

ThresholdInput.FocusLost:Connect(function()
    local num = tonumber(ThresholdInput.Text)
    if not num then
        ThresholdInput.Text = tostring(autoHarvestThreshold)
        return
    end
    
    if num > 200 then
        -- BUAT CUSTOM UI MODAL DI TENGAH LAYAR
        local modalBg = Instance.new("Frame")
        modalBg.Size = UDim2.new(1, 0, 1, 0)
        modalBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        modalBg.BackgroundTransparency = 0.5
        modalBg.ZIndex = 99999
        modalBg.Parent = ScreenGui
        
        local modalBox = Instance.new("Frame")
        modalBox.Size = UDim2.new(0, 300, 0, 160)
        modalBox.Position = UDim2.new(0.5, -150, 0.5, -80)
        modalBox.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
        modalBox.ZIndex = 100000
        modalBox.Parent = modalBg
        Instance.new("UICorner", modalBox).CornerRadius = UDim.new(0, 10)
        Instance.new("UIStroke", modalBox).Color = Color3.fromRGB(248, 113, 113)
        
        local mTitle = Instance.new("TextLabel")
        mTitle.Size = UDim2.new(1, 0, 0, 40)
        mTitle.BackgroundTransparency = 1
        mTitle.Text = "⚠️ KONFIRMASI"
        mTitle.TextColor3 = Color3.fromRGB(248, 113, 113)
        mTitle.Font = Enum.Font.GothamBold
        mTitle.TextSize = 18
        mTitle.ZIndex = 100001
        mTitle.Parent = modalBox
        
        local mText = Instance.new("TextLabel")
        mText.Size = UDim2.new(1, -20, 0, 60)
        mText.Position = UDim2.new(0, 10, 0, 40)
        mText.BackgroundTransparency = 1
        mText.Text = "Yakin mau setting harvest ke " .. num .. "kg?\nAngka ini sangat besar!"
        mText.TextColor3 = Color3.fromRGB(226, 232, 240)
        mText.Font = Enum.Font.GothamMedium
        mText.TextSize = 14
        mText.TextWrapped = true
        mText.ZIndex = 100001
        mText.Parent = modalBox
        
        local btnYes = Instance.new("TextButton")
        btnYes.Size = UDim2.new(0.4, 0, 0, 35)
        btnYes.Position = UDim2.new(0.06, 0, 1, -45)
        btnYes.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        btnYes.Text = "IYA"
        btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnYes.Font = Enum.Font.GothamBold
        btnYes.TextSize = 14
        btnYes.ZIndex = 100001
        btnYes.Parent = modalBox
        Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)
        
        local btnNo = Instance.new("TextButton")
        btnNo.Size = UDim2.new(0.4, 0, 0, 35)
        btnNo.Position = UDim2.new(0.54, 0, 1, -45)
        btnNo.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        btnNo.Text = "ENGGA"
        btnNo.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnNo.Font = Enum.Font.GothamBold
        btnNo.TextSize = 14
        btnNo.ZIndex = 100001
        btnNo.Parent = modalBox
        Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)
        
        btnYes.MouseButton1Click:Connect(function()
            autoHarvestThreshold = num
            ThresholdInput.Text = tostring(num)
            modalBg:Destroy()
        end)
        
        btnNo.MouseButton1Click:Connect(function()
            ThresholdInput.Text = tostring(autoHarvestThreshold)
            modalBg:Destroy()
        end)
        
        return
    end
    
    autoHarvestThreshold = num
    
    -- MATIKAN AUTO HARVEST SECARA OTOMATIS SAAT USER GANTI KG
    if autoHarvestEnabled then
        autoHarvestEnabled = false
        local autoHarvestToggleBtn = HarvestCard:FindFirstChild("Toggle_EnableAuto-Harvest", true)
        if autoHarvestToggleBtn then
            autoHarvestToggleBtn.Text = "OFF"
            autoHarvestToggleBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
            local stroke = autoHarvestToggleBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
        end
    end
end)

-- ==========================================
-- 2. MUTATION FILTER CARD (BARU!)
-- ==========================================
local MutationCard = createCard("MutationCard", 270, 2)

local MutCardTitle = Instance.new("TextLabel", MutationCard)
MutCardTitle.Size = UDim2.new(1, -20, 0, 25)
MutCardTitle.Position = UDim2.new(0, 10, 0, 5)
MutCardTitle.BackgroundTransparency = 1
MutCardTitle.Text = "FILTER MUTASI (HARVEST)"
MutCardTitle.TextColor3 = Color3.fromRGB(251, 191, 36)
MutCardTitle.Font = Enum.Font.GothamBold
MutCardTitle.TextSize = 11
MutCardTitle.TextXAlignment = Enum.TextXAlignment.Left
MutCardTitle.ZIndex = 10002

createToggle("Enable Mutation Filter", MutationCard, 30, mutationFilterEnabled, function(state) 
    mutationFilterEnabled = state 
end)

createToggle("HANYA Panen Non-Mutasi", MutationCard, 62, harvestNoMutation, function(state) 
    harvestNoMutation = state 
end)

-- Label info
local MutInfoLabel = Instance.new("TextLabel", MutationCard)
MutInfoLabel.Size = UDim2.new(1, -20, 0, 16)
MutInfoLabel.Position = UDim2.new(0, 10, 0, 94)
MutInfoLabel.BackgroundTransparency = 1
MutInfoLabel.Text = "Pilih mutasi yang ingin dipanen:"
MutInfoLabel.TextColor3 = Color3.fromRGB(156, 163, 175)
MutInfoLabel.Font = Enum.Font.GothamMedium
MutInfoLabel.TextSize = 10
MutInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
MutInfoLabel.ZIndex = 10002

-- Quick Action Buttons (Select All / Clear All)
local MutSelectAllBtn = Instance.new("TextButton", MutationCard)
MutSelectAllBtn.Size = UDim2.new(0.45, -5, 0, 22)
MutSelectAllBtn.Position = UDim2.new(0.03, 0, 0, 112)
MutSelectAllBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
MutSelectAllBtn.Text = "Pilih Semua"
MutSelectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MutSelectAllBtn.Font = Enum.Font.GothamBold
MutSelectAllBtn.TextSize = 10
MutSelectAllBtn.ZIndex = 10003
Instance.new("UICorner", MutSelectAllBtn).CornerRadius = UDim.new(0, 6)

local MutClearAllBtn = Instance.new("TextButton", MutationCard)
MutClearAllBtn.Size = UDim2.new(0.45, -5, 0, 22)
MutClearAllBtn.Position = UDim2.new(0.52, 0, 0, 112)
MutClearAllBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
MutClearAllBtn.Text = "Hapus Semua"
MutClearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MutClearAllBtn.Font = Enum.Font.GothamBold
MutClearAllBtn.TextSize = 10
MutClearAllBtn.ZIndex = 10003
Instance.new("UICorner", MutClearAllBtn).CornerRadius = UDim.new(0, 6)

-- Scrollable Multi-Select Mutation List
local MutScrollContainer = Instance.new("ScrollingFrame", MutationCard)
MutScrollContainer.Size = UDim2.new(1, -20, 0, 94)
MutScrollContainer.Position = UDim2.new(0, 10, 0, 138)
MutScrollContainer.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
MutScrollContainer.BorderSizePixel = 0
MutScrollContainer.ScrollBarThickness = 3
MutScrollContainer.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
MutScrollContainer.ZIndex = 10002
Instance.new("UICorner", MutScrollContainer).CornerRadius = UDim.new(0, 6)
local MutScrollStroke = Instance.new("UIStroke", MutScrollContainer)
MutScrollStroke.Color = Color3.fromRGB(36, 47, 65)

local MutScrollLayout = Instance.new("UIListLayout", MutScrollContainer)
MutScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
MutScrollLayout.Padding = UDim.new(0, 3)

-- Menyimpan referensi tombol agar bisa update visual
local mutationButtons = {}

local function updateMutationButtonVisual(mutName, btn, isSelected)
    local mutColor = MUTATION_COLORS[mutName] or Color3.fromRGB(209, 213, 219)
    if isSelected then
        btn.BackgroundColor3 = Color3.fromRGB(31, 41, 65)
        btn.TextColor3 = mutColor
    else
        btn.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
        btn.TextColor3 = Color3.fromRGB(100, 100, 100)
    end
end

-- Populate mutation checkboxes
local mutScrollHeight = 0
for idx, mutData in ipairs(MUTATION_LIST) do
    local mutName = mutData.Name
    local isSelected = selectedMutations[mutName] or false
    local mutColor = MUTATION_COLORS[mutName] or Color3.fromRGB(209, 213, 219)
    
    local row = Instance.new("Frame", MutScrollContainer)
    row.Size = UDim2.new(1, -6, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = idx
    row.ZIndex = 10002

    -- Checkbox indicator
    local checkLbl = Instance.new("TextLabel", row)
    checkLbl.Size = UDim2.new(0, 22, 1, 0)
    checkLbl.Position = UDim2.new(0, 2, 0, 0)
    checkLbl.BackgroundTransparency = 1
    checkLbl.Text = isSelected and "[X]" or "[ ]"
    checkLbl.TextColor3 = isSelected and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(100, 100, 100)
    checkLbl.TextSize = 13
    checkLbl.Font = Enum.Font.GothamBold
    checkLbl.ZIndex = 10003

    -- Mutation name + info
    local multiplierText = mutData.Multiplier > 0 and (tostring(mutData.Multiplier) .. "x") or "TBA"
    local displayText = string.format("%s (%s) [%s]", mutName, multiplierText, mutData.Category)
    
    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -80, 1, 0)
    nameLbl.Position = UDim2.new(0, 26, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = displayText
    nameLbl.TextColor3 = isSelected and mutColor or Color3.fromRGB(100, 100, 100)
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 10
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 10003

    -- Toggle button per mutation
    local toggleBtn = Instance.new("TextButton", row)
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ""
    toggleBtn.ZIndex = 10004

    toggleBtn.MouseButton1Click:Connect(function()
        isSelected = not isSelected
        selectedMutations[mutName] = isSelected or nil -- nil jika false untuk menjaga tabel bersih
        
        checkLbl.Text = isSelected and "[X]" or "[ ]"
        checkLbl.TextColor3 = isSelected and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(100, 100, 100)
        nameLbl.TextColor3 = isSelected and mutColor or Color3.fromRGB(100, 100, 100)
    end)

    -- Simpan referensi
    mutationButtons[mutName] = {
        check = checkLbl,
        name = nameLbl,
        color = mutColor,
        setSelected = function(sel)
            isSelected = sel
            selectedMutations[mutName] = sel or nil
            checkLbl.Text = sel and "[X]" or "[ ]"
            checkLbl.TextColor3 = sel and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(100, 100, 100)
            nameLbl.TextColor3 = sel and mutColor or Color3.fromRGB(100, 100, 100)
        end
    }

    mutScrollHeight = mutScrollHeight + 29
end
MutScrollContainer.CanvasSize = UDim2.new(0, 0, 0, mutScrollHeight)

-- Select All / Clear All handlers
MutSelectAllBtn.MouseButton1Click:Connect(function()
    for _, mutData in ipairs(MUTATION_LIST) do
        if mutationButtons[mutData.Name] then
            mutationButtons[mutData.Name].setSelected(true)
        end
    end
end)

MutClearAllBtn.MouseButton1Click:Connect(function()
    for _, mutData in ipairs(MUTATION_LIST) do
        if mutationButtons[mutData.Name] then
            mutationButtons[mutData.Name].setSelected(false)
        end
    end
    task.spawn(saveConfig)
end)

-- ==========================================
-- 3. AUTO SELL FILTER CARD
-- ==========================================
local AutoSellCard = createCard("AutoSellCard", 300, 3)

local autoSellFilterEnabled = false
local sellFilterOptions = {
    Fruit = "Any",
    Rarity = "Any",
    Mutation = "Any",
    ThresholdMode = "Any",
    ThresholdValue = 0
}

;(function()
    local SellCardTitle = Instance.new("TextLabel", AutoSellCard)
    SellCardTitle.Size = UDim2.new(1, -20, 0, 25)
    SellCardTitle.Position = UDim2.new(0, 10, 0, 5)
    SellCardTitle.BackgroundTransparency = 1
    SellCardTitle.Text = "AUTO SELL & FILTERS"
    SellCardTitle.TextColor3 = Color3.fromRGB(59, 130, 246)
    SellCardTitle.Font = Enum.Font.GothamBold
    SellCardTitle.TextSize = 11
    SellCardTitle.TextXAlignment = Enum.TextXAlignment.Left
    SellCardTitle.ZIndex = 10002

    createToggle("Enable Auto-Sell (ALL)", AutoSellCard, 30, autoSellEnabled, function(state) 
        autoSellEnabled = state 
        if state then autoSellFilterEnabled = false end 
        task.spawn(saveConfig)
    end)
    
    createToggle("Enable Auto-Sell (FILTER)", AutoSellCard, 55, autoSellFilterEnabled, function(state) 
        autoSellFilterEnabled = state 
        if state then autoSellEnabled = false end 
        task.spawn(saveConfig)
    end)
    
    local function createSellDropdown(title, yPos, options, defaultKey)
        local lbl = Instance.new("TextLabel", AutoSellCard)
        lbl.Size = UDim2.new(0.4, 0, 0, 22)
        lbl.Position = UDim2.new(0, 10, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = Color3.fromRGB(156, 163, 175)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 10002
    
        local btn = Instance.new("TextButton", AutoSellCard)
        btn.Size = UDim2.new(0.5, 0, 0, 22)
        btn.Position = UDim2.new(0.45, 0, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
        btn.Text = sellFilterOptions[defaultKey] or "Any"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.ZIndex = 10002
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
        btn.MouseButton1Click:Connect(function()
            openDropdown(title, options, function(selectedOpt)
                btn.Text = selectedOpt
                sellFilterOptions[defaultKey] = selectedOpt
            end)
        end)
    end
    
    createSellDropdown("Select Sell Fruit", 85, {"Any", "Carrot", "Apple", "Tomato", "Mushroom", "Coconut", "Strawberry", "Pomegranate", "Bamboo", "Corn", "Pumpkin"}, "Fruit")
    createSellDropdown("Select Sell Rarity", 115, {"Any", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}, "Rarity")
    createSellDropdown("Select Sell Mutation", 145, {"Any", "Gold", "Mega", "Rainbow", "Frozen"}, "Mutation")
    createSellDropdown("Select Threshold Mode", 175, {"Any", "Below (<)", "Above (>)", "Equal (==)"}, "ThresholdMode")
    
    local valLbl = Instance.new("TextLabel", AutoSellCard)
    valLbl.Size = UDim2.new(0.4, 0, 0, 22)
    valLbl.Position = UDim2.new(0, 10, 0, 205)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = "Threshold Weight/Value"
    valLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextSize = 10
    valLbl.TextXAlignment = Enum.TextXAlignment.Left
    valLbl.ZIndex = 10002

    local valBox = Instance.new("TextBox", AutoSellCard)
    valBox.Size = UDim2.new(0.5, 0, 0, 22)
    valBox.Position = UDim2.new(0.45, 0, 0, 205)
    valBox.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
    valBox.Text = tostring(sellFilterOptions.ThresholdValue)
    valBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    valBox.Font = Enum.Font.GothamBold
    valBox.TextSize = 10
    valBox.ZIndex = 10002
    Instance.new("UICorner", valBox).CornerRadius = UDim.new(0, 6)
    
    valBox.FocusLost:Connect(function()
        local num = tonumber(valBox.Text)
        if num then
            sellFilterOptions.ThresholdValue = num
        else
            valBox.Text = tostring(sellFilterOptions.ThresholdValue)
        end
    end)
    
    local forceBtn = Instance.new("TextButton", AutoSellCard)
    forceBtn.Size = UDim2.new(1, -20, 0, 25)
    forceBtn.Position = UDim2.new(0, 10, 0, 240)
    forceBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    forceBtn.Text = "FORCE SELL NOW (TEST)"
    forceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    forceBtn.Font = Enum.Font.GothamBold
    forceBtn.TextSize = 11
    forceBtn.ZIndex = 10002
    Instance.new("UICorner", forceBtn).CornerRadius = UDim.new(0, 6)
    
    forceBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            if typeof(PerformSell) == "function" then
                PerformSell()
            else
                print("[Test Sell] PerformSell belum terinisiasi, tunggu sebentar.")
            end
        end)
    end)
end)()

-- ==========================================
-- 4. KICK WEATHER CARD
-- ==========================================
local WeatherCard = createCard("WeatherCard", 160, 4)

local WeatherCardTitle = Instance.new("TextLabel", WeatherCard)
WeatherCardTitle.Size = UDim2.new(1, -20, 0, 25)
WeatherCardTitle.Position = UDim2.new(0, 10, 0, 5)
WeatherCardTitle.BackgroundTransparency = 1
WeatherCardTitle.Text = "AUTO-KICK WEATHER & PHASE"
WeatherCardTitle.TextColor3 = Color3.fromRGB(239, 68, 68) 
WeatherCardTitle.Font = Enum.Font.GothamBold
WeatherCardTitle.TextSize = 11
WeatherCardTitle.TextXAlignment = Enum.TextXAlignment.Left
WeatherCardTitle.ZIndex = 10002 

local ScrollContainer = Instance.new("ScrollingFrame", WeatherCard)
ScrollContainer.Size = UDim2.new(1, -20, 1, -35)
ScrollContainer.Position = UDim2.new(0, 10, 0, 30)
ScrollContainer.BackgroundTransparency = 1
ScrollContainer.ScrollBarThickness = 4
ScrollContainer.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
ScrollContainer.ZIndex = 10002

local ScrollLayout = Instance.new("UIListLayout", ScrollContainer)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Padding = UDim.new(0, 5)

local scrollHeight = 0
for i, weatherName in ipairs(weatherPhaseOptions) do
    if string.sub(weatherName, 1, 2) == "--" then
        local row = Instance.new("Frame", ScrollContainer)
        row.Size = UDim2.new(1, -10, 0, 20)
        row.BackgroundTransparency = 1
        row.LayoutOrder = i
        row.ZIndex = 10002 

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.gsub(weatherName, "%-", "") -- Hapus tanda strip (menjadi judul)
        lbl.TextColor3 = Color3.fromRGB(148, 163, 184)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.ZIndex = 10002 
        
        scrollHeight = scrollHeight + 25
    else
        local isSelected = selectedKickWeathers[weatherName] or false

        local row = Instance.new("Frame", ScrollContainer)
        row.Size = UDim2.new(1, -10, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = i
        row.ZIndex = 10002 

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = weatherName
        lbl.TextColor3 = Color3.fromRGB(226, 232, 240)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 10002 

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0, 50, 0, 22)
        btn.Position = UDim2.new(1, -50, 0.5, -11)
        btn.BackgroundColor3 = isSelected and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(55, 65, 81)
        btn.Text = isSelected and "KICK" or "SAFE"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.ZIndex = 10002 
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function()
            isSelected = not isSelected
            selectedKickWeathers[weatherName] = isSelected
            btn.Text = isSelected and "KICK" or "SAFE"
            btn.BackgroundColor3 = isSelected and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(55, 65, 81)
            checkWeatherKick()
        end)
        
        scrollHeight = scrollHeight + 33
    end
end
ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, scrollHeight)

-- ==========================================
-- 4. UTILITY CARD (FULL FIX DENGAN SEMUA FUNGSI)
-- ==========================================
local UtilityCard = createCard("UtilityCard", 700, 5) 

createToggle("Hide Fruits / Props (1x Toggle)", UtilityCard, 18, fruitsHidden, function(state)
    fruitsHidden = state
    if type(toggleFruits) == "function" then toggleFruits(state) end
end)
if fruitsHidden and type(toggleFruits) == "function" then task.spawn(function() toggleFruits(true) end) end

-- ==========================================
-- BRUTAL FPS BOOST DECLARATIONS
-- ==========================================
local function getParentType(desc)
    local current = desc
    local isFruit = false
    local isPlant = false
    while current and current ~= Workspace do
        if current.Name == "Fruits" then isFruit = true end
        if current.Name == "Plants" then isPlant = true end
        current = current.Parent
    end
    return isFruit, isPlant
end

local function superBrutalize(desc)
    if desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") or desc:IsA("Fire") or desc:IsA("Smoke") or desc:IsA("Sparkles") or desc:IsA("Light") or desc:IsA("PostEffect") or desc:IsA("Texture") or desc:IsA("Decal") or desc:IsA("SurfaceAppearance") then
        pcall(function() desc:Destroy() end)
        return
    end
    
    -- HAPUS TRACK HARVEST BUATAN GAME (HIJAU/PUTIH)
    local n = string.lower(desc.Name)
    if n:match("track") or n:match("trace") or n:match("arrow") or n:match("guide") or n:match("pointer") or n:match("waypoint") or n:match("highlight") then
        pcall(function() desc:Destroy() end)
        return
    end
    
    -- HAPUS LINGKARAN RADIUS SPRINKLER & ADORNMENT
    if desc:IsA("PVAdornment") or desc:IsA("HandleAdornment") or desc:IsA("SurfaceGui") then
        pcall(function() desc:Destroy() end)
        return
    end
    
    if desc:IsA("BillboardGui") and desc.Name ~= "FruitESP" then
        pcall(function() desc:Destroy() end)
        return
    end

    if desc:IsA("BasePart") then
        -- Deteksi brutal: Jika part ini ada di dalam model Sprinkler
        local parentModel = desc:FindFirstAncestorWhichIsA("Model")
        if parentModel and string.lower(parentModel.Name):match("sprinkler") then
            -- Hapus JIKA part ini besar (radius/ring pasti berukuran besar, sedangkan bodi sprinkler kecil)
            if desc.Size.X > 5 or desc.Size.Z > 5 then
                pcall(function() desc:Destroy() end)
                return
            end
            -- Hapus juga jika dia transparan (bodi sprinkler biasanya solid)
            if desc.Transparency > 0 then
                pcall(function() desc:Destroy() end)
                return
            end
        end
        
        if n:match("range") or n:match("radius") or n:match("area") or n:match("ring") or n:match("effect") or n:match("zone") or n:match("indicator") or n:match("visual") then
            pcall(function() desc:Destroy() end)
            return
        end
    end

    -- Hancurkan partikel, beam, mesh khusus, dan attachment yang sering digunakan untuk efek visual
    if desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") or desc:IsA("Fire") or desc:IsA("Smoke") or desc:IsA("Sparkles") or desc:IsA("Light") or desc:IsA("PostEffect") or desc:IsA("Texture") or desc:IsA("Decal") or desc:IsA("SurfaceAppearance") or desc:IsA("Attachment") or desc:IsA("SpecialMesh") then
        pcall(function() desc:Destroy() end)
        return
    end

    if desc:IsA("Motor6D") or desc:IsA("Animator") or desc:IsA("AnimationController") then
        pcall(function() desc:Destroy() end)
        return
    end
    if desc:IsA("BasePart") then
        desc.CastShadow = false
        local isFruit, isPlant = getParentType(desc)
           if desc.Name == "HarvestPart" then
            desc.Transparency = 1 
        elseif isFruit then
            desc.Transparency = 1
            desc.CanCollide = false
            if desc:IsA("MeshPart") then
                pcall(function() desc.TextureID = "" end)
            end
            desc.Material = Enum.Material.SmoothPlastic
            desc.Reflectance = 0
        elseif isPlant then
            if desc.Name ~= "Base" then
                desc.Transparency = 1
                desc.CanCollide = false 
            end
            desc.Anchored = true
        else
            desc.Material = Enum.Material.SmoothPlastic
            desc.Reflectance = 0
        end
    end
end

local function nukeEnvironment()
    local annoyingStuff = {"BirdVisuals", "Birds", "BlizzardBeams", "Weather", "Clouds", "Rain"}
    for _, name in ipairs(annoyingStuff) do
        local obj = Workspace:FindFirstChild(name)
        if obj then pcall(function() obj:Destroy() end) end
    end
    if Terrain then
        pcall(function()
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
            Terrain.Decoration = false
        end)
    end
end

local function optimizeWorld()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0 
        for _, child in pairs(Lighting:GetChildren()) do
            if child:IsA("BloomEffect") or child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then 
                child:Destroy() 
            end
        end
    end)
    nukeEnvironment()
    local char = LocalPlayer.Character
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if char and desc:IsDescendantOf(char) then continue end
        superBrutalize(desc)
    end
end

-- EVENT LISTENER: INSTANT BRUTALIZE NEWLY SPAWNED FRUITS (ANTI LAG SPAM AIR)
Workspace.DescendantAdded:Connect(function(desc)
    local char = LocalPlayer.Character
    if char and desc:IsDescendantOf(char) then return end
    
    task.defer(function()
        if not desc or not desc.Parent then return end
        
        if ultraBoostEnabled then
            superBrutalize(desc)
        end
        
        if fruitsHidden and desc:IsA("BasePart") and desc.Name ~= "HarvestPart" then
            local isFruit, isPlant = getParentType(desc)
            if isFruit or isPlant then
                desc.LocalTransparencyModifier = 1
                desc.Anchored = true
                desc.CanCollide = false
                desc.CanTouch = false
                desc.CanQuery = false
            end
        end
    end)
end)

createToggle("Brutal FPS Boost + Freeze", UtilityCard, 54, ultraBoostEnabled, function(state)
    ultraBoostEnabled = state
    if ultraBoostEnabled then task.spawn(optimizeWorld) end
end)
if ultraBoostEnabled then 
    task.spawn(function()
        task.wait(5)
        optimizeWorld()
    end)
end

createToggle("Enable GPU Saver (Blackscreen)", UtilityCard, 90, false, function(state)
    if BlackScreenGui then
        BlackScreenGui.Enabled = state
    end
end)

createToggle("Mute Game Audio", UtilityCard, 126, muteAudioEnabled, function(state)
    muteAudioEnabled = state
    if type(updateAudioMute) == "function" then updateAudioMute() end
end)
if muteAudioEnabled and type(updateAudioMute) == "function" then updateAudioMute() end

createToggle("Anti-AFK (Bypass Custom)", UtilityCard, 162, antiAfkEnabled, function(state)
    antiAfkEnabled = state
end)

createToggle("Auto-Nuke Others' Garden", UtilityCard, 198, autoNukeOthersEnabled, function(state)
    autoNukeOthersEnabled = state
    task.spawn(saveConfig)
    if state then
        pcall(function()
            local map = Workspace:FindFirstChild("Map")
            if map then map:Destroy() end
            local baseplate = Workspace:FindFirstChild("Baseplate")
            if baseplate then baseplate:Destroy() end
        end)
    end
end)

-- TOGGLE BARU: DESTROY ALL PLANTS (KHUSUS AFK)
createToggle("Destroy All Plants (Khusus AFK)", UtilityCard, 234, destroyAllPlantsEnabled, function(state)
    destroyAllPlantsEnabled = state
    task.spawn(saveConfig)
end)

-- NIA SAYANG ROW
local NiaRow = Instance.new("Frame", UtilityCard)
NiaRow.Size = UDim2.new(1, -20, 0, 30)
NiaRow.Position = UDim2.new(0, 10, 0, 270)
NiaRow.BackgroundTransparency = 1
NiaRow.ZIndex = 10002

local NiaLabel = Instance.new("TextLabel", NiaRow)
NiaLabel.Size = UDim2.new(0.6, 0, 1, 0)
NiaLabel.BackgroundTransparency = 1
NiaLabel.Text = "NIA SAYANG"
NiaLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
NiaLabel.Font = Enum.Font.GothamMedium
NiaLabel.TextSize = 12
NiaLabel.TextXAlignment = Enum.TextXAlignment.Left
NiaLabel.ZIndex = 10002

local NiaBtn = Instance.new("TextButton", NiaRow)
NiaBtn.Size = UDim2.new(0, 60, 0, 26)
NiaBtn.Position = UDim2.new(1, -60, 0.5, -13)
NiaBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
NiaBtn.Text = "EXECUTE"
NiaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NiaBtn.Font = Enum.Font.GothamBold
NiaBtn.TextSize = 12
NiaBtn.ZIndex = 10002
Instance.new("UICorner", NiaBtn).CornerRadius = UDim.new(0, 6)

NiaBtn.MouseButton1Click:Connect(function()
    local lp = game:GetService("Players").LocalPlayer
    for _, item in ipairs(lp.Backpack:GetChildren()) do
        if item:IsA("Tool") then item:Destroy() end
    end
    if lp.Character then
        for _, item in ipairs(lp.Character:GetChildren()) do
            if item:IsA("Tool") then item:Destroy() end
        end
    end
end)

do
    local autoEclipseWeather = false
    local eclipseAttempts = {}
    local eclipseCooldown = {}
    
    local function harvestEclipseOnce()
        local plot = nil
        for _, p in ipairs(workspace.Gardens:GetChildren()) do
            if p:GetAttribute("Owner") == game.Players.LocalPlayer.Name or p:GetAttribute("OwnerUserId") == game.Players.LocalPlayer.UserId then
                plot = p
                break
            end
        end
        if not plot then return false end
        
        local plants = plot:FindFirstChild("Plants")
        if not plants then return false end
        
        local eclipsePlants = {}
        for _, p in ipairs(plants:GetChildren()) do
            if tostring(p:GetAttribute("SeedName")):lower():match("eclipse") then
                local targetHp = p:FindFirstChild("HarvestPart", true)
                if targetHp then
                    local prompt = targetHp:FindFirstChild("HarvestPrompt")
                    if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then 
                        local cooldown = eclipseCooldown[p]
                        if not cooldown or os.time() > cooldown then
                            table.insert(eclipsePlants, {
                                Plant = p,
                                Prompt = prompt,
                                Fruit = targetHp.Parent
                            })
                        end
                    end
                end
            end
        end
        
        if #eclipsePlants > 0 then
            local randomIndex = math.random(1, #eclipsePlants)
            local bestPlant = eclipsePlants[randomIndex].Plant
            local bestPrompt = eclipsePlants[randomIndex].Prompt
            local bestFruit = eclipsePlants[randomIndex].Fruit
            
            eclipseAttempts[bestPlant] = (eclipseAttempts[bestPlant] or 0) + 1
            if eclipseAttempts[bestPlant] >= 5 then
                eclipseCooldown[bestPlant] = os.time() + 180 -- Abaikan selama 3 menit (180 detik)
                eclipseAttempts[bestPlant] = 0 -- Reset counter
            end
            
            local plantId = bestPlant:GetAttribute("Id") or bestPlant.Name
            local fruitId = bestFruit:GetAttribute("Id") or bestFruit.Name
            local PacketEvent = game:GetService("ReplicatedStorage"):FindFirstChild("PacketEvent", true)
            
            if PacketEvent and plantId and fruitId then
                local packet1 = "\xCD\x00$" .. tostring(plantId) .. "$" .. tostring(fruitId)
                pcall(function() PacketEvent:FireServer(buffer.fromstring(packet1)) end)
                
                local packet2 = "\xCD\x00$" .. tostring(fruitId) .. "$" .. tostring(plantId)
                pcall(function() PacketEvent:FireServer(buffer.fromstring(packet2)) end)
            end
            -- Harvest tanpa teleport dari jarak jauh (Spam prompt karena jarak jauh kadang miss)
            task.spawn(function()
                for i = 1, 20 do
                    if not bestPrompt or not bestPrompt.Parent then break end
                    pcall(fireproximityprompt, bestPrompt)
                    task.wait(0.05)
                end
            end)
            
            return true
        end
        
        return false
    end

-- Status label (HARUS di atas createToggle supaya bisa diakses)
local eclipseStatus = Instance.new("TextLabel")
eclipseStatus.Parent = UtilityCard
eclipseStatus.Position = UDim2.new(0, 10, 0, 342)
eclipseStatus.Size = UDim2.new(1, -20, 0, 20)
eclipseStatus.BackgroundTransparency = 1
eclipseStatus.ZIndex = 10002
eclipseStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
eclipseStatus.TextSize = 14
eclipseStatus.Font = Enum.Font.Gotham
eclipseStatus.TextXAlignment = Enum.TextXAlignment.Left
eclipseStatus.Text = "Eclipse Siap Panen: 0"
createToggle("Chaining Harvest Eclipse", UtilityCard, 306, false, function(state)
    autoEclipseWeather = state
    if state then
        local WeatherValues = game:GetService("ReplicatedStorage"):WaitForChild("WeatherValues", 10)
        if not WeatherValues then
            eclipseStatus.Text = "❌ Gagal mendeteksi Cuaca!"
            eclipseStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    else
        eclipseStatus.Text = "Eclipse Auto Harvest: OFF"
        eclipseStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end)

-- Background counter, UI Updater, & Auto-Trigger (Selalu jalan)
task.spawn(function()
    while task.wait(2) do
        local count = 0
        local plot = nil
        for _, p in ipairs(workspace.Gardens:GetChildren()) do
            if p:GetAttribute("Owner") == game.Players.LocalPlayer.Name or p:GetAttribute("OwnerUserId") == game.Players.LocalPlayer.UserId then
                plot = p
                break
            end
        end
        if plot then
            local plants = plot:FindFirstChild("Plants")
            if plants then
                for _, p in ipairs(plants:GetChildren()) do
                    if tostring(p:GetAttribute("SeedName")):lower():match("eclipse") then
                        local cooldown = eclipseCooldown[p]
                        if not cooldown or os.time() > cooldown then
                            local hp = p:FindFirstChild("HarvestPart", true)
                            if hp then
                                local prompt = hp:FindFirstChild("HarvestPrompt")
                                if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
        
        local WeatherValues = game:GetService("ReplicatedStorage"):FindFirstChild("WeatherValues")
        local isEclipse = WeatherValues and WeatherValues:GetAttribute("Eclipse_Playing")
        
        -- LOGIKA CHAINING ECLIPSE
        if autoEclipseWeather and not isEclipse and count > 0 then
            -- Jika Auto menyala, tidak sedang Eclipse, dan ada buah siap panen,
            -- Harvest TEPAT 1 buah untuk memicu cuaca Eclipse baru!
            local success = harvestEclipseOnce()
            if success then
                print("[Eclipse] Berhasil memanen 1 buah untuk memicu cuaca Eclipse!")
                count = count - 1
            end
        end
        
        -- UPDATE UI TEXT
        local statusStr = ""
        if autoEclipseWeather then
            if isEclipse then
                statusStr = "Status: Eclipse Berjalan! | "
            elseif count > 0 then
                statusStr = "Status: Memicu Eclipse... | "
            else
                statusStr = "Status: Menunggu Buah... | "
            end
        else
            statusStr = "Status: [AUTO OFF] | "
        end
        
        if count > 0 then
            eclipseStatus.Text = statusStr .. "Siap Panen: " .. tostring(count) .. " 🌑✨"
            eclipseStatus.TextColor3 = Color3.fromRGB(173, 91, 176)
        else
            eclipseStatus.Text = statusStr .. "Siap Panen: 0"
            if autoEclipseWeather and isEclipse then
                eclipseStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                eclipseStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
end)

end -- End of Eclipse Scope

-- ==========================================
-- ==========================================
-- AUTO SEED COLLECTOR (Moon & All Drops)
-- ==========================================
do
    local autoMoonSeed = false
    local autoCollectAllSeeds = false
    
    local moonSeedStatus = Instance.new("TextLabel")
    moonSeedStatus.Parent = UtilityCard
    moonSeedStatus.Position = UDim2.new(0, 10, 0, 414)
    moonSeedStatus.Size = UDim2.new(1, -20, 0, 20)
    moonSeedStatus.BackgroundTransparency = 1
    moonSeedStatus.ZIndex = 10002
    moonSeedStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
    moonSeedStatus.TextSize = 14
    moonSeedStatus.Font = Enum.Font.Gotham
    moonSeedStatus.TextXAlignment = Enum.TextXAlignment.Left
    moonSeedStatus.Text = "Seed Collector: Menunggu..."

    createToggle("Auto Moon Seed (Khusus Cuaca)", UtilityCard, 378, false, function(state)
        autoMoonSeed = state
        if not state and not autoCollectAllSeeds then
            moonSeedStatus.Text = "Seed Collector: OFF"
            moonSeedStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end)
    
    createToggle("Auto Collect ALL Dropped Seeds", UtilityCard, 450, false, function(state)
        autoCollectAllSeeds = state
        if not state and not autoMoonSeed then
            moonSeedStatus.Text = "Seed Collector: OFF"
            moonSeedStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end)
    
    local autoDropFruit = false
    createToggle("Auto Drop All Fruits", UtilityCard, 522, false, function(state)
        autoDropFruit = state
    end)
    
    task.spawn(function()
        local Networking = game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Networking")
        local NetworkingModule = require(Networking)

        -- Menunggu per FRAME, bukan per 0,05 detik.
        -- Terukur 2026-08-21: promote dan equip selesai dalam 0 frame (murni
        -- di sisi client), jadi jeda tetap apa pun cuma jadi rem kosong.
        local function tunggu(syarat, batas)
            local mulai = os.clock()
            repeat
                if syarat() then return true end
                task.wait()
            until os.clock() - mulai >= (batas or 1)
            return syarat()
        end

        -- BATAS SEBENARNYA: maksimal 10 barang tergeletak milik kita sendiri.
        --
        -- Terukur 2026-08-21: begitu DroppedItems berisi 10 model ber-atribut
        -- DroppedBy = UserId kita, RequestDrop ditolak DIAM-DIAM selamanya --
        -- 48 tembakan dalam 3 detik menghasilkan nol. Barangnya juga tidak
        -- hilang sendiri (yang tertua sudah 161 detik masih di sana). Jadi
        -- "dipercepat" atau "dispam" tidak menolong sama sekali di sini; yang
        -- benar adalah berhenti dan bilang kenapa.
        local BATAS_TANAH = 10
        local ID_SAYA = LocalPlayer.UserId
        local lapor = 0

        local function barangKuDiTanah()
            local f = workspace:FindFirstChild("DroppedItems")
            if not f then return 0 end
            local n = 0
            for _, c in ipairs(f:GetChildren()) do
                if c:GetAttribute("DroppedBy") == ID_SAYA then n = n + 1 end
            end
            return n
        end

        -- Terukur, satu buah dijatuhkan sungguhan:
        --     RequestDrop pada Configuration            -> ditolak, tetap di backpack
        --     PromoteFruit                              -> jadi Tool, masih di backpack
        --     RequestDrop pada Tool yang belum dipegang -> DITOLAK juga
        --     EquipTool -> pindah ke karakter, RequestDrop baru berhasil
        --
        -- Versi lama melewatkan equip untuk Configuration, jadi lintasan
        -- pertama cuma mem-promote dan buahnya baru jatuh di lintasan
        -- berikutnya -- itu sebabnya auto drop terasa harus di-trigger
        -- beberapa kali dulu. Backspace bawaan game memakai jalur yang sama
        -- persis (DroppedItemController), bedanya buahnya memang sudah di tangan.
        local function jatuhkan(item)
            local id = item:GetAttribute("Id")
            if not id then return false end
            local bp = LocalPlayer:FindFirstChild("Backpack")
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not bp or not hum then return false end

            local function punya(wadah)
                if not wadah then return nil end
                for _, c in ipairs(wadah:GetChildren()) do
                    if c:GetAttribute("Id") == id then return c end
                end
                return nil
            end

            -- 1. Configuration -> Tool
            if item:IsA("Configuration") then
                NetworkingModule.Backpack.PromoteFruit:Fire(id)
                local jadiTool = tunggu(function()
                    local c = punya(bp) or punya(LocalPlayer.Character)
                    return c ~= nil and c:IsA("Tool")
                end, 1)
                if not jadiTool then return false end
            end

            -- 2. Backpack -> tangan. Tanpa ini server menolak drop-nya.
            local alat = punya(LocalPlayer.Character)
            if not alat then
                alat = punya(bp)
                if not alat then return false end
                hum:EquipTool(alat)
                if not tunggu(function() return punya(LocalPlayer.Character) ~= nil end, 1) then
                    return false
                end
            end

            -- 3. Jatuhkan. Drop yang DITERIMA selesai 68-108 ms; yang belum
            -- dijawab dalam 0,16 detik itu ditolak, bukan lambat -- jadi
            -- ditembak ulang, bukan ditunggu lebih lama.
            for _ = 1, 4 do
                NetworkingModule.DroppedItem.RequestDrop:Fire("HarvestedFruits", id)
                if tunggu(function()
                    return punya(bp) == nil and punya(LocalPlayer.Character) == nil
                end, 0.16) then
                    return true
                end
            end
            return false
        end

        while true do
            if autoDropFruit then
                local pcallSuccess, err = pcall(function()
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    if not bp then return end

                    if barangKuDiTanah() >= BATAS_TANAH then
                        -- Dilaporkan sekali per 15 detik; tanpa rem ini konsol
                        -- dibanjiri peringatan yang sama tiap putaran.
                        if os.clock() - lapor > 15 then
                            lapor = os.clock()
                            warn(string.format(
                                "Auto Drop: tanah penuh (%d barang milikmu tergeletak). "
                                .. "Server menolak drop sampai sebagian dipungut.", BATAS_TANAH))
                        end
                        return
                    end

                    -- Daftarnya dikumpulkan dulu: jatuhkan() memindahkan benda
                    -- antara backpack dan karakter, jadi menelusuri wadahnya
                    -- sambil mengubah isinya membuat ada yang terlewat.
                    local antre = {}
                    for _, wadah in ipairs({ bp, LocalPlayer.Character }) do
                        if wadah then
                            for _, c in ipairs(wadah:GetChildren()) do
                                if (c:IsA("Configuration") or c:IsA("Tool"))
                                    and c:GetAttribute("HarvestedFruit") == true then
                                    antre[#antre + 1] = c
                                end
                            end
                        end
                    end

                    for _, item in ipairs(antre) do
                        if not autoDropFruit then break end
                        -- Diperiksa tiap buah, bukan sekali di awal: batasnya
                        -- bisa tercapai di tengah antrean, dan meneruskan
                        -- setelah itu cuma menembak ke tembok.
                        if barangKuDiTanah() >= BATAS_TANAH then break end
                        if item.Parent then jatuhkan(item) end
                    end
                end)
                if not pcallSuccess then
                    warn("Auto Drop Fruit Error: " .. tostring(err))
                end
            end
            -- Saat menyala jangan tidur sedetik penuh: itu yang bikin terasa
            -- lelet padahal satu buah cuma butuh ~0,1 detik.
            task.wait(autoDropFruit and 0.1 or 0.5)
        end
    end)
    
    local idleTicks = -1
    -- Dulu ini daftar ABADI, dan penandanya dipasang begitu karakter sampai,
    -- tanpa memastikan seed-nya benar-benar terambil. Jadi tiap pengambilan
    -- yang gagal langsung jadi permanen, dan makin lama makin banyak benda
    -- tergeletak yang selamanya dilewati. Itulah "macet di tengah, ga ngambil
    -- lagi". Sekarang isinya waktu kedaluwarsa, bukan sekadar true.
    local ignoredSeeds = {}
    local gagalSeed = {}

    -- Seed yang gagal ditunda, bukan dibuang: yang sekarang tak terjangkau
    -- bisa saja bisa diambil sebentar lagi (masih melayang jatuh, tertutup
    -- pemain lain, prompt-nya belum aktif).
    local function tandaiGagal(obj)
        local n = (gagalSeed[obj] or 0) + 1
        gagalSeed[obj] = n
        ignoredSeeds[obj] = os.clock() + (n >= 3 and 60 or 5)
    end

    -- Catatan yang bendanya sudah lenyap dibuang, supaya tabelnya tidak tumbuh
    -- selamanya dan tidak menahan Instance yang sudah dihancurkan.
    local function bersihkanCatatan()
        for obj, sampai in pairs(ignoredSeeds) do
            if not obj.Parent or os.clock() > sampai then
                ignoredSeeds[obj] = nil
                if not obj.Parent then gagalSeed[obj] = nil end
            end
        end
    end
    
    task.spawn(function()
        while true do
            task.wait(0.1)
            if autoMoonSeed or autoCollectAllSeeds then
                local pAttr = workspace:GetAttribute("ActivePhase") or ""
                
                local isGold = pAttr:match("Goldmoon")
                local isRainbow = pAttr:match("Rainbow")
                local isMega = pAttr:match("Mega")
                local isBlood = pAttr:match("Bloodmoon")
                
                local moonActive = (isGold or isRainbow or isMega)
                
                if autoCollectAllSeeds or (autoMoonSeed and moonActive) then
                    moonSeedStatus.Text = "Mencari Seed Jatuh..."
                    moonSeedStatus.TextColor3 = Color3.fromRGB(255, 215, 0)
                    
                    local foundSeed = nil
                    local targetPrompt = nil
                    
                    bersihkanCatatan()

                    -- Telusuri ProximityPrompt-nya LANGSUNG.
                    --
                    -- Versi lama memeriksa tiap Model/BasePart lalu mencari
                    -- prompt secara REKURSIF di dalamnya. Terukur di map ini:
                    -- 15.643 objek diperiksa demi menemukan 513 prompt, ~18 ms
                    -- tiap putaran, 10 kali per detik. Satu prompt juga
                    -- tercatat berkali-kali (lewat part-nya DAN tiap model
                    -- induknya), sehingga sasaran yang menang cuma tergantung
                    -- urutan telusur.
                    for _, prompt in ipairs(workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Parent then
                            local obj = prompt.Parent
                            do
                                local induk = prompt:FindFirstAncestorWhichIsA("Model")
                                -- Nama part DAN nama model induknya sama-sama
                                -- dipakai: penanda seed kadang cuma ada di salah satu.
                                local name = (obj.Name .. " " .. (induk and induk.Name or "")):lower()
                                local actionText = prompt.ActionText:lower()
                                local objectText = prompt.ObjectText:lower()
                                
                                local isValidSeed = false
                                
                                -- Cek apakah ini Moon Seed (baik dari nama Part maupun dari ObjectText di Prompt)
                                local isMoonSeed = name:match("gold") or name:match("rainbow") or name:match("mega") or objectText:match("gold") or objectText:match("rainbow") or objectText:match("mega")
                                
                                if autoMoonSeed and moonActive and isMoonSeed then
                                    isValidSeed = true
                                elseif autoCollectAllSeeds then
                                    if actionText:match("pick up") or actionText:match("collect") or actionText:match("take") or actionText:match("claim") then
                                        isValidSeed = true
                                    elseif name:match("seed") or name:match("gold") or name:match("mega") or name:match("rainbow") or name:match("carrot") or name:match("apple") or name:match("pomegranate") or name:match("coconut") or name:match("cactus") or name:match("mushroom") or name:match("bamboo") or name:match("corn") or name:match("berry") then
                                        if actionText ~= "harvest" and actionText ~= "sit" and actionText ~= "talk" and actionText ~= "buy" and actionText ~= "use" then
                                            isValidSeed = true
                                        end
                                    end
                                end
                                
                                if isValidSeed and not ignoredSeeds[obj] then
                                    local checkPos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or nil) or obj.Position
                                    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
                                        checkPos = prompt.Parent.Position
                                    end
                                    
                                    if checkPos and checkPos.Y < -5 then
                                        ignoredSeeds[obj] = os.clock() + 600 -- jatuh ke jurang, tunda lama
                                    else
                                        foundSeed = obj
                                        targetPrompt = prompt
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    if foundSeed and targetPrompt then
                        idleTicks = 0
                        moonSeedStatus.Text = "Menuju ke: " .. foundSeed.Name
                        local targetPos = foundSeed:IsA("Model") and foundSeed.PrimaryPart and foundSeed.PrimaryPart.Position or foundSeed.Position
                        
                        -- Pastikan kita teleport ke posisi Part yang memiliki prompt, bukan parent modelnya
                        if targetPrompt and targetPrompt.Parent and targetPrompt.Parent:IsA("BasePart") then
                            targetPos = targetPrompt.Parent.Position
                        end
                        
                        -- Buat pijakan sementara DULU sebelum teleport agar aman
                        local tempPlat = Instance.new("Part")
                        tempPlat.Size = Vector3.new(15, 1, 15)
                        tempPlat.Position = targetPos - Vector3.new(0, 4, 0)
                        tempPlat.Anchored = true
                        tempPlat.Transparency = 0.5
                        tempPlat.BrickColor = BrickColor.new("Bright green")
                        tempPlat.Material = Enum.Material.Neon
                        tempPlat.Parent = workspace
                        game:GetService("Debris"):AddItem(tempPlat, 5)

                        -- FLIGHT MODE & COLLECT
                        local char = game.Players.LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root then
                            -- Terbang menggunakan Tween (Kecepatan 30)
                            local reached = flyToTarget(targetPos)
                            
                            if reached then
                                moonSeedStatus.Text = "Memanen " .. foundSeed.Name .. "..."

                                -- Buka kunci prompt supaya pasti bisa ditekan.
                                targetPrompt.RequiresLineOfSight = false
                                targetPrompt.MaxActivationDistance = 9999
                                if targetPrompt.HoldDuration > 0 then targetPrompt.HoldDuration = 0 end

                                -- Tekan, lalu PERIKSA hasilnya.
                                --
                                -- Versi lama menembakkan 20 klik di thread
                                -- terpisah lalu langsung menandai seed-nya
                                -- "sudah diambil" tanpa menunggu apa-apa.
                                -- Begitu penekanannya gagal, benda itu tetap
                                -- tergeletak tapi selamanya dilewati.
                                -- Tanda berhasil = benda/prompt-nya lenyap.
                                local terambil = false
                                for _ = 1, 20 do
                                    if not (targetPrompt.Parent and foundSeed.Parent) then
                                        terambil = true
                                        break
                                    end
                                    pcall(fireproximityprompt, targetPrompt)
                                    task.wait(0.05)
                                end
                                if not (targetPrompt.Parent and foundSeed.Parent) then
                                    terambil = true
                                end

                                if terambil then
                                    ignoredSeeds[foundSeed] = nil
                                    gagalSeed[foundSeed] = nil
                                else
                                    tandaiGagal(foundSeed)
                                end
                            else
                                -- Gagal terbang ke sana. Tanpa dicatat, seed
                                -- yang tak terjangkau akan terpilih lagi tiap
                                -- putaran -- pencarian berhenti di kecocokan
                                -- PERTAMA -- dan collector mandek di situ terus.
                                tandaiGagal(foundSeed)
                            end
                        end
                    else
                        if idleTicks >= 0 and idleTicks < 30 then
                            idleTicks = idleTicks + 1
                            local sLeft = 3 - math.floor(idleTicks / 10)
                            moonSeedStatus.Text = "Menunggu seed baru... (" .. tostring(sLeft) .. "s)"
                        elseif idleTicks == 30 then
                            idleTicks = -1
                            moonSeedStatus.Text = "Selesai! Kembali ke Steven..."
                            
                            local steven = workspace:FindFirstChild("Steven", true)
                            if steven then
                                local st = steven:IsA("Model") and (steven.PrimaryPart or steven:FindFirstChild("HumanoidRootPart")) or (steven:IsA("BasePart") and steven)
                                if st then
                                    local char = game.Players.LocalPlayer.Character
                                    local root = char and char:FindFirstChild("HumanoidRootPart")
                                    if root then
                                        root.CFrame = st.CFrame + Vector3.new(0, 3, 3)
                                        root.Velocity = Vector3.zero
                                    end
                                end
                            end
                            task.wait(1.5)
                        end
                        
                        if idleTicks == -1 then
                            if autoMoonSeed and moonActive and not autoCollectAllSeeds then
                                moonSeedStatus.Text = "Moon Aktif! Menunggu Seed..."
                            else
                                moonSeedStatus.Text = "Seed Collector: Aktif (Standby)"
                                moonSeedStatus.TextColor3 = Color3.fromRGB(134, 239, 172)
                            end
                        end
                    end
                else
                    moonSeedStatus.Text = "Moon Seed: Menunggu Cuaca..."
                    moonSeedStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end
        end
    end)
end

-- ==========================================
-- AUTO STEAL / HARVEST AGP BERMUTASI
-- ==========================================
-- Atlantic Giant Pumpkin yang kena Gold/Rainbow itu mahal, dan buahnya bisa
-- diambil siapa pun yang lebih dulu sampai. Fitur ini menungguinya lalu
-- mengambil begitu muncul: PANEN kalau tanamannya milik sendiri, CURI kalau
-- milik akun lain.
--
-- Dua cabang itu bukan karangan -- persis yang dilakukan game sendiri di
-- FruitMagnetController:
--     if v.ownerUserId == LocalPlayer.UserId then
--         Networking.Garden.CollectFruit:Fire(v.plantId, v.fruitId)
--     else
--         Networking.Steal.BeginSteal:Fire(v.ownerUserId, v.plantId, v.fruitId)
--         Networking.Steal.CompleteSteal:Fire()
--     end
do
    local autoAgpEnabled = false

    -- Ejaan mutasi diambil dari tabel harga game, bukan tebakan. Terukur
    -- 2026-08-21: ReturnPriceMultiplier("Gold") = 10, ("Rainbow") = 30,
    -- sedangkan ("Golden") = 1 alias TIDAK dikenal. Jadi ejaan sahnya persis
    -- "Gold" dan "Rainbow" -- salah huruf berarti fitur ini diam selamanya.
    local agpMutasi = { Gold = true, Rainbow = true }
    local NAMA_AGP = "Atlantic Giant Pumpkin"

    local agpStatus = Instance.new("TextLabel")
    agpStatus.Parent = UtilityCard
    agpStatus.Position = UDim2.new(0, 10, 0, 594)
    agpStatus.Size = UDim2.new(1, -20, 0, 20)
    agpStatus.BackgroundTransparency = 1
    agpStatus.ZIndex = 10002
    agpStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
    agpStatus.TextSize = 14
    agpStatus.Font = Enum.Font.Gotham
    agpStatus.TextXAlignment = Enum.TextXAlignment.Left
    agpStatus.Text = "AGP: OFF"

    createToggle("Auto Steal AGP (Gold/Rainbow)", UtilityCard, 558, false, function(state)
        autoAgpEnabled = state
        if not state then
            agpStatus.Text = "AGP: OFF"
            agpStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end)

    -- Waktu percobaan terakhir per buah, supaya tidak menembaki buah yang sama.
    local terakhir = {}

    task.spawn(function()
        local Networking = game:GetService("ReplicatedStorage")
            :WaitForChild("SharedModules"):WaitForChild("Networking")
        local NetworkingModule = require(Networking)

        -- Kumpulkan buah AGP matang yang bermutasi, dari SEMUA kebun.
        --
        -- Struktur terukur: workspace.Gardens.PlotN.Plants berisi model bernama
        -- "{UserId}_{PlantId}" dengan atribut SeedName/UserId/PlantId, dan
        -- buahnya di folder anak "Fruits" dengan atribut FruitId, Mutation,
        -- Age, MaxAge. Ada 8 plot; yang kosong dilewati sendirinya.
        --
        -- Pemilik dibaca dari atribut UserId, BUKAN dari nomor plot: plot
        -- berpindah tangan saat pemain keluar-masuk server, jadi menyimpulkan
        -- pemilik dari nama plot akan salah menuduh dan salah memilih cabang.
        local function cariBuah()
            local hasil = {}
            local G = workspace:FindFirstChild("Gardens")
            if not G then return hasil end
            for _, plot in ipairs(G:GetChildren()) do
                local Plants = plot:FindFirstChild("Plants")
                if Plants then
                    for _, tanaman in ipairs(Plants:GetChildren()) do
                        if tanaman:GetAttribute("SeedName") == NAMA_AGP then
                            local Fruits = tanaman:FindFirstChild("Fruits")
                            if Fruits then
                                for _, buah in ipairs(Fruits:GetChildren()) do
                                    local mut = buah:GetAttribute("Mutation")
                                    local umur = buah:GetAttribute("Age")
                                    local maks = buah:GetAttribute("MaxAge")
                                    -- Buah tanpa Age/MaxAge dihitung matang --
                                    -- itu yang dilakukan game sendiri; menolaknya
                                    -- berarti melewatkan buah yang sebenarnya sah.
                                    local matang = (type(umur) ~= "number" or type(maks) ~= "number")
                                        or umur >= maks
                                    if matang and type(mut) == "string" and agpMutasi[mut] then
                                        hasil[#hasil + 1] = {
                                            buah = buah,
                                            mutasi = mut,
                                            pemilik = tonumber(buah:GetAttribute("UserId"))
                                                or tonumber(tanaman:GetAttribute("UserId")),
                                            plantId = buah:GetAttribute("PlantId")
                                                or tanaman:GetAttribute("PlantId"),
                                            fruitId = buah:GetAttribute("FruitId"),
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return hasil
        end

        -- Catatan cooldown dibuang setelah lewat, supaya tabelnya tidak tumbuh
        -- selamanya selama sesi AFK berjam-jam.
        local function bersihkanCatatan()
            for k, t in pairs(terakhir) do
                if os.clock() - t > 60 then terakhir[k] = nil end
            end
        end

        local function posisiBuah(buah)
            if buah:IsA("BasePart") then return buah.Position end
            if buah:IsA("Model") then
                if buah.PrimaryPart then return buah.PrimaryPart.Position end
                local ok, pivot = pcall(function() return buah:GetPivot().Position end)
                if ok then return pivot end
            end
            return nil
        end

        while true do
            task.wait(0.5)
            if autoAgpEnabled then
                local ok, err = pcall(function()
                    bersihkanCatatan()
                    local daftar = cariBuah()
                    if #daftar == 0 then
                        agpStatus.Text = "AGP: menunggu mutasi..."
                        agpStatus.TextColor3 = Color3.fromRGB(134, 239, 172)
                        return
                    end

                    local sudahMencuri = false
                    for _, b in ipairs(daftar) do
                        if not autoAgpEnabled then break end
                        if b.pemilik and b.plantId and b.fruitId and b.buah.Parent then
                            local kunci = string.format("%d_%s_%s", b.pemilik, b.plantId, b.fruitId)
                            -- Cooldown 1,5 detik per buah: angka yang dipakai
                            -- game sendiri. Menembak lebih rapat cuma menambah
                            -- tolakan, bukan mempercepat.
                            if not terakhir[kunci] or os.clock() - terakhir[kunci] >= 1.5 then
                                if b.pemilik == LocalPlayer.UserId then
                                    -- Milik sendiri: panen biasa, tanpa batas
                                    -- jumlah per putaran.
                                    terakhir[kunci] = os.clock()
                                    NetworkingModule.Garden.CollectFruit:Fire(b.plantId, b.fruitId)
                                    agpStatus.Text = "AGP: panen " .. b.mutasi
                                    agpStatus.TextColor3 = Color3.fromRGB(255, 215, 0)
                                elseif not sudahMencuri then
                                    -- SATU pencurian per putaran. Game sendiri
                                    -- membatasi begitu (flag v82 di
                                    -- FruitMagnetController); menembakkan
                                    -- beberapa sekaligus membuat sisanya
                                    -- terbuang tanpa jejak.
                                    sudahMencuri = true
                                    terakhir[kunci] = os.clock()

                                    -- Didatangi dulu. Steal di game ini disertai
                                    -- animasi berlutut plus deteksi gerak, jadi
                                    -- menembak dari seberang peta belum tentu
                                    -- diterima server. BeginSteal dan
                                    -- CompleteSteal ditembak berurutan tanpa
                                    -- jeda supaya deteksi gerak tidak sempat
                                    -- membatalkannya.
                                    local pos = posisiBuah(b.buah)
                                    if pos then
                                        agpStatus.Text = "AGP: menuju " .. b.mutasi
                                        agpStatus.TextColor3 = Color3.fromRGB(255, 215, 0)
                                        pcall(flyToTarget, pos)
                                    end

                                    NetworkingModule.Steal.BeginSteal:Fire(b.pemilik, b.plantId, b.fruitId)
                                    NetworkingModule.Steal.CompleteSteal:Fire()
                                    agpStatus.Text = string.format("AGP: curi %s dari %d", b.mutasi, b.pemilik)
                                end
                            end
                        end
                    end
                end)
                if not ok then
                    warn("Auto Steal AGP Error: " .. tostring(err))
                end
            end
        end
    end)
end


-- ==========================================
-- NUKE BUTTON DECLARATIONS
-- ==========================================
local function destroyUnusedMap()
    pcall(function()
        local map = Workspace:FindFirstChild("Map")
        if map then map:Destroy() end
    end)
    pcall(function()
        local baseplate = Workspace:FindFirstChild("Baseplate")
        if baseplate then baseplate:Destroy() end
    end)
    
    if Gardens then
        for _, plot in ipairs(Gardens:GetChildren()) do
            local ownerName = plot:GetAttribute("Owner")
            local ownerId = plot:GetAttribute("OwnerUserId")
            
            if ownerName ~= LocalPlayer.Name and ownerId ~= LocalPlayer.UserId then
                if ownerName then
                    if not plotCache[ownerName] then plotCache[ownerName] = { Plants = {} } end
                    local cData = plotCache[ownerName]
                    cData.PlotNum = tonumber(string.match(plot.Name, "%d+")) or 1
                    Siram.rekam(cData, plot:FindFirstChild("Plants"))
                end
                pcall(function() plot:Destroy() end)
            end
        end
    end
end

-- Nuke Row
local NukeRow = Instance.new("Frame", UtilityCard)
NukeRow.Size = UDim2.new(1, -20, 0, 30)
NukeRow.Position = UDim2.new(0, 10, 0, 486)
NukeRow.BackgroundTransparency = 1

local NukeLabel = Instance.new("TextLabel", NukeRow)
NukeLabel.Size = UDim2.new(0.6, 0, 1, 0)
NukeLabel.BackgroundTransparency = 1
NukeLabel.Text = "Destroy Map (Permanent!)"
NukeLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
NukeLabel.Font = Enum.Font.GothamMedium
NukeLabel.TextSize = 12
NukeLabel.TextXAlignment = Enum.TextXAlignment.Left

local NukeBtn = Instance.new("TextButton", NukeRow)
NukeBtn.Size = UDim2.new(0, 60, 0, 26)
NukeBtn.Position = UDim2.new(1, -60, 0.5, -13)
NukeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
NukeBtn.Text = "NUKE"
NukeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NukeBtn.Font = Enum.Font.GothamBold
NukeBtn.TextSize = 11
Instance.new("UICorner", NukeBtn).CornerRadius = UDim.new(0, 13)

NukeBtn.MouseButton1Click:Connect(function()
    NukeBtn.Text = "DONE"
    NukeBtn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
    task.spawn(destroyUnusedMap)
end)

-- 6. STATS & CONFIG CARD
local StatsCard = createCard("StatsCard", 200, 6)

local StatsTitleLabel = Instance.new("TextLabel", StatsCard)
StatsTitleLabel.Size = UDim2.new(1, -20, 0, 25)
StatsTitleLabel.Position = UDim2.new(0, 10, 0, 5)
StatsTitleLabel.BackgroundTransparency = 1
StatsTitleLabel.Text = "STATS & MONITOR"
StatsTitleLabel.TextColor3 = Color3.fromRGB(99, 102, 241)
StatsTitleLabel.Font = Enum.Font.GothamBold
StatsTitleLabel.TextSize = 11
StatsTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsTitleLabel.ZIndex = 10002

local ShecklesLabel = Instance.new("TextLabel", StatsCard)
ShecklesLabel.Size = UDim2.new(1, -20, 0, 20)
ShecklesLabel.Position = UDim2.new(0, 10, 0, 30)
ShecklesLabel.BackgroundTransparency = 1
ShecklesLabel.Text = "Sheckles: Loading..."
ShecklesLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ShecklesLabel.Font = Enum.Font.GothamSemibold
ShecklesLabel.TextSize = 12
ShecklesLabel.TextXAlignment = Enum.TextXAlignment.Left
ShecklesLabel.ZIndex = 10002

-- UI GARDEN VALUE BARU (Berwarna Emas)
local GardenValueLabel = Instance.new("TextLabel", StatsCard)
GardenValueLabel.Size = UDim2.new(1, -20, 0, 20)
GardenValueLabel.Position = UDim2.new(0, 10, 0, 50)
GardenValueLabel.BackgroundTransparency = 1
GardenValueLabel.Text = "Garden Value: Loading..."
GardenValueLabel.TextColor3 = Color3.fromRGB(251, 191, 36)
GardenValueLabel.Font = Enum.Font.GothamSemibold
GardenValueLabel.TextSize = 12
GardenValueLabel.TextXAlignment = Enum.TextXAlignment.Left
GardenValueLabel.ZIndex = 10002

-- UI TOTAL FRUIT BARU (Berwarna Hijau Muda)
local TotalFruitLabel = Instance.new("TextLabel", StatsCard)
TotalFruitLabel.Size = UDim2.new(1, -20, 0, 20)
TotalFruitLabel.Position = UDim2.new(0, 10, 0, 70)
TotalFruitLabel.BackgroundTransparency = 1
TotalFruitLabel.Text = "Total Fruit: Loading..."
TotalFruitLabel.TextColor3 = Color3.fromRGB(167, 243, 208)
TotalFruitLabel.Font = Enum.Font.GothamSemibold
TotalFruitLabel.TextSize = 12
TotalFruitLabel.TextXAlignment = Enum.TextXAlignment.Left
TotalFruitLabel.ZIndex = 10002

-- Ukuran PlantsLabel dikurangi agar muat dengan rapi di bawah TotalFruitLabel
local PlantsLabel = Instance.new("TextLabel", StatsCard)
PlantsLabel.Size = UDim2.new(1, -20, 0, 60)
PlantsLabel.Position = UDim2.new(0, 10, 0, 90)
PlantsLabel.BackgroundTransparency = 1
PlantsLabel.Text = "Menghitung tanaman..."
PlantsLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
PlantsLabel.Font = Enum.Font.GothamMedium
PlantsLabel.TextSize = 11
PlantsLabel.TextXAlignment = Enum.TextXAlignment.Left
PlantsLabel.TextYAlignment = Enum.TextYAlignment.Top
PlantsLabel.TextWrapped = true
PlantsLabel.ZIndex = 10002

local SaveBtn = Instance.new("TextButton", StatsCard)
SaveBtn.Size = UDim2.new(1, -20, 0, 30)
SaveBtn.Position = UDim2.new(0, 10, 0, 160)
SaveBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
SaveBtn.Text = "SAVE CONFIG"
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 12
SaveBtn.ZIndex = 10002
Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 8)

-- ==========================================
-- 7. FRUIT ESP CARD
-- ==========================================
local EspCard = createCard("EspCard", 240, 7)

local EspCardTitle = Instance.new("TextLabel", EspCard)
EspCardTitle.Size = UDim2.new(1, -20, 0, 25)
EspCardTitle.Position = UDim2.new(0, 10, 0, 5)
EspCardTitle.BackgroundTransparency = 1
EspCardTitle.Text = "FRUIT ESP (X-RAY)"
EspCardTitle.TextColor3 = Color3.fromRGB(16, 185, 129)
EspCardTitle.Font = Enum.Font.GothamBold
EspCardTitle.TextSize = 11
EspCardTitle.TextXAlignment = Enum.TextXAlignment.Left
EspCardTitle.ZIndex = 10002

local espEnabled = false
createToggle("Enable Fruit ESP", EspCard, 30, espEnabled, function(state) 
    espEnabled = state 
    if not state then
        -- Bersihkan ESP dari layar jika dimatikan
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui.Name == "FruitESP" then gui:Destroy() end
        end
    end
end)

local espNoMutation = false
createToggle("Tampilkan Buah Tanpa Mutasi", EspCard, 62, espNoMutation, function(state) 
    espNoMutation = state 
end)

local EspInfoLabel = Instance.new("TextLabel", EspCard)
EspInfoLabel.Size = UDim2.new(1, -20, 0, 16)
EspInfoLabel.Position = UDim2.new(0, 10, 0, 94)
EspInfoLabel.BackgroundTransparency = 1
EspInfoLabel.Text = "Pilih mutasi untuk ESP:"
EspInfoLabel.TextColor3 = Color3.fromRGB(156, 163, 175)
EspInfoLabel.Font = Enum.Font.GothamMedium
EspInfoLabel.TextSize = 10
EspInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
EspInfoLabel.ZIndex = 10002

local EspSelectAllBtn = Instance.new("TextButton", EspCard)
EspSelectAllBtn.Size = UDim2.new(0.45, -5, 0, 22)
EspSelectAllBtn.Position = UDim2.new(0.03, 0, 0, 112)
EspSelectAllBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
EspSelectAllBtn.Text = "Pilih Semua"
EspSelectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
EspSelectAllBtn.Font = Enum.Font.GothamBold
EspSelectAllBtn.TextSize = 10
EspSelectAllBtn.ZIndex = 10003
Instance.new("UICorner", EspSelectAllBtn).CornerRadius = UDim.new(0, 6)

local EspClearAllBtn = Instance.new("TextButton", EspCard)
EspClearAllBtn.Size = UDim2.new(0.45, -5, 0, 22)
EspClearAllBtn.Position = UDim2.new(0.52, 0, 0, 112)
EspClearAllBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
EspClearAllBtn.Text = "Hapus Semua"
EspClearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
EspClearAllBtn.Font = Enum.Font.GothamBold
EspClearAllBtn.TextSize = 10
EspClearAllBtn.ZIndex = 10003
Instance.new("UICorner", EspClearAllBtn).CornerRadius = UDim.new(0, 6)

-- Kotak Scroll Multi-Select ESP
local EspScrollContainer = Instance.new("ScrollingFrame", EspCard)
EspScrollContainer.Size = UDim2.new(1, -20, 0, 94)
EspScrollContainer.Position = UDim2.new(0, 10, 0, 138)
EspScrollContainer.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
EspScrollContainer.BorderSizePixel = 0
EspScrollContainer.ScrollBarThickness = 3
EspScrollContainer.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
EspScrollContainer.ZIndex = 10002
Instance.new("UICorner", EspScrollContainer).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", EspScrollContainer).Color = Color3.fromRGB(36, 47, 65)

local EspScrollLayout = Instance.new("UIListLayout", EspScrollContainer)
EspScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
EspScrollLayout.Padding = UDim.new(0, 3)

local selectedEspMutations = {}
local espMutationButtons = {}
local espScrollHeight = 0

for idx, mutData in ipairs(MUTATION_LIST) do
    local mutName = mutData.Name
    local isSelected = false
    local mutColor = MUTATION_COLORS[mutName] or Color3.fromRGB(209, 213, 219)
    
    local row = Instance.new("Frame", EspScrollContainer)
    row.Size = UDim2.new(1, -6, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = idx
    row.ZIndex = 10002

    local checkLbl = Instance.new("TextLabel", row)
    checkLbl.Size = UDim2.new(0, 22, 1, 0)
    checkLbl.Position = UDim2.new(0, 2, 0, 0)
    checkLbl.BackgroundTransparency = 1
    checkLbl.Text = "[ ]"
    checkLbl.TextColor3 = Color3.fromRGB(100, 100, 100)
    checkLbl.TextSize = 13
    checkLbl.Font = Enum.Font.GothamBold
    checkLbl.ZIndex = 10003

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -30, 1, 0)
    nameLbl.Position = UDim2.new(0, 26, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = string.format("%s [%s]", mutName, mutData.Category)
    nameLbl.TextColor3 = Color3.fromRGB(100, 100, 100)
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 10
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 10003

    local toggleBtn = Instance.new("TextButton", row)
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ""
    toggleBtn.ZIndex = 10004

    toggleBtn.MouseButton1Click:Connect(function()
        isSelected = not isSelected
        selectedEspMutations[mutName] = isSelected or nil
        
        checkLbl.Text = isSelected and "[X]" or "[ ]"
        checkLbl.TextColor3 = isSelected and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(100, 100, 100)
        nameLbl.TextColor3 = isSelected and mutColor or Color3.fromRGB(100, 100, 100)
    end)

    espMutationButtons[mutName] = {
        setSelected = function(sel)
            isSelected = sel
            selectedEspMutations[mutName] = sel or nil
            checkLbl.Text = sel and "[X]" or "[ ]"
            checkLbl.TextColor3 = sel and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(100, 100, 100)
            nameLbl.TextColor3 = sel and mutColor or Color3.fromRGB(100, 100, 100)
        end
    }
    espScrollHeight = espScrollHeight + 29
end
EspScrollContainer.CanvasSize = UDim2.new(0, 0, 0, espScrollHeight)

EspSelectAllBtn.MouseButton1Click:Connect(function()
    for _, mutData in ipairs(MUTATION_LIST) do
        if espMutationButtons[mutData.Name] then espMutationButtons[mutData.Name].setSelected(true) end
    end
end)

EspClearAllBtn.MouseButton1Click:Connect(function()
    for _, mutData in ipairs(MUTATION_LIST) do
        if espMutationButtons[mutData.Name] then espMutationButtons[mutData.Name].setSelected(false) end
    end
    task.spawn(saveConfig)
end)

-- ==========================================
-- 8. AUTO WATER & SPRINKLER CARD
-- ==========================================
local WaterCard = createCard("WaterCard", 346, 8)

local WaterCardTitle = Instance.new("TextLabel", WaterCard)
WaterCardTitle.Size = UDim2.new(1, -20, 0, 25)
WaterCardTitle.Position = UDim2.new(0, 10, 0, 5)
WaterCardTitle.BackgroundTransparency = 1
WaterCardTitle.Text = "AUTO WATER & SPRINKLER"
WaterCardTitle.TextColor3 = Color3.fromRGB(59, 130, 246)
WaterCardTitle.Font = Enum.Font.GothamBold
WaterCardTitle.TextSize = 11
WaterCardTitle.TextXAlignment = Enum.TextXAlignment.Left
WaterCardTitle.ZIndex = 10002

createToggle("Enable Auto Water/Sprinkler", WaterCard, 30, autoWaterEnabled, function(state) autoWaterEnabled = state end)

-- Dynamic Tool Options generated below
local function createRealDropdown(title, yPos, options, defaultVal, callback)
    local lbl = Instance.new("TextLabel", WaterCard)
    lbl.Size = UDim2.new(0.4, 0, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(156, 163, 175)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10002

    local btn = Instance.new("TextButton", WaterCard)
    btn.Size = UDim2.new(0.5, 0, 0, 22)
    btn.Position = UDim2.new(0.45, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
    btn.Text = defaultVal
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.ZIndex = 10002
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        openDropdown("PILIH " .. title, options, function(selectedOpt)
            btn.Text = selectedOpt
            callback(selectedOpt, btn)
        end)
    end)
    return btn
end

local function createMultiDropdown(title, yPos, options, defaultVals, callback)
    local lbl = Instance.new("TextLabel", WaterCard)
    lbl.Size = UDim2.new(0.4, 0, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(156, 163, 175)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10002

    local btn = Instance.new("TextButton", WaterCard)
    btn.Size = UDim2.new(0.5, 0, 0, 22)
    btn.Position = UDim2.new(0.45, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
    
    local function getBtnText(arr)
        if type(arr) ~= "table" or #arr == 0 then return "None" end
        if #arr == 1 then return arr[1] end
        return #arr .. " Terpilih"
    end
    
    btn.Text = getBtnText(defaultVals)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.ZIndex = 10002
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local currentVals = type(defaultVals) == "table" and defaultVals or {}

    btn.MouseButton1Click:Connect(function()
        openMultiDropdown("PILIH " .. title, options, currentVals, function(selectedArr)
            currentVals = selectedArr
            btn.Text = getBtnText(selectedArr)
            callback(selectedArr, btn)
        end)
    end)
    return btn
end

local function getInventoryToolsByKeyword(keyword)
    local tools = {}
    local seen = {}
    local function checkFolder(folder)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Tool") and string.find(string.lower(child.Name), string.lower(keyword)) then
                if not seen[child.Name] then
                    seen[child.Name] = true
                    table.insert(tools, child.Name)
                end
            end
        end
    end
    checkFolder(LocalPlayer.Backpack)
    local char = LocalPlayer.Character
    if char then checkFolder(char) end
    return tools
end

local availableSprinklers = getInventoryToolsByKeyword("sprinkler")
if #availableSprinklers == 0 then table.insert(availableSprinklers, "None") end

local availableWateringCans = getInventoryToolsByKeyword("watering can")
if #availableWateringCans == 0 then table.insert(availableWateringCans, "None") end

local function filterOwnedTools(selectedList, availableList)
    if type(selectedList) ~= "table" then return {} end
    local filtered = {}
    for _, s in ipairs(selectedList) do
        if table.find(availableList, s) then
            table.insert(filtered, s)
        end
    end
    return filtered
end

selectedSprinklerTool = filterOwnedTools(selectedSprinklerTool, availableSprinklers)
selectedWaterTool = filterOwnedTools(selectedWaterTool, availableWateringCans)

createMultiDropdown("Sprinkler Tool", 62, availableSprinklers, selectedSprinklerTool, function(val) selectedSprinklerTool = val end)
createMultiDropdown("Watering Can", 90, availableWateringCans, selectedWaterTool, function(val) selectedWaterTool = val end)

-- Delay Input
DelayLbl = Instance.new("TextLabel", WaterCard)
DelayLbl.Size = UDim2.new(0.4, 0, 0, 22)
DelayLbl.Position = UDim2.new(0, 10, 0, 118)
DelayLbl.BackgroundTransparency = 1
DelayLbl.Text = "Delay Siram (detik)"
DelayLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
DelayLbl.Font = Enum.Font.GothamMedium
DelayLbl.TextSize = 10
DelayLbl.TextXAlignment = Enum.TextXAlignment.Left
DelayLbl.ZIndex = 10002

DelayInput = Instance.new("TextBox", WaterCard)
DelayInput.Size = UDim2.new(0.5, 0, 0, 22)
DelayInput.Position = UDim2.new(0.45, 0, 0, 118)
DelayInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
DelayInput.Text = tostring(autoWaterDelay)
DelayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
DelayInput.Font = Enum.Font.GothamBold
DelayInput.TextSize = 10
DelayInput.ZIndex = 10002
Instance.new("UICorner", DelayInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", DelayInput).Color = Color3.fromRGB(75, 85, 99)
DelayInput.FocusLost:Connect(function()
    local num = tonumber(DelayInput.Text)
    if num and num > 0 then autoWaterDelay = num else DelayInput.Text = tostring(autoWaterDelay) end
end)

-- Jumlah Siram (Common)
CCountLbl = Instance.new("TextLabel", WaterCard)
CCountLbl.Size = UDim2.new(0.4, 0, 0, 22)
CCountLbl.Position = UDim2.new(0, 10, 0, 146)
CCountLbl.BackgroundTransparency = 1
CCountLbl.Text = "Count Common"
CCountLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
CCountLbl.Font = Enum.Font.GothamMedium
CCountLbl.TextSize = 10
CCountLbl.TextXAlignment = Enum.TextXAlignment.Left
CCountLbl.ZIndex = 10002

CCountInput = Instance.new("TextBox", WaterCard)
CCountInput.Size = UDim2.new(0.5, 0, 0, 22)
CCountInput.Position = UDim2.new(0.45, 0, 0, 146)
CCountInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
CCountInput.Text = tostring(commonWaterCount)
CCountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
CCountInput.Font = Enum.Font.GothamBold
CCountInput.TextSize = 10
CCountInput.ZIndex = 10002
Instance.new("UICorner", CCountInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", CCountInput).Color = Color3.fromRGB(75, 85, 99)
CCountInput.FocusLost:Connect(function()
    local num = tonumber(CCountInput.Text)
    if num and num > 0 then commonWaterCount = num else CCountInput.Text = tostring(commonWaterCount) end
end)

-- Jumlah Siram (Super)
SCountLbl = Instance.new("TextLabel", WaterCard)
SCountLbl.Size = UDim2.new(0.4, 0, 0, 22)
SCountLbl.Position = UDim2.new(0, 10, 0, 174)
SCountLbl.BackgroundTransparency = 1
SCountLbl.Text = "Count Super"
SCountLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
SCountLbl.Font = Enum.Font.GothamMedium
SCountLbl.TextSize = 10
SCountLbl.TextXAlignment = Enum.TextXAlignment.Left
SCountLbl.ZIndex = 10002

SCountInput = Instance.new("TextBox", WaterCard)
SCountInput.Size = UDim2.new(0.5, 0, 0, 22)
SCountInput.Position = UDim2.new(0.45, 0, 0, 174)
SCountInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
SCountInput.Text = tostring(superWaterCount)
SCountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SCountInput.Font = Enum.Font.GothamBold
SCountInput.TextSize = 10
SCountInput.ZIndex = 10002
Instance.new("UICorner", SCountInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", SCountInput).Color = Color3.fromRGB(75, 85, 99)
SCountInput.FocusLost:Connect(function()
    local num = tonumber(SCountInput.Text)
    if num and num > 0 then superWaterCount = num else SCountInput.Text = tostring(superWaterCount) end
end)

-- Target Selector
WaterStatus = Instance.new("TextLabel", WaterCard)
WaterStatus.Size = UDim2.new(1, -20, 0, 15)
WaterStatus.Position = UDim2.new(0, 10, 0, 316)
WaterStatus.BackgroundTransparency = 1
WaterStatus.Text = "Status: IDLE"
WaterStatus.TextColor3 = Color3.fromRGB(16, 185, 129)
WaterStatus.Font = Enum.Font.GothamMedium
WaterStatus.TextSize = 10
WaterStatus.TextXAlignment = Enum.TextXAlignment.Left
WaterStatus.ZIndex = 10002

ownerOptions = {"None"}
seedOptions = {"None"}
btnSeed = nil -- predeclare

btnOwnerTitle = Instance.new("TextLabel", WaterCard)
btnOwnerTitle.Size = UDim2.new(0.4, 0, 0, 22)
btnOwnerTitle.Position = UDim2.new(0, 10, 0, 202)
btnOwnerTitle.BackgroundTransparency = 1
btnOwnerTitle.Text = "Target Plot"
btnOwnerTitle.TextColor3 = Color3.fromRGB(156, 163, 175)
btnOwnerTitle.Font = Enum.Font.GothamMedium
btnOwnerTitle.TextSize = 10
btnOwnerTitle.TextXAlignment = Enum.TextXAlignment.Left
btnOwnerTitle.ZIndex = 10002

btnOwner = Instance.new("TextButton", WaterCard)
btnOwner.Size = UDim2.new(0.5, 0, 0, 22)
btnOwner.Position = UDim2.new(0.45, 0, 0, 202)
btnOwner.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
btnOwner.Text = selectedWaterOwner
btnOwner.TextColor3 = Color3.fromRGB(255, 255, 255)
btnOwner.Font = Enum.Font.GothamBold
btnOwner.TextSize = 10
btnOwner.ZIndex = 10002
Instance.new("UICorner", btnOwner).CornerRadius = UDim.new(0, 6)
btnOwner.MouseButton1Click:Connect(function()
    openDropdown("PILIH TARGET PLOT", ownerOptions, function(sel)
        btnOwner.Text = sel
        selectedWaterOwner = sel
        
        seedOptions = {"None"}
        if selectedWaterOwner ~= "None" and plotCache[selectedWaterOwner] then
            local seen = {}
            for sName, _ in pairs(plotCache[selectedWaterOwner].Plants) do
                if not seen[sName] then
                    seen[sName] = true
                    table.insert(seedOptions, sName)
                end
            end
        end
        selectedWaterSeed = "None"
        if btnSeed then btnSeed.Text = "None" end
    end)
end)

btnSeedTitle = Instance.new("TextLabel", WaterCard)
btnSeedTitle.Size = UDim2.new(0.4, 0, 0, 22)
btnSeedTitle.Position = UDim2.new(0, 10, 0, 230)
btnSeedTitle.BackgroundTransparency = 1
btnSeedTitle.Text = "Target Seed"
btnSeedTitle.TextColor3 = Color3.fromRGB(156, 163, 175)
btnSeedTitle.Font = Enum.Font.GothamMedium
btnSeedTitle.TextSize = 10
btnSeedTitle.TextXAlignment = Enum.TextXAlignment.Left
btnSeedTitle.ZIndex = 10002

btnSeed = Instance.new("TextButton", WaterCard)
btnSeed.Size = UDim2.new(0.5, 0, 0, 22)
btnSeed.Position = UDim2.new(0.45, 0, 0, 230)
btnSeed.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
btnSeed.Text = selectedWaterSeed
btnSeed.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSeed.Font = Enum.Font.GothamBold
btnSeed.TextSize = 10
btnSeed.ZIndex = 10002
Instance.new("UICorner", btnSeed).CornerRadius = UDim.new(0, 6)
btnSeed.MouseButton1Click:Connect(function()
    openDropdown("PILIH TARGET SEED", seedOptions, function(sel)
        btnSeed.Text = sel
        selectedWaterSeed = sel
    end)
end)

RefreshTargetsBtn = Instance.new("TextButton", WaterCard)
RefreshTargetsBtn.Size = UDim2.new(0.9, 0, 0, 25)
RefreshTargetsBtn.Position = UDim2.new(0.05, 0, 0, 266)
RefreshTargetsBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
RefreshTargetsBtn.Text = "Refresh Target List"
RefreshTargetsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshTargetsBtn.Font = Enum.Font.GothamBold
RefreshTargetsBtn.TextSize = 10
RefreshTargetsBtn.ZIndex = 10002
Instance.new("UICorner", RefreshTargetsBtn).CornerRadius = UDim.new(0, 6)
RefreshTargetsBtn.MouseButton1Click:Connect(function()
    local seen = {["None"] = true}
    ownerOptions = {"None"}
    
    local gardens = Workspace:FindFirstChild("Gardens")
    if gardens then
        for _, plot in ipairs(gardens:GetChildren()) do
            local ownerAttr = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
            if ownerAttr and not seen[ownerAttr] then
                seen[ownerAttr] = true
                table.insert(ownerOptions, ownerAttr)
            end
        end
    end
    
    for ownerAttr, _ in pairs(plotCache) do
        if not seen[ownerAttr] then
            seen[ownerAttr] = true
            table.insert(ownerOptions, ownerAttr)
        end
    end
    
    local found = false
    for _, o in ipairs(ownerOptions) do if o == selectedWaterOwner then found = true break end end
    if not found then selectedWaterOwner = "None"; btnOwner.Text = "None" end
    
    seedOptions = {"None"}
    if selectedWaterOwner ~= "None" then
        local plot = getPlotByOwner(selectedWaterOwner)
        if plotCache[selectedWaterOwner] then
            local seen = {}
            for sName, _ in pairs(plotCache[selectedWaterOwner].Plants) do
                if not seen[sName] then
                    seen[sName] = true
                    table.insert(seedOptions, sName)
                end
            end
        end
    end
    local foundSeed = false
    for _, s in ipairs(seedOptions) do if s == selectedWaterSeed then foundSeed = true break end end
    if not foundSeed then selectedWaterSeed = "None"; btnSeed.Text = "None" end

    RefreshTargetsBtn.Text = "Refreshed!"
    task.delay(1, function() if RefreshTargetsBtn.Parent then RefreshTargetsBtn.Text = "Refresh Target List" end end)
end)

-- ==========================================
-- 9. AUTO TROWEL PLANT CARD
-- ==========================================
-- card fields merge into Trowel table above
Trowel.card = createCard("TrowelCard", 260, 9)

do
    local t = Instance.new("TextLabel", Trowel.card)
    t.Size = UDim2.new(1, -20, 0, 25); t.Position = UDim2.new(0, 10, 0, 5)
    t.BackgroundTransparency = 1; t.Text = "AUTO TROWEL PLANT"
    t.TextColor3 = Color3.fromRGB(168, 85, 247); t.Font = Enum.Font.GothamBold
    t.TextSize = 11; t.TextXAlignment = Enum.TextXAlignment.Left; t.ZIndex = 10002
end

createToggle("Enable Auto Trowel", Trowel.card, 30, Trowel.enabled, function(state) Trowel.enabled = state end)

-- Mode dropdown (Good / Player / Saved / Random)
Trowel.modeOptions = {"Good", "Player", "Saved", "Random"}
Trowel.modeBtn = Instance.new("TextButton", Trowel.card)
Trowel.modeBtn.Size = UDim2.new(0.5, 0, 0, 24)
Trowel.modeBtn.Position = UDim2.new(0.45, 0, 0, 68)
Trowel.modeBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
Trowel.modeBtn.Text = Trowel.mode
Trowel.modeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Trowel.modeBtn.Font = Enum.Font.GothamBold
Trowel.modeBtn.TextSize = 10
Trowel.modeBtn.ZIndex = 10002
Instance.new("UICorner", Trowel.modeBtn).CornerRadius = UDim.new(0, 6)

Trowel.modeLbl = Instance.new("TextLabel", Trowel.card)
Trowel.modeLbl.Size = UDim2.new(0.4, 0, 0, 22)
Trowel.modeLbl.Position = UDim2.new(0, 10, 0, 70)
Trowel.modeLbl.BackgroundTransparency = 1
Trowel.modeLbl.Text = "Mode"
Trowel.modeLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
Trowel.modeLbl.Font = Enum.Font.GothamMedium
Trowel.modeLbl.TextSize = 10
Trowel.modeLbl.TextXAlignment = Enum.TextXAlignment.Left
Trowel.modeLbl.ZIndex = 10002

Trowel.modeBtn.MouseButton1Click:Connect(function()
    openDropdown("PILIH MODE", Trowel.modeOptions, function(selected)
        Trowel.mode = selected
        Trowel.modeBtn.Text = selected
        task.spawn(saveConfig)
    end)
end)

-- Seed filter dropdown
Trowel.seedLbl = Instance.new("TextLabel", Trowel.card)
Trowel.seedLbl.Size = UDim2.new(0.4, 0, 0, 22)
Trowel.seedLbl.Position = UDim2.new(0, 10, 0, 100)
Trowel.seedLbl.BackgroundTransparency = 1
Trowel.seedLbl.Text = "Seed Filter"
Trowel.seedLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
Trowel.seedLbl.Font = Enum.Font.GothamMedium
Trowel.seedLbl.TextSize = 10
Trowel.seedLbl.TextXAlignment = Enum.TextXAlignment.Left
Trowel.seedLbl.ZIndex = 10002

Trowel.seedBtn = Instance.new("TextButton", Trowel.card)
Trowel.seedBtn.Size = UDim2.new(0.5, 0, 0, 24)
Trowel.seedBtn.Position = UDim2.new(0.45, 0, 0, 98)
Trowel.seedBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
Trowel.seedBtn.Text = Trowel.seedFilter
Trowel.seedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Trowel.seedBtn.Font = Enum.Font.GothamBold
Trowel.seedBtn.TextSize = 10
Trowel.seedBtn.ZIndex = 10002
Instance.new("UICorner", Trowel.seedBtn).CornerRadius = UDim.new(0, 6)

Trowel.seedBtn.MouseButton1Click:Connect(function()
    local seedOpts = {"All"}
    local plotId = LocalPlayer:GetAttribute("PlotId")
    if plotId then
        local plot = Gardens:FindFirstChild("Plot" .. tostring(plotId))
        if plot then
            local seen = {}
            for _, child in ipairs(plot:GetDescendants()) do
                if child:IsA("Model") and child:GetAttribute("SeedName") then
                    local sn = child:GetAttribute("SeedName")
                    if not seen[sn] then seen[sn] = true; table.insert(seedOpts, sn) end
                end
            end
        end
    end
    openDropdown("PILIH SEED", seedOpts, function(selected)
        Trowel.seedFilter = selected
        Trowel.seedBtn.Text = selected
        task.spawn(saveConfig)
    end)
end)

-- Save Position button
Trowel.saveBtn = Instance.new("TextButton", Trowel.card)
Trowel.saveBtn.Size = UDim2.new(0.9, 0, 0, 28)
Trowel.saveBtn.Position = UDim2.new(0.05, 0, 0, 135)
Trowel.saveBtn.BackgroundColor3 = Color3.fromRGB(88, 28, 135)
Trowel.saveBtn.Text = "Save Current Position"
Trowel.saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Trowel.saveBtn.Font = Enum.Font.GothamBold
Trowel.saveBtn.TextSize = 11
Trowel.saveBtn.ZIndex = 10002
Instance.new("UICorner", Trowel.saveBtn).CornerRadius = UDim.new(0, 6)

Trowel.saveBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            Trowel.savedPos = hrp.Position
            Trowel.saveBtn.Text = "Saved! (" .. math.floor(hrp.Position.X) .. ", " .. math.floor(hrp.Position.Z) .. ")"
            task.spawn(saveConfig)
            task.delay(2, function()
                if Trowel.saveBtn.Parent then Trowel.saveBtn.Text = "Save Current Position" end
            end)
        end
    end
end)

-- Reset moved plants button
Trowel.resetBtn = Instance.new("TextButton", Trowel.card)
Trowel.resetBtn.Size = UDim2.new(0.43, 0, 0, 24)
Trowel.resetBtn.Position = UDim2.new(0.05, 0, 0, 170)
Trowel.resetBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
Trowel.resetBtn.Text = "Reset Moved"
Trowel.resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Trowel.resetBtn.Font = Enum.Font.GothamBold
Trowel.resetBtn.TextSize = 10
Trowel.resetBtn.ZIndex = 10002
Instance.new("UICorner", Trowel.resetBtn).CornerRadius = UDim.new(0, 6)

Trowel.resetBtn.MouseButton1Click:Connect(function()
    Trowel.moved = {}
    Trowel.retries = {}
    Trowel.resetBtn.Text = "Reset OK!"
    task.delay(1, function() if Trowel.resetBtn.Parent then Trowel.resetBtn.Text = "Reset Moved" end end)
end)

-- Status label
Trowel.status = Instance.new("TextLabel", Trowel.card)
Trowel.status.Size = UDim2.new(0.9, 0, 0, 30)
Trowel.status.Position = UDim2.new(0.05, 0, 0, 198)
Trowel.status.BackgroundTransparency = 1
Trowel.status.Text = "Status: OFF"
Trowel.status.TextColor3 = Color3.fromRGB(107, 114, 128)
Trowel.status.Font = Enum.Font.GothamMedium
Trowel.status.TextSize = 10
Trowel.status.TextWrapped = true
Trowel.status.TextXAlignment = Enum.TextXAlignment.Left
Trowel.status.ZIndex = 10002

-- ==========================================
-- AUTO WATER BACKGROUND LOOP
task.spawn(function()
    local lastWaterTime = 0
    while true do
        task.wait(1)
        if not autoWaterEnabled or not ScreenGui.Parent then continue end
        if selectedWaterOwner == "None" or selectedWaterSeed == "None" then
            WaterStatus.Text = "Status: Target belum dipilih."
            continue
        end

        local plot = getPlotByOwner(selectedWaterOwner)
        local cData = plotCache[selectedWaterOwner]
        
        if not plot and not cData then
            WaterStatus.Text = "Status: Plot tidak ditemukan."
            continue
        end

        -- Titik disesuaikan dengan radius kaleng yang benar-benar dipilih, dan
        -- yang dipilih adalah titik dengan tanaman sejenis TERBANYAK dalam satu
        -- semprotan -- bukan tanaman mana pun yang kebetulan terakhir dicatat.
        local radius = Siram.radius(selectedWaterTool)
        local plantPos, cakupan = getPlantPos(selectedWaterOwner, selectedWaterSeed, radius)
        if not plantPos then
            WaterStatus.Text = "Status: Pohon tidak ditemukan di Plot!"
            continue
        end
        local totalTanaman = 0
        local cData0 = plotCache[selectedWaterOwner]
        if cData0 and cData0.Plants and cData0.Plants[selectedWaterSeed] then
            totalTanaman = #cData0.Plants[selectedWaterSeed]
        end

        local pullCenter = (cData and cData.PullCenter) or plantPos
        local plotNum = (cData and cData.PlotNum) or 1

        local dirXZ = Vector3.new(pullCenter.X - plantPos.X, 0, pullCenter.Z - plantPos.Z)
        local pullDistance = 3.5
        
        if dirXZ.Magnitude > 0 then 
            if dirXZ.Magnitude < pullDistance then pullDistance = dirXZ.Magnitude end
            dirXZ = dirXZ.Unit 
        else 
            dirXZ = Vector3.new(0,0,1) 
            pullDistance = 0
        end
        
        local safeSprinklerPos = plantPos + (dirXZ * pullDistance)
        safeSprinklerPos = Vector3.new(safeSprinklerPos.X, plantPos.Y, safeSprinklerPos.Z)
        local safePlayerPos = plantPos + (dirXZ * 8.0)

        local needsSprinkler = false
        if type(selectedSprinklerTool) == "table" and #selectedSprinklerTool > 0 then
            local activeCount = 0
            for _, sprName in ipairs(selectedSprinklerTool) do
                if getActiveSprinklerCount(plot, sprName) > 0 then
                    activeCount = activeCount + 1
                end
            end
            if activeCount == 0 then
                local firstSpr = selectedSprinklerTool[1]
                local lastT = (lastSprinklerTime[selectedWaterOwner] and lastSprinklerTime[selectedWaterOwner][firstSpr]) or 0
                if os.clock() - lastT > 3 then
                    needsSprinkler = true
                end
            end
        end
        local needsWater = (os.clock() - lastWaterTime >= autoWaterDelay) and type(selectedWaterTool) == "table" and #selectedWaterTool > 0

        if needsSprinkler or needsWater then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            
            local originalCFrame = root.CFrame
            local originalPos = root.Position
            local plotNum = tonumber(string.match(plot.Name, "%d+")) or 1

            -- Pasang Sprinkler
            if needsSprinkler then
                WaterStatus.Text = "Status: Memasang Sprinkler..."
                local placedCount = 1
                local totalSprinklers = #selectedSprinklerTool
                
                for _, sprName in ipairs(selectedSprinklerTool) do
                    local spTool = equipTool(sprName)
                    if spTool and RemoteEvent then
                        -- [FIX KENTANG] Tunggu lebih lama agar server memproses Tool sudah dipegang
                        task.wait(1)
                        
                        local angleDeg = (placedCount - 1) * (360 / math.max(1, totalSprinklers))
                        local angleRad = math.rad(angleDeg)
                        local c = math.cos(angleRad)
                        local s = math.sin(angleRad)
                        local rotDir = Vector3.new(c, 0, s)
                        
                        local distance = 3
                        local placePos = plantPos + (rotDir * distance)
                        
                        local ref = plot:FindFirstChild("PlotSizeReference")
                        local groundY = ref and (ref.Position.Y + ref.Size.Y/2) or plantPos.Y
                        placePos = Vector3.new(placePos.X, groundY, placePos.Z)
                        
                        -- [FIX KENTANG] Spam penempatan 4x agar pasti masuk meski ping merah / lag
                        task.spawn(function()
                            for i=1, 4 do
                                pcall(function() Networking.Place.PlaceSprinkler:Fire(placePos, spTool.Name, spTool, plotNum) end)
                                task.wait(0.3)
                            end
                        end)
                        
                        if not lastSprinklerTime[selectedWaterOwner] then lastSprinklerTime[selectedWaterOwner] = {} end
                        lastSprinklerTime[selectedWaterOwner][sprName] = os.clock()
                        
                        -- [FIX KENTANG] Tunggu animasi/server memproses penempatan selesai
                        task.wait(1.5)
                    end
                    placedCount = placedCount + 1
                end
                task.wait(1)
            end

            -- Siram jika delay sudah tercapai
            if needsWater then
                local cam = workspace.CurrentCamera
                cam.CameraType = Enum.CameraType.Scriptable
                
                WaterStatus.Text = "Status: Terbang ke pohon (Menyiram)..."
                if flyToTarget(safePlayerPos) then
                    -- Cakupan ditampilkan supaya kelihatan titiknya memang
                    -- gerombolan, bukan tanaman yang berdiri sendirian.
                    WaterStatus.Text = string.format(
                        "Status: Menyiram! %d/%d %s kena (radius %d)",
                        cakupan or 0, totalTanaman, selectedWaterSeed, radius)
                    
                    -- Cek jika ada 2 alat (Common & Super)
                    local hasCommon = false
                    local hasSuper = false
                    local commonName, superName
                    for _, wt in ipairs(selectedWaterTool) do
                        if string.find(wt, "Common") then
                            hasCommon = true
                            commonName = wt
                        elseif string.find(wt, "Super") then
                            hasSuper = true
                            superName = wt
                        end
                    end
                    
                    if hasCommon and hasSuper then
                        -- Lakukan 5x Common, 1x Super
                        ensureAtTarget(safePlayerPos)
                        local waterTool = equipTool(commonName)
                        if waterTool and RemoteEvent then
                            task.wait(0.3)
                            for i = 1, commonWaterCount do
                                pcall(function() Networking.WateringCan.UseWateringCan:Fire(plantPos - Vector3.new(0, 0.3, 0), waterTool.Name, waterTool) end)
                                task.wait(0.1)
                            end
                            task.wait(0.3)
                        end
                        task.wait(0.25)
                        
                        ensureAtTarget(safePlayerPos)
                        local superTool = equipTool(superName)
                        if superTool and RemoteEvent then
                            task.wait(0.3)
                            for i = 1, superWaterCount do
                                pcall(function() Networking.WateringCan.UseWateringCan:Fire(plantPos - Vector3.new(0, 0.3, 0), superTool.Name, superTool) end)
                                task.wait(0.1)
                            end
                            task.wait(0.3)
                        end
                    else
                        -- Jika hanya ada 1 tipe alat penyiram
                        for _, wt in ipairs(selectedWaterTool) do
                            ensureAtTarget(safePlayerPos)
                            local waterTool = equipTool(wt)
                            if waterTool and RemoteEvent then
                                task.wait(0.3)
                                local count = string.find(wt, "Super") and superWaterCount or commonWaterCount
                                for i = 1, count do
                                    pcall(function() Networking.WateringCan.UseWateringCan:Fire(plantPos - Vector3.new(0, 0.3, 0), waterTool.Name, waterTool) end)
                                    task.wait(0.1)
                                end
                                task.wait(0.3)
                            end
                        end
                    end
                    lastWaterTime = os.clock()
                    WaterStatus.Text = "Status: Selesai menyiram."
                else
                    WaterStatus.Text = "Status: Gagal sampai ke target."
                end
            end

            -- Terbang kembali ke tempat awal
            if needsWater then
                WaterStatus.Text = "Status: Kembali ke tempat semula..."
                flyToTarget(originalPos)
                local char = game.Players.LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = originalCFrame
                end
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            end
            
            -- Lepas semua alat agar script game berhenti merender preview (ANTI LAG)
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:UnequipTools() end
            end
            
            WaterStatus.Text = string.format("Status: Menunggu delay... (%.0fs)", autoWaterDelay - (os.clock() - lastWaterTime))
        else
            WaterStatus.Text = string.format("Status: Menunggu delay... (%.0fs)", autoWaterDelay - (os.clock() - lastWaterTime))
        end
    end
end)

SaveBtn.MouseButton1Click:Connect(function()
    saveConfig()
    SaveBtn.Text = "SAVED TO WORKSPACE!"
    SaveBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
    task.wait(1.5)
    if SaveBtn.Parent then
        SaveBtn.Text = "SAVE CONFIG"
        SaveBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    end
end)

-- ==========================================
-- MODE SWITCHING LOGIC (HARVEST / MOZE)
-- ==========================================
local function switchMode(modeName)
    local isHarvest = (modeName == "Harvest")
    
    TabHarvest.BackgroundColor3 = isHarvest and Color3.fromRGB(31, 41, 65) or Color3.fromRGB(15, 19, 26)
    TabHarvest.TextColor3 = isHarvest and Color3.fromRGB(59, 130, 246) or Color3.fromRGB(100, 116, 139)
    TabMoze.BackgroundColor3 = not isHarvest and Color3.fromRGB(31, 41, 65) or Color3.fromRGB(15, 19, 26)
    TabMoze.TextColor3 = not isHarvest and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(100, 116, 139)

    if HarvestCard then HarvestCard.Visible = isHarvest end
    if MutationCard then MutationCard.Visible = isHarvest end
    if AutoSellCard then AutoSellCard.Visible = isHarvest end
    if WaterCard then WaterCard.Visible = isHarvest end
    
    if UtilityCard then UtilityCard.Visible = not isHarvest end
    if WeatherCard then WeatherCard.Visible = not isHarvest end
    if StatsCard then StatsCard.Visible = not isHarvest end
    if EspCard then EspCard.Visible = not isHarvest end

    local primaryColor = isHarvest and Color3.fromRGB(59, 130, 246) or Color3.fromRGB(168, 85, 247)
    
    for _, card in ipairs({HarvestCard, MutationCard, AutoSellCard, WaterCard, UtilityCard, WeatherCard, StatsCard, EspCard}) do
        if not card then continue end
        
        for _, child in ipairs(card:GetChildren()) do
            if child:IsA("TextLabel") and child.TextSize >= 10 and child.Font == Enum.Font.GothamBold then
                child.TextColor3 = primaryColor
            end
        end
    end
end

TabHarvest.MouseButton1Click:Connect(function() switchMode("Harvest") end)
TabMoze.MouseButton1Click:Connect(function() switchMode("Moze") end)
switchMode("Harvest")

-- Panggil check sekali setelah load UI
checkWeatherKick()

-- ==========================================
-- LOOP AUTO-NUKE & DESTROY PLANTS AFK
-- ==========================================
task.spawn(function()
    while true do
        task.wait(5) 
        if not ScreenGui or not ScreenGui.Parent then break end
        
        -- Hancurkan kebun orang lain
        if autoNukeOthersEnabled then
            if Gardens then
                for _, plot in ipairs(Gardens:GetChildren()) do
                    local ownerName = plot:GetAttribute("Owner")
                    local ownerId = plot:GetAttribute("OwnerUserId")
                    
                    if ownerName ~= LocalPlayer.Name and ownerId ~= LocalPlayer.UserId then
                        if ownerName then
                            if not plotCache[ownerName] then plotCache[ownerName] = { Plants = {} } end
                            local cData = plotCache[ownerName]
                            cData.PlotNum = tonumber(string.match(plot.Name, "%d+")) or 1
                            Siram.rekam(cData, plot:FindFirstChild("Plants"))
                        end
                        pcall(function() plot:Destroy() end)
                    end
                end
            end
        end
        
        -- Hancurkan TANAMAN di semua kebun (termasuk milik kita sendiri demi FPS/AFK)
        if destroyAllPlantsEnabled then
            if Gardens then
                for _, plot in ipairs(Gardens:GetChildren()) do
                    local ownerName = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
                    local plants = plot:FindFirstChild("Plants")
                    if plants then
                        if ownerName then
                            if not plotCache[ownerName] then plotCache[ownerName] = { Plants = {} } end
                            local cData = plotCache[ownerName]
                            cData.PlotNum = tonumber(string.match(plot.Name, "%d+")) or 1
                            Siram.rekam(cData, plants)
                        end
                        -- Kita hanya menghancurkan isinya agar gamenya tidak error saat bibit baru tumbuh
                        for _, plant in ipairs(plants:GetChildren()) do
                            pcall(function() plant:Destroy() end)
                        end
                    end
                end
            end
        end
    end
end)
-- ==========================================
-- PERIODIC WORLD OPTIMIZER (REVISI: BENAR-BENAR ANTI LAG)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(5) 
        
        if not ScreenGui.Parent then break end
        
        if ultraBoostEnabled and Gardens then
            pcall(function()
                local checkCount = 0
                
                for _, plot in ipairs(Gardens:GetChildren()) do
                    local descendants = plot:GetDescendants()
                    
                    for i = 1, #descendants do
                        local desc = descendants[i]
                        
                        checkCount = checkCount + 1
                        
                        if checkCount % 100 == 0 then
                            RunService.Heartbeat:Wait()
                        end
                        
                        if not desc:GetAttribute("IsBrutalized") then
                            superBrutalize(desc)
                            desc:SetAttribute("IsBrutalized", true)
                        end
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- ANTI AFK SYSTEM (CUSTOM + ROBLOX DEFAULT)
-- ==========================================
LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

task.spawn(function()
    while true do
        task.wait(math.random(150, 240)) 
        if not ScreenGui.Parent then break end
        
        if antiAfkEnabled then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            
            pcall(function()
                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Jump = true
                end
            end)
        end
    end
end)

-- ==========================================
-- MUTATION CHECK HELPER
-- ==========================================
local function shouldHarvestByMutation(fruitModel)
    -- Jika filter mutasi dimatikan, panen semua
    if not mutationFilterEnabled then
        return true
    end
    
    -- Ambil mutasi dari fruit model
    local mutation = fruitModel:GetAttribute("Mutation")
    local hasMutation = mutation and mutation ~= ""
    
    -- Jika user mencentang "HANYA Panen Non-Mutasi", tolak SEMUA buah bermutasi
    if harvestNoMutation then
        return not hasMutation -- Hanya boleh panen jika tidak ada mutasi
    end
    
    -- Jika buah TIDAK punya mutasi (sedangkan user mencari mutasi)
    if not hasMutation then
        return false 
    end
    
    -- Cek apakah mutasi buah ada di daftar yang dipilih
    return selectedMutations[mutation] == true
end

-- ==========================================
-- FARMING & SELLING LOGIC
-- ==========================================
local function getMyPlot()
    for _, plot in ipairs(workspace.Gardens:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.Name or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

-- Deteksi PacketEvent dari server
local PacketEvent = ReplicatedStorage:FindFirstChild("PacketEvent", true)



local isSelling = false
-- Fungsi mandiri untuk menjual semua buah
local function PerformSell()
    if isSelling then return end
    
    local fruits = {}
    
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if isSellableFruit(item) then table.insert(fruits, item) end
    end
    if LocalPlayer.Character then
        for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
            if isSellableFruit(item) then table.insert(fruits, item) end
        end
    end

    if #fruits > 0 then
        isSelling = true
        task.spawn(function()
            if autoSellFilterEnabled then
                for _, tool in ipairs(fruits) do
                    local id = tool:GetAttribute("Id")
                    if id and tool.Parent then
                        local pass = true
                        local toolName = tool.Name
                        
                        -- Fruit Filter
                        if sellFilterOptions.Fruit ~= "Any" and not string.match(toolName, sellFilterOptions.Fruit) then
                            pass = false
                        end
                        
                        -- Mutation Filter
                        if pass and sellFilterOptions.Mutation ~= "Any" and not string.match(toolName, sellFilterOptions.Mutation) then
                            pass = false
                        end
                        
                        -- Rarity Filter
                        if pass and sellFilterOptions.Rarity ~= "Any" then
                            local rarity = tool:GetAttribute("Rarity") or ""
                            if rarity ~= sellFilterOptions.Rarity and not string.match(toolName, sellFilterOptions.Rarity) then
                                pass = false
                            end
                        end
                        
                        -- Threshold Filter
                        if pass and sellFilterOptions.ThresholdMode ~= "Any" then
                            local weightStr = string.match(toolName, "%[(%d+%.?%d*)kg%]")
                            local val = tonumber(weightStr) or 0
                            local thr = sellFilterOptions.ThresholdValue
                            
                            if sellFilterOptions.ThresholdMode == "Below (<)" and val >= thr then pass = false
                            elseif sellFilterOptions.ThresholdMode == "Above (>)" and val <= thr then pass = false
                            elseif sellFilterOptions.ThresholdMode == "Equal (==)" and val ~= thr then pass = false
                            end
                        end
                        
                        if pass then
                            pcall(function() Networking.NPCS.SellFruit:Fire(id) end)
                            task.wait(0.05)
                        end
                    end
                end
            elseif autoSellEnabled then
                pcall(function()
                    Networking.NPCS.SellAll:Fire()
                end)
            end
            task.wait(0.5)
            isSelling = false
        end)
    end
end

-- LOOP 1: AUTO HARVEST (DENGAN MUTATION FILTER)
task.spawn(function()
    local RunService = game:GetService("RunService")
    while true do
        RunService.Heartbeat:Wait()
        
        if not ScreenGui.Parent then break end

        if autoHarvestEnabled then
            local Plot = getMyPlot()
            local Plants = Plot and Plot:FindFirstChild("Plants")
            
            if Plants then
                local harvestableFruits = {}
                
                for _, plant in ipairs(Plants:GetChildren()) do
                    local sName = plant:GetAttribute("SeedName") or plant.Name
                    if sName:match("Eclipse") then
                        continue -- IGNORE ECLIPSE BLOOM DARI AUTO HARVEST
                    end
                    
                    local fruitsFolder = plant:FindFirstChild("Fruits")
                    if fruitsFolder then
                        for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                            local harvestPart = fruitModel:FindFirstChild("HarvestPart")
                            local prompt = harvestPart and harvestPart:FindFirstChild("HarvestPrompt")
                            
                            if prompt and prompt:IsA("ProximityPrompt") then
                                local weight = FruitVisualizer:CalculateFruitWeight(fruitModel) or 0
                                table.insert(harvestableFruits, {
                                    model = fruitModel, 
                                    prompt = prompt, 
                                    weight = weight,
                                    plant = plant
                                })
                            end
                        end
                    end
                end

                table.sort(harvestableFruits, function(a, b)
                    return a.weight > b.weight
                end)

                for _, item in ipairs(harvestableFruits) do
                    if not autoHarvestEnabled then break end
                    
                    local lastHarvest = recentlyHarvested[item.prompt]
                    if not lastHarvest or (os.clock() - lastHarvest) > 0 then
                        local shouldHarvest = false
                        
                        if autoHarvestMode == "Any" then
                            shouldHarvest = true
                        elseif autoHarvestMode == "Above" and item.weight >= autoHarvestThreshold then
                            shouldHarvest = true
                        elseif autoHarvestMode == "Below" and item.weight <= autoHarvestThreshold then
                            shouldHarvest = true
                        end

                        -- CEK FILTER MUTASI (BARU!)
                        if shouldHarvest then
                            shouldHarvest = shouldHarvestByMutation(item.model)
                        end

                        if shouldHarvest then
                            recentlyHarvested[item.prompt] = os.clock()
                            
                            local plantId = item.plant:GetAttribute("Id") or item.plant.Name
                            local fruitId = item.model:GetAttribute("Id") or item.model.Name
                            
                            if PacketEvent and plantId and fruitId then
                                local packet1 = "\xCD\x00$" .. tostring(plantId) .. "$" .. tostring(fruitId)
                                pcall(function() PacketEvent:FireServer(buffer.fromstring(packet1)) end)
                                
                                local packet2 = "\xCD\x00$" .. tostring(fruitId) .. "$" .. tostring(plantId)
                                pcall(function() PacketEvent:FireServer(buffer.fromstring(packet2)) end)
                            else
                                task.spawn(function() pcall(fireproximityprompt, item.prompt) end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- LOOP 2: AUTO SELL (HEARTBEAT FAST SELL)
game:GetService("RunService").Heartbeat:Connect(function()
    if autoSellEnabled or autoSellFilterEnabled then
        PerformSell()
    end
end)

-- ==========================================
-- STATS MONITORING
-- ==========================================
local function updateStats()
    -- 1. Update Sheckles
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local sheckles = leaderstats:FindFirstChild("Sheckles")
        if sheckles then
            local val = tostring(sheckles.Value)
            local formatted = val:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            ShecklesLabel.Text = "Sheckles: " .. formatted
        end
    end

    -- 2. Update Plant Counts berdasarkan SeedName
    local plot = getMyPlot()
    local plantText = "Garden Plants:\n"

    if plot then
        local plantsFolder = plot:FindFirstChild("Plants")
        if plantsFolder then
            local plantCounts = {}
            local totalPlants = 0
            local currentFruits = 0
            local maxFruits = 0

            for _, plant in ipairs(plantsFolder:GetChildren()) do
                local seedName = plant:GetAttribute("SeedName")
                if seedName then
                    plantCounts[seedName] = (plantCounts[seedName] or 0) + 1
                    totalPlants = totalPlants + 1
                    
                    local fFolder = plant:FindFirstChild("Fruits")
                    local spawnFolder = plant:FindFirstChild("FruitSpawnLocations")
                    local cF = 0
                    local mF = 0
                    if spawnFolder then
                        mF = #spawnFolder:GetChildren()
                    end
                    if fFolder then
                        for _, fModel in ipairs(fFolder:GetChildren()) do
                            if fModel:IsA("Model") and fModel:FindFirstChild("HarvestPart") then
                                cF = cF + 1
                            end
                        end
                    end
                    
                    maxFruits = maxFruits + mF
                    currentFruits = currentFruits + cF
                end
            end
            
            if TotalFruitLabel then
                TotalFruitLabel.Text = "Total Fruit: " .. currentFruits .. "/" .. maxFruits
            end

            if totalPlants > 0 then
                for name, count in pairs(plantCounts) do
                    plantText = plantText .. "- " .. name .. ": " .. count .. "x\n"
                end
            else
                plantText = plantText .. "(Tidak ada tanaman)"
            end
        else
            plantText = plantText .. "(Folder Plants tidak ditemukan)"
        end
    else
        plantText = plantText .. "(Belum claim plot)"
    end

    PlantsLabel.Text = plantText
end

task.wait(2)
if ScreenGui.Parent then
    updateStats()
    task.spawn(function()
        while ScreenGui.Parent do
            task.wait(3)
            updateStats()
        end
    end)
end

-- ==========================================
-- AUTO TROWEL BACKGROUND LOOP
-- ==========================================
task.spawn(function()
    local Networking = nil
    pcall(function()
        Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
    end)
    if not Networking or not Networking.Trowel then
        warn("[AutoTrowel] Networking.Trowel tidak ditemukan")
        return
    end

    local _ = nil -- placeholder (lastTrowelMove dihapus, throttle sudah tidak ada)

    while true do
        task.wait(0.1)
        if not Trowel.enabled or not ScreenGui.Parent then continue end
        if not Networking.Trowel.MovePlant then continue end

        -- Cari plot pemain
        local plotId = LocalPlayer:GetAttribute("PlotId")
        if not plotId then
            Trowel.status.Text = "Status: PlotId tidak ditemukan"
            continue
        end
        local plot = Gardens:FindFirstChild("Plot" .. tostring(plotId))
        if not plot then
            Trowel.status.Text = "Status: Plot tidak ditemukan"
            continue
        end

        -- Verifikasi async: cek pohon yang sudah ditandai moved
        if Trowel.pendingVerify then
            for pid, pv in pairs(Trowel.pendingVerify) do
                if pv and pv.prePos then
                    -- Cari model berdasarkan plantId (model.Name)
                    local found = plot:FindFirstChild(pid)
                    if found and found.PrimaryPart then
                        local dist = (found.PrimaryPart.Position - pv.prePos).Magnitude
                        if dist < 1 then
                            -- Tidak berpindah → unmark + retry
                            Trowel.moved[pid] = nil
                            Trowel.retries[pid] = (Trowel.retries[pid] or 0) + 1
                            if Trowel.retries[pid] >= 3 then
                                Trowel.moved[pid] = true -- skip setelah 3x gagal
                            end
                        end
                    end
                    Trowel.pendingVerify[pid] = nil
                end
            end
        end

        -- Kumpulkan semua root plants (yang punya SeedName)
        local allPlants = {}
        local uniqueSeeds = {}
        for _, child in ipairs(plot:GetDescendants()) do
            if child:IsA("Model") and child:GetAttribute("SeedName") and child.PrimaryPart then
                local seedName = child:GetAttribute("SeedName")
                uniqueSeeds[seedName] = true
                if not Trowel.moved[child.Name] then
                    local sz = child:GetExtentsSize()
                    local vol = sz.X * sz.Y * sz.Z
                    table.insert(allPlants, {model = child, seed = seedName, vol = vol})
                end
            end
        end

        -- Filter by selected seed
        local plants = {}
        for _, p in ipairs(allPlants) do
            if Trowel.seedFilter == "All" or p.seed == Trowel.seedFilter then
                table.insert(plants, p)
            end
        end

        -- Good mode: sort by volume terbesar → terkecil biar grid rapi
        if Trowel.mode == "Good" and #plants > 1 then
            table.sort(plants, function(a, b) return a.vol > b.vol end)
        end

        local moved = 0
        for total in pairs(Trowel.moved) do moved = moved + 1 end
        local statusText = string.format("Moved: %d | To Move: %d | Seeds: %d", moved, #plants, (function() local c=0; for _ in pairs(uniqueSeeds) do c=c+1 end; return c end)())
        if #plants == 0 then
            Trowel.status.Text = "Status: " .. statusText .. " | DONE ✓ — Klik Reset untuk pindah lagi"
            continue
        end
        Trowel.status.Text = "Status: " .. statusText .. " | Moving..."

        -- Hitung target positions berdasarkan mode
        local positions = {}
        local psr = plot:FindFirstChild("PlotSizeReference")
        if Trowel.mode == "Good" then
            -- Grid rapi: sort by volume, spacing tetap (GetExtents includes fruits,too big)
            if psr and psr:IsA("BasePart") then
                local cf = psr.CFrame
                local sz = psr.Size
                local halfX = sz.X / 2 - 3
                local halfZ = sz.Z / 2 - 3
                -- Y baseline dari ground
                local groundY = cf.Position.Y
                local hrpChar = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrpChar then groundY = hrpChar.Position.Y - 3 end

                local count = #plants
                local cols = math.ceil(math.sqrt(count * (sz.X / sz.Z)))
                local rows = math.ceil(count / cols)
                local spacingX = (halfX * 2) / math.max(cols, 1)
                local spacingZ = (halfZ * 2) / math.max(rows, 1)

                local idx = 1
                for r = 0, rows - 1 do
                    for c = 0, cols - 1 do
                        if idx > count then break end
                        local localX = -halfX + spacingX * (c + 0.5)
                        local localZ = -halfZ + spacingZ * (r + 0.5)
                        local worldPos = cf * Vector3.new(localX, 0, localZ)
                        positions[idx] = Vector3.new(worldPos.X, groundY, worldPos.Z)
                        idx = idx + 1
                    end
                    if idx > count then break end
                end
            end
        elseif Trowel.mode == "Player" then
            -- Semua pohon numpuk di posisi player (biar kena siram semua)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for i = 1, #plants do
                    positions[i] = hrp.Position
                end
            end
        elseif Trowel.mode == "Saved" then
            if Trowel.savedPos then
                for i = 1, #plants do
                    positions[i] = Trowel.savedPos
                end
            end
        elseif Trowel.mode == "Random" then
            if psr and psr:IsA("BasePart") then
                local cf = psr.CFrame
                local sz = psr.Size
                local halfX = sz.X / 2 - 3
                local halfZ = sz.Z / 2 - 3
                local groundY = cf.Position.Y
                local hrpRand = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrpRand then groundY = hrpRand.Position.Y - 3 end
                for i = 1, #plants do
                    local rx = (math.random() - 0.5) * 2 * halfX
                    local rz = (math.random() - 0.5) * 2 * halfZ
                    local worldPos = cf * Vector3.new(rx, 0, rz)
                    positions[i] = Vector3.new(worldPos.X, groundY, worldPos.Z)
                end
            end
        end

        -- Pindahkan satu per satu dengan throttle
        for i, plantData in ipairs(plants) do
            if not Trowel.enabled then break end
            if not ScreenGui.Parent then break end

            local model = plantData.model
            local plantId = model.Name
            local targetPos = positions[i]

            if not targetPos or not model or not model.Parent then continue end

            -- Pastikan Trowel ter-equip sebelum fire
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local equipped = char and char:FindFirstChildWhichIsA("Tool")
            local hasTrowelEquipped = equipped and equipped:GetAttribute("Trowel")
            if not hasTrowelEquipped and humanoid then
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                if backpack then
                    for _, tool in ipairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("Trowel") then
                            humanoid:EquipTool(tool)
                            task.wait(0.15)
                            break
                        end
                    end
                end
            end
            -- Cek ulang setelah equip attempt
            equipped = char and char:FindFirstChildWhichIsA("Tool")
            if not equipped or not equipped:GetAttribute("Trowel") then
                Trowel.status.Text = "Status: Trowel tidak ditemukan!"
                continue
            end

            -- Fire langsung, throttle dihapus biar cepat (0.03s render wait sudah cukup)

            -- Async verify: cek posisi sebelumnya, verifikasi di iterasi berikutnya
            local prePos = model.PrimaryPart and model.PrimaryPart.Position
            Trowel.pendingVerify = Trowel.pendingVerify or {}
            Trowel.pendingVerify[plantId] = {prePos = prePos, target = targetPos}

            -- Fire remote (model.Name = unique ID, bukan PlantId!)
            local ok, err = pcall(function()
                Networking.Trowel.MovePlant:Fire(model.Name, targetPos, 0)
            end)

            if ok then
                Trowel.moved[plantId] = true
                local movedNow = 0
                for _ in pairs(Trowel.moved) do movedNow = movedNow + 1 end
                Trowel.status.Text = string.format("Status: Moved %d/%d | %s", movedNow, movedNow + #plants - i, plantData.seed)
            else
                warn("[AutoTrowel] Fire gagal:", err)
            end

            task.wait(0.03) -- beri jeda antar move biar render
        end

        -- Selesai
        local movedFinal = 0
        for _ in pairs(Trowel.moved) do movedFinal = movedFinal + 1 end
        Trowel.status.Text = "Status: Selesai! " .. movedFinal .. " pohon dipindah"
    end
end)

-- ==========================================
-- GARDEN VALUE SCANNER (FULL PROTECT)
-- ==========================================
do
    local RunService = game:GetService("RunService")
    local lastScanTime = 0

    task.spawn(function()
        while true do
            task.wait(2)
            
            -- Cek keberadaan UI (Karena pakai PlayerGui, ini 100% aman)
            if not ScreenGui or not ScreenGui.Parent then break end
        
        local success, err = pcall(function()
            local value = 0
            
            if Gardens and FruitValueCalc then
                local myPlot = nil
                for _, plot in ipairs(Gardens:GetChildren()) do
                    if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId or plot:GetAttribute("Owner") == LocalPlayer.Name then
                        myPlot = plot
                        break
                    end
                end
                
                if myPlot then
                    local plants = myPlot:FindFirstChild("Plants")
                    if plants then
                        for _, plant in ipairs(plants:GetChildren()) do
                            local fruitsFolder = plant:FindFirstChild("Fruits")
                            if fruitsFolder then
                                for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                                    if fruitModel:IsA("Model") or fruitModel:IsA("BasePart") then
                                        local fruitName = fruitModel:GetAttribute("CorePartName")
                                        local corePart = fruitName and fruitModel:FindFirstChild(fruitName) or fruitModel:FindFirstChildWhichIsA("BasePart")
                                        
                                        if not fruitName and corePart then fruitName = corePart.Name end
                                        
                                        if fruitName then
                                            local sizeMulti = fruitModel:GetAttribute("SizeMulti") or fruitModel:GetAttribute("SizeMultiplier") or (corePart and (corePart:GetAttribute("SizeMulti") or corePart:GetAttribute("SizeMultiplier"))) or 1
                                        local mutation = fruitModel:GetAttribute("Mutation") or (corePart and corePart:GetAttribute("Mutation"))
                                        local decayAlpha = fruitModel:GetAttribute("DecayAlpha") or (corePart and corePart:GetAttribute("DecayAlpha")) or 0
                                        
                                        local baseWorth = FruitValueCalc(fruitName, sizeMulti, mutation, LocalPlayer, decayAlpha)
                                        local stockMult = getStockMultiplier(fruitName)
                                        
                                        value = value + math.floor(baseWorth * stockMult)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if GardenValueLabel then
            local function formatP(n)
                if type(n) ~= "number" then return "0" end
                local left, num, right = string.match(tostring(math.floor(n)), '^([^%d]*%d)(%d*)(.-)$')
                if not left then return tostring(n) end
                return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
            end
            
            if type(FruitValueCalc) ~= "function" then
                GardenValueLabel.Text = "Garden Value: [Modul Tdk Valid]"
            else
                GardenValueLabel.Text = "Garden Value: $" .. formatP(value)
            end
        end
    end)
    
    if not success then
        -- Dibungkus pcall agar perubahan UI saat error TIDAK memicu red error lagi
        pcall(function()
            if GardenValueLabel then
                GardenValueLabel.Text = "Garden Value: [Error! Cek F9 Kuning]"
            end
        end)
        
        -- Print penyebab aslinya agar kita bisa tahu jika FruitValueCalc yang bermasalah!
        warn("========== ERROR KALKULATOR GARDEN ==========")
        warn(err)
    end
        end
    end)
end -- end do block for Garden Value Scanner

-- ==========================================
-- FRUIT ESP SCANNER LOOP (FIX BERAT KG ASLI)
-- ==========================================
do
    local FruitVisualizerController = nil;
pcall(function()
    local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts");
    local ctrl = ps:WaitForChild("Controllers");
    FruitVisualizerController = require(ctrl:WaitForChild("FruitVisualizerController"));
end);

task.spawn(function()
    while true do
        task.wait(1)
        
        if not espEnabled then continue end
    
    local success, err = pcall(function()
        local espCache = {};
        local renderedNormalCount = 0;
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui.Name == "FruitESP" and gui:IsA("BillboardGui") then
                if gui.Adornee then
                    espCache[gui.Adornee] = gui;
                else
                    gui:Destroy();
                end
            end
        end
        
        if Gardens then
            for _, plot in ipairs(Gardens:GetChildren()) do
                local plants = plot:FindFirstChild("Plants");
                if plants then
                    for _, plant in ipairs(plants:GetChildren()) do
                        local fruitsFolder = plant:FindFirstChild("Fruits");
                        if fruitsFolder then
                            for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                                if fruitModel:IsA("Model") or fruitModel:IsA("BasePart") then
                                    local fruitName = fruitModel:GetAttribute("CorePartName");
                                    local corePart = nil;
                                    
                                    if fruitName then 
                                        corePart = fruitModel:FindFirstChild(fruitName);
                                    end
                                    if not corePart then 
                                        corePart = fruitModel:FindFirstChildWhichIsA("BasePart");
                                    end
                                    if not fruitName and corePart then 
                                        fruitName = corePart.Name;
                                    end
                                    
                                    if fruitName and corePart then
                                        local mutation = fruitModel:GetAttribute("Mutation");
                                        if not mutation and corePart then 
                                            mutation = corePart:GetAttribute("Mutation");
                                        end
                                        
                                        local showFruit = false;
                                        if mutation and mutation ~= "" then
                                            if selectedEspMutations[mutation] then
                                                showFruit = true;
                                            end
                                        else
                                            if espNoMutation then
                                                if renderedNormalCount < 500 then
                                                    showFruit = true;
                                                    renderedNormalCount = renderedNormalCount + 1
                                                end
                                            end
                                        end
                                        
                                        if showFruit then
                                            local esp = espCache[corePart];
                                            local mutName = "Normal";
                                            if mutation and mutation ~= "" then mutName = mutation end
                                            
                                            local mutColor = Color3.fromRGB(255, 255, 255);
                                            if MUTATION_COLORS[mutName] then mutColor = MUTATION_COLORS[mutName] end
                                            
                                            -- AMBIL UKURAN (Secara Aman)
                                            local sizeMulti = fruitModel:GetAttribute("SizeMulti");
                                            if not sizeMulti then sizeMulti = fruitModel:GetAttribute("SizeMultiplier") end
                                            if not sizeMulti and corePart then
                                                sizeMulti = corePart:GetAttribute("SizeMulti");
                                                if not sizeMulti then sizeMulti = corePart:GetAttribute("SizeMultiplier") end
                                            end
                                            if not sizeMulti then sizeMulti = 1 end
                                            
                                            -- MENGHITUNG BERAT ASLI
                                            local realWeight = sizeMulti;
                                            if FruitVisualizerController then
                                                pcall(function()
                                                    local calc = FruitVisualizerController.CalculateFruitWeight(FruitVisualizerController, fruitModel);
                                                    if calc then realWeight = calc end
                                                end)
                                            end
                                            
                                            -- MENGHITUNG HARGA
                                            local fruitPrice = 0;
                                            if type(FruitValueCalc) == "function" then
                                                local decayAlpha = fruitModel:GetAttribute("DecayAlpha");
                                                if not decayAlpha and corePart then decayAlpha = corePart:GetAttribute("DecayAlpha") end
                                                if not decayAlpha then decayAlpha = 0 end
                                                
                                                local baseWorth = FruitValueCalc(fruitName, sizeMulti, mutation, LocalPlayer, decayAlpha);
                                                local stockMult = getStockMultiplier(fruitName);
                                                fruitPrice = math.floor(baseWorth * stockMult);
                                            end
                                            
                                            local function formatP(n)
                                                if type(n) ~= "number" then return "0" end
                                                local left, num, right = string.match(tostring(math.floor(n)), '^([^%d]*%d)(%d*)(.-)$')
                                                if not left then return tostring(n) end
                                                return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
                                            end
                                            
                                            if not esp then
                                                esp = Instance.new("BillboardGui");
                                                esp.Name = "FruitESP";
                                                esp.Adornee = corePart;
                                                esp.Size = UDim2.new(0, 200, 0, 50);
                                                esp.StudsOffset = Vector3.new(0, 3.5, 0);
                                                esp.AlwaysOnTop = true;
                                                
                                                local text = Instance.new("TextLabel", esp);
                                                text.Name = "TextESP";
                                                text.Size = UDim2.new(1, 0, 1, 0);
                                                text.BackgroundTransparency = 1;
                                                text.Font = Enum.Font.GothamBold;
                                                text.TextSize = 10;
                                                text.TextScaled = false;
                                                text.TextStrokeTransparency = 0.3;
                                                text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0);
                                                
                                                esp.Parent = PlayerGui;
                                            end
                                            
                                            -- FORMAT TEXT KG
                                            local textBerat = string.format("%.2fkg", realWeight)
                                            
                                            local priceStr = ""
                                            if fruitPrice >= 1000000 then
                                                priceStr = string.format("%.1fm", fruitPrice / 1000000):gsub("%.0m", "m")
                                            elseif fruitPrice >= 1000 then
                                                priceStr = string.format("%.1fk", fruitPrice / 1000):gsub("%.0k", "k")
                                            else
                                                priceStr = tostring(fruitPrice)
                                            end
                                            
                                            local title = string.lower(fruitName)
                                            if mutName ~= "Normal" then
                                                title = title .. " [" .. string.lower(mutName) .. "]"
                                            end
                                            
                                            -- HANYA UPDATE KALAU BERUBAH (ANTI LAG SPAM UI)
                                            local newText = string.format("%s\n%s || %s", title, textBerat, priceStr)
                                            if esp.TextESP.Text ~= newText then
                                                esp.TextESP.Text = newText
                                            end
                                            if esp.TextESP.TextColor3 ~= mutColor then
                                                esp.TextESP.TextColor3 = mutColor
                                            end
                                            
                                            espCache[corePart] = nil;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        for _, gui in pairs(espCache) do
            gui:Destroy();
        end
    end)
    
    if not success then
        warn("ESP LOOP ERROR:", err);
    end
    end
end)
end -- end do block for ESP Scanner
