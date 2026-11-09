/* Traductions d'orientation et du guichet de transport.
 * Présentation uniquement. Aucun itinéraire, frais, droit, action ou nom de lieu modifié.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const catalog={
  "fr": {
    "nationalInstitutions": "Institutions nationales",
    "youAreHere": "Vous êtes ici",
    "information": "information",
    "readOnly": "lecture seule",
    "foreignTravelHelp": "Utilisez l'aeroport ou le port pour vous rendre dans cet empire.",
    "foreignTravelBlocked": "Vous ne pouvez pas vous rendre ici sans passer par l'aeroport ou le port.",
    "capitalPrefix": "Capitale de ",
    "capital": "Capitale",
    "city": "Ville",
    "destinationEmpire": "DESTINATION — EMPIRE",
    "destination": "DESTINATION",
    "groupPriceNote": "Tarif par voyageur, PJ et PNJ compris. Le chef paie pour tout le groupe ; le coût en PA de cet ordre reste inchangé.",
    "transportTitleTrain": "Prendre le Train",
    "transportTitleBus": "Prendre le Bus/Taxi",
    "transportTitleAvion": "Prendre le Avion",
    "transportTitleBateau": "Prendre le Bateau",
    "transportDescTrain": "Intra-empire uniquement. Plus économique.",
    "transportDescBus": "Intra-empire. Rapide.",
    "transportDescAvion": "Inter-empire. Contrôle douanes obligatoire.",
    "transportDescBateau": "Inter-empire. Moins cher, plus lent.",
    "transportRequired": "Transport requis",
    "transportRequiredMessage": "Pour voyager entre les villes, rendez-vous au Centre Multinodal.",
    "specialAreaMessage": "Cette zone n'est accessible que via un taxi depuis le centre multinodal."
  },
  "en": {
    "nationalInstitutions": "National institutions",
    "youAreHere": "You are here",
    "information": "information",
    "readOnly": "view only",
    "foreignTravelHelp": "Use the airport or port to travel to this empire.",
    "foreignTravelBlocked": "You cannot travel here without going through the airport or port.",
    "capitalPrefix": "Capital of ",
    "capital": "Capital",
    "city": "City",
    "destinationEmpire": "DESTINATION — EMPIRE",
    "destination": "DESTINATION",
    "groupPriceNote": "Fare per traveller, including player characters and NPCs. The group leader pays for everyone; this order's AP cost remains unchanged.",
    "transportTitleTrain": "Take the train",
    "transportTitleBus": "Take the bus/taxi",
    "transportTitleAvion": "Take a flight",
    "transportTitleBateau": "Take the boat",
    "transportDescTrain": "Within the empire only. More economical.",
    "transportDescBus": "Within the empire. Fast.",
    "transportDescAvion": "Between empires. Customs inspection required.",
    "transportDescBateau": "Between empires. Cheaper, but slower.",
    "transportRequired": "Transport required",
    "transportRequiredMessage": "To travel between cities, go to the Multimodal Centre.",
    "specialAreaMessage": "This area can only be reached by taxi from the Multimodal Centre."
  },
  "es": {
    "nationalInstitutions": "Instituciones nacionales",
    "youAreHere": "Estás aquí",
    "information": "información",
    "readOnly": "solo lectura",
    "foreignTravelHelp": "Utiliza el aeropuerto o el puerto para viajar a este imperio.",
    "foreignTravelBlocked": "No puedes viajar aquí sin pasar por el aeropuerto o el puerto.",
    "capitalPrefix": "Capital de ",
    "capital": "Capital",
    "city": "Ciudad",
    "destinationEmpire": "DESTINO — IMPERIO",
    "destination": "DESTINO",
    "groupPriceNote": "Tarifa por viajero, incluidos personajes jugadores y PNJ. El líder paga por todo el grupo; el coste en PA de esta orden no cambia.",
    "transportTitleTrain": "Tomar el tren",
    "transportTitleBus": "Tomar el autobús/taxi",
    "transportTitleAvion": "Tomar un avión",
    "transportTitleBateau": "Tomar el barco",
    "transportDescTrain": "Solo dentro del imperio. Más económico.",
    "transportDescBus": "Dentro del imperio. Rápido.",
    "transportDescAvion": "Entre imperios. Control aduanero obligatorio.",
    "transportDescBateau": "Entre imperios. Más barato, pero más lento.",
    "transportRequired": "Transporte obligatorio",
    "transportRequiredMessage": "Para viajar entre ciudades, dirígete al Centro Multimodal.",
    "specialAreaMessage": "Solo se puede acceder a esta zona en taxi desde el Centro Multimodal."
  },
  "zh-TW": {
    "nationalInstitutions": "國家機構",
    "youAreHere": "你在這裡",
    "information": "資訊",
    "readOnly": "唯讀",
    "foreignTravelHelp": "請從機場或港口前往這個帝國。",
    "foreignTravelBlocked": "若未經機場或港口，就無法前往此處。",
    "capitalPrefix": "首都所在地：",
    "capital": "首都",
    "city": "城市",
    "destinationEmpire": "目的地 — 帝國",
    "destination": "目的地",
    "groupPriceNote": "每名旅客均須付費，包括玩家角色與 NPC。隊長代全隊付款；此指令的行動點數消耗不變。",
    "transportTitleTrain": "搭乘火車",
    "transportTitleBus": "搭乘巴士／計程車",
    "transportTitleAvion": "搭乘飛機",
    "transportTitleBateau": "搭乘船舶",
    "transportDescTrain": "僅限帝國境內，較經濟實惠。",
    "transportDescBus": "帝國境內交通，速度快。",
    "transportDescAvion": "跨帝國交通，須接受海關檢查。",
    "transportDescBateau": "跨帝國交通，較便宜但較慢。",
    "transportRequired": "需要交通工具",
    "transportRequiredMessage": "若要往返城市，請前往綜合交通中心。",
    "specialAreaMessage": "此區域只能從綜合交通中心搭乘計程車抵達。"
  },
  "ru": {
    "nationalInstitutions": "Государственные учреждения",
    "youAreHere": "Вы здесь",
    "information": "информация",
    "readOnly": "только просмотр",
    "foreignTravelHelp": "Чтобы попасть в эту империю, воспользуйтесь аэропортом или портом.",
    "foreignTravelBlocked": "Сюда можно попасть только через аэропорт или порт.",
    "capitalPrefix": "Столица страны ",
    "capital": "Столица",
    "city": "Город",
    "destinationEmpire": "ПУНКТ НАЗНАЧЕНИЯ — ИМПЕРИЯ",
    "destination": "ПУНКТ НАЗНАЧЕНИЯ",
    "groupPriceNote": "Плата взимается за каждого пассажира, включая игроков и НИП. Руководитель оплачивает поездку всей группы; стоимость этого приказа в ОД не меняется.",
    "transportTitleTrain": "Сесть на поезд",
    "transportTitleBus": "Поехать на автобусе/такси",
    "transportTitleAvion": "Полететь на самолёте",
    "transportTitleBateau": "Отправиться на корабле",
    "transportDescTrain": "Только внутри империи. Экономичнее.",
    "transportDescBus": "Внутри империи. Быстро.",
    "transportDescAvion": "Между империями. Обязательный таможенный контроль.",
    "transportDescBateau": "Между империями. Дешевле, но медленнее.",
    "transportRequired": "Требуется транспорт",
    "transportRequiredMessage": "Для поездок между городами отправляйтесь в мультимодальный транспортный центр.",
    "specialAreaMessage": "В эту зону можно попасть только на такси из мультимодального центра."
  },
  "ko": {
    "nationalInstitutions": "국가 기관",
    "youAreHere": "현재 위치",
    "information": "정보",
    "readOnly": "열람 전용",
    "foreignTravelHelp": "이 제국으로 이동하려면 공항이나 항구를 이용하세요.",
    "foreignTravelBlocked": "공항이나 항구를 거치지 않고는 이곳에 갈 수 없습니다.",
    "capitalPrefix": "수도: ",
    "capital": "수도",
    "city": "도시",
    "destinationEmpire": "목적지 — 제국",
    "destination": "목적지",
    "groupPriceNote": "플레이어 캐릭터와 NPC를 포함해 여행자마다 요금이 부과됩니다. 그룹장이 전원의 요금을 지불하며, 이 명령의 행동력 소모는 그대로입니다.",
    "transportTitleTrain": "기차 타기",
    "transportTitleBus": "버스/택시 타기",
    "transportTitleAvion": "비행기 타기",
    "transportTitleBateau": "배 타기",
    "transportDescTrain": "제국 내부 이동 전용. 더 저렴합니다.",
    "transportDescBus": "제국 내부 이동. 빠릅니다.",
    "transportDescAvion": "제국 간 이동. 세관 검사가 필수입니다.",
    "transportDescBateau": "제국 간 이동. 더 저렴하지만 느립니다.",
    "transportRequired": "교통수단 필요",
    "transportRequiredMessage": "도시 사이를 이동하려면 복합 교통센터로 가세요.",
    "specialAreaMessage": "이 구역은 복합 교통센터에서 택시로만 갈 수 있습니다."
  },
  "ar": {
    "nationalInstitutions": "المؤسسات الوطنية",
    "youAreHere": "أنت هنا",
    "information": "معلومات",
    "readOnly": "للعرض فقط",
    "foreignTravelHelp": "استخدم المطار أو الميناء للسفر إلى هذه الإمبراطورية.",
    "foreignTravelBlocked": "لا يمكنك الوصول إلى هنا دون المرور عبر المطار أو الميناء.",
    "capitalPrefix": "عاصمة ",
    "capital": "العاصمة",
    "city": "مدينة",
    "destinationEmpire": "الوجهة — الإمبراطورية",
    "destination": "الوجهة",
    "groupPriceNote": "تُحتسب الأجرة لكل مسافر، بما في ذلك شخصيات اللاعبين والشخصيات غير اللاعبة. يدفع قائد المجموعة عن الجميع، ولا تتغير تكلفة هذا الأمر بنقاط الحركة.",
    "transportTitleTrain": "ركوب القطار",
    "transportTitleBus": "ركوب الحافلة أو سيارة الأجرة",
    "transportTitleAvion": "ركوب الطائرة",
    "transportTitleBateau": "ركوب السفينة",
    "transportDescTrain": "داخل الإمبراطورية فقط. أقل تكلفة.",
    "transportDescBus": "داخل الإمبراطورية. سريع.",
    "transportDescAvion": "بين الإمبراطوريات. التفتيش الجمركي إلزامي.",
    "transportDescBateau": "بين الإمبراطوريات. أرخص لكنه أبطأ.",
    "transportRequired": "وسيلة نقل مطلوبة",
    "transportRequiredMessage": "للسفر بين المدن، توجّه إلى مركز النقل متعدد الوسائط.",
    "specialAreaMessage": "لا يمكن الوصول إلى هذه المنطقة إلا بسيارة أجرة من مركز النقل متعدد الوسائط."
  },
  "pt-BR": {
    "nationalInstitutions": "Instituições nacionais",
    "youAreHere": "Você está aqui",
    "information": "informações",
    "readOnly": "somente leitura",
    "foreignTravelHelp": "Use o aeroporto ou o porto para viajar até este império.",
    "foreignTravelBlocked": "Você não pode chegar aqui sem passar pelo aeroporto ou pelo porto.",
    "capitalPrefix": "Capital de ",
    "capital": "Capital",
    "city": "Cidade",
    "destinationEmpire": "DESTINO — IMPÉRIO",
    "destination": "DESTINO",
    "groupPriceNote": "Tarifa por viajante, incluindo personagens jogadores e NPCs. O líder paga pelo grupo inteiro; o custo desta ordem em PA permanece inalterado.",
    "transportTitleTrain": "Pegar o trem",
    "transportTitleBus": "Pegar o ônibus/táxi",
    "transportTitleAvion": "Pegar o avião",
    "transportTitleBateau": "Pegar o barco",
    "transportDescTrain": "Apenas dentro do império. Mais econômico.",
    "transportDescBus": "Dentro do império. Rápido.",
    "transportDescAvion": "Entre impérios. Inspeção alfandegária obrigatória.",
    "transportDescBateau": "Entre impérios. Mais barato, porém mais lento.",
    "transportRequired": "Transporte necessário",
    "transportRequiredMessage": "Para viajar entre cidades, dirija-se ao Centro Multimodal.",
    "specialAreaMessage": "Esta área só pode ser acessada de táxi a partir do Centro Multimodal."
  },
  "de": {
    "nationalInstitutions": "Nationale Institutionen",
    "youAreHere": "Sie sind hier",
    "information": "Information",
    "readOnly": "nur Ansicht",
    "foreignTravelHelp": "Nutzen Sie den Flughafen oder Hafen, um in dieses Imperium zu reisen.",
    "foreignTravelBlocked": "Sie können diesen Ort nur über den Flughafen oder Hafen erreichen.",
    "capitalPrefix": "Hauptstadt von ",
    "capital": "Hauptstadt",
    "city": "Stadt",
    "destinationEmpire": "REISEZIEL — IMPERIUM",
    "destination": "REISEZIEL",
    "groupPriceNote": "Der Fahrpreis gilt pro Reisendem, einschließlich Spielerfiguren und NSC. Der Gruppenführer bezahlt für alle; die AP-Kosten dieses Befehls bleiben unverändert.",
    "transportTitleTrain": "Mit dem Zug fahren",
    "transportTitleBus": "Bus/Taxi nehmen",
    "transportTitleAvion": "Mit dem Flugzeug reisen",
    "transportTitleBateau": "Mit dem Schiff fahren",
    "transportDescTrain": "Nur innerhalb des Imperiums. Günstiger.",
    "transportDescBus": "Innerhalb des Imperiums. Schnell.",
    "transportDescAvion": "Zwischen Imperien. Zollkontrolle erforderlich.",
    "transportDescBateau": "Zwischen Imperien. Günstiger, aber langsamer.",
    "transportRequired": "Transport erforderlich",
    "transportRequiredMessage": "Für Reisen zwischen Städten begeben Sie sich zum Multimodalen Verkehrszentrum.",
    "specialAreaMessage": "Dieses Gebiet ist nur per Taxi vom Multimodalen Verkehrszentrum aus erreichbar."
  }
};
 // "Bâtiments" correspond au libellé historique littéral du petit plan de ville.
 const buildings={
  fr:"Batiments",en:"Buildings",es:"Edificios","zh-TW":"建築物",ru:"Здания",
  ko:"건물",ar:"المباني","pt-BR":"Edifícios",de:"Gebäude"
 };
 for(const [locale,value] of Object.entries(buildings))catalog[locale].buildings=value;
 for(const [locale,strings] of Object.entries(catalog))
  if(resources[locale]?.translation) resources[locale].translation.navigation={...strings};
 const french=catalog.fr;
 function label(key,original){
  if(typeof original!=='string'||!Object.hasOwn(french,key)||french[key]!==original)return original;
  if(global.RP_I18N_GAME_ENABLED!==true)return original;
  const locale=global.RPPlateauI18n?.language?.()||'fr';
  if(locale==='fr')return original;
  const translated=resources[locale]?.translation?.navigation?.[key];
  return typeof translated==='string'&&translated.trim()?translated:original;
 }
 function labelHtml(key,original){
  const translated=label(key,original);
  // Texte uniquement, jamais de HTML interprétable dans SVG, modales ni boutons.
  return translated.replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
 }
 global.RPNavigationI18n=Object.freeze({label,labelHtml});
})(window);
