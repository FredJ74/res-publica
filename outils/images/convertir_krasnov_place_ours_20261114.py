#!/usr/bin/env python3
"""Convertir uniquement les cinq PNG confiés par Fred pour l'immeuble de la place de l'Ours."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps

DIRECTORY = Path('images/Sovarka/Krasnov')
MAPPING = {
    "Hall d’entrée soviétique au coucher du soleil.png": "Krasnov_immeuble_place_ours_hall.webp",
    "Image ChatGPT 14 nov. 2026, 19_26_27-1.png": "Krasnov_immeuble_place_ours_petit_1.webp",
    "Salon rétro chaleureux sous la pluie-1.png": "Krasnov_immeuble_place_ours_petit_2.webp",
    "Image ChatGPT 14 nov. 2026, 19_26_28-2.png": "Krasnov_immeuble_place_ours_grand_1.webp",
    "Salon soviétique vintage un soir d’automne-2.png": "Krasnov_immeuble_place_ours_grand_2.webp",
}

def normalize(value):
    return unicodedata.normalize("NFC", value)

files = {normalize(f.name): f for f in DIRECTORY.glob('*.png')}
missing = set(MAPPING) - set(files)
if missing:
    raise SystemExit("Sources manquantes : " + repr(sorted(missing)))
for original, target in MAPPING.items():
    source = files[original]
    destination = DIRECTORY / target
    if destination.exists():
        raise SystemExit("Destination déjà existante : " + str(destination))
    with Image.open(source) as img:
        if img.format != 'PNG':
            raise SystemExit("Source non PNG : " + str(source))
        converted = ImageOps.exif_transpose(img).convert("RGB")
        if converted.width < 500 or converted.height < 300:
            raise SystemExit("Dimensions insuffisantes : " + str(source))
        converted.save(destination, format="WEBP", quality=85, method=6)
    with Image.open(destination) as control:
        control.verify()
    print(source.name, '=>', target, destination.stat().st_size, 'octets')
for name in MAPPING:
    files[name].unlink()
print("5/5 WebP vérifiés et 5 PNG sources retirés (autres images inchangées).")
