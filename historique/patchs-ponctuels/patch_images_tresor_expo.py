#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """      salle_tresor_national: {
        name: "Salle du Trésor National",
        imageBg: "linear-gradient(135deg,#181008,#221408)",
        desc: "Regalia, objets d'Etat et symboles du pouvoir. Contenu a venir.",
        persons: [],
        orders: []
      },"""
new_1 = """      salle_tresor_national: {
        name: "Salle du Trésor National",
        imageBg: "linear-gradient(135deg,#181008,#221408)",
        desc: "Regalia, objets d'Etat et symboles du pouvoir. Acces strictement interdit — zone sous haute protection, surveillance 24h/24.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/tresor-national-musee-national.png",
        persons: [],
        orders: []
      },"""
assert content.count(old_1) == 1, f"tresor : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """      expositions_temporaires: {
        name: "Expositions Temporaires",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Une salle dediee aux expositions ponctuelles du musee. Contenu a venir.",
        persons: [],
        orders: []
      },"""
new_2 = """      expositions_temporaires: {
        name: "Expositions Temporaires",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Une salle dediee aux expositions ponctuelles du musee. Contenu a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/expositions-temporaires-musee-national.png",
        persons: [],
        orders: []
      },"""
assert content.count(old_2) == 1, f"expo : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Images ajoutées : Trésor National + Expositions Temporaires.")
