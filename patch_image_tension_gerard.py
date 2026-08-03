#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  html += '<img src="https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block;max-height:260px;object-fit:cover"/>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.6">Gérard Poinçon se tient là, immobile, vous observant.</div>';"""
new = """  html += '<img src="https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-debarras-tension.png" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block;max-height:280px;object-fit:cover"/>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.6">Gérard Poinçon se tient là, immobile, vous observant.</div>';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Vraie image de tension intégrée à l'étape 2 de la révélation.")
