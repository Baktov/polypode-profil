# Polypode Profiles (Polypode Profil)

*Version française : [README.md](README.md)*

**"Profiles"** window of [Polypode](https://github.com/Baktov/polypode), as a separate addon: a
library of **export strings** (WoW **Edit Mode** layout, **talents**, addon profiles
(**EllesmereUI**, **ElvUI**, **Baganator**, **MySlots**, **Simple Addon Manager**...), **action
bars**) kept once and for all and available on all your characters, to quickly set up a new
character or a new window.

When disabled, Polypode works normally, with no "Profiles" button or `/poly profil` command.

> **Languages**: French, English, German, Spanish, Italian and Brazilian Portuguese, following the
> language chosen in Polypode (option "Langue / Language"). The translations were made with the help
> of Claude, Anthropic's AI: feedback from native speakers is very welcome
> ([GitHub issue](https://github.com/Baktov/polypode-profil/issues)).

---

## Installation

1. Install **Polypode** first (required dependency).
2. Put the `Polypode_Profil` folder in `World of Warcraft/_retail_/Interface/AddOns/`
   (and, for **WoW Forever**, in `World of Warcraft/_forever_/Interface/AddOns/`).
3. Enable "Polypode Profiles" in the AddOns list.

---

## Usage

The **Profiles** button (title bar of the Polypode window) or `/poly profil` opens the window
(**double-click** its title bar: back to the default size).

- **On the left**, the profiles filed **by season, then under their character**. A profile's
  season is the one of its **last save** ("Midnight, season 2"; "Unknown season" for saves older
  than 1.9.0 and on WoW Forever); the current season comes first, then the others from newest to
  oldest. The same character shows in every season where it has profiles. It is shown as in
  Polypode's "Available characters": name in class color, class, level, "(you)", logged-in
  first, logged-out faded, and the same tooltip (logged in or not, teams). Your current
  character always shows in the current season, even with no profile.
  - Season header: left-click = collapse / expand the season (state kept).
  - Character header: left-click = collapse / expand its profiles of that season (state kept);
    right-click = new profile for this character (saved in the current season).
  - **Collapse all** button (right of the "Characters" title): collapses every season to only
    see their names; it becomes **Expand all** when everything is collapsed.
  - Profile (type then name, e.g. "Talents · Arcane raid"): left-click = open in the editor;
    right-click = duplicate or delete; on hover: type, character, date, **season and game
    version** of the save (for example "Midnight, season 2 (12.1.0)"; "unknown" for saves older
    than 1.9.0) and size.
  - **Transmogrification** profile: a small icon before its name **opens the dressing room** on the
    outfit (like the string pasted in the chat; out of combat).
  - **Title** profile: a small icon before its name makes the current character **wear this
    title** (if known; "No title" removes the title).
  - **Macro** profile: the icon before its name is **the macro's own**; a click **adds it to the
    macros** of the current character (general or character-specific, as when captured), out of
    combat. If a macro with the same name already exists, a confirmation is asked then its icon and
    text are replaced. The profile tooltip shows the icon, the type and the text.
  - **Action bars** profile: a small icon **applies** them to the current character, after
    confirmation (warning if the profile comes from another class); see "Action bars" below.
  - **Equipment set** profile: a small icon before its name **adds the set to the equipment
    sets** of the current character (see below); the profile tooltip gives its specialization and
    number of pieces.
  - **Addon list** profile: a small icon **applies** it to the current character (after
    confirmation), then offers to **reload the interface** ("Reload" button or Enter key; on WoW
    Forever, type /reload).
  - **Simple Addon Manager** profile: a small icon **imports** it into Simple Addon Manager (after
    confirmation), then opens its own "load the profile and reload" box.
  - **WoW options**, **Key bindings** and **Chat windows** profiles: a small icon before their name
    **applies** them to the current character, after confirmation (they replace the current
    setup); a report is shown.
- **On the right**, the editor. Header: on the left the open profile (or "New profile"), on the
  right its **character**, which cannot be changed: the one the profile was created under, or,
  for a new profile, the current character (the header's one after a right-click "New profile
  for this character"). Below: name, type (drop-down list) and the string itself, in a
  scrolling box.
  **Changing the type resets the editor**: name and string are cleared for a new profile of that
  type (same character); the profile that was open is not changed (confirmation asked if it had
  unsaved changes).

### Deleting all the profiles of a season

The **Delete a season** button (right of "Delete", at the bottom of the editor) lists the seasons
during which your profiles were saved (with their count, "Unknown season" for saves older than
1.9.0 and WoW Forever saves). Picking one deletes, after confirmation, every profile of that season, on all your clients.

### Saving a string

1. In the addon (or Edit Mode, or talents), use its **Export** button and copy the string
   (Ctrl+C).
2. In "Profiles": **New**, paste the string (Ctrl+V) into the text box, give a name and choose the
   type.
3. **Save**.

**Capture** (types "Edit Mode", "Talents", "Transmogrification", "Title", "Macro", "Equipment
set", "Action bars", "WoW options", "Key bindings", "Chat windows", "Addon list" and "Simple Addon
Manager") reads the string directly in game, without going through the clipboard:

- Edit Mode: a menu lists your layouts (the active layout is marked);
- Talents: the active talent loadout. The talent window (N) must have been opened at least once in
  the session (the addon does not load it itself, so as not to risk blocking talent changes
  later).
- Transmogrification: a menu offers the current character's **current appearance** and each of
  your **custom sets**. The string is Blizzard's (`/customset v1 ...`, like "Copy to clipboard" in
  the dressing room): to use it again, paste it in the **chat** and confirm; the dressing room opens
  with the outfit (to save or apply afterwards at the transmogrifier).
- Equipment set: a menu lists the sets of the current character's equipment manager (with their
  specialization). The profile keeps, for each slot, the exact piece (enchantment, gems, upgrades),
  the ignored slots and the specialization. Blizzard has no export string for sets: the text is
  specific to Polypode Profiles (not meant to be pasted in the chat).
- WoW options: a menu offers each category of the Options panel (Graphics, Audio, Interface,
  Combat...) or all of them. Only settings that are game variables (CVars) are kept; computed
  settings and addon settings are left out. Graphics and audio are specific to each PC: that is
  where the profile helps most.
- Key bindings: every binding of the active binding set (account or character). Applied, they
  **replace** the current bindings (keys bound otherwise are freed); commands of a missing addon
  are counted as "unknown".
- Chat windows: open windows (name, font, color, transparency, lock, docking, position if
  undocked), message types and channels of each, message type colors and chat settings (style,
  whispers, timestamps...). Applied, the profile closes the extra windows and opens the missing
  ones; the main window stays placed by Edit Mode. A **/reload** is advised afterwards.
- Addon list: each installed addon, enabled (`+`) or disabled (`-`) for the current character.
  Applied, it enables / disables the addons of the list for the current character; those not in
  the list do not change, those missing from this PC are counted, and Polypode and Polypode
  Profiles are never disabled. Takes effect on reload.
- Simple Addon Manager: a menu lists its profiles; each one is captured by Simple Addon Manager's
  own export (the string of its "Export" button, dependent profiles included). "All profiles" saves
  them all at once, one Polypode profile each. Simple Addon Manager must be loaded.
- Title: the title worn by the current character, as a Blizzard `/settitle Name` string (pasted in
  the chat, it changes the title; without a name, it removes it). Beware, Blizzard's command takes
  the first known title that *starts* with this name; the list icon looks for the exact name.
- Action bars: the 180 slots of bars 1 to 15 of the current character (form / stance bars
  included) and the text of the macros placed on them; filed under the current character, named
  after the specialization.
- Macro: menu of your macros (general, then the current character's, with their icon); the
  profile keeps the macro's name, icon, type and text: `Polypode macro v1`, `nom=`, `icone=`,
  `type=generale|personnage`, `---`, then the text as is ("|" and "%" written `%7C` and `%25`).
  A character-specific macro is filed under the current character.

Each capture opens a **new profile** (the open profile is never overwritten), named after the
layout, the talent loadout or the custom set; the current appearance is named "Current appearance
(date time)". You can thus keep several outfits, layouts or loadouts side by side. Talents and
current appearance are filed under the current character. All that is left is to **Save** (the
name can be changed first).

### Reusing a string

Open the profile, **Select all**, Ctrl+C, then Ctrl+V in the addon's import window (Edit Mode:
"Import" in the layouts menu; talents: "Import" in the loadouts menu). A WoW addon can neither read
nor write the clipboard: copying always goes through Ctrl+C / Ctrl+V.

An unsaved change is marked "(not saved)" in the editor header; opening another profile or creating
a new one then asks for confirmation.

---

### Re-creating an equipment set

The icon before a set profile creates it on the **current character**, under the **profile's
name**. WoW only saves a set from what the character **wears**; the addon:

1. checks (out of combat) that each piece is in the bags or already equipped, that no set already
   has this name and that the maximum number of sets is not reached; otherwise nothing moves;
2. equips the pieces one by one (the exact piece if it exists, otherwise the same item, for example
   upgraded since);
3. creates the set (same ignored slots, same icon) and assigns it the specialization (if it is the
   same class);
4. **puts back the outfit worn before**.

Limits: pieces in the bank are not taken; slots the set left **empty** are ignored by the re-created
set; a swap between a two-handed weapon and weapon + off-hand can prevent putting back exactly the
outfit worn before (a message says so).

### Action bars

The **Action bars** type applies the bars without the MySlot addon, but takes back less (no key
bindings, no pet bar, no click bindings, no Cooldown Manager): the **MySlots** type stays there to
keep MySlot strings as they are. The text is specific to Polypode Profiles (`Polypode barres v1`,
one line per slot: `12=spell:133:Fireball`, `13=macro:My macro`, `14=item:6948:...`, then one
`macro=` line per macro placed). Handled: spells (base spell; the talent upgrade follows), items,
macros, spell flyouts (portals...), mounts (including the random favorite mount), pets, equipment
sets and transmog outfits.

Applied (list icon, out of combat), the profile **puts each action back** on its slot and **clears
the others**. Macros are found by their name, otherwise created from the profile (if there is room
left). An unlearned spell, a missing item or a mount not owned leaves the slot empty; the report
counts them and names a few. Not taken back: pet bar, click casting, cooldown manager.

## Sharing between characters and clients

Profiles are kept in the **account** file (`PolypodeProfilDB`): shared by all characters. They are
also **exchanged between your logged-in clients** (multibox), like Polypode teams: at each login,
each client announces the version of its profiles and fetches those that are more recent
elsewhere; a profile saved or deleted goes out at once to the logged-in clients. The most recent
version wins; a deletion is passed on too. A profile open in the editor and changed elsewhere is
reloaded, unless it is being edited.

Long strings (full ElvUI or EllesmereUI profiles) travel in many messages: their arrival on the
other clients can take a few seconds.

This addon has no options.

---

## Ideas for later

- Direct import (without Ctrl+V) into the addons that expose an API for it, and into Edit Mode.
- Search in the list, if it gets long.

---

## Languages

Polypode Profiles follows the language chosen in Polypode ("Langue / Language" option,
`/poly language`), by default the game's: French, English, German, Spanish, Italian or Brazilian
Portuguese (English for any other language). Choosing the language requires Polypode 2.9; with an
older Polypode, the module stays in French. The `/poly profil` command keeps its name. Export
strings specific to Polypode Profiles keep their French field names (`nom=`, `icone=`...), so that
they can be read back whatever the language.

---

## Versions

The full version history is in the [French README](README.md#version).
