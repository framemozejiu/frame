--[[
=============================================================================
  FISH AN ANIME RNG — FAST RESTART + TOLAK-ROLL (standalone)
  place 74729868188364
=============================================================================

APA YANG DILAKUKAN

Memangkas waktu MATI di sisi client. Satu putaran mancing bentuknya begini
(terekam langsung dari FishingState, bukan dibaca dari nama remote):

    Started    <- server, membawa waitSeconds / targetPos / pondName
       ...menunggu waitSeconds...
    Hooked     <- server, membawa rewardRarity
    FishingClick x2   -> client, jeda antar klik 0,000 dtk
    Completed  <- server
       ...jeda restart milik CLIENT...
    Started    <- putaran berikutnya

Yang bisa diambil cuma jeda restart terakhir itu. Script ini menembak
FishingRequestStart begitu `Completed` datang, tanpa menunggu RestartDelay
bawaan game.

TERUKUR 2026-08-26 di akun sungguhan (83 rebirth), dua jendela ~70 detik:

    Fase           tangkapan   dtk/siklus   jeda restart   waitSeconds
    ------------   ---------   ----------   ------------   -----------
    baseline       42          1,666        0,291 (n=41)   1,219
    restart cepat  51          1,369        0,077 (n=51)   1,172

    -> +21,4% tangkapan. 51 tembakan, 51 diterima, 1:1, tanpa satu pun ditolak.

TOLAK-ROLL — bagian yang paling besar hasilnya

Kuncinya satu kalimat: event Started mengumumkan waitSeconds SEBELUM
penungguan dimulai. Jadi undiannya kelihatan lebih dulu. Dan FishingCancel
diikuti FishingRequestStart menghasilkan undian BARU yang bebas -- terukur
dari 101 penolakan: rata 1,256, min 0,236, maks 2,197.

Ongkos satu reroll: 0,096 dtk rata-rata (min 0,047). Membuang penungguan 2
detik seharga 0,1 detik itu tawaran yang sangat murah.

Sapuan ambang, semua digabung fast restart (tangkapan/menit):

    0,32=29,1   0,40=48,0   0,50=54,8   [0,60=66,8]   0,80=63,4
    1,00=63,0   1,30=53,1                mati=45,0

Optimum 0,6. Di bawah itu ANJLOK -- jumlah reroll naik lebih cepat daripada
waktu yang dihemat. Konfirmasi berpasangan (jendela sama, 40 dtk):
41,99 -> 56,97 per menit = +35,7%.

JANGAN pakai angka +48% yang sempat beredar: itu membandingkan 66,8 dengan
baseline dari jendela LAIN. waitSeconds sendiri berayun 0,25-2,2 dtk, jadi
perbandingan lintas-jendela di game ini selalu menipu. Ukur berpasangan.

Aman sepanjang pengujian: 319 penolakan dalam 35 detik pun tidak memicu kick.

YANG **TIDAK** DILAKUKAN, DAN KENAPA

Tidak menembak lebih dari sekali per `Completed`. Ini bukan sekadar
kehati-hatian -- sudah diuji di akun kosong: **64 tembakan dalam 10 detik
dibalas 3 `Started` saja**, dan `started` persis sama dengan `completed`.
Server hanya mengizinkan SATU putaran aktif per pemain; sisanya dibuang diam-
diam (tanpa error, tanpa balasan). Jadi menembak lebih rapat tidak menambah
satu pun tangkapan, cuma menambah lalu lintas yang mencurigakan.

Tidak menyentuh `waitSeconds`. Itu milik server dan tidak bergeser sama sekali
di pengukuran (1,219 -> 1,172, sedangkan sebarannya sendiri 0,29-2,20 dtk --
selisih itu derau, bukan hasil). Yang memangkasnya cuma upgrade Faster Catch
(Cash) dan potion fast catch, bukan script.

Tidak mempercepat klik saat `Hooked`. INI SUDAH DIUJI DAN GAGAL -- jangan
diulang:

    Hooked -> Completed   baseline        0,091 dtk rata (med 0,066, n=32)
                          klik seketika   0,116 dtk rata (med 0,100, n=35)

Jeda itu ternyata bolak-balik jaringan, bukan client yang menunda. Menembak
lebih awal justru sedikit lebih lambat sekaligus menambah lalu lintas.
(`FishingClick:FireServer()` sendiri tidak menerima argumen apa pun.)

Tidak membanjiri FishingClick SELAMA masa tunggu. Juga sudah diuji dan gagal:
selisih (Hooked datang - waitSeconds dijanjikan) baseline +0,042 dtk (n=34)
vs banjir ~34 klik/siklus +0,057 dtk (n=31). Hooked dikirim server, bukan
dilaporkan client -- itu beda arsitektur dengan game lain yang instant catch-
nya bisa jalan. Tolak-roll berhasil justru karena ia TIDAK melawan server:
ia memakai aturan server sendiri, yaitu meminta undian ulang.

PEMAKAIAN

    -- opsional, boleh dilewat seluruhnya:
    getgenv().MozeFishConfig = { TolakRoll = true, AmbangRoll = 0.6, Gui = true }
    loadstring(game:HttpGet("<url>?t=" .. os.time()))()

Panel kecil muncul di KANAN ATAS: saklar utama, saklar tolak-roll, baris
pengatur ambang (− / nilai / +), plus statistik hidup. Panelnya bisa digeser.
Matikan dengan `Gui = false`.

Baris pengatur: − dan + menggeser 0,05 dtk dan otomatis pindah ke mode
MANUAL; klik angkanya di tengah untuk kembali ke AUTO. Jadi tidak perlu
menyentuh kode sama sekali.

Dua saklarnya sengaja terpisah: fast restart tetap berguna tanpa tolak-roll,
dan tolak-roll yang menaikkan lalu lintas remote -- jadi ia harus bisa
dimatikan sendiri tanpa ikut mematikan yang lain.

BOOST FPS (default MATI -- nyalakan dari tombol di panel)

Default mati karena boost itu SATU ARAH: texture dan GUI yang sudah dihapus
tidak kembali tanpa rejoin. Mematikan tombolnya menghentikan sapuan lanjutan,
tapi tidak memulihkan yang sudah dibuang -- tombolnya menyebut itu.

Terukur di akun sungguhan, 6 pemain di server:

    tahap              FPS      char/menit   PlayerGui   workspace
    ----------------   ------   ----------   ---------   ---------
    asli               66,0     66-67        35.110      88.238
    + efek & texture   84,8     75,0
    + animasi & GUI    115,4    79,1         5.314       55.501
    + peta & plot      194,5    68,2                     31.110

Yang dilakukan: setfpscap(240), matikan bayangan & post-effect, air tanpa
pantulan, matikan semua ParticleEmitter/Trail/lampu, hapus 34 ribu Texture
dan Decal, bekukan animasi (termasuk yang baru dimainkan), buang GUI berat
yang tidak dipakai mancing, dan pangkas plot pemain lain + hiasan peta.

Aturan peta dipilih supaya MUSTAHIL menjatuhkan pemain: hanya BasePart
ber-CanCollide=false yang dibuang. PONDAREA* dikecualikan -- instance-nya
dipakai melempar. Terukur sesudahnya: posisi Y tetap, nyawa penuh, kolam utuh.

Saklar terpisah: BoostFps, BekukanAnimasi, BuangGui, RampingPeta, FpsCap.

PEMBERSIH TALI

Tiap pembatalan meninggalkan Beam "FishingLine" dan Part "FishBall". Terukur
menumpuk sampai 187 dan 169, padahal game merancang MaxBobberLines = 8 --
layar penuh tali, klien berat, dan dari luar terlihat janggal. Script
menyisakan 8 yang TERBARU tiap 5 detik. Tali pemain lain tidak disentuh.
Matikan dengan BersihTali=false.

PENJAGA ROD

Kalau rod terlepas, server membalas { kind="Denied", reason="NO_ROD" } dan
mancing berhenti TANPA error -- gejalanya "tiba-tiba diam". Script mendeteksi
balasan itu, memasang rod ber-Luck tertinggi dari Backpack, lalu melempar
lagi. Dibatasi sekali per 5 detik.

ANTI AFK (default nyala)

Game ini punya rejoin-idle SENDIRI, terpisah dari punya Roblox:
AutoRejoinClient menembak AutoRejoinIdle:FireServer() sesudah 900 detik tanpa
input asli. Itu penyebab "kadang rejoin". Script menyentuh input tiap 60
detik (gerak mouse 1 piksel lalu balik) -- terukur menyalakan InputChanged,
dan gerakan tidak menekan apa pun. Sinyal Player.Idled milik Roblox juga
ditangani. Matikan dengan AntiAfk=false.

Setelan (saklar utama, saklar tolak-roll, ambang manual) DISIMPAN ke
mozefish_setelan.json dan dimuat lagi otomatis sesudah rejoin. Ambang hasil
hitungan AUTO sengaja tidak disimpan -- ia turunan ping & kolam saat itu.
Urutan kuasa: getgenv > berkas simpanan > bawaan. Matikan dengan Simpan=false.

Jalankan lagi berkas yang sama = versi lama dilepas otomatis, tidak menumpuk.
Untuk berhenti sepenuhnya: `getgenv().MozeFishStop()`
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =========================================================================
-- KONFIGURASI
-- Tiap kunci butuh fallback sendiri: tabel dari getgenv() menggantikan tabel
-- ini SELURUHNYA, jadi kunci yang tidak diisi pemakai akan nil, bukan default.
-- =========================================================================
-- SIMPANAN SETELAN
--
-- Rejoin sering di layanan ini, dan tiap rejoin setelan kembali ke default.
-- Berkasnya JSON kecil di folder workspace executor.
--
-- Yang disimpan HANYA yang dipilih manusia (saklar & ambang manual). Ambang
-- hasil hitungan auto TIDAK disimpan: ia turunan dari ping dan sebaran kolam
-- saat itu, dan memuatnya kembali di sesi lain berarti memakai angka yang
-- dihitung untuk keadaan yang sudah lewat.
local BERKAS_SIMPAN = "mozefish_setelan.json"

local function bacaSimpanan()
    -- Executor tanpa isfile/readfile tetap harus jalan, cuma tanpa simpanan.
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return {} end
    local ok, isi = pcall(function()
        if not isfile(BERKAS_SIMPAN) then return nil end
        return readfile(BERKAS_SIMPAN)
    end)
    if not ok or type(isi) ~= "string" or isi == "" then return {} end
    local ok2, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(isi)
    end)
    -- Berkas rusak diperlakukan seperti tidak ada. Jangan pernah menghentikan
    -- script gara-gara satu berkas setelan yang korup.
    if not ok2 or type(data) ~= "table" then return {} end
    return data
end

local SIMPAN = bacaSimpanan()
local U = getgenv().MozeFishConfig or {}

-- Urutan kuasa: getgenv (paling eksplisit) > berkas simpanan > bawaan.
local function pilihSaklar(kunci, bawaan)
    if U[kunci] ~= nil then return U[kunci] ~= false end
    if SIMPAN[kunci] ~= nil then return SIMPAN[kunci] ~= false end
    return bawaan
end

local Config = {
    Aktif         = pilihSaklar("Aktif", true),   -- default NYALA: itu guna script ini
    Lapor         = U.Lapor ~= false,          -- cetak statistik berkala
    IntervalLapor = tonumber(U.IntervalLapor) or 30,

    -- Jeda sebelum menembak. 0 = seketika (yang diukur). Naikkan hanya kalau
    -- kamu memang mau menyamarkan pola; tiap 0,1 dtk di sini langsung
    -- memakan sebagian besar keuntungan 0,21 dtk yang ada.
    JedaTembak    = tonumber(U.JedaTembak) or 0,

    -- Pengaman: kalau sekian tembakan BERUNTUN tidak dibalas `Started` dalam
    -- BatasBalasan detik, script mematikan diri. Ini penjaga kalau server
    -- berubah dan mulai menolak -- lebih baik berhenti sendiri daripada terus
    -- menembak ke tembok.
    MaksGagalBeruntun = tonumber(U.MaksGagalBeruntun) or 5,
    BatasBalasan      = tonumber(U.BatasBalasan) or 3,

    -- ==== TOLAK-ROLL ====
    -- Kunci fiturnya: event `Started` mengumumkan `waitSeconds` SEBELUM
    -- penungguan dimulai. Kalau undiannya jelek, batalkan dan minta undian
    -- baru -- server memang mengizinkannya, dan ongkosnya cuma ~0,096 dtk.
    TolakRoll  = pilihSaklar("TolakRoll", true),
    -- Ambang detik. Roll >= angka ini ditolak.
    -- Terukur (sapuan penuh, semua digabung fast restart, tangkapan/menit):
    --   0,32=29,1  0,40=48,0  0,50=54,8  [0,60=66,8]  0,80=63,4  1,00=63,0  1,30=53,1
    -- Optimum di 0,6. Di bawah itu ANJLOK: jumlah reroll naik lebih cepat
    -- daripada waktu yang dihemat. Jangan diturunkan tanpa mengukur ulang.
    -- Boleh angka (kunci manual) atau "auto" (default). Mode auto MENGUKUR
    -- biaya reroll di koneksi ini lalu menghitung ambang yang paling untung.
    -- Itu sekaligus menyerap ping DAN fps: keduanya muncul sebagai biaya
    -- reroll yang lebih besar, jadi tidak perlu dibaca terpisah.
    AmbangRoll = (function()
        local a = U.AmbangRoll
        if a == nil then a = SIMPAN.AmbangRoll end
        if a == nil then return "auto" end
        return tonumber(a) or a
    end)(),
    -- Jepitan supaya hasil hitungan tidak pernah liar.
    AmbangMin  = tonumber(U.AmbangMin) or 0.35,
    AmbangMaks = tonumber(U.AmbangMaks) or 2.50,
    -- Dipakai sebelum sampel cukup. 1,0 sengaja konservatif: masih menang
    -- jelas atas mati, tapi tidak agresif di koneksi yang belum terukur.
    AmbangAwal = tonumber(U.AmbangAwal) or 1.0,
    -- Besar satu ketukan tombol - / + di panel.
    LangkahAmbang = tonumber(U.LangkahAmbang) or 0.05,
    -- Pengaman anti-loop: kalau sekian roll BERUNTUN ditolak, terima saja yang
    -- berikutnya. Menjaga dari keadaan yang belum pernah terlihat -- misalnya
    -- server berhenti mengacak dan selalu mengirim angka besar. Tanpa ini,
    -- script bisa membatalkan selamanya dan MALAH tidak menangkap apa pun.
    MaksTolakBeruntun = tonumber(U.MaksTolakBeruntun) or 25,

    -- ==== BOOST FPS ====
    -- Sasarannya perangkat yang menjalankan banyak klien sekaligus.
    -- DEFAULT MATI, dan sengaja. Boost itu SATU ARAH: texture dan GUI yang
    -- sudah dihapus tidak bisa dikembalikan tanpa rejoin. Fitur yang tidak
    -- bisa dibatalkan tidak boleh menyala tanpa diminta.
    BoostFps        = pilihSaklar("BoostFps", false),
    FpsCap          = tonumber(U.FpsCap) or 240,
    BekukanAnimasi  = pilihSaklar("BekukanAnimasi", true),
    BuangGui        = pilihSaklar("BuangGui", true),
    RampingPeta     = pilihSaklar("RampingPeta", true),

    -- ==== PEMBERSIH TALI ====
    -- Tiap pembatalan meninggalkan Beam "FishingLine" dan Part "FishBall".
    -- Terukur di akun sungguhan: menumpuk sampai 187 tali dan 169 pelampung,
    -- padahal game merancang MaxBobberLines = 8. Selain memberati klien, itu
    -- juga yang membuat layar penuh tali dan terlihat janggal dari luar.
    BersihTali = pilihSaklar("BersihTali", true),
    MaksTali   = tonumber(U.MaksTali) or 8,

    -- ==== ANTI AFK ====
    -- Game ini punya rejoin-idle sendiri: AutoRejoinClient menembak
    -- AutoRejoinIdle:FireServer() sesudah 900 detik TANPA INPUT ASLI, dan
    -- server memulangkanmu. Itu penyebab "kadang rejoin".
    AntiAfk = pilihSaklar("AntiAfk", true),
    -- Jeda antar sentuhan. 60 dtk memberi 15x margin terhadap batas 900 dtk,
    -- jadi satu-dua kali gagal pun tidak berakibat apa-apa.
    JedaAntiAfk = tonumber(U.JedaAntiAfk) or 60,

    -- Matikan kalau tidak mau script menulis berkas apa pun.
    Simpan = pilihSaklar("Simpan", true),

    Gui = U.Gui ~= false,   -- panel kecil di kanan atas
}

local function tulisSimpanan()
    if not Config.Simpan then return end
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(BERKAS_SIMPAN, game:GetService("HttpService"):JSONEncode({
            Aktif      = Config.Aktif,
            TolakRoll  = Config.TolakRoll,
            AmbangRoll = Config.AmbangRoll,
            BoostFps   = Config.BoostFps,
        }))
    end)
