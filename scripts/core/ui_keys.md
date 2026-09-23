# Core localization API

`GameState.tr_key(key)` returns Finnish/English. Missing keys return the key.
`GameState.localize({"fi": ..., "en": ...})` handles translated titles.
`GameState.get_card_lines(card_id)` returns exactly four localized text lines.
`GameState.topic_text(index)` returns a localized board title; indexes wrap over 64 topics.
Signals have **no arguments**: `language_changed`, `cards_changed`, `stats_changed`.

Available UI keys (format placeholders shown in English):

| Key | English |
| --- | --- |
| game_title | Kanban Office |
| started | Started |
| elapsed | Elapsed |
| rooms_visited | Rooms visited |
| pocket | Pocket |
| pocket_count | Pocket: %d |
| pocket_title | Cards in your pocket |
| pocket_empty | Your pocket is empty. |
| page | Page %d / %d |
| previous | Previous |
| next | Next |
| close | Close |
| back | Back |
| take | Take |
| take_to_pocket | Put in pocket |
| place | Place card |
| carry | Carry card |
| carrying | Carrying: %s |
| cancel_carry | Cancel carrying |
| board | Board |
| board_workspace | Kanban workspace |
| board_left | Left board |
| board_right | Right board |
| choose_board | Choose board |
| choose_list | Choose list |
| move | Move card |
| swimlane | Swimlane 1 |
| list_0 | Ideas |
| list_1 | Ready |
| list_2 | In progress |
| list_3 | Done |
| select_card | Select a card |
| drag_hint | Drag cards between boards or into your pocket. |
| board_hint | E / A: open board • Click a card to carry it |
| npc_hint | E / A: talk |
| place_hint | Click a board or press E / A to place the card |
| controls | Arrows: walk/turn • WASD: move • RMB: look • E/A: interact • I/Y: pocket • P/X: pocket card • Esc/B: back |
| card_pocketed | Card put in pocket. |
| card_placed | Card placed on board. |
| card_moved | Card moved. |
| move_failed | The card could not be moved. |
| save | Save |
| load | Load |
| new_game | New visit |
| saved | Game saved. |
| loaded | Game loaded. |
| save_failed | Could not save the game. |
| load_failed | No compatible saved game was found. |
| reception | Reception |
| receptionist | Receptionist |
| hello | Hello! How can I help you? |
| ask_directions | Where are the offices? |
| answer_directions | Offices are on both sides of the corridor. The stairs are at the back. |
| ask_kanban | How do I move cards? |
| answer_kanban | Open a board to drag cards. Your pocket lets you carry cards between rooms. |
| ask_controls | How do I move around? |
| answer_controls | Use the arrow keys or your controller. Hold the right mouse button to look around. |
| ask_topics | What do the teams work on? |
| answer_topics | Our teams build software, vehicles, robots and many other things. Every wall has a different topic. |
| ask_accessibility | Can I use a controller? |
| answer_accessibility | Yes. Use both sticks to walk and look. A opens boards, Y opens your pocket and B goes back. |
| goodbye | Thanks, goodbye! |
| thanks | You're welcome! Enjoy your visit. |
| floor | Floor %d |
| room | Room %s |
| welcome | Welcome to Kanban Office |
| click_pocket | Click here to open your pocket |
| selected | Selected |
| transfer | Transfer |
| dialogue | Conversation |
| source | Source |
| destination | Destination |
| language | Language |

For any additional keys, ask the core owner or keep local `{fi,en}` dictionaries.

## Runtime data and editing API

Signals have no arguments: `language_changed`, `cards_changed`, `stats_changed`,
`entities_changed`, `organizations_changed`. The first three UI signals remain
backwards compatible. Call `GameState` methods rather than mutating arrays.

- Initial content: 64 distinct topics, 16 cards per board, four initial lists and
  four initial cards/list. Every card retains exactly four localized preview lines.
- `boards[id].swimlanes`: `[{id,title:{fi,en},lists:[{fi,en}],cards:[[card_id]]}]`.
  List counts are independent per lane. `boards[id].lists` and `.cards` are live
  aliases to the first lane for older callers, repaired after database loading.
- `board_slots[slot_id]`: `{id,room_id,position:{x,y,z},yaw,board_id}`. Slots are
  physical walls. A board's `slot_id` and `room_id` are empty while pocketed.
- `rooms[id]`: `{id,workspace_id:id,organization_id,number,floor,name:{fi,en},position}`.
  Room/workspace are the same office. Floors are stored as 1–4.
- `organizations[id]`: `{id,name:{fi,en},building_index,position:{x,y,z}}`.
  One organization corresponds to one four-floor building.
- `entities[id]`: `{id,kind,name:{fi,en},description:{fi,en},room_id,organization_id,
  floor,position:{x,y,z},...}`. Kinds are furniture, fixture or person.

### Cards and localized editing

