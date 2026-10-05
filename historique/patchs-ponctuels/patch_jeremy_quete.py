#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """const QUETE_ACCUEIL_IMAGES = {
  gardeMenacant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-menacant-luthecia.png',
  gardeBienveillant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-bienveillant-luthecia.png'
};"""
new = """const QUETE_ACCUEIL_IMAGES = {
  gardeMenacant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-menacant-luthecia.png',
  gardeBienveillant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-bienveillant-luthecia.png',
  jeremy: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeremy-stagiaire-mairie.png'
};

// Reponse acceptee/refusee a la proposition d'aide de Jeremy (declenchee depuis plateau-pnj.js
// quand le joueur repond "je suis nouveau" au Secretaire Municipal Petit).
function queteAccueilAccepterJeremy() {
  state.char.queteAccueil = { etape: 'jeremy_groupe' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof rejoindreJeremy === 'function') rejoindreJeremy();

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Bonjour, je suis Jérémy, le stagiaire à tout faire de ce maudit Hôtel de Ville. Je suis bien content de pouvoir vous guider, le secrétaire n'arrête pas de me demander de lui faire du café et des photocopies. On va commencer par aller dans un endroit plus calme. On va aller dans la salle des élections.",
    suivant: null
  });
}

function queteAccueilRefuserJeremy() {
  state.char.queteAccueil = { etape: 'refusee' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fonctions Jérémy ajoutées à plateau-quete-accueil.js.")
