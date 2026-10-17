-- A player who used 0.2.3, where reading aloud was on for the whole
-- account, logs in on a character that has never run 0.2.4.
SwiftQuestDB = { accept = true, turnIn = false, narrate = true, listenFirst = true, rate = 2 }
SwiftQuestCharDB = nil

local ns = LoadAddon(ADDON_DIR, "SwiftQuest")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end

Fire("ADDON_LOADED", "SwiftQuest")
check(ns.db.narrate == false and ns.db.listenFirst == false, "a character starts with reading aloud off, whatever the account had")
check(SwiftQuestDB.narrate == nil and SwiftQuestDB.listenFirst == nil, "the old account-wide switches are dropped")
check(ns.db.turnIn == false and ns.db.rate == 2 and ns.db.skipTrivial == true, "the other settings are kept, and new ones filled in")
