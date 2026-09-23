extends RefCounted
## Fictional, bilingual staff expertise and scripted, topic-specific discussions.
## Each answer is grounded in the same work packages and acceptance criteria as
## that person's kanban boards. Roles never depend on a person's gender.

const Catalog = preload("res://scripts/core/catalog.gd")
static var _catalog = null

# [Finnish implementation role, English role, Finnish review role, English role]
const ROLE_TITLES = [
	["Ajoneuvosuunnittelija", "Vehicle designer", "Ajoneuvotestaaja", "Vehicle test engineer"],
	["Sovellusarkkitehti", "Application architect", "Ohjelmistotestaaja", "Software test engineer"],
	["Robotiikkainsinööri", "Robotics engineer", "Automaatioteknikko", "Automation technician"],
	["Verkkokauppakehittäjä", "E-commerce developer", "Palvelumuotoilija", "Service designer"],
	["Mobiilikehittäjä", "Mobile developer", "Mobiilitestaaja", "Mobile test engineer"],
	["Tietokanta-asiantuntija", "Database specialist", "Migraatioinsinööri", "Migration engineer"],
	["Pilviarkkitehti", "Cloud architect", "Ylläpitoinsinööri", "Site reliability engineer"],
	["Tapahtumatuottaja", "Event producer", "Tapahtumakoordinaattori", "Event coordinator"],
	["Polkupyörämekaanikko", "Bicycle mechanic", "Huoltoasiantuntija", "Service specialist"],
	["Energiasuunnittelija", "Energy designer", "Aurinkovoima-asiantuntija", "Solar energy specialist"],
	["Peliohjelmoija", "Game programmer", "Pelisuunnittelija", "Game designer"],
	["Verkkokehittäjä", "Web developer", "Saavutettavuusasiantuntija", "Accessibility specialist"],
	["Kahvilakonseptin kehittäjä", "Café concept developer", "Palveluvastaava", "Hospitality coordinator"],
	["Älykotikehittäjä", "Smart home developer", "Järjestelmäintegraattori", "Systems integrator"],
	["Avaruusjärjestelmäsuunnittelija", "Space systems designer", "Satelliittitestaaja", "Satellite test engineer"],
	["3D-tulostinasiantuntija", "3D printer specialist", "Mekaniikkatestaaja", "Mechanical test engineer"],
	["Kirjastojärjestelmäkehittäjä", "Library software developer", "Tietopalveluasiantuntija", "Information services specialist"],
	["Paikkatietokehittäjä", "Geospatial developer", "Reittialgoritmien tutkija", "Routing algorithms researcher"],
	["Mittausjärjestelmäsuunnittelija", "Measurement systems designer", "Ympäristödata-analyytikko", "Environmental data analyst"],
	["Verkkopelikehittäjä", "Multiplayer developer", "Palvelininsinööri", "Server engineer"],
	["Toimitilakoordinaattori", "Workplace coordinator", "Muuttosuunnittelija", "Relocation planner"],
	["Julkaisuinsinööri", "Release engineer", "Yhteisökoordinaattori", "Community coordinator"],
	["Mediatyönkulkujen kehittäjä", "Media workflow developer", "Videotuotannon asiantuntija", "Video production specialist"],
	["Äänituottaja", "Audio producer", "Podcast-toimittaja", "Podcast editor"],
	["Viljelysuunnittelija", "Growing systems planner", "Puutarha-asiantuntija", "Horticulture specialist"],
	["Sähköajoneuvokehittäjä", "Electric mobility developer", "Akkutestaaja", "Battery test engineer"],
	["Reseptipalvelun kehittäjä", "Recipe service developer", "Sisältösuunnittelija", "Content designer"],
	["Perehdytyssuunnittelija", "Onboarding designer", "Oppimisen asiantuntija", "Learning specialist"],
	["Automaatiosuunnittelija", "Automation designer", "Tuotantoteknikko", "Production technician"],
	["Energiadata-analyytikko", "Energy data analyst", "Mittauspalvelukehittäjä", "Metering service developer"],
	["Näyttelysuunnittelija", "Exhibition designer", "Museoteknologian asiantuntija", "Museum technology specialist"],
	["VR-kehittäjä", "VR developer", "Koulutussimulaatioiden testaaja", "Training simulation tester"],
	["Tallennuspalvelukehittäjä", "Storage service developer", "Tietoturvatestaaja", "Security test engineer"],
	["Editorikehittäjä", "Editor developer", "Tekstijärjestelmien testaaja", "Text systems tester"],
	["Lokalisointikoordinaattori", "Localization coordinator", "Kieliteknologian asiantuntija", "Language technology specialist"],
	["Verkkoinsinööri", "Network engineer", "Verkkopalveluiden testaaja", "Network services tester"],
	["Ääniohjelmoija", "Audio programmer", "Äänisynteesin suunnittelija", "Sound synthesis designer"],
	["Galleriapalvelun kehittäjä", "Gallery service developer", "Kuva-aineiston asiantuntija", "Image collection specialist"],
	["Varauspalvelukehittäjä", "Booking service developer", "Palveluprosessien testaaja", "Service process tester"],
	["Datavisualisoija", "Data visualization designer", "Kaupunkidata-analyytikko", "City data analyst"],
	["Lennokkisuunnittelija", "Drone designer", "Lennokkitestaaja", "Drone test engineer"],
	["Pakkaussuunnittelija", "Packaging designer", "Materiaaliasiantuntija", "Materials specialist"],
	["Viestipalvelukehittäjä", "Messaging service developer", "Protokollatestaaja", "Protocol test engineer"],
	["Vapaaehtoiskoordinaattori", "Volunteer coordinator", "Yhteisötoiminnan suunnittelija", "Community program planner"],
	["Kotipalvelinasiantuntija", "Home server specialist", "Ylläpitokehittäjä", "Operations developer"],
	["Oppimisympäristökehittäjä", "Learning platform developer", "Pedagoginen suunnittelija", "Instructional designer"],
	["Viljelyautomaatioinsinööri", "Growing automation engineer", "Vesiviljelyasiantuntija", "Hydroponics specialist"],
	["Animaatioteknologi", "Animation technologist", "Animaatiotuottaja", "Animation producer"],
	["Logistiikkajärjestelmäkehittäjä", "Logistics systems developer", "Varastoprosessien asiantuntija", "Warehouse process specialist"],
	["Design system -kehittäjä", "Design system developer", "Käyttöliittymäsuunnittelija", "Interface designer"],
	["Navigointialgoritmien kehittäjä", "Navigation algorithms developer", "Maastorobottitestaaja", "Rover test engineer"],
	["Yhteisöpuutarhan suunnittelija", "Community garden planner", "Puutarhakoordinaattori", "Garden coordinator"],
	["Havaittavuusinsinööri", "Observability engineer", "Lokidata-analyytikko", "Log data analyst"],
	["Karttasovelluskehittäjä", "Map application developer", "Opastuspalvelusuunnittelija", "Visitor guidance designer"],
	["Tietoturvaharjoitusten kehittäjä", "Security lab developer", "Tietoturvakouluttaja", "Security trainer"],
	["Tuotetietojärjestelmäkehittäjä", "Product information developer", "Varaosatiedon asiantuntija", "Parts information specialist"],
	["Virtuaalitilakehittäjä", "Virtual space developer", "3D-kokemussuunnittelija", "3D experience designer"],
	["Aineistoinsinööri", "Dataset engineer", "Aineiston laadun arvioija", "Dataset quality reviewer"],
	["Yhteistyövälinekehittäjä", "Collaboration tools developer", "Etätyöpalvelujen suunnittelija", "Remote work service designer"],
	["Sähkövenesuunnittelija", "Electric boat designer", "Venetekniikan testaaja", "Marine systems tester"],
	["Digitointiasiantuntija", "Digitization specialist", "Peliarkiston tutkija", "Game archive researcher"],
	["Kioskisovelluskehittäjä", "Kiosk application developer", "Asiointipalvelutestaaja", "Self-service systems tester"],
	["Tietomalliasiantuntija", "Building information specialist", "Digitaalisen kaksosen kehittäjä", "Digital twin developer"],
	["Kanban-toimiston kehittäjä", "Kanban Office developer", "Toimistopelin testaaja", "Office game tester"]
]


