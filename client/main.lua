local ESX = exports['es_extended']:getSharedObject()
local isOpen = false
local isPlacing = false
local placingJobName = nil
local placingJobLabel = nil
local activePoints = {}

-- ── Panel ────────────────────────────────────────────────────────────────

local function togglePanel(open)
    isOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({
        action = 'setVisible',
        data = open
    })
end

local function openPanel()
    if isOpen then
        togglePanel(false)
        return
    end

    ESX.TriggerServerCallback('jobspanel:getData', function(data)
        if not data then return end
        SendNUIMessage({
            action = 'loadData',
            data = data
        })
        togglePanel(true)
    end)
end

RegisterCommand(Config.Command, function()
    openPanel()
end, false)

RegisterKeyMapping(Config.Command, 'Open Jobs Panel', 'keyboard', Config.Keybind)

RegisterNUICallback('close', function(_, cb)
    togglePanel(false)
    cb('ok')
end)

RegisterNUICallback('createJob', function(data, cb)
    ESX.TriggerServerCallback('jobspanel:createJob', function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('updateJob', function(data, cb)
    ESX.TriggerServerCallback('jobspanel:updateJob', function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('deleteJob', function(data, cb)
    ESX.TriggerServerCallback('jobspanel:deleteJob', function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('setPlayerJob', function(data, cb)
    ESX.TriggerServerCallback('jobspanel:setPlayerJob', function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('refreshData', function(_, cb)
    ESX.TriggerServerCallback('jobspanel:getData', function(data)
        cb(data)
    end)
end)

-- ── Boss Point Placement ─────────────────────────────────────────────────

local function getRaycastResult()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local forward = vector3(
        -math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
        math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
        math.sin(math.rad(camRot.x))
    )
    local dest = camCoords + forward * 50.0
    local handle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, 17, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(handle)
    return hit == 1, endCoords
end

local function startPlacement(jobName, jobLabel)
    if isPlacing then return end
    isPlacing = true
    placingJobName = jobName
    placingJobLabel = jobLabel

    togglePanel(false)

    lib.showTextUI('[LEFT CLICK] Place  |  [RIGHT CLICK] Cancel', { position = 'top-center' })

    CreateThread(function()
        while isPlacing do
            local hit, coords = getRaycastResult()
            if hit then
                DrawMarker(1, coords.x, coords.y, coords.z + 0.02, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.6, 66, 135, 245, 160, false, true, 2, false, nil, nil, false)
            end

            if IsControlJustPressed(0, 24) and hit then -- left click
                isPlacing = false
                lib.hideTextUI()
                ESX.TriggerServerCallback('jobspanel:createBossPoint', function(result)
                    if result.success then
                        lib.notify({ title = 'Boss Menu', description = 'Point placed for ' .. placingJobLabel, type = 'success' })
                    else
                        lib.notify({ title = 'Boss Menu', description = result.error or 'Failed to place point', type = 'error' })
                    end
                end, { jobName = placingJobName, x = coords.x, y = coords.y, z = coords.z })
            end

            if IsControlJustPressed(0, 25) then -- right click
                isPlacing = false
                lib.hideTextUI()
                lib.notify({ title = 'Boss Menu', description = 'Placement cancelled', type = 'inform' })
            end

            Wait(0)
        end
    end)
end

RegisterNUICallback('startBossPointPlacement', function(data, cb)
    cb('ok')
    startPlacement(data.jobName, data.jobLabel)
end)

RegisterNUICallback('deleteBossPoint', function(data, cb)
    ESX.TriggerServerCallback('jobspanel:deleteBossPoint', function(result)
        cb(result)
    end, data)
end)

-- ── Boss Point Interaction (ox_lib points) ───────────────────────────────

local function destroyAllPoints()
    for _, p in pairs(activePoints) do
        p:remove()
    end
    activePoints = {}
end

local function createBossPoints(points)
    destroyAllPoints()

    for _, bp in ipairs(points) do
        local point = lib.points.new({
            coords = vector3(bp.x, bp.y, bp.z),
            distance = 10.0,
            jobName = bp.jobName,
            id = bp.id,
        })

        function point:onEnter()
            local playerData = ESX.GetPlayerData()
            if playerData.job and playerData.job.name == self.jobName then
                lib.showTextUI('[E] Boss Menu', { position = 'right-center', icon = 'clipboard' })
            end
        end

        function point:onExit()
            lib.hideTextUI()
        end

        function point:nearby()
            DrawMarker(1, self.coords.x, self.coords.y, self.coords.z + 0.02, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.5, 66, 135, 245, 120, false, true, 2, false, nil, nil, false)

            if self.currentDistance < 2.0 and IsControlJustReleased(0, 38) then -- E key
                local playerData = ESX.GetPlayerData()
                if playerData.job and playerData.job.name == self.jobName then
                    TriggerEvent('esx_society:openBossMenu', self.jobName, function(data, menu)
                        menu.close()
                    end, { wash = false })
                end
            end
        end

        activePoints[bp.id] = point
    end
end

RegisterNetEvent('jobspanel:syncBossPoints', function(points)
    createBossPoints(points)
end)

CreateThread(function()
    Wait(2000)
    ESX.TriggerServerCallback('jobspanel:getBossPoints', function(points)
        if points then
            createBossPoints(points)
        end
    end)
end)
