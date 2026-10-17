local addonName, ns = ...

-- Reads quest text aloud with the game's own text to speech, so the story
-- is not lost when SwiftQuest closes the quest window at once.
--
-- The game speaks with the voices installed in Windows. It plays messages
-- sent close together in no particular order, so the text goes one piece
-- at a time: each piece is sent when the one before has finished.

local CHUNK_LENGTH = 220        -- characters per piece, ending at a sentence
local SECONDS_PER_CHARACTER = 0.075
-- The game reports when each piece starts and finishes (seen in game on
-- 2026-10-17), and those reports are what move the reading on. The clock
-- is only a fallback: if no start is reported within START_WAIT seconds
-- the game is not reporting, so the piece is taken as done after its
-- expected time plus GRACE_SECONDS; if it started but its end never comes,
-- it is given up on after a generous STUCK_FACTOR times its expected time.
-- Speech runs slower than expected at times (0.13 s a character seen).
local START_WAIT = 5
local GRACE_SECONDS = 1.5
local STUCK_FACTOR = 3
local STUCK_EXTRA = 20

-- Male and female Windows voices, to guess which installed voice is which.
local MALE_NAMES = { "david", "mark", "george", "james", "richard", "guy", "ryan", "sean", "ravi", "paul", "daniel" }
local FEMALE_NAMES = { "zira", "hazel", "susan", "heera", "linda", "catherine", "jenny", "aria", "eva", "helena", "hortense", "sonia", "libby" }

local queue = {}                -- pieces still to say: { text =, voice = }
local speaking = false
local speakingSince = 0
local expected = 0              -- seconds the piece being spoken should take
local utterance                 -- the game's number for it, once it says
local cutShort                  -- the number of a piece just stopped, whose end report is old news
local pieceNumber = 0           -- counts pieces, so a timer only acts for its own
local debugEvents = false       -- /swiftquest ttsdebug
local generation = 0            -- bumped on every stop, so stale timers do nothing
local pending                   -- an automatic step waiting for the reading to end
local lastNarration             -- the last thing read in full, for /swiftquest replay
local currentTitle
local conversationWith          -- who the pieces in the queue belong to
local otherReader               -- set when another addon reads quests aloud