end

-- =========================================================================
-- LEPAS VERSI LAMA
-- Tanpa ini, menjalankan script dua kali membuat DUA listener menembak untuk
-- satu `Completed` yang sama. Tembakan kedua memang dibuang server, tapi
-- statistiknya jadi bohong dan polanya jadi ramai tanpa guna.
if type(getgenv().MozeFishStop) == "function" then
    pcall(getgenv().MozeFishStop)
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
if not Remotes then
    warn("[MozeFish] Remotes tidak ketemu — script berhenti.")
    return
end

local FishingState        = Remotes:WaitForChild("FishingState", 20)
local FishingRequestStart = Remotes:WaitForChild("FishingRequestStart", 20)
-- Boleh nil: kalau remote ini tidak ada, tolak-roll dimatikan sendiri di bawah
-- dan fast restart tetap jalan. Fitur tambahan tidak boleh menjatuhkan yang inti.
local FishingCancel       = Remotes:FindFirstChild("FishingCancel", true)
if not (FishingState and FishingRequestStart) then
    warn("[MozeFish] Remote mancing tidak lengkap — script berhenti.")
    return
end

-- =========================================================================
-- KEADAAN
local S = {
    hidup       = true,
    pond        = nil,   -- Instance, DIBACA dari event Started
    target      = nil,   -- Vector3, dibaca dari event Started
    pondName    = nil,
    menunggu    = nil,   -- os.clock() saat menembak, nil kalau tidak menunggu
    gagalBeruntun = 0,

    frame       = 0,   -- pencacah frame untuk FPS realtime
    fps         = 0,
    taliDibuang = 0,   -- total tali/pelampung basi yang dibersihkan
    rodPasang   = 0,   -- berapa kali rod dipasang ulang otomatis
    tDitolak    = nil, -- kapan Denied terakhir, untuk membatasi laju
    afkSentuh   = 0,   -- berapa kali anti-afk menyentuh input
    afkGagal    = 0,
    tolak       = 0,   -- roll dibuang seumur sesi
    tolakBeruntun = 0, -- dipakai pengaman anti-loop

    -- Bahan penyetel otomatis.
    sampelWait  = {},  -- cincin: waitSeconds yang pernah terlihat
    iWait       = 0,
    -- Biaya reroll dilacak sebagai rata-rata BERGERAK (EWMA), bukan rata-rata
    -- seumur sesi. Bedanya penting: ping bisa berubah di tengah main, dan
    -- rata-rata seumur sesi makin lama makin kaku -- sesudah 500 sampel, satu
    -- jam dengan ping dua kali lipat nyaris tidak menggeser angkanya.
    biaya       = nil, -- detik; nil = belum ada sampel
    biayaN      = 0,   -- cacah, hanya untuk gerbang "sampel cukup"
    tTolak      = nil, -- os.clock() saat menembak ulang karena menolak
    ambangAktif = nil, -- hasil hitungan terakhir (nil = belum ada)
    hitungSejak = 0,   -- berapa roll sejak terakhir dihitung ulang
    siklus      = 0,
    tembak      = 0,
    diterima    = 0,
    jumRestart  = 0,
    nRestart    = 0,
    tCompleted  = nil,
    -- Sengaja nil: jam baru dimulai pada tangkapan PERTAMA, bukan saat script
    -- dimuat. Kalau dihitung sejak muat, detik-detik awal (sebelum event
    -- Started pertama memberi pond & posisi) ikut masuk rata-rata, dan panel
    -- menampilkan angka yang jauh lebih buruk dari kenyataan.
    tMulai      = nil,
    conn        = {},
}

