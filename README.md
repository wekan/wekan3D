# Kanban Office — House of Work

An editable 3D office game in Finnish and English for **Redot 26.2**. Four floors,
16 offices, 64 kanban boards with different topics, and initially 1,024 cards with
four lines each. Graphics, characters and furniture are generated from the
included source code. No separate asset packs or addons are required.

## Getting started

1. Extract the entire ZIP into its own directory.
2. Open [Redot](https://redotengine.org/) and select **Import**.
3. Select `redot_kanban_office/project.godot` and open the project.
4. Start the game with **F5** (Run Project), rather than F6.

From the command line: `redot --path /path/to/redot_kanban_office --editor`, or
start the game directly with `redot --path /path/to/redot_kanban_office`.

The project uses Compatibility rendering (OpenGL). The ZIP contains the complete
source project, without the Redot editor or an exported Windows/Linux game
executable. The standard Redot version is sufficient; .NET is not required.

## Controls

| Action | Keyboard and mouse | USB controller |
|---|---|---|
| Walk forward / backward | Up / down arrow or W / S | Left stick or D-pad up / down |
| Turn | Left / right arrow | Right stick or D-pad left / right |
| Strafe | A / D | Left stick |
| Look around | Hold right mouse button and move mouse; Page Up / Down | Right stick |
| Run | Shift | Press left stick |
| Open board / talk / place carried card | E / Enter | A (bottom button) |
| Put targeted card in pocket | P | X (left button) |
| Open pocket | I / Tab or top-bar pocket button | Y (top button) |
| Close view / leave carried card in pocket | Esc | B (right button) |
| Help | F1 or talk at reception | Talk at reception |
| Select view buttons | Tab, arrow keys, Enter | D-pad, A |
| Switch language | Suomi / English in the upper corner | Focus language button and press A |

The controller uses standard USB/SDL mappings recognized by Redot. Button letters
above follow the Xbox layout; corresponding PlayStation and other buttons are
identified by physical position. No physical USB controller was available in the
development environment; automated tests check the input mappings.

## Playing

You start on the first floor facing reception. Aino and Maya answer basic
questions through clickable dialogue choices. A central corridor runs through
the building. The stairs are at the far end, beyond reception. Each floor has
four numbered offices. Walk up or down the stairs to move between floors.

Each of an office's four walls has a board. A board has a name, Swimlane 1, four
lists running left to right, and initially four cards per list. Each card has
four lines of text. Topics include building a car, developing kanban software
and assembling a robot. Colleagues discuss topics in speech bubbles and move
real cards between their room's boards. They move aside for the player.

### Moving a card

- **Directly in the 3D world:** point at a nearby card, hold the left mouse button,
  drag it to the desired list on another board, and release. The mouse pointer
  determines the target; controllers use the center of the screen.
- **Between rooms:** click a card to carry it, or press P / X to pocket it. Open
  the pocket, select a card to carry, walk to another room, and click the target
  list or press A. The carried card stays safely in the pocket until placed.
- **Board close-up:** open a board with E / A. Select boards from the same room
  for side-by-side views. Drag cards between lists or boards, or into the pocket.
  Buttons also provide a way to move cards.
- **Pocket:** the top-bar pocket button or I / Y opens a paginated fullscreen
  view. Esc / B returns to the game.

After moves, a list may contain more than four cards. Wall boards show the first
four and the number of additional cards; all cards are accessible in the
scrollable close-up. Colleagues pause card moves while a close-up is open.

## Persistent storage and data structure

The game uses a local **SQLite database, `officegame.sqlite`**. On first launch,
it is created with default content: a building, four floors, workspaces, boards,
cards, people, furniture and bilingual text. Its preferred location is beside
the exported game executable; if that directory is not writable, the game uses
the operating system's Redot user-data directory.

The database also contains corresponding records for the supplied WeKan models,
card date fields and an index of all text. Search finds room names, floors, card
text, people's names, job titles, questions, answers and furniture names. A
building is an organization and each office room is a workspace. The precise SQL
mapping is documented in `docs/DATABASE_MAPPING.md`.

### Editing spaces and objects

The management view in the top bar lets you add, rename, delete and pocket
buildings, floors and workspaces. Pocketing a floor or workspace keeps its boards,
people and objects together; the pocket placement view can move the entire group
to another building or floor.

The object panel lets you add and manage furniture, trees, vehicles, assistive
devices, animals, flowers, roads and desktop items. Each has a name and pocket
and delete actions. Choose a color from the color wheel and set width, height
and depth separately. For people, edit the name, age group, team, job title,
expertise and question–answer pairs. Changes are saved in the active language.

The game saves automatically during play and on exit, then loads the save on
next launch. You always start in front of reception, but world edits, cards and
game statistics persist.

## Project structure

| Directory / file | Contents |
|---|---|
| `project.godot`, `scenes/main.tscn` | Redot project and initial scene |
| `scripts/main.gd` | Component integration, interaction and autosave |
| `scripts/core/` | Bilingual data, state graph, SQLite storage and search index |
| `scripts/world/` | Building, furniture, stairs and outdoor scenery |
| `scripts/actors/` | Player, controls and office characters |
| `scripts/kanban/` | Drawing and targeting 3D boards |
| `scripts/ui/` | Top bar, search, pocket, board views, editors and space management |
| `tests/` | Automated functional tests |
| `docs/` | Architecture, test report and English instructions |
| `ROADMAP.md` | Work packages, progress and completion status |

## License

Original source code and procedurally generated assets: MIT, see `LICENSE`.
The Redot engine is separate software with its own licenses. The project includes
no commercial assets, tracking or web-service dependency.
