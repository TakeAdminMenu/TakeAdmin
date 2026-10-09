-- Schutz des Menü-Designs: Banner, HTML und CSS dürfen nicht verändert werden.
-- Weicht eine Datei vom Original ab, wird das Menü für alle Spieler gesperrt.

local PROTECTED = {
    { file = 'html/banner.png', hash = 0x86BCAA3E, text = false },
    { file = 'html/index.html', hash = 0x16A968AA, text = true },
    { file = 'html/style.css',  hash = 0x7D034B70, text = true },
}

-- FNV-1a (32 Bit)
local function checksum(data)
    local h = 0x811C9DC5
    for i = 1, #data, 4096 do
        local bytes = { data:byte(i, i + 4095) }
        for j = 1, #bytes do
            h = ((h ~ bytes[j]) * 16777619) & 0xFFFFFFFF
        end
    end
    return h
end

-- Binär direkt von der Platte lesen: LoadResourceFile bricht bei Binärdateien (PNG) am ersten Null-Byte ab
local function readFile(file)
    local path = GetResourcePath(GetCurrentResourceName())
    local f = path and io.open(path .. '/' .. file, 'rb')
    if f then
        local data = f:read('a')
        f:close()
        return data
    end
    return LoadResourceFile(GetCurrentResourceName(), file)
end

local broken = {}
for _, p in ipairs(PROTECTED) do
    local data = readFile(p.file)
    -- Zeilenenden ignorieren, damit Git unter Windows (CRLF) die Prüfung nicht bricht
    if data and p.text then data = data:gsub('\r', '') end
    local sum = data and checksum(data)
    if sum ~= p.hash then
        broken[#broken + 1] = p.file
        print(('^3[TakeAdmin] Prüfung %s: %s Bytes, Prüfsumme %s (erwartet %08X)^0'):format(
            p.file, data and #data or 'nicht gefunden', sum and ('%08X'):format(sum) or '-', p.hash))
    end
end

IntegrityOk = #broken == 0

if not IntegrityOk then
    local msg = '^1[TakeAdmin] Das Menü-Design wurde verändert (' .. table.concat(broken, ', ') ..
        '). Das Banner darf nicht geändert werden. Menü ist GESPERRT - Originaldateien wiederherstellen.^0'
    print(msg)
    CreateThread(function()
        while true do
            Wait(300000)
            print(msg)
        end
    end)
end
