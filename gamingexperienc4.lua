-- ==========================================
-- PS99 AUTO FARM — Standalone Kaitun Script
-- ==========================================
-- Fitur: Auto Farm, Auto Quest, Auto Rank, Auto World
-- UI in-game, config via local JSON, tanpa panel web

-- Penanda build. Tanpa ini kita tidak pernah tahu versi mana yang benar-benar
-- jalan, dan tiap diagnosis berpijak pada tebakan.
_G.PS99Build = "2026-08-23a | mode Lucky Block Breakout"
print("[PS99] " .. _G.PS99Build)

-- ==========================================
-- SERVICES & REFERENCES
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- Network & Library (PS99 structure)
local Network = ReplicatedStorage:WaitForChild("Network", 30)
local Library = ReplicatedStorage:WaitForChild("Library", 30)
local Client = Library and Library:WaitForChild("Client", 30)

-- Workspace structures
local Things = Workspace:WaitForChild("__THINGS", 30)
local Breakables = Things and Things:WaitForChild("Breakables", 30)
local Lootbags = Things and Things:FindFirstChild("Lootbags")
local Orbs = Things and Things:FindFirstChild("Orbs")

-- ==========================================
-- ANTI-AFK + ANTI-IDLE (7 layer, tanpa rejoin)
-- ==========================================
-- Layer 1: Matikan script idle tracking client
pcall(function()
    LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false
end)

-- Layer 2: Disable connection Idled event
if getconnections then
    pcall(function()
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do
            v:Disable()
        end
    end)
end

-- Layer 3: Fallback Idled handler
LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end)

-- Layer 4: Micro-mouse + key press tiap 30 detik
task.spawn(function()
    while true do
        task.wait(30)
        pcall(function()
            -- Mouse move random
            VirtualInputManager:SendMouseMoveEvent(math.random(1, 5), math.random(1, 5), game)
        end)
        -- W key tap
        pcall(function()
            VirtualInputManager:SendKeyEvent(Enum.UserInputType.Keyboard, "W", true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(Enum.UserInputType.Keyboard, "W", false, game, 0)
        end)
    end
end)

-- Layer 5: Micro-jump + sprint toggle tiap 45 detik
task.spawn(function()
    while true do
        task.wait(45)
        pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Jump = true
                -- Sprint (Shift) tap
                VirtualInputManager:SendKeyEvent(Enum.UserInputType.Keyboard, "LeftShift", true, game, 0)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(Enum.UserInputType.Keyboard, "LeftShift", false, game, 0)
            end
        end)
    end
end)

-- Layer 6: CFrame micro-nudge — geser character 0.01 stud lalu balik
-- Ini yang paling reliable buat server-side: character GERAK beneran
task.spawn(function()
    while true do
        task.wait(20)
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.CFrame.Position
                local offset = Vector3.new(math.random() * 0.02 - 0.01, 0, math.random() * 0.02 - 0.01)
                hrp.CFrame = CFrame.new(pos + offset)
                task.wait(0.1)
                hrp.CFrame = CFrame.new(pos) -- balik ke posisi awal
            end
        end)
    end
end)

-- Layer 7: Walk-to-same-position — paksa humanoid jalan ke posisi sendiri
-- Server lihat "player sedang WalkTo", bukan idle
task.spawn(function()
    while true do
        task.wait(35)
        pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp and humanoid.Health > 0 then
                humanoid.WalkToPoint = hrp.Position + Vector3.new(0.1, 0, 0.1)
                task.wait(0.5)
                -- Berhenti = arahkan ke posisi diri sendiri.
                -- JANGAN Vector3.new(0, 0, 0): itu bukan "batal", melainkan
                -- perintah berjalan ke titik nol dunia. Terukur di Fiesta lobby
                -- karakter kabur 77 stud tiap siklus sampai timeout MoveTo (8
                -- detik) menghentikannya. Di mode Kaitun tertutupi karena loop
                -- farm menarik balik tiap 0,3 detik; di mode Maze tidak ada
                -- yang menarik, jadi terlihat jalan sendiri entah ke mana.
                humanoid.WalkToPoint = hrp.Position
            end
        end)
    end
end)

-- ==========================================
-- PET SPEED OVERRIDE
-- ==========================================
-- Override kecepatan pet biar farming lebih cepat
pcall(function()
    require(Client.PlayerPet).CalculateSpeedMultiplier = function()
        return 200
    end
end)

-- ==========================================
-- CONFIG — load/save via folder MOZEPS99
-- ==========================================
-- Semua berkas script ditaruh di satu folder biar tidak tercecer di root
-- workspace executor. Config dan progres quest dipisah: progres ditulis jauh
-- lebih sering, jadi kalau berkasnya korup config tetap selamat.
local MOZE_DIR = "MOZEPS99"
local CONFIG_FILE = MOZE_DIR .. "/config.json"
local PROGRESS_FILE = MOZE_DIR .. "/zonequest_progress.json"
local CONFIG_FILE_LAMA = "PS99_AutoFarm_Config.json" -- sebelum pindah folder

-- Executor lama tidak selalu punya makefolder — semua akses berkas harus
-- tahan kalau API-nya absen, jangan sampai script mati cuma karena ini.
local function siapkanFolder()
    if not (isfolder and makefolder) then return false end
    local ok = pcall(function()
        if not isfolder(MOZE_DIR) then makefolder(MOZE_DIR) end
    end)
    return ok and isfolder(MOZE_DIR)
end

local folderSiap = siapkanFolder()

local DefaultConfig = {
    -- "kaitun" = farm keliling world seperti biasa.
    -- "maze"   = diam di tempat (Fiesta Maze): tetap menyerang & memungut,
    --            tapi semua yang menggerakkan karakter dimatikan.
    mode = "kaitun",
    autoFarm = true,
    autoLootbag = true,
    -- Isi ulang coin jar begitu yang lama habis. Default MATI: tiap putaran
    -- menghabiskan satu jar dari inventory, jadi harus dinyalakan sadar.
    autoCoinJar = false,
    -- LUCKY BLOCK BREAKOUT (pengganti Fiesta Maze yang sudah berakhir).
    --
    -- Terukur 2026-08-23: instance ber-ID "LuckyBreakout", masuk lewat
    -- InstancingCmds.Enter. Papan 18x24, bola pet disimulasikan SERVER -- jadi
    -- tidak ada gerak karakter sama sekali, dan tidak ada urusan anti-cheat.
    luckyAutoMasuk = true,   -- masuk domain sendiri begitu mode Lucky nyala
    luckyJagaAuto  = true,   -- jaga Auto Rebirth / Auto Buy Slots tetap nyala
    luckyAutoUpgrade = true, -- belanja Breakout Upgrades selama coin cukup

    -- Sisa event Fiesta Maze. Eventnya SUDAH BERAKHIR, jadi semuanya dipaksa
    -- mati; kodenya masih ada dan akan dibuang di pass pembersihan terpisah.
    autoEternalMaze = false,
    autoFiestaBooster = false,    -- default MATI (booster jumlahnya terbatas)
    autoFiestaLuckBoost = false,  -- default MATI (membelanjakan FiestaCoins)
    fiestaCoinSisa = "0",         -- FiestaCoins yang wajib tersisa
    autoPetSlot = false,          -- default MATI (membelanjakan Diamonds)
    petSlotSisaDiamond = "0",     -- Diamonds yang wajib tersisa
    boosterJedaMenit = 10,        -- jeda antar booster; durasinya tidak terbaca
    autoBukaFiestaGift = false,   -- default MATI (aksi satu arah: gift lenyap)
    autoOrb = true,
    autoQuest = true,
    autoRank = true,
    autoWorld = true,
    -- Jangan masuk world berikutnya sebelum rank minimum tercapai.
    -- Ini mencegah bot terseret ke world yang jauh lebih sulit dari progres akun.
    autoWorldRankGate = true,
    worldGateRankW2 = 5,
    worldGateRankW3 = 10,
    autoClaim = true,
    autoHatch = true,
    -- Saat ada quest hatch: hentikan farm, datangi egg, hatch di sana, dan
    -- lanjutkan farm begitu quest-nya kelar.
    autoHatchDatangiEgg = true,
    hatchGolden = true, -- hasil hatch dari best egg dijadikan pet emas
    bypassKlikBukaEgg = true, -- tutup prompt "Click to open!" otomatis
    autoFiestaUpgrade = false, -- beli upgrade maze sesuai prioritas

    -- ---- DAMAGE ----
    -- Isi slot pet yang menganggur dengan pet terkuat yang dimiliki.
    --
    -- Terukur di akun nyata: 35 dari 57 slot terpakai padahal punya 165 pet,
    -- padahal auto-equip bawaan game sudah ON. 22 slot itu damage yang hangus.
    -- Tidak menghabiskan apa pun -- cuma memakai slot yang memang hak user --
    -- jadi ini satu-satunya fitur damage yang aman menyala default.
    --
    -- Damage per pet TIDAK bisa dinaikkan dari client: dihitung server, dan tak
    -- ada satu pun remote yang membawa nilainya. Mengisi slot adalah satu-satunya
    -- cara nyata menaikkan damage.
    autoEquipBest = true,
    autoEquipJeda = 60, -- detik antar pemeriksaan slot

    -- Minum ulang potion begitu sisa waktunya menipis, supaya buff tidak pernah
    -- kosong saat ditinggal AFK.
    --
    -- DEFAULT MATI: tiap minum MENGHABISKAN satu potion dari inventory (terukur:
    -- 51 tersimpan). Menyalakannya harus keputusan sadar, bukan warisan default.
    --
    -- Yang dijaga hanya potion yang benar-benar menaikkan hasil farm. Potion
    -- lain sengaja tidak disentuh supaya stok tidak terbakar untuk buff yang
    -- tidak kamu pedulikan.
    -- Klaim hadiah gratis yang justru sering hangus KARENA bot-nya jalan bagus:
    -- kamu tidak pernah membuka menunya. Terukur saat fitur ini dibuat:
    -- Save.TwentyHourLoginGift = true, alias hadiah login menggantung.
    --
    -- Aman menyala default: semua remote di daftar ini MENGAMBIL, tidak ada yang
    -- membelanjakan atau membuang apa pun.
    autoClaimHarian = true,

    -- ==== CHEST BERWAKTU (Titanic & GARG) ====
    -- Mesin TimedReward cooldown 1 jam. Klaimnya WAJIB berdiri di atas mesin --
    -- tidak ada ProximityPrompt maupun ClickDetector di model-nya.
    --
    -- NYALA secara bawaan, berbeda dari fitur pemindah karakter lainnya:
    -- chest-nya cuma siap sekali per jam, perjalanannya beberapa detik, dan
    -- yang dilewatkan hangus begitu saja. Menunggu diklik manual justru
    -- membuang persis hal yang ingin diotomatiskan.
    autoChestBerwaktu = true,
    chestJeda = 60,
    chestTahanDetik = 4,
    chestKembaliKeAsal = true,

    -- ==== TELEPORT KE EVENT ====
    -- Posisi disimpan sebelum berangkat, dikembalikan saat event habis.
    -- DEFAULT MATI: memindahkan karakter tanpa diminta.
    autoTpEvent = false,
    eventJeda = 20,
    eventPulangKeAsal = true,
    claimHarianJeda = 300, -- detik; hadiah harian tak perlu dicek tiap detik

    autoPotion = false,
    potionDijaga = { "Damage", "Lucky" },
    potionAmbang = 300,  -- minum ulang kalau sisa < 300 detik
    potionJeda = 30,     -- detik antar pemeriksaan
    -- Pindah sel otomatis saat breakable habis. Hanya berlaku di mode Maze,
    -- yang sendirinya sudah harus dipilih user — jadi tidak akan menggerakkan
    -- karakter siapa pun tanpa dua keputusan sadar.
    autoMaze = false,
    autoClaimRewardMaze = false, -- claim peti prize room lewat Raids_CollectReward
    autoKeluarMaze  = false, -- keluar setelah claim, supaya siklus berulang
    autoBuatMaze = false, -- buat & masuk maze sendiri lewat portal kosong
    mazeSolo = false,     -- true = Solo, false = Open (siapa saja boleh gabung)
    -- Boss dikerjakan paling akhir (bersihkan semua room dulu).
    -- DEFAULT MATI: diuji di lapangan, membuka seluruh 19 room tidak sepadan —
    -- boss jauh lebih berharga per waktunya. Nyalakan hanya kalau memang mau
    -- memerah satu run sampai habis.
    mazeBossTerakhir = false,

    -- Tier maze: true = MAX (hadiah besar per run), false = MIN/tier 1
    -- (run pendek, boss cepat pecah — untuk mengejar jumlah putaran / farm orb).
    --
    -- Sengaja dibuat satu saklar tier tersendiri, terpisah dari autoBuatMaze.
    -- Label lama "Auto buat maze (tier max)" menyesatkan: mematikannya membuat
    -- maze tidak dibuat sama sekali, padahal dikira mengubah tier.
    mazeTierMax = false,
    -- Arahkan perpindahan sel ke boss TERDEKAT menurut jumlah langkah di pohon
    -- maze, bukan jarak stud. Sel yang paling dekat secara fisik sering justru
    -- cabang buntu yang menjauhkan dari boss.
    mazeKejarBoss = false,
    -- Pinata Boss sekali tantang = 107.900 FiestaCoins dan bersaing dengan
    -- anggaran upgrade. Default mati supaya tidak menguras diam-diam.
    autoPinataBoss = false,
    -- Mesin gold/rainbow MELEBUR 10 pet jadi 1. Default mati: ini satu arah dan
    -- tidak bisa dibatalkan, jadi harus dinyalakan sadar oleh user.
    questPakaiMesinPet = false,
    autoUltimate = true,
    BlackScreen = true,
    -- Zone quest default MATI: dia mengambil alih teleport dan menyeret
    -- karakter balik ke world 1, jadi jangan pernah nyala tanpa diminta.
    autoZoneQuest = false,
    zoneQuestPakaiItem = true, -- boleh habiskan coin jar / flag / pinata / lucky block
    zoneQuestMulaiWorld = 1,
    zoneQuestDelay = 3,
    targetZone = 0, -- 0 = otomatis (zone berikutnya)
    farmDelay = 0.05, -- brutal: hampir instant, fire semua sekaligus
    questDelay = 2,
    worldCheckDelay = 5,
    claimDelay = 3,
    fpsBoost = false,
}

local Config = {}

local function bacaJSON(path)
    if not (isfile and isfile(path)) then return nil end
    local ok, hasil = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    return ok and type(hasil) == "table" and hasil or nil
end

local function tulisJSON(path, tabel)
    pcall(function()
        if writefile then writefile(path, HttpService:JSONEncode(tabel)) end
    end)
end

local function loadConfig()
    for k, v in pairs(DefaultConfig) do
        Config[k] = v
    end

    -- Berkas di folder baru menang; kalau belum ada, pungut config lama sekali
    -- supaya setelan lama user tidak hilang saat update script.
    local decoded = bacaJSON(CONFIG_FILE) or bacaJSON(CONFIG_FILE_LAMA)
    if not decoded then return end

    for k in pairs(DefaultConfig) do
        -- Harus cek nil eksplisit. Pola `decoded[k] ~= nil and decoded[k] or v`
        -- membuang nilai `false` dan diam-diam mengembalikannya ke default —
        -- artinya toggle yang dimatikan user nyala lagi tiap restart.
        if decoded[k] ~= nil then
            Config[k] = decoded[k]
        end
    end
end

local function saveConfig()
    tulisJSON(CONFIG_FILE, Config)
end

loadConfig()

-- ==========================================
-- FPS BOOST — hapus/declutter semua yang berat
-- ==========================================
-- Toggle agresif: matikan animasi pet, buang particles, sembunyikan
-- dekorasi map, matikan sounds, pangkas render distance.
-- Default MATI. Nyalakan kalau FPS rendah / bot berjalan sendiri.
--
-- KARAKTER TIDAK DISENTUH — hanya environment dan pet.
-- PENGECECUALIAN: tidak menyentuh __REMOTES, __INSTANCE_CONTAINER,
-- Breakables, RandomEvents, atau segala remote — fungsionalitas game
-- tetap utuh.
-- Nama part yang BOLEH tinggal di PARTS_LOD -- itu lantai tempat berpijak.
--
-- Terukur 2026-08-21 di Tech World: dari 16.489 BasePart di seluruh PARTS_LOD
-- (101 zona), yang namanya mengandung "ground" cuma 194. Sisanya dekorasi:
-- part x13.870, cylinder x1.280, wedge x613, pohon, batu, jamur, gunung.
-- Pola lain sengaja TIDAK dipakai karena memang tidak ada satu pun yang cocok:
-- floor=0, baseplate=0, platform=0, path=0, road=0, bridge=0.
local function pijakanLOD(nama)
    return string.find(string.lower(nama), "ground", 1, true) ~= nil
end

