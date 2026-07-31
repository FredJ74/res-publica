#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Nouvelle fonction : reaction a la fermeture de la fiche personnage ---
old_1 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {"""
new_1 = """// Declenchee depuis le hook ajoute dans closeCharSheet() (plateau-personnage.js).
function queteAccueilApresFichePersonnage() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  if (state.char.queteAccueil.etape !== 'attente_fiche_personnage') return;

  state.char.queteAccueil = { etape: 'attente_hotel' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Donc une bonne chambre, c'est primordial, mais un bon repas aussi. On va à l'hôtel-restaurant ? C'est le deuxième bâtiment après l'Hôtel de Ville.",
    suivant: null
  });
}

function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Ajouter les etapes Hotel-Restaurant + Bar + guidage Stade dans queteAccueilVerifierEtapeBatiment ---
old_2 = """  if (etape === 'attente_entree_dispensaire' && buildingId === 'dispensaire-public') {"""
new_2 = """  if (etape === 'attente_hotel' && buildingId === 'hotel-republica') {
    state.char.queteAccueil = { etape: 'attente_bar' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici vous pouvez réserver une chambre, ou si vous avez les moyens, louer une suite. Une bonne nuit ici, c'est plus de PA récupérés en dormant le lendemain.",
      suivant: function() {
        queteAccueilSurbrillance('.action-btn[onclick*="reserver_chambre_hotel"]', 12000);
      }
    });
    return;
  }

  if (etape === 'attente_bar' && buildingId === 'hotel-republica' && roomId === 'bar') {
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
  }

  if (etape === 'guide_stade' && buildingId === 'stade') {
    state.char.queteAccueil = { etape: 'stade_libre' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché. Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter. Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et s'entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça. On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters. Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters... Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
      suivant: null
    });
    return;
  }

  if (etape === 'attente_entree_dispensaire' && buildingId === 'dispensaire-public') {"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hôtel-Restaurant (version courte) + Bar + guidage Stade ajoutés.")
