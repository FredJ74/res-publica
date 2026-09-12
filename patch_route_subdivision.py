#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'demander_divorce') { doDemanderDivorce(); return; }"""
new = """  if (fn === 'demander_divorce') { doDemanderDivorce(); return; }
  if (fn === 'diviser_construction') { doOuvrirDivisionTerrain(); return; }
  if (fn === 'louer_lot_ici') { doOuvrirLouerLot(); return; }
  if (fn === 'gerer_lot_loue') { doGererLotLoue(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 3 ordres routés (diviser, louer un lot, gérer mon local loué).")
