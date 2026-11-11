'use strict';
// Sovarka, justice et provinces (11/11/2026) : catalogues en neuf langues, interface traduite,
// données des joueurs et répliques du serveur intactes, réaffichage sans nouvel appel serveur.
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
const MODULES = {
  justice: { cat: 'i18n/sovarka-justice-resources.js', ecran: 'plateau-sovarka-justice.js', api: 'RPSovarkaJusticeI18n' },
  provinces: { cat: 'i18n/sovarka-provinces-resources.js', ecran: 'plateau-sovarka-provinces.js', api: 'RPSovarkaProvincesI18n' }
};
const REPONSES = {
  sovarka_justice_registre: { ok: true, ministre: true, jour: 5, commissaire_ville: 'capitale', juge_ville: 'capitale', affaires: [
    { id: 'a1', cible: 'Boris Kozlov', ville: 'capitale', statut: 'au_parquet', plaignant: 'Olga Brejneva', jour: 3, motif: 'Vol de « samovar »', peut_decider: true, consigne: 'severe' },
    { id: 'a3', cible: 'Piotr', ville: 'ville_b', statut: 'saisie', jour: 1, audience_jour: 9, motif: 'Fraude', consigne: 'relaxe' }] },
  sovarka_bons_etat_lire: { ok: true, jour: { taux: -3.5, indice: 50 }, bons: [{ montant: 100, taux: 2, statut: 'rembourse', rembourse: 102, planche_a_billets: true }] },
  sovarka_maison_lire: { ok: true, habitant: 'Dolgor Tsybikova', service: { label: '2 viandes' }, bouteille: false }
};

function jeu(nom, langue) {
  const m = MODULES[nom];
  const els = {};
  const el = id => els[id] || (els[id] = { id, textContent: '', innerHTML: '', value: '', classList: { s: new Set(), add(c) { this.s.add(c); }, remove(c) { this.s.delete(c); }, contains(c) { return this.s.has(c); } } });
  const appels = [];
  const ctx = {
    console, JSON, Number, Object, Array, Date, Promise, langue,
    RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => ctx.langue },
    state: { country: 'soviet', currentCity: 'capitale', char: { name: 'Ivan' } },
    document: {
      getElementById: el,
      querySelector: s => s === '#postes-body [data-sov-fenetre]' && el('postes-body').innerHTML.includes('data-sov-fenetre') ? {} : null,
      querySelectorAll: () => []
    },
    vehModal(t, h) { el('postes-modal-title').textContent = t; el('postes-body').innerHTML = h; el('modal-postes').classList.add('open'); },
    vehSection: (t, c) => '<section><b>' + t + '</b>' + c + '</section>',
    vehBouton: (l, js) => '<button onclick="' + js + '">' + l + '</button>',
    vehChamp: id => '<input id="' + id + '">',
    showToast() {}, addJournalEntry() {},
    sbRpcVerdict: async fn => { appels.push(fn); return JSON.parse(JSON.stringify(REPONSES[fn] || { ok: false })); }
  };
  vm.createContext(ctx);
  ctx.window = ctx;
  vm.runInContext(lire('i18n/sovarka-droits-resources.js'), ctx);
  vm.runInContext(lire(m.cat), ctx);
  // La fenêtre commune de Sovarka (marqueur et réaffichage) vient du module des droits.
  vm.runInContext(lire('plateau-sovarka-droits.js'), ctx);
  vm.runInContext(lire(m.ecran), ctx);
  return { ctx, el, appels };
}

for (const [nom, m] of Object.entries(MODULES)) {
  test(nom + ' : neuf langues, mêmes clés, mêmes variables et mêmes balises', () => {
    const { ctx } = jeu(nom, 'fr');
    const t = ctx[m.api];
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
    // Le catalogue source ne doit oublier aucune clé dans une langue (sinon le repli français masquerait le manque).
    const src = lire(m.cat);
    const blocs = src.split(/\n  "(?:[a-zA-Z-]+)": \{\n/).slice(1);
    assert.equal(blocs.length, 9);
    for (const b of blocs) assert.equal((b.match(/^    "\w+":/gm) || []).length, t.cles.length);
  });
}

test('justice en arabe : interface traduite, noms et motifs des joueurs intacts', async () => {
  const j = jeu('justice', 'ar');
  await j.ctx.ouvrirSovarkaRegistrePlaintes();
  const html = j.el('postes-body').innerHTML;
  assert.equal(j.el('postes-modal-title').textContent, 'القضايا القضائية في سوفاركا');
  for (const s of ['Boris Kozlov', 'Olga Brejneva', 'Vol de « samovar »', 'Krasnov', "justiceSovDecider('a1','saisir')"]) assert.ok(html.includes(s), s);
  assert.ok(!html.includes('Pas de procureur'), 'reste en français');
});

test('provinces en allemand : bons d’État et maison traduits, répliques du serveur intactes', async () => {
  const j = jeu('provinces', 'de');
  await j.ctx.ouvrirBonsEtat();
  assert.equal(j.el('postes-modal-title').textContent, 'Staatsanleihen von Sowarka');
  assert.ok(j.el('postes-body').innerHTML.includes('zurückgezahlt 102 PSK (Notenpresse)'));
  await j.ctx.ouvrirMaisonHabitant();
  const html = j.el('postes-body').innerHTML;
  assert.equal(j.el('postes-modal-title').textContent, 'Dolgor Tsybikova');
  assert.ok(html.includes('2 viandes') && html.includes("agirMaisonHabitant('service')"), 'objet du serveur et commande intacts');
});

test('changement de langue : registre et bons réaffichés sans nouvel appel serveur', async () => {
  for (const [nom, ouvrir, attendu] of [['justice', 'ouvrirSovarkaRegistrePlaintes', 'Судебные дела Соварки'], ['provinces', 'ouvrirBonsEtat', 'Государственные облигации Соварки']]) {
    const j = jeu(nom, 'fr');
    await j.ctx[ouvrir]();
    const avant = j.appels.length;
    j.ctx.langue = 'ru';
    await j.ctx.sovarkaRerendreFenetre();
    assert.equal(j.appels.length, avant, nom + ' : aucune nouvelle lecture');
    assert.equal(j.el('postes-modal-title').textContent, attendu);
  }
});

test('modules raccordés et catalogues chargés par le jeu et l’audit éditorial', () => {
  const html = lire('plateau.html');
  const audit = lire('outils/audits/audit-i18n-editorial.cjs');
  for (const m of Object.values(MODULES)) {
    assert.match(html, new RegExp(m.cat.replace(/[./]/g, '\\$&') + '\\?v='));
    assert.ok(audit.includes(path.basename(m.cat)));
  }
  const justice = lire(MODULES.justice.ecran), provinces = lire(MODULES.provinces.ecran);
  for (const s of ["'Registre des plaintes'", 'Pas de procureur en Sovarka', "'Offrir un café'", 'JUSTICE_SOV_MOTIFS']) assert.ok(!justice.includes(s), s);
  for (const s of ["'Bons d’État de Sovarka'", 'Soutenez l’économie', "'Rencontre en forêt profonde'", "'Na zdorovie !'"]) assert.ok(!provinces.includes(s), s);
  assert.ok(provinces.includes("provActe('sovarka_bon_etat_souscrire'") && justice.includes("sbRpcVerdict('sovarka_offrir_cafe'"), 'appels serveur inchangés');
});
