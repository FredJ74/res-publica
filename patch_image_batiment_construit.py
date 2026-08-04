#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  let chantierImg = null;
  if (buildingId?.startsWith('terrain-a-batir') && typeof getTerrainState === 'function') {
    const tsChantier = getTerrainState(buildingId);
    if (tsChantier?.chantier) chantierImg = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/chantier-en-cours.png';
  }
  const imgUrl = enigme1Img || chantierImg || empireRoomImg || roomOverride?.imageUrl || room.imageUrl;"""
new = """  let chantierImg = null;
  if (buildingId?.startsWith('terrain-a-batir') && typeof getTerrainState === 'function') {
    const tsChantier = getTerrainState(buildingId);
    if (tsChantier?.chantier) {
      chantierImg = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/chantier-en-cours.png';
    } else if (tsChantier?.niveau_construction && typeof NIVEAUX_CONSTRUCTION !== 'undefined') {
      chantierImg = NIVEAUX_CONSTRUCTION[tsChantier.niveau_construction]?.imageUrl || null;
    }
  }
  const imgUrl = enigme1Img || chantierImg || empireRoomImg || roomOverride?.imageUrl || room.imageUrl;"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Image du bâtiment fini affichée une fois le chantier livré (avant : image du chantier ; après : image du niveau construit).")
