local cooldown = {}
local COOLDOWN = Config.CooldownSeconds

local QBCore = exports['qb-core']:GetCoreObject()

-- ========= Rep helpers (QBCore metadata) =========
local function getRep(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    local md = Player.PlayerData.metadata or {}
    return md.scavrep or 0
end

local function setRep(src, value)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.SetMetaData('scavrep', value)
    TriggerClientEvent('vx_bins:repUpdated', src, value)
end

local function addRep(src, amount)
    local cur = getRep(src)
    setRep(src, cur + (amount or 0))
end

exports('GetScavRep', function(src) return getRep(src) end)
exports('AddScavRep', function(src, amount) addRep(src, amount) end)
exports('SetScavRep', function(src, value) setRep(src, value) end)

lib.callback.register('vx_bins:getRep', function(source, target)
    local src = target or source
    return getRep(src)
end)
-- =================================================

local function getIdentifiers(src)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        local k, v = id:match('([^:]+):(.+)')
        if k and v then ids[k] = v end
    end
    return ids
end

local function fmKey()
    local k = GetConvar('fivemerr:key', '')
    if k == '' then k = GetConvar('fivemerr:apiToken', '') end
    return k
end

local function sendFiveMerrLog(event, message, fields)
    if not Config.FiveMerr or not Config.FiveMerr.enabled then return end

    -- 1) Prefer fm-logs resource if it’s running
    if Config.FiveMerr.useFmLogsResource and GetResourceState('fm-logs') == 'started' then
        -- Try common export name
        local ok = pcall(function()
            -- export style (some versions): exports['fm-logs']:log(event, message, fields)
            if exports['fm-logs'] and exports['fm-logs'].log then
                exports['fm-logs']:log(event, message, fields)
            else
                -- event style (other versions)
                TriggerEvent('fm-logs:log', event, message, fields)
            end
        end)
        if ok then return end
        -- fall through to direct API if export/event isn’t present
    end

    -- 2) Fallback: direct API call
    local key = fmKey()
    if key == '' then
        print('[vx_bins] FiveMerr logging skipped (no API token convar set)')
        return
    end

    local body = {
        event = event,        -- e.g. "bins:search"
        message = message,    -- short description
        fields = fields or {},-- array of { name=..., value=..., inline=bool }
        service = Config.FiveMerr.service
    }

    PerformHttpRequest(
        'https://api.fivemerr.com/v1/logs',
        function() end,
        'POST',
        json.encode(body),
        {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = key,
            ['User-Agent'] = 'vx_bins'
        }
    )
end


