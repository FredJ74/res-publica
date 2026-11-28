/* ===========================================================================
   RES PUBLICA — api/_courriel-mj.js
   ACTIONS E-MAIL DE LA PAGE MJ (chantier 2 de Fred, 28/11/2026 au soir)
   ===========================================================================

   Greffé sur api/chat.js (plafond de 12 fonctions Vercel) : POST /api/courriel → /api/chat?mode=courriel.
   Corps { action } :
     • 'test'        : e-mail de test (objet « Human Gambit — e-mail de test (Brevo) »), adresse de réponse contact@.
                        Destinataire : l'adresse du compte MJ connecté (jeton administrateur, admin_courriel_test_adresse),
                        ou celle d'un jeton de test à usage unique posé en base par l'exploitant ({ jeton }, table courriel_tests,
                        lu avec la clé de service) — l'adresse n'apparaît ainsi jamais dans le dépôt.
     • 'test_statut' : événements Brevo du message (delivered, deferred, bounces…), par { jeton } ou { message_id } (MJ).
     • 'sanction'    : e-mail de notification d'une sanction déjà prononcée ({ sanction }), dans la langue du joueur,
                        adresse de réponse contact@ (admin_sanction_courriel_preparer).
   Tout appel MJ est revérifié par la base (admin_exiger lève en 42501 pour un compte non administrateur).
   =========================================================================== */
import { envoyerCourriel, evenementsCourriel } from './_courriel.js';

export const SUJET_TEST = 'Human Gambit — e-mail de test (Brevo)';
export function texteTest(maintenant = new Date()) {
  let quand = maintenant.toISOString();
  try { quand = maintenant.toLocaleString('fr-FR', { timeZone: 'Europe/Paris' }); } catch (_) {}
  return 'Bonjour,\n\nCet e-mail de test a été envoyé par le serveur de Human Gambit, par l’API transactionnelle de Brevo, le '
    + quand + ' (heure de Paris).\n\nExpéditeur : Human Gambit <noreply@human-gambit.com>. Une réponse à cet e-mail part vers '
    + 'contact@human-gambit.com.\n\nL’équipe de Human Gambit';
}

const un = e => (e && e.etat === 'ok') ? (Array.isArray(e.donnees) ? e.donnees[0] : e.donnees) : null;
const jetonAdmin = req => {
  const brut = String((req.headers && (req.headers.authorization || req.headers.Authorization)) || '');
  return brut.startsWith('Bearer ') ? brut.slice(7).trim() : '';
};

export function creerHandlerCourriel(deps = {}) {
  const env = deps.env || process.env;
  const fetchFn = deps.fetch || globalThis.fetch;
  const journal = deps.journal;   // undefined : journal par défaut de _courriel.js
  const rpc = deps.rpc || (async (fn, params, options) => (await import('./_supabase.js')).sbTransportRpc(fn, params, options));
  const opts = journal === undefined ? { env, fetchFn } : { env, fetchFn, journal };

  return async function handlerCourriel(req, res) {
    res.setHeader('Cache-Control', 'no-store');
    if (req.method !== 'POST') return res.status(405).json({ ok: false, raison: 'methode' });
    const b = (req.body && typeof req.body === 'object') ? req.body : {};
    const action = String(b.action || '');
    const jeton = typeof b.jeton === 'string' ? b.jeton.trim() : '';
    const admin = jetonAdmin(req);
    const refus = (code, raison) => res.status(code).json({ ok: false, raison });

    if (action === 'test') {
      let email = null;
      if (jeton) {
        const t = un(await rpc('courriel_test_jeton_service', { p_jeton: jeton }, { service: true }).catch(() => null));
        if (!t || t.ok !== true) return refus(403, (t && t.raison) || 'jeton_invalide');
        email = t.email;
      } else {
        if (!admin) return refus(401, 'session_absente');
        const t = un(await rpc('admin_courriel_test_adresse', {}, { jeton: admin }).catch(() => null));
        if (!t || t.ok !== true) return refus(403, (t && t.raison) || 'refus_administration');
        email = t.email;
      }
      const e = await envoyerCourriel({ a: email, sujet: SUJET_TEST, texte: texteTest(), repondre: true, contexte: 'test_mj' }, opts);
      if (e.ok && jeton && e.messageId) await rpc('courriel_test_jeton_service', { p_jeton: jeton, p_message_id: e.messageId }, { service: true }).catch(() => null);
      return res.status(200).json(e.ok ? { ok: true, messageId: e.messageId } : { ok: false, raison: e.raison, detail: e.detail || null });
    }

    if (action === 'test_statut') {
      let email = null, messageId = null;
      if (jeton) {
        const t = un(await rpc('courriel_test_jeton_service', { p_jeton: jeton, p_lire: true }, { service: true }).catch(() => null));
        if (!t || t.ok !== true) return refus(403, (t && t.raison) || 'jeton_invalide');
        email = t.email; messageId = t.message_id;
      } else {
        if (!admin) return refus(401, 'session_absente');
        const t = un(await rpc('admin_courriel_test_adresse', {}, { jeton: admin }).catch(() => null));
        if (!t || t.ok !== true) return refus(403, (t && t.raison) || 'refus_administration');
        email = t.email; messageId = typeof b.message_id === 'string' ? b.message_id.slice(0, 300) : null;
      }
      if (!messageId) return refus(400, 'message_inconnu');
      const r = await evenementsCourriel({ messageId, email }, { env, fetchFn });
      return res.status(200).json(r);
    }

    if (action === 'sanction') {
      if (!admin) return refus(401, 'session_absente');
      const id = Number(b.sanction);
      if (!Number.isInteger(id) || id <= 0) return refus(400, 'sanction_invalide');
      const p = un(await rpc('admin_sanction_courriel_preparer', { p_id: id }, { jeton: admin }).catch(() => null));
      if (!p || p.ok !== true) return res.status(200).json({ ok: false, raison: (p && p.raison) || 'refus_administration' });
      const e = await envoyerCourriel({ a: p.email, sujet: p.sujet, texte: p.texte, repondre: true, contexte: 'sanction', langue: p.langue }, opts);
      return res.status(200).json(e.ok ? { ok: true } : { ok: false, raison: e.raison, detail: e.detail || null });
    }

    return refus(400, 'action_inconnue');
  };
}

export const handlerCourriel = creerHandlerCourriel();