local Usable = function(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------

-- Quest text as the game shows it, made fit to be spoken: colour codes and
-- pictures go, links keep their words, and the angle brackets around
-- actions go too, because Windows reads <...> as instructions to the voice.
function ns.CleanText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    -- In case the game has left its placeholders in: $N name, $C class,
    -- $R race, $B a line break, and $g male:female; by the player's sex.
    local ok, name, class, race, sex = pcall(function()
        return UnitName("player"), UnitClass("player"), UnitRace("player"), UnitSex("player")
    end)
    if ok then
        text = text:gsub("%$[Nn]", Usable(name) and name or "")
        text = text:gsub("%$[Cc]", Usable(class) and class or "")
        text = text:gsub("%$[Rr]", Usable(race) and race or "")
        text = text:gsub("%$[Gg]%s*([^:;]*):([^;]*);", function(male, female)
            return (Usable(sex) and sex == 3) and female or male
        end)
    end
    text = text:gsub("%$[Bb]", " ")
    text = text:gsub("[<>]", ""):gsub("&", " and ")
    text = text:gsub("%s+", " ")
    return (text:gsub("^ ", ""):gsub(" $", ""))
end

-- Splits text into pieces of about CHUNK_LENGTH, each ending at a sentence.
function ns.SplitText(text)
    local pieces, current, position = {}, "", 1
    while position <= #text do
        -- The next sentence: up to a full stop, question or exclamation mark
        -- (and any closing quote) followed by a space, or else the rest.
        local _, stop = text:find("[%.%!%?]+[\"']?%s+", position)
        local sentence = text:sub(position, stop or #text):gsub("%s+$", "")
        position = (stop or #text) + 1
        if #current > 0 and #current + #sentence + 1 > CHUNK_LENGTH then
            pieces[#pieces + 1] = current
            current = sentence
        else
            current = (#current > 0) and (current .. " " .. sentence) or sentence
        end
    end
    if #current > 0 then pieces[#pieces + 1] = current end
    return pieces
end

---------------------------------------------------------------------------
-- Voices
---------------------------------------------------------------------------

local function Voices()
    local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
    return ok and type(voices) == "table" and voices or {}
end
ns.Voices = Voices

-- "Microsoft David Desktop - English (United States)" -> "David": the
-- full names are too long for the options window, and for saying aloud.
function ns.ShortVoiceName(name)
    if type(name) ~= "string" then return name end
    local short = name:gsub("^Microsoft ", ""):gsub("%s*%-%s.*$", ""):gsub(" Desktop$", ""):gsub(" Online.*$", "")
    return short ~= "" and short or name
end

local function NameOf(voiceID)
    for _, voice in ipairs(Voices()) do
        if voice.voiceID == voiceID then return ns.ShortVoiceName(voice.name) end
    end
end
ns.VoiceName = NameOf

local function Guess(names)
    for _, voice in ipairs(Voices()) do
        local lower = type(voice.name) == "string" and voice.name:lower() or ""
        for _, name in ipairs(names) do
            if lower:find(name, 1, true) then return voice.voiceID end
        end
    end
end

-- The voice the game's own settings use, standard (0) or alternate (1).
local function GameVoice(kind)
    local ok, voiceID = pcall(C_TTSSettings.GetVoiceOptionID, kind)
    if ok and Usable(voiceID) then return voiceID end
    local first = Voices()[1]
    return first and first.voiceID
end

-- Which voice to use for "male" or "female": the one chosen in the
-- options, else an installed voice that sounds like it, else the game's.
function ns.VoiceFor(sex)
    local db = ns.db
    if sex == "female" then
        if db.femaleVoice and NameOf(db.femaleVoice) then return db.femaleVoice end
        return Guess(FEMALE_NAMES) or GameVoice(1)
    end
    if db.maleVoice and NameOf(db.maleVoice) then return db.maleVoice end
    return Guess(MALE_NAMES) or GameVoice(0)
end

-- The quest giver's voice: female for a female quest giver, male otherwise.
local function SpeakerVoice()
    if not ns.db.matchVoice then return ns.VoiceFor("male") end
    local ok, sex = pcall(UnitSex, "npc")
    if ok and Usable(sex) and sex == 3 then return ns.VoiceFor("female") end
    return ns.VoiceFor("male")
end

-- Steps through the installed voices for the options window.
function ns.NextVoice(sex)
    local voices = Voices()
    if #voices == 0 then return end
    local key = sex == "female" and "femaleVoice" or "maleVoice"
    local now = ns.VoiceFor(sex)
    for index, voice in ipairs(voices) do
        if voice.voiceID == now then
            ns.db[key] = voices[index % #voices + 1].voiceID
            return
        end
    end
    ns.db[key] = voices[1].voiceID
end

---------------------------------------------------------------------------
-- Speaking
---------------------------------------------------------------------------

local SpeakNext

local function Finished()
    speaking = false
    if #queue > 0 then
        SpeakNext()
        return
    end
    ns.UpdateBar()
    -- The reading is over, so the step it was holding back can go ahead.
    local step = pending
    pending = nil
    if step then ns.Act(step) end
end

function SpeakNext()
    local piece = table.remove(queue, 1)
    if not piece then Finished(); return end
    speaking = true
    speakingSince = GetTime()
    utterance = nil
    pieceNumber = pieceNumber + 1
    local mine = pieceNumber
    expected = #piece.text * SECONDS_PER_CHARACTER * (1 - ns.db.rate / 20)
    if debugEvents then
        ns.Print(("speaking %d characters, expected %.1f s"):format(#piece.text, expected))
    end
    local ok = pcall(C_VoiceChat.SpeakText, piece.voice, piece.text, ns.db.rate, ns.db.volume, false)
    if not ok then
        -- Nothing will come back from the game, so move straight on.
        speaking = false
        queue = {}
        Finished()
        return
    end
    ns.UpdateBar()
    -- The fallbacks. Each checks that its own piece is still the one being
    -- spoken, so a timer left over from an earlier piece does nothing.
    local function MoveOn(why)
        if mine == pieceNumber and speaking then
            if debugEvents then ns.Print(why) end
            speaking = false
            SpeakNext()
        end
    end
    C_Timer.After(START_WAIT, function()
        if mine == pieceNumber and speaking and utterance == nil then
            -- No start reported: go by the clock for this piece.
            C_Timer.After(math.max(0, expected + GRACE_SECONDS - START_WAIT), function()
                MoveOn("the game did not report this piece; moving on by the clock")
            end)
        end
    end)
    C_Timer.After(expected * STUCK_FACTOR + STUCK_EXTRA, function()
        MoveOn("the end of this piece was never reported; moving on")
    end)
end

-- Adds text to what is being read, in the voice given.
local function Say(text, voice)
    for _, piece in ipairs(ns.SplitText(ns.CleanText(text))) do
        queue[#queue + 1] = { text = piece, voice = voice }
    end
    if not speaking then SpeakNext() end
end

function ns.IsSpeaking()
    return speaking or #queue > 0
end

-- Stops reading. The automatic step being held back goes ahead, as the
-- player has chosen to move on.
function ns.StopNarration()
    generation = generation + 1
    queue = {}
    if speaking then
        speaking = false
        cutShort = utterance
        pcall(C_VoiceChat.StopSpeakingText)
    end
    ns.UpdateBar()
    local step = pending
    pending = nil
    if step then ns.Act(step) end
end

-- Skips to the next piece.
function ns.SkipNarration()
    if not speaking then return end
    generation = generation + 1
    speaking = false
    cutShort = utterance
    pcall(C_VoiceChat.StopSpeakingText)
    -- The game reports the cut-short piece as finished; that report is
    -- ignored because speaking is already false.
    SpeakNext()
end

-- Prints the game's speech reports as they arrive, to see what this
-- client sends and when.
function ns.ToggleTtsDebug()
    debugEvents = not debugEvents
    ns.Print("Speech reports " .. (debugEvents and "will be shown in chat." or "are no longer shown."))
end

-- Runs an automatic step now, or, in "listen first" mode, once the reading
-- has finished.
function ns.AfterNarration(step)
    if ns.db.narrate and ns.db.listenFirst and ns.IsSpeaking() then
        pending = step
    else
        ns.Act(step)
    end
end

---------------------------------------------------------------------------
-- What to read
---------------------------------------------------------------------------

local function Ready()
    return ns.db and ns.db.narrate and not otherReader
end

-- A new person to talk to clears what was being read for someone else.
local function StartConversation()
    local ok, who = pcall(UnitGUID, "npc")
    if not ok or not Usable(who) then
        ok, who = pcall(UnitName, "npc")
        if not ok or not Usable(who) then who = nil end
    end
    if who ~= conversationWith then
        conversationWith = who
        if ns.IsSpeaking() then
            generation = generation + 1
            queue = {}
            pending = nil
            if speaking then
                speaking = false
                cutShort = utterance
                pcall(C_VoiceChat.StopSpeakingText)
            end
        end
    end
end

local function Read(title, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        local text = select(index, ...)
        if Usable(text) and type(text) == "string" and text:find("%S") then
            parts[#parts + 1] = text
        end
    end
    if #parts == 0 then return end
    local whole = table.concat(parts, " ")
    lastNarration = { title = title, text = whole, voice = SpeakerVoice() }
    currentTitle = title
    Say(whole, lastNarration.voice)
end

-- Whether this quest is one the player has chosen to leave alone.
local function Unwanted()
    local questID = GetQuestID()
    if not Usable(questID) or questID == 0 then return false end
    if ns.db.skipTrivial and C_QuestLog.IsQuestTrivial then
        local trivial = C_QuestLog.IsQuestTrivial(questID)
        if Usable(trivial) and trivial then return true end
    end
    if ns.db.skipRepeatable and C_QuestLog.IsRepeatableQuest then
        local repeatable = C_QuestLog.IsRepeatableQuest(questID)
        if Usable(repeatable) and repeatable then return true end
    end
    return false
end

local function Title()
    local title = GetTitleText()
    return Usable(title) and title or nil
end

local readers = {}

function readers.GOSSIP_SHOW()
    if not ns.db.readGreetings then return end
    StartConversation()
    local text = C_GossipInfo.GetText()
    local name = UnitName("npc")
    Read(Usable(name) and name or nil, text)
end

function readers.QUEST_GREETING()
    if not ns.db.readGreetings then return end
    StartConversation()
    local name = UnitName("npc")
    Read(Usable(name) and name or nil, GetGreetingText())
end

function readers.QUEST_DETAIL()
    StartConversation()
    if Unwanted() then return end
    local objectives = GetObjectiveText()
    Read(Title(), Title(), GetQuestText(), objectives)
end

function readers.QUEST_PROGRESS()
    StartConversation()
    if Unwanted() then return end
    Read(Title(), GetProgressText())
end

function readers.QUEST_COMPLETE()
    StartConversation()
    if Unwanted() then return end
    Read(Title(), GetRewardText())
end

-- Called by Core for each quest window, before it acts on it.
function ns.Narrate(event)
    if not Ready() or not readers[event] then return end
    local ok, problem = pcall(readers[event])
    if not ok then
        ns.Print("Could not read this aloud: " .. tostring(problem))
    end
end

-- Reads the last thing again.
function ns.Replay()
    if not lastNarration then
        ns.Print("Nothing has been read aloud yet.")
        return
    end
    ns.StopNarration()
    currentTitle = lastNarration.title
    Say(lastNarration.text, lastNarration.voice)
end

-- Reads a quest from the quest log: the one whose title contains the
-- words given, or else the one selected in the log.
function ns.ReadFromLog(words)
    local ok, problem = pcall(function()
        local questID
        words = words and words:lower():match("^%s*(.-)%s*$") or ""
        if words ~= "" then
            for index = 1, C_QuestLog.GetNumQuestLogEntries() do
                local info = C_QuestLog.GetInfo(index)
                if info and not info.isHeader and Usable(info.title) and info.title:lower():find(words, 1, true) then
                    questID = info.questID
                    break
                end
            end
            if not questID then
                ns.Print("No quest in your log matches \"" .. words .. "\".")
                return
            end
        else
            questID = C_QuestLog.GetSelectedQuest()
            if not Usable(questID) or not questID or questID == 0 then
                ns.Print("Select a quest in your quest log first, or type part of its name: /swiftquest read wolves")
                return
            end
        end
        local before = C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(questID)
        local description, objectives = GetQuestLogQuestText()
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if before and before ~= questID then C_QuestLog.SetSelectedQuest(before) end
        ns.StopNarration()
        lastNarration = { title = title, text = table.concat({ title or "", description or "", objectives or "" }, " "), voice = ns.VoiceFor("male") }
        currentTitle = title
        Say(lastNarration.text, lastNarration.voice)
    end)
    if not ok then
        ns.Print("Could not read that quest: " .. tostring(problem))
    end
end

-- A short sentence in each voice, for the options window's test button.
function ns.TestVoices()
    ns.StopNarration()
    currentTitle = "Voice test"
    local male, female = ns.VoiceFor("male"), ns.VoiceFor("female")
    if not male then
        ns.Print("The game has no text to speech voice to use. Check Options, Accessibility, Text to Speech, and the speech voices installed in Windows.")
        return
    end
    Say(("Quest givers will sound like this. I am %s."):format(NameOf(male) or "the game's voice"), male)
    if ns.db.matchVoice and female ~= male then
        Say(("And female quest givers like this. I am %s."):format(NameOf(female) or "the game's other voice"), female)
    end
end

---------------------------------------------------------------------------
-- The reading bar: what is being read, with Skip and Stop
---------------------------------------------------------------------------

local bar, barTitle

local function BarButton(text, x, onClick)
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(46, 20)
    button:SetPoint("RIGHT", x, 0)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(1, 1, 1, 0.08)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateBar()
    bar = CreateFrame("Frame", addonName .. "Narration", UIParent)
    bar:SetSize(300, 30)
    local position = ns.db.barPosition
    if position then
        bar:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        bar:SetPoint("TOP", 0, -140)
    end
    bar:SetFrameStrata("MEDIUM")
    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.barPosition = { point, relativePoint, x, y }
    end)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.05, 0.05, 0.06, 0.9)
    local accent = bar:CreateTexture(nil, "BORDER")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(3)
    accent:SetColorTexture(0.85, 0.63, 0.40, 1)
    barTitle = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barTitle:SetPoint("LEFT", 10, 0)
    barTitle:SetPoint("RIGHT", -104, 0)
    barTitle:SetJustifyH("LEFT")
    barTitle:SetWordWrap(false)
    BarButton("Stop", -4, function() ns.StopNarration() end)
    BarButton("Skip", -54, function() ns.SkipNarration() end)
    bar:Hide()
end

function ns.UpdateBar()
    if not ns.db or not ns.db.showBar then
        if bar then bar:Hide() end
        return
    end
    if not bar then CreateBar() end
    if ns.IsSpeaking() then
        barTitle:SetText("|cffd9a066Reading:|r " .. (currentTitle or "quest"))
        bar:Show()
    else
        bar:Hide()
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Another quest reader already installed: two voices at once would be no
-- use, so SwiftQuest leaves the reading to it.
local OTHER_READERS = { ["/ftts"] = "Forever TTS" }

local function FindOtherReader()
    for key in pairs(SlashCmdList) do
        for index = 1, 3 do
            local command = _G["SLASH_" .. key .. index]
            if type(command) == "string" and OTHER_READERS[command:lower()] then
                return OTHER_READERS[command:lower()]
            end
        end
    end
end

-- A "Listen" button on the quest log, which reads the quest selected
-- there. Which quest log this client has is not certain, so it looks for
-- the known ones and adds nothing if none is found; /swiftquest read works
-- either way.
local listenButtonAdded = false
local function AddListenButton()
    if listenButtonAdded then return end
    listenButtonAdded = true
    local details = (QuestMapFrame and QuestMapFrame.DetailsFrame) or QuestLogDetailFrame or QuestLogFrame
    if not details then return end
    local button = CreateFrame("Button", addonName .. "ListenButton", details)
    button:SetSize(64, 20)
    button:SetPoint("TOPRIGHT", details, "TOPRIGHT", -36, -4)
    button:SetFrameLevel((details:GetFrameLevel() or 1) + 10)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.05, 0.05, 0.06, 0.85)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText("Listen")
    button:SetScript("OnClick", function() ns.ReadFromLog("") end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("SwiftQuest")
        GameTooltip:AddLine("Read this quest aloud", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs({ "VOICE_CHAT_TTS_PLAYBACK_STARTED", "VOICE_CHAT_TTS_PLAYBACK_FINISHED", "VOICE_CHAT_TTS_PLAYBACK_FAILED",
        "VOICE_CHAT_TTS_SPEAK_TEXT_UPDATE", "QUEST_FINISHED", "GOSSIP_CLOSED" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...)
    if not ns.db then return end
    if debugEvents and event:find("^VOICE_CHAT") then
        local args = {}
        for index = 1, select("#", ...) do args[#args + 1] = tostring((select(index, ...))) end
        ns.Print(("%s (%s) at %.1f s"):format(event:gsub("VOICE_CHAT_TTS_", ""), table.concat(args, ", "), GetTime() - speakingSince))
    end
    if event == "PLAYER_LOGIN" then
        otherReader = FindOtherReader()
        pcall(AddListenButton)
        if otherReader and ns.db.narrate then
            ns.Print(otherReader .. " is installed, so SwiftQuest leaves reading quests aloud to it.")
        end
    elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
        -- The window has closed, so there is nothing left to press.
        pending = nil
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
        -- The first piece to start after sending is ours; remember its number.
        local id = ...
        if speaking and utterance == nil and Usable(id) then utterance = id end
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" or event == "VOICE_CHAT_TTS_PLAYBACK_FAILED" then
        if not speaking then return end
        local id = ...
        local elapsed = GetTime() - speakingSince
        -- The end of a piece just cut short is old news.
        if Usable(id) and id == cutShort then return end
        -- Before the start of ours is reported, an end can only be another's,
        -- unless it comes so late that the start report was simply missed.
        if utterance == nil and elapsed < START_WAIT then return end
        -- A report about some other piece of speech is not ours.
        if utterance ~= nil and Usable(id) and id ~= utterance then return end
        speaking = false
        SpeakNext()
    end
end)

function ns.OtherReader()
    return otherReader
end
