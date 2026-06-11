local ESX = exports['es_extended']:getSharedObject()

local function isAdmin(source)
    return IsPlayerAceAllowed(source, Config.AcePermission)
end

-- ── Validation helpers ────────────────────────────────────────────────────
local MAX_RANKS = 30
local MAX_NAME_LEN = 50
local MAX_LABEL_LEN = 100
local MAX_DESC_LEN = 500
local MAX_SALARY = 10000000
local MAX_GRADE = 100
local MAX_IDENT_LEN = 80

local function validJobName(s)
    return type(s) == 'string' and #s >= 1 and #s <= MAX_NAME_LEN and s:match('^[%w_-]+$') ~= nil
end

local function validLabel(s, maxLen)
    return type(s) == 'string' and #s >= 1 and #s <= (maxLen or MAX_LABEL_LEN)
end

local function validDescription(s)
    return s == nil or (type(s) == 'string' and #s <= MAX_DESC_LEN)
end

local function validInt(n, lo, hi)
    if type(n) ~= 'number' then return false end
    if n ~= math.floor(n) then return false end
    return n >= lo and n <= hi
end

local function validRank(r)
    if type(r) ~= 'table' then return false end
    if not validLabel(r.name, MAX_NAME_LEN) then return false end
    -- label is optional; falls back to name when writing to DB
    if r.label ~= nil and not validLabel(r.label, MAX_LABEL_LEN) then return false end
    if not validInt(r.level, 0, MAX_GRADE) then return false end
    if not validInt(r.salary, 0, MAX_SALARY) then return false end
    return true
end

local function validRanks(ranks)
    if type(ranks) ~= 'table' then return false end
    local n = #ranks
    if n < 1 or n > MAX_RANKS then return false end
    local seenLevels = {}
    for _, r in ipairs(ranks) do
        if not validRank(r) then return false end
        if seenLevels[r.level] then return false end
        seenLevels[r.level] = true
    end
    return true
end

local function validIdentifier(s)
    return type(s) == 'string' and #s >= 1 and #s <= MAX_IDENT_LEN
end

-- ── Rate limiter ──────────────────────────────────────────────────────────
local MUTATE_COOLDOWN_MS = 500
local lastMutateAt = {}

local function checkRate(source)
    local now = GetGameTimer()
    local last = lastMutateAt[source] or 0
    if now - last < MUTATE_COOLDOWN_MS then return false end
    lastMutateAt[source] = now
    return true
end

AddEventHandler('playerDropped', function()
    lastMutateAt[source] = nil
end)

-- ── Discord webhook ───────────────────────────────────────────────────────
local ACTION_COLORS = {
    CREATE_JOB      = 3066993,  -- green
    UPDATE_JOB      = 3447003,  -- blue
    DELETE_JOB      = 15158332, -- red
    UPDATE_USER_JOB = 16776960, -- yellow
}

local function sendDiscord(adminName, action, description)
    local url = Config.DiscordWebhook
    if not url or url == '' then return end

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        embeds = {{
            title = action:gsub('_', ' '),
            description = description,
            color = ACTION_COLORS[action] or 3447003,
            footer = { text = 'Admin: ' .. adminName },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }}
    }), { ['Content-Type'] = 'application/json' })
end

-- ── FiveManage logging ───────────────────────────────────────────────────
local function sendFiveManage(adminName, action, description)
    local key = Config.FiveManageKey
    if not key or key == '' then return end

    PerformHttpRequest('https://api.fivemanage.com/api/logs', function() end, 'POST', json.encode({
        message = action .. ': ' .. description,
        metadata = { admin = adminName, action = action },
    }), { ['Content-Type'] = 'application/json', ['Authorization'] = key })
end

-- ── Logging ───────────────────────────────────────────────────────────────
local function addLog(source, action, description)
    local xPlayer = ESX.GetPlayerFromId(source)
    local adminName = xPlayer and xPlayer.getName() or 'Unknown'
    if type(description) == 'string' and #description > 8000 then
        description = description:sub(1, 8000) .. '...[truncated]'
    end
    MySQL.insert('INSERT INTO jobspanel_logs (admin_name, admin_identifier, action, description) VALUES (?, ?, ?, ?)', {
        adminName,
        xPlayer and xPlayer.getIdentifier() or 'unknown',
        action,
        description
    })
    sendDiscord(adminName, action, description)
    sendFiveManage(adminName, action, description)
end

