#!/usr/bin/env node
// Garde de livraison #219 : les migrations déjà appliquées et les préparations
// hors paquet restent conservées comme fixtures, jamais exécutables depuis migrations/.
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const file = p => path.join(root, p);
const json = p => JSON.parse(readFileSync(file(p), 'utf8'));
const manifest = json('outils/audits/LIVRAISON-COMPLETE-219-20261031.json');
const classement = json('outils/audits/catalogue-1012/REHORODATEES-219-STATUT-REEL.json');
assert.equal(manifest.migrations.length, 95, 'Le paquet validé doit contenir 95 migrations');
const deployables = new Set(manifest.migrations.map(m => m.fichier));
assert.equal(deployables.size, 95, 'Une migration ne peut être sélectionnée deux fois');
assert.equal(new Set(manifest.migrations.map(m => m.version)).size, 95, 'Version de migration en double');

for (const item of manifest.migrations) {
  assert.ok(existsSync(file(item.fichier)), 'Migration sélectionnée absente : ' + item.fichier);
  const sha = createHash('sha256').update(readFileSync(file(item.fichier))).digest('hex');
  assert.equal(sha, item.sha256, 'Migration sélectionnée modifiée sans révision de son manifeste : ' + item.fichier);
}

let archivesAppliquees = 0;
let archivesPreparations = 0;
let nouvellesSelectionnees = 0;
for (const entry of classement.fichiers) {
  const original = entry.fichier_219;
  if (entry.dans_les_95) {
    assert.ok(deployables.has(original), 'Migration nouvelle exclue du manifeste : ' + original);
    nouvellesSelectionnees++;
    continue;
  }
  assert.ok(!existsSync(file(original)), 'Copie non sélectionnée encore exécutable : ' + original);
  const name = path.basename(original);
  const historique = 'historique/migrations-appliquees/rehorodatees-219/' + name;
  const preparation = 'historique/preparations-hors-paquet-219/' + name;
  assert.ok(existsSync(file(historique)) || existsSync(file(preparation)),
    'Source SQL hors paquet perdue : ' + name);
  if (existsSync(file(historique))) archivesAppliquees++;
  else archivesPreparations++;
}
assert.equal(nouvellesSelectionnees, 6, 'Six migrations nouvelles de cette coupe doivent être sélectionnées');
assert.equal(archivesAppliquees, 53, 'Les 50 copies suffixées et 3 copies identiques doivent être archivées');
assert.equal(archivesPreparations, 6, 'Six préparations hors paquet doivent être isolées');
for (const entry of readdirSync(file('migrations'))) {
  if (/^20261031113\d\d_.*\.sql$/.test(entry)) {
    assert.ok(deployables.has('migrations/' + entry),
      'Script rehorodaté non sélectionné sous migrations/ : ' + entry);
  }
}
console.log('OK livraison #219 : 95 migrations uniques et empreintes intactes, '
  + archivesAppliquees + ' sources historiques archivées, '
  + archivesPreparations + ' préparations isolées, aucun doublon exécutable');
