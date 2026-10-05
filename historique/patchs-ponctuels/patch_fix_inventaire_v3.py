#!/usr/bin/env python3
PATH_EC = "plateau-etat-civil.js"
with open(PATH_EC, "r", encoding="utf-8") as f:
    ec = f.read()

# Petits remplacements cibles, un par un
replacements = [
    ("item.nom === 'Fiche d", "item.name === 'Fiche d"),
    ("    nom: 'Fiche d", "    name: 'Fiche d"),
    ("    description: texteComplet", "    desc: texteComplet"),
    ("  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});\n  if (typeof showToast === 'function') showToast('Fiche imprimée'",
     "  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});\n  if (typeof updateUI === 'function') updateUI();\n  if (typeof renderInvItemsPanel === 'function') renderInvItemsPanel();\n  if (typeof showToast === 'function') showToast('Fiche imprimée'"),
]

for old, new in replacements:
    count = ec.count(old)
    if count != 1:
        print(f"⚠️  ATTENTION : '{old[:50]}...' trouvé {count} fois (attendu 1) — ignoré, à vérifier manuellement.")
        continue
    ec = ec.replace(old, new)
    print(f"✅ Remplacé : {old[:50]}...")

with open(PATH_EC, "w", encoding="utf-8") as f:
    f.write(ec)
