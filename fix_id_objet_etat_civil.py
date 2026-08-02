#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  state.inventory.push({
    name: 'Fiche d\\'état-civil — ' + fiche.nom,
    icon: 'ti-file-text',
    desc: texteComplet
  });"""
new = """  state.inventory.push({
    id: 'fiche-etat-civil-' + fiche.nom.replace(/\\s+/g, '-').toLowerCase() + '-' + Date.now(),
    name: 'Fiche d\\'état-civil — ' + fiche.nom,
    icon: 'ti-file-text',
    desc: texteComplet
  });"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Champ id ajouté à l'objet fiche d'état-civil (nécessaire pour pouvoir le déposer).")
