// Blocus syndical au serveur (02/11/2026, GAME-DESIGN-BLOCUS.md) : l'écran ne tire plus aucun dé,
// n'écrit plus le blocus, et passe par les quatre fonctions serveur ; le cron délègue la nuit.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const lire = (f) => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const section = (src, debut, fin) => { const i = src.indexOf(debut); assert.ok(i >= 0, debut); return src.slice(i, src.indexOf(fin, i)); };

test('écran : organiser et renouveler passent par le serveur, sans dé ni écriture', () => {
  const s = section(lire('plateau-organisations-quetes.js'), '// BLOCUS SYNDICAL — TOUT AU SERVEUR', '// SE RENSEIGNER');
  for (const rpc of ['blocus_syndical_organiser', 'blocus_syndical_renouveler', 'blocus_syndicaux_actifs']) assert.match(s, new RegExp("'" + rpc + "'"));
  assert.doesNotMatch(s, /Math\.random|sbSetBatimentEtat|doForcerBlocus/);
  assert.match(s, /gradeIdx === 2 \|\| gradeIdx === 3/);
});

test('commissaire : intervention au serveur, plus de levée par l\'écran ni par le ministre', () => {
  const p = lire('plateau-politique.js');
  assert.match(p, /'blocus_syndical_intervenir'/);
  assert.doesNotMatch(p, /confirmerRepressionBlocus/);
  assert.doesNotMatch(p, /sbSetBatimentEtat\([^)]*blocus/);
});

test('routeur : ordres du bâtiment bloqués, intervention du commissaire jamais bloquée', () => {
  const r = lire('plateau-router.js');
  assert.match(r, /fn !== 'mobiliser_police'/);
  assert.doesNotMatch(r, /blocusModificateurLegal|blocusEntreeResolueBuildingId/);
});

test('cron : la nuit des blocus est déléguée aux fonctions serveur', () => {
  const c = lire('api/cron-minuit.js');
  assert.match(c, /sbRpc\('blocus_nuit_expirer', \{\}, HEADERS_SERVICE\)/);
  assert.match(c, /sbRpc\('blocus_nuit_effets', \{\}, HEADERS_SERVICE\)/);
  assert.doesNotMatch(section(c, 'async function nettoyerBlocusExpires', '\n}\n'), /sbUpdate/);
});

test('migration : portes patchées et écriture écran fermée', () => {
  const m = lire('migrations/20261102135437_blocus_syndical_serveur.sql');
  for (const f of ['batiment_etat_sous_cle_ecrire', 'navigation_interieure_personnage_interne', 'payer_ordre_interne']) assert.ok(m.includes(f), f);
  assert.match(m, /commande_serveur_requise/);
  assert.doesNotMatch(m, /'mobiliser_police'\)/);
  assert.doesNotMatch(m.slice(m.indexOf('INSERT INTO public.blocus_ordres_batiments')), /mobiliser_police/);
});
