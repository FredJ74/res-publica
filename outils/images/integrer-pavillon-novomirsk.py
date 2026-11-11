#!/usr/bin/env python3
"""Conversion des cinq illustrations du Pavillon des Ambassadeurs (Novomirsk).

Conversion AVANT suppression des PNG. Ne modifie aucune règle métier.
"""
from pathlib import Path
from PIL import Image, ImageChops
import re
import os

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'images/Sovarka/Novomirsk'
DATA=ROOT/'data.js'
MAPPING={
  'hall_pavillon':('Novomirsk_pavillon ambassadeurs_hall.png','Novomirsk_pavillon_ambassadeurs_hall.webp'),
  'salle_reception':('Novomirsk_Pavillon Ambassadeurs_salle reception.png','Novomirsk_pavillon_ambassadeurs_salle_reception.webp'),
  'suite_presidentielle':('Novomirsk_ambassades_suite présidentielle.png','Novomirsk_pavillon_ambassadeurs_suite_presidentielle.webp'),
  'suite_privee':('Novomirsk_ambassades_suite privée.png','Novomirsk_pavillon_ambassadeurs_suite_privee.webp'),
  'suite_parti':('Novomirsk_ambassades_suite partis.png','Novomirsk_pavillon_ambassadeurs_suite_parti.webp'),
}
# Limiter explicitement toutes les substitutions au bâtiment concerné.
original=DATA.read_text(encoding='utf-8')
start=original.index("\n  'pavillon-ambassadeurs-novomirsk': {")
end=original.index("\n  'residence-imperiale-novomirsk': {",start)
before,segment,after=original[:start],original[start:end],original[end:]
assert len(MAPPING)==5
for room,(png,webp) in MAPPING.items():
    src=FOLDER/png
    if not src.exists():
        # Git peut stocker un nom en NFC/NFD ; repli uniquement sur même nom normalisé.
        import unicodedata
        variants=[p for p in FOLDER.iterdir() if unicodedata.normalize('NFC',p.name)==unicodedata.normalize('NFC',png)]
        assert len(variants)==1,(png,[v.name for v in variants])
        src=variants[0]
    dest=FOLDER/webp
    assert src.is_file() and src.suffix=='.png',src
    with Image.open(src) as im:
        im.load()
        assert im.format=='PNG' and im.width>=900 and im.height>=600,(src,im.size)
        assert im.width/im.height>1.35 and im.width/im.height<2.4,(src,im.size)
        color=im.convert('RGB')
        color.save(dest,'WEBP',quality=87,method=6)
        with Image.open(dest) as chk:
            chk.load()
            assert chk.format=='WEBP' and chk.size==im.size
            # Couleurs image intactes visuellement, tolérance compression.
            diff=ImageChops.difference(color,chk.convert('RGB'))
            import numpy as np
            arr=np.asarray(diff)
            mean=float(arr.mean())
            assert mean<20,(room,mean)
            print(f'CONVERTED {room}: {src.name} -> {dest.name}, {im.size}, {src.stat().st_size} -> {dest.stat().st_size} octets, mean_diff={mean:.2f}')
    # Insertion à l'intérieur de la seule pièce ; aucun prix, PA, PNJ ou ordre ne change.
    pattern=r"(\n      "+re.escape(room)+r": \{\n        name: [^\n]+\n        imageBg: [^\n]+\n)"
    assert len(re.findall(pattern,segment))==1,room
    image_url="images/Sovarka/Novomirsk/"+webp
    assert image_url not in segment
    segment=re.sub(pattern,lambda m:m.group(1)+"        imageUrl: '"+image_url+"',\n",segment,count=1)
    # Le PNG est supprimé uniquement après vérification du fichier WebP et insertion du chemin.
    src.unlink()
updated=before+segment+after
assert updated.count("imageUrl: 'images/Sovarka/Novomirsk/Novomirsk_pavillon_ambassadeurs_")==5
DATA.write_text(updated,encoding='utf-8')
print('DONE: 5 WebP vérifiés, 5 PNG supprimés, 5 pièces raccordées ; aucune mécanique modifiée')
