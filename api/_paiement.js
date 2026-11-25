/* ===========================================================================
   RES PUBLICA — api/_paiement.js
   PAIEMENT DES OPTIONS PREMIUM PAR UN REVENDEUR (mission du soir du 25/11/2026, bloc 4.4)
   ===========================================================================

   Décision de Fred (16/11 et 25/11) : un revendeur qui vend EN SON NOM et gère la TVA de tous les pays
   (« merchant of record »). Choix technique de Claude : Paddle (Paddle Billing). Tout se paie en euros, achat
   par achat, sans monnaie intermédiaire ; aucun prix n'est fixé ici : le prix vient de la base
   (premium_produits, réglage MJ), jamais du navigateur, et la base refuse tout prix sous 2 €.

   Greffé sur api/chat.js (plafond de 12 fonctions Vercel) :
     POST /api/paiement          → /api/chat?mode=paiement           { action: 'commander', produit, cible }
     POST /api/paiement/webhook  → /api/chat?mode=paiement_webhook   (appel signé du revendeur)

   Chemin d'un achat :
     1. le joueur commande : premium_achat_preparer (SON jeton) vérifie le produit, le prix fixé, la cible, et
        crée l'achat « en_attente » au montant de la base ;
     2. le revendeur crée la transaction (montant et achat_id dans custom_data) et rend l'adresse de paiement ;
        premium_achat_lier_service (clé serveur) note la référence ;
     3. le revendeur appelle le webhook, SIGNÉ (HMAC-SHA256 du corps brut) : seul ce chemin confirme l'achat
        (premium_achat_confirmer_service : montant et devise revérifiés, idempotent si l'appel est rejoué).

   Variables d'environnement (Vercel, jamais dans le dépôt) :
     PAIEMENT_FOURNISSEUR = aucun (défaut : paiement fermé) | paddle | faux (bancs et préproduction seulement)
     PADDLE_API_KEY, PADDLE_WEBHOOK_SECRET, PADDLE_ENV = sandbox (défaut) | production
     PAIEMENT_FAUX_SECRET (bancs) ; SUPABASE_SERVICE_ROLE_KEY (déjà présente).
   =========================================================================== */
import crypto from 'node:crypto';
import { sbTransportRpc, identiteServeurDisponible } from './_supabase.js';
import { joueurAuthentifie } from './_deepseek.js';

const TOLERANCE_SIGNATURE_S = 300;

// --- Signature : même forme pour Paddle et pour le faux fournisseur (« ts=…;h1=… », HMAC-SHA256 de « ts:corps »). ---
export function signerCorps(corpsBrut, secret, ts) {
  const h = crypto.createHmac('sha256', secret).update(`${ts}:${corpsBrut}`).digest('hex');
  return `ts=${ts};h1=${h}`;
}
export function verifierSignature(corpsBrut, entete, secret, maintenantS = Math.floor(Date.now() / 1000)) {
  if (!secret || !entete || typeof corpsBrut !== 'string') return false;
  const parts = Object.fromEntries(String(entete).split(';').map(x => x.split('=').map(s => s.trim())).filter(x => x.length === 2));
  const ts = Number(parts.ts);
  if (!Number.isFinite(ts) || Math.abs(maintenantS - ts) > TOLERANCE_SIGNATURE_S || !/^[0-9a-f]{64}$/.test(parts.h1 || '')) return false;
  const attendu = crypto.createHmac('sha256', secret).update(`${parts.ts}:${corpsBrut}`).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(attendu, 'hex'), Buffer.from(parts.h1, 'hex'));
}

