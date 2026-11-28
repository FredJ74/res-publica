// Mission du 28/11/2026, étape 4 (décision de Fred) : PAIEMENT PAR STRIPE EN FONCTIONNEMENT MIXTE — partie serveur.
// Aucun appel réseau : l'API Stripe et l'envoi d'e-mails (Brevo) sont des doublures ; le secret de signature est généré ici.
// Signature Stripe (t=…,v1=…, HMAC-SHA256 de « t.corps », tolérance 300 s, plusieurs v1) ; session Checkout classique
// (éditeur vendeur, mention 293 B, adresse de facturation) ou Managed Payments (managed_payments[enabled], aucun paramètre
// interdit) ; prix de la base ; consentements ; pays de Vercel ; événements (achat, abonnement, résiliation, remboursement,
// doublon) ; résiliation et remboursement demandés par le joueur ; e-mails dans 9 langues ; rappel annuel ; cron ; 12 fonctions.
// Lancer : node --test outils/bancs/banc-paiement-stripe-20261128.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { fileURLToPath } from 'node:url';
import { creerHandlerPaiement, signerStripe, verifierSignatureStripe, paramsSessionCheckout, formulaireStripe, fournisseurStripe,
  traiterEvenement, paysDeLaRequete, envoyerRappelsAnnuels } from '../../api/_paiement.js';
import { TEXTES_COURRIEL, LANGUES_COURRIEL, courrielConfirmation, courrielRappelAnnuel } from '../../api/_paiement-courriels.js';
import { envoyerCourriel } from '../../api/_courriel.js';   // Brevo depuis le 28/11/2026 au soir

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const SECRET = 'whsec_banc_' + crypto.randomBytes(24).toString('hex');   // généré par le banc, jamais un vrai secret

function reponse() { const r = { code: 0, corps: null }; r.status = c => { r.code = c; return r; }; r.json = j => { r.corps = j; return r; }; r.end = () => r; return r; }
const requeteBrute = (corps, entetes, query) => Object.assign(Readable.from([Buffer.from(corps)]), { method: 'POST', headers: entetes || {}, query });
const un = d => ({ etat: 'ok', donnees: d });

test('signature Stripe : t et v1, corps brut, tolérance, plusieurs v1, entrées inconnues tolérées', () => {
  const t = Math.floor(Date.now() / 1000), corps = '{"id":"evt_1","type":"checkout.session.completed"}';
  const h = signerStripe(corps, SECRET, t);
  assert.match(h, /^t=\d+,v1=[0-9a-f]{64}$/);
  const attendu = crypto.createHmac('sha256', SECRET).update(`${t}.${corps}`).digest('hex');
  assert.equal(h, `t=${t},v1=${attendu}`, 'HMAC-SHA256 de « t.corps » avec le secret tel quel');
  assert.ok(verifierSignatureStripe(corps, h, SECRET));
  assert.ok(verifierSignatureStripe(corps, `t=${t},v1=${'0'.repeat(64)},v1=${attendu},v0=abc,secret=whsec_****,destination=we_1`, SECRET), 'rotation du secret, métadonnées');
  assert.ok(!verifierSignatureStripe(corps, `v1=${attendu}`, SECRET), 'sans t');
  assert.ok(!verifierSignatureStripe(JSON.stringify(JSON.parse(corps), null, 1), h, SECRET), 'corps ré-sérialisé');
  assert.ok(!verifierSignatureStripe(corps, signerStripe(corps, SECRET, t - 301), SECRET), 'hors tolérance');
  assert.ok(verifierSignatureStripe(corps, signerStripe(corps, SECRET, t - 299), SECRET));
  assert.ok(!verifierSignatureStripe(corps, h, 'whsec_autre'));
  assert.ok(!verifierSignatureStripe(corps, h, ''));
});

