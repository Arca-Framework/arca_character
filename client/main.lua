local cam
local isOpen = false

local function hidePlayer(state)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not state, false)
    FreezeEntityPosition(ped, state)
    SetEntityInvincible(ped, state)
    SetPlayerControl(PlayerId(), not state, 0)
end

local function createCamera()
    local c = CharConfig.Camera
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.coords.x, c.coords.y, c.coords.z, 0.0, 0.0, 0.0, c.fov, false, 2)
    PointCamAtCoord(cam, c.pointAt.x, c.pointAt.y, c.pointAt.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function destroyCamera()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end

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

    local h = CharConfig.HiddenCoords
    local ped = PlayerPedId()
    SetEntityCoords(ped, h.x, h.y, h.z, false, false, false, false)
    hidePlayer(true)
    createCamera()

    refresh()
    SetNuiFocus(true, true)
    DoScreenFadeIn(500)
end

local function closeSelection()
    isOpen = false
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
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

local function appearanceResource()
    local res = CharConfig.Appearance.Resource
    return GetResourceState(res) == 'started' and res or nil
end

---Opens the appearance editor for a new character and saves the result
local function openCustomization(res)
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
    destroyCamera()
    SetNuiFocus(false, false)
    hidePlayer(false)
end)
