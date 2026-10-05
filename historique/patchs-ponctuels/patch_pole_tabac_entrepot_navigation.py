#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    'psm-terrains-vente': {
      // 'psm-terrains-lots' est un PLACEHOLDER (sous-scene des 5 lots, pas encore codee,
      // sur le modele de 'luthecia-terrains-lots').
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-vente-psm.png',
      zones: [
        { xPct: [55, 95], nom: 'Terrains à Bâtir', type: 'noeud', noeudId: 'psm-terrains-lots' }
      ],
      liens: { droite: 'psm-carrefour-artisanal-scierie', arriere: 'psm-chantier-naval' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },"""

new = """    'psm-terrains-vente': {
      // 'psm-terrains-lots' est un PLACEHOLDER (sous-scene des 5 lots, pas encore codee,
      // sur le modele de 'luthecia-terrains-lots').
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-vente-psm.png',
      zones: [
        { xPct: [55, 95], nom: 'Terrains à Bâtir', type: 'noeud', noeudId: 'psm-terrains-lots' }
      ],
      liens: { droite: 'psm-pole-tabac-entrepot', arriere: 'psm-chantier-naval' },
      flechesStyle: { arriere: 'bottom:10px; left:50%; transform:translateX(-50%);' }
    },

    'psm-pole-tabac-entrepot': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-pole-tabac-psm.png',
      zones: [
        { xPct: [0, 45],   nom: 'Pôle Tabac & Alcools Sainte-Mariannaise', type: 'batiment', buildingId: 'pole-tabac-alcools-psm' },
        { xPct: [55, 100], nom: 'Entrepôt Logistique de Sainte-Marie',     type: 'batiment', buildingId: 'entrepot-logistique-psm' }
      ],
      liens: { gauche: 'psm-terrains-vente', droite: 'psm-carrefour-artisanal-scierie', toutDroit: null, arriere: null }
    },"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Pôle Tabac & Alcools + Entrepôt Logistique de PSM insérés entre les Terrains à Bâtir et le carrefour de la Scierie.")
