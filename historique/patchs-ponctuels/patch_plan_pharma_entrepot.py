#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    'centre-multinodal-luthecia':  [784, 393, 98, 140],"""
new = """    'usine-pharmaceutique-luthecia':[672, 393, 98, 140],
    'centre-multinodal-luthecia':  [784, 393, 98, 140],
    'entrepot-logistique-luthecia': [896, 393, 98, 140],"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Usine Pharmaceutique et Entrepôt Logistique ajoutés au plan, de part et d'autre du Centre Multimodal.")
