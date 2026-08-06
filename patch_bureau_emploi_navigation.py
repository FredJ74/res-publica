#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """    'luthecia-terrains-artisanal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-artisanal.png',
      zones: [
        // Debut de zone decale de 0 a 8% pour laisser un espace libre a la fleche gauche
        { xPct: [8, 60],   nom: 'Terrains à Bâtir',            type: 'noeud', noeudId: 'luthecia-terrains-lots' },
        { xPct: [60, 100], nom: 'Centre Artisanal de Luthécia', type: 'batiment', buildingId: 'centre-artisanal' }
      ],
      liens: { gauche: 'luthecia-armurerie', droite: 'luthecia-quartier-ambassades', toutDroit: null, arriere: 'luthecia-centre-commercial' },"""
new_1 = """    'luthecia-bureau-emploi': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/bureau-national-emploi-luthecia.png',
      zones: [
        { xPct: [0, 100], nom: "Bureau National de l'Emploi", type: 'batiment', buildingId: 'bureau-national-emploi' }
      ],
      liens: { gauche: 'luthecia-terrains-artisanal', droite: 'luthecia-quartier-ambassades', toutDroit: null, arriere: null }
    },

    'luthecia-terrains-artisanal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-terrains-artisanal.png',
      zones: [
        // Debut de zone decale de 0 a 8% pour laisser un espace libre a la fleche gauche
        { xPct: [8, 60],   nom: 'Terrains à Bâtir',            type: 'noeud', noeudId: 'luthecia-terrains-lots' },
        { xPct: [60, 100], nom: 'Centre Artisanal de Luthécia', type: 'batiment', buildingId: 'centre-artisanal' }
      ],
      liens: { gauche: 'luthecia-armurerie', droite: 'luthecia-bureau-emploi', toutDroit: null, arriere: 'luthecia-centre-commercial' },"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """      liens: { gauche: 'luthecia-terrains-artisanal', droite: 'luthecia-usine-pharmaceutique', toutDroit: null, arriere: 'luthecia-musees' },"""
new_2 = """      liens: { gauche: 'luthecia-bureau-emploi', droite: 'luthecia-usine-pharmaceutique', toutDroit: null, arriere: 'luthecia-musees' },"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bureau National de l'Emploi inséré entre Centre Artisanal et Quartier des Ambassades.")
