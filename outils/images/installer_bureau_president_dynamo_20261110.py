#!/usr/bin/env python3
"""Installe le visuel du bureau du président du Dynamo depuis le PNG déposé par Fred.

Ne jamais supprimer le PNG avant vérification de l'identité de sa source,
de la conversion WebP et du raccordement effectif de la salle.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images/Sovarka/Novomirsk"
SOURCE = DIR / "Les cinq triomphes mondiaux du Dynamo Novomirsk.png"
TARGET = DIR / "Novomirsk.stade.bureau président.webP"
EXPECTED_SHA = "b35f33313e7022d3ba2a045ef40fd3ab57bdfdb6"
DATA = ROOT / "data.js"
RELATIVE_TARGET = "images/Sovarka/Novomirsk/Novomirsk.stade.bureau président.webP"

def git_blob_sha(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\\0" + raw).hexdigest()

def main():
    data = DATA.read_text(encoding="utf-8")
    if data.count("imageUrl: '" + RELATIVE_TARGET + "'") != 1:
        raise SystemExit("L'image n'est pas raccordée une seule fois au bureau président dans data.js")
    if TARGET.exists():
        if SOURCE.exists():
            raise SystemExit("WebP existe déjà alors que PNG reste présent : intervention manuelle nécessaire")
        with Image.open(TARGET) as image:
            if image.format != "WEBP" or min(image.size) < 600:
                raise SystemExit("Le WebP présent est invalide")
        print(f"Déjà installé : {TARGET.name}")
        return
    if not SOURCE.is_file():
        raise SystemExit(f"Source PNG absente : {SOURCE}")
    raw = SOURCE.read_bytes()
    if git_blob_sha(raw) != EXPECTED_SHA:
        raise SystemExit("Le PNG ne correspond pas à l'image déposée par Fred : aucun effacement")
    with Image.open(SOURCE) as image:
        if image.format != "PNG" or min(image.size) < 600:
            raise SystemExit(f"PNG invalide : {image.format}, {image.size}")
        dimensions = image.size
        image.convert("RGB").save(TARGET, "WEBP", quality=85, method=6)
    with Image.open(TARGET) as converted:
        if converted.format != "WEBP" or converted.size != dimensions:
            TARGET.unlink(missing_ok=True)
            raise SystemExit("Échec du contrôle de conversion WebP")
    if TARGET.stat().st_size < 20000:
        TARGET.unlink(missing_ok=True)
        raise SystemExit("WebP anormalement petit")
    SOURCE.unlink()
    print(f"Installé et vérifié : {TARGET.name} ({TARGET.stat().st_size} octets, {dimensions}); PNG supprimé")

if __name__ == "__main__":
    main()
