// Banc des réponses de Fred du 28/11/2026 (soir), points 8 et 9 (paiement, comptes) — migration 20261128220000.
// Statique (aucun accès réseau ni base) : contenu de la migration, textes de suspension dans les 9 langues, raccord du
// refus « compte_suspendu » renvoyé par la base pour le forum, le courrier et le chat (supabase.js), commentaires du
// paiement. L'essai SQL réel (transaction annulée, TESTS_OK) est décrit dans le rapport de la mission.
// Usage : node --test outils/bancs/banc-paiement-comptes-20261128-soir.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const RACINE = path.join(__dirname, '..', '..');
const lire = f => fs.readFileSync(path.join(RACINE, f), 'utf8');
const MIG = lire('migrations/20261128220000_reponses_fred_paiement_comptes.sql');

test('migration : transaction, marques, Biélorussie, blocage CGU non touché', () => {
  assert.match(MIG, /^BEGIN;$/m);
  assert.match(MIG, /^COMMIT;\s*$/m);
  for (const marque of ['comptes_sans_email_v1', 'moderation_suspension_ecrits_v1', 'export_masques_v1'])
    assert.ok(MIG.includes(marque), marque);
  assert.match(MIG, /cle = 'paiement_pays_exclus' AND NOT \('BY' = ANY/);
  assert.ok(!/UPDATE public\.juridique_parametres/.test(MIG), 'le blocage des CGU ne doit pas être touché');
  assert.ok(!/sk_(live|test)_|whsec_/.test(MIG), 'aucun secret');
});

test('goulag : les 13 clés étrangères vers la fiche sont remplacées par un contrôle, anonymisation à la suppression', () => {
  const fk = ['traversees_nom', 'depots_nom', 'autorisations_nom', 'refuges_nom', 'visites_nom', 'entrees_nom', 'registre_nom',
    'incidents_nom', 'tentatives_nom', 'traces_revelees_nom', 'corruptions_nom', 'interrogatoires_detenu', 'interrogatoires_interrogateur'];
  for (const f of fk) assert.ok(MIG.includes(`DROP CONSTRAINT IF EXISTS sovarka_goulag_${f}_fkey`), f);
  assert.match(MIG, /CREATE TRIGGER trg_zz_personnages_goulag_traces BEFORE DELETE OR UPDATE OF name ON public\.personnages_donnees/);
  assert.match(MIG, /goulag_nom_verifier_trg\('detenu', 'interrogateur'\)/);
  assert.ok(MIG.includes("c_det constant text := 'Ancien détenu'"));
  // Les tables d'historique sont gardées (mises à jour), seules les lignes d'état personnel sont effacées.
  for (const t of ['registre', 'entrees', 'incidents', 'tentatives', 'corruptions', 'depots', 'autorisations'])
    assert.ok(MIG.includes(`UPDATE public.sovarka_goulag_${t} SET nom = c_det WHERE nom = p_nom`), t);
  for (const t of ['registre', 'entrees', 'incidents', 'tentatives', 'corruptions', 'depots', 'autorisations', 'interrogatoires'])
    assert.ok(!MIG.includes(`DELETE FROM public.sovarka_goulag_${t} `), 'historique effacé : ' + t);
});

test('suspension : forum, courrier et chat bloqués côté base, serveur et administrateurs exemptés', () => {
  for (const t of ['forum_topics', 'forum_posts', 'mails', 'messages_chat'])
    assert.ok(new RegExp(`CREATE TRIGGER trg_moderation_suspension_ecrits BEFORE INSERT[^\\n]* ON public\\.${t}\\n`).test(MIG), t);
  assert.match(MIG, /IF v_uid IS NULL OR public\.est_appel_serveur\(\) THEN RETURN NEW; END IF;/);
  assert.match(MIG, /RAISE EXCEPTION 'compte_suspendu' USING ERRCODE = 'P0001', DETAIL = s::text/);
});

test('comptes sans e-mail : supprimés après 3 ans sans avertissement (liste et suppression)', () => {
  const n = (MIG.match(/OR coalesce\((a|x)\.email, ''\) = ''\)/g) || []).length;
  assert.equal(n, 2);
});

test('textes de suspension : forum, courrier et chat dans les 9 langues (écran et notification)', () => {
  const js = lire('juridique-client.js');
  assert.ok(!/ordres sont bloqués|orders are blocked until|órdenes están bloqueadas hasta/.test(js));
  const attendus = ['le forum, le courrier et le chat', 'forum, mail and chat', 'el foro, el correo y el chat',
    'das Forum, die Post und der Chat', 'форум, почта и чат', '포럼, 우편, 채팅', 'والمنتدى والبريد والدردشة',
    'o fórum, o correio e o chat', '論壇、信件與聊天'];
  for (const a of attendus) {
    assert.equal(js.split(a).length - 1, 2, 'écran : ' + a);
    assert.ok(MIG.includes(a), 'notification : ' + a);
  }
  assert.ok(lire('admin-signalements.js').includes('Suspension (ordres, forum, courrier et chat bloqués)'));
});

test('supabase.js : une erreur « compte_suspendu » ouvre le rappel de la suspension', () => {
  const src = lire('supabase.js');
  const debut = src.indexOf('function sbSignalerRefusSuspension(');
  const fin = src.indexOf('async function sbTransportRest(', debut);
  assert.ok(debut > 0 && fin > debut);
  const recus = [];
  const bac = { window: { rpJuridiqueRefus: v => recus.push(v) } };
  vm.createContext(bac);
  vm.runInContext(src.slice(debut, fin) + '\nthis.f = sbSignalerRefusSuspension;', bac);
  const sanction = { id: 4, type: 'suspension', fin: '2026-12-01T10:00:00Z' };
  assert.equal(bac.f(JSON.stringify({ code: 'P0001', message: 'compte_suspendu', details: JSON.stringify(sanction) })), true);
  assert.equal(recus.length, 1);
  assert.equal(recus[0].raison, 'compte_suspendu');
  assert.equal(recus[0].sanction.fin, sanction.fin);
  assert.equal(bac.f(JSON.stringify({ code: '42501', message: 'new row violates row-level security policy' })), false);
  assert.equal(bac.f('pas du JSON'), false);
  assert.equal(recus.length, 1);
  assert.equal((src.match(/=== 'function'\) sbSignalerRefusSuspension\(texte\)/g) || []).length, 2, 'REST et RPC');
});

test('paiement : TTC partout et codes fiscaux confirmés (plus de question ouverte dans le code)', () => {
  const p = lire('api/_paiement.js');
  assert.match(p, /tax_behavior: 'inclusive'/);
  assert.match(p, /TAX_CODE_ABONNEMENT_DEFAUT = 'txcd_10201004'/);
  assert.match(p, /TAX_CODE_UNITE_DEFAUT = 'txcd_10000000'/);
  assert.ok(!/question à Fred|à confirmer par Fred/.test(p));
});
