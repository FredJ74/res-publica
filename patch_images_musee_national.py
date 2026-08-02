#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """      salle_presidents: {
        name: "Salle des Présidents de Republia",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire presidentielle de la nation, ses meilleurs et ses pires chefs d'Etat. Classement a venir.",
        persons: [],
        orders: []
      },"""
new_1 = """      salle_presidents: {
        name: "Salle des Présidents de Republia",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire presidentielle de la nation, ses meilleurs et ses pires chefs d'Etat. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-presidents-musee-national.png",
        persons: [],
        orders: []
      },"""
assert content.count(old_1) == 1, f"bloc 1 (presidents) : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """      pantheon_national: {
        name: "Panthéon National",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Les personnalites les plus veneres du pays, toutes categories confondues. Classement a venir.",
        persons: [],
        orders: []
      },"""
new_2 = """      pantheon_national: {
        name: "Panthéon National",
        imageBg: "linear-gradient(135deg,#14181c,#1c2228)",
        desc: "Les personnalites les plus veneres du pays, toutes categories confondues. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/pantheon-national-musee-national.png",
        persons: [],
        orders: []
      },"""
assert content.count(old_2) == 1, f"bloc 2 (pantheon) : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Images ajoutées : Salle des Présidents + Panthéon National (Musée National).")
