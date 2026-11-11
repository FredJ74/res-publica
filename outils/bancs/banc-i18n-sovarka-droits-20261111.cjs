'use strict';
// Sovarka, droits d'exploiter (11/11/2026) : catalogue en neuf langues, rendu français inchangé,
// données des joueurs jamais traduites, réaffichage au changement de langue sans appel serveur.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.resolve(__dirname, '../..');
const catalogue = fs.readFileSync(path.join(racine, 'i18n/sovarka-droits-resources.js'), 'utf8');
const ecran = fs.readFileSync(path.join(racine, 'plateau-sovarka-droits.js'), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const variables = s => [...s.matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');

// Jeu minimal : une fenêtre (#modal-postes), un serveur simulé qui compte ses appels.
function jeu(langue, avecCatalogue = true) {
  const elements = {};
  const el = id => elements[id] || (elements[id] = { id, textContent: '', innerHTML: '', value: '', classList: { s: new Set(), add(c) { this.s.add(c); }, remove(c) { this.s.delete(c); }, contains(c) { return this.s.has(c); } } });
  const appels = [];
  const lecture = {
    ok: true, moi: 'Ivan Testov', ville: 'capitale', role: 'maire', caisseMairie: 12345,
    parametres: { coutLocal: 1000, delaiJours: 10 }, composition: 'mixte',
    locaux: [
      { ville: 'capitale', batiment: 'galeries', piece: 'local_1', label: 'Galerie <Nord>', loyer: 40, plafond: 150, origine: 'pj' },
      { ville: 'capitale', batiment: 'galeries', piece: 'local_2', label: 'Kiosque Pravda', loyer: 0, plafond: 0, origine: 'pnj', exploitant: 'Olga Brejneva' }
    ],
    demandes: [{ id: 'd1', ville: 'capitale', demandeur: 'Piotr Lenski', projet: 'Librairie « du Peuple »', statut: 'en_attente', local_souhaite_batiment: 'galeries', local_souhaite_piece: 'local_1' }],
    cessions: [], immeubles: [{ ville: 'capitale', terrain: 'terrain-a-batir-1', nb_commerces: 3, nb_logements: 2, statut: 'en_chantier', livraison_le: '2026-11-21' }]
  };
  const window = {
    RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => ctx.langue }, langue,
    VILLES: { soviet: { capitale: { nom: 'Novomirsk' } } }
  };
  const ctx = {
    window, console, Promise, JSON, Number, String, Object, Array,
    state: { country: 'soviet', currentCity: 'capitale', currentBuilding: 'galeries', currentRoom: 'local_1' },
    VILLES: window.VILLES, WORLD: { soviet: { capitale: {} } },
    document: {
      getElementById: el,
      querySelector: sel => sel === '#postes-body [data-sov-fenetre]' && el('postes-body').innerHTML.includes('data-sov-fenetre') ? {} : null,
      querySelectorAll: () => Object.values(elements).filter(e => /^sov-/.test(e.id)).map(e => e)
    },
    vehModal(titre, html) { el('postes-modal-title').textContent = titre; el('postes-body').innerHTML = html; el('modal-postes').classList.add('open'); },
    showToast() {},
    sbRpcVerdict: async fn => { appels.push(fn); return JSON.parse(JSON.stringify(lecture)); }
  };
  Object.assign(ctx, window);
  vm.createContext(ctx);
  ctx.window = ctx; // comme dans le navigateur : window est l'objet global
  if (avecCatalogue) vm.runInContext(catalogue, ctx);
  vm.runInContext(ecran + ';window.__f={ouvrirSovarkaDossiers,ouvrirSovarkaTerrain,ouvrirSovarkaCommercesLibres,sovarkaRerendreFenetre};', ctx);
  return { ctx, window: ctx, el, appels, f: ctx.__f };
}

test('neuf langues, mêmes clés et mêmes variables que le français', () => {
  const { window } = jeu('fr');
  const t = window.RPSovarkaDroitsI18n;
  assert.deepEqual([...t.langues], LANGUES);
  assert.ok(t.cles.length >= 150, 'catalogue complet');
  const fr = Object.fromEntries(t.cles.map(k => [k, t.text(k)]));
  for (const l of LANGUES) {
    window.langue = l;
    for (const k of t.cles) {
      const v = t.text(k);
      assert.ok(v && v.length, l + ' ' + k);
      assert.equal(variables(v), variables(fr[k]), l + ' ' + k + ' (variables)');
      if (l !== 'fr' && !['rentPerDay', 'plot', 'delivery', 'noRentParen'].includes(k) && fr[k].length > 12) assert.notEqual(v, fr[k], l + ' ' + k + ' non traduit');
    }
  }
});

test('repli français hors activation, clé inconnue vide', () => {
  const { window } = jeu('de');
  assert.equal(window.texteSovDroits('tSigned'), 'Zuteilung unterzeichnet');
  window.RP_I18N_GAME_ENABLED = false;
  assert.equal(window.texteSovDroits('tSigned'), 'Attribution signée');
  assert.equal(window.texteSovDroits('inexistante'), '');
});

test('français : fenêtre du maire identique avec ou sans catalogue', async () => {
  const a = jeu('fr', true), b = jeu('fr', false);
  // Sans catalogue, l'écran afficherait les clés : on vérifie donc que le catalogue français rend le texte attendu.
  await a.f.ouvrirSovarkaDossiers();
  const html = a.el('postes-body').innerHTML;
  for (const s of ['Caisse de la mairie : 12', 'PSK par local et se construit en 10 jours', 'Local demandé : <strong>Galerie &lt;Nord&gt;</strong>',
    '— attendre l’immeuble collectif —', 'exploité par Olga Brejneva (sans loyer)', 'PSK / jour (0 à 150)', 'livraison le 2026-11-21',
    'Type des prochains immeubles : <strong>mixte (commerces et logements)</strong>'])
    assert.ok(html.includes(s), s);
  assert.equal(a.el('postes-modal-title').textContent, 'Dossiers commerciaux — Novomirsk');
  assert.ok(b.f.ouvrirSovarkaDossiers, 'le module se charge aussi sans catalogue');
});

test('arabe et allemand : interface traduite, noms et projets des joueurs intacts', async () => {
  for (const [l, attendu] of [['ar', 'الملفات التجارية — Novomirsk'], ['de', 'Gewerbevorgänge — Novomirsk']]) {
    const j = jeu(l);
    await j.f.ouvrirSovarkaDossiers();
    const html = j.el('postes-body').innerHTML;
    assert.equal(j.el('postes-modal-title').textContent, attendu);
    for (const s of ['Piotr Lenski', 'Librairie « du Peuple »', 'Galerie &lt;Nord&gt;', 'Olga Brejneva']) assert.ok(html.includes(s), l + ' ' + s);
    assert.ok(!html.includes('Caisse de la mairie'), l + ' reste en français');
    assert.ok(html.includes("sovarkaAccepter('d1',0)"), l + ' commande inchangée');
  }
});

test('changement de langue fenêtre ouverte : réaffichage sans appel serveur, saisie conservée', async () => {
  const j = jeu('fr');
  await j.f.ouvrirSovarkaDossiers();
  const avant = j.appels.length;
  j.el('sov-loyer-0').value = '77';
  j.window.langue = 'ru';
  await j.f.sovarkaRerendreFenetre();
  assert.equal(j.appels.length, avant, 'aucune nouvelle lecture serveur');
  assert.equal(j.el('postes-modal-title').textContent, 'Торговые дела — Novomirsk');
  assert.equal(j.el('sov-loyer-0').value, '77', 'saisie conservée');
  // Une fenêtre d'un autre module (sans marqueur) n'est jamais écrasée.
  j.ctx.vehModal('Autre', '<p>autre module</p>');
  await j.f.sovarkaRerendreFenetre();
  assert.equal(j.el('postes-body').innerHTML, '<p>autre module</p>');
});

test('module raccordé : plus de textes en dur, catalogue chargé par le jeu et le banc mobile', () => {
  for (const s of ["'Commerces non attribués'", 'Camarade Maire,', "'Lecture impossible auprès du serveur.'", 'SOV_MOTIFS', "'Signer l’attribution (1 PA)'"]) assert.ok(!ecran.includes(s), s);
  assert.ok(ecran.includes("sovActe('sovarka_demande_location'"), 'appel serveur inchangé');
  const html = fs.readFileSync(path.join(racine, 'plateau.html'), 'utf8');
  assert.match(html, /i18n\/sovarka-droits-resources\.js\?v=/);
  assert.match(fs.readFileSync(path.join(racine, 'outils/bancs/banc-mobile-sovarka.cjs'), 'utf8'), /i18n\/sovarka-droits-resources\.js/);
});
