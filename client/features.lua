Features = {
    noclip = false, godmode = false, invisible = false, stamina = false, superJump = false,
    fastRun = false, names = false, blips = false, coords = false, vehGod = false,
    spectating = nil,
}

-- ================================================================ Noclip

local noclipSpeeds = { 2.0, 8.0, 20.0, 45.0, 90.0 }
local noclipSpeed = 2

function SetNoclip(state)
    if state and not Can('noclip') then return Notify('Keine Berechtigung.', 'error') end
    Features.noclip = state
    local ped = PlayerPedId()
    local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    if not state then
        SetEntityCollision(ent, true, true)
        FreezeEntityPosition(ent, false)
        SetEntityInvincible(ent, Features.godmode)
        ResetEntityAlpha(ent)
        if not Features.invisible then SetEntityVisible(ped, true, false) end
        if ent ~= ped then SetEntityCollision(ped, true, true) end
    end
    Notify(state and 'Noclip an  (W/A/S/D, Q/E hoch/runter, Shift/Alt Tempo, Mausrad Stufe)' or 'Noclip aus', 'info')
end

CreateThread(function()
    while true do
        if Features.noclip then
            local ped = PlayerPedId()
            local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

            for _, c in ipairs({ 30, 31, 32, 33, 34, 35, 36, 21, 19, 44, 38, 22, 241, 242, 14, 15, 16, 17, 85 }) do
                DisableControlAction(0, c, true)
            end

            SetEntityCollision(ent, false, false)
            FreezeEntityPosition(ent, true)
            SetEntityInvincible(ent, true)
            SetEntityVelocity(ent, 0.0, 0.0, 0.0)
            SetEntityAlpha(ent, 120, false)
            SetEntityVisible(ped, false, false)
            SetEntityLocallyVisible(ped)

            if IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then
                noclipSpeed = math.min(#noclipSpeeds, noclipSpeed + 1)
            elseif IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then
                noclipSpeed = math.max(1, noclipSpeed - 1)
            end

            local speed = noclipSpeeds[noclipSpeed]
            if IsDisabledControlPressed(0, 21) then speed = speed * 3.0 end
            if IsDisabledControlPressed(0, 19) then speed = speed * 0.25 end
            speed = speed * GetFrameTime()

            local rot = GetGameplayCamRot(2)
            local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
            local fwd = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
            local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
            local delta = vector3(0.0, 0.0, 0.0)

            if IsDisabledControlPressed(0, 32) then delta = delta + fwd end
            if IsDisabledControlPressed(0, 33) then delta = delta - fwd end
            if IsDisabledControlPressed(0, 34) then delta = delta - right end
            if IsDisabledControlPressed(0, 35) then delta = delta + right end
            if IsDisabledControlPressed(0, 38) or IsDisabledControlPressed(0, 22) then delta = delta + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, 44) or IsDisabledControlPressed(0, 36) then delta = delta - vector3(0.0, 0.0, 1.0) end

            local pos = GetEntityCoords(ent) + delta * speed
            SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, true, true, true)
            SetEntityHeading(ent, rot.z)

            DrawText2D(0.5, 0.95, ('~b~NOCLIP~w~  Stufe %d/%d'):format(noclipSpeed, #noclipSpeeds), 0.35, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

RegisterCommand('+takeadmin_noclip', function()
    if not Can('noclip') then return end
    SetNoclip(not Features.noclip)
    TriggerServerEvent('takeadmin:selfLog', 'Noclip ' .. (Features.noclip and 'an' or 'aus'))
end, false)
RegisterCommand('-takeadmin_noclip', function() end, false)
RegisterKeyMapping('+takeadmin_noclip', 'TakeAdmin Noclip', 'keyboard', Config.NoclipKey)

-- ================================================================ Selbst-Optionen (pro Frame)

CreateThread(function()
    while true do
        local active = Features.godmode or Features.invisible or Features.stamina or Features.superJump
            or Features.names or Features.coords or Features.vehGod
        if active then
            local pid, ped = PlayerId(), PlayerPedId()

            if Features.godmode then
                SetEntityInvincible(ped, true)
                SetPlayerInvincible(pid, true)
                if GetEntityHealth(ped) < GetEntityMaxHealth(ped) then SetEntityHealth(ped, GetEntityMaxHealth(ped)) end
            end
            if Features.invisible then
                SetEntityVisible(ped, false, false)
                SetEntityLocallyVisible(ped)
                SetEntityAlpha(ped, 150, false)
            end
            if Features.stamina then RestorePlayerStamina(pid, 1.0) end
            if Features.superJump then SetSuperJumpThisFrame(pid) end
            if Features.vehGod then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 then
                    SetEntityInvincible(veh, true)
                    SetVehicleCanBeVisiblyDamaged(veh, false)
                    if GetVehicleEngineHealth(veh) < 1000.0 then SetVehicleFixed(veh) end
                end
            end

            if Features.coords then
                local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
                DrawText2D(0.5, 0.01, ('~y~X~w~ %.2f  ~y~Y~w~ %.2f  ~y~Z~w~ %.2f  ~y~H~w~ %.2f'):format(c.x, c.y, c.z, h), 0.42, true)
            end

            if Features.names then
                local myPos = GetEntityCoords(ped)
                for _, player in ipairs(GetActivePlayers()) do
                    local tped = GetPlayerPed(player)
                    if tped ~= ped then
                        local pos = GetEntityCoords(tped)
                        if #(myPos - pos) < 150.0 then
                            local talking = NetworkIsPlayerTalking(player)
                            local hp = math.max(0, GetEntityHealth(tped) - 100)
                            DrawText3D(pos + vector3(0.0, 0.0, 1.1),
                                ('[%d] %s\n~c~HP %d | Rüstung %d'):format(GetPlayerServerId(player), GetPlayerName(player), hp, GetPedArmour(tped)),
                                talking and 80 or 255, talking and 160 or 255, 255)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

function SetGodmode(state)
    Features.godmode = state
    if not state then
        SetEntityInvincible(PlayerPedId(), false)
        SetPlayerInvincible(PlayerId(), false)
    end
end

function SetInvisible(state)
    Features.invisible = state
    if not state then
        SetEntityVisible(PlayerPedId(), true, false)
        ResetEntityAlpha(PlayerPedId())
    end
end

function SetFastRun(state)
    Features.fastRun = state
    SetRunSprintMultiplierForPlayer(PlayerId(), state and 1.49 or 1.0)
    SetSwimMultiplierForPlayer(PlayerId(), state and 1.49 or 1.0)
end

function SetVehGod(state)
    Features.vehGod = state
    if not state then
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then
            SetEntityInvincible(veh, false)
            SetVehicleCanBeVisiblyDamaged(veh, true)
        end
    end
end

-- ================================================================ Spieler-Blips

local blips = {}

local function clearBlips()
    for _, b in pairs(blips) do RemoveBlip(b) end
    blips = {}
end

function SetBlips(state)
    Features.blips = state
    if not state then clearBlips() end
end

CreateThread(function()
    while true do
        if Features.blips then
            local list = TriggerCallback('getBlips') or {}
            local seen = {}
            for _, p in ipairs(list) do
                seen[p.id] = true
                local b = blips[p.id]
                if not b or not DoesBlipExist(b) then
                    b = AddBlipForCoord(p.x, p.y, p.z)
                    SetBlipCategory(b, 7)
                    SetBlipScale(b, 0.85)
                    SetBlipAsShortRange(b, false)
                    blips[p.id] = b
                end
                SetBlipCoords(b, p.x, p.y, p.z)
                SetBlipSprite(b, p.veh and 225 or 1)
                SetBlipColour(b, p.veh and 3 or 0)
                ShowHeadingIndicatorOnBlip(b, not p.veh)
                SetBlipRotation(b, math.floor(p.h))
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(('[%d] %s'):format(p.id, p.name))
                EndTextCommandSetBlipName(b)
            end
            for id, b in pairs(blips) do
                if not seen[id] then RemoveBlip(b); blips[id] = nil end
            end
            Wait(1500)
        else
            Wait(500)
        end
    end
end)

-- ================================================================ Spectate

local spectateReturn = nil

function StopSpectate()
    if not Features.spectating then return end
    Features.spectating = nil
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    if spectateReturn then
        SetEntityCoords(ped, spectateReturn.x, spectateReturn.y, spectateReturn.z, false, false, false, false)
        spectateReturn = nil
    end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    if not Features.invisible then SetEntityVisible(ped, true, false) end
    if not Features.godmode then SetEntityInvincible(ped, false) end
    TriggerServerEvent('takeadmin:resetBucket')
    Notify('Zuschauen beendet.', 'info')
end

function StartSpectate(target, name)
    if target == GetPlayerServerId(PlayerId()) then return Notify('Du kannst dir nicht selbst zuschauen.', 'error') end
    local coords = TriggerCallback('getCoords', target)
    if not coords then return Notify('Spieler nicht gefunden.', 'error') end

    local ped = PlayerPedId()
    if not Features.spectating then spectateReturn = GetEntityCoords(ped) end
    Features.spectating = target

    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 15.0, false, false, false, false)

    local player, tries = GetPlayerFromServerId(target), 0
    while (player == -1 or not DoesEntityExist(GetPlayerPed(player))) and tries < 50 do
        Wait(100)
        tries = tries + 1
        player = GetPlayerFromServerId(target)
    end
    if player == -1 then
        StopSpectate()
        return Notify('Spieler konnte nicht geladen werden.', 'error')
    end

    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    DoAction('spectate', target)
    Notify(('Du schaust %s zu. Erneut im Menü auswählen zum Beenden.'):format(name or target), 'info')

    CreateThread(function()
        while Features.spectating == target do
            local p = GetPlayerFromServerId(target)
            if p == -1 then
                StopSpectate()
                break
            end
            local tped = GetPlayerPed(p)
            local tc = GetEntityCoords(tped)
            SetEntityCoords(PlayerPedId(), tc.x, tc.y, tc.z - 15.0, false, false, false, false)
            for _ = 1, 50 do
                if Features.spectating ~= target then break end
                local hp = math.max(0, GetEntityHealth(tped) - 100)
                DrawText2D(0.5, 0.88, ('~b~ZUSCHAUEN~w~  [%d] %s  |  HP %d  Rüstung %d'):format(target, name or '', hp, GetPedArmour(tped)), 0.4, true)
                Wait(0)
            end
        end
    end)
end

-- ================================================================ Events vom Server

RegisterNetEvent('takeadmin:teleport', function(coords)
    TeleportTo(coords, false)
end)

RegisterNetEvent('takeadmin:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then FreezeEntityPosition(veh, state) end
    Notify(state and 'Du wurdest von einem Admin eingefroren.' or 'Du wurdest aufgetaut.', state and 'warning' or 'success')
end)

RegisterNetEvent('takeadmin:slap', function(power)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then TaskLeaveVehicle(ped, veh, 16) Wait(200) end
    SetPedToRagdoll(ped, 2000, 2000, 0, false, false, false)
    ApplyForceToEntity(ped, 1, math.random(-3, 3) * 1.0, math.random(-3, 3) * 1.0, 6.0 + power * 2.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - power * 8))
end)

RegisterNetEvent('takeadmin:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('takeadmin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    if Config.HealEvent ~= '' then TriggerEvent(Config.HealEvent, 'big') end
end)

RegisterNetEvent('takeadmin:revive', function()
    if Config.ReviveEvent ~= '' and GetResourceState(Config.ReviveEvent:match('^[^:]+') or '') == 'started' then
        TriggerEvent(Config.ReviveEvent)
        return
    end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
end)

local weatherTransition = false

RegisterNetEvent('takeadmin:setWeather', function(weather)
    weatherTransition = true
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypeOvertimePersist(weather, 15.0)
    SetTimeout(15000, function()
        SetWeatherTypeNowPersist(weather)
        SetOverrideWeather(weather)
        weatherTransition = false
    end)
end)

RegisterNetEvent('takeadmin:setTime', function(h, m)
    NetworkOverrideClockTime(h, m, 0)
end)

-- Admin-Uhrzeit festhalten (läuft normal weiter: 1 Ingame-Minute = 2 Sekunden).
-- Verhindert, dass Sync-Skripte die Zeit wieder auf Tag zurücksetzen.
CreateThread(function()
    while true do
        local t = GlobalState.takeadmin_time
        if t then
            local mins = (t.h * 60 + t.m + math.floor((GetCloudTimeAsInt() - t.t) / 2)) % 1440
            local h, m = mins // 60, mins % 60
            if GetClockHours() ~= h or GetClockMinutes() ~= m then
                NetworkOverrideClockTime(h, m, 0)
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- Admin-Wetter festhalten (auch für Spieler, die später joinen)
CreateThread(function()
    while true do
        Wait(1000)
        local w = GlobalState.takeadmin_weather
        if w and not weatherTransition and GetPrevWeatherTypeHashName() ~= joaat(w) then
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypeNowPersist(w)
            SetOverrideWeather(w)
        end
    end
end)

RegisterNetEvent('takeadmin:showScreenshot', function(data, name)
    Menu.overlay = true
    SendNUIMessage({ action = 'screenshot', image = data, name = name })
    Notify('Screenshot erhalten. Zurück-Taste schließt ihn.', 'success')
end)
