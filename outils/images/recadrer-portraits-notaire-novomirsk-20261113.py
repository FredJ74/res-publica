#!/usr/bin/env python3
"""Recadrages strictement issus des images des salles notariales (aucune génération de visage)."""
from pathlib import Path
import cv2
from PIL import Image
import json

root=Path("images/Sovarka/Novomirsk")
noms=["accueil","successions","cessions_entreprises","archives"]
detecteur=cv2.CascadeClassifier(cv2.data.haarcascades+"haarcascade_frontalface_default.xml")
assert not detecteur.empty()
rapport=[]
for suffixe in noms:
    src=root/("Novomirsk_notaire_"+suffixe+".webp")
    dest=root/("Novomirsk_notaire_"+suffixe+"_portrait.webp")
    assert src.is_file(),f"Source manquante : {src}"
    with Image.open(src) as im:
        im=im.convert("RGB")
        w,h=im.size
        img=cv2.imread(str(src))
        assert img is not None
        gris=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
        rectangles=detecteur.detectMultiScale(gris,scaleFactor=1.05,minNeighbors=3,minSize=(30,30))
        boxes=sorted([[int(x),int(y),int(a),int(b)] for x,y,a,b in rectangles],
                    key=lambda p:p[2]*p[3],reverse=True)
        rapport.append(dict(scene=str(src),dimensions=[w,h],visages=boxes))
        if not boxes:
            continue
        # Le portrait central le plus grand est la personne principale de la scène.
        # En cas de plusieurs personnages, ne pas identifier arbitrairement une personne.
        if len(boxes)>1 and boxes[1][2]*boxes[1][3] > .75*boxes[0][2]*boxes[0][3]:
            continue
        x,y,fw,fh=boxes[0]
        cx=x+fw/2
        cy=y+fh/2+fh*.52   # de la tête vers les épaules pour la photo de fiche
        side=max(fw*3.1,fh*3.1, min(w,h)*.20)
        side=min(side,w,h)
        left=max(0,min(w-side,cx-side/2))
        top=max(0,min(h-side,cy-side/2))
        crop=im.crop((int(left),int(top),int(left+side),int(top+side)))
        crop=crop.resize((512,512),Image.Resampling.LANCZOS)
        crop.save(dest,"WEBP",quality=86,method=6)
        with Image.open(dest) as out:
            assert out.format=="WEBP" and out.size==(512,512)
        rapport[-1].update(portrait=str(dest),recadrage=[int(left),int(top),int(side)])
Path('outils/audits').mkdir(parents=True,exist_ok=True)
Path('outils/audits/diagnostic-visages-notaire-novomirsk.json').write_text(json.dumps(rapport,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(rapport,ensure_ascii=False,indent=2))
if len([r for r in rapport if 'portrait' in r])!=4:
    raise RuntimeError('Certains portraits nécessitent un recadrage spécifique ; diagnostic enregistré.')
