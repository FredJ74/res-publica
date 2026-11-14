#!/usr/bin/env python3
"""Six PNG du musée de Krasnov => WebP, portraits recadrés de l'accueil, sources retirées."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps

ROOT=Path('images/Sovarka/Krasnov')
MAPPING={
  'Hall d’accueil du musée Krasnov.png':'Krasnov_musee_accueil.webp',
  'Musée de la faune de Krasnov.png':'Krasnov_musee_faune_sauvage.webp',
  'Diorama botanique au musée soviétique.png':'Krasnov_musee_flore_sauvage.webp',
  'Exposition forestière de Krasnov.png':'Krasnov_musee_exploitation_bois.webp',
  'Exposition muséale sur le kolkhoze.png':'Krasnov_musee_kolkhozes.webp',
  'Centre d’écoute spatiale de Krasnov.png':'Krasnov_musee_ecoute_spatiale.webp',
}
FILES={unicodedata.normalize('NFC',f.name):f for f in ROOT.glob('*.png')}
missing=set(MAPPING)-set(FILES)
if missing: raise SystemExit('PNG introuvables : '+repr(sorted(missing)))
for srcname,dstname in MAPPING.items():
  src=FILES[srcname];dst=ROOT/dstname
  if dst.exists(): raise SystemExit('Destination existante : '+dstname)
  with Image.open(src) as im:
    if im.format!='PNG':raise SystemExit('Pas un PNG : '+srcname)
    im=ImageOps.exif_transpose(im).convert('RGB')
    if im.width<800 or im.height<500:raise SystemExit('Dimensions incorrectes : '+srcname)
    im.save(dst,'WEBP',quality=85,method=6)
  with Image.open(dst) as chk:chk.verify()
  print(srcname, '->',dstname, dst.stat().st_size, 'octets')
# Portraits des deux PNJ extraits de la même scène, sans générer d'autres visages.
with Image.open(ROOT/'Krasnov_musee_accueil.webp') as original:
  original=original.convert('RGB')
  w,h=original.size
  # Référence composition accueil : hôtesse au guichet à x=~21%, y=~47%;
  # guide debout à x=~52%, y=~46%.
  for target,cx,cy,span in [
    ('Krasnov_musee_accueil_hotesse.webp',.21,.48,.15),
    ('Krasnov_musee_accueil_guide.webp',.52,.44,.15)
  ]:
    side=int(min(w,h)*span*2)
    x=int(w*cx);y=int(h*cy)
    box=(max(0,x-side//2),max(0,y-side//2),min(w,x+side//2),min(h,y+side//2))
    crop=original.crop(box)
    if crop.width<100 or crop.height<100:raise SystemExit('Recadrage insuffisant : '+target)
    crop.save(ROOT/target, 'WEBP',quality=88,method=6)
    with Image.open(ROOT/target) as ck:ck.verify()
    print('Portrait issu du hall :',target)
for srcname in MAPPING: FILES[srcname].unlink()
print('6 WebP, 2 portraits dérivés, 6 PNG originaux supprimés')
