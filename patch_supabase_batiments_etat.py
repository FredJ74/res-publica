#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function sbCreerPret(pret) {"""
new = """// Etat generique par batiment (pas seulement les terrains) — sert de fondation au systeme
// de blocus syndical, mais reutilisable pour d'autres mecaniques futures liees a un batiment
// precis (pas a la ville entiere).
async function sbGetBatimentEtat(country, city, buildingId) {
  const id = country + '_' + city + '_' + buildingId;
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    try { return JSON.parse(rows[0].data); } catch(e) { return {}; }
  }
  return {};
}

async function sbSetBatimentEtat(country, city, buildingId, patch) {
  const id = country + '_' + city + '_' + buildingId;
  const actuel = await sbGetBatimentEtat(country, city, buildingId);
  const fusion = { ...actuel, ...patch };
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(id)}`, { data: JSON.stringify(fusion), updated_at: new Date().toISOString() });
  } else {
    await sbInsert('batiments_etat', { id, country, city, building_id: buildingId, data: JSON.stringify(fusion) });
  }
  return fusion;
}

async function sbCreerPret(pret) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ sbGetBatimentEtat / sbSetBatimentEtat créées (fondation générique par bâtiment).")
