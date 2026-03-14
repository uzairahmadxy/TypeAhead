# TypeAhead

A lightweight macOS menu bar app that expands text snippets as you type — system-wide, in any app.

Type a trigger like `//email` and TypeAhead instantly replaces it with your full expansion.

![TypeAhead demo](docs/demo.gif)

---

## Features

- **System-wide expansion** — works in any text field across all apps
- **Inline suggestion popup** — appears near your cursor as you type; navigate with ↑ ↓, confirm with Tab or Return, dismiss with Escape
- **Snippet management** — add, edit, delete, reorder, search, and sort snippets in one window
- **Sortable columns** — click Trigger, Name, or Expansion header to sort; click again to toggle direction
- **Search bar** — filter snippets instantly by trigger, name, or expansion text
- **Alphabetical / recency toggle** — switch the list and popup order between A–Z and most recently added
- **Exact trigger** — mark individual snippets to only appear when their trigger is typed explicitly, hiding them from the show-all list
- **Import / Export** — back up or share your snippet library as JSON
- **Configurable trigger prefix** — default `//`, change to anything you like
- **Show all on prefix** — typing the prefix alone lists every eligible snippet
- **Search expansions** — optionally match the popup against expansion text, not just trigger names
- **Backspace undo** — one backspace immediately after an expansion reverts it
- **Launch at login** — optional, toggled from the menu bar
- **Watchdog** — automatically restarts the event tap if it ever dies

---

## Requirements

- macOS 13 Ventura or later
- Two permissions (prompted on first launch):
  - **Accessibility** — System Settings → Privacy & Security → Accessibility
  - **Input Monitoring** — System Settings → Privacy & Security → Input Monitoring

Both are required. The app will guide you through granting them on first run.

---

## Installation

1. Download `TypeAhead.app` from the [Releases](../../releases) page
2. Move it to `/Applications`
3. Launch it — a **TA** icon appears in your menu bar
4. Grant Accessibility and Input Monitoring permissions when prompted
5. Start typing

---

## Usage

### Adding snippets

Open **Manage Snippets** from the menu bar icon. Fill in:

| Field | Description |
|---|---|
| Trigger | The shorthand you type, e.g. `//email` |
| Name | Optional label shown in the popup (falls back to trigger if empty) |
| Expansion | The full text to insert |

Press the **+** icon or hit Return to add.

### Using a snippet

Type the trigger in any text field. A popup appears near your cursor — use **↑ ↓** to navigate, **Tab** or **Return** to accept, **Escape** to dismiss.

### Sorting & searching

- Use the **search bar** at the top to filter by trigger, name, or expansion
- Click any column header (**Trigger**, **Name**, **Expansion**) to sort; click again to reverse
- Use the **ABC / clock toggle** in the search bar to switch the base order between A–Z and most recently added — this applies to both the snippet list and the suggestion popup
- Drag reorder is available when no search or column sort is active

### Exact trigger

Each snippet row has an **eye** icon. Click it to toggle **Exact trigger** mode:

- **Eye (default)** — snippet appears in the show-all list when you type the prefix alone
- **Eye-slash** — snippet is hidden from the show-all list; it only appears once you start typing its trigger explicitly

Useful for sensitive or rarely-used snippets you don't want cluttering the popup.

### Settings (bottom of Manage Snippets)

| Setting | Description |
|---|---|
| Trigger prefix | String that starts every trigger (default `//`) |
| Show all on prefix | Typing the prefix alone shows all eligible snippets |
| Search expansions | Popup also matches against expansion text |

---

## Snippet file location

Snippets are saved automatically to:

```
~/Library/Application Support/TypeAhead/snippets.json
```

You can back this file up directly or use the Export button in the app.

---

## Permissions — why they're needed

**Accessibility** allows TypeAhead to read the cursor position so the popup appears in the right place, and to inject the expansion text.

**Input Monitoring** allows TypeAhead to observe keypresses globally (in other apps) via `CGEventTap`. Without it the app cannot detect what you're typing.

Neither permission is used to log, transmit, or store any keystrokes beyond the current word buffer.
