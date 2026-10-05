#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (etape === 'stade_libre' && buildingId === 'stade') {
    // On arme le minuteur une seule fois (passage a 'stade_libre_minuteur' pour ne pas le
    // reclencher a chaque changement de piece a l'interieur du stade).
    state.char.queteAccueil = { etape: 'stade_libre_minuteur' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    setTimeout(function() {
      if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
      if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return; // le joueur a deja avance autrement
      afficherRepriseContactJeremy();
    }, 60000);
    return;
  }"""
new = """  if (etape === 'stade_libre' && buildingId === 'stade') {
    // On arme le minuteur une seule fois (passage a 'stade_libre_minuteur' pour ne pas le
    // reclencher a chaque changement de piece a l'interieur du stade). minuteurDebut est un
    // horodatage reel (pas seulement un setTimeout en memoire) pour survivre a un
    // rafraichissement de page — bug remonte par l'audit ChatGPT du 5 aout 2026.
    state.char.queteAccueil = { etape: 'stade_libre_minuteur', minuteurDebut: Date.now() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    setTimeout(function() {
      if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
      if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return; // le joueur a deja avance autrement
      afficherRepriseContactJeremy();
    }, 60000);
    return;
  }

  // Filet de securite : si le joueur revient dans un batiment (ou recharge la page) alors
  // que le minuteur du stade est toujours en attente, on verifie l'horodatage reel plutot
  // que de compter sur le setTimeout d'origine (perdu au rafraichissement). Si les 60
  // secondes sont deja ecoulees, on declenche immediatement ; sinon on rearme le temps
  // restant exact.
  if (etape === 'stade_libre_minuteur' && state.char.queteAccueil.minuteurDebut) {
    const ecoule = Date.now() - state.char.queteAccueil.minuteurDebut;
    if (ecoule >= 60000) {
      afficherRepriseContactJeremy();
    } else if (!state.char.queteAccueil.minuteurRearme) {
      state.char.queteAccueil.minuteurRearme = true; // evite de rearmer plusieurs fois par entrees successives
      setTimeout(function() {
        if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
        if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return;
        afficherRepriseContactJeremy();
      }, 60000 - ecoule);
    }
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Minuteur du stade basé sur un horodatage réel, survit désormais à un rafraîchissement de page.")
