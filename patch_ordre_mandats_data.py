#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        orders: [
          {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."}
        ]"""
new = """        orders: [
          {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."},
          {fn:'consulter_mandats_maires', label:'Consulter les résumés de mandats', pa:0, cost:0, type:'legal', icon:'ti-book', successRate:100, desc:'Grands chantiers et actes majeurs des maires successifs de Luthécia.'}
        ]"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre 'Consulter les résumés de mandats' ajouté à la Salle des Archives.")
