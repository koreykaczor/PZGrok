PZGR = PZGR or {}

local function addPreset(item, name, khz)
    local data = item.getDeviceData and item:getDeviceData()
    if not data then return false end
    if data.addPreset then
        pcall(function() data:addPreset(name, khz) end)
        return true
    end
    if data.getDevicePresets then
        local presets = data:getDevicePresets()
        if presets and presets.addPreset then
            pcall(function() presets:addPreset(name, khz) end)
            return true
        end
    end
    return false
end

local function alreadySeeded(item)
    local md = item.getModData and item:getModData()
    return md and md.PZGrokSeeded
end

local function mark(item)
    local md = item.getModData and item:getModData()
    if md then md.PZGrokSeeded = true end
end

local function seedItem(item)
    if not item or alreadySeeded(item) then return end
    if PZGR.itemTier(item) < 1 then return end
    local md = PZGR.md()
    if not md.groups then return end
    local names = md.presets or { "MOM", "CHURCH", "HOME" }
    local n = 2 + ZombRand(4)
    local live = ZombRand(6) == 0
    local tier = PZGR.itemTier(item)
    if live then
        local candidates = {}
        for i = 1, #md.groups do
            local g = md.groups[i]
            if PZGR.canTune(tier, g.frequencyKhz) then
                candidates[#candidates + 1] = g
            end
        end
        if #candidates > 0 then
            local g = candidates[ZombRand(#candidates) + 1]
            addPreset(item, names[ZombRand(#names) + 1], g.frequencyKhz)
            n = n - 1
        end
    end
    for i = 1, n do
        local b = PZGR.BANDS[ZombRand(#PZGR.BANDS) + 1]
        if tier >= b.tier then
            local khz = b.min + ZombRand(b.max - b.min)
            addPreset(item, names[((i - 1) % #names) + 1], khz)
        end
    end
    mark(item)
end

function PZGR.seedContainer(container)
    if not container then return end
    local items = container.getItems and container:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        seedItem(items:get(i))
    end
end

function PZGR.seedPlayer(player)
    if not player then return end
    local inv = player.getInventory and player:getInventory()
    PZGR.seedContainer(inv)
end

Events.OnFillContainer.Add(function(roomName, containerType, container)
    PZGR.seedContainer(container)
end)

Events.EveryTenMinutes.Add(function()
    local players = getOnlinePlayers and getOnlinePlayers()
    if IsoPlayer and IsoPlayer.getInstance then
        PZGR.seedPlayer(IsoPlayer.getInstance())
    end
    if getSpecificPlayer then
        PZGR.seedPlayer(getSpecificPlayer(0))
    end
end)
