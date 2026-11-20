'use strict';
// Prescription des plaintes (décision de Fred du 20/11/2026).
// Essai annulé en base le 20/11 : plainte du jour → rien ; même plainte vieillie de 31 jours (au parquet, affaire 82 non
// identifiée) → prescrite : historique « neutraliser / ville_b / prescrite », courrier « Votre plainte du 20/10/2026 pour
// … à Krasnov est prescrite : faute d'élément nouveau, l'enquête est close. », affaire 82 archivée (indices et détails
// vides) ; plainte au stade des poursuites (50 jours) → conservée.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const lire = (f) => fs.readFileSync(path.join(__dirname, '../..', f), 'utf8');

test('Serveur : 30 jours, jamais après identification ou procès, historique minimal, purge, courrier au PJ', () => {
  const sql = lire('migrations/20261120320000_plaintes_prescription.sql');
  assert.match(sql, /IF coalesce\(d ->> 'status', ''\) NOT IN \('au_parquet', 'enquete'\) THEN CONTINUE; END IF;/);
  assert.match(sql, /AND a\.identifie\) THEN CONTINUE; END IF;/);
  assert.match(sql, /plaintes_prescrire\(p_jours integer DEFAULT 30\)/);
  assert.match(sql, /SET indices = '\{\}'::jsonb, details = '\{\}'::jsonb, archivee_le = now\(\)/);
  assert.match(sql, /DELETE FROM public\.plaintes_en_cours WHERE id = r\.id;/);
  assert.match(sql, /EXISTS \(SELECT 1 FROM public\.personnages_donnees p WHERE p\.name = d ->> 'auteur'\)/);
  assert.match(sql, /' est prescrite : faute d''élément nouveau, l''enquête est close\.'/);
  assert.match(sql, /WHEN 'neutraliser' THEN 'neutralisation'/);
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.plaintes_prescrire\(integer\) FROM PUBLIC, anon, authenticated;/);
});

test('Passe de nuit et règle notée', () => {
  const cron = lire('api/cron-minuit.js');
  assert.match(cron, /sbRpc\('plaintes_prescrire', \{ p_jours: 30 \}, HEADERS_SERVICE\)/);
  assert.match(cron, /await traiterAmendesServeur\(\);\n  await traiterPrescriptionPlaintesServeur\(\);/);
  assert.match(lire('GAME-DESIGN-CRIMINALITE.md'), /\*\*Prescription des plaintes\*\*/);
});
