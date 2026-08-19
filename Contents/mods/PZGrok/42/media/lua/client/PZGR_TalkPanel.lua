-- Transmit panel: appears when a two-way is on, mic live, and the frequency is one somebody is on.
PZGR = PZGR or {}

local function currentFreq(window)
    if not window then return nil end
    if window.deviceData and window.deviceData.getChannel then
        return window.deviceData:getChannel()
    end
    if window.getDevice and window:getDevice() then
        local d = window:getDevice():getDeviceData()
        if d and d.getChannel then return d:getChannel() end
    end
    return nil
end

local function isTwoWay(item)
    if not item then return false end
    return PZGR.itemTier(item) >= 1
end

-- Hook the radio window after it builds so we can add a transmit strip.
local hooked = false
local function hookRadioWindow()
    if hooked then return end
    if not ISRadioWindow or not ISRadioWindow.createChildren then return end
    hooked = true
    local old = ISRadioWindow.createChildren
    function ISRadioWindow:createChildren()
        old(self)
        self.PZGR_entry = ISTextEntryBox:new("", 10, self:getHeight() - 54, self:getWidth() - 90, 22)
        self.PZGR_entry:initialise()
        self.PZGR_entry:instantiate()
        self:addChild(self.PZGR_entry)
        self.PZGR_btn = ISButton:new(self:getWidth() - 74, self:getHeight() - 54, 64, 22, "PTT", self, function()
            local freq = currentFreq(self)
            if not freq then return end
            local said = self.PZGR_entry:getText() or ""
            if said == "" then return end
            if PZGR.Talk and PZGR.Talk.pending then return end
            sendClientCommand("PZGrok", "talk", { freq = freq, said = said })
            self.PZGR_entry:setText("")
        end)
        self.PZGR_btn:initialise()
        self:addChild(self.PZGR_btn)
        self.PZGR_btn:setVisible(false)
        self.PZGR_entry:setVisible(false)
    end
    local oldPrerender = ISRadioWindow.prerender
    function ISRadioWindow:prerender()
        if oldPrerender then oldPrerender(self) end
        local freq = currentFreq(self)
        local show = false
        if freq and PZGR.groupForFreq then
            local g = PZGR.groupForFreq(freq)
            if g then show = true end
        end
        local sb = PZGR.sb and PZGR.sb()
        if sb and sb.ooc and freq == PZGR.OOC_KHZ then show = true end
        if self.PZGR_btn then
            self.PZGR_btn:setVisible(show)
            self.PZGR_entry:setVisible(show)
            if PZGR.Talk and PZGR.Talk.pending then
                self.PZGR_btn:setEnable(false)
            else
                self.PZGR_btn:setEnable(true)
            end
        end
    end
end

Events.OnGameStart.Add(hookRadioWindow)

-- Server command from the client panel (SP the client is the server).
if isServer and isServer() then
    -- dedicated: handle via ClientCommand
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "PZGrok" then return end
    if command == "talk" and args and args.freq then
        PZGR.submitTalk(args.freq, args.said or "")
        if player and PZGR.sb().noise and PZGR.sb().noise > 0 then
            addSound(player, player:getX(), player:getY(), player:getZ(), PZGR.sb().noise, PZGR.sb().noise)
        end
    end
end)

-- Singleplayer: OnClientCommand still fires; also bind a local fallback.
if not isClient or not isClient() then
    Events.OnKeyPressed.Add(function(key)
        -- no global hotkey; panel is the interface
    end)
end
