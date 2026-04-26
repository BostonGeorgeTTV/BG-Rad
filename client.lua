local radiation = 0.0
local activeZones = {}
local createdZones = {}

local nuiVisible = false
local lastNuiHash = ''
local effectRunning = false
local nextNotify = 0
local usingAntiRad = false

local soundPlaying = false
local filterSecondsLeft = 0.0
local filterActive = false

local loadedPersistentData = false
local lastSavedRadiation = 0.0
local nextAutoSave = 0
local nextFilterSave = 0

local function clamp(value, min, max)
    value = tonumber(value) or 0.0

    if value < min then return min end
    if value > max then return max end

    return value
end

local function hasActiveZone()
    return next(activeZones) ~= nil
end

local function getHighestZoneRate()
    local highest = 0.0

    for _, zone in pairs(activeZones) do
        if zone.increase and zone.increase > highest then
            highest = zone.increase
        end
    end

    return highest
end

local function getCurrentZoneLabel()
    local selectedLabel = nil
    local selectedRate = -1.0

    for _, zone in pairs(activeZones) do
        local rate = zone.increase or 0.0

        if rate > selectedRate then
            selectedRate = rate
            selectedLabel = zone.label or zone.name
        end
    end

    return selectedLabel or 'Zona radioattiva'
end

local function playRadiationSound()
    if not Config.RadiationSound or not Config.RadiationSound.enabled then return end
    if soundPlaying then return end

    soundPlaying = true

    SendNUIMessage({
        action = 'sound',
        state = true,
        volume = Config.RadiationSound.volume or 0.35,
        fadeMs = Config.RadiationSound.fadeMs or 1200
    })
end

local function stopRadiationSound()
    if not Config.RadiationSound or not Config.RadiationSound.enabled then return end
    if not soundPlaying then return end

    soundPlaying = false

    SendNUIMessage({
        action = 'sound',
        state = false,
        fadeMs = Config.RadiationSound.fadeMs or 1200
    })
end

local function getPlayerGender()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)

    if model == GetHashKey('mp_f_freemode_01') then
        return 'female'
    end

    return 'male'
end

local function textureAllowed(currentTexture, textures)
    if textures == false or textures == nil then
        return true
    end

    for _, texture in ipairs(textures) do
        if currentTexture == texture then
            return true
        end
    end

    return false
end

local function clothingEntryMatches(ped, entry)
    if not entry then return false end

    local currentDrawable
    local currentTexture

    if entry.prop ~= nil then
        currentDrawable = GetPedPropIndex(ped, entry.prop)
        currentTexture = GetPedPropTextureIndex(ped, entry.prop)
    else
        currentDrawable = GetPedDrawableVariation(ped, entry.component)
        currentTexture = GetPedTextureVariation(ped, entry.component)
    end

    if currentDrawable ~= entry.drawable then
        return false
    end

    return textureAllowed(currentTexture, entry.textures)
end

local function isWearingConfiguredSet(list, requireAll)
    local ped = PlayerPedId()

    if not list or #list == 0 then
        return false
    end

    if requireAll then
        for _, entry in ipairs(list) do
            if not clothingEntryMatches(ped, entry) then
                return false
            end
        end

        return true
    end

    for _, entry in ipairs(list) do
        if clothingEntryMatches(ped, entry) then
            return true
        end
    end

    return false
end

local function isWearingMask()
    if not Config.Protection or not Config.Protection.enabled then
        return false
    end

    local gender = getPlayerGender()
    return isWearingConfiguredSet(Config.Protection.masks and Config.Protection.masks[gender], false)
end

local function isWearingSuit()
    if not Config.Protection or not Config.Protection.enabled then
        return false
    end

    local gender = getPlayerGender()
    return isWearingConfiguredSet(
        Config.Protection.suits and Config.Protection.suits[gender],
        Config.Protection.suitRequiresAll ~= false
    )
end

