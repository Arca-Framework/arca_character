CharConfig = {
    -- where the (hidden) player waits while choosing a character
    HiddenCoords = vector4(-1355.9, -1487.8, 520.7, 0.0),

    -- scenic camera shown behind the menu
    Camera = {
        coords = vector3(-1355.9, -1487.8, 520.7),
        pointAt = vector3(-280.0, -1000.0, 200.0),
        fov = 50.0,
    },

    -- hand off to arca_spawn (event 'arca_spawn:client:open') instead of spawning at last position
    UseSpawnSelector = false,

    -- Clothing / appearance. Used automatically when the resource is started.
    Appearance = {
        Resource = 'illenium-appearance',
        -- menus shown to a freshly created character
        Customization = {
            ped = false,
            headBlend = true,
            faceFeatures = true,
            headOverlays = true,
            components = true,
            props = true,
            tattoos = true,
            allowExit = false,
        },
    },

    Models = {
        [0] = `mp_m_freemode_01`, -- male
        [1] = `mp_f_freemode_01`, -- female
    },

    Nationalities = { 'American', 'British', 'Canadian', 'Mexican', 'German', 'French', 'Italian', 'Other' },

    MinAge = 18,
    MaxAge = 90,
}
