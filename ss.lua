-- Taruh di paling atas script manapun
local TeleLogger = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bbimzz7/log/refs/heads/main/tele_logger.lua"
))()

TeleLogger.Send("VertictHub - sambung Kata")

-- paling atas
local Blacklist = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bbimzz7/log/refs/heads/main/blacklist.lua"
))()
Blacklist.Check()

-- WindUI
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title  = "VertictHub - Sambung Kata",
    Author = "@Bimz19",
    Icon   = "zap",
    Transparent = true,
    Acrylic = true,
})

local AutoPlayTab  = Window:Tab({ Title = "Auto Play", Icon = "play" })
local DatabaseTab  = Window:Tab({ Title = "Database", Icon = "database" })
local ServerTab    = Window:Tab({ Title = "Server",   Icon = "server" })
local VisualTab    = Window:Tab({ Title = "Visual",   Icon = "monitor" })
local PlayerTab    = Window:Tab({ Title = "Player",   Icon = "user" })
local SettingsTab  = Window:Tab({ Title = "Settings", Icon = "settings" })

--------------------------------------------------
-- GUI
--------------------------------------------------

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer.PlayerGui
local HttpService  = game:GetService("HttpService")

local WordGui =
    PlayerGui.MatchUI.BottomUI.TopUI.WordServerFrame.WordServer

local Keyboard =
    PlayerGui.MatchUI.BottomUI.Keyboard

--------------------------------------------------
-- remotes
--------------------------------------------------

local Remotes =
    game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

local Update    = Remotes:WaitForChild("BillboardUpdate")
local Submit    = Remotes:WaitForChild("SubmitWord")
local TypeSound = Remotes:WaitForChild("TypeSound")

--------------------------------------------------
-- load KBBI (Mode Mix)
--------------------------------------------------

local KBBI = {}
pcall(function()
    local raw = game:HttpGet(
        "https://raw.githubusercontent.com/Nejasss/KBBI/refs/heads/main/Dump_Unknown_07-00-44.txt"
    )
    KBBI = loadstring(raw)()
end)

local function countKBBI()
    local total = 0
    for _, list in pairs(KBBI) do
        total += #list
    end
    return total
end

local TotalKBBIWords = countKBBI()

--------------------------------------------------
-- load Database Umum (Mode Umum + kategori)
--------------------------------------------------

local UmumDB
local UmumDBLoaded = false

local okUmum, errUmum = pcall(function()
    local rawUmum = game:HttpGet(
        "https://raw.githubusercontent.com/bbimzz7/log/refs/heads/main/Dump_Unknown_03-58-25.txt"
    )
    UmumDB = loadstring(rawUmum)()
    UmumDBLoaded = UmumDB ~= nil and UmumDB.words ~= nil
end)

if not okUmum or not UmumDBLoaded then
    -- Fallback kosong supaya script tidak crash
    UmumDB = {
        categories = {"Semua"},
        words      = {}
    }
    warn("[VertictHub] Gagal load database Umum: " .. tostring(errUmum))
end

-- Bangun index per huruf awal untuk pencarian cepat
-- UmumIndex["a"] = { {word="aku", cat="Umum"}, ... }
local UmumIndex = {}

for word, cat in pairs(UmumDB.words) do
    local firstLetter = word:sub(1, 1)
    if not UmumIndex[firstLetter] then
        UmumIndex[firstLetter] = {}
    end
    table.insert(UmumIndex[firstLetter], { word = word, cat = cat })
end

local function countUmumWords(filterCat)
    local total = 0
    if not filterCat or filterCat == "Semua" then
        for _ in pairs(UmumDB.words) do total += 1 end
    else
        for _, cat in pairs(UmumDB.words) do
            if cat == filterCat then total += 1 end
        end
    end
    return total
end

--------------------------------------------------
-- Word Mode & settings
--------------------------------------------------

-- "Mix"  = pakai KBBI
-- "Umum" = pakai UmumDB + filter kategori
local WordMode       = "Mix"
local UmumKategori   = "Semua"
local FallbackActive = false   -- true saat mode Umum sedang fallback ke Mix

local UsedWords = {}

--------------------------------------------------
-- settings
--------------------------------------------------

local Auto          = true
local AutoRetry     = true
local AntiDuplicate = true

local TargetEnding        = ""
local TargetEndingEnabled = false

local MinTypingDelay = 0.18
local MaxTypingDelay = 0.38

local ThinkDelay  = 1.4
local SubmitDelay = 0.45
local TypoDelay   = 0.9
local TypoChance  = 15

--------------------------------------------------
-- stats
--------------------------------------------------

local StatWordsSuccess  = 0
local StatWordsRejected = 0
local StatWordsTotal    = 0
local StatLastWord      = "-"

local ParaSuccess, ParaRejected, ParaTotal, ParaLastWord
local ParaEndingList, ParaKBBITotal, ParaImportedCount
local ParaUmumTotal, ParaUmumMode

local ImportedWords = {}
local ImportedCount = 0

local function updateStats()
    if ParaSuccess  then ParaSuccess:SetDesc("Kata berhasil dikirim: "  .. StatWordsSuccess)  end
    if ParaRejected then ParaRejected:SetDesc("Kata ditolak: "          .. StatWordsRejected) end
    if ParaTotal    then ParaTotal:SetDesc("Total percobaan: "          .. StatWordsTotal)    end
    if ParaLastWord then ParaLastWord:SetDesc("Kata terakhir: "         .. StatLastWord)      end
end

local function updateUmumModeInfo()
    if ParaUmumMode then
        if WordMode == "Umum" then
            if FallbackActive then
                local cat = UmumKategori == "Semua" and "Semua Kategori" or UmumKategori
                ParaUmumMode:SetDesc("Mode aktif: Umum → Fallback Mix | Kategori: " .. cat)
            else
                local cat = UmumKategori == "Semua" and "Semua Kategori" or UmumKategori
                ParaUmumMode:SetDesc("Mode aktif: Umum | Kategori: " .. cat)
            end
        else
            FallbackActive = false
            ParaUmumMode:SetDesc("Mode aktif: Mix (KBBI)")
        end
    end