local function getRadiationProtection()
    if not Config.Protection or not Config.Protection.enabled then
        return {
            hasMask = false,
            hasSuit = false,
            filterActive = false,
            filterSecondsLeft = 0,
            protection = 0.0
        }
    end

    local hasMask = isWearingMask()
    local hasSuit = isWearingSuit()
    local activeFilter = filterActive and filterSecondsLeft > 0
    local protection = 0.0

    if hasSuit then
        protection = protection + (Config.Protection.suitProtection or 0.0)
    end

    if hasMask and activeFilter then
        protection = protection + (Config.Protection.maskProtection or 0.0)
    end

    protection = clamp(protection, 0.0, Config.Protection.maxProtection or 1.0)

    return {
        hasMask = hasMask,
        hasSuit = hasSuit,
        filterActive = activeFilter,
        filterSecondsLeft = filterSecondsLeft,
        protection = protection
    }
end

local function formatFilterTime(seconds)
    seconds = math.max(0, math.ceil(tonumber(seconds) or 0))

    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60

    return ('%02d:%02d'):format(minutes, secs)
end

local function sendRadiationSave(force)
    if not Config.Persistence or not Config.Persistence.enabled then return end
    if not loadedPersistentData then return end

    local now = GetGameTimer()
    local saveInterval = Config.Persistence.saveIntervalMs or 60000
    local changeThreshold = Config.Persistence.saveChangeThreshold or 2.0
    local filterSaveInterval = Config.Persistence.filterSaveIntervalMs or saveInterval

    local radiationDifference = math.abs((radiation or 0.0) - (lastSavedRadiation or 0.0))

    local shouldSaveByChange =
        Config.Persistence.saveOnChange and
        radiationDifference >= changeThreshold

    local shouldSaveByTime = now >= nextAutoSave
    local shouldSaveFilter = Config.Persistence.saveFilter and now >= nextFilterSave

    if not force and not shouldSaveByChange and not shouldSaveByTime and not shouldSaveFilter then
        return
    end

    lastSavedRadiation = radiation or 0.0
    nextAutoSave = now + saveInterval
    nextFilterSave = now + filterSaveInterval

    TriggerServerEvent('bg_radiations:server:saveData', {
        radiation = radiation or 0.0,
        filterSecondsLeft = filterSecondsLeft or 0,
        filterActive = filterActive or false
    })
end

local function setNuiVisible(state)
    if nuiVisible == state then return end

    nuiVisible = state

    SendNUIMessage({
        action = 'visible',
        state = state
    })
end

local function updateNui(force)
    local value = math.floor(radiation + 0.5)
    local protectionData = getRadiationProtection()
    local inZone = hasActiveZone()
    local filterMaxSeconds = Config.Protection and Config.Protection.filterDurationSeconds or 300

    local hash = table.concat({
        tostring(value),
        tostring(inZone),
        tostring(getCurrentZoneLabel()),
        tostring(protectionData.hasMask),
        tostring(protectionData.hasSuit),
        tostring(protectionData.filterActive),
        tostring(math.ceil(protectionData.filterSecondsLeft or 0)),
        tostring(math.floor((protectionData.protection or 0.0) * 100 + 0.5))
    }, '|')

    if not force and hash == lastNuiHash then return end

    lastNuiHash = hash

    SendNUIMessage({
        action = 'update',
        value = value,
        max = Config.MaxRadiation,
        inZone = inZone,
        zoneLabel = getCurrentZoneLabel(),

        protection = math.floor((protectionData.protection or 0.0) * 100 + 0.5),
        hasMask = protectionData.hasMask,
        hasSuit = protectionData.hasSuit,
        filterActive = protectionData.filterActive,
        filterTime = formatFilterTime(protectionData.filterSecondsLeft or 0),
        filterSeconds = math.ceil(protectionData.filterSecondsLeft or 0),
        filterMaxSeconds = filterMaxSeconds
    })
end

