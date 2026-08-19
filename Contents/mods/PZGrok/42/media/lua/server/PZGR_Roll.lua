PZGR = PZGR or {}

local FIRST_M = { "Dwight","Dale","Hank","Earl","Calvin","Buddy","Floyd","Wayne","Jerry","Ron","Steve","Todd","Glenn","Lester","Clay","Ray" }
local FIRST_F = { "Verna","Ruth","Cora","Patsy","Jean","Marlene","Bonnie","Delores","Kathy","Linda","Sharon","Peggy","Wanda","Connie" }
local SURNAMES = { "Cline","Hobbs","Rucker","Pate","Mattingly","Keeling","Burch","Hendricks","Logsdon","Phelps","Whitaker","Gossett" }
local VOICES = { "gravelly voice","thin tired voice","smoker rasp","young voice trying to sound sure","even practiced voice","someone too close to the mic","flat Indiana voice","a woman who does not waste words" }
local JOBS = { "lockmaster","auto-parts counter","river barge deckhand","church secretary","volunteer fire","diner night cook","high school shop teacher","soy and corn farm","ham radio club treasurer","marina clerk" }
local COUNTIES = { "Clark County, Indiana","Floyd County, Indiana","Harrison County, Indiana" }
local DISTANT = { "a basement in Toledo, Ohio","a ranch outside Amarillo, Texas","a fishing camp in the Upper Peninsula","a suburb of Cincinnati","a farmhouse west of Springfield, Missouri" }
local CALLS = { "WKNT","WQIN","WANK","WOHI","WRIZ","WFLR","WBLU" }
local RNAMES = { "Kentuckiana Country","River City FM","The Tick","Ohio Valley Gold","Sunrise 96" }
local HOSTS = { "Dale Hopper","Connie Brisk","Mike Ellis","Rita Calhoun","Jumpin Jay Rhodes" }
local PRESETS = { "MOM","CHURCH","STILL ON","DO NOT","HOME","DAD","BASE","WORK","UNIT","SCAN","SKIP","DEAD?","911","BOAT","FARM" }

local function ri(n) return ZombRand(n) end
local function pick(t) return t[ZombRand(#t) + 1] end

local function person(used, operator, job)
    local pool = (ZombRand(2) == 0) and FIRST_F or FIRST_M
    local name = pick(pool)
    local g = 0
    while used[name] and g < 12 do name = pick(pool); g = g + 1 end
    used[name] = true
    return {
        name = name, voice = pick(VOICES), operator = operator, backup = false,
        alive = true, nameKnown = false,
        color = { 0.4 + ZombRand(50)/100, 0.5 + ZombRand(40)/100, 0.35 + ZombRand(40)/100 },
        job = job,
    }
end

local function size()
    local r = ZombRand(100)
    if r < 18 then return 1 elseif r < 40 then return 2 elseif r < 60 then return 3
    elseif r < 76 then return 4 elseif r < 88 then return 5 elseif r < 94 then return 6
    else return 2 + ZombRand(5) end
end

local function startDay()
    if ZombRand(2) == 0 then return 0 end
    return 1 + ZombRand(14)
end

local function assignBands(n)
    local order = {}
    for i = 1, #PZGR.BANDS do order[i] = i end
    for i = #order, 2, -1 do
        local j = ZombRand(i) + 1
        order[i], order[j] = order[j], order[i]
    end
    local out = {}
    for i = 1, n do out[i] = PZGR.BANDS[order[((i - 1) % #order) + 1]] end
    return out
end

local function snap(band, raw)
    local s = math.floor((raw / 5) + 0.5) * 5
    if s < band.min then s = band.min end
    if s > band.max then s = band.max end
    return s
end

local function rollGroup(index, band, custom)
    local used = {}
    local n = size()
    local people = { person(used, true, pick(JOBS)) }
    for i = 2, n do people[i] = person(used, false, pick(JOBS)) end
    local loc, distant
    if band.hf then
        loc = pick(DISTANT); distant = true
    else
        loc = pick(COUNTIES); distant = false
    end
    local freq = snap(band, band.min + ZombRand(band.max - band.min + 1))
    local surname = pick(SURNAMES)
    local place = custom and custom.name ~= "" and custom.name or ("the " .. surname .. " place")
    return {
        uuid = "PZGR-GRP-" .. tostring(index) .. "-" .. tostring(100000 + ZombRand(900000)),
        index = index, placeName = place, placeKnown = false,
        band = band.id, frequencyKhz = freq, county = loc, distant = distant,
        startDay = startDay(), people = people, operatorName = people[1].name,
        silentForever = false,
        customHook = custom and custom.hook or "",
        lastContactDay = -1, invented = false,
    }
end

local function rollStation(kind)
    if kind == "radio" then
        return {
            kind = "radio", callsign = pick(CALLS), name = pick(RNAMES), host = pick(HOSTS),
            frequencyKhz = 88000 + ZombRand(200) * 100, format = "country and farm",
        }
    end
    return {
        kind = "tv", callsign = pick(CALLS), name = "Channel 3 News", host = pick(HOSTS),
        frequencyKhz = 210000 + ZombRand(8) * 6000, format = "local news",
    }
end

function PZGR.ensureRoll()
    local md = PZGR.md()
    if md.rolled then return md end
    local sb = PZGR.sb()
    local n = sb.survivors and (sb.randomize and (1 + ZombRand(15)) or sb.count) or 0
    if n < 0 then n = 0 end
    if n > 15 then n = 15 end
    local customs = {}
    for i = 1, #sb.custom do
        local c = sb.custom[i]
        if c.name ~= "" or c.hook ~= "" then customs[#customs + 1] = c end
    end
    local bands = assignBands(math.max(n + #customs, 1))
    local groups = {}
    for i = 1, n do
        groups[i] = rollGroup(i, bands[i], nil)
    end
    for i = 1, #customs do
        groups[#groups + 1] = rollGroup(#groups + 1, bands[((#groups) % #bands) + 1], customs[i])
    end
    md.groups = groups
    md.radio = rollStation("radio")
    md.tv = rollStation("tv")
    md.presets = PRESETS
    md.characterGen = 1
    md.rolled = true
    md.seq = 1
    ModData.add("PZGrok", md)
    PZGR.log("rolled " .. tostring(#groups) .. " groups; FM " .. tostring(md.radio.frequencyKhz) .. " " .. md.radio.callsign)
    for i = 1, #groups do
        local g = groups[i]
        PZGR.log("group " .. g.uuid .. " " .. g.band .. " " .. tostring(g.frequencyKhz) .. " start day " .. tostring(g.startDay))
    end
    return md
end

Events.OnGameStart.Add(function()
    PZGR.ensureRoll()
end)
