#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  'centre-multinodal-luthecia': {
    name: "Centre Multinodal de Luthecia","""

new = """  'entrepot-logistique-luthecia': {
    name: "Entrepôt Logistique de Luthécia",
    shortName: "Entrepôt Logistique",
    cat: "Économie",
    icon: "ti-building-warehouse",
    bgColor: "#141210",
    desc: "L'entrepôt public de Luthécia. Réceptionne les livraisons quotidiennes de matières premières et les revend aux commerces de la ville.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#141210,#1c1815)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-logistique-luthecia.png",
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

  'usine-pharmaceutique-luthecia': {
    name: "Usine Pharmaceutique Impériale de Républia",
    shortName: "Usine Pharmaceutique",
    cat: "Économie",
    icon: "ti-vaccine",
    bgColor: "#101418",
    desc: "L'entreprise stratégique pharmaceutique de Républia. Transforme les plantes récoltées en médicaments, sous contrôle de l'État.",
    rooms: {
      salle_ventes: {
        name: "Salle des Ventes",
        imageBg: "linear-gradient(135deg,#101418,#161c22)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/usine-pharmaceutique-luthecia.png",
        desc: "L'accueil et la salle de vente directe des médicaments produits sur place.",
        persons: [],
        orders: []
      },
      bureau_direction: {
        name: "Bureau de Direction",
        imageBg: "linear-gradient(135deg,#0f1510,#141c14)",
        imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80",
        desc: "Le bureau du directeur de l'usine. Accès sur rendez-vous.",
        persons: [],
        orders: []
      },
      salle_production: {
        name: "Salle de Production",
        imageBg: "linear-gradient(135deg,#0a0d10,#12161a)",
        imageUrl: "https://images.unsplash.com/photo-1581093458791-9d42e3c9f2c1?w=1200&q=80",
        desc: "Les lignes de production. Les plantes livrées y sont transformées en médicaments.",
        persons: [],
        orders: []
      }
    }
  },

  'centre-multinodal-luthecia': {
    name: "Centre Multinodal de Luthecia","""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Entrepôt Logistique (2 salles) et Usine Pharmaceutique (3 salles) créés.")
