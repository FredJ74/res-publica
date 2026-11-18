#!/usr/bin/env python3
"""Convertit les 3 PNG historiques déposés par Fred en portraits produits WebP Sovarka.

Ce script agit exclusivement sur les 3 images déposées à Starovka, puis raccorde
les trois entrées du catalogue soviétique sans modifier les règles métier.
"""
from pathlib import Path
import re
import unicodedata
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "images/Sovarka/Starovka"
DEST = ROOT / "images"
CATALOG = ROOT / "plateau-actions-illegales-rumeurs.js"

TARGETS = {
    "baionnette": ("baionnette", "arme-baionnette-soviet.webp"),
    "makarov": ("makarov", "arme-makarov-soviet.webp"),
    "kalachnikov": ("kalachnikov", "arme-kalachnikov-soviet.webp"),
}

def simple(value):
    return unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().lower()

catalog = CATALOG.read_text(encoding="utf-8")
for keyword, (_, filename) in TARGETS.items():
    matches = [p for p in SOURCE.glob("*.png") if keyword in simple(p.name)]
    if len(matches) != 1:
        raise RuntimeError(f"{keyword}: attendu 1 PNG d'origine, trouvé {len(matches)} : {matches}")
    source = matches[0]
    destination = DEST / filename
    if destination.exists():
        raise RuntimeError(f"WebP déjà présent, pas d'écrasement : {destination}")
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original).convert("RGB")
        if image.width != image.height:
            raise RuntimeError(f"{source.name} : format non carré {image.size}")
        image.save(destination, "WEBP", quality=86, method=6)
    with Image.open(destination) as result:
        result.verify()
    old = "images/arme-" + keyword + "-soviet.png"
    if catalog.count(old) != 1:
        raise RuntimeError(f"Référence du catalogue non unique pour {keyword}: {catalog.count(old)}")
    catalog = catalog.replace(old, "images/" + filename)
    print(f"{source.relative_to(ROOT)} => {destination.relative_to(ROOT)} ({destination.stat().st_size} octets)")
    source.unlink()

CATALOG.write_text(catalog, encoding="utf-8")
for _, filename in TARGETS.values():
    if not (DEST / filename).is_file():
        raise RuntimeError(f"WebP absent : {filename}")
print("Trois WebP contrôlés ; originaux supprimés ; catalogue raccordé.")
