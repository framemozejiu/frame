-- Auto buy event shop (Grow a Garden) + panel pilihan & pencarian.
--
-- Beli lewat tombol milik game sendiri:
--     BuyEventShopStock:FireServer(namaItem, namaToko)
-- Tidak ada harga/jumlah yang dikirim -- server yang menentukan, jadi menembak
-- item habis itu aman (ditolak, tidak memakan apa pun).
--
-- Stok dari DATA, bukan UI toko: panel toko hanya terisi saat dibuka, jadi
-- membaca UI membuat script buta selama panel tertutup.
--     DataService:GetData().EventShopStock[toko].Stocks[item].Stock
--
-- Terverifikasi: sekali jalan memborong Night Egg x1, Twilight Crate x3,
-- Star Caller x5, Moon Melon Seed [X5], Blood Banana Seed [X2].

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LP = game:GetService("Players").LocalPlayer

local BERKAS = "gag_eventshop.json"
local BAWAAN = { ["Night Egg"] = true, ["Night"] = true }

local Remote = RS.GameEvents:FindFirstChild("BuyEventShopStock")
local DS = require(RS.Modules.DataService)
local DataToko = require(RS.Data.EventShopData)
if not Remote then
    warn("[GAG] BuyEventShopStock tidak ada - berhenti.")
    return
end

local SIMPAN = (function()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return {} end
    if not isfile(BERKAS) then return {} end
    local ok, t = pcall(function() return HttpService:JSONDecode(readfile(BERKAS)) end)
    return (ok and type(t) == "table") and t or {}
end)()

local Config = { Aktif = (SIMPAN.Aktif ~= false), JedaItem = 0.25 }
-- Boost SATU ARAH: butuh rejoin untuk pulih. Karena itu default MATI dan
-- harus dinyalakan sendiri, tidak ikut menyala cuma karena panel dibuka.
Config.Boost = (SIMPAN.Boost == true)
-- Auto terima trade. Default MATI: menyalakannya berarti akun ini menerima
-- ajakan trade tanpa dilihat orang.
Config.Tiket = (SIMPAN.Tiket == true)
-- Kosong = siapa saja. Diisi = HANYA nama itu (pisah koma) yang diterima.
Config.TiketDari = type(SIMPAN.TiketDari) == "string" and SIMPAN.TiketDari or ""
-- Dideklarasikan maju: dipakai handler tombol yang dibuat sebelum badannya ada.
-- `local function` dua kali menghasilkan DUA fungsi berbeda, dan yang dipegang
-- tombol adalah yang kosong -- setelan tidak akan pernah tersimpan.
local simpanConfig

local function ringkas(n)
    n = tonumber(n) or 0
    for _, u in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        if n >= u[1] then return string.format("%.1f%s", n / u[1], u[2]) end
    end
    return tostring(math.floor(n))
end

local function bacaStok()
    local ok, d = pcall(function() return DS:GetData() end)
    return (ok and type(d) == "table" and d.EventShopStock) or {}
end

-- =========================================================================
-- BEE EGG SHOP
--
-- Toko ini TIDAK ada di EventShopStock; stoknya di cabang datanya sendiri dan
-- belinya lewat RemoteFunction, bukan RemoteEvent. Supaya tidak perlu jalur
-- kedua di seluruh panel, ia dipasang sebagai satu "toko" semu dan semua
-- pembacaan/pembelian lewat dua fungsi kecil di bawah.
--
-- Terukur 2026-08-29 pada akun hidup:
--   BuyBeeEggStock:InvokeServer("Common Bee Egg") -> boolean true
--   stok 6 -> 5, dari jarak 92 stud
-- Jadi server TIDAK memvalidasi jarak -- bot tidak perlu didekatkan ke toko.
-- =========================================================================
local BEE = "Bee Egg Shop"
local BeeRF = (function()
    local svc = RS.GameEvents:FindFirstChild("BeeColonyEggShopService")
    return svc and svc:FindFirstChild("BuyBeeEggStock") or nil
end)()

local function bacaStokBee()
    local ok, d = pcall(function() return DS:GetData() end)
    local b = ok and type(d) == "table" and d.BeeEggShopStock
    return (type(b) == "table" and type(b.Stocks) == "table") and b.Stocks or {}
end

-- Tabel Stocks satu toko, apa pun jenisnya.
local function stoksDari(semua, toko)
    if toko == BEE then return bacaStokBee() end
    local s2 = semua[toko]
    return s2 and s2.Stocks or nil
end

-- Satu pembelian. Bee memakai InvokeServer yang MEMBALAS boolean, jadi
-- kegagalan ketahuan; event shop memakai FireServer yang diam.
local function tembakBeli(toko, nama)
    if toko == BEE then
        if not BeeRF then return false end
        local ok, r = pcall(function() return BeeRF:InvokeServer(nama) end)
        return ok and r == true
    end
    pcall(function() Remote:FireServer(nama, toko) end)
    return true
end

-- Harga & mata uang item, dari katalog. Toko tanpa katalog mengembalikan nil
-- -- dan itu ditampilkan apa adanya, bukan ditebak.
local function hargaItem(toko, item)
    local c = DataToko[toko] and DataToko[toko][item]
    if type(c) ~= "table" then return nil, nil end
    return tonumber(c.Price), tostring(c.SpecialCurrencyType or "Sheckles")
end

