#!/usr/bin/env python3
"""Trois PNG fournis par Fred -> WebP VP8 qualité 85 ; supprimer les PNG seulement après vérification."""
from pathlib import Path
from PIL import Image, ImageOps
import unicodedata

root=Path(__file__).resolve().parents[2]
folder=root/"images"/"Sovarka"/"Starovka"
mapping={
    "Salle de vente industrielle soviétique.png": "Starovka_raffinerie_salle_ventes.webp",
    "Vue aérienne hivernale sur la raffinerie.png": "Starovka_raffinerie_bureau_directeur.webp",
    "Intérieur futuriste de raffinerie industrielle.png": "Starovka_raffinerie_interieur_usine.webp",
}
files={unicodedata.normalize("NFC",f.name):f for f in folder.glob("*.png")}
for initial,final in mapping.items():
    src=files.get(initial)
    dst=folder/final
    if src is None:
        if dst.exists():
            content=dst.read_bytes()
            assert content[:4]==b"RIFF" and content[8:16]==b"WEBPVP8 ", final
            print("Déjà converti:",final)
            continue
        raise FileNotFoundError(initial)
    with Image.open(src) as im:
        assert im.format=="PNG"
        picture=ImageOps.exif_transpose(im).convert("RGB")
        dimensions=picture.size
        picture.save(dst,format="WEBP",quality=85,lossless=False,method=6)
    with Image.open(dst) as im:
        assert im.format=="WEBP" and im.size==dimensions
    encoded=dst.read_bytes()
    assert encoded[:4]==b"RIFF" and encoded[8:16]==b"WEBPVP8 "
    assert len(encoded)<src.stat().st_size, "WebP non optimisé: "+final
    src.unlink()
    print("Converti et source supprimée:", src.name, "=>",dst.name,len(encoded))