static func make_profile(spec: Dictionary) -> Dictionary:
	if bool(spec.get("receptionist", false)):
		return _reception_profile(spec)
	if _catalog == null:
		_catalog = Catalog.new()
	var topic_index = posmod(int(spec.get("topic", 0)), maxi(1, _catalog.count()))
	var subject: Dictionary = _catalog.topic(topic_index)
	var seed_value = _profile_seed(spec)
	var variant = posmod(int(spec.get("role_variant", seed_value)), 2)
	var titles: Array = ROLE_TITLES[posmod(topic_index, ROLE_TITLES.size())]
	var title = _pair(titles[variant * 2], titles[variant * 2 + 1])
	var parts: Array = subject.get("parts", [])
	if parts.is_empty():
		parts = [{"name": _pair("Työpaketti", "Work package"), "work": _pair("toteuta sovittu muutos", "implement the agreed change"), "accept": _pair("sovittu testi läpäistään", "the agreed test passes")}]
	var first: Dictionary = parts[posmod(seed_value, parts.size())]
	var second: Dictionary = parts[posmod(seed_value + 1, parts.size())]
	var profile = {
		"title": title,
		"team_role": _pair("Vastaa toteutuksesta ja työpakettien suunnittelusta." if variant == 0 else "Vastaa katselmoinnista ja hyväksymistestien tuloksista.", "Owns implementation and work-package planning." if variant == 0 else "Owns reviews and acceptance-test results."),
		"expertise": _pair("%s: %s ja %s." % [subject.title.fi, str(first.name.fi).to_lower(), str(second.name.fi).to_lower()], "%s: %s and %s." % [subject.title.en, str(first.name.en).to_lower(), str(second.name.en).to_lower()]),
		"qa": []
	}
	profile.qa.append(_qa("role", "Mistä työstä vastaat tässä tiimissä?", "What is your responsibility in this team?", "%s. Erikoisalani on %s. %s" % [title.fi, subject.title.fi, profile.team_role.fi], "%s. I specialize in %s. %s" % [title.en, str(subject.title.en).to_lower(), profile.team_role.en]))
	for offset in range(4):
		var part: Dictionary = parts[posmod(seed_value + offset, parts.size())]
		var part_fi = str(part.name.fi)
		var part_en = str(part.name.en)
		match offset:
			0:
				profile.qa.append(_qa("plan", "Mitä työpaketissa «%s» tehdään?" % part_fi, "What does the '%s' work package involve?" % part_en, "%s. Kirjaan korttiin hyväksymisehdon: %s." % [str(part.work.fi).capitalize(), part.accept.fi], "%s. I record this acceptance criterion on the card: %s." % [str(part.work.en).capitalize(), part.accept.en]))
			1:
				profile.qa.append(_qa("verify", "Miten tarkistat työpaketin «%s»?" % part_fi, "How do you check '%s'?" % part_en, "Testaan työpaketin ja tarkistan hyväksymisehdon: %s. Tallennan havainnon ja testituloksen korttiin, jotta toinen tiimiläinen voi toistaa tarkistuksen." % part.accept.fi, "I verify that %s. I record the observation and test result on the card so a colleague can repeat the check." % part.accept.en))
			2:
				profile.qa.append(_qa("blocker", "Mitä jos «%s» ei läpäise tarkistusta?" % part_fi, "What if '%s' fails its check?" % part_en, "Kortti jää keskeneräiseksi. Korjattava työ on: %s. Uusintatarkistuksen ehto on edelleen: %s." % [part.work.fi, part.accept.fi], "The card stays in progress. The work to correct is: %s. The repeat check must still meet this criterion: %s." % [part.work.en, part.accept.en]))
			_:
				profile.qa.append(_qa("handoff", "Milloin «%s» voidaan hyväksyä?" % part_fi, "When can '%s' be accepted?" % part_en, "Kun hyväksymisehto «%s» on todettu ja tulos kirjattu, pyydän työparia katselmoimaan kortin. Sen jälkeen siirrämme sen yhdessä valmiiksi." % part.accept.fi, "Once the acceptance criterion '%s' has been verified and recorded, I ask my colleague to review the card. Then we move it to Done together." % part.accept.en))
	profile.qa.append(_qa("next", "Mistä tiedät, mitä kannattaa tehdä seuraavaksi?", "How do you choose what to work on next?", "Katson aiheen «%s» taululta keskeneräiset kortit. Ensisijainen osaamisalueeni on «%s», ja sovin työparin kanssa riippuvuuksista ennen uuden kortin aloittamista." % [subject.title.fi, first.name.fi], "I check unfinished cards on the '%s' board. My main area is '%s', and I agree dependencies with my colleague before starting another card." % [subject.title.en, first.name.en]))
	return profile


