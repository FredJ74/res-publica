#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function afficherPopupQueteAccueil(opts) {"""
new = """// =====================
// RAPPEL DE L'ETAPE EN COURS — parler a Jeremy (mot-cle) rejoue le meme message et la meme
// surbrillance que ceux affiches au demarrage de l'etape en cours, pour un joueur perdu
// (clic trop rapide, popup fermee sans lire...). Couvre les etapes a partir de
// 'jeremy_groupe' (avant, Jeremy n'est pas encore rencontre).
// =====================
function queteAccueilRappel() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return false;
  const etape = state.char.queteAccueil.etape;

  const rappels = {
    jeremy_groupe: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va dans la salle des élections, vous vous souvenez ?",
        suivant: function() { queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000); } });
    },
    guide_salle_elections: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va dans la salle des élections.",
        suivant: function() { queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000); } });
    },
    guide_sortie: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On sort de l'Hôtel de Ville, vous vous souvenez ?",
        suivant: function() {
          queteAccueilSurbrillance('.action-btn[onclick*="consulter_elections"]', 12000);
          queteAccueilSurbrillance('.sortir-btn', 12000);
        } });
    },
    attente_gauche_dispensaire: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allons sur la gauche, j'ai quelque chose à vous montrer.", suivant: null });
    },
    attente_entree_dispensaire: function() {
      afficherGuidageUnBatiment('luthecia-imprimerie', 'dispensaire-public', 'Entrons ici !');
    },
    attente_entree_mairie: function() {
      queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
    },
    attente_fiche_personnage: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allez donc consulter votre fiche personnage, je vous montrerai la suite après.",
        suivant: function() { queteAccueilSurbrillance('[onclick*="openSelfView"]', 15000); } });
    },
    attente_hotel: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va à l'hôtel-restaurant, vous vous souvenez ? C'est le deuxième bâtiment après l'Hôtel de Ville, sur la droite en sortant.",
        suivant: null });
    },
    attente_bar: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allons faire un tour au bar, juste à côté.",
        suivant: function() { queteAccueilSurbrillance(".piece-tab[onclick*=\\\",'bar',\\\"]", 15000); } });
    },
    attente_bar_apres_chambre: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allons faire un tour au bar, juste à côté.",
        suivant: function() { queteAccueilSurbrillance(".piece-tab[onclick*=\\\",'bar',\\\"]", 15000); } });
    },
    attente_offre_verre: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
        suivant: function() { queteAccueilSurbrillance('.action-btn[onclick*="boire_verre"]', 12000); } });
    },
    guide_stade: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "On va au stade de foot ! Sortez, allez à gauche, puis prenez la route perpendiculaire et tournez à droite. Le plan peut vous aider, en haut à droite.",
        suivant: function() { queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000); } });
    },
    stade_attente_action: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Allez-y, jetez un œil, essayez quelque chose au stade !", suivant: null });
    },
    stade_apres_action: function() { afficherConseilArchetypeJeremy(); },
    stade_libre_minuteur: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.", suivant: null });
    },
    reprise_contact: function() { afficherRepriseContactJeremy(); },
    choix_destination: function() { queteAccueilRepriseOui(); },
    attente_depart_jeremy: function() {
      afficherPopupQueteAccueil({ image: QUETE_ACCUEIL_IMAGES.jeremy, titre: 'Jérémy',
        texte: "Nos chemins se séparent ici, vous vous souvenez ? Si besoin, cliquez sur ma fiche pour m'ajouter à vos contacts, puis utilisez le bouton Messages/Forums.",
        suivant: function() {
          queteAccueilSurbrillance(".person-card[onclick*=\\\"openPnjModal('\\\"]", 15000);
          queteAccueilSurbrillance('#btn-messages', 15000);
        } });
    }
  };

  if (rappels[etape]) { rappels[etape](); return true; }
  return false;
}

function afficherPopupQueteAccueil(opts) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Système de rappel créé : queteAccueilRappel() rejoue le message + la surbrillance de l'étape en cours.")
