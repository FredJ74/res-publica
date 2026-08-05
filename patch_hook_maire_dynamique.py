#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof verifierBlocusEntree === 'function') {
    verifierBlocusEntree(buildingId, roomId);
  }"""
new = """  if (typeof verifierBlocusEntree === 'function') {
    verifierBlocusEntree(buildingId, roomId);
  }
  if (typeof verifierPresenceMaireLuthecia === 'function') {
    verifierPresenceMaireLuthecia(buildingId, roomId);
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Vérification de la présence du maire branchée à l'entrée dans la pièce.")
