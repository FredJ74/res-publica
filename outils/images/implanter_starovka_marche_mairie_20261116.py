#!/usr/bin/env python3
"""Implantation strictement graphique de six décors WebP, Starovka uniquement."""
from pathlib import Path
from PIL import Image, ImageOps
import unicodedata

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/"images/Sovarka/Starovka"
SOURCE_TARGET={
 "Image ChatGPT 16 nov. 2026, 01_08_10-1.png": "Starovka_mairie_accueil_mairie.webp",
 "Image ChatGPT 16 nov. 2026, 01_08_12-2.png": "Starovka_mairie_bureau_maire_local.webp",
 "Image ChatGPT 16 nov. 2026, 01_08_14-3.png": "Starovka_mairie_bureau_maire_adjoint.webp",
 "Image ChatGPT 16 nov. 2026, 01_08_15-4.png": "Starovka_mairie_salle_elections.webp",
 "Image ChatGPT 16 nov. 2026, 01_08_17-5.png": "Starovka_mairie_salle_partis.webp",
 "Marché d’hiver de Starovka enneigé.png": "Starovka_marche_marche_ext.webp",
}
for orig, dest in SOURCE_TARGET.items():
    matches=[p for p in FOLDER.iterdir() if p.suffix.lower()==".png" and unicodedata.normalize("NFC",p.name)==orig]
    target=FOLDER/dest
    if len(matches)==1:
        source=matches[0]
        with Image.open(source) as im:
            assert im.format=="PNG",source
            img=ImageOps.exif_transpose(im).convert("RGB")
            size=img.size
            img.save(target,format="WEBP",quality=85,method=6)
        with Image.open(target) as check:
            assert check.format=="WEBP" and check.size==size
        contents=target.read_bytes()
        assert contents[:4]==b"RIFF" and contents[8:12]==b"WEBP"
        assert len(contents)<source.stat().st_size, f"WebP pas plus petit que le PNG {orig}"
        source.unlink()
        print(f"{orig} => {dest} ({len(contents)} octets)")
    elif not matches and target.exists():
        contents=target.read_bytes()
        assert contents[:4]==b"RIFF" and contents[8:12]==b"WEBP"
    else:
        raise RuntimeError("PNG manquant ou ambigu : "+orig)

path=ROOT/"data.js"
s=path.read_text(encoding="utf8")
tag="STAROVKA_MARCHE_MAIRIE_SIX_WEBP_20261116"
if tag not in s:
    s+="""

// STAROVKA_MARCHE_MAIRIE_SIX_WEBP_20261116
// Décors propres à Starovka, sans modifier les commandes, PNJ, prix, accès ni autres villes.
(function () {
  const ville = WORLD.soviet?.ville_a;
  if (!ville) return;
  const marche = ville.buildingContext?.marche;
  const mairie = ville.buildingContext?.mairie;
  if (!marche || !mairie || !mairie.roomsExtra?.salle_elections || !mairie.roomsExtra?.salle_partis) {
    throw new Error('Pièces du marché ou de la mairie de Starovka absentes');
  }
  marche.roomOverrides = marche.roomOverrides || {};
  Object.assign(marche.roomOverrides.marche_ext = marche.roomOverrides.marche_ext || {}, {
    imageUrl: 'images/Sovarka/Starovka/Starovka_marche_marche_ext.webp'
  });
  mairie.roomOverrides = mairie.roomOverrides || {};
  const dir = 'images/Sovarka/Starovka/Starovka_mairie_';
  for (const [pieceId, nomImage] of Object.entries({
    accueil_mairie: 'accueil_mairie.webp',
    bureau_maire_local: 'bureau_maire_local.webp',
    bureau_maire_adjoint: 'bureau_maire_adjoint.webp',
    salle_elections: 'salle_elections.webp'
  })) {
    Object.assign(mairie.roomOverrides[pieceId] = mairie.roomOverrides[pieceId] || {}, {
      imageUrl: dir + nomImage
    });
  }
  mairie.roomsExtra.salle_partis.imageUrl = dir + 'salle_partis.webp';
})();
"""
    path.write_text(s,encoding="utf8")
assert all((FOLDER/f).is_file() for f in SOURCE_TARGET.values())
print("Les six WebP sont raccordés et leurs PNG originaux ont été supprimés.")
