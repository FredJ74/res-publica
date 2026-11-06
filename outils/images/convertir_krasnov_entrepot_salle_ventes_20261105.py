#!/usr/bin/env python3
"""Convertit la salle des ventes de Krasnov en WebP, après vérification."""
from pathlib import Path
from tempfile import TemporaryDirectory
from PIL import Image, ImageOps
import subprocess

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / 'images' / 'Sovarka' / 'Krasnov'
NAMES = ('Krasnov_entrepot_salle ventes.png',)

def main():
    png_files = {p.name for p in DIRECTORY.glob('*.png')}
    if png_files != set(NAMES):
        raise RuntimeError(f'PNG présents: {sorted(png_files)}, attendus: {sorted(NAMES)}')

    # Ne jamais supprimer un PNG si le client le référence encore directement.
    result = subprocess.run(
        ['git', 'grep', '-n', '-F', '-f', '/dev/stdin', '--', '*.js', '*.html', '*.css', '*.json'],
        cwd=ROOT, input='\n'.join(NAMES)+'\n', capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr)
    if result.stdout.strip():
        raise RuntimeError('Références PNG encore actives :\n' + result.stdout)

    with TemporaryDirectory() as td:
        prepared = []
        for name in NAMES:
            source = DIRECTORY / name
            target = source.with_suffix('.webp')
            if target.exists():
                raise RuntimeError(f'WebP existant, refus d\'écrasement : {target}')
            with Image.open(source) as im:
                rgb = ImageOps.exif_transpose(im).convert('RGB')
                dimensions = rgb.size
                output = Path(td) / target.name
                rgb.save(output, format='WEBP', quality=85, method=6)
            with Image.open(output) as verification:
                if verification.format != 'WEBP' or verification.size != dimensions:
                    raise RuntimeError(f'Échec vérification WebP : {name}')
                verification.verify()
            if output.stat().st_size < 100:
                raise RuntimeError(f'WebP anormalement petit : {name}')
            prepared.append((source, target, output))
            print(f'Validé : {name} -> {target.name} ({output.stat().st_size} octets)')

        # La conversion étant vérifiée, publication puis nettoyage.
        for _, target, output in prepared:
            target.write_bytes(output.read_bytes())
        for source, _, _ in prepared:
            source.unlink()

    if list(DIRECTORY.glob('*.png')):
        raise RuntimeError('Des PNG subsistent dans le dossier')
    for _, target, _ in prepared:
        with Image.open(target) as im:
            if im.format != 'WEBP':
                raise RuntimeError(f'WebP final invalide : {target}')
            im.verify()
    print('SUCCÈS : un WebP valide, aucun PNG dans le dossier Krasnov')

if __name__ == '__main__':
    main()
