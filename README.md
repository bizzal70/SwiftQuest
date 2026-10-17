# SwiftQuest

Accepts quests and hands them in as soon as you talk to the quest giver, and can read them aloud so you still get the story. An addon for World of Warcraft: Forever (client 1.60.x).

## What it does

Talk to a quest giver and SwiftQuest does the clicking:

- **accepts** the quests they offer, and
- **hands in** the quests you have finished, straight through to the reward.

Hold **Shift** while talking to someone to do it all by hand that time, for instance when you want to read the quest.

## Reading quests aloud

Turn on **Read quests aloud** in the options (or `/swiftquest narrate`) and SwiftQuest reads each quest to you with the game's text to speech: the title, the story and the objectives when you pick it up, and what the quest giver says when you hand it in. The quest is still accepted at once, and the reading carries on after the window closes, so you can walk off and listen.

- **A voice to suit the quest giver:** a female voice for female quest givers, a male one for everyone else. Choose each voice, the speed and the volume in the options, and try them with **Hear the voices**.
- **Listen first:** if you would rather hear the story before taking the quest, turn on **Wait for the reading before accepting**. Accepting and handing in then wait until the reading ends; Stop lets them go ahead.
- **What the quest giver says first:** their greeting is read before the quest. This can be turned off.
- **Grey and repeatable quests** are not read while SwiftQuest is leaving them to you.
- **Skip and Stop:** a small bar shows what is being read, with Skip and Stop. Drag it where you like. There are key bindings for Stop, Skip and Replay under Key Bindings, AddOns.
- **Hear a quest again:** `/swiftquest replay` reads the last one again; the **Listen** button in the quest log, or `/swiftquest read`, reads the quest selected there; `/swiftquest read wolves` reads the quest in your log with "wolves" in its name.
- **Forever TTS:** if you already use the Forever TTS addon, SwiftQuest leaves the reading to it, so two voices never talk over each other.

The voices are the ones installed in Windows. If you hear nothing, check **Options, Accessibility, Text to Speech** in the game and the speech voices in Windows settings. Stopping the reading also stops any other text to speech the game is doing at that moment, such as reading chat aloud.

## What it will not do

- **Choose a reward for you.** A quest that offers a choice stops at the reward window.
- **Pay for a quest.** One that asks for money is left for you to confirm.
- **Pick up low-level (grey) or repeatable quests**, unless you turn those on. Repeatable quests usually take items each time, so they are left alone by default.

## Options

Type `/swiftquest` to open the options, or use the addon's entry in the minimap's addon list.

| Setting | Command |
|---|---|
| Accept quests when they are offered | `/swiftquest accept` |
| Hand in finished quests | `/swiftquest turnin` |
| Leave low-level (grey) quests to me | `/swiftquest lowlevel` |
| Leave repeatable quests to me | `/swiftquest repeatable` |
| Read quests aloud | `/swiftquest narrate` |
| Wait for the reading before accepting | `/swiftquest listen` |
| Stop, skip ahead, read the last quest again | `/swiftquest stop`, `skip`, `replay` |
| Read a quest from your log | `/swiftquest read [part of its name]` |

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherTrail](https://github.com/bizzal70/GatherTrail)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[RangeShade](https://www.curseforge.com/wow/addons/rangeshade)** shades action buttons red when your target is out of range.
- **[VendorMate](https://github.com/bizzal70/VendorMate)** sells junk and repairs at vendors, and warns when your gear is wearing out.
- **[AltBoard](https://github.com/bizzal70/AltBoard)** shows all your characters at a glance: level, gold, rested and where you left them.
- **[SessionRecap](https://github.com/bizzal70/SessionRecap)** keeps a running tally of your play session: gold, experience per hour, quests, gathering and loot.

## Installing

Copy this folder into `World of Warcraft\_classic_beta_\Interface\AddOns\` as `SwiftQuest`, restart the game, and enable SwiftQuest on the character select screen.

## Developing

- `tools\Link-Addon.ps1` links this folder into the game's AddOns folder, so edits are live after `/reload`.
- `python tests/run.py` runs the tests (`pip install lupa` once). They run the addon in real Lua 5.1 against a fake of the game's API.
- `tools\Publish.ps1 -Message "..."` runs the tests and pushes to GitHub. GitHub runs the tests again on every push.

## Releasing

`tools\Publish.ps1 -Message "Release x.y.z" -Tag vx.y.z` publishes and tags. The tag makes GitHub package the addon and attach the zip to a GitHub release.

To also upload to CurseForge and Wago, two things are needed once:

1. Create the project on each site, then add its ID to `SwiftQuest.toc`:
   `## X-Curse-Project-ID: 123456` and `## X-Wago-ID: abc123`.
2. Create an upload token on each site and add it to this repository's secrets (Settings, Secrets and variables, Actions) as `CF_API_KEY` and `WAGO_API_TOKEN`.

Before each release: raise `## Version:` in `SwiftQuest.toc` and add the version to `CHANGELOG.md`.

## Licence

MIT. See `LICENSE`.
