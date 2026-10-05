#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

remplacements = [
    ("""        desc: "Le bureau du directeur de la raffinerie. Accès sur rendez-vous.",
        persons: [],
        orders: []""",
     """        desc: "Le bureau du directeur de la raffinerie. Accès sur rendez-vous.",
        persons: [],
        orders: [{fn:'nommer_directeur_raffinerie', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de la raffinerie. Poste exclusif (sauf député).'}]"""),
    ("""        desc: "Le bureau du directeur du pôle. Accès sur rendez-vous.",
        persons: [],
        orders: []""",
     """        desc: "Le bureau du directeur du pôle. Accès sur rendez-vous.",
        persons: [],
        orders: [{fn:'nommer_directeur_tabac_alcools', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur du Pôle Tabac & Alcools. Poste exclusif (sauf député).'}]"""),
    ("""        desc: "Le bureau du directeur de l'usine. Accès sur rendez-vous.",
        persons: [],
        orders: []""",
     """        desc: "Le bureau du directeur de l'usine. Accès sur rendez-vous.",
        persons: [],
        orders: [{fn:'nommer_directeur_pharma', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de l\\'Usine Pharmaceutique. Poste exclusif (sauf député).'}]"""),
]

for old, new in remplacements:
    nb = content.count(old)
    assert nb == 1, f"trouvé {nb} fois (attendu 1) pour : {old[:60]}..."
    content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordres de nomination ajoutés aux 3 bureaux de direction.")
