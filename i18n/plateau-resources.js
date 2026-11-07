/* Ressources d'interface du plateau, uniquement quand i18next est chargé.
 * Aucune action métier ni mutation serveur.
 */
(function(global){
  'use strict';
  const resources=global.RP_I18N_RESOURCES;
  if(!resources) return;
  const translations={
  "fr": {
    "character": "Mon personnage",
    "money": "Argent",
    "cash": "Argent liquide",
    "bank": "En banque",
    "inventory": "Inventaire",
    "cityMap": "Plan de la ville",
    "peoplePresent": "Personnes présentes",
    "availableActions": "Actions disponibles",
    "eventJournal": "Journal des événements",
    "combatReports": "Rapports de combat",
    "messages": "Messages",
    "newMessage": "Nouveau message",
    "room": "Pièce",
    "description": "Description"
  },
  "en": {
    "character": "My Character",
    "money": "Money",
    "cash": "Cash",
    "bank": "In bank",
    "inventory": "Inventory",
    "cityMap": "City map",
    "peoplePresent": "People present",
    "availableActions": "Available actions",
    "eventJournal": "Event journal",
    "combatReports": "Combat reports",
    "messages": "Messages",
    "newMessage": "New message",
    "room": "Room",
    "description": "Description"
  },
  "es": {
    "character": "Mi personaje",
    "money": "Dinero",
    "cash": "Efectivo",
    "bank": "En el banco",
    "inventory": "Inventario",
    "cityMap": "Mapa de la ciudad",
    "peoplePresent": "Personas presentes",
    "availableActions": "Acciones disponibles",
    "eventJournal": "Diario de sucesos",
    "combatReports": "Informes de combate",
    "messages": "Mensajes",
    "newMessage": "Nuevo mensaje",
    "room": "Sala",
    "description": "Descripción"
  },
  "zh-TW": {
    "character": "我的角色",
    "money": "金錢",
    "cash": "現金",
    "bank": "銀行存款",
    "inventory": "物品欄",
    "cityMap": "城市地圖",
    "peoplePresent": "在場人物",
    "availableActions": "可用行動",
    "eventJournal": "事件日誌",
    "combatReports": "戰鬥報告",
    "messages": "訊息",
    "newMessage": "新訊息",
    "room": "房間",
    "description": "說明"
  },
  "ru": {
    "character": "Мой персонаж",
    "money": "Деньги",
    "cash": "Наличные",
    "bank": "В банке",
    "inventory": "Инвентарь",
    "cityMap": "Карта города",
    "peoplePresent": "Присутствующие",
    "availableActions": "Доступные действия",
    "eventJournal": "Журнал событий",
    "combatReports": "Боевые отчёты",
    "messages": "Сообщения",
    "newMessage": "Новое сообщение",
    "room": "Помещение",
    "description": "Описание"
  },
  "ko": {
    "character": "내 캐릭터",
    "money": "돈",
    "cash": "현금",
    "bank": "은행 잔액",
    "inventory": "소지품",
    "cityMap": "도시 지도",
    "peoplePresent": "현재 인물",
    "availableActions": "가능한 행동",
    "eventJournal": "이벤트 기록",
    "combatReports": "전투 보고서",
    "messages": "메시지",
    "newMessage": "새 메시지",
    "room": "방",
    "description": "설명"
  },
  "ar": {
    "character": "شخصيتي",
    "money": "المال",
    "cash": "نقدًا",
    "bank": "في البنك",
    "inventory": "المخزون",
    "cityMap": "خريطة المدينة",
    "peoplePresent": "الأشخاص الموجودون",
    "availableActions": "الأفعال المتاحة",
    "eventJournal": "سجل الأحداث",
    "combatReports": "تقارير القتال",
    "messages": "الرسائل",
    "newMessage": "رسالة جديدة",
    "room": "الغرفة",
    "description": "الوصف"
  },
  "pt-BR": {
    "character": "Meu personagem",
    "money": "Dinheiro",
    "cash": "Dinheiro em espécie",
    "bank": "No banco",
    "inventory": "Inventário",
    "cityMap": "Mapa da cidade",
    "peoplePresent": "Pessoas presentes",
    "availableActions": "Ações disponíveis",
    "eventJournal": "Diário de eventos",
    "combatReports": "Relatórios de combate",
    "messages": "Mensagens",
    "newMessage": "Nova mensagem",
    "room": "Sala",
    "description": "Descrição"
  },
  "de": {
    "character": "Mein Charakter",
    "money": "Geld",
    "cash": "Bargeld",
    "bank": "Auf der Bank",
    "inventory": "Inventar",
    "cityMap": "Stadtplan",
    "peoplePresent": "Anwesende Personen",
    "availableActions": "Verfügbare Aktionen",
    "eventJournal": "Ereignisjournal",
    "combatReports": "Kampfberichte",
    "messages": "Nachrichten",
    "newMessage": "Neue Nachricht",
    "room": "Raum",
    "description": "Beschreibung"
  }
};
  const extendedLabels={
  "fr": {
    "personalActions": "Actions personnelles",
    "organizations": "Organisations",
    "identity": "Identité",
    "statistics": "Statistiques",
    "rules": "Règles du jeu",
    "localForum": "Forum local",
    "mailbox": "Boîte mail",
    "receivedMessages": "Messages reçus",
    "financeManagement": "Gestion des finances",
    "characterSheet": "Fiche de personnage",
    "conversation": "Conversation",
    "forum": "Forum"
  },
  "en": {
    "personalActions": "Personal actions",
    "organizations": "Organizations",
    "identity": "Identity",
    "statistics": "Statistics",
    "rules": "Game rules",
    "localForum": "Local forum",
    "mailbox": "Mailbox",
    "receivedMessages": "Received messages",
    "financeManagement": "Financial management",
    "characterSheet": "Character sheet",
    "conversation": "Conversation",
    "forum": "Forum"
  },
  "es": {
    "personalActions": "Acciones personales",
    "organizations": "Organizaciones",
    "identity": "Identidad",
    "statistics": "Estadísticas",
    "rules": "Reglas del juego",
    "localForum": "Foro local",
    "mailbox": "Buzón",
    "receivedMessages": "Mensajes recibidos",
    "financeManagement": "Gestión financiera",
    "characterSheet": "Ficha de personaje",
    "conversation": "Conversación",
    "forum": "Foro"
  },
  "zh-TW": {
    "personalActions": "個人行動",
    "organizations": "組織",
    "identity": "身分",
    "statistics": "統計",
    "rules": "遊戲規則",
    "localForum": "本地論壇",
    "mailbox": "信箱",
    "receivedMessages": "收到的訊息",
    "financeManagement": "財務管理",
    "characterSheet": "角色資料",
    "conversation": "對話",
    "forum": "論壇"
  },
  "ru": {
    "personalActions": "Личные действия",
    "organizations": "Организации",
    "identity": "Личность",
    "statistics": "Характеристики",
    "rules": "Правила игры",
    "localForum": "Местный форум",
    "mailbox": "Почта",
    "receivedMessages": "Входящие сообщения",
    "financeManagement": "Управление финансами",
    "characterSheet": "Карточка персонажа",
    "conversation": "Разговор",
    "forum": "Форум"
  },
  "ko": {
    "personalActions": "개인 행동",
    "organizations": "조직",
    "identity": "신원",
    "statistics": "능력치",
    "rules": "게임 규칙",
    "localForum": "지역 게시판",
    "mailbox": "우편함",
    "receivedMessages": "받은 메시지",
    "financeManagement": "재정 관리",
    "characterSheet": "캐릭터 정보",
    "conversation": "대화",
    "forum": "게시판"
  },
  "ar": {
    "personalActions": "الأفعال الشخصية",
    "organizations": "المنظمات",
    "identity": "الهوية",
    "statistics": "الإحصاءات",
    "rules": "قواعد اللعبة",
    "localForum": "المنتدى المحلي",
    "mailbox": "صندوق البريد",
    "receivedMessages": "الرسائل الواردة",
    "financeManagement": "الإدارة المالية",
    "characterSheet": "بطاقة الشخصية",
    "conversation": "المحادثة",
    "forum": "المنتدى"
  },
  "pt-BR": {
    "personalActions": "Ações pessoais",
    "organizations": "Organizações",
    "identity": "Identidade",
    "statistics": "Estatísticas",
    "rules": "Regras do jogo",
    "localForum": "Fórum local",
    "mailbox": "Caixa de correio",
    "receivedMessages": "Mensagens recebidas",
    "financeManagement": "Gestão financeira",
    "characterSheet": "Ficha de personagem",
    "conversation": "Conversa",
    "forum": "Fórum"
  },
  "de": {
    "personalActions": "Persönliche Aktionen",
    "organizations": "Organisationen",
    "identity": "Identität",
    "statistics": "Statistiken",
    "rules": "Spielregeln",
    "localForum": "Lokales Forum",
    "mailbox": "Postfach",
    "receivedMessages": "Eingegangene Nachrichten",
    "financeManagement": "Finanzverwaltung",
    "characterSheet": "Charakterbogen",
    "conversation": "Gespräch",
    "forum": "Forum"
  }
};
  for(const [locale,labels] of Object.entries(extendedLabels)) Object.assign(translations[locale],labels);
  const secondaryLabels={
  "fr": {
    "building": "Bâtiment",
    "category": "Catégorie",
    "worldMap": "Carte du monde",
    "orgChart": "Organigramme",
    "postalCard": "Carte postale",
    "subject": "Sujet",
    "messageLabel": "Message",
    "citizen": "Citoyen",
    "streetHint": "Dans la rue — Cliquez sur un bâtiment pour entrer",
    "noItems": "Aucun objet",
    "gameGuide": "Res Publica — Guide du joueur"
  },
  "en": {
    "building": "Building",
    "category": "Category",
    "worldMap": "World map",
    "orgChart": "Organization chart",
    "postalCard": "Postcard",
    "subject": "Subject",
    "messageLabel": "Message",
    "citizen": "Citizen",
    "streetHint": "In the street — Click a building to enter",
    "noItems": "No items",
    "gameGuide": "Res Publica — Player guide"
  },
  "es": {
    "building": "Edificio",
    "category": "Categoría",
    "worldMap": "Mapa del mundo",
    "orgChart": "Organigrama",
    "postalCard": "Tarjeta postal",
    "subject": "Asunto",
    "messageLabel": "Mensaje",
    "citizen": "Ciudadano",
    "streetHint": "En la calle — Haz clic en un edificio para entrar",
    "noItems": "Sin objetos",
    "gameGuide": "Res Publica — Guía del jugador"
  },
  "zh-TW": {
    "building": "建築",
    "category": "類別",
    "worldMap": "世界地圖",
    "orgChart": "組織架構",
    "postalCard": "明信片",
    "subject": "主旨",
    "messageLabel": "訊息",
    "citizen": "公民",
    "streetHint": "街道上 — 點選建築即可進入",
    "noItems": "沒有物品",
    "gameGuide": "Res Publica — 玩家指南"
  },
  "ru": {
    "building": "Здание",
    "category": "Категория",
    "worldMap": "Карта мира",
    "orgChart": "Организационная схема",
    "postalCard": "Открытка",
    "subject": "Тема",
    "messageLabel": "Сообщение",
    "citizen": "Гражданин",
    "streetHint": "На улице — Нажмите на здание, чтобы войти",
    "noItems": "Нет предметов",
    "gameGuide": "Res Publica — Руководство игрока"
  },
  "ko": {
    "building": "건물",
    "category": "분류",
    "worldMap": "세계 지도",
    "orgChart": "조직도",
    "postalCard": "엽서",
    "subject": "제목",
    "messageLabel": "메시지",
    "citizen": "시민",
    "streetHint": "거리 — 건물을 눌러 입장하세요",
    "noItems": "아이템 없음",
    "gameGuide": "Res Publica — 플레이어 안내서"
  },
  "ar": {
    "building": "المبنى",
    "category": "الفئة",
    "worldMap": "خريطة العالم",
    "orgChart": "الهيكل التنظيمي",
    "postalCard": "بطاقة بريدية",
    "subject": "الموضوع",
    "messageLabel": "الرسالة",
    "citizen": "مواطن",
    "streetHint": "في الشارع — انقر على مبنى للدخول إليه",
    "noItems": "لا توجد أغراض",
    "gameGuide": "Res Publica — دليل اللاعب"
  },
  "pt-BR": {
    "building": "Edifício",
    "category": "Categoria",
    "worldMap": "Mapa do mundo",
    "orgChart": "Organograma",
    "postalCard": "Cartão-postal",
    "subject": "Assunto",
    "messageLabel": "Mensagem",
    "citizen": "Cidadão",
    "streetHint": "Na rua — Clique em um edifício para entrar",
    "noItems": "Nenhum item",
    "gameGuide": "Res Publica — Guia do jogador"
  },
  "de": {
    "building": "Gebäude",
    "category": "Kategorie",
    "worldMap": "Weltkarte",
    "orgChart": "Organigramm",
    "postalCard": "Postkarte",
    "subject": "Betreff",
    "messageLabel": "Nachricht",
    "citizen": "Bürger",
    "streetHint": "Auf der Straße — Klicke auf ein Gebäude, um es zu betreten",
    "noItems": "Keine Gegenstände",
    "gameGuide": "Res Publica — Spielerhandbuch"
  }
};
  for(const [locale,labels] of Object.entries(secondaryLabels)) Object.assign(translations[locale],labels);
  const originalControls={
  "fr": {
    "showOriginal": "Voir l’original",
    "showTranslation": "Voir la traduction"
  },
  "en": {
    "showOriginal": "Show original",
    "showTranslation": "Show translation"
  },
  "es": {
    "showOriginal": "Ver original",
    "showTranslation": "Ver traducción"
  },
  "zh-TW": {
    "showOriginal": "查看原文",
    "showTranslation": "查看翻譯"
  },
  "ru": {
    "showOriginal": "Показать оригинал",
    "showTranslation": "Показать перевод"
  },
  "ko": {
    "showOriginal": "원문 보기",
    "showTranslation": "번역 보기"
  },
  "ar": {
    "showOriginal": "عرض النص الأصلي",
    "showTranslation": "عرض الترجمة"
  },
  "pt-BR": {
    "showOriginal": "Ver original",
    "showTranslation": "Ver tradução"
  },
  "de": {
    "showOriginal": "Original anzeigen",
    "showTranslation": "Übersetzung anzeigen"
  }
};
  for(const [locale,labels] of Object.entries(originalControls)) Object.assign(translations[locale],labels);
  // Navigation supérieure : clés purement textuelles, aucun gestionnaire de clic modifié.
  // Les info-bulles sont traduites via data-i18n-title, sans retirer les icônes et badges.
  const navigationLabels={
  "fr": {
    "imperialIndices": "Indices impériaux",
    "rules": "Règles",
    "messagesForums": "Messages/Forums",
    "players": "PJ",
    "orgs": "Orgas",
    "elections": "Élections",
    "worldMap": "Carte",
    "plan": "Plan",
    "indicesTitle": "Indices des 4 empires",
    "forumsTitle": "Messages et Forums",
    "playersTitle": "Liste des joueurs",
    "orgsTitle": "Mes organisations",
    "electionsTitle": "Calendrier électoral",
    "footballTitle": "Rejoindre le match en direct",
    "planTitle": "Plan de la ville",
    "forumActivity": "Nouvelle activité sur le forum"
  },
  "en": {
    "imperialIndices": "Imperial indicators",
    "rules": "Rules",
    "messagesForums": "Messages/Forums",
    "players": "Players",
    "orgs": "Orgs",
    "elections": "Elections",
    "worldMap": "Map",
    "plan": "City plan",
    "indicesTitle": "Indicators for the four empires",
    "forumsTitle": "Messages and forums",
    "playersTitle": "Player directory",
    "orgsTitle": "My organisations",
    "electionsTitle": "Election calendar",
    "footballTitle": "Join the live match",
    "planTitle": "City plan",
    "forumActivity": "New forum activity"
  },
  "es": {
    "imperialIndices": "Indicadores imperiales",
    "rules": "Reglas",
    "messagesForums": "Mensajes/Foros",
    "players": "Jugadores",
    "orgs": "Organiz.",
    "elections": "Elecciones",
    "worldMap": "Mapa",
    "plan": "Plano",
    "indicesTitle": "Indicadores de los cuatro imperios",
    "forumsTitle": "Mensajes y foros",
    "playersTitle": "Lista de jugadores",
    "orgsTitle": "Mis organizaciones",
    "electionsTitle": "Calendario electoral",
    "footballTitle": "Unirse al partido en directo",
    "planTitle": "Plano de la ciudad",
    "forumActivity": "Nueva actividad en el foro"
  },
  "zh-TW": {
    "imperialIndices": "帝國指標",
    "rules": "規則",
    "messagesForums": "訊息／論壇",
    "players": "玩家",
    "orgs": "組織",
    "elections": "選舉",
    "worldMap": "地圖",
    "plan": "市區圖",
    "indicesTitle": "四大帝國的指標",
    "forumsTitle": "訊息與論壇",
    "playersTitle": "玩家名錄",
    "orgsTitle": "我的組織",
    "electionsTitle": "選舉日程",
    "footballTitle": "加入即時比賽",
    "planTitle": "城市地圖",
    "forumActivity": "論壇有新動態"
  },
  "ru": {
    "imperialIndices": "Показатели империй",
    "rules": "Правила",
    "messagesForums": "Сообщения/Форумы",
    "players": "Игроки",
    "orgs": "Организации",
    "elections": "Выборы",
    "worldMap": "Карта",
    "plan": "План города",
    "indicesTitle": "Показатели четырёх империй",
    "forumsTitle": "Сообщения и форумы",
    "playersTitle": "Список игроков",
    "orgsTitle": "Мои организации",
    "electionsTitle": "Календарь выборов",
    "footballTitle": "Присоединиться к матчу",
    "planTitle": "План города",
    "forumActivity": "Новая активность на форуме"
  },
  "ko": {
    "imperialIndices": "제국 지표",
    "rules": "규칙",
    "messagesForums": "메시지/포럼",
    "players": "플레이어",
    "orgs": "조직",
    "elections": "선거",
    "worldMap": "지도",
    "plan": "도시 지도",
    "indicesTitle": "4개 제국의 지표",
    "forumsTitle": "메시지와 포럼",
    "playersTitle": "플레이어 목록",
    "orgsTitle": "내 조직",
    "electionsTitle": "선거 일정",
    "footballTitle": "실시간 경기에 참가",
    "planTitle": "도시 지도",
    "forumActivity": "포럼 새 활동"
  },
  "ar": {
    "imperialIndices": "مؤشرات الإمبراطوريات",
    "rules": "القواعد",
    "messagesForums": "الرسائل/المنتديات",
    "players": "اللاعبون",
    "orgs": "المنظمات",
    "elections": "الانتخابات",
    "worldMap": "الخريطة",
    "plan": "مخطط المدينة",
    "indicesTitle": "مؤشرات الإمبراطوريات الأربع",
    "forumsTitle": "الرسائل والمنتديات",
    "playersTitle": "قائمة اللاعبين",
    "orgsTitle": "منظماتي",
    "electionsTitle": "جدول الانتخابات",
    "footballTitle": "الانضمام إلى المباراة المباشرة",
    "planTitle": "مخطط المدينة",
    "forumActivity": "نشاط جديد في المنتدى"
  },
  "pt-BR": {
    "imperialIndices": "Indicadores imperiais",
    "rules": "Regras",
    "messagesForums": "Mensagens/Fóruns",
    "players": "Jogadores",
    "orgs": "Organiz.",
    "elections": "Eleições",
    "worldMap": "Mapa",
    "plan": "Planta",
    "indicesTitle": "Indicadores dos quatro impérios",
    "forumsTitle": "Mensagens e fóruns",
    "playersTitle": "Lista de jogadores",
    "orgsTitle": "Minhas organizações",
    "electionsTitle": "Calendário eleitoral",
    "footballTitle": "Entrar na partida ao vivo",
    "planTitle": "Mapa da cidade",
    "forumActivity": "Nova atividade no fórum"
  },
  "de": {
    "imperialIndices": "Imperiale Indikatoren",
    "rules": "Regeln",
    "messagesForums": "Nachrichten/Foren",
    "players": "Spieler",
    "orgs": "Orgas",
    "elections": "Wahlen",
    "worldMap": "Karte",
    "plan": "Stadtplan",
    "indicesTitle": "Indikatoren der vier Imperien",
    "forumsTitle": "Nachrichten und Foren",
    "playersTitle": "Spielerverzeichnis",
    "orgsTitle": "Meine Organisationen",
    "electionsTitle": "Wahlkalender",
    "footballTitle": "Am Live-Spiel teilnehmen",
    "planTitle": "Stadtplan",
    "forumActivity": "Neue Aktivität im Forum"
  }
};
  for(const [locale,labels] of Object.entries(navigationLabels)) Object.assign(translations[locale],labels);

  // Onglets du guide et champ destinataire : libellés seulement.
  // Les fonctions de clic et les champs de saisie restent ceux du jeu.
  const rulesAndMail = {
    "fr": {
      "rulesIntro": "Le Grand Jeu",
      "rulesTutorial": "🎓 Tutoriel",
      "rulesCharacter": "Personnage",
      "rulesBoard": "Plateau",
      "rulesPolitics": "Politique",
      "rulesInteractions": "Interactions",
      "rulesEconomy": "Économie",
      "rulesFootball": "⚽ Football",
      "rulesReligion": "Religions",
      "recipient": "À",
      "recipientPlaceholder": "Destinataire...",
      "subjectPlaceholder": "Objet du message...",
      "messagePlaceholder": "Votre message..."
    },
    "en": {
      "rulesIntro": "The Grand Game",
      "rulesTutorial": "🎓 Tutorial",
      "rulesCharacter": "Character",
      "rulesBoard": "Game board",
      "rulesPolitics": "Politics",
      "rulesInteractions": "Interactions",
      "rulesEconomy": "Economy",
      "rulesFootball": "⚽ Football",
      "rulesReligion": "Religions",
      "recipient": "To",
      "recipientPlaceholder": "Recipient...",
      "subjectPlaceholder": "Message subject...",
      "messagePlaceholder": "Your message..."
    },
    "es": {
      "rulesIntro": "El Gran Juego",
      "rulesTutorial": "🎓 Tutorial",
      "rulesCharacter": "Personaje",
      "rulesBoard": "Tablero",
      "rulesPolitics": "Política",
      "rulesInteractions": "Interacciones",
      "rulesEconomy": "Economía",
      "rulesFootball": "⚽ Fútbol",
      "rulesReligion": "Religiones",
      "recipient": "Para",
      "recipientPlaceholder": "Destinatario...",
      "subjectPlaceholder": "Asunto del mensaje...",
      "messagePlaceholder": "Tu mensaje..."
    },
    "zh-TW": {
      "rulesIntro": "權力大遊戲",
      "rulesTutorial": "🎓 教學",
      "rulesCharacter": "角色",
      "rulesBoard": "遊戲地圖",
      "rulesPolitics": "政治",
      "rulesInteractions": "互動",
      "rulesEconomy": "經濟",
      "rulesFootball": "⚽ 足球",
      "rulesReligion": "宗教",
      "recipient": "收件人",
      "recipientPlaceholder": "收件人...",
      "subjectPlaceholder": "訊息主旨...",
      "messagePlaceholder": "您的訊息..."
    },
    "ru": {
      "rulesIntro": "Большая игра",
      "rulesTutorial": "🎓 Обучение",
      "rulesCharacter": "Персонаж",
      "rulesBoard": "Игровое поле",
      "rulesPolitics": "Политика",
      "rulesInteractions": "Взаимодействия",
      "rulesEconomy": "Экономика",
      "rulesFootball": "⚽ Футбол",
      "rulesReligion": "Религии",
      "recipient": "Кому",
      "recipientPlaceholder": "Получатель...",
      "subjectPlaceholder": "Тема сообщения...",
      "messagePlaceholder": "Ваше сообщение..."
    },
    "ko": {
      "rulesIntro": "권력의 대결",
      "rulesTutorial": "🎓 튜토리얼",
      "rulesCharacter": "캐릭터",
      "rulesBoard": "게임판",
      "rulesPolitics": "정치",
      "rulesInteractions": "상호작용",
      "rulesEconomy": "경제",
      "rulesFootball": "⚽ 축구",
      "rulesReligion": "종교",
      "recipient": "받는 사람",
      "recipientPlaceholder": "수신자...",
      "subjectPlaceholder": "메시지 제목...",
      "messagePlaceholder": "메시지를 입력하세요..."
    },
    "ar": {
      "rulesIntro": "اللعبة الكبرى",
      "rulesTutorial": "🎓 دليل المبتدئين",
      "rulesCharacter": "الشخصية",
      "rulesBoard": "لوحة اللعبة",
      "rulesPolitics": "السياسة",
      "rulesInteractions": "التفاعلات",
      "rulesEconomy": "الاقتصاد",
      "rulesFootball": "⚽ كرة القدم",
      "rulesReligion": "الأديان",
      "recipient": "إلى",
      "recipientPlaceholder": "المستلم...",
      "subjectPlaceholder": "موضوع الرسالة...",
      "messagePlaceholder": "رسالتك..."
    },
    "pt-BR": {
      "rulesIntro": "O Grande Jogo",
      "rulesTutorial": "🎓 Tutorial",
      "rulesCharacter": "Personagem",
      "rulesBoard": "Tabuleiro",
      "rulesPolitics": "Política",
      "rulesInteractions": "Interações",
      "rulesEconomy": "Economia",
      "rulesFootball": "⚽ Futebol",
      "rulesReligion": "Religiões",
      "recipient": "Para",
      "recipientPlaceholder": "Destinatário...",
      "subjectPlaceholder": "Assunto da mensagem...",
      "messagePlaceholder": "Sua mensagem..."
    },
    "de": {
      "rulesIntro": "Das große Spiel",
      "rulesTutorial": "🎓 Tutorial",
      "rulesCharacter": "Charakter",
      "rulesBoard": "Spielbrett",
      "rulesPolitics": "Politik",
      "rulesInteractions": "Interaktionen",
      "rulesEconomy": "Wirtschaft",
      "rulesFootball": "⚽ Fußball",
      "rulesReligion": "Religionen",
      "recipient": "An",
      "recipientPlaceholder": "Empfänger...",
      "subjectPlaceholder": "Betreff der Nachricht...",
      "messagePlaceholder": "Ihre Nachricht..."
    }
  };
  for(const [locale,labels] of Object.entries(rulesAndMail)) Object.assign(translations[locale],labels);
  // Boutons de navigation : traduire seulement leur span texte, conserver l'icône.
  const commonButtons = {
    "fr": {
      "closeButton": "Fermer",
      "exitButton": "Sortir",
      "sendButton": "Envoyer",
      "backHomeTitle": "Retour accueil"
    },
    "en": {
      "closeButton": "Close",
      "exitButton": "Exit",
      "sendButton": "Send",
      "backHomeTitle": "Back to home"
    },
    "es": {
      "closeButton": "Cerrar",
      "exitButton": "Salir",
      "sendButton": "Enviar",
      "backHomeTitle": "Volver al inicio"
    },
    "zh-TW": {
      "closeButton": "關閉",
      "exitButton": "離開",
      "sendButton": "傳送",
      "backHomeTitle": "返回首頁"
    },
    "ru": {
      "closeButton": "Закрыть",
      "exitButton": "Выйти",
      "sendButton": "Отправить",
      "backHomeTitle": "На главную"
    },
    "ko": {
      "closeButton": "닫기",
      "exitButton": "나가기",
      "sendButton": "보내기",
      "backHomeTitle": "홈으로 돌아가기"
    },
    "ar": {
      "closeButton": "إغلاق",
      "exitButton": "خروج",
      "sendButton": "إرسال",
      "backHomeTitle": "العودة إلى الصفحة الرئيسية"
    },
    "pt-BR": {
      "closeButton": "Fechar",
      "exitButton": "Sair",
      "sendButton": "Enviar",
      "backHomeTitle": "Voltar ao início"
    },
    "de": {
      "closeButton": "Schließen",
      "exitButton": "Verlassen",
      "sendButton": "Senden",
      "backHomeTitle": "Zur Startseite"
    }
  };
  for(const [locale,labels] of Object.entries(commonButtons)) Object.assign(translations[locale],labels);
  for(const [locale,labels] of Object.entries(translations)) {
    if(resources[locale]?.translation) resources[locale].translation.plateau={...labels};
  }
})(window);
