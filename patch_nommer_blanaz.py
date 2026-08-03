#!/usr/bin/env python3
PATH = "plateau-communication.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    motif: "Assassinat d'un conseiller municipal, opposant déclaré au projet industriel sur la parcelle B-127. Le corps de la victime a été découvert enterré sur le site, alors en construction pour le compte de l'entrepreneur Jacques Moulin. Caillon résidait sur place, dans la maison de gardien du site industriel.","""
new = """    motif: "Assassinat de Gaston Blanaz, conseiller municipal et opposant déclaré au projet industriel sur la parcelle B-127. Le corps de la victime a été découvert enterré sur le site, alors en construction pour le compte de l'entrepreneur Jacques Moulin. Caillon résidait sur place, dans la maison de gardien du site industriel.","""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Gaston Blanaz nommé comme victime dans le dossier Caillon.")