test('formulaire encodé : objets et tableaux imbriqués', () => {
  const f = new URLSearchParams(formulaireStripe({ mode: 'payment', line_items: [{ quantity: 1, price_data: { unit_amount: 500 } }], m: { enabled: true }, vide: null }));
  assert.equal(f.get('line_items[0][price_data][unit_amount]'), '500');
  assert.equal(f.get('m[enabled]'), 'true');
  assert.ok(!f.has('vide'));
});

const ACHAT = { achat: 'a-42', produit: 'bureau_six', nature: 'option', libelle: 'Bureau à 6 emplacements', montant_centimes: 300, renonciation: true };
test('session Checkout classique (UE) : éditeur vendeur, mention 293 B, facture, adresse de facturation, prix de la base', () => {
  const p = paramsSessionCheckout(ACHAT, { mode: 'editeur', langue: 'de', editeurNom: 'Éditeur Test', urlSite: 'https://hg.example' });
  assert.equal(p.mode, 'payment'); assert.equal(p.client_reference_id, 'a-42');
  assert.equal(p.line_items[0].price_data.unit_amount, 300); assert.equal(p.line_items[0].price_data.currency, 'eur');
  assert.equal(p.managed_payments, undefined);
  assert.match(p.custom_text.submit.message, /Vendeur : Éditeur Test\. TVA non applicable, article 293 B du CGI\./);
  assert.match(p.invoice_creation.invoice_data.footer, /293 B du CGI.*renoncé expressément à son droit de rétractation/);
  assert.equal(p.billing_address_collection, 'required');
  assert.equal(p.payment_intent_data.metadata.achat_id, 'a-42');
  assert.equal(p.locale, 'de'); assert.match(p.success_url, /^https:\/\/hg\.example\/plateau\.html\?paiement=ok/);
  const s = paramsSessionCheckout({ ...ACHAT, produit: 'abonnement_annuel', nature: 'abonnement', intervalle: 'year', montant_centimes: 4800, renonciation: false },
    { mode: 'editeur', langue: 'ar', editeurNom: 'X' });
  assert.equal(s.mode, 'subscription'); assert.equal(s.line_items[0].price_data.recurring.interval, 'year');
  assert.equal(s.subscription_data.metadata.achat_id, 'a-42'); assert.equal(s.invoice_creation, undefined, 'facture d’abonnement : pied réglé dans Stripe');
  assert.equal(s.locale, 'auto', 'arabe absent des langues de Checkout');
});

test('session Managed Payments (hors UE) : managed_payments[enabled], code fiscal éligible, aucun paramètre non pris en charge', () => {
  for (const a of [ACHAT, { ...ACHAT, nature: 'abonnement', produit: 'abonnement_mensuel', intervalle: 'month' }]) {
    const p = paramsSessionCheckout(a, { mode: 'stripe', langue: 'ko', editeurNom: 'Éditeur Test' });
    assert.deepEqual(p.managed_payments, { enabled: true });
    assert.match(p.line_items[0].price_data.product_data.tax_code, /^txcd_\d{8}$/);
    // Liste des paramètres non pris en charge (docs.stripe.com/payments/managed-payments/update-checkout).
    for (const interdit of ['automatic_tax', 'tax_id_collection', 'payment_method_types', 'payment_method_configuration', 'excluded_payment_method_types',
      'adaptive_pricing', 'shipping_address_collection', 'shipping_options', 'invoice_creation', 'customer_update'])
      assert.equal(p[interdit], undefined, interdit);
    const d = p.payment_intent_data || {}, s = p.subscription_data || {};
    for (const k of ['statement_descriptor', 'statement_descriptor_suffix', 'receipt_email', 'shipping', 'application_fee_amount', 'on_behalf_of', 'transfer_data'])
      assert.equal(d[k], undefined, 'payment_intent_data.' + k);
    for (const k of ['invoice_settings', 'default_tax_rates', 'application_fee_percent', 'on_behalf_of', 'transfer_data']) assert.equal(s[k], undefined, 'subscription_data.' + k);
  }
  assert.equal(paramsSessionCheckout({ ...ACHAT, nature: 'abonnement', intervalle: 'month' }, { mode: 'stripe' }, { STRIPE_TAX_CODE_ABONNEMENT: 'txcd_10103000' })
    .line_items[0].price_data.product_data.tax_code, 'txcd_10103000', 'code fiscal réglable dans Vercel');
});

