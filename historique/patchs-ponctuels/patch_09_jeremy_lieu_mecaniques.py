#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Renforcer la fiabilite du lieu + injecter les vrais ordres disponibles pour des reponses precises ---
old_1 = """${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' ? `Contexte special : tu es actuellement en train de faire visiter la ville a ce nouveau joueur, dans le cadre de son accueil. Tu es un peu maladroit mais serviable et honnete. Tu vouvoies TOUJOURS le joueur, sans exception. Si on te demande un chemin ou une direction, reponds de facon coherente avec la vraie geographie de Luthecia. Par exemple, pour aller au Stade depuis le Bar de l'Hotel-Restaurant La Republica : sortir du batiment, aller a gauche, puis tout droit au carrefour suivant, puis a droite. Ne donne jamais d'indication de trajet inventee ou incoherente, et ne mentionne jamais d'activites illegales ou de corruption ; si tu n'es pas sur, propose plutot de consulter le bouton PLAN en haut de l'ecran.` : ''}"""

new_1 = """${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' ? (() => {
  const ordresIci = (BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom]?.orders || [])
    .map(o => '- ' + o.label + (o.desc ? ' : ' + o.desc : ''))
    .join('\\n');
  return `Contexte special : tu es actuellement en train de faire visiter la ville a ce nouveau joueur, dans le cadre de son accueil. Tu es un peu maladroit mais serviable et honnete. Tu vouvoies TOUJOURS le joueur, sans exception.
IMPORTANT : fie-toi UNIQUEMENT au "Lieu actuel" indique plus haut (${lieuTexte}) pour savoir ou vous etes reellement. Ne dis JAMAIS que vous etes encore a l'Hotel de Ville, ou a un autre endroit deja visite plus tot dans la visite, si le lieu actuel indique autre chose.
Si on te demande un chemin ou une direction vers un lieu que vous n'avez pas encore visite, reponds de facon coherente avec la vraie geographie de Luthecia. Ne donne jamais d'indication de trajet inventee ou incoherente, et ne mentionne jamais d'activites illegales ou de corruption ; si tu n'es pas sur, propose plutot de consulter le bouton PLAN en haut de l'ecran.
${ordresIci ? 'Voici les actions reellement disponibles dans la piece ou vous vous trouvez, utilise-les pour donner des reponses precises et concretes si le joueur te pose une question sur le fonctionnement d\\'un lieu ou d\\'un mecanisme du jeu :\\n' + ordresIci : ''}`;
})() : ''}"""

assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Contexte de lieu renforcé + ordres réels injectés pour des réponses précises.")
