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
dan Decal, bekukan animasi (termasuk yang baru dimainkan), buang dua layar
sekali-tayang, dan pangkas plot pemain lain + hiasan peta.

CATATAN 2026-08-28 -- angka di tabel atas didapat dengan sapuan LAMA, yang
juga menghapus seluruh toko dan seluruh NPC dunia. Keduanya sudah dicabut
(lihat komentar di daftar BUANG dan di sapuPeta), jadi baris "+ animasi &
GUI" tidak lagi mewakili apa yang dijalankan sekarang. Perlu diukur ulang.

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

-- Urutan mode auto feed. Ditaruh di atas karena dipakai DUA tempat: tombol
-- pemutar mode di panel, dan pengurut daftar stand di modul feed.
local MODE_FEED = { "rata", "level", "cps", "rarity", "rata200" }
-- Dipakai tombol pemutar di panel dan penyaring tipe prompt di modul feed.
local JUMLAH_FEED = { "1", "10", "max" }

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


    -- ==== PILIH KOLAM OTOMATIS ====
    -- Menilai kolam mana yang paling produktif dengan rod yang dimiliki, lalu
    -- MENAMPILKANNYA di panel. Tidak pernah memindahkan karakter -- ini script
    -- pendamping, posisi tetap milik pemain. Default nyala karena ia cuma
    -- membaca dan menampilkan; tidak ada yang bisa rusak karenanya.
    SaranKolam      = pilihSaklar("SaranKolam", true),

    -- ==== AUTO FEED & AUTO SPOT ====
    -- Keduanya MEMINDAHKAN karakter, jadi default MATI. Pemain yang
    -- memutuskan kapan botnya boleh meninggalkan kolam.
    AutoFeed        = pilihSaklar("AutoFeed", false),
    -- rata | level | cps | rarity | rata200
    -- Ikut simpanan seperti saklar lain; tanpa ini mode yang dipilih pemain
    -- balik ke "rata" tiap kali script dimuat ulang.
    FeedMode        = tostring(U.FeedMode or SIMPAN.FeedMode or "rata"),
    FeedJeda        = tonumber(U.FeedJeda) or 90,
    -- Berapa stand per lompatan. 5 stand ~2 detik; makin banyak makin lama
    -- karakter meninggalkan kolam, dan itu yang membatalkan pancingan.
    FeedPerSesi     = tonumber(U.FeedPerSesi) or 5,
    -- Sisakan food minimal sekian. 0 = pakai sampai habis.
    FeedSisaFood    = tonumber(U.FeedSisaFood) or 0,
    -- Batas level untuk mode "rata200".
    FeedBatas       = tonumber(U.FeedBatas) or 200,
    -- Batas satu kali tekan, sebagai PECAHAN dari food yang dipegang.
    -- Terukur kenapa ini perlu: tanpa batas, satu sesi menghabiskan 1,07
    -- MILIAR food karena tombol LevelUp10 di stand mahal ikut ditekan.
    FeedMaksPecahan = tonumber(U.FeedMaksPecahan) or 0.05,
    -- TABUNGAN: sesi feed tidak dimulai sama sekali sampai food mencapai
    -- angka ini. 0 = tanpa ambang. Isi 1e9 kalau mau menabung 1 miliar
    -- dulu baru memberi makan.
    FeedMulaiDari   = tonumber(U.FeedMulaiDari) or SIMPAN.FeedMulaiDari or 0,
    -- Berapa level sekali tekan: "1", "10", atau "max".
    -- "1" untuk meratakan, "max" untuk mendorong satu karakter jauh.
    FeedJumlah      = tostring(U.FeedJumlah or SIMPAN.FeedJumlah or "1"),
    AutoSpot        = pilihSaklar("AutoSpot", false),
    SpotJeda        = tonumber(U.SpotJeda) or 60,
    JedaPeriksaPond = tonumber(U.JedaPeriksaPond) or 20,
    -- Sejauh mana kolam masih dianggap milik kita saat script mendeteksi sendiri.
    JangkauanKolam  = tonumber(U.JangkauanKolam) or 120,
    -- Kolam yang MEMAKSA rarity ini ke atas selalu menang atas skor laju.
    RarityPrioritas = U.RarityPrioritas or "Mythical",
    -- Isi nama kolam untuk mengunci pilihan dan melewati penilaian.
    PondPaksa       = U.PondPaksa,

    -- ==== AUTO KLAIM ====
    -- DEFAULT NYALA, berbeda dari boost dan auto pindah kolam. Alasannya:
    -- mengklaim tidak bisa menghilangkan apa pun -- hadiah yang tidak diambil
    -- justru yang hangus. Tidak ada sisi buruk yang perlu dilindungi saklar.
    AutoKlaim   = pilihSaklar("AutoKlaim", true),
    JedaKlaim   = tonumber(U.JedaKlaim) or 60,
    -- Hadiah harian dipisah: ia terikat hari, bukan sesi, dan sebagian orang
    -- lebih suka mengambilnya sendiri di waktu yang mereka pilih.
    KlaimHarian = pilihSaklar("KlaimHarian", true),

    -- ==== PUNGUT GEM EVENT ====
    -- Sengaja TANPA tombol panel: event yang menjatuhkan gem itu langka dan
    -- tidak pernah terundi sendiri, jadi saklar yang perlu diklik justru akan
    -- ketinggalan saat event benar-benar datang. Nyala terus, murah, dan tidak
    -- bisa merugikan.
    AutoGem   = pilihSaklar("AutoGem", true),

    -- ==== LAYAR HITAM ====
    -- Default MATI. Beda dari kaitun utama yang layarnya permanen sampai UI
    -- Roblox ikut hilang, di sini ia cuma ScreenGui yang di-Enabled -- mematikan
    -- tombolnya mengembalikan tampilan game seketika, tanpa rejoin.
    LayarHitam = pilihSaklar("LayarHitam", false),

    -- ==== LAPORAN DISCORD ====
    -- PERINGATAN: URL ini adalah KREDENSIAL. Siapa pun yang membacanya bisa
    -- mengirim apa saja ke kanalmu. Script ini terbit di repo publik, jadi
    -- anggap URL-nya bocor sejak hari pertama dan siapkan diri untuk
    -- menggantinya (Discord: Integrations -> Webhooks -> ganti URL).
    -- Bisa ditimpa lewat getgenv().MozeFishConfig.Webhook kalau mau URL
    -- berbeda per pemakai tanpa menyunting berkas.
    Webhook = (type(U.Webhook) == "string" and U.Webhook)
        or "https://discord.com/api/webhooks/1542380727969128530/REJU327QD30xltATNcv0Dn8TjXKzcKwNyYTWFqugYK_DllLn6Pv1NGvPnS2NiQFTBxVI",
    -- Ambang bawah, mengikuti nama di Constants.RarityOrder.
    WebhookMinRarity = U.WebhookMinRarity or "Ancient",
    JedaGem   = tonumber(U.JedaGem) or 2,

    -- ==== BOOST FPS ====
    -- Sasarannya perangkat yang menjalankan banyak klien sekaligus.
    -- DEFAULT MATI, dan sengaja. Boost itu SATU ARAH: texture dan GUI yang
    -- sudah dihapus tidak bisa dikembalikan tanpa rejoin. Fitur yang tidak
    -- bisa dibatalkan tidak boleh menyala tanpa diminta.
    BoostFps        = pilihSaklar("BoostFps", false),
    -- NOL BERARTI TANPA BATAS, dan itu bukan sekadar konvensi -- itu yang
    -- paling cepat. Terukur di akun uji (executor Potassium, satu mesin,
    -- pengukuran berurutan 4-5 detik masing-masing):
    --
    --     tanpa cap ....... 229 fps
    --     setfpscap(240) .. 221
    --     setfpscap(1000) . 216   <- justru TURUN
    --     setfpscap(0) .... 276   <- tertinggi
    --
    -- Angka besar seperti 1000 terlihat seperti tanpa batas, tapi executor
    -- tetap memasang penjadwal untuk mengejarnya dan hasilnya lebih lambat
    -- daripada tidak dibatasi sama sekali. Jangan diganti tanpa mengukur ulang.
    FpsCap          = tonumber(U.FpsCap) or 0,
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

    -- Nyalakan hanya saat mencari masalah: getgenv().MozeFishConfig.Senyap = false
    Senyap = U.Senyap ~= false,

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
            SaranKolam = Config.SaranKolam,
            AutoKlaim  = Config.AutoKlaim,
            LayarHitam = Config.LayarHitam,
            KlaimHarian = Config.KlaimHarian,
            AutoFeed   = Config.AutoFeed,
            FeedMode   = Config.FeedMode,
            AutoSpot   = Config.AutoSpot,
            FeedJumlah = Config.FeedJumlah,
            FeedMulaiDari = Config.FeedMulaiDari,
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
-- Auto fish milik GAME. Dipakai auto spot/feed untuk menyalakan ulang panen
-- sesudah karakter dipindahkan; boleh nil, dan kalau nil fast restart kita
-- yang menanggung sendiri.
local AutoFishSync        = Remotes:FindFirstChild("FishingAutoFishEnabledSync", true)
-- Klik penyelesai tangkapan. Boleh nil; kalau nil, cabang Progress di bawah
-- diam saja dan script kembali bergantung pada Completed yang datang sendiri.
local FishingClick        = Remotes:FindFirstChild("FishingClick", true)
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
    -- KARAKTER, bukan siklus. Satu Completed membawa tabel `rewards` yang
    -- berisi BEBERAPA karakter sekaligus -- terukur di akun dengan triple
    -- catch: 3x34, 4x7, 5x10, 6x1 dari 52 siklus, rata-rata 3,58 dan tidak
    -- pernah di bawah 3. Panel dulu menampilkan siklus tapi menamainya
    -- "character/menit", jadi angkanya terlalu kecil 3,58 kali.
    karakter    = 0,
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

-- Senyap secara bawaan: 19 tempat memanggil ini, dan sebagian di dalam loop
-- yang jalan tiap beberapa detik -- di layar dengan 8-10 klien itu membanjiri
-- konsol sampai pesan game sendiri tidak terbaca.
--
-- Dua warn fatal di bawah SENGAJA tidak ikut dibungkam: keduanya menyala tepat
-- sekali, hanya saat script tidak bisa jalan sama sekali. Membungkamnya berarti
-- script mati tanpa meninggalkan satu pun jejak -- persis kelas bug yang paling
-- lama dikejar di proyek ini.
local function catat(fmt, ...)
    if Config.Senyap then return end
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

-- Menemukan kolam sendiri dari DUNIA, tanpa menunggu event Started.
--
-- KENAPA INI ADA. Dulu satu-satunya sumber nama kolam adalah event Started, dan
-- itu saling mengunci: begitu pemain pindah kolam, script masih menembak kolam
-- LAMA yang kini jauh, server membalas Denied, dan Started tidak pernah datang
-- sehingga kolamnya tidak pernah diperbarui. Gejalanya panel tetap menulis
-- PONDAREA1 padahal pemain sudah berdiri di PONDAREA2, dan siklus berhenti
-- bertambah tanpa satu pun pesan galat.
--
-- Jarak diukur ke PERMUKAAN zona, bukan ke pusatnya. Zona PONDAREA1 terukur
-- 837 stud panjangnya, jadi jarak-ke-pusat bisa ratusan stud padahal kita
-- berdiri tepat di tepinya.
local function deteksiKolam()
    local pemain = game:GetService("Players").LocalPlayer
    local hrp = pemain.Character and pemain.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local zona, dekat = nil, math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and string.match(d.Name, "^PONDAREA%d+$") then
            local l = d.CFrame:PointToObjectSpace(hrp.Position)
            local h = d.Size / 2
            local luar = Vector3.new(
                math.max(math.abs(l.X) - h.X, 0),
                math.max(math.abs(l.Y) - h.Y, 0),
                math.max(math.abs(l.Z) - h.Z, 0))
            if luar.Magnitude < dekat then zona, dekat = d, luar.Magnitude end
        end
    end
    if not zona or dekat > Config.JangkauanKolam then return false end

    -- Target WAJIB dekat pemain. Mengirim pusat zona membuat server membalas
    -- Denied -- terukur di PONDAREA1 yang zonanya sangat panjang. Karena itu
    -- posisi kita diproyeksikan ke titik terdekat DI DALAM zona.
    local l = zona.CFrame:PointToObjectSpace(hrp.Position)
    local h = zona.Size / 2
    S.target = zona.CFrame:PointToWorldSpace(Vector3.new(
        math.clamp(l.X, -h.X, h.X),
        math.clamp(l.Y, -h.Y, h.Y),
        math.clamp(l.Z, -h.Z, h.Z)))
    if S.pondName ~= zona.Name then
        catat("kolam terdeteksi: %s (%d stud)", zona.Name, math.floor(dekat))
    end
    S.pond, S.pondName = zona, zona.Name
    return true
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

