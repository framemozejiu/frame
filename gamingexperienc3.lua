--[[
    SMART KAITUN — FALL HARVEST
    Sekali eksekusi: beli -> tanam -> panen -> jual -> ulang, sambil menjalankan
    Cornucopia Quest, dengan mode speedrun Leaves saat kebun sudah bagus.

    Untuk dunia event "Fall Harvest", BUKAN Grow a Garden 2.

    ---------------------------------------------------------------------------
    SEMUA signature di bawah ditangkap dari panggilan ASLI di klien, bukan
    ditebak. Jangan diubah tanpa menangkap ulang:

      SeedShop.PurchaseSeed:Fire("Maple Carrot")
      Plant.PlantSeed:Fire(Vector3, "Maple Strawberry", Tool)   -- Tool WAJIB diequip
      Shovel.UseShovel:Fire("{userId}_{guid}", "", "Shovel", ToolShovel)
      Garden.CollectFruit:Fire("{guid}", "{indeksBuah}")
      NPCS.PreviewSellAll()  lalu  NPCS.SellAll()               -- tanpa argumen

    Dua jebakan yang cuma ketahuan dari data asli:
      1. UseShovel memakai plantId BER-PREFIX "{userId}_{guid}", sedangkan
         CollectFruit memakai guid TELANJANG + indeks buah. Nama model tanaman
         di workspace berbentuk "{userId}_{guid}_{n}", jadi ketiganya diurai
         dari satu nama itu.
      2. Jual butuh staging: PreviewSellAll dipanggil lebih dulu, kalau tidak
         server menolak diam-diam (pola yang sama dengan SellAll di GAG2).

    Soal jarak: dugaan awal "semua fire wajib dari jarak dekat" ternyata TERLALU
    LUAS. Diuji langsung di lapangan, panen, tanam, jual, dan cabut semuanya
    diterima server dari jarak jauh.

    Yang WAJIB mendekat tinggal MEMBELI, dan itu bukan soal berhasil-tidaknya:
    PurchaseSeed dari jauh tetap diterima, tapi anticheat menandainya dan ban
    menyusul belakangan. Karena itu jalur beli tidak punya opsi untuk dimatikan,
    dan kalau NPC-nya tak tercapai, pembelian dibatalkan seluruhnya.

    Geraknya sendiri memakai BodyVelocity berkecepatan tetap (default 22 studs/s).
    Versi pertama memakai BodyPosition yang menarik dengan gaya besar sehingga
    karakter melesat -- terlihat jelas tidak wajar.
]]

-- ==========================================
-- SISTEM VERIFIKASI HWID & DISCORD (MOZEFRAME)
-- ==========================================
-- Diport dari kaitun_main.txt. Panel key-nya SAMA, jadi buyer yang sudah punya
-- akses langsung bisa memakai script ini tanpa key baru.
--
-- PanelKey diterima dari DUA tempat: MuzeFallHarvestConfig (kalau kamu mengaturnya
-- khusus) maupun MuzeAutoBuyConfig (format snippet yang sudah dipakai panel).
-- Dengan begitu loader lama tidak perlu diubah bentuknya.
local cfgFH  = getgenv().MuzeFallHarvestConfig or {}
local cfgMain = getgenv().MuzeAutoBuyConfig or {}

local raw_panel_key = cfgFH.PanelKey or cfgMain.PanelKey or ""
local panel_key = raw_panel_key
if string.find(raw_panel_key, "/") then
    panel_key = string.split(raw_panel_key, "/")[1]
end

-- URL server Railway (pengganti Firebase)
local SERVER_URL = "https://mozeframe.my.id"

local hwid = gethwid and gethwid() or ""
if hwid == "" then
    local client_id = game:GetService("RbxAnalyticsService"):GetClientId()
    hwid = "RBX-" .. client_id
end

local function forceRejoin(reason)
    pcall(function()
        warn("Force Rejoining... Reason: " .. tostring(reason))
        game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
    end)
    task.wait(5)
    game.Players.LocalPlayer:Kick(reason)
end

-- GERBANG KEY DICABUT.
--
-- Whitelist sepenuhnya dipegang Luaegis di lapisan loader: kalau device tidak
-- berhak, script ini tidak pernah sampai untuk dijalankan. Memeriksa ulang di
-- sini tidak menambah proteksi apa pun -- yang ia tambahkan cuma dua cara
-- gagal, dan keduanya sudah terbukti buruk:
--
--   1. Server tak terjangkau -> forceRejoin() -> teleport ke place yang sama
--      -> gagal lagi -> teleport lagi. Lingkaran rejoin tanpa ujung; bot tidak
--      pernah main, cuma berputar.
--
--   2. Server membalas HTML, bukan JSON (halaman parkir domain kedaluwarsa
--      membalas 200). pcall di atasnya BERHASIL, lalu JSONDecode melempar --
--      terbaca sebagai bug script, padahal domainnya yang habis.
--
-- panel_key tetap dibaca di atas: sync config masih memakainya. Yang hilang di
-- sini hanya pemeriksaannya, bukan nilainya.
-- ==========================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local LocalPlayer        = Players.LocalPlayer



-- ==========================================
-- TUTORIAL BYPASS (MEMBANTU AKUN BARU AGAR TIDAK STUCK DI 1 LEAF)
-- ==========================================
-- Berlaku di SEMUA mode, termasuk Mode Buy: blok ini berjalan sebelum Config
-- dibangun, jadi tidak ada setelan yang bisa mematikannya. Mode Buy justru yang
-- paling membutuhkannya -- akun baru mendarat di tutorial dengan 1 Leaf, dan
-- seluruh pekerjaan mode itu adalah belanja.
--
-- Terverifikasi live di Fall Harvest: Networking.Tutorial ada dengan Complete,
-- Ready, dan Start -- bentuknya sama persis dengan World 1.
--
-- TIGA perbaikan dari versi sebelumnya:
--
-- 1. TutorialCompleted TIDAK LAGI DITULIS SENDIRI. Versi lama menembak
--    Complete:Fire() lalu menyetel atribut itu true dari klien -- padahal itulah
--    satu-satunya penanda yang direplikasi SERVER, dan dipakai loop ini sendiri
--    sebagai syarat berhenti. Akibatnya loop selalu berhenti di putaran kedua
--    entah server menerima atau menolak, dan akun yang gagal keluar tutorial
--    terlihat persis seperti akun yang berhasil.
--
-- 2. Jendelanya diperpanjang. 15 x 1,5 detik = 22 detik, sekali di awal script.
--    Script ini sendiri menunggu akun siap sampai TungguSiapDetik = 300 detik
--    karena akun baru bisa selama itu tertahan cutscene -- jadi versi lama sering
--    menghabiskan seluruh percobaannya sebelum tutorialnya sempat mulai.
--
-- 3. Scroll SeedShop ikut dibuka. Tutorial mengunci ScrollingEnabled di langkah
--    beli benih, dan stokShop() membaca stok dari GUI itu. Terukur ada DUA
--    ScrollingFrame di sana (NormalShop dan ExclusiveShop), jadi keduanya dibuka.
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")

    -- Pembersihan sisi klien. Dikumpulkan jadi satu karena dipakai di dua tempat:
    -- tiap percobaan, dan sekali lagi saat server sudah mengakui -- runner klien
    -- bisa menggantung walau tutorialnya sendiri sudah selesai di server.
    local function bersihkanSisiKlien()
        -- InTutorial dihapus TutorialController MILIK KLIEN, bukan server. Kalau
        -- runner-nya berhenti di tengah dialog, atribut ini tidak akan pernah
        -- hilang sendiri.
        pcall(function() workspace:SetAttribute("InTutorial", nil) end)
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local ui = pg and pg:FindFirstChild("TutorialUI")
            if ui then ui.Enabled = false end
        end)
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local shop = pg and pg:FindFirstChild("SeedShop")
            local frame = shop and shop:FindFirstChild("Frame")
            if not frame then return end
            for _, c in ipairs(frame:GetChildren()) do
                if c:IsA("ScrollingFrame") then c.ScrollingEnabled = true end
            end
        end)
    end

    local batas = os.clock() + 600
    local percobaan = 0

    while os.clock() < batas do
        -- Syarat berhentinya HANYA atribut milik server. Sekarang itu bermakna,
        -- karena tidak ada lagi yang menuliskannya dari sisi kita.
        if LocalPlayer:GetAttribute("TutorialCompleted") == true then
            if percobaan > 0 then
                warn(string.format("[TUTORIAL] Diakui server setelah %d percobaan", percobaan))
            end
            bersihkanSisiKlien()
            return
        end

        percobaan = percobaan + 1
        pcall(function()
            local net = require(RS:WaitForChild("SharedModules"):WaitForChild("Networking"))
            if net and net.Tutorial and net.Tutorial.Complete then
                net.Tutorial.Complete:Fire()
            end
        end)
        bersihkanSisiKlien()

        -- Rapat di awal, lalu melambat. Menembak remote tiap 3 detik selama
        -- sepuluh menit itu 200 tembakan -- tidak perlu, dan pola sekencang itu
        -- justru yang menonjol. Akun yang memang di tutorial hampir selalu selesai
        -- di percobaan pertama; jendela panjangnya untuk yang tutorialnya belum
        -- sempat mulai, dan untuk itu menunggu jauh lebih tepat daripada memaksa.
        task.wait(percobaan <= 5 and 3 or 15)
    end

    warn("[TUTORIAL] Belum diakui server setelah 10 menit — akun mungkin masih terkunci di tutorial")
