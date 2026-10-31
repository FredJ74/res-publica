// GARDE #299 (31/10/2026) : UNE PRÉPARATION DÉJÀ APPLIQUÉE SOUS UN AUTRE NOM NE REVIENT PAS.
//
// Le paquet #219 rehorodate d'anciennes préparations (« Ancien fichier : X »). Deux d'entre elles,
// `construction_materiaux_prix_et_dons` et `compromis_financement_reel`, sont en production depuis
// le 23 et le 25/10 (registre `_94` et `_135`) puis ont été réécrites par 20261030210000 : leur
// copie rehorodatée réintroduisait l'écriture par la vue `personnages` (garde 13/14) et ses
// propres gardes d'empreinte échouent contre la production. Ce test ne remplace pas la garde
// « écriture par la vue » : il nomme la vraie cause et empêche le retour de ces copies.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const DOSSIER = new URL('../../migrations/', import.meta.url);
const DEJA = JSON.parse(readFileSync(new URL('DEJA-APPLIQUEES.json', DOSSIER), 'utf8'));
const ANCIEN = /Ancien fichier\s*:\s*([0-9]{14}_[a-z0-9_]+\.sql)/i;

export function copieDeja(sql) {
  const m = sansCorps(sql).match(ANCIEN);
  return m && Object.hasOwn(DEJA, m[1]) ? m[1] : null;
}
function sansCorps(sql) { return sql.split('\n').slice(0, 5).join('\n'); }

test('le détecteur reconnaît une copie rehorodatée d une préparation déjà appliquée', () => {
  assert.equal(copieDeja('-- PRÉPARATION NON APPLIQUÉE : rehorodatée\n-- Ancien fichier : 20261024123500_compromis_financement_reel.sql ; aucun changement'),
               '20261024123500_compromis_financement_reel.sql');
  assert.equal(copieDeja('-- Ancien fichier : 20261016131932_reception_objets_atomique.sql ; aucun changement'), null);
  assert.equal(copieDeja('SELECT 1;'), null);
});

test('aucune copie rehorodatée d une préparation déjà appliquée dans migrations/', () => {
  const fautifs = readdirSync(DOSSIER).filter((f) => f.endsWith('.sql'))
    .map((f) => [f, copieDeja(readFileSync(new URL(f, DOSSIER), 'utf8'))])
    .filter(([, x]) => x).map(([f, x]) => f + ' recopie ' + x + ' (registre ' + DEJA[x].registre + ')');
  assert.deepEqual(fautifs, [], 'Retirer ces copies : déjà appliquées en production (#299).\n' + fautifs.join('\n'));
});
