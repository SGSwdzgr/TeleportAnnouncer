local ADDON_NAME, TeleportAnnouncer = ...

TeleportAnnouncer.Locale = {}
local L = TeleportAnnouncer.Locale

local C_Spell_GetSpellInfo, C_Spell_GetSpellLink = C_Spell.GetSpellInfo, C_Spell.GetSpellLink
local C_Item_GetItemInfo = C_Item.GetItemInfo
local C_ChatInfo_SendChatMessage = C_ChatInfo.SendChatMessage
local IsInGroup, UnitInRaid, UnitInParty, UnitInBattleground, IsPartyLFG = IsInGroup, UnitInRaid, UnitInParty, UnitInBattleground, IsPartyLFG

local function getConfigByKey(key, default)
    return TeleportAnnouncerDB and TeleportAnnouncerDB[key] or default
end

local function sendMessage(message)
    local channel = nil
    if UnitInBattleground("player") then
        channel = "INSTANCE_CHAT"
    elseif UnitInRaid("player") then
        if IsPartyLFG() then
            channel = "INSTANCE_CHAT"
        else
            local announceChannel = getConfigByKey("AnnounceChannel", 1)
            channel = announceChannel == 1 and "RAID" or "PARTY"
        end
    elseif UnitInParty("player") then
        channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    end
    -- print(message, channel)
    if channel then
        C_ChatInfo_SendChatMessage(message, channel)
    end
end

-- local lastAnnounceTime, currentTime = 0, nil
function TeleportAnnouncer:announceSpell(spellID, isSucceeded)
    local teleportData = TeleportAnnouncer.teleportSpells[spellID]
    if not teleportData then return end

    -- currentTime = time()
    -- if currentTime - lastAnnounceTime <= 1 then
    --     return
    -- end
    -- lastAnnounceTime = currentTime

    local onlyKeystone = getConfigByKey("OnlyKeystone", false)
    if onlyKeystone and not teleportData.keystone then return end

    local ignoreHeartstone = getConfigByKey("IgnoreHeartstone", false)
    if ignoreHeartstone and teleportData.heartstone then return end

    local announceTiming = getConfigByKey("AnnounceTiming", 1)
    if announceTiming == 2 and not isSucceeded then return end

    local doNotShowItem = getConfigByKey("DoNotShowItem", false)

    local messageTemplateUse = announceTiming == 1 and L["UsingAndHeadingTo"] or L["UsedAndArrivedAt"]
    local messageTemplateCast = announceTiming == 1 and L["CastingAndHeadingTo"] or L["CastAndArrivedAt"]
    if isSucceeded and announceTiming == 1 then
        local spellInfo = C_Spell_GetSpellInfo(spellID)
        if not spellInfo then return end
        if spellInfo.castTime ~= 0 then return end
        messageTemplateUse = L["UsedAndArrivedAt"]
        messageTemplateCast = L["CastAndArrivedAt"]
    end

    local message
    local destination = L[string.format("spell_%s", spellID)] or ""
    if not doNotShowItem then
        if TeleportAnnouncer.teleportItems[spellID] then
            message = string.format(messageTemplateUse, TeleportAnnouncer.teleportItems[spellID], destination)
        elseif teleportData.item then
            local _, itemLink = C_Item_GetItemInfo(teleportData.item)
            itemLink = itemLink or L["UnknownItem"]
            message = string.format(messageTemplateUse, itemLink, destination)
        end
    end
    if not message then
        local spellLink = C_Spell_GetSpellLink(spellID) or L["UnknownSpell"]
        message = string.format(messageTemplateCast, spellLink, destination)
    end
    sendMessage(message)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addOnName = ...
        if addOnName == ADDON_NAME then
            TeleportAnnouncer:prepareDBAndSettings()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" then
        TeleportAnnouncer:buildTeleportItems()
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, castGUID, spellID = ...
        if unitTarget == "player" and castGUID then
            TeleportAnnouncer:announceSpell(spellID, event == "UNIT_SPELLCAST_SUCCEEDED")
        end
    end
end)

