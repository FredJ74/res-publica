/* ===========================================================================
   RES PUBLICA — api/_paiement.js
   PAIEMENT DES OPTIONS PREMIUM PAR STRIPE, EN FONCTIONNEMENT MIXTE (décision de Fred du 28/11/2026 ; remplace le revendeur du 25/11)
   ===========================================================================

   • Acheteurs de France et de l'UE : Stripe classique (Checkout), l'éditeur est le vendeur (franchise de TVA : factures
     « TVA non applicable, article 293 B du CGI »). Reste du monde : Stripe Managed Payments (managed_payments[enabled]=true),
     Stripe — sous la marque Link — est le vendeur officiel. Le choix est fait par la BASE (premium_paiement_contexte_service)
     à partir du pays de l'acheteur que donne la géolocalisation de Vercel (en-tête x-vercel-ip-country, posé par la plateforme,
     jamais par le navigateur) ; réglage serveur paiement_mp_pour_ue pour étendre Managed Payments à l'UE sans recoder.
   • Même chemin d'achat qu'avant : prix lu en base (premium_produits, jamais sous 2 €) par premium_achat_preparer avec le jeton
     du joueur, achat « en_attente », consentements enregistrés (CGV, renonciation au droit de rétractation), session Checkout
     créée par le serveur, confirmation UNIQUEMENT par le webhook signé (Stripe-Signature, HMAC-SHA256 de « t.corps brut »),
     idempotente (premium_achat_confirmer_service).
   • Abonnement mensuel et annuel (Stripe Billing, mode « subscription »), renouvelé automatiquement ; résiliation à la fin de
     la période payée (cancel_at_period_end) ; remboursement dans les 14 jours si aucun avantage utilisé ; doublons remboursés.
   • Pas de SDK Stripe : quelques appels REST (formulaire encodé) et la vérification HMAC avec node:crypto suffisent, sans
     ajouter de dépendance au bundle des fonctions Vercel (plafond de 12 fonctions, démarrage à froid) ; version d'API figée
     par l'en-tête Stripe-Version (STRIPE_API_VERSION, défaut 2025-03-31.basil, minimum exigé par Managed Payments).

   Greffé sur api/chat.js (plafond de 12 fonctions Vercel) :
     POST /api/paiement          → /api/chat?mode=paiement           { action: 'etat' | 'commander' | 'resilier' | 'rembourser_abonnement' }
     POST /api/paiement/webhook  → /api/chat?mode=paiement_webhook   (appel signé de Stripe)
   Rappel des abonnements annuels : envoyerRappelsAnnuels(), appelé par api/cron-minuit.js.

   Variables d'environnement (Vercel, jamais dans le dépôt) :
     PAIEMENT_FOURNISSEUR = aucun (défaut : paiement fermé) | stripe | faux (bancs et préproduction seulement)
     STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET ; STRIPE_API_VERSION (facultatif) ;
     STRIPE_TAX_CODE_ABONNEMENT, STRIPE_TAX_CODE_UNITE (facultatifs, codes fiscaux éligibles à Managed Payments) ;
     PAIEMENT_URL_SITE (facultatif, adresse de retour après paiement) ; BREVO_API_KEY (e-mails, api/_courriel.js) ;
     PAIEMENT_FAUX_SECRET, PAIEMENT_PAYS_DEFAUT (bancs) ; SUPABASE_SERVICE_ROLE_KEY (déjà présente).
   =========================================================================== */
import crypto from 'node:crypto';
import { sbTransportRpc, identiteServeurDisponible } from './_supabase.js';
import { joueurAuthentifie } from './_deepseek.js';
import { courrielConfirmation, courrielRappelAnnuel, courrielDoublon, langueCourriel, LANGUES_COURRIEL } from './_paiement-courriels.js';
import { envoyerCourriel } from './_courriel.js';

