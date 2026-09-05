--[[
=============================================================================
  MOZEFRAME MARKET  --  Grow a Garden: Trade World  (place 129954712878723)
=============================================================================

  Auto klaim booth, pilih skin stall, listing pet borongan, dan hop server
  saat dagangan tidak laku.

  SEMUA protokol di bawah dibaca langsung dari script game yang terdekompilasi
  di server hidup (job 3db34852, PlaceVersion 207) -- bukan tebakan. Yang belum
  terukur ditandai terang-terangan, supaya tidak ada yang mengira sudah
  terbukti padahal belum.

  RINGKASAN PROTOKOL
    Booths.ClaimBooth:FireServer(modelBooth)            -- RemoteEvent, TANPA balasan
    Booths.RemoveBooth:FireServer()                     -- RemoteEvent
    Booths.CreateListing:InvokeServer(tipe, id, harga)  -> boolean
    Booths.RemoveListing:InvokeServer(listingUUID)      -> boolean
    TradeBoothSkinService.Equip:FireServer(kunciSkin)   -- RemoteEvent

  TIGA JEBAKAN YANG SUDAH MEMAKAN WAKTU SAAT RISET -- jangan diulang:

  1. UUID pet itu KUNCI TABEL, bukan field .UUID.
     Field `UUID` cuma ada di 58 dari 78 pet pada akun uji. Memakai entry.UUID
     membuat 20 pet hilang diam-diam dari daftar. buildInventory milik game
     sendiri memakai kunci iterasi, bukan field itu.

  2. ClaimBooth tidak punya nilai balik.
     Ia RemoteEvent. Gagal = SUNYI. Jadi tiap klaim WAJIB diverifikasi dengan
     membaca ulang Booths[uuid].Owner, bukan dianggap sukses.

  3. GetRAP() cuma membaca cache.
     Panggilan pertama SELALU nil, lalu ia menembak server lewat task.defer.
     Yang benar GetRAPAsync(). Cache 60 detik, dan ItemId-nya berbentuk
     "Pet-<Tipe>-<Mutasi>-T<tier>" sehingga satu RAP dipakai banyak pet --
     78 pet biasanya cuma butuh belasan permintaan.

  SOAL ANTI-CHEAT
     ReplicatedFirst.NameCallDetection ADA, tapi Enabled = false (terukur). Ia
     mendeteksi hook namecall lewat debug.info; script ini tidak meng-hook apa
     pun jadi tidak relevan. Perpindahan karakter memakai jalur milik game
     sendiri (Modules.TeleportPlayer) yang melapor ke server lewat
     PlayerTeleportTriggered, persis seperti tombol teleport bawaan.

  YANG BELUM TERUKUR (jangan diklaim sebagai fakta):
     - apakah server menuntut jarak <= 8 stud saat klaim (prompt 8 stud itu
       buatan client). Script tetap mendekat dulu, karena murah dan aman.
     - apakah server menolak pet favorit / ter-equip / kena trade lock.
     - laju maksimum CreateListing per detik.
     - batas 51 listing: itu angka SEBARAN dari 220 pemain di satu server,
       bukan konstanta yang terbaca di client.
=============================================================================
]]

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local TeleportSvc = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local WS          = game:GetService("Workspace")
local LP          = Players.LocalPlayer
local PlayerGui   = LP:WaitForChild("PlayerGui")

local GUI_NAME = "MozeframeMarketGUI"

-- =========================================================================
-- LETAK CONFIG  --  satu berkas PER AKUN
--
--     mozeframe/grow a garden 1/market/<username>/config.json
--
-- Sebelumnya semua akun berbagi satu berkas di akar workspace executor, jadi
-- akun kedua di HP yang sama menimpa setelan akun pertama tanpa tanda apa pun.
-- Nama akun dipakai apa adanya: username Roblox hanya huruf, angka, dan garis
-- bawah, jadi aman sebagai nama folder.
-- =========================================================================
local DIR_AKAR  = "mozeframe"
local DIR_GAME  = DIR_AKAR .. "/grow a garden 1"
local DIR_FITUR = DIR_GAME .. "/market"
local DIR_AKUN  = DIR_FITUR .. "/" .. LP.Name
local BERKAS    = DIR_AKUN .. "/config.json"
local BERKAS_LAMA = "mozeframe_market.json"

-- Tiap tingkat dibuat terpisah: makefolder pada jalur bertingkat tidak
-- membuat induknya sendiri di sebagian executor.
local function siapkanFolder()
    if type(makefolder) ~= "function" then return false end
    for _, d in ipairs({ DIR_AKAR, DIR_GAME, DIR_FITUR, DIR_AKUN }) do
        local ada = (type(isfolder) == "function") and isfolder(d)
        if not ada then pcall(makefolder, d) end
    end
    return true
end
siapkanFolder()

-- Batas keras server yang terbaca di client: math.clamp(harga, 1, 100000000).
local HARGA_MAKS   = 100000000
-- Plafon listing terukur dari sebaran pemain, BUKAN konstanta client.
local LISTING_MAKS = 51

-- URL yang diantre saat hop. Kosong = setelah pindah server script tidak hidup
-- lagi dan harus dijalankan manual.
local URL_ANTREAN = (getgenv and getgenv().MozeMarketURL) or ""

-- =========================================================================
-- GERBANG TEMPAT
-- Booth cuma ada di Trade World. Menjalankan sisanya di place lain hanya
-- menghasilkan error beruntun yang menuduh script padahal salah tempat.
-- =========================================================================
local TWFolder = WS:FindFirstChild("TradeWorld")
local BoothsFolder = TWFolder and TWFolder:FindFirstChild("Booths")
if not BoothsFolder then
    warn("[MARKET] Workspace.TradeWorld.Booths missing -- this is not Trade World. Stopping.")
    return
end

if PlayerGui:FindFirstChild(GUI_NAME) then PlayerGui[GUI_NAME]:Destroy() end

-- =========================================================================
-- MODUL GAME
-- Semua di-pcall: satu modul yang berpindah nama tidak boleh mematikan
-- seluruh tool. Yang gagal dicatat, fiturnya saja yang mati.
-- =========================================================================
local M = {}
local function ambilModul(nama, ambil)
    local ok, hasil = pcall(ambil)
    if ok and hasil then M[nama] = hasil else warn("[MARKET] module failed: " .. nama) end
end

ambilModul("Data",    function() return require(RS.Modules.DataService) end)
ambilModul("Rep",     function() return require(RS.Modules.ReplicationReciever) end)
ambilModul("Booth",   function() return require(RS.Data.TradeBoothsData) end)
ambilModul("SkinReg", function() return require(RS.Data.TradeBoothSkinRegistry) end)
ambilModul("PetUtil", function() return require(RS.Modules.PetServices.PetUtilities) end)
ambilModul("Mutasi",  function() return require(RS.Data.PetRegistry.PetMutationRegistry) end)
ambilModul("RAP",     function() return require(RS.Modules.TradeTokens.TokenRAPController) end)
ambilModul("Pindah",  function() return require(RS.Modules.TeleportPlayer) end)
ambilModul("Trade",   function() return require(RS.Modules.TradeControllers.TradingController) end)

local Remote = {}
do
    local ok = pcall(function()
        local B = RS.GameEvents.TradeEvents.Booths
        Remote.Buat    = B.CreateListing
        Remote.Hapus   = B.RemoveListing
        Remote.Klaim   = B.ClaimBooth
        Remote.Lepas   = B.RemoveBooth
        Remote.Riwayat = B.AddToHistory
        Remote.Beli    = B.BuyListing
        Remote.Skin    = RS.GameEvents.TradeBoothSkinService.Equip
        local T = RS.GameEvents.TradeEvents
        Remote.ReqMasuk = T.SendRequest      -- OnClientEvent saat ada yang mengajak
        Remote.JawabReq = T.RespondRequest   -- FireServer(id, terima:boolean)
    end)
    if not ok then
        warn("[MARKET] booth remotes incomplete -- stopping.")
        return
    end
end

-- =========================================================================
-- CONFIG  (auto simpan)
-- =========================================================================
local SIMPANAN = (function()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return {} end

    local function baca(jalur)
        if not isfile(jalur) then return nil end
        local ok, t = pcall(function() return HttpService:JSONDecode(readfile(jalur)) end)
        return (ok and type(t) == "table") and t or nil
    end

    local baru = baca(BERKAS)
    if baru then return baru end

    -- Pindahan sekali jalan dari letak lama. Berkas lamanya sengaja TIDAK
    -- dihapus: itu datamu, dan kalau pemindahan ini ternyata salah, tidak ada
    -- jalan kembali kalau sudah dibuang.
    local lama = baca(BERKAS_LAMA)
    if lama then
        warn("[MARKET] settings moved to " .. BERKAS)
        return lama
    end
    return {}
end)()

-- Semua otomatis DEFAULT MATI. Fitur yang menyentuh dunia luar (klaim, listing,
-- hop) tidak boleh menyala cuma karena panel dibuka.
local Cfg = {
    AutoKlaim   = SIMPANAN.AutoKlaim == true,
    AutoListing = SIMPANAN.AutoListing == true,
    AutoHop     = SIMPANAN.AutoHop == true,

    Skin        = type(SIMPANAN.Skin) == "string" and SIMPANAN.Skin or "Default",

    -- Hop dijalankan hanya bila DUA syarat terpenuhi sekaligus: sudah sekian
    -- menit tak ada yang membeli DAN server ini memang sepi.
    MenitSepi   = tonumber(SIMPANAN.MenitSepi) or 10,
    BatasSepi   = tonumber(SIMPANAN.BatasSepi) or 15,
    MinTujuan   = tonumber(SIMPANAN.MinTujuan) or 20,

    -- Laju yang diterima server BELUM TERUKUR, jadi jedanya sengaja longgar.
    JedaListing = tonumber(SIMPANAN.JedaListing) or 0.6,

    -- SAKLAR HARGA. Hidup = harga dihitung dari RAP x pengali saat listing
    -- dibuat; mati = pakai angka yang kamu ketik sendiri.
    --
    -- Dulu ini tombol "pakai RAP" yang MENIMPA harga manual ke dalam config,
    -- dan itu penyebab keluhan "sudah set 500 tapi tetap ikut RAP": angka
    -- manualnya memang sudah tertimpa dan tidak ada jejaknya. Sebagai saklar,
    -- harga manual tetap tersimpan utuh dan tinggal dipakai lagi begitu
    -- saklarnya dimatikan.
    PakaiRAP    = SIMPANAN.PakaiRAP == true,
    PengaliRAP  = tonumber(SIMPANAN.PengaliRAP) or 1.2,
    SembunyiFav = SIMPANAN.SembunyiFav == true,

    -- Batas bawaan per jenis kalau barisnya tidak menuliskan "x<jumlah>".
    -- 0 = ambil semua yang lolos saringan.
    MaksPerJenis = tonumber(SIMPANAN.MaksPerJenis) or 0,

    -- PENGAMAN MODE PER NAMA.
    -- Menjual borongan berdasarkan nama itu buta: satu Bald Eagle 12 kg
    -- bermutasi Nightmare berharga jauh di atas Bald Eagle polos 2 kg, tapi
    -- namanya sama persis. Dua saringan ini yang menahannya.
    --   MaksBerat 0 = tidak dibatasi.
    --   AbaikanMutasi default HIDUP: salah menjual pet mutasi tidak bisa
    --   dibatalkan, sedangkan salah menahannya cuma tertunda.
    MaksBerat     = tonumber(SIMPANAN.MaksBerat) or 0,
    AbaikanMutasi = SIMPANAN.AbaikanMutasi ~= false,

    -- Webhook Discord milik pemakai sendiri. URL itu RAHASIA: siapa pun yang
    -- memegangnya bisa mengirim pesan ke channel itu, jadi ia tidak pernah
    -- dicetak utuh ke log dan di layar hanya ditampilkan ekornya.
    Webhook      = type(SIMPANAN.Webhook) == "string" and SIMPANAN.Webhook or "",
    WebhookAktif = SIMPANAN.WebhookAktif == true,

    -- FPS boost SATU ARAH: pulih hanya dengan rejoin. Karena itu default MATI.
    BoostFPS     = SIMPANAN.BoostFPS == true,
    -- 0 = tanpa batas. Selain itu minimal 5 -- di bawah itu game praktis
    -- berhenti menggambar dan tombol pun jadi sulit ditekan.
    CapFPS       = tonumber(SIMPANAN.CapFPS) or 0,

    -- SNIPE. Default MATI: ini satu-satunya fitur yang MEMBELANJAKAN token
    -- sendiri tanpa diminta lagi.
    SnipeAktif   = SIMPANAN.SnipeAktif == true,
    SnipePet     = type(SIMPANAN.SnipePet) == "table" and SIMPANAN.SnipePet or {},
    SnipeHarga   = tonumber(SIMPANAN.SnipeHarga) or 0,
    SnipeMinKg   = tonumber(SIMPANAN.SnipeMinKg) or 0,
    SnipeMinAge  = tonumber(SIMPANAN.SnipeMinAge) or 0,
    -- Dulu satu string dipisah koma, sekarang tabel {[nama]=true} karena
    -- dipilih lewat dropdown. Bentuk lama tetap dibaca supaya setelan yang
    -- sudah diisi tidak hilang saat update.
    SnipeMutasi  = (function()
        local v = SIMPANAN.SnipeMutasi
        if type(v) == "table" then return v end
        local t = {}
        if type(v) == "string" then
            for b in string.gmatch(v, "[^,]+") do
                b = string.gsub(string.gsub(b, "^%s+", ""), "%s+$", "")
                if b ~= "" then t[b] = true end
            end
        end
        return t
    end)(),
    -- 0 = tanpa batas. Rem darurat kalau saringan ternyata terlalu longgar.
    SnipeBatas   = tonumber(SIMPANAN.SnipeBatas) or 0,

    -- Auto terima ajakan trade. Default MATI: menyalakannya berarti akun ini
    -- menerima ajakan tanpa dilihat orang.
    AutoTrade    = SIMPANAN.AutoTrade == true,
    -- Kosong = siapa saja. Diisi = HANYA nama itu (pisah koma).
    TradeDari    = type(SIMPANAN.TradeDari) == "string" and SIMPANAN.TradeDari or "",
    -- Jeda sebelum menjawab, supaya tidak terlihat seperti balasan mesin.
    JedaTrade    = tonumber(SIMPANAN.JedaTrade) or 2,

    -- Mode per nama punya penyimpanan sendiri supaya berpindah mode tidak
    -- menghapus pilihan yang sudah disusun di mode satunya.
    PilihNama  = type(SIMPANAN.PilihNama) == "table" and SIMPANAN.PilihNama or {},
    JumlahNama = type(SIMPANAN.JumlahNama) == "table" and SIMPANAN.JumlahNama or {},
    HargaNama  = type(SIMPANAN.HargaNama) == "table" and SIMPANAN.HargaNama or {},
}

-- Diisi GUI. Dipanggil SEKALI per penulisan sungguhan, bukan per perubahan --
-- kalau tiap ketukan slider memunculkan notifikasi, layar penuh dan notifikasi
-- itu justru jadi tidak terbaca.
local sesudahSimpan

