-- ==========================================
-- SISTEM VERIFIKASI HWID & DISCORD (MOZEFRAME)
-- ==========================================
local config = getgenv().MuzeAutoBuyConfig or {}
local raw_panel_key = config.PanelKey or ""
local panel_key = raw_panel_key
if string.find(raw_panel_key, "/") then
    panel_key = string.split(raw_panel_key, "/")[1]
end

-- ==== CONFIG GENERATOR MENANG ATAS PANEL ====
--
-- Tabel yang berisi LEBIH dari sekadar PanelKey pasti datang dari Config
-- Generator: loader biasa hanya menitipkan key. Kalau itu yang terjadi, setelan
-- di dalamnya harus dipakai apa adanya.
--
-- Kenapa ini perlu: dulu syncConfig() menyalin SELURUH config panel ke Config
-- (Config[k] = v), dan thread sync-nya menyala 0-30 detik sesudah start lalu
-- mengulang tiap 30 detik. Jadi setelan generator memang sempat berlaku, tapi
-- terhapus kurang dari setengah menit kemudian tanpa satu pun pesan -- dan akun
-- yang belum pernah disentuh panel malah mendapat DEFAULT SERVER, karena
-- hwid_bot.py membuatkan baris config baru saat sync pertama.
--
-- Sync sendiri TIDAK dimatikan: status, HWID, Live Monitor dan QuickAction
-- semuanya lewat jalur yang sama. Yang berhenti hanya penimpaan setelan.
_G.MozeConfigLokal = false
for k in pairs(config) do
    if k ~= "PanelKey" then
        _G.MozeConfigLokal = true
        break
    end
end

-- Salinan BEKU untuk titipan teleport.
--
-- `Config` di bawah adalah tabel getgenv() YANG SAMA dengan `config` di atas,
-- dan ia berubah saat runtime (QuickAction dihapus, AutoKeWorld2 dipaksa
-- false). Menyerahkannya langsung ke queue_on_teleport berarti menitipkan
-- keadaan runtime, bukan setelan asli buyer.
local function salinDalam(t)
    local hasil = {}
    for k, v in pairs(t) do
        hasil[k] = (type(v) == "table") and salinDalam(v) or v
    end
    return hasil
end
local CONFIG_ASLI_W1 = salinDalam(config)
local CONFIG_ASLI_W2 = salinDalam(getgenv().MuzeFallHarvestConfig or {})

-- URL server Railway (pengganti Firebase)
local SERVER_URL = "https://mozeframe.my.id"

-- Mendapatkan HWID
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

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")


local Networking = require(ReplicatedStorage.SharedModules.Networking)
local PlayerStateClient = require(ReplicatedStorage.ClientModules.PlayerStateClient)
local FruitValueCalc = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("FruitValueCalc"))
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

-- =========================================================================
-- FUNGSI REMOTE MAIL VIA WEB PANEL
-- =========================================================================

