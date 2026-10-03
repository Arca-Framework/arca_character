local cam
local isOpen = false
local previewPed
local previewToken = 0 -- bumps on every preview change so slow loads don't overwrite newer ones

local function hidePlayer(state)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not state, false)
    FreezeEntityPosition(ped, state)
    SetEntityInvincible(ped, state)
    SetEntityCollision(ped, not state, not state)
    SetPlayerControl(PlayerId(), not state, 0)
end

---Camera in front of the scene ped, looking at its waist
local function sceneCamera()
    local s = CharConfig.Scene
    local h = math.rad(s.ped.w)
    local forward = vec3(-math.sin(h), math.cos(h), 0.0)
    local pos = vec3(s.ped.x, s.ped.y, s.ped.z) + forward * s.distance
    return vec3(pos.x, pos.y, s.ped.z + s.height), vec3(s.ped.x, s.ped.y, s.ped.z)
end

local function createCamera()
    local pos, target = sceneCamera()
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, CharConfig.Scene.fov, false, 2)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function destroyCamera()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end

local function appearanceResource()
    local res = CharConfig.Appearance.Resource
    return GetResourceState(res) == 'started' and res or nil
end

---------------------------------------------------------------------
-- Preview ped
---------------------------------------------------------------------
local function deletePreview()
    if previewPed and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
    previewPed = nil
end

local function loadModel(model)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return nil end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(model) and model or nil
end

---Shows a character (or a blank male/female for new slots) standing in the scene
---@param gender number
---@param skin table|nil illenium-appearance data
local function showPreview(gender, skin)
    previewToken = previewToken + 1
    local token = previewToken

    local model = loadModel(skin and skin.model or CharConfig.Models[gender] or CharConfig.Models[0])
    if not model then
        print(('^3[arca_character] could not load preview model %s^7'):format(tostring(skin and skin.model or gender)))
        model = loadModel(CharConfig.Models[gender] or CharConfig.Models[0])
        skin = nil
    end
    if not model or token ~= previewToken then return end

    deletePreview()
    local p = CharConfig.Scene.ped
    RequestCollisionAtCoord(p.x, p.y, p.z)

    -- spawn slightly above the floor and let it settle, so a wrong z can't bury it
    local ped = CreatePed(2, model, p.x, p.y, p.z, p.w, false, true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then
        print('^1[arca_character] failed to create preview ped^7')
        return
    end
    previewPed = ped
    SetEntityHeading(ped, p.w)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    local res = appearanceResource()
    if skin and res then
        local ok, err = pcall(function() exports[res]:setPedAppearance(ped, skin) end)
        if not ok then
            print(('^3[arca_character] setPedAppearance failed: %s^7'):format(err))
            SetPedDefaultComponentVariation(ped)
        end
    else
        SetPedDefaultComponentVariation(ped)
    end

    local anim = CharConfig.Scene.anim
    if anim then
        RequestAnimDict(anim.dict)
        local timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(0) end
    end

    Wait(300)
    if token ~= previewToken or not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, true)
    if anim and HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 2.0, 2.0, -1, 1, 0, false, false, false)
    end

    -- aim the camera at where the ped actually ended up
    if cam then
        local c = GetEntityCoords(ped)
        PointCamAtCoord(cam, c.x, c.y, c.z)
    end
end

---------------------------------------------------------------------
-- Selection screen
---------------------------------------------------------------------
local function refresh()
    local characters, maxSlots, nationalities = Arca.Callback.Await('arca_character:getCharacters')
    SendNUIMessage({
        action = 'open',
        data = { characters = characters or {}, maxSlots = maxSlots or 1, nationalities = nationalities or {} },
    })
end

local function openSelection()
    if isOpen then return end
    isOpen = true

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    -- park the hidden player inside the scene so the interior streams in
    local p = sceneCamera()
    local ped = PlayerPedId()
    SetEntityCoords(ped, p.x, p.y, p.z - 1.0, false, false, false, false)
    hidePlayer(true)
    DisplayRadar(false)
    NetworkOverrideClockTime(CharConfig.Scene.hour or 12, 0, 0)

    local timeout = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

    createCamera()
    refresh()
    SetNuiFocus(true, true)
    DoScreenFadeIn(500)
end

local function closeSelection()
    isOpen = false
    previewToken = previewToken + 1
    deletePreview()
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    NetworkClearClockTimeOverride()
end

local function applyModel(gender)
    local model = CharConfig.Models[gender] or CharConfig.Models[0]
    if GetEntityModel(PlayerPedId()) == model then return end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    SetPlayerModel(PlayerId(), model)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(model)
end

---Opens the appearance editor for a new character and saves the result
local function openCustomization(res)
    -- Arca's illenium-appearance fork handles new characters itself (starter clothes, routing bucket, saving)
    if GetResourceMetadata(res, 'arca_support', 0) == 'yes' then
        TriggerEvent('illenium-appearance:client:arcaCreateFirstCharacter')
        return
    end

    exports[res]:startPlayerCustomization(function(appearance)
        -- allowExit can be enabled in config; fall back to whatever the ped is wearing
        appearance = appearance or exports[res]:getPedAppearance(PlayerPedId())
        TriggerServerEvent('arca_character:server:saveAppearance', appearance)
    end, CharConfig.Appearance.Customization)
end

local function spawn(data)
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    closeSelection()
    destroyCamera()

    local res = appearanceResource()
    local appearance = res and Arca.Callback.Await('arca_character:getAppearance')
    if appearance then
        exports[res]:setPlayerAppearance(appearance)
    else
        applyModel(data.charinfo and data.charinfo.gender or 0)
    end
    local needsCustomization = res ~= nil and not appearance

    if CharConfig.UseSpawnSelector and not needsCustomization and GetResourceState('arca_spawn') == 'started' then
        hidePlayer(false)
        TriggerEvent('arca_spawn:client:open', data)
        return
    end

    local pos = data.position
    local ped = PlayerPedId()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.w or 0.0)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

    hidePlayer(false)
    DoScreenFadeIn(750)
    if needsCustomization then openCustomization(res) end
    TriggerEvent('arca_character:client:spawned', data)
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
AddEventHandler('arca_core:client:onPlayerLoaded', function(data)
    if isOpen then spawn(data) end
end)

AddEventHandler('arca_core:client:onPlayerUnloaded', function()
    openSelection()
end)

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
RegisterNUICallback('preview', function(data, cb)
    cb(1)
    if data.citizenid then
        local info = Arca.Callback.Await('arca_character:getPreview', data.citizenid)
        if not info then print('^3[arca_character] no preview data for ' .. tostring(data.citizenid) .. '^7') end
        if isOpen then showPreview(info and info.gender or 0, info and info.skin) end
    else
        showPreview(tonumber(data.gender) or 0, nil)
    end
end)

RegisterNUICallback('select', function(data, cb)
    local ok = Arca.Callback.Await('arca_character:select', data.citizenid)
    cb({ ok = ok })
end)

RegisterNUICallback('create', function(data, cb)
    local ok, err = Arca.Callback.Await('arca_character:create', data)
    cb({ ok = ok, error = err })
end)

RegisterNUICallback('delete', function(data, cb)
    local ok = Arca.Callback.Await('arca_character:delete', data.citizenid)
    cb({ ok = ok })
    if ok then refresh() end
end)

---------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    if GetResourceState('spawnmanager') == 'started' then
        exports.spawnmanager:setAutoSpawn(false)
    end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    if not exports.arca_core:IsLoggedIn() then
        openSelection()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not isOpen then return end
    deletePreview()
    destroyCamera()
    SetNuiFocus(false, false)
    hidePlayer(false)
end)
