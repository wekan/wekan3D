# SQLite-tietomalli ja models.zip-vastaavuus

`officegame.sqlite` on oikea SQLite-tietokanta. Peli tallentaa koko pelitilan ja WeKan-mallien vastaavat kentät samassa atomisessa transaktiossa. Kortit, taulut, listat ja uimaradat ovat samoissa SQL-tauluissa kuin pelin omat tietueet; mallikentät eivät jää tyhjiksi rinnakkaistauluiksi.

## Aineisto ja kattavuus

Käyttäjän toimittaman `models.zip`-aineiston kaikki 65 JavaScript-tiedostoa on analysoitu suorittamatta niiden JavaScript-koodia. Aineisto määrittelee 49 Mongo-/FilesCollection-kokoelmaa. Pelilaajennus `workspaces` lisää yhden SQL-taulun. Kuvaus sisältää 873 kenttämääritystä, joista 626 on juuritason SQL-sarakkeita; sisäkkäiset polut säilyvät JSON-rakenteiden kenttäkuvauksina. Näihin lukuihin sisältyvät selvästi merkityt pelilaajennukset.

- `data/wekan_schema.json`: täydellinen koneellisesti luettava kenttäluettelo, alkuperäiset nimet, tyypit, sisäkkäiset polut, optional/default/allowedValues/min/max/regEx/blackbox-tiedot, lähderivit ja kaikkien 65 tiedoston SHA-256-tunnisteet.
- `data/wekan_schema.sql`: itsenäisen lähdemallin CREATE TABLE- ja indeksilauseet. Tiedostoa ei tarvitse ajaa käsin.
- `scripts/core/wekan_schema.gd`: idempotentti `ensure_tables(db)` ja todellista pelitilaa kirjoittava `sync_snapshot(db,snapshot)`. Tallennuskerros omistaa transaktion ja palauttaa virheessä edellisen ehjän tallennuksen.
- `tools/generate_schema.py`: riippuvuudeton Python-generaattori. Syötteenä annetaan alkuperäisen arkiston purettu models-kansio; kolmannen osapuolen lähdekoodia ei tarvitse liittää peliin.

## Tyyppimuunnokset

| JavaScript / SimpleSchema | SQLite | Säilytys |
|---|---|---|
| String | TEXT | Alkuperäinen Unicode-teksti |
| Boolean | INTEGER | 0 tai 1 |
| Date | TEXT | Päivä/aika ISO 8601 -tekstinä |
| Number | REAL | SQLite-numerokenttä |
| Array | TEXT | JSON-taulukko; elementtimääritykset kuvaustiedostossa |
| Object / sisäkkäinen SimpleSchema | TEXT | JSON-objekti; kaikki pistepolut kuvaustiedostossa |
| Match.OneOf | TEXT / sisältävän rakenteen JSON | Alkuperäinen tyyppilauseke säilytetään; arvoa ei pakoteta väärään tyyppiin |

Alkuperäisten kenttien camelCase-nimet säilyvät (`boardId`, `swimlaneId`, `listId`, `dueAt`, `spentTime` jne.). `_id` on yksilöllinen mallin tunniste; pelitaulujen olemassa oleva `id` ja omistusrakenteen avaimet säilyvät. Upstreamin `optional`, `autoValue` ja palvelinkoodin validointi eivät muutu arvaamalla SQL NOT NULL -rajoitteiksi. Dynaamisia oletuksia tai importoitujen moduulien symboleja ei suoriteta eikä keksitä: kuvaustiedosto merkitsee ne dynaamisiksi/symbolisiksi. Pelin omat voimassa olevat viite- ja yksilöllisyysrajoitteet ovat edelleen käytössä.

## Organisaatio, rakennus ja työtila

| Pelissä | Todellinen SQL-esitys | Yhteys |
|---|---|---|
| Organisaatio | `organizations` pelitietue + alkuperäinen `org`-malli | Yksi organisaatio omistaa toimistorakennuksen; nimi tallentuu `org.orgDisplayName`-kenttään |
| Toimistohuone / työtila | `rooms` pelitietue + `workspaces` | Yksi `workspaces`-rivi jokaista huonetta kohti; `_id` on huoneen workspace_id |
| Työtilan rakennus | `workspaces.orgId` | Organisaation tunniste |
| Huoneen nimi, numero ja kerros | `workspaces.name`, `title`, `room_number`, `floor`, `position` | Todelliset huonetiedot; koko tietue lisäksi `document_json` |
| Taulun työtila | `boards.workspaceId` | Nykyinen huone; tyhjä taskussa olevalle taululle |
| Taulun organisaatio | `boards.orgIds` ja alkuperäinen `boards.orgs` | JSON-organisaatiotunnisteet; alkuperäinen orgs-rakenne säilyy |
| Henkilö | `entities` + alkuperäinen `users`-malli | Keksitty nimi `users.profile.fullname`, sijainti/profiilitiedot JSON-objektissa; kirjautuminen pois käytöstä |
| Huonekalu | `entities` | Nimi, kuvaus, huone, kerros, sijainti ja muut ominaisuudet säilyvät |

