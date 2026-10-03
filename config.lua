CharConfig = {
    -- Selection scene: the preview character stands at ped (x, y, z, heading) and the camera
    -- is placed in front of it automatically, so the character is always centred.
    -- Default is the living room of Michael's house (always loaded, no IPL needed).
    Scene = {
        ped = vector4(-813.97, 176.22, 76.74, -7.5),
        distance = 2.6,     -- camera distance in front of the character
        height = 0.1,       -- camera height relative to the character's waist
        fov = 45.0,
        hour = 12,
        -- idle animation for the preview character
        anim = { dict = 'anim@heists@heist_corona@single_team', clip = 'single_team_loop_boss' },
    },

    -- hand off to arca_spawn (event 'arca_spawn:client:open') instead of spawning at last position
    UseSpawnSelector = true,  -- falls back to last position when arca_spawn isn't running

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
