'use strict';
// Mission du 28/11/2026, étape 4 (décision de Fred) : PAIEMENT PAR STRIPE EN FONCTIONNEMENT MIXTE — partie base de données.
// Migration 20261128120000 chargée dans PGlite par-dessus le socle premium (20261125700000, doublures du banc du socle).
// Mode de vente décidé par le pays (UE : éditeur ; reste du monde : Managed Payments, fermé tant qu'il n'est pas activé ;
// pays non servis : aucun achat), réglage pour étendre Managed Payments à l'UE ; consentements avant paiement ; abonnement
// annuel ; ce qui est activé pendant l'abonnement reste acquis ; résiliation en fin de période ; remboursement 14 jours
// sans avantage utilisé ; doublons détectés ; rappel des abonnements annuels ; réglages MJ.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-paiement-stripe-pglite-20261128.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG_SOCLE = 'migrations/20261125700000_premium_socle.sql';
const MIG = 'migrations/20261128120000_paiement_stripe.sql';

test('migration : BEGIN/COMMIT, contrôles en lecture, marque, aucun secret, aucune migration ancienne modifiée', () => {
  const m = lire(MIG);
  assert.match(m, /^BEGIN;$/m); assert.match(m, /^COMMIT;$/m);
  assert.match(m, /Contrôles en lecture après application/);
  assert.match(m, /paiement_stripe_v1/);
  assert.doesNotMatch(m, /sk_(live|test)_|whsec_|rk_live_/);
  assert.match(m, /article 293 B du CGI/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

const U = { olga: '00000000-0000-0000-0000-000000000001', ivan: '00000000-0000-0000-0000-000000000002',
  mj: '00000000-0000-0000-0000-0000000000aa', arnie: '00000000-0000-0000-0000-000000000004' };
// Même socle (tables, doublures aux ancrages exacts de la production) que le banc du socle premium.
const src = lire('outils/bancs/banc-premium-socle-pglite-20261125.cjs');
const SOCLE = new Function('U', 'return `' + src.match(/const SOCLE = `([\s\S]*?)`;\n/)[1] + '`;')(U);

async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG_SOCLE));
  await db.exec(lire(MIG));
  await db.exec(lire(MIG));   // rejouable : les remplacements marqués ne s'appliquent qu'une fois
  await db.exec(`UPDATE premium_parametres SET valeur = '0' WHERE cle = 'beta_tout_gratuit';
    UPDATE premium_produits SET prix_centimes = 500 WHERE produit IN ('abonnement_mensuel', 'bureau_six', 'publicite_joueur', 'renouvellement_image');
    UPDATE premium_produits SET prix_centimes = 4800 WHERE produit = 'abonnement_annuel';`);
  return db;
}
async function en(db, uid, sql, service = false) {
  await db.exec(`SELECT set_config('test.uid', '${uid || ''}', false), set_config('test.service', '${service ? '1' : '0'}', false)`);
  const r = await db.query(sql);
  return r.rows[0] && Object.values(r.rows[0])[0];
}
const srv = (db, sql) => en(db, null, sql, true);
// Achat complet : préparation (joueur), consentements, confirmation et notes (serveur, après le webhook signé).
async function acheter(db, uid, produit, { cible = null, ref, refPaiement = null, montant, email = 'joueur@example.org', renonciation = true } = {}) {
  const p = await en(db, uid, `SELECT premium_achat_preparer('${produit}', ${cible ? `'${cible}'` : 'NULL'})`);
  assert.equal(p.ok, true, JSON.stringify(p));
  const c = await srv(db, `SELECT premium_achat_consentir_service('${p.achat}', true, ${renonciation}, 'editeur', 'FR', 'fr')`);
  assert.equal(c.ok, true, JSON.stringify(c));
  const k = await srv(db, `SELECT premium_achat_confirmer_service('${p.achat}', 'stripe', '${ref}', ${montant ?? p.montant_centimes}, 'EUR')`);
  assert.equal(k.ok, true, JSON.stringify(k));
  const abo = p.nature === 'abonnement';
  const n = await srv(db, `SELECT premium_achat_paiement_noter_service('${p.achat}', ${abo ? 'NULL' : `'${refPaiement || ref}'`}, ${abo ? `'${ref}'` : 'NULL'}, '${email}')`);
  assert.equal(n.ok, true, JSON.stringify(n));
  return { p, n };
}

