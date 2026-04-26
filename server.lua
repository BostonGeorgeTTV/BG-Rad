local playerData = {}

local function getIdentifier(source)
    -- Default: license FiveM.
    -- Se usi ESX/QBCore/Qbox multicharacter, sostituisci qui con identifier/citizenid del personaggio.
    local identifierType = Config.Persistence and Config.Persistence.identifierType or 'license'
    local identifier = GetPlayerIdentifierByType(source, identifierType)

    if identifier then
        return identifier
    end

    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:find('license:') then
            return id
        end
    end

    return nil
end

local function sanitizeRadiation(value)
    value = tonumber(value) or 0.0

    if value < 0.0 then value = 0.0 end
    if value > Config.MaxRadiation then value = Config.MaxRadiation end

    return value
end

local function sanitizeFilterSeconds(value)
    value = tonumber(value) or 0

    if value < 0 then value = 0 end
    if value > 86400 then value = 86400 end

    return math.floor(value)
end

local function saveRadiation(source, data)
    if not Config.Persistence or not Config.Persistence.enabled then return end
    if not data then return end

    local identifier = getIdentifier(source)

    if not identifier then
        print(('[bg_radiations] Impossibile salvare: identifier non trovato per source %s'):format(source))
        return
    end

    local radiation = sanitizeRadiation(data.radiation)
    local filterSeconds = Config.Persistence.saveFilter ~= false and sanitizeFilterSeconds(data.filterSecondsLeft) or 0
    local filterActive = data.filterActive and filterSeconds > 0 and 1 or 0

    playerData[source] = {
        radiation = radiation,
        filterSecondsLeft = filterSeconds,
        filterActive = filterActive == 1
    }

    MySQL.prepare.await([[
        INSERT INTO bg_radiations_players
            (identifier, radiation, filter_seconds, filter_active)
        VALUES
            (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            radiation = VALUES(radiation),
            filter_seconds = VALUES(filter_seconds),
            filter_active = VALUES(filter_active)
    ]], {
        identifier,
        radiation,
        filterSeconds,
        filterActive
    })
end

RegisterNetEvent('bg_radiations:server:requestData', function()
    local src = source

    if not Config.Persistence or not Config.Persistence.enabled or Config.Persistence.loadOnJoin == false then
        TriggerClientEvent('bg_radiations:client:loadedData', src, {
            radiation = 0,
            filterSecondsLeft = 0,
            filterActive = false
        })

        return
    end

    local identifier = getIdentifier(src)

    if not identifier then
        TriggerClientEvent('bg_radiations:client:loadedData', src, {
            radiation = 0,
            filterSecondsLeft = 0,
            filterActive = false
        })

        return
    end

    local result = MySQL.single.await([[
        SELECT radiation, filter_seconds, filter_active
        FROM bg_radiations_players
        WHERE identifier = ?
    ]], {
        identifier
    })

    local data = {
        radiation = result and tonumber(result.radiation) or 0.0,
        filterSecondsLeft = result and tonumber(result.filter_seconds) or 0,
        filterActive = result and tonumber(result.filter_active) == 1 or false
    }

    playerData[src] = data

    TriggerClientEvent('bg_radiations:client:loadedData', src, data)
end)

RegisterNetEvent('bg_radiations:server:saveData', function(data)
    local src = source

    if type(data) ~= 'table' then return end

    saveRadiation(src, {
        radiation = data.radiation,
        filterSecondsLeft = data.filterSecondsLeft,
        filterActive = data.filterActive
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    local data = playerData[src]

    if data then
        saveRadiation(src, data)
        playerData[src] = nil
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for src, data in pairs(playerData) do
        saveRadiation(src, data)
    end
end)
