#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

ordre_achat = "[{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]"

# --- 1. Les 3 entrepots (texte identique, replace all) ---
old_1 = """        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: []"""
new_1 = """        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: """ + ordre_achat
nb_1 = content.count(old_1)
assert nb_1 == 3, f"entrepots : trouvé {nb_1} fois (attendu 3)"
content = content.replace(old_1, new_1)

# --- 2. Le Pole Tabac & Alcools de PSM (texte unique) ---
old_2 = """        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: []"""
new_2 = """        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: """ + ordre_achat
nb_2 = content.count(old_2)
assert nb_2 == 1, f"pole tabac : trouvé {nb_2} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ Ordre d'achat ajouté : {nb_1} entrepôts + {nb_2} pôle tabac & alcools.")