end

local function updateEndingList()
    if not ParaEndingList then return end
    if WordMode ~= "Mix" then
        ParaEndingList:SetDesc("Custom akhiran hanya tersedia di mode Mix.")
        return
    end
    if not TargetEndingEnabled or TargetEnding == "" then
        ParaEndingList:SetDesc("Custom akhiran tidak aktif.")
        return
    end

    local found = {}
    local prefix = WordGui.ContentText:lower()
    local firstLetter = prefix:sub(1, 1)
    local list = firstLetter ~= "" and KBBI[firstLetter] or nil

    if list then
        for _, w in ipairs(list) do
            if #w >= #TargetEnding and w:sub(-#TargetEnding) == TargetEnding then
                if not (AntiDuplicate and UsedWords[w]) then
                    table.insert(found, w)
                    if #found >= 30 then break end
                end
            end
        end
    end

    if #found == 0 then
        ParaEndingList:SetDesc("Tidak ada kata berakhiran \"" .. TargetEnding .. "\" yang tersedia.")
    else
        ParaEndingList:SetDesc(
            "Akhiran \"" .. TargetEnding .. "\" — " .. #found .. " kata tersedia:\n"
            .. table.concat(found, ", ")
        )
    end
end

local function resetDatabase()
    UsedWords         = {}
    StatWordsSuccess  = 0
    StatWordsRejected = 0
    StatWordsTotal    = 0
    StatLastWord      = "-"
    FallbackActive    = false
    updateStats()
    updateEndingList()
    updateUmumModeInfo()
    WindUI:Notify({
        Title    = "Database Direset",
        Content  = "Semua data & kata terpakai dihapus.",
        Duration = 3,
    })
end

--------------------------------------------------
-- preset modes
--------------------------------------------------

local InputMinTyping, InputMaxTyping
local InputThink, InputSubmit
local InputTypoDelay, InputTypoChance

local PlayModes = {
    ["Slow"] = {
        MinTypingDelay = 0.35,
        MaxTypingDelay = 0.55,
        ThinkDelay     = 1.8,
        SubmitDelay    = 0.85,
        TypoChance     = 20,
        TypoDelay      = 1.0,
    },
    ["Human"] = {
        MinTypingDelay = 0.18,
        MaxTypingDelay = 0.38,
        ThinkDelay     = 1.4,
        SubmitDelay    = 0.45,
        TypoChance     = 15,
        TypoDelay      = 0.9,
    },
    ["Fast"] = {
        MinTypingDelay = 0.15,
        MaxTypingDelay = 0.19,
        ThinkDelay     = 1.0,
        SubmitDelay    = 0.8,
        TypoChance     = 20,
        TypoDelay      = 0.75,
    },
    ["Super Fast"] = {
        MinTypingDelay = 0.1,
        MaxTypingDelay = 0.5,
        ThinkDelay     = 0.6,
        SubmitDelay    = 0.4,
        TypoChance     = 20,
        TypoDelay      = 0.6,
    },
}

local function applyMode(modeName)
    local preset = PlayModes[modeName]
    if not preset then return end

    MinTypingDelay = preset.MinTypingDelay
    MaxTypingDelay = preset.MaxTypingDelay
    ThinkDelay     = preset.ThinkDelay
    SubmitDelay    = preset.SubmitDelay
    TypoChance     = preset.TypoChance
    TypoDelay      = preset.TypoDelay

    if InputMinTyping  then InputMinTyping:Set(preset.MinTypingDelay)  end
    if InputMaxTyping  then InputMaxTyping:Set(preset.MaxTypingDelay)  end
    if InputThink      then InputThink:Set(preset.ThinkDelay)          end
    if InputSubmit     then InputSubmit:Set(preset.SubmitDelay)        end
    if InputTypoDelay  then InputTypoDelay:Set(preset.TypoDelay)       end
    if InputTypoChance then InputTypoChance:Set(preset.TypoChance)     end
end

local Typing     = false
local LastPrefix = ""

--------------------------------------------------
-- UI  ·  AUTO PLAY TAB
--------------------------------------------------

AutoPlayTab:Section({ Title = "Bot Control" })

AutoPlayTab:Toggle({
    Title = "Auto Play",
    Desc  = "Bot otomatis mencari & mengetik kata",
    Value = true,
    Callback = function(v) Auto = v end,
})

AutoPlayTab:Dropdown({
    Title  = "Play Mode",
    Desc   = "Preset kecepatan bot",
    Values = {"Slow", "Human", "Fast", "Super Fast"},
    Value  = "Human",
    Callback = function(v) applyMode(v) end,
})

AutoPlayTab:Toggle({
    Title = "Auto Retry Word",
    Desc  = "Coba kata lain jika kata ditolak",
    Value = true,
    Callback = function(v) AutoRetry = v end,
})

AutoPlayTab:Toggle({
    Title = "Anti Duplicate Word",
    Desc  = "Hindari penggunaan kata yang sama",
    Value = true,
    Callback = function(v) AntiDuplicate = v end,
})

--------------------------------------------------
-- WORD MODE SECTION
--------------------------------------------------

AutoPlayTab:Section({ Title = "Word Mode" })

AutoPlayTab:Paragraph({
    Title = "Info Word Mode",
    Desc  = "Mix = pakai database KBBI besar.\nUmum = pakai database kata umum dengan filter kategori (Benda, Hewan, dll).\nJika kata Umum habis, bot otomatis fallback ke Mix lalu kembali lagi.",
})

