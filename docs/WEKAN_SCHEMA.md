# WeKan source schema → card editor mapping

The authoritative input is the supplied `models.zip` (65 JavaScript files), not a guessed WeKan version. The original 20 separately supplied files are included in this bundle. Source files were inspected as text; no supplied JavaScript was executed. The project stores field facts and original field names, not copies of the third-party implementation.

`data/card_fields.json` is the editor descriptor catalog. `scripts/core/card_schema.gd` provides defaults, type validation, field lookup and bilingual composition. The independent full database inventory is `data/wekan_schema.json`; SQL projection is documented separately in `docs/DATABASE_MAPPING.md`.

## Coverage

- All **53 top-level fields** declared by `Cards.attachSchema(new SimpleSchema(...))` in `cards.js` are represented, including every declared nested path.
- `watchers` is included from the `simpleWatchable(Cards)` mixin in `watchable.js`.
- `_id` is included as the implicit MongoDB document identity.
- `priority` is a clearly marked **game extension** requested for the editor: `low`, `normal`, `high`, `urgent`. It is not claimed to be a field in the supplied `cards.js`.
- Total: **56 top-level editor descriptors**. The automated schema test compares every card field path from the independently extracted database inventory against the editor catalog.
- Related records have descriptors for checklists, checklist items, threaded comments, comment reactions, attachments and activities. Attachment/activity schemas are open because the supplied source does not declare an exhaustive schema for those collections.

## Storage and editing rules

Card identity remains `card.id`; the editor's `_id` displays that identity. Structural data is `card.details`. Human text is stored in `card.localized_details.fi` and `.en`. The preview uses four lines: title followed by the first three description lines. Editing one language leaves the other language's text intact.

Localized fields are title, description, manually entered requester/assigner names, location names/addresses, sticker names, vote question text, and string-valued custom-field values. Nested array text uses language overlays with an internal `__item_id` anchor where the source supplies `_id`, so reordering identified locations/custom fields keeps translations attached to the right entry. This anchor is storage metadata, not a WeKan field. Custom values that become numeric/boolean remain shared and supersede old text overlays.

IDs, membership arrays, dependency types, colors, icons, numbers, dates, boolean states and ordering are shared between languages. `poker.question` remains **Boolean**, exactly as declared in the source. System-generated identifiers, timestamps and current board/list/swimlane location fields are read only in this editor; this is a game editor rule, not a claim that the original schema declares an authorization policy. Transfers update locations through GameState.

Dates use ISO 8601 text in JSON/SQLite; the validator checks date shape, calendar days and time ranges. Arrays and objects retain nested JSON structure. Complex structures can be edited as JSON with the source field metadata visible. The validator checks nested types, declared allowed values, required fields and applicable size/pattern constraints. Unknown properties remain preserved for open records and forward compatibility. Referenced Meteor methods, authorization rules, database hooks and external storage services are not executed by these descriptors.

## Imported constants and source nuances

The bundle does not include `/config/const` or `/models/metadata/{colors,dependencies}`. Therefore `TYPE_CARD`, `DEFAULT_DEPENDENCY_TYPE`, `DEFAULT_DEPENDENCY_COLOR`, `DEFAULT_DEPENDENCY_ICON`, `DEPENDENCY_TYPE_IDS` and `CARD_COLORS` are recorded symbolically; their values are not invented. The application uses an empty editable value when an unresolved string default cannot be evaluated. The exact source default expression remains in the catalog.

The `type` allowed-values line in `cards.js` is commented out and is not treated as an enforced enum. `color` accepts a named imported palette color or custom hexadecimal color in the source; the external palette and full custom color validator are not reproduced. `assignees` has a comment recommending one assignee but no `maxCount` constraint, so the catalog does not invent one. `vote.end` explicitly defaults to null. Optionality and declared defaults are separately represented; convenient empty form values are application defaults rather than claims about source defaults.