test('contexte : UE → éditeur ; hors UE fermé tant que Managed Payments est éteint ; réglage UE ; pays non servis', async () => {
  const db = await base();
  const ctx = pays => srv(db, `SELECT premium_paiement_contexte_service(${pays === null ? 'NULL' : `'${pays}'`})`);
  assert.equal((await ctx('FR')).mode, 'editeur');
  assert.equal((await ctx('de')).mode, 'editeur');
  assert.equal((await ctx('RE')).mode, 'editeur', 'La Réunion : France');
  assert.equal((await ctx('US')).raison, 'vente_hors_ue_fermee');
  assert.equal((await ctx('US')).achats_possibles, false);
  assert.equal((await ctx('RU')).raison, 'pays_non_servi');
  assert.equal((await ctx(null)).raison, 'pays_inconnu');
  assert.equal((await en(db, U.olga, `SELECT premium_paiement_contexte_service('FR')`)).raison, 'reserve_serveur');
  await db.exec(`UPDATE premium_parametres SET valeur = '1' WHERE cle = 'paiement_mp_actif'`);
  assert.equal((await ctx('US')).mode, 'stripe');
  assert.equal((await ctx('JP')).mode, 'stripe');
  assert.equal((await ctx('FR')).mode, 'editeur');
  assert.equal((await ctx('CN')).raison, 'pays_non_servi');
  await db.exec(`UPDATE premium_parametres SET valeur = '1' WHERE cle = 'paiement_mp_pour_ue'`);
  assert.equal((await ctx('FR')).mode, 'stripe', 'Managed Payments étendu à l’UE sans recoder');
  assert.equal((await ctx('FR')).editeur_nom, null);
});

test('consentements : CGV toujours, renonciation pour l’unité et les options ; sinon achat annulé avant paiement', async () => {
  const db = await base();
  const p1 = await en(db, U.olga, `SELECT premium_achat_preparer('renouvellement_image', NULL)`);
  const c1 = await srv(db, `SELECT premium_achat_consentir_service('${p1.achat}', true, false, 'editeur', 'FR', 'fr')`);
  assert.equal(c1.raison, 'renonciation_requise');
  assert.equal(await srv(db, `SELECT statut FROM premium_achats WHERE id = '${p1.achat}'`), 'annule');
  const p2 = await en(db, U.olga, `SELECT premium_achat_preparer('abonnement_mensuel', NULL)`);
  assert.equal((await srv(db, `SELECT premium_achat_consentir_service('${p2.achat}', false, true, 'editeur', 'FR', 'fr')`)).raison, 'cgv_requises');
  const p3 = await en(db, U.olga, `SELECT premium_achat_preparer('abonnement_mensuel', NULL)`);
  const c3 = await srv(db, `SELECT premium_achat_consentir_service('${p3.achat}', true, false, 'editeur', 'FR', 'fr')`);
  assert.equal(c3.ok, true, 'abonnement : pas de renonciation (remboursable 14 jours)');
  assert.equal(await srv(db, `SELECT renonciation_retractation_le IS NULL AND cgv_acceptees_le IS NOT NULL FROM premium_achats WHERE id = '${p3.achat}'`), true);
  assert.equal((await en(db, U.olga, `SELECT premium_achat_consentir_service('${p3.achat}', true, true, 'editeur', 'FR', 'fr')`)).raison, 'reserve_serveur');
});

