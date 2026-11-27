local addonName, ns = ...

-- Accepts quests and hands them in as soon as the player talks to the
-- quest giver, so levelling is not a string of the same three clicks.
-- Holding Shift while talking to someone leaves everything to the player.
--
-- It never chooses a reward: a quest that offers a choice stops at the
-- reward window. It never pays for a quest that asks for money.

local defaults = {
    accept = true,
    turnIn = true,
    -- Low-level ("grey") quests are left for the player to pick up.
    skipTrivial = true,
    -- Repeatable quests usually take items each time, so are left alone.
    skipRepeatable = true,
    -- Group, dungeon, raid and elite quests are left for the player to choose.
    skipGroup = true,
}

-- Settings from the reading-aloud feature, which has been removed.
local OLD_SETTINGS = { "narrate", "listenFirst", "readGreetings", "matchVoice", "maleVoice", "femaleVoice",
    "rate", "volume", "showBar", "barPosition" }

-- Set if the game's quest functions turn out to behave differently here;
-- the addon then stops acting for the rest of the session.
local broken = false

function ns.Print(msg)
    print("|cffd9a066SwiftQuest|r: " .. tostring(msg))
end

-- A value the client may withhold cannot be tested.
local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Paused for this session (the key binding or /swiftquest pause).
ns.paused = false

local function Wanted(isTrivial, isRepeatable, isGroup)
    if ns.db.skipTrivial and Usable(isTrivial) and isTrivial then return false end
    if ns.db.skipRepeatable and Usable(isRepeatable) and isRepeatable then return false end
    if ns.db.skipGroup and Usable(isGroup) and isGroup then return false end
    return true
end

-- A quest's kind, from the quest log's own answers where the game gives
-- them: low-level, repeatable, and group (group, dungeon, raid, elite,
-- PvP). Unknown answers are nil and don't stop anything.
local GROUP_WORDS = { "group", "dungeon", "raid", "elite", "pvp", "heroic" }
local function QuestKind(questID)
    local log = C_QuestLog
    if not (log and Usable(questID) and questID) then return end
    local function Ask(fn)
        if not fn then return nil end
        local ok, value = pcall(fn, questID)
        if ok and Usable(value) then return value end
    end
    local trivial = Ask(log.IsQuestTrivial)
    local repeatable = Ask(log.IsRepeatableQuest)
    local group
    local tag = Ask(log.GetQuestTagInfo)
    if type(tag) == "table" and type(tag.tagName) == "string" and Usable(tag.tagName) then
        local name = tag.tagName:lower()
        for _, word in ipairs(GROUP_WORDS) do
            if name:find(word, 1, true) then group = true end
        end
    end
    return trivial, repeatable, group
end
ns.QuestKind = QuestKind

-- Free slots in the ordinary bags, or nil if the game won't say.
local function FreeSlots()
    local container = C_Container
    if not (container and container.GetContainerNumFreeSlots) then return nil end
    local free = 0
    for bag = 0, 4 do
        local ok, open, family = pcall(container.GetContainerNumFreeSlots, bag)
        if not ok then return nil end
        if Usable(open) and type(open) == "number" and (not Usable(family) or family == 0 or family == nil) then
            free = free + open
        end
    end
    return free
end

-- Room left in the partial stacks you carry, by item.
local function StackRoom()
    local room = {}
    local container = C_Container
    if not (container and container.GetContainerNumSlots and container.GetContainerItemInfo) then return room end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    for bag = 0, 4 do
        local ok, slots = pcall(container.GetContainerNumSlots, bag)
        for slot = 1, (ok and Usable(slots) and slots) or 0 do
            local info = container.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and Usable(info.itemID) and info.itemID and getInfo then
                local okInfo, _, _, _, _, _, _, _, maxStack = pcall(getInfo, info.itemID)
                if okInfo and Usable(maxStack) and type(maxStack) == "number" and maxStack > (info.stackCount or 1) then
                    room[info.itemID] = (room[info.itemID] or 0) + maxStack - (info.stackCount or 1)
                end
            end
        end
    end
    return room
end

