#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Si le joueur est marie, traiter la succession AVANT de supprimer le personnage
  if (typeof sbGetMariageActif === 'function') {
    try {
      const mariage = await sbGetMariageActif(nom);
      if (mariage) {
        const conjoint = mariage.conjoint1 === nom ? mariage.conjoint2 : mariage.conjoint1;
        await traiterSuccession(nom, conjoint);
        if (typeof sbDissoudreMariage === 'function') {
          await sbDissoudreMariage(mariage.id).catch(() => {});
        }
      }
    } catch(e) { console.warn('Erreur traitement succession', e); }
  }

  if (typeof sbDeletePersonnage === 'function') {
    await sbDeletePersonnage(nom).catch(() => {});
  }"""

new = """  // Si le joueur est marie, traiter la succession AVANT de supprimer le personnage
  if (typeof sbGetMariageActif === 'function') {
    try {
      const mariage = await sbGetMariageActif(nom);
      if (mariage) {
        const conjoint = mariage.conjoint1 === nom ? mariage.conjoint2 : mariage.conjoint1;
        await traiterSuccession(nom, conjoint);
        if (typeof sbDissoudreMariage === 'function') {
          await sbDissoudreMariage(mariage.id, 'veuvage').catch(() => {});
        }
      }
    } catch(e) { console.warn('Erreur traitement succession', e); }
  }

  // Archive permanente du deces, pour l'etat-civil (le personnage lui-meme va etre supprime
  // juste apres, cette trace est la seule qui subsistera).
  if (typeof sbEnregistrerDeces === 'function') {
    await sbEnregistrerDeces(nom, state.country).catch(() => {});
  }

  if (typeof sbDeletePersonnage === 'function') {
    await sbDeletePersonnage(nom).catch(() => {});
  }"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Archivage du décès + correction veuvage/mariage ajoutés à la destruction de personnage.")
