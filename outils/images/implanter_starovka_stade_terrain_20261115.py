#!/usr/bin/env python3
"""Convertit l'image terrain du stade de Starovka et relie la salle terrain uniquement à Starovka."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps
root = Path(__file__).resolve().parents[2]
folder = root / 'images/Sovarka/Starovka'
original = 'Interview au stade Starovka enneigé.png'
target = folder / 'Starovka_stade_terrain.webp'
matches = [p for p in folder.glob('*.png') if unicodedata.normalize('NFC', p.name) == original]
if len(matches) == 1:
    source = matches[0]
    with Image.open(source) as im:
        assert im.format == 'PNG', source
        image = ImageOps.exif_transpose(im).convert('RGB')
        dims = image.size
        image.save(target, 'WEBP', quality=85, method=6)
    with Image.open(target) as check:
        assert check.format == 'WEBP' and check.size == dims
    blob = target.read_bytes()
    assert blob[:4] == b'RIFF' and blob[8:12] == b'WEBP'
    assert target.stat().st_size < source.stat().st_size
    source.unlink()
elif not matches and target.is_file():
    blob = target.read_bytes()
    assert blob[:4] == b'RIFF' and blob[8:12] == b'WEBP'
else:
    raise RuntimeError('Source PNG non trouvée ou multiple: ' + original)
data = root / 'data.js'
s = data.read_text(encoding='utf8')
anchor = "    Object.assign(piece(stadeStarovka,'vestiaires'), {"
if "    Object.assign(piece(stadeStarovka,'terrain'), {" not in s:
    assert s.count(anchor)==1, 'Ancrage stade manquant ou ambigu'
    s = s.replace(anchor, """    // Terrain de Starovka : illustration propre à la ville, sans changer les ordres sportifs.
    Object.assign(piece(stadeStarovka,'terrain'), {
      imageUrl: fondStade('terrain')
    });
"""+anchor)
    data.write_text(s, encoding='utf8')
assert target.is_file() and "imageUrl: fondStade('terrain')" in data.read_text(encoding='utf8')
print('Terrain Starovka : WebP vérifié, ancien PNG supprimé, imageUrl raccordée.')
