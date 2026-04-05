-- RaidMakerCE.lua
-- Core logic: state management, event handling, slash commands, invite workflow

RaidMakerCE = {
    signups = {},
    nameLookup = {},
    specToClass = {},
    state = "idle",
    raidTitle = "",
    raidDate = "",
    raidTime = "",
    maxPlayers = 40,
    isCustom = false,
    invited = {},
    inRaid = {},
    declined = {},
    tentative = {},
    lastInviteName = nil,
    lastInviteTime = 0,
    settings = {
        postJoinClassCheck = false,
        triggerWords = "+, inv, invite",
    },
}

-- Color constants for chat output
local COLOR_GREEN = "|cff00ff00"
local COLOR_YELLOW = "|cffffff00"
local COLOR_RED = "|cffff0000"
local COLOR_ORANGE = "|cffff8800"
local COLOR_WHITE = "|cffffffff"
local COLOR_CYAN = "|cff00ffff"
local COLOR_RESET = "|r"

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(COLOR_CYAN .. "RaidMakerCE: " .. COLOR_RESET .. msg)
end

-- Split names on "/" and "|"
local function SplitNames(nameStr)
    local names = {}
    nameStr = string.gsub(nameStr, "|", "/")
    local start = 1
    while true do
        local pos = string.find(nameStr, "/", start, true)
        if pos then
            local fragment = string.sub(nameStr, start, pos - 1)
            -- Trim whitespace
            fragment = string.gsub(fragment, "^%s+", "")
            fragment = string.gsub(fragment, "%s+$", "")
            if fragment ~= "" then
                table.insert(names, fragment)
            end
            start = pos + 1
        else
            local fragment = string.sub(nameStr, start)
            fragment = string.gsub(fragment, "^%s+", "")
            fragment = string.gsub(fragment, "%s+$", "")
            if fragment ~= "" then
                table.insert(names, fragment)
            end
            break
        end
    end
    return names
end

-- Look up a player's class from the guild roster
local function GetGuildMemberClass(playerName)
    local playerLower = strlower(playerName)
    -- Check both online and offline counts
    local totalMembers = GetNumGuildMembers(true) or 0
    if totalMembers == 0 then
        totalMembers = GetNumGuildMembers() or 0
    end
    for i = 1, totalMembers do
        local name, _, _, _, class = GetGuildRosterInfo(i)
        if name and strlower(name) == playerLower then
            return class
        end
    end
    return nil
end

-- Check if a message matches any trigger word
local function MatchesTriggerWord(message)
    local msgLower = strlower(message)
    local triggerStr = RaidMakerCE.settings.triggerWords or "+, inv, invite"
    -- Split on commas
    local start = 1
    while true do
        local pos = string.find(triggerStr, ",", start, true)
        local word
        if pos then
            word = string.sub(triggerStr, start, pos - 1)
            start = pos + 1
        else
            word = string.sub(triggerStr, start)
        end
        -- Trim whitespace
        word = string.gsub(word, "^%s+", "")
        word = string.gsub(word, "%s+$", "")
        word = strlower(word)
        if word ~= "" then
            -- Check if message starts with this trigger word
            if string.sub(msgLower, 1, string.len(word)) == word then
                return true
            end
        end
        if not pos then break end
    end
    return false
end

-- Simple table sort by position field
local function SortByPosition(a, b)
    return (a.position or 9999) < (b.position or 9999)
end

