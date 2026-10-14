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
}

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

local function Wanted(isTrivial, isRepeatable)
    if ns.db.skipTrivial and Usable(isTrivial) and isTrivial then return false end
    if ns.db.skipRepeatable and Usable(isRepeatable) and isRepeatable then return false end
    return true
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
            if Usable(quest.questID) and Wanted(quest.isTrivial, quest.repeatable) then
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
    else
        AcceptQuest()
    end
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
    return ("It %s%s."):format(table.concat(doing, " and "),
        #leaving > 0 and (", leaving " .. table.concat(leaving, " and ") .. " quests to you") or "")
end

local TOGGLES = { accept = "accept", turnin = "turnIn", lowlevel = "skipTrivial", repeatable = "skipRepeatable" }

SLASH_SWIFTQUEST1 = "/swiftquest"
SLASH_SWIFTQUEST2 = "/squest"
SlashCmdList.SWIFTQUEST = function(msg)
    local command = (msg or ""):lower():match("^%s*(%S*)")
    if command == "" or command == "options" then
        ns.ToggleOptions()
        return
    elseif TOGGLES[command] then
        ns.db[TOGGLES[command]] = not ns.db[TOGGLES[command]]
    else
        ns.Print("/swiftquest - open the options")
        ns.Print("/swiftquest accept - accept quests when offered, on or off")
        ns.Print("/swiftquest turnin - hand in finished quests, on or off")
        ns.Print("/swiftquest lowlevel - leave low-level (grey) quests to you, on or off")
        ns.Print("/swiftquest repeatable - leave repeatable quests to you, on or off")
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
frame:SetScript("OnEvent", function(self, event, loaded)
    if event == "ADDON_LOADED" then
        if loaded ~= addonName then return end
        SwiftQuestDB = SwiftQuestDB or {}
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
    if not ns.db or broken or IsShiftKeyDown() then return end
    -- This presses buttons for the player, so a surprise from the game must
    -- stop it cleanly instead of leaving an error on screen.
    local ok, problem = pcall(handlers[event])
    if not ok then
        broken = true
        ns.Print("Something about quests works differently here, so it has stopped for now: " .. tostring(problem))
    end
end)