local function catat(fmt, ...)
    print("[MozeFish] " .. string.format(fmt, ...))
end

-- =========================================================================
-- PENEMBAK
--
-- Syarat pond DAN target wajib ada. Keduanya datang dari event `Started`,
-- TIDAK boleh ditulis mati: nama pond berbeda per area (di akun uji
-- "PONDAREA1"), dan menembak dengan pond yang salah berarti server mengabaikan
-- panggilannya diam-diam -- gejalanya "script tidak melakukan apa-apa" tanpa
-- satu pun error.
local function tembak()
    if not (S.hidup and Config.Aktif) then return end
    if not (S.pond and S.target) then return end
    -- Kolam bisa lenyap saat pindah area; pegangan lama menembak ke instance
    -- mati dan diabaikan server tanpa error. Lepas, biar dibaca ulang.
    if S.pond.Parent == nil then
        S.pond = nil
        return
    end

    S.tembak = S.tembak + 1
    S.menunggu = os.clock()
    pcall(function()
        FishingRequestStart:FireServer(S.pond, S.target)
    end)
end

-- =========================================================================
-- PENJAGA ROD
--
-- Terukur di akun sungguhan: server membalas lemparan dengan
--     { kind = "Denied", reason = "NO_ROD" }
-- kalau tidak ada rod tergenggam. Rod BISA terlepas di tengah main (terjadi
-- sesudah rentetan equip karakter dari backpack), dan begitu itu terjadi
-- script diam total tanpa satu pun error -- gejalanya "tiba-tiba berhenti
-- mancing" yang mustahil ditebak dari luar.
--
-- Rod terbaik dipilih dari Constants.Fishing.Rods menurut Luck, bukan dari
-- urutan di Backpack: urutan itu tidak berarti apa-apa.
local function pasangRodTerbaik()
    local ok = pcall(function()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        local bp = lp:FindFirstChild("Backpack")
        local ch = lp.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not (bp and hum) then return end

        local dataRod = {}
        pcall(function()
            dataRod = require(ReplicatedStorage.Constants).Fishing.Rods or {}
        end)

        local pilih, luckPilih = nil, -1
        for _, alat in ipairs(bp:GetChildren()) do
            if alat:IsA("Tool") then
                local d = dataRod[alat.Name]
                if d then
                    local luck = tonumber(d.Luck) or 0
                    if luck > luckPilih then pilih, luckPilih = alat, luck end
                end
            end
        end
        if not pilih then return end

        hum:EquipTool(pilih)
        S.rodPasang = S.rodPasang + 1
        catat("rod terlepas -> dipasang ulang: %s (luck %d)", pilih.Name, luckPilih)
    end)
    return ok
end

-- Wadah GUI dideklarasikan DI SINI, bukan di blok GUI jauh di bawah.
-- Pendengar di bawah memanggil Gui.ada / Gui.catRoll, dan kalau local-nya
-- baru muncul setelah itu, yang terbaca adalah global nil -- handler-nya
-- melempar error dan tolak-roll mati diam-diam. Ketahuan dari luau-analyze
-- (LocalShadow), bukan dari mata.
local Gui = { ada = false }

-- Dideklarasikan di sini, bukan di modul boost jauh di bawah: panel dibangun
-- SEBELUM modul itu, dan tombolnya perlu memanggil Boost.jalankan.
local Boost = { efek = 0, texture = 0, anim = 0, gui = 0, peta = 0,
                sudahJalan = false, jalankan = nil, conn = {} }

-- =========================================================================
-- PENYETEL AMBANG OTOMATIS
--
-- Modelnya sederhana dan seluruhnya dari angka yang TERUKUR di sesi ini:
--
--     biaya siklus(T) = (1/p - 1) * C  +  rata waitSeconds yang diterima
--
-- p  = peluang sebuah roll diterima pada ambang T (dari sampel nyata)
-- C  = biaya satu reroll, diukur dari jarak tembakan-ulang ke Started
--      berikutnya -- angka inilah yang membawa pengaruh ping dan fps.
--
-- Ongkos tetap lain (jaringan Hooked->Completed, jeda restart) sengaja tidak
-- ikut: nilainya sama untuk semua T, jadi tidak mengubah pemenangnya.
--
-- Kandidat ambang diambil dari sampel itu sendiri: kalau kita menerima k
-- sampel terkecil, ambangnya harus berada di antara sampel ke-k dan ke-k+1.
-- Cara ini tidak pernah mengarang angka yang tidak pernah terjadi.
local function hitungAmbang()
    local n = #S.sampelWait
    if n < 20 or S.biayaN < 5 or not S.biaya then return nil end   -- sampel belum cukup

    local w = table.clone(S.sampelWait)
    table.sort(w)
    local C = S.biaya

    local jum, terbaik, kBaik = 0, math.huge, 1
    for k = 1, n do
        jum = jum + w[k]
        local p = k / n
        local nilai = (1 / p - 1) * C + (jum / k)
        if nilai < terbaik then terbaik, kBaik = nilai, k end
    end

    -- Ambang diletakkan DI ANTARA sampel ke-k dan berikutnya. Menaruhnya
    -- persis di w[k] akan menolak sampel itu sendiri (syaratnya `w >= ambang`)
    -- dan diam-diam menerima satu lebih sedikit dari yang dihitung.
    local t
    if kBaik < n then t = (w[kBaik] + w[kBaik + 1]) / 2 else t = w[n] + 0.01 end
    return math.max(Config.AmbangMin, math.min(Config.AmbangMaks, t))
