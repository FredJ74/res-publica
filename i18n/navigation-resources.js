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
    "transportTitleAvion": "Prendre l’Avion",
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
 // Plan de ville déduit des rues : libellés de lecture seule, sans modifier le graphe.
 const planTerms={
  "fr": {
    "planTitlePrefix": "Plan de ",
    "planOfCity": "Plan de la ville",
    "hereSuffix": " — vous êtes ici",
    "hereText": "Vous êtes ici",
    "onStreet": "Vous êtes ici, dans la rue."
  },
  "en": {
    "planTitlePrefix": "Map of ",
    "planOfCity": "City map",
    "hereSuffix": " — you are here",
    "hereText": "You are here",
    "onStreet": "You are here, in the street."
  },
  "es": {
    "planTitlePrefix": "Plano de ",
    "planOfCity": "Plano de la ciudad",
    "hereSuffix": " — estás aquí",
    "hereText": "Estás aquí",
    "onStreet": "Estás aquí, en la calle."
  },
  "zh-TW": {
    "planTitlePrefix": "城市地圖：",
    "planOfCity": "城市地圖",
    "hereSuffix": " — 您在這裡",
    "hereText": "您在這裡",
    "onStreet": "您目前位於街道上。"
  },
  "ru": {
    "planTitlePrefix": "План города ",
    "planOfCity": "План города",
    "hereSuffix": " — вы здесь",
    "hereText": "Вы здесь",
    "onStreet": "Вы здесь, на улице."
  },
  "ko": {
    "planTitlePrefix": "도시 지도: ",
    "planOfCity": "도시 지도",
    "hereSuffix": " — 현재 위치",
    "hereText": "현재 위치",
    "onStreet": "현재 거리 위에 있습니다."
  },
  "ar": {
    "planTitlePrefix": "خريطة مدينة ",
    "planOfCity": "خريطة المدينة",
    "hereSuffix": " — أنت هنا",
    "hereText": "أنت هنا",
    "onStreet": "أنت هنا، في الشارع."
  },
  "pt-BR": {
    "planTitlePrefix": "Mapa de ",
    "planOfCity": "Mapa da cidade",
    "hereSuffix": " — você está aqui",
    "hereText": "Você está aqui",
    "onStreet": "Você está aqui, na rua."
  },
  "de": {
    "planTitlePrefix": "Stadtplan von ",
    "planOfCity": "Stadtplan",
    "hereSuffix": " — Sie sind hier",
    "hereText": "Sie sind hier",
    "onStreet": "Sie sind hier, auf der Straße."
  }
};
 for(const [locale,words] of Object.entries(planTerms)) Object.assign(catalog[locale],words);
 // "Bâtiments" correspond au libellé historique littéral du petit plan de ville.
 const buildings={
  fr:"Batiments",en:"Buildings",es:"Edificios","zh-TW":"建築物",ru:"Здания",
  ko:"건물",ar:"المباني","pt-BR":"Edifícios",de:"Gebäude"
 };
 for(const [locale,value] of Object.entries(buildings))catalog[locale].buildings=value;
 // Notifications de sortie : présentation seule, verdict et diagnostics conservés.
 const exitFeedback={
  "fr": {
    "exitSessionBody": "Votre session n’est plus valide. Reconnectez-vous avant de sortir.",
    "exitUnconfirmedBody": "La réponse est incertaine et la position serveur n’a pas pu être vérifiée. Réessayez : votre position sera relue avant tout nouvel ordre.",
    "exitNetworkBody": "La connexion n’a pas permis de joindre le serveur. Réessayez.",
    "exitForbiddenBody": "Le serveur refuse cet accès. Votre position reste inchangée.",
    "exitServiceBody": "Le service a retourné une erreur. Réessayez dans un instant.",
    "exitUnregisteredBody": "La sortie de ce bâtiment n’est pas déclarée sur le serveur.",
    "exitUnreadableBody": "La sortie n’a pas pu être confirmée. Réessayez.",
    "exitDeniedBody": "Le serveur n’autorise pas cette sortie dans votre situation actuelle.",
    "exitUnconfirmedTitle": "Sortie non confirmée",
    "exitForbiddenTitle": "Sortie non autorisée",
    "exitServiceTitle": "Service de sortie indisponible",
    "exitUnregisteredTitle": "Sortie non référencée",
    "exitUnreadableTitle": "Réponse du serveur illisible",
    "exitDeniedTitle": "Sortie refusée"
  },
  "en": {
    "exitSessionBody": "Your session is no longer valid. Sign in again before leaving.",
    "exitUnconfirmedBody": "The response is uncertain and your position on the server could not be verified. Try again: your position will be read again before any new order.",
    "exitNetworkBody": "The connection could not reach the server. Try again.",
    "exitForbiddenBody": "The server denies this access. Your position remains unchanged.",
    "exitServiceBody": "The service returned an error. Try again in a moment.",
    "exitUnregisteredBody": "This building’s exit is not registered on the server.",
    "exitUnreadableBody": "Your exit could not be confirmed. Try again.",
    "exitDeniedBody": "The server does not allow you to leave in your current situation.",
    "exitUnconfirmedTitle": "Exit not confirmed",
    "exitForbiddenTitle": "Exit not authorized",
    "exitServiceTitle": "Exit service unavailable",
    "exitUnregisteredTitle": "Exit not registered",
    "exitUnreadableTitle": "Unreadable server response",
    "exitDeniedTitle": "Exit denied"
  },
  "es": {
    "exitSessionBody": "Tu sesión ya no es válida. Vuelve a iniciar sesión antes de salir.",
    "exitUnconfirmedBody": "La respuesta es incierta y no se ha podido verificar tu posición en el servidor. Vuelve a intentarlo: se consultará de nuevo tu posición antes de cualquier nueva orden.",
    "exitNetworkBody": "La conexión no ha permitido contactar con el servidor. Vuelve a intentarlo.",
    "exitForbiddenBody": "El servidor deniega este acceso. Tu posición no cambia.",
    "exitServiceBody": "El servicio ha devuelto un error. Vuelve a intentarlo dentro de un momento.",
    "exitUnregisteredBody": "La salida de este edificio no está registrada en el servidor.",
    "exitUnreadableBody": "No se ha podido confirmar la salida. Vuelve a intentarlo.",
    "exitDeniedBody": "El servidor no permite esta salida en tu situación actual.",
    "exitUnconfirmedTitle": "Salida no confirmada",
    "exitForbiddenTitle": "Salida no autorizada",
    "exitServiceTitle": "Servicio de salida no disponible",
    "exitUnregisteredTitle": "Salida no registrada",
    "exitUnreadableTitle": "Respuesta del servidor ilegible",
    "exitDeniedTitle": "Salida denegada"
  },
  "zh-TW": {
    "exitSessionBody": "您的工作階段已失效。請重新登入後再離開。",
    "exitUnconfirmedBody": "回應不確定，且無法驗證伺服器上的位置。請重試：在執行任何新指令前，系統會重新讀取您的位置。",
    "exitNetworkBody": "連線無法連接到伺服器。請重試。",
    "exitForbiddenBody": "伺服器拒絕此存取要求。您的位置保持不變。",
    "exitServiceBody": "服務傳回錯誤。請稍後重試。",
    "exitUnregisteredBody": "此建築的出口尚未在伺服器上登記。",
    "exitUnreadableBody": "無法確認離開操作。請重試。",
    "exitDeniedBody": "在您目前的情況下，伺服器不允許此離開操作。",
    "exitUnconfirmedTitle": "離開未確認",
    "exitForbiddenTitle": "離開未獲授權",
    "exitServiceTitle": "離開服務無法使用",
    "exitUnregisteredTitle": "出口未登記",
    "exitUnreadableTitle": "無法讀取伺服器回應",
    "exitDeniedTitle": "離開遭拒"
  },
  "ru": {
    "exitSessionBody": "Ваша сессия больше не действительна. Войдите снова, прежде чем выходить.",
    "exitUnconfirmedBody": "Ответ неоднозначен, и проверить положение на сервере не удалось. Попробуйте ещё раз: перед любым новым приказом ваше положение будет прочитано заново.",
    "exitNetworkBody": "Соединиться с сервером не удалось. Попробуйте ещё раз.",
    "exitForbiddenBody": "Сервер запрещает этот доступ. Ваше положение остаётся прежним.",
    "exitServiceBody": "Сервис вернул ошибку. Попробуйте ещё раз через некоторое время.",
    "exitUnregisteredBody": "Выход из этого здания не зарегистрирован на сервере.",
    "exitUnreadableBody": "Подтвердить выход не удалось. Попробуйте ещё раз.",
    "exitDeniedBody": "В вашем нынешнем положении сервер не разрешает этот выход.",
    "exitUnconfirmedTitle": "Выход не подтверждён",
    "exitForbiddenTitle": "Выход не разрешён",
    "exitServiceTitle": "Сервис выхода недоступен",
    "exitUnregisteredTitle": "Выход не зарегистрирован",
    "exitUnreadableTitle": "Нечитаемый ответ сервера",
    "exitDeniedTitle": "В выходе отказано"
  },
  "ko": {
    "exitSessionBody": "세션이 더 이상 유효하지 않습니다. 나가기 전에 다시 로그인하세요.",
    "exitUnconfirmedBody": "응답이 불확실하며 서버의 위치 정보를 확인하지 못했습니다. 다시 시도하세요. 새 명령을 내리기 전에 위치 정보를 다시 읽습니다.",
    "exitNetworkBody": "서버에 연결하지 못했습니다. 다시 시도하세요.",
    "exitForbiddenBody": "서버가 접근을 거부했습니다. 현재 위치는 바뀌지 않습니다.",
    "exitServiceBody": "서비스에서 오류를 반환했습니다. 잠시 후 다시 시도하세요.",
    "exitUnregisteredBody": "이 건물의 출구가 서버에 등록되어 있지 않습니다.",
    "exitUnreadableBody": "나가기 작업을 확인하지 못했습니다. 다시 시도하세요.",
    "exitDeniedBody": "현재 상황에서는 서버가 나가기를 허용하지 않습니다.",
    "exitUnconfirmedTitle": "나가기 확인 안 됨",
    "exitForbiddenTitle": "나가기 권한 없음",
    "exitServiceTitle": "나가기 서비스 이용 불가",
    "exitUnregisteredTitle": "출구 미등록",
    "exitUnreadableTitle": "서버 응답을 읽을 수 없음",
    "exitDeniedTitle": "나가기 거부"
  },
  "ar": {
    "exitSessionBody": "لم تعد جلستك صالحة. سجّل الدخول مجددًا قبل الخروج.",
    "exitUnconfirmedBody": "الرد غير مؤكد وتعذّر التحقق من موقعك على الخادم. حاول مجددًا: ستُقرأ بيانات موقعك مرة أخرى قبل أي أمر جديد.",
    "exitNetworkBody": "تعذّر الوصول إلى الخادم عبر الاتصال. حاول مجددًا.",
    "exitForbiddenBody": "يرفض الخادم هذا الوصول. يظل موقعك دون تغيير.",
    "exitServiceBody": "أعادت الخدمة خطأ. حاول مجددًا بعد قليل.",
    "exitUnregisteredBody": "مخرج هذا المبنى غير مسجّل على الخادم.",
    "exitUnreadableBody": "تعذّر تأكيد الخروج. حاول مجددًا.",
    "exitDeniedBody": "لا يسمح الخادم بهذا الخروج في وضعك الحالي.",
    "exitUnconfirmedTitle": "الخروج غير مؤكد",
    "exitForbiddenTitle": "خروج غير مصرّح به",
    "exitServiceTitle": "خدمة الخروج غير متاحة",
    "exitUnregisteredTitle": "مخرج غير مسجّل",
    "exitUnreadableTitle": "رد الخادم غير قابل للقراءة",
    "exitDeniedTitle": "رُفض الخروج"
  },
  "pt-BR": {
    "exitSessionBody": "Sua sessão não é mais válida. Entre novamente antes de sair.",
    "exitUnconfirmedBody": "A resposta é incerta e não foi possível verificar sua posição no servidor. Tente novamente: sua posição será consultada de novo antes de qualquer nova ordem.",
    "exitNetworkBody": "A conexão não permitiu contatar o servidor. Tente novamente.",
    "exitForbiddenBody": "O servidor recusa esse acesso. Sua posição permanece inalterada.",
    "exitServiceBody": "O serviço retornou um erro. Tente novamente em instantes.",
    "exitUnregisteredBody": "A saída deste prédio não está registrada no servidor.",
    "exitUnreadableBody": "Não foi possível confirmar a saída. Tente novamente.",
    "exitDeniedBody": "O servidor não permite esta saída na sua situação atual.",
    "exitUnconfirmedTitle": "Saída não confirmada",
    "exitForbiddenTitle": "Saída não autorizada",
    "exitServiceTitle": "Serviço de saída indisponível",
    "exitUnregisteredTitle": "Saída não registrada",
    "exitUnreadableTitle": "Resposta do servidor ilegível",
    "exitDeniedTitle": "Saída recusada"
  },
  "de": {
    "exitSessionBody": "Deine Sitzung ist nicht mehr gültig. Melde dich erneut an, bevor du hinausgehst.",
    "exitUnconfirmedBody": "Die Antwort ist ungewiss und deine Position auf dem Server konnte nicht überprüft werden. Versuche es erneut: Vor jedem neuen Befehl wird deine Position nochmals gelesen.",
    "exitNetworkBody": "Der Server konnte über die Verbindung nicht erreicht werden. Versuche es erneut.",
    "exitForbiddenBody": "Der Server verweigert diesen Zugang. Deine Position bleibt unverändert.",
    "exitServiceBody": "Der Dienst hat einen Fehler zurückgegeben. Versuche es gleich noch einmal.",
    "exitUnregisteredBody": "Der Ausgang dieses Gebäudes ist auf dem Server nicht registriert.",
    "exitUnreadableBody": "Der Ausgang konnte nicht bestätigt werden. Versuche es erneut.",
    "exitDeniedBody": "In deiner derzeitigen Situation erlaubt der Server diesen Ausgang nicht.",
    "exitUnconfirmedTitle": "Ausgang nicht bestätigt",
    "exitForbiddenTitle": "Ausgang nicht erlaubt",
    "exitServiceTitle": "Ausgangsdienst nicht verfügbar",
    "exitUnregisteredTitle": "Ausgang nicht registriert",
    "exitUnreadableTitle": "Unlesbare Serverantwort",
    "exitDeniedTitle": "Ausgang verweigert"
  }
};
 for(const [locale,words] of Object.entries(exitFeedback))Object.assign(catalog[locale],words);
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
 const exitBodies=new Map(Object.entries(exitFeedback.fr).filter(([key])=>key.endsWith('Body')).map(([key,fr])=>[fr,'navigation.'+key]));
 function exitMessageKey(original){return exitBodies.get(original)||null;}
 for(const [key,fr] of Object.entries(exitFeedback.fr))if(key.endsWith('Title'))global.RPToastI18n?.registerTitle?.(fr,'navigation.'+key);
 global.RPNavigationI18n=Object.freeze({label,labelHtml,exitMessageKey});
})(window);
