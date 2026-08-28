--[[
=============================================================================
  MOZEFRAME — LOADER TUNGGAL
  Tanpa server proteksi sendiri. Whitelist diurus Luaegis (whitelist Discord).
=============================================================================

RANTAINYA SEKARANG DUA LANGKAH, BUKAN EMPAT

    dulu :  loader -> router -> games.lua -> script
    kini :  loader (Aegis) ------------------> script

Router dan games.lua DILIPAT ke sini. Keduanya kecil -- router 98 baris,
games.lua cuma 36 baris kode dari 137 (83% isinya komentar) -- dan memisahnya
berarti dua pengambilan HTTP tambahan tiap execute, masing-masing satu titik
gagal.

APA YANG DIBUANG DARI LOADER LAMA, DAN KENAPA

    HWID + gethwid()          -> Luaegis yang mengenali device
    /verify_login             -> Luaegis yang memutuskan siapa boleh jalan
    UI lock + input key       -> Luaegis punya jalurnya sendiri
    webhook Discord           -> tidak ada lagi yang perlu dilaporkan
    MuzeKey.txt / MuzeKeyOK   -> tidak ada key untuk disimpan
    masa tenggang 6 jam       -> tidak ada server proteksi yang bisa mati

Berkas ini tidak bisa mengunci siapa pun, dan itu memang tujuannya. Proteksi
ada satu lapis di luar: Luaegis membungkusnya.

YANG HILANG KARENA MELIPAT -- SEBUTKAN TERUS TERANG

Router lama menulis tujuannya sendiri: "menambah dunia baru cukup satu baris
di daftar, tanpa obfus ulang dan tanpa loader kedua." Melipat daftar ke sini
MEMBATALKAN sifat itu. Sekarang menambah dunia = sunting berkas ini + unggah
ulang ke Luaegis.

Itu harga yang dibayar untuk melindungi riset di komentar games.lua (peran tiap
place, PlaceId karantina bot, struktur world PS99) dan memangkas dua fetch.
Kalau nanti dunia sering bertambah dan harga itu terasa mahal, kembalikan
DAFTAR_URL: ambil tabelnya dari luar lagi, tanpa mengembalikan router.

CATATAN YANG BELUM SELESAI -- JANGAN DIANGGAP BERES

Loader ini sudah lepas dari mozeframe.my.id. Script kaitun-nya BELUM:
kaitun_main.txt masih memanggil /verify_login, sync config, dan /api/mail/log.
Selama VPS masih hidup itu tidak terasa. Begitu dimatikan, panggilan-panggilan
itu gagal -- dan gejalanya bukan pesan jelas, melainkan fitur yang diam saja.

Mematikan VPS bukan satu langkah. Berkas ini langkah pertama.

TIGA ATURAN YANG TIDAK BOLEH DILANGGAR DI SINI

1. NETRAL TERHADAP GAME. Jangan pernah menyentuh objek khas satu dunia di scope
   atas. Loader lama sempat punya `WaitForChild("SharedModules")` di baris awal
   -- itu hanya ada di GaG2/Fall Harvest, jadi di PS99 loader menggantung
   SELAMANYA sebelum sempat berbuat apa pun. Gejalanya cuma "Infinite yield
   possible", terbaca seperti masalah key.

2. SELALU CACHE-BUST. raw.githubusercontent menahan salinan lama sampai ~5
   menit. Tanpa parameter acak, log error menunjuk baris yang di sumbernya
   sudah benar.

3. WAJIB CEK PENANDA @MOZEFRAME-EOF@. Kejadian nyata: gamingexperienc3.lua
   ter-upload hanya 74.392 dari 95.731 byte dan terputus di tengah kata. Yang
   muncul cuma "malformed string" di baris 1722 -- terbaca seperti bug kode,
   padahal kodenya benar dan uploadnya yang gagal.
]]

-- =========================================================================
-- JANGAN JALAN DUA KALI
--
-- Executor gampang dieksekusi ulang, dan tiap kaitun memasang loop-nya sendiri.
-- Dua salinan berarti dua loop menembak remote yang sama -- di GaG2 itu berarti
-- dua jalur jual berebut inventory, kelas bug yang paling lama dikejar di
-- proyek ini.
if getgenv().MozeframeLoaderJalan then
    warn("[MOZE] Loader sudah berjalan di sesi ini. Eksekusi kedua dilewati.")
    return
end
getgenv().MozeframeLoaderJalan = true

local function beritahu(judul, isi)
    warn("[MOZE] " .. judul .. " -- " .. isi)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = judul, Text = isi, Duration = 10,
        })
    end)
end

local function batal(pesan)
    getgenv().MozeframeLoaderJalan = nil   -- boleh dicoba lagi tanpa rejoin
    beritahu("Loader berhenti", pesan)
