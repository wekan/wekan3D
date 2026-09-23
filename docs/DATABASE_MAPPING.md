# SQLite data model and models.zip mapping

`officegame.sqlite` is a real SQLite database. The game saves its complete state
and corresponding WeKan model fields in the same atomic transaction. Cards,
boards, lists and swimlanes share SQL tables with the game's own records; model
fields are not left in empty parallel tables.

## Source data and coverage

All 65 JavaScript files in the user-supplied `models.zip` were analyzed without
executing their JavaScript. They define 49 Mongo/FilesCollection collections.
The `workspaces` game extension adds one SQL table. The schema contains 873 field
definitions, including 626 root-level SQL columns; nested paths remain field
descriptions within JSON structures. These counts include clearly marked game
extensions.

- `data/wekan_schema.json`: complete machine-readable field inventory, original
  names, types, nested paths, optional/default/allowedValues/min/max/regEx/blackbox
  metadata, source lines and SHA-256 hashes for all 65 files.
- `data/wekan_schema.sql`: standalone CREATE TABLE and index statements for the
  source model. There is no need to run this file manually.
- `scripts/core/wekan_schema.gd`: idempotent `ensure_tables(db)` and
  `sync_snapshot(db,snapshot)`, which writes actual game state. The storage layer
  owns the transaction and restores the previous intact save on failure.
- `tools/generate_schema.py`: dependency-free Python generator. Its input is the
  models directory extracted from the original archive; third-party source code
  does not need to be included in the game.

## Type conversions

| JavaScript / SimpleSchema | SQLite | Storage |
|---|---|---|
| String | TEXT | Original Unicode text |
| Boolean | INTEGER | 0 or 1 |
| Date | TEXT | Date/time as ISO 8601 text |
| Number | REAL | SQLite numeric field |
| Array | TEXT | JSON array; element definitions in the schema description |
| Object / nested SimpleSchema | TEXT | JSON object; all dotted paths in the schema description |
| Match.OneOf | TEXT / JSON of the containing structure | Original type expression preserved; values are not forced into an incorrect type |

Original camelCase field names are preserved (`boardId`, `swimlaneId`, `listId`,
`dueAt`, `spentTime`, etc.). `_id` is the unique model identifier; existing game
`id` fields and ownership keys remain. Upstream `optional`, `autoValue` and
server-side validation are not guessed into SQL NOT NULL constraints. Dynamic
defaults and imported module symbols are neither executed nor invented: the
schema description marks them as dynamic/symbolic. Existing game reference and
uniqueness constraints remain in force.

## Organization, building and workspace

| In the game | Actual SQL representation | Relationship |
|---|---|---|
| Organization | `organizations` game record + original `org` model | One organization owns the office building; its name is stored in `org.orgDisplayName` |
| Office room / workspace | `rooms` game record + `workspaces` | One `workspaces` row per room; `_id` is the room's workspace_id |
| Workspace building | `workspaces.orgId` | Organization identifier |
| Room name, number and floor | `workspaces.name`, `title`, `room_number`, `floor`, `position` | Actual room data; complete record also in `document_json` |
| Board workspace | `boards.workspaceId` | Current room; empty for a pocketed board |
| Board organization | `boards.orgIds` and original `boards.orgs` | JSON organization identifiers; original orgs structure preserved |
| Person | `entities` + original `users` model | Fictional name in `users.profile.fullname`, location/profile data in JSON; login disabled |
| Furniture | `entities` | Name, description, room, floor, position and other properties preserved |

`workspaces`, `boards.workspaceId` and `boards.orgIds` are user-requested game
extensions. They are not presented as WeKan fields found in the archive. All
extensions are marked in the JSON schema description.

## Dynamic content and two languages

Shared card properties come from `details`. Text in the active language comes
from `localized_details.fi` or `.en`. `cards.title` and `cards.description` contain
the complete text, not just the short four-line 3D preview. When full text is not
yet available, preview lines serve as a fallback. `boardId`, `swimlaneId`, `listId`
and `sort` are always calculated last from the actual `card_locations` ownership
structure, so moving a card does not leave its old location in SQL fields.

Names and descriptions in both languages are also stored in:

```sql
model_translations(collection, document_id, field, language, value)
```

Its primary key combines the first four fields. Switching the active language
does not discard values in the other language. Boards, lists, swimlanes,
workspaces, organizations, people, cards and related records get translation rows
from the available text.

