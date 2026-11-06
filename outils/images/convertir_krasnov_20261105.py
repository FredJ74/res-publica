#!/usr/bin/env python3
"""Convertit exactement les cinq images fournies pour Krasnov en WebP et retire les PNG validés."""
from pathlib import Path
from PIL import Image, ImageOps
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "images" / "Sovarka" / "Krasnov"
EXPECTED = (
    "Krasnov rue église.png",
    "Krasnov rue gare.png",
    "Krasnov rue maison.png",
    "Krasnov rue terrains.png",
    "Krasnov_gare_hall.png",
)

def main():
    actual = sorted(p.name for p in FOLDER.glob("*.png"))
    if actual != sorted(EXPECTED):
        raise RuntimeError(f"Liste PNG non conforme : {actual!r} (attendus : {sorted(EXPECTED)!r})")
    # Ne pas supprimer un PNG encore référencé par le jeu ; seule la conversion des fichiers
    # nouveaux et non raccordés est autorisée dans cette mission.
    refs = subprocess.run(
        ["git", "grep", "-n", "-F", "-f", "/dev/stdin", "--", "*.js", "*.html", "*.css", "*.json"],
        input="\n".join(EXPECTED) + "\n",
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=ROOT, check=False,
    )
    if refs.returncode not in (0, 1):
        raise RuntimeError("git grep impossible : " + refs.stderr)
    if refs.stdout.strip():
        raise RuntimeError("Références PNG détectées avant suppression :\n" + refs.stdout)
    created = []
    for name in EXPECTED:
        original = FOLDER / name
        target = original.with_suffix(".webp")
        if target.exists():
            raise RuntimeError("Variante déjà présente, refus d'écraser : " + target.name)
        with Image.open(original) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
            width, height = image.size
            image.save(target, format="WEBP", quality=85, method=6)
        with Image.open(target) as verification:
            if verification.format != "WEBP" or verification.size != (width, height):
                raise RuntimeError("Conversion incorrecte : " + target.name)
            verification.verify()
        created.append(target)
        print(f"{name} -> {target.name}: {original.stat().st_size} -> {target.stat().st_size} octets")
    if len(created) != len(EXPECTED):
        raise RuntimeError("Conversions incomplètes : aucun PNG supprimé")
    for name in EXPECTED:
        (FOLDER / name).unlink()
    if list(FOLDER.glob("*.png")):
        raise RuntimeError("PNG résiduels dans Krasnov")
    print("OK : 5 WebP vérifiés, 5 PNG supprimés. Pas de changement de navigation.")

if __name__ == "__main__":
    main()
