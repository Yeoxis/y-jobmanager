local QBCore = exports['qb-core']:GetCoreObject()

local ActiveSessions = {}

local function FormatTotalHours(totalSeconds)
    local hours = math.floor(totalSeconds / 3600)
    local mins = math.floor((totalSeconds % 3600) / 60)
    return string.format("%d hrs %d mins", hours, mins)
end

local function GetFormattedTime()
    local timestamp = os.time()
    local adjusted = timestamp + (Config.TimezoneOffset * 3600)
    return os.date("!%Y-%m-%d %H:%M:%S", adjusted) .. " " .. Config.TimezoneName
end

local function GetCurrentWeekStart()
    local now = os.time()
    local dateTable = os.date("*t", now)
    local daysSinceMonday = (dateTable.wday == 1) and 6 or (dateTable.wday - 2)
    local mondayTimestamp = now - (daysSinceMonday * 86400)
    return os.date("%Y-%m-%d", mondayTimestamp)
end

local function GetWebhook(jobName, webhookType)
    local jobCfg = Config.Jobs[jobName]
    if not jobCfg then return nil end
    
    if webhookType == 'timeclock' and jobCfg.timeclockwebhook and jobCfg.timeclockwebhook ~= "" then
        return jobCfg.timeclockwebhook
    elseif webhookType == 'bossmenu' and jobCfg.bossmenuwebhook and jobCfg.bossmenuwebhook ~= "" then
        return jobCfg.bossmenuwebhook
    end
    
    return nil
end

local function GetJobLabel(jobName)
    if Config.Jobs[jobName] and Config.Jobs[jobName].label then
        return Config.Jobs[jobName].label
    end
    return jobName
end

local function SendDiscordWebhook(webhook, embed)
    if not webhook then return end
    
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        username = Config.TimeclockWebhook.botName,
        avatar_url = Config.TimeclockWebhook.botAvatar ~= "" and Config.TimeclockWebhook.botAvatar or nil,
        embeds = { embed }
    }), { ['Content-Type'] = 'application/json' })
end

local function GetHoursData(citizenid, jobName, callback)
    local currentWeek = GetCurrentWeekStart()
    
    MySQL.query('SELECT total_seconds, weekly_seconds, DATE_FORMAT(week_start, "%Y-%m-%d") as week_start FROM y_timeclock WHERE citizenid = ? AND job = ?', 
        {citizenid, jobName}, 
        function(result)
            if result and result[1] then
                local data = result[1]
                local totalSecs = data.total_seconds or 0
                local weeklySecs = data.weekly_seconds or 0
                local storedWeek = data.week_start
                
                if storedWeek ~= currentWeek then
                    MySQL.execute('UPDATE y_timeclock SET weekly_seconds = 0, week_start = ? WHERE citizenid = ? AND job = ?',
                        {currentWeek, citizenid, jobName})
                    callback(totalSecs, 0)
                else
                    callback(totalSecs, weeklySecs)
                end
            else
                callback(0, 0)
            end
        end)
end

local function AddTimeToTotal(citizenid, jobName, seconds, callback)
    local currentWeek = GetCurrentWeekStart()
    
    MySQL.query('SELECT DATE_FORMAT(week_start, "%Y-%m-%d") as week_start FROM y_timeclock WHERE citizenid = ? AND job = ?',
        {citizenid, jobName},
        function(result)
            if result and result[1] then
                local storedWeek = result[1].week_start
                if storedWeek == currentWeek then
                    MySQL.execute('UPDATE y_timeclock SET total_seconds = total_seconds + ?, weekly_seconds = weekly_seconds + ? WHERE citizenid = ? AND job = ?',
                        {seconds, seconds, citizenid, jobName}, function()
                            if callback then callback() end
                        end)
                else
                    MySQL.execute('UPDATE y_timeclock SET total_seconds = total_seconds + ?, weekly_seconds = ?, week_start = ? WHERE citizenid = ? AND job = ?',
                        {seconds, seconds, currentWeek, citizenid, jobName}, function()
                            if callback then callback() end
                        end)
                end
            else
                MySQL.execute('INSERT INTO y_timeclock (citizenid, job, total_seconds, weekly_seconds, week_start) VALUES (?, ?, ?, ?, ?)',
                    {citizenid, jobName, seconds, seconds, currentWeek}, function()
                        if callback then callback() end
                    end)
            end
        end)