-- FPS Boost.
--
-- Dulu SELURUH badan fungsi ini dibungkus SATU pcall, dan baris keempatnya
-- membaca `workspace.CurrentCamera.FarPlane` -- properti yang TIDAK ADA di
-- Camera Roblox ("FarPlane is not a valid member of Camera"). Jadi fungsi ini
-- meledak di langkah pertama dan TIDAK SATU PUN langkah sesudahnya pernah
-- berjalan, tanpa jejak apa pun. Jalur undo-nya juga menyentuh FarPlane, jadi
-- mematikan toggle pun ikut gagal.
--
-- Sekarang tiap langkah punya pcall sendiri dan kegagalannya dicatat, supaya
-- satu langkah rusak tidak membunuh sisanya lagi.
local function applyFpsBoost(on)
    local gagal = {}
    local function langkah(nama, fn)
        local ok, err = pcall(fn)
        if not ok then gagal[#gagal + 1] = nama .. ": " .. tostring(err) end
    end

    local Lighting = game:GetService("Lighting")
    local THINGS = workspace:FindFirstChild("__THINGS")

    if on then
        local saved = {
            GlobalShadows = Lighting.GlobalShadows,
            Technology = Lighting.Technology,
            parts = {},
            models = {},
            lod = {},      -- folder PARTS_LOD yang dicabut
            tanah = {},    -- part ground yang dipindah keluar sebelum pencabutan
        }

        langkah("lighting", function()
            Lighting.GlobalShadows = false
            pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") then v.Enabled = false end
            end
        end)

        -- Pet = Accessory dengan >= 50 descendant; karakter cuma ~30.
        langkah("pet", function()
            for _, player in ipairs(game.Players:GetPlayers()) do
                local char = player.Character
                if char then
                    for _, acc in ipairs(char:GetChildren()) do
                        if acc:IsA("Accessory") and #acc:GetDescendants() >= 50 then
                            for _, obj in ipairs(acc:GetDescendants()) do
                                if obj:IsA("BasePart") then
                                    saved.parts[#saved.parts + 1] = {obj, obj.Transparency}
                                    obj.Transparency = 1
                                    obj.CastShadow = false
                                end
                            end
                        end
                    end
                end
            end
        end)

        langkah("efek", function()
            local kelas = {
                ParticleEmitter = true, Trail = true, Beam = true,
                Smoke = true, Fire = true, Sparkles = true, Explosion = true,
            }
            for _, v in ipairs(workspace:GetDescendants()) do
                if kelas[v.ClassName] then v.Enabled = false end
            end
        end)

        langkah("suara", function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("Sound") then
                    v.Volume = 0
                    pcall(function() v:Stop() end)
                end
            end
        end)

        langkah("dekorasi __THINGS", function()
            if not THINGS then return end
            local buang = {
                "BalloonGifts", "VFX", "Pickaxes", "PaintSplotches",
                "MasteryCapes", "AnimatedCards", "CardPacks",
                "Sprinklers", "Ultimates", "Islands", "Cannons",
                "Booths", "Items", "Hoverboards",
            }
            for _, v in ipairs(THINGS:GetChildren()) do
                for _, h in ipairs(buang) do
                    if v.Name == h then
                        saved.models[#saved.models + 1] = {v, v.Parent}
                        v.Parent = nil
                        break
                    end
                end
            end
            local debris = THINGS:FindFirstChild("__DEBRIS")
                or workspace:FindFirstChild("__DEBRIS")
            if debris then
                saved.models[#saved.models + 1] = {debris, debris.Parent}
                debris.Parent = nil
            end
        end)

        -- === PARTS_LOD: bagian terberat, dan yang paling menghasilkan ===
        --
        -- Tiap zona di Map2 punya INTERACT / PARTS_LOD / PERSISTENT.
        -- PARTS_LOD isinya murni dekorasi jarak jauh. Yang dipakai berpijak
        -- ada di PERSISTENT, dan itu TIDAK disentuh.
        --
        -- Part ground dipindah keluar dulu, lalu SELURUH folder dicabut
        -- sekaligus: mencabut 100 folder jauh lebih murah daripada memproses
        -- 16.489 part satu per satu. Dicabut (Parent = nil), bukan Destroy,
        -- supaya toggle mati bisa mengembalikannya tanpa perlu rejoin.
        langkah("PARTS_LOD", function()
            local Map2 = workspace:FindFirstChild("Map2")
            if not Map2 then return end
            for _, zona in ipairs(Map2:GetChildren()) do
                local L = zona:FindFirstChild("PARTS_LOD")
                if L then
                    for _, c in ipairs(L:GetDescendants()) do
                        if c:IsA("BasePart") and pijakanLOD(c.Name) then
                            saved.tanah[#saved.tanah + 1] = {c, c.Parent}
                            c.Parent = zona
                        end
                    end
                    saved.lod[#saved.lod + 1] = {L, zona}
                    L.Parent = nil
                end
            end
        end)

        langkah("billboard", function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then v.Enabled = false end
            end
        end)

        langkah("decal", function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
            end
        end)

        _G._fpsBoostSaved = saved
        _G.FpsBoostDebug = string.format(
            "ON | %d folder LOD dicabut, %d ground disisakan, %d part disembunyikan%s",
            #saved.lod, #saved.tanah, #saved.parts,
            #gagal > 0 and (" | GAGAL: " .. table.concat(gagal, " ; ")) or "")
    else
        local saved = _G._fpsBoostSaved
        if not saved then
            _G.FpsBoostDebug = "OFF (tidak ada yang perlu dikembalikan)"
            return
        end

        langkah("lighting", function()
            Lighting.GlobalShadows = saved.GlobalShadows ~= nil and saved.GlobalShadows or true
            pcall(function() if saved.Technology then Lighting.Technology = saved.Technology end end)
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") then v.Enabled = true end
            end
        end)

        -- Folder LOD dikembalikan LEBIH DULU, baru ground-nya -- kalau
        -- dibalik, ground dipindahkan ke induk yang belum ada di dunia.
        langkah("PARTS_LOD", function()
            for _, e in ipairs(saved.lod or {}) do
                if e[1] and e[2] then pcall(function() e[1].Parent = e[2] end) end
            end
            for _, e in ipairs(saved.tanah or {}) do
                if e[1] and e[2] then pcall(function() e[1].Parent = e[2] end) end
            end
        end)

        langkah("part", function()
            for _, e in ipairs(saved.parts or {}) do
                if e[1] and e[1].Parent then
                    e[1].Transparency = e[2]
                    e[1].CastShadow = true
                end
            end
        end)

        langkah("model", function()
            for _, e in ipairs(saved.models or {}) do
                if e[1] and e[2] then pcall(function() e[1].Parent = e[2] end) end
            end
        end)

        langkah("efek & gui", function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                    or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    v.Enabled = true
                end
                if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then v.Enabled = true end
                if v:IsA("Sound") then v.Volume = 1 end
                if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 0 end
            end
        end)

        _G._fpsBoostSaved = nil
        _G.FpsBoostDebug = "OFF | dikembalikan"
            .. (#gagal > 0 and (" | GAGAL: " .. table.concat(gagal, " ; ")) or "")
    end

    -- Kegagalan diam adalah persis sebab bug ini tidak ketahuan berbulan-bulan.
    if #gagal > 0 then
        warn("[FPS Boost] " .. table.concat(gagal, " ; "))
    end
end


if Config.fpsBoost then task.spawn(function() applyFpsBoost(true) end) end

-- ==========================================
-- PENJAGA EKSEKUSI GANDA
--
-- Tanpa ini, menjalankan script dua kali meninggalkan DUA panel di layar dan
-- DUA set loop yang menembak remote yang sama -- terlihat langsung sebagai
-- panel bertumpuk, dan tidak terlihat sama sekali sebagai tembakan ganda.
--
-- JUJUR SOAL BATASNYA: panel lama dihapus dan generasi dinaikkan, tapi loop
-- dari eksekusi SEBELUMNYA tidak bisa dibunuh dari sini -- ia hanya berhenti
-- kalau memeriksa generasi. Loop lama yang tidak memeriksanya akan terus jalan
-- sampai rejoin. Karena itu: jangan jalankan ulang tanpa rejoin kecuali perlu.
-- ==========================================
do
    -- Disapu di KEDUA tempat: panel tinggal di PlayerGui, tapi blackscreen dan
    -- tombolnya diparkir di gethui()/CoreGui supaya lolos ResetOnSpawn. Guard
    -- yang cuma melihat PlayerGui meninggalkan layar hitam bertumpuk -- terukur
    -- 4 salinan sekaligus, dan yang teratas menutupi panel yang baru dibuat.
    local induk = { LocalPlayer:WaitForChild("PlayerGui") }
    pcall(function() if gethui then table.insert(induk, gethui()) end end)
    pcall(function() table.insert(induk, game:GetService("CoreGui")) end)

    local buang = { PS99AutoFarm = true, BS_Toggle = true, AFK_BlackScreen = true }
    for _, tempat in ipairs(induk) do
        -- GetChildren, bukan FindFirstChild: yang bertumpuk lebih dari satu.
        for _, anak in ipairs(tempat:GetChildren()) do
            if buang[anak.Name] then pcall(function() anak:Destroy() end) end
        end
    end
end
if getgenv then
    getgenv().MozePS99Gen = (tonumber(getgenv().MozePS99Gen) or 0) + 1
end
local GENERASI = (getgenv and getgenv().MozePS99Gen) or 1
-- Dipanggil loop untuk tahu apakah dirinya sudah usang.
local function generasiIni()
    return (not getgenv) or (getgenv().MozePS99Gen == GENERASI)
end

-- ==========================================
-- UI CREATION
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99AutoFarm"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 450)
MainFrame.Position = UDim2.new(0, 10, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "PS99 AUTO FARM"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -32, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Content area
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -44)
Content.Position = UDim2.new(0, 8, 0, 40)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(100, 116, 139)
Content.BorderSizePixel = 0
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = Content

-- Helper: buat card
local function createCard(name, height, order)
    local card = Instance.new("Frame")
    card.Name = name
    card.Size = UDim2.new(1, 0, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = Content
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(51, 65, 85)
    stroke.Thickness = 1
    stroke.Parent = card
    return card
end

-- Helper: buat toggle
local function createToggle(label, card, yPos, defaultState, onToggle)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 0, 24)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(203, 213, 225)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 52, 0, 24)
    btn.Position = UDim2.new(1, -62, 0, yPos)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
    btn.Text = defaultState and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = card
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local isOn = defaultState
    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        btn.Text = isOn and "ON" or "OFF"
        btn.BackgroundColor3 = isOn and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
        onToggle(isOn)
    end)

    return btn
end

-- Helper: buat status label
local function createStatus(card, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Menunggu..."
    lbl.TextColor3 = Color3.fromRGB(100, 116, 139)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = card
    return lbl
end

-- Helper: baris stat dengan ikon asli dari game (ImageLabel + nama + nilai).
-- Ikon diambil lewat Items.Currency(nama):GetIcon(), bukan asset id yang
-- ditulis tangan — mata uang tiap world beda dan bisa bertambah saat update.
local function createStatRow(card, yPos)
    local ikon = Instance.new("ImageLabel")
    ikon.Size = UDim2.new(0, 18, 0, 18)
    ikon.Position = UDim2.new(0, 10, 0, yPos + 1)
    ikon.BackgroundTransparency = 1
    ikon.ScaleType = Enum.ScaleType.Fit
    ikon.Parent = card

    local nilai = Instance.new("TextLabel")
    nilai.Size = UDim2.new(1, -36, 0, 20)
    nilai.Position = UDim2.new(0, 34, 0, yPos)
    nilai.BackgroundTransparency = 1
    nilai.Text = "-"
    nilai.TextColor3 = Color3.fromRGB(226, 232, 240)
    nilai.Font = Enum.Font.GothamMedium
    nilai.TextSize = 11
    nilai.TextXAlignment = Enum.TextXAlignment.Left
    nilai.Parent = card

    return { ikon = ikon, nilai = nilai }
end

-- ==========================================
-- CARD 0: PILIH MODE (Kaitun / Lucky)
-- ==========================================
-- Mode Lucky dipakai di Lucky Block Breakout (event pengganti Fiesta Maze yang
-- sudah berakhir). Karakter TIDAK boleh digerakkan sama sekali: papan breakout
-- disimulasikan server, bola pet memantul sendiri, jadi tugas kita cuma HADIR
-- di dalam instance dan menjaga auto-nya menyala.
--
-- Semua sumber gerakan dimatikan di satu tempat lewat modeLucky(), bukan dengan
-- mematikan toggle satu per satu -- kalau begitu user kehilangan setelan
-- Kaitun-nya tiap ganti mode.
local ModeCard = createCard("ModeCard", 58, 0)

local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(1, -20, 0, 16)
ModeLabel.Position = UDim2.new(0, 10, 0, 4)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "MODE"
ModeLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
ModeLabel.Font = Enum.Font.GothamBold
ModeLabel.TextSize = 10
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ModeLabel.Parent = ModeCard

local BtnKaitun, BtnLucky

local function catModeButtons()
    local aktifLucky = Config.mode == "lucky"
    BtnKaitun.BackgroundColor3 = aktifLucky and Color3.fromRGB(55, 65, 81) or Color3.fromRGB(16, 185, 129)
    BtnLucky.BackgroundColor3 = aktifLucky and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(55, 65, 81)
end

local function buatTombolMode(teks, xScale, nilai)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -14, 0, 26)
    b.Position = UDim2.new(xScale, xScale == 0 and 10 or 4, 0, 24)
    b.Text = teks
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = ModeCard
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        Config.mode = nilai
        saveConfig()
        catModeButtons()
    end)
    return b
end

BtnKaitun = buatTombolMode("Kaitun", 0, "kaitun")
BtnLucky = buatTombolMode("Lucky", 0.5, "lucky")
catModeButtons()

-- Satu sumber kebenaran untuk "sedang mode lucky".
local function modeLucky()
    return Config.mode == "lucky"
end

-- ==========================================
-- LUCKY BLOCK BREAKOUT: masuk domain & jaga auto
-- ==========================================
-- Terukur langsung di client 2026-08-23 (lihat memory ps99-lucky-block-breakout):
--
--   INSTANCE_ID = PLOT_ID = "LuckyBreakout"
--   masuk       = InstancingCmds.Enter(id, nil, true, pesan)
--   syarat      = DoesMeetRequirement -> true, tanpa pesan syarat
--
-- JEBAKAN yang sudah memakan waktu sekali: memanggil Enter dari identity
-- executor melempar "Cannot require a non-RobloxScript module from a
-- RobloxScript" di GUIFX.Transition -- padahal TELEPORTNYA TETAP JALAN.
-- Jadi errornya dibungkus pcall dan SENGAJA diabaikan; yang dipercaya cuma
-- IsInInstance sesudahnya, bukan nilai balik Enter.
local LuckyIC, LuckyCommon, LuckyCmds
local function luckyModul()
    if LuckyIC == nil then
        pcall(function()
            LuckyIC     = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
            LuckyCommon = require(game.ReplicatedStorage.Library.Util.LuckyBreakoutCommon)
        end)
        pcall(function()
            LuckyCmds = require(game.ReplicatedStorage.Library.Client.LuckyBreakoutCmds)
        end)
    end
    return LuckyIC, LuckyCommon
end

local function luckyDiDalam()
    local IC, C = luckyModul()
    if not (IC and C) then return false end
    local ok, hasil = pcall(IC.IsInInstance, C.INSTANCE_ID)
    return ok and hasil == true
end
_G.PS99LuckyDiDalam = luckyDiDalam

local luckyMasukTerakhir = 0
local function luckyMasuk()
    local IC, C = luckyModul()
    if not (IC and C) then return false, "modul tidak ada" end
    if luckyDiDalam() then return true, "sudah di dalam" end
    -- Jangan menembak beruntun: Enter memicu transisi layar dan server punya
    -- jeda sendiri. IsBusy dipakai kalau tersedia.
    if os.clock() - luckyMasukTerakhir < 8 then return false, "menunggu jeda" end
    local sibuk = false
    pcall(function() sibuk = IC.IsBusy() == true end)
    if sibuk then return false, "instance sibuk" end
    luckyMasukTerakhir = os.clock()
    pcall(function()
        IC.Enter(C.INSTANCE_ID, nil, true, "Masuk Lucky Block Breakout")
    end)
    _G.PS99LuckyMasukCoba = (_G.PS99LuckyMasukCoba or 0) + 1
    return true, "Enter ditembak"
end

-- Status ringkas untuk panel, dibaca dari modul game sendiri.
local function luckyStatus()
    local _, C = luckyModul()
    if not LuckyCmds then return nil end
    local stage, rebirth, buyslots
    pcall(function() stage = LuckyCmds.GetStageInfo() end)
    pcall(function() rebirth = LuckyCmds.GetAutoRebirth() end)
    pcall(function() buyslots = LuckyCmds.GetAutoBuySlots() end)
    return stage, rebirth, buyslots
end
_G.PS99LuckyStatus = luckyStatus

-- Jangkauan serang (pet & tap).
--
-- 70 stud itu angka lama yang jauh di bawah batas game sendiri. Terbaca di
-- BreakableFrontend: `MaxHitDistance = 220`, dan getMaxDistance() memakai
-- `zona.MaxClickDistance or MaxHitDistance` sebelum menolak pukulan. Terbukti
-- di lapangan juga: pinata pada 99 stud tetap menerima damage penuh.
--
-- Di Fiesta Maze ini menentukan: satu sel isinya cuma ~5 breakable dan room
-- berikutnya berjarak 64 stud, jadi radius 70 memutus serangan persis di
-- perbatasan sel — pet berhenti bekerja tepat saat sel berikutnya terbuka.
local JANGKAUAN_NORMAL = 70
local JANGKAUAN_MAZE = 220

-- Jangkauan FOKUS saat mengejar boss: sengaja dipersempit ke satu sel.
--
-- Room maze berjarak TEPAT 64 stud satu sama lain (terukur berulang: 64, 64,
-- 64, ...). Dengan radius 220, breakable dari beberapa sel sekaligus masuk
-- hitungan, sehingga:
--   1. Pet tersebar ke sel-sel lain alih-alih memberesi sel yang ditempati.
--   2. Syarat "sel ini bersih" TIDAK PERNAH terpenuhi, jadi karakter tidak
--      pernah pindah — terlihat seperti diam saja padahal room-nya sudah kosong.
-- Terukur di lapangan: room yang ditempati punya NOL breakable dalam 200 stud
-- dari pusatnya, tapi bot tetap melapor "garap dulu" karena sisa breakable jauh
-- ikut terhitung.
--
-- 45 dipilih supaya menutup isi satu sel tanpa menyentuh pusat sel tetangga
-- yang berjarak 64.
local JANGKAUAN_FOKUS = 45

local function jangkauanSerang()
    if not modeLucky() then return JANGKAUAN_NORMAL end
    -- Saat mengejar boss, fokus satu sel; kalau tidak, jangkauan maze penuh.
    if Config.mazeKejarBoss then return JANGKAUAN_FOKUS end
    return JANGKAUAN_MAZE
end

-- Boss dikerjakan TERAKHIR: habiskan seluruh room dulu.
--
-- Hadiah maze bertambah seiring room yang dibereskan, sementara membunuh boss
-- MENGAKHIRI run. Menyerbu boss saat room baru 5/19 berarti membuang sisa run
-- yang seharusnya masih bisa dipanen.
--
-- Hasilnya di-cache 1 detik: pemanggil terpanas adalah loop retarget pet yang
-- jalan 10x/detik, dan require + GetCurrent tiap tick itu pemborosan.
local bossSiapCache, bossSiapWaktu = false, 0
local function mazeSiapBoss()
    if not Config.mazeBossTerakhir then return true end
    if os.clock() - bossSiapWaktu < 1 then return bossSiapCache end
    bossSiapWaktu = os.clock()

    local ok, siap = pcall(function()
        local CRI = require(Client:WaitForChild("RaidCmds"):WaitForChild("ClientRaidInstance"))
        local raid = CRI.GetCurrent()
        -- Di luar raid jangan menghalangi apa pun (mis. pinata di lobby).
        if type(raid) ~= "table" then return true end
        local sekarang = tonumber(raid._roomNumber) or 0
        local maks = tonumber(raid._maxRoomNumber) or 0
        return maks > 0 and sekarang >= maks
    end)
    bossSiapCache = ok and siap or false
    return bossSiapCache
end

-- ==========================================
-- CARD 1: AUTO FARM
-- ==========================================
-- Tinggi 356 dulu menyisakan LUBANG 96 piksel di y 78-174: itu bekas toggle
-- Fiesta yang dibuang saat eventnya berakhir, tapi tingginya tidak ikut
-- disusutkan. Sekarang 176, pas dengan isinya.
local FarmCard = createCard("FarmCard", 176, 1)

createToggle("Auto Farm", FarmCard, 6, Config.autoFarm, function(state)
    Config.autoFarm = state
    saveConfig()
end)

createToggle("Lootbag + Orb", FarmCard, 30, Config.autoLootbag, function(state)
    Config.autoLootbag = state
    saveConfig()
end)

-- Biayanya ditulis: tiap putaran menghabiskan satu jar dari inventory.
createToggle("Auto Coin Jar (hanya saat ada quest)", FarmCard, 54, Config.autoCoinJar, function(state)
    Config.autoCoinJar = state
    saveConfig()
end)

-- Aksi satu arah: gift lenyap. Batas 8 per panggilan itu aturan server
-- (Lootboxes.MaxOpenAmount), bukan pilihan kita.
-- Memakai jatah harian yang tidak bisa dikembalikan, jadi default mati.
-- Booster jumlahnya terbatas dan tidak bisa dikembalikan, jadi default mati.
-- Membelanjakan FiestaCoins. Pakai 1/3 bertahap, bukan MAX. Default mati.
-- Membelanjakan Diamonds. Default mati.
createToggle("Auto Up Slot Pet (Diamonds)", FarmCard, 78, Config.autoPetSlot, function(state)
    Config.autoPetSlot = state
    saveConfig()
end)

local FarmStatus = createStatus(FarmCard, 102)
local CoinJarStatus = createStatus(FarmCard, 124)
local PetSlotStatus = createStatus(FarmCard, 146)

-- Empat baris ini milik Fiesta Maze yang eventnya SUDAH BERAKHIR: fiturnya
-- dipaksa mati, jadi teksnya selamanya "Menunggu..." dan cuma memenuhi panel.
-- Tetap DIBUAT, bukan dihapus -- variabelnya masih dirujuk di tempat lain, dan
-- membuangnya berarti memburu tiap pemakaian demi baris yang tak terlihat.
local FiestaGiftStatus = createStatus(FarmCard, 0)
local EternalStatus = createStatus(FarmCard, 0)
local BoosterStatus = createStatus(FarmCard, 0)
local LuckBoostStatus = createStatus(FarmCard, 0)
for _, l in ipairs({ FiestaGiftStatus, EternalStatus, BoosterStatus, LuckBoostStatus }) do
    pcall(function() l.Visible = false end)
end

-- ==========================================
-- CARD 2: AUTO QUEST
-- ==========================================
local QuestCard = createCard("QuestCard", 80, 2)

createToggle("Auto Quest", QuestCard, 6, Config.autoQuest, function(state)
    Config.autoQuest = state
    saveConfig()
end)

-- Label diberi angka biayanya supaya tidak ada yang menyalakannya tanpa sadar
-- bahwa 10 pet lenyap tiap kali dipakai.
createToggle("  └ Mesin gold/rainbow (-10 pet)", QuestCard, 30, Config.questPakaiMesinPet, function(state)
    Config.questPakaiMesinPet = state
    saveConfig()
end)

local QuestStatus = createStatus(QuestCard, 54)

-- ==========================================
-- CARD 3: AUTO HATCH
-- ==========================================
local HatchCard = createCard("HatchCard", 104, 3)

createToggle("Auto Hatch", HatchCard, 6, Config.autoHatch, function(state)
    Config.autoHatch = state
    saveConfig()
end)

createToggle("  └ Datangi egg (quest)", HatchCard, 30, Config.autoHatchDatangiEgg, function(state)
    Config.autoHatchDatangiEgg = state
    saveConfig()
end)

createToggle("  └ Golden pet", HatchCard, 54, Config.hatchGolden, function(state)
    Config.hatchGolden = state
    saveConfig()
    -- Matikan sekarang juga; kalau tidak, mode golden yang terlanjur nyala di
    -- server tetap jalan sampai hatch berikutnya di-setup ulang.
    if not state then
        pcall(function()
            local H = require(Client:WaitForChild("HatchingCmds"))
            local Hatching = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Types"):WaitForChild("Hatching"))
            H.Disable(Hatching.Options.GOLDEN)
        end)
    end
end)

local HatchStatus = createStatus(HatchCard, 78)

-- ==========================================
-- CARD 4: LUCKY BLOCK BREAKOUT
-- ==========================================
-- Menggantikan kartu Fiesta/Maze: eventnya sudah berakhir. Nama variabel
-- FiestaCard / MazeStatus / FiestaStatus SENGAJA dipertahankan supaya sisa
-- kode maze yang belum dibuang tidak menunjuk ke nil; pembersihannya menyusul
-- di pass terpisah.
-- 296 dulu menyisakan 174 piksel mati: kartunya dulu memuat toggle Fiesta Maze,
-- dan sesudah event itu berakhir isinya tinggal tiga toggle Lucky Breakout.
local FiestaCard = createCard("FiestaCard", 128, 4)

createToggle("Auto masuk domain Lucky", FiestaCard, 6, Config.luckyAutoMasuk, function(state)
    Config.luckyAutoMasuk = state
    saveConfig()
end)

createToggle("  └ Jaga Auto Rebirth/Buy Slots", FiestaCard, 30, Config.luckyJagaAuto, function(state)
    Config.luckyJagaAuto = state
    saveConfig()
end)

createToggle("  └ Auto Breakout Upgrade", FiestaCard, 54, Config.luckyAutoUpgrade, function(state)
    Config.luckyAutoUpgrade = state
    saveConfig()
end)

local MazeStatus = createStatus(FiestaCard, 78)
local FiestaStatus = createStatus(FiestaCard, 100)

-- Penjaga mode Lucky: pastikan kita berada di dalam instance selama mode nyala.
--
-- Sengaja loop lambat (2 detik). Enter memicu transisi layar dan server punya
-- jeda sendiri; menembaknya cepat-cepat cuma menumpuk transisi.
task.spawn(function()
    while true do
        task.wait(2)
        local ok = pcall(function()
            if not modeLucky() then
                return
            end
            local diDalam = luckyDiDalam()
            if not diDalam then
                if Config.luckyAutoMasuk then
                    local _, sebab = luckyMasuk()
                    FiestaStatus.Text = "Lucky: di luar domain — " .. tostring(sebab)
                else
                    FiestaStatus.Text = "Lucky: di luar domain (auto masuk mati)"
                end
                return
            end
            local stage, rebirth, buyslots = luckyStatus()
            FiestaStatus.Text = string.format("Lucky: stage %s | rebirth %s | slots %s",
                tostring(stage or "?"), tostring(rebirth), tostring(buyslots))
        end)
        if not ok then
            FiestaStatus.Text = "Lucky: status gagal dibaca"
        end
    end
end)

-- ==========================================
-- CARD 4: AUTO ZONE QUEST
-- ==========================================
-- Dua toggle terpisah: yang kedua menahan script supaya tidak menghabiskan
-- coin jar / flag / pinata / lucky block dari inventory tanpa izin.
local ZQCard = createCard("ZQCard", 80, 5)

createToggle("Auto Zone Quest", ZQCard, 6, Config.autoZoneQuest, function(state)
    Config.autoZoneQuest = state
    saveConfig()
end)

createToggle("  └ Boleh pakai item", ZQCard, 30, Config.zoneQuestPakaiItem, function(state)
    Config.zoneQuestPakaiItem = state
    saveConfig()
end)

local ZQStatus = createStatus(ZQCard, 54)

-- ==========================================
-- CARD 5: AUTO WORLD
-- ==========================================
local WorldCard = createCard("WorldCard", 56, 6)

createToggle("Auto World", WorldCard, 6, Config.autoWorld, function(state)
    Config.autoWorld = state
    saveConfig()
end)

local WorldStatus = createStatus(WorldCard, 30)

-- ==========================================
-- CARD 6: AUTO RANK
-- ==========================================
local RankCard = createCard("RankCard", 56, 7)

createToggle("Auto Rank", RankCard, 6, Config.autoRank, function(state)
    Config.autoRank = state
    saveConfig()
end)

local RankStatus = createStatus(RankCard, 30)

-- ==========================================
-- CARD 7: AUTO CLAIM
-- ==========================================
local ClaimCard = createCard("ClaimCard", 128, 8)

createToggle("Auto Claim", ClaimCard, 6, Config.autoClaim, function(state)
    Config.autoClaim = state
    saveConfig()
end)

createToggle("Auto Klaim Harian (gratis)", ClaimCard, 30, Config.autoClaimHarian, function(state)
    Config.autoClaimHarian = state
    saveConfig()
end)

createToggle("Auto Chest Titanic/GARG", ClaimCard, 54, Config.autoChestBerwaktu, function(state)
    Config.autoChestBerwaktu = state
    saveConfig()
end)

createToggle("Auto TP Event (simpan posisi)", ClaimCard, 78, Config.autoTpEvent, function(state)
    Config.autoTpEvent = state
    saveConfig()
end)

local ClaimStatus = createStatus(ClaimCard, 102)

-- ==========================================
-- CARD 8: STATUS GLOBAL
-- ==========================================
-- Baris pertama world, lalu deretan stat berikon: Diamonds, coin world yang
-- sedang dipakai, dan seterusnya. Tinggal tambah baris di bawah kalau mau
-- stat lain.
local StatusCard = createCard("StatusCard", 84, 9)
local StatusLabel = createStatus(StatusCard, 4)
StatusLabel.TextColor3 = Color3.fromRGB(16, 185, 129)

local RowDiamond = createStatRow(StatusCard, 26)
local RowCoin = createStatRow(StatusCard, 50)

-- ==========================================
-- CARD 10: PET / DAMAGE
-- ==========================================
-- Ditaruh di urutan 10 (setelah blackscreen digeser ke 11) supaya kartu damage
-- tidak terselip di bawah tombol tampilan.
local PetCard = createCard("PetCard", 104, 10)

createToggle("Auto Equip Best (isi slot kosong)", PetCard, 6, Config.autoEquipBest, function(state)
    Config.autoEquipBest = state
    saveConfig()
end)

createToggle("Auto Potion (pakai stok!)", PetCard, 30, Config.autoPotion, function(state)
    Config.autoPotion = state
    saveConfig()
end)

local PetStatus = createStatus(PetCard, 54)
local PotionStatus = createStatus(PetCard, 78)

-- ==========================================
-- CARD 11: BLACKSCREEN TOGGLE (selalu visible)
-- ==========================================
local BSCard = createCard("BSCard", 30, 11)

createToggle("BlackScreen", BSCard, 6, Config.BlackScreen, function(state)
    Config.BlackScreen = state
    saveConfig()
    if BS_GuiRef then
        BS_Visible = state
        BS_GuiRef.Enabled = state
        if BS_ToggleBtn then
            BS_ToggleBtn.Text = state and "Hide BS" or "Show BS"
        end
    end
end)

-- ==========================================
-- CARD 12: FPS BOOST
-- ==========================================
local FPSCard = createCard("FPSCard", 30, 12)

createToggle("FPS Boost", FPSCard, 6, Config.fpsBoost, function(state)
    Config.fpsBoost = state
    saveConfig()
    applyFpsBoost(state)
end)

-- Close button handler
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- questBusy: true kalau ada quest coinjar/comet/hatch yang belum selesai
-- Auto world tidak boleh beli area baru saat questBusy
local questBusy = false

-- farmDijeda: true saat auto hatch sedang menyeret karakter ke egg. Farm harus
-- benar-benar berhenti — kalau tidak, loop farm menarik karakter balik ke pusat
-- breakable tiap 0,3 detik dan kita tidak akan pernah sampai ke egg.
local farmDijeda = false

-- Lepaskan hatching yang menggantung.
--
-- HatchingCmds.Enable(AUTO) menyalakan mode auto-hatch MILIK GAME, dan mode itu
-- menahan karakter di egg. Kalau kita memutuskan untuk TIDAK jadi ke egg
-- (di maze, egg tidak ada di dunia ini, dana kurang), melepas rem farm saja
-- tidak cukup: AUTO tetap menyala dan IsHatching menggantung selamanya.
--
-- Terukur 2026-08-20 di Fantasy World: IsHatching=true, AUTO=true, egg target
-- "Hollow Egg" ter-setup 49 butir, TAPI part egg-nya tidak ada di zona tempat
-- karakter berdiri. Selama 12 detik: coin tidak berkurang, PurchaseCount tetap
-- 7578, jumlah pet tetap 224. Diam total dengan saldo 169 kuintiliun -- jadi
-- ini bukan soal uang sama sekali.
-- Menjalankan fn() pada thread identity 2.
--
-- Modul di Library.Balancing menolak di-require dari identity executor
-- ("Cannot require a non-RobloxScript module from a RobloxScript"), dan
-- FFlags ikut di-require di dalam badan fungsinya -- jadi identity harus
-- rendah saat MEMANGGIL, bukan cuma saat require.
local function denganIdentitas2(fn, ...)
    local sti = setthreadidentity or set_thread_identity
        or (syn and syn.set_thread_identity)
    local getid = getthreadidentity or get_thread_identity
    local lama = 8
    if getid then
        local ok, id = pcall(getid)
        if ok and type(id) == "number" then lama = id end
    end
    if sti then pcall(sti, 2) end
    local hasil = table.pack(pcall(fn, ...))
    if sti then pcall(sti, lama) end
    return table.unpack(hasil, 1, hasil.n)
end

-- Harga egg TIDAK ada di Directory.Eggs. Versi lama membacanya dari teks
-- billboard di dunia, dan itu sumber yang rapuh: kalau labelnya belum
-- ter-stream harganya nil, sehingga gerbang dana di loop hatch
-- (`if egg.harga and egg.currency then`) DILEWATI seluruhnya dan karakter
-- diparkir di egg tanpa pernah memeriksa uang -- persis gejala "nyantol di
-- hatch padahal duit kurang".
--
-- Sumber resminya CalcEggPricePlayer(entry), yang minta tabel entry Directory
-- (bukan nomor egg). Terukur 2026-08-21 di World 4:
--     Hollow Egg 9e15, Veilroot 4e15, Wraithcap 2e15 FantasyCoins.
local function hargaEggResmi(entry)
    if type(entry) ~= "table" then return nil end
    local ok, h = denganIdentitas2(function()
        local Calc = require(ReplicatedStorage.Library.Balancing.CalcEggPricePlayer)
        return Calc(entry)
    end)
    if ok and tonumber(h) and tonumber(h) > 0 then return tonumber(h) end
    return nil
end

local function lepaskanHatch()
    pcall(function()
        local HatchingCmds = require(Client:WaitForChild("HatchingCmds"))
        local Hatching = require(ReplicatedStorage:WaitForChild("Library")
            :WaitForChild("Types"):WaitForChild("Hatching"))
        if HatchingCmds.IsEnabled(Hatching.Options.AUTO) then
            HatchingCmds.Disable(Hatching.Options.AUTO)
        end
        if HatchingCmds.IsHatching() then
            HatchingCmds.StopHatching()
        end
    end)

    -- StopHatching TIDAK melepas penambatnya -- dan ini akar sebenarnya dari
    -- semua laporan "nyangkut di hatch, gabisa kemana-mana".
    --
    -- Terukur 2026-08-21 di Tech World: sesudah Disable(AUTO) + StopHatching(),
    -- IsHatching sudah false, TAPI 6 constraint bernama LocalAnchorPosition /
    -- LocalAnchorOrientation masih menempel di HumanoidRootPart. Selama itu
    -- ada, teleport CFrame ditarik balik ke 0,0 stud -- karakter benar-benar
    -- terkunci di tempat. Jumlahnya bertambah SEPASANG tiap hatching dimulai,
    -- jadi mereka menumpuk; terukur 3 pasang sekaligus.
    --
    -- Dimatikan, bukan dihancurkan: yang membuatnya game, dan ia boleh
    -- memakainya lagi nanti. Mematikan sudah cukup -- sesudah itu teleport
    -- langsung berpindah 24,7 stud. Namanya disaring supaya constraint lain
    -- milik karakter tidak ikut tersentuh.
    pcall(function()
        local ch = LocalPlayer.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, c in ipairs(hrp:GetChildren()) do
            if (c:IsA("AlignPosition") or c:IsA("AlignOrientation"))
                and string.sub(c.Name, 1, 11) == "LocalAnchor" then
                pcall(function() c.Enabled = false end)
            end
        end
    end)
end

-- zoneQuestBusy: true selama auto zone quest memegang kendali teleport.
-- Auto world teleport ke zone TERAKHIR yang dimiliki tiap beberapa detik, jadi
-- tanpa kunci ini karakter langsung ditarik keluar dari area world 1 yang
-- sedang dikerjakan dan quest-nya tidak pernah maju.
local zoneQuestBusy = false

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

-- Ambil coin dari CurrencyCmds (PS99 pakai Library.Client.CurrencyCmds)
-- Save.Get() return string, bukan table; CurrencyCmds.Get("Coins") return angka
local function getPlayerCoins()
    local success, coins = pcall(function()
        local currencyCmds = require(ReplicatedStorage:WaitForChild("Library").Client:WaitForChild("CurrencyCmds"))
        return currencyCmds.Get("Coins")
    end)
    if success and type(coins) == "number" then
        return coins
    end
    -- fallback: coba leaderstats (biasanya gada coins di sini)
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            local stat = ls:FindFirstChild("Coins")
            if stat then return stat.Value end
        end
    end)
    return 0
end

-- Walk ke target (bukan teleport — hoverboard tetap jalan)
local function walkTo(targetPos)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    -- tinggikan sedikit biar gak nabrak
    local pos = Vector3.new(targetPos.X, math.max(targetPos.Y, hrp.Position.Y), targetPos.Z)
    humanoid:MoveTo(pos)
    -- tunggu sampai sampai atau timeout 8 detik
    local start = os.clock()
    while (hrp.Position - pos).Magnitude > 5 and os.clock() - start < 8 do
        task.wait(0.2)
    end
end

-- Cari map path (World 1 = Map, World 2 = Map2)
local function getMapPath()
    if Workspace:FindFirstChild("Map") then
        return Workspace.Map
    elseif Workspace:FindFirstChild("Map2") then
        return Workspace.Map2
    end
    return nil
end

-- Cari zone berdasarkan angka
local function findZone(zoneNum)
    local map = getMapPath()
    if not map then return nil end
    for _, child in ipairs(map:GetChildren()) do
        local num = tonumber(string.match(child.Name, "^(%d+)"))
        if num == zoneNum then
            return child
        end
    end
    return nil
end

-- Cari zone berdasarkan substring nama (contoh: "Cherry Blossom" cari "6 | Cherry Blossom")
local function findZoneBySubstring(name)
    local map = getMapPath()
    if not map then return nil end
    for _, child in ipairs(map:GetChildren()) do
        if child.Name:find(name, 1, true) then
            return child
        end
    end
    return nil
end

-- ==========================================
-- QUEST HELPERS
-- ==========================================

-- Save.Get() return table, berisi ZoneQuests, Goals, Rank, RankStars, dll
local function getSaveData()
    local ok, Save = pcall(function()
        return require(Client:WaitForChild("Save"))
    end)
    if ok and Save then
        return Save.Get()
    end
    return nil
end

-- Baca semua quest aktif (zone + rank goals)
local function getAllActiveQuests()
    local quests = {}
    local data = getSaveData()
    if not data then return quests end

    -- 1. Zone Quests: cari di semua zone yang ada quest belum completed
    if data.ZoneQuests then
        for zoneName, zoneData in pairs(data.ZoneQuests) do
            if zoneData.Quests then
                for i, q in ipairs(zoneData.Quests) do
                    if not q.Completed and q.Goal then
                        table.insert(quests, {
                            source = "zone",
                            zone = zoneName,
                            idx = i,
                            type = q.Goal.Type,
                            amount = q.Goal.Amount,
                            progress = q.Goal.Progress or 0,
                            breakableType = q.Goal.BreakableType,
                            breakableDirID = q.Goal.BreakableDirID,
                            eggID = q.Goal.EggID,
                            potionID = q.Goal.PotionID,
                            potionTier = q.Goal.PotionTier,
                            fruitID = q.Goal.FruitID,
                            currencyID = q.Goal.CurrencyID,
                        })
                    end
                end
            end
        end
    end

    -- 2. Rank Goals (Epic Quests): max 4 aktif, keys = "1"-"4"
    if data.Goals then
        for goalId, goal in pairs(data.Goals) do
            if goal.Progress < goal.Amount then
                table.insert(quests, {
                    source = "rank",
                    goalId = goalId,
                    stars = goal.Stars,
                    type = goal.Type,
                    amount = goal.Amount,
                    progress = goal.Progress or 0,
                    breakableType = goal.BreakableType,
                    breakableDirID = goal.BreakableDirID,
                    eggID = goal.EggID,
                    potionID = goal.PotionID,
                    potionTier = goal.PotionTier,
                    fruitID = goal.FruitID,
                    currencyID = goal.CurrencyID,
                })
            end
        end
    end

    return quests
end

-- Cek apakah ada quest yang butuh "stay" (coinjar/comet/hatch/gold/rainbow)
-- Dipakai untuk questBusy flag
local function hasStayQuest(quests)
    local stayTypes = {
        [20] = true,  -- BEST_EGG (hatch)
        [31] = true,  -- BREAK_COIN_JAR (rank goals)
        [37] = true,  -- BEST_COIN_JAR
        [38] = true,  -- BEST_COMET
        [40] = true,  -- BEST_GOLD_PET
        [41] = true,  -- BEST_RAINBOW_PET
    }
    for _, q in ipairs(quests) do
        if stayTypes[q.type] then return true end
    end
    return false
end

-- Cek apakah ada quest coinjar/comet/hatch di zone quests (bukan rank goals)
-- Ini yang bikin auto world skip beli area
local function hasZoneStayQuest(quests)
    local stayTypes = {
        [20] = true,  -- BEST_EGG
        [37] = true,  -- BEST_COIN_JAR
        [38] = true,  -- BEST_COMET
    }
    for _, q in ipairs(quests) do
        if q.source == "zone" and stayTypes[q.type] then return true end
    end
    return false
end

-- Spawn coin jar dari inventory (RemoteFunction)
-- CoinJar_Spawn membutuhkan item UID, bukan nama
-- Urutan pemakaian jar: yang paling murah dulu.
--
-- Versi lama memakai `pairs()` dan menembak jar PERTAMA yang namanya memuat
-- "Coin Jar" — urutan pairs tidak terdefinisi, jadi Giant Coin Jar yang langka
-- bisa terbakar duluan sementara ratusan Basic menganggur.
local URUTAN_JAR = { "Basic Coin Jar", "Magic Coin Jar", "Giant Coin Jar" }

local function cariJar()
    local ok, uid, id = pcall(function()
        local data = require(Client:WaitForChild("Save")).Get()
        local misc = data and data.Inventory and data.Inventory.Misc
        if not misc then return nil end
        for _, mau in ipairs(URUTAN_JAR) do
            for u, it in pairs(misc) do
                if type(it) == "table" and it.id == mau and (tonumber(it._am) or 1) > 0 then
                    return u, it.id
                end
            end
        end
        -- Cadangan: jar jenis lain yang belum terdaftar di URUTAN_JAR.
        for u, it in pairs(misc) do
            if type(it) == "table" and type(it.id) == "string" and it.id:find("Coin Jar", 1, true) then
                return u, it.id
            end
        end
        return nil
    end)
    if not ok then return nil end
    return uid, id
end

-- Berapa event yang sedang aktif di area ini — SEMUA jenis, bukan coin jar saja.
--
-- Server mengizinkan SATU event per area, dan slot itu DIPAKAI BERSAMA lintas
-- jenis. Terukur 2026-08-20 dengan stok berlimpah (Comet 362, Basic Coin Jar 375):
--
--   comet aktif 1 -> Comet_Spawn   ditolak "There is already something in this area!"
--   comet aktif 1 -> CoinJar_Spawn ditolak dengan pesan yang SAMA
--
-- Versi lama cuma menghitung coin jar. Saat sebuah COMET sedang jalan, hitungan
-- itu 0, script mengira slot kosong, menembak, lalu ditolak — persis gejala
-- "kadang tidak spawn padahal stok ada". Stok tidak berkurang saat ditolak,
-- jadi kegagalannya diam total dan tidak meninggalkan jejak.
-- HANYA dua ini yang TERUKUR berbagi slot area (comet aktif -> CoinJar_Spawn
-- ditolak, dan sebaliknya). Item Jar / Lucky Block / Pinata sempat ikut
-- didaftarkan atas dasar dugaan, dan itu KELIRU: begitu salah satunya jalan --
-- yang sering terjadi di permainan normal -- hitungannya > 0 dan coin jar tidak
-- pernah di-spawn lagi. Jangan menambah jenis ke sini tanpa mengukurnya dulu.
-- Dideklarasikan lebih dulu karena eventAktif() di bawah memakainya,
-- sementara badannya baru ditulis setelah itu.
local diAreaTerbaik

local JENIS_EVENT = {
    "Random Events: Request All Coin Jar Data",
    "Random Events: Request All Comet Data",
}

-- Radius "satu area".
--
-- Terukur 2026-08-21 di Tech World: breakable milik zona yang sedang ditempati
-- terbentang 4-427 stud dari karakter, sedangkan jar yang berada di area lain
-- terukur 938 dan 1.463 stud. Celah antara 427 dan 938 lebar, jadi 600
-- memisahkan "di area ini" dari "di area lain" dengan aman.
local RADIUS_AREA = 600

-- Hitung event yang menempati slot AREA INI.
--
-- Versi lama menghitung SEMUA jar/comet di server tanpa peduli letaknya,
-- padahal slot event itu per-area. Akibatnya satu jar yang masih berjalan di
-- area belakang membuat hitungannya > 0, dan comet tidak pernah ditembak --
-- persis keluhan "ada jar di area sebelumnya, ada quest comet, tapi comet
-- gamau spawn". Menyembunyikan area lain TIDAK memperbaiki ini: yang menolak
-- server, bukan render.
--
-- Data event dari server memuat Position, jadi penyaringan ini memungkinkan.
-- Kalau karakter sedang TIDAK di area terbaik, posisinya bukan acuan yang sah
-- untuk menyaring; dalam keadaan itu hitung global saja -- lebih baik menahan
-- diri daripada menembak ke slot yang ternyata sudah terisi.
local function eventAktif()
    local hrp = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local saring = (hrp ~= nil) and diAreaTerbaik()

    local total = 0
    for _, nama in ipairs(JENIS_EVENT) do
        local ok, n = pcall(function()
            local r = Network:FindFirstChild(nama)
            if not r then return 0 end
            local d = r:InvokeServer()
            local c = 0
            if type(d) == "table" then
                for _, e in pairs(d) do
                    if not saring then
                        c = c + 1
                    elseif type(e) == "table" and typeof(e.Position) == "Vector3" then
                        if (e.Position - hrp.Position).Magnitude <= RADIUS_AREA then
                            c = c + 1
                        end
                    else
                        -- Tanpa Position letaknya tidak bisa dipastikan;
                        -- dihitung saja supaya tidak menembak slot terisi.
                        c = c + 1
                    end
                end
            end
            return c
        end)
        if ok then total = total + n end
    end
    return total
end

-- Nama lama dipertahankan supaya pemanggil lain tidak putus.
local jarAktif = eventAktif

-- Event HANYA dihitung kalau dipasang di AREA TERBAIK.
--
-- Quest jar/comet berbunyi "in best area". Sesudah auto-execute karakter
-- mendarat di area AWAL, bukan area terbaik -- kalau jar/comet dipasang di
-- sana, ia menyala tapi progres quest tidak pernah naik, dan slot area
-- terbuang. Karena itu pastikan pindah dulu sebelum spawn.
--
-- Kalau zona terbaik tidak terbaca, JANGAN menghalangi: gerbang yang
-- gagal-tertutup karena data belum siap sudah pernah mengunci fitur lain.
function diAreaTerbaik()
    local ok, sama = pcall(function()
        local ZoneCmds = require(Client:WaitForChild("ZoneCmds"))
        local Map = require(Client:WaitForChild("MapCmds"))
        local terbaik = ZoneCmds.GetMaxOwnedZone()
        if type(terbaik) ~= "string" or terbaik == "" then return true end
        return Map.GetCurrentZone() == terbaik
    end)
    return ok and sama == true
end

local function pastikanDiAreaTerbaik()
    if diAreaTerbaik() then return true end
    pcall(function()
        local ZoneCmds = require(Client:WaitForChild("ZoneCmds"))
        local terbaik = ZoneCmds.GetMaxOwnedZone()
        local tp = Network:FindFirstChild("Teleports_RequestTeleport")
        if tp and type(terbaik) == "string" and terbaik ~= "" then
            tp:InvokeServer(terbaik)
        end
    end)
    task.wait(1.5)
    return diAreaTerbaik()
end

-- Khusus COIN JAR yang sedang berjalan di area ini. Dibedakan dari
-- eventAktif(): untuk memutuskan "jangan pindah area dulu" yang relevan cuma
-- jar, bukan comet.
local function jarSedangJalan()
    local ok, n = pcall(function()
        local r = Network:FindFirstChild("Random Events: Request All Coin Jar Data")
        if not r then return 0 end
        local d = r:InvokeServer()
        local c = 0
        if type(d) == "table" then for _ in pairs(d) do c = c + 1 end end
        return c
    end)
    return ok and n > 0
end

-- Ada quest coin jar yang belum kelar? (31 = COIN_JAR, 37 = BEST_COIN_JAR)
--
-- Dipakai bersama jarSedangJalan() untuk memutuskan "jangan pindah area dulu".
local function adaQuestJar()
    local ok, ada = pcall(function()
        for _, q in ipairs(getAllActiveQuests()) do
            -- HANYA rank goal. Terukur 2026-08-21: ada 16 zone quest tipe 31
            -- yang menganggur di 0/5 terus-menerus, dan script ini memang tidak
            -- pernah mengerjakannya (zone quest cuma ditampilkan). Kalau ikut
            -- dihitung, gerbang ini praktis selalu menyala dan jar pemain lain
            -- akan menunda progres dunia berulang kali tanpa guna.
            if q.source == "rank" and (q.type == 31 or q.type == 37)
                and q.progress < q.amount then
                return true
            end
        end
        return false
    end)
    return ok and ada
end

-- Batas penahanan auto world gara-gara jar. Data jar dari server (terukur
-- 2026-08-21) cuma {Collected, Position, Required} -- TIDAK ada penanda
-- pemilik, jadi jar pemain lain ikut terhitung. Tanpa batas waktu, satu jar
-- terlantar milik orang lain bisa mengunci progres dunia selamanya.
local TAHAN_JAR_MAKS = 240
local tahanJarSejak = 0


local function spawnCoinJar()
    local remote = Network:FindFirstChild("CoinJar_Spawn")
    if not remote then return false, "remote hilang" end
    local uid, id = cariJar()
    if not uid then return false, "stok coin jar habis" end
    local ok, hasil, pesan = pcall(function() return remote:InvokeServer(uid) end)
    return (ok and hasil == true), (pesan or id)
end

-- Spawn comet dari inventory (RemoteFunction)
-- Comet_Spawn membutuhkan item UID, bukan nama
local function spawnComet()
    local ok, result = pcall(function()
        local remote = Network:FindFirstChild("Comet_Spawn")
        if not remote then return false end

        -- Cari UID comet di inventory
        local Save = require(Client:WaitForChild("Save"))
        local data = Save.Get()
        if not data or not data.Inventory or not data.Inventory.Misc then return false end

        for uid, itemData in pairs(data.Inventory.Misc) do
            if type(itemData) == "table" and itemData.id
                and itemData.id == "Comet" then
                return remote:InvokeServer(uid)
            end
        end
        return false
    end)
    return ok and result
end

-- Hatch best egg pakai HatchingCmds (auto-hatch loop game)
-- SetupEgg → Enable(AUTO) → game handle purchase + open animation
-- Tidak pakai Eggs_RequestPurchase langsung — itu cuma 1x purchase, gak buka
-- Cache Directory di level atas biar gak require berulang (timeout risk)
local Directory = nil
pcall(function()
    Directory = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Directory"))
end)
local lastHatchTime = 0
local lastHatchFailedTime = 0 -- cooldown setelah CanAfford gagal
-- Harga egg TIDAK ada di Directory -- ia dibaca dari teks billboard di dunia
-- oleh infoEggTerbaik(). Nilainya dititipkan ke sini supaya hatchBestEgg(),
-- yang didefinisikan lebih dulu, bisa ikut memakainya tanpa masalah urutan.
local hargaEggTerakhir, currencyEggTerakhir

local function hatchBestEgg()
    if os.clock() - lastHatchTime < 5 then return false end
    -- Cooldown 30 dtk setelah CanAfford gagal supaya farm jalan dulu kumpul coin
    if lastHatchFailedTime > 0 and os.clock() - lastHatchFailedTime < 30 then
        _G.HatchDebug = "Hatch: cooldown " .. math.floor(30 - (os.clock() - lastHatchFailedTime)) .. "dtk"
        return false
    end
    lastHatchTime = os.clock()

    local ok, result = pcall(function()
        local EggCmds = require(Client:WaitForChild("EggCmds"))
        local HatchingCmds = require(Client:WaitForChild("HatchingCmds"))
        local Hatching = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Types"):WaitForChild("Hatching"))

        -- Cari best egg dari Directory (cached)
        if not Directory then return false end
        local eggs = Directory.Eggs
        if not eggs then return false end

        local highest = EggCmds.GetHighestEggNumberAvailable()
        local bestEntry = nil
        for name, data in pairs(eggs) do
            if type(data) == "table" and data.eggNumber == highest then
                bestEntry = data
                break
            end
        end
        if not bestEntry then return false end

        -- CEK CANAFFORD DULU sebelum IsHatching.
        --
        -- Bug lama: `if IsHatching() then return true end` mendahului cek duit.
        -- Kalau hatch aktif tapi saldo habis (setelah beli batch sebelumnya),
        -- script mengira "hatch OK" padahal karakter stuck di egg tanpa coin.
        -- Return true → farm dianggap "jeda" → tidak pernah farm → coin tidak
        -- pernah bertambah → hatch mandek selamanya.
        local mampu = true
        if hargaEggTerakhir and currencyEggTerakhir then
            mampu = select(2, pcall(function()
                local CurrencyCmds = require(Client:WaitForChild("CurrencyCmds"))
                return CurrencyCmds.CanAfford(currencyEggTerakhir, hargaEggTerakhir)
            end)) == true
        end
        if mampu ~= true then
            -- Duit kurang: STOP hatch yang sudah aktif + cooldown supaya
            -- tidak spam coba tiap 5 detik (boros + log ramai).
            pcall(function()
                local Hatching2 = require(ReplicatedStorage:WaitForChild("Library")
                    :WaitForChild("Types"):WaitForChild("Hatching"))
                if HatchingCmds.IsEnabled(Hatching2.Options.AUTO) then
                    HatchingCmds.Disable(Hatching2.Options.AUTO)
                end
                if HatchingCmds.IsHatching() then
                    HatchingCmds.StopHatching()
                end
            end)
            _G.HatchDebug = "Hatch: nunggu duit untuk " .. tostring(bestEntry.name or "?")
            lastHatchFailedTime = os.clock() -- cooldown 30 dtk
            return false
        end

        -- Setup auto-hatch pakai HatchingCmds
        local maxHatch = EggCmds.GetMaxHatch()
        if maxHatch > 0 then
            HatchingCmds.SetupEgg(bestEntry, maxHatch)
            HatchingCmds.Enable(Hatching.Options.AUTO)

            -- Golden: hasil hatch jadi pet emas. Syaratnya 6 rebirth
            -- (HatchingCmds.Requirement[GOLDEN] = 6); server menolak dengan
            -- return false kalau belum cukup, jadi aman dipanggil apa adanya.
            if Config.hatchGolden then
                HatchingCmds.Enable(Hatching.Options.GOLDEN)
            end
            task.spawn(function()
                task.wait(1)
                pcall(function() HatchingCmds.AttemptHatch() end)
            end)
            return true
        end
        return false
    end)
    return ok and result
end

-- Cek apakah ada comet/coinjar aktif di area
local function findRandomEvent(eventType)
    local re = Things:FindFirstChild("RandomEvents")
    if not re then return false end
    for _, child in ipairs(re:GetChildren()) do
        if child.Name:find(eventType) then
            return true
        end
    end
    return false
end

-- Use potion (RemoteEvent)
-- Minum potion, TIER APA PUN yang tersedia.
--
-- Versi lama menembak `tier or 1` — selalu tier 1. Terukur 2026-08-20, stok
-- tier 1 justru yang paling tipis:
--     Lucky  T1=192 T2=957 T3=3020 T4=4352 T5=5515 T6=3867 T7=530 ...
--     Damage T1=234 T2=967 T3=2895 T4=3523 T5=3518 T6=2257 T7=305 ...
-- Jadi begitu T1 habis, fitur berhenti bekerja padahal ada belasan ribu potion
-- tier lain menganggur.
--
-- Tier terendah dipakai lebih dulu supaya tier tinggi yang langka tidak
-- terbakar duluan — prinsip yang sama dengan URUTAN_JAR.
--
-- Minum potion untuk quest USE_POTION (type 34).
--
-- Tanda tangannya BUKAN (nama, tier). Terukur 2026-08-21 dari menu aksi game
-- sendiri (Library.Client.UI.ActionMenu.Potion):
--
--     PotionCmds.Consume(item:GetUID(), jumlah)
--
-- yang diteruskan sebagai Network.Fire("Potions: Consume", uid, jumlah).
-- Versi lama mengirim NAMA potion ke slot yang diharapkan berisi UID, jadi
-- server menolaknya. Dan karena Consume itu Fire satu arah -- tanpa nilai
-- balik, tanpa error -- pcall tetap mengembalikan true, sehingga script
-- melapor "berhasil" sementara progress dan stok tidak bergerak sama sekali.
-- Terbukti: (nama, tier), (player, nama, tier), dan (nama) ketiganya
-- menghasilkan delta 0; (uid, 1) menaikkan progress 0->1 dan stok 13333->13332.
--
-- UID-nya adalah KUNCI tabel di Save.Get().Inventory.Potion.
local function usePotion(potionID, tier)
    local ok, hasil, ket = pcall(function()
        local PC = require(Client:WaitForChild("PotionCmds"))
        local MC = require(Client:WaitForChild("MasteryCmds"))
        local Save = require(Client:WaitForChild("Save"))
        local d = Save.Get()
        local inv = d and d.Inventory and d.Inventory.Potion
        if not inv then return false, "inventory potion tidak terbaca" end

        local tierWajib = tonumber(tier)

        -- Gerbang milik game: tier tinggi butuh Potions Mastery. Terukur
        -- T1-T8 boleh, T9 ditolak dengan "You need Potions Mastery: Level 50
        -- to drink this!". Tanpa cek ini, quest tier terkunci membuat script
        -- menembak terus tanpa hasil dan tanpa keterangan.
        if tierWajib then
            local okM, bisa, pesan = pcall(MC.CanUsePotion, tierWajib)
            if okM and bisa == false then
                return false, "tier " .. tierWajib .. " terkunci: " .. tostring(pesan)
            end
        end

        -- Pilih stok TERBANYAK: quest hanya menyebut tier ("Use 8 Tier IV
        -- Potions") dan tidak peduli jenisnya, jadi menghabiskan yang paling
        -- melimpah itu yang termurah dan menyisakan yang langka.
        local pilih
        for uid, it in pairs(inv) do
            if type(uid) == "string" and type(it) == "table" and type(it.id) == "string" then
                local jml = tonumber(it._am) or 0
                local t = tonumber(it.tn)
                if jml > 0 and t
                    and (not potionID or it.id == potionID)
                    and (not tierWajib or t == tierWajib) then
                    if not pilih or jml > pilih.jml then
                        pilih = { uid = uid, nama = it.id, tier = t, jml = jml }
                    end
                end
            end
        end

        if not pilih then
            return false, tierWajib and ("tidak ada potion tier " .. tierWajib)
                or "stok potion habis"
        end

        local sebelum = pilih.jml
        PC.Consume(pilih.uid, 1)

        -- Satu-satunya bukti yang sah adalah stoknya berkurang. Penolakan
        -- server di sini tidak menimbulkan error apa pun, jadi "pcall tidak
        -- meledak" TIDAK berarti potion-nya terminum.
        local turun = false
        for _ = 1, 20 do
            task.wait(0.1)
            local d2 = Save.Get()
            local inv2 = d2 and d2.Inventory and d2.Inventory.Potion
            local it2 = inv2 and inv2[pilih.uid]
            -- Entri hilang = stok habis terpakai, itu juga tanda berhasil.
            local kini = it2 and (tonumber(it2._am) or 0) or 0
            if kini < sebelum then turun = true break end
        end
        if not turun then
            return false, "ditolak (" .. pilih.nama .. " T" .. tostring(pilih.tier) .. ")"
        end

        return true, pilih.nama .. " T" .. tostring(pilih.tier)
    end)
    if not ok then return false, "error" end
    return hasil, ket
end

-- Makan fruit. Sama seperti potion: versi lama butuh `fruitID` dan quest
-- USE_FRUIT memanggilnya tanpa argumen, jadi tidak pernah menembak.
--
-- Buah ada di Inventory.Fruit (BUKAN Misc). Terukur 2026-08-20:
--     Rainbow 1053 · Banana 1952 · Apple 1803 · Orange 1702 ·
--     Pineapple 1700 · Watermelon 1530
--
-- FruitCmds.GetMaxConsume() adalah gerbang milik game — antrean fruit ada
-- batasnya, dan menembak saat penuh hanya menghasilkan penolakan diam.
local URUTAN_FRUIT = {
    "Rainbow", "Watermelon", "Pineapple", "Orange", "Apple", "Banana",
}

local function useFruit(fruitID)
    local ok, hasil, ket = pcall(function()
        local FC = require(Client:WaitForChild("FruitCmds"))
        local Save = require(Client:WaitForChild("Save"))
        local inv = Save.Get()
        inv = inv and inv.Inventory and inv.Inventory.Fruit
        if not inv then return false, "inventory fruit tidak terbaca" end

        local urutan = URUTAN_FRUIT
        if type(fruitID) == "string" then urutan = { fruitID } end

        for _, nama in ipairs(urutan) do
            local okMax, maks = pcall(function() return FC.GetMaxConsume(nama) end)
            if okMax and tonumber(maks) and tonumber(maks) <= 0 then
                -- antrean penuh untuk jenis ini
            else
                for uid, it in pairs(inv) do
                    if type(it) == "table" and it.id == nama
                        and (tonumber(it._am) or 1) > 0 then
                        local okC = pcall(function() FC.Consume(nama, uid, 1) end)
                        if not okC then
                            okC = pcall(function() FC.Consume(nama) end)
                        end
                        if okC then return true, nama end
                        break
                    end
                end
            end
        end
        return false, "tidak ada fruit yang bisa dimakan"
    end)
    if not ok then return false, "error" end
    return hasil, ket
end

-- Pasang flag.
--
-- Game sudah PINDAH sistem, dan remote lama sudah kosong. Terukur 2026-08-20:
--     Flags: Request        -> tabel KOSONG (n=0)
--     FlexibleFlags_Request -> ADA isinya (Magnet Flag aktif, AreaId=Main,
--                              ParentId=Hollow Veil Castle, EndTime=...)
--
-- Versi lama menembak "Flags: Consume" dan, karena `flagID` selalu dipanggil
-- nil dari quest USE_FLAG, ia bahkan tidak sampai menembak — langsung
-- `return false` tanpa pesan. Dua lapis gagal-diam sekaligus.
--
-- Bentuk yang benar, dijiplak dari ActionMenu game sendiri
-- (Library.Client.UI.ActionMenu.Misc.Flags.*):
--     FlexibleFlagCmds.Consume(namaFlag, item:GetUID(), jumlah)
--     FlexibleFlagCmds.GetMaxPlaceAutomaticContext(namaFlag)  -- gerbang
local URUTAN_FLAG = {
    "Magnet Flag", "Coins Flag", "Diamonds Flag", "Hasty Flag",
    "Strength Flag", "Shiny Flag", "Fortune Flag", "Rainbow Flag",
}

local function useFlag(flagID)
    local ok, hasil, ket = pcall(function()
        local FFC = require(Client:WaitForChild("FlexibleFlagCmds"))
        local Save = require(Client:WaitForChild("Save"))
        local misc = Save.Get()
        misc = misc and misc.Inventory and misc.Inventory.Misc
        if not misc then return false, "inventory tidak terbaca" end

        -- flagID boleh diisi untuk memaksa jenis tertentu; kalau nil, pakai
        -- urutan di atas supaya yang langka tidak terbakar duluan.
        local urutan = URUTAN_FLAG
        if type(flagID) == "string" then urutan = { flagID } end

        for _, nama in ipairs(urutan) do
            -- Gerbang milik game: 0 berarti slot flag jenis ini sudah penuh.
            local okMax, maks = pcall(function()
                return FFC.GetMaxPlaceAutomaticContext(nama)
            end)
            if okMax and tonumber(maks) and tonumber(maks) <= 0 then
                -- penuh, coba jenis berikutnya
            else
                for uid, it in pairs(misc) do
                    if type(it) == "table" and it.id == nama
                        and (tonumber(it._am) or 1) > 0 then
                        local okC, res = pcall(function()
                            return FFC.Consume(nama, uid, 1)
                        end)
                        if okC and res ~= false then return true, nama end
                        break -- uid jenis ini gagal; lanjut ke jenis lain
                    end
                end
            end
        end
        return false, "tidak ada flag yang bisa dipasang"
    end)
    if not ok then return false, "error" end
    return hasil, ket
end

-- MESIN GOLD / RAINBOW — AKSI SATU ARAH: 10 PET LENYAP MENJADI 1
--
-- Signature benar, dibaca dari PlayerScripts.Scripts.Game.Machines.*:
--   Network.Invoke("GoldMachine_Activate",    pet:GetUID(), jumlahHasil)
--   Network.Invoke("RainbowMachine_Activate", pet:GetUID(), jumlahHasil)
-- Biaya 10 pet identik per 1 hasil, dikurangi perk mastery Gold/RainbowReduction.
--
-- Versi lama memanggil TANPA argumen dan selalu ditolak server
-- ("Machines Manager.Gold Machine:59: assertion failed!"), jadi quest type 40
-- dan 41 tidak pernah tergarap. Jarak ke mesin TIDAK berpengaruh — terbukti
-- berhasil dari area farming, 3000 stud dari mesinnya.
--
-- UI game mengirim math.floor(jumlah / biaya): sekali klik bisa melahap seluruh
-- tumpukan (482 pet -> 48 gold sekaligus). Di sini dikunci 1 hasil per
-- panggilan supaya quest yang cuma butuh satu pet tidak menguras koleksi.
local MESIN_MIN_TUMPUKAN = 20 -- jangan sentuh tumpukan tipis

local function biayaMesin(namaPerk)
    local ok, red = pcall(function()
        local M = require(Client:WaitForChild("MasteryCmds"))
        if M.HasPerk("Pets", namaPerk) then return M.GetPerkPower("Pets", namaPerk) end
        return 0
    end)
    return math.max(1, 10 - ((ok and tonumber(red)) or 0))
end

-- Tumpukan pet terbanyak yang aman dikorbankan.
local function petUntukMesin(biaya)
    local ok, uid, id = pcall(function()
        local data = require(Client:WaitForChild("Save")).Get()
        local pets = data and data.Inventory and data.Inventory.Pet
        if not pets then return nil end
        local bUid, bId, bJml = nil, nil, 0
        local minimal = math.max(biaya, MESIN_MIN_TUMPUKAN)
        for u, it in pairs(pets) do
            -- Lewati yang sudah bertanda (pt=gold, r=rainbow, sh=shiny) supaya
            -- hasil olahan tidak ikut dilebur lagi.
            if type(it) == "table" and it.id and not it.pt and not it.r and not it.sh then
                local j = tonumber(it._am) or 1
                if j >= minimal and j > bJml then bUid, bId, bJml = u, it.id, j end
            end
        end
        return bUid, bId
    end)
    if not ok then return nil end
    return uid, id
end

local function jalankanMesinPet(remoteNama, namaPerk)
    if not Config.questPakaiMesinPet then return false, "mesin pet dimatikan" end
    local remote = Network:FindFirstChild(remoteNama)
    if not remote then return false, "remote hilang" end

    local biaya = biayaMesin(namaPerk)
    local uid, id = petUntukMesin(biaya)
    if not uid then
        return false, string.format("tak ada tumpukan >= %d", math.max(biaya, MESIN_MIN_TUMPUKAN))
    end

    local ok, berhasil = pcall(function() return remote:InvokeServer(uid, 1) end)
    return (ok and berhasil == true), string.format("%s -%d", tostring(id), biaya)
end

local function activateGoldMachine()
    return jalankanMesinPet("GoldMachine_Activate", "GoldReduction")
end

local function activateRainbowMachine()
    return jalankanMesinPet("RainbowMachine_Activate", "RainbowReduction")
end

-- Claim rank reward (RemoteEvent, pakai nomor rank)
-- Klaim rank reward.
--
-- Yang dikirim ke Ranks_ClaimReward adalah INDEX reward di dalam daftar rank
-- yang sedang berjalan — BUKAN nomor rank. Dibaca dari GUI game sendiri
-- (PlayerScripts.Scripts.GUIs.Ranks baris 602: `Network.Fire("Ranks_ClaimReward", i)`)
-- dengan syarat kelayakan di baris 413:
--     akumulasi StarsRequired <= RankStars  DAN  RedeemedRankRewards[tostring(i)] == nil
--
-- Dicocokkan dengan data asli: rank 8 = "Expert" punya 30 reward, 25 sudah
-- diklaim, dan reward ke-26 terbuka pada akumulasi 131 bintang. Itu sebabnya
-- kunci RedeemedRankRewards bisa mencapai 25 padahal rank baru 8 — versi lama
-- mengira kunci itu nomor rank dan mengirim angka yang salah.
local function claimRankReward()
    local ok, jumlah = pcall(function()
        local Save = require(Client:WaitForChild("Save"))
        local Dir = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Directory"))
        local RanksUtil = require(ReplicatedStorage.Library.Util.RanksUtil)

        local data = Save.Get()
        if not data or not data.Rank then return 0 end

        local rankID = RanksUtil.RankIDFromNumber(data.Rank)
        local daftar = rankID and Dir.Ranks[rankID] and Dir.Ranks[rankID].Rewards
        if not daftar then return 0 end

        local remote = Network:FindFirstChild("Ranks_ClaimReward")
        if not remote then return 0 end

        local redeemed = data.RedeemedRankRewards or {}
        local bintang = tonumber(data.RankStars) or 0
        local akum, n = 0, 0

        for i, v in ipairs(daftar) do
            akum = akum + (tonumber(v.StarsRequired) or 0)
            -- StarsRequired bersifat akumulatif menaik, jadi begitu melewati
            -- jumlah bintang, sisanya pasti belum terbuka.
            if akum > bintang then break end
            if redeemed[tostring(i)] == nil then
                remote:FireServer(i)
                n = n + 1
                task.wait(0.3) -- beri jeda agar save tersinkron sebelum index berikutnya
            end
        end
        return n
    end)
    return (ok and tonumber(jumlah)) or 0
end

-- Naik rank (RemoteEvent)
local function rankUp()
    local remote = Network:FindFirstChild("Ranks_RankUp")
    if remote then
        pcall(function() remote:FireServer() end)
        return true
    end
    return false
end

-- Format quest description untuk status UI
local function questDescription(quest)
    local remaining = quest.amount - quest.progress

    if quest.type == 9 then -- BREAK (zone quest)
        return string.format("Break %d breakables", remaining)
    elseif quest.type == 21 then -- CURRENT_BREAKABLE
        return string.format("Break %d breakables", remaining)
    elseif quest.type == 20 then -- BEST_EGG
        return string.format("Hatch %d best eggs", remaining)
    elseif quest.type == 38 then -- BEST_COMET
        return string.format("Break %d comets", remaining)
    elseif quest.type == 37 then -- BEST_COIN_JAR
        return string.format("Break %d coin jars", remaining)
    elseif quest.type == 31 then -- BREAK_COIN_JAR (rank goals)
        return string.format("Break %d coin jars", remaining)
    elseif quest.type == 39 then -- BEST_MINI_CHEST
        return string.format("Break %d mini-chests", remaining)
    elseif quest.type == 33 then -- USE_FLAG
        return string.format("Use %d flags", remaining)
    elseif quest.type == 34 then -- USE_POTION
        return string.format("Use %d potions", remaining)
    elseif quest.type == 35 then -- USE_FRUIT
        return string.format("Use %d fruits", remaining)
    elseif quest.type == 40 then -- BEST_GOLD_PET
        return string.format("Make %d golden pets", remaining)
    elseif quest.type == 41 then -- BEST_RAINBOW_PET
        return string.format("Make %d rainbow pets", remaining)
    elseif quest.type == 63 then -- GET_CRITICAL
        return string.format("Get %d critical hits", remaining)
    elseif quest.type == 64 then -- CURRENCY
        return string.format("Earn %d coins", remaining)
    elseif quest.type == 14 then -- COLLECT_ENCHANT
        return string.format("Collect %d enchants", remaining)
    elseif quest.type == 15 then -- COLLECT_POTION
        return string.format("Collect %d potions", remaining)
    elseif quest.type == 7 or quest.type == 8 then -- CURRENCY/OBTAIN
        return string.format("Earn %d diamonds", remaining)
    else
        return string.format("Type %d: %d/%d", quest.type, quest.progress, quest.amount)
    end
end

-- ==========================================
-- AUTO ZONE QUEST — data & helper
-- ==========================================
-- Alur: mulai world 1 area pertama, garap quest zone sampai habis, teleport ke
-- area berikutnya, dan seterusnya sampai world terakhir. Progres disimpan di
-- MOZEPS99/zonequest_progress.json supaya restart tidak mengulang dari nol.

-- Satu zone baru dianggap beres setelah lolos pengecekan sebanyak ini.
-- Save client belum tentu tersinkron tepat setelah teleport, jadi sekali
-- "kelihatan kosong" tidak cukup — itu cara paling gampang melewati area yang
-- sebenarnya masih punya quest.
local ZQ_VERIFIKASI_MIN = 2

local ZQ_Progress = { zona = {}, world = {} }

local function muatProgress()
    local d = bacaJSON(PROGRESS_FILE)
    if type(d) ~= "table" then return end
    if type(d.zona) == "table" then ZQ_Progress.zona = d.zona end
    if type(d.world) == "table" then ZQ_Progress.world = d.world end
end
muatProgress()

local function simpanProgress()
    tulisJSON(PROGRESS_FILE, ZQ_Progress)
end

-- Tulis hanya kalau nilainya berubah. Loop ini jalan tiap beberapa detik dan
-- menulis berkas tiap siklus bikin I/O executor tersendat.
local function setZonaLolos(nama, nilai)
    if ZQ_Progress.zona[nama] == nilai then return end
    ZQ_Progress.zona[nama] = nilai
    simpanProgress()
end

-- Directory.Zones itu dict tanpa urutan; kelompokkan per WorldNumber lalu urut
-- ZoneNumber supaya "area 1 sampai area terakhir" benar-benar berurutan.
local ZQ_DaftarWorld = nil
local function daftarWorld()
    if ZQ_DaftarWorld then return ZQ_DaftarWorld end
    local hasil = {}
    pcall(function()
        local Directory = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Directory"))
        for nama, z in pairs(Directory.Zones) do
            if type(z) == "table" and z.WorldNumber and z.ZoneNumber then
                hasil[z.WorldNumber] = hasil[z.WorldNumber] or {}
                table.insert(hasil[z.WorldNumber], { nama = nama, nomor = z.ZoneNumber })
            end
        end
        for _, daftar in pairs(hasil) do
            table.sort(daftar, function(a, b) return a.nomor < b.nomor end)
        end
    end)
    ZQ_DaftarWorld = hasil
    return hasil
end

-- Tipe quest zone yang menuntut pemakaian item. Tipe lain (1 break, 9 diamond,
-- 63 critical, 64 lootbag) beres sendiri lewat auto farm — cukup berdiri di
-- area yang benar. Peta ini hasil pembacaan seluruh 279 zone di Save.
local ZQ_ITEM = {
    [31] = { cocok = "Coin Jar",         remote = "CoinJar_Spawn" },          -- Break N coin jars
    [66] = { cocok = "Mini Pinata",      remote = "MiniPinata_Consume" },     -- Break N pinata
    [67] = { cocok = "Mini Lucky Block", remote = "MiniLuckyBlock_Consume" }, -- Break N lucky block
    -- Flag dicocokkan lewat akhiran, bukan "mengandung Flag". Inventory juga
    -- punya "Flag Bundle" — itu peti berisi flag, bukan flag yang bisa dipasang,
    -- dan urutan pairs() bisa saja menyodorkannya duluan.
    [33] = { sufiks = " Flag",           flag = true },                       -- Use N flags
}

-- Server menolak pemakaian item di dalam instance dan di luar kotak
-- putus-putus area farming. Cek dulu, kalau tidak item terbakar percuma.
local function bolehPakaiItem()
    local ok, hasil = pcall(function()
        local MapCmds = require(Client:WaitForChild("MapCmds"))
        local InstancingCmds = require(Client:WaitForChild("InstancingCmds"))
        if InstancingCmds.IsInInstance() then return false end
        if not MapCmds.GetCurrentZone() then return false end
        return MapCmds.IsInDottedBox() == true
    end)
    return ok and hasil == true
end

-- Cari item di Inventory.Misc. `cocok` dicari sebagai substring, `sufiks`
-- harus pas di ujung nama. Semua remote item ini minta UID inventory, bukan
-- nama itemnya.
local function cariItemMisc(spec)
    local ok, uid, id = pcall(function()
        local data = require(Client:WaitForChild("Save")).Get()
        local misc = data and data.Inventory and data.Inventory.Misc
        if not misc then return nil end
        for u, it in pairs(misc) do
            if type(it) == "table" and type(it.id) == "string" then
                local kena
                if spec.sufiks then
                    kena = string.sub(it.id, -#spec.sufiks) == spec.sufiks
                else
                    kena = string.find(it.id, spec.cocok, 1, true) ~= nil
                end
                if kena then return u, it.id end
            end
        end
        return nil
    end)
    if not ok then return nil end
    return uid, id
end

local zqPakaiTerakhir = 0
local function pakaiItemQuest(tipe)
    local spec = ZQ_ITEM[tipe]
    if not spec then return false, nil end
    if not Config.zoneQuestPakaiItem then return false, "pakai item dimatikan" end
    -- Event coin jar/pinata/lucky block punya cooldown di server; menembaknya
    -- tiap siklus cuma menghasilkan penolakan beruntun.
    if os.clock() - zqPakaiTerakhir < 5 then return false, "jeda" end
    if not bolehPakaiItem() then return false, "di luar kotak farming" end

    local uid, id = cariItemMisc(spec)
    if not uid then
        return false, "stok " .. (spec.cocok or spec.sufiks or "item") .. " habis"
    end

    zqPakaiTerakhir = os.clock()

    if spec.flag then
        -- Flag lewat FlexibleFlagCmds.Consume(id, uid, jumlah).
        -- Sengaja 1 per panggilan walau GetMaxPlaceAutomaticContext mengizinkan
        -- lebih — quest cuma menghitung jumlah pakai, tidak perlu boros.
        local ok, res = pcall(function()
            return require(Client:WaitForChild("FlexibleFlagCmds")).Consume(id, uid, 1)
        end)
        return (ok and res == true), id
    end

    local remote = Network:FindFirstChild(spec.remote)
    if not remote then return false, "remote " .. spec.remote .. " hilang" end
    local ok, res = pcall(function() return remote:InvokeServer(uid) end)
    return (ok and res ~= false), id
end

-- Status quest satu zone:
--   nil = save belum bisa dibaca, JANGAN ambil keputusan apa pun
--   -1  = quest belum di-assign server
--   0   = semua quest zone ini beres
--   >0  = jumlah quest yang masih tersisa
--
-- Soal -1: server baru membagikan quest sebuah zone setelah pemain memecah
-- breakable di sana. Zone yang belum pernah disentuh isinya cuma
-- {BreakablesBroken = 0} tanpa field Quests. Kalau itu dibaca sebagai "tidak
-- ada quest = beres", seluruh world 1 akan dilewati tanpa dikerjakan.
local function statusZone(namaZone)
    local ok, sisa, tipe, judul = pcall(function()
        local data = require(Client:WaitForChild("Save")).Get()
        if not data or not data.ZoneQuests then return nil end
        local zq = data.ZoneQuests[namaZone]
        if not zq then return -1 end
        if type(zq.Quests) ~= "table" or #zq.Quests == 0 then return -1 end

        local belum, t, j = 0, nil, nil
        for _, q in ipairs(zq.Quests) do
            local g = q.Goal
            local progres = g and tonumber(g.Progress) or 0
            local target = g and tonumber(g.Amount) or 0
            if g and not q.Completed and progres < target then
                belum = belum + 1
                if not t then
                    t = g.Type
                    local okJ, teks = pcall(function()
                        return require(Client:WaitForChild("QuestCmds")).MakeTitle(g)
                    end)
                    j = okJ and tostring(teks) or ("type " .. tostring(g.Type))
                end
            end
        end
        return belum, t, j
    end)
    if not ok then return nil end
    return sisa, tipe, judul
end

local function teleportKeZone(namaZone)
    local remote = Network:FindFirstChild("Teleports_RequestTeleport")
    if not remote then return false end
    local ok, res = pcall(function() return remote:InvokeServer(namaZone) end)
    return ok and res == true
end

-- ==========================================
-- PELACAK JALUR KE BOSS (Fiesta Maze)
-- ==========================================
-- Maze berbentuk POHON, dan datanya lengkap di FiestaMazeCmds.Get():
--   layout.chests[sel] == "boss"  -> sel itu berisi boss
--   graph.parentOf[sel]           -> induk sel (akar = sel tanpa induk)
--   built[sel] = "Room4"          -> sel sudah dibangun, modelnya ada di Rooms
--
-- Terukur di maze nyata: sel boss = 70, 102, 138. Dari sel 122, boss 70 ada di
-- rantai leluhur (di belakang) sementara 138 empat langkah ke depan
-- (122 -> 123 -> 124 -> 125 -> 138). Jadi "boss terdekat" bukan soal jarak
-- stud, melainkan jumlah langkah di pohon.
local function mazeRantaiKeAkar(parentOf, sel)
    local urut, lihat = {}, {}
    local c = sel
    while c ~= nil and not lihat[c] do
        lihat[c] = true
        urut[#urut + 1] = c
        c = parentOf[c]
    end
    return urut
end

-- Jalur sel A -> sel B lewat leluhur bersama terdekat.
local function mazeJalur(parentOf, a, b)
    local ra = mazeRantaiKeAkar(parentOf, a)
    local rb = mazeRantaiKeAkar(parentOf, b)
    local indeksA = {}
    for i, v in ipairs(ra) do indeksA[v] = i end

    local temu, iB
    for i, v in ipairs(rb) do
        if indeksA[v] then temu, iB = v, i break end
    end
    if not temu then return nil end

    local jalur = {}
    for i = 1, indeksA[temu] do jalur[#jalur + 1] = ra[i] end     -- naik A -> LCA
    for i = iB - 1, 1, -1 do jalur[#jalur + 1] = rb[i] end        -- turun LCA -> B
    return jalur
end

-- Kumpulan sel yang BENAR-BENAR di jalur boss.
--
-- Maze punya jalur utama + cabang buntu. Terukur di maze nyata:
--   config: pathLength=18, branchCount=5, branchMinLen/MaxLen=3
--   sel boss 47, 90, 52; gabungan rantainya = 18 sel  <- sama dengan pathLength
--   sisanya 16 sel (12,20,21,25,33,38,56,57,58,65,99,102,112,113,115,116)
--   adalah CABANG — tidak pernah menuju boss mana pun.
--
-- Dengan menyaring ke himpunan ini, perpindahan tidak lagi melenceng ke cabang
-- yang tidak menambah kemajuan ke boss.
local function mazeSelJalurBoss(g)
    local parentOf = g.graph and g.graph.parentOf or {}
    local set, adaBoss = {}, false
    for sel, jenis in pairs((g.layout or {}).chests or {}) do
        if tostring(jenis) == "boss" then
            adaBoss = true
            for _, c in ipairs(mazeRantaiKeAkar(parentOf, sel)) do set[c] = true end
        end
    end
    if not adaBoss then return nil end
    return set
end

-- Sasaran berikutnya menuju boss TERDEKAT (hitungan langkah, bukan stud).
-- Balikan: model room, sisa langkah, nomor sel boss.
local function mazeSasaranBoss()
    local ok, model, langkah, selBoss = pcall(function()
        local FM = require(Client:WaitForChild("FiestaMazeCmds"))
        local g = FM.Get()
        if type(g) ~= "table" or type(g.graph) ~= "table" or type(g.layout) ~= "table" then return nil end
        local rooms = typeof(g.rooms) == "Instance" and g.rooms or nil
        if not rooms then return nil end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        -- Sel sekarang = sel built yang model room-nya paling dekat.
        local selKini, jarakMin
        for sel, nama in pairs(g.built or {}) do
            local m = rooms:FindFirstChild(tostring(nama))
            if m then
                local d = (m:GetPivot().Position - hrp.Position).Magnitude
                if not jarakMin or d < jarakMin then selKini, jarakMin = sel, d end
            end
        end
        if not selKini then return nil end

        local parentOf = g.graph.parentOf or {}
        local jalurTerbaik, bossTerbaik
        for sel, jenis in pairs(g.layout.chests or {}) do
            if tostring(jenis) == "boss" then
                local j = mazeJalur(parentOf, selKini, sel)
                if j and (not jalurTerbaik or #j < #jalurTerbaik) then
                    jalurTerbaik, bossTerbaik = j, sel
                end
            end
        end
        if not jalurTerbaik then return nil end

        -- Pilih sel di jalur ini dengan urutan tegas:
        --
        --   1) Sel BELUM CLEARED yang paling dekat ke boss.
        --      Di sanalah breakable berada, dan membersihkannya yang membuka
        --      sel berikutnya. Ini yang menjaga langkah selalu MAJU.
        --   2) Kalau semua sel jalur sudah cleared, ambil yang TERJAUH sudah
        --      dibangun — batas kemajuan saat ini.
        --
        -- Keduanya hanya memilih dari `jalurTerbaik`, jadi cabang buntu tidak
        -- pernah ikut terpilih.
        local cleared = g.cleared or {}
        local built = g.built or {}
        local target, selTarget

        for i = #jalurTerbaik, 1, -1 do
            local sel = jalurTerbaik[i]
            local nama = built[sel]
            local m = nama and rooms:FindFirstChild(tostring(nama))
            if m and not cleared[sel] then target, selTarget = m, sel break end
        end

        if not target then
            for i = #jalurTerbaik, 1, -1 do
                local sel = jalurTerbaik[i]
                local nama = built[sel]
                local m = nama and rooms:FindFirstChild(tostring(nama))
                if m then target, selTarget = m, sel break end
            end
        end

        return target, #jalurTerbaik - 1, bossTerbaik, selTarget
    end)
    if not ok then return nil end
    return model, langkah, selBoss
end

-- Sel terbuka berikutnya yang MASIH DI JALUR BOSS.
-- Dipakai sebagai cadangan menggantikan mazeRoomBerikutnya() saat mode kejar
-- boss aktif, supaya bot tidak melenceng ke cabang buntu.
local function mazeSelBerikutnyaDiJalur()
    local ok, model, sel = pcall(function()
        local FM = require(Client:WaitForChild("FiestaMazeCmds"))
        local g = FM.Get()
        if type(g) ~= "table" then return nil end
        local rooms = typeof(g.rooms) == "Instance" and g.rooms or nil
        if not rooms then return nil end
        local jalurSet = mazeSelJalurBoss(g)
        if not jalurSet then return nil end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        local terbaik, terdekat, selT
        for s, nama in pairs(g.built or {}) do
            if jalurSet[s] and not (g.cleared or {})[s] then
                local m = rooms:FindFirstChild(tostring(nama))
                if m then
                    local d = (m:GetPivot().Position - hrp.Position).Magnitude
                    if not terdekat or d < terdekat then terbaik, terdekat, selT = m, d, s end
                end
            end
        end
        return terbaik, selT
    end)
    if not ok then return nil end
    return model, sel
end

-- Area berikutnya yang belum beres, urut world lalu nomor zone.
local function targetBerikutnya()
    local perWorld = daftarWorld()
    local nomorWorld = {}
    for w in pairs(perWorld) do table.insert(nomorWorld, w) end
    table.sort(nomorWorld)

    for _, w in ipairs(nomorWorld) do
        if w >= (Config.zoneQuestMulaiWorld or 1) and not ZQ_Progress.world[tostring(w)] then
            for _, z in ipairs(perWorld[w]) do
                if (ZQ_Progress.zona[z.nama] or 0) < ZQ_VERIFIKASI_MIN then
                    return w, z.nama
                end
            end
            -- Sampai sini berarti seluruh area world ini sudah lolos 2x cek.
            ZQ_Progress.world[tostring(w)] = true
            simpanProgress()
        end
    end
    return nil, nil
end

-- ==========================================
-- AUTO FARM LOOP
-- ==========================================
-- Farming = fire Breakables_PlayerDealDamage ke semua breakable
-- Breakable = Model dengan nama angka di Workspace.__THINGS.Breakables
-- Plus auto-claim lootbag + orb
-- WAJIB ke tengah breakable biar pet ikut nyerang
task.spawn(function()
    if not Breakables then return end

    -- auto-claim lootbag: listen ke child added
    if Lootbags then
        Lootbags.ChildAdded:Connect(function(bag)
            if not Config.autoLootbag then return end
            pcall(function()
                Network:WaitForChild("Lootbags_Claim"):FireServer({bag.Name})
                task.wait(0.1)
                if bag and bag.Parent then bag:Destroy() end
            end)
        end)
        -- claim yang sudah ada
        for _, bag in ipairs(Lootbags:GetChildren()) do
            pcall(function()
                Network:WaitForChild("Lootbags_Claim"):FireServer({bag.Name})
                task.wait(0.1)
                if bag and bag.Parent then bag:Destroy() end
            end)
        end
    end

    -- auto-collect orb: listen ke child added
    if Orbs then
        Orbs.ChildAdded:Connect(function(orb)
            if not Config.autoLootbag then return end
            pcall(function()
                Network:WaitForChild("Orbs: Collect"):FireServer({tonumber(orb.Name)})
                task.wait(0.1)
                if orb and orb.Parent then orb:Destroy() end
            end)
        end)
        -- collect yang sudah ada
        for _, orb in ipairs(Orbs:GetChildren()) do
            pcall(function()
                Network:WaitForChild("Orbs: Collect"):FireServer({tonumber(orb.Name)})
                task.wait(0.1)
                if orb and orb.Parent then orb:Destroy() end
            end)
        end
    end

    -- hitung pusat breakable TERDEKAT (bukan semua — spread antar zone bikin character lari jauh)
    local function getBreakableCenter()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        -- cari breakable terdekat dulu
        local closest, closestDist = nil, math.huge
        for _, b in ipairs(Breakables:GetChildren()) do
            if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name) then
                local dist = (b:GetPivot().Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = b
                end
            end
        end
        if not closest then return nil end

        -- kumpulkan breakable dalam radius 60 stud dari yang terdekat
        local centerPos = closest:GetPivot().Position
        local sumPos = Vector3.new(0, 0, 0)
        local count = 0
        for _, b in ipairs(Breakables:GetChildren()) do
            if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name) then
                local dist = (b:GetPivot().Position - centerPos).Magnitude
                if dist < 60 then
                    sumPos = sumPos + b:GetPivot().Position
                    count = count + 1
                end
            end
        end
        if count > 0 then
            return sumPos / count
        end
        return centerPos
    end

    -- main farm loop — kirim pets ke breakable terdekat
    -- CRITICAL: Breakables_PlayerDealDamage = player click damage (sangat kecil tanpa pet)
    -- Yang benar: PlayerPet.SetTarget(pet, breakableModel) → pet damage server-side
    local PlayerPetMod = nil
    pcall(function()
        PlayerPetMod = require(Client:WaitForChild("PlayerPet"))
    end)

    local lastTargetUID = nil -- hindari spam set target ke breakable yang sama

    -- Heartbeat retarget: langsung reassign pets saat breakable mati
    -- Lebih cepat dari polling — pet gak idle nunggu tick
    -- Throttle: retarget tiap ~6 frame (~10x/detik) supaya gak lag
    local retargetConnection = nil
    local retargetFrame = 0
    -- Dideklarasikan SEBELUM startRetarget, bukan di blok multi-tap di bawah.
    -- Retarget memakainya untuk mengenali boss; kalau deklarasinya di bawah,
    -- nama ini terbaca sebagai global nil di sini dan penargetan boss tidak
    -- pernah aktif — gagal diam-diam, tanpa error.
    local BreakableFrontendMod = nil
    pcall(function()
        BreakableFrontendMod = require(Client:WaitForChild("BreakableFrontend"))
    end)

    local function startRetarget()
        if retargetConnection then retargetConnection:Disconnect() end
        retargetFrame = 0
        retargetConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if not Config.autoFarm or farmDijeda then return end
            retargetFrame = retargetFrame + 1
            if retargetFrame % 6 ~= 0 then return end -- throttle: 10x/detik
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                if not PlayerPetMod then return end

                local pets = PlayerPetMod.GetByPlayer(LocalPlayer)
                local petList = {}
                for _, v in pairs(pets) do
                    table.insert(petList, v)
                end
                if #petList == 0 then return end

                -- kumpulkan breakable terdekat (sorted by distance)
                local nearby = {}
                for _, b in ipairs(Breakables:GetChildren()) do
                    if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name) then
                        local dist = (b:GetPivot().Position - hrp.Position).Magnitude
                        if dist < jangkauanSerang() then
                            table.insert(nearby, {model=b, dist=dist})
                        end
                    end
                end
                table.sort(nearby, function(a, b) return a.dist < b.dist end)

                if #nearby == 0 then return end

                -- Boss/pinata hadir -> SELURUH pet ke sana.
                --
                -- Terukur di boss maze (PinataBoss3, 2,2 juta HP, 72 stud):
                -- 25 tap = 59rb damage, sementara 27 pet dalam 4 detik = 271rb
                -- (~68rb/detik). Pet hampir 30x lebih berat daripada tap, jadi
                -- membiarkannya tersebar ke peti receh saat boss hidup itu
                -- pemborosan — boss berdurasi terbatas, peti terus respawn.
                -- BOSS ditunda sampai seluruh room habis (lihat mazeSiapBoss):
                -- membunuhnya mengakhiri run, sementara hadiah masih bertambah
                -- selama room belum mentok. Pinata biasa TIDAK ditunda — ia
                -- bonus lewat, bukan pengakhir run.
                -- Boss dicari di radius maze PENUH, bukan radius fokus.
                --
                -- Saat mengejar boss jangkauan dipersempit ke 45 supaya pet tidak
                -- tersebar antar sel — tapi boss sendiri terukur bisa berada 72
                -- stud jauhnya. Kalau ikut disaring 45, pet justru berhenti
                -- menyasarnya persis saat ia paling penting.
                local bossTarget = nil
                if BreakableFrontendMod then
                    local bolehBoss = mazeSiapBoss()
                    local radiusBoss = modeLucky() and JANGKAUAN_MAZE or JANGKAUAN_NORMAL
                    for _, b in ipairs(Breakables:GetChildren()) do
                        if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name)
                            and (b:GetPivot().Position - hrp.Position).Magnitude < radiusBoss then
                            local okB, dB = pcall(BreakableFrontendMod.Get, b.Name)
                            if okB and type(dB) == "table" then
                                local teks = (tostring(dB.id or "") .. " " .. tostring(dB.class or "")):lower()
                                local iniBoss = string.find(teks, "boss", 1, true) ~= nil
                                local iniPinata = string.find(teks, "pinata", 1, true) ~= nil
                                if (iniBoss and bolehBoss) or (iniPinata and not iniBoss) then
                                    bossTarget = b
                                    break
                                end
                            end
                        end
                    end
                end

                for i, pet in ipairs(petList) do
                    local target = bossTarget or (nearby[i] or nearby[1]).model
                    if target then
                        pet:SetTarget(target)
                    end
                end
            end)
        end)
    end
    startRetarget()

    -- ==========================================
    -- MULTI-TAP HEARTBEAT
    -- ==========================================
    -- Fire Breakables_PlayerDealDamage ke SEMUA breakable setiap tick
    -- Tap damage = click damage yang ditambah ke pet damage
    -- UnreliableFire = fire-and-forget, aman di-spam
    local tapFrame = 0
    local tapConnection = nil
    local tapTarget = nil      -- breakable yang sedang dihajar
    local tapTargetSaat = 0    -- kapan sasaran terakhir dipilih ulang

    local function tapData(nama)
        if not BreakableFrontendMod then return nil end
        local ok, d = pcall(BreakableFrontendMod.Get, nama)
        if ok and type(d) == "table" then return d end
        return nil
    end

    -- Sasaran prioritas: pinata dan BOSS maze.
    --
    -- Dikenali dari field id/class pada data breakable (contoh field nyata:
    -- id="Crate (Fiesta)" class="Normal", id="Pinata" class="Chest").
    -- Keduanya berdurasi terbatas dan hadiahnya jauh lebih besar daripada
    -- breakable biasa yang terus respawn, jadi selalu didahulukan dan
    -- TANPA batas jarak — tap terbukti menembus sampai 220 stud.
    local function adalahPinata(d)
        if type(d) ~= "table" then return false end
        local teks = (tostring(d.id or "") .. " " .. tostring(d.class or "")):lower()
        return string.find(teks, "pinata", 1, true) ~= nil
            or string.find(teks, "boss", 1, true) ~= nil
    end

    local function startMultiTap()
        if tapConnection then tapConnection:Disconnect() end
        tapFrame = 0
        tapConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if not Config.autoFarm or farmDijeda then return end
            tapFrame = tapFrame + 1
            if tapFrame % 3 ~= 0 then return end -- ~20x/detik (tiap 3 frame)
            pcall(function()
                local remote = Network:FindFirstChild("Breakables_PlayerDealDamage")
                if not remote then return end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- SATU tap per tick, bukan disemprot ke semua breakable.
                --
                -- Terukur di server: batas tap itu GLOBAL per pemain, bukan per
                -- breakable. 16 tap disebar ke 4 sasaran turun 393 HP; 16 tap
                -- ditumpuk ke 1 sasaran turun 432 HP — praktis sama. Versi lama
                -- menembak tiap breakable dalam radius tiap tick: dengan 17
                -- breakable itu 340 remote/detik padahal server cuma menerima
                -- ~16. Sisanya dibuang, jaringan berat, damage tidak bertambah.
                --
                -- Memusatkan tap juga mengubah damage jadi KILL lebih cepat;
                -- HP yang tersebar separuh-separuh hangus kalau breakable-nya
                -- keburu despawn.
                if not tapTarget or not tapTarget.Parent
                    or os.clock() - tapTargetSaat > 0.5 then
                    tapTargetSaat = os.clock()
                    local playerPos = hrp.Position
                    local terbaik, hpTerbaik = nil, math.huge
                    local boss = nil

                    for _, b in ipairs(Breakables:GetChildren()) do
                        if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name) then
                            local jarak = (b:GetPivot().Position - playerPos).Magnitude
                            local d = tapData(b.Name)

                            -- Pinata/boss dicek TANPA batas jarak: tap menembusnya
                            -- dari jauh, sementara breakable biasa tidak.
                            -- Boss ditunda sampai room mentok; pinata biasa tidak.
                            local teksD = type(d) == "table"
                                and (tostring(d.id or "") .. " " .. tostring(d.class or "")):lower() or ""
                            local iniBoss = string.find(teksD, "boss", 1, true) ~= nil
                            local layakPrioritas = adalahPinata(d)
                                and (not iniBoss or mazeSiapBoss())

                            if not boss and layakPrioritas then
                                boss = b
                            elseif jarak < jangkauanSerang() then
                                -- Sisanya: pilih yang paling sekarat supaya cepat pecah.
                                local h = d and tonumber(d.health)
                                if h and h < hpTerbaik then terbaik, hpTerbaik = b, h end
                            end
                        end
                    end

                    -- Boss selalu menang: dia berdurasi terbatas dan hadiahnya
                    -- jauh lebih besar daripada breakable biasa yang terus respawn.
                    tapTarget = boss or terbaik
                end

                if tapTarget and tapTarget.Parent then
                    remote:FireServer(tapTarget.Name)
                end
            end)
        end)
    end
    startMultiTap()

    -- polling fallback (lebih lambat, tapi handle edge case)
    while true do
        task.wait(0.3)
        if not Config.autoFarm then
            FarmStatus.Text = "Status: OFF"
            if retargetConnection then retargetConnection:Disconnect() end
            if tapConnection then tapConnection:Disconnect() end
            continue
        end
        if not retargetConnection or not retargetConnection.Connected then
            startRetarget()
        end
        if not tapConnection or not tapConnection.Connected then
            startMultiTap()
        end

        pcall(function()
            -- pastikan character ada
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then return end

            -- Jangan rebut kendali jalan saat auto hatch sedang menuju egg.
            if farmDijeda then
                FarmStatus.Text = "Status: Jeda (hatch jalan)"
                return
            end

            -- Mode Maze: serangan & pungut tetap jalan (lihat Heartbeat di atas),
            -- yang dimatikan hanya perpindahan. Karakter berdiri diam.
            if not modeLucky() then
                -- jalan ke pusat breakable terdekat
                local center = getBreakableCenter()
                if center and (hrp.Position - center).Magnitude > 10 then
                    humanoid:MoveTo(Vector3.new(center.X, center.Y, center.Z))
                end
            end

            -- pet target sudah di-handle oleh Heartbeat retarget di atas

            -- update status
            local count = 0
            for _, b in ipairs(Breakables:GetChildren()) do
                if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name) then
                    count = count + 1
                end
            end
            FarmStatus.Text = count > 0
                and string.format("Status: Farming %d breakable (pets+tap)", count)
                or "Status: Menunggu breakable..."
        end)
    end
end)

