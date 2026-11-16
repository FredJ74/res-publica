#!/usr/bin/env python3
"""Convertit les trois scènes du commissariat et les deux scènes du lycée de Starovka."""
from pathlib import Path
from PIL import Image, ImageOps
import unicodedata

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/"images/Sovarka/Starovka"
SOURCE_TARGET={
 "Image ChatGPT 16 nov. 2026, 01_26_44-1.png": "Starovka_commissariat_accueil_loc.webp",
 "Image ChatGPT 16 nov. 2026, 01_26_46-2.png": "Starovka_commissariat_bureau_commissaire.webp",
 "Image ChatGPT 16 nov. 2026, 01_26_48-3.png": "Starovka_commissariat_geoles.webp",
 "Cours de langues près des neiges.png": "Starovka_lycee_amphi.webp",
 "Bibliothèque du Lycée de l’Avenir enneigé.png": "Starovka_lycee_bibliotheque.webp",
}
for original,target_name in SOURCE_TARGET.items():
    sources=[p for p in FOLDER.iterdir() if p.suffix.lower()==".png" and unicodedata.normalize("NFC",p.name)==original]
    target=FOLDER/target_name
    if len(sources)==1:
        source=sources[0]
        with Image.open(source) as im:
            assert im.format=="PNG",source
            rgb=ImageOps.exif_transpose(im).convert("RGB")
            dimensions=rgb.size
            rgb.save(target,format="WEBP",quality=85,method=6)
        with Image.open(target) as check:
            assert check.format=="WEBP" and check.size==dimensions
        blob=target.read_bytes()
        assert blob[:4]==b"RIFF" and blob[8:12]==b"WEBP"
        assert len(blob)<source.stat().st_size, f"WebP non compact : {source.name}"
        source.unlink()
        print(f"{source.name} => {target.name} ({len(blob)} octets)")
    elif not sources and target.is_file():
        blob=target.read_bytes()
        assert blob[:4]==b"RIFF" and blob[8:12]==b"WEBP"
    else:
        raise RuntimeError(f"Source PNG absente ou multiple : {original}")

data=ROOT/"data.js"
s=data.read_text(encoding="utf8")
mark="STAROVKA_COMMISSARIAT_LYCEE_CINQ_WEBP_20261116"
if mark not in s:
    s+="""

// STAROVKA_COMMISSARIAT_LYCEE_CINQ_WEBP_20261116
// Décors exclusivement visuels : les ordres et les acteurs existants ne sont pas modifiés.
(function () {
  const cite = WORLD.soviet?.ville_a;
  if (!cite) return;
  const police = cite.buildingContext?.['commissariat-local'];
  const lycee = cite.buildingContext?.universite;
  if (!police || !lycee || !BUILDINGS['commissariat-local'] || !BUILDINGS.universite) {
    throw new Error('Commissariat local ou lycée de Starovka introuvable');
  }
  police.roomOverrides = police.roomOverrides || {};
  const imagesPolice = {
    accueil_loc: 'Starovka_commissariat_accueil_loc.webp',
    bureau_commissaire: 'Starovka_commissariat_bureau_commissaire.webp',
    geoles: 'Starovka_commissariat_geoles.webp'
  };
  for (const [piece, fichier] of Object.entries(imagesPolice)) {
    if (!BUILDINGS['commissariat-local'].rooms[piece]) throw new Error('Pièce de police inconnue : ' + piece);
    Object.assign(police.roomOverrides[piece] = police.roomOverrides[piece] || {}, {
      imageUrl: 'images/Sovarka/Starovka/' + fichier
    });
  }
  lycee.roomOverrides = lycee.roomOverrides || {};
  Object.assign(lycee.roomOverrides.amphi = lycee.roomOverrides.amphi || {}, {
    imageUrl: 'images/Sovarka/Starovka/Starovka_lycee_amphi.webp'
  });
  // Bibliothèque ajoutée au lycée comme lieu de rencontre et d'étude ; aucune mécanique inventée.
  lycee.roomsExtra = lycee.roomsExtra || {};
  lycee.roomsExtra.bibliotheque = {
    name: 'Bibliothèque et salle d’étude',
    imageUrl: 'images/Sovarka/Starovka/Starovka_lycee_bibliotheque.webp',
    imageBg: 'linear-gradient(135deg,#171718,#282c32)',
    desc: 'Rayonnages et tables de travail, à l’abri de la neige. Des lycéens y étudient les langues et consultent des ouvrages.',
    persons: [],
    orders: []
  };
})();
"""
    data.write_text(s,encoding="utf8")
assert all((FOLDER/name).is_file() for name in SOURCE_TARGET.values())
print("Cinq décors Starovka convertis, cinq PNG supprimés, images de salle raccordées.")