`move_card(card_id,board_id,list_index,target_index=-1,target_lane=0)` returns
bool. Index `-1` appends; other indices insert before the original index. Moving
within the same list correctly adjusts the removal offset. Invalid moves are
atomic. `pocket_card(card_id)` moves a card out of any nested container into the
loose pocket. `get_card_location` returns:

- Wall board: `{board_id,lane,list,index}`.
- Loose pocket: `{pocket:true,index}`.
- Pocket list/lane: `{pocket:true,item_id,kind,lane:0,list,index}`.
- Pocket board: `{pocket:true,item_id,kind:'board',board_id,lane,list,index}`.

Create/edit APIs operate on the currently selected language; new content starts
with the entered text in both languages, after which translations are independent:

- `add_swimlane(board_id,title)->String` lane ID.
- `add_list(board_id,lane_index,title)->int` list index (`-1` on failure).
- `add_card(board_id,lane_index,list_index,lines:Array)->String` card ID.
- `edit_board_title(board_id,text)->bool`.
- `edit_lane_title(board_id,lane_index,text)->bool`; alias `edit_swimlane_title`.
- `edit_list_title(board_id,lane_index,list_index,text)->bool`.
- `edit_card_lines(card_id,lines:Array)->bool` (exactly four nonempty strings).
- `rename_entity(entity_id,text)->bool`, `rename_room(room_id,text)->bool`.

`get_card_details(card_id,locale='')->Dictionary` composes all supplied source
card fields and related records in the chosen language. It includes actual
readonly IDs/location references. `edit_card_details(card_id,patch,locale='')`
accepts a changed-fields patch. Typed fields are shared; textual fields and
related texts use independent Finnish/English overlays. Schema validation runs
before mutation. Related new records receive IDs, timestamps and owner IDs.
Unknown payload fields survive saves. The first four preview lines reflect the
edited title and first three description lines; the complete description remains
in the full editor and database. `last_error` explains failure.

### Pocket containers

`pocket` remains an array of loose card IDs. `pocket_items` contains:

- `{id,kind:'list',title:{fi,en},cards:[ids]}`.
- `{id,kind:'swimlane',lane_id,title:{fi,en},lists:[{fi,en}],cards:[[ids]]}`.
- `{id,kind:'board',board_id,title:{fi,en}}`, referencing the existing board graph.

`pocket_card_count()` counts all cards including nested containers.
`get_pocket_item(id)` returns the container. APIs:

- `pocket_list(board_id,lane_index,list_index)->String` item ID.
- `pocket_swimlane(board_id,lane_index)->String` item ID.
- `pocket_board(board_id)->String` item ID.
- `place_pocket_item(item_id,board_id,target_lane=0)->bool`.
- `place_pocket_board(item_id,target_slot_id)->bool`.

Removing a last list/lane leaves an empty replacement so the source remains
usable. Placing a board on an occupied wall safely pockets the previous board.
No nested card is copied. `validate_state()` returns errors (empty means valid).

### SQLite lifecycle

SQLite is the only save format: `officegame.sqlite`. `database_path` exposes its
resolved location; `database_exists()` detects existing state. The bundled store
selects the exported executable directory when writable, otherwise the OS user
data directory. Editor runs use user data; `OFFICEGAME_DATA_DIR` isolates tests.

Initialization order: register organization, rooms/workspaces, entities, slots
and boards; then call `load_game()` or `save_game()` on the complete defaults if
the database did not exist. Finally set `autosave_enabled=true`. Every content
mutation saves immediately in a SQL transaction and rolls back memory on failure.
Invalid existing databases set `storage_read_blocked`, preventing replacement.
`last_storage_error` explains persistence failures. Timer/visits are captured by
explicit/periodic saves while elapsed time only counts active process time.

`register_organization(spec)` records initial data.
`create_organization(name)->String` adds the next building at x=index*60 and emits
`organizations_changed` synchronously before the save: the root listener must
construct/register its full rooms, entities, slots and boards before returning.
Loaded additional organizations/rooms are accepted and remain in the database.

### People and editable conversations

`entity.profile` contains `{title:{fi,en},team_role:{fi,en},expertise:{fi,en},
qa:[{id,question:{fi,en},answer:{fi,en}}]}`. Names stay in `entity.name`.

- `create_person(room_id,name,female=false)->String` creates a fictional worker
  in an existing workspace using the bilingual topic profile generator.
- `get_person_profile(entity_id,locale='')->Dictionary` returns composed plain
  strings and QA rows, plus readonly ID/workspace/organization/deleted status.
- `edit_person_profile(entity_id,patch,locale='')->bool` accepts name, title,
  team_role, expertise and QA rows. Stable QA IDs preserve the other language
  through edits/reordering; removing a row removes that pair in both languages.
  New pairs initially have empty text in the other language. Existing untranslated
  pairs can remain blank while other fields are edited; half-filled pairs and new
  empty pairs are rejected.
- `delete_person(entity_id)->bool` sets `deleted=true` and `deletedAt`, retaining
  identity/history. UI and NPC synchronization must hide deleted people.

Person mutations emit `entities_changed` after a successful immediate transaction.