-- Dropdown Filter Kategori (relevan saat mode Umum)
local DropdownKategori = AutoPlayTab:Dropdown({
    Title  = "Filter Kategori",
    Desc   = "Pilih kategori kata (hanya untuk mode Umum)",
    Values = UmumDB.categories,
    Value  = "Semua",
    Callback = function(v)
        UmumKategori = v
        updateUmumModeInfo()
        if ParaUmumTotal then
            ParaUmumTotal:SetDesc("Kata Umum tersedia (" .. v .. "): " .. countUmumWords(v) .. " kata")
        end
        WindUI:Notify({
            Title    = "Kategori Diubah",
            Content  = "Filter kategori: " .. v,
            Duration = 2,
        })
    end,
})

AutoPlayTab:Dropdown({
    Title  = "Word Mode",
    Desc   = "Pilih sumber database kata yang digunakan bot",
    Values = {"Mix", "Umum"},
    Value  = "Mix",
    Callback = function(v)
        WordMode = v
        updateEndingList()
        updateUmumModeInfo()
        if v == "Umum" then
            WindUI:Notify({
                Title    = "Mode: Umum",
                Content  = "Bot pakai database kata umum.\nGunakan Filter Kategori untuk menyaring kata.\nAuto fallback ke Mix jika kata habis.",
                Duration = 4,
            })
        else
            WindUI:Notify({
                Title    = "Mode: Mix",
                Content  = "Bot pakai database KBBI lengkap.",
                Duration = 3,
            })
        end
    end,
})

--------------------------------------------------
-- CUSTOM AKHIRAN (Mix only)
--------------------------------------------------

AutoPlayTab:Section({ Title = "Custom Akhiran" })

AutoPlayTab:Toggle({
    Title = "Aktifkan Custom Akhiran",
    Desc  = "Prioritaskan kata yang berakhiran tertentu (Mode Mix saja)",
    Value = false,
    Callback = function(v)
        TargetEndingEnabled = v
        updateEndingList()
    end,
})

AutoPlayTab:Input({
    Title       = "Target Akhiran",
    Desc        = "Contoh: nga, kan, an, in, nya",
    Placeholder = "nga",
    Value       = "",
    Callback    = function(v)
        TargetEnding = v:lower():gsub("%s+", "")
        updateEndingList()
    end,
})

--------------------------------------------------
-- UI  ·  SETTINGS (expandable section)
--------------------------------------------------

local SettingsDropdown = AutoPlayTab:Section({
    Title      = "Settings",
    Expandable = true,
    Expanded   = false,
})

SettingsDropdown:Section({ Title = "Typing Speed" })

InputMinTyping = SettingsDropdown:Slider({
    Title = "Min Typing Delay",
    Value = { Min = 0.01, Max = 1, Default = 0.18 },
    Step  = 0.01,
    Callback = function(v) MinTypingDelay = v end,
})

InputMaxTyping = SettingsDropdown:Slider({
    Title = "Max Typing Delay",
    Value = { Min = 0.01, Max = 1, Default = 0.38 },
    Step  = 0.01,
    Callback = function(v) MaxTypingDelay = v end,
})

SettingsDropdown:Section({ Title = "Bot Timing" })

InputThink = SettingsDropdown:Slider({
    Title = "Think Delay",
    Value = { Min = 0, Max = 3, Default = 1.4 },
    Step  = 0.05,
    Callback = function(v) ThinkDelay = v end,
})

InputSubmit = SettingsDropdown:Slider({
    Title = "Submit Delay",
    Value = { Min = 0, Max = 3, Default = 0.45 },
    Step  = 0.05,
    Callback = function(v) SubmitDelay = v end,
})

SettingsDropdown:Section({ Title = "Typo Simulation" })

InputTypoDelay = SettingsDropdown:Slider({
    Title = "Typo Delay",
    Value = { Min = 0, Max = 3, Default = 0.9 },
    Step  = 0.05,
    Callback = function(v) TypoDelay = v end,
})

InputTypoChance = SettingsDropdown:Slider({
    Title = "Typo Chance (%)",
    Value = { Min = 0, Max = 50, Default = 15 },
    Step  = 1,
    Callback = function(v) TypoChance = v end,
})

--------------------------------------------------
-- UI  ·  DATABASE TAB
--------------------------------------------------

DatabaseTab:Section({ Title = "Stats" })

ParaSuccess = DatabaseTab:Paragraph({
    Title = "Kata Berhasil",
    Desc  = "Kata berhasil dikirim: 0",
})

ParaRejected = DatabaseTab:Paragraph({
    Title = "Kata Ditolak",
    Desc  = "Kata ditolak: 0",
})

ParaTotal = DatabaseTab:Paragraph({
    Title = "Total Percobaan",
    Desc  = "Total percobaan: 0",
})

ParaLastWord = DatabaseTab:Paragraph({
    Title = "Kata Terakhir",
    Desc  = "Kata terakhir: -",
})

-- ── Info Database ──────────────────────────────

DatabaseTab:Section({ Title = "Info Database" })

ParaUmumMode = DatabaseTab:Paragraph({
    Title = "Mode Aktif",
    Desc  = "Mode aktif: Mix (KBBI)",
})

ParaKBBITotal = DatabaseTab:Paragraph({
    Title = "Total Kata KBBI (Mix)",
    Desc  = "Total kata KBBI ter-load: " .. TotalKBBIWords .. " kata",
})

ParaUmumTotal = DatabaseTab:Paragraph({
    Title = "Total Kata Umum",
    Desc  = "Kata Umum tersedia (Semua): " .. countUmumWords("Semua") .. " kata",
})

ParaImportedCount = DatabaseTab:Paragraph({
    Title = "Kata Import",
    Desc  = "Kata custom ter-import: 0 kata",
})

-- ── Import Kata ────────────────────────────────

DatabaseTab:Section({ Title = "Import Kata Custom" })

DatabaseTab:Paragraph({
    Title = "Cara Import",
    Desc  = "Masukkan daftar kata dipisahkan koma atau baris baru. Contoh: kucing, anjing, burung\nKata import akan digunakan bot bersama database KBBI (mode Mix).",
})

