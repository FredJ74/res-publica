#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """const NIVEAUX_CONSTRUCTION = {
  hangar:            { label: 'Hangar',             cout: 30000 },
  commerce_standard: { label: 'Commerce standard',  cout: 50000 },
  commerce_premium:  { label: 'Commerce premium',   cout: 70000 },
  building:          { label: 'Building',           cout: 100000 }
};"""
new = """const NIVEAUX_CONSTRUCTION = {
  hangar:            { label: 'Hangar',             cout: 30000,  imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hangar-construction-terrain.png' },
  commerce_standard: { label: 'Commerce standard',  cout: 50000,  imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commerce-standard-construction-terrain.png' },
  commerce_premium:  { label: 'Commerce premium',   cout: 70000,  imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commerce-premium-construction-terrain.png' },
  building:          { label: 'Building',           cout: 100000, imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/building-construction-terrain.png' }
};"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Les 4 images de niveaux de construction rattachées à NIVEAUX_CONSTRUCTION.")
