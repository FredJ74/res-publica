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
    building: 'Chantier à l’arrêt : intempéries en cours dans la ville.' },
  en: { gov: 'Government message', ok: 'Understood', at: 'in {ville} on {date}',
    crue: 'Flood warning {lieu}: {lieux} will be under water for 24 hours. Move your belongings to safety.',
    canicule: 'Heatwave warning {lieu}: drink water, stay in the shade, do not carry food on you.',
    orage: 'Storm warning {lieu}: power and internet cuts expected for 24 hours.',
    brouillard: 'Thick fog expected {lieu}. Take care on the streets.',
    blizzard: 'Blizzard warning {lieu}: stay indoors and get some fat.',
    building: 'Building site halted: severe weather in the city.' },
  es: { gov: 'Mensaje del gobierno', ok: 'Entendido', at: 'en {ville}, el {date}',
    crue: 'Alerta de inundación {lieu}: {lieux} quedarán bajo el agua durante 24 horas. Ponga sus bienes a salvo.',
    canicule: 'Alerta de ola de calor {lieu}: beba, quédese a la sombra, no lleve comida encima.',
    orage: 'Alerta de tormenta {lieu}: se esperan cortes de electricidad y de internet durante 24 horas.',
    brouillard: 'Se espera niebla espesa {lieu}. Precaución en la vía pública.',
    blizzard: 'Alerta de ventisca {lieu}: quédese en casa y consiga grasa.',
    building: 'Obra parada: mal tiempo en la ciudad.' },
  'zh-TW': { gov: '政府訊息', ok: '知道了', at: '{date}於{ville}',
    crue: '洪水警報（{lieu}）：{lieux}將被淹沒 24 小時。請把財物移到安全處。',
    canicule: '熱浪警報（{lieu}）：多喝水，待在陰涼處，別把食物帶在身上。',
    orage: '暴風雨警報（{lieu}）：預計停電並中斷網路 24 小時。',
    brouillard: '預計有濃霧（{lieu}）。上街請小心。',
    blizzard: '暴風雪警報（{lieu}）：請待在室內，備好油脂。',
    building: '工地停工：城裡正值惡劣天氣。' },
  ru: { gov: 'Сообщение правительства', ok: 'Понятно', at: '— {ville}, {date}',
    crue: 'Предупреждение о наводнении {lieu}: {lieux} будут под водой 24 часа. Уберите имущество в безопасное место.',
    canicule: 'Предупреждение о жаре {lieu}: пейте воду, держитесь в тени, не носите еду с собой.',
    orage: 'Предупреждение о грозе {lieu}: ожидаются отключения электричества и интернета на 24 часа.',
    brouillard: 'Ожидается густой туман {lieu}. Будьте осторожны на улице.',
    blizzard: 'Предупреждение о буране {lieu}: оставайтесь дома и запаситесь жиром.',
    building: 'Стройка остановлена: в городе непогода.' },
  ko: { gov: '정부 메시지', ok: '확인', at: '{date}, {ville}',
    crue: '홍수 경보({lieu}): {lieux}이(가) 24시간 동안 물에 잠깁니다. 재산을 안전한 곳으로 옮기세요.',
    canicule: '폭염 경보({lieu}): 물을 마시고 그늘에 머물며 음식을 몸에 지니지 마세요.',
    orage: '뇌우 경보({lieu}): 24시간 동안 정전과 인터넷 끊김이 예상됩니다.',
    brouillard: '짙은 안개 예상({lieu}). 거리에서 조심하세요.',
    blizzard: '눈보라 경보({lieu}): 집에 머물고 지방을 준비하세요.',
    building: '공사 중단: 시내에 악천후가 이어지고 있습니다.' },
  ar: { gov: 'رسالة من الحكومة', ok: 'فهمت', at: 'في {ville} يوم {date}',
    crue: 'إنذار فيضان {lieu}: ستغمر المياه {lieux} لمدة 24 ساعة. ضع ممتلكاتك في مكان آمن.',
    canicule: 'إنذار موجة حر {lieu}: اشرب، وابقَ في الظل، ولا تحمل طعامًا معك.',
    orage: 'إنذار عاصفة {lieu}: يُتوقع انقطاع الكهرباء والإنترنت لمدة 24 ساعة.',
    brouillard: 'يُتوقع ضباب كثيف {lieu}. توخَّ الحذر في الشوارع.',
    blizzard: 'إنذار عاصفة ثلجية {lieu}: ابقَ في منزلك وتزوّد بالشحم.',
    building: 'توقّف الورشة: طقس سيئ في المدينة.' },
  'pt-BR': { gov: 'Mensagem do governo', ok: 'Entendido', at: 'em {ville}, no dia {date}',
    crue: 'Alerta de enchente {lieu}: {lieux} ficarão debaixo d’água por 24 horas. Ponha seus bens em segurança.',
    canicule: 'Alerta de onda de calor {lieu}: beba água, fique na sombra, não carregue comida com você.',
    orage: 'Alerta de tempestade {lieu}: quedas de energia e de internet previstas por 24 horas.',
    brouillard: 'Neblina densa prevista {lieu}. Cuidado nas ruas.',
    blizzard: 'Alerta de nevasca {lieu}: fique em casa e arranje gordura.',
    building: 'Obra parada: mau tempo na cidade.' },
  de: { gov: 'Mitteilung der Regierung', ok: 'Verstanden', at: 'in {ville} am {date}',
    crue: 'Hochwasserwarnung {lieu}: {lieux} stehen 24 Stunden unter Wasser. Bringen Sie Ihr Hab und Gut in Sicherheit.',
    canicule: 'Hitzewarnung {lieu}: Trinken Sie, bleiben Sie im Schatten, tragen Sie keine Lebensmittel bei sich.',
    orage: 'Unwetterwarnung {lieu}: Strom- und Internetausfälle für 24 Stunden erwartet.',
    brouillard: 'Dichter Nebel erwartet {lieu}. Vorsicht auf der Straße.',
    blizzard: 'Schneesturmwarnung {lieu}: Bleiben Sie zu Hause und besorgen Sie sich Fett.',
    building: 'Baustelle gestoppt: Unwetter in der Stadt.' }
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

async function rafraichirClimat() {
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

global.RPClimat = { T, TYPES, texte, message, rafraichirClimat, appliquerFiltre };
})(typeof window !== 'undefined' ? window : globalThis);
