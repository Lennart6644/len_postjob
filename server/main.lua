local ESX = exports['es_extended']:getSharedObject()

local Shifts = {}
local StatsCache = {}

local function dbSingle(query, params)
    return exports.oxmysql:single_async(query, params)
end

local function dbUpdate(query, params)
    return exports.oxmysql:update_async(query, params)
end

local function dbInsert(query, params)
    return exports.oxmysql:insert_async(query, params)
end

local function serverCallback(name, handler)
    ESX.RegisterServerCallback(name, function(source, cb, ...)
        local args = table.pack(...)
        CreateThread(function()
            handler(source, cb, table.unpack(args, 1, args.n))
        end)
    end)
end

local function randomBetween(range)
    return math.random(range[1], range[2])
end

local function weightedPick(items)
    local total = 0
    for _, item in ipairs(items) do total = total + item.weight end
    local roll = math.random() * total
    for _, item in ipairs(items) do
        roll = roll - item.weight
        if roll <= 0 then return item end
    end
    return items[#items]
end

local function getStats(identifier)
    local cached = StatsCache[identifier]
    if cached then return cached end
    local row = dbSingle(
        'SELECT level, xp, deliveries, earned FROM len_postjob_stats WHERE identifier = ?',
        { identifier }
    )
    local stats = row and {
        level      = row.level,
        xp         = row.xp,
        deliveries = row.deliveries,
        earned     = row.earned,
    } or { level = 1, xp = 0, deliveries = 0, earned = 0 }
    StatsCache[identifier] = stats
    return stats
end

local function saveStats(identifier, stats)
    dbUpdate([[
        INSERT INTO len_postjob_stats (identifier, level, xp, deliveries, earned)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            level = VALUES(level),
            xp = VALUES(xp),
            deliveries = VALUES(deliveries),
            earned = VALUES(earned)
    ]], { identifier, stats.level, stats.xp, stats.deliveries, stats.earned })
end

local function logDelivery(identifier, cargo, payout, tip, xp)
    if not Config.Logging then return end
    dbInsert(
        'INSERT INTO len_postjob_logs (identifier, cargo, amount, payout, tip, xp) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, cargo.type, cargo.amount, payout, tip, xp }
    )
end

local function getRankData(level)
    if not Config.XPSystem then level = 1 end
    local current = Config.Ranks[1]
    for _, rank in ipairs(Config.Ranks) do
        if level >= rank.level then current = rank end
    end
    return current
end

local function getBonus(level)
    if not Config.XPSystem then return 0 end
    return math.min(Config.Level.maxBonus, (level - 1) * Config.Level.bonusPerLevel)
end

local function hasJob(xPlayer)
    if not xPlayer then return false end
    if not Config.UseJobSystem then return true end
    return xPlayer.job ~= nil and xPlayer.job.name == Config.Job
end

local function syncGrade(xPlayer, level)
    if not Config.UseJobSystem or not Config.XPSystem or not hasJob(xPlayer) then return end
    local grade = getRankData(level).grade
    if xPlayer.job.grade ~= grade then
        xPlayer.setJob(Config.Job, grade)
    end
end

local function distanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

local function vehicleFromNet(netId)
    if not netId then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return nil end
    return entity
end

local function vehicleNear(src, netId)
    local entity = vehicleFromNet(netId)
    if not entity then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(entity) - GetEntityCoords(ped)) <= Config.Vehicle.maxDistance
end

local function spawnVehicle()
    local c = Config.Vehicle.coords
    local entity = CreateVehicleServerSetter(GetHashKey(Config.Vehicle.model), 'automobile', c.x, c.y, c.z, c.w)
    local tries = 0
    while not DoesEntityExist(entity) and tries < 100 do
        Wait(50)
        tries = tries + 1
    end
    if not DoesEntityExist(entity) then return nil end
    return NetworkGetNetworkIdFromEntity(entity)
end