test('fournisseur Stripe : appels REST (version figée, idempotence), clé réelle refusée hors production', async () => {
  const appels = [];
  const fetchFn = async (url, init) => {
    appels.push({ url, init });
    if (url.endsWith('/checkout/sessions')) return { ok: true, json: async () => ({ id: 'cs_test_1', url: 'https://checkout.stripe.com/c/pay/cs_test_1' }) };
    if (url.includes('/invoices?')) return { ok: true, json: async () => ({ data: [{ id: 'in_1', payments: { data: [{ payment: { type: 'payment_intent', payment_intent: 'pi_abo' } }] } }] }) };
    if (url.endsWith('/refunds')) return { ok: true, json: async () => ({ id: 're_1' }) };
    if (init.method === 'DELETE') return { ok: true, json: async () => ({ id: 'sub_1', status: 'canceled' }) };
    return { ok: true, json: async () => ({ id: 'sub_1', cancel_at_period_end: true }) };
  };
  const f = fournisseurStripe({ STRIPE_SECRET_KEY: 'sk_test_banc', STRIPE_WEBHOOK_SECRET: SECRET }, fetchFn);
  assert.equal(f.pret, true);
  assert.deepEqual(await f.creerPaiement(ACHAT, { mode: 'editeur', editeurNom: 'X' }), { ref: 'cs_test_1', url: 'https://checkout.stripe.com/c/pay/cs_test_1' });
  assert.equal(appels[0].init.headers['Stripe-Version'], '2025-03-31.basil');
  assert.equal(appels[0].init.headers['Idempotency-Key'], 'achat-a-42');
  assert.equal(appels[0].init.headers.Authorization, 'Bearer sk_test_banc');
  assert.equal(new URLSearchParams(appels[0].init.body).get('line_items[0][price_data][unit_amount]'), '300');
  assert.equal((await f.resilier('sub_1')).ok, true);
  assert.equal(new URLSearchParams(appels[1].init.body).get('cancel_at_period_end'), 'true');
  assert.equal((await f.rembourserAbonnement('sub_1')).ok, true);
  assert.equal(new URLSearchParams(appels.find(a => a.url.endsWith('/refunds')).init.body).get('payment_intent'), 'pi_abo');
  assert.ok(appels.some(a => a.init.method === 'DELETE' && a.url.endsWith('/subscriptions/sub_1')), 'fin immédiate après remboursement');
  assert.equal(fournisseurStripe({ STRIPE_SECRET_KEY: 'sk_live_x', STRIPE_WEBHOOK_SECRET: 's', VERCEL_ENV: 'preview' }, fetchFn).pret, false);
  assert.equal(fournisseurStripe({ STRIPE_SECRET_KEY: 'sk_live_x', STRIPE_WEBHOOK_SECRET: 's', VERCEL_ENV: 'production' }, fetchFn).pret, true);
});

test('pays : en-tête de Vercel seulement ; défaut réservé au faux fournisseur', () => {
  assert.equal(paysDeLaRequete({ headers: { 'x-vercel-ip-country': 'fr' } }, {}, { nom: 'stripe' }), 'FR');
  assert.equal(paysDeLaRequete({ headers: {} }, { PAIEMENT_PAYS_DEFAUT: 'FR' }, { nom: 'stripe' }), null);
  assert.equal(paysDeLaRequete({ headers: {} }, { PAIEMENT_PAYS_DEFAUT: 'FR' }, { nom: 'faux' }), 'FR');
});