`workspaces` sekä `boards.workspaceId` ja `boards.orgIds` ovat käyttäjän pyytämää pelilaajennusta. Niitä ei esitetä arkistosta löydettyinä WeKan-kenttinä. Kaikki laajennukset on merkitty JSON-kuvaukseen.

## Muuttuva sisältö ja kaksi kieltä

Kortin yhteiset ominaisuudet tulevat `details`-rakenteesta. Aktiivisen kielen tekstiarvot tulevat `localized_details.fi`- tai `.en`-rakenteesta. `cards.title` ja `cards.description` sisältävät koko tekstin, eivät pelkän lyhyen nelirivisen 3D-esikatselun. Jos täydellisiä tekstejä ei vielä ole, esikatselurivit toimivat varatietona. `boardId`, `swimlaneId`, `listId` ja `sort` lasketaan aina todellisesta `card_locations`-omistusrakenteesta viimeiseksi, joten kortin siirto ei jätä SQL-kenttiin vanhaa sijaintia.

Molempien kielten nimet ja kuvaukset tallentuvat myös tauluun:

```sql
model_translations(collection, document_id, field, language, value)
```

Sen pääavain on kaikkien neljän ensimmäisen kentän yhdistelmä. Aktiivisen kielen vaihtaminen ei hävitä toisen kielen arvoja. Taulut, listat, uimaradat, työtilat, organisaatiot, henkilöt sekä kortit ja niiden liitännäistietueet saavat käännösrivit saatavilla olevista teksteistä.

`card.related[collection]`-liitännäistietueet projisoidaan vastaaviin lähdemallin tauluihin, esimerkiksi `card_comments`, `checklists`, `checklistItems`, `attachments` ja `customFields`. Jaetut kentät ja aktiivisen kielen tekstit yhdistetään. Pelin kirjoittamat lähdemallirivit kirjataan `game_model_projection`-rekisteriin, jotta poistettu kommentti tai muu tietue poistuu seuraavassa tallennuksessa myös oikeasta SQL-taulusta. Rekisteri ei poista muiden sovellusten lisäämiä, pelin ulkopuolisia tietueita.

Taskussa olevilla irtokorteilla ei ole keksittyä taulua/listaa: lähdekentät ovat NULL. Kokonaisena taskuun otettu taulu säilyttää korttiensa todellisen boardId-yhteyden ja pelin omistusrakenne kertoo, että taulu on taskussa. Taskulistojen ja -uimaratojen sisältö säilyy kokonaisena.

Lähdemallien loogiset suhteet ja hakua palvelevat indeksit ovat kuvauksessa. Ulkopuolisiin puuttuviin käyttäjiin tai muihin tuomattomiin WeKan-tietueisiin ei lisätä virheellisiä pakollisia vierasavaimia. Tämä on pelin tietomalli ja kenttävastaavuus; se ei suorita Meteorin palvelinmetodeja, käyttöoikeussääntöjä, tiedostopalvelua tai sähköpostitoimintoja.

## SQL-esimerkit

```sql
-- Kortin oikea sijainti ja huone:
SELECT c._id, c.title, c.boardId, c.swimlaneId, c.listId,
       w.name AS room_name, w.room_number, w.floor
FROM cards AS c
LEFT JOIN boards AS b ON b._id = c.boardId
LEFT JOIN workspaces AS w ON w._id = b.workspaceId;

-- Organisaatioiden toimistot:
SELECT o.orgDisplayName, w.name, w.room_number, w.floor
FROM workspaces AS w
LEFT JOIN org AS o ON o._id = w.orgId;

-- Korttien suomenkieliset täydelliset kuvaukset:
SELECT document_id, value
FROM model_translations
WHERE collection = 'cards' AND field = 'description' AND language = 'fi';
```

Pelin latauksessa kokonaiset JSON-pelitietueet ja validoitu omistusgraafi ovat auktoritatiivisia; lähdemallikentät ovat niiden atomisesti tallennettu, kyseltävä esitys. Pelin editori päivittää molemmat. Pelkän SQL-projektiosarakkeen muokkaaminen ulkoisella ohjelmalla ei automaattisesti korvaa pelin kokonaisia JSON-tietueita.

## Jokaisen lähdekokoelman vastaavuus

`JSON-polut` tarkoittaa sisäkkäisiä pistepolkuja saman juurisarakkeen JSON-sisällössä. Skeemattomissa malleissa `document_json` säilyttää avoimen dokumentin; erikseen havaitut ominaisuudet on merkitty päätellyiksi, eikä niitä väitetä upstreamin validoiduksi SimpleSchemaksi.

