#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Fusionner les pieces supplementaires (ctx.roomsExtra) dans la liste des onglets ---
old_1 = """  // Onglets pieces
  const rooms = Object.entries(b.rooms || {});
  const ctxForTabs = getBuildingContext(buildingId);"""
new_1 = """  // Onglets pieces — fusionne les pieces de base avec d'eventuelles pieces supplementaires
  // propres a une ville (ctx.roomsExtra), sans jamais les ajouter aux autres villes qui
  // partagent la meme definition de batiment globale (ex: centre-affaires).
  const ctxForTabs = getBuildingContext(buildingId);
  const rooms = Object.entries({ ...(b.rooms || {}), ...(ctxForTabs?.roomsExtra || {}) });"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. enterRoom : repli sur roomsExtra si la piece n'existe pas dans la definition de base ---
old_2 = """  const room = b.rooms?.[roomId];"""
new_2 = """  const ctxRoomsExtra = getBuildingContext(buildingId)?.roomsExtra;
  const room = b.rooms?.[roomId] || ctxRoomsExtra?.[roomId];"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Mécanisme roomsExtra créé : une pièce peut désormais exister uniquement pour une ville précise.")