-- Saldo mata uang pemain.
--
-- KENAPA PENTING: terukur, item yang dicentang tapi mata uangnya NOL tidak
-- pernah terbeli dan tampak seperti script rusak. Easter Seed Shop memakai
-- ChocCoins, Moon Coin Shop MoonCoins, Royal Jelly RoyalJelly, Tide Token
-- TideTokens -- semuanya 0 di akun uji, sementara Blood Moon dan Twilight
-- memakai Sheckles dan memang berhasil.
local function saldo(mata)
    local ok, v = pcall(function()
        local d = DS:GetData()
        if mata == "Sheckles" then
            return tonumber(d.Sheckles) or tonumber(LP.leaderstats and LP.leaderstats.Sheckles
                and LP.leaderstats.Sheckles.Value) or math.huge
        end
        local sc = d.SpecialCurrency
        return tonumber(sc and sc[mata]) or 0
    end)
    return (ok and v) or 0
end

local function stok(toko, item)
    local s = bacaStok()[toko]
    local st = s and s.Stocks and s.Stocks[item]
    if type(st) == "table" then return tonumber(st.Stock) or 0 end
    return tonumber(st) or 0
end

-- Toko ditemukan SENDIRI dari data pemain, bukan ditulis tangan.
--
-- Terukur: dari 21 toko yang punya stok hidup, ENAM tidak ada sama sekali di
-- EventShopData (Creepy Critters, Devilish Decor, Ghosty Gadgets, New Years
-- Shop, Santa's Stash, Spooky Seeds). Kalau daftar item hanya diambil dari
-- EventShopData, keenam toko itu tampil kosong padahal barangnya ada. Jadi
-- item digabung dari DUA sumber:
--   * katalog EventShopData -- supaya item bisa dicentang walau sedang habis
--   * kunci Stocks          -- supaya toko tanpa katalog tetap terisi
local TOKO, Daftar, Pilih = {}, {}, {}
do
    local semua = bacaStok()
    for toko, isi in pairs(semua) do
        if toko ~= "" and type(isi) == "table" then
            local adaStok = type(isi.Stocks) == "table" and next(isi.Stocks) ~= nil
            if adaStok or DataToko[toko] then TOKO[#TOKO + 1] = toko end
        end
    end
    table.sort(TOKO)

    for _, toko in ipairs(TOKO) do
        local nama, urut = {}, {}
        for item, cfg in pairs(DataToko[toko] or {}) do
            if type(cfg) == "table" and cfg.DisplayInShop ~= false then
                nama[item] = true
                urut[item] = tonumber(cfg.LayoutOrder) or 999
            end
        end
        local s = semua[toko]
        for item in pairs((s and s.Stocks) or {}) do nama[item] = true end

        local a = {}
        for item in pairs(nama) do a[#a + 1] = { nama = item, urut = urut[item] or 999 } end
        table.sort(a, function(x, y)
            if x.urut ~= y.urut then return x.urut < y.urut end
            return x.nama < y.nama
        end)
        Daftar[toko] = a
        Pilih[toko] = {}
        for _, x in ipairs(a) do Pilih[toko][x.nama] = false end
    end

    -- Bee Egg Shop ditambahkan TERAKHIR supaya nomor "Shop N" toko lain tidak
    -- bergeser -- pilihan tersimpan pengguna dikunci pada nama toko, tapi
    -- nomor yang berubah-ubah membingungkan saat dibaca.
    if BeeRF then
        -- Toko bee tidak punya katalog, jadi daftarnya hanya bisa dari stok yang
        -- SEDANG ada. Itu masalah: item yang kebetulan habis saat script mulai
        -- tidak akan pernah muncul di panel, sehingga tidak bisa dicentang, dan
        -- restock berikutnya terlewat diam-diam.
        --
        -- Benih di bawah dua nama yang benar-benar terlihat di toko (terukur
        -- 2026-08-29). Nama toko bee TIDAK sama dengan nama di PetRegistry --
        -- registry cuma punya "Bee Egg"/"Hive Egg", bukan kedua nama ini --
        -- jadi tidak ada sumber lain untuk mengambilnya.
        local nama = { ["Common Bee Egg"] = true, ["Transcendent Bee Egg"] = true }
        for item in pairs(bacaStokBee()) do nama[item] = true end

        local a = {}
        for item in pairs(nama) do a[#a + 1] = { nama = item, urut = 999 } end
        table.sort(a, function(x, y) return x.nama < y.nama end)
        if #a > 0 then
            TOKO[#TOKO + 1] = BEE
            Daftar[BEE] = a
            Pilih[BEE] = {}
            for _, x in ipairs(a) do Pilih[BEE][x.nama] = false end
        end
    end
end

simpanConfig = function()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(BERKAS, HttpService:JSONEncode({
            Aktif = Config.Aktif, Boost = Config.Boost, Pilih = Pilih,
            Tiket = Config.Tiket, TiketDari = Config.TiketDari,
        }))
    end)
end

-- =========================================================================
-- FPS BOOST  (satu arah -- pulih hanya dengan rejoin)
--
-- Aturannya DAFTAR LINDUNG, bukan daftar buang. Melewatkan satu hiasan cuma
-- kehilangan sedikit FPS; salah menghapus bisa mematikan NPC atau toko, dan
-- itu baru ketahuan berjam-jam kemudian.
--
-- Auto buy di atas TIDAK bergantung pada objek dunia sama sekali (stok dibaca
-- dari DataService, beli lewat remote), jadi ia tetap jalan walau seluruh
-- hiasan toko dibuang.
-- =========================================================================
local sudahBoost = false

local function boostFPS()
    if sudahBoost then return "sudah pernah dijalankan" end
    sudahBoost = true

    local Lighting = game:GetService("Lighting")
    local ws = workspace
    local LINDUNGI = {
        NPCS = true, Booths = true, PhysicalEggsShop = true, GardenCoinShop = true,
        Pads = true, Click_Points = true, Crafting = true, PetAgeMachine = true,
        PlatformPositions = true, NavSectors = true, ZONES = true,
        Player_Orientation_References = true, Terrain = true, Camera = true,
        ShopRestockTimer = true, CodeRedemptionServer = true, Sprinklers = true,
    }
    -- PetsPhysical/Farm/Interaction ikut dibuang atas permintaan pemilik script:
    -- plot, titik interaksi, dan pet yang terlihat HILANG. Aman di sini karena
    -- script ini murni auto buy lewat remote; jangan salin ke script tanam/panen.
    local BUANG = {
        "BirthdayDecor", "MapDecorations", "Rainbows", "Dirt_VFX", "PetZoneAbilityVFX",
        "Visuals", "Water_Effect", "WeatherVisuals", "WeatherObjects",
        "Tutorial_Arrows", "Tutorial_Points", "SoundEffects", "Intro", "SecretObby",
        "PetsPhysical", "Farm", "Interaction",
    }

    local n = { folder = 0, part = 0, efek = 0, texture = 0, rata = 0, anim = 0 }

    if type(setfpscap) == "function" then setfpscap(0) end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Technology = Enum.Technology.Compatibility
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 1
        -- Dibuang, bukan sekadar Enabled=false: efek yang mati pun masih ikut
        -- disiapkan tiap frame.
        for _, d in ipairs(Lighting:GetDescendants()) do
            pcall(function() d:Destroy() end)
            n.efek = n.efek + 1
        end
    end)
    pcall(function()
        ws.Terrain.WaterWaveSize = 0
        ws.Terrain.WaterWaveSpeed = 0
        ws.Terrain.WaterReflectance = 0
    end)

    for _, nama in ipairs(BUANG) do
        if not LINDUNGI[nama] then
            local f = ws:FindFirstChild(nama)
            if f then
                n.folder = n.folder + 1
                pcall(function() f:Destroy() end)
            end
        end
    end

    -- Mematikan partikel/lampu tidak menghapus apa pun yang bisa diklik atau
    -- dipijak, jadi aman di mana saja -- termasuk pada NPC. Yang hilang cuma kilau.
    local buangTexture = {}
    for _, d in ipairs(ws:GetDescendants()) do
        local k = d.ClassName
        if k == "ParticleEmitter" or k == "Trail" or k == "Smoke" or k == "Fire"
           or k == "Sparkles" or k == "Beam" or k == "PointLight" or k == "SpotLight"
           or k == "SurfaceLight" then
            pcall(function() d.Enabled = false end)
            n.efek = n.efek + 1
        elseif k == "Texture" or k == "Decal" then
            buangTexture[#buangTexture + 1] = d
        end
    end
    for i, d in ipairs(buangTexture) do
        pcall(function() d:Destroy() end)
        n.texture = n.texture + 1
        -- Dicicil: menghancurkan puluhan ribu instance sekaligus membuat klien
        -- tersendat beberapa detik, dan itu terlihat seperti script menggantung.
        if i % 800 == 0 then task.wait() end
    end

    -- KOREKSI terukur 2026-08-28: tanpa penjaga ini, sapuan part MENGHAPUS
    -- HumanoidRootPart pemain sendiri -- HRP ber-CanCollide=false dan model
    -- karakter adalah anak LANGSUNG workspace, jadi ia lolos daftar lindung
    -- berbasis nama. Karakter lalu terjebak Freefall sampai reset, dengan nyawa
    -- tetap 100 -- tidak ada satu pun tanda error.
    local function makhlukHidup(m)
        if not m:IsA("Model") then return false end
        if m:FindFirstChildOfClass("Humanoid") then return true end
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.Character == m then return true end
        end
        return false
    end

    local buangPart = {}
    for _, atas in ipairs(ws:GetChildren()) do
        if not LINDUNGI[atas.Name] and atas ~= ws.Terrain and not makhlukHidup(atas) then
            for _, d in ipairs(atas:GetDescendants()) do
                -- CanCollide=false berarti menurut definisinya tidak bisa dipijak.
                -- Yang bisa dipijak TIDAK PERNAH disentuh, supaya mustahil
                -- menjatuhkan pemain lewat lantai.
                if d:IsA("BasePart") and not d.CanCollide and not d:IsA("Terrain") then
                    buangPart[#buangPart + 1] = d
                end
            end
        end
    end
    for i, d in ipairs(buangPart) do
        pcall(function() d:Destroy() end)
        n.part = n.part + 1
        if i % 500 == 0 then task.wait() end
    end

    -- RATAKAN: part tetap ada dan tetap bisa dipijak, cuma digambar polos.
    -- SurfaceGui/BillboardGui ikut dibuang: papan nama melayang itu tiap-tiap
    -- satu kanvas GUI yang digambar ulang terus-menerus.
    local ratakan = {}
    for _, d in ipairs(ws:GetDescendants()) do
        local k = d.ClassName
        if k == "SpecialMesh" or k == "BlockMesh" or k == "CylinderMesh"
           or k == "SurfaceGui" or k == "BillboardGui" or k == "ImageLabel"
           or k == "ImageButton" then
            ratakan[#ratakan + 1] = d
        elseif k == "MeshPart" then
            pcall(function()
                d.TextureID = ""
                d.Material = Enum.Material.SmoothPlastic
                d.Reflectance = 0
            end)
            n.rata = n.rata + 1
        end
    end
    for i, d in ipairs(ratakan) do
        pcall(function() d:Destroy() end)
        n.rata = n.rata + 1
        if i % 600 == 0 then task.wait() end
    end

    -- Menghentikan track yang sedang jalan saja tidak cukup: begitu apa pun
    -- bergerak, track baru dimainkan. Animator MILIK PEMAIN dilewati -- animasi
    -- diri sendiri yang beku terlihat patah dan tidak menghemat apa pun berarti.
    local function bekukan(anim)
        local induk = anim.Parent and anim.Parent.Parent
        if induk and game:GetService("Players"):GetPlayerFromCharacter(induk) then return end
        for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
            pcall(function() t:Stop(0) end)
            n.anim = n.anim + 1
        end
        anim.AnimationPlayed:Connect(function(track)
            pcall(function() track:Stop(0) end)
        end)
    end
    for _, d in ipairs(ws:GetDescendants()) do
        if d:IsA("Animator") then pcall(bekukan, d) end
    end

    -- Penjaga: streaming memasukkan hiasan kembali saat pemain bergerak.
    -- Sengaja seringan mungkin (cek ClassName saja) -- handler ini menyala
    -- ribuan kali per menit; apa pun yang lebih berat di sini justru memakan
    -- kembali FPS yang baru dihemat.
    ws.DescendantAdded:Connect(function(d)
        local k = d.ClassName
        if k == "ParticleEmitter" or k == "Trail" or k == "Beam" or k == "PointLight"
           or k == "SpotLight" or k == "SurfaceLight" or k == "Smoke" or k == "Fire" then
            pcall(function() d.Enabled = false end)
        elseif k == "Texture" or k == "Decal" then
            pcall(function() d:Destroy() end)
        elseif k == "Animator" then
            pcall(bekukan, d)
        elseif k == "SpecialMesh" or k == "SurfaceGui" or k == "BillboardGui" then
            pcall(function() d:Destroy() end)
        end
    end)

    return ("%d folder, %d part, %d efek, %d texture, %d mesh/gambar")
        :format(n.folder, n.part, n.efek, n.texture, n.rata)
end

-- =========================================================================
-- AUTO TERIMA TRADE  ("ticket")
--
-- Dipakai untuk mengoper barang dari akun utama ke akun bot: akun utama yang
-- mengajak dan mengisi barang, bot cuma menerima.
--
-- Protokol terukur langsung dari script game (2026-08-29):
--   SendRequest.OnClientEvent(id, Player pengirim, kadaluarsa)
--       -> RespondRequest:FireServer(id, true)   -- menerima ajakan
--   lalu keadaan per pemain di TradingController.CurrentTradeReplicator:
--       Data.players = {Player, Player}
--       Data.states  = {"None"|"Accepted"|"Confirmed"|"Processing"}
--       Data.lastChange = waktu server perubahan terakhir
--   Accept BUKAN toggle -- ia maju None -> Accepted, lalu Confirm -> Confirmed.
--   Server menahan tombol selama TradeData.ButtonCooldown (terukur = 5 detik)
--   sejak lastChange, jadi menembak lebih cepat dari itu percuma.
--
-- BOT TIDAK PERNAH MENARUH APA PUN. AddItem/SetSheckles/SetTokens sengaja
-- tidak dipanggil di mana pun. Itu yang membuat auto terima ini tidak bisa
-- dipakai orang lain untuk menguras akun bot: pihak lain tidak punya cara
-- memindahkan barang dari sisi kita.
-- =========================================================================
local TradeEvents = RS.GameEvents:FindFirstChild("TradeEvents")
local TradingController, TradeData
pcall(function()
    TradingController = require(RS.Modules.TradeControllers.TradingController)
    TradeData = require(RS.Data.TradeData)
end)

local COOLDOWN = (TradeData and tonumber(TradeData.ButtonCooldown)) or 5
-- Trade yang menggantung memblokir bot (game menolak aksi lain dengan
-- "Finish trading first!"), jadi ada batas waktu -- bukan menunggu selamanya.
local TIKET_BATAS = 180

local tiketMulai, tiketLawan = 0, "-"
local tiketStat = { terima = 0, tolak = 0, selesai = 0 }

-- Keputusan satu langkah trade, dipisah supaya bisa diuji tanpa game.
--   saya/lawan : "None" | "Accepted" | "Confirmed" | "Processing"
--   umur       : detik sejak Data.lastChange menurut waktu server
local function tiketAksi(saya, lawan, umur)
    -- Server menolak sebelum cooldown lewat; menembak lebih awal cuma
    -- menghabiskan remote tanpa mengubah apa pun.
    if umur < COOLDOWN then return nil end
    if saya == "None" then return "accept" end
    if saya == "Accepted" and lawan ~= "None" then
        -- Menunggu lawan keluar dari "None" itu disengaja: Confirm saat lawan
        -- belum menerima ditolak server, dan penolakan itu me-reset lastChange
        -- sehingga malah menambah 5 detik.
        return "confirm"
    end
    if saya == "Confirmed" and lawan == "Confirmed" then return "selesai" end
    -- "Processing" sengaja tidak ditangani: itu keadaan server sedang memproses.
    return nil
end

local function tiketDiizinkan(pemain)
    local saring = Config.TiketDari or ""
    if saring:gsub("%s", "") == "" then return true end
    local nama = string.lower(pemain.Name)
    for potong in string.gmatch(string.lower(saring), "[^,]+") do
        potong = potong:match("^%s*(.-)%s*$")
        if potong ~= "" and potong == nama then return true end
    end
    return false
end

if TradeEvents and TradeEvents:FindFirstChild("SendRequest") then
    TradeEvents.SendRequest.OnClientEvent:Connect(function(id, pengirim, _)
        if not Config.Tiket then return end
        if typeof(pengirim) ~= "Instance" then return end
        if not tiketDiizinkan(pengirim) then
            tiketStat.tolak = tiketStat.tolak + 1
            pcall(function() TradeEvents.RespondRequest:FireServer(id, false) end)
            return
        end
        tiketStat.terima = tiketStat.terima + 1
        tiketLawan = pengirim.Name
        tiketMulai = os.clock()
        pcall(function() TradeEvents.RespondRequest:FireServer(id, true) end)
        warn(("[GAG TIKET] terima ajakan dari %s"):format(tiketLawan))
    end)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.Tiket and TradingController then
            pcall(function()
                local rep = TradingController.CurrentTradeReplicator
                if not rep then
                    tiketMulai = 0
                    return
                end
                if tiketMulai == 0 then tiketMulai = os.clock() end

                local Data = rep:GetData()
                if not Data or not Data.players or not Data.states then return end

                local iSaya = table.find(Data.players, LP)
                if not iSaya then return end
                local iLawan = (iSaya == 1) and 2 or 1
                local saya, lawan = Data.states[iSaya], Data.states[iLawan]

                if os.clock() - tiketMulai > TIKET_BATAS then
                    TradingController:Decline()
                    tiketMulai = 0
                    warn(("[GAG TIKET] batal: %s menggantung lebih dari %d dtk")
                        :format(tiketLawan, TIKET_BATAS))
                    return
                end

                local umur = workspace:GetServerTimeNow() - (tonumber(Data.lastChange) or 0)
                local aksi = tiketAksi(saya, lawan, umur)

                if aksi == "accept" then
                    TradingController:Accept()
                elseif aksi == "confirm" then
                    TradingController:Confirm()
                elseif aksi == "selesai" then
                    tiketStat.selesai = tiketStat.selesai + 1
                    tiketMulai = 0
                    warn(("[GAG TIKET] selesai dengan %s (total %d)")
                        :format(tiketLawan, tiketStat.selesai))
                end
            end)
        end
    end
end)

-- =========================================================================
-- PANEL
-- =========================================================================
local W = {
    latar = Color3.fromRGB(20, 21, 26), kepala = Color3.fromRGB(30, 32, 40),
    kartu = Color3.fromRGB(28, 30, 37), baris = Color3.fromRGB(36, 38, 47),
    pilih = Color3.fromRGB(52, 74, 62), centang = Color3.fromRGB(96, 200, 128),
    terang = Color3.fromRGB(236, 238, 243), redup = Color3.fromRGB(138, 142, 155),
    stokNol = Color3.fromRGB(90, 94, 106),
}
local segarkan, saring = {}, ""

local function sudut(o, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = o
end

for _, induk in ipairs({ (gethui and gethui()) or nil, LP:WaitForChild("PlayerGui") }) do
    if induk then
        for _, x in ipairs(induk:GetChildren()) do
            if x.Name == "GAGShopUI" then pcall(function() x:Destroy() end) end
        end
    end
end

local sg = Instance.new("ScreenGui")
sg.Name = "GAGShopUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

local bingkai = Instance.new("Frame")
bingkai.Size = UDim2.fromOffset(290, 458)
bingkai.Position = UDim2.fromScale(0.03, 0.15)
bingkai.BackgroundColor3 = W.latar
bingkai.BorderSizePixel = 0
bingkai.Active = true
bingkai.Draggable = true
bingkai.Parent = sg
sudut(bingkai, 12)

local kepala = Instance.new("Frame")
kepala.Size = UDim2.new(1, 0, 0, 38)
kepala.BackgroundColor3 = W.kepala
kepala.BorderSizePixel = 0
kepala.Parent = bingkai
sudut(kepala, 12)

local judul = Instance.new("TextLabel")
judul.Size = UDim2.new(1, -20, 1, 0)
judul.Position = UDim2.fromOffset(14, 0)
judul.BackgroundTransparency = 1
judul.Font = Enum.Font.GothamBold
judul.TextSize = 13
judul.TextXAlignment = Enum.TextXAlignment.Left
judul.TextColor3 = W.terang
judul.Text = "Event Shop  \226\128\162  Auto Buy"
judul.Parent = kepala

local bAktif = Instance.new("TextButton")
bAktif.Size = UDim2.fromOffset(128, 28)
bAktif.Position = UDim2.fromOffset(14, 44)
bAktif.Font = Enum.Font.GothamBold
bAktif.TextSize = 12
bAktif.BorderSizePixel = 0
bAktif.Parent = bingkai
sudut(bAktif, 8)

local bBoost = Instance.new("TextButton")
bBoost.Size = UDim2.fromOffset(128, 28)
bBoost.Position = UDim2.fromOffset(148, 44)
bBoost.Font = Enum.Font.GothamBold
bBoost.TextSize = 12
bBoost.BorderSizePixel = 0
bBoost.Parent = bingkai
sudut(bBoost, 8)

local bTiket = Instance.new("TextButton")
bTiket.Size = UDim2.fromOffset(128, 28)
bTiket.Position = UDim2.fromOffset(14, 78)
bTiket.Font = Enum.Font.GothamBold
bTiket.TextSize = 12
bTiket.BorderSizePixel = 0
bTiket.Parent = bingkai
sudut(bTiket, 8)

local kotakDari = Instance.new("TextBox")
kotakDari.Size = UDim2.fromOffset(128, 28)
kotakDari.Position = UDim2.fromOffset(148, 78)
kotakDari.BackgroundColor3 = W.baris
kotakDari.BorderSizePixel = 0
kotakDari.Font = Enum.Font.Gotham
kotakDari.TextSize = 11
kotakDari.TextColor3 = W.terang
kotakDari.PlaceholderText = "  from: anyone"
kotakDari.PlaceholderColor3 = W.stokNol
kotakDari.Text = Config.TiketDari or ""
kotakDari.ClearTextOnFocus = false
kotakDari.TextXAlignment = Enum.TextXAlignment.Left
kotakDari.Parent = bingkai
sudut(kotakDari, 7)

local cari = Instance.new("TextBox")
cari.Size = UDim2.fromOffset(262, 26)
cari.Position = UDim2.fromOffset(14, 112)
cari.BackgroundColor3 = W.baris
cari.BorderSizePixel = 0
cari.Font = Enum.Font.Gotham
cari.TextSize = 11
cari.TextColor3 = W.terang
cari.PlaceholderText = "  search item / shop..."
cari.PlaceholderColor3 = W.stokNol
cari.Text = ""
cari.ClearTextOnFocus = false
cari.TextXAlignment = Enum.TextXAlignment.Left
cari.Parent = bingkai
sudut(cari, 7)

local gulir = Instance.new("ScrollingFrame")
gulir.Position = UDim2.fromOffset(12, 146)
gulir.Size = UDim2.fromOffset(266, 300)
gulir.BackgroundTransparency = 1
gulir.BorderSizePixel = 0
gulir.ScrollBarThickness = 3
gulir.ScrollBarImageColor3 = W.redup
gulir.AutomaticCanvasSize = Enum.AutomaticSize.Y
gulir.CanvasSize = UDim2.new()
gulir.Parent = bingkai
local tata = Instance.new("UIListLayout")
tata.Padding = UDim.new(0, 4)
tata.Parent = gulir

local function catAktif()
    bAktif.Text = Config.Aktif and "AUTO BUY  \226\151\143  ON" or "AUTO BUY  \226\151\139  OFF"
    bAktif.BackgroundColor3 = Config.Aktif and W.pilih or W.baris
    bAktif.TextColor3 = Config.Aktif and W.centang or W.redup
end
bAktif.Activated:Connect(function()
    Config.Aktif = not Config.Aktif
    catAktif()
    simpanConfig()
end)
catAktif()

-- Tombol ini mewakili SETELAN TERSIMPAN, bukan keadaan sesi ini.
--
-- Versi sebelumnya mengunci diri begitu boost dipasang (`if sudahBoost
-- then return end`), sehingga setelan tidak pernah bisa dikembalikan ke
-- OFF -- boost lalu menyala otomatis tiap rejoin selamanya. Yang tidak
-- bisa dibatalkan itu sapuan yang SUDAH jalan, bukan pilihannya.
local function catBoost()
    bBoost.Text = Config.Boost and "FPS BOOST  \226\151\143  ON"
        or "FPS BOOST  \226\151\139  OFF"
    bBoost.BackgroundColor3 = Config.Boost and W.pilih or W.baris
    bBoost.TextColor3 = Config.Boost and W.centang or W.redup
end

bBoost.Activated:Connect(function()
    Config.Boost = not Config.Boost
    simpanConfig()
    catBoost()

    if not Config.Boost then
        if sudahBoost then
            warn("[GAG FPS] setelan OFF disimpan. Sapuan yang sudah jalan "
                .. "di sesi ini tidak bisa dibatalkan -- berlaku setelah rejoin.")
        end
        return
    end
    if sudahBoost then return end

    bBoost.Text = "BOOSTING..."
    task.spawn(function()
        local ok, hasil = pcall(boostFPS)
        catBoost()
        warn("[GAG FPS] " .. (ok and tostring(hasil) or ("GAGAL: " .. tostring(hasil))))
    end)
end)
catBoost()

local function catTiket()
    bTiket.Text = Config.Tiket and "AUTO TICKET  \226\151\143  ON"
        or "AUTO TICKET  \226\151\139  OFF"
    bTiket.BackgroundColor3 = Config.Tiket and W.pilih or W.baris
    bTiket.TextColor3 = Config.Tiket and W.centang or W.redup
end
bTiket.Activated:Connect(function()
    Config.Tiket = not Config.Tiket
    catTiket()
    simpanConfig()
end)
kotakDari.FocusLost:Connect(function()
    Config.TiketDari = kotakDari.Text
    simpanConfig()
end)
catTiket()

for nomor, toko in ipairs(TOKO) do
    -- Label disamarkan jadi "Shop N". Nama asli tetap dipakai memanggil remote;
    -- yang disembunyikan cuma dari mata pembeli script.
    local label = "Shop " .. nomor

    local kartu = Instance.new("Frame")
    kartu.Size = UDim2.new(1, -4, 0, 24)
    kartu.BackgroundColor3 = W.kartu
    kartu.BorderSizePixel = 0
    kartu.Parent = gulir
    sudut(kartu, 7)

    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1, -70, 1, 0)
    nm.Position = UDim2.fromOffset(10, 0)
    nm.BackgroundTransparency = 1
    nm.Font = Enum.Font.GothamBold
    nm.TextSize = 11
    nm.TextXAlignment = Enum.TextXAlignment.Left
    nm.TextColor3 = W.terang
    nm.Text = label
    nm.Parent = kartu

    local bSemua = Instance.new("TextButton")
    bSemua.Size = UDim2.fromOffset(54, 17)
    bSemua.Position = UDim2.new(1, -60, 0, 4)
    bSemua.BackgroundColor3 = W.baris
    bSemua.BorderSizePixel = 0
    bSemua.Font = Enum.Font.Gotham
    bSemua.TextSize = 10
    bSemua.TextColor3 = W.redup
    bSemua.Text = "all / none"
    bSemua.Parent = kartu
    sudut(bSemua, 5)

    local segarToko = {}
    bSemua.Activated:Connect(function()
        local adaKosong = false
        for _, x in ipairs(Daftar[toko]) do
            if not Pilih[toko][x.nama] then adaKosong = true break end
        end
        for _, x in ipairs(Daftar[toko]) do Pilih[toko][x.nama] = adaKosong end
        for _, f in ipairs(segarToko) do f() end
        simpanConfig()
    end)

    for _, x in ipairs(Daftar[toko]) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -4, 0, 24)
        b.BackgroundColor3 = W.baris
        b.BorderSizePixel = 0
        b.Text = ""
        b.AutoButtonColor = false
        b.Parent = gulir
        sudut(b, 7)

        local kotak = Instance.new("Frame")
        kotak.Size = UDim2.fromOffset(13, 13)
        kotak.Position = UDim2.fromOffset(9, 6)
        kotak.BorderSizePixel = 0
        kotak.Parent = b
        sudut(kotak, 4)
        local tanda = Instance.new("TextLabel")
        tanda.Size = UDim2.fromScale(1, 1)
        tanda.BackgroundTransparency = 1
        tanda.Font = Enum.Font.GothamBold
        tanda.TextSize = 10
        tanda.TextColor3 = W.latar
        tanda.Text = ""
        tanda.Parent = kotak

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -170, 1, 0)
        lbl.Position = UDim2.fromOffset(30, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = x.nama
        lbl.Parent = b

        local hrg = Instance.new("TextLabel")
        hrg.Size = UDim2.fromOffset(84, 15)
        hrg.Position = UDim2.new(1, -134, 0, 5)
        hrg.BackgroundTransparency = 1
        hrg.Font = Enum.Font.Gotham
        hrg.TextSize = 10
        hrg.TextXAlignment = Enum.TextXAlignment.Right
        hrg.TextColor3 = W.stokNol
        hrg.Parent = b

        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.fromOffset(36, 15)
        badge.Position = UDim2.new(1, -44, 0, 5)
        badge.BorderSizePixel = 0
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 10
        badge.Parent = b
        sudut(badge, 5)

        -- Pencarian mencocokkan nama item, label "Shop N", DAN nama asli
        -- tokonya -- yang terakhir supaya masih bisa dicari walau labelnya
        -- disamarkan di layar.
        local cocok = string.lower(x.nama .. " " .. label .. " " .. toko)
        local function cat()
            local tampil = (saring == "") or (string.find(cocok, saring, 1, true) ~= nil)
            b.Visible = tampil
            if not tampil then return end
            local dipilih = Pilih[toko][x.nama]
            local s = stok(toko, x.nama)
            b.BackgroundColor3 = dipilih and W.pilih or W.baris
            kotak.BackgroundColor3 = dipilih and W.centang or W.stokNol
            tanda.Text = dipilih and "\226\156\147" or ""
            lbl.TextColor3 = dipilih and W.terang or W.redup
            badge.Text = "x" .. s
            badge.BackgroundColor3 = (s > 0) and W.centang or W.kartu
            badge.TextColor3 = (s > 0) and W.latar or W.stokNol

            -- Harga DAN mata uangnya. Kalau saldonya kurang, teksnya memerah:
            -- item yang dicentang tapi tidak pernah terbeli itu justru gejala
            -- yang paling membingungkan, dan sebabnya hampir selalu ini.
            local p, mata = hargaItem(toko, x.nama)
            if p then
                local punya = saldo(mata or "Sheckles")
                local m = tostring(mata or "?")
                hrg.Text = ringkas(p) .. " " .. string.sub(m, 1, 9)
                hrg.TextColor3 = (punya >= p) and W.redup or Color3.fromRGB(210, 96, 96)
            else
                hrg.Text = "-"
                hrg.TextColor3 = W.stokNol
            end
        end
        b.Activated:Connect(function()
            Pilih[toko][x.nama] = not Pilih[toko][x.nama]
            cat()
            simpanConfig()
        end)
        segarkan[#segarkan + 1] = cat
        segarToko[#segarToko + 1] = cat
    end

    -- Kepala toko ikut disembunyikan kalau tidak ada satu pun itemnya lolos
    -- saringan: daftar penuh judul tanpa isi lebih membingungkan daripada
    -- daftar pendek.
    segarkan[#segarkan + 1] = function()
        local ada = false
        for _, x in ipairs(Daftar[toko]) do
            local c = string.lower(x.nama .. " " .. label .. " " .. toko)
            if saring == "" or string.find(c, saring, 1, true) then ada = true break end
        end
        kartu.Visible = ada
    end
end

local function gambarUlang()
    for _, f in ipairs(segarkan) do pcall(f) end
end

cari:GetPropertyChangedSignal("Text"):Connect(function()
    saring = string.lower(cari.Text)
    gambarUlang()
end)

-- Setelan tersimpan mengalahkan centang bawaan. Dipasang SESUDAH semua baris
-- ada: waktu dipasang saat membangun daftar, centangnya cuma menempel di satu
-- toko dan sisinya bahkan berpindah antar percobaan.
local adaSimpanan = type(SIMPAN.Pilih) == "table" and next(SIMPAN.Pilih) ~= nil
for _, toko in ipairs(TOKO) do
    for _, x in ipairs(Daftar[toko]) do
        if adaSimpanan then
            local t = SIMPAN.Pilih[toko]
            Pilih[toko][x.nama] = (type(t) == "table") and (t[x.nama] == true) or false
        elseif BAWAAN[x.nama] then
            Pilih[toko][x.nama] = true
        end
    end
end
gambarUlang()

-- Penyegar stok. Sekali sedetik, bukan tiap frame: menggambar ulang ratusan
-- baris 60x sedetik memakan FPS tanpa memberi informasi baru.
task.spawn(function()
    while sg.Parent do
        task.wait(1)
        gambarUlang()
    end
end)

-- =========================================================================
-- PEMBELI
-- =========================================================================
local terakhir = {}

-- Menembak SEBANYAK stok yang terlihat, bukan satu per sapuan.
--
-- Alasannya terukur dari script lama (kaitun_main): ia menembak tiap 0,1 dtk
-- dan itu yang membuatnya kelihatan "beli 2-3 sekaligus" -- sebenarnya cuma
-- hitungan inventory yang telat menyusul, tapi lajunya memang jauh di atas
-- satu-tembakan-per-0,25-dtk. Stok langka habis dalam hitungan detik, jadi
-- laju itu yang menentukan kebagian atau tidak.
--
-- Ini BUKAN cara menembus batas stok: server tetap memvalidasi tiap tembakan
-- dan menolak yang melebihi. Menembak stok habis aman (ditolak, tidak memakan
-- apa pun) -- itu sebabnya melebihkan sedikit tidak berbahaya.
local BURST_JEDA = 0.05
local BURST_MAKS = 25
local sedangBurst = {}

local function burstBeli(toko, nama, jumlah)
    local kunci = toko .. "|" .. nama
    -- Kunci per item: Heartbeat menyala 60x/dtk dan tanpa ini tiap frame
    -- menumpuk satu coroutine burst baru untuk item yang sama.
    if sedangBurst[kunci] then return end
    sedangBurst[kunci] = true
    task.spawn(function()
        for _ = 1, jumlah do
            tembakBeli(toko, nama)
            task.wait(BURST_JEDA)
            -- Berhenti begitu stok benar-benar habis, jangan menghabiskan
            -- sisa jatah burst. Stok yang terlihat bisa BASI: kalau pemain
            -- lain memborongnya lebih dulu, meneruskan burst berarti 25
            -- penolakan beruntun -- dan penolakan beruntun itu yang pernah
            -- memicu kick di game lain, bukan pembeliannya.
            local st = stoksDari(bacaStok(), toko)
            st = st and st[nama]
            local sisa = (type(st) == "table") and (tonumber(st.Stock) or 0)
                or (tonumber(st) or 0)
            if sisa <= 0 then break end
        end
        sedangBurst[kunci] = nil
    end)
end

local function sapuBeli()
    if not Config.Aktif then return end
    local kini = os.clock()
    -- Data dibaca SEKALI per frame, bukan sekali per item: dengan 21 toko,
    -- memanggil GetData ratusan kali tiap frame itu pemborosan yang terasa.
    local semua = bacaStok()
    for _, toko in ipairs(TOKO) do
        local stoks = stoksDari(semua, toko)
        if stoks then
            for _, x in ipairs(Daftar[toko]) do
                if Pilih[toko][x.nama] then
                    local st = stoks[x.nama]
                    local sisa = (type(st) == "table") and (tonumber(st.Stock) or 0)
                        or (tonumber(st) or 0)
                    local kunci = toko .. "|" .. x.nama
                    -- Gerbangnya: tanpa stok tidak menembak sama sekali. Jeda
                    -- per item menahan ~60 tembakan sedetik untuk satu stok
                    -- yang sama sebelum server sempat memperbaruinya.
                    -- PERKETAT: harga dicek lebih dulu. Item yang mata uangnya
                    -- kurang tidak pernah terbeli, jadi menembakinya cuma
                    -- membuang lalu lintas dan menutupi item lain yang
                    -- sebenarnya terjangkau.
                    local mampu = true
                    local p, mata = hargaItem(toko, x.nama)
                    if p then mampu = saldo(mata) >= p end
                    if sisa > 0 and mampu
                       and (kini - (terakhir[kunci] or 0)) >= Config.JedaItem then
                        terakhir[kunci] = kini
                        burstBeli(toko, x.nama, math.min(sisa, BURST_MAKS))
                    end
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(sapuBeli)

-- PERKETAT: ikut dipicu saat stok BERUBAH, tidak menunggu frame berikutnya.
--
-- Stok langka habis dalam hitungan detik, dan Heartbeat baru menyapu setelah
-- data replikasi sampai. Menyambung ke sinyal jalurnya membuat tembakan
-- pertama berangkat pada saat yang sama data restock masuk.
pcall(function()
    local sig = DS:GetPathSignal("EventShopStock/@")
    if sig then sig:Connect(sapuBeli) end
end)

-- =========================================================================
-- ANTI AFK
--
-- Yang dipakai GERAKAN mouse, bukan tombol: gerakan tidak menekan apa pun,
-- sedangkan SendKeyEvent bisa memicu hotkey game tanpa sengaja.
-- =========================================================================
pcall(function()
    local vim = game:GetService("VirtualInputManager")
    LP.Idled:Connect(function()
        pcall(function()
            vim:SendMouseMoveEvent(math.random(120, 320), math.random(120, 320), game)
        end)
    end)
end)

-- Boost dipasang ulang otomatis HANYA kalau pernah dinyalakan sendiri di sesi
-- sebelumnya. Ditunda sampai dunia selesai dimuat: menyapu terlalu dini membuat
-- hiasan yang belum sempat replikasi lolos, dan boost jadi terlihat lemah.
if Config.Boost then
    task.spawn(function()
        task.wait(6)
        local ok, hasil = pcall(boostFPS)
        pcall(catBoost)
        warn("[GAG FPS] otomatis - " .. (ok and tostring(hasil) or ("GAGAL: " .. tostring(hasil))))
    end)
end

print(("[GAG] panel siap. %d toko, setelan %s. Boost %s. Anti-AFK aktif."):format(#TOKO,
    adaSimpanan and "dimuat dari berkas" or "bawaan",
    Config.Boost and "ON (otomatis)" or "OFF"))

-- @MOZEFRAME-EOF@
