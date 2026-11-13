// Infobulles des ordres propres à Sovarka, cadre de l'infobulle et salon de coiffure (13/11/2026).
// Neuf langues, français strictement identique, montants et sigles conservés, bascule sans requête.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const R = new URL('../../', import.meta.url);
const lire = f => readFileSync(new URL(f, R), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
// Témoin : plateau-salon.js de main au commit 517a425, avant ce chantier.
const TEMOIN_SALON = 'outils/bancs/fixtures/salon-coiffure-temoin-517a425.js';
const fnSource = (src, nom) => { const i = src.indexOf('function ' + nom + '('); const j = src.indexOf('\n}', i); return src.slice(i, j + 2); };

function charger(pays, langue, extra = {}) {
  const ctx = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => langue }, ...extra };
  ctx.window = ctx; vm.createContext(ctx);
  // `state` est un let global du jeu : déclaré dans le contexte comme dans le navigateur.
  vm.runInContext('var state = { country: ' + JSON.stringify(pays) + ' };', ctx);
  vm.runInContext(fnSource(lire('plateau-politique.js'), 'deviseDansTexte'), ctx);
  vm.runInContext(fnSource(lire('data.js'), 'montantDansTexte'), ctx);
  vm.runInContext(lire('i18n/sovarka-infobulles-resources.js'), ctx);
  return ctx;
}
const I = (pays, langue) => charger(pays, langue).RPSovarkaInfobullesI18n;

// Mêmes règles que l'audit du 12/11 : ordres des pièces (gabarit, roomsExtra, overrides), hors pièces exclues.
function ordresParPays() {
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  const parPays = p => { const descs = new Set(), bientot = new Set();
    for (const city of Object.values(ctx.WORLD[p] || {})) for (const b of city.buildings || []) {
      const c = city.buildingContext?.[b] || {};
      for (const [r, room] of Object.entries({ ...(ctx.BUILDINGS[b]?.rooms || {}), ...(c.roomsExtra || {}) })) {
        if (c.roomsExclues?.includes(r)) continue;
        const ov = c.roomOverrides?.[r] || {};
        for (const o of [...(ov.orders || room?.orders || []), ...(ov.ordersExtra || [])]) {
          if (o?.desc) descs.add(o.desc);
          if (typeof o?.bientot === 'string') bientot.add(o.bientot);
        }
      } }
    return { descs, bientot }; };
  const sov = parPays('soviet'), rep = parPays('republic');
  return { descs: [...sov.descs].filter(d => !rep.descs.has(d)), bientot: [...sov.bientot].filter(d => !rep.bientot.has(d)) };
}

