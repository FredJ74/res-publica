// Banc du tableau de suivi des décisions de Fred (docs/suivi-decisions.md) et du script des listes du soir.
// Lancer : node --test outils/bancs/test-suivi-decisions.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const fichier = path.join(racine, 'docs', 'suivi-decisions.md');
const script = path.join(racine, 'outils', 'suivi', 'listes-du-soir.py');
const ETATS = new Set(['décidé', 'en cours', 'en ligne']);

function dateValide(t) {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(t);
  if (!m) return false;
  const [j, mo, a] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const d = new Date(Date.UTC(a, mo - 1, j));
  return d.getUTCFullYear() === a && d.getUTCMonth() === mo - 1 && d.getUTCDate() === j;
}

// Lignes de tableau hors en-têtes et séparateurs, avec leur numéro de ligne.
function lignesTableau() {
  return readFileSync(fichier, 'utf8').split('\n')
    .map((texte, i) => ({ texte: texte.trim(), n: i + 1 }))
    .filter(({ texte }) => texte.startsWith('|'))
    .map(({ texte, n }) => ({ n, cellules: texte.replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim()) }))
    .filter(({ cellules }) => cellules[0] !== 'Date' && !/^[-: ]+$/.test(cellules[0]));
}

test('le tableau contient des décisions', () => {
  assert.ok(lignesTableau().length > 0, 'aucune ligne de décision trouvée');
});

test('chaque en-tête de tableau a les six colonnes attendues', () => {
  const entetes = readFileSync(fichier, 'utf8').split('\n').filter((l) => l.trim().startsWith('| Date'));
  assert.ok(entetes.length >= 2, 'tableau principal et section Mission Purge attendus');
  for (const e of entetes) assert.equal(e.trim(), '| Date | Décision | État | En ligne le | Commit | Source |');
});

test('chaque ligne a 6 colonnes, une date et un état valides', () => {
  for (const { n, cellules } of lignesTableau()) {
    assert.equal(cellules.length, 6, `ligne ${n} : ${cellules.length} colonnes au lieu de 6`);
    const [date, decision, etat, enLigneLe, , source] = cellules;
    assert.ok(dateValide(date), `ligne ${n} : date invalide « ${date} »`);
    assert.ok(ETATS.has(etat), `ligne ${n} : état invalide « ${etat} »`);
    assert.ok(decision.length > 0, `ligne ${n} : décision vide`);
    assert.ok(source.length > 0, `ligne ${n} : source vide`);
    if (enLigneLe) assert.ok(dateValide(enLigneLe), `ligne ${n} : date de mise en ligne invalide « ${enLigneLe} »`);
  }
});

test('une ligne « en ligne » a un commit et une date de mise en ligne ; les autres n\'en ont pas', () => {
  for (const { n, cellules } of lignesTableau()) {
    const [, , etat, enLigneLe, commit] = cellules;
    if (etat === 'en ligne') {
      assert.match(commit, /^[0-9a-f]{7,12}$/, `ligne ${n} : commit manquant ou invalide`);
      assert.ok(dateValide(enLigneLe), `ligne ${n} : date de mise en ligne manquante`);
    } else {
      assert.equal(enLigneLe, '', `ligne ${n} : date de mise en ligne alors que l'état est « ${etat} »`);
    }
  }
});

test('le script Python sort les trois sections', () => {
  const sortie = execFileSync('python3', [script, '23/11/2026'], { encoding: 'utf8' });
  for (const titre of ["## Décidé aujourd'hui", "## En ligne aujourd'hui", '## Encore en attente']) {
    assert.ok(sortie.includes(titre), `section absente : ${titre}`);
  }
  assert.equal((sortie.match(/^## /gm) || []).length, 3, 'exactement trois sections attendues');
  const decide = Number(/## Décidé aujourd'hui \((\d+)\)/.exec(sortie)[1]);
  const attendu = lignesTableau().filter(({ cellules }) => cellules[0] === '23/11/2026').length;
  assert.equal(decide, attendu, 'le nombre de décisions du jour ne correspond pas au tableau');
});

test('le script refuse un argument mal formé', () => {
  assert.throws(() => execFileSync('python3', [script, '2026-11-23'], { encoding: 'utf8', stdio: 'pipe' }));
});