// Base factice : retient les appels, rend des réponses plausibles.
function base(ctx = { ok: true, pays: 'FR', ue: true, achats_possibles: true, mode: 'editeur', editeur_nom: 'Éditeur Test', cgv_url: 'https://hg.example/cgv' }, extra = {}) {
  const appels = [];
  const rpc = async (fn, params, options) => {
    appels.push({ fn, params, options });
    if (extra[fn]) return un(typeof extra[fn] === 'function' ? extra[fn](params) : extra[fn]);
    if (fn === 'premium_paiement_contexte_service') return un(ctx);
    if (fn === 'premium_achat_preparer') return un({ ok: true, achat: 'a-1', produit: params.p_produit, nature: params.p_produit.startsWith('abonnement') ? 'abonnement' : 'unite',
      libelle: 'Produit', montant_centimes: 500, intervalle: params.p_produit === 'abonnement_annuel' ? 'year' : null });
    if (fn === 'premium_achat_consentir_service') return un(params.p_cgv ? { ok: true } : { ok: false, raison: 'cgv_requises' });
    return un({ ok: true });
  };
  return { rpc, appels };
}
const envStripe = { PAIEMENT_FOURNISSEUR: 'stripe', STRIPE_SECRET_KEY: 'sk_test_banc', STRIPE_WEBHOOK_SECRET: SECRET };
const fetchSession = async () => ({ ok: true, json: async () => ({ id: 'cs_test_9', url: 'https://checkout.stripe.com/c/pay/cs_test_9' }) });

test('commande : pays de Vercel → contexte ; consentements avant le paiement ; vendeur rendu au joueur', async () => {
  const { rpc, appels } = base();
  const h = creerHandlerPaiement({ env: envStripe, rpc, auth: async () => ({ jeton: 'jj' }), serviceDispo: () => true, fetch: fetchSession });
  const res = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: { 'x-vercel-ip-country': 'FR', host: 'hg.example' },
    body: { action: 'commander', produit: 'abonnement_annuel', cgv: true, renonciation: false, langue: 'es', pays: 'US' } }, res);
  assert.deepEqual(res.corps, { ok: true, url: 'https://checkout.stripe.com/c/pay/cs_test_9', achat: 'a-1', vendeur: 'editeur' });
  assert.deepEqual(appels.map(a => a.fn), ['premium_paiement_contexte_service', 'premium_achat_preparer', 'premium_achat_consentir_service', 'premium_achat_lier_service']);
  assert.equal(appels[0].params.p_pays, 'FR', 'le pays vient de Vercel, jamais du navigateur');
  assert.deepEqual(appels[2].params, { p_achat: 'a-1', p_cgv: true, p_renonciation: false, p_mode: 'editeur', p_pays: 'FR', p_langue: 'es' });
  assert.equal(appels[3].params.p_ref, 'cs_test_9');
  // Sans case CGV : la base refuse, aucun paiement n'est créé.
  const b2 = base(); let sessions = 0;
  const h2 = creerHandlerPaiement({ env: envStripe, rpc: b2.rpc, auth: async () => ({ jeton: 'jj' }), serviceDispo: () => true, fetch: async () => { sessions++; return fetchSession(); } });
  const r2 = reponse();
  await h2({ method: 'POST', query: { mode: 'paiement' }, headers: { 'x-vercel-ip-country': 'FR' }, body: { action: 'commander', produit: 'renouvellement_image', cgv: 'true' } }, r2);
  assert.equal(r2.corps.raison, 'cgv_requises'); assert.equal(sessions, 0);
});

