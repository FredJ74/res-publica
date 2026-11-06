#!/usr/bin/env python3
"""Convertit strictement les 7 nouveaux PNG de Krasnov, puis supprime les sources validées."""
from pathlib import Path
from PIL import Image, ImageOps
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'images' / 'Sovarka' / 'Krasnov'
EXPECTED = ["Krasnov centre artisanal.png","Krasnov rue distillerie centre radar.png","Krasnov rue école foret.png","Krasnov rue immeubles centre commercial.png","Krasnov rue marché ferme.png","Krasnov rue stade commissariat.png","Krasnov rue tabac bar.png"]

def main():
    found = sorted(p.name for p in FOLDER.glob('*.png'))
    if found != sorted(EXPECTED):
        raise RuntimeError(f'PNG inattendus ou manquants: {found!r} au lieu de {sorted(EXPECTED)!r}')
    refs = subprocess.run(
        ['git', 'grep', '-n', '-F', '-f', '/dev/stdin', '--', '*.js', '*.html', '*.css', '*.json'],
        input='\n'.join(EXPECTED) + '\n', text=True, capture_output=True, cwd=ROOT
    )
    if refs.returncode not in (0, 1):
        raise RuntimeError('Échec de recherche des références : ' + refs.stderr)
    if refs.stdout.strip():
        raise RuntimeError('PNG référencés dans le jeu (refus de suppression):\n' + refs.stdout)
    for name in EXPECTED:
        if (FOLDER/name).with_suffix('.webp').exists():
            raise RuntimeError('Variante WebP déjà présente: ' + name)
    results=[]
    for name in EXPECTED:
        source=FOLDER/name
        target=source.with_suffix('.webp')
        with Image.open(source) as im:
            converted=ImageOps.exif_transpose(im).convert('RGB')
            dimensions=converted.size
            converted.save(target, 'WEBP', quality=85, method=6)
        with Image.open(target) as check:
            if check.format != 'WEBP' or check.size != dimensions:
                raise RuntimeError('WebP non conforme: ' + target.name)
            check.verify()
        if target.stat().st_size < 100:
            raise RuntimeError('WebP anormalement petit: ' + target.name)
        results.append((source, target))
        print(f'{name} -> {target.name} : {source.stat().st_size} -> {target.stat().st_size} octets')
    assert len(results)==7
    for source, _ in results:
        source.unlink()
    assert not list(FOLDER.glob('*.png'))
    print('SUCCESS: 7 WebP vérifiés et 7 PNG supprimés, autres fichiers intacts')

if __name__=='__main__':
    main()
