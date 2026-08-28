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
end

simpanConfig = function()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(BERKAS, HttpService:JSONEncode({ Aktif = Config.Aktif, Pilih = Pilih }))
    end)
end

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
bingkai.Size = UDim2.fromOffset(290, 424)
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
bAktif.Size = UDim2.fromOffset(262, 28)
bAktif.Position = UDim2.fromOffset(14, 44)
bAktif.Font = Enum.Font.GothamBold
bAktif.TextSize = 12
bAktif.BorderSizePixel = 0
bAktif.Parent = bingkai
sudut(bAktif, 8)

local cari = Instance.new("TextBox")
cari.Size = UDim2.fromOffset(262, 26)
cari.Position = UDim2.fromOffset(14, 78)
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
gulir.Position = UDim2.fromOffset(12, 112)
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

local function sapuBeli()
    if not Config.Aktif then return end
    local kini = os.clock()
    -- Data dibaca SEKALI per frame, bukan sekali per item: dengan 21 toko,
    -- memanggil GetData ratusan kali tiap frame itu pemborosan yang terasa.
    local semua = bacaStok()
    for _, toko in ipairs(TOKO) do
        local s = semua[toko]
        local stoks = s and s.Stocks
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
                        pcall(function() Remote:FireServer(x.nama, toko) end)
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

print(("[GAG] panel siap. %d toko, setelan %s. Anti-AFK aktif."):format(#TOKO,
    adaSimpanan and "dimuat dari berkas" or "bawaan"))