Related records in `card.related[collection]` are projected into the corresponding
source-model tables, such as `card_comments`, `checklists`, `checklistItems`,
`attachments` and `customFields`. Shared fields and active-language text are
combined. Source-model rows written by the game are tracked in
`game_model_projection`, so deleting a comment or another record also removes it
from the actual SQL table on the next save. The registry does not delete records
added outside the game by other applications.

Individual pocketed cards are not assigned an invented board/list: their source
fields are NULL. A board pocketed as a whole preserves its cards' actual boardId
relationship; the game's ownership structure records that the board is pocketed.
Pocketed lists and swimlanes retain all their contents.

The schema description includes logical source-model relationships and search
indexes. No invalid mandatory foreign keys are added for missing external users
or other WeKan records that were not imported. This is the game's data model and
field mapping; it does not execute Meteor server methods, permission rules, file
services or email functionality.

## SQL examples

```sql
-- Actual card location and room:
SELECT c._id, c.title, c.boardId, c.swimlaneId, c.listId,
       w.name AS room_name, w.room_number, w.floor
FROM cards AS c
LEFT JOIN boards AS b ON b._id = c.boardId
LEFT JOIN workspaces AS w ON w._id = b.workspaceId;

-- Organization offices:
SELECT o.orgDisplayName, w.name, w.room_number, w.floor
FROM workspaces AS w
LEFT JOIN org AS o ON o._id = w.orgId;

-- Complete Finnish card descriptions:
SELECT document_id, value
FROM model_translations
WHERE collection = 'cards' AND field = 'description' AND language = 'fi';
```

On load, complete JSON game records and the validated ownership graph are
authoritative; source-model fields are their atomically saved, queryable
representation. The game editor updates both. Editing an SQL projection column
with an external program does not automatically replace complete JSON game records.

## Mapping every source collection

`JSON paths` means nested dotted paths within the JSON content of the same root
column. In schemaless models, `document_json` preserves the open document;
separately detected properties are marked as inferred and are not claimed to be
upstream-validated SimpleSchema definitions.

| Source file | SQL table | SQL columns | JSON paths | Basis |
|---|---|---:|---:|---|
| `accessibilitySettings.js` | `accessibilitySettings` | 6 | 0 | SimpleSchema |
| `accountSettings.js` | `accountSettings` | 5 | 0 | SimpleSchema |
| `actions.js` | `actions` | 5 | 0 | Schemaless collection; open JSON |
| `activities.js` | `activities` | 20 | 0 | Schemaless collection; open JSON |
| `announcements.js` | `announcements` | 7 | 0 | SimpleSchema |
| `attachmentBulkMoveStatus.js` | `attachmentBulkMoveStatus` | 2 | 0 | Schemaless collection; open JSON |
| `attachmentMigrationStatus.js` | `attachmentMigrationStatus` | 2 | 0 | Schemaless collection; open JSON |
| `attachmentStorageSettings.js` | `attachmentStorageSettings` | 10 | 28 | SimpleSchema |
| `attachments.js` | `attachments` | 4 | 0 | Schemaless collection; open JSON |
| `avatars.js` | `avatars` | 2 | 0 | Schemaless collection; open JSON |
| `boards.js` | `boards` | 97 | 31 | SimpleSchema |
| `cardCommentReactions.js` | `card_comment_reactions` | 5 | 4 | SimpleSchema |
| `cardComments.js` | `card_comments` | 8 | 0 | SimpleSchema |
| `cards.js` | `cards` | 55 | 61 | SimpleSchema |
| `changeHistory.js` | `changeHistory` | 22 | 0 | SimpleSchema |
| `checklistItems.js` | `checklistItems` | 9 | 0 | SimpleSchema |
| `checklists.js` | `checklists` | 11 | 0 | SimpleSchema |
| `counters.js` | `counters` | 2 | 0 | Schemaless collection; open JSON |
| `customFields.js` | `customFields` | 12 | 8 | SimpleSchema |
| `eventLog.js` | `eventlog` | 26 | 0 | SimpleSchema |
| `eventLog.js` | `eventlogAcks` | 3 | 0 | SimpleSchema |
| `fileIntegrity.js` | `fileIntegrity` | 2 | 0 | Schemaless collection; open JSON |
| `fileIntegrity.js` | `fileIntegrityKeys` | 2 | 0 | Schemaless collection; open JSON |
| `impersonatedUsers.js` | `impersonatedUsers` | 8 | 0 | SimpleSchema |
| `integrations.js` | `integrations` | 11 | 1 | SimpleSchema |
| `invitationCodes.js` | `invitation_codes` | 8 | 1 | SimpleSchema |
| `inviteToBoardRolesSettings.js` | `inviteToBoardRolesSettings` | 5 | 1 | SimpleSchema |
| `lists.js` | `lists` | 19 | 4 | SimpleSchema |
| `lockoutSettings.js` | `lockoutSettings` | 6 | 0 | SimpleSchema |
| `loginAddresses.js` | `loginAddresses` | 10 | 0 | SimpleSchema |
| `org.js` | `org` | 23 | 1 | SimpleSchema |
| `orgUser.js` | `orgUser` | 6 | 0 | SimpleSchema |
| `positionHistory.js` | `positionHistory` | 10 | 0 | SimpleSchema |
| `presences.js` | `presences` | 2 | 0 | Schemaless collection; open JSON |
| `recoveryEvents.js` | `recoveryEvents` | 16 | 2 | SimpleSchema |
| `recoveryStatus.js` | `recoveryStatus` | 4 | 0 | Schemaless collection; open JSON |
| `rules.js` | `rules` | 9 | 0 | SimpleSchema |
| `usersessiondata.js` | `sessiondata` | 14 | 6 | SimpleSchema |
| `settings.js` | `settings` | 58 | 12 | SimpleSchema |
| `swimlanes.js` | `swimlanes` | 12 | 0 | SimpleSchema |
| `tableVisibilityModeSettings.js` | `tableVisibilityModeSettings` | 5 | 0 | SimpleSchema |
| `team.js` | `team` | 11 | 0 | SimpleSchema |
| `textMigrationStatus.js` | `text_migration_status` | 2 | 0 | Schemaless collection; open JSON |
| `translation.js` | `translation` | 6 | 0 | SimpleSchema |
| `trelloImportJobs.js` | `trello_import_jobs` | 2 | 0 | Schemaless collection; open JSON |
| `triggers.js` | `triggers` | 8 | 0 | Schemaless collection; open JSON |
| `unsavedEdits.js` | `unsaved-edits` | 7 | 0 | SimpleSchema |
| `userPositionHistory.js` | `userPositionHistory` | 22 | 0 | SimpleSchema |
| `users.js` | `users` | 17 | 87 | SimpleSchema |
| `(game extension)` | `workspaces` | 8 | 0 | Game extension |

