#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'diviser_construction') { doOuvrirDivisionTerrain(); return; }"""
new = """  if (fn === 'acte_vente_terrain') { doActeVenteTerrain(); return; }
  if (fn === 'diviser_construction') { doOuvrirDivisionTerrain(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre acte_vente_terrain routé.")