end)
-- Dibaca sekali di blok verifikasi di atas; dipakai ulang di sini supaya tidak
-- ada dua sumber kebenaran untuk config yang sama.
local cfg = cfgFH
local Config = {
    AutoBeli      = cfg.AutoBeli ~= false,
    AutoTanam     = cfg.AutoTanam ~= false,
    AutoPanen     = cfg.AutoPanen ~= false,
    AutoJual      = cfg.AutoJual ~= false,
    AutoQuest     = cfg.AutoQuest ~= false,
    -- Mengambil seed jatuhan (gold, rainbow, mega, dll) lewat pemindaian
    -- ProximityPrompt -- diport dari kaitun utama.
    AutoAmbilSeed = cfg.AutoAmbilSeed ~= false,

    -- MODE BELI SAJA ("force kaitun").
    --
    -- Nyala = akun ini HANYA belanja seed dan memungut seed jatuhan. Tanam,
    -- pasang sprinkler, siram, panen, dan cabut semuanya dimatikan paksa.
    --
    -- Default MATI: ini mode khusus, bukan perilaku normal. Menyalakannya di
    -- akun yang sedang bertani akan menghentikan seluruh siklus taninya.
    ModeBeliSaja = cfg.ModeBeliSaja ~= false,

    -- Daftar seed yang diborong, urut PRIORITAS. Bukan satu nama lagi:
    -- Maple Mushroom punya profil yang jauh berbeda dari Maple Bamboo --
    -- harga 15.000 vs 700, Epic vs Rare, PrimeTime 360 vs 120 detik, dan
    -- peluang restock 9,1% vs 80% dengan jatah 2-5 vs 7-11 per restock.
    -- Karena itu mushroom didahulukan: stoknya langka dan cepat direbut,
    -- sedangkan bambu hampir selalu tersedia.
    SeedTarget       = cfg.SeedTarget or { "Maple Mushroom", "Maple Bamboo" },
    -- ==== BAKE SALE / THE BAKER ====
    -- Semua DEFAULT MATI. Memasak menghabiskan buah hasil panen -- menyalakan
    -- diam-diam berarti membakar panen orang tanpa diminta.
    AutoMasak        = cfg.AutoMasak == true,
    -- ARRAY nama muffin, bukan map. terapkanConfig menolak tabel yang bukan
    -- array, jadi bentuk {nama=true} akan diabaikan tanpa pesan apa pun.
    -- Terukur ada empat: Blueberry / Pumpkin / Carrot / Rainbow Muffin.
    ResepMuffin      = cfg.ResepMuffin or {},
    -- Beli bahan yang kurang dari Baker shop (bukan dari seed shop biasa --
    -- shop itu punya prioritas SeedTarget sendiri yang tidak boleh digeser).
    AutoBeliBahanBaker = cfg.AutoBeliBahanBaker == true,
    -- Menukar muffin ke hadiah itu SATU ARAH, jadi saklarnya sendiri.
    AutoTukarMuffin  = cfg.AutoTukarMuffin == true,
    -- Bake 600 detik; 20 detik sudah jauh lebih rapat dari yang dibutuhkan.
    JedaMasak        = tonumber(cfg.JedaMasak) or 20,

    GearSprinkler    = cfg.GearSprinkler or "Syrup Sprinkler",
    GearSiram        = cfg.GearSiram or "Syrup Watering Can",

    -- Daftar gear yang boleh dibeli, urut prioritas.
    --
    -- Cadangannya dua kunci lama supaya panel versi lama yang hanya mengirim
    -- GearSprinkler/GearSiram tetap jalan apa adanya. Tanpa itu, akun yang
    -- belum menerima config baru akan berhenti membeli gear sama sekali --
    -- diam, tanpa error, dan baru ketahuan setelah kebun kering berjam-jam.
    GearTarget       = cfg.GearTarget or { cfg.GearSprinkler or "Syrup Sprinkler",
                                           cfg.GearSiram or "Syrup Watering Can",
                                           "Trowel" },
    -- Batas simpan gear. **0 = tanpa batas.**
    --
    -- Dulu default 3, dan itu salah kaprah: gear di game ini MENUMPUK dalam satu
    -- Tool beratribut Count, bukan banyak item terpisah. Terukur di akun nyata:
    -- satu Tool bernama "Trowel" dengan Count=49. Jadi batas 3 dibandingkan
    -- melawan isi tumpukan — sekali beli, tumpukannya melewati 3 dan pembelian
    -- mati SELAMANYA. Gejalanya persis "beli sekali lalu berhenti".
    --
    -- Niat aslinya tetap kuhormati (jangan memborong Bull Horn/Wind Staff sampai
    -- Leaves habis), tapi itu kini keputusan pemilik akun lewat panel, bukan
    -- angka mati yang mematikan fitur untuk semua orang.
    MaksGearDisimpan = tonumber(cfg.MaksGearDisimpan) or 0,
    -- 3-5 siraman per siklus. Lebih dari itu terbuang: pertumbuhan sudah penuh.
    SiramPerSiklus   = tonumber(cfg.SiramPerSiklus) or 4,
    -- Jumlah sprinkler yang dipasang per siklus. Kebun punya dua sisi plot,
    -- jadi dua sudah menutupi keduanya; lebih dari itu hanya menumpuk di titik
    -- yang sama dan terbuang.
    MaksSprinkler    = tonumber(cfg.MaksSprinkler) or 2,

    -- Sprinkler & watering can menguntungkan tanaman apa pun: sprinkler
    -- mempercepat tumbuh
    -- (GrowSpeedBonus) sekaligus menaikkan berat lewat SizeLuckBonus, dan berat
    -- itulah yang paling menentukan harga jual karena nilainya berpangkat.
    AutoSprinkler    = cfg.AutoSprinkler ~= false,
    AutoSiram        = cfg.AutoSiram ~= false,
    -- Beli gear-nya sendiri saat stok ada dan belum punya.
    AutoBeliGear     = cfg.AutoBeliGear ~= false,

    -- Batas frame. Sasarannya perangkat yang menjalankan 8-10 klien Roblox
    -- sekaligus -- di sana render adalah pemakan CPU terbesar, sedangkan bot
    -- tidak butuh frame tinggi sama sekali. Terukur: 125 fps -> 19 fps.
    --
    -- TIDAK BOLEH terlalu rendah. Loop terbang memakai RunService.Heartbeat,
    -- yang berdetak sekali per frame, jadi batas ini menentukan kerapatan
    -- koreksi arah dan pemasangan ulang noclip. Kecepatannya sendiri tidak
    -- terpengaruh (BodyVelocity dijalankan mesin fisika), tapi di bawah ~10 fps
    -- kemudinya mulai kasar dan karakter bisa menyangkut. Karena itu dijepit.
    -- Set 0 untuk mematikan pembatasan sepenuhnya.
    BatasFps      = (function()
        local v = tonumber(cfg.BatasFps) or 20
        if v <= 0 then return 0 end
        return math.max(10, math.min(240, v))
    end)(),
    -- Kebun orang lain dimuat bertahap seiring pemain berdatangan, jadi
    -- pembersihannya diulang. Murah (~1,2 ms, hanya menyentuh Gardens).
    -- Diturunkan 5 -> 2. Terukur di server sungguhan: Gardens menyumbang 16.903
    -- dari 22.233 instance workspace (76%), dan ia TUMBUH TERUS selama pemain
    -- berdatangan. Dengan jeda 5 siklus, kebun orang menumpuk cukup lama untuk
    -- mengembalikan sebagian besar beban yang baru saja dibuang.
    SiklusBersihKebun = tonumber(cfg.SiklusBersihKebun) or 2,

    -- Pindah server saat korban di server ini habis, untuk quest
    -- "Steal from N different people".
    --
    -- Server cuma muat 8 orang -> maksimal 7 korban, sementara quest bisa minta
    -- 15. Tanpa ini quest mentok di angka itu. Default MATI: pindah server
    -- memutus siklus tani dan memicu batas laju teleport Roblox.
    StealPindahServer = cfg.StealPindahServer == true,

    -- Sudah diuji terarah di kebun sungguhan: dari 27 tanaman, yang terpilih
    -- adalah Maple Strawberry (rarity terendah) -- bukan Bamboo/Cactus yang
    -- rarity-nya tinggi -- dan kebun turun 27 -> 26. Karena pemilihan target,
    -- gerak, dan remote-nya terbukti benar, default-nya dinyalakan.
    -- Set false kalau ingin mematikannya.
    -- Pencabutan untuk UPGRADE: cabut satu tanaman terendah, ganti dengan seed
    -- yang rarity-nya lebih tinggi. Ini rantai inti smart kaitun -- mencabut satu
    -- per satu untuk ditukar, BUKAN membabat kebun.
    AutoCabut     = cfg.AutoCabut ~= false,

    -- Selisih rarity MINIMUM sebelum sebuah tanaman boleh dicabut.
    --
    -- Tanpa ambang, kebun terus-menerus ditukar untuk kenaikan satu tingkat --
    -- Common ditukar Uncommon, lalu Uncommon ditukar Rare -- dan tiap tukar
    -- membuang tanaman yang sudah tumbuh beserta seluruh waktunya. Dengan
    -- ambang 2, pencabutan hanya terjadi kalau lompatannya memang berarti.
    -- Default 2 -> 1.
    --
    -- Dengan 2, seed Rare(r3) TIDAK bisa menggantikan tanaman Uncommon(r2):
    -- selisihnya cuma 1, jadi tanaman itu tidak pernah masuk daftar cabut dan
    -- kebun mentok di rarity rendah walau seed yang lebih baik sudah di tas.
    -- Itu gejala yang dilaporkan langsung dari lapangan.
    --
    -- Nilai 1 berarti "cukup lebih tinggi satu tingkat". Tetap bisa dinaikkan
    -- dari panel kalau penukaran satu tingkat dirasa terlalu boros.
    AmbangSelisihCabut = tonumber(cfg.AmbangSelisihCabut) or 1,

    -- Jumlah tanaman maksimum di kebun. 0 = tanpa batas (lahan fisik yang
    -- menentukan, seperti sebelum fitur ini ada).
    --
    -- Setelah batas tercapai kebun TIDAK berhenti bekerja -- ia beralih dari
    -- menambah jumlah ke menaikkan mutu: seed yang rarity-nya lebih tinggi
    -- mencabut satu tanaman terlemah dan menggantikannya. Seed yang tidak lebih
    -- tinggi tidak menggantikan apa pun, jadi isi kebun tidak pernah turun mutu.
    BatasTanam = tonumber(cfg.BatasTanam) or 0,

    -- Hanya beli seed yang rarity-nya DI ATAS tanaman terlemah di kebun, walau
    -- kebun masih ada ruang.
    --
    -- Kebun yang semuanya sudah r3 tidak lagi membeli r3 -- Leaves-nya disimpan
    -- untuk r4. Konsekuensinya disengaja: kalau shop sedang tidak menjual apa pun
    -- di atas r3, tanah kosong DIBIARKAN kosong sampai restock berikutnya.
    -- Itu pertukaran yang benar kalau tujuannya naik rarity secepatnya; matikan
    -- dari panel kalau lebih mementingkan tiap petak selalu terisi.
    FokusRarityNaik = cfg.FokusRarityNaik ~= false,

    -- Ambang speedrun Leaves: begitu tanaman di kebun sudah mencapai rarity ini
    -- atau lebih, berhenti belanja dan fokus panen-jual.
    AmbangSpeedrun = cfg.AmbangSpeedrun or "Epic",

    -- Seed yang TIDAK boleh ditanam (dikirim dari panel).
    -- Seed tetap dibeli — filter ini hanya di jalur tanam.
    IgnoreSeeds = type(cfg.IgnoreSeeds) == "table" and cfg.IgnoreSeeds or {},

    JedaSiklus    = tonumber(cfg.JedaSiklus) or 5,
    JedaAksi      = tonumber(cfg.JedaAksi) or 0.35,
    -- 0.05 detik = 50 ms, persis ambang yang dipaksakan klien resmi game:
    -- PlantController menolak penanaman kalau jaraknya kurang dari 0.05 detik
    -- (`if v57 - u2 < 0.05 then return false end`). Menembak lebih rapat dari itu
    -- berarti mengirim lebih cepat daripada yang MUNGKIN dilakukan pemain asli --
    -- pola yang persis dicari anticheat. Bisa diturunkan lewat config kalau kamu
    -- memang mau menanggung risikonya.
    JedaTanam     = tonumber(cfg.JedaTanam) or 0.05,

    -- Jarak minimum antar tanaman. Plot terukur 115 x 18 studs, sementara
    -- tanaman menumpuk dalam rentang 7 studs -- titik acak murni memang mudah
    -- berkerumun. Dengan jarak 5, plot ini muat sekitar 80 tanaman.
    JarakTanam    = tonumber(cfg.JarakTanam) or 5,
    -- Berapa kali mencari titik kosong sebelum kebun dianggap penuh.
    -- Dinaikkan dari 25: dengan jarak 5 studs di kebun yang setengah terisi,
    -- 25 lemparan acak kadang meleset semua dan kebun dikira penuh padahal masih
    -- ada ruang -- lalu cabut ikut terpicu terlalu dini.
    CobaTitik     = tonumber(cfg.CobaTitik) or 60,

    -- Jeda saat berpindah dari satu jenis seed ke jenis berikutnya. Berbeda dari
    -- JedaTanam (antar biji dalam satu tumpukan): pergantian seed melibatkan
    -- equip tool baru, dan tanpa jeda equip-nya belum selesai saat tembakan
    -- pertama dikirim -- itu yang membuatnya terlihat "loncat seed terlalu cepat".
    JedaGantiSeed = tonumber(cfg.JedaGantiSeed) or 1.0,

    BlackScreen   = cfg.BlackScreen ~= false,
    AntiAFK       = cfg.AntiAFK ~= false,

    -- ==== PENGHEMAT TAMPILAN: TIDAK ADA DI SINI LAGI ====
    --
    -- FpsBoost, Bekukan, SembunyikanTanaman, SembunyikanBuah, dan HapusAnimasi
    -- sekarang PERMANEN dan tidak lagi lewat config. Sasaran sesungguhnya adalah
    -- 8-10 akun dalam SATU perangkat cloud, dan di sana tidak ada seorang pun
    -- yang menonton layarnya -- jadi tidak ada keadaan di mana mematikannya
    -- berguna, sementara satu akun yang lupa dimatikan ikut menyeret sembilan
    -- lainnya.
    --
    -- Key-nya sengaja DIHAPUS dari tabel ini, bukan sekadar diberi default true.
    -- terapkanConfig() hanya menyalin key yang sudah ada di Config, jadi selama
    -- key-nya masih di sini, config LAMA yang tersimpan di panel (berisi false)
    -- akan mematikannya lagi diam-diam setiap sync.

    -- Setelah ambang speedrun, SeedTarget berhenti jadi urutan prioritas dan
    -- berubah jadi daftar beli untuk ditimbun. Default MATI: biarkan tanaman
    -- di kebun habis dijual, jangan beli lagi saat speedrun.
    BeliTargetSaatSpeedrun = cfg.BeliTargetSaatSpeedrun == true,

    -- ==== GATE PEMUATAN & WATCHDOG MACET ====
    --
    -- 120 detik dulu dipilih dengan asumsi "cutscene perkenalan jauh lebih pendek
    -- dari itu". Untuk akun BARU asumsi itu tidak berlaku -- terlihat langsung di
    -- cloud: 8 akun baru, runtime 1 jam lebih, Planted 0 semua.
    TungguSiapDetik = tonumber(cfg.TungguSiapDetik) or 300,

    -- Setelah gate dilepas karena timeout, sekian detik lagi boleh mencoba
    -- menunggu penuh SEKALI lagi. Dulu pelepasannya permanen, jadi penahan yang
    -- sifatnya sementara pun mengunci sisa sesi.
    GateCobaLagiDetik = tonumber(cfg.GateCobaLagiDetik) or 600,

    -- Rejoin saat Leaves macet di ambang bawah. Ambangnya NOL, bukan "tidak
    -- berubah": akun yang menimbun 5000 Leaves tanpa belanja itu sehat, sedangkan
    -- nol selama lima menit tidak pernah normal.
    RejoinSaatMacet   = cfg.RejoinSaatMacet ~= false,
    MacetDetik        = tonumber(cfg.MacetDetik) or 300,
    MacetLeavesAmbang = tonumber(cfg.MacetLeavesAmbang) or 0,

    -- ==== FREEZE / NETWORK WATCHDOG ====
    --
    -- Deteksi game yang benar-benar nyangkut (CPU freeze atau network putus)
    -- dan paksa rejoin otomatis. Berbeda dengan watchdog Leaves macet di atas
    -- yang hanya menangani "bot jalan tapi tidak produktif" — ini menangani
    -- "bot MATI TOTAL" di mana bahkan siklus utama tidak berjalan.
    AntiFreeze        = cfg.AntiFreeze == true,
    FreezeDelayDetik  = tonumber(cfg.FreezeDelayDetik) or 15,
    FreezePingBatas   = tonumber(cfg.FreezePingBatas) or 10000,

    -- Kapasitas buah terbaca dari atribut MaxFruitCapacity (terukur 100).
    -- Begitu FruitCount menyentuh ambang ini, JUAL dulu sebelum memanen lagi --
    -- tanpa ini panen terus ditembak ke inventory penuh dan terlihat seperti
    -- "stuck spam harvest".
    AmbangJualBuah = tonumber(cfg.AmbangJualBuah) or 70,

    -- ==== TAHAN BUAH BERAT SAMPAI BERMUTASI ====
    -- Buah seberat ini atau lebih TIDAK dipanen selama belum bermutasi.
    -- Satuannya kilogram; 0 mematikan fitur.
    --
    -- Dasarnya rumus harga jual game (FruitValueCalc): nilai = dasar x berat^pangkat
    -- x pengali mutasi. Gold 10x dan Rainbow 30x itu PENGALI, jadi menempel pada
    -- buah yang sudah berat menghasilkan lompatan yang jauh lebih besar daripada
    -- pada buah 1kg. Memanennya sekarang mengunci nilainya di pengali 1x selamanya.
    TahanBeratMin   = tonumber(cfg.TahanBeratMin) or 10,
    -- Batas waktu menunggu. Tanpa ini, buah berat yang tidak pernah kena mutasi
    -- menyandera petaknya selamanya -- tanaman tidak bisa berbuah lagi dan
    -- kapasitas kebun berkurang permanen.
    TahanMaksJam    = tonumber(cfg.TahanMaksJam) or 6,
    JarakAman     = tonumber(cfg.JarakAman) or 12,

    -- Pakai tombol teleport bawaan game sebelum terbang.
    --
    -- Ini jalur yang disediakan developer sendiri -- tombol Garden/Seeds/Sell di
    -- layar memanggil remote yang sama persis, jadi dari sisi server tidak ada
    -- bedanya dengan pemain yang mengkliknya. Terbang lintas peta itu yang justru
    -- rapuh: sering meleset, dan pembelian gagal karena jarak ke NPC tidak pernah
    -- tercapai.
    PakaiTeleportGui = cfg.PakaiTeleportGui ~= false,

    -- ==== MENCURI SAAT MALAM WEREWOLF ====
    -- DEFAULT MATI. Mencuri berarti masuk kebun orang lain, dan itu kelas risiko
    -- yang berbeda dari sekadar mengurus kebun sendiri -- jadi harus dinyalakan
    -- sendiri, bukan menyala diam-diam setelah update.
    AutoStealMalam    = cfg.AutoStealMalam == true,
    StealMaksPerSiklus = tonumber(cfg.StealMaksPerSiklus) or 20,
    -- Quest Pilgrim "StealPeople" menghitung ORANG yang berbeda (3 sampai 15),
    -- bukan jumlah buah. Menguras satu kebun memberi banyak Leaves tapi nol
    -- kemajuan quest, jadi pemilik yang belum pernah dicuri didahulukan.
    StealUtamakanOrangBaru = cfg.StealUtamakanOrangBaru ~= false,

    -- Mengirim ketukan tombol palsu supaya akun tidak dihitung AFK.
    --
    -- DEFAULT MATI, dan sengaja dipisah dari AutoStealMalam. Ini satu-satunya
    -- bagian yang MEMALSUKAN masukan pemain, bukan memanggil remote game --
    -- kelas risikonya berbeda dan itu keputusanmu, bukan bawaan.
    --
    -- Kenapa ada: PlayerActivityController melaporkan AFK setelah 120 detik
    -- tanpa input ASLI (WerewolfFlags.AfkIdleSeconds), dan bot tidak pernah
    -- menghasilkan satu pun. Terukur: VirtualUser -- cara anti-AFK yang biasa
    -- dipakai -- menghasilkan NOL event InputBegan, jadi tidak berguna di sini.
    AntiAfk           = cfg.AntiAfk == true,

    -- ==== PINDAH KE SERVER SEPI ====
    -- DEFAULT MATI. Terukur di API server-list: dari 100 server place karantina,
    -- 89 berisi 1 orang -- jadi server sepi memang berlimpah, bukan barang langka.
    AutoCariServerSepi = cfg.AutoCariServerSepi == true,
    -- Pindah kalau server sekarang berisi LEBIH dari ini. Bawaan 3 dari kapasitas
    -- 8: cukup longgar supaya tidak pindah tiap ada satu orang masuk, tapi tetap
    -- menghindari server yang benar-benar ramai.
    BatasIsiServer     = tonumber(cfg.BatasIsiServer) or 3,
    -- Jeda minimum antar perpindahan. Tanpa ini bot bisa pindah terus-menerus:
    -- tiap server yang baru ditinggalkan langsung terlihat "lebih sepi" dari
    -- tujuannya, dan siklus berikutnya memindahkannya kembali.
    JedaHopMenit       = tonumber(cfg.JedaHopMenit) or 15,
    MaxBeliPerSiklus = tonumber(cfg.MaxBeliPerSiklus) or 20,

    -- studs/detik. Versi pertama memakai BodyPosition yang menarik dengan gaya
    -- besar, jadi karakter melesat ke tujuan -- terlihat jelas tidak wajar.
    -- Sekarang kecepatannya dibatasi dan bisa diatur.
    KecepatanTerbang = tonumber(cfg.KecepatanTerbang) or 22,

    -- Sudah diuji di lapangan: panen, tanam, dan jual TETAP diterima server dari
    -- jarak jauh, jadi tidak perlu terbang bolak-balik untuk itu. Cabut belum
    -- teruji, jadi untuk yang satu itu tetap mendekat -- lebih baik lambat
    -- daripada ditolak diam-diam.
    DekatSaatPanen = cfg.DekatSaatPanen == true,
    -- WAJIB true. Terbukti di lapangan: menanam ditolak total kalau pemain tidak
    -- berada di kebunnya sendiri (atribut IsInOwnGarden). Dari 183 studs, empat
    -- tembakan berturut-turut menghasilkan Count 3->3 dan nol tanaman; setelah
    -- terbang ke plot, tanaman naik 14 -> 16. Laporan awal "tanam bisa dari jauh"
    -- kebetulan diambil saat sedang berdiri di plot.
    DekatSaatTanam = cfg.DekatSaatTanam ~= false,
    -- DEFAULT NYALA sejak teleport GUI dipakai.
    --
    -- Dulu dimatikan bukan karena menjual dari jauh itu aman, tapi karena
    -- ongkosnya: terbang bolak-balik ke Steven memakan waktu siklus dan sering
    -- meleset. Itu sudah tidak berlaku -- tombol "Sell" mendaratkan 7 stud dari
    -- Steven, di bawah JarakAman 12, jadi mendekat kini nyaris gratis.
    -- Menjual dari jarak jauh memang DITERIMA server, dan justru itu bahayanya:
    -- transaksinya lolos sementara akunnya ditandai.
    DekatSaatJual  = cfg.DekatSaatJual ~= false,
    -- Sudah diuji: cabut juga diterima dari jarak jauh, jadi tidak perlu lagi
    -- terbang ke tiap tanaman. Menyisakan HANYA pembelian yang wajib mendekat.
    -- Mendekat dulu sebelum mencabut. DEFAULT NYALA sejak 2026-08-02.
    --
    -- Terukur: mencabut dari 174 studs SELALU ditolak server, dan atribut
    -- IsInOwnGarden bernilai false di jarak itu. Satu-satunya pencabutan yang
    -- pernah berhasil terjadi saat karakter memang berdiri di kebunnya.
    -- Menembak dari jauh hanya menghasilkan penolakan beruntun.
    DekatSaatCabut = cfg.DekatSaatCabut ~= false,

    -- Panen dipisah dari JedaAksi supaya bisa jauh lebih rapat: satu kebun bisa
    -- berisi puluhan buah, dan 0.35 detik per buah membuat satu fase panen
    -- memakan setengah menit sendiri.
    JedaPanen     = tonumber(cfg.JedaPanen) or 0.08,

    -- Peta ini penuh batu dan penghalang. Tanpa noclip, terbang lurus sering
    -- tersangkut dan karakter berhenti di tengah jalan -- terlihat seperti macet.
    Noclip        = cfg.Noclip ~= false,

    -- ==== AUTO TAME PET ====
    AutoTame      = cfg.AutoTame == true,
    TamePets      = (type(cfg.TamePets) == "table" and #cfg.TamePets > 0) and cfg.TamePets or {},
    MaxTameBid    = cfg.MaxTameBid or "50M",
}

local function status(t)
    _G.FallHarvestDebug = t
    print("[FH] " .. t)
end

local okNet, Networking = pcall(function()
    return require(ReplicatedStorage.SharedModules.Networking)
end)
if not okNet or type(Networking.Pilgrim) ~= "table" then
    status("[BERHENTI] Bukan dunia Fall Harvest.")
    return
end
local SeedData = require(ReplicatedStorage.SharedModules.SeedData)

-- ==========================================================
-- DATA SEED
-- ==========================================================
-- SeedData adalah ARRAY (74 entri), bukan map bernama. Nama yang dipakai shop
-- dan atribut SeedTool ada di field SeedName, jadi indeksnya dibangun sekali.
local infoSeed = {}
for _, e in pairs(SeedData) do
    if type(e) == "table" and e.SeedName then
        infoSeed[e.SeedName] = {
            rarity = e.Rarity or "Common",
            harga  = tonumber(e.PurchasePrice) or math.huge,
        }
    end
end

-- Tangga rarity, diambil dari SeedData game -- bukan dari ingatan.
--
-- Versi sebelumnya memakai Common/Uncommon/Rare/Legendary/Mythic/Divine/
-- Prismatic/Transcendent. Tiga yang terakhir TIDAK ADA di game ini, sementara
-- EPIC dan SUPER yang benar-benar dipakai justru hilang -- jadi nilaiRarity()
-- mengembalikan 0 untuk keduanya.
--
-- Akibatnya nyata dan diam: 14 seed Epic (termasuk Maple Mushroom, salah satu
-- tulang punggung) dihitung rarity 0, sehingga tidak pernah dibeli saat kebun
-- penuh, tidak pernah bisa menggantikan tanaman apa pun, dan rarityTerendahKebun
-- melewatinya karena menyaring p.rarity > 0.
--
-- Urutan di bawah dibuktikan dari SeedShopDisplayOrder terkecil tiap rarity:
-- Common 1, Uncommon 4, Rare 7, Epic 11, Legendary 17, Mythic 24, Super 29,
-- Secret 30.
local TANGGA_RARITY = {
    Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
    Legendary = 5, Mythic = 6, Super = 7, Secret = 8,
}
local function nilaiRarity(nama)
    local i = infoSeed[nama]
    return i and (TANGGA_RARITY[i.rarity] or 0) or 0
end
-- Nama rarity -> angka. Ditulis apa adanya dari panel, jadi salah ketik akan
-- jatuh ke Legendary alih-alih ke 0 -- dan 0 berarti "speedrun selalu aktif",
-- yang menghentikan SELURUH pembelian sejak siklus pertama.
local AMBANG_SPEEDRUN = TANGGA_RARITY[Config.AmbangSpeedrun] or TANGGA_RARITY.Legendary

-- Menerapkan config yang datang dari panel ke Config yang sedang berjalan.
--
-- Panel mengirimnya tiap sync, tapi sebelumnya balasan itu hanya dibaca untuk
-- QuickAction lalu dibuang -- sehingga SELURUH setelan World 2 selamanya memakai
-- nilai bawaan. Gejalanya menyesatkan: panel menyimpan "Mythic" dengan benar dan
-- menampilkannya kembali dengan benar, tapi script tetap jalan di Legendary.
--
-- Tipe dijaga mengikuti nilai yang SUDAH ada di Config, bukan disalin mentah.
-- Panel mengirim angka sebagai number lewat JSON, tapi sekali saja ada yang
-- terkirim sebagai string, perbandingan seperti `rarityTerlemah >= AMBANG` atau
-- `kg < minKg` akan error di tengah siklus, bukan sekadar salah nilai.
-- Dua daftar dianggap sama kalau isinya sama urut.
--
-- Perlu dibandingkan per ISI, bukan dengan "==": Lua membandingkan tabel per
-- referensi, dan tiap sync menghasilkan tabel baru dari JSON. Tanpa ini
-- SeedTarget dan GearTarget selalu terhitung berubah, dan laporan "[CONFIG] 2
-- setelan diperbarui" akan muncul tiap 30 detik selamanya.
local function daftarSama(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Mode beli-saja dipaksakan DI ATAS toggle per-fase, bukan disebar jadi
-- pemeriksaan `if Config.ModeBeliSaja` di tiap fase.
--
-- Alasannya: fase-fase itu diperiksa di belasan tempat, dan satu saja yang
-- terlewat akan membuat mode ini bocor -- misalnya "tanam-awal" yang jalan lebih
-- dulu dari urutan fase normal. Dengan menekan toggle-nya di sumber, seluruh
-- kode di bawah otomatis patuh tanpa perlu tahu mode ini ada.
--
-- Dipanggil dua kali: sekali setelah Config dibangun, dan sekali lagi setiap
-- panel mengirim setelan baru -- kalau tidak, panel bisa menyalakan kembali
-- AutoTanam sementara mode ini masih aktif.
local function terapkanModeBeliSaja()
    if not Config.ModeBeliSaja then return end
    Config.AutoTanam = false
    Config.AutoPanen = false
    Config.AutoSiram = false
    Config.AutoSprinkler = false
    -- Cabut ikut dimatikan walau tidak kamu sebut: mencabut tanpa menanam ulang
    -- hanya menghapus tanaman yang sudah tumbuh dan tidak menghasilkan apa pun.
    Config.AutoCabut = false
end

-- Penegakan pertama, tepat setelah Config dibangun dari panel.
terapkanModeBeliSaja()
if Config.ModeBeliSaja then
    local jml = #(Config.SeedTarget or {})
    warn("[MODE] BELI SAJA aktif — tanam/sprinkler/siram/panen/cabut DIMATIKAN. "
        .. "Yang jalan hanya belanja seed" .. (Config.AutoAmbilSeed and " + ambil seed jatuhan." or ".")
        -- Disebut terang-terangan karena dua perilakunya bertolak belakang, dan
        -- yang satu pernah dikira bug: target KOSONG berarti borong semua.
        .. (jml > 0
            and string.format(" Hanya %d target seed yang dibeli.", jml)
            or " Target seed KOSONG — seluruh isi shop akan diborong."))
end

local function terapkanConfig(baru)
    if type(baru) ~= "table" then return 0 end
    local berubah = 0
    local modeSebelum = Config.ModeBeliSaja
    for k, v in pairs(baru) do
        -- QuickAction bukan setelan; ditangani terpisah dan harus habis sekali pakai.
        --
        -- Key yang tidak dikenal DIABAIKAN, bukan disalin masuk. Satu payload
        -- panel membawa setelan kedua dunia sekaligus -- terukur 53 key, 26 di
        -- antaranya milik World 1 yang tidak berarti apa-apa di sini. Menyalinnya
        -- masuk tidak merusak apa pun hari ini, tapi begitu ada nama yang
        -- bertabrakan nanti, setelan dunia lain akan diam-diam berlaku di sini.
        local lama = Config[k]
        if k ~= "QuickAction" and lama ~= nil then
            local nilai
            if type(lama) == "number" then
                nilai = tonumber(v)
            elseif type(lama) == "boolean" then
                nilai = (v == true) or (v == "true")
            elseif type(lama) == "table" then
                -- Daftar (SeedTarget/GearTarget) hanya diterima kalau memang
                -- daftar. Objek {nama=true} dari panel versi lama akan membuat
                -- ipairs menghasilkan NOL iterasi -- kebun berhenti total tanpa
                -- satu pun pesan error.
                nilai = (type(v) == "table" and #v > 0) and v or nil
                if nilai and daftarSama(nilai, lama) then nilai = nil end
            else
                nilai = v
            end
            if nilai ~= nil and nilai ~= lama then
                Config[k] = nilai
                berubah = berubah + 1
            end
        end
    end

    -- Turunan yang dihitung sekali saat start harus ikut diperbarui, kalau tidak
    -- AmbangSpeedrun yang baru tersimpan di Config tapi tidak pernah dipakai.
    if berubah > 0 then
        AMBANG_SPEEDRUN = TANGGA_RARITY[Config.AmbangSpeedrun] or TANGGA_RARITY.Legendary
    end

    -- Ditegakkan ulang SETELAH setelan panel masuk. Tanpa ini, payload panel yang
    -- membawa AutoTanam=true akan menyalakannya kembali diam-diam.
    terapkanModeBeliSaja()

    -- MODE BUY -> MODE KAITUN: rejoin, bukan sekadar menyalakan fitur lagi.
    --
    -- Mode Buy membuang tanaman kebun sendiri dari sisi klien. Server tetap
    -- menyimpannya, tapi klien ini tidak akan pernah melihatnya lagi tanpa muat
    -- ulang -- dan tanam, panen, serta cabut semuanya bekerja dari apa yang
    -- TERLIHAT klien. Menyalakan kembali fitur tani di atas kebun yang tampak
    -- kosong menghasilkan bot yang sibuk tanpa hasil, tanpa satu pun error.
    --
    -- Syarat kebunSendiriDihancurkan penting: akun yang baru masuk Mode Buy dan
    -- belum sempat membuang apa pun tidak punya alasan untuk terputus.
    if modeSebelum and not Config.ModeBeliSaja and kebunSendiriDihancurkan then
        status("[MODE] Kembali ke Mode Kaitun — rejoin supaya kebun sendiri muncul lagi")
        -- Dilempar ke thread lain: forceRejoin menunggu 5 detik sebelum Kick, dan
        -- itu tidak boleh menahan loop sync yang memanggil fungsi ini.
        task.spawn(forceRejoin, "Ganti ke Mode Kaitun — memuat ulang kebun")
    end
    return berubah
end
if not TANGGA_RARITY[Config.AmbangSpeedrun] then
    status(string.format("[CONFIG] AmbangSpeedrun '%s' tidak dikenal — dipakai Legendary",
        tostring(Config.AmbangSpeedrun)))
end

-- ==========================================================
-- GERAK
-- ==========================================================
local function karakter()
    local c = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return c, hrp, hum
end

local function jarakKe(pos)
    local _, hrp = karakter()
    if not hrp then return math.huge end
    return (hrp.Position - pos).Magnitude
end

-- ==========================================================
-- TELEPORT BAWAAN GAME
-- ==========================================================
-- Terbaca dari ButtonHandler milik game: tombol Garden/Seeds/Sell memanggil
-- Networking.TeleportButton.Request:Fire("Garden"/"Seeds"/"Sell").
--
-- Diuji langsung di server: "Seeds" memindahkan 136 stud dan mendarat 7 stud
-- dari Sam, "Sell" mendarat 7 stud dari Steven -- keduanya sudah di dalam
-- JarakAman, jadi tidak perlu terbang sama sekali.
--
-- "Gears" dan "Props" ADA sebagai part di workspace.Teleports tapi DITOLAK
-- server: keduanya menggeser 0 stud saat dicoba. Daftar yang diterima persis
-- tiga nama di bawah -- jangan ditambah tanpa mengujinya lebih dulu.
local TOMBOL_TELEPORT = { "Garden", "Seeds", "Sell" }

local function titikTeleport(nama)
    if nama == "Garden" then
        -- Kebun tiap pemain berbeda, jadi titiknya dibaca dari PlotId sendiri,
        -- bukan dari folder Teleports yang isinya hanya tujuan umum.
        local gardens = workspace:FindFirstChild("Gardens")
        local plot = gardens and gardens:FindFirstChild("Plot" .. tostring(LocalPlayer:GetAttribute("PlotId")))
        local sp = plot and plot:FindFirstChild("SpawnPoint")
        if not sp then return nil end
        return sp:IsA("BasePart") and sp.Position or sp.CFrame.Position
    end
    local T = workspace:FindFirstChild("Teleports")
    local p = T and T:FindFirstChild(nama)
    if p and p:IsA("BasePart") then return p.Position end
    return nil
end

-- Penjaga yang sama dengan milik game. Menembak remote saat salah satu keadaan
-- ini aktif akan ditolak diam-diam, dan bot akan mengira dirinya sudah pindah.
local function bolehTeleport()
    if LocalPlayer:GetAttribute("IsStealingFruit") == true then return false end
    if LocalPlayer:GetAttribute("CarryingStolenFruit") == true then return false end
    if workspace:GetAttribute("InAdminParty") == true then return false end
    return true
end

local teleportTerakhir = 0

local function teleportKe(nama)
    if not bolehTeleport() then return false end
    local tujuan = titikTeleport(nama)
    if not tujuan then return false end

    -- Game menolak klik yang berjarak kurang dari 0.25 detik. Ditunggu, bukan
    -- ditembak lalu berharap: permintaan yang ditolak tidak memberi tanda apa pun.
    local sisa = 0.3 - (tick() - teleportTerakhir)
    if sisa > 0 then task.wait(sisa) end
    teleportTerakhir = tick()

    local ok = pcall(function()
        Networking.TeleportButton.Request:Fire(nama)
    end)
    if not ok then return false end

    -- Batas 2.5 detik; game sendiri memakai 1.5 detik dengan ambang 12 stud.
    local batas = tick() + 2.5
    while tick() < batas do
        if jarakKe(tujuan) <= 12 then break end
        task.wait(0.1)
    end
    if jarakKe(tujuan) > 12 then return false end

    -- Pet ikut dipindahkan, sama seperti yang dilakukan tombol aslinya. Tanpa ini
    -- pet tertinggal di posisi lama dan itu terlihat jelas oleh pemain lain.
    pcall(function()
        Networking.Pets.SnapPets:Fire(tujuan)
    end)
    return true
end

-- Tombol yang mendaratkan paling dekat ke pos, beserta jaraknya.
local function tombolTerdekat(pos)
    local terbaik, jarak = nil, math.huge
    for _, nama in ipairs(TOMBOL_TELEPORT) do
        local t = titikTeleport(nama)
        if t then
            local d = (t - pos).Magnitude
            if d < jarak then jarak, terbaik = d, nama end
        end
    end
    return terbaik, jarak
end

-- Terbang ke tujuan dengan KECEPATAN TETAP.
--
-- Versi pertama memakai BodyPosition: gaya tariknya besar sehingga karakter
-- melesat dan geraknya tidak wajar. BodyVelocity dengan besaran tetap membuat
-- kecepatannya benar-benar terkendali -- arahnya saja yang diperbarui tiap
-- frame. MaxForce pada sumbu Y sekaligus menahan gravitasi.
-- Noclip: hanya part yang MEMANG tadinya menabrak yang dimatikan, dan persis
-- part itu pula yang dipulihkan. Mematikan semua lalu menyalakan semua akan
-- mengubah part yang aslinya sudah CanCollide=false (HumanoidRootPart, aksesori)
-- dan itu bisa merusak fisika karakter setelah terbang.
local function matikanTabrakan()
    local c = LocalPlayer.Character
    if not c then return {} end
    local disimpan = {}
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            disimpan[#disimpan + 1] = p
            p.CanCollide = false
        end
    end
    return disimpan
end

local function pulihkanTabrakan(disimpan)
    for _, p in ipairs(disimpan) do
        if p.Parent then p.CanCollide = true end
    end
end

-- ==========================================================
-- AUTO TAME PET
-- ==========================================================
-- parsePrice() mengubah teks harga seperti "50000" atau "¢50,000" jadi angka.
-- Format K/M/B tidak dipakai di sini (harga wild pet selalu angka polos),
-- tapi ditangani juga untuk jaga-jaga.
local function parsePriceTame(text)
    if not text then return 0 end
    local cleaned = string.gsub(string.upper(text), "[^%d%.%,%sKMB]", "")
    local numberStr, suffix = string.match(cleaned, "([%d%.%,]+)%s*([MBK]?)")
    if not numberStr then return 0 end
    numberStr = string.gsub(numberStr, ",", "")
    local amount = tonumber(numberStr) or 0
    if suffix == "M" then amount = amount * 1000000
    elseif suffix == "B" then amount = amount * 1000000000
    elseif suffix == "K" then amount = amount * 1000
    end
    return amount
end

-- flightToTame(): terbang ke posisi target pakai BodyVelocity + noclip.
-- Berbeda dengan pergiKe() yang pakai GUI teleport dulu — ini langsung
-- terbang karena targetnya bukan titik tetap melainkan hewan bergerak.
local function flightToTame(targetPos, speed)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    speed = speed or 50
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVel.Parent = root

    local noclipConn = RunService.Stepped:Connect(function()
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
        end
    end)

    local reached = false
    local timeout = 10
    local elapsed = 0

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local dist = (targetPos - root.Position).Magnitude
        if dist <= 4 or elapsed > timeout then
            reached = true
        else
            bodyVel.Velocity = (targetPos - root.Position).Unit * speed
            root.CFrame = CFrame.lookAt(root.Position,
                Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
        end
    end)

    while not reached do task.wait() end

    conn:Disconnect()
    noclipConn:Disconnect()
    if bodyVel then bodyVel:Destroy() end
    root.Velocity = Vector3.new(0, 0, 0)
    return true
end

-- cariWildPet(): mencari hewan liar yang sesuai whitelist dan belum di-tame.
-- Mengembalikan {model, rootPart, prompt, petType, price} atau nil.
local WH_PATH = {"Map", "WildPetSpawns"}

local function cariWildPet()
    local ma = LocalPlayer.Character
    if not ma or not ma:FindFirstChild("HumanoidRootPart") then return nil end

    local folder = Workspace
    for _, seg in ipairs(WH_PATH) do
        folder = folder:FindFirstChild(seg)
        if not folder then return nil end
    end

    local myPos = ma.HumanoidRootPart.Position
    local tameSet = {}
    for _, nm in ipairs(Config.TamePets) do tameSet[string.lower(string.gsub(nm, "%s+", ""))] = true end

    local terbaik, jarakTerbaik = nil, math.huge
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            -- ekstrak tipe dari nama: "WildPet_Dog_WildPet_xxx" -> "Dog"
            local petType = pet.Name:match("WildPet_(%w+)_WildPet")
            -- normalisasi: buang spasi + lower supaya "Golden Dragonfly" (panel)
            -- cocok dengan "GoldenDragonfly" (spawn name)
            if petType and tameSet[string.lower(petType)] then
                local root = pet:FindFirstChild("RootPart")
                local prompt = root and root:FindFirstChild("BuyPrompt")
                if root and prompt then
                    local d = (root.Position - myPos).Magnitude
                    if d < jarakTerbaik then
                        -- parse harga dari ObjectText
                        local price = parsePriceTame(prompt.ObjectText or "")
                        local maxBid = parsePriceTame(Config.MaxTameBid)
                        if maxBid <= 0 or price <= maxBid then
                            terbaik = {model = pet, root = root, prompt = prompt,
                                       petType = petType, price = price}
                            jarakTerbaik = d
                        end
                    end
                end
            end
        end
    end
    return terbaik
end

-- tameSatu(): mengerjakan satu siklus tame — cari, terbang, fire prompt,
-- ikuti sampai selesai, lalu teleport balik.
local function tameSatu()
    local pet = cariWildPet()
    if not pet then return false end

    status(string.format("[TAME] %s ditemukan (¢%s, jarak %.0f)",
        pet.petType, tostring(pet.price), (pet.root.Position - (LocalPlayer.Character.HumanoidRootPart.Position)).Magnitude))

    -- terbang ke hewan
    if not flightToTame(pet.root.Position + Vector3.new(0, 3, 0)) then
        status("[TAME] Gagal terbang ke hewan")
        return false
    end

    task.wait(0.2)

    -- fire proximity prompt
    if fireproximityprompt then
        fireproximityprompt(pet.prompt)
    end

    status("[TAME] Proximity prompt fired, menunggu hasil...")

    -- tunggu sampai hewan hilang (di-tame) atau timeout 15 detik
    local batas = tick() + 15
    while tick() < batas do
        if not pet.model.Parent or not pet.model:FindFirstChild("RootPart") then
            status("[TAME] Berhasil tame " .. pet.petType .. "!")
            task.wait(1)
            -- teleport balik ke Sell
            if Config.PakaiTeleportGui then
                teleportKe("Sell")
            end
            return true
        end
        task.wait(0.3)
    end

    status("[TAME] Timeout — hewan masih ada setelah 15 detik")
    -- tetap teleport balik walau gagal
    if Config.PakaiTeleportGui then
        teleportKe("Sell")
    end
    return false
end

local function pergiKe(pos, toleransi)
    toleransi = toleransi or Config.JarakAman
    local _, hrp = karakter()
    if not hrp then return false end

    if (hrp.Position - pos).Magnitude <= toleransi then return true end

    -- Teleport resmi dulu, terbang hanya untuk sisanya.
    if Config.PakaiTeleportGui then
        local tombol, jarakDarat = tombolTerdekat(pos)
        local jarakSekarang = (hrp.Position - pos).Magnitude
        -- Dua alasan yang sah untuk teleport, dan keduanya perlu.
        --
        -- (1) Mendarat langsung di dalam jangkauan. Terukur: titik "Sell" jatuh
        --     7 stud dari Steven, di bawah JarakAman 12 -- artinya sampai tanpa
        --     terbang sama sekali. Tanpa syarat ini, jarak 20 stud ke Steven
        --     ditempuh dengan terbang padahal teleport menyelesaikannya seketika.
        -- (2) Memangkas jarak. Ambangnya diturunkan 20 -> 5 stud.
        --
        --     Terbang itu jalur yang paling sering gagal: ia melawan tarikan
        --     server, bisa meleset, dan tiap kegagalan menghentikan fase yang
        --     sedang berjalan. Tombol GUI memakai remote milik game sendiri,
        --     jadi ia praktis selalu berhasil. Karena itu sekarang: KALAU ADA
        --     tombol yang mendekatkan, pakai tombolnya -- terbang tinggal
        --     mengurus sisa jarak yang tidak terjangkau tombol mana pun.
        --
        --     Margin 5 stud tetap ada supaya perpindahan pendek di dalam kebun
        --     sendiri tidak memicu teleport bolak-balik.
        local layak = tombol and (
            (jarakDarat <= toleransi and jarakSekarang > toleransi)
            or jarakDarat + 5 < jarakSekarang
        )
        if layak then
            if teleportKe(tombol) then
                if jarakKe(pos) <= toleransi then return true end
                -- Karakter bisa berganti saat respawn; ambil ulang sebelum terbang.
                local _, h = karakter()
                if not h then return false end
                hrp = h
            end
        end
    end

    local tujuan = pos + Vector3.new(0, 3, 0)

    -- Batas waktu dihitung dari jarak dan kecepatan, bukan angka tetap: dengan
    -- 22 studs/detik, tujuan 150 studs butuh ~7 detik, dan batas mati 20 detik
    -- akan memutus perjalanan yang sebenarnya sehat.
    local perkiraan = (hrp.Position - tujuan).Magnitude / math.max(1, Config.KecepatanTerbang)
    local batas = tick() + perkiraan * 2 + 5

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    local dimatikan = Config.Noclip and matikanTabrakan() or {}

    while tick() < batas do
        local _, h2 = karakter()
        if not h2 then break end
        local selisih = tujuan - h2.Position
        if (h2.Position - pos).Magnitude <= toleransi then break end
        bv.Velocity = selisih.Unit * Config.KecepatanTerbang
        -- Diterapkan ulang tiap frame: Roblox mengembalikan CanCollide sendiri
        -- pada beberapa keadaan, dan sekali saja di awal tidak cukup.
        if Config.Noclip then
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(dimatikan) do
                    if p.Parent and p.CanCollide then p.CanCollide = false end
                end
            end
        end
        RunService.Heartbeat:Wait()
    end

    bv:Destroy()
    pulihkanTabrakan(dimatikan)

    -- TUNGGU MENDARAT sebelum menyerahkan kendali.
    --
    -- Ini bukan kehati-hatian berlebihan: kalau langsung dipakai setelah terbang,
    -- karakter masih melayang dan Roblox MELEPAS tool yang baru diequip. Terlihat
    -- sebagai equip=false pada tiap percobaan, dan tidak satu pun penanaman jadi.
    local tungguDarat = tick() + 4
    while tick() < tungguDarat do
        local _, h3, hum3 = karakter()
        if not (h3 and hum3) then break end
        if hum3:GetState() == Enum.HumanoidStateType.Running
           and h3.AssemblyLinearVelocity.Magnitude < 3 then
            break
        end
        task.wait(0.1)
    end

    task.wait(0.2)
    return jarakKe(pos) <= toleransi * 1.5
end

-- ==========================================================
-- PLOT & TANAMAN
-- ==========================================================
-- Mengembalikan kebun milik kita, atau nil kalau BENAR-BENAR tidak bisa
-- dipastikan. Pemanggil WAJIB memperlakukan nil sebagai "jangan sentuh apa pun",
-- bukan sebagai "tidak ada yang perlu dilindungi" -- lihat applyFpsBoost.
local function plotSaya()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end

    -- 0. PlotId milik pemain. Ini cara GAME SENDIRI menemukan kebunmu -- tombol
    --    Garden bawaan memakainya persis begini:
    --        Gardens:FindFirstChild("Plot" .. LocalPlayer:GetAttribute("PlotId"))
    --
    --    Didahulukan karena satu-satunya yang bekerja pada KEBUN KOSONG. Ketiga
    --    cara di bawah semuanya butuh kebun yang sudah ada isinya: cara (2)
    --    membaca nama tanaman, cara (3) mensyaratkan #plants > 0. Di akun baru
    --    ketiganya buta, dan cara (3) bisa mengembalikan kebun ORANG LAIN yang
    --    StealPrompt-nya belum sempat dibuat -- bot lalu terbang ke kebun yang
    --    salah dan penanaman ditolak tanpa sebab yang terlihat.
    local plotId = LocalPlayer:GetAttribute("PlotId")
    if plotId ~= nil then
        local g = gardens:FindFirstChild("Plot" .. tostring(plotId))
        if g then return g end
    end

    -- 1. Atribut pemilik. Terverifikasi di server: kebun yang sudah dimiliki
    --    membawa OwnerUserId, kebun kosong tak bertuan tidak membawa apa-apa.
    for _, g in ipairs(gardens:GetChildren()) do
        for _, kunci in ipairs({ "OwnerUserId", "UserId", "Owner", "OwnerId", "PlayerUserId" }) do
            if tostring(g:GetAttribute(kunci)) == tostring(LocalPlayer.UserId) then return g end
        end
    end

    -- 2. Cadangan lewat nama tanaman "{userId}_{guid}". Format ini sudah
    --    diverifikasi di server sungguhan, sedangkan atribut di atas TIDAK --
    --    dan mengandalkan atribut saja pernah membuat seluruh kebun terhapus.
    local uid = tostring(LocalPlayer.UserId)
    for _, g in ipairs(gardens:GetChildren()) do
        local plants = g:FindFirstChild("Plants")
        if plants then
            for _, t in ipairs(plants:GetChildren()) do
                if string.match(t.Name, "^(%d+)_") == uid then return g end
            end
        end
    end

    -- 3. Cadangan terakhir: kebun orang lain memasang StealPrompt, kebun sendiri
    --    memakai HarvestPrompt. Berguna saat kebun kita masih kosong sehingga
    --    cara (2) tidak punya bahan.
    for _, g in ipairs(gardens:GetChildren()) do
        local plants = g:FindFirstChild("Plants")
        if plants and #plants:GetChildren() > 0 then
            local adaSteal = false
            for _, t in ipairs(plants:GetChildren()) do
                local hp = t:FindFirstChild("HarvestPart")
                if hp and hp:FindFirstChild("StealPrompt") then adaSteal = true break end
            end
            if not adaSteal then return g end
        end
    end

    return nil
end

-- Nama model tanaman: "{userId}_{guid}_{indeksBuah}".
-- CollectFruit butuh guid + indeks; UseShovel butuh "{userId}_{guid}".
local function uraiNamaTanaman(nama)
    local userId, guid, indeks = string.match(nama, "^(%d+)_([%w%-]+)_(%d+)$")
    if userId then return userId, guid, indeks end
    local u2, g2 = string.match(nama, "^(%d+)_([%w%-]+)$")
    if u2 then return u2, g2, nil end
    return nil, nil, nil
end

local function daftarTanaman()
    local plot = plotSaya()
    local folder = plot and plot:FindFirstChild("Plants")
    if not folder then return {} end

    local hasil = {}
    for _, m in ipairs(folder:GetChildren()) do
        local userId, guid = uraiNamaTanaman(m.Name)
        if guid then
            local jenis = m:GetAttribute("SeedName") or m:GetAttribute("PlantName") or m.Name
            hasil[#hasil + 1] = {
                model = m, userId = userId, guid = guid, nama = jenis,
                rarity = nilaiRarity(jenis),
                pos = (m.PrimaryPart and m.PrimaryPart.Position)
                      or (m:FindFirstChildWhichIsA("BasePart") and m:FindFirstChildWhichIsA("BasePart").Position),
            }
        end
    end
    return hasil
end

-- ==========================================================
-- BLACK SCREEN + PANEL STATUS
-- ==========================================================
-- Diport dari kaitun_main.txt. Perbedaannya untuk dunia ini:
--   * mata uangnya LEAVES, bukan Sheckles
--   * label dunia ikut ditampilkan supaya jelas akun ini di World 2
--
-- RIWAYAT DIGANTI RINGKASAN.
--
-- Dulu panel menampilkan 8 baris aktivitas terakhir (beli/tanam/panen/jual).
-- Isinya bergulir terus sehingga yang terbaca cuma potongan menit terakhir --
-- untuk bot yang ditinggal berjam-jam, itu tidak menjawab satu pun pertanyaan
-- yang benar-benar ingin diketahui: sudah berapa yang ditanam, berapa buah yang
-- ada, sudah jalan berapa lama, dan sekarang mengejar seed apa.
--
-- Keduanya dipegang di _G supaya bertahan saat instance script diganti (loader
-- bisa memuat ulang tanpa rejoin), jadi hitungannya tidak balik ke nol.
_G.FHMulai = _G.FHMulai or os.time()
_G.FHTotalTanam = _G.FHTotalTanam or 0
-- Cabut ikut dicacah. Sebelumnya tidak ada sama sekali, jadi kerja shovel tidak
-- pernah kelihatan di layar -- yang terlihat hanya "Planted" yang naik terus, dan
-- itu terbaca persis seperti "cuma ditambah, tidak pernah dicabut".
_G.FHTotalCabut = _G.FHTotalCabut or 0

-- Lama berjalan dalam bentuk HH:MM:SS.
local function lamaJalan()
    local d = os.time() - (_G.FHMulai or os.time())
    if d < 0 then d = 0 end
    return string.format("%02d:%02d:%02d", math.floor(d / 3600),
        math.floor(d % 3600 / 60), d % 60)
end

-- Seed yang sedang dikejar. SeedTarget itu daftar prioritas: yang pertama
-- adalah yang paling didahulukan saat belanja, dan saat speedrun ia jadi
-- satu-satunya yang dibeli.
local function targetBerikut()
    local t = Config.SeedTarget
    if type(t) ~= "table" or #t == 0 then return "-" end
    if #t == 1 then return tostring(t[1]) end
    return string.format("%s (+%d)", tostring(t[1]), #t - 1)
end

local function pasangBlackScreen()
    if not Config.BlackScreen then return end

    pcall(function() workspace.CurrentCamera.FieldOfView = 30 end)

    local ok = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "AFK_BlackScreen"
        gui.Enabled = true
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BorderSizePixel = 0
        bg.Parent = gui

        local kiri = Instance.new("ImageLabel")
        kiri.Size = UDim2.new(0.3, 0, 0.6, 0)
        kiri.Position = UDim2.new(0.05, 0, 0.5, 0)
        kiri.AnchorPoint = Vector2.new(0, 0.5)
        kiri.BackgroundTransparency = 1
        kiri.ScaleType = Enum.ScaleType.Fit
        kiri.Image = "rbxassetid://79880397850563"
        kiri.Parent = bg

        local kanan = Instance.new("ImageLabel")
        kanan.Size = UDim2.new(0.3, 0, 0.6, 0)
        kanan.Position = UDim2.new(0.95, 0, 0.5, 0)
        kanan.AnchorPoint = Vector2.new(1, 0.5)
        kanan.BackgroundTransparency = 1
        kanan.ScaleType = Enum.ScaleType.Fit
        kanan.Image = "rbxassetid://104624206636533"
        kanan.Parent = bg

        local judul = Instance.new("TextLabel")
        judul.Size = UDim2.new(0.9, 0, 0.25, 0)
        judul.Position = UDim2.new(0.5, 0, 0.95, 0)
        judul.AnchorPoint = Vector2.new(0.5, 1)
        judul.BackgroundTransparency = 1
        judul.Text = "AFK MODE — WORLD 2\nFENG JIU MY BINI"
        judul.TextColor3 = Color3.fromRGB(255, 255, 255)
        judul.TextScaled = true
        judul.TextWrapped = true
        judul.Font = Enum.Font.Code
        judul.ZIndex = 10
        judul.Parent = bg

        local tengah = Instance.new("TextLabel")
        tengah.Size = UDim2.new(0.4, 0, 0.2, 0)
        tengah.Position = UDim2.new(0.5, 0, 0.4, 0)
        tengah.AnchorPoint = Vector2.new(0.5, 0.5)
        tengah.BackgroundTransparency = 1
        tengah.Text = "Loading..."
        tengah.TextColor3 = Color3.fromRGB(255, 255, 0)
        tengah.TextScaled = true
        tengah.Font = Enum.Font.GothamBold
        tengah.ZIndex = 10
        tengah.Parent = bg
        local batasTeks = Instance.new("UITextSizeConstraint")
        batasTeks.MaxTextSize = 25
        batasTeks.Parent = tengah
        local strokeTengah = Instance.new("UIStroke")
        strokeTengah.Thickness = 1.5
        strokeTengah.Color = Color3.fromRGB(0, 0, 0)
        strokeTengah.Parent = tengah

        local riwayat = Instance.new("TextLabel")
        riwayat.Size = UDim2.new(0.4, 0, 0.3, 0)
        riwayat.Position = UDim2.new(0.5, 0, 0.5, 0)
        riwayat.AnchorPoint = Vector2.new(0.5, 0)
        riwayat.BackgroundTransparency = 1
        riwayat.Text = ""
        riwayat.TextColor3 = Color3.fromRGB(150, 255, 150)
        riwayat.TextSize = 14
        riwayat.TextXAlignment = Enum.TextXAlignment.Center
        riwayat.TextYAlignment = Enum.TextYAlignment.Top
        riwayat.TextWrapped = true
        riwayat.Font = Enum.Font.GothamBold
        riwayat.ZIndex = 10
        riwayat.Parent = bg
        local strokeRiwayat = Instance.new("UIStroke")
        strokeRiwayat.Thickness = 1.2
        strokeRiwayat.Color = Color3.fromRGB(0, 0, 0)
        strokeRiwayat.Parent = riwayat

        local perf = Instance.new("TextLabel")
        perf.Size = UDim2.new(0.5, 0, 0.05, 0)
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

        local debug = Instance.new("TextLabel")
        debug.Size = UDim2.new(0.8, 0, 0.05, 0)
        debug.Position = UDim2.new(0.5, 0, 0.08, 0)
        debug.AnchorPoint = Vector2.new(0.5, 0)
        debug.BackgroundTransparency = 1
        debug.TextColor3 = Color3.fromRGB(255, 255, 0)
        debug.TextSize = 13
        debug.Font = Enum.Font.Code
        debug.ZIndex = 10
        debug.Text = "Menunggu kaitun..."
        debug.Parent = bg
        local strokeDebug = Instance.new("UIStroke")
        strokeDebug.Thickness = 1
        strokeDebug.Color = Color3.fromRGB(0, 0, 0)
        strokeDebug.Parent = debug

        -- Ditempel ke CoreGui kalau executor mendukung, supaya tidak ikut hilang
        -- saat karakter respawn.
        local berhasil = pcall(function()
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not berhasil then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        local function ringkasAngka(n)
            n = tonumber(n) or 0
            if n >= 1e12 then return string.format("%.2fT", n / 1e12)
            elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
            elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
            elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
            else return tostring(n) end
        end

        task.spawn(function()
            local Stats = game:GetService("Stats")
            while gui.Parent do
                -- Mata uang dunia ini LEAVES, bukan Sheckles.
                local daun = 0
                pcall(function()
                    local ls = LocalPlayer:FindFirstChild("leaderstats")
                    local n = ls and ls:FindFirstChild("Leaves")
                    if n then daun = n.Value end
                end)
                tengah.Text = "👤 " .. LocalPlayer.Name .. "\n🍃 " .. ringkasAngka(daun)

                -- Buah dibaca dari atribut pemain, bukan dihitung dari kebun.
                -- FruitCount itu angka yang dipakai server sendiri untuk batas
                -- kapasitas, jadi ia selalu cocok dengan yang dilihat game --
                -- sedangkan menghitung folder Fruits bisa meleset saat kebun
                -- sedang dimuat ulang.
                local buah = tonumber(LocalPlayer:GetAttribute("FruitCount")) or 0
                local kap = tonumber(LocalPlayer:GetAttribute("MaxFruitCapacity")) or 100

                -- KEADAAN KEBUN dibaca langsung dari plot, bukan dari pencacah sesi.
                --
                -- Ini inti perbaikannya. "Planted" hidup di _G, jadi ia bertahan saat
                -- script dimuat ulang tapi TETAP kembali ke nol setiap rejoin -- dan
                -- buyer membacanya sebagai "kaitun-nya mengulang dari nol", padahal
                -- kebunnya utuh 112 tanaman. Angka yang menjawab pertanyaan itu adalah
                -- isi kebun sekarang, dan itu tidak pernah reset.
                --
                -- Terukur 0,107 ms per panggilan pada 112 tanaman, jadi memanggilnya
                -- tiap detik tidak perlu cache.
                local isiKebun
                if Config.ModeBeliSaja then
                    isiKebun = "— (Mode Buy)"
                else
                    local tan = daftarTanaman()
                    local batas = tonumber(Config.BatasTanam) or 0
                    -- Rarity terlemah ikut ditampilkan karena itulah yang menentukan
                    -- apakah shovel boleh bekerja: seed yang tidak melampaui angka ini
                    -- sebanyak AmbangSelisihCabut tidak mencabut apa pun. Tanpa
                    -- ditampilkan, "kenapa tidak dicabut" tidak bisa dijawab dari layar.
                    local terlemah = 0
                    for _, p in ipairs(tan) do
                        if p.rarity > 0 and (terlemah == 0 or p.rarity < terlemah) then
                            terlemah = p.rarity
                        end
                    end
                    -- Batas 0 berarti tanpa batas, dan "112/~" cuma memancing
                    -- pertanyaan. Penyebutnya dihilangkan saja kalau tidak ada batas.
                    isiKebun = string.format("%d%s%s", #tan,
                        batas > 0 and ("/" .. batas) or "",
                        terlemah > 0 and string.format("  terlemah r%d", terlemah) or "")
                end

                riwayat.Text = table.concat({
                    "────────────",
                    "🎮 Mode    : " .. (Config.ModeBeliSaja and "Buy" or "Kaitun"),
                    "🌿 Kebun   : " .. isiKebun,
                    "🌱 Planted : " .. tostring(_G.FHTotalTanam or 0) .. " (sesi)",
                    "⛏️ Cabut   : " .. tostring(_G.FHTotalCabut or 0) .. " (sesi)",
                    "🍎 Fruits  : " .. buah .. "/" .. kap,
                    "⏱️ Runtime : " .. lamaJalan(),
                    "🎯 Target  : " .. targetBerikut(),
                }, "\n")

                local ping, fps, mem = "0", "0", "0"
                pcall(function()
                    ping = string.split(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1] or "0"
                end)
                pcall(function() fps = tostring(math.floor(workspace:GetRealPhysicsFPS())) end)
                pcall(function()
                    mem = string.split(Stats.PerformanceStats.Memory:GetValueString(), " ")[1] or "0"
                end)
                perf.Text = string.format("🎮 FPS: %s  |  📶 Ping: %s ms  |  🧠 Mem: %s MB", fps, ping, mem)

                if _G.FallHarvestDebug then debug.Text = tostring(_G.FallHarvestDebug) end
                task.wait(1)
            end
        end)
    end)

    if not ok then warn("[FH] Gagal memasang black screen") end
end

-- ==========================================================
-- ANTI-AFK
-- ==========================================================
-- Ditegakkan fase tanam/cabut. Melompat di tengah penanaman membuat Humanoid
-- masuk Freefall, dan Roblox MELEPAS tool yang sedang dipegang -- itu persis bug
-- yang dulu membuat seluruh fase tanam gagal tanpa jejak (equip=false di setiap
-- percobaan). Jadi lompatan anti-AFK harus tahu kapan tidak boleh mengganggu.
_G.FHJanganLompat = false

local function pasangAntiAFK()
    local vu = game:GetService("VirtualUser")
    local vim = game:GetService("VirtualInputManager")

    -- Lapis 1: balasan langsung saat Roblox menandai idle.
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end)

    -- Lapis 2: gerakan nyata berkala. Klik saja kadang tidak cukup pada sesi
    -- panjang; lompatan menghasilkan input fisik yang jelas.
    task.spawn(function()
        while true do
            task.wait(math.random(150, 240))

            -- Ditunda kalau sedang menanam/mencabut. Dicoba lagi tiap 5 detik,
            -- maksimal 60 detik supaya tidak tertunda selamanya kalau ada fase
            -- yang menggantung.
            local tunggu = 0
            while _G.FHJanganLompat and tunggu < 60 do
                task.wait(5)
                tunggu = tunggu + 5
            end

            pcall(function()
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            pcall(function()
                local hum = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end)
        end
    end)
end

-- ==========================================================
-- FPS BOOST
-- ==========================================================
-- Diport dari applyFpsBoost() di kaitun_main.txt, dengan SATU perbedaan wajib:
-- versi asli menghapus seluruh Workspace.Gardens. Di dunia ini kebun sendiri
-- dipakai untuk menanam, memanen, dan mencabut -- menghapusnya berarti mematikan
-- hampir seluruh script. Jadi yang dibuang hanya kebun MILIK ORANG LAIN, yang
-- justru penyumbang beban terbesar (Plot7 saja terhitung 178 tanaman).
-- Pembersihan kebun orang lain. DIPISAH dari sapuan berat karena keduanya punya
-- irama yang sama sekali berbeda:
--
--   * Sapuan workspace berat sekali (14.744 instance, ~9 ms) tapi cukup SEKALI --
--     dekorasi yang sudah dihapus tidak kembali.
--   * Kebun justru dimuat BERTAHAP. Terukur: 8 pemain di server tapi baru 1 plot
--     yang termuat. Sekali jalan di siklus 1 hanya menemukan satu-dua kebun, dan
--     sisanya -- yang menyumbang 8.264 dari 14.744 instance workspace, 56% --
--     tidak pernah dibersihkan sama sekali.
--
-- Fungsi ini murah (~1,2 ms, hanya menyentuh Gardens), jadi aman diulang.
local function bersihkanKebunOrang(tunggu)
    local plotku = plotSaya()

    -- Kebun kita sendiri pun belum tentu sudah termuat saat siklus pertama.
    -- Penantian ini hanya untuk pemanggilan pertama; pemanggilan berkala tidak
    -- boleh memblokir siklus selama 20 detik.
    if not plotku and tunggu then
        status("[FPS] Menunggu kebun sendiri termuat...")
        local batas = tick() + 20
        while tick() < batas and not plotku do
            task.wait(1)
            plotku = plotSaya()
        end
    end

    -- GAGAL-TERTUTUP. Ini pernah menghancurkan kebun sungguhan.
    --
    -- Versi lama langsung menghapus tiap kebun yang `g ~= plotku`. Saat plotSaya()
    -- mengembalikan nil, SETIAP kebun tidak sama dengan nil -- jadi semuanya
    -- dihapus, termasuk milik sendiri. PlotSizeReference ikut lenyap, dan tanam,
    -- panen, serta cabut mati seluruhnya sampai pemain rejoin.
    --
    -- Gagal mengenali kebun sendiri TIDAK BOLEH berarti "tidak ada yang perlu
    -- dilindungi". Artinya: jangan hapus apa pun.
    if not plotku then
        if tunggu then
            status("[FPS] Kebun sendiri tidak terdeteksi — penghapusan DILEWATI demi keamanan")
        end
        return 0
    end

    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return 0 end

    local dibuang = 0
    for _, g in ipairs(gardens:GetChildren()) do
        if g ~= plotku then
            pcall(function() g:Destroy() end)
            dibuang = dibuang + 1
        end
    end
    if dibuang > 0 then
        status(string.format("[FPS] %d kebun orang lain dihapus", dibuang))
    end
    return dibuang
end

-- Dipakai untuk memutuskan apakah pindah ke Mode Kaitun perlu rejoin. Tanpa ini,
-- akun Mode Buy yang belum sempat membuang apa pun ikut terputus percuma.
local kebunSendiriDihancurkan = false

-- MODE BUY: isi kebun SENDIRI ikut dibuang.
--
-- Di mode ini tidak ada yang ditanam, disiram, dipanen, atau dicabut, jadi
-- tanaman sendiri tinggal beban render murni. Terukur di server sungguhan
-- (Plot1, 8 pemain): plot sendiri 45.076 instance dan 44.320 di antaranya --
-- 98,3% -- ada di folder Plants.
--
-- Yang dibuang ISI Plants, BUKAN plot-nya, dan itu keputusan yang disengaja.
-- plotSaya() mengenali kebun lewat plot beserta PlotSizeReference-nya; begitu ia
-- mengembalikan nil, bersihkanKebunOrang() gagal-tertutup dan berhenti
-- membersihkan kebun orang lain sama sekali. Menghapus plot utuh berarti
-- membiarkan 338.000 instance kebun orang menumpuk kembali demi menghemat 756.
-- Foldernya sendiri disisakan supaya tanaman baru masih punya induk.
--
-- TIDAK permanen: ini penghapusan sisi klien belaka, server tidak tahu apa-apa,
-- dan rejoin memulihkan seluruh tanaman. Justru itu sebabnya pindah ke Mode
-- Kaitun memaksa rejoin -- lihat terapkanConfig().
local function hancurkanKebunSendiri()
    local plotku = plotSaya()
    if not plotku then return 0 end
    local plants = plotku:FindFirstChild("Plants")
    if not plants then return 0 end

    local n = 0
    for _, c in ipairs(plants:GetChildren()) do
        pcall(function() c:Destroy() end)
        n = n + 1
    end
    if n > 0 then
        kebunSendiriDihancurkan = true
        status(string.format("[MODE BUY] %d tanaman kebun sendiri dibuang — kembali saat rejoin", n))
    end
    return n
end

-- Satu tempat untuk memutuskan "boleh disentuh atau tidak".
-- Dipakai sapuan awal MAUPUN hook DescendantAdded, supaya keduanya tidak bisa
-- berbeda pendapat -- kalau berbeda, hook akan merusak apa yang sengaja
-- dilindungi sapuan.
-- plotSaya() menelusuri Gardens dan membaca atribut tiap plot. Itu murah kalau
-- dipanggil sesekali, tapi bolehDibrutalkan() dipanggil untuk SETIAP instance --
-- 16.517 kali per sapuan, lalu sekali lagi tiap objek baru lewat hook. Tanpa
-- cache, penjagaan ini sendiri jadi jauh lebih mahal daripada seluruh sapuan.
--
-- Pemeriksaan .Parent membuat cache batal sendiri saat kebun dimuat ulang atau
-- dihapus, jadi tidak akan memegang acuan basi.
local plotCache = nil
local function plotSayaCepat()
    if plotCache and plotCache.Parent then return plotCache end
    plotCache = plotSaya()
    return plotCache
end

local function bolehDibrutalkan(d)
    if not d or not d.Parent then return false end

    local char = LocalPlayer.Character
    if char and d:IsDescendantOf(char) then return false end

    -- Kebun sendiri dilindungi UTUH. Membekukan, menyembunyikan, atau mengganti
    -- materialnya bisa mengacaukan pembacaan posisi tanaman dan raycast lahan
    -- tanam -- dan seluruh tanam/panen/cabut bergantung pada itu.
    local plotku = plotSayaCepat()
    if plotku and d:IsDescendantOf(plotku) then return false end

    if d == workspace.Terrain then return false end

    -- NPC WAJIB utuh: Sam/Gilbert (seed), George (gear), Steven (jual), dan
    -- Ethan (pindah dunia) dicari lewat HumanoidRootPart. script.txt menghapus
    -- Motor6D dan Attachment pada NPC; di sini itu tidak boleh, karena kita
    -- benar-benar memakai NPC untuk beli dan jual.
    local kini, dalam = d, 0
    while kini and kini ~= workspace and dalam < 5 do
        if kini:FindFirstChildWhichIsA("Humanoid") then return false end
        local n = string.lower(kini.Name)
        if n == "npcs" or n == "npc" then return false end
        kini = kini.Parent
        dalam = dalam + 1
    end

    return true
end

-- Diadaptasi dari superBrutalize() di script.txt, dengan dua penyimpangan yang
-- disengaja:
--   * TIDAK menghapus Attachment/Motor6D/Animator. script.txt boleh melakukannya
--     karena murni AFK; script ini memakai NPC untuk beli dan jual.
--   * TIDAK menyentuh CanCollide. Mematikannya di seluruh dunia membuat karakter
--     jatuh menembus lantai saat mendarat.
local function brutalkan(d)
    if not bolehDibrutalkan(d) then return false end

    local ok = pcall(function()
        if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
           or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
           or d:IsA("Light") or d:IsA("PostEffect")
           or d:IsA("Texture") or d:IsA("Decal") or d:IsA("SurfaceAppearance")
           or d:IsA("PVAdornment") or d:IsA("HandleAdornment")
           or d:IsA("SurfaceGui") or d:IsA("BillboardGui")
           or d:IsA("KeyframeSequence") then
            d:Destroy()
            return
        end

        if d:IsA("Sound") then
            -- DIHAPUS, tidak sekadar dibisukan.
            --
            -- Volume 0 menghentikan bunyinya tapi instance-nya tetap tinggal di
            -- memori dan tetap ikut di-mix tiap frame. Terukur di client asli:
            -- 341 sound masih aktif dan 78 MB terpakai, pada client yang bahkan
            -- belum menjalankan script ini.
            --
            -- KECUALI yang sedang berbunyi. Sebagian alur game menunggu
            -- Sound.Ended, dan menghapus di tengah putaran membuat penantian itu
            -- menggantung selamanya -- itu alasan versi lama memilih Volume 0
            -- untuk semuanya. Yang sedang main cukup dibisukan; begitu selesai
            -- ia tersapu di lintasan berikutnya.
            if d.IsPlaying then
                d.Volume = 0
            else
                d:Destroy()
            end
            return
        end

        if d:IsA("BasePart") then
            d.Material = Enum.Material.SmoothPlastic
            d.Reflectance = 0
            d.CastShadow = false
            -- FREEZE. Part yang dijangkarkan berhenti disimulasikan mesin fisika
            -- sama sekali -- inilah bagian "freeze" yang membuat script.txt
            -- terasa jauh lebih ringan daripada sekadar mematikan efek.
            --
            d.Anchored = true
            -- CanTouch SENGAJA TIDAK disentuh.
            --
            -- Dulu di sini ada `d.CanTouch = false` dengan alasan "kita tidak
            -- memakai event Touched di mana pun". Itu keliru: ShovelController
            -- memakai HIT DETECTION, dan hit detection butuh CanTouch. Terukur
            -- di kebun sungguhan -- 6.259 dari 6.789 part (92%) jadi CanTouch
            -- false, lalu SELURUH pencabutan ditolak server sampai pemain
            -- rejoin. Penghematan fisikanya tidak sebanding dengan mematikan
            -- fitur inti.
        end
    end)
    return ok
end

-- ScreenGui yang DIBUANG dari PlayerGui.
--
-- Daftar BUANG, bukan daftar SIMPAN -- dan itu keputusan yang lahir dari
-- kesalahan. Versi coba-coba sebelumnya menyimpan hanya SeedShop dan GearShop
-- lalu membuang 103 sisanya; akibatnya BackpackGui ikut terhapus, dan tanpa
-- hotbar penanaman MANUAL mati total sampai rejoin.
--
-- Dengan daftar buang, apa pun yang tidak dikenali otomatis DIPERTAHANKAN. Itu
-- arah gagal yang benar: melewatkan satu GUI berarti kehilangan sedikit
-- penghematan, bukan mematikan fitur.
--
-- Empat yang tidak boleh disentuh, dan alasannya:
--   SeedShop         stokShop() membaca daftar item dari sini
--   GearShop         stokItem() membaca stok sprinkler dan alat siram
--   BackpackGui      hotbar; tanpa ini equip dan tanam manual mati
--   ProximityPrompts wadah prompt panen
--
-- Terukur di server sungguhan: 37 GUI dibuang, PlayerGui 14.166 -> 5.070
-- instance, dan keempat di atas tetap utuh -- stok shop masih terbaca 29 item
-- dan equip tool lewat script tetap berhasil.
local GUI_BUANG = {
    "RobuxShop", "Auction", "CrateShop", "SecretDropLog", "FruitStockPrice",
    "MailboxUI", "PlayerGardenMarket", "GuildShop", "CustomiseFenceTheme",
    "GearCinematicBars", "CinematicBars", "ViewGuildProgress", "GrowingList",
    "ViewGuildPage", "CreateGiftRequest", "WeatherUI", "PlayerStats",
    "ViewGuildLeaderboard", "PremiumSeedShop", "Settings", "EditGuild",
    "CreateGuild", "PropsFrame", "PetList", "MushroomUI", "PartyOdds",
    "MagicMailUI", "ColorPickerGuild", "PetInfo", "GearInfo", "PartyPoint",
    "GuildTransfer", "GuildInvite", "PlayerSelector", "PilgrimQuests",
    "Odds", "EclipseMerge",
}

-- Wadah lingkungan yang murni hiasan. Daftar ini DIVERIFIKASI dari isi workspace
-- Fall Harvest, bukan disalin mentah dari script.txt -- nama di kedua game tidak
-- sepenuhnya sama.
local WADAH_HIASAN = {
    "Grass", "Trees", "Decorations",
    "BirdVisuals", "Birds", "BlizzardBeams", "LightningEffects",
    "RainDrops", "RainSplashes", "StormRainDrops", "StormSplashes",
    "GnomeVisuals", "Gnomes", "GrapplingHookVisuals", "PottedPlantVisuals",
    "Presents", "Dance", "Weather", "Clouds", "Rain", "PopVFXModel",
}

local function nukeLingkungan()
    local dibuang = 0
    -- GetChildren() ditelusuri, bukan FindFirstChild, karena ada nama yang
    -- MUNCUL BERKALI-KALI: terhitung 12 "PopVFXModel" sekaligus, dan
    -- FindFirstChild hanya akan membuang satu.
    for _, c in ipairs(workspace:GetChildren()) do
        for _, nama in ipairs(WADAH_HIASAN) do
            if c.Name == nama then
                pcall(function() c:Destroy() end)
                dibuang = dibuang + 1
                break
            end
        end
    end

    -- Baseplate.Decor: hiasan lantai, dibuang terpisah.
    --
    -- Tidak bisa lewat WADAH_HIASAN di atas karena daftar itu hanya memeriksa
    -- anak LANGSUNG workspace, sedangkan Decor bersarang di dalam Baseplate.
    --
    -- Terukur 2.604 instance / 2.341 BasePart, isinya model hiasan murni
    -- (Model147, Model150, ...). Lantai yang sesungguhnya terpisah sebagai
    -- TopLayer, MidLayer, BottomLayer, dan Center -- keempatnya anak Baseplate
    -- juga, dan TIDAK boleh ikut dibuang: TopLayer itu permukaan yang dikenai
    -- raycast saat mencari titik tanam, dan tanpa lantai karakter jatuh menembus
    -- dunia. Diverifikasi di server sungguhan: setelah Decor dibuang, keempatnya
    -- tetap ada dan karakter bertahan di Y=147,6.
    pcall(function()
        local bp = workspace:FindFirstChild("Baseplate")
        local decor = bp and bp:FindFirstChild("Decor")
        if decor then
            decor:Destroy()
            dibuang = dibuang + 1
        end
    end)

    pcall(function()
        local T = workspace.Terrain
        T.WaterWaveSize = 0
        T.WaterWaveSpeed = 0
        T.WaterReflectance = 0
        T.WaterTransparency = 1
        -- Terrain.Decoration sengaja TIDAK disentuh: propertinya sudah dihapus
        -- Roblox dan hanya melempar error. script.txt masih mengaturnya, tapi
        -- gagal diam-diam karena terbungkus pcall.
    end)

    return dibuang
end

-- ==========================================================
-- SEMBUNYIKAN TANAMAN & BUAH (kebun SENDIRI)
-- ==========================================================
--
-- Terpisah dari brutalkan() karena kebun sendiri sengaja dikecualikan di sana --
-- lihat bolehDibrutalkan(). Yang dilindungi di sana adalah STRUKTUR kebun, dan
-- itu tetap berlaku di sini: fungsi ini HANYA menyentuh Transparency.
--
-- Tidak ada yang dihapus, dijangkarkan, atau diubah CanCollide/CanTouch-nya.
-- Alasannya konkret, ketiganya jalur inti yang pernah rusak karena hal serupa:
--   * daftarTanaman() membaca PrimaryPart.Position -- Transparency tidak
--     mengubah posisi, menghapus part mengubahnya jadi nil.
--   * panen menembak remote memakai id buah, bukan klik visual.
--   * pencabutan butuh CanTouch (lihat catatan panjang di brutalkan()).
--
-- Jadi "hide" di sini benar-benar hanya menyembunyikan, bukan membuang.

-- Yang disembunyikan HANYA isi folder Plants: tanaman beserta buahnya.
--
-- Sisa plot sengaja dibiarkan terlihat -- TopLayer, PlantAreaColumn,
-- PlotSizeReference, Signs, Sprinklers. Itu LAHAN tempat menanam, bukan sesuatu
-- yang tumbuh, dan menyembunyikannya tidak menghemat apa pun yang berarti.
--
-- Versi sebelumnya menyaring dengan "seluruh isi plot kecuali Base", yang ikut
-- menjangkau perabot plot. Terukur berdampingan di kebun sungguhan: cara lama
-- menyembunyikan 12.474 part, cara ini 12.264 -- jadi selisihnya sekitar 280
-- part lahan, bukan mayoritas. Yang menentukan bukan jumlahnya melainkan
-- jenisnya: lahan tidak boleh ikut disentuh karena di situlah menanam.
--
-- Buah tidak lagi perlu dikenali terpisah: folder Fruits memang di dalam Plants.
--
-- `Base` kini IKUT disembunyikan. Ia cuma dibaca lewat .Position oleh
-- daftarTanaman(), dan posisi tidak peduli pada Transparency.
local function sembunyikanSatu(d)
    if not d or not d.Parent then return false end
    if not (d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture")) then return false end

    local plotku = plotSayaCepat()
    if not plotku then return false end

    local plants = plotku:FindFirstChild("Plants")
    if not plants or not d:IsDescendantOf(plants) then return false end

    pcall(function()
        d.Transparency = 1
        -- CastShadow ikut dimatikan. Part yang TEMBUS PANDANG tetap melemparkan
        -- bayangan di Roblox -- terukur 2.440 part masih CastShadow=true di kebun
        -- yang seluruhnya sudah disembunyikan. Ini murni properti gambar: posisi,
        -- CanTouch, dan ProximityPrompt tidak tersentuh sama sekali.
        if d:IsA("BasePart") then d.CastShadow = false end
    end)
    return true
end

-- Pemulihan tampilan DIHAPUS bersama sakelarnya.
--
-- Dulu Transparency asli dicatat di atribut FHTransAsli supaya mematikan opsinya
-- bisa mengembalikan tampilan. Sekarang tidak ada yang bisa dimatikan, jadi
-- pencatatan itu murni biaya: satu penulisan atribut untuk tiap dari ~4.100 part
-- kebun, pada perangkat yang justru sedang menahan 8-10 akun sekaligus.
local function sembunyikanKebun()
    local plotku = plotSayaCepat()
    if not plotku then return 0 end

    -- Ditelusuri dari folder Plants, bukan dari seluruh plot. Selain sesuai
    -- cakupan di atas, ini juga jauh lebih murah: lahan dan perabot plot tidak
    -- ikut dilewati satu per satu tiap kali sapuan berjalan.
    local plants = plotku:FindFirstChild("Plants")
    if not plants then return 0 end

    local kena, hitung = 0, 0
    for _, d in ipairs(plants:GetDescendants()) do
        if sembunyikanSatu(d) then kena = kena + 1 end
        hitung = hitung + 1
        if hitung % 500 == 0 then task.wait() end
    end
    return kena
end

-- ==========================================================
-- HAPUS ANIMASI
-- ==========================================================
--
-- Hanya menyentuh karakter PEMAIN. NPC sengaja tidak disentuh: Sam/Gilbert,
-- George, Steven, dan Ethan dicari lewat HumanoidRootPart untuk beli, jual, dan
-- pindah dunia -- dan komentar di bolehDibrutalkan() sudah mencatat kenapa
-- merusak NPC itu mahal.
--
-- Menghapus Animator TIDAK menghentikan gerak: Humanoid tetap berjalan lewat
-- MoveTo dan CFrame, yang mati cuma pemutaran animasinya.
local function hapusAnimasiPada(char)
    if not char then return 0 end
    local n = 0
    for _, o in ipairs(char:GetDescendants()) do
        if o:IsA("Animator") or o:IsA("Animation") then
            if pcall(function() o:Destroy() end) then n = n + 1 end
        end
    end
    local animate = char:FindFirstChild("Animate")
    if animate then
        if pcall(function() animate.Disabled = true end) then n = n + 1 end
    end
    return n
end

local function hapusAnimasi()
    local n = 0
    for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
        n = n + hapusAnimasiPada(pl.Character)
    end
    return n
end

local hookAnimasiTerpasang = false

local function pasangHookAnimasi()
    if hookAnimasiTerpasang then return end
    hookAnimasiTerpasang = true

    -- Respawn memasang ulang Animate dan Animator dari StarterCharacter, jadi
    -- sapuan sekali di awal hanya bertahan sampai kematian pertama. Ini yang
    -- membuat "remove animation" terlihat menyala sebentar lalu mati sendiri.
    local Players = game:GetService("Players")

    local function ikuti(pl)
        pl.CharacterAdded:Connect(function(char)
            task.wait(1)  -- beri waktu Animate dan Animator terpasang dulu
            hapusAnimasiPada(char)
        end)
    end

    for _, pl in ipairs(Players:GetPlayers()) do ikuti(pl) end
    Players.PlayerAdded:Connect(function(pl)
        ikuti(pl)
        if pl.Character then hapusAnimasiPada(pl.Character) end
    end)
end

-- Satu pintu untuk tiap instance baru.
--
-- Urutannya penting: brutalkan() mengembalikan false persis ketika d DILINDUNGI
-- -- kebun sendiri, karakter, NPC, Terrain. Kebun sendiri itulah satu-satunya
-- tempat penyembunyian bekerja, jadi menaruh sembunyikanSatu() di jalur "ditolak
-- brutalkan" membuat keduanya tidak pernah menyentuh instance yang sama.
local function tanganiBaru(d)
    if brutalkan(d) then return end
    sembunyikanSatu(d)
end

-- Antrean batch untuk hook DescendantAdded.
--
-- Versi sebelumnya memanggil task.defer SEKALI PER EVENT. Terukur 88 event/detik
-- di server ramai; dengan 8-10 client dalam satu perangkat itu jadi ~880
-- penjadwalan per detik yang saling berebut CPU yang sama.
--
-- Di sini event cuma dimasukkan ke tabel, dan SATU pemroses dijadwalkan untuk
-- seluruh gelombang. Beban penjadwalan turun dari per-event jadi per-frame,
-- sementara pekerjaan nyatanya tetap sama persis.
--
-- Sifat "tunda satu langkah" yang dulu diandalkan tetap terjaga: pemrosesnya
-- sendiri dijalankan lewat task.defer, jadi anak-anak instance baru sudah
-- terpasang saat dinilai.
local antreanBaru, antreanIsi = {}, 0
local pemrosesJalan = false

local function prosesAntrean()
    pemrosesJalan = true
    while antreanIsi > 0 do
        -- Tabelnya DITUKAR, bukan dikosongkan sambil ditelusuri. Event baru
        -- terus berdatangan selama pemrosesan; menulis dan membaca tabel yang
        -- sama membuat sebagian entri terlewat diam-diam.
        local batch, jumlah = antreanBaru, antreanIsi
        antreanBaru, antreanIsi = {}, 0

        for i = 1, jumlah do
            tanganiBaru(batch[i])
        end
        task.wait()  -- satu frame, supaya gelombang besar tidak memblokir
    end
    pemrosesJalan = false
end

local hookTerpasang = false

local function pasangHookBrutal()
    if hookTerpasang then return end
    hookTerpasang = true

    -- Inilah bagian yang membuat FPS BERTAHAN, bukan cuma naik sesaat.
    -- Sapuan sekali jalan hanya membereskan yang ada SAAT ITU; game terus
    -- memunculkan buah, VFX, dan efek cuaca baru, sehingga tanpa hook ini FPS
    -- merosot lagi dalam hitungan menit. Diambil dari pola Workspace
    -- .DescendantAdded di script.txt.
    workspace.DescendantAdded:Connect(function(d)
        -- Penyembunyian ikut menumpang hook ini. Tanaman dan buah TUMBUH terus
        -- selama bot jalan; tanpa jalur ini "hide" hanya berlaku untuk yang ada
        -- saat script mulai, dan kebun perlahan terlihat lagi dengan sendirinya.
        --
        -- Saringan kelas didahulukan, dan sengaja memakai perbandingan string
        -- biasa -- bukan :IsA() -- karena ini jalur terpanas di seluruh script.
        --
        -- Terukur di server ramai: 88 event/detik, dan 73% di antaranya Folder
        -- dan Model. Keduanya tidak pernah kita ubah apa pun, jadi menjadwalkan
        -- task.defer untuk mereka murni pemborosan. Anak-anaknya tetap terjamah
        -- karena DescendantAdded ikut menyala untuk tiap keturunan.
        local k = d.ClassName
        if k == "Folder" or k == "Model" or k == "Configuration"
           or k == "Script" or k == "LocalScript" or k == "ModuleScript" then
            return
        end

        -- Masuk antrean, bukan dijadwalkan sendiri-sendiri. Pemrosesnya
        -- dinyalakan sekali per gelombang -- lihat catatan di prosesAntrean().
        antreanIsi = antreanIsi + 1
        antreanBaru[antreanIsi] = d
        if not pemrosesJalan then
            pemrosesJalan = true  -- disetel di sini, bukan menunggu pemrosesnya
                                  -- benar-benar mulai. task.defer baru berjalan
                                  -- frame berikutnya, dan dalam jeda itu puluhan
                                  -- event lain bisa ikut menjadwalkan pemroses
                                  -- kedua, ketiga, dan seterusnya.
            task.defer(prosesAntrean)
        end
    end)
end

-- ==========================================================
-- BOOST FPS: BERTAHAP, SATU LANGKAH PER SIKLUS
-- ==========================================================
-- Dulu semuanya ditembakkan sekaligus dalam satu fase: sembunyikan kebun, hapus
-- kebun orang, sapu 23.000 instance workspace, lalu 113.000 instance global,
-- plus membuang GUI dan mengosongkan SoundService.
--
-- Di satu PC itu lewat begitu saja. Masalahnya 8-10 client start BERBARENGAN di
-- satu perangkat cloud: puluhan ribu penghapusan instance dan ratusan ribu
-- pembacaan terjadi serentak di detik yang sama, dan lonjakan itu yang membuat
-- klien tersendat bahkan mati.
--
-- Sekarang dipecah kecil-kecil, SATU langkah per siklus. Urutannya disusun dari
-- yang paling murah dan paling terasa lebih dulu, jadi FPS sudah naik sejak
-- siklus pertama sementara pekerjaan berat menyusul perlahan di belakang.
local langkahBoost = 1

local LANGKAH_BOOST = {

    -- 1. Paling murah, paling besar dampaknya: hanya menyetel properti, tidak
    --    menyentuh satu instance pun. Karena itu ditaruh paling depan.
    { "render", function()
        if Config.BatasFps and Config.BatasFps > 0 and typeof(setfpscap) == "function" then
            pcall(setfpscap, Config.BatasFps)
            status(string.format("[FPS] Batas frame %d", Config.BatasFps))
        end

        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)

        -- MUTE TOTAL: MasterVolume + SoundService reset
        pcall(function()
            UserSettings():GetService("UserGameSettings").MasterVolume = 0
            local SoundService = game:GetService("SoundService")
            SoundService.AmbientReverb = Enum.ReverbType.NoReverb
            SoundService.DistanceFactor = 0
            SoundService.DopplerScale = 0
            SoundService.RolloffScale = 0
            -- Hapus semua Sound/SoundGroup di SoundService
            for _, obj in ipairs(SoundService:GetDescendants()) do
                if obj:IsA("Sound") or obj:IsA("SoundGroup") then
                    pcall(function() obj:Destroy() end)
                end
            end
        end)

        -- POV didekatkan: kamera dikunci ke jarak minimum dan FOV dipersempit,
        -- jadi yang masuk kerucut pandang tinggal sekitar karakter. Hanya
        -- berguna kalau render 3D menyala -- tetap dipasang karena murah, dan
        -- jadi penyelamat kalau executor tidak punya Set3dRenderingEnabled.
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = 0.5
            LocalPlayer.CameraMinZoomDistance = 0.5
            workspace.CurrentCamera.FieldOfView = 20
        end)

        -- RENDER 3D DIMATIKAN TOTAL. Satu-satunya yang menyentuh biaya per
        -- FRAME, bukan per objek. Terukur: RAM tidak berubah sama sekali
        -- (2363 -> 2364 MB) -- yang dihemat murni waktu render, dan itulah yang
        -- jadi rebutan saat 8-10 client berbagi satu GPU.
        --
        -- Aman: seluruh berkas ini hanya menyentuh render satu kali, yaitu
        -- CurrentCamera.FieldOfView di pasangBlackScreen(). Tidak ada
        -- RenderStepped, ViewportSize, maupun WorldToScreenPoint di mana pun.
        -- GUI 2D tidak ikut mati, jadi panel status tetap terbaca.
        if typeof(RunService.Set3dRenderingEnabled) == "function" then
            local ok = pcall(function() RunService:Set3dRenderingEnabled(false) end)
            status(ok and "[FPS] Render 3D dimatikan" or "[FPS] Render 3D gagal dimatikan")
        end
    end },

    -- 2. Masih sangat murah: belasan objek, tapi mematikan seluruh mesin
    --    bayangan dan cuaca.
    { "lighting", function()
        pcall(function()
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0

            -- GlobalShadows=false saja tidak cukup: mesin bayangannya sendiri
            -- masih ShadowMap. Technology ternyata BISA diubah saat berjalan --
            -- terverifikasi ShadowMap -> Compatibility -- dan Compatibility
            -- tidak menghitung bayangan dinamis sama sekali.
            pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)

            -- SELURUH anak dibuang, bukan hanya kelas tertentu. Daftar kelas
            -- sebelumnya melewatkan "Charles" bertipe Configuration, dan
            -- "ActiveNightAtmosphere" baru muncul setelah yang lain dibuang.
            for _, c in ipairs(Lighting:GetChildren()) do
                pcall(function() c:Destroy() end)
            end
        end)

        -- Awan volumetrik: anak Terrain, BUKAN Lighting -- itu sebabnya ia lolos
        -- dari pembersihan di atas maupun dari WADAH_HIASAN.
        pcall(function()
            local awan = workspace.Terrain:FindFirstChildOfClass("Clouds")
            if awan then awan:Destroy() end
        end)

        -- Visual cuaca milik WeatherController. Yang dibuang HANYA objeknya,
        -- bukan controller-nya: script game masih boleh jalan, ia sekadar tidak
        -- punya apa pun untuk digambar.
        pcall(function()
            local ctrl = LocalPlayer:FindFirstChild("PlayerScripts")
            ctrl = ctrl and ctrl:FindFirstChild("Controllers")
            ctrl = ctrl and ctrl:FindFirstChild("WeatherController")
            if not ctrl then return end
            for _, d in ipairs(ctrl:GetDescendants()) do
                if d:IsA("Sky") or d:IsA("Atmosphere") or d:IsA("ParticleEmitter")
                   or d:IsA("Beam") or d:IsA("Trail") then
                    pcall(function() d:Destroy() end)
                end
            end
        end)
        status("[FPS] Lighting, bayangan, awan, dan cuaca dimatikan")
    end },

    -- 3. Animasi: hanya karakter pemain, jumlahnya kecil.
    { "animasi", function()
        local n = hapusAnimasi()
        pasangHookAnimasi()
        if n > 0 then status(string.format("[TAMPILAN] %d animasi dihapus", n)) end
    end },

    -- 4. GUI dan suara. Penghapusan pertama yang jumlahnya besar (~9.000
    --    instance), jadi ditaruh setelah semua yang murah selesai.
    { "gui-suara", function()
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            local set = {}
            for _, nm in ipairs(GUI_BUANG) do set[nm] = true end
            local n = 0
            for _, g in ipairs(pg:GetChildren()) do
                if set[g.Name] then
                    pcall(function() g:Destroy() end)
                    n = n + 1
                end
            end
            if n > 0 then status(string.format("[FPS] %d ScreenGui tak terpakai dibuang", n)) end
        end)

        -- SoundService dikosongkan: bot tidak memakai satu pun suara, dan tidak
        -- ada alur yang menunggu Sound.Ended di sini (yang begitu ada di
        -- workspace, ditangani terpisah).
        pcall(function()
            for _, c in ipairs(game:GetService("SoundService"):GetChildren()) do
                pcall(function() c:Destroy() end)
            end
        end)
    end },

    -- 5. Wadah hiasan dunia + Baseplate.Decor.
    { "hiasan", function()
        local n = nukeLingkungan()
        status(string.format("[FPS] %d wadah hiasan dibuang", n))
    end },

    -- 6. Kebun orang lain: penghapusan terbesar dari sisi instance. Fungsi ini
    --    menunggu kebun SENDIRI termuat lebih dulu -- itu penjagaannya, jangan
    --    dipindah ke depan.
    { "kebun-orang", function()
        bersihkanKebunOrang(true)
        -- Kebun sendiri dibuang di langkah yang SAMA, bukan langkah tersendiri:
        -- keduanya butuh plotSaya() sudah termuat, dan itu penantian 20 detik yang
        -- tidak perlu dibayar dua kali.
        if Config.ModeBeliSaja then hancurkanKebunSendiri() end
    end },

    -- 7. Sembunyikan kebun sendiri.
    { "sembunyi-kebun", function()
        local n = sembunyikanKebun()
        if n > 0 then
            status(string.format("[TAMPILAN] %d bagian kebun disembunyikan", n))
        end
    end },

    -- 8. Sapuan workspace: ~23.000 instance.
    { "sapuan-workspace", function()
        local hitung, kena = 0, 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if brutalkan(d) then kena = kena + 1 end
            hitung = hitung + 1
            if hitung % 500 == 0 then task.wait() end
        end
        status(string.format("[FPS] %d objek workspace dibrutalkan", kena))
    end },

    -- 9. Sapuan global: ~113.000 instance, yang TERBERAT. Sengaja paling
    --    belakang supaya seluruh penghematan murah sudah berlaku duluan.
    { "sapuan-global", function()
        pcall(function()
            -- DUA pencacah, dan itu wajib. `n` menghitung yang KENA, `langkah`
            -- yang DILEWATI; throttle harus memakai `langkah`.
            --
            -- Dulu memakai `n`, dan itu keliru: `n` hanya bertambah saat ada
            -- yang cocok, sedangkan `0 % 500 == 0` bernilai benar. Selama `n`
            -- berhenti di kelipatan 500 -- termasuk 0 di awal -- task.wait()
            -- dipanggil di SETIAP instance. Diukur berdampingan: throttle `n`
            -- 1.681 wait / 84,1 detik, throttle `langkah` 226 wait / 11,3 detik.
            local n, langkah = 0, 0
            for _, d in ipairs(game:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
                   or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                    -- Di luar workspace efeknya DIMATIKAN, bukan dihapus: banyak
                    -- yang template di ReplicatedStorage, dan menghapusnya
                    -- membuat clone berikutnya gagal.
                    pcall(function() d.Enabled = false end)
                    n = n + 1
                elseif d:IsA("Sound") then
                    pcall(function()
                        d.Volume = 0
                        d.Playing = false
                    end)
                    n = n + 1
                end
                langkah = langkah + 1
                if langkah % 500 == 0 then task.wait() end
            end
            status(string.format("[FPS] %d efek/suara global dimatikan", n))
        end)
    end },

    -- 10. Penutup: pulihkan CanTouch, lalu pasang hook.
    { "hook", function()
        -- Versi lama pernah mematikan CanTouch di seluruh workspace dan
        -- penjagaan kebun sendiri bocor -- 92% part kebun ikut termatikan, dan
        -- selama itu shovel ditolak server tanpa pesan. Dipulihkan di sini
        -- supaya klien yang terlanjur sembuh sendiri tanpa rejoin.
        pcall(function()
            local p = plotSaya()
            if not p then return end
            local pulih = 0
            for _, d in ipairs(p:GetDescendants()) do
                if d:IsA("BasePart") and d.CanTouch == false then
                    d.CanTouch = true
                    pulih = pulih + 1
                end
            end
            if pulih > 0 then
                status(string.format("[FPS] %d part kebun dipulihkan CanTouch-nya", pulih))
            end
        end)

        -- PALING AKHIR. Kalau dipasang sebelum sapuan, hook ikut menembak tiap
        -- instance yang tersentuh sapuan dan pekerjaannya berlipat dua.
        pasangHookBrutal()
    end },
}

-- Masih ada langkah yang belum dijalankan? Dipakai penyusun fase untuk
-- memutuskan apakah "fps-boost" perlu dijadwalkan lagi siklus ini.
local function boostBelumSelesai()
    return langkahBoost <= #LANGKAH_BOOST
end

-- Menjalankan SATU langkah tiap dipanggil. Siklus berikutnya melanjutkan.
local function applyFpsBoost()
    if langkahBoost > #LANGKAH_BOOST then return end

    local nama = LANGKAH_BOOST[langkahBoost][1]
    local fn = LANGKAH_BOOST[langkahBoost][2]
    local urutan = langkahBoost

    -- Dinaikkan SEBELUM dijalankan. Kalau langkahnya melempar error, ia tidak
    -- diulang selamanya di tiap siklus -- satu langkah gagal lebih baik
    -- daripada boost yang macet di situ dan tidak pernah sampai ke sisanya.
    langkahBoost = langkahBoost + 1

    status(string.format("[FPS] Langkah %d/%d: %s", urutan, #LANGKAH_BOOST, nama))
    fn()

    if langkahBoost > #LANGKAH_BOOST then
        status("[FPS] Selesai — semua langkah dijalankan")
    end
end

-- ==========================================================
-- SHOP
-- ==========================================================
-- Struktur UI-nya sama persis dengan SeedShop di GAG2: Frame.NormalShop berisi
-- kartu bernama item, harga di Cost_Text ("1c", "2.5Kc", "NO STOCK").
local function parseHarga(teks)
    if not teks then return 0 end
    local c = string.upper(teks)
    c = c:gsub("%s+", ""):gsub("\194\162", ""):gsub("\238\128\130", "")
    if c:match("^X%d+") then return 0 end
    local num, suf = c:match("([%d%.%,]+)([MBK]?)")
    if not num then return 0 end
    local a = tonumber((num:gsub(",", ""))) or 0
    if suf == "K" then a = a * 1e3 elseif suf == "M" then a = a * 1e6 elseif suf == "B" then a = a * 1e9 end
    return a
end

-- namaGui: Baker shop memakai struktur kartu yang IDENTIK (Cost_Text/Stock_Text),
-- terukur 2026-08-26. Dipakai bersama, bukan disalin -- salinan kedua pasti
-- melenceng begitu format kartunya berubah sebelah.
local function stokShop(namaGui)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pg and pg:FindFirstChild(namaGui or "SeedShop")
    local frame = shop and shop:FindFirstChild("Frame")
    local wadah = frame and (frame:FindFirstChild("NormalShop") or frame:FindFirstChild("ScrollingFrame"))
    if not wadah then return {} end

    local hasil = {}
    for _, kartu in ipairs(wadah:GetChildren()) do
        if kartu:IsA("Frame") and kartu.Name ~= "ItemTemplate" and kartu.Name ~= "Padding" then
            local cost = kartu:FindFirstChild("Cost_Text", true)
            local harga = cost and parseHarga(cost.Text) or 0
            if harga > 0 then
                hasil[#hasil + 1] = { nama = kartu.Name, harga = harga, rarity = nilaiRarity(kartu.Name) }
            end
        end
    end
    -- Termurah dulu, sesuai permintaan: beli dari termurah sampai termahal.
    table.sort(hasil, function(a, b) return a.harga < b.harga end)
    return hasil
end

-- Kapasitas buah: dibaca dari atribut pemain, bukan dihitung manual dari
-- Backpack -- server yang memegang angka sebenarnya.
local function jumlahBuah()
    return tonumber(LocalPlayer:GetAttribute("FruitCount")) or 0
end
local function kapasitasBuah()
    return tonumber(LocalPlayer:GetAttribute("MaxFruitCapacity")) or 100
end

-- Posisi NPC. Perannya dipastikan dari Script di dalam ProximityPrompt masing-
-- masing: Sam & Gilbert membuka SeedShop, George membuka GearShop, Steven jual.
local NPC_PERAN = { seed = { "Sam", "Gilbert" }, gear = { "George" }, jual = { "Steven" } }

local function posisiNPC(peran)
    local npcs = workspace:FindFirstChild("NPCS")
    if not npcs then return nil, nil end
    for _, nama in ipairs(NPC_PERAN[peran] or {}) do
        local n = npcs:FindFirstChild(nama)
        local root = n and (n:FindFirstChild("HumanoidRootPart") or n.PrimaryPart)
        if root then return root.Position, nama end
    end
    return nil, nil
end

-- Apakah game sudah selesai memuat dan menyerahkan kendali?
--
-- Syaratnya disalin persis dari PlayerActivityController milik game:
--     LoadingScreenDone == true
--     and OfflineCutscenePlaying ~= true
--     and CutsceneInputBlocked ~= true
--
-- Ini yang hilang dan membuat akun BARU selalu gagal menanam. Selama pemuatan,
-- pemain ditahan di LoadingCam/LoadingScreenCam -- keduanya ada di dalam plot --
-- dan gerakan dikembalikan server. Bot yang langsung bertani akan terbang,
-- ditarik balik, lalu menyerah dengan "Gagal mencapai kebun sendiri".
--
-- Akun lama melewati fase ini dalam sekejap sehingga tidak pernah terlihat;
-- akun baru kena cutscene perkenalan yang jauh lebih panjang.
-- Atribut mana yang sedang MENAHAN, beserta nilainya. nil = semuanya beres.
--
-- Nilainya ikut dikembalikan karena itu yang membedakan dua sebab yang gejalanya
-- identik tapi penanganannya berlawanan:
--     LoadingScreenDone=false  -> game memang masih memuat, menunggu itu benar
--     LoadingScreenDone=nil    -> dunia ini tidak pernah punya atribut itu,
--                                 menunggu berapa lama pun tidak akan berubah
-- Tanpa nilainya di log, keduanya sama-sama muncul sebagai "bot diam" dan tidak
-- ada cara membedakannya selain menebak.
local function penahanSiap()
    local v = LocalPlayer:GetAttribute("LoadingScreenDone")
    if v ~= true then return "LoadingScreenDone", v end
    v = LocalPlayer:GetAttribute("LoadingScreenActive")
    if v == true then return "LoadingScreenActive", v end
    v = LocalPlayer:GetAttribute("OfflineCutscenePlaying")
    if v == true then return "OfflineCutscenePlaying", v end
    v = LocalPlayer:GetAttribute("CutsceneInputBlocked")
    if v == true then return "CutsceneInputBlocked", v end
    return nil
end

local function siapBermain()
    return penahanSiap() == nil
end

-- Gate sudah pernah kehabisan waktu sekali. Dipegang di luar fungsi supaya
-- bertahan antar siklus.
local gateDilepas = false

-- Penghitung watchdog dunia-gagal-muat. Dipakai di loop utama; ditaruh di sini
-- supaya berada di scope yang sama dengan gateDilepas yang jadi pemicunya.
local siklusTanpaDunia = 0
local rejoinMacetTerakhir = 0
local SIKLUS_SEBELUM_REJOIN = 3

-- Satu tabel, bukan beberapa local terpisah: scope file di dunia ini sudah dekat
-- batas 200 local Luau, dan tabel tidak menambah hitungannya per field.
--   gatePada    kapan gate terakhir dilepas, untuk penjadwalan coba-lagi
--   leavesSejak sejak kapan Leaves duduk di ambang bawah; 0 = sedang tidak macet
local jagaMacet = { gatePada = 0, leavesSejak = 0 }

-- Menunggu sampai siap, dengan BATAS WAKTU.
--
-- Batasnya ada supaya satu atribut yang tidak pernah muncul -- misalnya karena
-- update game mengganti namanya -- tidak mengunci bot selamanya. Lebih baik
-- lanjut sambil memberi peringatan daripada diam tanpa sebab.
local function tungguSiap(detikMaks)
    detikMaks = detikMaks or Config.TungguSiapDetik

    if penahanSiap() == nil then
        -- Penahannya beres: gate DIPASANG LAGI.
        --
        -- Ini yang membuat pelepasan tidak permanen. Kalau nanti muncul penahan
        -- baru -- cutscene event, layar muat setelah teleport antar dunia --
        -- perlindungannya sudah aktif kembali, bukan tergadai sejak timeout
        -- pertama satu jam yang lalu.
        gateDilepas = false
        return true
    end

    -- Gate dilepas supaya siklus tidak membakar penuh setiap putaran menunggu
    -- sesuatu yang sudah terbukti tidak datang. Tapi pelepasannya BERBATAS WAKTU.
    --
    -- Versi lama melepasnya untuk seterusnya. Konsekuensinya: satu penahan yang
    -- sifatnya sementara -- cutscene perkenalan akun baru yang kebetulan lebih
    -- panjang dari batas -- mengunci sisa sesi, karena tidak ada lagi jalan untuk
    -- menunggunya dengan benar. Sekarang setelah GateCobaLagiDetik, satu
    -- penantian penuh boleh dicoba lagi.
    if gateDilepas then
        if tick() - jagaMacet.gatePada < Config.GateCobaLagiDetik then return false end
        gateDilepas = false
        status("[TUNGGU] Mencoba menunggu pemuatan sekali lagi setelah gate sempat dilepas")
    end

    local nama, nilai = penahanSiap()
    status(string.format("[TUNGGU] Game masih memuat (%s=%s) — bertani ditahan dulu",
        nama, tostring(nilai)))

    local batas = tick() + detikMaks
    local laporBerikut = tick() + 15
    while tick() < batas do
        if penahanSiap() == nil then
            status("[TUNGGU] Selesai memuat, bertani dimulai")
            return true
        end
        -- Dilaporkan berkala, bukan sekali di depan: kalau penahannya BERGANTI
        -- (LoadingScreenDone beres lalu cutscene mulai) itu pemuatan normal yang
        -- sedang maju. Penahan yang sama selama 120 detik berarti macet.
        if tick() >= laporBerikut then
            local n, v = penahanSiap()
            status(string.format("[TUNGGU] Masih ditahan %s=%s (%d detik lagi)",
                n, tostring(v), math.floor(batas - tick())))
            laporBerikut = tick() + 15
        end
        task.wait(1)
    end

    local n, v = penahanSiap()
    gateDilepas = true
    jagaMacet.gatePada = tick()
    status(string.format(
        "[TUNGGU] Batas waktu %ds tercapai — %s=%s tidak pernah beres. Gate dilepas, dicoba lagi dalam %ds.",
        math.floor(detikMaks), n, tostring(v), math.floor(Config.GateCobaLagiDetik)))
    return false
end

local function leaves()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local n = ls and ls:FindFirstChild("Leaves")
    return n and n.Value or 0
end

-- ==========================================================
-- AKSI
-- ==========================================================
local function toolBernama(nama)
    for _, wadah in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
        if wadah then
            for _, t in ipairs(wadah:GetChildren()) do
                if t:IsA("Tool") and (t.Name == nama or t:GetAttribute("SeedTool") == nama) then return t end
            end
        end
    end
end

local function equip(tool)
    local _, _, hum = karakter()
    if not (tool and hum) then return false end
    if tool.Parent == LocalPlayer.Character then return true end
    pcall(function() hum:EquipTool(tool) end)
    -- Ditunggu sampai BENAR-BENAR pindah, bukan jeda tetap. Terukur biasanya
    -- 0.001 detik, tapi bisa gagal total kalau karakter belum mendarat -- dan
    -- jeda tetap akan mengembalikan "gagal" padahal cuma kurang sabar.
    local batas = tick() + 2
    while tick() < batas do
        if tool.Parent == LocalPlayer.Character then return true end
        task.wait(0.05)
    end
    return false
end

-- Ditandai oleh fase tanam saat benar-benar tidak ada titik kosong tersisa.
-- Dipakai fase beli untuk memutuskan apakah masih layak membeli seed murah.
local kebunPenuh = false

-- Rarity TERENDAH yang sedang tumbuh. Saat kebun penuh, membeli seed di bawah
-- angka ini sia-sia: tidak ada yang bisa digantikan olehnya, jadi Leaves-nya
-- terbuang. Ini yang kamu maksud "jangan beli yang di bawah rarity kebun".
local function rarityTerendahKebun()
    local terendah = math.huge
    for _, p in ipairs(daftarTanaman()) do
        if p.rarity > 0 and p.rarity < terendah then terendah = p.rarity end
    end
    return (terendah == math.huge) and 0 or terendah
end

-- abaikanSaringKebunPenuh: melewati penyaring rarity di bawah.
--
-- Dipakai HANYA oleh belanja target saat speedrun. Penyaring itu membuang seed
-- yang tidak bisa menggantikan tanaman terlemah -- benar untuk belanja biasa,
-- salah untuk penimbunan, karena yang dibeli memang tidak untuk ditanam
-- sekarang. Dijadikan parameter, bukan cabang tersembunyi, supaya jelas di
-- tiap pemanggilan mana yang menonaktifkan penjagaan ini.
local function beli(daftar, abaikanSaringKebunPenuh)
    -- BEDA dengan panen/tanam/jual: membeli WAJIB dari dekat.
    --
    -- Secara teknis PurchaseSeed tetap diterima dari jarak jauh, tapi anticheat
    -- menandainya dan ban menyusul belakangan -- jadi "berhasil" di sini justru
    -- menyesatkan. Karena itu mendekat bukan opsi yang bisa dimatikan lewat
    -- config, dan kalau gagal mencapai NPC, pembelian DIBATALKAN seluruhnya.
    -- Kebun penuh -> saring dulu. Seed yang rarity-nya tidak lebih tinggi dari
    -- tanaman terlemah di kebun tidak bisa menggantikan apa pun, jadi membelinya
    -- hanya membuang Leaves. Saat kebun MASIH ADA RUANG, semua boleh dibeli --
    -- mengisi tanah kosong selalu lebih baik daripada membiarkannya menganggur.
    -- Penyaring rarity berlaku walau kebun MASIH ADA RUANG.
    --
    -- Dulu hanya aktif saat kebun penuh. Akibatnya kebun yang seluruh tanamannya
    -- sudah r3 tetap membeli r3 lagi hanya karena masih ada tanah kosong -- dan
    -- itu tidak menaikkan apa pun, cuma menghabiskan Leaves yang seharusnya
    -- dipakai naik ke r4.
    --
    -- Kebun KOSONG tidak ikut terhambat: rarityTerendahKebun() mengembalikan 0
    -- saat tidak ada tanaman, dan semua seed lolos syarat `> 0`. Jadi mulai dari
    -- nol tetap membeli apa pun yang ada, tanpa perlu pengecualian khusus.
    if Config.FokusRarityNaik and not abaikanSaringKebunPenuh then
        local batasRarity = rarityTerendahKebun()
        local tersaring = {}
        for _, s in ipairs(daftar) do
            if s.rarity > batasRarity then tersaring[#tersaring + 1] = s end
        end
        if #tersaring == 0 then
            status(string.format("[LEWAT] Kebun terendah r%d, tidak ada seed di atasnya di shop%s",
                batasRarity, kebunPenuh and "" or " — tanah kosong dibiarkan, menunggu restock"))
            return 0
        end
        status(string.format("[SARING] Terendah r%d — hanya beli rarity di atasnya (%d dari %d item)",
            batasRarity, #tersaring, #daftar))
        daftar = tersaring
    end

    -- PRIORITAS TULANG PUNGGUNG.
    --
    -- Seed di Config.SeedTarget didahulukan tanpa memandang rarity. Bambu
    -- rarity Rare, jadi urutan menurut rarity saja akan menaruhnya di belakang
    -- Epic/Legendary yang jauh lebih mahal dan lebih lambat matang -- padahal
    -- bambu justru yang untung per menit per petaknya tertinggi.
    --
    -- Stok bambu terbatas per restock (7-11), jadi kalau Leaves keburu habis
    -- untuk seed lain, jatah bambu terlewat sampai restock berikutnya.
    local prioritas = {}
    for i, nm in ipairs(Config.SeedTarget or {}) do prioritas[nm] = i end
    if next(prioritas) then
        table.sort(daftar, function(a, b)
            local pa, pb = prioritas[a.nama], prioritas[b.nama]
            if pa and pb then return pa < pb end
            if pa then return true end
            if pb then return false end
            -- Sisanya tetap urut rarity tertinggi dulu, seperti sebelumnya.
            return (a.rarity or 0) > (b.rarity or 0)
        end)
    end

    local pos, nama = posisiNPC("seed")
    if not pos then
        status("[BATAL] NPC penjual seed tidak ketemu")
        return 0
    end
    if not pergiKe(pos) then
        status("[BATAL] Gagal mencapai " .. tostring(nama) .. " — beli dilewati demi keamanan")
        return 0
    end
    status("[BELI] Di dekat " .. tostring(nama) .. " (jarak " .. math.floor(jarakKe(pos)) .. ")")

    local dibeli = 0
    for _, s in ipairs(daftar) do
        if not Config.AutoBeli then
            status("[BATAL] Auto Buy Seed dimatikan dari web")
            break
        end

        -- Jarak diperiksa ulang tiap item: karakter bisa terdorong menjauh di
        -- tengah pembelian, dan satu fire dari jauh sudah cukup untuk ditandai.
        if jarakKe(pos) > Config.JarakAman * 2 then
            -- DICOBA ULANG, bukan langsung menyerah.
            --
            -- Versi lama menghentikan SELURUH sisa pembelian begitu satu kali
            -- kembali gagal. Padahal terlempar dari NPC itu lumrah dan sesaat:
            -- server menarik posisi karakter, tombol teleport punya cooldown
            -- 0,3 detik, dan percobaan yang kebetulan jatuh di dalam cooldown
            -- itu pasti gagal. Sekali gagal lalu batal berarti membuang seluruh
            -- daftar belanja hanya karena satu tembakan meleset.
            --
            -- Tiga percobaan dengan jeda pendek: kalau memang cuma tersenggol,
            -- percobaan kedua hampir selalu berhasil.
            local kembali = false
            for percobaan = 1, 3 do
                if pergiKe(pos) then kembali = true break end
                task.wait(0.6)
            end
            if not kembali then
                status("[BATAL] Terlempar dari NPC dan gagal kembali 3x — sisa pembelian dihentikan")
                break
            end
        end
        if dibeli >= Config.MaxBeliPerSiklus then break end

        -- Tidak terjangkau -> LEWATI, jangan hentikan seluruh pembelian.
        --
        -- Dulu di sini `break`, dengan alasan "daftar terurut, sisanya pasti
        -- lebih mahal". Alasan itu benar sampai urutan prioritas SeedTarget
        -- ditambahkan -- sejak itu daftar diurutkan menurut PRIORITAS lalu
        -- rarity, bukan harga.
        --
        -- Akibatnya mematikan bagi akun baru, dan terukur: dengan 1 Leaf, item
        -- pertama adalah Maple Bamboo seharga 700, jadi `break` membatalkan
        -- seluruh belanja -- padahal Maple Carrot di urutan kedelapan berharga
        -- PERSIS 1. Nol seed dibeli -> tidak ada yang ditanam -> tidak ada buah
        -- -> Leaves tetap 1 selamanya. Akun terkunci sejak menit pertama.
        if leaves() < s.harga then continue end
        local ok = pcall(function() Networking.SeedShop.PurchaseSeed:Fire(s.nama) end)
        if ok then
            dibeli = dibeli + 1
            status(string.format("[BELI] %s (%d Leaves, sisa %d)", s.nama, s.harga, leaves()))
        end
        task.wait(Config.JedaAksi)
    end

    -- Tool hasil pembelian tiba di Backpack secara ASINKRON. Tanpa menunggu,
    -- fase tanam menembak sebelum barangnya sampai dan seed yang baru dibeli
    -- terlewat satu siklus penuh.
    if dibeli > 0 then
        local sebelum = #(LocalPlayer:FindFirstChild("Backpack") or {}):GetChildren()
        local batas = tick() + 5
        while tick() < batas do
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if bp and #bp:GetChildren() >= sebelum + math.min(dibeli, 1) then break end
            task.wait(0.15)
        end
        task.wait(Config.JedaAksi)
    end
    return dibeli
end

-- ==========================================================
-- BAKE SALE — THE BAKER (beli bahan + auto masak)
-- ==========================================================
-- Semua bentuk data di bawah DIUKUR live 2026-08-26 di server sungguhan.
-- Tidak satu pun disalin dari World 1 — sistem ini memang tidak ada di sana.
--
--   Oven.Request:Fire() -> {
--       Open, CraftingEnabled, ClaimEnabled, Now (unix milik server),
--       Recipes = { { Muffin, Output = { Count },
--                     Ingredients = { { FruitName, Seed, Count, Owned,
--                                       Rarity, Mutation? } } } },
--       Ovens   = { { Ref, Recipe, StartedAt, FinishesAt,
--                     Duration = 600, Kind = "Plaza" } } }
--   Oven.StartBake:Fire(ref, namaMuffin) -> (ok, alasan)
--   Oven.Claim:Fire(ref)                 -> (ok, alasan, muffin, jumlah)
--   BakerReward.Request:Fire()           -> { Open, Trades = { {Muffin, Cost,
--                                              Held, Available, CanAfford} } }
--   BakerReward.Trade:Fire(namaMuffin)   -> (ok, alasan)
--   BakerSeedShop.PurchaseSeed:Fire(nama)   -- bentuknya persis SeedShop biasa
--
-- TIGA jebakan, semuanya terukur — jangan "dirapikan" tanpa mengukur ulang:
--
--   1. Nama instance oven MENIPU. Di workspace: Oven1 / Oven2 / **Oven4**,
--      sedangkan yang ditampilkan "Oven 1/2/3". Ref karena itu SELALU dibaca
--      dari Oven.Request, tidak pernah diturunkan dari nama instance.
--   2. `Owned` per bahan datang DARI SERVER. Jangan dihitung ulang dari
--      Backpack: bahan resep tidak semuanya Tool, dan itu persis kesalahan
--      yang dulu membuat penghitung buah di W1 melaporkan inventory kosong
--      padahal penuh.
--   3. `State` mentah di data oven tidak dipakai UI. OvenController menurunkan
--      keadaannya sendiri dari FinishesAt/Recipe, dan itu yang ditiru di sini.
--
-- Satu local untuk seluruh blok: scope file sudah memuat 175 local dan batas
-- Luau 200 berlaku juga di chunk utama.
local Baker = {}

function Baker.baca()
    local ok, st = pcall(function() return Networking.Oven.Request:Fire() end)
    if not ok or type(st) ~= "table" then return nil end
    return st
end

-- Diturunkan PERSIS seperti OvenController: FinishesAt <= 0 atau Recipe kosong
-- berarti oven menganggur; sisanya masih memanggang selama sisa waktu >= 1
-- detik, lalu siap diambil.
function Baker.keadaan(o, sekarang)
    local selesai = tonumber(o.FinishesAt) or 0
    if selesai <= 0 or o.Recipe == nil or o.Recipe == "" then return "Empty" end
    return (selesai - sekarang) >= 1 and "Baking" or "Ready"
end

-- Titik tengah ketiga oven, dihitung saat jalan — bukan koordinat mati.
-- Terukur: Oven1 (244,152,-136), Oven2 (253,152,-136), Oven4 (261,152,-136),
-- terbentang 17 stud, sedangkan jangkauan prompt cuma 12. Berdiri di tengah
-- menaruh ketiganya dalam jangkauan sekaligus, jadi SATU perjalanan cukup
-- untuk mengurus tiga oven. Itu penting: tiap perjalanan menarik karakter
-- keluar dari lahan.
function Baker.posisiOven()
    local bs = workspace:FindFirstChild("BakeSale")
    local cc = bs and bs:FindFirstChild("ColorCHangeOven", true)
    if not cc then return nil end
    local total, jml = Vector3.new(), 0
    for _, o in ipairs(cc:GetChildren()) do
        local hb = o:FindFirstChild("HitBox")
        if hb and hb:IsA("BasePart") then
            total, jml = total + hb.Position, jml + 1
        end
    end
    if jml == 0 then return nil end
    return total / jml
end

function Baker.posisiBaker()
    local bs = workspace:FindFirstChild("BakeSale")
    local npc = bs and bs:FindFirstChild("Baker", true)
    local root = npc and (npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
    return root and root.Position or nil
end

-- Resep yang DICENTANG di panel.
--
-- ResepMuffin itu ARRAY nama, bukan map {nama=true}: terapkanConfig menolak
-- tabel yang bukan array (`#v > 0`), jadi bentuk map akan diabaikan diam-diam
-- dan setelan panel tidak pernah sampai.
function Baker.resepDipilih(st)
    local mau = {}
    for _, nama in ipairs(Config.ResepMuffin or {}) do mau[tostring(nama)] = true end
    local hasil = {}
    for _, r in ipairs(st.Recipes or {}) do
        if mau[tostring(r.Muffin)] then hasil[#hasil + 1] = r end
    end
    return hasil
end

function Baker.bahanCukup(r)
    for _, b in ipairs(r.Ingredients or {}) do
        if (tonumber(b.Owned) or 0) < (tonumber(b.Count) or 0) then return false end
    end
    return true
end

-- Ringkasan bahan yang kurang, dikelompokkan per SEED.
--
-- Yang dipakai field `Seed`, bukan `FruitName`: shop menjual benihnya
-- ("Carrot") sedangkan buah hasilnya bernama lain ("Maple Carrot").
-- Diambil yang terbesar antar resep, bukan dijumlah — memasak dua resep
-- sekaligus tetap butuh satu kali stok terbanyak lebih dulu.
function Baker.bahanKurang(daftarResep)
    local kurang = {}
    for _, r in ipairs(daftarResep) do
        for _, b in ipairs(r.Ingredients or {}) do
            local butuh = (tonumber(b.Count) or 0) - (tonumber(b.Owned) or 0)
            if butuh > 0 and type(b.Seed) == "string" then
                kurang[b.Seed] = math.max(kurang[b.Seed] or 0, butuh)
            end
        end
    end
    return kurang
end

-- Beli benih bahan yang kurang, HANYA dari Baker shop.
--
-- Sengaja tidak menyentuh seed shop biasa. Shop itu sudah punya daftar
-- prioritas sendiri (SeedTarget), dan menyisipkan pembelian bahan ke sana
-- akan diam-diam menggeser prioritas yang dipilih pemilik akun.
--
-- Terukur: Baker shop cuma menjual sebagian bahan (Wheat, Sugar Cane,
-- Chicken). Bahan yang tidak ada kartunya DILAPORKAN, bukan ditebak
-- padanannya — nama kartu "Chicken" dan bahan "Small Brown Egg" memang mirip
-- perannya, tapi SeedData tidak memuat keduanya, jadi hubungan itu BELUM
-- terbukti dan tidak boleh dijadikan aturan diam-diam.
function Baker.beliBahan(daftarResep)
    local kurang = Baker.bahanKurang(daftarResep)
    if next(kurang) == nil then return 0 end

    local pos = Baker.posisiBaker()
    if not pos then
        status("[BAKER] The Baker tidak ketemu di workspace")
        return 0
    end

    -- Stok dibaca dulu dari jauh karena itu gratis. Kalau KOSONG, jangan
    -- langsung menyerah: belum terbukti apakah kartu shop terisi tanpa
    -- mendekati The Baker. Menyerah di sini akan jadi kunci mati -- tidak
    -- pernah mendekat, jadi tidak pernah terisi, jadi tidak pernah mendekat.
    -- Karena itu sekali dicoba dari dekat sebelum benar-benar menyerah.
    local stok = stokShop("BakerSeedShop")
    if #stok == 0 then
        if not pergiKe(pos) then
            status("[BAKER] Gagal mencapai The Baker — beli bahan dilewati")
            return 0
        end
        stok = stokShop("BakerSeedShop")
        if #stok == 0 then
            status("[BAKER] Shop kosong walau sudah di depan The Baker")
            return 0
        end
    end

    local adaKartu = {}
    for _, s in ipairs(stok) do adaKartu[s.nama] = true end
    local takDijual = {}
    for nama in pairs(kurang) do
        if not adaKartu[nama] then takDijual[#takDijual + 1] = nama end
    end
    if #takDijual > 0 then
        table.sort(takDijual)
        status("[BAKER] Tidak dijual Baker: " .. table.concat(takDijual, ", "))
    end

    if not pergiKe(pos) then
        status("[BAKER] Gagal mencapai The Baker — beli bahan dilewati")
        return 0
    end

    local dibeli = 0
    for _, s in ipairs(stok) do
        local butuh = kurang[s.nama]
        if butuh and butuh > 0 then
            if leaves() < s.harga then
                status(string.format("[BAKER] %s butuh %d Leaves, punya %d",
                    s.nama, s.harga, leaves()))
            else
                local ok = pcall(function()
                    Networking.BakerSeedShop.PurchaseSeed:Fire(s.nama)
                end)
                if ok then
                    dibeli = dibeli + 1
                    status(string.format("[BAKER] Beli %s (%d Leaves, kurang %d)",
                        s.nama, s.harga, butuh))
                end
                task.wait(Config.JedaAksi)
            end
        end
    end
    return dibeli
end

-- Tukar muffin ke hadiah. Di balik saklar sendiri dan default MATI: menukar
-- itu satu arah, dan muffin yang sudah ditukar tidak bisa dikembalikan kalau
-- ternyata pemain menyimpannya untuk hadiah lain.
--
-- `CanAfford` dihitung server — dipakai apa adanya, bukan dibandingkan sendiri
-- antara Held dan Cost.
function Baker.tukar()
    if not Config.AutoTukarMuffin then return 0 end

    local ok, st = pcall(function() return Networking.BakerReward.Request:Fire() end)
    if not ok or type(st) ~= "table" or st.Open ~= true then return 0 end

    local bisa = {}
    for _, t in ipairs(st.Trades or {}) do
        if t.Available == true and t.CanAfford == true and type(t.Muffin) == "string" then
            bisa[#bisa + 1] = t
        end
    end
    if #bisa == 0 then return 0 end

    local pos = Baker.posisiBaker()
    if not pos or not pergiKe(pos) then
        status("[BAKER] Gagal mencapai The Baker — tukar hadiah dilewati")
        return 0
    end

    local n = 0
    for _, t in ipairs(bisa) do
        local ok2, hasil, alasan = pcall(function()
            return Networking.BakerReward.Trade:Fire(t.Muffin)
        end)
        if ok2 and hasil then
            n = n + 1
            status(string.format("[BAKER] Tukar %s (biaya %s muffin)",
                t.Muffin, tostring(t.Cost)))
        else
            status(string.format("[BAKER] Tukar %s ditolak: %s",
                t.Muffin, tostring(alasan)))
        end
        task.wait(Config.JedaAksi)
    end
    return n
end

function Baker.siklus()
    local st = Baker.baca()
    if not st then
        status("[MASAK] Oven.Request diam — siklus dilewati")
        return
    end
    if st.Open ~= true then
        status("[MASAK] Bake Sale sedang tutup")
        return
    end

    -- Jam SERVER, bukan os.time() lokal. Selisih jam client bikin oven yang
    -- masih memanggang terbaca "Ready", lalu Claim ditolak tanpa sebab jelas.
    local sekarang = tonumber(st.Now) or os.time()
    local resep = Baker.resepDipilih(st)

    if #resep == 0 then
        status("[MASAK] Belum ada resep dicentang di panel")
        return
    end

    -- Beli bahan DULU: hasilnya baru terlihat di Request berikutnya, jadi ini
    -- harus mendahului keputusan berangkat ke oven.
    if Config.AutoBeliBahanBaker and Baker.beliBahan(resep) > 0 then
        st = Baker.baca() or st
        resep = Baker.resepDipilih(st)
    end

    local adaReady, adaKosong = false, false
    for _, o in ipairs(st.Ovens or {}) do
        local k = Baker.keadaan(o, sekarang)
        if k == "Ready" then adaReady = true elseif k == "Empty" then adaKosong = true end
    end

    local bisaMasak = false
    for _, r in ipairs(resep) do
        if Baker.bahanCukup(r) then bisaMasak = true break end
    end

    -- Tidak ada urusan di oven -> JANGAN berangkat. Perjalanannya menarik
    -- karakter keluar dari lahan, dan tanpa syarat ini ia bolak-balik tiap
    -- siklus hanya untuk melihat oven yang masih memanggang 10 menit.
    local perlu = (adaReady and st.ClaimEnabled ~= false)
               or (adaKosong and bisaMasak and st.CraftingEnabled ~= false)
    if not perlu then
        if adaKosong and not bisaMasak then
            local kurang = Baker.bahanKurang(resep)
            local rinci = {}
            for nama, n in pairs(kurang) do rinci[#rinci + 1] = nama .. " x" .. n end
            table.sort(rinci)
            status("[MASAK] Bahan kurang: " .. (#rinci > 0 and table.concat(rinci, ", ") or "-"))
        end
        return
    end

    local pos = Baker.posisiOven()
    if not pos then
        status("[MASAK] Oven tidak ketemu di workspace")
        return
    end
    -- Toleransi 8: jangkauan prompt 12, dan oven terjauh 8-9 stud dari titik
    -- tengah. Menyisakan margin supaya dorongan kecil tidak melempar keluar.
    if not pergiKe(pos, 8) then
        status("[MASAK] Gagal mencapai oven — dicoba lagi siklus berikutnya")
        return
    end

    -- 1. Ambil yang sudah matang lebih dulu: oven yang dikosongkan di sini
    --    langsung bisa dipakai memanggang di langkah 2.
    if st.ClaimEnabled ~= false then
        for _, o in ipairs(st.Ovens or {}) do
            if Baker.keadaan(o, sekarang) == "Ready" then
                local ref = tostring(o.Ref)
                local ok, hasil, alasan, muffin, jml = pcall(function()
                    return Networking.Oven.Claim:Fire(ref)
                end)
                if ok and hasil then
                    status(string.format("[MASAK] Klaim oven %s: %s x%s",
                        ref, tostring(muffin or o.Recipe), tostring(jml or 1)))
                else
                    status(string.format("[MASAK] Klaim oven %s ditolak: %s",
                        ref, tostring(alasan)))
                end
                task.wait(Config.JedaAksi)
            end
        end
        st = Baker.baca() or st
        sekarang = tonumber(st.Now) or sekarang
        resep = Baker.resepDipilih(st)
    end

    -- 2. Isi oven yang menganggur.
    if st.CraftingEnabled ~= false then
        for _, o in ipairs(st.Ovens or {}) do
            if Baker.keadaan(o, sekarang) == "Empty" then
                -- Resep dipilih ulang tiap oven: memanggang menghabiskan bahan,
                -- jadi `Owned` dari pembacaan sebelumnya sudah basi. Tanpa ini,
                -- oven kedua menembak resep yang bahannya baru saja terpakai
                -- dan ditolak server tanpa gejala selain "gagal".
                local pilih
                for _, r in ipairs(resep) do
                    if Baker.bahanCukup(r) then pilih = r break end
                end
                if not pilih then break end

                local ref = tostring(o.Ref)
                local ok, hasil, alasan = pcall(function()
                    return Networking.Oven.StartBake:Fire(ref, pilih.Muffin)
                end)
                if ok and hasil then
                    status(string.format("[MASAK] Oven %s mulai: %s (%d dtk)",
                        ref, pilih.Muffin, tonumber(o.Duration) or 600))
                else
                    status(string.format("[MASAK] Oven %s ditolak: %s",
                        ref, tostring(alasan)))
                end
                task.wait(Config.JedaAksi)

                st = Baker.baca() or st
                sekarang = tonumber(st.Now) or sekarang
                resep = Baker.resepDipilih(st)
            end
        end
    end

    -- 3. Tukar hadiah (saklar sendiri, default mati).
    Baker.tukar()
end

local function startAutoMasak()
    task.spawn(function()
        while true do
            if Config.AutoMasak then
                local ok, err = pcall(Baker.siklus)
                if not ok then status("[MASAK] error: " .. tostring(err)) end
            end
            task.wait(tonumber(Config.JedaMasak) or 20)
        end
    end)
end

-- Cabut sampai muat: hanya tanaman yang rarity-nya LEBIH RENDAH dari seed yang
-- mau ditanam, diurut dari yang paling rendah. Kalau tidak ada yang lebih
-- rendah, penanaman itu dilewati -- bukan dipaksa.
local function cabutSampaiMuat(rarityMasuk, butuh)
    if not Config.AutoCabut then return 0 end
    local shovel = toolBernama("Shovel")
    if not shovel then
        status("[LEWAT] Tidak ada Shovel di backpack")
        return 0
    end

    -- Hanya tanaman yang selisih rarity-nya memenuhi ambang. Membandingkan
    -- "lebih rendah" saja tidak cukup: itu membenarkan penukaran satu tingkat
    -- yang membuang tanaman matang demi kenaikan tipis.
    local ambang = Config.AmbangSelisihCabut or 1
    local kandidat = {}
    local adaLebihRendah = false
    for _, p in ipairs(daftarTanaman()) do
        if p.rarity > 0 and p.rarity < rarityMasuk then
            adaLebihRendah = true
            if (rarityMasuk - p.rarity) >= ambang then
                kandidat[#kandidat + 1] = p
            end
        end
    end

    if #kandidat == 0 then
        -- Dibedakan supaya jelas: tidak ada yang lebih rendah sama sekali itu
        -- keadaan berbeda dengan ada yang lebih rendah tapi selisihnya tipis.
        if adaLebihRendah then
            status(string.format("[LEWAT] Ada tanaman lebih rendah, tapi selisihnya < %d tingkat", ambang))
        end
        return 0
    end
    table.sort(kandidat, function(a, b) return a.rarity < b.rarity end)

    if not equip(shovel) then return 0 end
    local dicabut = 0
    for i = 1, math.min(butuh, #kandidat) do
        local p = kandidat[i]
        -- Satu-satunya aksi yang masih mendekat: cabut belum pernah diuji, jadi
        -- diperlakukan seolah butuh jarak dekat sampai terbukti sebaliknya.
        if Config.DekatSaatCabut and p.pos then pergiKe(p.pos) end

        -- plantId dari nama model dan nama shovel dari atribut -- sama seperti
        -- ShovelController. Sebelumnya string "Shovel" ditulis mentah; kebetulan
        -- nilainya sama, tapi mengandalkan kebetulan itu patah diam-diam kalau
        -- game menggantinya.
        local plantId = (p.model and p.model.Name) or (p.userId .. "_" .. p.guid)
        local namaShovel = shovel:GetAttribute("Shovel") or "Shovel"

        pcall(function()
            Networking.Shovel.UseShovel:Fire(plantId, "", namaShovel, shovel)
        end)
        -- Jeda minimum game adalah 0,65 detik (ShovelController). JedaAksi bisa
        -- jauh lebih kecil, dan tembakan yang terlalu rapat dibuang server.
        task.wait(math.max(Config.JedaAksi or 0, 0.8))

        -- Keberhasilan diukur dari hilangnya model, bukan dari pcall -- server
        -- menolak diam-diam dan pcall tetap mengembalikan true.
        if p.model and p.model.Parent == nil then
            dicabut = dicabut + 1
            _G.FHTotalCabut = (_G.FHTotalCabut or 0) + 1
            status(string.format("[CABUT] %s (rarity %d, masuk r%d)", p.nama, p.rarity, rarityMasuk))
        else
            status("[CABUT] Ditolak server — dihentikan")
            break
        end
    end
    return dicabut
end

-- ==========================================================
-- AREA SPRINKLER & TITIK SIRAM
-- ==========================================================
-- Dideklarasikan di sini, bukan di blok SHOP/GEAR jauh di bawah: titik siram
-- dihitung di fungsi-fungsi berikut, yang letaknya SEBELUM blok itu. Kalau
-- deklarasinya tertinggal di bawah, pemanggilan di sini mengenai global nil dan
-- seluruh pemilihan titik siram gagal saat dijalankan -- padahal luac tetap lolos.
local CollectionService = game:GetService("CollectionService")

-- Angka radius dibaca dari modul data game, BUKAN ditebak:
--   SprinklerData   : Syrup Sprinkler Radius=20, Super Syrup Sprinkler Radius=55
--   WateringcanData : Syrup Watering Can SplashRadius=5, Super = 8
local okSD, SprinklerData = pcall(function()
    return require(ReplicatedStorage.SharedModules.SprinklerData)
end)
local okWD, WateringcanData = pcall(function()
    return require(ReplicatedStorage.SharedModules.WateringcanData)
end)

local function radiusSprinkler(nama)
    if okSD and type(SprinklerData) == "table" then
        for _, d in pairs(SprinklerData) do
            if type(d) == "table" and d.SprinklerName == nama and d.Radius then
                return d.Radius
            end
        end
    end
    return 20  -- nilai Syrup Sprinkler, dipakai kalau modulnya berubah
end

local function radiusSiram(nama)
    if okWD and type(WateringcanData) == "table" then
        for _, d in pairs(WateringcanData) do
            if type(d) == "table" and d.Name == nama and d.SplashRadius then
                return d.SplashRadius
            end
        end
    end
    return 5  -- nilai Syrup Watering Can
end

-- Sprinkler yang BENAR-BENAR sudah berdiri di kebun kita, bukan yang di tas.
local function sprinklerTerpasang()
    local p = plotSaya()
    local f = p and p:FindFirstChild("Sprinklers")
    if not f then return {} end

    local hasil = {}
    for _, s in ipairs(f:GetChildren()) do
        local pos
        if s:IsA("BasePart") then
            pos = s.Position
        else
            local bagian = s.PrimaryPart or s:FindFirstChildWhichIsA("BasePart")
            pos = bagian and bagian.Position
        end
        if pos then
            local nama = s:GetAttribute("SprinklerName") or s.Name
            hasil[#hasil + 1] = { pos = pos, radius = radiusSprinkler(nama), nama = nama }
        end
    end
    return hasil
end

-- Batas area tanam yang sedang berlaku. nil = bebas.
-- Diisi tanamDalamAreaSprinkler() sebelum menanam, lalu dikosongkan lagi --
-- kalau tertinggal terisi, penanaman berikutnya ikut terkurung di radius
-- sprinkler yang sudah tidak berlaku.
local areaSprinklerAktif = nil

local function dalamAreaSprinkler(x, z)
    if not areaSprinklerAktif or #areaSprinklerAktif == 0 then return true end
    local titik = Vector2.new(x, z)
    for _, s in ipairs(areaSprinklerAktif) do
        if (titik - Vector2.new(s.pos.X, s.pos.Z)).Magnitude <= s.radius then
            return true
        end
    end
    return false
end

-- Titik siram terbaik: TIDAK ada tanaman tepat di situ, tapi jangkauan
-- siramannya menutupi tanaman sebanyak mungkin.
--
-- Syarat "tidak ada tanaman di titik itu" bukan pilihan gaya. IsValidPlacement
-- di WateringcanController menolak kalau raycast tidak mengenai part bertag
-- PlantArea -- dan kalau ada tanaman berdiri di titik itu, sinarnya mengenai
-- tanaman, bukan tanah. Siramannya gagal tanpa pesan.
local function titikSiramTerbaik(radius)
    local p = plotSaya()
    if not p then return nil end

    local kolom = {}
    for _, part in ipairs(CollectionService:GetTagged("PlantArea")) do
        if part:IsA("BasePart") and part:IsDescendantOf(p) then kolom[#kolom + 1] = part end
    end
    if #kolom == 0 then return nil end

    local tanaman = {}
    for _, t in ipairs(daftarTanaman()) do
        if t.pos then tanaman[#tanaman + 1] = Vector2.new(t.pos.X, t.pos.Z) end
    end
    if #tanaman == 0 then
        -- Belum ada tanaman: siram di tengah saja, tidak ada yang perlu dihitung.
        local k = kolom[1]
        return k.Position + Vector3.new(0, k.Size.Y / 2, 0)
    end

    -- Kisi 2 stud. Cukup rapat untuk radius 5, dan tetap murah: satu kolom
    -- 44x16 menghasilkan sekitar 180 titik, bukan ribuan.
    local LANGKAH = 2
    local terbaik, skorTerbaik = nil, -1

    for _, k in ipairs(kolom) do
        local x0 = k.Position.X - k.Size.X * 0.45
        local x1 = k.Position.X + k.Size.X * 0.45
        local z0 = k.Position.Z - k.Size.Z * 0.45
        local z1 = k.Position.Z + k.Size.Z * 0.45

        local x = x0
        while x <= x1 do
            local z = z0
            while z <= z1 do
                local titik = Vector2.new(x, z)

                -- Tolak titik yang ditempati tanaman. 1.5 stud memberi kelonggaran
                -- untuk lebar model tanaman itu sendiri.
                local kosong = true
                local tertutup = 0
                for _, q in ipairs(tanaman) do
                    local jarak = (titik - q).Magnitude
                    if jarak < 1.5 then kosong = false break end
                    if jarak <= radius then tertutup = tertutup + 1 end
                end

                if kosong and tertutup > skorTerbaik then
                    skorTerbaik = tertutup
                    terbaik = Vector3.new(x, k.Position.Y + k.Size.Y / 2, z)
                end
                z = z + LANGKAH
            end
            x = x + LANGKAH
        end
    end

    return terbaik, skorTerbaik
end

-- Memastikan kita benar-benar DI DALAM kebun sendiri.
--
-- Yang diperiksa atribut IsInOwnGarden, BUKAN jarak -- karena itulah yang
-- dipakai server untuk menerima penanaman. Terukur langsung di kebun sungguhan:
-- atributnya menyala pada 7,3 stud dari PlotSizeReference dan mati di 9,6 stud.
--
-- Memakai jarak sebagai pengganti itu rapuh: tombol Garden mendaratkan pemain di
-- SpawnPoint yang berjarak 24 stud dari pusat plot, jadi ambang berapa pun yang
-- dipilih hanya menebak-nebak di mana batas sebenarnya.
local function masukKebunSendiri(acuan)
    if LocalPlayer:GetAttribute("IsInOwnGarden") == true then return true end

    -- Percuma terbang selama layar muat masih aktif: server mengembalikan posisi
    -- karakter, jadi ketiga percobaan di bawah pasti habis sia-sia.
    tungguSiap()

    for _ = 1, 3 do
        pergiKe(acuan.Position, 6)
        -- Atribut direplikasi dari server, jadi ada jeda setelah kita berhenti.
        -- Menyerah seketika akan membatalkan penanaman yang sebenarnya sudah
        -- berhasil sampai.
        local batas = tick() + 2
        while tick() < batas do
            if LocalPlayer:GetAttribute("IsInOwnGarden") == true then return true end
            task.wait(0.15)
        end
    end
    return LocalPlayer:GetAttribute("IsInOwnGarden") == true
end

-- Kolom lahan tanam, DI-CACHE.
--
-- Dulu dicari dengan plot:GetDescendants() di dalam titikKosong(), dan
-- titikKosong() dipanggil sekali per PERCOBAAN tanam. Terukur di kebun
-- sungguhan: satu plot berisi 12.264 instance, sedangkan yang dicari cuma 2 part
-- "PlantArea" yang tidak pernah berpindah maupun bertambah.
--
-- Dengan (Count+3) percobaan per tumpukan seed dan beberapa tumpukan per siklus,
-- satu fase tanam menelusuri RATUSAN RIBU instance tanpa menghasilkan apa pun
-- yang baru. Di PC itu sekadar lambat. Di perangkat cloud yang menahan 8-10
-- client, fase tanam jadi diam berlarut-larut sesudah "[TANAM] Di kebun" --
-- persis gejala "stuck" yang dilaporkan, dan bukan hang: ia memang sedang
-- menggilas CPU.
--
-- Cache dibatalkan sendiri lewat pemeriksaan .Parent, jadi kebun yang dimuat
-- ulang tidak akan memakai acuan basi.
local kolomCache, kolomPlot = nil, nil

local function kolomTanam(plot)
    if kolomCache and kolomPlot == plot
       and #kolomCache > 0 and kolomCache[1].Parent then
        return kolomCache
    end

    local k = {}
    for _, d in ipairs(plot:GetDescendants()) do
        if d:IsA("BasePart") and string.find(d.Name, "PlantArea", 1, true) then
            k[#k + 1] = d
        end
    end
    kolomCache, kolomPlot = k, plot
    return k
end

local function tanamSemua()
    -- Lompatan anti-AFK ditahan selama fase ini: Freefall melepas tool
    -- yang dipegang dan seluruh penanaman gagal tanpa jejak.
    _G.FHJanganLompat = true
    local plot = plotSaya()
    local acuan = plot and plot:FindFirstChild("PlotSizeReference")
    if not acuan then
        status("[LEWAT] PlotSizeReference tidak ketemu")
        return 0
    end

    local ditanam = 0
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end

    -- Daftar seed dibaca ULANG tiap putaran, bukan sekali di awal.
    --
    -- Fase tanam harus TUNTAS sebelum pindah tugas: habiskan seluruh seed di
    -- Backpack, atau berhenti karena kebun benar-benar penuh. Versi sebelumnya
    -- memotret sekali lalu keluar setelah satu lintasan, jadi seed yang baru
    -- masuk (atau yang tertunda karena satu tembakan meleset) baru tersentuh
    -- pada siklus berikutnya -- itulah yang terasa tidak stabil.
    -- Seed yang sudah terbukti tidak bisa ditanam di keadaan kebun sekarang.
    -- Hidup selama satu fase tanam saja, supaya keadaan kebun yang berubah
    -- (setelah panen atau cabut) tidak ikut terkunci.
    local seedMustahil = {}
    -- Seed yang ditahan karena rarity-nya di atas ambang. Dicatat per NAMA supaya
    -- satu jenis tidak terhitung berkali-kali saat antrean disusun ulang tiap putaran.
    local seedDitimbun = {}
    local ditimbun = 0

    local function antreanSeed()
        -- Kebun penuh -> seed yang rarity-nya tidak melebihi tanaman TERLEMAH
        -- tidak akan pernah bisa masuk: tidak ada tanah kosong, dan tidak ada
        -- tanaman yang cukup rendah untuk digantikan.
        --
        -- Disaring di sini, bukan dibiarkan gagal di dalam: tanpa ini setiap
        -- siklus mengulang percobaan yang sama dan mencetak "[PENUH] Tidak ada
        -- tanaman yang lebih rendah dari Maple Carrot" berulang-ulang -- terbaca
        -- seperti kerusakan padahal itu memang keadaan yang benar.
        local batas = kebunPenuh and rarityTerendahKebun() or 0

        -- Bangun set lookup untuk IgnoreSeeds supaya pencarian O(1) per seed.
        local ignoreSet = {}
        for _, nm in ipairs(Config.IgnoreSeeds or {}) do ignoreSet[nm] = true end

        local a = {}
        for _, t in ipairs(bp:GetChildren()) do
            local nama = t:IsA("Tool") and t:GetAttribute("SeedTool")
            if nama and not seedMustahil[nama] then
                local boleh = true

                -- JANGAN TANAM: seed yang ada di daftar IgnoreSeeds panel.
                -- Seed tetap dibeli — filter ini hanya di jalur tanam.
                if boleh and ignoreSet[nama] then
                    boleh = false
                end

                if batas > 0 and nilaiRarity(nama) <= batas then
                    boleh = false
                    seedMustahil[nama] = true
                end

                -- BATAS ATAS: seed di ATAS AmbangSpeedrun sengaja TIDAK ditanam.
                --
                -- Bukan karena tidak berguna -- justru sebaliknya, seed tinggi
                -- ditimbun untuk nanti. Nilai jual buah = dasar x berat^pangkat, dan
                -- beratnya sangat ditentukan sprinkler: Syrup Sprinkler memberi
                -- SizeLuckBonus 7, Super Syrup Sprinkler memberi 100. Menanam Mythic
                -- sekarang dengan sprinkler biasa mengunci potensinya di angka kecil,
                -- dan tanaman itu tidak bisa ditanam ulang.
                --
                -- Seed-nya TETAP DIBELI (penyaring ini hanya di jalur tanam), lalu
                -- menunggu di tas sampai sprinkler layak.
                if boleh and nilaiRarity(nama) > AMBANG_SPEEDRUN then
                    boleh = false
                    if not seedDitimbun[nama] then
                        seedDitimbun[nama] = true
                        ditimbun = ditimbun + 1
                    end
                end
                if boleh then a[#a + 1] = t end
            end
        end
        return a
    end

    -- Titik kosong: acak di SELURUH lebar plot, lalu ditolak kalau terlalu dekat
    -- dengan tanaman yang sudah ada. Titik acak murni gampang berkerumun -- itu
    -- sebabnya tanaman menumpuk di satu sudut padahal plotnya 115 studs.
    --
    -- Mengembalikan nil kalau setelah CobaTitik percobaan tidak ada ruang tersisa.
    -- nil itulah SATU-SATUNYA tanda "kebun penuh" yang dipakai script -- bukan
    -- sekadar satu penanaman yang gagal.
    local function titikKosong()
        local uk = acuan.Size
        local semua = daftarTanaman()

        -- BATAS JUMLAH TANAMAN.
        --
        -- Dipasang di sini, bukan di pemanggilnya, karena "tidak ada titik
        -- kosong" adalah persis pemicu jalur cabut-upgrade yang sudah ada:
        -- kebunPenuh diset, lalu cabutSampaiMuat() mencabut SATU tanaman
        -- terlemah -- dan itu hanya terjadi kalau seed yang masuk rarity-nya
        -- lebih tinggi. Jadi begitu batas tercapai, kebun berhenti bertambah dan
        -- otomatis beralih ke menaikkan mutu isinya, tanpa satu baris pun logika
        -- penggantian perlu diubah.
        --
        -- 0 berarti tanpa batas -- lahan fisiklah yang jadi penentu, seperti
        -- perilaku sebelum fitur ini ada.
        local batasTanam = tonumber(Config.BatasTanam) or 0
        if batasTanam > 0 and #semua >= batasTanam then
            return nil
        end

        local adaSekarang = {}
        for _, p in ipairs(semua) do
            if p.pos then adaSekarang[#adaSekarang + 1] = p.pos end
        end

        -- Titik diambil dari PlantAreaColumn, BUKAN dari PlotSizeReference.
        --
        -- Ini penyebab utama "tanam sering tidak bekerja". PlotSizeReference
        -- terukur X 76.8..191.8 / Z -20.2..-2.2, tapi lahan yang benar-benar bisa
        -- ditanami adalah DUA STRIP terpisah:
        --     PlantAreaColumn1  X 130.3..174.3  Z   3.1..19.1
        --     PlantAreaColumn2  X  90.0..134.0  Z -37.2..-21.2
        -- Rentang acuan itu justru menutupi CELAH di antara keduanya, jadi
        -- sebagian besar titik acak mendarat di tanah yang bukan lahan tanam dan
        -- ditolak server tanpa pesan apa pun.
        local kolom = kolomTanam(plot)
        if #kolom == 0 then
            -- Tidak ada kolom tanam: jatuh ke acuan lama daripada berhenti total.
            kolom = { acuan }
        end

        -- Include, bukan Exclude. Dengan Exclude, sinar mengenai apa pun yang
        -- kebetulan menutupi lahan lebih dulu -- terukur mendarat di
        -- "GardenTotalArea", "Part", dan "Move", dan penanaman di titik-titik itu
        -- ditolak. Membatasi ke kolom tanam membuat setiap hit dijamin di
        -- permukaan yang memang boleh ditanami.
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = kolom

        -- Tinggi asal sinar. Semua kolom tanam sejajar (terukur Y=143.38), jadi
        -- satu nilai cukup dan pengundi tidak perlu tahu kolom mana yang dipakai.
        local yAsal = kolom[1].Position.Y + 20

        -- Titik diundi LANGSUNG di dalam lingkaran sprinkler saat batas aktif,
        -- bukan diundi merata lalu disaring.
        --
        -- Bedanya besar: satu sprinkler radius 20 hanya menutupi 48% lahan
        -- (terukur), jadi cara lama membuang lebih dari separuh percobaan pada
        -- titik yang pasti ditolak. Karena kebun dinyatakan PENUH setelah
        -- CobaTitik percobaan gagal, pemborosan itu bukan cuma lambat -- ia
        -- membuat kebun yang masih longgar dikira penuh, lalu memicu pencabutan
        -- yang sebenarnya tidak perlu.
        local function undiTitik()
            if areaSprinklerAktif and #areaSprinklerAktif > 0 then
                local sp = areaSprinklerAktif[math.random(1, #areaSprinklerAktif)]
                local sudut = math.random() * math.pi * 2
                -- Akar kuadrat supaya sebarannya merata di seluruh cakram.
                -- Tanpa itu titik menumpuk di pusat dan tepi lingkaran nyaris
                -- tidak pernah terpakai.
                local jari = math.sqrt(math.random()) * sp.radius
                return sp.pos.X + math.cos(sudut) * jari,
                       sp.pos.Z + math.sin(sudut) * jari
            end
            local k = kolom[math.random(1, #kolom)]
            -- 0.85 memberi margin dari tepi kolom; titik tepat di bibir lahan
            -- gampang meleset saat di-raycast.
            return k.Position.X + (math.random() - 0.5) * k.Size.X * 0.85,
                   k.Position.Z + (math.random() - 0.5) * k.Size.Z * 0.85
        end

        for _ = 1, Config.CobaTitik do
            local x, z = undiTitik()

            -- Tetap diperiksa: saat batas tidak aktif ini selalu lolos, dan saat
            -- aktif ia menjaring titik yang meleset karena pembulatan.
            local cukupJauh = dalamAreaSprinkler(x, z)
            if cukupJauh then
                for _, q in ipairs(adaSekarang) do
                    -- Jarak diukur mendatar saja; tinggi tanaman tidak relevan.
                    if (Vector2.new(x, z) - Vector2.new(q.X, q.Z)).Magnitude < Config.JarakTanam then
                        cukupJauh = false
                        break
                    end
                end
            end

            if cukupJauh then
                -- Y dari raycast, bukan dari bidang acuan: permukaan lahan ada di
                -- Y=143.6 sementara acuan di 146.5, dan tangkapan panggilan asli
                -- game memang memakai 143.2.
                local hit = workspace:Raycast(
                    Vector3.new(x, yAsal, z), Vector3.new(0, -60, 0), params)
                if hit then return hit.Position end
            end
        end

        -- Lemparan acak dengan jarak penuh gagal. Sebelum menyimpulkan kebun
        -- PENUH -- dan memicu cabut -- coba sekali lagi dengan jarak lebih rapat.
        --
        -- Ini bedanya "tidak ketemu titik longgar" dan "benar-benar tidak ada
        -- ruang". Tanpa pass kedua, kebun setengah terisi bisa dikira penuh lalu
        -- tanaman dicabut padahal masih muat.
        local rapat = math.max(2, Config.JarakTanam * 0.5)
        for _ = 1, Config.CobaTitik do
            local x, z = undiTitik()

            local cukupJauh = dalamAreaSprinkler(x, z)
            if cukupJauh then
                for _, q in ipairs(adaSekarang) do
                    if (Vector2.new(x, z) - Vector2.new(q.X, q.Z)).Magnitude < rapat then
                        cukupJauh = false
                        break
                    end
                end
            end
            if cukupJauh then
                local hit = workspace:Raycast(
                    Vector3.new(x, yAsal, z), Vector3.new(0, -60, 0), params)
                if hit then return hit.Position end
            end
        end

        return nil
    end

    -- Putaran luar: ulangi sampai tidak ada seed tersisa atau tidak ada lagi yang
    -- bisa ditanam. Batas 30 putaran hanya jaring pengaman -- normalnya berhenti
    -- jauh sebelum itu karena Backpack habis.
    -- Sekali di awal fase: pindah ke kebun sendiri. Tanpa ini seluruh fase tanam
    -- ditolak server, dan yang terlihat cuma "seed berpindah cepat tanpa menanam".
    if Config.DekatSaatTanam then
        if not masukKebunSendiri(acuan) then
            status("[LEWAT] Gagal mencapai kebun sendiri, tanam dibatalkan")
            _G.FHJanganLompat = false
            return 0
        end
        status(string.format("[TANAM] Di kebun (IsInOwnGarden=%s)",
            tostring(LocalPlayer:GetAttribute("IsInOwnGarden"))))
    end

    -- Waktu status terakhir dicetak fase ini. Dipakai detak di dalam lintasan
    -- tanam supaya jeda diam tidak pernah melewati 10 detik.
    local detakTerakhir = tick()

    local putaran = 0
    while putaran < 30 do
        putaran = putaran + 1
        local antrean = antreanSeed()
        if #antrean == 0 then break end

        local majuDiPutaranIni = 0

    for _, t in ipairs(antrean) do
        local seedName = t.Parent and t:GetAttribute("SeedTool")
        if seedName then
            -- Satu Tool adalah SETUMPUK seed, bukan satu biji -- atribut Count
            -- terukur 4, 11, dan 13 di backpack. Versi sebelumnya menanam sekali
            -- per Tool lalu pindah, jadi dari 13 Maple Bamboo hanya satu yang
            -- masuk tanah. Sekarang dikuras sampai habis.
            local awal = tonumber(t:GetAttribute("Count")) or 1
            -- Jaring pengaman: kalau Count tidak pernah turun (kebun penuh, atau
            -- atributnya tidak dipakai untuk seed tertentu), loop tetap berhenti.
            local batas = awal + 3
            local percobaan, ditanamSeedIni = 0, 0

            if equip(t) then
                while t.Parent and percobaan < batas do
                    percobaan = percobaan + 1
                    local sebelum = tonumber(t:GetAttribute("Count")) or 0

                    local titik = titikKosong()
                    if not titik then
                        -- BARU di sinilah kebun benar-benar penuh: bukan karena satu
                        -- penanaman gagal, tapi karena tidak ada satu pun titik yang
                        -- cukup jauh dari tanaman lain setelah puluhan percobaan.
                        --
                        -- Cabut hanya boleh dari titik ini, dan hanya SATU tanaman
                        -- per penanaman -- bertahap, bukan membabat seluruh kebun
                        -- begitu muncul satu seed rarity tinggi.
                        kebunPenuh = true
                        if cabutSampaiMuat(nilaiRarity(seedName), 1) <= 0 then
                            -- Menyebut KEDUA rarity-nya. Versi lama hanya menyebut
                            -- seed-nya ("tidak ada yang lebih rendah dari Maple
                            -- Carrot") sehingga terbaca seperti salah hitung --
                            -- Carrot itu Common, mustahil ada yang lebih rendah.
                            -- Yang hilang justru keadaan kebunnya.
                            -- Sebab penuhnya disebutkan. Tanpa ini, "[PENUH]"
                            -- pada kebun yang jelas masih lapang terbaca seperti
                            -- salah deteksi, padahal batas jumlah dari panel yang
                            -- sedang berlaku.
                            local bt = tonumber(Config.BatasTanam) or 0
                            local sebab = (bt > 0 and #daftarTanaman() >= bt)
                                and string.format("batas %d tanaman tercapai", bt)
                                or "lahan habis"
                            status(string.format(
                                "[PENUH] %s — %s (r%d) tidak bisa menggantikan apa pun, tanaman terlemah r%d",
                                sebab, seedName, nilaiRarity(seedName), rarityTerendahKebun()))
                            seedMustahil[seedName] = true
                            break
                        end
                        equip(t)
                        titik = titikKosong()
                        if not titik then break end
                    end

                    -- Terbang ke plot dilakukan SEKALI di awal fase, bukan ke tiap
                    -- titik tanam. Di sini hanya dicek apakah kita terlempar keluar
                    -- kebun -- server memang menarik pemain kembali ke spawn, dan
                    -- terukur kejadian: jarak melonjak 9 -> 183 studs di sela aksi.
                    if Config.DekatSaatTanam and LocalPlayer:GetAttribute("IsInOwnGarden") ~= true then
                        pergiKe(acuan.Position, 8)
                        equip(t)
                    end

                    pcall(function()
                        Networking.Plant.PlantSeed:Fire(titik, seedName, t)
                    end)
                    task.wait(Config.JedaTanam)

                    if not t.Parent then
                        -- Tool habis dan dihapus: seluruh tumpukan tertanam.
                        ditanamSeedIni = ditanamSeedIni + 1
                        break
                    end

                    local sesudah = tonumber(t:GetAttribute("Count")) or 0
                    if sesudah < sebelum then
                        ditanamSeedIni = ditanamSeedIni + (sebelum - sesudah)
                        kebunPenuh = false
                    end

                    -- Detak, supaya fase ini tidak pernah diam tanpa kabar.
                    --
                    -- Jalur "menanam tapi Count tidak turun" TIDAK mencetak apa
                    -- pun: status hanya muncul saat ada yang benar-benar tertanam,
                    -- saat kebun penuh, atau saat fase selesai. Akibatnya fase
                    -- yang sedang bekerja keras terlihat sama persis dengan fase
                    -- yang menggantung -- dan itulah yang dilaporkan sebagai
                    -- "stuck di [TANAM] Di kebun".
                    if tick() - detakTerakhir >= 10 then
                        detakTerakhir = tick()
                        status(string.format(
                            "[TANAM] %s — percobaan %d/%d, tertanam %d",
                            seedName, percobaan, batas, ditanamSeedIni))
                    end
                    -- Count tidak turun TIDAK langsung berarti penuh: titik berikutnya
                    -- akan berbeda, dan itu sering sudah cukup. Percobaan berikutnya
                    -- yang menentukan -- inilah yang dulu membuat cabut terlalu cepat
                    -- dipicu hanya karena satu tembakan meleset.
                end

                if ditanamSeedIni > 0 then
                    ditanam = ditanam + ditanamSeedIni
                    majuDiPutaranIni = majuDiPutaranIni + ditanamSeedIni
                    status(string.format("[TANAM] %s x%d (dari %d)", seedName, ditanamSeedIni, awal))
                end

                -- Jeda sebelum pindah ke jenis seed berikutnya. Pergantian seed
                -- berarti equip tool baru, dan tanpa jeda tembakan pertama dikirim
                -- sebelum equip-nya benar-benar selesai.
                task.wait(Config.JedaGantiSeed)
            end
        end
    end

        -- Tidak ada satu pun yang tertanam di seluruh putaran ini: entah kebun
        -- penuh, entah seed yang tersisa tidak bisa ditanam. Berhenti daripada
        -- mengulang lintasan yang sama tanpa hasil.
        if majuDiPutaranIni == 0 then break end
    end

    _G.FHJanganLompat = false
    if ditanam > 0 then
        -- Penghitung SESI, dipakai baris "Planted" di panel status.
        --
        -- Ditambahkan di sini, bukan di dalam lintasan penanaman: `ditanam` di
        -- sini sudah angka yang benar-benar tertanam -- dihitung dari turunnya
        -- atribut Count pada tool, bukan dari berapa kali remote ditembak.
        -- Menghitung tembakan akan melaporkan penanaman yang ditolak server
        -- sebagai berhasil.
        _G.FHTotalTanam = (_G.FHTotalTanam or 0) + ditanam
        status(string.format("[TANAM] Selesai — %d biji, %d putaran", ditanam, putaran))
    end
    -- Dilaporkan supaya seed mahal yang menumpuk di tas terlihat DISENGAJA.
    -- Tanpa baris ini gejalanya sama persis dengan penanaman yang rusak.
    if ditimbun > 0 then
        status(string.format("[TIMBUN] %d jenis seed di atas %s disimpan, tidak ditanam",
            ditimbun, tostring(Config.AmbangSpeedrun)))
    end
    return ditanam
end

-- Berat buah dalam KILOGRAM, dibaca lewat fungsi milik game sendiri.
--
-- FruitVisualizerController:CalculateFruitWeight menghitungnya dari UserId,
-- PlantId, FruitId, dan CorePartName -- bukan sekadar satu atribut, jadi tidak
-- bisa ditiru dengan membaca properti begitu saja.
--
-- Satuannya KILOGRAM meski game memformatnya lewat "WeightFormat.FormatGrams".
-- Namanya menyesatkan: fungsi itu hanya menempelkan "kg" tanpa mengonversi apa
-- pun -- FormatGrams(10) menghasilkan "10.00kg". Terukur langsung: stroberi
-- biasa mengembalikan ~1.41, dan di inventory tertulis [1.41kg].
local okFVC, FruitVisualizer = pcall(function()
    return require(LocalPlayer.PlayerScripts.Controllers.FruitVisualizerController)
end)

local function beratBuahKg(inst)
    if not (okFVC and FruitVisualizer and FruitVisualizer.CalculateFruitWeight) then return nil end
    local ok, kg = pcall(function() return FruitVisualizer:CalculateFruitWeight(inst) end)
    return ok and tonumber(kg) or nil
end

-- Catatan kapan sebuah buah mulai ditahan, supaya penantiannya bisa dibatasi.
-- Kuncinya FruitId, bukan instance: instance bisa dibuat ulang saat kebun
-- dimuat ulang, dan itu akan mereset penantian tanpa alasan.
local mulaiDitahan = {}

-- Naik dari prompt ke instance buah yang sesungguhnya.
--
-- Prompt TIDAK menempel langsung pada buah. FruitVisualizerController membuat
-- "HarvestPart" -- sebuah Part kosong tanpa atribut apa pun -- lalu menaruh
-- prompt di dalamnya, jadi prompt.Parent adalah Part itu dan atribut buah ada
-- satu tingkat di atasnya. Dicari berdasarkan keberadaan FruitId, bukan dengan
-- menghitung ".Parent.Parent", supaya tetap benar kalau susunannya berubah.
--
-- Mengembalikan nil untuk panen TANAMAN UTUH (bambu, wortel, dsb) -- prompt-nya
-- menempel pada model tanaman yang hanya punya PlantId. Itu DISENGAJA, bukan
-- kelalaian: dari 919 tanaman yang diperiksa langsung di server, tidak satu pun
-- model tanaman membawa atribut Mutation -- mutasi hanya menempel pada buah.
-- Jadi menahan tanaman utuh berarti menunggu sesuatu yang tidak akan pernah
-- datang, dan bambu (419 dari 919 tanaman itu) akan mandek sampai batas waktu.
-- nil di sini membuatnya dipanen seperti biasa.
local function buahDariPrompt(prompt)
    local n = prompt.Parent
    for _ = 1, 4 do
        if not n then return nil end
        if n:GetAttribute("FruitId") then return n end
        n = n.Parent
    end
    return nil
end

-- Mengembalikan true kalau buah ini harus DILEWATI.
local function tahanBuahIni(promptInduk)
    local minKg = Config.TahanBeratMin or 0
    if minKg <= 0 then return false end

    -- Buah yang sudah bermutasi justru yang kita tunggu -- panen.
    local mutasi = promptInduk:GetAttribute("Mutation")
    if mutasi and mutasi ~= "" then return false end

    local kg = beratBuahKg(promptInduk)
    if not kg or kg < minKg then return false end

    local id = tostring(promptInduk:GetAttribute("FruitId") or promptInduk:GetFullName())
    local sejak = mulaiDitahan[id]
    if not sejak then
        mulaiDitahan[id] = os.time()
        return true
    end

    -- Sudah kelamaan menunggu: panen saja daripada petaknya mati terus.
    local maksDetik = (Config.TahanMaksJam or 0) * 3600
    if maksDetik > 0 and (os.time() - sejak) >= maksDetik then
        mulaiDitahan[id] = nil
        return false
    end
    return true
end

local function panenSemua()
    -- Dulu menyapu seluruh workspace:GetDescendants() tiap siklus -- mahal, dan
    -- daftarnya sudah basi begitu buah pertama dipanen. Sekarang cukup folder
    -- Plants milik plot sendiri, dan hasilnya DIPOTRET dulu sebelum ditembak
    -- supaya penghapusan instance tidak merusak penelusuran yang sedang jalan.
    local plot = plotSaya()
    local folder = plot and plot:FindFirstChild("Plants")
    if not folder then return 0 end

    local antrean = {}
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.ActionText == "Harvest" then
            antrean[#antrean + 1] = d
        end
    end

    local dipanen, ditahan = 0, 0
    for _, d in ipairs(antrean) do
        if d.Parent then
            local m = d:FindFirstAncestorWhichIsA("Model")
            if m then
                local userId, guid, indeks = uraiNamaTanaman(m.Name)
                if guid and tostring(userId) == tostring(LocalPlayer.UserId) then
                    -- Terbukti di lapangan: CollectFruit diterima dari jarak jauh,
                    -- jadi tidak ada lompat-lompat antar tanaman. Mendekat hanya
                    -- kalau kamu memaksanya lewat config.
                    if Config.DekatSaatPanen then
                        local induk = d.Parent
                        local pos = induk and induk:IsA("BasePart") and induk.Position
                        if pos then pergiKe(pos) end
                    end
                    -- Berhenti memanen begitu inventory penuh. Sebelumnya panen
                    -- terus ditembak ke kapasitas yang sudah mentok -- server
                    -- menolak diam-diam dan dari luar terlihat seperti macet
                    -- meng-spam harvest.
                    if jumlahBuah() >= kapasitasBuah() then
                        status(string.format("[PENUH] %d/%d buah — panen dihentikan",
                            jumlahBuah(), kapasitasBuah()))
                        break
                    end

                    -- Buah berat yang belum bermutasi ditahan supaya mutasi
                    -- sempat menempel; lihat catatan di TahanBeratMin.
                    local buah = buahDariPrompt(d)
                    if buah and tahanBuahIni(buah) then
                        ditahan = ditahan + 1
                        continue
                    end
                    local ok = pcall(function()
                        Networking.Garden.CollectFruit:Fire(guid, indeks or "")
                    end)
                    if ok then dipanen = dipanen + 1 end
                    task.wait(Config.JedaPanen)
                end
            end
        end
    end
    if dipanen > 0 then status("[PANEN] " .. dipanen .. " buah") end
    -- Dilaporkan supaya kebun yang "tidak dipanen-panen" tidak terlihat seperti
    -- macet. Tanpa baris ini gejalanya persis sama dengan panen yang rusak.
    if ditahan > 0 then
        -- %s untuk ambangnya, bukan %d: config boleh berisi pecahan dan
        -- string.format("%d", 10.5) itu error di Luau, bukan pembulatan.
        status(string.format("[TAHAN] %d buah >=%skg menunggu mutasi",
            ditahan, tostring(Config.TahanBeratMin)))
    end
    return dipanen
end

local function jual()
    -- Terbukti di lapangan: SellAll diterima dari jarak jauh, jadi tidak perlu
    -- terbang ke Steven sama sekali. Pencarian NPC hanya dilakukan kalau kamu
    -- memaksa mendekat lewat config.
    if Config.DekatSaatJual then
        local npcs = workspace:FindFirstChild("NPCS")
        local steven = npcs and npcs:FindFirstChild("Steven")
        local root = steven and (steven:FindFirstChild("HumanoidRootPart") or steven.PrimaryPart)
        if root and not pergiKe(root.Position) then
            status("[LEWAT] Gagal mencapai Steven")
            return false
        end
    end

    -- Staging wajib. Tanpa PreviewSellAll lebih dulu, SellAll ditolak diam-diam.
    pcall(function() Networking.NPCS.PreviewSellAll:Fire() end)
    task.wait(Config.JedaAksi)
    pcall(function() Networking.NPCS.SellAll:Fire() end)
    status("[JUAL] SellAll dikirim (Leaves: " .. leaves() .. ")")
    task.wait(1)
    return true
end

local cdsStarted = false
local function startAutoCDS()
    if cdsStarted then return end
    cdsStarted = true

    print("[CDS] Auto CDS (Claim Mail, Daily Deal, Sell) siap.")

    -- Loop Claim Mail (5s)
    task.spawn(function()
        while true do
            if Config.AutoJual then
                local remote = Networking.Mailbox and Networking.Mailbox.ClaimAll
                if remote then pcall(function() remote:Fire() end) end
            end
            task.wait(5)
        end
    end)

    -- Loop Daily Deal (2 mnt)
    task.spawn(function()
        while true do
            if Config.AutoJual then
                local remote = Networking.NPCS and Networking.NPCS.UseDailyDealAll
                if remote then
                    pcall(function() Networking.NPCS.PreviewSellAll:Fire() end)
                    task.wait(0.5)
                    pcall(function() remote:Fire() end)
                end
            end
            task.wait(120)
        end
    end)

    -- Loop Sell (5 mnt)
    task.spawn(function()
        while true do
            if Config.AutoJual then
                pcall(function() Networking.NPCS.PreviewSellAll:Fire() end)
                task.wait(0.5)
                pcall(function() Networking.NPCS.SellAll:Fire() end)
                status("[CDS] SellAll (5 menit) dikirim")
            end
            task.wait(300)
        end
    end)
end

-- ==========================================================
-- SYNC KE PANEL
-- ==========================================================
-- Tanpa ini akun World 2 tidak muncul di Kaitun Manager dan tidak bisa menerima
-- perintah apa pun -- termasuk tombol kembali ke GaG2.
--
-- Selain status dan saldo, dikirim juga penanda dunia. Panel memakainya untuk
-- menampilkan map di samping nama dan mengunci edit config, karena World 2
-- berjalan sepenuhnya otomatis.
local httprequest = (syn and syn.request) or (http and http.request)
    or http_request or (fluxus and fluxus.request) or request

-- Satu dunia bisa punya BEBERAPA place, dan tidak semua bisa dituju langsung.
-- Universe ini rootPlaceId-nya 97598239454123 (GaG2); kedua place Fall Harvest
-- adalah non-root sehingga hanya bisa dimasuki lewat teleport dari dalam
-- universe -- dan belum tentu keduanya menerima. Karena itu didaftar sebagai
-- kandidat, lalu dicoba berurutan.
local PLACE_DUNIA = {
    TP_GAG2 = { 97598239454123 },
    TP_FALL = { 129343810645058, 126987765280963 },
}
local NAMA_DUNIA = {
    [97598239454123]   = "Grow a Garden 2",
    [129343810645058]  = "Fall Harvest",
    [126987765280963]  = "Fall Harvest",
}

-- ==========================================================
-- TELEPORT TAHAN BANTING
-- ==========================================================
-- Dua masalah nyata, dan keduanya paling sering muncul di executor HP:
--
-- 1. SCRIPT MATI SETELAH TELEPORT. Executor menyuntik script ke place yang
--    sedang berjalan. Begitu pindah place atau server, tidak ada apa pun yang
--    menjalankannya lagi -- akun sampai di tujuan lalu diam selamanya. Itulah
--    yang terasa seperti "tidak bisa pindah sesuka hati": teleportnya jalan,
--    kaitunnya yang tidak ikut. queue_on_teleport menitipkan kode agar
--    dijalankan otomatis begitu tiba.
--
-- 2. KEGAGALAN TELEPORT TIDAK TERLIHAT. Teleport gagal secara ASINKRON lewat
--    event TeleportInitFailed, bukan lewat error. Jadi pcall di sekitar
--    :Teleport() tidak pernah menangkap apa pun, dan gagal terlihat persis sama
--    dengan berhasil.
local TeleportService = game:GetService("TeleportService")

-- URL loader yang sama dengan yang dipakai buyer. Sengaja loader, bukan script
-- ini langsung: routernya yang memilih script sesuai place tujuan, jadi satu
-- kode titipan ini benar untuk pindah ke dunia mana pun.
-- PASTIKAN URL INI SAMA dengan loader Luaegis yang sedang dipakai buyer.
-- Kalau Luaegis memberi UUID baru saat loader di-unggah ulang, baris ini ikut
-- diganti -- di W1 DAN W2.
--
-- Dulu menunjuk raw.githubusercontent akun lama. Itu bug migrasi yang paling
-- sulit dikenali: script jalan normal sampai teleport PERTAMA, lalu memuat
-- rantai lama menuju server mati dan berhenti tanpa sebab yang terlihat.
-- WAJIB subdomain "loader." -- terukur 2026-08-29:
--   https://luaegis.net/...        -> HTTP 301, isi 86 byte berupa TEKS URL
--   https://loader.luaegis.net/... -> HTTP 200, 9.055 byte Lua sungguhan
-- game:HttpGet tidak selalu mengikuti redirect. Tanpa subdomain ini, kode yang
-- dititipkan queue_on_teleport menerima 86 byte teks, loadstring gagal, dan bot
-- mendarat sesudah rejoin dalam keadaan MATI tanpa satu pun pesan.
local URL_LOADER = "https://loader.luaegis.net/scripts/v4/loaders/9ea5c8fe-2cd5-42d3-a929-5b626f3890c0.lua"

-- BELUM SELESAI: begitu sync config dicabut, titipan di bawah harus membawa
-- SELURUH Config, bukan cuma PanelKey. Sekarang ia cuma menitipkan key karena
-- sisanya diisi ulang oleh sync sesudah mendarat. Tanpa sync, bot yang baru
-- teleport akan berjalan tanpa satu pun setelan.

local function kodeLanjutan()
    -- Kedua nama config diisi karena tujuannya bisa GaG2 maupun Fall Harvest,
    -- dan masing-masing script membaca nama yang berbeda.
    return string.format(
        "getgenv().MuzeAutoBuyConfig = { PanelKey = %q }\n" ..
        "getgenv().MuzeFallHarvestConfig = { PanelKey = %q }\n" ..
        "loadstring(game:HttpGet(%q))()",
        raw_panel_key, raw_panel_key, URL_LOADER)
end

-- Nama fungsi antrian berbeda-beda antar executor, dan sebagian executor HP
-- tidak menyediakannya sama sekali. Yang tidak punya harus memakai autoexec.
local function titipKode()
    local f = (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or queue_on_teleport
        or queueonteleport
        or (getgenv and getgenv().queue_on_teleport)
    if type(f) ~= "function" then return false end
    return (pcall(f, kodeLanjutan()))
end

local alasanGagalTP = nil
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(pemain, hasil, pesan)
        if pemain ~= LocalPlayer then return end
        alasanGagalTP = tostring(hasil) .. " " .. tostring(pesan or "")
    end)
end)

local function teleportAman(lakukan, keterangan, percobaanMaks)
    for percobaan = 1, (percobaanMaks or 4) do
        alasanGagalTP = nil
        local adaAntrian = titipKode()
        if not adaAntrian and percobaan == 1 then
            status("[TP] Executor tanpa queue_on_teleport - andalkan autoexec")
        end

        local ok, err = pcall(lakukan)
        if not ok then
            alasanGagalTP = tostring(err)
        else
            -- Kalau teleport benar-benar jalan, client membongkar place ini dan
            -- baris di bawah tidak pernah selesai. Sampai di sini berarti belum
            -- tentu gagal -- beri waktu TeleportInitFailed tiba dulu.
            local batas = tick() + 12
            while tick() < batas and not alasanGagalTP do task.wait(0.25) end
            if not alasanGagalTP then return true end
        end

        -- "Flooded" artinya Roblox sendiri yang membatasi laju teleport. Itu
        -- keputusan server dan TIDAK bisa dilewati dari sisi client; satu-
        -- satunya yang masuk akal adalah menunggu lebih lama.
        local jeda = 5 * percobaan
        if string.find(string.lower(alasanGagalTP or ""), "flood") then
            jeda = 20 * percobaan
        end
        status("[TP GAGAL] " .. keterangan .. " -> " .. tostring(alasanGagalTP))
        task.wait(jeda)
    end
    status("[TP MENYERAH] " .. keterangan)
    return false
end

-- ==========================================================
-- PINDAH DUNIA LEWAT JALUR RESMI GAME
-- ==========================================================
-- Remote yang sama dengan yang ditembak NPC Ethan saat pemain memilih dunia:
--   EventWorldsTeleporterController -> Networking.Worlds.RequestTravel:Fire(id)
--
-- Lebih baik daripada TeleportService:Teleport(placeId) karena SERVER yang
-- memilih place tujuan. Daftar dunia punya PlaceType dan BotPlaceType terpisah
-- ("BotUser", "FallHarvestBotUser"), jadi akun yang ditandai bot diarahkan ke
-- place berbeda. Menembak PlaceId sendiri mengabaikan routing itu.
local DUNIA_ID = {
    TP_GAG2 = "Main",
    TP_FALL = "FallHarvest",
}

local function duniaSekarang()
    local ok, id = pcall(function()
        return require(ReplicatedStorage.SharedModules.Worlds).CurrentId
    end)
    return ok and id or nil
end

local function pindahDunia(worldId, kandidatPlace)
    -- Dititipkan sebelum apa pun ditembak: server bisa memindahkan kita kapan
    -- saja setelah remote ini diterima, dan begitu pindah script berhenti.
    titipKode()

    local ok = pcall(function()
        Networking.Worlds.RequestTravel:Fire(worldId)
    end)

    if ok then
        status("[PINDAH] RequestTravel -> " .. tostring(worldId))
        -- Kalau server menerima, place ini dibongkar dan loop di bawah tidak
        -- akan pernah selesai. Selesai = permintaannya diabaikan diam-diam.
        local batas = tick() + 15
        while tick() < batas do task.wait(0.5) end
    end

    status("[PINDAH] Jalur resmi diam, coba TeleportService")
    for _, pid in ipairs(kandidatPlace or {}) do
        if teleportAman(function()
            TeleportService:Teleport(pid, LocalPlayer)
        end, "dunia " .. tostring(pid), 2) then
            return true
        end
    end
    return false
end

-- ==========================================================
-- MENCARI SERVER SEPI
-- ==========================================================
-- Daftar server diambil dari API publik Roblox. Diuji dari dalam executor:
-- request() dan game:HttpGet() sama-sama menembus (status 200, 100 server).
local function ambilHttp(url)
    -- Nama fungsinya beda-beda antar executor; dicoba berurutan.
    local pengirim = request or http_request
        or (http and http.request)
        or (syn and syn.request)
    if pengirim then
        local ok, res = pcall(pengirim, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and tonumber(res.StatusCode) == 200 then
            return res.Body
        end
        -- Status selain 200 dikembalikan apa adanya supaya 429 bisa dibedakan
        -- dari gagal jaringan -- lihat catatan rate limit di cariServerSepi.
        if ok and type(res) == "table" then return nil, tonumber(res.StatusCode) end
        return nil
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    return ok and body or nil
end

local hopTerakhir = 0
-- Sampai kapan pencarian ditahan setelah API gagal / membatasi.
local backoffApi = 0

local function cariServerSepi()
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        game.PlaceId)
    -- Namanya "kode", BUKAN "status": nama itu akan menutupi fungsi status()
    -- di seluruh fungsi ini, dan pemanggilannya di bawah langsung error.
    local body, kode = ambilHttp(url)
    if not body then
        -- 429 itu keadaan yang WAJAR di sini, bukan kerusakan: satu perangkat
        -- menjalankan 8-10 client dan semuanya menembak API yang sama dari satu
        -- IP. Dilaporkan sekali lalu dilewati; siklus berikutnya mencoba lagi.
        if kode == 429 then
            status("[SERVER] API sedang membatasi (429) — dicoba lagi nanti")
        end
        return nil
    end

    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)
    if not ok or type(data) ~= "table" or type(data.data) ~= "table" then return nil end

    -- Kumpulkan yang paling sepi, lalu PILIH ACAK di antaranya.
    --
    -- Mengambil yang paling sepi begitu saja itu jebakan saat banyak akun:
    -- kedelapan client membaca daftar yang sama, memilih JobId yang sama, dan
    -- serentak menyerbu satu server -- yang seketika jadi server paling ramai.
    local terendah = math.huge
    for _, srv in ipairs(data.data) do
        local isi = tonumber(srv.playing) or 99
        local maks = tonumber(srv.maxPlayers) or 8
        if srv.id ~= game.JobId and isi < maks and isi < terendah then
            terendah = isi
        end
    end
    if terendah == math.huge then return nil end

    local pilihan = {}
    for _, srv in ipairs(data.data) do
        local isi = tonumber(srv.playing) or 99
        local maks = tonumber(srv.maxPlayers) or 8
        if srv.id ~= game.JobId and isi < maks and isi == terendah then
            pilihan[#pilihan + 1] = srv.id
        end
    end
    if #pilihan == 0 then return nil end
    return pilihan[math.random(1, #pilihan)], terendah, #pilihan
end

local function pindahServerSepi()
    if not Config.AutoCariServerSepi then return false end

    local isiSekarang = #Players:GetPlayers()
    if isiSekarang <= Config.BatasIsiServer then return false end

    local jeda = (Config.JedaHopMenit or 0) * 60
    if hopTerakhir > 0 and (tick() - hopTerakhir) < jeda then return false end
    if tick() < backoffApi then return false end

    local jid, isi, jumlah = cariServerSepi()
    if not jid then
        -- Backoff setelah gagal, dan ini WAJIB.
        --
        -- Terukur: tiga panggilan beruntun sudah kena 429. Satu perangkat
        -- menjalankan 8-10 client dari satu IP, dan sebelum perpindahan pertama
        -- hopTerakhir masih 0 -- artinya tanpa penahan ini setiap client
        -- menembak API tiap siklus, selamanya, dan saling membuat 429.
        backoffApi = tick() + 120
        return false
    end
    -- Tidak ada gunanya pindah ke server yang sama ramainya.
    if isi >= isiSekarang then
        status(string.format("[SERVER] Tidak ada yang lebih sepi dari %d — tetap di sini", isiSekarang))
        hopTerakhir = tick()
        return false
    end

    status(string.format("[SERVER] %d orang di sini — pindah ke server berisi %d (%d pilihan)",
        isiSekarang, isi, jumlah))
    hopTerakhir = tick()

    -- titipKode() WAJIB duluan: tanpa itu akun mendarat di server baru tanpa
    -- kaitun yang ikut, terlihat online dan sehat padahal diam total.
    titipKode()
    return teleportAman(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jid, LocalPlayer)
    end, "server sepi " .. string.sub(jid, 1, 8))
end

local function tanganiQuickAction(act)
    -- "JOIN|<placeId>|<jobId>" -- masuk ke server tertentu. Universe ini melarang
    -- private server, tapi server cuma muat 8 orang; mengumpulkan akun sendiri ke
    -- satu JobId memberi efek yang sama.
    if type(act) == "string" and string.sub(act, 1, 5) == "JOIN|" then
        local pid, jid = string.match(act, "^JOIN|(%d+)|(.+)$")
        pid = tonumber(pid)
        if pid and jid and jid ~= "" then
            if game.JobId == jid then
                status("[LEWAT] Sudah di server tujuan")
                return
            end
            status("[KUMPUL] Menuju server " .. string.sub(jid, 1, 8))
            local berhasil = teleportAman(function()
                TeleportService:TeleportToPlaceInstance(pid, jid, LocalPlayer)
            end, "server " .. string.sub(jid, 1, 8))

            -- Server cuma muat 8 orang. Kalau JobId tujuan sudah penuh, semua
            -- percobaan akan gagal dengan sebab yang sama dan mengulanginya
            -- percuma. Lebih baik tetap mendarat di dunia yang benar daripada
            -- tertinggal di server lama.
            if not berhasil then
                status("[KUMPUL] Server tujuan tidak bisa dimasuki, masuk acak")
                teleportAman(function()
                    TeleportService:Teleport(pid, LocalPlayer)
                end, "place " .. tostring(pid))
            end
        end
        return
    end

    -- Aksi cepat dari daftar akun panel. Sebelumnya HANYA dikenali kaitun World 1,
    -- jadi menekan Claim Mail / Daily Deal / SellAll untuk akun yang sedang di
    -- Fall Harvest tidak melakukan apa-apa dan tidak memberi tahu apa pun --
    -- perintahnya terhapus, panel tampak berhasil, dunia tidak berubah.
    --
    -- Nama remote-nya disalin dari World 1. NPCS.SellAll/PreviewSellAll sudah
    -- terbukti ada di sini (dipakai fungsi jual), tapi Mailbox dan
    -- UseDailyDealAll belum pernah dipastikan ada di Fall Harvest. Karena itu
    -- ketiadaannya DILAPORKAN berikut daftar nama yang benar-benar tersedia --
    -- satu kali jalan sudah cukup untuk tahu nama yang benar, tanpa menebak lagi.
    local function namaTersedia(tbl)
        if type(tbl) ~= "table" then return "(namespace tidak ada)" end
        local n = {}
        for k in pairs(tbl) do n[#n + 1] = tostring(k) end
        table.sort(n)
        return table.concat(n, ", ")
    end

    if act == "S" then
        jual()
        return
    end

    if act == "DD" then
        local remote = Networking.NPCS and Networking.NPCS.UseDailyDealAll
        if not remote then
            status("[DEAL] UseDailyDealAll tidak ada di Fall Harvest. Isi NPCS: "
                .. namaTersedia(Networking.NPCS))
            return
        end
        -- Staging sama seperti jual biasa: tanpa PreviewSellAll lebih dulu,
        -- server menolak diam-diam.
        pcall(function() Networking.NPCS.PreviewSellAll:Fire() end)
        task.wait(0.5)
        pcall(function() remote:Fire() end)
        status("[DEAL] UseDailyDealAll dikirim (Leaves: " .. leaves() .. ")")
        return
    end

    if act == "C" then
        local remote = Networking.Mailbox and Networking.Mailbox.ClaimAll
        if not remote then
            status("[MAIL] Mailbox.ClaimAll tidak ada di Fall Harvest. Isi Networking: "
                .. namaTersedia(Networking))
            return
        end
        pcall(function() remote:Fire() end)
        status("[MAIL] ClaimAll dikirim")
        return
    end

    local kandidat = PLACE_DUNIA[act]
    if kandidat then
        -- Dibandingkan lewat Worlds.CurrentId, bukan PlaceId. Satu dunia punya
        -- banyak place (shard + varian bot), jadi PlaceId tidak bisa dipakai
        -- untuk memastikan kita sudah berada di dunia yang dimaksud.
        local tujuanId = DUNIA_ID[act]
        if tujuanId and duniaSekarang() == tujuanId then
            status("[LEWAT] Sudah di dunia tujuan")
            return
        end
        pindahDunia(tujuanId, kandidat)
    end
end

-- ==========================================================
-- REMOTE MAIL VIA WEB PANEL -- World 2
-- ==========================================================
-- Diport dari kaitun_main. Sebelumnya World 2 sama sekali tidak punya jalur ini:
-- panel menulis perintah SendMailMulti ke Firebase, tidak ada yang membacanya,
-- dan perintah itu menggantung selamanya. Dari sisi panel terlihat "terkirim".
--
-- Batas server dipastikan dari script Fall Harvest sendiri, bukan diasumsikan
-- sama dengan GaG2: Cmdr "qamailpaircap" di sini menyebut angka yang identik --
-- cooldown 10 detik dan 5 mail per penerima per hari. Signature SendBatch juga
-- sama persis: (userId, batch, catatan) -> (sukses, pesan).
local JEDA_MAIL_W2 = 11
local MAKS_ULANG_BATCH_W2 = 5
local mailTerakhirW2, mailSibukW2 = 0, false

-- Item yang server tolak SENDIRIAN, diingat lalu dilewati di kiriman berikutnya.
--
-- Pemecahan batch memang menyelamatkan item yang sah, tapi ongkosnya nyata:
-- satu batch beracun berubah jadi ~9 kali kirim, dan yang berhasil di antaranya
-- ikut memakan jatah 5 mail/hari/penerima. Tanpa ingatan ini, ongkos itu dibayar
-- ulang persis sama setiap kali item yang sama ikut terkirim.
--
-- Sengaja hanya seumur SESI, bukan disimpan ke panel: kalau suatu penolakan
-- ternyata sementara dan salah digolongkan permanen, rejoin sudah cukup untuk
-- memulihkannya. Setiap yang dilewati tetap dilaporkan ke riwayat, jadi tidak
-- ada item yang hilang diam-diam.
local mailItemDitolak = {}
local function kunciSlot(slot)
    return tostring(slot.Category) .. "|" .. tostring(slot.ItemKey)
end

local function tungguCooldownMailW2()
    local batas = os.clock() + 180
    while mailSibukW2 and os.clock() < batas do task.wait(0.5) end
    mailSibukW2 = true
    while true do
        local sisa = JEDA_MAIL_W2 - (os.clock() - mailTerakhirW2)
        if sisa <= 0 then break end
        task.wait(math.min(sisa, 1))
    end
end

local function catatRiwayatMail(teks, target, jml)
    if not httprequest then return end
    pcall(function()
        httprequest({
            Url = SERVER_URL .. "/api/mail/log",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode({
                panel_key = raw_panel_key,
                log = string.format("[%s] %s > %s > %s",
                    os.date("%H:%M:%S"), LocalPlayer.Name, teks, tostring(target)),
                timestamp = os.time(),
                target = target,
                batches = jml or 0,
            }),
        })
    end)
end

-- Panel menampilkan seed World 2 dengan akhiran " (Seed)" -- itu ditambahkan
-- tulisMonitor supaya bibit tidak tertukar dengan buah bernama sama. Nama itulah
-- yang dikirim balik saat mengirim mail, sementara inventory menyimpannya TANPA
-- akhiran ("Maple Bamboo"). Tanpa membuang akhiran itu, tidak satu pun seed
-- pernah cocok dan pengiriman selalu menghasilkan nol item.
local function normalNama(s)
    s = string.lower(tostring(s))
    s = string.gsub(s, "%s*%(seed%)%s*$", "")
    s = string.gsub(s, "%s*%[[%d%.]+kg%]", "")
    return (string.gsub(s, "[ %-]", ""))
end

local function kirimMailRemote(targetUsername, itemsDiminta)
    local okAll, err = pcall(function()
        local ok, targetId = pcall(function()
            return Networking.Mailbox.LookupPlayer:Fire(targetUsername)
        end)
        if not ok or not targetId or targetId <= 0 then
            local alasan = string.format("GAGAL (target '%s' tidak ada di sistem Mail)", tostring(targetUsername))
            status("[MAIL] " .. alasan)
            catatRiwayatMail(alasan, targetUsername, 0)
            return
        end

        local PSC = require(ReplicatedStorage.ClientModules.PlayerStateClient)
        local replica = PSC:GetLocalReplica()
        if not (replica and replica.Data and replica.Data.Inventory) then
            status("[MAIL] Inventory belum termuat")
            return
        end

        local function jumlahDiminta(namaItem)
            local bersih = normalNama(namaItem)
            for k, v in pairs(itemsDiminta) do
                if normalNama(k) == bersih then return v end
            end
            return nil
        end

        -- namaSlot: slot batch -> nama terbaca. Ringkasan dihitung dari slot yang
        -- BENAR-BENAR terkirim, bukan dari yang disusun. Sebelumnya terkirimNama
        -- diisi saat batch dibentuk, jadi riwayat menyebut "213 Frog" walau batch
        -- itu ditolak mentah-mentah -- laporan yang terdengar berhasil padahal nol.
        local apiBatch, terkirimNama, namaSlot = {}, {}, {}
        local dilewati = {}
        for cat, catData in pairs(replica.Data.Inventory) do
            if type(catData) == "table" then
                for itemKey, itemData in pairs(catData) do
                    local jumlah, kunci, nama = 0, itemKey, itemKey
                    if typeof(itemData) == "number" then
                        jumlah = itemData
                    elseif typeof(itemData) == "table" then
                        jumlah = itemData.Amount or itemData.Count or itemData.Value or 1
                        kunci = itemData.Id or itemData.ItemKey or itemKey
                        nama = itemData.Name or itemData.DisplayName or itemKey
                        -- Pet yang sedang dipakai tidak boleh ikut terkirim.
                        if cat == "Pets" and itemData.Equipped then jumlah = 0 end
                    end

                    if jumlah > 0 then
                        local diminta = jumlahDiminta(nama)
                        if diminta ~= nil then
                            local kirim = tonumber(diminta) or 0
                            if kirim == 0 or kirim > jumlah then kirim = jumlah end
                            if kirim > 0 then
                                local slot = { Category = cat, ItemKey = kunci, Count = kirim }
                                if mailItemDitolak[kunciSlot(slot)] then
                                    dilewati[#dilewati + 1] = nama
                                else
                                    apiBatch[#apiBatch + 1] = slot
                                    namaSlot[slot] = nama
                                end
                            end
                        end
                    end
                end
            end
        end

        if #apiBatch == 0 then
            local n = 0
            for _ in pairs(itemsDiminta) do n = n + 1 end
            -- Dibedakan dari "tidak ada di inventory". Kalau semuanya ternyata ada
            -- tapi habis di daftar-lewat, menyebutnya "tidak ada" akan mengirim
            -- orang mencari ke arah yang salah.
            local alasan
            if #dilewati > 0 then
                alasan = string.format("GAGAL (%d item ada, tapi semuanya pernah ditolak server sesi ini: %s)",
                    #dilewati, table.concat(dilewati, ", "))
            else
                alasan = string.format("GAGAL (0 dari %d jenis item ada di inventory)", n)
            end
            status("[MAIL] " .. alasan)
            catatRiwayatMail(alasan, targetUsername, 0)
            return
        end

        -- Potong 20 per batch, lalu kirim dengan cooldown + pengulangan. Batch
        -- yang ditolak DIULANG, bukan dibuang -- itu perbaikan yang sama seperti
        -- di kaitun utama, di mana batch gagal dulu hilang tanpa jejak.
        local daftarBatch, kini = {}, {}
        for i, item in ipairs(apiBatch) do
            kini[#kini + 1] = item
            if #kini == 20 or i == #apiBatch then
                daftarBatch[#daftarBatch + 1] = kini
                kini = {}
            end
        end
        if #daftarBatch > 5 then
            status(string.format("[MAIL] %d batch, tapi batas server 5 mail/hari/penerima — sisanya akan ditolak",
                #daftarBatch))
        end

        -- Batch yang ditolak DIPECAH, bukan diulang utuh.
        --
        -- Server membalas satu pesan untuk seluruh batch ("Invalid items") tanpa
        -- menyebut item mana yang bermasalah, dan penolakannya menjatuhkan ke-20
        -- slot sekaligus -- termasuk 19 yang sah. Mengulang isi yang sama 5x tidak
        -- pernah menolong: kalau isinya yang ditolak, ia ditolak lagi persis sama.
        -- Yang terjadi hanya 55 detik terbuang lalu seluruh batch hilang.
        --
        -- Dengan membelah dua dan mencoba lagi, item yang sah tetap sampai dan
        -- yang ditolak menyempit sampai tersisa SATU -- nama item itu lalu ikut
        -- dilaporkan ke riwayat. Aturan mana yang dilanggar server BELUM diketahui
        -- (belum pernah diukur); laporan inilah yang akan memberitahunya.
        --
        -- Pemecahan hanya untuk penolakan PERMANEN. Penolakan sementara dikenali
        -- dari server yang menyebut sisa detik ("...in 7 seconds") -- itu cooldown,
        -- isinya tidak salah, jadi tetap diulang utuh seperti dulu.
        local batchOk, batchGagal, alasanGagal, itemTerkirim, batasHarian = 0, 0, nil, 0, false
        local itemDitolak = {}

        -- Antrian, bukan ipairs(daftarBatch): pecahan disisipkan saat berjalan.
        -- Batasnya ada supaya batch yang seluruhnya ditolak tidak berubah jadi
        -- 20 pengiriman satuan yang masing-masing menunggu cooldown 11 detik.
        local antrian = {}
        for _, b in ipairs(daftarBatch) do antrian[#antrian + 1] = b end
        local MAKS_KIRIM = 24
        local dikirim, ke = 0, 1

        while ke <= #antrian do
            local batch = antrian[ke]
            ke = ke + 1
            if batasHarian then
                batchGagal = batchGagal + 1
            elseif dikirim >= MAKS_KIRIM then
                batchGagal = batchGagal + 1
                alasanGagal = alasanGagal or "batas percobaan kirim tercapai"
            else
                local terkirim, permanen = false, false
                for _ = 1, MAKS_ULANG_BATCH_W2 do
                    tungguCooldownMailW2()
                    status(string.format("[MAIL] Kirim %d item ke %s (%d/%d di antrian)",
                        #batch, tostring(targetUsername), ke - 1, #antrian))
                    local ok2, hasil, pesan = pcall(function()
                        return Networking.Mailbox.SendBatch:Fire(
                            targetId, batch, "Delivery via Panel by MOZE FRAME(feng jiu)")
                    end)
                    mailTerakhirW2 = os.clock()
                    mailSibukW2 = false
                    dikirim = dikirim + 1

                    if ok2 and hasil then terkirim = true break end

                    local kabar
                    if not ok2 then kabar = "error client: " .. tostring(hasil)
                    elseif type(pesan) == "string" and pesan ~= "" then kabar = pesan
                    else kabar = "ditolak server tanpa alasan" end
                    alasanGagal = kabar

                    local kecil = string.lower(kabar)
                    for _, kata in ipairs({ "limit", "cap", "daily", "today", "full", "maximum" }) do
                        if string.find(kecil, kata, 1, true) then batasHarian = true break end
                    end
                    if batasHarian then break end

                    local detik = tonumber(string.match(kecil, "(%d+)%s*second"))
                    if detik and detik > 0 then
                        task.wait(math.min(detik + 1, 30))
                    else
                        permanen = true
                        break
                    end
                end

                if terkirim then
                    batchOk = batchOk + 1
                    itemTerkirim = itemTerkirim + #batch
                    for _, slot in ipairs(batch) do
                        local nm = namaSlot[slot] or tostring(slot.ItemKey)
                        terkirimNama[nm] = (terkirimNama[nm] or 0) + (slot.Count or 1)
                    end
                elseif permanen and #batch > 1 then
                    local tengah = math.floor(#batch / 2)
                    local kiri, kanan = {}, {}
                    for n, slot in ipairs(batch) do
                        if n <= tengah then kiri[#kiri + 1] = slot else kanan[#kanan + 1] = slot end
                    end
                    antrian[#antrian + 1] = kiri
                    antrian[#antrian + 1] = kanan
                    status(string.format("[MAIL] %d item ditolak (%s) — dipecah jadi %d + %d",
                        #batch, tostring(alasanGagal), #kiri, #kanan))
                else
                    batchGagal = batchGagal + 1
                    -- Tersisa satu dan tetap ditolak -> ITEM INI penyebabnya.
                    if permanen and #batch == 1 then
                        local slot = batch[1]
                        local nm = tostring(namaSlot[slot] or slot.ItemKey)
                        itemDitolak[#itemDitolak + 1] = string.format("%s (%s)", nm, tostring(slot.Category))
                        mailItemDitolak[kunciSlot(slot)] = nm
                    end
                end
            end
        end

        local bagian = {}
        for nama, n in pairs(terkirimNama) do bagian[#bagian + 1] = n .. " " .. nama end
        local ringkas = table.concat(bagian, ", ")
        if ringkas == "" then ringkas = "0 item" end

        local catatan = batasHarian and "batas 5 mail/hari untuk penerima ini habis" or tostring(alasanGagal)
        -- Nama item yang ditolak sendirian ikut dicatat. Ini satu-satunya jalan
        -- mengetahui apa yang sebenarnya tidak diterima server -- pesannya sendiri
        -- ("Invalid items") tidak pernah menyebutnya.
        if #itemDitolak > 0 then
            catatan = catatan .. " | ditolak: " .. table.concat(itemDitolak, ", ")
        end
        if #dilewati > 0 then
            catatan = catatan .. string.format(" | %d item dilewati (pernah ditolak sesi ini: %s)",
                #dilewati, table.concat(dilewati, ", "))
        end
        local hasilAkhir
        if batchGagal == 0 then
            -- Sukses penuh pun harus menyebut yang dilewati. Kalau tidak, riwayat
            -- terbaca "berhasil" sementara beberapa item sengaja tidak ikut.
            hasilAkhir = ringkas
            if #dilewati > 0 then
                hasilAkhir = hasilAkhir .. string.format(" (%d item dilewati: %s)",
                    #dilewati, table.concat(dilewati, ", "))
            end
        elseif itemTerkirim == 0 then
            hasilAkhir = string.format("GAGAL (%d batch ditolak: %s)", batchGagal, catatan)
        else
            hasilAkhir = string.format("SEBAGIAN %s -- %d dari %d item terkirim (%s)",
                ringkas, itemTerkirim, #apiBatch, catatan)
        end
        status("[MAIL] " .. hasilAkhir .. " -> " .. tostring(targetUsername))
        catatRiwayatMail(hasilAkhir, targetUsername, #apiBatch)
    end)
    mailSibukW2 = false
    if not okAll then warn("[Remote-Mail W2] Error: " .. tostring(err)) end
end

-- Pembaca perintah mail dari Firebase. Mengikuti kaitun utama termasuk kedua
-- penjagaannya: perintah yang lebih tua dari 15 menit dibuang (akun yang mati
-- saat perintah ditulis tidak boleh mengirim seluruh isi tasnya berjam-jam
-- kemudian), dan sidik jari mencegah perintah yang sama dikerjakan berulang
-- kalau penghapusannya di server gagal.
local sidikMailTerakhir = nil

local function periksaPerintahMail()
    if not httprequest or panel_key == "" then return end
    local url = SERVER_URL .. "/api/live/commands/" .. LocalPlayer.Name .. "?panel_key=" .. game:GetService("HttpService"):UrlEncode(raw_panel_key)

    local ok, res = pcall(function()
        return httprequest({ Url = url .. "&r=" .. tostring(math.random(1000000, 9999999)), Method = "GET" })
    end)
    if not ok or not res or not res.Body then return end
    if res.Body == "null" then
        sidikMailTerakhir = nil
        return
    end

    local okJ, cmd = pcall(function() return game:GetService("HttpService"):JSONDecode(res.Body) end)
    if not okJ or type(cmd) ~= "table" then return end
    if cmd.Command ~= "SendMailMulti" or type(cmd.Jobs) ~= "table" then return end

    local function hapus()
        pcall(function() httprequest({ Url = url, Method = "DELETE" }) end)
    end

    if type(cmd.Ts) == "number" then
        local ts = cmd.Ts
        if ts > 9999999999 then ts = ts / 1000 end
        if os.time() - ts > 900 then
            status("[MAIL] Perintah kedaluwarsa, tidak dikirim")
            hapus()
            return
        end
    end

    if res.Body == sidikMailTerakhir then
        hapus()
        return
    end
    sidikMailTerakhir = res.Body
    hapus()

    task.spawn(function()
        for _, job in ipairs(cmd.Jobs) do
            if job.Target then
                kirimMailRemote(job.Target, job.Items or {})
                task.wait(2)
            end
        end
    end)
end

local function syncKePanel()
    -- Kunci kosong DILAPORKAN, tidak didiamkan.
    --
    -- Tanpa panel key, akun ini tidak akan pernah muncul di Kaitun Manager dan
    -- tidak akan pernah menerima config -- tapi script tetap berjalan seolah
    -- semuanya normal. Itu jenis kegagalan yang paling mahal ditelusuri.
    if raw_panel_key == "" then
        _G.KaitunSyncDebug = "[GAGAL] PanelKey kosong — copy ulang snippet dari tab Loader"
        return
    end
    if not httprequest then
        _G.KaitunSyncDebug = "[GAGAL] Executor tidak punya http request"
        return
    end

    local leavesSekarang = 0
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local n = ls and ls:FindFirstChild("Leaves")
    if n then leavesSekarang = n.Value end

    local data = {
        username = LocalPlayer.Name,
        panel_key = raw_panel_key,
        -- Detak per DEVICE untuk perhitungan slot HWID. Lihat catatan panjang di
        -- kaitun_main.txt: username tidak cukup karena satu PC bisa menjalankan
        -- beberapa akun, jadi server butuh HWID untuk tahu device mana yang hidup.
        hwid = hwid,
        status = tostring(_G.FallHarvestDebug or "Kaitun World 2") .. " [FB:" .. ((game.Players.LocalPlayer:GetAttribute("Friends") or 0) * 10) .. "%] [DD:" .. (_G.DDStatus or "?") .. "]",
        -- Panel membaca field ini sebagai saldo. Di dunia ini mata uangnya Leaves,
        -- bukan Sheckles -- namanya tetap "shekels" supaya panel tidak perlu tahu
        -- bedanya, dan label dunianya yang menjelaskan.
        shekels = leavesSekarang,
            world = game.PlaceId,
        world_name = NAMA_DUNIA[game.PlaceId] or "Unknown",
        -- Identitas server, untuk fitur "kumpulkan ke 1 server" di panel.
        job_id = game.JobId,
    }

    local ok, res = pcall(function()
        return httprequest({
            Url = "https://mozeframe.my.id/api/kaitun/sync",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(data),
        })
    end)
    -- Kegagalan sync DILAPORKAN, tidak lagi `return` diam-diam.
    --
    -- Ini celah nyata yang baru ketahuan: World 1 mencatat hasil sync di
    -- _G.KaitunSyncDebug, World 2 tidak sama sekali. Terukur di akun hidup --
    -- script jelas berjalan (_G.FallHarvestDebug terisi) sementara
    -- _G.KaitunSyncDebug nil, jadi mustahil membedakan "sync sehat" dari "sync
    -- tidak pernah berhasil". Untuk memastikan config sampai atau tidak, aku
    -- terpaksa memanggil endpoint-nya sendiri dari luar.
    --
    -- Sekarang satu baris print sudah cukup menjawabnya di akun mana pun.
    if not ok then
        _G.KaitunSyncDebug = "[GAGAL] Tidak ada response: " .. tostring(res):sub(1, 120)
        return
    end
    if not res then
        _G.KaitunSyncDebug = "[GAGAL] Response kosong"
        return
    end
    if res.StatusCode ~= 200 then
        _G.KaitunSyncDebug = string.format("[GAGAL] HTTP %s: %s",
            tostring(res.StatusCode), tostring(res.Body):sub(1, 160))
        return
    end

    local okJ, balasan = pcall(function()
        return game:GetService("HttpService"):JSONDecode(res.Body)
    end)
    if okJ and balasan and balasan.status == "success" and type(balasan.config) == "table" then
        local berubah = terapkanConfig(balasan.config)
        if berubah > 0 then
            status(string.format("[CONFIG] %d setelan diperbarui dari panel", berubah))
        end

        -- Laporan sukses menyebut BERAPA kunci World 2 yang benar-benar datang,
        -- bukan sekadar "OK".
        --
        -- Terekam nyata: server membalas 200 dengan 34 kunci, TAPI SeedTarget,
        -- GearTarget, AutoBeliGear dan AutoJual semuanya nil -- karena Terapkan
        -- ditekan dari form World 1, dan payload W2 hanya ikut kalau form Fall
        -- Harvest yang dipakai. Dari akun, itu tidak terlihat sama sekali: sync
        -- sukses, config datang, tapi tidak ada satu pun setelan W2 di dalamnya.
        --
        -- Menghitungnya di sini membuat kekeliruan itu tampak seketika.
        -- Kelima nama ini HANYA dikirim oleh form Fall Harvest di panel (dicek:
        -- tidak satu pun muncul di payload World 1). Kunci lain seperti AutoTanam
        -- ada di tabel Config tapi tidak pernah dikirim panel mana pun, jadi
        -- memasukkannya akan membuat sync sehat terlihat kurang.
        local kunciW2 = { "SeedTarget", "GearTarget", "AutoBeliGear", "AutoJual", "IgnoreSeeds" }
        local adaW2, total = 0, 0
        for _ in pairs(balasan.config) do total = total + 1 end
        for _, k in ipairs(kunciW2) do
            if balasan.config[k] ~= nil then adaW2 = adaW2 + 1 end
        end
        _G.KaitunSyncDebug = string.format("[OK] %s | %d kunci, %d/%d setelan W2%s",
            os.date("%H:%M:%S"), total, adaW2, #kunciW2,
            adaW2 == 0 and "  <-- TIDAK ADA setelan W2, Terapkan dari form Fall Harvest"
            or "")

        local act = balasan.config.QuickAction
        if act then
            -- Dihapus lebih dulu supaya tidak dijalankan berulang tiap sync.
            pcall(function()
                httprequest({
                    Url = "https://mozeframe.my.id/api/kaitun/clear_action?panel_key="
                        .. game:GetService("HttpService"):UrlEncode(raw_panel_key)
                        .. "&username=" .. game:GetService("HttpService"):UrlEncode(LocalPlayer.Name),
                    Method = "GET",
                })
            end)
            task.spawn(tanganiQuickAction, act)
        end
    end
end

-- ==========================================================
-- MONITOR FIREBASE (Live Monitor di panel)
-- ==========================================================
-- Jalur TERPISAH dari syncKePanel: yang ini mengisi Live Monitor, yang itu
-- mengisi Kaitun Manager. Tanpa ini akun World 2 tidak muncul di Live Monitor
-- sama sekali.
--
-- Path-nya sama persis dengan kaitun utama (users/{panelKey}/accounts/{nama}),
-- ditambah field `world` supaya panel bisa memisahkan item W1 dan W2 -- isi
-- inventory kedua dunia berbeda (varian Maple, Leaves vs Sheckles), jadi
-- menggabungkannya menghasilkan angka yang tidak berarti.
local lastDDCheck = 0
local function tulisMonitor()
    if not httprequest then return end

    if os.clock() - lastDDCheck > 60 then
        lastDDCheck = os.clock()
        task.spawn(function()
            local fw = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Networking"))
            local check = fw.NPCS and fw.NPCS.CheckDailyDeal
            if check then
                local ok, res = pcall(function() return check:Fire() end)
                if ok and type(res) == "table" then
                    _G.DDStatus = res.Available and "V" or "X"
                end
            end
        end)
    end

    local panelKey = raw_panel_key ~= "" and raw_panel_key or "Public"

    local ok, err = pcall(function()
        local daun = 0
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        local n = ls and ls:FindFirstChild("Leaves")
        if n then daun = n.Value end

        -- Inventory dibaca dari Backpack, BUKAN dari replica seperti kaitun
        -- utama. Di game ini seed adalah Tool, dan satu Tool adalah setumpuk --
        -- jumlah sebenarnya ada di atribut Count. Sumber ini yang dipakai
        -- seluruh script untuk menanam, jadi angkanya sudah terbukti benar.
        -- Backpack di dunia ini berisi TIGA jenis Tool yang harus dibedakan:
        --
        --   Shovel / Build            tanpa atribut apa pun -> alat permanen,
        --                             dimiliki SEMUA pemain. Kalau ikut dihitung,
        --                             94 akun menghasilkan "Shovel x94" di puncak
        --                             daftar inventory W2 -- angka tanpa makna.
        --   "Maple Strawberry"        punya SeedTool + Count -> SEED (setumpuk)
        --   "Maple Strawberry [Gold]  tanpa atribut, berat di nama -> BUAH panen
        --    [1.37kg]"
        --
        -- Buah dihitung satu per satu supaya varian bernilai tinggi ([Gold],
        -- [Rainbow]) tetap terlihat di panel. Beratnya dibuang karena tiap buah
        -- punya berat berbeda -- kalau tidak, satu jenis buah pecah jadi puluhan
        -- baris berbeda dan tidak bisa dijumlahkan sama sekali.
        local invData = {}
        for _, wadah in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
            if wadah then
                for _, t in ipairs(wadah:GetChildren()) do
                    if t:IsA("Tool") then
                        local seedName = t:GetAttribute("SeedTool")
                        local count = tonumber(t:GetAttribute("Count"))

                        -- Syarat seed adalah atribut SeedTool, BUKAN sekadar
                        -- punya Count.
                        --
                        -- Dulu cabangnya `seedName or count`, padahal gear juga
                        -- bertumpuk lewat Count. Akibatnya panel menampilkan
                        -- "Trowel (Seed) 49", "Harp (Seed) 2" dan "Syrup
                        -- Sprinkler (Seed) 3" -- gear dilaporkan sebagai bibit,
                        -- dan angkanya mengotori daftar seed.
                        local nama, jumlah
                        if seedName then
                            -- Akhiran (Seed) supaya tidak tertukar dengan buah
                            -- bernama sama: "Maple Strawberry" bisa berarti
                            -- bibit maupun hasil panen. Dibuang lagi oleh
                            -- normalNama() saat pencocokan mail.
                            nama, jumlah = seedName .. " (Seed)", (count or 1)
                        elseif count then
                            -- Gear/alat bertumpuk: pakai namanya apa adanya.
                            nama, jumlah = t.Name, count
                        elseif string.find(t.Name, "kg]", 1, true) then
                            nama, jumlah = string.gsub(t.Name, "%s*%[[%d%.]+kg%]", ""), 1
                        end

                        -- Count 0 tetap dikirim sebelumnya, sehingga panel
                        -- memunculkan "Dog 0" dan "Turkey 0" -- barang yang
                        -- tidak dimiliki, ikut memenuhi daftar.
                        if nama and jumlah and jumlah > 0 then
                            invData[nama] = (invData[nama] or 0) + jumlah
                        end
                    end
                end
            end
        end

        local ping = 0
        pcall(function()
            local Stats = game:GetService("Stats")
            ping = tonumber(string.split(
                Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1]) or 0
        end)

        local livePayload = game:GetService("HttpService"):JSONEncode({
            panel_key = panelKey,
            username  = LocalPlayer.Name,
            data      = {
                username    = LocalPlayer.Name,
                coins       = daun,
                action      = tostring(_G.FallHarvestDebug or "Kaitun World 2") .. " [DD:" .. (_G.DDStatus or "?") .. "]",
                ping        = ping,
                inventory   = invData,
                world       = NAMA_DUNIA[game.PlaceId] or "Fall Harvest",
                placeId     = game.PlaceId,
            },
        })
        local reqOpt = {
            Url = SERVER_URL .. "/api/live/update",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = livePayload,
        }
        local res = httprequest(reqOpt)
        -- Retry sekali kalau server sibuk (checkpoint DB)
        if res and (res.StatusCode == 502 or res.StatusCode == 503) then
            task.wait(5)
            httprequest(reqOpt)
        end
    end)
    if not ok then warn("[FH] Monitor gagal: " .. tostring(err)) end
end

do
    -- Jitter awal + per siklus, mengikuti pola kaitun utama: ratusan akun yang
    -- start berbarengan tidak boleh sync pada detik yang sama.
    local rng = Random.new()
    task.spawn(function()
        local syncFailStreak = 0
        local lastAutoBeli = nil

        task.wait(rng:NextNumber(0, 20))
        while true do
            pcall(syncKePanel)

            -- Health check: lacak apakah config sudah berubah dari default
            if Config.AutoBeli ~= lastAutoBeli then
                lastAutoBeli = Config.AutoBeli
                syncFailStreak = 0
            else
                syncFailStreak = syncFailStreak + 1
            end

            -- Kalau AutoBeli=true tapi SeedTarget kosong, anomali — retry cepat
            if Config.AutoBeli and #(Config.SeedTarget or {}) == 0 then
                warn("[FH-SYNC] ⚠ AutoBeli=true tapi SeedTarget KOSONG! Retry dalam 10 detik...")
                _G.KaitunSyncDebug = "[ANOMALI] AutoBeli=true, SeedTarget kosong — retry"
                task.wait(10)
                pcall(syncKePanel)
            end

            -- Kalau 5 siklus config tidak berubah, paksa retry cepat
            if syncFailStreak >= 5 then
                warn("[FH-SYNC] ⚠ Config tidak berubah selama " .. syncFailStreak .. " siklus. Retry cepat...")
                _G.KaitunSyncDebug = "[PERINGATAN] Config stale — retry cepat"
                task.wait(10)
                pcall(syncKePanel)
                syncFailStreak = 0
            end

            task.wait(rng:NextNumber(30, 32))
        end
    end)

    -- Monitor jalan lebih rapat (5 detik) daripada sync config (30 detik),
    -- mengikuti kaitun utama: Live Monitor memakai lastUpdate untuk menentukan
    -- online/offline dengan ambang 60 detik, jadi 30 detik terlalu jarang dan
    -- akun sehat akan berkedip "Stuck".
    task.spawn(function()
        task.wait(rng:NextNumber(0, 5))
        while true do
            pcall(tulisMonitor)
            task.wait(5)
        end
    end)

    -- Perintah mail dibaca di jalurnya SENDIRI, bukan menumpang syncKePanel.
    -- syncKePanel jalan tiap 30 detik dan sudah membawa config + QuickAction;
    -- menumpangkan mail di sana membuat kiriman tertunda sampai setengah menit
    -- dan satu pengiriman panjang menahan pembaruan config seluruh akun.
    task.spawn(function()
        task.wait(rng:NextNumber(0, 8))
        while true do
            pcall(periksaPerintahMail)
            task.wait(5)
        end
    end)

    -- AUTO RECONNECT -- disalin dari kaitun utama, yang di sini belum ada sama
    -- sekali. Tanpa ini akun World 2 yang kena error 529/disconnect berhenti
    -- permanen sampai dijalankan ulang manual, dan itu sering terjadi di HP.
    local GuiService = game:GetService("GuiService")
    task.spawn(function()
        while true do
            task.wait(5)
            pcall(function()
                local kode = GuiService:GetErrorCode()
                local adaError = kode and kode.Value ~= 0

                if not adaError then
                    local gui = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
                    local overlay = gui and gui:FindFirstChild("promptOverlay")
                    adaError = overlay and overlay:FindFirstChild("ErrorPrompt") ~= nil
                end

                if adaError then
                    -- titipKode() WAJIB duluan. Tanpa itu akun memang kembali
                    -- masuk game, tapi tanpa script apa pun -- online, terlihat
                    -- sehat di monitor, dan sama sekali tidak bekerja.
                    titipKode()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end
    end)
end

-- ==========================================================
-- AUTO SEED COLLECTOR
-- ==========================================================
-- Diport dari startAutoSeedCollector() di kaitun_main.txt -- pendekatan yang sudah
-- terbukti dipakai di lapangan, jadi jangan "disederhanakan" tanpa menguji ulang.
--
-- Sengaja TIDAK memakai jalur SeedPack.ClickPack: pack ber-ClickDetector hanyalah
-- salah satu bentuk drop. Pemindaian ProximityPrompt menangkap semuanya sekaligus --
-- seed jatuhan, gold, rainbow, mega -- tanpa perlu tahu id internal apa pun.
local KATA_SEED = {
    "seed","gold","mega","rainbow","mutation","carrot","apple","pomegranate","coconut",
    "cactus","mushroom","bamboo","corn","berry","acorn","cranberry","pumpkin","banana",
    "beanstalk","blossom","rose","buttercup","cherry","cinnamon","cone","dragon","eclipse",
    "fern","pepper","grape","bean","melon","hypno","lotus","mango","moon","partfruit",
    "pineapple","pine","plum","poison","pop","romanesco","star","sun","thorn","tomato",
    "tulip","venom","venus","flare","crate","maple","honeysuckle","potato",
}
local AKSI_AMBIL = { "pick up", "collect", "take", "grab", "loot", "claim" }
-- Aksi yang TIDAK boleh ditekan kolektor.
--
-- "steal" wajib ada di sini. Terhitung 812 prompt 'steal' di peta ini -- semuanya
-- tanaman milik pemain lain. Daftar asli di kaitun utama tidak memuatnya, dan yang
-- menyelamatkan sejauh ini hanya kebetulan: model tanaman bernama GUID sehingga
-- tidak mengandung kata kunci. Satu tanaman bernama mengandung "maple" atau
-- "carrot" sudah cukup membuat bot terbang mencuri milik orang lain.
local AKSI_BUKAN_AMBIL = {
    harvest = true, sit = true, talk = true, buy = true, use = true,
    steal = true, view = true, gift = true, ["add friend"] = true,
    ["view guild"] = true, interact = true,
}

local function cariSeedJatuh()
    local semua = workspace:GetDescendants()
    for i, prompt in ipairs(semua) do
        -- Yield berkala: workspace di peta ini puluhan ribu instance, dan menelusuri
        -- sekaligus tanpa jeda membuat frame drop terasa.
        if i % 1000 == 0 then task.wait() end

        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local obj = prompt.Parent
            if obj and (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Attachment")) then
                local aksi = string.lower(prompt.ActionText or "")
                local sah = false

                for _, kata in ipairs(AKSI_AMBIL) do
                    if string.find(aksi, kata, 1, true) then sah = true break end
                end

                if not sah and not AKSI_BUKAN_AMBIL[aksi] then
                    local gabungan = string.lower(
                        (obj.Name or "") .. " " ..
                        ((obj.Parent and obj.Parent.Name) or "") .. " " ..
                        (prompt.ObjectText or ""))
                    for _, kata in ipairs(KATA_SEED) do
                        if string.find(gabungan, kata, 1, true) then sah = true break end
                    end
                end

                if sah then return obj, prompt end
            end
        end
    end
end

local function posisiDari(obj, prompt)
    if prompt.Parent:IsA("BasePart") then return prompt.Parent.Position end
    if prompt.Parent:IsA("Attachment") then return prompt.Parent.WorldPosition end
    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position
end

local function ambilSeedJatuh()
    local obj, prompt = cariSeedJatuh()
    if not (obj and prompt) then return 0 end

    local pos = posisiDari(obj, prompt)
    if not pos then return 0 end

    status("[SEED] Mengambil " .. tostring(obj.Name):sub(1, 30))
    if not pergiKe(pos) then return 0 end

    -- Pijakan sementara: tanpa ini karakter bisa jatuh menembus saat mendarat di
    -- titik yang tidak punya lantai.
    local pijakan = Instance.new("Part")
    pijakan.Name = "TempSeedPlatform"
    pijakan.Size = Vector3.new(15, 1, 15)
    pijakan.Position = pos - Vector3.new(0, 4, 0)
    pijakan.Anchored = true
    pijakan.Transparency = 1
    pijakan.Parent = workspace
    game:GetService("Debris"):AddItem(pijakan, 5)

    -- Membuka kunci prompt inilah yang membuatnya andal: bawaan game membatasi
    -- jarak aktivasi dan mensyaratkan garis pandang, dan keduanya sering menggagalkan
    -- penekanan otomatis.
    pcall(function()
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9999
        if prompt.HoldDuration > 0 then prompt.HoldDuration = 0 end
    end)

    for _ = 1, 20 do
        if not prompt.Parent then break end
        pcall(fireproximityprompt, prompt)
        task.wait(0.05)
    end
    task.wait(0.5)
    return 1
end

-- Sistem steal lama (daftarKorban/tembakPrompt/sapuSteal) DIHAPUS.
--
-- Ia memakai fireproximityprompt dan saklarnya (Config.AutoSteal) tidak
-- pernah ada di panel, jadi tidak bisa dinyalakan siapa pun -- sementara
-- quest steal memanggilnya dan karena itu selalu dilewati. Penggantinya
-- stealMalam(), yang memakai remote resmi game (BeginSteal/CompleteSteal).

-- ==========================================================
-- SHOP, GEAR, SPRINKLER & SIRAM
-- ==========================================================
-- Blok ini dulu bernama MODE BAMBOO. Modenya sudah dihapus; isi yang tersisa di
-- sini tidak pernah eksklusif miliknya -- semuanya dipakai alur normal.
--
-- SEMUA signature di bawah dibaca dari kode klien game, bukan ditebak:
--
--   Networking.GearShop.PurchaseGear:Fire("Syrup Watering Can")
--   Networking.Place.PlaceSprinkler:Fire(pos, tool:GetAttribute("Sprinkler"), tool, plotId)
--   Networking.WateringCan.UseWateringCan:Fire(pos - Vector3.new(0,0.3,0),
--                                              tool:GetAttribute("WateringCan"), tool)
--
-- Syarat keras yang dipaksakan server (SprinklerController/WateringcanController):
--   * Tool WAJIB terpasang di Character, bukan sekadar ada di Backpack.
--   * Nama diambil dari ATRIBUT tool ("Sprinkler" / "WateringCan"), bukan dari
--     Tool.Name -- keduanya bisa berbeda.
--   * Posisi WAJIB mengenai part bertag CollectionService "PlantArea" milik
--     plot kita sendiri. Titik di luar itu ditolak diam-diam.
--   * Sprinkler punya jeda 0,5 detik antar pemasangan.
local function plotId()
    local p = plotSaya()
    -- Sama persis dengan GetPlotId di SprinklerController: angka dari nama plot.
    return p and tonumber(string.match(p.Name, "%d+")) or nil
end

-- Titik-titik sah untuk menaruh sprinkler / menyiram.
local function titikPlantArea()
    local p = plotSaya()
    if not p then return {} end
    local hasil = {}
    for _, part in ipairs(CollectionService:GetTagged("PlantArea")) do
        if part:IsA("BasePart") and part:IsDescendantOf(p) then
            hasil[#hasil + 1] = part
        end
    end
    return hasil
end

-- Tool dicari lewat ATRIBUT, bukan nama, karena itu yang dipakai server untuk
-- mengesahkan pemakaian. Tool bernama "Syrup Watering Can" tanpa atribut
-- WateringCan akan ditolak.
-- `disukai` = nama gear yang HARUS didahulukan (mis. "Syrup Sprinkler").
--
-- Tanpa ini fungsi mengembalikan tool PERTAMA yang punya atributnya, dan
-- urutannya semata-mata bergantung isi tas. Akibatnya Super Syrup Sprinkler
-- (300rb) dan Super Syrup Watering Can (1jt) ikut terpakai untuk menyiram dan
-- memasang sprinkler, padahal keduanya sengaja ditimbun untuk dipakai nanti
-- saat kebun sudah rarity tinggi -- berat buah dihitung dari sprinkler yang
-- aktif SAAT PANEN, jadi menghabiskannya sekarang membuang potensinya.
--
-- Dicocokkan ke nama tool MAUPUN nilai atributnya: sebagian gear menyimpan
-- namanya di atribut, bukan di Tool.Name.
--
-- Yang tidak disukai tetap dipakai sebagai CADANGAN kalau yang disukai habis --
-- kebun yang tidak tersiram sama sekali lebih merugikan daripada satu Super
-- yang terpakai. Pemakaian cadangan itu dicatat di status supaya terlihat.
local function toolBeratribut(namaAtribut, disukai)
    local cadangan = nil
    for _, wadah in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
        if wadah then
            for _, t in ipairs(wadah:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute(namaAtribut) then
                    if disukai and (t.Name == disukai
                                    or tostring(t:GetAttribute(namaAtribut)) == disukai) then
                        return t
                    end
                    cadangan = cadangan or t
                end
            end
        end
    end
    return cadangan
end

-- Stok dibaca dari ReplicatedStorage.StockValues, BUKAN dari teks UI toko.
--
-- Terverifikasi di server: StockValues.<Shop>.Items berisi satu ValueBase per
-- item dengan jumlah persis, dan angkanya COCOK dengan yang dipajang UI. Bedanya,
-- UI hanya terisi saat tokonya pernah dibuka -- saat tertutup, membaca Cost_Text
-- memberi angka basi. StockValues tereplikasi terus tanpa perlu membuka apa pun.
local function stokItem(namaShop, namaItem)
    local sv = ReplicatedStorage:FindFirstChild("StockValues")
    local shop = sv and sv:FindFirstChild(namaShop)
    local items = shop and shop:FindFirstChild("Items")
    local v = items and items:FindFirstChild(namaItem)
    if v and v:IsA("ValueBase") then return tonumber(v.Value) or 0 end
    return 0
end

local function detikKeRestock(namaShop)
    local sv = ReplicatedStorage:FindFirstChild("StockValues")
    local shop = sv and sv:FindFirstChild(namaShop)
    local n = shop and shop:FindFirstChild("UnixNextRestock")
    if not (n and n:IsA("ValueBase")) then return nil end
    return math.max(0, (tonumber(n.Value) or 0) - os.time())
end

local function beliGear(nama)
    local ok = pcall(function()
        Networking.GearShop.PurchaseGear:Fire(nama)
    end)
    return ok
end

-- Harga gear dibaca dari modul data game, bukan ditulis ulang di sini.
-- Harganya pernah diubah lewat update dan angka yang dihafal akan diam-diam
-- meleset -- bot menembak beli yang pasti ditolak, atau melewatkan yang
-- sebenarnya terjangkau.
local okGSD, GearShopData = pcall(function()
    return require(ReplicatedStorage.SharedModules.GearShopData)
end)

local function hargaGear(nama)
    if not (okGSD and type(GearShopData) == "table") then return nil end
    -- Datanya bersarang beberapa lapis, jadi ditelusuri, bukan diindeks.
    local function cari(t, dalam)
        if dalam > 3 then return nil end
        for _, v in pairs(t) do
            if type(v) == "table" then
                if v.ItemName == nama then return tonumber(v.Cost) end
                local h = cari(v, dalam + 1)
                if h then return h end
            end
        end
    end
    return cari(GearShopData, 0)
end

-- Berapa banyak gear ini yang sudah dipegang.
local function jumlahGearDimiliki(nama)
    local n = 0
    for _, wadah in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
        if wadah then
            for _, t in ipairs(wadah:GetChildren()) do
                if t:IsA("Tool") then
                    -- Nama tool membawa akhiran jumlah, misalnya "Syrup Sprinkler [3]".
                    local bersih = string.gsub(t.Name, "%s*%[%d+%]$", "")
                    if bersih == nama then
                        n = n + (tonumber(t:GetAttribute("Count")) or 1)
                    end
                end
            end
        end
    end
    return n
end

-- Belanja seluruh gear yang dicentang di panel, urut prioritas.
--
-- WAJIB mendekat ke George dulu. Versi sebelumnya menembakkan PurchaseGear dari
-- posisi mana pun -- pembeliannya berhasil, dan justru itu masalahnya: anticheat
-- mengizinkan transaksinya lalu menandai akunnya. Seed sudah berjalan ke Sam
-- sejak awal; gear terlewat karena peran "gear" ada di NPC_PERAN tapi tidak
-- pernah sekali pun dipanggil.
local function belanjaGearTarget()
    local daftar = Config.GearTarget or {}
    if #daftar == 0 then return 0 end

    -- Disaring dulu sebelum berjalan. Perjalanan ke George memakan waktu siklus,
    -- dan menempuhnya untuk mendapati semuanya kosong itu murni pemborosan.
    -- 0 (atau nilai tak masuk akal) = tanpa batas. Lihat catatan di Config:
    -- gear menumpuk dalam satu Tool beratribut Count, jadi batas kecil apa pun
    -- akan terlewati sekali beli lalu mengunci fitur permanen.
    local maks = tonumber(Config.MaksGearDisimpan) or 0
    if maks < 1 then maks = math.huge end

    local layak = {}
    local alasan = {} -- kenapa yang tidak layak dilewati, untuk status di bawah
    for _, nama in ipairs(daftar) do
        local stok = stokItem("GearShop", nama)
        local punya = jumlahGearDimiliki(nama)
        if stok <= 0 then
            alasan[#alasan + 1] = nama .. " stok habis"
        elseif punya >= maks then
            alasan[#alasan + 1] = string.format("%s penuh %d/%d", nama, punya, maks)
        else
            local harga = hargaGear(nama)
            if harga and leaves() < harga then
                alasan[#alasan + 1] = string.format("%s butuh %d Leaves", nama, harga)
            else
                layak[#layak + 1] = { nama = nama, harga = harga }
            end
        end
    end

    -- Dulu diam-diam `return 0` di sini. Dari luar itu tidak bisa dibedakan dari
    -- "fitur mati" atau "script tidak jalan", dan justru itu yang paling sering
    -- dilaporkan sebagai auto buy gear rusak padahal batas simpannya tercapai.
    if #layak == 0 then
        status("[GEAR] Tidak ada yang dibeli — " .. table.concat(alasan, ", "))
        return 0
    end

    local pos, namaNpc = posisiNPC("gear")
    if not pos then
        status("[BATAL] NPC penjual gear tidak ketemu")
        return 0
    end
    if not pergiKe(pos) then
        status("[BATAL] Gagal mencapai " .. tostring(namaNpc) .. " — beli gear dilewati demi keamanan")
        return 0
    end

    local dibeli = 0
    for _, g in ipairs(layak) do
        if not Config.AutoBeliGear then
            status("[BATAL] Auto Buy Gear dimatikan dari web")
            break
        end

        -- Jarak diperiksa ulang tiap item, sama seperti pembelian seed: karakter
        -- bisa terdorong menjauh di tengah belanja.
        if jarakKe(pos) > Config.JarakAman * 2 then
            -- Dicoba ulang 3x, sama seperti pembelian seed. Lihat catatan di
            -- beli(): terlempar dari NPC itu sesaat, dan menyerah sekali gagal
            -- membuang seluruh sisa belanja tanpa alasan yang sepadan.
            local kembali = false
            for _ = 1, 3 do
                if pergiKe(pos) then kembali = true break end
                task.wait(0.6)
            end
            if not kembali then
                status("[BATAL] Terlempar dari " .. tostring(namaNpc) .. " dan gagal kembali 3x — sisa belanja gear dihentikan")
                break
            end
        end
        if g.harga and leaves() < g.harga then
            -- Dilewati, bukan berhenti: daftarnya urut prioritas, bukan urut
            -- harga, jadi item berikutnya bisa saja jauh lebih murah.
            status(string.format("[LEWAT] %s butuh %d Leaves, punya %d", g.nama, g.harga, leaves()))
        elseif beliGear(g.nama) then
            dibeli = dibeli + 1
            status(string.format("[GEAR] %s dibeli (sisa %d Leaves)", g.nama, leaves()))
            task.wait(Config.JedaAksi)
        end
    end
    return dibeli
end

-- Mengosongkan kebun sampai benar-benar 0 tanaman.
local function pasangSprinkler()
    local tool = toolBeratribut("Sprinkler", Config.GearSprinkler)
    if not tool then return false end

    local nama = tool:GetAttribute("Sprinkler")
    -- Terpaksa memakai yang bukan pilihan (mis. Super) karena yang biasa habis.
    -- Dicatat supaya pemakaian gear timbunan tidak terjadi diam-diam.
    if Config.GearSprinkler and nama ~= Config.GearSprinkler and tool.Name ~= Config.GearSprinkler then
        status(string.format("[GEAR] %s habis — memakai %s", tostring(Config.GearSprinkler), tostring(nama)))
    end
    local id = plotId()
    local titik = titikPlantArea()
    if not (nama and id and #titik > 0) then return false end

    if not equip(tool) then
        status("[SPRINKLER] Sprinkler tidak bisa dipegang")
        return false
    end

    -- PlantArea terdaftar lebih banyak daripada sisi plot yang sebenarnya.
    -- Terukur di kebun sungguhan: empat part bertag PlantArea, tapi dua di
    -- antaranya berjarak ~1 stud dari dua lainnya -- pasangan yang saling
    -- menimpa, bukan area terpisah:
    --
    --     Part              (153.0, 10.4)    Column1 (152.3, 11.1)   <- sisi kanan
    --     Part              (112.7, -29.9)   Column2 (112.0, -29.2)  <- sisi kiri
    --
    -- Memasang di keempatnya membuang dua sprinkler di titik yang praktis sama.
    -- Karena itu dikelompokkan dulu: part yang berdekatan dianggap satu sisi,
    -- dan sprinkler ditaruh di titik tengah tiap kelompok.
    local AMBANG_GUGUS = 25   -- di bawah jarak antar sisi (~57 studs), jauh di
                              -- atas jarak antar part yang menimpa (~1 stud)

    local gugus = {}
    for _, part in ipairs(titik) do
        local p = part.Position
        local masuk = nil
        for _, g in ipairs(gugus) do
            local d = (Vector2.new(p.X, p.Z) - Vector2.new(g.x, g.z)).Magnitude
            if d <= AMBANG_GUGUS then masuk = g break end
        end
        if masuk then
            -- Titik tengah digeser jadi rata-rata, supaya sprinkler mendarat di
            -- tengah gabungan kedua part, bukan di salah satunya.
            masuk.n = masuk.n + 1
            masuk.x = masuk.x + (p.X - masuk.x) / masuk.n
            masuk.z = masuk.z + (p.Z - masuk.z) / masuk.n
            if p.Y + part.Size.Y / 2 > masuk.y then masuk.y = p.Y + part.Size.Y / 2 end
        else
            gugus[#gugus + 1] = { x = p.X, z = p.Z, y = p.Y + part.Size.Y / 2, n = 1 }
        end
    end

    -- Sisi dengan part terbanyak didahulukan: itu yang lahannya paling luas,
    -- jadi kalau sprinkler yang dipegang cuma satu, ia jatuh di tempat yang
    -- paling banyak menaungi tanaman.
    table.sort(gugus, function(a, b) return a.n > b.n end)

    local maks = math.min(Config.MaksSprinkler or 2, #gugus)
    local dipasang = 0

    for i = 1, maks do
        local g = gugus[i]
        local pos = Vector3.new(g.x, g.y, g.z)
        local ok = pcall(function()
            Networking.Place.PlaceSprinkler:Fire(pos, nama, tool, id)
        end)
        if ok then dipasang = dipasang + 1 end
        -- Jeda 0,5 detik dipaksakan klien game (TryPlace menolak lebih cepat
        -- dari itu). 0,6 diberi sedikit kelonggaran.
        task.wait(0.6)
    end

    status(string.format("[SPRINKLER] %d dipasang di %d sisi plot (dari %d PlantArea)",
        dipasang, #gugus, #titik))
    return dipasang > 0
end

local function siramKebun(kali)
    local tool = toolBeratribut("WateringCan", Config.GearSiram)
    if not tool then return false end

    local nama = tool:GetAttribute("WateringCan")
    if not nama then return false end
    -- Sama seperti sprinkler: pemakaian gear timbunan tidak boleh senyap.
    if Config.GearSiram and nama ~= Config.GearSiram and tool.Name ~= Config.GearSiram then
        status(string.format("[GEAR] %s habis — memakai %s", tostring(Config.GearSiram), tostring(nama)))
    end

    if not equip(tool) then
        status("[SIRAM] Watering can tidak bisa dipegang")
        return false
    end

    local radius = radiusSiram(nama)
    local n = 0

    for _ = 1, (kali or 4) do
        -- Titik dihitung ULANG tiap siraman. Tanaman bisa tumbuh, dipanen, atau
        -- bertambah di sela-sela, sehingga titik terbaik ikut bergeser; memakai
        -- satu titik yang dihitung sekali di awal menyiram tempat yang sudah
        -- tidak optimal lagi.
        local pos, tertutup = titikSiramTerbaik(radius)
        if not pos then break end

        local ok = pcall(function()
            -- Offset -0.3 pada Y disalin dari WateringcanController: server
            -- memeriksa titiknya terhadap permukaan PlantArea, dan tanpa offset
            -- ini sebagian tembakan meleset di atas permukaan.
            Networking.WateringCan.UseWateringCan:Fire(
                pos - Vector3.new(0, 0.3, 0), nama, tool)
        end)
        if ok then
            n = n + 1
            status(string.format("[SIRAM] Siram %d/%d — menutupi %d tanaman (radius %d)",
                n, kali or 4, tertutup or 0, radius))
        end
        task.wait(0.35)
    end

    return n > 0
end

-- ==========================================================
-- MENCURI SAAT MALAM WEREWOLF
-- ==========================================================
-- Terbaca dari WerewolfNightData: atributnya "WerewolfNightDefender", dan
-- StealController menolak Defender dengan pesan "You can only steal as a
-- werewolf!". Jadi yang menentukan bukan "apakah kita werewolf" -- melainkan
-- "apakah kita BUKAN Defender", karena tidak ada atribut werewolf yang positif.
local ATRIBUT_DEFENDER = "WerewolfNightDefender"

local function malamWerewolf()
    -- ReplicatedStorage.Night itu boolean resmi yang direplikasi game; fase
    -- dipakai sebagai cadangan kalau nilainya belum sempat tersinkron.
    local n = ReplicatedStorage:FindFirstChild("Night")
    local malam = n ~= nil and n:IsA("BoolValue") and n.Value == true
    if not malam then
        -- Fase malam yang ada: Moon, Mega Moon, Bloodmoon, Goldmoon, Harvest
        -- Moon, Chained Moon, Pizza Moon, Rainbow Moon. Yang siang cuma Day
        -- dan Sunset.
        --
        -- Dikecilkan dulu huruf-hurufnya, dan itu WAJIB: "Bloodmoon" dan
        -- "Goldmoon" ditulis dengan m kecil sementara sisanya "Moon". Mencocokkan
        -- "Moon" apa adanya membuat dua malam itu terbaca siang -- gagal diam-diam,
        -- persis pada malam yang justru paling ramai.
        local fase = string.lower(tostring(workspace:GetAttribute("ActivePhase")))
        malam = string.find(fase, "moon", 1, true) ~= nil
    end
    if not malam then return false, "siang" end
    if LocalPlayer:GetAttribute(ATRIBUT_DEFENDER) == true then
        return false, "kita Defender malam ini"
    end
    return true, "malam"
end

-- Pemilik kebun yang sudah pernah kita curi. Untuk quest, bukan sekadar catatan:
-- yang dihitung ORANG berbeda, jadi ini yang menentukan urutan sasaran.
local sudahCuriDari = {}

-- Sasaran curi: buah milik orang lain yang punya StealPrompt.
--
-- StealPrompt hanya dibuat game untuk buah yang BUKAN milik kita dan memang
-- boleh dicuri, jadi keberadaannya sekaligus menjadi penyaring -- tidak perlu
-- menebak-nebak aturan mana yang berlaku.
local function sasaranSteal()
    local daftar = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" and d.Enabled then
            local buah = buahDariPrompt(d)
            if buah then
                local pemilik = tonumber(buah:GetAttribute("UserId"))
                local plantId = buah:GetAttribute("PlantId")
                local fruitId = buah:GetAttribute("FruitId")
                if pemilik and plantId and fruitId and pemilik ~= LocalPlayer.UserId then
                    local induk = d.Parent
                    daftar[#daftar + 1] = {
                        pemilik = pemilik,
                        plantId = plantId,
                        fruitId = fruitId,
                        pos = induk and induk:IsA("BasePart") and induk.Position or nil,
                        baru = sudahCuriDari[pemilik] == nil,
                    }
                end
            end
        end
    end

    if Config.StealUtamakanOrangBaru then
        -- Pemilik baru dulu; sisanya urut apa adanya. Tanpa ini, kebun terdekat
        -- dikuras habis dan quest "curi dari 15 orang" tidak pernah maju.
        table.sort(daftar, function(a, b)
            if a.baru ~= b.baru then return a.baru end
            return false
        end)
    end
    return daftar
end

-- paksa=true dipakai saat quest "Steal from N people" sedang aktif.
--
-- Penjagaan malam itu PREFERENSI, bukan aturan game: satu-satunya hal yang
-- benar-benar diblokir server adalah mencuri saat kita Defender. Menahan quest
-- sampai malam berarti quest berhenti sepanjang siang tanpa alasan teknis --
-- padahal quest inilah yang tidak bisa diselesaikan dengan cara lain.
local function stealMalam(paksa)
    if not Config.AutoStealMalam then return 0 end
    -- Defender tetap diperiksa dalam kedua mode. Ini aturan server, dan
    -- menembaknya hanya menghasilkan penolakan beruntun.
    if LocalPlayer:GetAttribute(ATRIBUT_DEFENDER) == true then return 0 end
    if not paksa then
        local boleh = malamWerewolf()
        if not boleh then return 0 end
    end

    local daftar = sasaranSteal()
    if #daftar == 0 then return 0 end

    local dicuri, orangBaru = 0, 0
    local pemilikDisentuh = {}
    for _, t in ipairs(daftar) do
        if dicuri >= Config.StealMaksPerSiklus then break end

        -- Satu buah per pemilik per siklus saat mengejar quest: yang dihitung
        -- orangnya, dan berlama-lama di satu kebun hanya menambah waktu terpapar.
        if not (Config.StealUtamakanOrangBaru and pemilikDisentuh[t.pemilik]) then
            -- Mendekat dulu, sama seperti pembelian. Fire jarak jauh diterima
            -- server -- dan justru itu yang ditandai anticheat.
            local dekat = true
            if t.pos then dekat = pergiKe(t.pos) end
            if dekat then
                local ok = pcall(function()
                    -- Pasangan ini diambil dari FruitMagnetController milik game
                    -- sendiri: BeginSteal lalu CompleteSteal berurutan. Menembak
                    -- CompleteSteal sendirian ditolak diam-diam, pola yang sama
                    -- dengan PreviewSellAll -> SellAll.
                    Networking.Steal.BeginSteal:Fire(t.pemilik, t.plantId, t.fruitId)
                    Networking.Steal.CompleteSteal:Fire()
                end)
                if ok then
                    dicuri = dicuri + 1
                    pemilikDisentuh[t.pemilik] = true
                    if sudahCuriDari[t.pemilik] == nil then
                        sudahCuriDari[t.pemilik] = true
                        orangBaru = orangBaru + 1
                    end
                    task.wait(Config.JedaAksi)
                end
            end
        end
    end

    if dicuri > 0 then
        local jumlahOrang = 0
        for _ in pairs(sudahCuriDari) do jumlahOrang = jumlahOrang + 1 end
        status(string.format("[CURI] %d buah, %d orang baru (total %d orang)",
            dicuri, orangBaru, jumlahOrang))
    end
    return dicuri
end

-- WATCHDOG: DETEKSI GAME/CPU/NETWORK FREEZE
--
-- Berbeda dengan watchdog Leaves macet (RejoinSaatMacet) yang hanya menangani
-- "bot jalan tapi tidak produktif", ini menangani "bot MATI TOTAL" — siklus
-- utama berhenti berjalan sama sekali karena engine freeze atau koneksi putus.
-- Pola deteksi identik dengan kaitun_main.txt AntiFreeze: task.wait(3) yang
-- memakan waktu > 15 detik berarti CPU freeze, ping > 10 detik berarti
-- network freeze.
local function startWatchdog()
    if not Config.AntiFreeze then return end
    task.spawn(function()
        local Stats = game:GetService("Stats")
        while true do
            local startTick = tick()
            task.wait(3)
            local elapsed = tick() - startTick
            if elapsed > Config.FreezeDelayDetik then
                forceRejoin("Game Freeze parah (" .. math.floor(elapsed) .. "s delay CPU)")
                return
            end
            pcall(function()
                local pingStr = string.split(
                    Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1]
                local ping = tonumber(pingStr) or 0
                if ping > Config.FreezePingBatas then
                    forceRejoin("Network Freeze / Ping terlalu tinggi (" .. math.floor(ping) .. "ms)")
                end
            end)
        end
    end)
end

-- Menjaga akun tetap terhitung aktif.
--
-- Dipisah ke fungsi sendiri supaya jelas: ini SATU-SATUNYA tempat script
-- memalsukan masukan pemain. Semua bagian lain hanya memanggil remote game.
local function mulaiAntiAfk()
    if not Config.AntiAfk then return end
    task.spawn(function()
        while true do
            -- 90 detik, di bawah ambang 120 detik milik AfkIdleSeconds supaya
            -- statusnya tidak sempat berganti jadi AFK sama sekali.
            task.wait(90)
            pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                -- LeftShift dipilih karena tidak terikat aksi apa pun di game
                -- ini -- tombol gerak atau angka akan benar-benar melakukan
                -- sesuatu dan mengacaukan siklus.
                VIM:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
            end)
        end
    end)
end

-- ==========================================================
-- CORNUCOPIA QUEST (menempel, tanpa gerakan tambahan)
-- ==========================================================
local function questTempel()
    if not Config.AutoQuest then return end
    local ok, st = pcall(function() return Networking.Pilgrim.GetState:Fire() end)
    if not ok or type(st) ~= "table" or st.Enabled == false then return end

    if st.ChainComplete == true then
        if st.RewardClaimed ~= true then
            pcall(function() Networking.Pilgrim.ClaimReward:Fire() end)
            status(string.format("[QUEST] %s diklaim!", tostring(st.RewardName or "Grand Prize")))
        else
            -- Rantai selesai DAN hadiah sudah diambil. Tidak ada lagi yang bisa
            -- dikerjakan sampai reset harian; melaporkan sisa waktunya lebih
            -- berguna daripada diam.
            local reset = tonumber(st.ResetAtUnix)
            local sisa = reset and math.max(0, reset - os.time())
            status(string.format("[QUEST] Rantai tuntas (%s/%s)%s",
                tostring(st.Done or "?"), tostring(st.Total or "?"),
                sisa and string.format(" — reset %dj %dm lagi",
                    math.floor(sisa / 3600), math.floor((sisa % 3600) / 60)) or ""))
        end
        return
    end

    local q
    for _, v in pairs(st.Quests or {}) do
        if type(v) == "table" and v.Status == "ongoing" then q = v break end
    end
    if not q then return end

    -- Rantai Cornucopia berurutan, dan sebagian langkahnya bertipe "passive":
    -- "Steal from 15 different people", "Grow a 100 ft tall plant". Keduanya
    -- tidak punya remote untuk disetor -- server yang menghitung sendiri dari
    -- kejadian di dunia. Bot akan MENUNGGU di langkah itu sampai syaratnya
    -- terpenuhi, dan tanpa pesan ini diamnya terlihat seperti quest rusak.
    if q.Kind ~= "delivery" then
        local desc = tostring(q.Description or "")
        local progres = tonumber(q.Progress) or 0
        local target = tonumber(q.Target) or 0

        -- Satu-satunya langkah pasif yang bisa kita dorong. "Grow a 100 ft tall
        -- plant" tidak ada aksinya sama sekali -- itu tumbuh sendiri seiring
        -- waktu, jadi memang hanya bisa ditunggu.
        if Config.AutoStealMalam and string.find(desc, "Steal", 1, true) then
            -- Dipaksa: quest tidak peduli siang atau malam, dan ini satu-satunya
            -- langkah quest yang benar-benar bisa didorong bot.
            local dicuri = stealMalam(true)
            local jumlahOrang = 0
            for _ in pairs(sudahCuriDari) do jumlahOrang = jumlahOrang + 1 end
            status(string.format("[STEAL] %s (%d/%d) — %d buah dicuri, %d orang tersentuh",
                desc, progres, target, dicuri, jumlahOrang))

            -- Nol curian berarti tidak ada sasaran BARU yang tersisa di server
            -- ini: stealMalam mengambil satu buah per pemilik dan melewati yang
            -- sudah pernah disentuh. Server cuma muat 8 orang, jadi paling banyak
            -- 7 korban -- kalau target quest lebih dari itu, pindah server memang
            -- satu-satunya jalan.
            if dicuri == 0 and progres < target and Config.StealPindahServer then
                status("[STEAL] Korban di server ini habis — pindah server")
                titipKode()
                teleportAman(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end, "ganti server untuk korban baru", 2)
            elseif dicuri == 0 and progres < target then
                status(string.format(
                    "[STEAL] Korban server ini habis (%d/%d). Nyalakan StealPindahServer untuk lanjut",
                    progres, target))
            end
            return
        end

        -- Dibedakan supaya jelas mana yang akan beres sendiri dan mana yang
        -- memang berhenti di situ. Tanpa pembedaan ini, keduanya terbaca sama
        -- seperti quest rusak.
        if string.find(desc, "Steal", 1, true) then
            status(string.format(
                "[QUEST] Dilewati (Curi Malam Werewolf mati): %s (%s/%s) — tani jalan terus",
                desc, tostring(q.Progress), tostring(q.Target)))
        else
            status(string.format("[QUEST] Menunggu langkah pasif: %s (%s/%s)",
                desc, tostring(q.Progress), tostring(q.Target)))
        end
        return
    end

    -- ---- LANGKAH DELIVERY ----
    local progres = tonumber(q.Progress) or 0
    local target = tonumber(q.Target) or 0
    local langkah = tonumber(st.StepIndex) or 0
    local totalLangkah = tonumber(st.Total) or 0
    local desc = tostring(q.Description or "?")

    -- Tidak ada buah -> tidak ada yang bisa disetor. Menembak SubmitDelivery
    -- dalam keadaan ini murni sia-sia: server menolaknya, progres tidak
    -- bergerak, dan versi sebelumnya tetap melakukannya sampai 15 kali tiap
    -- siklus. Panen dulu, baru quest -- urutan fase memang sudah begitu.
    local buah = jumlahBuah()
    if buah <= 0 then
        status(string.format("[QUEST] %d/%d %s (%d/%d) — inventory kosong, panen dulu",
            langkah, totalLangkah, desc, progres, target))
        return
    end

    -- Batas percobaan mengikuti jumlah buah yang benar-benar dipegang. Kalau
    -- cuma punya 3 buah, menembak 15 kali berarti 12 tembakan yang pasti gagal.
    local maks = math.min(15, buah)
    local awal = progres
    local mandek = 0

    for _ = 1, maks do
        local ok2, baru = pcall(function() return Networking.Pilgrim.SubmitDelivery:Fire() end)
        if not ok2 or type(baru) ~= "table" then break end

        local q2
        for _, v in pairs(baru.Quests or {}) do
            if type(v) == "table" and v.Status == "ongoing" then q2 = v break end
        end
        if not q2 then
            status(string.format("[QUEST] Langkah %d/%d TUNTAS: %s", langkah, totalLangkah, desc))
            return
        end

        local p2 = tonumber(q2.Progress) or 0
        if p2 <= progres then
            -- Progres tidak bergerak padahal buah ada. Hampir selalu berarti
            -- JENIS buahnya tidak cocok -- quest meminta tier atau varian
            -- tertentu ("Submit 50 Uncommon-tier fruit", "Submit 15 Electric
            -- fruit"), dan yang kita pegang bukan itu. Menembak lagi tidak akan
            -- mengubah apa pun.
            mandek = mandek + 1
            if mandek >= 2 then
                status(string.format("[QUEST] %d/%d %s (%d/%d) — punya %d buah tapi jenisnya tidak cocok",
                    langkah, totalLangkah, desc, progres, target, buah))
                return
            end
        else
            mandek = 0
            progres = p2
        end
        task.wait(0.4)
    end

    if progres > awal then
        status(string.format("[QUEST] %d/%d %s (%d/%d) +%d",
            langkah, totalLangkah, desc, progres, target, progres - awal))
    end
end

-- Menjalankan sebuah fungsi tanam dengan batas area sprinkler terpasang.
--
-- Satu-satunya jalur penanaman berbatas area. Dua hal yang wajib dijaga di sini:
--
--   1. Tanpa sprinkler berdiri, batas TIDAK dipasang. Mengurung penanaman ke
--      area yang tidak ada berarti tidak menanam apa pun sama sekali.
--   2. Batas dikosongkan lagi APA PUN yang terjadi. Kalau fungsi tanam melempar
--      error dan baris pengosongan terlewat, seluruh penanaman berikutnya ikut
--      terkurung ke sprinkler yang mungkin sudah kedaluwarsa -- kebun berhenti
--      terisi tanpa sebab yang terlihat.
local function tanamDalamAreaSprinkler(fnTanam)
    local area = sprinklerTerpasang()
    areaSprinklerAktif = (#area > 0) and area or nil

    if areaSprinklerAktif then
        status(string.format("[TANAM] Dikurung ke jangkauan %d sprinkler (radius %d)",
            #area, area[1].radius))
    end

    local hasil
    local ok, err = pcall(function() hasil = fnTanam() end)
    areaSprinklerAktif = nil
    if not ok then error(err, 0) end
    return hasil
end

-- ==========================================================
-- LOOP UTAMA
-- ==========================================================
_G.FHInstance = (_G.FHInstance or 0) + 1
local instanceSaya = _G.FHInstance

-- Penanda build dicetak lebih dulu supaya "script tidak jalan" bisa dipisahkan
-- dari "script jalan tapi salinannya lama". raw.githubusercontent menahan
-- salinan lama sampai ~5 menit, dan tanpa baris ini kita pernah berjam-jam
-- mendiagnosis bug yang di sumbernya sudah diperbaiki.
_G.FHBuild = "FH BUILD 2026-08-13a | sync-report=ON"
status(_G.FHBuild)
status(string.format("Aktif (#%d). Ambang speedrun=%s", instanceSaya, Config.AmbangSpeedrun))
mulaiAntiAfk()
startWatchdog()

pasangBlackScreen()
if Config.AntiAFK then pasangAntiAFK() end
startAutoCDS()
startAutoMasak()

task.spawn(function()
    local putaranSiklus = 0
    while instanceSaya == _G.FHInstance do
        putaranSiklus = putaranSiklus + 1

        -- Ditahan di sini, sebelum fase APA PUN disusun.
        --
        -- Bukan hanya penanaman yang gagal selama layar muat: beli menembak ke
        -- NPC yang belum ada, jual menembak inventory yang belum tersinkron,
        -- dan semuanya ditolak diam-diam. Menahan satu kali di depan jauh lebih
        -- murah daripada satu siklus penuh yang setiap fasenya gagal.
        --
        -- Sesudah siap, siapBermain() hanya membaca empat atribut, jadi biaya
        -- pemanggilan tiap siklus praktis nol.
        tungguSiap()

        -- WATCHDOG DUNIA GAGAL MUAT.
        --
        -- Gate yang dilepas berarti LoadingScreenDone tidak pernah beres. Itu
        -- punya DUA sebab yang penanganannya berlawanan, dan plotSaya() yang
        -- membedakannya:
        --
        --   plot KETEMU  -> dunia sebenarnya jalan, cuma atributnya yang tidak
        --                   pernah diset (mis. game mengganti namanya). Melepas
        --                   gate sudah jawaban yang benar; jangan rejoin.
        --   plot NIHIL   -> client-nya memang gagal memuat. Siklus tetap jalan
        --                   tapi tiap fase menembak dunia yang tidak ada:
        --                   tidak ada kebun, tidak ada NPC, Leaves diam di
        --                   tempat. Ini TIDAK pulih sendiri -- ditunggu berapa
        --                   lama pun hasilnya sama, jadi satu-satunya jalan
        --                   keluar adalah masuk ulang.
        --
        -- Tiga siklus dulu, bukan langsung: plotSaya() bisa sesaat nihil saat
        -- karakter respawn, dan rejoin karena itu justru membuang sesi yang sehat.
        if gateDilepas then
            if plotSaya() then
                siklusTanpaDunia = 0
            else
                siklusTanpaDunia = siklusTanpaDunia + 1
                status(string.format("[MACET] Dunia tidak termuat (%d/%d siklus) — kebun tidak ditemukan",
                    siklusTanpaDunia, SIKLUS_SEBELUM_REJOIN))
                -- Jarak antar rejoin dijaga: kalau server tujuannya yang bermasalah,
                -- rejoin beruntun hanya menghasilkan lingkaran join-gagal-join.
                if siklusTanpaDunia >= SIKLUS_SEBELUM_REJOIN
                   and tick() - rejoinMacetTerakhir > 300 then
                    rejoinMacetTerakhir = tick()
                    siklusTanpaDunia = 0
                    forceRejoin("Dunia tidak pernah selesai memuat — kebun tidak ditemukan setelah "
                        .. SIKLUS_SEBELUM_REJOIN .. " siklus. Masuk ulang.")
                end
            end
        end

        -- WATCHDOG MACET DI AMBANG BAWAH LEAVES.
        --
        -- Watchdog di atas hanya menyala saat plotSaya() NIHIL. Bot yang dunianya
        -- termuat normal -- kebun ketemu, NPC ketemu, sanggup berjalan ke Sam --
        -- tapi tidak pernah menanam sama sekali TIDAK PERNAH tersentuh olehnya,
        -- karena siklusTanpaDunia direset tiap siklus. Terlihat langsung di cloud:
        -- 8 akun baru, runtime 1 jam lebih, Planted 0 dan Fruits 0/100 semua.
        --
        -- Leaves dipakai sebagai ukuran karena itu satu-satunya angka yang pasti
        -- bergerak begitu ada SATU fase saja yang benar-benar berhasil.
        if Config.RejoinSaatMacet then
            -- Dihitung sekali: place tidak bisa berubah tanpa rejoin, dan require
            -- tiap siklus itu ongkos yang tidak perlu.
            if jagaMacet.karantina == nil then
                jagaMacet.karantina = false
                pcall(function()
                    jagaMacet.karantina =
                        require(game.ReplicatedStorage.SharedModules.Environment)
                            .isBotContainmentPlace == true
                end)
            end

            if leaves() > Config.MacetLeavesAmbang and leaves() > 1 then
                jagaMacet.leavesSejak = 0
                jagaMacet.paksaTanam = false
            elseif jagaMacet.karantina then
                -- Di place karantina Leaves MEMANG tidak akan bergerak, dan rejoin
                -- hanya mendarat di karantina lagi. Rejoin beruntun tiap lima menit
                -- justru pola paling mencolok yang bisa dilihat server, jadi di
                -- sini watchdog-nya melapor saja dan berhenti di situ.
                if jagaMacet.leavesSejak == 0 then
                    jagaMacet.leavesSejak = tick()
                    status("[MACET] Leaves di ambang bawah, TAPI ini place karantina bot — rejoin dilewati")
                end
            else
                if jagaMacet.leavesSejak == 0 then jagaMacet.leavesSejak = tick() end
                local diam = tick() - jagaMacet.leavesSejak
                
                -- Anti-Stuck Khusus 1/0 Leaves: 5 mnt = paksa tanam, 10 mnt = rejoin
                if leaves() <= 1 and diam >= 300 and diam < 600 and not jagaMacet.paksaTanam then
                    jagaMacet.paksaTanam = true
                    status("[ANTI-STUCK] Macet di 1/0 Leaves > 5 menit! Memaksa beli dan tanam Maple Carrot...")
                    task.spawn(function()
                        pcall(function() Networking.TeleportButton.Request:Fire("Seeds") end)
                        task.wait(1.5)
                        pcall(function() Networking.SeedShop.PurchaseSeed:Fire("Maple Carrot") end)
                        task.wait(1.5)
                        pcall(function() tanamSemua() end)
                    end)
                end

                local batasRejoin = (leaves() <= 1) and 600 or Config.MacetDetik
                if diam >= batasRejoin and tick() - rejoinMacetTerakhir > 300 then
                    rejoinMacetTerakhir = tick()
                    jagaMacet.leavesSejak = 0
                    jagaMacet.paksaTanam = false
                    forceRejoin(string.format(
                        "Macet di %d Leaves selama %d detik tanpa kemajuan. Masuk ulang.",
                        leaves(), math.floor(diam)))
                end
            end
        end

        -- SELURUH isi siklus dibungkus pcall, bukan hanya tiap fase.
        --
        -- Tiap fase memang sudah dilindungi pcall sendiri, tapi penyusunan daftar
        -- fase di bawah TIDAK: daftarTanaman(), rarityTerendahKebun(), dan
        -- jumlahBuah() semuanya dipanggil di luar perlindungan itu. Satu error di
        -- sana -- misalnya karakter respawn tepat saat kebun dibaca -- melempar
        -- keluar dari while, keluar dari thread, dan bot berhenti PERMANEN tanpa
        -- pesan apa pun. Untuk bot yang ditinggal berjam-jam, itu kegagalan
        -- paling mahal: kelihatan online di monitor, tapi tidak mengerjakan apa-apa.
        local okSiklus, errSiklus = pcall(function()

        local tanaman = daftarTanaman()

        -- Speedrun Leaves: berhenti belanja sama sekali.
        --
        -- DUA syarat, dan keduanya wajib:
        --   1. Kebun PENUH -- selama masih ada tanah kosong, mengisinya dengan
        --      seed apa pun lebih baik daripada membiarkannya menganggur.
        --   2. Tanaman TERLEMAH sudah mencapai ambang -- kalau yang terlemah pun
        --      sudah Legendary, tidak ada isi shop yang bisa menggantikannya,
        --      jadi setiap pembelian murni membuang Leaves.
        --
        -- Versi sebelumnya memakai rarity TERTINGGI dan tanpa syarat penuh:
        -- satu tanaman Legendary di kebun yang sisanya Common sudah menghentikan
        -- seluruh pembelian, padahal masih banyak tanah kosong. Itu keliru.
        local rarityTerlemah = rarityTerendahKebun()
        local speedrun = kebunPenuh and rarityTerlemah >= AMBANG_SPEEDRUN

        -- Fase dijalankan BERURUTAN dan satu per satu, tidak ada yang menumpuk.
        --
        -- Urutannya disengaja, bukan sekadar rapi:
        --   panen  -> menghasilkan buah
        --   quest  -> dapat giliran PERTAMA atas buah itu; SubmitDelivery dan
        --             SellAll sama-sama memakan inventory, dan sebelumnya
        --             keduanya jalan tanpa saling tahu sehingga buah untuk quest
        --             ikut terjual
        --   jual   -> membuang sisanya jadi Leaves
        --   beli   -> memakai Leaves yang baru saja masuk
        --   tanam  -> menanam seed yang baru saja dibeli
        --
        -- Tiap fase diberi jeda sendiri supaya efeknya sempat tercatat server
        -- sebelum fase berikutnya membaca keadaan.
        local fase = {}



        -- ==== PRIORITAS 1: SEED JATUHAN ====
        -- Ditaruh paling atas dengan sengaja. Ini satu-satunya sumber yang bisa
        -- HILANG DIREBUT pemain lain -- gold, rainbow, dan mega seed muncul
        -- sebentar lalu diambil siapa pun yang sampai duluan.
        --
        -- Sisanya tidak ke mana-mana: buah menunggu di kebun sendiri, Leaves tidak
        -- menguap, shop tidak kehabisan stok karena kita telat semenit. Jadi
        -- menunda seed demi panen adalah satu-satunya urutan yang benar-benar
        -- merugikan.
        if Config.AutoAmbilSeed then fase[#fase + 1] = { "ambil-seed", ambilSeedJatuh } end

        -- ==== SPRINKLER DULU, SEBELUM MENANAM APA PUN ====
        -- Penanaman dikurung ke radius sprinkler, jadi sprinkler HARUS sudah
        -- berdiri sebelum fase tanam mana pun -- termasuk "tanam-awal" yang
        -- berjalan jauh di atas fase "tanam". Kalau dipasang belakangan, siklus
        -- pertama menanam tanpa batas area sama sekali.
        --
        -- Konsekuensinya sprinkler kehilangan sebagian umur 120 detiknya di
        -- lahan yang belum terisi. Itu ditukar dengan jaminan setiap tanaman
        -- baru berada dalam jangkauan -- dan jangkauan itulah yang menaikkan
        -- berat, yang menentukan harga jual karena nilainya berpangkat.
        if Config.AutoBeliGear then
            fase[#fase + 1] = { "beli-gear", function()
                belanjaGearTarget()
            end }
        end

        if Config.AutoSprinkler and toolBeratribut("Sprinkler") then
            fase[#fase + 1] = { "sprinkler", pasangSprinkler }
        end

        -- ==== PRIORITAS 2: QUEST ====
        -- Quest naik ke urutan kedua, TAPI tidak bisa ditaruh mentah-mentah di
        -- sini. SubmitDelivery memakan buah dari inventory; kalau quest jalan
        -- saat inventory kosong ia tidak melakukan apa-apa, lalu fase "jual" di
        -- bawah menghabiskan buah hasil panen siklus ini -- quest tidak akan
        -- pernah kebagian buah sama sekali.
        --
        -- Jadi dipecah dua:
        --   sudah ada buah -> quest jalan SEKARANG, benar-benar prioritas 2 dan
        --                     mendahului "jual-awal" yang kalau tidak akan
        --                     menjual habis buah untuk quest
        --   belum ada buah -> quest menunggu tepat setelah panen, tetap sebelum
        --                     jual, jadi tetap dapat giliran pertama
        local adaBuah = jumlahBuah() > 0
        if Config.AutoQuest and adaBuah then
            fase[#fase + 1] = { "quest", questTempel }
        end

        -- Mencuri hanya berjalan saat malam DAN kita bukan Defender; di luar itu
        -- stealMalam() langsung mengembalikan 0 tanpa menyentuh apa pun, jadi
        -- aman didaftarkan di setiap siklus.
        if Config.AutoStealMalam then
            fase[#fase + 1] = { "curi", stealMalam }
        end

        -- Ditaruh PALING AKHIR. Pindah server memutus siklus di tengah jalan --
        -- seed yang sudah dibeli belum tertanam, buah yang sudah dipanen belum
        -- terjual. Setelah semua fase lain selesai, tidak ada yang hilang.
        if Config.AutoCariServerSepi then
            fase[#fase + 1] = { "server-sepi", pindahServerSepi }
        end

        -- Inventory hampir penuh -> JUAL DULU, sebelum panen.
        -- Kalau tidak, panen menembak ke kapasitas mentok, ditolak diam-diam,
        -- dan siklus berikutnya mengulang hal yang sama -- itu "stuck spam
        -- harvest" yang kamu lihat.
        local penuh = jumlahBuah() >= Config.AmbangJualBuah
        if penuh and Config.AutoJual then
            status(string.format("[PENUH] %d/%d buah — jual dulu", jumlahBuah(), kapasitasBuah()))
            fase[#fase + 1] = { "jual-awal", jual }
        end

        -- Sudah ada seed menganggur di Backpack -> TANAM DULU, sebelum apa pun.
        -- Kalau menunggu urutan normal, seed itu diam melewati panen, quest, dan
        -- jual dulu -- tanah kosong dibiarkan menganggur satu siklus penuh.
        if Config.AutoTanam then
            local bp = LocalPlayer:FindFirstChild("Backpack")
            local adaSeed = false
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") and t:GetAttribute("SeedTool") then adaSeed = true break end
                end
            end
            if adaSeed then
                fase[#fase + 1] = { "tanam-awal", function()
                    return tanamDalamAreaSprinkler(tanamSemua)
                end }
            end
        end

        -- Boost dijalankan BERTAHAP: satu langkah per siklus sampai habis.
        --
        -- Dulu seluruhnya dikerjakan sekali di siklus 1. Di satu PC itu lewat
        -- begitu saja, tapi 8-10 client start berbarengan di satu perangkat
        -- cloud dan lonjakannya bertumpuk di detik yang sama. Dengan sepuluh
        -- langkah kecil, beban yang sama tersebar ke sepuluh siklus.
        if boostBelumSelesai() then
            fase[#fase + 1] = { "fps-boost", applyFpsBoost }

        -- Kebun ORANG LAIN beda cerita: dimuat bertahap seiring pemain
        -- berdatangan. Terukur 8 pemain tapi baru 1 plot termuat, sementara
        -- Gardens menyumbang 56% dari seluruh instance workspace. Sekali jalan
        -- di siklus 1 hampir tidak membersihkan apa pun, jadi diulang berkala.
        elseif Config.SiklusBersihKebun > 0
               and putaranSiklus % Config.SiklusBersihKebun == 0 then
            fase[#fase + 1] = { "bersih-kebun", function()
                bersihkanKebunOrang(false)
                -- Diulang berkala, sama seperti kebun orang: tanaman sendiri juga
                -- bisa tumbuh kembali dari sisi server selama sesi berjalan.
                if Config.ModeBeliSaja then hancurkanKebunSendiri() end
            end }
        end

        if Config.AutoPanen then fase[#fase + 1] = { "panen", panenSemua } end

        -- Giliran kedua quest: hanya kalau tadi dilewati karena inventory kosong.
        -- Tetap sebelum "jual" supaya buah yang baru dipanen disetor dulu, bukan
        -- dijual. Tanpa penjagaan `not adaBuah`, quest akan jalan dua kali per
        -- siklus dan menembak SubmitDelivery percuma.
        if Config.AutoQuest and not adaBuah then
            fase[#fase + 1] = { "quest", questTempel }
        end

        if speedrun then
            status(string.format(
                "[SPEEDRUN] Kebun penuh & tanaman terlemah sudah rarity %d — belanja umum dilewati",
                rarityTerlemah))

            -- Target seed BERGANTI PERAN begitu ambang tercapai.
            --
            -- Di keadaan normal SeedTarget cuma urutan prioritas: seluruh stok
            -- tetap dibeli, isi target sekadar didahulukan. Setelah ambang,
            -- belanja umum berhenti -- dan di situlah target berubah jadi
            -- DAFTAR BELI, satu-satunya yang masih dibeli.
            --
            -- Gunanya menimbun. Kebun sudah penuh tanaman tinggi sehingga tidak
            -- ada lagi yang perlu digantikan, tapi seed tertentu tetap layak
            -- dikumpulkan untuk nanti. Berpasangan langsung dengan batas atas
            -- tanam: yang di atas ambang dibeli lalu ditahan di tas.
            if Config.AutoBeli and Config.BeliTargetSaatSpeedrun
               and #(Config.SeedTarget or {}) > 0 then
                fase[#fase + 1] = { "beli-target", function()
                    local mau = {}
                    for _, nm in ipairs(Config.SeedTarget) do mau[nm] = true end

                    local tersaring = {}
                    for _, s in ipairs(stokShop()) do
                        if mau[s.nama] then tersaring[#tersaring + 1] = s end
                    end

                    if #tersaring == 0 then
                        status("[TARGET] Tidak ada target seed di stok shop")
                        return 0
                    end

                    status(string.format("[TARGET] Belanja timbunan: %d jenis target",
                        #tersaring))

                    -- true = lewati penyaring "kebun penuh". Tanpa itu target
                    -- rarity rendah tersaring habis -- bambu itu Rare, dan saat
                    -- speedrun kebun sudah Legendary ke atas -- sehingga fitur
                    -- ini tidak akan pernah membeli apa pun.
                    return beli(tersaring, true)
                end }
            end
        elseif Config.ModeBeliSaja and Config.AutoBeli and #(Config.SeedTarget or {}) > 0 then
            -- Di mode ini SeedTarget adalah DAFTAR BELI, bukan urutan prioritas.
            --
            -- Belanja normal sengaja memborong seluruh stok: selama masih ada
            -- tanah kosong, seed murah sekalipun lebih untung daripada petak yang
            -- menganggur. Mode beli-saja tidak menanam apa pun, jadi alasan itu
            -- hilang seluruhnya -- yang dibeli hanya ditimbun untuk dikirim.
            -- Membeli di luar target berarti Leaves habis duluan dan jatah target
            -- terlewat sampai restock berikutnya, padahal justru itu yang diminta.
            fase[#fase + 1] = { "beli-target-saja", function()
                local mau = {}
                for _, nm in ipairs(Config.SeedTarget) do mau[nm] = true end

                local tersaring = {}
                for _, s in ipairs(stokShop()) do
                    if mau[s.nama] then tersaring[#tersaring + 1] = s end
                end

                if #tersaring == 0 then
                    status("[BELI-SAJA] Tidak ada target seed di stok shop")
                    return 0
                end

                status(string.format("[BELI-SAJA] %d dari %d jenis target ada di stok",
                    #tersaring, #Config.SeedTarget))

                -- true = lewati penyaring rarity kebun. Penyaring itu menilai seed
                -- dari apakah ia sanggup MENGGANTIKAN tanaman terlemah -- pertanyaan
                -- yang tidak berlaku di sini karena tidak ada yang ditanam. Tanpa
                -- ini, akun beli-saja yang kebunnya terlanjur Legendary tidak akan
                -- pernah membeli bambu Rare sekalipun ia satu-satunya target.
                return beli(tersaring, true)
            end }
        else
            if Config.AutoBeli then
                fase[#fase + 1] = { "beli", function()
                    local stok = stokShop()
                    if #stok > 0 then beli(stok) end
                end }
            end
            if Config.AutoTanam then
                fase[#fase + 1] = { "tanam", function()
                    return tanamDalamAreaSprinkler(tanamSemua)
                end }
            end
        end

        if Config.AutoSiram and toolBeratribut("WateringCan") then
            fase[#fase + 1] = { "siram", function() siramKebun(Config.SiramPerSiklus) end }
        end

        -- ==== AUTO TAME PET ====
        -- Dijalankan di akhir siklus. Config dikirim dari panel W1, tapi
        -- karena satu payload untuk semua akun, W2 juga ikut tame.
        if Config.AutoTame and #(Config.TamePets or {}) > 0 then
            fase[#fase + 1] = { "tame", tameSatu }
        end

        for _, f in ipairs(fase) do
            if instanceSaya ~= _G.FHInstance then break end
            local ok, err = pcall(f[2])
            if not ok then status("[ERROR] fase " .. f[1] .. ": " .. tostring(err)) end
            task.wait(Config.JedaAksi)
        end

        end)  -- tutup pcall siklus

        if not okSiklus then
            -- Dilaporkan lalu DILANJUTKAN. Siklus berikutnya membaca ulang
            -- keadaan dari nol, jadi gangguan sesaat (respawn, kebun sedang
            -- dimuat ulang, remote menolak) sembuh dengan sendirinya.
            status("[ERROR] siklus " .. putaranSiklus .. ": " .. tostring(errSiklus))
            task.wait(3)
        end

        task.wait(Config.JedaSiklus)
    end
    print("[FH] Instance #" .. instanceSaya .. " berhenti.")
end)

-- =========================================================================
-- AUTO UNFAV FRUIT BACKGROUND LOOP
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local Networking
    pcall(function() Networking = require(RS:WaitForChild("SharedModules"):WaitForChild("Networking")) end)
    local LocalPlayer = game:GetService("Players").LocalPlayer

    while task.wait(5) do
        if _G.Config and _G.Config.AutoUnfavFruit and Networking then
            local function unfavContainer(container)
                if not container then return end
                for _, item in ipairs(container:GetChildren()) do
                    local isFruit = item:GetAttribute("HarvestedFruit") == true or item:GetAttribute("FruitName") ~= nil or item:GetAttribute("Weight") ~= nil
                    if isFruit and (item:GetAttribute("IsFavorite") == true or item:GetAttribute("Favorited") == true) then
                        pcall(function()
                            Networking.Backpack.SetFruitFavorite:Fire(item.Name, false)
                        end)
                        task.wait(0.2)
                    end
                end
            end
            pcall(unfavContainer, LocalPlayer:FindFirstChild("Backpack"))
            if LocalPlayer.Character then
                pcall(unfavContainer, LocalPlayer.Character)
            end
        end
    end
end)
-- =========================================================================

-- @MOZEFRAME-EOF@ (penanda akhir berkas -- router menolak file tanpa baris ini)
