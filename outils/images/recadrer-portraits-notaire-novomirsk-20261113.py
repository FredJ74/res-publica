#!/usr/bin/env python3
"""Extraire les portraits directement des décors existants, sans génération IA.
Les coordonnées sont déduites du diagnostic OpenCV (scènes 1536x1024).
Klara conserve son portrait existant issu du décor d'accueil.
"""
from pathlib import Path
from PIL import Image
import json

root=Path('images/Sovarka/Novomirsk')
# Rectangle du visage (x,y,largeur,hauteur) détecté dans la scène originale.
# La sélection centrale correspond au personnage mis en avant dans sa salle.
visages={
  'successions': (658,322,127,127),
  'cessions_entreprises': (775,403,77,77),
  'archives': (814,316,221,221),
}
resultats=[]
for suffixe,(x,y,wf,hf) in visages.items():
    source=root/('Novomirsk_notaire_'+suffixe+'.webp')
    dest=root/('Novomirsk_notaire_'+suffixe+'_portrait.webp')
    assert source.is_file(),source
    assert not dest.exists(),dest
    with Image.open(source) as raw:
        img=raw.convert('RGB')
        w,h=img.size
        assert (w,h)==(1536,1024),(source,w,h)
        # Cadrage visage + buste, avec garde-fous sur les bords.
        cx=x+wf/2
        cy=y+hf/2+hf*.60
        cote=min(max(wf*2.8,hf*2.8,260),min(w,h))
        gauche=max(0,min(w-cote,cx-cote/2))
        haut=max(0,min(h-cote,cy-cote/2))
        portrait=img.crop((int(gauche),int(haut),int(gauche+cote),int(haut+cote)))
        portrait=portrait.resize((512,512),Image.Resampling.LANCZOS)
        portrait.save(dest,'WEBP',quality=86,method=6)
    with Image.open(dest) as verification:
        assert verification.format=='WEBP' and verification.size==(512,512)
    resultats.append({'source':str(source),'portrait':str(dest),'visage':[x,y,wf,hf],
                      'recadrage':[int(gauche),int(haut),int(cote)]})
assert (root/'Novo_klara_delounova_portrait.webp').is_file()
print(json.dumps(resultats,ensure_ascii=False,indent=2))
