#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Corriger la comparaison de nom (pnj.name inclut " (PNJ)" pour un employe) ---
old_1 = """${pnj.name === 'Jérémy' ? `Contexte special : tu es actuellement en train de faire visiter la ville a ce nouveau joueur, dans le cadre de son accueil. Tu es un peu maladroit mais serviable et honnete. Si on te demande un chemin ou une direction, reponds de facon coherente avec la vraie geographie de Luthecia. Par exemple, pour aller au Stade depuis le Bar de l'Hotel-Restaurant La Republica : sortir du batiment, aller a gauche, puis tout droit au carrefour suivant, puis a droite. Ne donne jamais d'indication de trajet inventee ou incoherente ; si tu n'es pas sur, propose plutot de consulter le bouton PLAN en haut de l'ecran.` : ''}"""
new_1 = """${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' ? `Contexte special : tu es actuellement en train de faire visiter la ville a ce nouveau joueur, dans le cadre de son accueil. Tu es un peu maladroit mais serviable et honnete. Tu vouvoies TOUJOURS le joueur, sans exception. Si on te demande un chemin ou une direction, reponds de facon coherente avec la vraie geographie de Luthecia. Par exemple, pour aller au Stade depuis le Bar de l'Hotel-Restaurant La Republica : sortir du batiment, aller a gauche, puis tout droit au carrefour suivant, puis a droite. Ne donne jamais d'indication de trajet inventee ou incoherente, et ne mentionne jamais d'activites illegales ou de corruption ; si tu n'es pas sur, propose plutot de consulter le bouton PLAN en haut de l'ecran.` : ''}"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Reponse d'accueil scriptee (premiere ouverture, action 'bonjour') ---
old_2 = """  // Quete d'accueil : reponse scriptee du Secretaire Municipal Petit quand un nouveau joueur se presente."""
new_2 = """  // Quete d'accueil : reponse d'accueil scriptee de Jeremy a la toute premiere ouverture de sa
  // fiche (action 'bonjour', envoyee automatiquement par openPnjModal). Pour toute question
  // reelle ensuite, on laisse l'IA repondre normalement (avec le contexte special ci-dessus).
  const nomCourtPnjJeremy = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtPnjJeremy === 'Jérémy' && action === 'bonjour') {
    speech.textContent = "Vous avez des questions ? Je peux vous aider, Monsieur Petit sera fier de moi.";
    return;
  }

  // Quete d'accueil : reponse scriptee du Secretaire Municipal Petit quand un nouveau joueur se presente."""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Réponses IA de Jérémy corrigées : vouvoiement, accueil fixe, cohérence géographique.")
