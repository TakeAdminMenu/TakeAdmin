-- Speicherung von Banns & Verwarnungen
-- MySQL (oxmysql): bleibt bei Neustarts UND Ressourcen-Updates erhalten.
-- JSON (Fallback): data/*.json - wird überschrieben, wenn man den Ordner neu kopiert!

Bans = {}
Warns = {}
Recent = {}

local useSQL = false
local ready = false

-- ---------------------------------------------------------------- Helfer

local function loadJson(file, default)
    local raw = LoadResourceFile(RESOURCE, 'data/' .. file)
    if not raw or raw == '' then return default end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    print('^1[TakeAdmin] data/' .. file .. ' ist beschädigt - wird ignoriert.^0')
    return default
end

local function saveJson(file, data)
    SaveResourceFile(RESOURCE, 'data/' .. file, json.encode(data, { indent = true }), -1)
end

local function sqlAwait(query, params)
    local p = promise.new()
    exports.oxmysql:query(query, params or {}, function(result) p:resolve(result or {}) end)
    return Citizen.Await(p)
end

local function sqlAsync(query, params)
    exports.oxmysql:query(query, params or {}, function() end)
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

local function nextBanId()
    local max = 0
    for _, b in ipairs(Bans) do if b.id > max then max = b.id end end
    return max + 1
end

-- ---------------------------------------------------------------- Speichern

local function insertBan(ban)
    if not useSQL then return saveJson('bans.json', Bans) end
    sqlAsync('INSERT INTO `takeadmin_bans` (`id`, `name`, `identifiers`, `tokens`, `reason`, `admin`, `time`, `expire`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        ban.id, ban.name, json.encode(ban.identifiers), json.encode(ban.tokens or {}), ban.reason, ban.admin, ban.time, ban.expire
    })
end

local function deleteBan(id)
    if not useSQL then return saveJson('bans.json', Bans) end
    sqlAsync('DELETE FROM `takeadmin_bans` WHERE `id` = ?', { id })
end

local function updateBanIds(ban)
    if not useSQL then return saveJson('bans.json', Bans) end
    sqlAsync('UPDATE `takeadmin_bans` SET `identifiers` = ?, `tokens` = ? WHERE `id` = ?', {
        json.encode(ban.identifiers), json.encode(ban.tokens or {}), ban.id
    })
end

-- license = welcher Spieler sich geändert hat (für MySQL)
function SaveWarns(license)
    if not useSQL then return saveJson('warns.json', Warns) end
    if not license then return end
    local list = Warns[license]
    if list and #list > 0 then
        sqlAsync('REPLACE INTO `takeadmin_warns` (`identifier`, `data`) VALUES (?, ?)', { license, json.encode(list) })
    else
        sqlAsync('DELETE FROM `takeadmin_warns` WHERE `identifier` = ?', { license })
    end
end

-- ---------------------------------------------------------------- Laden

CreateThread(function()
    local state = GetResourceState('oxmysql')
    if Config.Storage ~= 'json' and state ~= 'missing' and state ~= 'unknown' then
        local timeout = GetGameTimer() + 20000
        while GetResourceState('oxmysql') ~= 'started' and GetGameTimer() < timeout do Wait(100) end
        useSQL = GetResourceState('oxmysql') == 'started'
    end

    if Config.Storage == 'mysql' and not useSQL then
        print('^1[TakeAdmin] Config.Storage = "mysql", aber oxmysql läuft nicht! Banns werden NUR in JSON gespeichert.^0')
    end

    if useSQL then
        sqlAwait([[
            CREATE TABLE IF NOT EXISTS `takeadmin_bans` (
                `id` INT NOT NULL PRIMARY KEY,
                `name` VARCHAR(100) NOT NULL,
                `identifiers` LONGTEXT NOT NULL,
                `tokens` LONGTEXT NOT NULL,
                `reason` VARCHAR(255) NOT NULL,
                `admin` VARCHAR(100) NOT NULL,
                `time` INT NOT NULL,
                `expire` INT NOT NULL
            )
        ]])
        sqlAwait([[
            CREATE TABLE IF NOT EXISTS `takeadmin_warns` (
                `identifier` VARCHAR(100) NOT NULL PRIMARY KEY,
                `data` LONGTEXT NOT NULL
            )
        ]])

        for _, row in ipairs(sqlAwait('SELECT * FROM `takeadmin_bans`')) do
            Bans[#Bans + 1] = {
                id = row.id, name = row.name, reason = row.reason, admin = row.admin,
                time = row.time, expire = row.expire,
                identifiers = json.decode(row.identifiers) or {},
                tokens = json.decode(row.tokens) or {},
            }
        end
        table.sort(Bans, function(a, b) return a.id < b.id end)

        for _, row in ipairs(sqlAwait('SELECT * FROM `takeadmin_warns`')) do
            Warns[row.identifier] = json.decode(row.data) or {}
        end

        -- Alte JSON-Daten einmalig in die Datenbank übernehmen
        local oldBans = loadJson('bans.json', {})
        if #oldBans > 0 then
            for _, b in ipairs(oldBans) do
                b.id = nextBanId()
                Bans[#Bans + 1] = b
                insertBan(b)
            end
            saveJson('bans.json', {})
            print(('^2[TakeAdmin] %d Bann(s) aus data/bans.json in die Datenbank übernommen.^0'):format(#oldBans))
        end
        local oldWarns, migrated = loadJson('warns.json', {}), 0
        for license, list in pairs(oldWarns) do
            if type(license) == 'string' and not Warns[license] then
                Warns[license] = list
                SaveWarns(license)
                migrated = migrated + 1
            end
        end
        if migrated > 0 then
            saveJson('warns.json', {})
            print(('^2[TakeAdmin] Verwarnungen von %d Spieler(n) in die Datenbank übernommen.^0'):format(migrated))
        end
    else
        Bans = loadJson('bans.json', {})
        Warns = loadJson('warns.json', {})
    end

    ready = true
    print(('[TakeAdmin] Speicher: %s | %d Bann(s) geladen.'):format(useSQL and 'MySQL (oxmysql)' or 'JSON (data/bans.json)', #Bans))
end)

-- ---------------------------------------------------------------- Banns

local function removeExpired()
    local now = os.time()
    for i = #Bans, 1, -1 do
        local b = Bans[i]
        if b.expire ~= 0 and b.expire <= now then
            table.remove(Bans, i)
            deleteBan(b.id)
        end
    end
end

function FindBan(identifiers, tokens)
    removeExpired()
    for _, ban in ipairs(Bans) do
        for _, id in ipairs(identifiers) do
            if contains(ban.identifiers, id) then return ban end
        end
        for _, t in ipairs(tokens or {}) do
            if contains(ban.tokens or {}, t) then return ban end
        end
    end
    return nil
end

function BanMessage(ban)
    local expire = ban.expire == 0 and 'Permanent' or (FormatTime(ban.expire) .. ' (noch ' .. FormatDuration(ban.expire - os.time()) .. ')')
    return ('\n[TakeAdmin] Du bist von diesem Server gebannt.\n\nBan-ID: #%d\nGrund: %s\nGebannt von: %s\nAblauf: %s\n\n%s')
        :format(ban.id, ban.reason, ban.admin, expire, Config.BanAppeal)
end

-- Bannt einen Spieler (online: src gesetzt | offline: data mit name/identifiers/tokens)
function AddBan(adminSrc, data, reason, duration)
    local ban = {
        id          = nextBanId(),
        name        = data.name,
        identifiers = data.identifiers,
        tokens      = data.tokens or {},
        reason      = reason,
        admin       = Name(adminSrc),
        time        = os.time(),
        expire      = duration > 0 and (os.time() + duration) or 0,
    }
    Bans[#Bans + 1] = ban
    insertBan(ban)
    return ban
end

function RemoveBan(id)
    for i, b in ipairs(Bans) do
        if b.id == id then
            table.remove(Bans, i)
            deleteBan(b.id)
            return b
        end
    end
    return nil
end

function BanOnline(adminSrc, target, reason, duration)
    local ban = AddBan(adminSrc, {
        name        = Name(target),
        identifiers = GetIdentifiersOf(target),
        tokens      = GetTokensOf(target),
    }, reason, duration)
    DropPlayer(target, BanMessage(ban))
    return ban
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('[TakeAdmin] Prüfe Bann-Status...')

    while not ready do Wait(100) end

    local ids, tokens = GetIdentifiersOf(src), GetTokensOf(src)
    local ban = FindBan(ids, tokens)
    if ban then
        -- Neue Identifier an den Bann anhängen (gegen Ban-Umgehung)
        local changed = false
        for _, id in ipairs(ids) do
            if not contains(ban.identifiers, id) then ban.identifiers[#ban.identifiers + 1] = id; changed = true end
        end
        ban.tokens = ban.tokens or {}
        for _, t in ipairs(tokens) do
            if not contains(ban.tokens, t) then ban.tokens[#ban.tokens + 1] = t; changed = true end
        end
        if changed then updateBanIds(ban) end
        deferrals.done(BanMessage(ban))
        print(('[TakeAdmin] Gebannter Spieler %s abgewiesen (Ban #%d)'):format(GetPlayerName(src) or '?', ban.id))
        return
    end
    deferrals.done()
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    table.insert(Recent, 1, {
        name        = Name(src),
        id          = src,
        identifiers = GetIdentifiersOf(src),
        tokens      = GetTokensOf(src),
        reason      = reason,
        time        = os.time(),
    })
    while #Recent > Config.RecentPlayers do table.remove(Recent) end
end)
