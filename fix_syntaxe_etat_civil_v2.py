#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """  const dejaImprimee = state.inventory.some(function(item) { return item.nom === 'Fiche d\\\\'état-civil — ' + fiche.nom; });"""
new_1 = """  const dejaImprimee = state.inventory.some(function(item) { return item.nom === 'Fiche d\\'état-civil — ' + fiche.nom; });"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """    nom: 'Fiche d\\\\'état-civil — ' + fiche.nom,"""
new_2 = """    nom: 'Fiche d\\'état-civil — ' + fiche.nom,"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Deuxième erreur de syntaxe corrigée (Fiche d'état-civil).")
