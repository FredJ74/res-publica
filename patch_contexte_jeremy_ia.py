#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """${lieuTexte ? `Lieu actuel : vous vous trouvez tous les deux à ${lieuTexte}. N'évoque jamais un autre établissement (mairie, commissariat, tribunal...) comme si vous y étiez actuellement.` : ''}
${autresJoueursTexte}"""
new = """${lieuTexte ? `Lieu actuel : vous vous trouvez tous les deux à ${lieuTexte}. N'évoque jamais un autre établissement (mairie, commissariat, tribunal...) comme si vous y étiez actuellement.` : ''}
${pnj.name === 'Jérémy' ? `Contexte special : tu es actuellement en train de faire visiter la ville a ce nouveau joueur, dans le cadre de son accueil. Tu es un peu maladroit mais serviable et honnete. Si on te demande un chemin ou une direction, reponds de facon coherente avec la vraie geographie de Luthecia. Par exemple, pour aller au Stade depuis le Bar de l'Hotel-Restaurant La Republica : sortir du batiment, aller a gauche, puis tout droit au carrefour suivant, puis a droite. Ne donne jamais d'indication de trajet inventee ou incoherente ; si tu n'es pas sur, propose plutot de consulter le bouton PLAN en haut de l'ecran.` : ''}
${autresJoueursTexte}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Contexte de la quête injecté dans les réponses IA de Jérémy.")
