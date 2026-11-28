// ACCÈS RÉSERVÉ : Pavillon des Ambassadeurs et Résidence impériale de Novomirsk (décisions de Fred, 11-12/11/2026,
// GAME-DESIGN-NOVOMIRSK.md). Le serveur décide de l'accès, du jet « Forcer le passage », du combat contre le garde,
// des réservations, des paiements et du mini-bar ; l'écran n'affiche que ses réponses.
const ACCES_TEXTES = {
  fr: {
    tPav: 'Pavillon des Ambassadeurs', tRes: 'Résidence impériale',
    dignitaires: 'Arkadi Belov vous barre poliment le passage : bar, réception et suites sont réservés aux dignitaires.',
    postes: 'Sont admis, de Sovarka ou d’ailleurs : présidents de la République, Présidents du Conseil, ministres, ambassadeurs et députés.',
    location: 'Lev Zamkov vous arrête au pied de l’escalier : on ne monte que dans l’appartement que l’on a loué, ou au bras de son locataire.',
    reserverIci: 'Les réservations se font à l’accueil, auprès d’Ekaterina Klioutcheva.',
    unInvite: 'Le locataire ne peut amener qu’une seule personne : son groupe compte trop de monde.',
    forcer: 'Forcer le passage (2 PA)',
    forcerNote: 'Acte illégal : 60 % de chances, plus ou moins 4 % par point de Volonté au-dessus ou au-dessous de 13. En cas d’échec, il faudra affronter le garde. Délit : 1 jour de prison et 1 500 PSK d’amende.',
    tEntre: 'Vous êtes passé', entre: 'Vous voilà à l’intérieur, et recherché par la police. Vous circulez librement jusqu’à votre sortie du bâtiment.',
    tGarde: 'Le garde s’interpose', garde: '{nom} ne vous laissera pas passer sans combattre ({taux} % de chances, jet {jet}).',
    combattre: 'Combattre', tPasCombat: 'Combat non engagé', perdre: 'Si vous perdez, vous vous réveillerez à l’hôpital.',
    tRefus: 'Refusé', indispo: 'Réponse du serveur non confirmée.',
    resIntro: 'Location privative de 3 nuits, payées d’avance. L’appartement se rend le 3e jour à 12 h 00 (heure de Paris), ou se renouvelle pour 3 nuits. Vous pouvez y amener une seule personne de votre groupe.',
    nuit: '{prix} PSK la nuit · {total} PSK les 3 nuits', libre: 'Réserver', occupe: 'Occupé',
    appartement_1: 'Appartement n°1', appartement_2: 'Appartement n°2', appartement_3: 'Appartement n°3', appartement_4: 'Appartement n°4', grand_appartement: 'Grand Appartement impérial',
    bonusPetit: 'Chaque nuit : +4 POP +4 INF +4 DIS', bonusGrand: 'Chaque nuit : +15 POP +15 INF +5 DIS',
    maLocation: 'Votre location : {piece}, jusqu’au {fin}.', renouveler: 'Renouveler 3 nuits ({total} PSK)',
    aucune: 'Vous n’avez aucune location en cours.', tReserve: 'Appartement réservé', reserve: '{piece} est à vous jusqu’au {fin} ({montant} PSK).',
    tRenouvele: 'Location renouvelée', renouvele: 'Votre location court jusqu’au {fin} ({montant} PSK).',
    minibar: 'Bouteilles de vodka restantes : {n} sur 3.', prendre: 'Prendre une bouteille', remplir: 'Remplir le minibar (350 PSK)',
    tMinibar: 'Mini-bar', pris: 'Une bouteille de vodka rejoint votre inventaire.', rempli: 'Le mini-bar est de nouveau plein.',
    m_pas_sur_place: 'Présentez-vous sur place.', m_fonds_insuffisants: 'Vous n’avez pas cette somme.', m_pa_insuffisants: 'Pas assez de PA.',
    m_acteur_indisponible: 'Vous n’êtes pas en état d’agir.', m_acces_deja_autorise: 'L’accès vous est déjà ouvert.',
    m_reservation_a_l_accueil: 'Les réservations se font à l’accueil.', m_deja_locataire: 'Vous louez déjà un appartement.',
    m_appartement_occupe: 'Cet appartement est déjà loué.', m_aucune_location: 'Vous n’avez aucune location en cours.',
    m_dans_son_appartement: 'Rendez-vous dans votre appartement.', m_minibar_vide: 'Le mini-bar est vide.',
    m_minibar_plein: 'Le mini-bar est déjà plein.', m_inventaire_plein: 'Votre inventaire est plein.'
  },
  en: {
    tPav: 'Ambassadors’ Pavilion', tRes: 'Imperial Residence',
    dignitaires: 'Arkadi Belov politely bars your way: the bar, the reception hall and the suites are reserved for dignitaries.',
    postes: 'Admitted, from Sovarka or abroad: presidents of the Republic, heads of government, ministers, ambassadors and members of parliament.',
    location: 'Lev Zamkov stops you at the foot of the stairs: you only go up to the apartment you have rented, or on its tenant’s arm.',
    reserverIci: 'Bookings are made at the front desk, with Ekaterina Klioutcheva.',
    unInvite: 'The tenant may bring only one person: their group is too large.',
    forcer: 'Force your way in (2 AP)',
    forcerNote: 'Illegal act: 60% chance, plus or minus 4% per point of Willpower above or below 13. If you fail, you will have to fight the guard. Offence: 1 day in prison and a 1,500 PSK fine.',
    tEntre: 'You got through', entre: 'You are inside, and wanted by the police. You may move freely until you leave the building.',
    tGarde: 'The guard steps in', garde: '{nom} will not let you through without a fight ({taux}% chance, roll {jet}).',
    combattre: 'Fight', tPasCombat: 'Fight not started', perdre: 'If you lose, you will wake up in hospital.',
    tRefus: 'Refused', indispo: 'Server reply not confirmed.',
    resIntro: 'Private rental for 3 nights, paid in advance. The apartment must be returned on the 3rd day at 12:00 (Paris time) or renewed for 3 nights. You may bring one person from your group.',
    nuit: '{prix} PSK per night · {total} PSK for 3 nights', libre: 'Book', occupe: 'Taken',
    appartement_1: 'Apartment No. 1', appartement_2: 'Apartment No. 2', appartement_3: 'Apartment No. 3', appartement_4: 'Apartment No. 4', grand_appartement: 'Grand Imperial Apartment',
    bonusPetit: 'Each night: +4 POP +4 INF +4 DIS', bonusGrand: 'Each night: +15 POP +15 INF +5 DIS',
    maLocation: 'Your rental: {piece}, until {fin}.', renouveler: 'Renew 3 nights ({total} PSK)',
    aucune: 'You have no current rental.', tReserve: 'Apartment booked', reserve: '{piece} is yours until {fin} ({montant} PSK).',
    tRenouvele: 'Rental renewed', renouvele: 'Your rental now runs until {fin} ({montant} PSK).',
    minibar: 'Bottles of vodka left: {n} of 3.', prendre: 'Take a bottle', remplir: 'Refill the minibar (350 PSK)',
    tMinibar: 'Minibar', pris: 'A bottle of vodka goes into your inventory.', rempli: 'The minibar is full again.',
    m_pas_sur_place: 'You must be there in person.', m_fonds_insuffisants: 'You do not have that much money.', m_pa_insuffisants: 'Not enough AP.',
    m_acteur_indisponible: 'You are in no state to act.', m_acces_deja_autorise: 'You already have access.',
    m_reservation_a_l_accueil: 'Bookings are made at the front desk.', m_deja_locataire: 'You are already renting an apartment.',
    m_appartement_occupe: 'This apartment is already rented.', m_aucune_location: 'You have no current rental.',
    m_dans_son_appartement: 'Go to your apartment.', m_minibar_vide: 'The minibar is empty.',
    m_minibar_plein: 'The minibar is already full.', m_inventaire_plein: 'Your inventory is full.'
  },
  es: {
    tPav: 'Pabellón de los Embajadores', tRes: 'Residencia Imperial',
    dignitaires: 'Arkadi Belov le cierra el paso con cortesía: el bar, la sala de recepción y las suites están reservados a los dignatarios.',
    postes: 'Se admite, de Sovarka o del extranjero, a presidentes de la República, presidentes del Gobierno, ministros, embajadores y diputados.',
    location: 'Lev Zamkov le detiene al pie de la escalera: solo se sube al apartamento que uno ha alquilado, o del brazo de su inquilino.',
    reserverIci: 'Las reservas se hacen en la recepción, con Ekaterina Klioutcheva.',
    unInvite: 'El inquilino solo puede traer a una persona: su grupo es demasiado numeroso.',
    forcer: 'Forzar el paso (2 PA)',
    forcerNote: 'Acto ilegal: 60 % de probabilidad, un 4 % más o menos por cada punto de Voluntad por encima o por debajo de 13. Si falla, tendrá que enfrentarse al guardia. Delito: 1 día de cárcel y 1500 PSK de multa.',
    tEntre: 'Ha pasado', entre: 'Ya está dentro, y la policía le busca. Circula libremente hasta que salga del edificio.',
    tGarde: 'El guardia se interpone', garde: '{nom} no le dejará pasar sin pelear ({taux} % de probabilidad, tirada {jet}).',
    combattre: 'Pelear', tPasCombat: 'Combate no iniciado', perdre: 'Si pierde, despertará en el hospital.',
    tRefus: 'Rechazado', indispo: 'Respuesta del servidor no confirmada.',
    resIntro: 'Alquiler privado de 3 noches, pagadas por adelantado. El apartamento se devuelve el tercer día a las 12:00 (hora de París) o se renueva por 3 noches. Puede traer a una sola persona de su grupo.',
    nuit: '{prix} PSK la noche · {total} PSK las 3 noches', libre: 'Reservar', occupe: 'Ocupado',
    appartement_1: 'Apartamento n.º 1', appartement_2: 'Apartamento n.º 2', appartement_3: 'Apartamento n.º 3', appartement_4: 'Apartamento n.º 4', grand_appartement: 'Gran Apartamento Imperial',
    bonusPetit: 'Cada noche: +4 POP +4 INF +4 DIS', bonusGrand: 'Cada noche: +15 POP +15 INF +5 DIS',
    maLocation: 'Su alquiler: {piece}, hasta el {fin}.', renouveler: 'Renovar 3 noches ({total} PSK)',
    aucune: 'No tiene ningún alquiler en curso.', tReserve: 'Apartamento reservado', reserve: '{piece} es suyo hasta el {fin} ({montant} PSK).',
    tRenouvele: 'Alquiler renovado', renouvele: 'Su alquiler dura hasta el {fin} ({montant} PSK).',
    minibar: 'Botellas de vodka restantes: {n} de 3.', prendre: 'Tomar una botella', remplir: 'Rellenar el minibar (350 PSK)',
    tMinibar: 'Minibar', pris: 'Una botella de vodka pasa a su inventario.', rempli: 'El minibar vuelve a estar lleno.',
    m_pas_sur_place: 'Preséntese en persona.', m_fonds_insuffisants: 'No dispone de esa suma.', m_pa_insuffisants: 'No tiene suficientes PA.',
    m_acteur_indisponible: 'No está en condiciones de actuar.', m_acces_deja_autorise: 'Ya tiene acceso.',
    m_reservation_a_l_accueil: 'Las reservas se hacen en la recepción.', m_deja_locataire: 'Ya alquila un apartamento.',
    m_appartement_occupe: 'Este apartamento ya está alquilado.', m_aucune_location: 'No tiene ningún alquiler en curso.',
    m_dans_son_appartement: 'Vaya a su apartamento.', m_minibar_vide: 'El minibar está vacío.',
    m_minibar_plein: 'El minibar ya está lleno.', m_inventaire_plein: 'Su inventario está lleno.'
  },
  de: {
    tPav: 'Pavillon der Botschafter', tRes: 'Kaiserliche Residenz',
    dignitaires: 'Arkadi Belov verstellt Ihnen höflich den Weg: Bar, Empfangssaal und Suiten sind Würdenträgern vorbehalten.',
    postes: 'Zugelassen sind, aus Sovarka oder dem Ausland: Präsidenten der Republik, Regierungschefs, Minister, Botschafter und Abgeordnete.',
    location: 'Lev Zamkov hält Sie am Fuß der Treppe auf: Hinauf geht nur, wer die Wohnung gemietet hat oder ihren Mieter begleitet.',
    reserverIci: 'Reservierungen nimmt Ekaterina Klioutcheva am Empfang entgegen.',
    unInvite: 'Der Mieter darf nur eine Person mitbringen: Seine Gruppe ist zu groß.',
    forcer: 'Sich Zutritt verschaffen (2 AP)',
    forcerNote: 'Illegale Handlung: 60 % Erfolgschance, 4 % mehr oder weniger pro Punkt Willenskraft über oder unter 13. Bei einem Fehlschlag müssen Sie gegen den Wachmann kämpfen. Vergehen: 1 Tag Haft und 1.500 PSK Geldstrafe.',
    tEntre: 'Sie sind durch', entre: 'Sie sind drinnen und werden von der Polizei gesucht. Bis Sie das Gebäude verlassen, bewegen Sie sich frei.',
    tGarde: 'Der Wachmann stellt sich in den Weg', garde: '{nom} lässt Sie nicht kampflos durch ({taux} % Chance, Wurf {jet}).',
    combattre: 'Kämpfen', tPasCombat: 'Kampf nicht begonnen', perdre: 'Wenn Sie verlieren, wachen Sie im Krankenhaus auf.',
    tRefus: 'Abgelehnt', indispo: 'Serverantwort nicht bestätigt.',
    resIntro: 'Private Miete für 3 Nächte, im Voraus bezahlt. Die Wohnung wird am 3. Tag um 12:00 Uhr (Pariser Zeit) zurückgegeben oder um 3 Nächte verlängert. Sie dürfen eine Person aus Ihrer Gruppe mitbringen.',
    nuit: '{prix} PSK pro Nacht · {total} PSK für 3 Nächte', libre: 'Reservieren', occupe: 'Belegt',
    appartement_1: 'Wohnung Nr. 1', appartement_2: 'Wohnung Nr. 2', appartement_3: 'Wohnung Nr. 3', appartement_4: 'Wohnung Nr. 4', grand_appartement: 'Große kaiserliche Wohnung',
    bonusPetit: 'Jede Nacht: +4 POP +4 INF +4 DIS', bonusGrand: 'Jede Nacht: +15 POP +15 INF +5 DIS',
    maLocation: 'Ihre Miete: {piece}, bis {fin}.', renouveler: 'Um 3 Nächte verlängern ({total} PSK)',
    aucune: 'Sie haben keine laufende Miete.', tReserve: 'Wohnung reserviert', reserve: '{piece} gehört Ihnen bis {fin} ({montant} PSK).',
    tRenouvele: 'Miete verlängert', renouvele: 'Ihre Miete läuft bis {fin} ({montant} PSK).',
    minibar: 'Verbleibende Flaschen Wodka: {n} von 3.', prendre: 'Eine Flasche nehmen', remplir: 'Minibar auffüllen (350 PSK)',
    tMinibar: 'Minibar', pris: 'Eine Flasche Wodka wandert in Ihr Inventar.', rempli: 'Die Minibar ist wieder voll.',
    m_pas_sur_place: 'Kommen Sie persönlich vorbei.', m_fonds_insuffisants: 'So viel Geld haben Sie nicht.', m_pa_insuffisants: 'Nicht genug AP.',
    m_acteur_indisponible: 'Sie sind nicht in der Lage zu handeln.', m_acces_deja_autorise: 'Sie haben bereits Zutritt.',
    m_reservation_a_l_accueil: 'Reservierungen nur am Empfang.', m_deja_locataire: 'Sie mieten bereits eine Wohnung.',
    m_appartement_occupe: 'Diese Wohnung ist bereits vermietet.', m_aucune_location: 'Sie haben keine laufende Miete.',
    m_dans_son_appartement: 'Gehen Sie in Ihre Wohnung.', m_minibar_vide: 'Die Minibar ist leer.',
    m_minibar_plein: 'Die Minibar ist bereits voll.', m_inventaire_plein: 'Ihr Inventar ist voll.'
  },
  ru: {
    tPav: 'Павильон послов', tRes: 'Императорская резиденция',
    dignitaires: 'Аркадий Белов вежливо преграждает вам путь: бар, зал приёмов и люксы предназначены только для высоких гостей.',
    postes: 'Допускаются, из Соварки или из-за рубежа: президенты республики, главы правительств, министры, послы и депутаты.',
    location: 'Лев Замков останавливает вас у лестницы: подняться можно только в снятую вами квартиру или вместе с её съёмщиком.',
    reserverIci: 'Бронирование — на стойке регистрации, у Екатерины Ключевой.',
    unInvite: 'Съёмщик может привести только одного человека: в его группе слишком много людей.',
    forcer: 'Прорваться силой (2 ОД)',
    forcerNote: 'Незаконное действие: 60 % шанса, плюс или минус 4 % за каждое очко Воли выше или ниже 13. В случае неудачи придётся драться с охранником. Правонарушение: 1 день тюрьмы и штраф 1500 PSK.',
    tEntre: 'Вы прошли', entre: 'Вы внутри, и вас разыскивает полиция. Вы свободно передвигаетесь, пока не выйдете из здания.',
    tGarde: 'Охранник встаёт на пути', garde: '{nom} не пропустит вас без боя (шанс {taux} %, бросок {jet}).',
    combattre: 'Драться', tPasCombat: 'Бой не начат', perdre: 'Если проиграете, очнётесь в больнице.',
    tRefus: 'Отказано', indispo: 'Ответ сервера не подтверждён.',
    resIntro: 'Частная аренда на 3 ночи с предоплатой. Квартиру нужно сдать на 3-й день в 12:00 (по парижскому времени) или продлить ещё на 3 ночи. Можно привести одного человека из своей группы.',
    nuit: '{prix} PSK за ночь · {total} PSK за 3 ночи', libre: 'Забронировать', occupe: 'Занято',
    appartement_1: 'Квартира № 1', appartement_2: 'Квартира № 2', appartement_3: 'Квартира № 3', appartement_4: 'Квартира № 4', grand_appartement: 'Большая императорская квартира',
    bonusPetit: 'Каждая ночь: +4 POP +4 INF +4 DIS', bonusGrand: 'Каждая ночь: +15 POP +15 INF +5 DIS',
    maLocation: 'Ваша аренда: {piece}, до {fin}.', renouveler: 'Продлить на 3 ночи ({total} PSK)',
    aucune: 'У вас нет текущей аренды.', tReserve: 'Квартира забронирована', reserve: '{piece} ваша до {fin} ({montant} PSK).',
    tRenouvele: 'Аренда продлена', renouvele: 'Ваша аренда действует до {fin} ({montant} PSK).',
    minibar: 'Осталось бутылок водки: {n} из 3.', prendre: 'Взять бутылку', remplir: 'Пополнить мини-бар (350 PSK)',
    tMinibar: 'Мини-бар', pris: 'Бутылка водки отправляется в ваш инвентарь.', rempli: 'Мини-бар снова полон.',
    m_pas_sur_place: 'Явитесь лично.', m_fonds_insuffisants: 'У вас нет такой суммы.', m_pa_insuffisants: 'Недостаточно ОД.',
    m_acteur_indisponible: 'Вы не в состоянии действовать.', m_acces_deja_autorise: 'У вас уже есть доступ.',
    m_reservation_a_l_accueil: 'Бронирование — только на стойке регистрации.', m_deja_locataire: 'Вы уже снимаете квартиру.',
    m_appartement_occupe: 'Эта квартира уже сдана.', m_aucune_location: 'У вас нет текущей аренды.',
    m_dans_son_appartement: 'Пройдите в свою квартиру.', m_minibar_vide: 'Мини-бар пуст.',
    m_minibar_plein: 'Мини-бар уже полон.', m_inventaire_plein: 'Ваш инвентарь заполнен.'
  },
  ko: {
    tPav: '대사관 파빌리온', tRes: '황실 레지던스',
    dignitaires: '아르카디 벨로프가 정중하게 길을 막습니다. 바, 연회장, 스위트룸은 고위 인사 전용입니다.',
    postes: '소바르카나 외국의 대통령, 정부 수반, 장관, 대사, 국회의원만 입장할 수 있습니다.',
    location: '레프 잠코프가 계단 아래에서 당신을 막아섭니다. 자신이 빌린 아파트에만, 또는 임차인과 함께일 때만 올라갈 수 있습니다.',
    reserverIci: '예약은 안내 데스크의 예카테리나 클류체바에게 하십시오.',
    unInvite: '임차인은 한 사람만 데려올 수 있습니다. 그의 그룹 인원이 너무 많습니다.',
    forcer: '강제로 들어가기 (행동력 2)',
    forcerNote: '불법 행위입니다. 성공 확률은 60%이며, 의지가 13보다 1점 높거나 낮을 때마다 4%씩 오르내립니다. 실패하면 경비원과 싸워야 합니다. 경범죄: 징역 1일, 벌금 1,500 PSK.',
    tEntre: '통과했습니다', entre: '안으로 들어왔지만 경찰의 수배를 받습니다. 건물을 나갈 때까지 자유롭게 이동할 수 있습니다.',
    tGarde: '경비원이 막아섭니다', garde: '{nom}은(는) 싸우지 않고는 통과시켜 주지 않습니다 (확률 {taux}%, 주사위 {jet}).',
    combattre: '싸우기', tPasCombat: '전투가 시작되지 않았습니다', perdre: '패배하면 병원에서 깨어납니다.',
    tRefus: '거절됨', indispo: '서버 응답이 확인되지 않았습니다.',
    resIntro: '3박 단독 임대이며 선불입니다. 셋째 날 12:00(파리 시간)에 반납하거나 3박 연장하십시오. 그룹에서 한 사람만 데려올 수 있습니다.',
    nuit: '1박 {prix} PSK · 3박 {total} PSK', libre: '예약', occupe: '사용 중',
    appartement_1: '1호 아파트', appartement_2: '2호 아파트', appartement_3: '3호 아파트', appartement_4: '4호 아파트', grand_appartement: '황실 대형 아파트',
    bonusPetit: '매일 밤: +4 POP +4 INF +4 DIS', bonusGrand: '매일 밤: +15 POP +15 INF +5 DIS',
    maLocation: '임대 중: {piece}, {fin}까지.', renouveler: '3박 연장 ({total} PSK)',
    aucune: '진행 중인 임대가 없습니다.', tReserve: '아파트 예약 완료', reserve: '{fin}까지 {piece}을(를) 사용할 수 있습니다 ({montant} PSK).',
    tRenouvele: '임대 연장 완료', renouvele: '임대 기간이 {fin}까지로 연장되었습니다 ({montant} PSK).',
    minibar: '남은 보드카: 3병 중 {n}병.', prendre: '한 병 꺼내기', remplir: '미니바 채우기 (350 PSK)',
    tMinibar: '미니바', pris: '보드카 한 병이 인벤토리에 들어갑니다.', rempli: '미니바가 다시 가득 찼습니다.',
    m_pas_sur_place: '직접 방문하십시오.', m_fonds_insuffisants: '돈이 부족합니다.', m_pa_insuffisants: '행동력이 부족합니다.',
    m_acteur_indisponible: '행동할 수 있는 상태가 아닙니다.', m_acces_deja_autorise: '이미 출입할 수 있습니다.',
    m_reservation_a_l_accueil: '예약은 안내 데스크에서만 가능합니다.', m_deja_locataire: '이미 아파트를 임대 중입니다.',
    m_appartement_occupe: '이미 임대된 아파트입니다.', m_aucune_location: '진행 중인 임대가 없습니다.',
    m_dans_son_appartement: '자신의 아파트로 가십시오.', m_minibar_vide: '미니바가 비었습니다.',
    m_minibar_plein: '미니바가 이미 가득 찼습니다.', m_inventaire_plein: '인벤토리가 가득 찼습니다.'
  },
  ar: {
    tPav: 'جناح السفراء', tRes: 'المقر الإمبراطوري',
    dignitaires: 'يسدّ أركادي بيلوف طريقك بلباقة: البار وقاعة الاستقبال والأجنحة مخصّصة لكبار الشخصيات.',
    postes: 'يُسمح بالدخول، من سوفاركا أو من خارجها، لرؤساء الجمهورية ورؤساء الحكومات والوزراء والسفراء والنواب.',
    location: 'يوقفك ليف زامكوف عند أسفل الدرج: لا يصعد أحد إلا إلى الشقة التي استأجرها، أو برفقة مستأجرها.',
    reserverIci: 'تتم الحجوزات في مكتب الاستقبال لدى إيكاترينا كليوتشيفا.',
    unInvite: 'لا يحق للمستأجر أن يصطحب إلا شخصًا واحدًا: مجموعته كبيرة جدًا.',
    forcer: 'اقتحام المدخل (نقطتا عمل)',
    forcerNote: 'فعل غير قانوني: فرصة نجاح 60%، تزيد أو تنقص 4% عن كل نقطة إرادة فوق 13 أو دونها. عند الفشل ستضطر إلى مواجهة الحارس. جنحة: يوم سجن وغرامة 1500 PSK.',
    tEntre: 'لقد عبرت', entre: 'أنت في الداخل، والشرطة تبحث عنك. تتنقل بحرية إلى أن تغادر المبنى.',
    tGarde: 'الحارس يعترض طريقك', garde: 'لن يدعك {nom} تمرّ دون قتال (فرصة {taux}%، الرمية {jet}).',
    combattre: 'قاتل', tPasCombat: 'لم يبدأ القتال', perdre: 'إن خسرت فستستيقظ في المستشفى.',
    tRefus: 'مرفوض', indispo: 'لم يتأكد ردّ الخادم.',
    resIntro: 'إيجار خاص لثلاث ليالٍ يُدفع مقدّمًا. تُعاد الشقة في اليوم الثالث عند الساعة 12:00 (بتوقيت باريس) أو يُجدَّد الإيجار ثلاث ليالٍ. يمكنك اصطحاب شخص واحد من مجموعتك.',
    nuit: '{prix} PSK لليلة · {total} PSK للّيالي الثلاث', libre: 'احجز', occupe: 'مشغولة',
    appartement_1: 'الشقة رقم 1', appartement_2: 'الشقة رقم 2', appartement_3: 'الشقة رقم 3', appartement_4: 'الشقة رقم 4', grand_appartement: 'الشقة الإمبراطورية الكبرى',
    bonusPetit: 'كل ليلة: +4 POP +4 INF +4 DIS', bonusGrand: 'كل ليلة: +15 POP +15 INF +5 DIS',
    maLocation: 'إيجارك: {piece}، حتى {fin}.', renouveler: 'تجديد ثلاث ليالٍ ({total} PSK)',
    aucune: 'ليس لديك إيجار جارٍ.', tReserve: 'تم حجز الشقة', reserve: '{piece} لك حتى {fin} ({montant} PSK).',
    tRenouvele: 'تم تجديد الإيجار', renouvele: 'يسري إيجارك حتى {fin} ({montant} PSK).',
    minibar: 'زجاجات الفودكا المتبقية: {n} من 3.', prendre: 'خذ زجاجة', remplir: 'املأ الميني بار (350 PSK)',
    tMinibar: 'الميني بار', pris: 'انضمت زجاجة فودكا إلى مخزونك.', rempli: 'امتلأ الميني بار من جديد.',
    m_pas_sur_place: 'احضر بنفسك.', m_fonds_insuffisants: 'لا تملك هذا المبلغ.', m_pa_insuffisants: 'نقاط العمل غير كافية.',
    m_acteur_indisponible: 'لست في حال تسمح لك بالتصرف.', m_acces_deja_autorise: 'الدخول مسموح لك بالفعل.',
    m_reservation_a_l_accueil: 'تتم الحجوزات في مكتب الاستقبال.', m_deja_locataire: 'أنت تستأجر شقة بالفعل.',
    m_appartement_occupe: 'هذه الشقة مؤجرة بالفعل.', m_aucune_location: 'ليس لديك إيجار جارٍ.',
    m_dans_son_appartement: 'توجّه إلى شقتك.', m_minibar_vide: 'الميني بار فارغ.',
    m_minibar_plein: 'الميني بار ممتلئ بالفعل.', m_inventaire_plein: 'مخزونك ممتلئ.'
  },
  'pt-BR': {
    tPav: 'Pavilhão dos Embaixadores', tRes: 'Residência Imperial',
    dignitaires: 'Arkadi Belov barra sua passagem com educação: o bar, o salão de recepção e as suítes são reservados aos dignitários.',
    postes: 'São admitidos, de Sovarka ou do exterior, presidentes da República, chefes de governo, ministros, embaixadores e deputados.',
    location: 'Lev Zamkov detém você ao pé da escada: só se sobe ao apartamento alugado, ou de braço dado com o seu inquilino.',
    reserverIci: 'As reservas são feitas na recepção, com Ekaterina Klioutcheva.',
    unInvite: 'O inquilino só pode trazer uma pessoa: o grupo dele é grande demais.',
    forcer: 'Forçar a passagem (2 PA)',
    forcerNote: 'Ato ilegal: 60% de chance, 4% a mais ou a menos por ponto de Vontade acima ou abaixo de 13. Em caso de falha, você terá de enfrentar o guarda. Delito: 1 dia de prisão e multa de 1.500 PSK.',
    tEntre: 'Você passou', entre: 'Você está lá dentro, e procurado pela polícia. Circula livremente até sair do prédio.',
    tGarde: 'O guarda se interpõe', garde: '{nom} não vai deixar você passar sem luta ({taux}% de chance, rolagem {jet}).',
    combattre: 'Lutar', tPasCombat: 'Combate não iniciado', perdre: 'Se perder, você vai acordar no hospital.',
    tRefus: 'Recusado', indispo: 'Resposta do servidor não confirmada.',
    resIntro: 'Aluguel privativo de 3 noites, pagas adiantado. O apartamento deve ser devolvido no 3º dia às 12h00 (horário de Paris) ou renovado por 3 noites. Você pode trazer uma única pessoa do seu grupo.',
    nuit: '{prix} PSK a noite · {total} PSK as 3 noites', libre: 'Reservar', occupe: 'Ocupado',
    appartement_1: 'Apartamento nº 1', appartement_2: 'Apartamento nº 2', appartement_3: 'Apartamento nº 3', appartement_4: 'Apartamento nº 4', grand_appartement: 'Grande Apartamento Imperial',
    bonusPetit: 'Cada noite: +4 POP +4 INF +4 DIS', bonusGrand: 'Cada noite: +15 POP +15 INF +5 DIS',
    maLocation: 'Seu aluguel: {piece}, até {fin}.', renouveler: 'Renovar 3 noites ({total} PSK)',
    aucune: 'Você não tem aluguel em andamento.', tReserve: 'Apartamento reservado', reserve: '{piece} é seu até {fin} ({montant} PSK).',
    tRenouvele: 'Aluguel renovado', renouvele: 'Seu aluguel vai até {fin} ({montant} PSK).',
    minibar: 'Garrafas de vodca restantes: {n} de 3.', prendre: 'Pegar uma garrafa', remplir: 'Reabastecer o frigobar (350 PSK)',
    tMinibar: 'Frigobar', pris: 'Uma garrafa de vodca vai para o seu inventário.', rempli: 'O frigobar está cheio de novo.',
    m_pas_sur_place: 'Compareça pessoalmente.', m_fonds_insuffisants: 'Você não tem essa quantia.', m_pa_insuffisants: 'PA insuficientes.',
    m_acteur_indisponible: 'Você não está em condições de agir.', m_acces_deja_autorise: 'Você já tem acesso.',
    m_reservation_a_l_accueil: 'As reservas são feitas na recepção.', m_deja_locataire: 'Você já aluga um apartamento.',
    m_appartement_occupe: 'Este apartamento já está alugado.', m_aucune_location: 'Você não tem aluguel em andamento.',
    m_dans_son_appartement: 'Vá para o seu apartamento.', m_minibar_vide: 'O frigobar está vazio.',
    m_minibar_plein: 'O frigobar já está cheio.', m_inventaire_plein: 'Seu inventário está cheio.'
  },
  'zh-TW': {
    tPav: '大使館貴賓樓', tRes: '帝國官邸',
    dignitaires: '阿爾卡季・別洛夫客氣地擋住去路：酒吧、接待廳與套房僅限貴賓使用。',
    postes: '無論來自索瓦卡或外國，僅限共和國總統、政府首長、部長、大使與議員入內。',
    location: '列夫・扎姆科夫在樓梯口攔下您：只有租下公寓的人，或由承租人陪同者，才能上樓。',
    reserverIci: '請至櫃檯向葉卡捷琳娜・克柳切娃預訂。',
    unInvite: '承租人只能帶一人同行：他的隊伍人數過多。',
    forcer: '強行闖入（2 行動點）',
    forcerNote: '違法行為：成功率 60%，意志每高於或低於 13 一點，增減 4%。失敗時必須與警衛搏鬥。輕罪：監禁 1 天、罰款 1,500 PSK。',
    tEntre: '您闖過去了', entre: '您已進入，但遭警方通緝。在離開建築物之前，您可自由走動。',
    tGarde: '警衛擋在面前', garde: '{nom} 不打一架不會放行（成功率 {taux}%，擲出 {jet}）。',
    combattre: '搏鬥', tPasCombat: '戰鬥未開始', perdre: '若落敗，您將在醫院醒來。',
    tRefus: '遭拒', indispo: '伺服器回應未確認。',
    resIntro: '私人租用 3 晚，須預付。公寓須在第 3 天 12:00（巴黎時間）歸還，或再續租 3 晚。您可帶隊伍中的一人同住。',
    nuit: '每晚 {prix} PSK · 3 晚 {total} PSK', libre: '預訂', occupe: '已出租',
    appartement_1: '1 號公寓', appartement_2: '2 號公寓', appartement_3: '3 號公寓', appartement_4: '4 號公寓', grand_appartement: '帝國大公寓',
    bonusPetit: '每晚：+4 POP +4 INF +4 DIS', bonusGrand: '每晚：+15 POP +15 INF +5 DIS',
    maLocation: '您的租約：{piece}，至 {fin}。', renouveler: '續租 3 晚（{total} PSK）',
    aucune: '您目前沒有租約。', tReserve: '公寓已預訂', reserve: '{piece} 歸您使用至 {fin}（{montant} PSK）。',
    tRenouvele: '租約已續', renouvele: '您的租約延長至 {fin}（{montant} PSK）。',
    minibar: '剩餘伏特加：{n} / 3 瓶。', prendre: '取一瓶', remplir: '補滿迷你吧（350 PSK）',
    tMinibar: '迷你吧', pris: '一瓶伏特加放入您的物品欄。', rempli: '迷你吧已重新補滿。',
    m_pas_sur_place: '請親自到場。', m_fonds_insuffisants: '您沒有這筆錢。', m_pa_insuffisants: '行動點不足。',
    m_acteur_indisponible: '您目前無法行動。', m_acces_deja_autorise: '您已可進入。',
    m_reservation_a_l_accueil: '請至櫃檯預訂。', m_deja_locataire: '您已租有一間公寓。',
    m_appartement_occupe: '這間公寓已出租。', m_aucune_location: '您目前沒有租約。',
    m_dans_son_appartement: '請前往您的公寓。', m_minibar_vide: '迷你吧已空。',
    m_minibar_plein: '迷你吧已經滿了。', m_inventaire_plein: '您的物品欄已滿。'
  }
};
const ACCES_RESIDENCE = 'residence-imperiale-novomirsk';
const ACCES_RAISONS = ['acces_dignitaires', 'location_requise', 'un_seul_invite'];
let accesActeEnCours = false, accesEtatResidence = null;

