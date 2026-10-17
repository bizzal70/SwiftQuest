# SwiftQuest

Accepts quests and hands them in as soon as you talk to the quest giver. One addon, one repository: `bizzal70/SwiftQuest`.

## Workflow

- **No local `.git`.** GitHub holds all history. Publish with `tools\Publish.ps1 -Message "..."`, which uses a throwaway temp clone and runs the tests first.
- **Layout:** the addon's own files (`SwiftQuest.toc` and the Lua files) sit at the top of the project, because that is what the release packager expects. `tests/`, `tools/`, `media/` and `.github/` are development-only and are left out of the released zip by `.pkgmeta`.
- **Testing in game:** `tools\Link-Addon.ps1` junctions this folder into the client's `Interface\AddOns` as `SwiftQuest`. Edits are live after `/reload`; a new file or a TOC change needs a full client restart.
- **Client install:** `C:\Program Files (x86)\World of Warcraft\_classic_beta_\` (`WowB.exe`). Expect a different flavor folder after launch (reported for 2026-11-04); pass `-Flavor` to the link script then.
- **Tests:** `python tests/run.py` runs the addon in real Lua 5.1 (the `lupa` pip package) against a fake WoW API in `tests/wow_stub.lua`, loading the files the TOC lists. The tests run before every publish and again on GitHub. They prove the addon's own logic only; whether the real client behaves like the stub can only be checked in game. Earlier bugs in sibling addons were wrong assumptions about the game that the fake shared, so anything that calls a game function runs under `pcall` and a surprise ends in a chat line, not an error box.
- **Releases:** a tag starting with `v` runs `.github/workflows/release.yml`, which uses the BigWigs packager (it recognises this client and builds `-forever.zip` as game version 1.60.1). CurseForge and Wago uploads are skipped until their project IDs are in the TOC and their tokens are in the repository secrets.
- **This repository may be made public.** Keep character names, account details and machine-specific paths out of it.

## How it works

- Five events drive it: `GOSSIP_SHOW` (`C_GossipInfo.GetActiveQuests` / `GetAvailableQuests`, then `SelectActiveQuest` / `SelectAvailableQuest` by quest ID), `QUEST_GREETING` (`GetNumActiveQuests`, `GetActiveTitle`, `GetAvailableQuestInfo`, selected by index), `QUEST_DETAIL` (`AcceptQuest`, or `AcknowledgeAutoAcceptQuest` when `QuestGetAutoAccept` is true), `QUEST_PROGRESS` (`CompleteQuest` if `IsQuestCompletable` and `GetQuestMoneyToGet` is 0) and `QUEST_COMPLETE` (`GetQuestReward(1)` only when `GetNumQuestChoices` is 0 or 1).
- Finished quests are handed in before new ones are opened. One step is taken per event; the game's next event carries on from there.
- Shift held skips everything. Every handler runs under `pcall`; on the first failure it prints one line and stops acting for the session, because it presses buttons on the player's behalf.
- Not run in the real game when written (2026-10-13). Unverified: whether Forever lets an addon call the accept and complete functions without a click, and the field names in the gossip quest lists (`isComplete`, `isTrivial`, `repeatable`, `questID`).

## Client facts

Everything below, unless marked verified, comes from community sources during the beta (Warcraft Wiki, GitHub ports, fan guides), not from Blizzard docs. Builds change. Verify in game before relying on any of it.

- Local client was 1.60.1.70338 on 2026-10-11 (read from `WowB.exe`).
- TOC: `## Interface: 16001` (verified in game on build 70338).
- TOC flavor suffix is `_Forever.toc` or `_Camelot.toc`. The TOC `[Game]` variable expands to `Camelot`. Game type for `AllowLoadGameType` is `forever` / `camelot`.
- The client is Retail-based: Midnight 12.x API and UI architecture, not the Classic API. Port from Retail code.
- `WOW_PROJECT_ID` is `18` on build 70338 (verified in game 2026-10-11, along with interface 16001, by a starter addon since removed). Community guides written against earlier builds say it is 1 (`WOW_PROJECT_MAINLINE`); that is out of date, so Retail code gated on `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` will not run here. The name of the constant for 18 is not yet known. Prefer testing for the specific API you need over branching on either number.
- Lua 5.1: no `goto`, no `//`, no bitwise operators (use `bit.band` etc.), no `require`. The TOC is the module loader. Start files with `local addonName, ns = ...`.
- Removed globals: `GetItemInfo`, `GetSpellInfo`, `UnitAura`/`UnitBuff`/`UnitDebuff`, `GetTalentInfo`, `GetNumTalentTabs`, `CombatLogGetCurrentEventInfo`, `InterfaceOptionsFrame_OpenToCategory`. Use `C_Item`, `C_Spell`, `C_UnitAuras`, `C_Traits`, and the `Settings` API.
- `C_Spell.GetSpellInfo` returns a table. Item and spell data can be nil until cached.
- Registering an event that does not exist throws and aborts the file. Wrap speculative `RegisterEvent` calls in `pcall`.
- Secret values (Midnight combat restrictions) are active. In combat, `UnitHealth`, aura data, and some names and booleans can be secret: arithmetic, comparison, and printing fail. Guard with `issecretvalue`, and pass values straight to widgets (`StatusBar:SetValue`, `Cooldown:SetCooldownFromDurationObject`) instead of doing Lua math. Combat-log parsing is not available.
- Check `InCombatLockdown()` before touching protected frames and defer to `PLAYER_REGEN_ENABLED`.
- SavedVariables: initialise in `ADDON_LOADED`. Early beta builds reportedly wrote them but did not read them back; on build 70338 they are read back (confirmed in game 2026-10-11).
- Text to speech (verified in game 2026-10-17: GetTtsVoices lists the Windows voices, e.g. "Microsoft David Desktop - English (United States)", and SpeakText plays them): `C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap)` (12.0 removed the old `destination` argument), `C_VoiceChat.StopSpeakingText()`, `C_VoiceChat.GetTtsVoices()` (list of `{ voiceID, name }`), `C_TTSSettings.GetVoiceOptionID(0 standard / 1 alternate)`. Events `VOICE_CHAT_TTS_PLAYBACK_FINISHED` / `_FAILED`. Messages sent close together play in no fixed order, so Narrator.lua sends one piece at a time. On Windows the text is SAPI XML, so `<` `>` `&` must not reach it. The Forever TTS addon (slash `/ftts`) shows the API works on 1.60.1.
- TTS events seen in game 2026-10-17: `VOICE_CHAT_TTS_PLAYBACK_STARTED(utteranceID)` at send, `VOICE_CHAT_TTS_PLAYBACK_FINISHED(utteranceID)` when the speech really ends; IDs count up from 0 per session. Speech speed varies a lot (0.06 to 0.13 s a character at rate 0), so never time pieces by an estimate when the events are available.