-- =========================================================================
-- KOLAM: PENALAAN PER KOLAM DAN PINDAH OTOMATIS
--
-- Semua angka di sini DIBACA dari Constants.Fishing saat jalan, tidak satu pun
-- ditulis mati. Itu disengaja: kalau developer menyeimbangkan ulang kolam atau
-- menambah kolam event, script ikut menyesuaikan tanpa disentuh.
--
-- YANG TERUKUR DARI CONSTANTS (akun uji, Void Rod):
--
--   PONDAREA1   Strength 0      PondCatchTimeMulti 0 .. 0      -> tunggu NOL
--   PONDAREA2   Strength 2000   PondCatchTimeMulti nil .. 0,8  -> tunggu 0,8-8 dtk
--   PONDAREA7   Strength 1      PondCatchTime {Min 1, Max 5}   RarityChances {God=100}
--
-- PONDAREA1 waktu tangkapnya benar-benar NOL. Itu sebabnya di sana terasa
-- instan, dan sekaligus sebabnya tolak-roll nyaris tak berguna di sana: tidak
-- ada waktu tunggu yang bisa dihemat.
--
-- PONDAREA2 membeli mutasi (Lava x4) dan multi-pull (x1,5 / x2) DENGAN waktu.
-- Untuk Void Rod harapan karakter per tangkapan cuma naik 1,144 -> 1,186
-- (+3,7%) sementara waktu tangkap naik dari nol ke hitungan detik. Karena itu
-- penilai di bawah memakai KARAKTER PER DETIK, bukan per tangkapan.
--
-- YANG TIDAK MASUK MODEL, DAN HARUS DISADARI:
-- Harga tiap rarity dan tiap mutasi TIDAK ikut dihitung -- tabel pengalinya
-- tidak ditemukan di Constants. Jadi skor ini mengukur LAJU, bukan uang. Kolam
-- yang memaksa rarity tinggi (PONDAREA7, God 100%) karena itu ditangani
-- terpisah sebagai kelas prioritas, bukan lewat skor.



-- =========================================================================
-- LAYAR HITAM (BLACKSCREEN)
--
-- BEDA PENTING DARI KAITUN UTAMA: di sana layar hitamnya PERMANEN dan bahkan
-- menghapus UI Roblox -- sekali menyala, tidak ada jalan kembali tanpa rejoin.
-- Di sini TIDAK. Semuanya cuma satu ScreenGui yang di-Enabled/disable, jadi
-- mematikannya mengembalikan tampilan game apa adanya seketika, dan melepas
-- script ikut menghapusnya.
--
-- Teks "Caught ..." DICERMINKAN, bukan dibiarkan menembus. Notifikasinya dibuat
-- dinamis sebagai MainGui.NotificationGUI.Notification_NNNN, jadi membiarkannya
-- tembus berarti membuka seluruh MainGui ikut terlihat.
local Layar = {
    sg = nil, ada = false, terlihat = false,
    baris = {}, kartu = {}, terbaik = {},
    labelStat = {}, tabel = nil, conn = {},
}

local FJ_KIRI  = "rbxassetid://79880397850563"
local FJ_KANAN = "rbxassetid://104624206636533"

-- Upgrade yang ditampilkan, berurutan. Kode aslinya (T1O1 dst) tidak berarti
-- apa-apa bagi pemakai, jadi labelnya diambil dari Constants saat jalan.
local URUT_UPGRADE = { "T3O3", "T1O1", "T1O2", "T5O2", "T5O1" }

local function angkaPendek(n)
    n = tonumber(n) or 0
    for _, s in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        if n >= s[1] then return string.format("%.2f%s", n / s[1], s[2]) end
    end
    return string.format("%d", n)
end

local function buatLayar()
    if Layar.ada then return end
    local induk = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local lama = induk:FindFirstChild("MozeLayar")
    if lama then lama:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "MozeLayar"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    -- Di BAWAH panel kendali (DisplayOrder 9999) supaya tombolnya tetap bisa
    -- diklik saat layar menyala.
    sg.DisplayOrder = 1000
    sg.Enabled = false
    sg.Parent = induk
    Layar.sg = sg

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.Parent = sg

    local function gambar(id, kiri)
        local im = Instance.new("ImageLabel")
        im.Size = UDim2.new(0.22, 0, 0.535, 0)
        im.Position = UDim2.new(kiri and 0.02 or 0.98, 0, 0.5, 0)
        im.AnchorPoint = Vector2.new(kiri and 0 or 1, 0.5)
        im.BackgroundTransparency = 1
        im.ScaleType = Enum.ScaleType.Fit
        im.ImageTransparency = 0.12
        im.Image = id
        im.Parent = bg
    end
    gambar(FJ_KIRI, true)
    gambar(FJ_KANAN, false)

    local judul = Instance.new("TextLabel")
    judul.Size = UDim2.new(0.6, 0, 0, 40)
    judul.Position = UDim2.new(0.5, 0, 0, 18)
    judul.AnchorPoint = Vector2.new(0.5, 0)
    judul.BackgroundTransparency = 1
    judul.Font = Enum.Font.GothamBold
    judul.TextSize = 40
    judul.TextColor3 = Color3.fromRGB(232, 180, 74)
    judul.Text = "FAAR - MOZEFRAME"
    judul.Parent = bg

    -- ---- STAT ----
    local barisStat = Instance.new("Frame")
    barisStat.Size = UDim2.new(0, 780, 0, 40)
    barisStat.Position = UDim2.new(0.5, 0, 0, 62)
    barisStat.AnchorPoint = Vector2.new(0.5, 0)
    barisStat.BackgroundTransparency = 1
    barisStat.Parent = bg
    local tata = Instance.new("UIListLayout")
    tata.FillDirection = Enum.FillDirection.Horizontal
    tata.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tata.VerticalAlignment = Enum.VerticalAlignment.Center
    tata.Padding = UDim.new(0, 30)
    tata.Parent = barisStat
    for _, s in ipairs({ { "Cash", Color3.fromRGB(240, 210, 110) },
                          { "Food", Color3.fromRGB(150, 230, 140) },
                          { "Gems", Color3.fromRGB(120, 210, 255) } }) do
        local l = Instance.new("TextLabel")
        l.Name = s[1]
        l.Size = UDim2.fromOffset(230, 36)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 24
        l.TextColor3 = s[2]
        l.Text = s[1] .. " -"
        l.Parent = barisStat
        Layar.labelStat[s[1]] = l
    end

    -- ---- UPGRADE ----
    -- Teks polos, TANPA garis kotak. Percobaan pertama memakai karakter kotak
    -- Unicode di font Code dan hasilnya garis patah-patah yang tidak pernah
    -- lurus -- Roblox tidak merender glif itu selebar karakter biasa.
    local kepalaUpg = Instance.new("TextLabel")
    kepalaUpg.Size = UDim2.new(0, 320, 0, 24)
    kepalaUpg.Position = UDim2.new(0.5, 0, 0, 106)
    kepalaUpg.AnchorPoint = Vector2.new(0.5, 0)
    kepalaUpg.BackgroundTransparency = 1
    kepalaUpg.Font = Enum.Font.GothamBold
    kepalaUpg.TextSize = 24
    kepalaUpg.TextColor3 = Color3.fromRGB(232, 180, 74)
    kepalaUpg.Text = "Upgrade :"
    kepalaUpg.Parent = bg

    local tabel = Instance.new("TextLabel")
    tabel.Name = "Tabel"
    tabel.Size = UDim2.new(0, 560, 0, 220)
    tabel.Position = UDim2.new(0.5, 0, 0, 134)
    tabel.AnchorPoint = Vector2.new(0.5, 0)
    tabel.BackgroundTransparency = 1
    tabel.Font = Enum.Font.Gotham
    tabel.TextSize = 22
    tabel.LineHeight = 1.4
    tabel.TextColor3 = Color3.fromRGB(226, 226, 232)
    tabel.TextXAlignment = Enum.TextXAlignment.Center
    tabel.TextYAlignment = Enum.TextYAlignment.Top
    tabel.RichText = true
    tabel.Text = "memuat..."
    tabel.Parent = bg
    Layar.tabel = tabel

    -- ---- FEED "Caught ..." (DI TENGAH) ----
    -- 16 baris, bukan 8: feed pendek habis dalam belasan detik saat multi-hook,
    -- dan yang menarik justru barisan panjangnya.
    local feed = Instance.new("Frame")
    feed.Size = UDim2.new(0, 620, 0, 430)
    feed.Position = UDim2.new(0.5, 0, 0, 412)
    feed.AnchorPoint = Vector2.new(0.5, 0)
    feed.BackgroundTransparency = 1
    feed.Parent = bg
    local tataFeed = Instance.new("UIListLayout")
    tataFeed.SortOrder = Enum.SortOrder.LayoutOrder
    tataFeed.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tataFeed.Padding = UDim.new(0, 3)
    tataFeed.Parent = feed
    for i = 1, 16 do
        local l = Instance.new("TextLabel")
        l.LayoutOrder = i
        l.Size = UDim2.new(1, 0, 0, 25)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 21
        l.RichText = true
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextColor3 = Color3.fromRGB(210, 210, 218)
        l.Text = ""
        l.Parent = feed
        Layar.baris[i] = l
    end

    -- ---- BEST CATCH ----
    local judulBest = Instance.new("TextLabel")
    judulBest.Size = UDim2.new(0, 300, 0, 24)
    judulBest.Position = UDim2.new(0, 40, 1, -286)
    judulBest.BackgroundTransparency = 1
    judulBest.Font = Enum.Font.GothamBold
    judulBest.TextSize = 21
    judulBest.TextXAlignment = Enum.TextXAlignment.Left
    judulBest.TextColor3 = Color3.fromRGB(232, 180, 74)
    judulBest.Text = "BEST CATCH"
    judulBest.Parent = bg

    for i = 1, 5 do
        local kartu = Instance.new("Frame")
        kartu.Size = UDim2.fromOffset(172, 236)
        kartu.Position = UDim2.new(0, 40 + (i - 1) * 186, 1, -256)
        kartu.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        kartu.BorderSizePixel = 0
        kartu.Parent = bg
        Instance.new("UICorner", kartu).CornerRadius = UDim.new(0, 8)
        local garis = Instance.new("UIStroke")
        garis.Color = Color3.fromRGB(70, 70, 84)
        garis.Thickness = 1
        garis.Parent = kartu

        -- ViewportFrame, BUKAN ImageLabel: game ini tidak punya art 2D karakter,
        -- dan Roblox tidak bisa memuat gambar dari URL luar. Merender model
        -- aslinya satu-satunya cara menampilkan wajahnya di dalam game.
        local vp = Instance.new("ViewportFrame")
        vp.Name = "VP"
        vp.Size = UDim2.new(1, -14, 0, 130)
        vp.Position = UDim2.fromOffset(7, 7)
        vp.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        vp.BorderSizePixel = 0
        vp.Ambient = Color3.fromRGB(205, 205, 215)
        vp.LightColor = Color3.fromRGB(255, 250, 240)
        vp.LightDirection = Vector3.new(-0.35, -0.75, -0.55)
        vp.Parent = kartu
        Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 6)

        local function label(nama, y, ukuran, warna, tebal)
            local l = Instance.new("TextLabel")
            l.Name = nama
            l.Size = UDim2.new(1, -14, 0, 22)
            l.Position = UDim2.fromOffset(7, y)
            l.BackgroundTransparency = 1
            l.Font = tebal and Enum.Font.GothamBold or Enum.Font.Gotham
            l.TextSize = ukuran
            l.TextTruncate = Enum.TextTruncate.AtEnd
            l.TextColor3 = warna
            l.Text = ""
            l.Parent = kartu
            return l
        end
        label("Nama",   142, 17, Color3.fromRGB(235, 235, 240), true)
        label("Rarity", 166, 14, Color3.fromRGB(150, 150, 162))
        label("Mutasi", 187, 14, Color3.fromRGB(200, 150, 255))
        label("Cps",    208, 14, Color3.fromRGB(240, 210, 110))
        Layar.kartu[i] = kartu
    end

    -- ---- TANDA ----
    -- Ditaruh di ruang kosong antara feed dan kartu, bukan di dasar layar:
    -- kartu Best Catch sudah memenuhi bagian bawah kiri, dan menaruhnya di sana
    -- membuat keduanya bertindih di layar lebar.
    local tanda = Instance.new("TextLabel")
    tanda.Size = UDim2.new(0, 1400, 0, 110)
    tanda.Position = UDim2.new(0.5, 0, 0.78, 0)
    tanda.AnchorPoint = Vector2.new(0.5, 0.5)
    tanda.BackgroundTransparency = 1
    tanda.Font = Enum.Font.Code
    tanda.TextSize = 84
    tanda.TextColor3 = Color3.fromRGB(255, 255, 255)
    tanda.Text = "FENG JIU MY BINI"
    tanda.Parent = bg

    Layar.ada = true
end

