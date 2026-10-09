local Muted, Frozen, Reports, ReportCooldown, OrigBucket = {}, {}, {}, {}, {}
local reportCounter = 0

-- ================================================================ Callbacks

RegisterCallback('getPerms', function(src)
    local level = GetLevel(src)
    local perms = {}
    for perm, need in pairs(Config.Permissions) do
        perms[perm] = level >= need
    end
    return { level = level, group = GetGroupName(src), perms = perms, esx = ESX ~= nil, locked = not IntegrityOk }
end)

RegisterCallback('getPlayers', function(src)
    if not HasPerm(src, 'menu') then return {} end
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        list[#list + 1] = {
            id = id,
            name = Name(id),
            ping = GetPlayerPing(id),
            staff = GetLevel(id) > 0,
            muted = Muted[id] == true,
            frozen = Frozen[id] == true,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

RegisterCallback('getPlayer', function(src, target)
    target = tonumber(target)
    if not HasPerm(src, 'menu') or not PlayerExists(target) then return nil end
    return { id = target, name = Name(target), muted = Muted[target] == true, frozen = Frozen[target] == true }
end)

RegisterCallback('getPlayerInfo', function(src, target)
    target = tonumber(target)
    if not HasPerm(src, 'playerInfo') or not PlayerExists(target) then return nil end
    local ped = GetPlayerPed(target)
    local license = GetIdentifier(target, 'license')
    local info = {
        id          = target,
        name        = Name(target),
        ping        = GetPlayerPing(target),
        health      = ped ~= 0 and GetEntityHealth(ped) or 0,
        armor       = ped ~= 0 and GetPedArmour(ped) or 0,
        group       = GetGroupName(target),
        level       = GetLevel(target),
        warns       = license and Warns[license] and #Warns[license] or 0,
        bucket      = GetPlayerRoutingBucket(target),
        identifiers = GetPlayerIdentifiers(target),
    }
    local xPlayer = GetXPlayer(target)
    if xPlayer then
        info.esx = {
            identifier = xPlayer.identifier,
            rpName     = xPlayer.getName and xPlayer.getName() or nil,
            job        = xPlayer.job.label .. ' - ' .. (xPlayer.job.grade_label or tostring(xPlayer.job.grade)),
            accounts   = {},
        }
        for _, acc in ipairs(Config.Accounts) do
            local a = xPlayer.getAccount(acc.name)
            info.esx.accounts[#info.esx.accounts + 1] = { label = acc.label, money = a and a.money or 0 }
        end
    end
    return info
end)

RegisterCallback('getWarns', function(src, target)
    target = tonumber(target)
    if not HasPerm(src, 'warn') or not PlayerExists(target) then return {} end
    local license = GetIdentifier(target, 'license')
    return license and Warns[license] or {}
end)

RegisterCallback('getCoords', function(src, target)
    target = tonumber(target)
    if not (HasPerm(src, 'spectate') or HasPerm(src, 'goto')) or not PlayerExists(target) then return nil end
    local ped = GetPlayerPed(target)
    if ped == 0 then return nil end
    -- Admin in die gleiche Routing-Bucket (Instanz) wie das Ziel setzen
    local tb, sb = GetPlayerRoutingBucket(target), GetPlayerRoutingBucket(src)
    if tb ~= sb then
        if OrigBucket[src] == nil then OrigBucket[src] = sb end
        SetPlayerRoutingBucket(src, tb)
    end
    return GetEntityCoords(ped)
end)

RegisterNetEvent('takeadmin:resetBucket', function()
    local src = source
    if OrigBucket[src] ~= nil then
        SetPlayerRoutingBucket(src, OrigBucket[src])
        OrigBucket[src] = nil
    end
end)

RegisterCallback('getBlips', function(src)
    if not HasPerm(src, 'playerBlips') then return {} end
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local ped = GetPlayerPed(id)
        if id ~= src and ped ~= 0 then
            local c = GetEntityCoords(ped)
            list[#list + 1] = { id = id, name = Name(id), x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped), veh = GetVehiclePedIsIn(ped, false) ~= 0 }
        end
    end
    return list
end)

RegisterCallback('getBans', function(src)
    if not HasPerm(src, 'banList') then return {} end
    local list = {}
    for i = #Bans, 1, -1 do
        local b = Bans[i]
        if b.expire == 0 or b.expire > os.time() then
            list[#list + 1] = {
                id = b.id, name = b.name, reason = b.reason, admin = b.admin,
                time = FormatTime(b.time),
                expire = b.expire == 0 and 'Permanent' or FormatTime(b.expire),
                left = b.expire == 0 and 'Permanent' or FormatDuration(b.expire - os.time()),
                identifiers = b.identifiers,
            }
        end
    end
    return list
end)

RegisterCallback('getRecent', function(src)
    if not HasPerm(src, 'offlineBan') then return {} end
    local list = {}
    for i, r in ipairs(Recent) do
        list[#list + 1] = { index = i, name = r.name, id = r.id, reason = r.reason, time = FormatTime(r.time), ts = r.time }
    end
    return list
end)

RegisterCallback('getReports', function(src)
    if not HasPerm(src, 'reports') then return {} end
    local list = {}
    for _, r in pairs(Reports) do list[#list + 1] = r end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

RegisterCallback('getJobs', function(src)
    if not ESX or not HasPerm(src, 'setJob') then return {} end
    local jobs = {}
    for name, job in pairs(ESX.GetJobs()) do
        local grades = {}
        for _, g in pairs(job.grades or {}) do
            grades[#grades + 1] = { grade = tonumber(g.grade), label = g.label }
        end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        jobs[#jobs + 1] = { name = name, label = job.label, grades = grades }
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)
    return jobs
end)

-- ================================================================ Aktionen

local Actions = {}

local function Action(name, perm, needsTarget, fn)
    Actions[name] = { perm = perm, target = needsTarget, fn = fn }
end

RegisterNetEvent('takeadmin:action', function(name, target, data)
    local src = source
    local a = type(name) == 'string' and Actions[name]
    if not a then return end

    if not HasPerm(src, a.perm) then
        Notify(src, 'Keine Berechtigung.', 'error')
        Log(src, 'Unerlaubter Zugriffsversuch', nil, 'Aktion: ' .. name, 15158332)
        return
    end

    if a.target then
        target = tonumber(target)
        if not PlayerExists(target) then
            Notify(src, 'Spieler nicht gefunden.', 'error')
            return
        end
        if target ~= src and GetLevel(target) > GetLevel(src) then
            Notify(src, 'Dieser Spieler hat einen höheren Rang als du.', 'error')
            return
        end
    end

    a.fn(src, target, type(data) == 'table' and data or {})
end)

-- ---------------------------------------------------------------- Spieler

Action('kick', 'kick', true, function(src, target, data)
    local reason = Trim(data.reason, 200)
    if reason == '' then reason = 'Kein Grund angegeben' end
    Log(src, 'Kick', target, 'Grund: ' .. reason, 15105570)
    NotifyStaff(('%s wurde von %s gekickt: %s'):format(Name(target), Name(src), reason), 'warning')
    DropPlayer(target, '[TakeAdmin] Du wurdest gekickt.\nGrund: ' .. reason .. '\nVon: ' .. Name(src))
end)

Action('ban', 'ban', true, function(src, target, data)
    if target == src then return Notify(src, 'Du kannst dich nicht selbst bannen.', 'error') end
    local reason = Trim(data.reason, 200)
    if reason == '' then reason = 'Kein Grund angegeben' end
    local duration = tonumber(data.duration) or 0
    local name = Name(target)
    local ban = BanOnline(src, target, reason, duration)
    Log(src, 'Bann', nil, ('Spieler: %s\nGrund: %s\nDauer: %s\nBan-ID: #%d'):format(name, reason, FormatDuration(duration), ban.id), 15158332)
    NotifyStaff(('%s wurde von %s gebannt (%s): %s'):format(name, Name(src), FormatDuration(duration), reason), 'error')
end)

Action('offlineBan', 'offlineBan', false, function(src, _, data)
    local r = Recent[tonumber(data.index) or 0]
    if not r or r.time ~= data.time then
        -- Liste hat sich verschoben -> per Zeitstempel suchen
        r = nil
        for _, entry in ipairs(Recent) do
            if entry.time == data.time and entry.name == data.name then r = entry break end
        end
    end
    if not r then return Notify(src, 'Eintrag nicht mehr vorhanden.', 'error') end
    local reason = Trim(data.reason, 200)
    if reason == '' then reason = 'Kein Grund angegeben' end
    local duration = tonumber(data.duration) or 0
    local ban = AddBan(src, r, reason, duration)
    Log(src, 'Offline-Bann', nil, ('Spieler: %s\nGrund: %s\nDauer: %s\nBan-ID: #%d'):format(r.name, reason, FormatDuration(duration), ban.id), 15158332)
    Notify(src, ('%s wurde offline gebannt (#%d).'):format(r.name, ban.id), 'success')
end)

Action('unban', 'unban', false, function(src, _, data)
    local ban = RemoveBan(tonumber(data.id) or -1)
    if not ban then return Notify(src, 'Bann nicht gefunden.', 'error') end
    Log(src, 'Entbannung', nil, ('Spieler: %s\nBan-ID: #%d\nUrsprünglicher Grund: %s'):format(ban.name, ban.id, ban.reason), 3066993)
    Notify(src, ban.name .. ' wurde entbannt.', 'success')
end)

Action('warn', 'warn', true, function(src, target, data)
    local reason = Trim(data.reason, 200)
    if reason == '' then return Notify(src, 'Bitte einen Grund angeben.', 'error') end
    local license = GetIdentifier(target, 'license') or ('id:' .. target)
    Warns[license] = Warns[license] or {}
    table.insert(Warns[license], { reason = reason, admin = Name(src), time = FormatTime(os.time()) })
    SaveWarns(license)

    local count = #Warns[license]
    TriggerClientEvent('takeadmin:bigMessage', target, 'VERWARNUNG', ('%s<br><small>Verwarnung %d / %d • von %s</small>'):format(reason, count, Config.MaxWarns, Name(src)), 'warn')
    Log(src, 'Verwarnung', target, ('Grund: %s\nAnzahl: %d/%d'):format(reason, count, Config.MaxWarns), 16776960)
    Notify(src, ('%s verwarnt (%d/%d).'):format(Name(target), count, Config.MaxWarns), 'success')

    if count >= Config.MaxWarns then
        Warns[license] = {}
        SaveWarns(license)
        local autoReason = ('Automatisch: %d Verwarnungen (letzte: %s)'):format(count, reason)
        SetTimeout(4000, function()
            if not PlayerExists(target) then return end
            if Config.WarnAction == 'ban' then
                BanOnline(src, target, autoReason, Config.WarnBanTime)
            else
                DropPlayer(target, '[TakeAdmin] ' .. autoReason)
            end
        end)
    end
end)

Action('clearWarns', 'warn', true, function(src, target)
    local license = GetIdentifier(target, 'license') or ('id:' .. target)
    Warns[license] = nil
    SaveWarns(license)
    Log(src, 'Verwarnungen gelöscht', target)
    Notify(src, 'Verwarnungen von ' .. Name(target) .. ' gelöscht.', 'success')
end)

Action('mute', 'mute', true, function(src, target, data)
    local state = data.state == true
    Muted[target] = state or nil
    MumbleSetPlayerMuted(target, state)
    Notify(target, state and 'Du wurdest stummgeschaltet (Voice & Chat).' or 'Deine Stummschaltung wurde aufgehoben.', state and 'warning' or 'success')
    Notify(src, Name(target) .. (state and ' stummgeschaltet.' or ' entstummt.'), 'success')
    Log(src, state and 'Stummgeschaltet' or 'Entstummt', target)
end)

Action('freeze', 'freeze', true, function(src, target, data)
    local state = data.state == true
    Frozen[target] = state or nil
    TriggerClientEvent('takeadmin:freeze', target, state)
    Notify(src, Name(target) .. (state and ' eingefroren.' or ' aufgetaut.'), 'success')
    Log(src, state and 'Eingefroren' or 'Aufgetaut', target)
end)

Action('bring', 'bring', true, function(src, target)
    local ped = GetPlayerPed(src)
    local sb = GetPlayerRoutingBucket(src)
    if GetPlayerRoutingBucket(target) ~= sb then SetPlayerRoutingBucket(target, sb) end
    TriggerClientEvent('takeadmin:teleport', target, GetEntityCoords(ped))
    Notify(target, 'Du wurdest von einem Admin teleportiert.', 'info')
    Log(src, 'Spieler hergeholt', target)
end)

Action('goto', 'goto', true, function(src, target)
    Log(src, 'Zum Spieler teleportiert', target)
end)

Action('spectate', 'spectate', true, function(src, target)
    Log(src, 'Spectate gestartet', target)
end)

Action('slap', 'slap', true, function(src, target, data)
    local power = math.max(1, math.min(tonumber(data.power) or 1, 10))
    TriggerClientEvent('takeadmin:slap', target, power)
    Log(src, 'Geschlagen', target, 'Stärke: ' .. power)
end)

Action('kill', 'kill', true, function(src, target)
    TriggerClientEvent('takeadmin:kill', target)
    Log(src, 'Getötet', target, nil, 15158332)
end)

Action('heal', 'heal', true, function(src, target)
    TriggerClientEvent('takeadmin:heal', target)
    Notify(target, 'Du wurdest von einem Admin geheilt.', 'success')
    Log(src, 'Geheilt', target)
end)

Action('revive', 'revive', true, function(src, target)
    TriggerClientEvent('takeadmin:revive', target)
    Notify(target, 'Du wurdest von einem Admin wiederbelebt.', 'success')
    Log(src, 'Wiederbelebt', target)
end)

Action('dm', 'dm', true, function(src, target, data)
    local msg = Trim(data.message, 300)
    if msg == '' then return end
    TriggerClientEvent('takeadmin:bigMessage', target, 'NACHRICHT VOM ADMIN', msg .. '<br><small>von ' .. Name(src) .. '</small>', 'info')
    Notify(src, 'Nachricht gesendet.', 'success')
    Log(src, 'Privatnachricht', target, msg)
end)

Action('screenshot', 'screenshot', true, function(src, target)
    if GetResourceState('screenshot-basic') ~= 'started' then
        return Notify(src, 'screenshot-basic ist nicht gestartet.', 'error')
    end
    Notify(src, 'Screenshot wird angefordert...', 'info')
    exports['screenshot-basic']:requestClientScreenshot(target, { encoding = 'jpg', quality = 0.85 }, function(err, data)
        if err or not data then
            return Notify(src, 'Screenshot fehlgeschlagen: ' .. tostring(err), 'error')
        end
        TriggerLatentClientEvent('takeadmin:showScreenshot', src, 250000, data, Name(target))
        Log(src, 'Screenshot erstellt', target)
    end)
end)

-- ---------------------------------------------------------------- ESX

local function needESX(src)
    if not ESX then Notify(src, 'ESX ist nicht aktiv.', 'error') return false end
    return true
end

Action('giveMoney', 'giveMoney', true, function(src, target, data)
    if not needESX(src) then return end
    local xT = GetXPlayer(target)
    local amount = math.floor(tonumber(data.amount) or 0)
    local valid = false
    for _, acc in ipairs(Config.Accounts) do if acc.name == data.account then valid = true end end
    if not xT or not valid or amount == 0 then return Notify(src, 'Ungültige Eingabe.', 'error') end
    if amount > 0 then xT.addAccountMoney(data.account, amount) else xT.removeAccountMoney(data.account, -amount) end
    Notify(src, ('%s: %s$ (%s)'):format(Name(target), amount, data.account), 'success')
    Log(src, 'Geld gegeben', target, ('Konto: %s | Betrag: %d'):format(data.account, amount), 3066993)
end)

Action('setJob', 'setJob', true, function(src, target, data)
    if not needESX(src) then return end
    local xT = GetXPlayer(target)
    local grade = tonumber(data.grade) or 0
    if not xT or not ESX.DoesJobExist(data.job, grade) then return Notify(src, 'Job/Rang existiert nicht.', 'error') end
    xT.setJob(data.job, grade)
    Notify(src, ('Job von %s: %s (%d)'):format(Name(target), data.job, grade), 'success')
    Log(src, 'Job gesetzt', target, ('%s | Rang %d'):format(data.job, grade))
end)

Action('setGroup', 'setGroup', true, function(src, target, data)
    if not needESX(src) then return end
    local xT = GetXPlayer(target)
    local group = tostring(data.group or '')
    local lvl = group == 'user' and 0 or Config.Groups[group]
    if not xT or not lvl then return Notify(src, 'Ungültige Gruppe.', 'error') end
    if lvl > GetLevel(src) then return Notify(src, 'Du kannst keine höhere Gruppe als deine vergeben.', 'error') end
    xT.setGroup(group)
    Notify(src, ('Gruppe von %s: %s'):format(Name(target), group), 'success')
    Notify(target, 'Deine Gruppe wurde auf ' .. group .. ' gesetzt.', 'info')
    Log(src, 'Gruppe gesetzt', target, group, 10181046)
end)

Action('giveItem', 'giveItem', true, function(src, target, data)
    if not needESX(src) then return end
    local xT = GetXPlayer(target)
    local item, count = Trim(data.item, 60), math.floor(tonumber(data.count) or 1)
    if not xT or item == '' or count < 1 then return Notify(src, 'Ungültige Eingabe.', 'error') end
    if ESX.GetItemLabel and not ESX.GetItemLabel(item) then return Notify(src, 'Item "' .. item .. '" existiert nicht.', 'error') end
    xT.addInventoryItem(item, count)
    Notify(src, ('%dx %s an %s gegeben.'):format(count, item, Name(target)), 'success')
    Log(src, 'Item gegeben', target, ('%dx %s'):format(count, item))
end)

Action('clearInventory', 'clearInventory', true, function(src, target)
    if not needESX(src) then return end
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:ClearInventory(target)
    else
        local xT = GetXPlayer(target)
        if not xT then return end
        for _, it in pairs(xT.getInventory()) do
            if it.count and it.count > 0 then xT.removeInventoryItem(it.name, it.count) end
        end
    end
    Notify(src, 'Inventar von ' .. Name(target) .. ' geleert.', 'success')
    Log(src, 'Inventar geleert', target, nil, 15105570)
end)

-- ---------------------------------------------------------------- Server

Action('announce', 'announce', false, function(src, _, data)
    local msg = Trim(data.message, 400)
    if msg == '' then return end
    TriggerClientEvent('takeadmin:bigMessage', -1, 'ANKÜNDIGUNG', msg, 'announce')
    Log(src, 'Ankündigung', nil, msg)
end)

Action('weather', 'weather', false, function(src, _, data)
    local w = tostring(data.weather or '')
    local valid = false
    for _, v in ipairs(Config.Weather) do if v == w then valid = true end end
    if not valid then return end
    GlobalState.takeadmin_weather = w
    TriggerClientEvent('takeadmin:setWeather', -1, w)
    Notify(src, 'Wetter: ' .. w, 'success')
    Log(src, 'Wetter geändert', nil, w)
end)

Action('time', 'time', false, function(src, _, data)
    local h = math.floor(tonumber(data.hour) or 12) % 24
    -- Startzeit + Zeitstempel: Clients rechnen daraus die laufende Uhrzeit und halten sie fest
    GlobalState.takeadmin_time = { h = h, m = 0, t = os.time() }
    TriggerClientEvent('takeadmin:setTime', -1, h, 0)
    Notify(src, ('Uhrzeit: %02d:00'):format(h), 'success')
    Log(src, 'Uhrzeit geändert', nil, ('%02d:00'):format(h))
end)

local function playerPeds()
    local set = {}
    for _, id in ipairs(GetPlayers()) do set[GetPlayerPed(id)] = true end
    return set
end

Action('cleanup', 'cleanup', false, function(src, _, data)
    local kind, count = data.kind, 0
    local peds = playerPeds()
    if kind == 'vehicles' then
        for _, veh in ipairs(GetAllVehicles()) do
            local occupied = false
            for seat = -1, 6 do
                local p = GetPedInVehicleSeat(veh, seat)
                if p ~= 0 and peds[p] then occupied = true break end
            end
            if not occupied then DeleteEntity(veh); count = count + 1 end
        end
    elseif kind == 'peds' then
        for _, ped in ipairs(GetAllPeds()) do
            if not peds[ped] then DeleteEntity(ped); count = count + 1 end
        end
    elseif kind == 'objects' then
        for _, obj in ipairs(GetAllObjects()) do DeleteEntity(obj); count = count + 1 end
    else
        return
    end
    TriggerClientEvent('takeadmin:notify', -1, ('Server aufgeräumt: %d Entities entfernt.'):format(count), 'info')
    Log(src, 'Aufräumen (' .. kind .. ')', nil, count .. ' Entities gelöscht')
end)

Action('reviveAll', 'reviveAll', false, function(src)
    TriggerClientEvent('takeadmin:revive', -1)
    TriggerClientEvent('takeadmin:notify', -1, 'Alle Spieler wurden wiederbelebt.', 'success')
    Log(src, 'Alle wiederbelebt')
end)

Action('bringAll', 'bringAll', false, function(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then TriggerClientEvent('takeadmin:teleport', id, c) end
    end
    Log(src, 'Alle Spieler hergeholt', nil, nil, 15105570)
end)

Action('kickAll', 'kickAll', false, function(src, _, data)
    local reason = Trim(data.reason, 200)
    if reason == '' then reason = 'Serverneustart / Wartung' end
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if not HasPerm(id, 'menu') then DropPlayer(id, '[TakeAdmin] ' .. reason) end
    end
    Log(src, 'Alle gekickt', nil, reason, 15158332)
end)

Action('restartRes', 'restartRes', false, function(src, _, data)
    local res = Trim(data.resource, 80)
    if res == '' or res == RESOURCE or GetResourceState(res) == 'missing' then
        return Notify(src, 'Ressource ungültig.', 'error')
    end
    StopResource(res)
    SetTimeout(500, function()
        StartResource(res)
        Notify(src, 'Ressource ' .. res .. ' neu gestartet.', 'success')
    end)
    Log(src, 'Ressource neugestartet', nil, res, 15105570)
end)

-- ---------------------------------------------------------------- Reports

Action('reportClaim', 'reports', false, function(src, _, data)
    local r = Reports[tonumber(data.id) or -1]
    if not r then return Notify(src, 'Report existiert nicht mehr.', 'error') end
    r.claimed = Name(src)
    if PlayerExists(r.src) then Notify(r.src, Name(src) .. ' kümmert sich um deinen Report.', 'success') end
    NotifyStaff(('Report #%d wurde von %s übernommen.'):format(r.id, Name(src)), 'info', 'reports')
end)

Action('reportClose', 'reports', false, function(src, _, data)
    local r = Reports[tonumber(data.id) or -1]
    if not r then return end
    Reports[r.id] = nil
    if PlayerExists(r.src) then Notify(r.src, 'Dein Report wurde geschlossen.', 'info') end
    Log(src, 'Report geschlossen', nil, ('#%d von %s: %s'):format(r.id, r.name, r.message))
end)

RegisterCommand(Config.ReportCommand, function(src, args)
    if src == 0 then return end
    local msg = Trim(table.concat(args, ' '), 300)
    if msg == '' then return Notify(src, 'Benutzung: /' .. Config.ReportCommand .. ' <Nachricht>', 'error') end
    if ReportCooldown[src] and os.time() < ReportCooldown[src] then
        return Notify(src, 'Bitte warte, bevor du einen neuen Report sendest.', 'error')
    end
    ReportCooldown[src] = os.time() + Config.ReportCooldown
    reportCounter = reportCounter + 1
    Reports[reportCounter] = { id = reportCounter, src = src, name = Name(src), message = msg, time = os.date('%H:%M'), claimed = false }
    Notify(src, 'Report gesendet. Ein Teammitglied meldet sich.', 'success')
    NotifyStaff(('Neuer Report #%d von %s [%d]: %s'):format(reportCounter, Name(src), src, msg), 'report', 'reports')
    Log(src, 'Neuer Report', nil, msg, 10181046)
end, false)

RegisterCommand(Config.AdminChatCommand, function(src, args)
    if src ~= 0 and not HasPerm(src, 'adminChat') then return end
    local msg = Trim(table.concat(args, ' '), 300)
    if msg == '' then return end
    NotifyStaff(('[Admin-Chat] %s: %s'):format(Name(src), msg), 'staff', 'adminChat')
end, false)

RegisterNetEvent('takeadmin:selfLog', function(text)
    local src = source
    if not HasPerm(src, 'menu') or type(text) ~= 'string' then return end
    Log(src, Trim(text, 120))
end)

-- ---------------------------------------------------------------- Konsole

-- ta_unban <Ban-ID | Name | Identifier>
RegisterCommand('ta_unban', function(src, args)
    if src ~= 0 and not HasPerm(src, 'unban') then return end
    local query = table.concat(args, ' ')
    if query == '' then return Notify(src, 'Benutzung: ta_unban <Ban-ID | Name | Identifier>', 'error') end

    local id = tonumber((query:gsub('^#', '')))
    if not id then
        local found = {}
        for _, b in ipairs(Bans) do
            local hit = b.name:lower() == query:lower()
            for _, ident in ipairs(b.identifiers) do
                if ident == query then hit = true end
            end
            if hit then found[#found + 1] = b end
        end
        if #found > 1 then
            Notify(src, 'Mehrere Banns gefunden - bitte per Ban-ID entbannen:', 'error')
            for _, b in ipairs(found) do Notify(src, ('  #%d  %s  (%s)'):format(b.id, b.name, b.reason), 'info') end
            return
        end
        id = found[1] and found[1].id or -1
    end

    local ban = RemoveBan(id)
    Notify(src, ban and ('#' .. ban.id .. ' ' .. ban.name .. ' wurde entbannt.') or 'Bann nicht gefunden.', ban and 'success' or 'error')
    if ban then Log(src, 'Entbannung', nil, ('Spieler: %s\nBan-ID: #%d'):format(ban.name, ban.id), 3066993) end
end, false)

-- ta_bans [Suchbegriff]  -> listet aktive Banns
RegisterCommand('ta_bans', function(src, args)
    if src ~= 0 and not HasPerm(src, 'banList') then return end
    local query = table.concat(args, ' '):lower()
    local count = 0
    for _, b in ipairs(Bans) do
        if (b.expire == 0 or b.expire > os.time())
            and (query == '' or b.name:lower():find(query, 1, true) or b.reason:lower():find(query, 1, true)) then
            count = count + 1
            Notify(src, ('#%d  %s  |  %s  |  von %s  |  %s'):format(
                b.id, b.name, b.reason, b.admin,
                b.expire == 0 and 'Permanent' or ('bis ' .. FormatTime(b.expire))), 'info')
        end
    end
    Notify(src, count .. ' aktive(r) Bann(s).', 'info')
end, false)

-- ---------------------------------------------------------------- Chat-Mute & Aufräumen

AddEventHandler('chatMessage', function(src)
    if Muted[src] then
        CancelEvent()
        Notify(src, 'Du bist stummgeschaltet.', 'error')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Muted[src], Frozen[src], OrigBucket[src], ReportCooldown[src] = nil, nil, nil, nil
    for id, r in pairs(Reports) do
        if r.src == src then r.name = r.name .. ' (offline)' end
    end
end)
