'use strict';
// Victimes prévenues par le journal ; statut Masqué / Caché pour soi (décisions de Fred du 20/11/2026).
// Essai annulé en base le 20/11 : « Événement » à Arnie → aucun courrier, ligne crim_evenements 'journal' ; un autre
// expéditeur (Commissariat) écrit toujours un courrier ; une ligne de journal vieille de 10 jours est encore relevée ;
// crim_mon_statut_discretion répond { mode: 'decouvert', numero: null } pour un personnage à visage découvert.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

function charger() {
  const journal = [], doc = { readyState: 'loading', addEventListener() {}, getElementById: () => null };
  const g = { document: doc, setTimeout() {}, setInterval() {}, addJournalEntry: (t, c) => journal.push([t, c]) };
  g.window = g;
  vm.runInNewContext(lire('plateau-criminalite.js'), g);
  return { C: g.RPCriminalite, journal };
}

test('Serveur : un seul aiguillage, aucun appelant modifié', () => {
  const sql = lire('migrations/20261120270000_crim_victimes_journal_discretion.sql');
  assert.match(sql, /IF p_expediteur IN \('Événement', 'Événement mystérieux'\) THEN\n    INSERT INTO public\.crim_evenements \(personnage, type, donnees\)/);
  assert.match(sql, /OR type = 'journal'\) \/\* crim_victimes_journal_v1 \*\//);
  assert.match(sql, /'mode', public\.crim_mode_action_interne\(a\), 'numero', v_num/);
});

test('Écran : la ligne s\'inscrit au journal, en texte brut', () => {
  const { C, journal } = charger();
  C.inscrireAuJournal({ sujet: 'Vol', texte: 'Un individu masqué vous a dérobé <b>340 FR</b>.<br>Rien d\'autre.' });
  assert.equal(journal.length, 1);
  assert.equal(journal[0][0], 'Vol — Un individu masqué vous a dérobé 340 FR. Rien d&#39;autre.'.replace('&#39;', '\''));
  assert.equal(journal[0][1], 'event-bad');
  C.inscrireAuJournal({ sujet: '<img src=x onerror=alert(1)>Piège', texte: '' });
  assert.doesNotMatch(journal[1][0], /<img/);
  assert.match(lire('plateau-criminalite.js'), /else if \(ev\.type === 'journal'\) inscrireAuJournal\(ev\.donnees \|\| \{\}\);/);
});

test('Fiche : statut Masqué / Caché / Masqué et caché, infobulle de ce que voient les autres', () => {
  const { C } = charger();
  assert.equal(C.libellesStatutDiscretion('decouvert', null), null);
  assert.deepEqual(JSON.parse(JSON.stringify(C.libellesStatutDiscretion('masque', 2))), { libelle: 'Masqué', info: 'Les autres vous voient comme Individu masqué n° 2.' });
  assert.equal(C.libellesStatutDiscretion('cache', null).libelle, 'Caché');
  assert.equal(C.libellesStatutDiscretion('cache', null).info, 'Vous n’apparaissez pas dans la liste des présents.');
  assert.equal(C.libellesStatutDiscretion('cache_masque', 1).libelle, 'Masqué et caché');
  assert.match(lire('plateau-multijoueur.js'), /window\.RPCriminalite\.rafraichirStatutDiscretion\(\);/);
});

test('Docs : règle remplacée dans GAME-DESIGN-CRIMINALITE.md, clés Codex', () => {
  const gd = lire('GAME-DESIGN-CRIMINALITE.md');
  assert.doesNotMatch(gd, /\*\*Messages\*\* : courrier système « Événement »/);
  assert.match(gd, /ligne de son journal d'événements/);
  assert.match(lire('RELAIS.md'), /`discretionStatus\.masked`/);
});
