#!/usr/bin/env python3
"""Starovka : PNG de Fred → WebP VP8 qualité 85, original supprimé."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps
root = Path(__file__).resolve().parents[2]
folder = root / "images" / "Sovarka" / "Starovka"
name = "Raffinerie enneigée et route industrielle.png"
candidates = [f for f in folder.glob("*.png") if unicodedata.normalize("NFC", f.name) == name]
dest = folder / "Starovka_rue_raffinerie.webp"
if not candidates:
    if dest.exists():
        assert dest.read_bytes()[:4] == b"RIFF" and dest.read_bytes()[8:16] == b"WEBPVP8 "
        print("Conversion déjà effectuée")
    else:
        raise FileNotFoundError("PNG de raffinerie non trouvé")
else:
    if len(candidates) != 1:
        raise RuntimeError("Plusieurs PNG candidats")
    source = candidates[0]
    with Image.open(source) as img:
        assert img.format == "PNG"
        rgb = ImageOps.exif_transpose(img).convert("RGB")
        size = rgb.size
        rgb.save(dest, "WEBP", quality=85, lossless=False, method=6)
    with Image.open(dest) as result:
        assert result.format == "WEBP" and result.size == size
    b=dest.read_bytes()
    assert b[:4] == b"RIFF" and b[8:16] == b"WEBPVP8 "
    assert len(b) < source.stat().st_size
    source.unlink()
    print(f"PNG supprimé, WebP {dest.name}, {len(b)} octets")
