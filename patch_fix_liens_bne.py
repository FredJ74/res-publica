#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      liens: { gauche: 'luthecia-terrains-artisanal', droite: 'luthecia-quartier-ambassades', toutDroit: null, arriere: null }
    },

    'luthecia-terrains-artisanal': {"""
new = """      liens: { gauche: null, droite: null, toutDroit: 'luthecia-quartier-ambassades', arriere: 'luthecia-terrains-artisanal' }
    },

    'luthecia-terrains-artisanal': {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Liens du BNE corrigés : Quartier des Ambassades en 'tout droit' (nord), Terrains Artisanal en 'arrière' (sud).")
