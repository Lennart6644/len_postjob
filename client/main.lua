local ESX = exports['es_extended']:getSharedObject()

local shift = nil
local menuOpen = false
local actionBusy = false
local uniformOn = false
local savedSkin = nil
local bossPed = nil
local bossBlip = nil
local targetBlip = nil
local nearAction = nil
local shiftStartedAt = 0

local FROZEN_CONTROLS = { 21, 22, 23, 24, 25, 30, 31, 36, 44, 75, 140, 141, 142, 143 }
local NOTIFY_COLOR = { success = '~g~', error = '~r~', inform = '~b~' }

local function notify(kind, text)
    SetNotificationTextEntry('STRING')
    AddTextComponentString((NOTIFY_COLOR[kind] or '') .. text)
    DrawNotification(false, true)
end

local function serverCall(name, ...)
    local p = promise.new()
    ESX.TriggerServerCallback(name, function(result)
        p:resolve(result)
    end, ...)
    return Citizen.Await(p)
end

local function loadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
end

local function money(value)
    return ('%d %s'):format(value, Config.Currency)
end

local function dist(a, b)
    return #(a - b)
end

local function vehicleEntity()
    if not shift or not shift.vehicleNetId then return nil end
    if not NetworkDoesNetworkIdExist(shift.vehicleNetId) then return nil end
    local entity = NetworkGetEntityFromNetworkId(shift.vehicleNetId)
    if entity ~= 0 and DoesEntityExist(entity) then return entity end
    return nil
end

local function vehicleInRange()
    if not Config.Vehicle.enabled then return true end
    local entity = vehicleEntity()
    if not entity then return false end
    return dist(GetEntityCoords(entity), GetEntityCoords(PlayerPedId())) <= Config.Vehicle.maxDistance
end

local function currentTarget()
    if not shift then return nil end
    if shift.stage == 'pickup' then return Config.Pickups[shift.pickup], 'pickup' end
    if shift.stage == 'dropoff' then return Config.Dropoffs[shift.dropoff], 'dropoff' end
    return nil
end

local function cargoLabel(cargo)
    if not cargo then return nil end
    local key = ('cargo.%s.%s'):format(cargo.type, cargo.amount == 1 and 'singular' or 'plural')
    return ('%d × %s'):format(cargo.amount, L(key))
end

local function setTargetBlip(coords, stage)
    if targetBlip then
        RemoveBlip(targetBlip)
        targetBlip = nil
    end
    if not coords then return end
    local style = Config.Blips[stage]
    targetBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(targetBlip, style.sprite)
    SetBlipColour(targetBlip, style.color)
    SetBlipScale(targetBlip, style.scale)
    SetBlipRoute(targetBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(L('blip_' .. stage))
    EndTextCommandSetBlipName(targetBlip)
end

local function setShift(state)
    shift = {
        stage        = state.stage,
        pickup       = state.pickup,
        dropoff      = state.dropoff,
        cargo        = state.cargo,
        deliveries   = state.deliveries,
        earned       = state.earned,
        vehicleNetId = state.vehicleNetId,
    }
    local target, stage = currentTarget()
    setTargetBlip(target, stage)
end

local function clearShift()
    shift = nil
    setTargetBlip(nil)
    SendNUIMessage({ action = 'hud', show = false })
end

local function sendHud(distance)
    SendNUIMessage({
        action = 'hud',
        show = true,
        data = {
            stage      = shift.stage,
            distance   = distance,
            cargo      = cargoLabel(shift.cargo),
            deliveries = shift.deliveries,
            earned     = shift.earned,
            elapsed    = math.floor((GetGameTimer() - shiftStartedAt) / 1000),
            vehicleFar = not vehicleInRange(),
        },
    })
end

local function setPrompt(action, text)
    if action == nearAction then return end
    nearAction = action
    SendNUIMessage({ action = 'prompt', text = text })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'menu', show = false })
end

local function buildMenu(data)
    data.rank = L(data.rankKey)
    data.uniformOn = uniformOn
    data.uniformEnabled = Config.Uniform.enabled
    return data
end

local function pushMenu()
    local data = serverCall('len_postjob:getState')
    if not data then
        notify('error', L('err_no_job'))
        closeMenu()
        return false
    end
    SendNUIMessage({ action = 'menu', show = true, data = buildMenu(data) })
    return true
