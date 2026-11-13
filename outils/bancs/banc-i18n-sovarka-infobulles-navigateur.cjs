// Chromium réel (13/11/2026) : infobulles des ordres de Sovarka, badge de gain et salon de coiffure
// dans les neuf langues, en 320 px, 390 px et bureau. Sources réelles chargées ; aucun compte, aucun
// Supabase : la seule « requête » est un salon_lire simulé, compté.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const http = require('node:http'), os = require('node:os');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const fnSource = (src, nom) => { const i = src.indexOf('function ' + nom + '('); const j = src.indexOf('\n}', i); return src.slice(i, j + 2); };

function page() {
  const sources = [
    fnSource(lire('plateau-politique.js'), 'deviseDansTexte'),
    fnSource(lire('data.js'), 'montantDansTexte'),
    lire('i18n/sovarka-infobulles-resources.js'),
    fnSource(lire('plateau-vehicules.js'), 'vehModal'),
    lire('plateau-salon.js')
  ].join('\n;\n');
  return `<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="stylesheet" href="/style.css"><body>
<div class="actions-row" id="actions-row-bat"></div>
<div id="modal-postes" class="modal-overlay"><div class="modal-box"><div class="modal-header"><div class="modal-title" id="postes-modal-title">x</div><button class="modal-close">x</button></div><div id="postes-body"></div></div></div>
<script>
window.RP_I18N_GAME_ENABLED = true; let LANG = 'fr';
window.RPPlateauI18n = { language: () => LANG };
let state = { country: 'soviet', char: { name: 'Arnie' } };
const COUNTRIES = { soviet: { cur: 'PSK' } };
const RPC = []; const TOASTS = [];
async function sbRpcVerdict(nom) { RPC.push(nom); return { ok: true, salon: { id: 'salon-novo', prixCoupe: 20 }, jour: 10, prochaineCoupeJour: 12 }; }
function showToast(t, m) { TOASTS.push(t + ' ' + m); }
</script><script>${sources}</script><script>
const I = window.RPSovarkaInfobullesI18n;
const LANGUES = I.langues;
// Ordres réels de data.js (textes exacts), dont le train à tarif national (75 → 40) et une mention « Bientôt ».
const ORDRES = [
  { fn: 'sovarka_surveiller', label: 'Faire surveiller un citoyen', pa: 1, cost: 0, type: 'grey', d: ${JSON.stringify(lireDesc('Faire suivre un citoyen pendant 4 jours'))}, g: [], r: [['-2', 'DIS']], s: 100 },
  { fn: 'residence_louer', label: 'Louer un appartement', pa: 1, cost: 0, type: 'legal', d: ${JSON.stringify(lireDesc('Location privative de 3 nuits'))}, g: [['+15', 'POP'], ['+15', 'INF']], r: [], s: 100 },
  { fn: 'train_sovarka', label: 'Prendre le train', pa: 2, cost: 75, type: 'legal', d: '75 FR. 2 PA. Vers une autre ville de Sovarka.', n: { cost: 40, pa: 2 }, g: [], r: [], s: 100 },
  { fn: 'repas_hopital', label: 'Repas', pa: 1, cost: 0, type: 'legal', d: 'Repas economique. +5 Sante.', g: [['+5', 'sante'], ['+2', 'moral']], r: [], s: 100 },
  { fn: 'pharmacie', label: 'Acheter des médicaments', pa: 1, cost: 0, type: 'legal', bientot: 'Bientôt disponible : les médicaments de la pharmacie seront définis prochainement.', g: [['+10', 'sante']], r: [], s: 100 }
];
function afficheFr(o) { let d = deviseDansTexte(o.d || '', 'PSK'); if (o.n) d = montantDansTexte(d, o.cost, o.n.cost); return d; }
function rendreBoutons() {
  // Même gabarit que plateau-politique.js (bouton, title, descripteur, libellé, coût, badge).
  document.getElementById('actions-row-bat').innerHTML = ORDRES.map(o => {
    const spec = { d: o.d || '', a: afficheFr(o), c: o.cost, p: o.pa, v: 'PSK', n: o.n || null, g: o.g, r: o.r, s: o.s };
    const tooltip = o.bientot ? I.desc(o.bientot) : I.infobulle(spec);
    const desc = o.bientot ? { k: 'bientot', t: o.bientot } : spec;
    const gain = I.gains(o.g);
    return '<button class="action-btn ' + o.type + (o.bientot ? ' blocked' : '') + '" title="' + tooltip + '" data-rp-tip="' + encodeURIComponent(JSON.stringify(desc)) + '"><i class="ti ti-star"></i> <span>' + o.label + '</span> <span class="pa-cost">' + (o.n ? o.n.cost : o.cost) + ' PSK · ' + o.pa + ' PA</span>' + (gain ? '<span class="action-gain">' + gain + '</span>' : '') + '</button>';
  }).join('');
}
function exiger(c, m) { if (!c) throw Error(m); }
function debordement() { return Math.max(0, document.documentElement.scrollWidth - innerWidth); }
(async () => { try {
  const releve = {};
  rendreBoutons();
  const titresFr = [...document.querySelectorAll('[data-rp-tip]')].map(b => b.getAttribute('title'));
  // Le train : devise et tarif national appliqués au français comme à l'écran.
  exiger(titresFr[2].startsWith('40 PSK. 2 PA.'), 'train fr : ' + titresFr[2]);
  const debFr = debordement();
  await ouvrirSalonCoupe();
  const salonFr = document.getElementById('postes-body').innerHTML;
  for (const l of LANGUES) {
    LANG = l; document.documentElement.lang = l;
    if (l === 'ar') document.documentElement.setAttribute('dir', 'rtl'); else document.documentElement.removeAttribute('dir');
    for (const cb of window.RP_I18N_CHANGE_CALLBACKS) cb(l);
    const boutons = [...document.querySelectorAll('[data-rp-tip]')];
    boutons.forEach((b, i) => {
      const t = b.getAttribute('title');
      exiger(t && !t.includes('undefined'), l + ' titre vide ' + i);
      if (l === 'fr') exiger(t === titresFr[i], 'fr modifié ' + i);
      else exiger(t !== titresFr[i], l + ' non traduit ' + i + ' : ' + t);
      const badge = b.querySelector('.action-gain');
      if (badge) { const rb = badge.getBoundingClientRect(), rbt = b.getBoundingClientRect(); exiger(rb.right <= rbt.right + 1 && rb.left >= rbt.left - 1, l + ' badge hors du bouton ' + i); }
    });
    exiger(boutons[2].getAttribute('title').startsWith('40 PSK'), l + ' tarif du train perdu');
    if (l === 'de') exiger(boutons[3].querySelector('.action-gain').textContent === '+5 Gesundheit · +2 Moral', 'badge de');
    if (l === 'ru') exiger(/Здоровье/.test(boutons[3].querySelector('.action-gain').textContent), 'badge ru');
    exiger(debordement() <= Math.max(debFr, 0) + 1, l + ' débordement horizontal ' + debordement() + ' > ' + debFr);
    // Salon : repeint depuis le cache, fenêtre lisible, aucune requête de plus.
    const box = document.querySelector('#modal-postes .modal-box');
    exiger(document.getElementById('modal-postes').classList.contains('open'), l + ' salon fermé');
    exiger(box.getBoundingClientRect().width <= innerWidth + 1, l + ' fenêtre plus large que l’écran');
    exiger(box.scrollWidth <= box.clientWidth + 1, l + ' défilement horizontal dans la fenêtre');
    const corps = document.getElementById('postes-body').innerHTML;
    if (l === 'fr') exiger(corps === salonFr, 'salon fr modifié'); else exiger(corps !== salonFr, l + ' salon non traduit');
    releve[l] = { titre: document.getElementById('postes-modal-title').textContent, infobulle: boutons[0].getAttribute('title').slice(0, 60), dir: getComputedStyle(box).direction };
  }
  exiger(releve.ar.dir === 'rtl', 'arabe sans direction RTL');
  exiger(RPC.length === 1 && RPC[0] === 'salon_lire', 'requêtes : ' + RPC.join(','));
  exiger(sessionStorage.length === 0, 'coupe préparée par la bascule');
  exiger(TOASTS.length === 0, 'messages inattendus : ' + TOASTS.join(' / '));
  document.body.dataset.releve = JSON.stringify(releve);
  document.body.dataset.verdict = 'OK';
} catch (e) { document.body.dataset.verdict = 'ECHEC'; document.body.dataset.erreur = e.message; } })();
</script></body></html>`;
}
// Textes exacts : ceux du catalogue, dont un banc Node vérifie qu'ils sont ceux de data.js.
function lireDesc(debut) {
  const ctx = { window: null }; ctx.window = ctx; require('node:vm').createContext(ctx);
  require('node:vm').runInContext(lire('i18n/sovarka-infobulles-resources.js'), ctx);
  const t = ctx.RPSovarkaInfobullesI18n.textes.find(x => x.startsWith(debut));
  if (!t) throw Error('description introuvable : ' + debut);
  return t;
}

