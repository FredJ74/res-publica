#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... Les archives de la Mairie permettraient sans doute d'en apprendre davantage sur cet homme.\""""
new_1 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... Où pourrait-on trouver des informations sur un ancien maire de la ville ?\""""
assert content.count(old_1) == 1, f"maires : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... Le Commissariat permettrait sans doute d'en apprendre davantage sur cet homme.\""""
new_2 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... Qui, en ville, garderait la mémoire des affaires criminelles d'autrefois ?\""""
assert content.count(old_2) == 1, f"criminels : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Étude Notariale permettrait sans doute d'en apprendre davantage sur cet homme.\""""
new_3 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... Qui, en ville, garde une trace écrite de chaque terrain qui change de mains ?\""""
assert content.count(old_3) == 1, f"entrepreneurs : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

old_4 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Imprimerie L'Autruche Entravée permettrait sans doute d'en apprendre davantage sur cet homme.\""""
new_4 = """    texteAccroche: "Étrange qu'un portrait manque justement ici... Où retrouverait-on ce que la presse d'alors a bien pu écrire sur lui ?\""""
assert content.count(old_4) == 1, f"plumes : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Les 4 indices reformulés en questions ouvertes, sans nommer le lieu directement.")
