// Avertissement avant de tomber à 0 PA (décision de Fred, 04/11/2026).
//   node --test outils/bancs/test-avertissement-zero-pa.mjs
// doOrder() est exécuté dans un bac à sable : seule la garde 0 PA est observée, la suite du
// routeur est remplacée par un témoin (executerOrdreGenerique).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const RACINE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = fs.readFileSync(path.join(RACINE, 'plateau-router.js'), 'utf8');

function extraire(nom) {
  const debut = SRC.indexOf('function ' + nom + '(');
  assert.ok(debut >= 0, nom + ' introuvable');
  let i = SRC.indexOf('{', debut), prof = 0;
  for (; i < SRC.length; i++) {
    if (SRC[i] === '{') prof++;
    else if (SRC[i] === '}' && --prof === 0) break;
  }
  return SRC.slice(debut, i + 1);
}

function element() {
  const el = {
    className: '', textContent: '', style: {}, enfants: [], onclick: null,
    classList: { ouvert: false, add() { this.ouvert = true; }, remove() { this.ouvert = false; } },
    append(...e) { this.enfants.push(...e); }, replaceChildren(...e) { this.enfants = e; },
  };
  return el;
}

function bac(pa) {
  const modal = element(), titre = element(), corps = element();
  const envoyes = [], toasts = [];
  const ctx = {
    TEST_MODE: false, COUNTRIES: {}, BUILDINGS: {},
    state: { pa, char: { country: 'republic' } },
    document: {
      getElementById: (id) => ({ 'modal-postes': modal, 'postes-modal-title': titre, 'postes-body': corps })[id] || null,
      createElement: () => element(),
    },
    showToast: (...a) => toasts.push(a),
    executerOrdreGenerique: (fn) => envoyes.push(fn),
  };
  vm.createContext(ctx);
  // doOrder se termine par executerOrdreGenerique : les cas particuliers intermédiaires ne
  // concernent pas les noms d'ordre utilisés ici.
  vm.runInContext(extraire('doOrder') + '\n' + extraire('avertirZeroPa'), ctx);
  const boutons = () => corps.enfants[0].enfants[1].enfants;
  return { ctx, modal, corps, envoyes, toasts, boutons };
}

test('un ordre qui laisse des PA part sans avertissement', () => {
  const b = bac(5);
  b.ctx.doOrder('ordre_test', 3, 0, 'Ordre test', '', 100);
  assert.deepEqual(b.envoyes, ['ordre_test']);
  assert.equal(b.modal.classList.ouvert, false);
});

test('un ordre qui laisse 0 PA ouvre la confirmation et n\'envoie rien', () => {
  const b = bac(3);
  b.ctx.doOrder('ordre_test', 3, 0, 'Ordre test', '', 100);
  assert.deepEqual(b.envoyes, []);
  assert.equal(b.modal.classList.ouvert, true);
  assert.match(b.corps.enfants[0].enfants[0].textContent, /0 PA/);
});

test('Confirmer envoie l\'ordre une seule fois', () => {
  const b = bac(3);
  b.ctx.doOrder('ordre_test', 3, 0, 'Ordre test', '', 100);
  const [oui] = b.boutons();
  oui.onclick(); oui.onclick();
  assert.deepEqual(b.envoyes, ['ordre_test']);
  assert.equal(b.modal.classList.ouvert, false);
  assert.equal(b.ctx.state._zeroPaConfirme, null, 'la confirmation ne vaut que pour cet envoi');
});

test('Annuler n\'envoie rien, et le prochain essai redemande', () => {
  const b = bac(3);
  b.ctx.doOrder('ordre_test', 3, 0, 'Ordre test', '', 100);
  b.boutons()[1].onclick();
  assert.deepEqual(b.envoyes, []);
  b.ctx.doOrder('ordre_test', 3, 0, 'Ordre test', '', 100);
  assert.equal(b.modal.classList.ouvert, true);
  assert.deepEqual(b.envoyes, []);
});

test('un ordre gratuit en PA (Dormir…) n\'est jamais intercepté', () => {
  const b = bac(0);
  b.ctx.doOrder('ordre_gratuit', 0, 0, 'Gratuit', '', 100);
  assert.deepEqual(b.envoyes, ['ordre_gratuit']);
});
