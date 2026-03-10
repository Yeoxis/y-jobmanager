-- ═══════════════════════════════════════════════════════════════
-- y-jobmanager | Server
-- ═══════════════════════════════════════════════════════════════

local QBCore = exports['qb-core']:GetCoreObject()



-- ── Preprocess config permissions ─────────────────────────────────
for jobName, jobCfg in pairs(Config.Jobs) do
    if jobCfg.permissions then
        local grades = {}
        for _, perm in ipairs(jobCfg.permissions) do
            -- Support both single number and array
            local gradeList = type(perm.grades) == "table" and perm.grades or {perm.grades}
            for _, g in ipairs(gradeList) do
                grades[g] = perm.perms
            end
        end
        jobCfg.grades = grades
        jobCfg.permissions = nil
    end
end

-- ── Helper: Get player jobs from multijobs table ──────────────────
local function GetPlayerJobs(citizenid)
    local result = MySQL.scalar.await('SELECT jobdata FROM multijobs WHERE citizenid = ?', { citizenid })
    if result then
        local success, jobs = pcall(json.decode, result)
        if success and jobs then return jobs end
    end
    return {}
end

-- ── Helper: Check if player can see boss menu ──────────────────────
local function CanSeeBossMenu(jobName, grade)
    if not jobName or jobName == 'unemployed' then return false end
    
    local jobCfg = Config.Jobs[jobName]
    if not jobCfg or not jobCfg.grades then return false end
    
    local perms = jobCfg.grades[grade]
    
    if not perms then return false end
    
    -- Check if they have any permissions
    for _, perm in ipairs(perms) do
        if perm == 'all' or perm == 'hire' or perm == 'fire' or perm == 'change_rank' then
            return true
        end
    end
    
    return false
end

local function GetFormattedTime()
    local timestamp = os.time()
    local adjusted = timestamp + (Config.TimezoneOffset * 3600)
    return os.date("!%Y-%m-%d %H:%M:%S", adjusted) .. " " .. Config.TimezoneName
end

local function GetJobLabel(jobName)
    if Config.Jobs[jobName] and Config.Jobs[jobName].label then
        return Config.Jobs[jobName].label
    end
    return jobName
end

