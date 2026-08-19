PZGR = PZGR or {}
PZGR.Talk = PZGR.Talk or { pending = nil, since = 0 }

local function living(g)
    local n = 0
    for i = 1, #g.people do if g.people[i].alive then n = n + 1 end end
    return n
end

local function applyEvents(g, events)
    if not events then return end
    for i = 1, #events do
        local e = events[i]
        if e.type == "death" then
            for p = 1, #g.people do
                if g.people[p].name == e.name then g.people[p].alive = false end
            end
        elseif e.type == "join" then
            g.people[#g.people + 1] = {
                name = e.name, voice = e.voice or "a new voice", operator = false,
                backup = false, alive = true, nameKnown = false, color = { 0.5, 0.7, 0.55 }, job = "new",
            }
        elseif e.type == "operator_trained" then
            for p = 1, #g.people do
                if g.people[p].name == e.name then g.people[p].backup = true end
            end
        elseif e.type == "group_silent" then
            g.silentForever = true
        end
    end
    if living(g) == 0 then g.silentForever = true end
end

local function rollEvents(g)
    local events = {}
    if g.silentForever or living(g) == 0 then
        events[1] = { type = "group_silent" }
        return events
    end
    local day = PZGR.day()
    local deathP = (day < 7 and 1 or (day < 11 and 2 or 4)) + (g.startDay == 0 and 2 or 0)
    if ZombRand(100) < deathP then
        local alive = {}
        for i = 1, #g.people do if g.people[i].alive then alive[#alive + 1] = g.people[i] end end
        if #alive > 0 then
            events[#events + 1] = { type = "death", name = alive[ZombRand(#alive) + 1].name }
        end
    end
    if ZombRand(100) < 12 then events[#events + 1] = { type = "no_answer" } end
    return events
end

function PZGR.groupForFreq(khz)
    local md = PZGR.md()
    if not md.groups then return nil end
    for i = 1, #md.groups do
        if md.groups[i].frequencyKhz == khz then return md.groups[i] end
    end
    return nil
end

function PZGR.submitTalk(khz, said)
    local g = PZGR.groupForFreq(khz)
    local sb = PZGR.sb()
    local kind = "group"
    local session = g and g.uuid or ("freq-" .. tostring(khz))
    if sb.ooc and khz == PZGR.OOC_KHZ then
        kind = "ooc"; session = "ooc"; g = nil
    end
    local events = g and rollEvents(g) or {}
    applyEvents(g, events)
    local day = PZGR.day()
    local band = g and PZGR.bandFor(g.frequencyKhz) or nil
    local members = nil
    if g then
        members = {}
        for i = 1, #g.people do
            local p = g.people[i]
            members[#members + 1] = {
                name = p.name,
                was = p.job,
                voice = p.voice,
                operator = p.operator,
                alive = p.alive,
                nameKnown = p.nameKnown,
            }
        end
    end
    local req = {
        kind = kind,
        session_id = session,
        group_id = session,
        frequency_khz = khz,
        day = day,
        hour = PZGR.hour(),
        minute = PZGR.minute(),
        date = PZGR.dateString(),
        era = PZGR.lifeEra(day),
        knowledge = PZGR.knowledgeBeat(day),
        needIdentity = false,
        said = said or "",
        hours_silent = 0,
        new_voice = false,
        events = events,
        band = band and band.id or nil,
        identity = g and {
            name = g.placeName,
            where = g.county,
            operator = g.operatorName,
            band = g.band,
            frequency_khz = g.frequencyKhz,
            start_day = g.startDay,
            distant = g.distant and true or false,
            members = members,
        } or nil,
        roster = g and { operator = g.operatorName, people = g.people } or nil,
        custom_hook = g and g.customHook or "",
        header = (g and g.placeName or kind) .. " day " .. tostring(day),
    }
    -- Structural guarantee: never write player world state.
    req.x = nil; req.y = nil; req.health = nil; req.inventory = nil
    local seq = PZGR.Bridge.write("talk_request.json", req)
    PZGR.Talk.pending = seq
    PZGR.Talk.since = PZGR._tick or 0
    PZGR.Talk.group = g
    PZGR.log("talk seq=" .. tostring(seq) .. " on " .. tostring(khz))
    return seq
end

local function airOn(khz, lines)
    local ch = PZGR.channels and (PZGR.Talk.group and PZGR.channels[PZGR.Talk.group.uuid])
    if not ch then
        -- find by uuid cache
        for uuid, c in pairs(PZGR.channels or {}) do
            if PZGR.Talk.group and uuid == PZGR.Talk.group.uuid then ch = c end
        end
    end
    if not ch then return end
    local bc = RadioBroadCast.new("GEN-" .. tostring(ZombRand(100000, 999999)), -1, -1)
    for i = 1, #lines do
        local ln = lines[i]
        local label = ln.speaker
        local g = PZGR.Talk.group
        if g and PZGR.sb().unknown then
            for p = 1, #g.people do
                if g.people[p].name == ln.speaker and not g.people[p].nameKnown then
                    label = g.people[p].voice
                end
            end
        end
        local col = { 0.55, 0.8, 0.5 }
        bc:AddRadioLine(RadioLine.new("[" .. label .. "] " .. (ln.text or ""), col[1], col[2], col[3]))
    end
    ch:setAiringBroadcast(bc)
end

function PZGR.pollTalk()
    if not PZGR.Talk.pending then return end
    local reply = PZGR.Bridge.read("talk_reply.json")
    if reply and reply.seq == PZGR.Talk.pending then
        local lines = reply.lines or {}
        if PZGR.Talk.group and reply.revealed_names then
            for i = 1, #reply.revealed_names do
                local n = reply.revealed_names[i]
                for p = 1, #PZGR.Talk.group.people do
                    if PZGR.Talk.group.people[p].name == n then
                        PZGR.Talk.group.people[p].nameKnown = true
                    end
                end
            end
        end
        if PZGR.Talk.group then
            PZGR.Talk.group.lastContactDay = PZGR.day()
            PZGR.Talk.group.invented = true
        end
        if #lines > 0 then airOn(nil, lines) end
        PZGR.Talk.pending = nil
        PZGR.log("talk reply lines=" .. tostring(#lines))
        return
    end
    -- ~100s at 30-tick poll (see Stations) ≈ 100s if OnTick every frame: 100*60=6000
    if (PZGR._tick or 0) - (PZGR.Talk.since or 0) > 6000 then
        airOn(nil, { { speaker = "carrier", text = "<no reply>" } })
        PZGR.Talk.pending = nil
        PZGR.log("talk timeout")
    end
end

Events.OnTick.Add(function()
    if not PZGR._tick then PZGR._tick = 0 end
    if PZGR._tick % 10 ~= 0 then return end
    PZGR.pollTalk()
end)

-- Unprompted hails: hourly, band-weighted, not a refill.
Events.EveryHours.Add(function()
    local md = PZGR.md()
    if not md.groups then return end
    for i = 1, #md.groups do
        local g = md.groups[i]
        if g.silentForever then break end
        if PZGR.day() < g.startDay then break end
        local p = 4
        if g.band == "cb" then p = 22 elseif g.band == "marine" or g.band == "vhf-low" then p = 12
        elseif g.band == "2m" then p = 8 end
        if ZombRand(100) < p then
            PZGR.submitTalk(g.frequencyKhz, "")
            PZGR.log("unprompted hail " .. g.uuid)
        end
    end
end)