-- Whether the bags have room for the rewards in the reward window: yes,
-- or no with how many slots are needed and free. Unknown counts as yes.
local function RoomForRewards(choices)
    local free = FreeSlots()
    if not free then return true end
    local rewards = GetNumQuestRewards and GetNumQuestRewards() or 0
    if not Usable(rewards) then return true end
    local room = StackRoom()
    local need = (choices == 1) and 1 or 0
    for index = 1, rewards do
        local count = 1
        if GetQuestItemInfo then
            local ok, _, _, amount = pcall(GetQuestItemInfo, "reward", index)
            if ok and Usable(amount) and type(amount) == "number" then count = amount end
        end
        local itemID
        if GetQuestItemLink then
            local ok, link = pcall(GetQuestItemLink, "reward", index)
            if ok and Usable(link) and type(link) == "string" then itemID = tonumber(link:match("item:(%d+)")) end
        end
        if itemID and (room[itemID] or 0) >= count then
            room[itemID] = room[itemID] - count
        else
            need = need + 1
        end
    end
    return free >= need, need, free
end
ns.RoomForRewards = RoomForRewards

local function JunkMateLoaded()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("JunkMate")
    return loaded and true or false
end

local handlers = {}

-- A conversation that lists quests among other things to say.
function handlers.GOSSIP_SHOW()
    if ns.db.turnIn then
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if Usable(quest.isComplete) and quest.isComplete and Usable(quest.questID) then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return
            end
        end
    end
    if ns.db.accept then
        for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            local _, _, group = QuestKind(quest.questID)
            if Usable(quest.questID) and Wanted(quest.isTrivial, quest.repeatable, group) then
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return
            end
        end
    end
end

-- A quest giver who offers nothing but a list of quests.
function handlers.QUEST_GREETING()
    if ns.db.turnIn then
        local count = GetNumActiveQuests()
        for index = 1, (Usable(count) and count or 0) do
            local _, isComplete = GetActiveTitle(index)
            if Usable(isComplete) and isComplete then
                SelectActiveQuest(index)
                return
            end
        end
    end
    if ns.db.accept then
        local count = GetNumAvailableQuests()
        for index = 1, (Usable(count) and count or 0) do
            local isTrivial, _, isRepeatable = GetAvailableQuestInfo(index)
            if Wanted(isTrivial, isRepeatable) then
                SelectAvailableQuest(index)
                return
            end
        end
    end
end

-- The quest's description, with Accept and Decline.
function handlers.QUEST_DETAIL()
    if not ns.db.accept then return end
    local alreadyAccepted = QuestGetAutoAccept()
    if Usable(alreadyAccepted) and alreadyAccepted then
        -- The game has taken the quest already and only wants it acknowledged.
        AcknowledgeAutoAcceptQuest()
        return
    end
    -- A quest giver with just one quest opens it straight away, without a
    -- list: the same checks apply here as to a list.
    local questID = GetQuestID and GetQuestID()
    local trivial, repeatable, group = QuestKind(questID)
    if not group and GetSuggestedGroupNum then
        local size = GetSuggestedGroupNum()
        if Usable(size) and type(size) == "number" and size > 1 then group = true end
    end
    if not Wanted(trivial, repeatable, group) then return end
    AcceptQuest()
end

-- "Have you done it?", with Continue.
function handlers.QUEST_PROGRESS()
    if not ns.db.turnIn then return end
    local completable = IsQuestCompletable()
    if not Usable(completable) or not completable then return end
    local cost = GetQuestMoneyToGet()
    if Usable(cost) and cost > 0 then return end
    CompleteQuest()
end

-- The rewards, with Complete Quest.
function handlers.QUEST_COMPLETE()
    if not ns.db.turnIn then return end
    local choices = GetNumQuestChoices()
    if not Usable(choices) or choices > 1 then return end
    -- Bags too full for the reward: handing in would only fail. JunkMate,
    -- if you have it, offers to make room; otherwise say so once.
    local enough, need, free = RoomForRewards(choices)
    if not enough then
        if not JunkMateLoaded() then
            local title = GetTitleText and GetTitleText()
            ns.Print(("No room in your bags for the reward from %s (needs %d free slot%s, you have %d). Make room, then complete it.")
                :format(Usable(title) and title or "this quest", need, need == 1 and "" or "s", free))
        end
        return
    end
    GetQuestReward(1)
end

