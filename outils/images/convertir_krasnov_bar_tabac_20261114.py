#!/usr/bin/env python3
"""Convertit seulement les deux nouveaux PNG du Bar Sever et du Tabac/Presse de Krasnov."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps

folder = Path('images/Sovarka/Krasnov')
mapping = {
  'Bar soviétique rétro avec affiche vintage.png': 'Krasnov_bar_sever_salle.webp',
  'Kiosque soviétique rétro sous la pluie.png': 'Krasnov_tabac_presse_boutique.webp'
}
files = {unicodedata.normalize('NFC',p.name):p for p in folder.iterdir() if p.is_file()}
for origin,target in mapping.items():
  if origin not in files: raise SystemExit('Source manquante : '+origin)
  dst=folder/target
  if dst.exists(): raise SystemExit('Destination existante : '+target)
  src=files[origin]
  with Image.open(src) as im:
    if im.format!='PNG': raise SystemExit('Fichier non PNG : '+origin)
    im=ImageOps.exif_transpose(im).convert('RGB')
    if im.width < 500 or im.height < 300: raise SystemExit('Dimensions insuffisantes')
    im.save(dst,'WEBP',quality=85,method=6)
  with Image.open(dst) as check: check.verify()
  print(origin,'->',target,dst.stat().st_size,'octets')
for origin in mapping: files[origin].unlink()
print('2 PNG supprimés ; 2 WebP valides ; autres images conservées')
