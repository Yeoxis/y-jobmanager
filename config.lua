Config = {}

Config.AccentColor = '#a693ac'

-- Convert HexCodes To Decimal Here: https://www.binaryhexconverter.com/hex-to-decimal-converter

Config.TimeclockWebhook = {
    botName = 'Time Clock',
    botAvatar = 'https://your-image-url.png',
    colors = {
        clockIn = 3066993,   -- Green
        clockOut = 15158332, -- Red
    }
}

Config.BossMenuWebhook = {
    botName = 'Job Manager',
    botAvatar = 'https://your-image-url.png',
    colors = {
        hire = 3447003,      -- Blue
        fire = 15158332,     -- Red
        promote = 15844367,  -- Gold
        demote = 12745742,   -- Orange
        quit = 10038562,     -- Dark red
    }
}

Config.TimezoneOffset = -5
Config.TimezoneName = "EST"

--------------- JOB CONFIGURATION INFORMATION ---------------
--[[
! PERMISSIONS !
'hire' | hire anyone with server id or citizen id (qbcore)
'fire' | firing people of anyone below them. they cannot touch people at the same rank as them or below them.
'change_rank' | change rank of anyone below them. they cannot touch people at the same rank as them or below them.

'all' | this rank gives someone permission to do everything as well as move people up to ranks higher then them. i recommend only giving this to bosses to prevent exploitation.

perms = {} | will give no permissions to the defined ranks. they will only see their own jobs and not the boss menu option.

! ECT !
defining any grades you must put 'grades' as seen below in example. 'grade' will not work.
if you are doing multiple grades you will put them in {these, seperated, by, commas}
if you are doing a singluar grade you will just put the rank '5,'

any webhook can be disabled. the timeclock and bossmenu have an option to do different ones if you want to have the timeclock viewable by all employees and the boss actions only viewable by management or owners.
]]--

--------------- JOB CONFIGURATION EXAMPLE ---------------


--[[
['police'] = { -- job code
        label = 'Los Santos Police Department', -- job label that shows in the app and webhooks title
        icon  = '🚔', -- shows in the multijob menu
        permissions = {
            { grades = {0, 1}, perms = {} }, -- no permissions, will only see their job list
			{ grades = 2, perms = {'hire'} }, -- has access to hiring people
            { grades = 3, perms = {'hire', 'change_rank'} }, -- has access to hiring people and changing ranks of anyone below them
            { grades = 4, perms = {'hire', 'change_rank', 'fire'} }, -- has access to hiring, changing ranks, and firing anyone below them
            { grades = 5, perms = {'all'} }, -- has access to hiring, changing rank, and firing anyone, as well as promoting people to their rank and above
        },
        timeclockwebhook = 'YourDiscordWebhookLink', -- 'link' or nil
        bossmenuwebhook = nil, -- 'link' or nil
    },
]]--


Config.Jobs = {
    ['police'] = {
        label = 'Los Santos Police Department',
        icon  = '🚔',
        permissions = {
            { grades = {0, 1}, perms = {} },
			{ grades = 2, perms = {'hire'} },
            { grades = 3, perms = {'hire', 'change_rank'} },
            { grades = 4, perms = {'hire', 'change_rank', 'fire'} },
            { grades = 5, perms = {'all'} },
        },
        timeclockwebhook = 'YourDiscordWebhookLink', -- 'link' or nil
        bossmenuwebhook = nil, -- 'link' or nil
    },

    ['sheriff'] = {
        label = 'Blaine County Sheriff\'s Office',
        icon  = '🚓',
        permissions = {
            { grades = {0, 1}, perms = {} },
			{ grades = 2, perms = {'hire'} },
            { grades = 3, perms = {'hire', 'change_rank'} },
            { grades = 4, perms = {'hire', 'change_rank', 'fire'} },
            { grades = 5, perms = {'all'} },
        },
        timeclockwebhook = 'YourDiscordWebhookLink',
        bossmenuwebhook = nil,
    },

    -- Add as many as you want.

}
