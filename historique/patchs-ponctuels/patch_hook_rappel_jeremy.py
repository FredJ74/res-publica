#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  const nomCourtPnjJeremy = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtPnjJeremy === 'Jérémy' && action === 'bonjour') {
    speech.textContent = "Vous avez des questions ? Je peux vous aider, Monsieur Petit sera fier de moi.";
    return;
  }"""
new = """  const nomCourtPnjJeremy = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtPnjJeremy === 'Jérémy' && action === 'bonjour') {
    speech.textContent = "Vous avez des questions ? Je peux vous aider, Monsieur Petit sera fier de moi.";
    return;
  }

  // Rappel de l'etape en cours de la quete d'accueil, si le joueur se sent perdu (clic trop
  // rapide, popup fermee sans lire...). Rejoue le meme message et la meme surbrillance que
  // ceux affiches au demarrage de l'etape en cours.
  if (nomCourtPnjJeremy === 'Jérémy' && action !== 'bonjour' && /où en (?:étions|sommes)|rappel|perdu|que dois-je faire|je ne sais plus|c'était quoi déjà/i.test(action)) {
    if (typeof queteAccueilRappel === 'function' && queteAccueilRappel()) {
      speech.textContent = "Ah, vous vous êtes un peu perdu ? Pas de souci, je vous remontre.";
      return;
    }
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Rappel de la quête déclenché par mot-clé quand on parle à Jérémy.")
