#!/usr/bin/env python3
"""Convertit exactement les 10 scènes de toundra fournies dans images/Sovarka.
Les fichiers sources proviennent du dépôt (checkout de main dans CI).
Pas de sortie sans vérification des dimensions et des poids.
"""
from pathlib import Path
from PIL import Image
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "images" / "Sovarka"
DEST = SOURCE / "Goulag"
files = sorted(SOURCE.glob("Image ChatGPT 16 nov. 2026, 03_34_*-*.png"), key=lambda p: int(re.search(r"-(\d+)\.png$", p.name).group(1)))
assert len(files) == 10, f"10 scènes attendues, {len(files)} : {[p.name for p in files]}"
DEST.mkdir(parents=True, exist_ok=True)
index = []
dims = set()
for n, src in enumerate(files, start=1):
    out = DEST / f"Sovarka_goulag_toundra_{n:02}.webp"
    with Image.open(src) as im:
        dims.add(im.size)
        assert im.size == (1448, 1086), (src.name, im.size)
        im.convert("RGB").save(out, "WEBP", quality=85, method=6)
    with Image.open(out) as check:
        assert check.format == "WEBP" and check.size == (1448, 1086)
    assert out.stat().st_size < src.stat().st_size, out
    index.append({"etape": n, "source": src.name, "fichier": out.name, "octets": out.stat().st_size,
                  "sha256": hashlib.sha256(out.read_bytes()).hexdigest()})
assert len(dims) == 1
(DEST / "manifest.json").write_text(json.dumps({"dimensions": [1448, 1086], "qualite": 85, "vues": index}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
for src in files:
    src.unlink()
placeholder = SOURCE / "Goulag"  # old placeholder must be deleted by runner BEFORE mkdir
print("10/10 WebP créés et vérifiés : 1448x1086, qualité 85. 10 PNG supprimés.")
