#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof queteAccueilVerifierGuidage === 'function') {
    queteAccueilVerifierGuidage(pays, noeudId);
  }
  if (typeof queteAccueilVerifierGuidage === 'function') {
    queteAccueilVerifierGuidage(pays, noeudId);
  }"""
new = """  if (typeof queteAccueilVerifierGuidage === 'function') {
    queteAccueilVerifierGuidage(pays, noeudId);
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Doublon retiré.")
