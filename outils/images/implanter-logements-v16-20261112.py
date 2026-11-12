#!/usr/bin/env python3
"""Conversion et raccordement strict des six images des immeubles V16 de Novomirsk."""
from pathlib import Path
import re
import unicodedata
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
directory = ROOT / "images/Sovarka/Novomirsk"
DEST = {
    ("marche", "hall"): "Novomirsk_logements_marche_hall.webp",
    ("marche", "petit"): "Novomirsk_logements_marche_petit_appartement.webp",
    ("marche", "grand"): "Novomirsk_logements_marche_grand_appartement.webp",
    ("quais", "hall"): "Novomirsk_logements_quais_hall.webp",
    ("quais", "petit"): "Novomirsk_logements_quais_petit_appartement.webp",
    ("quais", "grand"): "Novomirsk_logements_quais_grand_appartement.webp",
}
def normalize(s):
    return "".join(ch for ch in unicodedata.normalize("NFKD", s.lower()) if not unicodedata.combining(ch))

sources = {}
for p in directory.glob("*.png"):
    name = normalize(p.stem)
    if not name.startswith("novomirsk_immeuble "):
        continue
    building = "marche" if "marche" in name else "quais" if "quais" in name else None
    kind = "hall" if "hall" in name else "petit" if "petit" in name else "grand" if "grand" in name else None
    assert building and kind, f"Nom inattendu : {p.name}"
    key = (building,kind)
    assert key not in sources, f"Doublon : {key}"
    sources[key] = p
assert set(sources) == set(DEST), f"PNG manquants ou inattendus : {set(DEST)-set(sources)} / {set(sources)-set(DEST)}"
for key, p in sources.items():
    target = directory / DEST[key]
    assert not target.exists(), f"Ne pas écraser {target}"
    with Image.open(p) as im:
        im.convert("RGB").save(target, format="WEBP", quality=85, method=6)
    with Image.open(target) as out:
        assert out.format == "WEBP" and out.width > 500 and out.height > 300
    print(f"{p.name} -> {target.name} ({target.stat().st_size:,} octets)")
    p.unlink()

datafile = ROOT / "data.js"
data = datafile.read_text(encoding="utf-8")
start = data.index("  const copieLogements = (id, nomImmeuble, desc, decalage) => {")
end = data.index("  copieLogements('logements-novomirsk-marche'", start)
original = data[start:end]
assert "b.rooms.salle.imageUrl" not in original
old = "    b.desc = desc;\n"
new = """    b.desc = desc;
    // Les deux immeubles V16 ont chacun leurs images, sans changer les loyers.
    const prefixeImage = 'images/Sovarka/Novomirsk/Novomirsk_logements_'
      + (id === 'logements-novomirsk-marche' ? 'marche' : 'quais') + '_';
    b.rooms.salle.imageUrl = prefixeImage + 'hall.webp';
"""
assert original.count(old) == 1
changed = original.replace(old, new)
old = "      r.name = nom;\n"
new = """      r.name = nom;
      r.imageUrl = prefixeImage + (m[1] === 'petit' ? 'petit' : 'grand') + '_appartement.webp';
"""
assert changed.count(old) == 1
changed = changed.replace(old, new)
data = data[:start] + changed + data[end:]
datafile.write_text(data, encoding="utf-8")
assert all((directory / name).is_file() for name in DEST.values())
assert not any(source.exists() for source in sources.values())
print("Raccordement data.js terminé : 2 halls et 16 appartements.")
