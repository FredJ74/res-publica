#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Ajouter le dictionnaire de conseils par archetype, apres QUETE_ACCUEIL_ICONES_FLECHES ---
old_1 = """const QUETE_ACCUEIL_ICONES_FLECHES = {
  arriere: '↓', gauche: '←', toutDroit: '↑', droite: '→'
};"""
new_1 = """const QUETE_ACCUEIL_ICONES_FLECHES = {
  arriere: '↓', gauche: '←', toutDroit: '↑', droite: '→'
};

// Reaction de Jeremy selon l'archetype deja choisi a la creation du personnage (state.char.archetype).
// Oriente vers le(s) type(s) d'organisation pertinent(s), sans poser de question ouverte au joueur.
const QUETE_ACCUEIL_CONSEILS_ARCHETYPE = {
  politician:     "Ambitieux, à ce qu'on dit sur vous... Vous comptez fonder votre propre parti, ou plutôt rejoindre une formation déjà en place ? J'en connais quelques-unes, si ça vous intéresse. Regardez du côté des organisations politiques.",
  authoritarian:  "Ordre et discipline, hein ? Ça tombe bien, il y a une Loge très à cheval sur les principes, si vous voyez ce que je veux dire. Ou sinon, il paraît qu'on recrute du côté de l'armée...",
  oligarch:       "Capitaliste ! L'argent avant tout, c'est ça ? Il existe des organisations économiques qui pourraient vous intéresser, on y parle chiffres et contrats toute la journée.",
  informer:       "Vous aimez faire circuler l'information, on dirait. Le journal du coin recrute peut-être, ou alors une organisation médiatique, si vous préférez rester dans l'ombre du micro.",
  legalist:       "Légaliste... vous devez adorer les formulaires, alors ! Ça tombe bien, on en a beaucoup ici. Sinon, la politique ou la Loge, ça vous dit ? On y respecte scrupuleusement les procédures.",
  believer:       "Une conviction profonde, à ce qu'on raconte. Vous devriez faire un tour du côté d'une organisation religieuse, ça pourrait vous parler.",
  shadow:         "Un homme de l'ombre, hein ? Discret, discret... Je ne devrais peut-être pas vous en parler, mais il existe une Loge, très discrète justement. Ou pire encore, si vous voyez ce que je veux dire.",
  anticapitalist: "Anti-capitaliste ! Vous devriez faire un tour du côté du syndicat, ils cherchent toujours du monde pour la prochaine manifestation.",
  criminal:       "Un criminel, vous ? Ne le répétez à personne, mais je m'en doutais un peu... Vous comptez travailler seul, ou plutôt rejoindre une organisation bien établie ? Il y en a une, justement, très active en ville."
};
const QUETE_ACCUEIL_CONSEIL_DEFAUT =
  "Quel que soit votre chemin, sachez qu'il existe plusieurs organisations en ville. Ça vaut le coup d'y jeter un œil.";"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. L'arrivee au stade enchaine maintenant sur le conseil d'archetype ---
old_2 = """  if (etape === 'guide_stade' && buildingId === 'stade') {
    state.char.queteAccueil = { etape: 'stade_libre' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché. Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter. Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et s'entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça. On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters. Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters... Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
      suivant: null
    });
    return;
  }"""
new_2 = """  if (etape === 'guide_stade' && buildingId === 'stade') {
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
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Nouvelle fonction affichant le conseil d'archetype, puis la phrase de conge finale ---
old_3 = """function afficherPopupQueteAccueil(opts) {"""
new_3 = """function afficherConseilArchetypeJeremy() {
  const archetype = state.char && state.char.archetype;
  const conseil = QUETE_ACCUEIL_CONSEILS_ARCHETYPE[archetype] || QUETE_ACCUEIL_CONSEIL_DEFAUT;
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: conseil,
    suivant: function() {
      afficherPopupQueteAccueil({
        image: QUETE_ACCUEIL_IMAGES.jeremy,
        titre: 'Jérémy',
        texte: "Je vous laisse découvrir. Si vous avez des questions pendant la visite, n'hésitez pas à me les poser.",
        suivant: null
      });
    }
  });
}

function afficherPopupQueteAccueil(opts) {"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Conseil d'archétype de Jérémy ajouté au stade.")
