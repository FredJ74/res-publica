#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100}"""
new = """{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'diviser_construction', label:'Diviser / gérer les lots', pa:0, cost:0, type:'legal', icon:'ti-grid-dots', successRate:100, desc:'Réservé aux Commerces Premium et Buildings construits.'},{fn:'louer_lot_ici', label:'Louer un lot ici', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'Louer un lot disponible, si ce terrain a été divisé par son propriétaire.'},{fn:'gerer_lot_loue', label:'Gérer mon local loué', pa:0, cost:0, type:'legal', icon:'ti-home-cog', successRate:100, desc:'Voir/accepter les propositions du propriétaire concernant votre lot loué ici.'}"""

nb = content.count(old)
assert nb == 5, f"trouvé {nb} fois (attendu 5, un par lot)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ Ordres ajoutés aux {nb} lots (diviser/gérer, louer un lot, gérer mon local loué).")
