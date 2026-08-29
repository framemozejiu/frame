
-- Penanda build. Tanpa ini kita tidak pernah tahu versi mana yang benar-benar
-- jalan, dan tiap diagnosis berpijak pada tebakan.
_G.SaeBuild = "2026-08-23h | bersih: akselerasi+gerbang+langkah+noclip"
print("[SAE] " .. _G.SaeBuild)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
if not game:IsLoaded() then
    game.Loaded:Wait()
end
local LP = Players.LocalPlayer
if not LP then
    local mulai = os.clock()
    repeat
        task.wait(0.1)
        LP = Players.LocalPlayer
    until LP or os.clock() - mulai > 30
end
if not LP then
    warn("[SAE] LocalPlayer tidak muncul — panel tidak dibuka")
    return
end
LP:WaitForChild("PlayerGui", 30)
local T = {
    base    = Color3.fromRGB(6, 9, 20),
    layer1  = Color3.fromRGB(17, 23, 39),
    layer2  = Color3.fromRGB(27, 35, 54),
    layer3  = Color3.fromRGB(38, 48, 70),
    stroke  = Color3.fromRGB(255, 255, 255),
    textHi  = Color3.fromRGB(248, 250, 252),
    textMid = Color3.fromRGB(170, 182, 200),
    textLo  = Color3.fromRGB(120, 132, 152),
    ember   = Color3.fromRGB(185, 28, 28),
    emberHi = Color3.fromRGB(244, 63, 94),
    gold    = Color3.fromRGB(232, 180, 74),
    cyan    = Color3.fromRGB(6, 182, 212),
    ok      = Color3.fromRGB(16, 185, 129),
    warn    = Color3.fromRGB(234, 179, 8),
}
local EASE  = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_S = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local S = {
    MinRarity = 6,
    MaksEgg = 0,
    MinBeratKg = 0,
    AntiAfk = false,
    KunciKamera = false,
    ModeGerak = "tween",
    FlightSpeed = 100,  -- tidak dipakai langsung; gerak = 9 stud/frame cap
    -- Tinggi jelajah saat pulang (stud di atas tanah).
    --
    -- 25 diukur, bukan dikira-kira: hitbox PlayerTrap (2,9 x 1,6 x 2,8) berhenti
    -- 1,6 stud di atas tanah, jadi 25 sudah jauh lebih dari cukup, dan makin
    -- rendah makin singkat waktu menanjak/menurun.
    --
    -- Soal batas atas: melayang diam di +8/+25/+40/+50/+60/+65/+73 diuji dan
    -- SELAMAT semua. Satu kali di +73 karakter mati dalam 0,8 detik, tapi dua
    -- pengulangan sesudahnya tidak menghasilkan kematian -- jadi sebabnya BELUM
    -- diketahui dan tidak boleh disebut sebagai batas ketinggian.
    ReturnHeight = 25,
    ReaksiInstan = true,
    Kekebalan = true,
    -- KebalMati MATI. Triknya sudah tidak berlaku: diukur 2026-08-22 di
    -- PlaceVersion 379, `Dead` dinyalakan balik ~26 ms sesudah nyawa jadi 0
    -- dan tidak bisa ditahan (263x dilawan tiap frame, tetap kalah). Dengan
    -- nyawa dinolkan, `pasangKebal` justru membuat bot bunuh diri tiap spawn.
    KebalMati = false,
    AntiTrap = true,
    -- Rampok: kalau target kita keburu disambar pemain lain, kejar dan pukul
    -- dengan bat supaya egg-nya jatuh, lalu ambil.
    --
    -- Default MATI. Ini satu-satunya fitur yang menyerang pemain lain secara
    -- langsung, jadi dinyalakan harus keputusan sadar pemakainya.
    Rampok = false,
    RampokBatasDetik = 12,
    MatikanTreadmill = true,
    MatikanGuard = true,
    MatikanAntiCheat = true,
    MatikanGuard = true,
    MatikanAntiCheat = true,
    SerbuMalam = true,
    AntiDorong = true,
    PakaiSpeedBoost = true,
    PakaiGerbangKabur = false,
    BankKeBase = false,
    SemburanCarry = 5,
    -- Satu angka untuk kecepatan jelajah DAN kecepatan bawa-egg.
    Speed = 250,
    GerakDiStepped = true,
    Akselerasi = 600,
    KecGerbang = 120,
    LebarGerbang = 30,
    LangkahMaks = 12,
    Noclip = true,
    BatasDiSarang = 0.55,   -- detik; guard bangun ~0,6 dtk
    -- Jeda diam sebelum permintaan sambar dikirim, supaya posisi kita sempat
    -- sampai ke server. Nol = matikan.
    JedaSambar = 0.15,
    AutoHatch = false,
    AutoTanam = false,
    TanamSekali = 5,
    AutoHop = false,
    HopSepiDetik = 30,
    -- Cari server sesepi mungkin, lalu berhenti begitu jumlah pemain di server
    -- (termasuk kita) <= SendirianMaks.
    --
    -- Private server TIDAK bisa dipakai di game ini: dicek 2026-08-21 lewat API
    -- Roblox, `createVipServersAllowed = false`. Jadi satu-satunya jalan untuk
    -- sepi adalah memilih server publik yang kosong -- dan itu masuk akal di
    -- sini karena `maxPlayers` cuma 7.
    CariServerSepi = false,
    SendirianMaks = 1,
    Berjalan = false,
    AutoJualPet = false,
    JualPetFilter = "rarity",
    JualPetMaksRarity = 2,
    JualPetMinPerSecond = 1e6,
    AutoFuse = false,
    FuseMaksRarity = 2,
    FuseLewatiMutasi = true,
    FuseSekali = 3,
    AutoEquipBest = false,
    EquipBestTiapDetik = 60,
    BoostFps = false,
    EspEgg = false,
    EspRarity = { ["6"] = true, ["7"] = true, ["8"] = true, ["9"] = true, ["10"] = true },
    AreaDilarang = {},
}
local BERKAS = "mozeframe_sae_config.json"
local HttpService = game:GetService("HttpService")
local function muatTersimpan()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end
    local ok, isi = pcall(function()
        return isfile(BERKAS) and readfile(BERKAS) or nil
    end)
    if not ok or type(isi) ~= "string" then
        return nil
    end
    local ok2, tabel = pcall(function()
        return HttpService:JSONDecode(isi)
    end)
    return (ok2 and type(tabel) == "table") and tabel or nil
end
do
    local tersimpan = muatTersimpan()
    if tersimpan then
        for k, v in pairs(tersimpan) do
            if S[k] ~= nil then
                S[k] = v
            end
        end
    end
    local g = getgenv().SAEConfig
    if type(g) == "table" then
        for k, v in pairs(g) do
            S[k] = v
        end
    end
    -- Nilai tersimpan menimpa default, jadi mengganti default saja tidak
    -- menolong pemain lama. Angka 70 yang tersimpan itu default warisan yang
    -- TIDAK PERNAH benar-benar dipakai -- sampai build ini jalur pulang memang
    -- tidak pernah terbang -- jadi menurunkannya bukan membuang pilihan pemain.
    if tonumber(S.ReturnHeight) and tonumber(S.ReturnHeight) > 60 then
        S.ReturnHeight = 25
    end

    -- `KebalMati` DIPAKSA mati, bukan cuma default-nya diubah. Device yang
    -- pernah menyimpannya `true` akan terus memakainya walau default sudah
    -- `false` -- dan akibatnya `pasangKebal` menolkan nyawa tiap spawn, jadi
    -- bot bunuh diri berulang. Triknya sendiri sudah tidak berlaku sejak
    -- PlaceVersion 379 (`Dead` dinyalakan balik ~26 ms sesudah nyawa 0, 263x
    -- dilawan tiap frame tetap kalah), jadi tidak ada pilihan yang dibuang.
    S.KebalMati = false

    -- Speed TIDAK diclamp lagi. Clamp 250 sempat dipasang untuk menyelamatkan
    -- device yang menyimpan 884, tapi ia jalan paling akhir sehingga memblokir
    -- setelan apa pun di atas 250 -- termasuk pengujian. Dan patokan 250 itu
    -- sendiri sudah goyah: BigFroot terukur bertahan 1.000+ stud/dtk selama
    -- 3,5 detik tanpa mati (lihat memory sae-bigfroot-terukur). Default untuk
    -- device baru tetap 250; yang lama silakan disetel sadar lewat GUI.

end
getgenv().SAEConfig = S
local simpanTertunda = false
local function simpanConfig()
    if simpanTertunda or type(writefile) ~= "function" then
        return
    end
    simpanTertunda = true
    task.delay(0.5, function()
        simpanTertunda = false
        pcall(function()
            writefile(BERKAS, HttpService:JSONEncode(S))
        end)
    end)
end
local RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary",
                 "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local function keAngka(teks)
    if type(teks) ~= "string" then
        return nil
    end
    local bersih = teks:gsub("%s+", ""):gsub(",", "."):lower()
    bersih = bersih:gsub("kg$", "")
    local angka, satuan = bersih:match("^([%d%.]+)([kmbt]?)$")
    angka = tonumber(angka)
    if not angka then
        return nil
    end
    local kali = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12 })[satuan] or 1
    return angka * kali
end
local function keTeks(n)
    n = tonumber(n) or 0
    for _, u in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        if n >= u[1] then
            return (string.format("%.1f", n / u[1]):gsub("%.0$", "")) .. u[2]
        end
    end
    return tostring(math.floor(n))
end
local function new(kelas, induk, props)
    local o = Instance.new(kelas)
    for k, v in pairs(props or {}) do
        o[k] = v
    end
    o.Parent = induk
    return o
end
local function radius(o, r)
    new("UICorner", o, { CornerRadius = UDim.new(0, r) })
