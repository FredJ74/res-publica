// GARDE (04/11/2026) : le navigateur ne déplace plus d'argent vers ou depuis un autre personnage,
// ni ne se paie lui-même par `state.arg -=` dans les restes portés au serveur ce jour-là.
// `arg` est un total calculé (20261104013000) : toute écriture de `arg` par l'écran est soit
// neutralisée en silence, soit un mensonge affiché. Les crédits et débits passent par la fonction
// serveur de l'acte (argent_crediter_interne / argent_debiter_interne).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const fichiers = fs.readdirSync('.').filter(f => /\.js$/.test(f));
const sans = s => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:'"\\])\/\/.*$/gm, '$1');

test('aucune écriture de `arg` sur la vue personnages depuis l’écran', () => {
  for (const f of fichiers) {
    const c = sans(fs.readFileSync(f, 'utf8'));
    assert.doesNotMatch(c, /sbUpdate(Verdict)?\(\s*'personnages'[^)]*\{\s*arg\s*:/, f + ' écrit encore arg');
  }
});

test('les anciens écrivains de solde ont disparu', () => {
  const tout = fichiers.map(f => sans(fs.readFileSync(f, 'utf8'))).join('\n');
  for (const nom of ['sbEcrireSoldePersonnage', 'sbAppliquerSalaire', 'sbAppliquerRachatEntreprise',
                     'sbResoudrePari', 'debiterCitoyenPlafonne', 'ajusterSoldeCibleFiscale', 'getSoldeCibleFiscale']) {
    assert.doesNotMatch(tout, new RegExp('\\b' + nom + '\\s*\\('), nom + ' est encore défini ou appelé');
  }
});

function corps(fichier, nom) {
  const src = fs.readFileSync(fichier, 'utf8');
  const i = src.search(new RegExp('(async\\s+)?function\\s+' + nom + '\\s*\\('));
  assert.ok(i >= 0, nom + ' introuvable');
  let k = src.indexOf('{', i), p = 0;
  for (let j = k; j < src.length; j++) { if (src[j] === '{') p++; else if (src[j] === '}' && --p === 0) return sans(src.slice(i, j + 1)); }
  throw new Error('corps non fermé : ' + nom);
}

test('paie des employés, don aux squatteurs, don religieux : une porte serveur, aucun débit local', () => {
  const cas = [['plateau-multijoueur.js', 'payerEmployes', 'employes_payer_jour'],
               ['plateau-justice-economie.js', 'confirmerDonArgent', 'terrain_squatteurs_don'],
               ['plateau-divers.js', 'doFaireDon', null]];
  for (const [f, nom, rpc] of cas) {
    const c = corps(f, nom);
    assert.doesNotMatch(c, /state\.(arg|pop|inf)\s*(\+=|-=|=[^=])/, nom + ' modifie encore une jauge ou l’argent à l’écran');
    assert.doesNotMatch(c, /modifierIP\(|deduireCoutOrdre\(/, nom + ' paie encore à l’écran');
    if (rpc) assert.match(c, new RegExp("'" + rpc + "'"), nom + ' n’appelle pas ' + rpc);
  }
  assert.match(corps('plateau-divers.js', 'doFaireDon'), /religionAgirServeur\('faire_don'/);
});

test('subvention du répertoire : par subvention_citoyen_verser', () => {
  const c = corps('plateau-politique.js', 'executerOrdreContact');
  const i = c.indexOf("action === 'subvention'");
  assert.ok(i > 0);
  assert.match(c.slice(i, i + 2500), /sbRpc\('subvention_citoyen_verser'/);
  assert.doesNotMatch(c.slice(i, i + 2500), /debiterCaisseBatimentPlafonne/);
});
