#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# Retirer le hook mal place dans closeCharSheet (mauvaise fonction)
old_1 = """function closeCharSheet() {
  if (typeof queteAccueilApresFichePersonnage === 'function') queteAccueilApresFichePersonnage();"""
new_1 = """function closeCharSheet() {"""
assert content.count(old_1) == 1, f"retrait : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# Ajouter le hook au bon endroit : closeSelfView (la vraie fiche accessible depuis Personnes Presentes)
old_2 = """function closeSelfView() {
  document.getElementById('vue-self').classList.remove('active');"""
new_2 = """function closeSelfView() {
  if (typeof queteAccueilApresFichePersonnage === 'function') queteAccueilApresFichePersonnage();
  document.getElementById('vue-self').classList.remove('active');"""
assert content.count(old_2) == 1, f"ajout : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook déplacé de closeCharSheet vers closeSelfView.")
