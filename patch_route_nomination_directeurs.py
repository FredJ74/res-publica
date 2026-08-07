#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'vente_directe_usine') { doOuvrirVenteDirecteUsine(); return; }"""
new = """  if (fn === 'vente_directe_usine') { doOuvrirVenteDirecteUsine(); return; }
  if (fn === 'nommer_directeur_pharma') { ouvrirModalNommerDirecteurPharma(); return; }
  if (fn === 'nommer_directeur_tabac_alcools') { ouvrirModalNommerDirecteurTabacAlcools(); return; }
  if (fn === 'nommer_directeur_raffinerie') { ouvrirModalNommerDirecteurRaffinerie(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 3 ordres de nomination routés.")
