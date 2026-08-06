#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    'quartier-ambassades':         [378, 133, 196, 70],"""
new = """    'quartier-ambassades':         [378, 133, 196, 70],
    'bureau-national-emploi':      [14, 133, 154, 70],"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bureau National de l'Emploi ajouté au plan (nord-ouest, proche du Quartier des Ambassades).")
