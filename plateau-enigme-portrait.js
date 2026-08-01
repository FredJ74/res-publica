// plateau-enigme-portrait.js
// Enigme freemium n°1 de Luthecia — Le Portrait Disparu.
// Etat sauvegarde sur le personnage : state.char.enigme1 = { etape, variante, dateDeclenchement }
//
// Etapes :
//   (absent / non_commencee) -> pas encore declenchee (personnage cree il y a moins de 3 jours)
//   declenchee               -> le mystere a ete annonce dans le journal, le joueur peut aller au musee
//   relancee                 -> relance unique a J+6 si le joueur n'a toujours rien fait
//   (suite a coder : resolution de l'enquete)

const ENIGME1_VARIANTES = ['maire', 'criminel', 'entrepreneur', 'plume'];
const ENIGME1_DELAI_DECLENCHEMENT_JOURS = 3;
const ENIGME1_DELAI_RELANCE_JOURS = 6; // 3 jours apres le declenchement

// Appelee a chaque synchronisation du personnage (hook dans plateau-core.js). Verifie si le
// delai est ecoule et declenche/relance le mystere du musee si besoin. Base sur la vraie date
// de creation du personnage (createdAt), pas sur un minuteur JS ni sur state.day (qui pourrait
// etre partage/different selon le contexte).
function enigme1VerifierDeclenchement() {
  if (typeof state === 'undefined' || !state.char || !state.char.createdAt) return;

  if (!state.char.enigme1) {
    state.char.enigme1 = { etape: 'non_commencee', variante: null };
  }
  const e = state.char.enigme1;

  const maintenant = Date.now();
  const creation = new Date(state.char.createdAt).getTime();
  const joursEcoules = (maintenant - creation) / (1000 * 60 * 60 * 24);

  if (e.etape === 'non_commencee' && joursEcoules >= ENIGME1_DELAI_DECLENCHEMENT_JOURS) {
    // Tirage aleatoire de la variante — fixe definitivement pour ce joueur. Determine
    // uniquement le point d'entree (quel PNJ/lieu le met sur la voie en premier) : les 4
    // salles du musee affichent de toute facon un cadre vide une fois l'enigme declenchee.
    const variante = ENIGME1_VARIANTES[Math.floor(Math.random() * ENIGME1_VARIANTES.length)];
    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      addJournalEntry("Une rumeur circule en ville : il paraît qu'il y a quelque chose d'étrange au musée de la ville...", 'event-secret');
    }
    return;
  }

  if (e.etape === 'declenchee' && joursEcoules >= ENIGME1_DELAI_RELANCE_JOURS) {
    state.char.enigme1.etape = 'relancee';
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      addJournalEntry("La rumeur persiste : le mystère du musée de la ville n'est toujours pas éclairci...", 'event-secret');
    }
  }
}
