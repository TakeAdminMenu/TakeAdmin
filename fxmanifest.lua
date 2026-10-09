fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'TakeAdmin'
author 'TakeAdmin'
description 'TakeAdmin - Admin-Menü mit ESX-Support'
version '1.0.1'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/menu.lua',
    'client/features.lua',
    'client/menus.lua',
    'client/main.lua'
}

server_scripts {
    'server/sv_config.lua',
    'server/integrity.lua',
    'server/utils.lua',
    'server/bans.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/banner.png',
    'html/fonts/*.woff2'
}

-- Für FiveM Asset Escrow: diese Dateien bleiben lesbar und bearbeitbar
escrow_ignore {
    'config.lua',
    'server/sv_config.lua'
}