end

-- Ambang yang BERLAKU sekarang: angka manual kalau diisi, hasil hitungan
-- kalau mode auto, dan AmbangAwal selama sampel belum cukup.
local function ambang()
    local manual = tonumber(Config.AmbangRoll)
    if manual then return manual end
    return S.ambangAktif or Config.AmbangAwal
end

-- =========================================================================
-- PENDENGAR
S.conn[#S.conn + 1] = FishingState.OnClientEvent:Connect(function(d)
    if typeof(d) ~= "table" then return end
    local kind = tostring(d.kind)
    local t = os.clock()

    if kind == "Denied" then
        -- Dibatasi 5 detik sekali: kalau sebabnya bukan rod, mengulang
        -- pemasangan secepat lemparan ditolak cuma menghasilkan banjir.
        if tostring(d.reason) == "NO_ROD"
           and (not S.tDitolak or (t - S.tDitolak) > 5) then
            S.tDitolak = t
            pasangRodTerbaik()
            -- Lempar lagi supaya siklus tidak menunggu pemicu berikutnya;
            -- tanpa ini script bisa diam sampai ada Started dari mana pun.
            task.delay(1, tembak)
        end
        return
    end

    if kind == "Started" then
        -- Selalu segarkan: pemain bisa pindah kolam, dan targetPos ikut geser.
        if d.targetPos then S.target = d.targetPos end
        if d.pondName and d.pondName ~= S.pondName then
            S.pondName = d.pondName
            S.pond = workspace:FindFirstChild(d.pondName, true)

            -- Kolam berganti = sebaran waitSeconds berganti. Terukur di
            -- Constants.Fishing.Ponds: tiap kolam punya PondCatchTimeMulti
            -- sendiri (PONDAREA2 misalnya 0,8 sedangkan PONDAREA1 nol).
            -- Menyimpan sampel kolam lama membuat ambangnya dihitung dari
            -- sebaran yang sudah tidak berlaku -- salah tanpa satu pun error.
            -- Biaya reroll TIDAK ikut dibuang: itu milik koneksi, bukan kolam.
            S.sampelWait = {}
            S.iWait = 0
            S.hitungSejak = 0
            S.ambangAktif = nil
            if Gui.ada then
                pcall(Gui.catRoll)
                pcall(Gui.catNilai)
            end
        end

        if S.menunggu then
            -- Balasan atas tembakan kita.
            S.diterima = S.diterima + 1
            S.gagalBeruntun = 0
            S.menunggu = nil
        end
        if S.tCompleted then
            S.jumRestart = S.jumRestart + (t - S.tCompleted)
            S.nRestart = S.nRestart + 1
            S.tCompleted = nil
        end

        -- ---- TOLAK-ROLL ----
        -- Keputusan ini HARUS diambil sekarang, di dalam handler Started:
        -- begitu kita kembali dari sini penungguan sudah berjalan, dan
        -- satu-satunya pilihan tinggal menunggu sampai habis.
        local w = tonumber(d.waitSeconds)

        -- Biaya reroll: jarak dari tembakan-ulang ke Started ini. Diukur
        -- terus-menerus, jadi ia ikut bergerak kalau ping/fps berubah.
        if S.tTolak then
            local biaya = t - S.tTolak
            S.tTolak = nil
            -- Buang pencilan: > 2 dtk hampir pasti lag sesaat, bukan biaya
            -- normal, dan satu angka begitu bisa menggeser rata-rata jauh.
            if biaya > 0 and biaya < 2 then
                if S.biaya then
                    -- alfa 0,15: cukup gesit mengikuti perubahan ping, tapi
                    -- tidak terlempar oleh satu paket yang kebetulan telat.
                    S.biaya = S.biaya + 0.15 * (biaya - S.biaya)
                else
                    S.biaya = biaya
                end
                S.biayaN = S.biayaN + 1
            end
        end

        if w then
            -- Cincin 80 sampel: cukup untuk bentuk sebarannya, dan tetap
            -- mengikuti kalau kolam/keadaan berganti.
            S.iWait = (S.iWait % 80) + 1
            S.sampelWait[S.iWait] = w
            S.hitungSejak = S.hitungSejak + 1
            if S.hitungSejak >= 10 then
                S.hitungSejak = 0
                local baru = hitungAmbang()
                if baru then
                    S.ambangAktif = baru
                    if Gui.ada then
                        pcall(Gui.catRoll)
                        pcall(Gui.catNilai)
                    end
                end
            end
        end

        if Config.TolakRoll and FishingCancel and w and S.pond and S.target
           and w >= ambang()
           and S.tolakBeruntun < Config.MaksTolakBeruntun then
            S.tolak = S.tolak + 1
            S.tolakBeruntun = S.tolakBeruntun + 1
            S.tTolak = t
            pcall(function() FishingCancel:FireServer() end)
            tembak()
            return
        end

        -- Hitungan beruntun HANYA disetel ulang kalau roll ini diterima karena
        -- memang bagus -- bukan karena pengaman anti-loop memaksa menerimanya.
        --
        -- Beda ini penting dan sempat salah: kalau penerimaan paksa ikut me-reset,
        -- roll jelek berikutnya langsung ditolak lagi, dan polanya jadi
        -- "tolak 25, terima 1, tolak 25, terima 1" selamanya. Pengamannya jadi
        -- hiasan. Dengan cara ini, sekali mentok script berhenti melawan sampai
        -- benar-benar datang roll bagus.
        if w and w < ambang() then
            S.tolakBeruntun = 0
        end

    elseif kind == "Completed" then
        if not S.tMulai then S.tMulai = t end
        S.siklus = S.siklus + 1
        S.tCompleted = t

        -- SATU tembakan. Tidak pernah lebih -- lihat catatan 64:3 di atas.
        if Config.JedaTembak > 0 then
            task.delay(Config.JedaTembak, tembak)
        else
            tembak()
        end
    end
end)