-- ── Formatters ────────────────────────────────────────────────────────────
local function getFormattedJobs()
    local jobs = MySQL.query.await('SELECT * FROM jobs')
    local grades = MySQL.query.await('SELECT * FROM job_grades ORDER BY job_name, grade')

    local result = {}
    for _, job in ipairs(jobs) do
        local jobGrades = {}
        for _, grade in ipairs(grades) do
            if grade.job_name == job.name then
                local gradeName  = grade.name  or grade.label or ('grade_' .. grade.grade)
                local gradeLabel = grade.label or grade.name  or ('Grade ' .. grade.grade)
                table.insert(jobGrades, {
                    id = grade.job_name .. '_' .. grade.grade,
                    name = gradeName,
                    label = gradeLabel,
                    level = grade.grade,
                    salary = grade.salary or 0
                })
            end
        end
        table.insert(result, {
            id = job.name,
            name = job.name,
            label = job.label,
            description = '',
            ranks = jobGrades,
            createdAt = '',
            updatedAt = ''
        })
    end
    return result
end

local function getFormattedPlayers()
    local players = MySQL.query.await('SELECT identifier, firstname, lastname, job, job_grade FROM users')
    local jobs = MySQL.query.await('SELECT name, label FROM jobs')

    local jobLabels = {}
    for _, job in ipairs(jobs) do
        jobLabels[job.name] = job.label
    end

    local result = {}
    for _, player in ipairs(players) do
        table.insert(result, {
            id = player.identifier,
            name = (player.firstname or '') .. ' ' .. (player.lastname or ''),
            identifier = player.identifier,
            jobId = player.job ~= 'unemployed' and player.job or nil,
            jobLabel = jobLabels[player.job] or 'Unemployed',
            rankLevel = player.job_grade
        })
    end
    return result
end

local function getFormattedLogs()
    local logs = MySQL.query.await('SELECT * FROM jobspanel_logs ORDER BY created_at DESC LIMIT 200')
    local result = {}
    for _, log in ipairs(logs or {}) do
        table.insert(result, {
            id = tostring(log.id),
            action = log.action,
            description = log.description,
            user = log.admin_name,
            timestamp = log.created_at
        })
    end
    return result
end

-- ── Callbacks ─────────────────────────────────────────────────────────────
ESX.RegisterServerCallback('jobspanel:getData', function(source, cb)
    if not isAdmin(source) then cb(nil) return end
    cb({
        jobs = getFormattedJobs(),
        players = getFormattedPlayers(),
        logs = getFormattedLogs(),
        bossPoints = getFormattedBossPoints()
    })
end)

ESX.RegisterServerCallback('jobspanel:createJob', function(source, cb, data)
    if not isAdmin(source) then cb({ success = false, error = 'Unauthorized' }) return end
    if not checkRate(source) then cb({ success = false, error = 'Too many requests' }) return end
    if type(data) ~= 'table' then cb({ success = false, error = 'Invalid payload' }) return end
    if not validJobName(data.name) then cb({ success = false, error = 'Invalid job name (alphanumeric, _ or -, 1-50 chars)' }) return end
    if not validLabel(data.label) then cb({ success = false, error = 'Invalid label (1-100 chars)' }) return end
    if not validDescription(data.description) then cb({ success = false, error = 'Description too long' }) return end
    if not validRanks(data.ranks) then cb({ success = false, error = 'Invalid ranks (1-' .. MAX_RANKS .. ', unique levels, salary 0-' .. MAX_SALARY .. ')' }) return end

    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM jobs WHERE name = ?', { data.name })
    if existing > 0 then
        cb({ success = false, error = 'Job already exists' })
        return
    end

    local queries = { { 'INSERT INTO jobs (name, label) VALUES (?, ?)', { data.name, data.label } } }
    for _, rank in ipairs(data.ranks) do
        local rLabel = rank.label or rank.name
        queries[#queries + 1] = {
            'INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { data.name, rank.level, rank.name, rLabel, rank.salary, '{}', '{}' }
        }
    end

    local ok = MySQL.transaction.await(queries)
    if not ok then
        cb({ success = false, error = 'Database transaction failed' })
        return
    end

    ESX.RefreshJobs()
    addLog(source, 'CREATE_JOB', 'Created job: ' .. data.label .. ' (' .. data.name .. ')')
    cb({ success = true, jobs = getFormattedJobs() })
end)

