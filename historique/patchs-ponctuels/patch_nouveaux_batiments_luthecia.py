#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Nouveaux noeuds : Usine Pharmaceutique (gauche) et Entrepot Logistique (droite) ---
old_1 = """    'luthecia-centre-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-multimodal.png',
      zones: [
        { xPct: [0, 100], nom: 'Centre Multimodal de Luthécia', type: 'batiment', buildingId: 'centre-multinodal-luthecia' }
      ],
      liens: { gauche: 'luthecia-quartier-ambassades', droite: 'luthecia-loge', toutDroit: null, arriere: 'luthecia-stade-multimodal' },
      flechesStyle: {"""
new_1 = """    'luthecia-usine-pharmaceutique': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/usine-pharmaceutique-luthecia.png',
      zones: [
        { xPct: [0, 100], nom: 'Usine Pharmaceutique Impériale de Républia', type: 'batiment', buildingId: 'usine-pharmaceutique-luthecia' }
      ],
      liens: { gauche: 'luthecia-quartier-ambassades', droite: 'luthecia-centre-multimodal', toutDroit: null, arriere: null }
    },

    'luthecia-entrepot-logistique': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/entrepot-logistique-luthecia.png',
      zones: [
        { xPct: [0, 100], nom: 'Entrepôt Logistique de Luthécia', type: 'batiment', buildingId: 'entrepot-logistique-luthecia' }
      ],
      liens: { gauche: 'luthecia-centre-multimodal', droite: 'luthecia-loge', toutDroit: null, arriere: null }
    },

    'luthecia-centre-multimodal': {
      image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/rue-centre-multimodal.png',
      zones: [
        { xPct: [0, 100], nom: 'Centre Multimodal de Luthécia', type: 'batiment', buildingId: 'centre-multinodal-luthecia' }
      ],
      liens: { gauche: 'luthecia-usine-pharmaceutique', droite: 'luthecia-entrepot-logistique', toutDroit: null, arriere: 'luthecia-stade-multimodal' },
      flechesStyle: {"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Quartier des Ambassades : droite pointe desormais vers l'Usine Pharmaceutique ---
old_2 = """      liens: { gauche: 'luthecia-terrains-artisanal', droite: 'luthecia-centre-multimodal', toutDroit: null, arriere: 'luthecia-musees' },"""
new_2 = """      liens: { gauche: 'luthecia-terrains-artisanal', droite: 'luthecia-usine-pharmaceutique', toutDroit: null, arriere: 'luthecia-musees' },"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Loge : droite pointe desormais vers l'Entrepot Logistique ---
old_3 = """      liens: { gauche: 'luthecia-hotel-de-ville', droite: 'luthecia-centre-multimodal', toutDroit: null, arriere: null }
    },"""
new_3 = """      liens: { gauche: 'luthecia-hotel-de-ville', droite: 'luthecia-entrepot-logistique', toutDroit: null, arriere: null }
    },"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Usine Pharmaceutique et Entrepôt Logistique insérés de part et d'autre du Centre Multimodal.")