function RaidMakerCE_LoadJSON(jsonString)
    local data, err = RaidMakerCEParseJSON(jsonString)
    if not data then
        Print(COLOR_RED .. "JSON parse error: " .. (err or "unknown") .. COLOR_RESET)
        return false
    end

    if not data.signUps then
        Print(COLOR_RED .. "Invalid data: missing signUps array" .. COLOR_RESET)
        return false
    end

    -- Build specToClass lookup from classes array (primary only)
    RaidMakerCE.specToClass = {}
    if data.classes then
        for _, classDef in ipairs(data.classes) do
            if classDef.type == "primary" and classDef.specs then
                for _, spec in ipairs(classDef.specs) do
                    RaidMakerCE.specToClass[spec.name] = classDef.name
                end
            end
        end
    end

    -- Filter out Absence entries and clean up spec names
    local eligible = {}
    for _, signup in ipairs(data.signUps) do
        if signup.className ~= "Absence" then
            -- Strip trailing "1" from spec names (e.g., Holy1 -> Holy, Protection1 -> Protection)
            if signup.specName then
                signup.specName = string.gsub(signup.specName, "1$", "")
            end
            table.insert(eligible, signup)
        end
    end

    -- Sort by position
    table.sort(eligible, SortByPosition)

    -- Store all eligible signups (first 40 are invite-eligible)
    RaidMakerCE.signups = eligible

    -- Mark tentative entries
    RaidMakerCE.tentative = {}
    for i, signup in ipairs(RaidMakerCE.signups) do
        if signup.className == "Tentative" then
            RaidMakerCE.tentative[strlower(SplitNames(signup.name)[1] or "")] = true
        end
    end

    -- Build name lookup
    RaidMakerCE.nameLookup = {}
    for i, signup in ipairs(RaidMakerCE.signups) do
        local names = SplitNames(signup.name)
        for _, name in ipairs(names) do
            RaidMakerCE.nameLookup[strlower(name)] = i
        end
    end

    -- Store raid info
    RaidMakerCE.raidTitle = data.displayTitle or data.title or "Unknown Raid"
    RaidMakerCE.raidDate = data.date or ""
    RaidMakerCE.raidTime = data.time or ""

    -- Reset invite tracking
    RaidMakerCE.invited = {}
    RaidMakerCE.inRaid = {}
    RaidMakerCE.declined = {}
    RaidMakerCE.lastInviteName = nil
    RaidMakerCE.lastInviteTime = 0

    -- Set state
    RaidMakerCE.state = "loaded"
    RaidMakerCE.isCustom = false

    -- Save to SavedVariables
    RaidMakerCE_SaveState()

    Print(COLOR_GREEN .. "Loaded " .. table.getn(RaidMakerCE.signups) .. " sign-ups for " ..
        RaidMakerCE.raidTitle .. " (" .. RaidMakerCE.raidDate .. " " .. RaidMakerCE.raidTime .. ")" .. COLOR_RESET)

    -- Update UI if visible
    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end

    return true
end

function RaidMakerCE_SaveState()
    RaidMakerCEDB = {
        signups = RaidMakerCE.signups,
        nameLookup = RaidMakerCE.nameLookup,
        specToClass = RaidMakerCE.specToClass,
        state = RaidMakerCE.state,
        raidTitle = RaidMakerCE.raidTitle,
        raidDate = RaidMakerCE.raidDate,
        raidTime = RaidMakerCE.raidTime,
        maxPlayers = RaidMakerCE.maxPlayers,
        isCustom = RaidMakerCE.isCustom,
        settings = RaidMakerCE.settings,
        invited = RaidMakerCE.invited,
        inRaid = RaidMakerCE.inRaid,
        declined = RaidMakerCE.declined,
        tentative = RaidMakerCE.tentative,
    }
end

