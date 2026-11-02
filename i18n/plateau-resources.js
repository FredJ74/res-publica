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
  for(const [locale,labels] of Object.entries(translations)) {
    if(resources[locale]?.translation) resources[locale].translation.plateau={...labels};
  }
})(window);
