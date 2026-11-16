#!/usr/bin/env python3
"""Starovka : trois vues de l'hôpital, sans changer les mécaniques des soins."""
from pathlib import Path
from PIL import Image, ImageOps
import hashlib
import json
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "images/Sovarka/Starovka"
SOURCES = {
    "Image ChatGPT 16 nov. 2026, 15_47_49-1.png": "Starovka_hopital_accueil.webp",
    "Image ChatGPT 16 nov. 2026, 15_47_50-2.png": "Starovka_hopital_chambre.webp",
    "Image ChatGPT 16 nov. 2026, 15_47_51-3.png": "Starovka_hopital_ehpad.webp",
}
RESULTATS = []
for orig, dest in SOURCES.items():
    matches = [p for p in FOLDER.iterdir() if p.suffix.lower() == ".png" and unicodedata.normalize("NFC", p.name) == unicodedata.normalize("NFC", orig)]
    target = FOLDER / dest
    if len(matches) == 1:
        source = matches[0]
        if target.exists():
            raise RuntimeError(f"Refus d'écraser le WebP : {target}")
        with Image.open(source) as im:
            if im.format != "PNG":
                raise RuntimeError(f"Source invalide : {source}")
            rgb = ImageOps.exif_transpose(im).convert("RGB")
            dims = rgb.size
            if dims[0] < 1000 or dims[1] < 700:
                raise RuntimeError(f"Résolution insuffisante : {source}")
            rgb.save(target, format="WEBP", quality=85, method=6)
        with Image.open(target) as check:
            check.load()
            if check.format != "WEBP" or check.size != dims:
                target.unlink(missing_ok=True)
                raise RuntimeError(f"WebP non conforme : {target}")
        data = target.read_bytes()
        if data[:4] != b"RIFF" or data[8:12] != b"WEBP" or len(data) >= source.stat().st_size:
            target.unlink(missing_ok=True)
            raise RuntimeError(f"WebP ou réduction invalide : {target}")
        source.unlink()
    elif not matches and target.exists():
        with Image.open(target) as check:
            if check.format != "WEBP" or check.size[0] < 1000:
                raise RuntimeError(f"WebP existant invalide : {target}")
    else:
        raise RuntimeError(f"PNG absent ou ambigu : {orig} ({len(matches)} correspondances)")
    RESULTATS.append({"image": dest, "octets": target.stat().st_size, "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})

path = ROOT / "data.js"
data = path.read_text(encoding="utf8")
tag = "STAROVKA_HOPITAL_TROIS_SALLES_20261116"
if tag not in data:
    data += """

// STAROVKA_HOPITAL_TROIS_SALLES_20261116
// Uniquement les décors de l'hôpital de Starovka : pas de modification des soins, PNJ ni ordres.
(function () {
  const ville = WORLD.soviet && WORLD.soviet.ville_a;
  if (!ville || !ville.buildingContext) throw new Error('Contexte de Starovka absent');
  const hopital = ville.buildingContext['dispensaire-public-v'];
  if (!hopital || !hopital.roomsExtra || !hopital.roomsExtra.chambre) {
    throw new Error("Pièces de l\'hôpital de Starovka absentes");
  }
  hopital.roomOverrides = hopital.roomOverrides || {};
  const path = 'images/Sovarka/Starovka/Starovka_hopital_';
  hopital.roomOverrides.attente = Object.assign(hopital.roomOverrides.attente || {}, {
    imageUrl: path + 'accueil.webp'
  });
  hopital.roomOverrides.ehpad = Object.assign(hopital.roomOverrides.ehpad || {}, {
    imageUrl: path + 'ehpad.webp'
  });
  hopital.roomsExtra.chambre.imageUrl = path + 'chambre.webp';
})();
"""
    path.write_text(data, encoding="utf8")
for f in SOURCES.values():
    if not (FOLDER / f).is_file():
        raise RuntimeError(f"Décor attendu absent : {f}")
print(json.dumps(RESULTATS, ensure_ascii=False, indent=2))
