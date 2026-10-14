# SwiftQuest

Accepts quests and hands them in as soon as you talk to the quest giver. An addon for World of Warcraft: Forever (client 1.60.x).

## What it does

Talk to a quest giver and SwiftQuest does the clicking:

- **accepts** the quests they offer, and
- **hands in** the quests you have finished, straight through to the reward.

Hold **Shift** while talking to someone to do it all by hand that time, for instance when you want to read the quest.

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