export const TOLERANCE_SIGNATURE_S = 300;   // tolérance par défaut des bibliothèques de Stripe
const API_STRIPE = 'https://api.stripe.com/v1';
const VERSION_API_DEFAUT = '2025-03-31.basil';
// Codes fiscaux éligibles à Managed Payments (docs.stripe.com/payments/managed-payments/eligibility) — à confirmer par Fred.
export const TAX_CODE_ABONNEMENT_DEFAUT = 'txcd_10201004';   // Video Games - streamed - subscription - with conditional rights
export const TAX_CODE_UNITE_DEFAUT = 'txcd_10000000';        // General - Electronically Supplied Services
const LOCALES_CHECKOUT = { fr: 'fr', en: 'en', es: 'es', de: 'de', ru: 'ru', ko: 'ko', ar: 'auto', 'pt-BR': 'pt-BR', 'zh-TW': 'zh-TW' };

// --- Signature des webhooks, format Stripe : en-tête « t=<horodatage>,v1=<hmac>[,v1=…][,v0=…] » ;
//     HMAC-SHA256 (clé = secret du point de terminaison, tel quel) de « <t>.<corps brut> » ; horodatage borné. ---
export function signerStripe(corpsBrut, secret, t) {
  return `t=${t},v1=${crypto.createHmac('sha256', secret).update(`${t}.${corpsBrut}`, 'utf8').digest('hex')}`;
}
export function verifierSignatureStripe(corpsBrut, entete, secret, maintenantS = Math.floor(Date.now() / 1000), tolerance = TOLERANCE_SIGNATURE_S) {
  if (!secret || !entete || typeof corpsBrut !== 'string') return false;
  let t = null; const v1 = [];
  for (const morceau of String(entete).split(',')) {
    const i = morceau.indexOf('='); if (i <= 0) continue;
    const k = morceau.slice(0, i).trim(), v = morceau.slice(i + 1).trim();
    if (k === 't') t = v; else if (k === 'v1' && /^[0-9a-f]{64}$/.test(v)) v1.push(v);
  }
  if (!t || !/^\d{1,12}$/.test(t) || !v1.length || Math.abs(maintenantS - Number(t)) > tolerance) return false;
  const attendu = Buffer.from(crypto.createHmac('sha256', secret).update(`${t}.${corpsBrut}`, 'utf8').digest('hex'), 'hex');
  return v1.some(s => crypto.timingSafeEqual(attendu, Buffer.from(s, 'hex')));
}

// --- Formulaire encodé de l'API Stripe : objets imbriqués → a[b][c]=v ; tableaux → a[0][b]=v. ---
export function formulaireStripe(obj) {
  const p = new URLSearchParams();
  const aplatir = (v, cle) => {
    if (v === undefined || v === null) return;
    if (Array.isArray(v)) v.forEach((x, i) => aplatir(x, `${cle}[${i}]`));
    else if (typeof v === 'object') Object.keys(v).forEach(k => aplatir(v[k], cle ? `${cle}[${k}]` : k));
    else p.append(cle, String(v));
  };
  aplatir(obj, '');
  return p.toString();
}

