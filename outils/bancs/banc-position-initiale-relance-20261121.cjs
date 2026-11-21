#!/usr/bin/env node
// Banc de l'incident du 21/11/2026 (nouveau joueur à Novomirsk, vue de rue vide, aucun déplacement possible).
// Exerce le vrai corps d'initialiserRueCentrale et le vrai contrôle de contexte, sans réseau ni écriture serveur :
// la fiche du personnage est remplacée pendant la lecture de position, comme à la création d'un personnage.
// Avant le correctif, l'initialisation s'arrêtait en silence et aucune scène n'était jamais affichée.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync('plateau-rue-centrale.js', 'utf8');
function tranche(debutTexte, finTexte) {
  const d = source.indexOf(debutTexte), f = source.indexOf(finTexte, d);
  assert.ok(d >= 0 && f > d, 'Tranche introuvable : ' + debutTexte);
  return source.slice(d, f);
}
const code = tranche('function contexteNavigationRue()', '\nlet rueCentraleNoeudActuel')
  + '\n' + tranche('async function initialiserRueCentrale(', '\nasync function afficherNoeudRue(');
const departs = { republic: { capitale: 'luthecia-palais-presidentiel' }, soviet: { capitale: 'novomirsk-vue-1', ville_b: 'krasnov-rue-gare' } };

async function scenario({ remplacerFiche, sceneDejaLa }) {
  const appels = [], toasts = [];
  let scene = !!sceneDejaLa, lectures = 0;
  const etat = { char: { name: 'Peter' }, country: 'soviet', currentCity: 'capitale', currentBuilding: null, currentRoom: null };
  const contexte = {
    state: etat, rueCentraleLecturePosition: 0, rueCentraleDeplacementEnCours: null, setTimeout, Promise,
    WORLD: { soviet: { capitale: {} } }, BUILDINGS: {},
    rueCentraleServeur: () => true,
    sbRpc: async (fn) => {
      assert.equal(fn, 'rue_position_lire');
      lectures++;
      // Création du personnage : la fiche est rechargée (nouvel objet, même nom) pendant la première lecture.
      if (remplacerFiche && lectures === 1) etat.char = { name: 'Peter' };
      return { ok: true, country: 'soviet', city: 'capitale', building: null, street: null };
    },
    RUE_CENTRALE_DEPART: departs,
    RUE_CENTRALE_NOEUDS: { soviet: { 'novomirsk-vue-1': {} } },
    afficherNoeudRue: async (...args) => { appels.push(args); scene = true; },
    showToast: (t, c) => toasts.push(t + ' : ' + c),
    document: { getElementById: id => id === 'rue-centrale-conteneur' ? {} : (id === 'rc-scene' && scene ? {} : null) }
  };
  vm.createContext(contexte);
  vm.runInContext(code + '\nthis.initialiserRueCentrale = initialiserRueCentrale;', contexte);
  await contexte.initialiserRueCentrale('soviet', 'novomirsk-vue-1', null);
  return { appels, toasts, lectures };
}

(async () => {
  // 1. Fiche rechargée pendant la lecture : la relance affiche quand même la première rue.
  let r = await scenario({ remplacerFiche: true });
  assert.equal(r.appels.length, 1, 'aucune scène affichée après rechargement de la fiche (vue de rue vide)');
  assert.deepEqual(r.appels[0].slice(0, 3), ['soviet', 'novomirsk-vue-1', null]);
  assert.equal(r.lectures, 2, 'une seule relance attendue');
  assert.deepEqual(r.toasts, []);
  // 2. Cas normal : une seule lecture, une seule scène, aucune relance.
  r = await scenario({ remplacerFiche: false });
  assert.equal(r.appels.length, 1);
  assert.equal(r.lectures, 1, 'relance inutile quand la scène est affichée');
  // 3. Le correctif ne déplace jamais un personnage dont la scène est déjà affichée.
  r = await scenario({ remplacerFiche: true, sceneDejaLa: true });
  assert.equal(r.appels.length, 0);
  assert.equal(r.lectures, 1);
  // 4. Filet de sécurité (Fred, 21/11) : la rue reste vide malgré les relances → message clair, « Réessayer »
  //    sans recharger la page, incident journalisé ; « Réessayer » relance l'affichage et la rue apparaît.
  {
    const rpc = [], etat = { char: { name: 'Peter' }, country: 'soviet', currentCity: 'capitale', currentBuilding: null, currentRoom: null };
    let scene = false, panneHtml = '', bouton = null, echouer = true;
    const conteneur = { set innerHTML(h) { panneHtml = h; bouton = /rc-panne-reessayer/.test(h) ? { disabled: false, onclick: null } : null; }, get innerHTML() { return panneHtml; } };
    const ctx = {
      state: etat, rueCentraleLecturePosition: 0, rueCentraleDeplacementEnCours: null, setTimeout, Promise,
      WORLD: { soviet: { capitale: {} } }, BUILDINGS: {}, rueCentraleServeur: () => true,
      sbRpc: async (fn, p) => {
        rpc.push(fn);
        if (fn === 'incident_client_noter') { rpc.push(JSON.stringify(p)); return { ok: true }; }
        if (echouer) etat.char = { name: 'Peter' };          // la fiche change à chaque lecture : abandon à chaque fois
        return { ok: true, country: 'soviet', city: 'capitale', building: null, street: null };
      },
      RUE_CENTRALE_DEPART: departs, RUE_CENTRALE_NOEUDS: { soviet: { 'novomirsk-vue-1': {} } },
      afficherNoeudRue: async () => { scene = true; }, showToast: () => {},
      document: { getElementById: id => id === 'rue-centrale-conteneur' ? conteneur : id === 'rc-scene' ? (scene ? {} : null) : id === 'rc-panne-reessayer' ? bouton : null }
    };
    vm.createContext(ctx);
    vm.runInContext(code + '\nthis.initialiserRueCentrale = initialiserRueCentrale;', ctx);
    await ctx.initialiserRueCentrale('soviet', 'novomirsk-vue-1', null);
    assert.equal(scene, false);
    assert.match(panneHtml, /La ville se charge encore…/, 'jamais de vue vide et muette');
    assert.match(panneHtml, /Réessayer/);
    assert.equal(rpc.filter(f => f === 'incident_client_noter').length, 1, 'incident journalisé une fois');
    assert.match(rpc[rpc.indexOf('incident_client_noter') + 1], /"p_type":"rue_vide"/);
    assert.equal(rpc.filter(f => f === 'rue_position_lire').length, 3, 'première lecture + deux relances');
    echouer = false;
    bouton.onclick();
    await new Promise(r => setTimeout(r, 50));
    assert.equal(scene, true, '« Réessayer » affiche la rue sans recharger la page');
  }
  console.log('OK : la première rue s’affiche même si la fiche est rechargée pendant la lecture de position ; sinon message et « Réessayer ».');
})().catch(e => { console.error(e); process.exitCode = 1; });
