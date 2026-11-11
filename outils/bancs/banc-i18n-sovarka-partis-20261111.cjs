'use strict';
// Sovarka, partis (11/11/2026) : catalogue en neuf langues, interface traduite, noms et programmes
// des partis intacts, réaffichage au changement de langue sans nouvel appel serveur.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const variables = s => [...s.matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
const balises = s => (s.match(/<\/?b>/g) || []).join('');
const LISTE = { ok: true, partis: [{ id: 1, nom: 'Parti des Précurseurs Politiques', chef: 'Olga Brejneva', siege: 'capitale', desc: 'Le tracteur <avant> tout', membres: 3, pop: 7, prix: 15 }],
  mon_parti: { id: 1, nom: 'Parti des Précurseurs Politiques', chef: 'Ivan', siege: 'ville_a', pop: 7, prix: 15, caisse: 40, est_chef: true, peut_designer_pm: false,
    membres: [{ nom: 'Ivan', grade: 'Chef' }, { nom: 'Piotr', grade: 'Membre' }], demandes: [{ nom: 'Sacha' }] } };

function jeu(langue) {
  const els = {};
  const el = id => els[id] || (els[id] = { id, textContent: '', innerHTML: '', value: '', classList: { s: new Set(), add(c) { this.s.add(c); }, remove(c) { this.s.delete(c); }, contains(c) { return this.s.has(c); } } });
  const appels = [];
  const ctx = {
    console, JSON, Number, Object, Array, Promise, langue,
    RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => ctx.langue },
    state: { country: 'soviet', currentCity: 'capitale', currentRoom: 'salle_partis', char: { name: 'Ivan' } },
    document: { getElementById: el, querySelector: s => s === '#postes-body [data-sov-fenetre]' && el('postes-body').innerHTML.includes('data-sov-fenetre') ? {} : null, querySelectorAll: () => [] },
    vehModal(t, h) { el('postes-modal-title').textContent = t; el('postes-body').innerHTML = h; el('modal-postes').classList.add('open'); },
    vehSection: (t, c) => '<section><b>' + t + '</b>' + c + '</section>',
    vehBouton: (l, js) => '<button onclick="' + js + '">' + l + '</button>',
    showToast() {}, ouvrirEcranPostes() { appels.push('postes'); },
    sbRpcVerdict: async fn => { appels.push(fn); return JSON.parse(JSON.stringify(LISTE)); }
  };
  vm.createContext(ctx);
  ctx.window = ctx;
  for (const f of ['i18n/sovarka-droits-resources.js', 'i18n/sovarka-partis-resources.js', 'plateau-sovarka-droits.js', 'plateau-sovarka-partis.js']) vm.runInContext(lire(f), ctx);
  return { ctx, el, appels };
}

test('neuf langues, mêmes clés, mêmes variables et mêmes balises', () => {
  const { ctx } = jeu('fr');
  const t = ctx.RPSovarkaPartisI18n;
  assert.deepEqual([...t.langues], LANGUES);
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
  const blocs = lire('i18n/sovarka-partis-resources.js').split(/\n  "(?:[a-zA-Z-]+)": \{\n/).slice(1);
  assert.equal(blocs.length, 9);
  for (const b of blocs) assert.equal((b.match(/^    "\w+":/gm) || []).length, t.cles.length);
});

test('coréen : Mon parti traduit, nom du parti (PPP), programme et grades intacts', async () => {
  const j = jeu('ko');
  await j.ctx.ouvrirSovarkaMonParti();
  const html = j.el('postes-body').innerHTML;
  assert.equal(j.el('postes-modal-title').textContent, '나의 정당');
  for (const s of ['Parti des Précurseurs Politiques', 'Chef', 'Membre', 'Sacha', 'Starovka', "partiRepondre(0,true)"]) assert.ok(html.includes(s), s);
  await j.ctx.sovarkaPostuler();
  assert.ok(j.el('postes-body').innerHTML.includes('Le tracteur &lt;avant&gt; tout') || j.appels.includes('postes'));
});

test('changement de langue : Mon parti réaffiché sans nouvel appel serveur', async () => {
  const j = jeu('fr');
  await j.ctx.ouvrirSovarkaMonParti();
  const avant = j.appels.length;
  j.ctx.langue = 'pt-BR';
  await j.ctx.sovarkaRerendreFenetre();
  assert.equal(j.appels.length, avant);
  assert.equal(j.el('postes-modal-title').textContent, 'Meu partido');
});

test('module raccordé, catalogue chargé par le jeu, le banc mobile et l’audit éditorial', () => {
  const ecran = lire('plateau-sovarka-partis.js');
  for (const s of ["'Salle des partis'", "'Mon parti'", 'PARTI_MOTIFS', 'Vous ne pouvez pas obtenir un poste']) assert.ok(!ecran.includes(s), s);
  assert.ok(ecran.includes("sbRpcVerdict('sovarka_parti_commande'"), 'appel serveur inchangé');
  assert.match(lire('plateau.html'), /i18n\/sovarka-partis-resources\.js\?v=/);
  assert.match(lire('outils/bancs/banc-mobile-sovarka.cjs'), /i18n\/sovarka-partis-resources\.js/);
  assert.ok(lire('outils/audits/audit-i18n-editorial.cjs').includes('sovarka-partis-resources.js'));
});
