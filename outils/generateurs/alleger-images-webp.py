#!/usr/bin/env python3
"""Allège les images WebP enregistrées SANS PERTE (format VP8L) en les réencodant AVEC PERTE.

Pourquoi (15/11/2026) : le payload Vercel avait dépassé son plafond (332,7 Mo pour 330). Les 44 images de
plus de 1 Mo étaient presque toutes des WebP sans perte (1,5 à 2,5 Mo pour 1536 × 1024) ; réencodées en
qualité 85, mêmes dimensions, elles pèsent 6 fois moins sans différence visible (80,6 Mo -> 12,5 Mo).

Usage : python3 outils/generateurs/alleger-images-webp.py [--seuil-ko 300] [--appliquer] fichier.webp ...
Sans --appliquer, n'écrit rien et affiche le gain. Le nom et les dimensions ne changent pas : aucune
référence du code n'est à modifier. Un fichier n'est réécrit que s'il gagne au moins 20 %.
"""
import argparse, io, os, sys
from PIL import Image

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('fichiers', nargs='+')
    ap.add_argument('--seuil-ko', type=int, default=300)
    ap.add_argument('--qualite', type=int, default=85)
    ap.add_argument('--appliquer', action='store_true')
    a = ap.parse_args()
    avant = apres = 0
    for p in a.fichiers:
        if not p.lower().endswith('.webp') or os.path.getsize(p) < a.seuil_ko * 1024:
            continue
        with open(p, 'rb') as f:
            if f.read(16)[12:16] != b'VP8L':
                continue  # déjà avec perte
        im = Image.open(p)
        im2 = im.convert('RGBA') if 'A' in im.mode else im.convert('RGB')
        b = io.BytesIO()
        im2.save(b, 'WEBP', quality=a.qualite, method=6)
        sz, nv = os.path.getsize(p), len(b.getvalue())
        if nv > sz * 0.8:
            continue
        avant += sz; apres += nv
        print(f'{sz / 1e6:6.2f} Mo -> {nv / 1e6:5.2f} Mo  {p}')
        if a.appliquer:
            with open(p, 'wb') as f:
                f.write(b.getvalue())
    print(f'Total : {avant / 1048576:.1f} Mo -> {apres / 1048576:.1f} Mo' + ('' if a.appliquer else ' (simulation)'))

if __name__ == '__main__':
    sys.exit(main())
