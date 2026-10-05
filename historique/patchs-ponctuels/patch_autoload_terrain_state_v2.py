#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof maxenceVerifierPresence === 'function') {
    maxenceVerifierPresence(buildingId, roomId);
  }

  // Loc"""
new = """  if (typeof maxenceVerifierPresence === 'function') {
    maxenceVerifierPresence(buildingId, roomId);
  }

  // Rafraichir l'etat reel du terrain depuis Supabase (proprietaire, construction, permis) —
  // corrige le bug ou un rafraichissement de page laissait croire qu'un terrain deja achete
  // etait redevenu libre. Re-affiche les ordres une fois la donnee fraiche disponible.
  if (buildingId?.startsWith('terrain-a-batir') && typeof chargerTerrainState === 'function') {
    chargerTerrainState(buildingId).then(function() {
      if (state.currentBuilding === buildingId && state.currentRoom === roomId) {
        renderRoomActions(room, buildingId, roomId);
      }
    }).catch(function() {});
  }

  // Loc"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Étape 1 : chargement automatique de l'état réel du terrain à l'entrée dans la pièce.")
