// Descriptions d'ordres communes à la Républia et à Sovarka (13/11/2026) : 205 textes, neuf langues,
// même résolveur que les 111 textes propres à Sovarka (RPSovarkaInfobullesI18n), dans les deux pays.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const R = new URL('../../', import.meta.url);
const lire = f => readFileSync(new URL(f, R), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const fnSource = (src, nom) => { const i = src.indexOf('function ' + nom + '('); const j = src.indexOf('\n}', i); return src.slice(i, j + 2); };

function charger(pays, langue, { communes = true, extra = {} } = {}) {
  const ctx = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => langue }, ...extra };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext('var state = { country: ' + JSON.stringify(pays) + ' };', ctx);
  vm.runInContext(fnSource(lire('plateau-politique.js'), 'deviseDansTexte'), ctx);
  vm.runInContext(fnSource(lire('data.js'), 'montantDansTexte'), ctx);
  if (communes) vm.runInContext(lire('i18n/infobulles-communes-resources.js'), ctx);
  vm.runInContext(lire('i18n/sovarka-infobulles-resources.js'), ctx);
  return ctx;
}
const I = (pays, langue, o) => charger(pays, langue, o).RPSovarkaInfobullesI18n;

// Descriptions réellement affichées : même fusion que l'écran (ordresDeclaresDeLaPiece : gabarit moins
// exclusions, plus ordres de la surcharge), hors pièces exclues. Corrigé le 13/11 (Héros du Travail) :
// l'ancien modèle laissait la surcharge remplacer le gabarit et sous-comptait 54 descriptions communes.
function descsParPays() {
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  const parPays = p => { const d = new Set();
    for (const city of Object.values(ctx.WORLD[p] || {})) for (const b of city.buildings || []) {
      const c = city.buildingContext?.[b] || {};
      for (const [r, room] of Object.entries({ ...(ctx.BUILDINGS[b]?.rooms || {}), ...(c.roomsExtra || {}) })) {
        if (c.roomsExclues?.includes(r)) continue;
        const ov = c.roomOverrides?.[r] || {};
        for (const o of [...ctx.ordresDeclaresDeLaPiece(room, c, r), ...(ov.ordersExtra || [])]) if (o?.desc) d.add(o.desc);
      } }
    return d; };
  return { sov: parPays('soviet'), rep: parPays('republic') };
}

test('inventaire : 254 descriptions communes affichées, aucune nouvelle hors catalogue, aucune en trop', () => {
  const { sov, rep } = descsParPays();
  const communesJeu = [...sov].filter(d => rep.has(d));
  const cat = [...I('republic', 'fr').communes].map(l => l[0]);
  // Mesuré le 13/11 avec la fusion réelle : 254 descriptions communes affichées, dont 54 pas encore au
  // catalogue (trou antérieur, chantier de traduction à venir, consigné dans RELAIS.md). Le plafond
  // empêche tout nouveau trou ; le baisser à mesure que ces textes sont traduits.
  assert.equal(communesJeu.length, 254, 'nombre de descriptions communes affichées');
  assert.ok(communesJeu.filter(d => !cat.includes(d)).length <= 54, 'nouvelles communes absentes du catalogue');
  // Français strictement identique : chaque texte du catalogue est une description exacte de data.js,
  // affichée dans au moins un pays (avec la fusion réelle, quelques-unes ne sont plus visibles qu'en Républia,
  // l'exclusion de Sovarka étant désormais prise en compte ; leur traduction y reste utile).
  assert.deepEqual(cat.filter(d => !sov.has(d) && !rep.has(d)), [], 'textes du catalogue introuvables tels quels');
  assert.equal(new Set(cat).size, cat.length);
});

