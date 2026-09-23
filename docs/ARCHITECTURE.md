# Integration contract
Target: Redot 26.2 (Godot 4.x GDScript APIs), Compatibility renderer. No external assets/dependencies. Programmatic scenes, SI metres, +Y up, default camera looks -Z.

## Ownership
- Core/data agent: scripts/core/game_state.gd and scripts/core/catalog.gd; autoload GameState.
- World agent: scripts/world/office_world.gd and world helper files.
- Board agent: scripts/kanban/board_3d.gd, scripts/kanban/board_canvas.gd.
- UI agent: scripts/ui/*.
- NPC agent: scripts/actors/office_npc.gd.
- Lead: project.godot, scenes/main.tscn, scripts/main.gd, scripts/actors/player.gd, integration tests, documentation, packaging.
Do not edit other owners' files. Avoid class_name: use preload scripts and duck typing. Avoid type inference (:=) on dynamic/Variant expressions; plain = is safer.

## GameState (autoload Node)
signal language_changed; signal cards_changed; signal stats_changed
var language: String = "fi"
var boards: Dictionary # id -> {id,room_id,topic,title:{fi,en},lists:[{fi,en} x4],cards:[[card_id,..] x4]}
var cards: Dictionary # id -> {id,topic,lines:{fi:[4 strings],en:[4 strings]}}
var pocket: Array # card ids; each card has ONE location
var visited_rooms: Dictionary; var started_at: String; var elapsed_seconds: float
func tr_key(key: String) -> String
func localize(value) -> String # translated dictionary or String
func set_language(value: String)
func ensure_board(board_id: String,room_id: String,topic_index: int) -> void
func move_card(card_id: String,target_board_id: String,target_list: int,target_index: int = -1) -> bool
func pocket_card(card_id: String) -> bool
func get_card_location(card_id: String) -> Dictionary # {board_id,list,index} OR {pocket:true,index}; empty if absent
func visit_room(room_id: String)
func topic_text(topic_index: int) -> String
func get_card_lines(card_id: String) -> Array
func save_game() -> bool; func load_game() -> bool; func reset_game()
Save user://office_save.json; preserve original start timestamp, active elapsed time, visited rooms, language and all card locations. initialize deterministic boards from world before load. Catalog has at least 64 distinct bilingual board titles/topics, 16 meaningful topic-specific cards per board, four text lines/card. UI keys documented in core/ui_keys.md by core owner.

## World (Node3D script)
func build() -> void # call after add_child, once
var rooms: Array # {id:String,floor:int (0..3),center:Vector3, bounds:AABB, topic:int, npc_positions:[Vector3,Vector3], waypoints:[Vector3,...]}
var board_specs: Array # {id,room_id,topic:int,position:Vector3,yaw:float}
var reception_positions: Array # two Vector3
var spawn_position = Vector3(0,0.12,11)
Four floors y=0,4,8,12. Main building x=-15..15,z=-12..12, corridor x=-3..3. Four rooms/floor: west/east x centers -9/+9 and z centers -6.5/+6.5. Stair extension at rear z=-12..-24; freely walkable connected switchbacks. Doors in hall-side walls, walls/windows and exterior entrance traversable; room AABBs exclude hallway. No boards spawned by world; create specs for 4 boards per room. Board surface front is local +Z; center y at floor+2.05; board physical dimensions width4.6 height2.65; keep all boards clear of furniture and doorways. Collision layer1 world, layer2 board target, layer4 NPC target. World geometry layer1 only. People are not blocking rigid obstacles.

## Board3D (Node3D script)
func setup(spec: Dictionary) -> void # after add_child
var board_id: String; var room_id: String
func hit_info(world_position:Vector3) -> Dictionary # {board_id,list:int,card_id:String (empty for gap),index:int}; transform hit position to grid
func update_board() -> void
func carry_anchor() -> Vector3 # front position for NPC optional
Create visual physical board and StaticBody3D layer2, with metadata "board_node" on collider self or parent. Surface local +Z, plane4.6 x2.65. Board canvases draw title, Swimlane1, four list headers then16 cards each4 lines. Connect language and cards changed. Rendered world surface legible nearby. use CanvasItem custom drawing + SubViewport UPDATE_ONCE for efficiency. make collision body metadata board_node pointing board Node3D.

## OfficeNPC (Node3D script)
func setup(spec:Dictionary, player:Node3D) -> void # after add_child
spec: {name:String,female:bool,receptionist:bool,position:Vector3,room_id:String,topic:int,waypoints:Array,board_ids:Array}
var display_name:String; var receptionist:bool; var room_id:String
func interact() -> Dictionary # {name,topic,room_id,receptionist}
Target collider layer4 metadata "npc_node" = this. Stylized clothed people; two female receptionists. Workers wander within room, visibly carry/move actual cards between their four boards and step away from player. Speech bubbles Label3D billboard, localized discussions about topic. Actual moves via GameState only, wait if player is near source/target boards to avoid snatching.

## UI (CanvasLayer script)
signal modal_changed(is_open:bool)
signal placement_requested(card_id:String)
signal cancel_carry_requested
func build() -> void # after add_child
func set_hint(text:String) -> void
func set_carry(card_id:String) -> void
func show_toast(text:String) -> void
func open_pocket() -> void
func open_board(board_id:String) -> void
func open_dialogue(npc_info:Dictionary) -> void
func close_modal() -> void
func is_modal_open() -> bool
HUD top start, elapsed,visited rooms,pocket button, Finnish/English toggle. Pocket full-screen paged cards (12/page), Esc returns, buttons to carry card into world. Board full-screen workstation UI lets choose TWO board panels from current room, side-by-side, drag/drop real cards across boards/lists and to pocket; also button-based transfer accessible via focus for controller. All cards four visible text lines. board panel updates on changes. set_carry shows held card, info. Bottom persistent bilingual control hints. UI creates its own theme, responsive desktop. UI calls GameState directly for transfers, emits placement_requested to lead for world carrying. close modal on ui_cancel, handle inventory input if desired but lead also exposes I/Tab.

## Player (lead)
CharacterBody3D, camera:Camera3D child at1.65m. ArrowUp/Down walk; ArrowLeft/Right turn (arrow-only navigation), WASD strafe, mouse look while RMB held, controller left stick move right stick look; controller D-pad navigate turns/moves. Default visible cursor; LMB world ray uses actual pointer, center ray when controller. E/A interact; I/Tab/Y pocket; P/X pocket targeted card; Esc/B modal/carry. Can drag a 3D card holding LMB and release over another board/list or pocket HUD; can click to pick then carry across rooms and click target board to place. Shift run. Root handles input interactions and UI.