-- ---- POTRET KARTU ----
local function pasangPotret(kartu, rarity, nama)
    local vp = kartu:FindFirstChild("VP")
    if not vp then return false end
    for _, c in ipairs(vp:GetChildren()) do
        if not c:IsA("Camera") then c:Destroy() end
    end
    local berhasil = false
    pcall(function()
        local A = game:GetService("ReplicatedStorage").Assets.Characters
        local folder = A:FindFirstChild(rarity)
        local model = folder and folder:FindFirstChild(nama)
        if not model then return end
        local klon = model:Clone()
        for _, d in ipairs(klon:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored = true end
        end
        klon.Parent = vp
        local kepala = klon:FindFirstChild("Head")
        if not kepala then return end
        local cam = vp.CurrentCamera
        if not cam then
            cam = Instance.new("Camera")
            cam.Parent = vp
            vp.CurrentCamera = cam
        end
        cam.FieldOfView = 40
        -- Dibidik ke part Head dari arah hadapnya. Bidikan berbasis bounding box
        -- selalu mendarat di senjata atau sayap, bukan wajah.
        local jarak = 3.2 / (2 * math.tan(math.rad(cam.FieldOfView / 2)))
        local sasaran = kepala.Position - Vector3.new(0, kepala.Size.Y * 0.15, 0)
        cam.CFrame = CFrame.new(sasaran + kepala.CFrame.LookVector * jarak, sasaran)
        berhasil = true
    end)
    return berhasil
end

local function segarkanBest()
    if not Layar.ada then return end
    for i = 1, 5 do
        local kartu = Layar.kartu[i]
        local e = Layar.terbaik[i]
        if e then
            kartu.Nama.Text = e.nama
            kartu.Rarity.Text = e.rarity
            kartu.Mutasi.Text = (e.mutasi ~= "" and e.mutasi) or "-"
            kartu.Cps.Text = "$" .. angkaPendek(e.cps) .. "/s"
            if not e.terpasang then
                e.terpasang = pasangPotret(kartu, e.rarity, e.nama)
            end
        else
            kartu.Nama.Text = "-"
            kartu.Rarity.Text = ""
            kartu.Mutasi.Text = ""
            kartu.Cps.Text = ""
        end
    end
end

-- Menawarkan satu tangkapan ke papan Best Catch.
--
-- Peringkatnya dinaikkan kalau punya mutasi: karakter bermutasi jauh lebih
-- berharga daripada yang polos di rarity yang sama, jadi papan yang mengabaikan
-- mutasi akan memajang yang salah. Nama yang sama boleh masuk dua kali kalau
-- mutasinya berbeda -- itu memang tangkapan yang berbeda.
function Layar.tawarkan(nama, rarity, peringkat, mutasi, cps)
    if not nama or not peringkat then return end
    mutasi = tostring(mutasi or "")
    local kunci = nama .. "|" .. mutasi
    for _, e in ipairs(Layar.terbaik) do
        if e.kunci == kunci then return end
    end
    local nilai = peringkat + (mutasi ~= "" and 0.5 or 0)
    table.insert(Layar.terbaik, {
        kunci = kunci, nama = nama, rarity = rarity,
        mutasi = mutasi, cps = tonumber(cps) or 0, nilai = nilai,
    })
    table.sort(Layar.terbaik, function(a, b)
        if a.nilai ~= b.nilai then return a.nilai > b.nilai end
        return a.cps > b.cps
    end)
    while #Layar.terbaik > 5 do table.remove(Layar.terbaik) end
    segarkanBest()
end

function Layar.catatTangkapan(teks)
    if not Layar.ada then return end
    for i = #Layar.baris, 2, -1 do
        Layar.baris[i].Text = Layar.baris[i - 1].Text
    end
    Layar.baris[1].Text = teks
end

local function segarkanStat()
    local LP = game:GetService("Players").LocalPlayer
    local s = Layar.labelStat
    if s.Cash then s.Cash.Text = "Cash  $" .. angkaPendek(LP:GetAttribute("CashNumber")) end
    if s.Food then s.Food.Text = "Food  " .. angkaPendek(LP:GetAttribute("FoodNumber")) end
    if s.Gems then s.Gems.Text = "Gems  " .. angkaPendek(LP:GetAttribute("GemsNumber")) end
end

local function segarkanUpgrade()
    local ok, teks = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local C = require(RS.Constants)
        local st = RS.Remotes.UpgradesStoreGetState:InvokeServer()
        local level = (st and st.levels) or {}
        local O = C.UpgradesStore.Offers
        local baris = {}
        for _, kode in ipairs(URUT_UPGRADE) do
            local cfg = O[kode]
            if cfg then
                local lv = tonumber(level[kode]) or 0
                local mx = tonumber(cfg.MaxLevels) or 0
                -- Yang sudah mentok diberi warna berbeda supaya sekilas terlihat
                -- mana yang masih perlu diurus.
                local warna = (lv >= mx and mx > 0) and "rgb(120,220,150)" or "rgb(226,226,232)"
                baris[#baris + 1] = string.format(
                    "%s  <font color=\"%s\"><b>%d</b> : %d</font>",
                    tostring(cfg.Label or kode), warna, lv, mx)
            end
        end
        return table.concat(baris, "\n")
    end)
    if ok and teks and Layar.tabel then Layar.tabel.Text = teks end
end

function Layar.tampil(nyala)
    if not Layar.ada then buatLayar() end
    Layar.terlihat = nyala and true or false
    if Layar.sg then Layar.sg.Enabled = Layar.terlihat end
    if Layar.terlihat then
        pcall(segarkanStat)
        pcall(segarkanUpgrade)
        segarkanBest()
    end
end

local function jagaLayar()
    task.wait(3)
    buatLayar()
    -- Pulihkan setelan tersimpan. Tanpa baris ini layar yang ditinggalkan
    -- menyala tidak pernah muncul lagi sesudah rejoin -- tombolnya menulis ON,
    -- tapi layarnya tetap gelap. Salah yang tidak memunculkan error apa pun.
    Layar.tampil(Config.LayarHitam)

    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGui")
    local ng = mg and mg:FindFirstChild("NotificationGUI")
    if ng then
        Layar.conn[#Layar.conn + 1] = ng.ChildAdded:Connect(function(d)
            if not Layar.terlihat then return end
            task.defer(function()
                local t = tostring((d:IsA("TextLabel") and d.Text) or "")
                if t ~= "" and string.find(t, "Caught") then
                    pcall(Layar.catatTangkapan, t)
                end
            end)
        end)
    end

    local n = 0
    while S.hidup do
        if Layar.terlihat then
            pcall(segarkanStat)
            n = n + 1
            -- Upgrade lebih jarang: itu panggilan ke server, bukan atribut lokal.
            if n % 5 == 0 then pcall(segarkanUpgrade) end
        end
        task.wait(2)
    end
end

-- =========================================================================
-- LAPORAN TANGKAPAN LANGKA KE DISCORD
--
-- Hanya rarity ANCIENT KE ATAS yang dikirim. Urutannya diambil dari
-- Constants.RarityOrder saat jalan, bukan ditulis mati -- kalau developer
-- menambah rarity baru di atas Ancient, ia ikut terkirim tanpa disentuh:
--
--   1 Common      6 Mythical   11 Divine     16 Omniscient
--   2 Uncommon    7 Cosmic     12 Supreme    17 Exclusive
--   3 Rare        8 Secret     13 Celestial
--   4 Epic        9 Rainbow    14 Ancient   <- ambang
--   5 Legendary  10 Ascended   15 God
--
-- SEBERAPA JARANG: dalam 216 tangkapan berturut-turut yang diukur di akun uji,
-- TIDAK SATU PUN mencapai Ancient. Tertinggi yang muncul Ascended (peringkat 10)
-- sebanyak 3 kali. Jadi kanal ini akan sunyi berhari-hari, dan itu memang
-- tujuannya -- tidak perlu penjaga laju yang rumit.
--
-- TIDAK ADA GAMBAR KARAKTER, DAN ITU BUKAN KELALAIAN.
-- Karakter di game ini disimpan sebagai Model 3D di
-- ReplicatedStorage.Assets.Characters.<Rarity>.<Nama> -- tidak ada art 2D di
-- mana pun. Diuji: thumbnail Roblox untuk mesh-nya membalas state "Completed"
-- tapi URL CDN-nya 404 dengan badan JSON error (aset 2D biasa berhasil, jadi
-- yang gagal memang khusus mesh). Kalau nanti mau ada gambar, isi PETA_GAMBAR
-- di bawah dengan URL yang kamu hosting sendiri.
local Webhook = { terkirim = 0, gagal = 0, dilewati = 0, pesanGalat = "" }

-- Potret 24 karakter Ancient ke atas. Dibuat sendiri, karena game ini tidak
-- menyimpan art 2D di mana pun: model 3D-nya dirender ke ViewportFrame lalu
-- dipotret, dibidik ke part Head dari arah LookVector-nya.
--
-- Kenapa cuma 24: hanya rarity Ancient ke atas yang memicu webhook, dan
-- seluruh game hanya punya 24 karakter di tingkat itu. Daftarnya tetap.
local BASE = "https://mozenian.github.io/framegenerator/ikon_karakter/"
local PETA_GAMBAR = {
    ["Ada Smasher"] = BASE .. "Ada_Smasher.png",
    ["Aemira"] = BASE .. "Aemira.png",
    ["Almira Eye"] = BASE .. "Almira_Eye.png",
    ["Angelia"] = BASE .. "Angelia.png",
    ["Astra"] = BASE .. "Astra.png",
    ["Changlia"] = BASE .. "Changlia.png",
    ["Darkfire"] = BASE .. "Darkfire.png",
    ["Elfaria"] = BASE .. "Elfaria.png",
    ["Emeliara"] = BASE .. "Emeliara.png",
    ["Exalia"] = BASE .. "Exalia.png",
    ["Froza"] = BASE .. "Froza.png",
    ["Girlyfang"] = BASE .. "Girlyfang.png",
    ["Griffina"] = BASE .. "Griffina.png",
    ["Guthia"] = BASE .. "Guthia.png",
    ["Kaneko II"] = BASE .. "Kaneko_II.png",
    ["Kira Ho"] = BASE .. "Kira_Ho.png",
    ["Limitless Goja"] = BASE .. "Limitless_Goja.png",
    ["Nekopura II"] = BASE .. "Nekopura_II.png",
    ["Rimura Tempesta"] = BASE .. "Rimura_Tempesta.png",
    ["Riyo Reaper"] = BASE .. "Riyo_Reaper.png",
    ["Ronova"] = BASE .. "Ronova.png",
    ["Rora Mercuri"] = BASE .. "Rora_Mercuri.png",
    ["Yang"] = BASE .. "Yang.png",
    ["Yin"] = BASE .. "Yin.png",
}

-- Warna embed mengikuti rarity supaya sekilas terlihat seberapa besar.
local WARNA = {
    Ancient = 0xC77B2E, God = 0xF2C230, Omniscient = 0x9B4DFF, Exclusive = 0xFF3B6B,
    Celestial = 0x4FC3F7, Supreme = 0xE04FD0, Divine = 0xFFE082, Ascended = 0x7CE0A3,
}

-- Constants.RarityOrder memetakan ANGKA -> NAMA (RO[14] = "Ancient"), bukan
-- sebaliknya. Membacanya sebagai RO.Ancient menghasilkan nil, dan perbandingan
-- ambangnya lalu gagal diam-diam -- modul lolos compile, jalan tanpa error, dan
-- tidak pernah mengirim satu pun laporan. Karena itu petanya DIBALIK di sini.
local function urutanRarity()
    local ok, C = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("Constants", 5))
    end)
    if not (ok and type(C) == "table" and type(C.RarityOrder) == "table") then return nil end
    local balik = {}
    for angka, nama in pairs(C.RarityOrder) do
        if type(nama) == "string" then balik[nama] = tonumber(angka) end
    end
    return (next(balik) ~= nil) and balik or nil
end

local function kirimDiscord(isi)
    local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (syn and syn.request) or (fluxus and fluxus.request)
    if not req then
        Webhook.gagal = Webhook.gagal + 1
        Webhook.pesanGalat = "executor tanpa fungsi request"
        return false
    end
    local ok, res = pcall(function()
        return req({
            Url = Config.Webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(isi),
        })
    end)
    if not ok then
        Webhook.gagal = Webhook.gagal + 1
        Webhook.pesanGalat = tostring(res):sub(1, 70)
        return false
    end
    local kode = res and (res.StatusCode or res.Status) or 0
    -- Discord membalas 204 tanpa badan kalau berhasil.
    if kode == 204 or kode == 200 then
        Webhook.terkirim = Webhook.terkirim + 1
        return true
    end
    Webhook.gagal = Webhook.gagal + 1
    Webhook.pesanGalat = "HTTP " .. tostring(kode)
    return false
end

local function laporkan(hadiah)
    local nama = tostring(hadiah.name or "?")
    local rarity = tostring(hadiah.rarity or "?")
    local mutasi = tostring(hadiah.typeName or "")
    local pemain = game:GetService("Players").LocalPlayer.Name

    local kolom = {
        { name = "Character", value = "**" .. nama .. "**", inline = true },
        { name = "Rarity",    value = rarity,               inline = true },
        { name = "Player",    value = pemain,               inline = true },
    }
    -- SELALU ada, walau kosong. Kolom yang kadang muncul kadang tidak membuat
    -- tata letak embed melompat antar laporan, dan pembaca jadi ragu apakah
    -- karakternya memang polos atau datanya yang hilang.
    table.insert(kolom, { name = "Mutation", value = (mutasi ~= "" and mutasi) or "-", inline = true })
    -- Peluang jauh lebih berkesan sebagai "1 dari N" daripada persen berkoma.
    local p = tonumber(hadiah.chancePercent)
    if p and p > 0 then
        table.insert(kolom, { name = "Chance", value = string.format("1 in %s",
            (function()
                local n = math.floor(100 / p + 0.5)
                local s = tostring(n)
                local hasil = ""
                while #s > 3 do
                    hasil = "," .. string.sub(s, -3) .. hasil
                    s = string.sub(s, 1, -4)
                end
                return s .. hasil
            end)()), inline = true })
    end
    local cps = tonumber(hadiah.cps)
    if cps then
        table.insert(kolom, { name = "CPS", value = "$" .. tostring(math.floor(cps)) .. "/s", inline = true })
    end

    local embed = {
        title = "Character Obtained",
        color = WARNA[rarity] or 0xB91C1C,
        fields = kolom,
        footer = { text = "Fish an Anime RNG | Mozeframe" },
    }
    local gbr = PETA_GAMBAR[nama]
    if gbr then embed.thumbnail = { url = gbr } end

    kirimDiscord({ username = "Mozeframe", embeds = { embed } })
end

