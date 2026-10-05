#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Simplifier queteAccueilVerifierEtapeBatiment : un seul popup, deux boutons en surbrillance ---
old_1 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {
    state.char.queteAccueil = { etape: 'guide_sortie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici on sera tranquille, en plus le responsable électoral est malentendant. Ici on est au cœur du système électoral car c'est ici qu'on vote. On peut aussi voir qui est candidat aux élections par exemple. Chaque pièce est dédiée à un usage.",
      suivant: function() {
        afficherPopupQueteAccueil({
          image: QUETE_ACCUEIL_IMAGES.jeremy,
          titre: 'Jérémy',
          texte: "À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",
          suivant: function() {
            queteAccueilSurbrillance('.sortir-btn', 12000);
          }
        });
      }
    });
  }
}"""

new_1 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {
    state.char.queteAccueil = { etape: 'guide_sortie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici on sera tranquille, en plus le responsable électoral est malentendant. Ici on est au cœur du système électoral car c'est ici qu'on vote. On peut aussi voir qui est candidat aux élections par exemple. Chaque pièce est dédiée à un usage. À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",
      suivant: function() {
        // Les deux boutons reels concernes sont mis en surbrillance en meme temps :
        // "Voir les candidats" (bouton d'ordre de la piece) et "Sortir" (bouton de batiment).
        queteAccueilSurbrillance('.action-btn[onclick*="consulter_elections"]', 12000);
        queteAccueilSurbrillance('.sortir-btn', 12000);
      }
    });
  }
}"""

assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Salle des Élections simplifiée : un seul message, deux boutons en surbrillance simultanée.")
