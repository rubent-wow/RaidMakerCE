# RaidMakerCE

A Classic WoW addon that automates raid invitations. Import sign-up data from [raid-helper.xyz](https://raid-helper.xyz) or create a custom raid on the fly. Players type `+` in guild chat or whisper to receive an automatic invite.

## Features

- **Imported raids** - Paste raid-helper.xyz JSON to build a roster from sign-up data
- **Custom raids** - Create a raid with a name and max player limit, open to anyone
- **Auto-invite** - Monitors guild chat and whispers for `+` messages
- **Open invite mode** - Switch from registered-only to open invites at any time
- **Alt name support** - Names with `/` or `|` (e.g., "Thespirit/Torinas") match any alt
- **Auto-responses** - Unregistered players and full-raid requests get a polite whisper reply
- **Live roster UI** - Color-coded status tracking with scrollable player list
- **Raid sync** - Detects players joining, leaving, or being invited by assistants
- **Persistence** - State survives `/reload` via SavedVariables
- **In-game help** - Click the `?` button for a quick usage guide

## Installation

1. Download or clone this repository
2. Copy the `RaidMakerCE/` folder into your WoW `Interface/AddOns/` directory
3. Restart WoW or type `/reload`

## Usage

### Importing from raid-helper.xyz

1. In a Raid-Helper post in Discord, click on the **Web View** link
2. Click on the **JSON** badge in the top right of the raid panel
3. Copy the JSON contents to your clipboard (`Ctrl+A`, `Ctrl+C`)
4. In-game, click **Paste** (or `/rm paste`), paste the contents (`Ctrl+V`), then click **Load**

### Imported Raid
3. Form a party with at least one other player
4. Click **Start** to begin invite mode (announces in guild chat), or **Quiet** for no announcement
5. Registered players type `+` in guild chat or whisper to receive an invite
6. Click **Open** to allow anyone to join once the registered roster is filled
7. Click **Stop** when done

### Custom Raid

1. Click **Create** (or `/rm create <name> [max]`), enter a raid name and optional max players
2. The raid enters open invite mode immediately — anyone typing `+` gets invited
3. Existing raid members are automatically added to the roster
4. Click **Stop** when done

### Commands

| Command | Description |
|---------|-------------|
| `/rm` | Toggle the roster window |
| `/rm paste` | Open the JSON paste dialog |
| `/rm create <name> [max]` | Create a custom raid |
| `/rm start` | Start invite mode (announces in guild chat) |
| `/rm startquiet` | Start invite mode without announcing |
| `/rm open` | Switch to open invite mode (anyone can join) |
| `/rm stop` | Stop invite mode |
| `/rm invite <name>` | Manually invite a player |
| `/rm reset` | Clear all loaded data |

### Roster UI

The roster window displays all players with color-coded status:

- **White** - Pending (hasn't typed `+` yet)
- **Yellow** - Invited (waiting to join)
- **Green** - In Raid
- **Red** - Declined
- **Orange** - Tentative

The title bar shows the raid name and max player limit. The status bar shows counts for each state and the current mode (LOADED, INVITING, or OPEN).

Buttons: **Paste** | **Create** | **Start** | **Quiet** | **Open** | **Stop** | **Reset**

Click the **?** button next to the close button for an in-game help guide.

## How It Works

- **Sign-up filtering**: Entries marked as "Absence" are excluded. All other sign-ups (including "Tentative") are registered.
- **Invite eligibility**: For imported raids, only the first 40 sign-ups by position are auto-invited. Players beyond position 40 get a whisper explaining that only the first 40 get auto-invites but there may be space if people don't show up. Unregistered players get a separate message letting them know to be patient. In open mode or custom raids, anyone is eligible.
- **Name matching**: Names containing `/` or `|` are split so any alt name triggers a match. All matching is case-insensitive.
- **Decline recovery**: If a player declines and types `+` again, they will be re-invited.
- **Raid full**: When the raid hits the max player limit, new `+` requests receive a whisper that the raid is full.
- **Raid conversion**: If you're in a party when starting invite mode, the addon automatically converts to a raid.
- **Raid sync**: Players invited by assistants or already in the raid are automatically detected and added to the roster. In custom raids, players who leave are removed from the roster.
- **Class detection**: For players joining via open invite or assistant invite, the addon detects their class from the raid roster API.
- **Disband detection**: If the raid disbands, invite mode stops automatically and tracking resets.

## Requirements

- Classic WoW client (1.12.x interface)
- Raid leader or assist privileges to send invites

## File Structure

```
RaidMakerCE/
  RaidMakerCE.toc          Addon manifest
  RaidMakerCEJSON.lua       JSON parser (Lua 5.0 compatible)
  RaidMakerCE.lua           Core logic and event handling
  RaidMakerCEUI.lua         UI rendering
  RaidMakerCE.xml           Frame definitions
```

## License

0BSD