local function Describe()
    local db = ns.db
    local doing = {}
    if db.accept then doing[#doing + 1] = "accepts quests" end
    if db.turnIn then doing[#doing + 1] = "hands them in" end
    if #doing == 0 then
        return "It is leaving quests to you."
    end
    local leaving = {}
    if db.skipTrivial then leaving[#leaving + 1] = "low-level" end
    if db.skipRepeatable then leaving[#leaving + 1] = "repeatable" end
    if db.skipGroup then leaving[#leaving + 1] = "group" end
    return ("It %s%s."):format(table.concat(doing, " and "),
        #leaving > 0 and (", leaving " .. table.concat(leaving, " and ") .. " quests to you") or "")
end

local TOGGLES = { accept = "accept", turnin = "turnIn", lowlevel = "skipTrivial", repeatable = "skipRepeatable",
    group = "skipGroup" }

-- Pauses or resumes SwiftQuest for this session (the key binding too).
function ns.TogglePause()
    ns.paused = not ns.paused
    ns.Print(ns.paused and "Paused: quests are left to you until you resume (same key, or /swiftquest pause)."
        or "Resumed: accepting and handing in quests again.")
end
function SwiftQuest_TogglePause() ns.TogglePause() end
function SwiftQuest_ToggleOptions() ns.ToggleOptions() end
BINDING_HEADER_SWIFTQUEST = "SwiftQuest"
BINDING_NAME_SWIFTQUEST_PAUSE = "Pause or resume SwiftQuest"
BINDING_NAME_SWIFTQUEST_OPTIONS = "Open SwiftQuest's options"

SLASH_SWIFTQUEST1 = "/swiftquest"
SLASH_SWIFTQUEST2 = "/squest"
SlashCmdList.SWIFTQUEST = function(msg)
    local command = (msg or ""):lower():match("^%s*(%S*)")
    if command == "" or command == "options" then
        ns.ToggleOptions()
        return
    elseif command == "pause" or command == "resume" then
        ns.TogglePause()
        return
    elseif command == "debug" then
        local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
        ns.Print(("version %s; accept %s, hand in %s, leave low-level %s, repeatable %s, group %s; paused %s; stopped after a problem %s; JunkMate %s.")
            :format(tostring(version), tostring(ns.db.accept), tostring(ns.db.turnIn), tostring(ns.db.skipTrivial),
                tostring(ns.db.skipRepeatable), tostring(ns.db.skipGroup), tostring(ns.paused), tostring(broken),
                JunkMateLoaded() and "loaded" or "not loaded"))
        return
    elseif TOGGLES[command] then
        ns.db[TOGGLES[command]] = not ns.db[TOGGLES[command]]
    else
        ns.Print("/swiftquest - open the options")
        ns.Print("/swiftquest accept - accept quests when offered, on or off")
        ns.Print("/swiftquest turnin - hand in finished quests, on or off")
        ns.Print("/swiftquest lowlevel - leave low-level (grey) quests to you, on or off")
        ns.Print("/swiftquest repeatable - leave repeatable quests to you, on or off")
        ns.Print("/swiftquest group - leave group, dungeon, raid and elite quests to you, on or off")
        ns.Print("/swiftquest pause - pause or resume for this session (also a key binding)")
        ns.Print("/swiftquest debug - version and settings, for a bug report")
        ns.Print("Hold Shift while talking to someone to do it all by hand that time.")
        return
    end
    ns.Print(Describe())
    ns.RefreshOptions()
end

-- Entry in the minimap's addon list.
function SwiftQuest_OnAddonCompartmentClick()
    ns.ToggleOptions()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loaded)
    if event == "PLAYER_LOGIN" then
        -- Once, the first time: what it does and where to change it.
        if ns.db and not ns.db.welcomed then
            ns.db.welcomed = true
            ns.Print("On: accepts quests and hands them in when you talk to a quest giver. It never picks a reward, pays gold, or takes group, low-level or repeatable quests. Hold Shift to do it yourself; /swiftquest for options.")
        end
        return
    end
    if event == "ADDON_LOADED" then
        if loaded ~= addonName then return end
        SwiftQuestDB = SwiftQuestDB or {}
        -- Versions 0.2.0 to 0.2.4 could read quests aloud; that was taken
        -- out in 0.3.0, so its saved settings are cleared away.
        for _, key in ipairs(OLD_SETTINGS) do
            SwiftQuestDB[key] = nil
        end
        for key, value in pairs(defaults) do
            if SwiftQuestDB[key] == nil then
                SwiftQuestDB[key] = value
            end
        end
        ns.db = SwiftQuestDB
        self:UnregisterEvent("ADDON_LOADED")
        -- Registering an event this client does not have throws.
        for name in pairs(handlers) do
            pcall(self.RegisterEvent, self, name)
        end
        return
    end
    if not ns.db or broken or ns.paused or IsShiftKeyDown() then return end
    -- This presses buttons for the player, so a surprise from the game must
    -- stop it cleanly instead of leaving an error on screen.
    local ok, problem = pcall(handlers[event])
    if not ok then
        broken = true
        ns.Print("Something about quests works differently here, so it has stopped for now: " .. tostring(problem))
    end
end)
