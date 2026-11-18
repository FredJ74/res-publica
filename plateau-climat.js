// Événements climatiques — lot 3 (GAME-DESIGN-MALADIES-CLIMAT.md §§ 4 et 11, décisions de Fred du 18/11/2026).
// Le serveur tranche tout (calendrier, alertes 48 h avant, événement en cours) : climat_etat() ne renvoie que les alertes
// publiées du pays du joueur. L'écran affiche une fenêtre « Message du gouvernement » une fois par alerte et par personnage,
// et un filtre animé sur la vue de rue de la ville touchée pendant l'événement (aucune nouvelle image).
(function (global) {
'use strict';
const T = {
  fr: { gov: 'Message du gouvernement', ok: 'Compris', at: 'à {ville}, le {date}',
    crue: 'Alerte crue {lieu} : {lieux} seront sous les eaux pendant 24 heures. Mettez vos biens à l’abri.',
    canicule: 'Alerte canicule {lieu} : buvez, restez à l’ombre, ne gardez pas de nourriture sur vous.',
    orage: 'Alerte orage {lieu} : coupures d’électricité et d’internet attendues pendant 24 heures.',
    brouillard: 'Brouillard épais attendu {lieu}. Prudence sur la voie publique.',
    blizzard: 'Alerte blizzard {lieu} : restez chez vous et munissez-vous de graisse.',
    building: 'Chantier à l’arrêt : intempéries en cours dans la ville.',
    fats: 'Graisses', g_graisse_castor: 'Bocal de graisse de castor', g_graisse_ours: 'Bocal de graisse d’ours', g_kolkhoze_graisse_renne: 'Bocal de graisse de renne', buy: 'Acheter', cancel: 'Renoncer', quantity: 'Quantité', bought: '{qte} bocal(aux) pour {paye} {cur}.', deposit: 'Déposer dans ma pharmacie', deposited: '{n} bocal(aux) déposé(s) : stock de la pharmacie {stock}.', blizzardLost: 'Le blizzard vous a coûté {n} PA.', blizzardFat: 'Votre bocal de graisse vous a protégé du froid.', left: 'reste {n}', r_pas_de_graisse_ici: 'Pas de graisse en vente ici.', r_pas_ma_pharmacie: 'Ce n’est pas votre pharmacie.', r_pas_de_graisse: 'Vous n’avez pas ce bocal.', r_stock_insuffisant: 'Stock insuffisant : il en reste {restant}.', r_fonds_insuffisants: 'Fonds insuffisants.', r_inventaire_plein: 'Inventaire plein.', r_quantite_invalide: 'Quantité invalide (1 à 10).', refused: 'Le serveur a refusé l’opération.' },
  en: { gov: 'Government message', ok: 'Understood', at: 'in {ville} on {date}',
    crue: 'Flood warning {lieu}: {lieux} will be under water for 24 hours. Move your belongings to safety.',
    canicule: 'Heatwave warning {lieu}: drink water, stay in the shade, do not carry food on you.',
    orage: 'Storm warning {lieu}: power and internet cuts expected for 24 hours.',
    brouillard: 'Thick fog expected {lieu}. Take care on the streets.',
    blizzard: 'Blizzard warning {lieu}: stay indoors and get some fat.',
    building: 'Building site halted: severe weather in the city.',
    fats: 'Fat', g_graisse_castor: 'Jar of beaver fat', g_graisse_ours: 'Jar of bear fat', g_kolkhoze_graisse_renne: 'Jar of reindeer fat', buy: 'Buy', cancel: 'Cancel', quantity: 'Quantity', bought: '{qte} jar(s) for {paye} {cur}.', deposit: 'Leave in my pharmacy', deposited: '{n} jar(s) left: the pharmacy now holds {stock}.', blizzardLost: 'The blizzard cost you {n} AP.', blizzardFat: 'Your jar of fat protected you from the cold.', left: '{n} left', r_pas_de_graisse_ici: 'No fat on sale here.', r_pas_ma_pharmacie: 'This is not your pharmacy.', r_pas_de_graisse: 'You do not have this jar.', r_stock_insuffisant: 'Not enough stock: {restant} left.', r_fonds_insuffisants: 'Insufficient funds.', r_inventaire_plein: 'Inventory full.', r_quantite_invalide: 'Invalid quantity (1 to 10).', refused: 'The server refused the operation.' },
  es: { gov: 'Mensaje del gobierno', ok: 'Entendido', at: 'en {ville}, el {date}',
    crue: 'Alerta de inundación {lieu}: {lieux} quedarán bajo el agua durante 24 horas. Ponga sus bienes a salvo.',
    canicule: 'Alerta de ola de calor {lieu}: beba, quédese a la sombra, no lleve comida encima.',
    orage: 'Alerta de tormenta {lieu}: se esperan cortes de electricidad y de internet durante 24 horas.',
    brouillard: 'Se espera niebla espesa {lieu}. Precaución en la vía pública.',
    blizzard: 'Alerta de ventisca {lieu}: quédese en casa y consiga grasa.',
    building: 'Obra parada: mal tiempo en la ciudad.',
    fats: 'Grasas', g_graisse_castor: 'Tarro de grasa de castor', g_graisse_ours: 'Tarro de grasa de oso', g_kolkhoze_graisse_renne: 'Tarro de grasa de reno', buy: 'Comprar', cancel: 'Renunciar', quantity: 'Cantidad', bought: '{qte} tarro(s) por {paye} {cur}.', deposit: 'Dejar en mi farmacia', deposited: '{n} tarro(s) entregado(s): existencias de la farmacia {stock}.', blizzardLost: 'La ventisca le ha costado {n} PA.', blizzardFat: 'Su tarro de grasa le protegió del frío.', left: 'quedan {n}', r_pas_de_graisse_ici: 'Aquí no se vende grasa.', r_pas_ma_pharmacie: 'Esta no es su farmacia.', r_pas_de_graisse: 'No tiene este tarro.', r_stock_insuffisant: 'Existencias insuficientes: quedan {restant}.', r_fonds_insuffisants: 'Fondos insuficientes.', r_inventaire_plein: 'Inventario lleno.', r_quantite_invalide: 'Cantidad no válida (1 a 10).', refused: 'El servidor rechazó la operación.' },
  'zh-TW': { gov: '政府訊息', ok: '知道了', at: '{date}於{ville}',
    crue: '洪水警報（{lieu}）：{lieux}將被淹沒 24 小時。請把財物移到安全處。',
    canicule: '熱浪警報（{lieu}）：多喝水，待在陰涼處，別把食物帶在身上。',
    orage: '暴風雨警報（{lieu}）：預計停電並中斷網路 24 小時。',
    brouillard: '預計有濃霧（{lieu}）。上街請小心。',
    blizzard: '暴風雪警報（{lieu}）：請待在室內，備好油脂。',
    building: '工地停工：城裡正值惡劣天氣。',
    fats: '油脂', g_graisse_castor: '一罐河狸油脂', g_graisse_ours: '一罐熊油脂', g_kolkhoze_graisse_renne: '一罐馴鹿油脂', buy: '購買', cancel: '放棄', quantity: '數量', bought: '{qte} 罐，共 {paye} {cur}。', deposit: '放到我的藥房', deposited: '已放下 {n} 罐：藥房存量 {stock}。', blizzardLost: '暴風雪讓你損失了 {n} 行動點。', blizzardFat: '你的油脂罐幫你抵禦了寒冷。', left: '剩 {n}', r_pas_de_graisse_ici: '這裡不賣油脂。', r_pas_ma_pharmacie: '這不是你的藥房。', r_pas_de_graisse: '你沒有這種罐子。', r_stock_insuffisant: '庫存不足：只剩 {restant}。', r_fonds_insuffisants: '資金不足。', r_inventaire_plein: '背包已滿。', r_quantite_invalide: '數量無效（1 至 10）。', refused: '伺服器拒絕了此操作。' },
  ru: { gov: 'Сообщение правительства', ok: 'Понятно', at: '— {ville}, {date}',
    crue: 'Предупреждение о наводнении {lieu}: {lieux} будут под водой 24 часа. Уберите имущество в безопасное место.',
    canicule: 'Предупреждение о жаре {lieu}: пейте воду, держитесь в тени, не носите еду с собой.',
    orage: 'Предупреждение о грозе {lieu}: ожидаются отключения электричества и интернета на 24 часа.',
    brouillard: 'Ожидается густой туман {lieu}. Будьте осторожны на улице.',
    blizzard: 'Предупреждение о буране {lieu}: оставайтесь дома и запаситесь жиром.',
    building: 'Стройка остановлена: в городе непогода.',
    fats: 'Жир', g_graisse_castor: 'Банка бобрового жира', g_graisse_ours: 'Банка медвежьего жира', g_kolkhoze_graisse_renne: 'Банка оленьего жира', buy: 'Купить', cancel: 'Отказаться', quantity: 'Количество', bought: 'Банок: {qte} за {paye} {cur}.', deposit: 'Оставить в моей аптеке', deposited: 'Оставлено банок: {n}; запас аптеки: {stock}.', blizzardLost: 'Буран стоил вам {n} ОД.', blizzardFat: 'Банка жира защитила вас от холода.', left: 'осталось {n}', r_pas_de_graisse_ici: 'Здесь жир не продаётся.', r_pas_ma_pharmacie: 'Это не ваша аптека.', r_pas_de_graisse: 'У вас нет такой банки.', r_stock_insuffisant: 'Недостаточно запасов: осталось {restant}.', r_fonds_insuffisants: 'Недостаточно средств.', r_inventaire_plein: 'Инвентарь полон.', r_quantite_invalide: 'Неверное количество (от 1 до 10).', refused: 'Сервер отклонил операцию.' },
  ko: { gov: '정부 메시지', ok: '확인', at: '{date}, {ville}',
    crue: '홍수 경보({lieu}): {lieux}이(가) 24시간 동안 물에 잠깁니다. 재산을 안전한 곳으로 옮기세요.',
    canicule: '폭염 경보({lieu}): 물을 마시고 그늘에 머물며 음식을 몸에 지니지 마세요.',
    orage: '뇌우 경보({lieu}): 24시간 동안 정전과 인터넷 끊김이 예상됩니다.',
    brouillard: '짙은 안개 예상({lieu}). 거리에서 조심하세요.',
    blizzard: '눈보라 경보({lieu}): 집에 머물고 지방을 준비하세요.',
    building: '공사 중단: 시내에 악천후가 이어지고 있습니다.',
    fats: '지방', g_graisse_castor: '비버 지방 한 병', g_graisse_ours: '곰 지방 한 병', g_kolkhoze_graisse_renne: '순록 지방 한 병', buy: '구매', cancel: '취소', quantity: '수량', bought: '{qte}병, {paye} {cur}.', deposit: '내 약국에 맡기기', deposited: '{n}병을 맡겼습니다: 약국 재고 {stock}.', blizzardLost: '눈보라로 AP {n}을 잃었습니다.', blizzardFat: '지방 한 병이 추위를 막아 주었습니다.', left: '{n} 남음', r_pas_de_graisse_ici: '이곳에서는 지방을 팔지 않습니다.', r_pas_ma_pharmacie: '당신의 약국이 아닙니다.', r_pas_de_graisse: '이 병을 가지고 있지 않습니다.', r_stock_insuffisant: '재고 부족: {restant} 남았습니다.', r_fonds_insuffisants: '자금이 부족합니다.', r_inventaire_plein: '인벤토리가 가득 찼습니다.', r_quantite_invalide: '잘못된 수량입니다(1~10).', refused: '서버가 작업을 거부했습니다.' },
  ar: { gov: 'رسالة من الحكومة', ok: 'فهمت', at: 'في {ville} يوم {date}',
    crue: 'إنذار فيضان {lieu}: ستغمر المياه {lieux} لمدة 24 ساعة. ضع ممتلكاتك في مكان آمن.',
    canicule: 'إنذار موجة حر {lieu}: اشرب، وابقَ في الظل، ولا تحمل طعامًا معك.',
    orage: 'إنذار عاصفة {lieu}: يُتوقع انقطاع الكهرباء والإنترنت لمدة 24 ساعة.',
    brouillard: 'يُتوقع ضباب كثيف {lieu}. توخَّ الحذر في الشوارع.',
    blizzard: 'إنذار عاصفة ثلجية {lieu}: ابقَ في منزلك وتزوّد بالشحم.',
    building: 'توقّف الورشة: طقس سيئ في المدينة.',
    fats: 'شحوم', g_graisse_castor: 'مرطبان شحم القندس', g_graisse_ours: 'مرطبان شحم الدب', g_kolkhoze_graisse_renne: 'مرطبان شحم الرنة', buy: 'اشترِ', cancel: 'تراجع', quantity: 'الكمية', bought: '{qte} مرطبان مقابل {paye} {cur}.', deposit: 'اتركه في صيدليتي', deposited: 'تُرك {n} مرطبان: مخزون الصيدلية {stock}.', blizzardLost: 'كلّفتك العاصفة الثلجية {n} نقاط عمل.', blizzardFat: 'حماك مرطبان الشحم من البرد.', left: 'المتبقي {n}', r_pas_de_graisse_ici: 'لا يُباع الشحم هنا.', r_pas_ma_pharmacie: 'هذه ليست صيدليتك.', r_pas_de_graisse: 'ليس لديك هذا المرطبان.', r_stock_insuffisant: 'المخزون غير كافٍ: المتبقي {restant}.', r_fonds_insuffisants: 'أموال غير كافية.', r_inventaire_plein: 'المخزون ممتلئ.', r_quantite_invalide: 'كمية غير صالحة (من 1 إلى 10).', refused: 'رفض الخادم العملية.' },
  'pt-BR': { gov: 'Mensagem do governo', ok: 'Entendido', at: 'em {ville}, no dia {date}',
    crue: 'Alerta de enchente {lieu}: {lieux} ficarão debaixo d’água por 24 horas. Ponha seus bens em segurança.',
    canicule: 'Alerta de onda de calor {lieu}: beba água, fique na sombra, não carregue comida com você.',
    orage: 'Alerta de tempestade {lieu}: quedas de energia e de internet previstas por 24 horas.',
    brouillard: 'Neblina densa prevista {lieu}. Cuidado nas ruas.',
    blizzard: 'Alerta de nevasca {lieu}: fique em casa e arranje gordura.',
    building: 'Obra parada: mau tempo na cidade.',
    fats: 'Gorduras', g_graisse_castor: 'Pote de gordura de castor', g_graisse_ours: 'Pote de gordura de urso', g_kolkhoze_graisse_renne: 'Pote de gordura de rena', buy: 'Comprar', cancel: 'Desistir', quantity: 'Quantidade', bought: '{qte} pote(s) por {paye} {cur}.', deposit: 'Deixar na minha farmácia', deposited: '{n} pote(s) entregue(s): estoque da farmácia {stock}.', blizzardLost: 'A nevasca lhe custou {n} PA.', blizzardFat: 'Seu pote de gordura protegeu você do frio.', left: 'restam {n}', r_pas_de_graisse_ici: 'Não se vende gordura aqui.', r_pas_ma_pharmacie: 'Esta não é a sua farmácia.', r_pas_de_graisse: 'Você não tem este pote.', r_stock_insuffisant: 'Estoque insuficiente: restam {restant}.', r_fonds_insuffisants: 'Fundos insuficientes.', r_inventaire_plein: 'Inventário cheio.', r_quantite_invalide: 'Quantidade inválida (1 a 10).', refused: 'O servidor recusou a operação.' },
  de: { gov: 'Mitteilung der Regierung', ok: 'Verstanden', at: 'in {ville} am {date}',
    crue: 'Hochwasserwarnung {lieu}: {lieux} stehen 24 Stunden unter Wasser. Bringen Sie Ihr Hab und Gut in Sicherheit.',
    canicule: 'Hitzewarnung {lieu}: Trinken Sie, bleiben Sie im Schatten, tragen Sie keine Lebensmittel bei sich.',
    orage: 'Unwetterwarnung {lieu}: Strom- und Internetausfälle für 24 Stunden erwartet.',
    brouillard: 'Dichter Nebel erwartet {lieu}. Vorsicht auf der Straße.',
    blizzard: 'Schneesturmwarnung {lieu}: Bleiben Sie zu Hause und besorgen Sie sich Fett.',
    building: 'Baustelle gestoppt: Unwetter in der Stadt.',
    fats: 'Fett', g_graisse_castor: 'Glas Biberfett', g_graisse_ours: 'Glas Bärenfett', g_kolkhoze_graisse_renne: 'Glas Rentierfett', buy: 'Kaufen', cancel: 'Abbrechen', quantity: 'Menge', bought: '{qte} Glas/Gläser für {paye} {cur}.', deposit: 'In meiner Apotheke abgeben', deposited: '{n} Glas/Gläser abgegeben: Bestand der Apotheke {stock}.', blizzardLost: 'Der Schneesturm hat Sie {n} AP gekostet.', blizzardFat: 'Ihr Glas Fett hat Sie vor der Kälte geschützt.', left: 'noch {n}', r_pas_de_graisse_ici: 'Hier wird kein Fett verkauft.', r_pas_ma_pharmacie: 'Das ist nicht Ihre Apotheke.', r_pas_de_graisse: 'Sie haben dieses Glas nicht.', r_stock_insuffisant: 'Bestand reicht nicht: noch {restant}.', r_fonds_insuffisants: 'Unzureichende Mittel.', r_inventaire_plein: 'Inventar voll.', r_quantite_invalide: 'Ungültige Menge (1 bis 10).', refused: 'Der Server hat den Vorgang abgelehnt.' }
};
const TYPES = ['crue', 'canicule', 'orage', 'brouillard', 'blizzard'];
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
function message(ev) {
  const pays = etat().country || 'republic';
  const lieu = texte('at', { ville: (VILLES[pays] && VILLES[pays][ev.ville]) || ev.ville, date: dateCourte(ev.debut) });
  return texte(TYPES.includes(ev.type) ? ev.type : 'brouillard', { lieu, lieux: (ev.lieux || []).map(nomLieu).join(', ') });
}

// ── Fenêtre du gouvernement : une fois par alerte et par personnage ──────────────────────────────
const cleVu = id => 'rp-climat-vu:' + (etat().char && etat().char.name || '') + ':' + id;
function dejaVu(id) { try { return global.localStorage.getItem(cleVu(id)) === '1'; } catch (_) { return false; } }
function marquerVu(id) { try { global.localStorage.setItem(cleVu(id), '1'); } catch (_) {} }
let fileAlertes = [];
function afficherSuivante() {
  const doc = global.document;
  if (!doc || doc.getElementById('climat-gouvernement') || !fileAlertes.length) return;
  const ev = fileAlertes.shift();
  const fond = doc.createElement('div');
  fond.id = 'climat-gouvernement';
  fond.setAttribute('role', 'dialog');
  fond.style.cssText = 'position:fixed;inset:0;z-index:9000;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;padding:16px';
  fond.innerHTML = '<div style="max-width:440px;width:100%;background:#12100c;border:1px solid #8a6a20;padding:1.1rem 1.2rem;color:#e0d4b0">'
    + '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.12em;color:#C9A84C;font-size:1.05rem;margin-bottom:.6rem"><i class="ti ti-alert-triangle"></i> ' + esc(texte('gov')) + '</div>'
    + '<p style="font-size:.9rem;line-height:1.55;margin:0 0 1rem">' + esc(message(ev)) + '</p>'
    + '<button type="button" class="cpj-touche cpj-primaire" style="width:100%">' + esc(texte('ok')) + '</button></div>';
  fond.querySelector('button').onclick = () => { marquerVu(ev.id); fond.remove(); afficherSuivante(); };
  doc.body.appendChild(fond);
}

// ── Filtre animé sur la vue de rue de la ville touchée ──────────────────────────────────────────
let evenements = [];
function injecterStyle() {
  const doc = global.document;
  if (!doc || doc.getElementById('climat-style')) return;
  const st = doc.createElement('style');
  st.id = 'climat-style';
  st.textContent = '#climat-filtre{position:absolute;inset:0;pointer-events:none;z-index:3}'
    + '#climat-filtre.brouillard{background:rgba(235,235,240,.42);backdrop-filter:blur(2px) contrast(.8)}'
    + '#climat-filtre.blizzard{background:rgba(255,255,255,.35);backdrop-filter:brightness(1.15);background-image:radial-gradient(#fff 1px,transparent 1.5px);background-size:18px 18px;animation:climatNeige 2.5s linear infinite}'
    + '#climat-filtre.orage{background:rgba(10,15,30,.45);background-image:repeating-linear-gradient(105deg,rgba(180,200,230,.35) 0 1px,transparent 1px 9px);animation:climatPluie .4s linear infinite,climatEclair 7s infinite}'
    + '#climat-filtre.canicule{background:rgba(255,140,40,.18);backdrop-filter:saturate(1.3) sepia(.25);animation:climatChaleur 3s ease-in-out infinite}'
    + '#climat-filtre.crue{background:linear-gradient(to top,rgba(40,70,90,.65) 0,rgba(40,70,90,.35) 22%,transparent 40%);animation:climatEau 4s ease-in-out infinite}'
    + '@keyframes climatNeige{to{background-position:30px 180px}}@keyframes climatPluie{to{background-position:-20px 40px}}'
    + '@keyframes climatEclair{0%,94%,100%{filter:none}95%,97%{filter:brightness(2.4)}}@keyframes climatChaleur{50%{filter:blur(.6px)}}'
    + '@keyframes climatEau{50%{transform:translateY(-6px)}}';
  doc.head.appendChild(st);
}
function appliquerFiltre() {
  const doc = global.document;
  if (!doc) return;
  const s = etat();
  const ev = evenements.find(e => e.en_cours && e.ville === s.currentCity);
  const rue = doc.getElementById('rue-image');
  let f = doc.getElementById('climat-filtre');
  if (!ev || !rue) { if (f) f.remove(); return; }
  injecterStyle();
  if (!f || f.parentNode !== rue) {
    if (f) f.remove();
    f = doc.createElement('div'); f.id = 'climat-filtre';
    if (global.getComputedStyle && global.getComputedStyle(rue).position === 'static') rue.style.position = 'relative';
    rue.appendChild(f);
  }
  f.className = ev.type;
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
  return null;
}
// Ce que l'événement a fait au personnage (blizzard : PA perdus ou graisse consommée), une fois, dans sa langue.
async function lireEffets() {
  const r = un(await global.sbRpc('climat_effets_lire', {}).catch(() => null));
  if (!r || r.ok !== true || !Array.isArray(r.effets)) return;
  for (const e of r.effets) {
    if (e.type === 'blizzard') global.showToast(texte('blizzard', { lieu: '' }).split(':')[0], e.graisse ? texte('blizzardFat') : texte('blizzardLost', { n: e.pa_perdus || 0 }), !!e.graisse);
  }
}

async function rafraichirClimat() {
  lireEffets().catch(() => {});
  if (typeof global.sbRpc !== 'function') return;
  const r = un(await global.sbRpc('climat_etat', {}).catch(() => null));
  if (!r || r.ok !== true) return;
  evenements = Array.isArray(r.evenements) ? r.evenements : [];
  for (const ev of evenements) if (!dejaVu(ev.id) && !fileAlertes.some(x => x.id === ev.id)) fileAlertes.push(ev);
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
    return orig.apply(this, args);
  };
  enveloppe.__climat = true;
  global.showToast = enveloppe;
}
function demarrer() {
  brancherToast();
  setTimeout(rafraichirClimat, 6000);
  setInterval(rafraichirClimat, 600000);
  setInterval(appliquerFiltre, 5000);   // la vue de rue change à chaque déplacement : le filtre suit, sans lecture serveur
}
if (global.document && global.document.readyState !== 'loading') demarrer();
else if (global.document) global.document.addEventListener('DOMContentLoaded', demarrer);

global.RPClimat = { T, TYPES, texte, message, rafraichirClimat, appliquerFiltre, nomObjet: nomObjetClimat };
Object.assign(global, { ouvrirGraisses, confirmerGraisse, climatGraissesBoutiqueHtml, boutonDeposerGraisse, deposerGraisse });
})(typeof window !== 'undefined' ? window : globalThis);