function RaidMakerCE_RestoreState()
    if not RaidMakerCEDB then return end
    RaidMakerCE.signups = RaidMakerCEDB.signups or {}
    RaidMakerCE.nameLookup = RaidMakerCEDB.nameLookup or {}
    RaidMakerCE.specToClass = RaidMakerCEDB.specToClass or {}
    RaidMakerCE.state = RaidMakerCEDB.state or "idle"
    RaidMakerCE.raidTitle = RaidMakerCEDB.raidTitle or ""
    RaidMakerCE.raidDate = RaidMakerCEDB.raidDate or ""
    RaidMakerCE.raidTime = RaidMakerCEDB.raidTime or ""
    RaidMakerCE.maxPlayers = RaidMakerCEDB.maxPlayers or 40
    RaidMakerCE.isCustom = RaidMakerCEDB.isCustom or false
    if RaidMakerCEDB.settings then
        RaidMakerCE.settings.postJoinClassCheck = RaidMakerCEDB.settings.postJoinClassCheck or false
        RaidMakerCE.settings.triggerWords = RaidMakerCEDB.settings.triggerWords or "+, inv, invite"
    end
    RaidMakerCE.invited = RaidMakerCEDB.invited or {}
    RaidMakerCE.inRaid = RaidMakerCEDB.inRaid or {}
    RaidMakerCE.declined = RaidMakerCEDB.declined or {}
    RaidMakerCE.tentative = RaidMakerCEDB.tentative or {}

    -- If we were inviting/open, drop back to loaded (re-sync after reload)
    if RaidMakerCE.state == "inviting" or RaidMakerCE.state == "open" then
        RaidMakerCE.state = "loaded"
    end
end

function RaidMakerCE_GetSignupStatus(index)
    local signup = RaidMakerCE.signups[index]
    if not signup then return "unknown" end
    local names = SplitNames(signup.name)
    for _, name in ipairs(names) do
        local lower = strlower(name)
        if RaidMakerCE.inRaid[lower] then return "inraid" end
    end
    for _, name in ipairs(names) do
        local lower = strlower(name)
        if RaidMakerCE.invited[lower] then return "invited" end
    end
    for _, name in ipairs(names) do
        local lower = strlower(name)
        if RaidMakerCE.declined[lower] then return "declined" end
    end
    if signup.className == "Tentative" then return "tentative" end
    return "pending"
end

function RaidMakerCE_GetDisplayClass(signup)
    local className = signup.className
    if className == "Tank" or className == "Tentative" then
        if signup.specName and RaidMakerCE.specToClass[signup.specName] then
            return RaidMakerCE.specToClass[signup.specName]
        end
    end
    return className
end

