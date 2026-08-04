#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  const enigme1Img = (typeof enigme1ImageSalleVide === 'function') ? enigme1ImageSalleVide(buildingId, roomId) : null;
  const imgUrl = enigme1Img || empireRoomImg || roomOverride?.imageUrl || room.imageUrl;"""
new = """  const enigme1Img = (typeof enigme1ImageSalleVide === 'function') ? enigme1ImageSalleVide(buildingId, roomId) : null;
  let chantierImg = null;
  if (buildingId?.startsWith('terrain-a-batir') && typeof getTerrainState === 'function') {
    const tsChantier = getTerrainState(buildingId);
    if (tsChantier?.chantier) chantierImg = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/chantier-en-cours.png';
  }
  const imgUrl = enigme1Img || chantierImg || empireRoomImg || roomOverride?.imageUrl || room.imageUrl;"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Image du chantier intégrée à la priorité d'affichage de la pièce.")
