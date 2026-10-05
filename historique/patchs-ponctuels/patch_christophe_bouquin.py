#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        persons: [
          {name:'Archiviste Municipal (PNJ)', role:'PNJ - Gardien des archives', rel:'neutral', job:'archiviste'}
        ],
        orders: [
          {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."},"""
new = """        persons: [
          {name:'Christophe Bouquin (PNJ)', role:'Archiviste Municipal', rel:'neutral', job:'archiviste', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/christophe-bouquin-archiviste.png', photoPos:'50% 15%'}
        ],
        orders: [
          {fn:'consulter_etat_civil', label:"Consulter l'état-civil", pa:0, cost:0, type:'legal', icon:'ti-file-search', successRate:100, desc:"Rechercher par nom ou par décennie dans le registre d'état-civil de Republia."},"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Christophe Bouquin nommé Archiviste Municipal, avec sa photo.")