function RaidMakerCE_StartInviteMode(quiet)
    if RaidMakerCE.state == "idle" then
        Print(COLOR_RED .. "No raid data loaded. Use /rm paste first." .. COLOR_RESET)
        return
    end
    if RaidMakerCE.state == "inviting" then
        Print(COLOR_YELLOW .. "Already in invite mode." .. COLOR_RESET)
        return
    end

    -- Refresh guild roster for class verification
    if GuildRoster then GuildRoster() end

    -- Convert to raid if in party
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 then
        ConvertToRaid()
        Print("Converted party to raid.")
    end

    -- Custom raids go straight to open mode (no registration check)
    if RaidMakerCE.isCustom then
        RaidMakerCE.state = "open"
    else
        RaidMakerCE.state = "inviting"
    end

    -- Sync existing raid members against the roster
    RaidMakerCE_SyncRaidRoster()

    RaidMakerCE_SaveState()
    Print(COLOR_GREEN .. "Invite mode started. Monitoring guild chat for '+' messages." .. COLOR_RESET)

    if not quiet then
        SendChatMessage("Raid signup for " .. RaidMakerCE.raidTitle .. " is open. Type + for an invite.", "GUILD")
    end

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_OpenInviteMode()
    if RaidMakerCE.state ~= "inviting" then
        Print(COLOR_RED .. "Must be in invite mode first. Use /rm start." .. COLOR_RESET)
        return
    end
    RaidMakerCE.state = "open"
    RaidMakerCE_SaveState()
    Print(COLOR_GREEN .. "Open invite mode. Anyone typing '+' will be invited." .. COLOR_RESET)

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_StopInviteMode()
    if RaidMakerCE.state ~= "inviting" and RaidMakerCE.state ~= "open" then
        Print(COLOR_YELLOW .. "Not currently in invite mode." .. COLOR_RESET)
        return
    end
    RaidMakerCE.state = "loaded"
    RaidMakerCE_SaveState()
    Print(COLOR_YELLOW .. "Invite mode stopped." .. COLOR_RESET)

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_Reset()
    RaidMakerCE.signups = {}
    RaidMakerCE.nameLookup = {}
    RaidMakerCE.specToClass = {}
    RaidMakerCE.state = "idle"
    RaidMakerCE.isCustom = false
    RaidMakerCE.raidTitle = ""
    RaidMakerCE.raidDate = ""
    RaidMakerCE.raidTime = ""
    RaidMakerCE.invited = {}
    RaidMakerCE.inRaid = {}
    RaidMakerCE.declined = {}
    RaidMakerCE.tentative = {}
    RaidMakerCE.lastInviteName = nil
    RaidMakerCE.lastInviteTime = 0
    RaidMakerCE.maxPlayers = 40
    RaidMakerCEDB = nil
    Print("All data cleared.")

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_CreateRaid(title, maxPlayers)
    if not title or title == "" then
        Print(COLOR_RED .. "Please provide a raid name." .. COLOR_RESET)
        return
    end

    local maxNum = tonumber(maxPlayers)
    if not maxNum or maxNum < 1 then
        maxNum = 40
    end
    if maxNum > 40 then maxNum = 40 end
    maxPlayers = maxNum

    RaidMakerCE.signups = {}
    RaidMakerCE.nameLookup = {}
    RaidMakerCE.specToClass = {}
    RaidMakerCE.raidTitle = title
    RaidMakerCE.raidDate = date("%d-%m-%Y")
    RaidMakerCE.raidTime = date("%H:%M")
    RaidMakerCE.maxPlayers = maxPlayers
    RaidMakerCE.isCustom = true
    RaidMakerCE.invited = {}
    RaidMakerCE.inRaid = {}
    RaidMakerCE.declined = {}
    RaidMakerCE.tentative = {}
    RaidMakerCE.lastInviteName = nil
    RaidMakerCE.lastInviteTime = 0
    RaidMakerCE.state = "loaded"

    -- Sync existing raid members into the roster
    RaidMakerCE_SyncRaidRoster()

    RaidMakerCE_SaveState()
    Print(COLOR_GREEN .. "Created custom raid: " .. title .. " (max " .. maxPlayers .. " players). Use Start, Quiet, or Open to begin inviting." .. COLOR_RESET)

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
    if RaidMakerCEUI_ShowMainFrame then
        RaidMakerCEUI_ShowMainFrame()
    end
end

