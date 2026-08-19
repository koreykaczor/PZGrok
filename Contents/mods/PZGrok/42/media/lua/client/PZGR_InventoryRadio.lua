-- Vanilla Device Options is hardcoded to primary, secondary, or clothing Back.
-- This adds the same menu entry from anywhere in the inventory.
PZGR = PZGR or {}

local function isRadio(item)
    if not item then return false end
    if item.IsRadioDevice and item:IsRadioDevice() then return true end
    local t = item.getType and item:getType() or ""
    return string.find(t, "WalkieTalkie") or string.find(t, "HamRadio") or string.find(t, "Radio")
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    for i = 1, #items do
        local entry = items[i]
        local item = entry
        if type(entry) == "table" then
            item = entry.items and entry.items[1] or entry.item or entry
        end
        if isRadio(item) then
            context:addOption("Device Options", item, function()
                if ISRadioWindow and ISRadioWindow.activate then
                    ISRadioWindow.activate(player, item)
                elseif ISRadioWindow then
                    local w = ISRadioWindow:new(0, 0, 400, 300, player, item)
                    w:initialise()
                    w:addToUIManager()
                end
            end)
            break
        end
    end
end)