local function deleteVehicle(netId)
    local entity = vehicleFromNet(netId)
    if entity then DeleteEntity(entity) end
end

local function publicState(shift)
    return {
        stage        = shift.stage,
        pickup       = shift.pickup,
        dropoff      = shift.dropoff,
        cargo        = shift.cargo,
        deliveries   = shift.deliveries,
        earned       = shift.earned,
        vehicleNetId = shift.vehicleNetId,
    }
end

local function newPickup(shift)
    local index
    repeat
        index = math.random(#Config.Pickups)
    until index ~= shift.pickup or #Config.Pickups == 1
    shift.pickup  = index
    shift.dropoff = nil
    shift.cargo   = nil
    shift.stage   = 'pickup'
end

local function pickCargo(level)
    local pool = {}
    for id, cfg in pairs(Config.Cargo) do
        if not Config.XPSystem or level >= (cfg.minLevel or 1) then
            pool[#pool + 1] = { id = id, weight = cfg.weight or 1 }
        end
    end
    return weightedPick(pool).id
end

local function pickQuantity()
    return weightedPick(Config.Quantity).amount
end

local function context(src, stage, vehicleNetId)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil, nil, 'err_no_player' end
    if not hasJob(xPlayer) then return nil, nil, 'err_no_job' end
    local shift = Shifts[src]
    if not shift then return nil, nil, 'err_no_shift' end
    if shift.busy then return nil, nil, 'err_busy' end
    if shift.stage ~= stage then return nil, nil, 'err_wrong_stage' end
    if Config.Vehicle.enabled then
        if shift.vehicleNetId ~= vehicleNetId then return nil, nil, 'err_no_vehicle' end
        if not vehicleNear(src, vehicleNetId) then return nil, nil, 'err_vehicle_far' end
    end
    return xPlayer, shift, nil
end

local function cleanup(src)
    local shift = Shifts[src]
    if shift then
        deleteVehicle(shift.vehicleNetId)
        if shift.identifier then StatsCache[shift.identifier] = nil end
    end
    Shifts[src] = nil
end

serverCallback('len_postjob:getState', function(src, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not hasJob(xPlayer) then return cb(nil) end

    local stats = getStats(xPlayer.identifier)
    syncGrade(xPlayer, stats.level)
    local shift = Shifts[src]

    cb({
        name       = xPlayer.getName(),
        xpEnabled  = Config.XPSystem,
        rankKey    = getRankData(stats.level).label,
        level      = stats.level,
        maxLevel   = stats.level >= Config.Level.max,
        xp         = stats.xp,
        xpNeeded   = Config.XPNeeded(stats.level),
        bonus      = math.floor(getBonus(stats.level) * 100 + 0.5),
        deliveries = stats.deliveries,
        earned     = stats.earned,
        shift      = shift and shift.stage and publicState(shift) or nil,
    })
end)

serverCallback('len_postjob:startShift', function(src, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return cb({ ok = false, reason = 'err_no_player' }) end
    if not hasJob(xPlayer) then return cb({ ok = false, reason = 'err_no_job' }) end
    if Shifts[src] then return cb({ ok = false, reason = 'err_shift_active' }) end
    if distanceTo(src, Config.Boss.coords) > Config.ShiftStartDistance then
        return cb({ ok = false, reason = 'err_far_boss' })
    end

    local shift = { busy = true, deliveries = 0, earned = 0, identifier = xPlayer.identifier }
    Shifts[src] = shift

    local ok, stats = pcall(getStats, xPlayer.identifier)
    if not ok then
        Shifts[src] = nil
        print(('[len_postjob] stats load failed: %s'):format(tostring(stats)))
        return cb({ ok = false, reason = 'err_db' })
    end
    syncGrade(xPlayer, stats.level)
    shift.level = stats.level

    if Config.Vehicle.enabled then
        shift.vehicleNetId = spawnVehicle()
        if not shift.vehicleNetId then
            Shifts[src] = nil
            return cb({ ok = false, reason = 'err_no_vehicle' })
        end
    end

    newPickup(shift)
    shift.busy = false
    cb({ ok = true, shift = publicState(shift) })
end)

serverCallback('len_postjob:pickup', function(src, cb, vehicleNetId)
    local _, shift, err = context(src, 'pickup', vehicleNetId)
    if err then return cb({ ok = false, reason = err }) end
    if distanceTo(src, Config.Pickups[shift.pickup]) > Config.PointRadius then
        return cb({ ok = false, reason = 'err_far_point' })
    end

    shift.cargo   = { type = pickCargo(shift.level), amount = pickQuantity() }
    shift.dropoff = math.random(#Config.Dropoffs)
    shift.stage   = 'dropoff'
    cb({ ok = true, shift = publicState(shift) })
end)

serverCallback('len_postjob:dropoff', function(src, cb, vehicleNetId)
    local xPlayer, shift, err = context(src, 'dropoff', vehicleNetId)
    if err then return cb({ ok = false, reason = err }) end
    if distanceTo(src, Config.Dropoffs[shift.dropoff]) > Config.PointRadius then
        return cb({ ok = false, reason = 'err_far_point' })
    end

    shift.busy = true
    local ok, result = pcall(function()
        local identifier = xPlayer.identifier
        local stats = getStats(identifier)
        local cargo = shift.cargo
        local cfg = Config.Cargo[cargo.type]

        local payout = math.floor(randomBetween(cfg.pay) * cargo.amount * (1 + getBonus(stats.level)))
        local tip = 0
        if math.random() < Config.Tip.chance then
            tip = math.random(Config.Tip.min, Config.Tip.max)
        end
        local xpGain = Config.XPSystem and randomBetween(cfg.xp) * cargo.amount or 0
        local total = payout + tip

        local updated = {
            level      = stats.level,
            xp         = stats.xp + xpGain,
            deliveries = stats.deliveries + 1,
            earned     = stats.earned + total,
        }
        local leveled = false
        while Config.XPSystem and updated.level < Config.Level.max and updated.xp >= Config.XPNeeded(updated.level) do
            updated.xp = updated.xp - Config.XPNeeded(updated.level)
            updated.level = updated.level + 1
            leveled = true
        end
        if updated.level >= Config.Level.max then updated.xp = 0 end

        saveStats(identifier, updated)
        StatsCache[identifier] = updated
        xPlayer.addAccountMoney(Config.PayAccount, total)
        syncGrade(xPlayer, updated.level)
        logDelivery(identifier, cargo, payout, tip, xpGain)

        return { payout = payout, tip = tip, xp = xpGain, leveled = leveled, level = updated.level }
    end)
    shift.busy = false

    if not ok then
        print(('[len_postjob] delivery failed: %s'):format(tostring(result)))
        return cb({ ok = false, reason = 'err_db' })
    end

    shift.deliveries = shift.deliveries + 1
    shift.earned     = shift.earned + result.payout + result.tip
    shift.level      = result.level
    newPickup(shift)

    cb({
        ok      = true,
        payout  = result.payout,
        tip     = result.tip,
        xp      = result.xp,
        levelUp = result.leveled and result.level or nil,
        rankKey = result.leveled and getRankData(result.level).label or nil,
        shift   = publicState(shift),
    })
end)

serverCallback('len_postjob:endShift', function(src, cb)
    local shift = Shifts[src]
    if not shift then return cb({ ok = false, reason = 'err_no_shift' }) end
    if shift.busy then return cb({ ok = false, reason = 'err_busy' }) end

    deleteVehicle(shift.vehicleNetId)
    Shifts[src] = nil
    cb({ ok = true, deliveries = shift.deliveries, earned = shift.earned })
end)

AddEventHandler('playerDropped', function()
    cleanup(source)
end)

AddEventHandler('esx:playerLogout', function(playerId)
    cleanup(playerId)
end)
