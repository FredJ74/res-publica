#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'voler_materiel_chantier') { doVolerMaterielChantier(); return; }"""
new = """  if (fn === 'voler_materiel_chantier') { doVolerMaterielChantier(); return; }
  if (fn === 'emprunter_construction') { ouvrirModalPretBancaire('nationale', 'travaux'); return; }
  if (fn === 'emprunter') {
    const typeBanque = state.currentBuilding === 'banque-privee' ? 'privee' : 'nationale';
    ouvrirModalPretBancaire(typeBanque);
    return;
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordres 'emprunter_construction' et 'emprunter' routés.")
