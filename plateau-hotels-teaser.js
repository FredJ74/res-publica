// =====================
// PLATEAU-HOTELS-TEASER.JS
// Hotel Ciudad Roja, centre multimodal de Ciudad Roja et Hôtel Royal d'Al-Khalija (Fred, 28/11/2026).
// Le navigateur n'envoie que l'action, la cible et, pour le billet ou le backgammon, le montant : lieu, PA, argent,
// limites, tirages et effets sont décidés par le serveur (hotel_teaser_agir, hotel_backgammon_repondre,
// migration 20261128030000). Accès réservés : refus et « Forcer le passage » (acces_forcer_passage).
// Textes dans les 9 langues du jeu.
// =====================
(function () {
  'use strict';

  const T = {
    fr: {
      tHotelCR: 'Hotel Ciudad Roja', tHotelAM: 'Hôtel Royal d’Al-Khalija', tDouane: 'Douane de Ciudad Roja', tBg: 'Backgammon',
      reserveH: 'Accès strictement réservé aux hommes', reserveF: 'Accès strictement réservé aux femmes',
      gardeH: 'Le gardien vous barre le passage : cette pièce est strictement réservée aux hommes.',
      gardeF: 'La matrone vous barre le passage : cette pièce est strictement réservée aux femmes.',
      forcer: 'Forcer le passage', forcerNote: '2 PA. Chance : 60 % + 4 % par point de VOL au-dessus de 13 (− 4 % en dessous). Échec : un jour de prison, sans combat ni amende. Réussite : vous circulez librement dans les pièces réservées jusqu’à votre sortie de l’hôtel, sans être recherché.',
      entre: 'Vous êtes entré. Personne ne vous retient jusqu’à votre sortie de l’hôtel.', prison: 'Les gardiens vous remettent à la police : un jour de prison.',
      montant: 'Montant', cible: 'Joueur visé (présent dans la pièce)', valider: 'Valider', annuler: 'Annuler', personnel: 'À qui ?',
      ok: 'C’est fait.', refus: 'Impossible', rumeur: 'Tito Maletas se penche vers vous : « {texte} »',
      billetOk: 'Juanita Soborno empoche le billet ({taux} %) : vous passerez sans confiscation.',
      billetKo: '« Si tu avais été moins radin, tu aurais gardé tes objets, imbécile ! On t’avait pourtant laissé une chance ! » ({taux} %)',
      saisis: 'Objets saisis : {noms}.', rienSaisi: 'Vous n’aviez rien d’illégal sur vous.',
      police: 'La police des mœurs a été prévenue : {amende} DR d’amende.',
      narguileSecret: 'La fumée vous délie la langue : « {secret} » ({n} témoin(s)).',
      scsOk: 'Échange réussi ({taux} %) : vous apprenez un secret de {cible}, qui apprend un des vôtres.',
      scsKo: 'Rien ne sort ({taux} %). {cible} ne se doute de rien.', scsCrit: '{cible} vous a retourné la question : c’est elle ou lui qui apprend un de vos secrets.',
      bgLancer: 'Défier un joueur', bgDefi: 'Défi envoyé à {cible} pour {mise} DR.', bgRecus: 'Défis reçus', bgAucun: 'Aucun défi en attente.',
      bgAccepter: 'Accepter', bgRefuser: 'Refuser', bgDe: '{auteur} vous défie pour {mise} DR.',
      bgGagne: 'Vous gagnez la partie et {mise} DR de mise adverse (+2 popularité).', bgPerdu: 'Vous perdez la partie et votre mise de {mise} DR.', bgRefuse: 'Défi décliné.',
      m: { pas_sur_place: 'Ce geste n’est pas possible ici.', limite_quotidienne: 'Vous l’avez déjà fait autant de fois qu’il est permis aujourd’hui.',
           effet_deja_actif: 'L’effet du précédent café dure encore.', cible_absente: 'Ce joueur n’est pas dans la pièce.', montant_invalide: 'Montant invalide.',
           fonds_insuffisants: 'Fonds insuffisants.', pa_insuffisants: 'PA insuffisants.', defi_deja_lance: 'Vous avez déjà défié ce joueur.',
           defi_introuvable: 'Ce défi n’existe plus.', defi_expire: 'Ce défi a expiré.', acteur_indisponible: 'Vous ne pouvez pas agir pour le moment.', indispo: 'Le serveur ne répond pas. Réessayez.' }
    },
    en: {
      tHotelCR: 'Hotel Ciudad Roja', tHotelAM: 'Royal Hotel of Al-Khalija', tDouane: 'Ciudad Roja customs', tBg: 'Backgammon',
      reserveH: 'Strictly reserved for men', reserveF: 'Strictly reserved for women',
      gardeH: 'The guard blocks your way: this room is strictly reserved for men.', gardeF: 'The matron blocks your way: this room is strictly reserved for women.',
      forcer: 'Force your way in', forcerNote: '2 AP. Chance: 60% + 4% per WIL point above 13 (−4% below). Failure: one day in prison, no fight, no fine. Success: you move freely through the reserved rooms until you leave the hotel, and you are not wanted.',
      entre: 'You are in. Nobody stops you until you leave the hotel.', prison: 'The guards hand you over to the police: one day in prison.',
      montant: 'Amount', cible: 'Target player (in the room)', valider: 'Confirm', annuler: 'Cancel', personnel: 'To whom?',
      ok: 'Done.', refus: 'Not possible', rumeur: 'Tito Maletas leans towards you: “{texte}”',
      billetOk: 'Juanita Soborno pockets the bill ({taux}%): you will pass without confiscation.',
      billetKo: '“If you hadn’t been so stingy, you’d have kept your things, idiot! We gave you a chance!” ({taux}%)',
      saisis: 'Seized items: {noms}.', rienSaisi: 'You had nothing illegal on you.',
      police: 'The morality police were told: {amende} DR fine.', narguileSecret: 'The smoke loosens your tongue: “{secret}” ({n} witness(es)).',
      scsOk: 'Exchange succeeded ({taux}%): you learn a secret of {cible}, who learns one of yours.', scsKo: 'Nothing comes out ({taux}%). {cible} suspects nothing.',
      scsCrit: '{cible} turned the tables: they learn one of your secrets.',
      bgLancer: 'Challenge a player', bgDefi: 'Challenge sent to {cible} for {mise} DR.', bgRecus: 'Challenges received', bgAucun: 'No pending challenge.',
      bgAccepter: 'Accept', bgRefuser: 'Decline', bgDe: '{auteur} challenges you for {mise} DR.',
      bgGagne: 'You win the game and the opponent’s {mise} DR stake (+2 popularity).', bgPerdu: 'You lose the game and your {mise} DR stake.', bgRefuse: 'Challenge declined.',
      m: { pas_sur_place: 'You cannot do this here.', limite_quotidienne: 'You have already done this as many times as allowed today.', effet_deja_actif: 'The previous coffee is still working.',
           cible_absente: 'This player is not in the room.', montant_invalide: 'Invalid amount.', fonds_insuffisants: 'Not enough money.', pa_insuffisants: 'Not enough AP.',
           defi_deja_lance: 'You have already challenged this player.', defi_introuvable: 'This challenge no longer exists.', defi_expire: 'This challenge has expired.',
           acteur_indisponible: 'You cannot act right now.', indispo: 'The server is not responding. Try again.' }
    },
    es: {
      tHotelCR: 'Hotel Ciudad Roja', tHotelAM: 'Hotel Real de Al-Khalija', tDouane: 'Aduana de Ciudad Roja', tBg: 'Backgammon',
      reserveH: 'Acceso estrictamente reservado a los hombres', reserveF: 'Acceso estrictamente reservado a las mujeres',
      gardeH: 'El guardián le cierra el paso: esta sala está reservada a los hombres.', gardeF: 'La matrona le cierra el paso: esta sala está reservada a las mujeres.',
      forcer: 'Forzar el paso', forcerNote: '2 PA. Probabilidad: 60 % + 4 % por punto de VOL por encima de 13 (− 4 % por debajo). Fracaso: un día de cárcel, sin combate ni multa. Éxito: circula libremente por las salas reservadas hasta salir del hotel, sin ser buscado.',
      entre: 'Ha entrado. Nadie le detiene hasta que salga del hotel.', prison: 'Los guardianes le entregan a la policía: un día de cárcel.',
      montant: 'Importe', cible: 'Jugador objetivo (en la sala)', valider: 'Validar', annuler: 'Cancelar', personnel: '¿A quién?',
      ok: 'Hecho.', refus: 'Imposible', rumeur: 'Tito Maletas se inclina hacia usted: «{texte}»',
      billetOk: 'Juanita Soborno se guarda el billete ({taux} %): pasará sin confiscación.',
      billetKo: '«¡Si hubieras sido menos tacaño, habrías conservado tus cosas, imbécil! ¡Te habíamos dado una oportunidad!» ({taux} %)',
      saisis: 'Objetos incautados: {noms}.', rienSaisi: 'No llevaba nada ilegal.',
      police: 'La policía de costumbres ha sido avisada: multa de {amende} DR.', narguileSecret: 'El humo le suelta la lengua: «{secret}» ({n} testigo(s)).',
      scsOk: 'Intercambio logrado ({taux} %): conoce un secreto de {cible}, que conoce uno de los suyos.', scsKo: 'No sale nada ({taux} %). {cible} no sospecha nada.',
      scsCrit: '{cible} le dio la vuelta: es quien descubre uno de sus secretos.',
      bgLancer: 'Desafiar a un jugador', bgDefi: 'Desafío enviado a {cible} por {mise} DR.', bgRecus: 'Desafíos recibidos', bgAucun: 'Ningún desafío pendiente.',
      bgAccepter: 'Aceptar', bgRefuser: 'Rechazar', bgDe: '{auteur} le desafía por {mise} DR.',
      bgGagne: 'Gana la partida y la apuesta rival de {mise} DR (+2 popularidad).', bgPerdu: 'Pierde la partida y su apuesta de {mise} DR.', bgRefuse: 'Desafío rechazado.',
      m: { pas_sur_place: 'No puede hacerlo aquí.', limite_quotidienne: 'Ya lo ha hecho tantas veces como se permite hoy.', effet_deja_actif: 'El café anterior aún hace efecto.',
           cible_absente: 'Ese jugador no está en la sala.', montant_invalide: 'Importe no válido.', fonds_insuffisants: 'Fondos insuficientes.', pa_insuffisants: 'PA insuficientes.',
           defi_deja_lance: 'Ya ha desafiado a este jugador.', defi_introuvable: 'Ese desafío ya no existe.', defi_expire: 'Ese desafío ha caducado.',
           acteur_indisponible: 'No puede actuar por ahora.', indispo: 'El servidor no responde. Inténtelo de nuevo.' }
    },
    de: {
      tHotelCR: 'Hotel Ciudad Roja', tHotelAM: 'Königliches Hotel von Al-Khalija', tDouane: 'Zoll von Ciudad Roja', tBg: 'Backgammon',
      reserveH: 'Zutritt nur für Männer', reserveF: 'Zutritt nur für Frauen',
      gardeH: 'Der Wächter versperrt Ihnen den Weg: Dieser Raum ist nur für Männer.', gardeF: 'Die Matrone versperrt Ihnen den Weg: Dieser Raum ist nur für Frauen.',
      forcer: 'Sich Zutritt erzwingen', forcerNote: '2 AP. Chance: 60 % + 4 % pro WIL-Punkt über 13 (− 4 % darunter). Misserfolg: ein Tag Gefängnis, kein Kampf, keine Geldstrafe. Erfolg: freie Bewegung in den reservierten Räumen bis zum Verlassen des Hotels, ohne gesucht zu werden.',
      entre: 'Sie sind drin. Niemand hält Sie auf, bis Sie das Hotel verlassen.', prison: 'Die Wächter übergeben Sie der Polizei: ein Tag Gefängnis.',
      montant: 'Betrag', cible: 'Zielspieler (im Raum)', valider: 'Bestätigen', annuler: 'Abbrechen', personnel: 'Wem?',
      ok: 'Erledigt.', refus: 'Nicht möglich', rumeur: 'Tito Maletas beugt sich zu Ihnen: „{texte}“',
      billetOk: 'Juanita Soborno steckt den Schein ein ({taux} %): Sie passieren ohne Beschlagnahme.',
      billetKo: '„Wärst du nicht so knauserig gewesen, hättest du deine Sachen behalten, Dummkopf! Wir hatten dir eine Chance gegeben!“ ({taux} %)',
      saisis: 'Beschlagnahmt: {noms}.', rienSaisi: 'Sie hatten nichts Illegales dabei.',
      police: 'Die Sittenpolizei wurde informiert: {amende} DR Geldstrafe.', narguileSecret: 'Der Rauch löst Ihre Zunge: „{secret}“ ({n} Zeuge(n)).',
      scsOk: 'Tausch gelungen ({taux} %): Sie erfahren ein Geheimnis von {cible}, die Person erfährt eines von Ihnen.', scsKo: 'Nichts kommt heraus ({taux} %). {cible} ahnt nichts.',
      scsCrit: '{cible} hat den Spieß umgedreht und erfährt eines Ihrer Geheimnisse.',
      bgLancer: 'Einen Spieler herausfordern', bgDefi: 'Herausforderung an {cible} für {mise} DR gesendet.', bgRecus: 'Erhaltene Herausforderungen', bgAucun: 'Keine offene Herausforderung.',
      bgAccepter: 'Annehmen', bgRefuser: 'Ablehnen', bgDe: '{auteur} fordert Sie für {mise} DR heraus.',
      bgGagne: 'Sie gewinnen die Partie und den gegnerischen Einsatz von {mise} DR (+2 Beliebtheit).', bgPerdu: 'Sie verlieren die Partie und Ihren Einsatz von {mise} DR.', bgRefuse: 'Herausforderung abgelehnt.',
      m: { pas_sur_place: 'Das ist hier nicht möglich.', limite_quotidienne: 'Heute bereits so oft wie erlaubt.', effet_deja_actif: 'Der letzte Kaffee wirkt noch.',
           cible_absente: 'Dieser Spieler ist nicht im Raum.', montant_invalide: 'Ungültiger Betrag.', fonds_insuffisants: 'Nicht genug Geld.', pa_insuffisants: 'Nicht genug AP.',
           defi_deja_lance: 'Sie haben diesen Spieler bereits herausgefordert.', defi_introuvable: 'Diese Herausforderung gibt es nicht mehr.', defi_expire: 'Diese Herausforderung ist abgelaufen.',
           acteur_indisponible: 'Sie können gerade nicht handeln.', indispo: 'Der Server antwortet nicht. Bitte erneut versuchen.' }
    },
    ru: {
      tHotelCR: 'Отель «Ciudad Roja»', tHotelAM: 'Королевский отель Al-Khalija', tDouane: 'Таможня Сьюдад-Рохи', tBg: 'Нарды',
      reserveH: 'Вход только для мужчин', reserveF: 'Вход только для женщин',
      gardeH: 'Охранник преграждает путь: зал только для мужчин.', gardeF: 'Смотрительница преграждает путь: зал только для женщин.',
      forcer: 'Прорваться', forcerNote: '2 ОД. Шанс: 60 % + 4 % за каждое очко ВОЛ выше 13 (− 4 % ниже). Неудача: один день тюрьмы, без боя и штрафа. Успех: свободный проход по закрытым залам до выхода из отеля, без розыска.',
      entre: 'Вы вошли. До выхода из отеля вас никто не остановит.', prison: 'Охрана сдаёт вас полиции: один день тюрьмы.',
      montant: 'Сумма', cible: 'Игрок-цель (в зале)', valider: 'Подтвердить', annuler: 'Отмена', personnel: 'Кому?',
      ok: 'Готово.', refus: 'Невозможно', rumeur: 'Tito Maletas наклоняется к вам: «{texte}»',
      billetOk: 'Хуанита Соборно прячет купюру ({taux} %): вы пройдёте без конфискации.',
      billetKo: '«Был бы ты не таким жадным — сохранил бы вещи, болван! Мы ведь дали тебе шанс!» ({taux} %)',
      saisis: 'Изъято: {noms}.', rienSaisi: 'У вас не было ничего незаконного.',
      police: 'Полиция нравов предупреждена: штраф {amende} DR.', narguileSecret: 'Дым развязывает вам язык: «{secret}» (свидетелей: {n}).',
      scsOk: 'Обмен удался ({taux} %): вы узнаёте тайну {cible}, а тот — вашу.', scsKo: 'Ничего не вышло ({taux} %). {cible} ничего не подозревает.',
      scsCrit: '{cible} перехватил(а) инициативу и узнаёт одну из ваших тайн.',
      bgLancer: 'Вызвать игрока', bgDefi: 'Вызов отправлен {cible} на {mise} DR.', bgRecus: 'Полученные вызовы', bgAucun: 'Нет ожидающих вызовов.',
      bgAccepter: 'Принять', bgRefuser: 'Отказаться', bgDe: '{auteur} вызывает вас на {mise} DR.',
      bgGagne: 'Вы выиграли партию и ставку соперника {mise} DR (+2 популярности).', bgPerdu: 'Вы проиграли партию и свою ставку {mise} DR.', bgRefuse: 'Вызов отклонён.',
      m: { pas_sur_place: 'Здесь это невозможно.', limite_quotidienne: 'Сегодня вы уже сделали это максимальное число раз.', effet_deja_actif: 'Прошлый кофе ещё действует.',
           cible_absente: 'Этого игрока нет в зале.', montant_invalide: 'Неверная сумма.', fonds_insuffisants: 'Недостаточно денег.', pa_insuffisants: 'Недостаточно ОД.',
           defi_deja_lance: 'Вы уже вызвали этого игрока.', defi_introuvable: 'Этого вызова больше нет.', defi_expire: 'Срок вызова истёк.',
           acteur_indisponible: 'Сейчас вы не можете действовать.', indispo: 'Сервер не отвечает. Повторите попытку.' }
    },
    ko: {
      tHotelCR: 'Ciudad Roja 호텔', tHotelAM: 'Al-Khalija 왕립 호텔', tDouane: 'Ciudad Roja 세관', tBg: '백개먼',
      reserveH: '남성 전용 구역', reserveF: '여성 전용 구역',
      gardeH: '경비원이 길을 막습니다. 이곳은 남성 전용입니다.', gardeF: '관리인이 길을 막습니다. 이곳은 여성 전용입니다.',
      forcer: '강제로 들어가기', forcerNote: '2 AP. 확률: 60% + VOL 13 초과 1점당 4% (미만은 1점당 −4%). 실패: 전투나 벌금 없이 감옥 1일. 성공: 호텔을 나갈 때까지 전용 구역을 자유롭게 다니며 수배되지 않습니다.',
      entre: '들어왔습니다. 호텔을 나갈 때까지 아무도 막지 않습니다.', prison: '경비원이 당신을 경찰에 넘깁니다. 감옥 1일.',
      montant: '금액', cible: '대상 플레이어(같은 방)', valider: '확인', annuler: '취소', personnel: '누구에게?',
      ok: '완료했습니다.', refus: '불가능', rumeur: 'Tito Maletas가 몸을 기울입니다. "{texte}"',
      billetOk: '후아니타 소보르노가 지폐를 챙깁니다({taux}%). 압수 없이 통과합니다.',
      billetKo: '"덜 인색했으면 물건을 지켰을 텐데, 멍청이! 기회를 줬잖아!" ({taux}%)',
      saisis: '압수된 물품: {noms}.', rienSaisi: '불법 물품이 없었습니다.',
      police: '풍기 단속 경찰에 신고되었습니다. 벌금 {amende} DR.', narguileSecret: '연기에 혀가 풀립니다. "{secret}" (목격자 {n}명)',
      scsOk: '교환 성공({taux}%): {cible}의 비밀을 알게 되고, 상대도 당신의 비밀을 하나 압니다.', scsKo: '아무것도 나오지 않았습니다({taux}%). {cible}은(는) 눈치채지 못했습니다.',
      scsCrit: '{cible}이(가) 판을 뒤집어 당신의 비밀 하나를 알게 됩니다.',
      bgLancer: '플레이어에게 도전', bgDefi: '{cible}에게 {mise} DR 도전을 보냈습니다.', bgRecus: '받은 도전', bgAucun: '대기 중인 도전이 없습니다.',
      bgAccepter: '수락', bgRefuser: '거절', bgDe: '{auteur}이(가) {mise} DR로 도전합니다.',
      bgGagne: '승리하여 상대의 판돈 {mise} DR을 얻습니다(인기 +2).', bgPerdu: '패배하여 판돈 {mise} DR을 잃습니다.', bgRefuse: '도전을 거절했습니다.',
      m: { pas_sur_place: '여기서는 할 수 없습니다.', limite_quotidienne: '오늘 허용된 횟수를 모두 사용했습니다.', effet_deja_actif: '이전 커피 효과가 아직 남아 있습니다.',
           cible_absente: '그 플레이어는 이 방에 없습니다.', montant_invalide: '잘못된 금액입니다.', fonds_insuffisants: '돈이 부족합니다.', pa_insuffisants: 'AP가 부족합니다.',
           defi_deja_lance: '이미 이 플레이어에게 도전했습니다.', defi_introuvable: '이 도전은 더 이상 없습니다.', defi_expire: '이 도전은 만료되었습니다.',
           acteur_indisponible: '지금은 행동할 수 없습니다.', indispo: '서버가 응답하지 않습니다. 다시 시도하세요.' }
    },
    ar: {
      tHotelCR: 'فندق Ciudad Roja', tHotelAM: 'الفندق الملكي في Al-Khalija', tDouane: 'جمارك Ciudad Roja', tBg: 'طاولة الزهر',
      reserveH: 'الدخول مقصور على الرجال حصرًا', reserveF: 'الدخول مقصور على النساء حصرًا',
      gardeH: 'يسدّ الحارس طريقك: هذه القاعة للرجال حصرًا.', gardeF: 'تسدّ المشرفة طريقك: هذه القاعة للنساء حصرًا.',
      forcer: 'اقتحام المدخل', forcerNote: 'نقطتا عمل. الفرصة: 60٪ + 4٪ لكل نقطة إرادة فوق 13 (− 4٪ تحتها). الفشل: يوم في السجن دون قتال ولا غرامة. النجاح: تتنقل بحرية في القاعات المحجوزة حتى تغادر الفندق، دون أن تكون مطلوبًا.',
      entre: 'لقد دخلت. لن يوقفك أحد حتى تغادر الفندق.', prison: 'يسلّمك الحراس إلى الشرطة: يوم في السجن.',
      montant: 'المبلغ', cible: 'اللاعب المستهدف (في القاعة)', valider: 'تأكيد', annuler: 'إلغاء', personnel: 'لمن؟',
      ok: 'تم.', refus: 'غير ممكن', rumeur: 'يميل Tito Maletas نحوك: «{texte}»',
      billetOk: 'تضع خوانيتا سوبورنو الورقة في جيبها ({taux}٪): ستمرّ دون مصادرة.',
      billetKo: '«لو لم تكن بخيلًا لاحتفظت بأغراضك يا أحمق! لقد منحناك فرصة!» ({taux}٪)',
      saisis: 'الأغراض المصادرة: {noms}.', rienSaisi: 'لم يكن معك شيء غير قانوني.',
      police: 'أُبلغت شرطة الآداب: غرامة {amende} DR.', narguileSecret: 'الدخان يحلّ عقدة لسانك: «{secret}» ({n} شاهد).',
      scsOk: 'نجح التبادل ({taux}٪): تعرف سرًا لـ{cible}، ويعرف سرًا لك.', scsKo: 'لم يخرج شيء ({taux}٪). {cible} لا يشكّ في شيء.',
      scsCrit: 'قلب {cible} الطاولة: هو من يعرف أحد أسرارك.',
      bgLancer: 'تحدّي لاعب', bgDefi: 'أُرسل التحدي إلى {cible} مقابل {mise} DR.', bgRecus: 'التحديات الواردة', bgAucun: 'لا توجد تحديات معلّقة.',
      bgAccepter: 'قبول', bgRefuser: 'رفض', bgDe: '{auteur} يتحداك مقابل {mise} DR.',
      bgGagne: 'تفوز بالمباراة وبرهان الخصم {mise} DR (+2 شعبية).', bgPerdu: 'تخسر المباراة ورهانك {mise} DR.', bgRefuse: 'رُفض التحدي.',
      m: { pas_sur_place: 'لا يمكنك فعل ذلك هنا.', limite_quotidienne: 'بلغت الحد المسموح لهذا اليوم.', effet_deja_actif: 'ما زال مفعول القهوة السابقة قائمًا.',
           cible_absente: 'هذا اللاعب ليس في القاعة.', montant_invalide: 'مبلغ غير صالح.', fonds_insuffisants: 'المال غير كافٍ.', pa_insuffisants: 'نقاط العمل غير كافية.',
           defi_deja_lance: 'لقد تحديت هذا اللاعب من قبل.', defi_introuvable: 'لم يعد هذا التحدي موجودًا.', defi_expire: 'انتهت مدة هذا التحدي.',
           acteur_indisponible: 'لا يمكنك التصرف حاليًا.', indispo: 'الخادم لا يستجيب. أعد المحاولة.' }
    },
    'pt-BR': {
      tHotelCR: 'Hotel Ciudad Roja', tHotelAM: 'Hotel Real de Al-Khalija', tDouane: 'Alfândega de Ciudad Roja', tBg: 'Gamão',
      reserveH: 'Acesso estritamente reservado aos homens', reserveF: 'Acesso estritamente reservado às mulheres',
      gardeH: 'O guarda bloqueia a passagem: esta sala é reservada aos homens.', gardeF: 'A matrona bloqueia a passagem: esta sala é reservada às mulheres.',
      forcer: 'Forçar a passagem', forcerNote: '2 PA. Chance: 60% + 4% por ponto de VON acima de 13 (− 4% abaixo). Falha: um dia de prisão, sem combate nem multa. Sucesso: você circula livremente pelas salas reservadas até sair do hotel, sem ser procurado.',
      entre: 'Você entrou. Ninguém o impede até sair do hotel.', prison: 'Os guardas o entregam à polícia: um dia de prisão.',
      montant: 'Valor', cible: 'Jogador alvo (na sala)', valider: 'Confirmar', annuler: 'Cancelar', personnel: 'Para quem?',
      ok: 'Feito.', refus: 'Impossível', rumeur: 'Tito Maletas se inclina para você: “{texte}”',
      billetOk: 'Juanita Soborno embolsa a nota ({taux}%): você passará sem confisco.',
      billetKo: '“Se você fosse menos pão-duro, teria ficado com suas coisas, imbecil! Nós te demos uma chance!” ({taux}%)',
      saisis: 'Itens apreendidos: {noms}.', rienSaisi: 'Você não tinha nada ilegal.',
      police: 'A polícia de costumes foi avisada: multa de {amende} DR.', narguileSecret: 'A fumaça solta sua língua: “{secret}” ({n} testemunha(s)).',
      scsOk: 'Troca bem-sucedida ({taux}%): você descobre um segredo de {cible}, que descobre um seu.', scsKo: 'Nada sai ({taux}%). {cible} não desconfia de nada.',
      scsCrit: '{cible} virou o jogo: é quem descobre um dos seus segredos.',
      bgLancer: 'Desafiar um jogador', bgDefi: 'Desafio enviado a {cible} por {mise} DR.', bgRecus: 'Desafios recebidos', bgAucun: 'Nenhum desafio pendente.',
      bgAccepter: 'Aceitar', bgRefuser: 'Recusar', bgDe: '{auteur} desafia você por {mise} DR.',
      bgGagne: 'Você vence a partida e a aposta adversária de {mise} DR (+2 popularidade).', bgPerdu: 'Você perde a partida e sua aposta de {mise} DR.', bgRefuse: 'Desafio recusado.',
      m: { pas_sur_place: 'Não é possível fazer isso aqui.', limite_quotidienne: 'Você já fez isso o máximo de vezes permitido hoje.', effet_deja_actif: 'O café anterior ainda faz efeito.',
           cible_absente: 'Esse jogador não está na sala.', montant_invalide: 'Valor inválido.', fonds_insuffisants: 'Dinheiro insuficiente.', pa_insuffisants: 'PA insuficientes.',
           defi_deja_lance: 'Você já desafiou este jogador.', defi_introuvable: 'Este desafio não existe mais.', defi_expire: 'Este desafio expirou.',
           acteur_indisponible: 'Você não pode agir no momento.', indispo: 'O servidor não responde. Tente novamente.' }
    },
    'zh-TW': {
      tHotelCR: 'Ciudad Roja飯店', tHotelAM: '哈利賈皇家飯店', tDouane: 'Ciudad Roja海關', tBg: '雙陸棋',
      reserveH: '僅限男性進入', reserveF: '僅限女性進入',
      gardeH: '守衛擋住您的去路：此廳僅限男性。', gardeF: '女管事擋住您的去路：此廳僅限女性。',
      forcer: '強行闖入', forcerNote: '2 行動點。機率：60% + 意志每高於 13 一點加 4%（低於則每點減 4%）。失敗：入獄一天，無戰鬥、無罰款。成功：離開飯店前可在保留廳室自由走動，且不會遭通緝。',
      entre: '您已進入。離開飯店前沒有人會攔您。', prison: '守衛把您交給警方：入獄一天。',
      montant: '金額', cible: '目標玩家（在此廳）', valider: '確認', annuler: '取消', personnel: '給誰？',
      ok: '完成。', refus: '無法執行', rumeur: 'Tito Maletas湊近您：「{texte}」',
      billetOk: '胡安妮塔·索博爾諾收下鈔票（{taux}%）：您將免於沒收通關。',
      billetKo: '「要是你沒那麼小氣，東西就保住了，蠢貨！我們可是給過你機會！」（{taux}%）',
      saisis: '沒收物品：{noms}。', rienSaisi: '您身上沒有違禁品。',
      police: '風化警察已接獲通報：罰款 {amende} DR。', narguileSecret: '煙霧讓您口無遮攔：「{secret}」（{n} 名目擊者）。',
      scsOk: '交換成功（{taux}%）：您得知 {cible} 的一個秘密，對方也得知您的一個。', scsKo: '一無所獲（{taux}%）。{cible} 毫無察覺。',
      scsCrit: '{cible} 反將一軍：得知您的一個秘密。',
      bgLancer: '挑戰玩家', bgDefi: '已向 {cible} 發出 {mise} DR 的挑戰。', bgRecus: '收到的挑戰', bgAucun: '沒有待回應的挑戰。',
      bgAccepter: '接受', bgRefuser: '拒絕', bgDe: '{auteur} 以 {mise} DR 向您挑戰。',
      bgGagne: '您贏得比賽與對手的 {mise} DR 賭注（人氣 +2）。', bgPerdu: '您輸掉比賽與 {mise} DR 賭注。', bgRefuse: '已拒絕挑戰。',
      m: { pas_sur_place: '此處無法執行。', limite_quotidienne: '今天已達允許次數。', effet_deja_actif: '上一杯咖啡仍有效果。',
           cible_absente: '該玩家不在此廳。', montant_invalide: '金額無效。', fonds_insuffisants: '資金不足。', pa_insuffisants: '行動點不足。',
           defi_deja_lance: '您已挑戰過此玩家。', defi_introuvable: '此挑戰已不存在。', defi_expire: '此挑戰已過期。',
           acteur_indisponible: '您目前無法行動。', indispo: '伺服器沒有回應，請再試一次。' }
    }
  };

  function langue() {
    const l = (typeof window !== 'undefined' && window.RP_I18N_GAME_ENABLED === true && window.RPPlateauI18n?.language?.()) || 'fr';
    return T[l] ? l : 'fr';
  }
  // Réponses de Fred du 28/11 (après-midi) : assignation à résidence au lieu de la prison, Tito et le réseau Roxane Velours.
  const T_SUITE = {
    fr: { forcerNote: '2 PA. Chance : 60 % + 4 % par point de VOL au-dessus de 13 (− 4 % en dessous). Échec : assignation à résidence dans votre suite de l’hôtel, offerte par la maison, jusqu’à votre prochain « Dormir ». Réussite : vous circulez librement dans les pièces réservées jusqu’à votre sortie de l’hôtel, sans être recherché.',
      assigne: 'Les gardiens vous raccompagnent poliment dans votre suite, offerte par la maison : vous êtes assigné à résidence. Vous ne pouvez pas en sortir ; vous pouvez dormir, commander au service d’étage, écrire et aller sur le forum. L’assignation prend fin à votre premier « Dormir ».',
      assigneJournal: 'Hôtel Royal d’Al-Khalija : vous êtes assigné à résidence dans votre suite jusqu’à votre prochain « Dormir ».',
      assigneFin: 'Hôtel Royal d’Al-Khalija : votre assignation à résidence est levée. Vous pouvez quitter votre suite.',
      assigneRefus: 'Vous êtes assigné à résidence dans votre suite de l’Hôtel Royal jusqu’à votre prochain « Dormir ».',
      tito: 'Tito Maletas empoche le billet et baisse la voix : « Le réseau Roxane Velours est partout dans le monde, et ses escorts entendent toutes les confidences. Sur {cible}, on m’a soufflé ceci : {secret} »',
      titoRien: 'Tito Maletas empoche le billet : « Le réseau Roxane Velours n’a rien entendu d’intéressant ces temps-ci. »' },
    en: { forcerNote: '2 AP. Chance: 60% + 4% per WIL point above 13 (−4% below). Failure: house arrest in your hotel suite, on the house, until your next “Sleep”. Success: you move freely through the reserved rooms until you leave the hotel, and you are not wanted.',
      assigne: 'The guards politely escort you back to your suite, on the house: you are under house arrest. You cannot leave it; you can sleep, order room service, write letters and use the forum. The house arrest ends at your first “Sleep”.',
      assigneJournal: 'Royal Hotel of Al-Khalija: you are under house arrest in your suite until your next “Sleep”.',
      assigneFin: 'Royal Hotel of Al-Khalija: your house arrest is lifted. You may leave your suite.',
      assigneRefus: 'You are under house arrest in your Royal Hotel suite until your next “Sleep”.',
      tito: 'Tito Maletas pockets the note and lowers his voice: “The Roxane Velours network is everywhere in the world, and its escorts hear every confidence. About {cible}, I was told this: {secret}”',
      titoRien: 'Tito Maletas pockets the note: “The Roxane Velours network hasn’t heard anything interesting lately.”' },
    es: { forcerNote: '2 PA. Probabilidad: 60 % + 4 % por punto de VOL por encima de 13 (− 4 % por debajo). Fracaso: arresto domiciliario en su suite del hotel, invitación de la casa, hasta su próximo «Dormir». Éxito: circula libremente por las salas reservadas hasta salir del hotel, sin ser buscado.',
      assigne: 'Los guardianes le acompañan cortésmente a su suite, invitación de la casa: queda bajo arresto domiciliario. No puede salir; puede dormir, pedir servicio de habitaciones, escribir e ir al foro. El arresto termina con su primer «Dormir».',
      assigneJournal: 'Hotel Real de Al-Khalija: queda bajo arresto domiciliario en su suite hasta su próximo «Dormir».',
      assigneFin: 'Hotel Real de Al-Khalija: se levanta su arresto domiciliario. Puede salir de su suite.',
      assigneRefus: 'Está bajo arresto domiciliario en su suite del Hotel Real hasta su próximo «Dormir».',
      tito: 'Tito Maletas se guarda el billete y baja la voz: «La red Roxane Velours está en todo el mundo, y sus escorts oyen todas las confidencias. Sobre {cible}, me han soplado esto: {secret}»',
      titoRien: 'Tito Maletas se guarda el billete: «La red Roxane Velours no ha oído nada interesante últimamente.»' },
    de: { forcerNote: '2 AP. Chance: 60 % + 4 % pro WIL-Punkt über 13 (− 4 % darunter). Misserfolg: Hausarrest in Ihrer Hotelsuite, auf Kosten des Hauses, bis zu Ihrem nächsten „Schlafen“. Erfolg: freie Bewegung in den reservierten Räumen bis zum Verlassen des Hotels, ohne gesucht zu werden.',
      assigne: 'Die Wächter begleiten Sie höflich in Ihre Suite, auf Kosten des Hauses: Sie stehen unter Hausarrest. Sie können sie nicht verlassen; Sie können schlafen, den Zimmerservice bestellen, Briefe schreiben und ins Forum gehen. Der Hausarrest endet mit Ihrem ersten „Schlafen“.',
      assigneJournal: 'Königliches Hotel von Al-Khalija: Sie stehen bis zu Ihrem nächsten „Schlafen“ unter Hausarrest in Ihrer Suite.',
      assigneFin: 'Königliches Hotel von Al-Khalija: Ihr Hausarrest ist aufgehoben. Sie dürfen Ihre Suite verlassen.',
      assigneRefus: 'Sie stehen bis zu Ihrem nächsten „Schlafen“ unter Hausarrest in Ihrer Suite des Königlichen Hotels.',
      tito: 'Tito Maletas steckt den Schein ein und senkt die Stimme: „Das Netzwerk Roxane Velours ist überall auf der Welt, und seine Escorts hören jede Vertraulichkeit. Über {cible} hat man mir das zugeflüstert: {secret}“',
      titoRien: 'Tito Maletas steckt den Schein ein: „Das Netzwerk Roxane Velours hat in letzter Zeit nichts Interessantes gehört.“' },
    ru: { forcerNote: '2 ОД. Шанс: 60 % + 4 % за каждое очко ВОЛ выше 13 (− 4 % ниже). Неудача: домашний арест в вашем номере-люкс за счёт заведения до следующего «Спать». Успех: свободный проход по закрытым залам до выхода из отеля, без розыска.',
      assigne: 'Охрана вежливо провожает вас в ваш люкс, за счёт заведения: вы под домашним арестом. Выйти нельзя; можно спать, заказывать обслуживание в номер, писать письма и заходить на форум. Арест заканчивается при первом «Спать».',
      assigneJournal: 'Королевский отель Al-Khalija: вы под домашним арестом в своём люксе до следующего «Спать».',
      assigneFin: 'Королевский отель Al-Khalija: домашний арест снят. Вы можете покинуть люкс.',
      assigneRefus: 'Вы под домашним арестом в люксе Королевского отеля до следующего «Спать».',
      tito: 'Tito Maletas прячет купюру и понижает голос: «Сеть Roxane Velours есть по всему миру, и её эскорт слышит все откровения. Про {cible} мне шепнули вот что: {secret}»',
      titoRien: 'Tito Maletas прячет купюру: «Сеть Roxane Velours в последнее время ничего интересного не слышала.»' },
    ko: { forcerNote: '2 AP. 확률: 60% + VOL 13 초과 1점당 4% (미만은 1점당 −4%). 실패: 다음 “잠자기”까지 호텔이 무료로 제공하는 스위트룸에 가택 연금. 성공: 호텔을 나갈 때까지 전용 구역을 자유롭게 다니며 수배되지 않습니다.',
      assigne: '경비원이 정중하게 당신을 호텔이 무료로 제공하는 스위트룸으로 데려갑니다. 가택 연금입니다. 밖으로 나갈 수 없지만 잠자기, 룸서비스 주문, 편지 쓰기, 포럼 이용은 가능합니다. 첫 “잠자기”와 함께 연금이 끝납니다.',
      assigneJournal: 'Al-Khalija 왕립 호텔: 다음 “잠자기”까지 스위트룸에 가택 연금되었습니다.',
      assigneFin: 'Al-Khalija 왕립 호텔: 가택 연금이 해제되었습니다. 스위트룸을 나갈 수 있습니다.',
      assigneRefus: '다음 “잠자기”까지 왕립 호텔 스위트룸에 가택 연금 중입니다.',
      tito: 'Tito Maletas가 지폐를 챙기며 목소리를 낮춥니다. "Roxane Velours 네트워크는 전 세계 어디에나 있고, 그곳 에스코트들은 모든 속내를 듣지요. {cible}에 대해선 이런 얘기를 들었습니다: {secret}"',
      titoRien: 'Tito Maletas가 지폐를 챙깁니다. "Roxane Velours 네트워크도 요즘은 흥미로운 얘기를 듣지 못했네요."' },
    ar: { forcerNote: 'نقطتا عمل. الفرصة: 60٪ + 4٪ لكل نقطة إرادة فوق 13 (− 4٪ تحتها). الفشل: إقامة جبرية في جناحك بالفندق، على حساب الدار، حتى «النوم» التالي. النجاح: تتنقل بحرية في القاعات المحجوزة حتى تغادر الفندق، دون أن تكون مطلوبًا.',
      assigne: 'يرافقك الحراس بأدب إلى جناحك، على حساب الدار: أنت تحت الإقامة الجبرية. لا يمكنك الخروج منه؛ يمكنك النوم وطلب خدمة الغرف وكتابة الرسائل وزيارة المنتدى. تنتهي الإقامة الجبرية عند أول «نوم».',
      assigneJournal: 'الفندق الملكي في Al-Khalija: أنت تحت الإقامة الجبرية في جناحك حتى «النوم» التالي.',
      assigneFin: 'الفندق الملكي في Al-Khalija: رُفعت عنك الإقامة الجبرية. يمكنك مغادرة جناحك.',
      assigneRefus: 'أنت تحت الإقامة الجبرية في جناحك بالفندق الملكي حتى «النوم» التالي.',
      tito: 'يدسّ Tito Maletas الورقة في جيبه ويخفض صوته: «شبكة Roxane Velours في كل مكان من العالم، ومرافقوها يسمعون كل الأسرار. عن {cible} همسوا لي بهذا: {secret}»',
      titoRien: 'يدسّ Tito Maletas الورقة في جيبه: «لم تسمع شبكة Roxane Velours شيئًا مثيرًا في الآونة الأخيرة.»' },
    'pt-BR': { forcerNote: '2 PA. Chance: 60% + 4% por ponto de VON acima de 13 (− 4% abaixo). Falha: prisão domiciliar na sua suíte do hotel, por conta da casa, até o seu próximo “Dormir”. Sucesso: você circula livremente pelas salas reservadas até sair do hotel, sem ser procurado.',
      assigne: 'Os guardas o acompanham educadamente até a sua suíte, por conta da casa: você está em prisão domiciliar. Não pode sair; pode dormir, pedir serviço de quarto, escrever cartas e ir ao fórum. A prisão domiciliar termina no seu primeiro “Dormir”.',
      assigneJournal: 'Hotel Real de Al-Khalija: você está em prisão domiciliar na sua suíte até o seu próximo “Dormir”.',
      assigneFin: 'Hotel Real de Al-Khalija: sua prisão domiciliar foi suspensa. Você pode sair da sua suíte.',
      assigneRefus: 'Você está em prisão domiciliar na sua suíte do Hotel Real até o seu próximo “Dormir”.',
      tito: 'Tito Maletas embolsa a nota e baixa a voz: “A rede Roxane Velours está no mundo inteiro, e as escorts ouvem todas as confidências. Sobre {cible}, me sopraram isto: {secret}”',
      titoRien: 'Tito Maletas embolsa a nota: “A rede Roxane Velours não ouviu nada interessante ultimamente.”' },
    'zh-TW': { forcerNote: '2 行動點。機率：60% ＋意志每高於 13 一點加 4%（低於則每點減 4%）。失敗：在飯店招待的套房內軟禁，直到您下一次「睡覺」。成功：離開飯店前可自由出入保留區，且不會被通緝。',
      assigne: '守衛客氣地送您回到飯店招待的套房：您遭到軟禁。您不能離開套房，但可以睡覺、叫客房服務、寫信和上論壇。軟禁在您第一次「睡覺」時結束。',
      assigneJournal: 'Al-Khalija皇家飯店：您在套房內遭到軟禁，直到下一次「睡覺」。',
      assigneFin: 'Al-Khalija皇家飯店：您的軟禁已解除，可以離開套房了。',
      assigneRefus: '您在皇家飯店的套房內遭到軟禁，直到下一次「睡覺」。',
      tito: 'Tito Maletas收下鈔票，壓低聲音：「Roxane Velours的網絡遍布全世界，她們的伴遊聽得到所有的心事。關於{cible}，有人跟我說了這個：{secret}」',
      titoRien: 'Tito Maletas收下鈔票：「Roxane Velours的網絡最近沒聽到什麼有意思的事。」' }
  };
  for (const l of Object.keys(T_SUITE)) Object.assign(T[l], T_SUITE[l]);

  function t(cle, vars) {
    const l = T[langue()];
    let s = (l[cle] !== undefined ? l[cle] : T.fr[cle]) || cle;
    Object.keys(vars || {}).forEach(k => { s = s.split('{' + k + '}').join(String(vars[k])); });
    return s;
  }
  const motif = v => { const m = T[langue()].m, k = v?.raison; return (k && (m[k] || T.fr.m[k])) || m.indispo; };
  const ech = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const toast = (titre, corps) => { if (typeof showToast === 'function') showToast(titre, corps, false); };
  const fermer = () => document.getElementById('modal-postes')?.classList.remove('open');
  const titreLieu = () => state.country === 'khalija' ? t('tHotelAM') : (state.currentBuilding === 'hotel-republica' ? t('tHotelCR') : t('tDouane'));
  function fenetre(titre, html) {
    const t1 = document.getElementById('postes-modal-title'), b = document.getElementById('postes-body'), m = document.getElementById('modal-postes');
    if (!t1 || !b || !m) return null;
    t1.textContent = titre;
    b.innerHTML = '<div class="cpj-dialogue hotels-teaser" dir="auto">' + html + '</div>';
    m.classList.add('open');
    return b;
  }
  const bouton = (id, libelle, primaire) => '<button type="button" id="' + id + '" class="cpj-touche' + (primaire ? ' cpj-touche-primaire' : '') + '" style="margin:.25rem">' + ech(libelle) + '</button>';

  // Joueurs et PNJ affichés dans la pièce (la présence réelle est revérifiée par le serveur).
  const nomsCartes = joueurs => Array.from(document.querySelectorAll('.person-card' + (joueurs ? '.vrai-joueur-card' : ':not(.vrai-joueur-card)') + ' .person-name'))
    .map(el => el.textContent.replace(/\s*\(PNJ\)\s*$/, '').trim()).filter(Boolean).filter((n, i, a) => a.indexOf(n) === i);

  let enCours = false;
  async function acte(rpc, params, geste) {
    if (enCours) return null;
    enCours = true;
    const cle = 'hg-hotel-teaser:' + (state.char?.name || '') + ':' + rpc + ':' + geste;
    try {
      let requete = sessionStorage.getItem(cle);
      if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
      const v = await sbRpcVerdict(rpc, Object.assign({ p_requete: requete }, params)).catch(() => null);
      if (v && !v.transport) sessionStorage.removeItem(cle);
      if (v && v.ok === true) {
        if (Array.isArray(v.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
        if (typeof appliquerPaiementServeur === 'function' && (v.pa != null || v.liquide != null)) appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide });
        if (typeof updateHeader === 'function') updateHeader();
        if (typeof updateUI === 'function') updateUI();
      }
      return v;
    } finally { enCours = false; }
  }

  function demander(titre, champs, suite) {
    const html = champs.map((c, i) => '<label style="display:block;margin:.4rem 0">' + ech(c.libelle)
      + (c.choix && c.choix.length
        ? '<select id="ht-champ-' + i + '" style="display:block;width:100%">' + c.choix.map(n => '<option>' + ech(n) + '</option>').join('') + '</select>'
        : '<input id="ht-champ-' + i + '" type="' + (c.nombre ? 'number' : 'text') + '"' + (c.nombre ? ' min="1" step="1"' : '') + ' style="display:block;width:100%">')
      + '</label>').join('') + '<div style="text-align:center">' + bouton('ht-ok', t('valider'), true) + bouton('ht-non', t('annuler')) + '</div>';
    const b = fenetre(titre, html);
    if (!b) return;
    b.querySelector('#ht-non').onclick = fermer;
    b.querySelector('#ht-ok').onclick = () => {
      const valeurs = champs.map((c, i) => { const v = b.querySelector('#ht-champ-' + i).value.trim(); return c.nombre ? Math.floor(Number(v)) : v; });
      if (valeurs.some((v, i) => champs[i].nombre ? !(v >= 1) : !v)) return;
      fermer(); suite(...valeurs);
    };
  }

  async function executer(fn, cible, montant) {
    const v = await acte('hotel_teaser_agir', { p_action: fn, p_cible: cible ?? null, p_montant: montant ?? null }, fn + ':' + (cible || '') + ':' + (montant || ''));
    if (!v) return;
    if (v.ok !== true) { toast(t('refus'), motif(v)); return; }
    let corps = t('ok');
    if (fn === 'cr_pourboire' && v.tito) corps = v.tito.cible ? t('tito', { cible: v.tito.cible, secret: v.tito.secret || '' }) : t('titoRien');
    if (fn === 'cr_billet_douaniers') {
      corps = v.reussi ? t('billetOk', { taux: v.taux }) : t('billetKo', { taux: v.taux }) + ' '
        + ((v.saisis || []).length ? t('saisis', { noms: v.saisis.map(o => o.name || o.nom).join(', ') }) : t('rienSaisi'));
    }
    if (fn === 'am_the_special' && v.police_moeurs) corps = t('police', { amende: v.amende });
    if (fn === 'am_narguile' && v.secret_lache) corps = t('narguileSecret', { secret: v.secret, n: v.temoins || 0 });
    if (fn === 'am_secret_contre_secret') corps = v.reussi ? t('scsOk', { taux: v.taux, cible: v.cible }) : (v.critique ? t('scsCrit', { cible: v.cible }) : t('scsKo', { taux: v.taux, cible: v.cible }));
    if (fn === 'am_backgammon') corps = t('bgDefi', { cible: v.cible, mise: v.mise });
    toast(titreLieu(), corps);
  }

  async function backgammon() {
    const l = await sbRpcVerdict('hotel_backgammon_lister', {}).catch(() => null);
    const recus = (l && l.ok === true && l.recus) || [];
    const html = '<h4 style="margin:.2rem 0">' + ech(t('bgRecus')) + '</h4>'
      + (recus.length ? recus.map(d => '<p>' + ech(t('bgDe', { auteur: d.auteur, mise: d.mise })) + '<br>'
          + bouton('ht-bg-oui-' + d.id, t('bgAccepter'), true) + bouton('ht-bg-non-' + d.id, t('bgRefuser')) + '</p>').join('')
        : '<p>' + ech(t('bgAucun')) + '</p>')
      + '<div style="text-align:center;margin-top:.6rem">' + bouton('ht-bg-lancer', t('bgLancer'), true) + '</div>';
    const b = fenetre(t('tBg'), html);
    if (!b) return;
    recus.forEach(d => {
      b.querySelector('#ht-bg-oui-' + d.id).onclick = () => repondre(d, true);
      b.querySelector('#ht-bg-non-' + d.id).onclick = () => repondre(d, false);
    });
    b.querySelector('#ht-bg-lancer').onclick = () => demander(t('bgLancer'),
      [{ libelle: t('cible'), choix: nomsCartes(true) }, { libelle: t('montant') + ' (DR)', nombre: true }],
      (cible, mise) => executer('am_backgammon', cible, mise));
  }
  async function repondre(d, accepter) {
    fermer();
    const v = await acte('hotel_backgammon_repondre', { p_defi: d.id, p_accepter: accepter }, 'bg:' + d.id + ':' + accepter);
    if (!v) return;
    if (v.ok !== true) { toast(t('tBg'), motif(v)); return; }
    toast(t('tBg'), !v.accepte ? t('bgRefuse') : (v.gagne ? t('bgGagne', { mise: v.mise }) : t('bgPerdu', { mise: v.mise })));
  }

  function hotelTeaserOrdre(fn) {
    if (fn === 'cr_billet_douaniers') return demander(t('tDouane'), [{ libelle: t('montant') + ' (PS)', nombre: true }], m => executer(fn, null, m));
    if (fn === 'cr_pourboire') return demander(t('tHotelCR'), [{ libelle: t('personnel'), choix: nomsCartes(false) }], c => executer(fn, c, null));
    if (fn === 'am_secret_contre_secret') return demander(t('tHotelAM'), [{ libelle: t('cible'), choix: nomsCartes(true) }], c => executer(fn, c, null));
    if (fn === 'am_backgammon') return backgammon();
    return executer(fn, null, null);
  }

  // Accès réservés de l'Hôtel Royal : infobulle de l'onglet et fenêtre de refus.
  const RESERVEES = { salon_gentlemen: 'H', hammam_hommes: 'H', hammam_femmes: 'F' };
  function hotelTeaserOngletReserve(batiment, piece) {
    if (state.country !== 'khalija' || state.currentCity !== 'capitale' || batiment !== 'hotel-republica' || !RESERVEES[piece]) return '';
    return RESERVEES[piece] === 'H' ? t('reserveH') : t('reserveF');
  }
  function hotelTeaserRefus(r) {
    if (r.raison === 'assignation_residence') { toast(t('tHotelAM'), t('assigneRefus')); return true; }
    const piece = r.piece, h = r.raison === 'reserve_hommes';
    const b = fenetre(t('tHotelAM'), '<p><strong>' + ech(h ? t('reserveH') : t('reserveF')) + '</strong></p><p>' + ech(h ? t('gardeH') : t('gardeF')) + '</p>'
      + '<div style="text-align:center">' + bouton('ht-forcer', t('forcer'), true) + '</div><p class="cpj-note">' + ech(t('forcerNote')) + '</p>');
    if (b && piece) b.querySelector('#ht-forcer').onclick = () => forcer(piece);
    return true;
  }
  async function forcer(piece) {
    fermer();
    const v = await acte('acces_forcer_passage', { p_piece: piece }, 'forcer:' + piece);
    if (!v) return;
    if (v.ok !== true) { toast(t('refus'), motif(v)); return; }
    if (typeof adopterEtatCrimeServeur === 'function') adopterEtatCrimeServeur(v);
    if (v.reussi === true) {
      toast(t('tHotelAM'), t('entre'));
      if (typeof commanderNavigationInterieure === 'function') await commanderNavigationInterieure('hotel-republica', piece);
      return;
    }
    // Échec : assignation à résidence dans la suite (Fred, 28/11/2026, après-midi) ; le serveur a déjà déplacé le personnage.
    toast(t('tHotelAM'), v.assignation ? t('assigne') : t('prison'));
    if (typeof adopterPositionServeurRelue === 'function') await adopterPositionServeurRelue();
    if (typeof updateUI === 'function') updateUI();
  }

  // Journal du personnage : textes écrits ici dans la langue du joueur (le serveur envoie un texte vide).
  const gestionnaires = window.rpEvenementsPersonnageGestionnaires = window.rpEvenementsPersonnageGestionnaires || {};
  gestionnaires.assignation_hotel_royal = () => { if (typeof addJournalEntry === 'function') addJournalEntry(ech(t('assigneJournal')), 'event-bad'); };
  gestionnaires.assignation_hotel_royal_fin = () => { if (typeof addJournalEntry === 'function') addJournalEntry(ech(t('assigneFin')), 'event-good'); };

  window.hotelTeaserOrdre = hotelTeaserOrdre;
  window.hotelTeaserOngletReserve = hotelTeaserOngletReserve;
  window.hotelTeaserRefus = hotelTeaserRefus;
  window.RP_HOTELS_TEASER_T = T;
})();
