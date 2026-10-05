#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},"""
new = """{fn:'payer_versement_chantier', label:'Payer le versement du chantier', pa:0, cost:0, type:'legal', icon:'ti-cash', successRate:100, desc:'Régler le versement en attente pour que le chantier reprenne.'},{fn:'corrompre_chantier', label:'Accélérer le chantier (corruption)', pa:2, cost:1500, type:'illegal', icon:'ti-coins', successRate:100, desc:'Réduit de moitié le délai restant du chantier.'},{fn:'voler_materiel_chantier', label:'Voler du matériel de chantier', pa:2, cost:0, type:'illegal', icon:'ti-truck', successRate:0, desc:'Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.'},"""

nb = content.count(old)
assert nb == 5, f"trouvé {nb} fois (attendu 5)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ Ordre de vol de matériel ajouté aux {nb} lots.")
