#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface,
    valeur_totale: prix,
    dette_fonciere: 0
  });"""
new_1 = """  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface,
    valeur_totale: prix,
    dette_fonciere: 0,
    city: state.currentCity || 'capitale'
  });"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire, surface, valeur_totale: prix, dette_fonciere: 0 }).catch(() => {});
    }"""
new_2 = """    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire, surface, valeur_totale: prix, dette_fonciere: 0, city: state.currentCity || 'capitale' }).catch(() => {});
    }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ville d'appartenance du terrain stockée à l'achat (nécessaire pour le cron de taxe foncière).")