local ImportedRawText = ""

DatabaseTab:Input({
    Title       = "Daftar Kata",
    Desc        = "Pisahkan kata dengan koma ( , ) atau baris baru",
    Placeholder = "kucing, anjing, burung",
    Value       = "",
    Callback    = function(v)
        ImportedRawText = v
    end,
})

DatabaseTab:Button({
    Title    = "Import Kata",
    Desc     = "Proses & simpan kata custom ke database",
    Callback = function()
        ImportedWords = {}
        ImportedCount = 0

        local raw2 = ImportedRawText:gsub("\n", ",")
        for word in raw2:gmatch("[^,]+") do
            local clean = word:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if clean ~= "" then
                local firstLetter = clean:sub(1, 1)
                if not KBBI[firstLetter] then
                    KBBI[firstLetter] = {}
                end

                local exists = false
                for _, w in ipairs(KBBI[firstLetter]) do
                    if w == clean then exists = true break end
                end

                if not exists then
                    table.insert(KBBI[firstLetter], clean)
                    ImportedWords[clean] = true
                    ImportedCount += 1
                end
            end
        end

        TotalKBBIWords = countKBBI()
        if ParaKBBITotal then
            ParaKBBITotal:SetDesc("Total kata KBBI ter-load: " .. TotalKBBIWords .. " kata")
        end
        if ParaImportedCount then
            ParaImportedCount:SetDesc("Kata custom ter-import: " .. ImportedCount .. " kata")
        end

        WindUI:Notify({
            Title    = "Import Berhasil",
            Content  = ImportedCount .. " kata baru berhasil ditambahkan ke database.",
            Duration = 3,
        })
    end,
})

DatabaseTab:Button({
    Title    = "Hapus Kata Import",
    Desc     = "Hapus semua kata yang pernah di-import",
    Callback = function()
        for word, _ in pairs(ImportedWords) do
            local firstLetter = word:sub(1, 1)
            if KBBI[firstLetter] then
                for i = #KBBI[firstLetter], 1, -1 do
                    if KBBI[firstLetter][i] == word then
                        table.remove(KBBI[firstLetter], i)
                        break
                    end
                end
            end
        end

        ImportedWords   = {}
        ImportedCount   = 0
        ImportedRawText = ""

        TotalKBBIWords = countKBBI()
        if ParaKBBITotal then
            ParaKBBITotal:SetDesc("Total kata KBBI ter-load: " .. TotalKBBIWords .. " kata")
        end
        if ParaImportedCount then
            ParaImportedCount:SetDesc("Kata custom ter-import: 0 kata")
        end

        WindUI:Notify({
            Title    = "Import Dihapus",
            Content  = "Semua kata import telah dihapus dari database.",
            Duration = 3,
        })
    end,
})

-- ── Ending List ────────────────────────────────

DatabaseTab:Section({ Title = "Kata Akhiran Tersedia" })

ParaEndingList = DatabaseTab:Paragraph({
    Title = "Daftar Kata",
    Desc  = "Custom akhiran tidak aktif.",
})

DatabaseTab:Button({
    Title    = "Refresh Daftar",
    Desc     = "Update daftar kata berakhiran target",
    Callback = function()
        updateEndingList()
    end,
})

DatabaseTab:Section({ Title = "Reset Database" })

DatabaseTab:Paragraph({
    Title = "Peringatan",
    Desc  = "Reset akan menghapus semua kata terpakai & statistik ronde ini.",
})

DatabaseTab:Button({
    Title    = "Reset Database",
    Desc     = "Hapus semua data & mulai ulang",
    Callback = function()
        resetDatabase()
    end,
})

--------------------------------------------------
-- UI  ·  SERVER TAB
--------------------------------------------------

local TeleportService = game:GetService("TeleportService")
local RunService      = game:GetService("RunService")

local ParaJobId, ParaPlayers, ParaServerAge, ParaPing

local function getServerAge()
    local seconds = math.floor(workspace.DistributedGameTime)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d menit %d detik", m, s)
end

local function getPing()
    return math.floor(LocalPlayer:GetNetworkPing() * 1000) .. " ms"
end

local function getPlayerCount()
    return #Players:GetPlayers() .. "/" .. Players.MaxPlayers
end

local function refreshServerInfo()
    if ParaJobId     then ParaJobId:SetDesc("Job ID: "        .. game.JobId)        end
    if ParaPlayers   then ParaPlayers:SetDesc("Pemain: "      .. getPlayerCount())   end
    if ParaServerAge then ParaServerAge:SetDesc("Umur Server: " .. getServerAge())   end
    if ParaPing      then ParaPing:SetDesc("Ping: "           .. getPing())           end
end

ServerTab:Section({ Title = "Server Info" })

ParaJobId = ServerTab:Paragraph({
    Title = "Job ID",
    Desc  = "Job ID: " .. game.JobId,
})

ParaPlayers = ServerTab:Paragraph({
    Title = "Pemain",
    Desc  = "Pemain: " .. getPlayerCount(),
})

ParaServerAge = ServerTab:Paragraph({
    Title = "Umur Server",
    Desc  = "Umur Server: " .. getServerAge(),
})

ParaPing = ServerTab:Paragraph({
    Title = "Ping",
    Desc  = "Ping: " .. getPing(),
})

ServerTab:Button({
    Title    = "Refresh Info",
    Desc     = "Perbarui informasi server",
    Callback = function()
        refreshServerInfo()
        WindUI:Notify({
            Title    = "Server Info",
            Content  = "Info server diperbarui.",
            Duration = 2,
        })
    end,
})

task.spawn(function()
    while task.wait(5) do
        refreshServerInfo()
    end
end)

-- ── Server Hop ─────────────────────────────────

ServerTab:Section({ Title = "Server Hop" })