-- =========================================================================
-- GUI — panel kecil di kanan atas
--
-- Seluruhnya dibungkus pcall: kalau executor tidak mengizinkan salah satu
-- langkah, script INTINYA harus tetap jalan. Fitur kecepatan tidak boleh mati
-- gara-gara satu tombol gagal digambar.
local function bangunGui()
    if not Config.Gui then return end

    -- Urutan induk: gethui() paling aman dari pemindaian game, CoreGui
    -- cadangannya, PlayerGui pilihan terakhir (ikut kehapus saat respawn,
    -- karena itu ResetOnSpawn dimatikan).
    local induk
    pcall(function() induk = gethui and gethui() end)
    if not induk then pcall(function() induk = game:GetService("CoreGui") end) end
    if not induk then
        pcall(function() induk = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5) end)
    end
    if not induk then return end

    -- Palet dikumpulkan di satu tempat supaya warna tidak berserakan sebagai
    -- angka ajaib di dua puluh baris berbeda.
    local W = {
        latar     = Color3.fromRGB(16, 18, 24),
        kepala    = Color3.fromRGB(23, 26, 34),
        garis     = Color3.fromRGB(52, 58, 74),
        terang    = Color3.fromRGB(232, 237, 245),
        redup     = Color3.fromRGB(132, 140, 158),
        hijau     = Color3.fromRGB(38, 166, 91),
        merah     = Color3.fromRGB(168, 52, 46),
        biru      = Color3.fromRGB(38, 116, 180),
        ungu      = Color3.fromRGB(84, 66, 128),
        tombol    = Color3.fromRGB(38, 42, 54),
    }

    local sg = Instance.new("ScreenGui")
    sg.Name = "MozeFishUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 9999
    sg.Parent = induk

    local LEBAR, TINGGI, TINGGI_KECIL = 212, 182, 32

    local bingkai = Instance.new("Frame")
    bingkai.Name = "Panel"
    bingkai.AnchorPoint = Vector2.new(1, 0)
    bingkai.Position = UDim2.new(1, -12, 0, 12)   -- KANAN ATAS
    bingkai.Size = UDim2.fromOffset(LEBAR, TINGGI)
    bingkai.BackgroundColor3 = W.latar
    bingkai.BackgroundTransparency = 0.06
    bingkai.BorderSizePixel = 0
    bingkai.Active = true
    bingkai.Draggable = true                      -- boleh digeser kalau menutupi HUD
    bingkai.Parent = sg

    local function sudut(inst, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r)
        c.Parent = inst
        return c
    end
    sudut(bingkai, 10)

    local garis = Instance.new("UIStroke")
    garis.Color = W.garis
    garis.Thickness = 1
    garis.Parent = bingkai

    -- ---- KEPALA ----
    local kepala = Instance.new("Frame")
    kepala.Name = "Kepala"
    kepala.Size = UDim2.new(1, 0, 0, TINGGI_KECIL)
    kepala.BackgroundColor3 = W.kepala
    kepala.BorderSizePixel = 0
    kepala.Parent = bingkai
    sudut(kepala, 10)

    -- Menutup lengkung bawah kepala supaya sambungannya rata, bukan bulat dua kali.
    local tambal = Instance.new("Frame")
    tambal.Size = UDim2.new(1, 0, 0, 10)
    tambal.Position = UDim2.new(0, 0, 1, -10)
    tambal.BackgroundColor3 = W.kepala
    tambal.BorderSizePixel = 0
    tambal.Parent = kepala

    local titik = Instance.new("Frame")
    titik.Name = "Titik"
    titik.Size = UDim2.fromOffset(8, 8)
    titik.Position = UDim2.fromOffset(12, 12)
    titik.BackgroundColor3 = W.hijau
    titik.BorderSizePixel = 0
    titik.ZIndex = 2
    titik.Parent = kepala
    sudut(titik, 4)

    local judul = Instance.new("TextLabel")
    judul.BackgroundTransparency = 1
    judul.Position = UDim2.fromOffset(28, 0)
    judul.Size = UDim2.new(1, -66, 1, 0)
    judul.Font = Enum.Font.GothamBold
    judul.TextSize = 12
    judul.TextXAlignment = Enum.TextXAlignment.Left
    judul.TextColor3 = W.terang
    judul.Text = "MozeFish"
    judul.ZIndex = 2
    judul.Parent = kepala

    local labelFps = Instance.new("TextLabel")
    labelFps.Name = "Fps"
    labelFps.BackgroundTransparency = 1
    labelFps.Position = UDim2.new(1, -86, 0, 0)
    labelFps.Size = UDim2.fromOffset(50, TINGGI_KECIL)
    labelFps.Font = Enum.Font.Code
    labelFps.TextSize = 11
    labelFps.TextXAlignment = Enum.TextXAlignment.Right
    labelFps.TextColor3 = W.redup
    labelFps.Text = "-- fps"
    labelFps.ZIndex = 2
    labelFps.Parent = kepala

    local tKecil = Instance.new("TextButton")
    tKecil.Name = "Kecilkan"
    tKecil.Size = UDim2.fromOffset(24, 20)
    tKecil.Position = UDim2.new(1, -32, 0, 6)
    tKecil.BackgroundColor3 = W.tombol
    tKecil.BorderSizePixel = 0
    tKecil.Font = Enum.Font.GothamBold
    tKecil.TextSize = 13
    tKecil.TextColor3 = W.redup
    tKecil.Text = "–"
    tKecil.AutoButtonColor = true
    tKecil.ZIndex = 2
    tKecil.Parent = kepala
    sudut(tKecil, 5)

    -- ---- ISI (bisa disembunyikan) ----
    local isi = Instance.new("Frame")
    isi.Name = "Isi"
    isi.BackgroundTransparency = 1
    isi.Position = UDim2.fromOffset(0, TINGGI_KECIL)
    isi.Size = UDim2.new(1, 0, 1, -TINGGI_KECIL)
    isi.Parent = bingkai

    -- Angka besar: ini satu-satunya angka yang benar-benar dipedulikan pemakai,
    -- jadi ia yang dibesarkan. Sisanya menyusut jadi keterangan.
    local angka = Instance.new("TextLabel")
    angka.Name = "Angka"
    angka.BackgroundTransparency = 1
    angka.Position = UDim2.fromOffset(14, 4)
    angka.Size = UDim2.fromOffset(96, 30)
    angka.Font = Enum.Font.GothamBold
    angka.TextSize = 24
    angka.TextXAlignment = Enum.TextXAlignment.Left
    angka.TextColor3 = W.terang
    angka.Text = "--"
    angka.Parent = isi

    local satuan = Instance.new("TextLabel")
    satuan.BackgroundTransparency = 1
    satuan.Position = UDim2.fromOffset(112, 12)
    satuan.Size = UDim2.fromOffset(86, 18)
    satuan.Font = Enum.Font.Gotham
    satuan.TextSize = 10
    satuan.TextXAlignment = Enum.TextXAlignment.Left
    satuan.TextColor3 = W.redup
    satuan.Text = "character / menit"
    satuan.Parent = isi

    local rinci = Instance.new("TextLabel")
    rinci.Name = "Statistik"
    rinci.BackgroundTransparency = 1
    rinci.Position = UDim2.fromOffset(14, 34)
    rinci.Size = UDim2.new(1, -28, 0, 13)
    rinci.Font = Enum.Font.Code
    rinci.TextSize = 10
    rinci.TextXAlignment = Enum.TextXAlignment.Left
    rinci.TextColor3 = W.redup
    rinci.Text = "menunggu siklus pertama..."
    rinci.Parent = isi

    local function pil(nama, x, lebar, y, tinggi)
        local b = Instance.new("TextButton")
        b.Name = nama
        b.Position = UDim2.fromOffset(x, y)
        b.Size = UDim2.fromOffset(lebar, tinggi)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.AutoButtonColor = true
        b.BorderSizePixel = 0
        b.BackgroundColor3 = W.tombol
        b.TextColor3 = W.terang
        b.Parent = isi
        sudut(b, 6)
        return b
    end

    local tombol     = pil("Saklar", 14, 88, 54, 26)
    local tombolRoll = pil("SaklarRoll", 110, 88, 54, 26)
    local bKurang    = pil("Kurang", 14, 30, 88, 24)
    local bNilai     = pil("Nilai", 50, 112, 88, 24)
    local bTambah    = pil("Tambah", 168, 30, 88, 24)
    bKurang.Text = "−"
    bTambah.Text = "+"
    bNilai.TextSize = 10

    local bBoost = pil("Boost", 14, 184, 118, 24)
    bBoost.TextSize = 11

    -- Warna mengikuti angkanya supaya bisa dinilai sekilas tanpa dibaca:
    -- di layar penuh 8-10 klien, membaca angka satu per satu tidak praktis.
    local function catFps(nilai)
        labelFps.Text = string.format("%d fps", math.floor(nilai + 0.5))
        if nilai >= 100 then labelFps.TextColor3 = W.hijau
        elseif nilai >= 45 then labelFps.TextColor3 = Color3.fromRGB(190, 160, 60)
        else labelFps.TextColor3 = W.merah end
    end

    -- ---- PEWARNA ----
    local function cat()
        if Config.Aktif then
            tombol.Text = "AKTIF"
            tombol.BackgroundColor3 = W.hijau
            titik.BackgroundColor3 = W.hijau
        else
            tombol.Text = "MATI"
            tombol.BackgroundColor3 = W.merah
            titik.BackgroundColor3 = W.merah
        end
    end

    local function catRoll()
        if not FishingCancel then
            tombolRoll.Text = "ROLL: N/A"
            tombolRoll.BackgroundColor3 = W.tombol
            tombolRoll.TextColor3 = W.redup
        elseif Config.TolakRoll then
            tombolRoll.Text = "TOLAK-ROLL"
            tombolRoll.BackgroundColor3 = W.biru
            tombolRoll.TextColor3 = W.terang
        else
            tombolRoll.Text = "ROLL: MATI"
            tombolRoll.BackgroundColor3 = W.ungu
            tombolRoll.TextColor3 = W.terang
        end
    end

    local function catNilai()
        local manual = tonumber(Config.AmbangRoll)
        if manual then
            bNilai.Text = string.format("%.2fs  manual", manual)
            bNilai.BackgroundColor3 = W.ungu
        else
            bNilai.Text = string.format("%.2fs  AUTO", S.ambangAktif or Config.AmbangAwal)
            bNilai.BackgroundColor3 = Color3.fromRGB(28, 54, 70)
        end
    end

    -- Statistik dipecah: angka besar terpisah dari keterangan kecil, jadi
    -- pemanggil tidak perlu tahu susunan panelnya.
    local function catStat(ikanPerMenit, siklus, tolak, biaya)
        angka.Text = string.format("%.1f", ikanPerMenit or 0)
        rinci.Text = string.format("%d character · buang %d · %s",
            siklus or 0, tolak or 0,
            biaya and string.format("%.0fms", biaya * 1000) or "--")
    end

    local function catBoost()
        if Config.BoostFps then
            bBoost.Text = Boost.sudahJalan and "BOOST FPS: JALAN" or "BOOST FPS: ON"
            bBoost.BackgroundColor3 = Color3.fromRGB(150, 96, 24)
            bBoost.TextColor3 = Color3.fromRGB(255, 240, 220)
        else
            bBoost.Text = Boost.sudahJalan and "BOOST: OFF (rejoin utk pulih)"
                or "BOOST FPS: OFF"
            bBoost.BackgroundColor3 = W.tombol
            bBoost.TextColor3 = W.redup
        end
    end

    -- ---- PERILAKU ----
    tombol.Activated:Connect(function()
        Config.Aktif = not Config.Aktif
        -- Menyalakan lagi = beri kesempatan baru. Tanpa ini, penjaga yang
        -- sudah menghitung 5 kegagalan akan langsung mematikannya kembali.
        if Config.Aktif then S.gagalBeruntun = 0 end
        cat()
        tulisSimpanan()
    end)

    tombolRoll.Activated:Connect(function()
        if not FishingCancel then return end
        Config.TolakRoll = not Config.TolakRoll
        S.tolakBeruntun = 0
        catRoll()
        tulisSimpanan()
    end)

    -- Menggeser = pindah ke manual, dimulai dari angka yang SEDANG berlaku.
    -- Kalau dimulai dari nilai default, satu ketukan bisa melompat jauh dari
    -- yang sedang dipakai dan terasa seperti tombolnya rusak.
    local function geser(arah)
        local sekarang = tonumber(Config.AmbangRoll) or S.ambangAktif or Config.AmbangAwal
        local baru = sekarang + arah * Config.LangkahAmbang
        baru = math.max(Config.AmbangMin, math.min(Config.AmbangMaks, baru))
        Config.AmbangRoll = math.floor(baru * 100 + 0.5) / 100
        S.tolakBeruntun = 0
        catNilai()
        catRoll()
        tulisSimpanan()
    end

    bKurang.Activated:Connect(function() geser(-1) end)
    bTambah.Activated:Connect(function() geser(1) end)
    bBoost.Activated:Connect(function()
        Config.BoostFps = not Config.BoostFps
        if Config.BoostFps and Boost.jalankan then
            task.spawn(function()
                Boost.jalankan()
                catBoost()
            end)
        end
        catBoost()
        tulisSimpanan()
    end)

    bNilai.Activated:Connect(function()
        -- Klik nilainya = kembali ke AUTO.
        Config.AmbangRoll = "auto"
        S.tolakBeruntun = 0
        catNilai()
        catRoll()
        tulisSimpanan()
    end)

    -- Kecilkan: berguna saat menjalankan banyak klien sekaligus -- panel yang
    -- menumpuk di tiap jendela lebih mengganggu daripada membantu.
    local kecil = false
    tKecil.Activated:Connect(function()
        kecil = not kecil
        isi.Visible = not kecil
        bingkai.Size = UDim2.fromOffset(LEBAR, kecil and TINGGI_KECIL or TINGGI)
        tKecil.Text = kecil and "+" or "–"
    end)

    cat()
    catRoll()
    catNilai()
    catBoost()

    Gui.ada = true
    Gui.sg = sg
    Gui.cat = cat
    Gui.catRoll = catRoll
    Gui.catNilai = catNilai
    Gui.catStat = catStat
    Gui.catFps = catFps
    Gui.catBoost = catBoost
    Gui.statistik = rinci   -- dipertahankan: ada kode lama yang menyentuhnya