// --- Paramètres de la session Checkout (fonction pure, éprouvée au banc). a = achat préparé par la base ; ctx = contexte. ---
export function paramsSessionCheckout(a, ctx, env = {}) {
  const abonnement = a.nature === 'abonnement';
  const mp = ctx.mode === 'stripe';
  const base = String(ctx.urlSite || 'https://res-publica.vercel.app').replace(/\/+$/, '');
  const p = {
    mode: abonnement ? 'subscription' : 'payment',
    client_reference_id: a.achat,
    metadata: { achat_id: a.achat, mode_vente: ctx.mode },
    line_items: [{ quantity: 1, price_data: {
      currency: 'eur', unit_amount: a.montant_centimes,
      // Le prix affiché au joueur est le prix payé (taxes comprises quand Managed Payments en collecte) — question à Fred.
      tax_behavior: 'inclusive',
      product_data: { name: a.libelle, tax_code: abonnement ? (env.STRIPE_TAX_CODE_ABONNEMENT || TAX_CODE_ABONNEMENT_DEFAUT) : (env.STRIPE_TAX_CODE_UNITE || TAX_CODE_UNITE_DEFAUT) },
      ...(abonnement ? { recurring: { interval: a.intervalle === 'year' ? 'year' : 'month' } } : {})
    } }],
    success_url: `${base}/plateau.html?paiement=ok&achat=${encodeURIComponent(a.achat)}`,
    cancel_url: `${base}/plateau.html?paiement=annule&achat=${encodeURIComponent(a.achat)}`,
    locale: LOCALES_CHECKOUT[ctx.langue] || 'auto'
  };
  if (abonnement) p.subscription_data = { metadata: { achat_id: a.achat, mode_vente: ctx.mode } };
  else p.payment_intent_data = { metadata: { achat_id: a.achat, mode_vente: ctx.mode } };
  if (mp) {
    // Managed Payments : Stripe vendeur officiel ; il gère taxes, factures et e-mails (pas d'invoice_creation, ni d'adresse
    // de facturation forcée, ni de moyens de paiement imposés : paramètres non pris en charge selon la documentation).
    p.managed_payments = { enabled: true };
  } else {
    // Stripe classique : l'éditeur est le vendeur, franchise de TVA.
    const vendeur = String(ctx.editeurNom || '').slice(0, 160);
    p.billing_address_collection = 'required';
    p.custom_text = { submit: { message: `Vendeur : ${vendeur}. TVA non applicable, article 293 B du CGI.`.slice(0, 1200) } };
    if (!abonnement) {
      const pied = ['TVA non applicable, article 293 B du CGI.',
        a.renonciation ? 'Livraison immédiate demandée par l’acheteur, qui a renoncé expressément à son droit de rétractation.' : null].filter(Boolean).join(' ');
      p.invoice_creation = { enabled: true, invoice_data: { footer: pied, metadata: { achat_id: a.achat } } };
    }
  }
  return p;
}