local function handleScreenEffect()
    if not Config.ScreenEffects then return end

    if radiation >= Config.EffectAt and not effectRunning then
        AnimpostfxPlay(Config.ScreenEffectName, 0, true)
        effectRunning = true
    elseif radiation < Config.EffectAt and effectRunning then
        AnimpostfxStop(Config.ScreenEffectName)
        effectRunning = false
    end
end

local function refreshUi()
    if radiation > 0 or hasActiveZone() then
        setNuiVisible(true)
    else
        setNuiVisible(false)
    end

    updateNui(false)
end

local function setRadiation(value)
    radiation = clamp(value, 0.0, Config.MaxRadiation)
    handleScreenEffect()
    refreshUi()
    sendRadiationSave(false)
end

local function addRadiation(amount)
    amount = tonumber(amount) or 0.0

    if amount <= 0.0 then
        updateNui(false)
        return
    end

    setRadiation(radiation + amount)
end

local function reduceRadiation(amount)
    amount = tonumber(amount) or 0.0

    if amount <= 0.0 then
        updateNui(false)
        return
    end

    setRadiation(radiation - amount)
end

local function activateZone(self, zoneConfig)
    local id = self.id or zoneConfig.name

    if activeZones[id] then return end

    activeZones[id] = {
        name = zoneConfig.name,
        label = zoneConfig.label or zoneConfig.name,
        increase = zoneConfig.increase or Config.DefaultIncreasePerTick
    }

    setNuiVisible(true)
    updateNui(true)
    playRadiationSound()

    lib.notify({
        type = 'error',
        title = 'Radiazioni',
        description = ('Sei entrato in: %s'):format(activeZones[id].label)
    })
end

local function deactivateZone(self, zoneConfig)
    local id = self.id or zoneConfig.name

    if not activeZones[id] then return end

    local label = activeZones[id].label
    activeZones[id] = nil

    if not hasActiveZone() then
        stopRadiationSound()
    end

    lib.notify({
        type = 'inform',
        title = 'Radiazioni',
        description = ('Sei uscito da: %s'):format(label)
    })

    refreshUi()
end

