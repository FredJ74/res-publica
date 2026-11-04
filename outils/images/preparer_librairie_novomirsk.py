#!/usr/bin/env python3
"""Prépare les visuels WebP et les portraits des deux PNJ de la librairie de Novomirsk."""
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "images" / "Sovarka" / "Novomirsk"
ASSETS = [
    ("Novo_librairie_accueil.png", "Novo_librairie_accueil.webp",
     "Novo_ludmila_pamphletova_portrait.webp", (510, 230, 930, 650)),
    ("Novo_librairie_atelier.png", "Novo_librairie_atelier.webp",
     "Novo_typographe_portrait.webp", (395, 120, 885, 610)),
]
for source, scene, portrait, crop in ASSETS:
    path = FOLDER / source
    if not path.is_file():
        raise FileNotFoundError(path)
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        image.save(FOLDER / scene, "WEBP", quality=85, method=6)
        crop = tuple(round(v * image.width / 1448) if source.endswith("accueil.png") and i % 2 == 0
                     else round(v * image.height / 1086) if source.endswith("accueil.png")
                     else v for i, v in enumerate(crop))
        # Le cadrage respecte le personnage au premier plan de chaque scène.
        visage = image.crop(crop).resize((480, 480), Image.Resampling.LANCZOS)
        visage.save(FOLDER / portrait, "WEBP", quality=87, method=6)

data_path = ROOT / "data.js"
data = data_path.read_text(encoding="utf-8")
old = """        'imprimerie-librairie': {
          name: "Librairie du Peuple",
          imagesAVenir: true,
          desc: "La librairie du Parti, sur la Place du Peuple. On y imprime livres, brochures et tracts, sous l'oeil bienveillant du Comite.",
          roomOverrides: {
            accueil_imprimerie: {
              imageUrl: 'images/Sovarka/Novomirsk/Novo_librairie_accueil.png'
            }
          },
          persons: [{name: 'Ludmila Pamphletova (PNJ)', role: 'PNJ - Libraire-imprimeuse du Parti', rel: 'neutral', job: 'imprimeur'}]
        },"""
new = """        'imprimerie-librairie': {
          name: "Librairie du Peuple",
          imagesAVenir: true,
          desc: "La librairie du Parti, sur la Place du Peuple. On y imprime livres, brochures et tracts, sous l'oeil bienveillant du Comite.",
          roomOverrides: {
            accueil_imprimerie: {
              imageUrl: 'images/Sovarka/Novomirsk/Novo_librairie_accueil.webp',
              persons: [{name: 'Ludmila Pamphletova (PNJ)', role: 'PNJ - Libraire-imprimeuse du Parti', rel: 'neutral', job: 'imprimeur', photoUrl: 'images/Sovarka/Novomirsk/Novo_ludmila_pamphletova_portrait.webp'}]
            },
            atelier: {
              imageUrl: 'images/Sovarka/Novomirsk/Novo_librairie_atelier.webp',
              persons: [{name: 'Ouvrier typographe (PNJ)', role: 'PNJ - Typographe', rel: 'neutral', job: 'typographe', photoUrl: 'images/Sovarka/Novomirsk/Novo_typographe_portrait.webp'}]
            }
          },
          persons: [{name: 'Ludmila Pamphletova (PNJ)', role: 'PNJ - Libraire-imprimeuse du Parti', rel: 'neutral', job: 'imprimeur'}]
        },"""
if data.count(old) != 1:
    raise RuntimeError(f"Ancrage Novomirsk inattendu : {data.count(old)} occurrence(s)")
data_path.write_text(data.replace(old, new), encoding="utf-8")
for name in [x for row in ASSETS for x in (row[1], row[2])]:
    output = FOLDER / name
    with Image.open(output) as pic:
        assert pic.format == "WEBP"
    print(f"{output.relative_to(ROOT)} — {output.stat().st_size} octets")
print("Raccordement data.js réalisé (accueil, atelier, portraits des deux PNJ).")
