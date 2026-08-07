#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'voler_materiel_chantier') { doVolerMaterielChantier(); return; }"""
new = """  if (fn === 'voler_materiel_chantier') { doVolerMaterielChantier(); return; }
  if (fn === 'acheter_ressources_entrepot') { doOuvrirAchatEntrepot(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre acheter_ressources_entrepot routé.")
