#!/usr/bin/env python3
"""Convertit les trois images demandées, et découpe la planche du centre d'affaires.
Ne touche pas à la quatrième PNG (hôpital) déposée dans le même dossier.
"""
from pathlib import Path
from PIL import Image, ImageOps
import unicodedata

DIR = Path("images/Sovarka/Krasnov")
SRC = {
    "Épicerie soviétique au crépuscule.png": "Krasnov_station_service_boutique.webp",
    "Cuisine russe rétro aux couleurs chaleureuses.png": "Krasnov_maison_antonina_interieur.webp",
    "Centre d’affaires au coucher du soleil.png": None,
}
norm = lambda name: unicodedata.normalize("NFC", name)
actual = {norm(p.name): p for p in DIR.glob("*.png")}
if set(map(norm, SRC)) - set(actual):
    raise SystemExit("Sources absentes : " + repr(sorted(set(map(norm, SRC)) - set(actual))))
outputs = {
    "Krasnov_station_service_boutique.webp",
    "Krasnov_maison_antonina_interieur.webp",
    "Krasnov_centre_affaires_accueil.webp",
    "Krasnov_centre_affaires_bureau_maison_bleue.webp",
    "Krasnov_centre_affaires_bureau_hopital.webp",
    "Krasnov_centre_affaires_hotesse.webp",
}
if any((DIR / name).exists() for name in outputs):
    raise SystemExit("Les sorties sont déjà présentes ; conversion interrompue pour éviter un écrasement.")

def save(image, file):
    image.convert("RGB").save(DIR / file, format="WEBP", quality=87, method=6)
    with Image.open(DIR / file) as chk:
        chk.verify()
    print(file, (DIR / file).stat().st_size, "octets")

for name, target in SRC.items():
    p = actual[norm(name)]
    with Image.open(p) as image:
        if image.format != "PNG":
            raise SystemExit("Source non PNG : " + p.name)
        image = ImageOps.exif_transpose(image).convert("RGB")
        w,h=image.size
        if w<900 or h<500: raise SystemExit("Dimensions inattendues : " + str((w,h)))
        if target:
            save(image,target)
        else:
            # Planche générée : partie supérieure = accueil ; moitié inférieure
            # gauche = vue maison bleue ; moitié inférieure droite = vue hôpital.
            split=int(h*.532)
            half=w//2
            hall=image.crop((0,0,w,split))
            bleu=image.crop((0,split,half,h))
            hopital=image.crop((half,split,w,h))
            # Remise à l'échelle en préservant strictement le cadrage de chaque pièce.
            save(hall,"Krasnov_centre_affaires_accueil.webp")
            save(bleu,"Krasnov_centre_affaires_bureau_maison_bleue.webp")
            save(hopital,"Krasnov_centre_affaires_bureau_hopital.webp")
            # Hôtesse déjà présente dans la scène. Recadrage depuis l'angle
            # gauche de la moitié supérieure de la planche, pas de nouveau portrait.
            crop=image.crop((int(w*.185),int(h*.17),int(w*.36),int(h*.52)))
            if crop.width<120 or crop.height<120:
                raise SystemExit("Portrait insuffisant")
            save(crop,"Krasnov_centre_affaires_hotesse.webp")
for name in SRC:
    actual[norm(name)].unlink()
print("3 PNG supprimés ; 6 WebP produits et vérifiés ; quatrième PNG laissée intacte.")
