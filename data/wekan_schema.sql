-- Generated from the user-provided models.zip; JavaScript was parsed, never executed.
-- Standalone source-model schema. Runtime uses ensure_tables() to augment game tables.
-- Required/optional and dynamic autoValue semantics remain in wekan_schema.json.
PRAGMA foreign_keys = ON;

-- accessibilitySettings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "accessibilitySettings" (
  "enabled" INTEGER,
  "title" TEXT,
  "body" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);

-- accountSettings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "accountSettings" (
  "_id" TEXT UNIQUE,
  "booleanValue" INTEGER,
  "sort" REAL,
  "createdAt" TEXT,
  "modifiedAt" TEXT
);

-- actions.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "actions" (
  "document_json" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "desc" TEXT,
  "_id" TEXT UNIQUE
);

-- activities.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "activities" (
  "document_json" TEXT,
  "boardId" TEXT,
  "oldBoardId" TEXT,
  "userId" TEXT,
  "memberId" TEXT,
  "listId" TEXT,
  "swimlaneId" TEXT,
  "oldSwimlaneId" TEXT,
  "oldListId" TEXT,
  "cardId" TEXT,
  "commentId" TEXT,
  "commentText" TEXT,
  "attachmentId" TEXT,
  "checklistId" TEXT,
  "checklistItemId" TEXT,
  "subtaskId" TEXT,
  "customFieldId" TEXT,
  "labelId" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_activities_boardId" ON "activities"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_activities_userId" ON "activities"("userId");
CREATE INDEX IF NOT EXISTS "wekan_activities_listId" ON "activities"("listId");
CREATE INDEX IF NOT EXISTS "wekan_activities_swimlaneId" ON "activities"("swimlaneId");
CREATE INDEX IF NOT EXISTS "wekan_activities_cardId" ON "activities"("cardId");
CREATE INDEX IF NOT EXISTS "wekan_activities_commentId" ON "activities"("commentId");
CREATE INDEX IF NOT EXISTS "wekan_activities_checklistId" ON "activities"("checklistId");

-- announcements.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "announcements" (
  "enabled" INTEGER,
  "title" TEXT,
  "body" TEXT,
  "sort" REAL,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);

-- attachmentBulkMoveStatus.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "attachmentBulkMoveStatus" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- attachmentMigrationStatus.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "attachmentMigrationStatus" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- attachmentStorageSettings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "attachmentStorageSettings" (
  "defaultStorage" TEXT,
  "storageConfig" TEXT,
  "uploadSettings" TEXT,
  "limitSettings" TEXT,
  "migrationSettings" TEXT,
  "createdAt" TEXT,
  "updatedAt" TEXT,
  "createdBy" TEXT,
  "updatedBy" TEXT,
  "_id" TEXT UNIQUE
);

-- attachments.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "attachments" (
  "document_json" TEXT,
  "meta" TEXT,
  "userId" TEXT,
  "name" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_attachments_userId" ON "attachments"("userId");

-- avatars.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "avatars" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- boards.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "boards" (
  "title" TEXT,
  "slug" TEXT,
  "archived" INTEGER,
  "archivedAt" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "stars" REAL,
  "labels" TEXT,
  "members" TEXT,
  "permission" TEXT,
  "orgs" TEXT,
  "teams" TEXT,
  "domains" TEXT,
  "importUsernames" TEXT,
  "color" TEXT,
  "customThemeColors" TEXT,
  "backgroundImageURL" TEXT,
  "backgroundImageId" TEXT,
  "allowsCardCounterList" INTEGER,
  "cardAging" INTEGER,
  "showDependencies" INTEGER,
  "cardAgingDays1" REAL,
  "cardAgingDays2" REAL,
  "cardAgingDays3" REAL,
  "allowsBoardMemberList" INTEGER,
  "description" TEXT,
  "subtasksDefaultBoardId" TEXT,
  "migrationVersion" REAL,
  "subtasksDefaultListId" TEXT,
  "dateSettingsDefaultBoardId" TEXT,
  "dateSettingsDefaultListId" TEXT,
  "allowsSubtasks" INTEGER,
  "allowsSubtasksOnMinicard" INTEGER,
  "allowsAttachments" INTEGER,
  "allowsAttachmentsOnMinicard" INTEGER,
  "allowsChecklists" INTEGER,
  "allowsChecklistsOnMinicard" INTEGER,
  "allowsCustomFields" INTEGER,
  "allowsCustomFieldsOnMinicard" INTEGER,
  "allowsChecklistCountBadgeOnMinicard" INTEGER,
  "allowsComments" INTEGER,
  "allowsDescriptionTitle" INTEGER,
  "allowsDescriptionTitleOnMinicard" INTEGER,
  "allowsDescriptionText" INTEGER,
  "allowsDescriptionTextOnMinicard" INTEGER,
  "allowsCoverAttachmentOnMinicard" INTEGER,
  "allowsCoverAttachmentOnCard" INTEGER,
  "allowsBadgeAttachmentOnMinicard" INTEGER,
  "allowsAttachmentCountOnCard" INTEGER,
  "allowsChecklistCountBadgeOnCard" INTEGER,
  "allowsCardSortingByNumberOnMinicard" INTEGER,
  "allowsCardNumber" INTEGER,
  "allowsCardNumberOnMinicard" INTEGER,
  "allowsActivities" INTEGER,
  "allowsLabels" INTEGER,
  "allowsLabelsOnMinicard" INTEGER,
  "allowsCreator" INTEGER,
  "allowsCreatorOnMinicard" INTEGER,
  "allowsAssignee" INTEGER,
  "allowsAssigneeOnMinicard" INTEGER,
  "allowsMembers" INTEGER,
  "allowsMembersOnMinicard" INTEGER,
  "allowsRequestedBy" INTEGER,
  "allowsRequestedByOnMinicard" INTEGER,
  "allowsCardSortingByNumber" INTEGER,
  "allowsShowLists" INTEGER,
  "allowsAssignedBy" INTEGER,
  "allowsAssignedByOnMinicard" INTEGER,
  "allowsShowListsOnMinicard" INTEGER,
  "allowsChecklistAtMinicard" INTEGER,
  "allowsReceivedDate" INTEGER,
  "restrictCommentEditing" INTEGER,
  "allowsPersonalListWidth" INTEGER,
  "autoWidth" INTEGER,
  "allowsReceivedDateOnMinicard" INTEGER,
  "allowsStartDate" INTEGER,
  "allowsStartDateOnMinicard" INTEGER,
  "allowsEndDate" INTEGER,
  "allowsEndDateOnMinicard" INTEGER,
  "allowsDueDate" INTEGER,
  "allowsDueDateOnMinicard" INTEGER,
  "allowsDueComplete" INTEGER,
  "allowsDueCompleteOnMinicard" INTEGER,
  "presentParentTask" TEXT,
  "receivedAt" TEXT,
  "startAt" TEXT,
  "dueAt" TEXT,
  "endAt" TEXT,
  "spentTime" REAL,
  "isOvertime" INTEGER,
  "type" TEXT,
  "sort" REAL,
  "showActivities" INTEGER,
  "watchers" TEXT,
  "workspaceId" TEXT,
  "orgIds" TEXT,
  "_id" TEXT UNIQUE
);

-- cardCommentReactions.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "card_comment_reactions" (
  "boardId" TEXT,
  "cardId" TEXT,
  "cardCommentId" TEXT,
  "reactions" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_card_comment_reactions_boardId" ON "card_comment_reactions"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_card_comment_reactions_cardId" ON "card_comment_reactions"("cardId");

-- cardComments.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "card_comments" (
  "boardId" TEXT,
  "cardId" TEXT,
  "text" TEXT,
  "parentId" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "userId" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_card_comments_boardId" ON "card_comments"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_card_comments_cardId" ON "card_comments"("cardId");
CREATE INDEX IF NOT EXISTS "wekan_card_comments_userId" ON "card_comments"("userId");

-- cards.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "cards" (
  "title" TEXT,
  "archived" INTEGER,
  "archivedAt" TEXT,
  "deletedAt" TEXT,
  "deletedBy" TEXT,
  "deleteBatchId" TEXT,
  "parentId" TEXT,
  "listId" TEXT,
  "swimlaneId" TEXT,
  "boardId" TEXT,
  "coverId" TEXT,
  "color" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "customFields" TEXT,
  "dateLastActivity" TEXT,
  "description" TEXT,
  "requestedBy" TEXT,
  "assignedBy" TEXT,
  "labelIds" TEXT,
  "members" TEXT,
  "assignees" TEXT,
  "requesters" TEXT,
  "assigners" TEXT,
  "receivedAt" TEXT,
  "startAt" TEXT,
  "dueAt" TEXT,
  "endAt" TEXT,
  "dueComplete" INTEGER,
  "stickers" TEXT,
  "locationName" TEXT,
  "locationAddress" TEXT,
  "locationLatitude" REAL,
  "locationLongitude" REAL,
  "locations" TEXT,
  "spentTime" REAL,
  "isOvertime" INTEGER,
  "userId" TEXT,
  "sort" REAL,
  "subtaskSort" REAL,
  "type" TEXT,
  "linkedId" TEXT,
  "cardDependencies" TEXT,
  "vote" TEXT,
  "poker" TEXT,
  "targetId_gantt" TEXT,
  "linkType_gantt" TEXT,
  "linkId_gantt" TEXT,
  "cardNumber" REAL,
  "showActivities" INTEGER,
  "showListOnMinicard" INTEGER,
  "showChecklistAtMinicard" INTEGER,
  "hideFinishedChecklistIfItemsAreHidden" INTEGER,
  "watchers" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_cards_listId" ON "cards"("listId");
CREATE INDEX IF NOT EXISTS "wekan_cards_swimlaneId" ON "cards"("swimlaneId");
CREATE INDEX IF NOT EXISTS "wekan_cards_boardId" ON "cards"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_cards_userId" ON "cards"("userId");

-- changeHistory.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "changeHistory" (
  "boardId" TEXT,
  "swimlaneId" TEXT,
  "listId" TEXT,
  "cardId" TEXT,
  "entityType" TEXT,
  "entityId" TEXT,
  "group" TEXT,
  "changeType" TEXT,
  "previousContent" TEXT,
  "newContent" TEXT,
  "userId" TEXT,
  "createdAt" TEXT,
  "undone" INTEGER,
  "undoneAt" TEXT,
  "isCheckpoint" INTEGER,
  "batchId" TEXT,
  "restoredFromId" TEXT,
  "restoredByUserId" TEXT,
  "previousHash" TEXT,
  "integrityHash" TEXT,
  "superseded" INTEGER,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_changeHistory_boardId" ON "changeHistory"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_changeHistory_swimlaneId" ON "changeHistory"("swimlaneId");
CREATE INDEX IF NOT EXISTS "wekan_changeHistory_listId" ON "changeHistory"("listId");
CREATE INDEX IF NOT EXISTS "wekan_changeHistory_cardId" ON "changeHistory"("cardId");
CREATE INDEX IF NOT EXISTS "wekan_changeHistory_userId" ON "changeHistory"("userId");

-- checklistItems.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "checklistItems" (
  "title" TEXT,
  "sort" REAL,
  "isFinished" INTEGER,
  "checklistId" TEXT,
  "cardId" TEXT,
  "boardId" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_checklistItems_checklistId" ON "checklistItems"("checklistId");
CREATE INDEX IF NOT EXISTS "wekan_checklistItems_cardId" ON "checklistItems"("cardId");
CREATE INDEX IF NOT EXISTS "wekan_checklistItems_boardId" ON "checklistItems"("boardId");

-- checklists.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "checklists" (
  "cardId" TEXT,
  "boardId" TEXT,
  "title" TEXT,
  "finishedAt" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "sort" REAL,
  "hideCheckedChecklistItems" INTEGER,
  "hideAllChecklistItems" INTEGER,
  "showChecklistAtMinicard" INTEGER,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_checklists_cardId" ON "checklists"("cardId");
CREATE INDEX IF NOT EXISTS "wekan_checklists_boardId" ON "checklists"("boardId");

-- counters.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "counters" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- customFields.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "customFields" (
  "boardIds" TEXT,
  "name" TEXT,
  "type" TEXT,
  "settings" TEXT,
  "showOnCard" INTEGER,
  "automaticallyOnCard" INTEGER,
  "alwaysOnCard" INTEGER,
  "showLabelOnMiniCard" INTEGER,
  "showSumAtTopOfList" INTEGER,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);

-- eventLog.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "eventlog" (
  "stream" TEXT,
  "at" TEXT,
  "severity" TEXT,
  "category" TEXT,
  "bleed" TEXT,
  "action" TEXT,
  "source" TEXT,
  "cwe" TEXT,
  "userId" TEXT,
  "username" TEXT,
  "ip" TEXT,
  "ipv4" TEXT,
  "ipv6" TEXT,
  "location" TEXT,
  "count" REAL,
  "firstAt" TEXT,
  "actors" TEXT,
  "actorsOverflow" REAL,
  "detail" TEXT,
  "type" TEXT,
  "db" TEXT,
  "kind" TEXT,
  "message" TEXT,
  "api" TEXT,
  "apiUserId" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_eventlog_userId" ON "eventlog"("userId");

-- eventLog.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "eventlogAcks" (
  "stream" TEXT,
  "at" TEXT,
  "_id" TEXT UNIQUE
);

-- fileIntegrity.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "fileIntegrity" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- fileIntegrity.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "fileIntegrityKeys" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- (game extension): explicit game extension; absent from uploaded models.zip
CREATE TABLE IF NOT EXISTS "floors" (
  "_id" TEXT UNIQUE,
  "orgId" TEXT,
  "name" TEXT,
  "title" TEXT,
  "number" INTEGER,
  "deleted" INTEGER,
  "in_pocket" INTEGER
);
CREATE INDEX IF NOT EXISTS "wekan_floors_orgId" ON "floors"("orgId");

-- impersonatedUsers.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "impersonatedUsers" (
  "adminId" TEXT,
  "userId" TEXT,
  "boardId" TEXT,
  "attachmentId" TEXT,
  "reason" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_impersonatedUsers_userId" ON "impersonatedUsers"("userId");
CREATE INDEX IF NOT EXISTS "wekan_impersonatedUsers_boardId" ON "impersonatedUsers"("boardId");

-- integrations.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "integrations" (
  "enabled" INTEGER,
  "title" TEXT,
  "type" TEXT,
  "activities" TEXT,
  "url" TEXT,
  "token" TEXT,
  "boardId" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "userId" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_integrations_boardId" ON "integrations"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_integrations_userId" ON "integrations"("userId");

-- invitationCodes.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "invitation_codes" (
  "code" TEXT,
  "email" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "authorId" TEXT,
  "boardsToBeInvited" TEXT,
  "valid" INTEGER,
  "_id" TEXT UNIQUE
);

-- inviteToBoardRolesSettings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "inviteToBoardRolesSettings" (
  "_id" TEXT UNIQUE,
  "allowedRoles" TEXT,
  "sort" REAL,
  "createdAt" TEXT,
  "modifiedAt" TEXT
);

-- lists.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "lists" (
  "title" TEXT,
  "starred" INTEGER,
  "archived" INTEGER,
  "archivedAt" TEXT,
  "deletedAt" TEXT,
  "deletedBy" TEXT,
  "deleteBatchId" TEXT,
  "boardId" TEXT,
  "swimlaneId" TEXT,
  "createdAt" TEXT,
  "sort" REAL,
  "updatedAt" TEXT,
  "modifiedAt" TEXT,
  "wipLimit" TEXT,
  "color" TEXT,
  "type" TEXT,
  "width" REAL,
  "watchers" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_lists_boardId" ON "lists"("boardId");
CREATE INDEX IF NOT EXISTS "wekan_lists_swimlaneId" ON "lists"("swimlaneId");

-- lockoutSettings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "lockoutSettings" (
  "_id" TEXT UNIQUE,
  "value" REAL,
  "category" TEXT,
  "sort" REAL,
  "createdAt" TEXT,
  "modifiedAt" TEXT
);

-- loginAddresses.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "loginAddresses" (
  "address" TEXT,
  "ipv4" TEXT,
  "ipv6" TEXT,
  "count" REAL,
  "firstAt" TEXT,
  "at" TEXT,
  "users" TEXT,
  "location" TEXT,
  "locationLabel" TEXT,
  "_id" TEXT UNIQUE
);

-- org.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "org" (
  "orgDisplayName" TEXT,
  "orgDesc" TEXT,
  "orgShortName" TEXT,
  "orgAutoAddUsersWithDomainName" TEXT,
  "orgWebsite" TEXT,
  "orgIsActive" INTEGER,
  "orgSharedTemplates" INTEGER,
  "orgPropagateMembersToBoards" INTEGER,
  "orgSyncMembersFromAuth" INTEGER,
  "orgDomains" TEXT,
  "orgProductName" TEXT,
  "orgThemeColor" TEXT,
  "orgThemeCustomColors" TEXT,
  "orgCustomLoginLogoImageUrl" TEXT,
  "orgCustomLoginLogoLinkUrl" TEXT,
  "orgTextBelowCustomLoginLogo" TEXT,
  "orgCustomTopLeftCornerLogoImageUrl" TEXT,
  "orgCustomTopLeftCornerLogoLinkUrl" TEXT,
  "orgCustomHelpLinkUrl" TEXT,
  "orgLegalNotice" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);

-- orgUser.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "orgUser" (
  "_id" REAL UNIQUE,
  "orgId" REAL,
  "userId" REAL,
  "role" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT
);
CREATE INDEX IF NOT EXISTS "wekan_orgUser_orgId" ON "orgUser"("orgId");
CREATE INDEX IF NOT EXISTS "wekan_orgUser_userId" ON "orgUser"("userId");

-- positionHistory.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "positionHistory" (
  "boardId" TEXT,
  "entityType" TEXT,
  "entityId" TEXT,
  "originalPosition" TEXT,
  "originalSwimlaneId" TEXT,
  "originalListId" TEXT,
  "originalTitle" TEXT,
  "createdAt" TEXT,
  "updatedAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_positionHistory_boardId" ON "positionHistory"("boardId");

-- presences.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "presences" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- recoveryEvents.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "recoveryEvents" (
  "type" TEXT,
  "db" TEXT,
  "detail" TEXT,
  "severity" TEXT,
  "source" TEXT,
  "done" INTEGER,
  "deletedData" INTEGER,
  "userId" TEXT,
  "username" TEXT,
  "ipv4" TEXT,
  "ipv6" TEXT,
  "location" TEXT,
  "boardIds" TEXT,
  "boardTitles" TEXT,
  "createdAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_recoveryEvents_userId" ON "recoveryEvents"("userId");

-- recoveryStatus.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "recoveryStatus" (
  "document_json" TEXT,
  "active" TEXT,
  "message" TEXT,
  "_id" TEXT UNIQUE
);

-- rules.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "rules" (
  "title" TEXT,
  "triggerId" TEXT,
  "actionId" TEXT,
  "boardId" TEXT,
  "buttonType" TEXT,
  "buttonLabel" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_rules_triggerId" ON "rules"("triggerId");
CREATE INDEX IF NOT EXISTS "wekan_rules_actionId" ON "rules"("actionId");
CREATE INDEX IF NOT EXISTS "wekan_rules_boardId" ON "rules"("boardId");

-- usersessiondata.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "sessiondata" (
  "_id" REAL UNIQUE,
  "userId" TEXT,
  "sessionId" TEXT,
  "totalHits" REAL,
  "resultsCount" REAL,
  "lastHit" REAL,
  "cards" TEXT,
  "selector" TEXT,
  "projection" TEXT,
  "errorMessages" TEXT,
  "errors" TEXT,
  "debug" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT
);
CREATE INDEX IF NOT EXISTS "wekan_sessiondata_userId" ON "sessiondata"("userId");

-- settings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "settings" (
  "disableRegistration" INTEGER,
  "disableForgotPassword" INTEGER,
  "renderLinksAsPlainText" INTEGER,
  "alwaysShowCodeAsText" INTEGER,
  "disableActivities" INTEGER,
  "disableNotifications" INTEGER,
  "disableWatch" INTEGER,
  "enablePermanentDelete" INTEGER,
  "disableAllExport" INTEGER,
  "disableAllImport" INTEGER,
  "disableExportAvatars" INTEGER,
  "disableImportAvatars" INTEGER,
  "anonymizeExportUsers" INTEGER,
  "anonymizeImportUsers" INTEGER,
  "mailServer" TEXT,
  "productName" TEXT,
  "themeColor" TEXT,
  "themeCustomColors" TEXT,
  "displayAuthenticationMethod" INTEGER,
  "defaultAuthenticationMethod" TEXT,
  "spinnerName" TEXT,
  "hideLogo" INTEGER,
  "hideCardCounterList" INTEGER,
  "cardsLoading" TEXT,
  "hideBoardMemberList" INTEGER,
  "hideBoardActivitiesOnAllBoards" INTEGER,
  "customLoginLogoImageUrl" TEXT,
  "customLoginLogoLinkUrl" TEXT,
  "customHelpLinkUrl" TEXT,
  "textBelowCustomLoginLogo" TEXT,
  "automaticLinkedUrlSchemes" TEXT,
  "customTopLeftCornerLogoImageUrl" TEXT,
  "customTopLeftCornerLogoLinkUrl" TEXT,
  "customTopLeftCornerLogoHeight" TEXT,
  "oidcBtnText" TEXT,
  "mailDomainName" TEXT,
  "legalNotice" TEXT,
  "customHeadEnabled" INTEGER,
  "customHeadMetaTags" TEXT,
  "customHeadLinkTags" TEXT,
  "customManifestEnabled" INTEGER,
  "customManifestContent" TEXT,
  "customAssetLinksEnabled" INTEGER,
  "customAssetLinksContent" TEXT,
  "accessibilityPageEnabled" INTEGER,
  "accessibilityTitle" TEXT,
  "accessibilityContent" TEXT,
  "supportPopupText" TEXT,
  "supportPageEnabled" INTEGER,
  "supportPagePublic" INTEGER,
  "boardMembersFromSameOrgOnly" INTEGER,
  "boardMembersFromSameTeamOnly" INTEGER,
  "boardMembersFromSameOrgOrTeamOnly" INTEGER,
  "supportTitle" TEXT,
  "supportPageText" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);

-- swimlanes.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "swimlanes" (
  "title" TEXT,
  "archived" INTEGER,
  "archivedAt" TEXT,
  "boardId" TEXT,
  "createdAt" TEXT,
  "sort" REAL,
  "color" TEXT,
  "updatedAt" TEXT,
  "modifiedAt" TEXT,
  "type" TEXT,
  "height" REAL,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_swimlanes_boardId" ON "swimlanes"("boardId");

-- tableVisibilityModeSettings.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "tableVisibilityModeSettings" (
  "_id" TEXT UNIQUE,
  "booleanValue" INTEGER,
  "sort" REAL,
  "createdAt" TEXT,
  "modifiedAt" TEXT
);

-- team.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "team" (
  "teamDisplayName" TEXT,
  "teamDesc" TEXT,
  "teamShortName" TEXT,
  "teamWebsite" TEXT,
  "teamIsActive" INTEGER,
  "teamSharedTemplates" INTEGER,
  "teamPropagateMembersToBoards" INTEGER,
  "teamSyncMembersFromAuth" INTEGER,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "orgId" TEXT,
  "workspaceId" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_team_orgId" ON "team"("orgId");

-- textMigrationStatus.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "text_migration_status" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- translation.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "translation" (
  "language" TEXT,
  "text" TEXT,
  "translationText" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);

-- trelloImportJobs.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "trello_import_jobs" (
  "document_json" TEXT,
  "_id" TEXT UNIQUE
);

-- triggers.js: schemaless: no SimpleSchema declaration in uploaded file
CREATE TABLE IF NOT EXISTS "triggers" (
  "document_json" TEXT,
  "createdAt" TEXT,
  "updatedAt" TEXT,
  "desc" TEXT,
  "fromId" TEXT,
  "toId" TEXT,
  "labelIds" TEXT,
  "_id" TEXT UNIQUE
);

-- unsavedEdits.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "unsaved-edits" (
  "fieldName" TEXT,
  "docId" TEXT,
  "value" TEXT,
  "userId" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_unsaved_edits_userId" ON "unsaved-edits"("userId");

-- userPositionHistory.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "userPositionHistory" (
  "userId" TEXT,
  "boardId" TEXT,
  "entityType" TEXT,
  "entityId" TEXT,
  "actionType" TEXT,
  "previousState" TEXT,
  "newState" TEXT,
  "previousSort" REAL,
  "newSort" REAL,
  "previousSwimlaneId" TEXT,
  "newSwimlaneId" TEXT,
  "previousListId" TEXT,
  "newListId" TEXT,
  "previousBoardId" TEXT,
  "newBoardId" TEXT,
  "createdAt" TEXT,
  "isCheckpoint" INTEGER,
  "checkpointName" TEXT,
  "batchId" TEXT,
  "undone" INTEGER,
  "undoneAt" TEXT,
  "_id" TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS "wekan_userPositionHistory_userId" ON "userPositionHistory"("userId");
CREATE INDEX IF NOT EXISTS "wekan_userPositionHistory_boardId" ON "userPositionHistory"("boardId");

-- users.js: declared SimpleSchema
CREATE TABLE IF NOT EXISTS "users" (
  "username" TEXT,
  "orgs" TEXT,
  "teams" TEXT,
  "emails" TEXT,
  "createdAt" TEXT,
  "modifiedAt" TEXT,
  "profile" TEXT,
  "services" TEXT,
  "heartbeat" TEXT,
  "isAdmin" INTEGER,
  "createdThroughApi" INTEGER,
  "loginDisabled" INTEGER,
  "authenticationMethod" TEXT,
  "sessionData" TEXT,
  "importUsernames" TEXT,
  "lastConnectionDate" TEXT,
  "_id" TEXT UNIQUE
);

-- (game extension): explicit game extension; absent from uploaded models.zip
CREATE TABLE IF NOT EXISTS "workspaces" (
  "_id" TEXT UNIQUE,
  "orgId" TEXT,
  "floorId" TEXT,
  "name" TEXT,
  "title" TEXT,
  "room_number" TEXT,
  "floor" REAL,
  "slot_index" INTEGER,
  "deleted" INTEGER,
  "in_pocket" INTEGER,
  "position" TEXT,
  "document_json" TEXT
);
CREATE INDEX IF NOT EXISTS "wekan_workspaces_orgId" ON "workspaces"("orgId");

CREATE TABLE IF NOT EXISTS model_translations (collection TEXT NOT NULL, document_id TEXT NOT NULL, field TEXT NOT NULL, language TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(collection, document_id, field, language));
CREATE TABLE IF NOT EXISTS game_model_projection (collection TEXT NOT NULL, document_id TEXT NOT NULL, PRIMARY KEY(collection, document_id));
