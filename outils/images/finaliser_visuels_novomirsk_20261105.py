#!/usr/bin/env python3
"""Conversion des scènes de Novomirsk, portraits et raccordement sans PNG résiduels."""
from pathlib import Path
from PIL import Image, ImageOps
import re

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images" / "Sovarka" / "Novomirsk"
DATA = ROOT / "data.js"
scene_files = {
    "restaurant": "Novo_restaurant Volga.png",
    "musee": next(p.name for p in DIR.glob("Novo_mus*hall.png")),
    "palais": "Novo_palais_hall.png",
}
# Portraits cadrés en fractions de la scène ; aucune altération des visages.
# Coordonnées : gauche, haut, droite, bas (en fraction de la taille originale).
portraits = [
    ("restaurant", "Novo_tatiana_bortchova_portrait.webp", (.245,.055,.525,.475)),
    ("musee", "Novo_irina_guichetova_portrait.webp", (.095,.365,.292,.702)),
    ("musee", "Novo_lev_patrimonov_portrait.webp", (.275,.31,.540,.718)),
    ("musee", "Novo_ilia_medailine_portrait.webp", (.520,.225,.830,.735)),
]
scenes = {}
for key, filename in scene_files.items():
    path = DIR / filename
    if not path.exists():
        raise RuntimeError(f"Source manquante : {path}")
    with Image.open(path) as original:
        scenes[key] = ImageOps.exif_transpose(original).convert("RGB")
    output = DIR / ("Novo_restaurant_Volga.webp" if key == "restaurant"
                    else "Novo_musee_municipal_hall.webp" if key == "musee"
                    else "Novo_palais_hall.webp")
    scenes[key].save(output, "WEBP", quality=85, method=6)
for key, filename, box in portraits:
    im = scenes[key]
    coords = tuple(round(x * (im.width if i % 2 == 0 else im.height))
                   for i, x in enumerate(box))
    im.crop(coords).resize((480,480), Image.Resampling.LANCZOS).save(
        DIR / filename, "WEBP", quality=87, method=6)

text = DATA.read_text(encoding="utf-8")
def once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label} : attendu 1 ancrage, trouvé {count}")
    text = text.replace(old,new)

once("images/Sovarka/Novomirsk/Novo_palais_hall.png",
     "images/Sovarka/Novomirsk/Novo_palais_hall.webp", "palais")
old_rest = """        'capitaine-sauvage': {
          name: "Restaurant La Mère Volga",
          imagesAVenir: true,
          desc: "La cantine de quartier du Prospekt du Peuple : nappes à carreaux, samovar fumant et portions réglementaires. La Mère Volga nourrit le prolétariat depuis trois plans quinquennaux.",
          persons: [{name: 'Tatiana Bortchova (PNJ)', role: 'Serveuse', rel: 'neutral', job: 'serveur'}]
        }"""
new_rest = """        'capitaine-sauvage': {
          name: "Restaurant La Mère Volga",
          imagesAVenir: true,
          desc: "La cantine de quartier du Prospekt du Peuple : nappes à carreaux, samovar fumant et portions réglementaires. La Mère Volga nourrit le prolétariat depuis trois plans quinquennaux.",
          roomOverrides: {
            salle_principale: {
              imageUrl: 'images/Sovarka/Novomirsk/Novo_restaurant_Volga.webp',
              persons: [{name: 'Tatiana Bortchova (PNJ)', role: 'Responsable de salle', rel: 'neutral', job: 'serveur', photoUrl: 'images/Sovarka/Novomirsk/Novo_tatiana_bortchova_portrait.webp'}]
            }
          },
          persons: [{name: 'Tatiana Bortchova (PNJ)', role: 'Serveuse', rel: 'neutral', job: 'serveur'}]
        }"""
once(old_rest,new_rest,"restaurant Sovarka")

museum_start = text.index("  'musee-novomirsk': {")
museum_end = text.index("\n  // =====================",museum_start)
museum = text[museum_start:museum_end]
assert "name: \"Hall d'accueil\"" in museum
museum = museum.replace('name: "Hall d\'accueil",','name: "Hall d\'accueil",\n        imageUrl: "images/Sovarka/Novomirsk/Novo_musee_municipal_hall.webp",',1)
for name, photo in [
    ("Irina Guichetova (PNJ)","Novo_irina_guichetova_portrait.webp"),
    ("Docteur Lev Patrimonov (PNJ)","Novo_lev_patrimonov_portrait.webp"),
    ("Vétéran Ilia Médailline (PNJ)","Novo_ilia_medailine_portrait.webp"),
]:
    pattern = r"(\\{name:'" + re.escape(name) + r"', role:'[^']+', rel:'neutral', job:'[^']+')\\}"
    hits = len(re.findall(pattern,museum))
    if hits < 1: raise RuntimeError("PNJ sans occurrence : "+name)
    museum = re.sub(pattern, lambda m: m.group(1)+", photoUrl:'images/Sovarka/Novomirsk/"+photo+"'}",museum)
    print(f"{name}: {hits} occurences")
text=text[:museum_start]+museum+text[museum_end:]
# L'atelier et l'accueil de la librairie sont déjà sur WebP.
DATA.write_text(text,encoding="utf-8")
# Les cinq originaux du dossier ont désormais chacun une variante WebP.
for png in sorted(DIR.glob("*.png")):
    assert (DIR / (png.stem+".webp")).exists() or png.name in (
        "Novo_restaurant Volga.png",scene_files["musee"]), f"WebP absent : {png}"
    png.unlink()
assert not list(DIR.glob("*.png"))
for file in sorted(DIR.glob("*.webp")):
    with Image.open(file) as im:
        assert im.format == "WEBP",file
        im.verify()
    print(file.name, file.stat().st_size)
print("Novomirsk : 0 PNG ; 2 nouvelles scènes et 4 portraits reliés, palais passé en WebP")
