#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      zones: [
        { xPct: [0, 45],   nom: 'Musée de la Ville de Luthécia', type: 'batiment', buildingId: 'musee-ville-luthecia' },
        { xPct: [55, 100], nom: 'Musée National de Republia',    type: 'batiment', buildingId: 'musee-national-republia' }
      ],"""
new = """      zones: [
        { xPct: [0, 45],   nom: 'Musée de la Ville de Luthécia', type: 'batiment', buildingId: 'musee-ville-luthecia' },
        { xPct: [28, 52],  yPct: [20, 78], nom: 'Parc Botanique National', type: 'batiment', buildingId: 'parc-botanique-national' },
        { xPct: [55, 100], nom: 'Musée National de Republia',    type: 'batiment', buildingId: 'musee-national-republia' }
      ],"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Zone cliquable du parc ajoutée sur la scène de rue.")
