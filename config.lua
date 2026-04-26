Config = {}

Config.Debug = true

-- Tick principale radiazioni
Config.TickMs = 1000

-- Valori radiazioni
Config.MaxRadiation = 100.0
Config.DefaultIncreasePerTick = 1.5

-- Se vuoi che fuori dalla zona scenda da sola, metti tipo 0.2.
-- Se vuoi che scenda SOLO con siringa, lascia 0.
Config.NaturalDecayOutside = 0.0

-- Item antiradiazioni
Config.AntiRadReduction = 35.0

-- Danno quando supera una certa soglia
Config.DamageAt = 75.0
Config.DamagePerTick = 4

-- Effetto video
Config.ScreenEffects = true
Config.EffectAt = 55.0
Config.ScreenEffectName = 'DrugsMichaelAliensFight'

-- Notifiche
Config.NotifyAt = 60.0
Config.NotifyCooldownMs = 15000

Config.RadiationSound = {
    enabled = true,
    volume = 0.35,
    fadeMs = 1200,
}

-- Persistenza radiazioni su database con oxmysql.
-- Richiede SQL in install/bg_radiations_players.sql.
Config.Persistence = {
    enabled = true,

    -- Carica i dati quando il player entra.
    loadOnJoin = true,

    -- Salva automaticamente mentre il player è online.
    saveIntervalMs = 60000,

    -- Salva quando la radiazione cambia almeno di questa soglia.
    saveOnChange = true,
    saveChangeThreshold = 2.0,

    -- Salva anche filtro attivo e secondi rimasti.
    saveFilter = true,
    filterSaveIntervalMs = 60000,

    -- Default: license FiveM.
    -- Se usi multicharacter ESX/QBCore/Qbox modifica getIdentifier in server.lua.
    identifierType = 'license'
}

-- Protezioni tramite vestiti + filtro maschera.
-- Per trovare drawable/texture esatti indossa il vestito e usa /radclothes con Config.Debug = true.
Config.Protection = {
    enabled = true,

    -- 5 minuti. Il tempo scala SOLO mentre sei dentro una zona radioattiva.
    filterDurationSeconds = 300,

    -- Se true, il filtro scala solo quando sei dentro zona radioattiva E stai indossando la maschera.
    -- Se false, scala dentro zona anche se togli la maschera.
    filterDrainRequiresMask = true,

    -- Maschera + filtro attivo. 1.0 = blocca completamente le radiazioni.
    maskProtection = 1.0,

    -- Tuta antiradiazioni. Attenua, ma da sola non blocca tutto.
    suitProtection = 0.50,

    -- Cap massimo protezione totale.
    maxProtection = 1.0,

    -- La maschera viene riconosciuta se indossi almeno UNO degli elementi configurati.
    masks = {
        male = {
            -- component 1 = mask
            -- Sostituisci drawable/texture con quelli reali della tua maschera.
            { component = 1, drawable = 46, textures = false },
            { component = 1, drawable = 52, textures = false },
        },

        female = {
            { component = 1, drawable = 46, textures = false },
            { component = 1, drawable = 52, textures = false },
        }
    },

    -- La tuta viene riconosciuta solo se indossi TUTTI i componenti configurati.
    -- Metti suitRequiresAll = false se vuoi che basti anche un solo componente.
    suitRequiresAll = true,
    suits = {
        male = {
            -- Esempi: sostituisci con i drawable reali della tua tuta.
            { component = 11, drawable = 67, textures = false }, -- torso / giacca
            { component = 4, drawable = 40, textures = false },  -- pantaloni
            -- { component = 8, drawable = 15, textures = false }, -- maglia / undershirt, opzionale
        },

        female = {
            { component = 11, drawable = 61, textures = false },
            { component = 4, drawable = 40, textures = false },
            -- { component = 8, drawable = 15, textures = false },
        }
    }
}

-- Zone radioattive
Config.Zones = {
    {
        name = 'zona_radioattiva_1',
        label = 'Zona radioattiva',
        increase = 2.0,
        thickness = 4.0,
        points = {
            vec3(3611.0, 3724.0, 30.0),
            vec3(3606.0, 3718.0, 30.0),
            vec3(3610.0, 3713.0, 30.0),
            vec3(3615.0, 3721.0, 30.0),
        }
    },

    -- Esempio seconda zona più forte
    -- {
    --     name = 'zona_radioattiva_2',
    --     label = 'Reattore contaminato',
    --     increase = 4.0,
    --     thickness = 8.0,
    --     points = {
    --         vec3(100.0, 100.0, 30.0),
    --         vec3(120.0, 100.0, 30.0),
    --         vec3(120.0, 120.0, 30.0),
    --         vec3(100.0, 120.0, 30.0),
    --     }
    -- }
}
