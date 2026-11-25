// Mission du soir du 25/11/2026, bloc 4.4 : interface de paiement des options premium (api/_paiement.js), faux fournisseur.
// Signature du webhook vérifiée sur le corps brut ; seul le webhook signé confirme ; le prix vient de la base, jamais du
// navigateur ; le faux fournisseur est interdit en production ; paiement fermé par défaut ; greffe sur chat.js (12 fonctions).
// Lancer : node --test outils/bancs/banc-paiement-premium-20261125.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { fileURLToPath } from 'node:url';
import { creerHandlerPaiement, signerCorps, verifierSignature, choisirFournisseur, traiterEvenement, fournisseurPaddle } from '../../api/_paiement.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const SECRET = 'secret-de-banc';

function reponse() {
  const r = { code: 0, corps: null };
  r.status = c => { r.code = c; return r; };
  r.json = j => { r.corps = j; return r; };
  r.end = () => r;
  return r;
}
function requeteBrute(corps, entetes, query) {
  const req = Readable.from([Buffer.from(corps)]);
  req.method = 'POST'; req.headers = entetes || {}; req.query = query;
  return req;
}
function rpcFactice() {
  const appels = [];
  const rpc = async (fn, params, options) => {
    appels.push({ fn, params, options });
    if (fn === 'premium_achat_preparer') {
      if (params.p_produit === 'sans_prix') return { etat: 'ok', donnees: { ok: false, raison: 'prix_non_fixe' } };
      return { etat: 'ok', donnees: { ok: true, achat: 'a-1', produit: params.p_produit, nature: 'option', libelle: 'Bureau à 6 emplacements', montant_centimes: 300 } };
    }
    return { etat: 'ok', donnees: { ok: true } };
  };
  return { rpc, appels };
}
const envFaux = { PAIEMENT_FOURNISSEUR: 'faux', PAIEMENT_FAUX_SECRET: SECRET, VERCEL_ENV: 'preview' };

test('signature : HMAC du corps brut, horodatage borné, comparaison à temps constant', () => {
  const ts = Math.floor(Date.now() / 1000);
  const corps = '{"a":1}';
  assert.ok(verifierSignature(corps, signerCorps(corps, SECRET, ts), SECRET));
  assert.ok(!verifierSignature(corps + ' ', signerCorps(corps, SECRET, ts), SECRET), 'corps modifié');
  assert.ok(!verifierSignature(corps, signerCorps(corps, 'autre', ts), SECRET), 'mauvais secret');
  assert.ok(!verifierSignature(corps, signerCorps(corps, SECRET, ts - 3600), SECRET), 'trop ancien');
  assert.ok(!verifierSignature(corps, 'ts=1;h1=zz', SECRET));
});

test('fournisseur : fermé par défaut ; faux interdit en production ; Paddle prêt seulement avec ses deux clés', () => {
  assert.equal(choisirFournisseur({}), null);
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'faux', VERCEL_ENV: 'production' }), null);
  assert.equal(choisirFournisseur(envFaux).nom, 'faux');
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'paddle' }).pret, false);
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'paddle', PADDLE_API_KEY: 'k', PADDLE_WEBHOOK_SECRET: 's' }).pret, true);
});

test('commande : prix lu en base avec le jeton du joueur, transaction liée par la clé serveur', async () => {
  const { rpc, appels } = rpcFactice();
  const h = creerHandlerPaiement({ env: envFaux, rpc, auth: async () => ({ jeton: 'jeton-joueur' }), serviceDispo: () => true });
  const res = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'commander', produit: 'bureau_six', cible: 'x', montant: 1 } }, res);
  assert.equal(res.corps.ok, true); assert.match(res.corps.url, /paiement-faux/);
  assert.equal(appels[0].fn, 'premium_achat_preparer'); assert.equal(appels[0].options.jeton, 'jeton-joueur');
  assert.ok(!('p_montant' in appels[0].params), 'le navigateur ne donne jamais le prix');
  assert.equal(appels[1].fn, 'premium_achat_lier_service'); assert.equal(appels[1].options.service, true);
  const res2 = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'commander', produit: 'sans_prix' } }, res2);
  assert.equal(res2.corps.raison, 'prix_non_fixe');
  const res3 = reponse();
  await creerHandlerPaiement({ env: {}, rpc, auth: async () => ({ jeton: 'j' }), serviceDispo: () => true })(
    { method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'commander', produit: 'bureau_six' } }, res3);
  assert.equal(res3.corps.raison, 'paiement_inactif');
});

