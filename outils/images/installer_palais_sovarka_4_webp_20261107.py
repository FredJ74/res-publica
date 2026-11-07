#!/usr/bin/env python3
"""Installe les quatre visuels du Conseil du peuple à Novomirsk.

Chantier isolé: ne modifie aucune mécanique, aucun ordre, aucun PNJ, aucun coût.
Échoue sans supprimer les PNG si l'un des quatre visuels n'est pas le bon.
"""
from __future__ import annotations
import hashlib
import os
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images/Sovarka/Novomirsk"
FILES = {
    "Novomirsk_palais gouvernement_bureau pre\u0301sident.png": (
        "Novomirsk_palais_gouvernement_bureau_president.webp",
        "de0a61354f88a4e56e58e36d4d55057e1f6d8db4",
    ),
    "Novomirsk_Palais gouvernement_salle conseil.png": (
        "Novomirsk_palais_gouvernement_salle_conseil.webp",
        "adc1d96789ca5c32a6493a971a1484a1c4fee21a",
    ),
    "Novomirsk_palais gouvernemental_salle presse.png": (
        "Novomirsk_palais_gouvernement_salle_presse.webp",
        "f7773bae94ad3dc90f54dc1119608aee6b26b5c3",
    ),
    "Novomirsk_palais gouvernemental_archives.png": (
        "Novomirsk_palais_gouvernement_archives.webp",
        "9b53d63c0f117c34c425b1a06c76bc8a83c58aa8",
    ),
}
def git_sha(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()

# Vérification des quatre fichiers avant toute modification.
for name, (target, sha) in FILES.items():
    source = DIR / name
    if not source.is_file():
        raise SystemExit(f"Fichier absent : {source}")
    if git_sha(source.read_bytes()) != sha:
        raise SystemExit(f"PNG inattendu (SHA modifié) : {source}")
    if (DIR / target).exists():
        raise SystemExit(f"Ne pas écraser une illustration existante : {target}")

# Valider les substitutions AVANT de créer ou de supprimer des visuels.
data_path = ROOT / "data.js"
source = data_path.read_text(encoding="utf-8")
start = source.index("        'palais-gouvernement': {", source.index("empireName: 'Sovarka'"))
end = source.index("        'assemblee': {", start)
segment = source[start:end]
if segment.count("roomOverrides: {") != 1:
    raise SystemExit("Structure du palais de Sovarka inattendue")
replacement = {
    "            bureaux:        { name: 'Bureau du Président du Conseil du Peuple' },":
    "            bureaux:        { name: 'Bureau du Président du Conseil du Peuple', imageUrl: 'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_bureau_president.webp' },",
    "            salle_conseil:  { name: 'Salle du Conseil du Peuple' },":
    "            salle_conseil:  { name: 'Salle du Conseil du Peuple', imageUrl: 'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_salle_conseil.webp' },",
    "            bureau_min_int: { name: 'Bureau - Ministre de la Sécurité du Peuple' },":
    "            salle_presse:   { imageUrl: 'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_salle_presse.webp' },\n"
    "            archives_gouv:  { imageUrl: 'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_archives.webp' },\n"
    "            bureau_min_int: { name: 'Bureau - Ministre de la Sécurité du Peuple' },",
}
for old, new in replacement.items():
    if segment.count(old) != 1:
        raise SystemExit(f"Fragment de salle absent ou dupliqué : {old}")
    segment = segment.replace(old, new, 1)

# Remplacer aussi les images impériales de repli, sans affecter Republia.
mapping_start = source.index("  soviet: {", source.index("ROOM_IMAGES_EMPIRE"))
mapping_end = source.index("    'tribunal': {", mapping_start)
mapping = source[mapping_start:mapping_end]
old_mapping = """      'bureaux':           'images/bureau-gouv-sovarka.png',
      'salle_conseil':     'images/conseil-ministres-sovarka.webp',
      'bureau_min_fin':"""
new_mapping = """      'bureaux':           'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_bureau_president.webp',
      'salle_conseil':     'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_salle_conseil.webp',
      'salle_presse':      'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_salle_presse.webp',
      'archives_gouv':     'images/Sovarka/Novomirsk/Novomirsk_palais_gouvernement_archives.webp',
      'bureau_min_fin':"""
if mapping.count(old_mapping) != 1:
    raise SystemExit("Mapping de repli Sovarka inattendu")
mapping = mapping.replace(old_mapping, new_mapping, 1)
out = source[:start] + segment + source[end:]
out = out[:out.index("  soviet: {", out.index("ROOM_IMAGES_EMPIRE"))] + mapping + out[out.index("    'tribunal': {", out.index("  soviet: {", out.index("ROOM_IMAGES_EMPIRE"))):]
assert out.count("Novomirsk_palais_gouvernement_archives.webp") == 2
assert out.count("Novomirsk_palais_gouvernement_salle_presse.webp") == 2

# Quatre conversions, ouverture des fichiers encodés et contrôle des dimensions.
for name, (target, _) in FILES.items():
    with Image.open(DIR / name) as image:
        dimensions = image.size
        if image.format != "PNG" or min(dimensions) < 600:
            raise SystemExit(f"Image invalide : {name} {image.format} {dimensions}")
        image.convert("RGB").save(DIR / target, format="WEBP", quality=85, method=6)
    with Image.open(DIR / target) as check:
        if check.format != "WEBP" or check.size != dimensions:
            raise SystemExit(f"Échec contrôle WebP : {target}")
        print(f"OK {name} -> {target}, {dimensions}, {os.stat(DIR / target).st_size} octets")

# L'opération est maintenant suffisamment vérifiée pour substituer puis supprimer.
data_path.write_text(out, encoding="utf-8")
for name in FILES:
    (DIR / name).unlink()
print("OK : 4 illustrations intégrées, 4 PNG originaux supprimés, source de jeu conservée.")