ServerTab:Paragraph({
    Title = "Info",
    Desc  = "Server Hop akan memindahkanmu ke server lain secara otomatis. Gunakan dengan bijak.",
})

local HopDelay = 3

ServerTab:Slider({
    Title = "Delay Hop (detik)",
    Desc  = "Jeda sebelum berpindah server",
    Value = { Min = 1, Max = 10, Default = 3 },
    Step  = 1,
    Callback = function(v)
        HopDelay = v
    end,
})

ServerTab:Button({
    Title    = "Server Hop",
    Desc     = "Pindah ke server lain",
    Callback = function()
        WindUI:Notify({
            Title    = "Server Hop",
            Content  = "Mencari server lain... harap tunggu " .. HopDelay .. " detik.",
            Duration = HopDelay,
        })

        task.spawn(function()
            task.wait(HopDelay)

            local placeId    = game.PlaceId
            local currentJob = game.JobId
            local servers

            local ok, result = pcall(function()
                local url = "https://games.roblox.com/v1/games/"
                    .. placeId
                    .. "/servers/Public?sortOrder=Asc&limit=100"
                local res = game:HttpGet(url)
                return HttpService:JSONDecode(res)
            end)

            if ok and result and result.data then
                servers = result.data
            end

            if servers and #servers > 0 then
                local candidates = {}
                for _, s in ipairs(servers) do
                    if s.id ~= currentJob
                        and s.playing ~= nil
                        and s.maxPlayers ~= nil
                        and s.playing < s.maxPlayers
                    then
                        table.insert(candidates, s.id)
                    end
                end

                if #candidates > 0 then
                    local chosen = candidates[math.random(1, #candidates)]
                    TeleportService:TeleportToPlaceInstance(placeId, chosen, LocalPlayer)
                    return
                end
            end

            TeleportService:Teleport(placeId, LocalPlayer)
        end)
    end,
})

-- ── Rejoin Server ──────────────────────────────

ServerTab:Section({ Title = "Rejoin Server" })

ServerTab:Paragraph({
    Title = "Info",
    Desc  = "Rejoin akan mengembalikanmu ke server yang sama (Job ID yang sama).",
})

local SavedJobId = game.JobId

ServerTab:Button({
    Title    = "Rejoin Server",
    Desc     = "Masuk ulang ke server yang sama",
    Callback = function()
        WindUI:Notify({
            Title    = "Rejoin",
            Content  = "Bergabung ulang ke server saat ini...",
            Duration = 3,
        })

        task.spawn(function()
            task.wait(2)
            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    SavedJobId,
                    LocalPlayer
                )
            end)

            if not ok then
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
    end,
})

ServerTab:Button({
    Title    = "Simpan Job ID Saat Ini",
    Desc     = "Update Job ID tujuan rejoin ke server sekarang",
    Callback = function()
        SavedJobId = game.JobId
        if ParaJobId then
            ParaJobId:SetDesc("Job ID: " .. SavedJobId)
        end
        WindUI:Notify({
            Title    = "Job ID Disimpan",
            Content  = "Job ID server ini telah disimpan untuk rejoin.",
            Duration = 3,
        })
    end,
})

--------------------------------------------------
-- UI  ·  VISUAL TAB
--------------------------------------------------

local Lighting     = game:GetService("Lighting")
local UserSettings_ = UserSettings()
local GameSettings_ = UserSettings_:GetService("UserGameSettings")

local OriginalBrightness     = Lighting.Brightness
local OriginalAmbient        = Lighting.Ambient
local OriginalOutdoorAmbient = Lighting.OutdoorAmbient
local OriginalFogEnd         = Lighting.FogEnd
local OriginalFogStart       = Lighting.FogStart
local OriginalClockTime      = Lighting.ClockTime
local OriginalShadows        = Lighting.GlobalShadows

local FPSBoostActive       = false
local RemoveFogActive      = false
local DisableShadowsActive = false
local CustomBrightActive   = false

local ToggleFPSBoost, ToggleRemoveFog, ToggleDisableShadows, ToggleCustomBright
local SliderBrightness, SliderAmbient, SliderRenderQuality

local removedEffects = {}

local function removeAllLightingEffects()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") or obj:IsA("Sky") or obj:IsA("Atmosphere")
        or obj:IsA("BloomEffect") or obj:IsA("BlurEffect")
        or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect")
        or obj:IsA("DepthOfFieldEffect") then
            table.insert(removedEffects, { instance = obj, parent = obj.Parent })
            obj.Parent = nil
        end
    end
end

local function restoreAllLightingEffects()
    for _, data in ipairs(removedEffects) do
        pcall(function() data.instance.Parent = data.parent end)
    end
    removedEffects = {}
end

local removedDecorations = {}

local function removeWorkspaceDecorations()
    local function scan(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke")
            or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("SelectionBox") then
                table.insert(removedDecorations, { instance = obj, parent = obj.Parent })
                obj.Parent = nil
            elseif obj:IsA("BasePart") and obj.Parent ~= workspace.Terrain then
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("Decal") or child:IsA("Texture") then
                        table.insert(removedDecorations, { instance = child, parent = child.Parent })
                        child.Parent = nil
                    end
                end
            end
            if obj:IsA("Model") or obj:IsA("Folder") then scan(obj) end
        end
    end
    scan(workspace)
end

local function restoreWorkspaceDecorations()
    for _, data in ipairs(removedDecorations) do
        pcall(function() data.instance.Parent = data.parent end)
    end
    removedDecorations = {}
end

local function applyFPSBoost(enabled)
    if enabled then
        removeAllLightingEffects()
        Lighting.FogEnd        = 1000000
        Lighting.FogStart      = 999999
        Lighting.GlobalShadows = false
        removeWorkspaceDecorations()
    else
        restoreAllLightingEffects()
        Lighting.FogEnd        = OriginalFogEnd
        Lighting.FogStart      = OriginalFogStart
        Lighting.GlobalShadows = OriginalShadows
        restoreWorkspaceDecorations()
    end
end

-- ── Section FPS Boost ──────────────────────────

VisualTab:Section({ Title = "FPS Boost" })

VisualTab:Paragraph({
    Title = "Info",
    Desc  = "FPS Boost menghapus efek berat (lighting FX, partikel, fog) tanpa membuat layar jadi putih/full bright.",
})

ToggleFPSBoost = VisualTab:Toggle({
    Title = "Aktifkan FPS Boost",
    Desc  = "Hapus efek visual berat untuk meningkatkan FPS",
    Value = false,
    Callback = function(v)
        FPSBoostActive = v
        applyFPSBoost(v)
        WindUI:Notify({
            Title    = v and "FPS Boost ON" or "FPS Boost OFF",
            Content  = v and "Efek berat dihapus, FPS meningkat." or "Visual dikembalikan ke normal.",
            Duration = 3,
        })
    end,
})

-- ── Section Lighting Manual ────────────────────

VisualTab:Section({ Title = "Pengaturan Cahaya" })

ToggleRemoveFog = VisualTab:Toggle({
    Title = "Hapus Fog",
    Desc  = "Hilangkan kabut/fog dari dunia",
    Value = false,
    Callback = function(v)
        RemoveFogActive = v
        if v then
            Lighting.FogEnd   = 1000000
            Lighting.FogStart = 999999
        else
            if not FPSBoostActive then
                Lighting.FogEnd   = OriginalFogEnd
                Lighting.FogStart = OriginalFogStart
            end
        end
    end,
})

ToggleDisableShadows = VisualTab:Toggle({
    Title = "Matikan Shadow",
    Desc  = "Nonaktifkan bayangan untuk performa lebih baik",
    Value = false,
    Callback = function(v)
        DisableShadowsActive   = v
        Lighting.GlobalShadows = not v
    end,
})

ToggleCustomBright = VisualTab:Toggle({
    Title = "Custom Brightness",
    Desc  = "Atur kecerahan manual (tanpa full bright)",
    Value = false,
    Callback = function(v)
        CustomBrightActive = v
        if not v then
            Lighting.Brightness     = OriginalBrightness
            Lighting.Ambient        = OriginalAmbient
            Lighting.OutdoorAmbient = OriginalOutdoorAmbient
        end
    end,
})

SliderBrightness = VisualTab:Slider({
    Title = "Brightness",
    Desc  = "Kecerahan lingkungan (default: " .. tostring(math.floor(OriginalBrightness * 10) / 10) .. ")",
    Value = { Min = 0, Max = 5, Default = math.clamp(OriginalBrightness, 0, 5) },
    Step  = 0.1,
    Callback = function(v)
        if CustomBrightActive then
            Lighting.Brightness = v
        end
    end,
})

SliderAmbient = VisualTab:Slider({
    Title = "Ambient (RGB rata-rata)",
    Desc  = "Sesuaikan cahaya ambient (0 = gelap, 255 = terang)",
    Value = { Min = 0, Max = 255, Default = 100 },
    Step  = 5,
    Callback = function(v)
        if CustomBrightActive then
            local c = v / 255
            Lighting.Ambient        = Color3.new(c, c, c)
            Lighting.OutdoorAmbient = Color3.new(c, c, c)
        end
    end,
})

-- ── Section Render Quality ─────────────────────

VisualTab:Section({ Title = "Render Quality" })

VisualTab:Paragraph({
    Title = "Info",
    Desc  = "Mengatur kualitas render Roblox. Lebih rendah = FPS lebih tinggi. Default biasanya 10–14.",
})

SliderRenderQuality = VisualTab:Slider({
    Title = "Render Quality Level",
    Desc  = "1 = kualitas terendah (FPS tertinggi), 21 = kualitas tertinggi",
    Value = { Min = 1, Max = 21, Default = 10 },
    Step  = 1,
    Callback = function(v)
        local idx = tostring(v)
        if v < 10 then idx = "0" .. idx end
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel["Level" .. idx]
        end)
    end,
})

VisualTab:Button({
    Title    = "Reset ke Default",
    Desc     = "Kembalikan semua pengaturan Visual ke kondisi awal",
    Callback = function()
        FPSBoostActive       = false
        RemoveFogActive      = false
        DisableShadowsActive = false
        CustomBrightActive   = false

        applyFPSBoost(false)
        Lighting.Brightness     = OriginalBrightness
        Lighting.Ambient        = OriginalAmbient
        Lighting.OutdoorAmbient = OriginalOutdoorAmbient
        Lighting.FogEnd         = OriginalFogEnd
        Lighting.FogStart       = OriginalFogStart
        Lighting.GlobalShadows  = OriginalShadows

        if ToggleFPSBoost       then ToggleFPSBoost:Set(false)       end
        if ToggleRemoveFog      then ToggleRemoveFog:Set(false)      end
        if ToggleDisableShadows then ToggleDisableShadows:Set(false) end
        if ToggleCustomBright   then ToggleCustomBright:Set(false)   end

        if SliderBrightness    then SliderBrightness:Set(math.clamp(OriginalBrightness, 0, 5)) end
        if SliderAmbient       then SliderAmbient:Set(100)           end
        if SliderRenderQuality then SliderRenderQuality:Set(10)      end

        WindUI:Notify({
            Title    = "Visual Direset",
            Content  = "Semua pengaturan visual dikembalikan ke normal.",
            Duration = 3,
        })
    end,
})

--------------------------------------------------
-- UI  ·  PLAYER TAB
--------------------------------------------------

local UserInputService = game:GetService("UserInputService")

local Character  = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid   = Character:WaitForChild("Humanoid")
local RootPart   = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid  = newChar:WaitForChild("Humanoid")
    RootPart  = newChar:WaitForChild("HumanoidRootPart")
end)

