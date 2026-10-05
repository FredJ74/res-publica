#!/usr/bin/env python3

# --- 1. doAcheterTerrain : inclure valeur_totale (surface reelle) dans les ecritures ---
PATH_PNJ = "plateau-pnj.js"
with open(PATH_PNJ, "r", encoding="utf-8") as f:
    pnj = f.read()

old_1 = """  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface
  });"""
new_1 = """  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface,
    valeur_totale: prix,
    dette_fonciere: 0
  });"""
assert pnj.count(old_1) == 1, f"bloc 1 : trouvé {pnj.count(old_1)} fois (attendu 1)"
pnj = pnj.replace(old_1, new_1)

old_2 = """    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire, surface }).catch(() => {});
    }"""
new_2 = """    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire, surface, valeur_totale: prix, dette_fonciere: 0 }).catch(() => {});
    }"""
assert pnj.count(old_2) == 1, f"bloc 2 : trouvé {pnj.count(old_2)} fois (attendu 1)"
pnj = pnj.replace(old_2, new_2)

with open(PATH_PNJ, "w", encoding="utf-8") as f:
    f.write(pnj)
print("✅ valeur_totale (prix reel au m²) et dette_fonciere initialisees a l'achat.")

# --- 2. getValeurTotaleBien : partir de la vraie valeur du terrain, pas d'un prix fixe ---
PATH_JE = "plateau-justice-economie.js"
with open(PATH_JE, "r", encoding="utf-8") as f:
    je = f.read()

old_3 = """function getValeurTotaleBien(ts) {
  if (!ts) return PRIX_TERRAIN;
  const niveau = NIVEAUX_CONSTRUCTION[ts.niveau_construction];
  return PRIX_TERRAIN + (niveau ? niveau.cout : 0);
}"""
new_3 = """function getValeurTotaleBien(ts) {
  if (!ts) return PRIX_TERRAIN;
  const base = ts.valeur_totale || PRIX_TERRAIN; // prix reel au m2 paye a l'achat, si connu
  const niveau = NIVEAUX_CONSTRUCTION[ts.niveau_construction];
  return base + (niveau ? niveau.cout : 0);
}"""
assert je.count(old_3) == 1, f"bloc 3 : trouvé {je.count(old_3)} fois (attendu 1)"
je = je.replace(old_3, new_3)

with open(PATH_JE, "w", encoding="utf-8") as f:
    f.write(je)
print("✅ getValeurTotaleBien utilise désormais la vraie valeur du terrain (surface × prix).")
