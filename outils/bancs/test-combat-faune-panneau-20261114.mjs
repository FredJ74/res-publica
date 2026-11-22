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
    ['libelleLieuCombat', 'libelleAdversaireDebout', 'rpConclusionFaune', 'dernierRoundDetaille', 'libelleIssueCombat', 'verrouillerCommandesCombat', 'avecVerrouCombat', 'journaliserFinCombat'])
    + '\nconst combatsJournalises = new Set();', c);
  c.journal = []; c.addJournalEntry = (t, cls) => c.journal.push([t, cls]); c.escapeHtmlText = t => String(t);
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
  assert.match(faune('fuite'), /ni peau ni viande/);
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

test("l'issue d'un combat contre une bête va au journal, une seule fois, avec le butin", () => {
  const c = contexte();
  const b = { id: 7, statut: 'terminee', type: 'faune', adversaire_nom: 'Ours', resultat: 'tues', issue: 'victoire_acteur', mon_camp: 'acteur',
    lieu: { ville: 'ville_b', batiment: 'zone-production', piece: 'foret_vue_3' },
    butin: [{ nom: 'Tissus et peaux', qte: 10 }, { nom: 'Viande', qte: 9 }, { nom: 'Bois', qte: 4 }, { nom: "Dent d'ours", qte: 2 }] };
  c.journaliserFinCombat(b); c.journaliserFinCombat(b);
  assert.equal(c.journal.length, 1);
  assert.equal(c.journal[0][1], 'event-good');
  assert.match(c.journal[0][0], /^Forêt profonde — Le ravin noir · Krasnov : Ours est abattu\. Victoire\. Butin : Tissus et peaux ×10, Viande ×9, Bois ×4, Dent d'ours ×2\.$/);
  c.journaliserFinCombat({ ...b, id: 8, resultat: 'fuite', butin: [{ nom: 'Bois', qte: 2 }] });
  assert.match(c.journal[1][0], /s’enfuit.*Butin : Bois ×2\./);
  assert.equal(c.journal[1][1], 'event-bad');
  c.journaliserFinCombat({ ...b, id: 9, statut: 'en_cours' });
  assert.equal(c.journal.length, 2);
});

test('seul un ordre du joueur écrit au journal, pas la relecture d’un rapport', () => {
  const src = lire('plateau-politique.js');
  assert.match(src, /await ouvrirPanneauCombat\(batailleId, \{ journaliser: true \}\);/);
  assert.match(src, /if \(fini && options\?\.journaliser\) journaliserFinCombat\(b\);/);
  const mig = lire('migrations/20261114153000_foret_combat_journal.sql');
  const fn = mig.slice(mig.indexOf('CREATE OR REPLACE FUNCTION public.sovarka_foret_issue_combat_interne'), mig.indexOf('REVOKE ALL'));
  assert.doesNotMatch(fn, /mail_systeme_poser_interne/);
});