## Card top-level fields

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `_id` | string | Not declared | Shared | Read only | cards.js |
| `title` | string | `""` | FI/EN text | Editable | cards.js |
| `archived` | boolean | Not declared | Shared | Editable | cards.js |
| `archivedAt` | date | Not declared | Shared | Read only | cards.js |
| `deletedAt` | date | Not declared | Shared | Read only | cards.js |
| `deletedBy` | string | Not declared | Shared | Read only | cards.js |
| `deleteBatchId` | string | Not declared | Shared | Read only | cards.js |
| `parentId` | string | `""` | Shared | Editable | cards.js |
| `listId` | string | `""` | Shared | Read only | cards.js |
| `swimlaneId` | string | Not declared | Shared | Read only | cards.js |
| `boardId` | string | `""` | Shared | Read only | cards.js |
| `coverId` | string | `""` | Shared | Editable | cards.js |
| `color` | string | Not declared | Shared | Editable | cards.js |
| `createdAt` | date | Not declared | Shared | Read only | cards.js |
| `modifiedAt` | date | Not declared | Shared | Read only | cards.js |
| `customFields` | array | `[]` | Shared | Editable | cards.js |
| `dateLastActivity` | date | Not declared | Shared | Read only | cards.js |
| `description` | string | `""` | FI/EN text | Editable | cards.js |
| `requestedBy` | string | `""` | FI/EN text | Editable | cards.js |
| `assignedBy` | string | `""` | FI/EN text | Editable | cards.js |
| `labelIds` | array | `[]` | Shared | Editable | cards.js |
| `members` | array | `[]` | Shared | Editable | cards.js |
| `assignees` | array | `[]` | Shared | Editable | cards.js |
| `requesters` | array | `[]` | Shared | Editable | cards.js |
| `assigners` | array | `[]` | Shared | Editable | cards.js |
| `receivedAt` | date | Not declared | Shared | Editable | cards.js |
| `startAt` | date | Not declared | Shared | Editable | cards.js |
| `dueAt` | date | Not declared | Shared | Editable | cards.js |
| `endAt` | date | Not declared | Shared | Editable | cards.js |
| `dueComplete` | boolean | `false` | Shared | Editable | cards.js |
| `stickers` | array | `[]` | Shared | Editable | cards.js |
| `locationName` | string | `""` | FI/EN text | Editable | cards.js |
| `locationAddress` | string | `""` | FI/EN text | Editable | cards.js |
| `locationLatitude` | number | Not declared | Shared | Editable | cards.js |
| `locationLongitude` | number | Not declared | Shared | Editable | cards.js |
| `locations` | array | `[]` | Shared | Editable | cards.js |
| `spentTime` | number | `0` | Shared | Editable | cards.js |
| `isOvertime` | boolean | `false` | Shared | Editable | cards.js |
| `userId` | string | Not declared | Shared | Read only | cards.js |
| `sort` | number | `0` | Shared | Read only | cards.js |
| `subtaskSort` | number | `-1` | Shared | Read only | cards.js |
| `type` | string | `TYPE_CARD` (unresolved import) | Shared | Editable | cards.js |
| `linkedId` | string | `""` | Shared | Editable | cards.js |
| `cardDependencies` | array | `[]` | Shared | Editable | cards.js |
| `vote` | object | Not declared | Shared | Editable | cards.js |
| `poker` | object | Not declared | Shared | Editable | cards.js |
| `targetId_gantt` | array | `[]` | Shared | Editable | cards.js |
| `linkType_gantt` | array | `[]` | Shared | Editable | cards.js |
| `linkId_gantt` | array | `[]` | Shared | Editable | cards.js |
| `cardNumber` | number | `0` | Shared | Read only | cards.js |
| `showActivities` | boolean | `false` | Shared | Editable | cards.js |
| `showListOnMinicard` | boolean | `false` | Shared | Editable | cards.js |
| `showChecklistAtMinicard` | boolean | `false` | Shared | Editable | cards.js |
| `hideFinishedChecklistIfItemsAreHidden` | boolean | `false` | Shared | Editable | cards.js |
| `watchers` | array | Not declared | Shared | Editable | watchable.js |
| `priority` | string | `"normal"` | Shared | Editable | game extension |

