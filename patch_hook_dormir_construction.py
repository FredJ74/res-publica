#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Payer les loyers des locations actives
  payerLocations();
  // Payer les escorts actives
  payerEscorts();
  payerEmployes();"""
new = """  // Payer les loyers des locations actives
  payerLocations();
  // Revenu passif + bonus INF/POP/DIS des bâtiments construits sur des terrains possédés
  if (typeof collecterRevenusConstructions === 'function') await collecterRevenusConstructions();
  // Payer les escorts actives
  payerEscorts();
  payerEmployes();"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Revenu passif des constructions branché dans la séquence Dormir.")
