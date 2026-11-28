// Banc statique des réponses de Fred aux 29 questions (mission du 28/11/2026 soir, chantier 1), partie serveur tenue par
// la session principale : Tito vise d'abord un joueur actif ; une nuit à l'hôpital décompte un jour de peine.
// L'essai en production (transaction annulée, TESTS_OK) est consigné dans RELAIS.md.
const test = require('node:test'), assert = require('node:assert'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIG = 'migrations/20261128200000_reponses_29_questions.sql';

test('migration : transaction et marques', () => {
  const m = lire(MIG);
  assert.ok(/\nBEGIN;\n/.test(m) && /\nCOMMIT;\n/.test(m));
  for (const k of ['tito_joueur_actif_v1', 'transfert_peine_hopital_v1']) assert.ok(m.includes(k), k);
});

test('Tito : joueurs actifs (7 jours) d’abord, jamais un PNJ ni un compte de test', () => {
  const m = lire(MIG);
  const f = m.slice(m.indexOf('FUNCTION public.tito_secret_reseau_interne'), m.indexOf('REVOKE ALL ON FUNCTION public.tito_secret_reseau_interne'));
  assert.ok(f.includes("interval '7 days'"));
  assert.ok(f.includes('JOIN auth.users u ON u.id = d.user_id'), 'un PNJ n’a pas de compte');
  assert.ok(f.includes('NOT public.est_compte_test(d.name)'));
  assert.ok(/ORDER BY coalesce\(actif, false\) DESC, client DESC, random\(\)/.test(f), 'ordre de priorité');
  assert.ok(m.includes('REVOKE ALL ON FUNCTION public.tito_secret_reseau_interne(text) FROM PUBLIC, anon, authenticated'));
});

test('hôpital : les suites du « Dormir » appelées dans la branche d’hospitalisation, pas au jour 0', () => {
  const m = lire(MIG);
  const apres = m.split("'public.pa_repos_nocturne(text)'::regprocedure,")[1].split('$q$,\n$q$')[1];
  assert.ok(apres.includes('PERFORM public.pa_repos_suites_interne(p_acteur); /* transfert_peine_hopital_v1 */'));
  assert.ok(apres.indexOf('pa_repos_le = v_jour') < apres.indexOf('pa_repos_suites_interne'), 'après l’enregistrement du sommeil');
  assert.ok(apres.includes('-- Rébellion'), 'ancrage dans la branche d’hospitalisation');
});
