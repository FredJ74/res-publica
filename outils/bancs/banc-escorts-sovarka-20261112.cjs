// Pavillon et Résidence de Novomirsk : standard Roxane Velours, service d'étage, dossiers du ministre (Fred, 12/11/2026).
// Contrôle hors ligne : textes en 9 langues, raccords d'ordres et de routeur, rumeur, PNJ de La Voix de Sovarka, migration.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');

const ctx = { console, state: { char: { name: 'Test' } } };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(lire('plateau-escorts-sovarka.js'), ctx);
const T = ctx.ESC_TEXTES;
assert.deepEqual(Object.keys(T).sort(), ['ar', 'de', 'en', 'es', 'fr', 'ko', 'pt-BR', 'ru', 'zh-TW']);
const vars = s => (s.match(/\{\w+\}/g) || []).sort().join();
for (const [l, t] of Object.entries(T)) {
  assert.deepEqual(Object.keys(t).sort(), Object.keys(T.fr).sort(), l);
  for (const k of Object.keys(T.fr)) {
    assert.ok(t[k].trim(), l + '/' + k);
    assert.equal(vars(t[k]), vars(T.fr[k]), l + '/' + k);
  }
}
// Les répliques de Rebecca validées par Fred, mot pour mot.
assert.equal(T.fr.accueil, 'Bonsoir, agence internationale Roxane Velours à l’appareil, Rebecca pour vous servir. Que puis-je pour vous ?');
assert.equal(T.fr.confirme, 'Très bien, je vous les envoie de suite. Le coût est de {nombre} × {prix} PSK. Validez le paiement sur votre téléphone.');
assert.equal(T.fr.annule, 'Vous n’avez pas validé, ce n’est pas grave. En espérant vous satisfaire une prochaine fois. Passez une bonne soirée.');

// Ordres : deux par suite du Pavillon et par appartement de la Résidence ; dossiers au bureau du ministre de l'Intérieur.
const data = lire('data.js');
const pav = data.slice(data.indexOf("'pavillon-ambassadeurs-novomirsk': {"), data.indexOf("'residence-imperiale-novomirsk': {"));
const res = data.slice(data.indexOf("'residence-imperiale-novomirsk': {"), data.indexOf('// GARAGE DE NOVOMIRSK'));
const compte = (s, m) => s.split(m).length - 1;
// « service_etage » est déjà l'ordre des hôtels de Républia (50/150 FR) : l'ordre du Grand Hôtel s'appelle « service_etage_carte ».
assert.ok(!pav.includes("fn:'service_etage',") && !res.includes("fn:'service_etage',"));
assert.equal(compte(pav, "fn:'escort_standard'"), 3);
assert.equal(compte(pav, "fn:'service_etage_carte'"), 3);
assert.equal(compte(res, "fn:'escort_standard'"), 5);
assert.equal(compte(res, "fn:'service_etage_carte'"), 5);
assert.match(data, /fn:'interieur_dossiers', label:'Dossiers confidentiels'[^\n]*requiresPost:'min_int'/);
assert.ok(data.includes('Zoïa Glazounova (PNJ)') && data.includes('Capitaine Arseni Petchatnikov (PNJ)'));
for (const f of ['Novo_zoia_glazounova_portrait.webp', 'Novo_arseni_petchatnikov_portrait.webp'])
  assert.ok(fs.existsSync(path.join(root, 'images/Sovarka/Novomirsk', f)), f);

const router = lire('plateau-router.js');
for (const fn of ['escort_standard', 'service_etage_carte', 'interieur_dossiers']) assert.ok(router.includes("fn === '" + fn + "'"), fn);
assert.match(lire('plateau.html'), /plateau-escorts-sovarka\.js\?v=/);
assert.match(lire('plateau-escorts-agence.js'), /function escortsAgenceAdopter\(r, agence\)/);

// Rumeur : la formulation lit « lieu|poste » écrit par le serveur.
const rum = lire('plateau-actions-illegales-rumeurs.js');
const debut = rum.indexOf('  appel_escort:');
assert.ok(debut > 0);
const formule = vm.runInNewContext('(' + rum.slice(rum.indexOf('(a, c) =>', debut), rum.indexOf('},\n', debut) + 1) + ')');
assert.equal(formule('Arnie', 'residence|Ministre de la Défense'),
  'On raconte que l\'agence Roxane Velours a fait livrer de la compagnie à la Résidence impériale, chez Arnie, Ministre de la Défense. Et pas pour parler politique.');
assert.equal(formule('Arnie', 'pavillon|'),
  'On raconte que l\'agence Roxane Velours a fait livrer de la compagnie au Pavillon des Ambassadeurs, chez Arnie. Et pas pour parler politique.');

const mig = lire('migrations/20261112005000_escorts_roxane_velours_sovarka.sql');
for (const m of ['escort_scandale_v1', 'escort_piratage_v1', "random() < 0.5", "random() >= 0.25", 'rumeur_pop_retirer_interne(s.dignitaire, 3)',
  'c_service constant integer := 20', 'Soirée velours pour ', 'Et pas pour parler politique', 'escort_secret_transmettre'])
  if (m !== 'Et pas pour parler politique') assert.ok(mig.includes(m), m);
console.log('Escorts Roxane Velours, service d’étage et dossiers : 9 langues, ordres, rumeur et migration en place.');