ESX.RegisterServerCallback('jobspanel:updateJob', function(source, cb, data)
    if not isAdmin(source) then cb({ success = false, error = 'Unauthorized' }) return end
    if not checkRate(source) then cb({ success = false, error = 'Too many requests' }) return end
    if type(data) ~= 'table' then cb({ success = false, error = 'Invalid payload' }) return end
    if not validJobName(data.name) then cb({ success = false, error = 'Invalid job name' }) return end
    if not validLabel(data.label) then cb({ success = false, error = 'Invalid label' }) return end
    if not validDescription(data.description) then cb({ success = false, error = 'Description too long' }) return end
    if not validRanks(data.ranks) then cb({ success = false, error = 'Invalid ranks' }) return end

    local jobExists = MySQL.scalar.await('SELECT COUNT(*) FROM jobs WHERE name = ?', { data.name })
    if jobExists == 0 then
        cb({ success = false, error = 'Job not found' })
        return
    end

    local queries = {
        { 'UPDATE jobs SET label = ? WHERE name = ?', { data.label, data.name } },
        { 'DELETE FROM job_grades WHERE job_name = ?', { data.name } },
    }
    for _, rank in ipairs(data.ranks) do
        local rLabel = rank.label or rank.name
        queries[#queries + 1] = {
            'INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { data.name, rank.level, rank.name, rLabel, rank.salary, '{}', '{}' }
        }
    end

    local ok = MySQL.transaction.await(queries)
    if not ok then
        cb({ success = false, error = 'Database transaction failed' })
        return
    end

    ESX.RefreshJobs()
    addLog(source, 'UPDATE_JOB', 'Updated job: ' .. data.label .. ' (' .. data.name .. ')')
    cb({ success = true, jobs = getFormattedJobs() })
end)

ESX.RegisterServerCallback('jobspanel:deleteJob', function(source, cb, data)
    if not isAdmin(source) then cb({ success = false, error = 'Unauthorized' }) return end
    if not checkRate(source) then cb({ success = false, error = 'Too many requests' }) return end
    if type(data) ~= 'table' or not validJobName(data.name) then
        cb({ success = false, error = 'Invalid job name' })
        return
    end

    local job = MySQL.single.await('SELECT name, label FROM jobs WHERE name = ?', { data.name })
    if not job then
        cb({ success = false, error = 'Job not found' })
        return
    end

    if type(data.confirmLabel) ~= 'string' or data.confirmLabel ~= job.label then
        cb({ success = false, error = 'Confirmation label does not match' })
        return
    end

    local affected = MySQL.query.await('SELECT identifier, job_grade FROM users WHERE job = ?', { data.name }) or {}
    local snapshot = { job = data.name, label = job.label, users = {} }
    for i, u in ipairs(affected) do
        if i <= 100 then
            snapshot.users[#snapshot.users + 1] = { id = u.identifier, grade = u.job_grade }
        end
    end
    snapshot.totalAffected = #affected
    snapshot.snapshotCapped = #affected > 100

    local queries = {
        { 'UPDATE users SET job = ?, job_grade = ? WHERE job = ?', { 'unemployed', 0, data.name } },
        { 'DELETE FROM job_grades WHERE job_name = ?', { data.name } },
        { 'DELETE FROM jobs WHERE name = ?', { data.name } },
    }
    local ok = MySQL.transaction.await(queries)
    if not ok then
        cb({ success = false, error = 'Database transaction failed' })
        return
    end

    local xPlayers = ESX.GetExtendedPlayers('job', data.name)
    for _, xPlayer in pairs(xPlayers) do
        xPlayer.setJob('unemployed', 0)
    end

    ESX.RefreshJobs()
    addLog(source, 'DELETE_JOB', 'Deleted job: ' .. job.label .. ' | snapshot=' .. json.encode(snapshot))
    cb({ success = true, jobs = getFormattedJobs() })
end)

ESX.RegisterServerCallback('jobspanel:setPlayerJob', function(source, cb, data)
    if not isAdmin(source) then cb({ success = false, error = 'Unauthorized' }) return end
    if not checkRate(source) then cb({ success = false, error = 'Too many requests' }) return end
    if type(data) ~= 'table' or not validIdentifier(data.identifier) then
        cb({ success = false, error = 'Invalid identifier' })
        return
    end

    local jobName = data.jobName or 'unemployed'
    local grade = data.grade or 0

    if not (jobName == 'unemployed' or validJobName(jobName)) then
        cb({ success = false, error = 'Invalid job name' })
        return
    end
    if not validInt(grade, 0, MAX_GRADE) then
        cb({ success = false, error = 'Invalid grade' })
        return
    end

    if jobName ~= 'unemployed' then
        local gradeExists = MySQL.scalar.await(
            'SELECT COUNT(*) FROM job_grades WHERE job_name = ? AND grade = ?',
            { jobName, grade }
        )
        if gradeExists == 0 then
            cb({ success = false, error = 'Job or grade does not exist' })
            return
        end
    end

    local userExists = MySQL.scalar.await('SELECT COUNT(*) FROM users WHERE identifier = ?', { data.identifier })
    if userExists == 0 then
        cb({ success = false, error = 'Player not found' })
        return
    end

    MySQL.update.await('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {
        jobName, grade, data.identifier
    })

    local xTarget = ESX.GetPlayerFromIdentifier(data.identifier)
    if xTarget then
        xTarget.setJob(jobName, grade)
    end

    local jobLabel = MySQL.scalar.await('SELECT label FROM jobs WHERE name = ?', { jobName }) or 'Unemployed'
    addLog(source, 'UPDATE_USER_JOB', 'Set ' .. (data.playerName or 'player') .. ' [' .. data.identifier .. '] to ' .. jobLabel .. ' (grade ' .. grade .. ')')
    cb({ success = true, players = getFormattedPlayers() })
end)