test('104 lignes de neuf colonnes non vides, sans guillemet droit ni balise', () => {
  const lignes = I('soviet', 'fr').lignes;
  assert.equal(lignes.length, 104);
  for (const l of lignes) {
    assert.equal(l.length, 9, l[0]);
    for (const v of l) assert.ok(v.trim(), l[0]);
    // Le texte part dans title="…" sans échappement : pas de " ni de < > dans les traductions.
    for (const v of l.slice(1)) assert.ok(!/["<>]/.test(v), v);
  }
});

test('toute description et mention « Bientôt » propre à Sovarka affichée par le jeu est au catalogue', () => {
  const textes = new Set(I('soviet', 'en').textes);
  const { descs, bientot } = ordresParPays();
  assert.ok(descs.length >= 100);
  assert.deepEqual(descs.filter(d => !textes.has(d)), []);
  assert.deepEqual(bientot.filter(d => !textes.has(d)), []);
});

test('nombres, montants et sigles conservés dans les huit traductions', () => {
  for (const l of I('soviet', 'fr').lignes) {
    const nombres = l[0].match(/\d+(?:[  ]\d{3})*/g) || [];
    for (const v of l.slice(1)) {
      for (const n of nombres) assert.ok(v.includes(n), JSON.stringify(n) + ' manquant : ' + l[0] + ' → ' + v);
      for (const s of ['PSK', 'FR', 'POP', 'INF', 'DIS', 'IP']) {
        const re = new RegExp('\\b' + s + '\\b', 'g');
        assert.equal((v.match(re) || []).length, (l[0].match(re) || []).length, s + ' : ' + l[0] + ' → ' + v);
      }
    }
  }
});

test('traduit en Sovarka seulement, jamais en français, texte inconnu intact', () => {
  const fr = 'Voir les présidents qui ont marqué Sovarka.';
  assert.equal(I('soviet', 'en').desc(fr), 'See the presidents who left their mark on Sovarka.');
  assert.equal(I('republic', 'en').desc(fr), fr);
  assert.equal(I('soviet', 'fr').desc(fr), fr);
  assert.equal(I('soviet', 'ru').desc('Texte inconnu'), 'Texte inconnu');
  assert.match(I('soviet', 'ar').desc(fr), /Sovarka/);
});

test('devise et tarif national appliqués après traduction, comme à l’écran', () => {
  const src = { desc: '75 FR. 2 PA. Vers une autre ville de Sovarka.', cost: 75, pa: 2 };
  const ctx = charger('soviet', 'de');
  const affiche = { desc: ctx.montantDansTexte(ctx.deviseDansTexte(src.desc, 'PSK'), 75, 40) };
  assert.equal(ctx.RPSovarkaInfobullesI18n.descOrdre(src, affiche, 'PSK', { cost: 40, pa: 2 }), '40 PSK. 2 AP. In eine andere Stadt von Sovarka.');
  // En français : exactement la description déjà transformée.
  assert.equal(I('soviet', 'fr').descOrdre(src, affiche, 'PSK', { cost: 40, pa: 2 }), affiche.desc);
  // Description inconnue (gabarit commun) : rendue telle quelle dans toutes les langues.
  const commun = { desc: 'Repas complet. +10 Sante.', cost: 20, pa: 1 };
  for (const l of LANGUES) assert.equal(I('soviet', l).descOrdre(commun, { desc: 'X' }, 'PSK', null), 'X');
});

test('infobulle et badge : en français, chaîne identique à l’ancienne construction', () => {
  const ancienne = (desc, g, r, rate) => { const p = []; if (desc) p.push(desc); if (g) p.push('Gain: ' + g); if (r) p.push('Risque: ' + r); p.push('Reussite: ' + rate + '%'); return p.join(' | '); };
  const nom = { sante: 'Sante', moral: 'Moral' };
  const cas = [
    { d: '', a: '', g: [], r: [], s: 70 },
    { d: 'Repas economique. +5 Sante.', a: 'Repas economique. +5 Sante.', g: [['+5', 'sante']], r: [], s: 100 },
    { d: '+5 IP +3 POP.', a: '+5 IP +3 POP.', g: [['+5', 'sante'], ['+2', 'moral'], ['+3', 'INF'], ['+4', 'POP'], ['+100', 'PSK']], r: [['-2', 'DIS'], ['-1', 'POP']], s: 45 },
    { d: 'Le gabarit "commun".', a: 'Le gabarit "commun".', g: [], r: [['-3', 'DIS']], s: 60 }
  ];
  for (const pays of ['soviet', 'republic']) for (const c of cas) {
    const i = I(pays, 'fr');
    const g = c.g.map(e => e[0] + ' ' + (nom[e[1]] || e[1])).join(' · '), r = c.r.map(e => e[0] + ' ' + e[1]).join(' · ');
    assert.equal(i.gains(c.g), g);
    assert.equal(i.infobulle({ ...c, c: 0, p: 1, v: pays === 'soviet' ? 'PSK' : 'FR', n: null }), ancienne(c.a, g, r, c.s));
  }
  const en = I('soviet', 'en').infobulle({ d: 'Repas economique. +5 Sante.', a: 'Repas economique. +5 Sante.', c: 0, p: 1, v: 'PSK', n: null, g: [['+5', 'sante']], r: [['-1', 'DIS']], s: 100 });
  assert.equal(en, 'Budget meal. +5 Health. | Gain: +5 Health | Risk: -1 DIS | Success: 100%');
  assert.match(I('republic', 'ar').gains([['+2', 'moral']]), /معنويات/);
});

test('bascule de langue : titre et badge repeints depuis le descripteur, sans autre effet', () => {
  let langue = 'fr';
  const appels = [];
  const badge = { textContent: '+5 Sante' };
  const spec = { d: 'Repas economique. +5 Sante.', a: 'Repas economique. +5 Sante.', c: 0, p: 1, v: 'PSK', n: null, g: [['+5', 'sante']], r: [], s: 100 };
  const bouton = (p, titre) => ({ attrs: { 'data-rp-tip': encodeURIComponent(JSON.stringify(p)), title: titre },
    getAttribute(n) { return this.attrs[n]; }, setAttribute(n, v) { appels.push(n); this.attrs[n] = v; }, querySelector: () => badge });
  const b1 = bouton(spec, 'x'), b2 = bouton({ k: 'bientot', t: 'Bientôt disponible : les médicaments de la pharmacie seront définis prochainement.' }, 'y');
  const ctx = charger('soviet', 'fr', { document: { querySelectorAll: () => [b1, b2] }, RPPlateauI18n: { language: () => langue } });
  langue = 'ko';
  for (const cb of ctx.RP_I18N_CHANGE_CALLBACKS) cb('ko');
  assert.equal(b1.attrs.title, '알뜰 식사. 건강 +5. | 이득: +5 건강 | 성공률: 100%');
  assert.equal(badge.textContent, '+5 건강');
  assert.match(b2.attrs.title, /약국/);
  assert.deepEqual([...new Set(appels)], ['title']);
});

test('salon : français du catalogue identique aux textes d’origine, variables identiques', () => {
  const src = lire(TEMOIN_SALON).replace(/' \+\s*\n\s*'/g, '');
  const S = I('soviet', 'fr').salons;
  for (const [cle, l] of Object.entries(S)) {
    assert.equal(l.length, 9, cle);
    const vars = l[0].match(/\{[a-z]+\}/g) || [];
    for (const v of l) { assert.ok(v.trim(), cle); assert.deepEqual((v.match(/\{[a-z]+\}/g) || []).sort(), [...vars].sort(), cle + ' ' + v); }
    // Le français est soit littéral dans l'ancien fichier, soit reconstitué autour d'une variable.
    for (const morceau of l[0].split(/\{[a-z]+\}/).map(x => x.trim()).filter(x => x.length > 1)) assert.ok(src.includes(morceau), cle + ' : ' + morceau);
  }
  assert.equal(I('soviet', 'ru').salon('couper', 'x', { prix: '20', devise: 'PSK' }), 'Подстричься — 20 PSK');
  assert.equal(I('republic', 'fr').salon('prochaine', ' Prochaine coupe possible dans {n} jour(s).', { n: 2 }), ' Prochaine coupe possible dans 2 jour(s).');
});

// Exécute l'ancien et le nouveau plateau-salon.js avec la même réponse serveur et compare le rendu.
function rendreSalon(source, langue, l, verdict) {
  const traces = { rpc: [], modal: null, toasts: [], session: [] };
  const elts = { 'modal-postes': { classList: { contains: () => true, remove() {}, add() {} } }, 'postes-body': { querySelector: () => ({}) } };
  const ctx = {
    RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => langue }, COUNTRIES: { soviet: { cur: 'PSK' } },
    sbRpcVerdict: async (nom, args) => { traces.rpc.push(nom); return nom === 'salon_lire' ? l : verdict; },
    showToast: (t, m, ok) => traces.toasts.push([t, m, ok]), vehModal: (t, h) => { traces.modal = [t, h]; },
    document: { getElementById: id => elts[id] || null }, crypto: { randomUUID: () => 'uuid' },
    sessionStorage: { getItem: () => null, setItem: k => traces.session.push(k), removeItem() {} },
    appliquerPaiementServeur() {}, adopterJaugeServeur() {}, updateHeader() {}
  };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext('var state = { country: "soviet", char: { name: "Arnie" } };', ctx);
  vm.runInContext(lire('i18n/sovarka-infobulles-resources.js'), ctx);
  vm.runInContext(source, ctx);
  return { ctx, traces };
}
test('salon : rendu français identique à main, traduit ailleurs, bascule sans requête', async () => {
  const ancien = lire(TEMOIN_SALON);
  const nouveau = lire('plateau-salon.js');
  const lectures = [
    { ok: true, salon: { id: 'salon-novo', prixCoupe: 20 }, jour: 10, prochaineCoupeJour: null },
    { ok: true, salon: { id: 'salon-novo', prixCoupe: 20 }, jour: 10, prochaineCoupeJour: 12 },
    { ok: true, salon: { id: 'salon-novo', prixCoupe: null }, jour: 10, prochaineCoupeJour: null },
    { ok: true, salon: null }, { ok: false }
  ];
  for (const l of lectures) {
    const a = rendreSalon(ancien, 'fr', l), n = rendreSalon(nouveau, 'fr', l);
    await vm.runInContext('ouvrirSalonCoupe()', a.ctx); await vm.runInContext('ouvrirSalonCoupe()', n.ctx);
    assert.deepEqual(n.traces.toasts, a.traces.toasts);
    if (a.traces.modal) {
      assert.equal(n.traces.modal[0], a.traces.modal[0]);
      assert.equal(n.traces.modal[1].replace(' data-salon-i18n="coupe"', ''), a.traces.modal[1]);
    } else assert.equal(n.traces.modal, null);
  }
  for (const v of [{ ok: false, raison: 'fonds_insuffisants' }, { ok: false, raison: 'autre' }, null, { ok: true, pa: 1, bonusCha: true }, { ok: true, pa: 1 }]) {
    const a = rendreSalon(ancien, 'fr', lectures[0], v), n = rendreSalon(nouveau, 'fr', lectures[0], v);
    await vm.runInContext('salonCouper("salon-novo")', a.ctx); await vm.runInContext('salonCouper("salon-novo")', n.ctx);
    assert.deepEqual(n.traces.toasts, a.traces.toasts);
  }
  // Arabe puis bascule en russe : repeint depuis le cache, aucune requête de plus, aucune coupe.
  let langue = 'ar';
  const n = rendreSalon(nouveau, 'ar', lectures[1]);
  n.ctx.RPPlateauI18n.language = () => langue;
  await vm.runInContext('ouvrirSalonCoupe()', n.ctx);
  assert.match(n.traces.modal[0], /صالون/);
  assert.match(n.traces.modal[1], /بعد 2 يوم/);
  langue = 'ru';
  for (const cb of n.ctx.RP_I18N_CHANGE_CALLBACKS) cb('ru');
  assert.equal(n.traces.modal[0], 'Парикмахерская');
  assert.match(n.traces.modal[1], /через 2 дн\./);
  assert.deepEqual(n.traces.rpc, ['salon_lire']);
  assert.deepEqual(n.traces.session, []);
});

test('branchements : catalogue chargé, infobulle et descripteur posés, « Bientôt » décidé par o.bientot', () => {
  const html = lire('plateau.html');
  const a = html.indexOf('i18n/sovarka-infobulles-resources.js'), b = html.indexOf('i18n/plateau-init.js');
  assert.ok(a > 0 && b > a);
  const pol = lire('plateau-politique.js');
  assert.match(pol, /infobulleI18n\.infobulle\(tipSpec\)/);
  assert.match(pol, /data-rp-tip="/);
  assert.match(pol, /if \(o\.bientot\) needsBientot = true;/);
  // Le texte passé à doOrder reste la description française d'origine.
  assert.match(pol, /const safeDesc = \(o\.desc\|\|''\)/);
  assert.ok(lire('outils/audits/audit-i18n-editorial.cjs').includes("'sovarka-infobulles-resources.js'"));
});
