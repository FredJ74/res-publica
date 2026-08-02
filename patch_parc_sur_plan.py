#!/usr/bin/env python3

# --- 1. Ajouter le parc a la liste des batiments de Luthecia (data.js) ---
PATH_DATA = "data.js"
with open(PATH_DATA, "r", encoding="utf-8") as f:
    data = f.read()

old_1 = "'musee-ville-luthecia','musee-national-republia'],"
assert data.count(old_1) == 1, f"data.js : trouvé {data.count(old_1)} fois (attendu 1)"
new_1 = "'musee-ville-luthecia','musee-national-republia','parc-botanique-national'],"
data = data.replace(old_1, new_1)

with open(PATH_DATA, "w", encoding="utf-8") as f:
    f.write(data)
print("✅ Parc ajouté à la liste des bâtiments de Luthécia.")

# --- 2. Position et icone sur le plan (plateau-navigation.js) ---
PATH_NAV = "plateau-navigation.js"
with open(PATH_NAV, "r", encoding="utf-8") as f:
    nav = f.read()

old_2 = """    'musee-ville-luthecia':        [270, 175,  75,  40],
    'musee-national-republia':     [355, 175,  75,  40],"""
new_2 = """    'musee-ville-luthecia':        [270, 175,  75,  40],
    'parc-botanique-national':     [345, 175,  10,  40],
    'musee-national-republia':     [355, 175,  75,  40],"""
assert nav.count(old_2) == 1, f"plateau-navigation.js (position) : trouvé {nav.count(old_2)} fois (attendu 1)"
nav = nav.replace(old_2, new_2)

old_3 = """'musee-ville-luthecia': '🖼', 'musee-national-republia': '🏛',"""
new_3 = """'musee-ville-luthecia': '🖼', 'parc-botanique-national': '🌳', 'musee-national-republia': '🏛',"""
assert nav.count(old_3) == 1, f"plateau-navigation.js (icone) : trouvé {nav.count(old_3)} fois (attendu 1)"
nav = nav.replace(old_3, new_3)

with open(PATH_NAV, "w", encoding="utf-8") as f:
    f.write(nav)
print("✅ Position et icône du parc ajoutées au plan de la ville.")
