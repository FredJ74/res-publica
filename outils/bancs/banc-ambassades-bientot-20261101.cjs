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
  vm.runInContext(extraire(politique, 'function libelleMunicipalI18n(') + ';\n' +
    extraire(politique, 'const DEMARCHES_ETAT_CIVIL_PAR_BATIMENT') + ';\n' +
    extraire(politique, 'function ouvrirEtatCivil()') + ';\nouvrirEtatCivil();', ctx);
  return elements['postes-body'].innerHTML;
}

// Naturalisation et domiciliation ouvertes (Fred, 18/11/2026, chantier « Nationalité, domicile et élections ») :
// la naturalisation n'est plus grisée ; l'examen des demandes par le ministre de l'Intérieur non plus.
for (const batiment of ['mairie-capitale', 'mairie']) {
  test('État civil (' + batiment + ') : naturalisation et domiciliation actives, aucune démarche grisée', () => {
    const html = rendreEtatCivil(batiment);
    const boutons = html.split('<button').slice(1);
    assert.strictEqual(boutons.length, 5);
    for (const libelle of ['Demander un acte officiel', 'Demander la naturalisation', 'Se domicilier ici', 'Demander en mariage', 'Officialiser un mariage']) {
      const b = boutons.find(x => x.includes(libelle));
      assert.ok(b, libelle + ' absent');
      assert.ok(!b.includes("showToast('Bientôt disponible'"), libelle + ' ne doit pas être grisé');
    }
  });
}

test('data.js : examen des naturalisations ouvert pour le ministre de l\'Intérieur', () => {
  const ligne = data.split('\n').find(l => l.includes("fn:'demandes_naturalisation'"));
  assert.ok(ligne && !/bientot:/.test(ligne));
});

test('data.js : transfert d\'un détenu ouvert chez Sovarka (Luthécia), grisé chez Al-Khalija et El Estado (Fred, 27/11/2026)', () => {
  // Les trois bureaux de Luthecia ; ceux du Palais des Ambassades de Novomirsk sont controles a part.
  const lignes = data.split('\n').filter(l => l.includes("fn:'demander_transfert_detenu'") && !l.includes('ambassades de Novomirsk') && !l.includes('pays hôte'));
  assert.strictEqual(lignes.length, 2);
  for (const l of lignes) {
    assert.ok(/bientot:'Bientôt disponible/.test(l));
    assert.ok(l.includes("requiresPost:'ambassadeur_local'"));
  }
  assert.strictEqual(data.split('\n').filter(l => l.includes("fn:'demander_transfert_detenu'") && !/bientot:/.test(l)).length, 2);
});

// 13/11/2026 (Palais des Ambassades, salle et accès) : la salle de réception est retirée (elle appartient au Pavillon)
// et « Demander audience » / « Demander l'asile » sont réactivés à l'accueil ; les trois bureaux restent grisés.
// 27/11/2026 (consigne de Fred) : l'Ambassade de Républia ouvre relations bilatérales, réception et mécénat.
test('data.js : Palais des Ambassades de Novomirsk, audience, asile et trois ordres de Républia actifs, le reste grisé', () => {
  const i = data.indexOf("\n  'palais-ambassades-novomirsk': {");
  assert.ok(i >= 0);
  const bloc = data.slice(i, data.indexOf("\n  'pavillon-ambassadeurs-novomirsk': {", i));
  const ordres = bloc.split('\n').filter(l => l.includes('{fn:'));
  assert.strictEqual(ordres.length, 14);
  const actifs = ordres.filter(l => !/bientot:/.test(l)).map(l => l.match(/fn:'([a-z_]+)'/)[1]);
  assert.deepStrictEqual(actifs, ['demander_audience_ambassadeur', 'demander_asile_politique',
    'relations_bilaterales', 'organiser_reception_diplomatique', 'financer_oeuvre_culturelle', 'demander_transfert_detenu']);
  for (const l of ordres.filter(l => /bientot:/.test(l))) assert.ok(/bientot:'Bientôt disponible : les ambassades de Novomirsk/.test(l), l);
  assert.strictEqual(ordres.filter(l => /bientot:/.test(l)).length, 8);
});