// --- Fournisseurs. Interface : creerPaiement(achat, ctx) → { ref, url } ; resilier(ref) ; rembourserAbonnement(ref) ;
//     rembourserPaiement(refPaiement) → { ok } ; secretWebhook ; pret ; nom. ---
export function fournisseurStripe(env, fetchFn) {
  const cle = env.STRIPE_SECRET_KEY || '';
  // Une clé réelle (sk_live / rk_live) ne sert qu'en production ; ailleurs, seulement des clés de test.
  const cleAdmise = !!cle && (env.VERCEL_ENV === 'production' || !/^(sk|rk)_live_/.test(cle));
  const appel = async (methode, chemin, params, idem) => {
    const r = await fetchFn(API_STRIPE + chemin, {
      method: methode,
      headers: { Authorization: 'Bearer ' + cle, 'Stripe-Version': env.STRIPE_API_VERSION || VERSION_API_DEFAUT,
        ...(params ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}), ...(idem ? { 'Idempotency-Key': idem } : {}) },
      ...(params ? { body: formulaireStripe(params) } : {}),
      signal: AbortSignal.timeout(8000)
    });
    const j = await r.json().catch(() => null);
    return { ok: !!r.ok, j: j || {} };
  };
  return {
    nom: 'stripe',
    secretWebhook: env.STRIPE_WEBHOOK_SECRET || '',
    pret: cleAdmise && !!env.STRIPE_WEBHOOK_SECRET,
    async creerPaiement(a, ctx) {
      const { ok, j } = await appel('POST', '/checkout/sessions', paramsSessionCheckout(a, ctx, env), 'achat-' + a.achat);
      if (!ok || !j.id || typeof j.url !== 'string') return null;
      return { ref: j.id, url: j.url };
    },
    async resilier(refAbonnement) {
      const { ok, j } = await appel('POST', '/subscriptions/' + encodeURIComponent(refAbonnement), { cancel_at_period_end: true });
      return { ok: ok && (j.cancel_at_period_end === true || !!j.cancel_at) };
    },
    async rembourserPaiement(refPaiement) {
      const { ok, j } = await appel('POST', '/refunds', { payment_intent: refPaiement }, 'remb-' + refPaiement);
      return { ok: ok || (j.error && j.error.code === 'charge_already_refunded') };
    },
    // Dernière facture payée de l'abonnement → paiement → remboursement intégral, puis fin immédiate de l'abonnement.
    async rembourserAbonnement(refAbonnement) {
      const q = '?subscription=' + encodeURIComponent(refAbonnement) + '&status=paid&limit=1&expand[]=data.payments';
      const f = await appel('GET', '/invoices' + q);
      const inv = f.ok && Array.isArray(f.j.data) ? f.j.data[0] : null;
      if (!inv) return { ok: false, raison: 'facture_introuvable' };
      const paiement = inv.payments && Array.isArray(inv.payments.data) && inv.payments.data[0] && inv.payments.data[0].payment;
      let pi = (paiement && paiement.payment_intent) || inv.payment_intent || null;
      if (pi && typeof pi === 'object') pi = pi.id;
      const ch = !pi ? ((paiement && paiement.charge) || inv.charge || null) : null;
      if (!pi && !ch) return { ok: false, raison: 'paiement_introuvable' };
      const r = await appel('POST', '/refunds', pi ? { payment_intent: pi } : { charge: typeof ch === 'object' ? ch.id : ch }, 'remb-' + refAbonnement);
      if (!r.ok && !(r.j.error && r.j.error.code === 'charge_already_refunded')) return { ok: false, raison: 'remboursement_refuse' };
      const d = await appel('DELETE', '/subscriptions/' + encodeURIComponent(refAbonnement));
      return { ok: d.ok || (d.j.error && d.j.error.code === 'resource_missing') || d.j.status === 'canceled' };
    }
  };
}
export function fournisseurFaux(env) {
  return {
    nom: 'faux',
    secretWebhook: env.PAIEMENT_FAUX_SECRET || 'faux-secret-de-banc',
    pret: true,
    async creerPaiement(a, ctx) {
      const ref = 'cs_faux_' + crypto.randomUUID().replace(/-/g, '');
      return { ref, url: '/paiement-faux.html?achat=' + encodeURIComponent(a.achat) + '&ref=' + ref + '&vendeur=' + encodeURIComponent(ctx.mode) };
    },
    async resilier() { return { ok: true }; },
    async rembourserPaiement() { return { ok: true }; },
    async rembourserAbonnement() { return { ok: true }; }
  };
}
export function choisirFournisseur(env, fetchFn) {
  const n = String(env.PAIEMENT_FOURNISSEUR || 'aucun').toLowerCase();
  if (n === 'stripe') return fournisseurStripe(env, fetchFn);
  // Le faux fournisseur ne sert jamais en production : il confirmerait des achats sans argent.
  if (n === 'faux' && env.VERCEL_ENV !== 'production') return fournisseurFaux(env);
  return null;
}

// --- Pays de l'acheteur : géolocalisation de Vercel (posée par la plateforme). Le faux fournisseur peut prendre un défaut. ---
export function paysDeLaRequete(req, env, fournisseur) {
  const h = req && req.headers ? (req.headers['x-vercel-ip-country'] || req.headers['X-Vercel-IP-Country']) : null;
  const p = String(h || '').trim().toUpperCase();
  if (/^[A-Z]{2}$/.test(p)) return p;
  if (fournisseur && fournisseur.nom === 'faux' && /^[A-Z]{2}$/.test(String(env.PAIEMENT_PAYS_DEFAUT || ''))) return env.PAIEMENT_PAYS_DEFAUT;
  return null;
}

