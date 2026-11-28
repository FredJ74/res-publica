// Capitales en teaser (Fred, 28/11/2026, après-midi, point 14) : noms de pièces, noms de bâtiments, rôles des PNJ et
// descriptions des ordres des deux capitales (Ciudad Roja, Al Madina), dans les neuf langues du jeu.
// Présentation seule : identifiants, ordres, coûts et profils de dialogue inchangés ; le français reste la source.
// Raccords : RPRoomI18n.label (noms de pièces), RPSovarkaRolesI18n.label (rôles affichés, via roleAfficheSovarka),
// RPOrderDescriptionsI18n.registerCatalogue (descriptions), RPTeaserCapitalesI18n.batiment (en-tête du bâtiment).
(function (global) {
  'use strict';
  const PAYS = ['narco', 'khalija'];
  const langue = () => (global.RP_I18N_GAME_ENABLED === true && global.RPPlateauI18n?.language?.()) || 'fr';
  const pays = () => (typeof state !== 'undefined' && state) ? state.country : null; // `state` : let global de plateau-core.js
  const ici = () => PAYS.includes(pays()) && (typeof state === 'undefined' || !state || !state.currentCity || state.currentCity === 'capitale');

  // [fr, en, es, de, ru, ko, ar, pt-BR, zh-TW]
  const ORDRE = ['fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW'];
  const ligne = a => Object.fromEntries(ORDRE.map((l, i) => [l, a[i]]));

  const PIECES = {
    'Piscine': ligne(['Piscine', 'Swimming pool', 'Piscina', 'Schwimmbad', 'Бассейн', '수영장', 'المسبح', 'Piscina', '游泳池']),
    'Réception': ligne(['Réception', 'Reception', 'Recepción', 'Rezeption', 'Ресепшн', '리셉션', 'الاستقبال', 'Recepção', '接待處']),
    'Restaurant': ligne(['Restaurant', 'Restaurant', 'Restaurante', 'Restaurant', 'Ресторан', '레스토랑', 'المطعم', 'Restaurante', '餐廳']),
    'Bar extérieur': ligne(['Bar extérieur', 'Outdoor bar', 'Bar exterior', 'Außenbar', 'Открытый бар', '야외 바', 'البار الخارجي', 'Bar externo', '戶外酒吧']),
    'Suite': ligne(['Suite', 'Suite', 'Suite', 'Suite', 'Люкс', '스위트룸', 'الجناح', 'Suíte', '套房']),
    'Salon de thé': ligne(['Salon de thé', 'Tea room', 'Salón de té', 'Teesalon', 'Чайный салон', '티룸', 'صالون الشاي', 'Salão de chá', '茶室']),
    'Salon des gentlemen': ligne(['Salon des gentlemen', 'Gentlemen’s lounge', 'Salón de caballeros', 'Herrensalon', 'Мужской салон', '신사 라운지', 'صالون السادة', 'Salão dos cavalheiros', '紳士沙龍']),
    'Hammam des hommes': ligne(['Hammam des hommes', 'Men’s hammam', 'Hammam de hombres', 'Männerhammam', 'Мужской хаммам', '남성 하맘', 'حمّام الرجال', 'Hammam masculino', '男子浴室']),
    'Hammam des femmes': ligne(['Hammam des femmes', 'Women’s hammam', 'Hammam de mujeres', 'Frauenhammam', 'Женский хаммам', '여성 하맘', 'حمّام النساء', 'Hammam feminino', '女子浴室'])
  };
  const SCOPES_PIECES = {
    'hotel-republica': ['piscine', 'accueil', 'restaurant', 'bar', 'chambres', 'salon_gentlemen', 'hammam_hommes', 'hammam_femmes']
  };

  const BATIMENTS = {
    'Hôtel Royal d\'Al-Khalija': ligne(['Hôtel Royal d\'Al-Khalija', 'Royal Hotel of Al-Khalija', 'Hotel Real de Al-Khalija', 'Königliches Hotel von Al-Khalija', 'Королевский отель Аль-Халиджи', '알칼리자 왕립 호텔', 'الفندق الملكي في الخليجة', 'Hotel Real de Al-Khalija', '阿爾哈利加皇家飯店']),
    'Centre multimodal d\'Al Madina': ligne(['Centre multimodal d\'Al Madina', 'Al Madina transport hub', 'Centro multimodal de Al Madina', 'Verkehrsknotenpunkt Al Madina', 'Транспортный узел Аль-Мадины', '알 마디나 복합 교통 센터', 'مركز المدينة متعدد الوسائط', 'Centro multimodal de Al Madina', '麥地那綜合交通中心']),
    'Centre multimodal de Ciudad Roja': ligne(['Centre multimodal de Ciudad Roja', 'Ciudad Roja transport hub', 'Centro multimodal de Ciudad Roja', 'Verkehrsknotenpunkt Ciudad Roja', 'Транспортный узел Сьюдад-Рохи', '시우다드 로하 복합 교통 센터', 'مركز سيوداد روخا متعدد الوسائط', 'Centro multimodal de Ciudad Roja', '紅城綜合交通中心'])
  };

  const ROLES = {
    'Escort de l’hôtel': ligne(['Escort de l’hôtel', 'Hotel escort', 'Acompañante del hotel', 'Hotel-Begleitung', 'Эскорт отеля', '호텔 에스코트', 'مرافقة الفندق', 'Acompanhante do hotel', '飯店伴遊']),
    'Caudillo en villégiature': ligne(['Caudillo en villégiature', 'Caudillo on holiday', 'Caudillo de vacaciones', 'Caudillo im Urlaub', 'Каудильо на отдыхе', '휴가 중인 카우디요', 'زعيم في عطلة', 'Caudilho em férias', '度假中的獨裁者']),
    'Réceptionniste en chef': ligne(['Réceptionniste en chef', 'Head receptionist', 'Recepcionista jefe', 'Empfangschefin', 'Старший администратор', '수석 접수원', 'رئيسة الاستقبال', 'Recepcionista-chefe', '首席接待員']),
    'Chef de la sécurité': ligne(['Chef de la sécurité', 'Head of security', 'Jefe de seguridad', 'Sicherheitschef', 'Начальник охраны', '보안 책임자', 'رئيس الأمن', 'Chefe de segurança', '保安主管']),
    'Bagagiste': ligne(['Bagagiste', 'Porter', 'Botones', 'Gepäckträger', 'Носильщик', '벨보이', 'حامل الأمتعة', 'Carregador', '行李員']),
    'Maître d’hôtel': ligne(['Maître d’hôtel', 'Head waiter', 'Maître', 'Oberkellner', 'Метрдотель', '지배인', 'رئيس النُّدُل', 'Maître', '餐廳領班']),
    'Barman': ligne(['Barman', 'Bartender', 'Barman', 'Barkeeper', 'Бармен', '바텐더', 'ساقي البار', 'Barman', '酒保']),
    'Serveur de narguilé': ligne(['Serveur de narguilé', 'Hookah server', 'Camarero de narguile', 'Shisha-Kellner', 'Кальянщик', '물담배 담당', 'نادل الأرجيلة', 'Garçom de narguilé', '水煙侍者']),
    'Gardien du salon': ligne(['Gardien du salon', 'Lounge guard', 'Guardián del salón', 'Wächter des Salons', 'Страж салона', '라운지 경비원', 'حارس الصالون', 'Guardião do salão', '沙龍守衛']),
    'Gardien du hammam des hommes': ligne(['Gardien du hammam des hommes', 'Men’s hammam attendant', 'Guardián del hammam de hombres', 'Wächter des Männerhammams', 'Смотритель мужского хаммама', '남성 하맘 관리인', 'حارس حمّام الرجال', 'Guardião do hammam masculino', '男子浴室看守']),
    'Matrone du hammam des femmes': ligne(['Matrone du hammam des femmes', 'Women’s hammam matron', 'Matrona del hammam de mujeres', 'Matrone des Frauenhammams', 'Матрона женского хаммама', '여성 하맘 사감', 'مشرفة حمّام النساء', 'Matrona do hammam feminino', '女子浴室女管事']),
    'Serveur du salon de thé': ligne(['Serveur du salon de thé', 'Tea room waiter', 'Camarero del salón de té', 'Kellner im Teesalon', 'Официант чайного салона', '티룸 웨이터', 'نادل صالون الشاي', 'Garçom do salão de chá', '茶室侍者']),
    'Chef de gare': ligne(['Chef de gare', 'Stationmaster', 'Jefe de estación', 'Bahnhofsvorsteher', 'Начальник вокзала', '역장', 'ناظر المحطة', 'Chefe da estação', '站長']),
    'Cheffe des douanes': ligne(['Cheffe des douanes', 'Head of customs', 'Jefa de aduanas', 'Zollchefin', 'Начальница таможни', '세관장', 'رئيسة الجمارك', 'Chefe da alfândega', '海關主管']),
    'Douanier': ligne(['Douanier', 'Customs officer', 'Aduanero', 'Zollbeamter', 'Таможенник', '세관원', 'موظف الجمارك', 'Fiscal da alfândega', '海關人員']),
    'Agente de sécurité': ligne(['Agente de sécurité', 'Security officer', 'Agente de seguridad', 'Sicherheitsbeamtin', 'Сотрудница охраны', '보안 요원', 'عنصر أمن', 'Agente de segurança', '保安人員']),
    'Référent transport': ligne(['Référent transport', 'Transport adviser', 'Referente de transporte', 'Ansprechpartner für Verkehr', 'Консультант по транспорту', '교통 안내 담당', 'مرجع النقل', 'Referência de transporte', '交通諮詢員'])
  };

  // Descriptions des ordres : clé = texte français exact de data.js.
  const DESCRIPTIONS = [
    ['+5 Santé et protection contre la canicule pour la journée. Deux fois par jour.',
     '+5 Health and protection from the heatwave for the day. Twice a day.',
     '+5 Salud y protección contra la ola de calor durante el día. Dos veces al día.',
     '+5 Gesundheit und Schutz vor der Hitzewelle für den Tag. Zweimal am Tag.',
     '+5 к Здоровью и защита от жары на день. Дважды в день.',
     '건강 +5, 하루 동안 폭염 보호. 하루 두 번.',
     '+5 صحة وحماية من موجة الحر طوال اليوم. مرتان في اليوم.',
     '+5 Saúde e proteção contra a onda de calor durante o dia. Duas vezes por dia.',
     '健康 +5，當天免受熱浪影響。每天兩次。'],
    ['−8 Santé, mais +7 influence et +5 popularité : on vous voit avec les bonnes personnes. Une fois par jour.',
     '−8 Health, but +7 influence and +5 popularity: you are seen with the right people. Once a day.',
     '−8 Salud, pero +7 influencia y +5 popularidad: le ven con la gente adecuada. Una vez al día.',
     '−8 Gesundheit, aber +7 Einfluss und +5 Beliebtheit: Man sieht Sie mit den richtigen Leuten. Einmal am Tag.',
     '−8 к Здоровью, но +7 к влиянию и +5 к популярности: вас видят с нужными людьми. Раз в день.',
     '건강 −8, 대신 영향력 +7, 인기 +5: 중요한 사람들과 함께 있는 모습이 보입니다. 하루 한 번.',
     '−8 صحة، لكن +7 نفوذ و+5 شعبية: يراك الناس مع الأشخاص المناسبين. مرة في اليوم.',
     '−8 Saúde, mas +7 influência e +5 popularidade: você é visto com as pessoas certas. Uma vez por dia.',
     '健康 −8，但影響力 +7、聲望 +5：大家看到您和對的人在一起。每天一次。'],
    ['200 PS au membre du personnel de votre choix : +1 popularité. Tito Maletas, le bagagiste, livre en prime un vrai secret sur un joueur, soufflé par le réseau Roxane Velours. Sans limite.',
     '200 PS to the staff member of your choice: +1 popularity. Tito Maletas, the porter, also passes on a real secret about a player, whispered by the Roxane Velours network. No limit.',
     '200 PS al empleado que elija: +1 popularidad. Tito Maletas, el botones, le revela además un secreto real sobre un jugador, que le sopla la red Roxane Velours. Sin límite.',
     '200 PS für ein Mitglied des Personals Ihrer Wahl: +1 Beliebtheit. Tito Maletas, der Gepäckträger, verrät Ihnen dazu ein echtes Geheimnis über einen Spieler, zugeflüstert vom Netzwerk Roxane Velours. Ohne Begrenzung.',
     '200 PS выбранному сотруднику: +1 к популярности. Носильщик Тито Малетас вдобавок выдаёт настоящий секрет о игроке, который ему нашептала сеть Роксаны Велур. Без ограничений.',
     '원하는 직원에게 200 PS: 인기 +1. 벨보이 티토 말레타스가 덤으로 록산 벨루르 네트워크에서 들은 어느 플레이어의 진짜 비밀을 알려 줍니다. 제한 없음.',
     '200 PS لمن تختار من العاملين: +1 شعبية. ويكشف لك تيتو ماليتاس، حامل الأمتعة، سرًّا حقيقيًّا عن لاعب همست به شبكة روكسان فولور. بلا حد.',
     '200 PS ao funcionário que você escolher: +1 popularidade. Tito Maletas, o carregador, ainda revela um segredo real sobre um jogador, soprado pela rede Roxane Velours. Sem limite.',
     '給您選擇的員工 200 PS：聲望 +1。行李員提托·馬萊塔斯還會附送一個由洛珊·維洛網絡透露的玩家真實秘密。無次數限制。'],
    ['Le standard de l’agence internationale Roxane Velours et les trois escorts de l’hôtel. 800 PS par escort et par jour, jusqu’à ce que vous rompiez le contrat. Réservé aux clients de l’hôtel (nuitée réservée à la réception, jusqu’à votre prochain « Dormir »). Légal, mais immoral : la rumeur coûte cher.',
     'The switchboard of the Roxane Velours international agency and the hotel’s three escorts. 800 PS per escort per day, until you end the contract. Hotel guests only (night booked at reception, until your next “Sleep”). Legal but immoral: rumours cost dearly.',
     'La centralita de la agencia internacional Roxane Velours y los tres acompañantes del hotel. 800 PS por acompañante y por día, hasta que rompa el contrato. Solo para clientes del hotel (noche reservada en recepción, hasta su próximo «Dormir»). Legal, pero inmoral: el rumor sale caro.',
     'Die Vermittlung der internationalen Agentur Roxane Velours und die drei Begleitungen des Hotels. 800 PS pro Begleitung und Tag, bis Sie den Vertrag beenden. Nur für Hotelgäste (Übernachtung an der Rezeption gebucht, bis zu Ihrem nächsten „Schlafen“). Legal, aber unmoralisch: Gerüchte kommen teuer.',
     'Коммутатор международного агентства «Роксана Велур» и три эскорта отеля. 800 PS за эскорт в день, пока вы не расторгнете контракт. Только для гостей отеля (ночь забронирована на ресепшене, до следующего «Спать»). Законно, но безнравственно: слухи обходятся дорого.',
     '록산 벨루르 국제 에이전시 교환대와 호텔 에스코트 세 명. 에스코트 한 명당 하루 800 PS, 계약을 끝낼 때까지. 호텔 투숙객 전용(리셉션에서 숙박 예약, 다음 “잠자기”까지). 합법이지만 부도덕합니다. 소문은 비쌉니다.',
     'مقسم وكالة روكسان فولور الدولية ومرافقو الفندق الثلاثة. 800 PS لكل مرافق في اليوم حتى تفسخ العقد. لنزلاء الفندق فقط (ليلة محجوزة في الاستقبال، حتى «النوم» التالي). قانوني لكنه غير أخلاقي: الشائعة مكلفة.',
     'A central da agência internacional Roxane Velours e os três acompanhantes do hotel. 800 PS por acompanhante por dia, até você romper o contrato. Só para hóspedes (pernoite reservado na recepção, até o seu próximo “Dormir”). Legal, mas imoral: o boato custa caro.',
     '洛珊·維洛國際經紀公司的總機與飯店的三位伴遊。每位伴遊每天 800 PS，直到您解約為止。僅限飯店住客（在接待處訂房，直到您下一次「睡覺」）。合法但不道德：流言代價高昂。'],
    ['+4 influence, −2 Santé. Trois par jour au plus. Dès la deuxième pipe de la journée, la langue se délie : un vrai secret sur vous échappe à tous les joueurs présents, et la rumeur court.',
     '+4 influence, −2 Health. Three a day at most. From the second pipe of the day, your tongue loosens: a real secret about you slips out to every player present, and the rumour spreads.',
     '+4 influencia, −2 Salud. Tres al día como máximo. Desde la segunda pipa del día se le suelta la lengua: un secreto real sobre usted llega a todos los jugadores presentes y corre el rumor.',
     '+4 Einfluss, −2 Gesundheit. Höchstens drei am Tag. Ab der zweiten Pfeife des Tages löst sich die Zunge: Ein echtes Geheimnis über Sie entschlüpft allen anwesenden Spielern, und das Gerücht macht die Runde.',
     '+4 к влиянию, −2 к Здоровью. Не больше трёх в день. Со второй трубки за день язык развязывается: настоящий секрет о вас узнают все присутствующие игроки, и пойдёт слух.',
     '영향력 +4, 건강 −2. 하루 최대 세 번. 그날 두 번째 물담배부터 입이 풀립니다. 당신의 진짜 비밀이 그 자리의 모든 플레이어에게 새어 나가고 소문이 돕니다.',
     '+4 نفوذ، −2 صحة. ثلاث مرات في اليوم على الأكثر. منذ النرجيلة الثانية في اليوم ينحلّ لسانك: يفلت سرّ حقيقي عنك إلى كل اللاعبين الحاضرين، وتسري الشائعة.',
     '+4 influência, −2 Saúde. No máximo três por dia. A partir do segundo cachimbo do dia, a língua se solta: um segredo real sobre você escapa para todos os jogadores presentes, e o boato corre.',
     '影響力 +4，健康 −2。每天最多三次。從當天第二管開始，您會說溜嘴：一個關於您的真實秘密傳到所有在場玩家耳中，流言隨之傳開。'],
    ['+2 VOL pendant 6 heures, non cumulable.',
     '+2 WIL for 6 hours, not cumulative.', '+2 VOL durante 6 horas, no acumulable.', '+2 WIL für 6 Stunden, nicht kumulierbar.',
     '+2 к ВОЛ на 6 часов, не суммируется.', '6시간 동안 VOL +2, 중첩 불가.', '+2 إرادة لمدة 6 ساعات، غير قابل للتراكم.',
     '+2 VON por 6 horas, não cumulativo.', '意志 +2，持續 6 小時，不可疊加。'],
    ['Défiez un joueur présent : il accepte ou refuse. Chacun mise le montant choisi par celui qui défie. Chance : 50 % + 2 % par point d’INT d’écart. Le gagnant empoche les mises et +2 popularité.',
     'Challenge a player who is present: they accept or refuse. Each stakes the amount chosen by the challenger. Chance: 50% + 2% per point of INT difference. The winner pockets the stakes and +2 popularity.',
     'Desafíe a un jugador presente: acepta o rechaza. Cada uno apuesta la cantidad elegida por quien desafía. Probabilidad: 50 % + 2 % por punto de diferencia de INT. El ganador se lleva las apuestas y +2 popularidad.',
     'Fordern Sie einen anwesenden Spieler heraus: Er nimmt an oder lehnt ab. Jeder setzt den vom Herausforderer gewählten Betrag. Chance: 50 % + 2 % pro Punkt INT-Unterschied. Der Gewinner streicht die Einsätze ein und erhält +2 Beliebtheit.',
     'Бросьте вызов присутствующему игроку: он принимает или отказывается. Каждый ставит сумму, выбранную бросившим вызов. Шанс: 50 % + 2 % за каждое очко разницы ИНТ. Победитель забирает ставки и +2 к популярности.',
     '자리에 있는 플레이어에게 도전하세요. 상대는 수락하거나 거절합니다. 둘 다 도전자가 정한 금액을 겁니다. 확률: 50% + INT 차이 1점당 2%. 승자는 판돈과 인기 +2를 가져갑니다.',
     'تحدَّ لاعبًا حاضرًا: يقبل أو يرفض. يراهن كل منكما بالمبلغ الذي يختاره صاحب التحدي. الفرصة: 50٪ + 2٪ لكل نقطة فرق في الذكاء. يربح الفائز الرهانات و+2 شعبية.',
     'Desafie um jogador presente: ele aceita ou recusa. Cada um aposta o valor escolhido por quem desafia. Chance: 50% + 2% por ponto de diferença de INT. O vencedor embolsa as apostas e +2 popularidade.',
     '向在場的玩家挑戰：對方可接受或拒絕。雙方都押上挑戰者選定的金額。機率：50% ＋智力每差一點 2%。勝者拿走賭注並獲得聲望 +2。'],
    ['Visez un joueur de la même pièce, une fois par jour et par cible, sans son accord. Chance : 50 % + 3 % par point de CHA au-dessus de 8 − 3 % par point de VOL de la cible au-dessus de 8 (entre 10 et 90 %). Réussite : chacun apprend un vrai secret de l’autre. Échec : rien, et la cible n’est pas prévenue ; une fois sur dix, c’est elle qui apprend un de vos secrets.',
     'Target a player in the same room, once a day per target, without their consent. Chance: 50% + 3% per CHA point above 8 − 3% per target WIL point above 8 (between 10 and 90%). Success: each learns a real secret of the other. Failure: nothing, and the target is not warned; one time in ten, they learn one of your secrets.',
     'Elija a un jugador de la misma sala, una vez al día por objetivo, sin su consentimiento. Probabilidad: 50 % + 3 % por punto de CAR por encima de 8 − 3 % por punto de VOL del objetivo por encima de 8 (entre 10 y 90 %). Éxito: cada uno conoce un secreto real del otro. Fracaso: nada, y el objetivo no se entera; una vez de cada diez, es él quien conoce uno de sus secretos.',
     'Wählen Sie einen Spieler im selben Raum, einmal am Tag pro Ziel, ohne seine Zustimmung. Chance: 50 % + 3 % pro CHA-Punkt über 8 − 3 % pro WIL-Punkt des Ziels über 8 (zwischen 10 und 90 %). Erfolg: Jeder erfährt ein echtes Geheimnis des anderen. Misserfolg: nichts, und das Ziel wird nicht gewarnt; in einem von zehn Fällen erfährt es eines Ihrer Geheimnisse.',
     'Выберите игрока в той же комнате, раз в день на каждую цель, без его согласия. Шанс: 50 % + 3 % за каждое очко ХАР выше 8 − 3 % за каждое очко ВОЛ цели выше 8 (от 10 до 90 %). Успех: каждый узнаёт настоящий секрет другого. Неудача: ничего, и цель не предупреждена; в одном случае из десяти уже она узнаёт ваш секрет.',
     '같은 방의 플레이어 한 명을 동의 없이 지목합니다. 대상마다 하루 한 번. 확률: 50% + 8을 넘는 CHA 1점당 3% − 8을 넘는 대상 VOL 1점당 3% (10~90%). 성공: 서로 상대의 진짜 비밀을 하나씩 알게 됩니다. 실패: 아무 일도 없고 대상은 모릅니다. 열 번에 한 번은 대상이 당신의 비밀을 알게 됩니다.',
     'استهدف لاعبًا في القاعة نفسها، مرة في اليوم لكل هدف، دون موافقته. الفرصة: 50٪ + 3٪ لكل نقطة جاذبية فوق 8 − 3٪ لكل نقطة إرادة لدى الهدف فوق 8 (بين 10 و90٪). النجاح: يعرف كلٌّ منكما سرًّا حقيقيًّا للآخر. الفشل: لا شيء، ولا يُنبَّه الهدف؛ ومرة من كل عشر، هو من يعرف أحد أسرارك.',
     'Escolha um jogador da mesma sala, uma vez por dia por alvo, sem o consentimento dele. Chance: 50% + 3% por ponto de CAR acima de 8 − 3% por ponto de VON do alvo acima de 8 (entre 10 e 90%). Sucesso: cada um descobre um segredo real do outro. Falha: nada, e o alvo não é avisado; uma vez em dez, é ele quem descobre um dos seus segredos.',
     '未經同意，鎖定同一房間的一名玩家，每個目標每天一次。機率：50% ＋魅力每高於 8 一點加 3% −目標意志每高於 8 一點減 3%（介於 10% 到 90%）。成功：雙方各得知對方一個真實秘密。失敗：什麼也沒發生，目標不會察覺；十次中有一次，反而是對方得知您的一個秘密。'],
    ['+6 Santé et guérit la gueule de bois. Une fois par jour.',
     '+6 Health and cures hangovers. Once a day.', '+6 Salud y cura la resaca. Una vez al día.', '+6 Gesundheit und heilt den Kater. Einmal am Tag.',
     '+6 к Здоровью и лечит похмелье. Раз в день.', '건강 +6, 숙취 해소. 하루 한 번.', '+6 صحة ويشفي من آثار السُّكر. مرة في اليوم.',
     '+6 Saúde e cura a ressaca. Uma vez por dia.', '健康 +6，並治好宿醉。每天一次。'],
    ['+2 Santé.', '+2 Health.', '+2 Salud.', '+2 Gesundheit.', '+2 к Здоровью.', '건강 +2.', '+2 صحة.', '+2 Saúde.', '健康 +2。'],
    ['Un repas léger.', 'A light meal.', 'Una comida ligera.', 'Eine leichte Mahlzeit.', 'Лёгкий перекус.', '가벼운 식사.', 'وجبة خفيفة.', 'Uma refeição leve.', '一份輕食。'],
    ['+1 Santé et protection contre la chaleur pour la journée.',
     '+1 Health and protection from the heat for the day.', '+1 Salud y protección contra el calor durante el día.', '+1 Gesundheit und Schutz vor der Hitze für den Tag.',
     '+1 к Здоровью и защита от жары на день.', '건강 +1, 하루 동안 더위 보호.', '+1 صحة وحماية من الحر طوال اليوم.',
     '+1 Saúde e proteção contra o calor durante o dia.', '健康 +1，當天免受高溫影響。'],
    ['Nabil Naana sert de l’alcool dans une théière : effets habituels de l’alcool. Une fois sur dix, la police des mœurs est prévenue : 1 000 DR d’amende, sans prison.',
     'Nabil Naana serves alcohol in a teapot: the usual effects of alcohol. One time in ten, the morality police are told: 1,000 DR fine, no prison.',
     'Nabil Naana sirve alcohol en una tetera: efectos habituales del alcohol. Una vez de cada diez, avisan a la policía de costumbres: multa de 1 000 DR, sin cárcel.',
     'Nabil Naana serviert Alkohol in einer Teekanne: die üblichen Wirkungen von Alkohol. In einem von zehn Fällen wird die Sittenpolizei informiert: 1 000 DR Geldstrafe, kein Gefängnis.',
     'Набиль Наана подаёт алкоголь в чайнике: обычное действие алкоголя. В одном случае из десяти полицию нравов предупреждают: штраф 1 000 DR, без тюрьмы.',
     '나빌 나아나가 찻주전자에 술을 담아 내옵니다. 술의 일반적인 효과가 있습니다. 열 번에 한 번은 풍기 단속 경찰에 신고되어 벌금 1,000 DR을 내지만 감옥에는 가지 않습니다.',
     'يقدّم نبيل نعناع الكحول في إبريق شاي: آثار الكحول المعتادة. ومرة من كل عشر تُبلَّغ شرطة الآداب: غرامة 1000 DR دون سجن.',
     'Nabil Naana serve álcool num bule de chá: efeitos habituais do álcool. Uma vez em dez, a polícia de costumes é avisada: multa de 1.000 DR, sem prisão.',
     '納比勒·納阿納用茶壺盛酒端上：一般飲酒效果。十次中有一次會被舉報給風化警察：罰款 1,000 DR，不必坐牢。'],
    ['Vous choisissez le montant. Chance : 50 % + 1 % par tranche de 10 PS + 2 % par point de CHA et d’ENT au-dessus de 8 + 1 % par 3 points d’indice de sécurité sous 50 (95 % au plus). Réussite : vous passez sans confiscation. Échec : le billet est perdu et vos objets illégaux sont saisis, sans arrestation ni amende.',
     'You choose the amount. Chance: 50% + 1% per 10 PS + 2% per CHA and ENT point above 8 + 1% per 3 points of security index below 50 (95% at most). Success: you pass without confiscation. Failure: the note is lost and your illegal items are seized, with no arrest or fine.',
     'Usted elige la cantidad. Probabilidad: 50 % + 1 % por cada 10 PS + 2 % por punto de CAR y de EMP por encima de 8 + 1 % por cada 3 puntos de índice de seguridad por debajo de 50 (95 % como máximo). Éxito: pasa sin confiscación. Fracaso: el billete se pierde y le requisan los objetos ilegales, sin arresto ni multa.',
     'Sie wählen den Betrag. Chance: 50 % + 1 % je 10 PS + 2 % pro CHA- und UNT-Punkt über 8 + 1 % je 3 Punkte Sicherheitsindex unter 50 (höchstens 95 %). Erfolg: Sie kommen ohne Beschlagnahme durch. Misserfolg: Der Schein ist verloren und Ihre illegalen Gegenstände werden beschlagnahmt, ohne Festnahme oder Geldstrafe.',
     'Сумму выбираете вы. Шанс: 50 % + 1 % за каждые 10 PS + 2 % за каждое очко ХАР и ПРЕД выше 8 + 1 % за каждые 3 пункта индекса безопасности ниже 50 (не более 95 %). Успех: вы проходите без конфискации. Неудача: купюра потеряна, незаконные предметы изъяты, без ареста и штрафа.',
     '금액은 직접 정합니다. 확률: 50% + 10 PS당 1% + 8을 넘는 CHA와 ENT 1점당 2% + 50 미만 치안 지수 3점당 1% (최대 95%). 성공: 압수 없이 통과합니다. 실패: 지폐를 잃고 불법 물품을 압수당하지만 체포나 벌금은 없습니다.',
     'أنت تختار المبلغ. الفرصة: 50٪ + 1٪ لكل 10 PS + 2٪ لكل نقطة جاذبية وريادة فوق 8 + 1٪ لكل 3 نقاط من مؤشر الأمن تحت 50 (95٪ على الأكثر). النجاح: تمرّ دون مصادرة. الفشل: تضيع الورقة وتُصادَر أغراضك غير القانونية، دون اعتقال ولا غرامة.',
     'Você escolhe o valor. Chance: 50% + 1% a cada 10 PS + 2% por ponto de CAR e EMP acima de 8 + 1% a cada 3 pontos de índice de segurança abaixo de 50 (no máximo 95%). Sucesso: você passa sem confisco. Falha: a nota é perdida e seus objetos ilegais são apreendidos, sem prisão nem multa.',
     '金額由您決定。機率：50% ＋每 10 PS 加 1% ＋魅力與企圖心每高於 8 一點加 2% ＋治安指數每低於 50 三點加 1%（最高 95%）。成功：不被沒收即可通過。失敗：鈔票白給，違禁物品被沒收，但不會被逮捕或罰款。']
  ];

  function traduit(table, fr) {
    const l = langue(); if (l === 'fr' || !ici()) return null;
    const t = table[fr]?.[l]; return typeof t === 'string' && t.trim() ? t : null;
  }
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // Noms de pièces : avant la chaîne existante.
  const salles = global.RPRoomI18n;
  const pieceTeaser = (b, r, o) => (SCOPES_PIECES[b] || []).includes(r) ? traduit(PIECES, o) : null;
  global.RPRoomI18n = Object.freeze({
    label: (b, r, o) => pieceTeaser(b, r, o) || (salles ? salles.label(b, r, o) : o),
    labelHtml: (b, r, o) => { const t = pieceTeaser(b, r, o); return t ? esc(t) : (salles ? salles.labelHtml(b, r, o) : o); }
  });

  // Rôles des PNJ : « (PNJ) » et « PNJ - » conservés comme dans le catalogue de Sovarka.
  const roles = global.RPSovarkaRolesI18n;
  const PREFIXE = { fr: 'PNJ', en: 'NPC', es: 'PNJ', 'zh-TW': 'NPC', ru: 'НИП', ko: 'NPC', ar: 'NPC', 'pt-BR': 'NPC', de: 'NSC' };
  function roleTeaser(role) {
    if (typeof role !== 'string') return null;
    let pre = '', coeur = role, suf = '';
    if (coeur.startsWith('PNJ - ')) { pre = 'PNJ - '; coeur = coeur.slice(6); }
    if (coeur.endsWith(' (PNJ)')) { suf = ' (PNJ)'; coeur = coeur.slice(0, -6); }
    const t = traduit(ROLES, coeur.replace(/'/g, '’')); if (!t) return null;
    const p = PREFIXE[langue()] || 'NPC';
    return (pre ? p + ' - ' : '') + t + (suf ? ' (' + p + ')' : '');
  }
  global.RPSovarkaRolesI18n = Object.freeze(Object.assign({}, roles || {}, {
    label: role => roleTeaser(role) || (roles ? roles.label(role) : role)
  }));

  // Descriptions des ordres (catalogue des infobulles, seulement en El Estado et en Al-Khalija).
  const COLONNES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
  const lignes = DESCRIPTIONS.map(d => { const o = ligne(d); return COLONNES.map(l => o[l]); });
  global.RPOrderDescriptionsI18n?.registerCatalogue?.({ id: 'teaser-capitales', countries: PAYS.slice(), rows: lignes });

  global.RPTeaserCapitalesI18n = Object.freeze({
    batiment: (buildingId, nom) => traduit(BATIMENTS, nom) || nom,
    piece: (b, r, o) => pieceTeaser(b, r, o) || o,
    role: role => roleTeaser(role) || role,
    langues: Object.freeze(ORDRE.slice()),
    tables: Object.freeze({ PIECES, BATIMENTS, ROLES, DESCRIPTIONS })
  });
})(typeof window !== 'undefined' ? window : globalThis);
