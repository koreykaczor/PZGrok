PZGR = PZGR or {}
PZGR.Fallback = PZGR.Fallback or {}

local function era(day)
    if day <= 1 then return "situation" end
    if day <= 4 then return "riots" end
    if day <= 6 then return "degenerative" end
    if day == 7 then return "second-wave" end
    if day == 8 then return "worldwide" end
    if day <= 10 then return "bites" end
    return "loops"
end

local COPY = {
    situation = {
        { "HOST", "Sunrise, Kentuckiana. DOT says the I-64 ramps into Louisville are still closed." },
        { "HOST", "They are calling it a situation. That's the word they used." },
        { "HOST", "If you're coming in from New Albany, give yourself an hour you do not have." },
    },
    riots = {
        { "NEWS", "Wire says Washington, Detroit, Los Angeles. Riots." },
        { "HOST", "Closer to home, the blockade is still the blockade." },
        { "HOST", "We've had callers asking if it's a flu. The statehouse says it is not a flu." },
    },
    degenerative = {
        { "NEWS", "General McGrew: the condition is degenerative. Panic and confusion. Sufferers are not deceased." },
        { "HOST", "I am going to read that again. Not deceased." },
        { "HOST", "The phones into the zone have been a busy signal since Tuesday." },
    },
    ["second-wave"] = {
        { "NEWS", "The second wave. Spreading with no contact. Stay in your homes." },
        { "HOST", "I am at the station because I slept here." },
        { "HOST", "If you can hear me, you are already doing the one thing they asked." },
    },
    worldwide = {
        { "NEWS", "Louisville. Cincinnati. London. Mogadishu. Worldwide." },
        { "HOST", "If you are calling about the bridge, the bridge is closed from both ends." },
        { "TAPE", "This is a recording of the recording. Please stand by." },
    },
    bites = {
        { "NEWS", "McGrew, to those unaffected by the second wave: from now on it spreads only by bites. They may be your family." },
        { "HOST", "If you are still keeping a log of who you've heard from, keep it." },
        { "HOST", "We will be here until we are not." },
    },
    loops = {
        { "TAPE", "You are listening to a station that has not changed the reel since Thursday." },
        { "TAPE", "Stay in your homes. Stay in your homes." },
        { "TAPE", "<static>" },
    },
}

function PZGR.Fallback.segment(station, day, hour)
    local e = era(day)
    local lines = COPY[e] or COPY.loops
    local out = {}
    for i = 1, #lines do
        local sp = lines[i][1]
        if sp == "HOST" then sp = station.host or "HOST" end
        out[i] = { speaker = sp, text = lines[i][2] }
    end
    return { show = (station.callsign or "STA") .. " " .. e .. " h" .. tostring(hour), lines = out }
end
