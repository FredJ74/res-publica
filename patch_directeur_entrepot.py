#!/usr/bin/env python3
# Tableau de bord du directeur d'entrepot PJ — meme principe que le directeur d'usine
# (commit precedent), mais nomme par le Maire (poste local, un seul id 'directeur_entrepot'
# reutilise dans les 3 villes via scope:'ville', comme le commissaire) plutot que par le
# Ministre des Finances. Bouton de nomination place dans l'entrepot lui-meme, comme pour
# l'usine.
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

remplacements = [
    # --- Entrepot Logistique de Montrouge ---
    ("""    desc: "L'entrepôt public de Montrouge. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://images.unsplash.com/photo-1553413077-190dd305871c?w=1200&q=80",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [],
        orders: []
      }""",
     """    desc: "L'entrepôt public de Montrouge. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://images.unsplash.com/photo-1553413077-190dd305871c?w=1200&q=80",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [{name:'Norbert Charton (PNJ)', role:"Directeur de l'Entrepôt Logistique", rel:'neutral', job:'directeur_entrepot'}],
        orders: [
          {fn:'nommer_directeur_entrepot', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'maire', desc:"Nommer un PJ directeur de l'entrepôt. Poste exclusif (sauf député)."},
          {fn:'fixer_prix_achat_entrepot', label:"Fixer les prix d'achat", pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_entrepot', desc:"Fixer le prix de chaque ressource vendue à l'entrepôt, dans la fourchette autorisée (±40% du prix de base)."}
        ]
      }"""),
    # --- Entrepot Logistique de Port-Sainte-Marie ---
    ("""    desc: "L'entrepôt public de Port-Sainte-Marie. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [],
        orders: []
      }""",
     """    desc: "L'entrepôt public de Port-Sainte-Marie. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: [{fn:'acheter_ressources_entrepot', label:'Acheter des ressources', pa:1, cost:0, type:'legal', icon:'ti-shopping-cart', successRate:100, desc:'Choisir les ressources et quantités à acheter, selon le stock et le prix du moment.'}]
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [{name:'Yvon Paletier (PNJ)', role:"Directeur de l'Entrepôt Logistique", rel:'neutral', job:'directeur_entrepot'}],
        orders: [
          {fn:'nommer_directeur_entrepot', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'maire', desc:"Nommer un PJ directeur de l'entrepôt. Poste exclusif (sauf député)."},
          {fn:'fixer_prix_achat_entrepot', label:"Fixer les prix d'achat", pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_entrepot', desc:"Fixer le prix de chaque ressource vendue à l'entrepôt, dans la fourchette autorisée (±40% du prix de base)."}
        ]
      }"""),
    # --- Entrepot Logistique de Luthecia ---
    ("""        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-entrepot-luthecia.png",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [],
        orders: []
      }""",
     """        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-direction-entrepot-luthecia.png",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [{name:'Marcel Silo (PNJ)', role:"Directeur de l'Entrepôt Logistique", rel:'neutral', job:'directeur_entrepot'}],
        orders: [
          {fn:'nommer_directeur_entrepot', label:'Nommer un directeur', pa:3, cost:0, type:'legal', icon:'ti-user-star', successRate:100, requiresPost:'maire', desc:"Nommer un PJ directeur de l'entrepôt. Poste exclusif (sauf député)."},
          {fn:'fixer_prix_achat_entrepot', label:"Fixer les prix d'achat", pa:1, cost:0, type:'legal', icon:'ti-tag', successRate:100, requiresPost:'directeur_entrepot', desc:"Fixer le prix de chaque ressource vendue à l'entrepôt, dans la fourchette autorisée (±40% du prix de base)."}
        ]
      }"""),
]

for old, new in remplacements:
    nb = content.count(old)
    assert nb == 1, f"trouvé {nb} fois (attendu 1) pour : {old[:70]}..."
    content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ PNJ + ordres du tableau de bord directeur ajoutés aux 3 bureaux de direction des entrepôts.")
