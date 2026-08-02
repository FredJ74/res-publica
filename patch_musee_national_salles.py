#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

ORDRE_STD = "        orders: [\n          {fn:'consulter_personnalites_musee', label:'Consulter les personnalités', pa:0, cost:0, type:'legal', icon:'ti-users', successRate:100, desc:'Voir les figures marquantes de cette salle.'}\n        ]\n"

# --- 1. Mettre a jour les 3 salles existantes (image + ordre) ---
old_1 = """      salle_reussites_economiques: {
        name: "Salle des Grandes Réussites Économiques",
        imageBg: "linear-gradient(135deg,#141c14,#1c2818)",
        desc: "Les plus grandes fortunes et entreprises a l'echelle nationale. Classement a venir.",
        persons: [],
        orders: []
      },"""
new_1 = """      salle_reussites_economiques: {
        name: "Salle des Grandes Réussites Économiques",
        imageBg: "linear-gradient(135deg,#141c14,#1c2818)",
        desc: "Les plus grandes fortunes et entreprises a l'echelle nationale.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-economie-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      },"""
assert content.count(old_1) == 1, f"bloc 1 (economie) : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """      salle_honneur_militaire_nationale: {
        name: "Salle d'Honneur Militaire Nationale",
        imageBg: "linear-gradient(135deg,#141410,#201f18)",
        desc: "Les plus grands faits d'armes a l'echelle du pays. Classement a venir.",
        persons: [],
        orders: []
      },"""
new_2 = """      salle_honneur_militaire_nationale: {
        name: "Salle d'Honneur Militaire Nationale",
        imageBg: "linear-gradient(135deg,#141410,#201f18)",
        desc: "Les plus grands faits d'armes a l'echelle du pays.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-militaires-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      },
      salle_politiques: {
        name: "Salle des Personnalités Politiques",
        imageBg: "linear-gradient(135deg,#181408,#221c0c)",
        desc: "Ministres, députés et diplomates ayant marqué l'histoire nationale (hors présidents et maires).",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-politiques-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      },
      salle_civils_intellectuels: {
        name: "Salle des Personnalités Civiles et Intellectuelles",
        imageBg: "linear-gradient(135deg,#14100c,#1c1810)",
        desc: "Universitaires, philosophes, journalistes et chercheurs ayant marqué le pays.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-civils-intellectuels-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      },
      salle_organisations: {
        name: "Salle des Responsables d'Organisations Syndicales ou Religieuses",
        imageBg: "linear-gradient(135deg,#181008,#221408)",
        desc: "Figures religieuses, syndicales et de loges ayant marqué le pays.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-organisations-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      },
      salle_artistes_sportifs: {
        name: "Salle des Artistes et Sportifs",
        imageBg: "linear-gradient(135deg,#101418,#181c22)",
        desc: "Compositeurs, sculpteurs, champions et figures populaires du sport national.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-artistes-sportifs-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      },"""
assert content.count(old_2) == 1, f"bloc 2 (militaire + 4 nouvelles salles) : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """      salle_criminels_pays: {
        name: "Salle des Plus Grands Criminels du Pays",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Les plus grands criminels de chaque ville du pays entrent en competition pour le titre de plus grand criminel de la nation. Classement a venir.",
        persons: [],
        orders: []
      }
    }
  },

  'place-formulaire-liberte': {"""
new_3 = """      salle_criminels_pays: {
        name: "Salle des Plus Grands Criminels du Pays",
        imageBg: "linear-gradient(135deg,#1a0d0d,#241010)",
        desc: "Les plus grands criminels de chaque ville du pays entrent en competition pour le titre de plus grand criminel de la nation. Classement a venir.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-musee-national.png",
        persons: [],
""" + ORDRE_STD + """      }
    }
  },

  'place-formulaire-liberte': {"""
assert content.count(old_3) == 1, f"bloc 3 (criminels) : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 7 salles du Musée National complétées (4 nouvelles créées, 3 mises à jour).")
