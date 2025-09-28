fx_version 'cerulean'
game 'gta5'

name 'vx_bins'
author 'VX'
description 'Grab-a-bag bin searching using ox_lib UI + progress, ox_target, ox_inventory, QBCore metadata rep, and Discord webhook.'
version '1.9.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    '@lation_ui/init.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- remove if unused
    'server/main.lua'
}

server_exports {
    'GetScavRep',
    'AddScavRep',
    'SetScavRep'
}

lua54 'yes'
