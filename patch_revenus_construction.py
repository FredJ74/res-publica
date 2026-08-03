#!/usr/bin/env python3

# --- 1. Nouvelle fonction Supabase : tous les terrains possedes par un joueur ---
PATH_SB = "supabase.js"
with open(PATH_SB, "r", encoding="utf-8") as f:
    sb = f.read()

old_sb = """async function sbGetTerrainsLibres(country) {"""
new_sb = """// Tous les terrains possedes par un joueur donne, quel que soit l'endroit ou il se trouve
// (necessaire pour le revenu passif/bonus au moment de Dormir, qui peut se produire ailleurs
// que sur le terrain lui-meme).
async function sbGetTerrainsPossedesPar(country, nom) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}&proprietaire=eq.${encodeURIComponent(nom)}`);
  return (rows || []).map(function(r) {
    try { return { buildingId: r.building_id, ...JSON.parse(r.data) }; } catch(e) { return null; }
  }).filter(Boolean);
}

async function sbGetTerrainsLibres(country) {"""
assert sb.count(old_sb) == 1, f"supabase.js : trouvé {sb.count(old_sb)} fois (attendu 1)"
sb = sb.replace(old_sb, new_sb)

with open(PATH_SB, "w", encoding="utf-8") as f:
    f.write(sb)
print("✅ sbGetTerrainsPossedesPar créée.")

# --- 2. Tables de revenu/bonus par niveau + fonction de collecte ---
PATH_JE = "plateau-justice-economie.js"
with open(PATH_JE, "r", encoding="utf-8") as f:
    je = f.read()

old_je = """function getValeurTotaleBien(ts) {"""
new_je = """// Revenu passif quotidien + bonus INF/POP/DIS par niveau de construction. Applique sans
// condition (contrairement aux bureaux loues, qui necessitent une organisation domiciliee) :
// c'est le proprietaire lui-meme qui en profite directement, chaque nuit.
const REVENU_CONSTRUCTION = { hangar: 50, commerce_standard: 150, commerce_premium: 300, building: 500 };
const BONUS_CONSTRUCTION = {
  hangar: {},
  commerce_standard: { inf: 3 },
  commerce_premium: { inf: 6, pop: 2 },
  building: { inf: 10, pop: 5, dis: 3 }
};

async function collecterRevenusConstructions() {
  if (typeof sbGetTerrainsPossedesPar !== 'function' || !state.char?.name) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let terrains;
  try {
    terrains = await sbGetTerrainsPossedesPar(state.country, state.char.name);
  } catch(e) { return; }

  (terrains || []).forEach(function(ts) {
    if (!ts.niveau_construction) return;
    const revenu = REVENU_CONSTRUCTION[ts.niveau_construction] || 0;
    const bonus = BONUS_CONSTRUCTION[ts.niveau_construction] || {};
    const label = NIVEAUX_CONSTRUCTION[ts.niveau_construction]?.label || ts.niveau_construction;

    if (revenu > 0) {
      state.arg = (state.arg || 0) + revenu;
      addJournalEntry('Revenu du ' + label + ' : +' + revenu + ' ' + cur, 'event-good');
    }
    if (bonus.pop) state.pop = Math.min(100, (state.pop || 0) + bonus.pop);
    if (bonus.inf) state.inf = Math.min(100, (state.inf || 0) + bonus.inf);
    if (bonus.dis) state.dis = Math.min(100, (state.dis || 50) + bonus.dis);
  });
}

function getValeurTotaleBien(ts) {"""
assert je.count(old_je) == 1, f"plateau-justice-economie.js : trouvé {je.count(old_je)} fois (attendu 1)"
je = je.replace(old_je, new_je)

with open(PATH_JE, "w", encoding="utf-8") as f:
    f.write(je)
print("✅ collecterRevenusConstructions créée (revenu passif + bonus INF/POP/DIS).")