function RaidMakerCE_OnGuildChat(message, sender)
    if RaidMakerCE.state ~= "inviting" and RaidMakerCE.state ~= "open" then return end
    if not MatchesTriggerWord(message) then return end

    local senderLower = strlower(sender)
    local index = RaidMakerCE.nameLookup[senderLower]

    -- In normal invite mode, only top 40 registered players
    if RaidMakerCE.state == "inviting" then
        if index and index > 40 then
            SendChatMessage("Only the first 40 sign-ups for " .. RaidMakerCE.raidTitle .. " get auto-invites, but hang tight. If people don't show up there may be space for you soon.", "WHISPER", nil, sender)
            return
        elseif not index then
            SendChatMessage("You are not registered for " .. RaidMakerCE.raidTitle .. ", but please be patient. If there is still space you will receive an invite.", "WHISPER", nil, sender)
            return
        end
    end

    -- Verify class matches signup (prevents wrong-alt invites)
    if index then
        local signup = RaidMakerCE.signups[index]
        local expectedClass = RaidMakerCE_GetDisplayClass(signup)
        if expectedClass and expectedClass ~= "Unknown" and expectedClass ~= "Tank" and expectedClass ~= "Tentative" then
            local actualClass = GetGuildMemberClass(sender)
            if actualClass then
                if strlower(actualClass) ~= strlower(expectedClass) then
                    SendChatMessage("You are signed up as " .. expectedClass .. " for " .. RaidMakerCE.raidTitle .. ", but you are on a " .. actualClass .. ". Please log onto the correct character.", "WHISPER", nil, sender)
                    Print(COLOR_ORANGE .. sender .. " (" .. actualClass .. ") tried to join but is signed up as " .. expectedClass .. "." .. COLOR_RESET)
                    return
                end
            else
                Print(COLOR_YELLOW .. "Could not verify class for " .. sender .. " (expected " .. expectedClass .. "). Inviting anyway." .. COLOR_RESET)
            end
        end
    end

    -- In open mode, add unregistered players to the roster
    if RaidMakerCE.state == "open" and not index then
        local newSignup = {
            name = sender,
            className = "Unknown",
            specName = "",
            roleName = "",
            position = table.getn(RaidMakerCE.signups) + 1,
        }
        table.insert(RaidMakerCE.signups, newSignup)
        index = table.getn(RaidMakerCE.signups)
        RaidMakerCE.nameLookup[senderLower] = index
    end

    -- Check if already in raid
    if RaidMakerCE.inRaid[senderLower] then return end

    -- Clear declined status if re-requesting, allow re-invite
    if RaidMakerCE.declined[senderLower] then
        RaidMakerCE.declined[senderLower] = nil
        RaidMakerCE.invited[senderLower] = nil
    end

    -- Check if already invited and pending
    if RaidMakerCE.invited[senderLower] then return end

    -- Check if raid is full
    if GetNumRaidMembers() >= RaidMakerCE.maxPlayers then
        Print(COLOR_YELLOW .. "Raid is full (" .. RaidMakerCE.maxPlayers .. ")! Cannot invite " .. sender .. "." .. COLOR_RESET)
        SendChatMessage("Sorry, " .. RaidMakerCE.raidTitle .. " is full (" .. RaidMakerCE.maxPlayers .. "/" .. RaidMakerCE.maxPlayers .. "). No spots available right now.", "WHISPER", nil, sender)
        return
    end

    -- Send invite
    InviteByName(sender)
    RaidMakerCE.invited[senderLower] = true
    RaidMakerCE.lastInviteName = senderLower
    RaidMakerCE.lastInviteTime = GetTime()
    RaidMakerCE_SaveState()

    local signup = RaidMakerCE.signups[index]
    local displayClass = RaidMakerCE_GetDisplayClass(signup)
    local actualClass = GetGuildMemberClass(sender) or "unknown"
    Print(COLOR_GREEN .. "Invited " .. sender .. " with class " .. actualClass ..
        " that matched position " .. (signup.position or index) .. " in sign up" ..
        " (registered as " .. (displayClass or "?") .. "/" .. (signup.specName or "?") .. ")" .. COLOR_RESET)

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_OnSystemMessage(message)
    if RaidMakerCE.state ~= "inviting" and RaidMakerCE.state ~= "loaded" then return end

    -- "X declines your group invitation."
    local _, _, decliner = string.find(message, "(.+) declines your group invitation")
    if decliner then
        local lower = strlower(decliner)
        if RaidMakerCE.invited[lower] then
            RaidMakerCE.invited[lower] = nil
            RaidMakerCE.declined[lower] = true
            RaidMakerCE_SaveState()
            Print(COLOR_RED .. decliner .. " declined the invitation." .. COLOR_RESET)
            if RaidMakerCEUI_UpdateRoster then
                RaidMakerCEUI_UpdateRoster()
            end
        end
        return
    end

    -- "X is already in a group."
    local _, _, grouped = string.find(message, "(.+) is already in a group")
    if grouped then
        local lower = strlower(grouped)
        if RaidMakerCE.invited[lower] then
            RaidMakerCE.invited[lower] = nil
            RaidMakerCE.declined[lower] = true
            RaidMakerCE_SaveState()
            Print(COLOR_ORANGE .. grouped .. " is already in a group." .. COLOR_RESET)
            if RaidMakerCEUI_UpdateRoster then
                RaidMakerCEUI_UpdateRoster()
            end
        end
        return
    end

    -- "Player not found."
    if message == "Player not found." then
        if RaidMakerCE.lastInviteName and (GetTime() - RaidMakerCE.lastInviteTime) < 3 then
            local lower = RaidMakerCE.lastInviteName
            if RaidMakerCE.invited[lower] then
                RaidMakerCE.invited[lower] = nil
                RaidMakerCE_SaveState()
                Print(COLOR_ORANGE .. lower .. " is offline (player not found)." .. COLOR_RESET)
                if RaidMakerCEUI_UpdateRoster then
                    RaidMakerCEUI_UpdateRoster()
                end
            end
            RaidMakerCE.lastInviteName = nil
        end
        return
    end