## Nested card structures

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `customFields.$` | object | Not declared | Shared | Editable | cards.js |
| `customFields.$._id` | string | `""` | Shared | Editable | cards.js |
| `customFields.$.value` | mixed | `""` | FI/EN only for string values; other types shared | Editable | cards.js |
| `customFields.$.value.$` | string | Not declared | Shared | Editable | cards.js |
| `labelIds.$` | string | Not declared | Shared | Editable | cards.js |
| `members.$` | string | Not declared | Shared | Editable | cards.js |
| `assignees.$` | string | Not declared | Shared | Editable | cards.js |
| `requesters.$` | string | Not declared | Shared | Editable | cards.js |
| `assigners.$` | string | Not declared | Shared | Editable | cards.js |
| `stickers.$` | object | Not declared | Shared | Editable | cards.js |
| `stickers.$.icon` | string | `""` | Shared | Editable | cards.js |
| `stickers.$.name` | string | `""` | FI/EN text | Editable | cards.js |
| `stickers.$.highlight` | string | Not declared | Shared | Editable | cards.js |
| `stickers.$.position` | number | `0` | Shared | Editable | cards.js |
| `locations.$` | object | Not declared | Shared | Editable | cards.js |
| `locations.$._id` | string | Not declared | Shared | Editable | cards.js |
| `locations.$.name` | string | `""` | FI/EN text | Editable | cards.js |
| `locations.$.address` | string | `""` | FI/EN text | Editable | cards.js |
| `locations.$.latitude` | number | Not declared | Shared | Editable | cards.js |
| `locations.$.longitude` | number | Not declared | Shared | Editable | cards.js |
| `cardDependencies.$` | object | Not declared | Shared | Editable | cards.js |
| `cardDependencies.$.cardId` | string | Not declared | Shared | Editable | cards.js |
| `cardDependencies.$.type` | string | `DEFAULT_DEPENDENCY_TYPE` (unresolved import) | Shared | Editable | cards.js |
| `cardDependencies.$.color` | string | `DEFAULT_DEPENDENCY_COLOR` (unresolved import) | Shared | Editable | cards.js |
| `cardDependencies.$.icon` | string | `DEFAULT_DEPENDENCY_ICON` (unresolved import) | Shared | Editable | cards.js |
| `vote.question` | string | `""` | FI/EN text | Editable | cards.js |
| `vote.positive` | array | `[]` | Shared | Editable | cards.js |
| `vote.positive.$` | string | Not declared | Shared | Editable | cards.js |
| `vote.negative` | array | `[]` | Shared | Editable | cards.js |
| `vote.negative.$` | string | Not declared | Shared | Editable | cards.js |
| `vote.end` | date | `null` | Shared | Editable | cards.js |
| `vote.public` | boolean | `false` | Shared | Editable | cards.js |
| `vote.allowNonBoardMembers` | boolean | `false` | Shared | Editable | cards.js |
| `poker.question` | boolean | Not declared | Shared | Editable | cards.js |
| `poker.one` | array | Not declared | Shared | Editable | cards.js |
| `poker.one.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.two` | array | Not declared | Shared | Editable | cards.js |
| `poker.two.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.three` | array | Not declared | Shared | Editable | cards.js |
| `poker.three.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.five` | array | Not declared | Shared | Editable | cards.js |
| `poker.five.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.eight` | array | Not declared | Shared | Editable | cards.js |
| `poker.eight.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.thirteen` | array | Not declared | Shared | Editable | cards.js |
| `poker.thirteen.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.twenty` | array | Not declared | Shared | Editable | cards.js |
| `poker.twenty.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.forty` | array | Not declared | Shared | Editable | cards.js |
| `poker.forty.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.oneHundred` | array | Not declared | Shared | Editable | cards.js |
| `poker.oneHundred.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.unsure` | array | Not declared | Shared | Editable | cards.js |
| `poker.unsure.$` | string | Not declared | Shared | Editable | cards.js |
| `poker.end` | date | Not declared | Shared | Editable | cards.js |
| `poker.allowNonBoardMembers` | boolean | Not declared | Shared | Editable | cards.js |
| `poker.estimation` | number | Not declared | Shared | Editable | cards.js |
| `targetId_gantt.$` | string | Not declared | Shared | Editable | cards.js |
| `linkType_gantt.$` | number | Not declared | Shared | Editable | cards.js |
| `linkId_gantt.$` | string | Not declared | Shared | Editable | cards.js |
| `watchers.$` | string | Not declared | Shared | Editable | watchable.js |

