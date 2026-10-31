// Banc de non-régression (31/10/2026, clôture Luthécia) : tout avis personnel émis par l'écran
// via addMailNotification('<expéditeur>', ...) doit être signé d'une identité que la base accepte
// pour un courrier adressé au joueur lui-même (libre, ou autorise_soi), sinon l'avis est refusé
// en silence par la politique `mails_envoi` et n'arrive jamais.
// Sources de vérité côté dépôt : le seed `mails_expediteurs_systeme` du baseline, puis les
// migrations de `migrations/` qui l'amendent. Aucun accès réseau.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const racine = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');

function identitesAcceptees() {
  const ok = new Set();
  const seed = lire('baseline/seeds/90_socle/mails_expediteurs_systeme.sql');
  // colonnes : expediteur, note, est_prefixe, postes, autorise_soi, libre, ...
  for (const m of seed.matchAll(/VALUES \('((?:[^']|'')*)', (?:'(?:[^']|'')*'|NULL), '(true|false)', '[^']*', '(true|false)', '(true|false)'/g)) {
    const [, nom, prefixe, soi, libre] = m;
    if (prefixe === 'false' && (soi === 'true' || libre === 'true')) ok.add(nom.replace(/''/g, "'"));
  }
  for (const f of fs.readdirSync(path.join(racine, 'migrations')).filter(f => f.endsWith('.sql')).sort()) {
    const sql = lire('migrations/' + f);
    if (!/mails_expediteurs_systeme/.test(sql)) continue;
    // Lignes d'INSERT « ('Nom', 'note', false, '{}', true|false, true|false, ... »
    for (const m of sql.matchAll(/\(\s*'((?:[^']|'')*)',\s*'(?:[^']|'')*',\s*false,\s*'\{\}',\s*(true|false),\s*(true|false)/g)) {
      if (m[2] === 'true' || m[3] === 'true') ok.add(m[1].replace(/''/g, "'"));
    }
    for (const m of sql.matchAll(/SET autorise_soi = true\s+WHERE expediteur IN \(([^)]*)\)/g)) {
      for (const n of m[1].matchAll(/'((?:[^']|'')*)'/g)) ok.add(n[1].replace(/''/g, "'"));
    }
  }
  return ok;
}

function expediteursAvisPersonnels() {
  const res = new Map();
  for (const f of fs.readdirSync(racine).filter(f => f.endsWith('.js'))) {
    const src = lire(f);
    for (const m of src.matchAll(/addMailNotification\(\s*'((?:[^'\\]|\\.)*)'/g)) {
      const nom = m[1].replace(/\\'/g, "'");
      if (!res.has(nom)) res.set(nom, f);
    }
  }
  // Expéditeur calculé de la convocation douanière (plateau-navigation.js) : table explicite.
  const nav = lire('plateau-navigation.js');
  const table = nav.match(/const commissairePays = \{([^}]*)\}\[pays\] \|\| '([^']*)'/);
  assert.ok(table, 'table des commissaires de la convocation douanière introuvable');
  for (const m of table[1].matchAll(/:'((?:[^'\\]|\\.)*)'/g)) res.set(m[1], 'plateau-navigation.js');
  res.set(table[2], 'plateau-navigation.js');
  return res;
}

test('chaque avis personnel est signé d’une identité acceptée par la base', () => {
  const ok = identitesAcceptees();
  assert.ok(ok.has('Système') && ok.has('Office Notarial'), 'lecture du seed incomplète');
  const refuses = [...expediteursAvisPersonnels()].filter(([nom]) => !ok.has(nom)).map(([n, f]) => `${n} (${f})`);
  assert.deepEqual(refuses, [], 'avis personnels refusés par mails_envoi : ' + refuses.join(', '));
});

test('les identités ajoutées n’écrivent qu’au joueur lui-même', () => {
  const sql = lire('migrations/20261031190000_avis_personnels_expediteurs_declares.sql');
  for (const m of sql.matchAll(/\(\s*'((?:[^']|'')*)',\s*'(?:[^']|'')*',\s*(true|false),\s*'(\{[^}]*\})',\s*(true|false),\s*(true|false),\s*(true|false),\s*(true|false),\s*(true|false)\)/g)) {
    const [, nom, prefixe, postes, soi, libre, titulaire, conjoint, fret] = m;
    assert.equal(prefixe, 'false', nom);
    assert.equal(postes, '{}', nom);
    assert.equal(soi, 'true', nom);
    assert.deepEqual([libre, titulaire, conjoint, fret], ['false', 'false', 'false', 'false'], nom + ' ouvert vers un tiers');
  }
});
