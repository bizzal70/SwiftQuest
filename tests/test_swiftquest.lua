-- The game's side: what a quest giver offers, and what gets pressed.
SHIFT = false
PRESSED = {}
local function press(what) PRESSED[#PRESSED + 1] = what end
IsShiftKeyDown = function() return SHIFT end
GOSSIP_ACTIVE, GOSSIP_AVAILABLE = {}, {}
C_GossipInfo = {
    GetActiveQuests = function() return GOSSIP_ACTIVE end,
    GetAvailableQuests = function() return GOSSIP_AVAILABLE end,
    SelectActiveQuest = function(id) press("gossip hand in " .. id) end,
    SelectAvailableQuest = function(id) press("gossip open " .. id) end,
}
GREETING_ACTIVE, GREETING_AVAILABLE = {}, {}   -- lists of { complete = } and { trivial =, repeatable = }
GetNumActiveQuests = function() return #GREETING_ACTIVE end
GetActiveTitle = function(i) return "Quest " .. i, GREETING_ACTIVE[i].complete end
SelectActiveQuest = function(i) press("greeting hand in " .. i) end
GetNumAvailableQuests = function() return #GREETING_AVAILABLE end
GetAvailableQuestInfo = function(i) local q = GREETING_AVAILABLE[i]; return q.trivial or false, 1, q.repeatable or false end
SelectAvailableQuest = function(i) press("greeting open " .. i) end
AUTO_ACCEPTED, COMPLETABLE, COST, CHOICES = false, true, 0, 0
QuestGetAutoAccept = function() return AUTO_ACCEPTED end
AcknowledgeAutoAcceptQuest = function() press("acknowledge") end
AcceptQuest = function() press("accept") end
IsQuestCompletable = function() return COMPLETABLE end
GetQuestMoneyToGet = function() return COST end
CompleteQuest = function() press("continue") end
GetNumQuestChoices = function() return CHOICES end
GetQuestReward = function(choice) press("take reward " .. tostring(choice)) end

local ns = LoadAddon(ADDON_DIR, "SwiftQuest")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end
-- Fires an event and returns what the addon pressed in response.
local function on(event)
    PRESSED = {}
    Fire(event)
    return table.concat(PRESSED, ", ")
end

Fire("QUEST_DETAIL")
check(#PRESSED == 0, "before its settings load, it presses nothing")
Fire("ADDON_LOADED", "SwiftQuest")
check(ns.db.accept and ns.db.turnIn and ns.db.skipTrivial and ns.db.skipRepeatable, "settings start with everything on")

check(on("QUEST_DETAIL") == "accept", "a quest that is offered is accepted")
AUTO_ACCEPTED = true
check(on("QUEST_DETAIL") == "acknowledge", "a quest the game already gave is acknowledged, not accepted twice")
AUTO_ACCEPTED = false

check(on("QUEST_PROGRESS") == "continue", "a finished quest is continued to its rewards")
COMPLETABLE = false
check(on("QUEST_PROGRESS") == "", "an unfinished quest is left alone")
COMPLETABLE, COST = true, 5000
check(on("QUEST_PROGRESS") == "", "a quest that asks for money is never paid for automatically")
COST = 0

check(on("QUEST_COMPLETE") == "take reward 1", "a quest with no choice of reward is completed")
CHOICES = 1
check(on("QUEST_COMPLETE") == "take reward 1", "so is one with a single reward")
CHOICES = 3
check(on("QUEST_COMPLETE") == "", "a quest with a choice of rewards waits for the player to choose")
CHOICES = 0

-- a conversation that lists quests
GOSSIP_ACTIVE = { { questID = 11, isComplete = false }, { questID = 12, isComplete = true } }
GOSSIP_AVAILABLE = { { questID = 21 } }
check(on("GOSSIP_SHOW") == "gossip hand in 12", "in a conversation, a finished quest is handed in first")
GOSSIP_ACTIVE = { { questID = 11, isComplete = false } }
check(on("GOSSIP_SHOW") == "gossip open 21", "then a new quest is opened")
GOSSIP_AVAILABLE = { { questID = 31, isTrivial = true }, { questID = 32, repeatable = true }, { questID = 33 } }
check(on("GOSSIP_SHOW") == "gossip open 33", "low-level and repeatable quests are passed over")
GOSSIP_AVAILABLE = { { questID = 31, isTrivial = true } }
check(on("GOSSIP_SHOW") == "", "and if those are all there is, nothing is pressed")
SlashCmdList.SWIFTQUEST("lowlevel")
check(on("GOSSIP_SHOW") == "gossip open 31", "/swiftquest lowlevel lets low-level quests through")
SlashCmdList.SWIFTQUEST("lowlevel")
GOSSIP_ACTIVE, GOSSIP_AVAILABLE = {}, {}
check(on("GOSSIP_SHOW") == "", "a conversation with no quests is left alone")

-- a quest giver with only a list of quests
GREETING_ACTIVE = { { complete = false }, { complete = true } }
GREETING_AVAILABLE = { { trivial = true }, { repeatable = true }, {} }
check(on("QUEST_GREETING") == "greeting hand in 2", "at a quest giver's list, a finished quest is handed in first")
GREETING_ACTIVE = {}
check(on("QUEST_GREETING") == "greeting open 3", "then the first suitable new quest is opened")
SlashCmdList.SWIFTQUEST("repeatable")
check(on("QUEST_GREETING") == "greeting open 2", "/swiftquest repeatable lets repeatable quests through")
SlashCmdList.SWIFTQUEST("repeatable")

SHIFT = true
check(on("QUEST_DETAIL") == "" and on("QUEST_PROGRESS") == "" and on("QUEST_COMPLETE") == "" and on("QUEST_GREETING") == "", "holding Shift leaves everything to the player")
SHIFT = false

SlashCmdList.SWIFTQUEST("accept")
check(on("QUEST_DETAIL") == "" and on("QUEST_GREETING") == "" and on("QUEST_PROGRESS") == "continue", "/swiftquest accept turns accepting off, and handing in carries on")
SlashCmdList.SWIFTQUEST("accept")
SlashCmdList.SWIFTQUEST("turnin")
check(on("QUEST_PROGRESS") == "" and on("QUEST_COMPLETE") == "" and on("QUEST_DETAIL") == "accept", "/swiftquest turnin turns handing in off, and accepting carries on")
SlashCmdList.SWIFTQUEST("turnin")

-- options window
SlashCmdList.SWIFTQUEST("")
check(SwiftQuestOptions:IsShown(), "/swiftquest opens the options")
local rows = {}
for _, f in ipairs(Frames()) do
    if rawget(f, "Refresh") and f.__scripts.OnClick then rows[#rows + 1] = f end
end
check(#rows == 4, "the options have four switches")
for index, key in ipairs({ "accept", "turnIn", "skipTrivial", "skipRepeatable" }) do
    rows[index].__scripts.OnClick(rows[index])
    local off = not ns.db[key]
    rows[index].__scripts.OnClick(rows[index])
    assert(off and ns.db[key], key)
end
check(true, "each one switches its setting off and on")
SwiftQuest_OnAddonCompartmentClick()
check(not SwiftQuestOptions:IsShown(), "the minimap addon list entry toggles the options")
SlashCmdList.SWIFTQUEST("help")

-- the game behaving differently must stop it cleanly, once
IsQuestCompletable = function() error("something this client does differently") end
local printedBefore = #PRINTED
local ok = pcall(Fire, "QUEST_PROGRESS")
check(ok and PRINTED[#PRINTED]:find("has stopped for now", 1, true) ~= nil, "a surprise from the game is reported in chat, not as an error")
check(on("QUEST_DETAIL") == "" and #PRINTED == printedBefore + 1, "and it then stops pressing anything, without repeating itself")
