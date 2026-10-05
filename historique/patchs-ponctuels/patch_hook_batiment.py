#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Ordres
  renderRoomActions(room, buildingId, roomId);

  // Loc"""
new = """  // Ordres
  renderRoomActions(room, buildingId, roomId);

  if (typeof queteAccueilVerifierEtapeBatiment === 'function') {
    queteAccueilVerifierEtapeBatiment(buildingId, roomId);
  }

  // Loc"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook de quête ajouté dans enterRoom (plateau-navigation.js).")
