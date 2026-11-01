// Banc du 01/11/2026 — ordres d'ambassade non raccordables passés en « Bientôt disponible »
// (décision de Fred, 01/11 : visibles et grisés plutôt que masqués, en attendant le voyage
// entre empires). Vérifie :
//  1. les deux démarches « Demander la naturalisation » (mairies) portent `bientot` ;
//  2. la pop-up État civil les rend grisées, sans appel à doOrder, et laisse les autres actives ;
//  3. « Demandes de naturalisation » (ministre de l'Intérieur) et « Demander le transfert d'un
//     détenu » (trois bureaux d'ambassadeur) portent `bientot` dans data.js.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const racine = path.join(__dirname, '..', '..');
const politique = fs.readFileSync(path.join(racine, 'plateau-politique.js'), 'utf8');
const data = fs.readFileSync(path.join(racine, 'data.js'), 'utf8');

function extraire(source, debut) {
  const i = source.indexOf(debut);
  assert.ok(i >= 0, 'introuvable : ' + debut);
  let profondeur = 0, j = source.indexOf('{', i);
  for (; j < source.length; j++) {
    if (source[j] === '{') profondeur++;
    else if (source[j] === '}') { profondeur--; if (profondeur === 0) break; }
  }
  return source.slice(i, j + 1);
}

function rendreEtatCivil(batiment) {
  const elements = {};
  const el = id => (elements[id] = elements[id] || { textContent: '', innerHTML: '', classList: { add() {} } });
  const ctx = {
    state: { currentBuilding: batiment, char: { country: 'republic' } },
    COUNTRIES: { republic: { cur: 'FR' } },
    document: { getElementById: el },
  };
  vm.createContext(ctx);
  vm.runInContext(extraire(politique, 'const DEMARCHES_ETAT_CIVIL_PAR_BATIMENT') + ';\n' +
    extraire(politique, 'function ouvrirEtatCivil()') + ';\nouvrirEtatCivil();', ctx);
  return elements['postes-body'].innerHTML;
}

for (const batiment of ['mairie-capitale', 'mairie']) {
  test('État civil (' + batiment + ') : naturalisation grisée, autres démarches actives', () => {
    const html = rendreEtatCivil(batiment);
    const boutons = html.split('<button').slice(1);
    assert.strictEqual(boutons.length, 4);
    const natu = boutons.find(b => b.includes('Demander la naturalisation'));
    assert.ok(natu, 'bouton de naturalisation absent : il doit rester visible');
    assert.ok(!natu.includes('doOrder'), 'le bouton grisé ne doit appeler aucune porte');
    assert.ok(natu.includes('opacity:.45') && natu.includes('not-allowed'));
    assert.ok(natu.includes('voyage entre empires'));
    // Le motif est échappé : aucun guillemet double brut ne casse l'attribut onclick.
    const onclick = natu.match(/onclick="([^"]*)"/)[1];
    assert.ok(onclick.startsWith("showToast('Bientôt disponible'"), onclick);
    for (const autre of ['Demander un acte officiel', 'Demander en mariage', 'Officialiser un mariage']) {
      const b = boutons.find(x => x.includes(autre));
      assert.ok(b && b.includes('doOrder('), autre + ' doit rester actif');
    }
  });
}

test('data.js : examen des naturalisations grisé pour le ministre de l\'Intérieur', () => {
  const ligne = data.split('\n').find(l => l.includes("fn:'demandes_naturalisation'"));
  assert.ok(ligne && /bientot:'Bientôt disponible/.test(ligne));
});

test('data.js : transfert d\'un détenu visible et grisé dans les trois bureaux d\'ambassadeur', () => {
  const lignes = data.split('\n').filter(l => l.includes("fn:'demander_transfert_detenu'"));
  assert.strictEqual(lignes.length, 3);
  for (const l of lignes) {
    assert.ok(/bientot:'Bientôt disponible/.test(l));
    assert.ok(l.includes("requiresPost:'ambassadeur_local'"));
  }
});