-- Sisa kunci dari mode per-pet yang sudah dihapus. Dibiarkan, ia tetap ikut
-- tertulis tiap simpan (config akun uji sempat menyimpan 67 entri Pilih yang
-- tidak lagi berarti apa-apa) dan membuat isi berkas menyesatkan saat dibaca
-- orang untuk mendiagnosis.
SIMPANAN.Harga, SIMPANAN.Pilih, SIMPANAN.ModeNama = nil, nil, nil

local simpanTertunda = false
local function simpanConfig()
    if type(writefile) ~= "function" then return end
    if simpanTertunda then return end
    simpanTertunda = true
    -- Ditunda: mengetik di kotak harga memicu puluhan perubahan beruntun, dan
    -- menulis berkas tiap ketukan bikin tersendat di emulator.
    task.delay(1, function()
        simpanTertunda = false
        local ok = pcall(function()
            siapkanFolder()
            writefile(BERKAS, HttpService:JSONEncode(Cfg))
        end)
        if sesudahSimpan then pcall(sesudahSimpan, ok) end
    end)
end

-- =========================================================================
-- UTIL
-- =========================================================================
local function ringkas(n)
    n = tonumber(n) or 0
    local satuan = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, u in ipairs(satuan) do
        if n >= u[1] then return string.format("%.2f%s", n / u[1], u[2]) end
    end
    return tostring(math.floor(n))
end

-- Menerima "250k", "1.5m", "1,000", "2.500.000". Dipakai semua kotak harga.
--
-- PEMISAH RIBUAN vs TITIK DESIMAL -- ini pernah salah dan akibatnya mahal:
-- versi pertama mengubah semua koma jadi titik, sehingga "1,000" terbaca 1.0
-- lalu di-floor jadi HARGA 1 TOKEN. Pet dijual seharga satu token tanpa pesan
-- apa pun. Aturan sekarang:
--   * koma yang diikuti tepat 3 angka        -> ribuan, dibuang
--   * titik yang diikuti tepat 3 angka DAN
--     tidak ada sufiks K/M/B/T               -> ribuan, dibuang
--   * sisanya                                -> titik desimal
-- Harga itu bilangan bulat (server mem-floor), jadi "2.500" hampir pasti
-- berarti 2500, bukan 2,5. Desimal baru masuk akal bila ada sufiks: "1.5m".
local function uraiAngka(teks)
    if type(teks) ~= "string" then return nil end
    local t = string.gsub(string.upper(teks), "%s", "")

    local kali = 1
    if string.find(t, "K") then kali = 1e3
    elseif string.find(t, "M") then kali = 1e6
    elseif string.find(t, "B") then kali = 1e9
    elseif string.find(t, "T") then kali = 1e12 end
    local adaSufiks = kali > 1

    -- Dilakukan berulang: gsub tidak menumpuk, jadi "1,000,000" butuh dua putaran.
    local n = 1
    while n > 0 do t, n = string.gsub(t, "(%d),(%d%d%d)", "%1%2") end
    if not adaSufiks then
        n = 1
        while n > 0 do t, n = string.gsub(t, "(%d)%.(%d%d%d)", "%1%2") end
    end
    t = string.gsub(t, ",", ".")

    local angka = tonumber((string.gsub(t, "[^%d%.]", "")))
    if not angka then return nil end
    return math.floor(angka * kali)
end

-- Server meng-clamp 1..100.000.000. Dilakukan juga di sini supaya angka yang
-- TAMPIL sama dengan yang benar-benar dikirim -- selisih diam-diam antara
-- keduanya itu yang bikin orang mengira harganya salah tersimpan.
local function rapikanHarga(n)
    n = tonumber(n) or 1
    return math.clamp(math.floor(n), 1, HARGA_MAKS)
end

local tulisLog     -- diisi setelah GUI berdiri
local kabarTrade = function() end   -- diganti GUI
local kabarSnipe = function() end   -- diganti GUI
local function catat(pesan, warna)
    if tulisLog then tulisLog(pesan, warna) else print("[MARKET] " .. tostring(pesan)) end
end

-- =========================================================================
-- LAPISAN DATA
--
-- DUA sumber, dan keduanya BEDA cara baca -- ini pernah tertukar saat riset:
--   profil()    -> DataService:GetData()          (punya sendiri, sinkron)
--   dataBooth() -> ReplicationReciever "Booths"   (milik dunia, perlu Async)
--
-- ReplicationReciever:GetData() mengembalikan nil sampai channel-nya di-init
-- oleh DataStream. Game sendiri selalu memakai GetDataAsync (TradeBoothController
-- baris 633). Kalau memakai GetData terlalu dini, booth sendiri terbaca "tidak
-- punya" dan script akan melepas/klaim di atas asumsi yang salah.
--
-- GetDataAsync TANPA argumen menunggu SELAMANYA (1/0 detik), jadi timeout wajib.
-- =========================================================================
local boothCh
local function dataBooth(paksaAsync)
    if not M.Rep then return nil end
    if not boothCh then
        local ok, ch = pcall(function() return M.Rep.new("Booths") end)
        if not ok then return nil end
        boothCh = ch
    end
    -- JANGAN pernah memanggil boothCh:Destroy(): registry-nya dipakai bersama
    -- seluruh game (u1[nama] = nil), dan itu mematikan UI booth bawaan.
    if not paksaAsync then
        local ok, d = pcall(function() return boothCh:GetData() end)
        if ok and d then return d end
    end
    local ok2, d2 = pcall(function() return boothCh:GetDataAsync(10) end)
    return (ok2 and d2) or nil
end

local function profil()
    if not M.Data then return nil end
    local ok, d = pcall(function() return M.Data:GetData() end)
    return (ok and d) or nil
end

local function idSaya()
    if M.Booth and M.Booth.getPlayerId then
        local ok, v = pcall(function() return M.Booth.getPlayerId(LP) end)
        if ok and v then return v end
    end
    return "Player_" .. tostring(LP.UserId)
end

-- =========================================================================
-- BOOTH
-- =========================================================================
local function boothSaya(d)
    d = d or dataBooth()
    if not d or not d.Players then return nil, d end
    local rec = d.Players[idSaya()]
    return (rec and rec.Booth) or nil, d
end

local function hitungBooth(d)
    d = d or dataBooth()
    local kosong, terisi = 0, 0
    if d and d.Booths then
        for _, rec in pairs(d.Booths) do
            if rec and rec.Owner then terisi = terisi + 1 else kosong = kosong + 1 end
        end
    end
    return kosong, terisi
end

-- Prompt "Claim" dipasang client di part ber-tag TradeBoothSign, pada Attachment
-- ber-offset. Titik itu -- bukan pivot model -- yang jaraknya diukur, jadi ke
-- sanalah kita mendekat.
local function titikBooth(model)
    local prompt
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then prompt = d break end
    end
    if prompt and prompt.Parent and prompt.Parent:IsA("Attachment") then
        return prompt.Parent.WorldPosition
    end
    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
        return prompt.Parent.Position
    end
    local ok, cf = pcall(function() return model:GetPivot() end)
    return ok and cf.Position or nil
end

-- Titik acuan "depan".
--
-- Dulu memakai rata-rata part di TradeWorld.Spawns. Terukur 2026-09-03:
-- folder itu BISA KOSONG (isiSpawns = {}), dan waktu kosong titikUtama
-- mengembalikan nil sehingga pemilihan booth diam-diam kembali acak -- persis
-- keluhan "masih ngambil yang belakang". Gejalanya sunyi karena nil itu jalur
-- cadangan yang sah, bukan error.
--
-- Sekarang acuannya dihitung dari booth itu sendiri: titik tengah seluruh
-- prompt booth. Ke-30 booth selalu punya prompt (terukur 30/30), jadi acuan
-- ini tidak bisa hilang karena folder yang dikosongkan atau diganti nama.
-- Terukur di server hidup: jarak dari titik itu min=75, median=80, max=115 --
-- dua cincin terpisah bersih.
local pusatCache, pusatSudah = nil, false
local function titikUtama()
    if pusatSudah then return pusatCache end
    pusatSudah = true
    local jml, n = Vector3.new(0, 0, 0), 0
    for _, m in ipairs(BoothsFolder:GetChildren()) do
        local t = titikBooth(m)
        if t then
            jml = jml + t
            n = n + 1
        end
    end
    if n < 4 then
        catat("booth anchor unavailable (" .. n .. " found) -- picking at random")
        return nil
    end
    pusatCache = jml / n
    return pusatCache
end

local function hrp()
    local kar = LP.Character
    return kar and kar:FindFirstChild("HumanoidRootPart")
end

-- Memakai jalur pindah milik game (PivotTo + lapor PlayerTeleportTriggered).
-- Menulis CFrame sendiri akan melewatkan laporan itu, dan itu perbedaan yang
-- tidak perlu kita ambil risikonya.
local function dekati(model)
    local titik = titikBooth(model)
    if not titik then return false, "booth anchor point not found" end
    if not M.Pindah then return false, "TeleportPlayer module missing" end

    local akar = hrp()
    if not akar then return false, "character not spawned yet" end
    if (akar.Position - titik).Magnitude <= 8 then return true end

    -- 3 stud ke samping dan 3 ke atas: cukup dekat untuk prompt 8 stud, tapi
    -- tidak menimpa geometri stall.
    local tujuan = CFrame.new(titik + Vector3.new(0, 3, 3))
    local ok = pcall(function() M.Pindah(LP, tujuan, "Booth") end)
    if not ok then return false, "move was rejected" end

    for _ = 1, 20 do
        task.wait(0.1)
        local a = hrp()
        if a and (a.Position - titik).Magnitude <= 8 then return true end
    end
    local a = hrp()
    local jarak = a and math.floor((a.Position - titik).Magnitude) or -1
    return false, "still " .. jarak .. " studs away"
end

local function lepasBooth()
    local punya = boothSaya()
    if not punya then return false, "you do not own a booth" end
    pcall(function() Remote.Lepas:FireServer() end)
    for _ = 1, 16 do
        task.wait(0.25)
        if not boothSaya(dataBooth(true)) then return true end
    end
    return false, "server did not release the booth"
end

