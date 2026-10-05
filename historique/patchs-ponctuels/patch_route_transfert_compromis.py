#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'corrompre_rdv_notaire') { doCorrompreRdvNotaire(); return; }"""
new = """  if (fn === 'corrompre_rdv_notaire') { doCorrompreRdvNotaire(); return; }
  if (fn === 'transferer_compromis') { doOuvrirTransfertCompromis(); return; }
  if (fn === 'valider_transfert_compromis') { doValiderTransfertCompromis(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordres routés.")
