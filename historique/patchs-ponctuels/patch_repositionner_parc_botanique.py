#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    'musee-ville-luthecia':        [270, 175,  75,  40],
    'parc-botanique-national':     [345, 175,  10,  40],
    'musee-national-republia':     [355, 175,  75,  40],"""
new = """    'musee-ville-luthecia':        [270, 175,  75,  40],
    'musee-national-republia':     [345, 175,  75,  40],
    'parc-botanique-national':     [270, 125,  75,  40],"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Parc Botanique repositionné au nord du Musée de la Ville, avec une vraie largeur (75px au lieu de 10px).")