-- Mengembalikan (berhasil, keterangan). Verifikasi WAJIB: ClaimBooth itu
-- RemoteEvent tanpa balasan, jadi satu-satunya bukti sukses adalah Owner
-- berubah di data replikasi.
local function klaimBooth()
    local d = dataBooth(true)
    if not d or not d.Booths then return false, "booth data has not arrived yet" end

    local punya = boothSaya(d)
    if punya then return true, "already own booth " .. string.sub(punya, 1, 8) end

    local aku = idSaya()
    local pusat = titikUtama()
    local kandidat = {}
    for _, model in ipairs(BoothsFolder:GetChildren()) do
        local rec = d.Booths[model.Name]
        -- Booth kosong = tabel KOSONG, bukan entri yang hilang. Keduanya
        -- diperlakukan sama supaya tidak bergantung pada bentuk itu.
        if (not rec) or rec.Owner == nil then
            local jarak = 0
            if pusat then
                local t = titikBooth(model)
                jarak = t and (t - pusat).Magnitude or math.huge
            end
            kandidat[#kandidat + 1] = { model = model, jarak = jarak }
        end
    end
    if #kandidat == 0 then return false, "all 30 booths are taken" end

    -- UTAMAKAN YANG DEKAT TITIK SPAWN.
    --
    -- Terukur di server hidup: booth membentuk DUA CINCIN dari titik spawn --
    -- 15 booth di 80-82 stud dan 15 lagi di 120-122 stud. Pembeli mendarat di
    -- spawn, jadi cincin belakang jauh lebih jarang dilewati. Versi lama
    -- memilih acak dari seluruh 30, sehingga separuh waktu mendarat di
    -- belakang padahal depan masih ada.
    table.sort(kandidat, function(a, b) return a.jarak < b.jarak end)

    -- Acak DI DALAM cincin terdepan saja (selisih dalam satu cincin cuma ~3
    -- stud, cincin berikutnya lompat ke 120). Kalau tidak diacak sama sekali,
    -- semua akun membaca daftar yang sama lalu menyerbu booth yang persis
    -- sama, dan hanya satu yang dapat.
    local terdekat = kandidat[1].jarak
    local sering = 0
    for _, k in ipairs(kandidat) do
        if k.jarak <= terdekat + 8 then sering = sering + 1 end
    end
    local model = kandidat[math.random(1, sering)].model

    local dekat, alasanDekat = dekati(model)
    if not dekat then return false, "could not get close: " .. tostring(alasanDekat) end

    pcall(function() Remote.Klaim:FireServer(model) end)

    for _ = 1, 20 do
        task.wait(0.25)
        local dd = dataBooth(true)
        local rec = dd and dd.Booths and dd.Booths[model.Name]
        if rec and rec.Owner == aku then
            return true, "claimed booth " .. string.sub(model.Name, 1, 8)
        end
    end
    return false, "server never confirmed the claim (someone else grabbed it?)"
end

-- =========================================================================
-- SKIN STALL
--
-- Equip terpisah dari klaim: ClaimBooth tidak membawa data skin sama sekali.
-- "Wooden Stall" = kunci "Default" (string), bukan nil -- server memang
-- menyimpan string "Default" pada booth yang diklaim tanpa skin lain.
-- =========================================================================
local function skinDimiliki()
    local daftar = { { kunci = "Default", nama = "Wooden Stall", punya = true } }
    local d = profil()
    local milik = d and d.TradeBoothSkinData and d.TradeBoothSkinData.OwnedSkins or {}
    local reg = M.SkinReg or {}
    for kunci, info in pairs(reg) do
        if kunci ~= "Default" then
            local v = milik[kunci]
            -- Nilainya bisa boolean ATAU angka (stack). Jangan anggap selalu true.
            local punya = (v ~= nil) and (v ~= false) and (v ~= 0)
            if punya or not info.HiddenByDefault then
                daftar[#daftar + 1] = {
                    kunci = kunci,
                    nama  = info.DisplayName or kunci,
                    rarity = info.Rarity or "?",
                    punya = punya,
                }
            end
        end
    end
    table.sort(daftar, function(a, b)
        if a.punya ~= b.punya then return a.punya end
        return a.nama < b.nama
    end)
    return daftar
end

local function skinAktif()
    local d = profil()
    return (d and d.TradeBoothSkinData and d.TradeBoothSkinData.CurrentSkin) or "Default"
end

local function pasangSkin(kunci)
    pcall(function() Remote.Skin:FireServer(kunci) end)
    for _ = 1, 12 do
        task.wait(0.2)
        if skinAktif() == kunci then return true end
    end
    -- Gate kepemilikan di game cuma ada di client, jadi skin yang tidak dimiliki
    -- kemungkinan besar ditolak diam-diam oleh server. Tidak diklaim pasti.
    return false
end

-- =========================================================================
-- INVENTARIS PET + RAP
-- =========================================================================
local RAPCache = {}   -- [itemId] = angka
local Daftar   = {}   -- hasil pindaian terakhir

local function namaMutasi(kode)
    if not kode then return nil end
    local reg = M.Mutasi and M.Mutasi.EnumToPetMutation
    -- PEKA HURUF BESAR-KECIL: "a"=Shocked tapi "A"=Nightmare. Jangan :lower().
    return (reg and reg[kode]) or kode
end

local function beratPet(pd)
    if not (M.PetUtil and pd) then return nil end
    local ok, w = pcall(function()
        return M.PetUtil:CalculateWeight(pd.BaseWeight, pd.Level)
    end)
    return ok and w or nil
end

local function pindaiPet()
    local d = profil()
    Daftar = {}
    if not d or not d.PetsData or not d.PetsData.PetInventory then return Daftar end

    -- Item yang SUDAH ter-listing disaring keluar, sama seperti FilterItems
    -- milik game. Tanpa ini pet yang sudah dijual tetap muncul dan setiap
    -- percobaan listing ulang ditolak server.
    local sudah = {}
    local td = d.TradeData or {}
    for _, l in pairs(td.Listings or {}) do
        if l and l.ItemId then sudah[l.ItemId] = true end
    end
    local kunci = (td.TradeLocks and td.TradeLocks.Pet) or {}
    local ritual = d.SummerFireEventData and d.SummerFireEventData.RitualPet

    for uuid, e in pairs(d.PetsData.PetInventory.Data or {}) do
        -- uuid = KUNCI TABEL. Bukan e.UUID -- field itu cuma ada di sebagian pet.
        if not sudah[uuid] and uuid ~= ritual then
            local pd = e.PetData or {}
            Daftar[#Daftar + 1] = {
                id      = uuid,
                tipe    = "Pet",
                entri   = e,
                nama    = e.PetType or "?",
                level   = pd.Level,
                berat   = beratPet(pd),
                mutasi  = namaMutasi(pd.MutationType),
                -- IsFavorite OPSIONAL: ada di sebagian pet saja. Memakai
                -- `== false` akan melewatkan pet yang tidak punya field ini.
                favorit = pd.IsFavorite == true,
                terkunci = kunci[uuid] ~= nil,
            }
        end
    end
    table.sort(Daftar, function(a, b)
        if a.nama ~= b.nama then return a.nama < b.nama end
        return (a.level or 0) > (b.level or 0)
    end)
    return Daftar
end

-- RAP per JENIS, bukan per pet: ItemId-nya "Pet-<Tipe>-<Mutasi>-T<tier>".
-- 78 pet biasanya cuma menghasilkan belasan permintaan.
--
-- Simpanannya BERUMUR 60 detik, sama dengan RAPCacheLifetime milik game. Dulu
-- disimpan selamanya, dan itu tidak apa-apa selagi RAP cuma dipakai sekali
-- lewat tombol -- tapi begitu harga BOLEH mengikuti RAP terus-menerus, cache
-- abadi membuat harga membeku di angka jam-jam sebelumnya.
local function rapPet(item, bolehTembak)
    if not M.RAP then return nil end
    local okId, itemId = pcall(function()
        return require(RS.Modules.TradeTokens.TokenRAPUtil).GetItemId("Pet", item.entri)
    end)

    local simpan = okId and itemId and RAPCache[itemId]
    if simpan and (os.time() - simpan.waktu) < 60 then return simpan.nilai end

    local ok, nilai = pcall(function()
        if bolehTembak then return M.RAP:GetRAPAsync("Pet", item.entri) end
        return M.RAP:GetRAP("Pet", item.entri)
    end)
    if ok and type(nilai) == "number" then
        if okId and itemId then RAPCache[itemId] = { nilai = nilai, waktu = os.time() } end
        return nilai
    end
    -- Gagal ambil: pakai simpanan lama kalau ada. Harga basi masih jauh lebih
    -- baik daripada nil, yang akan membuat item itu dilewati sama sekali.
    return simpan and simpan.nilai or nil
end

-- Harga tertinggi dalam satu kelompok. Dipakai mode RAP untuk listing per nama:
-- satu harga dipakai banyak ekor, sedangkan RAP berbeda menurut tier dan mutasi.
-- Diambil yang tertinggi -- kemahalan cuma lambat laku, kemurahan langsung rugi.
local function rapTertinggi(daftarItem)
    local tinggi
    for _, item in ipairs(daftarItem) do
        local r = rapPet(item, true)
        if r and (not tinggi or r > tinggi) then tinggi = r end
    end
    return tinggi
end

-- =========================================================================
-- PENGELOMPOKAN PER NAMA  (mode "Bald Eagle 10x harga")
-- =========================================================================

-- Berapa ekor per JENIS yang sedang terpasang di booth.
--
-- Bisa dihitung karena pet yang sudah di-listing TETAP ada di PetInventory.Data
-- -- game cuma menyaringnya dari tampilan lewat FilterItems, bukan membuangnya
-- dari data. Jadi ItemId listing masih bisa ditukar jadi PetType.
local function listingPerNama()
    local hasil = {}
    local d = profil()
    if not d or not d.TradeData or not d.PetsData then return hasil end
    local pets = d.PetsData.PetInventory and d.PetsData.PetInventory.Data or {}
    for _, l in pairs(d.TradeData.Listings or {}) do
        if l and l.ItemId then
            local e = pets[l.ItemId]
            local nama = e and e.PetType
            if nama then hasil[nama] = (hasil[nama] or 0) + 1 end
        end
    end
    return hasil
end

-- Apakah satu ekor boleh ikut borongan per-nama.
local function lolosSaringan(item)
    if item.terkunci then return false end                       -- trade cooldown
    if Cfg.SembunyiFav and item.favorit then return false end
    if Cfg.AbaikanMutasi and item.mutasi then return false end
    if Cfg.MaksBerat > 0 then
        -- Berat nil = CalculateWeight gagal. Diperlakukan sebagai TIDAK LOLOS,
        -- bukan lolos: menahan pet yang tidak diketahui beratnya jauh lebih
        -- murah daripada menjual pet besar karena beratnya gagal dibaca.
        if not item.berat then return false end
        if item.berat > Cfg.MaksBerat then return false end
    end
    return true
end

-- Mengembalikan daftar kelompok, tiap kelompok sudah URUT DARI YANG PALING
-- RINGAN. Itu yang membuat "jual 10 dari 30" mengambil sepuluh terkecil dan
-- meninggalkan yang besar -- pasangan alami dari saringan MaksBerat.
local function kelompokNama()
    local peta, urutan = {}, {}
    for _, item in ipairs(Daftar) do
        local g = peta[item.nama]
        if not g then
            g = { nama = item.nama, semua = {}, lolos = {} }
            peta[item.nama] = g
            urutan[#urutan + 1] = g
        end
        g.semua[#g.semua + 1] = item
        if lolosSaringan(item) then g.lolos[#g.lolos + 1] = item end
    end

    local terpasang = listingPerNama()
    for _, g in ipairs(urutan) do
        table.sort(g.lolos, function(a, b)
            return (a.berat or math.huge) < (b.berat or math.huge)
        end)
        g.terpasang = terpasang[g.nama] or 0
    end
    table.sort(urutan, function(a, b) return a.nama < b.nama end)
    return urutan
end

-- =========================================================================
-- LISTING
-- =========================================================================
local function ringkasanJual()
    local d = profil()
    if not d or not d.TradeData then return nil, nil end
    local n = 0
    for _ in pairs(d.TradeData.Listings or {}) do n = n + 1 end
    return n, tonumber(d.TradeData.Tokens) or 0
end

-- Mengembalikan (ok, alasan). CreateListing itu RemoteFunction yang membalas
-- boolean; penolakan server TIDAK melempar error, jadi nilai baliknya wajib
-- dibaca. Mengabaikannya = gagal diam-diam.
local function buatListing(tipe, id, harga)
    local ok, hasil, pesan = pcall(function()
        return Remote.Buat:InvokeServer(tipe, id, rapikanHarga(harga))
    end)
    if not ok then return false, "remote error: " .. tostring(hasil) end
    if hasil then return true end
    return false, (pesan and tostring(pesan)) or "rejected by server"
end

local sedangListing = false
-- Loop otomatis memanggil ini tiap beberapa detik. Kalau setelannya memang
-- belum lengkap, diagnosanya benar tapi akan tercetak terus-menerus sampai
-- log tidak terbaca. Jadi untuk panggilan otomatis, keluhan yang SAMA cuma
-- dicetak sekali per menit; tekan tombolnya sendiri dan ia selalu menjawab.
local keluhTerakhir, keluhKapan = "", 0

local function listingTerpilih(otomatis)
    if sedangListing then
        if not otomatis then catat("a listing run is already in progress") end
        return
    end
    sedangListing = true

    task.spawn(function()
        local aktif = select(1, ringkasanJual()) or 0
        local antre = {}

        -- Kenapa alasannya dikumpulkan, bukan sekadar "tidak ada yang dipasang":
        -- pernah terjadi -- nama sudah dicentang, auto listing menyala, booth
        -- sudah dipegang, tapi tidak ada apa pun yang terkirim karena targetnya
        -- masih 0. Pesan lama menuduh "target sudah terpenuhi" dan itu menutup
        -- penyebab sebenarnya.
        local alasan = {}
        local tanpaHarga = 0

        -- SATU jalur saja sekarang: tiap JENIS yang punya harga akan dijual.
        -- Tidak ada lagi mode per-pet dan tidak ada centang terpisah -- dua hal
        -- itu yang membuat "sudah saya isi" dan "yang dipakai script" bisa
        -- berbeda tanpa terlihat di layar.
        --
        -- Jumlahnya TARGET TERPASANG, bukan "tambah sekian": kalau 3 Bald Eagle
        -- sudah dipajang dan targetnya 10, yang dikirim 7. Tanpa itu, menekan
        -- tombol dua kali (atau auto listing yang berputar) menguras seluruh tas.
        for _, g in ipairs(kelompokNama()) do
            local harga = Cfg.HargaNama[g.nama]

            -- Mode RAP dihitung DI SINI, tidak disimpan ke config, supaya harga
            -- ketikan di bawahnya tidak pernah tertimpa.
            if Cfg.PakaiRAP and #g.lolos > 0 and (harga or Cfg.PilihNama[g.nama]) then
                local r = rapTertinggi(g.lolos)
                harga = r and (r * Cfg.PengaliRAP) or nil
                if not r then
                    tanpaHarga = tanpaHarga + 1
                    alasan[#alasan + 1] = g.nama .. ": RAP unavailable"
                end
            end

            if harga then
                -- Kosong = jual SEMUA; angka = batas per jenis.
                --
                -- `target` itu berapa yang harus TERPASANG, sedangkan #g.lolos
                -- itu sisa di tas. Versi lama memakai #g.lolos sebagai target,
                -- lalu menguranginya dengan yang sudah terpasang -- begitu
                -- terpasang melewati sisa tas, hasilnya negatif dan listing
                -- berhenti total. Terukur: 11 Bald Eagle, 6 terpasang, 5 di
                -- tas -> target 5, kurang = 5-6 = -1, tidak ada yang dikirim
                -- padahal 5 ekor masih menunggu.
                local target = tonumber(Cfg.JumlahNama[g.nama])
                    or ((Cfg.MaksPerJenis or 0) > 0 and Cfg.MaksPerJenis)
                    or (g.terpasang + #g.lolos)

                if #g.lolos == 0 and target > g.terpasang then
                    alasan[#alasan + 1] = g.nama .. ": 0 pets pass the filters"
                else
                    local kurang = math.min(target - g.terpasang, #g.lolos)

                    -- Angka lengkapnya dicetak saat tombol ditekan sendiri.
                    -- Tanpa ini, "kok cuma sekian yang naik?" tidak bisa
                    -- dijawab tanpa membongkar config -- dan itu sudah dua kali
                    -- memakan waktu. Panggilan otomatis tetap diam.
                    if not otomatis then
                        catat(string.format("%s: %d listed + %d eligible, target %s -> posting %d",
                            g.nama, g.terpasang, #g.lolos,
                            Cfg.JumlahNama[g.nama] and tostring(target) or (tostring(target) .. " (all)"),
                            math.max(kurang, 0)))
                    end

                    if kurang <= 0 then
                        alasan[#alasan + 1] = string.format("%s: %d already listed (target %d)",
                            g.nama, g.terpasang, target)
                    else
                        for i = 1, kurang do
                            antre[#antre + 1] = { item = g.lolos[i], harga = rapikanHarga(harga) }
                        end
                    end
                end
            end
        end

        if tanpaHarga > 0 then
            catat("SKIPPED " .. tanpaHarga
                .. " type(s) with no RAP -- turn RAP pricing off and type a price")
        end

        if #antre == 0 then
            local ringkasKeluh = table.concat(alasan, "|")
            local bolehKeluh = (not otomatis)
                or ringkasKeluh ~= keluhTerakhir
                or (os.time() - keluhKapan) >= 60
            if bolehKeluh then
                keluhTerakhir, keluhKapan = ringkasKeluh, os.time()
                if #alasan == 0 then
                    catat("no prices set -- type a price next to a pet name")
                else
                    catat("nothing to post:")
                    for i = 1, math.min(#alasan, 5) do catat("   - " .. alasan[i]) end
                end
            end
            sedangListing = false
            return
        end

        catat(string.format("listing %d pets (active %d/%d)", #antre, aktif, LISTING_MAKS))

        local sukses, gagal = 0, 0
        for _, baris in ipairs(antre) do
            if aktif + sukses >= LISTING_MAKS then
                catat("stopped: hit the " .. LISTING_MAKS .. " listing ceiling")
                break
            end

            local item, harga = baris.item, baris.harga
            local ok, alasan = buatListing(item.tipe, item.id, harga)
            if ok then
                sukses = sukses + 1
                -- Harga per jenis sengaja TIDAK dihapus sesudah berhasil:
                -- itulah yang membuat auto listing bisa mengisi ulang sendiri
                -- begitu ada yang laku.
                catat(string.format("OK  %s%s -> %s tokens", item.nama,
                    item.berat and string.format(" %.2fkg", item.berat) or "",
                    ringkas(harga)), nil)
            else
                gagal = gagal + 1
                catat(string.format("FAILED %s: %s", item.nama, tostring(alasan)))
            end
            task.wait(Cfg.JedaListing)
        end

        simpanConfig()
        catat(string.format("done: %d listed, %d failed", sukses, gagal))
        sedangListing = false
    end)
end

-- =========================================================================
-- WEBHOOK DISCORD
--
-- URL-nya milik pemakai, diisi sendiri di tab Automation > Misc.
-- HttpService:PostAsync diblokir untuk tujuan sembarangan dari client, jadi
-- yang dipakai `request` milik executor -- sama seperti pengambil daftar server.
-- =========================================================================
local function kirimWebhook(judul, baris, warna)
    if not Cfg.WebhookAktif then return false, "off" end
    local url = Cfg.Webhook or ""
    if not string.find(url, "^https://") then return false, "url kosong/salah" end

    local req = (syn and syn.request) or (http and http.request) or http_request
        or (fluxus and fluxus.request) or request
    if not req then return false, "executor tanpa request()" end

    local isian = {}
    for _, b in ipairs(baris) do
        isian[#isian + 1] = { name = b[1], value = tostring(b[2]), inline = b[3] == true }
    end

    local badan = {
        username = "Mozeframe Market",
        embeds = { {
            title = judul,
            color = warna or 16022797,   -- #f4820d, oranye Feng Jiu
            fields = isian,
            footer = { text = "Trade World - " .. LP.Name },
        } },
    }

    local ok, res = pcall(req, {
        Url = url, Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(badan),
    })
    if not ok then return false, "gagal kirim" end
    local kode = res and (res.StatusCode or res.Status) or 0
    -- Discord membalas 204 tanpa isi kalau berhasil.
    if kode == 200 or kode == 204 then return true end
    return false, "HTTP " .. tostring(kode)
end

-- =========================================================================
-- PEMANTAU PENJUALAN
--
-- Sumber KEBENARAN-nya polling profil (Listings berkurang / Tokens bertambah),
-- bukan AddToHistory. Alasannya: AddToHistory memang membawa payload jual-beli,
-- tapi apakah server benar-benar mem-FireClient ke PENJUAL tidak pernah
-- terbukti dari kode client -- cabang "Sold" juga tercapai lewat FetchHistory.
-- Jadi ia dipakai sebagai kabar cepat saja, dan tetap direkonsiliasi.
-- =========================================================================
local Pantau = {
    listingSebelum = nil,
    tokenSebelum   = nil,
    -- Detik dinding, bukan os.clock(): yang diukur "sudah berapa menit tak
    -- ada pembeli", dan os.clock() itu waktu CPU.
    terakhirLaku   = os.time(),
    totalLaku      = 0,
    tokenDapat     = 0,
    sudahLapor     = {},
}

pcall(function()
    Remote.Riwayat.OnClientEvent:Connect(function(rec)
        if type(rec) ~= "table" then return end
        local penjual = rec.seller and rec.seller.userId
        local hasil = rec.status and rec.status.result
        if penjual ~= LP.UserId or hasil == "Failed" then return end

        -- Event yang sama bisa datang dua kali (push + FetchHistory saat
        -- panel dibuka). Tanpa penyaring id, satu penjualan terkirim dua kali
        -- ke Discord dan angka sesi ikut dihitung ganda.
        local id = rec.id and tostring(rec.id) or nil
        if id then
            if Pantau.sudahLapor[id] then return end
            Pantau.sudahLapor[id] = true
        end

        Pantau.terakhirLaku = os.time()

        local pembeli = (rec.buyer and rec.buyer.username) or "?"
        local harga = tonumber(rec.price) or 0
        local data = rec.item and rec.item.data and rec.item.data.ItemData
        local nama = (data and (data.PetType or data.ItemName or data.SkinID))
            or (rec.item and rec.item.type) or "?"

        Pantau.totalLaku = Pantau.totalLaku + 1
        Pantau.tokenDapat = Pantau.tokenDapat + harga

        catat("SOLD " .. nama .. " to " .. pembeli .. " for " .. ringkas(harga))

        -- Dikirim di thread terpisah: satu permintaan HTTP yang lambat tidak
        -- boleh menahan pendengar remote milik game.
        task.spawn(function()
            local sisa, token = ringkasanJual()
            local rincian = ""
            if data then
                local bagian = {}
                if data.PetData and data.PetData.Level then
                    bagian[#bagian + 1] = "Lv" .. tostring(data.PetData.Level)
                end
                if data.MutationString and data.MutationString ~= "" then
                    bagian[#bagian + 1] = data.MutationString
                end
                if #bagian > 0 then rincian = "  (" .. table.concat(bagian, ", ") .. ")" end
            end
            kirimWebhook("Sold " .. nama, {
                { "Item", nama .. rincian },
                { "Price", ringkas(harga) .. " tokens", true },
                { "Buyer", pembeli, true },
                { "Total Tokens", ringkas(token or 0), true },
                { "Listings left", tostring(sisa or "?") .. "/" .. LISTING_MAKS, true },
                { "Sold this session", tostring(Pantau.totalLaku), true },
                { "Earned this session", ringkas(Pantau.tokenDapat), true },
                { "Server", #Players:GetPlayers() .. " players" },
            })
        end)
    end)
end)

-- =========================================================================
-- HOP SERVER
--
-- Game tidak menyediakan API daftar server untuk client (dicari: GetServers,
-- servers/Public, TeleportToPlaceInstance, ReserveServer, TeleportAsync -- nol
-- hasil di seluruh script). Jadi lewat endpoint publik Roblox.
--
-- sortOrder=Desc DI SINI BENAR, dan itu KEBALIKAN dari catatan hop GAG1 lama:
-- di GAG1 maxPlayers cuma 4 sehingga Desc selalu memberi server penuh dan nol
-- kandidat. Trade World MaxPlayers 30, dan yang kita cari memang yang ramai.
-- Yang penuh tetap disaring lewat isi < maks.
-- =========================================================================
local function ambilHttp(url)
    local req = (syn and syn.request) or (http and http.request) or http_request
        or (fluxus and fluxus.request) or request
    if req then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and res and res.StatusCode == 200 then return res.Body end
        if ok and res then return nil, res.StatusCode end
        return nil
    end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    return ok and body or nil
end

local function serverRamai()
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100",
        game.PlaceId)
    local body, kode = ambilHttp(url)
    if not body then
        -- 429 wajar kalau banyak akun menembak dari satu IP. Bukan kerusakan.
        catat(kode == 429 and "server list rate-limited (429), retrying later"
            or ("could not fetch server list" .. (kode and (" [" .. tostring(kode) .. "]") or "")))
        return nil
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
        catat("server list response could not be parsed")
        return nil
    end

    local kandidat = {}
    for _, s in ipairs(data.data) do
        local isi = tonumber(s.playing) or 0
        local maks = tonumber(s.maxPlayers) or 30
        if s.id ~= game.JobId and isi < maks and isi >= Cfg.MinTujuan then
            kandidat[#kandidat + 1] = { id = s.id, isi = isi }
        end
    end
    return kandidat
end

local function hop()
    local kandidat = serverRamai()
    if not kandidat or #kandidat == 0 then
        catat("no server with >= " .. Cfg.MinTujuan .. " players that is not full")
        return false
    end

    -- Acak di antara yang teramai, bukan ambil yang paling ramai: kalau lima
    -- akun membaca daftar yang sama, semuanya akan menuju server yang persis
    -- sama dan langsung memenuhinya.
    table.sort(kandidat, function(a, b) return a.isi > b.isi end)
    local batas = math.min(#kandidat, 5)
    local pilih = kandidat[math.random(1, batas)]

    if URL_ANTREAN ~= "" then
        local q = (syn and syn.queue_on_teleport) or queue_on_teleport
            or (fluxus and fluxus.queue_on_teleport)
        -- Yang diantre cuma pemanggil satu baris: batas panjang antrean teleport
        -- di sebagian executor pendek, dan menitipkan seluruh script gagal diam-diam.
        if q then pcall(q, 'loadstring(game:HttpGet("' .. URL_ANTREAN .. '"))()') end
    else
        catat("rejoin URL empty -- run the script again by hand after the hop")
    end

    catat("hopping to a server with " .. pilih.isi .. " players...")
    local ok = pcall(function()
        TeleportSvc:TeleportToPlaceInstance(game.PlaceId, pilih.id, LP)
    end)
    if not ok then catat("teleport was rejected") end
    return ok
end

-- =========================================================================
-- LOOP OTOMATIS
-- =========================================================================
task.spawn(function()
    task.wait(5)
    Pantau.listingSebelum, Pantau.tokenSebelum = ringkasanJual()

    while true do
        task.wait(5)

        local n, tok = ringkasanJual()
        if n and Pantau.listingSebelum then
            -- Listing berkurang ATAU token bertambah = ada yang laku. Dua-duanya
            -- dipakai: listing juga berkurang saat kita sendiri menghapusnya,
            -- dan token juga naik dari sumber lain.
            local berkurang = n < Pantau.listingSebelum
            local tokenNaik = tok and Pantau.tokenSebelum and tok > Pantau.tokenSebelum
            if berkurang and tokenNaik then
                local selisih = tok - Pantau.tokenSebelum
                Pantau.totalLaku = Pantau.totalLaku + (Pantau.listingSebelum - n)
                Pantau.tokenDapat = Pantau.tokenDapat + selisih
                Pantau.terakhirLaku = os.time()
                catat("sold " .. (Pantau.listingSebelum - n) .. " item(s), +"
                    .. ringkas(selisih) .. " tokens")
            end
        end
        Pantau.listingSebelum, Pantau.tokenSebelum = n, tok

        if Cfg.AutoKlaim and not boothSaya() then
            local ok, alasan = klaimBooth()
            catat((ok and "booth claim: " or "booth claim failed: ") .. tostring(alasan))
        end

        if Cfg.AutoListing and not sedangListing then
            local adaPilihan = false
            for _ in pairs(Cfg.HargaNama) do adaPilihan = true break end
            if adaPilihan and (n or 0) < LISTING_MAKS then
                pindaiPet()
                listingTerpilih(true)
            end
        end

        if Cfg.AutoHop then
            if LblSnipe then LblSnipe:SetText(ringkasanSnipe()) end

        local menit = (os.time() - Pantau.terakhirLaku) / 60
            local jumlahPemain = #Players:GetPlayers()
            -- DUA syarat, bukan satu. Sepi tapi baru saja ada pembeli = tetap
            -- tinggal; ramai tapi tak laku = juga tetap tinggal.
            if menit >= Cfg.MenitSepi and jumlahPemain < Cfg.BatasSepi then
                catat(string.format("%d min without a buyer & %d players here -- hopping",
                    math.floor(menit), jumlahPemain), nil)
                hop()
                task.wait(20)
            end
        end
    end
end)

-- =========================================================================
-- SNIPE  --  beli listing murah milik siapa pun
--
-- SEMUA angka di bawah diukur langsung di server hidup 2026-09-03, termasuk
-- satu pembelian sungguhan:
--   BuyListing:InvokeServer(<Instance Player pemilik>, listingUUID) -> true
--   token 15 -> 11 untuk listing seharga 4 (potongan tepat, tanpa biaya lain)
--   dilakukan dari jarak 123 STUD dari booth pemilik -> JARAK TIDAK DIPERIKSA,
--   jadi snipe tetap jalan walau FPS boost sudah menghapus etalase booth
--   round-trip 1700 ms
--
-- Argumen pertama WAJIB Instance Player, bukan userId dan bukan "Player_<id>"
-- (getPlayerById milik game memakai Players:GetPlayerByUserId). Akibatnya
-- keras: listing milik pemain yang TIDAK ADA di server tidak bisa dibeli sama
-- sekali. Terukur: dari 2436 listing, hanya 486 milik pemain online.
--
-- KENAPA POLLING, BUKAN SINYAL: ch:GetPathSignal(...) memang mengembalikan
-- Signal, tapi PathSignalClass mencetak Signal baru untuk string APA PUN, jadi
-- keberadaannya bukan bukti. Diawasi 12 detik: nol kali menyala. Polling atas
-- GetData() sudah terbukti mencerminkan keadaan, jadi itu jalur utamanya;
-- sinyal tetap dipasang sebagai pemercepat yang tidak merugikan kalau diam.
-- =========================================================================
local Snipe = { dicoba = {}, dibeli = 0, belanja = 0, kandidat = 0 }

local function daftarMutasiSnipe()
    local set, ada = {}, false
    for nama, dipilih in pairs(Cfg.SnipeMutasi or {}) do
        if dipilih then
            set[string.lower(nama)] = true
            ada = true
        end
    end
    return ada and set or nil
end

-- Daftar mutasi diambil dari registry game, bukan dihardcode: 61 nama saat ini,
-- dan yang baru ikut sendiri kalau developer menambahnya. "Normal" ikut supaya
-- pet TANPA mutasi bisa jadi sasaran juga.
local function daftarMutasiTersedia()
    local set, urut = { Normal = true }, {}
    local reg = M.Mutasi and M.Mutasi.EnumToPetMutation
    for _, nama in pairs(reg or {}) do
        if type(nama) == "string" then set[nama] = true end
    end
    for nama in pairs(set) do urut[#urut + 1] = nama end
    table.sort(urut)
    return urut
end

-- Mengembalikan daftar sasaran yang LOLOS seluruh saringan.
local function cariSasaran(bd)
    local hasil = {}
    local batasHarga = tonumber(Cfg.SnipeHarga) or 0
    if batasHarga <= 0 then return hasil end

    local mutasiWajib = daftarMutasiSnipe()
    local minKg = tonumber(Cfg.SnipeMinKg) or 0
    local minAge = tonumber(Cfg.SnipeMinAge) or 0
    local n = 0

    for pid, rec in pairs(bd.Players or {}) do
        local uid = tonumber(string.match(pid, "Player_(%-?%d+)"))
        -- Pemilik offline dilewati LEBIH DULU: itu 80% katalog, dan menyaringnya
        -- duluan memangkas sebagian besar pekerjaan tiap putaran.
        local pemilik = uid and Players:GetPlayerByUserId(uid)
        if pemilik and pemilik ~= LP then
            for luid, l in pairs(rec.Listings or {}) do
                if l.ItemType == "Pet" and not Snipe.dicoba[luid]
                    and (tonumber(l.Price) or 1e9) <= batasHarga then
                    local it = rec.Items and rec.Items[l.ItemId]
                    local pd = it and it.PetData
                    if it and pd and Cfg.SnipePet[it.PetType] then
                        n = n + 1
                        local lolosMut = true
                        if mutasiWajib then
                            -- Tanpa MutationType berarti "Normal", bukan
                            -- "tidak punya nama" -- kalau tidak, memilih Normal
                            -- di dropdown tidak akan pernah cocok dengan pet
                            -- polos, yang justru mayoritas.
                            local nm = (pd.MutationType and namaMutasi(pd.MutationType)) or "Normal"
                            lolosMut = mutasiWajib[string.lower(nm)] == true
                        end
                        local berat = beratPet(pd) or 0
                        local umur = tonumber(pd.Level) or 0
                        if lolosMut and berat >= minKg and umur >= minAge then
                            hasil[#hasil + 1] = {
                                pemilik = pemilik,
                                uuid = luid,
                                harga = tonumber(l.Price) or 0,
                                nama = it.PetType,
                                berat = berat,
                                umur = umur,
                                mutasi = pd.MutationType and namaMutasi(pd.MutationType) or nil,
                            }
                        end
                    end
                end
            end
        end
    end
    Snipe.kandidat = n
    return hasil
end

local function beliSasaran(t)
    -- Ditandai SEBELUM ditembak. Round-trip terukur 1700 ms, dan tanpa penanda
    -- di depan, putaran berikutnya menembak listing yang sama berkali-kali.
    Snipe.dicoba[t.uuid] = true
    task.spawn(function()
        local ok, hasil = pcall(function()
            return Remote.Beli:InvokeServer(t.pemilik, t.uuid)
        end)
        if ok and hasil then
            Snipe.dibeli = Snipe.dibeli + 1
            Snipe.belanja = Snipe.belanja + t.harga
            local rinci = string.format("%s %.2fkg age %d%s", t.nama, t.berat, t.umur,
                t.mutasi and (" " .. t.mutasi) or "")
            catat("SNIPED " .. rinci .. " for " .. ringkas(t.harga)
                .. " from " .. t.pemilik.Name)
            kabarSnipe("Sniped " .. t.nama,
                rinci .. " - " .. ringkas(t.harga) .. " tokens")
            task.spawn(function()
                local _, sisaToken = ringkasanJual()
                kirimWebhook("Sniped " .. t.nama, {
                    { "Item", rinci },
                    { "Paid", ringkas(t.harga) .. " tokens", true },
                    { "Seller", t.pemilik.Name, true },
                    -- Sisa saldo ikut dilaporkan: saat snipe berjalan sendiri,
                    -- itu angka yang menentukan berhenti atau lanjut, dan
                    -- tanpa ini kamu baru sadar kehabisan setelah membuka game.
                    { "Tokens left", ringkas(sisaToken or 0), true },
                    { "Bought this session", tostring(Snipe.dibeli), true },
                    { "Spent this session", ringkas(Snipe.belanja), true },
                }, 3447003)
            end)
        end
    end)
end

-- Panggilan PERTAMA ke sebuah RemoteFunction jauh lebih mahal daripada
-- berikutnya. Terukur: 248 ms lalu 61, 56 -- dan getter lain 283 lalu 51, 43,
-- 40, 49. Selisih ~200 ms itu persis momen yang menentukan siapa yang dapat
-- barangnya. Jadi jalur belinya dipanaskan lebih dulu dengan satu listing
-- palsu milik diri sendiri: server tidak menemukannya, tidak ada token yang
-- keluar, tapi jalurnya sudah hangat saat sasaran sungguhan muncul.
local sudahPanas = false
local function panaskanBeli()
    if sudahPanas then return end
    sudahPanas = true
    task.spawn(function()
        local t0 = os.clock()
        pcall(function()
            Remote.Beli:InvokeServer(LP, "00000000-0000-0000-0000-000000000000")
        end)
        catat(string.format("snipe ready (buy path warmed in %d ms)",
            math.floor((os.clock() - t0) * 1000)))
    end)
end

local function putaranSnipe()
    if not Cfg.SnipeAktif then return end
    if (Cfg.SnipeBatas or 0) > 0 and Snipe.belanja >= Cfg.SnipeBatas then
        if not Snipe.remBerbunyi then
            Snipe.remBerbunyi = true
            catat("snipe stopped: spend limit " .. ringkas(Cfg.SnipeBatas) .. " reached")
        end
        return
    end
    local bd = dataBooth()
    if not bd then return end
    for _, t in ipairs(cariSasaran(bd)) do
        beliSasaran(t)
    end
end

task.spawn(function()
    task.wait(5)
    if Cfg.SnipeAktif then panaskanBeli() end
end)

task.spawn(function()
    -- Terikat frame, jadi cap FPS yang sangat rendah ikut memperlambat deteksi.
    -- Terukur: satu putaran pindaian cuma 0,52 ms untuk 410 listing, jadi
    -- biayanya bukan di sini -- yang menentukan tinggal round-trip server
    -- (~56 ms) dan seberapa sering frame berjalan.
    while true do
        task.wait()
        pcall(putaranSnipe)
    end
end)

pcall(function()
    if not M.Rep then return end
    local ch = M.Rep.new("Booths")
    for _, jalur in ipairs({ "Players", "Players/@" }) do
        local ok, sig = pcall(function() return ch:GetPathSignal(jalur) end)
        if ok and sig then
            sig:Connect(function() pcall(putaranSnipe) end)
        end
    end
end)

-- =========================================================================
-- AUTO TERIMA TRADE
--
-- KENAPA INI AMAN, dan apa yang membuatnya aman:
-- script ini TIDAK PERNAH memanggil AddItem, SetSheckles, atau SetTokens.
-- Sisi kita selalu kosong, jadi trade yang diselesaikan hanya bisa MENAMBAH.
-- Itu satu-satunya jaminan yang dipegang di sini -- bukan menebak niat lawan.
--
-- Protokol terukur dari modul game:
--   TradeEvents.SendRequest.OnClientEvent(id, pemain, ...)   <- ada yang mengajak
--   TradeEvents.RespondRequest:FireServer(id, true/false)    <- terima / tolak
--   TradingController:Accept() / :Confirm() / :Decline()     <- di dalam trade
--   TradingController.CurrentTradeReplicator:GetDataAsync()  <- keadaan trade
--
-- BELUM TERUKUR: bentuk tabel keadaan trade, dan kapan persisnya Confirm
-- diterima server. Karena itu Confirm memakai aturan TOLAK-BILA-RAGU di bawah.
-- =========================================================================
local tradeSibuk = false

local function bolehTradeDari(nama)
    local saring = Cfg.TradeDari or ""
    if saring == "" then return true end
    local n = string.lower(tostring(nama))
    for bagian in string.gmatch(string.lower(saring), "[^,]+") do
        bagian = string.gsub(string.gsub(bagian, "^%s+", ""), "%s+$", "")
        if bagian ~= "" and bagian == n then return true end
    end
    return false
end

-- Berapa item yang ADA DI SISI KITA. Mengembalikan nil kalau tidak terbaca.
--
-- nil sengaja diperlakukan sebagai "jangan lanjut". Kalau keadaan trade tidak
-- bisa dibaca, satu-satunya kesalahan yang mahal adalah menyelesaikan trade
-- yang ternyata memuat barang kita -- misalnya saat pemakai sedang menyusun
-- trade sendiri secara manual dan script ikut menekan Confirm.
local function jumlahTawaranSaya()
    local TC = M.Trade
    local rep = TC and TC.CurrentTradeReplicator
    if not rep then return nil end
    local ok, data = pcall(function() return rep:GetDataAsync(10) end)
    if not ok or type(data) ~= "table" then return nil end

    local offers = data.offers or data.Offers
    if type(offers) ~= "table" then return nil end

    local kunci = { tostring(LP.UserId), "Player_" .. tostring(LP.UserId), LP.Name }
    for _, k in ipairs(kunci) do
        local milik = offers[k]
        if type(milik) == "table" then
            local n = 0
            for _, v in pairs(milik) do
                if type(v) == "table" then
                    for _ in pairs(v) do n = n + 1 end
                else
                    n = n + 1
                end
            end
            return n
        end
    end
    return nil
end

local function awasiTrade()
    if tradeSibuk then return end
    tradeSibuk = true
    task.spawn(function()
        task.wait(2)

        -- Bentuk tabel keadaan trade belum pernah terukur. Kunci tingkat-atasnya
        -- dicatat sekali supaya bisa dipertajam dari data nyata, bukan tebakan.
        local TC = M.Trade
        local rep = TC and TC.CurrentTradeReplicator
        if rep then
            local ok, data = pcall(function() return rep:GetDataAsync(10) end)
            if ok and type(data) == "table" then
                local k = {}
                for nama in pairs(data) do k[#k + 1] = tostring(nama) end
                table.sort(k)
                catat("trade state keys: " .. table.concat(k, ", "))
            end
        end

        local milik = jumlahTawaranSaya()
        if milik == nil then
            catat("trade: cannot read my own offer -- NOT confirming (safe default)")
            tradeSibuk = false
            return
        end
        if milik > 0 then
            catat("trade: your side has " .. milik .. " item(s) -- NOT auto-confirming")
            tradeSibuk = false
            return
        end

        local okA = pcall(function() TC:Accept() end)
        catat(okA and "trade accepted (my side empty)" or "trade accept failed")

        -- Cooldown tombol trade di data game = 5 detik (TradeData.ButtonCooldown).
        task.wait(5)

        -- Diperiksa ULANG sebelum Confirm: dalam 5 detik itu pemakai bisa saja
        -- menambahkan barang sendiri lewat UI game.
        local lagi = jumlahTawaranSaya()
        if lagi ~= 0 then
            catat("trade: my side changed to " .. tostring(lagi) .. " -- not confirming")
            tradeSibuk = false
            return
        end
        local okC = pcall(function() TC:Confirm() end)
        catat(okC and "trade confirmed" or "trade confirm failed")
        tradeSibuk = false
    end)
end

pcall(function()
    Remote.ReqMasuk.OnClientEvent:Connect(function(id, pemain)
        if not Cfg.AutoTrade then return end
        -- Dibaca lewat .Name langsung, bukan lewat typeof: kalau pemeriksaan
        -- tipe itu gagal, nama jatuh ke "?" dan SETIAP ajakan ikut tertolak
        -- selama daftar nama diisi -- gagal ke arah yang salah dan sunyi.
        local nama = "?"
        pcall(function() nama = tostring(pemain.Name or pemain) end)
        if not bolehTradeDari(nama) then
            catat("trade request from " .. nama .. " declined (not on your list)")
            pcall(function() Remote.JawabReq:FireServer(id, false) end)
            return
        end
        task.spawn(function()
            task.wait(Cfg.JedaTrade)
            pcall(function() Remote.JawabReq:FireServer(id, true) end)
            catat("trade request from " .. nama .. " accepted")
            kabarTrade("Trade request", nama .. " -- accepted")
        end)
    end)
end)

pcall(function()
    if M.Trade and M.Trade.OnTradeCreated then
        M.Trade.OnTradeCreated:Connect(function() awasiTrade() end)
    end
end)

-- =========================================================================
-- FPS BOOST  --  SATU ARAH, pulih hanya dengan rejoin
--
-- Mengikuti boost GAG1 yang sudah terbukti, tapi ATURAN LINDUNGNYA BEDA.
-- Di sana daftar lindung berbasis NAMA folder; di sini yang dilindungi adalah
-- APA PUN YANG BISA DIINTERAKSI -- tiap ProximityPrompt dan ClickDetector,
-- beserta seluruh jalur induknya. Alasannya: yang menentukan bisa-tidaknya
-- berjualan bukan nama folder, melainkan prompt "Claim" di booth. Aturan
-- berbasis nama akan tetap benar hari ini dan diam-diam salah saat developer
-- mengganti nama foldernya.
--
-- Yang dilindungi:
--   * seluruh subtree Workspace.TradeWorld.Booths (etalase + prompt klaim)
--   * tiap objek ber-ProximityPrompt/ClickDetector dan induk-induknya
--     (termasuk Portal Pete -- tanpa itu akun terkurung sampai rejoin)
--   * model makhluk hidup, TERMASUK karakter sendiri. Tanpa ini sapuan part
--     menghapus HumanoidRootPart pemain (HRP ber-CanCollide=false) dan
--     karakter terjebak Freefall tanpa satu pun pesan error.
--   * PlayerGui tidak pernah disentuh sama sekali.
-- =========================================================================
local boostSudah = false

-- Cap dipisah dari boost supaya bisa diubah kapan saja tanpa menjalankan
-- sapuan satu-arah itu lagi.
local function terapkanCap()
    if type(setfpscap) ~= "function" then return false end
    local n = tonumber(Cfg.CapFPS) or 0
    if n > 0 and n < 5 then n = 5 end
    pcall(setfpscap, n)
    return true
end

local function boostFPS()
    if boostSudah then return false, "already applied" end
    boostSudah = true

    local Lighting = game:GetService("Lighting")
    local n = { part = 0, efek = 0, texture = 0, rata = 0, anim = 0 }

    -- 1. daftar lindung
    local aman = {}
    local function keAtas(o)
        local x = o
        while x and x ~= WS do
            aman[x] = true
            x = x.Parent
        end
    end
    for _, d in ipairs(WS:GetDescendants()) do
        if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then keAtas(d) end
    end
    if BoothsFolder then
        keAtas(BoothsFolder)
        for _, d in ipairs(BoothsFolder:GetDescendants()) do aman[d] = true end
    end

    local Pemain = game:GetService("Players")
    local function makhlukHidup(m)
        if not m:IsA("Model") then return false end
        if m:FindFirstChildOfClass("Humanoid") then return true end
        for _, pl in ipairs(Pemain:GetPlayers()) do
            if pl.Character == m then return true end
        end
        return false
    end

    -- 2. cap & pencahayaan
    terapkanCap()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Technology = Enum.Technology.Compatibility
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 1
        -- Dibuang, bukan dimatikan: efek ber-Enabled=false masih ikut disiapkan
        -- tiap frame.
        for _, d in ipairs(Lighting:GetDescendants()) do
            pcall(function() d:Destroy() end)
            n.efek = n.efek + 1
        end
    end)
    pcall(function()
        WS.Terrain.WaterWaveSize = 0
        WS.Terrain.WaterWaveSpeed = 0
        WS.Terrain.WaterReflectance = 0
    end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        local UGS = UserSettings():GetService("UserGameSettings")
        UGS.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        UGS.MasterVolume = 0
    end)
    pcall(function()
        WS.Terrain.Decoration = false
        for _, d in ipairs(WS.Terrain:GetChildren()) do
            if d:IsA("Clouds") then d:Destroy() end
        end
    end)

    -- 2b. SUARA. Semuanya dibuang dari Workspace dan SoundService -- tiap Sound
    -- yang hidup itu satu voice yang di-mix tiap frame. PlayerGui tidak
    -- disentuh: suara UI ada di sana dan membuangnya pernah mematikan toko
    -- di script lain.
    for _, d in ipairs(WS:GetDescendants()) do
        if d:IsA("Sound") then
            -- Stop dan Destroy DIPISAH: kalau Stop melempar (mis. Sound yang
            -- sudah setengah dibongkar game), pcall gabungan membuat Destroy
            -- ikut batal dan suaranya selamat tanpa jejak.
            pcall(function() d:Stop() end)
            pcall(function() d:Destroy() end)
            n.efek = n.efek + 1
        end
    end
    pcall(function()
        for _, d in ipairs(game:GetService("SoundService"):GetDescendants()) do
            if d:IsA("Sound") then
                pcall(function() d:Stop() end)
                pcall(function() d:Destroy() end)
            end
        end
    end)

    -- 2c. KARAKTER PEMAIN LAIN dibuang seluruhnya.
    --
    -- Ini penyumbang terbesar di server 30 orang: tiap karakter itu belasan
    -- part ber-mesh plus aksesori, animasi, dan papan nama. Menghapusnya di
    -- CLIENT tidak mengubah apa pun di server -- pembeli tetap bisa mendatangi
    -- booth dan membeli, dan nama pembeli tetap terbaca karena datang dari
    -- payload remote, bukan dari karakternya.
    local function buangKarakterLain()
        for _, pl in ipairs(Pemain:GetPlayers()) do
            if pl ~= LP and pl.Character then
                pcall(function() pl.Character:Destroy() end)
            end
        end
    end
    buangKarakterLain()
    Pemain.PlayerAdded:Connect(function(pl)
        pl.CharacterAdded:Connect(function(kar)
            task.wait(0.2)
            pcall(function() kar:Destroy() end)
        end)
    end)
    for _, pl in ipairs(Pemain:GetPlayers()) do
        if pl ~= LP then
            pl.CharacterAdded:Connect(function(kar)
                task.wait(0.2)
                pcall(function() kar:Destroy() end)
            end)
        end
    end

    -- 2d. BOOTH ORANG LAIN DIKULITI (bukan dihapus).
    --
    -- Etalase booth orang itu sumber kerlip: partikel rarity, beam, cahaya,
    -- dan model pet yang dipajang di empat pad. Semuanya dibuang.
    --
    -- TAPI prompt "Claim" dan part penahannya SENGAJA DISISAKAN. Kalau seluruh
    -- booth dihapus, tiga hal ikut mati: klaim booth (butuh prompt), titik
    -- acuan "depan" (dihitung dari 30 prompt), dan klaim ulang sesudah hop --
    -- dan matinya tanpa pesan. Menghapus etalase sudah menghilangkan hampir
    -- seluruh biayanya; prompt itu satu objek tanpa gambar.
    --
    -- Booth SENDIRI dibiarkan utuh supaya dagangan sendiri tetap terlihat.
    local function boothKu()
        local ok, bd = pcall(function() return boothCh and boothCh:GetData() end)
        if not ok or not bd or not bd.Players then return nil end
        local rec = bd.Players[idSaya()]
        return rec and rec.Booth or nil
    end

    local function kulitiBooth(m)
        if m.Name == boothKu() then return end
        local prompt
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompt = d break end
        end
        local simpan = {}
        if prompt then
            simpan[prompt] = true
            local naik = prompt.Parent
            while naik and naik ~= m do
                simpan[naik] = true
                naik = naik.Parent
            end
        end
        for _, d in ipairs(m:GetDescendants()) do
            if not simpan[d] then
                pcall(function() d:Destroy() end)
                n.part = n.part + 1
            end
        end
        -- Part penahan prompt tetap ada tapi tidak digambar.
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") then
                pcall(function()
                    d.Transparency = 1
                    d.CastShadow = false
                end)
            end
        end
    end

    for _, m in ipairs(BoothsFolder:GetChildren()) do
        pcall(kulitiBooth, m)
    end

    -- Booth dibangun ulang server saat pemiliknya berganti, jadi kerlipnya
    -- kembali. Dipasang penjaga, ditunda sebentar supaya tidak menguliti
    -- booth yang baru separuh direplikasi.
    local antreKuliti = false
    BoothsFolder.DescendantAdded:Connect(function()
        if antreKuliti then return end
        antreKuliti = true
        task.delay(1, function()
            antreKuliti = false
            for _, m in ipairs(BoothsFolder:GetChildren()) do
                pcall(kulitiBooth, m)
            end
        end)
    end)

    -- 3. sapuan utama
    local buangPart, buangTex, buangRata = {}, {}, {}
    for _, atas in ipairs(WS:GetChildren()) do
        if atas ~= WS.Terrain and not makhlukHidup(atas) then
            for _, d in ipairs(atas:GetDescendants()) do
                if not aman[d] then
                    local k = d.ClassName
                    if k == "ParticleEmitter" or k == "Trail" or k == "Smoke" or k == "Fire"
                       or k == "Sparkles" or k == "Beam" or k == "PointLight"
                       or k == "SpotLight" or k == "SurfaceLight" then
                        pcall(function() d.Enabled = false end)
                        n.efek = n.efek + 1
                    elseif k == "Texture" or k == "Decal" then
                        buangTex[#buangTex + 1] = d
                    elseif k == "SpecialMesh" or k == "BlockMesh" or k == "CylinderMesh"
                        or k == "SurfaceGui" or k == "BillboardGui" then
                        buangRata[#buangRata + 1] = d
                    elseif k == "MeshPart" then
                        pcall(function()
                            d.TextureID = ""
                            d.Material = Enum.Material.SmoothPlastic
                            d.Reflectance = 0
                        end)
                        n.rata = n.rata + 1
                    elseif k == "SurfaceAppearance" then
                        -- Tekstur PBR: paling mahal per part, dan tidak pernah
                        -- menentukan apa pun yang bisa diklik.
                        buangRata[#buangRata + 1] = d
                    elseif d:IsA("BasePart") and d.CanCollide then
                        -- Yang bisa dipijak TIDAK dihapus, tapi tetap
                        -- diratakan: bayangan dan bahan mengkilap itu biaya
                        -- gambar, bukan bagian dari tabrakan.
                        pcall(function()
                            d.CastShadow = false
                            d.Material = Enum.Material.SmoothPlastic
                            d.Reflectance = 0
                        end)
                        n.rata = n.rata + 1
                    elseif d:IsA("BasePart") and not d.CanCollide then
                        -- CanCollide=false berarti menurut definisinya tidak
                        -- bisa dipijak, jadi mustahil menjatuhkan pemain.
                        buangPart[#buangPart + 1] = d
                    end
                end
            end
        end
    end

    -- Dicicil: menghancurkan puluhan ribu instance sekaligus membuat client
    -- tersendat beberapa detik, dan itu terlihat seperti script menggantung.
    for i, d in ipairs(buangTex) do
        pcall(function() d:Destroy() end)
        n.texture = n.texture + 1
        if i % 800 == 0 then task.wait() end
    end
    for i, d in ipairs(buangRata) do
        pcall(function() d:Destroy() end)
        n.rata = n.rata + 1
        if i % 600 == 0 then task.wait() end
    end
    for i, d in ipairs(buangPart) do
        pcall(function() d:Destroy() end)
        n.part = n.part + 1
        if i % 500 == 0 then task.wait() end
    end

    -- 4. ANIMASI DIHAPUS, bukan cuma dihentikan.
    --
    -- Animator yang masih hidup tetap menghitung pose tiap frame walau
    -- track-nya dihentikan, dan apa pun yang bergerak akan memainkan track
    -- baru. Yang dibuang: Animator, AnimationController, dan Animation di
    -- seluruh Workspace.
    --
    -- Animator MILIK KARAKTER SENDIRI dikecualikan: menghapusnya membuat
    -- karakter terpaku dalam satu pose saat berjalan ke booth, dan itu jauh
    -- lebih mencolok daripada hemat yang didapat dari satu karakter.
    local function punyaKita(d)
        local kar = LP.Character
        return kar and d:IsDescendantOf(kar)
    end

    local buangAnim = {}
    for _, d in ipairs(WS:GetDescendants()) do
        if (d:IsA("Animator") or d:IsA("AnimationController") or d:IsA("Animation"))
           and not punyaKita(d) then
            if d:IsA("Animator") then
                for _, t in ipairs(d:GetPlayingAnimationTracks()) do
                    pcall(function() t:Stop(0) end)
                end
            end
            buangAnim[#buangAnim + 1] = d
        end
    end
    for i, d in ipairs(buangAnim) do
        pcall(function() d:Destroy() end)
        n.anim = n.anim + 1
        if i % 300 == 0 then task.wait() end
    end

    -- 5. penjaga: streaming memasukkan hiasan kembali saat pemain bergerak.
    -- Sengaja seringan mungkin -- handler ini menyala ribuan kali per menit,
    -- dan apa pun yang lebih berat di sini memakan kembali FPS yang dihemat.
    WS.DescendantAdded:Connect(function(d)
        local k = d.ClassName
        if k == "ParticleEmitter" or k == "Trail" or k == "Beam" or k == "PointLight"
           or k == "SpotLight" or k == "SurfaceLight" or k == "Smoke" or k == "Fire" then
            pcall(function() d.Enabled = false end)
        elseif k == "Texture" or k == "Decal" then
            if not d:IsDescendantOf(BoothsFolder) then pcall(function() d:Destroy() end) end
        elseif k == "Animator" or k == "AnimationController" or k == "Animation" then
            local kar = LP.Character
            if not (kar and d:IsDescendantOf(kar)) then
                pcall(function() d:Destroy() end)
            end
        end
    end)

    return true, string.format("%d parts, %d textures, %d meshes/guis, %d effects, %d anims",
        n.part, n.texture, n.rata, n.efek, n.anim)
end

-- =========================================================================
-- GUI  --  library Obsidian (yang dipakai Ouroboros)
--
-- Kenapa memakai library orang, bukan menggambar sendiri: tampilan hub itu
-- ratusan baris Frame/UICorner yang tidak menambah satu pun kemampuan, dan
-- hasilnya tetap kalah rapi. Obsidian sudah dipakai hub lain di HP yang sama,
-- jadi buyer sudah terbiasa.
--
-- DIAMBIL DARI REPO SENDIRI, bukan repo aslinya. Kalau menunjuk ke
-- deividcomsono/Obsidian langsung, pemilik repo itu bisa mengganti isinya
-- kapan saja dan kode barunya ikut jalan di semua akun buyer.
--
-- API-nya diuji langsung di client sebelum ditulis. Satu temuan yang tidak
-- ada di contoh resminya: `Toggles` dan `Options` TIDAK terpasang sebagai
-- global di thread executor -- yang sah cuma Library.Toggles / Library.Options.
-- =========================================================================
local URL_UILIB = (getgenv and getgenv().MozeUILibURL)
    or "https://raw.githubusercontent.com/framemozejiu/frame/main/uilib.lua"

local Library
do
    -- ?t= wajib: raw.githubusercontent menahan salinan lama sampai ~5 menit,
    -- dan itu membuat perbaikan terlihat "tidak berpengaruh".
    local ok, hasil = pcall(function()
        return loadstring(game:HttpGet(URL_UILIB .. "?t=" .. tostring(os.time())))()
    end)
    if ok and type(hasil) == "table" then
        Library = hasil
    else
        -- Tidak berhenti total: config sudah tersimpan di berkas, jadi auto
        -- listing/klaim/hop tetap jalan tanpa panel. Yang hilang cuma cara
        -- mengubah setelan dari dalam game.
        warn("[MARKET] UI library gagal dimuat (" .. tostring(hasil) .. ")")
        warn("[MARKET] jalan tanpa panel; setelan tersimpan tetap dipakai.")
        print("[MARKET] BUILD 2026-09-04e | Trade World | headless")
        return
    end
end

-- =========================================================================
-- TEMA FENG JIU
--
-- Angkanya BUKAN karangan: diambil dari variabel CSS panel web sendiri
-- (index.html) supaya panel dan in-game memakai merah-oranye yang sama.
--     --primary #ef4444   --accent #f97316
--     --ember-deep #7f1d1d   --bg-color #020617
-- Scheme harus diisi SEBELUM CreateWindow: registry warna dibangun saat
-- jendela dibuat, jadi mengubahnya sesudah itu butuh sapuan ulang.
-- =========================================================================
Library.Scheme.BackgroundColor = Color3.fromRGB(2, 6, 23)      -- #020617
Library.Scheme.MainColor       = Color3.fromRGB(15, 19, 26)    -- panel gelap
Library.Scheme.AccentColor     = Color3.fromRGB(249, 115, 22)  -- #f97316 oranye
Library.Scheme.OutlineColor    = Color3.fromRGB(127, 29, 29)   -- #7f1d1d ember
Library.Scheme.FontColor       = Color3.fromRGB(241, 245, 249)
Library.Scheme.RedColor        = Color3.fromRGB(239, 68, 68)   -- #ef4444
Library.Scheme.DestructiveColor = Color3.fromRGB(185, 28, 28)  -- #b91c1c

-- Bawaan Obsidian itu Enum.Font.Code (monospace) -- itu yang bikin terlihat
-- seperti konsol. Dicoba berurutan karena nama font berbeda antar versi
-- Roblox; menembak satu nama lalu salah akan mematikan seluruh GUI.
for _, nama in ipairs({ "BuilderSansMedium", "GothamMedium", "Gotham", "SourceSansSemibold" }) do
    local ok = pcall(function()
        assert(Enum.Font[nama])
        Library.Scheme.Font = Font.fromEnum(Enum.Font[nama])
    end)
    if ok then break end
end

-- Jendela lama DIBONGKAR dulu. Script bisa dijalankan ulang (rejoin, hop,
-- atau eksekusi manual kedua kali), dan tanpa ini tiap kali menambah satu
-- jendela Obsidian baru di atas yang lama -- yang lama tetap hidup, tetap
-- membaca config yang sama, dan tetap punya loop-nya sendiri.
pcall(function()
    if _G.MozeMarketLib and _G.MozeMarketLib ~= Library then
        _G.MozeMarketLib:Unload()
    end
end)
_G.MozeMarketLib = Library

local Window = Library:CreateWindow({
    Title = "Mozeframe Market",
    Footer = "Trade World",
    NotifySide = "Right",
    ShowCustomCursor = false,
    -- Sembunyi/tampil. Di HP muncul tombol Toggle + Lock melayang di kiri atas;
    -- di PC lewat tombol ini. Sebelumnya dua-duanya memakai bawaan library dan
    -- tidak pernah disebut di mana pun, jadi panelnya terasa tidak bisa ditutup.
    ToggleKeybind = Enum.KeyCode.RightControl,
    MobileButtonsSide = "Left",
    ShowMobileButtons = true,
})

local Tabs = {
    Booth = Window:AddTab("Booth", "store"),
    Sell  = Window:AddTab("Sell", "tag"),
    Buy   = Window:AddTab("Buy", "crosshair"),
    Auto  = Window:AddTab("Automation", "repeat"),
    Log   = Window:AddTab("Log", "scroll-text"),
}

local O = Library.Options
local T = Library.Toggles

-- Dipasang saat kita sendiri yang mengubah isi widget. Tanpa ini, SetValue
-- memicu Callback yang menulis balik ke Cfg -- dan pilihan yang sedang dipulihkan
-- dari berkas justru terhapus oleh proses pemulihannya sendiri.
local memuat = false

-- =========================================================================
-- LOG
-- =========================================================================
local LogBox = Tabs.Log:AddGroupbox({ Side = "Left", Name = "Activity", IconName = "scroll-text" })
local BARIS_LOG = 16
local labelLog, isiLog = {}, {}
for i = 1, BARIS_LOG do
    labelLog[i] = LogBox:AddLabel("", true)
end

tulisLog = function(pesan, _)
    table.insert(isiLog, tostring(pesan))
    while #isiLog > BARIS_LOG do table.remove(isiLog, 1) end
    for i = 1, BARIS_LOG do
        labelLog[i]:SetText(isiLog[i] or "")
    end
end

kabarSnipe = function(judul, isi)
    pcall(function()
        Library:Notify({ Title = judul, Description = isi, Time = 5 })
    end)
end

kabarTrade = function(judul, isi)
    pcall(function()
        Library:Notify({ Title = judul, Description = isi, Time = 4 })
    end)
end

local function kabar(judul, isi, detik)
    pcall(function()
        Library:Notify({ Title = judul, Description = isi, Time = detik or 4 })
    end)
end

-- Notifikasi tiap setelan benar-benar tertulis ke berkas. Dipasang ke kait
-- di simpanConfig, jadi satu notifikasi per penulisan -- bukan per ketukan.
sesudahSimpan = function(ok)
    kabar(ok and "Settings saved" or "SAVE FAILED",
        ok and "mozeframe_market.json updated"
        or "could not write mozeframe_market.json", 2)
end

-- =========================================================================
-- TAB: BOOTH
-- =========================================================================
local BoothBox = Tabs.Booth:AddGroupbox({ Side = "Left", Name = "Booth", IconName = "store" })
local LblBooth = BoothBox:AddLabel("reading booth data...", true)

BoothBox:AddButton({
    Text = "Claim empty booth",
    Func = function()
        task.spawn(function()
            local ok, alasan = klaimBooth()
            catat((ok and "claim: " or "claim failed: ") .. tostring(alasan))
            kabar(ok and "Booth claimed" or "Claim failed", tostring(alasan))
        end)
    end,
})

BoothBox:AddButton({
    Text = "Unclaim booth",
    DoubleClick = true,   -- satu arah: booth bisa langsung disambar orang lain
    Func = function()
        task.spawn(function()
            local ok, alasan = lepasBooth()
            catat(ok and "booth released" or ("release failed: " .. tostring(alasan)))
        end)
    end,
})

BoothBox:AddToggle("AutoClaim", {
    Text = "Auto claim booth when empty",
    Default = Cfg.AutoKlaim,
    Callback = function(v)
        if memuat then return end
        Cfg.AutoKlaim = v
        simpanConfig()
    end,
})

local SkinBox = Tabs.Booth:AddGroupbox({ Side = "Right", Name = "Stall skin", IconName = "palette" })
local PetaSkin = {}   -- teks tampil -> kunci registry

local function isiSkin()
    local nilai, terpilih = {}, nil
    PetaSkin = {}
    local aktif = skinAktif()
    for _, s in ipairs(skinDimiliki()) do
        if s.punya then
            local teks = s.nama
            PetaSkin[teks] = s.kunci
            nilai[#nilai + 1] = teks
            if s.kunci == aktif then terpilih = teks end
        end
    end
    if #nilai == 0 then nilai = { "Wooden Stall" } end
    memuat = true
    O.SkinPick:SetValues(nilai)
    if terpilih then pcall(function() O.SkinPick:SetValue(terpilih) end) end
    memuat = false
end

SkinBox:AddDropdown("SkinPick", {
    Values = { "Wooden Stall" },
    Default = 1,
    Multi = false,
    Text = "Skin you own",
    Callback = function(v)
        if memuat then return end
        local kunci = PetaSkin[v]
        if not kunci then return end
        Cfg.Skin = kunci
        simpanConfig()
    end,
})

SkinBox:AddButton({
    Text = "Equip selected skin",
    Func = function()
        task.spawn(function()
            local kunci = PetaSkin[O.SkinPick.Value] or Cfg.Skin
            local ok = pasangSkin(kunci)
            catat(ok and ("skin equipped: " .. tostring(kunci))
                or ("skin did not change: " .. tostring(kunci)))
        end)
    end,
})

SkinBox:AddLabel("Only skins you own are listed. Wooden Stall is always available.", true)

-- =========================================================================
-- TAB: SELL
--
-- DIRANCANG ULANG 2026-09-03. Bentuk sebelumnya menuntut empat langkah
-- berurutan (pilih mode -> centang jenis -> pilih "configure which type" ->
-- ketik harga -> tekan Save) dan tiga di antaranya tidak kelihatan kalau
-- dilewati. Akibatnya nyata: config tercatat 67 pet terpilih dengan NOL harga,
-- dan dari layar tidak ada satu pun tanda bahwa harganya tidak masuk.
--
-- Sekarang satu layar, satu aturan: TIAP JENIS PET PUNYA BARISNYA SENDIRI.
-- Ada harga = dijual. Kosong = tidak dijual. Tidak ada mode, tidak ada centang.
-- =========================================================================
local HargaBox = Tabs.Sell:AddGroupbox({ Side = "Left", Name = "Price list", IconName = "coins" })
local OptBox   = Tabs.Sell:AddGroupbox({ Side = "Right", Name = "Options", IconName = "sliders-horizontal" })
local SafeBox  = Tabs.Sell:AddGroupbox({ Side = "Right", Name = "Safety", IconName = "shield" })
local ActBox   = Tabs.Sell:AddGroupbox({ Side = "Right", Name = "Actions", IconName = "play" })

local LblAksi, LblHarga, LblRingkasan
local segarkanDaftar   -- deklarasi maju: dipakai callback yang dibuat lebih dulu

local function ringkasanSnipe()
    local n = 0
    for _ in pairs(Cfg.SnipePet) do n = n + 1 end
    if n == 0 or (Cfg.SnipeHarga or 0) <= 0 then
        return "Idle - pick at least one pet and a price."
    end
    return string.format("Watching %d pet type(s) at %s or less\nBought %d, spent %s",
        n, ringkas(Cfg.SnipeHarga), Snipe.dibeli, ringkas(Snipe.belanja))
end

local function ringkasanHarga()
    if Cfg.PakaiRAP then
        return string.format("Using RAP x%.2f (live). Typed prices are kept but ignored.",
            Cfg.PengaliRAP)
    end
    return "Using your typed prices. A type with no price is simply not sold."
end

-- KENAPA SEMUA KOTAK MEMAKAI Finished = false
--
-- Dengan Finished = true, Obsidian hanya menyimpan bila FocusLost membawa
-- enterPressed = true (Library.lua ~7374). Tap di luar kotak -- cara paling
-- lumrah menutup papan ketik di HP -- membuat nilainya DIBUANG diam-diam.
-- Itu penyebab "sudah set 500 tapi tidak ngefek" yang terulang tiga kali.
--
-- Finished = false menyalakan callback tiap ketukan, jadi tidak ada yang
-- hilang. Konsekuensinya nilai setengah jadi ("5", "50") ikut lewat, dan itu
-- berbahaya karena auto listing berputar tiap 5 detik dan bisa memakai harga
-- 5. Karena itu penulisan ke config DITUNDA 0,8 detik sesudah ketukan
-- terakhir -- nilai transisi tidak pernah sampai ke Cfg.
local tundaHarga = {}
local function jadwalkan(kunci, f)
    tundaHarga[kunci] = (tundaHarga[kunci] or 0) + 1
    local milikku = tundaHarga[kunci]
    task.delay(0.8, function()
        if tundaHarga[kunci] == milikku then f() end
    end)
end

-- Satu kotak menerima harga DAN jumlah: "500" atau "500 x10".
-- Digabung karena satu kotak per jenis sudah cukup panjang daftarnya; menaruh
-- dua kotak per jenis membuat daftarnya dua kali lebih tinggi tanpa guna.
local function uraiHargaJumlah(teks)
    if type(teks) ~= "string" or teks == "" then return nil, nil end
    local kiri, kanan = string.match(teks, "^(.-)%s*[xX%*]%s*(%d+)%s*$")
    if kiri and kiri ~= "" then return uraiAngka(kiri), tonumber(kanan) end
    return uraiAngka(teks), nil
end

local function tulisHargaJumlah(nama)
    local h, j = Cfg.HargaNama[nama], Cfg.JumlahNama[nama]
    if not h then return "" end
    if j then return ringkas(h) .. " x" .. tostring(j) end
    return ringkas(h)
end

-- Daftar dibangun ulang tiap muat ulang inventaris: jenis pet bisa bertambah
-- (menetas) atau habis terjual, dan daftar yang membeku akan menyesatkan.
local barisHarga = {}

local function bangunDaftarHarga(kelompok)
    -- Groupbox lama DIHANCURKAN, bukan disembunyikan -- kalau tidak, tiap
    -- muat ulang menumpuk daftar baru di bawah yang lama.
    if HargaBox then pcall(function() HargaBox:Destroy() end) end
    HargaBox = Tabs.Sell:AddGroupbox({ Side = "Left", Name = "Price list", IconName = "coins" })
    barisHarga = {}

    HargaBox:AddLabel("Type a price to sell that pet. Leave blank to skip it.\n"
        .. "Add \"x10\" to cap how many stay listed, e.g. 500 x10", true)
    HargaBox:AddDivider()

    -- Jenis yang STOKNYA HABIS tetap ditampilkan selama harganya masih
    -- tersimpan. Kalau tidak, barisnya lenyap begitu 10 eagle terakhir naik
    -- ke booth, dan dari layar itu terlihat seperti setelan harganya hilang --
    -- padahal masih hidup dan akan mengisi ulang sendiri begitu stok datang.
    local urut, ada = {}, {}
    for _, g in ipairs(kelompok) do
        urut[#urut + 1] = g
        ada[g.nama] = true
    end
    for nama in pairs(Cfg.HargaNama) do
        if not ada[nama] then
            urut[#urut + 1] = { nama = nama, lolos = {}, semua = {}, terpasang = 0 }
        end
    end
    table.sort(urut, function(a, b) return a.nama < b.nama end)

    if #urut == 0 then
        HargaBox:AddLabel("No pets found. Press Refresh inventory.", true)
        return
    end

    for _, g in ipairs(urut) do
        local nama = g.nama
        local idx = "hrg_" .. nama
        HargaBox:AddInput(idx, {
            Text = (g.terpasang or 0) > 0
                and string.format("%s  (%d ready, %d up)", nama, #g.lolos, g.terpasang)
                or string.format("%s  (%d ready)", nama, #g.lolos),
            Default = tulisHargaJumlah(nama),
            Finished = false,
            Placeholder = "price",
            Callback = function(v)
                if memuat then return end
                jadwalkan(nama, function()
                    local h, j = uraiHargaJumlah(v)
                    Cfg.HargaNama[nama] = h and rapikanHarga(h) or nil
                    Cfg.JumlahNama[nama] = j
                    -- Ada harga = ikut dijual. Tidak ada centang terpisah lagi,
                    -- jadi tidak mungkin lagi "sudah diisi tapi belum tercentang".
                    Cfg.PilihNama[nama] = h and true or nil
                    simpanConfig()
                    if h then
                        catat(nama .. " -> " .. ringkas(rapikanHarga(h))
                            .. (j and (" x" .. j) or " (all)"))
                    elseif v ~= "" then
                        catat("could not read \"" .. tostring(v) .. "\" -- try 500 or 500 x10")
                    end
                end)
            end,
        })
        barisHarga[nama] = idx
    end
end

-- ---------------------------------------------------------------- options
OptBox:AddButton({ Text = "Refresh inventory", Func = function()
    if segarkanDaftar then segarkanDaftar(true) end
end })

OptBox:AddToggle("PakaiRAP", {
    Text = "Price from RAP (live)",
    Default = Cfg.PakaiRAP,
    Callback = function(v)
        if memuat then return end
        Cfg.PakaiRAP = v
        simpanConfig()
        if LblHarga then LblHarga:SetText(ringkasanHarga()) end
    end,
})

OptBox:AddSlider("RapMul", {
    Text = "RAP multiplier", Default = Cfg.PengaliRAP, Min = 0.1, Max = 5, Rounding = 2,
    Callback = function(v)
        if memuat then return end
        Cfg.PengaliRAP = v
        simpanConfig()
        if LblHarga then LblHarga:SetText(ringkasanHarga()) end
    end,
})

OptBox:AddInput("MaksPerJenis", {
    Text = "Default max per type", Default = tostring(Cfg.MaksPerJenis or 0),
    Numeric = true, Finished = false, Placeholder = "0 = all",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__maks", function()
            local x = tonumber((string.gsub(v or "", "%D", "")))
            Cfg.MaksPerJenis = (x and x > 0) and x or 0
            simpanConfig()
        end)
    end,
})

LblHarga = OptBox:AddLabel(ringkasanHarga(), true)

-- ---------------------------------------------------------------- safety
SafeBox:AddToggle("SkipMut", {
    Text = "Never sell mutated pets",
    Default = Cfg.AbaikanMutasi,
    Callback = function(v)
        if memuat then return end
        Cfg.AbaikanMutasi = v
        simpanConfig()
        if segarkanDaftar then segarkanDaftar() end
    end,
})

SafeBox:AddToggle("HideFav", {
    Text = "Never sell favorited pets",
    Default = Cfg.SembunyiFav,
    Callback = function(v)
        if memuat then return end
        Cfg.SembunyiFav = v
        simpanConfig()
        if segarkanDaftar then segarkanDaftar() end
    end,
})

SafeBox:AddInput("MaxKg", {
    Text = "Max weight kg (0 = any)",
    Default = tostring(Cfg.MaksBerat), Finished = false, Placeholder = "0",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__kg", function()
            local x = tonumber((string.gsub(v or "", "[^%d%.]", "")))
            Cfg.MaksBerat = (x and x > 0) and x or 0
            simpanConfig()
            if segarkanDaftar then segarkanDaftar() end
        end)
    end,
})

SafeBox:AddLabel("The lightest pets are always sold first, so the big ones stay.", true)

-- ---------------------------------------------------------------- actions
ActBox:AddButton({ Text = "List now", Func = function()
    listingTerpilih()
    task.delay(2, function() if segarkanDaftar then segarkanDaftar(true) end end)
end })

ActBox:AddButton({
    Text = "Clear every price",
    DoubleClick = true,
    Func = function()
        Cfg.HargaNama, Cfg.JumlahNama, Cfg.PilihNama = {}, {}, {}
        simpanConfig()
        if segarkanDaftar then segarkanDaftar() end
        catat("all prices cleared")
    end,
})

LblAksi = ActBox:AddLabel("Listings: -", true)
LblRingkasan = ActBox:AddLabel("", true)


-- =========================================================================
-- TAB: BUY  (snipe)
-- =========================================================================
local PickBox = Tabs.Buy:AddGroupbox({ Side = "Left", Name = "What to snipe", IconName = "crosshair" })
local FiltBox = Tabs.Buy:AddGroupbox({ Side = "Right", Name = "Filters", IconName = "filter" })
local RunBox  = Tabs.Buy:AddGroupbox({ Side = "Right", Name = "Run", IconName = "play" })

local LblSnipe

-- Daftar jenis diambil dari KATALOG HIDUP, bukan dari daftar pet bawaan game:
-- yang berguna hanyalah yang benar-benar sedang dijual orang, dan daftar itu
-- juga otomatis ikut kalau developer menambah pet baru.
local function jenisDiKatalog()
    local set, urut = {}, {}
    local bd = dataBooth()
    if bd then
        for _, rec in pairs(bd.Players or {}) do
            for _, l in pairs(rec.Listings or {}) do
                if l.ItemType == "Pet" then
                    local it = rec.Items and rec.Items[l.ItemId]
                    if it and it.PetType and not set[it.PetType] then
                        set[it.PetType] = true
                        urut[#urut + 1] = it.PetType
                    end
                end
            end
        end
    end
    -- Jenis yang sudah dipilih tetap ditampilkan walau sedang tidak ada yang
    -- menjualnya, supaya pilihanmu tidak lenyap dari layar.
    for nama in pairs(Cfg.SnipePet) do
        if not set[nama] then
            set[nama] = true
            urut[#urut + 1] = nama
        end
    end
    table.sort(urut)
    return urut
end

PickBox:AddDropdown("SnipePick", {
    Values = {}, Default = {}, Multi = true, Searchable = true,
    -- AllowNull WAJIB. Tanpa itu Obsidian MENOLAK melepas centang terakhir
    -- (Library.lua:8435 dan :8574 keduanya `return` lebih dulu), jadi begitu
    -- satu pet dipilih ia tidak pernah bisa dilepas lagi -- dan tidak ada
    -- pesan apa pun yang menjelaskan kenapa.
    AllowNull = true,
    Text = "Pets to snipe",
    Callback = function(v)
        if memuat then return end
        Cfg.SnipePet = {}
        for nama, dipilih in pairs(v) do
            if dipilih then Cfg.SnipePet[nama] = true end
        end
        simpanConfig()
    end,
})

PickBox:AddButton({ Text = "Refresh pet list", Func = function()
    local urut = jenisDiKatalog()
    local pilih = {}
    for nama in pairs(Cfg.SnipePet) do pilih[nama] = true end
    memuat = true
    O.SnipePick:SetValues(urut)
    pcall(function() O.SnipePick:SetValue(pilih) end)
    memuat = false
    catat(#urut .. " pet types currently on sale")
end })

PickBox:AddButton({ Text = "Clear pet selection", Func = function()
    Cfg.SnipePet = {}
    simpanConfig()
    memuat = true
    pcall(function() O.SnipePick:SetValue({}) end)
    memuat = false
    if LblSnipe then LblSnipe:SetText(ringkasanSnipe()) end
    catat("snipe list cleared")
end })

PickBox:AddInput("SnipeHarga", {
    Text = "Buy at or below", Default = tostring(Cfg.SnipeHarga),
    Finished = false, Placeholder = "300",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__sh", function()
            Cfg.SnipeHarga = uraiAngka(v) or 0
            simpanConfig()
            if LblSnipe then LblSnipe:SetText(ringkasanSnipe()) end
        end)
    end,
})

PickBox:AddLabel("Only listings owned by players IN THIS SERVER can be bought - "
    .. "that is how the game works, not a limit of this script. "
    .. "Roughly one in five listings qualifies.", true)

-- ---------------------------------------------------------------- filters
FiltBox:AddDropdown("SnipeMutasi", {
    Values = {}, Default = {}, Multi = true, Searchable = true,
    AllowNull = true,   -- lihat catatan di SnipePick
    Text = "Mutations (none = any)",
    Callback = function(v)
        if memuat then return end
        Cfg.SnipeMutasi = {}
        for nama, dipilih in pairs(v) do
            if dipilih then Cfg.SnipeMutasi[nama] = true end
        end
        simpanConfig()
    end,
})

FiltBox:AddInput("SnipeMinKg", {
    Text = "Min weight kg (0 = any)", Default = tostring(Cfg.SnipeMinKg),
    Finished = false, Placeholder = "0",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__skg", function()
            local x = tonumber((string.gsub(v or "", "[^%d%.]", "")))
            Cfg.SnipeMinKg = (x and x > 0) and x or 0
            simpanConfig()
        end)
    end,
})

FiltBox:AddInput("SnipeMinAge", {
    Text = "Min age (0 = any)", Default = tostring(Cfg.SnipeMinAge),
    Finished = false, Numeric = true, Placeholder = "0",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__sage", function()
            local x = tonumber((string.gsub(v or "", "%D", "")))
            Cfg.SnipeMinAge = (x and x > 0) and x or 0
            simpanConfig()
        end)
    end,
})

FiltBox:AddLabel("Leave all three blank or 0 and it takes anything: any "
    .. "mutation, any size, any age.", true)

-- ---------------------------------------------------------------- run
RunBox:AddToggle("SnipeAktif", {
    Text = "Auto snipe",
    Default = Cfg.SnipeAktif,
    Callback = function(v)
        if memuat then return end
        Cfg.SnipeAktif = v
        Snipe.remBerbunyi = false
        simpanConfig()
        if v then panaskanBeli() end
        if LblSnipe then LblSnipe:SetText(ringkasanSnipe()) end
    end,
})

RunBox:AddInput("SnipeBatas", {
    Text = "Stop after spending (0 = no limit)", Default = tostring(Cfg.SnipeBatas),
    Finished = false, Placeholder = "0",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__sbat", function()
            Cfg.SnipeBatas = uraiAngka(v) or 0
            Snipe.remBerbunyi = false
            simpanConfig()
        end)
    end,
})

LblSnipe = RunBox:AddLabel("", true)

RunBox:AddLabel("Buying does NOT need you near the booth, so the FPS boost "
    .. "does not get in the way. "
    .. "Measured: the buy call itself takes about 56 ms - that is one network "
    .. "round trip to Roblox and nothing on your device can beat it. Scanning "
    .. "the whole catalogue costs 0.5 ms, so the script is not what slows you "
    .. "down. A very low FPS cap does, though - keep it at 30 or higher while "
    .. "sniping.", true)

-- =========================================================================
-- TAB: AUTOMATION
-- =========================================================================
local AutoL = Tabs.Auto:AddGroupbox({ Side = "Left", Name = "Listing", IconName = "repeat" })
local AutoR = Tabs.Auto:AddGroupbox({ Side = "Right", Name = "Server hop", IconName = "globe" })

AutoL:AddToggle("AutoList", {
    Text = "Auto listing (restock when sold)",
    Default = Cfg.AutoListing,
    Callback = function(v)
        if memuat then return end
        Cfg.AutoListing = v
        simpanConfig()
    end,
})

-- Batas atas dinaikkan ke 10 detik. Game menyimpan ButtonCooldown = 5 di
-- ReplicatedStorage.Data.TradeData, dan pemilik script mengamati cooldown 5
-- detik per listing. Catatan jujur: konstanta itu dibaca TradingController
-- untuk trade langsung -- cooldown khusus CreateListing belum pernah diukur,
-- jadi angkanya dibiarkan bisa diatur, bukan dipaksa.
AutoL:AddSlider("Jeda", {
    Text = "Delay between listings", Default = Cfg.JedaListing,
    Min = 0.1, Max = 10, Rounding = 1, Suffix = "s",
    Callback = function(v)
        if memuat then return end
        Cfg.JedaListing = v
        simpanConfig()
    end,
})

AutoL:AddLabel("Quantity is a TARGET: sell one of ten and the next pass puts "
    .. "one back. The game defines a 5s cooldown, so 5 is a safe delay.", true)

AutoR:AddToggle("AutoHop", {
    Text = "Auto hop server",
    Default = Cfg.AutoHop,
    Callback = function(v)
        if memuat then return end
        Cfg.AutoHop = v
        simpanConfig()
    end,
})

AutoR:AddSlider("MntSepi", {
    Text = "Hop after no buyer for", Default = Cfg.MenitSepi,
    Min = 1, Max = 60, Rounding = 0, Suffix = " min",
    Callback = function(v)
        if memuat then return end
        Cfg.MenitSepi = v
        simpanConfig()
    end,
})

AutoR:AddSlider("BatasSepi", {
    Text = "This server counts as quiet below", Default = Cfg.BatasSepi,
    Min = 1, Max = 30, Rounding = 0, Suffix = " players",
    Callback = function(v)
        if memuat then return end
        Cfg.BatasSepi = v
        simpanConfig()
    end,
})

AutoR:AddSlider("MinTujuan", {
    Text = "Target server must have at least", Default = Cfg.MinTujuan,
    Min = 1, Max = 30, Rounding = 0, Suffix = " players",
    Callback = function(v)
        if memuat then return end
        Cfg.MinTujuan = v
        simpanConfig()
    end,
})

local LblAuto = AutoR:AddLabel("", true)

-- ---------------------------------------------------------------- misc
local MiscBox = Tabs.Auto:AddGroupbox({ Side = "Left", Name = "Misc", IconName = "wrench" })

-- URL webhook itu RAHASIA: siapa pun yang memegangnya bisa memposting ke
-- channel itu. Karena itu tidak pernah dicetak utuh ke log, dan yang
-- ditampilkan balik cuma ekornya.
local function samarkanUrl(u)
    if not u or u == "" then return "not set" end
    if #u <= 12 then return "set" end
    return "set (..." .. string.sub(u, -8) .. ")"
end

local LblWebhook

MiscBox:AddInput("WebhookUrl", {
    Text = "Discord webhook URL",
    Default = Cfg.Webhook, Finished = false,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__wh", function()
            Cfg.Webhook = v or ""
            simpanConfig()
            if LblWebhook then LblWebhook:SetText("Webhook: " .. samarkanUrl(Cfg.Webhook)) end
        end)
    end,
})

MiscBox:AddToggle("WebhookAktif", {
    Text = "Discord message on every sale AND snipe",
    Default = Cfg.WebhookAktif,
    Callback = function(v)
        if memuat then return end
        Cfg.WebhookAktif = v
        simpanConfig()
    end,
})

MiscBox:AddButton({ Text = "Send test message", Func = function()
    task.spawn(function()
        local sisa, token = ringkasanJual()
        -- Sengaja dipaksa nyala sesaat: menguji webhook sambil saklarnya mati
        -- akan selalu "gagal" dan itu menyesatkan.
        local semula = Cfg.WebhookAktif
        Cfg.WebhookAktif = true
        local ok, kenapa = kirimWebhook("Test message", {
            { "Item", "Bald Eagle (example)" },
            { "Price", "500 tokens", true },
            { "Buyer", "someone", true },
            { "Total Tokens", ringkas(token or 0), true },
            { "Listings", tostring(sisa or "?") .. "/" .. LISTING_MAKS, true },
        }, 3066993)
        Cfg.WebhookAktif = semula
        catat(ok and "webhook test sent" or ("webhook failed: " .. tostring(kenapa)))
        kabar(ok and "Webhook OK" or "Webhook failed", ok and "check your Discord channel"
            or tostring(kenapa))
    end)
end })

LblWebhook = MiscBox:AddLabel("Webhook: " .. samarkanUrl(Cfg.Webhook)
    .. "  -  covers both what you sell and what the sniper buys.", true)

MiscBox:AddDivider()

-- Trade: satu-satunya fitur di sini yang bisa MENGELUARKAN barang, jadi
-- keterangannya dibuat gamblang di panel, bukan cuma di komentar kode.
MiscBox:AddToggle("AutoTrade", {
    Text = "Auto accept trade requests",
    Default = Cfg.AutoTrade,
    Callback = function(v)
        if memuat then return end
        Cfg.AutoTrade = v
        simpanConfig()
    end,
})

MiscBox:AddInput("TradeDari", {
    Text = "Only from (comma separated)", Default = Cfg.TradeDari,
    Finished = false, Placeholder = "blank = anyone",
    Callback = function(v)
        if memuat then return end
        jadwalkan("__td", function()
            Cfg.TradeDari = v or ""
            simpanConfig()
        end)
    end,
})

MiscBox:AddSlider("JedaTrade", {
    Text = "Wait before answering", Default = Cfg.JedaTrade,
    Min = 0, Max = 15, Rounding = 0, Suffix = "s",
    Callback = function(v)
        if memuat then return end
        Cfg.JedaTrade = v
        simpanConfig()
    end,
})

MiscBox:AddLabel("This script never puts items in a trade, so accepting can "
    .. "only ADD to your account. If your own side is not empty, or the trade "
    .. "state cannot be read, it refuses to confirm.", true)

MiscBox:AddDivider()

MiscBox:AddToggle("BoostFPS", {
    Text = "FPS boost (one-way, needs rejoin to undo)",
    -- Mencerminkan keadaan TERSIMPAN. Sebelumnya selalu tampil OFF walau
    -- tersimpan ON, sehingga panel berbohong soal apa yang akan terjadi
    -- di sesi berikutnya.
    Default = Cfg.BoostFPS,
    Callback = function(v)
        if memuat then return end
        Cfg.BoostFPS = v and true or false
        simpanConfig()
        if not v then
            -- Sapuan itu satu arah -- yang sudah dihapus tidak bisa kembali
            -- tanpa rejoin. Yang bisa dimatikan cuma pengulangan otomatisnya.
            catat("FPS boost will NOT run automatically next session "
                .. "(this session stays boosted until you rejoin)")
            return
        end
        task.spawn(function()
            local ok, ket = boostFPS()
            catat(ok and ("FPS boost: " .. ket) or ("FPS boost: " .. tostring(ket)))
            kabar("FPS boost applied", "rejoin to restore graphics", 5)
        end)
    end,
})

MiscBox:AddSlider("CapFPS", {
    Text = "FPS cap", Default = Cfg.CapFPS,
    Min = 0, Max = 120, Rounding = 0, Suffix = " fps",
    Callback = function(v)
        if memuat then return end
        -- 0 = tanpa batas. Di bawah 5 game praktis berhenti menggambar dan
        -- tombolnya sendiri jadi sulit ditekan, jadi dinaikkan diam-diam ke 5
        -- lalu dipantulkan balik ke slider supaya angkanya jujur.
        local n = math.floor(v)
        if n > 0 and n < 5 then
            n = 5
            memuat = true
            pcall(function() O.CapFPS:SetValue(5) end)
            memuat = false
        end
        Cfg.CapFPS = n
        simpanConfig()
        local ok = terapkanCap()
        catat(ok and ("FPS cap: " .. (n == 0 and "unlimited" or tostring(n)))
            or "executor has no setfpscap")
    end,
})

MiscBox:AddLabel("FPS cap 0 = unlimited, otherwise 5 and up. "
    .. "Booths, anything with an interact prompt, and your own character are "
    .. "never touched -- selling keeps working. Other players' characters, "
    .. "all sounds, textures and shadows ARE removed.", true)


-- =========================================================================
-- ISI ULANG DAFTAR
-- =========================================================================
segarkanDaftar = function(pindaiUlang)
    if pindaiUlang then pindaiPet() end

    local kelompok = kelompokNama()

    -- Config warisan: dulu jenis harus dicentang TERPISAH dari harganya, jadi
    -- ada yang bercentang tanpa harga. Sekarang harga itulah centangnya, jadi
    -- centang tanpa harga dibuang supaya tidak ada penanda yang tidak berarti.
    for nama in pairs(Cfg.PilihNama) do
        if not Cfg.HargaNama[nama] then Cfg.PilihNama[nama] = nil end
    end

    bangunDaftarHarga(kelompok)

    local totalLolos, berharga = 0, 0
    for _, g in ipairs(kelompok) do
        totalLolos = totalLolos + #g.lolos
        if Cfg.HargaNama[g.nama] then berharga = berharga + 1 end
    end

    if LblHarga then LblHarga:SetText(ringkasanHarga()) end
    if LblRingkasan then
        LblRingkasan:SetText(string.format(
            "%d pets | %d pass filters | %d of %d types priced",
            #Daftar, totalLolos, berharga, #kelompok))
    end
end

-- =========================================================================
-- PENYEGAR TAMPILAN
-- =========================================================================
task.spawn(function()
    while not Library.Unloaded and _G.MozeMarketLib == Library do
        local d = dataBooth()
        local punya = boothSaya(d)
        local kosong, terisi = hitungBooth(d)
        local nList, token = ringkasanJual()

        LblBooth:SetText(string.format(
            "My booth: %s\nSkin: %s\nThis server: %d taken, %d free (of 30)",
            punya and string.sub(punya, 1, 8) or "NONE",
            tostring(skinAktif()), terisi, kosong))

        LblAksi:SetText(string.format(
            "Listings %s/%d   |   Tokens %s   |   Sold this session %d",
            tostring(nList or "?"), LISTING_MAKS, ringkas(token or 0), Pantau.totalLaku))

        local menit = (os.time() - Pantau.terakhirLaku) / 60
        LblAuto:SetText(string.format(
            "No buyer for %.1f min (limit %s)\nPlayers here: %d (quiet below %s)\n"
            .. "Tokens earned this session: %s\nBoth conditions must be true before it hops.\n"
            .. "Rejoin URL: %s",
            menit, tostring(Cfg.MenitSepi), #Players:GetPlayers(),
            tostring(Cfg.BatasSepi), ringkas(Pantau.tokenDapat),
            URL_ANTREAN ~= "" and "set" or "EMPTY (script stops after hop)"))

        task.wait(3)
    end
end)

-- Cap diterapkan tiap start, terlepas dari boost: itu setelan berkelanjutan,
-- bukan bagian dari sapuan satu-arah.
terapkanCap()

-- Boost dijalankan sendiri kalau sesi sebelumnya menyalakannya, supaya tidak
-- perlu ditekan ulang tiap rejoin/hop.
if Cfg.BoostFPS then
    task.spawn(function()
        task.wait(3)
        local ok, ket = boostFPS()
        if ok then catat("FPS boost: " .. ket) end
    end)
end

isiSkin()
pindaiPet()
pcall(function()
    local urut = jenisDiKatalog()
    local pilih = {}
    for nama in pairs(Cfg.SnipePet) do pilih[nama] = true end
    local mut, pilihMut = daftarMutasiTersedia(), {}
    for nama in pairs(Cfg.SnipeMutasi) do pilihMut[nama] = true end
    memuat = true
    O.SnipePick:SetValues(urut)
    pcall(function() O.SnipePick:SetValue(pilih) end)
    O.SnipeMutasi:SetValues(mut)
    pcall(function() O.SnipeMutasi:SetValue(pilihMut) end)
    memuat = false
    LblSnipe:SetText(ringkasanSnipe())
end)
segarkanDaftar()

catat("ready. Booth " .. (boothSaya() and "already claimed" or "not claimed yet"))
kabar("Mozeframe Market", #Daftar .. " pets loaded")
print("[MARKET] BUILD 2026-09-04e | Trade World | explicit minimize")

-- @MOZEFRAME-EOF@
