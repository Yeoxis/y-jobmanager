fx_version 'cerulean'
game 'gta5'

author 'Yeox'
description 'Job Manager - Multi Job, Boss Menu, and Timeclock Tracking App for CodeM Phone v2'
version '1.1.3'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/timeclock.lua',
    'server/jobmanager.lua'
}

files {
    'ui/**/*'
}