end

local function openMenu()
    if menuOpen or not pushMenu() then return end
    menuOpen = true
    SetNuiFocus(true, true)
end

local function refreshMenu()
    if menuOpen then pushMenu() end
end

local function handlePayout(res)
    SendNUIMessage({
        action = 'payout',
        data = {
            payout  = res.payout,
            tip     = res.tip,
            xp      = res.xp,
            levelUp = res.levelUp,
            rank    = res.rankKey and L(res.rankKey) or nil,
        },
    })
    if res.levelUp then
        notify('success', L('levelup', res.levelUp, L(res.rankKey)))
    end
end

local function startShift()
    if shift then return end
    local res = serverCall('len_postjob:startShift')
    if not res or not res.ok then
        notify('error', L(res and res.reason or 'err_db'))
        return
    end
    setShift(res.shift)
    shiftStartedAt = GetGameTimer()
    notify('success', L('shift_started'))
end

local function endShift()
    if not shift then return end
    local res = serverCall('len_postjob:endShift')
    if not res or not res.ok then
        notify('error', L(res and res.reason or 'err_db'))
        return
    end
    clearShift()
    notify('inform', L('shift_ended', res.deliveries, money(res.earned)))
end

local function toggleUniform()
    if not Config.Uniform.enabled then return end
    if uniformOn then
        if savedSkin then TriggerEvent('skinchanger:loadSkin', savedSkin) end
        savedSkin = nil
        uniformOn = false
        notify('inform', L('uniform_off'))
        return
    end
    TriggerEvent('skinchanger:getSkin', function(skin)
        savedSkin = skin
        local outfit = skin.sex == 1 and Config.Outfits.female or Config.Outfits.male
        TriggerEvent('skinchanger:loadClothes', skin, outfit)
        uniformOn = true
        notify('inform', L('uniform_on'))
    end)
end

local function triangle(t)
    local p = t % 2
    if p <= 1 then return p end
    return 2 - p
end

local function runSkillcheck()
    local cfg = Config.Minigame.skillcheck
    for round = 1, cfg.rounds do
        local zoneStart = math.random() * (1 - cfg.zoneWidth)
        local zoneEnd = zoneStart + cfg.zoneWidth
        local speed = cfg.speed * (1 + (round - 1) * cfg.speedStep)
        SendNUIMessage({
            action = 'skill',
            show = true,
            round = round,
            rounds = cfg.rounds,
            zoneStart = zoneStart,
            zoneEnd = zoneEnd,
        })

        local started = GetGameTimer()
        local result = nil
        while result == nil do
            Wait(0)
            local pos = triangle((GetGameTimer() - started) / 1000 * speed)
            SendNUIMessage({ action = 'skillPos', pos = pos })
            if IsControlJustPressed(0, Config.Minigame.key) then
                result = (pos >= zoneStart and pos <= zoneEnd) and 'hit' or 'miss'
            elseif IsControlJustPressed(0, Config.Minigame.cancelKey) then
                result = 'cancel'
            end
        end

        if result ~= 'hit' then
            SendNUIMessage({ action = 'skill', show = false })
            return result
        end
    end
    SendNUIMessage({ action = 'skill', show = false })
    return 'hit'
end

local function runProgress(label, duration)
    SendNUIMessage({ action = 'progress', show = true, label = label, duration = duration })
    local started = GetGameTimer()
    local cancelled = false
    while GetGameTimer() - started < duration do
        Wait(0)
        for _, control in ipairs(FROZEN_CONTROLS) do
            DisableControlAction(0, control, true)
        end
        if IsControlJustPressed(0, Config.Minigame.cancelKey) then
            cancelled = true
            break
        end
    end
    SendNUIMessage({ action = 'progress', show = false })
    return not cancelled
end