end

-- =========================================================================
-- SUMBER SCRIPT  <-- SATU-SATUNYA BAGIAN YANG PERLU DIISI
--
-- Isi akun dan repo di sini, lalu berkas ini siap dibungkus Luaegis.
local AKUN   = "framemozejiu"
local REPO   = "frame"
local CABANG = "main"

-- KENAPA raw.githubusercontent, BUKAN LAGI /api/script
--
-- VPS-nya dimatikan, jadi endpoint itu ikut mati. Loader yang masih menunjuk
-- ke sana tidak gagal sebagian -- ia gagal total di setiap dunia.
--
-- YANG IKUT HILANG, DAN INI HARUS DISADARI:
--
--   1. SOURCE TIDAK LAGI TERSEMBUNYI. URL-nya memang terkubur di dalam bungkus
--      Luaegis, tapi bisa dibaca saat jalan lewat hook HttpGet beberapa baris.
--      Anggap source ini publik, karena memang publik.
--
--   2. GERBANG TINGKATAN PS99 LENYAP. Dulu /api/script hanya menyerahkan
--      f=ps99 kepada PS99_KEY khusus, dan membalas 403 ke panel key biasa.
--      GitHub tidak mengenal siapa pun. Kalau PS99 masih dijual terpisah,
--      buat loader Luaegis KEDUA khusus PS99 dengan whitelist sendiri, lalu
--      keluarkan baris PS99 dari daftar di bawah.
--
-- Yang TIDAK hilang: siapa yang boleh menjalankan loader sama sekali. Itu
-- tetap dipegang Luaegis.
local RAW = "https://raw.githubusercontent.com/" .. AKUN .. "/" .. REPO .. "/" .. CABANG .. "/"

-- Nama berkas meneruskan pola yang sudah dipakai (gamingexperienc2/3) ke 4 dan
-- 5. Sengaja netral: nama berkas ikut terbaca kalau repo-nya ditemukan orang.
local GAG2 = RAW .. "gamingexperienc2.lua"   -- Grow a Garden 2
local FALL = RAW .. "gamingexperienc3.lua"   -- Fall Harvest
local PS99 = RAW .. "gamingexperienc4.lua"   -- Pet Simulator 99
local SAE  = RAW .. "gamingexperienc5.lua"   -- Steal An Egg
local FAAR = RAW .. "gamingexperienc6.lua"   -- Fish an Anime RNG
local GAG1 = RAW .. "gamingexperienc7.lua"   -- Grow a Garden 1

-- =========================================================================
-- DAFTAR DUNIA
--
-- KUNCINYA PlaceId, BUKAN GameId. GaG2 dan Fall Harvest berbagi universeId yang
-- sama, jadi game.GameId identik untuk keduanya dan tidak bisa membedakan apa
-- pun.
--
-- SATU DUNIA PUNYA BANYAK PLACE. Game mengarahkan pemain ke place berbeda
-- menurut keadaan akun -- termasuk place KARANTINA BOT. Script harus jalan di
-- mana pun akun mendarat, jadi semuanya dipetakan.
--
-- Rincian peran tiap place, daftar place yang sengaja TIDAK dipetakan beserta
-- alasannya, dan cara mengambil ulang daftarnya: lihat games.lua di repo lokal.
-- Sengaja tidak disalin ke sini -- itu hasil riset, dan berkas ini beredar.
local Games = {
    -- Grow a Garden 2
    [97598239454123]  = GAG2,
    [73504898027860]  = GAG2,
    [77085202503540]  = GAG2,
    [133438856880402] = GAG2,

    -- Fall Harvest
    [126987765280963] = FALL,
    [129343810645058] = FALL,

    -- Pet Simulator 99
    [8737899170]      = PS99,
    [16498369169]     = PS99,
    [17503543197]     = PS99,
    [140403681187145] = PS99,
    [130404940988186] = PS99,

    -- Steal An Egg
    [107778070777162] = SAE,

    -- Fish an Anime RNG
    -- Universe 9582986239 cuma punya SATU place (dicek lewat
    -- develop.roblox.com/v1/universes/9582986239/places) -- tidak ada place
    -- karantina maupun varian sesi pertama seperti GaG2. Kalau nanti muncul,
    -- tambahkan barisnya di sini.
    [74729868188364]  = FAAR,

    -- Grow a Garden 1
    -- Universe 7436755782. Baru SATU place yang dikonfirmasi (dibaca langsung
    -- dari game.PlaceId di sesi hidup, bukan disalin dari daftar). GaG2 punya
    -- empat place, jadi kemungkinan besar yang ini juga -- tambahkan barisnya
    -- di sini begitu ketemu, jangan menebak nomornya.
    [126884695634066] = GAG1,
}

