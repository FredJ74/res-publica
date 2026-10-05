#!/usr/bin/env python3
# Tableau de bord du directeur PJ (Pharma / Tabac & Alcools / Raffinerie) :
# - un PNJ par defaut occupe le bureau de direction tant qu'aucun PJ n'est nomme
#   (masque automatiquement des qu'un PJ est nomme, via POSTES_UNIQUES_A_MASQUER)
# - 2 nouveaux ordres reserves au directeur en poste : fixer librement les prix de la
#   vente directe, et repartir la production entre entrepots et vente directe sur place
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

remplacements = [
    # --- Usine Pharmaceutique de Luthecia ---
    ("""        desc: "Le bureau du directeur de l'usine. Accès sur rendez-vous.",
        persons: [],
        orders: [{fn:'nommer_directeur_pharma', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de l\\'Usine Pharmaceutique. Poste exclusif (sauf député).'}]""",
     """        desc: "Le bureau du directeur de l'usine. Accès sur rendez-vous.",
        persons: [{name:'Bernard Piluler (PNJ)', role:"Directeur de l'Usine Pharmaceutique", rel:'neutral', job:'directeur_pharma'}],
        orders: [
          {fn:'nommer_directeur_pharma', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de l\\'Usine Pharmaceutique. Poste exclusif (sauf député).'},
          {fn:'fixer_prix_vente_directe', label:'Fixer les prix de vente', pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_pharma', desc:'Définir librement le prix de chaque produit vendu en vente directe, à la place du prix automatique.'},
          {fn:'fixer_repartition_production', label:'Répartir la production', pa:1, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'directeur_pharma', desc:'Choisir la part de la production quotidienne envoyée aux entrepôts publics (le reste part en vente directe sur place).'}
        ]"""),
    # --- Pole Tabac & Alcools de Port-Sainte-Marie ---
    ("""        desc: "Le bureau du directeur du pôle. Accès sur rendez-vous.",
        persons: [],
        orders: [{fn:'nommer_directeur_tabac_alcools', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur du Pôle Tabac & Alcools. Poste exclusif (sauf député).'}]""",
     """        desc: "Le bureau du directeur du pôle. Accès sur rendez-vous.",
        persons: [{name:'Fernand Cendrier (PNJ)', role:'Directeur du Pôle Tabac & Alcools', rel:'neutral', job:'directeur_tabac_alcools'}],
        orders: [
          {fn:'nommer_directeur_tabac_alcools', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur du Pôle Tabac & Alcools. Poste exclusif (sauf député).'},
          {fn:'fixer_prix_vente_directe', label:'Fixer les prix de vente', pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_tabac_alcools', desc:'Définir librement le prix de chaque produit vendu en vente directe, à la place du prix automatique.'},
          {fn:'fixer_repartition_production', label:'Répartir la production', pa:1, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'directeur_tabac_alcools', desc:'Choisir la part de la production quotidienne envoyée aux entrepôts publics (le reste part en vente directe sur place).'}
        ]"""),
    # --- Raffinerie de Montrouge ---
    ("""        desc: "Le bureau du directeur de la raffinerie. Accès sur rendez-vous.",
        persons: [],
        orders: [{fn:'nommer_directeur_raffinerie', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de la raffinerie. Poste exclusif (sauf député).'}]""",
     """        desc: "Le bureau du directeur de la raffinerie. Accès sur rendez-vous.",
        persons: [{name:'Gustave Baril (PNJ)', role:'Directeur de la Raffinerie', rel:'neutral', job:'directeur_raffinerie'}],
        orders: [
          {fn:'nommer_directeur_raffinerie', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'min_fin', desc:'Nommer un PJ directeur de la raffinerie. Poste exclusif (sauf député).'},
          {fn:'fixer_prix_vente_directe', label:'Fixer les prix de vente', pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_raffinerie', desc:'Définir librement le prix de chaque produit vendu en vente directe, à la place du prix automatique.'},
          {fn:'fixer_repartition_production', label:'Répartir la production', pa:1, cost:0, type:'legal', icon:'ti-adjustments', successRate:100, requiresPost:'directeur_raffinerie', desc:'Choisir la part de la production quotidienne envoyée aux entrepôts publics (le reste part en vente directe sur place).'}
        ]"""),
]

for old, new in remplacements:
    nb = content.count(old)
    assert nb == 1, f"trouvé {nb} fois (attendu 1) pour : {old[:70]}..."
    content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ PNJ + ordres du tableau de bord directeur ajoutés aux 3 bureaux de direction.")