// --- Fournisseurs. Interface : creerPaiement(achat) → { ref, url } ; secretWebhook ; nom. ---
export function fournisseurPaddle(env, fetchFn) {
  const base = env.PADDLE_ENV === 'production' ? 'https://api.paddle.com' : 'https://sandbox-api.paddle.com';
  return {
    nom: 'paddle',
    secretWebhook: env.PADDLE_WEBHOOK_SECRET || '',
    pret: !!(env.PADDLE_API_KEY && env.PADDLE_WEBHOOK_SECRET),
    async creerPaiement(a) {
      const prix = { description: a.libelle, name: a.libelle,
        unit_price: { amount: String(a.montant_centimes), currency_code: 'EUR' },
        product: { name: a.libelle, tax_category: 'standard' } };
      if (a.nature === 'abonnement') prix.billing_cycle = { interval: 'month', frequency: 1 };
      const r = await fetchFn(base + '/transactions', {
        method: 'POST',
        headers: { 'Authorization': 'Bearer ' + env.PADDLE_API_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ items: [{ quantity: 1, price: prix }], custom_data: { achat_id: a.achat } })
      });
      const j = await r.json().catch(() => null);
      const t = j && j.data;
      if (!r.ok || !t || !t.id || !t.checkout || !t.checkout.url) return null;
      return { ref: t.id, url: t.checkout.url };
    }
  };
}
export function fournisseurFaux(env) {
  return {
    nom: 'faux',
    secretWebhook: env.PAIEMENT_FAUX_SECRET || 'faux-secret-de-banc',
    pret: true,
    async creerPaiement(a) {
      const ref = 'txn_faux_' + crypto.randomUUID().replace(/-/g, '');
      return { ref, url: '/paiement-faux.html?achat=' + encodeURIComponent(a.achat) + '&ref=' + ref };
    }
  };
}
export function choisirFournisseur(env, fetchFn) {
  const n = String(env.PAIEMENT_FOURNISSEUR || 'aucun').toLowerCase();
  if (n === 'paddle') return fournisseurPaddle(env, fetchFn);
  // Le faux fournisseur ne sert jamais en production : il confirmerait des achats sans argent.
  if (n === 'faux' && env.VERCEL_ENV !== 'production') return fournisseurFaux(env);
  return null;
}

// --- Événements du revendeur (forme Paddle Billing) → RPC serveur. ---
const STATUTS_ABONNEMENT = { active: 'actif', trialing: 'actif', past_due: 'actif', paused: 'annule', canceled: 'expire' };
export async function traiterEvenement(ev, { rpc, fournisseur }) {
  const type = ev && ev.event_type, d = (ev && ev.data) || {};
  const svc = { service: true };
  if (type === 'transaction.completed' || type === 'transaction.paid') {
    const achat = d.custom_data && d.custom_data.achat_id;
    const item = Array.isArray(d.items) ? d.items[0] : null;
    const montant = Number(item && item.price && item.price.unit_price && item.price.unit_price.amount);
    const devise = (item && item.price && item.price.unit_price && item.price.unit_price.currency_code) || d.currency_code;
    if (d.subscription_id && d.origin === 'subscription_recurring') {
      const fin = d.billing_period && d.billing_period.ends_at;
      return rpc('premium_abonnement_maj_service', { p_ref: d.subscription_id, p_statut: 'actif', p_fin: fin || null }, svc);
    }
    if (!achat) return { etat: 'ignore' };
    return rpc('premium_achat_confirmer_service', { p_achat: achat, p_fournisseur: fournisseur.nom,
      p_ref: d.subscription_id || d.id, p_montant: Number.isFinite(montant) ? montant : null, p_devise: devise || null }, svc);
  }
  if (type && type.startsWith('subscription.')) {
    const statut = STATUTS_ABONNEMENT[d.status];
    if (!statut || !d.id) return { etat: 'ignore' };
    const fin = (d.current_billing_period && d.current_billing_period.ends_at) || d.canceled_at || null;
    return rpc('premium_abonnement_maj_service', { p_ref: d.id, p_statut: d.scheduled_change && d.scheduled_change.action === 'cancel' ? 'annule' : statut,
      p_fin: fin }, svc);
  }
  if ((type === 'adjustment.created' || type === 'adjustment.updated') && d.action === 'refund' && d.status === 'approved' && d.transaction_id) {
    return rpc('premium_achat_rembourser_service', { p_ref: d.transaction_id }, svc);
  }
  return { etat: 'ignore' };
}

