-- Menü-Engine: Lua hält den Zustand, die NUI zeichnet nur.
Menu = { open = false, stack = {}, blockUntil = 0, overlay = false }

local function current() return Menu.stack[#Menu.stack] end

-- ---------------------------------------------------------------- Item-Helfer

function Button(label, desc, onSelect, right)
    return { type = 'button', label = label, desc = desc, onSelect = onSelect, right = right }
end

function Sub(label, desc, builder, ...)
    return { type = 'submenu', label = label, desc = desc, submenu = builder, args = table.pack(...) }
end

function Checkbox(label, desc, checked, onChange)
    return { type = 'checkbox', label = label, desc = desc, checked = checked == true, onChange = onChange }
end

-- options: Liste von Strings oder { label = ... }
function List(label, desc, options, index, onSelect, onChange)
    return { type = 'list', label = label, desc = desc, options = options, index = index or 1, onSelect = onSelect, onChange = onChange }
end

function Slider(label, desc, value, max, onSelect, onChange)
    return { type = 'slider', label = label, desc = desc, value = value or 0, max = max or 10, onSelect = onSelect, onChange = onChange }
end

function Separator(label)
    return { type = 'separator', label = label or '' }
end

-- ---------------------------------------------------------------- Rendering

local function optionLabel(opt)
    return type(opt) == 'table' and opt.label or tostring(opt)
end

function Menu.Render()
    local m = current()
    if not m then return end
    local items = {}
    for i, it in ipairs(m.items) do
        items[i] = {
            type    = it.type,
            label   = it.label,
            right   = it.right,
            checked = it.checked,
            list    = it.type == 'list' and it.options[it.index] and optionLabel(it.options[it.index]) or nil,
            value   = it.value,
            max     = it.max,
            color   = it.color,
        }
    end
    local sel = m.items[m.index]
    local parent = Menu.stack[#Menu.stack - 1]
    SendNUIMessage({
        action      = 'menu',
        title       = m.title,
        subtitle    = m.subtitle,
        parent      = parent and parent.subtitle:gsub('%s*•.*$', '') or 'TakeAdmin',
        items       = items,
        index       = m.index,
        description = sel and sel.desc or nil,
    })
end

local function prepare(m, builder, args)
    m.builder, m.args = builder, args
    m.items = m.items or {}
    m.title = m.title or 'TakeAdmin'
    m.subtitle = m.subtitle or ''
    return m
end

local function firstSelectable(m, from, dir)
    local n = #m.items
    if n == 0 then return 1 end
    local i = from
    for _ = 1, n do
        if m.items[i] and m.items[i].type ~= 'separator' then return i end
        i = ((i - 1 + dir) % n) + 1
    end
    return from
end

function Menu.Push(builder, ...)
    local args = table.pack(...)
    local m = builder(table.unpack(args, 1, args.n))
    if not m then return end
    prepare(m, builder, args)
    m.index = firstSelectable(m, 1, 1)
    Menu.stack[#Menu.stack + 1] = m
    Menu.Render()
end

function Menu.Refresh()
    local m = current()
    if not m or not m.builder then return end
    local new = m.builder(table.unpack(m.args, 1, m.args.n))
    if not new then return end
    prepare(new, m.builder, m.args)
    new.index = firstSelectable(new, math.max(1, math.min(m.index, #new.items)), -1)
    Menu.stack[#Menu.stack] = new
    Menu.Render()
end

function Menu.Back()
    if Menu.overlay then
        Menu.overlay = false
        SendNUIMessage({ action = 'hideScreenshot' })
        return
    end
    PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if #Menu.stack <= 1 then
        Menu.Close()
        return
    end
    Menu.stack[#Menu.stack] = nil
    local parent = current()
    if parent.refresh then Menu.Refresh() else Menu.Render() end
end

-- n Ebenen zurück (z. B. nach Bann zurück zur Spielerliste)
function Menu.BackTo(levels)
    for _ = 1, levels do
        if #Menu.stack > 1 then Menu.stack[#Menu.stack] = nil end
    end
    Menu.Refresh()
end

function Menu.Open(builder)
    Menu.open = true
    Menu.stack = {}
    SendNUIMessage({ action = 'show', position = Config.MenuPosition, accent = Config.AccentColor })
    Menu.Push(builder)
    Menu.Cooldown()
end

function Menu.Close()
    Menu.open = false
    Menu.stack = {}
    Menu.overlay = false
    SendNUIMessage({ action = 'hide' })
    SendNUIMessage({ action = 'hideScreenshot' })
end

function Menu.Cooldown(ms)
    Menu.blockUntil = GetGameTimer() + (ms or 200)
end

-- Bestätigungs-Untermenü
function Menu.Confirm(text, onYes)
    Menu.Push(function()
        return {
            subtitle = text,
            items = {
                Button('~r~Bestätigen', 'Aktion ausführen: ' .. text, function()
                    Menu.Back()
                    onYes()
                end),
                Button('Abbrechen', nil, function() Menu.Back() end),
            }
        }
    end)
end

-- ---------------------------------------------------------------- Eingabe

local function move(dir)
    local m = current()
    if not m or #m.items == 0 then return end
    local n = #m.items
    m.index = ((m.index - 1 + dir) % n) + 1
    m.index = firstSelectable(m, m.index, dir)
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    Menu.Render()
end

local function side(dir)
    local m = current()
    local it = m and m.items[m.index]
    if not it then return end
    if it.type == 'list' and #it.options > 0 then
        it.index = ((it.index - 1 + dir) % #it.options) + 1
        if it.onChange then it.onChange(it.index, it.options[it.index], it) end
    elseif it.type == 'slider' then
        it.value = math.max(0, math.min(it.max, it.value + dir))
        if it.onChange then it.onChange(it.value, it) end
    else
        return
    end
    PlaySoundFrontend(-1, 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    Menu.Render()
end

local function select()
    local m = current()
    local it = m and m.items[m.index]
    if not it or it.type == 'separator' then return end
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

    if it.type == 'submenu' then
        Menu.Push(it.submenu, table.unpack(it.args, 1, it.args.n))
    elseif it.type == 'checkbox' then
        it.checked = not it.checked
        Menu.Render()
        if it.onChange then it.onChange(it.checked, it) end
    elseif it.type == 'list' then
        if it.onSelect then it.onSelect(it.index, it.options[it.index], it) end
    elseif it.type == 'slider' then
        if it.onSelect then it.onSelect(it.value, it) end
    elseif it.onSelect then
        it.onSelect(it)
    end
end

local disabled = { 27, 24, 25, 140, 141, 142, 257, 263, 264, 199, 200, 37, 44, 85, 172, 173, 174, 175, 176, 177, 18, 191, 201 }

CreateThread(function()
    local nextRepeat, repeatDir = 0, 0
    while true do
        if Menu.open then
            for i = 1, #disabled do DisableControlAction(0, disabled[i], true) end

            if GetGameTimer() >= Menu.blockUntil and not IsPauseMenuActive() then
                local now = GetGameTimer()
                if IsDisabledControlJustPressed(0, 172) then
                    move(-1); repeatDir = -1; nextRepeat = now + 350
                elseif IsDisabledControlJustPressed(0, 173) then
                    move(1); repeatDir = 1; nextRepeat = now + 350
                elseif repeatDir ~= 0 and IsDisabledControlPressed(0, repeatDir == -1 and 172 or 173) then
                    if now >= nextRepeat then move(repeatDir); nextRepeat = now + 70 end
                else
                    repeatDir = 0
                end

                if IsDisabledControlJustPressed(0, 174) then side(-1)
                elseif IsDisabledControlJustPressed(0, 175) then side(1)
                elseif IsDisabledControlJustPressed(0, 176) or IsDisabledControlJustPressed(0, 191) then select()
                elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 202) then Menu.Back()
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