| Lähdetiedosto | SQL-taulu | SQL-sarakkeita | JSON-polkuja | Perusta |
|---|---|---:|---:|---|
| `accessibilitySettings.js` | `accessibilitySettings` | 6 | 0 | SimpleSchema |
| `accountSettings.js` | `accountSettings` | 5 | 0 | SimpleSchema |
| `actions.js` | `actions` | 5 | 0 | Skeematon kokoelma; avoin JSON |
| `activities.js` | `activities` | 20 | 0 | Skeematon kokoelma; avoin JSON |
| `announcements.js` | `announcements` | 7 | 0 | SimpleSchema |
| `attachmentBulkMoveStatus.js` | `attachmentBulkMoveStatus` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `attachmentMigrationStatus.js` | `attachmentMigrationStatus` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `attachmentStorageSettings.js` | `attachmentStorageSettings` | 10 | 28 | SimpleSchema |
| `attachments.js` | `attachments` | 4 | 0 | Skeematon kokoelma; avoin JSON |
| `avatars.js` | `avatars` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `boards.js` | `boards` | 97 | 31 | SimpleSchema |
| `cardCommentReactions.js` | `card_comment_reactions` | 5 | 4 | SimpleSchema |
| `cardComments.js` | `card_comments` | 8 | 0 | SimpleSchema |
| `cards.js` | `cards` | 55 | 61 | SimpleSchema |
| `changeHistory.js` | `changeHistory` | 22 | 0 | SimpleSchema |
| `checklistItems.js` | `checklistItems` | 9 | 0 | SimpleSchema |
| `checklists.js` | `checklists` | 11 | 0 | SimpleSchema |
| `counters.js` | `counters` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `customFields.js` | `customFields` | 12 | 8 | SimpleSchema |
| `eventLog.js` | `eventlog` | 26 | 0 | SimpleSchema |
| `eventLog.js` | `eventlogAcks` | 3 | 0 | SimpleSchema |
| `fileIntegrity.js` | `fileIntegrity` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `fileIntegrity.js` | `fileIntegrityKeys` | 2 | 0 | Skeematon kokoelma; avoin JSON |
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
| `presences.js` | `presences` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `recoveryEvents.js` | `recoveryEvents` | 16 | 2 | SimpleSchema |
| `recoveryStatus.js` | `recoveryStatus` | 4 | 0 | Skeematon kokoelma; avoin JSON |
| `rules.js` | `rules` | 9 | 0 | SimpleSchema |
| `usersessiondata.js` | `sessiondata` | 14 | 6 | SimpleSchema |
| `settings.js` | `settings` | 58 | 12 | SimpleSchema |
| `swimlanes.js` | `swimlanes` | 12 | 0 | SimpleSchema |
| `tableVisibilityModeSettings.js` | `tableVisibilityModeSettings` | 5 | 0 | SimpleSchema |
| `team.js` | `team` | 11 | 0 | SimpleSchema |
| `textMigrationStatus.js` | `text_migration_status` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `translation.js` | `translation` | 6 | 0 | SimpleSchema |
| `trelloImportJobs.js` | `trello_import_jobs` | 2 | 0 | Skeematon kokoelma; avoin JSON |
| `triggers.js` | `triggers` | 8 | 0 | Skeematon kokoelma; avoin JSON |
| `unsavedEdits.js` | `unsaved-edits` | 7 | 0 | SimpleSchema |
| `userPositionHistory.js` | `userPositionHistory` | 22 | 0 | SimpleSchema |
| `users.js` | `users` | 17 | 87 | SimpleSchema |
| `(game extension)` | `workspaces` | 8 | 0 | Pelilaajennus |

## Tiedostot, joista ei tehdä erillistä taulua

Seuraavat tiedostot lisäävät toimintoja olemassa oleviin malleihin tai ovat import/export-/palvelinapureita. Ne on analysoitu, mutta ne eivät itse määrittele uutta kokoelmaa.

| Tiedosto | Merkitys |
|---|---|
| `attachments.server.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `avatars.server.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `csvCreator.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `export.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `exportExcel.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `exportExcelCard.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `exportPDF.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `exporter.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `fileValidation.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `import.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `importZip.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `jiraCreator.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `kanboardCreator.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `runOnServer.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `trelloCreator.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `watchable.js` | watchers-kenttien mixin: sisällytetty boards-, lists- ja cards-skeemoihin |
| `wekanCreator.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |
| `wekanmapper.js` | Apuri tai olemassa olevan mallin palvelin-/tuonti-/vientitoiminto |

## Todentaminen

```bash
python tools/generate_schema.py /polku/purettuihin/models
redot --headless --path . --script res://tests/wekan_schema_test.gd
redot --headless --path . --script res://tests/sqlite_test.gd
```

Generaattori ajaa tuotetun DDL:n kahdesti oikeaan muistissa olevaan SQLite-tietokantaan, tarkistaa jokaisen generoidun sarakkeen ja sisäkkäisen JSON-juuren sekä `PRAGMA integrity_check`-tuloksen. Redot-testi tarkistaa kaikki 626 saraketta ja sisäkkäiset juuret sekä todellisten korttien, listojen, uimaratojen, työtilojen, organisaatioiden, henkilöiden, kommenttien ja käännösten SQL-arvot. Mukana ovat siirto taskuun, nimen muokkaus, liitännäistietueen poisto, SQL-erikoismerkkejä sisältävä teksti, idempotentti skeemalisäys ja olemassa olevan tallennuksen avaaminen.