end

function RaidMakerCE_SyncRaidRoster()
    if RaidMakerCE.state == "idle" then return end

    -- Detect leaving raid (disband, kick, etc.)
    -- Only reset if we previously had people in the raid
    local hadMembers = false
    for _ in pairs(RaidMakerCE.inRaid) do
        hadMembers = true
        break
    end
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 and hadMembers then
        if RaidMakerCE.state == "inviting" or RaidMakerCE.state == "open" then
            Print(COLOR_YELLOW .. "Raid disbanded. Invite mode stopped." .. COLOR_RESET)
        end
        RaidMakerCE.state = "loaded"
        RaidMakerCE.invited = {}
        RaidMakerCE.inRaid = {}
        RaidMakerCE.declined = {}
        RaidMakerCE_SaveState()
        if RaidMakerCEUI_UpdateRoster then
            RaidMakerCEUI_UpdateRoster()
        end
        return
    end

    -- Auto-convert party to raid when first person joins (deferred)
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 then
        if RaidMakerCE.state == "inviting" or RaidMakerCE.state == "open" then
            RaidMakerCE.pendingConvert = true
            return
        end
    end

    local newInRaid = {}
    for i = 1, GetNumRaidMembers() do
        local name, _, _, _, class = GetRaidRosterInfo(i)
        if name then
            local nameLower = strlower(name)
            newInRaid[nameLower] = true

            local index = RaidMakerCE.nameLookup[nameLower]

            -- Add raid members not on the roster
            if not index then
                local newSignup = {
                    name = name,
                    className = (class and class ~= "") and class or "Unknown",
                    specName = "",
                    roleName = "",
                    position = table.getn(RaidMakerCE.signups) + 1,
                }
                table.insert(RaidMakerCE.signups, newSignup)
                index = table.getn(RaidMakerCE.signups)
                RaidMakerCE.nameLookup[nameLower] = index
            end

            -- Backfill class for players with Unknown class
            if class and class ~= "" and index then
                local signup = RaidMakerCE.signups[index]
                if signup and signup.className == "Unknown" then
                    signup.className = class
                end
            end

            -- Post-join class check for new raid members
            if RaidMakerCE.settings.postJoinClassCheck and not RaidMakerCE.inRaid[nameLower] then
                if class and class ~= "" and index then
                    local signup = RaidMakerCE.signups[index]
                    local expectedClass = RaidMakerCE_GetDisplayClass(signup)
                    if expectedClass and expectedClass ~= "Unknown" and expectedClass ~= "Tank" and expectedClass ~= "Tentative" then
                        if strlower(class) ~= strlower(expectedClass) then
                            Print(COLOR_RED .. "WARNING: " .. name .. " joined as " .. class .. " but is signed up as " .. expectedClass .. "!" .. COLOR_RESET)
                            SendChatMessage("Notice: You joined " .. RaidMakerCE.raidTitle .. " as " .. class .. ", but you signed up as " .. expectedClass .. ". Please let the raid leader know if this is intentional.", "WHISPER", nil, name)
                        end
                    end
                end
            end
        end
    end

    -- Move invited players who are now in raid
    for name, _ in pairs(RaidMakerCE.invited) do
        if newInRaid[name] then
            RaidMakerCE.invited[name] = nil
        end
    end

    -- Also clear from declined if they somehow joined
    for name, _ in pairs(RaidMakerCE.declined) do
        if newInRaid[name] then
            RaidMakerCE.declined[name] = nil
        end
    end

    -- For custom raids, remove players who left
    if RaidMakerCE.isCustom then
        local newSignups = {}
        local newLookup = {}
        for i, signup in ipairs(RaidMakerCE.signups) do
            -- Keep if still in raid, or if invited/pending (not yet joined)
            local names = {}
            local nameStr = string.gsub(signup.name, "|", "/")
            local start = 1
            while true do
                local pos = string.find(nameStr, "/", start, true)
                if pos then
                    table.insert(names, string.sub(nameStr, start, pos - 1))
                    start = pos + 1
                else
                    table.insert(names, string.sub(nameStr, start))
                    break
                end
            end

            local stillRelevant = false
            for _, n in ipairs(names) do
                local lower = strlower(n)
                if newInRaid[lower] or RaidMakerCE.invited[lower] then
                    stillRelevant = true
                    break
                end
            end

            if stillRelevant then
                table.insert(newSignups, signup)
                local newIndex = table.getn(newSignups)
                for _, n in ipairs(names) do
                    newLookup[strlower(n)] = newIndex
                end
            end
        end
        RaidMakerCE.signups = newSignups
        RaidMakerCE.nameLookup = newLookup
    end

    RaidMakerCE.inRaid = newInRaid
    RaidMakerCE_SaveState()

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_ManualInvite(name)
    if not name or name == "" then
        Print(COLOR_RED .. "Usage: /rm invite <name>" .. COLOR_RESET)
        return
    end
    local lower = strlower(name)
    if RaidMakerCE.inRaid[lower] then
        Print(COLOR_YELLOW .. name .. " is already in the raid." .. COLOR_RESET)
        return
    end
    InviteByName(name)
    RaidMakerCE.invited[lower] = true
    RaidMakerCE.lastInviteName = lower
    RaidMakerCE.lastInviteTime = GetTime()
    RaidMakerCE_SaveState()
    Print(COLOR_GREEN .. "Manually invited " .. name .. "." .. COLOR_RESET)

    if RaidMakerCEUI_UpdateRoster then
        RaidMakerCEUI_UpdateRoster()
    end
