#!/usr/bin/env python3
"""Deux PNG validés par Fred => WebP VP8 avec perte (qualité 85), suppression des PNG."""
from pathlib import Path
from PIL import Image, ImageOps
import unicodedata

RACINE = Path(__file__).resolve().parents[2]
DOSSIER = RACINE / "images" / "Sovarka" / "Starovka"
IMAGES = {
    "Hôpital soviétique sous la neige hivernale.png": "Starovka_rue_hopital.webp",
    "Rue enneigée de Starovka Caldwell.png": "Starovka_rue_tribunal_centre_artisanal.webp",
}

def normaliser(nom):
    return unicodedata.normalize("NFC", nom)

def main():
    entrees = {normaliser(f.name): f for f in DOSSIER.glob("*.png")}
    for nom, sortie in IMAGES.items():
        original = entrees.get(nom)
        destination = DOSSIER / sortie
        if original is None:
            if destination.exists():
                with Image.open(destination) as im:
                    assert im.format == "WEBP", destination
                print("Déjà converti :", sortie)
                continue
            raise FileNotFoundError("PNG attendu introuvable : " + nom)
        with Image.open(original) as source:
            if source.format != "PNG":
                raise ValueError("Source non PNG : " + original.name)
            im = ImageOps.exif_transpose(source).convert("RGB")
            im.save(destination, "WEBP", quality=85, lossless=False, method=6)
            if im.size != Image.open(destination).size:
                raise AssertionError("Dimensions modifiées : " + sortie)
        b = destination.read_bytes()
        if b[0:4] != b"RIFF" or b[8:16] != b"WEBPVP8 ":
            raise AssertionError("WebP VP8 avec perte requis : " + sortie)
        if len(b) >= original.stat().st_size:
            raise AssertionError("L'image WebP n'est pas plus légère : " + sortie)
        original.unlink()
        print(f"OK {original.name} -> {sortie} ({len(b)} octets)")

if __name__ == "__main__":
    main()
