#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function closeCharSheet() {"""
new = """function closeCharSheet() {
  if (typeof queteAccueilApresFichePersonnage === 'function') queteAccueilApresFichePersonnage();"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook ajouté dans closeCharSheet.")
