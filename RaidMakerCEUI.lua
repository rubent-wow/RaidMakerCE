-- RaidMakerCEUI.lua
-- UI update and rendering functions

local VISIBLE_ROWS = 20
local ROW_HEIGHT = 16

-- WoW class colors (Classic)
local CLASS_COLORS = {
    ["Warrior"]  = { r = 0.78, g = 0.61, b = 0.43 },
    ["Paladin"]  = { r = 0.96, g = 0.55, b = 0.73 },
    ["Hunter"]   = { r = 0.67, g = 0.83, b = 0.45 },
    ["Rogue"]    = { r = 1.00, g = 0.96, b = 0.41 },
    ["Priest"]   = { r = 1.00, g = 1.00, b = 1.00 },
    ["Shaman"]   = { r = 0.00, g = 0.44, b = 0.87 },
    ["Mage"]     = { r = 0.25, g = 0.78, b = 0.92 },
    ["Warlock"]  = { r = 0.53, g = 0.53, b = 0.93 },
    ["Druid"]    = { r = 1.00, g = 0.49, b = 0.04 },
}

local STATUS_COLORS = {
    ["pending"]   = { r = 0.8, g = 0.8, b = 0.8 },
    ["invited"]   = { r = 1.0, g = 1.0, b = 0.0 },
    ["inraid"]    = { r = 0.0, g = 1.0, b = 0.0 },
    ["declined"]  = { r = 1.0, g = 0.0, b = 0.0 },
    ["tentative"] = { r = 1.0, g = 0.5, b = 0.0 },
}

local STATUS_TEXT = {
    ["pending"]   = "Pending",
    ["invited"]   = "Invited",
    ["inraid"]    = "In Raid",
    ["declined"]  = "Declined",
    ["tentative"] = "Tentative",
}