end

function RaidMakerCE_PrintStatus()
    if RaidMakerCE.state == "idle" then
        Print("No raid data loaded.")
        return
    end

    local total = table.getn(RaidMakerCE.signups)
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

    Print(RaidMakerCE.raidTitle .. " (" .. RaidMakerCE.raidDate .. " " .. RaidMakerCE.raidTime .. ")")
    Print("State: " .. COLOR_YELLOW .. RaidMakerCE.state .. COLOR_RESET)
    Print(COLOR_GREEN .. countInRaid .. COLOR_RESET .. " in raid | " ..
        COLOR_YELLOW .. countInvited .. COLOR_RESET .. " invited | " ..
        COLOR_WHITE .. countPending .. COLOR_RESET .. " pending | " ..
        COLOR_ORANGE .. countTentative .. COLOR_RESET .. " tentative | " ..
        COLOR_RED .. countDeclined .. COLOR_RESET .. " declined")
end

function RaidMakerCE_PrintList()
    if RaidMakerCE.state == "idle" then
        Print("No raid data loaded.")
        return
    end

    Print("--- " .. RaidMakerCE.raidTitle .. " Roster ---")
    for i, signup in ipairs(RaidMakerCE.signups) do
        local status = RaidMakerCE_GetSignupStatus(i)
        local displayClass = RaidMakerCE_GetDisplayClass(signup)
        local statusColor = COLOR_WHITE
        local statusText = "Pending"
        if status == "inraid" then
            statusColor = COLOR_GREEN
            statusText = "In Raid"
        elseif status == "invited" then
            statusColor = COLOR_YELLOW
            statusText = "Invited"
        elseif status == "declined" then
            statusColor = COLOR_RED
            statusText = "Declined"
        elseif status == "tentative" then
            statusColor = COLOR_ORANGE
            statusText = "Tentative"
        end
        Print(i .. ". " .. signup.name .. " - " .. (displayClass or "?") ..
            " " .. (signup.specName or "") .. " " .. (signup.roleName or "") ..
            " [" .. statusColor .. statusText .. COLOR_RESET .. "]")
    end