test('commande refusée : pays non servi, hors UE fermé, CGV ou vendeur non configurés', async () => {
  const cas = [[{ ok: true, achats_possibles: false, raison: 'pays_non_servi' }, 'pays_non_servi'],
    [{ ok: true, achats_possibles: false, raison: 'vente_hors_ue_fermee' }, 'vente_hors_ue_fermee'],
    [{ ok: true, achats_possibles: true, mode: 'editeur', editeur_nom: 'X', cgv_url: null }, 'cgv_non_publiees'],
    [{ ok: true, achats_possibles: true, mode: 'editeur', editeur_nom: null, cgv_url: '/cgv' }, 'vendeur_non_configure']];
  for (const [ctx, raison] of cas) {
    const { rpc, appels } = base(ctx);
    const h = creerHandlerPaiement({ env: envStripe, rpc, auth: async () => ({ jeton: 'jj' }), serviceDispo: () => true, fetch: fetchSession });
    const res = reponse();
    await h({ method: 'POST', query: { mode: 'paiement' }, headers: { 'x-vercel-ip-country': 'RU' }, body: { action: 'commander', produit: 'bureau_six', cgv: true, renonciation: true } }, res);
    assert.equal(res.corps.raison, raison); assert.ok(!appels.some(a => a.fn === 'premium_achat_preparer'), raison + ' : aucun achat créé');
    const e = reponse();
    await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'etat' } }, e);
    assert.equal(e.corps.achats_possibles, false); assert.equal(e.corps.raison, raison);
  }
  const { rpc } = base({ ok: true, achats_possibles: true, mode: 'stripe', cgv_url: '/cgv' });
  const e = reponse();
  await creerHandlerPaiement({ env: envStripe, rpc, auth: async () => ({ jeton: 'jj' }), serviceDispo: () => true })({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'etat' } }, e);
  assert.equal(e.corps.vendeur, 'stripe'); assert.equal(e.corps.achats_possibles, true, 'Managed Payments : Stripe vendeur, nom de l’éditeur non exigé');
});

test('webhook Stripe : signature, confirmation au montant hors taxes en euros, e-mail une fois, rejeu idempotent', async () => {
  const mails = [];
  const fetchMail = async (url, init) => { const corps = JSON.parse(init.body); mails.push({ url, corps, cle: corps.headers && corps.headers.idempotencyKey, cleApi: init.headers['api-key'] }); return { ok: true, status: 201, json: async () => ({ messageId: '<m@brevo>' }) }; };
  const noter = { ok: true, achat: 'a-1', user: 'u-1', produit: 'bureau_six', libelle: 'Bureau à 6 emplacements', nature: 'option', montant_centimes: 300,
    langue: 'de', mode_vente: 'editeur', renonciation: true, envoyer_courriel: true, doublon: false, ref_fournisseur: 'cs_1', ref_paiement: 'pi_1' };
  const { rpc, appels } = base(undefined, { premium_achat_confirmer_service: { ok: true }, premium_achat_paiement_noter_service: noter });
  const env = { ...envStripe, BREVO_API_KEY: 'brevo_banc' };
  const h = creerHandlerPaiement({ env, rpc, serviceDispo: () => true, fetch: fetchMail });
  const ev = JSON.stringify({ id: 'evt_1', type: 'checkout.session.completed', data: { object: { id: 'cs_1', object: 'checkout.session', mode: 'payment',
    payment_status: 'paid', client_reference_id: 'a-1', payment_intent: 'pi_1', amount_subtotal: 300, amount_total: 300, currency: 'eur',
    presentment_details: { presentment_amount: 410, presentment_currency: 'usd' }, customer_details: { email: 'k@example.org' } } } });
  const r = reponse();
  await h(requeteBrute(ev, { 'stripe-signature': signerStripe(ev, SECRET, Math.floor(Date.now() / 1000)) }, { mode: 'paiement_webhook' }), r);
  assert.equal(r.code, 200);
  const conf = appels.find(a => a.fn === 'premium_achat_confirmer_service');
  assert.deepEqual(conf.params, { p_achat: 'a-1', p_fournisseur: 'stripe', p_ref: 'pi_1', p_montant: 300, p_devise: 'EUR' });
  assert.deepEqual(appels.find(a => a.fn === 'premium_achat_paiement_noter_service').params, { p_achat: 'a-1', p_ref_paiement: 'pi_1', p_abonnement_ref: null, p_email: 'k@example.org' });
  assert.equal(mails.length, 1); assert.equal(mails[0].url, 'https://api.brevo.com/v3/smtp/email'); assert.equal(mails[0].cleApi, 'brevo_banc');
  assert.deepEqual(mails[0].corps.to, [{ email: 'k@example.org' }]); assert.equal(mails[0].cle, 'achat-a-1');
  assert.deepEqual(mails[0].corps.sender, { name: 'Human Gambit', email: 'noreply@human-gambit.com' });
  assert.deepEqual(mails[0].corps.replyTo, { name: 'Human Gambit', email: 'contact@human-gambit.com' });
  assert.match(mails[0].corps.textContent, /Verkäufer: Éditeur Test/); assert.match(mails[0].corps.textContent, /293 B/); assert.match(mails[0].corps.textContent, /Widerrufsrecht/);
  assert.match(mails[0].corps.htmlContent, /<html lang="de">/);
  assert.ok(appels.some(a => a.fn === 'premium_achat_courriel_noter_service'));
  // Sans signature : 400, rien en base.
  const b = base(); const r2 = reponse();
  await creerHandlerPaiement({ env, rpc: b.rpc, serviceDispo: () => true })(requeteBrute(ev, {}, { mode: 'paiement_webhook' }), r2);
  assert.equal(r2.code, 400); assert.equal(b.appels.length, 0);
  // Paiement différé non encore réglé : ignoré.
  const b3 = base();
  assert.deepEqual(await traiterEvenement({ type: 'checkout.session.completed', data: { object: { payment_status: 'unpaid', client_reference_id: 'a' } } },
    { rpc: b3.rpc, fournisseur: { nom: 'stripe' } }), { etat: 'ignore' });
  // Base indisponible : 500, Stripe réessaiera.
  const h4 = creerHandlerPaiement({ env, rpc: async () => ({ etat: 'erreur' }), serviceDispo: () => true });
  const r4 = reponse();
  await h4(requeteBrute(ev, { 'stripe-signature': signerStripe(ev, SECRET, Math.floor(Date.now() / 1000)) }, { mode: 'paiement_webhook' }), r4);
  assert.equal(r4.code, 500);
});

