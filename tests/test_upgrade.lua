-- A player who used a version that could read quests aloud (0.2.x)
-- updates to 0.3.0, where that feature is gone.
SwiftQuestDB = { accept = true, turnIn = false, narrate = true, listenFirst = true, rate = 2, volume = 50,
    maleVoice = 1, femaleVoice = 2, readGreetings = true, matchVoice = true, showBar = true, barPosition = { "TOP" } }

local ns = LoadAddon(ADDON_DIR, "SwiftQuest")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end

Fire("ADDON_LOADED", "SwiftQuest")
local left = {}
for _, key in ipairs({ "narrate", "listenFirst", "readGreetings", "matchVoice", "maleVoice", "femaleVoice", "rate", "volume", "showBar", "barPosition" }) do
    if SwiftQuestDB[key] ~= nil then left[#left + 1] = key end
end
check(#left == 0, "the old reading-aloud settings are cleared away: " .. table.concat(left, ", "))
check(ns.db.accept == true and ns.db.turnIn == false and ns.db.skipTrivial == true, "the quest settings are kept, and missing ones filled in")
check(ns.Narrate == nil and SwiftQuestNarration == nil and SlashCmdList.SWIFTQUEST, "nothing of the reading aloud is left")