-- Dicek sebelum menyentuh jaringan. Tanpa ini, isian yang belum diganti tetap
-- berakhir sebagai 404 -- tapi baru sesudah 3 percobaan dan ~6 detik, dengan
-- pesan "balasan pendek" yang menuduh hosting padahal salahnya di dua baris atas.
if string.find(RAW, "GANTI%-") then
    return batal("AKUN/REPO di loader belum diisi -- masih 'GANTI-...'")
end

local URL = Games[game.PlaceId]
if not URL then
    -- Sengaja diberi pesan, bukan diam. Kalau Roblox menambah place baru,
    -- gejalanya jadi jelas alih-alih script yang diam saja.
    return batal("PlaceId " .. tostring(game.PlaceId) .. " belum terdaftar")
end

-- =========================================================================
-- AMBIL SCRIPT
--
-- `request` native didahulukan: selain lebih tahan anti-cheat, ia juga memberi
-- body apa adanya. game:HttpGet dipakai sebagai cadangan untuk executor yang
-- tidak menyediakannya.
--
-- Dicoba beberapa kali: gangguan sesaat lebih sering daripada script yang
-- benar-benar hilang. Menyerah di percobaan pertama membuat pemakai mengira
-- key-nya bermasalah.
local PERCOBAAN = 3

local function ambil(url)
    local galatTerakhir = "tidak diketahui"
    for percobaan = 1, PERCOBAAN do
        local pemisah = string.find(url, "?", 1, true) and "&" or "?"
        local target = url .. pemisah .. "r=" .. tostring(os.time()) .. tostring(percobaan)

        local ok, isi = pcall(function()
            local req = (type(request) == "function" and request)
                or (type(http_request) == "function" and http_request)
                or (syn and syn.request) or (fluxus and fluxus.request)
            if req then
                local res = req({ Url = target, Method = "GET" })
                return res and res.Body or nil
            end
            return game:HttpGet(target, true)
        end)

        if ok and type(isi) == "string" and #isi > 0 then
            -- Balasan pendek hampir pasti bukan script: 403 berupa komentar Lua,
            -- halaman error proxy, atau body kosong. Menjalankannya menghasilkan
            -- galat yang menyesatkan.
            if #isi < 200 then
                -- Isinya dikutip apa adanya, bukan ditebak. GitHub membalas
                -- persis "404: Not Found" (14 byte) untuk repo/berkas yang tidak
                -- ada -- menyebutnya "403 / halaman error" mengirim orang
                -- memeriksa hal yang salah.
                galatTerakhir = "balasan cuma " .. #isi .. " byte: "
                    .. string.gsub(string.sub(isi, 1, 60), "%s+", " ")
            else
                return isi
            end
        else
            galatTerakhir = tostring(isi)
        end

        if percobaan < PERCOBAAN then task.wait(percobaan * 2) end
    end
    return nil, galatTerakhir
end

local sumber, galat = ambil(URL)
if not sumber then
    return batal("Gagal mengambil script: " .. tostring(galat))
end

-- Penjaga berkas terpotong. Lihat aturan 3 di kepala berkas.
if not string.find(sumber, "@MOZEFRAME" .. "-EOF@", 1, true) then
    return batal("Script terpotong saat diambil (penanda akhir tidak ada). "
        .. "Diterima " .. #sumber .. " byte -- coba lagi sebentar.")
end

-- =========================================================================
-- COMPILE, LALU JALANKAN
--
-- Dipisah supaya galat SINTAKS tidak tertukar dengan galat SAAT JALAN. Yang
-- satu berarti source di hosting rusak, yang lain berarti bug di script.
local muat = getgenv().loadstring or loadstring
if type(muat) ~= "function" then
    return batal("Executor tidak didukung: loadstring tidak tersedia")
end

local fungsi, galatCompile = muat(sumber)
if not fungsi then
    return batal("Script gagal compile: " .. tostring(galatCompile))
end

local ok, galatJalan = pcall(fungsi)
if not ok then
    -- Penanda TIDAK dilepas di sini, dan itu disengaja: script sudah terlanjur
    -- berjalan sebagian dan mungkin sudah memasang loop. Mengizinkan eksekusi
    -- kedua berarti menumpuk di atas keadaan setengah jadi.
    beritahu("Script berhenti dengan galat", tostring(galatJalan))
end

-- Tidak ada penanda @MOZEFRAME-EOF@ di berkas ini: penanda itu dicek terhadap
-- script kaitun yang DIMUAT. Berkas ini yang memuatnya, jadi tidak pernah
-- melewati pemeriksaan itu sendiri.
