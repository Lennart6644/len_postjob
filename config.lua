Config = {}

Config.Locale = 'en'
Config.FallbackLocale = 'en'
Config.UseJobSystem = false
Config.XPSystem = true
Config.Job = 'post'
Config.PayAccount = 'money'
Config.Currency = '$'
Config.InteractKey = 'E'
Config.InteractDistance = 1.8
Config.PointRadius = 6.0
Config.ShiftStartDistance = 10.0
Config.ProgressTime = 5000
Config.Minigame = {
    key = 38,
    keyLabel = 'E',
    cancelKey = 177,
    cancelLabel = 'Backspace',
    skillcheck = { rounds = 3, speed = 0.9, speedStep = 0.2, zoneWidth = 0.2 },
}
Config.Anim = { scenario = 'PROP_HUMAN_BUM_BIN' }
Config.Logging = true

Config.Boss = {
    coords  = vec3(132.9577, 96.1347, 83.5076),
    heading = 160.0,
    ped     = 's_m_m_postal_01',
    blip    = { sprite = 478, color = 5, scale = 0.75 },
}

Config.Vehicle = {
    enabled     = true,
    model       = 'boxville2',
    coords      = vec4(130.4967, 88.7683, 82.1197, 71.5777),
    maxDistance = 50.0,
}

Config.Blips = {
    pickup  = { sprite = 478, color = 5, scale = 0.7 },
    dropoff = { sprite = 478, color = 2, scale = 0.7 },
}

Config.Uniform = {
    enabled = true,
}

Config.Outfits = {
    male = {
        tshirt_1 = 15, tshirt_2 = 0,
        torso_1  = 65, torso_2  = 0,
        decals_1 = 0,  decals_2 = 0,
        arms     = 11,
        pants_1  = 35, pants_2  = 0,
        shoes_1  = 25, shoes_2  = 0,
        bags_1   = 0,  bags_2   = 0,
        chain_1  = 0,  chain_2  = 0,
    },
    female = {
        tshirt_1 = 15, tshirt_2 = 0,
        torso_1  = 50, torso_2  = 0,
        decals_1 = 0,  decals_2 = 0,
        arms     = 9,
        pants_1  = 34, pants_2  = 0,
        shoes_1  = 27, shoes_2  = 0,
        bags_1   = 0,  bags_2   = 0,
        chain_1  = 0,  chain_2  = 0,
    },
}

Config.Level = {
    max           = 40,
    bonusPerLevel = 0.05,
    maxBonus      = 2.0,
}

Config.XPNeeded = function(level)
    return 100 + (level - 1) * 50
end

Config.Ranks = {
    { level = 1,  grade = 0, label = 'rank.1' },
    { level = 5,  grade = 1, label = 'rank.5' },
    { level = 10, grade = 2, label = 'rank.10' },
    { level = 15, grade = 3, label = 'rank.15' },
    { level = 20, grade = 4, label = 'rank.20' },
    { level = 25, grade = 5, label = 'rank.25' },
    { level = 30, grade = 6, label = 'rank.30' },
    { level = 35, grade = 7, label = 'rank.35' },
    { level = 40, grade = 8, label = 'rank.40' },
}

Config.Cargo = {
    letter            = { minLevel = 1,  weight = 40,  pay = { 300, 550 },   xp = { 15, 30 } },
    small_parcel      = { minLevel = 3,  weight = 22,  pay = { 500, 900 },   xp = { 18, 34 } },
    registered_letter = { minLevel = 5,  weight = 20,  pay = { 450, 800 },   xp = { 20, 36 } },
    parcel            = { minLevel = 8,  weight = 12,  pay = { 600, 1100 },  xp = { 24, 42 } },
    large_parcel      = { minLevel = 15, weight = 6,   pay = { 900, 1500 },  xp = { 30, 48 } },
    express           = { minLevel = 20, weight = 3,   pay = { 1400, 2100 }, xp = { 36, 56 } },
    valuables         = { minLevel = 25, weight = 2,   pay = { 2000, 3000 }, xp = { 44, 64 } },
}

Config.Quantity = {
    { amount = 1, weight = 50 },
    { amount = 2, weight = 30 },
    { amount = 3, weight = 14 },
    { amount = 4, weight = 6 },
}

Config.Tip = {
    chance = 0.15,
    min    = 50,
    max    = 250,
}

Config.Pickups = {
    vec3(-323.078491, 134.504517, 67.35902),
    vec3(-53.839478, -98.676315, 56.827251),
    vec3(-187.542511, -705.314514, 33.244240),
    vec3(458.0612, 119.2107, 100.2166),
    vec3(307.4605, 170.5526, 105.1635),
    vec3(153.2845, 227.5036, 108.0229),
    vec3(-480.8493, -10.7733, 46.5173),
    vec3(-275.0341, -25.0483, 50.7380),
    vec3(-283.3239, -52.7574, 50.6022),
    vec3(117.9551, -164.0182, 55.9383),
    vec3(220.0064, -201.3739, 55.1706),
    vec3(296.9405, -230.1303, 55.1724),
    vec3(-296.6239, -290.6967, 31.8260),
    vec3(-469.3233, -229.2925, 37.4411),
    vec3(-637.0059, -44.5805, 42.4216),
    vec3(-846.4009, -143.3095, 39.0920),
    vec3(-558.5587, -386.6899, 36.2819),
}

Config.Dropoffs = {
    vec3(207.2148, -85.1660, 69.1744),
    vec3(319.9483, -121.5708, 68.3529),
    vec3(330.2487, -202.4634, 54.0863),
    vec3(229.5711, -22.3388, 74.9873),
    vec3(137.2320, -72.1489, 68.0648),
    vec3(109.9305, -152.8682, 54.8493),
    vec3(52.5765, -179.5008, 54.9767),
    vec3(-456.1684, 92.3734, 63.5468),
    vec3(-725.0157, 124.3040, 56.5726),
    vec3(-367.5248, -241.3543, 36.0801),
    vec3(-37.5273, 170.4360, 95.3650),
    vec3(223.2669, 121.7888, 102.8371),
    vec3(391.5383, 3.1162, 91.9320),
    vec3(418.6918, -207.1154, 59.9104),
    vec3(751.5035, 223.8431, 87.4230),
    vec3(252.0359, 358.6432, 105.9621),
}
