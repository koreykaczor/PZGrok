PZGR = PZGR or {}

local function spawnTestRadio()
    local sb = PZGR.sb()
    if not sb.test then return end
    local player = getSpecificPlayer(0)
    if not player then return end
    local inv = player:getInventory()
    if not inv then return end
    local item = inv:AddItem("Base.WalkieTalkie5")
    if not item then return end
    local data = item.getDeviceData and item:getDeviceData()
    if data then
        if data.setIsTurnedOn then data:setIsTurnedOn(true) end
        if data.setPower then data:setPower(1) end
        if data.setMicIsMuted then data:setMicIsMuted(false) end
    end
    local md = PZGR.md()
    if md.groups then
        for i = 1, #md.groups do
            local g = md.groups[i]
            if data and data.addPreset then
                pcall(function() data:addPreset("G" .. tostring(i), g.frequencyKhz) end)
            end
        end
        if md.radio and data and data.addPreset then
            pcall(function() data:addPreset(md.radio.callsign, md.radio.frequencyKhz) end)
        end
    end
    local imd = item:getModData()
    if imd then imd.PZGrokSeeded = true end
    PZGR.log("spawned test WalkieTalkie5")
end

Events.OnCreatePlayer.Add(function()
    spawnTestRadio()
end)