-- Batas milik server GaG2, dipastikan dari script game:
--   * Cooldown kirim 10 detik  (Cmdr "qamailpaircap": "...without sending 5
--     gifts through the 10s cooldown")
--   * 5 mail per penerima per hari (Game.Mailbox.PerRecipientDailyLimit --
--     argumen Count perintah itu menyebut "4 = one gift left before the cap")
--   * Kapasitas kotak masuk 100 (MailboxFlags.Capacity)
-- Ketiganya dipegang server dan TIDAK direplikasi ke client, jadi satu-satunya
-- cara mengetahui penolakan adalah dari nilai balik SendBatch.
--
-- Versi lama menunggu 8 detik -- DI BAWAH cooldown 10 detik. Batch pertama
-- lolos, sisanya ditolak, dan batch yang ditolak tidak pernah diulang: itu
-- sebabnya kiriman sedikit (muat 1 batch) selalu aman sementara kiriman banyak
-- hanya masuk sebagian dan harus dikirim dua kali.
local JEDA_MAIL = 11
local MAKS_ULANG_BATCH = 5

-- Cooldown berlaku untuk pengirimnya, bukan per penerima, jadi penghitungnya
-- harus global -- kalau per pemanggilan, batch pertama ke target kedua
-- langsung menabrak cooldown sisa dari target pertama.
local mailTerakhirKirim = 0

-- Sejak batch diulang, satu pengiriman bisa berjalan menit-an. Perintah kedua
-- yang masuk selagi yang pertama jalan akan memakai thread sendiri, dan tanpa
-- kunci keduanya bisa lolos gerbang cooldown pada detik yang sama lalu saling
-- menjatuhkan. Batas tunggunya dipasang supaya kunci yang tak sempat dilepas
-- (thread mati di tengah) tidak membekukan fitur mail sampai rejoin.
local mailSedangJalan = false

local function kunciMail()
    local batas = os.clock() + 180
    while mailSedangJalan and os.clock() < batas do
        task.wait(0.5)
    end
    mailSedangJalan = true
end

local function lepasKunciMail()
    mailSedangJalan = false
end

local function tungguCooldownMail()
    kunciMail()
    while true do
        local sisa = JEDA_MAIL - (os.clock() - mailTerakhirKirim)
        if sisa <= 0 then break end
        -- Dipotong 1 detik supaya thread ini tidak menahan eksekusi lama-lama
        -- dan status panel tetap ikut ter-update selama menunggu.
        task.wait(math.min(sisa, 1))
    end
end

_G.executeRemoteMail = function(targetUsername, lockedItemsToSend)
    local success, err = pcall(function()
        print("[Remote-Mail] Mengeksekusi pengiriman via Web Panel ke target: " .. tostring(targetUsername))
        
        local ok, targetId = pcall(function()
            return Networking.Mailbox.LookupPlayer:Fire(targetUsername)
        end)
        
        if not ok or not targetId or targetId <= 0 then
            -- Nama pengirim ikut dicatat supaya formatnya sama dengan entri lain
            -- ("[jam] pengirim > hasil > target") dan bisa ditelusuri per akun.
            local alasan = string.format("GAGAL (target '%s' tidak ada di sistem Mail)", tostring(targetUsername))
            _G.RemoteMailDebug = alasan
            local historyEntry = string.format("[%s] %s > %s > %s", os.date("%H:%M:%S"), LocalPlayer.Name, alasan, tostring(targetUsername))
            local req = (syn and syn.request) or request or http_request or (http and http.request)
            if req then
                req({
                    Url = SERVER_URL .. "/api/mail/log",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({ panel_key = raw_panel_key, log = historyEntry, timestamp = os.time(), target = targetUsername, batches = 0 })
                })
            end
            return
        end
        
        local replica = PlayerStateClient:GetLocalReplica()
        if not replica or not replica.Data or not replica.Data.Inventory then return end
        
        local inventory = replica.Data.Inventory
        local apiBatch = {}
        local sentCounts = {}

        -- Pencarian jumlah untuk sebuah item di dalam lockedItemsToSend.
        --
        -- Dulu satu loop saja dengan syarat `cleanName == cleanK or cleanName:find(cleanK)`
        -- dan langsung break. Karena pairs() tidak berurutan, "Poison Apple" bisa
        -- tersangkut kunci "Apple" lebih dulu dan terkirim memakai jumlah milik item
        -- lain -- hasilnya berbeda-beda tiap panggilan. Sekarang cocok-persis selalu
        -- diprioritaskan, substring hanya jadi cadangan.
        --
        -- find() juga dipaksa mode literal (plain=true): nama item mengandung
        -- karakter seperti "'" dan "(" yang kalau diperlakukan sebagai pola bisa
        -- salah cocok atau melempar error.
        local function cariJumlahItem(namaItem)
            local cleanName = string.lower(string.gsub(namaItem, "[ %-]", ""))
            for k, v in pairs(lockedItemsToSend) do
                if string.lower(string.gsub(k, "[ %-]", "")) == cleanName then
                    return v
                end
            end
            for k, v in pairs(lockedItemsToSend) do
                local cleanK = string.lower(string.gsub(k, "[ %-]", ""))
                if cleanK ~= "" and string.find(cleanName, cleanK, 1, true) then
                    return v
                end
            end
            return nil
        end
        
        for cat, catData in pairs(inventory) do
            if typeof(catData) == "table" and cat ~= "HarvestedFruits" then
                for itemKey, itemData in pairs(catData) do
                    local amount = 0
                    local actualItemKey = itemKey
                    local name = itemKey
                    
                    if typeof(itemData) == "number" then
                        amount = itemData
                    elseif typeof(itemData) == "table" then
                        amount = itemData.Amount or itemData.Count or itemData.Value or 1
                        actualItemKey = itemData.Id or itemData.ItemKey or itemKey
                        name = itemData.Name or itemData.DisplayName or itemData.ItemName or itemKey
                        if cat == "Pets" and itemData.Equipped then
                            continue
                        end
                    end
                    
                    if amount > 0 then
                        local exactAmount = cariJumlahItem(name)
                        
                        if exactAmount ~= nil then
                            if cat == "Pets" or (typeof(itemData) == "table" and itemData.Id) then
                                if not sentCounts[name] then sentCounts[name] = 0 end
                                if exactAmount == 0 or sentCounts[name] < exactAmount then
                                    table.insert(apiBatch, { Category = cat, ItemKey = actualItemKey, Count = 1 })
                                    sentCounts[name] = sentCounts[name] + 1
                                end
                            else
                                local toSend = tonumber(exactAmount)
                                if toSend == 0 or toSend > amount then
                                    toSend = amount
                                end
                                if toSend > 0 then
                                    table.insert(apiBatch, { Category = cat, ItemKey = actualItemKey, Count = toSend })
                                end
                            end
                        end
                    end
                end
            end
        end
        
        local function scanFruitsIn(container)
            if not container then return end
            for _, item in ipairs(container:GetChildren()) do
                local isFruit = item:GetAttribute("HarvestedFruit") == true
                if not isFruit and item:IsA("Tool") then
                    if item:GetAttribute("FruitName") or item:GetAttribute("Weight") or item:GetAttribute("Mutation") then
                        isFruit = true
                    end
                end
                
                if isFruit then
                    local id = item:GetAttribute("Id") or item.Name
                    if id then
                        local name = item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or item.Name
                        local exactAmount = cariJumlahItem(name)
                        
                        if exactAmount ~= nil then
                            if not sentCounts[name] then sentCounts[name] = 0 end
                            if exactAmount == 0 or sentCounts[name] < exactAmount then
                                table.insert(apiBatch, { Category = "HarvestedFruits", ItemKey = id, Count = 1 })
                                sentCounts[name] = sentCounts[name] + 1
                            end
                        end
                    end
                end
            end
        end
        
        scanFruitsIn(LocalPlayer:FindFirstChild("Backpack"))
        if LocalPlayer.Character then scanFruitsIn(LocalPlayer.Character) end
        
        if #apiBatch > 0 then
            getgenv().KaitunStatus = "Sending Mail..."
            print(string.format("[Remote-Mail] Terdeteksi %d item/pet/buah yang cocok. Memproses pengiriman...", #apiBatch))
            -- Batch dibentuk seluruhnya dulu, baru dikirim. Dengan begitu jumlah
            -- batch diketahui di depan, dan batch yang ditolak bisa diulang utuh
            -- tanpa harus menyusun ulang potongannya.
            local daftarBatch = {}
            local currentBatch = {}
            for i, item in ipairs(apiBatch) do
                table.insert(currentBatch, item)
                if #currentBatch == 20 or i == #apiBatch then
                    table.insert(daftarBatch, currentBatch)
                    currentBatch = {}
                end
            end

            -- 5 mail/hari/penerima x 20 item = 100 item per target per hari.
            -- Diberitahukan di depan supaya jelas sisanya bukan hilang karena bug.
            if #daftarBatch > 5 then
                print(string.format(
                    "[Remote-Mail] %d batch untuk %s, tapi batas server 5 mail/hari/penerima. "
                    .. "Maksimal ~100 item hari ini, sisanya akan ditolak.",
                    #daftarBatch, tostring(targetUsername)))
            end

            local batchOk, batchGagal, alasanGagal = 0, 0, nil
            local itemTerkirim, batasHarian = 0, false

            for nomor, batch in ipairs(daftarBatch) do
                if batasHarian then
                    -- Sisa batch tidak usah dicoba: batas harian baru lepas saat
                    -- hari berganti, bukan setelah menunggu.
                    batchGagal = batchGagal + 1
                else
                    local terkirim = false

                    for percobaan = 1, MAKS_ULANG_BATCH do
                        tungguCooldownMail()

                        getgenv().KaitunStatus = string.format(
                            "Sending Mail... (%d/%d)", nomor, #daftarBatch)

                        -- SendBatch adalah remote BER-RESPONS (ResponseTimeout=10) dan
                        -- mengembalikan (sukses, pesan). MailboxController milik game
                        -- membacanya persis begini: kalau `sukses` false, `pesan` berisi
                        -- alasan penolakan dari server.
                        --
                        -- Dulu kedua nilai itu dibuang -- pcall-nya bahkan tanpa penerima.
                        -- Akibatnya penolakan server tidak terlihat sama sekali, dan baris
                        -- riwayat "N Item" tetap ditulis walau tidak satu pun mail terkirim.
                        local ok, hasil, pesan = pcall(function()
                            return Networking.Mailbox.SendBatch:Fire(targetId, batch, "Delivery via Panel by MOZE FRAME(feng jiu)")
                        end)
                        -- Dicatat walau gagal: percobaan yang ditolak tetap
                        -- menyentuh server, jadi cooldown berikutnya dihitung
                        -- dari sini juga.
                        mailTerakhirKirim = os.clock()
                        lepasKunciMail()

                        if ok and hasil then
                            terkirim = true
                            break
                        end

                        local kabar
                        if not ok then
                            kabar = "error client: " .. tostring(hasil)
                        elseif type(pesan) == "string" and pesan ~= "" then
                            kabar = pesan
                        else
                            kabar = "ditolak server tanpa alasan"
                        end
                        alasanGagal = kabar

                        local kecil = string.lower(kabar)

                        -- "you cant gift item during the tutorial" -- akun masih
                        -- di tutorial di sisi server. Bypass startup kadang tidak
                        -- tercatat (lihat pastikanTutorialSelesai), jadi dipastikan
                        -- ulang DI SINI lalu percobaan berikutnya mencoba kirim
                        -- lagi. Bukan mentok -- jangan di-break.
                        if string.find(kecil, "tutorial", 1, true) and _G.pastikanTutorialSelesai then
                            print("[Remote-Mail] Ditolak karena tutorial -- menyelesaikan tutorial lalu retry...")
                            _G.pastikanTutorialSelesai(20)
                        else
                            local mentok = false
                            for _, kata in ipairs({ "limit", "cap", "daily", "today", "full", "maximum" }) do
                                if string.find(kecil, kata, 1, true) then
                                    mentok = true
                                    break
                                end
                            end
                            if mentok then
                                batasHarian = true
                                break
                            end
                        end

                        -- Kalau server menyebut sisa detiknya ("...in 7 seconds"),
                        -- patuhi angkanya daripada menebak.
                        local detik = tonumber(string.match(kecil, "(%d+)%s*second"))
                        if detik and detik > 0 then
                            task.wait(math.min(detik + 1, 30))
                        end
                    end

                    if terkirim then
                        batchOk = batchOk + 1
                        itemTerkirim = itemTerkirim + #batch
                    else
                        batchGagal = batchGagal + 1
                    end
                end
            end

            getgenv().KaitunStatus = "Idling & Monitoring..."
            print("[Remote-Mail] Pengiriman selesai. Batch OK=" .. batchOk .. " GAGAL=" .. batchGagal)

            local summaryParts = {}
            for name, count in pairs(sentCounts) do
                table.insert(summaryParts, count .. " " .. name)
            end
            local summaryString = table.concat(summaryParts, ", ")
            if summaryString == "" then summaryString = #apiBatch .. " Item" end

            -- Riwayat harus mencerminkan hasil sebenarnya, bukan sekadar "sudah dicoba".
            local totalBatch = batchOk + batchGagal
            -- Batas harian bukan kegagalan yang perlu diulang -- dibedakan supaya
            -- tidak terbaca sebagai error dan memancing kirim ulang percuma.
            local catatan = batasHarian
                and "batas 5 mail/hari untuk penerima ini sudah habis"
                or tostring(alasanGagal)
            local ringkasHasil
            if batchGagal == 0 then
                ringkasHasil = summaryString
            elseif batchOk == 0 then
                ringkasHasil = string.format("GAGAL (%d batch ditolak: %s)", totalBatch, catatan)
            else
                ringkasHasil = string.format("SEBAGIAN %s -- %d dari %d item terkirim (%d/%d batch gagal: %s)",
                    summaryString, itemTerkirim, #apiBatch, batchGagal, totalBatch, catatan)
            end
            _G.RemoteMailDebug = ringkasHasil .. " -> " .. tostring(targetUsername)

            local panelKey = panel_key ~= "" and panel_key or "Public"
            local historyEntry = string.format("[%s] %s > %s > %s", os.date("%H:%M:%S"), LocalPlayer.Name, ringkasHasil, targetUsername)
            local req = (syn and syn.request) or request or http_request or (http and http.request)
            if req then
                req({
                    Url = SERVER_URL .. "/api/mail/log",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({ panel_key = raw_panel_key, log = historyEntry, timestamp = os.time(), target = targetUsername, batches = #apiBatch })
                })
            end
        else
            -- apiBatch kosong: tidak satu pun jenis item yang diminta panel ada di
            -- inventory saat perintah benar-benar dijalankan. "Item tidak ada" saja
            -- tidak memberi tahu apa-apa, jadi jumlah yang diminta ikut dicatat --
            -- itu yang membedakan "panel minta 0 item" dari "inventory sudah kosong".
            local diminta = 0
            for _ in pairs(lockedItemsToSend) do diminta = diminta + 1 end
            local alasan = string.format("GAGAL (0 dari %d jenis item diminta ada di inventory)", diminta)
            _G.RemoteMailDebug = alasan .. " -> " .. tostring(targetUsername)

            local historyEntry = string.format("[%s] %s > %s > %s", os.date("%H:%M:%S"), LocalPlayer.Name, alasan, tostring(targetUsername))
            local req = (syn and syn.request) or request or http_request or (http and http.request)
            if req then
                req({
                    Url = SERVER_URL .. "/api/mail/log",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({ panel_key = raw_panel_key, log = historyEntry, timestamp = os.time(), target = targetUsername, batches = 0 })
                })
            end
        end
    end)
    if not success then
        warn("[Remote-Mail] Error: " .. tostring(err))
    end
end

local antiAfkEnabled = true

-- AUTO CLICK TENGAH LAYAR (TIAP 5 DETIK, SELAMA 5 MENIT / 60 KALI)
local function startAutoClick()
    if config.AutoClick or (getgenv().MuzeAutoBuyConfig and getgenv().MuzeAutoBuyConfig.AutoClick) then
        task.spawn(function()
            for i = 1, 60 do
                task.wait(5)
                pcall(function()
                    local cam = Workspace.CurrentCamera
                    if cam then
                        VirtualUser:Button1Down(Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2))
                        VirtualUser:Button1Up(Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2))
                    end
                end)
            end
        end)
    end
end

-- VARIABEL TRACKING HISTORY (FORMAT STACKING)
local PurchaseHistoryLog = {}

local function getItemCount(itemName)
    local replica = PlayerStateClient:GetLocalReplica()
    if not replica or not replica.Data or not replica.Data.Inventory then return 0 end
    
    local total = 0
    for _, catData in pairs(replica.Data.Inventory) do
        if typeof(catData) == "table" then
            for itemKey, itemVal in pairs(catData) do
                if itemKey == itemName then
                    if typeof(itemVal) == "number" then
                        total = total + itemVal
                    elseif typeof(itemVal) == "table" and (itemVal.Amount or itemVal.Count) then
                        total = total + (itemVal.Amount or itemVal.Count)
                    end
                elseif typeof(itemVal) == "table" and itemVal.Name == itemName then
                    total = total + 1
                end
            end
        end
    end
    return total
end

local function logPurchase(itemName, amountBought)
    amountBought = amountBought or 1
    -- Jika item yang baru dibeli sama dengan item paling atas, tambahkan jumlahnya
    if #PurchaseHistoryLog > 0 and PurchaseHistoryLog[1].name == itemName then
        PurchaseHistoryLog[1].count = PurchaseHistoryLog[1].count + amountBought
    else
        -- Jika beda, masukkan ke urutan paling atas (index 1)
        table.insert(PurchaseHistoryLog, 1, {name = itemName, count = amountBought})
    end
    
    -- Maksimal simpan 5 baris agar layar tidak penuh
    if #PurchaseHistoryLog > 5 then
        table.remove(PurchaseHistoryLog, 6)
    end
end

-- =========================================================================
-- MENGAMBIL KONFIGURASI DARI LUAR (GETGENV)
local Config = getgenv().MuzeAutoBuyConfig or {
    BlackScreen = true,
    BuySeeds = false,
    BuyGears = false,
    AutoSell = false,
    AutoSellThreshold = "0",   -- "0" = jual apa pun; isi mis. "50M" untuk nunggu nilai tertentu

    -- ==== MODE JUAL ====
    -- "0" = normal: jual semua isi inventory (perilaku lama).
    -- "2" / "4" = hanya jual jenis buah yang pengalinya mencapai angka itu di
    -- papan harga FruitStock, yang diacak ulang tiap 10 menit. Sisanya
    -- dibiarkan menunggu gilirannya, dan buah favorit tidak pernah ikut.
    -- Default "0" supaya akun yang belum diatur tetap berperilaku seperti dulu.
    AmbangPengali = "0",
    SellDelay = 30,            -- jeda antar siklus auto sell (detik)
    DailyDeal = false,
    DailyDealThreshold = "0",

    -- Tahan penjualan sampai tumpukan mencapai DailyDealThreshold, supaya
    -- deal 2,2x jatuh ke inventory besar dan bukan ke sisa panen kecil.
    -- DEFAULT MATI: menahan penjualan bisa merugikan (inventory penuh -> panen
    -- berhenti), jadi harus diminta sendiri lewat panel. Dua katup pengaman
    -- ada di bolehDailyDeal -- batas waktu, dan berhenti kalau nilainya tidak
    -- tumbuh lagi.
    TahanUntukDailyDeal = false,
    TahanDDMaksMenit = 30,     -- katup waktu; lewat ini, jual biasa
    Delay = 10,
    Seeds = {},
    Gears = {},
    
    -- SETTING AUTO TAME PET
    Pets = {},
    AutoTame = false,
    TamePets = {},
    MaxTameBid = "50M",

    -- Kriteria lepas-jenis. Kosong = tidak dipakai; fitur tetap jalan dengan
    -- TamePets saja, persis seperti sebelumnya.
    TameSizes = {},
    TameRainbow = false,
    
    -- FILTER BELI BERDASARKAN NILAI (per kategori)
    -- Mode: "off" (atau nil) = tidak menyaring, "above" = hanya yang lebih mahal
    -- dari batas, "below" = hanya yang lebih murah. Batas memakai format K/M/B
    -- yang sama dengan kolom harga lain, contoh "100M".
    SeedValueMode = "off",
    SeedValueThreshold = "0",
    GearValueMode = "off",
    GearValueThreshold = "0",
    PetValueMode = "off",
    PetValueThreshold = "0",

    -- ==== AUTO AUCTION: MATI SECARA DEFAULT ====
    --
    -- Fitur ini mengeluarkan sheckles tanpa konfirmasi, jadi butuh TIGA syarat
    -- sekaligus dan ketiganya gagal-tertutup:
    --
    --   1. AutoAuction == true   -- saklar eksplisit
    --   2. AuctionItems terisi   -- tidak ada item terpilih = tidak beli
    --   3. AuctionMaxBid > 0     -- batas kosong berarti TIDAK BELI, bukan bebas
    --
    -- AuctionMinSaldo adalah jaring terakhir: sheckles yang wajib tersisa.
    -- Kalau saldo tidak terbaca sama sekali, script juga tidak membeli.
    AutoAuction = false,
    AuctionItems = {},
    AuctionMaxBid = "0",
    AuctionMinSaldo = "0",

    -- SETTING LAINNYA
    Monitoring = false,
    AntiFreeze = true,

    -- Kunci yang sama dipakai form World 1 dan World 2 -- memang satu setelan,
    -- ditampilkan di dua tab. Default mati supaya akun yang panel-nya belum
    -- pernah mengirimnya tidak diam-diam meng-unfav buah yang sengaja dikunci.
    AutoUnfavFruit = false,


    -- ==== AUTO MAIL: MATI SECARA DEFAULT ====
    --
    -- Insiden 2026-08-02: default TargetUsername dulu "sayangniaaa" (akun
    -- bawaan). Akun mana pun yang panel-nya belum mengisi target ikut mengirim
    -- inventarisnya ke sana tiap 6 jam. Tercatat 326 kiriman dari 321 akun di
    -- 8 panel buyer yang berbeda sebelum ketahuan.
    --
    -- Memperbaiki nilai default saja TIDAK cukup, karena masih ada dua jalan
    -- lain menuju keadaan yang sama: config tersimpan yang basi, dan panel yang
    -- mengirim interval default saat kolomnya kosong. Karena itu sekarang
    -- dibutuhkan TIGA syarat sekaligus, dan ketiganya gagal-tertutup:
    --
    --   1. AutoMail == true      -- saklar eksplisit, harus dinyalakan sendiri
    --   2. ada target            -- daftar target tidak boleh kosong
    --   3. MailIntervalHours > 0 -- interval harus diisi sendiri
    --
    -- Config yang tidak menyebut ketiganya sama sekali TIDAK akan pernah
    -- mengirim mail apa pun.
    AutoMail = false,
    TargetUsername = "",
    MailIntervalHours = 0
}

-- Fallback untuk Config lama yang belum punya variabel BlackScreen
if Config.BlackScreen == nil then
    Config.BlackScreen = true
end
-- =========================================================================

-- =========================================================================
-- REMOTE CONTROL (WEB PANEL SYNC)
-- =========================================================================
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local HttpService = game:GetService("HttpService")
local LocalPlayer = game.Players.LocalPlayer

getgenv().KaitunStatus = "Memulai script..."

-- Dideklarasikan di sini karena handler QuickAction di bawah memakainya,
-- sedangkan definisinya ada jauh setelah blok ini. Tanpa forward declaration,
-- pemanggilan di dalam syncConfig akan mengenai global nil.
local PerformSell

-- nearSteven ikut di-forward-declare karena alasan yang SAMA, dan karena
-- ketiadaannya di jalur QuickAction adalah bug yang membuat tombol SellAll /
-- Daily Deal di panel "tidak melakukan apa-apa":
--
-- Di GaG2 penjualan HANYA diterima kalau pemain berada di dekat NPC Steven.
-- Jalur auto-sell selalu membungkusnya (`nearSteven(function() ... end)`),
-- tapi jalur tombol panel dulu memanggil PerformSell LANGSUNG dari posisi
-- farming. Server menolak, PreviewSellAll membalas FruitCount = 0, dan script
-- mencatat "[SKIP] Tidak ada buah untuk dijual" -- terbaca seperti inventory
-- kosong, bukan seperti kegagalan. Karena itu gejalanya "ga jalan samsek"
-- tanpa satu pun pesan error.
local nearSteven

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

-- Sengaja loader, bukan script ini langsung: routernya yang memilih script
-- sesuai place tujuan, jadi satu kode titipan ini benar untuk dunia mana pun.
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

-- SELESAI (dulu bertanda BELUM): titipan di bawah kini membawa SELURUH setelan,
-- bukan cuma PanelKey.
--
-- Ini WAJIB begitu config generator diprioritaskan. Sebelumnya titipan cukup
-- membawa key karena sisanya diisi ulang oleh sync sesudah mendarat; sekarang
-- sync tidak lagi menimpa, jadi titipan inilah SATU-SATUNYA pembawa setelan
-- melewati teleport. Kalau ia tetap cuma membawa PanelKey, bot yang pindah
-- dunia atau rejoin akan mendarat polos tanpa satu pun setelan.

-- Menyusun literal Lua dari tabel setelan. Kunci ditulis dalam bentuk ["nama"]
-- supaya nama dengan spasi ("Baby Cactus") maupun angka tetap sah.
local function tulisLua(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t ~= "table" then return "nil" end
    local bagian = {}
    for kk, vv in pairs(v) do
        local kunci
        if type(kk) == "string" then
            kunci = "[" .. string.format("%q", kk) .. "]="
        elseif type(kk) == "number" then
            kunci = "[" .. tostring(kk) .. "]="
        end
        -- Kunci bertipe lain (boolean/tabel) dibuang: tidak pernah ada di config
        -- mana pun, dan menuliskannya menghasilkan Lua yang tidak sah.
        if kunci then
            bagian[#bagian + 1] = kunci .. tulisLua(vv)
        end
    end
    return "{" .. table.concat(bagian, ",") .. "}"
end

local function kodeLanjutan()
    -- Kedua nama config diisi karena tujuannya bisa GaG2 maupun Fall Harvest,
    -- dan masing-masing script membaca nama yang berbeda. Setelan W2 diteruskan
    -- APA ADANYA dari titipan asli -- script W1 tidak pernah memegang config
    -- World 2, jadi ia hanya boleh meneruskan, bukan menyusun ulang.
    local w1 = salinDalam(CONFIG_ASLI_W1)
    local w2 = salinDalam(CONFIG_ASLI_W2)
    w1.PanelKey = raw_panel_key
    w2.PanelKey = raw_panel_key
    return string.format(
        "getgenv().MuzeAutoBuyConfig = %s\n" ..
        "getgenv().MuzeFallHarvestConfig = %s\n" ..
        "loadstring(game:HttpGet(%q))()",
        tulisLua(w1), tulisLua(w2), URL_LOADER)
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
            _G.KaitunSyncDebug = "[TP] Executor tanpa queue_on_teleport - andalkan autoexec"
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
        _G.KaitunSyncDebug = "[TP GAGAL] " .. keterangan .. " -> " .. tostring(alasanGagalTP)
        getgenv().KaitunStatus = "Teleport gagal, ulang..."
        task.wait(jeda)
    end
    _G.KaitunSyncDebug = "[TP MENYERAH] " .. keterangan
    return false
end

-- ==========================================================
-- PINDAH DUNIA LEWAT JALUR RESMI GAME
-- ==========================================================
-- Remote yang sama dengan yang ditembak NPC Ethan saat pemain memilih dunia:
--   EventWorldsTeleporterController -> Networking.Worlds.RequestTravel:Fire(id)
--
-- Ini lebih baik daripada TeleportService:Teleport(placeId) karena SERVER yang
-- memilih place tujuan. Daftar dunia punya PlaceType dan BotPlaceType terpisah
-- ("BotUser", "FallHarvestBotUser"), jadi akun yang ditandai bot diarahkan ke
-- place yang berbeda. Menembak PlaceId sendiri mengabaikan routing itu -- itu
-- sebabnya dulu tombol GaG2 sempat mendaratkan akun di versi khusus bot.
--
-- Id dunia yang sah: "Main" (Garden Valley) dan "FallHarvest".
local DUNIA_ID = {
    TP_GAG2 = "Main",
    TP_FALL = "FallHarvest",
}

-- Place per dunia. Dipegang di sini, bukan di panel: panel hanya mengirim
-- kodenya, jadi kalau Roblox mengganti place cukup satu tempat yang diperbarui.
--
-- Satu dunia bisa punya BEBERAPA place, dan tidak semua bisa dituju langsung.
-- Universe ini rootPlaceId-nya 97598239454123 (GaG2); kedua place Fall Harvest
-- adalah non-root, jadi hanya bisa dimasuki lewat teleport dari dalam universe --
-- dan belum tentu keduanya menerima. Karena itu didaftar sebagai kandidat dan
-- dicoba berurutan. Terpantau 2026-08-03: akun bot mendarat di 126987765280963,
-- varian "FallHarvestBotUser", bukan di kandidat pertama.
local PLACE_DUNIA = {
    TP_GAG2 = { 97598239454123 },
    TP_FALL = { 129343810645058, 126987765280963 },
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

    -- Jawaban server DIDENGARKAN, bukan ditunggu buta.
    --
    -- RequestTravel tidak mengembalikan apa pun; server menjawab lewat
    -- Worlds.TravelStarted atau Worlds.TravelFailed (terverifikasi di server
    -- hidup 2026-08-03). Versi sebelumnya menunggu 15 detik penuh untuk SETIAP
    -- percobaan, jadi permintaan yang ditolak seketika tetap memakan 15 detik --
    -- dan begitu perpindahan dicoba berulang otomatis, itu menumpuk jadi
    -- menit-menit diam yang terbaca seperti bot menggantung.
    local jawab, alasanTolak = nil, nil
    local ikatan = {}
    pcall(function()
        local W = require(ReplicatedStorage.SharedModules.Networking).Worlds
        ikatan[#ikatan + 1] = W.TravelStarted.OnClientEvent:Connect(function()
            jawab = "mulai"
        end)
        ikatan[#ikatan + 1] = W.TravelFailed.OnClientEvent:Connect(function(a)
            jawab, alasanTolak = "gagal", tostring(a or "")
        end)
    end)

    local function lepasIkatan()
        for _, c in ipairs(ikatan) do pcall(function() c:Disconnect() end) end
        ikatan = {}
    end

    local ok = pcall(function()
        require(ReplicatedStorage.SharedModules.Networking).Worlds.RequestTravel:Fire(worldId)
    end)

    if ok then
        _G.KaitunSyncDebug = "[PINDAH] RequestTravel -> " .. tostring(worldId)

        local batas = tick() + 15
        while tick() < batas and jawab == nil do task.wait(0.25) end

        if jawab == "mulai" then
            -- Server menerima. Place ini akan dibongkar dan thread ini mati
            -- dengan sendirinya -- yang tersisa hanya menunggu. Jangan jatuh ke
            -- TeleportService di bawah: menembak place sendiri saat perpindahan
            -- resmi sedang berjalan justru bisa mendaratkan kita di varian yang
            -- salah, dan itu persis masalah yang jalur resmi ini hindari.
            lepasIkatan()
            _G.KaitunSyncDebug = "[PINDAH] Diterima server, menunggu dipindahkan"
            local tunggu = tick() + 20
            while tick() < tunggu do task.wait(0.5) end
            return true
        elseif jawab == "gagal" then
            _G.KaitunSyncDebug = "[PINDAH] Ditolak server: " .. tostring(alasanTolak)
        end
    end

    lepasIkatan()

    -- Jalur resmi tidak menghasilkan apa-apa. Baru sekarang paksa lewat
    -- TeleportService, dengan risiko mendarat di place yang salah varian.
    _G.KaitunSyncDebug = "[PINDAH] Jalur resmi diam, coba TeleportService"
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
-- AUTO KEMBALI KE WORLD 2
-- ==========================================================
-- Fall Harvest hanya bisa dimasuki DARI GaG2, dan rejoin selalu mendarat di
-- GaG2 -- bukan di dunia tempat akun terputus. Jadi tiap kali koneksi putus,
-- akun World 2 diam-diam berubah jadi akun World 1: router membaca PlaceId lalu
-- memuat script GaG2, panel melihatnya "jalan normal", padahal kebun Fall
-- Harvest-nya berhenti diurus.
--
-- PENGAWAS, bukan pemeriksaan sekali jalan. Versi sebelumnya memeriksanya satu
-- kali di urutan startup tepat sesudah tutorial, dan itu TERLALU CEPAT: pada
-- detik itu Config baru berisi PanelKey dari loader -- seluruh setelan lain baru
-- tiba lewat sync pertama beberapa detik kemudian. Jadi Config.AutoKeWorld2
-- hampir selalu masih nil saat diperiksa, blok itu terlewat diam-diam, dan
-- gejalanya persis "sudah dicentang di panel tapi akun diam saja".
--
-- Bentuk pengawas juga menutup kasus kedua yang sama seringnya: opsi dinyalakan
-- SAAT akun sudah berjalan. Pemeriksaan sekali jalan tidak akan pernah melihatnya.
task.spawn(function()
    -- Jeda awal: modul Worlds baru terisi setelah dunia selesai dimuat, dan sync
    -- pertama butuh beberapa detik untuk membawa setelan dari panel.
    task.wait(15)

    while true do
        if Config.AutoKeWorld2 then
            local dunia = duniaSekarang()

            if dunia == nil then
                -- Diam lebih aman daripada menebak. Kalau dunianya tidak
                -- terbaca, memaksa pindah bisa melempar akun yang sudah benar
                -- keluar dari dunianya.
                _G.KaitunSyncDebug = "[W2] Dunia belum terbaca, menunggu"

            elseif dunia ~= DUNIA_ID.TP_FALL then
                getgenv().KaitunStatus = "Kembali ke World 2..."
                _G.KaitunSyncDebug = string.format(
                    "[W2] Terdeteksi di %s — pindah ke Fall Harvest", tostring(dunia))

                pindahDunia(DUNIA_ID.TP_FALL, PLACE_DUNIA.TP_FALL)

                -- Jeda panjang setelah satu percobaan. Kalau perpindahannya
                -- berhasil, thread ini mati bersama place-nya dan jeda tidak
                -- berarti apa-apa. Kalau ditolak -- biasanya place tujuan penuh
                -- -- mencoba lagi seketika hanya menembaki server yang sedang
                -- menolak.
                task.wait(30)
            end
        end
        task.wait(10)
    end
end)

local function syncConfig()
    -- Tanpa guard ini, akun berjalan seolah normal tapi datanya menulis ke
    -- KaitunClients//{username} di server; Firebase menggabungkan "//" sehingga
    -- record mendarat di top-level dan akun TIDAK PERNAH muncul di panel.
    if not raw_panel_key or raw_panel_key:gsub("%s", "") == "" then
        _G.KaitunSyncDebug = "[FATAL] PanelKey kosong. Akun ini tidak akan muncul di panel. Copy ulang snippet dari web panel setelah login."
        warn("[KAITUN] " .. _G.KaitunSyncDebug)
        return
    end

    if not httprequest then
        _G.KaitunSyncDebug = "[FATAL] Executor tidak mendukung HTTP request. Sync mati total."
        warn("[KAITUN] " .. _G.KaitunSyncDebug)
        return
    end

    local ok, err = pcall(function()
        local currentShekels = 0
        if LocalPlayer:FindFirstChild("leaderstats") then
            for _, currencyName in ipairs({"Sheckles", "Coins", "Tokens", "Money", "Cash", "Gems", "Shekels"}) do
                local stat = LocalPlayer.leaderstats:FindFirstChild(currencyName)
                if stat then
                    currentShekels = stat.Value
                    break
                end
            end
        end
        
        -- Penanda dunia. Tanpa ini panel tidak bisa membedakan akun yang jalan di
        -- GaG2 dari yang sudah pindah ke Fall Harvest -- dan penguncian edit config
        -- untuk World 2 ikut tidak bisa bekerja.
        local NAMA_DUNIA = {
            [97598239454123]  = "Grow a Garden 2",
            [129343810645058] = "Fall Harvest",
        }

        local data = {
            username = LocalPlayer.Name,
            panel_key = raw_panel_key,
            -- Detak per DEVICE untuk perhitungan slot HWID.
            --
            -- username saja tidak cukup: satu PC bisa menjalankan beberapa akun
            -- Roblox, jadi dari username server tidak bisa menyimpulkan berapa
            -- device yang hidup. Tanpa field ini last_seen device hanya terisi
            -- sekali saat verify_login, lalu dianggap offline 3 menit kemudian
            -- meski script-nya masih jalan -- dan slotnya direbut device lain.
            hwid = hwid,
            status = tostring(getgenv().KaitunStatus or "Idling") .. " [FB:" .. ((game.Players.LocalPlayer:GetAttribute("Friends") or 0) * 10) .. "%] [DD:" .. tostring(getgenv().DDStatus or "?") .. "]",
            shekels = currentShekels,
            world = game.PlaceId,
            world_name = NAMA_DUNIA[game.PlaceId] or "Unknown",
            -- Identitas server. Dipakai panel untuk mengumpulkan akun ke satu
            -- server: satu akun jadi tuan rumah, sisanya diarahkan ke JobId ini.
            job_id = game.JobId,

            --[[ ALASAN GAGAL JUAL IKUT DIKIRIM.

                 PerformSell dan startAutoDailyDeal sudah lama mencatat kenapa
                 mereka berhenti ("[SKIP] Tidak ada buah untuk dijual",
                 "[GAGAL] PreviewSellAll error: ...", "[TUNGGU] x < threshold"),
                 tapi catatan itu berhenti di konsol client. Dari sisi kita
                 keluhan buyer karena itu selalu sampai sebagai "ga work" tanpa
                 satu pun keterangan, dan tiap diagnosis jadi tebakan.

                 Dipotong 120 karakter: ini menempel di sync tiap 30 detik dan
                 tidak ada gunanya membawa jejak panjang. ]]
            sell_debug = tostring(_G.AutoSellDebug or ""):sub(1, 120),
            deal_debug = tostring(_G.DailyDealDebug or ""):sub(1, 120),
        }
        
        local response = httprequest({
            Url = "https://mozeframe.my.id/api/kaitun/sync",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
        
        if not response then
            _G.KaitunSyncDebug = "[GAGAL] Tidak ada response dari server."
            return
        end

        if response.StatusCode ~= 200 then
            -- Server sekarang membalas 400 dengan alasan jelas kalau panel_key invalid
            _G.KaitunSyncDebug = string.format("[GAGAL] HTTP %s: %s",
                tostring(response.StatusCode), tostring(response.Body):sub(1, 200))
            return
        end

        _G.KaitunSyncDebug = string.format("[OK] Sync %s", os.date("%H:%M:%S"))

        if response and response.StatusCode == 200 then
            local resData = HttpService:JSONDecode(response.Body)
            if resData.status == "success" and resData.config then
                -- QuickAction DIKECUALIKAN dari gerbang config lokal.
                --
                -- Ia bukan setelan melainkan perintah sekali pakai (tombol
                -- SellAll / Daily Deal / JOIN di panel), dan handler di bawah
                -- membacanya dari Config.QuickAction. Kalau ikut diblokir,
                -- tombol-tombol panel mati diam-diam untuk semua akun yang
                -- memakai config generator.
                for k, v in pairs(resData.config) do
                    if k == "QuickAction" or not _G.MozeConfigLokal then
                        Config[k] = v
                    end
                end

                -- ==== BERSIHKAN KEY USANG ====
                -- AutoKeWorld2 sudah dihapus dari panel dan tidak relevan untuk
                -- script W1. Kalau masih tersimpan di database config akun lama,
                -- ia tetap disalin oleh loop di atas dan memicu watchdog teleport
                -- ke W2 tanpa sebab. Paksa matikan di sini.
                Config.AutoKeWorld2 = false

                -- ==== MAPPING KEY PANEL → SCRIPT ====
                -- Panel mengirim "AutoBeli" (boolean) dan "SeedTarget" (array),
                -- tapi script ini membaca "BuySeeds" (boolean) dan "Seeds"
                -- (dictionary {nama: true}). Tanpa mapping ini, seed tidak
                -- pernah dibeli meski panel sudah di-set — terukur 2026-08-08.
                --
                -- Ikut dilewati saat config lokal dipakai: seluruh blok ini
                -- menulis ke Config dari payload panel, jadi tanpa gerbang ini
                -- setelan generator tetap tertimpa lewat pintu belakang.
                if not _G.MozeConfigLokal then
                if resData.config.AutoBeli ~= nil then
                    Config.BuySeeds = resData.config.AutoBeli
                end
                -- SeedTarget (W2: array → dictionary) atau Seeds (W1: sudah dictionary)
                if type(resData.config.Seeds) == "table" and next(resData.config.Seeds) then
                    Config.Seeds = resData.config.Seeds
                elseif type(resData.config.SeedTarget) == "table" and #resData.config.SeedTarget > 0 then
                    Config.Seeds = {}
                    for _, nama in ipairs(resData.config.SeedTarget) do
                        Config.Seeds[nama] = true
                    end
                end
                -- GearTarget (W2: array → dictionary) atau Gears (W1: sudah dictionary)
                -- Gears (W1) diprioritaskan: satu payload panel membawa keduanya,
                -- dan default W2 (Syrup Sprinkler/Syrup Watering Can) akan meng-
                -- overwrites gear W1 kalau GearTarget dicek duluan.
                if type(resData.config.Gears) == "table" and next(resData.config.Gears) then
                    Config.Gears = resData.config.Gears
                elseif type(resData.config.GearTarget) == "table" and #resData.config.GearTarget > 0 then
                    Config.Gears = {}
                    for _, nama in ipairs(resData.config.GearTarget) do
                        Config.Gears[nama] = true
                    end
                end
                end -- tutup gerbang _G.MozeConfigLokal

                -- [DEBUG VISUAL UNTUK USER]
                print("========================================")
                -- Kalimatnya dibedakan supaya log tidak berbohong: saat config
                -- lokal dipakai, yang dicetak di bawah adalah setelan GENERATOR
                -- yang bertahan, bukan yang baru datang dari panel.
                print(_G.MozeConfigLokal
                    and "[WEB-SYNC] Config generator DIPAKAI — payload panel diabaikan"
                    or  "[WEB-SYNC] Config terbaru diterima dari panel!")
                print("-> Auto Buy Seeds: " .. tostring(Config.BuySeeds))
                local s_str = ""
                local s_count = 0
                if type(Config.Seeds) == "table" then
                    for itemName, isEnabled in pairs(Config.Seeds) do
                        if isEnabled then 
                            s_str = s_str .. itemName .. ", " 
                            s_count = s_count + 1
                        end
                    end
                else
                    s_str = tostring(Config.Seeds)
                end
                print("-> Total Seed Dicentang: " .. tostring(s_count) .. " (" .. (s_str == "" and "KOSONG" or s_str) .. ")")
                print("========================================")
                
                -- PROSES QUICK ACTION
                if Config.QuickAction then
                    local act = Config.QuickAction
                    Config.QuickAction = nil

                    task.spawn(function()
                        -- Fall Harvest hanya bisa dimasuki dari GaG2, jadi tombol
                        -- ini yang menggantikan langkah login manual itu.
                        -- Daftar place-nya dipegang di PLACE_DUNIA (level berkas)
                        -- supaya tombol manual dan auto-kembali memakai daftar
                        -- yang SAMA -- dua salinan pasti akan berbeda suatu hari.
                        --
                        -- "JOIN|<placeId>|<jobId>" -- masuk ke server tertentu.
                        -- Universe ini melarang private server (createVipServersAllowed
                        -- = false), tapi server cuma muat 8 orang. Mengumpulkan 8 akun
                        -- sendiri ke satu JobId memberi efek yang sama: tidak ada orang
                        -- luar yang mencuri tanaman atau merebut seed jatuhan.
                        if type(act) == "string" and string.sub(act, 1, 5) == "JOIN|" then
                            local pid, jid = string.match(act, "^JOIN|(%d+)|(.+)$")
                            pid = tonumber(pid)
                            if pid and jid and jid ~= "" then
                                if game.JobId == jid then
                                    _G.KaitunSyncDebug = "[LEWAT] Sudah di server tujuan"
                                    return
                                end
                                getgenv().KaitunStatus = "Pindah server..."
                                _G.KaitunSyncDebug = "[KUMPUL] Menuju server " .. string.sub(jid, 1, 8)
                                local berhasil = teleportAman(function()
                                    TeleportService:TeleportToPlaceInstance(pid, jid, LocalPlayer)
                                end, "server " .. string.sub(jid, 1, 8))

                                -- Server cuma muat 8 orang. Kalau JobId tujuan
                                -- sudah penuh, mengulanginya percuma -- lebih
                                -- baik tetap mendarat di dunia yang benar
                                -- daripada tertinggal di server lama.
                                if not berhasil then
                                    _G.KaitunSyncDebug = "[KUMPUL] Server penuh, masuk acak"
                                    teleportAman(function()
                                        TeleportService:Teleport(pid, LocalPlayer)
                                    end, "place " .. tostring(pid))
                                end
                            end
                            return
                        end

                        local kandidat = PLACE_DUNIA[act]
                        if kandidat then
                            -- Dibandingkan lewat Worlds.CurrentId, bukan PlaceId.
                            -- Satu dunia punya banyak place (shard + varian bot),
                            -- jadi PlaceId tidak bisa dipakai untuk memastikan
                            -- kita sudah berada di dunia yang dimaksud.
                            local tujuanId = DUNIA_ID[act]
                            if tujuanId and duniaSekarang() == tujuanId then
                                _G.KaitunSyncDebug = "[LEWAT] Sudah berada di dunia tujuan"
                                return
                            end

                            getgenv().KaitunStatus = "Pindah dunia..."
                            pindahDunia(tujuanId, kandidat)
                            return
                        end

                        if act == "C" then
                            pcall(function() Networking.Mailbox.ClaimAll:Fire() end)
                            task.wait(1.5)
                            local ok, inbox = pcall(function() return Networking.Mailbox.OpenInbox:Fire() end)
                            if ok and typeof(inbox) == "table" then
                                for id in pairs(inbox) do
                                    pcall(function() Networking.Mailbox.Claim:Fire(id) end)
                                    task.wait(0.3)
                                end
                            end
                        elseif act == "DD" or act == "S" then
                            -- Tunggu definisi PerformSell DAN nearSteven siap
                            -- (sync pertama bisa menyusul sebelum body script
                            -- selesai dieksekusi)
                            for _ = 1, 50 do
                                if PerformSell and nearSteven then break end
                                task.wait(0.1)
                            end

                            if PerformSell and nearSteven then
                                -- DIBUNGKUS nearSteven, sama seperti jalur auto-sell.
                                --
                                -- PerformSell menjalankan PreviewSellAll dulu supaya
                                -- server men-stage transaksinya. Tapi staging saja tidak
                                -- cukup: GaG2 hanya menerima penjualan dari pemain yang
                                -- BERADA DEKAT Steven. Dipanggil langsung dari posisi
                                -- farming, PreviewSellAll membalas FruitCount = 0 dan
                                -- semuanya berhenti tanpa error -- itulah sebabnya tombol
                                -- panel dulu tampak "tidak melakukan apa-apa".
                                --
                                -- nearSteven memindahkan karakter, menjalankan penjualan,
                                -- lalu MENGEMBALIKANNYA ke posisi semula, jadi farming
                                -- tidak tertinggal di tempat yang salah.
                                local hasil = nearSteven(function()
                                    return PerformSell(act == "DD")
                                end)
                                if not hasil then
                                    _G.AutoSellDebug = (_G.AutoSellDebug or "")
                                        .. " | QuickAction " .. tostring(act) .. " tidak menjual apa pun"
                                end
                            else
                                _G.AutoSellDebug = "[GAGAL] PerformSell/nearSteven belum siap."
                            end
                        end
                    end)
                    
                    pcall(function()
                        httprequest({
                            Url = "https://mozeframe.my.id/api/kaitun/clear_action?panel_key="..HttpService:UrlEncode(raw_panel_key).."&username="..HttpService:UrlEncode(LocalPlayer.Name),
                            Method = "GET"
                        })
                    end)
                end
                
                print("[KAITUN] Config berhasil disinkronisasi dengan Web Panel.")
            end
        end
    end)

    if not ok then
        _G.KaitunSyncDebug = "[ERROR] " .. tostring(err)
        warn("[KAITUN] Sync error: " .. tostring(err))
    end
end

-- Interval dijaga tetap 30 detik: ambang status di panel (Online <=30 dtk,
-- Delay <=120 dtk) dihitung dari LastSync, jadi memperlambat sync akan membuat
-- akun sehat tampil "Delay" terus.
--
-- Yang diacak adalah fasenya. Tanpa ini, ratusan akun yang start berbarengan
-- -- atau rejoin serentak lewat setupAutoReconnect setelah Roblox/server
-- bermasalah -- akan sync pada detik yang sama dan tetap sefase selamanya,
-- memaku beban rata-rata menjadi lonjakan berulang tiap 30 detik.
-- Random.new() disemai dari sumber OS per client. math.random dihindari di sini
-- karena state globalnya bisa sama antar client -- offset-nya akan identik dan
-- jitternya tidak berguna -- sekaligus supaya math.random yang dipakai bagian
-- lain script tidak ikut tergeser.
local syncRng = Random.new()

-- =========================================================================
-- SYNC LOOP DENGAN HEALTH CHECK
-- =========================================================================
-- Kalau syncConfig() tidak pernah berhasil (panel_key invalid, network down),
-- Config tetap default dan auto buy mati tanpa pesan error yang jelas.
-- Health check: setelah 3 sync cycle tanpa perubahan BuySeeds, paksa retry
-- lebih cepat dan log peringatan.
task.spawn(function()
    local syncFailStreak = 0
    local lastBuySeeds = nil

    -- Offset awal membubarkan kawanan yang start bersamaan
    task.wait(syncRng:NextNumber(0, 30))
    while true do
        syncConfig()

        -- Health check: lacak apakah config sudah berubah dari default
        if Config.BuySeeds ~= lastBuySeeds then
            lastBuySeeds = Config.BuySeeds
            syncFailStreak = 0
        else
            syncFailStreak = syncFailStreak + 1
        end

        -- Kalau BuySeeds=true tapi Seeds kosong, itu anomali — kemungkinan
        -- panel mengirim BuySeeds tanpa SeedTarget, atau sync terpotong.
        if Config.BuySeeds and (not Config.Seeds or next(Config.Seeds) == nil) then
            warn("[SYNC] ⚠ BuySeeds=true tapi Seeds KOSONG! Retry dalam 10 detik...")
            _G.KaitunSyncDebug = "[ANOMALI] BuySeeds=true, Seeds kosong — retry"
            task.wait(10)
            syncConfig()
        end

        -- Kalau 5 siklus berturut-turut config tidak berubah, paksa retry cepat
        if syncFailStreak >= 5 then
            warn("[SYNC] ⚠ Config tidak berubah selama " .. syncFailStreak .. " siklus. Retry cepat...")
            _G.KaitunSyncDebug = "[PERINGATAN] Config stale — retry cepat"
            task.wait(10)
            syncConfig()
            syncFailStreak = 0
        end

        -- Jitter per siklus menjaga agar tidak menyatu fase lagi setelah
        -- gangguan. Dibatasi 2 detik: ambang "Online" di panel 30 detik
        -- dihitung dari LastSync, jadi periode yang terlalu longgar membuat
        -- akun sehat berkedip kuning "Delay".
        task.wait(syncRng:NextNumber(30, 32))
    end
end)
-- =========================================================================
-- =========================================================================

-- 1. BYPASS TUTORIAL
--
-- Diukur langsung 2026-08-03 di akun yang memang sedang tutorial:
--     Networking.Tutorial.Complete:Fire()
--         -> Player.TutorialCompleted   false -> true   (server terima, TANPA staging)
--         -> Workspace.InTutorial        TETAP true
--
-- Di situ jebakannya. `InTutorial` dihapus oleh TutorialRunner MILIK KLIEN, di
-- baris tepat sesudah Fire()-nya sendiri -- bukan oleh server. Runner itu masih
-- menggantung menunggu langkah dialog "Sell Inventory!" yang tidak akan pernah
-- kita kerjakan, jadi atributnya tidak akan hilang dengan sendirinya.
--
-- Karena itu bersihkan sendiri di sini. Kalau tidak, script menunggu akibat dari
-- sesuatu yang tidak pernah ia lakukan.
-- Sisa yang ditinggalkan tutorial kalau runner-nya tidak pernah selesai:
-- gerbang lokal InTutorial, overlay TutorialUI yang menutupi layar, dan scroll
-- daftar shop yang dikunci di langkah "beli benih".
local function bersihkanSisaTutorial()
    pcall(function()
        Workspace:SetAttribute("InTutorial", nil)
    end)
    pcall(function()
        local char = LocalPlayer.Character
        if char then char:SetAttribute("InTutorial", nil) end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        -- cari SEMUA ScreenGui yang namanya mengandung "tutorial" (case-insensitive)
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and string.find(gui.Name:lower(), "tutorial", 1, true) then
                gui.Enabled = false
            end
        end
        -- fallback: FindFirstChild recursive kalau nama tidak cocok di level atas
        local ui = pg:FindFirstChild("TutorialUI", true)
            or pg:FindFirstChild("TutorialScreen", true)
            or pg:FindFirstChild("TutorialFrame", true)
        if ui and ui:IsA("ScreenGui") then ui.Enabled = false end

        local shop = pg:FindFirstChild("SeedShop", true)
        local frame = shop and shop:FindFirstChild("Frame")
        local normal = frame and frame:FindFirstChild("NormalShop")
        if normal then normal.ScrollingEnabled = true end
    end)
end

-- Selesaikan tutorial, DIULANG sampai server mengakui (TutorialCompleted=true).
--
-- Diukur 2026-08-03: satu Complete:Fire() menaikkan TutorialCompleted
-- false->true -- TAPI tidak selalu. Kalau tembakan pertama balapan dengan
-- TutorialRunner klien atau server belum siap menerima, atributnya tetap false
-- dan akun TERJEBAK di tutorial. Server lalu menolak gift mail dengan
-- "you cant gift item during the tutorial". Itu sebabnya di sini ditembak
-- BERULANG, bukan sekali seperti versi lama.
--
-- Lewat _G supaya Remote Mail (didefinisikan jauh di ATAS fungsi ini) bisa
-- memanggilnya ulang tepat sebelum mengirim.
function _G.pastikanTutorialSelesai(batasDetik)
    batasDetik = batasDetik or 20
    if LocalPlayer:GetAttribute("TutorialCompleted") == true then
        bersihkanSisaTutorial()
        return true
    end

    -- Pastikan Networking sudah loaded. Kalau belum, coba load manual.
    if not Networking then
        pcall(function()
            Networking = require(ReplicatedStorage.SharedModules.Networking)
        end)
    end
    if not Networking or not Networking.Tutorial or not Networking.Tutorial.Complete then
        warn("[1/6] Bypass tutorial: Networking.Tutorial.Complete tidak tersedia!")
        return false
    end

    print("[1/6] Bypass tutorial (loop sampai server mengakui)...")
    local mulai = os.clock()
    while LocalPlayer:GetAttribute("TutorialCompleted") ~= true
          and os.clock() - mulai < batasDetik do
        pcall(function() Networking.Tutorial.Complete:Fire() end)
        bersihkanSisaTutorial()
        -- Tunggu sebentar tiap tembakan, lalu tembak lagi kalau server belum ngaku.
        local tembak = os.clock()
        while LocalPlayer:GetAttribute("TutorialCompleted") ~= true
              and os.clock() - tembak < 1.5 do
            task.wait(0.25)
        end
    end

    local selesai = LocalPlayer:GetAttribute("TutorialCompleted") == true
    if selesai then
        print("[1/6] Tutorial selesai (TutorialCompleted=true)")
    else
        print("[!] Bypass tutorial: server belum mengakui setelah " .. batasDetik .. " detik.")
    end
    return selesai
end

local function completeTutorialInstantly()
    return _G.pastikanTutorialSelesai(20)
end

-- 2. TELEPORT KE STEVEN
local function teleportToSteven()
    print("[2/6] Teleport ke Steven...")
    local steven = Workspace:FindFirstChild("Steven", true)
    
    if not steven then
        repeat
            task.wait(1)
            steven = Workspace:FindFirstChild("Steven", true)
        until steven
    end

    local target = (steven:IsA("Model") and (steven.PrimaryPart or steven:FindFirstChild("HumanoidRootPart"))) or (steven:IsA("BasePart") and steven)
    
    if target then
        for i = 1, 5 do
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = target.CFrame + Vector3.new(0, 3, 3)
                root.Velocity = Vector3.new(0, 0, 0)
                
                local platName = "AntiVoidPlatform_Steven"
                if not Workspace:FindFirstChild(platName) then
                    local plat = Instance.new("Part")
                    plat.Name = platName
                    plat.Size = Vector3.new(50, 2, 50)
                    plat.Position = root.Position - Vector3.new(0, 4, 0)
                    plat.Anchored = true
                    plat.Transparency = 0.5 
                    plat.BrickColor = BrickColor.new("Bright green")
                    plat.Material = Enum.Material.Neon
                    plat.Parent = Workspace
                end
                
                -- Anchor Steven agar tidak jatuh saat map dihancurkan
                if target:IsA("Model") then
                    for _, v in ipairs(target:GetDescendants()) do
                        if v:IsA("BasePart") then v.Anchored = true end
                    end
                elseif target:IsA("BasePart") then
                    target.Anchored = true
                end
            end
            task.wait(5)
        end
    end
end

-- 3. AUTO CLAIM MAIL
local function startAutoClaimMail()
    print("[3/6] Auto Claim Mail siap (aktif kalau Config.AutoClaimMail true).")
    task.spawn(function()
        while true do
            -- Pemeriksaan config DI DALAM loop. Sebelumnya di luar, sehingga
            -- fungsi ini return permanen saat startup selama AutoClaimMail masih
            -- false -- dan mengaktifkannya lewat panel tidak berpengaruh sama
            -- sekali sampai script dijalankan ulang.
            if Config.AutoClaimMail then
                local ok, inbox = pcall(function() return Networking.Mailbox.OpenInbox:Fire() end)

                if not ok or typeof(inbox) ~= "table" then
                    _G.MailDebug = "[GAGAL] OpenInbox: " .. tostring(inbox)
                else
                    local jumlah = 0
                    for _ in pairs(inbox) do jumlah = jumlah + 1 end

                    if jumlah == 0 then
                        _G.MailDebug = "[KOSONG] Tidak ada mail."
                    else
                        -- ClaimAll asinkron: nilai kembaliannya selalu nil, dan
                        -- selesainya dilaporkan lewat ClaimAllFinished. Dulu
                        -- ditunggu buta 1,5 detik, yang bisa kurang saat mail
                        -- banyak dan kelebihan saat mail sedikit.
                        local selesai = false
                        local conn = Networking.Mailbox.ClaimAllFinished.OnClientEvent:Connect(function()
                            selesai = true
                        end)

                        pcall(function() Networking.Mailbox.ClaimAll:Fire() end)

                        local t = 0
                        while t < 15 and not selesai do
                            task.wait(0.25)
                            t = t + 0.25
                        end
                        conn:Disconnect()

                        -- Bersihkan sisa yang benar-benar masih ada. Dulu fallback
                        -- ini menembak ulang seluruh snapshot lama tanpa cek, jadi
                        -- memanggil Claim untuk ID yang sudah selesai.
                        local ok2, sisa = pcall(function() return Networking.Mailbox.OpenInbox:Fire() end)
                        local sisaJumlah = 0
                        if ok2 and typeof(sisa) == "table" then
                            for id in pairs(sisa) do
                                sisaJumlah = sisaJumlah + 1
                                pcall(function() Networking.Mailbox.Claim:Fire(id) end)
                                task.wait(0.3)
                            end
                        end

                        _G.MailDebug = string.format("[OK] %d mail, ClaimAll %s, sisa %d",
                            jumlah, selesai and "selesai" or "timeout", sisaJumlah)
                    end
                end
            end
            task.wait(30)
        end
    end)
end

-- ==========================
-- FPS BOOST HELPERS
-- ==========================
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
    if desc:IsA("Motor6D") or desc:IsA("Animator") or desc:IsA("AnimationController") then
        pcall(function() desc:Destroy() end)
        return
    end
    if desc:IsA("BasePart") then
        desc.CastShadow = false
        local isFruit, isPlant = getParentType(desc)
        if desc.Name == "HarvestPart" then
            desc.Transparency = 0.5
            desc.Color = Color3.fromRGB(0, 255, 0) 
            desc.Material = Enum.Material.Neon
        elseif isFruit then
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
            if desc.Parent and not desc.Parent:FindFirstChild("Humanoid") then
                desc.Anchored = true
            end
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
            -- Terrain:Clear() DIHAPUS — menghapus seluruh terrain (tanah,
            -- jalan, fondasi) sehingga akun jatuh ke void. Aman: water props
            -- di atas sudah dihandle, dan terrain kosong tanpa dekorasi saja
            -- sudah menghemat cukup banyak.
        end)
    end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        UserSettings():GetService("UserGameSettings").MasterVolume = 0
    end)
end

-- 4. FPS BOOST & BLACK SCREEN
local function applyFpsBoost()
    print("[4/6] Mengaktifkan Brutal FPS Boost & Custom Black Screen.")

    -- GRAFIK ROBLOX KE LEVEL 1 + MUTE TOTAL
    nukeEnvironment()

    -- HAPUS SEMUA SOUND/SOUNDGROUP (permanen, termasuk yang spawn belakangan)
    pcall(function()
        local SoundService = game:GetService("SoundService")
        -- Matikan semua child di SoundService
        for _, obj in ipairs(SoundService:GetDescendants()) do
            if obj:IsA("Sound") or obj:IsA("SoundGroup") then
                pcall(function() obj:Destroy() end)
            end
        end
        -- Disable ambient music/sound
        SoundService.AmbientReverb = Enum.ReverbType.NoReverb
        SoundService.DistanceFactor = 0
        SoundService.DopplerScale = 0
        SoundService.RolloffScale = 0
    end)

    -- HAPUS SOUND DI SELURUH WORKSPACE
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Sound") then
                pcall(function() obj:Destroy() end)
            end
        end
    end)

    -- LOOP PERMANEN: bunuh Sound baru yang muncul (game suka spawn ulang)
    task.spawn(function()
        while task.wait(3) do
            pcall(function()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Sound") and obj.Playing then
                        obj:Stop()
                        obj.Volume = 0
                        pcall(function() obj:Destroy() end)
                    end
                end
                for _, obj in ipairs(game:GetService("SoundService"):GetDescendants()) do
                    if obj:IsA("Sound") and obj.Playing then
                        obj:Stop()
                        obj.Volume = 0
                        pcall(function() obj:Destroy() end)
                    end
                end
            end)
        end
    end)
    
    -- MENGHAPUS DEKORASI BERAT (PLANT, FRUIT, TREES) TANPA MENGHAPUS LANTAI (BASEPLATE)
    -- W1 hanya beli benih, tidak ada tanam/panen — Gardens boleh dihapus
    local objectsToDestroy = {"Grass", "Gardens", "Trees", "Decorations"}
    for _, name in pairs(objectsToDestroy) do
        if Workspace:FindFirstChild(name) then pcall(function() Workspace[name]:Destroy() end) end
    end
    
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        for _, child in pairs(Lighting:GetChildren()) do
            if child:IsA("BloomEffect") or child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then 
                child:Destroy() 
            end
        end
    end)
    
    local function isProtected(desc)
        if not desc then return true end
        if LocalPlayer.Character and desc:IsDescendantOf(LocalPlayer.Character) then return true end
        if desc.Name == "Terrain" or desc.Name == "Camera" then return true end
        
        -- Jangan hapus NPC dan Shop
        local current = desc
        local depth = 0
        while current and current ~= Workspace and depth < 4 do
            if current:FindFirstChildWhichIsA("Humanoid") then return true end
            if current.Name:lower() == "npcs" or current.Name:lower() == "npc" then return true end
            current = current.Parent
            depth = depth + 1
        end
        return false
    end
    
    local count = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if not isProtected(desc) then
            if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("UnionOperation") then
                pcall(function() 
                    desc.Material = Enum.Material.SmoothPlastic
                    desc.CastShadow = false
                    desc.Anchored = true -- MEMBEKUKAN SEMUA YANG BERGERAK
                end)
            elseif desc:IsA("Texture") or desc:IsA("Decal") or desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
                pcall(function() desc:Destroy() end)
            end
        end
        
        count = count + 1
        if count % 500 == 0 then
            task.wait() -- Memberi nafas ke CPU
        end
    end
    
    -- MEMATIKAN SEMUA ANIMASI UNTUK PERFORMA EKSTREM
    pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                for _, obj in ipairs(player.Character:GetDescendants()) do
                    if obj:IsA("Animator") or obj:IsA("Animation") or obj:IsA("AnimationTrack") then
                        obj:Destroy()
                    end
                end
                local animateScript = player.Character:FindFirstChild("Animate")
                if animateScript then
                    animateScript.Disabled = true
                end
            end
        end
    end)
    Workspace.CurrentCamera.FieldOfView = 30

    pcall(function()
        if true then -- [PERMANENT BLACKSCREEN LOCK]
            local bgGui = Instance.new("ScreenGui")
            bgGui.Name = "AFK_BlackScreen"
            bgGui.Enabled = true
            bgGui.IgnoreGuiInset = true
            bgGui.ResetOnSpawn = false
            
            local bgFrame = Instance.new("Frame")
            bgFrame.Size = UDim2.new(1, 0, 1, 0)
            bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bgFrame.BorderSizePixel = 0
            bgFrame.Parent = bgGui

            local leftImage = Instance.new("ImageLabel")
            leftImage.Size = UDim2.new(0.3, 0, 0.6, 0) 
            leftImage.Position = UDim2.new(0.05, 0, 0.5, 0)
            leftImage.AnchorPoint = Vector2.new(0, 0.5)
            leftImage.BackgroundTransparency = 1
            leftImage.ScaleType = Enum.ScaleType.Fit
            leftImage.Image = "rbxassetid://79880397850563"
            leftImage.Parent = bgFrame

            local rightImage = Instance.new("ImageLabel")
            rightImage.Size = UDim2.new(0.3, 0, 0.6, 0)
            rightImage.Position = UDim2.new(0.95, 0, 0.5, 0)
            rightImage.AnchorPoint = Vector2.new(1, 0.5)
            rightImage.BackgroundTransparency = 1
            rightImage.ScaleType = Enum.ScaleType.Fit
            rightImage.Image = "rbxassetid://104624206636533"
            rightImage.Parent = bgFrame
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(0.9, 0, 0.25, 0)
            textLabel.Position = UDim2.new(0.5, 0, 0.95, 0)
            textLabel.AnchorPoint = Vector2.new(0.5, 1)
            textLabel.BackgroundTransparency = 1
            textLabel.Text = "AFK MODE\nFENG JIU MY BINI"
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextScaled = true
            textLabel.TextWrapped = true
            textLabel.Font = Enum.Font.Code
            textLabel.ZIndex = 10
            textLabel.Parent = bgFrame
            
            local centerLabel = Instance.new("TextLabel")
            centerLabel.Size = UDim2.new(0.4, 0, 0.2, 0)
            centerLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
            centerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            centerLabel.BackgroundTransparency = 1
            centerLabel.Text = "Loading..."
            centerLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            centerLabel.TextScaled = true
            centerLabel.TextWrapped = false
            centerLabel.Font = Enum.Font.GothamBold
            centerLabel.ZIndex = 10
            centerLabel.Parent = bgFrame
            
            local textConstraint = Instance.new("UITextSizeConstraint")
            textConstraint.MaxTextSize = 25
            textConstraint.Parent = centerLabel
            
            local centerStroke = Instance.new("UIStroke")
            centerStroke.Thickness = 1.5
            centerStroke.Color = Color3.fromRGB(0, 0, 0)
            centerStroke.Parent = centerLabel
            
            -- HISTORY UI 
            local historyLabel = Instance.new("TextLabel")
            historyLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
            historyLabel.Position = UDim2.new(0.5, 0, 0.5, 0) 
            historyLabel.AnchorPoint = Vector2.new(0.5, 0)
            historyLabel.BackgroundTransparency = 1
            historyLabel.Text = ""
            historyLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
            historyLabel.TextScaled = false
            historyLabel.TextSize = 14 
            historyLabel.TextXAlignment = Enum.TextXAlignment.Center
            historyLabel.TextYAlignment = Enum.TextYAlignment.Top
            historyLabel.TextWrapped = true
            historyLabel.Font = Enum.Font.GothamBold
            historyLabel.ZIndex = 10
            historyLabel.Parent = bgFrame
            
            local historyStroke = Instance.new("UIStroke")
            historyStroke.Thickness = 1.2
            historyStroke.Color = Color3.fromRGB(0, 0, 0)
            historyStroke.Parent = historyLabel
            
            -- PERFORMANCE UI
            local perfLabel = Instance.new("TextLabel")
            perfLabel.Size = UDim2.new(0.5, 0, 0.05, 0)
            perfLabel.Position = UDim2.new(0.5, 0, 0.02, 0) 
            perfLabel.AnchorPoint = Vector2.new(0.5, 0)
            perfLabel.BackgroundTransparency = 1
            perfLabel.Text = "FPS: - | Ping: - ms | Mem: - MB"
            perfLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            perfLabel.TextScaled = false
            perfLabel.TextSize = 14
            perfLabel.Font = Enum.Font.Code
            perfLabel.ZIndex = 10
            perfLabel.Parent = bgFrame
            
            local perfStroke = Instance.new("UIStroke")
            perfStroke.Thickness = 1
            perfStroke.Color = Color3.fromRGB(0, 0, 0)
            perfStroke.Parent = perfLabel
            
            local debugLabel = Instance.new("TextLabel")
            debugLabel.Size = UDim2.new(0.8, 0, 0.05, 0)
            debugLabel.Position = UDim2.new(0.5, 0, 0.08, 0)
            debugLabel.AnchorPoint = Vector2.new(0.5, 0)
            debugLabel.BackgroundTransparency = 1
            debugLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            debugLabel.TextSize = 13
            debugLabel.Font = Enum.Font.Code
            debugLabel.ZIndex = 10
            debugLabel.Text = "Menunggu Auto Buy..."
            debugLabel.Parent = bgFrame
            
            local debugStroke = Instance.new("UIStroke")
            debugStroke.Thickness = 1
            debugStroke.Color = Color3.fromRGB(0, 0, 0)
            debugStroke.Parent = debugLabel
            
            task.spawn(function()
                local Stats = game:GetService("Stats")
                while true do
                    local sheckles = "0"
                    pcall(function()
                        if LocalPlayer:FindFirstChild("leaderstats") then
                            for _, currencyName in ipairs({"Sheckles", "Coins", "Tokens", "Money", "Cash", "Gems"}) do
                                local stat = LocalPlayer.leaderstats:FindFirstChild(currencyName)
                                if stat then
                                    sheckles = tostring(stat.Value)
                                    break
                                end
                            end
                        end
                    end)
                    local function formatNumber(n)
                        n = tonumber(n) or 0
                        if n >= 1e12 then return string.format("%.2fT", n / 1e12)
                        elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
                        elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
                        elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
                        else return tostring(n) end
                    end
                    centerLabel.Text = "👤 " .. LocalPlayer.Name .. "\n💰 " .. formatNumber(sheckles)
                    
                    -- Update History
                    local historyLines = {}
                    for i, data in ipairs(PurchaseHistoryLog) do
                        table.insert(historyLines, data.name .. " " .. data.count .. "x")
                    end
                    
                    if #historyLines > 0 then
                        historyLabel.Text = "🛒 HISTORY (REAL-TIME):\n" .. table.concat(historyLines, "\n")
                    else
                        historyLabel.Text = ""
                    end
                    
                    -- Update Performance Stats
                    local ping = "0"
                    pcall(function() ping = string.split(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1] or "0" end)
                    
                    local fps = "0"
                    pcall(function() fps = tostring(math.floor(Workspace:GetRealPhysicsFPS())) end)
                    
                    local mem = "0"
                    pcall(function() mem = string.split(Stats.PerformanceStats.Memory:GetValueString(), " ")[1] or "0" end)
                    
                    perfLabel.Text = string.format("🎮 FPS: %s  |  📶 Ping: %s ms  |  🧠 Mem: %s MB", fps, ping, mem)
                    
                    if _G.AutoBuyDebug then
                        debugLabel.Text = _G.AutoBuyDebug
                    end
                    
                    task.wait(1)
                end
            end)

            local success = pcall(function() bgGui.Parent = CoreGui end)
            if not success then
                bgGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
            end

            pcall(function()
                RunService:Set3dRenderingEnabled(false)
            end)
        end
        if setfpscap then setfpscap(15) end
    end)
end

-- FUNGSI MEMBACA UI SHOP (SMART FILTER)
local function getShopUITextBlob()
    local textBlob = ""
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local seedShop = playerGui:FindFirstChild("SeedShop")
        if seedShop then
            for _, gui in ipairs(seedShop:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    textBlob = textBlob .. gui.Text .. " | "
                end
            end
        end
        local gearShop = playerGui:FindFirstChild("GearShop")
        if gearShop then
            for _, gui in ipairs(gearShop:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    textBlob = textBlob .. gui.Text .. " | "
                end
            end
        end
    end
    return textBlob
end

-- ==========================
-- PARSER HARGA
-- ==========================
-- Definisinya sengaja DI SINI, di atas loop Auto Buy. Sebelumnya berada jauh di
-- bawah (setelah startAutoDailyDeal), sehingga pemanggilan dari kode di atasnya
-- me-resolve ke global nil -> "attempt to call a nil value" -> thread task.spawn
-- mati tanpa jejak di iterasi pertama. Aturannya: fungsi ini harus berada di atas
-- SEMUA pemanggilnya, termasuk filter nilai di bawah dan loop Auto Buy.
local function parsePrice(text)
    if not text then return 0 end
    local cleanedText = string.upper(text)
    cleanedText = string.gsub(cleanedText, "%s+", "")
    cleanedText = string.gsub(cleanedText, "\238\128\130", "")  -- glyph Robux (U+E002)
    cleanedText = string.gsub(cleanedText, "¢", "")

    -- Teks durasi seperti "30m 30s" menjadi "30M30S", dan pola angka di bawah
    -- akan membacanya sebagai 30 JUTA. Kalau label yang terbaca kebetulan sebuah
    -- timer, harga palsu itu lolos di bawah batas mana pun dan barangnya dibeli.
    if string.match(cleanedText, "^%d+[DHMS]%d+[DHMS]$") then return 0 end

    -- Label kuantitas ("x5") terbaca sebagai harga 5 dan lolos di bawah batas
    -- mana pun. Harga tidak pernah diawali "x".
    if string.match(cleanedText, "^X%d+") then return 0 end

    local numberStr, suffix = string.match(cleanedText, "([%d%.%,]+)([MBK]?)")
    if not numberStr then return 0 end
    numberStr = string.gsub(numberStr, ",", "")
    local amount = tonumber(numberStr) or 0

    if suffix == "M" then amount = amount * 1000000
    elseif suffix == "B" then amount = amount * 1000000000
    elseif suffix == "K" then amount = amount * 1000
    end
    return amount
end

-- ==========================
-- FILTER BELI BERDASARKAN NILAI
-- ==========================
-- getShopUITextBlob() tidak bisa dipakai di sini: fungsi itu menggabung SELURUH
-- teks shop jadi satu string, sehingga nama item dan harganya kehilangan kaitan.
--
-- Struktur nyata (diverifikasi langsung di klien pada Grow a Garden 2):
--   SeedShop.Frame.NormalShop.<Nama Item>....Cost_Text   -> "1¢", "2.5K¢", "NO STOCK"
--   GearShop.Frame.ScrollingFrame.<Nama Item>....Cost_Text -> "2K¢", "OWNED", ...
-- Nama kontainernya BERBEDA antar shop ("NormalShop" vs "ScrollingFrame"), jadi
-- kartunya dicari lewat nama Frame yang persis sama dengan nama item, bukan lewat
-- jalur tetap.
--
-- Dua jebakan yang sudah terbukti ada, jangan diulang:
--  1. Label harganya bernama "Cost_Text" -- bukan "Cost" atau "Price".
--  2. JANGAN memindai teks lalu memanjat ke induk. "ItemTemplate" (prototipe
--     tersembunyi) juga memuat nama item, dan memanjat dari sana sampai ke
--     ScrollingFrame bersama, lalu mengambil harga milik item yang sama sekali lain.
local function getShopItemPrice(itemName)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    for _, namaShop in ipairs({"SeedShop", "GearShop"}) do
        local shop = playerGui:FindFirstChild(namaShop)
        if shop then
            for _, kartu in ipairs(shop:GetDescendants()) do
                if kartu.Name == itemName then
                    local cost = kartu:FindFirstChild("Cost_Text", true)
                    if cost and cost:IsA("TextLabel") then
                        local teks = cost.Text or ""
                        -- Harga Robux tidak ikut filter mata uang in-game.
                        if string.find(teks, "\238\128\130") or string.find(teks, "\226\130\131") then
                            return math.huge
                        end
                        -- "NO STOCK" / "OWNED" ikut jadi 0 di parsePrice, dan itu
                        -- memang seharusnya dilewati: tidak bisa (atau tidak perlu)
                        -- dibeli.
                        local nilai = parsePrice(teks)
                        if nilai > 0 then return nilai end
                        return nil
                    end
                end
            end
        end
    end
    return nil
end

-- true = boleh dibeli. Filter yang mati (mode bukan above/below, atau batas <= 0)
-- selalu meloloskan, jadi pengguna yang tidak memakainya tidak berubah sama sekali.
local function lolosFilterHarga(mode, batasTeks, harga)
    if mode ~= "above" and mode ~= "below" then return true end
    local batas = parsePrice(batasTeks or "0")
    if batas <= 0 then return true end
    -- Harga tak diketahui: TOLAK. Kalau diloloskan, item yang justru ingin
    -- dihindari pengguna akan terbeli diam-diam.
    if type(harga) ~= "number" or harga <= 0 or harga == math.huge then return false end
    if mode == "above" then return harga > batas end
    return harga < batas
end

local function lolosFilterNilaiShop(mode, batasTeks, itemName, kategori)
    if mode ~= "above" and mode ~= "below" then return true end
    if parsePrice(batasTeks or "0") <= 0 then return true end

    local harga = getShopItemPrice(itemName)
    if not lolosFilterHarga(mode, batasTeks, harga) then
        if type(harga) ~= "number" then
            _G.AutoBuyDebug = "[LEWAT] " .. kategori .. " " .. itemName .. ": harga tidak terbaca"
        else
            _G.AutoBuyDebug = string.format("[LEWAT] %s %s: harga %s tidak memenuhi %s %s",
                kategori, itemName, tostring(harga), tostring(mode), tostring(batasTeks))
        end
        return false
    end
    return true
end

-- WATCHDOG (ANTI-FREEZE & ANTI-STUCK)
local function startWatchdog()
    if not Config.AntiFreeze then 
        print("[Auto-Drop] Fitur Anti-Freeze dinonaktifkan oleh pengguna.")
        return 
    end
    
    task.spawn(function()
        local Stats = game:GetService("Stats")
        while true do
            local startTick = tick()
            task.wait(3)
            local elapsed = tick() - startTick
            
            -- 1. Deteksi Engine Freeze (CPU/RAM Macet)
            -- Jika task.wait(3) memakan waktu lebih dari 15 detik, berarti game benar-benar nyangkut!
            if elapsed > 15 then
                forceRejoin("[Auto-Drop] Rejoining: Game Freeze parah (" .. math.floor(elapsed) .. "s delay CPU).")
                return
            end
            
            -- 2. Deteksi Network Freeze (Jaringan Nyangkut / Server Tidak Merespon)
            pcall(function()
                local pingStr = string.split(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1]
                local ping = tonumber(pingStr) or 0
                if ping > 10000 then -- Jika ping di atas 10 detik
                    forceRejoin("[Auto-Drop] Rejoining: Jaringan Stuck / Ping terlalu tinggi (" .. math.floor(ping) .. " ms).")
                end
            end)
        end
    end)
end

-- FIREBASE MONITORING
local function startFirebaseMonitor()
    task.spawn(function()
        local Stats = game:GetService("Stats")
        local HttpService = game:GetService("HttpService")
        local req = (syn and syn.request) or (http and http.request) or request
        
        if not req then 
            warn("[Auto-Drop] Executor tidak mensupport HTTP Request untuk Monitoring.")
            return 
        end
        
        local panelKey = panel_key ~= "" and panel_key or "Public"

        -- Sidik jari command terakhir yang sudah dikerjakan klien ini.
        local lastCommandSidik = nil

        -- Menghapus command yang sudah dikerjakan.
        --
        -- Dulu hanya "Method = DELETE" tanpa header, di dalam pcall kosong yang
        -- membuang errornya. Penghapusan itu ternyata tidak pernah berhasil di
        -- lapangan: command tetap tergeletak di Firebase (terhitung 266 command
        -- menumpuk di 10 panel key) dan ikut terbaca lagi tiap 5 detik.
        --
        -- PUT dengan body "null" dipakai sebagai jalur utama karena Firebase
        -- memperlakukan null sebagai penghapusan, dan PUT adalah metode yang sudah
        -- TERBUKTI jalan lewat upload monitor di BLOCK 1 pada executor yang sama.
        -- DELETE tetap dicoba lebih dulu untuk executor yang memang mendukungnya.
        local function hapusCommand(req, urlCommand)
            pcall(function()
                req({
                    Url = urlCommand,
                    Method = "DELETE",
                    Headers = {["Content-Type"] = "application/json"}
                })
            end)
            pcall(function()
                req({
                    Url = urlCommand,
                    Method = "PUT",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = "null"
                })
            end)
        end

        local lastDDCheck = 0
        while true do
            -- Gerbang diperiksa di sini, bukan sekali saat startup -- lihat
            -- catatan di startAutoBuy(). Config.Monitoring bisa berubah kapan
            -- saja lewat syncConfig(), termasuk puluhan detik setelah mulai.
            if not Config.Monitoring then
                task.wait(5)
                continue
            end

            -- BLOCK 1: Upload monitoring data (terpisah)
            local success, err = pcall(function()
                local sheckles = 0
                if LocalPlayer:FindFirstChild("leaderstats") then
                    for _, currencyName in ipairs({"Sheckles", "Coins", "Tokens", "Money", "Cash", "Gems"}) do
                        local stat = LocalPlayer.leaderstats:FindFirstChild(currencyName)
                        if stat then
                            sheckles = stat.Value
                            break
                        end
                    end
                end
                
                local pingStr = string.split(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1]
                local ping = tonumber(pingStr) or 0

                local invData = {}
                local replica = PlayerStateClient:GetLocalReplica()
                if replica and replica.Data and replica.Data.Inventory then
                    for cat, catData in pairs(replica.Data.Inventory) do
                        if cat == "HarvestedFruits" then
                            -- Skip count tool
                        else
                            for key, val in pairs(catData) do
                                local count = 0
                                local itemName = key
                                if typeof(val) == "number" then count = val
                                elseif typeof(val) == "table" then
                                    count = val.Amount or val.Count or val.Value or 1
                                    itemName = val.Name or val.DisplayName or val.ItemName or key
                                end
                                if count > 0 then
                                    invData[itemName] = (invData[itemName] or 0) + count
                                end
                            end
                        end
                    end
                end
                
                -- Hitung Total Value (Di-disable karena bikin LAG)
                local gardenValue = 0

                if os.clock() - lastDDCheck > 60 then
                    lastDDCheck = os.clock()
                    task.spawn(function()
                        if Networking and Networking.NPCS then
                            local ok, res = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                            if ok and type(res) == "table" then
                                getgenv().DDStatus = res.Available and "V" or "X"
                            end
                        end
                    end)
                end

                local data = {
                    panel_key = raw_panel_key,
                    username = LocalPlayer.Name,
                    data = {
                        coins = sheckles,
                        gardenValue = gardenValue,
                        action = tostring(_G.AutoBuyDebug or "Sedang Idle") .. " [DD:" .. tostring(getgenv().DDStatus or "?") .. "]",
                        ping = ping,
                        inventory = invData,
                        world = "Grow a Garden 2",
                        placeId = game.PlaceId,
                        lastUpdate = os.time()
                    }
                }

                local res = req({
                    Url = SERVER_URL .. "/api/live/update",
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = HttpService:JSONEncode(data)
                })
                if res and res.StatusCode ~= 200 then
                    warn("[Auto-Drop] Live Monitor Upload Error: " .. tostring(res.StatusCode) .. " - " .. tostring(res.Body))
                    -- Retry sekali kalau server sibuk (checkpoint DB)
                    if res.StatusCode == 502 or res.StatusCode == 503 then
                        task.wait(5)
                        local retry = req({
                            Url = SERVER_URL .. "/api/live/update",
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode(data)
                        })
                        if retry and retry.StatusCode ~= 200 then
                            warn("[Auto-Drop] Live Monitor Retry Gagal: " .. tostring(retry.StatusCode))
                        end
                    end
                end
            end)
            if not success then
                warn("[Auto-Drop] Pcall Block 1 Error: " .. tostring(err))
            end
            
            -- BLOCK 2: Cek perintah remote (TERPISAH dari monitoring agar tidak ikut gagal)
            local cmdBlokOk, cmdBlokErr = pcall(function()
                local urlCommand = SERVER_URL .. "/api/live/commands/" .. LocalPlayer.Name .. "?panel_key=" .. HttpService:UrlEncode(raw_panel_key)

                local cmdReq = req({
                    Url = urlCommand .. "&r=" .. tostring(math.random(1000000, 9999999)),
                    Method = "GET"
                })

                if cmdReq and cmdReq.Body and cmdReq.Body ~= "null" then
                    local cmdOk, cmdData = pcall(function()
                        return HttpService:JSONDecode(cmdReq.Body)
                    end)

                    if cmdOk and cmdData and typeof(cmdData) == "table" then
                        if (cmdData.Command == "SendMail" and cmdData.Target) or (cmdData.Command == "SendMailMulti" and cmdData.Jobs) then
                            -- Perintah basi dibuang tanpa dikerjakan.
                            --
                            -- Akun yang mati saat perintah ditulis akan menemukannya
                            -- utuh begitu jalan lagi -- terukur 15 perintah menggantung
                            -- dari akun yang berhenti 92-100 menit sebelumnya. Tanpa
                            -- batas umur, seluruh inventory terkirim berjam-jam kemudian
                            -- ke target yang mungkin sudah tidak diniatkan.
                            --
                            -- Ts memakai cap waktu server Firebase. Perintah tanpa Ts
                            -- (panel versi lama) tetap dijalankan, dan umur negatif --
                            -- selisih jam antar mesin -- dianggap masih segar: lebih baik
                            -- mengirim yang sah daripada diam-diam membuangnya.
                            local umurDetik = nil
                            if type(cmdData.Ts) == "number" then
                                local ts = cmdData.Ts
                                if ts > 9999999999 then ts = ts / 1000 end
                                umurDetik = os.time() - ts
                            end

                            if umurDetik and umurDetik > 900 then
                                _G.RemoteMailDebug = string.format(
                                    "[LEWAT] Perintah kedaluwarsa (%d menit), tidak dikirim",
                                    math.floor(umurDetik / 60))
                                warn("[Remote-Mail] " .. _G.RemoteMailDebug)
                                hapusCommand(req, urlCommand)
                                return
                            end

                            -- Sidik jari command yang sudah dikerjakan. Ini jaring
                            -- pengaman UTAMA, bukan pelengkap: kalau penghapusan di
                            -- server gagal, command yang sama akan terbaca lagi pada
                            -- iterasi berikutnya dan dikirim ULANG tiap 5 detik tanpa
                            -- henti. Itu yang benar-benar terjadi -- terukur 33,7 entri
                            -- riwayat per detik dengan jarak persis 5 detik per akun,
                            -- dan menumpuk sampai lebih dari sejuta entri.
                            local sidik = cmdReq.Body
                            if sidik == lastCommandSidik then
                                hapusCommand(req, urlCommand)   -- coba bersihkan lagi, jangan dikerjakan ulang
                                return
                            end
                            lastCommandSidik = sidik

                            print("[Remote-Mail] Command pengiriman item diterima dari Web Panel!")
                            hapusCommand(req, urlCommand)

                            task.spawn(function()
                                if cmdData.Command == "SendMailMulti" then
                                    for _, job in ipairs(cmdData.Jobs) do
                                        pcall(function()
                                            req({
                                                Url = SERVER_URL .. "/api/mail/log",
                                                Method = "POST",
                                                Headers = {["Content-Type"] = "application/json"},
                                                Body = HttpService:JSONEncode({
                                                    panel_key = raw_panel_key,
                                                    log = string.format("[%s] %s > Sedang memproses... > %s",
                                                        os.date("%H:%M:%S"), LocalPlayer.Name, job.Target),
                                                    timestamp = os.time(),
                                                    target = job.Target,
                                                    batches = 0
                                                })
                                            })
                                        end)
                                        if _G.executeRemoteMail then
                                            _G.executeRemoteMail(job.Target, job.Items or {})
                                            task.wait(2)
                                        end
                                    end
                                else
                                    pcall(function()
                                        req({
                                            Url = SERVER_URL .. "/api/mail/log",
                                            Method = "POST",
                                            Headers = {["Content-Type"] = "application/json"},
                                            Body = HttpService:JSONEncode({
                                                panel_key = raw_panel_key,
                                                log = string.format("[%s] %s > Sedang memproses... > %s",
                                                    os.date("%H:%M:%S"), LocalPlayer.Name, cmdData.Target),
                                                timestamp = os.time(),
                                                target = cmdData.Target,
                                                batches = 0
                                            })
                                        })
                                    end)
                                    
                                    if _G.executeRemoteMail then
                                        _G.executeRemoteMail(cmdData.Target, cmdData.Items or {})
                                    else
                                        warn("[Remote-Mail] _G.executeRemoteMail belum terdefinisi!")
                                    end
                                end
                            end)
                        end
                    end
                elseif cmdReq and cmdReq.Body == "null" then
                    -- Node sudah kosong -> penghapusan berhasil. Sidik jarinya
                    -- dilupakan supaya perintah identik berikutnya (target dan item
                    -- sama persis) tetap dikerjakan, bukan dikira duplikat.
                    lastCommandSidik = nil
                end
            end)
            -- Dulu errornya dibuang diam-diam oleh pcall tanpa penerima, jadi
            -- kegagalan apa pun di jalur command tidak pernah terlihat sama sekali.
            if not cmdBlokOk then
                _G.RemoteMailDebug = "[ERROR] Poll command: " .. tostring(cmdBlokErr)
                warn("[Remote-Mail] " .. _G.RemoteMailDebug)
            end

            task.wait(5) -- Update setiap 5 detik
        end
    end)
end

-- ==========================
-- AUTO SEND MAIL BERKALA
-- ==========================
-- Config.TargetUsername dan Config.MailIntervalHours sebelumnya HANYA ada di tabel
-- Config tanpa satu pun pembaca -- kolomnya di panel mengirim nilai yang tidak
-- pernah dipakai, jadi fiturnya tidak pernah benar-benar ada. Ini implementasinya.
local mailRng = Random.new()

-- Potret inventory: { namaItem = jumlah }. Sumbernya sama dengan yang dipakai
-- monitor, dan pet yang sedang dipakai dikecualikan seperti di executeRemoteMail.
local function potretInventoryUntukMail()
    local daftar = {}
    local jenis = 0
    local replica = PlayerStateClient:GetLocalReplica()
    if not (replica and replica.Data and replica.Data.Inventory) then
        return daftar, jenis
    end

    for cat, catData in pairs(replica.Data.Inventory) do
        if cat ~= "HarvestedFruits" and typeof(catData) == "table" then
            for key, val in pairs(catData) do
                local count, itemName = 0, key
                if typeof(val) == "number" then
                    count = val
                elseif typeof(val) == "table" then
                    count = val.Amount or val.Count or val.Value or 1
                    itemName = val.Name or val.DisplayName or val.ItemName or key
                    if cat == "Pets" and val.Equipped then count = 0 end
                end
                if count > 0 then
                    if daftar[itemName] == nil then jenis = jenis + 1 end
                    daftar[itemName] = (daftar[itemName] or 0) + count
                end
            end
        end
    end
    return daftar, jenis
end

-- Membagi rata satu potret inventory ke beberapa target, meniru persis cara
-- Remote Mail manual di panel: base = floor(total / jumlahTarget), dan SISA
-- pembagian ditambahkan ke target terakhir supaya tidak ada item yang menguap.
local function bagiRataKeTarget(potret, jumlahTarget)
    local bagian = {}
    for i = 1, jumlahTarget do bagian[i] = {} end

    for nama, total in pairs(potret) do
        local base = math.floor(total / jumlahTarget)
        local sisa = total % jumlahTarget
        for i = 1, jumlahTarget do
            local jatah = base
            if i == jumlahTarget then jatah = jatah + sisa end
            if jatah > 0 then
                bagian[i][nama] = jatah
            end
        end
    end
    return bagian
end

-- Daftar target dari panel. Mendukung TargetUsernames (array, maks 5) sekaligus
-- TargetUsername lama sebagai cadangan supaya config yang belum diperbarui tetap
-- jalan. Duplikat dan entri kosong dibuang.
local function ambilDaftarTarget()
    local mentah = Config.TargetUsernames
    if typeof(mentah) ~= "table" then
        mentah = { Config.TargetUsername }
    end

    local hasil, sudah = {}, {}
    for _, v in pairs(mentah) do
        local nama = tostring(v or ""):match("^%s*(.-)%s*$") or ""
        local kunci = string.lower(nama)
        if nama ~= "" and not sudah[kunci] and #hasil < 5 then
            sudah[kunci] = true
            table.insert(hasil, nama)
        end
    end
    return hasil
end

local function startAutoSendMail()
    task.spawn(function()
        -- Sengaja TIDAK mengirim saat start. Akun rejoin sendiri lewat
        -- setupAutoReconnect, dan mengirim di awal berarti mail terkirim setiap
        -- kali rejoin -- bukan tiap N jam seperti yang diminta pengguna.
        local berikutnya = nil
        local intervalTerpakai = nil

        while true do
            local targets = ambilDaftarTarget()
            local jam = tonumber(Config.MailIntervalHours) or 0

            -- Saklar eksplisit diperiksa PERTAMA. Selama AutoMail belum
            -- dinyalakan sendiri, target dan interval tidak berarti apa-apa --
            -- config basi yang masih menyimpan keduanya pun tidak bisa
            -- menghidupkan pengiriman.
            local nyala = (Config.AutoMail == true)

            if not nyala or #targets == 0 or jam <= 0 then
                -- Fitur mati. Jadwal direset supaya saat dinyalakan nanti tidak
                -- langsung terkirim gara-gara waktunya dianggap sudah lewat.
                berikutnya = nil
                intervalTerpakai = nil
                -- Sebabnya disebut spesifik. Pesan lama ("target atau interval
                -- belum diatur") tidak membedakan tiga keadaan yang berbeda,
                -- jadi tidak bisa dipakai memastikan fiturnya memang sengaja
                -- mati -- justru itu yang membuat insiden kemarin lolos lama.
                if not nyala then
                    _G.AutoMailDebug = "[MATI] Auto Mail tidak diaktifkan di panel"
                elseif #targets == 0 then
                    _G.AutoMailDebug = "[MATI] Auto Mail nyala tapi target kosong"
                else
                    _G.AutoMailDebug = "[MATI] Auto Mail nyala tapi interval 0 jam"
                end
            else
                local interval = jam * 3600
                -- Jitter memakai Random per client: ratusan akun yang start
                -- berbarengan tidak boleh mengirim mail pada detik yang sama.
                if berikutnya == nil or intervalTerpakai ~= interval then
                    berikutnya = os.time() + interval + mailRng:NextInteger(0, 300)
                    intervalTerpakai = interval
                    _G.AutoMailDebug = string.format("[MENUNGGU] %d target, tiap %s jam",
                        #targets, tostring(jam))
                elseif os.time() >= berikutnya then
                    local potret, jenis = potretInventoryUntukMail()
                    if jenis > 0 and _G.executeRemoteMail then
                        local bagian = bagiRataKeTarget(potret, #targets)
                        for i, nama in ipairs(targets) do
                            -- Potret diambil SEKALI di awal lalu dibagi, jadi jatah
                            -- target berikutnya tetap sesuai rencana walau inventory
                            -- sudah menyusut oleh pengiriman sebelumnya.
                            _G.AutoMailDebug = string.format("[KIRIM %d/%d] %d jenis -> %s",
                                i, #targets, jenis, nama)
                            pcall(function() _G.executeRemoteMail(nama, bagian[i]) end)
                            task.wait(2)
                        end
                        _G.AutoMailDebug = string.format("[SELESAI] %d jenis dibagi ke %d target",
                            jenis, #targets)
                    else
                        _G.AutoMailDebug = "[LEWAT] Tidak ada item untuk dikirim"
                    end
                    berikutnya = os.time() + interval + mailRng:NextInteger(0, 300)
                end
            end

            task.wait(60)
        end
    end)
end

-- 5. AUTO BUY (MENGGUNAKAN GETGENV CONFIG & API TERBARU ANTI-PATCH)
local function startAutoBuy()
    startWatchdog()
    -- Dulu: "if Config.Monitoring then startFirebaseMonitor() end".
    --
    -- Gerbang itu dievaluasi SEKALI di sini, padahal Config baru terisi dari
    -- server oleh syncConfig() -- dan thread sync menunggu 0-30 detik acak
    -- sebelum sync pertamanya (jitter anti-thundering-herd). Pada akun yang
    -- offset acaknya besar, alur startup sampai ke titik ini lebih dulu,
    -- sehingga Config.Monitoring masih bernilai default `false`: monitor tidak
    -- pernah menyala dan akun itu TIDAK PERNAH muncul di Live Monitor -- walau
    -- di Kaitun Manager terlihat normal, karena syncConfig tetap jalan, hanya
    -- belakangan. Offsetnya acak, jadi korbannya berbeda tiap peluncuran; itu
    -- persis gejala "sebagian akun tidak muncul padahal sudah di-execute".
    --
    -- Sekarang loop selalu dijalankan dan gerbangnya diperiksa per iterasi,
    -- jadi monitor menyala sendiri begitu config tiba -- tanpa execute ulang.
    startFirebaseMonitor()
    
    task.spawn(function()
        
        while true do
            -- ===== HEALTH CHECK: config belum sync? =====
            -- Kalau BuySeeds/BuyGears aktif tapi target kosong, kemungkinan
            -- config belum tiba dari panel. Tampilkan peringatan sekali saja.
            if Config.BuySeeds and (not Config.Seeds or next(Config.Seeds) == nil) then
                if not _G._autoBuyWarned then
                    _G._autoBuyWarned = true
                    warn("[AUTOBUY] ⚠ BuySeeds=true tapi Seeds kosong! Config mungkin belum sync dari panel.")
                    warn("[AUTOBUY] Cek console untuk [WEB-SYNC] — kalau tidak muncul, pastikan PanelKey benar.")
                end
                -- Saat config lokal dipakai, tidak ada apa pun yang sedang
                -- ditunggu: sync tidak akan pernah mengisi Seeds. Menyuruh
                -- buyer menunggu di keadaan itu membuat mereka diam berjam-jam
                -- padahal yang salah ada di generator-nya.
                _G.AutoBuyDebug = _G.MozeConfigLokal
                    and "[SALAH SETEL] Beli seed nyala tapi daftar seed KOSONG di generator"
                    or  "[WAIT] Seeds kosong — tunggu config dari panel..."
            else
                _G._autoBuyWarned = false
            end

            -- Membeli Seed jika diaktifkan di config dalam
            if Config.BuySeeds and Config.Seeds then
                local targetSeeds = Config.Seeds
                
                local count = 0
                for k,v in pairs(Config.Seeds) do count = count + 1 end
                
                if Config.Seeds["All"] and count < 5 then
                    targetSeeds = {
                        ["Carrot"]=true, ["Apple"]=true, ["Blueberry"]=true, ["Strawberry"]=true, ["Tomato"]=true, 
                        ["Tulip"]=true, ["Baby Cactus"]=true, ["Bamboo"]=true, ["Cactus"]=true, ["Corn"]=true, 
                        ["Horned Melon"]=true, ["Pineapple"]=true, ["Banana"]=true, ["Coconut"]=true, 
                        ["Glow Mushroom"]=true, ["Grape"]=true, ["Green Bean"]=true, ["Mango"]=true, 
                        ["Mushroom"]=true, ["Acorn"]=true, ["Cherry"]=true, ["Dragon Fruit"]=true, 
                        ["Fire Fern"]=true, ["Poison Ivy"]=true, ["Sunflower"]=true, ["Ghost Pepper"]=true, 
                        ["Poison Apple"]=true, ["Pomegranate"]=true, ["Venom Spitter"]=true, 
                        ["Venus Fly Trap"]=true, ["Dragon's Breath"]=true, ["Hypno Bloom"]=true, 
                        ["Moon Bloom"]=true, ["Sun Bloom"]=true, ["Star Fruit"]=true, ["Eclipse Bloom"]=true, 
                        ["Rocket Pop"]=true, ["Atlantic Giant Pumpkin"]=true, ["Amber Cranberry"]=true, 
                        ["Briar Rose"]=true, ["Romanesco"]=true, ["Cinnamon Stick"]=true, ["Conifer Cone"]=true, 
                        ["Conifer Cone Sapling"]=true, ["Plum"]=true, ["Beanstalk"]=true, ["Bone Blossom"]=true, 
                        ["Buttercup"]=true, ["Lotus"]=true, ["Magic Beanstalk"]=true, ["PartFruit"]=true, 
                        ["Pinetree"]=true, ["Pumpkin"]=true, ["Thorn Rose"]=true, ["Gold Seed"]=true, 
                        ["Mega Seed"]=true, ["Rainbow Seed"]=true, ["Diamond Seed"]=true, 
                        ["Blue Apple Seed"]=true, ["Red Apple Seed"]=true, ["Fairy's Bloom Seed"]=true,
                        ["Solar Flare Seed"]=true, ["Eclipse Seed"]=true, ["Crate Seed"]=true
                    }
                end
                
                local uiBlob = getShopUITextBlob()
                for itemName, isEnabled in pairs(targetSeeds) do 
                    if isEnabled == true then
                        -- SMART FILTER: Hanya beli jika nama item ada di layar Shop (atau jika UI tidak terbaca)
                        if (uiBlob == "" or string.find(uiBlob, itemName, 1, true))
                           and lolosFilterNilaiShop(Config.SeedValueMode, Config.SeedValueThreshold, itemName, "Seed") then
                            _G.AutoBuyDebug = "[Mencoba Beli Seed] -> " .. itemName
                            local failCount = 0
                            while true do 
                                if not Config.BuySeeds then
                                    _G.AutoBuyDebug = "[DIBATALKAN] Auto Buy Seeds dimatikan dari web"
                                    break
                                end
                                local oldAmount = getItemCount(itemName)
                                
                                local success, err = pcall(function() Networking.SeedShop.PurchaseSeed:Fire(itemName) end)
                                if not success then
                                    _G.AutoBuyDebug = "[ERROR] Seed " .. itemName .. ":\n" .. tostring(err)
                                    task.wait(2)
                                end
                                task.wait(0.1) 
                                
                                local newAmount = getItemCount(itemName)
                                
                                if newAmount > oldAmount then
                                    local boughtAmount = newAmount - oldAmount
                                    _G.AutoBuyDebug = "[SUKSES] Membeli Seed: " .. itemName .. " (" .. newAmount .. ")"
                                    if Config.History then
                                        print(string.format("[BELI SEED] %s | Jumlah: %d", itemName, boughtAmount))
                                    end
                                    failCount = 0 -- Reset kegagalan karena berhasil beli
                                else
                                    failCount = failCount + 1
                                    if failCount >= 3 then
                                        _G.AutoBuyDebug = "[HABIS/GAGAL] Seed: " .. itemName
                                        task.wait(0.5)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Membeli Gear jika diaktifkan di config dalam
            if Config.BuyGears and Config.Gears then
                local targetGears = Config.Gears
                
                local countGears = 0
                for k,v in pairs(Config.Gears) do countGears = countGears + 1 end
                
                if Config.Gears["All"] and countGears < 5 then
                    targetGears = {
                        ["Common Sprinkler"]=true, ["Common Watering Can"]=true, ["Sign"]=true,
                        ["Uncommon Sprinkler"]=true, ["Rare Sprinkler"]=true, ["Trowel"]=true,
                        ["Jump Mushroom"]=true, ["Speed Mushroom"]=true, ["Lantern"]=true, ["Megaphone"]=true,
                        ["Shrink Mushroom"]=true, ["Supersize Mushroom"]=true, ["Gnome"]=true, ["Flashbang"]=true,
                        ["Basic Pot"]=true, ["Legendary Sprinkler"]=true, ["Teleporter"]=true,
                        ["Invisibility Mushroom"]=true, ["Wheelbarrow"]=true, ["Player Magnet"]=true,
                        ["Strawberry Sniper"]=true, ["Super Watering Can"]=true, ["Super Sprinkler"]=true,
                        ["Power Hose"]=true, ["Freeze Ray"]=true, ["Grappling Hook"]=true, ["Rainbow Carpet"]=true,
                        ["Vine Wrapper"]=true, ["Legendary Pet Teleporter"]=true, ["Mythic Pet Teleporter"]=true,
                        ["Super Pet Teleporter"]=true, ["Rake"]=true, ["Crowbar"]=true, ["Weather Staff"]=true,
                        ["Wind Staff"]=true, ["Bull Horn"]=true, ["Harp"]=true, ["Wrench"]=true,
                        ["Syrup Watering Can"]=true, ["Syrup Sprinkler"]=true,
                        ["Super Syrup Watering Can"]=true, ["Super Syrup Sprinkler"]=true,
                        ["Rare Magic Mail"]=true, ["Legendary Magic Mail"]=true,
                        ["Super Magic Mail"]=true                    }
                end
                
                local uiBlob = getShopUITextBlob()
                for itemName, isEnabled in pairs(targetGears) do
                    if isEnabled == true then
                        -- SMART FILTER: Hanya beli jika nama item ada di layar Shop
                        -- (GearShop visible:false tetap me-render TextLabels → nama tetap ada di uiBlob)
                        if (uiBlob == "" or string.find(uiBlob, itemName, 1, true))
                           and lolosFilterNilaiShop(Config.GearValueMode, Config.GearValueThreshold, itemName, "Gear") then
                            _G.AutoBuyDebug = "[Mencoba Beli Gear] -> " .. itemName
                            local failCount = 0
                            while true do 
                                if not Config.BuyGears then
                                    _G.AutoBuyDebug = "[DIBATALKAN] Auto Buy Gears dimatikan dari web"
                                    break
                                end
                                local oldAmount = getItemCount(itemName)
                                
                                local success, err = pcall(function() Networking.GearShop.PurchaseGear:Fire(itemName) end)
                                if not success then
                                    _G.AutoBuyDebug = "[ERROR] Gear " .. itemName .. ":\n" .. tostring(err)
                                    task.wait(2)
                                end
                                task.wait(0.1)
                                
                                local newAmount = getItemCount(itemName)
                                
                                if newAmount > oldAmount then
                                    _G.AutoBuyDebug = "[SUKSES] Membeli Gear: " .. itemName .. " (" .. newAmount .. ")"
                                    failCount = 0 -- Reset kegagalan
                                else
                                    failCount = failCount + 1
                                    if failCount >= 3 then
                                        _G.AutoBuyDebug = "[HABIS/GAGAL] Gear: " .. itemName
                                        task.wait(0.5)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            task.wait(Config.Delay or 10)
            -- Tampilkan status config di debug label saat idle
            -- supaya user bisa cek langsung dari layar apakah config sudah masuk
            local seedCount = 0
            if type(Config.Seeds) == "table" then for _ in pairs(Config.Seeds) do seedCount = seedCount + 1 end end
            local gearCount = 0
            if type(Config.Gears) == "table" then for _ in pairs(Config.Gears) do gearCount = gearCount + 1 end end
            _G.AutoBuyDebug = string.format("[IDLE] Seed:%s(%d) Gear:%s(%d) Delay:%ds",
                Config.BuySeeds and "ON" or "off", seedCount,
                Config.BuyGears and "ON" or "off", gearCount,
                Config.Delay or 10)
        end
    end)
end

-- ==========================
-- PARSER HARGA
-- ==========================
-- Definisinya dipindah lebih jauh ke atas lagi, ke dekat getShopUITextBlob(),
-- karena filter beli-berdasarkan-nilai pada loop Auto Buy (yang letaknya di atas
-- blok ini) ikut memakainya. Lihat blok "PARSER HARGA" di sana.

-- ==========================
-- AUTO SELL HELPERS
-- ==========================
-- Buah asli selalu punya attribute SizeMultiplier. Filter lama berbasis
-- substring nama ikut membuang buah yang kebetulan mengandung nama alat:
-- "Potato" -> "Pot", "Cantaloupe"/"Candy Blossom" -> "Can".
-- Terukur 2026-08-20: dari 22 buah di backpack, 20 berkelas Configuration
-- (proxy FruitProxy) dan hanya 2 Tool. Predikat lama `IsA("Tool")` menghitung
-- 2 dari 22, jadi countSellableFruit() melaporkan "kosong" padahal inventory
-- penuh -- dan startAutoSell melewatkan penjualan karenanya.
local function isSellableFruit(item)
    return item:GetAttribute("HarvestedFruit") == true
end

local function countSellableFruit()
    local n = 0
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if isSellableFruit(item) then n = n + 1 end
    end
    if LocalPlayer.Character then
        for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
            if isSellableFruit(item) then n = n + 1 end
        end
    end
    return n
end

-- Auto sell, daily deal, dan tombol QuickAction sama-sama lewat sini. Tanpa
-- kunci, dua perjalanan bisa tumpang tindih dan saling merusak:
--
--   trip A simpan origin=lahan, teleport ke Steven
--   trip B simpan origin=STEVEN (posisi sekarang), teleport ke Steven
--   trip A selesai, pulihkan CFrame ke lahan  <- fn milik B jalan dari LAHAN
--   trip B selesai, pulihkan CFrame ke STEVEN <- karakter ditinggal di Steven
--
-- Dua akibatnya sama-sama diam: penjualan kedua dijalankan dari jauh (dan
-- PreviewSellAll membalas nol dari sana), lalu karakter berakhir nyangkut di
-- depan Steven karena "posisi asal" yang tersimpan sudah keliru. Perjalanan
-- yang datang belakangan dilewati saja -- pemanggilnya loop, siklus berikutnya
-- akan mencoba lagi.
local sedangKeSteven = false

-- Dekati Steven, jalankan fn, lalu balik ke posisi semula.
-- Bukan `local function`: variabelnya sudah di-forward-declare di atas supaya
-- handler QuickAction (yang letaknya jauh SEBELUM baris ini) bisa memakainya.
-- Menulis `local function` di sini akan membuat local KEDUA yang menaungi yang
-- pertama, dan handler itu tetap melihat nil.
function nearSteven(fn)
    if sedangKeSteven then return false end
    sedangKeSteven = true

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local steven = Workspace:FindFirstChild("Steven", true)
    local target = steven and (
        (steven:IsA("Model") and (steven.PrimaryPart or steven:FindFirstChild("HumanoidRootPart")))
        or (steven:IsA("BasePart") and steven)
    )

    if not (root and target) then
        local ok, res = pcall(fn)
        sedangKeSteven = false
        return ok and res or false
    end

    local origin = root.CFrame
    root.CFrame = target.CFrame + Vector3.new(0, 3, 3)
    task.wait(0.5)

    local ok, res = pcall(fn)

    task.wait(0.3)
    if root.Parent then root.CFrame = origin end
    sedangKeSteven = false
    return ok and res or false
end

-- Terukur 2026-08-26 di server sungguhan: SellFlags.DailyDealMultiplier = 2,2x
-- atas TotalBaseValue. Untuk inventory ber-base 7.860, SellAll membayar 8.134
-- sedangkan UseDailyDealAll 17.292. Jadi selama deal-nya tersedia, menjual
-- biasa membuang lebih dari separuh nilai.
--
-- Keputusannya HARUS diambil di sini -- sesudah PreviewSellAll, saat karakter
-- sudah berada di depan Steven. Dulu daily deal punya loop sendiri yang
-- memutuskan dari lahan, dan dua loop itu memperebutkan inventory yang sama:
-- yang sampai duluan menguras habis, yang belakangan cuma menemukan
-- "[SKIP] Tidak ada buah". Karena auto sell jauh lebih agresif (tanpa ambang
-- ia menjual apa pun yang ada), deal 2,2x praktis tidak pernah kepakai.
-- Keadaan penahanan. Satu tabel, bukan tiga local terpisah, supaya penambahan
-- di scope file tetap hemat terhadap batas 200 local Luau.
--   mulai     = os.time() saat mulai menahan (nil = tidak sedang menahan)
--   tertinggi = nilai inventory tertinggi yang pernah terlihat selama menahan
--   mandek    = berapa siklus beruntun nilainya TIDAK tumbuh
local tahanDD = { mulai = nil, tertinggi = 0, mandek = 0 }

local function lepasTahan()
    tahanDD.mulai, tahanDD.tertinggi, tahanDD.mandek = nil, 0, 0
end

-- Mengembalikan TIGA keadaan, bukan dua:
--   true     -> pakai UseDailyDealAll
--   false    -> jual biasa (SellAll)
--   "tahan"  -> JANGAN jual apa pun; tunggu tumpukan mencapai ambang DD
local function bolehDailyDeal(nilaiInventory, jumlahBuah)
    if not Config.DailyDeal then lepasTahan() return false end

    local ok, res = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
    if not (ok and res and res.Available) then
        -- Deal-nya sudah kepakai/belum siap: tidak ada lagi yang ditunggu.
        -- Wajib melepas tahan di sini, kalau tidak penjualan ikut beku sampai
        -- katup waktu yang menyelamatkan -- telat sampai setengah jam.
        lepasTahan()
        return false
    end

    local ambang = parsePrice(Config.DailyDealThreshold or "0")
    if ambang <= 0 or (nilaiInventory or 0) >= ambang then
        lepasTahan()
        return true
    end

    -- Ambang belum tercapai. Tanpa saklar: jual biasa, deal-nya disimpan untuk
    -- tumpukan berikutnya. Perilaku ini yang default -- menahan penjualan itu
    -- keputusan yang bisa merugikan, jadi harus diminta sendiri.
    if not Config.TahanUntukDailyDeal then
        lepasTahan()
        return false
    end

    local sekarang = os.time()
    local baruMulai = (tahanDD.mulai == nil)
    if baruMulai then
        tahanDD.mulai = sekarang
        tahanDD.tertinggi = nilaiInventory or 0
        tahanDD.mandek = 0
    end

    -- KATUP 1 -- batas waktu. Ambang yang kelewat tinggi (atau panen yang
    -- pelan) tidak boleh membekukan penjualan selamanya.
    local maksDetik = (tonumber(Config.TahanDDMaksMenit) or 30) * 60
    if sekarang - tahanDD.mulai >= maksDetik then
        lepasTahan()
        _G.AutoSellDebug = string.format(
            "[TAHAN LEPAS] Lewat %d menit, ambang DD tak tercapai -- jual biasa.",
            math.floor(maksDetik / 60))
        return false
    end

    -- KATUP 2 -- inventory hampir penuh. Terukur 2026-08-26 di server sungguhan:
    -- player punya atribut `MaxFruitCapacity` = 100, dan `preview.FruitCount`
    -- memakai satuan yang sama persis (18 = 18 item ber-atribut HarvestedFruit).
    -- Begitu penuh, panen BERHENTI -- menahan penjualan lebih lama justru
    -- membuat bot berhenti bekerja sama sekali.
    --
    -- Sisa 5 slot itu pilihan, bukan hasil ukur: siklus auto sell 30 detik,
    -- jadi menunggu sampai persis penuh berarti panen sempat mandek di selanya.
    local kapasitas = tonumber(LocalPlayer:GetAttribute("MaxFruitCapacity")) or 100
    if (jumlahBuah or 0) >= kapasitas - 5 then
        lepasTahan()
        _G.AutoSellDebug = string.format(
            "[TAHAN LEPAS] Inventory %d/%d hampir penuh -- jual biasa.",
            jumlahBuah or 0, kapasitas)
        return false
    end

    -- KATUP 3 -- nilainya berhenti tumbuh walau inventory belum penuh. Artinya
    -- panen mandek karena sebab lain (lahan kosong, karakter nyangkut), dan
    -- menunggu lebih lama tidak akan menambah apa pun.
    -- Siklus pertama hanya MENETAPKAN garis dasar. Menghitungnya sebagai
    -- "tidak tumbuh" bikin katup lepas satu siklus lebih cepat dari yang
    -- tertulis di pesannya -- angka yang bohong kecil, tapi bohong.
    if baruMulai then
        return "tahan"
    end

    if (nilaiInventory or 0) > tahanDD.tertinggi then
        tahanDD.tertinggi = nilaiInventory or 0
        tahanDD.mandek = 0
    else
        tahanDD.mandek = tahanDD.mandek + 1
        if tahanDD.mandek >= 5 then
            lepasTahan()
            _G.AutoSellDebug = "[TAHAN LEPAS] Nilai berhenti tumbuh 5 siklus -- jual biasa."
            -- (pesan sengaja beda dari katup kapasitas: dua sebab yang berbeda
            --  tidak boleh terbaca sama di panel)
            return false
        end
    end

    return "tahan"
end

-- Urutan yang dipakai game asli (NPCController.Sell_Steven):
--     PreviewSellAll  ->  cek FruitCount  ->  SellAll / UseDailyDealAll
-- PreviewSellAll yang men-stage transaksi di server. Tanpa itu SellAll ditolak,
-- dan karena return value-nya dulu dibuang, kegagalan tidak pernah terlihat.
function PerformSell(useDailyDeal)
    local ok, preview = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
    if not ok or typeof(preview) ~= "table" then
        _G.AutoSellDebug = "[GAGAL] PreviewSellAll error: " .. tostring(preview)
        return false
    end

    local fruitCount = preview.FruitCount or 0
    if fruitCount <= 0 then
        _G.AutoSellDebug = "[SKIP] Tidak ada buah untuk dijual."
        return false
    end

    -- Mode "auto": pemanggil menyerahkan pilihan SellAll/UseDailyDealAll ke
    -- sini, karena baru di titik ini dua syaratnya terpenuhi sekaligus --
    -- karakter sudah dekat Steven, dan nilai inventory sudah terbaca.
    -- Wajib jadi boolean sebelum baris `remote` di bawah: string "auto" itu
    -- truthy, jadi kalau dibiarkan ia akan selalu memilih daily deal.
    if useDailyDeal == "auto" then
        local nilai = preview.TotalSellValue or preview.TotalValue or 0
        useDailyDeal = bolehDailyDeal(nilai, fruitCount)

        -- "tahan": tumpukan belum mencapai ambang daily deal dan pemain minta
        -- ditunggu. Keluar TANPA menjual -- justru menjual di sini yang membuat
        -- ambangnya tidak pernah tercapai.
        if useDailyDeal == "tahan" then
            _G.AutoSellDebug = string.format(
                "[TAHAN] %s < ambang DD %s -- menunggu tumpukan.",
                tostring(math.floor(nilai)),
                tostring(parsePrice(Config.DailyDealThreshold or "0")))
            return false
        end
    end

    -- Game asli menunggu lebih lama sebelum commit kalau inventory besar
    if fruitCount > 100 then task.wait(1) else task.wait(0.25) end

    local remote = useDailyDeal and Networking.NPCS.UseDailyDealAll or Networking.NPCS.SellAll
    local label = useDailyDeal and "DAILY DEAL" or "SELL ALL"

    local ok2, res = pcall(function() return remote:Fire() end)
    if not ok2 then
        _G.AutoSellDebug = "[GAGAL] " .. label .. " error: " .. tostring(res)
        return false
    end

    if res and res.Success then
        _G.AutoSellDebug = string.format(
            "[SUKSES] %s: %d item -> %s",
            label, res.SoldCount or 0, tostring(res.SellPrice or 0)
        )
        return true
    end

    _G.AutoSellDebug = string.format(
        "[GAGAL] %s ditolak server. Reason=%s",
        label, tostring(res and res.Reason or "nil")
    )
    return false
end

-- Harga jual tiap jenis buah BERFLUKTUASI, dan servernya membuka datanya.
--
-- Networking.FruitStock.Request:Fire() mengembalikan:
--     { enabled, cycleSeconds=600, nextRefreshUnix, server_now_unix,
--       entries = { ["Coconut"] = { multiplier = 0.88, tier = "normal" }, ... } }
--
-- Terukur di server sungguhan: 38 buah, pengali 0,801 sampai 2,000, dan tier
-- hanya dua -- "normal" (35 buah) dan "big" (3 buah). Yang ber-tier "big"
-- pengalinya PERSIS 2,000. Jadi "harga 2x" itu bukan tebakan: ia keadaan yang
-- benar-benar ada, berganti tiap 10 menit.
--
-- Nama buah di inventory langsung cocok dengan kunci entries -- Tool.Name buah
-- hasil panen memang nama dasarnya ("Coconut"), sama seperti yang sudah dipakai
-- getTotalFruitValue() untuk FruitValueCalc.
-- Pendeteksi buah. TIGA koreksi terhadap versi lama, ketiganya diukur
-- 2026-08-20 di server sungguhan:
--
--   1. Buah TIDAK selalu Tool. Dari 22 buah di backpack, 20 berkelas
--      Configuration (proxy, beratribut FruitProxy=true) dan hanya 2 Tool.
--      Filter `IsA("Tool")` melewatkan 90% isi inventory.
--   2. Kunci `entries` itu nama DASAR ("Coconut"), sedangkan Tool.Name memuat
--      berat ("Coconut [1.58kg]"). Terukur: `entries[item.Name]` nil untuk
--      SEMUA buah, jadi pemicu pengali lama tidak pernah menyala sekali pun.
--   3. Nama dasar sudah tersedia di atribut FruitName -- tidak perlu memotong
--      string dan menebak formatnya.
local function tiapBuah(fn)
    local function scan(parent)
        if not parent then return end
        for _, item in ipairs(parent:GetChildren()) do
            if item:GetAttribute("HarvestedFruit") == true then fn(item) end
        end
    end
    scan(LocalPlayer.Backpack)
    if LocalPlayer.Character then scan(LocalPlayer.Character) end
end

-- Papan harga buah. Terukur: cycleSeconds = 600, jadi pengali diacak ulang
-- tiap 10 menit. Tier yang ada: normal / big (persis x2) / mega / harvest.
-- Fiturnya di balik AB test "Sell.PriceStock.Enabled" -- kalau akun tidak
-- kebagian, snap.enabled false dan kita TIDAK menjual apa pun.
local function pengaliStok()
    local ok, snap = pcall(function() return Networking.FruitStock.Request:Fire() end)
    if not ok or typeof(snap) ~= "table" then return nil end
    if snap.enabled == false or typeof(snap.entries) ~= "table" then return nil end
    return snap.entries
end

-- Jual HANYA buah yang jenisnya sedang kena pengali >= minimal.
--
-- Bedanya dengan PerformSell: SellAll membuang SELURUH inventory pada harga
-- masing-masing, termasuk buah yang kebetulan sedang 0,8x. Jendela pengali
-- tinggi cuma 10 menit dan hanya mengenai beberapa jenis; menjual sisanya
-- sekalian justru membuang nilai.
--
-- Protokol terukur 2026-08-20: SellFruit:Fire(Id) berhasil LANGSUNG dari
-- backpack -- tanpa equip, dan tanpa staging PreviewSellAll seperti SellAll.
-- Dua penjualan uji: Success=true, saldo naik persis sebesar SellPrice.
local function jualBuahPengaliTinggi(minimal)
    local entries = pengaliStok()
    if not entries then
        _G.AutoSellDebug = "[PENGALI] papan harga tidak tersedia"
        return 0, 0
    end

    local sasaran = {}
    tiapBuah(function(item)
        -- Buah favorit TIDAK dijual. Mencentang favorit itu cara pemain
        -- menandai simpanan, dan menjualnya tidak bisa dibatalkan. Server pun
        -- menolak menawar buah favorit ("You cannot bargain favorited fruit!").
        if item:GetAttribute("IsFavorite") == true then return end
        local nama = item:GetAttribute("FruitName")
        local id = item:GetAttribute("Id")
        if not nama or not id then return end
        local e = entries[nama]
        local m = e and tonumber(e.multiplier) or 0
        if m >= minimal then
            sasaran[#sasaran + 1] = { id = id, nama = nama, pengali = m }
        end
    end)

    if #sasaran == 0 then return 0, 0 end

    local terjual, hasil, gagalBeruntun = 0, 0, 0
    local jenis = {}
    for _, b in ipairs(sasaran) do
        local ok, res = pcall(function() return Networking.NPCS.SellFruit:Fire(b.id) end)
        if ok and typeof(res) == "table" and res.Success then
            terjual = terjual + 1
            hasil = hasil + (tonumber(res.SellPrice) or 0)
            jenis[b.nama] = (jenis[b.nama] or 0) + 1
            gagalBeruntun = 0
        else
            -- Berhenti setelah beberapa penolakan beruntun. Kalau server
            -- menolak (jarak, cooldown, atau buah sudah tidak ada), meneruskan
            -- ratusan tembakan cuma menambah beban tanpa hasil.
            gagalBeruntun = gagalBeruntun + 1
            if gagalBeruntun >= 5 then break end
        end
        task.wait(0.15)
    end

    local rinci = {}
    for nama, n in pairs(jenis) do rinci[#rinci + 1] = nama .. " x" .. n end
    table.sort(rinci)
    _G.AutoSellDebug = string.format(
        "[PENGALI] %d/%d buah terjual (>=%.2fx) -> %d | %s",
        terjual, #sasaran, minimal, math.floor(hasil),
        (#rinci > 0 and table.concat(rinci, ", ") or "-"))
    return terjual, hasil
end

-- 9. AUTO SELL
local function startAutoSell()
    task.spawn(function()
        while true do
            if Config.AutoSell then
                local threshold = parsePrice(Config.AutoSellThreshold or "0")
                local proceed = true

                -- PENGALI MENDAHULUI THRESHOLD. Jendela harga naik cuma 10
                -- menit, sedangkan threshold dibuat untuk menunggu tumpukan
                -- besar. Kalau threshold didahulukan, buah yang sedang mahal
                -- ditahan sampai jendelanya lewat -- kebalikan dari yang mau.
                --
                -- Jalur selektif: jual HANYA jenis yang sedang kena pengali,
                -- lalu selesai -- jangan diteruskan ke SellAll di bawah.
                --
                -- Jalur lama (JualSaat2x + buahPengaliTinggi + SellAll) DIBUANG.
                -- Ia tidak pernah menyala karena `entries[item.Name]` selalu nil
                -- dan filter IsA("Tool") melewatkan buah proxy; kalaupun menyala
                -- ia memanggil SellAll yang membuang seluruh inventory. Kunci
                -- JualSaat2x/Ambang2x juga tidak pernah ada di panel.
                -- Mode jual dari panel: "0"/kosong = normal (jual semua lewat
                -- SellAll di bawah), "2" atau "4" = hanya jenis yang pengalinya
                -- mencapai angka itu. Nilai tak terbaca jatuh ke 0 = perilaku
                -- lama, bukan menjual selektif dengan ambang tebakan.
                local minimal = tonumber(Config.AmbangPengali) or 0
                if minimal > 0 then
                    if jualBuahPengaliTinggi(minimal) > 0 then
                        proceed = false
                    end
                end

                if not proceed then
                    -- sudah ditangani jalur selektif
                elseif threshold > 0 then
                    local okp, preview = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
                    local value = 0
                    if okp and typeof(preview) == "table" then
                        value = preview.TotalSellValue or preview.TotalValue or 0
                    end
                    if value < threshold then
                        proceed = false
                        _G.AutoSellDebug = string.format(
                            "[TUNGGU] Nilai %s < threshold %s", tostring(value), tostring(threshold)
                        )
                    end
                elseif countSellableFruit() <= 0 then
                    proceed = false
                    _G.AutoSellDebug = "[SKIP] Inventory kosong."
                end

                if proceed then
                    -- "auto", bukan false: satu perjalanan, satu keputusan.
                    -- PerformSell yang memilih SellAll atau UseDailyDealAll
                    -- sesudah PreviewSellAll. Selama dipaksa false di sini,
                    -- auto sell selalu menang duluan atas loop daily deal dan
                    -- menghabiskan buah yang seharusnya dijual 2,2x.
                    nearSteven(function() return PerformSell("auto") end)
                end
            end
            task.wait(Config.SellDelay or 30)
        end
    end)
end

-- DUA perbaikan, keduanya terukur 2026-08-20 dan keduanya membuat fungsi ini
-- SELALU mengembalikan 0 sebelumnya:
--
--   1. Filter `IsA("Tool")` cuma melihat 2 dari 22 buah (sisanya Configuration).
--   2. FruitValueCalc minta nama DASAR. Diuji pada buah yang sama:
--        FruitValueCalc("Coconut [1.69kg]", ...) -> 0
--        FruitValueCalc("Coconut", ...)          -> 80
--      Nama dasar diambil dari atribut FruitName, bukan dipotong dari Tool.Name.
local function getTotalFruitValue()
    local total = 0
    tiapBuah(function(item)
        pcall(function()
            local nama = item:GetAttribute("FruitName")
            if not nama then return end
            local size = item:GetAttribute("SizeMultiplier") or 1
            local decay = item:GetAttribute("DecayAlpha") or 0
            local mutation = item:GetAttribute("Mutation")
            local price = FruitValueCalc(nama, size, mutation, LocalPlayer, decay)
            if type(price) == "number" then
                total = total + price
            end
        end)
    end)
    return total
end

-- 6. AUTO DAILY DEAL (cek tiap 10s)
local function startAutoDailyDeal()
    task.spawn(function()
        while true do
            -- Kalau auto sell nyala, DIA yang menjual dan dia pula yang
            -- memutuskan pakai daily deal atau tidak (PerformSell "auto").
            -- Loop ini tidak boleh ikut menjual: dua loop yang menjual
            -- inventory yang sama saling mendahului, dan yang kalah cuma
            -- menemukan inventory kosong. Loop ini tetap hidup untuk akun yang
            -- daily deal-nya nyala TANPA auto sell.
            if Config.DailyDeal and not Config.AutoSell then
                local ok, res = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)

                if ok and res and res.Available then
                    local threshold = parsePrice(Config.DailyDealThreshold or "0")

                    --[[ CEK THRESHOLD DIPINDAH KE DALAM nearSteven.

                         Dulu PreviewSellAll untuk threshold dipanggil di sini,
                         dari posisi farming. Padahal jalur QuickAction di atas
                         sudah mencatat temuan sebaliknya: PreviewSellAll hanya
                         menjawab angka sebenarnya kalau pemain berada dekat
                         Steven, dan dari jauh ia membalas nol.

                         Akibatnya value selalu 0, `0 < threshold` selalu benar,
                         dan daily deal TIDAK PERNAH diklaim selama threshold
                         diisi -- tanpa error, cuma "[TUNGGU] 0 < threshold" yang
                         terbaca seperti "belum cukup mahal". Threshold 0 tidak
                         kena karena cabangnya dilewati sama sekali; itu yang
                         membuat bug ini hanya menimpa sebagian akun.

                         Preview dan penjualan sekarang satu perjalanan: berangkat
                         dua kali berarti dua kali meninggalkan lahan. ]]
                    -- Inventory kosong dicek dari sini, sebelum berangkat.
                    -- Tanpa ini loop berjalan tiap 10 detik: gagal "tidak ada
                    -- buah" tidak kena cooldown, jadi karakter ditarik dari
                    -- lahan ke Steven dan balik lagi enam kali semenit.
                    if countSellableFruit() <= 0 then
                        _G.DailyDealDebug = "[SKIP] Inventory kosong, tidak berangkat."
                        task.wait(10)
                        continue
                    end

                    local pesanTunggu
                    local sold = nearSteven(function()
                        if threshold > 0 then
                            local okp, preview = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
                            local value = 0
                            if okp and typeof(preview) == "table" then
                                value = preview.TotalSellValue or preview.TotalValue or 0
                            end
                            if value < threshold then
                                pesanTunggu = string.format(
                                    "[TUNGGU] %s < threshold %s", tostring(value), tostring(threshold)
                                )
                                return false
                            end
                        end
                        return PerformSell(true)
                    end)

                    -- Pesan threshold TIDAK boleh tertimpa AutoSellDebug: kalau
                    -- tertimpa, alasan "belum cukup mahal" berubah jadi "tidak ada
                    -- buah", dan itu menuduh keadaan yang salah.
                    _G.DailyDealDebug = pesanTunggu or _G.AutoSellDebug

                    -- Cooldown hanya kalau benar-benar terjual, biar kegagalan
                    -- tidak memblokir 60 detik percuma.
                    if sold then
                        task.wait(60)
                    elseif pesanTunggu then
                        -- Belum cukup mahal: jangan bolak-balik ke Steven tiap 10
                        -- detik. Perjalanannya memindahkan karakter dari lahan,
                        -- jadi mengulanginya sesering itu mengganggu farming lebih
                        -- besar daripada manfaat responsifnya.
                        task.wait(60)
                    end
                else
                    _G.DailyDealDebug = "[IDLE] Daily deal belum tersedia."
                end
            elseif Config.DailyDeal then
                _G.DailyDealDebug = "[AUTOSELL] Deal dipakai lewat auto sell."
            end
            task.wait(10)
        end
    end)
end

-- AUTO RECONNECT (ERROR CODE 529 DLL)
local function setupAutoReconnect()
    if not Config.AutoReconnect then return end
    print("[+] Auto Reconnect (Error Handler) diaktifkan.")
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    
    task.spawn(function()
        while true do
            task.wait(5)
            pcall(function()
                -- Cek ErrorCode dari GuiService (Metode Paling Ampuh di Mobile)
                -- titipKode() WAJIB sebelum tiap rejoin. Tanpa itu akun memang
                -- kembali masuk game, tapi tanpa script apa pun -- online,
                -- terlihat sehat di monitor, dan sama sekali tidak bekerja.
                local errorCode = GuiService:GetErrorCode()
                if errorCode and errorCode.Value ~= 0 then
                    print("[!] Terdeteksi Disconnect (ErrorCode: " .. tostring(errorCode.Value) .. "). Melakukan Teleport...")
                    titipKode()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end

                -- Cek PromptOverlay (Cadangan)
                local promptOverlay = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui") and game:GetService("CoreGui").RobloxPromptGui:FindFirstChild("promptOverlay")
                if promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt") then
                    print("[!] Terdeteksi Error Prompt UI. Melakukan Teleport...")
                    titipKode()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end
    end)
end

-- ANTI AFK
local function setupAntiAFK()
    print("[+] Anti-AFK diaktifkan.")
    
    LocalPlayer.Idled:Connect(function()
        if antiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)

    task.spawn(function()
        while true do
            task.wait(math.random(150, 240)) 
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
end

-- AUTO ADD & ACCEPT FRIEND
local function startAutoFriend()
    if not Config.AutoFriend then return end
    print("[+] Mengaktifkan Auto Add & Accept Friend...")
    task.spawn(function()
        while true do
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    pcall(function()
                        LocalPlayer:RequestFriendship(player)
                    end)
                end
            end
            task.wait(60)
        end
    end)
end

-- FLY TO TARGET (ANTI-BAN)
local function flyToTarget(targetPos)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return false end
    
    local root = char.HumanoidRootPart
    local hum = char.Humanoid
    local finalTarget = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    local distance = (root.Position - finalTarget).Magnitude
    if distance <= 8 then return true end 
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    hum.PlatformStand = true 
    
    local noclipConnection
    noclipConnection = game:GetService("RunService").Stepped:Connect(function()
        if char then
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end
    end)
    
    local speed = 25 
    local timeout = 0
    local maxTime = (distance / speed) + 5 
    while char and root and (root.Position - finalTarget).Magnitude > 5 and timeout < maxTime do
        local direction = (finalTarget - root.Position).Unit
        bv.Velocity = direction * speed
        task.wait(0.05)
        timeout = timeout + 0.05
    end
    
    if noclipConnection then noclipConnection:Disconnect() end
    if bv then pcall(function() bv:Destroy() end) end
    root.Velocity = Vector3.zero
    hum.PlatformStand = false 
    task.wait(0.2)
    return (root.Position - finalTarget).Magnitude <= 15
end

-- AUTO SEED COLLECTOR (HEADLESS)
local function startAutoSeedCollector()
    if not Config.CollectSeed then return end
    getgenv().KaitunStatus = "Auto Seed Collector..."
    print("[+] Mengaktifkan Auto Seed Collector (Tumbal)...")
    local wasCollecting = false
    
    task.spawn(function()
        while true do
            task.wait(2.5) -- Diperlambat agar CPU tidak panas
            local foundSeed = nil
            local targetPrompt = nil
            
            local prompts = workspace:GetDescendants()
            for i, prompt in ipairs(prompts) do
                if i % 1000 == 0 then task.wait() end -- YIELD PENTING: Mencegah CPU Spike / Lag saat looping
                if prompt:IsA("ProximityPrompt") then
                    local obj = prompt.Parent
                    if obj and (obj:IsA("Model") or obj:IsA("BasePart")) then
                        local name = obj.Name:lower()
                        local parentName = (obj.Parent and obj.Parent.Name) and obj.Parent.Name:lower() or ""
                        local actionText = prompt.ActionText:lower()
                        local objectText = prompt.ObjectText:lower()
                        local isValidSeed = false
                        
                        if actionText:match("pick up") or actionText:match("collect") or actionText:match("take") or actionText:match("grab") or actionText:match("loot") or actionText:match("claim") then
                            isValidSeed = true
                        else
                            local combinedText = name .. " " .. parentName .. " " .. objectText
                            local isCrop = false
                            local seedKeywords = {"seed", "gold", "mega", "rainbow", "mutation", "carrot", "apple", "pomegranate", "coconut", "cactus", "mushroom", "bamboo", "corn", "berry", "acorn", "cranberry", "pumpkin", "banana", "beanstalk", "blossom", "rose", "buttercup", "cherry", "cinnamon", "cone", "dragon", "eclipse", "fern", "pepper", "grape", "bean", "melon", "hypno", "lotus", "mango", "moon", "partfruit", "pineapple", "pine", "plum", "poison", "pop", "romanesco", "star", "sun", "thorn", "tomato", "tulip", "venom", "venus", "flare", "crate"}
                            
                            for _, kw in ipairs(seedKeywords) do
                                if combinedText:match(kw) then
                                    isCrop = true
                                    break
                                end
                            end
                            
                            if isCrop then
                                if actionText ~= "harvest" and actionText ~= "sit" and actionText ~= "talk" and actionText ~= "buy" and actionText ~= "use" then
                                    isValidSeed = true
                                end
                            end
                        end
                        
                        if isValidSeed then
                            foundSeed = obj
                            targetPrompt = prompt
                            break
                        end
                    end
                end
            end
            
            if foundSeed and targetPrompt then
                wasCollecting = true
                
                -- AMBIL POSISI DENGAN AMAN (Bisa dari Part, Attachment, atau dalam Model)
                local targetPos = nil
                if targetPrompt.Parent:IsA("BasePart") then
                    targetPos = targetPrompt.Parent.Position
                elseif targetPrompt.Parent:IsA("Attachment") then
                    targetPos = targetPrompt.Parent.WorldPosition
                else
                    local part = foundSeed:IsA("BasePart") and foundSeed or foundSeed:FindFirstChildWhichIsA("BasePart", true)
                    if part then targetPos = part.Position end
                end
                
                if targetPos then
                    local reached = flyToTarget(targetPos)
                    if reached then
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        -- Buat pijakan sementara
                        local tempPlat = Instance.new("Part")
                        tempPlat.Name = "TempSeedPlatform"
                        tempPlat.Size = Vector3.new(15, 1, 15)
                        tempPlat.Position = targetPos - Vector3.new(0, 4, 0)
                        tempPlat.Anchored = true
                        tempPlat.Transparency = 0.5
                        tempPlat.BrickColor = BrickColor.new("Bright green")
                        tempPlat.Material = Enum.Material.Neon
                        tempPlat.Parent = workspace
                        game:GetService("Debris"):AddItem(tempPlat, 5)
                        
                        -- BUKA KUNCI PROMPT AGAR 100% BISA DITEKAN
                        targetPrompt.RequiresLineOfSight = false
                        targetPrompt.MaxActivationDistance = 9999
                        if targetPrompt.HoldDuration > 0 then targetPrompt.HoldDuration = 0 end
                        
                        -- SPAM KLIK SUPER BARBAR DI BACKGROUND (Spam 20x)
                        task.spawn(function()
                            for i=1, 20 do
                                pcall(fireproximityprompt, targetPrompt)
                                task.wait(0.05)
                            end
                        end)
                        
                        task.wait(1) -- Beri waktu sebentar untuk memastikan barang masuk
                    end
                end
                end
            else
                if wasCollecting then
                    wasCollecting = false
                    print("[+] Selesai mungut barang, kembali ke Steven...")
                    local steven = Workspace:FindFirstChild("Steven", true)
                    if steven then
                        local st = (steven:IsA("Model") and (steven.PrimaryPart or steven:FindFirstChild("HumanoidRootPart"))) or (steven:IsA("BasePart") and steven)
                        if st then
                            flyToTarget(st.Position + Vector3.new(0, 0, 3))
                        end
                    end
                end
            end
        end
    end)
end

-- =========================================================================
-- AUTO TAME PET (GETGENV CONFIG)
-- =========================================================================

local function flightTo(targetPart, offset, speed)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not targetPart then return end
    
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVel.Parent = root
    
    local reached = false
    local connection
    
    connection = RunService.Heartbeat:Connect(function()
        if not targetPart or not targetPart.Parent then
            reached = true
            return
        end
        local currentPos = root.Position
        local targetPos = targetPart.Position + offset
        local distance = (targetPos - currentPos).Magnitude
        
        if distance <= 3 then
            reached = true
        else
            bodyVel.Velocity = (targetPos - currentPos).Unit * speed
            root.CFrame = CFrame.lookAt(currentPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))
        end
    end)
    
    while not reached do task.wait() end
    connection:Disconnect()
    bodyVel:Destroy()
    root.Velocity = Vector3.new(0, 0, 0)
end

-- parsePriceTame(): mengubah teks harga jadi angka. Menangani format
-- "50000", "¢50,000", dan K/M/B.
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

-- cariWildPet(): mencari hewan liar sesuai whitelist, terdekat dari karakter.
local WH_PATH = {"Map", "WildPetSpawns"}

local function cariWildPet()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    local folder = Workspace
    for _, seg in ipairs(WH_PATH) do
        folder = folder:FindFirstChild(seg)
        if not folder then return nil end
    end

    local myPos = char.HumanoidRootPart.Position
    local tameSet = {}
    for _, nm in ipairs(Config.TamePets or {}) do tameSet[string.lower(string.gsub(nm, "%s+", ""))] = true end

    -- KRITERIA LEPAS-JENIS. Satu wild pet diambil kalau jenisnya dicentang ATAU
    -- ukurannya diminta ATAU dia Rainbow -- apa pun spesiesnya.
    --
    -- Sumbernya atribut yang disalin SpawnPetController ke model wild pet saat
    -- membuatnya (baris 863-866 di script game):
    --     PetSize = "Big" / "Huge" / nil   (nil = ukuran biasa)
    --     PetType = "Rainbow" / nil
    -- Hanya ada dua ukuran istimewa: PetSizes.Scales terukur {Big=2, Huge=4}.
    -- Nama ukuran dibandingkan huruf kecil supaya "big"/"Big"/"BIG" sama saja.
    local sizeSet = {}
    if type(Config.TameSizes) == "table" then
        if #Config.TameSizes > 0 then
            for _, sz in ipairs(Config.TameSizes) do sizeSet[string.lower(tostring(sz))] = true end
        else
            for sz, aktif in pairs(Config.TameSizes) do
                if aktif then sizeSet[string.lower(tostring(sz))] = true end
            end
        end
    end
    local mauRainbow = Config.TameRainbow == true

    local terbaik, jarakTerbaik = nil, math.huge
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            local petType = pet.Name:match("WildPet_(%w+)_WildPet")
            local ukuran = pet:GetAttribute("PetSize")
            local mutasi = pet:GetAttribute("PetType")
            local alasan = nil
            if petType then
                if tameSet[string.lower(petType)] then
                    alasan = "jenis"
                elseif ukuran ~= nil and sizeSet[string.lower(tostring(ukuran))] then
                    alasan = "ukuran " .. tostring(ukuran)
                elseif mauRainbow and mutasi == "Rainbow" then
                    alasan = "Rainbow"
                end
            end
            if alasan then
                local root = pet:FindFirstChild("RootPart")
                local prompt = root and root:FindFirstChild("BuyPrompt")
                if root and prompt then
                    local d = (root.Position - myPos).Magnitude
                    if d < jarakTerbaik then
                        local price = parsePriceTame(prompt.ObjectText or "")
                        local maxBid = parsePriceTame(Config.MaxTameBid)
                        if maxBid <= 0 or price <= maxBid then
                            terbaik = {model = pet, root = root, prompt = prompt,
                                       petType = petType, price = price,
                                       alasan = alasan, ukuran = ukuran, mutasi = mutasi}
                            jarakTerbaik = d
                        end
                    end
                end
            end
        end
    end
    return terbaik
end

-- teleportSell(): pakai GUI teleport untuk balik ke Sell setelah tame.
local function teleportSell()
    if not Config.PakaiTeleportGui then return end
    pcall(function()
        Networking.TeleportButton.Request:Fire("Sell")
    end)
    task.wait(1.5)
end

-- tameSatu(): satu siklus tame — cari, terbang, fire prompt, tunggu, teleport.
local function tameSatu()
    local pet = cariWildPet()
    if not pet then return end

    print("[TAME] " .. pet.petType .. " ditemukan (¢" .. tostring(pet.price)
        .. ") | cocok karena: " .. tostring(pet.alasan)
        .. " | size=" .. tostring(pet.ukuran) .. " type=" .. tostring(pet.mutasi))

    -- terbang ke hewan
    flightTo(pet.root, Vector3.new(0, 3, 0), 50)
    task.wait(0.2)

    -- fire proximity prompt
    if fireproximityprompt then
        fireproximityprompt(pet.prompt)
    end

    print("[TAME] Proximity prompt fired, menunggu...")

    -- tunggu sampai hewan hilang atau timeout 15 detik
    local batas = tick() + 15
    while tick() < batas do
        if not pet.model.Parent or not pet.model:FindFirstChild("RootPart") then
            print("[TAME] Berhasil tame " .. pet.petType .. "!")
            task.wait(1)
            teleportSell()
            return true
        end
        task.wait(0.3)
    end

    print("[TAME] Timeout — tetap teleport balik")
    teleportSell()
    return false
end


-- ==========================
-- --- EKSEKUSI URUTAN ---
-- ==========================

-- ==========================
setupAutoReconnect()
setupAntiAFK()
startAutoFriend()
startAutoSeedCollector()
startAutoClick()

task.spawn(function()
    -- 0. CLICK FULLY LOADED -- DEFAULT MATI, dan kuncinya sendiri.
    --
    -- Blok ini penyebab keluhan "sudah bypass tutorial tapi karakter bergerak
    -- sendiri dan beli 1 carrot". Dua hal di versi lama, dua-duanya berbahaya:
    --
    --  (1) Klik buta di koordinat 20%/80% layar lewat VirtualUser. Itu klik
    --      SUNGGUHAN ke dunia -- karakter ikut bergerak, dan kalau kebetulan
    --      mendarat di UI toko, ia menekan apa pun yang ada di situ.
    --
    --  (2) Pencocokan SUBSTRING pada gui.Name. "play" cocok dengan
    --      PlayerStats, PlayerSelector, PlayerGardenMarket; "start" cocok
    --      dengan apa pun yang mengandungnya. Jadi MouseButton1Click ditembakkan
    --      ke tombol-tombol acak di seluruh PlayerGui, 15 kali berturut-turut.
    --      Itulah pembelian carrot yang tidak pernah diminta siapa pun.
    --
    -- Sekarang: kunci terpisah dari BypassTutorial (dulu ikut menyala begitu
    -- bypass dinyalakan), default MATI, klik buta dibuang, dan pencocokan hanya
    -- pada TEKS tombol yang benar-benar terlihat -- bukan namanya.
    if Config.KlikLayarMuat == true then
        task.spawn(function()
            for _ = 1, 15 do
                -- Berhenti begitu benar-benar masuk: tombol "play/loaded" hanya
                -- ada di layar muat, jadi setelah itu tidak ada yang perlu
                -- diklik dan menembak terus hanya menambah risiko.
                if LocalPlayer:GetAttribute("LoadingScreenDone") == true then break end

                pcall(function()
                    for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                        if gui:IsA("TextButton") and gui.Visible then
                            local teks = string.lower(gui.Text or "")
                            -- Dicocokkan UTUH, bukan substring. Teks tombol layar
                            -- muat memang pendek dan pasti; substring justru
                            -- menjaring tombol lain yang kebetulan sehuruf.
                            if teks == "play" or teks == "start" or teks == "loaded"
                               or teks == "continue" or teks == "tap to play" then
                                if getconnections then
                                    for _, conn in pairs(getconnections(gui.MouseButton1Click)) do conn:Fire() end
                                    for _, conn in pairs(getconnections(gui.Activated)) do conn:Fire() end
                                end
                            end
                        end
                    end
                end)
                task.wait(1)
            end
        end)
    end

    -- 1. BYPASS TUTORIAL
    local function isInTutorial()
        local char = LocalPlayer.Character
        -- cek workspace + character attribute
        if Workspace:GetAttribute("InTutorial") == true then return true end
        if char and char:GetAttribute("InTutorial") == true then return true end
        -- fallback: kalau attribute belum direplikasi, cek ada TutorialUI yang enabled
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled
                    and string.find(gui.Name:lower(), "tutorial", 1, true) then
                    return true
                end
            end
            local tut = pg:FindFirstChild("TutorialUI", true)
            if tut and tut:IsA("ScreenGui") and tut.Enabled then return true end
        end
        return false
    end

    -- Menyala kecuali dimatikan eksplisit dari panel.
    --
    -- Akun yang mendarat di tutorial TIDAK BISA bertani sama sekali, jadi tidak
    -- ada keadaan di mana membiarkannya lebih baik. Untuk akun yang sudah lewat
    -- tutorial ini nol biaya: isInTutorial() langsung false dan blok ini dilewati.
    if Config.BypassTutorial ~= false then
        -- Retry loop: tunggu karakter + InTutorial attribute siap. Satu cek
        -- saja terlalu cepat — karakter mungkin belum spawn atau attribute
        -- belum direplikasi saat task.spawn ini mulai jalan.
        local inTutorial = false
        for attempt = 1, 20 do
            if isInTutorial() then
                inTutorial = true
                break
            end
            task.wait(0.5)
        end

        if inTutorial then
            completeTutorialInstantly()
            task.wait(1)
            -- pasca-bypass: pastikan benar-benar bersih
            bersihkanSisaTutorial()
        else
            print("[1/6] Bypass tutorial: bukan akun tutorial (skip)")
        end
    end
    
    -- 1.5 AUTO KEMBALI KE WORLD 2 -- dijalankan oleh PENGAWAS di bawah,
    --     bukan di sini. Lihat catatan di task.spawn "AUTO KEMBALI KE WORLD 2".

    -- 2. TELEPORT KE STEVEN
    teleportToSteven()
    task.wait(1)
    
    -- 3. AUTO CLAIM MAIL
    startAutoClaimMail()
    task.wait(0.5)
    
    -- 4. FPS BOOST
    applyFpsBoost()
    task.wait(0.5)
    
    -- 5. AUTO BUY
    startAutoBuy()
    task.wait(0.5)
    -- 6. AUTO DAILY DEAL
    startAutoDailyDeal()
    task.wait(0.5)
    
    -- 7. AUTO TAME PET
    task.wait(0.5)

    -- 8. AUTO SEND MAIL BERKALA (Target & interval diatur dari Web Panel)
    startAutoSendMail()
    task.wait(0.5)

    -- 8. AUTO SELL
    startAutoSell()
    
    getgenv().KaitunStatus = "Idling & Monitoring..."
    print("[+] Selesai! Semua fitur telah dijalankan dan sedang bekerja di latar belakang.")
end)

-- =========================================================================
-- SYSTEM ANTI FORCE CLOSE (MEMORY LEAK PREVENTION)
task.spawn(function()
    while true do
        task.wait(60) -- Setiap 1 menit
        pcall(function()
            -- Paksa Lua Engine untuk membuang memori sampah (Mencegah LUA Heap membesar)
            collectgarbage("collect")
            
            -- Bersihkan console exploit yang sering menyebabkan GUI memory leak (22000+ UI Objects)
            if clearconsole then 
                clearconsole() 
            end
        end)
    end
end)

-- =========================================================================
-- AUTO UNFAV FRUIT BACKGROUND LOOP
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local Networking
    pcall(function() Networking = require(RS:WaitForChild("SharedModules"):WaitForChild("Networking")) end)
    local LocalPlayer = game:GetService("Players").LocalPlayer

    while task.wait(5) do
        -- Dulu membaca `_G.Config`, padahal berkas ini tidak pernah mengisi
        -- global itu -- satu-satunya tabel config di sini adalah local `Config`
        -- dari bagian MENGAMBIL KONFIGURASI DARI LUAR. Jadi syaratnya selalu
        -- nil dan loop ini tidak pernah melakukan apa pun sejak ditulis.
        -- Gagalnya diam: tidak ada error, thread tetap hidup, isinya saja yang
        -- tidak pernah jalan.
        if Config.AutoUnfavFruit and Networking then
            local function unfavContainer(container)
                if not container then return end
                for _, item in ipairs(container:GetChildren()) do
                    local isFruit = item:GetAttribute("HarvestedFruit") == true or item:GetAttribute("FruitName") ~= nil or item:GetAttribute("Weight") ~= nil
                    if isFruit and (item:GetAttribute("IsFavorite") == true or item:GetAttribute("Favorited") == true) then
                        -- Server menuntut atribut `Id` buah (UUID), BUKAN nama Tool.
                        -- InventoryController game memakai `Tool:GetAttribute("Id")`.
                        -- Terukur 2026-08-19: remote ini punya Response boolean, dan
                        -- Fire(item.Name, false) dijawab FALSE = ditolak, sedangkan
                        -- Fire(id, false) dijawab TRUE. Jadi versi lama tidak pernah
                        -- meng-unfav apa pun, dan pcall menelan kegagalannya diam-diam.
                        local id = item:GetAttribute("Id")
                        if id then
                            pcall(function()
                                Networking.Backpack.SetFruitFavorite:Fire(id, false)
                            end)
                            task.wait(0.2)
                        end
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

print(">> KAITUN MAIN EXECUTED SUCCESSFULLY <<")
-- =========================================================================



-- =========================================================================
-- AUTO TAME PET BACKGROUND LOOP
-- =========================================================================
-- Dijalankan terpisah dari siklus utama: satu attempt per 8 detik.
-- Tidak pakai phase system karena kaitun_main punya struktur task.spawn
-- per fitur, bukan fase berurutan.
task.spawn(function()
    task.wait(20) -- tunggu sync pertama + load dunia
    while true do
        -- Kriteria ukuran/Rainbow berdiri sendiri. Kalau hanya itu yang diisi
        -- (misal "ambil apa pun yang Huge"), TamePets memang kosong -- gerbang
        -- lama yang cuma mengecek #TamePets akan mematikan fiturnya diam-diam.
        local adaKriteria = #(Config.TamePets or {}) > 0
            or (type(Config.TameSizes) == "table" and next(Config.TameSizes) ~= nil)
            or Config.TameRainbow == true
        if Config.AutoTame and adaKriteria then
            pcall(tameSatu)
        end
        task.wait(8)
    end
end)

-- =========================================================================
-- AUTO AUCTION (World 1 / GaG2)
-- =========================================================================
-- Auto auction versi lama membaca harga dari TEKS TOMBOL di UI Auction. Dua
-- alasan kenapa itu tidak akan pernah benar, keduanya terbaca langsung di
-- AuctioneerController milik game:
--
--   1. Angka di tombol adalah ANIMASI. Tiap frame dia di-ease ke harga asli
--      (`v116 + (v110-v116) * (1-exp(-dt*6))`) lalu dibulatkan lewat
--      NumberUtils.Abbreviate ("121.2B"). Jadi yang terbaca sengaja tertinggal
--      dari harga sebenarnya, lalu kehilangan presisi lagi saat disingkat.
--
--   2. Lot Robux-only punya startPrice KECIL -- terukur 749..1499 untuk barang
--      yang harga shecklesnya milyaran. Parser lama membacanya sebagai "949
--      sheckles", jauh di bawah batas mana pun, lalu memborong. Ini penyebab
--      paling mungkin saldo habis.
--
-- Versi ini tidak menyentuh UI sama sekali. Harga dihitung dengan rumus
-- resmi milik game (SharedModules.Auctioneer.CurrentPrice) di atas data lot
-- yang dikirim server, jadi angkanya bilangan bulat yang sama persis dengan
-- yang dipakai server saat memotong saldo.
--
-- Semua deklarasi sengaja DI DALAM closure ini, bukan di scope berkas: chunk
-- utama kaitun_main sudah dekat batas 200 local per fungsi milik Luau.
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local LocalPlayer = game:GetService("Players").LocalPlayer

    local Networking, Auctioneer
    local siap = pcall(function()
        local SM = RS:WaitForChild("SharedModules", 30)
        Networking = require(SM:WaitForChild("Networking", 30))
        Auctioneer = require(SM:WaitForChild("Auctioneer", 30))
    end)
    if not siap or not Networking or not Auctioneer or not Networking.Auctioneer then
        _G.KaitunAuctionDebug = "[MATI] modul Auctioneer tidak ada di server ini"
        return
    end

    -- Cache snapshot. `lots` array of lot, `stock` peta [lotId] = sisa nyata.
    local lots, stock = {}, {}
    local gagalBeruntun = {}   -- [lotId] = berapa kali server menolak berturut-turut
    local pesanTolak = {}      -- [lotId] = alasan penolakan terakhir, untuk debug
    local hargaTerakhir = {}   -- [lotId] = harga tembakan terakhir, untuk hitung belanja
    local totalBeli, totalSukses, totalBelanja = 0, 0, 0

    -- ---------------------------------------------------------------------
    -- BOOTSTRAP SNAPSHOT PERTAMA
    -- ---------------------------------------------------------------------
    -- Server hanya MENDORONG snapshot saat restock, dan restocknya tiap 1800
    -- detik (terukur dari rollIntervalSeconds). RequestSnapshot:Fire() dijawab
    -- nil -- sudah diuji di thread identity 2 dan 8, dua-duanya nil, dan
    -- AuctioneerController sendiri memperlakukan nil sebagai wajar.
    --
    -- Tanpa bootstrap, script yang baru dijalankan diam sampai gelombang
    -- berikutnya: sampai 30 menit tanpa membeli apa pun padahal lot yang cocok
    -- sedang tayang. AuctioneerController sudah memegang snapshot terakhir di
    -- upvalue handler Snapshot-nya, jadi kita pinjam sekali di awal.
    --
    -- Dijalankan SEBELUM listener kita sendiri terpasang. Kalau dibalik, kita
    -- bisa menemukan tabel kosong milik kita sendiri di rantai signal yang sama.
    local function bootstrapDariController()
        local getups = (debug and debug.getupvalues) or getupvalues
        if not getups then return false end

        local node = Networking.Auctioneer.Snapshot.OnClientEvent
        for _ = 1, 12 do
            if type(node) ~= "table" then return false end
            local fn = rawget(node, "Function")
            if type(fn) == "function" then
                local ups = getups(fn)
                local calonLot, calonStock
                for _, v in pairs(ups) do
                    if type(v) == "table" then
                        if type(v[1]) == "table" and v[1].lotId ~= nil then
                            calonLot = v
                        else
                            for k2, v2 in pairs(v) do
                                if type(k2) == "string" and string.sub(k2, 1, 8) == "auction:" and type(v2) == "number" then
                                    calonStock = v
                                    break
                                end
                            end
                        end
                    end
                end
                if calonLot then
                    lots = calonLot
                    if calonStock then stock = calonStock end
                    return true
                end
            end
            node = rawget(node, "Next")
        end
        return false
    end
    pcall(bootstrapDariController)

    -- ---------------------------------------------------------------------
    -- LISTENER SENDIRI (tidak menumpang state controller setelah ini)
    -- ---------------------------------------------------------------------
    pcall(function()
        Networking.Auctioneer.Snapshot.OnClientEvent:Connect(function(snap)
            if type(snap) ~= "table" then return end
            local baru = {}
            if type(snap.manifest) == "table" and type(snap.manifest.lots) == "table" then
                for _, l in pairs(snap.manifest.lots) do
                    if type(l) == "table" and type(l.lotId) == "string" then
                        baru[#baru + 1] = l
                    end
                end
            end
            lots = baru
            if type(snap.stock) == "table" then stock = snap.stock end
            -- Gelombang baru: lot lama sudah tidak ada, hitungan tolaknya ikut
            -- dibuang supaya lot yang sempat kehabisan stok bisa dicoba lagi.
            gagalBeruntun = {}
        end)

        Networking.Auctioneer.StockUpdate.OnClientEvent:Connect(function(p)
            if type(p) == "table" and type(p.stock) == "table" then stock = p.stock end
        end)

        Networking.Auctioneer.PurchaseResult.OnClientEvent:Connect(function(lotId, sukses, pesan)
            if type(lotId) ~= "string" then return end
            if sukses then
                gagalBeruntun[lotId] = 0
                -- Belanja dihitung DI SINI, bukan saat menembak. Terukur
                -- 2026-08-19: dari 24 tembakan cuma 3 yang jadi -- server punya
                -- cooldown sendiri dan menolak sisanya ("cooldown"), sebagian
                -- lagi tidak dijawab sama sekali. Menghitung per tembakan
                -- melaporkan 13,1 juta padahal saldo cuma turun 1,67 juta.
                -- Angka yang mengada-ada di penghitung belanja justru berbahaya
                -- untuk fitur yang gunanya menjaga saldo.
                totalSukses = totalSukses + 1
                totalBelanja = totalBelanja + (hargaTerakhir[lotId] or 0)
            else
                gagalBeruntun[lotId] = (gagalBeruntun[lotId] or 0) + 1
                pesanTolak[lotId] = tostring(pesan)
            end
        end)
    end)

    -- ---------------------------------------------------------------------
    local function normalisasiNama(s)
        return (string.gsub(string.lower(tostring(s or "")), "[^%a%d]", ""))
    end

    -- Panel W1 mengirim dictionary {nama = true}; bentuk array tetap diterima
    -- supaya config lama/manual tidak diam-diam jadi "tidak ada yang dipilih".
    local function itemTerpilih()
        local set = {}
        local src = Config.AuctionItems
        if type(src) ~= "table" then return set end
        if #src > 0 then
            for _, nama in ipairs(src) do set[normalisasiNama(nama)] = true end
        else
            for nama, aktif in pairs(src) do
                if aktif then set[normalisasiNama(nama)] = true end
            end
        end
        return set
    end

    -- nil = TIDAK TAHU saldo. Pemanggilnya wajib membaca nil sebagai "jangan
    -- beli", bukan sebagai nol: menebak di sini persis yang bikin saldo habis.
    local function saldoSheckles()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        local s = ls and ls:FindFirstChild("Sheckles")
        if s and type(s.Value) == "number" then return s.Value end
        return nil
    end

    -- ---------------------------------------------------------------------
    local function putaran()
        local terpilih = itemTerpilih()
        if not next(terpilih) then return end

        -- Batas kosong/0 berarti TIDAK BELI, bukan "tanpa batas". Auto buy lain
        -- di script ini memakai 0 = bebas, tapi di sini arah gagalnya harus
        -- terbalik: config yang belum diisi tidak boleh berarti borong bebas.
        local maxBid = parsePrice(Config.AuctionMaxBid or "0")
        if maxBid <= 0 then return end

        local minSaldo = parsePrice(Config.AuctionMinSaldo or "0")

        for _, lot in ipairs(lots) do
            if type(lot) == "table" and type(lot.lotId) == "string" then
                -- Predikat ini disalin dari AuctioneerController baris 371-386:
                -- lot ber-robuxPrice yang BUKAN dualCurrency dibayar Robux, dan
                -- tombol shecklesnya diganti jadi tombol Robux. Game sendiri
                -- tidak pernah menembak PurchaseLot ke lot semacam itu.
                local bisaSheckles = (lot.robuxPrice == nil) or (lot.dualCurrency == true)
                local cocok = terpilih[normalisasiNama(lot.item)]
                    or terpilih[normalisasiNama(lot.displayName)]

                if bisaSheckles and cocok and (gagalBeruntun[lot.lotId] or 0) < 5 then
                    -- Spam beli: server memakai token per pembelian, jadi satu
                    -- Fire = satu unit. Batas 40 per putaran cuma supaya satu lot
                    -- tidak memonopoli loop -- putaran berikutnya lanjut lagi.
                    for _ = 1, 40 do
                        local now = workspace:GetServerTimeNow()
                        local sisa = stock[lot.lotId]
                        if not Auctioneer.IsActive(lot, now, sisa) then break end

                        -- Dihitung ULANG tiap tembakan: decrementIntervalSeconds
                        -- lot sheckles terukur 1 detik, jadi harga yang dipakai
                        -- di awal loop sudah basi beberapa tembakan kemudian.
                        local harga = Auctioneer.CurrentPrice(lot, now)
                        if type(harga) ~= "number" or harga ~= harga or harga > maxBid then break end

                        local saldo = saldoSheckles()
                        if saldo == nil then break end
                        if saldo - harga < minSaldo then break end

                        hargaTerakhir[lot.lotId] = harga
                        Networking.Auctioneer.PurchaseLot:Fire(lot.lotId, harga)
                        totalBeli = totalBeli + 1

                        if (gagalBeruntun[lot.lotId] or 0) >= 5 then break end
                        task.wait(0.08)
                    end
                end
            end
        end
    end

    _G.KaitunAuctionDebug = string.format("[SIAP] %d lot di cache", #lots)
    print(string.format(">> AUTO AUCTION SIAP | %d lot di cache | default MATI <<", #lots))

    while true do
        task.wait(1)
        if Config.AutoAuction == true then
            local ok, err = pcall(putaran)
            _G.KaitunAuctionDebug = string.format(
                "[%s] %s | lot=%d tembak=%d berhasil=%d belanja=%d",
                os.date("%H:%M:%S"), ok and "ON" or ("ERR " .. tostring(err)),
                #lots, totalBeli, totalSukses, math.floor(totalBelanja)
            )
        end
    end
end)
-- =========================================================================
-- @MOZEFRAME-EOF@ (penanda akhir berkas -- router menolak file tanpa baris ini)