local function pasangWebhook()
    if type(Config.Webhook) ~= "string" or Config.Webhook == "" then return end
    local RO = urutanRarity()
    if not RO then
        Webhook.pesanGalat = "Constants.RarityOrder tidak terbaca"
        return
    end
    local ambang = RO[Config.WebhookMinRarity] or RO.Ancient or 14

    local State = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("FishingState")
    S.conn[#S.conn + 1] = State.OnClientEvent:Connect(function(d)
        if typeof(d) ~= "table" or tostring(d.kind) ~= "Completed" then return end
        if type(d.rewards) ~= "table" then return end
        -- rewards itu ARRAY: satu tarikan bisa memberi beberapa karakter
        -- sekaligus (multi-pull), dan tiap butir dinilai sendiri.
        for _, hadiah in pairs(d.rewards) do
            if type(hadiah) == "table" and hadiah.rarity then
                local peringkat = RO[tostring(hadiah.rarity)]
                -- Papan Best Catch memajang lima terbaik SESI INI, jadi ia diberi
                -- makan tiap tangkapan -- bukan hanya yang lolos ambang Discord.
                pcall(Layar.tawarkan, tostring(hadiah.name), tostring(hadiah.rarity),
                      peringkat, tostring(hadiah.typeName or ""), tonumber(hadiah.cps))
                if peringkat and peringkat >= ambang then
                    task.spawn(function() pcall(laporkan, hadiah) end)
                else
                    Webhook.dilewati = Webhook.dilewati + 1
                end
            end
        end
    end)
    catat("webhook aktif, ambang %s ke atas", tostring(Config.WebhookMinRarity))
end

-- =========================================================================
-- PUNGUT GEM EVENT
--
-- Sebagian event menjatuhkan gem dari langit. Terbaca dari Constants:
--
--   TypeEvents.Events["Hell's Gates"].Gem = { RewardGems=100, SpawnEverySeconds=3,
--       SpawnHeight=150, SpawnRadius=200, FallSpeed=170, MaxAlive=100,
--       LifetimeSeconds=420 }
--
-- Setelan yang sama dipakai event "S U B  Z E R O". Satu butir 100 gem, muncul
-- tiap 3 detik selama event -- sekitar 20.000 gem per event 10 menit kalau
-- semuanya terpungut.
--
-- CARA MEMUNGUTNYA, DAN KENAPA JARAK TIDAK PENTING.
-- Butirnya BasePart bernama "Gem", anak langsung Workspace, Anchored=true,
-- CanCollide=false, CanTouch=true, dan membawa TouchInterest. Jadi ia dipungut
-- lewat SENTUHAN -- dan sentuhan bisa dipalsukan tanpa mendekat.
--
-- TERUKUR di akun sungguhan saat event Hell's Gates berjalan:
--   satu butir di jarak 349 stud -> firetouchinterest -> +100 gem, butir lenyap
--   sapuan 45 detik -> 97 butir, +9.840 gem, 0 gagal
--
-- Karena itu fitur ini TIDAK memindahkan karakter sama sekali, berbeda dari
-- ide auto-teleport yang sudah dibuang.
--
-- DEFAULT NYALA: memungut tidak bisa merugikan. Yang tidak diambil justru
-- hangus sendiri sesudah LifetimeSeconds.
local Gem = { dipungut = 0, gagal = 0, terakhirAda = 0 }

local function sapuGem()
    if type(firetouchinterest) ~= "function" then return end
    local pemain = game:GetService("Players").LocalPlayer
    local hrp = pemain.Character and pemain.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- GetChildren, BUKAN GetDescendants: butirnya selalu anak langsung Workspace,
    -- dan menyapu 25 ribu turunan tiap dua detik itu boros di jalur yang juga
    -- dipakai mancing.
    local ada = 0
    for _, d in ipairs(workspace:GetChildren()) do
        if d:IsA("BasePart") and d.Name == "Gem" and d.Parent then
            ada = ada + 1
            local ok = pcall(function()
                firetouchinterest(hrp, d, 0)
                firetouchinterest(hrp, d, 1)
            end)
            if ok then Gem.dipungut = Gem.dipungut + 1 else Gem.gagal = Gem.gagal + 1 end
        end
    end
    Gem.terakhirAda = ada
end

local function jagaGem()
    -- Ditunda: saat script baru dimuat, karakter sering belum ada.
    task.wait(5)
    while S.hidup do
        if Config.AutoGem then pcall(sapuGem) end
        -- 2 detik sudah rapat: butir hidup 420 detik dan maksimal 100 sekaligus,
        -- jadi tidak ada yang sempat hangus. Lebih rapat cuma memakan waktu di
        -- jalur yang sama dengan mancing tanpa menambah hasil.
        task.wait(Config.JedaGem)
    end
end

-- =========================================================================
-- AUTO KLAIM: PLAYTIME REWARDS, QUEST, HADIAH HARIAN
--
-- Ketiganya menumpuk sendiri selama script jalan berjam-jam, dan semuanya
-- hangus kalau tidak diambil. Tidak ada yang bisa hilang dengan mengklaim --
-- karena itu fitur ini DEFAULT NYALA, berbeda dari boost dan auto pindah kolam
-- yang default mati karena efeknya tidak bisa dibatalkan.
--
-- BENTUK DATA, TERBACA LANGSUNG DARI SERVER (bukan tebakan):
--
--   GetPlaytimeRewardsState -> { rewardStates = { [i] = {ready, claimed, remaining} },
--                                waitSecondsByReward, claimedMask, totalRewards }
--   QuestGetState           -> { totalCompleted, quests = { [i] = {claimable, id, title, ...} } }
--   GetDailyRewardsState    -> { totalDays, unlockedDay, claimedMask, timer }
--
-- TERUKUR: ClaimPlaytimeReward:InvokeServer(6) mengubah claimedMask 31 -> 63
-- dan rewardStates[6] jadi claimed=true. Jadi tanda tangannya memang indeks
-- angka, bukan id atau tabel.
--
-- BELUM TERUJI: QuestClaimAll. Saat diperiksa tidak ada satu pun quest yang
-- claimable, jadi jalur itu tidak pernah benar-benar dijalankan. Ia dibungkus
-- pcall dan kegagalannya dicatat, bukan didiamkan -- kalau tanda tangannya
-- ternyata beda, itu akan terlihat di log alih-alih hilang.
local Klaim = { playtime = 0, quest = 0, harian = 0, galat = 0, pesanGalat = "" }

local function remotes()
    local ok, R = pcall(function()
        return game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5)
    end)
    return ok and R or nil
end

-- Tiap bagian dibungkus pcall SENDIRI. Satu pcall besar membuat kegagalan di
-- playtime ikut membatalkan quest dan harian, dan gejalanya "auto klaim tidak
-- jalan" tanpa satu pun keterangan bagian mana yang bermasalah.
local function langkahKlaim(nama, f)
    local ok, err = pcall(f)
    if not ok then
        Klaim.galat = Klaim.galat + 1
        Klaim.pesanGalat = nama .. ": " .. tostring(err):sub(1, 60)
        catat("klaim/%s gagal: %s", nama, tostring(err):sub(1, 60))
    end
    return ok
end

local function klaimPlaytime(R)
    local st = R.GetPlaytimeRewardsState:InvokeServer()
    if type(st) ~= "table" or type(st.rewardStates) ~= "table" then return end
    for i, r in pairs(st.rewardStates) do
        if type(r) == "table" and r.ready and not r.claimed then
            R.ClaimPlaytimeReward:InvokeServer(i)
            Klaim.playtime = Klaim.playtime + 1
            catat("klaim playtime #%s", tostring(i))
            -- Jeda kecil antar klaim: server memperbarui state-nya sendiri, dan
            -- menembak beruntun tanpa jeda pernah membuat klaim kedua mengenai
            -- keadaan yang belum sempat berubah.
            task.wait(0.35)
        end
    end
end

local function klaimQuest(R)
    local qs = R.QuestGetState:InvokeServer()
    if type(qs) ~= "table" or type(qs.quests) ~= "table" then return end
    local bisa = 0
    for _, q in pairs(qs.quests) do
        if type(q) == "table" and q.claimable then bisa = bisa + 1 end
    end
    if bisa == 0 then return end
    -- ClaimAll didahulukan: satu panggilan untuk semua. Kalau ia gagal, jatuh
    -- ke klaim satu per satu -- lebih berisik tapi tidak ikut mati.
    local ok = pcall(function() R.QuestClaimAll:InvokeServer() end)
    if not ok then
        for _, q in pairs(qs.quests) do
            if type(q) == "table" and q.claimable and q.id then
                pcall(function() R.QuestClaim:InvokeServer(q.id) end)
                task.wait(0.3)
            end
        end
    end
    Klaim.quest = Klaim.quest + bisa
    catat("klaim %d quest", bisa)
end

local function klaimHarian(R)
    local ds = R.GetDailyRewardsState:InvokeServer()
    if type(ds) ~= "table" then return end
    local hari = tonumber(ds.unlockedDay)
    local mask = tonumber(ds.claimedMask) or 0
    if not hari or hari < 1 then return end
    -- claimedMask itu bitmask: bit ke-(hari-1) menyala berarti sudah diambil.
    local bit = 2 ^ (hari - 1)
    if math.floor(mask / bit) % 2 == 1 then return end
    R.ClaimDailyReward:InvokeServer(hari)
    Klaim.harian = Klaim.harian + 1
    catat("klaim hadiah harian #%d", hari)
end

local function klaimSekali()
    local R = remotes()
    if not R then return end
    langkahKlaim("playtime", function() klaimPlaytime(R) end)
    langkahKlaim("quest", function() klaimQuest(R) end)
    if Config.KlaimHarian then
        langkahKlaim("harian", function() klaimHarian(R) end)
    end
end

local function jagaKlaim()
    -- Ditunda sebentar di awal: saat script baru dimuat, Remotes dan state
    -- pemain sering belum siap, dan klaim pertama akan gagal tanpa sebab.
    task.wait(8)
    while S.hidup do
        if Config.AutoKlaim then pcall(klaimSekali) end
        task.wait(Config.JedaKlaim)
    end
end

-- Script ini tidak punya variabel LocalPlayer di scope berkas -- tiap tempat
-- mengambilnya sendiri. Modul ini ikut begitu supaya tidak bergantung pada
-- urutan deklarasi di luar dirinya.
local PemainLokal = game:GetService("Players").LocalPlayer

local Kolam = {
    ukur = {},          -- nama -> {n, jum} waktu tunggu SUNGGUHAN
    pilihan = nil,      -- nama kolam yang sedang dituju
    alasan = "",        -- ditampilkan di MozeFishInfo
    skor = {},          -- nama -> rincian, untuk panel
    kekuatan = 0,
}

-- Urutan rarity dari rendah ke tinggi. Dipakai HANYA untuk memutuskan apakah
-- sebuah kolam layak masuk kelas prioritas -- bukan untuk menaksir harga.
-- Urutan RESMI, disalin dari Constants.RarityOrder. Tabel sebelumnya di sini
-- dikarang dari ingatan dan SALAH di lima tempat (Secret dan Rainbow tertukar,
-- Supreme/Celestial tertukar, God dan Omniscient tertukar, Exclusive hilang).
-- Itu dipakai memutuskan kolam mana yang masuk kelas prioritas, jadi salahnya
-- tidak kelihatan sampai kolam event benar-benar muncul.
local URUT_RARITY = {
    Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythical = 6,
    Cosmic = 7, Secret = 8, Rainbow = 9, Ascended = 10, Divine = 11,
    Supreme = 12, Celestial = 13, Ancient = 14, God = 15, Omniscient = 16,
    Exclusive = 17,
}

local function konstanta()
    local ok, C = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("Constants", 5))
    end)
    if ok and type(C) == "table" and type(C.Fishing) == "table" then return C.Fishing end
    return nil
end

-- Yang menentukan bukan rod di tangan melainkan rod TERKUAT yang dimiliki:
-- Strength memutuskan kolam mana yang boleh dimasuki, dan pemain bisa saja
-- sedang memegang rod lemah tanpa sadar.
local function rodTerkuat(F)
    local terbaik, kuat = nil, 0
    local function periksa(alat)
        if not alat or not alat.Name then return end
        local s = tonumber(alat:GetAttribute("RodStrength"))
        if not s then
            local cfg = F.Rods and F.Rods[alat.Name]
            s = cfg and tonumber(cfg.Strength)
        end
        if s and s > kuat then terbaik, kuat = alat.Name, s end
    end
    for _, v in ipairs(PemainLokal.Backpack:GetChildren()) do periksa(v) end
    if PemainLokal.Character then
        for _, v in ipairs(PemainLokal.Character:GetChildren()) do
            if v:IsA("Tool") then periksa(v) end
        end
    end
    return terbaik, kuat
end

local function rerata(t, bawaan)
    if type(t) ~= "table" then return bawaan end
    local mn, mx = tonumber(t.Min), tonumber(t.Max)
    if mn and mx then return (mn + mx) / 2 end
    return bawaan
end

-- Harapan jumlah karakter per tangkapan, sesudah pengali kolam diterapkan.
local function harapanTarikan(rodCfg, pondCfg)
    local dasar = (pondCfg and pondCfg.MultiPullChances) or (rodCfg and rodCfg.MultiPullChances)
    if type(dasar) ~= "table" then return 1 end
    local mult = pondCfg and pondCfg.MultiPullChancesMultiplier
    local tot, jum = 0, 0
    for k, v in pairs(dasar) do
        local n = tonumber(k) or 1
        local p = v * ((mult and (mult[k] or mult[n])) or 1)
        tot = tot + p
        jum = jum + n * p
    end
    return tot > 0 and (jum / tot) or 1
