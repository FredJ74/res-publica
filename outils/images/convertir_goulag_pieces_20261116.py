#!/usr/bin/env python3
"""Conversion contrôlée des cinq vues du bâtiment Goulag de Sovarka.
Les PNG sont supprimés seulement après la création et validation des WebP.
Ne modifie pas les dix vues de la toundra ni leurs manifestes.
"""
from pathlib import Path
from PIL import Image
import hashlib
import json
import unicodedata

DOSSIER = Path("images/Sovarka/Goulag")
SOURCES = {
    "Entrée enneigée du camp de Sovarka.png": "Sovarka_goulag_entree.webp",
    "Dortoir glacial des baraquements du Goulag.png": "Sovarka_goulag_dortoir.webp",
    "Cellule disciplinaire en bois enneigée.png": "Sovarka_goulag_cachot_disciplinaire.webp",
    "Bureaucratie soviétique sous fumée.png": "Sovarka_goulag_bureau_chef.webp",
    "Tour de guet dans un camp enneigé.png": "Sovarka_goulag_mirador.webp",
}
TAILLE = (1448,1086)
details=[]
sources_reelles={unicodedata.normalize('NFC', p.name): p for p in DOSSIER.iterdir() if p.is_file()}
for source, destination in SOURCES.items():
    src=sources_reelles.get(unicodedata.normalize('NFC', source), DOSSIER/source)
    dst=DOSSIER/destination
    if not src.is_file():
        if not dst.is_file():
            raise SystemExit(f"Image manquante : {src} / {dst}")
        with Image.open(dst) as im:
            if im.format!="WEBP" or im.size!=TAILLE:
                raise SystemExit(f"WebP existant invalide : {dst}")
        details.append({"fichier":destination,"conserve":True})
        continue
    if dst.exists():
        raise SystemExit(f"Refus d'écraser un WebP : {dst}")
    with Image.open(src) as im:
        im.load()
        if im.width < 1000 or im.height < 700:
            raise SystemExit(f"Image source de résolution insuffisante : {src}")
        im=im.convert("RGB")
        if im.size != TAILLE:
            im=im.resize(TAILLE, Image.Resampling.LANCZOS)
        im.save(dst,format="WEBP",quality=85,method=6)
    with Image.open(dst) as nouveau:
        nouveau.load()
        if nouveau.format!="WEBP" or nouveau.size!=TAILLE:
            dst.unlink(missing_ok=True)
            raise SystemExit(f"Conversion non valide : {dst}")
    details.append({"fichier":destination,"octets":dst.stat().st_size,"sha256":hashlib.sha256(dst.read_bytes()).hexdigest()})
    src.unlink()
# Garde : ne pas effacer les vues 01-10 de la toundra.
assert all((DOSSIER/f"Sovarka_goulag_toundra_{i:02d}.webp").exists() for i in range(1,11))
print(json.dumps({"dimensions":TAILLE,"vues":details},ensure_ascii=False,indent=2))
