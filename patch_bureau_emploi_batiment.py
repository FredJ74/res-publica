#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  'entrepot-logistique-luthecia': {
    name: "Entrepôt Logistique de Luthécia","""

new = """  'bureau-national-emploi': {
    name: "Bureau National de l'Emploi",
    shortName: "Bureau de l'Emploi",
    cat: "Économie",
    icon: "ti-briefcase",
    bgColor: "#0f1216",
    desc: "L'office national qui recense les demandeurs d'emploi et les offres disponibles. Votre avenir, notre mission.",
    rooms: {
      accueil: {
        name: "Accueil",
        imageBg: "linear-gradient(135deg,#0f1216,#161a20)",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-national-emploi-luthecia.png",
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

  'entrepot-logistique-luthecia': {
    name: "Entrepôt Logistique de Luthécia","""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """'entrepot-logistique-luthecia','usine-pharmaceutique-luthecia'],"""
new_2 = """'entrepot-logistique-luthecia','usine-pharmaceutique-luthecia','bureau-national-emploi'],"""
assert content.count(old_2) == 1, f"bloc liste : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bureau National de l'Emploi créé (2 salles) et ajouté à la liste active de Luthécia.")