end

-- Waktu tunggu rata-rata di kolam ini, dalam detik.
--
-- HASIL UKUR SELALU MENANG ATAS TAKSIRAN, dan itu pelajaran mahal. Taksiran
-- dari Constants sempat dipakai sendirian dan hasilnya SALAH TOTAL:
--
--   ditaksir   PONDAREA1 0 dtk   PONDAREA2 2,2 dtk  -> P1 delapan kali lebih baik
--   diukur     PONDAREA1 1,09    PONDAREA2 0,952    -> P2 justru 13% lebih cepat
--
-- Sebabnya PondCatchTimeMulti = 0 ternyata berarti "tanpa modifier", bukan
-- "dikali nol" -- dan yang benar-benar menentukan adalah upgrade pemain
-- (UpgFasterCatch, QuickFish, gamepass), yang tidak ada di tabel kolam sama
-- sekali. Jadi taksiran di bawah HANYA dipakai untuk kolam yang belum pernah
-- dikunjungi, dan bahkan di situ ia cuma urutan kasar.
local function taksirTunggu(rodCfg, pondCfg)
    if type(pondCfg.PondCatchTime) == "table" then
        return rerata(pondCfg.PondCatchTime, 3)
    end
    local dasar = rerata(rodCfg and rodCfg.PondCatchTime, 3)
    -- NOL BERARTI "TANPA MODIFIER", BUKAN "DIKALI NOL". Salah membaca ini
    -- membuat PONDAREA1 ditaksir 0 detik -- yang berarti laju tak terhingga --
    -- dan penilai selalu memilihnya. Terukur di server, PONDAREA1 justru 1,09
    -- dtk dan PONDAREA2 0,952 dtk, jadi arahnya terbalik total.
    local mn = tonumber(pondCfg.PondCatchTimeMultiMINIMUM)
    local mx = tonumber(pondCfg.PondCatchTimeMultiMAXIMUM)
    if mn == 0 then mn = nil end
    if mx == 0 then mx = nil end
    if not mn and not mx then return dasar end
    if not mn then return dasar * mx end
    if not mx then return dasar * mn end
    return dasar * ((mn + mx) / 2)
end

-- Rata-rata TERUKUR kalau sampelnya cukup, taksiran kalau belum pernah ke sana.
-- Ambang 8 sampel: cukup untuk menstabilkan rata-rata, masih cepat terkumpul.
local function perkiraanTunggu(rodCfg, pondCfg, nama)
    local u = Kolam.ukur[nama]
    if u and u.n >= 8 then return u.jum / u.n, true end
    return taksirTunggu(rodCfg, pondCfg), false
end

-- Dipanggil dari handler Started: satu-satunya sumber angka yang benar.
function Kolam.catatTunggu(nama, detik)
    if not nama or type(detik) ~= "number" or detik <= 0 then return end
    local u = Kolam.ukur[nama]
    if not u then
        u = { n = 0, jum = 0 }
        Kolam.ukur[nama] = u
    end
    -- Jendela bergulir 60: kalau server menyeimbangkan ulang, angka lama tidak
    -- menahan rata-rata selamanya.
    if u.n >= 60 then
        u.jum = u.jum * (59 / 60)
        u.n = 59
    end
    u.n = u.n + 1
    u.jum = u.jum + detik
end

-- Kolam yang MEMAKSA satu rarity tinggi (RarityChances dengan satu entri 100).
-- Ini kelas tersendiri: kolam event seperti PONDAREA7 (God 100%) nilainya jauh
-- di atas apa pun yang bisa dikejar dengan menghemat milidetik, dan model laju
-- tidak bisa melihat itu karena tidak tahu harga.
local function rarityPaksa(pondCfg)
    local rc = pondCfg.RarityChances
    if type(rc) ~= "table" then return nil, 0 end
    local nama, nilai = nil, 0
    for k, v in pairs(rc) do
        local n = tonumber(v)
        if n and n > nilai then nama, nilai = tostring(k), n end
    end
    if nama and nilai >= 100 then return nama, URUT_RARITY[nama] or 0 end
    return nil, 0
end

-- Instance kolam yang ada di dunia, TERDEKAT dengan kita.
--
-- DUA PART BERBEDA, DAN MEMBEDAKANNYA ITU PENTING:
--
--   PONDAREA<n>    zona pemicu di atas AIR. Size.Y = 0, Transparency = 1,
--                  CanCollide = false. Ini yang dikirim ke FishingRequestStart.
--   TPPONDAREA<n>  penanda 1x1x1 di folder PondAreasTeleports -- titik BERDIRI
--                  yang disediakan game, di darat, dekat dock dan papan strength.
--
-- Teleport ke PONDAREA sudah dicoba dan hasilnya: nyemplung ke air, lalu server
-- memulangkan kita 549 stud dalam 3 detik. Nyawa tetap penuh, jadi itu bukan
-- anti-cheat -- cuma jatuh ke tempat yang bukan pijakan. Karena itu tujuan
-- teleport WAJIB memakai TPPONDAREA, sedangkan penentuan "kolam ini ada di
-- dunia atau tidak" tetap memakai PONDAREA.
local function partKolam(nama, untukPijakan)
    local hrp = PemainLokal.Character and PemainLokal.Character:FindFirstChild("HumanoidRootPart")
    local cari = untukPijakan and ("TP" .. nama) or nama
    local dekat, jarak = nil, math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == cari then
            local j = hrp and (d.Position - hrp.Position).Magnitude or 0
            if j < jarak then dekat, jarak = d, j end
        end
    end
    -- Tidak semua kolam punya penanda TP -- kolam event mungkin tidak. Kalau
    -- tidak ada, lebih baik tidak pindah sama sekali daripada nyemplung lagi.
    return dekat, jarak
end

-- Menilai semua kolam yang BOLEH dimasuki, lalu mengembalikan yang terbaik.
function Kolam.nilai()
    local F = konstanta()
    if not F or type(F.Ponds) ~= "table" then return nil, "Constants.Fishing tidak terbaca" end

    if Config.PondPaksa and F.Ponds[Config.PondPaksa] then
        return Config.PondPaksa, "dikunci manual"
    end

    local namaRod, kuat = rodTerkuat(F)
    Kolam.kekuatan = kuat
    local rodCfg = namaRod and F.Rods and F.Rods[namaRod] or nil

    -- Ongkos tetap tiap siklus di luar penungguan: restart + jaringan. Diukur
    -- terus oleh script, jadi peringkatnya ikut mengikuti koneksi sungguhan.
    local overhead = (S.nRestart > 0) and (S.jumRestart / S.nRestart) or 0.3
    if overhead < 0.05 then overhead = 0.05 end

    local terbaik, skorTerbaik, alasan = nil, -1, ""
    local prioritasTerbaik = -1
    Kolam.skor = {}

    for nama, cfg in pairs(F.Ponds) do
        local perlu = tonumber(cfg.RequiredStrength) or 0
        local part = partKolam(nama)
        -- Kolam tanpa wujud di dunia dilewati diam-diam: PONDAREA7-12 adalah
        -- kolam event yang cuma muncul sesekali, dan menargetkannya saat tidak
        -- ada berarti script menembak ke tempat kosong selamanya.
        if part and kuat >= perlu then
            local tunggu, terukur = perkiraanTunggu(rodCfg, cfg, nama)
            local karakter = harapanTarikan(rodCfg, cfg)
            local skor = karakter / (tunggu + overhead)
            local rNama, rTingkat = rarityPaksa(cfg)
            local ambangPri = URUT_RARITY[Config.RarityPrioritas] or 6
            local prioritas = (rNama and rTingkat >= ambangPri) and rTingkat or 0

            Kolam.skor[nama] = { skor = skor, tunggu = tunggu, karakter = karakter,
                                 prioritas = prioritas, rarity = rNama, terukur = terukur }

            -- Kelas prioritas menang lebih dulu, baru skor laju.
            if prioritas > prioritasTerbaik
               or (prioritas == prioritasTerbaik and skor > skorTerbaik) then
                terbaik, skorTerbaik, prioritasTerbaik = nama, skor, prioritas
                if prioritas > 0 then
                    alasan = string.format("%s memaksa %s 100 persen", nama, tostring(rNama))
                else
                    alasan = string.format("%s: %.2f karakter/dtk (tunggu %.2f dtk, %s)",
                        nama, skor, tunggu, terukur and "terukur" or "taksiran")
                end
            end
        end
    end

    return terbaik, alasan
end

-- Ambang tolak-roll AWAL untuk kolam ini, dihitung dari Constants alih-alih
-- menunggu 20 sampel. Bedanya terasa persis saat berpindah kolam: tanpa ini,
-- puluhan roll pertama dinilai memakai ambang milik kolam LAMA.
function Kolam.ambangAwal(nama)
    local F = konstanta()
    if not F or not F.Ponds or not F.Ponds[nama] then return nil end
    local namaRod = rodTerkuat(F)
    local rodCfg = namaRod and F.Rods and F.Rods[namaRod] or nil
    local tunggu = perkiraanTunggu(rodCfg, F.Ponds[nama], nama)
    -- Kolam tanpa penungguan (PONDAREA1) tidak punya apa pun untuk ditolak.
    if tunggu <= 0 then return nil end
    -- Sedikit di bawah rata-rata: kira-kira separuh roll ditolak sejak awal,
    -- lalu penala otomatis mengambil alih begitu sampelnya cukup.
    return math.max(Config.AmbangMin, math.min(Config.AmbangMaks, tunggu * 0.8))
end



-- Penjaga berkala. Sengaja jarang: memindai seluruh workspace itu mahal, dan
-- kolam tidak berganti tiap detik. Yang berubah cuma kolam EVENT, dan jeda 20
-- detik masih menangkapnya jauh sebelum event berakhir.
-- Menilai kolam lalu MENYARANKAN -- tidak pernah memindahkan karakter.
--
-- Auto-teleport sengaja DIBUANG. Ini script pendamping: pemain yang memegang
-- kendali atas posisinya sendiri, dan karakter yang berpindah tanpa diminta di
-- tengah permainan itu mengejutkan, bukan membantu. Kemampuan teleportnya
-- sendiri sudah terbukti jalan saat diuji (penanda TPPONDAREA, bertahan tanpa
-- ditarik server), tapi terbukti bisa bukan alasan untuk memakainya.
--
-- Yang tersisa berguna: menghitung kolam mana yang paling produktif dengan rod
-- yang kamu punya, lalu menampilkannya di panel supaya kamu yang memutuskan.
local function jagaKolam()
    while S.hidup do
        task.wait(Config.JedaPeriksaPond)
        if Config.SaranKolam then
            local ok, err = pcall(function()
                local nama, alasan = Kolam.nilai()
                if not nama then return end
                Kolam.pilihan, Kolam.alasan = nama, alasan
                -- Dicatat SEKALI saja tiap kali saran berubah. Kolam yang sama
                -- dilaporkan tiap 20 detik cuma memenuhi konsol.
                if nama ~= S.pondName and nama ~= Kolam.saranTerakhir then
                    Kolam.saranTerakhir = nama
                    catat("saran kolam: %s | %s", nama, alasan)
                elseif nama == S.pondName then
                    Kolam.saranTerakhir = nil
                end
                if Gui.ada then pcall(Gui.catPond) end
            end)
            if not ok then catat("jagaKolam galat: %s", tostring(err):sub(1, 70)) end
        end
    end
end


-- Ambang yang BERLAKU sekarang: angka manual kalau diisi, hasil hitungan
-- kalau mode auto, dan AmbangAwal selama sampel belum cukup.
local function ambang()
    local manual = tonumber(Config.AmbangRoll)
    if manual then return manual end
    return S.ambangAktif or S.ambangKolam or Config.AmbangAwal
end