test('webhook : refusé sans signature valide ; confirmé avec montant et devise transmis à la base', async () => {
  const { rpc, appels } = rpcFactice();
  const h = creerHandlerPaiement({ env: envFaux, rpc, serviceDispo: () => true });
  const ev = JSON.stringify({ event_type: 'transaction.completed', data: { id: 'txn_1', custom_data: { achat_id: 'a-1' },
    items: [{ price: { unit_price: { amount: '300', currency_code: 'EUR' } } }] } });
  const r1 = reponse();
  await h(requeteBrute(ev, { 'paddle-signature': 'ts=1;h1=' + '0'.repeat(64) }, { mode: 'paiement_webhook' }), r1);
  assert.equal(r1.code, 401); assert.equal(appels.length, 0);
  const r2 = reponse();
  await h(requeteBrute(ev, { 'paddle-signature': signerCorps(ev, SECRET, Math.floor(Date.now() / 1000)) }, { mode: 'paiement_webhook' }), r2);
  assert.equal(r2.code, 200);
  assert.deepEqual(appels[0], { fn: 'premium_achat_confirmer_service', options: { service: true },
    params: { p_achat: 'a-1', p_fournisseur: 'faux', p_ref: 'txn_1', p_montant: 300, p_devise: 'EUR' } });
});

test('événements : renouvellement et fin d’abonnement, remboursement', async () => {
  const { rpc, appels } = rpcFactice();
  const f = { nom: 'faux' };
  await traiterEvenement({ event_type: 'transaction.completed', data: { id: 't2', subscription_id: 'sub_1', origin: 'subscription_recurring',
    billing_period: { ends_at: '2027-01-25T00:00:00Z' } } }, { rpc, fournisseur: f });
  await traiterEvenement({ event_type: 'subscription.canceled', data: { id: 'sub_1', status: 'canceled', current_billing_period: null, canceled_at: '2027-01-02T00:00:00Z' } }, { rpc, fournisseur: f });
  await traiterEvenement({ event_type: 'adjustment.updated', data: { action: 'refund', status: 'approved', transaction_id: 'txn_1' } }, { rpc, fournisseur: f });
  assert.deepEqual(appels.map(a => [a.fn, a.params.p_statut || a.params.p_ref]), [
    ['premium_abonnement_maj_service', 'actif'], ['premium_abonnement_maj_service', 'expire'], ['premium_achat_rembourser_service', 'txn_1']]);
});

test('Paddle : transaction en euros au montant de la base, achat_id dans custom_data, cycle mensuel pour l’abonnement', async () => {
  let envoye = null;
  const p = fournisseurPaddle({ PADDLE_API_KEY: 'k', PADDLE_WEBHOOK_SECRET: 's' }, async (url, init) => {
    envoye = { url, corps: JSON.parse(init.body), auth: init.headers.Authorization };
    return { ok: true, json: async () => ({ data: { id: 'txn_9', checkout: { url: 'https://pay.example/txn_9' } } }) };
  });
  const t = await p.creerPaiement({ achat: 'a-9', libelle: 'Abonnement mensuel', montant_centimes: 500, nature: 'abonnement' });
  assert.deepEqual(t, { ref: 'txn_9', url: 'https://pay.example/txn_9' });
  assert.equal(envoye.url, 'https://sandbox-api.paddle.com/transactions');
  assert.equal(envoye.corps.items[0].price.unit_price.amount, '500');
  assert.equal(envoye.corps.items[0].price.unit_price.currency_code, 'EUR');
  assert.deepEqual(envoye.corps.items[0].price.billing_cycle, { interval: 'month', frequency: 1 });
  assert.equal(envoye.corps.custom_data.achat_id, 'a-9');
});

test('greffe : chat.js route le paiement avant toute lecture du corps ; réécritures ; aucune clé ni Stripe dans le dépôt', () => {
  const chat = lire('api/chat.js'), vercel = JSON.parse(lire('vercel.json')), pay = lire('api/_paiement.js');
  const iRoute = chat.indexOf("return handlerPaiement(req, res)"), iBody = chat.indexOf('req.body');
  assert.ok(iRoute > 0 && iRoute < iBody, 'paiement routé avant toute lecture de req.body');
  const rw = vercel.rewrites.map(r => r.source + '>' + r.destination);
  assert.ok(rw.indexOf('/api/paiement/webhook>/api/chat?mode=paiement_webhook') >= 0);
  assert.ok(rw.indexOf('/api/paiement/webhook>/api/chat?mode=paiement_webhook') < rw.indexOf('/api/paiement>/api/chat?mode=paiement'));
  assert.doesNotMatch(pay, /pdl_(live|sdbx)_|sk_live|whsec_/);
  assert.doesNotMatch(pay, /stripe/i);
});
