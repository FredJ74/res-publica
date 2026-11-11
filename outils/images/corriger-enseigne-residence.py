#!/usr/bin/env python3
"""Retouche précise de la source WebP de la rue V7 de Novomirsk.

Ne modifie pas les bâtiments ni les autres textes. Supprime seulement le S
final du titre « RÉSIDENCES » pour afficher « RÉSIDENCE IMPÉRIALE ».
"""
import argparse
import base64
import hashlib
import io
from pathlib import Path

from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT / 'images/rue-residences-eglise-novomirsk.webp'
EXPECTED_SHA256=''  # La sécurité de l'exécution utilise le SHA Git du blob.

def inspect():
    image=Image.open(SOURCE).convert('RGB')
    print(f"ORIGINAL_SIZE={image.size[0]}x{image.size[1]}")
    crop=image.crop((1360,355,1520,550)).resize((640,780),Image.Resampling.LANCZOS)
    buffer=io.BytesIO()
    crop.save(buffer,format='WEBP',quality=82)
    print('INSPECTION_WEBP_BASE64_BEGIN')
    print(base64.b64encode(buffer.getvalue()).decode('ascii'))
    print('INSPECTION_WEBP_BASE64_END')

def apply():
    import cv2
    import numpy as np
    rgb=np.array(Image.open(SOURCE).convert('RGB'))
    assert rgb.shape==(1024,1536,3),f'Taille modifiée : {rgb.shape}'
    mask=np.zeros(rgb.shape[:2],dtype=np.uint8)
    # S final uniquement, plaque noire en perspective à droite.
    polygon=np.array([(1477,370),(1491,369),(1491,412),(1476,414)],dtype=np.int32)
    cv2.fillPoly(mask,[polygon],255)
    bgr=cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR)
    corrected=cv2.inpaint(bgr,mask,3,cv2.INPAINT_TELEA)
    output=Image.fromarray(cv2.cvtColor(corrected,cv2.COLOR_BGR2RGB))
    output.save(SOURCE,format='WEBP',quality=96,method=6)
    check=Image.open(SOURCE)
    assert check.size==(1536,1024) and check.format=='WEBP'
    print('CORRECTED_FILE=',SOURCE)
    print('WEBP_BYTES=',SOURCE.stat().st_size)
    print('FILE_SHA256=',hashlib.sha256(SOURCE.read_bytes()).hexdigest())
    # Aucun pixel hors de la zone sélectionnée n'a été modifié avant réencodage.
    exact=np.all(corrected[mask==0]==bgr[mask==0])
    assert exact,'La correction change des pixels hors masque'

def main():
    parser=argparse.ArgumentParser()
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--inspect',action='store_true')
    mode.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    if args.inspect:inspect()
    else:apply()

if __name__=='__main__':main()
