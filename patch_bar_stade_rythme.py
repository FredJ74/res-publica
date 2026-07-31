#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Bar : ne plus enchainer automatiquement sur le stade ---
old_1 = """  if ((etape === 'attente_bar' || etape === 'attente_bar_apres_chambre') && buildingId === 'hotel-republica' && roomId === 'bar') {
    state.char.queteAccueil = { etape: 'guide_stade' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté... Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes. Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="boire_verre"]', 12000);
        afficherPopupQueteAccueil({
          image: QUETE_ACCUEIL_IMAGES.jeremy,
          titre: 'Jérémy',
          texte: "On va aller dans un super endroit : le stade de foot ! Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite. Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",
          suivant: function() {
            queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000);
          }
        });
      }
    });
    return;
  }"""
new_1 = """  if ((etape === 'attente_bar' || etape === 'attente_bar_apres_chambre') && buildingId === 'hotel-republica' && roomId === 'bar') {
    state.char.queteAccueil = { etape: 'attente_offre_verre' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté... Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes. Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="boire_verre"]', 12000);
      }
    });
    return;
  }"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Stade : attendre une action avant le conseil d'archetype ---
old_2 = """  if (etape === 'guide_stade' && buildingId === 'stade') {
    state.char.queteAccueil = { etape: 'stade_libre' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché. Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter. Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et s'entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça. On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters. Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters...",
      suivant: afficherConseilArchetypeJeremy
    });
    return;
  }"""
new_2 = """  if (etape === 'guide_stade' && buildingId === 'stade') {
    state.char.queteAccueil = { etape: 'stade_attente_action' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché. Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter. Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et s'entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça. On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters. Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters... Allez-y, jetez un œil, essayez quelque chose !",
      suivant: null
    });
    return;
  }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Nouvelle fonction : notification generique de n'importe quel ordre (hook doOrder) ---
old_3 = """function afficherConseilArchetypeJeremy() {"""
new_3 = """// Declenchee depuis le hook ajoute au tout debut de doOrder() (plateau-router.js).
// Recoit le nom de l'ordre (fn) que le joueur vient de cliquer, quel qu'il soit.
function queteAccueilNotifierOrdre(fn) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'attente_offre_verre' && fn === 'boire_verre') {
    state.char.queteAccueil = { etape: 'guide_stade' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "On va aller dans un super endroit : le stade de foot ! Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite. Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",
      suivant: function() {
        queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000);
      }
    });
    return;
  }

  if (etape === 'stade_attente_action' && state.currentBuilding === 'stade') {
    state.char.queteAccueil = { etape: 'stade_apres_action' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherConseilArchetypeJeremy();
    return;
  }
}

// Arme le minuteur de reprise de contact (90s). Appele a la fin de la sequence du stade,
// pas seulement a l'entree dans le batiment (le joueur peut ne pas changer de piece apres).
function queteAccueilArmerMinuteurStade() {
  state.char.queteAccueil = { etape: 'stade_libre_minuteur' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  setTimeout(function() {
    if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
    if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return;
    afficherRepriseContactJeremy();
  }, 90000);
}

function afficherConseilArchetypeJeremy() {"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

# --- 4. La derniere pop-up ("Je vous laisse decouvrir") arme desormais le minuteur ---
old_4 = """      afficherPopupQueteAccueil({
        image: QUETE_ACCUEIL_IMAGES.jeremy,
        titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
        suivant: null
      });
    }
  });
}"""
new_4 = """      afficherPopupQueteAccueil({
        image: QUETE_ACCUEIL_IMAGES.jeremy,
        titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
        suivant: queteAccueilArmerMinuteurStade
      });
    }
  });
}"""
assert content.count(old_4) == 1, f"bloc 4 : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bar et Stade attendent désormais une vraie action avant d'enchaîner.")
