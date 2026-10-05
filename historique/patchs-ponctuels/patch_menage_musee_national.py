#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Supprimer salle_peres_fondateurs ---
old_1 = """      salle_peres_fondateurs: {
        name: "Salle des Pères Fondateurs",
        imageBg: "linear-gradient(135deg,#14100a,#1c1610)",
        desc: "Les figures historiques a l'origine de la nation. Contenu a venir.",
        persons: [],
        orders: []
      },
"""
assert content.count(old_1) == 1, f"peres_fondateurs : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, "")

# --- 2. Transformer pantheon_national en Expositions Temporaires ---
old_2 = """      pantheon_national: {
        name: "Panthéon National",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Les personnalites les plus veneres du pays, toutes categories confondues. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/pantheon-national-musee-national.png",
        persons: [],
        orders: []
      },"""
new_2 = """      expositions_temporaires: {
        name: "Expositions Temporaires",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Une salle dediee aux expositions ponctuelles du musee. Contenu a venir.",
        persons: [],
        orders: []
      },"""
assert content.count(old_2) == 1, f"pantheon : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Supprimer salle_relations_diplomatiques ---
old_3 = """      salle_relations_diplomatiques: {
        name: "Salle des Relations Diplomatiques",
        imageBg: "linear-gradient(135deg,#0e1418,#141c22)",
        desc: "Traites, alliances et tensions entre empires. Contenu a venir.",
        persons: [],
        orders: []
      },
"""
assert content.count(old_3) == 1, f"relations_diplomatiques : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, "")

# --- 4. Supprimer salle_scandales_etat ---
old_4 = """      salle_scandales_etat: {
        name: "Salle des Scandales d'État",
        imageBg: "linear-gradient(135deg,#100c10,#181018)",
        desc: "Les plus grandes affaires politiques nationales. Classement a venir.",
        persons: [],
        orders: []
      },
"""
assert content.count(old_4) == 1, f"scandales_etat : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, "")

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ménage effectué : 3 salles supprimées, Panthéon transformé en Expositions Temporaires.")
