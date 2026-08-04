#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},"""
new = """{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'corrompre_rdv_notaire', label:'Accélérer le rendez-vous (corruption)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant avant le rendez-vous notarial d\\'un achat direct.'},"""

nb = content.count(old)
assert nb == 5, f"trouvé {nb} fois (attendu 5)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ Ordre de corruption du rendez-vous ajouté aux {nb} lots.")