static func _reception_profile(spec: Dictionary) -> Dictionary:
	var identity = str(spec.get("entity_id", spec.get("id", "")))
	var variant = posmod(_profile_seed(spec), 2)
	if not identity.is_empty() and identity.right(1).is_valid_int():
		variant = int(identity.right(1)) % 2
	return {
		"title": _pair("Vastaanottokoordinaattori" if variant == 0 else "Vierailupalvelujen asiantuntija", "Reception coordinator" if variant == 0 else "Visitor services specialist"),
		"team_role": _pair("Toivottaa vieraat tervetulleiksi ja neuvoo toimistojen sijainnit." if variant == 0 else "Opastaa Kanban-toimiston työtavoissa ja ohjauksessa.", "Welcomes visitors and helps them find offices." if variant == 0 else "Explains Kanban Office workflows and controls."),
		"expertise": _pair("Rakennusten ja huoneiden opastus, korttien kuljetus sekä näppäimistö- ja peliohjainkäyttö.", "Building and room directions, carrying cards, and keyboard or controller use."),
		"qa": [
			_qa("directions", "Mistä pääsen ylempiin kerroksiin?", "How do I reach the upper floors?", "Jatka keskikäytävää rakennuksen takaosaan. Siellä portaat yhdistävät kaikki neljä kerrosta. Kävele portaita pitkin nuolilla tai peliohjaimella.", "Follow the central corridor to the rear of the building. The stairs there connect all four floors. Walk up using the arrow keys or your controller."),
			_qa("rooms", "Missä työryhmien toimistot ovat?", "Where are the teams' offices?", "Toimistojen ovet ovat keskikäytävän molemmin puolin. Jokaisessa kerroksessa on neljä toimistoa. Huoneen numero ja nimi auttavat löytämään oikean tiimin.", "Office doors are on both sides of the central corridor. There are four offices on each floor. The room number and name help you find the right team."),
			_qa("carry", "Kuinka vien kortin toiseen huoneeseen?", "How do I take a card to another room?", "Laita kortti taskuun taulun näkymässä tai kohdista korttiin ja paina P. Kulje toiseen huoneeseen, avaa tasku ja valitse kortin sijoitus kohteen taululle.", "Put the card in your pocket from a board view, or target it and press P. Walk to another room, open your pocket, and choose to place the card on the destination board."),
			_qa("containers", "Voiko kokonaisen listan tai uimaradan siirtää?", "Can I move a complete list or swimlane?", "Kyllä. Taulun muokkausnäkymässä voit ottaa listan tai uimaradan taskuun kortteineen. Valitse sitten taskusta sisältö ja sijoita se toisen taulun sopivaan kohtaan.", "Yes. In the board editor you can put a list or swimlane in your pocket with its cards. Then select the item from your pocket and place it at a suitable location on another board."),
			_qa("controller", "Miten käytän USB-peliohjainta?", "How do I use a USB controller?", "Vasen tatti liikuttaa ja oikea katsoo ympärille. A avaa kohteen, Y avaa taskun ja B palaa takaisin. Voit myös liikkua ja kääntyä ristiohjaimella.", "The left stick moves and the right stick looks around. A opens a target, Y opens your pocket, and B goes back. The D-pad can also move and turn."),
			_qa("language", "Miten vaihdan kieltä tai kysyn apua?", "How do I change language or ask for help?", "Valitse suomi tai englanti yläkulman kielipainikkeesta. Klikkaa henkilön kohdalta keskustelu auki: voit valita hänen osaamiseensa liittyviä kysymyksiä.", "Choose Finnish or English with the language button in the upper corner. Open a conversation with a person to select questions about their expertise.")
		]
	}


static func _profile_seed(spec: Dictionary) -> int:
	var person_name = spec.get("name", "Alex")
	if person_name is Dictionary:
		person_name = person_name.get("fi", person_name.get("en", "Alex"))
	return posmod(hash(str(person_name) + "|" + str(spec.get("room_id", ""))), 2147483647)


static func _pair(fi: String, en: String) -> Dictionary:
	return {"fi": fi, "en": en}


static func _qa(identifier: String, question_fi: String, question_en: String, answer_fi: String, answer_en: String) -> Dictionary:
	return {"id": identifier, "question": _pair(question_fi, question_en), "answer": _pair(answer_fi, answer_en)}