## Related record schemas

### checklists

Declared in `checklists.js`.

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `cardId` | string | Not declared | Shared | Read only | checklists.js |
| `boardId` | string | Not declared | Shared | Read only | checklists.js |
| `title` | string | `"Checklist"` | FI/EN text | Editable | checklists.js |
| `finishedAt` | date | Not declared | Shared | Read only | checklists.js |
| `createdAt` | date | Not declared | Shared | Read only | checklists.js |
| `modifiedAt` | date | Not declared | Shared | Read only | checklists.js |
| `sort` | number | Not declared | Shared | Editable | checklists.js |
| `hideCheckedChecklistItems` | boolean | Not declared | Shared | Editable | checklists.js |
| `hideAllChecklistItems` | boolean | Not declared | Shared | Editable | checklists.js |
| `showChecklistAtMinicard` | boolean | Not declared | Shared | Editable | checklists.js |

### checklistItems

Declared in `checklistItems.js`.

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `title` | string | Not declared | FI/EN text | Editable | checklistItems.js |
| `sort` | number | Not declared | Shared | Editable | checklistItems.js |
| `isFinished` | boolean | `false` | Shared | Editable | checklistItems.js |
| `checklistId` | string | Not declared | Shared | Read only | checklistItems.js |
| `cardId` | string | Not declared | Shared | Read only | checklistItems.js |
| `boardId` | string | Not declared | Shared | Read only | checklistItems.js |
| `createdAt` | date | Not declared | Shared | Read only | checklistItems.js |
| `modifiedAt` | date | Not declared | Shared | Read only | checklistItems.js |

### cardComments

Declared in `cardComments.js`.

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `boardId` | string | Not declared | Shared | Read only | cardComments.js |
| `cardId` | string | Not declared | Shared | Read only | cardComments.js |
| `text` | string | Not declared | FI/EN text | Editable | cardComments.js |
| `parentId` | string | `""` | Shared | Editable | cardComments.js |
| `createdAt` | date | Not declared | Shared | Read only | cardComments.js |
| `modifiedAt` | date | Not declared | Shared | Read only | cardComments.js |
| `userId` | string | Not declared | Shared | Read only | cardComments.js |

### cardCommentReactions

Declared in `cardCommentReactions.js`.

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `boardId` | string | Not declared | Shared | Read only | cardCommentReactions.js |
| `cardId` | string | Not declared | Shared | Read only | cardCommentReactions.js |
| `cardCommentId` | string | Not declared | Shared | Read only | cardCommentReactions.js |
| `reactions` | array | `[]` | Shared | Editable | cardCommentReactions.js |
| `reactions.$` | object | Not declared | Shared | Editable | cardCommentReactions.js |
| `reactions.$.reactionCodepoint` | string | Not declared | Shared | Editable | cardCommentReactions.js |
| `reactions.$.userIds` | array | `[]` | Shared | Editable | cardCommentReactions.js |
| `reactions.$.userIds.$` | string | Not declared | Shared | Editable | cardCommentReactions.js |

### attachments

