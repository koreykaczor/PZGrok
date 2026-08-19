PZGR = PZGR or {}

local function addLines(bc, lines, r, g, b)
    for i = 1, #lines do
        local t = lines[i].text or ""
        local sp = lines[i].speaker or ""
        bc:AddRadioLine(RadioLine.new("[" .. sp .. "] " .. t, r or 0.6, g or 0.85, b or 0.55))
    end
end

local function makeBroadcast(lines)
    local bc = RadioBroadCast.new("GEN-" .. tostring(ZombRand(100000, 999999)), -1, -1)
    addLines(bc, lines, 0.6, 0.85, 0.55)
    return bc
end

local function scriptManager()
    local radio = getZomboidRadio()
    if not radio then return nil end
    return radio:getScriptManager()
end

function PZGR.registerStations()
    local md = PZGR.ensureRoll()
    local sb = PZGR.sb()
    local sm = scriptManager()
    if not sm then return end
    PZGR.channels = PZGR.channels or {}

    local function ensure(uuid, name, freq, cat, register)
        if PZGR.channels[uuid] then return PZGR.channels[uuid] end
        local ch = DynamicRadioChannel.new(name, freq, cat, uuid)
        sm:AddChannel(ch, register and true or false)
        PZGR.channels[uuid] = ch
        PZGR.log("registered " .. name .. " @ " .. tostring(freq) .. " listed=" .. tostring(register))
        return ch
    end

    if sb.radio and md.radio then
        PZGR.radioCh = ensure("PZGR-RADIO", md.radio.callsign, md.radio.frequencyKhz, "Radio", true)
    end
    if sb.tv and md.tv then
        PZGR.tvCh = ensure("PZGR-TV", md.tv.callsign, md.tv.frequencyKhz, "Television", true)
    end
    if sb.ooc then
        PZGR.oocCh = ensure("PZGR-OOC", "Out of character", PZGR.OOC_KHZ, "Amateur", true)
    end
    if sb.survivors and md.groups then
        for i = 1, #md.groups do
            local g = md.groups[i]
            -- Hidden: register=false so they do not appear in the channel list.
            ensure(g.uuid, "---", g.frequencyKhz, "Amateur", false)
        end
    end
end

local stationPending = {}

local function requestStation(kind, station, ch)
    if not ch then return end
    local airing = ch.getAiringBroadcast and ch:getAiringBroadcast()
    if airing ~= nil then return end
    if stationPending[kind] then
        local reply = PZGR.Bridge.read("station_reply.json")
        if reply and reply.seq == stationPending[kind] and reply.lines then
            ch:setAiringBroadcast(makeBroadcast(reply.lines))
            stationPending[kind] = nil
            PZGR.log("aired " .. kind .. " " .. (reply.show or ""))
            return
        end
        -- timeout ~3 minutes of ticks handled by falling through to fallback after a deadline
        stationPending[kind .. "_age"] = (stationPending[kind .. "_age"] or 0) + 1
        if stationPending[kind .. "_age"] < 4000 then return end
        stationPending[kind] = nil
    end
    local seg = PZGR.Fallback.segment(station, PZGR.day(), PZGR.hour())
    if PZGR.Bridge.heartbeatFresh() then
        local seq = PZGR.Bridge.write("station_request.json", {
            kind = kind,
            day = PZGR.day(),
            hour = PZGR.hour(),
            minute = PZGR.minute(),
            station = station,
            header = (station.callsign or kind) .. " day " .. tostring(PZGR.day()),
        })
        stationPending[kind] = seq
        stationPending[kind .. "_age"] = 0
        -- air fallback immediately so it is never dead air; sidecar may replace next gap
        ch:setAiringBroadcast(makeBroadcast(seg.lines))
        PZGR.log("fallback " .. kind .. " while waiting on sidecar")
    else
        ch:setAiringBroadcast(makeBroadcast(seg.lines))
    end
end

function PZGR.tickStations()
    local md = PZGR.md()
    if not md.rolled then return end
    local sb = PZGR.sb()
    if sb.radio then requestStation("radio", md.radio, PZGR.radioCh) end
    if sb.tv then requestStation("tv", md.tv, PZGR.tvCh) end
end

Events.OnGameStart.Add(function()
    PZGR.registerStations()
end)

Events.OnTick.Add(function()
    if not PZGR._tick then PZGR._tick = 0 end
    PZGR._tick = PZGR._tick + 1
    if PZGR._tick % 30 ~= 0 then return end
    PZGR.tickStations()
end)
