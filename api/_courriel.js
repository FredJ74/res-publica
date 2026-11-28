/* ===========================================================================
   RES PUBLICA — api/_courriel.js
   ENVOI DES E-MAILS DU JEU PAR BREVO (chantier 2 de Fred, 28/11/2026 au soir)
   ===========================================================================

   Module partagé (préfixe _ : pas une fonction Vercel). Seul point d'envoi des e-mails du jeu : avertissement des comptes
   inactifs (api/_comptes-inactifs.js), confirmation d'achat, rappel d'abonnement annuel et doublon remboursé
   (api/_paiement.js, textes dans api/_paiement-courriels.js), notification de sanction et e-mail de test (api/_courriel-mj.js).
   Les e-mails de Supabase Auth (confirmation d'adresse) ne passent pas ici : Supabase les envoie par le SMTP de Brevo.

   • API transactionnelle de Brevo : POST https://api.brevo.com/v3/smtp/email, en-tête « api-key », réponse 201
     { messageId } (developers.brevo.com/reference/sendtransacemail). Aucune dépendance.
   • Expéditeur fixe « Human Gambit <noreply@human-gambit.com> » (domaine authentifié dans Brevo, DKIM et DMARC).
     Les e-mails qui appellent une réponse (paiement, sanction, comptes inactifs, test) portent l'adresse de réponse
     contact@human-gambit.com (option « repondre »).
   • Une seule variable, dans Vercel (Production et Preview), jamais dans le dépôt : BREVO_API_KEY (droit « Emails
     transactionnels »).
   • Clé absente, refusée ou expirée, refus ou panne de Brevo : AUCUN e-mail ne part, l'appelant reçoit
     { ok:false, raison } et l'échec est consigné (journal Vercel + courriel_echec_noter_service), ce qui affiche une alerte
     dans la page MJ (admin-courriels.js) jusqu'à ce que le MJ la marque comme lue.
   =========================================================================== */

export const BREVO_URL_ENVOI = 'https://api.brevo.com/v3/smtp/email';
export const BREVO_URL_EVENEMENTS = 'https://api.brevo.com/v3/smtp/statistics/events';
export const EXPEDITEUR = Object.freeze({ name: 'Human Gambit', email: 'noreply@human-gambit.com' });
export const ADRESSE_REPONSE = Object.freeze({ name: 'Human Gambit', email: 'contact@human-gambit.com' });
// Raisons qui tiennent à l'appelant (adresse vide ou mal formée) : rien à signaler au MJ.
const RAISONS_APPELANT = new Set(['parametres_invalides', 'adresse_invalide']);

export function courrielConfigure(env = process.env) {
  return !!(env && typeof env.BREVO_API_KEY === 'string' && env.BREVO_API_KEY.trim());
}

const echapper = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export function texteEnHtml(texte, langue) {
  const l = /^[a-zA-Z-]{2,5}$/.test(String(langue || '')) ? langue : 'fr';
  return '<!DOCTYPE html><html lang="' + l + '"' + (l === 'ar' ? ' dir="rtl"' : '') + '><body>'
    + '<div style="font-family:sans-serif;line-height:1.5">'
    + String(texte).split('\n\n').map(p => '<p>' + echapper(p).replace(/\n/g, '<br>') + '</p>').join('') + '</div></body></html>';
}

// Classement d'une réponse de Brevo. 401 : clé inconnue, révoquée ou expirée (ou adresse IP non autorisée dans Brevo) ;
// 403 : clé sans le droit demandé. Les autres refus sont rendus avec leur code HTTP.
export function classerReponseBrevo(status) {
  if (status === 401 || status === 403) return 'cle_refusee';
  if (status >= 500) return 'brevo_indisponible_' + status;
  return 'envoi_refuse_' + status;
}

// Journal par défaut : la table courriel_echecs (clé de service). Chargé à la demande pour que le module reste importable
// seul (bancs) ; une panne du journal n'empêche jamais l'appelant de continuer.
async function journalParDefaut(raison, contexte, detail) {
  try {
    const sb = await import('./_supabase.js');
    if (!sb.identiteServeurDisponible()) return;
    await sb.sbTransportRpc('courriel_echec_noter_service', { p_raison: raison, p_contexte: contexte, p_detail: detail }, { service: true });
  } catch (_) { /* rien : l'échec reste dans le journal Vercel */ }
}

async function consigner(r, contexte, journal) {
  if (RAISONS_APPELANT.has(r.raison)) return r;
  try { console.error('[courriel] échec', contexte, r.raison, r.detail || ''); } catch (_) {}
  if (journal) { try { await journal(r.raison, contexte, r.detail || null); } catch (_) {} }
  return r;
}

