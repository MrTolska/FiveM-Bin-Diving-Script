Config = {}

-- Dumpsters to target
Config.DumpsterModels = {
    `prop_dumpster_01a`,
    `prop_dumpster_02a`,
    `prop_dumpster_02b`,
}

-- Single, better-centred bag prop
Config.BagProp = `prop_cs_rub_binbag_01`

-- Where/how to attach the bag
Config.BagAttach = {
    bone = 57005, -- right hand
    pos = { x = 0.08, y = 0.02, z = -0.02 },
    rot = { x = 240.0, y = 90.0, z = -10.0 }
}

-- Progress UI
Config.Grab = {
    duration = 4500,
    label = 'Grabbing A Bin Bag...',
    canCancel = true
}

Config.Search = {
    duration = 10000,
    label = 'Rummaging Through Bag...',
    canCancel = true
}

-- Text UI while holding a bag (ox_lib)
Config.TextUI = {
    enabled = true,
    text = '[E] Search Bag   •   [G] Discard Bag',
    position = 'right-center' -- ox_lib positions: 'left-center', 'right-center', etc.
}

-- Rep system (stored in QBCore PlayerData.metadata.scavrep)
Config.Rep = {
    gainChance = 5,      -- % chance to gain rep per successful search
    gainAmount = 1,      -- how much rep to add when it triggers
    repPerStep = 25,     -- each 25 rep increases bonus by tierBonusStep
    tierBonusStep = 1,   -- +1% chance per tier step per rep step
    maxTierBonus = 10    -- cap per tier (so tier 3 max +30% total)
}

-- Cooldowns
Config.CooldownSeconds = 900
Config.ProdCooldownSeconds = 900

-- Loot table
-- Add 'tier' to mark "better" items. Higher tiers benefit more from rep.
Config.LootTable = {
    { item = 'plastic',     chance = 35, min = 1, max = 3, tier = 1 },
    { item = 'scrapmetal',  chance = 30, min = 1, max = 2, tier = 1 },
    { item = 'rubber',      chance = 22, min = 1, max = 2, tier = 1 },
    { item = 'aluminium',   chance = 15, min = 1, max = 1, tier = 2 },
    { item = 'mystery_key', chance =  3, min = 1, max = 1, tier = 3 },
}

-- If true, select only ONE item per search by weighted chance.
Config.SingleRoll = false

-- Labels
Config.TargetLabelGrab = 'Grab Bin Bag'

-- Discord webhook logging
Config.Webhook = {
    enabled = false,
    url = 'https://discord.com/api/webhooks/1403847942569459895/LVf_laobNpdk737yoj_bb5osOLh_MJP_lOQ3A5Mmfc9Jc7Wo1RA5OyeSRhx9vfEOm5qR',
    username = 'VX Bins',
    avatar = '',
    mentionRoleId = ''
}

-- FiveMerr logging
Config.FiveMerr = {
    enabled = true,            -- turn off if you only want Discord
    useFmLogsResource = true,  -- try to log via fm-logs resource first
    service = 'BinSearching'        -- just a label/tag for your dashboards
}
