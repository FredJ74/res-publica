#!/usr/bin/env python3
"""Convertit les SIX PNG originaux chargés par Fred pour la Résidence impériale.
Exécution seulement sur la branche temporaire et en CI ; préserve les noms de salle."""
from pathlib import Path
from PIL import Image
import unicodedata
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
IMAGES = ROOT / "images" / "Sovarka" / "Novomirsk"
OUTS = {
  "hall": "novomirsk-residence-imperiale-hall.webp",
  "grand": "novomirsk-residence-imperiale-grand-appartement.webp",
  "1": "novomirsk-residence-imperiale-appartement-1.webp",
  "2": "novomirsk-residence-imperiale-appartement-2.webp",
  "3": "novomirsk-residence-imperiale-appartement-3.webp",
  "4": "novomirsk-residence-imperiale-appartement-4.webp",
}
def sans_accents(n):
    return ''.join(c for c in unicodedata.normalize("NFKD", n) if not unicodedata.combining(c)).lower()
def key(file):
    stem=sans_accents(file.stem)
    if not stem.startswith("novomirsk_") or "residence" not in stem or "imperial" not in stem:
        return None
    if "grand appartement" in stem: return "grand"
    if "hall" in stem: return "hall"
    for num in "1234":
        if f"appartement {num}" in stem or f"appartment {num}" in stem:
            return num
    raise ValueError(f"Image de la résidence sans attribution certaine : {file.name}")
candidates = [x for x in IMAGES.glob("*.png") if key(x) is not None]
if len(candidates) != 6: raise SystemExit(f"6 images attendues, {len(candidates)} trouvées")
seen = {}
for src in candidates:
    k=key(src)
    if k in seen: raise SystemExit(f"Doublon {k} : {src}, {seen[k]}")
    seen[k]=src
if set(seen)!=set(OUTS): raise SystemExit(f"Attribution incomplète : {sorted(seen)}")
rows=[]
for k,target in OUTS.items():
    src=seen[k]
    dest=IMAGES/target
    if dest.exists(): raise SystemExit(f"WebP préexistant : {dest}")
    with Image.open(src) as im:
        if im.format != "PNG": raise SystemExit(f"Source non PNG : {src}")
        dimensions=im.size
        if min(dimensions)<900: raise SystemExit(f"Dimensions inattendues : {src} {dimensions}")
        im.convert("RGB").save(dest, "WEBP", quality=89, method=6)
    with Image.open(dest) as check:
        check.verify()
    with Image.open(dest) as check:
        if check.format!="WEBP" or check.size != dimensions: raise SystemExit(f"WebP non conforme : {dest}")
    rows.append({
        "piece": k, "ancien_png": str(src.relative_to(ROOT)),
        "webp": str(dest.relative_to(ROOT)), "dimensions": list(dimensions),
        "png_octets": src.stat().st_size, "webp_octets": dest.stat().st_size,
        "sha256_webp": hashlib.sha256(dest.read_bytes()).hexdigest()
    })
    src.unlink()
audit=ROOT/"outils"/"audits"/"residence-imperiale-six-webp-20261111.json"
audit.parent.mkdir(parents=True, exist_ok=True)
audit.write_text(json.dumps(rows,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps(rows,ensure_ascii=False,indent=2))
