local function loadPerms()
    local p = TriggerCallback('getPerms')
    if p then Perms = p end
    return p ~= nil
end

local function openAdminMenu()
    if not loadPerms() then return Notify('Server antwortet nicht.', 'error') end
    if Perms.locked then return Notify('TakeAdmin ist gesperrt: Das Menü-Banner wurde verändert.', 'error') end
    if not Can('menu') then return Notify('Du hast keine Berechtigung für das Admin-Menü.', 'error') end
    Menu.Open(MainMenu)
end

RegisterCommand(Config.Command, function()
    CreateThread(function()
        if Menu.open then Menu.Close() else openAdminMenu() end
    end)
end, false)
RegisterKeyMapping(Config.Command, 'TakeAdmin Menü öffnen', 'keyboard', Config.OpenKey)

-- Rechte beim Start laden (für Noclip-Taste ohne Menü)
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2000)
    loadPerms()
    SendNUIMessage({ action = 'init', position = Config.MenuPosition, accent = Config.AccentColor })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Features.noclip then SetNoclip(false) end
    if Features.spectating then StopSpectate() end
    SetBlips(false)
end)

TriggerEvent('chat:addSuggestion', '/' .. Config.ReportCommand, 'Report an das Team senden', { { name = 'Nachricht', help = 'Beschreibe dein Problem' } })
TriggerEvent('chat:addSuggestion', '/' .. Config.AdminChatCommand, 'Admin-Chat (nur Team)', { { name = 'Nachricht', help = 'Nachricht ans Team' } })
