/* Goulag de Sovarka — verrou d'ouverture côté navigateur (décision de Fred du 17/11/2026).
 *
 * Tant que le serveur ne CONFIRME pas que le goulag est ouvert, tout le client du goulag reste
 * caché : aucun nouveau bouton (pièces du camp, centres de transport, bureau du ministre de la
 * Justice), les ordres actuels des cinq pièces restent, le juge garde la condamnation au QHS.
 *
 * Une seule source : la RPC `sovarka_goulag_ouvert()` (lecture de sovarka_goulag_configuration).
 * Fonction absente, en erreur, injoignable, ou réponse autre que le booléen `true` : FERMÉ.
 * Jamais l'inverse. Aucun message n'est affiché au joueur dans ce cas.
 */
(function () {
  'use strict';
  const DUREE_MS = 5 * 60 * 1000;
  let ouvert = false;
  let promesse = null;
  let verifieLe = 0;

  // Flèche de la rue de l'école de Krasnov vers la cour des bûcherons (point d'arrivée de la
  // traversée) : posée seulement quand le goulag est ouvert.
  function appliquerRue() {
    try {
      // eslint-disable-next-line no-undef
      const noeuds = typeof RUE_CENTRALE_NOEUDS !== 'undefined' ? RUE_CENTRALE_NOEUDS : null;
      const ecole = noeuds && noeuds.soviet && noeuds.soviet['krasnov-rue-ecole-foret'];
      if (!ecole || !ecole.liens) return;
      if (ouvert && noeuds.soviet['krasnov-camp-bucherons']) ecole.liens.droite = 'krasnov-camp-bucherons';
      else if (ecole.liens.droite === 'krasnov-camp-bucherons') delete ecole.liens.droite;
    } catch (_) { /* fermé par défaut */ }
  }

  async function interroger() {
    if (typeof sbTransportRpc !== 'function') return false;
    try {
      const env = await sbTransportRpc('sovarka_goulag_ouvert', {});
      return !!env && env.etat === 'ok' && env.donnees === true;
    } catch (_) { return false; }
  }

  function verifier() {
    const maintenant = Date.now();
    if (promesse && maintenant - verifieLe < DUREE_MS) return promesse;
    verifieLe = maintenant;
    promesse = interroger().then(v => {
      const avant = ouvert;
      ouvert = v === true;
      appliquerRue();
      if (avant !== ouvert && typeof updateUI === 'function') { try { updateUI(); } catch (_) { /* rien */ } }
      return ouvert;
    }, () => { ouvert = false; appliquerRue(); return false; });
    return promesse;
  }

  // Lecture synchrone pour les fournisseurs d'ordres : rend l'état connu (fermé tant que rien
  // n'est confirmé) et relance une vérification pour les joueurs de Sovarka.
  function estOuvert() {
    if (typeof state !== 'undefined' && state && state.country === 'soviet') verifier();
    return ouvert === true;
  }

  if (typeof window !== 'undefined') {
    window.goulagOuvert = estOuvert;
    window.goulagOuvertureVerifier = verifier;
  }
})();