test('événements d’abonnement : renouvellement, résiliation programmée, fin ; remboursement d’un achat à l’unité', async () => {
  const { rpc, appels } = base();
  const f = { nom: 'stripe' };
  const fin = 1798761600; // 2027-01-01
  await traiterEvenement({ type: 'customer.subscription.updated', data: { object: { id: 'sub_1', status: 'active', cancel_at_period_end: false,
    items: { data: [{ current_period_end: fin }] } } } }, { rpc, fournisseur: f });
  await traiterEvenement({ type: 'customer.subscription.updated', data: { object: { id: 'sub_1', status: 'active', cancel_at_period_end: true,
    cancel_at: fin, items: { data: [{ current_period_end: fin }] } } } }, { rpc, fournisseur: f });
  await traiterEvenement({ type: 'customer.subscription.deleted', data: { object: { id: 'sub_1', status: 'canceled', ended_at: fin } } }, { rpc, fournisseur: f });
  await traiterEvenement({ type: 'customer.subscription.updated', data: { object: { id: 'sub_2', status: 'incomplete' } } }, { rpc, fournisseur: f });
  await traiterEvenement({ type: 'charge.refunded', data: { object: { id: 'ch_1', refunded: true, payment_intent: 'pi_9' } } }, { rpc, fournisseur: f });
  await traiterEvenement({ type: 'charge.refunded', data: { object: { id: 'ch_2', refunded: false, payment_intent: 'pi_8' } } }, { rpc, fournisseur: f });
  assert.deepEqual(appels.map(a => [a.fn, a.params.p_statut || a.params.p_ref_paiement, a.params.p_fin || null]), [
    ['premium_abonnement_maj_service', 'actif', '2027-01-01T00:00:00.000Z'],
    ['premium_abonnement_maj_service', 'annule', '2027-01-01T00:00:00.000Z'],
    ['premium_abonnement_maj_service', 'expire', '2027-01-01T00:00:00.000Z'],
    ['premium_achat_rembourser_paiement_service', 'pi_9', null]]);
});

