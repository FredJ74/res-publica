#!/usr/bin/env python3
"""Convertir les deux PNG de la rue blizzard, raccorder les salles et leurs zones visibles."""
from pathlib import Path
from PIL import Image, ImageOps
ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/"images/Sovarka/Starovka"
SOURCES={
    "Image ChatGPT 16 nov. 2026, 00_18_03-1.png":"Starovka_centre-affaires_tribune_republia.webp",
    "Image ChatGPT 16 nov. 2026, 00_18_04-2.png":"Starovka_locaux-starovka_local_1.webp",
}
for original,target_name in SOURCES.items():
    src=FOLDER/original
    dst=FOLDER/target_name
    if src.exists():
        with Image.open(src) as im:
            assert im.format=="PNG",src
            img=ImageOps.exif_transpose(im).convert("RGB")
            size=img.size
            img.save(dst,"WEBP",quality=85,method=6)
        with Image.open(dst) as check:
            assert check.format=="WEBP" and check.size==size
        data=dst.read_bytes()
        assert data[:4]==b"RIFF" and data[8:12]==b"WEBP"
        assert dst.stat().st_size<src.stat().st_size
        src.unlink()
        print(f"{src.name} => {dst.name} ({dst.stat().st_size} octets)")
    elif dst.exists():
        data=dst.read_bytes()
        assert data[:4]==b"RIFF" and data[8:12]==b"WEBP"
    else:
        raise RuntimeError(f"PNG absent : {original}")
data_path=ROOT/"data.js"
s=data_path.read_text(encoding="utf8")
anchor="  voix('ville_a', 'Starovka', 'Saran Batbayar');"
tag="STAROVKA_IMAGES_IMPRIMERIE_LOCAL_20261116"
if tag not in s:
    assert s.count(anchor)==1,"Ancrage antenne presse de Starovka absent"
    s=s.replace(anchor,anchor+"""
  // STAROVKA_IMAGES_IMPRIMERIE_LOCAL_20261116 — visuel local du journal Metel.
  // Ne modifie ni les journalistes ni les ordres de l'antenne.
  Object.assign(piece(contexte('ville_a', 'centre-affaires'), 'tribune_republia'), {
    imageUrl: 'images/Sovarka/Starovka/Starovka_centre-affaires_tribune_republia.webp'
  });
""")
    local_anchor="BUILDINGS['locaux-starovka'] = {"
    assert s.count(local_anchor)==1,"Définition du local commercial absente"
    start=s.index(local_anchor)
    end=s.index("\n};",start)+3
    extra="""
// Local commercial n°1, boutique vide face à l'imprimerie du journal Metel.
// Le local n°2 reste sans nouveau décor ; commandes et baux inchangés.
BUILDINGS['locaux-starovka'].rooms.local_1.imageUrl =
  'images/Sovarka/Starovka/Starovka_locaux-starovka_local_1.webp';
BUILDINGS['locaux-starovka'].imagesAVenir = false;
"""
    s=s[:end]+extra+s[end:]
    data_path.write_text(s,encoding="utf8")

street=ROOT/"plateau-rue-centrale.js"
s=street.read_text(encoding="utf8")
target="""    'starovka-rue-blizzard': {
      image: 'images/Sovarka/Starovka/Starovka_rue_blizzard.webp',
      zones: [],"""
replacement="""    'starovka-rue-blizzard': {
      image: 'images/Sovarka/Starovka/Starovka_rue_blizzard.webp',
      // Deux vitrines de cette rue : à gauche le local louable, à droite l'imprimerie.
      // Les deux sorties réutilisent des bâtiments existants sans recréer de commerce.
      zones: [
        { xPct: [0, 35], yPct: [29, 77], nom: 'Local commercial à louer', type: 'batiment', buildingId: 'locaux-starovka' },
        { xPct: [65, 100], yPct: [29, 76], nom: 'Imprimerie du journal Metel', type: 'batiment', buildingId: 'centre-affaires' }
      ],"""
if "Imprimerie du journal Metel', type: 'batiment'" not in s:
    assert s.count(target)==1,"Nœud de la rue du journal introuvable"
    s=s.replace(target,replacement)
    street.write_text(s,encoding="utf8")
for target in SOURCES.values():
    assert (FOLDER/target).is_file()
print("Les deux WebP, le raccordement et les zones de rue sont prêts.")