FilesCollection has no attached SimpleSchema in supplied source. These are observed file/metadata properties, not an exhaustive library schema. Binary payload is separate from card metadata.

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `_id` | string | Not declared | Shared | Read only | attachments.js |
| `name` | string | Not declared | Shared | Editable | attachments.js |
| `type` | string | Not declared | Shared | Editable | attachments.js |
| `extension` | string | Not declared | Shared | Editable | attachments.js |
| `extensionWithDot` | string | Not declared | Shared | Editable | attachments.js |
| `userId` | string | Not declared | Shared | Read only | attachments.js |
| `meta` | object | Not declared | Shared | Editable | attachments.js |
| `meta.boardId` | string | Not declared | Shared | Read only | attachments.js |
| `meta.cardId` | string | Not declared | Shared | Read only | attachments.js |
| `meta.listId` | string | Not declared | Shared | Read only | attachments.js |
| `meta.swimlaneId` | string | Not declared | Shared | Read only | attachments.js |
| `versions` | object | Not declared | Shared | Read only | attachments.js |

### activities

Source explicitly has no schema: trusted server events contain event-specific fields. Observed references and timestamp hooks are listed; preserve extra fields.

| Source path | Type | Source default | Storage | Editor | Source |
|---|---|---|---|---|---|
| `_id` | string | Not declared | Shared | Read only | activities.js |
| `activityType` | string | Not declared | Shared | Read only | attachments.js |
| `type` | string | Not declared | Shared | Read only | attachments.js |
| `userId` | string | Not declared | Shared | Read only | attachments.js |
| `boardId` | string | Not declared | Shared | Read only | activities.js |
| `oldBoardId` | string | Not declared | Shared | Read only | activities.js |
| `cardId` | string | Not declared | Shared | Read only | activities.js |
| `listId` | string | Not declared | Shared | Read only | activities.js |
| `oldListId` | string | Not declared | Shared | Read only | activities.js |
| `swimlaneId` | string | Not declared | Shared | Read only | activities.js |
| `oldSwimlaneId` | string | Not declared | Shared | Read only | activities.js |
| `memberId` | string | Not declared | Shared | Read only | activities.js |
| `commentId` | string | Not declared | Shared | Read only | activities.js |
| `commentText` | string | Not declared | Shared | Read only | activities.js |
| `attachmentId` | string | Not declared | Shared | Read only | activities.js |
| `attachmentName` | string | Not declared | Shared | Read only | attachments.js |
| `checklistId` | string | Not declared | Shared | Read only | activities.js |
| `checklistItemId` | string | Not declared | Shared | Read only | activities.js |
| `subtaskId` | string | Not declared | Shared | Read only | activities.js |
| `customFieldId` | string | Not declared | Shared | Read only | activities.js |
| `labelId` | string | Not declared | Shared | Read only | activities.js |
| `createdAt` | date | Not declared | Shared | Read only | activities.js |
| `modifiedAt` | date | Not declared | Shared | Read only | activities.js |

`checklists.cardId` links a checklist to a card. `checklistItems.checklistId` links each entry to its checklist, with cardId/boardId denormalized on the record. Comment `parentId` links a reply to another comment. Reaction records link to `cardCommentId`; reaction entries contain an HTML numeric character reference and shared user IDs. Attachments link to cards through `meta.cardId`; file bytes and storage strategy behavior are separate from metadata. Activity records have event-specific links, original text snapshots and server-generated timestamps; extra event properties are preserved.

## All supplied files

This inventory covers all 65 supplied files. Collection fields for non-card models are mapped in the full SQLite inventory; import/export adapters and server helpers are recorded as source roles rather than misrepresented as database collections.

