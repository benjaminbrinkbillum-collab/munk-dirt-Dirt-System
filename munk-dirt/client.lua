--[[
    munk-dirt client.lua
    Author: Munk
    Description: Client-side logic for dirt system. Handles vehicle state reporting and applying dirt visuals.
]]

local lastPlate = nil
local lastVeh = nil
local lastDirt = 0.0
local lastSync = 0
local dirtCache = {} -- [plate] = dirt

-- Utility: Get vehicle plate (trimmed, upper)
local function getPlate(veh)
    return string.upper(string.gsub(GetVehicleNumberPlateText(veh) or '', '^%s*(.-)%s*$', '%1'))
end

-- Utility: Is vehicle offroad
local function isOffroad(veh)
    local surface = GetVehicleWheelSurfaceMaterial(veh, 0)
    -- 4, 5, 6, 7, 8, 9, 10 = sand, grass, mud, dirt, gravel, etc.
    return surface and (surface >= 4 and surface <= 10)
end

-- Utility: Is it raining
local function isRaining()
    local weather = GetPrevWeatherTypeHashName()
    return weather == GetHashKey('RAIN') or weather == GetHashKey('THUNDER')
end

-- Main loop: report active vehicles
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if not ped then goto continue end
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and GetPedInVehicleSeat(veh, -1) == ped then
            local plate = getPlate(veh)
            if plate and #plate > 0 then
                local pos = GetEntityCoords(veh)
                local moving = GetEntitySpeed(veh) > 1.0
                if moving then
                    -- Check if the car is driving through water
                    local waterHeight = GetWaterHeight(pos.x, pos.y, pos.z, 0.0)
                    local inWater = false
                    if waterHeight then
                        local vehZ = GetEntityCoords(veh).z
                        if (waterHeight - vehZ) > 0.5 then
                            inWater = true
                        end
                    end
                    -- Check if the car is in an oil zone
                    local inOilZone = false
                    if Config and Config.OilZones then
                        for _, zone in ipairs(Config.OilZones) do
                            local dx = pos.x - zone.center.x
                            local dy = pos.y - zone.center.y
                            local dist = math.sqrt(dx*dx + dy*dy)
                            if dist < zone.radius then
                                inOilZone = true
                                break
                            end
                        end
                    end
                    TriggerServerEvent('munk-dirt:vehicleActive', plate, NetworkGetNetworkIdFromEntity(veh), {x=pos.x, y=pos.y, z=pos.z}, isRaining(), isOffroad(veh), inWater, inOilZone)
                end
                if lastPlate ~= plate or (GetGameTimer() - lastSync > 10000) then
                    TriggerServerEvent('munk-dirt:requestDirt', plate, NetworkGetNetworkIdFromEntity(veh))
                    lastPlate = plate
                    lastVeh = veh
                    lastSync = GetGameTimer()
                end
            end
        end
        ::continue::
    end
end)

-- Sync dirt from server (on enter/stream in)
RegisterNetEvent('munk-dirt:syncDirt', function(plate, dirt, vehNet)
    dirtCache[plate] = dirt
    local veh = NetworkGetEntityFromNetworkId(vehNet)
    if veh and DoesEntityExist(veh) then
        SetVehicleDirtLevel(veh, dirt) -- sæt til serverens dirt-niveau for mere realistisk effekt
    end
end)

-- Sync dirt to all nearby (periodic)
RegisterNetEvent('munk-dirt:syncDirtAll', function(plate, dirt, vehNet)
    dirtCache[plate] = dirt
    local veh = NetworkGetEntityFromNetworkId(vehNet)
    if veh and DoesEntityExist(veh) then
        SetVehicleDirtLevel(veh, dirt) -- sæt til serverens dirt-niveau for mere realistisk effekt
    end
end)

-- On player streams in vehicle, request dirt
AddEventHandler('entityCreated', function(entity)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then return end
    local plate = getPlate(entity)
    if plate and #plate > 0 then
        TriggerServerEvent('munk-dirt:requestDirt', plate, NetworkGetNetworkIdFromEntity(entity))
    end
end)
