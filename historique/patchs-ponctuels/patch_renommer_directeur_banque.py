#!/usr/bin/env python3

# --- data.js ---
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """{name:'Directeur Mercier', role:"PNJ - Directeur d'agence", rel:'neutral', job:'directeur'}"""
new_1 = """{name:'Laurent Barre', role:"PNJ - Directeur d'agence", rel:'neutral', job:'directeur'}"""
assert content.count(old_1) == 1, f"data.js bloc 1 : trouvé {content.count(old_1)}"
content = content.replace(old_1, new_1)

old_2 = """Le Directeur Mercier ne pose jamais de questions sur le contenu."""
new_2 = """Le Directeur Barre ne pose jamais de questions sur le contenu."""
assert content.count(old_2) == 1, f"data.js bloc 2 : trouvé {content.count(old_2)}"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ data.js : 2 occurrences renommées.")

# --- plateau-enigme-portrait.js ---
PATH2 = "plateau-enigme-portrait.js"
with open(PATH2, "r", encoding="utf-8") as f:
    content2 = f.read()

old_3 = """Directeur Mercier</div>';"""
new_3 = """Laurent Barre</div>';"""
assert content2.count(old_3) == 1, f"enigme bloc : trouvé {content2.count(old_3)}"
content2 = content2.replace(old_3, new_3)

with open(PATH2, "w", encoding="utf-8") as f:
    f.write(content2)
print("✅ plateau-enigme-portrait.js : 1 occurrence renommée.")

# --- plateau-pnj.js ---
PATH3 = "plateau-pnj.js"
with open(PATH3, "r", encoding="utf-8") as f:
    content3 = f.read()

old_4 = """  // Enigme du portrait disparu : Clerc Delhune (notaire) et Directeur Mercier (banquier),"""
new_4 = """  // Enigme du portrait disparu : Clerc Delhune (notaire) et Laurent Barre (banquier),"""
assert content3.count(old_4) == 1, f"pnj bloc 1 : trouvé {content3.count(old_4)}"
content3 = content3.replace(old_4, new_4)

old_5 = """    if (nomCourtEnigme === 'Directeur Mercier' && /coffre|thibault/i.test(action)) {"""
new_5 = """    if (nomCourtEnigme === 'Laurent Barre' && /coffre|thibault/i.test(action)) {"""
assert content3.count(old_5) == 1, f"pnj bloc 2 : trouvé {content3.count(old_5)}"
content3 = content3.replace(old_5, new_5)

with open(PATH3, "w", encoding="utf-8") as f:
    f.write(content3)
print("✅ plateau-pnj.js : 2 occurrences renommées.")
