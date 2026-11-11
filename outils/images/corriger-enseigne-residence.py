#!/usr/bin/env python3
"""Correction de l'inscription de la Résidence impériale, sur le WebP utilisé en jeu.

Commande --inspect : émettre une miniature zoomée (base64 WebP) pour ajuster
avec précision les coordonnées avant toute retouche. Sans --inspect : aucune
modification automatique n'est faite tant que le patch n'est pas validé.
"""
import argparse, base64, io
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT / 'images/rue-residences-eglise-novomirsk.webp'

def inspect():
    image=Image.open(SOURCE).convert('RGB')
    print(f"ORIGINAL_SIZE={image.size[0]}x{image.size[1]}")
    crop=image.crop((1360,355,1520,550)).resize((640,780),Image.Resampling.LANCZOS)
    buff=io.BytesIO()
    crop.save(buff,format='WEBP',quality=80)
    print('INSPECTION_WEBP_BASE64_BEGIN')
    print(base64.b64encode(buff.getvalue()).decode('ascii'))
    print('INSPECTION_WEBP_BASE64_END')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--inspect',action='store_true')
    args=parser.parse_args()
    if args.inspect:inspect()
    else:raise SystemExit('Inspection requise avant correction de la source')

if __name__=='__main__':main()
