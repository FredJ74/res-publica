#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = "  authoritarian:  \"Ordre et discipline, hein ? Ça tombe bien, il y a une Loge très à cheval sur les principes, si vous voyez ce que je veux dire. Ou sinon, il paraît qu'on recrute du côté de l'armée...\","
new = "  authoritarian:  \"Ordre et discipline, à ce qu'on m'a dit ! Vous devriez tenter votre chance du côté de la Caserne — on y grimpe les échelons, de simple soldat à officier, avec une vraie hiérarchie à respecter. Sinon, il paraît qu'il existe aussi une Loge assez stricte sur les principes, si la discipline version secrète vous tente davantage.\","
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Conseil 'Ordre et discipline' orienté Caserne militaire en priorité.")
