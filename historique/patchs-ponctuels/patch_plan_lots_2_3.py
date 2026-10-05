#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    'terrain-a-batir-1':           [ 10, 345, 110, 26],
    'terrain-a-batir-4':           [ 10, 375, 110, 26],
    'terrain-a-batir-5':           [ 10, 405, 110, 26],
    'terrain-a-batir-6':           [ 10, 435, 110, 26],
    'terrain-a-batir-7':           [ 10, 465, 110, 26],"""

new = """    'terrain-a-batir-1':           [ 10, 345, 110, 26],
    'terrain-a-batir-2':           [ 10, 375, 110, 26],
    'terrain-a-batir-3':           [ 10, 405, 110, 26],
    'terrain-a-batir-4':           [ 10, 435, 110, 26],
    'terrain-a-batir-5':           [ 10, 465, 110, 26],"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Plan de Luthécia mis à jour : les 5 lots de la Châtaigneraie (6/7 retirés du plan).")
