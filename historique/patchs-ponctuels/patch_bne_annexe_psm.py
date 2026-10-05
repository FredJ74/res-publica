#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """          roomOverrides: {
            zone_recolte: {
              name: "Atelier",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/atelier-scierie-guy-tarembois-psm.png"
            }
          }
        },
        'stade': {"""

new = """          roomOverrides: {
            zone_recolte: {
              name: "Atelier",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/atelier-scierie-guy-tarembois-psm.png"
            }
          }
        },
        'centre-affaires': {
          // Annexe du Bureau National de l'Emploi, propre a PSM (voir roomsExtra,
          // plateau-navigation.js). Simple salle, pas de mecanique dediee pour l'instant.
          roomsExtra: {
            bureau_emploi_annexe: {
              name: "Bureau National de l'Emploi (Annexe)",
              imageBg: "linear-gradient(135deg,#0f1216,#161a20)",
              imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-emploi-annexe-psm.png",
              desc: "L'antenne locale du Bureau National de l'Emploi de Républia. Offres d'emploi, accompagnement, formation.",
              persons: [],
              orders: []
            }
          }
        },
        'stade': {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Annexe du Bureau National de l'Emploi ajoutée au Centre d'Affaires de PSM uniquement (via roomsExtra).")