test('doublon : remboursé automatiquement chez Stripe puis en base, sans e-mail de confirmation d’achat', async () => {
  const fournis = { nom: 'stripe', rembourses: [], async rembourserAbonnement(r) { this.rembourses.push(r); return { ok: true }; }, async rembourserPaiement(r) { this.rembourses.push(r); return { ok: true }; } };
  const { rpc, appels } = base(undefined, { premium_achat_confirmer_service: { ok: true },
    premium_achat_paiement_noter_service: { ok: true, achat: 'a-2', user: 'u-1', nature: 'abonnement', libelle: 'Abonnement mensuel', montant_centimes: 500,
      doublon: true, abonnement_ref: 'sub_b', envoyer_courriel: false } });
  await traiterEvenement({ type: 'checkout.session.completed', data: { object: { id: 'cs_2', mode: 'subscription', payment_status: 'paid', client_reference_id: 'a-2',
    subscription: 'sub_b', amount_subtotal: 500, currency: 'eur' } } }, { rpc, fournisseur: fournis });
  assert.deepEqual(fournis.rembourses, ['sub_b']);
  assert.deepEqual(appels.find(a => a.fn === 'premium_abonnement_rembourser_service').params, { p_user: 'u-1', p_ref: 'sub_b', p_motif: 'doublon' });
  const echec = { nom: 'stripe', async rembourserPaiement() { return { ok: false }; } };
  const b = base(undefined, { premium_achat_confirmer_service: { ok: true }, premium_achat_paiement_noter_service: { ok: true, nature: 'option', doublon: true, ref_paiement: 'pi_2' } });
  assert.equal((await traiterEvenement({ type: 'checkout.session.completed', data: { object: { mode: 'payment', payment_status: 'paid', client_reference_id: 'a-3',
    payment_intent: 'pi_2', amount_subtotal: 500, currency: 'eur' } } }, { rpc: b.rpc, fournisseur: echec })).etat, 'erreur', 'Stripe réessaiera');
});

test('résilier et rembourser depuis la fiche du compte : référence obtenue avec le jeton du joueur, Stripe d’abord', async () => {
  const fetchs = [];
  const fetchFn = async (url, init) => { fetchs.push({ url, init }); return { ok: true, json: async () => ({ id: 'sub_9', cancel_at_period_end: true }) }; };
  const { rpc, appels } = base(undefined, { premium_abonnement_action_preparer: p => p.p_action === 'resilier'
    ? { ok: true, ref: 'sub_9', fournisseur: 'stripe', fin: '2027-01-01T00:00:00Z', user: 'u-9' } : { ok: false, raison: 'avantage_utilise' },
    premium_abonnement_resilier_service: { ok: true, fin: '2027-01-01T00:00:00Z' } });
  const h = creerHandlerPaiement({ env: envStripe, rpc, auth: async () => ({ jeton: 'jj' }), serviceDispo: () => true, fetch: fetchFn });
  const r = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'resilier' } }, r);
  assert.deepEqual(r.corps, { ok: true, fin: '2027-01-01T00:00:00Z' });
  assert.equal(appels[0].options.jeton, 'jj');
  assert.match(fetchs[0].url, /\/subscriptions\/sub_9$/);
  assert.deepEqual(appels.find(a => a.fn === 'premium_abonnement_resilier_service').params, { p_user: 'u-9', p_ref: 'sub_9' });
  const r2 = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'rembourser_abonnement' } }, r2);
  assert.equal(r2.corps.raison, 'avantage_utilise'); assert.equal(fetchs.length, 1, 'aucun appel à Stripe si la base refuse');
});