function RaidMakerCEUI_UpdateRoster()
    local total = table.getn(RaidMakerCE.signups)

    -- Update title
    if RaidMakerCE.state ~= "idle" then
        getglobal("RaidMakerCEMainFrameTitle"):SetText("RaidMakerCE - " .. RaidMakerCE.raidTitle .. " [Max " .. RaidMakerCE.maxPlayers .. "]")
        getglobal("RaidMakerCEMainFrameSubtitle"):SetText(RaidMakerCE.raidDate .. " " .. RaidMakerCE.raidTime)
    else
        getglobal("RaidMakerCEMainFrameTitle"):SetText("RaidMakerCE")
        getglobal("RaidMakerCEMainFrameSubtitle"):SetText("Use /rm paste to load raid data")
    end

    -- Update scroll frame
    FauxScrollFrame_Update(RaidMakerCEScrollFrame, total, VISIBLE_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(RaidMakerCEScrollFrame)

    -- Status counters
    local countInRaid = 0
    local countInvited = 0
    local countDeclined = 0
    local countPending = 0
    local countTentative = 0

    for i = 1, total do
        local status = RaidMakerCE_GetSignupStatus(i)
        if status == "inraid" then
            countInRaid = countInRaid + 1
        elseif status == "invited" then
            countInvited = countInvited + 1
        elseif status == "declined" then
            countDeclined = countDeclined + 1
        elseif status == "tentative" then
            countTentative = countTentative + 1
        else
            countPending = countPending + 1
        end
    end

    -- Update rows
    for row = 1, VISIBLE_ROWS do
        local rowFrame = getglobal("RaidMakerCERow" .. row)
        local index = offset + row
        if index <= total then
            local signup = RaidMakerCE.signups[index]
            local status = RaidMakerCE_GetSignupStatus(index)
            local displayClass = RaidMakerCE_GetDisplayClass(signup)
            local classColor = CLASS_COLORS[displayClass] or { r = 0.7, g = 0.7, b = 0.7 }
            local statusColor = STATUS_COLORS[status] or STATUS_COLORS["pending"]
            local statusText = STATUS_TEXT[status] or "?"

            -- Number
            getglobal("RaidMakerCERow" .. row .. "Number"):SetText(index .. ".")

            -- Name - show first name only for display, full in tooltip
            local displayName = signup.name
            getglobal("RaidMakerCERow" .. row .. "Name"):SetText(displayName)
            getglobal("RaidMakerCERow" .. row .. "Name"):SetTextColor(classColor.r, classColor.g, classColor.b)

            -- Class/Spec
            local specText = displayClass or "?"
            if signup.specName and signup.specName ~= "" then
                specText = specText .. "/" .. signup.specName
            end
            getglobal("RaidMakerCERow" .. row .. "Class"):SetText(specText)
            getglobal("RaidMakerCERow" .. row .. "Class"):SetTextColor(classColor.r, classColor.g, classColor.b)

            -- Role
            getglobal("RaidMakerCERow" .. row .. "Role"):SetText(signup.roleName or "")

            -- Status
            getglobal("RaidMakerCERow" .. row .. "Status"):SetText(statusText)
            getglobal("RaidMakerCERow" .. row .. "Status"):SetTextColor(statusColor.r, statusColor.g, statusColor.b)

            rowFrame:Show()
        else
            rowFrame:Hide()
        end
    end

    -- Update status bar
    local stateLabel = ""
    if RaidMakerCE.state == "inviting" then
        stateLabel = "|cff00ff00[INVITING]|r "
    elseif RaidMakerCE.state == "open" then
        stateLabel = "|cff00ffff[OPEN]|r "
    elseif RaidMakerCE.state == "loaded" then
        stateLabel = "|cffffff00[LOADED]|r "
    end

    getglobal("RaidMakerCEStatusBar"):SetText(
        stateLabel ..
        "|cff00ff00" .. countInRaid .. "|r raid " ..
        "|cffffff00" .. countInvited .. "|r inv " ..
        "|cffffffff" .. countPending .. "|r pend " ..
        "|cffff8800" .. countTentative .. "|r tentative " ..
        "|cffff0000" .. countDeclined .. "|r declined"
    )

    -- Update button states
    if RaidMakerCE.state == "idle" then
        getglobal("RaidMakerCEStartButton"):Disable()
        getglobal("RaidMakerCEStartQuietButton"):Disable()
        getglobal("RaidMakerCEOpenButton"):Disable()
        getglobal("RaidMakerCEStopButton"):Disable()
    elseif RaidMakerCE.state == "loaded" then
        getglobal("RaidMakerCEStartButton"):Enable()
        getglobal("RaidMakerCEStartQuietButton"):Enable()
        getglobal("RaidMakerCEOpenButton"):Disable()
        getglobal("RaidMakerCEStopButton"):Disable()
    elseif RaidMakerCE.state == "inviting" then
        getglobal("RaidMakerCEStartButton"):Disable()
        getglobal("RaidMakerCEStartQuietButton"):Disable()
        getglobal("RaidMakerCEOpenButton"):Enable()
        getglobal("RaidMakerCEStopButton"):Enable()
    elseif RaidMakerCE.state == "open" then
        getglobal("RaidMakerCEStartButton"):Disable()
        getglobal("RaidMakerCEStartQuietButton"):Disable()
        getglobal("RaidMakerCEOpenButton"):Disable()
        getglobal("RaidMakerCEStopButton"):Enable()
    end
end

function RaidMakerCEUI_ShowPasteDialog()
    RaidMakerCEPasteFrame:Show()
end

function RaidMakerCEUI_ShowCreateDialog()
    RaidMakerCECreateFrame:Show()
end

function RaidMakerCEUI_SubmitCreateDialog()
    local raidName = RaidMakerCECreateNameEditBox:GetText()
    local maxPlayers = RaidMakerCECreateMaxEditBox:GetText()
    if raidName and raidName ~= "" then
        RaidMakerCE_CreateRaid(raidName, maxPlayers)
        RaidMakerCECreateFrame:Hide()
    end
end

function RaidMakerCEUI_ShowMainFrame()
    RaidMakerCEMainFrame:Show()
end

function RaidMakerCEUI_ToggleMainFrame()
    if RaidMakerCEMainFrame:IsVisible() then
        RaidMakerCEMainFrame:Hide()
    else
        RaidMakerCEMainFrame:Show()
    end
end

function RaidMakerCEUI_ToggleInfoFrame()
    if RaidMakerCEInfoFrame:IsVisible() then
        RaidMakerCEInfoFrame:Hide()
    else
        RaidMakerCEInfoFrame:Show()
    end
end

function RaidMakerCEUI_ToggleSettingsFrame()
    if RaidMakerCESettingsFrame:IsVisible() then
        RaidMakerCESettingsFrame:Hide()
    else
        RaidMakerCESettingsFrame:Show()
    end
end

function RaidMakerCEUI_RefreshSettings()
    RaidMakerCEPostJoinCheckButton:SetChecked(RaidMakerCE.settings.postJoinClassCheck)
    RaidMakerCETriggerWordsEditBox:SetText(RaidMakerCE.settings.triggerWords or "+, inv, invite")
end

function RaidMakerCEUI_SetInfoText()
    local text =
        "|cff00ffffImporting from raid-helper.xyz:|r\n" ..
        "1. In Discord, click Web View on the raid post\n" ..
        "2. Click the JSON badge (top right)\n" ..
        "3. Select all and copy (Ctrl+A, Ctrl+C)\n" ..
        "4. In-game: click Paste, Ctrl+V, click Load\n" ..
        "\n" ..
        "|cff00ffffImported Raid:|r\n" ..
        "1. Click Start (guild announce) or Quiet\n" ..
        "2. Players type + in guild chat or whisper\n" ..
        "3. Click Open to allow anyone to join\n" ..
        "4. Click Stop when done\n" ..
        "(Auto-converts to raid when first person joins)\n" ..
        "\n" ..
        "|cff00ffffCustom Raid:|r\n" ..
        "1. Click Create, enter name and max size\n" ..
        "2. Click Start, Quiet, or Open to begin\n" ..
        "3. Anyone typing + gets invited\n" ..
        "4. Click Stop when done\n" ..
        "\n" ..
        "|cff00ffffSlash Commands:|r\n" ..
        "/rm - Toggle this window\n" ..
        "/rm paste - Paste JSON\n" ..
        "/rm create <name> [max] - Custom raid\n" ..
        "/rm start | startquiet | open | stop\n" ..
        "/rm invite <name> - Manual invite\n" ..
        "/rm reset - Clear all data"
    getglobal("RaidMakerCEInfoFrameText"):SetText(text)
end