-- =========================================================================
-- PENDENGAR
S.conn[#S.conn + 1] = FishingState.OnClientEvent:Connect(function(d)
    if typeof(d) ~= "table" then return end
    local kind = tostring(d.kind)
    local t = os.clock()
    -- Penanda "server mancing masih menjawab kita". Dipakai untuk memastikan
    -- penyalaan ulang sesudah pindah benar-benar nyangkut; tPanen tidak bisa
    -- dipakai karena baru bergerak saat Completed, dan itu bisa beberapa detik
    -- kemudian. HARUS di bawah `local t` -- sempat ditulis di atasnya, dan di
    -- situ `t` masih global nil sehingga penandanya tidak pernah terisi.
    S.tSinyal = t
    -- Hanya kejadian yang berarti "mancing benar-benar berjalan". `Denied` dan
    -- `Stopped` SENGAJA tidak masuk: keduanya juga balasan server, jadi kalau
    -- ikut dihitung, pemastian di bawah lolos padahal pancingan justru ditolak
    -- -- lolos-palsu yang membuat panen berhenti diam-diam.
    if kind == "Started" or kind == "Hooked" or kind == "Progress" or kind == "Completed" then
        S.tSinyalBaik = t
    end

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
            S.ditolakBeruntun = 0
            return
        end

        -- BUSY berarti sesi kita SENDIRI masih berjalan -- bukan masalah kolam,
        -- dan sering muncul saat dua tembakan berpapasan. Terukur: satu probe
        -- luar yang menembak bersamaan menghasilkan belasan BUSY berturut-turut
        -- padahal loop utamanya sehat. Memicu pemindaian workspace karena ini
        -- cuma memboroskan waktu di jalur yang paling panas.
        if tostring(d.reason) == "BUSY" then return end

        -- Sebab SELAIN rod dan BUSY -- yang paling sering: kolam yang kita
        -- pegang sudah jauh karena pemain pindah. Dulu cabang ini kosong dan
        -- script diam selamanya. Ditunggu tiga kali dulu supaya penolakan
        -- sesaat tidak memicu pemindaian workspace yang mahal.
        S.ditolakBeruntun = (S.ditolakBeruntun or 0) + 1
        if S.ditolakBeruntun >= 3
           and (not S.tDeteksi or (t - S.tDeteksi) > 3) then
            S.tDeteksi = t
            S.ditolakBeruntun = 0
            if deteksiKolam() then
                if Gui.ada then pcall(Gui.catPond) end
                task.delay(0.3, tembak)
            end
        end
        return
    end

    if kind == "Started" then
        S.ditolakBeruntun = 0
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
            -- Ambang sementara dari Constants, dipakai sampai sampel kolam BARU
            -- cukup. Tanpa ini puluhan roll pertama dinilai dengan ambang milik
            -- kolam lama -- salah, dan tanpa satu pun error.
            S.ambangKolam = Kolam.ambangAwal(S.pondName)
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
            Kolam.catatTunggu(S.pondName, w)
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

    elseif kind == "Progress" then
        -- TANGKAPAN BISA MENGGANTUNG DI SINI. Terukur 2026-08-28: sesudah
        -- `Hooked`, server mengirim { kind="Progress", clicks=0,
        -- requiredClicks=1 } dan TIDAK PERNAH mengirim `Completed` sampai
        -- kliknya masuk. Gejalanya paling menipu: `Progress` mengalir terus
        -- sehingga terlihat sibuk, tapi panennya NOL -- 45 detik tanpa satu
        -- pun tangkapan, sementara panel tetap tampak sehat.
        --
        -- Tidak semua kolam/rod memintanya (sebagian mengirim Completed
        -- langsung), jadi kliknya dikirim hanya sebanyak yang KURANG.
        if FishingClick then
            local perlu = tonumber(d.requiredClicks) or 0
            local sudah = tonumber(d.clicks) or 0
            for _ = 1, math.max(0, perlu - sudah) do
                pcall(function() FishingClick:FireServer() end)
            end
        end

    elseif kind == "Completed" then
        if not S.tMulai then S.tMulai = t end
        S.siklus = S.siklus + 1
        -- Dihitung dengan pairs, bukan #d.rewards: panjang tabel Luau tidak
        -- bisa dipercaya untuk tabel yang datang dari jaringan -- terukur
        -- pernah melaporkan 3 untuk isi yang sebenarnya 4.
        local n = 0
        if type(d.rewards) == "table" then
            for _ in pairs(d.rewards) do n = n + 1 end
        end
        S.karakter = S.karakter + (n > 0 and n or 1)
        S.tCompleted = t
        -- tCompleted DIHAPUS lagi di handler Started, jadi tidak bisa dipakai
        -- untuk menjawab "masih panen atau tidak". tPanen tidak pernah dihapus.
        S.tPanen = t

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

    -- TINGGI naik dari 242 saat baris AUTO FEED dan AUTO SPOT ditambahkan;
    -- tanpa itu dua tombol terakhir terpotong di bawah bingkai.
    local LEBAR, TINGGI, TINGGI_KECIL = 212, 302, 32

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

    local bPond = pil("Pond", 14, 184, 148, 24)
    bPond.TextSize = 11

    local bLayar = pil("Layar", 14, 184, 178, 24)
    bLayar.TextSize = 11

    -- Feed dan mode dipisah: modenya diputar tanpa harus mematikan fiturnya,
    -- supaya bisa ganti strategi di tengah jalan.
    local bFeed = pil("Feed", 14, 96, 208, 24)
    bFeed.TextSize = 11
    local bMode = pil("Mode", 114, 52, 208, 24)
    bMode.TextSize = 10
    -- Tombol ketiga di baris yang sama: berapa level sekali tekan (1/10/max).
    local bJum = pil("Jumlah", 170, 28, 208, 24)
    bJum.TextSize = 10

    local bSpot = pil("Spot", 14, 184, 238, 24)
    bSpot.TextSize = 11

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
            tombolRoll.Text = "BLATANT: N/A"
            tombolRoll.BackgroundColor3 = W.tombol
            tombolRoll.TextColor3 = W.redup
        elseif Config.TolakRoll then
            -- Dinamai BLATANT di panel: itu istilah yang dipakai pemakainya.
            -- Nama internalnya tetap TolakRoll supaya setelan lama tetap terbaca.
            tombolRoll.Text = "BLATANT: ON"
            tombolRoll.BackgroundColor3 = W.biru
            tombolRoll.TextColor3 = W.terang
        else
            tombolRoll.Text = "BLATANT: OFF"
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
    -- Angka besar sekarang KARAKTER per menit, bukan siklus. Keduanya dikirim
    -- supaya barisan rincinya tetap bisa menunjukkan laju tangkapan -- dua
    -- angka itu berbeda jauh begitu multi-pull aktif.
    local function catStat(karPerMenit, tangkapPerMenit, karakter, tolak, biaya)
        angka.Text = string.format("%.1f", karPerMenit or 0)
        rinci.Text = string.format("%d char · %.0f tangkap/mnt · buang %d · %s",
            karakter or 0, tangkapPerMenit or 0, tolak or 0,
            biaya and string.format("%.0fms", biaya * 1000) or "--")
    end

    -- Tombol ini TIDAK memindahkan apa pun -- ia melapor. Yang ditampilkan
    -- kolam tempat kita memancing SEKARANG, dan kalau ada yang lebih baik,
    -- namanya ikut disebut supaya pemain yang memutuskan mau pindah atau tidak.
    local function catLayar()
        if Config.LayarHitam then
            bLayar.Text = "BLACKSCREEN: ON"
            bLayar.BackgroundColor3 = Color3.fromRGB(58, 58, 74)
            bLayar.TextColor3 = Color3.fromRGB(232, 232, 240)
        else
            bLayar.Text = "BLACKSCREEN: OFF"
            bLayar.BackgroundColor3 = W.tombol
            bLayar.TextColor3 = W.redup
        end
    end

    local function catFeed()
        if Config.AutoFeed then
            bFeed.Text = "AUTO FEED: ON"
            bFeed.BackgroundColor3 = Color3.fromRGB(58, 58, 74)
            bFeed.TextColor3 = Color3.fromRGB(232, 232, 240)
        else
            bFeed.Text = "AUTO FEED: OFF"
            bFeed.BackgroundColor3 = W.tombol
            bFeed.TextColor3 = W.redup
        end
        bMode.Text = tostring(Config.FeedMode)
        bJum.Text = tostring(Config.FeedJumlah)
    end

    local function catSpot()
        if Config.AutoSpot then
            bSpot.Text = "AUTO SPOT: " .. tostring(Kolam.pilihan or "?")
            bSpot.BackgroundColor3 = Color3.fromRGB(58, 58, 74)
            bSpot.TextColor3 = Color3.fromRGB(232, 232, 240)
        else
            bSpot.Text = "AUTO SPOT: OFF"
            bSpot.BackgroundColor3 = W.tombol
            bSpot.TextColor3 = W.redup
        end
    end

    local function catPond()
        local kini = S.pondName
        if not Config.SaranKolam then
            bPond.Text = "POND: " .. tostring(kini or "?")
            bPond.BackgroundColor3 = W.tombol
            bPond.TextColor3 = W.redup
            return
        end
        local saran = Kolam.pilihan
        if kini and saran and saran ~= kini then
            bPond.Text = kini .. "  \f  " .. saran .. " lebih baik"
            bPond.BackgroundColor3 = Color3.fromRGB(150, 96, 24)
            bPond.TextColor3 = Color3.fromRGB(255, 240, 220)
        else
            bPond.Text = "POND: " .. tostring(kini or saran or "mencari...")
            bPond.BackgroundColor3 = Color3.fromRGB(28, 104, 96)
            bPond.TextColor3 = Color3.fromRGB(214, 255, 246)
        end
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
    bLayar.Activated:Connect(function()
        Config.LayarHitam = not Config.LayarHitam
        pcall(Layar.tampil, Config.LayarHitam)
        catLayar()
        tulisSimpanan()
    end)

    bPond.Activated:Connect(function()
        Config.SaranKolam = not Config.SaranKolam
        catPond()
        tulisSimpanan()
    end)

    bFeed.Activated:Connect(function()
        Config.AutoFeed = not Config.AutoFeed
        catFeed()
        tulisSimpanan()
    end)

    -- Diputar, bukan dropdown: lima pilihan tidak sepadan dengan menu, dan
    -- panel ini dipakai di layar penuh 8-10 klien.
    bMode.Activated:Connect(function()
        local i = 1
        for k, v in ipairs(MODE_FEED) do
            if v == Config.FeedMode then i = k break end
        end
        Config.FeedMode = MODE_FEED[(i % #MODE_FEED) + 1]
        catFeed()
        tulisSimpanan()
    end)

    bJum.Activated:Connect(function()
        local i = 1
        for k, v in ipairs(JUMLAH_FEED) do
            if v == Config.FeedJumlah then i = k break end
        end
        Config.FeedJumlah = JUMLAH_FEED[(i % #JUMLAH_FEED) + 1]
        catFeed()
        tulisSimpanan()
    end)

    bSpot.Activated:Connect(function()
        Config.AutoSpot = not Config.AutoSpot
        catSpot()
        tulisSimpanan()
    end)

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
    catPond()
    catLayar()
    catFeed()
    catSpot()

    Gui.ada = true
    Gui.sg = sg
    Gui.cat = cat
    Gui.catRoll = catRoll
    Gui.catNilai = catNilai
    Gui.catStat = catStat
    Gui.catFps = catFps
    Gui.catBoost = catBoost
    Gui.catPond = catPond
    Gui.catLayar = catLayar
    Gui.catFeed = catFeed
    Gui.catSpot = catSpot
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
-- Folder dunia yang tidak dipakai bot sama sekali. LeaderBoards saja berisi
-- 13.658 instance -- 52% dari seluruh workspace.
--
-- JUJUR SOAL HASILNYA: membuangnya diukur dan FPS TIDAK naik (231 -> 225,
-- selisih di dalam derau). Papan-papan itu rupanya tidak dirender saat berada
-- di luar layar, jadi jumlah instance bukan penghambatnya di mesin uji.
-- Tetap dibuang karena gratis dan bisa membantu perangkat lemah yang
-- menjalankan banyak klien -- tapi jangan berharap lonjakan.
--
-- PondAreas dan PondAreasTeleports TIDAK BOLEH IKUT: mancing mengirim
-- instance PONDAREA ke server, dan penanda TP dipakai menemukan kolam.
local FOLDER_SIA = {
    "LeaderBoards", "DevProducts", "TutorialAreas", "UpdateStands",
    "UpdateBoards", "LikesCounter",
    -- CharacterOfTheHour dan CharacterOfTheDay DIKELUARKAN: yang kedua berisi
    -- satu model ber-Humanoid (terukur: Guthia), jadi membuangnya ikut
    -- menghapus NPC yang terlihat pemain. Isinya cuma 15 dan 220 instance --
    -- tidak sepadan dengan satu NPC yang hilang.
}

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

    local scripted = workspace:FindFirstChild("Scripted")
    if scripted then
        for _, nama in ipairs(FOLDER_SIA) do
            -- Beberapa muncul lebih dari sekali (LikesCounter ada dua), jadi
            -- disapu berulang sampai habis, bukan sekali ambil.
            while true do
                local v = scripted:FindFirstChild(nama)
                if not v then break end
                Boost.peta = Boost.peta + #v:GetDescendants()
                local ok = pcall(function() v:Destroy() end)
                if not ok then break end
            end
        end
    end

    -- SpawnedCharacters SENGAJA TIDAK DISENTUH.
    --
    -- Dulu folder ini dikosongkan dengan ClearAllChildren. Itu ternyata
    -- membuang SELURUH NPC dunia -- terukur 8 model ber-Humanoid sekaligus
    -- (Frog Baddie, Histora Reissa, Touki, ...) -- dan karena sapuPeta diulang
    -- tiap 30 detik, NPC yang muncul lagi langsung dihapus lagi. Gejalanya
    -- persis seperti game yang rusak: "semua NPC ilang" dan tidak pernah balik
    -- sampai rejoin.
    --
    -- Yang dibeli dari penghapusan itu pun nol: lihat catatan di bawah, 13.958
    -- instance LeaderBoards cuma mengubah 231 -> 225 fps.

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
            -- sini DIPERTAHANKAN.
            --
            -- DIPANGKAS BESAR-BESARAN 2026-08-28. Daftar lama berisi 30 nama,
            -- termasuk SELURUH toko dan panel hadiah. Akibatnya nyata: dengan
            -- boost menyala, menekan prompt NPC upgrade tidak memunculkan apa
            -- pun, karena UpgradesStoreGUI sudah dihancurkan dan Frame yang
            -- dihancurkan tidak pernah dibuat ulang tanpa rejoin. Toko, sell,
            -- quest, daily, rebirth, trading -- semuanya ikut mati diam-diam.
            --
            -- JUJUR SOAL UNTUNG-RUGINYA. Terukur di dunia hidup: panel seperti
            -- UpgradesStoreGUI, StoreGUI, SettingsGUI semuanya sudah
            -- `Visible = false` selama tidak dibuka, dan Frame tak terlihat
            -- tidak dirender -- jadi secara waktu gambar seharusnya nol.
            -- TAPI tabel pengukuran di header menggabungkan "animasi & GUI"
            -- dalam satu baris (84,8 -> 115,4 fps), jadi bagian GUI-nya
            -- TIDAK PERNAH diukur sendirian dan angka itu tidak boleh
            -- dibebankan ke sini. Yang pasti terukur cuma jumlah instance
            -- PlayerGui turun 35.110 -> 5.314, dan di proyek ini jumlah
            -- instance sudah terbukti bukan penentu FPS.
            --
            -- Karena untungnya tidak terbukti sementara ruginya terbukti
            -- (semua toko mati), dipilih sisi yang menjaga toko tetap hidup.
            --
            -- Sisanya cuma layar sekali-tayang yang tidak punya prompt maupun
            -- tombol untuk dipanggil lagi.
            --
            -- FishAction SENGAJA tidak ada di daftar: runtime mancing milik game
            -- membacanya, dan membuangnya mematikan auto fish.
            local BUANG = {
                "IntroGUI", "CutsceneGUI",
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
                local tangkapMnt = perSiklus > 0 and (60 / perSiklus) or 0
                -- Karakter dibagi waktu berjalan langsung, bukan dikali
                -- rata-rata per siklus: multi-pull berubah-ubah tiap tarikan,
                -- jadi mengalikan rata-rata menambah galat tanpa alasan.
                local karMnt = jalan > 0 and (S.karakter / jalan * 60) or 0
                Gui.catStat(karMnt, tangkapMnt, S.karakter, S.tolak, S.biaya)
            end)
        end

        if Config.Lapor and os.clock() >= laporBerikut then
            laporBerikut = os.clock() + Config.IntervalLapor
            local jalan = os.clock() - (S.tMulai or os.clock())
            local perSiklus = S.siklus > 1 and (jalan / (S.siklus - 1)) or 0
            local restart = S.nRestart > 0 and (S.jumRestart / S.nRestart) or 0
            catat("%.1f karakter/menit (%.1f tangkap/mnt) | %d siklus | restart %.3f | buang %d | rr %s | diterima %d/%d%s",
                jalan > 0 and (S.karakter / jalan * 60) or 0,
                perSiklus > 0 and (60 / perSiklus) or 0, S.siklus, restart, S.tolak,
                S.biaya and string.format("%.0fms", S.biaya * 1000) or "-",
                S.diterima, S.tembak,
                Config.Aktif and "" or " | NONAKTIF")
        end
    end
end)

-- =========================================================================
-- GERAK -- satu pintu untuk semua yang memindahkan karakter
--
-- Auto feed dan auto spot sama-sama memindahkan karakter. Kalau keduanya
-- jalan bersamaan, yang satu menyeret yang lain di tengah urusan: posisi asal
-- tersimpan jadi milik siapa pun yang menyimpan terakhir, dan karakter tidak
-- pernah pulang ke kolam. Jadi keduanya WAJIB lewat sini.
-- =========================================================================
local Gerak = { sibuk = false }

local function pakaiGerak(nama, fn)
    if Gerak.sibuk then return false end
    Gerak.sibuk = true
    local ok, err = pcall(fn)
    Gerak.sibuk = false
    if not ok then catat("%s galat: %s", nama, tostring(err):sub(1, 70)) end
    return ok
end

-- Memasang rod terkuat yang dimiliki. Mengembalikan namanya.
--
-- Kalau rod-nya SUDAH dipegang, jangan equip ulang: itu memainkan animasi
-- pasang dan menyia-nyiakan waktu di jendela yang justru harus sesingkat
-- mungkin.
local function pasangRod()
    local F = konstanta()
    local nama = F and rodTerkuat(F)
    if not nama then return nil end
    local char = PemainLokal.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name == nama then return nama end
    end
    local alat = PemainLokal.Backpack:FindFirstChild(nama)
    if alat then pcall(function() hum:EquipTool(alat) end) end
    return nama
end

-- Menyalakan ulang mancing sesudah karakter dipindahkan.
--
-- WAJIB dipanggil sesudah SETIAP perpindahan. Begitu karakter meninggalkan
-- kolam, pancingan yang sedang jalan dibatalkan -- itu yang bikin mancingnya
-- "kebatalan terus". Tanpa penyalaan ulang, satu sesi feed menghentikan panen
-- sampai pemain menyadarinya sendiri.
local function nyalakanMancing(namaKolam)
    namaKolam = namaKolam or S.pondName or Kolam.pilihan
    if not namaKolam then return false end
    local part = partKolam(namaKolam)
    if not part then return false end
    pasangRod()
    S.pond, S.pondName, S.target = part, namaKolam, part.Position
    pcall(function() FishingRequestStart:FireServer(part, part.Position) end)
    -- Auto fish milik GAME. Sekali menyala ia menembak sendiri, jadi kalau
    -- fast restart kita telat sedetik pun panennya tidak ikut berhenti.
    if AutoFishSync then pcall(function() AutoFishSync:FireServer(true) end) end
    return true
end

-- Menyalakan mancing lalu MEMASTIKAN server menjawab.
--
-- KENAPA: menembak sekali lalu berharap ternyata tidak cukup. Sesudah pindah,
-- lemparan pertama sering ditolak karena posisi kita belum sampai di server,
-- dan kalau tidak diulang panen berhenti diam-diam sampai pemain sadar sendiri
-- -- persis keluhan "abis ngefeed kadang ga mancing".
local function pastikanMancing(namaKolam, maks)
    for _ = 1, (maks or 5) do
        local sebelum = S.tSinyalBaik
        if nyalakanMancing(namaKolam) then
            -- Terukur: sesudah kembali ke kolam, `Started` datang dalam 0,06
            -- detik dan `Completed` dalam 1,02 detik. Jendela 1 detik sudah
            -- longgar; lebih lama hanya menahan kunci gerak tanpa guna.
            local batas = os.clock() + 1.0
            while os.clock() < batas do
                if S.tSinyalBaik and S.tSinyalBaik ~= sebelum then return true end
                task.wait(0.05)
            end
        end
        -- Jeda antar percobaan: menembak beruntun tanpa jeda cuma menumpuk
        -- penolakan BUSY, dan itu ikut memicu penjaga gagal-beruntun.
        task.wait(0.3)
    end
    catat("mancing tidak menyala ulang di %s sesudah 4 percobaan", tostring(namaKolam))
    return false
end

-- =========================================================================
-- AUTO FEED -- menaikkan level karakter di plot sendiri
--
-- Level itu pengungkit terbesar di game ini: terukur Almira Eye base 125 juta
-- menghasilkan 5,7 MILIAR di level 149 (45x), sementara food menumpuk miliaran
-- tanpa terpakai.
--
-- Memberi makan dari jarak jauh MUSTAHIL, dan itu sudah dibuktikan berlapis:
--   * fireproximityprompt tidak pernah bekerja, bahkan dari 3 stud
--   * menaikkan atribut ServerMaxActivationDistance jadi 10000 memang membuat
--     prompt tampak terjangkau, tapi picuan dari 59 stud tetap ditolak
--   * StandPromptController (script client-nya) NOL menyentuh Triggered, dan
--     hook __namecall tidak menangkap satu remote pun saat level-up terjadi
-- Jadi picuannya ditangani server, dan jaraknya dijaga engine Roblox.
--
-- Yang tersisa: lompat, picu, balik -- dengan jendela sesingkat mungkin.
-- =========================================================================
local Feed = { status = "siap", naik = 0, sesi = 0, food = 0 }


-- Jeda per stand. Terukur di akun sungguhan, 4 stand tiap percobaan:
--   0,35/0,12/0,35 -> 3/4 dalam 3,34 dtk
--   0,18/0,06/0,18 -> 4/4 dalam 1,79 dtk   <- dasar angka di bawah
--   0,10/0,05/0,10 -> 2/4 dalam 1,08 dtk
--   0,05/0,03/0,05 -> 0/4 dalam 0,58 dtk
-- Tebingnya di bawah 0,10. Angka di bawah sengaja di sisi aman; sampelnya cuma
-- 4 per sel, jadi jangan ditala ulang berdasarkan satu percobaan.
local FEED_TIBA, FEED_TAHAN, FEED_PASCA = 0.20, 0.08, 0.20

-- 793200 -> "793.2K". Dipakai di status panel: angka food mentah 10 digit
-- tidak terbaca di baris selebar 184 piksel.
local function angkaRingkas(n)
    n = tonumber(n) or 0
    local satuan = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, s in ipairs(satuan) do
        if n >= s[1] then return string.format("%.1f%s", n / s[1], s[2]) end
    end
    return string.format("%d", n)
end

local function plotSendiri()
    local pp = workspace:FindFirstChild("PlayerPlots")
    if not pp then return nil end
    for _, plot in ipairs(pp:GetChildren()) do
        if tostring(plot:GetAttribute("OwnerUserId")) == tostring(PemainLokal.UserId) then
            return plot
        end
    end
    return nil
end

-- "793.2K" -> 793200. Harganya hanya ada sebagai teks di ActionText; tidak ada
-- atribut mana pun yang memuat angkanya.
local function bacaHarga(teks)
    local n, sat = tostring(teks):match("%(([%d%.]+)%s*([KMBT]?)")
    local v = tonumber(n)
    if not v then return nil end
    local kali = { K = 1e3, M = 1e6, B = 1e9, T = 1e12 }
    return v * (kali[sat] or 1)
end

-- Stand yang BISA dinaikkan sekarang.
--
-- ServerEnabled itu milik server: false berarti harganya belum terjangkau atau
-- karakternya sudah mentok. Menyaringnya di sini jauh lebih murah daripada
-- melompat ke sana lalu gagal -- tiap lompatan gagal tetap membayar ongkos
-- "karakter meninggalkan kolam".
--
-- LevelUp10 didahulukan: sepuluh level dalam satu lompatan jauh lebih sedikit
-- mengganggu mancing daripada sepuluh lompatan satu level. MaxLevelUp SENGAJA
-- tidak dipakai -- terukur 2,5 MILIAR sekali tekan, itu menguras seluruh
-- tabungan food dalam satu gerakan dan tidak bisa dibatalkan.
local function feedDaftar(mode)
    local plot = plotSendiri()
    if not plot then return {} end

    local perStand = {}
    for _, m in ipairs(plot:GetChildren()) do
        if m:IsA("Model") and tostring(m.Name):sub(1, 7) == "Placed_" then
            local sid = m:GetAttribute("StandId")
            if sid ~= nil then perStand[tostring(sid)] = m end
        end
    end

    local hasil = {}
    local function sapu(induk)
        if not induk then return end
        for _, node in ipairs(induk:GetChildren()) do
            local pn = node:FindFirstChild("PromptNode_Pickup")
            if pn then
                -- KOREKSI terukur: versi pertama selalu memilih LevelUp10 kalau
                -- ada. Hasilnya 1,07 MILIAR food terpakai untuk kenaikan yang
                -- sedikit -- LevelUp10 di stand mahal bisa ratusan juta sekali
                -- tekan. Sekarang keduanya dinilai dengan HARGA PER LEVEL, dan
                -- yang termurah per level yang menang.
                -- Tipe prompt ditentukan pilihan pemain (1 / 10 / max), bukan
                -- ditebak. "1" penting untuk mode rata: LevelUp10 melompatkan
                -- satu karakter 10 level sekaligus dan merusak perataan.
                local mau = tostring(Config.FeedJumlah or "1")
                local TIPE = { ["1"] = "LevelUp", ["10"] = "LevelUp10", max = "MaxLevelUp" }
                local tipeMau = TIPE[mau] or "LevelUp"
                local pilih, murah
                for _, p in ipairs(pn:GetChildren()) do
                    if p:IsA("ProximityPrompt") and p:GetAttribute("ServerEnabled") == true then
                        local tipe = p:GetAttribute("PromptType")
                        local naik = (tipe == "LevelUp10") and 10
                            or ((tipe == "LevelUp") and 1)
                            or ((tipe == "MaxLevelUp") and 1 or nil)
                        if tipe ~= tipeMau then naik = nil end
                        if naik then
                            local h = bacaHarga(p.ActionText)
                            if h then
                                local perLevel = h / naik
                                if not murah or perLevel < murah then
                                    pilih, murah = { prompt = p, harga = h, naik = naik }, perLevel
                                end
                            end
                        end
                    end
                end
                if pilih then
                    local kar = perStand[tostring(pilih.prompt:GetAttribute("StandId"))]
                    if kar then
                        hasil[#hasil + 1] = {
                            node = node, prompt = pilih.prompt, kar = kar,
                            harga = pilih.harga, naik = pilih.naik, perLevel = murah,
                            level = tonumber(kar:GetAttribute("Level")) or 0,
                            cps = tonumber(kar:GetAttribute("CPS")) or 0,
                            rarity = URUT_RARITY[tostring(kar:GetAttribute("Rarity"))] or 0,
                        }
                    end
                end
            end
        end
    end
    sapu(plot)
    sapu(plot:FindFirstChild("Purchases"))
    return hasil
end

local function feedUrut(daftar, mode)
    if mode == "level" then
        table.sort(daftar, function(a, b) return a.level > b.level end)
    elseif mode == "cps" then
        table.sort(daftar, function(a, b) return a.cps > b.cps end)
    elseif mode == "rarity" then
        table.sort(daftar, function(a, b)
            if a.rarity ~= b.rarity then return a.rarity > b.rarity end
            return a.cps > b.cps
        end)
    elseif mode == "rata200" then
        -- Yang sudah lewat batas dibuang dulu, sisanya diratakan dari bawah.
        local sisa = {}
        local batas = tonumber(Config.FeedBatas) or 200
        for _, x in ipairs(daftar) do
            if x.level < batas then sisa[#sisa + 1] = x end
        end
        table.sort(sisa, function(a, b) return a.level < b.level end)
        return sisa
    else
        table.sort(daftar, function(a, b) return a.level < b.level end)
    end
    return daftar
end

local function feedSesi()
    local hrp = PemainLokal.Character and PemainLokal.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local mode = tostring(Config.FeedMode)
    local daftar = feedUrut(feedDaftar(mode), mode)
    if #daftar == 0 then
        Feed.status = "tidak ada yang bisa dinaikkan"
        return
    end

    local sisaMin = tonumber(Config.FeedSisaFood) or 0
    local food = tonumber(PemainLokal:GetAttribute("FoodNumber")) or 0

    -- TABUNGAN. Di bawah ambang ini sesi tidak dimulai sama sekali -- bukan
    -- "coba dulu lalu gagal", tapi memang menunggu. Diperiksa sebelum apa pun
    -- yang lain supaya karakter tidak meninggalkan kolam tanpa hasil.
    local mulaiDari = tonumber(Config.FeedMulaiDari) or 0
    if mulaiDari > 0 and food < mulaiDari then
        Feed.status = string.format("menabung %s / %s", angkaRingkas(food), angkaRingkas(mulaiDari))
        return
    end

    -- MENABUNG. Jatah sekali sesi dibatasi sepersekian dari food yang dipegang,
    -- BUKAN per tekan. Dengan begitu simpanan tetap tumbuh: produksi menambah
    -- terus sementara tiap sesi hanya boleh mengambil sebagian kecil.
    --
    -- Kalau yang termurah pun sudah lebih mahal dari jatah, sesi ini SENGAJA
    -- tidak melakukan apa-apa dan menunggu food terkumpul. Itu perilaku yang
    -- diminta: jangan feed terus-terusan.
    local jatah = (tonumber(Config.FeedMaksPecahan) or 0.05) * food
    local termurah
    for _, x in ipairs(daftar) do
        if (food - x.harga) >= sisaMin and (not termurah or x.harga < termurah) then
            termurah = x.harga
        end
    end
    if not termurah then
        Feed.status = string.format("food kurang (%s)", angkaRingkas(food))
        return
    end
    if termurah > jatah then
        Feed.status = string.format("menabung: termurah %s > jatah %s",
            angkaRingkas(termurah), angkaRingkas(jatah))
        return
    end

    local kolamAsal = S.pondName or Kolam.pilihan
    local asal = hrp.CFrame
    local naik, dicoba, dilewati, belanja = 0, 0, 0, 0

    for i = 1, math.min(tonumber(Config.FeedPerSesi) or 5, #daftar) do
        local x = daftar[i]
        food = tonumber(PemainLokal:GetAttribute("FoodNumber")) or 0

        -- KOREKSI terukur 2026-08-28: `ServerEnabled` TETAP true walau food
        -- tidak cukup. Terbukti di akun dengan food 85 juta -- stand seharga
        -- 92,1 juta dan 223,6 juta tetap ServerEnabled=true dan tetap gagal
        -- ditekan, sementara yang 12,8 juta berhasil. Jadi keterjangkauan HARUS
        -- dihitung sendiri. Inilah sebab "kadang ga ngefeed": mode urut menaruh
        -- stand mahal di depan, semua tekanan gagal diam-diam, dan sesi
        -- berakhir tanpa satu pun kenaikan.
        local mampu = (food - x.harga) >= sisaMin
        local muat = (belanja + x.harga) <= jatah

        if not (mampu and muat) then
            -- Dilewati, BUKAN berhenti: daftar diurut sesuai mode pemain, jadi
            -- yang mahal bisa berada di depan sementara yang murah menunggu.
            dilewati = dilewati + 1
        else
            local plat = x.node:FindFirstChild("Platform")
                or x.node:FindFirstChild("PromptPart") or x.prompt.Parent
            if plat and plat:IsA("BasePart") then
                local l0 = tonumber(x.kar:GetAttribute("Level")) or 0
                hrp.CFrame = CFrame.new(plat.Position + Vector3.new(0, 3, 0))
                -- Ditunggu supaya posisi kita sampai di SERVER. Prompt.Enabled
                -- bukan acuan: terukur ia menyala 0-217 ms sesudah teleport
                -- sementara picuannya tetap ditolak -- yang dipakai server
                -- posisi versi server, bukan versi client.
                task.wait(FEED_TIBA)
                dicoba = dicoba + 1
                -- fireproximityprompt TIDAK bekerja di prompt ini -- sudah
                -- diuji dan gagal bahkan dari 3 stud. Hanya pasangan ini jalan.
                pcall(function() x.prompt:InputHoldBegin() end)
                task.wait(FEED_TAHAN)
                pcall(function() x.prompt:InputHoldEnd() end)
                task.wait(FEED_PASCA)
                -- Kenaikan diambil dari SELISIH LEVEL sungguhan, bukan dari
                -- taksiran per tipe prompt: "max" tidak mengumumkan berapa
                -- level yang didapat, jadi menaksirnya pasti salah.
                local l1 = tonumber(x.kar:GetAttribute("Level")) or 0
                if l1 ~= l0 then
                    naik = naik + (l1 - l0)
                    belanja = belanja + x.harga
                end
            end
        end
    end

    hrp.CFrame = asal
    Feed.naik = Feed.naik + naik
    Feed.sesi = Feed.sesi + 1
    Feed.food = Feed.food + belanja
    Feed.status = string.format("+%d level, %d tekan, %s%s", naik, dicoba,
        angkaRingkas(belanja), dilewati > 0 and (", " .. dilewati .. " dilewati") or "")

    -- Tanpa syarat: karakter baru saja meninggalkan kolam.
    pastikanMancing(kolamAsal)
end

-- =========================================================================
-- AUTO SPOT -- pergi ke kolam terbaik lalu mulai mancing
--
-- Penilaiannya memakai Kolam.nilai() yang sudah ada: ia membandingkan
-- karakter-per-detik memakai kekuatan rod yang BENAR-BENAR dimiliki, jadi
-- kolam yang RequiredStrength-nya belum terpenuhi tidak pernah terpilih.
--
-- Yang dituju penanda TPPONDAREA*, bukan kolamnya sendiri -- mendarat di
-- tengah air membuat karakter berenang dan lemparannya ditolak.
-- =========================================================================
local Spot = { status = "siap", pindah = 0 }

-- Benar kalau sudah sekian detik tidak ada satu pun tangkapan masuk.
--
-- KENAPA PERLU: uji pertama menemukan AutoFishActive=true tapi NOL tangkapan
-- dalam 65 detik. Auto spot lama hanya bertindak kalau kolam terbaik BERBEDA
-- dari kolam sekarang, jadi saat pancingan mati di tempat ia diam saja dan
-- panen berhenti tanpa satu pun tanda.
local function mancingMacet(batas)
    if not S.tPanen then return true end
    return (os.clock() - S.tPanen) > (batas or 20)
end

local function spotSesi()
    local nama = Kolam.pilihan
    if not nama then Spot.status = "belum ada saran" return end

    if nama == S.pondName then
        if mancingMacet(20) then
            -- Kolamnya sudah benar, yang mati pancingannya. Nyalakan ulang di
            -- tempat, TANPA memindahkan karakter -- gerakan yang tidak perlu
            -- justru membatalkan pancingan yang baru saja dipasang.
            if pastikanMancing(nama) then
                Spot.status = "nyalakan ulang di " .. nama
                catat("auto spot: mancing macet, dinyalakan ulang di %s", nama)
            end
        else
            Spot.status = "sudah di " .. nama
        end
        return
    end

    local pijakan = partKolam(nama, true)
    if not pijakan then
        -- Kolam event sering tidak punya penanda TP. Lebih baik diam daripada
        -- menebak koordinat lalu menjatuhkan pemain ke tempat asing.
        Spot.status = nama .. ": tanpa penanda TP"
        return
    end

    local hrp = PemainLokal.Character and PemainLokal.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pijakan.Position + Vector3.new(0, 4, 0))
    -- Ditunggu sebentar: menembak sebelum posisi kita sampai di server membuat
    -- lemparan pertama ditolak, dan penjaga gagal-beruntun ikut terpicu.
    task.wait(1.2)
    if pastikanMancing(nama) then
        Spot.pindah = Spot.pindah + 1
        Spot.status = "pindah ke " .. nama
        catat("auto spot: pindah ke %s", nama)
    else
        Spot.status = "gagal mulai di " .. nama
    end
end

task.spawn(function()
    while S.hidup do
        task.wait(tonumber(Config.FeedJeda) or 90)
        if Config.AutoFeed then
            pakaiGerak("feed", feedSesi)
            if Gui.ada then pcall(Gui.catFeed) end
        end
    end
end)

task.spawn(function()
    while S.hidup do
        task.wait(tonumber(Config.SpotJeda) or 60)
        if Config.AutoSpot then
            pakaiGerak("spot", spotSesi)
            if Gui.ada then pcall(Gui.catSpot) end
        elseif Config.AutoFeed and mancingMacet(25) and S.pondName then
            -- Jaring pengaman saat AUTO SPOT mati tapi AUTO FEED menyala:
            -- feed tetap memindahkan karakter, jadi pancingan tetap bisa mati.
            -- Sengaja TIDAK jalan kalau kedua fitur mati -- pemain yang memang
            -- sedang tidak mancing tidak boleh dipaksa mancing.
            pakaiGerak("jaga", function() pastikanMancing(S.pondName) end)
        end
    end
end)

task.spawn(jagaKolam)
task.spawn(jagaKlaim)
task.spawn(jagaGem)
task.spawn(pasangWebhook)
task.spawn(jagaLayar)

-- Mulai sendiri, jangan menunggu dipancing dari luar.
--
-- Dulu script diam sampai ada event Started -- padahal Started baru datang
-- kalau ADA yang menembak lebih dulu. Kalau pemain menjalankan script tanpa
-- sempat memancing manual sekali, script tidak pernah mulai sama sekali, dan
-- panel cuma menulis "menunggu siklus pertama" selamanya.
task.spawn(function()
    for _ = 1, 20 do
        if not S.hidup then return end
        if S.pond and S.target then return end   -- sudah jalan dari sumber lain
        if Config.Aktif and deteksiKolam() then
            if Gui.ada then pcall(Gui.catPond) end
            tembak()
            return
        end
        task.wait(1.5)
    end
    catat("tidak menemukan kolam dalam 30 detik -- berdirilah di dekat kolam")
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
        charPerMenit = (jalan > 0) and (S.karakter / jalan * 60) or 0,
        tangkapPerMenit = (S.siklus > 1 and jalan > 0) and (60 / (jalan / (S.siklus - 1))) or 0,
        karakter    = S.karakter,
        pond        = S.pondName,
        pondPilihan = Kolam.pilihan,
        pondAlasan  = Kolam.alasan,
        kekuatanRod = Kolam.kekuatan,
        webhook     = (Config.Webhook ~= "") and { terkirim = Webhook.terkirim,
                        gagal = Webhook.gagal, dilewati = Webhook.dilewati,
                        pesanGalat = Webhook.pesanGalat ~= "" and Webhook.pesanGalat or nil } or false,
        gem         = Config.AutoGem and { dipungut = Gem.dipungut, gagal = Gem.gagal,
                                              adaSekarang = Gem.terakhirAda } or false,
        klaim       = Config.AutoKlaim and {
            playtime = Klaim.playtime, quest = Klaim.quest,
            harian = Klaim.harian, galat = Klaim.galat,
            pesanGalat = Klaim.pesanGalat ~= "" and Klaim.pesanGalat or nil,
        } or false,
        saranKolam  = Config.SaranKolam,
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
-- Saklar dari luar, supaya layar bisa dikendalikan tanpa mengklik panel
-- (berguna saat menjalankan banyak klien).
getgenv().MozeFishLayar = function(nyala)
    if nyala == nil then nyala = not Config.LayarHitam end
    Config.LayarHitam = nyala and true or false
    pcall(Layar.tampil, Config.LayarHitam)
    if Gui.ada then pcall(Gui.catLayar) end
    pcall(tulisSimpanan)
    return Config.LayarHitam
end

getgenv().MozeFishStop = function()
    S.hidup = false
    Config.Aktif = false
    for _, c in ipairs(S.conn) do pcall(function() c:Disconnect() end) end
    S.conn = {}
    if Gui.sg then pcall(function() Gui.sg:Destroy() end) end
    Gui.ada = false
    -- Layar ikut dibersihkan: meninggalkannya berarti layar hitam menempel
    -- selamanya sesudah script dilepas, dan itu persis perilaku kaitun utama
    -- yang justru ingin dihindari di sini.
    pcall(function() if Layar.sg then Layar.sg:Destroy() end end)
    Layar.ada, Layar.terlihat = false, false
    for _, c in ipairs(Layar.conn) do pcall(function() c:Disconnect() end) end
    getgenv().MozeFishLayar = nil
    getgenv().MozeFishStop = nil
    getgenv().MozeFishInfo = nil
    catat("dilepas. %d siklus, %d tembakan, %d diterima.", S.siklus, S.tembak, S.diterima)
end

catat("aktif. Menunggu event `Started` pertama untuk membaca pond & posisi.")
catat("berhenti: getgenv().MozeFishStop()")

-- @MOZEFRAME-EOF@ (penanda akhir berkas -- router menolak file tanpa baris ini)
