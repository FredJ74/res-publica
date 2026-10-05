#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'valider_transfert_compromis') { doValiderTransfertCompromis(); return; }"""
new = """  if (fn === 'valider_transfert_compromis') { doValiderTransfertCompromis(); return; }
  if (fn === 'payer_versement_chantier') { doPayerVersementChantier(); return; }
  if (fn === 'corrompre_chantier') { doCorrompreChantier(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordres routés.")
