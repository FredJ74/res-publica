#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function ouvrirPlanVille(countryId, cityId, readOnly) {
  countryId = countryId || state.country;
  cityId = cityId || state.currentCity;
  readOnly = readOnly || false;"""
new = """function ouvrirPlanVille(countryId, cityId, readOnly) {
  countryId = countryId || state.country;
  cityId = cityId || state.currentCity;
  // Le plan est une carte d'orientation, pas un moyen de deplacement (choix explicite de
  // Fred, jamais voulu autrement) — readOnly=true par defaut desormais. Passer false
  // explicitement pour reactiver le clic, si un jour ce choix change.
  readOnly = readOnly === false ? false : true;"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Navigation directe depuis le Plan désactivée (readOnly=true par défaut) — le plan redevient une simple carte d'orientation.")
