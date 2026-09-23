# Kanban Office — ROADMAP

## Current goal
Complete editable bilingual Redot 3D office game. The specification has expanded during implementation: full-text search, portable SQLite database, editable multilingual text and Kanban structure, pocketable lists/swimlanes/boards, and a full card editor and SQL schema based on the supplied WeKan models.zip.

## Implemented foundation
- [x] Redot 26.2 project; self-contained procedural 3D graphics.
- [x] Four floors,16 furnished offices,64 wall boards,windows/glass partitions,outdoor scene,reception.
- [x] Connected physical stairs; actual player climbed and descended all floors in tests.
- [x] Arrow-only walking/turning,WASD,mouse look,USB controller mappings.
- [x] 64 different bilingual topics,1,024 initial cards,4 text lines/card.
- [x] Readable world board surfaces,accurate rotated hit picking,overflow cues.
- [x] 34 fictional adult colleagues incl2 female receptionists; discussion bubbles,actual card transfers,player avoidance.
- [x] HUD with start timestamp,elapsed time,visited rooms,pocket and language.
- [x] Fullscreen paginated pocket,two-board workspace,mouse drag/drop and controller focus.
- [x] Free-text search including room/floor,all board text,422 furniture/fixture entries and people.

## Expanded user requirements — completed feature work, final runtime review
- [x] SQLite `officegame.sqlite`: beside exported executable where writable;OS user-data fallback;create seeded defaults when missing.
- [x] Saved rooms,organizations,floors,teams,objects and person metadata;local-language edits preserve the other language.
- [x] Editable board/lane/list/card text;add lanes/lists/cards;rename people/furniture.
- [x] Atomic pocket transport for cards,lists,swimlanes and entire boards;safe occupied wall-slot exchange.
- [x] Full card editor on single click,using fields from supplied WeKan models.
- [x] Corresponding SQLite fields/tables for all model schemas in models.zip,with mapping documentation.
- [x] Search-result world markers and immediate search refresh after edits/moves.
- [ ] Final desktop screenshot inspection and exported-build packaging.
- [ ] Updated bilingual instructions,verification report and final ZIP delivery.

## Evidence so far
- Redot26.2.official executable used for actual parsing and runtime tests.
- World:1,468 capsule clearance samples;all floor transitions with shipping player passed.
- Board surfaces:376 hit/schema/overflow assertions passed before wall-slot expansion.
- UI:headless actual controller A/B events,paging,drag and button transfers passed before full-card expansion.
- Search:36 assertions including205-result pagination,bilingual matching and container locations passed.
- NPC:actual transfer,language update,avoidance and thin-desk collision checks passed.
- Latest integration: 1,838 core checks, 115 persistence/integration checks and 1,468 world checks passed with 0 failures.
- Spatial editor: dynamic buildings, floors, workspaces, people and custom props are represented by the saved spatial graph; rebuilding the world reapplies pocket, color and independent X/Y/Z size changes.

These are intermediate feature checks. Final readiness requires the combined expanded-version verification below; no claim of final completion yet.
