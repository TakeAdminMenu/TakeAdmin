ESX = nil
RESOURCE = GetCurrentResourceName()

if Config.Framework == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then
        ESX = obj
    else
        print('^1[TakeAdmin] es_extended nicht gefunden - starte im Standalone-Modus. Starte es_extended VOR TakeAdmin.^0')
    end
end

function GetXPlayer(src)
    if not ESX then return nil end
    return ESX.GetPlayerFromId(src)
end

-- ---------------------------------------------------------------- Rechte

function GetLevel(src)
    src = tonumber(src)
    if not src or src <= 0 then return 9999 end -- Konsole
    if not IntegrityOk then return 0 end -- Menü-Design verändert

    local level = 0
    local xPlayer = GetXPlayer(src)
    if xPlayer then
        level = Config.Groups[xPlayer.getGroup()] or 0
    end
    if Config.UseAce then
        for group, lvl in pairs(Config.Groups) do
            if lvl > level and IsPlayerAceAllowed(src, 'takeadmin.' .. group) then
                level = lvl
            end
        end
    end
    return level
end

function HasPerm(src, perm)
    local need = Config.Permissions[perm]
    if not need then return false end
    return GetLevel(src) >= need
end

function GetGroupName(src)
    local xPlayer = GetXPlayer(src)
    if xPlayer then return xPlayer.getGroup() end
    local best, bestLvl = 'user', 0
    for group, lvl in pairs(Config.Groups) do
        if lvl > bestLvl and IsPlayerAceAllowed(src, 'takeadmin.' .. group) then
            best, bestLvl = group, lvl
        end
    end
    return best
end

function GetStaff(perm)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if HasPerm(id, perm or 'menu') then list[#list + 1] = id end
    end
    return list
end

-- ---------------------------------------------------------------- Allgemein

function Name(src)
    if not src or src == 0 then return 'Konsole' end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

function PlayerExists(src)
    src = tonumber(src)
    return src ~= nil and GetPlayerName(src) ~= nil
end

function Notify(src, msg, nType)
    if src == 0 then print('[TakeAdmin] ' .. msg) return end
    TriggerClientEvent('takeadmin:notify', src, msg, nType or 'info')
end

function NotifyStaff(msg, nType, perm)
    for _, id in ipairs(GetStaff(perm)) do Notify(id, msg, nType) end
end

function GetIdentifiersOf(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if Config.BanIP or not id:find('^ip:') then
            ids[#ids + 1] = id
        end
    end
    return ids
end

function GetTokensOf(src)
    local tokens = {}
    local n = GetNumPlayerTokens(src) or 0
    for i = 0, n - 1 do
        local t = GetPlayerToken(src, i)
        if t then tokens[#tokens + 1] = t end
    end
    return tokens
end

function GetIdentifier(src, kind)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('^' .. kind .. ':') then return id end
    end
    return nil
end

function FormatTime(ts)
    if not ts or ts == 0 then return 'Nie' end
    return os.date('%d.%m.%Y %H:%M', ts)
end

function FormatDuration(sec)
    if sec <= 0 then return 'Permanent' end
    local d = math.floor(sec / 86400); sec = sec % 86400
    local h = math.floor(sec / 3600); sec = sec % 3600
    local m = math.floor(sec / 60)
    local out = {}
    if d > 0 then out[#out + 1] = d .. 'd' end
    if h > 0 then out[#out + 1] = h .. 'h' end
    if m > 0 or #out == 0 then out[#out + 1] = m .. 'min' end
    return table.concat(out, ' ')
end

function Trim(s, max)
    s = tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #s > max then s = s:sub(1, max) end
    return s
end

-- ---------------------------------------------------------------- Logs

function Log(src, action, target, details, color)
    local adminName = Name(src)
    local line = ('[TakeAdmin] %s (%s) -> %s%s'):format(
        adminName, tostring(src), action,
        target and (' | Ziel: ' .. Name(target) .. ' (' .. target .. ')') or '',
        details and (' | ' .. details) or '')
    print(line)

    if SvConfig.Webhook == '' then return end

    local fields = {
        { name = 'Admin', value = ('%s (ID %s)\n%s'):format(adminName, tostring(src), src ~= 0 and (GetIdentifier(src, 'license') or '-') or '-'), inline = true },
    }
    if target then
        fields[#fields + 1] = { name = 'Ziel', value = ('%s (ID %s)\n%s'):format(Name(target), target, GetIdentifier(target, 'license') or '-'), inline = true }
    end
    if details then
        fields[#fields + 1] = { name = 'Details', value = tostring(details):sub(1, 1000), inline = false }
    end

    PerformHttpRequest(SvConfig.Webhook, function() end, 'POST', json.encode({
        username = SvConfig.WebhookName,
        embeds = { {
            title = action,
            color = color or 3447003,
            fields = fields,
            footer = { text = 'TakeAdmin • ' .. os.date('%d.%m.%Y %H:%M:%S') },
        } }
    }), { ['Content-Type'] = 'application/json' })
end

-- ---------------------------------------------------------------- Callbacks

local Callbacks = {}

function RegisterCallback(name, fn)
    Callbacks[name] = fn
end

RegisterNetEvent('takeadmin:cb:request', function(name, reqId, ...)
    local src = source
    local fn = Callbacks[name]
    if not fn then
        TriggerClientEvent('takeadmin:cb:response', src, reqId)
        return
    end
    local result = table.pack(pcall(fn, src, ...))
    if not result[1] then
        print('^1[TakeAdmin] Fehler in Callback ' .. tostring(name) .. ': ' .. tostring(result[2]) .. '^0')
        TriggerClientEvent('takeadmin:cb:response', src, reqId)
        return
    end
    TriggerClientEvent('takeadmin:cb:response', src, reqId, table.unpack(result, 2, result.n))
end)
