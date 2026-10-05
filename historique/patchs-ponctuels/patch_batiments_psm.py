#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  'entrepot-logistique-luthecia': {
    name: "Entrepôt Logistique de Luthécia","""

new = """  'pole-tabac-alcools-psm': {
    name: "Pôle Tabac & Alcools Sainte-Mariannaise",
    shortName: "Pôle Tabac & Alcools",
    cat: "Économie",
    icon: "ti-glass-full",
    bgColor: "#181410",
    desc: "L'entreprise stratégique de Port-Sainte-Marie. Distille l'alcool et manufacture le tabac, sous contrôle de l'État.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#181410,#221c15)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png",
        desc: "L'accueil et la salle de vente directe, alcools et tabac confondus.",
        persons: [],
        orders: []
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur du pôle. Accès sur rendez-vous.",
        persons: [],
        orders: []
      },
      distillerie: {
        name: "Distillerie",
        imageBg: "linear-gradient(135deg,#0a0d10,#12161a)",
        imageUrl: "https://images.unsplash.com/photo-1569529465841-dfecdab7503b?w=1200&q=80",
        desc: "Les alambics. Céréales et fruits livrés y sont distillés en alcool.",
        persons: [],
        orders: []
      },
      manufacture_tabac: {
        name: "Manufacture de Tabac",
        imageBg: "linear-gradient(135deg,#100d0a,#1a1512)",
        imageUrl: "https://images.unsplash.com/photo-1519669417670-68775a50919f?w=1200&q=80",
        desc: "Les lignes de manufacture. Les plantes livrées y sont transformées en tabac.",
        persons: [],
        orders: []
      }
    }
  },

  'entrepot-logistique-psm': {
    name: "Entrepôt Logistique de Sainte-Marie",
    shortName: "Entrepôt Logistique",
    cat: "Économie",
    icon: "ti-building-warehouse",
    bgColor: "#141210",
    desc: "L'entrepôt public de Port-Sainte-Marie. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png",
        desc: "Le quai de chargement et la salle des ventes. Le stock et les prix varient selon les livraisons du jour.",
        persons: [],
        orders: []
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'entrepôt. Accès sur rendez-vous.",
        persons: [],
        orders: []
      }
    }
  },

  'entrepot-logistique-luthecia': {
    name: "Entrepôt Logistique de Luthécia","""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','port-plaisance-psm','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11','stade','zone-production','capitaine-sauvage','chasse-peche-psm','place-armes-psm','ecole-marine','chantier-naval','notre-dame-mer','phare-psm','marche-psm','musee-port-sainte-marie'],"""
new_2 = """      buildings: ['hotel-port','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','bar-des-pecheurs','imprimerie-librairie','centre-multinodal-port-sainte-marie','port-sainte-marie','port-plaisance-psm','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-8','terrain-a-batir-9','terrain-a-batir-10','terrain-a-batir-11','stade','zone-production','capitaine-sauvage','chasse-peche-psm','place-armes-psm','ecole-marine','chantier-naval','notre-dame-mer','phare-psm','marche-psm','musee-port-sainte-marie','pole-tabac-alcools-psm','entrepot-logistique-psm'],"""
assert content.count(old_2) == 1, f"bloc liste : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Pôle Tabac & Alcools (4 salles) et Entrepôt Logistique de PSM créés et ajoutés à la liste.")
