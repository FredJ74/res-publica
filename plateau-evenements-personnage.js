// JOURNAL D'ÉVÉNEMENTS ÉCRIT PAR LE SERVEUR (Santé et forêt, Fred, 22/11/2026, GAME-DESIGN-SANTE-20261122.md).
// Le serveur écrit dans personnage_evenements (réveil, MST, diagnostic d'un médecin, objet montré…) ; jamais par courrier.
// Le navigateur lit ses entrées non lues (personnage_evenements_lire) au chargement, à chaque signal du personnage
// (plateau-temps-reel.js) et toutes les minutes, puis les inscrit au journal. Texte affiché en texte brut (échappé).
// Un module peut réagir à une clé précise (fenêtre, etc.) : window.rpEvenementsPersonnageGestionnaires[cle] = fn(ev).
(function (global) {
  'use strict';
  const gestionnaires = global.rpEvenementsPersonnageGestionnaires = global.rpEvenementsPersonnageGestionnaires || {};
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const CLASSES = { bon: 'event-good', mauvais: 'event-bad', neutre: '' };
  let enCours = false;
  async function lireEvenementsPersonnage() {
    const s = global.state;
    if (enCours || !(s && s.char && s.char.name) || typeof global.sbRpc !== 'function') return;
    enCours = true;
    try {
      const r = await global.sbRpc('personnage_evenements_lire', {});
      if (!r || r.ok !== true) return;
      for (const ev of (r.evenements || [])) {
        const p = ev.params || {};
        if (ev.texte && typeof global.addJournalEntry === 'function') global.addJournalEntry(esc(ev.texte), CLASSES[p.ton] || '');
        const g = gestionnaires[ev.cle];
        if (typeof g === 'function') { try { g(ev); } catch (e) { console.warn('événement ' + ev.cle, e); } }
      }
    } catch (e) {
      // Fonction serveur pas encore déployée ou panne passagère : on réessaiera au prochain signal.
    } finally { enCours = false; }
  }
  global.lireEvenementsPersonnage = lireEvenementsPersonnage;
  if (typeof document !== 'undefined') {
    setTimeout(lireEvenementsPersonnage, 6000);
    setInterval(lireEvenementsPersonnage, 60000);
  }
})(typeof window !== 'undefined' ? window : globalThis);
