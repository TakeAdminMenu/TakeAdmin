Perms = { level = 0, perms = {}, esx = false }

function Can(perm)
    return Perms.perms[perm] == true
end

-- ---------------------------------------------------------------- Callbacks

local cbId, pending = 0, {}

function TriggerCallback(name, ...)
    cbId = cbId + 1
    local id = cbId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('takeadmin:cb:request', name, id, ...)
    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ n = 0 })
        end
    end)
    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

RegisterNetEvent('takeadmin:cb:response', function(id, ...)
    local p = pending[id]
    if p then
        pending[id] = nil
        p:resolve(table.pack(...))
    end
end)

function DoAction(name, target, data)
    TriggerServerEvent('takeadmin:action', name, target, data or {})
end

-- ---------------------------------------------------------------- UI

function Notify(msg, nType)
    SendNUIMessage({ action = 'notify', text = msg, type = nType or 'info' })
end

RegisterNetEvent('takeadmin:notify', function(msg, nType)
    Notify(msg, nType)
    if nType == 'report' then PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true) end
end)

RegisterNetEvent('takeadmin:bigMessage', function(title, text, style)
    SendNUIMessage({ action = 'bigMessage', title = title, text = text, style = style })
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end)

function KeyboardInput(title, default, maxLen)
    AddTextEntry('TAKEADMIN_INPUT', title)
    DisplayOnscreenKeyboard(1, 'TAKEADMIN_INPUT', '', default or '', '', '', '', maxLen or 128)
    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Wait(0)
    end
    Menu.Cooldown()
    if UpdateOnscreenKeyboard() == 1 then
        local result = GetOnscreenKeyboardResult()
        if result and result ~= '' then return result end
    end
    return nil
end

function DrawText2D(x, y, text, scale, center)
    SetTextFont(4)
    SetTextScale(scale or 0.4, scale or 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextCentre(center == true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function DrawText3D(coords, text, r, g, b)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    local dist = #(GetGameplayCamCoord() - coords)
    local scale = math.max(0.25, 1.4 / dist * 2) * (1 / GetGameplayCamFov()) * 55
    scale = math.min(scale, 0.55)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

function TeleportTo(coords, findGround)
    local ped = PlayerPedId()
    local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end

    local x, y, z = coords.x, coords.y, coords.z
    SetEntityCoords(ent, x, y, z, false, false, false, false)
    if findGround then
        for height = 1000.0, 0.0, -25.0 do
            SetEntityCoordsNoOffset(ent, x, y, height, false, false, false)
            RequestCollisionAtCoord(x, y, height)
            Wait(20)
            local found, gz = GetGroundZFor_3dCoord(x, y, height, false)
            if found then
                z = gz + 1.0
                break
            end
        end
        SetEntityCoords(ent, x, y, z, false, false, false, false)
    else
        RequestCollisionAtCoord(x, y, z)
        local t = GetGameTimer() + 2000
        while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < t do Wait(0) end
    end
    DoScreenFadeIn(300)
end

function CopyToClipboard(text)
    SendNUIMessage({ action = 'copy', text = text })
    Notify('In Zwischenablage kopiert: ' .. text, 'success')
end