end

-- Slash command handler
local function SlashHandler(msg)
    msg = msg or ""
    local _, _, cmd, rest = string.find(msg, "^(%S+)%s*(.*)")
    if not cmd then cmd = "" end
    cmd = strlower(cmd)

    if cmd == "paste" then
        if RaidMakerCEUI_ShowPasteDialog then
            RaidMakerCEUI_ShowPasteDialog()
        end
    elseif cmd == "start" then
        RaidMakerCE_StartInviteMode(false)
    elseif cmd == "startquiet" then
        RaidMakerCE_StartInviteMode(true)
    elseif cmd == "open" then
        RaidMakerCE_OpenInviteMode()
    elseif cmd == "stop" then
        RaidMakerCE_StopInviteMode()
    elseif cmd == "invite" then
        RaidMakerCE_ManualInvite(rest)
    elseif cmd == "create" then
        -- /rm create <name> [max] e.g. /rm create Onyxia 40
        local _, _, cname, cmax = string.find(rest, "^(.+)%s+(%d+)%s*$")
        if not cname then
            cname = rest
        end
        RaidMakerCE_CreateRaid(cname, cmax)
    elseif cmd == "reset" then
        RaidMakerCE_Reset()
    else
        -- Toggle main UI
        if RaidMakerCEUI_ToggleMainFrame then
            RaidMakerCEUI_ToggleMainFrame()
        else
            Print("Commands: paste | create | start | startquiet | open | stop | invite <name> | reset")
        end
    end
end

SLASH_RAIDMAKER1 = "/rm"
SLASH_RAIDMAKER2 = "/raidmaker"
SlashCmdList["RAIDMAKER"] = SlashHandler

-- Event handler
function RaidMakerCE_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "RaidMakerCE" then
        RaidMakerCE_RestoreState()
        -- Request guild roster so class lookups work
        if GuildRoster then GuildRoster() end
        if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
        if RaidMakerCE.state ~= "idle" then
            Print("Restored raid data for " .. RaidMakerCE.raidTitle .. ". State: " .. RaidMakerCE.state)
        end
        Print("Loaded. Type /rm for help.")
    elseif event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_WHISPER" then
        RaidMakerCE_OnGuildChat(arg1, arg2)
    elseif event == "RAID_ROSTER_UPDATE" then
        RaidMakerCE_SyncRaidRoster()
    elseif event == "PARTY_MEMBERS_CHANGED" then
        RaidMakerCE_SyncRaidRoster()
    elseif event == "CHAT_MSG_SYSTEM" then
        RaidMakerCE_OnSystemMessage(arg1)
    end
end

-- Deferred convert: runs on next frame via OnUpdate
function RaidMakerCE_OnUpdate()
    if RaidMakerCE.pendingConvert then
        RaidMakerCE.pendingConvert = nil
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 then
            if RaidMakerCE.state == "inviting" or RaidMakerCE.state == "open" then
                ConvertToRaid()
                Print("Converted party to raid.")
            end
        end
    end
end
