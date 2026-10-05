#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  emp.inGroupe = true;
  updateUI();
  renderEmployesPanel();
  showToast(nomPnj + ' rejoint le groupe !', '', true);
}"""
new = """  emp.inGroupe = true;
  updateUI();
  renderEmployesPanel();
  showToast(nomPnj + ' rejoint le groupe !', '', true);

  // Quete d'accueil : la premiere fois qu'un joueur recupere un employe via ce systeme,
  // on explique comment s'en separer plus tard (icone X dans Mes Employes).
  if (nomPnj === 'Jérémy' && typeof queteAccueilExpliquerLicenciement === 'function') {
    queteAccueilExpliquerLicenciement();
  }
}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook d'explication du licenciement ajouté à recupererPnjDansGroupe.")
