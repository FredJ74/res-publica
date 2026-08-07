#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'organiser_blocus_syndical') { doOrganiserBlocusSyndical(); return; }"""
new = """  if (fn === 'organiser_blocus_syndical') { doOrganiserBlocusSyndical(); return; }
  if (fn === 'acheter_ressources_entrepot') { doOuvrirAchatEntrepot(); return; }"""

if content.count(old) == 1:
    content = content.replace(old, new)
    print("✅ Ordre routé (ancré sur organiser_blocus_syndical).")
else:
    # Repli : ancrage different si le premier motif n'est pas trouve tel quel
    old2 = """function routeOrder(fn) {"""
    idx = content.find(old2)
    assert idx != -1, "point d'ancrage introuvable"
    insert_after = content.find('\n', idx) + 1
    content = content[:insert_after] + "  if (fn === 'acheter_ressources_entrepot') { doOuvrirAchatEntrepot(); return; }\n" + content[insert_after:]
    print("✅ Ordre routé (ancré sur le début de la fonction de routage).")

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
