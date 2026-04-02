# RaidMakerCE

A Classic WoW addon that automates raid invitations. Import sign-up data from [raid-helper.xyz](https://raid-helper.xyz) or create a custom raid on the fly. Players type `+` in guild chat or whisper to receive an automatic invite.

## Features

- **Imported raids** - Paste raid-helper.xyz JSON to build a roster from sign-up data
- **Custom raids** - Create a raid with a name and max player limit, open to anyone
- **Auto-invite** - Monitors guild chat and whispers for `+` messages
- **Open invite mode** - Switch from registered-only to open invites at any time
- **Alt name support** - Names with `/` or `|` (e.g., "Thespirit/Torinas") match any alt
- **Class verification** - Checks guild roster to prevent wrong-alt invites; optional post-join verification for non-guild members
- **Auto-responses** - Unregistered players, overflow sign-ups, and full-raid requests each get a distinct whisper reply
- **Spec name cleanup** - Strips raid-helper suffixes (e.g., "Holy1" displays as "Holy")
- **Live roster UI** - Color-coded status tracking with scrollable player list
- **Raid sync** - Detects players joining, leaving, or being invited by assistants
- **Auto party-to-raid conversion** - Start solo, first `+` invite creates a party, auto-converts to raid when they join
- **Persistence** - State survives `/reload` via SavedVariables
- **In-game help** - Click the **?** button for a quick usage guide
- **Configurable settings** - Click the **Config** button to toggle options like post-join class checks

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

1. After loading JSON, click **Start** (announces in guild chat) or **Quiet** (no announcement)
2. Registered players type `+` in guild chat or whisper to receive an invite
3. Click **Open** to allow anyone to join once the registered roster is filled
4. Click **Stop** when done

You can start invite mode even while solo — the addon will auto-convert to a raid once the first person joins your party.

### Custom Raid

1. Click **Create** (or `/rm create <name> [max]`), enter a raid name and optional max players (defaults to 40 if left blank)
2. Click **Start**, **Quiet**, or **Open** to begin inviting
3. Anyone typing `+` in guild chat or whisper gets invited and added to the roster
4. Existing raid members are automatically added to the roster
5. Click **Stop** when done

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

- Click the **?** button (top right) for an in-game help guide
- Click the **Config** button (top left) to toggle settings

### Settings

Access settings via the **Config** button on the main window:

- **Verify class after joining (non-guild)** - When enabled, warns the raid leader and whispers the player if someone joins the raid on a different class than they signed up as. Useful for catching wrong-alt joins that can't be verified via the guild roster before inviting.

## How It Works

- **Sign-up filtering**: Entries marked as "Absence" are excluded. All other sign-ups (including "Tentative") are registered. Spec names are cleaned up (e.g., "Holy1" becomes "Holy").
- **Invite eligibility**: For imported raids, only the first 40 sign-ups by position are auto-invited. Players beyond position 40 get a whisper explaining that only the first 40 get auto-invites but there may be space if people don't show up. Unregistered players get a separate message letting them know to be patient. Custom raids always use open mode — anyone is eligible.
- **Class verification**: When a registered player sends `+`, their class is checked against the guild roster. If they're on the wrong character, they receive a whisper asking them to switch. For non-guild members, an optional post-join check can be enabled in settings.
- **Name matching**: Names containing `/` or `|` are split so any alt name triggers a match. All matching is case-insensitive.
- **Decline recovery**: If a player declines and types `+` again, they will be re-invited.
- **Raid full**: When the raid hits the max player limit, new `+` requests receive a whisper that the raid is full.
- **Auto party-to-raid conversion**: You can start invite mode while solo. The first `+` invite creates a party, and the addon automatically converts to a raid when they join.
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