| Source file | Purpose | Collections found by the database extractor |
|---|---|---|
| `accessibilitySettings.js` | Accessibility preferences | `accessibilitySettings` |
| `accountSettings.js` | Account policy settings | `accountSettings` |
| `actions.js` | Automation actions | `actions` |
| `activities.js` | Polymorphic activity log | `activities` |
| `announcements.js` | Announcements | `announcements` |
| `attachmentBulkMoveStatus.js` | Attachment bulk-move progress | `attachmentBulkMoveStatus` |
| `attachmentMigrationStatus.js` | Attachment migration progress | `attachmentMigrationStatus` |
| `attachmentStorageSettings.js` | Attachment storage configuration | `attachmentStorageSettings` |
| `attachments.js` | File metadata and FilesCollection client hooks | `attachments` |
| `attachments.server.js` | Server attachment storage/upload hooks | No collection declaration |
| `avatars.js` | Avatar FilesCollection | `avatars` |
| `avatars.server.js` | Server avatar storage hooks | No collection declaration |
| `boards.js` | Boards, memberships and board options | `boards` |
| `cardCommentReactions.js` | Comment reactions and user IDs | `card_comment_reactions` |
| `cardComments.js` | Threaded card comments | `card_comments` |
| `cards.js` | Card fields and card behavior | `cards` |
| `changeHistory.js` | Universal change audit history | `changeHistory` |
| `checklistItems.js` | Checklist entries | `checklistItems` |
| `checklists.js` | Card checklists | `checklists` |
| `counters.js` | Sequence counters | `counters` |
| `csvCreator.js` | CSV import adapter | No collection declaration |
| `customFields.js` | Custom-field definitions | `customFields` |
| `eventLog.js` | Event log collection | `eventlog`, `eventlogAcks` |
| `export.js` | Export orchestration | No collection declaration |
| `exportExcel.js` | Spreadsheet export | No collection declaration |
| `exportExcelCard.js` | Card spreadsheet export | No collection declaration |
| `exportPDF.js` | PDF export | No collection declaration |
| `exporter.js` | Export data assembly | No collection declaration |
| `fileIntegrity.js` | File integrity checks | `fileIntegrity`, `fileIntegrityKeys` |
| `fileValidation.js` | Uploaded-file validation | No collection declaration |
| `impersonatedUsers.js` | Impersonation state | `impersonatedUsers` |
| `import.js` | Import orchestration | No collection declaration |
| `importZip.js` | ZIP import | No collection declaration |
| `integrations.js` | External integration settings | `integrations` |
| `invitationCodes.js` | Invitation codes | `invitation_codes` |
| `inviteToBoardRolesSettings.js` | Board invitation role settings | `inviteToBoardRolesSettings` |
| `jiraCreator.js` | Jira import adapter | No collection declaration |
| `kanboardCreator.js` | Kanboard import adapter | No collection declaration |
| `lists.js` | Board lists | `lists` |
| `lockoutSettings.js` | Account lockout configuration | `lockoutSettings` |
| `loginAddresses.js` | Login address records | `loginAddresses` |
| `org.js` | Organizations | `org` |
| `orgUser.js` | Organization membership | `orgUser` |
| `positionHistory.js` | Card position history | `positionHistory` |
| `presences.js` | Presence records | `presences` |
| `recoveryEvents.js` | Recovery event records | `recoveryEvents` |
| `recoveryStatus.js` | Recovery progress | `recoveryStatus` |
| `rules.js` | Automation rules | `rules` |
| `runOnServer.js` | Server execution support | No collection declaration |
| `settings.js` | Global application settings | `settings` |
| `swimlanes.js` | Board swimlanes | `swimlanes` |
| `tableVisibilityModeSettings.js` | Table-view visibility options | `tableVisibilityModeSettings` |
| `team.js` | Teams | `team` |
| `textMigrationStatus.js` | Text migration progress | `text_migration_status` |
| `translation.js` | Translation data | `translation` |
| `trelloCreator.js` | Trello import adapter | No collection declaration |
| `trelloImportJobs.js` | Trello import job tracking | `trello_import_jobs` |
| `triggers.js` | Automation triggers | `triggers` |
| `unsavedEdits.js` | Unsaved editor content | `unsaved-edits` |
| `userPositionHistory.js` | User position history | `userPositionHistory` |
| `users.js` | Meteor user profiles and account schema | `users` |
| `usersessiondata.js` | User session data | `sessiondata` |
| `watchable.js` | Watcher schema mixins | No collection declaration |
| `wekanCreator.js` | WeKan import adapter | No collection declaration |
| `wekanmapper.js` | WeKan import field mapping | No collection declaration |

## Verification

`tests/card_schema_test.gd` checks complete source-path coverage, default documents, type/enum/date/reaction validation, language isolation, nested shared IDs and translated array reordering. `tests/card_editor_test.gd` covers the editor integration. Source SHA-256 fingerprints are in the JSON catalogs.