test('205 lignes de neuf colonnes non vides, sans guillemet droit ni balise, toutes traduites', () => {
  const lignes = I('soviet', 'fr').communes;
  assert.equal(lignes.length, 205);
  for (const l of lignes) {
    assert.equal(l.length, 9, l[0]);
    for (const v of l) assert.ok(v.trim(), l[0]);
    for (const v of l.slice(1)) { assert.ok(!/["<>]/.test(v), v); assert.notEqual(v, l[0], 'non traduit : ' + l[0]); }
  }
});

test('nombres, pourcentages, devises et sigles conservés dans les huit traductions', () => {
  for (const l of I('soviet', 'fr').communes) {
    const nombres = l[0].match(/\d+(?:[  ]\d{3})*/g) || [];
    for (const v of l.slice(1)) {
      for (const n of nombres) assert.ok(v.includes(n), JSON.stringify(n) + ' manquant : ' + l[0] + ' → ' + v);
      assert.equal((v.match(/%/g) || []).length, (l[0].match(/%/g) || []).length, '% : ' + l[0] + ' → ' + v);
      for (const s of ['FR', 'PSK', 'POP', 'INF', 'DIS', 'IP', 'PER', 'CHA', 'DUP', 'ENT', 'MG', 'QHS', 'ISN', 'HP']) {
        const re = new RegExp('\\b' + s + '\\b', 'g');
        assert.equal((v.match(re) || []).length, (l[0].match(re) || []).length, s + ' : ' + l[0] + ' → ' + v);
      }
      for (const nom of ['Luthécia', 'Republia', 'La Tribune']) if (l[0].includes(nom)) assert.ok(v.includes(nom), nom + ' : ' + v);
    }
  }
});

test('traduit dans les deux pays, jamais en français, texte inconnu intact', () => {
  const fr = "Voir ce qui est disponible au bar et commander.";
  for (const pays of ['republic', 'soviet']) {
    assert.equal(I(pays, 'en').desc(fr), 'See what is available at the bar and order.');
    assert.equal(I(pays, 'fr').desc(fr), fr);
    assert.equal(I(pays, 'ru').desc('Texte inconnu'), 'Texte inconnu');
  }
  assert.match(I('republic', 'ar').desc(fr), /البار/);
  assert.match(I('soviet', 'zh-TW').desc(fr), /吧台/);
});

test('111 textes propres à Sovarka inchangés et prioritaires ; restent limités à Sovarka', () => {
  const avec = I('soviet', 'en'), sans = I('soviet', 'en', { communes: false });
  assert.equal(avec.lignes.length, 111);
  assert.equal(JSON.stringify(avec.lignes), JSON.stringify(sans.lignes));
  for (const l of avec.lignes) assert.equal(avec.desc(l[0]), sans.desc(l[0]));
  const propre = 'Voir les présidents qui ont marqué Sovarka.';
  assert.equal(I('republic', 'en').desc(propre), propre);
  // Aucun texte n'est à la fois propre à Sovarka et commun.
  const communs = new Set(avec.communes.map(l => l[0]));
  assert.equal([...avec.textes].filter(t => communs.has(t)).length, 0);
  // Sans le fichier des communes, le comportement d'avant est intact.
  assert.equal(sans.desc("Voir ce qui est disponible au bar et commander."), "Voir ce qui est disponible au bar et commander.");
  assert.equal(sans.communes.length, 0);
});

test('devise et tarif national : FR en Républia, PSK et tarif réappliqués en Sovarka', () => {
  const src = { desc: '75 FR. 2 PA. Transport intra-empire vers une autre ville.', cost: 75, pa: 2 };
  assert.equal(I('republic', 'en').descOrdre(src, { desc: src.desc }, 'FR', null), '75 FR. 2 AP. Intra-empire transport to another city.');
  const ctx = charger('soviet', 'de');
  const affiche = { desc: ctx.montantDansTexte(ctx.deviseDansTexte(src.desc, 'PSK'), 75, 40) };
  assert.equal(ctx.RPSovarkaInfobullesI18n.descOrdre(src, affiche, 'PSK', { cost: 40, pa: 2 }), '40 PSK. 2 AP. Transport innerhalb des Imperiums in eine andere Stadt.');
  assert.equal(I('soviet', 'fr').descOrdre(src, affiche, 'PSK', { cost: 40, pa: 2 }), affiche.desc);
});

test('infobulle complète et repeinte au changement de langue, en Républia, sans requête', () => {
  let langue = 'fr';
  const appels = [];
  const spec = { d: 'Voir ce qui est disponible au bar et commander.', a: 'Voir ce qui est disponible au bar et commander.', c: 0, p: 0, v: 'FR', n: null, g: [['+5', 'sante']], r: [], s: 100 };
  const badge = { textContent: '+5 Sante' };
  const b = { attrs: { 'data-rp-tip': encodeURIComponent(JSON.stringify(spec)), title: 'x' },
    getAttribute(n) { return this.attrs[n]; }, setAttribute(n, v) { appels.push(n); this.attrs[n] = v; }, querySelector: () => badge };
  const reseau = [];
  const ctx = charger('republic', 'fr', { extra: { document: { querySelectorAll: () => [b] }, RPPlateauI18n: { language: () => langue },
    fetch: (...a) => { reseau.push(a); return Promise.reject(Error('interdit')); } } });
  langue = 'es';
  for (const cb of ctx.RP_I18N_CHANGE_CALLBACKS) cb('es');
  assert.equal(b.attrs.title, 'Ver lo que hay disponible en la barra y pedir. | Ganancia: +5 Salud | Éxito: 100%');
  assert.equal(badge.textContent, '+5 Salud');
  assert.deepEqual([...new Set(appels)], ['title']);
  assert.deepEqual(reseau, []);
});

test('branchements : catalogue chargé avant le résolveur, audit éditorial, aucun changement de plateau-politique.js', () => {
  const html = lire('plateau.html');
  const a = html.indexOf('i18n/infobulles-communes-resources.js'), b = html.indexOf('i18n/sovarka-infobulles-resources.js'), c = html.indexOf('i18n/plateau-init.js');
  assert.ok(a > 0 && b > a && c > b);
  assert.ok(lire('outils/audits/audit-i18n-editorial.cjs').includes("'infobulles-communes-resources.js'"));
  const cat = lire('i18n/infobulles-communes-resources.js');
  assert.doesNotMatch(cat, /\bfunction\s*\(|=>|fetch\(|sbRpc|\bstate\.[a-z]/);
});
