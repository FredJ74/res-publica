// MALADIES — LOT 1 (Fred, 18/11/2026 ; GAME-DESIGN-MALADIES-CLIMAT.md §§ 2 et 11).
// Le serveur décide de tout (migration 20261118060000) : contraction, malus, plafond de PA, guérison au Dormir,
// stock et prix de la pharmacie. L'écran affiche ses verdicts : état de santé, pharmacie, prise de médicament,
// symptômes des personnes présentes (jamais le nom de la maladie). Textes dans les neuf langues ; le nom et le
// symptôme temporaires fixés par le MJ sont affichés tels quels.
(function (global) {
'use strict';
const T = {
  fr: {
    n_intoxication: 'Intoxication alimentaire', n_gueule_de_bois: 'Gueule de bois', n_grippe: 'Grippe', n_coup_de_chaleur: 'Coup de chaleur',
    s_intoxication: 'Vous vomissez toutes les 10 minutes, ce qui vous rend moins charmeur.',
    s_gueule_de_bois: 'La lumière vous agresse et chaque pensée vous coûte.',
    s_grippe: 'Vous avez le nez qui coule et les idées embrumées.',
    s_coup_de_chaleur: 'Vous avez la tête qui tourne et transpirez à grosses gouttes.',
    o_intoxication: 'Teint verdâtre, une main sur le ventre, s’éclipse souvent.',
    o_gueule_de_bois: 'Yeux cernés, plisse les paupières à la moindre lumière.',
    o_grippe: 'Tousse, renifle, a le nez rouge.',
    o_coup_de_chaleur: 'Visage écarlate, ruisselant de sueur, un peu chancelant.',
    m_antinauseeux: 'Anti-nauséeux', m_aspirine: 'Aspirine', m_antigrippal: 'Antigrippal', m_sels_rehydratation: 'Sels de réhydratation',
    health: 'État de santé', treated: 'traitement pris', paCap: 'PA plafonnés à {n}', noWeapon: 'bonus d’arme perdu',
    sick: 'Vous êtes malade', cured: 'Vous êtes guéri(e) : {noms}.', symptoms: 'Symptômes : {s}',
    pharmacy: 'Pharmacie', pharmacyIntro: 'Le médicament adapté guérit au prochain Dormir.',
    left: 'reste {n}', outOfStock: 'rupture', buy: 'Acheter', cancel: 'Renoncer', quantity: 'Quantité',
    bought: '{qte} × {med} pour {paye} {cur}.', take: 'Prendre', taken: 'Médicament pris : guérison au prochain Dormir.',
    drink: 'Boire', drunk: 'Vous buvez : {nom}.',
    spoiled: 'Certains de vos aliments se sont gâtés : {liste}.', a_viande: 'viande', a_viande_renne: 'viande de renne', a_laitages: 'laitages', a_poisson: 'poisson', a_fruits_legumes: 'fruits et légumes', a_oeufs: 'œufs',
    strips: 'Bandelettes réactives', stripsDeposit: 'Déposer dans ce commerce', stripsDeposited: '{n} bandelette(s) déposée(s) : réserve du commerce {reserve}.', foodRefused: 'Contrôle à la réception : {n} unité(s) avariée(s) refusée(s), détruite(s) et non payée(s).', r_pas_dans_un_commerce: 'Il faut être dans un commerce.', r_pas_de_bandelettes: 'Vous n’avez pas de bandelettes.',
    r_aucune_maladie_a_traiter: 'Ce médicament ne soigne aucun de vos maux.',
    r_deja_traitee: 'Traitement déjà pris : guérison au prochain Dormir.',
    r_rupture: 'Rupture de stock pour aujourd’hui.', r_stock_insuffisant: 'Stock insuffisant : il en reste {restant}.',
    r_fonds_insuffisants: 'Fonds insuffisants.', r_inventaire_plein: 'Inventaire plein.',
    r_pas_a_la_pharmacie: 'Il faut être au comptoir de la pharmacie.', r_pas_de_medicament: 'Vous n’avez pas ce médicament.',
    r_quantite_invalide: 'Quantité invalide (1 à 10).', refused: 'Le serveur a refusé l’opération.'
  },
  en: {
    n_intoxication: 'Food poisoning', n_gueule_de_bois: 'Hangover', n_grippe: 'Flu', n_coup_de_chaleur: 'Heatstroke',
    s_intoxication: 'You throw up every 10 minutes, which makes you less charming.',
    s_gueule_de_bois: 'The light hurts and every thought is an effort.',
    s_grippe: 'Your nose is running and your mind is foggy.',
    s_coup_de_chaleur: 'Your head is spinning and you are dripping with sweat.',
    o_intoxication: 'Greenish complexion, a hand on the stomach, keeps slipping away.',
    o_gueule_de_bois: 'Dark circles under the eyes, squinting at the slightest light.',
    o_grippe: 'Coughing, sniffling, red nose.',
    o_coup_de_chaleur: 'Scarlet face, dripping with sweat, a little unsteady.',
    m_antinauseeux: 'Anti-nausea tablets', m_aspirine: 'Aspirin', m_antigrippal: 'Flu remedy', m_sels_rehydratation: 'Rehydration salts',
    health: 'Health', treated: 'treatment taken', paCap: 'AP capped at {n}', noWeapon: 'weapon bonus lost',
    sick: 'You are ill', cured: 'You have recovered: {noms}.', symptoms: 'Symptoms: {s}',
    pharmacy: 'Pharmacy', pharmacyIntro: 'The right medicine cures you at your next Sleep.',
    left: '{n} left', outOfStock: 'out of stock', buy: 'Buy', cancel: 'Cancel', quantity: 'Quantity',
    bought: '{qte} × {med} for {paye} {cur}.', take: 'Take', taken: 'Medicine taken: you will recover at your next Sleep.',
    drink: 'Drink', drunk: 'You drink: {nom}.',
    spoiled: 'Some of your food has gone bad: {liste}.', a_viande: 'meat', a_viande_renne: 'reindeer meat', a_laitages: 'dairy', a_poisson: 'fish', a_fruits_legumes: 'fruit and vegetables', a_oeufs: 'eggs',
    strips: 'Reactive test strips', stripsDeposit: 'Leave them in this shop', stripsDeposited: '{n} strip(s) left: the shop now holds {reserve}.', foodRefused: 'Inspection on delivery: {n} spoiled unit(s) refused, destroyed and unpaid.', r_pas_dans_un_commerce: 'You must be inside a shop.', r_pas_de_bandelettes: 'You have no test strips.',
    r_aucune_maladie_a_traiter: 'This medicine treats none of your ailments.',
    r_deja_traitee: 'Treatment already taken: you will recover at your next Sleep.',
    r_rupture: 'Out of stock for today.', r_stock_insuffisant: 'Not enough stock: {restant} left.',
    r_fonds_insuffisants: 'Insufficient funds.', r_inventaire_plein: 'Inventory full.',
    r_pas_a_la_pharmacie: 'You must be at the pharmacy counter.', r_pas_de_medicament: 'You do not have this medicine.',
    r_quantite_invalide: 'Invalid quantity (1 to 10).', refused: 'The server refused the operation.'
  },
  es: {
    n_intoxication: 'Intoxicación alimentaria', n_gueule_de_bois: 'Resaca', n_grippe: 'Gripe', n_coup_de_chaleur: 'Golpe de calor',
    s_intoxication: 'Vomita cada 10 minutos, lo que le resta encanto.',
    s_gueule_de_bois: 'La luz le agrede y cada pensamiento le cuesta.',
    s_grippe: 'Le gotea la nariz y tiene las ideas nubladas.',
    s_coup_de_chaleur: 'La cabeza le da vueltas y suda a mares.',
    o_intoxication: 'Tez verdosa, una mano en el vientre, se escabulle a menudo.',
    o_gueule_de_bois: 'Ojeras, entrecierra los ojos ante la menor luz.',
    o_grippe: 'Tose, se sorbe la nariz, nariz roja.',
    o_coup_de_chaleur: 'Rostro escarlata, empapado en sudor, algo tambaleante.',
    m_antinauseeux: 'Antiemético', m_aspirine: 'Aspirina', m_antigrippal: 'Antigripal', m_sels_rehydratation: 'Sales de rehidratación',
    health: 'Estado de salud', treated: 'tratamiento tomado', paCap: 'PA limitados a {n}', noWeapon: 'bonificación de arma perdida',
    sick: 'Está enfermo/a', cured: 'Se ha curado: {noms}.', symptoms: 'Síntomas: {s}',
    pharmacy: 'Farmacia', pharmacyIntro: 'El medicamento adecuado cura en el próximo Dormir.',
    left: 'quedan {n}', outOfStock: 'agotado', buy: 'Comprar', cancel: 'Renunciar', quantity: 'Cantidad',
    bought: '{qte} × {med} por {paye} {cur}.', take: 'Tomar', taken: 'Medicamento tomado: curación en el próximo Dormir.',
    drink: 'Beber', drunk: 'Bebe: {nom}.',
    spoiled: 'Algunos de sus alimentos se han echado a perder: {liste}.', a_viande: 'carne', a_viande_renne: 'carne de reno', a_laitages: 'lácteos', a_poisson: 'pescado', a_fruits_legumes: 'frutas y verduras', a_oeufs: 'huevos',
    strips: 'Tiras reactivas', stripsDeposit: 'Dejarlas en este comercio', stripsDeposited: '{n} tira(s) entregada(s): reserva del comercio {reserve}.', foodRefused: 'Control en la recepción: {n} unidad(es) en mal estado rechazada(s), destruida(s) y no pagada(s).', r_pas_dans_un_commerce: 'Debe estar en un comercio.', r_pas_de_bandelettes: 'No tiene tiras reactivas.',
    r_aucune_maladie_a_traiter: 'Este medicamento no trata ninguno de sus males.',
    r_deja_traitee: 'Tratamiento ya tomado: curación en el próximo Dormir.',
    r_rupture: 'Agotado por hoy.', r_stock_insuffisant: 'Existencias insuficientes: quedan {restant}.',
    r_fonds_insuffisants: 'Fondos insuficientes.', r_inventaire_plein: 'Inventario lleno.',
    r_pas_a_la_pharmacie: 'Debe estar en el mostrador de la farmacia.', r_pas_de_medicament: 'No tiene este medicamento.',
    r_quantite_invalide: 'Cantidad no válida (1 a 10).', refused: 'El servidor rechazó la operación.'
  },
  'zh-TW': {
    n_intoxication: '食物中毒', n_gueule_de_bois: '宿醉', n_grippe: '流感', n_coup_de_chaleur: '中暑',
    s_intoxication: '您每 10 分鐘就嘔吐一次，魅力大減。',
    s_gueule_de_bois: '光線刺眼，每個念頭都很吃力。',
    s_grippe: '您流著鼻水，腦袋昏沉。',
    s_coup_de_chaleur: '您頭暈目眩，汗如雨下。',
    o_intoxication: '臉色發青，一手按著肚子，常常溜開。',
    o_gueule_de_bois: '黑眼圈，稍有光線就瞇起眼睛。',
    o_grippe: '咳嗽、吸鼻子、鼻頭發紅。',
    o_coup_de_chaleur: '滿臉通紅、汗流浹背，腳步有點不穩。',
    m_antinauseeux: '止吐藥', m_aspirine: '阿斯匹靈', m_antigrippal: '感冒藥', m_sels_rehydratation: '口服補液鹽',
    health: '健康狀況', treated: '已服藥', paCap: '行動點上限 {n}', noWeapon: '失去武器加成',
    sick: '您生病了', cured: '您已痊癒：{noms}。', symptoms: '症狀：{s}',
    pharmacy: '藥局', pharmacyIntro: '對症的藥物會在下次睡覺時治癒您。',
    left: '剩餘 {n}', outOfStock: '缺貨', buy: '購買', cancel: '放棄', quantity: '數量',
    bought: '{qte} × {med}，共 {paye} {cur}。', take: '服用', taken: '已服藥：下次睡覺時痊癒。',
    drink: '喝', drunk: '你喝了：{nom}。',
    spoiled: '你的部分食物已經壞了：{liste}。', a_viande: '肉', a_viande_renne: '馴鹿肉', a_laitages: '乳製品', a_poisson: '魚', a_fruits_legumes: '蔬果', a_oeufs: '蛋',
    strips: '檢測試紙', stripsDeposit: '放在這家店', stripsDeposited: '已放下 {n} 張試紙：店內存量 {reserve}。', foodRefused: '收貨檢查：{n} 單位腐壞貨品被拒收、銷毀，不予付款。', r_pas_dans_un_commerce: '你必須在商店裡。', r_pas_de_bandelettes: '你沒有檢測試紙。',
    r_aucune_maladie_a_traiter: '這種藥治不了您的任何病痛。',
    r_deja_traitee: '已服過藥：下次睡覺時痊癒。',
    r_rupture: '今日缺貨。', r_stock_insuffisant: '庫存不足：剩餘 {restant}。',
    r_fonds_insuffisants: '資金不足。', r_inventaire_plein: '物品欄已滿。',
    r_pas_a_la_pharmacie: '必須在藥局櫃檯。', r_pas_de_medicament: '您沒有這種藥。',
    r_quantite_invalide: '數量無效（1 至 10）。', refused: '伺服器拒絕了此操作。'
  },
  ru: {
    n_intoxication: 'Пищевое отравление', n_gueule_de_bois: 'Похмелье', n_grippe: 'Грипп', n_coup_de_chaleur: 'Тепловой удар',
    s_intoxication: 'Вас тошнит каждые 10 минут, и обаяния это не прибавляет.',
    s_gueule_de_bois: 'Свет режет глаза, каждая мысль даётся с трудом.',
    s_grippe: 'У вас течёт из носа и туман в голове.',
    s_coup_de_chaleur: 'У вас кружится голова, пот льёт градом.',
    o_intoxication: 'Зеленоватый цвет лица, рука на животе, то и дело исчезает.',
    o_gueule_de_bois: 'Круги под глазами, щурится от малейшего света.',
    o_grippe: 'Кашляет, шмыгает носом, нос красный.',
    o_coup_de_chaleur: 'Багровое лицо, весь в поту, слегка пошатывается.',
    m_antinauseeux: 'Противорвотное', m_aspirine: 'Аспирин', m_antigrippal: 'Противогриппозное', m_sels_rehydratation: 'Регидратационные соли',
    health: 'Здоровье', treated: 'лекарство принято', paCap: 'ОД не выше {n}', noWeapon: 'бонус оружия утрачен',
    sick: 'Вы заболели', cured: 'Вы выздоровели: {noms}.', symptoms: 'Симптомы: {s}',
    pharmacy: 'Аптека', pharmacyIntro: 'Подходящее лекарство вылечит вас при следующем сне.',
    left: 'осталось {n}', outOfStock: 'нет в наличии', buy: 'Купить', cancel: 'Отказаться', quantity: 'Количество',
    bought: '{qte} × {med} за {paye} {cur}.', take: 'Принять', taken: 'Лекарство принято: выздоровление при следующем сне.',
    drink: 'Выпить', drunk: 'Вы выпили: {nom}.',
    spoiled: 'Часть ваших продуктов испортилась: {liste}.', a_viande: 'мясо', a_viande_renne: 'оленина', a_laitages: 'молочные продукты', a_poisson: 'рыба', a_fruits_legumes: 'фрукты и овощи', a_oeufs: 'яйца',
    strips: 'Тест-полоски', stripsDeposit: 'Оставить в этом магазине', stripsDeposited: 'Оставлено полосок: {n}; запас магазина: {reserve}.', foodRefused: 'Проверка при приёмке: {n} испорченных единиц отклонено, уничтожено и не оплачено.', r_pas_dans_un_commerce: 'Нужно находиться в магазине.', r_pas_de_bandelettes: 'У вас нет тест-полосок.',
    r_aucune_maladie_a_traiter: 'Это лекарство не лечит ни одного из ваших недугов.',
    r_deja_traitee: 'Лекарство уже принято: выздоровление при следующем сне.',
    r_rupture: 'На сегодня товар закончился.', r_stock_insuffisant: 'Недостаточно запасов: осталось {restant}.',
    r_fonds_insuffisants: 'Недостаточно средств.', r_inventaire_plein: 'Инвентарь полон.',
    r_pas_a_la_pharmacie: 'Нужно быть у аптечного прилавка.', r_pas_de_medicament: 'У вас нет этого лекарства.',
    r_quantite_invalide: 'Неверное количество (от 1 до 10).', refused: 'Сервер отклонил операцию.'
  },
  ko: {
    n_intoxication: '식중독', n_gueule_de_bois: '숙취', n_grippe: '독감', n_coup_de_chaleur: '열사병',
    s_intoxication: '10분마다 구토를 해서 매력이 떨어집니다.',
    s_gueule_de_bois: '빛이 눈을 찌르고 생각 하나하나가 힘겹습니다.',
    s_grippe: '콧물이 흐르고 머리가 멍합니다.',
    s_coup_de_chaleur: '머리가 핑 돌고 땀이 비 오듯 흐릅니다.',
    o_intoxication: '안색이 푸르스름하고 배를 움켜쥔 채 자주 자리를 비운다.',
    o_gueule_de_bois: '눈 밑이 거뭇하고 작은 빛에도 눈을 찡그린다.',
    o_grippe: '기침을 하고 코를 훌쩍이며 코가 빨갛다.',
    o_coup_de_chaleur: '얼굴이 새빨갛고 땀범벅에 약간 비틀거린다.',
    m_antinauseeux: '진토제', m_aspirine: '아스피린', m_antigrippal: '감기약', m_sels_rehydratation: '경구 수분 보충염',
    health: '건강 상태', treated: '복용함', paCap: 'AP 상한 {n}', noWeapon: '무기 보너스 상실',
    sick: '병에 걸렸습니다', cured: '회복되었습니다: {noms}.', symptoms: '증상: {s}',
    pharmacy: '약국', pharmacyIntro: '맞는 약을 먹으면 다음 잠자기 때 낫습니다.',
    left: '{n}개 남음', outOfStock: '품절', buy: '구매', cancel: '취소', quantity: '수량',
    bought: '{med} {qte}개, {paye} {cur}.', take: '복용', taken: '약을 먹었습니다: 다음 잠자기 때 회복됩니다.',
    drink: '마시기', drunk: '마셨습니다: {nom}.',
    spoiled: '음식 일부가 상했습니다: {liste}.', a_viande: '고기', a_viande_renne: '순록 고기', a_laitages: '유제품', a_poisson: '생선', a_fruits_legumes: '과일과 채소', a_oeufs: '달걀',
    strips: '검사 시험지', stripsDeposit: '이 가게에 맡기기', stripsDeposited: '시험지 {n}개를 맡겼습니다: 가게 보유량 {reserve}.', foodRefused: '입고 검사: 상한 물품 {n}개가 거부되어 폐기되었고 대금은 지급되지 않았습니다.', r_pas_dans_un_commerce: '가게 안에 있어야 합니다.', r_pas_de_bandelettes: '검사 시험지가 없습니다.',
    r_aucune_maladie_a_traiter: '이 약은 당신의 어떤 병도 치료하지 않습니다.',
    r_deja_traitee: '이미 약을 먹었습니다: 다음 잠자기 때 회복됩니다.',
    r_rupture: '오늘은 품절입니다.', r_stock_insuffisant: '재고 부족: {restant}개 남음.',
    r_fonds_insuffisants: '자금이 부족합니다.', r_inventaire_plein: '인벤토리가 가득 찼습니다.',
    r_pas_a_la_pharmacie: '약국 카운터에 있어야 합니다.', r_pas_de_medicament: '이 약을 가지고 있지 않습니다.',
    r_quantite_invalide: '잘못된 수량 (1~10).', refused: '서버가 작업을 거부했습니다.'
  },
  ar: {
    n_intoxication: 'تسمم غذائي', n_gueule_de_bois: 'صداع الثمالة', n_grippe: 'إنفلونزا', n_coup_de_chaleur: 'ضربة شمس',
    s_intoxication: 'تتقيأ كل 10 دقائق، مما يقلل من جاذبيتك.',
    s_gueule_de_bois: 'الضوء يؤذيك وكل فكرة تكلّفك جهدًا.',
    s_grippe: 'أنفك يسيل وأفكارك مشوشة.',
    s_coup_de_chaleur: 'رأسك يدور والعرق يتصبب منك.',
    o_intoxication: 'بشرة مخضرّة، يد على البطن، يتوارى كثيرًا.',
    o_gueule_de_bois: 'هالات تحت العينين، يغمض عينيه لأدنى ضوء.',
    o_grippe: 'يسعل ويتنشق، أنف أحمر.',
    o_coup_de_chaleur: 'وجه قرمزي، غارق في العرق، مترنّح قليلًا.',
    m_antinauseeux: 'مضاد للغثيان', m_aspirine: 'أسبرين', m_antigrippal: 'دواء الإنفلونزا', m_sels_rehydratation: 'أملاح الإماهة',
    health: 'الحالة الصحية', treated: 'تم أخذ العلاج', paCap: 'نقاط العمل بحد أقصى {n}', noWeapon: 'فقدان مكافأة السلاح',
    sick: 'أنت مريض', cured: 'لقد شُفيت: {noms}.', symptoms: 'الأعراض: {s}',
    pharmacy: 'صيدلية', pharmacyIntro: 'الدواء المناسب يشفيك عند النوم التالي.',
    left: 'المتبقي {n}', outOfStock: 'نفد', buy: 'شراء', cancel: 'تراجع', quantity: 'الكمية',
    bought: '{qte} × {med} مقابل {paye} {cur}.', take: 'تناول', taken: 'تم تناول الدواء: الشفاء عند النوم التالي.',
    drink: 'اشرب', drunk: 'شربت: {nom}.',
    spoiled: 'فسد بعض طعامك: {liste}.', a_viande: 'لحم', a_viande_renne: 'لحم الرنة', a_laitages: 'ألبان', a_poisson: 'سمك', a_fruits_legumes: 'فواكه وخضروات', a_oeufs: 'بيض',
    strips: 'شرائط كاشفة', stripsDeposit: 'اتركها في هذا المتجر', stripsDeposited: 'تُركت {n} شريطة: مخزون المتجر {reserve}.', foodRefused: 'فحص عند الاستلام: رُفضت {n} وحدة فاسدة وأُتلفت ولم يُدفع ثمنها.', r_pas_dans_un_commerce: 'يجب أن تكون داخل متجر.', r_pas_de_bandelettes: 'ليست لديك شرائط كاشفة.',
    r_aucune_maladie_a_traiter: 'هذا الدواء لا يعالج أيًّا من أمراضك.',
    r_deja_traitee: 'تم أخذ العلاج بالفعل: الشفاء عند النوم التالي.',
    r_rupture: 'نفد المخزون لهذا اليوم.', r_stock_insuffisant: 'المخزون غير كافٍ: المتبقي {restant}.',
    r_fonds_insuffisants: 'أموال غير كافية.', r_inventaire_plein: 'المخزون ممتلئ.',
    r_pas_a_la_pharmacie: 'يجب أن تكون عند منضدة الصيدلية.', r_pas_de_medicament: 'ليس لديك هذا الدواء.',
    r_quantite_invalide: 'كمية غير صالحة (من 1 إلى 10).', refused: 'رفض الخادم العملية.'
  },
  'pt-BR': {
    n_intoxication: 'Intoxicação alimentar', n_gueule_de_bois: 'Ressaca', n_grippe: 'Gripe', n_coup_de_chaleur: 'Insolação',
    s_intoxication: 'Você vomita a cada 10 minutos, o que tira seu charme.',
    s_gueule_de_bois: 'A luz agride e cada pensamento custa.',
    s_grippe: 'Seu nariz escorre e suas ideias estão enevoadas.',
    s_coup_de_chaleur: 'Sua cabeça gira e você sua em bicas.',
    o_intoxication: 'Pele esverdeada, uma mão na barriga, some com frequência.',
    o_gueule_de_bois: 'Olheiras, aperta os olhos à menor luz.',
    o_grippe: 'Tosse, funga, nariz vermelho.',
    o_coup_de_chaleur: 'Rosto escarlate, encharcado de suor, um pouco cambaleante.',
    m_antinauseeux: 'Antiemético', m_aspirine: 'Aspirina', m_antigrippal: 'Antigripal', m_sels_rehydratation: 'Sais de reidratação',
    health: 'Estado de saúde', treated: 'tratamento tomado', paCap: 'PA limitados a {n}', noWeapon: 'bônus de arma perdido',
    sick: 'Você está doente', cured: 'Você se curou: {noms}.', symptoms: 'Sintomas: {s}',
    pharmacy: 'Farmácia', pharmacyIntro: 'O remédio certo cura no próximo Dormir.',
    left: 'restam {n}', outOfStock: 'esgotado', buy: 'Comprar', cancel: 'Desistir', quantity: 'Quantidade',
    bought: '{qte} × {med} por {paye} {cur}.', take: 'Tomar', taken: 'Remédio tomado: cura no próximo Dormir.',
    drink: 'Beber', drunk: 'Você bebe: {nom}.',
    spoiled: 'Parte dos seus alimentos estragou: {liste}.', a_viande: 'carne', a_viande_renne: 'carne de rena', a_laitages: 'laticínios', a_poisson: 'peixe', a_fruits_legumes: 'frutas e legumes', a_oeufs: 'ovos',
    strips: 'Tiras reagentes', stripsDeposit: 'Deixar neste comércio', stripsDeposited: '{n} tira(s) entregue(s): estoque do comércio {reserve}.', foodRefused: 'Controle no recebimento: {n} unidade(s) estragada(s) recusada(s), destruída(s) e não paga(s).', r_pas_dans_un_commerce: 'É preciso estar em um comércio.', r_pas_de_bandelettes: 'Você não tem tiras reagentes.',
    r_aucune_maladie_a_traiter: 'Este remédio não trata nenhum dos seus males.',
    r_deja_traitee: 'Tratamento já tomado: cura no próximo Dormir.',
    r_rupture: 'Esgotado por hoje.', r_stock_insuffisant: 'Estoque insuficiente: restam {restant}.',
    r_fonds_insuffisants: 'Fundos insuficientes.', r_inventaire_plein: 'Inventário cheio.',
    r_pas_a_la_pharmacie: 'É preciso estar no balcão da farmácia.', r_pas_de_medicament: 'Você não tem este remédio.',
    r_quantite_invalide: 'Quantidade inválida (1 a 10).', refused: 'O servidor recusou a operação.'
  },
  de: {
    n_intoxication: 'Lebensmittelvergiftung', n_gueule_de_bois: 'Kater', n_grippe: 'Grippe', n_coup_de_chaleur: 'Hitzschlag',
    s_intoxication: 'Sie übergeben sich alle 10 Minuten, was Ihren Charme schmälert.',
    s_gueule_de_bois: 'Das Licht schmerzt, und jeder Gedanke fällt schwer.',
    s_grippe: 'Ihre Nase läuft, und Ihre Gedanken sind vernebelt.',
    s_coup_de_chaleur: 'Ihnen ist schwindlig, und der Schweiß rinnt in Strömen.',
    o_intoxication: 'Grünliche Gesichtsfarbe, eine Hand am Bauch, verschwindet oft.',
    o_gueule_de_bois: 'Augenringe, kneift beim kleinsten Licht die Augen zusammen.',
    o_grippe: 'Hustet, schnieft, rote Nase.',
    o_coup_de_chaleur: 'Hochrotes Gesicht, schweißgebadet, etwas wackelig.',
    m_antinauseeux: 'Mittel gegen Übelkeit', m_aspirine: 'Aspirin', m_antigrippal: 'Grippemittel', m_sels_rehydratation: 'Elektrolytsalze',
    health: 'Gesundheit', treated: 'Mittel eingenommen', paCap: 'AP auf {n} begrenzt', noWeapon: 'Waffenbonus verloren',
    sick: 'Sie sind krank', cured: 'Sie sind genesen: {noms}.', symptoms: 'Symptome: {s}',
    pharmacy: 'Apotheke', pharmacyIntro: 'Das passende Medikament heilt Sie beim nächsten Schlafen.',
    left: 'noch {n}', outOfStock: 'ausverkauft', buy: 'Kaufen', cancel: 'Verzichten', quantity: 'Menge',
    bought: '{qte} × {med} für {paye} {cur}.', take: 'Einnehmen', taken: 'Medikament eingenommen: Genesung beim nächsten Schlafen.',
    drink: 'Trinken', drunk: 'Sie trinken: {nom}.',
    spoiled: 'Einige Ihrer Lebensmittel sind verdorben: {liste}.', a_viande: 'Fleisch', a_viande_renne: 'Rentierfleisch', a_laitages: 'Milchprodukte', a_poisson: 'Fisch', a_fruits_legumes: 'Obst und Gemüse', a_oeufs: 'Eier',
    strips: 'Teststreifen', stripsDeposit: 'In diesem Geschäft lassen', stripsDeposited: '{n} Teststreifen abgegeben: Vorrat des Geschäfts {reserve}.', foodRefused: 'Wareneingangskontrolle: {n} verdorbene Einheit(en) abgelehnt, vernichtet und nicht bezahlt.', r_pas_dans_un_commerce: 'Sie müssen sich in einem Geschäft befinden.', r_pas_de_bandelettes: 'Sie haben keine Teststreifen.',
    r_aucune_maladie_a_traiter: 'Dieses Medikament hilft gegen keines Ihrer Leiden.',
    r_deja_traitee: 'Bereits eingenommen: Genesung beim nächsten Schlafen.',
    r_rupture: 'Für heute ausverkauft.', r_stock_insuffisant: 'Nicht genug Vorrat: noch {restant}.',
    r_fonds_insuffisants: 'Nicht genug Geld.', r_inventaire_plein: 'Inventar voll.',
    r_pas_a_la_pharmacie: 'Sie müssen am Apothekentresen sein.', r_pas_de_medicament: 'Sie haben dieses Medikament nicht.',
    r_quantite_invalide: 'Ungültige Menge (1 bis 10).', refused: 'Der Server hat den Vorgang abgelehnt.'
  }
};
const CLES = ['intoxication', 'gueule_de_bois', 'grippe', 'coup_de_chaleur'];
const MEDICAMENTS = ['antinauseeux', 'aspirine', 'antigrippal', 'sels_rehydratation'];

function langue() {
  const l = (global.RPPlateauI18n && typeof global.RPPlateauI18n.language === 'function' && global.RPPlateauI18n.language())
    || (global.i18next && global.i18next.language) || 'fr';
  return T[l] ? l : (T[String(l).split('-')[0]] ? String(l).split('-')[0] : 'fr');
}
function texteMaladie(cle, vars) {
  const s = (T[langue()] && T[langue()][cle]) || T.fr[cle] || cle;
  return String(s).replace(/\{(\w+)\}/g, (m, k) => (vars && Object.prototype.hasOwnProperty.call(vars, k)) ? String(vars[k]) : m);
}
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
// Nom et symptômes : le texte libre du MJ prime ; sinon le catalogue (clé inconnue = clé brute, jamais d'erreur).
const nomMaladie = m => (m && m.nom_mj) || (CLES.includes(m && m.cle) ? texteMaladie('n_' + m.cle) : String((m && m.cle) || ''));
const symptomeSoi = m => (m && m.symptome_mj) || (CLES.includes(m && m.cle) ? texteMaladie('s_' + m.cle) : '');
const symptomeAutre = s => (s && s.symptome_mj) || (CLES.includes(s && s.symptome) ? texteMaladie('o_' + s.symptome) : '');
const nomMedicament = k => MEDICAMENTS.includes(k) ? texteMaladie('m_' + k) : String(k || '');
const motif = v => {
  const r = v && v.raison;
  return (r && T.fr['r_' + r]) ? texteMaladie('r_' + r, v) : texteMaladie('refused');
};
const devise = () => (global.COUNTRIES && typeof state !== 'undefined' && state && global.COUNTRIES[state.country]?.cur) || '';
const uuid = () => (global.crypto && typeof global.crypto.randomUUID === 'function') ? global.crypto.randomUUID()
  : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => Math.floor(Math.random() * 16).toString(16));
const un = r => Array.isArray(r) ? r[0] : r;
const appliquerInventaire = r => {
  if (r && Array.isArray(r.inventory) && typeof state !== 'undefined' && state) {
    state.inventory = r.inventory;
    if (r.revision != null) state.inventoryRevision = r.revision;
  }
  if (r && typeof r.liquide === 'number' && typeof state !== 'undefined' && state) state.liquide = r.liquide;
};

// ── État de santé du joueur ─────────────────────────────────────────────────────────────────────
let mesMaladies = [];
let connues = null;   // clés connues au dernier rafraîchissement (détecte les guérisons)
function rendreEtatSante() {
  const grille = global.document && global.document.getElementById('stat-mini-grid');
  if (!grille || !grille.parentNode) return;
  let el = global.document.getElementById('etat-sante');
  if (!el) {
    el = global.document.createElement('div');
    el.id = 'etat-sante';
    el.style.cssText = 'font-size:.72rem;color:#c8604a;margin-top:.35rem;line-height:1.35';
    grille.parentNode.insertBefore(el, grille.nextSibling);
  }
  if (!mesMaladies.length) { el.innerHTML = ''; el.style.display = 'none'; return; }
  el.style.display = '';
  el.innerHTML = '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.08em;color:#d08a6a">' + esc(texteMaladie('health')) + '</div>'
    + mesMaladies.map(m => {
      const extras = [];
      if (m.pa_max != null && m.pa_max < 30) extras.push(texteMaladie('paCap', { n: m.pa_max }));
      if (m.sans_bonus_arme) extras.push(texteMaladie('noWeapon'));
      if (m.traitee) extras.push(texteMaladie('treated'));
      return '<div>• <strong>' + esc(nomMaladie(m)) + '</strong> — ' + esc(symptomeSoi(m))
        + (extras.length ? ' <span style="color:#9a7a50">(' + esc(extras.join(', ')) + ')</span>' : '') + '</div>';
    }).join('');
}
async function rafraichirMaladies() {
  if (typeof global.sbRpc !== 'function') return null;
  const r = un(await global.sbRpc('maladies_mes_maladies', {}).catch(() => null));
  if (!r || r.ok !== true) return null;
  const liste = Array.isArray(r.maladies) ? r.maladies : [];
  if (Array.isArray(r.effets_actifs) && typeof state !== 'undefined' && state) state.effetsActifs = r.effets_actifs;
  for (const m of liste) {
    if (m.nouvelle) global.showToast && global.showToast(texteMaladie('sick'), nomMaladie(m) + ' — ' + symptomeSoi(m), false);
  }
  const cles = new Set(liste.map(m => m.cle));
  if (connues) {
    const gueries = mesMaladies.filter(m => !cles.has(m.cle));
    if (gueries.length && global.showToast) global.showToast(texteMaladie('health'), texteMaladie('cured', { noms: gueries.map(nomMaladie).join(', ') }), true);
  }
  connues = cles;
  mesMaladies = liste;
  // Aliments gâtés (lot 2a) : seul le propriétaire est prévenu, une fois ; aucune marque sur l'objet.
  const g = un(await global.sbRpc('aliments_annonces_lire', {}).catch(() => null));
  if (g && g.ok === true && Array.isArray(g.gates) && g.gates.length && global.showToast) {
    global.showToast(texteMaladie('health'), texteMaladie('spoiled', { liste: g.gates.map(c => texteMaladie('a_' + c)).join(', ') }), false);
  }
  rendreEtatSante();
  if (typeof global.updateUI === 'function') { try { global.updateUI(); } catch (_) {} rendreEtatSante(); }
  return liste;
}

// ── Pharmacie ───────────────────────────────────────────────────────────────────────────────────
async function ouvrirPharmacie() {
  const e = un(await global.sbRpc('pharmacie_etat', {}).catch(() => null));
  if (!e || e.ok !== true) { global.showToast(texteMaladie('pharmacy'), motif(e), false); return; }
  const cur = devise();
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texteMaladie('pharmacy');
  let html = '<div class="cpj-dialogue" style="padding:1rem">';
  html += '<div class="cpj-note" style="margin-bottom:.8rem">' + esc(texteMaladie('pharmacyIntro')) + '</div>';
  html += '<select id="pharmacie-medicament" class="cpj-champ" style="width:100%;margin-bottom:.6rem">';
  for (const m of (e.medicaments || [])) {
    const dispo = m.restant > 0 ? texteMaladie('left', { n: m.restant }) : texteMaladie('outOfStock');
    html += '<option value="' + esc(m.medicament) + '"' + (m.restant > 0 ? '' : ' disabled') + '>'
      + esc(nomMedicament(m.medicament)) + ' (' + esc(nomMaladie({ cle: m.maladie, nom_mj: m.nom_mj })) + ') — '
      + esc(m.prix) + ' ' + esc(cur) + ' — ' + esc(dispo) + '</option>';
  }
  if (e.prix_bandelette != null) html += '<option value="__bandelettes__">' + esc(texteMaladie('strips')) + ' — ' + esc(e.prix_bandelette) + ' ' + esc(cur) + '</option>';
  html += '</select>';
  html += '<label class="cpj-note" for="pharmacie-qte">' + esc(texteMaladie('quantity')) + '</label>';
  html += '<input id="pharmacie-qte" class="cpj-champ" type="number" min="1" max="10" step="1" value="1" style="width:100%;margin-bottom:.8rem">';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button class="cpj-touche cpj-primaire" style="flex:1" onclick="confirmerPharmacie()">' + esc(texteMaladie('buy')) + '</button>';
  html += '<button class="cpj-touche" style="flex:1" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texteMaladie('cancel')) + '</button>';
  html += '</div></div>';
  global.document.getElementById('postes-body').innerHTML = html;
  global.document.getElementById('modal-postes').classList.add('open');
}
let achatEnCours = false;
async function confirmerPharmacie() {
  if (achatEnCours) return;
  const med = global.document.getElementById('pharmacie-medicament')?.value;
  const qte = Number(global.document.getElementById('pharmacie-qte')?.value);
  if (!med) return;
  if (!Number.isSafeInteger(qte) || qte < 1 || qte > 10) { global.showToast(texteMaladie('pharmacy'), texteMaladie('r_quantite_invalide'), false); return; }
  achatEnCours = true;
  try {
    const bandelettes = med === '__bandelettes__';
    const r = un(await global.sbRpc(bandelettes ? 'pharmacie_bandelettes_acheter' : 'pharmacie_acheter',
      bandelettes ? { p_requete: uuid(), p_qte: qte } : { p_requete: uuid(), p_medicament: med, p_qte: qte }).catch(() => null));
    if (!r || r.ok !== true) { global.showToast(texteMaladie('pharmacy'), motif(r), false); return; }
    appliquerInventaire(r);
    global.document.getElementById('modal-postes')?.classList.remove('open');
    global.showToast(texteMaladie('pharmacy'), texteMaladie('bought', { qte: r.quantite, med: bandelettes ? texteMaladie('strips') : nomMedicament(r.medicament), paye: r.paye, cur: devise() }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { achatEnCours = false; }
}
async function prendreMedicament(medicament) {
  const r = un(await global.sbRpc('medicament_prendre', { p_requete: uuid(), p_medicament: medicament }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(nomMedicament(medicament), motif(r), false); return; }
  appliquerInventaire(r);
  global.document.getElementById('modal-postes')?.classList.remove('open');
  global.showToast(nomMedicament(medicament), texteMaladie('taken'), true);
  await rafraichirMaladies();
  if (typeof global.switchSelfTab === 'function') { try { global.switchSelfTab('inventaire', null); } catch (_) {} }
}
// Bouton du détail d'un objet (plateau-personnage.js) pour un médicament de maladie.
function boutonMedicamentMaladie(item, style) {
  if (!item || item.type !== 'medicament_maladie' || !item.medicament) return '';
  return '<button onclick="prendreMedicament(\'' + esc(item.medicament).replace(/'/g, '') + '\')" style="' + (style || '') + '">'
    + esc(texteMaladie('take')) + '</button>';
}
// Boissons (décision de Fred, 18/11/2026) : une boisson étiquetée (alcoolisée ou non) se boit depuis l'inventaire. L'étiquette
// est tranchée par le serveur (recette ou objet) ; l'écran ne propose le bouton qu'aux objets qui peuvent en porter une.
function estBoisson(item) {
  if (!item) return false;
  if (item.boisson === 'alcoolisee' || item.boisson === 'non_alcoolisee') return true;
  return !!item.recette_id && (item.generique_id === 'boisson' || item.generique_id === 'alcool-de-distillerie');
}
function boutonBoire(item, idx, style) {
  if (!estBoisson(item) || !Number.isInteger(idx)) return '';
  return '<button onclick="boireBoisson(' + idx + ')" style="' + (style || '') + '"><i class="ti ti-glass-full"></i> ' + esc(texteMaladie('drink')) + '</button>';
}
let boireEnCours = false;
async function boireBoisson(idx) {
  if (boireEnCours || typeof global.removeFromInventory !== 'function') return;
  const item = ((typeof state !== 'undefined' && state && state.inventory) || [])[idx]; // state : « let » de plateau-core.js, hors de window
  if (!estBoisson(item)) return;
  boireEnCours = true;
  try {
    global.document.getElementById('modal-postes')?.classList.remove('open');
    const r = await global.removeFromInventory(idx, 'consommer');
    if (!r || !r.ok) {
      const msg = typeof global.messageRefusSortieInventaire === 'function' ? global.messageRefusSortieInventaire(r && r.raison) : texteMaladie('refused');
      global.showToast(texteMaladie('drink'), msg, false); return;
    }
    global.showToast(texteMaladie('drink'), texteMaladie('drunk', { nom: item.name || '' }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
    setTimeout(() => { rafraichirMaladies().catch(() => {}); }, 400);
  } finally { boireEnCours = false; }
}
// Nom affiché d'un médicament de maladie dans l'inventaire.
function nomObjetMaladie(item) {
  if (item && item.type === 'bandelette_reactive') return texteMaladie('strips');
  return item && item.type === 'medicament_maladie' ? nomMedicament(item.medicament) : null;
}
// Bandelettes réactives (lot 2b) : déposées dans le commerce de la pièce (un don ; le serveur trouve le commerce).
function boutonBandelettes(item, style) {
  if (!item || item.type !== 'bandelette_reactive') return '';
  return '<button onclick="deposerBandelettes(' + Math.max(1, Math.floor(Number(item.qty) || 1)) + ')" style="' + (style || '') + '"><i class="ti ti-test-pipe"></i> '
    + esc(texteMaladie('stripsDeposit')) + '</button>';
}
let depotEnCours = false;
async function deposerBandelettes(qte) {
  if (depotEnCours) return;
  depotEnCours = true;
  try {
    const r = un(await global.sbRpc('commerce_bandelettes_deposer', { p_requete: uuid(), p_qte: qte }).catch(() => null));
    if (!r || r.ok !== true) { global.showToast(texteMaladie('strips'), motif(r), false); return; }
    appliquerInventaire(r);
    global.document.getElementById('modal-postes')?.classList.remove('open');
    global.showToast(texteMaladie('strips'), texteMaladie('stripsDeposited', { n: r.quantite, reserve: r.reserve }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { depotEnCours = false; }
}

// ── Symptômes des personnes présentes ───────────────────────────────────────────────────────────
let cacheSymptomes = { t: 0, v: {} };
async function symptomesDe(nom) {
  if (!nom || typeof global.sbRpc !== 'function') return [];
  if (Date.now() - cacheSymptomes.t > 20000) {
    const r = un(await global.sbRpc('maladies_symptomes_piece', {}).catch(() => null));
    cacheSymptomes = { t: Date.now(), v: (r && r.ok === true && r.symptomes) || {} };
  }
  return (cacheSymptomes.v[nom] || []).map(symptomeAutre).filter(Boolean);
}
async function afficherSymptomesDans(conteneurApres, nom) {
  if (!conteneurApres || !conteneurApres.parentNode) return;
  let el = global.document.getElementById('pnj-symptomes');
  if (!el) {
    el = global.document.createElement('div');
    el.id = 'pnj-symptomes';
    el.style.cssText = 'font-size:.72rem;color:#c8604a;margin-top:.2rem;font-style:italic';
    conteneurApres.parentNode.insertBefore(el, conteneurApres.nextSibling);
  }
  el.textContent = '';
  const s = await symptomesDe(nom);
  el.textContent = s.length ? texteMaladie('symptoms', { s: s.join(' ') }) : '';
}

// Après les actions qui peuvent rendre malade ou guérir (manger cru, boire, Dormir), relire l'état de santé.
const RPC_SANTE = new Set(['matiere_brute_manger', 'sovarka_maison_agir', 'tournee_cloturer_boire', 'pa_repos_nocturne', 'inventaire_consommer',
  'consommer_sur_place_commerce', 'service_etage_commander', 'restaurant_diner_servir']);
function brancherSbRpc() {
  const orig = global.sbRpc;
  if (typeof orig !== 'function' || orig.__maladies) return;
  const enveloppe = async function (fn) {
    const r = await orig.apply(this, arguments);
    if (RPC_SANTE.has(fn)) setTimeout(() => { rafraichirMaladies().catch(() => {}); }, 400);
    return r;
  };
  enveloppe.__maladies = true;
  global.sbRpc = enveloppe;
  // Ventes et dons d'aliments à un commerce (lot 2b) : annoncer les unités refusées au contrôle.
  const origV = global.sbRpcVerdict;
  if (typeof origV === 'function' && !origV.__maladies) {
    const enveloppeV = async function (fn) {
      const r = await origV.apply(this, arguments);
      if ((fn === 'commerce_apporter_matiere' || fn === 'fonds_matiere_apporter') && r && Number(r.refuses) > 0 && global.showToast) {
        global.showToast(texteMaladie('health'), texteMaladie('foodRefused', { n: Number(r.refuses) }), false);
      }
      return r;
    };
    enveloppeV.__maladies = true;
    global.sbRpcVerdict = enveloppeV;
  }
}
function demarrer() {
  if (typeof global.sbRpc !== 'function') return;
  brancherSbRpc();
  setTimeout(rafraichirMaladies, 4000);
  setInterval(rafraichirMaladies, 180000);
}
if (global.document && global.document.readyState !== 'loading') demarrer();
else if (global.document) global.document.addEventListener('DOMContentLoaded', demarrer);

Object.assign(global, {
  RPMaladies: { T, CLES, MEDICAMENTS, texte: texteMaladie, nomMaladie, symptomeSoi, symptomeAutre, nomMedicament, motif },
  rafraichirMaladies, rendreEtatSante, ouvrirPharmacie, confirmerPharmacie, prendreMedicament,
  boutonMedicamentMaladie, nomObjetMaladie, afficherSymptomesDans, boutonBoire, boireBoisson, estBoisson, boutonBandelettes, deposerBandelettes
});
})(typeof window !== 'undefined' ? window : globalThis);
