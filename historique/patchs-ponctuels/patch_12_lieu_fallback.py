#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = "IMPORTANT : fie-toi UNIQUEMENT au \"Lieu actuel\" indique plus haut (${lieuTexte}) pour savoir ou vous etes reellement. Ne dis JAMAIS que vous etes encore a l'Hotel de Ville, ou a un autre endroit deja visite plus tot dans la visite, si le lieu actuel indique autre chose."
new = "IMPORTANT : fie-toi UNIQUEMENT au \"Lieu actuel\" indique plus haut pour savoir ou vous etes reellement. Ne dis JAMAIS que vous etes encore a l'Hotel de Ville, ou a un autre endroit deja visite plus tot dans la visite, si le lieu actuel indique autre chose. Si AUCUN lieu actuel n'est indique plus haut (vous etes dans la rue, pas dans un batiment), ne devine JAMAIS un nom de lieu precis (n'invente jamais \"Place de la Concorde\" ou autre) : dis simplement que vous etes ensemble dans la rue et propose de consulter le bouton PLAN, en haut de l'ecran, pour s'orienter."
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Jérémy n'invente plus de lieu quand aucun bâtiment n'est indiqué (rue).")
