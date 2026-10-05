#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof queteAccueilVerifierEtapeBatiment === 'function') {
    queteAccueilVerifierEtapeBatiment(buildingId, roomId);
  }

  // Loc"""
new = """  if (typeof queteAccueilVerifierEtapeBatiment === 'function') {
    queteAccueilVerifierEtapeBatiment(buildingId, roomId);
  }
  if (typeof maxenceVerifierPresence === 'function') {
    maxenceVerifierPresence(buildingId, roomId);
  }

  // Loc"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook Maxence ajouté dans enterRoom.")