local function runStage(stage)
    if actionBusy or not shift then return end
    if not vehicleInRange() then
        notify('error', L('err_vehicle_far'))
        return
    end

    actionBusy = true
    local outcome = runSkillcheck()
    if outcome ~= 'hit' then
        actionBusy = false
        if outcome == 'cancel' then
            notify('inform', L('action_cancelled'))
        else
            notify('error', L('skill_failed'))
        end
        return
    end

    local ped = PlayerPedId()
    local netId = shift.vehicleNetId
    TaskStartScenarioInPlace(ped, Config.Anim.scenario, 0, true)
    local completed = runProgress(L('progress_' .. stage), Config.ProgressTime)
    ClearPedTasks(ped)
    if not completed then
        actionBusy = false
        notify('inform', L('action_cancelled'))
        return
    end

    local res = serverCall('len_postjob:' .. stage, netId)
    actionBusy = false
    if not shift then return end
    if not res or not res.ok then
        notify('error', L(res and res.reason or 'err_db'))
        return
    end

    setShift(res.shift)
    if stage == 'dropoff' then handlePayout(res) end
end

local function syncFromServer()
    local data = serverCall('len_postjob:getState')
    if data and data.shift and data.shift.stage and not shift then
        setShift(data.shift)
        shiftStartedAt = GetGameTimer()
    end
end

local function setupBoss()
    local model = GetHashKey(Config.Boss.ped)
    loadModel(model)
    local c = Config.Boss.coords
    bossPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, Config.Boss.heading, false, false)
    SetEntityInvincible(bossPed, true)
    SetBlockingOfNonTemporaryEvents(bossPed, true)
    FreezeEntityPosition(bossPed, true)
    TaskStartScenarioInPlace(bossPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(model)

    bossBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(bossBlip, Config.Boss.blip.sprite)
    SetBlipColour(bossBlip, Config.Boss.blip.color)
    SetBlipScale(bossBlip, Config.Boss.blip.scale)
    SetBlipAsShortRange(bossBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(L('blip_boss'))
    EndTextCommandSetBlipName(bossBlip)
end

RegisterNUICallback('ready', function(_, cb)
    cb({
        locale       = Config.Locale,
        numberLocale = Config.Locale == 'de' and 'de-DE' or 'en-US',
        currency     = Config.Currency,
        interactKey  = Config.InteractKey,
        minigameKey  = Config.Minigame.keyLabel,
        cancelLabel  = Config.Minigame.cancelLabel,
        xpEnabled    = Config.XPSystem,
        strings      = UIStrings(),
    })
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    closeMenu()
end)

RegisterNUICallback('toggleShift', function(_, cb)
    cb('ok')
    CreateThread(function()
        if shift then endShift() else startShift() end
        refreshMenu()
    end)
end)

RegisterNUICallback('toggleUniform', function(_, cb)
    cb('ok')
    CreateThread(function()
        toggleUniform()
        refreshMenu()
    end)
end)

RegisterCommand('+len_postjob_interact', function()
    if menuOpen or actionBusy then return end
    CreateThread(function()
        if nearAction == 'boss' then
            openMenu()
        elseif nearAction == 'pickup' or nearAction == 'dropoff' then
            runStage(nearAction)
        end
    end)
end, false)

RegisterCommand('-len_postjob_interact', function() end, false)
RegisterKeyMapping('+len_postjob_interact', L('keymap_desc'), 'keyboard', Config.InteractKey)

CreateThread(function()
    while true do
        local wait = 500
        local action, text
        if not menuOpen then
            local pos = GetEntityCoords(PlayerPedId())
            if dist(pos, Config.Boss.coords) <= Config.InteractDistance then
                action, text = 'boss', L('prompt_boss')
            end
            if shift then
                local target, stage = currentTarget()
                if target then
                    local d = dist(pos, target)
                    wait = d <= 40.0 and 200 or 500
                    if not action and d <= Config.InteractDistance and not actionBusy then
                        action, text = stage, L('prompt_' .. stage)
                    end
                    sendHud(d)
                end
            end
        end
        setPrompt(action, text)
        Wait(wait)
    end
end)

CreateThread(function()
    setupBoss()
    Wait(2000)
    syncFromServer()
end)

AddEventHandler('esx:playerLoaded', function()
    CreateThread(syncFromServer)
end)

AddEventHandler('esx:onPlayerLogout', function()
    clearShift()
    closeMenu()
    uniformOn = false
    savedSkin = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if bossPed and DoesEntityExist(bossPed) then DeletePed(bossPed) end
    if bossBlip then RemoveBlip(bossBlip) end
    if targetBlip then RemoveBlip(targetBlip) end
    if menuOpen then SetNuiFocus(false, false) end
end)
