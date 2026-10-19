fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'len_postjob'
author 'DeinName'
description 'Postal courier job with levels, uniform, cargo types, custom minigames and DE/EN locales'
version '4.0.0'

shared_scripts {
    'config.lua',
    'locales/locale.lua',
    'locales/de.lua',
    'locales/en.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'es_extended',
    'oxmysql',
    'skinchanger',
}
