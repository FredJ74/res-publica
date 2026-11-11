'use strict';
// Sovarka, pouvoir (11/11/2026) : catalogue en neuf langues (Soviet Suprême, repas et musée présidentiels,
// lois, séance, fiscalité, saisine, sondages, fuite, signalements, conscription, autocritique, surveillance) ;
// titres de lois et noms intacts ; réaffichage au changement de langue sans nouvel appel serveur.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const variables = s => [...s.matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
const balises = s => (s.match(/<\/?strong>/g) || []).join('');
const POUVOIR = { ok: true, pm: true, depute: true, jeudi: true, emarge: true, postes: ['min_def'], conscription: { active: false },
  lois: [{ id: 'l1', statut: 'adoptee', titre: 'Loi sur le Tractorisme <obligatoire>' }],
  ordre_du_jour: [{ id: 'o1', titre: 'Loi sur le Tractorisme <obligatoire>', parti_nom: 'Parti des Précurseurs Politiques', approbations: 4, abstentions: 1 }] };
const SOVIET = { ok: true, scores: [{ partiId: 1, nom: 'Parti des Précurseurs Politiques', adherentsPJ: 3, partisansPNJ: 9 }], sieges: { 1: 9 }, deputes: { 1: ['Olga Brejneva'] }, vainqueur: 'Parti des Précurseurs Politiques' };

function jeu(langue) {
  const els = {};
  const el = id => els[id] || (els[id] = { id, textContent: '', innerHTML: '', value: '', classList: { s: new Set(), add(c) { this.s.add(c); }, remove(c) { this.s.delete(c); }, contains(c) { return this.s.has(c); } } });
  const appels = [];
  const ctx = {
    console, JSON, Number, Object, Array, Date, Set, Math, Promise, langue,
    RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => ctx.langue },
    state: { country: 'soviet', currentCity: 'capitale', char: { name: 'Ivan' } },
    crypto: { randomUUID: () => 'u' },
    document: { getElementById: el, querySelector: s => s === '#postes-body [data-sov-fenetre]' && el('postes-body').innerHTML.includes('data-sov-fenetre') ? {} : null, querySelectorAll: () => [] },
    vehModal(t, h) { el('postes-modal-title').textContent = t; el('postes-body').innerHTML = h; el('modal-postes').classList.add('open'); },
    vehSection: (t, c) => '<section><b>' + t + '</b>' + c + '</section>',
    vehBouton: (l, js) => '<button onclick="' + js + '">' + l + '</button>',
    showToast(t, m) { appels.push('toast:' + t + ':' + m); },
    sbRpcVerdict: async (fn, p) => { appels.push(fn); return JSON.parse(JSON.stringify(fn === 'sovarka_soviet_etat' ? SOVIET : fn === 'sovarka_pouvoir_commande' ? { ok: true, appeles: 6 } : POUVOIR)); }
  };
  vm.createContext(ctx);
  ctx.window = ctx;
  for (const f of ['i18n/sovarka-droits-resources.js', 'i18n/sovarka-pouvoir-resources.js', 'plateau-sovarka-droits.js', 'plateau-sovarka-pouvoir.js']) vm.runInContext(lire(f), ctx);
  return { ctx, el, appels };
}

test('neuf langues, mêmes clés, mêmes variables et mêmes balises', () => {
  const { ctx } = jeu('fr');
  const t = ctx.RPSovarkaPouvoirI18n;
  assert.deepEqual([...t.langues], LANGUES);
  assert.ok(t.cles.length >= 180);
  const fr = Object.fromEntries(t.cles.map(k => [k, t.text(k)]));
  for (const l of LANGUES) {
    ctx.langue = l;
    for (const k of t.cles) {
      const v = t.text(k);
      assert.ok(v && v.length, l + ' ' + k);
      assert.equal(variables(v), variables(fr[k]), l + ' ' + k + ' (variables)');
      assert.equal(balises(v), balises(fr[k]), l + ' ' + k + ' (balises)');
    }
  }
  const blocs = lire('i18n/sovarka-pouvoir-resources.js').split(/\n  "(?:[a-zA-Z-]+)": \{\n/).slice(1);
  assert.equal(blocs.length, 9);
  for (const b of blocs) assert.equal((b.match(/^    "\w+":/gm) || []).length, t.cles.length);
});

test('chinois : Soviet Suprême traduit, nom du PPP et des députés intacts', async () => {
  const j = jeu('zh-TW');
  await j.ctx.ouvrirSovietSupreme();
  const html = j.el('postes-body').innerHTML;
  assert.equal(j.el('postes-modal-title').textContent, '最高蘇維埃');
  for (const s of ['Parti des Précurseurs Politiques', 'Olga Brejneva', '9 席']) assert.ok(html.includes(s), s);
});

test('allemand : séance du jeudi traduite, titre de loi échappé et intact, commandes inchangées', async () => {
  const j = jeu('de');
  await j.ctx.ouvrirSovarkaSeance();
  const html = j.el('postes-body').innerHTML;
  assert.equal(j.el('postes-modal-title').textContent, 'Sitzung des Volksrates');
  assert.ok(html.includes('Loi sur le Tractorisme &lt;obligatoire&gt;'));
  assert.ok(html.includes('(Parti des Précurseurs Politiques · 4 Billigung(en), 1 Enthaltung(en))'));
  assert.ok(html.includes("sovarkaApprouver(&quot;o1&quot;,'APPROUVE')"));
});

test('conscription : bouton raccordé à une fonction, même action serveur, notification traduite', async () => {
  const j = jeu('es');
  await j.ctx.ouvrirSovarkaConscription();
  assert.ok(j.el('postes-body').innerHTML.includes('onclick="sovarkaConscriptionDecreter()"'));
  await j.ctx.sovarkaConscriptionDecreter();
  assert.ok(j.appels.includes('toast:Reclutamiento obligatorio:6 ciudadano(s) llamado(s) a filas.'));
});

test('changement de langue : séance réaffichée sans nouvel appel serveur', async () => {
  const j = jeu('fr');
  await j.ctx.ouvrirSovarkaSeance();
  const avant = j.appels.length;
  j.ctx.langue = 'ar';
  await j.ctx.sovarkaRerendreFenetre();
  assert.equal(j.appels.length, avant);
  assert.equal(j.el('postes-modal-title').textContent, 'جلسة مجلس الشعب');
});

test('module raccordé, catalogue chargé par le jeu, le banc mobile et l’audit éditorial', () => {
  const ecran = lire('plateau-sovarka-pouvoir.js');
  for (const s of ['SOVIET_MOTIFS', 'SOV_POUVOIR_MOTIFS', "'Séance du Conseil du Peuple'", "'Placer sous surveillance'", "'Conscription en vigueur.'"]) assert.ok(!ecran.includes(s), s);
  assert.ok(ecran.includes("sbRpcVerdict('sovarka_pouvoir_commande'") && ecran.includes("sovPouvoirActe('conscription_declencher'"), 'actions serveur inchangées');
  assert.match(lire('plateau.html'), /i18n\/sovarka-pouvoir-resources\.js\?v=/);
  assert.match(lire('outils/bancs/banc-mobile-sovarka.cjs'), /i18n\/sovarka-pouvoir-resources\.js/);
  assert.ok(lire('outils/audits/audit-i18n-editorial.cjs').includes('sovarka-pouvoir-resources.js'));
});
