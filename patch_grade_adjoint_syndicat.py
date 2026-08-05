#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    grades: {
      republic: ['Adhérent', 'Délégué', 'Secrétaire Général', 'Confédéral'],
      narco:    ['Miembro', 'Delegado', 'Secretario', 'El Capo Sindical'],
      soviet:   ['Travailleur Uni', 'Délégué du Peuple', 'Commissaire Syndical', 'Grand Camarade'],
      khalija:  ['Membre', 'Représentant', 'Directeur Syndical', 'Grand Cheikh Ouvrier'],
    },"""
new = """    grades: {
      republic: ['Adhérent', 'Secrétaire Général Adjoint', 'Secrétaire Général', 'Confédéral'],
      narco:    ['Miembro', 'Secretario Adjunto', 'Secretario', 'El Capo Sindical'],
      soviet:   ['Travailleur Uni', 'Commissaire Adjoint', 'Commissaire Syndical', 'Grand Camarade'],
      khalija:  ['Membre', 'Directeur Adjoint', 'Directeur Syndical', 'Grand Cheikh Ouvrier'],
    },"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Grade 'Secrétaire Général Adjoint' (et équivalents) créé, à l'indice 1, pour les 4 empires.")