local function getCharacterName(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.charinfo then
        return nil
    end
    local ci = Player.PlayerData.charinfo
    local first = ci.firstname or ci.firstName or ''
    local last  = ci.lastname  or ci.lastName  or ''
    local fullname = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if fullname == '' then return nil end
    return fullname
end

local function sendWebhook(payload)
    if not Config.Webhook or not Config.Webhook.enabled or not Config.Webhook.url or Config.Webhook.url == '' then return end
    local body = {
        username = Config.Webhook.username or 'VX Bins',
        avatar_url = Config.Webhook.avatar or nil,
        embeds = {{
            title = payload.title or 'Bin Search',
            description = payload.description or '',
            color = payload.color or 5793266,
            fields = payload.fields or {},
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    if Config.Webhook.mentionRoleId and Config.Webhook.mentionRoleId ~= '' then
        body.content = string.format('<@&%s>', Config.Webhook.mentionRoleId)
    end
    PerformHttpRequest(Config.Webhook.url, function() end, 'POST', json.encode(body), { ['Content-Type'] = 'application/json' })
end

-- FiveMerr log
sendFiveMerrLog(
    'bins:search',
    string.format('%s (%s) searched a bin: %s', name, rpName, lootText),
    fields -- re-use the same fields you built for Discord (Player, RP, Bin Key, Coords, IDs)
)

local function makeBinKey(model, coords)
    local x = math.floor(coords.x + 0.5)
    local y = math.floor(coords.y + 0.5)
    local z = math.floor(coords.z + 0.5)
    return ('%s:%d:%d:%d'):format(model, x, y, z)
end

lib.callback.register('vx_bins:getBinKey', function(source, model, coords)
    if not model or not coords or not coords.x then return nil end
    return makeBinKey(model, coords)
end)

lib.callback.register('vx_bins:canSearch', function(source, binKey)
    if not binKey then return false, COOLDOWN end
    local now = os.time()
    local last = cooldown[binKey] or 0
    local remaining = (last + COOLDOWN) - now
    if remaining > 0 then
        return false, remaining
    end
    return true, 0
end)

local function effectiveChance(baseChance, tier, rep)
    tier = tier or 1
    rep = rep or 0
    local steps = math.floor((rep or 0) / (Config.Rep.repPerStep or 25))
    local per = Config.Rep.tierBonusStep or 1
    local cap = Config.Rep.maxTierBonus or 10
    local bonusPerTier = math.min(cap, steps * per) -- e.g. +1 per 25 rep capped at 10
    local bonus = (tier - 1) * bonusPerTier        -- tier1 gets 0, tier2=+bonusPerTier, tier3=+2*bonusPerTier
    local out = math.min(100, (baseChance or 0) + bonus)
    return out
end

local function rollLoot(single, rep)
    local awarded = {}
    if single then
        local pool = {}
        local total = 0
        for _, e in ipairs(Config.LootTable) do
            local eff = effectiveChance(e.chance or 0, e.tier, rep)
            if eff > 0 then
                total = total + eff
                table.insert(pool, {ref=e, acc=total, eff=eff})
            end
        end
        if total == 0 then return awarded end
        local r = math.random(1, total)
        for _, b in ipairs(pool) do
            if r <= b.acc then
                local count = math.random(b.ref.min or 1, b.ref.max or 1)
                table.insert(awarded, { item = b.ref.item, count = count })
                break
            end
        end
    else
        for _, e in ipairs(Config.LootTable) do
            local eff = effectiveChance(e.chance or 0, e.tier, rep)
            local roll = math.random(1, 100)
            if roll <= eff then
                local count = math.random(e.min or 1, e.max or 1)
                table.insert(awarded, { item = e.item, count = count })
            end
        end
    end
    return awarded
end

lib.callback.register('vx_bins:finishSearch', function(source, binKey)
    if not binKey then return false end
    local now = os.time()
    cooldown[binKey] = now

    -- get rep for scaling
    local rep = getRep(source)

    local items = rollLoot(Config.SingleRoll, rep)

    local given = {}
    for _, it in ipairs(items) do
        local ok = exports.ox_inventory:AddItem(source, it.item, it.count or 1)
        if ok then
            table.insert(given, it)
        end
    end

    -- 5% chance to gain rep (configurable)
    if #given > 0 then
        local chance = Config.Rep.gainChance or 5
        if math.random(1, 100) <= chance then
            addRep(source, Config.Rep.gainAmount or 1)
        end
    end

    local name = GetPlayerName(source) or 'Unknown'
    local rpName = getCharacterName(source) or 'Unknown'
    local ids = getIdentifiers(source)
    local ped = GetPlayerPed(source)
    local coords = ped and GetEntityCoords(ped) or vector3(0,0,0)

    local fields = {
        { name = 'Player (Rockstar)', value = tostring(name), inline = true },
        { name = 'Character (RP)',    value = tostring(rpName), inline = true },
        { name = 'Rep',               value = tostring(getRep(source)), inline = true },
        { name = 'Bin Key',           value = binKey, inline = true },
        { name = 'Coords',            value = string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z), inline = true },
    }
    if ids.license then table.insert(fields, { name = 'License', value = ids.license, inline = true }) end
    if ids.discord then table.insert(fields, { name = 'Discord', value = ids.discord, inline = true }) end
    if ids.steam   then table.insert(fields, { name = 'Steam',   value = ids.steam,   inline = true }) end

    local lootText = (#given > 0) and table.concat((function()
        local t = {}
        for _, it in ipairs(given) do t[#t+1] = (it.count .. 'x ' .. it.item) end
        return t
    end)(), ', ') or 'None'

    sendWebhook({
        title = 'Bin Bag Search Result',
        description = string.format('**%s** (%s) searched a bin bag and received: %s', name, rpName, lootText),
        color = (#given > 0) and 3066993 or 15158332,
        fields = fields
    })

    return #given > 0, given
end)