test('e-mails : 9 langues complètes ; vendeur Stripe hors UE ; rappel annuel ; envoi fermé sans clé', async () => {
  assert.deepEqual(Object.keys(TEXTES_COURRIEL).sort(), [...LANGUES_COURRIEL].sort());
  const cles = Object.keys(TEXTES_COURRIEL.fr).sort();
  for (const l of LANGUES_COURRIEL) assert.deepEqual(Object.keys(TEXTES_COURRIEL[l]).sort(), cles, l);
  const m = courrielConfirmation({ langue: 'en', libelle: 'Yearly subscription', montant_centimes: 4800, nature: 'abonnement', intervalle: 'year', mode_vente: 'stripe' });
  assert.match(m.texte, /Stripe \(Link\), merchant of record/); assert.doesNotMatch(m.texte, /293 B/, 'pas de mention de franchise quand Stripe vend');
  assert.match(m.texte, /yearly subscription renews automatically/); assert.match(m.texte, /14 days/);
  const r = courrielRappelAnnuel({ langue: 'fr', fin: '2027-03-15T10:00:00Z', montant_centimes: 4800 });
  assert.match(r.sujet, /15 mars 2027/); assert.match(r.texte, /48,00\s€/);
  assert.deepEqual(await envoyerCourriel({ a: 'x@example.org', sujet: 's', texte: 't' }, { env: {}, journal: null }), { ok: false, raison: 'cle_absente', detail: 'BREVO_API_KEY absente de l’environnement' });
});

test('rappel annuel (cron) : envoi puis note ; arrêt propre sans service d’e-mail', async () => {
  const notes = [];
  const rpc = async (fn, p) => {
    if (fn === 'premium_rappels_annuels_service') return un({ ok: true, rappels: [{ id: 'ab-1', email: 'a@example.org', langue: 'pt-BR', fin: '2027-02-01T00:00:00Z', montant_centimes: 4800 }] });
    notes.push([fn, p]); return un({ ok: true });
  };
  const mails = [];
  const ok = await envoyerRappelsAnnuels({ rpc, env: { BREVO_API_KEY: 'k' }, serviceDispo: () => true,
    fetchFn: async (u, i) => { mails.push(JSON.parse(i.body)); return { ok: true, status: 201, json: async () => ({ messageId: '<r@brevo>' }) }; } });
  assert.deepEqual(ok, { ok: true, envoyes: 1, echecs: 0 });
  assert.match(mails[0].subject, /assinatura anual/); assert.deepEqual(notes, [['premium_rappel_noter_service', { p_id: 'ab-1', p_fin: '2027-02-01T00:00:00Z' }]]);
  notes.length = 0;
  assert.equal((await envoyerRappelsAnnuels({ rpc, env: {}, serviceDispo: () => true })).raison, 'cle_absente');
  assert.equal(notes.length, 0, 'rien de noté : le rappel partira quand l’e-mail sera configuré');
});

test('raccords : cron de minuit, page MJ, fiche du compte, 12 fonctions, aucune clé dans le dépôt', () => {
  const cron = lire('api/cron-minuit.js');
  assert.match(cron, /import \{ envoyerRappelsAnnuels \} from '\.\/_paiement\.js'/);
  assert.match(cron, /await envoyerRappelsAnnuels\(\)/);
  const fonctions = fs.readdirSync(path.join(root, 'api')).filter(f => f.endsWith('.js') && !f.startsWith('_'));
  assert.ok(fonctions.length <= 12, fonctions.length + ' fonctions');
  for (const f of ['api/_paiement.js', 'api/_paiement-courriels.js', 'api/_courriel.js', 'plateau-paiement.js', 'migrations/20261128120000_paiement_stripe.sql'])
    assert.doesNotMatch(lire(f), /sk_live_[A-Za-z0-9]{6}|sk_test_[A-Za-z0-9]{6}|whsec_[A-Za-z0-9]{6}|xkeysib-[A-Za-z0-9]{6}/, f);
  assert.match(lire('admin-premium.js'), /premium_admin_paiement_fixer/);
  assert.match(lire('plateau-personnage.js'), /rpHtmlAbonnementCompte/);
  assert.match(lire('plateau.html'), /<script src="plateau-paiement\.js\?v=paiement-stripe-20261128"><\/script>/);
});