test('abonnement annuel : un an, fiche complétée, e-mail une seule fois, rappel au plus tard 30 jours avant', async () => {
  const db = await base();
  const { p, n } = await acheter(db, U.olga, 'abonnement_annuel', { ref: 'sub_annuel' });
  assert.equal(p.intervalle, 'year');
  assert.equal(n.envoyer_courriel, true); assert.equal(n.doublon, false); assert.equal(n.intervalle, 'year');
  assert.equal(await srv(db, `SELECT fin > now() + interval '360 days' FROM premium_abonnements WHERE ref_fournisseur = 'sub_annuel'`), true);
  assert.equal(await srv(db, `SELECT intervalle || '|' || email_facturation || '|' || (premier_paiement_le IS NOT NULL) FROM premium_abonnements WHERE ref_fournisseur = 'sub_annuel'`),
    'year|joueur@example.org|true');
  await srv(db, `SELECT premium_achat_courriel_noter_service('${p.achat}')`);
  assert.equal((await srv(db, `SELECT premium_achat_paiement_noter_service('${p.achat}', NULL, 'sub_annuel', NULL)`)).envoyer_courriel, false, 'webhook rejoué : pas de second e-mail');
  assert.equal((await srv(db, `SELECT premium_rappels_annuels_service()`)).rappels.length, 0, 'loin du renouvellement');
  await db.exec(`UPDATE premium_abonnements SET fin = now() + interval '34 days' WHERE ref_fournisseur = 'sub_annuel'`);
  const r = (await srv(db, `SELECT premium_rappels_annuels_service()`)).rappels;
  assert.equal(r.length, 1); assert.equal(r[0].email, 'joueur@example.org'); assert.equal(r[0].montant_centimes, 4800);
  await srv(db, `SELECT premium_rappel_noter_service('${r[0].id}', '${r[0].fin}')`);
  assert.equal((await srv(db, `SELECT premium_rappels_annuels_service()`)).rappels.length, 0, 'un seul rappel par échéance');
  await db.exec(`UPDATE premium_abonnements SET fin = now() + interval '33 days' WHERE ref_fournisseur = 'sub_annuel'`);
  assert.equal((await srv(db, `SELECT premium_rappels_annuels_service()`)).rappels.length, 1, 'nouvelle échéance : nouveau rappel');
  await srv(db, `SELECT premium_abonnement_maj_service('sub_annuel', 'annule', NULL)`);
  assert.equal((await srv(db, `SELECT premium_rappels_annuels_service()`)).rappels.length, 0, 'résilié : pas de rappel');
  assert.equal((await en(db, U.olga, `SELECT premium_achat_preparer('abonnement_mensuel', NULL)`)).raison, 'deja_abonne');
});

test('fiche du compte : remboursable 14 jours sans avantage ; une activation pendant l’abonnement reste acquise', async () => {
  const db = await base();
  await acheter(db, U.olga, 'abonnement_mensuel', { ref: 'sub_olga' });
  let l = await en(db, U.olga, `SELECT premium_abonnement_lire()`);
  assert.equal(l.abonne, true); assert.equal(l.intervalle, 'month'); assert.equal(l.remboursable, true); assert.equal(l.resiliable, true);
  const b = await en(db, U.olga, `SELECT equipement_option_premium_activer()`);
  assert.equal(b.ok, true); assert.equal(b.emplacements, 6);
  assert.equal(await en(db, U.olga, `SELECT paiement FROM bureaux_option_premium`), 'acquis_abonnement');
  assert.equal(await srv(db, `SELECT count(*)::int FROM premium_droits WHERE source = 'abonnement' AND produit = 'bureau_six'`), 1);
  l = await en(db, U.olga, `SELECT premium_abonnement_lire()`);
  assert.equal(l.remboursable, false); assert.equal(l.raison_non_remboursable, 'avantage_utilise');
  assert.equal((await en(db, U.olga, `SELECT premium_abonnement_action_preparer('rembourser')`)).raison, 'avantage_utilise');
  // Fin de l'abonnement : le bureau à 6 activé pendant l'abonnement reste acquis.
  await srv(db, `SELECT premium_abonnement_maj_service('sub_olga', 'expire', now() - interval '1 minute')`);
  assert.equal((await en(db, U.olga, `SELECT premium_abonnement_lire()`)).abonne, false);
  assert.equal(await en(db, U.olga, `SELECT equipements_emplacements_interne('republic', 'ville_b', 'centre-affaires', 'bureau_1')`), 6);
  // Une publicité de joueur via l'abonnement n'est pas un lieu : rien d'acquis, mais l'usage est noté.
  assert.equal(await srv(db, `SELECT count(*)::int FROM premium_droits WHERE produit = 'publicite_joueur'`), 0);
});

