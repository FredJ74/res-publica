// Faits divers du Journal du jour (décision de Fred du 20/11/2026).
// Essai annulé en base le 20/11 : neutralisation d'Arnie (ministre de la Défense, Républia) à Krasnov par un auteur
// masqué non identifié → le fait ne contient que « un individu masqué », aucune trace de l'auteur ; vol identifié →
// auteur nommé, « environ 2300 volés » ; explosion prématurée retenue ; fait transfrontalier présent dans les deux pays.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const racine = path.join(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const { faitDiversDepuisServeur, collecterFaitsDivers } = await import(path.join(racine, 'api/_journal-collecte.js'));

const masque = { id: 'crim_affaires:83', type: 'neutralisation', issue: 'reussite', date: '2026-11-20T17:47:41Z',
  lieu: { batiment: 'station-radar-krasnov', ville: 'ville_b', pays: 'soviet' },
  victime: { nom: 'Arnie', estPJ: true, poste: 'Ministre de la Defense', nationalite: 'republic' },
  auteur: { identifie: false, designation: 'un individu masqué' }, consequence: 'victime hospitalisée', transfrontalier: true };

test('Auteur masqué non identifié : aucune donnée de l\'auteur dans le paquet envoyé au générateur', async () => {
  // Défense en profondeur : même si le serveur laissait passer un nom par erreur, il n'est pas recopié.
  const fuite = { ...masque, auteur: { identifie: false, designation: 'un individu masqué', nom: 'Tom Tom', mode: 'cache_masque' } };
  const f = faitDiversDepuisServeur(fuite, new Map([['Arnie', { photo_url: null }]]));
  const texte = JSON.stringify(f);
  assert.doesNotMatch(texte, /Tom Tom|cache_masque/);
  assert.deepEqual(f.auteur, { identifie: false, designation: 'un individu masqué' });
  assert.match(f.resume, /^Arnie \(Ministre de la Defense\) a été neutralisé\(e\) par un individu masqué/);
  assert.equal(f.domaine, 'faits_divers'); assert.equal(f.estPJ, true); assert.equal(f.transfrontalier, true);
  assert.deepEqual(f.pays, ['soviet', 'republic']);                        // incident lisible dans les deux pays
  assert.equal(f.poids, 'majeur');                                         // PJ + responsable politique + transfrontalier
  // Le paquet complet tel que la collecte le construit, à partir de la réponse du serveur.
  globalThis.fetch = async () => ({ ok: true, json: async () => [masque] });
  const paquet = await collecterFaitsDivers({ debut: '2026-11-20T00:00:00Z', fin: '2026-11-21T00:00:00Z' }, 'republic', new Map());
  assert.equal(paquet.length, 1);
  assert.doesNotMatch(JSON.stringify(paquet), /Tom Tom/);
});

test('Auteur identifié par les voies du jeu : nommé', () => {
  const f = faitDiversDepuisServeur({ ...masque, type: 'vol_personne', auteur: { identifie: true, nom: 'Tom Tom' }, consequence: 'environ 2300 volés' }, new Map());
  assert.deepEqual(f.auteur, { identifie: true, nom: 'Tom Tom' });
  assert.match(f.resume, /a été volé\(e\) par Tom Tom/);
});

test('Serveur : anonymisation dans la fonction, réservée au serveur ; prompt : jamais d\'hypothèse sur l\'auteur', () => {
  const sql = lire('migrations/20261120300000_journal_faits_divers.sql');
  assert.match(sql, /'auteur', CASE WHEN a\.identifie AND a\.auteur IS NOT NULL\s+THEN jsonb_build_object\('identifie', true, 'nom', a\.auteur\)/);
  assert.match(sql, /'designation', CASE WHEN a\.mode IN \('masque', 'cache_masque'\) THEN 'un individu masqué' ELSE 'un inconnu' END/);
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.journal_faits_divers\(text, timestamptz, timestamptz\) FROM PUBLIC, anon, authenticated;/);
  const prompt = lire('api/_journal-generation.js');
  assert.match(prompt, /tu ne formules AUCUNE hypothèse sur son identité/);
  assert.match(prompt, /LES PJ FONT L'ACTUALITÉ/);
  assert.match(prompt, /incident diplomatique/);
  assert.match(lire('GAME-DESIGN-PRESSE.md'), /Faits divers/);
});
