// Actions de pièce. Historique : « Fouiller ou voler » (Fred, 11/11/2026), un seul ordre vert à menu. Lot de Krasnov,
// point 9 (Fred, 20/11/2026 ; codé le 22/11/2026) : il devient « Inspecter la pièce » (1 PA, caméras + personnes cachées),
// à côté de « Se cacher » (retiré de la fiche personnelle) et de « Désinstaller du matériel » ; « Voler quelqu'un » en sort.
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

test('pièce : trois ordres verts en bas de liste — Inspecter (1 PA), Se cacher, Désinstaller ; plus de menu « Fouiller ou voler »', () => {
  const ctx = charger();
  assert.ok(ctx.window.RP_ORDRES_DYNAMIQUES.includes(ctx.ordresFouillerVoler));
  const o = ctx.ordresFouillerVoler('bureaux', 'bureau_1');
  assert.equal(JSON.stringify(o.map(x => x.fn)), JSON.stringify(['inspecter_piece', 'se_cacher', 'desinstaller_materiel']));
  assert.equal(JSON.stringify(o.map(x => x.label)), JSON.stringify(['Inspecter la pièce', 'Se cacher', 'Désinstaller du matériel']));
  assert.ok(o.every(x => x.type === 'legal' && x.basDeListe === true));
  assert.equal(o[0].pa, 1);
  assert.equal(ctx.ordresFouillerVoler(null, null).length, 0);
  // Rue : « Inspecter les lieux », caméras seulement, au même endroit.
  assert.match(ctx.ordreFouillerVolerRueHtml(), /class="action-btn legal" data-fn="inspecter_piece" onclick="ouvrirFenetreInspecter\(\)"/);
  const s = lire('plateau-surveillance.js');
  assert.doesNotMatch(s, /crimVolerChoisirCible|crimOuvrirCambriolage|ouvrirFouilleCachettes/, 'plus de vol de personne ni d’« Emporter » ni de débusquage séparé');
  assert.match(s, /surveillanceRpc\('inspecter_piece', \{\}\)/);
  assert.match(s, /surveillanceRpc\('desinstaller_lire', \{\}\)/);
  assert.match(s, /surveillanceRpc\('desinstaller_materiel', \{ p_requete: requete, p_id: id \}\)/);
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

test('fenêtre de désinstallation : légal ou vol annoncé avant, bouton grisé avec la raison, objet au sol rafraîchi', async () => {
  const ctx = charger();
  const html = []; const appels = []; const toasts = [];
  ctx.equipementsModale = (t, h) => { html.push([t, h]); return {}; };
  ctx.document = { querySelectorAll: () => [], getElementById: () => null };
  ctx.showToast = (t, m, ok) => toasts.push([t, m, ok]);
  ctx.sbRpc = async (fn, p) => {
    appels.push(fn);
    if (fn === 'desinstaller_lire') return { ok: true, chez_soi: false, pa: 1, materiel: [{ id: 'e1', nom: 'Ordinateur', legal: false, a_moi: false, ferme_a_cle: false }] };
    return { ok: false, raison: 'x' };
  };
  vm.runInContext('globalThis.sbRpc = sbRpc;', ctx);
  await ctx.ouvrirDesinstaller();
  const [titre, h] = html.pop();
  assert.equal(titre, 'Désinstaller du matériel');
  assert.match(h, /démonter le matériel des autres est un vol/);
  assert.match(h, /disabled title="Il faut 2 PA\."/);
  assert.match(h, /se ramasse sans PA/);
});
