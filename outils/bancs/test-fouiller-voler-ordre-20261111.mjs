// Actions de pièce. Historique : « Fouiller ou voler » (Fred, 11/11/2026), un seul ordre vert à menu. Lot de Krasnov,
// point 9 (Fred, 20/11/2026 ; codé le 22/11/2026) : il devient « Inspecter la pièce » (1 PA, caméras + personnes cachées),
// à côté de « Se cacher » (retiré de la fiche personnelle) et de « Désinstaller du matériel » ; « Voler quelqu'un » en sort.
// Regroupement (Fred, 22/11/2026, soir, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 17) : « Inspecter la pièce » ouvre
// une fenêtre à trois volets (installé / fouiller / désinstaller) ; le bouton « Désinstaller du matériel » disparaît.
// 23/11/2026 (mission Novomirsk) : ouvrir la fenêtre coûte 0 PA, la fouille 1 PA, « Voler (2 PA) » affiche son coût.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const racine = new URL('../../', import.meta.url);
const lire = f => fs.readFileSync(new URL(f, racine), 'utf8');

function charger() {
  const ctx = { window: {}, state: {}, console };
  vm.createContext(ctx);
  vm.runInContext(lire('i18n/equipements-resources.js'), ctx);
  ctx.texteEquip = ctx.window.texteEquip;
  vm.runInContext(lire('plateau-surveillance.js'), ctx);
  return ctx;
}

test('pièce : deux ordres verts en bas de liste — Inspecter la pièce (fenêtre à trois volets), Se cacher ; plus de « Désinstaller du matériel »', () => {
  const ctx = charger();
  assert.ok(ctx.window.RP_ORDRES_DYNAMIQUES.includes(ctx.ordresFouillerVoler));
  const o = ctx.ordresFouillerVoler('bureaux', 'bureau_1');
  assert.equal(JSON.stringify(o.map(x => x.fn)), JSON.stringify(['inspecter_piece', 'se_cacher']));
  assert.equal(JSON.stringify(o.map(x => x.label)), JSON.stringify(['Inspecter la pièce', 'Se cacher']));
  assert.ok(o.every(x => x.type === 'legal' && x.basDeListe === true));
  // Ouvrir la fenêtre ne coûte rien (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md) ; la fouille garde 1 PA.
  assert.equal(o[0].pa, 0, 'ouvrir « Inspecter la pièce » : 0 PA');
  assert.match(lire('plateau-surveillance.js'), /const TARIF_FOUILLE = \{ fn: 'inspecter_piece', label: 'Fouiller les lieux', pa: 1, cost: 0 \};/);
  assert.equal(ctx.ordresFouillerVoler(null, null).length, 0);
  // Rue : « Inspecter les lieux », caméras seulement, au même endroit.
  assert.match(ctx.ordreFouillerVolerRueHtml(), /class="action-btn legal" data-fn="inspecter_piece" onclick="ouvrirFenetreInspecter\(\)"/);
  const s = lire('plateau-surveillance.js');
  assert.doesNotMatch(s, /crimVolerChoisirCible|crimOuvrirCambriolage|ouvrirFouilleCachettes/, 'plus de vol de personne ni d’« Emporter » ni de débusquage séparé');
  assert.match(s, /surveillanceRpc\('inspecter_piece', \{\}\)/);
  assert.match(s, /surveillanceRpc\('desinstaller_lire', \{\}\)/);
  assert.match(s, /surveillanceRpc\('desinstaller_materiel', \{ p_requete: requete, p_id: id \}\)/);
  assert.match(s, /crimCambrioler\('materiel', id\)/, '« Voler » : les règles existantes du vol de matériel');
});

test('la liste des ordres met les ordres basDeListe à la fin ; la rue ajoute le bouton en dernier', () => {
  assert.match(lire('plateau-politique.js'), /\.concat\(dynOrders\.filter\(d => !d\.basDeListe\)\)\s*\n[^\n]*\n\s*\.concat\(dynOrders\.filter\(d => d\.basDeListe\)\)/);
  assert.match(lire('plateau-navigation.js'), /: ''\)\s*\n[^\n]*\n\s*\+ \(typeof ordreFouillerVolerRueHtml === 'function' \? ordreFouillerVolerRueHtml\(\) : ''\);/);
});

test('routeur : sortie avant tout débit ; « Se cacher » n’est plus dans la fiche personnelle', () => {
  const routeur = lire('plateau-router.js');
  for (const fn of ['inspecter_piece', 'desinstaller_materiel', 'fouiller_voler']) {
    const i = routeur.indexOf("fn === '" + fn + "'");
    assert.ok(i > 0 && i < routeur.indexOf("fn === 'camion_militaire'"), fn);
  }
  assert.match(routeur, /if \(fn === 'se_cacher'\)\s+\{ doSeCacher\(\); return; \}/);
  assert.doesNotMatch(lire('plateau-personnage.js'), /doOrder\(\\'se_cacher\\'/);
});

test('fenêtre d’inspection : trois volets ; « Voler » en face du matériel d’autrui ; « Désinstaller » seulement pour le légal', async () => {
  const ctx = charger();
  const html = []; const toasts = [];
  const corps = { querySelectorAll: () => [] };
  ctx.equipementsModale = (t, h) => { html.push([t, h]); return corps; };
  ctx.document = { querySelectorAll: () => [], getElementById: () => null };
  ctx.showToast = (t, m, ok) => toasts.push([t, m, ok]);
  ctx.state = { currentBuilding: 'bureaux', currentRoom: 'bureau_1' };
  ctx.sbRpc = async (fn) => {
    if (fn === 'desinstaller_lire') return { ok: true, chez_soi: false, pa: 1, materiel: [
      { id: 'e1', nom: 'Ordinateur de Tom', legal: false, a_moi: false, volable: true, ferme_a_cle: false },
      { id: 'e2', nom: 'Box à moi', legal: true, a_moi: true, volable: false, ferme_a_cle: false }] };
    return { ok: false, raison: 'x' };
  };
  vm.runInContext('globalThis.sbRpc = sbRpc; globalThis.state = state;', ctx);
  await ctx.ouvrirFenetreInspecter('installe');
  let [titre, h] = html.pop();
  assert.equal(titre, 'Inspecter la pièce');
  for (const v of ['Ce qui est installé ici', 'Fouiller les lieux', 'Désinstaller']) assert.ok(h.includes('>' + v + '</button>'), v);
  assert.match(h, /Ordinateur de Tom <span class="cpj-note">\(à quelqu’un d’autre\)<\/span><\/span><button type="button" class="cpj-touche" data-voler="e1">Voler \(2 PA\)<\/button>/, '« Voler (2 PA) » : coût affiché (23/11/2026)');
  assert.doesNotMatch(h, /data-voler="e2"/, 'pas de « Voler » pour son propre matériel');
  assert.doesNotMatch(h, /data-desinstaller/, 'pas de désinstallation dans le premier volet');
  ctx.inspectionOnglet('desinstaller');
  [, h] = html.pop();
  assert.match(h, /vous ne pouvez désinstaller que votre propre matériel/);
  assert.match(h, /data-desinstaller="e2" disabled title="Il faut 2 PA\."/);
  assert.doesNotMatch(h, /data-desinstaller="e1"/, 'le matériel d’autrui hors de chez soi ne se désinstalle pas');
  ctx.inspectionOnglet('fouiller');
  [, h] = html.pop();
  assert.match(h, /onclick="inspecterConfirmer\(\)">Fouiller \(1 PA\)/);
});
