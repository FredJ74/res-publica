#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Enigme du portrait disparu : Clerc Delhune (notaire) et Directeur Mercier (banquier),"""

new = """  // Legende urbaine de Maxence Monfils : rumeurs independantes de toute enigme, tant que
  // le joueur mentionne son nom, aupres de quelques PNJ qui le "surveillent" sans jamais
  // vraiment le trouver. Le mystere ne doit jamais etre tranche.
  if (/maxence/i.test(action)) {
    if (nomCourtEnigme === 'Pat Hounette') {
      speech.textContent = "Chut... si Maxence apprend qu'il y a des scarabées ici, on est mal...";
      return;
    }
    if (nomCourtEnigme === 'Florian Grès') {
      speech.textContent = "Je le surveille depuis ce matin. Impossible de savoir où il est passé...";
      return;
    }
    if (nomCourtEnigme === 'Jean-Pierre Ciseaux') {
      speech.textContent = "Les orchidées ne risquent rien... ce sont les insectes qui m'inquiètent.";
      return;
    }
    if (nomCourtEnigme === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      return;
    }
  }

  // Enigme du portrait disparu : Clerc Delhune (notaire) et Directeur Mercier (banquier),"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Rumeurs sur Maxence Monfils ajoutées (Pat Hounette, Florian Grès, Jean-Pierre Ciseaux, Louis Chevillard).")
