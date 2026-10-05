#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Revenu passif + bonus INF/POP/DIS des bâtiments construits sur des terrains possédés
  if (typeof collecterRevenusConstructions === 'function') await collecterRevenusConstructions();"""
new = """  // Revenu passif + bonus INF/POP/DIS des bâtiments construits sur des terrains possédés
  if (typeof collecterRevenusConstructions === 'function') await collecterRevenusConstructions();
  // Loyers des lots subdivisés loués ailleurs (paiement direct au propriétaire)
  if (typeof payerLoyersLotsLoues === 'function') await payerLoyersLotsLoues();"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Paiement des loyers de lots branché dans la séquence Dormir.")