## Files without a separate table

The following files add functionality to existing models or provide import/export/server helpers. They were analyzed, but do not define a new collection themselves.

| File | Purpose |
|---|---|
| `attachments.server.js` | Helper or server/import/export functionality for an existing model |
| `avatars.server.js` | Helper or server/import/export functionality for an existing model |
| `csvCreator.js` | Helper or server/import/export functionality for an existing model |
| `export.js` | Helper or server/import/export functionality for an existing model |
| `exportExcel.js` | Helper or server/import/export functionality for an existing model |
| `exportExcelCard.js` | Helper or server/import/export functionality for an existing model |
| `exportPDF.js` | Helper or server/import/export functionality for an existing model |
| `exporter.js` | Helper or server/import/export functionality for an existing model |
| `fileValidation.js` | Helper or server/import/export functionality for an existing model |
| `import.js` | Helper or server/import/export functionality for an existing model |
| `importZip.js` | Helper or server/import/export functionality for an existing model |
| `jiraCreator.js` | Helper or server/import/export functionality for an existing model |
| `kanboardCreator.js` | Helper or server/import/export functionality for an existing model |
| `runOnServer.js` | Helper or server/import/export functionality for an existing model |
| `trelloCreator.js` | Helper or server/import/export functionality for an existing model |
| `watchable.js` | Mixin for watchers fields: included in the boards, lists and cards schemas |
| `wekanCreator.js` | Helper or server/import/export functionality for an existing model |
| `wekanmapper.js` | Helper or server/import/export functionality for an existing model |

## Verification

```bash
python tools/generate_schema.py /path/to/extracted/models
redot --headless --path . --script res://tests/wekan_schema_test.gd
redot --headless --path . --script res://tests/sqlite_test.gd
```

The generator runs the generated DDL twice against a real in-memory SQLite database, checks every generated column and nested JSON root, and checks `PRAGMA integrity_check`. The Redot test checks all 626 columns and nested roots, plus actual SQL values for cards, lists, swimlanes, workspaces, organizations, people, comments and translations. Coverage includes pocket moves, renaming, related-record deletion, text with SQL special characters, idempotent schema creation and opening an existing save.
