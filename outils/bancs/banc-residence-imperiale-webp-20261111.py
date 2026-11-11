#!/usr/bin/env python3
"""Régression de présence, d'identité et de dimensions des six décors de la Résidence."""
from pathlib import Path
from PIL import Image
import json
import re
import unicodedata

root=Path(__file__).resolve().parents[2]
base=root/"images/Sovarka/Novomirsk"
data=(root/"data.js").read_text(encoding="utf-8")
start=data.find("'residence-imperiale-novomirsk': {")
end=data.find("// GARAGE DE NOVOMIRSK",start)
assert start>=0 and end>start
b=data[start:end]
pieces={"hall_residence":"hall","appartement_1":"appartement-1","appartement_2":"appartement-2",
        "appartement_3":"appartement-3","appartement_4":"appartement-4",
        "grand_appartement":"grand-appartement"}
audit=root/"outils/audits/residence-imperiale-six-webp-20261111.json"
rows=json.loads(audit.read_text())
assert len(rows)==6
for piece,suffix in pieces.items():
    filename="novomirsk-residence-imperiale-"+suffix+".webp"
    path=base/filename
    assert path.is_file(),path
    with Image.open(path) as im:
        assert im.format=="WEBP" and min(im.size)>=900,(filename,im.size)
    section=b.split("      "+piece+": {",1)[1].split("\n      }",1)[0]
    assert section.count("imageUrl:")==1,(piece,"imageUrl absent ou doublonné")
    assert "imageUrl: 'images/Sovarka/Novomirsk/"+filename+"'" in section, piece
    assert any(r["piece"]==("grand" if piece=="grand_appartement" else
                             "hall" if piece=="hall_residence" else piece[-1])
               and r["webp"]=="images/Sovarka/Novomirsk/"+filename
               for r in rows)
def canon(f):
    return ''.join(c for c in unicodedata.normalize('NFKD',f.name) if not unicodedata.combining(c)).lower()
assert not any("residence" in canon(p) and "imperial" in canon(p)
               for p in base.glob("*.png")), "anciens PNG non supprimés"
# Location privative à l'accueil (Fred, 12/11/2026) : l'ancienne location de local a disparu.
assert "fn:'louer_local'" not in b and "fn:'gerer_local'" not in b, "ancienne location de local encore présente"
assert "fn:'residence_reserver'" in b and b.count("fn:'residence_minibar'")==5, "ordres de la Résidence absents"
print("Six salles illustrées en WebP, six PNG supprimés, réservation à l'accueil en place.")