function accesT(cle, vars = {}) {
  const lang = (typeof window !== 'undefined' && window.RP_I18N_GAME_ENABLED === true && window.RPPlateauI18n?.language?.()) || 'fr';
  const modele = (ACCES_TEXTES[lang] || ACCES_TEXTES.fr)[cle] || ACCES_TEXTES.fr[cle] || cle;
  return modele.replace(/\{(\w+)\}/g, (tout, k) => Object.hasOwn(vars, k) ? String(vars[k]) : tout);
}
const accesEch = s => (typeof sovEchapper === 'function') ? sovEchapper(s) : String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const accesJs = s => JSON.stringify(String(s)).replace(/"/g, '&quot;');
// Marqueur de présentation : les autres fenêtres de #modal-postes gardent leur habillage.
const accesModal = (titre, html, rouvrir) => {
  const contenu = '<div class="acces-reserve-dialogue">' + html + '</div>';
  return (typeof sovModal === 'function') ? sovModal(titre, contenu, rouvrir) : vehModal(titre, contenu);
};
const accesFermer = () => document.getElementById('modal-postes')?.classList.remove('open');
const accesTitre = b => accesT(b === ACCES_RESIDENCE ? 'tRes' : 'tPav');
const accesMotif = v => { const k = 'm_' + (v?.raison || ''); return ACCES_TEXTES.fr[k] ? accesT(k) : accesT('indispo'); };
const accesFin = f => { const d = new Date(String(f || '') + ':00'); return isNaN(d) ? String(f || '') : d.toLocaleString(undefined, { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }); };

// Acte idempotent : clé de requête stable par geste, oubliée après une réponse du serveur.
async function accesActe(rpc, params, geste) {
  if (accesActeEnCours) return null;
  accesActeEnCours = true;
  const cle = 'hg-acces:' + (state.char?.name || '') + ':' + rpc + ':' + geste;
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict(rpc, Object.assign({ p_requete: requete }, params)).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (v && v.ok === true) {
      if (Array.isArray(v.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
      if (typeof appliquerPaiementServeur === 'function' && (v.pa != null || v.liquide != null)) appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
      if (typeof renderInventory === 'function') renderInventory();
      if (typeof updateHeader === 'function') updateHeader();
      if (typeof updateUI === 'function') updateUI();
    }
    return v;
  } finally { accesActeEnCours = false; }
}

// Refus d'entrer (appelé par la navigation intérieure) : explication et « Forcer le passage ».
function accesReserveRefus(r) {
  if (!r || !ACCES_RAISONS.includes(r.raison)) return false;
  const b = r.batiment || state.currentBuilding, piece = r.piece;
  let html = r.raison === 'acces_dignitaires'
    ? '<p>' + accesT('dignitaires') + '</p><p>' + accesT('postes') + '</p>'
    : '<p>' + accesT('location') + '</p><p>' + accesT(r.raison === 'un_seul_invite' ? 'unInvite' : 'reserverIci') + '</p>';
  if (piece) html += vehSection('', vehBouton(accesT('forcer'), 'accesForcerPassage(' + accesJs(piece) + ')', false)
    + '<p class="cpj-note">' + accesT('forcerNote') + '</p>');
  accesModal(accesTitre(b), html, () => accesReserveRefus(r));
  return true;
}

async function accesForcerPassage(piece) {
  const b = state.currentBuilding;
  const v = await accesActe('acces_forcer_passage', { p_piece: piece }, piece);
  if (!v) return;
  if (v.ok !== true) { showToast(accesT('tRefus'), accesMotif(v), false); return; }
  if (typeof adopterEtatCrimeServeur === 'function') adopterEtatCrimeServeur(v);
  if (v.reussi === true) {
    accesFermer();
    showToast(accesT('tEntre'), accesT('entre'), false);
    if (typeof commanderNavigationInterieure === 'function') await commanderNavigationInterieure(b, piece);
    return;
  }
  accesAfficherGarde(v);
}

function accesAfficherGarde(v) {
  const modes = (typeof NEUTRALISER_MODES === 'object' && NEUTRALISER_MODES) ? NEUTRALISER_MODES : { mains: { label: '✊' } };
  const html = '<p>' + accesT('garde', { nom: accesEch(v.garde), taux: Number(v.taux) || 0, jet: Number(v.jet) || 0 }) + '</p>'
    + vehSection(accesT('combattre'), Object.keys(modes).map(m => {
      const possede = m === 'mains' || typeof neutraliserPossedeArme !== 'function' || neutraliserPossedeArme(m);
      return possede ? vehBouton(accesEch(modes[m].label), 'accesCombattreGarde(' + accesJs(v.pnj) + ',' + accesJs(m) + ')', m === 'mains') : '';
    }).join('') + '<p class="cpj-note">' + accesT('perdre') + '</p>');
  accesModal(accesT('tGarde'), html, () => accesAfficherGarde(v));
}

async function accesCombattreGarde(pnj, mode) {
  accesFermer();
  const v = await sbCombatOuvrir(pnj, mode);
  if (v?.ok !== true || !Number.isSafeInteger(Number(v.bataille))) { showToast(accesT('tPasCombat'), v?.raison || accesT('indispo'), false); return; }
  if (v.paie && typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(v.paie);
  if (typeof ouvrirPanneauCombat === 'function') await ouvrirPanneauCombat(Number(v.bataille));
}

function ouvrirAccesReserveInfo() {
  accesModal(accesT('tPav'), '<p>' + accesT('dignitaires') + '</p><p>' + accesT('postes') + '</p>', ouvrirAccesReserveInfo);
}

// ---------- RÉSIDENCE IMPÉRIALE ----------
async function accesLireResidence(cache) {
  const v = (cache === true && accesEtatResidence) || await sbRpcVerdict('residence_etat', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast(accesT('tRes'), accesMotif(v), false); return null; }
  accesEtatResidence = v;
  return v;
}
const accesBonus = piece => accesT(piece === 'grand_appartement' ? 'bonusGrand' : 'bonusPetit');
const accesLigneLocation = m => m ? '<p>' + accesT('maLocation', { piece: accesT(m.piece), fin: accesEch(accesFin(m.fin)) }) + '</p>' : '<p>' + accesT('aucune') + '</p>';

async function ouvrirResidenceReservation(cache) {
  const v = await accesLireResidence(cache);
  if (!v) return;
  let html = '<p>' + accesT('resIntro') + '</p>' + accesLigneLocation(v.ma_location);
  html += (v.appartements || []).map(a => vehSection(accesT(a.piece),
    '<p>' + accesT('nuit', { prix: Number(a.prix_nuit), total: 3 * Number(a.prix_nuit) }) + '<br>' + accesBonus(a.piece) + '</p>'
    + (a.libre && !v.ma_location ? vehBouton(accesT('libre'), 'residenceAgir(\'reserver\',' + accesJs(a.piece) + ')', true) : '<p class="cpj-note">' + accesT(a.libre ? 'libre' : 'occupe') + '</p>'))).join('');
  accesModal(accesT('tRes'), html, () => ouvrirResidenceReservation(true));
}

async function ouvrirResidenceLocation(cache) {
  const v = await accesLireResidence(cache);
  if (!v) return;
  const m = v.ma_location;
  let html = accesLigneLocation(m);
  if (m) html += '<p>' + accesBonus(m.piece) + '</p>' + vehBouton(accesT('renouveler', { total: 3 * Number(m.prix_nuit) }), 'residenceAgir(\'renouveler\')', true);
  accesModal(accesT('tRes'), html, () => ouvrirResidenceLocation(true));
}

async function ouvrirResidenceMinibar(cache) {
  const v = await accesLireResidence(cache);
  if (!v) return;
  const m = v.ma_location;
  if (!m || m.piece !== v.piece_courante) { showToast(accesT('tMinibar'), accesT('m_dans_son_appartement'), false); return; }
  const html = '<p>' + accesT('minibar', { n: Number(m.minibar) }) + '</p>'
    + (m.minibar > 0 ? vehBouton(accesT('prendre'), 'residenceAgir(\'minibar_prendre\')', true) : '')
    + (m.minibar < 3 ? vehBouton(accesT('remplir'), 'residenceAgir(\'minibar_remplir\')', false) : '');
  accesModal(accesT('tMinibar'), html, () => ouvrirResidenceMinibar(true));
}

async function residenceAgir(action, piece) {
  const v = await accesActe('residence_acte', { p_action: action, p_piece: piece || null }, action + ':' + (piece || ''));
  if (!v) return;
  if (v.ok !== true) { showToast(accesT('tRes'), accesMotif(v), false); return; }
  const vars = { piece: accesT(v.piece || ''), fin: accesEch(accesFin(v.fin)), montant: Number(v.montant) || 0 };
  if (action === 'reserver') showToast(accesT('tReserve'), accesT('reserve', vars), false);
  else if (action === 'renouveler') showToast(accesT('tRenouvele'), accesT('renouvele', vars), false);
  else showToast(accesT('tMinibar'), accesT(action === 'minibar_prendre' ? 'pris' : 'rempli'), false);
  accesEtatResidence = null;
  if (action.startsWith('minibar')) await ouvrirResidenceMinibar();
  else if (action === 'reserver') await ouvrirResidenceReservation();
  else await ouvrirResidenceLocation();
}

if (typeof window !== 'undefined') Object.assign(window, { accesReserveRefus, accesForcerPassage, accesCombattreGarde, ouvrirAccesReserveInfo,
  ouvrirResidenceReservation, ouvrirResidenceLocation, ouvrirResidenceMinibar, residenceAgir, ACCES_TEXTES });
