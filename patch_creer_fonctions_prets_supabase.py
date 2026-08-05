#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// NOTE : sbGetTerrainsAvecLotsLoues a ete retiree"""
new = """// Trois fonctions manquantes decouvertes le 5 aout 2026 : appelees partout dans le code des
// prets bancaires (confirmerPretBancaire, preleverPretsBancaires) mais jamais definies —
// les prets n'etaient donc jamais reellement persistes, juste de l'argent credite en memoire.
async function sbCreerPret(pret) {
  return await sbInsert('prets', pret);
}

async function sbGetPretsEnCours(nom) {
  const rows = await sbGet('prets', `emprunteur=eq.${encodeURIComponent(nom)}&statut=eq.en_cours`);
  return rows || [];
}

async function sbUpdatePret(id, patch) {
  return await sbUpdate('prets', `id=eq.${encodeURIComponent(id)}`, patch);
}

// NOTE : sbGetTerrainsAvecLotsLoues a ete retiree"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ sbCreerPret, sbGetPretsEnCours, sbUpdatePret créées.")
