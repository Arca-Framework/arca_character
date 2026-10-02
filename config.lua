CharConfig = {
    -- Selection scene: the preview ped stands at Ped, the camera films it from Camera.
    -- Default is the living room of Michael's house (always loaded, no IPL needed).
    Scene = {
        ped = vector4(-813.97, 176.22, 76.74, -7.5),
        camera = vector3(-813.40, 179.10, 76.95),
        lookAt = vector3(-813.97, 176.22, 76.55),
        fov = 48.0,
        hour = 12,
        -- idle animation for the preview ped
        anim = { dict = 'anim@heists@heist_corona@single_team', clip = 'single_team_loop_boss' },
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