CreateThread(function()
    for _, zoneConfig in ipairs(Config.Zones) do
        local zc = zoneConfig

        local zone = lib.zones.poly({
            name = zc.name,
            points = zc.points,
            thickness = zc.thickness or 4.0,
            debug = Config.Debug,

            onEnter = function(self)
                activateZone(self, zc)
            end,

            onExit = function(self)
                deactivateZone(self, zc)
            end,

            -- Fallback leggero: se onEnter non parte per qualche motivo,
            -- inside aggancia la zona senza fare logica pesante ogni tick/frame.
            inside = function(self)
                local id = self.id or zc.name

                if not activeZones[id] then
                    activateZone(self, zc)
                end
            end
        })

        createdZones[#createdZones + 1] = zone
    end
end)

CreateThread(function()
    while true do
        Wait(Config.TickMs)

        local rate = getHighestZoneRate()

        if rate > 0 then
            if Config.Protection and Config.Protection.enabled and filterActive and filterSecondsLeft > 0 then
                local shouldDrainFilter = true

                if Config.Protection.filterDrainRequiresMask ~= false then
                    shouldDrainFilter = isWearingMask()
                end

                if shouldDrainFilter then
                    filterSecondsLeft = filterSecondsLeft - ((Config.TickMs or 1000) / 1000.0)

                    if filterSecondsLeft <= 0 then
                        filterSecondsLeft = 0
                        filterActive = false
                        sendRadiationSave(true)

                        lib.notify({
                            type = 'error',
                            title = 'Filtro esaurito',
                            description = 'Il filtro della maschera antiradiazioni è terminato.'
                        })
                    end
                end
            end

            local protectionData = getRadiationProtection()
            local finalRate = rate * (1.0 - (protectionData.protection or 0.0))
            finalRate = math.max(0.0, finalRate)

            if finalRate > 0.001 then
                addRadiation(finalRate)
            else
                updateNui(false)
            end
        elseif Config.NaturalDecayOutside > 0 and radiation > 0 then
            reduceRadiation(Config.NaturalDecayOutside)
        else
            updateNui(false)
        end

        if radiation >= Config.DamageAt then
            local ped = PlayerPedId()

            if not IsEntityDead(ped) then
                ApplyDamageToPed(ped, Config.DamagePerTick, false)
            end
        end

        if radiation >= Config.NotifyAt then
            local now = GetGameTimer()

            if now >= nextNotify then
                nextNotify = now + Config.NotifyCooldownMs

                lib.notify({
                    type = 'error',
                    title = 'Radiazioni alte',
                    description = ('Livello radiazioni: %s%%'):format(math.floor(radiation + 0.5))
                })
            end
        end

        sendRadiationSave(false)
    end
end)

exports('antiRadSyringe', function(data, slot)
    if usingAntiRad then return end

    if radiation <= 0 then
        lib.notify({
            type = 'error',
            title = 'Siringa antiradiazioni',
            description = 'Non hai radiazioni da curare.'
        })

        return
    end

    usingAntiRad = true

    exports.ox_inventory:useItem(data, function(used)
        usingAntiRad = false

        if not used then return end

        reduceRadiation(Config.AntiRadReduction)
        sendRadiationSave(true)

        lib.notify({
            type = 'success',
            title = 'Siringa antiradiazioni',
            description = ('Radiazioni ridotte di %s%%. Livello attuale: %s%%'):format(
                math.floor(Config.AntiRadReduction),
                math.floor(radiation + 0.5)
            )
        })
    end)
end)

exports('useRadiationFilter', function(data, slot)
    if not Config.Protection or not Config.Protection.enabled then
        lib.notify({
            type = 'error',
            title = 'Filtro antiradiazioni',
            description = 'Sistema protezioni disattivato.'
        })

        return
    end

    if not isWearingMask() then
        lib.notify({
            type = 'error',
            title = 'Filtro antiradiazioni',
            description = 'Devi indossare una maschera antiradiazioni per usare il filtro.'
        })

        return
    end

    if filterActive and filterSecondsLeft > 0 then
        lib.notify({
            type = 'error',
            title = 'Filtro antiradiazioni',
            description = ('Hai già un filtro attivo. Durata residua: %s'):format(formatFilterTime(filterSecondsLeft))
        })

        return
    end

    exports.ox_inventory:useItem(data, function(used)
        if not used then return end

        filterSecondsLeft = Config.Protection.filterDurationSeconds or 300
        filterActive = true

        updateNui(true)
        sendRadiationSave(true)

        lib.notify({
            type = 'success',
            title = 'Filtro antiradiazioni',
            description = ('Filtro installato. Durata: %s'):format(formatFilterTime(filterSecondsLeft))
        })
    end)
end)

RegisterNetEvent('bg_radiations:client:reduceRadiation', function(amount)
    reduceRadiation(tonumber(amount) or Config.AntiRadReduction)
end)

RegisterNetEvent('bg_radiations:client:addRadiation', function(amount)
    addRadiation(tonumber(amount) or Config.DefaultIncreasePerTick)
end)

exports('GetRadiation', function()
    return radiation
end)

exports('SetRadiation', function(value)
    setRadiation(tonumber(value) or 0)
end)

exports('AddRadiation', function(value)
    addRadiation(tonumber(value) or Config.DefaultIncreasePerTick)
end)

exports('ReduceRadiation', function(value)
    reduceRadiation(tonumber(value) or Config.AntiRadReduction)
end)

exports('GetRadiationProtection', function()
    return getRadiationProtection()
end)

exports('GetRadiationFilterSeconds', function()
    return math.ceil(filterSecondsLeft)
end)

exports('SetRadiationFilterSeconds', function(seconds)
    seconds = tonumber(seconds) or 0
    filterSecondsLeft = math.max(0, seconds)
    filterActive = filterSecondsLeft > 0
    updateNui(true)
    sendRadiationSave(true)
end)

RegisterNetEvent('bg_radiations:client:loadedData', function(data)
    data = data or {}

    radiation = clamp(tonumber(data.radiation) or 0.0, 0.0, Config.MaxRadiation)

    if Config.Persistence and Config.Persistence.saveFilter ~= false then
        filterSecondsLeft = math.max(0, tonumber(data.filterSecondsLeft) or 0)
        filterActive = data.filterActive == true and filterSecondsLeft > 0
    end

    loadedPersistentData = true
    lastSavedRadiation = radiation
    nextAutoSave = GetGameTimer() + (Config.Persistence and Config.Persistence.saveIntervalMs or 60000)
    nextFilterSave = GetGameTimer() + (Config.Persistence and Config.Persistence.filterSaveIntervalMs or 60000)

    handleScreenEffect()
    refreshUi()
    updateNui(true)

    if Config.Debug then
        print(('[bg_radiations] Dati persistenti caricati: radiation=%s filter=%s active=%s'):format(
            radiation,
            math.ceil(filterSecondsLeft),
            tostring(filterActive)
        ))
    end
end)

CreateThread(function()
    Wait(2500)

    if Config.Persistence and Config.Persistence.enabled and Config.Persistence.loadOnJoin ~= false then
        TriggerServerEvent('bg_radiations:server:requestData')
    else
        loadedPersistentData = true
        lastSavedRadiation = radiation
        nextAutoSave = GetGameTimer() + (Config.Persistence and Config.Persistence.saveIntervalMs or 60000)
        nextFilterSave = GetGameTimer() + (Config.Persistence and Config.Persistence.filterSaveIntervalMs or 60000)
    end
end)

if Config.Debug then
    RegisterCommand('radtest', function(_, args)
        local value = tonumber(args[1]) or 0
        setRadiation(value)
    end, false)

    RegisterCommand('radsoundtest', function()
        playRadiationSound()

        SetTimeout(5000, function()
            stopRadiationSound()
        end)
    end, false)

    RegisterCommand('radfiltertest', function(_, args)
        local seconds = tonumber(args[1]) or (Config.Protection and Config.Protection.filterDurationSeconds) or 300
        filterSecondsLeft = seconds
        filterActive = seconds > 0
        updateNui(true)

        lib.notify({
            type = 'inform',
            title = 'Debug filtro',
            description = ('Filtro impostato a %s'):format(formatFilterTime(filterSecondsLeft))
        })
    end, false)

    RegisterCommand('radclothes', function()
        local ped = PlayerPedId()
        local protectionData = getRadiationProtection()

        print('^2[bg_radiations]^7 Componenti player attuali:')

        for component = 0, 11 do
            print(('[bg_radiations] component=%s drawable=%s texture=%s'):format(
                component,
                GetPedDrawableVariation(ped, component),
                GetPedTextureVariation(ped, component)
            ))
        end

        print('^2[bg_radiations]^7 Props player attuali:')

        for prop = 0, 7 do
            print(('[bg_radiations] prop=%s drawable=%s texture=%s'):format(
                prop,
                GetPedPropIndex(ped, prop),
                GetPedPropTextureIndex(ped, prop)
            ))
        end

        lib.notify({
            type = 'inform',
            title = 'Debug vestiti',
            description = ('Maschera: %s | Tuta: %s | Protezione: %s%%'):format(
                protectionData.hasMask and 'SI' or 'NO',
                protectionData.hasSuit and 'SI' or 'NO',
                math.floor((protectionData.protection or 0.0) * 100 + 0.5)
            )
        })
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    sendRadiationSave(true)

    setNuiVisible(false)
    stopRadiationSound()

    if effectRunning then
        AnimpostfxStop(Config.ScreenEffectName)
    end

    for _, zone in ipairs(createdZones) do
        zone:remove()
    end
end)
