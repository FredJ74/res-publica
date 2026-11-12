// Rechargement dans une pièce propre à une ville (roomsExtra) : la position du serveur est restaurée.
// Retour de Ben (12/11/2026) : Bureau du Directeur de la banque de Montrouge, écran resté sur une rue vide.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const src = readFileSync(new URL('../../plateau-core.js', import.meta.url), 'utf8');
const debut = src.indexOf('function restaurerPositionApresChargement(char) {');
const fin = src.indexOf('\n}\n', debut) + 2;
function executer(char, ctxVille) {
  const appels = [];
  const ctx = {
    BUILDINGS: { 'banque-locale': { rooms: { guichet: {} } } },
    getBuildingContext: () => ctxVille,
    state: { country: 'republic', currentCity: 'ville_b', currentBuilding: null, currentRoom: null, char: { name: 'Ben' } },
    window: {}, console,
    setTimeout: (f) => f(),
    representerPositionServeur: (b, r) => appels.push([b, r])
  };
  vm.createContext(ctx);
  vm.runInContext(src.slice(debut, fin) + ';restaurerPositionApresChargement(' + JSON.stringify(char) + ');', ctx);
  return appels;
}
test('une pièce de ville (roomsExtra) est restaurée', () => {
  const appels = executer({ currentBuilding: 'banque-locale', currentRoom: 'bureau_directeur' },
    { roomsExtra: { bureau_directeur: {} } });
  assert.deepEqual(appels, [['banque-locale', 'bureau_directeur']]);
});
test('une pièce exclue ou inconnue ne l’est pas', () => {
  assert.deepEqual(executer({ currentBuilding: 'banque-locale', currentRoom: 'bureau_directeur' },
    { roomsExtra: { bureau_directeur: {} }, roomsExclues: ['bureau_directeur'] }), []);
  assert.deepEqual(executer({ currentBuilding: 'banque-locale', currentRoom: 'inexistante' }, null), []);
});
test('une pièce du gabarit commun reste restaurée', () => {
  assert.deepEqual(executer({ currentBuilding: 'banque-locale', currentRoom: 'guichet' }, null), [['banque-locale', 'guichet']]);
});