local function SendBossMenuWebhook(jobName, action, data)
    local jobCfg = Config.Jobs[jobName]
    if not jobCfg or not jobCfg.bossmenuwebhook or jobCfg.bossmenuwebhook == "" then return end
    
    local jobLabel = GetJobLabel(jobName)
    local color = Config.BossMenuWebhook.colors[action] or 16777215
    
    local embed = {
        author = { name = jobLabel },
        color = color,
        fields = data.fields,
        footer = { text = GetFormattedTime() },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    PerformHttpRequest(jobCfg.bossmenuwebhook, function(err, text, headers) end, 'POST', json.encode({
        username = Config.BossMenuWebhook.botName,
        avatar_url = Config.BossMenuWebhook.botAvatar ~= "" and Config.BossMenuWebhook.botAvatar or nil,
        embeds = { embed }
    }), { ['Content-Type'] = 'application/json' })
end

-- ── Helper: Get permissions for grade ──────────────────────────────
local function GetPermissions(jobName, grade)
    local jobCfg = Config.Jobs[jobName]
    if not jobCfg or not jobCfg.grades then return {} end
    
    local perms = jobCfg.grades[grade]
    if not perms then return {} end
    
    local result = {
        canHire = false,
        canFire = false,
        canChangeRank = false
    }
    
    for _, perm in ipairs(perms) do
        if perm == 'all' then
            result.canHire = true
            result.canFire = true
            result.canChangeRank = true
            return result
        elseif perm == 'hire' then
            result.canHire = true
        elseif perm == 'fire' then
            result.canFire = true
        elseif perm == 'change_rank' then
            result.canChangeRank = true
        end
    end
    
    return result
end

-- ── Helper: Save player jobs to multijobs table ────────────────────
local function SavePlayerJobs(citizenid, jobs)
    -- Use REPLACE to ensure no duplicates
    MySQL.query.await('REPLACE INTO multijobs (citizenid, jobdata) VALUES (?, ?)', { 
        citizenid, 
        json.encode(jobs) 
    })
end

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Init
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:init', function(source, payload, cb)
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        return cb({ success = false }) 
    end

    local pd = Player.PlayerData
    local jobName = pd.job and pd.job.name or 'unemployed'
    local grade = pd.job and pd.job.grade.level or 0

    -- Build job list
    local jobList = {}
    for name, cfg in pairs(Config.Jobs) do
        local sharedJob = QBCore.Shared.Jobs[name]
        if sharedJob then
            local grades = {}
            for gradeLevel, gradeData in pairs(sharedJob.grades) do
                table.insert(grades, {
                    level = tonumber(gradeLevel),
                    label = gradeData.name
                })
            end
            table.sort(grades, function(a, b) return a.level < b.level end)
            table.insert(jobList, {
                name = name,
                label = cfg.label,
                icon = cfg.icon,
                grades = grades
            })
        end
    end

    -- Get player's jobs
    local playerJobs = {}
    local multiJobsData = GetPlayerJobs(pd.citizenid)
    
    -- Auto-add active job to multijobs if it's missing (from /setjob or other commands)
    if jobName ~= 'unemployed' and not multiJobsData[jobName] then
        multiJobsData[jobName] = grade
        SavePlayerJobs(pd.citizenid, multiJobsData)
    end
    
    for jName, jGrade in pairs(multiJobsData) do
        local jobCfg = Config.Jobs[jName]
        local sharedJob = QBCore.Shared.Jobs[jName]
        if jobCfg and sharedJob then
            local gradeLabel = (sharedJob.grades[tostring(jGrade)] and sharedJob.grades[tostring(jGrade)].name) or 'Employee'
            table.insert(playerJobs, {
                name = jName,
                grade = jGrade,
                gradeLabel = gradeLabel
            })
        end
    end

    cb({
        success = true,
        currentJob = jobName,
        currentGradeLevel = grade,
        currentGradeLabel = pd.job and pd.job.grade.name or '',
        onDuty = pd.job and pd.job.onduty or false,
        canSeeBossMenu = CanSeeBossMenu(jobName, grade),
        jobs = jobList,
        playerJobs = playerJobs,
        accentColor = Config.AccentColor or '#e8a628'
    })
end)

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Switch job
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:switchJob', function(source, payload, cb)
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        return cb({ success = false }) 
    end

    local cjob = payload.job
    local cgrade = payload.grade


    if cjob == "unemployed" and cgrade == 0 then
        Player.Functions.SetJob(cjob, cgrade)
        return cb({ 
            success = true, 
            gradeLevel = 0,
            gradeLabel = 'Unemployed',
            onDuty = false,
            canSeeBossMenu = false
        })
    end

    local jobs = GetPlayerJobs(Player.PlayerData.citizenid)
    
    for job, grade in pairs(jobs) do
        if cjob == job and tonumber(cgrade) == tonumber(grade) then
            Player.Functions.SetJob(job, tonumber(grade))
            
            -- Get updated job info
            local sharedJob = QBCore.Shared.Jobs[job]
            local gradeData = sharedJob and sharedJob.grades[tostring(grade)]
            local gradeLabel = gradeData and gradeData.name or 'Employee'
            local onDuty = Player.PlayerData.job.onduty or false
            
            
            local canSeeBossMenu = CanSeeBossMenu(job, grade)
            
            
            return cb({ 
                success = true,
                gradeLevel = grade,
                gradeLabel = gradeLabel,
                onDuty = onDuty,
                canSeeBossMenu = canSeeBossMenu
            })
        end
    end
    
    cb({ success = false, error = 'You do not have this job' })
end)

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Toggle duty
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:toggleDuty', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false }) end
    
    local newDutyState = not Player.PlayerData.job.onduty
    
    Player.PlayerData.job.onduty = newDutyState
    Player.Functions.SetPlayerData("job", Player.PlayerData.job)
    
    -- Trigger client events
    TriggerClientEvent('QBCore:Client:SetDuty', source, newDutyState)
    TriggerClientEvent('QBCore:Client:OnJobUpdate', source, Player.PlayerData.job)
    
    -- Handle timeclock logging
    local jobName = Player.PlayerData.job.name
    local gradeName = Player.PlayerData.job.grade.name
    local gradeLevel = Player.PlayerData.job.grade.level
    
    if newDutyState then
        exports['y-jobmanager']:HandleClockIn(source, jobName, gradeName, gradeLevel)
    else
        exports['y-jobmanager']:HandleClockOut(source, jobName)
    end
    
    cb({ success = true, onDuty = newDutyState })
end)

