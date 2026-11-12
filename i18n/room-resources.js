/* Traduction d'affichage des quatre salles du gouvernement.
 * Un seul moteur i18next : réutilise les locales et le dictionnaire central.
 * Le nom source, roomId, navigation, état de porte et ordres restent inchangés.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const localized={
  "fr": {
    "bureaux": "Bureau du Président du Conseil du Peuple",
    "salle_conseil": "Salle du Conseil du Peuple",
    "salle_presse": "Salle de Presse",
    "archives_gouv": "Archives Gouvernementales"
  },
  "en": {
    "bureaux": "Office of the President of the People's Council",
    "salle_conseil": "People's Council Chamber",
    "salle_presse": "Press Room",
    "archives_gouv": "Government Archives"
  },
  "es": {
    "bureaux": "Despacho del Presidente del Consejo del Pueblo",
    "salle_conseil": "Sala del Consejo del Pueblo",
    "salle_presse": "Sala de prensa",
    "archives_gouv": "Archivos gubernamentales"
  },
  "zh-TW": {
    "bureaux": "人民委員會主席辦公室",
    "salle_conseil": "人民委員會會議廳",
    "salle_presse": "新聞發布室",
    "archives_gouv": "政府檔案室"
  },
  "ru": {
    "bureaux": "Кабинет председателя Совета народа",
    "salle_conseil": "Зал Совета народа",
    "salle_presse": "Пресс-зал",
    "archives_gouv": "Правительственный архив"
  },
  "ko": {
    "bureaux": "인민평의회 의장실",
    "salle_conseil": "인민평의회 회의실",
    "salle_presse": "기자회견실",
    "archives_gouv": "정부 기록보관소"
  },
  "ar": {
    "bureaux": "مكتب رئيس مجلس الشعب",
    "salle_conseil": "قاعة مجلس الشعب",
    "salle_presse": "قاعة الصحافة",
    "archives_gouv": "الأرشيف الحكومي"
  },
  "pt-BR": {
    "bureaux": "Gabinete do Presidente do Conselho do Povo",
    "salle_conseil": "Sala do Conselho do Povo",
    "salle_presse": "Sala de imprensa",
    "archives_gouv": "Arquivos governamentais"
  },
  "de": {
    "bureaux": "Büro des Vorsitzenden des Volksrats",
    "salle_conseil": "Saal des Volksrats",
    "salle_presse": "Presseraum",
    "archives_gouv": "Regierungsarchiv"
  }
};
 // Intitulés propres aux six ministères de Sovarka (autres empires inchangés).
 const ministries={
  "fr": {
    "bureau_min_int": "Bureau - Ministre de la Sécurité du Peuple",
    "bureau_min_fin": "Bureau - Ministre de l'Économie collective",
    "bureau_min_just": "Bureau - Ministre de la Justice prolétarienne",
    "bureau_min_def": "Bureau - Ministre de la Défense de la Patrie",
    "bureau_min_info": "Bureau - Ministre de la Vérité officielle",
    "bureau_min_ae": "Bureau - Ministre de l'Amitié entre les Peuples"
  },
  "en": {
    "bureau_min_int": "Office — Minister of People's Security",
    "bureau_min_fin": "Office — Minister of the Collective Economy",
    "bureau_min_just": "Office — Minister of Proletarian Justice",
    "bureau_min_def": "Office — Minister of Homeland Defence",
    "bureau_min_info": "Office — Minister of Official Truth",
    "bureau_min_ae": "Office — Minister of Friendship among Peoples"
  },
  "es": {
    "bureau_min_int": "Despacho — Ministro de Seguridad del Pueblo",
    "bureau_min_fin": "Despacho — Ministro de Economía Colectiva",
    "bureau_min_just": "Despacho — Ministro de Justicia Proletaria",
    "bureau_min_def": "Despacho — Ministro de Defensa de la Patria",
    "bureau_min_info": "Despacho — Ministro de la Verdad Oficial",
    "bureau_min_ae": "Despacho — Ministro de Amistad entre los Pueblos"
  },
  "zh-TW": {
    "bureau_min_int": "人民安全部長辦公室",
    "bureau_min_fin": "集體經濟部長辦公室",
    "bureau_min_just": "無產階級司法部長辦公室",
    "bureau_min_def": "祖國國防部長辦公室",
    "bureau_min_info": "官方真相部長辦公室",
    "bureau_min_ae": "民族友誼部長辦公室"
  },
  "ru": {
    "bureau_min_int": "Кабинет министра народной безопасности",
    "bureau_min_fin": "Кабинет министра коллективной экономики",
    "bureau_min_just": "Кабинет министра пролетарской юстиции",
    "bureau_min_def": "Кабинет министра обороны Родины",
    "bureau_min_info": "Кабинет министра официальной правды",
    "bureau_min_ae": "Кабинет министра дружбы народов"
  },
  "ko": {
    "bureau_min_int": "인민안전부 장관실",
    "bureau_min_fin": "집단경제부 장관실",
    "bureau_min_just": "프롤레타리아 사법부 장관실",
    "bureau_min_def": "조국방위부 장관실",
    "bureau_min_info": "공식 진실부 장관실",
    "bureau_min_ae": "민족 간 우호부 장관실"
  },
  "ar": {
    "bureau_min_int": "مكتب وزير أمن الشعب",
    "bureau_min_fin": "مكتب وزير الاقتصاد الجماعي",
    "bureau_min_just": "مكتب وزير العدالة البروليتارية",
    "bureau_min_def": "مكتب وزير الدفاع عن الوطن",
    "bureau_min_info": "مكتب وزير الحقيقة الرسمية",
    "bureau_min_ae": "مكتب وزير الصداقة بين الشعوب"
  },
  "pt-BR": {
    "bureau_min_int": "Gabinete — Ministro da Segurança do Povo",
    "bureau_min_fin": "Gabinete — Ministro da Economia Coletiva",
    "bureau_min_just": "Gabinete — Ministro da Justiça Proletária",
    "bureau_min_def": "Gabinete — Ministro da Defesa da Pátria",
    "bureau_min_info": "Gabinete — Ministro da Verdade Oficial",
    "bureau_min_ae": "Gabinete — Ministro da Amizade entre os Povos"
  },
  "de": {
    "bureau_min_int": "Büro — Minister für Volkssicherheit",
    "bureau_min_fin": "Büro — Minister für Kollektivwirtschaft",
    "bureau_min_just": "Büro — Minister für proletarische Justiz",
    "bureau_min_def": "Büro — Minister für Landesverteidigung",
    "bureau_min_info": "Büro — Minister für offizielle Wahrheit",
    "bureau_min_ae": "Büro — Minister für Völkerfreundschaft"
  }
};
 for(const [lang,labels] of Object.entries(ministries)) Object.assign(localized[lang],labels);
 // Mairies provinciales : uniquement les trois intitulés canoniques des gabarits.
 const mairie={
  "fr": {
    "accueil_mairie": "Accueil",
    "bureau_maire_local": "Bureau du Maire",
    "bureau_maire_adjoint": "Bureau du Maire Adjoint"
  },
  "en": {
    "accueil_mairie": "Reception",
    "bureau_maire_local": "Mayor's Office",
    "bureau_maire_adjoint": "Deputy Mayor's Office"
  },
  "es": {
    "accueil_mairie": "Recepción",
    "bureau_maire_local": "Despacho del alcalde",
    "bureau_maire_adjoint": "Despacho del teniente de alcalde"
  },
  "zh-TW": {
    "accueil_mairie": "接待處",
    "bureau_maire_local": "市長辦公室",
    "bureau_maire_adjoint": "副市長辦公室"
  },
  "ru": {
    "accueil_mairie": "Приёмная",
    "bureau_maire_local": "Кабинет мэра",
    "bureau_maire_adjoint": "Кабинет заместителя мэра"
  },
  "ko": {
    "accueil_mairie": "안내실",
    "bureau_maire_local": "시장실",
    "bureau_maire_adjoint": "부시장실"
  },
  "ar": {
    "accueil_mairie": "الاستقبال",
    "bureau_maire_local": "مكتب رئيس البلدية",
    "bureau_maire_adjoint": "مكتب نائب رئيس البلدية"
  },
  "pt-BR": {
    "accueil_mairie": "Recepção",
    "bureau_maire_local": "Gabinete do prefeito",
    "bureau_maire_adjoint": "Gabinete do vice-prefeito"
  },
  "de": {
    "accueil_mairie": "Empfang",
    "bureau_maire_local": "Büro des Bürgermeisters",
    "bureau_maire_adjoint": "Büro des stellvertretenden Bürgermeisters"
  }
};
 const governmentRoomIds=new Set(Object.keys(localized.fr));
 // Palais diplomatique de Novomirsk uniquement : noms des salles, jamais les
 // accès des ambassadeurs ou les décisions serveur.
 const embassies={
  "fr": {
   "accueil_ambassades_novomirsk": "Accueil du Palais des Ambassades",
   "salle_reception": "Salle de Réception",
   "bureau_republia_novomirsk": "Ambassade de Républia",
   "bureau_khalija_novomirsk": "Ambassade d'Al-Khalija",
   "bureau_estado_novomirsk": "Ambassade d'El Estado"
  },
  "en": {
   "accueil_ambassades_novomirsk": "Embassies Palace Reception",
   "salle_reception": "Reception Hall",
   "bureau_republia_novomirsk": "Embassy of Republia",
   "bureau_khalija_novomirsk": "Embassy of Al-Khalija",
   "bureau_estado_novomirsk": "Embassy of El Estado"
  },
  "es": {
   "accueil_ambassades_novomirsk": "Recepción del Palacio de las Embajadas",
   "salle_reception": "Sala de recepciones",
   "bureau_republia_novomirsk": "Embajada de Republia",
   "bureau_khalija_novomirsk": "Embajada de Al-Khalija",
   "bureau_estado_novomirsk": "Embajada de El Estado"
  },
  "zh-TW": {
   "accueil_ambassades_novomirsk": "大使館宮殿接待廳",
   "salle_reception": "外交接待廳",
   "bureau_republia_novomirsk": "雷普布利亞大使館",
   "bureau_khalija_novomirsk": "哈利賈大使館",
   "bureau_estado_novomirsk": "埃爾埃斯塔多大使館"
  },
  "ru": {
   "accueil_ambassades_novomirsk": "Приёмная Дворца посольств",
   "salle_reception": "Зал приёмов",
   "bureau_republia_novomirsk": "Посольство Републии",
   "bureau_khalija_novomirsk": "Посольство Аль-Халиджи",
   "bureau_estado_novomirsk": "Посольство Эль-Эстадо"
  },
  "ko": {
   "accueil_ambassades_novomirsk": "대사관 궁전 안내실",
   "salle_reception": "외교 연회장",
   "bureau_republia_novomirsk": "레푸블리아 대사관",
   "bureau_khalija_novomirsk": "알 칼리자 대사관",
   "bureau_estado_novomirsk": "엘 에스타도 대사관"
  },
  "ar": {
   "accueil_ambassades_novomirsk": "استقبال قصر السفارات",
   "salle_reception": "قاعة الاستقبال الدبلوماسي",
   "bureau_republia_novomirsk": "سفارة ريبوبليا",
   "bureau_khalija_novomirsk": "سفارة الخليج",
   "bureau_estado_novomirsk": "سفارة إل إستادو"
  },
  "pt-BR": {
   "accueil_ambassades_novomirsk": "Recepção do Palácio das Embaixadas",
   "salle_reception": "Salão de recepções",
   "bureau_republia_novomirsk": "Embaixada de Republia",
   "bureau_khalija_novomirsk": "Embaixada de Al-Khalija",
   "bureau_estado_novomirsk": "Embaixada de El Estado"
  },
  "de": {
   "accueil_ambassades_novomirsk": "Empfang im Botschaftspalast",
   "salle_reception": "Empfangssaal",
   "bureau_republia_novomirsk": "Botschaft von Republia",
   "bureau_khalija_novomirsk": "Botschaft von Al-Khalija",
   "bureau_estado_novomirsk": "Botschaft von El Estado"
  }
 };
 // Armurerie partagée : seul « Magasin » est traduit, sans changer le fournisseur.
 const armory={
  "fr":{"magasin":"Magasin"},
  "en":{"magasin":"Gun shop"},
  "es":{"magasin":"Armería"},
  "zh-TW":{"magasin":"槍械商店"},
  "ru":{"magasin":"Оружейный магазин"},
  "ko":{"magasin":"총포점"},
  "ar":{"magasin":"متجر الأسلحة"},
  "pt-BR":{"magasin":"Loja de armas"},
  "de":{"magasin":"Waffengeschäft"}
 };
 for(const [locale,labels] of Object.entries(armory)) Object.assign(localized[locale],labels);
 // Accès civiques ordinaires : traduire seulement les noms sources exacts,
 // jamais la destination, le rôle ou les droits des visiteurs.
 const everyday={
  "fr":{"accueil_police":"Accueil","prison":"Cellules de garde a vue",
   "bureau_commissaire":"Bureau du Commissaire","marche_ext":"Etals du marche"},
  "en":{"accueil_police":"Police reception","prison":"Holding cells",
   "bureau_commissaire":"Police Commissioner's Office","marche_ext":"Market stalls"},
  "es":{"accueil_police":"Recepción de la comisaría","prison":"Calabozos",
   "bureau_commissaire":"Despacho del comisario","marche_ext":"Puestos del mercado"},
  "zh-TW":{"accueil_police":"警察局接待處","prison":"拘留室",
   "bureau_commissaire":"警察局長辦公室","marche_ext":"市場攤位"},
  "ru":{"accueil_police":"Приёмная полиции","prison":"Камеры предварительного задержания",
   "bureau_commissaire":"Кабинет комиссара полиции","marche_ext":"Торговые ряды"},
  "ko":{"accueil_police":"경찰서 접수처","prison":"유치장",
   "bureau_commissaire":"경찰서장실","marche_ext":"시장 가판대"},
  "ar":{"accueil_police":"استقبال مركز الشرطة","prison":"زنازين الاحتجاز",
   "bureau_commissaire":"مكتب مفوض الشرطة","marche_ext":"أكشاك السوق"},
  "pt-BR":{"accueil_police":"Recepção da delegacia","prison":"Celas de detenção",
   "bureau_commissaire":"Gabinete do delegado","marche_ext":"Bancas do mercado"},
  "de":{"accueil_police":"Empfang der Polizeiwache","prison":"Gewahrsamszellen",
   "bureau_commissaire":"Büro des Polizeikommissars","marche_ext":"Marktstände"}
 };
 for(const [locale,labels] of Object.entries(everyday)) Object.assign(localized[locale],labels);
 // Noms historiques de l'hôtel, des banques, de l'office notarial et de l'université.
 // Surcharges de texte uniquement sur correspondance exacte salle + bâtiment.
 const serviceRooms={
  "fr": {
   "accueil": "Accueil",
   "restaurant": "Salle du Restaurant",
   "bar": "Bar",
   "chambres": "Chambres",
   "suite_privee": "Suite Privée — Local à louer",
   "suite_presidentielle": "Suite Présidentielle — Local à louer",
   "accueil_banque": "Accueil",
   "coffre_privatif": "Coffre Privatif — Local à louer",
   "bureau_prive": "Bureau prive",
   "accueil_notaire": "Accueil",
   "bureau_successions": "Bureau des Successions",
   "bureau_contrats": "Bureau des Contrats",
   "archives_notariales": "Archives Notariales",
   "amphi": "Amphitheatre",
   "salle_reunion": "Salle de Réunion"
  },
  "en": {
   "accueil": "Reception",
   "restaurant": "Restaurant Dining Room",
   "bar": "Bar",
   "chambres": "Guest Rooms",
   "suite_privee": "Private Suite — Available to rent",
   "suite_presidentielle": "Presidential Suite — Available to rent",
   "accueil_banque": "Bank Reception",
   "coffre_privatif": "Private Safe — Available to rent",
   "bureau_prive": "Private Office",
   "accueil_notaire": "Notary Reception",
   "bureau_successions": "Inheritance Office",
   "bureau_contrats": "Contracts Office",
   "archives_notariales": "Notarial Archives",
   "amphi": "Lecture Hall",
   "salle_reunion": "Meeting Room"
  },
  "es": {
   "accueil": "Recepción",
   "restaurant": "Sala del restaurante",
   "bar": "Bar",
   "chambres": "Habitaciones",
   "suite_privee": "Suite privada — Disponible para alquilar",
   "suite_presidentielle": "Suite presidencial — Disponible para alquilar",
   "accueil_banque": "Recepción del banco",
   "coffre_privatif": "Caja fuerte privada — Disponible para alquilar",
   "bureau_prive": "Despacho privado",
   "accueil_notaire": "Recepción de la notaría",
   "bureau_successions": "Despacho de sucesiones",
   "bureau_contrats": "Despacho de contratos",
   "archives_notariales": "Archivos notariales",
   "amphi": "Anfiteatro",
   "salle_reunion": "Sala de reuniones"
  },
  "zh-TW": {
   "accueil": "接待處",
   "restaurant": "餐廳用餐區",
   "bar": "酒吧",
   "chambres": "客房",
   "suite_privee": "私人套房—可租賃",
   "suite_presidentielle": "總統套房—可租賃",
   "accueil_banque": "銀行接待處",
   "coffre_privatif": "私人保險箱—可租賃",
   "bureau_prive": "私人辦公室",
   "accueil_notaire": "公證處接待處",
   "bureau_successions": "繼承事務辦公室",
   "bureau_contrats": "合約事務辦公室",
   "archives_notariales": "公證檔案室",
   "amphi": "階梯講堂",
   "salle_reunion": "會議室"
  },
  "ru": {
   "accueil": "Приёмная",
   "restaurant": "Ресторанный зал",
   "bar": "Бар",
   "chambres": "Номера",
   "suite_privee": "Частный люкс — сдаётся в аренду",
   "suite_presidentielle": "Президентский люкс — сдаётся в аренду",
   "accueil_banque": "Приёмная банка",
   "coffre_privatif": "Частный сейф — сдаётся в аренду",
   "bureau_prive": "Частный кабинет",
   "accueil_notaire": "Приёмная нотариуса",
   "bureau_successions": "Отдел наследства",
   "bureau_contrats": "Отдел договоров",
   "archives_notariales": "Нотариальный архив",
   "amphi": "Лекционный зал",
   "salle_reunion": "Зал заседаний"
  },
  "ko": {
   "accueil": "안내실",
   "restaurant": "식당 홀",
   "bar": "바",
   "chambres": "객실",
   "suite_privee": "개인 스위트룸 — 임대 가능",
   "suite_presidentielle": "대통령 스위트룸 — 임대 가능",
   "accueil_banque": "은행 접수처",
   "coffre_privatif": "개인 금고 — 임대 가능",
   "bureau_prive": "개인 사무실",
   "accueil_notaire": "공증사무소 접수처",
   "bureau_successions": "상속 사무실",
   "bureau_contrats": "계약 사무실",
   "archives_notariales": "공증 기록보관소",
   "amphi": "강의실",
   "salle_reunion": "회의실"
  },
  "ar": {
   "accueil": "الاستقبال",
   "restaurant": "قاعة المطعم",
   "bar": "البار",
   "chambres": "الغرف",
   "suite_privee": "جناح خاص — متاح للإيجار",
   "suite_presidentielle": "جناح رئاسي — متاح للإيجار",
   "accueil_banque": "استقبال البنك",
   "coffre_privatif": "خزنة خاصة — متاحة للإيجار",
   "bureau_prive": "مكتب خاص",
   "accueil_notaire": "استقبال مكتب التوثيق",
   "bureau_successions": "مكتب شؤون الميراث",
   "bureau_contrats": "مكتب العقود",
   "archives_notariales": "أرشيف التوثيق",
   "amphi": "قاعة المحاضرات",
   "salle_reunion": "قاعة الاجتماعات"
  },
  "pt-BR": {
   "accueil": "Recepção",
   "restaurant": "Salão do restaurante",
   "bar": "Bar",
   "chambres": "Quartos",
   "suite_privee": "Suíte privativa — Disponível para aluguel",
   "suite_presidentielle": "Suíte presidencial — Disponível para aluguel",
   "accueil_banque": "Recepção do banco",
   "coffre_privatif": "Cofre privativo — Disponível para aluguel",
   "bureau_prive": "Escritório privativo",
   "accueil_notaire": "Recepção do cartório",
   "bureau_successions": "Sala de sucessões",
   "bureau_contrats": "Sala de contratos",
   "archives_notariales": "Arquivo notarial",
   "amphi": "Anfiteatro",
   "salle_reunion": "Sala de reuniões"
  },
  "de": {
   "accueil": "Empfang",
   "restaurant": "Restaurantbereich",
   "bar": "Bar",
   "chambres": "Zimmer",
   "suite_privee": "Privatsuite — zu vermieten",
   "suite_presidentielle": "Präsidentensuite — zu vermieten",
   "accueil_banque": "Bankempfang",
   "coffre_privatif": "Privater Tresor — zu vermieten",
   "bureau_prive": "Privatbüro",
   "accueil_notaire": "Notariatsempfang",
   "bureau_successions": "Nachlassbüro",
   "bureau_contrats": "Vertragsbüro",
   "archives_notariales": "Notariatsarchiv",
   "amphi": "Hörsaal",
   "salle_reunion": "Besprechungsraum"
  }
 };
 for(const [locale,labels] of Object.entries(serviceRooms)) Object.assign(localized[locale],labels);


 for(const [locale,labels] of Object.entries(mairie)) Object.assign(localized[locale],labels);
 for(const [locale,labels] of Object.entries(embassies)) Object.assign(localized[locale],labels);
 // Pièces de Novomirsk/Krasnov, identifiants séparés pour éviter toute collision de salles homonymes.
 // Résolution strictement par bâtiment + pièce + libellé français : aucune navigation changée.
 const extraRoomScopes={
  "stade": {
    "terrain": ["dynamoPitch", "Terrain — Dynamo de Novomirsk"],
    "vestiaires": ["dynamoChangingRooms", "Vestiaires — Dynamo de Novomirsk"],
    "buvette": ["dynamoKiosk", "Buvette des tribunes"],
    "guichet_paris": ["dynamoBookmaker", "Bookmaker du Dynamo"],
    "siege_supporters": ["dynamoFanClub", "Club des supporters du Dynamo"],
    "boutique": ["dynamoStore", "Boutique officielle du Dynamo"]
  },
  "musee-novomirsk": {
    "hall": [
      "novoMuseumHall",
      "Hall d'accueil"
    ],
    "salle_criminels": [
      "novoMuseumCriminals",
      "Salle des Grands Criminels Novomirskois"
    ],
    "salle_maires": [
      "novoMuseumMayors",
      "Salle des Présidents du Soviet municipal"
    ],
    "salle_personnalites": [
      "novoMuseumHeroes",
      "Salle des Héros du Peuple"
    ],
    "salle_entrepreneurs": [
      "novoMuseumBuilders",
      "Salle des Grands Bâtisseurs de la Production"
    ],
    "salle_organisations": [
      "novoMuseumOrgs",
      "Salle des Organisations Novomirskoises"
    ],
    "salle_plumes": [
      "novoMuseumWriters",
      "Salle des Plumes Novomirskoises"
    ],
    "salle_honneur_militaire": [
      "novoMuseumMilitary",
      "Salle d'Honneur Militaire"
    ],
    "salle_unions": [
      "novoMuseumUnions",
      "Salle des Unions Célèbres"
    ],
    "salle_scandales": [
      "novoMuseumScandals",
      "Salle des Scandales et Affaires"
    ]
  },
  "garage-novomirsk": {
    "atelier_garage": [
      "novoGarageWorkshop",
      "Atelier"
    ]
  },
  "salon-coiffure-novomirsk": {
    "salon_coiffure": [
      "novoHairSalon",
      "Salon"
    ]
  },
  "pharmacie-officielle-novomirsk": {
    "comptoir_pharmacie": [
      "novoPharmacyCounter",
      "Comptoir"
    ]
  },
  "poissonniere-novomirsk": {
    "etal_poissonniere": [
      "novoFishStall",
      "Étal"
    ]
  },
  "station-service-krasnov": {
    "boutique_station": [
      "krasnovFuelShop",
      "Boutique"
    ]
  },
  "siege-renseignement": {
    "accueil_renseignement": [
      "intelReception",
      "Accueil"
    ],
    "salle_ecoutes": [
      "intelListeningRoom",
      "Salle des Écoutes"
    ],
    "salle_interrogatoire_renseignement": [
      "intelInterrogationRoom",
      "Salle d'Interrogatoire"
    ]
  },
  "entrepot-logistique-novomirsk": {
    "salle_ventes": [
      "novoWarehouseSales",
      "Salle des Ventes"
    ],
    "bureau_direction": [
      "novoWarehouseDirector",
      "Bureau de Direction"
    ]
  }
};
 const extraRoomWords={
  "fr": {
    "dynamoPitch": "Terrain — Dynamo de Novomirsk",
    "dynamoChangingRooms": "Vestiaires — Dynamo de Novomirsk",
    "dynamoKiosk": "Buvette des tribunes",
    "dynamoBookmaker": "Bookmaker du Dynamo",
    "dynamoFanClub": "Club des supporters du Dynamo",
    "dynamoStore": "Boutique officielle du Dynamo",
    "novoMuseumHall": "Hall d'accueil",
    "novoMuseumCriminals": "Salle des Grands Criminels Novomirskois",
    "novoMuseumMayors": "Salle des Présidents du Soviet municipal",
    "novoMuseumHeroes": "Salle des Héros du Peuple",
    "novoMuseumBuilders": "Salle des Grands Bâtisseurs de la Production",
    "novoMuseumOrgs": "Salle des Organisations Novomirskoises",
    "novoMuseumWriters": "Salle des Plumes Novomirskoises",
    "novoMuseumMilitary": "Salle d'Honneur Militaire",
    "novoMuseumUnions": "Salle des Unions Célèbres",
    "novoMuseumScandals": "Salle des Scandales et Affaires",
    "novoGarageWorkshop": "Atelier",
    "novoHairSalon": "Salon",
    "novoPharmacyCounter": "Comptoir",
    "novoFishStall": "Étal",
    "krasnovFuelShop": "Boutique",
    "intelReception": "Accueil",
    "intelListeningRoom": "Salle des Écoutes",
    "intelInterrogationRoom": "Salle d'Interrogatoire",
    "novoWarehouseSales": "Salle des Ventes",
    "novoWarehouseDirector": "Bureau de Direction"
  },
  "en": {
    "dynamoPitch": "Pitch — Dynamo Novomirsk",
    "dynamoChangingRooms": "Changing rooms — Dynamo Novomirsk",
    "dynamoKiosk": "Stands refreshment kiosk",
    "dynamoBookmaker": "Dynamo bookmaker",
    "dynamoFanClub": "Dynamo Supporters' Club",
    "dynamoStore": "Official Dynamo Store",
    "novoMuseumHall": "Reception Hall",
    "novoMuseumCriminals": "Hall of Notorious Novomirsk Criminals",
    "novoMuseumMayors": "Hall of Municipal Soviet Chairpersons",
    "novoMuseumHeroes": "Hall of the People's Heroes",
    "novoMuseumBuilders": "Hall of the Great Builders of Production",
    "novoMuseumOrgs": "Hall of Novomirsk Organisations",
    "novoMuseumWriters": "Hall of Novomirsk Writers",
    "novoMuseumMilitary": "Military Hall of Honour",
    "novoMuseumUnions": "Hall of Famous Unions",
    "novoMuseumScandals": "Hall of Scandals and Affairs",
    "novoGarageWorkshop": "Workshop",
    "novoHairSalon": "Hair Salon",
    "novoPharmacyCounter": "Pharmacy Counter",
    "novoFishStall": "Fish Stall",
    "krasnovFuelShop": "Petrol Station Shop",
    "intelReception": "Intelligence Reception",
    "intelListeningRoom": "Listening Room",
    "intelInterrogationRoom": "Interrogation Room",
    "novoWarehouseSales": "Sales Room",
    "novoWarehouseDirector": "Director's Office"
  },
  "es": {
    "dynamoPitch": "Campo — Dynamo de Novomirsk",
    "dynamoChangingRooms": "Vestuarios — Dynamo de Novomirsk",
    "dynamoKiosk": "Bar de las gradas",
    "dynamoBookmaker": "Casa de apuestas del Dynamo",
    "dynamoFanClub": "Club de aficionados del Dynamo",
    "dynamoStore": "Tienda oficial del Dynamo",
    "novoMuseumHall": "Vestíbulo de recepción",
    "novoMuseumCriminals": "Sala de los grandes criminales de Novomirsk",
    "novoMuseumMayors": "Sala de los presidentes del Sóviet municipal",
    "novoMuseumHeroes": "Sala de los héroes del pueblo",
    "novoMuseumBuilders": "Sala de los grandes constructores de la producción",
    "novoMuseumOrgs": "Sala de las organizaciones de Novomirsk",
    "novoMuseumWriters": "Sala de los escritores de Novomirsk",
    "novoMuseumMilitary": "Sala de honor militar",
    "novoMuseumUnions": "Sala de las uniones célebres",
    "novoMuseumScandals": "Sala de escándalos y asuntos",
    "novoGarageWorkshop": "Taller",
    "novoHairSalon": "Peluquería",
    "novoPharmacyCounter": "Mostrador de farmacia",
    "novoFishStall": "Puesto de pescado",
    "krasnovFuelShop": "Tienda de la gasolinera",
    "intelReception": "Recepción de inteligencia",
    "intelListeningRoom": "Sala de escuchas",
    "intelInterrogationRoom": "Sala de interrogatorios",
    "novoWarehouseSales": "Sala de ventas",
    "novoWarehouseDirector": "Despacho de dirección"
  },
  "zh-TW": {
    "dynamoPitch": "球場 — 諾沃米爾斯克迪納摩",
    "dynamoChangingRooms": "更衣室 — 諾沃米爾斯克迪納摩",
    "dynamoKiosk": "看臺飲料攤",
    "dynamoBookmaker": "迪納摩投注站",
    "dynamoFanClub": "迪納摩球迷俱樂部",
    "dynamoStore": "迪納摩官方商店",
    "novoMuseumHall": "接待大廳",
    "novoMuseumCriminals": "諾沃米爾斯克重大罪犯展廳",
    "novoMuseumMayors": "市蘇維埃主席展廳",
    "novoMuseumHeroes": "人民英雄展廳",
    "novoMuseumBuilders": "生產建設功臣展廳",
    "novoMuseumOrgs": "諾沃米爾斯克組織展廳",
    "novoMuseumWriters": "諾沃米爾斯克文人展廳",
    "novoMuseumMilitary": "軍事榮譽展廳",
    "novoMuseumUnions": "著名聯盟展廳",
    "novoMuseumScandals": "醜聞與案件展廳",
    "novoGarageWorkshop": "維修工坊",
    "novoHairSalon": "理髮店",
    "novoPharmacyCounter": "藥房櫃檯",
    "novoFishStall": "魚販攤位",
    "krasnovFuelShop": "加油站商店",
    "intelReception": "情報部門接待處",
    "intelListeningRoom": "監聽室",
    "intelInterrogationRoom": "訊問室",
    "novoWarehouseSales": "銷售大廳",
    "novoWarehouseDirector": "主管辦公室"
  },
  "ru": {
    "dynamoPitch": "Поле — «Динамо» Новомирска",
    "dynamoChangingRooms": "Раздевалки — «Динамо» Новомирска",
    "dynamoKiosk": "Буфет на трибунах",
    "dynamoBookmaker": "Букмекер «Динамо»",
    "dynamoFanClub": "Клуб болельщиков «Динамо»",
    "dynamoStore": "Официальный магазин «Динамо»",
    "novoMuseumHall": "Приёмный зал",
    "novoMuseumCriminals": "Зал известных преступников Новомирска",
    "novoMuseumMayors": "Зал председателей городского Совета",
    "novoMuseumHeroes": "Зал народных героев",
    "novoMuseumBuilders": "Зал великих строителей производства",
    "novoMuseumOrgs": "Зал организаций Новомирска",
    "novoMuseumWriters": "Зал писателей Новомирска",
    "novoMuseumMilitary": "Зал воинской славы",
    "novoMuseumUnions": "Зал знаменитых союзов",
    "novoMuseumScandals": "Зал скандалов и дел",
    "novoGarageWorkshop": "Мастерская",
    "novoHairSalon": "Парикмахерская",
    "novoPharmacyCounter": "Аптечный прилавок",
    "novoFishStall": "Рыбный прилавок",
    "krasnovFuelShop": "Магазин автозаправки",
    "intelReception": "Приёмная разведки",
    "intelListeningRoom": "Комната прослушивания",
    "intelInterrogationRoom": "Комната допросов",
    "novoWarehouseSales": "Торговый зал",
    "novoWarehouseDirector": "Кабинет директора"
  },
  "ko": {
    "dynamoPitch": "경기장 — 노보미르스크 디나모",
    "dynamoChangingRooms": "탈의실 — 노보미르스크 디나모",
    "dynamoKiosk": "관중석 매점",
    "dynamoBookmaker": "디나모 스포츠 베팅 창구",
    "dynamoFanClub": "디나모 서포터즈 클럽",
    "dynamoStore": "디나모 공식 상점",
    "novoMuseumHall": "안내 홀",
    "novoMuseumCriminals": "노보미르스크 주요 범죄자 전시실",
    "novoMuseumMayors": "시 소비에트 의장 전시실",
    "novoMuseumHeroes": "인민 영웅 전시실",
    "novoMuseumBuilders": "생산 건설 공로자 전시실",
    "novoMuseumOrgs": "노보미르스크 단체 전시실",
    "novoMuseumWriters": "노보미르스크 작가 전시실",
    "novoMuseumMilitary": "군사 명예 전시실",
    "novoMuseumUnions": "유명한 연합 전시실",
    "novoMuseumScandals": "스캔들과 사건 전시실",
    "novoGarageWorkshop": "정비 작업장",
    "novoHairSalon": "미용실",
    "novoPharmacyCounter": "약국 계산대",
    "novoFishStall": "생선 가판대",
    "krasnovFuelShop": "주유소 매점",
    "intelReception": "정보기관 접수처",
    "intelListeningRoom": "도청실",
    "intelInterrogationRoom": "심문실",
    "novoWarehouseSales": "판매실",
    "novoWarehouseDirector": "소장실"
  },
  "ar": {
    "dynamoPitch": "الملعب — دينامو نوفوميرسك",
    "dynamoChangingRooms": "غرف تبديل الملابس — دينامو نوفوميرسك",
    "dynamoKiosk": "كشك مشروبات المدرجات",
    "dynamoBookmaker": "مكتب مراهنات دينامو",
    "dynamoFanClub": "نادي مشجعي دينامو",
    "dynamoStore": "متجر دينامو الرسمي",
    "novoMuseumHall": "قاعة الاستقبال",
    "novoMuseumCriminals": "قاعة كبار المجرمين في نوفوميرسك",
    "novoMuseumMayors": "قاعة رؤساء المجلس البلدي",
    "novoMuseumHeroes": "قاعة أبطال الشعب",
    "novoMuseumBuilders": "قاعة كبار بناة الإنتاج",
    "novoMuseumOrgs": "قاعة منظمات نوفوميرسك",
    "novoMuseumWriters": "قاعة أدباء نوفوميرسك",
    "novoMuseumMilitary": "قاعة الشرف العسكري",
    "novoMuseumUnions": "قاعة الاتحادات الشهيرة",
    "novoMuseumScandals": "قاعة الفضائح والقضايا",
    "novoGarageWorkshop": "ورشة العمل",
    "novoHairSalon": "صالون تصفيف الشعر",
    "novoPharmacyCounter": "منضدة الصيدلية",
    "novoFishStall": "بسطة بيع الأسماك",
    "krasnovFuelShop": "متجر محطة الوقود",
    "intelReception": "استقبال الاستخبارات",
    "intelListeningRoom": "غرفة التنصّت",
    "intelInterrogationRoom": "غرفة الاستجواب",
    "novoWarehouseSales": "قاعة المبيعات",
    "novoWarehouseDirector": "مكتب المدير"
  },
  "pt-BR": {
    "dynamoPitch": "Campo — Dynamo Novomirsk",
    "dynamoChangingRooms": "Vestiários — Dynamo Novomirsk",
    "dynamoKiosk": "Lanchonete das arquibancadas",
    "dynamoBookmaker": "Casa de apostas do Dynamo",
    "dynamoFanClub": "Clube de torcedores do Dynamo",
    "dynamoStore": "Loja oficial do Dynamo",
    "novoMuseumHall": "Hall de recepção",
    "novoMuseumCriminals": "Sala dos grandes criminosos de Novomirsk",
    "novoMuseumMayors": "Sala dos presidentes do Soviete municipal",
    "novoMuseumHeroes": "Sala dos heróis do povo",
    "novoMuseumBuilders": "Sala dos grandes construtores da produção",
    "novoMuseumOrgs": "Sala das organizações de Novomirsk",
    "novoMuseumWriters": "Sala dos escritores de Novomirsk",
    "novoMuseumMilitary": "Sala de honra militar",
    "novoMuseumUnions": "Sala das uniões célebres",
    "novoMuseumScandals": "Sala dos escândalos e casos",
    "novoGarageWorkshop": "Oficina",
    "novoHairSalon": "Salão de beleza",
    "novoPharmacyCounter": "Balcão da farmácia",
    "novoFishStall": "Banca de peixes",
    "krasnovFuelShop": "Loja do posto de combustível",
    "intelReception": "Recepção da inteligência",
    "intelListeningRoom": "Sala de escuta",
    "intelInterrogationRoom": "Sala de interrogatório",
    "novoWarehouseSales": "Salão de vendas",
    "novoWarehouseDirector": "Gabinete da direção"
  },
  "de": {
    "dynamoPitch": "Spielfeld — Dynamo Nowomirsk",
    "dynamoChangingRooms": "Umkleiden — Dynamo Nowomirsk",
    "dynamoKiosk": "Tribünenkiosk",
    "dynamoBookmaker": "Dynamo-Wettbüro",
    "dynamoFanClub": "Dynamo-Fanclub",
    "dynamoStore": "Offizieller Dynamo-Fanshop",
    "novoMuseumHall": "Empfangshalle",
    "novoMuseumCriminals": "Saal der großen Verbrecher von Novomirsk",
    "novoMuseumMayors": "Saal der Vorsitzenden des Stadtsowjets",
    "novoMuseumHeroes": "Saal der Volkshelden",
    "novoMuseumBuilders": "Saal der großen Produktionspioniere",
    "novoMuseumOrgs": "Saal der Organisationen von Novomirsk",
    "novoMuseumWriters": "Saal der Schriftsteller von Novomirsk",
    "novoMuseumMilitary": "Militärischer Ehrensaal",
    "novoMuseumUnions": "Saal berühmter Vereinigungen",
    "novoMuseumScandals": "Saal der Skandale und Affären",
    "novoGarageWorkshop": "Werkstatt",
    "novoHairSalon": "Friseursalon",
    "novoPharmacyCounter": "Apothekentheke",
    "novoFishStall": "Fischstand",
    "krasnovFuelShop": "Tankstellenshop",
    "intelReception": "Empfang des Nachrichtendienstes",
    "intelListeningRoom": "Abhörraum",
    "intelInterrogationRoom": "Verhörraum",
    "novoWarehouseSales": "Verkaufshalle",
    "novoWarehouseDirector": "Direktionsbüro"
  }
};
 for(const [locale,translations] of Object.entries(extraRoomWords)) {
   if(resources[locale]?.translation) resources[locale].translation.extraRooms={...translations};
 }
 const expected=localized.fr;
 for(const [locale,labels] of Object.entries(localized)){
  if(resources[locale]?.translation)
   resources[locale].translation.rooms={...labels};
 }
 function label(buildingId,roomId,original){
  if(typeof original!=='string')return original;
  const extra=extraRoomScopes[buildingId]?.[roomId];
  if(extra){
   if(original!==extra[1])return original;
   const locale=global.RPPlateauI18n?.language?.()||'fr';
   const translated=resources[locale]?.translation?.extraRooms?.[extra[0]];
   return typeof translated==='string' && translated.trim()?translated:original;
  }
  // Les autres édifices et les variantes politiques conservent leurs noms.
  if(buildingId==='mairie') {
   if(!Object.hasOwn(mairie.fr,roomId)||original!==mairie.fr[roomId])return original;
  } else if(buildingId==='palais-gouvernement') {
   if(!governmentRoomIds.has(roomId)||original!==expected[roomId])return original;
  } else if(buildingId==='palais-ambassades-novomirsk') {
   if(!Object.hasOwn(embassies.fr,roomId)||original!==embassies.fr[roomId])return original;
  } else if(buildingId==='armurerie') {
   if(!Object.hasOwn(armory.fr,roomId)||original!==armory.fr[roomId])return original;
  } else if(buildingId==='commissariat') {
   if(!['accueil_police','prison','bureau_commissaire'].includes(roomId)||original!==everyday.fr[roomId])return original;
  } else if(buildingId==='marche') {
   if(roomId!=='marche_ext'||original!==everyday.fr[roomId])return original;
  } else if(['hotel-republica','banque-nationale','banque-privee','office-notarial','universite'].includes(buildingId)) {
   const allowed={
    'hotel-republica':['accueil','restaurant','bar','chambres','suite_privee','suite_presidentielle'],
    'banque-nationale':['accueil_banque','coffre_privatif'],
    'banque-privee':['bureau_prive'],
    'office-notarial':['accueil_notaire','bureau_successions','bureau_contrats','archives_notariales'],
    'universite':['amphi','salle_reunion']
   };
   if(!allowed[buildingId].includes(roomId)||original!==serviceRooms.fr[roomId])return original;
  } else return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  const translated=global.i18next?.t?.('rooms.'+roomId,{lng:locale,defaultValue:original});
  return typeof translated==='string'&&translated.trim() ? translated : original;
 }
 function labelHtml(buildingId,roomId,original){
  const output=label(buildingId,roomId,original);
  if(output===original)return original;
  return output.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 // Pièces propres à Sovarka (12/11/2026) : dernier recours, seulement si rien ci-dessus n'a traduit.
 function labelAvecSovarka(buildingId,roomId,original){
  const t=label(buildingId,roomId,original);
  if(t!==original)return t;
  const s=global.RPSovarkaPiecesI18n?.label?.(buildingId,roomId,original);
  return typeof s==='string'&&s.trim()?s:original;
 }
 function labelHtmlAvecSovarka(buildingId,roomId,original){
  const output=labelAvecSovarka(buildingId,roomId,original);
  if(output===original)return original;
  return output.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 }
 global.RPRoomI18n=Object.freeze({label:labelAvecSovarka,labelHtml:labelHtmlAvecSovarka});
})(window);