end

pcall(bangunGui)

-- =========================================================================
-- ANTI AFK
--
-- Dua idle yang berbeda, dan satu sentuhan mengurus keduanya:
--
--   1. Milik GAME. AutoRejoinClient menyimpan waktu input terakhir, lalu
--      menembak AutoRejoinIdle:FireServer() sesudah 900 detik. Fungsi
--      bump()-nya tersambung ke InputBegan, InputChanged, DAN WindowFocused.
--   2. Milik ROBLOX. Pemain menganggur ~20 menit diputus sendiri.
--
-- Yang dipakai GERAKAN MOUSE, bukan tombol. Terukur: SendMouseMoveEvent
-- menyalakan InputChanged 3 dari 3 kali, dan gerakan tidak menekan apa pun --
-- sedangkan SendKeyEvent bisa memicu hotkey game tanpa sengaja.
--
-- Menembak langsung koneksi InputBegan/InputChanged sengaja TIDAK dipakai:
-- terukur ada 68 dan 61 koneksi di sana, hampir semuanya milik game, dan
-- memanggil semuanya dengan argumen karangan itu mengundang kerusakan.
--
-- Catatan: AutoRejoinClient melewatkan bump kalau _G.__AntiIdleSyntheticAt
-- baru saja diisi. Terukur, TIDAK ADA satu pun script game yang mengisinya,
-- jadi penjaga itu menganggur. Script ini pun tidak pernah mengisinya.
local function sentuhInput()
    local ok = pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        local UIS = game:GetService("UserInputService")
        local m = UIS:GetMouseLocation()
        -- Geser satu piksel lalu kembali: cukup untuk memicu InputChanged,
        -- dan posisi akhirnya sama dengan semula supaya tidak mengganggu
        -- kalau kebetulan mesinnya sedang dipakai.
        VIM:SendMouseMoveEvent(m.X + 1, m.Y, game)
        task.wait(0.06)
        VIM:SendMouseMoveEvent(m.X, m.Y, game)
    end)
    if ok then S.afkSentuh = S.afkSentuh + 1 else S.afkGagal = S.afkGagal + 1 end
    return ok
end

