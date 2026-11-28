# SwiftQuest

Accepts quests and hands them in as soon as you talk to the quest giver. An addon for World of Warcraft: Forever (client 1.60.x).

## What it does

Talk to a quest giver and SwiftQuest does the clicking:

- **accepts** the quests they offer, and
- **hands in** the quests you have finished, straight through to the reward.

Hold **Shift** while talking to someone to do it all by hand that time, for instance when you want to read the quest. On a controller, set the **Pause** key instead (Key Bindings > AddOns > SwiftQuest), or type `/swiftquest pause`.

If your bags are too full for a quest's reward, SwiftQuest doesn't try to hand it in (the game would only fail it); it says how much room you need. With [JunkMate](https://www.curseforge.com/wow/addons/junkmate) installed, JunkMate offers to make room and hands the quest in for you.

## What it will not do

- **Choose a reward for you.** A quest that offers a choice stops at the reward window.
- **Pay for a quest.** One that asks for money is left for you to confirm.
- **Pick up low-level (grey), repeatable, or group, dungeon, raid and elite quests**, unless you turn those on. Repeatable quests usually take items each time, and group quests fill your log with ones you won't do solo, so they are left alone by default.

## Options

Type `/swiftquest` (or `/squest`) to open the options, use the addon's entry in the minimap's addon list, find it in the game's **Options > AddOns**, or set a key for it in Key Bindings.

| Setting | Command |
|---|---|
| Accept quests when they are offered | `/swiftquest accept` |
| Hand in finished quests | `/swiftquest turnin` |
| Leave low-level (grey) quests to me | `/swiftquest lowlevel` |
| Leave repeatable quests to me | `/swiftquest repeatable` |
| Leave group, dungeon and elite quests to me | `/swiftquest group` |
| Pause or resume for this session | `/swiftquest pause` (or a key binding) |

`/swiftquest debug` prints the version and settings, handy for a bug report.

## Controller

With a game controller, the **B** button closes the SwiftQuest options, like the X and Escape do. While a window is open, B closes it; once it is closed, B goes back to whatever you have it set to. When a fight starts, B goes straight back to its usual job, even with the window open.

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherLog](https://www.curseforge.com/wow/addons/gatherlog)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[RangeShade](https://www.curseforge.com/wow/addons/rangeshade)** shades action buttons red when your target is out of range.
- **[JunkMate](https://www.curseforge.com/wow/addons/junkmate)** sells junk and repairs at vendors, makes room for loot when your bags are full, and tidies your bank.
- **[AltGlance](https://www.curseforge.com/wow/addons/altglance)** shows all your characters at a glance: level, gold, rested and where you left them.
- **[SessionRecap](https://www.curseforge.com/wow/addons/sessionrecap)** keeps a running tally of your play session: gold, experience per hour, quests, gathering and loot.
- **[MacroKit](https://www.curseforge.com/wow/addons/macrokit)** adds ready-made macros for your class and spec, for all nine classes, and never overwrites your own.
- **[ZoomPad](https://www.curseforge.com/wow/addons/zoompad)** puts big + and - buttons on screen that zoom the camera, made for the Steam Deck touchscreen.
- **[GamepadMacros](https://www.curseforge.com/wow/addons/gamepadmacros)** adds ready-made macros for controller and Steam Deck players: heal yourself, use a quest item, save and wear gear, leave a group, emotes.
- **[FDR - Flight Data Recorder](https://www.curseforge.com/wow/addons/fdr-flight-data-recorder)** times every flight-master flight and counts your next one down to landing.
- **[AuctionMate](https://www.curseforge.com/wow/addons/auctionmate)** prices what you sell at the auction house just under the lowest listing, and warns before you post far too low.

## Installing

Copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `SwiftQuest`, restart the game, and enable SwiftQuest on the character select screen.

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
