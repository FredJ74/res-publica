#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  const pieceImg = document.getElementById('piece-image');
  const imgUrl = empireRoomImg || roomOverride?.imageUrl || room.imageUrl;
  if (imgUrl) {
    pieceImg.style.background = `linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0) 65%, rgba(0,0,0,0.18) 100%), url('${imgUrl}') center/cover no-repeat`;
  } else {
    pieceImg.style.background = room.imageBg || 'linear-gradient(135deg,#0a0a07,#0f0d08)';
  }"""
new = """  const pieceImg = document.getElementById('piece-image');
  const enigme1Img = (typeof enigme1ImageSalleVide === 'function') ? enigme1ImageSalleVide(buildingId, roomId) : null;
  const imgUrl = enigme1Img || empireRoomImg || roomOverride?.imageUrl || room.imageUrl;
  if (imgUrl) {
    pieceImg.style.background = `linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0) 65%, rgba(0,0,0,0.18) 100%), url('${imgUrl}') center/cover no-repeat`;
  } else {
    pieceImg.style.background = room.imageBg || 'linear-gradient(135deg,#0a0a07,#0f0d08)';
  }
  if (typeof enigme1InjecterZoneCliquable === 'function') enigme1InjecterZoneCliquable(buildingId, roomId);"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook branché : priorité d'image + zone cliquable du cadre vide.")
