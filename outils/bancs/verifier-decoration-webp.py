#!/usr/bin/env python3
"""Garde de non-régression pour commerce-decoration (source versionnée)."""
from pathlib import Path
p=Path("supabase/edge-functions/commerce-decoration/index.ts")
s=p.read_text(encoding="utf-8")
requirements={
 "sortie WebP": 'form.append("output_format","webp")',
 "compression": 'form.append("output_compression","85")',
 "extension": 'crypto.randomUUID()+".webp"',
 "type Supabase": 'contentType:"image/webp"',
 "préservation PNG en entrée": 'const photoPng=',
 "prise en charge WebP en retouche": 'const photoWebp=',
 "fichier de retouche MIME détecté": '"interieur."+photoExt,{type:photoMime}',
 "conservation ancienne version": 'existing?.image_path||null',
}
for label,term in requirements.items():
 assert term in s, f"Non-conformité {label}: {term}"
assert 'crypto.randomUUID()+".png"' not in s, "Nouvelle génération PNG détectée"
print("OK — sortie WebP, retouches multi-formats et héritage des anciens décors")