async function scenario(largeur, mobile) {
  const html = page();
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-infobulles-'));
  const serveur = http.createServer((req, res) => {
    const css = req.url === '/style.css';
    res.setHeader('Content-Type', css ? 'text/css' : 'text/html; charset=utf-8');
    res.end(css ? fs.readFileSync(path.join(root, 'style.css')) : html);
  });
  let nav, ws; const attente = new Map(); let id = 0;
  const pause = ms => new Promise(r => setTimeout(r, ms));
  try {
    await new Promise((r, j) => { serveur.once('error', j); serveur.listen(0, '127.0.0.1', r); });
    const executable = process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p));
    if (!executable) throw Error('HG_CHROMIUM_SPAWN : Chromium requis pour cette vérification');
    nav = await lancerChromium({ executable, profil });
    let cible; const limite = performance.now() + 7000;
    while (performance.now() < limite) {
      nav.controlerProcessus();
      cible = (await (await fetch('http://127.0.0.1:' + nav.port + '/json/list')).json()).find(p => p.type === 'page' && p.webSocketDebuggerUrl);
      if (cible) break; await pause(50);
    }
    if (!cible) throw Error('HG_CHROMIUM_CDP_TIMEOUT : aucune page');
    ws = new WebSocket(cible.webSocketDebuggerUrl);
    await new Promise((r, j) => { ws.onopen = r; ws.onerror = () => j(Error('HG_CHROMIUM_CDP : WebSocket refusée')); });
    ws.onmessage = e => { const m = JSON.parse(e.data); const a = attente.get(m.id); if (a) { attente.delete(m.id); m.error ? a.j(Error(JSON.stringify(m.error))) : a.r(m.result); } };
    const cdp = (method, params = {}) => new Promise((r, j) => { const n = ++id; attente.set(n, { r, j }); ws.send(JSON.stringify({ id: n, method, params })); setTimeout(() => { if (attente.delete(n)) j(Error('HG_CHROMIUM_CDP_TIMEOUT : ' + method)); }, 7000); });
    await cdp('Emulation.setDeviceMetricsOverride', { width: largeur, height: 760, deviceScaleFactor: 1, mobile });
    await cdp('Page.navigate', { url: 'http://127.0.0.1:' + serveur.address().port + '/' });
    let verdict; const fin = performance.now() + 10000;
    while (performance.now() < fin) {
      verdict = (await cdp('Runtime.evaluate', { expression: 'document.body && document.body.dataset.verdict', returnByValue: true })).result?.value;
      if (verdict) break; await pause(25);
    }
    const infos = (await cdp('Runtime.evaluate', { expression: 'JSON.stringify({e:document.body.dataset.erreur||"",r:document.body.dataset.releve||"{}"})', returnByValue: true })).result.value;
    return { verdict, ...JSON.parse(infos) };
  } finally {
    for (const a of attente.values()) a.j(Error('fermeture'));
    try { ws?.close(); } catch (_) {}
    await nav?.arreter?.();
    serveur.close();
    fs.rmSync(profil, { recursive: true, force: true });
  }
}

for (const [nom, largeur, mobile] of [['téléphone 320 px', 320, true], ['téléphone 390 px', 390, true], ['bureau 1280 px', 1280, false]]) {
  test('Chromium ' + nom + ' : neuf langues, infobulles, badge et salon', { timeout: 60000 }, async () => {
    const r = await scenario(largeur, mobile);
    assert.equal(r.verdict, 'OK', r.e);
    const releve = JSON.parse(r.r);
    assert.equal(releve.ru.titre, 'Парикмахерская');
    assert.equal(releve.ar.titre, 'صالون حلاقة');
    assert.match(releve.ko.infobulle, /미행/);
  });
}
