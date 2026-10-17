# SwiftQuest

## 0.2.2

- Fixed: with "Wait for the reading before accepting" on, quests were accepted while still being read. The game can report a piece of speech as finished when it has only passed it to Windows; such early reports are no longer believed, and only reports about SwiftQuest's own speech count.
- In that mode, choosing a quest from a conversation now waits for the greeting to be read too.
- `/swiftquest ttsdebug` shows the game's speech reports in chat.

## 0.2.1

- Voice names are shortened ("David" rather than "Microsoft David Desktop - English (United States)") so they fit in the options window.

## 0.2.0

- Reads quests aloud with the game's text to speech (off until you turn it on): the story and objectives when you pick a quest up, and what the quest giver says when you hand it in. The quest is still accepted at once and the reading carries on.
- A female voice for female quest givers and a male one for the rest, each chosen in the options, with speed and volume.
- "Wait for the reading before accepting", for hearing the story first.
- The quest giver's greeting is read before the quest.
- Grey and repeatable quests are not read while they are left to you.
- A bar with Skip and Stop while reading, key bindings for Stop, Skip and Replay, a Listen button in the quest log, and `/swiftquest read` for any quest in your log.
- Leaves the reading to Forever TTS if that addon is installed.

## 0.1.0

- First version.