end

function HandleClockIn(source, jobName, gradeName, gradeLevel)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo
    local playerName = charinfo.firstname .. ' ' .. charinfo.lastname
    
    ActiveSessions[citizenid] = {
        job = jobName,
        clockInTime = os.time(),
        name = playerName,
        grade = gradeLevel,
        gradeName = gradeName
    }
    
    local webhook = GetWebhook(jobName, 'timeclock')
    if webhook then
        GetHoursData(citizenid, jobName, function(totalSecs, weeklySecs)
            local jobLabel = GetJobLabel(jobName)
            local weeklyTime = FormatTotalHours(weeklySecs)
            local totalTime = FormatTotalHours(totalSecs)
            
            local embed = {
                author = { name = jobLabel },
                color = Config.TimeclockWebhook.colors.clockIn,
                fields = {
                    { name = "Type", value = "Clock In", inline = true },
                    { name = "Employee", value = playerName, inline = true },
                    { name = "Role", value = gradeName, inline = true },
                    { name = "Hours This Week", value = weeklyTime, inline = true },
                    { name = "All Time Hours", value = totalTime, inline = true },
                },
                footer = { text = GetFormattedTime() },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            SendDiscordWebhook(webhook, embed)
        end)
    end
end

function HandleClockOut(source, jobName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local session = ActiveSessions[citizenid]
    
    -- If no session exists, still send webhook but with 0 session time
    if not session or session.job ~= jobName then
        -- Send webhook without session time
        local webhook = GetWebhook(jobName, 'timeclock')
        if webhook then
            GetHoursData(citizenid, jobName, function(totalSecs, weeklySecs)
                local charinfo = Player.PlayerData.charinfo
                local playerName = charinfo.firstname .. ' ' .. charinfo.lastname
                local gradeName = Player.PlayerData.job.grade.name
                
                local jobLabel = GetJobLabel(jobName)
                local weeklyTime = FormatTotalHours(weeklySecs)
                local totalTime = FormatTotalHours(totalSecs)
                
                local embed = {
                    author = { name = jobLabel },
                    color = Config.TimeclockWebhook.colors.clockOut,
                    fields = {
                        { name = "Type", value = "Clock Out", inline = true },
                        { name = "Employee", value = playerName, inline = true },
                        { name = "Role", value = gradeName, inline = true },
                        { name = "Hours This Week", value = weeklyTime, inline = true },
                        { name = "All Time Hours", value = totalTime, inline = true },
                    },
                    footer = { text = GetFormattedTime() },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
                SendDiscordWebhook(webhook, embed)
            end)
        end
        ActiveSessions[citizenid] = nil
        return
    end
    
    local clockOutTime = os.time()
    local duration = clockOutTime - session.clockInTime
    
    AddTimeToTotal(citizenid, jobName, duration, function()
        GetHoursData(citizenid, jobName, function(totalSecs, weeklySecs)
            local webhook = GetWebhook(jobName, 'timeclock')
            if webhook then
                local jobLabel = GetJobLabel(jobName)
                local weeklyTime = FormatTotalHours(weeklySecs)
                local totalTime = FormatTotalHours(totalSecs)
                
                local embed = {
                    author = { name = jobLabel },
                    color = Config.TimeclockWebhook.colors.clockOut,
                    fields = {
                        { name = "Type", value = "Clock Out", inline = true },
                        { name = "Employee", value = session.name, inline = true },
                        { name = "Role", value = session.gradeName, inline = true },
                        { name = "Hours This Week", value = weeklyTime, inline = true },
                        { name = "All Time Hours", value = totalTime, inline = true },
                    },
                    footer = { text = GetFormattedTime() },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
                SendDiscordWebhook(webhook, embed)
            end
        end)
    end)
    
    ActiveSessions[citizenid] = nil
end

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    if ActiveSessions[citizenid] and Player.PlayerData.job.onduty then
        HandleClockOut(source, Player.PlayerData.job.name)
    end
end)

exports('HandleClockIn', HandleClockIn)
exports('HandleClockOut', HandleClockOut)
