#!/usr/bin/env python3
"""
Patch data.js : ajoute imageUrl aux salles salle_criminels et salle_maires
du Musée de la Ville de Luthécia.
À exécuter à la racine du repo res-publica.
"""
import re

PATH = "data.js"

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- Bloc salle_criminels (Musée de la Ville de Luthécia) ---
old_criminels = """      salle_criminels: {
        name: "Salle des Grands Criminels",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Portraits et affaires des malfrats les plus tristement celebres de Luthecia. Classement a venir.",
        persons: [],
        orders: []
      },"""

new_criminels = """      salle_criminels: {
        name: "Salle des Grands Criminels",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Portraits et affaires des malfrats les plus tristement celebres de Luthecia. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-musee-luthecia.png",
        persons: [],
        orders: []
      },"""

assert content.count(old_criminels) == 1, f"salle_criminels : trouvé {content.count(old_criminels)} fois (attendu 1)"
content = content.replace(old_criminels, new_criminels)

# --- Bloc salle_maires (Musée de la Ville de Luthécia) ---
old_maires = """      salle_maires: {
        name: "Salle des Maires de Luthécia",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire municipale de la ville, ses meilleurs et ses pires edeciles reunis dans la meme salle. Classement a venir.",
        persons: [],
        orders: []
      },"""

new_maires = """      salle_maires: {
        name: "Salle des Maires de Luthécia",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "L'histoire municipale de la ville, ses meilleurs et ses pires edeciles reunis dans la meme salle. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-musee-luthecia.png",
        persons: [],
        orders: []
      },"""

assert content.count(old_maires) == 1, f"salle_maires : trouvé {content.count(old_maires)} fois (attendu 1)"
content = content.replace(old_maires, new_maires)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Patch appliqué avec succès : imageUrl ajoutée pour salle_criminels et salle_maires (Musée de la Ville de Luthécia).")
