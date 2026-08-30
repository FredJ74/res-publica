// =====================
// RES PUBLICA — RESSOURCES DE TRADUCTION (I18N LOT 1)
// Perimetre : page d'accueil (index.html, ecran #intro) uniquement. Le francais reste la langue
// source/canonique du projet. Cles semantiques stables (home.*) -- jamais le texte francais
// lui-meme comme cle technique. Aucun namespace multiple pour l'instant (inutile a ce stade,
// un seul namespace 'translation', celui par defaut d'i18next).
//
// home.subtitle et home.tagline reprennent le sous-titre/l'accroche officiels de la page
// d'accueil (lore du jeu) : traduction proposee de bonne foi, a valider par Fred avant diffusion
// large si un terme ne convient pas a l'univers de Res Publica (voir rapport avant commit).
// =====================
window.RP_I18N_RESOURCES = {
  fr: {
    translation: {
      home: {
        subtitle: "Le Grand Jeu du Pouvoir",
        tagline: "Parodie politique multijoueur · 4 empires · Zero scrupule",
        createCharacter: "Creer mon personnage",
        findCharacter: "Retrouver mon personnage",
        findCharacterPlaceholder: "Votre nom de personnage...",
        loadCharacter: "Charger ce personnage"
      }
    }
  },
  en: {
    translation: {
      home: {
        subtitle: "The Great Game of Power",
        tagline: "A multiplayer political satire · 4 empires · No scruples",
        createCharacter: "Create My Character",
        findCharacter: "Find My Character",
        findCharacterPlaceholder: "Your character's name...",
        loadCharacter: "Load This Character"
      }
    }
  }
};
