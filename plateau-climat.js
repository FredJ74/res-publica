// Événements climatiques — lot 3 (GAME-DESIGN-MALADIES-CLIMAT.md §§ 4 et 11, décisions de Fred du 18/11/2026).
// Le serveur tranche tout (calendrier, alertes 48 h avant, événement en cours) : climat_etat() ne renvoie que les alertes
// publiées du pays du joueur. L'écran affiche une fenêtre « Message du gouvernement » une fois par alerte et par personnage,
// et un filtre animé sur la vue de rue de la ville touchée pendant l'événement (aucune nouvelle image).
(function (global) {
'use strict';
const T = {
  fr: { gov: 'Message du gouvernement', ok: 'Compris', at: 'à {ville}, le {date}',
    crue: 'Alerte crue {lieu} : {lieux} seront sous les eaux pendant 12 heures. Mettez vos biens à l’abri.',
    canicule: 'Alerte canicule {lieu} : buvez, restez à l’ombre, ne gardez pas de nourriture sur vous.',
    orage: 'Alerte orage {lieu} : coupures d’électricité et d’internet attendues pendant 12 heures.',
    brouillard: 'Brouillard épais attendu {lieu}. Prudence sur la voie publique.',
    blizzard: 'Alerte blizzard {lieu} : restez chez vous et munissez-vous de graisse.',
    building: 'Chantier à l’arrêt : intempéries en cours dans la ville.',
    fats: 'Graisses', g_graisse_castor: 'Bocal de graisse de castor', g_graisse_ours: 'Bocal de graisse d’ours', g_kolkhoze_graisse_renne: 'Bocal de graisse de renne', buy: 'Acheter', cancel: 'Renoncer', quantity: 'Quantité', bought: '{qte} bocal(aux) pour {paye} {cur}.', deposit: 'Déposer dans ma pharmacie', deposited: '{n} bocal(aux) déposé(s) : stock de la pharmacie {stock}.', blizzardLost: 'Le blizzard vous a coûté {n} PA.', blizzardFat: 'Votre bocal de graisse vous a protégé du froid.', left: 'reste {n}', r_pas_de_graisse_ici: 'Pas de graisse en vente ici.', r_pas_ma_pharmacie: 'Ce n’est pas votre pharmacie.', r_pas_de_graisse: 'Vous n’avez pas ce bocal.', r_stock_insuffisant: 'Stock insuffisant : il en reste {restant}.', r_fonds_insuffisants: 'Fonds insuffisants.', r_inventaire_plein: 'Inventaire plein.', r_quantite_invalide: 'Quantité invalide (1 à 10).', refused: 'Le serveur a refusé l’opération.',
    shop: 'Équipements contre les intempéries', o_bouteille_eau: 'Bouteille d’eau', o_sac_de_sable: 'Sac de sable', o_groupe_electrogene: 'Groupe électrogène', shopBought: '{qte} × {nom} pour {paye} {cur}.', pose: 'Poser un sac de sable devant ce bâtiment (1 PA)', posed: 'Sac de sable posé : à la prochaine crue, ce lieu restera ouvert et gardera tous ses stocks.', fill: 'Remplir (bidons)', filled: 'Réservoir : {n} bidon(s).', heatLost: 'La canicule vous a coûté {n} PA.', heatWater: 'Votre bouteille d’eau vous a protégé de la chaleur.', spoiledHeat: 'La chaleur a gâté la nourriture que vous portiez ({n}).', flooded: 'Ce bâtiment est sous les eaux.', cat: 'État de catastrophe naturelle', catPropose: 'Proposer au Premier ministre', catProposed: 'Proposition envoyée au Premier ministre.', catIntro: 'Pertes de la crue à {ville} : {pertes} {cur}. Indemnisation à {part} % sur la caisse du gouvernement.', catSacs: 'Seuls les sinistrés qui avaient posé des sacs de sable : {n} sinistré(s), coût {cout} {cur}.', catTous: 'Tous les sinistrés : {n} sinistré(s), coût {cout} {cur}.', catReserve: 'Caisse du gouvernement : {reserve} {cur}.', catDeadline: 'Décision possible jusqu’au {date}.', catDeclared: 'Déclarer', catDone: 'État de catastrophe naturelle déclaré : {cout} {cur} versés.', r_pas_a_la_boutique: 'Il faut être dans la boutique.', r_hors_zone_inondable: 'Ce bâtiment n’est pas en zone inondable.', r_pas_proprietaire_ni_exploitant: 'Seul le propriétaire ou l’exploitant peut poser des sacs.', r_deja_protege: 'Ce bâtiment est déjà protégé pour la prochaine crue.', r_pas_de_sacs: 'Vous n’avez pas de sacs de sable.', r_pas_de_groupe: 'Pas de groupe électrogène installé ici.', r_bidons_insuffisants: 'Pas assez de bidons de carburant.', r_poste_requis: 'Réservé au ministre de l’Intérieur ou au Premier ministre.', r_delai_depasse: 'Le délai de 72 heures est dépassé.', r_deja_propose: 'Déjà proposé.', r_pas_de_proposition: 'Le ministre de l’Intérieur n’a rien proposé.', r_deja_declare: 'Déjà déclaré.', r_budget_insuffisant: 'La caisse du gouvernement ne suffit pas.', r_crue_inconnue: 'Crue inconnue.', r_pa_insuffisants: 'Pas assez de PA.' },
  en: { gov: 'Government message', ok: 'Understood', at: 'in {ville} on {date}',
    crue: 'Flood warning {lieu}: {lieux} will be under water for 24 hours. Move your belongings to safety.',
    canicule: 'Heatwave warning {lieu}: drink water, stay in the shade, do not carry food on you.',
    orage: 'Storm warning {lieu}: power and internet cuts expected for 24 hours.',
    brouillard: 'Thick fog expected {lieu}. Take care on the streets.',
    blizzard: 'Blizzard warning {lieu}: stay indoors and get some fat.',
    building: 'Building site halted: severe weather in the city.',
    fats: 'Fat', g_graisse_castor: 'Jar of beaver fat', g_graisse_ours: 'Jar of bear fat', g_kolkhoze_graisse_renne: 'Jar of reindeer fat', buy: 'Buy', cancel: 'Cancel', quantity: 'Quantity', bought: '{qte} jar(s) for {paye} {cur}.', deposit: 'Leave in my pharmacy', deposited: '{n} jar(s) left: the pharmacy now holds {stock}.', blizzardLost: 'The blizzard cost you {n} AP.', blizzardFat: 'Your jar of fat protected you from the cold.', left: '{n} left', r_pas_de_graisse_ici: 'No fat on sale here.', r_pas_ma_pharmacie: 'This is not your pharmacy.', r_pas_de_graisse: 'You do not have this jar.', r_stock_insuffisant: 'Not enough stock: {restant} left.', r_fonds_insuffisants: 'Insufficient funds.', r_inventaire_plein: 'Inventory full.', r_quantite_invalide: 'Invalid quantity (1 to 10).', refused: 'The server refused the operation.',
    shop: 'Severe weather equipment', o_bouteille_eau: 'Bottle of water', o_sac_de_sable: 'Sandbag', o_groupe_electrogene: 'Generator', shopBought: '{qte} × {nom} for {paye} {cur}.', pose: 'Lay your sandbags in front of this building (1 AP)', posed: '{n} sandbag(s) laid. In front of this building: {total}/{max} bags; loss at the next flood: {perte}% of stock.', fill: 'Refill (jerrycans)', filled: 'Tank: {n} jerrycan(s).', heatLost: 'The heatwave cost you {n} AP.', heatWater: 'Your bottle of water protected you from the heat.', spoiledHeat: 'The heat spoiled the food you were carrying ({n}).', flooded: 'This building is under water.', cat: 'State of natural disaster', catPropose: 'Propose to the Prime Minister', catProposed: 'Proposal sent to the Prime Minister.', catIntro: 'Flood losses in {ville}: {pertes} {cur}. Compensation at {part}% from the government fund.', catSacs: 'Only victims who had laid sandbags: {n} victim(s), cost {cout} {cur}.', catTous: 'All victims: {n} victim(s), cost {cout} {cur}.', catReserve: 'Government fund: {reserve} {cur}.', catDeadline: 'Decision possible until {date}.', catDeclared: 'Declare', catDone: 'State of natural disaster declared: {cout} {cur} paid out.', r_pas_a_la_boutique: 'You must be in the shop.', r_hors_zone_inondable: 'This building is not in a flood zone.', r_pas_proprietaire_ni_exploitant: 'Only the owner or the operator can lay sandbags.', r_deja_protege: 'This building already has the maximum number of sandbags.', r_pas_de_sacs: 'You have no sandbags.', r_pas_de_groupe: 'No generator installed here.', r_bidons_insuffisants: 'Not enough jerrycans of fuel.', r_poste_requis: 'Reserved for the Interior Minister or the Prime Minister.', r_delai_depasse: 'The 72-hour deadline has passed.', r_deja_propose: 'Already proposed.', r_pas_de_proposition: 'The Interior Minister has proposed nothing.', r_deja_declare: 'Already declared.', r_budget_insuffisant: 'The government fund is not enough.', r_crue_inconnue: 'Unknown flood.', r_pa_insuffisants: 'Not enough AP.' },
  es: { gov: 'Mensaje del gobierno', ok: 'Entendido', at: 'en {ville}, el {date}',
    crue: 'Alerta de inundación {lieu}: {lieux} quedarán bajo el agua durante 24 horas. Ponga sus bienes a salvo.',
    canicule: 'Alerta de ola de calor {lieu}: beba, quédese a la sombra, no lleve comida encima.',
    orage: 'Alerta de tormenta {lieu}: se esperan cortes de electricidad y de internet durante 24 horas.',
    brouillard: 'Se espera niebla espesa {lieu}. Precaución en la vía pública.',
    blizzard: 'Alerta de ventisca {lieu}: quédese en casa y consiga grasa.',
    building: 'Obra parada: mal tiempo en la ciudad.',
    fats: 'Grasas', g_graisse_castor: 'Tarro de grasa de castor', g_graisse_ours: 'Tarro de grasa de oso', g_kolkhoze_graisse_renne: 'Tarro de grasa de reno', buy: 'Comprar', cancel: 'Renunciar', quantity: 'Cantidad', bought: '{qte} tarro(s) por {paye} {cur}.', deposit: 'Dejar en mi farmacia', deposited: '{n} tarro(s) entregado(s): existencias de la farmacia {stock}.', blizzardLost: 'La ventisca le ha costado {n} PA.', blizzardFat: 'Su tarro de grasa le protegió del frío.', left: 'quedan {n}', r_pas_de_graisse_ici: 'Aquí no se vende grasa.', r_pas_ma_pharmacie: 'Esta no es su farmacia.', r_pas_de_graisse: 'No tiene este tarro.', r_stock_insuffisant: 'Existencias insuficientes: quedan {restant}.', r_fonds_insuffisants: 'Fondos insuficientes.', r_inventaire_plein: 'Inventario lleno.', r_quantite_invalide: 'Cantidad no válida (1 a 10).', refused: 'El servidor rechazó la operación.',
    shop: 'Equipos contra el mal tiempo', o_bouteille_eau: 'Botella de agua', o_sac_de_sable: 'Saco de arena', o_groupe_electrogene: 'Grupo electrógeno', shopBought: '{qte} × {nom} por {paye} {cur}.', pose: 'Colocar sus sacos delante de este edificio (1 PA)', posed: '{n} saco(s) colocado(s). Delante de este edificio: {total}/{max} sacos; pérdida en la próxima inundación: {perte} % de las existencias.', fill: 'Rellenar (bidones)', filled: 'Depósito: {n} bidón(es).', heatLost: 'La ola de calor le ha costado {n} PA.', heatWater: 'Su botella de agua le protegió del calor.', spoiledHeat: 'El calor estropeó la comida que llevaba ({n}).', flooded: 'Este edificio está bajo el agua.', cat: 'Estado de catástrofe natural', catPropose: 'Proponer al primer ministro', catProposed: 'Propuesta enviada al primer ministro.', catIntro: 'Pérdidas de la inundación en {ville}: {pertes} {cur}. Indemnización del {part} % con cargo a la caja del gobierno.', catSacs: 'Solo los damnificados que habían colocado sacos de arena: {n} damnificado(s), coste {cout} {cur}.', catTous: 'Todos los damnificados: {n} damnificado(s), coste {cout} {cur}.', catReserve: 'Caja del gobierno: {reserve} {cur}.', catDeadline: 'Decisión posible hasta el {date}.', catDeclared: 'Declarar', catDone: 'Estado de catástrofe natural declarado: {cout} {cur} abonados.', r_pas_a_la_boutique: 'Debe estar en la tienda.', r_hors_zone_inondable: 'Este edificio no está en zona inundable.', r_pas_proprietaire_ni_exploitant: 'Solo el propietario o el explotador puede colocar sacos.', r_deja_protege: 'Este edificio ya tiene el máximo de sacos de arena.', r_pas_de_sacs: 'No tiene sacos de arena.', r_pas_de_groupe: 'No hay grupo electrógeno instalado aquí.', r_bidons_insuffisants: 'No hay suficientes bidones de combustible.', r_poste_requis: 'Reservado al ministro del Interior o al primer ministro.', r_delai_depasse: 'Se ha superado el plazo de 72 horas.', r_deja_propose: 'Ya propuesto.', r_pas_de_proposition: 'El ministro del Interior no ha propuesto nada.', r_deja_declare: 'Ya declarado.', r_budget_insuffisant: 'La caja del gobierno no alcanza.', r_crue_inconnue: 'Inundación desconocida.', r_pa_insuffisants: 'No hay suficientes PA.' },
  'zh-TW': { gov: '政府訊息', ok: '知道了', at: '{date}於{ville}',
    crue: '洪水警報（{lieu}）：{lieux}將被淹沒 24 小時。請把財物移到安全處。',
    canicule: '熱浪警報（{lieu}）：多喝水，待在陰涼處，別把食物帶在身上。',
    orage: '暴風雨警報（{lieu}）：預計停電並中斷網路 24 小時。',
    brouillard: '預計有濃霧（{lieu}）。上街請小心。',
    blizzard: '暴風雪警報（{lieu}）：請待在室內，備好油脂。',
    building: '工地停工：城裡正值惡劣天氣。',
    fats: '油脂', g_graisse_castor: '一罐河狸油脂', g_graisse_ours: '一罐熊油脂', g_kolkhoze_graisse_renne: '一罐馴鹿油脂', buy: '購買', cancel: '放棄', quantity: '數量', bought: '{qte} 罐，共 {paye} {cur}。', deposit: '放到我的藥房', deposited: '已放下 {n} 罐：藥房存量 {stock}。', blizzardLost: '暴風雪讓你損失了 {n} 行動點。', blizzardFat: '你的油脂罐幫你抵禦了寒冷。', left: '剩 {n}', r_pas_de_graisse_ici: '這裡不賣油脂。', r_pas_ma_pharmacie: '這不是你的藥房。', r_pas_de_graisse: '你沒有這種罐子。', r_stock_insuffisant: '庫存不足：只剩 {restant}。', r_fonds_insuffisants: '資金不足。', r_inventaire_plein: '背包已滿。', r_quantite_invalide: '數量無效（1 至 10）。', refused: '伺服器拒絕了此操作。',
    shop: '防災裝備', o_bouteille_eau: '一瓶水', o_sac_de_sable: '沙包', o_groupe_electrogene: '發電機', shopBought: '{qte} × {nom}，共 {paye} {cur}。', pose: '把你的沙包放在這棟建築前（1 行動點）', posed: '放了 {n} 個沙包。這棟建築前：{total}/{max} 個；下次洪水損失：庫存的 {perte}%。', fill: '加油（油桶）', filled: '油箱：{n} 桶。', heatLost: '熱浪讓你損失了 {n} 行動點。', heatWater: '你的瓶裝水讓你免於中暑。', spoiledHeat: '高溫讓你身上的食物壞了（{n}）。', flooded: '這棟建築被水淹了。', cat: '自然災害狀態', catPropose: '向總理提議', catProposed: '已向總理送出提議。', catIntro: '{ville}的洪水損失：{pertes} {cur}。由政府金庫補償 {part}%。', catSacs: '僅限放了沙包的受災者：{n} 名，花費 {cout} {cur}。', catTous: '所有受災者：{n} 名，花費 {cout} {cur}。', catReserve: '政府金庫：{reserve} {cur}。', catDeadline: '可決定至 {date}。', catDeclared: '宣布', catDone: '已宣布自然災害狀態：已撥付 {cout} {cur}。', r_pas_a_la_boutique: '你必須在店裡。', r_hors_zone_inondable: '這棟建築不在洪水區內。', r_pas_proprietaire_ni_exploitant: '只有業主或經營者能放沙包。', r_deja_protege: '這棟建築前的沙包已達上限。', r_pas_de_sacs: '你沒有沙包。', r_pas_de_groupe: '這裡沒有安裝發電機。', r_bidons_insuffisants: '燃料桶不足。', r_poste_requis: '限內政部長或總理。', r_delai_depasse: '已超過 72 小時期限。', r_deja_propose: '已提議。', r_pas_de_proposition: '內政部長尚未提議。', r_deja_declare: '已宣布。', r_budget_insuffisant: '政府金庫不足。', r_crue_inconnue: '未知的洪水。', r_pa_insuffisants: '行動點不足。' },
  ru: { gov: 'Сообщение правительства', ok: 'Понятно', at: '— {ville}, {date}',
    crue: 'Предупреждение о наводнении {lieu}: {lieux} будут под водой 24 часа. Уберите имущество в безопасное место.',
    canicule: 'Предупреждение о жаре {lieu}: пейте воду, держитесь в тени, не носите еду с собой.',
    orage: 'Предупреждение о грозе {lieu}: ожидаются отключения электричества и интернета на 24 часа.',
    brouillard: 'Ожидается густой туман {lieu}. Будьте осторожны на улице.',
    blizzard: 'Предупреждение о буране {lieu}: оставайтесь дома и запаситесь жиром.',
    building: 'Стройка остановлена: в городе непогода.',
    fats: 'Жир', g_graisse_castor: 'Банка бобрового жира', g_graisse_ours: 'Банка медвежьего жира', g_kolkhoze_graisse_renne: 'Банка оленьего жира', buy: 'Купить', cancel: 'Отказаться', quantity: 'Количество', bought: 'Банок: {qte} за {paye} {cur}.', deposit: 'Оставить в моей аптеке', deposited: 'Оставлено банок: {n}; запас аптеки: {stock}.', blizzardLost: 'Буран стоил вам {n} ОД.', blizzardFat: 'Банка жира защитила вас от холода.', left: 'осталось {n}', r_pas_de_graisse_ici: 'Здесь жир не продаётся.', r_pas_ma_pharmacie: 'Это не ваша аптека.', r_pas_de_graisse: 'У вас нет такой банки.', r_stock_insuffisant: 'Недостаточно запасов: осталось {restant}.', r_fonds_insuffisants: 'Недостаточно средств.', r_inventaire_plein: 'Инвентарь полон.', r_quantite_invalide: 'Неверное количество (от 1 до 10).', refused: 'Сервер отклонил операцию.',
    shop: 'Снаряжение против непогоды', o_bouteille_eau: 'Бутылка воды', o_sac_de_sable: 'Мешок с песком', o_groupe_electrogene: 'Генератор', shopBought: '{qte} × {nom} за {paye} {cur}.', pose: 'Уложить свои мешки перед этим зданием (1 ОД)', posed: 'Уложено мешков: {n}. Перед зданием: {total}/{max}; потери при следующем наводнении: {perte} % запасов.', fill: 'Заправить (канистры)', filled: 'Бак: канистр — {n}.', heatLost: 'Жара стоила вам {n} ОД.', heatWater: 'Бутылка воды защитила вас от жары.', spoiledHeat: 'Жара испортила еду, которую вы несли ({n}).', flooded: 'Это здание под водой.', cat: 'Режим стихийного бедствия', catPropose: 'Предложить премьер-министру', catProposed: 'Предложение отправлено премьер-министру.', catIntro: 'Потери от наводнения в {ville}: {pertes} {cur}. Возмещение {part} % из казны правительства.', catSacs: 'Только пострадавшие, уложившие мешки с песком: {n}, стоимость {cout} {cur}.', catTous: 'Все пострадавшие: {n}, стоимость {cout} {cur}.', catReserve: 'Казна правительства: {reserve} {cur}.', catDeadline: 'Решение возможно до {date}.', catDeclared: 'Объявить', catDone: 'Режим стихийного бедствия объявлен: выплачено {cout} {cur}.', r_pas_a_la_boutique: 'Нужно находиться в магазине.', r_hors_zone_inondable: 'Здание не в зоне затопления.', r_pas_proprietaire_ni_exploitant: 'Мешки может уложить только владелец или арендатор.', r_deja_protege: 'Перед этим зданием уже максимум мешков с песком.', r_pas_de_sacs: 'У вас нет мешков с песком.', r_pas_de_groupe: 'Здесь не установлен генератор.', r_bidons_insuffisants: 'Недостаточно канистр с топливом.', r_poste_requis: 'Только для министра внутренних дел или премьер-министра.', r_delai_depasse: 'Срок в 72 часа истёк.', r_deja_propose: 'Уже предложено.', r_pas_de_proposition: 'Министр внутренних дел ничего не предложил.', r_deja_declare: 'Уже объявлено.', r_budget_insuffisant: 'В казне правительства недостаточно средств.', r_crue_inconnue: 'Неизвестное наводнение.', r_pa_insuffisants: 'Недостаточно ОД.' },
  ko: { gov: '정부 메시지', ok: '확인', at: '{date}, {ville}',
    crue: '홍수 경보({lieu}): {lieux}이(가) 24시간 동안 물에 잠깁니다. 재산을 안전한 곳으로 옮기세요.',
    canicule: '폭염 경보({lieu}): 물을 마시고 그늘에 머물며 음식을 몸에 지니지 마세요.',
    orage: '뇌우 경보({lieu}): 24시간 동안 정전과 인터넷 끊김이 예상됩니다.',
    brouillard: '짙은 안개 예상({lieu}). 거리에서 조심하세요.',
    blizzard: '눈보라 경보({lieu}): 집에 머물고 지방을 준비하세요.',
    building: '공사 중단: 시내에 악천후가 이어지고 있습니다.',
    fats: '지방', g_graisse_castor: '비버 지방 한 병', g_graisse_ours: '곰 지방 한 병', g_kolkhoze_graisse_renne: '순록 지방 한 병', buy: '구매', cancel: '취소', quantity: '수량', bought: '{qte}병, {paye} {cur}.', deposit: '내 약국에 맡기기', deposited: '{n}병을 맡겼습니다: 약국 재고 {stock}.', blizzardLost: '눈보라로 AP {n}을 잃었습니다.', blizzardFat: '지방 한 병이 추위를 막아 주었습니다.', left: '{n} 남음', r_pas_de_graisse_ici: '이곳에서는 지방을 팔지 않습니다.', r_pas_ma_pharmacie: '당신의 약국이 아닙니다.', r_pas_de_graisse: '이 병을 가지고 있지 않습니다.', r_stock_insuffisant: '재고 부족: {restant} 남았습니다.', r_fonds_insuffisants: '자금이 부족합니다.', r_inventaire_plein: '인벤토리가 가득 찼습니다.', r_quantite_invalide: '잘못된 수량입니다(1~10).', refused: '서버가 작업을 거부했습니다.',
    shop: '악천후 대비 장비', o_bouteille_eau: '물 한 병', o_sac_de_sable: '모래주머니', o_groupe_electrogene: '발전기', shopBought: '{nom} {qte}개, {paye} {cur}.', pose: '가진 모래주머니를 이 건물 앞에 쌓기 (1 AP)', posed: '모래주머니 {n}개를 쌓았습니다. 이 건물 앞: {total}/{max}개, 다음 홍수 손실: 재고의 {perte}%.', fill: '연료 채우기 (통)', filled: '연료통: {n}통.', heatLost: '폭염으로 AP {n}을 잃었습니다.', heatWater: '물 한 병이 더위를 막아 주었습니다.', spoiledHeat: '더위로 지니고 있던 음식이 상했습니다 ({n}).', flooded: '이 건물은 물에 잠겼습니다.', cat: '자연재해 사태', catPropose: '총리에게 제안하기', catProposed: '총리에게 제안을 보냈습니다.', catIntro: '{ville} 홍수 피해: {pertes} {cur}. 정부 금고에서 {part}% 보상.', catSacs: '모래주머니를 쌓은 피해자만: {n}명, 비용 {cout} {cur}.', catTous: '모든 피해자: {n}명, 비용 {cout} {cur}.', catReserve: '정부 금고: {reserve} {cur}.', catDeadline: '{date}까지 결정할 수 있습니다.', catDeclared: '선포', catDone: '자연재해 사태 선포: {cout} {cur} 지급.', r_pas_a_la_boutique: '가게 안에 있어야 합니다.', r_hors_zone_inondable: '이 건물은 침수 구역이 아닙니다.', r_pas_proprietaire_ni_exploitant: '소유자나 운영자만 모래주머니를 쌓을 수 있습니다.', r_deja_protege: '이 건물 앞에는 이미 모래주머니가 최대치입니다.', r_pas_de_sacs: '모래주머니가 없습니다.', r_pas_de_groupe: '이곳에 발전기가 설치되어 있지 않습니다.', r_bidons_insuffisants: '연료통이 부족합니다.', r_poste_requis: '내무부 장관이나 총리만 가능합니다.', r_delai_depasse: '72시간 기한이 지났습니다.', r_deja_propose: '이미 제안했습니다.', r_pas_de_proposition: '내무부 장관이 아무것도 제안하지 않았습니다.', r_deja_declare: '이미 선포했습니다.', r_budget_insuffisant: '정부 금고가 부족합니다.', r_crue_inconnue: '알 수 없는 홍수입니다.', r_pa_insuffisants: 'AP가 부족합니다.' },
  ar: { gov: 'رسالة من الحكومة', ok: 'فهمت', at: 'في {ville} يوم {date}',
    crue: 'إنذار فيضان {lieu}: ستغمر المياه {lieux} لمدة 24 ساعة. ضع ممتلكاتك في مكان آمن.',
    canicule: 'إنذار موجة حر {lieu}: اشرب، وابقَ في الظل، ولا تحمل طعامًا معك.',
    orage: 'إنذار عاصفة {lieu}: يُتوقع انقطاع الكهرباء والإنترنت لمدة 24 ساعة.',
    brouillard: 'يُتوقع ضباب كثيف {lieu}. توخَّ الحذر في الشوارع.',
    blizzard: 'إنذار عاصفة ثلجية {lieu}: ابقَ في منزلك وتزوّد بالشحم.',
    building: 'توقّف الورشة: طقس سيئ في المدينة.',
    fats: 'شحوم', g_graisse_castor: 'مرطبان شحم القندس', g_graisse_ours: 'مرطبان شحم الدب', g_kolkhoze_graisse_renne: 'مرطبان شحم الرنة', buy: 'اشترِ', cancel: 'تراجع', quantity: 'الكمية', bought: '{qte} مرطبان مقابل {paye} {cur}.', deposit: 'اتركه في صيدليتي', deposited: 'تُرك {n} مرطبان: مخزون الصيدلية {stock}.', blizzardLost: 'كلّفتك العاصفة الثلجية {n} نقاط عمل.', blizzardFat: 'حماك مرطبان الشحم من البرد.', left: 'المتبقي {n}', r_pas_de_graisse_ici: 'لا يُباع الشحم هنا.', r_pas_ma_pharmacie: 'هذه ليست صيدليتك.', r_pas_de_graisse: 'ليس لديك هذا المرطبان.', r_stock_insuffisant: 'المخزون غير كافٍ: المتبقي {restant}.', r_fonds_insuffisants: 'أموال غير كافية.', r_inventaire_plein: 'المخزون ممتلئ.', r_quantite_invalide: 'كمية غير صالحة (من 1 إلى 10).', refused: 'رفض الخادم العملية.',
    shop: 'معدات مقاومة الأحوال الجوية', o_bouteille_eau: 'زجاجة ماء', o_sac_de_sable: 'كيس رمل', o_groupe_electrogene: 'مولّد كهربائي', shopBought: '{qte} × {nom} مقابل {paye} {cur}.', pose: 'ضع أكياسك أمام هذا المبنى (نقطة عمل واحدة)', posed: 'وُضع {n} كيس. أمام هذا المبنى: {total}/{max} أكياس؛ الخسارة في الفيضان القادم: {perte}% من المخزون.', fill: 'املأ (جراكن)', filled: 'الخزان: {n} جركن.', heatLost: 'كلّفتك موجة الحر {n} نقاط عمل.', heatWater: 'حمتك زجاجة الماء من الحر.', spoiledHeat: 'أفسد الحر الطعام الذي كنت تحمله ({n}).', flooded: 'هذا المبنى غارق في المياه.', cat: 'حالة الكارثة الطبيعية', catPropose: 'اقترح على رئيس الوزراء', catProposed: 'أُرسل الاقتراح إلى رئيس الوزراء.', catIntro: 'خسائر الفيضان في {ville}: {pertes} {cur}. تعويض بنسبة {part}% من صندوق الحكومة.', catSacs: 'المتضررون الذين وضعوا أكياس رمل فقط: {n}، الكلفة {cout} {cur}.', catTous: 'جميع المتضررين: {n}، الكلفة {cout} {cur}.', catReserve: 'صندوق الحكومة: {reserve} {cur}.', catDeadline: 'القرار ممكن حتى {date}.', catDeclared: 'أعلن', catDone: 'أُعلنت حالة الكارثة الطبيعية: دُفع {cout} {cur}.', r_pas_a_la_boutique: 'يجب أن تكون في المتجر.', r_hors_zone_inondable: 'هذا المبنى ليس في منطقة معرضة للفيضان.', r_pas_proprietaire_ni_exploitant: 'المالك أو المستغل وحده يضع أكياس الرمل.', r_deja_protege: 'أمام هذا المبنى الحد الأقصى من أكياس الرمل.', r_pas_de_sacs: 'ليست لديك أكياس رمل.', r_pas_de_groupe: 'لا يوجد مولّد مركّب هنا.', r_bidons_insuffisants: 'جراكن الوقود غير كافية.', r_poste_requis: 'مخصص لوزير الداخلية أو رئيس الوزراء.', r_delai_depasse: 'انقضت مهلة 72 ساعة.', r_deja_propose: 'سبق الاقتراح.', r_pas_de_proposition: 'لم يقترح وزير الداخلية شيئًا.', r_deja_declare: 'سبق الإعلان.', r_budget_insuffisant: 'صندوق الحكومة لا يكفي.', r_crue_inconnue: 'فيضان غير معروف.', r_pa_insuffisants: 'نقاط العمل غير كافية.' },
  'pt-BR': { gov: 'Mensagem do governo', ok: 'Entendido', at: 'em {ville}, no dia {date}',
    crue: 'Alerta de enchente {lieu}: {lieux} ficarão debaixo d’água por 24 horas. Ponha seus bens em segurança.',
    canicule: 'Alerta de onda de calor {lieu}: beba água, fique na sombra, não carregue comida com você.',
    orage: 'Alerta de tempestade {lieu}: quedas de energia e de internet previstas por 24 horas.',
    brouillard: 'Neblina densa prevista {lieu}. Cuidado nas ruas.',
    blizzard: 'Alerta de nevasca {lieu}: fique em casa e arranje gordura.',
    building: 'Obra parada: mau tempo na cidade.',
    fats: 'Gorduras', g_graisse_castor: 'Pote de gordura de castor', g_graisse_ours: 'Pote de gordura de urso', g_kolkhoze_graisse_renne: 'Pote de gordura de rena', buy: 'Comprar', cancel: 'Desistir', quantity: 'Quantidade', bought: '{qte} pote(s) por {paye} {cur}.', deposit: 'Deixar na minha farmácia', deposited: '{n} pote(s) entregue(s): estoque da farmácia {stock}.', blizzardLost: 'A nevasca lhe custou {n} PA.', blizzardFat: 'Seu pote de gordura protegeu você do frio.', left: 'restam {n}', r_pas_de_graisse_ici: 'Não se vende gordura aqui.', r_pas_ma_pharmacie: 'Esta não é a sua farmácia.', r_pas_de_graisse: 'Você não tem este pote.', r_stock_insuffisant: 'Estoque insuficiente: restam {restant}.', r_fonds_insuffisants: 'Fundos insuficientes.', r_inventaire_plein: 'Inventário cheio.', r_quantite_invalide: 'Quantidade inválida (1 a 10).', refused: 'O servidor recusou a operação.',
    shop: 'Equipamentos contra intempéries', o_bouteille_eau: 'Garrafa de água', o_sac_de_sable: 'Saco de areia', o_groupe_electrogene: 'Gerador', shopBought: '{qte} × {nom} por {paye} {cur}.', pose: 'Colocar seus sacos diante deste prédio (1 PA)', posed: '{n} saco(s) colocado(s). Diante deste prédio: {total}/{max} sacos; perda na próxima enchente: {perte}% do estoque.', fill: 'Abastecer (galões)', filled: 'Tanque: {n} galão(ões).', heatLost: 'A onda de calor lhe custou {n} PA.', heatWater: 'Sua garrafa de água protegeu você do calor.', spoiledHeat: 'O calor estragou a comida que você carregava ({n}).', flooded: 'Este prédio está debaixo d’água.', cat: 'Estado de calamidade natural', catPropose: 'Propor ao primeiro-ministro', catProposed: 'Proposta enviada ao primeiro-ministro.', catIntro: 'Perdas da enchente em {ville}: {pertes} {cur}. Indenização de {part}% pelo caixa do governo.', catSacs: 'Somente os atingidos que tinham colocado sacos de areia: {n} atingido(s), custo {cout} {cur}.', catTous: 'Todos os atingidos: {n} atingido(s), custo {cout} {cur}.', catReserve: 'Caixa do governo: {reserve} {cur}.', catDeadline: 'Decisão possível até {date}.', catDeclared: 'Declarar', catDone: 'Estado de calamidade natural declarado: {cout} {cur} pagos.', r_pas_a_la_boutique: 'É preciso estar na loja.', r_hors_zone_inondable: 'Este prédio não fica em área inundável.', r_pas_proprietaire_ni_exploitant: 'Só o proprietário ou o operador pode colocar sacos.', r_deja_protege: 'Este prédio já tem o máximo de sacos de areia.', r_pas_de_sacs: 'Você não tem sacos de areia.', r_pas_de_groupe: 'Nenhum gerador instalado aqui.', r_bidons_insuffisants: 'Galões de combustível insuficientes.', r_poste_requis: 'Reservado ao ministro do Interior ou ao primeiro-ministro.', r_delai_depasse: 'O prazo de 72 horas passou.', r_deja_propose: 'Já proposto.', r_pas_de_proposition: 'O ministro do Interior não propôs nada.', r_deja_declare: 'Já declarado.', r_budget_insuffisant: 'O caixa do governo não é suficiente.', r_crue_inconnue: 'Enchente desconhecida.', r_pa_insuffisants: 'PA insuficientes.' },
  de: { gov: 'Mitteilung der Regierung', ok: 'Verstanden', at: 'in {ville} am {date}',
    crue: 'Hochwasserwarnung {lieu}: {lieux} stehen 24 Stunden unter Wasser. Bringen Sie Ihr Hab und Gut in Sicherheit.',
    canicule: 'Hitzewarnung {lieu}: Trinken Sie, bleiben Sie im Schatten, tragen Sie keine Lebensmittel bei sich.',
    orage: 'Unwetterwarnung {lieu}: Strom- und Internetausfälle für 24 Stunden erwartet.',
    brouillard: 'Dichter Nebel erwartet {lieu}. Vorsicht auf der Straße.',
    blizzard: 'Schneesturmwarnung {lieu}: Bleiben Sie zu Hause und besorgen Sie sich Fett.',
    building: 'Baustelle gestoppt: Unwetter in der Stadt.',
    fats: 'Fett', g_graisse_castor: 'Glas Biberfett', g_graisse_ours: 'Glas Bärenfett', g_kolkhoze_graisse_renne: 'Glas Rentierfett', buy: 'Kaufen', cancel: 'Abbrechen', quantity: 'Menge', bought: '{qte} Glas/Gläser für {paye} {cur}.', deposit: 'In meiner Apotheke abgeben', deposited: '{n} Glas/Gläser abgegeben: Bestand der Apotheke {stock}.', blizzardLost: 'Der Schneesturm hat Sie {n} AP gekostet.', blizzardFat: 'Ihr Glas Fett hat Sie vor der Kälte geschützt.', left: 'noch {n}', r_pas_de_graisse_ici: 'Hier wird kein Fett verkauft.', r_pas_ma_pharmacie: 'Das ist nicht Ihre Apotheke.', r_pas_de_graisse: 'Sie haben dieses Glas nicht.', r_stock_insuffisant: 'Bestand reicht nicht: noch {restant}.', r_fonds_insuffisants: 'Unzureichende Mittel.', r_inventaire_plein: 'Inventar voll.', r_quantite_invalide: 'Ungültige Menge (1 bis 10).', refused: 'Der Server hat den Vorgang abgelehnt.',
    shop: 'Ausrüstung gegen Unwetter', o_bouteille_eau: 'Flasche Wasser', o_sac_de_sable: 'Sandsack', o_groupe_electrogene: 'Stromaggregat', shopBought: '{qte} × {nom} für {paye} {cur}.', pose: 'Ihre Sandsäcke vor diesem Gebäude auslegen (1 AP)', posed: '{n} Sandsack/-säcke ausgelegt. Vor diesem Gebäude: {total}/{max}; Verlust beim nächsten Hochwasser: {perte} % des Bestands.', fill: 'Auffüllen (Kanister)', filled: 'Tank: {n} Kanister.', heatLost: 'Die Hitzewelle hat Sie {n} AP gekostet.', heatWater: 'Ihre Wasserflasche hat Sie vor der Hitze geschützt.', spoiledHeat: 'Die Hitze hat die Lebensmittel verdorben, die Sie bei sich trugen ({n}).', flooded: 'Dieses Gebäude steht unter Wasser.', cat: 'Naturkatastrophenzustand', catPropose: 'Dem Premierminister vorschlagen', catProposed: 'Vorschlag an den Premierminister gesendet.', catIntro: 'Hochwasserschäden in {ville}: {pertes} {cur}. Entschädigung zu {part} % aus der Regierungskasse.', catSacs: 'Nur Geschädigte, die Sandsäcke ausgelegt hatten: {n}, Kosten {cout} {cur}.', catTous: 'Alle Geschädigten: {n}, Kosten {cout} {cur}.', catReserve: 'Regierungskasse: {reserve} {cur}.', catDeadline: 'Entscheidung möglich bis {date}.', catDeclared: 'Ausrufen', catDone: 'Naturkatastrophenzustand ausgerufen: {cout} {cur} ausgezahlt.', r_pas_a_la_boutique: 'Sie müssen im Geschäft sein.', r_hors_zone_inondable: 'Dieses Gebäude liegt nicht im Überschwemmungsgebiet.', r_pas_proprietaire_ni_exploitant: 'Nur Eigentümer oder Betreiber können Sandsäcke auslegen.', r_deja_protege: 'Vor diesem Gebäude liegen bereits die maximal möglichen Sandsäcke.', r_pas_de_sacs: 'Sie haben keine Sandsäcke.', r_pas_de_groupe: 'Hier ist kein Stromaggregat installiert.', r_bidons_insuffisants: 'Nicht genug Kraftstoffkanister.', r_poste_requis: 'Dem Innenminister oder dem Premierminister vorbehalten.', r_delai_depasse: 'Die 72-Stunden-Frist ist abgelaufen.', r_deja_propose: 'Bereits vorgeschlagen.', r_pas_de_proposition: 'Der Innenminister hat nichts vorgeschlagen.', r_deja_declare: 'Bereits ausgerufen.', r_budget_insuffisant: 'Die Regierungskasse reicht nicht aus.', r_crue_inconnue: 'Unbekanntes Hochwasser.', r_pa_insuffisants: 'Nicht genug AP.' }
};
const TYPES = ['crue', 'canicule', 'orage', 'brouillard', 'blizzard'];
// Alerte discrète des vues de rue (Fred, 21/11/2026). Table à part, en français : Codex y ajoute les huit autres langues
// (mêmes clés), puis elle peut rejoindre T. Repli sur le français tant qu'une langue manque.
const ALERTES = { fr: { brouillard: 'Attention : brouillard', blizzard: 'Attention : blizzard', orage: 'Attention : orage', crue: 'Attention : crue', canicule: 'Attention : canicule' } };
// Pictogrammes des alertes (Fred, 21/11/2026, version définitive) : signalétique officielle, trait noir sur triangle jaune.
const PICTOS = {
  orage: '<path d="M52 34 L40 58 H50 L44 78 L62 50 H52 L58 34 Z" fill="#111"/>',
  crue: '<path d="M30 56 q5 -6 10 0 t10 0 t10 0 t10 0 M30 66 q5 -6 10 0 t10 0 t10 0 t10 0 M34 76 q5 -6 10 0 t10 0 t10 0" fill="none" stroke="#111" stroke-width="4" stroke-linecap="round"/>',
  canicule: '<circle cx="42" cy="58" r="7" fill="#111"/><path d="M42 44v4M42 68v4M28 58h4M52 58h4M32 48l3 3M49 65l3 3M32 68l3-3M49 51l3-3" stroke="#111" stroke-width="3" stroke-linecap="round"/><path d="M63 44v24" stroke="#111" stroke-width="5" stroke-linecap="round"/><circle cx="63" cy="72" r="6" fill="#111"/>',
  brouillard: '<path d="M30 50h40M26 59h48M30 68h40M36 77h28" stroke="#111" stroke-width="4.5" stroke-linecap="round"/>',
  blizzard: '<path d="M50 40v38M34 49l32 20M34 69l32-20M44 42l6 5 6-5M44 76l6-5 6 5M33 55l7-2-1-7M67 63l-7 2 1 7M33 63l7 2-1 7M67 55l-7-2 1-7" fill="none" stroke="#111" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>'
};
function pictogramme(type) {
  return '<svg class="climat-picto" viewBox="0 0 100 92" width="64" height="59" aria-hidden="true">'
    + '<path d="M50 6 L95 86 H5 Z" fill="#FFD200" stroke="#111" stroke-width="6" stroke-linejoin="round"/>' + (PICTOS[type] || PICTOS.brouillard) + '</svg>';
}
// Explications du climat (Fred, 21/11/2026 : « une marque ne doit jamais rester sans explication », fenêtre d'accueil du
// nouveau personnage, message clair quand un lieu inondé refuse l'entrée). Même principe qu'ALERTES : français ici,
// Codex ajoute les huit autres langues sous les mêmes clés ; repli sur le français tant qu'une langue manque.
const EXPLIC = { fr: {
  nom_crue: 'Crue', nom_orage: 'Orage', nom_canicule: 'Canicule', nom_brouillard: 'Brouillard', nom_blizzard: 'Blizzard',
  restant: 'Encore {duree} (fin vers {heure}).', bientot: 'Se termine dans quelques instants.',
  duree_h: '{h} h {m} min', duree_m: '{m} min',
  ferme_titre: 'Lieu fermé : crue', ce_lieu: 'Ce lieu',
  ferme_corps: '{nom} est sous les eaux et fermé à cause de la crue. Il rouvre dans {duree} (vers {heure}). En attendant, vous circulez librement partout ailleurs : rues, autres lieux, gare et trains restent ouverts.',
  ferme_infobulle: 'Fermé (crue) : {nom}, réouverture dans {duree}',
  lieux_fermes: 'Lieux fermés : {lieux}.', aucun_lieu: 'Aucun lieu n’est fermé.',
  pourquoi: 'Pourquoi cet effet sur l’image ?',
  lieux_proteges: 'Protégés par des sacs de sable, donc ouverts : {lieux}.',
  annonce_crue: 'Crue annoncée {lieu}, à {heure} (heure du jeu).', annonce_orage: 'Orage annoncé {lieu}, à {heure} (heure du jeu).',
  annonce_canicule: 'Canicule annoncée {lieu}, à {heure} (heure du jeu).', annonce_brouillard: 'Brouillard annoncé {lieu}, à {heure} (heure du jeu).',
  annonce_blizzard: 'Blizzard annoncé {lieu}, à {heure} (heure du jeu).', debut_le: 'Début : le {date} à {heure} (heure du jeu).',
  cat_tous: 'Sinistrés de la crue (lieux non protégés qui ont perdu des stocks) : {n} sinistré(s), indemnisés à {part} % des stocks perdus, coût {cout} {cur}.',
  cat_libre: 'Vous restez libre de ne pas déclarer l’état de catastrophe naturelle.', cat_aucun: 'Aucun sinistré : aucun lieu non protégé n’a perdu de stock.',
  consignes: 'Consignes',
  o_bidon_carburant: 'Bidon de carburant', o_sels_rehydratation: 'Sels de réhydratation',
  eau_bouton: 'Remplir une bouteille d’eau', eau_infobulle: 'Gratuit, 0 PA : une bouteille d’eau, comme celle du commerce.',
  eau_ok: 'Vous avez rempli une bouteille d’eau à {nom}.', eau_titre: 'Point d’eau', eau_refus: 'Il n’y a pas de point d’eau ici.',
  accueil_titre: 'Bienvenue à {ville}',
  accueil_intro: 'Bienvenue parmi nous ! Un événement climatique frappe la ville en ce moment ({evenement}). Rien de grave : il est passager, et voici comment vous en protéger.',
  accueil_ok: 'J’ai compris, allons-y'
} };
// Nom d'un article de la boutique climat : table T (neuf langues), sinon EXPLIC (articles du complément du 21/11).
function nomArticle(cle) { const k = 'o_' + cle; return (T.fr[k] ? texte(k) : explic(k)); }
function explic(cle, vars) {
  const s = (EXPLIC[langue()] && EXPLIC[langue()][cle]) || EXPLIC.fr[cle] || cle;
  return String(s).replace(/\{(\w+)\}/g, (m, k) => (vars && Object.prototype.hasOwnProperty.call(vars, k)) ? String(vars[k]) : m);
}
// Un événement est « en cours » entre debut et fin, lus côté client à chaque passage : le filtre et les marques
// disparaissent à l'heure exacte de fin (6 heures), sans attendre la prochaine lecture du serveur.
function enCours(ev, maintenant) {
  const t = maintenant == null ? Date.now() : maintenant;
  return !!ev && Date.parse(ev.debut) <= t && t < Date.parse(ev.fin);
}
function dureeRestante(ev, maintenant) {
  const ms = Date.parse(ev.fin) - (maintenant == null ? Date.now() : maintenant);
  if (!(ms > 60000)) return null;
  const min = Math.ceil(ms / 60000), h = Math.floor(min / 60), m = min % 60;
  return h ? explic('duree_h', { h, m: String(m).padStart(2, '0') }) : explic('duree_m', { m });
}
// Heure du jeu (Paris) d'un instant ISO : heure de début annoncée (décision du 21/11 : début tiré au hasard sur 24 heures).
function heureDe(iso) {
  try { return new Date(iso).toLocaleTimeString(langue() === 'zh-TW' ? 'zh-TW' : langue(), { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Paris' }); }
  catch (_) { return String(iso).slice(11, 16); }
}
function heureFin(ev) {
  try { return new Date(ev.fin).toLocaleTimeString(langue() === 'zh-TW' ? 'zh-TW' : langue(), { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Paris' }); }
  catch (_) { return String(ev.fin).slice(11, 16); }
}
function ligneRestant(ev) {
  const d = dureeRestante(ev);
  return d ? explic('restant', { duree: d, heure: heureFin(ev) }) : explic('bientot');
}
function typeConnu(ev) { return TYPES.includes(ev && ev.type) ? ev.type : 'brouillard'; }
function lieuxFermes(ev) {
  const l = (ev && ev.type === 'crue' && Array.isArray(ev.lieux)) ? ev.lieux : [];
  return l.length ? explic('lieux_fermes', { lieux: l.map(nomLieu).join(', ') }) : '';
}
function lieuxProteges(ev) {
  const l = (ev && ev.type === 'crue' && Array.isArray(ev.lieux_proteges)) ? ev.lieux_proteges : [];
  return l.length ? explic('lieux_proteges', { lieux: l.map(nomLieu).join(', ') }) : '';
}
// Fenêtre commune : explication d'un événement (bandeau des vues de rue, accueil du nouveau personnage).
function fenetreExplication(ev, opts) {
  const doc = global.document;
  if (!doc || doc.getElementById('climat-explication')) return null;
  const o = opts || {}, type = typeConnu(ev);
  const fond = doc.createElement('div');
  fond.id = 'climat-explication';
  fond.setAttribute('role', 'dialog');
  fond.style.cssText = 'position:fixed;inset:0;z-index:9001;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;padding:16px';
  const titre = o.titre || explic('nom_' + type);
  const intro = o.intro ? '<p style="margin:0 0 .7rem">' + esc(o.intro) + '</p>' : '';
  const sec = (t, c) => '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.08em;color:#C9A84C;margin:.7rem 0 .2rem">' + esc(t) + '</div><p style="margin:0">' + esc(c) + '</p>';
  // Durée restante d'abord, puis la consigne du point 7 (texte serveur, propre à la ville).
  fond.innerHTML = '<div style="max-width:460px;width:100%;max-height:90vh;overflow:auto;background:#12100c;border:1px solid #8a6a20;padding:1.1rem 1.2rem;color:#e0d4b0;font-size:.9rem;line-height:1.55">'
    + '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.12em;color:#C9A84C;font-size:1.1rem;margin-bottom:.6rem"><i class="ti ti-cloud-storm"></i> ' + esc(titre) + '</div>'
    + intro + '<p style="margin:0" class="climat-restant">' + esc(ligneRestant(ev)) + '</p>'
    + '<p style="margin:.2rem 0 0;opacity:.85" class="climat-debut">' + esc(explic('debut_le', { date: dateCourte(ev.debut), heure: heureDe(ev.debut) })) + '</p>'
    + (lieuxFermes(ev) ? '<p style="margin:.4rem 0 0" class="climat-lieux">' + esc(lieuxFermes(ev)) + '</p>' : '')
    + (lieuxProteges(ev) ? '<p style="margin:.4rem 0 0" class="climat-proteges">' + esc(lieuxProteges(ev)) + '</p>' : '')
    + (ev.consigne ? sec(explic('consignes'), ev.consigne) : '')
    + '<button type="button" class="cpj-touche cpj-primaire" style="width:100%;margin-top:1rem">' + esc(o.bouton || texte('ok')) + '</button></div>';
  const fermer = () => { fond.remove(); if (typeof o.apres === 'function') o.apres(); };
  fond.querySelector('button').onclick = fermer;
  fond.addEventListener('click', e => { if (e.target === fond) fermer(); });
  doc.body.appendChild(fond);
  return fond;
}
function evenementIci() {
  const s = etat();
  return evenements.find(e => enCours(e) && e.ville === s.currentCity) || null;
}
function crueIci(batiment) {
  const ev = evenementIci();
  return ev && ev.type === 'crue' && Array.isArray(ev.lieux) && ev.lieux.includes(batiment) ? ev : null;
}
// Entrée refusée dans un lieu inondé : la cause, la durée restante et ce que le joueur peut faire.
function messageLieuFerme(batiment) {
  const ici = evenementIci();
  const ev = batiment ? crueIci(batiment) : (ici && ici.type === 'crue' ? ici : null);
  if (!ev) return texte('flooded');
  return explic('ferme_corps', { nom: batiment ? nomLieu(batiment) : explic('ce_lieu'), duree: dureeRestante(ev) || explic('duree_m', { m: 1 }), heure: heureFin(ev) });
}
// Lieux inondés sur la vue de rue : hachures bleues, infobulle et clic expliqués, entrée bloquée avec le message clair.
function marquerLieuxInondes() {
  const doc = global.document;
  if (!doc || !doc.querySelectorAll) return;
  const ev = evenementIci();
  const lieux = (ev && ev.type === 'crue' && Array.isArray(ev.lieux)) ? ev.lieux : [];
  doc.querySelectorAll('.rc-zone.climat-inonde').forEach(z => { if (!lieux.includes(z.dataset.building)) { z.classList.remove('climat-inonde'); z.removeAttribute('title'); } });
  for (const b of lieux) {
    doc.querySelectorAll('.rc-zone[data-building="' + String(b).replace(/["\\]/g, '') + '"]').forEach(z => {
      const info = explic('ferme_infobulle', { nom: nomLieu(b), duree: dureeRestante(ev) || explic('duree_m', { m: 1 }) });
      z.classList.add('climat-inonde');
      z.title = info;
      if (z.__climatInonde) return;
      z.__climatInonde = true;
      // Après l'infobulle d'origine (« Entrer dans : … ») : la raison de la marque la remplace.
      z.addEventListener('mousemove', () => {
        if (!z.classList.contains('climat-inonde')) return;
        const tip = doc.getElementById('rc-tooltip');
        if (tip) tip.textContent = z.title;
      });
      // Capture : passe avant l'entrée dans le bâtiment, qui serait de toute façon refusée par le serveur.
      z.addEventListener('click', e => {
        if (!z.classList.contains('climat-inonde') || !crueIci(z.dataset.building)) return;
        e.stopImmediatePropagation(); e.preventDefault();
        if (typeof global.showToast === 'function') global.showToast(explic('ferme_titre'), messageLieuFerme(z.dataset.building), false);
      }, true);
    });
  }
}
// Fenêtre d'accueil du nouveau personnage : une fois par événement, tenue par le serveur (climat_accueil_vu).
let accueilEnCours = false;
async function accueillirNouveau() {
  if (accueilEnCours || typeof global.sbRpc !== 'function' || !global.document) return;
  accueilEnCours = true;
  try {
    const r = un(await global.sbRpc('climat_accueil_lire', {}).catch(() => null));
    const ev = r && r.ok === true && r.evenement;
    if (!ev || !ev.id) return;
    const pays = etat().country || 'republic';
    const ville = (VILLES[pays] && VILLES[pays][ev.ville]) || ev.ville;
    // Le message du gouvernement du même événement ferait doublon.
    marquerVu(ev);
    fileAlertes = fileAlertes.filter(x => x.id !== ev.id);
    fenetreExplication(ev, { titre: explic('accueil_titre', { ville }), intro: explic('accueil_intro', { evenement: explic('nom_' + typeConnu(ev)).toLowerCase() }),
      bouton: explic('accueil_ok'), apres: () => { global.sbRpc('climat_accueil_vu', { p_evenement: ev.id }).catch(() => null); afficherSuivante(); } });
  } finally { accueilEnCours = false; }
}
const VILLES = { republic: { capitale: 'Luthécia', ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' },
                 soviet: { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' } };
const langue = () => { try { return (global.RPPlateauI18n && global.RPPlateauI18n.language && global.RPPlateauI18n.language()) || 'fr'; } catch (_) { return 'fr'; } };
function texte(cle, vars) {
  const s = (T[langue()] && T[langue()][cle]) || T.fr[cle] || cle;
  return String(s).replace(/\{(\w+)\}/g, (m, k) => (vars && Object.prototype.hasOwnProperty.call(vars, k)) ? String(vars[k]) : m);
}
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const etat = () => (typeof state !== 'undefined' && state) ? state : {};   // « let » de plateau-core.js, hors de window
const un = r => Array.isArray(r) ? r[0] : r;

function nomLieu(id) {
  try {
    if (typeof global.nomBatimentTraduit === 'function') { const n = global.nomBatimentTraduit(id); if (n) return n; }
    if (typeof BUILDINGS !== 'undefined' && BUILDINGS[id] && BUILDINGS[id].name) return String(BUILDINGS[id].name).replace(/&amp;/g, '&');
  } catch (_) {}
  return id;
}
function dateCourte(iso) {
  try { return new Date(iso).toLocaleDateString(langue() === 'zh-TW' ? 'zh-TW' : langue(), { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }); }
  catch (_) { return String(iso).slice(0, 10); }
}
// Message du gouvernement (alerte 48 heures avant) : l'annonce, puis la consigne du point 7 (menace, conséquences, parade).
function message(ev) {
  const pays = etat().country || 'republic';
  const lieu = texte('at', { ville: (VILLES[pays] && VILLES[pays][ev.ville]) || ev.ville, date: dateCourte(ev.debut) });
  return [explic('annonce_' + typeConnu(ev), { lieu, heure: heureDe(ev.debut) }), lieuxFermes(ev), ev.consigne || ''].filter(Boolean).join(' ');
}

// ── Fenêtre du gouvernement : une fois par alerte et par personnage ──────────────────────────────
// Un événement reporté (un seul à la fois par pays) est annoncé de nouveau : la clé suit sa date.
const cleVu = (id, debut) => 'rp-climat-vu:' + (etat().char && etat().char.name || '') + ':' + id + (debut ? ':' + String(debut).slice(0, 16) : '');
function dejaVu(ev) { try { return global.localStorage.getItem(cleVu(ev.id, ev.debut)) === '1'; } catch (_) { return false; } }
function marquerVu(ev) { try { global.localStorage.setItem(cleVu(ev.id, ev.debut), '1'); } catch (_) {} }
let fileAlertes = [];
function afficherSuivante() {
  const doc = global.document;
  if (!doc || doc.getElementById('climat-gouvernement') || doc.getElementById('climat-explication') || !fileAlertes.length) return;
  const ev = fileAlertes.shift();
  const fond = doc.createElement('div');
  fond.id = 'climat-gouvernement';
  fond.setAttribute('role', 'dialog');
  fond.style.cssText = 'position:fixed;inset:0;z-index:9000;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;padding:16px';
  fond.innerHTML = '<div style="max-width:440px;width:100%;background:#12100c;border:1px solid #8a6a20;padding:1.1rem 1.2rem;color:#e0d4b0">'
    + '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.12em;color:#C9A84C;font-size:1.05rem;margin-bottom:.6rem"><i class="ti ti-alert-triangle"></i> ' + esc(texte('gov')) + '</div>'
    + '<p style="font-size:.9rem;line-height:1.55;margin:0 0 1rem">' + esc(message(ev)) + '</p>'
    + '<button type="button" class="cpj-touche cpj-primaire" style="width:100%">' + esc(texte('ok')) + '</button></div>';
  fond.querySelector('button').onclick = () => { marquerVu(ev); fond.remove(); afficherSuivante(); };
  doc.body.appendChild(fond);
}

// ── Filtre animé sur la vue de rue de la ville touchée ──────────────────────────────────────────
let evenements = [];
// Tuiles de pluie : traits fins, verticaux dans la tuile (l'inclinaison vient de « rotate »), répartis pour ne pas
// dessiner de colonnes visibles.
const tuilePluie = (l, h, traits, couleur) => 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="' + l + '" height="' + h + '">'
  + traits.map(([x, y, n]) => '<line x1="' + x + '" y1="' + y + '" x2="' + x + '" y2="' + (y + n) + '" stroke="' + couleur + '" stroke-width="1.2" stroke-linecap="round"/>').join('') + '</svg>');
const PLUIE_PROCHE = tuilePluie(120, 160, [[8, 10, 26], [37, 92, 22], [61, 40, 28], [88, 128, 24], [104, 66, 20], [22, 140, 18]], 'rgba(205,220,240,.9)');
const PLUIE_LOINTAINE = tuilePluie(80, 120, [[6, 30, 14], [29, 84, 12], [47, 8, 15], [66, 58, 13], [74, 104, 10]], 'rgba(190,205,225,.8)');
function injecterStyle() {
  const doc = global.document;
  if (!doc || doc.getElementById('climat-style')) return;
  const st = doc.createElement('style');
  st.id = 'climat-style';
  st.textContent = '#climat-filtre{position:absolute;inset:0;pointer-events:none;z-index:3;overflow:hidden}'
    + '#climat-filtre.brouillard{background:rgba(235,235,240,.42);backdrop-filter:blur(2px) contrast(.8)}'
    + '#climat-filtre.blizzard{background:rgba(255,255,255,.35);backdrop-filter:brightness(1.15);background-image:radial-gradient(#fff 1px,transparent 1.5px);background-size:18px 18px;animation:climatNeige 2.5s linear infinite}'
    + '#climat-filtre.orage{background:rgba(10,15,30,.4);animation:climatEclair 7s infinite}'
    // Pluie animée (Fred, 21/11/2026) : chute continue, douce et régulière, légère obliquité. Deux nappes de gouttes
    // (proche, lointaine) en tuiles SVG qui se répètent verticalement ; seul un transform est animé (composité par la
    // carte graphique, aucun redessin), d'exactement une tuile par boucle : aucun à-coup. L'inclinaison (propriété
    // « rotate ») se compose avec l'animation. Les flèches restent au-dessus (z-index 1001), le filtre ne capte aucun clic.
    + '#climat-filtre.orage::before,#climat-filtre.orage::after{content:"";position:absolute;left:-25%;right:-25%;top:-160px;bottom:-40px;'
    + 'rotate:12deg;will-change:transform;background-repeat:repeat;pointer-events:none}'
    + '#climat-filtre.orage::before{background-image:url("' + PLUIE_PROCHE + '");background-size:120px 160px;opacity:.55;animation:climatPluieProche 1.1s linear infinite}'
    + '#climat-filtre.orage::after{background-image:url("' + PLUIE_LOINTAINE + '");background-size:80px 120px;opacity:.35;animation:climatPluieLointaine 1.6s linear infinite}'
    + '#climat-filtre.canicule{background:rgba(255,140,40,.18);backdrop-filter:saturate(1.3) sepia(.25);animation:climatChaleur 3s ease-in-out infinite}'
    + '#climat-filtre.crue{background:linear-gradient(to top,rgba(40,70,90,.65) 0,rgba(40,70,90,.35) 22%,transparent 40%);animation:climatEau 4s ease-in-out infinite}'
    + '@keyframes climatNeige{to{background-position:30px 180px}}@keyframes climatPluieProche{from{transform:translate3d(0,0,0)}to{transform:translate3d(0,160px,0)}}'
    + '@keyframes climatPluieLointaine{from{transform:translate3d(0,0,0)}to{transform:translate3d(0,120px,0)}}'
    + '@keyframes climatEclair{0%,94%,100%{filter:none}95%,97%{filter:brightness(2.4)}}@keyframes climatChaleur{50%{filter:blur(.6px)}}'
    + '@keyframes climatEau{50%{transform:translateY(-6px)}}'
    // Le climat illustre, il ne gêne jamais la navigation (Fred, 21/11/2026) : flèches et zones restent nettes, au-dessus du filtre.
    + '#rc-scene .rc-fleche,#rue-image .rc-fleche{position:absolute;z-index:1001}'
    // Lieux fermés par la crue : hachures bleues sur la zone du bâtiment (Fred, 21/11 : une marque toujours expliquée).
    + '.rc-zone.climat-inonde{background:repeating-linear-gradient(135deg,rgba(60,120,170,.42) 0 6px,rgba(60,120,170,.12) 6px 12px);outline:2px dashed rgba(140,190,230,.8);cursor:not-allowed}'
    // Le bandeau s'explique au clic (pourquoi l'image est rayée, combien de temps, quoi faire).
    + '#climat-alerte{position:absolute;top:8px;left:50%;transform:translateX(-50%);z-index:1002;pointer-events:auto;cursor:pointer;'
    + 'display:flex;flex-direction:column;align-items:center;gap:2px;animation:climatAlerte 4s ease-in-out infinite}'
    + '#climat-alerte .climat-alerte-texte{padding:.15rem .55rem;background:rgba(10,8,6,.7);color:#FFD200;border-radius:3px;'
    + 'font-family:Bebas Neue,sans-serif;letter-spacing:.1em;font-size:.95rem;white-space:nowrap}'
    + '#climat-alerte .climat-picto{filter:drop-shadow(0 1px 2px rgba(0,0,0,.6))}'
    // Clignotement lent, sans agressivité : l'alerte ne disparaît jamais tout à fait.
    + '@keyframes climatAlerte{0%,100%{opacity:1}50%{opacity:.55}}'
    // Joueurs qui ont demandé à réduire les animations dans leur système : tout reste visible, rien ne bouge.
    + '@media (prefers-reduced-motion: reduce){#climat-filtre,#climat-filtre::before,#climat-filtre::after,#climat-alerte{animation:none!important}}'
    + '#climat-eau{position:absolute;left:50%;bottom:58px;transform:translateX(-50%);z-index:1002;pointer-events:auto}';
  doc.head.appendChild(st);
}
function appliquerFiltre() {
  const doc = global.document;
  if (!doc) return;
  const s = etat();
  const ev = evenementIci();
  const rue = doc.getElementById('rue-image');
  // Scène de rue centrale : le filtre se pose DANS la scène, au-dessus de l'image mais sous les flèches de navigation.
  const hote = doc.getElementById('rc-scene') || rue;
  let f = doc.getElementById('climat-filtre');
  let a = doc.getElementById('climat-alerte');
  afficherPointEau(hote);
  if (!ev || !hote) { if (f) f.remove(); if (a) a.remove(); marquerLieuxInondes(); return; }
  injecterStyle();
  if (!f || f.parentNode !== hote) {
    if (f) f.remove();
    f = doc.createElement('div'); f.id = 'climat-filtre';
    if (global.getComputedStyle && global.getComputedStyle(hote).position === 'static') hote.style.position = 'relative';
    hote.appendChild(f);
  }
  f.className = ev.type;
  // Vues de rue uniquement : message discret qui clignote lentement (jamais dans les pièces).
  if (!a || a.parentNode !== hote) {
    if (a) a.remove();
    a = doc.createElement('div'); a.id = 'climat-alerte'; a.setAttribute('role', 'button'); a.tabIndex = 0;
    a.addEventListener('click', e => { e.stopPropagation(); const ici = evenementIci(); if (ici) fenetreExplication(ici); });
    a.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); const ici = evenementIci(); if (ici) fenetreExplication(ici); } });
    hote.appendChild(a);
  }
  const type = TYPES.includes(ev.type) ? ev.type : 'brouillard';
  const libelle = (ALERTES[langue()] && ALERTES[langue()][type]) || ALERTES.fr[type];
  if (a.dataset.type !== type || a.dataset.libelle !== libelle) {
    a.dataset.type = type; a.dataset.libelle = libelle;
    a.innerHTML = pictogramme(type) + '<span class="climat-alerte-texte">' + esc(libelle) + '</span>';
  }
  a.setAttribute('aria-label', libelle);
  a.title = explic('pourquoi') + ' ' + ligneRestant(ev);
  marquerLieuxInondes();
}

// ── Points d'eau : « Remplir une bouteille d'eau », gratuit, 0 PA (Fred, 21/11/2026) ─────────────────
// La liste vient du serveur (climat_points_eau, configuration) : un nouveau point d'eau n'exige aucun développement.
let pointsEau = null, pointsEauLecture = null;
function lirePointsEau() {
  if (pointsEau || pointsEauLecture || typeof global.sbRpc !== 'function') return;
  pointsEauLecture = global.sbRpc('climat_points_eau_lister', {}).then(r => { r = un(r); pointsEau = (r && r.ok === true && Array.isArray(r.points)) ? r.points : null; })
    .catch(() => null).finally(() => { pointsEauLecture = null; });
}
function pointEauIci() {
  const s = etat();
  const noeud = (typeof rueCentraleNoeudActuel !== 'undefined') ? rueCentraleNoeudActuel : global.__rueNoeud;   // « let » de plateau-rue-centrale.js
  if (!pointsEau || !noeud || s.currentBuilding) return null;
  return pointsEau.find(p => p.noeud === noeud && p.ville === s.currentCity && (!s.country || p.pays === s.country)) || null;
}
function afficherPointEau(hote) {
  const doc = global.document;
  lirePointsEau();
  const pe = hote ? pointEauIci() : null;
  let b = doc.getElementById('climat-eau');
  if (!pe) { if (b) b.remove(); return; }
  injecterStyle();
  if (b && b.parentNode === hote && b.dataset.point === pe.id) return;
  if (b) b.remove();
  b = doc.createElement('button');
  b.type = 'button'; b.id = 'climat-eau'; b.className = 'cpj-touche cpj-primaire'; b.dataset.point = pe.id;
  b.innerHTML = '<i class="ti ti-bottle"></i> ' + esc(explic('eau_bouton'));
  b.title = explic('eau_infobulle');
  b.addEventListener('click', e => { e.stopPropagation(); remplirBouteille(pe); });
  hote.appendChild(b);
}
async function remplirBouteille(pe) {
  const r = un(await global.sbRpc('point_eau_remplir', { p_requete: uuid() }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(explic('eau_titre'), r && r.raison === 'pas_de_point_eau' ? explic('eau_refus') : motif(r), false); return; }
  appliquerInventaire(r);
  global.showToast(explic('eau_titre'), explic('eau_ok', { nom: pe.nom }), true);
  if (typeof global.updateUI === 'function') global.updateUI();
}

// ── Graisses (lot 4) : poissonnière de Novomirsk, marché de Krasnov, pharmacies ouvertes par un PJ ─────
const CLES_GRAISSE = ['graisse_castor', 'graisse_ours', 'kolkhoze_graisse_renne'];
const uuid = () => (global.crypto && global.crypto.randomUUID) ? global.crypto.randomUUID()
  : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => Math.floor(Math.random() * 16).toString(16));
function devise() { return etat().country === 'soviet' ? 'PSK' : 'FR'; }
function motif(r) {
  const k = 'r_' + (r && r.raison);
  return (T[langue()] && T[langue()][k]) || T.fr[k] ? texte(k, r || {}) : texte('refused');
}
function appliquerInventaire(r) {
  if (r && typeof global.sbAdopterInventaireServeur === 'function') { try { global.sbAdopterInventaireServeur(r); } catch (_) {} }
  else if (r && Array.isArray(r.inventory) && typeof state !== 'undefined' && state) state.inventory = r.inventory;
}
async function ouvrirGraisses() {
  const e = un(await global.sbRpc('graisse_etat', {}).catch(() => null));
  if (!e || e.ok !== true) { global.showToast(texte('fats'), motif(e), false); return; }
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('fats');
  let html = '<div class="cpj-dialogue" style="padding:1rem"><select id="graisse-cle" class="cpj-champ" style="width:100%;margin-bottom:.6rem">';
  for (const o of (e.offre || [])) html += '<option value="' + esc(o.cle) + '">' + esc(texte('g_' + o.cle)) + ' — ' + esc(e.prix) + ' ' + esc(devise())
    + (o.restant != null ? ' — ' + esc(texte('left', { n: o.restant })) : '') + '</option>';
  html += '</select><label class="cpj-note" for="graisse-qte">' + esc(texte('quantity')) + '</label>'
    + '<input id="graisse-qte" class="cpj-champ" type="number" min="1" max="10" value="1" style="width:100%;margin-bottom:.8rem">'
    + '<div style="display:flex;gap:.5rem"><button class="cpj-touche cpj-primaire" style="flex:1" onclick="confirmerGraisse()">' + esc(texte('buy')) + '</button>'
    + '<button class="cpj-touche" style="flex:1" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div></div>';
  global.document.getElementById('postes-body').innerHTML = html;
  global.document.getElementById('modal-postes').classList.add('open');
}
let graisseEnCours = false;
async function confirmerGraisse() {
  if (graisseEnCours) return;
  const cle = global.document.getElementById('graisse-cle')?.value;
  const qte = Number(global.document.getElementById('graisse-qte')?.value);
  if (!cle || !Number.isSafeInteger(qte) || qte < 1 || qte > 10) { global.showToast(texte('fats'), texte('r_quantite_invalide'), false); return; }
  graisseEnCours = true;
  try {
    const r = un(await global.sbRpc('graisse_acheter', { p_requete: uuid(), p_cle: cle, p_qte: qte }).catch(() => null));
    if (!r || r.ok !== true) { global.showToast(texte('fats'), motif(r), false); return; }
    appliquerInventaire(r);
    global.document.getElementById('modal-postes')?.classList.remove('open');
    global.showToast(texte('g_' + cle), texte('bought', { qte: r.quantite, paye: r.paye, cur: devise() }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { graisseEnCours = false; }
}
// Pharmacie ouverte par un PJ : bouton « Graisses » dans la boutique (plateau-commerce-pj.js).
function climatGraissesBoutiqueHtml(fonds) {
  const types = (fonds && fonds.typesAutorises) || [];
  if (!Array.isArray(types) || types.indexOf('pharmacie') === -1) return '';
  return '<div style="margin-top:.6rem"><button onclick="ouvrirGraisses()" style="padding:.5rem .9rem;border:1px solid #B99A57;border-radius:5px;background:transparent;color:#E5C477;cursor:pointer">'
    + '<i class="ti ti-jar"></i> ' + esc(texte('fats')) + '</button></div>';
}
// Fiche d'un bocal dans l'inventaire : le propriétaire d'une pharmacie PJ le dépose dans sa boutique (le serveur vérifie).
function boutonDeposerGraisse(item, style) {
  if (!item || CLES_GRAISSE.indexOf(item.stackKey) === -1) return '';
  return '<button onclick="deposerGraisse(\'' + esc(item.stackKey) + '\',' + Math.max(1, Math.floor(Number(item.qty) || 1)) + ')" style="' + (style || '') + '"><i class="ti ti-jar"></i> '
    + esc(texte('deposit')) + '</button>';
}
async function deposerGraisse(cle, qte) {
  const r = un(await global.sbRpc('fonds_graisses_deposer', { p_requete: uuid(), p_cle: cle, p_qte: qte }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(texte('fats'), motif(r), false); return; }
  appliquerInventaire(r);
  global.document.getElementById('modal-postes')?.classList.remove('open');
  global.showToast(texte('g_' + cle), texte('deposited', { n: r.quantite, stock: r.stock }), true);
  if (typeof global.updateUI === 'function') global.updateUI();
}
function nomObjetClimat(item) {
  if (item && CLES_GRAISSE.indexOf(item.stackKey) !== -1) return texte('g_' + item.stackKey);
  if (item && item.stackKey === 'bouteille_eau') return texte('o_bouteille_eau');
  if (item && item.stackKey === 'sac_de_sable') return texte('o_sac_de_sable');
  if (item && item.generique_id === 'groupe-electrogene') return texte('o_groupe_electrogene');
  return null;
}
// Ce que l'événement a fait au personnage (blizzard : PA perdus ou graisse consommée), une fois, dans sa langue.
async function lireEffets() {
  const r = un(await global.sbRpc('climat_effets_lire', {}).catch(() => null));
  if (!r || r.ok !== true || !Array.isArray(r.effets)) return;
  for (const e of r.effets) {
    if (e.type === 'blizzard') global.showToast(texte('blizzard', { lieu: '' }).split(':')[0], e.graisse ? texte('blizzardFat') : texte('blizzardLost', { n: e.pa_perdus || 0 }), !!e.graisse);
    if (e.type === 'canicule') {
      if (e.eau !== undefined) global.showToast(texte('canicule', { lieu: '' }).split(':')[0], e.eau ? texte('heatWater') : texte('heatLost', { n: e.pa_perdus || 0 }), !!e.eau);
      if (e.aliments_gates) global.showToast(texte('canicule', { lieu: '' }).split(':')[0], texte('spoiledHeat', { n: e.aliments_gates }), false);
    }
  }
}

// ── Boutique « Équipements contre les intempéries » (lot 5) ─────────────────────────────────────
async function ouvrirBoutiqueClimat() {
  const e = un(await global.sbRpc('boutique_climat_etat', {}).catch(() => null));
  if (!e || e.ok !== true) { global.showToast(texte('shop'), motif(e), false); return; }
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('shop');
  let html = '<div class="cpj-dialogue" style="padding:1rem"><select id="climat-objet" class="cpj-champ" style="width:100%;margin-bottom:.6rem">';
  for (const o of (e.offre || [])) html += '<option value="' + esc(o.cle) + '">' + esc(nomArticle(o.cle)) + ' — ' + esc(o.prix) + ' ' + esc(devise()) + '</option>';
  html += '</select><label class="cpj-note" for="climat-qte">' + esc(texte('quantity')) + '</label>'
    + '<input id="climat-qte" class="cpj-champ" type="number" min="1" max="10" value="1" style="width:100%;margin-bottom:.8rem">'
    + '<div style="display:flex;gap:.5rem"><button class="cpj-touche cpj-primaire" style="flex:1" onclick="confirmerBoutiqueClimat()">' + esc(texte('buy')) + '</button>'
    + '<button class="cpj-touche" style="flex:1" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div></div>';
  global.document.getElementById('postes-body').innerHTML = html;
  global.document.getElementById('modal-postes').classList.add('open');
}
let boutiqueEnCours = false;
async function confirmerBoutiqueClimat() {
  if (boutiqueEnCours) return;
  const cle = global.document.getElementById('climat-objet')?.value;
  const qte = Number(global.document.getElementById('climat-qte')?.value);
  if (!cle || !Number.isSafeInteger(qte) || qte < 1 || qte > 10) { global.showToast(texte('shop'), texte('r_quantite_invalide'), false); return; }
  boutiqueEnCours = true;
  try {
    const r = un(await global.sbRpc('boutique_climat_acheter', { p_requete: uuid(), p_cle: cle, p_qte: qte }).catch(() => null));
    if (!r || r.ok !== true) { global.showToast(texte('shop'), motif(r), false); return; }
    appliquerInventaire(r);
    global.document.getElementById('modal-postes')?.classList.remove('open');
    global.showToast(texte('shop'), texte('shopBought', { qte: r.quantite, nom: nomArticle(cle), paye: r.paye, cur: devise() }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { boutiqueEnCours = false; }
}
// Sac de sable de l'inventaire : en poser un (1 PA) devant le bâtiment où l'on se trouve ; il le protège pour la prochaine crue (le serveur vérifie zone et droits).
function boutonPoserSacs(item, style) {
  if (!item || item.stackKey !== 'sac_de_sable') return '';
  return '<button onclick="poserSacsSable()" style="' + (style || '') + '"><i class="ti ti-bag"></i> ' + esc(texte('pose')) + '</button>';
}
async function poserSacsSable() {
  const r = un(await global.sbRpc('sacs_sable_poser', { p_requete: uuid() }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(texte('o_sac_de_sable'), motif(r), false); return; }
  appliquerInventaire(r);
  if (typeof r.pa === 'number' && typeof state !== 'undefined' && state) state.pa = r.pa;
  global.document.getElementById('modal-postes')?.classList.remove('open');
  global.showToast(texte('o_sac_de_sable'), texte('posed'), true);
  if (typeof global.updateUI === 'function') global.updateUI();
}
// Groupe électrogène installé dans le bureau : le remplir de bidons de carburant (plateau-equipements.js).
function boutonGroupeRemplir(e) {
  if (!e || e.generique_id !== 'groupe-electrogene' || !e.a_moi) return '';
  return '<button type="button" class="cpj-touche" onclick="groupeRemplir()">' + esc(texte('fill')) + '</button>';
}
async function groupeRemplir() {
  const n = Number(global.prompt ? global.prompt(texte('fill'), '5') : 5);
  if (!Number.isSafeInteger(n) || n < 1) return;
  const r = un(await global.sbRpc('groupe_remplir', { p_requete: uuid(), p_qte: n }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(texte('o_groupe_electrogene'), motif(r), false); return; }
  appliquerInventaire(r);
  global.showToast(texte('o_groupe_electrogene'), texte('filled', { n: r.bidons }), true);
  if (typeof global.updateUI === 'function') global.updateUI();
}

// ── État de catastrophe naturelle (boutons des courriers du ministère de l'Intérieur) ──────────────
async function catastropheProposer(id) {
  const r = un(await global.sbRpc('catastrophe_proposer', { p_evenement: Number(id) }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(texte('cat'), motif(r), false); return; }
  global.showToast(texte('cat'), texte('catProposed'), true);
}
async function catastropheExaminer(id) {
  const e = un(await global.sbRpc('catastrophe_etat', { p_evenement: Number(id) }).catch(() => null));
  if (!e || e.ok !== true) { global.showToast(texte('cat'), motif(e), false); return; }
  const cur = devise();
  const pays = etat().country || 'republic';
  const ville = (VILLES[pays] && VILLES[pays][e.ville]) || e.ville;
  const doc = global.document;
  const titre = doc.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('cat');
  let html = '<div class="cpj-dialogue" style="padding:1rem">'
    + '<p class="cpj-note">' + esc(texte('catIntro', { ville, pertes: e.pertes, cur, part: e.part })) + '</p>'
    + '<p class="cpj-note">' + esc(texte('catReserve', { reserve: e.reserve, cur })) + ' ' + esc(texte('catDeadline', { date: new Date(e.limite).toLocaleString() })) + '</p>';
  if (e.declare) html += '<p class="cpj-note">' + esc(texte('catDone', { cout: e.cout_verse, cur })) + '</p>';
  else if (e.poste === 'pm') {
    // Décision du 21/11 : une seule option, tous les sinistrés (lieux non protégés qui ont perdu des stocks) à 50 %.
    html += '<div style="border:1px solid #394656;padding:.7rem;margin:.6rem 0"><p class="cpj-note">'
      + esc(Number(e.sinistres) > 0 ? explic('cat_tous', { n: e.sinistres, part: e.part, cout: e.cout, cur }) : explic('cat_aucun')) + '</p>'
      + '<p class="cpj-note">' + esc(explic('cat_libre')) + '</p>'
      + '<button class="cpj-touche cpj-primaire" style="width:100%" onclick="catastropheDeclarer(' + Number(e.evenement) + ')">' + esc(texte('catDeclared')) + '</button></div>';
  } else if (!e.propose) {
    html += '<button class="cpj-touche cpj-primaire" style="width:100%" onclick="catastropheProposer(' + Number(e.evenement) + ')">' + esc(texte('catPropose')) + '</button>';
  }
  html += '<button class="cpj-touche" style="width:100%;margin-top:.6rem" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div>';
  doc.getElementById('postes-body').innerHTML = html;
  doc.getElementById('modal-postes').classList.add('open');
}
async function catastropheDeclarer(id) {
  const r = un(await global.sbRpc('catastrophe_declarer', { p_evenement: Number(id), p_etendre: true }).catch(() => null));
  if (!r || r.ok !== true) { global.showToast(texte('cat'), motif(r), false); return; }
  global.document.getElementById('modal-postes')?.classList.remove('open');
  global.showToast(texte('cat'), texte('catDone', { cout: r.cout, cur: devise() }), true);
}

async function rafraichirClimat() {
  lireEffets().catch(() => {});
  if (typeof global.sbRpc !== 'function') return;
  const r = un(await global.sbRpc('climat_etat', {}).catch(() => null));
  if (!r || r.ok !== true) return;
  evenements = Array.isArray(r.evenements) ? r.evenements : [];
  for (const ev of evenements) if (!dejaVu(ev) && !fileAlertes.some(x => x.id === ev.id)) fileAlertes.push(ev);
  await accueillirNouveau();
  afficherSuivante();
  appliquerFiltre();
}
// Chantier refusé pendant les intempéries : le refus du serveur arrive sous forme de code (« chantier_intemperies ») dans
// le message générique des commandes de construction ; on le remplace par la phrase traduite.
function brancherToast() {
  const orig = global.showToast;
  if (typeof orig !== 'function' || orig.__climat) return;
  const enveloppe = function (titre, corps) {
    const args = Array.prototype.slice.call(arguments);
    if (corps === 'chantier_intemperies') args[1] = texte('building');
    if (corps === 'batiment_inonde') { args[1] = messageLieuFerme(null); if (titre !== explic('ferme_titre')) args[0] = explic('ferme_titre'); }
    return orig.apply(this, args);
  };
  enveloppe.__climat = true;
  global.showToast = enveloppe;
}
function demarrer() {
  brancherToast();
  setTimeout(rafraichirClimat, 6000);
  setInterval(rafraichirClimat, 600000);
  setInterval(appliquerFiltre, 1500);   // la vue de rue change à chaque déplacement : le filtre et l'alerte suivent, sans lecture serveur
}
if (global.document && global.document.readyState !== 'loading') demarrer();
else if (global.document) global.document.addEventListener('DOMContentLoaded', demarrer);

global.RPClimat = { T, ALERTES, EXPLIC, TYPES, PICTOS, pictogramme, texte, explic, message, rafraichirClimat, appliquerFiltre, nomObjet: nomObjetClimat,
  pointEauIci, remplirBouteille, _pointsEau: v => { if (Array.isArray(v)) pointsEau = v; return pointsEau; },
  enCours, dureeRestante, messageLieuFerme, fenetreExplication, accueillirNouveau, marquerLieuxInondes,
  _evenements: v => { if (Array.isArray(v)) evenements = v; return evenements; } };
Object.assign(global, { ouvrirGraisses, confirmerGraisse, climatGraissesBoutiqueHtml, boutonDeposerGraisse, deposerGraisse,
  ouvrirBoutiqueClimat, confirmerBoutiqueClimat, boutonPoserSacs, poserSacsSable, boutonGroupeRemplir, groupeRemplir,
  catastropheProposer, catastropheExaminer, catastropheDeclarer });
})(typeof window !== 'undefined' ? window : globalThis);
