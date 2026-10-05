#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  'bureau-national-emploi': {
    name: "Bureau National de l'Emploi","""

new = """  'entrepot-logistique-montrouge': {
    name: "Entrepôt Logistique de Montrouge",
    shortName: "Entrepôt Logistique",
    cat: "Économie",
    icon: "ti-building-warehouse",
    bgColor: "#141210",
    desc: "L'entrepôt public de Montrouge. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://images.unsplash.com/photo-1553413077-190dd305871c?w=1200&q=80",
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

  'raffinerie-montrouge': {
    name: "Raffinerie Impériale de Montrouge",
    shortName: "Raffinerie",
    cat: "Économie",
    icon: "ti-droplet",
    bgColor: "#181410",
    desc: "L'entreprise stratégique pétrolière de Montrouge. Raffine le pétrole brut en carburant, sous contrôle de l'État.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#181410,#221c15)",
        imageUrl: "https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1200&q=80",
        desc: "L'accueil et la salle de vente directe du carburant produit sur place.",
        persons: [],
        orders: []
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de la raffinerie. Accès sur rendez-vous.",
        persons: [],
        orders: []
      },
      salle_production: {
        name: "Salle de Production",
        imageBg: "linear-gradient(135deg,#0a0d10,#12161a)",
        imageUrl: "https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1200&q=80",
        desc: "Les installations de raffinage. Le pétrole brut livré y est transformé en carburant.",
        persons: [],
        orders: []
      }
    }
  },

  'bureau-national-emploi-montrouge': {
    name: "Bureau National de l'Emploi — Montrouge",
    shortName: "Bureau de l'Emploi",
    cat: "Économie",
    icon: "ti-briefcase",
    bgColor: "#0f1216",
    desc: "L'office national qui recense les demandeurs d'emploi et les offres disponibles. Votre avenir, notre mission.",
    rooms: {
      accueil: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#0f1216,#161a20)",
        imageUrl: "https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&q=80",
        desc: "Le hall d'accueil du Bureau National de l'Emploi. Offres d'emploi, accompagnement, formation, création d'activité.",
        persons: [],
        orders: []
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'office. Accès sur rendez-vous.",
        persons: [],
        orders: []
      }
    }
  },

  'bureau-national-emploi': {
    name: "Bureau National de l'Emploi","""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """      desc:'Ville industrielle au nord. Syndicats puissants, usines et tensions sociales.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production'],"""
new_2 = """      desc:'Ville industrielle au nord. Syndicats puissants, usines et tensions sociales.',
      isCapitale: false,
      buildings: ['hotel-mineur','mairie','banque-locale','dispensaire-public-v','commissariat-local','tribunal-local','siege-syndical','usine-principale','centre-multinodal-montrouge','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-3','stade','zone-production','entrepot-logistique-montrouge','raffinerie-montrouge','bureau-national-emploi-montrouge'],"""
assert content.count(old_2) == 1, f"bloc liste : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Entrepôt Logistique, Raffinerie et Bureau de l'Emploi de Montrouge créés et ajoutés à la liste.")
