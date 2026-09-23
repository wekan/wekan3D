# Spatial editing expansion contract

Latest user requirements add/remove/rename floors, rooms, objects, people; change person's team; pocket and relocate furniture,people,buildings,trees,cars,benches,bicycles,mopeds,motorcycles,rollators. Existing Kanban/SQLite functionality remains.

## Ownership for this pass
Core: game_state.gd state APIs and graph. World: office_world.gd dynamic layout/stable targets. NPC: prop_factory.gd and NPC room/team handling. UI: game_ui.gd generic pocket and spatial entry points. Boards agent after views: spatial_editor.gd panel. Search: SQLite store + schema projection + search updates. Lead: main.gd/physical placement/overall integration.

## State
- organizations remains buildings; add deleted:false/in_pocket:false as optional backward-compatible flags.
- floors:Dictionary `{id,organization_id,name:{fi,en},number:int,deleted:bool}`. number 1-based contiguous for active floors.
- rooms remains workspace records; add floor_id, slot_index (0-based per floor), deleted:false. Initial4rooms/floor, initially4floors. Stable IDs independent of geometry positions. `workspace_id == id`.
- teams:Dictionary `{id,organization_id,name:{fi,en},room_id}`. Initially one team/workspace; people can change team (and corresponding room).
- entities names/profile and current positions stay authoritative; add template, deleted:false,in_pocket:false. Portable types include desk,chair,monitor,plant,sofa,bookshelf,tree,car,bench,bicycle,moped,motorcycle,rollator. All types have visible procedural geometry.
- pocket_items adds `{id,kind:'entity',entity_id,title:{fi,en}}` and `{id,kind:'building',organization_id,title:{fi,en}}` references. Never duplicate entity/building graphs into pocket payloads. Existing card/list/swimlane/board containers retain their APIs.
- Effective pocket containment includes cards/people/objects inside a pocketed building. Such records remain hierarchically owned by that building until placed; search labels the enclosing pocket building, and only one top-level item appears in pocket. Don't double-count card totals.

## APIs (core owns exact signatures; tell clients if changes)
`ensure_spatial_layout(org_id)` seeds4floors and4rooms each only for freshorg without layout.
`add_floor(org_id,name)->String`; `rename_floor(id,name)->bool`; `delete_floor(id)->bool`.
`add_room(floor_id,name)->String`; `rename_room(id,name)->bool`; `delete_room(id)->bool`.
`create_object(template,name,room_id,position:Vector3,org_id='')->String`.
`delete_entity(id)->bool`; `rename_entity(id,name)->bool` existing.
`move_person_to_team(person_id,team_id)->bool`; create/edit/deleteperson existing.
`pocket_entity(id)->String`; `pocket_building(org_id)->String`.
`place_spatial_item(item_id,room_id,position:Vector3,org_id='')->bool` (building snaps to campusplot at60m spacing; rejects overlap or finds freeplot; entity can be placed indoors or outdoors).
Signals `layout_changed` and `entities_changed`; root rebuilds geometry from persisted layout after changes. Root must synchronously seed new board slots/boards/entities before a new layout commit (same pattern as organizations_changed). SQLite failure rollback emits layout_changed to remove phantom geometry.
Delete floor/room retains its boards and portable contents by putting them in pocket before soft-deleting the structural container. UI explains this before confirmation. Last active floor may be deleted only if building retains usable ground entrance or reject withclearerror; core/world agree.

## Dynamic world geometry
World adds `configure_layout(org_id:String, floors:Array, rooms:Array)` before build(). It must generate activefloor count and >=arbitrary room slots per floor, extending corridor/building footprint for morethan4rooms. Initial rendering staysclose existing4floor/16room style. Export room/board specs retainstate IDs; no lead prefix remapping when configured. Geometry specs use local building coords; lead translatesglobaloffset. Missing room slots stayopen/lounge space, notsolidunreachable rooms. Floor deletion renumbers and rebuildsstairs.
Default semantic entity IDs must stable byorganization/floor/workspace/semanticitem (not traversalorder thatchanges when roomsadded). Runtime additions/deletions/movedpositions applyaftertemplatebuild.
World provides `apply_saved_entities(state)` or lead property factory updates/hides targets. Existing objecttarget metadata entity_id binds correctrecord; organization_id/floor_id/room_id metadata on architecture letsclickopeneditor.

## UI
SpatialEditor VBoxContainer `setup(context:Dictionary)` where context={organization_id,floor_id,room_id,entity_id,kind}; signals changed/closed; contextmenus allowadd/delete/rename andpocket. Root connects freshstatecommands. Sidebar hierarchy building/floor/room andobjects lists, objecttypepicker; explicitDeleteconfirmation for structuralcascades. Personteam picker integrates existing PersonEditor.
GameUI public `open_spatial(context)`; buttonfromlogo Organizations and physicalgeometry; inventory entity/buildingtiles have Carry button viaexistingcontainer_placement_requested.
Lead places carriedspatialitem onpointedfloor/world surface or atplayerforwardsafe point whenE/A, usingcurrentroom/org. ESC leavesitempocketed. Clickingbuilding/floorwall opens spatialeditor. Objectinteraction opens rename/editor +Pocket/Delete.

## Verification
Initial baseline counts unchanged. Test add/deletefloor,room expansion beyond4,reachable newroom, saved/reloadedpositions, customprops alltypes,deletedobjectcollidersremoved, personteam relocation, pocketperson andwholebuilding/hierarchycardcount, placing buildingfreeplot withoutcollision, rollback geometry and SQLite refs.