/* Envoi. Renvoie { ok:true, messageId } ou { ok:false, raison, detail? }.
   a : adresse ; sujet, texte : contenu (texte brut, paragraphes séparés par une ligne vide ; une version HTML en est tirée) ;
   repondre : adresse de réponse contact@human-gambit.com ; cle : clé d'idempotence (webhook rejoué) ;
   contexte : origine, consignée avec l'échec (« paiement_achat », « comptes_inactifs »…) ; langue : attribut lang du HTML. */
export async function envoyerCourriel({ a, sujet, texte, cle, repondre = false, contexte = 'inconnu', langue = 'fr' } = {},
  { env = process.env, fetchFn = globalThis.fetch, journal = journalParDefaut } = {}) {
  if (!a || !sujet || !texte) return { ok: false, raison: 'parametres_invalides' };
  if (!/^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$/.test(String(a))) return { ok: false, raison: 'adresse_invalide' };
  if (!courrielConfigure(env)) {
    return consigner({ ok: false, raison: 'cle_absente', detail: 'BREVO_API_KEY absente de l’environnement' }, contexte, journal);
  }
  const cleApi = env.BREVO_API_KEY.trim();
  const corps = {
    sender: { ...EXPEDITEUR }, to: [{ email: String(a) }], subject: String(sujet),
    textContent: String(texte), htmlContent: texteEnHtml(texte, langue), tags: ['hg-' + String(contexte).slice(0, 40)]
  };
  if (repondre) corps.replyTo = { ...ADRESSE_REPONSE };
  if (cle) corps.headers = { idempotencyKey: String(cle).slice(0, 200) };
  let res;
  try {
    res = await fetchFn(BREVO_URL_ENVOI, {
      method: 'POST',
      headers: { 'api-key': cleApi, 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(corps),
      signal: AbortSignal.timeout(8000)
    });
  } catch (e) {
    return consigner({ ok: false, raison: 'envoi_echoue', detail: String((e && (e.name || e.message)) || 'reseau').slice(0, 100) }, contexte, journal);
  }
  let donnees = null;
  try { donnees = await res.json(); } catch (_) {}
  if (res.ok) return { ok: true, messageId: (donnees && (donnees.messageId || (donnees.messageIds || [])[0])) || null };
  // Le corps d'erreur de Brevo est { code, message } : il ne contient pas la clé, on l'en retire tout de même par prudence.
  const detail = ('HTTP ' + res.status + (donnees && donnees.code ? ' ' + donnees.code : '') + (donnees && donnees.message ? ' : ' + donnees.message : ''))
    .split(cleApi).join('[clé]').slice(0, 300);
  return consigner({ ok: false, raison: classerReponseBrevo(res.status), detail }, contexte, journal);
}

/* Événements d'un message (vérification de livraison) : GET /v3/smtp/statistics/events?messageId=…&email=…&days=…
   Renvoie { ok:true, evenements:[{ event, date, reason? }], livre } ou { ok:false, raison, detail? } (sans journal). */
export async function evenementsCourriel({ messageId, email, jours = 2 } = {}, { env = process.env, fetchFn = globalThis.fetch } = {}) {
  if (!messageId) return { ok: false, raison: 'parametres_invalides' };
  if (!courrielConfigure(env)) return { ok: false, raison: 'cle_absente' };
  const q = new URLSearchParams({ messageId: String(messageId), days: String(jours), limit: '50', sort: 'asc' });
  if (email) q.set('email', String(email));
  try {
    const res = await fetchFn(BREVO_URL_EVENEMENTS + '?' + q.toString(), {
      headers: { 'api-key': env.BREVO_API_KEY.trim(), Accept: 'application/json' }, signal: AbortSignal.timeout(8000)
    });
    let d = null; try { d = await res.json(); } catch (_) {}
    if (!res.ok) return { ok: false, raison: classerReponseBrevo(res.status), detail: ('HTTP ' + res.status + (d && d.message ? ' : ' + d.message : '')).slice(0, 300) };
    const evenements = ((d && d.events) || []).map(e => ({ event: e.event, date: e.date, ...(e.reason ? { reason: e.reason } : {}) }));
    return { ok: true, evenements, livre: evenements.some(e => e.event === 'delivered') };
  } catch (e) {
    return { ok: false, raison: 'envoi_echoue', detail: String((e && (e.name || e.message)) || 'reseau').slice(0, 100) };
  }
}
