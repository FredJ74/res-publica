#!/usr/bin/env python3
"""Conversion atomique des deux vues Starovka, suppression après validation."""
from pathlib import Path
from tempfile import TemporaryDirectory
from PIL import Image, ImageOps
import subprocess

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / 'images' / 'Sovarka' / 'Starovka'
NAMES = ('Starovka_rue_gare.png', 'Starovka_rue_port industriel.png')

def main():
    found = {p.name for p in DIRECTORY.glob('*.png')}
    if found != set(NAMES):
        raise RuntimeError(f'PNG réels {sorted(found)!r} ; attendus {sorted(NAMES)!r}')
    check = subprocess.run(
        ['git','grep','-n','-F','-f','/dev/stdin','--','*.js','*.html','*.css','*.json'],
        input='\n'.join(NAMES)+'\n', cwd=ROOT, capture_output=True, text=True)
    if check.returncode not in (0,1):
        raise RuntimeError(check.stderr)
    if check.stdout.strip():
        raise RuntimeError('Références PNG actives: '+check.stdout)
    with TemporaryDirectory() as td:
        prepared = []
        for name in NAMES:
            source = DIRECTORY / name
            target = source.with_suffix('.webp')
            if target.exists():
                raise RuntimeError(f'WebP déjà existant, refus écrasement: {target}')
            with Image.open(source) as im:
                rgb=ImageOps.exif_transpose(im).convert('RGB')
                dimensions=rgb.size
                temporary=Path(td)/target.name
                rgb.save(temporary,'WEBP',quality=85,method=6)
            with Image.open(temporary) as im:
                assert im.format == 'WEBP' and im.size == dimensions, name
                im.verify()
            if temporary.stat().st_size < 100:
                raise RuntimeError('WebP invalide: '+name)
            prepared.append((source,target,temporary))
            print(f'CONVERSION VALIDE: {name} -> {target.name} {dimensions}, {temporary.stat().st_size} octets')
        for source,target,temporary in prepared:
            target.write_bytes(temporary.read_bytes())
        for source,target,_ in prepared:
            source.unlink()
    assert not list(DIRECTORY.glob('*.png')), 'PNG restants'
    for _,target,_ in prepared:
        with Image.open(target) as im:
            assert im.format=='WEBP'
            im.verify()
    print('STAROVKA: 2 WebP valides, 0 PNG restants')

if __name__ == '__main__':
    main()
