// Envoi d'e-mails réels (Fred, 28/11/2026) — module partagé, pas une fonction Vercel (préfixe _).
// Aucun fournisseur n'est encore choisi : le jeu n'envoyait jusqu'ici aucun e-mail en dehors de ceux de Supabase Auth
// (confirmation d'adresse). Ce module parle à l'API HTTP de Resend si, et seulement si, deux variables d'environnement
// sont posées dans Vercel : RESEND_API_KEY et COURRIEL_EXPEDITEUR (ex. « Human Gambit <noreply@human-gambit.com> »).
// Sans elles, rien n'est envoyé et l'appelant reçoit { ok:false, raison:'fournisseur_non_configure' } : un avertissement
// non envoyé n'est jamais noté, donc aucune suppression de compte inactif ne peut suivre (api/_comptes-inactifs.js).
// Aucune clé dans le dépôt.

export function courrielConfigure(env = process.env) {
  return !!(env.RESEND_API_KEY && env.COURRIEL_EXPEDITEUR);
}

export async function envoyerCourriel({ a, sujet, texte }, { env = process.env, fetchImpl = globalThis.fetch } = {}) {
  if (!a || !sujet || !texte) return { ok: false, raison: 'parametres_invalides' };
  if (!courrielConfigure(env)) return { ok: false, raison: 'fournisseur_non_configure' };
  try {
    const res = await fetchImpl('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + env.RESEND_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: env.COURRIEL_EXPEDITEUR, to: [a], subject: sujet, text: texte })
    });
    if (!res.ok) return { ok: false, raison: 'http_' + res.status };
    return { ok: true };
  } catch (e) {
    return { ok: false, raison: 'reseau' };
  }
}
