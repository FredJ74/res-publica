#!/usr/bin/env python3
# 7 PNJ par defaut manquants pour la cascade de nomination automatique (President + les 6
# ministres) — voir plan du 8 aout 2026. Convention reprise du Maire : nom generique
# "Le [Poste] (PNJ)", pas de nom propre (reserve aux postes economiques).
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

remplacements = [
    # --- President ---
    ("""        persons: [
          {name:'Huguette Papier (PNJ)', role:'PNJ - Secretaire general de la presidence', rel:'neutral', job:'secretaire_general', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/huguette-papier.png', photoPos:'50% 15%'}
        ],""",
     """        persons: [
          {name:'Le Président (PNJ)', role:'PNJ - Président de la République', rel:'neutral', job:'president'},
          {name:'Huguette Papier (PNJ)', role:'PNJ - Secretaire general de la presidence', rel:'neutral', job:'secretaire_general', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/huguette-papier.png', photoPos:'50% 15%'}
        ],"""),
    # --- Ministre de l'Interieur ---
    ("""        requiresPostId: 'min_int',
        persons: [],""",
     """        requiresPostId: 'min_int',
        persons: [{name:"Le Ministre de l'Intérieur (PNJ)", role:'PNJ - Ministre de l\\'Interieur', rel:'neutral', job:'min_int'}],"""),
    # --- Ministre des Finances ---
    ("""        requiresPostId: 'min_fin',
        persons: [],""",
     """        requiresPostId: 'min_fin',
        persons: [{name:'Le Ministre des Finances (PNJ)', role:'PNJ - Ministre des Finances', rel:'neutral', job:'min_fin'}],"""),
    # --- Ministre de la Justice ---
    ("""        requiresPostId: 'min_just',
        persons: [],""",
     """        requiresPostId: 'min_just',
        persons: [{name:'Le Ministre de la Justice (PNJ)', role:'PNJ - Ministre de la Justice', rel:'neutral', job:'min_just'}],"""),
    # --- Ministre de la Defense ---
    ("""        requiresPostId: 'min_def',
        persons: [],""",
     """        requiresPostId: 'min_def',
        persons: [{name:'Le Ministre de la Défense (PNJ)', role:'PNJ - Ministre de la Defense', rel:'neutral', job:'min_def'}],"""),
    # --- Ministre de l'Information ---
    ("""        requiresPostId: 'min_info',
        persons: [],""",
     """        requiresPostId: 'min_info',
        persons: [{name:"Le Ministre de l'Information (PNJ)", role:"PNJ - Ministre de l'Information", rel:'neutral', job:'min_info'}],"""),
    # --- Ministre des Affaires Etrangeres ---
    ("""        requiresPostId: 'min_ae',
        persons: [],""",
     """        requiresPostId: 'min_ae',
        persons: [{name:'Le Ministre des Affaires Étrangères (PNJ)', role:'PNJ - Ministre des Affaires Etrangeres', rel:'neutral', job:'min_ae'}],"""),
]

for old, new in remplacements:
    nb = content.count(old)
    assert nb == 1, f"trouvé {nb} fois (attendu 1) pour : {old[:70]}..."
    content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 7 PNJ par défaut créés (Président + les 6 ministres) pour la cascade de nomination automatique.")
