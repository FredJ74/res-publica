#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doOrder(fn, pa, cost, label, desc, successRate) {
  successRate = successRate || 70;"""
new = """function doOrder(fn, pa, cost, label, desc, successRate) {
  if (typeof queteAccueilNotifierOrdre === 'function') queteAccueilNotifierOrdre(fn);
  successRate = successRate || 70;"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook générique ajouté dans doOrder.")
