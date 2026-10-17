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

-- Text to speech: two Windows voices, and a record of what was said.
SPOKEN = {}          -- { voice =, text = } for each piece sent
STOPS = 0
VOICES = { { voiceID = 1, name = "Microsoft David - English (United States)" }, { voiceID = 2, name = "Microsoft Zira - English (United States)" } }
C_VoiceChat = {
    GetTtsVoices = function() return VOICES end,
    SpeakText = function(voice, text, rate, volume, overlap)
        assert(type(voice) == "number" and type(text) == "string" and type(rate) == "number" and type(volume) == "number", "SpeakText arguments")
        SPOKEN[#SPOKEN + 1] = { voice = voice, text = text }
    end,
    StopSpeakingText = function() STOPS = STOPS + 1 end,
}
C_TTSSettings = { GetVoiceOptionID = function(kind) return kind == 1 and 2 or 1 end }
-- The quest giver and the quest on offer.
NPC = { guid = "Creature-1", name = "Marshal Dughan", sex = 2 }
UnitGUID = function(unit) if unit == "npc" then return NPC.guid end return "Player-1" end
UnitName = function(unit) if unit == "npc" then return NPC.name end return "Bizzaal" end
UnitSex = function(unit) if unit == "npc" then return NPC.sex end return 2 end
UnitClass = function() return "Paladin", "PALADIN" end
UnitRace = function() return "Dwarf", "Dwarf" end
QUEST = { id = 11, title = "Wolves Across the Border", text = "Hey there, $N. <The marshal looks you over.> The wolves are a menace! Bring me 8 pelts.", objectives = "Kill 8 wolves.", progress = "Got those pelts?", reward = "Fine work, |cffffd100hero|r." }
GetQuestID = function() return QUEST.id end
GetTitleText = function() return QUEST.title end
GetQuestText = function() return QUEST.text end
GetObjectiveText = function() return QUEST.objectives end
GetProgressText = function() return QUEST.progress end
GetRewardText = function() return QUEST.reward end
GetGreetingText = function() return "Greetings, traveller." end
C_GossipInfo.GetText = function() return "These are dark times." end
TRIVIAL, REPEATABLE = false, false
LOG = { { title = "Wolves Across the Border", questID = 11 }, { title = "The Fargodeep Mine", questID = 12 } }
SELECTED = 0
C_QuestLog = {
    IsQuestTrivial = function() return TRIVIAL end,
    IsRepeatableQuest = function() return REPEATABLE end,
    GetNumQuestLogEntries = function() return #LOG end,
    GetInfo = function(i) return LOG[i] end,
    GetSelectedQuest = function() return SELECTED end,
    SetSelectedQuest = function(id) SELECTED = id end,
    GetTitleForQuestID = function(id) for _, q in ipairs(LOG) do if q.questID == id then return q.title end end end,
}
GetQuestLogQuestText = function() return "Text of quest " .. SELECTED .. ".", "Objectives of quest " .. SELECTED .. "." end

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
check(#rows == 13, "the options have eight switches and five buttons")
for index, key in ipairs({ "accept", "turnIn", "skipTrivial", "skipRepeatable", "narrate", "listenFirst", "readGreetings", "matchVoice" }) do
    local before = ns.db[key]
    rows[index].__scripts.OnClick(rows[index])
    local changed = ns.db[key] ~= before
    rows[index].__scripts.OnClick(rows[index])
    assert(changed and ns.db[key] == before, key)
end
check(true, "each switch turns its setting over and back")
ns.db.narrate = false
rows[11].__scripts.OnClick(rows[11]); check(ns.db.rate == 2, "the speed button steps the speed up")
rows[11].__scripts.OnClick(rows[11]); rows[11].__scripts.OnClick(rows[11]); check(ns.db.rate == -4, "and comes round to the slowest")
ns.db.rate = 0
rows[12].__scripts.OnClick(rows[12]); check(ns.db.volume == 25, "the volume button goes round too")
ns.db.volume = 100
rows[9].__scripts.OnClick(rows[9]); check(ns.db.maleVoice == 2, "the voice button steps through the installed voices")
ns.db.maleVoice = nil
SPOKEN = {}
rows[13].__scripts.OnClick(rows[13])
check(#SPOKEN == 1 and SPOKEN[1].voice == 1 and SPOKEN[1].text == "Quest givers will sound like this. I am David.", "Hear the voices says a sentence in the male voice: " .. SPOKEN[1].text)
check(ns.ShortVoiceName("Microsoft Zira Desktop - English (United States)") == "Zira" and ns.ShortVoiceName("Microsoft Aria Online (Natural) - English (United States)") == "Aria" and ns.ShortVoiceName("Hazel") == "Hazel", "voice names are shortened to fit the options")
check(rows[9].Refresh and (function() rows[9].Refresh(); return true end)(), "the voice button can show its name")
Fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
NOW = NOW + 5; Fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
check(#SPOKEN == 2 and SPOKEN[2].voice == 2, "and then one in the female voice, once the first has finished")
NOW = NOW + 5; Fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
SwiftQuest_OnAddonCompartmentClick()
check(not SwiftQuestOptions:IsShown(), "the minimap addon list entry toggles the options")
SlashCmdList.SWIFTQUEST("help")

---------------------------------------------------------------------------
-- reading quests aloud
---------------------------------------------------------------------------
check(ns.CleanText("Hey $N. <He nods.> |cffffd100Gold|r & |Hitem:1|h[Linen]|h$B$Bbye") == "Hey Bizzaal. He nods. Gold and [Linen] bye", "quest text is cleaned for speaking: name filled in, brackets, colours and links tidied")
local long = ("This is a sentence of some length, for testing. "):rep(10)
local pieces = ns.SplitText(long:sub(1, -2))
check(#pieces == 3 and pieces[1]:sub(-1) == "." and table.concat(pieces, " ") == long:sub(1, -2), "long text is split at sentences into pieces, losing nothing")
check(#ns.SplitText("No full stop at the end") == 1 and ns.SplitText("One. Two")[1] == "One. Two", "short text stays in one piece")

-- Plays out the reading: reports each piece finished, a moment apart.
local function finishAll()
    for _ = 1, 20 do NOW = NOW + 5; Fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED") end
end
local function said() local t = {} for _, x in ipairs(SPOKEN) do t[#t + 1] = x.text end return table.concat(t, " ") end

SPOKEN = {}
check(on("QUEST_DETAIL") == "accept" and #SPOKEN == 0, "with reading aloud off, nothing is said")
SlashCmdList.SWIFTQUEST("narrate")
check(ns.db.narrate and PRINTED[#PRINTED]:find("Quests are read aloud", 1, true), "/swiftquest narrate turns reading aloud on")

SPOKEN = {}
check(on("QUEST_DETAIL") == "accept", "the quest is still accepted at once")
finishAll()
check(said() == "Wolves Across the Border Hey there, Bizzaal. The marshal looks you over. The wolves are a menace! Bring me 8 pelts. Kill 8 wolves.", "and its title, text and objectives are read: " .. said())
check(SPOKEN[1].voice == 1, "in the male voice for a male quest giver")

SPOKEN = {}
NPC = { guid = "Creature-2", name = "Innkeeper Farley", sex = 3 }
on("QUEST_COMPLETE"); finishAll()
check(said() == "Fine work, hero." and SPOKEN[1].voice == 2, "the hand-in text is read in the female voice for a female quest giver")
ns.db.matchVoice = false
SPOKEN = {}; on("QUEST_PROGRESS"); finishAll()
check(SPOKEN[1].voice == 1 and said() == "Got those pelts?", "with matching off, everyone has the same voice")
ns.db.matchVoice = true

-- a greeting is read first, and the quest after it
SPOKEN = {}
NPC = { guid = "Creature-3", name = "Guard Thomas", sex = 2 }
GOSSIP_AVAILABLE = { { questID = 20 } }
check(on("GOSSIP_SHOW") == "gossip open 20", "the quest is opened from the conversation")
on("QUEST_DETAIL"); finishAll()
check(said():find("^These are dark times%. Wolves Across the Border") ~= nil, "what the quest giver says comes first, then the quest: " .. said())
GOSSIP_AVAILABLE = {}
ns.db.readGreetings = false
SPOKEN = {}; Fire("GOSSIP_SHOW"); Fire("QUEST_GREETING"); finishAll()
check(#SPOKEN == 0, "greetings can be left unread")
ns.db.readGreetings = true

-- skipping what is skipped
TRIVIAL = true
SPOKEN = {}; on("QUEST_DETAIL"); finishAll()
check(#SPOKEN == 0, "grey quests are not read while they are left to the player")
TRIVIAL = false

-- talking to someone new stops what was being read for someone else
SPOKEN = {}; STOPS = 0
on("QUEST_DETAIL")
NPC = { guid = "Creature-4", name = "Remy", sex = 2 }
on("QUEST_PROGRESS"); finishAll()
check(STOPS == 1 and #SPOKEN == 2 and SPOKEN[2].text == "Got those pelts?", "talking to someone new cuts the old reading short")

-- listen first: the accept waits for the reading
SlashCmdList.SWIFTQUEST("listen")
SPOKEN = {}
check(on("QUEST_DETAIL") == "", "in listen-first mode the quest is not accepted while it is read")
PRESSED = {}
finishAll()
check(table.concat(PRESSED, ", ") == "accept", "and is accepted when the reading ends")
on("QUEST_DETAIL"); PRESSED = {}
Fire("QUEST_FINISHED"); finishAll()
check(#PRESSED == 0, "closing the quest window meanwhile leaves the quest alone")
on("QUEST_DETAIL"); PRESSED = {}
SlashCmdList.SWIFTQUEST("stop")
check(table.concat(PRESSED, ", ") == "accept" and not ns.IsSpeaking(), "/swiftquest stop silences it and lets the accept go ahead")
SlashCmdList.SWIFTQUEST("listen")

-- skip, replay and the quest log
SPOKEN = {}
QUEST.text = long
on("QUEST_DETAIL")
local first = #SPOKEN
SlashCmdList.SWIFTQUEST("skip")
check(#SPOKEN == first + 1, "/swiftquest skip moves on to the next piece")
finishAll()
SPOKEN = {}
SlashCmdList.SWIFTQUEST("replay"); finishAll()
check(said():find("^Wolves Across the Border") ~= nil, "/swiftquest replay reads the last quest again")
SPOKEN = {}
SlashCmdList.SWIFTQUEST("read mine"); finishAll()
check(said() == "The Fargodeep Mine Text of quest 12. Objectives of quest 12." and SELECTED == 0, "/swiftquest read finds a quest in the log by part of its name: " .. said())
SPOKEN = {}
SlashCmdList.SWIFTQUEST("read")
check(#SPOKEN == 0 and PRINTED[#PRINTED]:find("Select a quest", 1, true), "with nothing named or selected, it says how to choose one")
SELECTED = 11
SlashCmdList.SWIFTQUEST("read"); finishAll()
check(said():find("^Wolves Across the Border Text of quest 11") ~= nil, "or reads the quest selected in the log")
SELECTED = 0
SPOKEN = {}
SlashCmdList.SWIFTQUEST("read dragons")
check(#SPOKEN == 0 and PRINTED[#PRINTED]:find("No quest in your log matches", 1, true), "a name that matches nothing is reported")

-- the reading bar
SPOKEN = {}; on("QUEST_DETAIL")
check(SwiftQuestNarration and SwiftQuestNarration.__shown, "a bar shows while a quest is read")
finishAll()
check(not SwiftQuestNarration.__shown, "and goes when it ends")

-- a piece the game never reports finished is moved past anyway
SPOKEN = {}; AFTERS = {}
on("QUEST_DETAIL")
local count = #SPOKEN
NOW = NOW + 60
for _, fn in ipairs(AFTERS) do fn() end
check(#SPOKEN == count + 1, "a piece the game never reports finished is moved past after a while")
finishAll()

-- the game without text to speech
local speak = C_VoiceChat.SpeakText
C_VoiceChat.SpeakText = function() error("no voices") end
PRESSED = {}
check(pcall(Fire, "QUEST_DETAIL") and not ns.IsSpeaking() and PRESSED[1] == "accept", "if the game cannot speak, nothing breaks and the quest is still accepted")
C_VoiceChat.SpeakText = speak

-- another quest reader installed
SLASH_FOREVERTTS1 = "/ftts"; SlashCmdList.FOREVERTTS = function() end
Fire("PLAYER_LOGIN")
SPOKEN = {}; on("QUEST_DETAIL"); finishAll()
check(#SPOKEN == 0 and PRINTED[#PRINTED]:find("Forever TTS is installed", 1, true), "with Forever TTS installed, SwiftQuest leaves the reading to it")
SlashCmdList.FOREVERTTS = nil
Fire("PLAYER_LOGIN")
SlashCmdList.SWIFTQUEST("narrate")
check(not ns.db.narrate, "and reading aloud turns off again")

-- the game behaving differently must stop it cleanly, once
IsQuestCompletable = function() error("something this client does differently") end
local printedBefore = #PRINTED
local ok = pcall(Fire, "QUEST_PROGRESS")
check(ok and PRINTED[#PRINTED]:find("has stopped for now", 1, true) ~= nil, "a surprise from the game is reported in chat, not as an error")
check(on("QUEST_DETAIL") == "" and #PRINTED == printedBefore + 1, "and it then stops pressing anything, without repeating itself")
