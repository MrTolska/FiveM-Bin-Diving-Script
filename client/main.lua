local holdingBag = false
local bagEntity = nil
local lastBinKey = nil
local textUIShown = false

local function progress(cfg)
    if lib and lib.progressCircle then
        return lib.progressCircle({
            duration = cfg.duration,
            label = cfg.label,
            position = 'bottom',
            useWhileDead = false,
            canCancel = cfg.canCancel,
            disable = { move = true, car = true, combat = true },
        })
    else
        Wait(cfg.duration)
        return true
    end
end

local function attachBagProp(ped)
    local model = Config.BagProp
    RequestModel(model)
    local start = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(0)
        if GetGameTimer() - start > 3000 then return nil end
    end
    local pos = GetEntityCoords(ped)
    local obj = CreateObject(model, pos.x, pos.y, pos.z, true, true, false)
    local bone = GetPedBoneIndex(ped, Config.BagAttach.bone or 57005)
    AttachEntityToEntity(
        obj, ped, bone,
        Config.BagAttach.pos.x, Config.BagAttach.pos.y, Config.BagAttach.pos.z,
        Config.BagAttach.rot.x, Config.BagAttach.rot.y, Config.BagAttach.rot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function entityKeyFromServer(entity)
    local coords = GetEntityCoords(entity)
    local mdl = GetEntityModel(entity)
    return lib.callback.await('vx_bins:getBinKey', false, mdl, coords)
end

local function hideTextUI()
    if textUIShown then
        lib.hideTextUI()
        textUIShown = false
    end
end

local function showTextUI()
    if not Config.TextUI.enabled then return end
    if not textUIShown then
        local options = {}
        if Config.TextUI.position then options.position = Config.TextUI.position end
        lib.showTextUI(Config.TextUI.text or '[E] Search • [G] Discard', options)
        textUIShown = true
    end
end

local function clearBag()
    hideTextUI()
    if bagEntity and DoesEntityExist(bagEntity) then
        DetachEntity(bagEntity, true, true)
        DeleteObject(bagEntity)
    end
    bagEntity = nil
    holdingBag = false
    lastBinKey = nil
end

local function grabBag(entity)
    if holdingBag then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    local binKey = entityKeyFromServer(entity)
    if not binKey then
        if lib and lib.notify then lib.notify({ type = 'error', description = 'Can’t identify this bin' }) end
        return
    end

    local ok, remaining = lib.callback.await('vx_bins:canSearch', false, binKey)
    if not ok then
        if lib and lib.notify then lib.notify({ type = 'error', description = ('This bin looks empty. Try again in %ds'):format(remaining or 0) }) end
        return
    end

    -- Rummage/search style emote at the dumpster
    RequestAnimDict('amb@prop_human_bum_bin@idle_a')
    while not HasAnimDictLoaded('amb@prop_human_bum_bin@idle_a') do Wait(0) end
    TaskPlayAnim(ped, 'amb@prop_human_bum_bin@idle_a', 'idle_a', 4.0, -4.0, -1, 49, 0, false, false, false)

    local done = progress(Config.Grab)
    ClearPedTasks(ped)

    if not done then
        if lib and lib.notify then lib.notify({ type = 'inform', description = 'You stopped.' }) end
        return
    end

    local obj = attachBagProp(ped)
    if not obj then
        if lib and lib.notify then lib.notify({ type = 'error', description = 'Failed to grab a bag.' }) end
        return
    end

    holdingBag = true
    bagEntity = obj
    lastBinKey = binKey

    if lib and lib.notify then lib.notify({ type = 'success', description = 'You grabbed a bin bag.' }) end
    showTextUI()
end

local function searchBag()
    if not holdingBag or not lastBinKey then return end
    local ped = PlayerPedId()

    RequestAnimDict('amb@prop_human_bum_bin@idle_a')
    while not HasAnimDictLoaded('amb@prop_human_bum_bin@idle_a') do Wait(0) end
    TaskPlayAnim(ped, 'amb@prop_human_bum_bin@idle_a', 'idle_a', 4.0, -4.0, -1, 49, 0, false, false, false)

    local success = progress(Config.Search)
    ClearPedTasks(ped)

    if not success then
        if lib and lib.notify then lib.notify({ type = 'inform', description = 'You stopped searching.' }) end
        return
    end

    local got, items = lib.callback.await('vx_bins:finishSearch', false, lastBinKey)
    clearBag()

    if not got or not items or #items == 0 then
        if lib and lib.notify then lib.notify({ type = 'inform', description = 'Nothing useful found.' }) end
    end
end

-- Show rep updates
RegisterNetEvent('vx_bins:repUpdated', function(newRep)
    if lib and lib.notify then
        lib.notify({ type = 'success', description = ('Your rep has increased - Now: %d'):format(newRep) })
    end
end)

-- Key handler while holding a bag
CreateThread(function()
    while true do
        if holdingBag then
            showTextUI()

            DisableControlAction(0, 38, true) -- INPUT_PICKUP
            DisableControlAction(0, 51, true) -- INPUT_CONTEXT

            if IsDisabledControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 51) or IsControlJustPressed(0, 38) or IsControlJustPressed(0, 51) then
                searchBag()
            elseif IsControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 47) then -- G discard
                clearBag()
                if lib and lib.notify then lib.notify({ type = 'inform', description = 'You discarded the bag.' }) end
            end
        else
            if textUIShown then hideTextUI() end
            Wait(150)
        end
        Wait(0)
    end
end)

-- Target: Dumpsters → Grab bag
CreateThread(function()
    Wait(500)
    exports.ox_target:addModel(Config.DumpsterModels, {
        {
            name = 'vx_bins_grab',
            label = Config.TargetLabelGrab,
            icon = 'fa-solid fa-hand',
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                return not holdingBag
            end,
            onSelect = function(data)
                if data and data.entity then
                    grabBag(data.entity)
                end
            end
        }
    })
end)


-- /binrep -> shows your current scavenging rep via ox_lib notify
RegisterCommand('binrep', function()
    local rep = lib.callback.await('vx_bins:getRep', false)
    if rep == nil then rep = 0 end
    lib.notify({ type = 'inform', description = ('Scav rep: %d'):format(rep) })
end, false)

-- Optional chat suggestion (no keybind)
CreateThread(function()
    if RegisterKeyMapping then
        -- no keybind per request
    end
    TriggerEvent('chat:addSuggestion', '/binrep', 'Show your scavenging reputation')
end)