// Corps brut, indispensable à la vérification de la signature. Ne JAMAIS lire req.body avant (il serait analysé).
export async function lireCorpsBrut(req, limite = 256 * 1024) {
  const morceaux = []; let n = 0;
  if (typeof req.on === 'function' && req.readable !== false) {
    await new Promise((ok, ko) => {
      req.on('data', c => { n += c.length; if (n > limite) { ko(new Error('corps_trop_long')); return; } morceaux.push(Buffer.from(c)); });
      req.on('end', ok); req.on('error', ko);
    });
  }
  if (morceaux.length) return Buffer.concat(morceaux).toString('utf8');
  if (Buffer.isBuffer(req.rawBody)) return req.rawBody.toString('utf8');
  if (typeof req.rawBody === 'string') return req.rawBody;
  return null;
}

export function creerHandlerPaiement(deps = {}) {
  const env = deps.env || process.env;
  const rpc = deps.rpc || ((fn, params, options) => sbTransportRpc(fn, params, options));
  const auth = deps.auth || (req => joueurAuthentifie(req, { signal: AbortSignal.timeout(4000) }));
  const serviceDispo = deps.serviceDispo || identiteServeurDisponible;
  const fetchFn = deps.fetch || fetch;
  const corpsBrut = deps.lireCorpsBrut || lireCorpsBrut;
  const un = e => (e && e.etat === 'ok') ? (Array.isArray(e.donnees) ? e.donnees[0] : e.donnees) : null;

  return async function handlerPaiement(req, res) {
    const mode = req.query && req.query.mode;
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    const fournisseur = choisirFournisseur(env, fetchFn);

    if (mode === 'paiement_webhook') {
      if (!fournisseur || !fournisseur.pret) return res.status(503).json({ ok: false, raison: 'paiement_inactif' });
      if (!serviceDispo()) return res.status(503).json({ ok: false, raison: 'service_indisponible' });
      let brut;
      try { brut = await corpsBrut(req); } catch (_) { return res.status(413).json({ ok: false }); }
      const entete = req.headers && (req.headers['paddle-signature'] || req.headers['Paddle-Signature']);
      if (!brut || !verifierSignature(brut, entete, fournisseur.secretWebhook)) return res.status(401).json({ ok: false, raison: 'signature_invalide' });
      let ev; try { ev = JSON.parse(brut); } catch (_) { return res.status(400).json({ ok: false, raison: 'corps_invalide' }); }
      const r = await traiterEvenement(ev, { rpc, fournisseur });
      if (r && r.etat && r.etat !== 'ok' && r.etat !== 'ignore') return res.status(500).json({ ok: false, raison: 'base_indisponible' }); // le revendeur réessaiera
      const v = un(r);
      return res.status(200).json({ ok: true, resultat: v && typeof v === 'object' ? { ok: v.ok, raison: v.raison || null } : null });
    }

    // Commande d'un joueur.
    const b = req.body && typeof req.body === 'object' ? req.body : {};
    if (b.action !== 'commander') return res.status(400).json({ error: 'Action inconnue.' });
    const u = await auth(req);
    if (!u) return res.status(401).json({ error: 'Authentification requise.' });
    if (!fournisseur || !fournisseur.pret) return res.status(200).json({ ok: false, raison: 'paiement_inactif' });
    if (!serviceDispo()) return res.status(503).json({ ok: false, raison: 'service_indisponible' });
    const produit = typeof b.produit === 'string' ? b.produit.slice(0, 60) : '';
    const cible = typeof b.cible === 'string' ? b.cible.slice(0, 200) : null;
    const p = un(await rpc('premium_achat_preparer', { p_produit: produit, p_cible: cible }, { jeton: u.jeton }));
    if (!p || p.ok !== true) return res.status(200).json({ ok: false, raison: (p && p.raison) || 'indisponible' });
    if (!(Number(p.montant_centimes) >= 200)) return res.status(200).json({ ok: false, raison: 'prix_inferieur_minimum' });
    const t = await fournisseur.creerPaiement(p).catch(() => null);
    if (!t) return res.status(200).json({ ok: false, raison: 'fournisseur_indisponible' });
    await rpc('premium_achat_lier_service', { p_achat: p.achat, p_fournisseur: fournisseur.nom, p_ref: t.ref }, { service: true });
    return res.status(200).json({ ok: true, url: t.url, achat: p.achat });
  };
}

export const handlerPaiement = creerHandlerPaiement();
