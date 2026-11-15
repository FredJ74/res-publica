#!/usr/bin/env python3
"""Remplacer l'accueil de Krasnov par la nouvelle image unique, sans conserver la planche."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps
root=Path("images/Sovarka/Krasnov")
target_name=unicodedata.normalize("NFC", "Réception chaleureuse du centre d’affaires.png")
matches=[p for p in root.iterdir() if unicodedata.normalize("NFC",p.name)==target_name]
if len(matches)!=1: raise SystemExit(f"Source ambiguë ou absente: {matches}")
source=matches[0]
with Image.open(source) as incoming:
    if incoming.format!="PNG": raise SystemExit("Source non PNG")
    image=ImageOps.exif_transpose(incoming).convert("RGB")
    w,h=image.size
    if w < 1200 or h < 700: raise SystemExit(f"Dimensions inattendues {w}x{h}")
    print("Image unique:",w,h,"ratio",round(w/h,3))
    # Nouveau décor unique en ratio standard; pas de mise au format bande panoramique.
    out=root/"Krasnov_centre_affaires_accueil.webp"
    image.save(out,"WEBP",quality=88,method=6)
    # Portrait extrait du nouveau décor : l'hôtesse est à gauche, derrière le comptoir.
    # La fenêtre portrait évite le logo et les quatre bureaux.
    portrait=image.crop((int(w*.22),int(h*.29),int(w*.38),int(h*.63)))
    if portrait.width<150 or portrait.height<150: raise SystemExit("Recadrage du portrait insuffisant")
    portrait.save(root/"Krasnov_centre_affaires_hotesse.webp","WEBP",quality=90,method=6)
for file in [root/"Krasnov_centre_affaires_accueil.webp",root/"Krasnov_centre_affaires_hotesse.webp"]:
    with Image.open(file) as check:
        assert check.format=="WEBP"
        print(file.name, check.size, file.stat().st_size)
source.unlink()
print("Ancien décor remplacé, nouveau WebP vérifié, PNG source supprimé.")
