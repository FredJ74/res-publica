/* Libellés partagés des pièces provenant des gabarits de BUILDINGS.
 * En dernier recours après les variantes et traductions propres à Sovarka :
 * uniquement pour le couple (buildingId,roomId,nom français exact) listé ici.
 * Pas de traduction des noms propres, boutiques rebaptisées ou pièces louées.
 * Aucun ID, accès, coût, serveur ni état joueur modifié.
 */
(function(global){'use strict';
const rows={
  "fr": {
    "Accueil": "Accueil",
    "Hall d'accueil": "Hall d'accueil",
    "Hall d'Entrée": "Hall d'Entrée",
    "Hall d'entree": "Hall d'entree",
    "Salle d'attente": "Salle d'attente",
    "Salle d'audience": "Salle d'audience",
    "Bureau des magistrats": "Bureau des magistrats",
    "Greffe": "Greffe",
    "Salle des Archives": "Salle des Archives",
    "Bureau du Maire": "Bureau du Maire",
    "Bureau du Maire Adjoint": "Bureau du Maire Adjoint",
    "Salle des Elections": "Salle des Elections",
    "Salle de Réunion": "Salle de Réunion",
    "Salle de Reunion": "Salle de Reunion",
    "Salle de Presse": "Salle de Presse",
    "Bar": "Bar",
    "Chambres": "Chambres",
    "Chambre": "Chambre",
    "Salle du Restaurant": "Salle du Restaurant",
    "Reception": "Reception",
    "Redaction": "Redaction",
    "Boutique": "Boutique",
    "Guichet": "Guichet",
    "Salle des Ventes": "Salle des Ventes",
    "Bureau de Direction": "Bureau de Direction",
    "Salle de Production": "Salle de Production",
    "Atelier d'Imprimerie": "Atelier d'Imprimerie",
    "Hall de la Gare": "Hall de la Gare",
    "Salle de cours": "Salle de cours",
    "Vestiaires": "Vestiaires",
    "Infirmerie": "Infirmerie",
    "Réfectoire": "Réfectoire",
    "Bureau": "Bureau",
    "Hall": "Hall",
    "Geôles": "Geôles",
    "Salle du bar": "Salle du bar",
    "Direction": "Direction",
    "Hall Principal": "Hall Principal",
    "Hall des Douanes": "Hall des Douanes",
    "Capitainerie": "Capitainerie",
    "Douanes": "Douanes",
    "Entrepôts": "Entrepôts",
    "Criée": "Criée",
    "Salle de Commandement": "Salle de Commandement",
    "Corps de Garde": "Corps de Garde",
    "Quartier des Troupes": "Quartier des Troupes",
    "Salle des Faits d'Armes": "Salle des Faits d'Armes",
    "Armurerie Militaire": "Armurerie Militaire",
    "Amphitheatre": "Amphitheatre",
    "Salle Principale": "Salle Principale",
    "Nef": "Nef",
    "Terrain": "Terrain",
    "Salle des Organisations": "Salle des Organisations",
    "Salle des Plumes": "Salle des Plumes",
    "Salle d'Honneur Militaire": "Salle d'Honneur Militaire",
    "Salle des Unions Célèbres": "Salle des Unions Célèbres",
    "Salle des Scandales et Affaires": "Salle des Scandales et Affaires",
    "Salle des Grands Criminels": "Salle des Grands Criminels",
    "Salle des Maires de Luthécia": "Salle des Maires de Luthécia"
  },
  "en": {
    "Accueil": "Reception",
    "Hall d'accueil": "Reception hall",
    "Hall d'Entrée": "Entrance hall",
    "Hall d'entree": "Entrance hall",
    "Salle d'attente": "Waiting room",
    "Salle d'audience": "Courtroom",
    "Bureau des magistrats": "Judges' office",
    "Greffe": "Court registry",
    "Salle des Archives": "Archives room",
    "Bureau du Maire": "Mayor's office",
    "Bureau du Maire Adjoint": "Deputy mayor's office",
    "Salle des Elections": "Election room",
    "Salle de Réunion": "Meeting room",
    "Salle de Reunion": "Meeting room",
    "Salle de Presse": "Press room",
    "Bar": "Bar",
    "Chambres": "Rooms",
    "Chambre": "Room",
    "Salle du Restaurant": "Restaurant dining room",
    "Reception": "Reception",
    "Redaction": "Editorial office",
    "Boutique": "Shop",
    "Guichet": "Service counter",
    "Salle des Ventes": "Sales room",
    "Bureau de Direction": "Management office",
    "Salle de Production": "Production hall",
    "Atelier d'Imprimerie": "Print workshop",
    "Hall de la Gare": "Station concourse",
    "Salle de cours": "Classroom",
    "Vestiaires": "Changing rooms",
    "Infirmerie": "Infirmary",
    "Réfectoire": "Mess hall",
    "Bureau": "Office",
    "Hall": "Hall",
    "Geôles": "Jail cells",
    "Salle du bar": "Bar room",
    "Direction": "Management",
    "Hall Principal": "Main hall",
    "Hall des Douanes": "Customs hall",
    "Capitainerie": "Harbor master's office",
    "Douanes": "Customs",
    "Entrepôts": "Warehouses",
    "Criée": "Fish auction",
    "Salle de Commandement": "Command room",
    "Corps de Garde": "Guardroom",
    "Quartier des Troupes": "Troop quarters",
    "Salle des Faits d'Armes": "Military honors hall",
    "Armurerie Militaire": "Military armory",
    "Amphitheatre": "Lecture hall",
    "Salle Principale": "Main room",
    "Nef": "Nave",
    "Terrain": "Grounds",
    "Salle des Organisations": "Organizations hall",
    "Salle des Plumes": "Writers' hall",
    "Salle d'Honneur Militaire": "Military honor hall",
    "Salle des Unions Célèbres": "Famous unions hall",
    "Salle des Scandales et Affaires": "Scandals and affairs hall",
    "Salle des Grands Criminels": "Notorious criminals hall",
    "Salle des Maires de Luthécia": "Luthécia mayors' hall"
  },
  "es": {
    "Accueil": "Recepción",
    "Hall d'accueil": "Vestíbulo",
    "Hall d'Entrée": "Vestíbulo de entrada",
    "Hall d'entree": "Vestíbulo de entrada",
    "Salle d'attente": "Sala de espera",
    "Salle d'audience": "Sala de audiencias",
    "Bureau des magistrats": "Despacho de los magistrados",
    "Greffe": "Secretaría judicial",
    "Salle des Archives": "Sala de archivos",
    "Bureau du Maire": "Despacho del alcalde",
    "Bureau du Maire Adjoint": "Despacho del teniente de alcalde",
    "Salle des Elections": "Sala de elecciones",
    "Salle de Réunion": "Sala de reuniones",
    "Salle de Reunion": "Sala de reuniones",
    "Salle de Presse": "Sala de prensa",
    "Bar": "Bar",
    "Chambres": "Habitaciones",
    "Chambre": "Habitación",
    "Salle du Restaurant": "Comedor del restaurante",
    "Reception": "Recepción",
    "Redaction": "Redacción",
    "Boutique": "Tienda",
    "Guichet": "Ventanilla",
    "Salle des Ventes": "Sala de ventas",
    "Bureau de Direction": "Despacho de dirección",
    "Salle de Production": "Sala de producción",
    "Atelier d'Imprimerie": "Taller de imprenta",
    "Hall de la Gare": "Vestíbulo de la estación",
    "Salle de cours": "Aula",
    "Vestiaires": "Vestuarios",
    "Infirmerie": "Enfermería",
    "Réfectoire": "Comedor",
    "Bureau": "Despacho",
    "Hall": "Vestíbulo",
    "Geôles": "Calabozos",
    "Salle du bar": "Sala del bar",
    "Direction": "Dirección",
    "Hall Principal": "Vestíbulo principal",
    "Hall des Douanes": "Vestíbulo de aduanas",
    "Capitainerie": "Capitanía del puerto",
    "Douanes": "Aduanas",
    "Entrepôts": "Almacenes",
    "Criée": "Lonja de pescado",
    "Salle de Commandement": "Sala de mando",
    "Corps de Garde": "Cuerpo de guardia",
    "Quartier des Troupes": "Alojamiento de las tropas",
    "Salle des Faits d'Armes": "Sala de hazañas militares",
    "Armurerie Militaire": "Armería militar",
    "Amphitheatre": "Anfiteatro",
    "Salle Principale": "Sala principal",
    "Nef": "Nave",
    "Terrain": "Terreno",
    "Salle des Organisations": "Sala de organizaciones",
    "Salle des Plumes": "Sala de los escritores",
    "Salle d'Honneur Militaire": "Sala de honor militar",
    "Salle des Unions Célèbres": "Sala de uniones célebres",
    "Salle des Scandales et Affaires": "Sala de escándalos y asuntos",
    "Salle des Grands Criminels": "Sala de grandes criminales",
    "Salle des Maires de Luthécia": "Sala de alcaldes de Luthécia"
  },
  "zh-TW": {
    "Accueil": "接待處",
    "Hall d'accueil": "接待大廳",
    "Hall d'Entrée": "入口大廳",
    "Hall d'entree": "入口大廳",
    "Salle d'attente": "候診室",
    "Salle d'audience": "法庭",
    "Bureau des magistrats": "法官辦公室",
    "Greffe": "法院書記處",
    "Salle des Archives": "檔案室",
    "Bureau du Maire": "市長辦公室",
    "Bureau du Maire Adjoint": "副市長辦公室",
    "Salle des Elections": "選舉室",
    "Salle de Réunion": "會議室",
    "Salle de Reunion": "會議室",
    "Salle de Presse": "新聞室",
    "Bar": "酒吧",
    "Chambres": "客房",
    "Chambre": "客房",
    "Salle du Restaurant": "餐廳用餐區",
    "Reception": "接待處",
    "Redaction": "編輯部",
    "Boutique": "商店",
    "Guichet": "服務櫃檯",
    "Salle des Ventes": "銷售廳",
    "Bureau de Direction": "管理辦公室",
    "Salle de Production": "生產車間",
    "Atelier d'Imprimerie": "印刷工坊",
    "Hall de la Gare": "車站大廳",
    "Salle de cours": "教室",
    "Vestiaires": "更衣室",
    "Infirmerie": "醫務室",
    "Réfectoire": "食堂",
    "Bureau": "辦公室",
    "Hall": "大廳",
    "Geôles": "牢房",
    "Salle du bar": "酒吧大廳",
    "Direction": "管理部",
    "Hall Principal": "主大廳",
    "Hall des Douanes": "海關大廳",
    "Capitainerie": "港務長辦公室",
    "Douanes": "海關",
    "Entrepôts": "倉庫",
    "Criée": "魚貨拍賣場",
    "Salle de Commandement": "指揮室",
    "Corps de Garde": "衛兵室",
    "Quartier des Troupes": "部隊營舍",
    "Salle des Faits d'Armes": "軍功紀念廳",
    "Armurerie Militaire": "軍械庫",
    "Amphitheatre": "階梯教室",
    "Salle Principale": "主廳",
    "Nef": "中殿",
    "Terrain": "場地",
    "Salle des Organisations": "組織展廳",
    "Salle des Plumes": "作家展廳",
    "Salle d'Honneur Militaire": "軍事榮譽廳",
    "Salle des Unions Célèbres": "知名聯盟展廳",
    "Salle des Scandales et Affaires": "醜聞與事件展廳",
    "Salle des Grands Criminels": "重大罪犯展廳",
    "Salle des Maires de Luthécia": "盧特西亞市長展廳"
  },
  "ru": {
    "Accueil": "Приёмная",
    "Hall d'accueil": "Приёмный холл",
    "Hall d'Entrée": "Вестибюль",
    "Hall d'entree": "Вестибюль",
    "Salle d'attente": "Зал ожидания",
    "Salle d'audience": "Зал судебных заседаний",
    "Bureau des magistrats": "Кабинет судей",
    "Greffe": "Судебная канцелярия",
    "Salle des Archives": "Архивный зал",
    "Bureau du Maire": "Кабинет мэра",
    "Bureau du Maire Adjoint": "Кабинет заместителя мэра",
    "Salle des Elections": "Избирательный зал",
    "Salle de Réunion": "Переговорная",
    "Salle de Reunion": "Переговорная",
    "Salle de Presse": "Пресс-зал",
    "Bar": "Бар",
    "Chambres": "Номера",
    "Chambre": "Номер",
    "Salle du Restaurant": "Зал ресторана",
    "Reception": "Приёмная",
    "Redaction": "Редакция",
    "Boutique": "Магазин",
    "Guichet": "Окно обслуживания",
    "Salle des Ventes": "Торговый зал",
    "Bureau de Direction": "Кабинет директора",
    "Salle de Production": "Производственный цех",
    "Atelier d'Imprimerie": "Печатный цех",
    "Hall de la Gare": "Вокзальный зал",
    "Salle de cours": "Учебный класс",
    "Vestiaires": "Раздевалки",
    "Infirmerie": "Медпункт",
    "Réfectoire": "Столовая",
    "Bureau": "Кабинет",
    "Hall": "Холл",
    "Geôles": "Тюремные камеры",
    "Salle du bar": "Зал бара",
    "Direction": "Дирекция",
    "Hall Principal": "Главный зал",
    "Hall des Douanes": "Таможенный зал",
    "Capitainerie": "Капитания порта",
    "Douanes": "Таможня",
    "Entrepôts": "Склады",
    "Criée": "Рыбный аукцион",
    "Salle de Commandement": "Командный зал",
    "Corps de Garde": "Караульное помещение",
    "Quartier des Troupes": "Казармы личного состава",
    "Salle des Faits d'Armes": "Зал боевых заслуг",
    "Armurerie Militaire": "Военный арсенал",
    "Amphitheatre": "Лекционный зал",
    "Salle Principale": "Главный зал",
    "Nef": "Неф",
    "Terrain": "Территория",
    "Salle des Organisations": "Зал организаций",
    "Salle des Plumes": "Зал писателей",
    "Salle d'Honneur Militaire": "Зал воинской славы",
    "Salle des Unions Célèbres": "Зал знаменитых союзов",
    "Salle des Scandales et Affaires": "Зал скандалов и дел",
    "Salle des Grands Criminels": "Зал известных преступников",
    "Salle des Maires de Luthécia": "Зал мэров Лютеции"
  },
  "ko": {
    "Accueil": "안내 데스크",
    "Hall d'accueil": "안내 홀",
    "Hall d'Entrée": "입구 홀",
    "Hall d'entree": "입구 홀",
    "Salle d'attente": "대기실",
    "Salle d'audience": "법정",
    "Bureau des magistrats": "판사실",
    "Greffe": "법원 서기실",
    "Salle des Archives": "기록 보관실",
    "Bureau du Maire": "시장실",
    "Bureau du Maire Adjoint": "부시장실",
    "Salle des Elections": "선거실",
    "Salle de Réunion": "회의실",
    "Salle de Reunion": "회의실",
    "Salle de Presse": "기자실",
    "Bar": "바",
    "Chambres": "객실",
    "Chambre": "객실",
    "Salle du Restaurant": "식당 홀",
    "Reception": "접수처",
    "Redaction": "편집실",
    "Boutique": "상점",
    "Guichet": "창구",
    "Salle des Ventes": "판매실",
    "Bureau de Direction": "경영진 사무실",
    "Salle de Production": "생산실",
    "Atelier d'Imprimerie": "인쇄 작업실",
    "Hall de la Gare": "역 대합실",
    "Salle de cours": "강의실",
    "Vestiaires": "탈의실",
    "Infirmerie": "의무실",
    "Réfectoire": "식당",
    "Bureau": "사무실",
    "Hall": "홀",
    "Geôles": "유치장",
    "Salle du bar": "바 홀",
    "Direction": "운영실",
    "Hall Principal": "중앙 홀",
    "Hall des Douanes": "세관 홀",
    "Capitainerie": "항만 관리 사무소",
    "Douanes": "세관",
    "Entrepôts": "창고",
    "Criée": "수산물 경매장",
    "Salle de Commandement": "지휘실",
    "Corps de Garde": "경비실",
    "Quartier des Troupes": "병사 숙소",
    "Salle des Faits d'Armes": "전공 기념관",
    "Armurerie Militaire": "군 무기고",
    "Amphitheatre": "강당",
    "Salle Principale": "주 공간",
    "Nef": "본당",
    "Terrain": "부지",
    "Salle des Organisations": "단체 전시실",
    "Salle des Plumes": "작가 전시실",
    "Salle d'Honneur Militaire": "군사 명예관",
    "Salle des Unions Célèbres": "유명 연합 전시실",
    "Salle des Scandales et Affaires": "스캔들과 사건 전시실",
    "Salle des Grands Criminels": "악명 높은 범죄자 전시실",
    "Salle des Maires de Luthécia": "루테시아 시장 전시실"
  },
  "ar": {
    "Accueil": "الاستقبال",
    "Hall d'accueil": "بهو الاستقبال",
    "Hall d'Entrée": "بهو المدخل",
    "Hall d'entree": "بهو المدخل",
    "Salle d'attente": "غرفة الانتظار",
    "Salle d'audience": "قاعة المحكمة",
    "Bureau des magistrats": "مكتب القضاة",
    "Greffe": "قلم المحكمة",
    "Salle des Archives": "قاعة الأرشيف",
    "Bureau du Maire": "مكتب رئيس البلدية",
    "Bureau du Maire Adjoint": "مكتب نائب رئيس البلدية",
    "Salle des Elections": "قاعة الانتخابات",
    "Salle de Réunion": "قاعة الاجتماعات",
    "Salle de Reunion": "قاعة الاجتماعات",
    "Salle de Presse": "قاعة الصحافة",
    "Bar": "حانة",
    "Chambres": "الغرف",
    "Chambre": "غرفة",
    "Salle du Restaurant": "قاعة المطعم",
    "Reception": "الاستقبال",
    "Redaction": "هيئة التحرير",
    "Boutique": "متجر",
    "Guichet": "شباك الخدمة",
    "Salle des Ventes": "قاعة المبيعات",
    "Bureau de Direction": "مكتب الإدارة",
    "Salle de Production": "قاعة الإنتاج",
    "Atelier d'Imprimerie": "ورشة الطباعة",
    "Hall de la Gare": "بهو المحطة",
    "Salle de cours": "قاعة الدروس",
    "Vestiaires": "غرف تبديل الملابس",
    "Infirmerie": "العيادة الطبية",
    "Réfectoire": "قاعة الطعام",
    "Bureau": "مكتب",
    "Hall": "بهو",
    "Geôles": "زنازين",
    "Salle du bar": "قاعة الحانة",
    "Direction": "الإدارة",
    "Hall Principal": "القاعة الرئيسية",
    "Hall des Douanes": "قاعة الجمارك",
    "Capitainerie": "مكتب قائد الميناء",
    "Douanes": "الجمارك",
    "Entrepôts": "المستودعات",
    "Criée": "مزاد الأسماك",
    "Salle de Commandement": "غرفة القيادة",
    "Corps de Garde": "غرفة الحراسة",
    "Quartier des Troupes": "ثكنات الجنود",
    "Salle des Faits d'Armes": "قاعة المآثر العسكرية",
    "Armurerie Militaire": "مستودع الأسلحة العسكري",
    "Amphitheatre": "المدرج",
    "Salle Principale": "القاعة الرئيسية",
    "Nef": "صحن الكنيسة",
    "Terrain": "الأرض",
    "Salle des Organisations": "قاعة المنظمات",
    "Salle des Plumes": "قاعة الكتّاب",
    "Salle d'Honneur Militaire": "قاعة الشرف العسكري",
    "Salle des Unions Célèbres": "قاعة التحالفات الشهيرة",
    "Salle des Scandales et Affaires": "قاعة الفضائح والقضايا",
    "Salle des Grands Criminels": "قاعة كبار المجرمين",
    "Salle des Maires de Luthécia": "قاعة رؤساء بلدية لوثيسيا"
  },
  "pt-BR": {
    "Accueil": "Recepção",
    "Hall d'accueil": "Hall de entrada",
    "Hall d'Entrée": "Hall de entrada",
    "Hall d'entree": "Hall de entrada",
    "Salle d'attente": "Sala de espera",
    "Salle d'audience": "Sala de audiências",
    "Bureau des magistrats": "Gabinete dos magistrados",
    "Greffe": "Cartório judicial",
    "Salle des Archives": "Sala de arquivos",
    "Bureau du Maire": "Gabinete do prefeito",
    "Bureau du Maire Adjoint": "Gabinete do vice-prefeito",
    "Salle des Elections": "Sala de eleições",
    "Salle de Réunion": "Sala de reuniões",
    "Salle de Reunion": "Sala de reuniões",
    "Salle de Presse": "Sala de imprensa",
    "Bar": "Bar",
    "Chambres": "Quartos",
    "Chambre": "Quarto",
    "Salle du Restaurant": "Salão do restaurante",
    "Reception": "Recepção",
    "Redaction": "Redação",
    "Boutique": "Loja",
    "Guichet": "Guichê",
    "Salle des Ventes": "Salão de vendas",
    "Bureau de Direction": "Sala da direção",
    "Salle de Production": "Sala de produção",
    "Atelier d'Imprimerie": "Oficina de impressão",
    "Hall de la Gare": "Hall da estação",
    "Salle de cours": "Sala de aula",
    "Vestiaires": "Vestiários",
    "Infirmerie": "Enfermaria",
    "Réfectoire": "Refeitório",
    "Bureau": "Escritório",
    "Hall": "Hall",
    "Geôles": "Celas",
    "Salle du bar": "Salão do bar",
    "Direction": "Direção",
    "Hall Principal": "Hall principal",
    "Hall des Douanes": "Hall da alfândega",
    "Capitainerie": "Capitania do porto",
    "Douanes": "Alfândega",
    "Entrepôts": "Armazéns",
    "Criée": "Leilão de pescado",
    "Salle de Commandement": "Sala de comando",
    "Corps de Garde": "Corpo da guarda",
    "Quartier des Troupes": "Alojamento das tropas",
    "Salle des Faits d'Armes": "Sala de feitos militares",
    "Armurerie Militaire": "Arsenal militar",
    "Amphitheatre": "Auditório",
    "Salle Principale": "Salão principal",
    "Nef": "Nave",
    "Terrain": "Terreno",
    "Salle des Organisations": "Sala das organizações",
    "Salle des Plumes": "Sala dos escritores",
    "Salle d'Honneur Militaire": "Sala de honra militar",
    "Salle des Unions Célèbres": "Sala das uniões célebres",
    "Salle des Scandales et Affaires": "Sala dos escândalos e casos",
    "Salle des Grands Criminels": "Sala dos grandes criminosos",
    "Salle des Maires de Luthécia": "Sala dos prefeitos de Luthécia"
  },
  "de": {
    "Accueil": "Empfang",
    "Hall d'accueil": "Empfangshalle",
    "Hall d'Entrée": "Eingangshalle",
    "Hall d'entree": "Eingangshalle",
    "Salle d'attente": "Wartezimmer",
    "Salle d'audience": "Gerichtssaal",
    "Bureau des magistrats": "Richterbüro",
    "Greffe": "Gerichtskanzlei",
    "Salle des Archives": "Archivraum",
    "Bureau du Maire": "Büro des Bürgermeisters",
    "Bureau du Maire Adjoint": "Büro des stellvertretenden Bürgermeisters",
    "Salle des Elections": "Wahlraum",
    "Salle de Réunion": "Besprechungsraum",
    "Salle de Reunion": "Besprechungsraum",
    "Salle de Presse": "Presseraum",
    "Bar": "Bar",
    "Chambres": "Zimmer",
    "Chambre": "Zimmer",
    "Salle du Restaurant": "Restaurant-Speisesaal",
    "Reception": "Empfang",
    "Redaction": "Redaktion",
    "Boutique": "Geschäft",
    "Guichet": "Schalter",
    "Salle des Ventes": "Verkaufsraum",
    "Bureau de Direction": "Büro der Geschäftsleitung",
    "Salle de Production": "Produktionshalle",
    "Atelier d'Imprimerie": "Druckwerkstatt",
    "Hall de la Gare": "Bahnhofshalle",
    "Salle de cours": "Unterrichtsraum",
    "Vestiaires": "Umkleiden",
    "Infirmerie": "Krankenstation",
    "Réfectoire": "Speisesaal",
    "Bureau": "Büro",
    "Hall": "Halle",
    "Geôles": "Gefängniszellen",
    "Salle du bar": "Schankraum",
    "Direction": "Leitung",
    "Hall Principal": "Haupthalle",
    "Hall des Douanes": "Zollhalle",
    "Capitainerie": "Hafenmeisterei",
    "Douanes": "Zoll",
    "Entrepôts": "Lagerhäuser",
    "Criée": "Fischauktion",
    "Salle de Commandement": "Kommandoraum",
    "Corps de Garde": "Wachstube",
    "Quartier des Troupes": "Mannschaftsquartier",
    "Salle des Faits d'Armes": "Saal der Heldentaten",
    "Armurerie Militaire": "Militärwaffenkammer",
    "Amphitheatre": "Hörsaal",
    "Salle Principale": "Hauptraum",
    "Nef": "Kirchenschiff",
    "Terrain": "Gelände",
    "Salle des Organisations": "Saal der Organisationen",
    "Salle des Plumes": "Saal der Schriftsteller",
    "Salle d'Honneur Militaire": "Militärischer Ehrensaal",
    "Salle des Unions Célèbres": "Saal berühmter Bündnisse",
    "Salle des Scandales et Affaires": "Saal der Skandale und Affären",
    "Salle des Grands Criminels": "Saal berüchtigter Verbrecher",
    "Salle des Maires de Luthécia": "Saal der Bürgermeister von Luthécia"
  }
};
const scopes=new Map([
  [
    "hotel-republica::accueil",
    "Accueil"
  ],
  [
    "hotel-republica::restaurant",
    "Salle du Restaurant"
  ],
  [
    "hotel-republica::bar",
    "Bar"
  ],
  [
    "hotel-republica::chambres",
    "Chambres"
  ],
  [
    "palais-presidentiel::salle_presse_elysee",
    "Salle de Presse"
  ],
  [
    "palais-gouvernement::hall",
    "Hall d'entree"
  ],
  [
    "palais-gouvernement::salle_presse",
    "Salle de Presse"
  ],
  [
    "assemblee::accueil_assemblee",
    "Accueil"
  ],
  [
    "assemblee::salle_archives_assemblee",
    "Salle des Archives"
  ],
  [
    "office-notarial::accueil_notaire",
    "Accueil"
  ],
  [
    "stade::terrain",
    "Terrain"
  ],
  [
    "stade::vestiaires",
    "Vestiaires"
  ],
  [
    "tribunal::salle_audience",
    "Salle d'audience"
  ],
  [
    "tribunal::bureau_magistrats",
    "Bureau des magistrats"
  ],
  [
    "tribunal::greffe",
    "Greffe"
  ],
  [
    "banque-nationale::accueil_banque",
    "Accueil"
  ],
  [
    "clinique-privee::reception_clinique",
    "Reception"
  ],
  [
    "dispensaire-public::salle_attente",
    "Salle d'attente"
  ],
  [
    "commissariat::accueil_police",
    "Accueil"
  ],
  [
    "la-tribune::accueil_tribune",
    "Accueil"
  ],
  [
    "la-tribune::redaction",
    "Redaction"
  ],
  [
    "loge-maconnique::hall_loge",
    "Hall d'accueil"
  ],
  [
    "loge-maconnique::salle_reunion_loge",
    "Salle de Reunion"
  ],
  [
    "universite::amphi",
    "Amphitheatre"
  ],
  [
    "universite::salle_reunion",
    "Salle de Réunion"
  ],
  [
    "mairie-capitale::hall_mairie",
    "Hall d'accueil"
  ],
  [
    "mairie-capitale::bureau_maire",
    "Bureau du Maire"
  ],
  [
    "mairie-capitale::bureau_maire_adjoint",
    "Bureau du Maire Adjoint"
  ],
  [
    "mairie-capitale::salle_elections",
    "Salle des Elections"
  ],
  [
    "mairie-capitale::salle_archives",
    "Salle des Archives"
  ],
  [
    "musee-port-sainte-marie::hall",
    "Hall d'accueil"
  ],
  [
    "musee-port-sainte-marie::salle_honneur_militaire",
    "Salle d'Honneur Militaire"
  ],
  [
    "musee-port-sainte-marie::salle_scandales",
    "Salle des Scandales et Affaires"
  ],
  [
    "musee-novomirsk::hall",
    "Hall d'accueil"
  ],
  [
    "musee-novomirsk::salle_honneur_militaire",
    "Salle d'Honneur Militaire"
  ],
  [
    "musee-novomirsk::salle_unions",
    "Salle des Unions Célèbres"
  ],
  [
    "musee-novomirsk::salle_scandales",
    "Salle des Scandales et Affaires"
  ],
  [
    "centre-commercial::hall",
    "Hall d'Entrée"
  ],
  [
    "centre-affaires::hall",
    "Hall d'Entrée"
  ],
  [
    "mairie::accueil_mairie",
    "Accueil"
  ],
  [
    "mairie::bureau_maire_local",
    "Bureau du Maire"
  ],
  [
    "mairie::bureau_maire_adjoint",
    "Bureau du Maire Adjoint"
  ],
  [
    "hotel-port::hall_port",
    "Hall"
  ],
  [
    "hotel-port::chambre_port",
    "Chambre"
  ],
  [
    "bar-des-pecheurs::salle_bar",
    "Salle du bar"
  ],
  [
    "services-sociaux-montrouge::accueil",
    "Accueil"
  ],
  [
    "usine-principale::direction_usine",
    "Direction"
  ],
  [
    "hotel-mineur::hall_mineur",
    "Hall"
  ],
  [
    "hotel-mineur::chambre_mineur",
    "Chambre"
  ],
  [
    "banque-locale::guichet",
    "Guichet"
  ],
  [
    "dispensaire-public-v::attente",
    "Salle d'attente"
  ],
  [
    "commissariat-local::accueil_loc",
    "Accueil"
  ],
  [
    "commissariat-local::geoles",
    "Geôles"
  ],
  [
    "tribunal-local::salle_audience_locale",
    "Salle d'audience"
  ],
  [
    "tribunal-local::bureau_magistrats",
    "Bureau des magistrats"
  ],
  [
    "tribunal-local::greffe",
    "Greffe"
  ],
  [
    "imprimerie-librairie::atelier",
    "Atelier d'Imprimerie"
  ],
  [
    "capitaine-sauvage::salle_principale",
    "Salle Principale"
  ],
  [
    "chasse-peche-psm::boutique",
    "Boutique"
  ],
  [
    "ecole-marine::hall",
    "Hall d'accueil"
  ],
  [
    "ecole-marine::salle_cours",
    "Salle de cours"
  ],
  [
    "chantier-naval::bureau",
    "Bureau"
  ],
  [
    "notre-dame-mer::hall",
    "Accueil"
  ],
  [
    "notre-dame-mer::nef",
    "Nef"
  ],
  [
    "port-plaisance-psm::capitainerie",
    "Capitainerie"
  ],
  [
    "terrain-a-batir-8::terrain8",
    "Terrain"
  ],
  [
    "terrain-a-batir-9::terrain9",
    "Terrain"
  ],
  [
    "terrain-a-batir-10::terrain10",
    "Terrain"
  ],
  [
    "terrain-a-batir-11::terrain11",
    "Terrain"
  ],
  [
    "terrain-a-batir-psm-12::terrain",
    "Terrain"
  ],
  [
    "terrain-a-batir-psm-13::terrain",
    "Terrain"
  ],
  [
    "terrain-a-batir-2::terrain",
    "Terrain"
  ],
  [
    "terrain-a-batir-3::terrain",
    "Terrain"
  ],
  [
    "caserne-militaire::corps_garde",
    "Corps de Garde"
  ],
  [
    "caserne-militaire::infirmerie",
    "Infirmerie"
  ],
  [
    "caserne-militaire::salle_commandement",
    "Salle de Commandement"
  ],
  [
    "caserne-militaire::armurerie_militaire",
    "Armurerie Militaire"
  ],
  [
    "caserne-militaire::refectoire",
    "Réfectoire"
  ],
  [
    "caserne-militaire::salle_faits_armes",
    "Salle des Faits d'Armes"
  ],
  [
    "caserne-militaire::quartier_troupes",
    "Quartier des Troupes"
  ],
  [
    "musee-ville-luthecia::hall",
    "Hall d'accueil"
  ],
  [
    "musee-ville-luthecia::salle_criminels",
    "Salle des Grands Criminels"
  ],
  [
    "musee-ville-luthecia::salle_maires",
    "Salle des Maires de Luthécia"
  ],
  [
    "musee-ville-luthecia::salle_organisations",
    "Salle des Organisations"
  ],
  [
    "musee-ville-luthecia::salle_plumes",
    "Salle des Plumes"
  ],
  [
    "musee-ville-luthecia::salle_honneur_militaire",
    "Salle d'Honneur Militaire"
  ],
  [
    "musee-ville-luthecia::salle_unions",
    "Salle des Unions Célèbres"
  ],
  [
    "musee-ville-luthecia::salle_scandales",
    "Salle des Scandales et Affaires"
  ],
  [
    "musee-national-republia::hall",
    "Hall d'accueil"
  ],
  [
    "pavillon-ambassadeurs-novomirsk::bar",
    "Bar"
  ],
  [
    "station-service-krasnov::boutique_station",
    "Boutique"
  ],
  [
    "entrepot-logistique-novomirsk::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "entrepot-logistique-novomirsk::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "siege-renseignement::accueil_renseignement",
    "Accueil"
  ],
  [
    "entrepot-logistique-montrouge::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "entrepot-logistique-montrouge::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "entrepot-logistique-krasnov::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "entrepot-logistique-krasnov::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "raffinerie-montrouge::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "raffinerie-montrouge::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "raffinerie-montrouge::salle_production",
    "Salle de Production"
  ],
  [
    "bureau-national-emploi::accueil",
    "Accueil"
  ],
  [
    "pole-tabac-alcools-psm::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "pole-tabac-alcools-psm::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "entrepot-logistique-psm::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "entrepot-logistique-psm::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "entrepot-logistique-luthecia::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "entrepot-logistique-luthecia::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "usine-pharmaceutique-luthecia::salle_ventes",
    "Salle des Ventes"
  ],
  [
    "usine-pharmaceutique-luthecia::bureau_direction",
    "Bureau de Direction"
  ],
  [
    "usine-pharmaceutique-luthecia::salle_production",
    "Salle de Production"
  ],
  [
    "centre-multinodal-luthecia::hall_gare",
    "Hall Principal"
  ],
  [
    "centre-multinodal-luthecia::hall_douanes",
    "Hall des Douanes"
  ],
  [
    "centre-multinodal-port-sainte-marie::hall_gare_psm",
    "Hall de la Gare"
  ],
  [
    "centre-multinodal-montrouge::hall_gare_montrouge",
    "Hall de la Gare"
  ],
  [
    "port-sainte-marie::criee",
    "Criée"
  ],
  [
    "port-sainte-marie::entrepot",
    "Entrepôts"
  ],
  [
    "port-sainte-marie::douanes",
    "Douanes"
  ]
]);
const resources=global.RP_I18N_RESOURCES;
if(resources)for(const [locale,entries] of Object.entries(rows)){
 if(resources[locale]?.translation)resources[locale].translation.commonRoomLabels=entries;
}
function label(buildingId,roomId,original){
 if(typeof original!=='string')return original;
 if(scopes.get(buildingId+'::'+roomId)!==original)return original;
 if(global.RP_I18N_GAME_ENABLED!==true)return original;
 const lang=global.RPPlateauI18n?.language?.()||'fr';
 if(lang==='fr')return original;
 return rows[lang]?.[original]||original;
}
global.RPCommonRoomI18n=Object.freeze({label,words:rows,scopes});
})(window);
