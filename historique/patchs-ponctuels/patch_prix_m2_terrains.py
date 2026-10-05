#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doAcheterTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  const prix = 25000;"""

new = """// Surface reelle de chaque lot (m2), source de verite unique pour le prix au m2 et pour la
// future taxe fonciere (le cron cote serveur lira aussi cette valeur une fois stockee dans
// l'etat du terrain — voir doAcheterTerrain ci-dessous).
const SURFACE_TERRAINS = {
  'terrain-a-batir-1': 2150,
  'terrain-a-batir-2': 2300,
  'terrain-a-batir-3': 2300,
  'terrain-a-batir-4': 1850,
  'terrain-a-batir-5': 2750
};
const PRIX_AU_M2_TERRAIN = 12;

function doAcheterTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  const surface = SURFACE_TERRAINS[id] || 2000;
  const prix = surface * PRIX_AU_M2_TERRAIN;"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

# Stocker la surface dans l'etat persiste, pour que le futur cron de taxe fonciere puisse la
# lire directement sans avoir besoin de connaitre le contenu du jeu (BUILDINGS).
old_2 = """  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis
  });"""
new_2 = """  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface
  });"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Prix au m² appliqué (12 FR/m²), surface stockée dans l'état persisté du terrain.")
