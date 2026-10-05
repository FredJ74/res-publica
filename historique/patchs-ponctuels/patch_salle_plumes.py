#!/usr/bin/env python3
"""
Patch data.js : ajoute imageUrl a la salle salle_plumes du Musee de la Ville de Luthecia.
A executer a la racine du repo res-publica.
"""

PATH = "data.js"

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_plumes = """      salle_plumes: {
        name: "Salle des Plumes",
        imageBg: "linear-gradient(135deg,#181018,#221824)",
        desc: "Les plus belles diatribes, lettres ouvertes et recits qui ont marque la vie forumiale de Luthecia. Contenu a venir.",
        persons: [],
        orders: []
      },"""

new_plumes = """      salle_plumes: {
        name: "Salle des Plumes",
        imageBg: "linear-gradient(135deg,#181018,#221824)",
        desc: "Les plus belles diatribes, lettres ouvertes et recits qui ont marque la vie forumiale de Luthecia. Contenu a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-musee-luthecia.png",
        persons: [],
        orders: []
      },"""

assert content.count(old_plumes) == 1, f"salle_plumes : trouvé {content.count(old_plumes)} fois (attendu 1)"
content = content.replace(old_plumes, new_plumes)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Patch appliqué avec succès : imageUrl ajoutée pour salle_plumes (Musée de la Ville de Luthécia).")