const enIso = s => (Number.isFinite(Number(s)) && Number(s) > 0 ? new Date(Number(s) * 1000).toISOString() : null);
const finDePeriode = sub => {
  const it = sub && sub.items && Array.isArray(sub.items.data) ? sub.items.data[0] : null;
  return enIso((it && it.current_period_end) || (sub && sub.current_period_end));   // basil : sur l'élément ; avant : sur l'abonnement
};
const un = e => (e && e.etat === 'ok') ? (Array.isArray(e.donnees) ? e.donnees[0] : e.donnees) : null;

// --- Événements de Stripe → RPC serveur. Renvoie la réponse de la base (ou { etat: 'ignore' }). ---
export async function traiterEvenement(ev, { rpc, fournisseur, env = {}, fetchFn, editeurNom = null }) {
  const type = ev && ev.type, o = (ev && ev.data && ev.data.object) || {};
  const svc = { service: true };
  if (type === 'checkout.session.completed' || type === 'checkout.session.async_payment_succeeded') {
    if (o.payment_status !== 'paid') return { etat: 'ignore' };   // paiement différé : on attend async_payment_succeeded
    const achat = o.client_reference_id || (o.metadata && o.metadata.achat_id);
    if (!achat) return { etat: 'ignore' };
    const abonnement = o.mode === 'subscription';
    const ref = abonnement ? (typeof o.subscription === 'object' && o.subscription ? o.subscription.id : o.subscription) : (typeof o.payment_intent === 'object' && o.payment_intent ? o.payment_intent.id : o.payment_intent);
    // Montant hors taxes ajoutées (amount_subtotal), dans la devise de la session (euros, même avec la conversion d'Adaptive Pricing).
    const montant = Number(o.amount_subtotal);
    const r = await rpc('premium_achat_confirmer_service', { p_achat: achat, p_fournisseur: fournisseur.nom, p_ref: ref || o.id,
      p_montant: Number.isFinite(montant) ? montant : null, p_devise: o.currency ? String(o.currency).toUpperCase() : null }, svc);
    const c = un(r);
    if (!c || c.ok !== true) return r;
    const email = (o.customer_details && o.customer_details.email) || o.customer_email || null;
    const n = un(await rpc('premium_achat_paiement_noter_service', { p_achat: achat, p_ref_paiement: abonnement ? null : (ref || null),
      p_abonnement_ref: abonnement ? (ref || null) : null, p_email: email }, svc));
    if (!n || n.ok !== true) return r;
    if (n.doublon) {
      // Débit en double : remboursé intégralement, automatiquement.
      const rb = n.nature === 'abonnement' ? await fournisseur.rembourserAbonnement(n.abonnement_ref) : await fournisseur.rembourserPaiement(n.ref_paiement);
      if (!rb || !rb.ok) return { etat: 'erreur', raison: 'remboursement_doublon' };   // Stripe réessaiera (clé d'idempotence)
      if (n.nature === 'abonnement') await rpc('premium_abonnement_rembourser_service', { p_user: n.user, p_ref: n.abonnement_ref, p_motif: 'doublon' }, svc);
      else await rpc('premium_achat_rembourser_service', { p_ref: n.ref_fournisseur }, svc);
      if (email && n.envoyer_courriel) {
        const m = courrielDoublon(n);
        const e = await envoyerCourriel({ a: email, ...m, cle: 'doublon-' + achat, repondre: true, contexte: 'paiement_doublon', langue: langueCourriel(n.langue) }, { env, fetchFn });
        if (e.ok) await rpc('premium_achat_courriel_noter_service', { p_achat: achat }, svc);
      }
      return r;
    }
    if (email && n.envoyer_courriel) {
      const m = courrielConfirmation(n, { editeurNom });
      const e = await envoyerCourriel({ a: email, ...m, cle: 'achat-' + achat, repondre: true, contexte: 'paiement_achat', langue: langueCourriel(n.langue) }, { env, fetchFn });
      if (e.ok) await rpc('premium_achat_courriel_noter_service', { p_achat: achat }, svc);
    }
    return r;
  }
  if (type === 'customer.subscription.created' || type === 'customer.subscription.updated') {
    if (!o.id) return { etat: 'ignore' };
    const statuts = { active: 'actif', trialing: 'actif', past_due: 'actif', canceled: 'expire', unpaid: 'expire', incomplete_expired: 'expire' };
    let statut = statuts[o.status];
    if (!statut) return { etat: 'ignore' };   // incomplete, paused : rien à changer
    let fin = finDePeriode(o);
    if (statut === 'actif' && (o.cancel_at_period_end === true || o.cancel_at)) { statut = 'annule'; fin = enIso(o.cancel_at) || fin; }
    if (statut === 'expire') fin = enIso(o.ended_at) || enIso(o.canceled_at) || fin;
    return rpc('premium_abonnement_maj_service', { p_ref: o.id, p_statut: statut, p_fin: fin }, svc);
  }
  if (type === 'customer.subscription.deleted') {
    if (!o.id) return { etat: 'ignore' };
    return rpc('premium_abonnement_maj_service', { p_ref: o.id, p_statut: 'expire', p_fin: enIso(o.ended_at) || enIso(o.canceled_at) || new Date().toISOString() }, svc);
  }
  // Remboursement intégral d'un paiement à l'unité ou d'une option (tableau de bord Stripe ou assistance Link) : droit retiré.
  // Les remboursements d'échéances d'abonnement ne retirent rien (débit en erreur) ; la fin d'abonnement vient de .deleted.
  if (type === 'charge.refunded') {
    const pi = typeof o.payment_intent === 'object' && o.payment_intent ? o.payment_intent.id : o.payment_intent;
    if (o.refunded !== true || !pi) return { etat: 'ignore' };
    const r = await rpc('premium_achat_rembourser_paiement_service', { p_ref_paiement: pi }, svc);
    const v = un(r);
    return v && v.raison === 'achat_inconnu' ? { etat: 'ignore' } : r;
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

// --- Rappel des abonnements annuels (traitement de nuit). ---
export async function envoyerRappelsAnnuels({ rpc = (fn, p, o) => sbTransportRpc(fn, p, o), env = process.env, fetchFn = fetch, serviceDispo = identiteServeurDisponible } = {}) {
  if (!serviceDispo()) return { ok: false, raison: 'service_indisponible' };
  const l = un(await rpc('premium_rappels_annuels_service', {}, { service: true }));
  if (!l || l.ok !== true) return { ok: false, raison: (l && l.raison) || 'base_indisponible' };
  let envoyes = 0, echecs = 0;
  for (const r of l.rappels || []) {
    const m = courrielRappelAnnuel(r);
    const e = await envoyerCourriel({ a: r.email, ...m, cle: 'rappel-' + r.id + '-' + r.fin, repondre: true, contexte: 'paiement_rappel', langue: langueCourriel(r.langue) }, { env, fetchFn });
    if (e.ok) { envoyes++; await rpc('premium_rappel_noter_service', { p_id: r.id, p_fin: r.fin }, { service: true }); }
    else { echecs++; if (e.raison === 'cle_absente' || e.raison === 'cle_refusee') return { ok: false, raison: e.raison, a_envoyer: (l.rappels || []).length }; }
  }
  return { ok: true, envoyes, echecs };
}

const urlSite = (req, env) => {
  if (/^https:\/\/[a-z0-9.-]+(:\d+)?$/i.test(String(env.PAIEMENT_URL_SITE || ''))) return env.PAIEMENT_URL_SITE;
  const h = String((req.headers && (req.headers['x-forwarded-host'] || req.headers.host)) || '');
  return /^[a-z0-9.-]+(:\d+)?$/i.test(h) && !/^localhost/i.test(h) ? 'https://' + h : 'https://res-publica.vercel.app';
};

export function creerHandlerPaiement(deps = {}) {
  const env = deps.env || process.env;
  const rpc = deps.rpc || ((fn, params, options) => sbTransportRpc(fn, params, options));
  const auth = deps.auth || (req => joueurAuthentifie(req, { signal: AbortSignal.timeout(4000) }));
  const serviceDispo = deps.serviceDispo || identiteServeurDisponible;
  const fetchFn = deps.fetch || fetch;
  const corpsBrut = deps.lireCorpsBrut || lireCorpsBrut;
  const svc = { service: true };

  // Contexte d'achat : la base décide du mode à partir du pays ; le serveur ajoute ce qui manque pour vendre réellement.
  async function contexte(req, fournisseur) {
    const pays = paysDeLaRequete(req, env, fournisseur);
    const c = un(await rpc('premium_paiement_contexte_service', { p_pays: pays }, svc));
    if (!c || c.ok !== true) return { achats_possibles: false, raison: (c && c.raison) || 'base_indisponible' };
    const ctx = { pays: c.pays, ue: !!c.ue, mode: c.mode || null, achats_possibles: !!c.achats_possibles, raison: c.raison || null,
      editeurNom: c.editeur_nom || null, cgvUrl: c.cgv_url || null };
    if (ctx.achats_possibles && fournisseur.nom === 'stripe') {
      if (!ctx.cgvUrl) Object.assign(ctx, { achats_possibles: false, raison: 'cgv_non_publiees' });
      else if (ctx.mode === 'editeur' && !ctx.editeurNom) Object.assign(ctx, { achats_possibles: false, raison: 'vendeur_non_configure' });
    }
    return ctx;
  }

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
      const entete = req.headers && (req.headers['stripe-signature'] || req.headers['Stripe-Signature']);
      if (!brut || !verifierSignatureStripe(brut, entete, fournisseur.secretWebhook)) return res.status(400).json({ ok: false, raison: 'signature_invalide' });
      let ev; try { ev = JSON.parse(brut); } catch (_) { return res.status(400).json({ ok: false, raison: 'corps_invalide' }); }
      let editeurNom = null;
      if (ev && ev.type && ev.type.startsWith('checkout.session.')) {
        const c = un(await rpc('premium_paiement_contexte_service', { p_pays: 'FR' }, svc));
        editeurNom = (c && c.editeur_nom) || null;
      }
      const r = await traiterEvenement(ev, { rpc, fournisseur, env, fetchFn, editeurNom });
      if (r && r.etat && r.etat !== 'ok' && r.etat !== 'ignore') return res.status(500).json({ ok: false, raison: r.raison || 'base_indisponible' }); // Stripe réessaiera
      const v = un(r);
      return res.status(200).json({ ok: true, resultat: v && typeof v === 'object' ? { ok: v.ok, raison: v.raison || null } : null });
    }

    const b = req.body && typeof req.body === 'object' ? req.body : {};
    if (!['etat', 'commander', 'resilier', 'rembourser_abonnement'].includes(b.action)) return res.status(400).json({ error: 'Action inconnue.' });
    const u = await auth(req);
    if (!u) return res.status(401).json({ error: 'Authentification requise.' });
    if (!fournisseur || !fournisseur.pret) return res.status(200).json({ ok: false, raison: 'paiement_inactif', paiement_ouvert: false });
    if (!serviceDispo()) return res.status(503).json({ ok: false, raison: 'service_indisponible' });

    if (b.action === 'etat') {
      const ctx = await contexte(req, fournisseur);
      return res.status(200).json({ ok: true, paiement_ouvert: true, achats_possibles: ctx.achats_possibles, raison: ctx.raison,
        vendeur: ctx.mode === 'stripe' ? 'stripe' : (ctx.mode === 'editeur' ? 'editeur' : null), editeur_nom: ctx.editeurNom, cgv_url: ctx.cgvUrl, pays: ctx.pays || null });
    }

    if (b.action === 'resilier' || b.action === 'rembourser_abonnement') {
      const action = b.action === 'resilier' ? 'resilier' : 'rembourser';
      const p = un(await rpc('premium_abonnement_action_preparer', { p_action: action }, { jeton: u.jeton }));
      if (!p || p.ok !== true) return res.status(200).json({ ok: false, raison: (p && p.raison) || 'indisponible', fin: (p && p.fin) || null });
      // L'abonnement doit avoir été souscrit chez le fournisseur actif (le faux ne résilie pas un abonnement Stripe, et inversement).
      if (p.fournisseur && p.fournisseur !== fournisseur.nom) return res.status(200).json({ ok: false, raison: 'fournisseur_different' });
      const f = action === 'resilier' ? await fournisseur.resilier(p.ref).catch(() => null) : await fournisseur.rembourserAbonnement(p.ref).catch(() => null);
      if (!f || !f.ok) return res.status(200).json({ ok: false, raison: 'fournisseur_indisponible' });
      const r = un(action === 'resilier'
        ? await rpc('premium_abonnement_resilier_service', { p_user: p.user, p_ref: p.ref }, svc)
        : await rpc('premium_abonnement_rembourser_service', { p_user: p.user, p_ref: p.ref, p_motif: 'demande_14_jours' }, svc));
      // Stripe a agi : même si la base tarde, l'événement signé suivant (subscription.updated / .deleted) la mettra à jour.
      return res.status(200).json({ ok: true, fin: (r && r.fin) || p.fin || null });
    }

    // Commande d'un joueur.
    const ctx = await contexte(req, fournisseur);
    if (!ctx.achats_possibles) return res.status(200).json({ ok: false, raison: ctx.raison || 'achats_indisponibles' });
    const produit = typeof b.produit === 'string' ? b.produit.slice(0, 60) : '';
    const cible = typeof b.cible === 'string' ? b.cible.slice(0, 200) : null;
    const langue = LANGUES_COURRIEL.includes(b.langue) ? b.langue : 'fr';
    const p = un(await rpc('premium_achat_preparer', { p_produit: produit, p_cible: cible }, { jeton: u.jeton }));
    if (!p || p.ok !== true) return res.status(200).json({ ok: false, raison: (p && p.raison) || 'indisponible' });
    if (!(Number(p.montant_centimes) >= 200)) return res.status(200).json({ ok: false, raison: 'prix_inferieur_minimum' });
    // CGV et renonciation au droit de rétractation : exigées et enregistrées par la base, avant tout paiement.
    const c = un(await rpc('premium_achat_consentir_service', { p_achat: p.achat, p_cgv: b.cgv === true, p_renonciation: b.renonciation === true,
      p_mode: ctx.mode, p_pays: ctx.pays, p_langue: langue }, svc));
    if (!c || c.ok !== true) return res.status(200).json({ ok: false, raison: (c && c.raison) || 'indisponible' });
    const intervalle = p.intervalle || (p.produit === 'abonnement_annuel' ? 'year' : 'month');
    const t = await fournisseur.creerPaiement({ ...p, intervalle, renonciation: b.renonciation === true },
      { mode: ctx.mode, langue, editeurNom: ctx.editeurNom, urlSite: urlSite(req, env) }).catch(() => null);
    if (!t) return res.status(200).json({ ok: false, raison: 'fournisseur_indisponible' });
    await rpc('premium_achat_lier_service', { p_achat: p.achat, p_fournisseur: fournisseur.nom, p_ref: t.ref }, svc);
    return res.status(200).json({ ok: true, url: t.url, achat: p.achat, vendeur: ctx.mode === 'stripe' ? 'stripe' : 'editeur' });
  };
}

export const handlerPaiement = creerHandlerPaiement();