-- ══════════════════════════════════════════════════════════════════
-- SERVER EVENT: Change job
-- ══════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════
-- SERVER EVENT: Toggle duty
-- ══════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Get employees
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:getEmployees', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false }) end
    
    local jobName = Player.PlayerData.job.name
    local myRank = Player.PlayerData.job.grade.level
    local perms = GetPermissions(jobName, myRank)
    
    local employees = {}
    
    -- Get all players who have this job in multijobs
    local result = MySQL.query.await('SELECT citizenid, jobdata FROM multijobs', {})
    
    for _, row in ipairs(result) do
        local jobs = json.decode(row.jobdata)
        if jobs and jobs[jobName] then
            -- This player has the job, get their info
            local playerInfo = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', { row.citizenid })
            if playerInfo[1] then
                local charinfo = json.decode(playerInfo[1].charinfo)
                local grade = jobs[jobName]
                local sharedJob = QBCore.Shared.Jobs[jobName]
                local gradeLabel = (sharedJob.grades[tostring(grade)] and sharedJob.grades[tostring(grade)].name) or 'Employee'
                
                -- Show ALL employees, mark if they're manageable
                -- 'all' perms can manage anyone, others can only manage lower
                local hasAllPerms = perms.canFire and perms.canChangeRank and perms.canHire
                local canManage = hasAllPerms or (grade < myRank)
                
                -- Check if player is online and on duty
                local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(row.citizenid)
                local onDuty = false
                if TargetPlayer and TargetPlayer.PlayerData.job.name == jobName then
                    onDuty = TargetPlayer.PlayerData.job.onduty or false
                end
                
                table.insert(employees, {
                    citizenid = row.citizenid,
                    name = charinfo.firstname .. ' ' .. charinfo.lastname,
                    grade = grade,
                    gradeLabel = gradeLabel,
                    canManage = canManage,
                    onDuty = onDuty
                })
            end
        end
    end
    
    -- Build grades list for dropdown
    -- 'all' perms can see all ranks, others only up to their own
    local grades = {}
    local sharedJob = QBCore.Shared.Jobs[jobName]
    local hasAllPerms = perms.canFire and perms.canChangeRank and perms.canHire
    
    if sharedJob then
        for gradeLevel, gradeData in pairs(sharedJob.grades) do
            local level = tonumber(gradeLevel)
            -- If 'all' perms, show all grades. Otherwise only up to your rank.
            if hasAllPerms or level <= myRank then
                table.insert(grades, {
                    level = level,
                    label = gradeData.name
                })
            end
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
    end
    
    cb({ success = true, employees = employees, permissions = perms, grades = grades })
end)

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Hire player
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:hire', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false, error = 'Player not found' }) end
    
    local jobName = Player.PlayerData.job.name
    local perms = GetPermissions(jobName, Player.PlayerData.job.grade.level)
    
    if not perms.canHire then
        return cb({ success = false, error = 'No permission' })
    end
    
    local targetId = payload.targetId
    local TargetPlayer = nil
    local targetCitizenid = nil
    
    -- Try as server ID first
    if tonumber(targetId) then
        TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
        if TargetPlayer then
            targetCitizenid = TargetPlayer.PlayerData.citizenid
        end
    end
    
    -- If not found, try as citizenid
    if not targetCitizenid then
        targetCitizenid = targetId
        TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenid)
    end
    
    -- Verify citizenid exists in database
    local exists = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', { targetCitizenid })
    if not exists then
        return cb({ success = false, error = 'Player not found' })
    end
    
    -- Check if they already have this job
    local jobs = GetPlayerJobs(targetCitizenid)
    if jobs[jobName] then
        return cb({ success = false, error = 'Player already has this job' })
    end
    
    -- Add to multijobs
    jobs[jobName] = 0
    SavePlayerJobs(targetCitizenid, jobs)
    
    -- Get player name from database
    local playerInfo = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', { targetCitizenid })
    local charinfo = json.decode(playerInfo[1].charinfo)
    local employeeName = charinfo.firstname .. ' ' .. charinfo.lastname
    
    -- Get grade label
    local sharedJob = QBCore.Shared.Jobs[jobName]
    local gradeLabel = (sharedJob.grades['0'] and sharedJob.grades['0'].name) or 'Employee'
    
    -- If player is online, set as active job
    if TargetPlayer then
        TargetPlayer.Functions.SetJob(jobName, 0)
    end
    
    -- Call callback first
    cb({ 
        success = true, 
        employee = {
            citizenid = targetCitizenid,
            name = employeeName,
            grade = 0,
            gradeLabel = gradeLabel
        }
    })
    
    -- Send webhook (async, after callback)
    local hirer = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    SendBossMenuWebhook(jobName, 'hire', {
        fields = {
            { name = "Action", value = "Hired", inline = true },
            { name = "Employee", value = employeeName, inline = true },
            { name = "Rank", value = gradeLabel, inline = true },
            { name = "Hired By", value = hirer .. ' (' .. Player.PlayerData.job.grade.name .. ')', inline = false },
        }
    })