-- ── Movement ───────────────────────────────────

PlayerTab:Section({ Title = "Movement" })

PlayerTab:Slider({
    Title = "Walk Speed",
    Desc  = "Kecepatan jalan karakter (default: 16)",
    Value = { Min = 1, Max = 100, Default = 16 },
    Step  = 1,
    Callback = function(v)
        if Humanoid then Humanoid.WalkSpeed = v end
    end,
})

PlayerTab:Slider({
    Title = "Jump Power",
    Desc  = "Kekuatan lompat karakter (default: 50)",
    Value = { Min = 1, Max = 200, Default = 50 },
    Step  = 1,
    Callback = function(v)
        if Humanoid then
            Humanoid.JumpPower  = v
            Humanoid.JumpHeight = v / 10
        end
    end,
})

local InfiniteJumpActive = false
local InfiniteJumpConn

PlayerTab:Toggle({
    Title = "Infinite Jump",
    Desc  = "Lompat tanpa batas di udara",
    Value = false,
    Callback = function(v)
        InfiniteJumpActive = v
        if v then
            InfiniteJumpConn = UserInputService.JumpRequest:Connect(function()
                if InfiniteJumpActive and Humanoid then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        else
            if InfiniteJumpConn then
                InfiniteJumpConn:Disconnect()
                InfiniteJumpConn = nil
            end
        end
    end,
})

local NoclipActive = false
local NoclipConn

PlayerTab:Toggle({
    Title = "Noclip",
    Desc  = "Tembus dinding & objek",
    Value = false,
    Callback = function(v)
        NoclipActive = v
        if v then
            NoclipConn = game:GetService("RunService").Stepped:Connect(function()
                if not NoclipActive then return end
                if not Character then return end
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end)
        else
            if NoclipConn then
                NoclipConn:Disconnect()
                NoclipConn = nil
            end
            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end,
})

-- ── Anti ───────────────────────────────────────

PlayerTab:Section({ Title = "Anti" })

local AntiAFKConn
local AntiAFKActive = false

PlayerTab:Toggle({
    Title = "Anti AFK",
    Desc  = "Cegah kick otomatis karena tidak aktif",
    Value = false,
    Callback = function(v)
        AntiAFKActive = v
        if v then
            local VirtualUser = game:GetService("VirtualUser")
            AntiAFKConn = LocalPlayer.Idled:Connect(function()
                if AntiAFKActive then
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(0.1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end
            end)
        else
            if AntiAFKConn then
                AntiAFKConn:Disconnect()
                AntiAFKConn = nil
            end
        end
    end,
})

local AutoRejoinActive = false

PlayerTab:Toggle({
    Title = "Auto Rejoin",
    Desc  = "Otomatis rejoin saat kena kick atau disconnect",
    Value = false,
    Callback = function(v)
        AutoRejoinActive = v
    end,
})

LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.RequestedFromServer and AutoRejoinActive then
        task.wait(3)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
end)

LocalPlayer.AncestryChanged:Connect(function(_, parent)
    if not parent and AutoRejoinActive then
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId)
        end)
    end
