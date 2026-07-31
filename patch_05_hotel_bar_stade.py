#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = '''    texte: "Donc une bonne chambre, c'est primordial, mais un bon repas aussi. On va à l'hôtel-restaurant ? C'est le deuxième bâtiment après l'Hôtel de Ville.",'''
new_1 = '''    texte: "Donc une bonne chambre, c'est primordial, mais un bon repas aussi.<br><br>On va à l'hôtel-restaurant ? C'est le deuxième bâtiment après l'Hôtel de Ville. Vous vous souvenez où c'est ? On en vient. Il faut sortir du bâtiment et aller à droite.",'''
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Parfait ! Maintenant, dès que vous passerez l'ordre Dormir dans cette chambre réservée, vous récupérerez plus de PA et de Moral que si vous dormiez n'importe où. Bon, en attendant, allons faire un tour au bar, juste à côté.",
    suivant: null
  });
}"""
new_2 = """  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Parfait ! Maintenant, dès que vous passerez l'ordre Dormir dans cette chambre réservée, vous récupérerez plus de PA et de Moral que si vous dormiez n'importe où. Bon, en attendant, allons faire un tour au bar, juste à côté.",
    suivant: function() {
      queteAccueilSurbrillance(".piece-tab[onclick*=\\",'bar',\\"]", 15000);
    }
  });
}"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = '''      texte: "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté... Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes. Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",'''
new_3 = '''      texte: "Ici c'est un lieu un peu spécial, pas toujours bien fréquenté...<br><br>Enfin, c'est ce qu'on m'a dit, je n'ai pas le droit de venir seul ici, seulement avec des adultes.<br><br>Vous pouvez m'offrir un verre ? J'ai très soif à force de parler.",'''
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

old_4 = '''    texte: "On va aller dans un super endroit : le stade de foot ! Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite. Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",'''
new_4 = '''    texte: "On va aller dans un super endroit : le stade de foot !<br><br>Pour ça il faut sortir puis aller sur la gauche, et ensuite, prendre la route perpendiculaire, puis tourner à droite.<br><br>Au pire, si vous êtes perdu, vous pouvez consulter le plan, en haut à droite.",'''
assert content.count(old_4) == 1, f"bloc 4 : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

old_5 = '''      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché. Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter. Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et s'entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça. On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters. Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters... Allez-y, jetez un œil, essayez quelque chose !",'''
new_5 = '''      texte: "Ça c'est le stade de notre équipe de Luthécia ! On y est tous très attaché.<br><br>Il y a 12 clubs qui s'affrontent pour savoir qui sera le meilleur. Pour connaître le classement, il suffit de le consulter.<br><br>Si vous voulez intégrer l'équipe, il faut prendre sa licence dans le vestiaire et vous entraîner jusqu'à faire partie des 15 meilleurs joueurs du club. Demandez conseil à l'entraîneur adjoint, il est là pour ça.<br><br>On peut boire un coup, acheter des accessoires du club, parier sur les matchs, ou encore rejoindre le club des supporters.<br><br>Attention, il ne faut pas croire mais c'est bien plus qu'un endroit où l'on fait du sport. Vous verrez à l'usage, mais ici des maires ont perdu leur poste ou à l'inverse ont été réélus selon l'humeur des supporters...<br><br>Allez-y, jetez un œil, essayez quelque chose !",'''
assert content.count(old_5) == 1, f"bloc 5 : trouvé {content.count(old_5)} fois (attendu 1)"
content = content.replace(old_5, new_5)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Textes Hôtel/Bar/Stade mis à jour + surbrillance de l'onglet Bar ajoutée.")