end
local function stroke(o, transparansi, warna)
    return new("UIStroke", o, {
        Color = warna or T.stroke,
        Thickness = 1,
        Transparency = transparansi,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end
local function pad(o, atas, sisi)
    new("UIPadding", o, {
        PaddingTop = UDim.new(0, atas),
        PaddingBottom = UDim.new(0, atas),
        PaddingLeft = UDim.new(0, sisi),
        PaddingRight = UDim.new(0, sisi),
    })
end
local function tween(o, info, props)
    TweenService:Create(o, info, props):Play()
end
-- ==========================================
-- PROTEKSI  (Anti Guard + Anti Trap)
-- ==========================================
-- Ditaruh DI PANEL, bukan di dalam SUMBER_STEAL.
--
-- Sebelumnya semuanya hidup di dalam string SUMBER_STEAL, yang baru
-- di-loadstring saat tombol Mulai ditekan. Akibatnya siapa pun yang mencuri
-- MANUAL -- pemakaian paling wajar untuk fitur ini -- menyalakan saklar Anti
-- Guard yang tidak menyalakan apa pun. Terekam 2026-08-21: guard mendekat
-- 22 -> 2 stud tanpa pernah beku, lalu Humanoid jadi Physics dan karakter
-- terlempar 70 stud dalam 0,6 detik.
--
-- Semua dibungkus `do ... end` supaya tidak menambah local di scope berkas;
-- chunk ini sudah memuat 219 local, mepet ke batas 200-per-fungsi Luau.
do
    local RunService = game:GetService("RunService")
    local RS = game:GetService("ReplicatedStorage")

    _G.SaeProteksi = "dimuat"
    _G.SaeProteksiPanel = true

    local function akarKu()
        local ch = LP.Character
        return ch and ch:FindFirstChild("HumanoidRootPart")
    end

    ---------------------------------------------------------------- guard
    -- PEMBEKUAN GUARD DIBUANG.
    --
    -- Memarkir klon guard hanya menghentikan guard versi CLIENT. Server punya
    -- guard sendiri, dan itulah yang benar-benar memukul: terukur `Health
    -- -1000/1000000000` -- damage 1000 pada nyawa yang sebenarnya 100. Guard
    -- lokal boleh beku semua (dan memang terukur `BEKU` di kesembilan area)
    -- sementara pemain tetap dipukul dan mati.
    --
    -- Jadi loop ini membayar mahal -- menulis Anchored dan CFrame sembilan
    -- guard TIAP FRAME -- untuk sesuatu yang tidak mencegah apa pun.
    --
    -- Yang dijalankan sekarang cuma satu kali: MELEPAS anchor kalau sesi
    -- sebelumnya sempat membekukannya, supaya guard tidak tertinggal beku.
    task.spawn(function()
        task.wait(2)
        local ok, ga = pcall(function()
            return workspace.__OBJECTS.Areas.GuardAreas
        end)
        if not ok or not ga then return end
        for _, area in ipairs(ga:GetChildren()) do
            local g = area:FindFirstChild("Guard")
            local r = g and g:FindFirstChild("HumanoidRootPart")
            if r and r.Anchored then
                pcall(function() r.Anchored = false end)
                _G.SaeGuardDilepas = (_G.SaeGuardDilepas or 0) + 1
            end
        end
    end)

    ---------------------------------------------------------------- anti ragdoll
    -- ANTI RAGDOLL + JANGKAR POSISI. Diuji langsung di client dan berhasil.
    --
    -- Duduk perkaranya, setelah semua yang lain gugur:
    --
    -- 1. Guard dijalankan SERVER. Sudah dicoba membekukan modelnya, menghapus
    --    `PlayerScripts.Game.GuardAreas`, bahkan menghapus model guard-nya
    --    sampai lenyap -- pukulan tetap datang. Guard masih bergeser 19 stud
    --    per sampel walau seluruh script guard di client dibuang.
    -- 2. Menghindarinya mustahil: dari 45 sarang di server, KESEMUANYA berjarak
    --    9-23 stud dari guard. Guard memang ditempatkan di sarang.
    -- 3. Pukulannya TIDAK memberi damage. Nyawa tetap 100/100 di seluruh
    --    rekaman, nol penurunan hp. Yang dilakukannya cuma dua: me-ragdoll dan
    --    merebut egg. Jadi "Kekebalan" bernyawa 1e9 tidak pernah relevan --
    --    dan memang tidak pernah bekerja, karena server melihat nyawa 100
    --    (terbukti lewat `Health -1000/1000000000`).
    --
    -- Karena ragdoll DITERAPKAN DI CLIENT (Library.Modules.Ragdoll ->
    -- ApplyClientRagdoll), ia bisa dibatalkan di client juga, memakai
    -- `ClearClientRagdoll` milik game sendiri. Tanpa hook apa pun.
    --
    -- Lapisan kedua -- jangkar posisi -- yang membuatnya benar-benar mulus.
    -- Membatalkan ragdoll saja masih menyisakan dorongan, karena impulsnya
    -- terlanjur diterapkan sebelum pembatalan sempat berjalan. Jadi posisi saat
    -- pukulan mendarat DICATAT sekali, lalu selama 0,45 detik kecepatan
    -- dinolkan dan tiap pergeseran di atas 2 stud dikembalikan ke titik itu.
    local ModulRagdoll = nil
    do
        local ok, m = pcall(function()
            return require(RS.Library.Modules.Ragdoll)
        end)
        if ok and type(m) == "table" and type(m.ClearClientRagdoll) == "function" then
            ModulRagdoll = m
        end
    end
    _G.SaeRagdollModul = ModulRagdoll ~= nil

    do
        local RSv = game:GetService("RunService")
        local sampai = 0      -- akhir jendela penahanan
        local jangkar = nil   -- posisi tepat sebelum terdorong

        RSv.Heartbeat:Connect(function()
            if S.Kekebalan == false or _G.SaeMatikanAntiMental then return end
            local ch = LP.Character
            if not ch then return end
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp
                or (hum.Health <= 0 and not _G.SaeKebalAktif) then return end

            local st = hum:GetState()
            local kena = hum.PlatformStand
                or st == Enum.HumanoidStateType.Physics
                or st == Enum.HumanoidStateType.Ragdoll
                or st == Enum.HumanoidStateType.FallingDown
            if not kena then
                for _, x in ipairs(ch:GetDescendants()) do
                    if (x:IsA("BallSocketConstraint") or x:IsA("HingeConstraint"))
                        and x:GetAttribute("RagdollConstraint") then
                        kena = true
                        break
                    end
                end
            end

            if kena then
                -- Jangkar dipasang SEKALI di awal jendela, bukan tiap frame --
                -- kalau diperbarui terus, ia ikut hanyut bersama dorongannya.
                if os.clock() > sampai then jangkar = hrp.Position end
                sampai = os.clock() + 0.45
                if ModulRagdoll then
                    pcall(ModulRagdoll.ClearClientRagdoll, ch)
                end
                pcall(function()
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    -- ClearClientRagdoll menyalakan CanCollide; dimatikan lagi
                    -- SEKARANG, jangan menunggu loop noclip di Stepped.
                    hrp.CanCollide = false
                end)
                _G.SaeRagdollDibatalkan = (_G.SaeRagdollDibatalkan or 0) + 1
            end

            -- JANGAN menjangkar kalau guard-nya masih dekat.
            --
            -- Jangkar menahan kita di tempat 0,45 detik supaya tidak terlempar
            -- -- bagus kalau pukulannya nyasar, TAPI kalau guard berdiri di
            -- sebelah kita, penguncian itu justru menahan kita DI DALAM
            -- jangkauannya sampai ia memukul lagi. Itulah lingkaran
            -- "dipukul, ambil egg, jalan sedikit, dipukul lagi".
            --
            -- Jarak pukulnya 10 stud; di bawah 25 stud kita masih dalam bahaya,
            -- jadi ragdoll tetap dibatalkan tapi kita DIBIARKAN BERGERAK PERGI.
            local guardDekat = false
            do
                local okG, folder = pcall(function()
                    return workspace.__OBJECTS.Areas.GuardAreas
                end)
                if okG and folder then
                    for _, ar in ipairs(folder:GetChildren()) do
                        local gm = ar:FindFirstChild("Guard")
                        local gr = gm and gm:FindFirstChild("HumanoidRootPart")
                        if gr then
                            local dx = gr.Position.X - hrp.Position.X
                            local dz = gr.Position.Z - hrp.Position.Z
                            if (dx * dx + dz * dz) < (25 * 25) then
                                guardDekat = true
                                break
                            end
                        end
                    end
                end
            end

            -- SATU PEMILIK POSISI PADA SATU WAKTU.
            --
            -- Jangkar ini menahan posisi 0,45 detik sesudah dipukul. Kalau mesin
            -- luncur sedang berjalan, keduanya menulis CFrame di frame yang sama
            -- dan saling tarik -- di 250 stud/dtk selisihnya beberapa stud dan
            -- tak terasa, di 600+ jadi puluhan stud dan terbaca sebagai
            -- rubberband. Inilah yang membedakan kita dari script pembanding:
            -- ia tidak punya rutin tambahan yang ikut menulis posisi.
            if _G.SaeSedangTerbang then
                -- Sedang meluncur: cukup batalkan ragdoll, JANGAN sentuh posisi.
            elseif os.clock() < sampai and jangkar and not guardDekat then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                if (hrp.Position - jangkar).Magnitude > 2 then
                    hrp.CFrame = CFrame.new(jangkar)
                        * (hrp.CFrame - hrp.CFrame.Position)
                    _G.SaeDorongDitahan = (_G.SaeDorongDitahan or 0) + 1
                end
            elseif guardDekat then
                _G.SaeJangkarDilewati = (_G.SaeJangkarDilewati or 0) + 1
            end
        end)
    end

    ---------------------------------------------------------------- anti-cheat
    -- Buang pendeteksi kecepatan.
    --
    -- Terekam 2026-08-26, tiga kematian beruntun:
    --   -1.000.000.000 hp | guard 47 stud  | laju 1198
    --   -1.000.000.000 hp | guard 125 stud | laju 1341
    --   -1.000.000.000 hp | guard 81 stud  | laju  751
    -- Nyawa turun SATU MILIAR sekaligus -- dari MaxHealth 1e9 langsung ke nol.
    -- Itu bukan pukulan guard (yang tercatat 1000 damage), dan guard terdekat
    -- 47-125 stud, jauh di luar jangkauan pukul 10 stud. Yang tersisa: ada yang
    -- membunuh karena kita bergerak terlalu cepat.
    --
    -- Pelakunya `PlayerScripts.Game.Runtime_XXXXXXXX` -- LocalScript bernama
    -- TERACAK TIAP SESI (aslinya `RuntimePulse` di StarterPlayerScripts). Nama
    -- yang diacak itu sendiri ciri anti-cheat. Kita pernah mematikannya manual
    -- dan gerak tetap bersih, tapi script ini tidak pernah membuangnya sendiri
    -- -- jadi tiap rejoin ia hidup lagi.
    --
    -- Dicari lewat POLA nama, bukan nama tetap, justru karena diacak.
    task.spawn(function()
        while true do
            if S.MatikanAntiCheat ~= false then
                pcall(function()
                    local ps = LP:FindFirstChild("PlayerScripts")
                    local gm = ps and ps:FindFirstChild("Game")
                    if not gm then return end
                    for _, c in ipairs(gm:GetChildren()) do
                        if string.match(c.Name, "^Runtime_") then
                            if c:IsA("LocalScript") then c.Enabled = false end
                            c:Destroy()
                            _G.SaeAntiCheatDibuang = (_G.SaeAntiCheatDibuang or 0) + 1
                        end
                    end
                end)
            end
            task.wait(1)
        end
    end)

    ---------------------------------------------------------------- treadmill
    -- Treadmill: dimatikan TERUS-MENERUS selama saklarnya menyala.
    --
    -- Dulu ini dijalankan sekali saja saat script dimuat, dan itu tidak cukup:
    -- script treadmill bisa dimuat SESUDAH kita, plot baru bisa muncul
    -- belakangan, dan sesudah rejoin semuanya kembali. Akibatnya pemain masih
    -- tersangkut walau fiturnya "menyala".
    --
    -- Yang menahan itu LOGIKANYA, bukan part-nya: mematikan CanTouch pada part
    -- bernama treadmill tidak pernah menolong -- di seluruh workspace cuma ada
    -- 3 part seperti itu dan ketiganya sudah mati sementara pemain tetap
    -- terjerat. Yang menyelesaikan adalah membuang tiga LocalScript-nya di
    -- PlayerScripts.Game.Plots.
    --
    -- Tetangganya JANGAN disentuh: ActiveAssetsController menggambar pet di plot
    -- dan PlotSignManager mengurus papan nama.
    task.spawn(function()
        while true do
            task.wait(1)
            if S.MatikanTreadmill ~= false then
                _G.SaeTreadmillDetak = (_G.SaeTreadmillDetak or 0) + 1
                pcall(function()
                    local ps = LP:FindFirstChild("PlayerScripts")
                    local gm = ps and ps:FindFirstChild("Game")
                    local plots = gm and gm:FindFirstChild("Plots")
                    if plots then
                        for _, x in ipairs(plots:GetChildren()) do
                            if string.find(string.lower(x.Name), "treadmill", 1, true) then
                                if x:IsA("LocalScript") then x.Enabled = false end
                                x:Destroy()
                                _G.SaeTreadmillScriptDibuang =
                                    (_G.SaeTreadmillScriptDibuang or 0) + 1
                            end
                        end
                    end
                    local wp = workspace:FindFirstChild("Plots")
                    if wp then
                        for _, x in ipairs(wp:GetDescendants()) do
                            if x:IsA("BasePart") and (x.CanTouch or x.CanCollide)
                                and string.find(string.lower(x:GetFullName()),
                                    "treadmill", 1, true) then
                                x.CanTouch = false
                                x.CanCollide = false
                            end
                        end
                    end
                end)
            end
        end
    end)

    ---------------------------------------------------------------- dinding reset
    -- Penembus dinding reset, untuk Serbu Malam.
    --
    -- Dinding itu milik client: `AreaEggResetWall` hanya menyetel
    -- `WallStartCollision.CanCollide`, jadi mematikannya secara lokal sudah
    -- cukup untuk lewat. (Pengusiran dari arena saat malam TETAP terjadi dan
    -- ditegakkan server -- itu perkara terpisah yang sudah terbukti tidak bisa
    -- ditembus dari client.)
    task.spawn(function()
        while true do
            task.wait(0.25)
            if S.SerbuMalam ~= false then
                _G.SaeDindingDetak = (_G.SaeDindingDetak or 0) + 1
                pcall(function()
                    local A = workspace:FindFirstChild("__OBJECTS")
                    A = A and A:FindFirstChild("Areas")
                    local w = A and A:FindFirstChild("WallStartCollision")
                    if not w then return end
                    if w:IsA("BasePart") then w.CanCollide = false end
                    for _, x in ipairs(w:GetDescendants()) do
                        if x:IsA("BasePart") and x.CanCollide then
                            x.CanCollide = false
                        end
                    end
                end)
            end
        end
    end)

    ---------------------------------------------------------------- kebal mati
    -- KEKEBALAN MATI. `Dead` dimatikan, nyawa dibiarkan 0.
    --
    -- Terukur 2026-08-22 di akun sendiri, rute dan kode gerak identik:
    -- 7 dari 7 percobaan MATI tanpa ini, 0 dari 3 dengan ini -- termasuk
    -- 600 stud/dtk menembus jauh ke dalam `GuardAreas.<Area>.Bounds`, tempat
    -- yang membunuh kita tujuh kali beruntun.
    --
    -- Bahan aktifnya `Dead` YANG DIMATIKAN, bukan nyawa 0. Pembunuhnya
    -- MENOLKAN nyawa berapa pun besarnya: diuji dengan MaxHealth/Health 1e9
    -- dan `Dead` hidup, damage-nya tercatat -1000000000 dan tetap mati 3 dari
    -- 3. Jadi menaikkan nyawa -- yang selama ini dilakukan `Kekebalan` --
    -- tidak pernah bisa menolong.
    --
    -- Nyawa SENGAJA tidak pernah ditulis ulang. Varian yang memulihkannya
    -- tiap frame berakhir dengan kick `ERR INT @27`, dan script pembanding
    -- pun membiarkan nyawanya 0. Yang dijaga cuma flag `Dead`-nya.
    --
    -- Urutan pemasangan wajib: matikan `Dead` DULU, baru nolkan nyawa.
    -- Dibalik, karakternya mati beneran.
    local function pasangKebal(ch)
        if S.KebalMati == false then return end
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)
        task.wait(0.1)
        pcall(function()
            if hum.Health > 0 then hum.Health = 0 end
        end)
        _G.SaeKebalAktif = true
        _G.SaeKebalPasang = (_G.SaeKebalPasang or 0) + 1
    end

    LP.CharacterAdded:Connect(function(ch)
        -- Respawn mengembalikan `Dead` ke hidup, jadi harus dipasang lagi tiap
        -- karakter baru -- bukan sekali saat script dimuat.
        ch:WaitForChild("Humanoid", 10)
        task.wait(0.5)
        pasangKebal(ch)
    end)
    if LP.Character then
        task.spawn(function() pasangKebal(LP.Character) end)
    end

    task.spawn(function()
        local sudahPulih = false
        while true do
            task.wait(1)
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if S.KebalMati == false then
                if _G.SaeKebalAktif and hum and not sudahPulih then
                    -- Dikembalikan sekali saja, bukan tiap detik.
                    sudahPulih = true
                    pcall(function()
                        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                        hum.MaxHealth = 100
                        hum.Health = 100
                    end)
                end
                _G.SaeKebalAktif = false
            elseif hum then
                sudahPulih = false
                _G.SaeKebalDetak = (_G.SaeKebalDetak or 0) + 1
                if hum:GetStateEnabled(Enum.HumanoidStateType.Dead) then
                    pcall(function()
                        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                    end)
                    _G.SaeKebalDipasangUlang = (_G.SaeKebalDipasangUlang or 0) + 1
                end
                _G.SaeKebalAktif = true
            end
        end
    end)

    ---------------------------------------------------------------- trap
    -- PlayerTrap hanya memicu kalau penyentuh bukan pemiliknya, berada di sisi
    -- arena, DAN sedang memegang egg. Pemicunya sentuhan, dan sentuhan part
    -- milik client dilaporkan OLEH client kita -- jadi CanTouch lokal cukup.
    local trapAsli = {}
    local function aturTrap()
        local wadah = workspace:FindFirstChild("__DEBRIS")
        if not wadah then return end
        for _, trap in ipairs(wadah:GetChildren()) do
            if trap.Name == "PlayerTrap" then
                local bagian = {}
                if trap:IsA("BasePart") then bagian[#bagian + 1] = trap end
                for _, c in ipairs(trap:GetDescendants()) do
                    if c:IsA("BasePart") then bagian[#bagian + 1] = c end
                end
                for _, part in ipairs(bagian) do
                    if trapAsli[part] == nil then
                        trapAsli[part] = { part.CanTouch, part.CanCollide }
                    end
                    pcall(function()
                        part.CanTouch = false
                        part.CanCollide = false
                    end)
                end
            end
        end
    end

    task.spawn(function()
        local wadah = workspace:WaitForChild("__DEBRIS", 30)
        if wadah then
            -- Trap yang baru dipasang harus tertangkap seketika: pemain bisa
            -- menaruhnya tepat di depan kita.
            wadah.ChildAdded:Connect(function(x)
                if x.Name == "PlayerTrap" and S.AntiTrap ~= false then
                    task.spawn(function()
                        x:WaitForChild("Hitbox", 5)
                        pcall(aturTrap)
                    end)
                end
            end)
        end
        while true do
            task.wait(0.25)
            if S.AntiTrap ~= false and not _G.SaeMatikanAntiTrap then
                _G.SaeTrapDetak = (_G.SaeTrapDetak or 0) + 1
                pcall(aturTrap)
            else
                for part, asal in pairs(trapAsli) do
                    if part.Parent then
                        pcall(function()
                            part.CanTouch = asal[1]
                            part.CanCollide = asal[2]
                        end)
                    end
                end
                trapAsli = {}
            end
        end
    end)

    _G.SaeProteksi = "jalan"
end

local SUMBER_STEAL = [==[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
if not game:IsLoaded() then
    game.Loaded:Wait()
end
local function tungguAnak(induk, nama, batas)
    local ada = induk:FindFirstChild(nama)
    if ada then
        return ada
    end
    return induk:WaitForChild(nama, batas or 60)
end
do
    local perlu = {
        { RS, "Library" },
        { RS, "Directory" },
        { workspace, "__OBJECTS" },
    }
    for _, p in ipairs(perlu) do
        if not tungguAnak(p[1], p[2]) then
            warn("[EGG] " .. p[2] .. " tidak muncul setelah 60 detik — script berhenti")
            return
        end
    end
end
local Config = {
    MinRarity = 6,
    MinBeratKg = 0,
    AntiAfk = false,
    KunciKamera = false,
    AmbilJatuh = true,
    LupakanGagalDetik = 20,
    MaksEgg = 0,
    JedaAntarEgg = 1.5,
    -- Berapa lama menunggu egg benar-benar masuk inventory sebelum menyerah
    -- dan memakai jeda penuh.
    BatasTungguSimpan = 6,
    -- Jeda setelah egg TERBUKTI tersimpan. Kecil saja; yang menahan kita
    -- seharusnya kepastian, bukan angka.
    JedaSetelahSimpan = 0.1,
    BatasVerifikasi = 4,
    BatasJalan = 12,
    ModeGerak = "tween",
    ReaksiInstan = true,
    Kekebalan = true,
    AntiTrap = true,
    -- MATI. Fitur ini menulis WalkSpeed, padahal game punya loop sendiri yang
    -- menimpanya balik -- terukur: diset 197, 1,5 detik kemudian 208,14 lagi.
    -- Lebih buruk lagi, saat dimatikan ia mengembalikan `speedDasar` yang sudah
    -- BASI, sehingga tiap siklus menurunkan speed pemain dan game mendorongnya
    -- naik lagi. Tarik-menarik itu yang terasa sebagai rubberband.
    PakaiSpeedBoost = false,
    MarginSpeed = 0.92,
    -- Kecepatan terbang = WalkSpeed SAAT ITU dikali angka ini.
    --
    -- JANGAN dipatok angka tetap. Terukur 2026-08-21: WalkSpeed di SAE tumbuh
    -- sendiri (208,1 -> 219,0 dalam hitungan menit). Nilai tetap 300 berarti
    -- 1,38x di akun yang sudah cepat, tapi 6x di akun WalkSpeed 50 dan 10x di
    -- akun WalkSpeed 30 -- di situlah rubberband paling ganas.
    --
    -- Ambang 1,40x yang sempat terukur "ditarik balik" (29% bertahan) diambil
    -- SAMBIL memalsukan AssemblyLinearVelocity. Sesudah pemalsuan itu dibuang,
    -- angka tersebut tidak lagi berlaku -- script pembanding berjalan mulus di
    -- ~300 stud/dtk terus-menerus. Hasilnya dibatasi 120..300: 300 karena itu
    -- yang terbukti aman di lapangan, 120 supaya akun ber-WalkSpeed kecil tidak
    -- ikut ditembak ke kecepatan yang tidak masuk akal buat dirinya.
    KaliKecepatanTerbang = 1.4,
    -- Meluncur (CFrame) untuk SEMUA perpindahan. Setel false hanya kalau
    -- benar-benar ingin karakter berjalan kaki memakai MoveTo.
    SelaluMeluncur = true,
    MarginAman = 10,
    AreaDilarang = {},
    -- NYALA. Terukur 2026-08-21: empat kematian beruntun terjadi 36-81 stud
    -- dari guard, dengan nyawa jatuh 100 -> 0 dalam SATU langkah dan tercatat
    -- -1000/100 (kerusakan berlebih = bunuh seketika, bukan luka bertahap).
    -- Guard punya keadaan Sleeping / Waking / Chasing; saat pengukuran
    -- Prehistoric sedang "Chasing" dan Snow "Waking", dan justru ke area
    -- itulah script terbang lalu mati sebelum sempat menyambar sekali pun
    -- (jejak carry KOSONG sama sekali).
    HindariGuardBangun = true,
    PakaiGerbangKabur = false,
    MarginKabur = 1.15,
    -- MATI, dan memang tidak diperlukan: egg tersimpan begitu kita menyeberang
    -- ke zona aman. Menyalakannya hanya menambah perjalanan ke CenterPoint plot,
    -- yang tidak menambah apa pun selain waktu.
    BankKeBase = false,
    BatasLariBalik = 40,
    -- MATI. Dinding reset itu MILIK CLIENT -- lihat catatan SerbuMalam.
    -- Menghormatinya berarti berdiri menunggu di luar tepat pada 10 detik yang
    -- paling berharga, lalu masuk bersamaan dengan semua orang.
    HormatiDinding = false,
    RuntuhkanDinding = true,
    SerbuMalam = true,
    BatasTungguPrompt = 6,
    SemburanCarry = 5,
    -- Satu angka untuk kecepatan jelajah DAN kecepatan bawa-egg.
    Speed = 250,
    GerakDiStepped = true,
    Akselerasi = 600,
    KecGerbang = 120,
    LebarGerbang = 30,
    LangkahMaks = 12,
    Noclip = true,
    BatasDiSarang = 0.55,   -- detik; guard bangun ~0,6 dtk
    -- Jeda diam sebelum permintaan sambar dikirim, supaya posisi kita sempat
    -- sampai ke server. Nol = matikan.
    JedaSambar = 0.15,
    -- MATI (0). Sempat diisi 25 dengan maksud menghindari sarang dekat guard.
    -- Terukur 2026-08-22 dan langsung batal: dari 45 sarang di server, KESEMBILAN
    -- BELAS -- tepatnya semuanya, 45 dari 45 -- berjarak 9 sampai 23 stud dari
    -- guard. Guard memang ditempatkan DI sarang; tidak ada sarang aman. Mengisi
    -- angka di sini > 9 berarti script berhenti mencuri sama sekali.
    JarakMinGuard = 0,
    JedaSemburan = 0.02,
    TahanTeleport = 0.8,
    WaktuDiArena = 0.35,
    JedaMasukArena = 0.6,
    LewatGerbangMasuk = true,
    TahanGerbang = 0.5,
    TahanKabur = nil,
    AutoHatch = false,
    AutoTanam = false,
    TanamSekali = 5,
    HatchRadiusAwal = 10,
    HatchJarakCincin = 5,
    HatchCincin = 4,
    HatchJarakAntar = 6,
    HatchJedaBuka = 0.6,      -- jeda RequestHatchEgg -> RequestCompleteHatchEgg
    HatchJedaAntar = 0.4,
    HatchJedaTanam = 0.6,     -- setelah sampai taman, sebelum menanam
    HatchJedaPutaran = 10,
    AutoHop = false,
    HopSepiDetik = 30,
    -- Cari server sesepi mungkin, lalu berhenti begitu jumlah pemain di server
    -- (termasuk kita) <= SendirianMaks.
    --
    -- Private server TIDAK bisa dipakai di game ini: dicek 2026-08-21 lewat API
    -- Roblox, `createVipServersAllowed = false`. Jadi satu-satunya jalan untuk
    -- sepi adalah memilih server publik yang kosong -- dan itu masuk akal di
    -- sini karena `maxPlayers` cuma 7.
    CariServerSepi = false,
    SendirianMaks = 1,
    HopMaksPercobaan = 5,
    HopTungguPindah = 6,
    AutoJualPet = false,
    JualPetFilter = "rarity",
    JualPetMaksRarity = 2,
    JualPetMinPerSecond = 1e6,
    JualPetSekali = 25,
    JualPetJedaPutaran = 0.1,
    JualPetJedaSepi = 5,
    AutoFuse = false,
    FuseMaksRarity = 2,
    FuseLewatiMutasi = true,
    FuseSekali = 3,
    FuseJedaMasuk = 0.15,
    FuseJedaReveal = 0.8,
    AutoEquipBest = false,
    EquipBestTiapDetik = 60,
    EspEgg = false,
    EspRarity = { [6] = true, [7] = true, [8] = true, [9] = true, [10] = true },
    EspSegarTiap = 1,
    BoostFps = false,
    BoostFpsSapuTiap = 5,
    KaburKeTanah = false,
    GerbangKeTanah = false,
    BatasMenjejak = 0.3,
    BatasSeberang = 4,
    PercobaanPicu = 4,
    PaksaEnable = true,
    Log = true,
}
do
    local g = getgenv().SAEConfig
    if type(g) == "table" then
        for k, v in pairs(g) do
            if Config[k] ~= nil or k == "AreaDilarang" then
                Config[k] = v
            end
        end
    end
end
local Player = Players.LocalPlayer
local speedDasar = nil
local sedangBoost = false
local sanggupKabur
local resetSyarat
local exitPoint
local sisiAman
local guardBangun
local function log(...)
    if Config.Log then
        print("[EGG]", ...)
    end
end
local EggCmds = require(RS.Library.Client.EggCmds)
local Assets = require(RS.Directory.Assets)
local Guards = require(RS.Directory.Guards)
local PlotCmds = require(RS.Library.Client.PlotCmds)
local GEP = require(RS.Library.Modules.GuardAreas.GuardEscapePrediction)
local ResetWall = nil
pcall(function()
    ResetWall = require(RS.Library.Client.AreaEggResetWall)
end)
local GCP = require(RS.Library.Modules.GuardAreas.GuardChasePolicy)
local EggUtil = select(2, pcall(require, RS.Library.Util.EggItemUtil))
local ResetUtil = select(2, pcall(require, RS.Library.Util.AreaEggResetTimeUtil))
local function nilaiRarity(kategori)
    local cfg = Assets.Directory[kategori]
    if not cfg or not cfg.Rarity then
        return 0, "?"
    end
    return cfg.Rarity.RarityNumber or 0, cfg.Rarity._id or "?"
end
-- Berat dalam KG, memakai perhitungan game sendiri kalau tersedia.
--
-- Sebelumnya filter memakai `ModelWeight * AssetScale` sementara riwayat di
-- panel menampilkan `EggItemUtil.GetWeightKg`. Keduanya BEDA, kadang lebih dari
-- dua kali lipat -- terukur 2026-08-21: Galaxy Gecko 26,9 vs 59,9 kg; Chillin
-- Chilli 43,6 vs 92,2 kg. Akibatnya angka yang diketik pemain di "Berat
-- minimum" tidak berarti sama dengan angka kg yang ia lihat sendiri di riwayat.
-- ModelWeight * AssetScale dipertahankan hanya sebagai cadangan.
local function beratEgg(rec)
    if type(EggUtil) == "table" and EggUtil.GetWeightKg then
        local ok, kg = pcall(EggUtil.GetWeightKg, rec)
        if ok and type(kg) == "number" and kg > 0 then
            return kg
        end
    end
    local cfg = Assets.Directory[rec.AssetCategory]
    if not cfg or not cfg.ModelWeight then
        return 0
    end
    return cfg.ModelWeight * (rec.AssetScale or 1)
end
local RIWAYAT_MAKS = 20
local function catatRiwayat(rec)
    local d = Assets.Directory[rec.AssetCategory]
    local e = d and d.Egg
    local r = _G.__SAEriwayat
    if type(r) ~= "table" then
        r = {}
        _G.__SAEriwayat = r
    end
    -- Satu sumber angka saja: beratEgg sudah memakai GetWeightKg.
    local berat = beratEgg(rec)
    local angka, nama = nilaiRarity(rec.AssetCategory)
    table.insert(r, 1, {
        nama  = (e and e.DisplayName) or tostring(rec.AssetCategory),
        berat = berat,
        ikon  = e and e.Icon and tostring(e.Icon):match("(%d+)") or nil,
        rarity = angka,
        rarity_nama = nama,
        waktu = os.time(),
    })
    while #r > RIWAYAT_MAKS do
        table.remove(r)
    end
end
local function jumlahMutasi(rec)
    local n = 0
    if type(rec.Mutations) == "table" then
        for _ in pairs(rec.Mutations) do
            n = n + 1
        end
    end
    return n
end
local function cacahPerolehan()
    local ok, rt = pcall(EggCmds.GetRuntimeSnapshot)
    if not ok or type(rt) ~= "table" then
        return -1
    end
    for _, entri in pairs(rt) do
        if type(entri) == "table" and entri.OwnerUserId == Player.UserId then
            local n = 0
            for _ in pairs(entri.Records or {}) do
                n = n + 1
            end
            return n
        end
    end
    return 0
end
local function dindingTertutup()
    if not ResetWall then
        return nil
    end
    local ok, tertutup = pcall(ResetWall.IsClosed)
    if not ok then
        return nil
    end
    return tertutup == true
end
-- CATATAN: tidak ada fungsi "melepas egg" di sini, dan itu disengaja.
--
-- Menyeberang ke zona aman sudah menyimpan egg ke kantong, dan sesudah itu egg
-- memang tidak bisa dijatuhkan. Jadi `RequestDropHeldAreaEgg` tidak punya
-- kegunaan sama sekali selain membuang hasil sambaran di lapangan -- persis yang
-- sempat terjadi. Jangan dipasang lagi.

-- Egg yang sedang dibawa BUKAN Tool.
--
-- Terukur 2026-08-22: karakter sama sekali tidak punya Tool saat membawa egg.
-- Yang benar, egg itu muncul di GetAreaEggSnapshot sebagai record berstatus
-- "Carried" dengan field CarrierUserId. Deteksi lama (mencari Tool bernama
-- "egg") SELALU mengembalikan nil, sehingga pelepasan egg tidak pernah
-- dijalankan -- egg terus tergenggam sampai guard memukul.
-- Jarak sarang ke guard TERDEKAT (XZ saja, seperti aturan pukul game).
--
-- Terekam 2026-08-22 pada momen pukulan: guard berdiri 8 stud dari kita dengan
-- geser 0,0 -- ia TIDAK mengejar, kitalah yang terbang tepat ke pangkuannya,
-- karena sarang sasaran memang berada di dalam radius pukul 10 stud miliknya.
--
-- Guard digerakkan SERVER (terbukti: masih bergeser 19 dan 13 stud per sampel
-- walau `PlayerScripts.Game.GuardAreas` sudah dibuang), jadi ia tidak bisa
-- dimatikan dari client sama sekali. Yang bisa kita atur cuma satu: JANGAN
-- memilih sarang yang berada di dekatnya.
local function jarakKeGuard(posisi)
    local ok, folder = pcall(function()
        return workspace.__OBJECTS.Areas.GuardAreas
    end)
    if not ok or not folder then return math.huge end
    local dekat = math.huge
    for _, area in ipairs(folder:GetChildren()) do
        local m = area:FindFirstChild("Guard")
        local r = m and m:FindFirstChild("HumanoidRootPart")
        if r then
            local j = Vector3.new(r.Position.X - posisi.X, 0, r.Position.Z - posisi.Z).Magnitude
            if j < dekat then dekat = j end
        end
    end
    return dekat
end

-- Kabar bawa-egg dari sinyal game sendiri, bukan dari polling snapshot.
--
-- `EggCmds.AreaEggCarryStateChanged` membawa `IsCarrying` dan berdetak persis
-- pada perpindahan egg ke inventory -- kejadian yang sama dengan notif
-- "You stole an EGG". Ditemukan lewat GuardTutorialController.MilestoneAdapter,
-- yang menyimpannya sebagai `_areaEggCarryState` lalu membacanya di
-- `IsCarryingAreaEgg`. Membacanya gratis, jadi penantian bisa serapat frame
-- tanpa menarik snapshot berulang -- `GetAreaEggSnapshot` tidak gratis.
--
-- Detaknya ikut dihitung. Itu yang membuat nilai BASI tidak bisa menipu:
-- `false` dari putaran sebelumnya tidak boleh dibaca sebagai "sudah tersimpan"
-- untuk egg yang baru saja disambar.
local bawaLive = nil
pcall(function()
    EggCmds.AreaEggCarryStateChanged:Connect(function(st)
        bawaLive = (type(st) == "table" and st.IsCarrying) and true or false
        _G.SaeBawaLive = bawaLive
        _G.SaeBawaLiveDetak = (_G.SaeBawaLiveDetak or 0) + 1
    end)
end)

local function eggDipegang()
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return nil
    end
    for _, rec in pairs(snap.Records) do
        if rec.State == "Carried" and rec.CarrierUserId == Player.UserId then
            return tostring(rec.AssetCategory or "egg")
        end
    end
    return nil
end
local function akar()
    local ch = Player.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function cariEggTerbaik(dilewati)
    local hrp = akar()
    if not hrp then
        return nil
    end
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return nil
    end
    resetSyarat()
    local terbaik, skorTerbaik
    -- Sebab kandidat berkelas tinggi tidak jadi dipilih.
    --
    -- Pemilih ini SUDAH mengurut rarity paling atas (`skor = { angka, jatuh,
    -- berat, -jarak }` dibandingkan leksikografis), jadi kalau Secret (8) kalah
    -- oleh Cosmic (7), Secret-nya pasti tersaring SEBELUM sempat dinilai --
    -- bukan kalah skor. Tanpa catatan ini kita cuma bisa menebak saringan mana
    -- yang membuangnya, dan menaikkan bobot rarity tidak akan mengubah apa pun.
    local lewatSebab = {}
    for _, rec in pairs(snap.Records) do
        local eggTutorial = type(rec.Uid) == "string" and rec.Uid:find("^FirstAreaEgg") ~= nil
        local bisaDiambil = rec.State == "Slot"
            or (Config.AmbilJatuh and rec.State == "Dropped")
        local ditunda = dilewati[rec.Uid]
        if ditunda and os.clock() >= ditunda then
            dilewati[rec.Uid] = nil
            ditunda = nil
        end
        -- Egg yang JATUH tidak pernah dilewati, walau uid-nya sedang ditunda.
        --
        -- Skenario yang selama ini terlewat: kita gagal menyambar sebuah egg,
        -- uid-nya masuk daftar tunda selama LupakanGagalDetik. Beberapa detik
        -- kemudian pemain lain menyambarnya lalu menjatuhkannya -- egg itu jadi
        -- rebutan bebas, tapi kita justru mengabaikannya sampai daftar tundanya
        -- kedaluwarsa, dan malah pergi mencari sasaran lain.
        -- Sarang yang terlalu dekat guard DILEWATI.
        --
        -- Ini bukan kehati-hatian berlebih: pada jarak segitu guard memukul
        -- sebelum kita sempat pergi, dan egg-nya pasti direbut kembali --
        -- terekam tiga kali berturut-turut, egg lepas setelah 1,0 sampai 1,9
        -- detik. Lebih baik kehilangan satu kandidat daripada kehilangan
        -- perjalanan penuh plus egg-nya.
        local jGuard = rec.BottomCFrame and jarakKeGuard(rec.BottomCFrame.Position)
            or math.huge
        if jGuard < (Config.JarakMinGuard or 25) then
            bisaDiambil = false
            _G.SaeSarangDilewatiGuard = (_G.SaeSarangDilewatiGuard or 0) + 1
        end

        if not eggTutorial and rec.BottomCFrame then
            local angkaCek = nilaiRarity(rec.AssetCategory)
            if angkaCek >= (Config.MinRarity or 6) then
                local sebab = nil
                if rec.State ~= "Slot"
                    and not (Config.AmbilJatuh and rec.State == "Dropped") then
                    sebab = "state " .. tostring(rec.State)
                elseif jGuard < (Config.JarakMinGuard or 25) then
                    sebab = string.format("guard %.0f stud (batas %d)",
                        jGuard, Config.JarakMinGuard or 25)
                elseif ditunda and rec.State ~= "Dropped" then
                    sebab = "sedang ditunda"
                end
                if sebab then
                    lewatSebab[#lewatSebab + 1] = { angka = angkaCek,
                        nama = tostring(rec.AssetCategory), sebab = sebab }
                end
            end
        end

        if bisaDiambil and (not ditunda or rec.State == "Dropped")
            and not eggTutorial then
            local angka = nilaiRarity(rec.AssetCategory)
            local berat = beratEgg(rec)
            local lolosRarity = angka >= Config.MinRarity
            local lolosBerat = (Config.MinBeratKg or 0) > 0 and berat >= Config.MinBeratKg
            -- Dipecah jadi dua penanda supaya sebab penolakannya bisa DISEBUT
            -- namanya, bukan sekadar "tidak lolos". Keduanya memakai cache yang
            -- sama (`resetSyarat`), jadi tidak ada tambahan biaya berarti.
            local bisaKabur = sanggupKabur(rec.AreaId,
                Player.Character and Player.Character:FindFirstChildOfClass("Humanoid"))
            -- `~= false` supaya config tersimpan yang belum punya kunci ini
            -- ikut memakai perilaku baru; mengubah default saja tidak cukup
            -- karena berkas config menimpanya.
            local guardTerjaga = Config.HindariGuardBangun ~= false
                and guardBangun(rec.AreaId)
            if not ((lolosRarity or lolosBerat) and bisaKabur and not guardTerjaga)
                and angka >= (Config.MinRarity or 6) then
                lewatSebab[#lewatSebab + 1] = { angka = angka,
                    nama = tostring(rec.AssetCategory),
                    sebab = (not bisaKabur) and "tak sanggup kabur dari area"
                        or guardTerjaga and "guard area sedang bangun"
                        or "tidak lolos rarity/berat" }
            end
            if (lolosRarity or lolosBerat) and bisaKabur and not guardTerjaga then
                local jarak = (hrp.Position - rec.BottomCFrame.Position).Magnitude
                local jatuh = rec.State == "Dropped" and 1 or 0
                local skor = { angka, jatuh, berat, -jarak }
                local menang = false
                if not skorTerbaik then
                    menang = true
                else
                    for u = 1, #skor do
                        if skor[u] ~= skorTerbaik[u] then
                            menang = skor[u] > skorTerbaik[u]
                            break
                        end
                    end
                end
                if menang then
                    terbaik, skorTerbaik = rec, skor
                end
            end
        end
    end
    -- Dilaporkan HANYA kalau ada yang berkelas lebih tinggi daripada yang
    -- terpilih -- persis keluhan "ada Secret tapi malah ambil Cosmic". Kalau
    -- tidak ada, diam saja; log ini tidak boleh jadi bising.
    if #lewatSebab > 0 then
        local angkaPilih = terbaik and nilaiRarity(terbaik.AssetCategory) or 0
        local puncak = nil
        for _, x in ipairs(lewatSebab) do
            if x.angka > angkaPilih and (not puncak or x.angka > puncak.angka) then
                puncak = x
            end
        end
        if puncak then
            _G.SaeLewatTinggi = (_G.SaeLewatTinggi or 0) + 1
            _G.SaeLewatTinggiAkhir = string.format("%s r%d > r%d — %s",
                puncak.nama, puncak.angka, angkaPilih, puncak.sebab)
            log(string.format("DILEWATI %s [rarity %d] padahal pilihan cuma [%d] — %s",
                puncak.nama, puncak.angka, angkaPilih, puncak.sebab))
        end
    end
    return terbaik
end
local function promptUntuk(rec)
    local dekat, jarakDekat = nil, 4
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
            local d = (c.Position - rec.BottomCFrame.Position).Magnitude
            if d < jarakDekat then
                local p = c:FindFirstChild("CarryAreaEgg")
                if p and p:IsA("ProximityPrompt") then
                    dekat, jarakDekat = p, d
                end
            end
        end
    end
    return dekat
end
local TOLERANSI_MENDARAT = 5
local Stats = game:GetService("Stats")
local function pingDetik()
    local ok, ms = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(ms) == "number" and ms > 0 then
        return ms / 1000
    end
    return 0.2
end
local function tahanan()
    return math.max(Config.TahanTeleport, pingDetik() * 3)
end
local function titikTanah(posisi)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Player.Character }
    local kena = workspace:Raycast(posisi + Vector3.new(0, 14, 0), Vector3.new(0, -90, 0), params)
    if not kena then
        return posisi + Vector3.new(0, 3, 0)
    end
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    local h = akar()
    return kena.Position
        + Vector3.new(0, (h and h.Size.Y / 2 or 1) + (hum and hum.HipHeight or 2) + 0.1, 0)
end
local function menjejakTanah(batas)
    local mulai = os.clock()
    while os.clock() - mulai < (batas or 0.35) do
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            return true
        end
        task.wait(0.03)
    end
    return false
end
local noclipAktif = false
local noclipKoneksi = nil
local noclipSemua = false -- true = noclip termasuk HRP (untuk fly)
-- Saklar noclip. Catatan lama menyimpulkan noclip WAJIB karena script
-- pembanding waktu itu (WisHub) punya `CanCollide=false`. Terukur 2026-08-23,
-- BigFroot -- yang melaju 825-1013 stud/dtk tanpa sekali pun kena sentakan --
-- justru memakai `CanCollide = TRUE`, dengan keempat koneksi anti-cheat HIDUP.
--
-- Dugaannya: noclip membuat kita dinilai TERBANG, bukan berlari. Kode
-- anti-cheat penuh istilah yang menyangkut itu (`GroundClearanceTolerance`,
-- `AirborneDurationTolerance`, modul `Surface`, alasan koreksi `Flight`).
-- Kalau benar, yang menghukum kita bukan detektor kecepatan sama sekali.
--
-- Default tetap NYALA supaya perilaku lama tidak berubah diam-diam.
local function mulaiNoclip(semua)
    if Config.Noclip == false then
        -- Dimatikan lewat config: pastikan tidak ada sisa koneksi yang menahan
        -- CanCollide di false, lalu kembalikan HRP supaya bertabrakan lagi.
        if noclipKoneksi then noclipKoneksi:Disconnect(); noclipKoneksi = nil end
        noclipAktif = false
        local ch = Player.Character
        local hrpN = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrpN then pcall(function() hrpN.CanCollide = true end) end
        return
    end
    if noclipAktif then
        noclipSemua = semua or false
        return
    end
    noclipAktif = true
    noclipSemua = semua or false
    noclipKoneksi = RunService.Stepped:Connect(function()
        local ch = Player.Character
        if not ch then return end
        for _, part in ipairs(ch:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipSemua or part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = false
                end
            end
        end
    end)
end
local function stopNoclip()
    noclipAktif = false
    if noclipKoneksi then
        noclipKoneksi:Disconnect()
        noclipKoneksi = nil
    end
end

-- Blok "BYPASS GUARD & ANTI-RAGDOLL" yang dulu di sini SUDAH DIGABUNG ke loop
-- Kekebalan (cari `GERAK.Kekebalan`). Isinya tumpang tindih: sama-sama
-- memaksa keadaan ragdoll kembali ke Running, dan urusan CanCollide sudah
-- ditangani mulaiNoclip(true). Dua loop yang mengerjakan hal yang sama adalah
-- sumber bug terpanjang di script ini, jadi disatukan -- dan yang gabungan
-- punya saklar di GUI, sementara yang lama selalu menyala tanpa bisa dimatikan.

task.wait(2) -- delay supaya game fully load dulu (mirip LimeHub)

-- NOCLIP HRP: NYALA TERUS, dan HRP HARUS ikut.
--
-- Komentar lama di sini berbunyi "aktifkan noclip di awal = rubberband karena
-- server expect ground collision". Itu TERBALIK dari kenyataan, dan gara-gara
-- itu `mulaiNoclip` tidak pernah dipanggil sama sekali -- fungsinya jadi kode
-- mati, dan HumanoidRootPart selalu bertabrakan.
--
-- Dibuktikan dengan membandingkan keadaan dunia sebelum/sesudah script
-- pembanding yang tidak pernah rubberband dijalankan. Dari 94 script dan
-- seluruh objek arena yang dipantau, HANYA SATU yang berbeda:
--     HRP  polos: CanCollide=true   -> saat script itu jalan: CanCollide=false
-- Tidak ada script game yang dimatikan, tidak ada objek arena yang diubah.
--
-- Sebabnya masuk akal: meluncur 300 stud/dtk dengan HRP yang masih bertabrakan
-- membuat karakter menabrak medan/tembok, fisika memantulkannya, dan server
-- mengoreksi posisi -- itulah sentakan mundur 150-252 stud sekali per detik,
-- dan ujungnya karakter mati terjepit.
--
-- `semua = true` WAJIB: part karakter lain di game ini sudah CanCollide=false
-- sejak awal, jadi noclip yang mengecualikan HRP tidak melakukan apa pun.
mulaiNoclip(true)
--[[
    Modifikasi HRP seperti LimeHub: perkecil + invisible.
    BAC tidak kick kalau HRP dimodifikasi begini.
    Dipanggil sekali saat script mulai.
]]
local function modifikasiHRP()
    -- TIDAK ada modifikasi! Biarkan default seperti LimeHub.
    -- Anti-cheat detect setiap property change selain WalkSpeed.
end
modifikasiHRP()
-- TIDAK ada HP loop — biarkan normal seperti LimeHub



-- ==========================================
-- SISTEM GERAK  (dipindahkan dari sae_steal_minimal, 2026-08-22)
-- ==========================================
-- Bentuk ini SUDAH TERBUKTI di lapangan: tanpa rubberband, tanpa tersedot ke
-- atas, dan guard tidak lagi menghajar. Jangan diubah tanpa mengukur ulang.
-- Enam hal yang menentukan, semuanya hasil pengukuran:
--
-- 1. HumanoidRootPart wajib CanCollide = false.
-- 2. Kecepatan 250 stud/dtk. JANGAN 300: server memvalidasi posisi dengan jeda
--    ~0,8 dtk, jadi 300 membuat kita ~240 stud di depan validasinya, sementara
--    sentakan terukur mulai di 233 stud. 250 -> ~200 stud, aman.
-- 3. Langkah per frame dikali dt, dan AssemblyLinearVelocity dibiarkan NOL
--    (jangan dipalsukan).
-- 4. Menempel tanah. Raycast dimulai dari +4 stud SAJA di atas kepala -- versi
--    lama menembak dari +60 dan tersangkut atap/badan guard, lalu karakter
--    tersedot ke atas. Kenaikan Y dibatasi 6 stud per langkah.
-- 5. Lewat lane tengah (Bases.Center: X 552..3451 pada Z = -364), jangan
--    terbang lurus menembus wilayah guard.
-- 6. Jangan berlama-lama di dekat sarang: guard bangun ~0,6 detik.

local GERAK = {
    -- 1200, bukan 250.
    --
    -- Angka 250 lama berdiri di atas kesimpulanku yang SALAH. Aku menguji
    -- kecepatan dengan rute yang menembus seluruh area guard (X 700..3200,
    -- lewat tepat di sarang), lalu membaca kematian di 300 sebagai "server
    -- membunuh yang terlalu cepat". Yang sebenarnya terjadi hampir pasti
    -- dipukul guard di jalan -- "sentakan 380 stud" itu lemparannya.
    --
    -- Dibantah langsung oleh pengukuran script pembanding di akun yang SAMA:
    -- 1.092 stud/dtk pada WalkSpeed 225, `anchored = false`, tanpa mover atau
    -- constraint apa pun di HumanoidRootPart. Itu 4,9x WalkSpeed -- jadi
    -- "batas 1,2x WalkSpeed" yang sempat kutulis juga salah.
    --
    -- SIDIK JARI script pembanding, direkam per frame di akun yang sama:
    --   laju     388 .. 3069 stud/dtk
    --   dY       ~ -0,1        -> menempel tanah, Y tetap 70-71
    --   anchored 0 dari 120    -> tidak pernah di-anchor
    --   vel      ~0 di 119/120 -> AssemblyLinearVelocity dinolkan
    --   state    Running 120/120
    --   dt       0,005..0,015  -> per frame, mengikuti frame rate
    --
    -- Itu PERSIS teknik kita: tulis CFrame per frame, kecepatan dinolkan,
    -- menempel tanah, tanpa anchor. Bukan tween, bukan velocity, bukan trik
    -- lain. Satu-satunya beda adalah ANGKANYA.
    --
    -- Lebih cepat juga berarti LEBIH AMAN di sini: makin singkat waktu di dekat
    -- sarang, makin sedikit kesempatan guard memukul.
    -- Diatur dari slider "Speed" di panel; 400 kalau panel belum pernah dipakai.
    --
    -- KOREKSI atas patokan 250 yang lama. Kematian yang dulu dipakai sebagai
    -- buktinya -- tiga kali di 456/510/594 stud/dtk dengan nyawa turun satu
    -- miliar sekaligus -- ternyata BUKAN hukuman laju.
    --
    -- Terukur 2026-08-22: pembunuh itu MENOLKAN nyawa berapa pun besarnya.
    -- Diuji dengan MaxHealth/Health 1e9, damage-nya tercatat -1000000000 dan
    -- tetap mati 3 dari 3 -- jadi angka "-1e9" dulu cuma sebesar nyawa kita
    -- saat itu, bukan tanda pembunuh yang berbeda. Pemicunya masuk
    -- `GuardAreas.<Area>.Bounds`: jalan PELAN 100 stud/dtk pun mati di sana,
    -- 7 dari 7 percobaan, dan CanCollide hidup atau mati tidak berpengaruh.
    --
    -- `KebalMati` DICABUT 2026-08-22 (PlaceVersion 379): `Dead` dinyalakan
    -- balik ~26 ms sesudah nyawa jadi 0 dan tidak bisa ditahan, jadi kekebalan
    -- terhadap `Bounds` itu HILANG. Konsekuensinya patokan 250 berlaku lagi:
    -- masuk area guard tetap membunuh seperti dulu, 7 dari 7.
    --
    -- Yang MASIH belum diukur: batas laju di rute yang legal. Naikkan bertahap,
    -- dan yang dipantau bukan cuma kematian tapi juga KICK -- server terbukti
    -- punya reaksi lain (`ERR INT @27`).
    Kecepatan = Config.Speed or 250,
    -- Menulis gerak di `Stepped` (sebelum fisika) alih-alih `Heartbeat`.
    DiStepped = Config.GerakDiStepped ~= false,
    -- stud/dtk^2. 0 = tanpa ramp (perilaku lama, terbukti kehilangan
    -- kepemilikan di 320).
    Akselerasi = tonumber(Config.Akselerasi) or 600,
    -- Laju maksimum saat melewati mulut GameplayZ (0 = mati). Lihat GERBANG
    -- PELAN di loop luncur.
    KecGerbang = tonumber(Config.KecGerbang) or 120,
    LebarGerbang = tonumber(Config.LebarGerbang) or 30,
    -- Batas perpindahan SATU frame (stud). Menjinakkan lonjakan dt; BigFroot
    -- terukur memakai ~8. 0/nil = tanpa batas (perilaku lama).
    LangkahMaks = tonumber(Config.LangkahMaks) or 12,
    Noclip = Config.Noclip ~= false,
    MenempelTanah = true,
    TinggiKaki = 3.2,
    NaikMaksPerLangkah = 6,
    BatasTerbang = 25,
    PakaiLane = true,
    LaneZ = -364,
    LaneXMin = 560,
    LaneXMaks = 3440,
    MatikanTreadmill = true,
    MatikanGuard = true,
    MatikanAntiCheat = true,
    -- KEKEBALAN. Terukur 2026-08-22: MaxHealth/Health dinaikkan ke 1e9 dan
    -- BERTAHAN -- server tidak mengoreksinya sama sekali selama 4,5 detik
    -- pemantauan. Pukulan guard tercatat -1000, jadi dengan nyawa 1e9 ia cuma
    -- menggores. Sekalian menahan efek mental: PlatformStand dikembalikan ke
    -- false dan keadaan ragdoll/terjatuh dipaksa kembali ke Running.
    Kekebalan = true,
    NyawaTarget = 1e9,
    -- BEKUKAN GUARD -- inti dari Anti Guard, terukur 2026-08-21.
    --
    -- Guard di game ini KLON MILIK CLIENT: ForestGuardRuntime menjalankan
    -- `Guard:Clone()` dengan `ServerOwnsPhysics = false`, dan klon itu tidak
    -- direplikasi. Pukulannya pun bukan keputusan server melainkan LAPORAN
    -- client: `Network.Fire(FOREST_HIT, {EggUid, GuardCFrame})`, dikirim
    -- GuardComponent._attemptAttack begitu
    -- `GuardDistance.XZ(guard, kita) <= ResolveHitDistance()` -- terukur 10 stud,
    -- dan XZ saja, ketinggian TIDAK dihitung (jadi terbang tinggi tidak menolong).
    --
    -- Karena itu menahan lemparan adalah obat yang salah, malah memperparah:
    -- lemparan justru melempar kita KELUAR dari 10 stud itu. Menolkannya membuat
    -- kita menetap di jangkauan dan dipukul lagi tiap ATTACK_MIN_INTERVAL --
    -- persis keluhan "malah kena hit terus".
    --
    -- Yang benar: klon guard diparkir di rumahnya sendiri supaya jaraknya tidak
    -- pernah turun ke 10 stud. Tanpa hook, tanpa mencegat remote.
    -- MATI. Memarkir klon guard hanya menghentikan guard versi client; server
    -- punya guard sendiri dan itulah yang memukul (terukur damage 1000 pada
    -- nyawa 100). Kesembilan guard pernah terukur BEKU sementara pemain tetap
    -- dipukul dan mati -- jadi loop ini membayar mahal untuk hasil nol.
    BekukanGuard = false,
    JarakAmanGuard = 30,
    -- Sambar ulang egg yang terlepas karena pukulan guard.
    --
    -- Memblokir jatuhnya egg butuh mencegat panggilan client, dan itu TIDAK
    -- BISA dilakukan di game ini: hook metamethod -- bahkan yang cuma mencatat
    -- -- membuat pemain di-kick. Jadi yang dilakukan bukan mencegah, melainkan
    -- MEREBUT KEMBALI secepat mungkin: egg yang terjatuh berubah status jadi
    -- "Dropped" di snapshot dan masih bisa disambar lagi.
    -- Pulang lewat atas: DIMATIKAN.
    --
    -- Dicoba dan gagal di lapangan -- menanjak/menurun memicu sentakan, padahal
    -- meluncur menempel tanah tidak. Jadi trap tidak dihindari dengan terbang
    -- melainkan dimatikan langsung (lihat MatikanTrap). Jalurnya dibiarkan ada
    -- supaya bisa diuji lagi kalau perlu, tapi default MATI: full slide.
    PulangLewatAtas = false,

    -- Matikan PlayerTrap yang terpasang pemain lain.
    --
    -- Trap adalah MeshPart 1,9 x 0,6 x 1,8 di workspace.__DEBRIS dengan anak
    -- `Hitbox` (2,9 x 1,6 x 2,8, CanTouch = true). Pemicunya `Hitbox.Touched`
    -- di SERVER, dan syaratnya terbaca jelas di sana: pemicu hanya jadi kalau
    -- penyentuh bukan pemilik trap, `IsPlayerInGameplayArea`, DAN
    -- `IsHoldingEgg`. Jadi trap memang cuma menggigit saat kita pulang membawa
    -- egg dan masih di sisi arena -- persis keluhannya.
    --
    -- Deteksi sentuhan untuk part milik client direplikasi DARI CLIENT KITA,
    -- jadi mematikan CanTouch secara lokal membuat sentuhan itu tidak pernah
    -- dilaporkan. Persis cara treadmill sudah ditangani di `aturTreadmill`.
    --
    -- Atribut `TrapActive = false` BUKAN berarti trap mati; itu berarti belum
    -- meletus. Yang sudah meletus menghapus dirinya sendiri setelah 7,5 detik.
    MatikanTrap = Config.AntiTrap ~= false,

    -- ANTI MENTAL.
    --
    -- Lemparan guard BUKAN sekadar impuls kecepatan -- itu sebabnya menolkan
    -- AssemblyLinearVelocity saja dulu tidak cukup dan tetap "masih mental".
    -- Jalur sebenarnya ada di `ReplicatedStorage.Library.Modules.Ragdoll`:
    -- `ApplyClientRagdoll(char, impuls)` melakukan (1) ChangeState(Physics),
    -- (2) RootPart:ApplyImpulse(impuls), lalu (3) mengubah tiap Motor6D jadi
    -- BallSocketConstraint. Yang melempar jauh adalah RAGDOLL-nya: sendi lepas,
    -- karakter jadi boneka, dan karena noclip menyala dinding tidak menahan --
    -- persis "tembus map lalu jatuh".
    --
    -- Modul itu ada di ReplicatedStorage dan mengekspor pembatalnya sendiri,
    -- `ClearClientRagdoll(char)`, jadi ragdoll dibatalkan memakai API game
    -- sendiri. Tidak ada hook sama sekali -- hook metamethod di game ini bikin
    -- kick, dan itu sudah pernah terjadi.
    TahanMental = true,
    AmbangLemparan = 60,

    -- Kecepatan TERPISAH saat menggenggam egg.
    --
    -- 250 stud/dtk terbukti aman untuk perjalanan biasa, tapi keluhan sentakan
    -- selalu muncul di ruas PULANG SAMBIL MEMBAWA EGG -- tidak pernah saat
    -- berangkat. Itu masuk akal: sebelum Anti Guard ada, egg selalu terlepas
    -- lebih dulu sehingga ruas itu praktis tidak pernah dijalani, jadi Anti
    -- Guard bukan penyebabnya melainkan yang MEMBUAT ruas itu akhirnya terjadi.
    --
    -- Kecepatan saat MENGGENGGAM egg, dan ia MENYESUAIKAN DIRI.
    --
    -- Terukur 2026-08-21 langsung di client, membandingkan posisi yang kita
    -- tulis dengan posisi nyata frame berikutnya:
    --   tangan kosong  -> sentakan NOL, tidak sekali pun
    --   menggenggam    -> sentakan sampai 299,7 stud
    -- Jadi server memang memvalidasi posisi lebih ketat selama egg dibawa, dan
    -- 250 stud/dtk melewatinya. Tangan kosong tetap 250 -- di sana tidak ada
    -- masalah sama sekali.
    --
    -- Dua tersangka lain sudah GUGUR di pengukuran yang sama: LocalScript
    -- `AntiCollisionHighSeedPushBack` sudah dimatikan (Enabled=false) dan
    -- sentakannya tetap ada, dan part egg ternyata tidak menempel di rakitan
    -- HumanoidRootPart sehingga tidak ada tabrakan yang bisa disalahkan.
    -- SAMA dengan kecepatan biasa, dan TIDAK diturunkan otomatis lagi.
    --
    -- Sempat kubuat menyesuaikan diri: turun 20% tiap "sentakan" saat
    -- menggenggam. Itu berdasar model yang SALAH. Terukur 2026-08-21: setelah
    -- turun sampai 98 stud/dtk pun sentakannya tetap terjadi, malah 653 stud --
    -- dan 653 itu kira-kira jarak dari dalam arena kembali ke SpawnLocation
    -- (X=513). Jadi yang terbaca sebagai "sentakan" bukan koreksi kecepatan
    -- server, melainkan GUARD YANG ME-RESET KARAKTER. Memperlambat tidak
    -- menolong sama sekali; ia malah memperlama kita di arena sehingga makin
    -- sering tertangkap.
    -- SAMA dengan kecepatan jelajah, dari slider "Speed" yang sama.
    --
    -- Dua setelan terpisah itulah yang dulu bikin "berangkat kencang, pulang
    -- lambat": menaikkan Kecepatan ke 600 tidak menyentuh angka ini yang masih
    -- 250, dan saat menggenggam HANYA angka ini yang dipakai --
    --   local kecepatan = kecKhusus
    --       or (bawaEgg and (GERAK.KecepatanBawaEgg or 250))
    --       or GERAK.Kecepatan
    -- Script pembanding terukur 1.197 stud/dtk baik membawa egg maupun tidak;
    -- berat egg tidak mengubah apa pun padanya.
    KecepatanBawaEgg = Config.Speed or 250,
    IkatKecBawa = false,
    IkatKecJelajah = true,
    SambarUlang = true,
    SambarUlangJeda = 0.15,
}
getgenv().SAEGerak = GERAK
-- Dicerminkan ke _G juga. `getgenv()` milik executor TIDAK terlihat dari
-- konteks lain (terbukti 2026-08-21: getgenv() ~= _G, dan SAEGerak nil dari
-- luar) -- tanpa cermin ini keadaan script mustahil diperiksa saat mendiagnosis.
_G.SAEGerak = GERAK
_G.SaeTahap = "GERAK siap" 

-- Parkir klon guard di rumahnya.
--
-- Alasan lengkapnya ada di catatan GERAK.BekukanGuard. Singkatnya: pukulan cuma
-- terjadi kalau jarak XZ guard ke kita <= 10 stud, dan guard itu milik client
-- kita sendiri -- jadi cukup pastikan ia tidak pernah sedekat itu.
local rumahGuard = {}

local function daftarGuardRoot()
    local hasil = {}
    local ok, ga = pcall(function()
        return workspace.__OBJECTS.Areas.GuardAreas
    end)
    if not ok or not ga then return hasil end
    for _, area in ipairs(ga:GetChildren()) do
        local g = area:FindFirstChild("Guard")
        local r = g and g:FindFirstChild("HumanoidRootPart")
        if r then hasil[#hasil + 1] = r end
    end
    return hasil
end

local function lepaskanGuard()
    for r, asal in pairs(rumahGuard) do
        if r.Parent then
            pcall(function() r.Anchored = asal.anchored end)
        end
    end
    rumahGuard = {}
end

_G.SaeTahap = "loop guard dispawn"
task.spawn(function()
    local dibekukan = false
    while true do
        task.wait(0.1)
        -- Detak dan keadaan ditulis ke _G supaya "loop mati" bisa dibedakan
        -- dari "loop hidup tapi saklarnya mati" tanpa menebak.
        _G.SaeGuardDetak = (_G.SaeGuardDetak or 0) + 1
        _G.SaeGuardAktif = tostring(GERAK.Kekebalan) .. "/" .. tostring(GERAK.BekukanGuard)
        local aktif = GERAK.Kekebalan and GERAK.BekukanGuard
            and not _G.SaeProteksiPanel
        if not aktif then
            -- Dilepas sekali saja saat saklar dimatikan, bukan tiap putaran.
            if dibekukan then
                lepaskanGuard()
                dibekukan = false
            end
        else
            dibekukan = true
            local hrp = akar()
            local aman = GERAK.JarakAmanGuard or 30
            for _, r in ipairs(daftarGuardRoot()) do
                local asal = rumahGuard[r]
                if asal == nil then
                    -- Direkam saat guard masih tidur di rumahnya; kalau ia sedang
                    -- mengejar, posisi ini ikut terbawa -- karena itu rumahnya
                    -- selalu dikoreksi lagi oleh dorongan menjauh di bawah.
                    asal = { cf = r.CFrame, anchored = r.Anchored }
                    rumahGuard[r] = asal
                end
                local tujuan = asal.cf
                if hrp then
                    local beda = Vector3.new(tujuan.X - hrp.Position.X, 0, tujuan.Z - hrp.Position.Z)
                    if beda.Magnitude < aman then
                        -- Rumah guard bisa kebetulan berdempetan dengan sarang
                        -- yang sedang kita sambar; dorong menjauh sepanjang
                        -- garis kita->rumah supaya tetap di luar jangkauan.
                        local arah = (beda.Magnitude > 0.1) and beda.Unit or Vector3.new(1, 0, 0)
                        tujuan = tujuan + arah * (aman - beda.Magnitude)
                    end
                end
                pcall(function()
                    r.Anchored = true
                    if (r.Position - tujuan.Position).Magnitude > 1 then
                        r.CFrame = tujuan
                    end
                end)
            end
        end
    end
end)

_G.SaeTahap = "anti mental" 
-- Batalkan ragdoll seketika. Penjelasan lengkap ada di catatan GERAK.TahanMental.
local ModulRagdoll = nil
do
    local ok, m = pcall(function()
        return require(game:GetService("ReplicatedStorage").Library.Modules.Ragdoll)
    end)
    if ok and type(m) == "table" and type(m.ClearClientRagdoll) == "function" then
        ModulRagdoll = m
    end
end

local function batalkanRagdoll(ch)
    if not ModulRagdoll then return end
    pcall(ModulRagdoll.ClearClientRagdoll, ch)
end

-- Bagian murah dijalankan tiap frame SESUDAH fisika (Heartbeat): keadaan
-- Humanoid dan kecepatan. Menyapu seluruh keturunan karakter tiap frame terlalu
-- mahal, jadi pemeriksaan sendi ragdoll dipisah ke loop 0,1 detik di bawah.
task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if _G.SaeProteksiPanel then return end
        if not (GERAK.Kekebalan and GERAK.TahanMental) then return end
        local ch = Player.Character
        if not ch then return end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp
            or (hum.Health <= 0 and not _G.SaeKebalAktif) then return end

        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics
            or st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown then
            batalkanRagdoll(ch)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if hum.PlatformStand then
            hum.PlatformStand = false
        end

        -- Sisa impuls dibuang. Gerak kita sendiri memakai CFrame dan selalu
        -- menyetel kecepatan ke nol, jadi kecepatan besar SELALU dari luar.
        if hrp.AssemblyLinearVelocity.Magnitude > (GERAK.AmbangLemparan or 60) then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end)

-- Sendi ragdoll bisa tertinggal walau keadaan Humanoid sudah normal lagi;
-- selama sendi itu ada, karakter tetap terurai dan gampang terlempar.
task.spawn(function()
    while true do
        task.wait(0.1)
        if GERAK.Kekebalan and GERAK.TahanMental then
            local ch = Player.Character
            if ch then
                local ada = false
                for _, x in ipairs(ch:GetDescendants()) do
                    if (x:IsA("BallSocketConstraint") or x:IsA("HingeConstraint"))
                        and x:GetAttribute("RagdollConstraint") then
                        ada = true
                        break
                    end
                end
                if ada then
                    batalkanRagdoll(ch)
                end
            end
        end
    end
end)

_G.SaeTahap = "anti trap" 
-- Matikan trap pemain.
--
-- Dijalankan terus, bukan cuma saat mencuri: trap dipasang di mana saja, dan
-- yang baru bisa muncul kapan saja. Sifatnya lokal dan bisa dibalik -- CanTouch
-- dikembalikan ke nilai asli begitu saklarnya dimatikan.
local trapAsli = {}

local function bagianTrap(x)
    -- MeshPart trap-nya sendiri plus anak `Hitbox`; keduanya CanTouch = true
    -- dari sisi server, jadi keduanya harus dimatikan.
    local hasil = {}
    if x:IsA("BasePart") then hasil[#hasil + 1] = x end
    for _, c in ipairs(x:GetDescendants()) do
        if c:IsA("BasePart") then hasil[#hasil + 1] = c end
    end
    return hasil
end

local function aturTrap(matikan)
    local wadah = workspace:FindFirstChild("__DEBRIS")
    local daftar = {}
    if wadah then
        for _, x in ipairs(wadah:GetChildren()) do
            if x.Name == "PlayerTrap" then
                daftar[#daftar + 1] = x
            end
        end
    end
    if matikan then
        for _, trap in ipairs(daftar) do
            for _, part in ipairs(bagianTrap(trap)) do
                if trapAsli[part] == nil then
                    trapAsli[part] = { part.CanTouch, part.CanCollide }
                end
                pcall(function()
                    part.CanTouch = false
                    part.CanCollide = false
                end)
            end
        end
    else
        for part, asal in pairs(trapAsli) do
            if part.Parent then
                pcall(function()
                    part.CanTouch = asal[1]
                    part.CanCollide = asal[2]
                end)
            end
        end
        trapAsli = {}
    end
end
getgenv().SAEAturTrap = aturTrap

-- Trap yang BARU dipasang harus tertangkap seketika, bukan menunggu putaran
-- berikutnya: pemain bisa menaruhnya tepat di depan kita.
task.spawn(function()
    local wadah = workspace:WaitForChild("__DEBRIS", 30)
    if not wadah then return end
    wadah.ChildAdded:Connect(function(x)
        if x.Name == "PlayerTrap" and GERAK.MatikanTrap then
            -- Hitbox adalah anak yang direplikasi menyusul, jadi ditunggu dulu.
            task.spawn(function()
                x:WaitForChild("Hitbox", 5)
                pcall(aturTrap, true)
            end)
        end
    end)
end)

task.spawn(function()
    local dimatikan = false
    while true do
        task.wait(0.25)
        if GERAK.MatikanTrap and not _G.SaeProteksiPanel then
            dimatikan = true
            pcall(aturTrap, true)
        elseif dimatikan then
            dimatikan = false
            pcall(aturTrap, false)
        end
    end
end)

-- Jaring pengaman kalau toh sempat kena.
--
-- Trap membekukan dengan `rootPart.Anchored = true` + JumpHeight/AutoRotate/
-- PlatformStand, dan menandai karakter dengan atribut `IsTrapped`. Melepas
-- anchor secara lokal mengembalikan kendali gerak tanpa menunggu 7 detik.
task.spawn(function()
    while true do
        task.wait(0.2)
        if GERAK.MatikanTrap then
            local ch = Player.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Anchored or ch:GetAttribute("IsTrapped")) then
                pcall(function()
                    hrp.Anchored = false
                    local hum = ch:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.PlatformStand = false
                        hum.AutoRotate = true
                    end
                end)
            end
        end
    end
end)

_G.SaeTahap = "sambar ulang" 
-- Rebut kembali egg yang terlepas.
--
-- Berjalan pasif: cuma membaca snapshot dan memanggil remote resmi yang sama
-- dengan yang dipakai saat mencuri. Tidak ada hook, tidak ada penyadapan.
task.spawn(function()
    local uidTerakhir = nil
    while true do
        task.wait(GERAK.SambarUlangJeda or 0.15)
        if GERAK.SambarUlang and GERAK.Kekebalan then
            pcall(function()
                local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
                if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
                    return
                end
                -- Masih memegang sesuatu? Ingat uid-nya, tidak perlu berbuat apa-apa.
                for _, rec in pairs(snap.Records) do
                    if rec.State == "Carried" and rec.CarrierUserId == Player.UserId then
                        uidTerakhir = rec.Uid
                        return
                    end
                end
                -- Tidak memegang, tapi egg yang tadi kita bawa kini tergeletak
                -- di dekat kita: itu terlepas karena dipukul. Sambar lagi.
                if not uidTerakhir then return end
                local hrp = akar()
                if not hrp then return end
                for _, rec in pairs(snap.Records) do
                    if rec.Uid == uidTerakhir and rec.State == "Dropped" and rec.BottomCFrame then
                        local jarak = (rec.BottomCFrame.Position - hrp.Position).Magnitude
                        if jarak < 120 then
                            pcall(EggCmds.RequestCarryAreaEgg, rec.Uid, nil)
                        else
                            uidTerakhir = nil
                        end
                        return
                    end
                end
                uidTerakhir = nil
            end)
        end
    end
end)

-- Kekebalan: nyawa dijaga penuh, dan efek mental dibatalkan.
--
-- Dijalankan di Stepped supaya sempat membatalkan ragdoll sebelum fisika
-- sempat melemparkan karakter. Ia TIDAK pernah menulis posisi, jadi tidak bisa
-- ikut menarik karakter seperti bug lama.
task.spawn(function()
    RunService.Stepped:Connect(function()
        if not GERAK.Kekebalan then return end
        -- GERAK.Kekebalan disinkronkan dari saklar GUI (S.Kekebalan).
        local ch = Player.Character
        if not ch then return end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or (hum.Health <= 0 and not _G.SaeKebalAktif) then return end

        -- Menaikkan nyawa dilewati saat KebalMati menyala. Dua alasan, dua-duanya
        -- terukur: pembunuhnya menolkan nyawa berapa pun (1e9 pun mati 3 dari 3),
        -- dan menulis nyawa berulang memicu kick `ERR INT @27`.
        if not _G.SaeKebalAktif then
            if hum.MaxHealth < GERAK.NyawaTarget then
                hum.MaxHealth = GERAK.NyawaTarget
            end
            if hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end
        if hum.PlatformStand then
            hum.PlatformStand = false
        end

        -- Kecepatan SENGAJA tidak dinolkan di sini lagi.
        --
        -- Menolkannya justru menahan kita di dalam radius pukul 10 stud sehingga
        -- guard memukul berulang kali. Kalau toh sebuah pukulan lolos, terlempar
        -- itu menguntungkan: ia mengeluarkan kita dari jangkauan, dan egg yang
        -- terjatuh disambar lagi oleh loop SambarUlang.
        local hrp = ch:FindFirstChild("HumanoidRootPart")

        -- Benda pelempar yang ditempelkan game (BodyVelocity/LinearVelocity/
        -- VectorForce) dimatikan, bukan dihancurkan -- yang membuatnya game,
        -- dan menghancurkan milik orang lain gampang menimbulkan error susulan.
        if hrp then
            for _, x in ipairs(hrp:GetChildren()) do
                if (x:IsA("BodyVelocity") or x:IsA("BodyForce") or x:IsA("BodyThrust")
                    or x:IsA("LinearVelocity") or x:IsA("VectorForce"))
                    and x.Name ~= "SwimmingLinearVelocity" then
                    pcall(function() x.Enabled = false end)
                    pcall(function() x.Velocity = Vector3.zero end)
                    pcall(function() x.Force = Vector3.zero end)
                end
            end
        end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end)

local sedangTerbang = false
local terbangSejak = 0

-- Alasan untuk MEMBATALKAN penerbangan yang sedang berjalan.
--
-- Diisi pemanggil sebelum berangkat, dibaca `luncurKe` tiap frame. Dipakai
-- untuk berhenti di tengah jalan ketika target sudah tidak ada gunanya lagi --
-- mis. egg keburu disambar pemain lain. Tanpa ini kita tetap menempuh 2.800
-- stud menuju sarang yang sudah kosong.
local batalTerbang = nil

-- Penjaga bendera penggerak.
--
-- `luncurKe` menaikkan `sedangTerbang` di awal dan baru menurunkannya di baris
-- terakhir. Kalau ada error di tengah loop -- dan pemanggilnya membungkus
-- dengan pcall sehingga errornya tertelan -- bendera itu tersangkut `true`
-- SELAMANYA, dan tiap perintah gerak berikutnya ditolak "penggerak sedang
-- dipakai". Gejalanya: karakter berhenti total di tempat, tidak tersangkut apa
-- pun, dan tiap sambaran ditolak server karena kita tidak pernah sampai ke
-- arena. Terukur 2026-08-21: diam di X=663, bergeser 0 stud dalam 2 detik.
--
-- Batasnya BatasTerbang + 6 detik: penerbangan sah paling lama BatasTerbang,
-- jadi lewat dari itu pasti sudah tidak ada pemiliknya.
task.spawn(function()
    while true do
        task.wait(1)
        if sedangTerbang and terbangSejak > 0
            and os.clock() - terbangSejak > (GERAK.BatasTerbang or 25) + 6 then
            sedangTerbang = false
            _G.SaeSedangTerbang = false
            _G.SaeBenderaDibebaskan = (_G.SaeBenderaDibebaskan or 0) + 1
        end
    end
end)

-- Tinggi jelajah saat pulang, dipasang sebagai KEADAAN, bukan argumen.
--
-- Versi pertama menaruhnya sebagai parameter `bankKeBase` saja, dan itu tidak
-- pernah terpakai: `bankKeBase` dibuka dengan `if not Config.BankKeBase then
-- return true end`, sedangkan di config pemain setelan itu MATI. Jalur pulang
-- yang benar-benar berjalan adalah `lariKeAman`. Sebagai keadaan, SEMUA ruas
-- perjalanan ikut naik tanpa perlu menambal tiap pemanggil.
--
-- Hitbox PlayerTrap terukur 2,9 x 1,6 x 2,8 stud dan berhenti 1,6 stud di atas
-- tanah, sementara kita meluncur dengan kaki nyaris menyentuh tanah -- itulah
-- sebabnya trap selalu kena.
-- Ditandai saat sambaran diterima, dibersihkan setelah sampai rumah.
-- Sengaja BUKAN eggDipegang(): fungsi itu memanggil GetAreaEggSnapshot, terlalu
-- mahal untuk dipanggil tiap frame di dalam mesin luncur.
local bawaEgg = false

-- Pengendali kecepatan saat menggenggam.
--
-- Tiga hal yang membuat perjalanan bawa-egg tidak stabil, dan masing-masing
-- ditangani di sini:
--
-- 1. WalkSpeed BERFLUKTUASI. Server menuliskannya berkala, jadi sesaat setelah
--    menyambar nilainya masih yang lama (tinggi) sebelum penalti egg berlaku.
--    Membaca nilai sesaat berarti kita sempat meluncur jauh di atas jatah.
--    -> dipakai NILAI TERENDAH dalam 1 detik terakhir, bukan nilai sesaat.
-- 2. Penalti belum sempat diterapkan di detik pertama.
--    -> 0,5 detik pertama sesudah menyambar dijalankan pelan (0,8x).
-- 3. Kalau toh tetap ditarik, tidak ada gunanya mengulang kesalahan yang sama.
--    -> pengali turun permanen untuk perjalanan itu, dan pulih sendiri saat
--       tangan kosong lagi.
local kaliBawa = 1.0
local wsRiwayat = {}
local mulaiBawa = 0

local function kecepatanBawa()
    local hum = Player.Character
        and Player.Character:FindFirstChildOfClass("Humanoid")
    local ws = hum and hum.WalkSpeed
    if not ws or ws <= 0 then return nil end

    local t = os.clock()
    wsRiwayat[#wsRiwayat + 1] = { t = t, v = ws }
    while #wsRiwayat > 0 and t - wsRiwayat[1].t > 1 do
        table.remove(wsRiwayat, 1)
    end
    local terendah = ws
    for _, r in ipairs(wsRiwayat) do
        if r.v < terendah then terendah = r.v end
    end

    -- TEPAT di WalkSpeed, tidak melampauinya sama sekali.
    --
    -- Ini bukan sekadar hati-hati, ada alasannya: WalkSpeed yang diberikan game
    -- SUDAH merupakan hasil kalkulasi berat egg (terukur: 623 kg -> 216,1;
    -- 8.690 kg -> 204,7; kosong -> 225,1, dan kembali persis begitu dilepas).
    -- Jadi bergerak tepat sebesar itu berarti bergerak persis seperti pemain
    -- sungguhan yang membawa egg sama beratnya -- tidak ada yang bisa ditolak
    -- server, karena tidak ada yang dilampaui.
    --
    -- Dan kita tidak kehilangan apa pun dengan tidak melampauinya: guard yang
    -- mengejar IKUT melambat bersama kita, jadi jarak relatifnya tetap sama.
    -- Rasio 1,11x memang pernah terukur bersih, tapi 1,22x sudah mendekati
    -- batas dan 1,26x ditarik -- ruangnya terlalu sempit untuk ditukar dengan
    -- risiko kehilangan egg.
    local kali = kaliBawa
    if t - mulaiBawa < 0.5 then
        -- Detik pertama: penalti berat sering belum sempat diterapkan server,
        -- jadi WalkSpeed masih menunjukkan angka tangan-kosong yang tinggi.
        kali = math.min(kali, 0.85)
    end
    _G.SaeKecBawaHidup = math.max(60, terendah * kali)
    _G.SaeKaliBawa = kaliBawa
    return _G.SaeKecBawaHidup
end

local tinggiPulang = 0
local function aturPulangTinggi(nyala)
    if nyala and GERAK.PulangLewatAtas then
        -- Dijepit ke 8..60 sebagai margin, BUKAN karena 60 terbukti jadi batas:
        -- +73 pun selamat di dua dari tiga percobaan. Yang pasti cuma bahwa
        -- makin tinggi makin lama menanjak dan menurun, sementara 8 stud saja
        -- sudah melewati hitbox trap. Penjepit ini sekaligus menjaga nilai
        -- tersimpan yang kelewat besar -- di proyek ini config tersimpan
        -- menimpa default, jadi mengganti default saja tidak cukup.
        tinggiPulang = math.clamp(tonumber(Config.ReturnHeight) or 25, 8, 60)
    else
        tinggiPulang = 0
    end
end

local paramTanah = RaycastParams.new()
paramTanah.FilterType = Enum.RaycastFilterType.Exclude

-- Ketinggian tanah di bawah satu titik.
--
-- Yang dicari TANAH, dan tanah selalu Anchored. Part yang tidak di-anchor
-- dilewati, lalu sinarnya diteruskan ke bawahnya.
--
-- Ini bukan kerapian, ini perbaikan bug: EGG YANG KITA GENGGAM adalah benda
-- besar yang ikut bergerak bersama kita dan BUKAN bagian dari model karakter,
-- jadi ia lolos dari saringan lama yang cuma mengecualikan karakter. Sinar
-- membentur egg, "tanah" terbaca setinggi punggung egg, lalu kita dinaikkan ke
-- atasnya -- dan frame berikutnya egg itu ikut naik, jadi naik lagi. Makin
-- besar egg makin parah, dan hanya terasa saat pulang menggenggam: persis
-- gejala "jalan biasa normal, pegang egg gede posisinya jadi kacau".
local function tinggiTanah(x, z, yAcuan)
    -- DIKEMBALIKAN ke bentuk build 24c.
    --
    -- Sempat kuubah supaya melewati part tak-anchored, dengan dugaan sinar
    -- membentur egg genggaman. Dugaan itu tidak pernah terbukti -- loop pencari
    -- part egg tidak menemukan satu pun -- sementara build 24c yang memakai
    -- bentuk sederhana ini terbukti aman untuk egg Eternal di tangan buyer.
    -- Jangan diubah lagi tanpa bukti bahwa sinarnya memang salah sasaran.
    local ch = Player.Character
    paramTanah.FilterDescendantsInstances = ch and { ch } or {}
    local asal = Vector3.new(x, (yAcuan or 100) + 4, z)
    local hasil = workspace:Raycast(asal, Vector3.new(0, -300, 0), paramTanah)
    return hasil and hasil.Position.Y or nil
end
-- Benarkah kita mati, atau karakternya cuma sedang tidak ada sesaat?
--
-- Versi lama melaporkan "mati" begitu Character/Humanoid tidak ketemu, dan itu
-- menghasilkan laporan PALSU: perekam kematian tidak mencatat satu pun `Died`
-- maupun penurunan nyawa, padahal jejak gerak penuh "mati saat meluncur".
-- Sebabnya guard menangkap dengan ME-RESET karakter -- model lama hilang
-- sesaat, lalu model baru muncul.
--
-- `_G.SaeAlasanMati` menyimpan sebab terakhir supaya tidak perlu ditebak lagi.
local function nyawaOk()
    local ch = Player.Character
    if not ch then
        _G.SaeAlasanMati = "Character nil"
        return false
    end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then
        _G.SaeAlasanMati = "Humanoid nil"
        return false
    end
    if hum.Health <= 0 and not _G.SaeKebalAktif then
        _G.SaeAlasanMati = string.format("Health %.0f/%.0f", hum.Health, hum.MaxHealth)
        return false
    end
    return true
end

-- Mesin luncur tunggal. Tidak memakai :Connect() supaya umurnya milik
-- pemanggilnya dan tidak bisa diputus dari luar.
-- `tinggiEkstra` = melayang sekian stud di atas permukaan sepanjang perjalanan.
-- X bidang GameplayZ, diambil sekali saat pertama dibutuhkan. Dipakai untuk
-- memperlambat luncuran tepat di mulut gerbang -- lihat GERBANG PELAN.
local GerbangXCache = nil
-- Dipakai saat pulang membawa egg, supaya tidak menyentuh trap di tanah.
local function luncurKe(tujuan, toleransi, tinggiEkstra, kecKhusus)
    if sedangTerbang then
        return false, "penggerak sedang dipakai"
    end
    sedangTerbang = true
    -- Dicatat supaya penjaga di bawah bisa membebaskan bendera ini kalau
    -- pemiliknya mati di tengah jalan. Tanpa itu satu error saja membekukan
    -- SELURUH gerak sampai script dijalankan ulang.
    terbangSejak = os.clock()
    _G.SaeSedangTerbang = true
    toleransi = toleransi or 8
    tinggiEkstra = math.max(tinggiEkstra or 0, tinggiPulang)
    -- Kecepatan yang benar-benar dipakai, merayap naik ke target (lihat
    -- catatan AKSELERASI di dalam loop). Mulai dari WalkSpeed supaya langkah
    -- pertama tidak pernah jadi lompatan mendadak.
    local kecLaju = 0
    do
        local humA = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        kecLaju = (humA and humA.WalkSpeed and humA.WalkSpeed > 0) and humA.WalkSpeed or 100
    end
    local tulisTerakhir = nil
    local adaSnap = false
    local snapBeruntun = 0
    local jalanKaki = false

    mulaiNoclip(true)

    local hasil, alasan = false, nil
    local mulai = os.clock()
    while true do
        -- Jalan kaki jauh lebih lambat daripada meluncur, jadi batas waktunya
        -- dilonggarkan; kalau tidak, tiap peralihan ke jalan kaki pasti berakhir
        -- "kehabisan waktu".
        local batasIni = jalanKaki and (GERAK.BatasTerbang * 4) or GERAK.BatasTerbang
        if os.clock() - mulai > batasIni then
            alasan = "kehabisan waktu"
            break
        end
        if not nyawaOk() then
            alasan = "mati saat meluncur"
            break
        end
        if batalTerbang then
            local okB, sebabB = pcall(batalTerbang)
            if okB and sebabB then
                alasan = tostring(sebabB)
                break
            end
        end
        local h = akar()
        if not h then
            alasan = "karakter hilang"
            break
        end

        local selisih = tujuan - h.Position
        local jarak = GERAK.MenempelTanah
            and Vector3.new(selisih.X, 0, selisih.Z).Magnitude
            or selisih.Magnitude
        if jarak <= toleransi then
            hasil = true
            break
        end

        -- Gerak ditulis di `Stepped` (SEBELUM fisika), bukan `Heartbeat`.
        --
        -- Terukur 2026-08-23 dari BigFroot: 99,6% perpindahannya jatuh di ruas
        -- Stepped->Heartbeat, laju sampai 1.174 stud/dtk, NOL sentakan. Script
        -- kita menulis di Heartbeat -- sesudah fisika -- dan kena rubberband
        -- sejak 270. Dugaannya: tulisan sebelum fisika ikut disimulasikan dan
        -- direplikasi sebagai keadaan wajar; tulisan sesudahnya terkirim sebagai
        -- loncatan mentah dan ditolak server.
        --
        -- `Stepped:Wait()` mengembalikan DUA nilai (waktu, delta) -- beda dari
        -- `Heartbeat:Wait()`. Salah ambil di sini membuat dt jadi jam server.
        local dt
        if GERAK.DiStepped then
            local _, d = RunService.Stepped:Wait()
            dt = d
        else
            dt = RunService.Heartbeat:Wait()
        end
        local h2 = akar()
        if not h2 then
            alasan = "karakter hilang"
            break
        end
        -- Sentakan = selisih antara posisi yang KITA tulis frame lalu dengan
        -- posisi nyata sekarang. Selisih besar berarti server memindahkan kita.
        if tulisTerakhir then
            local selisihNyata = (h2.Position - tulisTerakhir).Magnitude
            if selisihNyata > 6 then
                local kunci = bawaEgg and "SaeSnapBawa" or "SaeSnapKosong"
                if (rawget(_G, kunci) or 0) < selisihNyata then
                    _G[kunci] = selisihNyata
                end
                _G.SaeSnapJml = (_G.SaeSnapJml or 0) + 1

                -- Titik ASAL dan TUJUAN dicatat. Besarnya lompatan saja tidak
                -- cukup: tujuan di X~513 berarti karakter di-reset ke
                -- SpawnLocation, X~553 berarti ditarik ke gerbang, dan tujuan
                -- acak berarti sesuatu yang lain lagi. Tanpa ini tiga sebab yang
                -- sangat berbeda terlihat sama.
                local d = _G.SaeSnapJejak
                if type(d) ~= "table" then
                    d = {}
                    _G.SaeSnapJejak = d
                end
                d[#d + 1] = string.format("%s %.0f stud | tulis(%.0f,%.0f,%.0f) -> nyata(%.0f,%.0f,%.0f)",
                    bawaEgg and "BAWA" or "kosong", selisihNyata,
                    tulisTerakhir.X, tulisTerakhir.Y, tulisTerakhir.Z,
                    h2.Position.X, h2.Position.Y, h2.Position.Z)
                while #d > 20 do table.remove(d, 1) end

                -- Menyesuaikan diri, bukan menebak angka sekali lalu berharap.
                -- Tiap sentakan saat menggenggam menurunkan kecepatan bawa 20%
                -- sampai batas bawah, dan nilainya bertahan selama sesi -- jadi
                -- akun yang server-nya lebih ketat menemukan batasnya sendiri
                -- tanpa perlu diukur ulang secara manual.
                -- Angkanya cuma DICATAT, tidak lagi dipakai menurunkan
                -- kecepatan: lompatan besar di sini berarti karakter di-reset
                -- guard, bukan kita terlalu cepat.
                -- HITUNG PENOLAKAN, DAN MENYERAH SEBELUM YANG KETIGA.
                --
                -- Aturannya datang dari lapangan, bukan dari teori: sentakan
                -- tiga kali berarti mati/reset, hampir selalu. Itu ciri
                -- anti-cheat yang membunuh setelah sekian kali gerak ditolak --
                -- jadi yang harus dihentikan penolakannya, bukan akibatnya.
                --
                -- Begitu penolakan KEDUA terjadi saat menggenggam, kita berhenti
                -- menulis CFrame sama sekali dan berjalan seperti pemain biasa
                -- lewat Humanoid. Jalan kaki tidak pernah ditolak server, jadi
                -- hitungannya tidak pernah sampai tiga.
                if bawaEgg then
                    adaSnap = true
                    snapBeruntun = snapBeruntun + 1
                    -- Ditarik berarti jatahnya terlampaui. Turunkan pengali
                    -- untuk SISA perjalanan ini; mengulang angka yang sama cuma
                    -- menghasilkan tarikan berikutnya.
                    kaliBawa = math.max(0.7, kaliBawa - 0.15)
                    _G.SaeKaliBawa = kaliBawa
                    if snapBeruntun >= 2 then
                        jalanKaki = true
                        _G.SaeJalanKakiPaksa = (_G.SaeJalanKakiPaksa or 0) + 1
                        log("gerak ditolak 2x sambil menggenggam — beralih jalan kaki")
                    end
                end
            end
        end
        -- Vektor nol tidak boleh dinormalkan: hasilnya NaN, dan menulis CFrame
        -- ber-NaN melempar error -- yang dulu berarti bendera penggerak
        -- tersangkut dan seluruh gerak mati.
        local mentah = GERAK.MenempelTanah
            and Vector3.new(selisih.X, 0, selisih.Z)
            or selisih
        if mentah.Magnitude < 1e-4 then
            hasil = true
            break
        end
        local arah = mentah.Unit
        -- Kecepatan khusus diberikan PER PANGGILAN, tidak pernah menimpa
        -- GERAK.Kecepatan. Versi sebelumnya menimpa nilai global lalu
        -- mengembalikannya di baris terakhir -- dan kalau alurnya terputus di
        -- tengah (mati, error), seluruh script tertinggal di kecepatan lambat
        -- itu. Terekam: penerbangan 450 stud butuh 22,4 detik (~20 stud/dtk)
        -- padahal rute sama biasanya 1.729 stud dalam 7,0 detik.
        local kecepatan = kecKhusus
            or (bawaEgg and (GERAK.KecepatanBawaEgg or 250))
            or GERAK.Kecepatan

        -- Kecepatan jelajah IKUT WalkSpeed, tidak dipatok angka mati.
        --
        -- Atap kecepatan ternyata ditentukan RASIO terhadap WalkSpeed, bukan
        -- angka mutlak. Terukur, semuanya di lane yang sama:
        --   ws 225, luncur 250 = 1,11x -> bersih
        --   ws 204, luncur 250 = 1,22x -> ditarik (saat menggenggam)
        --   ws 225, luncur 300 = 1,33x -> MATI seketika
        --
        -- Dan itu BUKAN soal cara bergerak: tulis-CFrame mati di 300, TweenService
        -- + Anchored juga mati di 300 (sentakan 388 stud), gerak berbasis
        -- velocity malah dilawan Humanoid sampai efektif ~50 stud/dtk.
        --
        -- Karena WalkSpeed tumbuh mengikuti SpeedPower, mengikatkannya begini
        -- membuat kecepatan kita NAIK SENDIRI saat akun makin kuat -- tanpa
        -- perlu menyetel ulang apa pun. Dipakai 1,1x (di bawah 1,22x yang sudah
        -- terbukti ditarik), dan tidak pernah lebih lambat dari 250 yang sudah
        -- terbukti aman.
        -- DICABUT. Pengikatan ke WalkSpeed lahir dari model rasio yang sudah
        -- terbantah (script pembanding: 4,9x WalkSpeed, mulus). Dibiarkan mati
        -- supaya kecepatan jelajah murni mengikuti GERAK.Kecepatan.
        if false and not kecKhusus and not bawaEgg and GERAK.IkatKecJelajah ~= false then
            local humJ = Player.Character
                and Player.Character:FindFirstChildOfClass("Humanoid")
            if humJ and humJ.WalkSpeed > 0 then
                kecepatan = math.max(GERAK.Kecepatan, humJ.WalkSpeed * 1.1)
                _G.SaeKecJelajah = kecepatan
            end
        end

        -- SAAT MENGGENGGAM: ikat ke WalkSpeed HIDUP, bukan angka tetap.
        --
        -- Yang menentukan diterima atau ditolaknya gerak kita ternyata bukan
        -- laju mutlak, melainkan SEBERAPA JAUH KITA MELAMPAUI WalkSpeed saat
        -- itu. Terukur di client, semuanya di lane yang sama:
        --
        --   tangan kosong  WalkSpeed 225, luncur 250 = 1,11x -> bersih,
        --                  0 sentakan sepanjang 460 frame
        --   bawa Bronto    WalkSpeed 199, luncur 250 = 1,26x -> DITARIK
        --   tangan kosong  WalkSpeed 225, luncur 300 = 1,33x -> MATI seketika
        --
        -- Game memang menurunkan WalkSpeed pembawa egg berat (225 -> 199 pada
        -- 24.115 kg), jadi angka tetap 250 diam-diam berubah arti begitu egg
        -- makin berat. Dipakai 1,05x -- lebih rapat daripada 1,11x yang sudah
        -- terbukti aman.
        --
        -- Catatan: WalkSpeed TIDAK BISA dinaikkan sebagai jalan pintas. Diuji
        -- 300/400/500/650, semuanya ditimpa balik game ke 225 dalam < 0,4 detik.
        -- Pengendali kecepatan-bawa DIMATIKAN (IkatKecBawa default false).
        --
        -- Ia menurunkan kecepatan ke WalkSpeed saat menggenggam, dengan dugaan
        -- server menolak gerak yang melampaui WalkSpeed. Dugaan itu terbantah:
        -- script pembanding membawa egg pada laju penuh, tidak melambat sama
        -- sekali. Kodenya dibiarkan supaya bisa dinyalakan lagi lewat
        -- `getgenv().SAEGerak.IkatKecBawa = true` kalau ternyata masih perlu.
        if bawaEgg and not kecKhusus and GERAK.IkatKecBawa == true then
            local kb = kecepatanBawa()
            if kb then kecepatan = kb end
        end

        -- DICABUT. Ikatan ke WalkSpeed ini pernah dipasang di sini dan TERBANTAH:
        -- script pembanding membawa egg 5 JUTA kg pada laju penuh tanpa
        -- sentakan sama sekali. Kalau server menolak berdasarkan laju, script
        -- itu justru yang paling parah tersentak. Sebab sesungguhnya sudah
        -- terukur: karakter MATI saat membawa egg berat, lalu server mengambil
        -- alih simulasi (ReceiveAge 0 -> 0,10) dan menimpa balik tiap tulisan
        -- CFrame kita. Blok di bawah dimatikan, biarkan sebagai catatan.
        if false then
        --
        -- Game memperlambat pembawa egg berat lewat WalkSpeed. Angka tetap 250
        -- aman ketika WalkSpeed ~225 (1,1x), tapi begitu egg berat menurunkan
        -- WalkSpeed, 250 jadi berkali-kali lipat dari yang server izinkan dan
        -- gerak kita ditolak. Terekam 2026-08-21 dengan Bronto ~31.000 kg:
        -- kita menulis X mengecil (menuju pulang), server mengembalikan kita ke
        -- X yang sama berulang kali -- 238, 237, 236, 225 stud -- dengan titik
        -- tujuan yang persis sama (2799, lalu 2581). Itu ciri penolakan posisi,
        -- bukan tabrakan.
        --
        -- 1,2x adalah angka yang sudah terbukti di proyek ini; batas bawah 60
        -- supaya egg sangat berat tidak membuat kita merayap.
            local humK = Player.Character
                and Player.Character:FindFirstChildOfClass("Humanoid")
            local ws = humK and humK.WalkSpeed
            if ws and ws > 0 then
                kecepatan = math.clamp(ws * 1.2, 60, kecepatan)
                _G.SaeKecBawa = kecepatan
            end
        end
        -- AKSELERASI BERTAHAP. Terukur 2026-08-23 dengan detektor
        -- `isnetworkowner`: melompat seketika ke 320 stud/dtk membuat server
        -- MENCABUT network ownership HRP dalam 1,51 detik -- sesudah itu server
        -- yang mensimulasikan karakter dan semua tulisan CFrame kita dibuang
        -- (itulah "beku di tempat" yang selama ini disalahartikan rubberband).
        --
        -- Dengan kecepatan dinaikkan mulus, kepemilikan BERTAHAN sampai 501
        -- stud/dtk tanpa sekali pun lepas. Jadi pemicunya perubahan mendadak,
        -- bukan laju mutlak. `Akselerasi` = stud/dtk^2; 0 mematikan ramp.
        -- GERBANG PELAN. `GameplayZ` cuma setebal ~2,5 stud di X~553, dan ia
        -- pintu masuk arena yang sesungguhnya -- server menolak carry, lalu
        -- menarik kita pulang, kalau penyeberangannya tidak pernah tercatat.
        --
        -- Terukur 2026-08-23 pada Speed 340: karakter mentok di x~527-536 lalu
        -- dilempar balik ke 492 berulang kali, 48 sentakan. Penyebabnya rutin
        -- `lewatiGerbangZ` menahan posisi di kotak gerbang (Y=68) sementara
        -- mesin luncur mendorong maju di Y=71; pada 250 selisih per frame kecil
        -- dan tak terasa, pada 340 keduanya bertengkar dan kita tidak pernah
        -- benar-benar lewat.
        --
        -- Melambat HANYA di mulut gerbang, bukan menurunkan Speed global.
        if (GERAK.KecGerbang or 0) > 0 then
            if GerbangXCache == nil then
                local a = workspace:FindFirstChild("__OBJECTS")
                a = a and a:FindFirstChild("Areas")
                local gz = a and a:FindFirstChild("GameplayZ")
                GerbangXCache = (gz and gz:IsA("BasePart")) and gz.Position.X or false
            end
            if GerbangXCache and math.abs(h2.Position.X - GerbangXCache) < (GERAK.LebarGerbang or 30) then
                kecepatan = math.min(kecepatan, GERAK.KecGerbang)
                kecLaju = math.min(kecLaju, GERAK.KecGerbang)
                _G.SaeGerbangPelan = (_G.SaeGerbangPelan or 0) + 1
            end
        end

        if (GERAK.Akselerasi or 0) > 0 then
            kecLaju = math.min(kecepatan, kecLaju + GERAK.Akselerasi * dt)
            kecepatan = kecLaju
            _G.SaeKecRamp = math.floor(kecLaju)
        end
        -- LANGKAH DIBATASI PER FRAME. `kecepatan * dt` mengubah frame tersendat
        -- jadi teleport: pada 340 stud/dtk, hitch 0,5 detik menghasilkan langkah
        -- 170 stud dalam SATU frame, dan ambang penolakan server terukur 233.
        --
        -- Terekam 2026-08-23: tulisan kita melompat 163, 270, lalu 286 stud
        -- sementara posisi nyata tertinggal di 627 -- bukan server memaku kita,
        -- melainkan langkah kita sendiri yang meledak lalu ditolak.
        --
        -- BigFroot melangkah JARAK TETAP ~8 stud per frame, bukan kecepatan*dt,
        -- jadi frame tersendat tidak pernah membesarkan langkahnya. Itu sebabnya
        -- ia bisa 1.000+ stud/dtk tanpa sekali pun kena sentakan.
        local langkah = math.min(jarak, kecepatan * dt, GERAK.LangkahMaks or math.huge)
        local titik = h2.Position + arah * langkah

        if GERAK.MenempelTanah then
            local yT = tinggiTanah(titik.X, titik.Z, h2.Position.Y)
            if yT then
                local yBaru = yT + GERAK.TinggiKaki + tinggiEkstra
                local naik = yBaru - h2.Position.Y
                if naik > GERAK.NaikMaksPerLangkah then
                    yBaru = h2.Position.Y + GERAK.NaikMaksPerLangkah
                end
                titik = Vector3.new(titik.X, yBaru, titik.Z)
            end
        end

        -- Perpindahan TOTAL per langkah dibatasi jatah kecepatan yang sama.
        -- Tanpa ini, menanjak ke ReturnHeight menambahkan komponen Y di atas
        -- jatah XZ yang sudah penuh; gabungannya bisa melewati ambang sentakan
        -- server (terukur mulai 233 stud di depan validasi).
        local geser = titik - h2.Position
        local jatah = math.min(kecepatan * dt, GERAK.LangkahMaks or math.huge)
        if geser.Magnitude > jatah then
            titik = h2.Position + geser.Unit * jatah
        end

        if jalanKaki then
            -- Berjalan sungguhan: server yang menggerakkan, jadi tidak ada yang
            -- bisa ditolak. Lebih lambat, tapi sampai -- dan tidak mati.
            local humJ = Player.Character
                and Player.Character:FindFirstChildOfClass("Humanoid")
            if humJ then
                humJ:Move(arah, false)
            end
            tulisTerakhir = nil
        else
            h2.AssemblyLinearVelocity = Vector3.zero
            h2.CFrame = CFrame.new(titik) * (h2.CFrame - h2.CFrame.Position)
            tulisTerakhir = titik
        end
    end

    sedangTerbang = false
    _G.SaeSedangTerbang = false
    return hasil, alasan
end

-- Nama lama dipertahankan supaya seluruh pemanggil di berkas ini tidak putus.
local function terbangKe(posisi, durasi, keTanah)
    local ok = luncurKe(posisi, 8)
    return ok == true
end
local function terbangNaik()
    return true
end
local function terbangHorizontal(targetXZ)
    local ok = luncurKe(targetXZ, 6)
    return ok == true
end
local teleportKe = terbangKe
local function tahanPosisi(posisi, keTanah) end
local function lepasTahan() end

-- Treadmill sering menangkap karakter yang melintas. CanTouch dan CanCollide
-- dimatikan selama mencuri, lalu dikembalikan.
local treadmillAsli = {}
local function aturTreadmill(matikan)
    if not GERAK.MatikanTreadmill then return end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        for _, o in ipairs(plot:GetChildren()) do
            if o.Name:lower():find("treadmill") then
                local daftar = o:IsA("BasePart") and { o } or o:GetDescendants()
                for _, part in ipairs(daftar) do
                    if part:IsA("BasePart") then
                        if matikan then
                            if treadmillAsli[part] == nil then
                                treadmillAsli[part] = { part.CanTouch, part.CanCollide }
                            end
                            part.CanTouch = false
                            part.CanCollide = false
                        else
                            local a = treadmillAsli[part]
                            if a then
                                part.CanTouch = a[1]
                                part.CanCollide = a[2]
                            end
                        end
                    end
                end
            end
        end
    end
    if not matikan then treadmillAsli = {} end
end
getgenv().SAEAturTreadmill = aturTreadmill

local function titikSpawn()
    local sp = workspace:FindFirstChild("SpawnLocation")
    return sp and sp.Position or nil
end

-- Turun ke tanah di tempat. Dipakai setelah pulang melayang supaya kita tidak
-- menggantung, dan supaya pemeriksaan batas plot tidak gagal gara-gara Y.
local function mendarat()
    aturPulangTinggi(false)
    local h = akar()
    if not h then return end
    local yT = tinggiTanah(h.Position.X, h.Position.Z, h.Position.Y)
    if not yT then return end
    luncurKe(Vector3.new(h.Position.X, yT + GERAK.TinggiKaki, h.Position.Z), 3)
end

-- Rute lewat lane tengah: masuk jalur, maju lurus, baru belok ke sasaran.
local function lewatLane(tujuan, tinggiEkstra)
    if not GERAK.PakaiLane then
        return luncurKe(tujuan, 8, tinggiEkstra)
    end
    local h = akar()
    if not h then return false, "karakter hilang" end

    -- Sasaran di SISI AMAN (X < 552, di belakang SeparationLine).
    --
    -- Dua keadaan berbeda:
    --   a. Kita juga sudah di sisi aman -> langsung saja. Memakai lane di sini
    --      memaksa mampir SpawnLocation lalu masuk jalur dulu: itulah
    --      "muter-muter di savezone", dan tiap detik itu dihabiskan sambil
    --      masih menggenggam egg.
    --   b. Kita masih di DALAM arena -> susuri lane keluar dulu, baru lurus.
    --      Menembak lurus dari dalam arena ke base memotong wilayah guard.
    if tujuan.X < 548 then
        if h.Position.X < 548 then
            return luncurKe(tujuan, 8, tinggiEkstra)
        end
        if math.abs(h.Position.Z - GERAK.LaneZ) > 6 then
            local xM = math.clamp(h.Position.X, GERAK.LaneXMin, GERAK.LaneXMaks)
            local okM = luncurKe(Vector3.new(xM, h.Position.Y, GERAK.LaneZ), 8, tinggiEkstra)
            if not okM then return false, "gagal masuk lane saat pulang" end
        end
        local hk = akar()
        if hk then
            local okK = luncurKe(Vector3.new(GERAK.LaneXMin - 20, hk.Position.Y, GERAK.LaneZ), 12, tinggiEkstra)
            if not okK then return false, "gagal keluar lane saat pulang" end
        end
        return luncurKe(tujuan, 8)
    end

    -- JANGAN mampir SpawnLocation. Terukur 2026-08-21: SpawnLocation ada di
    -- X=513, yaitu tepat di petak base tempat treadmill berdiri. Mampir ke sana
    -- berarti tiap putaran steal kita menaruh diri sendiri di atas treadmill
    -- lebih dulu, lalu tersangkut di sana -- karakter lari di tempat sementara
    -- script mengira sedang menuju arena. Perekam menangkapnya tiga kali macet
    -- 2,1 detik di X=522 dan X=551, keduanya di sekitar base.
    --
    -- Yang benar: langsung ke MULUT LANE, yang berada di sumbu Z lane dan jauh
    -- dari petak mana pun.
    if h.Position.X < GERAK.LaneXMin - 5
        and math.abs(h.Position.Z - GERAK.LaneZ) > 30 then
        local mulut = Vector3.new(GERAK.LaneXMin, h.Position.Y, GERAK.LaneZ)
        if not luncurKe(mulut, 10) then
            return false, "gagal ke mulut lane"
        end
    end

    h = akar() or h
    local xMasuk = math.clamp(h.Position.X, GERAK.LaneXMin, GERAK.LaneXMaks)
    if math.abs(h.Position.Z - GERAK.LaneZ) > 6 then
        local ok, sebab = luncurKe(Vector3.new(xMasuk, h.Position.Y, GERAK.LaneZ), 8, tinggiEkstra)
        if not ok then return false, "gagal masuk lane: " .. tostring(sebab) end
    end

    local xSasaran = math.clamp(tujuan.X, GERAK.LaneXMin, GERAK.LaneXMaks)
    local hh = akar()
    if hh and math.abs(hh.Position.X - xSasaran) > 8 then
        local ok, sebab = luncurKe(Vector3.new(xSasaran, hh.Position.Y, GERAK.LaneZ), 8, tinggiEkstra)
        if not ok then return false, "gagal susur lane: " .. tostring(sebab) end
    end

    return luncurKe(tujuan, 8)
end

local function kembaliKeLane()
    if not GERAK.PakaiLane then return end
    local h = akar()
    if not h then return end
    -- Sudah di sisi aman? Tidak ada gunanya balik ke jalur arena.
    if h.Position.X < 548 then return end
    if math.abs(h.Position.Z - GERAK.LaneZ) > 6 then
        local x = math.clamp(h.Position.X, GERAK.LaneXMin, GERAK.LaneXMaks)
        luncurKe(Vector3.new(x, h.Position.Y, GERAK.LaneZ), 8)
    end
end

-- Jejak diagnostik: angka `sisa=` memisahkan "sampai", "mati di jalan", dan
-- "terlalu lambat" tanpa perlu menebak.
local function catatJejak(areaId, jarakAwal, lama, sisa, hasil)
    local d = _G.__EggJejakHalus
    if type(d) ~= "table" then
        d = {}
        _G.__EggJejakHalus = d
    end
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    d[#d + 1] = string.format("%s|%.0fstud|%.1fs|sisa=%.0f|ws=%.0f|%s",
        tostring(areaId), jarakAwal, lama, sisa, hum and hum.WalkSpeed or -1, hasil)
    while #d > 60 do
        table.remove(d, 1)
    end
end

local function jalanKe(posisi, areaId, paksaPintu)
    local hrpAwal = akar()
    local jarakAwal = hrpAwal and (hrpAwal.Position - posisi).Magnitude or -1
    local mulaiJalan = os.clock()

    local ok, alasan = lewatLane(posisi)

    local h = akar()
    catatJejak(areaId, jarakAwal, os.clock() - mulaiJalan,
        h and (h.Position - posisi).Magnitude or -1,
        ok and "SAMPAI" or ("GAGAL: " .. tostring(alasan)))
    return ok
end
getgenv().SAEKembaliKeLane = kembaliKeLane


local Areas = workspace.__OBJECTS.Areas
local SepLine = Areas:FindFirstChild("SeparationLine")
sisiAman = function(posisi)
    if not SepLine then
        return true
    end
    return (posisi - SepLine.Position):Dot(SepLine.CFrame.LookVector.Unit) < 0
end
local function titikAman(dari)
    if not SepLine then
        return dari
    end
    local n = SepLine.CFrame.LookVector.Unit
    local r = SepLine.CFrame.RightVector.Unit
    local rel = dari - SepLine.Position
    local sepanjang = math.clamp(rel:Dot(r), -(SepLine.Size.X / 2 - 6), SepLine.Size.X / 2 - 6)
    return SepLine.Position + r * sepanjang - n * Config.MarginAman + Vector3.new(0, 3, 0)
end
local syaratCache = {}
resetSyarat = function()
    syaratCache = {}
end
local function syaratKabur(areaId)
    if syaratCache[areaId] ~= nil then
        return syaratCache[areaId]
    end
    local hasil = false -- false = tak terhitung; dibedakan dari angka
    local ga = Areas:FindFirstChild("GuardAreas")
    local area = ga and areaId and ga:FindFirstChild(areaId)
    local cfg = area and Guards.Directory[areaId]
    local bounds = area and area:FindFirstChild("Bounds")
    local cep = area and area:FindFirstChild("ClosestExitPoint")
    local guard = area and area:FindFirstChild("Guard")
    if cfg and bounds and cep and guard and SepLine then
        local gp
        if guard:IsA("Model") then
            gp = guard:GetPivot().Position
        elseif guard:IsA("BasePart") then
            gp = guard.Position
        end
        if not gp then
            local pp = guard:FindFirstChildWhichIsA("BasePart", true)
            gp = pp and pp.Position
        end
        if gp then
            local arah = -SepLine.CFrame.LookVector
            local okD, jarakKeluar = pcall(GEP.ResolveExitDistance, bounds.CFrame, bounds.Size, cep.Position, arah)
            local okH, jarakPukul = pcall(GCP.ResolveHitDistance, cfg.HitDistance)
            if okD and okH then
                local okR, minWS = pcall(GEP.ResolvePlayerWalkSpeedRequirement, {
                    BaseGuardWalkSpeed = cfg.WalkSpeed,
                    ExitDirection = arah,
                    ExitDistance = jarakKeluar,
                    FlatRadius = cfg.FlatRadius,
                    GuardStartPosition = gp,
                    HitDistance = jarakPukul,
                    PlayerStartPosition = cep.Position,
                }, 1)
                if okR and type(minWS) == "number" then
                    hasil = minWS
                end
            end
        end
    end
    syaratCache[areaId] = hasil
    return hasil
end
local function kecepatanSanggup(hum)
    -- WalkSpeed HIDUP lebih dulu, bukan speedDasar yang di-cache: nilai cache
    -- cepat basi karena speed di SAE tumbuh terus, dan memakainya membuat
    -- gerbang kabur menilai kita lebih lambat daripada kenyataan.
    local dasar = (hum and hum.WalkSpeed) or speedDasar or 16
    if Config.PakaiSpeedBoost then
        return (dasar * 1.22 + 8) * Config.MarginSpeed
    end
    return dasar
end
sanggupKabur = function(areaId, hum)
    if areaId and Config.AreaDilarang and Config.AreaDilarang[areaId] then
        return false
    end
    if not Config.PakaiGerbangKabur then
        return true
    end
    local syarat = syaratKabur(areaId)
    if syarat == false then
        return true
    end
    return kecepatanSanggup(hum) >= syarat * Config.MarginKabur
end
guardBangun = function(areaId)
    local ga = Areas:FindFirstChild("GuardAreas")
    local area = ga and areaId and ga:FindFirstChild(areaId)
    local guard = area and area:FindFirstChild("Guard")
    if not guard then
        return true
    end
    local ok, keadaan = pcall(function()
        return guard:GetAttribute("GuardState")
    end)
    if not ok or keadaan == nil then
        return true
    end
    return keadaan ~= "Sleeping"
end
exitPoint = function(areaId)
    local ga = Areas:FindFirstChild("GuardAreas")
    local area = ga and areaId and ga:FindFirstChild(areaId)
    local p = area and area:FindFirstChild("ClosestExitPoint")
    return p and p.Position or nil
end
local function catatSpeedDasar(hum)
    if hum and not sedangBoost then
        speedDasar = hum.WalkSpeed
    end
end
local function pasangBoost(hum, nyala)
    -- SENGAJA tidak melakukan apa-apa.
    --
    -- Fitur ini menulis Humanoid.WalkSpeed, padahal game punya loop sendiri
    -- yang menimpanya balik (terukur: diset 197, 1,5 detik kemudian 208 lagi)
    -- dan speed di SAE tumbuh serta meluruh sendiri. Lebih buruk, saat
    -- dimatikan ia mengembalikan `speedDasar` yang sudah basi sehingga
    -- menurunkan speed pemain tiap siklus.
    --
    -- Tidak cukup mengubah default jadi false: config tersimpan pemain berisi
    -- PakaiSpeedBoost = true dan menimpa default itu. Jadi penolakannya
    -- dipasang di sini, bukan di tabel Config.
    do return end
    -- luacheck: ignore
    if not hum or not Config.PakaiSpeedBoost then
        return
    end
    if nyala then
        local dasar = speedDasar or hum.WalkSpeed
        hum.WalkSpeed = (dasar * 1.22 + 8) * Config.MarginSpeed
        sedangBoost = true
    else
        sedangBoost = false
        if speedDasar then
            hum.WalkSpeed = speedDasar
        end
    end
end
-- Kabur ke sisi aman.
--
-- Versi lama berputar tiga kali (naik -> horizontal -> turun -> menjejak tanah)
-- dan berakhir dengan hum:MoveTo() -- itulah "muter-muter di savezone" dan
-- "baliknya lari". Sekarang: balik ke lane, lalu susuri lane keluar arena.
-- Tidak ada MoveTo di mana pun; semua lewat mesin luncur yang sama.
local function lariKeAman(areaId)
    kembaliKeLane()
    local h = akar()
    if not h then return false end
    -- X di bawah 552 = sudah di luar arena (garis SeparationLine ada di 552).
    if h.Position.X <= 548 then return true end
    local ok = luncurKe(Vector3.new(GERAK.LaneXMin - 20, h.Position.Y, GERAK.LaneZ), 12)
    return ok == true
end

-- Antar egg ke base.
--
-- Langsung ke CenterPoint plot lewat lane, tanpa MoveTo dan tanpa mampir
-- ke mana-mana: memegang egg terlalu lama itu yang mengundang guard.
-- `paksa` dipakai saat kita TERLANJUR menggenggam egg: mengantar pulang adalah
-- satu-satunya cara menyimpannya, dan menyerah di situ berarti egg tergenggam
-- selamanya sehingga seluruh putaran berikutnya ditolak server.
local function bankKeBase(paksa)
    if not Config.BankKeBase and not paksa then
        -- Setelan mati: egg tidak diantar ke base. Kepergian dari sarang sudah
        -- ditangani pemanggil, jadi di sini cukup berhenti tanpa menahan alur.
        return true
    end
    local ok, slot = pcall(PlotCmds.GetMySlot)
    if not ok or slot == nil then
        log("slot base tak terbaca")
        return false
    end
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(tostring(slot))
    local titik = plot and (plot:FindFirstChild("CenterPoint") or plot:FindFirstChild("SpawnPoint"))
    if not titik then
        log("CenterPoint base tak ketemu (slot " .. tostring(slot) .. ")")
        return false
    end

    -- lewatLane sudah menangani "balik ke jalur dulu" sendiri; memanggil
    -- kembaliKeLane di sini membuat perjalanan terpecah jadi ruas tambahan,
    -- dan tiap batas ruas itu terlihat sebagai berhenti sejenak.
    -- Pulang melayang di atas tanah: trap terpasang di permukaan, dan kita
    -- sedang menggenggam egg -- kena trap di sini paling mahal akibatnya.
    local tinggi = GERAK.PulangLewatAtas
        and math.clamp(tonumber(Config.ReturnHeight) or 25, 8, 60) or 0
    lewatLane(titik.Position, tinggi)

    -- Turun ke tanah setelah sampai. Tanpa ini kita menggantung setinggi
    -- ReturnHeight di atas CenterPoint, dan pemeriksaan batas plot di bawah
    -- bisa gagal hanya gara-gara ketinggian.
    if tinggi > 0 then
        luncurKe(titik.Position, 8, 0)
    end

    for _ = 1, 12 do
        local h = akar()
        local okI, di = pcall(PlotCmds.IsWorldPositionWithinLocalPlotBounds, h and h.Position)
        if okI and di == true then
            return true
        end
        task.wait(0.05)
    end
    return false
end
local function picu(prompt, cara, uid)
    if prompt == nil then
        if cara ~= 4 then
            return nil
        end
        local ok, berhasil, alasan = pcall(EggCmds.RequestCarryAreaEgg, uid, nil)
        if ok and berhasil then
            return "remote"
        end
        return nil, (ok and tostring(alasan) or "invoke gagal")
    end
    if Config.PaksaEnable then
        pcall(function()
            prompt.Enabled = true
        end)
    end
    local tahan = (prompt.HoldDuration or 1.2)
    if cara == 1 then
        local fpp = fireproximityprompt
        if type(fpp) == "function" and pcall(fpp, prompt) then
            return "fireproximityprompt"
        end
        return nil
    elseif cara == 2 then
        local ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(tahan + 0.35)
            prompt:InputHoldEnd()
        end)
        return ok and "InputHold" or nil
    elseif cara == 3 then
        local fpp = fireproximityprompt
        if type(fpp) == "function" and pcall(fpp, prompt, tahan) then
            return "fireproximityprompt+durasi"
        end
        return nil
    else
        local ok, berhasil, alasan = pcall(EggCmds.RequestCarryAreaEgg, uid, nil)
        if ok and berhasil then
            return "remote"
        end
        return nil, (ok and tostring(alasan) or "invoke gagal")
    end
end
local function tungguPromptSiap(rec, batas)
    local mulai = os.clock()
    local pernahAda = false
    while os.clock() - mulai < batas do
        local h = akar()
        if not h then
            return nil, "karakter hilang"
        end
        local d = (h.Position - rec.BottomCFrame.Position).Magnitude
        if d > 8 then
            return nil, string.format("gerak gagal — masih %.0f stud dari egg", d)
        end
        local p = promptUntuk(rec)
        if p then
            pernahAda = true
            if p.Enabled then
                return p, "siap"
            end
            if Config.PaksaEnable then
                local ok = pcall(function()
                    p.Enabled = true
                end)
                if ok and p.Enabled then
                    return p, "dipaksa"
                end
            end
        end
        task.wait(0.1)
    end
    return nil, pernahAda and "ada tapi tak pernah enabled" or "prompt tak pernah muncul"
end
local function terambil(uid)
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return false
    end
    for _, rec in pairs(snap.Records) do
        if rec.Uid == uid then
            return rec.State ~= "Slot" and rec.State ~= "Dropped"
        end
    end
    return true
end
local PlotCmds2 = PlotCmds
local statusSteal = { adaSasaran = false, sibuk = false }
local function setelan(kunci)
    local g = getgenv().SAEConfig
    if type(g) == "table" and g[kunci] ~= nil then
        return g[kunci]
    end
    return Config[kunci]
end
local function plotAsal()
    local ok, data = pcall(PlotCmds2.GetPlotData)
    if not ok or type(data) ~= "table" or not data.CenterPoint then
        return nil
    end
    local cp = data.CenterPoint
    return cp:IsA("BasePart") and cp.CFrame or cp:GetPivot()
end
local function recordKu()
    local ok, rec = pcall(EggCmds.GetOwnerRuntimeRecords, Player.UserId)
    return (ok and type(rec) == "table") and rec or {}
end
local function titikTanamKosong(rec)
    local asal = plotAsal()
    if not asal then
        return nil
    end
    local dipakai = {}
    for _, r in pairs(rec) do
        if r.Placement and r.Placement.LocalCFrame then
            dipakai[#dipakai + 1] = r.Placement.LocalCFrame.Position
        end
    end
    for cincin = 1, Config.HatchCincin do
        local radius = Config.HatchRadiusAwal + (cincin - 1) * Config.HatchJarakCincin
        local titik = math.max(8, math.floor(radius))
        for i = 0, titik - 1 do
            local sudut = (i / titik) * math.pi * 2
            local kandidat = Vector3.new(math.cos(sudut) * radius, -0.5, math.sin(sudut) * radius)
            local kosong = true
            for _, p in ipairs(dipakai) do
                if (p - kandidat).Magnitude < Config.HatchJarakAntar then
                    kosong = false
                    break
                end
            end
            if kosong and PlotCmds2.IsWorldPositionWithinLocalPlotBounds((asal * CFrame.new(kandidat)).Position) then
                return CFrame.new(kandidat)
            end
        end
    end
    return nil
end
local Net2 = require(RS.Library.Client.Network)
local function petDiBackpack()
    local daftar = {}
    local wadah = { Player.Backpack, Player.Character }
    for _, w in ipairs(wadah) do
        for _, t in ipairs(w and w:GetChildren() or {}) do
            if t:IsA("Tool") and t:GetAttribute("ItemType") == "Asset" then
                local cfg = t:FindFirstChild("Configuration")
                daftar[#daftar + 1] = {
                    tool = t,
                    uid = t:GetAttribute("UID"),
                    kategori = t:GetAttribute("Category"),
                    favorit = t:GetAttribute("Favorite") == true,
                    perSecond = cfg and cfg:GetAttribute("perSecond") or nil,
                }
            end
        end
    end
    return daftar
end
local function jualPet(p)
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not p.uid then
        return false
    end
    pcall(function()
        hum:EquipTool(p.tool)
    end)
    local tEquip = os.clock()
    while os.clock() - tEquip < 0.5 do
        if p.tool.Parent == Player.Character then
            break
        end
        task.wait()
    end
    pcall(Net2.Fire, "AssetInventory: SellAsset", { p.uid })
    local mulai = os.clock()
    while os.clock() - mulai < 2 do
        if not p.tool.Parent then
            return true
        end
        task.wait(0.03)
    end
    return false
end
local function jualPetSekali(maks)
    local filter = setelan("JualPetFilter")
    local kandidat = {}
    for _, p in ipairs(petDiBackpack()) do
        if not p.favorit and p.uid then
            local layak = false
            if filter == "money" then
                layak = type(p.perSecond) == "number"
                    and p.perSecond < setelan("JualPetMinPerSecond")
            else
                local angka = nilaiRarity(p.kategori)
                layak = angka >= 1 and angka <= setelan("JualPetMaksRarity")
            end
            if layak then
                kandidat[#kandidat + 1] = p
            end
        end
    end
    local terjual = 0
    for i = 1, math.min(maks, #kandidat) do
        if statusSteal.adaSasaran or statusSteal.sibuk then
            break
        end
        if jualPet(kandidat[i]) then
            terjual = terjual + 1
            log(string.format("jual pet %s (perSecond=%s)",
                tostring(kandidat[i].kategori), tostring(kandidat[i].perSecond)))
        else
            log("gagal menjual pet " .. tostring(kandidat[i].kategori) .. ", berhenti")
            break
        end
    end
    if terjual > 0 then
        local ch = Player.Character
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                h:UnequipTools()
            end)
        end
    end
    return terjual, #kandidat
end
getgenv().SAEJualPet = jualPetSekali
local FuseUtil = select(2, pcall(require, RS.Library.Util.FuseKernelUtil))
local function petUntukFuse()
    local layak = {}
    for _, p in ipairs(petDiBackpack()) do
        local angka = nilaiRarity(p.kategori)
        local bermutasi = p.tool:GetAttribute("Mutations")
        bermutasi = type(bermutasi) == "string" and bermutasi ~= ""
        if not p.favorit and p.uid
            and angka >= 1 and angka <= setelan("FuseMaksRarity")
            and not (setelan("FuseLewatiMutasi") and bermutasi)
        then
            local boleh = true
            if type(FuseUtil) == "table" and type(FuseUtil.CanSelectPet) == "function" then
                local ok, hasil = pcall(FuseUtil.CanSelectPet, p.tool)
                if ok and hasil == false then
                    boleh = false
                end
            end
            if boleh then
                layak[#layak + 1] = p
            end
        end
    end
    local grup = {}
    for _, p in ipairs(layak) do
        local k = tostring(p.kategori)
        grup[k] = grup[k] or {}
        table.insert(grup[k], p)
    end
    local pilihan
    for _, anggota in pairs(grup) do
        if #anggota >= 3 then
            table.sort(anggota, function(a, b)
                return (a.perSecond or 0) < (b.perSecond or 0)
            end)
            local nilai = (anggota[1].perSecond or 0) + (anggota[2].perSecond or 0)
                + (anggota[3].perSecond or 0)
            if not pilihan or nilai < pilihan.nilai then
                pilihan = { anggota = anggota, nilai = nilai }
            end
        end
    end
    return pilihan and pilihan.anggota or {}
end
local function fuseSekali()
    local layak = petUntukFuse()
    if #layak < 3 then
        return false, "tak ada 3 pet sejenis yang layak"
    end
    local dimasukkan = {}
    for i = 1, 3 do
        local ok, berhasil, sebab = pcall(Net2.Invoke, "FuseMachine: InsertMob", layak[i].uid)
        if ok and berhasil == true then
            dimasukkan[#dimasukkan + 1] = layak[i]
        else
            for _, m in ipairs(dimasukkan) do
                pcall(Net2.Invoke, "FuseMachine: RemoveMob", m.uid)
            end
            return false, "InsertMob ditolak: " .. tostring(sebab)
        end
        task.wait(Config.FuseJedaMasuk)
    end
    local ok2, berhasil2, sebab2, hasil = pcall(Net2.Invoke, "FuseMachine: StartFuse")
    if not ok2 or berhasil2 ~= true then
        for _, m in ipairs(dimasukkan) do
            pcall(Net2.Invoke, "FuseMachine: RemoveMob", m.uid)
        end
        return false, "StartFuse ditolak: " .. tostring(sebab2)
    end
    task.wait(Config.FuseJedaReveal)
    pcall(Net2.Invoke, "FuseMachine: CompleteReveal")
    local dapat = type(hasil) == "table" and tostring(hasil.AssetCategory) or "?"
    log(string.format("fuse: %s + %s + %s -> %s",
        tostring(dimasukkan[1].kategori), tostring(dimasukkan[2].kategori),
        tostring(dimasukkan[3].kategori), dapat))
    return true, dapat
end
getgenv().SAEFuse = fuseSekali
local function equipBest()
    local pg = Player:FindFirstChild("PlayerGui")
    local f = pg and pg:FindFirstChild("PetList")
    f = f and f:FindFirstChild("Frame")
    local btn = f and f:FindFirstChild("EquipBest")
    if not btn then
        return false, "tombol EquipBest tidak ada"
    end
    if type(firesignal) == "function" then
        local ok = pcall(firesignal, btn.Activated)
        if ok then
            return true
        end
        pcall(firesignal, btn.MouseButton1Click)
        return true
    elseif type(getconnections) == "function" then
        for _, c in ipairs(getconnections(btn.Activated)) do
            if c.Function then
                pcall(c.Function)
            end
        end
        return true
    end
    return false, "executor tanpa firesignal/getconnections"
end
getgenv().SAEEquipBest = equipBest
local Lighting = game:GetService("Lighting")
local function matikanEfek(d)
    if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
        or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
        or d:IsA("Sound") or d:IsA("Explosion")
        or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance")
    then
        pcall(function()
            d:Destroy()
        end)
        return true
    elseif d:IsA("SpecialMesh") then
        pcall(function()
            d.TextureId = ""
        end)
        return true
    elseif d:IsA("BasePart") then
        pcall(function()
            d.CastShadow = false
            d.Reflectance = 0
            d.Material = Enum.Material.SmoothPlastic
            if d:IsA("MeshPart") then
                d.RenderFidelity = Enum.RenderFidelity.Performance
                d.TextureID = ""
            end
            if not (Player.Character and d:IsDescendantOf(Player.Character)) then
                d.Color = Color3.fromRGB(128, 132, 138)
            end
        end)
        return true
    end
    return false
end
local function buangKarakterLain()
    local n = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        local ch = pl ~= Player and pl.Character
        if ch then
            n = n + 1
            for _, d in ipairs(ch:GetDescendants()) do
                if d:IsA("Accessory") or d:IsA("Decal") or d:IsA("Texture")
                    or d:IsA("ParticleEmitter") or d:IsA("Trail")
                then
                    pcall(function()
                        d:Destroy()
                    end)
                elseif d:IsA("BasePart") then
                    pcall(function()
                        d.Transparency = 1
                        d.CastShadow = false
                    end)
                end
            end
            local h = ch:FindFirstChildOfClass("Humanoid")
            local anim = h and h:FindFirstChildOfClass("Animator")
            if anim then
                for _, tr in ipairs(anim:GetPlayingAnimationTracks()) do
                    pcall(function()
                        tr:Stop(0)
                    end)
                end
            end
        end
    end
    return n
end
local boostTerpasang = false
local function boostFps()
    local dibuang = { efek = 0, plot = 0, eggTaman = 0, render = 0, karakter = 0 }
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 1
    end)
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") or e:IsA("Atmosphere") or e:IsA("Clouds") then
            pcall(function()
                e:Destroy()
            end)
        end
    end
    pcall(function()
        local t = workspace.Terrain
        t.WaterWaveSize, t.WaterWaveSpeed, t.WaterReflectance = 0, 0, 0
        t.Decoration = false
    end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    local cra = workspace:FindFirstChild("ClientRenderedAssets")
    if cra then
        dibuang.render = #cra:GetDescendants()
        pcall(function()
            cra:Destroy()
        end)
    end
    local slotKu = tostring(select(2, pcall(PlotCmds2.GetMySlot)))
    local plots = workspace:FindFirstChild("Plots")
    if plots and slotKu ~= "nil" then
        for _, p in ipairs(plots:GetChildren()) do
            if p.Name ~= slotKu then
                dibuang.plot = dibuang.plot + 1
                pcall(function()
                    p:Destroy()
                end)
            end
        end
    end
    for _, f in ipairs(workspace:GetChildren()) do
        if f.Name == "PlacedEggRenders" then
            for _, d in ipairs(f:GetDescendants()) do
                if d:IsA("BasePart") then
                    dibuang.eggTaman = dibuang.eggTaman + 1
                    pcall(function()
                        d.Transparency = 1
                        d.CastShadow = false
                    end)
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    pcall(function()
                        d.Transparency = 1
                    end)
                end
            end
        end
    end
    for _, nama in ipairs({ "Stands", "Giftbox", "Dragons", "ObjectCache",
                            "_MultiPhotoboothExports", "__ClientTreadmillRenders",
                            "__DEBRIS", "ClientRenderedAssets" })
    do
        for _, f in ipairs(workspace:GetChildren()) do
            if f.Name == nama then
                dibuang.render = dibuang.render + #f:GetDescendants()
                pcall(function()
                    f:Destroy()
                end)
            end
        end
    end
    dibuang.karakter = buangKarakterLain()
    local OBJ = workspace:FindFirstChild("__OBJECTS")
    local ESP = workspace:FindFirstChild("__SAE_ESP")
    for _, d in ipairs(workspace:GetDescendants()) do
        if not (OBJ and d:IsDescendantOf(OBJ)) and not (ESP and d:IsDescendantOf(ESP)) then
            if matikanEfek(d) then
                dibuang.efek = dibuang.efek + 1
            end
        end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= Player and pl.Character then
            local h = pl.Character:FindFirstChildOfClass("Humanoid")
            local anim = h and h:FindFirstChildOfClass("Animator")
            if anim then
                for _, tr in ipairs(anim:GetPlayingAnimationTracks()) do
                    pcall(function()
                        tr:Stop(0)
                    end)
                end
            end
        end
    end
    if not boostTerpasang then
        boostTerpasang = true
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= Player then
                pl.CharacterAdded:Connect(function()
                    if setelan("BoostFps") then
                        task.delay(1, buangKarakterLain)
                    end
                end)
            end
        end
        Players.PlayerAdded:Connect(function(pl)
            pl.CharacterAdded:Connect(function()
                task.wait(0.5)
                modifikasiHRP()
                if setelan("BoostFps") then
                    task.delay(1, buangKarakterLain)
                end
            end)
        end)
        workspace.DescendantAdded:Connect(function(d)
            if not setelan("BoostFps") then
                return
            end
            if OBJ and d:IsDescendantOf(OBJ) then
                return
            end
            task.defer(matikanEfek, d)
        end)
        task.spawn(function()
            while true do
                task.wait(Config.BoostFpsSapuTiap)
                if setelan("BoostFps") then
                    buangKarakterLain()
                    for _, d in ipairs(workspace:GetDescendants()) do
                        if d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Trail")
                            or d:IsA("Beam") or d:IsA("Decal") or d:IsA("Texture")
                            or d:IsA("SpecialMesh") or d:IsA("MeshPart")
                        then
                            local esp = workspace:FindFirstChild("__SAE_ESP")
                            if not (OBJ and d:IsDescendantOf(OBJ))
                                and not (esp and d:IsDescendantOf(esp))
                            then
                                matikanEfek(d)
                            end
                        end
                    end
                end
            end
        end)
    end
    log(string.format("boost fps: %d efek dimatikan, %d plot dihapus, "
        .. "%d part egg taman diinvis, %d aset render, %d karakter lain disembunyikan",
        dibuang.efek, dibuang.plot, dibuang.eggTaman, dibuang.render, dibuang.karakter))
    return dibuang
end
getgenv().SAEBoostFps = boostFps
local function daftarTumbuh()
    local siap, tumbuh, simpan = {}, {}, 0
    for uid, r in pairs(recordKu()) do
        if r.Placement ~= nil then
            local angka, nama = nilaiRarity(r.AssetCategory)
            local baris = { uid = uid, kategori = tostring(r.AssetCategory),
                            rarity = angka, rarityNama = nama }
            if EggCmds.IsLocalEggReady(uid) then
                siap[#siap + 1] = baris
            else
                tumbuh[#tumbuh + 1] = baris
            end
        else
            simpan = simpan + 1
        end
    end
    return siap, tumbuh, simpan
end
getgenv().SAEDaftarTumbuh = daftarTumbuh
local function tetaskan(uid)
    if not EggCmds.IsLocalEggReady(uid) then
        return false, "belum siap"
    end
    local ok1, b1, s1 = pcall(EggCmds.RequestHatchEgg, uid)
    if not ok1 or b1 ~= true then
        return false, tostring(s1 or "hatch ditolak")
    end
    task.wait(Config.HatchJedaBuka)
    local ok2, b2, s2 = pcall(EggCmds.RequestCompleteHatchEgg, uid)
    if not ok2 or b2 ~= true then
        return false, tostring(s2 or "complete ditolak")
    end
    return true
end
getgenv().SAETetaskan = tetaskan
getgenv().__HatchGen = (getgenv().__HatchGen or 0) + 1
local function loopHatch(generasi)
    while getgenv().__HatchGen == generasi do
        local siap, _, tersimpan = daftarTumbuh()
        local giliranHatch = not statusSteal.sibuk and not statusSteal.adaSasaran
        if setelan("AutoHatch") and giliranHatch then
            for _, e in ipairs(siap) do
                if getgenv().__HatchGen ~= generasi then
                    return
                end
                if statusSteal.adaSasaran or statusSteal.sibuk then
                    break
                end
                local ok, sebab = tetaskan(e.uid)
                log(string.format("tetas %s [%s] — %s", e.kategori, e.rarityNama,
                    ok and "berhasil" or tostring(sebab)))
                task.wait(Config.HatchJedaAntar)
            end
        end
        local giliranTanam = not statusSteal.sibuk and not statusSteal.adaSasaran
        if setelan("AutoTanam") and tersimpan > 0 and giliranTanam then
            local asal = plotAsal()
            if asal then
                local kembali = akar() and akar().Position or nil
                teleportKe(asal.Position, nil, true)
                task.wait(Config.HatchJedaTanam)
                local ditanam = 0
                while ditanam < setelan("TanamSekali")
                    and getgenv().__HatchGen == generasi
                    and not statusSteal.adaSasaran
                do
                    local rec = recordKu()
                    local lokal = titikTanamKosong(rec)
                    if not lokal then
                        log("taman penuh — tak ada titik tanam kosong")
                        break
                    end
                    local pilih
                    for uid, r in pairs(rec) do
                        if r.Placement == nil then
                            local a = nilaiRarity(r.AssetCategory)
                            if not pilih or a < pilih.angka then
                                pilih = { uid = uid, angka = a, kategori = tostring(r.AssetCategory) }
                            end
                        end
                    end
                    if not pilih then
                        break
                    end
                    local ok, berhasil, sebab = pcall(EggCmds.RequestPlaceEgg, pilih.uid, lokal)
                    if ok and berhasil == true then
                        ditanam = ditanam + 1
                        log(string.format("tanam %s [rarity %d]", pilih.kategori, pilih.angka))
                    else
                        log("gagal menanam: " .. tostring(sebab))
                        break
                    end
                    task.wait(Config.HatchJedaAntar)
                end
                if kembali and ditanam > 0 then
                    teleportKe(kembali, nil, true)
                end
            end
        end
        task.wait(Config.HatchJedaPutaran)
    end
end
getgenv().SAEMulaiHatch = function()
    getgenv().__HatchGen = (getgenv().__HatchGen or 0) + 1
    local g = getgenv().__HatchGen
    task.spawn(loopHatch, g)
    log("loop hatch jalan")
end
getgenv().SAEBerhentiHatch = function()
    getgenv().__HatchGen = (getgenv().__HatchGen or 0) + 1
    log("loop hatch berhenti")
end
local kameraTerkunci = false
local function kunciKamera(nyala)
    local cam = workspace.CurrentCamera
    if not cam then
        return false
    end
    if nyala then
        local ok = pcall(function()
            cam.CameraType = Enum.CameraType.Scriptable
        end)
        kameraTerkunci = ok
        return ok
    end
    pcall(function()
        cam.CameraType = Enum.CameraType.Custom
    end)
    kameraTerkunci = false
    return true
end
getgenv().SAEKunciKamera = kunciKamera
task.spawn(function()
    local generasi = getgenv().__EggGen
    while getgenv().__EggGen == generasi do
        local mau = setelan("KunciKamera") == true
        local cam = workspace.CurrentCamera
        if mau and cam and cam.CameraType ~= Enum.CameraType.Scriptable then
            kunciKamera(true)
        elseif not mau and kameraTerkunci then
            kunciKamera(false)
        end
        task.wait(2)
    end
end)
-- Anti AFK DIHAPUS: VirtualUser memicu BAC-5517 kick (terkonfirmasi 2026-08-17)
local ESP_FOLDER = "__SAE_ESP"
local function folderEsp()
    local f = workspace:FindFirstChild(ESP_FOLDER)
    if not f then
        f = Instance.new("Folder")
        f.Name = ESP_FOLDER
        f.Parent = workspace
    end
    return f
end
local function bersihkanEsp()
    local f = workspace:FindFirstChild(ESP_FOLDER)
    if f then
        f:Destroy()
    end
end
getgenv().SAEBersihkanEsp = bersihkanEsp
local WARNA_RARITY = {
    Color3.fromRGB(160, 168, 180), Color3.fromRGB(120, 200, 140),
    Color3.fromRGB(90, 170, 240),  Color3.fromRGB(170, 120, 240),
    Color3.fromRGB(240, 180, 60),  Color3.fromRGB(240, 90, 90),
    Color3.fromRGB(0, 230, 220),   Color3.fromRGB(255, 120, 220),
    Color3.fromRGB(150, 255, 120), Color3.fromRGB(255, 255, 255),
}
local function segarkanEsp()
    if not setelan("EspEgg") then
        bersihkanEsp()
        return
    end
    local pilih = setelan("EspRarity")
    if type(pilih) ~= "table" then
        pilih = {}
    end
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return
    end
    local f = folderEsp()
    local hidup = {}
    for _, rec in pairs(snap.Records) do
        local angka, nama = nilaiRarity(rec.AssetCategory)
        local dipilih = pilih[angka] == true or pilih[tostring(angka)] == true
        if (rec.State == "Slot" or rec.State == "Dropped") and dipilih
            and type(rec.Uid) == "string" and not rec.Uid:find("^FirstAreaEgg")
        then
            hidup[rec.Uid] = true
            local jangkar = f:FindFirstChild(rec.Uid)
            if not jangkar then
                jangkar = Instance.new("Part")
                jangkar.Name = rec.Uid
                jangkar.Size = Vector3.new(1, 1, 1)
                jangkar.Anchored = true
                jangkar.CanCollide = false
                jangkar.CanQuery = false
                jangkar.CanTouch = false
                jangkar.Transparency = 1
                jangkar.Parent = f
                local bb = Instance.new("BillboardGui")
                bb.Name = "Label"
                bb.Size = UDim2.fromOffset(190, 34)
                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                bb.AlwaysOnTop = true
                bb.MaxDistance = math.huge
                bb.Parent = jangkar
                local t = Instance.new("TextLabel")
                t.Size = UDim2.fromScale(1, 1)
                t.BackgroundTransparency = 1
                t.Font = Enum.Font.GothamBold
                t.TextSize = 13
                t.TextStrokeTransparency = 0.35
                t.Parent = bb
            end
            jangkar.CFrame = CFrame.new(rec.BottomCFrame.Position)
            local t = jangkar.Label.TextLabel
            t.Text = string.format("%s\n%s · %.0fkg%s", rec.AssetCategory, nama,
                beratEgg(rec), jumlahMutasi(rec) > 0 and " · mutasi" or "")
            t.TextColor3 = WARNA_RARITY[angka] or Color3.new(1, 1, 1)
        end
    end
    for _, c in ipairs(f:GetChildren()) do
        if not hidup[c.Name] then
            c:Destroy()
        end
    end
end
getgenv().__EspGen = (getgenv().__EspGen or 0) + 1
task.spawn(function()
    local g = getgenv().__EspGen
    while getgenv().__EspGen == g do
        pcall(segarkanEsp)
        task.wait(Config.EspSegarTiap)
    end
end)
local function hopServer()
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local placeId = game.PlaceId
    local kandidat = {}
    local ok, isi = pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100")
            :format(placeId)
        local minta = (syn and syn.request) or (http and http.request) or request or http_request
        if minta then
            return minta({ Url = url, Method = "GET" }).Body
        end
        return game:HttpGet(url)
    end)
    if ok and type(isi) == "string" then
        local ok2, data = pcall(function()
            return HttpService:JSONDecode(isi)
        end)
        if ok2 and type(data) == "table" and type(data.data) == "table" then
            for _, sv in ipairs(data.data) do
                if sv.playing and sv.maxPlayers and sv.playing < sv.maxPlayers
                    and sv.id ~= game.JobId
                then
                    kandidat[#kandidat + 1] = { id = sv.id, isi = sv.playing }
                end
            end
            -- Diurutkan dari yang PALING SEPI.
            --
            -- Versi lama mengambil kandidat acak asal belum penuh, jadi peluang
            -- mendarat di server ramai sama besarnya dengan yang sepi. Padahal
            -- maxPlayers di sini cuma 7, sehingga server berisi 1 orang banyak
            -- tersedia dan jauh lebih berharga -- makin sedikit pemain, makin
            -- sedikit egg yang direbut duluan.
            table.sort(kandidat, function(a, b) return a.isi < b.isi end)
        end
    end
    local gagalInit = false
    local conn
    pcall(function()
        conn = TeleportService.TeleportInitFailed:Connect(function()
            gagalInit = true
        end)
    end)
    -- Diacak HANYA kalau kita tidak sedang mengejar server sepi; kalau iya,
    -- urutan "paling sepi dulu" itu justru yang ingin kita pertahankan.
    if not Config.CariServerSepi then
        for i = #kandidat, 2, -1 do
            local j = math.random(1, i)
            kandidat[i], kandidat[j] = kandidat[j], kandidat[i]
        end
    end
    local jobKu = tostring(game.JobId)
    for i = 1, math.min(#kandidat, Config.HopMaksPercobaan) do
        gagalInit = false
        log(string.format("hop ke server %s… (%d, isi %s)",
            tostring(kandidat[i].id):sub(1, 8), i, tostring(kandidat[i].isi)))
        pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, kandidat[i].id, Player)
        end)
        local t = os.clock()
        while os.clock() - t < Config.HopTungguPindah do
            if gagalInit then
                break
            end
            task.wait(0.5)
        end
        if not gagalInit and tostring(game.JobId) ~= jobKu then
            if conn then conn:Disconnect() end
            return true
        end
        log("kandidat " .. i .. " tidak menerima — coba berikutnya")
    end
    if conn then conn:Disconnect() end
    log("semua kandidat gagal — teleport acak")
    pcall(function()
        TeleportService:Teleport(placeId, Player)
    end)
    return true
end
getgenv().SAEHop = hopServer

-- Cari server sampai cukup sepi.
--
-- Dijalankan sekali saat script mulai dan sesudah tiap perpindahan: kalau
-- jumlah pemain di server ini masih di atas batas, hop lagi. Diberi jeda 8
-- detik supaya tidak menghujani TeleportService dengan permintaan beruntun.
task.spawn(function()
    if not Config.CariServerSepi then return end
    local Players2 = game:GetService("Players")
    task.wait(5)
    for _ = 1, 12 do
        if not Config.CariServerSepi then return end
        local isi = #Players2:GetPlayers()
        if isi <= (Config.SendirianMaks or 1) then
            log(string.format("server sudah sepi (%d pemain) — berhenti mencari", isi))
            return
        end
        log(string.format("server berisi %d pemain, cari yang lebih sepi", isi))
        hopServer()
        task.wait(8)
    end
end)
getgenv().__HopGen = (getgenv().__HopGen or 0) + 1
getgenv().SAEMulaiHop = function()
    getgenv().__HopGen = (getgenv().__HopGen or 0) + 1
    local g = getgenv().__HopGen
    task.spawn(function()
        local sepiSejak = nil
        while getgenv().__HopGen == g do
            if statusSteal.adaSasaran or statusSteal.sibuk then
                sepiSejak = nil
            else
                sepiSejak = sepiSejak or os.clock()
                local batas = math.max(5, setelan("HopSepiDetik"))
                if os.clock() - sepiSejak >= batas then
                    log(string.format("sepi %d detik — pindah server", batas))
                    hopServer()
                    return -- teleport mengakhiri sesi ini; loop tidak perlu lanjut
                end
            end
            task.wait(1)
        end
    end)
    log("auto hop jalan: pindah setelah sepi "
        .. tostring(setelan("HopSepiDetik")) .. " detik")
end
getgenv().SAEBerhentiHop = function()
    getgenv().__HopGen = (getgenv().__HopGen or 0) + 1
    log("auto hop berhenti")
end
local GerbangZ = Areas:FindFirstChild("GameplayZ")
-- masukLewatGerbang DIBUANG. Sudah terbukti tidak diperlukan (strip x=553
-- boleh dilewati sambil meluncur) dan memanggilnya justru menciptakan
-- sentakan karena tiap percobaan gagal menerbangkan karakter balik ke
-- titik gerbang. Ia juga satu-satunya sisa pemakai hum:MoveTo().
-- Seberangi GameplayZ sungguhan sebelum menyambar.
--
-- Terukur 2026-08-21: GameplayZ adalah Part 2,5 x 1,0 x 136,4 di (553, 68, -366)
-- -- kotak setinggi SATU stud yang menempel permukaan. Luncuran kita menahan HRP
-- di ground + TinggiKaki (3,2 stud), jadi selama ini kita TERBANG MELEWATINYA
-- tanpa pernah berada di dalamnya, dan server menolak tiap carry dengan
-- "Enter the gameplay area first" -- 6 dari 7 sambaran gagal karena ini.
--
-- Dulu ada `masukLewatGerbang` yang mengurus hal ini; aku membuangnya dengan
-- alasan "strip x=553 boleh dilewati sambil meluncur". Itu keliru: yang boleh
-- dilewati sambil meluncur adalah SeparationLine (garis tipis di X=552, sekadar
-- penanda sisi), bukan GameplayZ yang merupakan pintu masuk sesungguhnya.
local function lewatiGerbangZ()
    local gz = GerbangZ
    if not gz or not gz:IsA("BasePart") then
        return true
    end
    local h = akar()
    if not h then
        return false
    end

    -- SUDAH DI DALAM? Jangan mundur ke gerbang lagi.
    --
    -- Terekam pada kecepatan tinggi: kita menulis (570,71) dan hasilnya selalu
    -- (562,68) -- dan 68 itu persis GameplayZ.Position.Y. Jadi yang menarik
    -- balik bukan server, melainkan rutin ini sendiri yang menahan posisi di
    -- kotak gerbang sementara mesin luncur mendorong maju. Pada 250 stud/dtk
    -- tarikannya kecil dan tak terasa; pada 1200 tiap frame melompat 20 stud,
    -- jadi pertengkarannya jadi kentara.
    if h.Position.X > gz.Position.X + 8 then
        return true
    end
    -- Tetap di rentang Z kotaknya, dengan margin supaya tidak menyerempet tepi.
    local setengahZ = gz.Size.Z / 2
    local z = math.clamp(h.Position.Z, gz.Position.Z - setengahZ + 8,
        gz.Position.Z + setengahZ - 8)
    local titik = Vector3.new(gz.Position.X, gz.Position.Y, z)

    -- Menempel tanah dimatikan sementara: justru ketinggian itu yang membuat
    -- kita tidak pernah masuk.
    local simpan = GERAK.MenempelTanah
    GERAK.MenempelTanah = false
    luncurKe(titik, 2)

    -- Ditahan sebentar DI DALAM kotak. Tebalnya cuma 2,5 stud, sementara pada
    -- 250 stud/dtk satu frame memindahkan ~4 stud -- melintas begitu saja bisa
    -- menembusnya di antara dua frame tanpa pernah tercatat berada di dalam.
    local sampai = os.clock() + 0.25
    while os.clock() < sampai do
        local hh = akar()
        if not hh then break end
        hh.AssemblyLinearVelocity = Vector3.zero
        hh.CFrame = CFrame.new(titik) * (hh.CFrame - hh.CFrame.Position)
        RunService.Heartbeat:Wait()
    end
    GERAK.MenempelTanah = simpan
    return true
end

-- Simpan egg yang ada di tangan.
--
-- MENYEBERANG KE ZONA AMAN SUDAH CUKUP: begitu melewati SeparationLine, egg
-- masuk kantong dengan sendirinya dan sesudah itu memang tidak bisa dijatuhkan
-- lagi. Jadi tidak ada yang perlu "dilepas", dan tidak perlu diantar sampai
-- CenterPoint plot -- perjalanan tambahan itu cuma menambah waktu menggenggam.
--
-- Jalur melepas (`RequestDropHeldAreaEgg`) SUDAH DIBUANG SELURUHNYA. Sempat
-- dipakai di dua tempat tepat sesudah sambaran berhasil, dan begitu
-- panggilannya dibetulkan (dulu `RequestUnequipTool` yang memang tidak
-- berfungsi), keduanya berubah jadi membuang setiap egg yang baru dicuri --
-- "drop egg terus-terusan padahal tidak ada apa-apa".
-- Dideklarasikan lebih dulu karena `serbuSebelumReset` di bawah memanggilnya,
-- sementara definisinya baru muncul ~60 baris kemudian. Tanpa ini ia terbaca
-- sebagai global nil dan meledak begitu Serbu Malam benar-benar berjalan.
local sambarSerempak

-- Sarang terbaik untuk DIKEMAHI, tanpa peduli sekarang ada isinya atau tidak.
--
-- Berbeda dari cariEggTerbaik yang hanya melihat egg yang bisa diambil DETIK
-- INI. Menjelang reset, sarang bagus justru sedang kosong -- dan itu tepat yang
-- ingin kita tunggui.
local function sarangTerbaik()
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return nil
    end
    local hrp = akar()
    if not hrp then return nil end
    local terbaik, skorTerbaik = nil, -1
    for _, rec in pairs(snap.Records) do
        if rec.BottomCFrame and rec.AreaId and not (Config.AreaDilarang or {})[rec.AreaId] then
            local angka = nilaiRarity(rec.AssetCategory)
            local berat = beratEgg(rec)
            local lolos = angka >= Config.MinRarity
                or ((Config.MinBeratKg or 0) > 0 and berat >= Config.MinBeratKg)
            if lolos then
                -- Rarity dulu, lalu yang paling dekat: jendelanya cuma 10 detik,
                -- jadi sarang jauh yang sedikit lebih bagus tetap kalah.
                local jarak = (hrp.Position - rec.BottomCFrame.Position).Magnitude
                local skor = angka * 10000 - jarak
                if skor > skorTerbaik then
                    skorTerbaik = skor
                    terbaik = rec
                end
            end
        end
    end
    return terbaik
end

-- Berangkat sebelum reset, lalu MENUNGGU di sarang.
--
-- Ini inti Serbu Malam, dan versi sebelumnya melewatkannya: menembus dinding
-- saja tidak cukup kalau kita baru berangkat setelah malam mulai. Jendelanya
-- 10 detik (`GetNightDurationSeconds`), sedangkan Prehistoric berjarak 2266
-- stud -- sekitar 9,5 detik pada 250 stud/dtk. Berangkat saat malam mulai
-- SELALU telat, dan egg keburu diambil orang.
--
-- Karena itu keberangkatan dihitung mundur dari `GetNextResetAt`: waktu tempuh
-- ditambah margin. Guard sudah diparkir, jadi menunggu di sarang tidak berisiko.
local function serbuSebelumReset(dilewati)
    if not Config.SerbuMalam or type(ResetUtil) ~= "table" then return false end
    if eggDipegang() then return false end

    local t = workspace:GetServerTimeNow()
    local okR, resetAt = pcall(ResetUtil.GetNextResetAt, t)
    if not okR or type(resetAt) ~= "number" then return false end
    local sisa = resetAt - t
    if sisa <= 0 or sisa > 40 then return false end

    local rec = sarangTerbaik()
    if not rec then return false end

    local h = akar()
    if not h then return false end
    local jarak = (h.Position - rec.BottomCFrame.Position).Magnitude
    -- Dipakai 200 stud/dtk, bukan 250: rute lewat lane tidak lurus, dan tiba
    -- kecepatan lebih baik daripada tiba telat.
    local perluDetik = jarak / 200 + 3

    if sisa > perluDetik then return false end

    log(string.format("SERBU — reset %.1f dtk lagi, %s %.0f stud (butuh %.1f dtk)",
        sisa, tostring(rec.AreaId), jarak, perluDetik))

    -- MENUNGGU DI MULUT GERBANG, bukan menerobos masuk lebih awal.
    --
    -- Selama 10 detik malam server MENGOSONGKAN arena: gerbangnya memang bisa
    -- ditembus, tapi karakter langsung dipaksa balik ke zona aman. Jadi masuk
    -- duluan mustahil, dan mencobanya cuma menghasilkan bolak-balik.
    --
    -- Justru itu menguntungkan: semua pemain dipaksa mulai dari garis yang
    -- sama, dan yang menang adalah yang paling cepat menyeberang PADA DETIK
    -- reset. Kita bisa berdiri tepat di mulut lane dan berangkat pada detik itu
    -- juga -- keunggulan yang tidak dimiliki pemain yang masih berlari dari
    -- base masing-masing.
    do
        -- Menunggu TEPAT DI BELAKANG garis, bukan jauh di zona aman.
        --
        -- Terekam 2026-08-22 selama jendela malam: server menjepit pemain di
        -- ambang pintu -- maju ke X 568..577, dikembalikan ke X 552..554,
        -- berulang 12 kali dalam 3,5 detik. Jadi arena benar-benar ditutup
        -- server, dan itu TIDAK BISA ditembus dari client (sudah dicoba:
        -- merobohkan dinding lewat ResetWall.Collapse, mematikan CanCollide-nya,
        -- bahkan mematikan anti-cheat Runtime_* -- jepitannya tetap jalan).
        --
        -- Yang bisa kita menangkan cuma satu: jadi yang PERTAMA lewat begitu
        -- pintunya dibuka. Karena itu ditunggu di X = garis - 4, bukan jauh di
        -- belakang. Jangan menempel ke garisnya: mendorong terus menghasilkan
        -- belasan koreksi posisi beruntun, dan koreksi beruntun itulah yang
        -- berujung mati.
        local h2 = akar()
        if h2 then
            luncurKe(Vector3.new(548, h2.Position.Y, GERAK.LaneZ), 6)
        end
        -- Tunggu sampai reset benar-benar terjadi. Diberi 0,15 detik kelebihan
        -- supaya egg sudah lahir saat kita tiba, bukan masih kosong.
        local t2 = workspace:GetServerTimeNow()
        local okR2, resetAt2 = pcall(ResetUtil.GetNextResetAt, t2)
        if okR2 and type(resetAt2) == "number" then
            local batasTunggu = os.clock() + math.max(0, resetAt2 - t2) + 12
            _G.SaeSengajaDiam = true
            while os.clock() < batasTunggu do
                local t3 = workspace:GetServerTimeNow()
                -- Berangkat 0,05 detik SEBELUM reset: perjalanan dari X=548 ke
                -- garis butuh waktu juga, jadi kita tiba pas pintunya terbuka.
                if t3 >= resetAt2 - 0.05 then break end
                task.wait(0.05)
            end
            _G.SaeSengajaDiam = false
            _G.SaeSerbuMenunggu = (_G.SaeSerbuMenunggu or 0) + 1
        end
    end

    lewatiGerbangZ()
    jalanKe(rec.BottomCFrame.Position, rec.AreaId)

    -- Menunggu di sarang sampai egg benar-benar muncul, lalu langsung sambar.
    -- Ditandai supaya penjaga macet tidak menganggap ini tersangkut.
    _G.SaeSengajaDiam = true
    local batas = os.clock() + math.max(sisa, 0) + 8
    while os.clock() < batas do
        local ok2, snap = pcall(EggCmds.GetAreaEggSnapshot)
        if ok2 and type(snap) == "table" and type(snap.Records) == "table" then
            for _, r in pairs(snap.Records) do
                if r.NestId == rec.NestId and r.AreaId == rec.AreaId
                    and r.State == "Slot" and not (dilewati or {})[r.Uid] then
                    log("SERBU — egg muncul, sambar")
                    _G.SaeSengajaDiam = false
                    return sambarSerempak(r)
                end
            end
        end
        task.wait(0.1)
    end
    _G.SaeSengajaDiam = false
    log("SERBU — egg tidak muncul, kembali ke putaran biasa")
    return false
end

-- Uid egg yang sedang digenggam, dan pembaca record berdasarkan uid.
local function uidGenggaman()
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return nil
    end
    for _, rec in pairs(snap.Records) do
        if rec.State == "Carried" and rec.CarrierUserId == Player.UserId then
            return rec.Uid
        end
    end
    return nil
end

local function recordUid(uid)
    local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
    if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
        return nil
    end
    for _, rec in pairs(snap.Records) do
        if rec.Uid == uid then return rec end
    end
    return nil
end

-- Bawa pulang, dan REBUT LAGI kalau guard menjatuhkannya di tengah jalan.
--
-- Guard tidak bisa dimatikan (server-side) dan tidak bisa dihindari (45 dari 45
-- sarang berada 9-23 stud darinya). Jadi kehilangan egg di perjalanan pulang
-- adalah kejadian WAJAR, bukan kegagalan -- dan yang benar bukan menyerah lalu
-- mencari sasaran baru, melainkan berbalik mengambilnya lagi.
--
-- Loop rebut-ulang yang lama cuma memanggil RequestCarryAreaEgg dari jauh, dan
-- server menolaknya dengan "Get closer to the egg" -- jadi praktis tidak pernah
-- berhasil. Di sini kita benar-benar TERBANG kembali ke egg-nya.
--
-- Tiga percobaan: cukup untuk beberapa kali dipukul beruntun, tapi tidak sampai
-- terjebak selamanya kalau egg-nya keburu diambil pemain lain.
local function simpanGenggaman()
    local uid = uidGenggaman()
    if not uid then
        return true
    end

    for percobaan = 1, 3 do
        lariKeAman(nil)

        -- Sampai sisi aman: egg tersimpan kalau record-nya lenyap.
        for _ = 1, 12 do
            if not eggDipegang() then
                if recordUid(uid) == nil then
                    return true
                end
                break
            end
            task.wait(0.1)
        end

        if eggDipegang() then
            -- Masih di tangan tapi belum tersimpan: ulangi penyeberangan.
            _G.SaeUlangSeberang = (_G.SaeUlangSeberang or 0) + 1
        else
            local rec = recordUid(uid)
            if rec == nil then
                return true
            elseif rec.State == "Dropped" and rec.BottomCFrame then
                -- Direbut guard di jalan. Kembali ambil, lalu lanjut pulang.
                log(string.format("egg direbut di jalan — ambil lagi (%d/3)", percobaan))
                _G.SaeRebutLagi = (_G.SaeRebutLagi or 0) + 1
                jalanKe(rec.BottomCFrame.Position, rec.AreaId)
                pcall(EggCmds.RequestCarryAreaEgg, uid, nil)
                task.wait(0.15)
                if not eggDipegang() then
                    -- Sekali lagi dari dekat; kadang balasan pertama lambat.
                    pcall(EggCmds.RequestCarryAreaEgg, uid, nil)
                    task.wait(0.2)
                end
                if not eggDipegang() then
                    log("gagal merebut kembali — tinggalkan")
                    return false
                end
            else
                -- Kembali ke Slot atau disambar orang lain: tidak ada yang bisa
                -- dikejar lagi.
                log("egg tidak lagi bisa direbut (" .. tostring(rec.State) .. ")")
                return false
            end
        end
    end

    return not eggDipegang()
end

-- Rampok egg dari pemain yang menyambarnya duluan.
--
-- Memakai jalur game sendiri, tanpa memalsukan apa pun: bat punya controller
-- yang MEMILIH SASARANNYA SENDIRI --
--   local v88 = self:_selectClosestTarget()
--   Network.Fire(Bat.ACTIVATE, v88, traceId)
-- -- jadi kita cukup meng-equip bat lalu memanggil `tool:Activate()`. Controller
-- itu yang mengurus pemilihan target, cooldown 0,6 detik, dan pengirimannya.
--
-- Melebarkan hitbox TIDAK ADA GUNANYA: server menghitung jangkauannya sendiri
-- (`Config.Range + RangeBonus`, dasar 15 stud) dan toleransi +2 hanya ada di
-- sisi client. Jadi satu-satunya cara adalah benar-benar mendekat.
local function cariBat()
    local ch = Player.Character
    if ch then
        for _, x in ipairs(ch:GetChildren()) do
            if x:IsA("Tool") and string.find(x.Name, "Bat", 1, true) then
                return x, true
            end
        end
    end
    local bp = Player:FindFirstChild("Backpack")
    if bp then
        for _, x in ipairs(bp:GetChildren()) do
            if x:IsA("Tool") and string.find(x.Name, "Bat", 1, true) then
                return x, false
            end
        end
    end
    return nil, false
end

local function rampokEgg(uid)
    if not Config.Rampok then return false end

    local bat, terpasang = cariBat()
    if not bat then
        log("Rampok: tidak punya bat")
        return false
    end

    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if not terpasang then
        pcall(function() hum:EquipTool(bat) end)
        task.wait(0.2)
    end

    local batas = os.clock() + (Config.RampokBatasDetik or 12)
    local pukulBerikut = 0

    while os.clock() < batas do
        local rec = recordUid(uid)
        if not rec then
            log("Rampok: egg lenyap")
            return false
        end
        if rec.State == "Dropped" then
            log("Rampok: BERHASIL — egg jatuh")
            _G.SaeRampokBerhasil = (_G.SaeRampokBerhasil or 0) + 1
            return true
        end
        if rec.State ~= "Carried" or not rec.CarrierUserId then
            return false
        end

        local perampas = game:GetService("Players"):GetPlayerByUserId(rec.CarrierUserId)
        local ch2 = perampas and perampas.Character
        local hrpLawan = ch2 and ch2:FindFirstChild("HumanoidRootPart")
        if not hrpLawan then
            return false
        end

        local h = akar()
        if not h then return false end
        local jarak = (hrpLawan.Position - h.Position).Magnitude

        if jarak > 12 then
            -- Dikejar sampai DI DALAM jangkauan server (15 stud); 12 memberi
            -- margin karena dia juga bergerak.
            luncurKe(hrpLawan.Position, 10)
        elseif os.clock() >= pukulBerikut then
            -- Cooldown bat 0,6 detik; 0,7 supaya tidak ditolak client sendiri.
            pukulBerikut = os.clock() + 0.7
            pcall(function() bat:Activate() end)
            _G.SaeRampokPukul = (_G.SaeRampokPukul or 0) + 1
        else
            task.wait(0.05)
        end
    end

    log("Rampok: waktu habis")
    return false
end

function sambarSerempak(rec)
    local diterima, alasan = false, nil

    -- MENOLAK BERANGKAT KALAU TANGAN MASIH PENUH.
    --
    -- Ini jaring pengaman untuk seluruh jalur sekaligus. Server menolak sambaran
    -- kedua dengan "carrying an egg", dan penanganan penolakan itu memanggil
    -- sambarSerempak SEKALI LAGI -- yang berarti terbang penuh kembali ke sarang
    -- dengan egg masih di tangan, berdiri di depan guard yang sudah bangun.
    -- Pada egg besar itu berakhir dengan kematian, dan egg-nya ikut hilang.
    --
    -- Tangan wajib kosong dulu; mengosongkannya urusan pemanggil.
    if eggDipegang() then
        return false, "masih menggenggam egg"
    end

    -- 0. Masuk arena lewat pintunya. Tanpa ini server menolak carry.
    lewatiGerbangZ()

    -- 1. Gerak ke egg -- sambil terus memeriksa egg-nya masih ada.
    --
    -- Kalau pemain lain menyambarnya duluan, sarangnya kosong dan meneruskan
    -- perjalanan cuma membuang waktu; pada area jauh itu 2.800 stud sia-sia.
    -- Yang berstatus "Dropped" TIDAK dibatalkan: egg jatuh justru sasaran sah.
    -- Dibatasi tiap 0,3 detik. Snapshot itu tidak gratis, dan memanggilnya
    -- tiap frame berarti 60 kali per detik sepanjang perjalanan.
    local cekBerikut = 0
    batalTerbang = function()
        if os.clock() < cekBerikut then return nil end
        cekBerikut = os.clock() + 0.3
        local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
        if not ok or type(snap) ~= "table" or type(snap.Records) ~= "table" then
            return nil
        end
        for _, r in pairs(snap.Records) do
            if r.Uid == rec.Uid then
                if r.State == "Slot" or r.State == "Dropped" then
                    return nil
                end
                -- Disambar orang lain. Kalau Rampok menyala, JANGAN batalkan --
                -- perjalanan diteruskan supaya kita bisa mengejar perampasnya.
                if Config.Rampok and r.State == "Carried"
                    and r.CarrierUserId and r.CarrierUserId ~= Player.UserId then
                    return nil
                end
                return "target keburu diambil (" .. tostring(r.State) .. ")"
            end
        end
        return "target sudah tidak ada"
    end
    local okJalan = jalanKe(rec.BottomCFrame.Position, rec.AreaId)
    batalTerbang = nil
    if not okJalan then
        -- Tangan kosong: tidak ada yang perlu diantar pulang.
        return false, "perjalanan dibatalkan"
    end

    -- 2. Steal — burst secepat mungkin, OK = langsung kabur.
    --
    -- Dibatasi WAKTU, bukan cuma jumlah tembakan: guard bangun sekitar 0,6
    -- detik, dan yang menentukan selamat atau tidak adalah lama berada di
    -- dekat sarang -- bukan seberapa cepat kita datang.
    -- 2. Sambar, lalu PERGI tanpa menunggui balasan.
    --
    -- `RequestCarryAreaEgg` itu InvokeServer yang MEMBLOKIR. Jejak nyata:
    -- 0,04 / 0,07 / 0,09 / 0,16 detik di kasus cepat, tapi 0,82 / 1,04 / 1,27 /
    -- 1,84 detik di kasus lambat -- dan selama itu karakter BERDIRI DIAM di
    -- sarang. Kematian terukur datang ~1 detik sesudah menyambar, persis di
    -- ekor lambat itu. `BatasDiSarang` tidak bisa menolong karena ia diperiksa
    -- SEBELUM panggilan, bukan saat panggilan sedang berjalan.
    --
    -- Kenapa hanya egg berat yang mati: egg berat memperlambat pembawa, jadi
    -- dari sisi server kita masih tertinggal di dekat sarang saat guard-nya
    -- bangun. Pukulannya 1000 damage, dan itu mematikan karena nyawa
    -- sesungguhnya 100 -- tulisan MaxHealth 1e9 kita hanya berlaku di client
    -- dan tidak pernah dilihat server (terbukti: `Health -1000/1000000000`).
    --
    -- Jadi permintaannya dikirim di utas terpisah. Kita menunggu sebentar saja
    -- supaya paketnya sempat berangkat dan balasan cepat tetap tertangkap di
    -- tempat, lalu pergi. Balasan lambat dipanen sambil berjalan.
    local mulaiSarang = os.clock()

    -- DIAM SEJENAK supaya posisi kita sempat sampai ke server.
    --
    -- Terukur 2026-08-22 di lima kedatangan berturut-turut: saat mesin luncur
    -- berhenti, jarak CLIENT ke egg cuma 3, 4, 4, 6, dan 8 stud -- jelas di
    -- dalam toleransi 8. Tapi server tetap menjawab "Get closer to the egg",
    -- dan hanya KADANG: 3 sambaran berhasil, 2 gagal, di area yang sama-sama
    -- jauh. Yang tertinggal adalah posisi kita di sisi SERVER, bukan mesin
    -- luncurnya -- dan itu sebabnya di 250 stud/dtk tidak pernah terjadi
    -- sementara di 600 sering.
    --
    -- Jedanya sekarang jauh lebih murah daripada dulu. Alasan lama untuk
    -- menembak seketika adalah guard yang membunuh dalam ~0,6 detik; dengan
    -- KebalMati itu tidak berlaku lagi. Yang tersisa cuma risiko egg direbut,
    -- dan itu terukur baru mulai 1,0 detik sesudah MENGGENGGAM -- bukan
    -- sebelum menggenggam.
    --
    -- Posisinya ditulis tiap frame, bukan sekadar menunggu: berdiri diam sambil
    -- menegaskan satu titik yang sama itulah yang membuat server menyusul.
    if (Config.JedaSambar or 0.15) > 0 then
        local hJ = akar()
        if hJ then
            local titik = hJ.Position
            local sampaiT = os.clock() + (Config.JedaSambar or 0.15)
            while os.clock() < sampaiT do
                local h2 = akar()
                if not h2 then break end
                h2.CFrame = CFrame.new(titik) * (h2.CFrame - h2.CFrame.Position)
                h2.AssemblyLinearVelocity = Vector3.zero
                RunService.Heartbeat:Wait()
            end
            _G.SaeJedaSambar = (_G.SaeJedaSambar or 0) + 1
        end
    end

    local hasilCarry = { selesai = false }
    local tKirim = os.clock()

    -- Dianggap MEMBAWA sejak permintaan dikirim, bukan sejak balasan tiba.
    --
    -- Bug ini mahal dan sempat menyesatkan lama: sejak sambaran dibuat
    -- asinkron, `bawaEgg` baru menyala SESUDAH balasan server datang -- padahal
    -- pelarian sudah berjalan lebih dulu. Akibatnya sepanjang perjalanan pulang
    -- script mengira tangannya kosong dan meluncur 250 penuh, lalu ditarik.
    -- Seluruh pembatasan kecepatan-bawa yang dibangun berhari-hari TIDAK PERNAH
    -- aktif sekali pun -- terbukti: `_G.SaeKaliBawa` dan `_G.SaeKecBawaHidup`
    -- keduanya masih nil sesudah berkali-kali mencuri, sementara sentakan
    -- tercatat sebagai "kosong 218 stud".
    --
    -- Kalau sambaran ternyata gagal, penanda ini dimatikan lagi di dalam utas.
    bawaEgg = true
    _G.SaeSedangBawa = true
    mulaiBawa = os.clock()
    wsRiwayat = {}

    task.spawn(function()
        local ok, berhasil, sebab = pcall(EggCmds.RequestCarryAreaEgg, rec.Uid, nil)
        hasilCarry.ok = ok
        hasilCarry.berhasil = berhasil
        hasilCarry.sebab = sebab
        hasilCarry.lama = os.clock() - tKirim
        hasilCarry.selesai = true
        if not (ok and berhasil) then
            bawaEgg = false
            _G.SaeSedangBawa = false
        end
    end)

    -- Ditunggu di tempat SESINGKAT MUNGKIN -- 0,12 detik, sekadar cukup agar
    -- paket permintaannya berangkat (ping terukur 75 ms, jadi sekali jalan ~40 ms).
    --
    -- Kenapa bukan menunggu balasan: guard bangun ~0,6 detik setelah kita tiba,
    -- dan terekam tiga kali berturut-turut egg direbut pada 1,0 / 1,5 / 1,9
    -- detik sesudah disambar. Setiap 0,1 detik berdiri di sarang itu mahal.
    -- Balasan yang datang belakangan tetap dipanen sambil kita sudah kabur.
    --
    -- Menghindari guard TIDAK MUNGKIN: ia digerakkan server (masih bergeser 19
    -- stud per sampel walau seluruh script guard di client dibuang), dan semua
    -- sarang berada dalam 9-23 stud darinya. Yang bisa kita atur cuma lamanya
    -- kita berada di sana.
    local batasTunggu = os.clock() + 0.12
    while not hasilCarry.selesai and os.clock() < batasTunggu do
        task.wait(0.02)
    end

    local j = _G.__EggJejakCarry
    if type(j) ~= "table" then
        j = {}
        _G.__EggJejakCarry = j
    end
    j[#j + 1] = string.format("%s|%s|%.2f|%s", rec.AreaId,
        hasilCarry.selesai and "sync" or "ASYNC", os.clock() - tKirim,
        hasilCarry.selesai
            and (hasilCarry.ok and (hasilCarry.berhasil and "OK"
                or tostring(hasilCarry.sebab)) or "invoke gagal")
            or "pergi duluan")
    while #j > 60 do
        table.remove(j, 1)
    end

    if hasilCarry.selesai and hasilCarry.ok and hasilCarry.berhasil then
        diterima = true
    elseif hasilCarry.selesai then
        alasan = hasilCarry.ok and tostring(hasilCarry.sebab) or "invoke gagal"
        -- Ditolak KARENA JARAK saja: kita masih berdiri di sarang, jadi cukup
        -- beri server sedikit waktu lagi lalu tembak ulang. Jauh lebih murah
        -- daripada membatalkan sasaran dan terbang balik dari zona aman.
        if hasilCarry.ok and string.find(string.lower(alasan), "closer", 1, true) then
            _G.SaeSambarUlangDekat = (_G.SaeSambarUlangDekat or 0) + 1
            task.wait(0.15)
            local ok2, berhasil2, sebab2 = pcall(EggCmds.RequestCarryAreaEgg, rec.Uid, nil)
            if ok2 and berhasil2 then
                diterima = true
                alasan = nil
                bawaEgg = true
                _G.SaeSedangBawa = true
                mulaiBawa = os.clock()
                wsRiwayat = {}
                _G.SaeSambarUlangBerhasil = (_G.SaeSambarUlangBerhasil or 0) + 1
            else
                alasan = ok2 and tostring(sebab2) or "invoke gagal"
            end
        end
    else
        -- Balasan belum datang. Pergi dulu, panen sambil berjalan.
        alasan = "menunggu balasan sambil kabur"
        _G.SaeCarryLambat = (_G.SaeCarryLambat or 0) + 1
    end

    -- 3. KABUR — steal OK atau gagal, yang penting keluar dari arena.
    -- Balik ke lane tengah dulu supaya tidak memotong lewat wilayah guard.
    -- Kalau dapat egg, lewati singgah ke zona aman: bankKeBase sudah
    -- menyusuri lane keluar sendiri, dan singgah dua kali cuma menambah
    -- waktu menggenggam.
    -- SELALU tinggalkan sarang, apa pun hasilnya.
    --
    -- Dulu baris ini dijaga `if not diterima`, dengan asumsi bankKeBase yang
    -- mengurus kepergian saat berhasil. Tapi bankKeBase dibuka dengan
    -- `if not Config.BankKeBase then return true end` -- dan di config pemain
    -- setelan itu MATI. Akibatnya begitu berhasil menyambar, tidak ada satu pun
    -- perintah gerak yang dijalankan: karakter berdiri diam menggenggam egg
    -- sampai putaran berikutnya, tepat di depan guard yang sedang bangun.
    -- PULANG HANYA KALAU MEMBAWA EGG.
    --
    -- Dulu baris ini selalu dijalankan "apa pun hasilnya", dengan alasan jangan
    -- berlama-lama di dekat sarang. Alasan itu sudah tidak berlaku sejak guard
    -- diparkir: sambaran yang gagal tidak menghasilkan apa-apa, dan pulang
    -- dengan tangan kosong berarti menempuh ribuan stud bolak-balik tanpa guna.
    -- KELUAR DARI WILAYAH GUARD LEBIH DULU, lewat sisi terdekat.
    --
    -- Guard hanya mengejar di dalam `Bounds` areanya. Terukur 2026-08-22:
    -- Bounds tiap area lebarnya ratusan stud di X tapi cuma ~150 stud di Z, dan
    -- sarang berada di tengah -- jadi jalan keluar terdekat itu KE SAMPING,
    -- 33-39 stud, bukan lari lurus pulang yang 94-315 stud.
    --
    -- Itu bedanya besar saat membawa egg berat: kecepatan kita terkunci di
    -- WalkSpeed, guard tidak, jadi tiap stud tambahan di dalam wilayahnya
    -- berarti satu kesempatan lagi untuk ditabok. Game sendiri menandai
    -- pintunya lewat part `ClosestExitPoint` di tiap area.
    do
        local okA, ga = pcall(function()
            return workspace.__OBJECTS.Areas.GuardAreas
        end)
        local area = okA and ga and rec.AreaId and ga:FindFirstChild(rec.AreaId)
        local keluar = area and area:FindFirstChild("ClosestExitPoint")
        if keluar and keluar:IsA("BasePart") then
            luncurKe(keluar.Position, 10)
            _G.SaeLewatPintuKeluar = (_G.SaeLewatPintuKeluar or 0) + 1
        end
    end

    -- Kalau balasan belum datang, kabur DULU lalu panen jawabannya.
    local sudahKabur = false
    if not hasilCarry.selesai then
        sudahKabur = true
        kembaliKeLane()
        lariKeAman(rec.AreaId)
        local sampai = os.clock() + 3
        while not hasilCarry.selesai and os.clock() < sampai do
            task.wait(0.05)
        end
        if hasilCarry.selesai and hasilCarry.ok and hasilCarry.berhasil then
            diterima = true
            alasan = nil
        end
    end

    aturPulangTinggi(diterima)
    if diterima and not sudahKabur then
        kembaliKeLane()
        lariKeAman(rec.AreaId)
    end

    -- 4. Dapat egg? LANGSUNG antar ke base pada detik itu juga.
    --
    -- Tiap jeda di dekat sarang -- sekecil apa pun -- memberi guard peluang
    -- memukul, karena dia bangun sekitar 0,6 detik sesudah kita datang.
    --
    -- `RequestUnequipTool` sempat dipakai di sini dan itu keliru: itu untuk
    -- Tool, sedangkan egg yang dibawa bukan Tool melainkan record berstatus
    -- "Carried". Jalan yang benar memang membawanya pulang. Karena selama
    -- menggenggam kita rawan dipukul, perjalanannya dibuat sependek mungkin --
    -- langsung ke base, tanpa mampir dan tanpa lewat jalur arena.
    if diterima then
        -- DIUKUR, belum diubah: apakah egg sudah tersimpan SEBELUM perjalanan
        -- ke base dimulai?
        --
        -- Kalau `SaeBankPercuma` terus naik sementara `SaeBankPerlu` diam,
        -- berarti menyeberang garis aman sudah cukup untuk menyimpan dan
        -- seluruh trip ke taman itu pemborosan murni -- `BankKeBase` tinggal
        -- dimatikan. Perilakunya sengaja TIDAK diubah dulu: kalau ternyata
        -- terbalik, mematikannya membuat egg nyangkut di tangan dan SEMUA
        -- sambaran berikutnya ditolak server.
        if Config.BankKeBase then
            if eggDipegang() == nil then
                _G.SaeBankPercuma = (_G.SaeBankPercuma or 0) + 1
            else
                _G.SaeBankPerlu = (_G.SaeBankPerlu or 0) + 1
            end
        end
        bankKeBase()
    end
    -- Selalu diturunkan lagi, termasuk saat bankKeBase mati -- kalau tidak,
    -- putaran berikutnya berangkat ke sarang dalam keadaan masih melayang.
    mendarat()
    bawaEgg = false
    _G.SaeSedangBawa = false
    -- Pulih untuk perjalanan berikutnya; penurunan tadi hanya berlaku untuk
    -- perjalanan yang bermasalah, bukan selamanya.
    -- Kembali normal begitu egg tersimpan: pembatasan ini HANYA berlaku selama
    -- egg ada di tangan. Perjalanan berangkat dan berkeliling tetap 250 penuh.
    kaliBawa = 1.0

    return diterima, alasan
end
local adaKabar = false
local koneksi = {}
local function pasangPendengar()
    if not Config.ReaksiInstan then
        return
    end
    local function tandai()
        adaKabar = true
    end
    for _, nama in ipairs({ "AreaEggUpdated", "AreaEggSnapshotUpdated", "AreaEggRemoved" }) do
        local sinyal = EggCmds[nama]
        if type(sinyal) == "table" and type(sinyal.Connect) == "function" then
            local ok, c = pcall(function()
                return sinyal:Connect(tandai)
            end)
            if ok and c then
                koneksi[#koneksi + 1] = c
            end
        end
    end
    log("pendengar egg terpasang:", #koneksi)
end
local function lepasPendengar()
    for _, c in ipairs(koneksi) do
        pcall(function()
            c:Disconnect()
        end)
    end
    koneksi = {}
end
local function tungguKabar(maks)
    if not Config.ReaksiInstan or #koneksi == 0 then
        task.wait(maks)
        return
    end
    adaKabar = false
    local mulai = os.clock()
    while os.clock() - mulai < maks do
        if adaKabar then
            return
        end
        task.wait(0.05)
    end
end
getgenv().__EggGen = (getgenv().__EggGen or 0) + 1
local generasiku = getgenv().__EggGen
local function berjalanKah()
    return getgenv().__EggGen == generasiku
end
local function berhenti()
    getgenv().__EggGen = (getgenv().__EggGen or 0) + 1
    -- Kembalikan treadmill ke keadaan semula; jangan tinggalkan dunia
    -- pemain dalam kondisi yang kita ubah.
    pcall(aturTreadmill, false)
end
getgenv().StealAnEggStop = berhenti
local function utama()
    -- Treadmill dimatikan selama mencuri: ia sering menangkap karakter yang
    -- melintas dan menahannya di sana.
    pcall(aturTreadmill, true)
    local dilewati = {}
    local diambil = 0
    local sepiDilaporkan = false
    while berjalanKah() do
        local humc = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if not humc or (humc.Health <= 0 and not _G.SaeKebalAktif) then
            log("karakter mati / belum siap — tunggu respawn")
            local tW = os.clock()
            while os.clock() - tW < 20 and berjalanKah() do
                local h2 = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
                if h2 and (h2.Health > 0 or _G.SaeKebalAktif) and akar() then break end
                task.wait(0.5)
            end
            task.wait(1)
        end
        local hrpAwal = akar()
        if hrpAwal and sisiAman and not sisiAman(hrpAwal.Position) then
            log("respawn di dalam arena — pulang dulu")
            lariKeAman(nil)
        end
        catatSpeedDasar(Player.Character and Player.Character:FindFirstChildOfClass("Humanoid"))
        -- Saat Serbu Malam menyala, dinding tidak pernah ditunggu: ia sudah
        -- ditembus dari sisi panel, dan justru di 10 detik inilah kita ingin
        -- berada di dalam.
        if Config.HormatiDinding and not Config.SerbuMalam then
            local tutup = dindingTertutup()
            if tutup == true then
                if Config.RuntuhkanDinding and ResetWall and ResetWall.Collapse then
                    pcall(ResetWall.Collapse)
                    task.wait(0.5)
                end
                if dindingTertutup() == true then
                    log("dinding reset sedang berdiri — tunggu terbuka")
                    tungguKabar(4)
                    task.wait(1)
                end
            end
        end
        local sudahBawa = eggDipegang()
        if sudahBawa then
            -- Diantar pulang LEBIH DULU, bukan dibuang: egg ini sudah berhasil
            -- dicuri, membuangnya berarti membuang hasil kerja satu putaran.
            log("masih menggenggam " .. sudahBawa .. " — antar pulang dulu")
            simpanGenggaman()
        end
        -- Menjelang reset, berangkat lebih dulu dan tunggu di sarang.
        -- Serbu malam ikut dihitung "sedang steal".
        --
        -- Dulu blok ini berjalan SEBELUM `adaSasaran` diisi, jadi sepanjang
        -- serbu dan pengantaran egg-nya kedua penanda masih false -- dan loop
        -- hatch, fuse, jual, serta tanam bebas menyelinap justru pada saat kita
        -- sedang menggenggam egg di dalam arena.
        statusSteal.sibuk = true
        if serbuSebelumReset(dilewati) then
            simpanGenggaman()
        end
        statusSteal.sibuk = false

        local rec = cariEggTerbaik(dilewati)
        statusSteal.adaSasaran = rec ~= nil
        if not rec then
            if next(dilewati) then
                dilewati = {}
                log("kandidat habis, daftar tunda direset")
            else
                if not sepiDilaporkan then
                    sepiDilaporkan = true
                    log(string.format("tak ada egg rarity >=%d - tunggu reset",
                        Config.MinRarity))
                end
            end
            tungguKabar(3)
        else
            statusSteal.sibuk = true
            sepiDilaporkan = false
            -- Dipakai di akhir putaran untuk membedakan berhasil dari gagal
            -- tanpa mengintip variabel milik sambarSerempak.
            local diambilAwal = diambil
            local angka, nama = nilaiRarity(rec.AssetCategory)
            log(string.format("sasaran: %s %.0fkg [%s/%d] mutasi=%d area=%s",
                rec.AssetCategory, beratEgg(rec), nama, angka, jumlahMutasi(rec), tostring(rec.AreaId)))
            -- SELALU pakai jalur remote (sambarSerempak), apa pun ModeGerak.
            --
            -- Cabang ini dulu dijaga ModeGerak == "instan", sedangkan config
            -- pemain berisi "tween" -- jadi sambarSerempak TIDAK PERNAH dipanggil.
            -- Yang jalan cabang ProximityPrompt (tungguPromptSiap -> picu), dan
            -- itu berdiri menunggu prompt siap di depan sarang: persis gejala
            -- "sampai di egg lalu diam, tidak menyambar sama sekali".
            --
            -- Jalur remote sudah terbukti: RequestCarryAreaEgg menjawab dan egg
            -- benar-benar terbawa (State jadi "Carried"). ModeGerak sekarang
            -- hanya memilih RUTE, tidak lagi memilih cara menyambar.
            if true then
                local perolehanSebelum = cacahPerolehan()

                -- masukLewatGerbang TIDAK dipanggil di sini.
                --
                -- Sempat dipanggil (build 22c) berdasarkan catatan lama bahwa
                -- strip x=553 wajib diseberangi fisik. Catatan itu TIDAK LAGI
                -- BERLAKU: script pembanding terukur menyeberang lima kali
                -- sambil meluncur 300 stud/dtk dengan MoveDirection 0,00 dan
                -- tetap selamat. Tidak ada langkah fisik sama sekali.
                --
                -- Lebih buruk, memanggilnya di sini MEMBUAT rubberband: tiap
                -- percobaan yang gagal mengulang alur, dan pengulangan itu
                -- menerbangkan karakter kembali ke titik gerbang. Terekam
                -- mentah -- maju ke X=720..747 lalu disentak ke X=531..539
                -- (titikAmanGerbang=542, X_SAFE=544), berulang tiap ~1,1 detik.

                local diterima, alasan = sambarSerempak(rec)
                if alasan and string.find(alasan, "inventory is full") then
                    log("INVENTARIS PENUH (" .. cacahPerolehan() .. " record) — berhenti. "
                        .. "Tanam & tetaskan egg dulu lewat tab Hatch.")
                    break
                end
                if not diterima and alasan
                    and (string.find(alasan, "carrying an egg")
                        or string.find(alasan, "masih menggenggam")) then
                    -- Diantar pulang, BUKAN dibuang: egg yang sudah di tangan
                    -- itu hasil putaran sebelumnya.
                    log("tangan masih penuh — antar pulang dulu")
                    simpanGenggaman()
                    -- Diulang HANYA kalau tangan benar-benar sudah kosong.
                    -- Tanpa syarat ini kita terbang balik ke sarang sambil
                    -- menggenggam, dan itu yang selama ini berakhir dipukul.
                    if not eggDipegang() then
                        diterima, alasan = sambarSerempak(rec)
                    else
                        log("tangan masih penuh — sambaran ini dilewati")
                    end
                elseif not diterima and alasan and string.find(alasan, "gameplay area") then
                    log("belum tercatat masuk arena — ulangi")
                    diterima, alasan = sambarSerempak(rec)
                end
                local dapatBeneran = false
                local tungguT = os.clock()
                while os.clock() - tungguT < Config.BatasVerifikasi do
                    if cacahPerolehan() > perolehanSebelum then
                        dapatBeneran = true
                        break
                    end
                    task.wait(0.07)
                end
                if dapatBeneran then
                    diambil = diambil + 1
                    catatRiwayat(rec)
                    log(string.format("MASUK — %s [%s] — total %d",
                        rec.AssetCategory, nama, diambil))
                else
                    log(string.format("TIDAK masuk — %s%s", rec.AssetCategory,
                        alasan and (" (" .. alasan .. ")") or ""))
                    -- Sebelum menyerah: kalau egg ini sedang dibawa pemain lain
                    -- dan Rampok menyala, rebut dulu.
                    local rr = recordUid(rec.Uid)
                    if Config.Rampok and rr and rr.State == "Carried"
                        and rr.CarrierUserId and rr.CarrierUserId ~= Player.UserId then
                        if rampokEgg(rec.Uid) then
                            diterima = sambarSerempak(rec)
                        end
                    end
                    if not diterima then
                        dilewati[rec.Uid] = os.clock() + Config.LupakanGagalDetik
                    end
                end
                -- Diantar pulang. Sebelumnya di sini egg langsung dibuang,
                -- jadi tiap sambaran yang berhasil hilang lagi seketika.
                simpanGenggaman()
                if Config.MaksEgg > 0 and diambil >= Config.MaksEgg then
                    log("batas MaksEgg tercapai, berhenti")
                    break
                end
            elseif not (function()
                local h = akar()
                if h and sisiAman(h.Position) and not sisiAman(rec.BottomCFrame.Position) then
                    local pintu = exitPoint(rec.AreaId)
                    if pintu then
                        local z = pintu.Z
                        if not jalanKe(Vector3.new(542, h.Position.Y, z), rec.AreaId) then return false end
                        if not jalanKe(Vector3.new(568, h.Position.Y, z), rec.AreaId) then return false end
                    end
                end
                return jalanKe(rec.BottomCFrame.Position, rec.AreaId)
            end)() then
                log("gagal mencapai, dilewati")
                dilewati[rec.Uid] = os.clock() + Config.LupakanGagalDetik
            else
                tahanPosisi(rec.BottomCFrame.Position)
                local prompt, sebab
                if Config.ModeGerak == "instan" then
                    prompt = promptUntuk(rec)
                else
                    prompt, sebab = tungguPromptSiap(rec, Config.BatasTungguPrompt)
                end
                if not prompt and Config.ModeGerak ~= "instan" then
                    lepasTahan()
                    log("prompt tidak siap (" .. tostring(sebab) .. "), dilewati")
                    dilewati[rec.Uid] = os.clock() + Config.LupakanGagalDetik
                else
                    local cara, dapat = nil, false
                    local sudahLewatPintu = false
                    local perolehanSebelum = cacahPerolehan()
                    do
                        for _ = 1, Config.SemburanCarry do
                            pcall(EggCmds.RequestCarryAreaEgg, rec.Uid, nil)
                            task.wait(Config.JedaSemburan)
                        end
                        lepasTahan()
                        lariKeAman(rec.AreaId)
                        cara = "remote-semburan"
                        dapat = terambil(rec.Uid) or eggDipegang() ~= nil
                    end
                    for percobaan = 1, (dapat and 0 or Config.PercobaanPicu) do
                        local modus = 2
                        local alasan
                        if prompt then
                            cara, alasan = picu(prompt, modus, rec.Uid)
                        elseif modus == 4 then
                            cara, alasan = picu(nil, 4, rec.Uid)
                        end
                        local tPicu = os.clock()
                        while os.clock() - tPicu < 1.2 do
                            if terambil(rec.Uid) then
                                dapat = true
                                break
                            end
                            task.wait(0.1)
                        end
                        if dapat then
                            pcall(EggCmds.RequestEquipTool, rec.Uid)
                            lepasTahan()
                            lariKeAman(rec.AreaId)
                            break
                        end
                        log("picu cara " .. modus .. " belum berbuah"
                            .. (alasan and (" (" .. alasan .. ")") or ""))
                        if alasan and string.find(alasan, "gameplay area") and not sudahLewatPintu then
                            sudahLewatPintu = true
                            log("masuk lewat pintu area dulu, lalu ulangi")
                            lepasTahan()
                            if jalanKe(rec.BottomCFrame.Position, rec.AreaId, true) then
                                tahanPosisi(rec.BottomCFrame.Position)
                                local lagi = promptUntuk(rec)
                                if lagi then
                                    prompt = lagi
                                end
                            end
                        end
                        if percobaan < Config.PercobaanPicu then
                            local lagi = promptUntuk(rec)
                            if lagi then
                                prompt = lagi
                            end
                        end
                    end
                    lepasTahan()
                    if dapat then
                        log(string.format("DAPAT (%s) %s [%s] — lari ke safe zone",
                            cara, rec.AssetCategory, nama))
                        local dapatBeneran = false
                        local tungguT = os.clock()
                        while os.clock() - tungguT < Config.BatasVerifikasi do
                            if cacahPerolehan() > perolehanSebelum then
                                dapatBeneran = true
                                break
                            end
                            task.wait(0.2)
                        end
                        if dapatBeneran then
                            diambil = diambil + 1
                            log(string.format("MASUK — %s [%s] — total %d",
                                rec.AssetCategory, nama, diambil))
                        else
                            log(string.format("TIDAK masuk — %s", rec.AssetCategory))
                        end
                        simpanGenggaman()
                        if Config.MaksEgg > 0 and diambil >= Config.MaksEgg then
                            log("batas MaksEgg tercapai, berhenti")
                            break
                        end
                    else
                        log("gagal ambil" .. (cara and (" (" .. cara .. " tak diterima)") or " (tak ada cara picu)"))
                        dilewati[rec.Uid] = os.clock() + Config.LupakanGagalDetik
                    end
                end
            end
            -- LANJUT BEGITU EGG BENAR-BENAR MASUK INVENTORY.
            --
            -- Egg baru berpindah saat notif "You stole an EGG" muncul; sebelum
            -- itu ia MASIH TERGENGGAM, dan sambaran berikutnya pasti ditolak
            -- server dengan "carrying an egg". Jadi yang ditunggu kepastian
            -- perpindahan itu, bukan angka jeda yang dikira-kira.
            --
            -- `eggDipegang()` jadi nil persis pada perpindahan tersebut: ia
            -- membaca record berstatus "Carried" atas nama kita di snapshot.
            --
            -- Dulu di sini `task.wait(math.max(JedaAntarEgg, ping*4))` -- 1,5
            -- detik mati tiap putaran, dibayar rata baik berhasil maupun gagal.
            -- Jeda penuh sekarang hanya untuk putaran yang GAGAL, dan untuk
            -- kasus egg tak kunjung masuk (di situ berangkat cepat justru
            -- menjamin penolakan).
            if diambil > diambilAwal then
                local batasS = os.clock() + (Config.BatasTungguSimpan or 6)
                local pegang = eggDipegang() ~= nil
                -- Detak sinyal saat penantian DIMULAI. Hanya detak yang lebih
                -- baru yang boleh dipercaya; tanpa ini, `bawaLive` yang masih
                -- `false` dari egg sebelumnya akan langsung meloloskan kita
                -- padahal egg yang baru masih di tangan.
                local detakAwal = _G.SaeBawaLiveDetak or 0
                local cekSnap = os.clock()
                while pegang and os.clock() < batasS do
                    if bawaLive == false and (_G.SaeBawaLiveDetak or 0) > detakAwal then
                        pegang = false
                        _G.SaeSimpanLewatSinyal = (_G.SaeSimpanLewatSinyal or 0) + 1
                    else
                        RunService.Heartbeat:Wait()
                        -- Cadangan kalau sinyalnya tidak pernah datang: snapshot
                        -- tiap 0,25 detik. Lambat tapi pasti, dan tidak membiarkan
                        -- kita menggantung hanya karena satu sinyal meleset.
                        if os.clock() - cekSnap >= 0.25 then
                            cekSnap = os.clock()
                            pegang = eggDipegang() ~= nil
                            if not pegang then
                                _G.SaeSimpanLewatSnapshot =
                                    (_G.SaeSimpanLewatSnapshot or 0) + 1
                            end
                        end
                    end
                end
                if pegang then
                    log("egg belum masuk inventory setelah menunggu — jeda penuh")
                    _G.SaeTungguSimpanGagal = (_G.SaeTungguSimpanGagal or 0) + 1
                    task.wait(math.max(Config.JedaAntarEgg, pingDetik() * 4))
                else
                    _G.SaeLanjutCepat = (_G.SaeLanjutCepat or 0) + 1
                    task.wait(math.max(Config.JedaSetelahSimpan or 0.1, pingDetik() * 2))
                end
            else
                task.wait(math.max(Config.JedaAntarEgg, pingDetik() * 4))
            end
            statusSteal.sibuk = false
        end
    end
    statusSteal.adaSasaran, statusSteal.sibuk = false, false
    lepasPendengar()
    log("selesai. total diambil:", diambil)
end
pasangPendengar()
task.spawn(utama)
-- pasangAntiAfk() DIHAPUS — VirtualUser memicu BAC-5517
getgenv().SAEMulaiHatch()
if Config.AutoHop then
    getgenv().SAEMulaiHop()
end
task.spawn(function()
    local generasi = getgenv().__EggGen
    while getgenv().__EggGen == generasi do
        local giliranJual = not statusSteal.sibuk and not statusSteal.adaSasaran
        if setelan("AutoFuse") and giliranJual then
            for _ = 1, setelan("FuseSekali") do
                if statusSteal.adaSasaran or statusSteal.sibuk then
                    break
                end
                local ok, sebab = fuseSekali()
                if not ok then
                    if sebab ~= "tak ada 3 pet sejenis yang layak" then
                        log("fuse berhenti: " .. tostring(sebab))
                    end
                    break
                end
            end
        end
        if setelan("AutoJualPet") and giliranJual then
            local terjual, kandidat = jualPetSekali(setelan("JualPetSekali"))
            if kandidat > 0 and terjual == 0 then
                log("jual pet: " .. kandidat .. " kandidat, tak satu pun terjual")
            end
            if terjual > 0 then
                task.wait(Config.JualPetJedaPutaran)
            else
                task.wait(math.max(2, Config.JualPetJedaSepi))
            end
        else
            task.wait(2)
        end
    end
end)
if Config.BoostFps then
    task.spawn(boostFps)
end
task.spawn(function()
    local generasi = getgenv().__EggGen
    while getgenv().__EggGen == generasi do
        if setelan("AutoEquipBest") then
            local ok, sebab = equipBest()
            if not ok then
                log("equip best gagal: " .. tostring(sebab))
            end
        end
        local t = os.clock()
        local jeda = math.max(15, setelan("EquipBestTiapDetik"))
        while os.clock() - t < jeda and getgenv().__EggGen == generasi do
            task.wait(1)
        end
    end
end)
]==]
-- LIVE MONITOR DICABUT. Modulnya dulu seluruhnya berada di string SUMBER_LIVE
-- di sini (315 baris) dan hanya di-loadstring kalau saklarnya dinyalakan --
-- default-nya mati, jadi ia praktis tidak pernah jalan. Satu-satunya alasan
-- keberadaannya adalah mengirim status ke panel lewat /api/live/update, dan
-- panel itu sedang dipensiunkan bersama Controller.
local induk = (gethui and gethui()) or game:GetService("CoreGui")
local lama = induk:FindFirstChild("MozeSAE")
if lama then
    lama:Destroy()
end
local gui = new("ScreenGui", induk, {
    Name = "MozeSAE",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
})
local shell = new("Frame", gui, {
    Size = UDim2.fromOffset(428, 580),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1,
})
local skala = new("UIScale", shell, { Scale = 1 })
local function hitungSkala()
    local cam = workspace.CurrentCamera
    if not cam then
        return
    end
    local vp = cam.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then
        return
    end
    local muat = math.min((vp.X * 0.60) / 428, (vp.Y * 0.80) / 580)
    skala.Scale = math.clamp(muat, 0.55, 1)
end
hitungSkala()
do
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(hitungSkala)
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local baru2 = workspace.CurrentCamera
        if baru2 then
            baru2:GetPropertyChangedSignal("ViewportSize"):Connect(hitungSkala)
            hitungSkala()
        end
    end)
end
local halo = new("Frame", shell, {
    Size = UDim2.new(1, 24, 1, 24),
    Position = UDim2.fromOffset(-12, -12),
    BackgroundColor3 = T.ember,
    BackgroundTransparency = 0.86,
    BorderSizePixel = 0,
    ZIndex = 0,
})
radius(halo, 22)
new("UIGradient", halo, {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.65),
        NumberSequenceKeypoint.new(1, 1),
    }),
})
local root = new("Frame", shell, {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.base,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 1,
})
radius(root, 14)
stroke(root, 0.86)
local mica = new("Frame", root, {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.layer1,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ZIndex = 1,
})
radius(mica, 14)
new("UIGradient", mica, {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(0.55, 0.55),
        NumberSequenceKeypoint.new(1, 0.85),
    }),
})
local sheen = new("Frame", root, {
    Size = UDim2.new(1, 0, 0, 120),
    BackgroundColor3 = T.emberHi,
    BackgroundTransparency = 0.94,
    BorderSizePixel = 0,
    ZIndex = 1,
})
new("UIGradient", sheen, {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(1, 1),
    }),
})
local bar = new("Frame", root, {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundTransparency = 1,
    ZIndex = 3,
})
local ikon = new("Frame", bar, {
    Size = UDim2.fromOffset(32, 32),
    Position = UDim2.fromOffset(16, 12),
    BackgroundColor3 = T.ember,
    BorderSizePixel = 0,
    ZIndex = 3,
})
radius(ikon, 9)
new("UIGradient", ikon, {
    Rotation = 135,
    Color = ColorSequence.new(T.ember, T.emberHi),
})
new("TextLabel", ikon, {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "🥚",
    TextSize = 16,
    ZIndex = 4,
})
new("TextLabel", bar, {
    Size = UDim2.new(1, -160, 0, 16),
    Position = UDim2.fromOffset(58, 13),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "Steal An Egg",
    TextColor3 = T.textHi,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
})
local subJudul = new("TextLabel", bar, {
    Size = UDim2.new(1, -160, 0, 12),
    Position = UDim2.fromOffset(58, 30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Tidak berjalan",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
})
local function tombolJendela(simbol, x, warnaHover)
    local b = new("TextButton", bar, {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, x, 0, 12),
        BackgroundColor3 = warnaHover,
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = simbol,
        TextColor3 = T.textMid,
        TextSize = 13,
        AutoButtonColor = false,
        ZIndex = 3,
    })
    radius(b, 8)
    b.MouseEnter:Connect(function()
        tween(b, EASE_S, { BackgroundTransparency = 0.82, TextColor3 = T.textHi })
    end)
    b.MouseLeave:Connect(function()
        tween(b, EASE_S, { BackgroundTransparency = 1, TextColor3 = T.textMid })
    end)
    return b
end
local btnMin = tombolJendela("‒", -84, T.layer3)
local btnTutup = tombolJendela("✕", -44, T.ember)
local nav = new("Frame", root, {
    Size = UDim2.new(1, -32, 0, 34),
    Position = UDim2.fromOffset(16, 60),
    BackgroundColor3 = T.layer1,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 3,
})
radius(nav, 9)
stroke(nav, 0.9)
local pil = new("Frame", nav, {
    Size = UDim2.new(1 / 3, -6, 1, -6),
    Position = UDim2.fromOffset(3, 3),
    BackgroundColor3 = T.layer3,
    BorderSizePixel = 0,
    ZIndex = 3,
})
radius(pil, 7)
stroke(pil, 0.86)
local HALAMAN = { "Steal", "Hatch", "Misc" }
local tabBtn, halaman = {}, {}
local aktifIdx = 1
local isi = new("Frame", root, {
    Size = UDim2.new(1, -32, 1, -168),
    Position = UDim2.fromOffset(16, 102),
    BackgroundTransparency = 1,
    ZIndex = 3,
})
local function halamanBaru(nama)
    local sf = new("ScrollingFrame", isi, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.layer3,
        ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        ZIndex = 3,
    })
    new("UIListLayout", sf, {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    new("UIPadding", sf, { PaddingRight = UDim.new(0, 6) })
    halaman[nama] = sf
    return sf
end
for i, nama in ipairs(HALAMAN) do
    halamanBaru(nama)
    local b = new("TextButton", nav, {
        Size = UDim2.new(1 / 3, 0, 1, 0),
        Position = UDim2.new((i - 1) / 3, 0, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = nama,
        TextColor3 = i == 1 and T.textHi or T.textLo,
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 4,
    })
    tabBtn[i] = b
    b.MouseButton1Click:Connect(function()
        if aktifIdx == i then
            return
        end
        aktifIdx = i
        tween(pil, EASE, { Position = UDim2.new((i - 1) / 3, 3, 0, 3) })
        for j, bb in ipairs(tabBtn) do
            tween(bb, EASE_S, { TextColor3 = j == i and T.textHi or T.textLo })
        end
        for j, nm in ipairs(HALAMAN) do
            halaman[nm].Visible = (j == i)
        end
    end)
end
halaman[HALAMAN[1]].Visible = true
local urut = 0
local function ord()
    urut = urut + 1
    return urut
end
local function kartu(sf, tinggi)
    local f = new("Frame", sf, {
        Size = UDim2.new(1, 0, 0, tinggi),
        BackgroundColor3 = T.layer1,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        LayoutOrder = ord(),
        ZIndex = 3,
    })
    radius(f, 10)
    local st = stroke(f, 0.9)
    f.MouseEnter:Connect(function()
        tween(f, EASE_S, { BackgroundTransparency = 0.16 })
        tween(st, EASE_S, { Transparency = 0.78 })
    end)
    f.MouseLeave:Connect(function()
        tween(f, EASE_S, { BackgroundTransparency = 0.3 })
        tween(st, EASE_S, { Transparency = 0.9 })
    end)
    return f
end
local function tajuk(sf, teks)
    local l = new("TextLabel", sf, {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = teks,
        TextColor3 = T.textMid,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        LayoutOrder = ord(),
        ZIndex = 3,
    })
    return l
end
local function labelKiri(induk2, teks, sub)
    new("TextLabel", induk2, {
        Size = UDim2.new(1, -80, 0, 16),
        Position = UDim2.fromOffset(14, sub and 11 or 0),
        AnchorPoint = sub and Vector2.new(0, 0) or Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = teks,
        TextColor3 = T.textHi,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    if sub then
        new("TextLabel", induk2, {
            Size = UDim2.new(1, -80, 0, 13),
            Position = UDim2.fromOffset(14, 29),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = sub,
            TextColor3 = T.textLo,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
    end
end
local function kotak(sf, teks, sub, awal, onUbah)
    local f = kartu(sf, 56)
    new("TextLabel", f, {
        Size = UDim2.new(1, -130, 0, 20),
        Position = UDim2.fromOffset(14, 10),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = teks,
        TextColor3 = T.textHi,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    new("TextLabel", f, {
        Size = UDim2.new(1, -130, 0, 16),
        Position = UDim2.fromOffset(14, 30),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = sub or "",
        TextColor3 = T.textLo,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    local kotakF = new("Frame", f, {
        Size = UDim2.fromOffset(100, 30),
        Position = UDim2.new(1, -114, 0.5, -15),
        BackgroundColor3 = T.layer3,
        ZIndex = 4,
    })
    radius(kotakF, 8)
    stroke(kotakF, 0.85)
    local input = new("TextBox", kotakF, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = keTeks(awal),
        PlaceholderText = "500m",
        TextColor3 = T.textHi,
        TextSize = 12,
        ClearTextOnFocus = false,
        ZIndex = 5,
    })
    local sekarang = awal
    input.FocusLost:Connect(function()
        local n = keAngka(input.Text)
        if n then
            sekarang = n
            input.Text = keTeks(n)
            onUbah(n)
        else
            input.Text = keTeks(sekarang)
        end
    end)
    return f
end
-- Tombol sekali-tekan. `saklar` untuk keadaan menyala/mati; ini untuk aksi
-- yang dijalankan saat itu juga, dan labelnya bisa berubah jadi laporan hasil.
local function tombolAksi(sf, teks, sub, labelTombol, onKlik)
    local f = kartu(sf, 56)
    labelKiri(f, teks, sub)
    local btn = new("TextButton", f, {
        Size = UDim2.fromOffset(86, 26),
        Position = UDim2.new(1, -100, 0.5, -13),
        BackgroundColor3 = T.layer3,
        Font = Enum.Font.GothamBold,
        Text = labelTombol,
        TextColor3 = T.textHi,
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 4,
    })
    radius(btn, 8)
    stroke(btn, 0.8)
    btn.MouseButton1Click:Connect(function()
        local ok, hasil = pcall(onKlik)
        btn.Text = ok and tostring(hasil or "OK") or "GAGAL"
        tween(btn, EASE, { BackgroundColor3 = ok and T.ok or T.emberHi })
        task.delay(2, function()
            if btn and btn.Parent then
                btn.Text = labelTombol
                tween(btn, EASE, { BackgroundColor3 = T.layer3 })
            end
        end)
    end)
    return btn
end

local function saklar(sf, teks, sub, awal, onUbah)
    local f = kartu(sf, sub and 56 or 42)
    if not sub then
        new("TextLabel", f, {
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.fromOffset(14, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = teks,
            TextColor3 = T.textHi,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
    else
        labelKiri(f, teks, sub)
    end
    local jalur = new("TextButton", f, {
        Size = UDim2.fromOffset(40, 20),
        Position = UDim2.new(1, -54, 0.5, -10),
        BackgroundColor3 = awal and T.ok or T.layer3,
        BackgroundTransparency = awal and 0 or 0.25,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
    })
    radius(jalur, 10)
    local js = stroke(jalur, awal and 1 or 0.75)
    local knop = new("Frame", jalur, {
        Size = UDim2.fromOffset(12, 12),
        Position = awal and UDim2.fromOffset(24, 4) or UDim2.fromOffset(4, 4),
        BackgroundColor3 = awal and T.textHi or T.textMid,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    radius(knop, 6)
    local nilai = awal
    jalur.MouseButton1Click:Connect(function()
        nilai = not nilai
        tween(jalur, EASE, {
            BackgroundColor3 = nilai and T.ok or T.layer3,
            BackgroundTransparency = nilai and 0 or 0.25,
        })
        tween(js, EASE_S, { Transparency = nilai and 1 or 0.75 })
        tween(knop, EASE, {
            Position = nilai and UDim2.fromOffset(24, 4) or UDim2.fromOffset(4, 4),
            BackgroundColor3 = nilai and T.textHi or T.textMid,
        })
        onUbah(nilai)
    end)
    return f
end
local function slider(sf, teks, min, maks, awal, format, onUbah)
    local f = kartu(sf, 62)
    new("TextLabel", f, {
        Size = UDim2.new(1, -28, 0, 15),
        Position = UDim2.fromOffset(14, 11),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = teks,
        TextColor3 = T.textHi,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    local nilaiLbl = new("TextLabel", f, {
        Size = UDim2.new(0, 150, 0, 15),
        Position = UDim2.new(1, -164, 0, 11),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = format(awal),
        TextColor3 = T.gold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4,
    })
    local rel = new("Frame", f, {
        Size = UDim2.new(1, -28, 0, 4),
        Position = UDim2.fromOffset(14, 40),
        BackgroundColor3 = T.layer3,
        BorderSizePixel = 0,
        ZIndex = 4,
    })
    radius(rel, 2)
    local frac = (awal - min) / math.max(maks - min, 1)
    local isiRel = new("Frame", rel, {
        Size = UDim2.fromScale(frac, 1),
        BackgroundColor3 = T.ember,
        BorderSizePixel = 0,
        ZIndex = 4,
    })
    radius(isiRel, 2)
    new("UIGradient", isiRel, { Color = ColorSequence.new(T.ember, T.emberHi) })
    local thumb = new("Frame", rel, {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(frac, -6, 0.5, -6),
        BackgroundColor3 = T.textHi,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    radius(thumb, 6)
    stroke(thumb, 0.6)
    local nilai = awal
    local seret = false
    local function setDari(px)
        local rx = rel.AbsolutePosition.X
        local rw = math.max(rel.AbsoluteSize.X, 1)
        local f2 = math.clamp((px - rx) / rw, 0, 1)
        local v = math.floor(min + f2 * (maks - min) + 0.5)
        if v ~= nilai then
            nilai = v
            nilaiLbl.Text = format(v)
            onUbah(v)
        end
        local fr = (nilai - min) / math.max(maks - min, 1)
        isiRel.Size = UDim2.fromScale(fr, 1)
        thumb.Position = UDim2.new(fr, -6, 0.5, -6)
    end
    local hit = new("TextButton", f, {
        Size = UDim2.new(1, -28, 0, 22),
        Position = UDim2.fromOffset(14, 31),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5,
    })
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            seret = true
            tween(thumb, EASE_S, { Size = UDim2.fromOffset(16, 16), Position = UDim2.new((nilai - min) / math.max(maks - min, 1), -8, 0.5, -8) })
            setDari(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if seret and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            setDari(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if seret and (i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch) then
            seret = false
            local fr = (nilai - min) / math.max(maks - min, 1)
            tween(thumb, EASE_S, { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(fr, -6, 0.5, -6) })
        end
    end)
    return f
end
local function segmen(sf, teks, opsi, awal, onUbah)
    local f = kartu(sf, 70)
    new("TextLabel", f, {
        Size = UDim2.new(1, -28, 0, 15),
        Position = UDim2.fromOffset(14, 11),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = teks,
        TextColor3 = T.textHi,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    local trek = new("Frame", f, {
        Size = UDim2.new(1, -28, 0, 30),
        Position = UDim2.fromOffset(14, 32),
        BackgroundColor3 = T.base,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 4,
    })
    radius(trek, 8)
    stroke(trek, 0.9)
    local n = #opsi
    local idxAwal = 1
    for i, o in ipairs(opsi) do
        if o.nilai == awal then
            idxAwal = i
        end
    end
    local penanda = new("Frame", trek, {
        Size = UDim2.new(1 / n, -6, 1, -6),
        Position = UDim2.new((idxAwal - 1) / n, 3, 0, 3),
        BackgroundColor3 = T.ember,
        BorderSizePixel = 0,
        ZIndex = 4,
    })
    radius(penanda, 6)
    new("UIGradient", penanda, {
        Rotation = 90,
        Color = ColorSequence.new(T.emberHi, T.ember),
    })
    local btns = {}
    for i, o in ipairs(opsi) do
        local b = new("TextButton", trek, {
            Size = UDim2.new(1 / n, 0, 1, 0),
            Position = UDim2.new((i - 1) / n, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = o.label,
            TextColor3 = i == idxAwal and T.textHi or T.textLo,
            TextSize = 11,
            AutoButtonColor = false,
            ZIndex = 5,
        })
        btns[i] = b
        b.MouseButton1Click:Connect(function()
            tween(penanda, EASE, { Position = UDim2.new((i - 1) / n, 3, 0, 3) })
            for j, bb in ipairs(btns) do
                tween(bb, EASE_S, { TextColor3 = j == i and T.textHi or T.textLo })
            end
            onUbah(o.nilai)
        end)
    end
    return f
end
local p1 = halaman["Steal"]
tajuk(p1, "FILTER EGG")
slider(p1, "Rarity minimum", 1, 10, S.MinRarity, function(v)
    return (RARITY[v] or "?") .. " ke atas"
end, function(v)
    S.MinRarity = v
    simpanConfig()
end)
slider(p1, "Batas egg", 0, 100, S.MaksEgg, function(v)
    return v == 0 and "Tanpa batas" or (v .. " lalu berhenti")
end, function(v)
    S.MaksEgg = v
    simpanConfig()
end)
-- Berat naik PANGKAT TIGA terhadap AssetScale; `ModelWeight` di direktori itu
-- berat pada skala 1, BUKAN atap. Terukur 2026-08-21: Archdemon Dragon
-- 120k kg di skala 1, 960k di skala 2, 7,68 juta di skala 4, dan 5,1 MILIAR di
-- skala 35 (skala tertinggi di tabel roll EggItemUtil). 57 dari 84 kategori
-- sanggup menembus 5 juta kg. Jadi jangan pernah menyebut ModelWeight sebagai
-- batas atas -- aku pernah salah begitu dan menyesatkan.
kotak(p1, "Berat minimum", "Seberat ini ke atas, rarity apa pun. 0 = mati. 5jt kg wajar, 1jt+ sering",
    S.MinBeratKg, function(v)
        S.MinBeratKg = v
        simpanConfig()
    end)
tajuk(p1, "PENGAMBILAN")
-- Speed. Satu angka, dua setelan: kecepatan jelajah dan kecepatan saat
-- menggenggam egg selalu ikut bersama-sama.
--
-- Menggantikan slider "Semburan carry" yang sudah tidak berguna; semburannya
-- sendiri dipatok 5 dan tidak lagi bisa diatur dari panel.
slider(p1, "Speed", 100, 1200, S.Speed or 250, function(v)
    return v .. " stud/dtk"
end, function(v)
    S.Speed = v
    -- GERAK lahir di potongan lain (SUMBER_STEAL), jadi disuntik lewat KEDUA
    -- jalur: terbukti 2026-08-21 getgenv() ~= _G, dan salah satunya bisa nil.
    -- Nilai ini juga sudah dibaca ulang saat GERAK dibuat, sehingga Mulai
    -- berikutnya tidak kembali ke bawaan.
    local function terap(g)
        if type(g) == "table" then
            g.Kecepatan = v
            g.KecepatanBawaEgg = v
        end
    end
    terap(getgenv().SAEGerak)
    terap(_G.SAEGerak)
    simpanConfig()
end)
saklar(p1, "Reaksi instan", "Sambar begitu egg muncul", S.ReaksiInstan, function(v)
    S.ReaksiInstan = v
    simpanConfig()
end)

-- Kekebalan. Terukur 2026-08-22 di client sungguhan: MaxHealth/Health 1e9
-- bertahan tanpa dikoreksi server, damage 1.000 dan 500.000 sama-sama tidak
-- mematikan.
--
-- Saklar ini juga menyalakan anti mental. Terukur 2026-08-21 dengan memicu
-- ApplyClientRagdoll pada diri sendiri memakai impuls setara pukulan guard:
-- tanpa penangkal terlempar 367 stud, dengan penangkal 5 stud.
saklar(p1, "Anti Guard", "Batalkan ragdoll + kunci posisi saat dipukul guard",
    S.Kekebalan ~= false, function(v)
    S.Kekebalan = v
    -- GERAK adalah local di potongan lain, jadi diakses lewat getgenv()
    -- yang memang sengaja diekspos saat sistem gerak dibuat.
    local g = getgenv().SAEGerak
    if type(g) == "table" then g.Kekebalan = v end
    if not v then
        -- Kembalikan nyawa ke wajar saat dimatikan; turunkan Health dulu supaya
        -- tidak terpotong mendadak oleh MaxHealth yang mengecil.
        pcall(function()
            -- `Player` adalah local di potongan lain; di kode GUI harus diambil sendiri.
            local plr = game:GetService("Players").LocalPlayer
            local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Health = math.min(hum.Health, 100)
                hum.MaxHealth = 100
                hum.Health = 100
            end
        end)
    end
    simpanConfig()
end)

-- Anti Trap. Syaratnya terbaca di script trap sisi server: pemicu hanya jadi
-- saat penyentuh sedang MEMEGANG EGG dan masih di sisi arena -- jadi trap
-- memang cuma menggigit di perjalanan pulang.
--
-- "Return height" dihapus dari sini: pulang lewat atas sudah dimatikan karena
-- menanjak memicu sentakan, sementara meluncur menempel tanah tidak. Menyisakan
-- slider yang tidak berefek cuma menyesatkan.
-- Rampok. Satu-satunya fitur yang menyerang pemain lain, jadi default MATI dan
-- keterangannya dibuat jujur soal itu.
--
-- Tidak memalsukan apa pun: bat punya controller yang memilih sasarannya
-- sendiri, kita cuma meng-equip lalu memanggil Activate(). Jangkauannya
-- ditegakkan server (15 stud + bonus bat), jadi kita memang harus mendekat --
-- melebarkan hitbox di client tidak berpengaruh sama sekali.
saklar(p1, "Rampok", "Target dicuri orang? Kejar & pukul pakai bat, lalu ambil",
    S.Rampok == true, function(v)
    S.Rampok = v
    local c = getgenv().SAEConfig
    if type(c) == "table" then c.Rampok = v end
    simpanConfig()
end)

saklar(p1, "Anti Trap", "Matikan PlayerTrap pemain lain — CanTouch dimatikan lokal",
    S.AntiTrap ~= false, function(v)
    S.AntiTrap = v
    local g = getgenv().SAEGerak
    if type(g) == "table" then g.MatikanTrap = v end
    simpanConfig()
end)

-- Anti Dorong. Mematikan LocalScript `AntiCollisionHighSeedPushBack` di
-- karakter dan tabrakan part egg genggaman. Belum terbukti sebagai penyebab
saklar(p1, "Anti Dorong",
    "Untuk egg besar — matikan dorong-balik saat kecepatan tinggi",
    S.AntiDorong ~= false, function(v)
    S.AntiDorong = v
    simpanConfig()
end)

-- Serbu Malam. Egg reset tiap 300 detik dan malam mulai 10 detik sebelumnya;
-- dinding reset itu milik client, jadi menembusnya tidak menyentuh server.
saklar(p1, "Serbu Malam", "Tembus dinding reset — masuk duluan di 10 detik sebelum egg muncul",
    S.SerbuMalam ~= false, function(v)
    S.SerbuMalam = v
    local c = getgenv().SAEConfig
    if type(c) == "table" then c.SerbuMalam = v end
    simpanConfig()
end)
local p2 = halaman["Hatch"]
tajuk(p2, "TANAM & TETAS")
new("TextLabel", p2, {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Menanam menyeret karakter ke taman; menetaskan tidak — terukur berhasil dari 90 stud.",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = ord(),
    ZIndex = 3,
})
saklar(p2, "Auto tetas", "Tetaskan begitu siap", S.AutoHatch, function(v)
    S.AutoHatch = v
    simpanConfig()
end)
saklar(p2, "Auto tanam", "Tanam mengitari taman — menyela mencuri", S.AutoTanam, function(v)
    S.AutoTanam = v
    simpanConfig()
end)
slider(p2, "Tanam sekali singgah", 1, 20, S.TanamSekali, function(v)
    return v .. " egg"
end, function(v)
    S.TanamSekali = v
    simpanConfig()
end)
tajuk(p2, "JUAL PET")
new("TextLabel", p2, {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Menjual TIDAK bisa dibatalkan. Pet favorit tidak pernah dijual.",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = ord(),
    ZIndex = 3,
})
saklar(p2, "Auto jual pet", "Jalan sambil mencuri — tidak menyela", S.AutoJualPet, function(v)
    S.AutoJualPet = v
    simpanConfig()
end)
segmen(p2, "Saring pakai", {
    { nilai = "rarity", label = "★  Rarity" },
    { nilai = "money", label = "$  Money" },
}, S.JualPetFilter, function(v)
    S.JualPetFilter = v
    simpanConfig()
end)
slider(p2, "Rarity — jual sampai", 1, 10, S.JualPetMaksRarity, function(v)
    return (RARITY[v] or "?") .. " ke bawah"
end, function(v)
    S.JualPetMaksRarity = v
    simpanConfig()
end)
kotak(p2, "Money — jual di bawah", "Boleh pakai K/M/B/T, misal 40k atau 1.5b",
    S.JualPetMinPerSecond, function(v)
        S.JualPetMinPerSecond = v
        simpanConfig()
    end)
tajuk(p2, "FUSE PET")
new("TextLabel", p2, {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Tiga pet dilebur jadi satu, hasilnya diundi. TIDAK bisa dibatalkan. "
        .. "Favorit dan mutasi tidak disentuh. Mengambil dari kolam yang sama dengan auto jual.",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = ord(),
    ZIndex = 3,
})
saklar(p2, "Auto fuse", "Jalan saat tidak ada sasaran curian", S.AutoFuse, function(v)
    S.AutoFuse = v
    simpanConfig()
end)
slider(p2, "Fuse sampai rarity", 1, 10, S.FuseMaksRarity, function(v)
    return (RARITY[v] or "?") .. " ke bawah"
end, function(v)
    S.FuseMaksRarity = v
    simpanConfig()
end)
slider(p2, "Fuse sekali putaran", 1, 20, S.FuseSekali, function(v)
    return v .. "x"
end, function(v)
    S.FuseSekali = v
    simpanConfig()
end)
saklar(p2, "Lindungi mutasi (fuse)", "Pet bermutasi tak pernah dilebur", S.FuseLewatiMutasi, function(v)
    S.FuseLewatiMutasi = v
    simpanConfig()
end)
tajuk(p2, "GROWING EGGS")
local daftarFrame = new("Frame", p2, {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = ord(),
    ZIndex = 3,
})
new("UIListLayout", daftarFrame, {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
local function gambarDaftar()
    for _, c in ipairs(daftarFrame:GetChildren()) do
        if not c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
    local ambil = getgenv().SAEDaftarTumbuh
    if type(ambil) ~= "function" then
        new("TextLabel", daftarFrame, {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "Tekan Mulai dulu — daftar dibaca dari script yang berjalan.",
            TextColor3 = T.textLo,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        })
        return
    end
    local ok, siap, tumbuh, tersimpan = pcall(ambil)
    if not ok then
        new("TextLabel", daftarFrame, {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "Daftar gagal dibaca: " .. tostring(siap):sub(1, 80),
            TextColor3 = T.warn,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        })
        return
    end
    siap, tumbuh, tersimpan = siap or {}, tumbuh or {}, tersimpan or 0
    new("TextLabel", daftarFrame, {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = string.format("%d siap · %d tumbuh · %d tersimpan",
            #siap, #tumbuh, tersimpan),
        TextColor3 = T.textMid,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
        ZIndex = 3,
    })
    local urut = 1
    local function baris(e, bisaBuka)
        local kartu = new("Frame", daftarFrame, {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = T.layer2,
            BackgroundTransparency = 0.35,
            LayoutOrder = urut,
            ZIndex = 3,
        })
        urut = urut + 1
        radius(kartu, 8)
        stroke(kartu, 0.93)
        new("TextLabel", kartu, {
            Size = UDim2.new(1, -84, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = string.format("%s  ·  %s", e.kategori, e.rarityNama or "?"),
            TextColor3 = bisaBuka and T.textHi or T.textMid,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 4,
        })
        if bisaBuka then
            local b = new("TextButton", kartu, {
                Size = UDim2.fromOffset(64, 22),
                Position = UDim2.new(1, -72, 0.5, -11),
                BackgroundColor3 = T.ok,
                Font = Enum.Font.GothamBold,
                Text = "Open",
                TextColor3 = T.textHi,
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 5,
            })
            radius(b, 6)
            b.MouseButton1Click:Connect(function()
                local tetas = getgenv().SAETetaskan
                if type(tetas) ~= "function" then
                    return
                end
                b.Text = "…"
                local berhasil = select(1, pcall(tetas, e.uid))
                b.Text = berhasil and "✓" or "gagal"
                task.delay(0.6, gambarDaftar)
            end)
        else
            new("TextLabel", kartu, {
                Size = UDim2.fromOffset(64, 22),
                Position = UDim2.new(1, -72, 0.5, -11),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = "tumbuh",
                TextColor3 = T.textLo,
                TextSize = 10,
                ZIndex = 4,
            })
        end
    end
    for _, e in ipairs(siap) do
        baris(e, true)
    end
    for _, e in ipairs(tumbuh) do
        baris(e, false)
    end
    if #siap == 0 and #tumbuh == 0 then
        new("TextLabel", daftarFrame, {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "Belum ada egg tertanam.",
            TextColor3 = T.textLo,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            ZIndex = 3,
        })
    end
end
gambarDaftar()
local p3 = halaman["Misc"]
tajuk(p3, "PINDAH SERVER")
new("TextLabel", p3, {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Server yang sudah habis egg bagusnya tidak akan terisi ulang lebih cepat karena ditunggui.",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = ord(),
    ZIndex = 3,
})
-- Tombol hapus treadmill.
--
-- Penghapusan otomatis sudah jalan saat script dimuat, tapi treadmill bisa
-- muncul lagi -- mis. plot baru dimuat, atau kamu rejoin dan script belum
-- sempat menyapunya. Tombol ini membuang script-nya SEKARANG JUGA.
--
-- Yang dibuang cuma tiga LocalScript treadmill di PlayerScripts.Game.Plots.
-- Tetangganya SENGAJA tidak disentuh: ActiveAssetsController menggambar pet di
-- plot dan PlotSignManager mengurus papan nama -- membuang seluruh folder Plots
-- ikut mematikan itu.
saklar(p3, "Matikan treadmill", "Terus dimatikan selama menyala — aman sesudah rejoin",
    S.MatikanTreadmill ~= false, function(v)
    S.MatikanTreadmill = v
    simpanConfig()
end)

-- Private server tidak tersedia di game ini (createVipServersAllowed = false,
-- dicek lewat API Roblox 2026-08-21). maxPlayers cuma 7, jadi mencari server
-- publik yang kosong adalah cara paling dekat untuk "sendirian".
saklar(p3, "Cari server sepi", "Hop sampai server berisi 1 orang saja",
    S.CariServerSepi == true, function(v)
    S.CariServerSepi = v
    local c = getgenv().SAEConfig
    if type(c) == "table" then c.CariServerSepi = v end
    simpanConfig()
end)

saklar(p3, "Auto hop", "Pindah kalau egg sudah habis", S.AutoHop, function(v)
    S.AutoHop = v
    simpanConfig()
    local mulai, henti = getgenv().SAEMulaiHop, getgenv().SAEBerhentiHop
    if v and type(mulai) == "function" then
        mulai()
    elseif not v and type(henti) == "function" then
        henti()
    end
end)
slider(p3, "Hop setelah sepi", 5, 300, S.HopSepiDetik, function(v)
    return v .. " detik tanpa egg"
end, function(v)
    S.HopSepiDetik = v
    simpanConfig()
end)
tajuk(p3, "ESP EGG ARENA")
new("TextLabel", p3, {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Pilih rarity yang mau disorot. Menyorot semuanya membuat arena penuh label.",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = ord(),
    ZIndex = 3,
})
saklar(p3, "ESP egg", "Label di tiap egg yang masih di sarang", S.EspEgg, function(v)
    S.EspEgg = v
    simpanConfig()
    if not v and type(getgenv().SAEBersihkanEsp) == "function" then
        pcall(getgenv().SAEBersihkanEsp)
    end
end)
for i = 1, 10 do
    local kunci = tostring(i)
    saklar(p3, RARITY[i] or ("Rarity " .. i), nil, S.EspRarity[kunci] == true, function(v)
        S.EspRarity[kunci] = v or nil
        simpanConfig()
    end)
end
tajuk(p3, "LAIN-LAIN")
saklar(p3, "Kunci kamera", "Layar beku saat bekerja — hemat render", S.KunciKamera, function(v)
    S.KunciKamera = v
    simpanConfig()
    if type(getgenv().SAEKunciKamera) == "function" then
        pcall(getgenv().SAEKunciKamera, v)
    end
end)
saklar(p3, "Anti AFK", "⚠️ MEMICU BAC KICK — jangan diaktifkan", S.AntiAfk, function(v)
    S.AntiAfk = v
    simpanConfig()
end)
tajuk(p3, "PERFORMA")
new("TextLabel", p3, {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Menghapus plot orang lain, aset render, efek, bayangan, dan suara. "
        .. "Egg taman cuma diinvis (dihapus = hatch tak menghasilkan pet). "
        .. "Permanen sampai rejoin.",
    TextColor3 = T.textLo,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = ord(),
    ZIndex = 3,
})
saklar(p3, "Boost FPS", "Berlaku juga untuk yang muncul kemudian", S.BoostFps, function(v)
    S.BoostFps = v
    simpanConfig()
    if v and type(getgenv().SAEBoostFps) == "function" then
        task.spawn(getgenv().SAEBoostFps)
    end
end)
tajuk(p3, "PET")
saklar(p3, "Auto equip best", "Menekan tombol Equip Best milik game", S.AutoEquipBest, function(v)
    S.AutoEquipBest = v
    simpanConfig()
end)
slider(p3, "Equip tiap", 15, 300, S.EquipBestTiapDetik, function(v)
    return v .. " detik"
end, function(v)
    S.EquipBestTiapDetik = v
    simpanConfig()
end)
local btnEquip = new("TextButton", p3, {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = T.layer3,
    Font = Enum.Font.GothamBold,
    Text = "Equip best sekarang",
    TextColor3 = T.textHi,
    TextSize = 12,
    AutoButtonColor = false,
    LayoutOrder = ord(),
    ZIndex = 3,
})
radius(btnEquip, 8)
stroke(btnEquip, 0.9)
btnEquip.MouseButton1Click:Connect(function()
    local f = getgenv().SAEEquipBest
    if type(f) ~= "function" then
        btnEquip.Text = "tekan Mulai dulu"
    else
        local ok, sebab = f()
        btnEquip.Text = ok and "✓ ter-equip" or ("gagal: " .. tostring(sebab):sub(1, 24))
    end
    task.delay(1.5, function()
        btnEquip.Text = "Equip best sekarang"
    end)
end)
tajuk(p3, "PINDAH SERVER")
local btnHop = new("TextButton", p3, {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = T.layer3,
    Font = Enum.Font.GothamBold,
    Text = "Hop sekarang",
    TextColor3 = T.textHi,
    TextSize = 12,
    AutoButtonColor = false,
    LayoutOrder = ord(),
    ZIndex = 3,
})
radius(btnHop, 8)
stroke(btnHop, 0.9)
btnHop.MouseButton1Click:Connect(function()
    local hop = getgenv().SAEHop
    if type(hop) == "function" then
        btnHop.Text = "memindahkan…"
        task.spawn(hop)
    else
        btnHop.Text = "tekan Mulai dulu"
        task.delay(1.5, function()
            btnHop.Text = "Hop sekarang"
        end)
    end
end)
local guiHidup = true
gui.Destroying:Connect(function()
    guiHidup = false
end)
local sudahLapor = false
task.spawn(function()
    while guiHidup do
        task.wait(4)
        local ok, err = pcall(gambarDaftar)
        if not ok and not sudahLapor then
            sudahLapor = true
            warn("[SAE] daftar Growing Eggs gagal digambar: " .. tostring(err))
        end
    end
end)
local footer = new("Frame", root, {
    Size = UDim2.new(1, -32, 0, 44),
    Position = UDim2.new(0, 16, 1, -60),
    BackgroundTransparency = 1,
    ZIndex = 3,
})
local btnMulai = new("TextButton", footer, {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.ember,
    Font = Enum.Font.GothamBold,
    Text = "Mulai",
    TextColor3 = T.textHi,
    TextSize = 13,
    AutoButtonColor = false,
    ZIndex = 3,
})
radius(btnMulai, 10)
local grad = new("UIGradient", btnMulai, {
    Rotation = 90,
    Color = ColorSequence.new(T.emberHi, T.ember),
})
stroke(btnMulai, 0.8)
btnMulai.MouseEnter:Connect(function()
    tween(btnMulai, EASE_S, { Size = UDim2.new(1, 0, 1, 2), Position = UDim2.fromOffset(0, -1) })
end)
btnMulai.MouseLeave:Connect(function()
    tween(btnMulai, EASE_S, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0) })
end)
local jalan = false
local mulaiKlik
mulaiKlik = function()
    jalan = not jalan
    S.Berjalan = jalan
    simpanConfig()
    getgenv().SAEConfig = S
    if jalan then
        btnMulai.Text = "Berhenti"
        grad.Color = ColorSequence.new(T.layer3, T.layer2)
        subJudul.Text = "Berjalan · " .. (RARITY[S.MinRarity] or "?") .. " ke atas"
        subJudul.TextColor3 = T.ok
        task.spawn(function()
            local sumber = SUMBER_STEAL
            local fn, compileErr = loadstring(sumber)
            if not fn then
                jalan = false
                btnMulai.Text = "Mulai"
                grad.Color = ColorSequence.new(T.emberHi, T.ember)
                local msg = "COMPILE ERROR: " .. tostring(compileErr)
                subJudul.Text = msg:sub(1, 80)
                subJudul.TextColor3 = T.emberHi
                warn("[SAE ERROR] " .. msg)
                return
            end
            local ok, runtimeErr = xpcall(fn, function(e)
                return tostring(e) .. "\n" .. debug.traceback()
            end)
            if not ok then
                jalan = false
                btnMulai.Text = "Mulai"
                grad.Color = ColorSequence.new(T.emberHi, T.ember)
                subJudul.Text = "RUNTIME ERROR: " .. tostring(runtimeErr):gsub("\n", " | "):sub(1, 80)
                subJudul.TextColor3 = T.emberHi
                warn("[SAE ERROR] RUNTIME: " .. tostring(runtimeErr))
            end
        end)
    else
        btnMulai.Text = "Mulai"
        grad.Color = ColorSequence.new(T.emberHi, T.ember)
        subJudul.Text = "Berhenti"
        subJudul.TextColor3 = T.warn
        if getgenv().StealAnEggStop then
            pcall(getgenv().StealAnEggStop)
        end
        if getgenv().SAEBerhentiHatch then
            pcall(getgenv().SAEBerhentiHatch)
        end
        if getgenv().SAEBerhentiHop then
            pcall(getgenv().SAEBerhentiHop)
        end
    end
end
btnMulai.MouseButton1Click:Connect(mulaiKlik)
if S.Berjalan then
    task.delay(1.5, function()
        if not jalan then
            mulaiKlik()
        end
    end)
end
do
    local seret, mulai, awal = false, nil, nil
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            seret, mulai, awal = true, i.Position, shell.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if seret and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - mulai
            local x = awal.X.Offset + d.X
            local y = awal.Y.Offset + d.Y
            local cam = workspace.CurrentCamera
            if cam then
                local vp = cam.ViewportSize
                local uk = shell.AbsoluteSize
                local sisaX, sisaY = uk.X / 2, uk.Y / 2
                x = math.clamp(x, -vp.X * 0.5 + sisaX - uk.X + 40,
                                   vp.X * 0.5 - sisaX + uk.X - 40)
                y = math.clamp(y, -vp.Y * 0.5 + sisaY,
                                   vp.Y * 0.5 - sisaY + uk.Y - 40)
            end
            shell.Position = UDim2.new(awal.X.Scale, x, awal.Y.Scale, y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            seret = false
        end
    end)
end
local kecil = false
btnMin.MouseButton1Click:Connect(function()
    kecil = not kecil
    nav.Visible = not kecil
    isi.Visible = not kecil
    footer.Visible = not kecil
    tween(shell, EASE, { Size = kecil and UDim2.fromOffset(428, 56) or UDim2.fromOffset(428, 580) })
    btnMin.Text = kecil and "□" or "‒"
end)
btnTutup.MouseButton1Click:Connect(function()
    if getgenv().StealAnEggStop then
        pcall(getgenv().StealAnEggStop)
    end
    tween(shell, EASE_S, { Size = UDim2.fromOffset(428, 0) })
    task.delay(0.16, function()
        gui:Destroy()
    end)
end)
shell.Size = UDim2.fromOffset(428, 0)
tween(shell, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Size = UDim2.fromOffset(428, 580),
})
getgenv().SAEGuiTutup = function()
    if gui then
        gui:Destroy()
    end
end

-- @MOZEFRAME-EOF@
