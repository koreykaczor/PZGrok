PZGR = PZGR or {}
PZGR.DIR = "PZGrok"
PZGR.OOC_KHZ = 162550
PZGR.FM_MIN = 88000
PZGR.FM_MAX = 108000

PZGR.BANDS = {
    { id = "2m",      label = "2 metre amateur", min = 144000, max = 148000, tier = 1, hf = false, hail = "CQ, CQ, anybody copy?" },
    { id = "marine",  label = "Marine VHF",      min = 156000, max = 162000, tier = 2, hf = false, hail = "Any station, this is a hailing call, over." },
    { id = "cb",      label = "Citizens band",   min = 26965,  max = 27405,  tier = 3, hf = false, hail = "Breaker breaker, anybody got their ears on?" },
    { id = "vhf-low", label = "VHF low band",    min = 33000,  max = 46000,  tier = 3, hf = false, hail = "Dispatch, anybody still on this channel?" },
    { id = "40m",     label = "40 metre amateur",min = 7000,   max = 7300,   tier = 5, hf = true,  hail = "CQ DX, CQ DX, listening." },
    { id = "80m",     label = "80 metre amateur",min = 3500,   max = 4000,   tier = 5, hf = true,  hail = "CQ eighty, CQ eighty, this is a call." },
}

function PZGR.log(msg)
    print("PZGrok: " .. tostring(msg))
end

function PZGR.sb()
    local s = SandboxVars and SandboxVars.PZGrok or {}
    return {
        radio = s.RadioStation ~= false,
        tv = s.TelevisionStation ~= false,
        survivors = s.Survivors ~= false,
        randomize = s.RandomizeCount ~= false,
        count = s.GroupCount or 3,
        ooc = s.OOC == true,
        noise = s.TransmissionNoise or 12,
        test = s.TestRadio == true,
        unknown = s.UnknownVoices ~= false,
        custom = {
            { name = s.Custom1Name or "", hook = s.Custom1Hook or "" },
            { name = s.Custom2Name or "", hook = s.Custom2Hook or "" },
            { name = s.Custom3Name or "", hook = s.Custom3Hook or "" },
        },
    }
end

function PZGR.bandFor(khz)
    for i = 1, #PZGR.BANDS do
        local b = PZGR.BANDS[i]
        if khz >= b.min and khz <= b.max then return b end
    end
    return nil
end

function PZGR.itemTier(item)
    if not item then return 0 end
    local t = item:getType() or ""
    if string.find(t, "WalkieTalkie5") or string.find(t, "HamRadio2") then return 5 end
    if string.find(t, "WalkieTalkie4") or string.find(t, "HamRadio") then return 5 end
    if string.find(t, "WalkieTalkie3") then return 3 end
    if string.find(t, "WalkieTalkie2") then return 2 end
    if string.find(t, "WalkieTalkie") then return 1 end
    return 0
end

function PZGR.canTune(tier, khz)
    if khz >= PZGR.FM_MIN and khz <= PZGR.FM_MAX then return true end
    if khz == PZGR.OOC_KHZ then return tier >= 2 end
    local b = PZGR.bandFor(khz)
    if not b then return false end
    return tier >= b.tier
end

function PZGR.day()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getNightsSurvived() or 0
end

function PZGR.hour()
    local gt = getGameTime()
    if not gt then return 9 end
    return gt:getHour() or 9
end

function PZGR.minute()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getMinutes() or 0
end

local MONTHS = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

function PZGR.dateString()
    local gt = getGameTime()
    local y, m, d = 1993, 7, 9
    if gt then
        if gt.getYear then y = gt:getYear() or y end
        if gt.getMonth then
            local mo = gt:getMonth()
            -- PZ months are 0-indexed.
            if mo ~= nil then m = (mo % 12) + 1 end
        end
        if gt.getDay then d = gt:getDay() or d end
    end
    local hh = string.format("%02d", PZGR.hour())
    local mm = string.format("%02d", PZGR.minute())
    return (MONTHS[m] or "July") .. " " .. tostring(d) .. ", " .. tostring(y) .. "  " .. hh .. ":" .. mm
end

function PZGR.lifeEra(day)
    day = day or 0
    if day <= 4 then return "era 1, days 0-4" end
    if day <= 9 then return "era 2, days 5-9" end
    if day <= 17 then return "era 3, days 10-17" end
    return "era 4, day 18+"
end

function PZGR.knowledgeBeat(day)
    day = day or 0
    if day <= 0 then
        return 'A "situation" in Kentucky. Forest and farmland cut off, roads blocked, border patrolled. No mention of illness.'
    elseif day == 1 then
        return 'Experts on air speculating. Still "the Knox situation".'
    elseif day == 2 then
        return "Rioting nationwide — Washington, Detroit, Los Angeles. Looting, running battles with police."
    elseif day == 3 then
        return "Public anger at the government. A confirmed fatality in New York."
    elseif day == 4 then
        return '"Conflict is endemic throughout the Exclusion Zone."'
    elseif day == 5 then
        return 'General John McGrew: the Knox Event is "degenerative", causes "panic and confusion", and "Sufferers are NOT deceased."'
    elseif day == 6 then
        return "Pitched battles between civilians and troops inside the zone. Gunfire, tear gas."
    elseif day == 7 then
        return "The second wave. Confirmed spreading without any contact with an infected body. Flu-like symptoms. Stay in your homes."
    elseif day == 8 then
        return "Confirmed in Louisville and surrounding area, Cincinnati, Columbus, London, Mogadishu. Worldwide."
    elseif day <= 10 then
        return 'McGrew, to those unaffected by the second wave: it spreads by bites. "They may be your family."'
    end
    return 'Recorded loops. "An unknown plague known as the Knox Infection has taken hold on America." Then the broadcasts stop.'
end

function PZGR.md()
    return ModData.getOrCreate("PZGrok")
end
