// Mission du soir du 25/11/2026, bloc 4.4 : interface de paiement des options premium (api/_paiement.js), faux fournisseur.
// Mis à jour le 28/11/2026 (étape 4) : Paddle remplacé par Stripe ; les garanties restent : signature du webhook vérifiée sur
// le corps brut ; seul le webhook signé confirme ; le prix vient de la base, jamais du navigateur ; le faux fournisseur est
// interdit en production ; paiement fermé par défaut ; greffe sur chat.js (12 fonctions). Détails Stripe :
// outils/bancs/banc-paiement-stripe-20261128.mjs.
// Lancer : node --test outils/bancs/banc-paiement-premium-20261125.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { fileURLToPath } from 'node:url';
import { creerHandlerPaiement, signerStripe, verifierSignatureStripe, choisirFournisseur } from '../../api/_paiement.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const SECRET = 'secret-de-banc-' + Math.random().toString(36).slice(2);

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
    if (fn === 'premium_paiement_contexte_service') return { etat: 'ok', donnees: { ok: true, pays: 'FR', ue: true, achats_possibles: true, mode: 'editeur' } };
    if (fn === 'premium_achat_preparer') {
      if (params.p_produit === 'sans_prix') return { etat: 'ok', donnees: { ok: false, raison: 'prix_non_fixe' } };
      return { etat: 'ok', donnees: { ok: true, achat: 'a-1', produit: params.p_produit, nature: 'option', libelle: 'Bureau à 6 emplacements', montant_centimes: 300 } };
    }
    return { etat: 'ok', donnees: { ok: true } };
  };
  return { rpc, appels };
}
const envFaux = { PAIEMENT_FOURNISSEUR: 'faux', PAIEMENT_FAUX_SECRET: SECRET, VERCEL_ENV: 'preview', PAIEMENT_PAYS_DEFAUT: 'FR' };

test('signature : HMAC du corps brut, horodatage borné, comparaison à temps constant', () => {
  const ts = Math.floor(Date.now() / 1000);
  const corps = '{"a":1}';
  assert.ok(verifierSignatureStripe(corps, signerStripe(corps, SECRET, ts), SECRET));
  assert.ok(!verifierSignatureStripe(corps + ' ', signerStripe(corps, SECRET, ts), SECRET), 'corps modifié');
  assert.ok(!verifierSignatureStripe(corps, signerStripe(corps, 'autre', ts), SECRET), 'mauvais secret');
  assert.ok(!verifierSignatureStripe(corps, signerStripe(corps, SECRET, ts - 3600), SECRET), 'trop ancien');
  assert.ok(!verifierSignatureStripe(corps, 't=1,v1=zz', SECRET));
});

test('fournisseur : fermé par défaut ; faux interdit en production ; Stripe prêt seulement avec ses deux clés', () => {
  assert.equal(choisirFournisseur({}), null);
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'aucun' }), null);
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'paddle' }), null, 'Paddle retiré');
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'faux', VERCEL_ENV: 'production' }), null);
  assert.equal(choisirFournisseur(envFaux).nom, 'faux');
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'stripe' }).pret, false);
  assert.equal(choisirFournisseur({ PAIEMENT_FOURNISSEUR: 'stripe', STRIPE_SECRET_KEY: 'sk_test_x', STRIPE_WEBHOOK_SECRET: 's' }).pret, true);
});

test('commande : prix lu en base avec le jeton du joueur, paiement lié par la clé serveur', async () => {
  const { rpc, appels } = rpcFactice();
  const h = creerHandlerPaiement({ env: envFaux, rpc, auth: async () => ({ jeton: 'jeton-joueur' }), serviceDispo: () => true });
  const res = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'commander', produit: 'bureau_six', cible: 'x', montant: 1, cgv: true, renonciation: true } }, res);
  assert.equal(res.corps.ok, true); assert.match(res.corps.url, /paiement-faux/);
  const prep = appels.find(a => a.fn === 'premium_achat_preparer');
  assert.equal(prep.options.jeton, 'jeton-joueur');
  assert.ok(!('p_montant' in prep.params), 'le navigateur ne donne jamais le prix');
  const lier = appels.find(a => a.fn === 'premium_achat_lier_service');
  assert.equal(lier.options.service, true);
  const res2 = reponse();
  await h({ method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'commander', produit: 'sans_prix', cgv: true, renonciation: true } }, res2);
  assert.equal(res2.corps.raison, 'prix_non_fixe');
  const res3 = reponse();
  await creerHandlerPaiement({ env: {}, rpc, auth: async () => ({ jeton: 'j' }), serviceDispo: () => true })(
    { method: 'POST', query: { mode: 'paiement' }, headers: {}, body: { action: 'commander', produit: 'bureau_six' } }, res3);
  assert.equal(res3.corps.raison, 'paiement_inactif');
});

test('webhook : refusé sans signature valide ; confirmé avec montant et devise transmis à la base', async () => {
  const { rpc, appels } = rpcFactice();
  const h = creerHandlerPaiement({ env: envFaux, rpc, serviceDispo: () => true });
  const ev = JSON.stringify({ id: 'evt_1', type: 'checkout.session.completed', data: { object: { id: 'cs_1', mode: 'payment', payment_status: 'paid',
    client_reference_id: 'a-1', payment_intent: 'pi_1', amount_subtotal: 300, amount_total: 300, currency: 'eur' } } });
  const r1 = reponse();
  await h(requeteBrute(ev, { 'stripe-signature': 't=1,v1=' + '0'.repeat(64) }, { mode: 'paiement_webhook' }), r1);
  assert.equal(r1.code, 400); assert.equal(appels.length, 0);
  const r2 = reponse();
  await h(requeteBrute(ev, { 'stripe-signature': signerStripe(ev, SECRET, Math.floor(Date.now() / 1000)) }, { mode: 'paiement_webhook' }), r2);
  assert.equal(r2.code, 200);
  assert.deepEqual(appels.find(a => a.fn === 'premium_achat_confirmer_service'), { fn: 'premium_achat_confirmer_service', options: { service: true },
    params: { p_achat: 'a-1', p_fournisseur: 'faux', p_ref: 'pi_1', p_montant: 300, p_devise: 'EUR' } });
});

test('greffe : chat.js route le paiement avant toute lecture du corps ; réécritures ; aucune clé dans le dépôt', () => {
  const chat = lire('api/chat.js'), vercel = JSON.parse(lire('vercel.json')), pay = lire('api/_paiement.js');
  const iRoute = chat.indexOf("return handlerPaiement(req, res)"), iBody = chat.indexOf('req.body');
  assert.ok(iRoute > 0 && iRoute < iBody, 'paiement routé avant toute lecture de req.body');
  const rw = vercel.rewrites.map(r => r.source + '>' + r.destination);
  assert.ok(rw.indexOf('/api/paiement/webhook>/api/chat?mode=paiement_webhook') >= 0);
  assert.ok(rw.indexOf('/api/paiement/webhook>/api/chat?mode=paiement_webhook') < rw.indexOf('/api/paiement>/api/chat?mode=paiement'));
  assert.doesNotMatch(pay, /pdl_(live|sdbx)_|sk_live_[A-Za-z0-9]|sk_test_[A-Za-z0-9]|whsec_[A-Za-z0-9]/);
  assert.doesNotMatch(pay, /paddle/i, 'Paddle remplacé par Stripe');
});
