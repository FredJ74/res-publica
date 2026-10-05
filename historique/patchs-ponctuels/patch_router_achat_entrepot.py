#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

ordre_achat = """[{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]"""

anchors = [
    """        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: []""",
    """        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: []""",
]

count_total = 0
for anchor in anchors:
    old = anchor
    new = anchor.replace("orders: []", "orders: " + ordre_achat)
    nb = content.count(old)
    assert nb == 1, f"trouvé {nb} fois (attendu 1) pour : {old[:60]}..."
    content = content.replace(old, new)
    count_total += 1

# Montrouge et le 3e entrepot (repartis differemment, meme desc "quai de chargement")
old_generique = """        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: []"""
nb_restant = content.count(old_generique)
if nb_restant > 0:
    new_generique = old_generique.replace("orders: []", "orders: " + ordre_achat)
    content = content.replace(old_generique, new_generique)
    count_total += nb_restant

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"✅ Ordre d'achat ajouté à {count_total} salle(s) des ventes d'entrepôt/pôle transformateur.")
