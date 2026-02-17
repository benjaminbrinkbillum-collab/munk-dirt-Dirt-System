--[[
    munk-dirt server.lua
    Author: Munk
    Description: Server-side logic for fully synced, multiplayer-safe dirt system.
    Handles all dirt calculations, storage, and sync.
]]

local dirtData = {} -- [plate] = {dirt = float, lastUpdate = os.time(), lastPos = vector3, lastDriver = source}
local updatingVehicles = {} -- [plate] = true if being updated
local lastRequest = {} -- [source] = os.time() anti-spam

local function clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

-- MySQL integration (oxmysql or mysql-async)
local useDB = Config.SaveToDatabase
local dbReady = false
if useDB then
    if GetResourceState('oxmysql') == 'started' then
        dbReady = true
    elseif GetResourceState('mysql-async') == 'started' then
        dbReady = true
    else
        print('[munk-dirt] WARNING: No supported MySQL resource found! Dirt will not persist.')
        useDB = false
    end
end

-- Load dirt from DB
local function loadDirt(plate, cb)
    if not useDB then cb(0.0) return end
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:fetch('SELECT dirt FROM munk_dirt WHERE plate = ?', {plate}, function(result)
            if result and result[1] then cb(result[1].dirt or 0.0) else cb(0.0) end
        end)
    elseif GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:fetch_all('SELECT dirt FROM munk_dirt WHERE plate = @plate', {['@plate'] = plate}, function(result)
            if result and result[1] then cb(result[1].dirt or 0.0) else cb(0.0) end
        end)
    else
        cb(0.0)
    end
end

-- Save dirt to DB
local function saveDirt(plate, dirt)
    if not useDB then return end
    dirt = clamp(dirt, 0.0, Config.MaxDirt)
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:update('INSERT INTO munk_dirt (plate, dirt) VALUES (?, ?) ON DUPLICATE KEY UPDATE dirt = ?', {plate, dirt, dirt})
    elseif GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:execute('INSERT INTO munk_dirt (plate, dirt) VALUES (@plate, @dirt) ON DUPLICATE KEY UPDATE dirt = @dirt', {['@plate'] = plate, ['@dirt'] = dirt})
    end
end

-- Validate plate (alphanumeric, 1-32 chars)
local function validPlate(plate)
    return type(plate) == 'string' and #plate > 0 and #plate <= 32 and plate:match('^%w+$')
end

-- Called by client when entering vehicle or requesting dirt
RegisterNetEvent('munk-dirt:requestDirt', function(plate, vehNet)
    local src = source
    if not validPlate(plate) then return end
    if not vehNet or type(vehNet) ~= 'number' then return end
    if lastRequest[src] and os.time() - lastRequest[src] < 2 then return end -- anti-spam
    lastRequest[src] = os.time()
    if dirtData[plate] then
        TriggerClientEvent('munk-dirt:syncDirt', src, plate, dirtData[plate].dirt, vehNet)
    else
        loadDirt(plate, function(dirt)
            dirtData[plate] = {dirt = dirt, lastUpdate = os.time()}
            TriggerClientEvent('munk-dirt:syncDirt', src, plate, dirt, vehNet)
        end)
    end
end)

-- Client notifies server of vehicle actively being driven
RegisterNetEvent('munk-dirt:vehicleActive', function(plate, vehNet, pos, isRaining, isOffroad, inWater, inOilZone)
    local src = source
    if not validPlate(plate) then return end
    if not vehNet or type(vehNet) ~= 'number' then return end
    if not pos or type(pos) ~= 'table' then return end
    updatingVehicles[plate] = {src = src, vehNet = vehNet, pos = pos, isRaining = isRaining, isOffroad = isOffroad, inWater = inWater, inOilZone = inOilZone, lastUpdate = os.time()}
end)

-- Main dirt update loop
CreateThread(function()
    while true do
        Wait(Config.DirtIncreaseInterval * 1000)
        local now = os.time()
        for plate, data in pairs(updatingVehicles) do
            if dirtData[plate] == nil then
                loadDirt(plate, function(dirt)
                    dirtData[plate] = {dirt = dirt, lastUpdate = now}
                end)
            end
            local dirt = dirtData[plate] and dirtData[plate].dirt or 0.0
            local increase = Config.BaseIncrease
            if data.isRaining then increase = increase * Config.RainMultiplier end
            if data.isOffroad then increase = increase * Config.OffroadMultiplier end
            -- If the car is in water, add extra dirt
            if data.inWater then
                increase = increase + 5.0 -- extra dirt from water
            end
            -- If the car is in an oil zone, add extra dirt
            if data.inOilZone and Config and Config.OilDirtBonus then
                increase = increase + Config.OilDirtBonus
            end
            dirt = clamp(dirt + increase, 0.0, Config.MaxDirt)
            dirtData[plate] = {dirt = dirt, lastUpdate = now}
            saveDirt(plate, dirt)
            -- Sync to all players near vehicle
            TriggerClientEvent('munk-dirt:syncDirtAll', -1, plate, dirt, data.vehNet)
        end
        updatingVehicles = {} -- Only update vehicles that are still active
    end
end)

-- On player disconnect, cleanup
AddEventHandler('playerDropped', function(reason)
    local src = source
    for plate, data in pairs(updatingVehicles) do
        if data.src == src then updatingVehicles[plate] = nil end
    end
end)

-- On resource stop, save all dirt
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for plate, data in pairs(dirtData) do
        saveDirt(plate, data.dirt)
    end
end)
