#!/usr/bin/env python3
"""Convertit le ZIP des huit portraits de Starovka et retire l'archive source.

Chaque fichier est vérifié par son nom, sa taille et son ouverture WebP. Un fichier
nommé par erreur ou un portrait déjà présent bloque la conversion.
"""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images/Sovarka/Starovka"
ZIP = DIR / "Starovka_8_portraits_individuels.zip"
NAMES = (
    "Starovka_portrait_mairie_munko-tsybenov.png",
    "Starovka_portrait_mairie_dugar-tsyrempilov.png",
    "Starovka_portrait_mairie_soyolma-ayusheeva.png",
    "Starovka_portrait_mairie_tsyden-zhalsaraev.png",
    "Starovka_portrait_mairie_erdem-gombozhapov.png",
    "Starovka_portrait_gare_gombo-zhigzhitov.png",
    "Starovka_portrait_centre-affaires_oyuuna-tsydenova.png",
    "Starovka_portrait_syndicat_batbayar-dachiev.png",
)
assert ZIP.is_file(), f"ZIP absent : {ZIP}"
with ZipFile(ZIP) as z:
    entries = [i for i in z.infolist() if not i.is_dir()
               and not i.filename.startswith("__MACOSX/")
               and not Path(i.filename).name.startswith(".")]
    mapping = {}
    for info in entries:
        name = Path(info.filename).name
        if name in mapping:
            raise RuntimeError(f"Doublon de nom dans le ZIP : {name}")
        mapping[name] = info
    if set(mapping) != set(NAMES):
        raise RuntimeError(f"Noms du ZIP non conformes : manquants={sorted(set(NAMES)-set(mapping))}, autres={sorted(set(mapping)-set(NAMES))}")
    for name in NAMES:
        out = DIR / name.replace(".png", ".webp")
        if out.exists():
            raise RuntimeError(f"Portrait existant à protéger : {out}")
        with Image.open(BytesIO(z.read(mapping[name]))) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
            if image.size != (1024, 1024):
                raise RuntimeError(f"Portrait non carré 1024 : {name} {image.size}")
            image.save(out, "WEBP", quality=86, method=6)
        with Image.open(out) as saved:
            saved.verify()
        print(f"{name} -> {out.name} ({out.stat().st_size} octets)")
ZIP.unlink()
print("SUCCÈS : huit WebP validés et ZIP original supprimé.")
