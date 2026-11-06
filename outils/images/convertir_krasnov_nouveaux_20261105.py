#!/usr/bin/env python3
"""Traite les trois PNG Krasnov, sans écraser de WebP existant ni perdre d'image."""
from pathlib import Path
from PIL import Image, ImageOps, ImageChops, ImageStat
from tempfile import TemporaryDirectory
import subprocess

ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/'images'/'Sovarka'/'Krasnov'
EXPECTED=["Krasnov rue mairie place.png","Krasnov rue station musée.png","Krasnov rue tabac bar.png"]

def rgb(path):
    with Image.open(path) as im:
        return ImageOps.exif_transpose(im).convert('RGB')

def main():
    found=sorted(p.name for p in DIR.glob('*.png'))
    if found!=sorted(EXPECTED):
        raise RuntimeError(f'PNG trouvés {found!r}; attendus {sorted(EXPECTED)!r}')
    refs=subprocess.run(['git','grep','-n','-F','-f','/dev/stdin','--','*.js','*.html','*.css','*.json'],
        input='\n'.join(EXPECTED)+'\n', text=True,capture_output=True,cwd=ROOT)
    if refs.returncode not in (0,1): raise RuntimeError(refs.stderr)
    if refs.stdout.strip(): raise RuntimeError('PNG référencés: '+refs.stdout)
    # Préparer et vérifier TOUTES les conversions avant de toucher à un original.
    with TemporaryDirectory() as tmp:
        ready=[]
        for name in EXPECTED:
            source=DIR/name
            target=source.with_suffix('.webp')
            converted=rgb(source)
            scratch=Path(tmp)/target.name
            converted.save(scratch,'WEBP',quality=85,method=6)
            with Image.open(scratch) as check:
                if check.format!='WEBP' or check.size!=converted.size:
                    raise RuntimeError('WebP temporaire invalide: '+name)
                check.verify()
            if scratch.stat().st_size<100: raise RuntimeError('WebP trop petit: '+name)
            if target.exists():
                current=rgb(target)
                if current.size!=converted.size:
                    raise RuntimeError('WebP déjà existant avec dimensions différentes: '+name)
                # Le WebP existant est avec perte. Comparaison visuelle moyenne sur 3 canaux.
                rms=ImageStat.Stat(ImageChops.difference(converted,current)).rms
                max_rms=max(rms)
                if max_rms>12:
                    raise RuntimeError(f'WebP déjà existant sensiblement différent: {name}; RMS={rms!r}')
                print(f'Doublon confirmé, WebP conservé: {target.name}; RMS={rms!r}')
                ready.append((source,None))
            else:
                ready.append((source,scratch))
                print(f'WebP nouveau vérifié: {target.name}; {scratch.stat().st_size} octets')
        for source,scratch in ready:
            if scratch is not None:
                source.with_suffix('.webp').write_bytes(scratch.read_bytes())
        for source,_ in ready:
            source.unlink()
    assert not list(DIR.glob('*.png'))
    print('OK: 3 PNG traités et supprimés; WebP préexistant conservé')

if __name__=='__main__':
    main()
