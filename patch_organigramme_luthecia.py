#!/usr/bin/env python3
PATH = "plateau-politique.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    { title: 'Villes', postes: [
      ...(postes.ville_a || []),
      ...(postes.ville_b || [])
    ]}"""
new = """    { title: 'Villes', postes: [
      ...(postes.ville_capitale || []),
      ...(postes.ville_a || []),
      ...(postes.ville_b || [])
    ]}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Luthécia ajoutée à la section 'Villes' de l'organigramme.")
