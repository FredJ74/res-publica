// Panneau de combat contre une bête (14/11/2026) : aucune clé technique, un seul round par clic,
// images des rencontres préchargées. Complète le banc SQL banc-combat-faune-20261114.sql.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let acorn;
try { acorn = require('acorn'); } catch { acorn = require('../vercel/node_modules/acorn'); }
const racine = new URL('../../', import.meta.url);
const lire = f => fs.readFileSync(new URL(f, racine), 'utf8');

function fonctions(fichier, noms) {
  const src = lire(fichier);
  const ast = acorn.parse(src, { ecmaVersion: 'latest' });
  return noms.map(n => {
    const d = ast.body.find(x => x.type === 'FunctionDeclaration' && x.id.name === n);
    assert.ok(d, n + ' introuvable dans ' + fichier);
    return src.slice(d.start, d.end);
  }).join('\n');
}

function contexte() {
  const c = {
    state: { country: 'soviet' },
    BUILDINGS: { 'zone-production': { name: 'Exploitation forestière de Krasnov', rooms: { foret_vue_3: { name: 'Forêt profonde — Le ravin noir' } } } },
    WORLD: { soviet: { ville_b: { name: 'Krasnov' } } },
  };
  vm.createContext(c);
  vm.runInContext('let commandeCombatEnCours=false;\n' + fonctions('plateau-politique.js',
    ['libelleLieuCombat', 'libelleAdversaireDebout', 'libelleIssueCombat', 'verrouillerCommandesCombat', 'avecVerrouCombat']), c);
  return c;
}

test('le lieu du combat est nommé, jamais par ses clés', () => {
  const c = contexte();
  const l = c.libelleLieuCombat({ ville: 'ville_b', batiment: 'zone-production', piece: 'foret_vue_3' });
  assert.equal(l, 'Forêt profonde — Le ravin noir · Krasnov');
  assert.doesNotMatch(c.libelleLieuCombat({ ville: 'ville_x', batiment: 'inconnu', piece: 'p' }), /ville_x|inconnu/);
});

test('la bête est nommée au lieu de « soldats »', () => {
  const c = contexte();
  const b = { adversaire_nom: 'Ours' };
  assert.equal(c.libelleAdversaireDebout(b, { adversaire_estime: { libelle: '1 à 2 soldats', effectif_min: 1, effectif_max: 2 } }), 'Ours');
  assert.equal(c.libelleAdversaireDebout(b, { adversaire_estime: { libelle: 'plus aucun adversaire debout' } }), 'plus aucun adversaire debout');
  assert.equal(c.libelleAdversaireDebout({}, { adversaire_estime: { libelle: '3 à 5 soldats' } }), '3 à 5 soldats');
});

test("l'issue est une phrase, jamais une clé comme victoire_acteur", () => {
  const c = contexte();
  const faune = r => c.libelleIssueCombat({ type: 'faune', adversaire_nom: 'Ours', resultat: r, issue: 'victoire_acteur', mon_camp: 'acteur' });
  assert.match(faune('tues'), /Ours est abattu/);
  assert.match(faune('fuite'), /s’enfuit/);
  assert.match(faune('fuite'), /Pas de butin/);
  assert.match(faune('defaite'), /hors de combat/);
  assert.equal(c.libelleIssueCombat({ issue: 'victoire_acteur', mon_camp: 'acteur' }), 'Victoire.');
  assert.equal(c.libelleIssueCombat({ issue: 'victoire_defenseur', mon_camp: 'acteur' }), 'Défaite.');
  for (const b of [{ issue: 'victoire_acteur', mon_camp: 'acteur' }, { issue: 'aneantissement_mutuel' }, {}])
    assert.doesNotMatch(c.libelleIssueCombat(b), /_/);
});

test('un clic répété pendant un round ne joue pas un second round', async () => {
  const c = contexte();
  let appels = 0, liberer;
  const lent = () => new Promise(r => { appels++; liberer = r; });
  const p1 = c.avecVerrouCombat(lent);
  await c.avecVerrouCombat(lent);
  await c.avecVerrouCombat(lent);
  assert.equal(appels, 1);
  liberer(); await p1;
  await c.avecVerrouCombat(async () => { appels++; });
  assert.equal(appels, 2);
});

test('poursuivre et décider passent par le verrou', () => {
  const src = lire('plateau-politique.js');
  assert.match(src, /async function poursuivreCombat\(batailleId\) \{ return avecVerrouCombat\(/);
  assert.match(src, /async function deciderCombat\(batailleId, decision\) \{ return avecVerrouCombat\(/);
  assert.doesNotMatch(src, /'Issue : ' \+ escapeHtmlText\(b\.issue\)/);
  assert.doesNotMatch(src, /escapeHtmlText\(b\.lieu\?\.ville/);
});

test('les images des rencontres sont préchargées pendant la coupe et en forêt profonde', () => {
  const src = lire('plateau-sovarka-provinces.js');
  assert.match(src, /function foretPrechargerImages\(\)/);
  assert.match(src, /async function foretCouper\(\) \{\n  foretPrechargerImages\(\);/);
  assert.match(src, /if \(Number\(v\.vue\) > 0\) foretPrechargerImages\(\);/);
  const c = { PROV_FORET_IMAGES: { cf_ours: 'Krasnov_foret_ours_attaque.webp', olga: 'Krasnov_foret_olga_panier.webp' }, charges: [] };
  c.Image = function () { return new Proxy({}, { set: (o, k, v) => { if (k === 'src') c.charges.push(v); o[k] = v; return true; } }); };
  vm.createContext(c);
  vm.runInContext('let foretImagesPrechargees=false;\n' + fonctions('plateau-sovarka-provinces.js', ['foretPrechargerImages']) + '\nforetPrechargerImages();foretPrechargerImages();', c);
  assert.deepEqual(c.charges, ['images/Sovarka/Krasnov/Krasnov_foret_ours_attaque.webp', 'images/Sovarka/Krasnov/Krasnov_foret_olga_panier.webp']);
  for (const f of c.charges) assert.ok(fs.existsSync(new URL(f, racine)), f);
});
