// #379 : les producteurs POP/INF portés au serveur n'écrivent plus jamais une jauge à l'écran.
// Chaque lot ajoute ici ses fonctions ; la liste ne doit que grandir.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const PORTES = {
  'plateau-politique.js': ['publierDecret', 'publierMessagePresidentiel', 'censurer',
    'confirmerMobilisationPolice', 'confirmerBanquetDiplomatique', 'doReceptionAvecBonus', 'confirmerGuerreEmpire',
    'executerOrdreTexte', 'traiterDemandeManifestation'],
  'plateau-actions-illegales-rumeurs.js': ['confirmerCorruptionRegistre'],
  'plateau-divers.js': ['appliquerMalusPopExcommunication'],
  'plateau-justice-economie.js': ['appliquerBonusLocation', 'confirmerDonObjetPnj'],
  'plateau-multijoueur.js': ['payerEscorts'],
};

function corps(fichier, nom) {
  const s = fs.readFileSync(fichier, 'utf8');
  const m = new RegExp('(?:async )?function ' + nom + '\\(').exec(s);
  assert.ok(m, nom + ' introuvable dans ' + fichier);
  let i = s.indexOf('{', m.index), prof = 0;
  for (let j = i; j < s.length; j++) {
    if (s[j] === '{') prof++;
    else if (s[j] === '}' && --prof === 0) return s.slice(m.index, j + 1);
  }
  throw new Error('corps non fermé : ' + nom);
}

for (const [fichier, noms] of Object.entries(PORTES)) {
  for (const nom of noms) {
    test(nom + ' : aucune écriture locale de POP ou INF', () => {
      const c = corps(fichier, nom);
      assert.doesNotMatch(c, /state\.(pop|inf)\s*(=[^=]|\+=|-=)/, nom + ' écrit encore une jauge');
      assert.doesNotMatch(c, /Math\.random\(\)/, nom + ' tire encore un aléa à l’écran');
    });
  }
}

test('les ordres morts interdire_manif_cible / reprimer_manif_cible ne sont plus routés', () => {
  assert.doesNotMatch(fs.readFileSync('plateau-router.js', 'utf8'), /manif_cible/);
});

// Don d'argent sur un terrain : la branche « promoteur » (+5 INF) est retirée ; les jets des
// squatteurs (hors POP/INF) restent à l'écran, d'où une garde limitée aux jauges.
for (const nom of ['confirmerDonArgent', 'confirmerDonPnj']) {
  test(nom + ' : aucune écriture locale de POP ou INF, aucun débit local', () => {
    const c = corps('plateau-justice-economie.js', nom).replace(/\/\/.*$/gm, '');
    assert.doesNotMatch(c, /state\.(pop|inf)\s*(=[^=]|\+=|-=)/);
    if (nom === 'confirmerDonPnj') assert.doesNotMatch(c, /state\.arg\s*(\+=|-=)/);
  });
}
