#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','port-plaisance-psm','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-2','terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11','stade','zone-production','capitaine-sauvage','chasse-peche-psm','place-armes-psm','ecole-marine','chantier-naval','notre-dame-mer','phare-psm','marche-psm','musee-port-sainte-marie'],"""

new = """      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','port-plaisance-psm','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11','stade','zone-production','capitaine-sauvage','chasse-peche-psm','place-armes-psm','ecole-marine','chantier-naval','notre-dame-mer','phare-psm','marche-psm','musee-port-sainte-marie'],"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Collision retirée : terrain-a-batir-2 n'est plus listé à PSM (réservé à Luthécia).")