-- ── Boss Points ──────────────────────────────────────────────────────────
local function getFormattedBossPoints()
    local points = MySQL.query.await('SELECT * FROM jobspanel_boss_points ORDER BY job_name, id')
    local result = {}
    for _, p in ipairs(points or {}) do
        result[#result + 1] = {
            id = p.id,
            jobName = p.job_name,
            x = p.x,
            y = p.y,
            z = p.z,
        }
    end
    return result
end

ESX.RegisterServerCallback('jobspanel:getBossPoints', function(source, cb)
    cb(getFormattedBossPoints())
end)

ESX.RegisterServerCallback('jobspanel:createBossPoint', function(source, cb, data)
    if not isAdmin(source) then cb({ success = false, error = 'Unauthorized' }) return end
    if not checkRate(source) then cb({ success = false, error = 'Too many requests' }) return end
    if type(data) ~= 'table' then cb({ success = false, error = 'Invalid payload' }) return end
    if not validJobName(data.jobName) then cb({ success = false, error = 'Invalid job name' }) return end
    if type(data.x) ~= 'number' or type(data.y) ~= 'number' or type(data.z) ~= 'number' then
        cb({ success = false, error = 'Invalid coordinates' })
        return
    end

    local jobExists = MySQL.scalar.await('SELECT COUNT(*) FROM jobs WHERE name = ?', { data.jobName })
    if jobExists == 0 then
        cb({ success = false, error = 'Job not found' })
        return
    end

    MySQL.insert.await(
        'INSERT INTO jobspanel_boss_points (job_name, x, y, z) VALUES (?, ?, ?, ?)',
        { data.jobName, data.x, data.y, data.z }
    )

    local points = getFormattedBossPoints()
    addLog(source, 'CREATE_BOSS_POINT', ('Created boss menu point for %s at %.1f, %.1f, %.1f'):format(data.jobName, data.x, data.y, data.z))
    TriggerClientEvent('jobspanel:syncBossPoints', -1, points)
    cb({ success = true, bossPoints = points })
end)

ESX.RegisterServerCallback('jobspanel:deleteBossPoint', function(source, cb, data)
    if not isAdmin(source) then cb({ success = false, error = 'Unauthorized' }) return end
    if not checkRate(source) then cb({ success = false, error = 'Too many requests' }) return end
    if type(data) ~= 'table' or not validInt(data.id, 1, 2147483647) then
        cb({ success = false, error = 'Invalid point ID' })
        return
    end

    local point = MySQL.single.await('SELECT * FROM jobspanel_boss_points WHERE id = ?', { data.id })
    if not point then
        cb({ success = false, error = 'Boss point not found' })
        return
    end

    MySQL.query.await('DELETE FROM jobspanel_boss_points WHERE id = ?', { data.id })

    local points = getFormattedBossPoints()
    addLog(source, 'DELETE_BOSS_POINT', ('Deleted boss menu point #%d for %s'):format(data.id, point.job_name))
    TriggerClientEvent('jobspanel:syncBossPoints', -1, points)
    cb({ success = true, bossPoints = points })
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS jobspanel_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            admin_name VARCHAR(50) NOT NULL,
            admin_identifier VARCHAR(60) NOT NULL,
            action VARCHAR(50) NOT NULL,
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS jobspanel_boss_points (
            id INT AUTO_INCREMENT PRIMARY KEY,
            job_name VARCHAR(50) NOT NULL,
            x FLOAT NOT NULL,
            y FLOAT NOT NULL,
            z FLOAT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY idx_boss_job (job_name)
        )
    ]])
end)
