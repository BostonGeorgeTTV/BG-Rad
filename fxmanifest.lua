fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'BostongeorgeTTV'
description 'Sistema radiazioni con ox_lib poly zones + NUI'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/radiation_icon.png',
    'html/sound/radiation_extreme.ogg',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}