end)

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Fire employee
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:fire', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false, error = 'Player not found' }) end
    
    local jobName = Player.PlayerData.job.name
    local perms = GetPermissions(jobName, Player.PlayerData.job.grade.level)
    
    if not perms.canFire then
        return cb({ success = false, error = 'No permission' })
    end
    
    local citizenid = payload.citizenid
    local jobs = GetPlayerJobs(citizenid)
    local targetGrade = jobs[jobName]
    
    -- If you have 'all' perms, can fire anyone. Otherwise only lower.
    local hasAllPerms = perms.canFire and perms.canChangeRank and perms.canHire
    if not hasAllPerms and targetGrade >= Player.PlayerData.job.grade.level then
        return cb({ success = false, error = 'Cannot fire someone with equal or higher rank' })
    end
    
    jobs[jobName] = nil
    
    SavePlayerJobs(citizenid, jobs)
    
    -- Verify it saved
    local verifyJobs = GetPlayerJobs(citizenid)
    
    -- If player is online and has this as active job
    local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if TargetPlayer and TargetPlayer.PlayerData.job.name == jobName then
        -- Find another job or set to unemployed
        local nextJob = nil
        local nextGrade = nil
        for jName, jGrade in pairs(jobs) do
            nextJob = jName
            nextGrade = jGrade
            break
        end
        
        if nextJob then
            TargetPlayer.Functions.SetJob(nextJob, nextGrade)
        else
            TargetPlayer.Functions.SetJob('unemployed', 0)
        end
    end
    
    -- Get fired employee name
    local playerInfo = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    local charinfo = json.decode(playerInfo[1].charinfo)
    local employeeName = charinfo.firstname .. ' ' .. charinfo.lastname
    
    -- Call callback first
    cb({ success = true })
    
    -- Send webhook (async, after callback)
    local firer = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    SendBossMenuWebhook(jobName, 'fire', {
        fields = {
            { name = "Action", value = "Fired", inline = true },
            { name = "Employee", value = employeeName, inline = true },
            { name = "Fired By", value = firer .. ' (' .. Player.PlayerData.job.grade.name .. ')', inline = false },
        }
    })
end)

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Change grade
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:changeGrade', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false, error = 'Player not found' }) end
    
    local jobName = Player.PlayerData.job.name
    local perms = GetPermissions(jobName, Player.PlayerData.job.grade.level)
    
    if not perms.canChangeRank then
        return cb({ success = false, error = 'No permission' })
    end
    
    local citizenid = payload.citizenid
    local newGrade = tonumber(payload.newGrade)
    local myRank = Player.PlayerData.job.grade.level
    
    -- Get current grade
    local jobs = GetPlayerJobs(citizenid)
    local currentGrade = jobs[jobName] or 0
    
    -- If you have 'all' perms, can manage anyone and promote to any rank
    -- Otherwise, can only promote up to your rank and manage lower ranks
    local hasAllPerms = perms.canFire and perms.canChangeRank and perms.canHire
    if not hasAllPerms then
        if newGrade > myRank then
            return cb({ success = false, error = 'Cannot promote above your own rank' })
        end
        if currentGrade >= myRank then
            return cb({ success = false, error = 'Cannot change rank of equal or higher ranked employee' })
        end
    end
    
    -- Update multijobs
    jobs[jobName] = newGrade
    SavePlayerJobs(citizenid, jobs)
    
    -- Get grade label
    local sharedJob = QBCore.Shared.Jobs[jobName]
    local gradeLabel = (sharedJob.grades[tostring(newGrade)] and sharedJob.grades[tostring(newGrade)].name) or 'Employee'
    
    -- If player is online and has this as active job, update it
    local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if TargetPlayer and TargetPlayer.PlayerData.job.name == jobName then
        TargetPlayer.Functions.SetJob(jobName, newGrade)
    end
    
    -- Get employee name and old grade label
    local playerInfo = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    local charinfo = json.decode(playerInfo[1].charinfo)
    local employeeName = charinfo.firstname .. ' ' .. charinfo.lastname
    local oldGradeLabel = (sharedJob.grades[tostring(currentGrade)] and sharedJob.grades[tostring(currentGrade)].name) or 'Employee'
    
    -- Determine if promote or demote
    local action = newGrade > currentGrade and 'promote' or 'demote'
    
    -- Call callback first to prevent timeout
    cb({ success = true, newGradeLabel = gradeLabel })
    
    -- Send webhook (async, after callback)
    local changer = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    SendBossMenuWebhook(jobName, action, {
        fields = {
            { name = "Action", value = action == 'promote' and "Promoted" or "Demoted", inline = true },
            { name = "Employee", value = employeeName, inline = true },
            { name = "Previous Rank", value = oldGradeLabel, inline = true },
            { name = "New Rank", value = gradeLabel, inline = true },
            { name = "Changed By", value = changer .. ' (' .. Player.PlayerData.job.grade.name .. ')', inline = false },
        }
    })
