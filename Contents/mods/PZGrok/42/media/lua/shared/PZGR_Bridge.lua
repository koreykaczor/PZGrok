PZGR = PZGR or {}
PZGR.Bridge = PZGR.Bridge or {}
PZGR.Bridge.seq = PZGR.Bridge.seq or 1

local function path(name)
    return PZGR.DIR .. "/" .. name
end

function PZGR.Bridge.write(name, tbl)
    PZGR.Bridge.seq = (PZGR.Bridge.seq or 1) + 1
    tbl.seq = PZGR.Bridge.seq
    local body = PZGR.Json.encode(tbl) .. "\n--END " .. tostring(tbl.seq) .. "\n"
    local w = getFileWriter(path(name), true, false)
    if not w then
        PZGR.log("could not write " .. name)
        return nil
    end
    w:write(body)
    w:close()
    return tbl.seq
end

function PZGR.Bridge.read(name)
    local r = getFileReader(path(name), false)
    if not r then return nil end
    local buf = {}
    local line = r:readLine()
    while line ~= nil do
        buf[#buf + 1] = line
        line = r:readLine()
    end
    r:close()
    local raw = table.concat(buf, "\n")
    local body, sentinel = string.match(raw, "^(.*)\n%-%-END%s+(%d+)%s*$")
    -- sidecar writes atomically, no sentinel required
    if not body then
        local ok, data = pcall(PZGR.Json.decode, raw)
        if ok then return data end
        return nil
    end
    local ok, data = pcall(PZGR.Json.decode, body)
    if not ok or type(data) ~= "table" then return nil end
    if tostring(data.seq) ~= sentinel then return nil end
    return data
end

function PZGR.Bridge.heartbeatFresh()
    local data = PZGR.Bridge.read("heartbeat.json")
    if not data or not data.ts then return false end
    -- sidecar stamps unix seconds; treat < 15s old as live. Lua has no os.time
    -- reliably — compare against last seen tick instead.
    PZGR.Bridge._lastBeat = PZGR.Bridge._lastBeat or 0
    if data.ts ~= PZGR.Bridge._lastTs then
        PZGR.Bridge._lastTs = data.ts
        PZGR.Bridge._lastBeat = PZGR._tick or 0
        return true
    end
    return ((PZGR._tick or 0) - (PZGR.Bridge._lastBeat or 0)) < 400
end
