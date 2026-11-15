#!/usr/bin/env python3
"""Starovka : cinq illustrations des logements collectifs, conversion et raccordement local."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "images/Sovarka/Starovka"
FILES = {
    "Hall d’entrée soviétique sous la neige.png": "Starovka_logements_hall.webp",
    "Salon chaleureux sur stade enneigé.png": "Starovka_logements_petit_stade.webp",
    "Salon industriel enneigé avec vue sur les pompes à pétrole.png": "Starovka_logements_petit_foreuses.webp",
    "Salon hivernal baigné de lumière naturelle.png": "Starovka_logements_grand_stade.webp",
    "Salon hivernal face aux derricks enneigés.png": "Starovka_logements_grand_foreuses.webp",
}
for original, output in FILES.items():
    candidates = [p for p in FOLDER.glob("*.png") if unicodedata.normalize("NFC", p.name) == original]
    target = FOLDER / output
    if len(candidates) == 1:
        source = candidates[0]
        with Image.open(source) as im:
            assert im.format == "PNG", source
            rgb = ImageOps.exif_transpose(im).convert("RGB")
            original_size = rgb.size
            rgb.save(target, "WEBP", quality=85, method=6)
        with Image.open(target) as verify:
            assert verify.format == "WEBP" and verify.size == original_size, target
        assert target.read_bytes()[:4] == b"RIFF"
        assert len(target.read_bytes()) < source.stat().st_size, target
        source.unlink()
        print(f"{source.name} -> {target.name}")
    elif not candidates and target.is_file():
        assert target.read_bytes()[:4] == b"RIFF"
    else:
        raise RuntimeError(f"PNG absent ou ambigu : {original} ({len(candidates)})")

path = ROOT / "data.js"
data = path.read_text(encoding="utf8")
marker = "  Object.assign(contexte('ville_a', 'logements-novomirsk'), { name: 'Baraquement Sibirsk-9',"
assert data.count(marker) == 1, "Surcharge Starovka introuvable"
tag = "// STAROVKA_LOGEMENTS_CINQ_WEBP"
if tag not in data:
    insertion = """  // STAROVKA_LOGEMENTS_CINQ_WEBP — décors exclusifs à la ville_a,
  // aucune modification des baux, des ordres ou des logements des autres villes.
  {
    const logementStarovka = contexte('ville_a', 'logements-novomirsk');
    const decorLogement = (pieceId, fichier) => {
      Object.assign(piece(logementStarovka, pieceId), {
        imageUrl: 'images/Sovarka/Starovka/Starovka_logements_' + fichier + '.webp'
      });
    };
    decorLogement('salle', 'hall');
    for (let n = 1; n <= 4; n++) {
      const vue = n % 2 === 1 ? 'stade' : 'foreuses';
      decorLogement('petit_appartement_' + n, 'petit_' + vue);
      decorLogement('grand_appartement_' + n, 'grand_' + vue);
      // Les chambres premium conservent la vue du salon associé.
      decorLogement('petit_appartement_' + n + '_chambre_1', 'petit_' + vue);
      decorLogement('grand_appartement_' + n + '_chambre_1', 'grand_' + vue);
      decorLogement('grand_appartement_' + n + '_chambre_2', 'grand_' + vue);
    }
  }
"""
    index = data.index(marker)
    data = data[:index] + insertion + data[index:]
    path.write_text(data, encoding="utf8")
else:
    print("Raccordement déjà réalisé")
for f in FILES.values():
    assert (FOLDER / f).exists(), f
print("5 WebP, 5 anciens PNG supprimés, surcharge ville_a prête.")