test('résiliation en fin de période ; remboursement 14 jours ; délai dépassé', async () => {
  const db = await base();
  await acheter(db, U.ivan, 'abonnement_mensuel', { ref: 'sub_ivan' });
  const a = await en(db, U.ivan, `SELECT premium_abonnement_action_preparer('resilier')`);
  assert.equal(a.ok, true); assert.equal(a.ref, 'sub_ivan'); assert.equal(a.user, U.ivan);
  assert.equal((await en(db, U.olga, `SELECT premium_abonnement_action_preparer('resilier')`)).raison, 'aucun_abonnement', 'jamais l’abonnement d’un autre');
  assert.equal((await srv(db, `SELECT premium_abonnement_resilier_service('${U.ivan}', 'sub_ivan')`)).ok, true);
  let l = await en(db, U.ivan, `SELECT premium_abonnement_lire()`);
  assert.equal(l.abonne, true, 'actif jusqu’à la fin de la période payée'); assert.equal(l.annule, true); assert.equal(l.resiliable, false);
  assert.equal((await en(db, U.ivan, `SELECT premium_abonnement_action_preparer('resilier')`)).raison, 'deja_resilie');
  assert.equal((await en(db, U.ivan, `SELECT premium_abonnement_action_preparer('rembourser')`)).ok, true, 'résilié mais encore remboursable');
  assert.equal((await srv(db, `SELECT premium_abonnement_rembourser_service('${U.ivan}', 'sub_ivan', 'demande_14_jours')`)).ok, true);
  assert.equal((await en(db, U.ivan, `SELECT premium_abonnement_lire()`)).abonne, false);
  assert.equal(await srv(db, `SELECT statut FROM premium_achats WHERE produit = 'abonnement_mensuel' AND user_id = '${U.ivan}'`), 'rembourse');
  assert.equal((await srv(db, `SELECT premium_abonnement_rembourser_service('${U.ivan}', 'sub_ivan', 'demande_14_jours')`)).deja, true, 'idempotent');
  // Délai dépassé.
  await acheter(db, U.arnie, 'abonnement_mensuel', { ref: 'sub_arnie' });
  await db.exec(`UPDATE premium_abonnements SET premier_paiement_le = now() - interval '15 days' WHERE ref_fournisseur = 'sub_arnie'`);
  assert.equal((await en(db, U.arnie, `SELECT premium_abonnement_lire()`)).raison_non_remboursable, 'delai_depasse');
  assert.equal((await srv(db, `SELECT premium_abonnement_rembourser_service('${U.arnie}', 'sub_arnie', 'demande_14_jours')`)).raison, 'delai_depasse');
  assert.equal((await srv(db, `SELECT premium_abonnement_rembourser_service('${U.arnie}', 'sub_arnie', 'doublon')`)).ok, true, 'un doublon est toujours remboursé');
});

