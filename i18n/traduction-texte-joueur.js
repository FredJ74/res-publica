/* Service de traduction des textes de joueurs, côté écran (décision n° 10 de Fred, 26/11/2026 : le forum d'abord, puis les
 * rumeurs de la chronique). Il ne transmet JAMAIS le texte : seulement la source (type, identifiant, champ) et la langue du
 * lecteur ; le serveur relit l'original sous les droits du lecteur (/api/traduction). Mémoire de la session pour ne pas
 * redemander une traduction déjà obtenue, et regroupement des demandes identiques simultanées.
 * Sans service (migration 20261126300000 non appliquée, quota atteint, panne) : r.ok === false, l'original reste affiché.
 */
(function (global) {
  'use strict';
  const memoire = new Map();
  const enCours = new Map();
  async function traduire({ type, id, field, langueCible }) {
    const cle = [type, id, field, langueCible].join('|');
    if (memoire.has(cle)) return memoire.get(cle);
    if (enCours.has(cle)) return enCours.get(cle);
    const promesse = (async () => {
      try {
        if (typeof global.rpAuthAssurerSession === 'function') await global.rpAuthAssurerSession();
        const jeton = typeof global.rpAuthJeton === 'function' ? global.rpAuthJeton() : null;
        if (!jeton) return { ok: false, raison: 'session' };
        const r = await fetch('/api/traduction', { method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton },
          body: JSON.stringify({ type, id: String(id), field, langue: langueCible }) });
        const j = await r.json().catch(() => null);
        const res = j && typeof j === 'object' ? j : { ok: false, raison: 'reponse_invalide' };
        // Seules les réponses abouties (ou les refus définitifs) sont mémorisées : une panne se retente plus tard.
        if (res.ok === true || ['requete_invalide', 'texte_invalide', 'quota_atteint'].includes(res.raison)) memoire.set(cle, res);
        return res;
      } catch (_) { return { ok: false, raison: 'reseau' }; }
      finally { enCours.delete(cle); }
    })();
    enCours.set(cle, promesse);
    return promesse;
  }
  global.RPTraductionTexteJoueur = Object.freeze({ traduire });
})(window);