end)

--------------------------------------------------
-- random typing delay
--------------------------------------------------

local function getTypingDelay()
    return math.random() * (MaxTypingDelay - MinTypingDelay) + MinTypingDelay
end

--------------------------------------------------
-- CARI KATA - Mode Mix (KBBI)
--------------------------------------------------

local function getWordMix(prefix)
    prefix = prefix:lower()
    local list = KBBI[prefix:sub(1, 1)]
    if not list then return nil end

    local prioritized = {}
    local fallback    = {}

    for _, w in ipairs(list) do
        if w:sub(1, #prefix) == prefix then
            local eligible = not (AntiDuplicate and UsedWords[w])
            if eligible then
                if TargetEndingEnabled and TargetEnding ~= "" then
                    if #w >= #TargetEnding and w:sub(-#TargetEnding) == TargetEnding then
                        table.insert(prioritized, w)
                    else
                        table.insert(fallback, w)
                    end
                else
                    table.insert(fallback, w)
                end
            end
        end
    end

    if #prioritized > 0 then
        return prioritized[math.random(1, #prioritized)]
    elseif #fallback > 0 then
        return fallback[math.random(1, #fallback)]
    end
    return nil
end

--------------------------------------------------
-- CARI KATA - Mode Umum (database kategori)
--------------------------------------------------

local function getWordUmum(prefix)
    prefix = prefix:lower()
    local list = UmumIndex[prefix:sub(1, 1)]
    if not list then return nil end

    local candidates = {}

    for _, entry in ipairs(list) do
        local w   = entry.word
        local cat = entry.cat

        if w:sub(1, #prefix) == prefix then
            local catOk    = (UmumKategori == "Semua") or (cat == UmumKategori)
            local eligible = not (AntiDuplicate and UsedWords[w])
            if catOk and eligible then
                table.insert(candidates, w)
            end
        end
    end

    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    end
    return nil
end

--------------------------------------------------
-- GETWORD - dispatcher + auto fallback
-- Jika mode Umum & kata tidak ada → fallback ke Mix sementara
-- Begitu kata Umum ada lagi → otomatis balik ke Umum
--------------------------------------------------

local function getWord(prefix)
    if WordMode == "Mix" then
        return getWordMix(prefix)
    end

    -- Mode Umum: coba database Umum dulu
    local word = getWordUmum(prefix)

    if word then
        -- Kata ketemu di Umum
        if FallbackActive then
            -- Baru balik dari fallback, notify user
            FallbackActive = false
            WindUI:Notify({
                Title    = "Kembali ke Mode Umum",
                Content  = "Kata Umum ditemukan, bot kembali ke database Umum.",
                Duration = 3,
            })
            updateUmumModeInfo()
        end
        return word
    end

    -- Kata tidak ketemu di Umum → fallback ke Mix sementara
    if not FallbackActive then
        FallbackActive = true
        WindUI:Notify({
            Title    = "Fallback ke Mix",
            Content  = "Kata Umum habis/tidak ada, bot sementara pakai KBBI.\nAkan balik ke Umum otomatis.",
            Duration = 3,
        })
        if ParaUmumMode then
            ParaUmumMode:SetDesc("Mode aktif: Umum → Fallback Mix (KBBI)")
        end
    end

    return getWordMix(prefix)
end

--------------------------------------------------
-- random huruf typo
--------------------------------------------------

local alphabet = "abcdefghijklmnopqrstuvwxyz"

local function randomLetter()
    local r = math.random(1, #alphabet)
    return alphabet:sub(r, r)
end

--------------------------------------------------
-- typing
--------------------------------------------------

local function typeWord(word, prefix)
    Typing = true

    local startIndex = #prefix + 1

    for i = startIndex, #word do
        if not Keyboard.Visible then
            Typing = false
            return
        end

        local isMiddle = (i > startIndex) and (i < #word)

        if isMiddle and math.random(1, 100) <= TypoChance then
            local wrong = word:sub(1, i - 1) .. randomLetter()
            Update:FireServer(wrong)
            TypeSound:FireServer()
            task.wait(TypoDelay)

            Update:FireServer(word:sub(1, i - 1))
            TypeSound:FireServer()
            task.wait(TypoDelay)

            Update:FireServer(word:sub(1, i))
            TypeSound:FireServer()
        else
            Update:FireServer(word:sub(1, i))
            TypeSound:FireServer()
        end

        task.wait(getTypingDelay())
    end

    task.wait(SubmitDelay)
    Submit:FireServer(word)

    StatWordsTotal  += 1
    StatLastWord     = word
    UsedWords[word]  = true
    Typing           = false
end

--------------------------------------------------
-- play logic + retry
--------------------------------------------------

local function play(prefix)
    task.wait(ThinkDelay)

    local tries = 0

    while tries < 5 do
        if not Keyboard.Visible then return end

        tries += 1

        local word = getWord(prefix)
        if not word then return end

        typeWord(word, prefix)
        task.wait(0.7)

        local newPrefix = WordGui.ContentText

        if newPrefix ~= prefix then
            StatWordsSuccess += 1
            updateStats()
            return
        end

        StatWordsRejected += 1
        updateStats()

        if not AutoRetry then return end
    end
end

--------------------------------------------------
-- LOOP DETECTOR
--------------------------------------------------

task.spawn(function()
    while true do
        task.wait(0.1)
        if Auto and not Typing and Keyboard.Visible then
            local prefix = WordGui.ContentText
            if prefix ~= "" and prefix ~= LastPrefix then
                LastPrefix = prefix
                task.spawn(function()
                    play(prefix)
                end)
            end
        end
    end
end)

--------------------------------------------------
-- reset ronde
--------------------------------------------------

Keyboard:GetPropertyChangedSignal("Visible"):Connect(function()
    if Keyboard.Visible then
        LastPrefix = ""
    end
end)

--------------------------------------------------
-- UI  ·  SETTINGS TAB
--------------------------------------------------

local SCRIPT_VERSION = "v2.0.0 stable"

-- ── Info ───────────────────────────────────────

SettingsTab:Section({ Title = "Info" })

SettingsTab:Paragraph({
    Title = "VertictHub Sambung Kata",
    Desc  = "Versi: " .. SCRIPT_VERSION .. "\nDibuat oleh: Bimz\nPowered by WindUI",
})

-- ── Appearance ─────────────────────────────────

SettingsTab:Section({ Title = "Appearance" })

SettingsTab:Dropdown({
    Title  = "Theme",
    Desc   = "Pilih tema tampilan UI (Dark / Light)",
    Values = { "Dark", "Light" },
    Value  = "Dark",
    Callback = function(v)
        pcall(function() WindUI:SetTheme(v) end)
        WindUI:Notify({
            Title    = "Theme",
            Content  = "Theme diubah ke " .. v,
            Duration = 2,
        })
    end,
})

-- ── Danger Zone ────────────────────────────────

SettingsTab:Section({ Title = "Danger Zone" })

SettingsTab:Paragraph({
    Title = "Peringatan",
    Desc  = "Destroy All menghapus script sepenuhnya dari memory. Semua fitur berhenti total dan tidak bisa diaktifkan kembali tanpa execute ulang.",
})

SettingsTab:Button({
    Title    = "Destroy All",
    Desc     = "Hapus script & hentikan semua fitur sekarang",
    Callback = function()
        WindUI:Notify({
            Title    = "Destroying...",
            Content  = "Script dihapus. Semua fitur dihentikan.",
            Duration = 3,
        })

        task.wait(1)

        Auto               = false
        NoclipActive       = false
        AntiAFKActive      = false
        AutoRejoinActive   = false
        FPSBoostActive     = false
        InfiniteJumpActive = false

        if NoclipConn       then pcall(function() NoclipConn:Disconnect()       end) end
        if InfiniteJumpConn then pcall(function() InfiniteJumpConn:Disconnect() end) end
        if AntiAFKConn      then pcall(function() AntiAFKConn:Disconnect()      end) end

        pcall(function()
            applyFPSBoost(false)
            Lighting.Brightness     = OriginalBrightness
            Lighting.Ambient        = OriginalAmbient
            Lighting.OutdoorAmbient = OriginalOutdoorAmbient
            Lighting.FogEnd         = OriginalFogEnd
            Lighting.FogStart       = OriginalFogStart
            Lighting.GlobalShadows  = OriginalShadows
        end)

        pcall(function()
            if Humanoid then
                Humanoid.WalkSpeed = 16
                Humanoid.JumpPower = 50
            end
            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end)

        task.wait(2)
        pcall(function() Window:Destroy() end)
        pcall(function() WindUI:Destroy() end)
    end,
})

-- paling bawah
Blacklist.StartLoop()