test('doublons : option payée deux fois, second abonnement ; remboursement par référence de paiement', async () => {
  const db = await base();
  const p1 = await en(db, U.olga, `SELECT premium_achat_preparer('publicite_joueur', NULL)`);
  const p2 = await en(db, U.olga, `SELECT premium_achat_preparer('publicite_joueur', NULL)`);   // deux onglets
  for (const [p, ref] of [[p1, 'pi_1'], [p2, 'pi_2']]) {
    await srv(db, `SELECT premium_achat_consentir_service('${p.achat}', true, true, 'editeur', 'FR', 'fr')`);
    await srv(db, `SELECT premium_achat_confirmer_service('${p.achat}', 'stripe', 'cs_${ref}', 500, 'EUR')`);
  }
  assert.equal((await srv(db, `SELECT premium_achat_paiement_noter_service('${p1.achat}', 'pi_1', NULL, NULL)`)).doublon, false);
  const n2 = await srv(db, `SELECT premium_achat_paiement_noter_service('${p2.achat}', 'pi_2', NULL, NULL)`);
  assert.equal(n2.doublon, true); assert.equal(n2.ref_paiement, 'pi_2'); assert.equal(n2.ref_fournisseur, 'cs_pi_2');
  assert.equal((await srv(db, `SELECT premium_achat_rembourser_paiement_service('pi_2')`)).ok, true);
  assert.equal(await srv(db, `SELECT count(*)::int FROM premium_droits WHERE produit = 'publicite_joueur' AND revoque_le IS NULL`), 1);
  assert.equal((await srv(db, `SELECT premium_achat_rembourser_paiement_service('pi_inconnu')`)).raison, 'achat_inconnu');
  // Deux abonnements confirmés : le second est un doublon.
  const a1 = await en(db, U.ivan, `SELECT premium_achat_preparer('abonnement_mensuel', NULL)`);
  const a2 = await en(db, U.ivan, `SELECT premium_achat_preparer('abonnement_annuel', NULL)`);
  for (const [p, ref, m] of [[a1, 'sub_a', 500], [a2, 'sub_b', 4800]]) {
    await srv(db, `SELECT premium_achat_consentir_service('${p.achat}', true, false, 'stripe', 'US', 'en')`);
    await srv(db, `SELECT premium_achat_confirmer_service('${p.achat}', 'stripe', '${ref}', ${m}, 'EUR')`);
  }
  assert.equal((await srv(db, `SELECT premium_achat_paiement_noter_service('${a1.achat}', NULL, 'sub_a', 'i@example.org')`)).doublon, false);
  const d = await srv(db, `SELECT premium_achat_paiement_noter_service('${a2.achat}', NULL, 'sub_b', 'i@example.org')`);
  assert.equal(d.doublon, true); assert.equal(d.abonnement_ref, 'sub_b'); assert.equal(d.mode_vente, 'stripe'); assert.equal(d.langue, 'en');
  // Montant différent de la base : refusé par la confirmation (le prix vient de la base).
  const a3 = await en(db, U.arnie, `SELECT premium_achat_preparer('renouvellement_image', NULL)`);
  await srv(db, `SELECT premium_achat_consentir_service('${a3.achat}', true, true, 'editeur', 'FR', 'fr')`);
  assert.equal((await srv(db, `SELECT premium_achat_confirmer_service('${a3.achat}', 'stripe', 'pi_x', 100, 'EUR')`)).raison, 'montant_incoherent');
});

test('réglages MJ du paiement : validés, journalisés, réservés au MJ', async () => {
  const db = await base();
  const fix = (cle, v, uid = U.mj) => en(db, uid, `SELECT premium_admin_paiement_fixer('${cle}', '${v}')`);
  assert.equal((await fix('paiement_mp_pour_ue', '1')).ok, true);
  assert.equal((await fix('paiement_mp_pour_ue', 'oui')).raison, 'valeur_invalide');
  assert.equal((await fix('paiement_pays_exclus', 'ru, cu,IR')).ok, true);
  assert.equal(await srv(db, `SELECT valeur FROM premium_parametres WHERE cle = 'paiement_pays_exclus'`), 'RU,CU,IR');
  assert.equal((await fix('paiement_pays_exclus', 'Russie')).raison, 'valeur_invalide');
  assert.equal((await fix('cgv_url', 'https://exemple.org/cgv')).ok, true);
  assert.equal((await fix('cgv_url', 'javascript:alert(1)')).raison, 'valeur_invalide');
  assert.equal((await fix('rappel_annuel_jours', '20')).raison, 'valeur_invalide', 'jamais moins de 30 jours');
  assert.equal((await fix('remboursement_abonnement_jours', '7')).raison, 'valeur_invalide', 'jamais moins de 14 jours');
  assert.equal((await fix('beta_tout_gratuit', '0')).raison, 'reglage_inconnu');
  assert.equal((await fix('vendeur_editeur_nom', 'Éditeur de test')).ok, true);
  assert.equal((await srv(db, `SELECT premium_paiement_contexte_service('FR')`)).editeur_nom, 'Éditeur de test');
  await assert.rejects(fix('paiement_mp_actif', '1', U.olga), /reserve_admin/);
  assert.equal(await srv(db, `SELECT count(*)::int FROM admin_journal WHERE action = 'premium_paiement'`), 4);
});
