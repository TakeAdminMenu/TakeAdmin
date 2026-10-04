-- Alle Menüs. Jede Funktion gibt { subtitle, items, refresh } zurück.

local function myId() return GetPlayerServerId(PlayerId()) end

local function matches(text, filter)
    if not filter or filter == '' then return true end
    return tostring(text):lower():find(filter:lower(), 1, true) ~= nil
end

local function searchButton(state)
    return Button('~b~Suchen', 'Liste nach Name / ID filtern. Leere Eingabe = Filter entfernen.', function()
        state.filter = KeyboardInput('Suche (Name oder ID)', state.filter or '', 50)
        Menu.Refresh()
    end, (state.filter and state.filter ~= '') and state.filter or nil)
end

-- ================================================================ Hauptmenü

function MainMenu()
    local items = {
        Sub('Spielerverwaltung', 'Alle Spieler auf dem Server verwalten.', PlayerListMenu, {}),
    }
    if Can('reports') then items[#items + 1] = Sub('Reports', 'Offene Spieler-Reports (/' .. Config.ReportCommand .. ').', ReportsMenu) end
    if Can('offlineBan') then items[#items + 1] = Sub('Kürzlich getrennt', 'Spieler, die den Server verlassen haben (Offline-Bann).', RecentMenu) end
    if Can('banList') then items[#items + 1] = Sub('Bannliste', 'Alle aktiven Banns ansehen und aufheben.', BanListMenu, {}) end
    if Can('selfOptions') then items[#items + 1] = Sub('Eigene Optionen', 'Noclip, Godmode, Unsichtbarkeit, Teleport ...', SelfMenu) end
    if Can('vehicle') then items[#items + 1] = Sub('Fahrzeug-Optionen', 'Spawnen, reparieren, tunen, löschen ...', VehicleMenu) end

    for _, p in ipairs({ 'announce', 'weather', 'time', 'cleanup', 'reviveAll', 'bringAll', 'kickAll', 'restartRes' }) do
        if Can(p) then
            items[#items + 1] = Sub('Server-Verwaltung', 'Ankündigungen, Wetter, Uhrzeit, Aufräumen ...', ServerMenu)
            break
        end
    end

    items[#items + 1] = Button('Menü schließen', nil, function() Menu.Close() end)
    return { subtitle = ('Hauptmenü  •  %s'):format(Perms.group or ''), items = items }
end

-- ================================================================ Spieler

function PlayerListMenu(state)
    local players = TriggerCallback('getPlayers') or {}
    local items = { searchButton(state) }
    local count = 0
    for _, p in ipairs(players) do
        if matches(p.name, state.filter) or tostring(p.id) == state.filter then
            count = count + 1
            local flags = {}
            if p.staff then flags[#flags + 1] = '★' end
            if p.muted then flags[#flags + 1] = 'Stumm' end
            if p.frozen then flags[#flags + 1] = 'Eingefroren' end
            local it = Sub(('[%d] %s'):format(p.id, p.name), ('Ping: %dms%s'):format(p.ping, p.id == myId() and '  •  Das bist du' or ''), PlayerMenu, p.id, p.name)
            it.right = #flags > 0 and table.concat(flags, ' ') or nil
            items[#items + 1] = it
        end
    end
    return { subtitle = ('Spieler online: %d'):format(count), items = items, refresh = true }
end

function PlayerMenu(id, name)
    local p = TriggerCallback('getPlayer', id)
    if not p then
        Notify('Spieler ist nicht mehr online.', 'error')
        return nil
    end
    name = p.name
    local items = {}
    local function add(perm, item) if Can(perm) then items[#items + 1] = item end end

    add('kick', Button('Spieler kicken', 'Spieler mit Grund vom Server werfen.', function()
        local reason = KeyboardInput('Kick-Grund', '', 200)
        if not reason then return end
        DoAction('kick', id, { reason = reason })
        Wait(400)
        Menu.BackTo(1)
    end))

    add('ban', Sub('Spieler bannen', 'Spieler zeitlich oder permanent bannen.', BanMenu, id, name, { reason = '', dur = 4 }))

    add('mute', Checkbox('Stummschalten', 'Voice-Chat und Text-Chat sperren.', p.muted, function(state)
        DoAction('mute', id, { state = state })
    end))

    add('spectate', Button(Features.spectating == id and '~o~Zuschauen beenden' or 'Spieler zuschauen', 'Unsichtbar zuschauen (funktioniert auch in anderen Instanzen).', function()
        if Features.spectating == id then StopSpectate() else StartSpectate(id, name) end
        Menu.Refresh()
    end))

    add('goto', Button('Zum Spieler teleportieren', nil, function()
        if Features.spectating then StopSpectate() end
        local coords = TriggerCallback('getCoords', id)
        if not coords then return Notify('Spieler nicht gefunden.', 'error') end
        TeleportTo(coords, false)
        DoAction('goto', id)
    end))

    add('bring', Button('Spieler zu mir teleportieren', nil, function()
        DoAction('bring', id)
    end))

    add('slap', Slider('Spieler schlagen', 'Stärke mit ←/→ einstellen, Enter zum Schlagen.', 3, 10, function(value)
        DoAction('slap', id, { power = math.max(1, value) })
    end))

    add('freeze', Checkbox('Spieler einfrieren', 'Spieler kann sich nicht mehr bewegen.', p.frozen, function(state)
        DoAction('freeze', id, { state = state })
    end))

    add('screenshot', Button('Screenshot machen', 'Benötigt screenshot-basic. Bild wird direkt hier angezeigt.', function()
        DoAction('screenshot', id)
    end))

    add('warn', Button('Spieler verwarnen', ('Ab %d Verwarnungen: automatischer %s.'):format(Config.MaxWarns, Config.WarnAction == 'ban' and 'Bann' or 'Kick'), function()
        local reason = KeyboardInput('Verwarnungsgrund', '', 200)
        if reason then DoAction('warn', id, { reason = reason }) end
    end))

    add('warn', Sub('Verwarnungen ansehen', nil, WarnsMenu, id, name))

    items[#items + 1] = Separator('Weitere Aktionen')

    add('heal', Button('Heilen', 'Leben, Hunger und Durst auffüllen.', function() DoAction('heal', id) end))
    add('revive', Button('Wiederbeleben', nil, function() DoAction('revive', id) end))
    add('kill', Button('~r~Töten', nil, function()
        Menu.Confirm(name .. ' töten?', function() DoAction('kill', id) end)
    end))
    add('dm', Button('Privatnachricht senden', 'Große Nachricht auf dem Bildschirm des Spielers.', function()
        local msg = KeyboardInput('Nachricht an ' .. name, '', 300)
        if msg then DoAction('dm', id, { message = msg }) end
    end))
    add('playerInfo', Sub('Spieler-Informationen', 'Identifier, Geld, Job, Gruppe ...', PlayerInfoMenu, id))

    if Perms.esx then
        for _, perm in ipairs({ 'giveMoney', 'setJob', 'setGroup', 'giveItem', 'clearInventory' }) do
            if Can(perm) then
                items[#items + 1] = Sub('ESX-Optionen', 'Geld, Job, Gruppe, Items, Inventar.', ESXMenu, id, name)
                break
            end
        end
    end

    return { subtitle = ('[%d] %s'):format(id, name), items = items }
end

function BanMenu(target, name, state, recent)
    local reasonText = state.reason ~= '' and state.reason or '~c~Kein Grund'
    return {
        subtitle = (recent and 'Offline-Bann: ' or 'Bannen: ') .. name,
        items = {
            Button('Grund', 'Grund eingeben (wird dem Spieler angezeigt).', function()
                local r = KeyboardInput('Bann-Grund', state.reason, 200)
                if r then state.reason = r end
                Menu.Refresh()
            end, reasonText),
            List('Dauer', 'Wie lange soll der Bann gelten?', Config.BanDurations, state.dur, nil, function(idx)
                state.dur = idx
            end),
            Button('~r~Bann ausführen', nil, function()
                if state.reason == '' then return Notify('Bitte zuerst einen Grund eingeben.', 'error') end
                local dur = Config.BanDurations[state.dur]
                Menu.Confirm(('%s bannen (%s)?'):format(name, dur.label), function()
                    if recent then
                        DoAction('offlineBan', nil, { index = recent.index, time = recent.ts, name = recent.name, reason = state.reason, duration = dur.time })
                        Wait(300)
                        Menu.BackTo(1)
                    else
                        DoAction('ban', target, { reason = state.reason, duration = dur.time })
                        Wait(500)
                        Menu.BackTo(2)
                    end
                end)
            end),
        }
    }
end

function WarnsMenu(id, name)
    local warns = TriggerCallback('getWarns', id) or {}
    local items = {}
    for i, w in ipairs(warns) do
        items[#items + 1] = Button(('#%d  %s'):format(i, w.reason), ('Von %s am %s'):format(w.admin, w.time), nil)
    end
    if #items == 0 then
        items[#items + 1] = Button('~c~Keine Verwarnungen', nil, nil)
    else
        items[#items + 1] = Button('~r~Alle Verwarnungen löschen', nil, function()
            Menu.Confirm('Verwarnungen löschen?', function()
                DoAction('clearWarns', id)
                Wait(300)
                Menu.Refresh()
            end)
        end)
    end
    return { subtitle = ('Verwarnungen: %s (%d/%d)'):format(name, #warns, Config.MaxWarns), items = items }
end

function PlayerInfoMenu(id)
    local info = TriggerCallback('getPlayerInfo', id)
    if not info then Notify('Spieler nicht gefunden.', 'error') return nil end
    local copy = function(it) CopyToClipboard(it.copy) end
    local function line(label, value)
        local it = Button(label, 'Enter = kopieren', copy, tostring(value))
        it.copy = tostring(value)
        return it
    end

    local items = {
        line('Server-ID', info.id),
        line('Name', info.name),
        line('Ping', info.ping .. ' ms'),
        line('Leben', math.max(0, info.health - 100)),
        line('Rüstung', info.armor),
        line('Gruppe', ('%s (Level %d)'):format(info.group, info.level)),
        line('Verwarnungen', info.warns .. ' / ' .. Config.MaxWarns),
        line('Instanz (Bucket)', info.bucket),
    }
    if info.esx then
        items[#items + 1] = Separator('ESX')
        if info.esx.rpName then items[#items + 1] = line('RP-Name', info.esx.rpName) end
        items[#items + 1] = line('Job', info.esx.job)
        for _, acc in ipairs(info.esx.accounts) do
            items[#items + 1] = line(acc.label, acc.money .. ' $')
        end
        items[#items + 1] = line('ESX-Identifier', info.esx.identifier)
    end
    items[#items + 1] = Separator('Identifier')
    for _, ident in ipairs(info.identifiers) do
        local kind, value = ident:match('^(%w+):(.+)$')
        items[#items + 1] = line(kind or 'id', ident)
    end
    return { subtitle = ('Info: [%d] %s'):format(info.id, info.name), items = items, refresh = true }
end

-- ================================================================ ESX

function ESXMenu(id, name)
    local items = {}

    if Can('giveMoney') then
        items[#items + 1] = List('Geld geben', 'Konto mit ←/→ wählen, Enter = Betrag eingeben (negativ = abziehen).', Config.Accounts, 1, function(_, acc)
            local amount = tonumber(KeyboardInput(acc.label .. ' Betrag', '', 12))
            if amount then DoAction('giveMoney', id, { account = acc.name, amount = amount }) end
        end)
    end

    if Can('setJob') then
        items[#items + 1] = Sub('Job setzen', 'Job und Rang aus Liste wählen.', JobsMenu, id, name, {})
        items[#items + 1] = Button('Job setzen (manuell)', 'Jobname und Rang eintippen.', function()
            local job = KeyboardInput('Jobname (z. B. police)', '', 50)
            if not job then return end
            local grade = tonumber(KeyboardInput('Rang (Zahl)', '0', 3)) or 0
            DoAction('setJob', id, { job = job, grade = grade })
        end)
    end

    if Can('setGroup') then
        local groups = { { label = 'user', level = 0 } }
        for g, lvl in pairs(Config.Groups) do
            if lvl <= Perms.level then groups[#groups + 1] = { label = g, level = lvl } end
        end
        table.sort(groups, function(a, b) return a.level < b.level end)
        items[#items + 1] = List('Gruppe setzen', 'Gruppe mit ←/→ wählen, Enter = setzen.', groups, 1, function(_, g)
            Menu.Confirm(('Gruppe von %s auf %s setzen?'):format(name, g.label), function()
                DoAction('setGroup', id, { group = g.label })
            end)
        end)
    end

    if Can('giveItem') then
        items[#items + 1] = Button('Item geben', 'Itemname und Anzahl eingeben.', function()
            local item = KeyboardInput('Itemname (z. B. bread)', '', 60)
            if not item then return end
            local count = tonumber(KeyboardInput('Anzahl', '1', 5)) or 1
            DoAction('giveItem', id, { item = item, count = count })
        end)
    end

    if Can('clearInventory') then
        items[#items + 1] = Button('~r~Inventar leeren', nil, function()
            Menu.Confirm('Inventar von ' .. name .. ' leeren?', function() DoAction('clearInventory', id) end)
        end)
    end

    return { subtitle = 'ESX: ' .. name, items = items }
end

function JobsMenu(id, name, state)
    local jobs = TriggerCallback('getJobs') or {}
    local items = { searchButton(state) }
    for _, job in ipairs(jobs) do
        if matches(job.label, state.filter) or matches(job.name, state.filter) then
            local grades = {}
            for _, g in ipairs(job.grades) do
                grades[#grades + 1] = { label = ('%s (%d)'):format(g.label, g.grade), grade = g.grade }
            end
            if #grades > 0 then
                items[#items + 1] = List(job.label, ('Job: %s  •  Rang mit ←/→ wählen, Enter = setzen'):format(job.name), grades, 1, function(_, g)
                    DoAction('setJob', id, { job = job.name, grade = g.grade })
                end)
            end
        end
    end
    return { subtitle = 'Job setzen: ' .. name, items = items }
end

-- ================================================================ Bannliste / Offline

function BanListMenu(state)
    local bans = TriggerCallback('getBans') or {}
    local items = { searchButton(state) }
    local count = 0
    for _, b in ipairs(bans) do
        if matches(b.name, state.filter) or tostring(b.id) == state.filter or matches(b.reason, state.filter) then
            count = count + 1
            local it = Sub(('#%d  %s'):format(b.id, b.name), ('Grund: %s\nVon: %s'):format(b.reason, b.admin), BanDetailMenu, b)
            it.right = b.left
            items[#items + 1] = it
        end
    end
    return { subtitle = ('Aktive Banns: %d'):format(count), items = items, refresh = true }
end

function BanDetailMenu(b)
    local copy = function(it) CopyToClipboard(it.copy) end
    local function line(label, value)
        local it = Button(label, tostring(value), copy, tostring(value))
        it.copy = tostring(value)
        return it
    end
    local items = {
        line('Ban-ID', '#' .. b.id),
        line('Name', b.name),
        line('Grund', b.reason),
        line('Gebannt von', b.admin),
        line('Datum', b.time),
        line('Läuft ab', b.expire),
        line('Verbleibend', b.left),
    }
    if Can('unban') then
        items[#items + 1] = Button('~g~Entbannen', nil, function()
            Menu.Confirm(b.name .. ' entbannen?', function()
                DoAction('unban', nil, { id = b.id })
                Wait(300)
                Menu.BackTo(1)
            end)
        end)
    end
    items[#items + 1] = Separator('Identifier')
    for _, ident in ipairs(b.identifiers or {}) do
        items[#items + 1] = line(ident:match('^(%w+):') or 'id', ident)
    end
    return { subtitle = ('Bann #%d: %s'):format(b.id, b.name), items = items }
end

function RecentMenu()
    local list = TriggerCallback('getRecent') or {}
    local items = {}
    for _, r in ipairs(list) do
        local it = Sub(('[%d] %s'):format(r.id, r.name), ('Getrennt: %s\nGrund: %s'):format(r.time, r.reason or '-'), BanMenu, nil, r.name, { reason = '', dur = 4 }, r)
        it.right = r.time:sub(-5)
        items[#items + 1] = it
    end
    if #items == 0 then items[1] = Button('~c~Noch niemand getrennt', nil, nil) end
    return { subtitle = 'Kürzlich getrennte Spieler', items = items, refresh = true }
end

-- ================================================================ Reports

function ReportsMenu()
    local reports = TriggerCallback('getReports') or {}
    local items = {}
    for _, r in ipairs(reports) do
        local it = Sub(('#%d  [%d] %s'):format(r.id, r.src, r.name), r.message, ReportMenu, r)
        it.right = r.claimed and ('~g~' .. r.claimed) or r.time
        items[#items + 1] = it
    end
    if #items == 0 then items[1] = Button('~c~Keine offenen Reports', nil, nil) end
    return { subtitle = ('Offene Reports: %d'):format(#reports), items = items, refresh = true }
end

function ReportMenu(r)
    local items = {
        Button('Nachricht', r.message, nil, r.time),
        Button('Übernehmen', 'Dem Spieler mitteilen, dass du dich kümmerst.', function()
            DoAction('reportClaim', nil, { id = r.id })
        end, r.claimed or nil),
    }
    if Can('goto') then
        items[#items + 1] = Button('Zum Spieler teleportieren', nil, function()
            local coords = TriggerCallback('getCoords', r.src)
            if not coords then return Notify('Spieler ist offline.', 'error') end
            TeleportTo(coords, false)
            DoAction('goto', r.src)
        end)
    end
    if Can('bring') then
        items[#items + 1] = Button('Spieler zu mir holen', nil, function() DoAction('bring', r.src) end)
    end
    items[#items + 1] = Sub('Spielermenü öffnen', nil, PlayerMenu, r.src, r.name)
    items[#items + 1] = Button('~r~Report schließen', nil, function()
        DoAction('reportClose', nil, { id = r.id })
        Wait(300)
        Menu.BackTo(1)
    end)
    return { subtitle = ('Report #%d: %s'):format(r.id, r.name), items = items }
end

-- ================================================================ Eigene Optionen

function SelfMenu()
    local items = {}
    local function log(text) TriggerServerEvent('takeadmin:selfLog', text) end

    if Can('noclip') then
        items[#items + 1] = Checkbox('Noclip', 'Durch Wände fliegen. Taste: ' .. Config.NoclipKey, Features.noclip, function(s)
            SetNoclip(s); log('Noclip ' .. (s and 'an' or 'aus'))
        end)
    end
    if Can('godmode') then
        items[#items + 1] = Checkbox('Godmode', 'Unverwundbar.', Features.godmode, function(s)
            SetGodmode(s); log('Godmode ' .. (s and 'an' or 'aus'))
        end)
    end
    if Can('invisible') then
        items[#items + 1] = Checkbox('Unsichtbar', 'Andere Spieler sehen dich nicht.', Features.invisible, function(s)
            SetInvisible(s); log('Unsichtbar ' .. (s and 'an' or 'aus'))
        end)
    end
    items[#items + 1] = Checkbox('Unendlich Ausdauer', nil, Features.stamina, function(s) Features.stamina = s end)
    items[#items + 1] = Checkbox('Super-Sprung', nil, Features.superJump, function(s) Features.superJump = s end)
    items[#items + 1] = Checkbox('Schnell rennen', nil, Features.fastRun, function(s) SetFastRun(s) end)

    items[#items + 1] = Separator()
    items[#items + 1] = Button('Heilen', nil, function() TriggerEvent('takeadmin:heal') end)
    items[#items + 1] = Button('Wiederbeleben', nil, function() TriggerEvent('takeadmin:revive'); log('Selbst wiederbelebt') end)
    items[#items + 1] = Button('Rüstung auffüllen', nil, function() SetPedArmour(PlayerPedId(), 100) end)
    items[#items + 1] = Button('Zum Wegpunkt teleportieren', 'Setze zuerst einen Wegpunkt auf der Karte.', function()
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then return Notify('Kein Wegpunkt gesetzt.', 'error') end
        TeleportTo(GetBlipInfoIdCoord(blip), true)
    end)
    items[#items + 1] = Button('Zu Koordinaten teleportieren', 'Format: x, y, z', function()
        local input = KeyboardInput('Koordinaten (x, y, z)', '', 80)
        if not input then return end
        local nums = {}
        for n in input:gmatch('-?%d+%.?%d*') do nums[#nums + 1] = tonumber(n) end
        if #nums < 2 then return Notify('Ungültige Koordinaten.', 'error') end
        TeleportTo(vector3(nums[1], nums[2], nums[3] or 0.0), nums[3] == nil)
    end)

    items[#items + 1] = Separator()
    items[#items + 1] = Checkbox('Koordinaten anzeigen', nil, Features.coords, function(s) Features.coords = s end)
    items[#items + 1] = List('Koordinaten kopieren', 'Format mit ←/→ wählen, Enter = kopieren.', { 'vector3', 'vector4', 'x, y, z', 'JSON' }, 1, function(idx)
        local c, h = GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId())
        local fmt = {
            ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z),
            ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h),
            ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z),
            ('{"x": %.2f, "y": %.2f, "z": %.2f, "h": %.2f}'):format(c.x, c.y, c.z, h),
        }
        CopyToClipboard(fmt[idx])
    end)
    if Can('playerNames') then
        items[#items + 1] = Checkbox('Spielernamen anzeigen', 'ID, Name, HP über dem Kopf. Blau = spricht.', Features.names, function(s)
            Features.names = s; log('Spielernamen ' .. (s and 'an' or 'aus'))
        end)
    end
    if Can('playerBlips') then
        items[#items + 1] = Checkbox('Spieler-Blips', 'Alle Spieler auf der Karte (OneSync).', Features.blips, function(s)
            SetBlips(s); log('Spieler-Blips ' .. (s and 'an' or 'aus'))
        end)
    end
    return { subtitle = 'Eigene Optionen', items = items }
end

-- ================================================================ Fahrzeuge

local function getVehicle(silent)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local pos, best, bestDist = GetEntityCoords(ped), 0, 6.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - pos)
        if d < bestDist then best, bestDist = v, d end
    end
    if best == 0 and not silent then Notify('Kein Fahrzeug in der Nähe.', 'error') end
    return best ~= 0 and best or nil
end

local function control(ent)
    local t = GetGameTimer() + 1500
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < t do
        NetworkRequestControlOfEntity(ent)
        Wait(10)
    end
end

local function deleteVehicle(veh)
    control(veh)
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    if DoesEntityExist(veh) then DeleteEntity(veh) end
end

function SpawnVehicle(model)
    local hash = LoadModel(model)
    if not hash or not IsModelAVehicle(hash) then return Notify('Ungültiges Fahrzeugmodell: ' .. model, 'error') end
    local ped = PlayerPedId()
    local old = GetVehiclePedIsIn(ped, false)
    if old ~= 0 then deleteVehicle(old) end
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local veh = CreateVehicle(hash, c.x, c.y, c.z, h, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true)
    SetVehicleNumberPlateText(veh, 'ADMIN')
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)
    TriggerServerEvent('takeadmin:selfLog', 'Fahrzeug gespawnt: ' .. model)
end

function VehicleMenu()
    local items = {
        Button('Fahrzeug spawnen', 'Modellnamen eingeben (z. B. adder).', function()
            local model = KeyboardInput('Fahrzeugmodell', '', 30)
            if model then SpawnVehicle(model) end
        end),
        List('Schnellauswahl', 'Modell mit ←/→ wählen, Enter = spawnen.', Config.QuickVehicles, 1, function(_, model)
            SpawnVehicle(model)
        end),
        Separator(),
        Button('Reparieren', nil, function()
            local veh = getVehicle()
            if not veh then return end
            control(veh)
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 1000.0)
            SetVehiclePetrolTankHealth(veh, 1000.0)
            SetVehicleUndriveable(veh, false)
            SetVehicleEngineOn(veh, true, true, false)
            Notify('Fahrzeug repariert.', 'success')
        end),
        Button('Waschen', nil, function()
            local veh = getVehicle()
            if veh then control(veh); SetVehicleDirtLevel(veh, 0.0); WashDecalsFromVehicle(veh, 1.0) end
        end),
        Button('Umdrehen', nil, function()
            local veh = getVehicle()
            if not veh then return end
            control(veh)
            local r = GetEntityRotation(veh, 2)
            SetEntityRotation(veh, 0.0, 0.0, r.z, 2, true)
            SetVehicleOnGroundProperly(veh)
        end),
        Button('Max-Tuning', 'Alle Teile auf höchste Stufe, Turbo, Xenon.', function()
            local veh = getVehicle()
            if not veh then return end
            control(veh)
            SetVehicleModKit(veh, 0)
            for i = 0, 49 do
                local n = GetNumVehicleMods(veh, i)
                if n > 0 then SetVehicleMod(veh, i, n - 1, false) end
            end
            ToggleVehicleMod(veh, 18, true)
            ToggleVehicleMod(veh, 22, true)
            SetVehicleWindowTint(veh, 1)
            Notify('Fahrzeug getunt.', 'success')
        end),
        Button('Kennzeichen ändern', 'Max. 8 Zeichen.', function()
            local veh = getVehicle()
            if not veh then return end
            local plate = KeyboardInput('Kennzeichen', GetVehicleNumberPlateText(veh), 8)
            if plate then control(veh); SetVehicleNumberPlateText(veh, plate) end
        end),
        Checkbox('Fahrzeug unzerstörbar', 'Gilt für das Fahrzeug, in dem du sitzt.', Features.vehGod, function(s) SetVehGod(s) end),
        Button('~r~Fahrzeug löschen', 'Aktuelles oder nächstes Fahrzeug (6 m).', function()
            local veh = getVehicle()
            if veh then deleteVehicle(veh); Notify('Fahrzeug gelöscht.', 'success') end
        end),
    }
    return { subtitle = 'Fahrzeug-Optionen', items = items }
end

-- ================================================================ Server

function ServerMenu()
    local items = {}

    if Can('announce') then
        items[#items + 1] = Button('Ankündigung senden', 'Große Nachricht für alle Spieler.', function()
            local msg = KeyboardInput('Ankündigung', '', 400)
            if msg then DoAction('announce', nil, { message = msg }) end
        end)
    end
    if Can('weather') then
        items[#items + 1] = List('Wetter', '←/→ wählen, Enter = setzen. (Wetter-Sync-Skripte können überschreiben)', Config.Weather, 1, function(_, w)
            DoAction('weather', nil, { weather = w })
        end)
    end
    if Can('time') then
        local hours = {}
        for h = 0, 23 do hours[#hours + 1] = { label = ('%02d:00'):format(h), hour = h } end
        items[#items + 1] = List('Uhrzeit', '←/→ wählen, Enter = setzen.', hours, GetClockHours() + 1, function(_, h)
            DoAction('time', nil, { hour = h.hour })
        end)
    end
    if Can('cleanup') then
        local kinds = { { label = 'Fahrzeuge', kind = 'vehicles' }, { label = 'NPCs', kind = 'peds' }, { label = 'Objekte', kind = 'objects' } }
        items[#items + 1] = List('Aufräumen', 'Leere Fahrzeuge / NPCs / Objekte löschen (OneSync).', kinds, 1, function(_, k)
            Menu.Confirm('Alle ' .. k.label .. ' löschen?', function() DoAction('cleanup', nil, { kind = k.kind }) end)
        end)
    end
    if Can('reviveAll') then
        items[#items + 1] = Button('Alle wiederbeleben', nil, function()
            Menu.Confirm('Alle Spieler wiederbeleben?', function() DoAction('reviveAll') end)
        end)
    end
    if Can('bringAll') then
        items[#items + 1] = Button('Alle zu mir holen', nil, function()
            Menu.Confirm('Alle Spieler zu dir holen?', function() DoAction('bringAll') end)
        end)
    end
    if Can('kickAll') then
        items[#items + 1] = Button('~r~Alle kicken', 'Kickt alle außer Teammitgliedern.', function()
            local reason = KeyboardInput('Grund', 'Serverneustart', 200)
            if not reason then return end
            Menu.Confirm('Alle Spieler kicken?', function() DoAction('kickAll', nil, { reason = reason }) end)
        end)
    end
    if Can('restartRes') then
        items[#items + 1] = Button('Ressource neu starten', 'Name der Ressource eingeben.', function()
            local res = KeyboardInput('Ressourcenname', '', 80)
            if not res then return end
            Menu.Confirm(res .. ' neu starten?', function() DoAction('restartRes', nil, { resource = res }) end)
        end)
    end
    return { subtitle = 'Server-Verwaltung', items = items }
end