-- ==========================================
-- AUTO QUEST LOOP (Zone Quests + Rank Goals)
-- ==========================================
-- Baca quest dari Save.Get().ZoneQuests dan Save.Get().Goals
-- Handle: spawn coinjar/comet, gold/rainbow machine, use items
-- questBusy flag mencegah auto world beli area saat quest aktif
-- coinjar speed-up: saat 1 jar selesai, langsung beli area baru + spawn jar lagi
task.spawn(function()
    local questSpawnCooldown = 0
    local lastCoinJarProgress = 0 -- track progress coinjar buat speed-up
    local lastPotionUseTime = 0 -- debounce USE_POTION: 3 dtk antar consume

    while true do
        task.wait(Config.questDelay)
        if not Config.autoQuest then
            QuestStatus.Text = "Status: OFF"
            questBusy = false
            continue
        end

        pcall(function()
            -- 1. Baca semua quest aktif
            local quests = getAllActiveQuests()

            -- 2. Update global state untuk auto world
            -- questBusy HANYA dari rank goals (zone quest optional, gak block beli area)
            -- coinjar (37) TIDAK block auto world — malah trigger beli area baru
            -- Hatch (20) dan Comet (38) masih block auto world
            questBusy = false
            for _, q in ipairs(quests) do
                if q.source == "rank" and q.progress < q.amount then
                    local stayTypes = {[20]=true, [38]=true} -- 37 (coinjar) dihapus
                    if stayTypes[q.type] then
                        questBusy = true
                        break
                    end
                end
            end

            -- 3. Handle HANYA rank goals (zone quest cuma display)
            local rankActive = 0
            local hasHatchQuest = false
            local statusTexts = {}

            for _, q in ipairs(quests) do
                if q.progress >= q.amount then continue end

                -- Zone quest: cuma tampilkan, jangan handle
                if q.source == "zone" then
                    local desc = questDescription(q)
                    table.insert(statusTexts, string.format("[Z] %s", desc))
                    continue
                end

                -- Rank goals: handle aktif
                rankActive = rankActive + 1
                local desc = questDescription(q)
                table.insert(statusTexts, string.format("[R] %s", desc))

                -- === COIN JAR (SPEED-UP) ===
                if q.type == 37 or q.type == 31 then -- BEST_COIN_JAR / BREAK_COIN_JAR
                    -- Quest selesai atau quest baru (UID beda) → reset tracking
                    if q.progress >= q.amount then
                        lastCoinJarProgress = 0
                    elseif lastCoinJarProgress > q.progress + 1 then
                        -- Quest baru: progress jauh di bawah last tracking
                        lastCoinJarProgress = 0
                    end
                    -- Inisialisasi tracking di tick pertama
                    if lastCoinJarProgress == 0 and q.progress > 0 then
                        lastCoinJarProgress = q.progress
                    end
                    -- Coin jar progress naik = 1 jar selesai
                    -- Strategy: beli area baru + spawn jar lagi → biar cepat
                    -- JANGAN pindah/upgrade area selama masih ada jar berjalan.
                    -- Jar terikat ke area tempat ia dipasang dan TIDAK bisa
                    -- dibatalkan; meninggalkannya berarti membuang isinya dan
                    -- tetap mengunci slot di area lama. Selesaikan dulu, baru
                    -- naik area.
                    if q.progress > lastCoinJarProgress and not jarSedangJalan() then
                        lastCoinJarProgress = q.progress
                        -- Beli area berikutnya
                        pcall(function()
                            local ZoneCmds = require(Client:WaitForChild("ZoneCmds"))
                            local nextZone = ZoneCmds.GetNextZone()
                            if nextZone and nextZone ~= "" then
                                local Network2 = ReplicatedStorage:WaitForChild("Network")
                                local buyRemote = Network2:FindFirstChild("Zones_RequestPurchase")
                                if buyRemote then
                                    buyRemote:InvokeServer(nextZone)
                                    task.wait(0.5)
                                    -- Teleport ke area baru
                                    local tpRemote = Network2:FindFirstChild("Teleports_RequestTeleport")
                                    if tpRemote then
                                        pcall(function() tpRemote:InvokeServer(nextZone) end)
                                    end
                                end
                            end
                        end)
                        task.wait(1) -- tunggu area load
                    end
                    -- Ditembak langsung, TANPA gerbang tebakan.
                    -- Server menolak dengan bersih ("There is already something
                    -- in this area!") dan stok TIDAK berkurang saat ditolak --
                    -- itu sudah diukur. Jadi mencoba tidak merugikan, sedangkan
                    -- menebak kapan boleh mencoba justru pernah membuat quest
                    -- jar mandek total.
                    -- COMET DIDAHULUKAN.
                    --
                    -- Comet dan coin jar berebut satu slot per area, dan jar
                    -- TIDAK bisa dibatalkan sementara comet pecah jauh lebih
                    -- cepat. Kalau jar dipasang duluan saat quest comet juga
                    -- aktif, quest comet terkunci sampai kuota jar penuh --
                    -- terukur sebuah jar butuh 121.285 sementara comet cuma
                    -- perlu beberapa kali pecah.
                    local adaQuestComet = false
                    for _, q2 in ipairs(getAllActiveQuests()) do
                        if q2.type == 38 and q2.progress < q2.amount then
                            adaQuestComet = true
                            break
                        end
                    end

                    if adaQuestComet then
                        QuestStatus.Text = "Quest jar: ditunda, comet didahulukan"
                    elseif not pastikanDiAreaTerbaik() then
                        QuestStatus.Text = "Quest jar: pindah ke area terbaik dulu"
                    else
                        local jarOk, jarKet = spawnCoinJar()
                        if not jarOk then
                            QuestStatus.Text = "Quest jar: " .. tostring(jarKet)
                        end
                    end

                -- === COMET ===
                elseif q.type == 38 then -- BEST_COMET
                    -- Pakai keadaan SERVER, bukan hasil pencarian di workspace:
                    -- slot area dipakai bersama semua jenis event, jadi comet
                    -- tetap ditolak kalau yang aktif kebetulan sebuah coin jar.
                    if eventAktif() == 0 then
                        if pastikanDiAreaTerbaik() then
                            spawnComet()
                        else
                            QuestStatus.Text = "Quest comet: pindah ke area terbaik dulu"
                        end
                    end

                -- === GOLD MACHINE ===
                elseif q.type == 40 then -- BEST_GOLD_PET
                    activateGoldMachine()

                -- === RAINBOW MACHINE ===
                elseif q.type == 41 then -- BEST_RAINBOW_PET
                    activateRainbowMachine()

                -- === USE POTION ===
                elseif q.type == 34 then -- USE_POTION
                    -- Server perlu waktu memperbarui progress; tanpa jeda, satu
                    -- quest lambat bisa menghabiskan banyak potion sekaligus.
                    if os.clock() - lastPotionUseTime >= 3 then
                        local okPotion, ketPotion = usePotion(q.potionID, q.potionTier)
                        if okPotion then
                            lastPotionUseTime = os.clock()
                        elseif ketPotion then
                            QuestStatus.Text = "Potion: " .. tostring(ketPotion)
                        end
                    end

                -- === USE FRUIT ===
                elseif q.type == 35 then -- USE_FRUIT
                    useFruit(q.fruitID)

                -- === USE FLAG ===
                elseif q.type == 33 then -- USE_FLAG
                    useFlag(nil)

                -- === HATCH BEST EGG ===
                elseif q.type == 20 then -- BEST_EGG
                    hatchBestEgg()
                    hasHatchQuest = true

                -- === HATCH LEGENDARY ===
                elseif q.type == 42 then -- HATCH LEGENDARY
                    hatchBestEgg()
                    hasHatchQuest = true

                end
                -- Type lain (21,39,63,64,14,15): auto-farm via farm loop
            end

            -- Stop hatch HANYA kalau auto hatch memang dimatikan user.
            -- Sebelumnya blok ini jalan tiap siklus quest (2 dtk) begitu tidak
            -- ada quest type 20 — dan loop auto hatch baru menyalakan ulang tiap
            -- 8 dtk, jadi hatch selalu mati sebelum sempat jalan. Itu sebabnya
            -- auto hatch terlihat "tidak bekerja" padahal SetupEgg/Enable normal.
            if not hasHatchQuest and not Config.autoHatch then
                pcall(function()
                    local HatchingCmds = require(Client:WaitForChild("HatchingCmds"))
                    if HatchingCmds.IsHatching() then
                        HatchingCmds.StopHatching()
                    end
                end)
            end

            -- 4. Auto claim dimatikan — Ranks_ClaimReward buka GUI, ganggu gameplay
            -- Claim manual via tombol Rewards di game

            -- 5. Update status UI (tampilkan rank goals + zone quest count)
            local totalActive = rankActive
            -- hitung zone quest yang belum selesai (cuma count, buat display)
            local zonePending = 0
            for _, q in ipairs(quests) do
                if q.source == "zone" and q.progress < q.amount then
                    zonePending = zonePending + 1
                end
            end

            if rankActive > 0 or zonePending > 0 then
                local display = table.concat(statusTexts, " | ")
                if #display > 80 then
                    display = string.sub(display, 1, 77) .. "..."
                end
                local zoneInfo = zonePending > 0
                    and string.format(" (+%d zone)", zonePending)
                    or ""
                QuestStatus.Text = string.format("%d goal: %s%s", rankActive, display, zoneInfo)
            else
                QuestStatus.Text = "Status: Semua quest selesai ✓"
            end
        end)
    end
end)

-- ==========================================
-- AUTO HATCH — datangi egg saat ada quest hatch
-- ==========================================
-- Data egg terbaik: id, zone, mata uang, harga, dan part fisiknya di dunia.
-- Harga hanya ada sebagai teks di PriceHUD ("55k"), jadi dipulihkan ke angka
-- pakai Functions.ParseNumberSmart milik game sendiri.
local function infoEggTerbaik()
    local ok, hasil = pcall(function()
        local EggsUtil = require(ReplicatedStorage.Library.Util.EggsUtil)
        local Functions = require(ReplicatedStorage.Library.Functions)
        local EggCmds = require(Client:WaitForChild("EggCmds"))
        local Dir = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Directory"))

        -- Pilih lewat penanda `bestEgg`, JANGAN lewat nomor egg tertinggi.
        --
        -- eggNumber dan zoneNumber beda skala: eggNumber 279 itu "Mirror Tome
        -- Path Egg" yang berada di zone 267, sedangkan egg terbaik "Hollow Egg"
        -- bernomor 291 di zone 279. Kalau GetHighestEggNumberAvailable() sempat
        -- mengembalikan nilai lebih rendah (mis. Save belum tersinkron sesaat
        -- setelah join), karakter dikirim ke zone yang salah — persis gejala
        -- "malah ke 267 padahal best area 279".
        -- Egg TERKUNCI harus ditolak, bukan cuma "tidak tersedia".
        --
        -- Terukur 2026-08-20 di Tech World: egg terbuka PER ZONA.
        --     Tech City Egg   zone 101  tersedia=true  terkunci=false  (dibeli 60x)
        --     Tech Forest Egg zone 102  tersedia=false terkunci=true
        --     Tech Silo Egg   zone 103  tersedia=false terkunci=true
        -- Begitu bot maju ke zona baru (mis. lewat pembelian zona di quest
        -- jar), egg di sana masih terkunci. Menjadikannya target berarti
        -- karakter dikirim ke egg yang tidak bisa ditetaskan lalu nyangkut di
        -- sana -- persis gejala "parkir di egg dan tidak mau farming".
        local function layak(nama)
            local okA, tersedia = pcall(EggCmds.IsEggAvailable, nama)
            if not (okA and tersedia) then return false end
            local okL, terkunci = pcall(EggCmds.IsEggLocked, nama)
            if okL and terkunci == true then
                -- Coba buka sekali; kalau tetap terkunci, JANGAN dijadikan
                -- target. Lebih baik tidak punya target (dan terus farming)
                -- daripada punya target yang tidak bisa dipakai.
                pcall(EggCmds.RequestUnlock, nama)
                task.wait(0.5)
                local ok2, masih = pcall(EggCmds.IsEggLocked, nama)
                if ok2 and masih == true then return false end
            end
            return true
        end

        local id
        for nama, v in pairs(Dir.Eggs) do
            if type(v) == "table" and v.bestEgg and layak(nama) then
                id = nama
                break
            end
        end

        -- Cadangan kalau tidak ada egg bertanda bestEgg yang layak.
        -- Versi lama memakai nomor tertinggi APA ADANYA, tanpa memeriksa
        -- tersedia maupun terkunci -- itu jalur yang mengirim karakter ke egg
        -- terkunci.
        if not id then
            local nomor = EggCmds.GetHighestEggNumberAvailable()
            local calon = nomor and EggsUtil.GetIdByNumber(nomor)
            if calon and layak(calon) then id = calon end
        end

        local entry = id and Dir.Eggs[id]
        if not entry then return nil end

        -- GetEggPart minta eggNumber, BUKAN zoneNumber.
        --
        -- Kapsul di __THINGS.ZoneEggs dinamai pakai nomor EGG: World 4 berisi
        -- kapsul 252..291 (rentang eggNumber), sedangkan zone-nya 240..279.
        -- Memberi zoneNumber 279 mengembalikan kapsul egg 279 = "Mirror Tome
        -- Path Egg" yang fisiknya ada di zone 267 — itulah kenapa karakter
        -- selalu mendarat di area 267 padahal best area-nya 279.
        local part = EggsUtil.GetEggPart(entry.eggNumber)

        -- Nama zone tempat egg ini berada, untuk teleport resmi game.
        local namaZone
        for n, z in pairs(Dir.Zones) do
            if type(z) == "table" and z.ZoneNumber == entry.zoneNumber then namaZone = n break end
        end
        -- Harga resmi dulu; billboard cuma cadangan kalau modul balancing
        -- tidak bisa dipanggil (executor tanpa setthreadidentity).
        local harga = hargaEggResmi(entry)
        if not harga and typeof(part) == "Instance" then
            local akar = part:FindFirstAncestorWhichIsA("Model") or part
            for _, d in ipairs(akar:GetDescendants()) do
                if d:IsA("TextLabel") and d.Name == "Amount" then
                    harga = Functions.ParseNumberSmart(d.Text)
                    break
                end
            end
        end

        return {
            id = id,
            currency = entry.currency,
            zoneNumber = entry.zoneNumber,
            eggNumber = entry.eggNumber,
            namaZone = namaZone,
            part = typeof(part) == "Instance" and part or nil,
            harga = tonumber(harga),
        }
    end)
    -- Titipkan harga + mata uang untuk hatchBestEgg(), yang didefinisikan lebih
    -- dulu sehingga tidak bisa memanggil fungsi ini secara langsung.
    if ok and hasil then
        hargaEggTerakhir = tonumber(hasil.harga)
        currencyEggTerakhir = hasil.currency
    end
    return ok and hasil or nil
end

-- Quest hatch yang belum kelar (type 20 BEST_EGG / 42 HATCH LEGENDARY).
-- Posisi sebelum berangkat ke egg, supaya bisa dikembalikan ke area farming.
local hatchPosAsal = nil

-- Pemantau kemajuan hatch, dipakai detektor macet di loop bawah.
local hatchCountTerakhir = nil
local hatchDiamSejak = 0

local function adaQuestHatch()
    local ok, ada = pcall(function()
        for _, q in ipairs(getAllActiveQuests()) do
            -- 3 = EGG ("Hatch N eggs" di zona berjalan), beda dari 20
            -- (BEST_EGG). Terukur 2026-08-21: modul goal game
            -- GoalCmds.Modules.Eggs menutup diri dengan
            -- `if RebirthCmds.Get() >= 1 then return end`, jadi quest ini
            -- HANYA hidup di akun rebirth 0 -- itu sebabnya cuma kelihatan
            -- di akun rank kecil.
            if (q.type == 3 or q.type == 20 or q.type == 42) and q.progress < q.amount then
                return true
            end
        end
        return false
    end)
    return ok and ada
end

task.spawn(function()
    while true do
        task.wait(3)

        -- Di maze tidak ada egg, dan berjalan mencarinya berarti keluar dari maze.
        if modeLucky() then
            if farmDijeda then farmDijeda = false end
            lepaskanHatch()
            HatchStatus.Text = "Status: nonaktif (mode Maze)"
            continue
        end

        local lanjut = pcall(function()
            local HatchingCmds = require(Client:WaitForChild("HatchingCmds"))
            local questHatch = adaQuestHatch()

            -- Tanpa quest hatch, jangan pernah memarkir karakter di egg —
            -- farm akan mati selamanya. Cukup coba nyalakan auto hatch di tempat.
            if not questHatch then
                hatchCountTerakhir = nil
                if farmDijeda then
                    farmDijeda = false
                    -- Balikkan ke titik farming semula. Tanpa ini karakter
                    -- ditinggal ~937 stud dari breakable dan loop farm mulai
                    -- lagi dari nol di area egg yang kosong.
                    if hatchPosAsal then
                        local ch = LocalPlayer.Character
                        local h = ch and ch:FindFirstChild("HumanoidRootPart")
                        if h then h.CFrame = hatchPosAsal end
                        hatchPosAsal = nil
                    end
                    HatchStatus.Text = "Status: quest hatch kelar, balik farm"
                else
                    HatchStatus.Text = Config.autoHatch and "Status: siaga (tanpa quest hatch)" or "Status: OFF"
                end
                if Config.autoHatch and not HatchingCmds.IsHatching() then
                    hatchBestEgg()
                end
                return
            end

            -- === Ada quest hatch ===
            if not Config.autoHatchDatangiEgg then
                -- WAJIB lepas remnya di sini. Tanpa baris ini, farmDijeda yang
                -- sudah terlanjur true dari siklus sebelumnya tidak pernah
                -- dilepas, dan farm berhenti total tanpa jejak error.
                farmDijeda = false
                HatchStatus.Text = "Status: quest hatch (datangi egg dimatikan)"
                if not HatchingCmds.IsHatching() then hatchBestEgg() end
                return
            end

            local egg = infoEggTerbaik()
            if not egg or not egg.part then
                farmDijeda = false
                -- Tanpa ini, hatching yang sempat dinyalakan tetap menggantung
                -- dan karakter terparkir walau egg-nya tidak ada di sini.
                lepaskanHatch()
                HatchStatus.Text = "Status: egg tidak ketemu di dunia ini"
                return
            end

            -- Cek dana untuk satu batch penuh. Kalau kurang, lepaskan farm dulu
            -- supaya coin-nya terkumpul — persis alur yang diminta.
            local CurrencyCmds = require(Client:WaitForChild("CurrencyCmds"))
            local EggCmds = require(Client:WaitForChild("EggCmds"))
            local batch = math.max(1, tonumber(EggCmds.GetMaxHatch()) or 1)
            if egg.harga and egg.currency then
                local butuh = egg.harga * batch
                local mampu = select(2, pcall(CurrencyCmds.CanAfford, egg.currency, butuh))
                if mampu == false then
                    farmDijeda = false
                    -- Teleport ke zone terakhir yang dimiliki (farming area).
                    -- hatchPosAsal bisa kosong atau posisi lama yang juga di egg,
                    -- jadi jangan andalkan itu. Langsung teleport ke farming zone.
                    pcall(function()
                        local ZoneCmds = require(Client:WaitForChild("ZoneCmds"))
                        local terbaik = ZoneCmds.GetMaxOwnedZone()
                        local tp = Network:FindFirstChild("Teleports_RequestTeleport")
                        if tp and type(terbaik) == "string" and terbaik ~= "" then
                            tp:InvokeServer(terbaik)
                        end
                    end)
                    hatchPosAsal = nil
                    lepaskanHatch()
                    HatchStatus.Text = string.format("Status: %s kurang, balik farm", tostring(egg.currency))
                    return
                end
            end

            -- Dana cukup: rem farm, lalu jalan ke egg.
            farmDijeda = true

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then
                -- Karakter sedang respawn: lepas rem dulu, jangan kunci farm
                -- sambil menunggu sesuatu yang belum tentu datang.
                farmDijeda = false
                return
            end

            local tujuan = egg.part:GetPivot().Position
            local jarak = (hrp.Position - tujuan).Magnitude

            if jarak > 8 then
                if not hatchPosAsal then
                    hatchPosAsal = hrp.CFrame -- disimpan biar bisa balik ke area farming
                end

                -- Langkah 1: pindah zone lewat teleport resmi game.
                -- CFrame jarak jauh ke zone yang belum ter-stream akan dipental
                -- balik (terukur: diminta 4 stud, mendarat 983 stud). Teleport
                -- zone membuat areanya dimuat lebih dulu.
                local Map = require(Client:WaitForChild("MapCmds"))
                if egg.namaZone and Map.GetCurrentZone() ~= egg.namaZone then
                    local tp = Network:FindFirstChild("Teleports_RequestTeleport")
                    if tp then pcall(function() tp:InvokeServer(egg.namaZone) end) end
                    HatchStatus.Text = string.format("Status: teleport ke %s", tostring(egg.namaZone))
                    task.wait(2)
                    return
                end

                -- Langkah 2: rapatkan ke kapsul. Diulang karena percobaan
                -- pertama sering terpental saat area masih dimuat.
                -- MoveTo tidak dipakai: dia bukan pathfinding, jalan lurus
                -- menabrak tembok lalu nyangkut, dan punya timeout 8 detik.
                for _ = 1, 8 do
                    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not h then break end
                    h.CFrame = CFrame.new(tujuan + Vector3.new(0, 4, 0))
                    task.wait(0.6)
                    if (h.Position - tujuan).Magnitude <= 8 then break end
                end

                HatchStatus.Text = string.format("Status: menuju %s (%.0f stud)", tostring(egg.id), jarak)
                return
            end

            -- Sudah di depan egg.
            if not HatchingCmds.IsHatching() then hatchBestEgg() end

            -- Detektor macet -- jaring pengaman terakhir.
            --
            -- Game TIDAK melempar error kalau hatch tidak jadi: IsHatching
            -- cuma menggantung `true` selamanya sementara farm direm, jadi
            -- coin tidak pernah bertambah dan keadaannya tidak pulih sendiri.
            -- Terukur 2026-08-21 dari jarak 16.491 stud: IsHatching=true tapi
            -- 0 pembelian dan 0 perubahan saldo dalam 6 detik.
            --
            -- Penyebabnya bisa macam-macam (kejauhan, duit kurang, egg belum
            -- di-unlock, server menolak), jadi yang dipantau HASILnya saja:
            -- jumlah pembelian egg. Diam = macet, apa pun sebabnya.
            local EggCmdsPantau = require(Client:WaitForChild("EggCmds"))
            local cnt = tonumber(select(2, pcall(EggCmdsPantau.GetPurchaseCount, egg.id)))
            if cnt ~= hatchCountTerakhir then
                hatchCountTerakhir = cnt
                hatchDiamSejak = os.clock()
            elseif os.clock() - hatchDiamSejak > 20 then
                -- 20 detik tanpa satu pun egg bertambah itu macet, bukan lambat:
                -- satu batch normal selesai jauh di bawah itu.
                farmDijeda = false
                hatchPosAsal = nil
                hatchCountTerakhir = nil
                hatchDiamSejak = os.clock()
                lepaskanHatch()
                pcall(function()
                    local ZoneCmds = require(Client:WaitForChild("ZoneCmds"))
                    local terbaik = ZoneCmds.GetMaxOwnedZone()
                    local tp = Network:FindFirstChild("Teleports_RequestTeleport")
                    if tp and type(terbaik) == "string" and terbaik ~= "" then
                        tp:InvokeServer(terbaik)
                    end
                end)
                HatchStatus.Text = "Status: hatch macet 20 dtk, balik farm"
                return
            end

            HatchStatus.Text = string.format("Status: hatch %s (batch %d)", tostring(egg.id), batch)
        end)

        -- Kalau blok di atas meledak, jangan tinggalkan farm dalam keadaan
        -- terkunci — itu membuat script diam total tanpa jejak.
        if not lanjut and farmDijeda then
            farmDijeda = false
            HatchStatus.Text = "Status: error, farm dilepas"
        end
    end
end)

-- ==========================================
-- AUTO COIN JAR — jaga selalu ada satu yang aktif
-- ==========================================
-- Coin jar BUKAN sekali pakai; yang membatasi adalah aturan server "satu event
-- per area". Terukur: dengan stok 340 Basic dan satu jar sedang jalan, spawn
-- kedua ditolak `false, "There is already something in this area!"` dan stok
-- tidak berkurang sama sekali.
--
-- Jadi loop-nya bukan "spawn terus", melainkan "isi lagi begitu kosong".
--
-- Syarat lain yang terukur: di luar kotak putus-putus penolakannya berbunyi
-- "You cannot do that here!" — itu MapCmds.IsInDottedBox(), bukan soal jar.
task.spawn(function()
    while true do
        task.wait(5)
        if not Config.autoCoinJar then continue end

        -- TANPA quest jar, JANGAN pasang jar.
        --
        -- Coin jar dan comet berbagi satu slot event per area. Jar yang
        -- terpasang tanpa alasan mengunci slot itu sampai kuotanya penuh, dan
        -- kuotanya bisa sangat besar -- terukur 2026-08-20: sebuah jar berjalan
        -- dengan Collected=530 dari Required=121.285 (0,4%) sementara quest
        -- comet Type=38 menunggu di 0/3 dan tidak pernah bisa jalan. Jar juga
        -- TIDAK bisa dibatalkan: tidak ada remote cancel/despawn sama sekali,
        -- jadi slotnya tidak bisa dibebaskan paksa.
        --
        -- Karena itu jar hanya dipasang kalau memang ada quest yang memintanya.
        local adaQuestJar, adaQuestComet = false, false
        pcall(function()
            for _, q in ipairs(getAllActiveQuests()) do
                if q.progress < q.amount then
                    if q.type == 37 or q.type == 31 then adaQuestJar = true end
                    if q.type == 38 then adaQuestComet = true end
                end
            end
        end)
        if not adaQuestJar then
            CoinJarStatus.Text = "Jar: tidak ada quest jar, dilewati"
            continue
        end
        -- Comet menang: jar akan mengunci slot sampai kuotanya penuh, sedangkan
        -- comet pecah cepat. Gerbang yang sama juga ada di cabang quest jar.
        if adaQuestComet then
            CoinJarStatus.Text = "Jar: ditunda, comet didahulukan"
            continue
        end

        pcall(function()
            local Map = require(Client:WaitForChild("MapCmds"))
            local IC = require(Client:WaitForChild("InstancingCmds"))

            -- Di dalam instance (maze/lobby) event area tidak berlaku.
            if select(2, pcall(IC.IsInInstance)) == true then
                CoinJarStatus.Text = "Jar: di instance, dilewati"
                return
            end
            if select(2, pcall(Map.IsInDottedBox)) ~= true then
                CoinJarStatus.Text = "Jar: di luar kotak farming"
                return
            end

            local aktif = jarAktif()
            if aktif > 0 then
                CoinJarStatus.Text = string.format("Jar: %d aktif, tunggu selesai", aktif)
                return
            end

            -- Quest jar menuntut "in best area". Memasang di area awal (mis.
            -- tepat sesudah auto-execute) membuat jar menyala tanpa menaikkan
            -- progres, sekaligus membuang slot area.
            if not pastikanDiAreaTerbaik() then
                CoinJarStatus.Text = "Jar: pindah ke area terbaik dulu"
                return
            end

            local berhasil, ket = spawnCoinJar()
            CoinJarStatus.Text = berhasil
                and ("Jar: spawn " .. tostring(ket))
                or ("Jar: " .. tostring(ket))
        end)
    end
end)

-- ==========================================
-- AUTO BUKA FIESTA GIFT
-- ==========================================
-- Membuka gift satu per satu lewat menu itu lama karena server membatasi
-- 8 per panggilan: Library.Types.Lootboxes.MaxOpenAmount = 8. Terukur
-- 2026-08-20 — memasukkan 50 DITOLAK (stok tidak berkurang sama sekali),
-- memasukkan 8 selalu berhasil. Jadi satu-satunya cara mempercepat adalah
-- mengulang panggilan 8-an, bukan memperbesar angkanya.
--
-- Nilai balik remote TIDAK bisa dipercaya: "Lootbox: Open" membalas `false`
-- padahal stok berkurang 8, dan LootboxCmds.Open melempar error di sisi client
-- setelah panggilan server terlanjur jalan. Karena itu keberhasilan diukur
-- dari PERUBAHAN STOK, bukan dari yang dikembalikan.
--
-- AKSI SATU ARAH: gift lenyap dan tidak bisa dikembalikan. Default MATI.
task.spawn(function()
    local NAMA_GIFT = "Fiesta Gift"

    local function stokGift()
        local ok, n = pcall(function()
            local Save = require(Client:WaitForChild("Save"))
            local inv = Save.Get()
            inv = inv and inv.Inventory and inv.Inventory.Lootbox
            if not inv then return 0 end
            local s = 0
            for _, it in pairs(inv) do
                if type(it) == "table" and it.id == NAMA_GIFT then
                    s = s + (tonumber(it._am) or 1)
                end
            end
            return s
        end)
        return ok and n or 0
    end

    local function uidGift()
        local ok, u = pcall(function()
            local Save = require(Client:WaitForChild("Save"))
            local inv = Save.Get()
            inv = inv and inv.Inventory and inv.Inventory.Lootbox
            if not inv then return nil end
            for uid, it in pairs(inv) do
                if type(it) == "table" and it.id == NAMA_GIFT
                    and (tonumber(it._am) or 1) > 0 then
                    return uid
                end
            end
            return nil
        end)
        return ok and u or nil
    end

    while true do
        task.wait(2)
        if Config.autoBukaFiestaGift then
            pcall(function()
                local remote = Network:FindFirstChild("Lootbox: Open")
                if not remote then
                    FiestaGiftStatus.Text = "Gift: remote tidak ada"
                    return
                end

                local sisa = stokGift()
                if sisa <= 0 then
                    FiestaGiftStatus.Text = "Gift: habis"
                    return
                end

                local uid = uidGift()
                if not uid then
                    FiestaGiftStatus.Text = "Gift: uid tidak ketemu"
                    return
                end

                local sebelum = sisa
                pcall(function() remote:InvokeServer(uid, 8) end)
                task.wait(1)
                local sesudah = stokGift()

                if sesudah < sebelum then
                    FiestaGiftStatus.Text = string.format(
                        "Gift: dibuka %d, sisa %d", sebelum - sesudah, sesudah)
                else
                    -- Tidak berkurang = server menolak (animasi masih jalan,
                    -- atau sedang di tempat yang tidak mengizinkan). Beri jeda
                    -- lebih panjang daripada menembak terus tanpa hasil.
                    FiestaGiftStatus.Text = "Gift: ditolak, tunggu (sisa " .. sesudah .. ")"
                    task.wait(5)
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO FIESTA LUCK BOOST — tambah waktu pakai FiestaCoins
-- ==========================================
-- Mesin FiestaLuckMachine menambah DURASI lima boost dengan FiestaCoins:
--     FiestaMachineDamage / KeyLuck / HugeLuck / TitanicLuck / GargLuck
-- Cap-nya 21600 detik (6 jam) per boost -- terukur dari GetMaxBoostSeconds dan
-- cocok dengan teks GUI "Remains active for 6:00:00".
--
-- SENGAJA memakai tombol 1/3, BUKAN MAX. Terukur 2026-08-20: sekali menekan MAX
-- menghabiskan SELURUH FiestaCoins (3,49 juta) dan yang kembali cuma +4 menit
-- 21 detik durasi Titanic. Tanpa cara membaca tarifnya, MAX adalah lubang tanpa
-- dasar; 1/3 membelanjakan bertahap dan bisa dihentikan kapan saja.
--
-- Gerbangnya dibaca dari TEKS GUI, bukan dari API. FiestaLuckMachineCmds
-- terlihat menjanjikan (GetBoostTime, GetUnitsToMax, SpendableCap,
-- GetSecondsPerUnit) tapi KELIMANYA mengembalikan 0 untuk semua boost, di
-- segala bentuk argumen, baik dari jauh maupun dari 4 stud. AddBoost pun
-- ditolak. Yang benar-benar bekerja hanya menekan tombol GUI-nya.
task.spawn(function()
    local BARIS = {
        "DurationDamage", "DurationKey", "DurationHuge",
        "DurationTitanic", "DurationGargantuan",
    }
    local CAP_DETIK = 21600  -- 6 jam

    -- "Remains active for 4:42:23" -> 16943 detik. Teks lain (mis. "You need
    -- Fiesta Coins for ...") tidak cocok pola dan dianggap 0 = belum aktif.
    local function detikDari(teks)
        local j, m, d = string.match(tostring(teks), "(%d+):(%d%d):(%d%d)")
        if not j then return 0 end
        return tonumber(j) * 3600 + tonumber(m) * 60 + tonumber(d)
    end

    local function coinSekarang()
        local ok, n = pcall(function()
            local Save = require(Client:WaitForChild("Save"))
            local d = Save.Get()
            for _, it in pairs(d.Inventory.Currency or {}) do
                if type(it) == "table" and it.id == "FiestaCoins" then
                    return tonumber(it._am) or 0
                end
            end
            -- Entri hilang = saldo nol. Terukur: begitu FiestaCoins habis,
            -- kuncinya benar-benar lenyap dari tabel Currency, bukan jadi 0.
            return 0
        end)
        return ok and n or 0
    end

    local function tekan(b)
        if not b then return end
        pcall(function()
            if firesignal then
                firesignal(b.Activated)
                firesignal(b.MouseButton1Click)
            elseif getconnections then
                for _, c in ipairs(getconnections(b.Activated)) do
                    pcall(function() c:Fire() end)
                end
            end
        end)
    end

    while true do
        task.wait(60)
        if not Config.autoFiestaLuckBoost then continue end

        pcall(function()
            local sisaWajib = tonumber(Config.fiestaCoinSisa) or 0
            local coin = coinSekarang()
            if coin <= sisaWajib then
                LuckBoostStatus.Text = string.format("Luck: coin %d <= sisa %d",
                    coin, sisaWajib)
                return
            end

            local M = LocalPlayer.PlayerGui:FindFirstChild("_MACHINES")
            M = M and M:FindFirstChild("FiestaLuckMachine")
            if not M then
                LuckBoostStatus.Text = "Luck: mesin tidak ada"
                return
            end

            local items = M.Frame:FindFirstChild("ItemsFrame")
            items = items and items:FindFirstChild("Items")
            if not items then return end

            -- GUI harus aktif supaya tombolnya hidup; keadaan semula dipulihkan
            -- supaya tidak mengganggu apa yang sedang dilihat pemain.
            local semula = M.Enabled
            M.Enabled = true
            task.wait(0.4)

            local dikerjakan, dilewati = 0, 0
            for _, nama in ipairs(BARIS) do
                if coinSekarang() <= sisaWajib then break end

                local row = items:FindFirstChild(nama)
                local desc = row and row:FindFirstChild("Desc", true)
                if row and desc then
                    if detikDari(desc.Text) >= CAP_DETIK then
                        dilewati = dilewati + 1   -- sudah 6 jam, jangan buang coin
                    else
                        local sel = row:FindFirstChild("SelectHolder")
                        local q = sel and sel:FindFirstChild("QuickAmounts")
                        tekan(q and q:FindFirstChild("QuickThird"))
                        task.wait(0.6)
                        tekan(sel and sel:FindFirstChild("Purchase"))
                        task.wait(1.2)
                        dikerjakan = dikerjakan + 1
                    end
                end
            end

            M.Enabled = semula
            LuckBoostStatus.Text = string.format("Luck: %d diisi, %d penuh, coin %d",
                dikerjakan, dilewati, coinSekarang())
        end)
    end
end)

-- ==========================================
-- AUTO FIESTA BOOSTER — damage di dalam maze
-- ==========================================
-- Tidak ada "fast clear" sisi client. Sudah diperiksa: FiestaMazeCmds.SetCleared
-- memang ada, tapi ia dipanggil DARI paket server (baris 1331 modul itu) --
-- jadi memanggilnya sendiri cuma mengubah tampilan lokal dan akan ditimpa update
-- berikutnya. Ruangan hanya bersih kalau breakable-nya benar-benar hancur.
--
-- Dan yang menghancurkan itu PET, bukan klik: Breakables_PlayerDealDamage adalah
-- damage klik pemain yang kecil. Jadi satu-satunya pengungkit nyata adalah
-- damage — yaitu booster ini, plus upgrade FiestaDamage/FiestaSmashSpeed.
--
-- Protokol terukur 2026-08-20. ConsumableCmds.Consume menuntut objek
-- ConsumableItem (assert ConsumableItem:IsA), tapi di dalamnya ia hanya
-- memanggil remote di bawah -- jadi uid mentah dari Save cukup:
--     Network.Invoke("Consumables_Consume", uid, jumlah)  ->  true
--     stok T1 106 -> 105
--
-- Tier RENDAH dipakai lebih dulu supaya tier tinggi yang langka tidak terbakar.
-- Sisa durasi booster TIDAK terbaca (BoostCmds.GetPower/GetTimer menolak nama
-- item ini), jadi dipakai jeda waktu tetap -- bukan menebak dari timer.
task.spawn(function()
    local NAMA_BOOSTER = "Fiesta Maze Damage Booster"
    local terakhir = 0

    while true do
        task.wait(15)
        if not Config.autoFiestaBooster then continue end

        pcall(function()
            local IC = require(Client:WaitForChild("InstancingCmds"))
            local diInstance = select(2, pcall(function()
                local i = IC.Get()
                return i and tostring(i.instanceID) or ""
            end))
            -- Hanya berguna di dalam maze; di luar itu cuma membuang stok.
            if diInstance ~= "FiestaMaze" then
                BoosterStatus.Text = "Booster: di luar maze"
                return
            end

            local jeda = (tonumber(Config.boosterJedaMenit) or 10) * 60
            if os.clock() - terakhir < jeda then
                BoosterStatus.Text = string.format("Booster: tunggu %dm",
                    math.ceil((jeda - (os.clock() - terakhir)) / 60))
                return
            end

            local Save = require(Client:WaitForChild("Save"))
            local inv = Save.Get()
            inv = inv and inv.Inventory and inv.Inventory.Consumable
            if not inv then return end

            -- Kumpulkan tier yang ada stoknya, pakai yang terendah dulu.
            local pilihan = {}
            for uid, it in pairs(inv) do
                if type(it) == "table" and it.id == NAMA_BOOSTER
                    and (tonumber(it._am) or 1) > 0 then
                    pilihan[#pilihan + 1] = { uid = uid, tn = tonumber(it.tn) or 99 }
                end
            end
            if #pilihan == 0 then
                BoosterStatus.Text = "Booster: stok habis"
                return
            end
            table.sort(pilihan, function(a, b) return a.tn < b.tn end)

            local Net = require(Client:WaitForChild("Network"))
            local ok, hasil = pcall(function()
                return Net.Invoke("Consumables_Consume", pilihan[1].uid, 1)
            end)
            if ok and hasil == true then
                terakhir = os.clock()
                BoosterStatus.Text = string.format("Booster: dipakai T%d", pilihan[1].tn)
            else
                BoosterStatus.Text = "Booster: ditolak server"
            end
        end)
    end
end)

-- ==========================================
-- AUTO ETERNAL MAZE — pakai jatah harian sebelum hangus
-- ==========================================
-- Eternal maze BUKAN sistem terpisah: begitu masuk, instanceID-nya "FiestaMaze"
-- persis seperti maze biasa, dan EternalMazeLoop.IsEternalRaid() menandainya
-- sebagai raid biasa yang diberi flag. Jadi solver maze yang sudah ada di bawah
-- menangani isinya tanpa perlu diubah — bagian ini cuma mengurus MASUKNYA.
--
-- Terukur 2026-08-20 dengan hook __namecall merekam seluruh FireServer/
-- InvokeServer selama pemain masuk manual: dari 214 panggilan, TIDAK ADA satu
-- pun remote eternal/maze/raid. Yang terdekat cuma "Machines: Mark Approached".
-- Kesimpulannya masuk itu dideteksi SERVER dari sentuhan fisik ke part `Enter`,
-- dan tidak ada remote yang bisa ditiru.
--
-- Karena itu karakter harus benar-benar BERJALAN menembusnya. Menyetel CFrame
-- langsung ke posisi part TIDAK bekerja — sudah diuji dua kali dan gagal:
-- part-nya hanya 0,4 stud tebal, jadi teleport melompatinya di antara dua frame
-- tanpa pernah bersentuhan.
--
-- Keadaan dibaca dari EternalMazeCmds: AttemptsLeft() 3 per hari,
-- CooldownRemaining() 86400 detik, runAllowance 300 detik per run.
task.spawn(function()
    while true do
        task.wait(10)
        if not Config.autoEternalMaze then continue end

        pcall(function()
            local EM = require(Client:WaitForChild("EternalMazeCmds"))
            local IC = require(Client:WaitForChild("InstancingCmds"))

            -- Sedang berlari: biarkan solver maze yang bekerja.
            if select(2, pcall(EM.Running)) == true then
                EternalStatus.Text = string.format("Eternal: berjalan (depth %s)",
                    tostring(select(2, pcall(EM.Depth))))
                return
            end

            local sisa = tonumber(select(2, pcall(EM.AttemptsLeft))) or 0
            if sisa <= 0 then
                EternalStatus.Text = "Eternal: jatah harian habis"
                return
            end

            local cd = tonumber(select(2, pcall(EM.CooldownRemaining))) or 0
            if cd > 0 then
                EternalStatus.Text = string.format("Eternal: cooldown %ds", math.floor(cd))
                return
            end

            -- Mesinnya cuma ada di FiestaLobby.
            local diInstance = select(2, pcall(function()
                local i = IC.Get()
                return i and tostring(i.instanceID) or ""
            end))
            if diInstance ~= "FiestaLobby" then
                EternalStatus.Text = "Eternal: " .. sisa .. " sisa, butuh di FiestaLobby"
                return
            end

            local okM, enter = pcall(function()
                return workspace.__THINGS.__INSTANCE_CONTAINER.Active
                    .FiestaLobby.INTERACT.Machines.EternalMaze.Enter
            end)
            if not okM or not enter then
                EternalStatus.Text = "Eternal: mesin tidak ketemu"
                return
            end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum) then return end

            -- Menyentuh gerbang memunculkan dialog konfirmasi, BUKAN langsung
            -- masuk: "Eternal Maze / Do you want to start an Eternal Maze?"
            -- dengan tombol Yes. Jadi ada dua langkah, dan langkah kedua yang
            -- benar-benar memulai run.
            --
            -- Menempel BENAR-BENAR ke gerbangnya. Berdiri agak mundur tidak
            -- memunculkan dialog sama sekali -- itu sebabnya percobaan pertama
            -- gagal tanpa pesan.
            local function dialogEternal()
                local M = LocalPlayer.PlayerGui:FindFirstChild("Message")
                if not (M and M.Enabled) then return nil end
                local judul = M:FindFirstChild("Frame")
                judul = judul and judul:FindFirstChild("Top")
                judul = judul and judul:FindFirstChild("Title")
                -- Judul WAJIB dicocokkan. `Message` itu dialog generik yang
                -- dipakai seluruh game; menekan Yes tanpa memeriksa judul bisa
                -- mengiyakan konfirmasi lain yang merugikan dan tidak bisa
                -- dibatalkan.
                if not (judul and tostring(judul.Text) == "Eternal Maze") then return nil end
                local isi = M.Frame:FindFirstChild("Contents")
                local yes = isi and isi:FindFirstChild("Yes")
                if yes and yes:IsA("GuiButton") and yes.Visible then return yes end
                return nil
            end

            local masuk = false
            for _ = 1, 3 do
                if select(2, pcall(EM.Running)) == true then masuk = true break end

                -- Tempel ke gerbang: mundur sedikit lalu jalan menembusnya.
                local depan = enter.Position - enter.CFrame.LookVector * 6
                hrp.CFrame = CFrame.new(depan.X, hrp.Position.Y, depan.Z)
                task.wait(0.4)
                hum:MoveTo(Vector3.new(enter.Position.X, hrp.Position.Y, enter.Position.Z))
                task.wait(2.5)

                -- Tunggu dialognya muncul, lalu tekan Yes.
                for _ = 1, 10 do
                    local yes = dialogEternal()
                    if yes then
                        -- Sinyal GUI Roblox TIDAK bisa di-:Fire() dari Lua biasa.
                        -- Yang bekerja: firesignal, atau menyalakan tiap koneksi
                        -- lewat getconnections. Keduanya fungsi executor, jadi
                        -- dicoba berurutan dan dibungkus pcall.
                        pcall(function()
                            local fs = firesignal
                            local gc = getconnections
                            for _, nama in ipairs({ "Activated", "MouseButton1Click" }) do
                                local ev = yes[nama]
                                if ev then
                                    if fs then
                                        fs(ev)
                                    elseif gc then
                                        for _, c in ipairs(gc(ev)) do
                                            pcall(function() c:Fire() end)
                                        end
                                    end
                                end
                            end
                        end)
                        task.wait(2)
                        break
                    end
                    task.wait(0.4)
                end

                if select(2, pcall(EM.Running)) == true then masuk = true break end
            end

            EternalStatus.Text = masuk
                and ("Eternal: masuk, sisa " .. math.max(0, sisa - 1))
                or ("Eternal: gagal masuk (sisa " .. sisa .. ")")
        end)
    end
end)

-- ==========================================
-- AUTO MAZE — pindah sel saat breakable habis
-- ==========================================
-- Struktur maze terbaca dari FiestaMazeCmds.Get():
--   built   = {[sel] = "Room1", [sel] = "Room2", ...}  sel yang sudah dibangun
--   cleared = {[sel] = true}                            sel yang sudah dibereskan
--   rooms   = "Rooms"                                   nama folder model room
-- Terukur di maze nyata: satu sel isinya ~5 breakable, dan room bertetangga
-- berjarak 64 stud (Room1 x=-524, Room2 x=-460).
local function mazeRoomBerikutnya()
    local ok, model, jarak = pcall(function()
        local FM = require(Client:WaitForChild("FiestaMazeCmds"))
        local g = FM.Get()
        if type(g) ~= "table" or type(g.built) ~= "table" then return nil end

        -- g.rooms itu INSTANCE folder-nya langsung, bukan nama.
        -- tostring(g.rooms) kebetulan menghasilkan "Rooms" sehingga mudah
        -- disangka string; FindFirstChild(userdata) diam-diam mengembalikan nil
        -- dan seluruh auto maze tidak pernah menemukan sel berikutnya.
        local rooms
        if typeof(g.rooms) == "Instance" then
            rooms = g.rooms
        else
            local akt = Workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active")
            local maze = akt and akt:FindFirstChild("FiestaMaze")
            rooms = maze and maze:FindFirstChild(tostring(g.rooms or "Rooms"))
        end
        if not rooms then return nil end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        local cleared = g.cleared or {}
        local terbaik, terdekat = nil, nil
        for sel, namaRoom in pairs(g.built) do
            -- Sel yang sudah cleared dilewati; itulah tanda "kotak ini habis".
            if not cleared[sel] then
                local m = rooms:FindFirstChild(tostring(namaRoom))
                if m and (m:IsA("Model") or m:IsA("BasePart")) then
                    local d = (m:GetPivot().Position - hrp.Position).Magnitude
                    if not terdekat or d < terdekat then terbaik, terdekat = m, d end
                end
            end
        end
        return terbaik, terdekat
    end)
    if not ok then return nil end
    return model, jarak
end

task.spawn(function()
    while true do
        -- 0,35 detik, bukan 2. Jeda 2 detik terasa jelas sebagai "diam dulu"
        -- tiap kali sel selesai dibersihkan — dan dengan siklus maze yang
        -- puluhan sel, itu menumpuk jadi menit-menit terbuang.
        -- Isi loop-nya murni pembacaan tabel + satu CFrame, jadi murah.
        task.wait(0.35)

        if not (Config.autoMaze and modeLucky()) then continue end

        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            -- Hanya bekerja DI DALAM maze.
            --
            -- Tanpa ini ia ikut jalan di FiestaLobby dan menulis
            -- "36 breakable, garap dulu" tiap 2 detik — menimpa status loop
            -- pembuatan maze yang justru sedang melapor kenapa gagal.
            local diMaze = select(2, pcall(function()
                local IC2 = require(Client:WaitForChild("InstancingCmds"))
                local i = IC2.Get()
                return i and tostring(i.instanceID) or ""
            end))
            if diMaze ~= "FiestaMaze" then return end

            -- Masih ada yang bisa dipukul di sel ini? Jangan pindah dulu.
            -- Dipakai jangkauan yang sama dengan serangan, supaya "habis"
            -- berarti benar-benar tidak ada lagi yang terjangkau.
            local sisa = 0
            for _, b in ipairs(Breakables:GetChildren()) do
                if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name)
                    and (b:GetPivot().Position - hrp.Position).Magnitude < jangkauanSerang() then
                    sisa = sisa + 1
                end
            end
            if sisa > 0 then
                MazeStatus.Text = string.format("Maze: %d breakable, garap dulu", sisa)
                return
            end

            -- BOSS DITUNDA sampai seluruh room habis.
            --
            -- Membunuh boss MENGAKHIRI run, sementara hadiah terus bertambah
            -- selama room belum mentok — jadi menyerbunya di room 5/19 membuang
            -- sisa run yang masih bisa dipanen. Selama belum mentok, alur jatuh
            -- ke pemilihan sel di bawah dan terus membersihkan kotak.
            if not mazeSiapBoss() then
                local sisaSel = mazeRoomBerikutnya()
                if not sisaSel then
                    -- Tidak ada sel tersisa padahal room belum mentok: tidak ada
                    -- lagi yang bisa dikerjakan selain boss. Lepaskan penundaan
                    -- daripada berdiri diam selamanya.
                    MazeStatus.Text = "Maze: sel habis sebelum room mentok — boss dilepas"
                else
                    MazeStatus.Text = "Maze: room belum mentok, bersihkan sel dulu"
                    -- lanjut ke blok pemilihan sel di bawah
                end
            end

            -- Boss punya breakable sendiri (tiap room Boss1/2/3 berisi folder
            -- BREAK_ZONES). Kalau ada boss di dunia tapi di luar jangkauan
            -- serang, hampiri — tap dan pet sama-sama butuh ia masuk radius.
            local BF = require(Client:WaitForChild("BreakableFrontend"))
            local bossModel, bossJarak = nil, nil
            for _, b in ipairs(Breakables:GetChildren()) do
                if (b:IsA("Model") or b:IsA("Part")) and tonumber(b.Name) then
                    local okD, d = pcall(BF.Get, b.Name)
                    if okD and type(d) == "table" then
                        local teks = (tostring(d.id or "") .. " " .. tostring(d.class or "")):lower()
                        if string.find(teks, "boss", 1, true) then
                            local jr = (b:GetPivot().Position - hrp.Position).Magnitude
                            if not bossJarak or jr < bossJarak then bossModel, bossJarak = b, jr end
                        end
                    end
                end
            end
            -- Hanya digarap kalau room sudah mentok, ATAU tidak ada sel tersisa.
            if bossModel and (mazeSiapBoss() or not mazeRoomBerikutnya()) then
                if bossJarak > jangkauanSerang() * 0.6 then
                    hrp.CFrame = CFrame.new(bossModel:GetPivot().Position + Vector3.new(0, 5, 12))
                    MazeStatus.Text = string.format("Maze: hampiri BOSS (%.0f stud)", bossJarak)
                else
                    MazeStatus.Text = string.format("Maze: gempur BOSS (%.0f stud)", bossJarak)
                end
                return
            end

            -- KEJAR BOSS: arahkan ke sel boss terdekat menurut jumlah langkah di
            -- pohon maze, bukan jarak stud. Sel terdekat secara fisik sering
            -- justru cabang buntu yang menjauhkan dari boss.
            local room, jarak
            if Config.mazeKejarBoss then
                local target, langkah, selBoss, selTarget = mazeSasaranBoss()
                if target then
                    local d = (target:GetPivot().Position - hrp.Position).Magnitude

                    -- SUDAH BERADA di sel tujuan dan tidak ada apa-apa lagi di
                    -- sini: jangan berhenti di situ.
                    --
                    -- Terukur saat macet: sel 100 adalah sel boss, sudah
                    -- built+cleared, jarak 3 stud, 0 breakable dalam radius
                    -- fokus — tapi boss BELUM spawn. Jalur boss menunjuk room
                    -- yang sedang ditempati, jaraknya < 25, lalu loop menulis
                    -- "menunggu isi sel" dan diam selamanya, sementara 13
                    -- breakable di sel lain diabaikan.
                    --
                    -- Boss baru muncul setelah run maju cukup jauh, jadi selama
                    -- ia belum ada, jalan yang benar adalah membereskan sel lain
                    -- supaya progres berlanjut.
                    if d < 25 then
                        -- Sudah di sel tujuan. Cari sel lain yang MASIH DI JALUR
                        -- boss — jangan melompat ke cabang buntu yang tidak
                        -- menambah kemajuan sama sekali.
                        local lainJalur, selLain = mazeSelBerikutnyaDiJalur()
                        if lainJalur and lainJalur ~= target then
                            room = lainJalur
                            jarak = (lainJalur:GetPivot().Position - hrp.Position).Magnitude
                            MazeStatus.Text = string.format("Maze: lanjut jalur boss, sel %s", tostring(selLain))
                        else
                            MazeStatus.Text = string.format("Maze: sel %s bersih, tunggu jalur ke boss %s terbuka",
                                tostring(selTarget), tostring(selBoss))
                        end
                    else
                        room = target
                        jarak = d
                        MazeStatus.Text = string.format("Maze: kejar boss %s via sel %s (%d langkah)",
                            tostring(selBoss), tostring(selTarget), tonumber(langkah) or -1)
                    end
                end
            end

            -- Cadangan. Saat mode kejar boss aktif, cadangannya pun WAJIB tetap
            -- di jalur boss; mazeRoomBerikutnya() yang bebas-arah hanya dipakai
            -- kalau data jalur benar-benar tidak terbaca (graph belum siap).
            if not room and Config.mazeKejarBoss then
                room = mazeSelBerikutnyaDiJalur()
                if room then jarak = (room:GetPivot().Position - hrp.Position).Magnitude end
            end
            if not room then
                room, jarak = mazeRoomBerikutnya()
            end

            if not room then
                MazeStatus.Text = "Maze: tidak ada sel terbuka berikutnya"
                return
            end

            -- Sudah berdiri di sel itu dan tidak ada isinya: JANGAN berhenti.
            --
            -- Dulu di sini loop menulis "menunggu isi sel" lalu return, dan itu
            -- jadi titik macet — sel yang sudah cleared tidak akan pernah terisi
            -- lagi, jadi menunggu berarti menunggu selamanya. Sekarang sel ini
            -- dicoret dan pilihan berikutnya diambil pada siklus 0,35 detik
            -- berikutnya.
            if jarak and jarak < 25 then
                local lain = Config.mazeKejarBoss and mazeSelBerikutnyaDiJalur() or mazeRoomBerikutnya()
                if lain and lain ~= room then
                    room = lain
                    jarak = (lain:GetPivot().Position - hrp.Position).Magnitude
                else
                    MazeStatus.Text = string.format("Maze: di %s, tidak ada sel lain di jalur", room.Name)
                    return
                end
            end

            -- CFrame, bukan MoveTo: maze berdinding dan MoveTo bukan pathfinding —
            -- karakter akan menempel di tembok pemisah sel.
            local tujuan = room:GetPivot().Position
            hrp.CFrame = CFrame.new(tujuan + Vector3.new(0, 5, 0))
            MazeStatus.Text = string.format("Maze: pindah ke %s (%.0f stud)", room.Name, jarak or -1)
        end)
    end
end)

-- ==========================================
-- AUTO BUAT MAZE — masuk lewat portal sendiri
-- ==========================================
-- Bentuk pemanggilannya dijiplak dari script game sendiri
-- (PlayerScripts.Scripts.Game."Auto Raid"), bukan dikarang:
--
--   RaidCmds.Create({ Portal = <nomor>, Difficulty = <angka>, PartyMode = <enum> })
--
-- Nilai terukur di akun ini: GetDifficultyLevel() = 897 (tier maksimum yang
-- diizinkan level Fiesta), PartyMode.Solo = 1, PartyMode.Open = 4.
-- Portal dianggap kosong kalau ClientRaidInstance.GetByPortal(n) mengembalikan nil.
task.spawn(function()
    while true do
        task.wait(5)

        if not (Config.autoBuatMaze and modeLucky()) then continue end

        pcall(function()
            local RaidCmds = require(Client:WaitForChild("RaidCmds"))
            local InstancingCmds = require(Client:WaitForChild("InstancingCmds"))

            -- Sudah punya raid berjalan: jangan bikin lagi.
            if select(2, pcall(RaidCmds.GetCurrent)) then return end

            -- JANGAN memblokir hanya karena "sedang di dalam instance".
            --
            -- FiestaLobby ITU SENDIRI sebuah instance, dan justru di lobby itulah
            -- portal maze berada — terukur: IsInInstance()=true saat berdiri di
            -- FiestaLobby dengan 10 portal sejauh ~100 stud. Syarat lama menolak
            -- tepat di satu-satunya tempat pembuatan maze bisa dilakukan, jadi
            -- tidak pernah terjadi apa-apa dan tanpa pesan apa pun.
            --
            -- Yang benar-benar harus dihindari cuma: sudah berada DI DALAM maze.
            local diInstance = select(2, pcall(function()
                local i = InstancingCmds.Get()
                return i and tostring(i.instanceID) or ""
            end))
            if diInstance == "FiestaMaze" then return end

            local CRI = require(Client.RaidCmds:WaitForChild("ClientRaidInstance"))
            local portal
            for i = 1, 12 do
                local okP, dipakai = pcall(CRI.GetByPortal, i)
                if okP and not dipakai then portal = i break end
            end
            if not portal then
                MazeStatus.Text = "Maze: semua portal terpakai"
                return
            end

            -- Tier: MAX (bawaan) atau MIN/tier 1 untuk farm orb.
            --
            -- Batas bawahnya 1, dibaca dari Util.FiestaRaidLevel:
            --   DifficultyCap  -> math.max(1, ...)
            --   MinDifficulty  -> math.clamp(..., 1, ...)  dan `if p13 <= 0 then return 1`
            -- jadi 1 memang lantai yang sah, bukan angka karangan.
            local diff
            if Config.mazeTierMax == false then
                diff = 1 -- MIN / farm orb
            else
                local okD, cap = pcall(RaidCmds.GetDifficultyLevel)
                if not okD or type(cap) ~= "number" then
                    MazeStatus.Text = "Maze: tier tidak terbaca"
                    return
                end
                diff = cap
            end

            local Raids = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Types"):WaitForChild("Raids"))
            local mode = Config.mazeSolo and Raids.PartyMode.Solo or Raids.PartyMode.Open

            -- Create mengembalikan TIGA nilai: (ok, pesan, instanceRaid).
            -- Nilai ketiga itu yang dipakai untuk masuk — membuat saja tidak
            -- memindahkan pemain ke mana pun. Terukur: setelah Create berhasil,
            -- pemain tetap di FiestaLobby dan GetCurrent() masih nil sampai
            -- raid:Join() dipanggil.
            local okC, berhasil, pesan, raidBaru = pcall(RaidCmds.Create, {
                Portal = portal,
                Difficulty = diff,
                PartyMode = mode,
            })
            if not (okC and berhasil) then
                MazeStatus.Text = "Maze: gagal buat — " .. tostring(pesan or berhasil)
                return
            end
            if not raidBaru then
                MazeStatus.Text = "Maze: dibuat tapi instance-nya kosong"
                return
            end

            local okJ = pcall(raidBaru.Join, raidBaru)
            MazeStatus.Text = okJ
                and string.format("Maze: masuk! portal %d, tier %d (%s), %s",
                    portal, diff, (Config.mazeTierMax == false) and "MIN/orb" or "MAX",
                    Config.mazeSolo and "Solo" or "Open")
                or string.format("Maze: dibuat portal %d tapi gagal masuk", portal)
        end)
    end
end)

-- ==========================================
-- AUTO PUNGUT REWARD PRIZE ROOM
-- ==========================================
-- Setelah boss pecah, prize room berisi peti (terukur: LeprechaunChest,
-- LootChest, TitanicChest, HugeChest — semuanya 47-54 stud dari titik mendarat).
--
-- TIDAK perlu berjalan ke tiap peti, dan tidak perlu menekan E: game sendiri
-- memungutnya lewat satu remote per peti. Dijiplak dari
-- PlayerScripts.Scripts.Game."Auto Raid":
--
--   for i, v in pairs(Raids.ChestDirectory) do
--       if not v.Retired then Network.Invoke("Raids_CollectReward", i, raid._ct) end
--   end
--
-- `_ct` adalah token raid dari ClientRaidInstance.GetCurrent() (terukur:
-- "c611873c545d4747a64e24ee9e741224"). Entri ber-Retired WAJIB dilewati —
-- Tier1000Chest sudah pensiun dan hanya menghasilkan penolakan.
local rewardTerakhir = ""
task.spawn(function()
    while true do
        task.wait(3)
        if not (Config.autoClaimRewardMaze and modeLucky()) then continue end

        pcall(function()
            local Raids = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Types"):WaitForChild("Raids"))
            local CRI = require(Client:WaitForChild("RaidCmds"):WaitForChild("ClientRaidInstance"))
            local Net = require(Client:WaitForChild("Network"))

            local raid = select(2, pcall(CRI.GetCurrent))
            if type(raid) ~= "table" or not raid._ct then return end

            -- GERBANG UTAMA: PETI HARUS SUDAH MUNCUL.
            --
            -- `_completed` / `IsComplete()` TIDAK cukup — itu menandai 19 room
            -- selesai, bukan boss mati. Dengan gerbang itu bot keluar saat room
            -- habis padahal boss belum disentuh, persis yang dilaporkan.
            --
            -- Sinyal yang benar adalah `_chests`. Terukur di tengah run:
            -- `_chests (0)` kosong sementara `_chestModels (4)` sudah ada, dan
            -- OpenChest menolak dengan "This chest isn't spawned!" kalau
            -- `_chests[id]` belum ada. Jadi `_chests` baru terisi ketika peti
            -- benar-benar muncul — yaitu setelah boss pecah dan prize room
            -- terbuka. Itulah satu-satunya penanda hadiah siap dipungut.
            --
            -- Gerbang ini menjaga DUA hal sekaligus:
            --   1. Tidak keluar sebelum boss beres.
            --   2. Klaim tidak dijalankan (lalu ditandai selesai) terlalu dini —
            --      kalau itu terjadi, hadiah run tersebut hangus tanpa jejak.
            local adaPeti = false
            local jumlahPeti = 0
            for _ in pairs(raid._chests or {}) do
                adaPeti = true
                jumlahPeti = jumlahPeti + 1
            end

            -- SYARAT KEDUA: semua boss harus Completed.
            --
            -- Dulu gerbangnya HANYA `adaPeti`, dengan asumsi peti baru muncul
            -- setelah boss terakhir pecah. Asumsi itu benar saat maze cuma punya
            -- SATU boss. Sejak tier tinggi, satu maze bisa punya 3 boss
            -- (layout.config.bossFractions = 0.34 / 0.67 / 1), dan asumsinya
            -- tidak lagi bisa dipegang -- dilaporkan keluar setelah 2 boss.
            --
            -- `raid._bosses[*].Completed` adalah penanda resmi game dan sudah
            -- dibaca di sini untuk pesan status; ia cuma tidak pernah dijadikan
            -- syarat. Sekarang dijadikan syarat, jadi berapa pun jumlah boss-nya
            -- script tidak bisa keluar lebih awal.
            --
            -- Klaim ikut ditahan, bukan cuma keluarnya: kalau peti muncul
            -- bertahap, mengklaim di tengah lalu menandai run selesai membuat
            -- hadiah boss berikutnya hangus.
            local bossBelum, bossTotal = 0, 0
            for _, b in pairs(raid._bosses or {}) do
                bossTotal = bossTotal + 1
                if type(b) == "table" and not b.Completed then bossBelum = bossBelum + 1 end
            end

            if not adaPeti or bossBelum > 0 then
                MazeStatus.Text = string.format("Maze: room %s/%s, boss %d/%d beres, peti %d",
                    tostring(raid._roomNumber or "?"), tostring(raid._maxRoomNumber or "?"),
                    bossTotal - bossBelum, bossTotal, jumlahPeti)
                return
            end

            local tanda = tostring(raid._ct)

            -- Sudah diklaim untuk raid ini: JANGAN return di sini.
            --
            -- Dulu barisnya `if rewardTerakhir == tanda then return end`, dan
            -- itu memotong jalan SEBELUM blok keluar di bawah. Akibatnya kalau
            -- keluar sempat gagal sekali, ia tidak pernah dicoba lagi — bot
            -- tersangkut selamanya di maze yang sudah _completed sambil memukuli
            -- breakable sisa. Terlihat nyata di lapangan.
            --
            -- Sekarang klaim dilewati, tapi alur tetap turun ke blok keluar.
            local dapat, coba = 0, 0
            if rewardTerakhir ~= tanda then
                for id, info in pairs(Raids.ChestDirectory or {}) do
                    if not (type(info) == "table" and info.Retired) then
                        coba = coba + 1
                        local ok, berhasil = pcall(Net.Invoke, "Raids_CollectReward", id, raid._ct)
                        if ok and berhasil then dapat = dapat + 1 end
                        task.wait(0.25)
                    end
                end
                -- Ditandai walau `dapat` nol: nol berarti peti memang sudah
                -- habis diklaim (server menjawab false untuk yang sudah diambil),
                -- bukan berarti gagal. Menandainya mencegah loop menembak ulang
                -- keempat peti tiap 3 detik tanpa guna.
                rewardTerakhir = tanda
                MazeStatus.Text = string.format("Maze: claim %d/%d peti (%d spawn)", dapat, coba, jumlahPeti)
            end

            -- Keluar setelah reward diambil, supaya siklus bisa berulang.
            --
            -- Syaratnya BUKAN lagi `dapat > 0`, melainkan "raid ini sudah selesai
            -- DAN klaimnya sudah dijalankan". Versi lama menempelkan keluar pada
            -- keberhasilan klaim di siklus yang sama; begitu klaim sudah pernah
            -- jalan, siklus berikutnya keluar lebih awal dan keluar-otomatis
            -- tidak pernah dicoba lagi — bot tersangkut di maze _completed sambil
            -- memukuli breakable sisa.
            --
            -- Dialog "are you sure you want to leave" itu konfirmasi sisi klien;
            -- InstancingCmds.Leave() menempuh jalur yang sama dengan menekan Yes.
            -- LeaveViaExit TIDAK dipakai: bawaannya mencari part "LeavePart",
            -- sedangkan prize room memakai "TeleportPart".
            -- Sampai di sini raid sudah pasti selesai (dijaga gerbang di atas),
            -- jadi syaratnya cukup: klaim untuk raid ini sudah dijalankan.
            if Config.autoKeluarMaze and rewardTerakhir == tanda then
                task.wait(1.5) -- beri jeda supaya klaim tercatat server dulu

                -- Leave() HARUS dijalankan di identitas thread 2 (script biasa).
                --
                -- Di identitas tinggi ia meledak dengan "Cannot require a
                -- non-RobloxScript module from a RobloxScript" — terukur: pada
                -- identitas 8 gagal, pada identitas 2 berhasil dan inInstance
                -- berubah true -> false. Executor umumnya berjalan di 8, jadi
                -- tanpa penurunan ini keluar-otomatis tidak akan pernah jalan.
                --
                -- Ini kebalikan dari blackscreen, yang justru butuh identitas 8
                -- untuk menulis ke gethui(). Keduanya benar di konteksnya
                -- masing-masing; jangan disamakan.
                local identitasAsli = getthreadidentity and getthreadidentity() or nil
                local setId = setthreadidentity or (syn and syn.set_thread_identity) or setidentity
                pcall(function()
                    if setId then setId(2) end
                    require(Client:WaitForChild("InstancingCmds")).Leave()
                end)
                -- Dikembalikan apa pun hasilnya: sisa loop lain di script ini
                -- (mis. blackscreen) masih mengandalkan identitas semula.
                pcall(function()
                    if setId and identitasAsli then setId(identitasAsli) end
                end)

                MazeStatus.Text = "Maze: reward beres, keluar — siap ulang"
            end
        end)
    end
end)

-- ==========================================
-- AUTO FIESTA UPGRADE + PINATA BOSS
-- ==========================================
-- Upgrade dibeli menurut prioritas dan berhenti pada keberhasilan PERTAMA tiap
-- siklus, supaya FiestaCoins mengalir ke prioritas tertinggi dulu, bukan
-- terpecah rata.
-- Server menolak dengan bersih (`false, "You can't afford this!"`) kalau kurang,
-- jadi mencoba berulang tidak berbahaya.
-- Urutan: damage -> smash -> equip(pet). Boss key TIDAK ikut di sini.
-- Terukur 2026-08-20: Directory.EventUpgrades memuat 138 upgrade, dan yang
-- berawalan "Fiesta" ada 14 -- BUKAN 3. Daftar lama cuma tahu tiga, jadi
-- sepuluh upgrade lain tidak pernah dibeli sekali pun walau FiestaCoins
-- menumpuk. Tier saat diukur:
--     FiestaPets 46 · FiestaDamage 27 · FiestaSmashSpeed 26 · FiestaKeyDrops 13
--     SEMUA sisanya tier 0.
--
-- Yang disebut lebih dulu dibeli lebih dulu; sisanya diisi OTOMATIS dari
-- Directory, supaya upgrade baru yang ditambahkan game ikut terbeli tanpa
-- perlu menyunting script lagi.
local FIESTA_PRIORITAS_INTI = {
    "FiestaDamage",           -- damage naik = semua hal lain ikut cepat
    "FiestaMoreCurrency",     -- lebih banyak coin = upgrade lain lebih cepat
    "FiestaSmashSpeed",
    "FiestaPets",
    "FiestaBetterLoot",
    "FiestaBossDamage",
    "FiestaXP",
    "FiestaPetSpeed",
    "FiestaEggCost",
    "FiestaHugeChest",
    "FiestaTitanicChest",
    "FiestaBossHugeChances",
    "FiestaBossTitanicChances",
}

-- Gabungkan inti + apa pun ber-awalan "Fiesta" yang belum tersebut.
local FIESTA_PRIORITAS = (function()
    local urut, sudah = {}, {}
    for _, id in ipairs(FIESTA_PRIORITAS_INTI) do
        urut[#urut + 1] = id
        sudah[id] = true
    end
    pcall(function()
        local D = require(ReplicatedStorage.Library.Directory.EventUpgrades)
        local tambahan = {}
        for id, d in pairs(D) do
            if type(d) == "table" and type(id) == "string"
                and string.sub(id, 1, 6) == "Fiesta"
                and not sudah[id] and id ~= "FiestaKeyDrops" then
                tambahan[#tambahan + 1] = id
            end
        end
        table.sort(tambahan)  -- urutan pairs tidak terdefinisi; jangan acak
        for _, id in ipairs(tambahan) do urut[#urut + 1] = id end
    end)
    return urut
end)()

-- Boss key disendirikan: baru dibeli kalau ketiga di atas tidak bisa dibeli lagi.
--
-- Tidak ada API batas tier yang terekspos, jadi "sudah max" tidak bisa
-- ditanyakan langsung. Yang dipakai: kalau tiga upgrade utama sama-sama menolak
-- dalam satu siklus, coin dialihkan ke boss key. Kalau penolakannya karena
-- coin kurang (bukan karena max), boss key ikut menolak dan tidak ada yang
-- terbuang — jadi aman tanpa perlu tahu batasnya.
local FIESTA_CADANGAN = "FiestaKeyDrops"


task.spawn(function()
    while true do
        task.wait(15)

        if Config.autoFiestaUpgrade then
            pcall(function()
                local EU = require(Client:WaitForChild("EventUpgradeCmds"))
                local terbeli = nil

                for _, nama in ipairs(FIESTA_PRIORITAS) do
                    local ok, berhasil = pcall(EU.Purchase, nama)
                    if ok and berhasil == true then
                        terbeli = nama
                        break -- satu pembelian per siklus
                    end
                end

                -- Ketiganya menolak: entah sudah max, entah coin kurang.
                -- Dua-duanya aman dialihkan ke boss key — kalau ternyata coin
                -- yang kurang, boss key ikut menolak dan tidak ada yang hilang.
                if not terbeli then
                    local ok, berhasil = pcall(EU.Purchase, FIESTA_CADANGAN)
                    if ok and berhasil == true then terbeli = FIESTA_CADANGAN end
                end

                if terbeli then
                    local tier = select(2, pcall(EU.GetTier, terbeli))
                    FiestaStatus.Text = string.format("Upgrade: %s -> tier %s (%d dipantau)",
                        terbeli, tostring(tier), #FIESTA_PRIORITAS)
                end
            end)
        end

        -- Pinata Boss: harus berdiri di Pad-nya, dan berbayar FiestaCoins.
        if Config.autoPinataBoss then
            pcall(function()
                local akt = Workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active")
                local lobby = akt and akt:FindFirstChild("FiestaLobby")
                local mesin = lobby and lobby:FindFirstChild("INTERACT")
                local pin = mesin and mesin:FindFirstChild("Machines")
                pin = pin and pin:FindFirstChild("ChallengePinata")
                if not pin then
                    FiestaStatus.Text = "Pinata: tidak ada di tempat ini"
                    return
                end

                local pad = pin:FindFirstChild("Pad")
                local titik = pad and pad.Position or pin:GetPivot().Position
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local kembali = hrp.CFrame
                if (hrp.Position - titik).Magnitude > 8 then
                    hrp.CFrame = CFrame.new(titik + Vector3.new(0, 5, 0))
                    task.wait(2)
                end

                local remote = Network:FindFirstChild("PinataChallenge: Start")
                if not remote then return end
                local ok, berhasil, pesan = pcall(function() return remote:InvokeServer() end)
                FiestaStatus.Text = (ok and berhasil == true)
                    and "Pinata: challenge dimulai!"
                    or ("Pinata: " .. tostring(pesan or "ditolak"))

                -- Gagal (biasanya coin kurang) = jangan tinggalkan karakter
                -- nangkring di pad, kembalikan ke tempat semula.
                if not (ok and berhasil == true) then
                    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if h then h.CFrame = kembali end
                end
            end)
        end
    end
end)

-- ==========================================
-- BYPASS PROMPT "Click to open!"
-- ==========================================
-- Animasi buka telur memunculkan frame TapToOpen yang menunggu klik dan tidak
-- hilang sendiri, sehingga hatch berikutnya tertahan. Game menutupnya lewat
-- Mouse.Button1Down (atau tombol A/X gamepad) — terbaca di
-- PlayerScripts.Scripts.Game."Egg Opening Frontend" baris 1554.
-- Klik virtual terverifikasi membubarkannya (hilang pada klik ke-3).
task.spawn(function()
    local VIM = game:GetService("VirtualInputManager")
    while true do
        task.wait(0.4)
        if Config.bypassKlikBukaEgg then
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                local gui = pg and pg:FindFirstChild("EggOpenAnimation")
                if not gui or not gui.Enabled then return end
                -- Hanya klik saat prompt-nya benar-benar ada, jangan menembaki
                -- layar terus-menerus.
                if not gui:FindFirstChild("TapToOpen", true) then return end

                local cam = Workspace.CurrentCamera
                if not cam then return end
                local x, y = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
                VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
                task.wait(0.03)
                VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end)
        end
    end
end)

-- ==========================================
-- AUTO ULTIMATE
-- ==========================================
-- Pakai UltimateCmds.Activate, jangan panggil remote mentah.
--
-- Versi lama mengirim `Save.Get().EquippedUltimate` — itu UID simpanan
-- (contoh terukur: "ef9d0c54582e4442901596a11191b6ba"), bukan id yang diminta
-- server. Remote "Ultimates: Activate" mau `_id` hasil IdToDirectoryType, yang
-- didapat dari `EquippedUltimateId` (contoh: "Ground Pound"). Terbukti di client:
-- dengan charge penuh, cara lama dijawab false, cara ini dijawab true dan
-- charge langsung turun 1 -> 0.
task.spawn(function()
    while true do
        task.wait(2) -- server yang menolak kalau belum penuh, tidak perlu timer sendiri
        if Config.autoUltimate then
            pcall(function()
                local Save = require(Client:WaitForChild("Save"))
                local UltimateCmds = require(Client:WaitForChild("UltimateCmds"))
                local data = Save.Get()
                if not data then return end

                local ultId = data.EquippedUltimateId
                if not ultId then return end -- tidak ada ultimate ter-equip

                -- Cek charge dulu supaya tidak menghujani server dengan invoke
                -- yang pasti ditolak setiap 2 detik.
                if UltimateCmds.IsCharged(ultId) and not UltimateCmds.IsActive(ultId) then
                    UltimateCmds.Activate(ultId)
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO ZONE QUEST LOOP
-- ==========================================
task.spawn(function()
    local zonaDipegang = nil -- area yang sedang digarap; nil = perlu teleport

    while true do
        task.wait(Config.zoneQuestDelay)

        -- Zone quest bekerja dengan teleport antar area — mustahil digabung
        -- dengan mode diam di maze.
        if modeLucky() then
            if zoneQuestBusy then zoneQuestBusy = false end
            ZQStatus.Text = "Status: nonaktif (mode Maze)"
            continue
        end

        if not Config.autoZoneQuest then
            if zoneQuestBusy then
                zoneQuestBusy = false
                zonaDipegang = nil
            end
            -- Status ditulis tiap siklus, bukan cuma saat baru dimatikan.
            -- Kalau tidak, saat start dengan toggle mati labelnya tidak pernah
            -- disentuh dan berhenti di teks bawaan "Menunggu..." — terlihat
            -- seperti fiturnya menggantung padahal memang belum dinyalakan.
            local mati = "Status: OFF — tekan tombol untuk mulai"
            if ZQStatus.Text ~= mati then ZQStatus.Text = mati end
            continue
        end

        pcall(function()
            local w, namaZone = targetBerikutnya()

            if not namaZone then
                zoneQuestBusy = false
                zonaDipegang = nil
                ZQStatus.Text = "Status: Semua world selesai ✓"
                return
            end

            -- Kunci dipasang sebelum teleport, bukan sesudah. Auto world jalan
            -- tiap 5 detik dan akan menarik balik ke zone terakhir yang dimiliki
            -- kalau sempat menyela di tengah perpindahan.
            zoneQuestBusy = true

            if zonaDipegang ~= namaZone then
                -- Cek posisi dulu. Teleport ke zone yang sedang ditempati bisa
                -- dijawab false oleh server, dan tanpa cek ini area tempat kita
                -- berdiri malah ditandai "tak bisa masuk" lalu dilewati.
                local sudahDiSini = false
                pcall(function()
                    sudahDiSini = require(Client:WaitForChild("MapCmds")).GetCurrentZone() == namaZone
                end)

                if sudahDiSini or teleportKeZone(namaZone) then
                    zonaDipegang = namaZone
                    ZQStatus.Text = string.format("W%d · %s: masuk area...", w, namaZone)
                    task.wait(1.5) -- tunggu area load + save tersinkron
                else
                    -- Gagal teleport = area belum dimiliki. Tandai lolos supaya
                    -- antrian tidak macet selamanya di area yang tak bisa dimasuki.
                    setZonaLolos(namaZone, ZQ_VERIFIKASI_MIN)
                    ZQStatus.Text = string.format("W%d · %s: tak bisa masuk, dilewati", w, namaZone)
                    return
                end
            end

            local sisa, tipe, judul = statusZone(namaZone)

            if sisa == nil then
                -- Save belum terbaca. Diam saja siklus ini — menebak di sini
                -- berarti menandai area selesai berdasarkan data kosong.
                ZQStatus.Text = string.format("W%d · %s: menunggu save...", w, namaZone)
                return
            end

            if sisa == -1 then
                -- Quest zone ini belum dibagikan server. Pemicunya memecah
                -- breakable di area ini, jadi tugasnya cuma bertahan di sini
                -- dan biarkan auto farm bekerja.
                setZonaLolos(namaZone, 0)
                ZQStatus.Text = string.format("W%d · %s: quest belum turun%s",
                    w, namaZone,
                    Config.autoFarm and " (farming...)" or " — NYALAKAN AUTO FARM")
                return
            end

            if sisa == 0 then
                local lolos = (ZQ_Progress.zona[namaZone] or 0) + 1
                setZonaLolos(namaZone, lolos)
                ZQStatus.Text = string.format("W%d · %s: beres (cek %d/%d)",
                    w, namaZone, math.min(lolos, ZQ_VERIFIKASI_MIN), ZQ_VERIFIKASI_MIN)
                if lolos >= ZQ_VERIFIKASI_MIN then
                    zonaDipegang = nil -- lanjut ke area berikutnya siklus depan
                end
                return
            end

            -- Masih ada quest tersisa: batalkan hitungan verifikasi, kalau tidak
            -- pembacaan lama bisa meluluskan area yang belum kelar.
            setZonaLolos(namaZone, 0)

            local terpakai, ket = pakaiItemQuest(tipe)
            local tambahan = ""
            if ZQ_ITEM[tipe] then
                tambahan = terpakai and (" [pakai " .. tostring(ket) .. "]")
                    or (" [" .. tostring(ket) .. "]")
            end
            ZQStatus.Text = string.format("W%d · %s: %s (sisa %d)%s",
                w, namaZone, tostring(judul), sisa, tambahan)
        end)
    end
end)

-- ==========================================
-- AUTO WORLD LOOP
-- ==========================================
-- Rank gate dihitung dari Save/RankCmds, bukan nama zone. Directory.Zones
-- dipakai untuk tahu apakah next zone sudah menyeberang ke world berikutnya.
local function worldGateInfo()
    if Config.autoWorldRankGate == false then
        return 99, 0, false
    end

    local rank = 0
    local maxRank = false
    pcall(function()
        local Save = require(Client:WaitForChild("Save"))
        local data = Save.Get()
        rank = tonumber(data and data.Rank) or 0
    end)
    pcall(function()
        local RankCmds = require(Client:WaitForChild("RankCmds"))
        maxRank = RankCmds.IsMaxRank() == true
    end)

    if maxRank then return 99, rank, true end
    if rank >= (tonumber(Config.worldGateRankW3) or 10) then return 3, rank, false end
    if rank >= (tonumber(Config.worldGateRankW2) or 5) then return 2, rank, false end
    return 1, rank, false
end

local function worldGateRequirement(world)
    if world <= 1 then return "rank 1" end
    if world == 2 then return "rank " .. tostring(Config.worldGateRankW2 or 5) end
    if world == 3 then return "rank " .. tostring(Config.worldGateRankW3 or 10) end
    return "rank MAX"
end

-- Beli zone berikutnya, lalu TELEPORT ke tengah farming area
-- Pakai Teleports_RequestTeleport — instan, gak perlu jalan
task.spawn(function()
    local lastTeleportZone = "" -- hindari spam teleport ke zone yang sama

    while true do
        task.wait(Config.worldCheckDelay)

        -- Auto world beli + teleport zone. Di mode Maze ini yang paling
        -- berbahaya: sekali teleport, kamu keluar dari maze.
        if modeLucky() then
            WorldStatus.Text = "Status: nonaktif (mode Maze)"
            continue
        end

        if not Config.autoWorld then
            WorldStatus.Text = "Status: OFF"
            continue
        end

        -- Auto zone quest sedang memegang kendali teleport. Kalau tetap jalan,
        -- karakter ditarik ke zone terakhir yang dimiliki dan quest world 1
        -- tidak akan pernah maju.
        if zoneQuestBusy then
            WorldStatus.Text = "Status: Tahan (zone quest jalan)"
            lastTeleportZone = "" -- paksa teleport ulang saat zone quest selesai
            continue
        end

        -- Skip beli area kalau ada quest coinjar/comet/hatch yang belum selesai
        if questBusy then
            WorldStatus.Text = "Status: Skip (quest aktif)"
            continue
        end

        -- Jangan beli/teleport area selagi coin jar masih berjalan.
        --
        -- questBusy sengaja TIDAK menyala untuk coin jar (lihat stayTypes:
        -- type 37 dikeluarkan) supaya jar yang SELESAI bisa langsung memicu
        -- pembelian area. Tapi itu meninggalkan celah: begitu syarat zona
        -- berikutnya terpenuhi, loop ini membeli lalu teleport walau jar-nya
        -- baru separuh terisi -- jar ditinggal dan quest tidak pernah maju.
        -- Itu persis gejala "ter-tp ke level selanjutnya, jar belum beres".
        if adaQuestJar() and jarSedangJalan() then
            if tahanJarSejak == 0 then tahanJarSejak = os.clock() end
            local lama = os.clock() - tahanJarSejak
            if lama < TAHAN_JAR_MAKS then
                WorldStatus.Text = string.format("Status: Tahan, jar jalan (%ds)", math.floor(lama))
                continue
            end
            -- Sudah kelamaan: kemungkinan besar jar orang lain yang tidak
            -- akan pernah kita selesaikan. Lanjut, jangan mengunci diri.
            WorldStatus.Text = "Status: jar tak kunjung beres, lanjut"
            tahanJarSejak = 0
        else
            tahanJarSejak = 0
        end


        pcall(function()
            local ZoneCmds = require(Client:WaitForChild("ZoneCmds"))
            local Network = ReplicatedStorage:WaitForChild("Network")
            local Directory = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Directory"))
            local nextZone = ZoneCmds.GetNextZone()
            local maxOwned = ZoneCmds.GetMaxOwnedZone()
            local tpRemote = Network:FindFirstChild("Teleports_RequestTeleport")
            local buyRemote = Network:FindFirstChild("Zones_RequestPurchase")

            -- RANK GATE: cek apakah next zone menyeberang ke world yang belum diizinkan.
            local maxAllowed, rankSekarang = worldGateInfo()

            -- Cari world dari maxOwned (zona yang sedang dimiliki).
            local worldSekarang = 1
            if maxOwned and maxOwned ~= "" then
                local zInfo = Directory.Zones and Directory.Zones[maxOwned]
                worldSekarang = (zInfo and zInfo.WorldNumber) or 1
            end

            -- Kalau nextZone ada, cek world tujuannya.
            if nextZone and nextZone ~= "" then
                local nextInfo = Directory.Zones and Directory.Zones[nextZone]
                local nextWorld = (nextInfo and nextInfo.WorldNumber) or 1
                if nextWorld > maxAllowed then
                    WorldStatus.Text = string.format("Tahan W%d (rank %d, butuh %s untuk W%d)",
                        worldSekarang, rankSekarang, worldGateRequirement(nextWorld), nextWorld)
                    return -- jangan beli/teleport
                end
            end

            -- coba beli zone berikutnya
            if nextZone and nextZone ~= "" and buyRemote then
                WorldStatus.Text = string.format("Status: Coba beli %s...", nextZone)
                local success, result = pcall(buyRemote.InvokeServer, buyRemote, nextZone)
                if success and result == true then
                    WorldStatus.Text = string.format("Status: %s dibeli!", nextZone)
                    task.wait(0.5)
                    -- beli berhasil, update maxOwned
                    maxOwned = nextZone
                end
            end

            -- teleport ke zone terakhir dimiliki (instan)
            if maxOwned and maxOwned ~= "" and maxOwned ~= lastTeleportZone and tpRemote then
                WorldStatus.Text = string.format("Status: Teleport ke %s...", maxOwned)
                local ok, res = pcall(tpRemote.InvokeServer, tpRemote, maxOwned)
                if ok and res == true then
                    lastTeleportZone = maxOwned
                    WorldStatus.Text = string.format("Status: Di %s ✓", maxOwned)
                else
                    -- mungkin sudah di zona itu, skip
                    lastTeleportZone = maxOwned
                    WorldStatus.Text = string.format("Status: Gagal teleport %s (%s)", maxOwned, tostring(res))
                end
            elseif maxOwned and maxOwned ~= "" then
                WorldStatus.Text = string.format("Status: Di %s ✓", maxOwned)
            elseif not nextZone or nextZone == "" then
                WorldStatus.Text = "Status: Semua zone terbuka!"
            end
        end)
    end
end)

-- ==========================================
-- AUTO RANK LOOP
-- ==========================================
-- Rank reward claim: klik GUI button (bukan remote langsung)
-- Remote Ranks_ClaimReward fire tapi TIDAK claim — yang benar lewat GUI
-- Rank remotes:
--   Ranks_RankUp (RE) — naik rank
--   Rebirth_Request (RF) — rebirth (reset untuk bonus)
task.spawn(function()
    while true do
        task.wait(Config.worldCheckDelay)
        if not Config.autoRank then
            RankStatus.Text = "Status: OFF"
            continue
        end

        pcall(function()
            local count = 0
            local Save = require(Client:WaitForChild("Save"))
            local saveData = Save.Get()

            -- 1. Klaim rank reward yang sudah terbuka.
            local diklaim = claimRankReward()
            count = count + diklaim

            -- 2. Rank up hanya kalau semua reward rank ini sudah diambil —
            -- itu syarat game-nya, sekaligus mencegah remote ditembak percuma
            -- tiap siklus.
            local RankCmds = require(Client:WaitForChild("RankCmds"))
            local siapRankUp = select(2, pcall(RankCmds.AllRewardsRedeemed)) == true
            if siapRankUp and not (select(2, pcall(RankCmds.IsMaxRank)) == true) then
                local naik = Network:FindFirstChild("Ranks_RankUp")
                if naik then
                    pcall(function() naik:FireServer() end)
                    count = count + 1
                end
            end

            -- 3. Rebirth kalau memenuhi syarat. Server menolak sendiri kalau
            -- belum layak, tapi jangan dihitung sebagai "action" — dulu selalu
            -- ditambah sehingga status memamerkan "1 action" padahal tidak
            -- terjadi apa-apa.
            local rebirth = Network:FindFirstChild("Rebirth_Request")
            if rebirth then
                local okR, hasil = pcall(function() return rebirth:InvokeServer() end)
                if okR and hasil == true then count = count + 1 end
            end

            saveData = Save.Get() -- baca ulang: rank/bintang bisa berubah di atas
            local rank = saveData and saveData.Rank or "?"
            local stars = saveData and saveData.RankStars or "?"
            local sisa = select(2, pcall(RankCmds.AllRewardsReady)) == true and " · ada reward siap" or ""
            RankStatus.Text = count > 0
                and string.format("Status: Rank %s (%s★) %d aksi%s", rank, stars, count, sisa)
                or string.format("Status: Rank %s (%s★)%s", rank, stars, sisa)
        end)
    end
end)

-- ==========================================
-- AUTO CLAIM LOOP
-- ==========================================
-- Claim semua reward yang tersedia: free gift, login streak, mailbox,
-- rank reward, daycare, forever packs, dll.
-- Semua remote safe — return false kalau tidak ada yang di-claim
task.spawn(function()
    while true do
        task.wait(Config.claimDelay)
        if not Config.autoClaim then
            ClaimStatus.Text = "Status: OFF"
            continue
        end

        pcall(function()
            local claimed = 0
            local SaveMod = require(Client:WaitForChild("Save"))

            -- free gift: coba index 1-10
            local freeGift = Network:FindFirstChild("Redeem Free Gift")
            if freeGift then
                for i = 1, 10 do
                    pcall(function()
                        local ok, res = freeGift:InvokeServer(i)
                        if ok and res == true then claimed = claimed + 1 end
                    end)
                end
            end

            -- login streak
            pcall(function()
                local r = Network:FindFirstChild("Login Streaks: Claim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- daily rewards
            pcall(function()
                local r = Network:FindFirstChild("DailyRewards_Redeem")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- mailbox claim all
            pcall(function()
                local r = Network:FindFirstChild("Mailbox: Claim All")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- transfer claim all
            pcall(function()
                local r = Network:FindFirstChild("Transferring_ClaimAll")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- rank reward claim DIMATIKAN — GUI spam ganggu gameplay
            -- Claim manual via tombol Rewards di game

            -- forever packs free
            pcall(function()
                local r = Network:FindFirstChild("ForeverPacks: Claim Free")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- daycare claim
            pcall(function()
                local r = Network:FindFirstChild("Daycare: Claim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- exclusive daycare
            pcall(function()
                local r = Network:FindFirstChild("Exclusive Daycare: Claim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- instance chests
            pcall(function()
                local r = Network:FindFirstChild("InstanceChests_Claim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- raids open chest
            pcall(function()
                local r = Network:FindFirstChild("Raids_OpenChest")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- CTA pet claim
            pcall(function()
                local r = Network:FindFirstChild("CTA Pet: Claim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- doodle jar
            pcall(function()
                local r = Network:FindFirstChild("DoodleJar_RequestColorClaim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- prison cell chest
            pcall(function()
                local r = Network:FindFirstChild("PrisonCell_ChestUnlock")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- breakables bonus
            pcall(function()
                local r = Network:FindFirstChild("Breakables_Bonus")
                if r then r:FireServer() claimed = claimed + 1 end
            end)

            -- farming claim storage
            pcall(function()
                local r = Network:FindFirstChild("Farming_ClaimStorage")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- EB redeem (exchange booth)
            pcall(function()
                local r = Network:FindFirstChild("EB_Redeem")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- exclusive daycare redeem
            pcall(function()
                local r = Network:FindFirstChild("Exclusive Daycare: Redeem")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- merch codes redeem (safe, no code needed)
            pcall(function()
                local r = Network:FindFirstChild("MerchCodes: Redeem")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            -- item creator claim
            pcall(function()
                local r = Network:FindFirstChild("Item Creator: Claim")
                if r then local ok, res = r:InvokeServer() if ok and res == true then claimed = claimed + 1 end end
            end)

            ClaimStatus.Text = claimed > 0
                and string.format("Status: Claimed %d reward!", claimed)
                or "Status: Menunggu reward..."
        end)
    end
end)

-- ==========================================
-- STATUS GLOBAL LOOP
-- ==========================================
task.spawn(function()
    -- Ikon tidak pernah berubah untuk mata uang yang sama, jadi disimpan.
    -- Items.Currency() cukup mahal untuk dipanggil tiap detik.
    local cacheIkon = {}
    local function ikonMataUang(nama)
        if cacheIkon[nama] ~= nil then return cacheIkon[nama] end
        local ok, hasil = pcall(function()
            return require(ReplicatedStorage.Library.Items).Currency(nama):GetIcon()
        end)
        cacheIkon[nama] = ok and hasil or false
        return cacheIkon[nama]
    end

    -- FormatAbbreviated = format yang dipakai HUD game sendiri (609m, 20.8Qt).
    -- FormatFigures memberi "20,800,000,000,000,000,000" — meluber dari kartu.
    local function angkaRapi(n)
        if type(n) ~= "number" then return "-" end
        local ok, teks = pcall(function()
            return require(ReplicatedStorage.Library.Functions).FormatAbbreviated(n)
        end)
        return (ok and teks) and tostring(teks) or tostring(n)
    end

    while true do
        task.wait(1)
        pcall(function()
            local CurrencyCmds = require(Client:WaitForChild("CurrencyCmds"))
            local MapCmds = require(Client:WaitForChild("MapCmds"))
            local Dir = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Directory"))

            local zona = MapCmds.GetCurrentZone()
            local z = zona and Dir.Zones[zona]

            -- Tiap world punya mata uangnya sendiri (W1 Coins, W2 TechCoins,
            -- W3 VoidCoins, W4 FantasyCoins), jadi ambil dari data zone —
            -- jangan pernah mengunci ke "Coins".
            local mataUang = (z and z.Currency) or "Coins"

            if modeLucky() then
                -- Di mode Maze yang berguna bukan nama zone, tapi level Fiesta
                -- dan apakah kita benar-benar sudah di dalam maze.
                local lvl, diMaze = "?", "?"
                pcall(function()
                    lvl = tostring(require(Client:WaitForChild("FiestaLevelCmds")).Get())
                    diMaze = tostring(require(Client:WaitForChild("FiestaScoreCmds")).IsInMaze())
                end)
                StatusLabel.Text = string.format("MAZE · Fiesta Lv %s · di maze: %s", lvl, diMaze)
            else
                StatusLabel.Text = string.format("World %s · %s",
                    tostring(z and z.WorldNumber or "?"), tostring(zona or "?"))
            end

            local ikonD = ikonMataUang("Diamonds")
            RowDiamond.ikon.Image = ikonD or ""
            RowDiamond.nilai.Text = angkaRapi(CurrencyCmds.Get("Diamonds"))

            local ikonC = ikonMataUang(mataUang)
            RowCoin.ikon.Image = ikonC or ""
            RowCoin.nilai.Text = string.format("%s  (%s)",
                angkaRapi(CurrencyCmds.Get(mataUang)), tostring(mataUang))
        end)
    end
end)

print("[PS99 Auto Farm] Loaded! Toggle features via UI.")

-- ==========================================
-- BLACKSCREEN — tampilan informatif layar penuh
-- ==========================================
-- Variabel global buat toggle dari UI
BS_Visible = true
BS_GuiRef = nil

local function applyBlackScreen()
    if BS_GuiRef then BS_GuiRef.Enabled = BS_Visible end
    if BS_ToggleBtn then
        BS_ToggleBtn.Text = BS_Visible and "Hide BS" or "Show BS"
    end
end

local function pasangBlackScreen()
    if not Config.BlackScreen then return end

    pcall(function() workspace.CurrentCamera.FieldOfView = 30 end)

    -- ==========================================
    -- TOGGLE BUTTON — ScreenGui TERPISAH, selalu visible
    -- ==========================================
    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name = "BS_Toggle"
    toggleGui.Enabled = true
    toggleGui.IgnoreGuiInset = false
    toggleGui.ResetOnSpawn = false
    toggleGui.DisplayOrder = 999
    pcall(function() toggleGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not toggleGui.Parent then toggleGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "BSToggle"
    toggleBtn.Size = UDim2.new(0, 100, 0, 32)
    toggleBtn.Position = UDim2.new(1, -110, 0, 50)
    toggleBtn.AnchorPoint = Vector2.new(0, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleBtn.BackgroundTransparency = 0.2
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = "Hide BS"
    toggleBtn.TextSize = 13
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.ZIndex = 100
    toggleBtn.Parent = toggleGui
    BS_ToggleBtn = toggleBtn

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = toggleBtn
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = Color3.fromRGB(100, 100, 100)
    btnStroke.Parent = toggleBtn

    local function toggleBS()
        BS_Visible = not BS_Visible
        if BS_GuiRef then BS_GuiRef.Enabled = BS_Visible end
        toggleBtn.Text = BS_Visible and "Hide BS" or "Show BS"
    end

    toggleBtn.MouseButton1Click:Connect(toggleBS)

    -- Keyboard shortcut: tekan B untuk toggle
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.B then
            toggleBS()
        end
    end)

    -- ==========================================
    -- BLACKSCREEN GUI — layar penuh
    -- ==========================================
    local ok, err = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "AFK_BlackScreen"
        gui.Enabled = true
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        BS_GuiRef = gui

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BorderSizePixel = 0
        bg.Parent = gui

        -- Gambar kiri
        local kiri = Instance.new("ImageLabel")
        kiri.Size = UDim2.new(0.3, 0, 0.6, 0)
        kiri.Position = UDim2.new(0.05, 0, 0.5, 0)
        kiri.AnchorPoint = Vector2.new(0, 0.5)
        kiri.BackgroundTransparency = 1
        kiri.ScaleType = Enum.ScaleType.Fit
        kiri.Image = "rbxassetid://79880397850563"
        kiri.Parent = bg

        -- Gambar kanan
        local kanan = Instance.new("ImageLabel")
        kanan.Size = UDim2.new(0.3, 0, 0.6, 0)
        kanan.Position = UDim2.new(0.95, 0, 0.5, 0)
        kanan.AnchorPoint = Vector2.new(1, 0.5)
        kanan.BackgroundTransparency = 1
        kanan.ScaleType = Enum.ScaleType.Fit
        kanan.Image = "rbxassetid://104624206636533"
        kanan.Parent = bg

        -- Judul bawah
        local judul = Instance.new("TextLabel")
        judul.Size = UDim2.new(0.9, 0, 0.15, 0)
        judul.Position = UDim2.new(0.5, 0, 0.95, 0)
        judul.AnchorPoint = Vector2.new(0.5, 1)
        judul.BackgroundTransparency = 1
        judul.Text = "Pawtuer Bot — PS99\nFENG JIU MY ISTRI"
        judul.TextColor3 = Color3.fromRGB(255, 255, 255)
        judul.TextScaled = true
        judul.TextWrapped = true
        judul.Font = Enum.Font.Code
        judul.ZIndex = 10
        judul.Parent = bg

        -- Info tengah (Username, Rank/Rebirth)
        local infoTengah = Instance.new("TextLabel")
        infoTengah.Size = UDim2.new(0.4, 0, 0.25, 0)
        infoTengah.Position = UDim2.new(0.5, 0, 0.35, 0)
        infoTengah.AnchorPoint = Vector2.new(0.5, 0.5)
        infoTengah.BackgroundTransparency = 1
        infoTengah.Text = "Loading..."
        infoTengah.TextColor3 = Color3.fromRGB(255, 255, 0)
        infoTengah.TextScaled = true
        infoTengah.Font = Enum.Font.GothamBold
        infoTengah.ZIndex = 10
        infoTengah.Parent = bg
        local batasTeks = Instance.new("UITextSizeConstraint")
        batasTeks.MaxTextSize = 28
        batasTeks.Parent = infoTengah
        local strokeTengah = Instance.new("UIStroke")
        strokeTengah.Thickness = 1.5
        strokeTengah.Color = Color3.fromRGB(0, 0, 0)
        strokeTengah.Parent = infoTengah

        -- Baris mata uang dengan ikon asli game (diamond + coin world berjalan)
        local barisUang = Instance.new("Frame")
        barisUang.Size = UDim2.new(0.46, 0, 0.06, 0)
        barisUang.Position = UDim2.new(0.5, 0, 0.47, 0)
        barisUang.AnchorPoint = Vector2.new(0.5, 0.5)
        barisUang.BackgroundTransparency = 1
        barisUang.ZIndex = 10
        barisUang.Parent = bg

        local function selUang(xScale)
            local ikon = Instance.new("ImageLabel")
            ikon.Size = UDim2.new(0, 26, 0, 26)
            ikon.Position = UDim2.new(xScale, 0, 0.5, 0)
            ikon.AnchorPoint = Vector2.new(0, 0.5)
            ikon.BackgroundTransparency = 1
            ikon.ScaleType = Enum.ScaleType.Fit
            ikon.ZIndex = 11
            ikon.Parent = barisUang

            local teks = Instance.new("TextLabel")
            teks.Size = UDim2.new(0.5, -32, 1, 0)
            teks.Position = UDim2.new(xScale, 30, 0, 0)
            teks.BackgroundTransparency = 1
            teks.Text = "-"
            teks.TextColor3 = Color3.fromRGB(255, 255, 255)
            teks.TextSize = 20
            teks.Font = Enum.Font.GothamBold
            teks.TextXAlignment = Enum.TextXAlignment.Left
            teks.ZIndex = 11
            teks.Parent = barisUang
            local s = Instance.new("UIStroke")
            s.Thickness = 1.2
            s.Color = Color3.fromRGB(0, 0, 0)
            s.Parent = teks
            return { ikon = ikon, teks = teks }
        end

        local uangDiamond = selUang(0)
        local uangCoin = selUang(0.5)

        -- Detail tengah (World, Quest)
        local detail = Instance.new("TextLabel")
        detail.Size = UDim2.new(0.4, 0, 0.35, 0)
        detail.Position = UDim2.new(0.5, 0, 0.55, 0)
        detail.AnchorPoint = Vector2.new(0.5, 0)
        detail.BackgroundTransparency = 1
        detail.Text = ""
        detail.TextColor3 = Color3.fromRGB(150, 255, 150)
        detail.TextSize = 14
        detail.TextXAlignment = Enum.TextXAlignment.Center
        detail.TextYAlignment = Enum.TextYAlignment.Top
        detail.TextWrapped = true
        detail.Font = Enum.Font.GothamBold
        detail.ZIndex = 10
        detail.Parent = bg
        local strokeDetail = Instance.new("UIStroke")
        strokeDetail.Thickness = 1.2
        strokeDetail.Color = Color3.fromRGB(0, 0, 0)
        strokeDetail.Parent = detail

        -- Performa atas
        local perf = Instance.new("TextLabel")
        perf.Size = UDim2.new(0.5, 0, 0.04, 0)
        perf.Position = UDim2.new(0.5, 0, 0.02, 0)
        perf.AnchorPoint = Vector2.new(0.5, 0)
        perf.BackgroundTransparency = 1
        perf.Text = "FPS: - | Ping: - ms | Mem: - MB"
        perf.TextColor3 = Color3.fromRGB(200, 200, 200)
        perf.TextSize = 14
        perf.Font = Enum.Font.Code
        perf.ZIndex = 10
        perf.Parent = bg
        local strokePerf = Instance.new("UIStroke")
        strokePerf.Thickness = 1
        strokePerf.Color = Color3.fromRGB(0, 0, 0)
        strokePerf.Parent = perf

        -- Ditempel ke CoreGui
        local berhasil = pcall(function()
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not berhasil then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        -- Pakai format bawaan game (609m, 20.8Qt) supaya sama persis dengan HUD
        -- aslinya. Format buatan sendiri mentok di T dan salah menampilkan
        -- angka PS99 yang rutin menembus 1e20.
        local function ringkasAngka(n)
            n = tonumber(n) or 0
            local ok, teks = pcall(function()
                return require(ReplicatedStorage.Library.Functions).FormatAbbreviated(n)
            end)
            if ok and teks then return tostring(teks) end
            if n >= 1e12 then return string.format("%.2fT", n / 1e12)
            elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
            elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
            elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
            else return tostring(n) end
        end

        -- Cache Save module di luar loop — retry kalau belum siap
        local SaveMod = nil
        task.spawn(function()
            for _ = 1, 30 do
                pcall(function() SaveMod = require(Client:WaitForChild("Save")) end)
                if SaveMod then break end
                task.wait(1)
            end
        end)

        task.spawn(function()
            -- TIDAK ada setthreadidentity(8) di sini lagi.
            --
            -- Dulu ada, dengan alasan "instance di CoreGui butuh identitas
            -- tinggi". Diukur ulang dan hasilnya kebalikannya: sesudah identitas
            -- dipaksa ke 8, thread ini justru tidak bisa menyentuh Instance mana
            -- pun -- CoreGui DAN PlayerGui sama-sama menolak dengan "lacking
            -- capability Plugin". Identitas sekarang diurus adaptif di dalam loop:
            -- tulis dulu apa adanya, baru cari identitas yang benar kalau gagal.
            local Stats = game:GetService("Stats")
            -- Cache CurrencyCmds sekalian (sudah proven work di getPlayerCoins)
            local CurrencyCmds = nil
            pcall(function()
                CurrencyCmds = require(ReplicatedStorage:WaitForChild("Library").Client:WaitForChild("CurrencyCmds"))
            end)

            -- Ikon mata uang dari game, di-cache karena tidak pernah berubah.
            local cacheIkonBS = {}
            local function ikonUang(nama)
                if cacheIkonBS[nama] ~= nil then return cacheIkonBS[nama] end
                local ok, hasil = pcall(function()
                    return require(ReplicatedStorage.Library.Items).Currency(nama):GetIcon()
                end)
                cacheIkonBS[nama] = ok and hasil or false
                return cacheIkonBS[nama]
            end

            -- Penanda supaya peringatan gagal-tulis dicetak sekali, bukan tiap detik.
            local gagalTulisDilapor = false
            local gagalBerturut = 0
            -- Urutan coba saat penulisan ditolak. 2 = identitas script biasa
            -- (paling sering benar), 8 dan 7 untuk executor yang menuntut lebih
            -- tinggi. Begitu ada yang berhasil, daftar ini disusutkan ke satu itu.
            local identitasKandidat = { 2, 8, 7, 3 }

            while gui.Parent do
                -- Baca data dari Save — retry module kalau belum ada
                local data = nil
                if not SaveMod then
                    pcall(function() SaveMod = require(Client:WaitForChild("Save")) end)
                end
                if SaveMod then
                    pcall(function() data = SaveMod.Get() end)
                end

                local username = LocalPlayer.Name
                local rank = "?"
                local rebirths = "?"
                local diamonds = 0
                local coins = 0
                local mapName = "—"
                local questInfo = "—"

                if data then
                    -- Baca field satu per satu — field mungkin beda nama antar versi
                    pcall(function() rank = data.Rank or "?" end)
                    pcall(function() rebirths = data.Rebirths or data.Rebirth or "?" end)
                    pcall(function() diamonds = data.Diamonds or data.Diamond or 0 end)
                    pcall(function() coins = data.Coins or 0 end)

                    -- Map dari data.Zone atau ZoneCmds
                    pcall(function()
                        local z = data.Zone
                        if type(z) == "table" and z.Name then
                            mapName = z.Name
                        elseif type(z) == "string" then
                            mapName = z
                        end
                    end)

                    -- Quest aktif
                    pcall(function()
                        if data.ZoneQuests then
                            for zoneName, zoneData in pairs(data.ZoneQuests) do
                                if zoneData.Quests then
                                    for _, q in ipairs(zoneData.Quests) do
                                        if not q.Completed and q.Goal then
                                            local sisa = q.Goal.Amount - (q.Goal.Progress or 0)
                                            if sisa > 0 then
                                                questInfo = string.format("[%s] %d/%d (%d left)",
                                                    zoneName, q.Goal.Progress or 0, q.Goal.Amount, sisa)
                                                break
                                            end
                                        end
                                    end
                                    if questInfo ~= "—" then break end
                                end
                            end
                        end
                    end)
                end

                -- Zone berjalan menentukan mata uangnya: W1 Coins, W2 TechCoins,
                -- W3 VoidCoins, W4 FantasyCoins. Versi lama mengunci ke "Coins"
                -- sehingga di World 4 yang tampil saldo world lain.
                local mataUang = "Coins"
                pcall(function()
                    local zona = require(Client:WaitForChild("MapCmds")).GetCurrentZone()
                    if zona then
                        mapName = zona
                        local z = require(ReplicatedStorage.Library.Directory).Zones[zona]
                        if z and z.Currency then mataUang = z.Currency end
                    end
                end)

                -- Diamonds TIDAK ada di Save sebagai field; harus lewat CurrencyCmds.
                if CurrencyCmds then
                    pcall(function() diamonds = CurrencyCmds.Get("Diamonds") or diamonds end)
                    pcall(function() coins = CurrencyCmds.Get(mataUang) or coins end)
                end

                if mapName == "—" then
                    pcall(function()
                        local map = getMapPath()
                        if map then mapName = map.Name end
                    end)
                end

                -- Performa
                local ping, fps, mem = "0", "0", "0"
                pcall(function()
                    ping = string.split(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1] or "0"
                end)
                pcall(function() fps = tostring(math.floor(workspace:GetRealPhysicsFPS())) end)
                pcall(function()
                    mem = string.split(Stats.PerformanceStats.Memory:GetValueString(), " ")[1] or "0"
                end)

                -- SEMUA penulisan GUI dalam satu blok terlindungi.
                --
                -- Dulu baris-baris ini telanjang. Sekali saja salah satunya gagal
                -- -- terekam nyata di log user: "The current thread cannot access
                -- 'Instance' (lacking capability Plugin)" pada baris penulisan
                -- pertama -- thread ini mati DIAM-DIAM dan layar berhenti di
                -- "Loading..." selamanya. Satu kedip tidak boleh mematikan
                -- tampilan permanen, jadi kegagalan cuma melewati satu putaran.
                local function tulisSemua()
                    infoTengah.Text = "Username : " .. tostring(username)

                    uangDiamond.ikon.Image = ikonUang("Diamonds") or ""
                    uangDiamond.teks.Text = ringkasAngka(diamonds)
                    uangCoin.ikon.Image = ikonUang(mataUang) or ""
                    uangCoin.teks.Text = ringkasAngka(coins)

                    detail.Text = table.concat({
                        "────────────",
                        "World : " .. tostring(mapName),
                        "Quest : " .. tostring(questInfo),
                    }, "\n")

                    perf.Text = string.format("🎮 FPS: %s  |  📶 Ping: %s ms  |  🧠 Mem: %s MB", fps, ping, mem)
                end

                -- Identitas TIDAK dipaksa di muka.
                --
                -- Versi sebelumnya memanggil setthreadidentity(8) di awal thread
                -- dengan asumsi identitas tinggi = lebih boleh. Terukur sebaliknya:
                -- sesudah itu thread justru tak bisa menyentuh Instance mana pun --
                -- CoreGui DAN PlayerGui sama-sama ditolak. Jadi coba tulis apa
                -- adanya dulu; identitas hanya disentuh kalau penulisan gagal, dan
                -- yang berhasil diingat supaya putaran berikutnya langsung benar.
                local okTulis, errTulis = pcall(tulisSemua)
                if not okTulis then
                    local setId = setthreadidentity or (syn and syn.set_thread_identity) or setidentity
                    if setId then
                        for _, id in ipairs(identitasKandidat) do
                            if pcall(setId, id) and pcall(tulisSemua) then
                                okTulis = true
                                -- Yang berhasil dipindah ke depan antrean.
                                identitasKandidat = { id }
                                break
                            end
                        end
                    end
                end

                if okTulis then
                    gagalBerturut = 0
                else
                    gagalBerturut = gagalBerturut + 1

                    -- Diberitahukan sekali saja. Kalau tiap putaran, satu
                    -- kegagalan menetap membanjiri console 1 baris per detik.
                    if not gagalTulisDilapor then
                        gagalTulisDilapor = true
                        warn("[PS99] Black screen gagal menulis: " .. tostring(errTulis))
                    end

                    -- CADANGAN: pindah ke PlayerGui.
                    --
                    -- Instance di gethui()/CoreGui hanya bisa ditulis dari thread
                    -- beridentitas tinggi, dan di sebagian executor identitas itu
                    -- TIDAK bisa dipertahankan di dalam thread loop -- terekam
                    -- nyata "lacking capability Plugin" berulang meski
                    -- setthreadidentity(8) dipanggil tiap putaran. PlayerGui tidak
                    -- punya syarat itu sama sekali.
                    --
                    -- Sengaja CADANGAN, bukan default: CoreGui lebih sulit dilihat
                    -- game. Pindah hanya setelah 3 kegagalan beruntun supaya
                    -- gangguan sesaat tidak langsung menurunkan tempat tinggalnya.
                    if gagalBerturut == 3 then
                        local okPindah = pcall(function()
                            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
                        end)
                        warn("[PS99] Black screen pindah ke PlayerGui (CoreGui menolak ditulis): "
                             .. (okPindah and "berhasil" or "GAGAL juga"))
                    end
                end

                task.wait(1)
            end
        end)
    end)

    -- Pesan aslinya ikut dicetak. Versi lama cuma bilang "Gagal memasang black
    -- screen" tanpa alasan, dan itu membuat penelusuran kenapa layarnya mandek
    -- di "Loading..." jauh lebih lama daripada seharusnya.
    if not ok then warn("[PS99] Gagal memasang black screen: " .. tostring(err)) end
end

-- ==========================================
-- AUTO EQUIP BEST — isi slot pet yang menganggur
-- ==========================================
task.spawn(function()
    -- PetCmds menolak dipanggil dari identitas RobloxScript: modul dalamnya
    -- melempar "Cannot require a non-RobloxScript module from a RobloxScript".
    -- Terukur, bukan dugaan. Identitas 2 (script biasa) yang diterima.
    pcall(function() if setthreadidentity then setthreadidentity(2) end end)

    local PetCmds
    for _ = 1, 30 do
        pcall(function() PetCmds = require(Client:WaitForChild("PetCmds")) end)
        if PetCmds then break end
        task.wait(1)
    end
    if not PetCmds then
        pcall(function() PetStatus.Text = "Status: PetCmds tidak tersedia" end)
        return
    end

    -- Semua fungsi PetCmds butuh objek pemain sebagai argumen. Tanpa itu ia
    -- meledak di dalam PetPlayer ("table index is nil"), bukan mengembalikan nil
    -- -- jadi pcall di sini wajib, bukan kehati-hatian berlebih.
    local function angka(f, ...)
        local ok, v = pcall(f, ...)
        return ok and tonumber(v) or nil
    end
    local function cacah(f, ...)
        local ok, t = pcall(f, ...)
        if not ok or type(t) ~= "table" then return 0 end
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    local terakhirDilapor = ""
    while true do
        if not Config.autoEquipBest then
            pcall(function() PetStatus.Text = "Status: OFF" end)
            task.wait(2)
        else
            local maks = angka(PetCmds.GetMaxEquipped) or 0
            local terpasang = cacah(PetCmds.GetEquippedItems, LocalPlayer)
            local punya = cacah(PetCmds.GetDamageSortedPets, LocalPlayer)

            -- Hanya bertindak kalau memang ada slot nganggur DAN ada pet cadangan.
            -- Tanpa syarat kedua, EquipBest dipanggil percuma tiap menit.
            if maks > 0 and terpasang < maks and punya > terpasang then
                local sebelum = angka(PetCmds.CalculatePlayerDamage, LocalPlayer)

                -- Bentuk argumen EquipBest berbeda antar versi game; dicoba dua-duanya.
                local ok = pcall(PetCmds.EquipBest, LocalPlayer)
                if not ok then ok = pcall(PetCmds.EquipBest) end
                task.wait(1)

                local sesudah = angka(PetCmds.CalculatePlayerDamage, LocalPlayer)
                local kini = cacah(PetCmds.GetEquippedItems, LocalPlayer)
                local pesan
                if not ok then
                    pesan = string.format("EquipBest ditolak game (slot %d/%d)", terpasang, maks)
                elseif sebelum and sesudah and sesudah > sebelum then
                    pesan = string.format("Slot %d->%d/%d, dmg +%.1f%%",
                        terpasang, kini, maks, (sesudah / sebelum - 1) * 100)
                else
                    pesan = string.format("Slot %d->%d/%d", terpasang, kini, maks)
                end
                if pesan ~= terakhirDilapor then
                    terakhirDilapor = pesan
                    pcall(function() PetStatus.Text = "Status: " .. pesan end)
                end
            else
                pcall(function()
                    PetStatus.Text = string.format("Slot: %d/%d (%d pet dimiliki)",
                        terpasang, maks, punya)
                end)
            end
            task.wait(tonumber(Config.autoEquipJeda) or 60)
        end
    end
end)

-- ==========================================
-- AUTO KLAIM HARIAN — hadiah gratis yang terlewat saat AFK
-- ==========================================
-- Semua nama di bawah diambil dari isi ReplicatedStorage.Network yang nyata,
-- bukan dikarang. Semuanya MENGAMBIL sesuatu; tidak ada yang membelanjakan,
-- membuang, atau menjual — itu syarat sebuah remote boleh masuk daftar ini.
-- DIUJI SATU PER SATU di akun nyata. Yang masuk hanya yang bisa dipanggil TANPA
-- argumen dan membalas rapi. Dua yang dibuang:
--   DailyRewards_Redeem  -> butuh argumen (Library.Functions assertion)
--   EventGoals_Claim     -> butuh argumen (Library.Asserts:109)
-- Keduanya melempar error tiap panggilan, jadi memasukkannya cuma menambah
-- pekerjaan sia-sia tiap 5 menit. Bisa ditambahkan lagi kalau bentuk
-- argumennya sudah dibongkar.
-- Tiap nama SUDAH DIUJI dipanggil tanpa argumen dan membalas dengan sopan
-- (true/false), bukan melempar. Yang TIDAK masuk karena menuntut argumen dan
-- melempar assertion: InstanceChests_Claim, EventGoals_Claim,
-- TimeTrials_OpenChest, DailyRewards_Redeem. Ranks_ClaimReward juga tidak --
-- itu RemoteEvent, bukan RemoteFunction, jadi Invoke pasti gagal.
local KLAIM_HARIAN = {
    "Login Streaks: Claim",
    "ForeverPacks: Claim Free",
    "Mailbox: Claim All",
    "Free Gift: Claimed",
    "Transferring_ClaimAll",
    "Daycare: Claim",
    "Exclusive Daycare: Claim",
    "Farming_ClaimStorage",
}

task.spawn(function()
    pcall(function() if setthreadidentity then setthreadidentity(2) end end)
    local Network = ReplicatedStorage:WaitForChild("Network")

    -- Kelasnya dicek, bukan diasumsikan: Network memuat RemoteEvent DAN
    -- RemoteFunction, dan memanggil FireServer pada RemoteFunction (atau
    -- sebaliknya) melempar error, bukan diam-diam gagal.
    local function panggil(nama)
        local r = Network:FindFirstChild(nama, true)
        if not r then return nil end
        if r:IsA("RemoteFunction") then
            return pcall(function() return r:InvokeServer() end)
        elseif r:IsA("RemoteEvent") then
            return pcall(function() r:FireServer() end)
        end
        return nil
    end

    while true do
        if not Config.autoClaimHarian then
            pcall(function() ClaimStatus.Text = "Harian: OFF" end)
            task.wait(5)
        else
            local dapat, hilang = 0, 0
            for _, nama in ipairs(KLAIM_HARIAN) do
                local ok = panggil(nama)
                if ok == nil then hilang = hilang + 1
                elseif ok then dapat = dapat + 1 end
            end

            -- Penanda hadiah login dibaca SESUDAH klaim supaya statusnya
            -- menunjukkan hasil, bukan keadaan sebelum dicoba.
            local gift = "?"
            pcall(function()
                gift = tostring(require(Client:WaitForChild("Save")).Get().TwentyHourLoginGift)
            end)

            pcall(function()
                ClaimStatus.Text = string.format("Harian: %d dikirim, %d remote hilang | gift20j=%s",
                    dapat, hilang, gift)
            end)
            task.wait(tonumber(Config.claimHarianJeda) or 300)
        end
    end
end)

-- ==========================================
-- AUTO POTION — minum ulang sebelum buff habis
-- ==========================================
task.spawn(function()
    pcall(function() if setthreadidentity then setthreadidentity(2) end end)

    local PotionCmds
    for _ = 1, 30 do
        pcall(function() PotionCmds = require(Client:WaitForChild("PotionCmds")) end)
        if PotionCmds then break end
        task.wait(1)
    end
    if not PotionCmds then
        pcall(function() PotionStatus.Text = "Potion: modul tidak tersedia" end)
        return
    end

    -- GetActivePotions mengembalikan tabel bernama, isinya ARRAY sisa detik per
    -- tumpukan -- terukur: Damage{4800,44400,86400,20489}. Tabel kosong ({})
    -- berarti aktif tanpa batas waktu, jadi TIDAK boleh dianggap habis.
    local function sisaDetik(aktif, nama)
        local v = aktif and aktif[nama]
        if v == nil then return 0 end          -- tidak aktif
        if type(v) ~= "table" then return math.huge end
        local n, maks = 0, 0
        for _, d in pairs(v) do
            n = n + 1
            local x = tonumber(d) or 0
            if x > maks then maks = x end
        end
        if n == 0 then return math.huge end     -- {} = tanpa kedaluwarsa
        return maks
    end

    while true do
        if not Config.autoPotion then
            pcall(function() PotionStatus.Text = "Potion: OFF" end)
            task.wait(2)
        else
            local aktif
            pcall(function() aktif = PotionCmds.GetActivePotions(LocalPlayer) end)

            local lapor = {}
            for _, nama in ipairs(Config.potionDijaga or {}) do
                local sisa = sisaDetik(aktif, nama)
                local ambang = tonumber(Config.potionAmbang) or 300

                if sisa == math.huge then
                    lapor[#lapor+1] = nama .. ":∞"
                elseif sisa > ambang then
                    lapor[#lapor+1] = string.format("%s:%dm", nama, math.floor(sisa / 60))
                else
                    -- Punya stoknya dulu, baru minum. Tanpa cek ini Consume
                    -- dipanggil percuma tiap 30 detik saat stok habis.
                    local punya = false
                    pcall(function() punya = PotionCmds.Has(LocalPlayer, nama) and true or false end)
                    if not punya then
                        lapor[#lapor+1] = nama .. ":stok habis"
                    else
                        local ok = pcall(PotionCmds.Consume, LocalPlayer, nama)
                        if not ok then ok = pcall(PotionCmds.Consume, nama) end
                        lapor[#lapor+1] = nama .. (ok and ":diminum" or ":Consume ditolak")
                    end
                end
            end

            pcall(function()
                PotionStatus.Text = "Potion: " .. (#lapor > 0 and table.concat(lapor, " ") or "tidak ada target")
            end)
            task.wait(tonumber(Config.potionJeda) or 30)
        end
    end
end)

-- ==========================================
-- AUTO UP SLOT PET
-- ==========================================
-- Slot equip pet dibeli lewat mesin EquipSlots -- di inventory tab Pets,
-- tombol "+1 Equip" -- dan dibayar pakai Diamonds.
--
-- Terukur 2026-08-21 (akun mozenian, Tech World):
--
--     Network["EquipSlotsMachine_RequestPurchase"]:InvokeServer(nomorSlot)
--
-- Argumennya NOMOR SLOT BERIKUTNYA (PetSlotsPurchased + 1), BUKAN jumlah yang
-- mau dibeli. Buktinya: InvokeServer(1) dijawab `false` karena slot itu sudah
-- dimiliki, sedangkan InvokeServer(14) dijawab `true` dan memotong 3.500
-- Diamonds -- persis CalcPetSlotPrice(14). Memanggil tanpa argumen sama sekali
-- melempar assertion di Library.Asserts.
--
-- Harganya menanjak bertingkat, bukan linear: slot 13 = 3.250, slot 20 = 5.000,
-- slot 50 = 450.000. Batas atasnya 80 slot -- CalcPetSlotPrice(81) melempar
-- assertion, jadi jangan menembak di atas itu.
task.spawn(function()
    local BATAS_SLOT = 80

    -- CalcPetSlotPrice ada di Library.Balancing, yang menolak di-require dari
    -- identity executor. Pakai pembungkus yang sama dengan harga egg.
    local function hargaSlot(n)
        local ok, h = denganIdentitas2(function()
            local Calc = require(ReplicatedStorage.Library.Balancing.CalcPetSlotPrice)
            return Calc(n)
        end)
        if ok and tonumber(h) and tonumber(h) > 0 then return tonumber(h) end
        return nil
    end

    while true do
        task.wait(30)
        if not Config.autoPetSlot then
            PetSlotStatus.Text = "Slot pet: OFF"
            continue
        end

        pcall(function()
            local Save = require(Client:WaitForChild("Save"))
            local CurrencyCmds = require(Client:WaitForChild("CurrencyCmds"))
            local data = Save.Get()
            if not data then return end

            local dibeli = tonumber(data.PetSlotsPurchased) or 0
            local berikut = dibeli + 1
            if berikut > BATAS_SLOT then
                PetSlotStatus.Text = string.format("Slot pet: mentok (%d/%d)", dibeli, BATAS_SLOT)
                return
            end

            local harga = hargaSlot(berikut)
            if not harga then
                PetSlotStatus.Text = "Slot pet: harga tidak terbaca"
                return
            end

            -- Sisakan saldo sesuai setelan. Diamonds dipakai fitur lain juga,
            -- jadi jangan pernah dikuras sampai nol tanpa diminta.
            local sisaWajib = tonumber(Config.petSlotSisaDiamond) or 0
            local dia = tonumber(select(2, pcall(CurrencyCmds.Get, "Diamonds"))) or 0
            if dia - harga < sisaWajib then
                PetSlotStatus.Text = string.format("Slot pet: butuh %d, punya %d (sisa wajib %d)",
                    harga, dia, sisaWajib)
                return
            end

            local remote = Network:FindFirstChild("EquipSlotsMachine_RequestPurchase")
            if not remote then
                PetSlotStatus.Text = "Slot pet: remote hilang"
                return
            end

            local okKirim, jawab = pcall(function() return remote:InvokeServer(berikut) end)

            -- Server memang menjawab boolean, tapi jangan berhenti di situ:
            -- yang sah adalah PetSlotsPurchased benar-benar naik.
            task.wait(1)
            local data2 = Save.Get()
            local sesudah = tonumber(data2 and data2.PetSlotsPurchased) or dibeli
            if sesudah > dibeli then
                PetSlotStatus.Text = string.format("Slot pet: %d -> %d (-%d dmd)",
                    dibeli, sesudah, harga)
            else
                PetSlotStatus.Text = string.format("Slot pet: ditolak di slot %d (jawab=%s)",
                    berikut, tostring(okKirim and jawab))
            end
        end)
    end
end)


-- Log senyap secara bawaan: modul di bawah jalan dalam loop, dan di layar
-- dengan banyak klien pesan berulang menutupi konsol game sendiri.
-- Nyalakan lewat getgenv().MozePS99Verbose = true saat mencari masalah.
local function catatPS(fmt, ...)
    if not (getgenv and getgenv().MozePS99Verbose) then return end
    print("[MozePS99] " .. string.format(fmt, ...))
end


-- ==========================================
-- AUTO BREAKOUT UPGRADE
--
-- KOREKSI 2026-08-28: toggle "Auto Breakout Upgrade" sudah ada di panel sejak
-- lama, tapi `Config.luckyAutoUpgrade` TIDAK PERNAH DIBACA di mana pun --
-- muncul persis dua kali di seluruh berkas: nilai awal toggle dan setternya.
-- Jadi selama ini ia menyala, tersimpan, dan tidak melakukan apa pun. Dari sisi
-- pemain itu tidak bisa dibedakan dari fitur yang bekerja, dan buyer melaporkan
-- "upgrade ga work". Mereka benar.
--
-- Jalurnya sama persis dengan Fiesta di atas: upgrade Lucky Breakout ternyata
-- **EventUpgrades**, bukan zone Upgrades. Terukur di akun uji, 9 upgrade
-- berawalan "LuckyBreakout" ada di Directory.EventUpgrades:
--
--     BoardSlots (Pet Slots, power 30)  BallPower (Pet Power)
--     BallSpeed (Pet Speed)             BuxBonus (Breakout Coin Boost)
--     BlockLuck                         EggTier (Better Eggs)
--     GiftDrops (Lucky Bag Drops)       TitanicChestLuck (power 0)
--     GargantuanChestLuck (power 0)
--
-- `UpgradeCmds` BUKAN jalurnya, dan itu sempat menyesatkan: fungsinya menerima
-- DUA argumen (idUpgrade, zona) sehingga panggilan satu argumen selalu balik
-- nil, seolah tidak ada apa-apa di sana.
local LUCKY_PRIORITAS_INTI = {
    "LuckyBreakoutBallPower",   -- damage dulu: semua hal lain ikut cepat
    "LuckyBreakoutBuxBonus",    -- lalu penghasilan coin, supaya sisanya menyusul
    "LuckyBreakoutBoardSlots",
    "LuckyBreakoutBallSpeed",
    "LuckyBreakoutBlockLuck",
    "LuckyBreakoutEggTier",
    "LuckyBreakoutGiftDrops",
    "LuckyBreakoutTitanicChestLuck",
    "LuckyBreakoutGargantuanChestLuck",
}

-- Sama seperti Fiesta: yang disebut lebih dulu dibeli lebih dulu, sisanya
-- diisi OTOMATIS dari Directory supaya upgrade baru yang ditambahkan game ikut
-- terbeli tanpa perlu menyunting script lagi.
local LUCKY_PRIORITAS = (function()
    local urut, sudah = {}, {}
    for _, id in ipairs(LUCKY_PRIORITAS_INTI) do
        urut[#urut + 1] = id
        sudah[id] = true
    end
    pcall(function()
        local D = require(ReplicatedStorage.Library.Directory.EventUpgrades)
        local tambahan = {}
        for id, d in pairs(D) do
            if type(d) == "table" and type(id) == "string"
                and string.sub(id, 1, 13) == "LuckyBreakout"
                and not sudah[id] then
                tambahan[#tambahan + 1] = id
            end
        end
        table.sort(tambahan)  -- urutan pairs tidak terdefinisi; jangan acak
        for _, id in ipairs(tambahan) do urut[#urut + 1] = id end
    end)
    return urut
end)()

task.spawn(function()
    pcall(function() if setthreadidentity then setthreadidentity(2) end end)
    while generasiIni() do
        task.wait(15)

        if Config.luckyAutoUpgrade then
            pcall(function()
                local EU = require(Client:WaitForChild("EventUpgradeCmds"))
                local terbeli, tierBaru

                for _, nama in ipairs(LUCKY_PRIORITAS) do
                    -- Tidak ada API "sudah max" yang terekspos, jadi tidak ada
                    -- yang bisa ditanyakan lebih dulu: Purchase sendiri yang
                    -- menolak, entah karena max entah karena coin kurang.
                    -- Keduanya aman -- yang ditolak tidak memakan apa pun.
                    local ok, berhasil = pcall(EU.Purchase, nama)
                    if ok and berhasil == true then
                        terbeli = nama
                        -- Dijeda sebentar sebelum membaca tier: dibaca seketika
                        -- sesudah Purchase, nilainya masih yang LAMA (terukur
                        -- melaporkan "tier 0" padahal sudah jadi 1), dan status
                        -- yang salah lebih buruk daripada status yang telat.
                        task.wait(0.3)
                        tierBaru = select(2, pcall(EU.GetTier, nama))
                        break -- satu pembelian per siklus
                    end
                end

                if terbeli then
                    MazeStatus.Text = string.format("Breakout upgrade: %s -> tier %s",
                        tostring(terbeli):sub(14), tostring(tierBaru))
                    catatPS("breakout upgrade %s -> tier %s", tostring(terbeli), tostring(tierBaru))
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO KLAIM CHEST BERWAKTU (Titanic & GARG)
--
-- Keduanya mesin TimedReward, bukan tombol UI:
--   Directory.TimedRewards.LuckyBreakoutTitanicChest    Cooldown=3600
--   Directory.TimedRewards.LuckyBreakoutGargantuanChest Cooldown=3600
--
-- Model-nya di Workspace.__THINGS.Plots.<N>.Interactable.Machines.<nama>,
-- bertuliskan "TITANIC Chest! / Claim!". TIDAK ada ProximityPrompt maupun
-- ClickDetector -- satu-satunya jalur adalah BERDIRI DI ATAS part `Pad`.
--
-- KOREKSI 2026-08-28: versi pertama memakai MachineCmds.CanUse sebagai penanda
-- "chest siap". Dua-duanya salah. Dibaca dari sumbernya, CanUse(p1) menerima
-- NAMA MESIN (string) -- `table.find(t2, p1)`, `t.Owns(p1)` -- jadi mengirim
-- Model membuatnya selalu false, dan fitur ini tidak pernah berangkat sekali
-- pun. Lebih dalam lagi, isinya cuma cek JARAK <= 80 stud; itu "cukup dekat
-- untuk dipakai", bukan "sudah boleh diklaim".
--
-- Penanda siap yang benar ada di simpanan pemain:
--   Save.Get().TimedRewardTimestamps[<id>]  vs  Directory.TimedRewards[<id>].Cooldown
-- Terukur di akun uji: cap terakhir 1787491284, waktu server 1787856355 --
-- lewat 101 jam dari cooldown 1 jam, jadi memang sudah siap sejak lama
-- sementara CanUse tetap melaporkan false untuk kedelapan mesin.
--
-- Requirement() milik Directory tidak bisa dipanggil dari client (ia menyentuh
-- ServerScriptService.Library), jadi tidak dipakai -- biar server yang menolak.
local CHEST_BERWAKTU = { "LuckyBreakoutTitanicChest", "LuckyBreakoutGargantuanChest" }

-- Sisa cooldown dalam detik; 0 berarti siap. nil kalau data belum ada.
local function chestSisaCooldown(id)
    if not Client then return nil end
    local modSave = Client:FindFirstChild("Save")
    local dirTR = ReplicatedStorage.Library:FindFirstChild("Directory")
    dirTR = dirTR and dirTR:FindFirstChild("TimedRewards")
    if not (modSave and dirTR) then return nil end

    local ok, sisa = pcall(function()
        local simpanan = require(modSave).Get()
        if not simpanan then return nil end
        local cap = simpanan.TimedRewardTimestamps and simpanan.TimedRewardTimestamps[id]
        local cooldown = tonumber(require(dirTR)[id] and require(dirTR)[id].Cooldown) or 3600
        -- Belum pernah diklaim: StartsOnCooldown=true, tapi tanpa cap kita
        -- tidak punya acuan -- anggap siap dan biarkan server yang memutuskan.
        if not cap then return 0 end
        local lewat = os.time() - tonumber(cap)
        return math.max(0, cooldown - lewat)
    end)
    if not ok then return nil end
    return sisa
end

-- Mengembalikan part Pad terdekat dari chest yang cooldown-nya sudah habis.
local function chestSiap()
    local LP = game.Players.LocalPlayer
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local plots = workspace:FindFirstChild("__THINGS")
    plots = plots and plots:FindFirstChild("Plots")
    if not plots then return nil end

    local terbaik, jarakTerbaik, idTerbaik = nil, math.huge, nil
    for _, id in ipairs(CHEST_BERWAKTU) do
        local sisa = chestSisaCooldown(id)
        if sisa == 0 then
            for _, plot in ipairs(plots:GetChildren()) do
                local mesin = plot:FindFirstChild("Interactable")
                mesin = mesin and mesin:FindFirstChild("Machines")
                local model = mesin and mesin:FindFirstChild(id)
                -- Pad, bukan pivot model: pivot jatuh di tengah tumpukan
                -- (Chest, Present, Pile), sedangkan yang dibaca game cuma Pad.
                local pad = model and model:FindFirstChild("Pad")
                if pad and pad:IsA("BasePart") then
                    local j = (pad.Position - hrp.Position).Magnitude
                    -- Terdekat, bukan yang pertama ketemu: satu nama muncul di
                    -- tiap plot pemain, dan mesin milik orang lain berarti
                    -- melintasi peta tanpa hasil.
                    if j < jarakTerbaik then
                        terbaik, jarakTerbaik, idTerbaik = pad, j, id
                    end
                end
            end
        end
    end
    return terbaik, jarakTerbaik, idTerbaik
end

task.spawn(function()
    pcall(function() if setthreadidentity then setthreadidentity(2) end end)
    task.wait(12)
    while generasiIni() do
        if not Config.autoChestBerwaktu then
            task.wait(10)
        else
            local ok, err = pcall(function()
                local pad, jarak, id = chestSiap()
                if not pad then return end
                local LP = game.Players.LocalPlayer
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local asal = hrp.CFrame
                local atas = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 4, 0)
                local tahan = tonumber(Config.chestTahanDetik) or 4

                -- Dipasang ULANG tiap 0,3 detik selama menahan: sekali set lalu
                -- ditinggal membuat karakter melayang turun/terpental dan
                -- "berdiri di atas" tidak pernah terbaca penuh.
                local habis = os.clock() + tahan
                while os.clock() < habis do
                    hrp.CFrame = CFrame.new(atas)
                    task.wait(0.3)
                end

                local sisa = chestSisaCooldown(id)
                if Config.chestKembaliKeAsal then hrp.CFrame = asal end
                catatPS("chest %s: jarak %d, sisa cooldown sesudahnya %s",
                    tostring(id), math.floor(jarak or 0), tostring(sisa))
            end)
            if not ok then catatPS("chest galat: %s", tostring(err):sub(1, 70)) end
            task.wait(tonumber(Config.chestJeda) or 60)
        end
    end
end)

-- ==========================================
-- AUTO TELEPORT KE EVENT + SIMPAN POSISI
--
-- RandomEventCmds.GetActive() mengembalikan peta {id = data}; GetZone(id)
-- memberi zona tempat event itu berlangsung. TeleportMapCmds.TeleportZones
-- yang memindahkan.
--
-- Posisi asal DISIMPAN sebelum berangkat dan dikembalikan saat event habis --
-- tanpa itu, bot yang tadinya farming di zona tertentu tidak pernah pulang dan
-- diam-diam berhenti menghasilkan.
local posisiSimpan = nil
local eventTerakhir = nil

task.spawn(function()
    pcall(function() if setthreadidentity then setthreadidentity(2) end end)
    task.wait(15)
    local RE, TM
    for _ = 1, 30 do
        pcall(function()
            RE = require(Client:WaitForChild("RandomEventCmds"))
            TM = require(Client:WaitForChild("TeleportMapCmds"))
        end)
        if RE and TM then break end
        task.wait(1)
    end
    if not (RE and TM) then
        catatPS("event: modul tidak ketemu, fitur dilewati")
        return
    end

    while generasiIni() do
        if not Config.autoTpEvent then
            task.wait(8)
        else
            local ok, err = pcall(function()
                local aktif = RE.GetActive()
                local idEvent, zona
                if type(aktif) == "table" then
                    for id in pairs(aktif) do
                        idEvent = id
                        zona = select(2, pcall(function() return RE.GetZone(id) end))
                        break
                    end
                end

                local LP = game.Players.LocalPlayer
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                if idEvent and zona then
                    if idEvent ~= eventTerakhir then
                        -- Simpan HANYA saat berangkat pertama kali. Menyimpan ulang
                        -- tiap putaran akan merekam posisi di lokasi event, dan
                        -- "pulang" jadi tidak berarti apa-apa.
                        if not posisiSimpan then posisiSimpan = hrp.CFrame end
                        eventTerakhir = idEvent
                        local berhasil = select(2, pcall(function() return TM.TeleportZones(zona) end))
                        catatPS("event %s -> zona %s (%s)", tostring(idEvent):sub(1, 8),
                            tostring(zona), tostring(berhasil))
                    end
                elseif eventTerakhir then
                    -- Event selesai: pulang ke tempat semula.
                    eventTerakhir = nil
                    if posisiSimpan and Config.eventPulangKeAsal then
                        hrp.CFrame = posisiSimpan
                        catatPS("event habis, kembali ke posisi tersimpan")
                    end
                    posisiSimpan = nil
                end
            end)
            if not ok then catatPS("event galat: %s", tostring(err):sub(1, 70)) end
            task.wait(tonumber(Config.eventJeda) or 20)
        end
    end
end)

-- Pasang blackscreen
pasangBlackScreen()

-- @MOZEFRAME-EOF@ (penanda akhir berkas — router menolak file tanpa baris ini)
