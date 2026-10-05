#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

ordre_vente_directe = "[{fn:'vente_directe_usine', label:'Vente directe', pa:1, cost:0, type:'legal', icon:'ti-cash-register', successRate:100, desc:'Acheter la production locale, disponible en quantité limitée.'}]"

# --- 1. Corriger le Pole Tabac & Alcools (avait par erreur l'ordre d'achat de l'entrepot) ---
old_1 = """        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]"""
new_1 = """        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: """ + ordre_vente_directe
assert content.count(old_1) == 1, f"pole tabac (correction) : trouvé {content.count(old_1)}"
content = content.replace(old_1, new_1)

# --- 2. Usine Pharmaceutique de Luthecia ---
old_2 = """        desc: "L'accueil et la salle de vente directe des médicaments produits sur place.",
        persons: [],
        orders: []"""
new_2 = """        desc: "L'accueil et la salle de vente directe des médicaments produits sur place.",
        persons: [],
        orders: """ + ordre_vente_directe
assert content.count(old_2) == 1, f"pharma : trouvé {content.count(old_2)}"
content = content.replace(old_2, new_2)

# --- 3. Raffinerie de Montrouge ---
old_3 = """        desc: "L'accueil et la salle de vente directe du carburant produit sur place.",
        persons: [],
        orders: []"""
new_3 = """        desc: "L'accueil et la salle de vente directe du carburant produit sur place.",
        persons: [],
        orders: """ + ordre_vente_directe
assert content.count(old_3) == 1, f"raffinerie : trouvé {content.count(old_3)}"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Vente directe branchée aux 3 usines (Pôle Tabac & Alcools corrigé, Pharma, Raffinerie).")
