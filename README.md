# Kanban Office — Työn talo

Suomen- ja englanninkielinen, muokattava 3D-toimistopeli **Redot 26.2** -pelimoottorille. Neljä kerrosta, 16 toimistoa, 64 eri aiheista kanban-taulua ja aluksi 1 024 nelirivistä korttia. Grafiikka, hahmot ja kalusteet tuotetaan projektin mukana tulevasta lähdekoodista. Erillisiä aineistopaketteja tai lisäosia ei tarvita.

## Käynnistys

1. Pura ZIP kokonaan omaan kansioon.
2. Avaa [Redot](https://redotengine.org/) ja valitse **Import / Tuo**.
3. Valitse `redot_kanban_office/project.godot` ja avaa projekti.
4. Käynnistä peli **F6 sijasta F5:llä** (Run Project).

Komentoriviltä: `redot --path /polku/redot_kanban_office --editor`, tai suoraan peliin `redot --path /polku/redot_kanban_office`.

Projekti käyttää Compatibility-renderöintiä (OpenGL). ZIP on täydellinen lähdeprojekti; siihen ei sisälly Redot-editoria tai valmiiksi vietyä Windows/Linux-pelitiedostoa. Tavallinen Redot-versio riittää; .NET-versiota ei tarvita.

## Ohjaus

| Toiminto | Näppäimistö ja hiiri | USB-peliohjain |
|---|---|---|
| Kävele eteen / taakse | Nuoli ylös / alas tai W / S | Vasen sauva tai ristiohjain ylös / alas |
| Käänny | Nuoli vasemmalle / oikealle | Oikea sauva tai ristiohjain vasen / oikea |
| Liiku sivuttain | A / D | Vasen sauva |
| Katso ympärille | Oikea hiiripainike pohjassa + hiiri; Page Up / Down | Oikea sauva |
| Juokse | Shift | Vasemman sauvan painallus |
| Avaa taulu / keskustele / aseta kannettu kortti | E / Enter | A (alapainike) |
| Siirrä tähdätty kortti taskuun | P | X (vasen painike) |
| Avaa tasku | I / Tab tai yläpalkin taskupainike | Y (yläpainike) |
| Sulje näkymä / jätä kannettu kortti taskuun | Esc | B (oikea painike) |
| Ohjeet | F1 tai keskustelu respassa | Keskustelu respassa |
| Valitse näkymän painikkeita | Tab, nuolinäppäimet, Enter | Ristiohjain, A |
| Vaihda kieli | Yläkulman Suomi / English | Kohdista kielipainikkeeseen ja paina A |

Peliohjain käyttää Redotin tunnistamia tavallisia USB/SDL-ohjainmäärityksiä. Painikkeiden kirjaimet yllä ovat Xbox-tyyliset; vastaavat PlayStation-/muut painikkeet määräytyvät fyysisen sijainnin mukaan. Fyysistä USB-ohjainta ei ollut käytettävissä kehitysympäristössä; automaattiset testit tarkistavat syötteiden määritykset.

## Pelaaminen

Aloitat ensimmäisestä kerroksesta kasvot vastaanottoon päin. Aino ja Maya vastaavat klikattavilla vastausvaihtoehdoilla peruskysymyksiin. Käytävä kulkee rakennuksen keskellä. Portaikko on käytävän perällä, vastaanotosta eteenpäin. Jokainen kerros sisältää neljä numeroitua toimistoa. Kerrosten välillä kuljetaan kävelemällä portaissa.

Jokaisen toimiston neljällä seinällä on oma taulu. Taulun rakenne on nimi, Swimlane 1, neljä vasemmalta oikealle kulkevaa listaa ja aluksi neljä korttia kussakin listassa. Jokainen kortti sisältää neljä tekstiriviä. Aiheet käsittelevät esimerkiksi auton rakentamista, kanban-ohjelmiston kehittämistä ja robotin kokoamista. Työtoverit keskustelevat aiheista puhekuplissa ja siirtävät oikeita kortteja huoneensa taulujen välillä. He väistävät pelaajaa.

### Kortin siirtäminen

- **Suoraan 3D-maailmassa:** osoita lähellä olevaa korttia, paina vasen hiiripainike, vedä toisen taulun haluttuun listaan ja vapauta. Hiiren osoitin määrää kohteen; peliohjaimella käytetään ruudun keskikohtaa.
- **Huoneesta toiseen:** klikkaa korttia kantaaksesi sitä tai paina P / X siirtääksesi sen taskuun. Avaa tasku, valitse kortti kannettavaksi, kävele toiseen huoneeseen ja klikkaa kohdelistaa tai paina A. Kannettu kortti on turvallisesti taskussa siihen asti, että asetat sen taululle.
- **Taulujen lähinäkymä:** avaa taulu E / A. Valitse saman huoneen taulut rinnakkaisiin näkymiin. Vedä kortteja listasta tai taulusta toiseen tai taskuun. Näkymässä on myös painikkeilla käytettävä siirtotapa.
- **Tasku:** yläpalkin taskupainike tai I / Y avaa koko ruudun sivutetun näkymän. Esc / B palauttaa peliin.

Siirtojen jälkeen listassa voi olla enemmän kuin neljä korttia. Seinän taulu näyttää ensimmäiset neljä ja ylimääräisten määrän; kaikki kortit saa esiin vieritettävässä lähinäkymässä. Työtoverien kortinsiirrot pysähtyvät lähinäkymän ajaksi.

## Pysyvä tallennus ja tietorakenne

Peli käyttää paikallista **SQLite-tietokantaa `officegame.sqlite`**. Se luodaan ensimmäisellä käynnistyksellä oletussisällöllä: rakennus, neljä kerrosta, työtilat, taulut, kortit, henkilöt, huonekalut ja kaksikieliset tekstit. Ensisijainen sijainti on vietävän peliohjelman vieressä; jos kansioon ei voi kirjoittaa, peli käyttää käyttöjärjestelmän Redot-käyttäjädatakansiota.

Tietokanta sisältää myös toimitettujen WeKan-mallien vastaavat tietueet, kortin päivämääräkentät sekä hakemiston kaikelle tekstille. Haku löytää esimerkiksi huoneen nimen, kerroksen, kortin tekstin, ihmisen nimen, tittelin, kysymyksen, vastauksen ja huonekalun nimen. Rakennus on organisaatio ja jokainen toimistohuone on työtila (`workspace`). Tarkka SQL-mappaus on `docs/DATABASE_MAPPING.md`.

### Tilojen ja esineiden muokkaus

Yläpalkin hallinta-avauksesta voi lisätä, nimetä, poistaa ja taskuttaa rakennuksia, kerroksia ja työtiloja. Kerroksen tai työtilan taskuttaminen säilyttää sen taulut, henkilöt ja esineet yhtenä kokonaisuutena; taskun sijoitusnäkymällä sen voi asettaa toiseen rakennukseen tai kerrokseen.

Esinepaneelissa voi lisätä ja käsitellä kalusteita, puita, ajoneuvoja, apuvälineitä, eläimiä, kukkia, teitä ja pöytäesineitä. Jokaisella on nimi, taskutoiminto ja poisto. Väri valitaan väriympyrästä ja leveys, korkeus sekä syvyys asetetaan erikseen. Henkilölle voi muuttaa nimen, ikäryhmän, tiimin, tittelin, osaamisen sekä kysymys–vastausparit. Muutokset tallennetaan aktiivisella kielellä tietokantaan.

Tallennus tehdään automaattisesti pelin aikana ja suljettaessa. Se ladataan seuraavalla käynnistyksellä. Aloituspaikka on aina vastaanoton edessä, mutta maailman muokkaukset, kortit ja pelitilastot säilyvät.

## Projektin rakenne

| Hakemisto / tiedosto | Sisältö |
|---|---|
| `project.godot`, `scenes/main.tscn` | Redot-projekti ja aloituskohtaus |
| `scripts/main.gd` | Osien yhdistäminen, vuorovaikutus, automaattitallennus |
| `scripts/core/` | Kaksikielinen aineisto, tilagraafi, SQLite-tallennus ja hakemisto |
| `scripts/world/` | Rakennus, kalusteet, portaat, ulkomaisema |
| `scripts/actors/` | Pelaaja, ohjaus ja toimistohahmot |
| `scripts/kanban/` | 3D-taulujen piirtäminen ja kohdistaminen |
| `scripts/ui/` | Yläpalkki, haku, tasku, taulunäkymät, muokkaimet ja tilahallinta |
| `tests/` | Toiminnalliset automaattitestit |
| `docs/` | Arkkitehtuuri, testiraportti ja englanninkieliset ohjeet |
| `ROADMAP.md` | Työpaketit, eteneminen ja valmius |

## Lisenssi

Projektin alkuperäinen lähdekoodi ja ohjelmallisesti luotu aineisto: MIT, katso `LICENSE`. Redot-moottori on erillinen ohjelmisto omine lisensseineen. Projekti ei sisällä kaupallisia aineistoja, seurantaa tai verkkopalveluriippuvuutta.
