Config = {}

-- 'esx' = ESX Legacy (Gruppen, Geld, Jobs, Items) | 'standalone' = nur ACE-Rechte
Config.Framework = 'esx'

-- Befehl + Standardtaste zum Öffnen (Taste kann jeder Spieler in den GTA-Einstellungen ändern)
Config.Command   = 'takeadmin'
Config.OpenKey   = 'F2'
Config.NoclipKey = 'F3'

-- Menü-Seite: 'left' oder 'right'
Config.MenuPosition = 'left'

-- Akzentfarbe des Menüs (Auswahl, Leisten, Regler) als Hex
Config.AccentColor = '#3b82f6'

-- Rang-Level je Gruppe. Höheres Level = mehr Rechte.
-- ESX: Gruppe kommt von xPlayer.getGroup()
-- ACE: add_ace group.admin takeadmin.admin allow   (Name nach "takeadmin." = Gruppenname hier)
Config.Groups = {
    ['leitung'] = 100,
    ['dev']      = 100,
    ['verwaltung']        = 80,
    ['administrator']    = 80,
    ['moderator'] = 50,
    ['supporter'] = 20,
    ['guide'] = 20,
}
Config.UseAce = true

-- Mindest-Level pro Funktion
Config.Permissions = {
    menu           = 20,

    -- Spieler
    kick           = 20,
    ban            = 50,
    offlineBan     = 50,
    unban          = 80,
    warn           = 20,
    mute           = 20,
    spectate       = 20,
    ['goto']       = 20,
    bring          = 20,
    slap           = 50,
    freeze         = 20,
    screenshot     = 20,
    heal           = 20,
    revive         = 20,
    kill           = 80,
    dm             = 20,
    playerInfo     = 20,

    -- ESX
    giveMoney      = 100,
    setJob         = 80,
    setGroup       = 100,
    giveItem       = 80,
    clearInventory = 80,

    -- Selbst
    noclip         = 20,
    godmode        = 50,
    invisible      = 50,
    selfOptions    = 20,
    playerNames    = 20,
    playerBlips    = 50,

    -- Fahrzeug
    vehicle        = 50,

    -- Server
    announce       = 50,
    weather        = 80,
    time           = 80,
    cleanup        = 80,
    reviveAll      = 80,
    bringAll       = 100,
    kickAll        = 100,
    restartRes     = 100,
    banList        = 50,
    reports        = 20,
    adminChat      = 20,
}

Config.BanDurations = {
    { label = '1 Stunde',  time = 3600 },
    { label = '6 Stunden', time = 21600 },
    { label = '12 Stunden',time = 43200 },
    { label = '1 Tag',     time = 86400 },
    { label = '3 Tage',    time = 259200 },
    { label = '1 Woche',   time = 604800 },
    { label = '2 Wochen',  time = 1209600 },
    { label = '1 Monat',   time = 2592000 },
    { label = 'Permanent', time = 0 },
}

-- Speicherort für Banns & Verwarnungen:
-- 'auto'  = MySQL über oxmysql, falls vorhanden, sonst JSON
-- 'mysql' = immer MySQL (Tabellen werden automatisch erstellt)
-- 'json'  = data/bans.json (ACHTUNG: beim Neu-Kopieren des Ordners überschrieben!)
Config.Storage = 'auto'

-- Text, der gebannten Spielern beim Verbinden angezeigt wird
Config.BanAppeal = 'Entbannungsantrag auf unserem Discord.'
-- IP-Adressen mit bannen (kann bei geteilten Netzen Unschuldige treffen)
Config.BanIP = false

-- Verwarnungen: ab dieser Anzahl automatische Strafe
Config.MaxWarns   = 3
Config.WarnAction = 'ban'      -- 'kick' oder 'ban'
Config.WarnBanTime = 86400     -- Sekunden (0 = permanent)

-- ESX-Events (leer lassen = eingebaute Variante wird benutzt)
Config.ReviveEvent = 'esx_ambulancejob:revive'
Config.HealEvent   = 'esx_basicneeds:healPlayer'

Config.Accounts = {
    { label = 'Bargeld',     name = 'money' },
    { label = 'Bank',        name = 'bank' },
    { label = 'Schwarzgeld', name = 'black_money' },
}

Config.QuickVehicles = {
    'adder', 't20', 'zentorno', 'sultanrs', 'kuruma2', 'police', 'police3',
    'ambulance', 'firetruk', 'sanchez', 'bati', 'buzzard2', 'frogger', 'dinghy'
}

Config.Weather = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY',
    'RAIN', 'THUNDER', 'CLEARING', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'HALLOWEEN'
}

-- Anzahl der zuletzt getrennten Spieler, die für Offline-Banns gemerkt werden
Config.RecentPlayers = 30

-- Report-Befehl für Spieler und Admin-Chat-Befehl
Config.ReportCommand    = 'report'
Config.AdminChatCommand = 'a'
Config.ReportCooldown   = 60 -- Sekunden