end)

-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Quit job
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:quitJob', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        return cb({ success = false, error = 'Player not found' }) 
    end
    
    local jobName = Player.PlayerData.job.name
    
    if jobName == 'unemployed' then
        return cb({ success = false, error = 'You are unemployed' })
    end
    
    -- Remove from multijobs
    local jobs = GetPlayerJobs(Player.PlayerData.citizenid)
    jobs[jobName] = nil
    SavePlayerJobs(Player.PlayerData.citizenid, jobs)
    
    -- Find another job or set to unemployed
    local nextJob = nil
    local nextGrade = nil
    for jName, jGrade in pairs(jobs) do
        nextJob = jName
        nextGrade = jGrade
        break
    end
    
    if nextJob then
        Player.Functions.SetJob(nextJob, nextGrade)
    else
        Player.Functions.SetJob('unemployed', 0)
    end
    
    -- Call callback first
    cb({ success = true })
    
    -- Send webhook (async, after callback)
    local employeeName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    SendBossMenuWebhook(jobName, 'quit', {
        fields = {
            { name = "Action", value = "Quit", inline = true },
            { name = "Employee", value = employeeName, inline = true },
            { name = "Rank", value = Player.PlayerData.job.grade.name, inline = true },
        }
    })
end)



-- ══════════════════════════════════════════════════════════════════
-- CODEM-PHONE CALLBACK: Get hours for current job
-- ══════════════════════════════════════════════════════════════════
AddEventHandler('codem-phone:customApp:y-jobmanager:getHours', function(source, payload, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false }) end
    
    local jobName = Player.PlayerData.job.name
    local citizenid = Player.PlayerData.citizenid
    
    -- Get current week start
    local now = os.time()
    local dateTable = os.date('*t', now)
    
    local currentDay = dateTable.wday
    local weekStartDay = Config.WeekStartDay or 2
    
    local daysSinceWeekStart
    if currentDay >= weekStartDay then
        daysSinceWeekStart = currentDay - weekStartDay
    else
        daysSinceWeekStart = (7 - weekStartDay) + currentDay
    end
    
    local weekStartTimestamp = now - (daysSinceWeekStart * 86400)
    local currentWeek = os.date('%Y-%m-%d', weekStartTimestamp)
    
    -- Get hours from database
    local result = MySQL.query.await('SELECT total_seconds, weekly_seconds, DATE_FORMAT(week_start, "%Y-%m-%d") as week_start FROM y_timeclock WHERE citizenid = ? AND job = ?', {citizenid, jobName})
    
    if result and result[1] then
        local data = result[1]
        local totalSecs = data.total_seconds or 0
        local weeklySecs = data.weekly_seconds or 0
        local storedWeek = data.week_start
        
        -- Check if week rolled over
        if storedWeek ~= currentWeek then
            weeklySecs = 0
        end
        
        -- Format to hours and minutes
        local totalHours = math.floor(totalSecs / 3600)
        local totalMins = math.floor((totalSecs % 3600) / 60)
        local weeklyHours = math.floor(weeklySecs / 3600)
        local weeklyMins = math.floor((weeklySecs % 3600) / 60)
        
        cb({ 
            success = true,
            totalHours = totalHours,
            totalMins = totalMins,
            weeklyHours = weeklyHours,
            weeklyMins = weeklyMins
        })
    else
        -- No data yet
        cb({ success = true, totalHours = 0, totalMins = 0, weeklyHours = 0, weeklyMins = 0 })
    end
end)
