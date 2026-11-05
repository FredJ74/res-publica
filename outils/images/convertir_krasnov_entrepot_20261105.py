#!/usr/bin/env python3
"""Convertit la vue entrepôt de Krasnov en WebP puis supprime le PNG vérifié."""
from pathlib import Path
from PIL import Image, ImageOps
import subprocess

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'images'/'Sovarka'/'Krasnov'/'Krasnov rue entrepôt.png'
TARGET=SOURCE.with_suffix('.webp')

if not SOURCE.is_file():
    if TARGET.is_file():
        with Image.open(TARGET) as im:
            assert im.format=='WEBP'
            im.verify()
        print('Conversion déjà effectuée')
        raise SystemExit(0)
    raise FileNotFoundError(SOURCE)
if TARGET.exists():
    raise RuntimeError('WebP préexistant : aucun écrasement ni suppression autorisés')

r=subprocess.run(['git','grep','-n','-F',SOURCE.name,'--','*.js','*.html','*.css','*.json'],
                 cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
if r.returncode not in (0,1):
    raise RuntimeError(r.stderr)
if r.stdout.strip():
    raise RuntimeError('PNG encore utilisé : '+r.stdout)

with Image.open(SOURCE) as original:
    rgb=ImageOps.exif_transpose(original).convert('RGB')
    dimensions=rgb.size
    rgb.save(TARGET,format='WEBP',quality=85,method=6)
with Image.open(TARGET) as check:
    assert check.format=='WEBP' and check.size==dimensions
    check.verify()
assert TARGET.stat().st_size>0
print(f'{SOURCE.name}: {SOURCE.stat().st_size} octets -> {TARGET.name}: {TARGET.stat().st_size} octets')
SOURCE.unlink()
print('PNG supprimé après validation du WebP')
