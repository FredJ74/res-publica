#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (titreEl) titreEl.textContent = opts.titre || '';
  if (texteEl) texteEl.textContent = opts.texte || '';"""
new = """  if (titreEl) titreEl.textContent = opts.titre || '';
  if (texteEl) texteEl.innerHTML = opts.texte || '';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ innerHTML activé (retours à la ligne et gras possibles).")
