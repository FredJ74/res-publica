#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function sbGetTerrainsLibres(country) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}`);
  return rows || [];
}"""

new = """async function sbGetTerrainsLibres(country) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}`);
  return rows || [];
}

// Historique PERMANENT des ventes de terrains (contrairement a 'terrains_etat' qui n'ecrase
// que l'etat courant) — chaque achat s'y ajoute, sans jamais rien remplacer. Sert de base
// pour les Archives Notariales.
async function sbEnregistrerVenteTerrain(country, buildingId, proprietaire, prix) {
  return sbInsert('terrains_historique_ventes', {
    id: 'vente-' + buildingId + '-' + Date.now(),
    country, building_id: buildingId, proprietaire, prix
  });
}

async function sbGetHistoriqueTerrain(country, buildingId) {
  const rows = await sbGet('terrains_historique_ventes', `country=eq.${encodeURIComponent(country)}&building_id=eq.${encodeURIComponent(buildingId)}&order=created_at.asc`);
  return rows || [];
}

async function sbGetToutHistoriqueTerrains(country) {
  const rows = await sbGet('terrains_historique_ventes', `country=eq.${encodeURIComponent(country)}&order=created_at.asc`);
  return rows || [];
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fonctions Supabase créées : historique permanent des ventes de terrains.")