if Config.AntiAfk then
    -- Jalur Roblox: sinyal Idled datang tepat sebelum diputus. VirtualUser
    -- dipakai di sini karena itu yang dikenali penghitung idle Roblox.
    pcall(function()
        local LocalPlayer = game:GetService("Players").LocalPlayer
        S.conn[#S.conn + 1] = LocalPlayer.Idled:Connect(function()
            if not S.hidup then return end
            pcall(function()
                local VU = game:GetService("VirtualUser")
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
            sentuhInput()
            catat("anti-afk: sinyal Idled ditangani")
        end)
    end)

    -- Jalur game: sentuh berkala jauh sebelum 900 detik.
    task.spawn(function()
        -- Sentuh sekali di awal supaya jam idle mulai dari sekarang, bukan
        -- dari kapan pun input asli terakhir terjadi sebelum script dimuat.
        sentuhInput()
        while S.hidup do
            task.wait(math.max(10, Config.JedaAntiAfk))
            if S.hidup and Config.AntiAfk then sentuhInput() end
        end
    end)
end

-- =========================================================================
-- PENJAGA
-- =========================================================================
-- BOOST FPS
--
-- Sasarannya perangkat yang menjalankan banyak klien sekaligus: di sana render
-- adalah pemakan CPU terbesar, sedangkan bot tidak butuh gambar bagus sama
-- sekali.
--
-- TERUKUR di akun sungguhan, 6 pemain di server:
--
--     tahap            FPS      character/menit   PlayerGui   workspace
--     --------------   ------   ---------------   ---------   ---------
--     asli             66,0     66-67             35.110      88.238
--     + efek/texture   84,8     75,0
--     + animasi/GUI    115,4    79,1              5.314       55.501
--
-- Catatan penting: tangkapan per menit ikut NAIK, bukan turun. Jadi ini bukan
-- pertukaran -- tidak ada yang dikorbankan selain tampilan.
--
-- Tiap langkah dibungkus pcall SENDIRI. Ini bukan gaya, ini pelajaran mahal:
-- satu pcall raksasa membuat satu kegagalan kecil membunuh seluruh sisanya,
-- dan gejalanya "boost tidak terasa" tanpa satu pun error.

local function langkah(nama, f)
    local ok, err = pcall(f)
    if not ok then catat("boost/%s gagal: %s", nama, tostring(err):sub(1, 70)) end
    return ok
end

-- Dipakai juga oleh pendengar streaming di bawah, jadi dipisah.
local function redamInstance(d)
    local k = d.ClassName
    if k == "ParticleEmitter" or k == "Trail" or k == "Smoke" or k == "Fire" or k == "Sparkles"
       or k == "PointLight" or k == "SpotLight" or k == "SurfaceLight" then
        d.Enabled = false
        Boost.efek = Boost.efek + 1
        return true
    elseif k == "Texture" or k == "Decal" then
        d:Destroy()
        Boost.texture = Boost.texture + 1
        return true
    end
    return false
end

local function bekukanAnimator(anim)
    if not anim then return end
    for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
        pcall(function() t:Stop(0) end)
        Boost.anim = Boost.anim + 1
    end
    -- Menghentikan yang sedang jalan saja tidak cukup: begitu karakter bergerak,
    -- track baru dimainkan. Di server ini rata-rata semua bergerak, jadi tanpa
    -- pendengar ini pembekuannya cuma bertahan sedetik.
    Boost.conn[#Boost.conn + 1] = anim.AnimationPlayed:Connect(function(track)
        if Config.BekukanAnimasi then pcall(function() track:Stop(0) end) end
    end)
end

-- Memangkas isi dunia yang murni hiasan. Aturannya dipilih supaya MUSTAHIL
-- menjatuhkan pemain: hanya BasePart ber-CanCollide=false yang dibuang --
-- benda yang menurut definisinya tidak bisa dipijak. Yang bisa dipijak tidak
-- pernah disentuh sama sekali.
--
-- PONDAREA* DIKECUALIKAN: instance-nya dikirim ke FishingRequestStart, jadi
-- membuangnya menghentikan mancing sepenuhnya.
--
-- Terukur: 24.630 instance plot orang lain + 1.334 hiasan peta + 830 karakter
-- jatuhan; posisi Y tetap, nyawa penuh, kolam utuh.
local function sapuPeta()
    local lp = game:GetService("Players").LocalPlayer

    -- Plot pemain LAIN. Punya sendiri disisakan -- di situ stand penghasil
    -- CPS berada, dan kalau nanti mau diutak-atik ia harus ada.
    local pp = workspace:FindFirstChild("PlayerPlots")
    if pp then
        for _, plot in ipairs(pp:GetChildren()) do
            if tostring(plot:GetAttribute("OwnerUserId")) ~= tostring(lp.UserId) then
                Boost.peta = Boost.peta + #plot:GetDescendants()
                pcall(function() plot:Destroy() end)
            end
        end
    end

    local sc = workspace:FindFirstChild("SpawnedCharacters")
    if sc then
        Boost.peta = Boost.peta + #sc:GetDescendants()
        pcall(function() sc:ClearAllChildren() end)
    end

    local map = workspace:FindFirstChild("Map")
    if map then
        local buang = {}
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("BasePart") and not d.CanCollide then
                local nama = d.Name
                local induk = d.Parent and d.Parent.Name or ""
                if not (nama:find("PONDAREA") or induk:find("PONDAREA")
                        or nama:find("Spawn") or induk:find("Spawn")) then
                    buang[#buang + 1] = d
                end
            end
        end
        for i, d in ipairs(buang) do
            pcall(function() d:Destroy() end)
            Boost.peta = Boost.peta + 1
            if i % 500 == 0 then task.wait() end
        end
    end
end

local function jalankanBoost()
    langkah("fpscap", function()
        if type(setfpscap) == "function" then setfpscap(Config.FpsCap) end
    end)

    langkah("lighting", function()
        local L = game:GetService("Lighting")
        L.GlobalShadows = false
        L.Technology = Enum.Technology.Compatibility
        L.FogEnd = 1e6
        for _, d in ipairs(L:GetDescendants()) do
            if d:IsA("PostEffect") then d.Enabled = false end
            if d:IsA("Atmosphere") then d:Destroy() end
        end
    end)

    langkah("air", function()
        local T = workspace.Terrain
        T.WaterWaveSize = 0
        T.WaterWaveSpeed = 0
        T.WaterReflectance = 0
    end)

    langkah("efek+texture", function()
        local buang = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            local k = d.ClassName
            if k == "Texture" or k == "Decal" then
                buang[#buang + 1] = d
            else
                redamInstance(d)
            end
        end
        -- Dicicil: menghancurkan 34 ribu instance sekaligus membuat klien
        -- tersendat beberapa detik, dan itu terlihat seperti script menggantung.
        for i, d in ipairs(buang) do
            pcall(function() d:Destroy() end)
            Boost.texture = Boost.texture + 1
            if i % 800 == 0 then task.wait() end
        end
    end)

    if Config.BekukanAnimasi then
        langkah("animasi", function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("Humanoid") or d:IsA("AnimationController") then bekukanAnimator(d) end
            end
        end)
    end

    if Config.BuangGui then
        langkah("gui", function()
            -- DAFTAR BUANG, bukan daftar simpan. Apa pun yang tidak disebut di
            -- sini DIPERTAHANKAN -- arah gagal yang benar: melewatkan satu GUI
            -- berarti kehilangan sedikit penghematan, bukan mematikan fitur.
            --
            -- FishAction SENGAJA tidak ada di daftar: runtime mancing milik game
            -- membacanya, dan membuangnya mematikan auto fish.
            local BUANG = {
                "SettingsGUI", "IndexWorldGUI", "StoreGUI", "GemStoreGUI",
                "UpgradesStoreGUI", "FishingStoreGUI", "ClanGUI", "BoostsStoreGUI",
                "SecretStoreGUI", "SecretStore2GUI", "SellGUI", "QuestGUI",
                "CaseGUI", "CaseActions", "CaseOdds", "CaseOdds2", "DailyGUI",
                "MedalGUI", "PlaytimeRewardsGUI", "RebirthGUI", "GiftGUI",
                "CutsceneGUI", "IntroGUI", "ConfirmationGUI", "Sacrifice1GUI",
                "Sacrifice2GUI", "SacrificeStartGUI", "WikiGUI", "TradingGUI",
                "ColorPickerGuild",
            }
            local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            local mg = pg and pg:FindFirstChild("MainGui")
            if mg then
                for _, nama in ipairs(BUANG) do
                    local v = mg:FindFirstChild(nama)
                    if v then
                        Boost.gui = Boost.gui + #v:GetDescendants()
                        pcall(function() v:Destroy() end)
                    end
                end
            end
            local rc = pg and pg:FindFirstChild("RareCatch")
            if rc then
                Boost.gui = Boost.gui + #rc:GetDescendants()
                pcall(function() rc:Destroy() end)
            end
        end)
    end

    if Config.RampingPeta then
        langkah("peta", function() sapuPeta() end)
    end

    -- Pendengar streaming. StreamingEnabled = true di game ini, jadi isi dunia
    -- terus dimuat ulang saat kamu bergerak -- tanpa ini, efek dan texture yang
    -- baru masuk tidak ikut diredam dan FPS perlahan merosot lagi.
    langkah("pendengar", function()
        Boost.conn[#Boost.conn + 1] = workspace.DescendantAdded:Connect(function(d)
            if not Config.BoostFps then return end
            -- Sengaja seringan mungkin: pemeriksaan ClassName saja. Handler ini
            -- menyala ribuan kali per menit, jadi apa pun yang lebih berat di
            -- sini justru memakan kembali FPS yang baru dihemat.
            if not redamInstance(d) and Config.BekukanAnimasi then
                if d:IsA("Humanoid") or d:IsA("AnimationController") then
                    bekukanAnimator(d)
                end
            end
        end)
    end)
end

-- Dipakai tombol panel. Menjaga agar sapuan berat tidak jalan dua kali.
Boost.jalankan = function()
    if Boost.sudahJalan then return false end
    Boost.sudahJalan = true
    jalankanBoost()
    catat("boost: %d efek, %d texture, %d animasi, %d GUI, %d peta",
        Boost.efek, Boost.texture, Boost.anim, Boost.gui, Boost.peta)
    return true
end

if Config.BoostFps then
    task.spawn(function()
        -- Ditunda sebentar: saat script baru dimuat, dunia sering masih
        -- berdatangan. Menyapu terlalu dini berarti setengahnya belum ada.
        task.wait(2)
        Boost.jalankan()
        -- Sapu ulang berkala: streaming memasukkan kembali plot dan hiasan
        -- saat kamu bergerak. Pendengar DescendantAdded sudah mengurus efek
        -- dan texture satu per satu, tapi plot masuk sebagai satu blok besar
        -- sekaligus dan lebih murah disapu sesekali daripada dijaga per-anak.
        while S.hidup do
            task.wait(30)
            if Config.BoostFps and Config.RampingPeta then
                pcall(sapuPeta)
            end
        end
    end)
end

-- PEMBERSIH TALI dipanggil dari sini juga (lihat fungsinya di bawah).
-- Dua tugas: melaporkan, dan mematikan diri kalau tembakan mulai tidak
-- dibalas. Yang kedua penting -- kalau suatu saat server mulai menolak,
-- script yang terus menembak jauh lebih menarik perhatian daripada script
-- yang berhenti sendiri.
-- Yang disisakan adalah yang TERBARU: GetChildren/GetDescendants mengembalikan
-- urutan penambahan, jadi lemparan yang sedang berjalan pasti ada di ekor.
-- Membuang dari depan berarti tidak pernah menyentuh yang aktif.
--
-- Hanya nama persis "FishingLine" dan "FishBall". "FishingNearbyLine" SENGAJA
-- dilewati: itu tali milik pemain lain yang digambar di klien kita, dan
-- menghapusnya cuma merusak tampilan tanpa memperbaiki apa pun.
--
-- Terukur aman: 187 tali dibuang jadi 8, mancing lanjut di 57,6 ikan/menit,
-- dan sesudah 25 detik jumlahnya tetap 7 -- tidak menumpuk lagi.
local function bersihkanTali()
    if not Config.BersihTali then return end
    local sisa = math.max(1, Config.MaksTali)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        local ch = lp.Character
        if ch then
            local garis = {}
            for _, d in ipairs(ch:GetDescendants()) do
                if d.Name == "FishingLine" and d:IsA("Beam") then garis[#garis + 1] = d end
            end
            for i = 1, #garis - sisa do
                pcall(function() garis[i]:Destroy() end)
                S.taliDibuang = S.taliDibuang + 1
            end
        end

        local bola = {}
        for _, d in ipairs(workspace:GetChildren()) do
            if d.Name == "FishBall" then bola[#bola + 1] = d end
        end
        for i = 1, #bola - sisa do
            pcall(function() bola[i]:Destroy() end)
            S.taliDibuang = S.taliDibuang + 1
        end
    end)
end

task.spawn(function()
    -- Pencacah frame. Heartbeat menyala sekali per frame, jadi menghitungnya
    -- selama satu detik memberi FPS sesungguhnya -- bukan perkiraan dari
    -- DeltaTime satu frame yang gampang meleset saat ada lonjakan.
    -- Dibungkus pcall: penghitung FPS itu hiasan, sedangkan penjaga di bawahnya
    -- yang mematikan script saat server menolak itu tugas keselamatan. Kalau
    -- baris ini gagal dan tidak dibungkus, ia membunuh seluruh penjaga --
    -- ketahuan dari uji regresi, bukan dari membaca.
    pcall(function()
        S.conn[#S.conn + 1] = game:GetService("RunService").Heartbeat:Connect(function()
            S.frame = S.frame + 1
        end)
    end)

    local laporBerikut = os.clock() + Config.IntervalLapor
    local bersihBerikut = os.clock() + 5
    local fpsBerikut = os.clock() + 1
    while S.hidup do
        task.wait(1)

        if os.clock() >= fpsBerikut then
            local lewat = os.clock() - (fpsBerikut - 1)
            S.fps = S.frame / math.max(0.001, lewat)
            S.frame = 0
            fpsBerikut = os.clock() + 1
            if Gui.ada then pcall(function() Gui.catFps(S.fps) end) end
        end

        -- Tiap 5 detik, bukan tiap detik: menyapu ratusan descendant sesering
        -- itu justru menambah beban yang mau dikurangi.
        if os.clock() >= bersihBerikut then
            bersihBerikut = os.clock() + 5
            bersihkanTali()
        end

        if S.menunggu and (os.clock() - S.menunggu) > Config.BatasBalasan then
            S.menunggu = nil
            S.gagalBeruntun = S.gagalBeruntun + 1
            if S.gagalBeruntun >= Config.MaksGagalBeruntun then
                catat("BERHENTI: %d tembakan beruntun tidak dibalas dalam %.0f dtk. "
                    .. "Server mungkin berubah — periksa dulu sebelum dinyalakan lagi.",
                    S.gagalBeruntun, Config.BatasBalasan)
                Config.Aktif = false
                -- Tombolnya wajib ikut berubah. Panel yang menunjukkan "AKTIF"
                -- padahal script sudah mematikan diri itu bohong ke pemakai,
                -- dan bikin salah menyimpulkan kenapa tangkapan melambat.
                if Gui.ada then pcall(Gui.cat) end
            end
        end

        if Gui.ada and S.siklus > 1 and S.tMulai then
            local jalan = os.clock() - S.tMulai
            pcall(function()
                local perSiklus = jalan / (S.siklus - 1)
                Gui.catStat(perSiklus > 0 and (60 / perSiklus) or 0,
                    S.siklus, S.tolak, S.biaya)
            end)
        end

        if Config.Lapor and os.clock() >= laporBerikut then
            laporBerikut = os.clock() + Config.IntervalLapor
            local jalan = os.clock() - (S.tMulai or os.clock())
            local perSiklus = S.siklus > 1 and (jalan / (S.siklus - 1)) or 0
            local restart = S.nRestart > 0 and (S.jumRestart / S.nRestart) or 0
            catat("%.1f character/menit | %d siklus | restart %.3f | buang %d | rr %s | diterima %d/%d%s",
                perSiklus > 0 and (60 / perSiklus) or 0, S.siklus, restart, S.tolak,
                S.biaya and string.format("%.0fms", S.biaya * 1000) or "-",
                S.diterima, S.tembak,
                Config.Aktif and "" or " | NONAKTIF")
        end
    end
end)

-- =========================================================================
-- PEMERIKSA KEADAAN
-- Berguna saat menjalankan banyak akun: keadaan bisa dibaca dari luar tanpa
-- melihat panel satu per satu.
getgenv().MozeFishInfo = function()
    local jalan = S.tMulai and (os.clock() - S.tMulai) or 0
    return {
        aktif       = Config.Aktif,
        tolakRoll   = Config.TolakRoll,
        ambangSetel = Config.AmbangRoll,          -- "auto" atau angka manual
        ambangPakai = ambang(),                   -- yang benar-benar berlaku
        biayaReroll = S.biaya,
        siklus      = S.siklus,
        tolak       = S.tolak,
        charPerMenit = (S.siklus > 1 and jalan > 0) and (60 / (jalan / (S.siklus - 1))) or 0,
        pond        = S.pondName,
        simpan      = Config.Simpan,
        antiAfk     = Config.AntiAfk,
        rodPasang   = S.rodPasang,
        taliDibuang = S.taliDibuang,
        fps         = S.fps,
        boost       = Config.BoostFps and {
            efek = Boost.efek, texture = Boost.texture,
            animasi = Boost.anim, gui = Boost.gui, peta = Boost.peta,
        } or false,
        afkSentuh   = S.afkSentuh,
        afkGagal    = S.afkGagal,
    }
end

-- =========================================================================
-- PELEPAS
getgenv().MozeFishStop = function()
    S.hidup = false
    Config.Aktif = false
    for _, c in ipairs(S.conn) do pcall(function() c:Disconnect() end) end
    S.conn = {}
    if Gui.sg then pcall(function() Gui.sg:Destroy() end) end
    Gui.ada = false
    getgenv().MozeFishStop = nil
    getgenv().MozeFishInfo = nil
    catat("dilepas. %d siklus, %d tembakan, %d diterima.", S.siklus, S.tembak, S.diterima)
end

catat("aktif. Menunggu event `Started` pertama untuk membaca pond & posisi.")
catat("berhenti: getgenv().MozeFishStop()")

-- @MOZEFRAME-EOF@ (penanda akhir berkas -- router menolak file tanpa baris ini)
