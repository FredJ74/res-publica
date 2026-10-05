#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      evenements.push({ annee: autre.naissanceAnnee, texte: autre.naissanceAnnee + ' : naissance de ' + autre.nom + ', fils/fille de ' + p.parents_display_placeholder_ignore + '' });
    }
  });"""
new = """  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      const parentsEnfantTxt = autre.parents.join(' et ');
      evenements.push({ annee: autre.naissanceAnnee, texte: autre.naissanceAnnee + ' : naissance de ' + autre.nom + ', fils/fille de ' + parentsEnfantTxt + '.' });
    }
  });"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bug corrigé : les enfants affichent maintenant leurs deux vrais parents.")
